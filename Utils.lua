utils = {}
do
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

    function utils.getZoneOfUnitFromPosition(position)
        for i, zone in ipairs(zones) do
            if zone:isPointInsideZone(position) then
                return zone
            end
        end
        return nil
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
                    min = { x = minX, y = -500, z = minZ },
                    max = { x = maxX, y = 9999, z = maxZ }
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
end