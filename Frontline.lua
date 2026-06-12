Frontline = {}

-- Frontline rendering via clipped Voronoi cells.
--
-- For every non-neutral zone we build its Voronoi cell exactly, by clipping a
-- padded bounding rectangle against the perpendicular-bisector half-plane of
-- every other zone. The frontline is then every cell edge that borders a cell
-- of the opposing coalition.
--
-- Robustness:
--   * No circumcenters, so skinny/obtuse triangles around coastal or isolated
--     zones can no longer fling stray segments across the map.
--   * Each opposing border is collected per unordered zone pair and emitted
--     once. A real Voronoi edge survives in BOTH neighbouring cells; an edge
--     that only appears in one cell (numeric noise, premature pruning) is
--     discarded, which removes the stray "artifact" lines.
--   * An isolated zone deep in enemy territory is bordered by enemy cells on
--     all sides, so the union of its opposing-border edges is a closed polygon
--     that surrounds it.

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

    -- Initial cell: the padded bounding rectangle. Cells are stored as an
    -- unordered bag of edges; each edge remembers which site's bisector
    -- created it (tag), or nil for the outer rectangle. Convexity guarantees
    -- each half-plane clip removes one chunk and adds exactly one new edge.
    local function newBoundsCell()
        return {
            {ax = bounds.min_x, ay = bounds.min_y, bx = bounds.max_x, by = bounds.min_y, tag = nil},
            {ax = bounds.max_x, ay = bounds.min_y, bx = bounds.max_x, by = bounds.max_y, tag = nil},
            {ax = bounds.max_x, ay = bounds.max_y, bx = bounds.min_x, by = bounds.max_y, tag = nil},
            {ax = bounds.min_x, ay = bounds.max_y, bx = bounds.min_x, by = bounds.min_y, tag = nil}
        }
    end

    local CLIP_EPS = 0.01 -- meters; half-planes are normalized so d() is a distance

    -- Clip a convex cell (edge bag) against the half-plane nx*x + ny*y <= c.
    -- (nx, ny) must be unit length. New edges created on the clip line are
    -- tagged with the index of the site whose bisector this is.
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

    -- Build each zone's full Voronoi cell by clipping against EVERY other site.
    -- No early-break: correctness over speed. Zone counts here are small (tens),
    -- and skipping clips was the source of half-built cells whose stray
    -- bisector edges leaked across the map.
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

    -- For every cell, gather the (sub)segments that were created by an opposing
    -- neighbour's bisector, keyed by the unordered zone pair. A genuine Voronoi
    -- border appears in both neighbouring cells; we require that reciprocity so
    -- numeric noise cannot produce a one-sided stray line.
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

    -- Emit the border for each opposing pair that was witnessed by BOTH cells.
    -- Use the recorded sub-segments from one side; reciprocity from the other
    -- side is the validity check that suppresses artifacts.
    for key, bucket in pairs(seen) do
        local meta = pair_meta[key]
        local a_segs = bucket[meta[1]]
        local b_segs = bucket[meta[2]]
        if a_segs and b_segs then
            for _, s in ipairs(a_segs) do
                local p1 = {x = s.ax, y = s.ay}
                local p2 = {x = s.bx, y = s.by}
                table.insert(frontline_segments, {p1, p2})
                table.insert(frontline_points, p1)
                table.insert(frontline_points, p2)
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
