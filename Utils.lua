utils = {}

utils.LineStyle = {
    NONE = 0,
    SOLID = 1,
    DASHED = 2,
    DOTTED = 3,
    DOT_DASH = 4,
    LONG_DASH = 5,
    TWO_DASH = 6,
}
---@param tbl table
---@param value any
---@return any|nil
function utils.indexOf(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

function utils.startsWith(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

---@param position vec3|vec2
---@return ZoneHandler|nil
function utils.getZoneOfUnitFromPosition(position)
    for i, zone in ipairs(zones) do
        if zone:isPointInsideZone(position) then
            return zone
        end
    end
    return nil
end

-- Fisher-Yates Shuffle
---@param t table
---@return table
function utils.shuffleTable(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

--- Get all alive units inside a ZoneHandler zone (circle or quad)
-- Uses BOX for quads, SPHERE for circles
---@param zone ZoneHandler Zone object
---@param coalition_filter coalition.side|nil coalition.side.RED/BLUE or nil for all
---@return Unit[]
function utils.getUnitsInZoneObj(zone, coalition_filter)
    if not zone or not zone.zone then return {} end

    local units_in_zone = {}
    local vol

    if zone:isCircle() then
        -- sphere around circle zone
        vol = {
            id = world.VolumeType.SPHERE,
            params = { point = zone.zone.point, radius = zone.zone.radius }
        }
    elseif zone:isQuad() then
        -- bounding box around quad vertices
        local minX, maxX = math.huge, -math.huge
        local minZ, maxZ = math.huge, -math.huge
        for _, v in ipairs(zone.zone.vertices) do
            if v.x < minX then minX = v.x end
            if v.x > maxX then maxX = v.x end
            if v.z < minZ then minZ = v.z end
            if v.z > maxZ then maxZ = v.z end
        end
        vol = {
            id = world.VolumeType.BOX,
            params = {
                min = { x = minX, y = -1000, z = minZ },
                max = { x = maxX, y = 99999, z = maxZ }
            }
        }
    end

    if not vol then
        MissionLogger:info("Unknown volume")
        return {} end

    world.searchObjects(Object.Category.UNIT, vol, function(obj)
        if obj and obj:isExist() and obj:isActive() then
            if not coalition_filter or obj:getCoalition() == coalition_filter then
                local pos = obj:getPoint()
                local inside = false

                if zone:isCircle() then
                    inside = mist.utils.get2DDist(pos, zone.zone.point) <= zone.zone.radius
                elseif zone:isQuad() then
                    inside = mist.pointInPolygon(pos, zone.zone.vertices)
                end
                
                if inside then
                    -- MissionLogger:info("Unit inside zone "..zone.name ..": "..obj:getName())
                    table.insert(units_in_zone, obj)
                end
            end
        end
    end)
    return units_in_zone
end

--- Get all alive statics inside a ZoneHandler zone (circle or quad)
---@param zone ZoneHandler Zone object
---@return StaticObject[]
function utils.getStaticsInZoneObj(zone)
    if not zone or not zone.zone then return {} end

    local statics_in_zone = {}
    local vol

    if zone:isCircle() then
        vol = {
            id = world.VolumeType.SPHERE,
            params = { point = zone.zone.point, radius = zone.zone.radius }
        }
    elseif zone:isQuad() then
        local minX, maxX = math.huge, -math.huge
        local minZ, maxZ = math.huge, -math.huge
        for _, v in ipairs(zone.zone.vertices) do
            if v.x < minX then minX = v.x end
            if v.x > maxX then maxX = v.x end
            if v.z < minZ then minZ = v.z end
            if v.z > maxZ then maxZ = v.z end
        end
        vol = {
            id = world.VolumeType.BOX,
            params = {
                min = { x = minX, y = -500, z = minZ },
                max = { x = maxX, y = 9999, z = maxZ }
            }
        }
    end

    if not vol then return {} end

    world.searchObjects(Object.Category.STATIC, vol, function(obj)
        if obj and obj:isExist() then
            local pos = obj:getPoint()
            local inside = false

            if zone:isCircle() then
                inside = mist.utils.get2DDist(pos, zone.zone.point) <= zone.zone.radius
            elseif zone:isQuad() then
                inside = mist.pointInPolygon(pos, zone.zone.vertices)
            end

            if inside then
                -- optional: ensure static is "intact"
                local ok, life = pcall(function() return obj:getLife() end)
                if not ok then life = 1 end
                if life == nil or life >= 1 then
                    table.insert(statics_in_zone, obj)
                end
            end
        end
    end)

    return statics_in_zone
end

---@param friendly_coalition coalition.side
---@return coalition.side
function utils.getEnemyCoalition(friendly_coalition)
    if friendly_coalition == coalition.side.BLUE then
        return coalition.side.RED
    elseif friendly_coalition == coalition.side.RED then
        return coalition.side.BLUE
    else return coalition.side.NEUTRAL end
end

---@param coalition_side coalition.side
---@return string
function utils.coalitionToString(coalition_side)
    if coalition_side == coalition.side.RED then
        return "RED"
    elseif coalition_side == coalition.side.BLUE then
        return "BLUE"
    elseif coalition_side == coalition.side.NEUTRAL then
        return "NEUTRAL"
    else
        return "UNKNOWN"
    end
end

-- center: vec3
-- minR: minimum radius from center in meter
-- maxR: maximum radius from center in meter
---@param center vec3
---@param minR number
---@param maxR number
---@return vec3
function utils.rndPointFromCenter(center, minR, maxR)
    

    local r = math.random() * (maxR - minR) + minR
    local a = math.random() * 2 * math.pi
    return { x = center.x + r * math.cos(a), y = land.getHeight({x=center.x,y=center.z}), z = center.z + r * math.sin(a) }
end

function utils.tableContains(tbl, val)
    for _, v in pairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

function utils.editCommsAntennasCount(coalition_side, delta)
    if coalition_side == coalition.side.BLUE then
        stats.blue_comms_antennas = stats.blue_comms_antennas + delta
    elseif coalition_side == coalition.side.RED then
        stats.red_comms_antennas = stats.red_comms_antennas + delta
    end
end

function utils.editAmmoDepotsCount(coalition_side, delta)
    if coalition_side == coalition.side.BLUE then
        stats.blue_ammo_depots = stats.blue_ammo_depots + delta
    elseif coalition_side == coalition.side.RED then
        stats.red_ammo_depots = stats.red_ammo_depots + delta
    end
end

function utils.calculateSuppliesCAPforCoalition(coalition_side)
    -- Legacy helper kept for backward compatibility with old call sites.
    -- The supply model is now zone-local, so coalition-wide command-post caps are retired.
    return Config.supplies.absolute_max_supplies or 0
end


---@param point vec3
---@param coalition_side coalition.side|nil
---@return ZoneHandler|nil
function utils.fetchSuppliesZoneFromPoint(point, coalition_side)
    for _,zone in pairs(zones) do
        if zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP or zone.zone_type == ZoneTypes.LOGISTICS then
            
            if (not coalition_side or zone.side == coalition_side) and zone:isPointInsideZone(point) then
                return zone
            end
        end
    end
    return nil
end

---@param unit Unit
---@return ZoneHandler|nil
function utils.fetchSuppliesZoneFromUnit(unit)
    if unit and unit:isExist() then
        return utils.fetchSuppliesZoneFromPoint(unit:getPoint(), unit:getCoalition())
    end
    return nil
end

---@param zone ZoneHandler
---@return number
function utils.fetchLocalSuppliesFromZone(zone)
    return zone.local_supplies or 0
end

---@param to_zone ZoneHandler
---@param side coalition.side
---@param max_distance_m number|nil
---@return table|nil
function utils.findClosestCaptureHeloSource(to_zone, side, max_distance_m)
    if not to_zone or not to_zone.zone then return nil end

    local candidates = {}

    for _, zone in ipairs(zones) do
        if zone.side == side and zone.zone_type == ZoneTypes.LOGISTICS and (zone.heli_avail or 0) > 0 then
            local distance = mist.utils.get2DDist(to_zone.zone.point, zone.zone.point)
            if not max_distance_m or distance <= max_distance_m then
                table.insert(candidates, {
                    source = zone,
                    distance = distance,
                })
            end
        end
    end

    if Config.lha_setup and Config.lha_setup.enabled and Config.lha_setup.lha_unit_name then
        local lha_unit = Unit.getByName(Config.lha_setup.lha_unit_name)
        local lha_point = nil
        if lha_unit and lha_unit:isExist() then
            lha_point = lha_unit:getPoint()
        end

        if lha_point then
            local distance = mist.utils.get2DDist(to_zone.zone.point, lha_point)
            if not max_distance_m or distance <= max_distance_m then
                Config.lha_setup.lha_source = true
                table.insert(candidates, {
                    source = {
                        name = Config.lha_setup.name,
                        side = side,
                        zone_type = ZoneTypes.LOGISTICS,
                        zone = {
                            point = lha_point
                        },
                        ammo_depot_intact = true,
                        heli_avail = 4, -- warehouse limitations will prevent when none are left
                        local_supplies = 0,
                        lha_source = true,
                    },
                    distance = distance,
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.distance < b.distance
    end)

    if #candidates > 0 then
        return candidates[1].source
    end

    return nil
end

-- This function prevents lost, ignored, invalid zones to be left inside the zones main table
---@param zone_list table
---@return ZoneHandler[]
function utils.compactZoneList(zone_list)
    local compact = {}
    local numeric_keys = {}

    for k, _ in pairs(zone_list or {}) do
        if type(k) == "number" then
            table.insert(numeric_keys, k)
        end
    end

    table.sort(numeric_keys)

    for _, key in ipairs(numeric_keys) do
        local zone = zone_list[key]
        if zone then
            table.insert(compact, zone)
        end
    end

    return compact
end

---@param table number[]
---@return number
function utils.tableMax(table)
    local max = table[1]
    -- Iterate through the table
    for i, num in ipairs(table) do
        if num > max then
            max = num
        end
    end
    return max
end

---@param table number[]
---@return number
function utils.tableMin(table)
    local min = table[1]
    -- Iterate through the table
    for i, num in ipairs(table) do
        if num < min then
            min = num
        end
    end
    return min
end

---@param vec vec3|vec2
---@return vec2
function utils.toVec2(vec) do
    if vec.x and vec.y and not vec.z then return { x = vec.x, y = vec.y} end -- already vec2

    return { x = vec.x, y = vec.z } end
end

---@param vec vec2|vec3
---@param agl number|nil if nil, will use land height at vec position
function utils.toVec3(vec,agl) do
    if vec.x and vec.y and vec.z then return { x = vec.x, y = vec.y, z = vec.z } end -- already vec3

    return { x = vec.x, y = agl or land.getHeight(vec), z = vec.y } end
end

---@param point_a vec3|vec2
---@param point_b vec3|vec2
---@param ratio number
---@return vec3
function utils.pointAlongSegment(point_a, point_b, ratio)
    local a = utils.toVec3(point_a)
    local b = utils.toVec3(point_b)
    local t = math.max(0, math.min(1, ratio or 0.5))

    local x = a.x + (b.x - a.x) * t
    local z = a.z + (b.z - a.z) * t
    return { x = x, y = land.getHeight({ x = x, y = z }), z = z }
end

---@param point_a vec3|vec2
---@param point_b vec3|vec2
---@param width_m number
---@param corner_radius_m number
---@param corner_segments number
---@return vec3[]
function utils.buildRoundedRectAroundSegment(point_a, point_b, width_m, corner_radius_m, corner_segments)
    local a = utils.toVec3(point_a)
    local b = utils.toVec3(point_b)

    local dx = b.x - a.x
    local dz = b.z - a.z
    local leg_len = math.sqrt(dx * dx + dz * dz)
    if leg_len < 1 then
        return {}
    end

    local ux = dx / leg_len
    local uz = dz / leg_len
    local vx = -uz
    local vz = ux

    local center_x = (a.x + b.x) * 0.5
    local center_z = (a.z + b.z) * 0.5
    local half_len = leg_len * 0.5
    local half_w = math.max(1, (width_m or 1) * 0.5)
    local radius = math.max(0, math.min(corner_radius_m or 0, half_len, half_w))
    local steps = math.max(1, math.floor(corner_segments or 4))

    local points = {}
    local function toWorld(lx, ly)
        local x = center_x + (ux * lx) + (vx * ly)
        local z = center_z + (uz * lx) + (vz * ly)
        return { x = x, y = land.getHeight({ x = x, y = z }), z = z }
    end

    if radius < 1 then
        table.insert(points, toWorld(half_len, half_w))
        table.insert(points, toWorld(half_len, -half_w))
        table.insert(points, toWorld(-half_len, -half_w))
        table.insert(points, toWorld(-half_len, half_w))
        return points
    end

    local function addArc(cx, cy, start_deg, end_deg)
        for i = 0, steps do
            local t = i / steps
            local angle = math.rad(start_deg + ((end_deg - start_deg) * t))
            local lx = cx + radius * math.cos(angle)
            local ly = cy + radius * math.sin(angle)
            local wp = toWorld(lx, ly)
            local last = points[#points]
            if not last or mist.utils.get2DDist(last, wp) > 1 then
                table.insert(points, wp)
            end
        end
    end

    addArc(half_len - radius, half_w - radius, 90, 0)      -- top-right
    addArc(half_len - radius, -half_w + radius, 0, -90)     -- bottom-right
    addArc(-half_len + radius, -half_w + radius, -90, -180) -- bottom-left
    addArc(-half_len + radius, half_w - radius, 180, 90)    -- top-left

    return points
end

---@param MHz number
---@return number
function utils.MHztoHz(MHz)
    return MHz*1e6
end