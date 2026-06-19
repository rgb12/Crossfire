Frontline = {}
do

    function Frontline.computeFrontline()
        local data_points = {}
        -- Create the list of points
        for _, zone in ipairs(zones) do
            if zone.side ~= coalition.side.NEUTRAL then
                table.insert(data_points, {
                    x = zone.zone.point.x,
                    y = zone.zone.point.z,
                    coalition = zone.side,
                    zone_name = zone.name or zone.zone.name,
                    zone_ref = zone
                })
            end
        end

        local empty_result = {
            triangles = {},
            frontline_points = {},
            frontline_segments = {}
        }

        if #data_points < 2 then
            return empty_result
        end

        -- A frontline only exists if both coalitions are present.
        local has_blue = false
        local has_red = false
        for _, p in ipairs(data_points) do
            if p.coalition == coalition.side.BLUE then has_blue = true end
            if p.coalition == coalition.side.RED then has_red = true end
        end
        if not (has_blue and has_red) then
            return empty_result
        end

        local function computeFrontlineBounds(points)
            local x_coords = {}
            local y_coords = {}
            for _, p in ipairs(points) do
                table.insert(x_coords, p.x)
                table.insert(y_coords, p.y)
            end

            local min_x, max_x = utils.tableMin(x_coords), utils.tableMax(x_coords)
            local min_y, max_y = utils.tableMin(y_coords), utils.tableMax(y_coords)
            local dx = math.max(max_x - min_x, 1)
            local dy = math.max(max_y - min_y, 1)
            -- Generous padding so a peripheral/isolated zone's cell is still closed
            -- by the bounding rectangle rather than running off to infinity.
            local padding = math.max(dx, dy) * 0.5

            return {
                min_x = min_x - padding,
                max_x = max_x + padding,
                min_y = min_y - padding,
                max_y = max_y + padding
            }
        end

        local bounds = computeFrontlineBounds(data_points)

        local function newBoundsCell()
            return {
                {ax = bounds.min_x, ay = bounds.min_y, bx = bounds.max_x, by = bounds.min_y, tag = nil},
                {ax = bounds.max_x, ay = bounds.min_y, bx = bounds.max_x, by = bounds.max_y, tag = nil},
                {ax = bounds.max_x, ay = bounds.max_y, bx = bounds.min_x, by = bounds.max_y, tag = nil},
                {ax = bounds.min_x, ay = bounds.max_y, bx = bounds.min_x, by = bounds.min_y, tag = nil}
            }
        end

        local CLIP_EPS = 0.01 -- meters; half-planes are normalized so d() is a distance

        local function clipCellHalfPlane(edges, nx, ny, c, tag)
            local out = {}
            local exit_x, exit_y, entry_x, entry_y

            for i = 1, #edges do
                local e = edges[i]
                local da = nx * e.ax + ny * e.ay - c
                local db = nx * e.bx + ny * e.by - c
                local a_in = da <= CLIP_EPS
                local b_in = db <= CLIP_EPS

                if a_in and b_in then
                    table.insert(out, e)
                elseif a_in and not b_in then
                    -- Leaving the half-plane: keep the inner part, remember exit.
                    local t = da / (da - db)
                    local ix = e.ax + (e.bx - e.ax) * t
                    local iy = e.ay + (e.by - e.ay) * t
                    table.insert(out, {ax = e.ax, ay = e.ay, bx = ix, by = iy, tag = e.tag})
                    exit_x, exit_y = ix, iy
                elseif (not a_in) and b_in then
                    -- Entering the half-plane: keep the inner part, remember entry.
                    local t = da / (da - db)
                    local ix = e.ax + (e.bx - e.ax) * t
                    local iy = e.ay + (e.by - e.ay) * t
                    table.insert(out, {ax = ix, ay = iy, bx = e.bx, by = e.by, tag = e.tag})
                    entry_x, entry_y = ix, iy
                end
                -- both outside: edge dropped
            end

            if exit_x and entry_x then
                local dx = entry_x - exit_x
                local dy = entry_y - exit_y
                if (dx * dx + dy * dy) > (CLIP_EPS * CLIP_EPS) then
                    table.insert(out, {ax = exit_x, ay = exit_y, bx = entry_x, by = entry_y, tag = tag})
                end
            end

            return out
        end

        local function buildCell(site_index)
            local site = data_points[site_index]
            local edges = newBoundsCell()

            for j = 1, #data_points do
                if j ~= site_index then
                    local other = data_points[j]
                    local dx = other.x - site.x
                    local dy = other.y - site.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist > CLIP_EPS then
                        -- Half-plane "closer to site than to other": unit normal
                        -- toward other, boundary through the midpoint.
                        local nx = dx / dist
                        local ny = dy / dist
                        local mid_x = (site.x + other.x) * 0.5
                        local mid_y = (site.y + other.y) * 0.5
                        local c = nx * mid_x + ny * mid_y
                        edges = clipCellHalfPlane(edges, nx, ny, c, j)
                    end
                end
            end

            return edges
        end


        local seen = {}        -- pair_key -> { side_index -> list of {ax,ay,bx,by} }
        local pair_meta = {}   -- pair_key -> { i, j }

        local MIN_FRAGMENT_LEN_SQ = CLIP_EPS * CLIP_EPS

        for i = 1, #data_points do
            local site = data_points[i]
            local edges = buildCell(i)
            for _, e in ipairs(edges) do
                local j = e.tag
                if j then
                    local other = data_points[j]
                    if other.coalition ~= site.coalition then
                        local dx = e.bx - e.ax
                        local dy = e.by - e.ay
                        if (dx * dx + dy * dy) >= MIN_FRAGMENT_LEN_SQ then
                            local lo = math.min(i, j)
                            local hi = math.max(i, j)
                            local key = lo .. ":" .. hi
                            local bucket = seen[key]
                            if not bucket then
                                bucket = {}
                                seen[key] = bucket
                                pair_meta[key] = {lo, hi}
                            end
                            local side_list = bucket[i]
                            if not side_list then
                                side_list = {}
                                bucket[i] = side_list
                            end
                            table.insert(side_list, {ax = e.ax, ay = e.ay, bx = e.bx, by = e.by})
                        end
                    end
                end
            end
        end

        local frontline_points = {}
        local frontline_segments = {}

        local MAX_FRONTLINE_EXTENT = Config.frontline_max_extent or 35000

        local MERGE_GAP = 1.0

        for key, bucket in pairs(seen) do
            local meta = pair_meta[key]
            local a_segs = bucket[meta[1]]
            local b_segs = bucket[meta[2]]
            if a_segs and b_segs then
                local za = data_points[meta[1]]
                local zb = data_points[meta[2]]
                local mid_x = (za.x + zb.x) * 0.5
                local mid_y = (za.y + zb.y) * 0.5
                local jdx = zb.x - za.x
                local jdy = zb.y - za.y
                local jlen = math.sqrt(jdx * jdx + jdy * jdy)
                local nx, ny = 1, 0
                if jlen > CLIP_EPS then nx, ny = jdx / jlen, jdy / jlen end
                -- tangent: direction along the bisector
                local tx, ty = -ny, nx

                local function proj(px, py)
                    return (px - mid_x) * tx + (py - mid_y) * ty
                end

                -- Collect 1-D intervals from both cells' fragments.
                local intervals = {}
                local function addSegs(segs)
                    if not segs then return end
                    for _, s in ipairs(segs) do
                        local s1 = proj(s.ax, s.ay)
                        local s2 = proj(s.bx, s.by)
                        if s1 > s2 then s1, s2 = s2, s1 end
                        intervals[#intervals + 1] = {s1, s2}
                    end
                end
                addSegs(a_segs)
                addSegs(b_segs)

                if #intervals > 0 then
                    table.sort(intervals, function(p, q) return p[1] < q[1] end)

                    -- Merge overlapping / near-touching intervals into spans.
                    local merged = {}
                    local cur = {intervals[1][1], intervals[1][2]}
                    for i = 2, #intervals do
                        local iv = intervals[i]
                        if iv[1] <= cur[2] + MERGE_GAP then
                            if iv[2] > cur[2] then cur[2] = iv[2] end
                        else
                            merged[#merged + 1] = cur
                            cur = {iv[1], iv[2]}
                        end
                    end
                    merged[#merged + 1] = cur

                    for _, span in ipairs(merged) do
                        -- Clip span to [-ext, ext] along the bisector.
                        local s1 = math.max(span[1], -MAX_FRONTLINE_EXTENT)
                        local s2 = math.min(span[2],  MAX_FRONTLINE_EXTENT)
                        if s2 - s1 >= 5 then -- ignore spans shorter than 5 m
                            local p1 = {x = mid_x + tx * s1, y = mid_y + ty * s1}
                            local p2 = {x = mid_x + tx * s2, y = mid_y + ty * s2}
                            table.insert(frontline_segments, {p1, p2})
                            table.insert(frontline_points, p1)
                            table.insert(frontline_points, p2)
                        end
                    end
                end
            end
        end

        return {
            triangles = {},
            frontline_points = frontline_points,
            frontline_segments = frontline_segments
        }
    end

    Frontline.mark_id = nil
    Frontline.mark_ids = nil

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
        Frontline.clearFrontline()

        for _, segment in ipairs(frontline_data.frontline_segments) do
            local p1 = segment[1]
            local p2 = segment[2]

            local mark_id = nextMarkId()
            trigger.action.lineToAll(-1, mark_id, utils.toVec3(p1), utils.toVec3(p2), Config.draw_color_palette.frontline_color, Config.draw_color_palette.frontline_linestyle, true)

            table.insert(Frontline.mark_ids, mark_id)
        end

        Frontline.mark_id = Frontline.mark_ids[#Frontline.mark_ids]
        MissionLogger:info("FRONTLINE: Frontline drawn")
    end
end
