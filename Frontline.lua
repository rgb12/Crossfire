Frontline = {}
do
    function Frontline.computeFrontline()
        local empty_result = { frontline_segments = {} }

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

        local boundary = {}
        local function addContacts(own, enemy)
            for _, p in ipairs(own) do
                local best, best_e = math.huge, nil
                for _, e in ipairs(enemy) do
                    local d = dist2(p, e)
                    if d < best then best, best_e = d, e end
                end
                if best_e and best <= CONTACT_RANGE_SQ then
                    local mx = (p.x + best_e.x) * 0.5
                    local my = (p.y + best_e.y) * 0.5
                    boundary[#boundary + 1] = {x = mx, y = my, proj = mx * tx + my * ty}
                end
            end
        end
        addContacts(red_pts, blue_pts)
        addContacts(blue_pts, red_pts)

        if #boundary == 0 then
            return empty_result
        end

        -- Order across the front.
        table.sort(boundary, function(u, v) return u.proj < v.proj end)

        -- Collapse near-duplicate / out-of-order points: keep monotone progress
        -- along the front and drop points closer than MIN_SPACING so smoothing
        -- isn't dominated by clustered midpoints.
        local MIN_SPACING_SQ = 1000 * 1000
        local pts = {}
        for _, b in ipairs(boundary) do
            local prev = pts[#pts]
            if not prev or dist2(prev, b) >= MIN_SPACING_SQ then
                pts[#pts + 1] = {x = b.x, y = b.y}
            end
        end

        if #pts < 2 then
            return empty_result
        end

        local frontline_segments = {}
        for i = 1, #pts - 1 do
            frontline_segments[#frontline_segments + 1] = {
                {x = pts[i].x,     y = pts[i].y},
                {x = pts[i + 1].x, y = pts[i + 1].y}
            }
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
