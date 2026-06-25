Frontline = {}
do
    function Frontline.computeFrontline()
        local empty_result = { frontline_segments = {} }

        -- Split owned zones by side. Neutral zones are excluded (they have no
        -- owner, so no contact line passes through them).
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

        local boundary = {}
        for _, r in ipairs(red_pts) do
            for _, b in ipairs(blue_pts) do
                local d = dist2(r, b)
                if d <= CONTACT_RANGE_SQ then
                    boundary[#boundary + 1] = {
                        x = (r.x + b.x) * 0.5,
                        y = (r.y + b.y) * 0.5
                    }
                end
            end
        end

        if #boundary == 0 then
            local best, br, bb = math.huge, nil, nil
            for _, r in ipairs(red_pts) do
                for _, b in ipairs(blue_pts) do
                    local d = dist2(r, b)
                    if d < best then best, br, bb = d, r, b end
                end
            end
            if br and bb then
                boundary[1] = {x = (br.x + bb.x) * 0.5, y = (br.y + bb.y) * 0.5}
            end
        end

        if #boundary == 0 then
            return empty_result
        end

        local MIN_SPACING_SQ = 1000 * 1000
        local nodes = {}
        for _, m in ipairs(boundary) do
            local dup = false
            for _, n in ipairs(nodes) do
                if dist2(m, n) < MIN_SPACING_SQ then dup = true; break end
            end
            if not dup then nodes[#nodes + 1] = {x = m.x, y = m.y} end
        end
        if #nodes == 1 then
            local n = nodes[1]
            return { frontline_segments = {
                { {x = n.x, y = n.y - 8000}, {x = n.x, y = n.y + 8000} }
            } }
        end

        local start_i = 1
        for i = 2, #nodes do
            local n, s = nodes[i], nodes[start_i]
            if n.x < s.x or (n.x == s.x and n.y < s.y) then start_i = i end
        end

        local used = {}
        local path = { nodes[start_i] }
        used[start_i] = true
        for _ = 2, #nodes do
            local last = path[#path]
            local best, best_i = math.huge, nil
            for i = 1, #nodes do
                if not used[i] then
                    local d = dist2(last, nodes[i])
                    if d < best then best, best_i = d, i end
                end
            end
            if not best_i then break end
            used[best_i] = true
            path[#path + 1] = nodes[best_i]
        end

        local frontline_segments = {}
        for i = 1, #path - 1 do
            frontline_segments[#frontline_segments + 1] = {
                {x = path[i].x,     y = path[i].y},
                {x = path[i + 1].x, y = path[i + 1].y}
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
