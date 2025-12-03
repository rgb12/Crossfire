UnitHandler = {}
do

    function UnitHandler.findClosestAvailableAirfieldSpawn(to_zone,side,aircraft_type)
        --WARN maybe also check airbase parking avail using Airbase.getParking()
        local loop_prevention = 0

        local unavail_airbases = {}
        local closest_airbase = to_zone:getClosestZone(side,unavail_airbases,{ZoneTypes.AIRBASE})
        while closest_airbase and loop_prevention < 400 do
            MissionLogger:info("Closest airbase to "..to_zone.name.."is "..closest_airbase.name)
            if closest_airbase.airbase_name then
    
                local airbase = Airbase.getByName(closest_airbase.airbase_name)
                if airbase and airbase:getCoalition() == side then
                    local airbase_warehouse = airbase:getWarehouse()
    
                    local aircraft_count = 0
                    local group_name
                    if WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name]
                    and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side]
                    and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type]
                    and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].warehouse_name
                    and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].group_name  then
                        aircraft_count =airbase_warehouse:getItemCount(WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].warehouse_name)
                        group_name = WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].group_name
                    end
                    if aircraft_count and aircraft_count>0 and group_name then
                        return closest_airbase,group_name
                    end
                end
                table.insert(unavail_airbases,closest_airbase.name)
                closest_airbase,_ = to_zone:getClosestZone(side,unavail_airbases,{ZoneTypes.AIRBASE})
            end
            loop_prevention = loop_prevention+1
        end
        if loop_prevention >395 then MissionLogger:error("Loop prevention prevented crash") end
        return nil,nil
    end

    ---@param zone ZoneHandler
    ---@param max_tries number|nil
    ---@param clear_radius number|nil
    ---@return vec2
    function UnitHandler.findClearPoint(zone, max_tries, clear_radius)
        max_tries = max_tries or 6
        clear_radius = clear_radius or 50
        local last
        for i = 1, max_tries do
            local candidate = mist.getRandomPointInZone(zone.name)

            if candidate and mist.isTerrainValid(candidate,{"LAND"}) then
                last = candidate
                local found = false

                if clear_radius then
                    local vol = { id = world.VolumeType.SPHERE, params = { point = candidate, radius = clear_radius } }
                    world.searchObjects({Object.Category.UNIT,Object.Category.STATIC}, vol, function() found = true end)
                end
                if not found then return candidate end
            end
        end
        if not last then return mist.utils.makeVec2(zone.zone.point) end
        return mist.utils.makeVec2(last)
    end

    ---@param group_name string
    ---@param zone ZoneHandler
    ---@param disperse boolean|nil
    ---@return string|nil -- group name
    function UnitHandler.clone(group_name, zone, disperse)
        local clear_point = UnitHandler.findClearPoint(zone)
        local new_group
        new_group = mist.teleportToPoint({
            groupName = group_name,
            point = clear_point,
            action = 'clone',
            disperse = disperse or false,
            initTasks = true
        })
        if not new_group or not new_group.name then
            return nil
        end

        table.insert(zone.linked_groups, new_group.name)
        
        if new_group and new_group.name then return new_group.name end
    end

    ---@param group_name string
    ---@param from_zone ZoneHandler
    function UnitHandler.abortHeliCapture(group_name, from_zone)
        local group = Group.getByName(group_name)
        if not group or not group:isExist() then return end

        local HELO_LZ_TO_MAX_RADIUS_FROM_CENTER = 200 --meters
        local max_radius = from_zone.zone.radius or 200
        if from_zone.zone.radius > HELO_LZ_TO_MAX_RADIUS_FROM_CENTER then max_radius = HELO_LZ_TO_MAX_RADIUS_FROM_CENTER end

        local safe_lz_pos = utils.rndPointFromCenter(from_zone.zone.point,15,max_radius)
        for i=0,10 do
            if from_zone:isPointClearOfUnits(safe_lz_pos,30) then
                break
            else safe_lz_pos = utils.rndPointFromCenter(from_zone.zone.point,15,max_radius) end
        end

        local helo_controller = group:getController()

        helo_controller:resetTask()

        timer.scheduleFunction(function ()
            helo_controller:setTask({
                id = "Land",
                params = {
                    x = safe_lz_pos.x,
                    y = safe_lz_pos.z
                }
            })
        end, {}, timer.getTime()+2)


        helo_controller:setOption(AI.Option.Air.id.REACTION_ON_THREAT,
            AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)

        -- set aborted flag if not already set
        local heli = EnrouteManager:findByGroup(group_name)
        if heli then  heli.aborted = true end

    end

    ---@param potential_birth_zone ZoneHandler
    function UnitHandler.checkRedirectAbortedCaptureHeli(potential_birth_zone)
        -- MissionLogger:info("Checking for potential aborted heli redirect")
        for _,heli in ipairs(EnrouteManager.enroutes) do
            if heli.from_zone.name == potential_birth_zone.name and heli.aborted then
                local closest_zone, _ = potential_birth_zone:getClosestZone(heli.side)
                if closest_zone then
                    UnitHandler.abortHeliCapture(heli.group_name, closest_zone)
                    heli.from_zone = closest_zone
                    MissionLogger:info("Aborted Helo capture redirected to closest zone: " ..heli.group_name .. " to zone: " .. closest_zone.zone.name)
                else
                    MissionLogger:info("Aborted Helo capture could not be redirected, no closest zone found, destroying it: " ..heli.group_name)
                    local group = Group.getByName(heli.group_name)
                    if group and group:isExist() then group:destroy() end
                    EnrouteManager:remove(heli.group_name)
                end
            end
        end
    end

    ---@param convoy_group Group
    ---@return boolean
    function UnitHandler.checkConvoyMoving(convoy_group)
            -- group must exist
            if not convoy_group or not convoy_group.isExist or not convoy_group:isExist() then return false end
        
            local units = convoy_group.getUnits and convoy_group:getUnits() or {}
            if #units == 0 then return false end
        
            for _, un in ipairs(units) do
                if un and un.isExist and un:isExist() then
                    local vel = un.getVelocity and un:getVelocity()
                    if vel then
                        if (mist.vec.mag(vel) or 0) > 0.1 then
                            return true
                        end
                    end
                end
            end
            return false
    end

    --- Update the units in the zone depending on tier and side
    ---@param zone ZoneHandler
    function UnitHandler.updateZoneUnits(zone)
        -- first remove all existing units
        for _, group_name in pairs(zone.linked_groups) do
            local group = Group.getByName(group_name)
            if group and group:isExist() then
                group:destroy()
            end
        end
        zone.linked_groups = {}

        -- then respawn new units
        UnitHandler.initZoneUnits(zone)

    end

    ---@param zone ZoneHandler
    function UnitHandler.initZoneUnits(zone)

        if zone.zone_type == ZoneTypes.STRONGPOINT and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground frontline units
            if zone.side == coalition.side.RED then

                UnitHandler.clone(GroupData.STRONGPOINT_SITES.RED[zone.level].group_name, zone,true) --TO CHANGE
                stats.red_strongpoints = stats.red_strongpoints +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.STRONGPOINT_SITES.BLUE[zone.level].group_name, zone,true)
                stats.blue_strongpoints = stats.blue_strongpoints +1

            end


        elseif zone.zone_type == ZoneTypes.LOGISTICS and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then
                UnitHandler.clone(GroupData.LOGISTICS_SITES.RED[zone.level].group_name, zone,true)
                stats.red_logistics_zone = stats.red_logistics_zone +1

            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.LOGISTICS_SITES.BLUE[zone.level].group_name, zone,true)
                stats.blue_logistics_zone = stats.blue_logistics_zone +1
            end


        elseif zone.zone_type == ZoneTypes.SAMSITE and zone.side ~= coalition.side.NEUTRAL then
            
            local grp = nil
            local sam_spawn_options = {}
            for _, sam_obj in pairs(GroupData.SAM_SITES_NG) do
                if zone.side == sam_obj.side and zone.sam_classification == sam_obj.sam_classification then
                    table.insert(sam_spawn_options, sam_obj.group_name)
                end
            end
            if #sam_spawn_options >0 then
                local sam_choice_index = math.random(1,#sam_spawn_options)
                grp = UnitHandler.clone(sam_spawn_options[sam_choice_index], zone, false)
            end
            if grp then
                if zone.side == coalition.side.RED then
                    stats.red_sam_sites = stats.red_sam_sites+1
                else stats.blue_sam_sites = stats.blue_sam_sites+1 end
            end


        elseif zone.zone_type == ZoneTypes.FARP and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then
                -- UnitHandler.clone(obj.init_groups or {"GRND L1"}, obj.zone.name)
                stats.red_farp_zones = stats.red_farp_zones +1
            elseif zone.side == coalition.side.BLUE then
                -- UnitHandler.clone(obj.init_groups or {"BLUE GRND L1"}, obj.zone.name)
                stats.blue_farp_zones = stats.blue_farp_zones +1
            end


        elseif zone.zone_type == ZoneTypes.COMMS and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then

                UnitHandler.clone(GroupData.COMMS_SITES.RED[zone.level].group_name, zone,true)
                stats.red_comms_zones = stats.red_comms_zones +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.COMMS_SITES.BLUE[zone.level].group_name, zone,true)
                stats.blue_comms_zones = stats.blue_comms_zones +1
            end


        elseif zone.zone_type == ZoneTypes.EWSITE and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then
                UnitHandler.clone(GroupData.EW_SITES.RED[zone.level].group_name, zone,true)
                stats.red_ew_zones = stats.red_ew_zones +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.EW_SITES.BLUE[zone.level].group_name, zone,true)
                stats.blue_ew_zones = stats.blue_ew_zones +1
            end
        
        elseif zone.zone_type == ZoneTypes.AIRBASE and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then
                UnitHandler.clone(GroupData.AIRBASE_SITES.RED[zone.level].group_name, zone,true)
                for _,sam in pairs(GroupData.AIRBASE_SAMS.RED) do
                    if sam.tier == zone.level then
                        UnitHandler.clone(sam.group_name, zone,false)
                    end
                end
                stats.red_airbases = stats.red_airbases +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.AIRBASE_SITES.BLUE[zone.level].group_name, zone,true)
                for _,sam in pairs(GroupData.AIRBASE_SAMS.BLUE) do
                    if sam.tier == zone.level then
                        UnitHandler.clone(sam.group_name, zone,false)
                    end
                end
                stats.blue_airbases = stats.blue_airbases +1
            end
        end
    end

    function UnitHandler.initStatics(zone)
        local country_name
        if zone.side == coalition.side.BLUE then country_name = country.id.CJTF_BLUE
        else country_name = country.id.CJTF_RED end

        if zone.zone_type == ZoneTypes.LOGISTICS then
            local point = mist.getRandomPointInZone(zone.name) or {x=zone.zone.point.x+55,y=zone.zone.point.z-29}

            
            local ammo_depot = mist.dynAddStatic({
                type = ".Ammunition depot",
                country = country_name,
                category = "Warehouses",
                x = point.x,
                y = point.y})
            if ammo_depot then
                zone.ammo_depot_intact = true
                zone.linked_ammo_depot = ammo_depot.name
                
                table.insert(zone.linked_statics, ammo_depot.name)
               
            else
                MissionLogger:error("Could not spawn ammo depot for ".. zone.name)
            end

        elseif zone.zone_type == ZoneTypes.COMMS then
            local point = mist.getRandomPointInZone(zone.name) or {x=zone.zone.point.x+25,y=zone.zone.point.z-19}

            local comms_tower = mist.dynAddStatic({
                type = "Comms tower M",
                country = country_name,
                category = "Fortifications",
                x = point.x,
                y = point.y})
            if comms_tower then
                zone.comms_tower_intact = true
                zone.linked_comms_tower = comms_tower.name
                
                if zone.side == coalition.side.BLUE then
                    stats.blue_comms_antennas = stats.blue_comms_antennas +1
                else
                    stats.red_comms_antennas = stats.red_comms_antennas +1
                end
               
                table.insert(zone.linked_statics, comms_tower.name)
               
            else
                MissionLogger:error("Could not spawn comms tower for ".. zone.name)
            end


        elseif zone.zone_type == ZoneTypes.AIRBASE then
            local cmd_center_point = UnitHandler.findClearPoint(zone,50,500)

            local command_center = mist.dynAddStatic({
                type = ".Command Center",
                country = country_name, --81 = CJTF RED | 82= CJTF BLUE
                category = "Fortifications",
                x = cmd_center_point.x,
                y = cmd_center_point.y
            })
            if command_center then

                table.insert(zone.linked_statics, command_center.name)
            else
                MissionLogger:error("Could not spawn comms tower for ".. zone.name)
            end


        elseif zone.zone_type == ZoneTypes.FARP then
            -- local farp_ammo_storage_point = mist.getRandomPointInZone(zone.name) or {x=zone.zone.point.x+85,y=zone.zone.point.z-29}
            -- local farp_fuel_depot_point = mist.getRandomPointInZone(zone.name) or {x=zone.zone.point.x+57,y=zone.zone.point.z-27}

            local farp_heliport_point = UnitHandler.findClearPoint(zone,6,10)
            local farp_tent = UnitHandler.findClearPoint(zone,6,10)
            local farp_fuel_depot_point = UnitHandler.findClearPoint(zone,6,10)
            local farp_ammo_storage_point = UnitHandler.findClearPoint(zone,6,10)

            mist.dynAddStatic({
                type = "Invisible FARP",
                shape_name = "invisiblefarp",
                country = country_name,
                category = "Heliports",
                x = farp_heliport_point.x,
                y = farp_heliport_point.y})

            mist.dynAddStatic({
                type = "FARP Tent",
                country = country_name,
                category = "Fortifications",
                x = farp_tent.x,
                y = farp_tent.y})

            mist.dynAddStatic({
                type = "FARP Fuel Depot",
                country = country_name,
                category = "Fortifications",
                x = farp_fuel_depot_point.x,
                y = farp_fuel_depot_point.y})
            mist.dynAddStatic({
                type = "FARP Ammo Dump Coating",
                country = country_name,
                category = "Fortifications",
                x = farp_ammo_storage_point.x,
                y = farp_ammo_storage_point.y}) --TO CHANGE complete the spawns
            
            -- if zone.side == coalition.side.RED then --WARN Deleted by accident the units
            --     mist.cloneInZone("RED FARP UNITS",zone.name,true,10)
            -- elseif zone.side == coalition.side.BLUE then 
            --     mist.cloneInZone("BLUE FARP UNITS",zone.name,true,10)
            -- end
        end
    
    end


end