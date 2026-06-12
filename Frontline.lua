Frontline = {}

function Frontline.computeFrontline()
    local data_points = {}
    -- Create the list of points
    for _,zone in ipairs(zones) do
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

    if #data_points < 3 then
        return {
            triangles = {},
            frontline_points = {},
            frontline_segments = {}
        }
    end

    local function superTriangle(points)
        local x_coords = {}
        local y_coords = {}
        for _, p in ipairs(points) do
            table.insert(x_coords, p.x)
            table.insert(y_coords, p.y)
        end

        local min_x, max_x = utils.tableMin(x_coords), utils.tableMax(x_coords)
        local min_y, max_y = utils.tableMin(y_coords), utils.tableMax(y_coords)

        local dx = max_x - min_x
        local dy = max_y - min_y
        local d = math.max(dx, dy) * 10
        local mid_x = (min_x + max_x) / 2
        local mid_y = (min_y + max_y) / 2

        local p1 = {x = mid_x - 2 * d, y = mid_y - d}
        local p2 = {x = mid_x + 2 * d, y = mid_y - d}
        local p3 = {x = mid_x,         y = mid_y + 2 * d}

        return {p1, p2, p3}
    end

    local function isPointInsideCircumcircle(point, triangle)
        if #triangle ~= 3 then return false end

        local px, py = point.x, point.y
        local x1, y1 = triangle[1].x, triangle[1].y
        local x2, y2 = triangle[2].x, triangle[2].y
        local x3, y3 = triangle[3].x, triangle[3].y

        local ax, ay = x1 - px, y1 - py
        local bx, by = x2 - px, y2 - py
        local cx, cy = x3 - px, y3 - py

        local det = (ax * ax + ay * ay) * (bx * cy - by * cx) -
                    (bx * bx + by * by) * (ax * cy - ay * cx) +
                    (cx * cx + cy * cy) * (ax * by - ay * bx)

        local orient = (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)
        if orient > 0 then
            return det > 1e-12
        end
        return det < -1e-12
    end

    local function triangleEdges(triangle)
        return {
            {triangle[1], triangle[2]},
            {triangle[2], triangle[3]},
            {triangle[3], triangle[1]}
        }
    end

    local function pointLess(a, b)
        return (a.x < b.x) or (a.x == b.x and a.y < b.y)
    end

    local function samePoint(a, b)
        return a.x == b.x and a.y == b.y
    end

    local function makeEdgeKey(edge)
        local a = edge[1]
        local b = edge[2]
        if pointLess(b, a) then
            a, b = b, a
        end
        return {a.x, a.y, b.x, b.y}
    end

    local function edgeKeyEquals(k1, k2)
        return k1[1] == k2[1] and k1[2] == k2[2]
            and k1[3] == k2[3] and k1[4] == k2[4]
    end

    local function addOrIncrementEdge(edge_stats, edge)
        local key = makeEdgeKey(edge)
        for i = 1, #edge_stats do
            local rec = edge_stats[i]
            if edgeKeyEquals(rec.key, key) then
                rec.count = rec.count + 1
                return
            end
        end

        table.insert(edge_stats, {
            key = key,
            edge = edge,
            count = 1
        })
    end

    local function pointInSuperTriangle(super_triangle, p)
        for i = 1, #super_triangle do
            if samePoint(super_triangle[i], p) then
                return true
            end
        end
        return false
    end


    local function computeBoywerWatson(points)
        local coords = {}
        for _, p in ipairs(points) do
            table.insert(coords, {x = p.x, y = p.y, coalition = p.coalition})
        end

        local super_triangle = superTriangle(coords)
        local triangles = {super_triangle}

        for _, point in ipairs(coords) do
            local bad_triangles = {}
            for _, triangle in ipairs(triangles) do
                if isPointInsideCircumcircle(point, triangle) then
                    table.insert(bad_triangles, triangle)
                end
            end

            local edge_stats = {}
            for _, triangle in ipairs(bad_triangles) do
                local edges = triangleEdges(triangle)
                for _, edge in ipairs(edges) do
                    addOrIncrementEdge(edge_stats, edge)
                end
            end

            local polygon = {}
            for _, rec in ipairs(edge_stats) do
                if rec.count == 1 then
                    table.insert(polygon, rec.edge)
                end
            end

            local kept = {}
            for _, tri in ipairs(triangles) do
                local is_bad = false
                for _, bad_tri in ipairs(bad_triangles) do
                    if tri == bad_tri then
                        is_bad = true
                        break
                    end
                end
                if not is_bad then
                    table.insert(kept, tri)
                end
            end
            triangles = kept

            for _, edge in ipairs(polygon) do
                local v1 = {x = edge[1].x, y = edge[1].y}
                local v2 = {x = edge[2].x, y = edge[2].y}
                table.insert(triangles, {v1, v2, point})
            end
        end

        local final_triangles = {}
        for _, tri in ipairs(triangles) do
            local touches_super = false
            for i = 1, 3 do
                if pointInSuperTriangle(super_triangle, tri[i]) then
                    touches_super = true
                    break
                end
            end
            if not touches_super then
                table.insert(final_triangles, tri)
            end
        end

        return final_triangles
    end

    local function getPointCoalition(point)
        for _, p in ipairs(data_points) do
            if p.x == point.x and p.y == point.y then
                return p.coalition
            end
        end
        return nil
    end

    local function distance2D(a, b)
        local dx = a.x - b.x
        local dy = a.y - b.y
        return math.sqrt(dx * dx + dy * dy)
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
        local padding = math.max(dx, dy) * 0.15

        return {
            min_x = min_x - padding,
            max_x = max_x + padding,
            min_y = min_y - padding,
            max_y = max_y + padding
        }
    end

    local function clipSegmentToBounds(point1, point2, bounds)
        local x0, y0 = point1.x, point1.y
        local x1, y1 = point2.x, point2.y
        local dx = x1 - x0
        local dy = y1 - y0

        local t0 = 0
        local t1 = 1

        local function clipTest(p, q)
            if p == 0 then
                return q >= 0
            end

            local r = q / p
            if p < 0 then
                if r > t1 then
                    return false
                end
                if r > t0 then
                    t0 = r
                end
            else
                if r < t0 then
                    return false
                end
                if r < t1 then
                    t1 = r
                end
            end

            return true
        end

        if not clipTest(-dx, x0 - bounds.min_x) then return nil, nil end
        if not clipTest(dx, bounds.max_x - x0) then return nil, nil end
        if not clipTest(-dy, y0 - bounds.min_y) then return nil, nil end
        if not clipTest(dy, bounds.max_y - y0) then return nil, nil end

        local clipped1 = {
            x = x0 + t0 * dx,
            y = y0 + t0 * dy
        }
        local clipped2 = {
            x = x0 + t1 * dx,
            y = y0 + t1 * dy
        }

        return clipped1, clipped2
    end

    local function computeCircumcenter(triangle)
        local x1, y1 = triangle[1].x, triangle[1].y
        local x2, y2 = triangle[2].x, triangle[2].y
        local x3, y3 = triangle[3].x, triangle[3].y

        local centroid = {
            x = (x1 + x2 + x3) / 3,
            y = (y1 + y2 + y3) / 3
        }

        local d = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        if math.abs(d) < 1e-9 then
            return centroid
        end

        local ux = ((x1 * x1 + y1 * y1) * (y2 - y3) +
                    (x2 * x2 + y2 * y2) * (y3 - y1) +
                    (x3 * x3 + y3 * y3) * (y1 - y2)) / d

        local uy = ((x1 * x1 + y1 * y1) * (x3 - x2) +
                    (x2 * x2 + y2 * y2) * (x1 - x3) +
                    (x3 * x3 + y3 * y3) * (x2 - x1)) / d

        return {x = ux, y = uy}
    end

    -- Returns the circumcenter of a triangle, clamped so it stays within
    -- max_radius of the triangle centroid. Used to prevent far-circumcenter
    -- artifacts from obtuse triangles while still drawing a frontline segment.
    local function computeClampedCircumcenter(triangle, max_radius)
        local centroid = {
            x = (triangle[1].x + triangle[2].x + triangle[3].x) / 3,
            y = (triangle[1].y + triangle[2].y + triangle[3].y) / 3
        }
        local cc = computeCircumcenter(triangle)
        local dist = distance2D(cc, centroid)
        if dist > max_radius then
            local scale = max_radius / dist
            return {
                x = centroid.x + (cc.x - centroid.x) * scale,
                y = centroid.y + (cc.y - centroid.y) * scale
            }
        end
        return cc
    end

    local function addTriangleToEdgeMap(edge_triangle_map, edge, triangle_index)
        local key = makeEdgeKey(edge)
        for i = 1, #edge_triangle_map do
            local rec = edge_triangle_map[i]
            if edgeKeyEquals(rec.key, key) then
                table.insert(rec.triangles, triangle_index)
                return
            end
        end

        table.insert(edge_triangle_map, {
            key = key,
            edge = edge,
            triangles = {triangle_index}
        })
    end

    local function pointKey(point)
        return tostring(point.x) .. ":" .. tostring(point.y)
    end

    local function buildAdjacency(triangles, points)
        local index_by_key = {}
        for i, p in ipairs(points) do
            index_by_key[pointKey(p)] = i
        end

        local adjacency = {}
        for i = 1, #points do
            adjacency[i] = {}
        end

        for _, triangle in ipairs(triangles) do
            local edges = triangleEdges(triangle)
            for _, edge in ipairs(edges) do
                local key1 = pointKey(edge[1])
                local key2 = pointKey(edge[2])
                local i1 = index_by_key[key1]
                local i2 = index_by_key[key2]
                if i1 and i2 then
                    if points[i1].coalition == points[i2].coalition then
                        table.insert(adjacency[i1], i2)
                        table.insert(adjacency[i2], i1)
                    end
                end
            end
        end

        return adjacency
    end

    local function findBaseIndex(base_zone, points)
        if not base_zone then return nil end
        for i, p in ipairs(points) do
            if p.zone_ref == base_zone then
                return i
            end
        end
        if base_zone.name then
            for i, p in ipairs(points) do
                if p.zone_name == base_zone.name then
                    return i
                end
            end
        end
        return nil
    end

    local function collectConnected(start_index, side, adjacency, points)
        local visited = {}
        if not start_index then
            return visited
        end

        local stack = {start_index}
        visited[start_index] = true

        while #stack > 0 do
            local idx = table.remove(stack)
            for _, neighbor in ipairs(adjacency[idx] or {}) do
                if not visited[neighbor] and points[neighbor].coalition == side then
                    visited[neighbor] = true
                    table.insert(stack, neighbor)
                end
            end
        end

        return visited
    end

    -- Build frontline from Voronoi edges dual to mixed Delaunay edges.
    local delaunay_triangles = computeBoywerWatson(data_points)
    local adjacency = buildAdjacency(delaunay_triangles, data_points)

    local blue_base_index = findBaseIndex(blue_airbase, data_points)
    local red_base_index = findBaseIndex(red_airbase, data_points)
    local blue_connected = collectConnected(blue_base_index, coalition.side.BLUE, adjacency, data_points)
    local red_connected = collectConnected(red_base_index, coalition.side.RED, adjacency, data_points)

    local filtered_points = {}
    for i, p in ipairs(data_points) do
        if blue_connected[i] or red_connected[i] then
            table.insert(filtered_points, p)
        end
    end

    if #filtered_points >= 3 then
        data_points = filtered_points
        delaunay_triangles = computeBoywerWatson(data_points)
    end
    local frontline_points = {}
    local frontline_segments = {}
    local triangle_circumcenters = {}
    local edge_triangle_map = {}
    local frontline_bounds = computeFrontlineBounds(data_points)

    -- Clamp radius: circumcenters further than this from their triangle centroid
    -- are pulled back in. Sized to the data extent so isolated-zone maps don't
    -- produce runaway rays while still letting the frontline span the whole map.
    local dx = frontline_bounds.max_x - frontline_bounds.min_x
    local dy = frontline_bounds.max_y - frontline_bounds.min_y
    local clamp_radius = math.max(dx, dy) * 0.75

    for triangle_index, triangle in ipairs(delaunay_triangles) do
        triangle_circumcenters[triangle_index] = computeClampedCircumcenter(triangle, clamp_radius)

        local edges = triangleEdges(triangle)
        for _, edge in ipairs(edges) do
            addTriangleToEdgeMap(edge_triangle_map, edge, triangle_index)
        end
    end

    for _, rec in ipairs(edge_triangle_map) do
        local point1 = rec.edge[1]
        local point2 = rec.edge[2]
        local coalition1 = getPointCoalition(point1)
        local coalition2 = getPointCoalition(point2)

        if not (coalition1 and coalition2 and coalition1 ~= coalition2) then
            goto continue
        end

        if #rec.triangles == 2 then
            local center1 = triangle_circumcenters[rec.triangles[1]]
            local center2 = triangle_circumcenters[rec.triangles[2]]

            if center1 and center2 and not samePoint(center1, center2) then
                local clipped1, clipped2 = clipSegmentToBounds(center1, center2, frontline_bounds)
                if clipped1 and clipped2 and not samePoint(clipped1, clipped2) then
                    table.insert(frontline_segments, {clipped1, clipped2})
                    table.insert(frontline_points, clipped1)
                    table.insert(frontline_points, clipped2)
                end
            end
        elseif #rec.triangles == 1 then
            -- Hull edge: one open Voronoi ray. Extend from the single circumcenter
            -- outward along the perpendicular bisector of the edge to the bounds.
            local center = triangle_circumcenters[rec.triangles[1]]
            if center then
                local mid = {
                    x = (point1.x + point2.x) / 2,
                    y = (point1.y + point2.y) / 2
                }
                -- Direction away from circumcenter along the perpendicular
                local ex = center.x - mid.x
                local ey = center.y - mid.y
                local elen = math.sqrt(ex * ex + ey * ey)
                if elen > 1e-6 then
                    -- Ray endpoint: push far enough to always reach the clip bounds
                    local ray_len = math.max(dx, dy) * 2
                    local ray_end = {
                        x = mid.x - (ex / elen) * ray_len,
                        y = mid.y - (ey / elen) * ray_len
                    }
                    local clipped1, clipped2 = clipSegmentToBounds(center, ray_end, frontline_bounds)
                    if clipped1 and clipped2 and not samePoint(clipped1, clipped2) then
                        table.insert(frontline_segments, {clipped1, clipped2})
                        table.insert(frontline_points, clipped1)
                        table.insert(frontline_points, clipped2)
                    end
                end
            end
        end

        ::continue::
    end

    return {
        triangles = delaunay_triangles,
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
        -- trigger.action.lineToAll(-1, mark_id, utils.toVec3(p1), utils.toVec3(p2), {67/255,104/255,153/255,1}, 5, true)
        trigger.action.lineToAll(-1, mark_id, utils.toVec3(p1), utils.toVec3(p2), Config.draw_color_palette.frontline_color, Config.draw_color_palette.frontline_linestyle, true)

        table.insert(Frontline.mark_ids, mark_id)
    end

    Frontline.mark_id = Frontline.mark_ids[#Frontline.mark_ids]
    MissionLogger:info("FRONTLINE: Frontline drawn")
end