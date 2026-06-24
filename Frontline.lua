Frontline = {}
do
    function Frontline.computeFrontline()
        local empty_result = {
            red_segments = {},
            blue_segments = {},
            frontline_segments = {}
        }

        -- Split owned zones by side.
        local red_pts, blue_pts = {}, {}
        for _, zone in ipairs(zones) do
            local p = {x = zone.zone.point.x, y = zone.zone.point.z}
            if zone.side == coalition.side.RED then
                table.insert(red_pts, p)
            elseif zone.side == coalition.side.BLUE then
                table.insert(blue_pts, p)
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

        local function centroid(pts)
            local sx, sy = 0, 0
            for _, p in ipairs(pts) do sx = sx + p.x; sy = sy + p.y end
            return {x = sx / #pts, y = sy / #pts}
        end

        local red_c = centroid(red_pts)
        local blue_c = centroid(blue_pts)

        local adx = blue_c.x - red_c.x
        local ady = blue_c.y - red_c.y
        local alen = math.sqrt(adx * adx + ady * ady)
        local tx, ty
        if alen > 1 then
            tx, ty = -ady / alen, adx / alen
        else
            tx, ty = 1, 0 -- centroids coincide; arbitrary tangent
        end

        local function buildSideLine(own, enemy)
            -- Score every owned zone by distance to its nearest enemy zone.
            local scored = {}
            for _, p in ipairs(own) do
                local best = math.huge
                for _, e in ipairs(enemy) do
                    local d = dist2(p, e)
                    if d < best then best = d end
                end
                scored[#scored + 1] = {p = p, near = best, proj = p.x * tx + p.y * ty}
            end

            -- Forward-edge zones: nearest enemy within contact range.
            local front = {}
            for _, s in ipairs(scored) do
                if s.near <= CONTACT_RANGE_SQ then
                    front[#front + 1] = s
                end
            end

            if #front < 2 and #scored >= 2 then
                table.sort(scored, function(u, v) return u.near < v.near end)
                front = {scored[1], scored[2]}
            end

            table.sort(front, function(u, v) return u.proj < v.proj end)

            local segments = {}
            for i = 1, #front - 1 do
                segments[#segments + 1] = {
                    {x = front[i].p.x,     y = front[i].p.y},
                    {x = front[i + 1].p.x, y = front[i + 1].p.y}
                }
            end
            return segments
        end

        local red_segments = buildSideLine(red_pts, blue_pts)
        local blue_segments = buildSideLine(blue_pts, red_pts)

        local frontline_segments = {}
        for _, s in ipairs(red_segments) do frontline_segments[#frontline_segments + 1] = s end
        for _, s in ipairs(blue_segments) do frontline_segments[#frontline_segments + 1] = s end

        return {
            red_segments = red_segments,
            blue_segments = blue_segments,
            frontline_segments = frontline_segments
        }
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
        local red_color = palette.frontline_red_color or palette.frontline_color
        local blue_color = palette.frontline_blue_color or palette.frontline_color
        local red_linestyle = palette.frontline_red_linestyle or palette.frontline_linestyle
        local blue_linestyle = palette.frontline_blue_linestyle or palette.frontline_linestyle

        local function drawSide(segments, color, linestyle)
            for _, segment in ipairs(segments) do
                local mark_id = nextMarkId()
                trigger.action.lineToAll(-1, mark_id, utils.toVec3(segment[1]), utils.toVec3(segment[2]), color, linestyle, true)
                table.insert(Frontline.mark_ids, mark_id)
            end
        end

        drawSide(frontline_data.red_segments, red_color, red_linestyle)
        drawSide(frontline_data.blue_segments, blue_color, blue_linestyle)

        Frontline.mark_id = Frontline.mark_ids[#Frontline.mark_ids]
        MissionLogger:info("FRONTLINE: Frontline drawn")
    end
end
