UnitHandler = {}
do
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
    ---@param max_disperse_disperse number|nil
    ---@param inner_radius number|nil
    ---@return string|nil -- group name
    function UnitHandler.clone(group_name, zone, disperse,max_disperse_disperse, inner_radius)
        local clear_point = UnitHandler.findClearPoint(zone)
        local new_group
        new_group = mist.teleportToPoint({
            groupName = group_name,
            point = clear_point,
            action = 'clone',
            disperse = disperse or false,
            maxDisperse = max_disperse_disperse or nil,
            innerRadius = inner_radius or nil,
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
                        UnitHandler.clone(sam.group_name, zone,true,300)
                    end
                end
                stats.red_airbases = stats.red_airbases +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.AIRBASE_SITES.BLUE[zone.level].group_name, zone,true)
                for _,sam in pairs(GroupData.AIRBASE_SAMS.BLUE) do
                    if sam.tier == zone.level then
                        UnitHandler.clone(sam.group_name, zone,true,300)
                    end
                end
                stats.blue_airbases = stats.blue_airbases +1
            end
        elseif zone.zone_type == ZoneTypes.FARP and zone.side ~= coalition.side.NEUTRAL then
            -- spawn red or blue ground logistics units
            if zone.side == coalition.side.RED then
                UnitHandler.clone(GroupData.FARP_SUPPORT.RED[zone.level].group_name, zone,true,100,300)
                stats.red_farp_zones = stats.red_farp_zones +1
            elseif zone.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.FARP_SUPPORT.BLUE[zone.level].group_name, zone,true,100,300)
                stats.blue_farp_zones = stats.blue_farp_zones +1
            end
        end
    end

    function UnitHandler.initStatics(zone)
        if zone.side == coalition.side.NEUTRAL then return end
        local country_name
        if zone.side == coalition.side.BLUE then country_name = country.id.CJTF_BLUE
        else country_name = country.id.CJTF_RED end

        if zone.zone_type == ZoneTypes.LOGISTICS then
            if zone.ammo_depot_intact == false then return end

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
            if zone.comms_tower_intact == false then return end
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

        end
    
    end

    ---@param zone ZoneHandler
    function UnitHandler.initFARP(zone)
        if zone.zone_type ~= ZoneTypes.FARP then return end
        if zone.side == coalition.side.NEUTRAL then return end

        local country_name_id
        if zone.side == coalition.side.BLUE then
            country_name_id = country.id.CJTF_BLUE
            stats.blue_farp_zones = stats.blue_farp_zones +1
        else 
            country_name_id = country.id.CJTF_RED
            stats.red_farp_zones = stats.red_farp_zones +1
        end

        -- Base coordinates for the zone center (where Invisible FARP goes)
        local base_x = zone.zone.point.x
        local base_y = zone.zone.point.z -- DCS world Z coordinate is Lua's Y

        -- List of Statics to spawn with their estimated offsets (X, Y)
        local farp_statics_to_spawn = {
            -- Invisible FARP (Center Point)
            { type = "Invisible FARP", category = "Heliports", shape_name = "invisiblefarp", offset_x = 0, offset_y = 0 },

            -- Tents (clustered east of the pad)
            { type = "FARP Tent", category = "Fortifications", offset_x = 5, offset_y = 55 },
            { type = "FARP Tent", category = "Fortifications", offset_x = -15, offset_y = 55 },

            -- Ammo Storage (North of the pad)
            { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = 30, offset_y = 5 },
            { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = 30, offset_y = -5 },


            -- Fuel Depots (South of the pad)
            { type = "FARP Fuel Depot", category = "Fortifications", offset_x = 5, offset_y = -60 },
            { type = "FARP Fuel Depot", category = "Fortifications", offset_x = -5, offset_y = -60 },
        }

        -- Spawn the Statics
        for _, static_data in ipairs(farp_statics_to_spawn) do
            local static_point = {
                x = base_x + static_data.offset_x,
                y = base_y + static_data.offset_y
            }

            -- some dcs quirks with invisible farps .. that makes it work

            if not (zone.side == coalition.side.RED and static_data.type == "Invisible FARP")
            and not (zone.linked_farp and static_data.type == "Invisible FARP") then
 
                local new_static = mist.dynAddStatic({
                        type = static_data.type,
                        shape_name = static_data.shape_name,
                        country = country_name_id,
                        category = static_data.category,
                        x = static_point.x,
                        y = static_point.y,
                        heading = 0
                    })

                if new_static and new_static.name then

                    
                    if static_data.type ~= "Invisible FARP" then
                        -- do not track invisible farps as they are not destroyable
                        table.insert(zone.linked_statics, new_static.name)
                    else
                        zone.linked_farp = new_static.name
                    end
            
                end
            end
        end
        -- Add to warehouse
        
        -- set warehouse
        if zone.linked_farp then
            timer.scheduleFunction(function()
                WarehouseManager:clearWarehouse(zone.linked_farp)

                WarehouseManager:attributeAirbaseStock(zone.linked_farp, zone.side, {WarehouseManager.StockTypes.FARP})
            end, {}, timer.getTime()+1)
        end


        local group_template_name = "BLUE FARP" -- Assumes this is the name of your Late Activated group template
        local group_offset_x = -55
        local group_offset_y = 10
        local group_spawn_point = {
            x = base_x + group_offset_x,
            y = base_y + group_offset_y
        }

        -- Vehicle group
        if zone.side == coalition.side.RED then
            group_template_name = GroupData.COMMON_ASSETS.RED.farp
        else 
            group_template_name = GroupData.COMMON_ASSETS.BLUE.farp
        end

        local vehicles_gr = mist.teleportToPoint({
            groupName = group_template_name,
            point = group_spawn_point,
            action = 'clone',
            disperse = false,
            initTasks = true,
            anyTerrain = true
        })

        if vehicles_gr and vehicles_gr.name then
            table.insert(zone.linked_groups, vehicles_gr.name)
            MissionLogger:info("Cloned FARP Unit Group: " .. group_template_name)
        else
            MissionLogger:error("Failed to clone FARP Unit Group: " .. group_template_name .. ". Ensure the group exists and is Late Activated.")
        end
    end

    function UnitHandler.carrierCheck()
        if not Scenario then return end

        local carrier_data = Scenario.carrier_setup
        if not carrier_data then return end
        if not carrier_data.enabled then
            local carrier_unit = Unit.getByName(carrier_data.carrier_unit_name)
            if not carrier_unit or not carrier_unit:isExist() then return end
            local carrier_group = carrier_unit:getGroup()
            if carrier_group and carrier_group:isExist() then
                MissionLogger:info("Destroying carrier as per scenario settings...")
                carrier_group:destroy()
            end
            return
        end
    end

    ---@param group_name string
    ---@param airbase_name string
    ---@param side coalition.side
    ---@param stock_types WarehouseManager.StockTypes[] if none are provided, a random stock type will be chosen
    function UnitHandler.simulateResupply(group_name,airbase_name, side, stock_types)
        local possible_stocks_rnd =
            {
                {
                    out_text = "AA Aircraft, AA Long Range and AA Short Range missiles",
                    stocks = {
                        WarehouseManager.StockTypes.AA_AIRCRAFT,
                        WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE,
                        WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE,
                    },
                },
                {
                    out_text = "AG and Cargo Aircraft",
                    stocks = {
                        WarehouseManager.StockTypes.CARGO_AIRCRAFT,
                        WarehouseManager.StockTypes.AG_AIRCRAFT,
                    },
                },
                {
                    out_text = "AG Missiles and Rockets",
                    stocks = {
                        WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES,
                        WarehouseManager.StockTypes.AIR_GROUND_ROCKETS,
                    },
                },
                {
                    out_text = "AG Unguided and Guided Bombs",
                    stocks = {
                        WarehouseManager.StockTypes.AIR_GROUND_BOMBS,
                        WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS,
                    },
                },
                {
                    out_text = "ECM, TGPs and Misc Equipment",
                    stocks = {
                        WarehouseManager.StockTypes.ECM,
                        WarehouseManager.StockTypes.TGP,
                        WarehouseManager.StockTypes.MISC,
                    },
                },
            }

        if not stock_types then
            stock_types = stock_types or {}
        end
        if #stock_types==0 and Config.enabled_su25t_blufor then
            table.insert(possible_stocks_rnd,
            {
                out_text = "SU-25T BLUFOR Package (AA Aircraft, AG Missiles, Guided Bombs, ECM and TGPs)",
                stocks = {
                    WarehouseManager.StockTypes.SU25T_BLUFOR,
                },
            })
        end

        local stock_type_choice = possible_stocks_rnd[math.random(1,#possible_stocks_rnd)]

        local out_text = ""
        local chosen_stocks = {}
        if #stock_types == 0 and Config.random_resupply_types then
            chosen_stocks = stock_type_choice.stocks
            out_text = stock_type_choice.out_text
        elseif #stock_types == 0 then
            chosen_stocks = {WarehouseManager.StockTypes.INITIAL}
            out_text = "Initial Stock Package"
        else 
            chosen_stocks = mist.utils.deepCopy(stock_types)
            local stock_descs = {
                [WarehouseManager.StockTypes.AA_AIRCRAFT] = "AA Aircraft",
                [WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE] = "AA Long Range Missiles",
                [WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE] = "AA Short Range Missiles",
                [WarehouseManager.StockTypes.CARGO_AIRCRAFT] = "Cargo Aircraft",
                [WarehouseManager.StockTypes.AG_AIRCRAFT] = "AG Aircraft",
                [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES] = "AG Missiles",
                [WarehouseManager.StockTypes.AIR_GROUND_ROCKETS] = "AG Rockets",
                [WarehouseManager.StockTypes.AIR_GROUND_BOMBS] = "AG Unguided Bombs",
                [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS] = "AG Guided Bombs",
                [WarehouseManager.StockTypes.ECM] = "ECM Equipment",
                [WarehouseManager.StockTypes.TGP] = "TGPs",
                [WarehouseManager.StockTypes.MISC] = "Misc Equipment",
                [WarehouseManager.StockTypes.SU25T_BLUFOR] = "SU-25T BLUFOR Package",
                [WarehouseManager.StockTypes.INITIAL] = "Initial Stock Package",
            }
            for _, stock in ipairs(chosen_stocks) do
                if out_text ~= "" then out_text = out_text .. ", " end
                out_text = out_text .. (stock_descs[stock] or "Unknown Stock Type")
            end
        end

        local prefix = (side == coalition.side.RED) and "RED" or "BLUE"
        trigger.action.outTextForCoalition(side, "RESUPPLY Airdrop packaged secured at " .. airbase_name.."\nAssets received: " ..out_text, 10)
        trigger.action.outSoundForCoalition(side, "supply_package_received.ogg")

        MissionLogger:info(prefix .. " Resupply airdrop delivered at " .. airbase_name)

        
        if side == coalition.side.RED then
            WarehouseManager:attributeAirbaseStock(airbase_name, coalition.side.RED, chosen_stocks or {WarehouseManager.StockTypes.INITIAL})
        else
            local stocks = chosen_stocks or {WarehouseManager.StockTypes.INITIAL}
            WarehouseManager:attributeAirbaseStock(airbase_name, coalition.side.BLUE, stocks)
        end

        EnrouteManager:remove(group_name)

        timer.scheduleFunction(function()
            local g = Group.getByName(group_name)
            if g and g:isExist() then
                MissionLogger:info("Despawning resupply aircraft enroute.")
                g:destroy()
            end
        end, {}, timer.getTime() + 60)
    end

end

---@param zone ZoneHandler
---@param attributes string[]
---@return boolean
function UnitHandler.checkIfZoneHasUnitWithAttributes(zone, attributes)
    local groups_in_zone = zone.linked_groups
    if not groups_in_zone or #groups_in_zone == 0 then return false end
    for _, group_name in ipairs(groups_in_zone) do
        local group = Group.getByName(group_name)
        if group and group:isExist() then
            local units = group:getUnits()
            for _, unit in ipairs(units) do
                if unit and unit:isActive() and unit:isExist() then
                    for _, attr in ipairs(attributes) do
                        if unit:hasAttribute(attr) then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end