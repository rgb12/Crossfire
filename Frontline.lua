Frontline = {}
do
    local function circumcentre(a, b, c)
        local ax, ay, bx, by, cx, cy = a.x, a.y, b.x, b.y, c.x, c.y
        local d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        if d > -1e-6 and d < 1e-6 then return nil end
        local a2 = ax * ax + ay * ay
        local b2 = bx * bx + by * by
        local c2 = cx * cx + cy * cy
        local ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
        local uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
        return ux, uy
    end

    local function triangulate(pts)
        local n = #pts
        if n < 3 then return {} end

        -- Super-triangle large enough to contain every point.
        local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
        for _, p in ipairs(pts) do
            if p.x < minx then minx = p.x end
            if p.y < miny then miny = p.y end
            if p.x > maxx then maxx = p.x end
            if p.y > maxy then maxy = p.y end
        end
        local dx, dy = maxx - minx, maxy - miny
        local dmax = (dx > dy and dx or dy)
        if dmax <= 0 then dmax = 1 end
        local midx, midy = (minx + maxx) * 0.5, (miny + maxy) * 0.5
        -- Super-triangle vertices appended to a working copy of pts.
        local work = {}
        for i = 1, n do work[i] = pts[i] end
        work[n + 1] = {x = midx - 20 * dmax, y = midy - dmax}
        work[n + 2] = {x = midx,             y = midy + 20 * dmax}
        work[n + 3] = {x = midx + 20 * dmax, y = midy - dmax}

        local function makeTri(i1, i2, i3)
            local cx, cy = circumcentre(work[i1], work[i2], work[i3])
            if not cx then return nil end
            local ddx, ddy = work[i1].x - cx, work[i1].y - cy
            return {i1, i2, i3, cx = cx, cy = cy, r2 = ddx * ddx + ddy * ddy}
        end

        local super = makeTri(n + 1, n + 2, n + 3)
        if not super then return {} end
        local tris = { super }

        for i = 1, n do
            local p = work[i]
            local bad = {}
            for ti = #tris, 1, -1 do
                local t = tris[ti]
                local ex, ey = p.x - t.cx, p.y - t.cy
                if ex * ex + ey * ey <= t.r2 then
                    bad[#bad + 1] = t
                    table.remove(tris, ti)
                end
            end
            local edge_count = {}
            local edge_list = {}
            local function addEdge(u, v)
                local lo, hi = u, v
                if lo > hi then lo, hi = hi, lo end
                local key = lo * 1000000 + hi
                if edge_count[key] then
                    edge_count[key] = edge_count[key] + 1
                else
                    edge_count[key] = 1
                    edge_list[#edge_list + 1] = {lo, hi, key}
                end
            end
            for _, t in ipairs(bad) do
                addEdge(t[1], t[2]); addEdge(t[2], t[3]); addEdge(t[3], t[1])
            end
            for _, e in ipairs(edge_list) do
                if edge_count[e[3]] == 1 then
                    local nt = makeTri(e[1], e[2], i)
                    if nt then tris[#tris + 1] = nt end
                end
            end
        end

        -- Drop any triangle still touching a super-triangle vertex.
        local result = {}
        for _, t in ipairs(tris) do
            if t[1] <= n and t[2] <= n and t[3] <= n then
                result[#result + 1] = t
            end
        end
        return result
    end

    function Frontline.computeFrontline()
        local empty_result = { frontline_segments = {} }

        local pts, sides = {}, {}
        for _, zone in ipairs(zones) do
            local s = zone.side
            if s == coalition.side.RED or s == coalition.side.BLUE then
                pts[#pts + 1] = {x = zone.zone.point.x, y = zone.zone.point.z}
                sides[#pts] = s
            end
        end

        -- A frontline only exists if both coalitions are present.
        local n_red, n_blue = 0, 0
        for _, s in ipairs(sides) do
            if s == coalition.side.RED then n_red = n_red + 1 else n_blue = n_blue + 1 end
        end
        if n_red == 0 or n_blue == 0 then
            return empty_result
        end

        local CONTACT_RANGE = Config.frontline_contact_range or 80000
        local CONTACT_RANGE_SQ = CONTACT_RANGE * CONTACT_RANGE
        local function dist2(a, b)
            local ddx, ddy = a.x - b.x, a.y - b.y
            return ddx * ddx + ddy * ddy
        end

        local frontline_segments = {}

        if #pts < 3 then
            local best, br, bb = math.huge, nil, nil
            for i = 1, #pts do
                for j = i + 1, #pts do
                    if sides[i] ~= sides[j] then
                        local d = dist2(pts[i], pts[j])
                        if d < best then best, br, bb = d, pts[i], pts[j] end
                    end
                end
            end
            if br and bb then
                local mx, my = (br.x + bb.x) * 0.5, (br.y + bb.y) * 0.5
                local vx, vy = bb.x - br.x, bb.y - br.y
                local len = math.sqrt(vx * vx + vy * vy)
                if len > 1 then
                    local nx, ny = -vy / len, vx / len
                    frontline_segments[1] = {
                        {x = mx - nx * 8000, y = my - ny * 8000},
                        {x = mx + nx * 8000, y = my + ny * 8000}
                    }
                end
            end
            if #frontline_segments == 0 then return empty_result end
            return { frontline_segments = frontline_segments }
        end

        local tris = triangulate(pts)

        local edge_tris = {}
        local function edgeKey(u, v)
            if u > v then u, v = v, u end
            return u * 1000000 + v, u, v
        end
        local function recordEdge(u, v, cx, cy, apex)
            local key, lo, hi = edgeKey(u, v)
            local e = edge_tris[key]
            if not e then
                e = {lo, hi, {x = cx, y = cy}}
                e[5] = apex
                edge_tris[key] = e
            else
                e[4] = {x = cx, y = cy}
            end
        end
        for _, t in ipairs(tris) do
            recordEdge(t[1], t[2], t.cx, t.cy, t[3])
            recordEdge(t[2], t[3], t.cx, t.cy, t[1])
            recordEdge(t[3], t[1], t.cx, t.cy, t[2])
        end

        for _, e in pairs(edge_tris) do
            local u, v = e[1], e[2]
            if sides[u] ~= sides[v] and dist2(pts[u], pts[v]) <= CONTACT_RANGE_SQ then
                local c1, c2 = e[3], e[4]
                if c2 then
                    -- Interior edge: full Voronoi segment between both circumcentres.
                    frontline_segments[#frontline_segments + 1] = {
                        {x = c1.x, y = c1.y}, {x = c2.x, y = c2.y}
                    }
                else
                    local a, b = pts[u], pts[v]
                    local apex = pts[e[5]]
                    -- Unit normal to edge (a,b).
                    local nx, ny = -(b.y - a.y), (b.x - a.x)
                    local nlen = math.sqrt(nx * nx + ny * ny)
                    if nlen > 1 then
                        nx, ny = nx / nlen, ny / nlen
                        -- Flip to point away from the apex (the interior side).
                        local mx, my = (a.x + b.x) * 0.5, (a.y + b.y) * 0.5
                        if (apex.x - mx) * nx + (apex.y - my) * ny > 0 then
                            nx, ny = -nx, -ny
                        end
                        local ext = 20000
                        frontline_segments[#frontline_segments + 1] = {
                            {x = c1.x, y = c1.y},
                            {x = c1.x + nx * ext, y = c1.y + ny * ext}
                        }
                    end
                end
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
