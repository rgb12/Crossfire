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

        local MIN_SEGMENT_LEN_SQ = 25 -- ignore sub-segments shorter than 5 m

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
                        if (dx * dx + dy * dy) >= MIN_SEGMENT_LEN_SQ then
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

        local function clipSegmentToExtent(ax, ay, bx, by, mid_x, mid_y, nx, ny, ext)
            -- tangent (along the bisector)
            local tx, ty = -ny, nx
            local sa = (ax - mid_x) * tx + (ay - mid_y) * ty
            local sb = (bx - mid_x) * tx + (by - mid_y) * ty

            if (sa > ext and sb > ext) or (sa < -ext and sb < -ext) then
                return nil
            end

            local t0, t1 = 0.0, 1.0
            local d = sb - sa
            if math.abs(d) > 1e-9 then
                local tlo = (-ext - sa) / d
                local thi = ( ext - sa) / d
                if tlo > thi then tlo, thi = thi, tlo end
                if tlo > t0 then t0 = tlo end
                if thi < t1 then t1 = thi end
            end
            if t0 > t1 then return nil end

            local nax = ax + (bx - ax) * t0
            local nay = ay + (by - ay) * t0
            local nbx = ax + (bx - ax) * t1
            local nby = ay + (by - ay) * t1
            return nax, nay, nbx, nby
        end

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

                for _, s in ipairs(a_segs) do
                    local nax, nay, nbx, nby = clipSegmentToExtent(
                        s.ax, s.ay, s.bx, s.by, mid_x, mid_y, nx, ny, MAX_FRONTLINE_EXTENT)
                    if nax then
                        local cdx = nbx - nax
                        local cdy = nby - nay
                        if (cdx * cdx + cdy * cdy) >= MIN_SEGMENT_LEN_SQ then
                            local p1 = {x = nax, y = nay}
                            local p2 = {x = nbx, y = nby}
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
