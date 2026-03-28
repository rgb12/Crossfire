Frontline = {}

function Frontline.computeFrontline()
    local data_points = {}
    -- Create the list of points
    for _,zone in ipairs(zones) do
        if zone.side ~= coalition.side.NEUTRAL then
            table.insert(data_points, {
                x = zone.zone.point.x,
                y = zone.zone.point.z,
                coalition = zone.side
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

    -- For each triangle, see if an edge has blue and red
    -- Draw the frontline as segments connecting mixed-edge midpoints.
    local delaunay_triangles = computeBoywerWatson(data_points)
    local frontline_points = {}
    local frontline_segments = {}

    for _, triangle in ipairs(delaunay_triangles) do
        local edges = triangleEdges(triangle)
        local mixed_edge_midpoints = {}

        for _, point_edges in ipairs(edges) do
            local point1 = point_edges[1]
            local point2 = point_edges[2]

            if getPointCoalition(point1) ~= getPointCoalition(point2) then
                local midpoint = {
                    x = (point1.x + point2.x) / 2,
                    y = (point1.y + point2.y) / 2
                }
                table.insert(mixed_edge_midpoints, midpoint)
                table.insert(frontline_points, midpoint)
            end
        end

        -- In a triangle crossing coalition boundaries, there are usually 2 mixed edges.
        if #mixed_edge_midpoints == 2 then
            table.insert(frontline_segments, {
                mixed_edge_midpoints[1],
                mixed_edge_midpoints[2]
            })
        end
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
        trigger.action.lineToAll(-1, mark_id, utils.toVec3(p1), utils.toVec3(p2), {1,0,0,1}, 4, true)
        table.insert(Frontline.mark_ids, mark_id)
    end

    Frontline.mark_id = Frontline.mark_ids[#Frontline.mark_ids]
    MissionLogger:info("FRONTLINE: Frontline drawn")
end