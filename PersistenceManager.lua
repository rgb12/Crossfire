---@diagnostic disable: lowercase-global

--[[
    Persistence Manager
    
    Inspired by Dzsek's Pretense persistence script
]]
PersistenceManager = {}
do 

    local JSON = (loadfile("Scripts/JSON.lua"))()
    PersistenceManager.enabled = false
    PersistenceManager.data = {}

    function PersistenceManager:isEnabled()
        if not Config or not Config.persistence then return false end

        if Config.persistence.enable and lfs and io then
            PersistenceManager.enabled = true
            PersistenceManager:checkPath()
            return true
        elseif Config.persistence.enable then
            PersistenceManager.enabled = false
            trigger.action.outText("Persistence disabled, could not access io or lfs.", 60)
        elseif not Config.persistence.enable then
            trigger.action.outText("Persistence disabled in config.", 60)
        end
        return false
    end


    --- Gathers all mission data into the data table.
    function PersistenceManager:fetchState()
        if not PersistenceManager.enabled then return end
        PersistenceManager.data = {} -- Clear old data

        PersistenceManager.data.scenario = Scenario

        PersistenceManager.data.stats = stats

        PersistenceManager.data.zones = {}
        for _, z in ipairs(zones) do
            local zone_data = {
                -- Identity & Configuration
                name = z.name,
                side = z.side,
                level = z.level,
                zone_type = z.zone_type,
                
                -- Type-specific properties
                airbase_name = z.airbase_name,  -- Only for airbases
                sam_classification = z.sam_classification,  -- Only for SAM sites
                
                capture_heli_avail = z.capture_heli_avail or 0,
                attack_convoy = z.attack_convoy or 0,
                local_supply = z.local_supply or 0,
                static_queue = {},
                
                -- State tracking
                ammo_depot_intact = z.ammo_depot_intact,
                ammo_depot_time_since_destroyed = z.ammo_depot_last_destroyed and (timer.getTime() - z.ammo_depot_last_destroyed) or nil,

                comms_tower_intact = z.comms_tower_intact,
                comms_tower_time_since_destroyed = z.comms_tower_last_destroyed and (timer.getTime() - z.comms_tower_last_destroyed) or nil,

                cmdc_intact = z.cmdc_intact,
                cmdc_time_since_destroyed = z.cmdc_last_destroyed and (timer.getTime() - z.cmdc_last_destroyed) or nil,

                -- Zone FARPs are dynamically recreated and may get new object names on restore.
                -- Persist their warehouse inventory with the zone record so we can remap it.
                farp_warehouse_inventory = nil
            }

            if z.zone_type == ZoneTypes.FARP and z.linked_farp then
                local farp_airbase = Airbase.getByName(z.linked_farp)
                if farp_airbase then
                    local farp_warehouse = farp_airbase:getWarehouse()
                    if farp_warehouse then
                        zone_data.farp_warehouse_inventory = farp_warehouse:getInventory()
                    end
                end
            end

            if z.static_queue then
                for _, q in ipairs(z.static_queue) do
                    if q and q.static_type and q.rebuild_at then
                        table.insert(zone_data.static_queue, {
                            static_type = q.static_type,
                            category = q.category,
                            priority = q.priority,
                            time_until_rebuild = math.max(0, q.rebuild_at - timer.getTime())
                        })
                    end
                end
            end

            PersistenceManager.data.zones[z.name] = zone_data
        end

        PersistenceManager.data.warehouses = {}
        for _, z in ipairs(zones) do
            if z.zone_type == ZoneTypes.AIRBASE and z.airbase_name then
                local airbase = Airbase.getByName(z.airbase_name)
                if airbase then
                    local warehouse = airbase:getWarehouse()
                    if warehouse then
                        PersistenceManager.data.warehouses[z.airbase_name] = warehouse:getInventory()
                    end
                end
            end
            if z.zone_type == ZoneTypes.FARP and z.linked_farp then
                local farp = Airbase.getByName(z.linked_farp)
                if farp then
                    local warehouse = farp:getWarehouse()
                    if warehouse then
                        PersistenceManager.data.warehouses[z.linked_farp] = warehouse:getInventory()
                    end
                end
            end
        end

        -- Save carrier warehouse
        if Scenario.carrier_setup.enabled and Scenario.carrier_setup.carrier_unit_name then
            local carrier = Airbase.getByName(Scenario.carrier_setup.carrier_unit_name)
            if carrier then
                local warehouse = carrier:getWarehouse()
                if warehouse then
                    PersistenceManager.data.warehouses[Scenario.carrier_setup.carrier_unit_name] = warehouse:getInventory()
                end
            end
        end

        -- Save constructed FARP warehouses and FARP registry
        PersistenceManager.data.ctld_farps = {}
        if ctld.FARPs then
            for _, farp_data in ipairs(ctld.FARPs) do
                if farp_data.farp_name then
                    local farp = Airbase.getByName(farp_data.farp_name)
                    if farp then
                        local warehouse = farp:getWarehouse()
                        if warehouse then
                            PersistenceManager.data.warehouses[farp_data.farp_name] = warehouse:getInventory()
                        end
                    end
                    table.insert(PersistenceManager.data.ctld_farps, {
                        farp_name = farp_data.farp_name,
                        display_name = farp_data.display_name,
                        point = farp_data.point,
                        coalition = farp_data.coalition,
                        linked_zone_name = farp_data.linked_zone and farp_data.linked_zone.name or nil
                    })
                end
            end
        end

        PersistenceManager.data.placed_assets = {}
        if Config.persistence.enable_ctld_persistence then
            for _, asset in ipairs(ctld.placed_assets) do
                -- Handle groups (SAM systems, etc.)
                if asset.is_group and asset.group_name then
                    local group = Group.getByName(asset.group_name)
                    if group and group:isExist() then
                        local units = group:getUnits()
                        local group_units_data = {}
                        
                        -- Check if all units are alive and collect their data
                        for _, unit in ipairs(units) do
                            if unit and unit:isExist() and unit:getLife() > 1
                            and unit.inAir and not unit:inAir() then
                                    table.insert(group_units_data, {
                                        type = unit:getTypeName(),
                                        name = unit:getName(),
                                        point = unit:getPoint()
                                    })
                            end
                        end
                        
                        -- Save group if all units are alive
                        if #group_units_data > 0 then
                            table.insert(PersistenceManager.data.placed_assets, {
                                is_group = true,
                                group_name = asset.group_name,
                                asset_name = asset.asset_name,
                                type = asset.type,
                                coalition = asset.coalition,
                                units = group_units_data
                            })
                        end
                    end
                else
                    -- Handle individual units and statics
                    local obj = nil
                    local obj_exists = false
                    
                    -- Check if it's a static object (cargo crates, FARPs)
                    if asset.type == ctld.AssetTypes.CARGO_CRATES or asset.type == ctld.AssetTypes.STATIC then
                        obj = StaticObject.getByName(asset.unit_name)
                        if obj and obj.isExist and obj:isExist() then
                            obj_exists = true
                        end
                    -- Check if it's a unit (troops, vehicles, unpacked units)
                    elseif asset.type == ctld.AssetTypes.TROOPS or asset.type == ctld.AssetTypes.VEHICLES then
                        obj = Unit.getByName(asset.unit_name)
                        if obj and obj:isExist() and obj:getLife() > 1 then
                            obj_exists = true
                        end
                    end
                    
                    -- Save if object exists and is alive
                    if obj_exists and obj then
                        if asset.type == ctld.AssetTypes.STATIC then
                            
                            table.insert(PersistenceManager.data.placed_assets, {
                                unit_name = asset.unit_name,
                                asset_name = asset.asset_name,
                                category = asset.category,
                                shape_name = asset.shape_name,
                                type = asset.type,
                                point = obj:getPoint(),
                                coalition = asset.coalition
                            })
                        elseif not obj:inAir() then
                            table.insert(PersistenceManager.data.placed_assets, {
                                unit_name = asset.unit_name,
                                asset_name = asset.asset_name,
                                type = asset.type,
                                point = obj:getPoint(),
                                coalition = asset.coalition or obj:getCoalition()
                            })
                        end
                    end
                end
            end
            PersistenceManager.data.ctld_last_group_id = mist.getNextGroupId()
            PersistenceManager.data.ctld_last_unit_id = mist.getNextUnitId()
        end
    end

    function PersistenceManager:enroutesRefund()

        for _, enroute in ipairs(EnrouteManager.enroutes) do
            local zone_data = nil
            if enroute.from_zone then
                zone_data = PersistenceManager.data.zones[enroute.from_zone.name]
            end

            if zone_data then
                -- Refund Asset Counts to the Save Data
                if enroute.ai_task_type == AITaskTypes.CAPTURE_HELO then
                    zone_data.capture_heli_avail = (zone_data.capture_heli_avail or 0) + 1
                elseif enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    zone_data.attack_convoy = (zone_data.attack_convoy or 0) + 1
                end
            end

            -- Refund Aircraft & Payloads to the Warehouse Data
            -- (Skip ground assets that don't use warehouses)
            if enroute.ai_task_type ~= AITaskTypes.CAPTURE_HELO
            and enroute.ai_task_type ~= AITaskTypes.ATTACK_CONVOY
            and enroute.ai_task_type ~= AITaskTypes.RESUPPLY_CARGO then
                
                if enroute.from_zone and enroute.from_zone.airbase_name then
                    -- Find the warehouse data in our Save Table
                    local wh_root = PersistenceManager.data.warehouses[enroute.from_zone.airbase_name]
                    
                    if wh_root then
                        -- Ensure categories exist in save data if they were empty
                        if not wh_root["aircraft"] then wh_root["aircraft"] = {} end
                        if not wh_root["weapon"] then wh_root["weapon"] = {} end

                        -- 1. Refund the Airframe
                        local side = enroute.side
                        if WarehouseManager.AirbaseGroupData[enroute.from_zone.airbase_name]
                        and WarehouseManager.AirbaseGroupData[enroute.from_zone.airbase_name][side]
                        and WarehouseManager.AirbaseGroupData[enroute.from_zone.airbase_name][side][enroute.ai_task_type] then
                            
                            local acft_name = WarehouseManager.AirbaseGroupData[enroute.from_zone.airbase_name][side][enroute.ai_task_type].warehouse_name
                            if acft_name then
                                -- Add to "aircraft" category in save data
                                wh_root["aircraft"][acft_name] = (wh_root["aircraft"][acft_name] or 0) + 1
                            end
                        end

                        -- 2. Refund the Payload
                        local payload_def = WarehouseManager.AIPayloads[enroute.side][enroute.ai_task_type]
                        if payload_def then
                            for wpn_id, amount in pairs(payload_def) do
                                -- Add to "weapon" category in save data
                                wh_root["weapon"][wpn_id] = (wh_root["weapon"][wpn_id] or 0) + amount
                            end
                        end
                    end
                end
            end
        end
    end


    --- Create the folder if it doesn't exist
    function PersistenceManager:checkPath()
        if not PersistenceManager.enabled then return end
        if not Config or not Config.persistence then return end

        lfs.mkdir(lfs.writedir()..Config.persistence.save_dir)
        PersistenceManager.mission_save_file_path = lfs.writedir()..Config.persistence.save_dir .. Config.persistence.save_file
        PersistenceManager.user_data_file_path = lfs.writedir()..Config.persistence.save_dir .. Config.persistence.user_data_file
    end

    --- Serializes self.data and writes it to the save file.
    function PersistenceManager:saveMissionToFile()
        if not PersistenceManager.enabled then return end
        PersistenceManager:checkPath()

        self:fetchState()

        self:enroutesRefund()

        if not JSON then return end
            ---@diagnostic disable-next-line: undefined-field
            local file_content = JSON:encode(PersistenceManager.data)
            if file_content then

                local file= io.open(PersistenceManager.mission_save_file_path, "w")
                if file then
                    file:write(file_content)
                    file:close()
                    MissionLogger:info("Mission state saved to " .. PersistenceManager.mission_save_file_path)
                end

            end

    end

    ---
    --- Reads the save file and deserializes it into self.data.
    ---
    function PersistenceManager:loadFromFile()
        if not PersistenceManager.enabled then return end
        
        -- Check path in case lfs isn't loaded yet
        PersistenceManager:checkPath()

        if not lfs.attributes(PersistenceManager.mission_save_file_path) then
            MissionLogger:info("No save file found at " .. PersistenceManager.mission_save_file_path)
            return false
        end

        local file = io.open(PersistenceManager.mission_save_file_path, "r")
        if file and JSON then
            local file_data = file:read("*all")
            ---@diagnostic disable-next-line: undefined-field
            local data = JSON:decode(file_data)
            file:close()

            if data then
                PersistenceManager.data = data
                MissionLogger:info("Successfully loaded data from " .. PersistenceManager.mission_save_file_path)
                return true
            end
        end
    end

    ---
    --- Applies the loaded self.data to the running mission.
    ---
    function PersistenceManager:restoreState()
        if not PersistenceManager.enabled then return false end

        -- -- Load user data regardless of mission data existence
        -- PersistenceManager:loadUserData()

        if not PersistenceManager.data or not PersistenceManager.data.zones then
            MissionLogger:error("Restore failed: No data loaded.")
            return false
        end
        
        MissionLogger:info("Applying loaded mission state...")

        -- 1. Restore Scenario
        ---@type Scenario

        if not PersistenceManager.data.scenario
        or not PersistenceManager.data.scenario.name
        or not PersistenceManager.data.scenario.blue_airbase
        or not PersistenceManager.data.scenario.red_airbase then
            MissionLogger:error("Restore failed: Save file is missing scenario metadata.")
            return false
        end

        local saved_scenario_name = PersistenceManager.data.scenario.name
        if saved_scenario_name ~= Config.persistence.scenario_selected then
            MissionLogger:info("Restore failed: Saved scenario '" .. saved_scenario_name .. "' does not match selected scenario '" .. Config.persistence.scenario_selected .. "'.")
            return false
        end

        local matched_scenario = nil
        for _, scenario in pairs(Scenarios) do
            if scenario.name == saved_scenario_name then
                matched_scenario = scenario
                break
            end
        end

        if not matched_scenario then
            MissionLogger:error("Restore failed: Scenario '" .. saved_scenario_name .. "' was not found in Scenarios.")
            return false
        end

        Scenario = matched_scenario
        MissionLogger:info("Scenario restored: " .. Scenario.name)

        local blue_airbase_candidate = ZoneHandler.getFromName(PersistenceManager.data.scenario.blue_airbase.name)
        local red_airbase_candidate = ZoneHandler.getFromName(PersistenceManager.data.scenario.red_airbase.name)
        
        if not (blue_airbase_candidate and red_airbase_candidate) then
            MissionLogger:error("Restore failed: Could not find home airbases.")
            return false
        end
        blue_airbase = blue_airbase_candidate
        red_airbase = red_airbase_candidate

        -- 2. Restore Stats
        stats = PersistenceManager.data.stats
        stats.blue_comms_antennas = 0
        stats.red_comms_antennas = 0
        stats.blue_command_posts = 0
        stats.red_command_posts = 0
        stats.blue_ammo_depots = 0
        stats.red_ammo_depots = 0
        MissionLogger:info("Stats table restored.")

        -- 3. Restore Zones
        local new_zones = {}
        for _, saved_zone in pairs(PersistenceManager.data.zones) do
            local zone = ZoneHandler.getFromName(saved_zone.name)
            if zone then -- Ensures not available zones get ignored
                -- Restore identity & configuration
                zone.side = saved_zone.side
                zone.level = saved_zone.level
                zone.zone_type = saved_zone.zone_type
                zone.airbase_name = saved_zone.airbase_name
                zone.sam_classification = saved_zone.sam_classification
                
                -- Restore dynamic counters
                zone.capture_heli_avail = saved_zone.capture_heli_avail or 0
                zone.attack_convoy = saved_zone.attack_convoy or 0
                zone.local_supply = saved_zone.local_supply or 0
                zone.static_queue = {}
                if saved_zone.static_queue then
                    for _, q in ipairs(saved_zone.static_queue) do
                        if q and q.static_type and q.time_until_rebuild then
                            table.insert(zone.static_queue, {
                                static_type = q.static_type,
                                category = q.category,
                                priority = q.priority,
                                rebuild_at = timer.getTime() + math.max(0, q.time_until_rebuild)
                            })
                        end
                    end
                end
                
                -- Restore state tracking
                zone.ammo_depot_intact = saved_zone.ammo_depot_intact
                if saved_zone.ammo_depot_time_since_destroyed then
                    zone.ammo_depot_last_destroyed = timer.getTime() - saved_zone.ammo_depot_time_since_destroyed
                end
                
                zone.comms_tower_intact = saved_zone.comms_tower_intact
                if saved_zone.comms_tower_time_since_destroyed then
                    zone.comms_tower_last_destroyed = timer.getTime() - saved_zone.comms_tower_time_since_destroyed
                else
                    zone.comms_tower_last_destroyed = nil
                end

                -- Backward compatibility: old saves may not include cmdc_* fields.
                zone.cmdc_intact = saved_zone.cmdc_intact
                if zone.zone_type == ZoneTypes.AIRBASE and zone.cmdc_intact == nil then
                    zone.cmdc_intact = true
                end
                if saved_zone.cmdc_time_since_destroyed then
                    zone.cmdc_last_destroyed = timer.getTime() - saved_zone.cmdc_time_since_destroyed
                else
                    zone.cmdc_last_destroyed = nil
                end
                
                -- Clear runtime tracking arrays - will be repopulated by spawn functions
                zone.linked_groups = {}
                zone.linked_statics = {}


                -- Spawn the units for the zone's side and level
                UnitHandler.initZoneUnits(zone)
                UnitHandler.initStatics(zone)
                UnitHandler.initFARP(zone,false)

                -- Restore zone FARP warehouse by zone mapping (not old FARP object name).
                if zone.zone_type == ZoneTypes.FARP and zone.linked_farp and saved_zone.farp_warehouse_inventory then
                    local farp_airbase = Airbase.getByName(zone.linked_farp)
                    if farp_airbase then
                        local farp_warehouse = farp_airbase:getWarehouse()
                        if farp_warehouse then
                            if WarehouseManager and WarehouseManager.clearWarehouse then
                                WarehouseManager:clearWarehouse(zone.linked_farp)
                            end
                            for category, items_table in pairs(saved_zone.farp_warehouse_inventory) do
                                if type(items_table) == "table" and category ~= "liquids" then
                                    for item_name, count in pairs(items_table) do
                                        farp_warehouse:setItem(item_name, count)
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Post-spawn check for destroyed statics
                if not zone.ammo_depot_intact and zone.linked_ammo_depot then
                    local depot = StaticObject.getByName(zone.linked_ammo_depot)
                    if depot and depot:isExist() then depot:destroy() end
                end

                if not zone.comms_tower_intact and zone.linked_comms_tower then
                    local comms = StaticObject.getByName(zone.linked_comms_tower)
                    if comms and comms:isExist() then comms:destroy() end
                end

                -- Set airbase coalition
                if zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                    local airbase = Airbase.getByName(zone.airbase_name)
                    if airbase then
                        airbase:autoCapture(false)
                        airbase:setCoalition(zone.side)
                    end
                end
                
                -- Redraw the F10 map
                zone:drawF10()
            end
            table.insert(new_zones, zone)
        end
        zones = new_zones
        
        MissionLogger:info("Zone states and units restored.")

        -- 4. Pre-spawn CTLD FARP statics
        if PersistenceManager.data.placed_assets then
            for _, saved_asset in ipairs(PersistenceManager.data.placed_assets) do
                if saved_asset.type == ctld.AssetTypes.STATIC then
                    local country_id = saved_asset.coalition == coalition.side.BLUE and country.id["CJTF_BLUE"] or country.id["CJTF_RED"]
                    mist.dynAddStatic({
                        type = saved_asset.asset_name,
                        shape_name = saved_asset.shape_name,
                        name = saved_asset.unit_name,   -- preserve original name so warehouse key matches
                        country = country_id,
                        category = saved_asset.category or "Fortifications",
                        x = saved_asset.point.x,
                        y = saved_asset.point.z,
                        heading = 0
                    })
                end
            end
        end

        -- Restore ctld.FARPs registry
        if PersistenceManager.data.ctld_farps then
            ctld.FARPs = {}
            for _, saved_farp in ipairs(PersistenceManager.data.ctld_farps) do
                ---@type ConstructedFARP
                local farp = {
                    farp_name = saved_farp.farp_name,
                    display_name = saved_farp.display_name,
                    point = saved_farp.point,
                    coalition = saved_farp.coalition,
                    linked_zone = saved_farp.linked_zone_name and ZoneHandler.getFromName(saved_farp.linked_zone_name) or nil
                }

                table.insert(ctld.FARPs, farp)
                ctld.displayConstructedFarp(farp)
            end
            MissionLogger:info(string.format("Restored %d CTLD FARPs.", #ctld.FARPs))
        end

        -- 5. Restore Warehouses
        for airbase_name, saved_inventory in pairs(PersistenceManager.data.warehouses) do
            local airbase = Airbase.getByName(airbase_name)
            if airbase then
                local warehouse = airbase:getWarehouse()
                if warehouse then

                    -- Restore saved stock
                    if saved_inventory then
                        for category, items_table in pairs(saved_inventory) do
                            if type(items_table) == "table" and category ~= "liquids" then
                                for item_name, count in pairs(items_table) do
                                    warehouse:setItem(item_name, count)
                                end
                            end
                        end
                    end
                end
            end
        end
        MissionLogger:info("Warehouses restored")
        
        -- 6. Restore Placed Assets (CTLD cargo, troops, vehicles, groups)
        mist.nextGroupId = PersistenceManager.data.ctld_last_group_id or mist.getNextGroupId()
        mist.nextUnitId = PersistenceManager.data.ctld_last_unit_id or mist.getNextUnitId()

        if PersistenceManager.data.placed_assets then
            ctld.placed_assets = {} -- Clear current list
            for _, saved_asset in ipairs(PersistenceManager.data.placed_assets) do
                
                -- Handle groups (SAM systems, etc.)
                if saved_asset.is_group and saved_asset.units and saved_asset.coalition then

                        local country_id = saved_asset.coalition == coalition.side.BLUE and country.id["CJTF_BLUE"] or country.id["CJTF_RED"]
                        
                        -- Build units table for the group
                        local units_table = {}
                        for _, unit_data in ipairs(saved_asset.units) do
                            local u_id = mist.getNextUnitId()
                            table.insert(units_table, {
                                type = unit_data.type,
                                unitId = u_id,
                                name = unit_data.name,
                                x = unit_data.point.x,
                                y = unit_data.point.z,
                            })
                        end
                        
                        -- Spawn the group with all its units
                        local spawned_group = mist.dynAdd({
                            units = units_table,
                            country = country_id,
                            category = Group.Category.GROUND,
                            groupName = saved_asset.group_name,
                        })
                        
                        if spawned_group then
                            table.insert(ctld.placed_assets, {
                                is_group = true,
                                group_name = saved_asset.group_name,
                                asset_name = saved_asset.asset_name,
                                type = saved_asset.type,
                                coalition = saved_asset.coalition,
                                unit_count = #units_table
                            })
                            MissionLogger:info(string.format("Restored group %s with %d units", saved_asset.group_name, #units_table))
                        end
                    
                else
                    -- Handle individual units and statics
                    if not saved_asset.point or not saved_asset.asset_name or not saved_asset.coalition then
                        MissionLogger:warn("Skipping invalid placed asset: missing required data")
                    else
                        if saved_asset.type == ctld.AssetTypes.STATIC then
                            table.insert(ctld.placed_assets, {
                                unit_name = saved_asset.unit_name,
                                asset_name = saved_asset.asset_name,
                                category = saved_asset.category,
                                shape_name = saved_asset.shape_name,
                                type = saved_asset.type,
                                point = saved_asset.point,
                                coalition = saved_asset.coalition
                            })
                        else
                            local part = nil
                            for _, p in ipairs(ctld.parts) do
                                if p.name == saved_asset.asset_name then
                                    part = p
                                    break
                                end
                            end
                            
                            if part then
                                -- Determine country from coalition
                                local country_id = saved_asset.coalition == coalition.side.BLUE and country.id["CJTF_BLUE"] or country.id["CJTF_RED"]

                                if saved_asset.type == ctld.AssetTypes.TROOPS or saved_asset.type == ctld.AssetTypes.VEHICLES then
                                    -- Respawn as unit with "unpacked" prefix for vehicles to enable unitAttack
                                    local u_id = mist.getNextUnitId()
                                    local unit_name = saved_asset.type == ctld.AssetTypes.VEHICLES
                                        and Config.ctld.unpacked_asset_prefix ..part.name .. "_" .. u_id
                                        or part.name .. "_" .. u_id
                                    
                                    local spawned_group = mist.dynAdd({
                                        units = {{
                                            type = part.name,
                                            unitId = u_id,
                                            name = unit_name,
                                            x = saved_asset.point.x,
                                            y = saved_asset.point.z,
                                        }},
                                        country = country_id,
                                        category = Group.Category.GROUND,
                                    })
                                    
                                    if spawned_group then
                                        table.insert(ctld.placed_assets, {
                                            unit_name = unit_name,
                                            asset_name = part.name,
                                            point = saved_asset.point,
                                            type = saved_asset.type,
                                            coalition = saved_asset.coalition
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Updates check
        if not stats.blue_supplies then stats.blue_supplies = 0 end
        if not stats.red_supplies then stats.red_supplies = 0 end
        
        MissionLogger:info("Mission state successfully restored.")
        --trigger.action.outText("Persistence, restored from last save.", 10)
        return true
    end

function PersistenceManager:saveUserDataToFile()
        if not PersistenceManager.enabled then return end
        if not PersistenceManager.user_data_file_path then return end
        if not JSON then return end
        
        local file_content = JSON:encode(ExperienceManager.user_data)

        if file_content then
            local file = io.open(PersistenceManager.user_data_file_path, "w")
            if file then
                file:write(file_content)
                file:close()
            end
        end
    end

    ---@return boolean
    function PersistenceManager:loadUserData()
        if not PersistenceManager.enabled then return false end
        if not PersistenceManager.user_data_file_path then return false end

        if not lfs.attributes(PersistenceManager.user_data_file_path) then
            MissionLogger:info("No user data file found.")
            return false
        end

        local file = io.open(PersistenceManager.user_data_file_path, "r")
        if file and JSON then
            local file_data = file:read("*all")
            local data = JSON:decode(file_data)
            file:close()

            if data then
                ExperienceManager:restoreUserData(data)
                return true
            end
        end
        return false
    end

    function PersistenceManager:autoSave()
        if not Config or not Config.persistence or not Config.persistence.save_interval then return end
        
        MissionLogger:info("Auto-save enabled.")

        timer.scheduleFunction(function()

            PersistenceManager:saveMissionToFile()
            PersistenceManager:saveUserDataToFile()

            return timer.getTime() + (Config.persistence.save_interval)
        end, {}, timer.getTime() + (Config.persistence.save_interval))
    end

end