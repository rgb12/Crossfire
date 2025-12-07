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
            trigger.action.outText("> Persistence enabled.",60)
            return true
        elseif Config.persistence.enable then
            PersistenceManager.enabled = false
            trigger.action.outText("> Persistence disabled, could not access io or lfs.", 60)
        end
        return false
    end


    --- Gathers all mission-critical data into the data table.
    function PersistenceManager:fetchState()
        if not PersistenceManager.enabled then return end  
        MissionLogger:info("Gathering current mission state...")
        PersistenceManager.data = {} -- Clear old data

        -- 1. Save Scenario (the home bases)
        PersistenceManager.data.scenario = Scenario
        -- PersistenceManager.data.scenario = {
        --     blue_airbase_name = blue_airbase.name,
        --     red_airbase_name = red_airbase.name
        -- }

        -- 2. Save stats
        PersistenceManager.data.stats = stats

        -- 3. Save only essential zone properties that cannot be reconstructed
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
                
                -- Dynamic counters (must save, can't reconstruct)
                capture_heli_avail = z.capture_heli_avail or 0,
                capture_convoy_avail = z.capture_convoy_avail or 0,
                attack_convoy = z.attack_convoy or 0,
                
                -- State tracking
                ammo_depot_intact = z.ammo_depot_intact,
                ammo_depot_last_destroyed = z.ammo_depot_last_destroyed,
                next_level_up_avail = z.next_level_up_avail,
            }
            PersistenceManager.data.zones[z.name] = zone_data
        end

        -- 4. Save Warehouse Inventories
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
        end
        MissionLogger:info("State successfully gathered.")
    end

    --- Simply places enroutes back into warehouses for next mission
    function PersistenceManager:enroutesRefund()
        MissionLogger:info("Calculating virtual refunds for save file...")
        
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
            and enroute.ai_task_type ~= AITaskTypes.CAPTURE_CONVOY
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

        if not PersistenceManager.data or not PersistenceManager.data.zones then
            MissionLogger:error("Restore failed: No data loaded.")
            return false
        end
        
        MissionLogger:info("Applying loaded mission state...")

        -- 1. Restore Scenario
        Scenario = PersistenceManager.data.scenario
        blue_airbase = ZoneHandler.getFromName(PersistenceManager.data.scenario.blue_airbase.name)
        red_airbase = ZoneHandler.getFromName(PersistenceManager.data.scenario.red_airbase.name)
        if not (blue_airbase and red_airbase) then
            MissionLogger:error("Restore failed: Could not find home airbases.")
            return false
        end

        -- 2. Restore Stats
        stats = PersistenceManager.data.stats
        stats.blue_comms_antennas = 0
        stats.red_comms_antennas = 0
        MissionLogger:info("Stats table restored.")

        -- 3. Restore Zones
        local new_zones = {}
        for _, saved_zone in pairs(PersistenceManager.data.zones) do
            local zone = ZoneHandler.getFromName(saved_zone.name)
            if zone then
                -- Restore identity & configuration
                zone.side = saved_zone.side
                zone.level = saved_zone.level
                zone.zone_type = saved_zone.zone_type
                zone.airbase_name = saved_zone.airbase_name
                zone.sam_classification = saved_zone.sam_classification
                
                -- Restore dynamic counters
                zone.capture_heli_avail = saved_zone.capture_heli_avail or 0
                zone.capture_convoy_avail = saved_zone.capture_convoy_avail or 0
                zone.attack_convoy = saved_zone.attack_convoy or 0
                
                -- Restore state tracking
                zone.ammo_depot_intact = saved_zone.ammo_depot_intact
                zone.ammo_depot_last_destroyed = saved_zone.ammo_depot_last_destroyed
                zone.next_level_up_avail = saved_zone.next_level_up_avail
                
                -- Clear runtime tracking arrays - will be repopulated by spawn functions
                zone.linked_groups = {}
                zone.linked_statics = {}
                
                -- Spawn the correct units for the zone's side and level
                UnitHandler.initZoneUnits(zone)
                UnitHandler.initStatics(zone)
                
                -- Post-spawn check for destroyed statics
                if not zone.ammo_depot_intact and zone.linked_ammo_depot then
                    local depot = StaticObject.getByName(zone.linked_ammo_depot)
                    if depot and depot:isExist() then depot:destroy() end
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

        -- 4. Restore Warehouses
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
                    MissionLogger:info("Warehouse restored for: " .. airbase_name)
                end
            end
        end
        
        PersistenceManager:loadUserData()
        
        MissionLogger:info("Mission state successfully restored.")
        trigger.action.outText("Mission state restored from last save.", 10)
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

    function PersistenceManager:loadUserData()
        if not PersistenceManager.enabled then return end
        if not PersistenceManager.user_data_file_path then return end

        if not lfs.attributes(PersistenceManager.user_data_file_path) then
            MissionLogger:info("No user data file found.")
            return
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