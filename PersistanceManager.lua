---@diagnostic disable: lowercase-global

--[[
    Persistance Manager
    
    Inspired by Dzsek's Pretense persistance script
]]
PersistanceManager = {}
do 

    local JSON = (loadfile("Scripts/JSON.lua"))()
    PersistanceManager.enabled = false
    PersistanceManager.data = {}
    PersistanceManager.user_data = {}

    function PersistanceManager:isEnabled()
        if Config.persistance.enable
        and lfs and io then
            PersistanceManager.enabled = true
            PersistanceManager:checkPath()

            return true
        end
        return false
    end


    ---
    --- Gathers all mission-critical data into the self.data table.
    ---
    function PersistanceManager:fetchState()
        if not PersistanceManager.enabled then return end  
        MissionLogger:info("Gathering current mission state...")
        PersistanceManager.data = {} -- Clear old data

        -- 1. Save Scenario (the home bases)
        PersistanceManager.data.scenario = {
            blue_airbase_name = blue_airbase.name,
            red_airbase_name = red_airbase.name
        }

        -- 2. Save the entire stats table
        PersistanceManager.data.stats = stats

        -- 3. Save a simplified version of all zones
        -- CHANGE: Use [z.name] as key instead of table.insert. 
        -- This allows applyVirtualRefunds to find zones instantly.
        PersistanceManager.data.zones = {}
        for _, z in ipairs(zones) do
            local zone_data = {
                name = z.name,
                side = z.side,
                level = z.level,
                capture_heli_avail = z.capture_heli_avail or 0,
                capture_convoy_avail = z.capture_convoy_avail or 0,
                attack_convoy = z.attack_convoy or 0,
                last_attacked_by = z.last_attacked_by,
                last_capture_attempt = z.last_capture_attempt,
                ammo_depot_intact = z.ammo_depot_intact,
                ammo_depot_last_destroyed = z.ammo_depot_last_destroyed,
                next_level_up_avail = z.next_level_up_avail,
                linked_ammo_depot = z.linked_ammo_depot
            }
            PersistanceManager.data.zones[z.name] = zone_data
        end

        -- 4. Save Warehouse Inventories
        PersistanceManager.data.warehouses = {}
        for _, z in ipairs(zones) do
            if z.zone_type == ZoneTypes.AIRBASE and z.airbase_name then
                local airbase = Airbase.getByName(z.airbase_name)
                if airbase then
                    local warehouse = airbase:getWarehouse()
                    if warehouse then
                        PersistanceManager.data.warehouses[z.airbase_name] = warehouse:getInventory()
                    end
                end
            end
        end
        MissionLogger:info("State successfully gathered.")
    end

    ---
    --- "Virtual Refund": Calculates enroute units and adds them to the SAVE DATA
    --- WITHOUT destroying the actual units in the live mission.
    ---
    function PersistanceManager:applyVirtualRefunds()
        MissionLogger:info("Calculating refunds for save file...")
        
        for _, enroute in ipairs(EnrouteManager.enroutes) do
            -- Find the zone data in our Save Table (not the live object)
            local zone_data = nil
            if enroute.from_zone then
                zone_data = PersistanceManager.data.zones[enroute.from_zone.name]
            end

            if zone_data then
                -- Refund Asset Counts to the Save Data
                if enroute.ai_task_type == AITaskTypes.CAPTURE_HELO then
                    zone_data.capture_heli_avail = (zone_data.capture_heli_avail or 0) + 1
                elseif enroute.ai_task_type == AITaskTypes.CAPTURE_CONVOY then
                    zone_data.capture_convoy_avail = (zone_data.capture_convoy_avail or 0) + 1
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
                    -- Note: getInventory returns structure like { ["weapon"] = { ... } }
                    local wh_root = PersistanceManager.data.warehouses[enroute.from_zone.airbase_name]
                    
                    if wh_root then
                        -- Ensure categories exist in save data if they were empty
                        if not wh_root["aircraft"] then wh_root["aircraft"] = {} end
                        if not wh_root["weapon"] then wh_root["weapon"] = {} end

                        -- 1. Refund the Airframe
                        local side = enroute.side
                        if AIRCRAFT_GROUP[enroute.from_zone.airbase_name] 
                        and AIRCRAFT_GROUP[enroute.from_zone.airbase_name][side]
                        and AIRCRAFT_GROUP[enroute.from_zone.airbase_name][side][enroute.ai_task_type] then
                            
                            local acft_name = AIRCRAFT_GROUP[enroute.from_zone.airbase_name][side][enroute.ai_task_type].warehouse_name
                            if acft_name then
                                -- Add to "aircraft" category in save data
                                wh_root["aircraft"][acft_name] = (wh_root["aircraft"][acft_name] or 0) + 1
                            end
                        end

                        -- 2. Refund the Payload
                        local payload_def = WarehouseManager.AIPayloads[enroute.ai_task_type]
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
    function PersistanceManager:checkPath()
        if not PersistanceManager.enabled then return end

        lfs.mkdir(lfs.writedir()..Config.persistance.save_dir)
        PersistanceManager.save_file_path = lfs.writedir()..Config.persistance.save_dir .. Config.persistance.save_file
        PersistanceManager.user_data_file_path = lfs.writedir()..Config.persistance.save_dir .. Config.persistance.user_data_file
    end

    ---
    --- Serializes self.data and writes it to the save file.
    ---
    function PersistanceManager:saveToFile()
        if not PersistanceManager.enabled then return end
        PersistanceManager:checkPath()

        -- CHANGE: Fetch state FIRST (to get the baseline)
        self:fetchState()

        -- CHANGE: Apply refunds to the fetched state (virtual only)
        -- This replaces the old self:refundEnrouteAI() call
        self:applyVirtualRefunds()

        -- 3. Serialize and write to file
        if not JSON then return end
            ---@diagnostic disable-next-line: undefined-field
            local file_content = JSON:encode(PersistanceManager.data)
            if file_content then

                local file= io.open(PersistanceManager.save_file_path, "w")
                if file then
                    file:write(file_content)
                    file:close()
                    MissionLogger:info("Mission state saved to " .. PersistanceManager.save_file_path)
                end

            end

            -- Save user data
            if Config.persistance.enable_user_data_persistance then
                ---@diagnostic disable-next-line: undefined-field
                local user_file_content = JSON:encode(PersistanceManager.user_data)
                if user_file_content then
                    local user_file= io.open(PersistanceManager.user_data_file_path, "w")
                    if user_file then
                        user_file:write(user_file_content)
                        user_file:close()
                        MissionLogger:info("User data saved to " .. PersistanceManager.user_data_file_path)
                    end
                end
            end

    end

    ---
    --- Reads the save file and deserializes it into self.data.
    ---
    function PersistanceManager:loadFromFile()
        if not PersistanceManager.enabled then return end

        if not lfs.attributes(PersistanceManager.save_file_path) then
            MissionLogger:info("No save file found at " .. PersistanceManager.save_file_path)
            return false
        end

        local file = io.open(PersistanceManager.save_file_path, "r")
        if file and JSON then
            local file_data = file:read("*all")
            ---@diagnostic disable-next-line: undefined-field
            local data = JSON:decode(file_data)
            file:close()

            if data then
                PersistanceManager.data = data
                MissionLogger:info("Successfully loaded data from " .. PersistanceManager.save_file_path)
                return true
            end
        end

        if Config.persistance.enable_user_data_persistance then
            -- Load user data
            if not lfs.attributes(PersistanceManager.user_data_file_path) then
                MissionLogger:info("No user data file found at " .. PersistanceManager.user_data_file_path)
                return false
            end

            local user_file = io.open(PersistanceManager.user_data_file_path, "r")
            if user_file and JSON then
                local user_file_data = user_file:read("*all")
                ---@diagnostic disable-next-line: undefined-field
                local user_data = JSON:decode(user_file_data)
                user_file:close()

                if user_data then
                    PersistanceManager.user_data = user_data
                    MissionLogger:info("Successfully loaded user data from " .. PersistanceManager.user_data_file_path)
                end
            end
        end

    end

    ---
    --- Applies the loaded self.data to the running mission.
    ---
    function PersistanceManager:restoreState()
        if not PersistanceManager.enabled then return false end

        if not PersistanceManager.data or not PersistanceManager.data.zones then
            MissionLogger:error("Restore failed: No data loaded.")
            return false
        end
        
        MissionLogger:info("Applying loaded mission state...")

        -- 1. Restore Scenario
        blue_airbase = ZoneHandler.getFromName(PersistanceManager.data.scenario.blue_airbase_name)
        red_airbase = ZoneHandler.getFromName(PersistanceManager.data.scenario.red_airbase_name)
        if not (blue_airbase and red_airbase) then
            MissionLogger:error("Restore failed: Could not find home airbases.")
            return false
        end

        -- 2. Restore Stats
        stats = PersistanceManager.data.stats
        MissionLogger:info("Stats table restored.")

        -- 3. Restore Zones
        -- CHANGE: Use pairs() because 'zones' is now a dictionary [name]=data
        for _, saved_zone in pairs(PersistanceManager.data.zones) do
            local zone = ZoneHandler.getFromName(saved_zone.name)
            if zone then
                zone.side = saved_zone.side
                zone.level = saved_zone.level
                zone.capture_heli_avail = saved_zone.capture_heli_avail
                zone.capture_convoy_avail = saved_zone.capture_convoy_avail
                zone.attack_convoy = saved_zone.attack_convoy
                zone.last_attacked_by = saved_zone.last_attacked_by
                zone.last_capture_attempt = saved_zone.last_capture_attempt
                zone.ammo_depot_intact = saved_zone.ammo_depot_intact
                zone.ammo_depot_last_destroyed = saved_zone.ammo_depot_last_destroyed
                zone.next_level_up_avail = saved_zone.next_level_up_avail
                zone.linked_ammo_depot = saved_zone.linked_ammo_depot

                -- Spawn the correct units for the zone's side and level
                UnitHandler.initZoneUnits(zone)
                UnitHandler.initStatics(zone)

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
        end
        MissionLogger:info("Zone states and units restored.")

        -- 4. Restore Warehouses
        for airbase_name, saved_inventory in pairs(PersistanceManager.data.warehouses) do
            local airbase = Airbase.getByName(airbase_name)
            if airbase then
                local warehouse = airbase:getWarehouse()
                if warehouse then

                    MissionLogger:info("saved inventory for " .. airbase_name)
                    
                    -- 1. Get current inventory to find what needs to be cleared
                    local current_inventory = warehouse:getInventory()
                    
                    -- 2. Clear existing stock (set everything to 0)
                    if current_inventory then
                        for category, items_table in pairs(current_inventory) do
                            -- Only clear weapons and aircraft. Liquids use different functions.
                            if type(items_table) == "table" and category ~= "liquids" then
                                for item_name, _ in pairs(items_table) do
                                    warehouse:setItem(item_name, 0)
                                end
                            end
                        end
                    end

                    -- 3. Restore saved stock
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
        
        MissionLogger:info("Mission state successfully restored.")
        trigger.action.outText("Mission state restored from last save.", 10)
        return true
    end

    function PersistanceManager:autoSave()
        if not Config.persistance.save_interval then return  end
        MissionLogger:info("Auto-save enabled, saving every " .. tostring(Config.persistance.save_interval) .. " seconds.")    

        timer.scheduleFunction(function()
            PersistanceManager:saveToFile()
            return timer.getTime() + (Config.persistance.save_interval)
        end, {}, timer.getTime() + (Config.persistance.save_interval))
    end

end