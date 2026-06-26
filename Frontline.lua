Frontline = {}
do
    function Frontline.computeFrontline()
        local empty_result = { frontline_segments = {} }

        local red_pts, blue_pts = {}, {}
        for _, zone in ipairs(zones) do
            local p = {x = zone.zone.point.x, y = zone.zone.point.z}
            if zone.side == coalition.side.RED then
                red_pts[#red_pts + 1] = p
            elseif zone.side == coalition.side.BLUE then
                blue_pts[#blue_pts + 1] = p
            end
        end

        -- A frontline only exists if both coalitions are present.
        if #red_pts == 0 or #blue_pts == 0 then
            return empty_result
        end

        local CONTACT_RANGE = Config.frontline_contact_range or 80000
        local CONTACT_RANGE_SQ = CONTACT_RANGE * CONTACT_RANGE

        local function dist2(a, b)
            local dx = a.x - b.x
            local dy = a.y - b.y
            return dx * dx + dy * dy
        end
        local function isContactPair(r, b)
            local cx, cy = (r.x + b.x) * 0.5, (r.y + b.y) * 0.5
            local rad_sq = dist2(r, b) * 0.25
            for _, q in ipairs(red_pts) do
                if q ~= r and q ~= b then
                    local dx, dy = q.x - cx, q.y - cy
                    if dx * dx + dy * dy < rad_sq then return false end
                end
            end
            for _, q in ipairs(blue_pts) do
                if q ~= r and q ~= b then
                    local dx, dy = q.x - cx, q.y - cy
                    if dx * dx + dy * dy < rad_sq then return false end
                end
            end
            return true
        end

        local MIN_HALF = 6000
        local MAX_HALF = 30000
        local frontline_segments = {}
        local closest_d, closest_r, closest_b = math.huge, nil, nil
        for _, r in ipairs(red_pts) do
            for _, b in ipairs(blue_pts) do
                local d = dist2(r, b)
                if d < closest_d then closest_d, closest_r, closest_b = d, r, b end
                if d <= CONTACT_RANGE_SQ and isContactPair(r, b) then
                    local mx, my = (r.x + b.x) * 0.5, (r.y + b.y) * 0.5
                    -- Perpendicular to (b - r), normalised.
                    local dirx, diry = b.x - r.x, b.y - r.y
                    local len = math.sqrt(dirx * dirx + diry * diry)
                    if len > 1 then
                        local nx, ny = -diry / len, dirx / len
                        local half = len * 0.5
                        if half < MIN_HALF then half = MIN_HALF end
                        if half > MAX_HALF then half = MAX_HALF end
                        frontline_segments[#frontline_segments + 1] = {
                            {x = mx - nx * half, y = my - ny * half},
                            {x = mx + nx * half, y = my + ny * half}
                        }
                    end
                end
            end
        end

        if #frontline_segments == 0 and closest_r and closest_b then
            local r, b = closest_r, closest_b
            local mx, my = (r.x + b.x) * 0.5, (r.y + b.y) * 0.5
            local dirx, diry = b.x - r.x, b.y - r.y
            local len = math.sqrt(dirx * dirx + diry * diry)
            if len > 1 then
                local nx, ny = -diry / len, dirx / len
                frontline_segments[1] = {
                    {x = mx - nx * 8000, y = my - ny * 8000},
                    {x = mx + nx * 8000, y = my + ny * 8000}
                }
            else
                frontline_segments[1] = {
                    {x = mx, y = my - 8000}, {x = mx, y = my + 8000}
                }
            end
        end

        if #frontline_segments == 0 then
            return empty_result
        end

        return { frontline_segments = frontline_segments }
    end

    Frontline.mark_id = nil
    Frontline.mark_ids = nil
    Frontline.cached_segments = {}

    -- Shortest distance (meters) from a world point to the current frontline.
    ---@param point table
    ---@return number
    function Frontline.distanceToFrontline(point)
        local segments = Frontline.cached_segments
        if not segments or #segments == 0 then
            return 0
        end

        -- Frontline segment points are stored as {x = world.x, y = world.z}.
        local px = point.x
        local py = point.z or point.y

        local best = math.huge
        for _, segment in ipairs(segments) do
            local a, b = segment[1], segment[2]
            local abx, aby = b.x - a.x, b.y - a.y
            local apx, apy = px - a.x, py - a.y
            local ab_len_sq = abx * abx + aby * aby
            local t = 0
            if ab_len_sq > 0 then
                t = (apx * abx + apy * aby) / ab_len_sq
                if t < 0 then t = 0 elseif t > 1 then t = 1 end
            end
            local cx, cy = a.x + abx * t, a.y + aby * t
            local dx, dy = px - cx, py - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < best then best = dist end
        end
        return best
    end

    function Frontline.clearFrontline()
        if not Frontline.mark_ids then
            Frontline.mark_ids = {}
            return
        end

        for _, mark_id in ipairs(Frontline.mark_ids) do
            trigger.action.removeMark(mark_id)
        end

        Frontline.mark_ids = {}
        Frontline.mark_id = nil
    end

    function Frontline.drawFrontline()
        MissionLogger:info("FRONTLINE: Computing frontline...")
        local frontline_data = Frontline.computeFrontline()
        Frontline.cached_segments = frontline_data.frontline_segments
        Frontline.clearFrontline()

        local palette = Config.draw_color_palette
        local color = palette.frontline_color
        local linestyle = palette.frontline_linestyle

        for _, segment in ipairs(frontline_data.frontline_segments) do
            local mark_id = nextMarkId()
            trigger.action.lineToAll(-1, mark_id, utils.toVec3(segment[1]), utils.toVec3(segment[2]), color, linestyle, true)
            table.insert(Frontline.mark_ids, mark_id)
        end

        Frontline.mark_id = Frontline.mark_ids[#Frontline.mark_ids]
        MissionLogger:info("FRONTLINE: Frontline drawn")
    end
end
