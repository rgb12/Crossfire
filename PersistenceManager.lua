---@diagnostic disable: lowercase-global, undefined-global

--[[
    Persistence Manager
    
    Inspired by Dzsek's Pretense persistence script
]]
PersistenceManager = {}
do 

    local JSON = (loadfile("Scripts/JSON.lua"))()
    PersistenceManager.enabled = false
    PersistenceManager.data = {}

    local function cleanJSON(json_text)
        if not json_text or json_text == "" then
            return json_text
        end

        local indent = 0
        local output = {}
        local stack = {}
        local in_string = false
        local escaped = false

        local function append(chunk)
            output[#output + 1] = chunk
        end

        local function current_frame()
            return stack[#stack]
        end

        local function start_value()
            local frame = current_frame()
            if frame and frame.pending_indent then
                append("\n")
                append(string.rep("    ", indent))
                frame.pending_indent = false
            end
            if frame then
                frame.has_content = true
            end
        end

        for i = 1, #json_text do
            local char = json_text:sub(i, i)

            if in_string then
                append(char)
                if escaped then
                    escaped = false
                elseif char == "\\" then
                    escaped = true
                elseif char == '"' then
                    in_string = false
                end
            elseif char == '"' then
                start_value()
                in_string = true
                append(char)
            elseif char == '{' or char == '[' then
                start_value()
                append(char)
                indent = indent + 1
                stack[#stack + 1] = {
                    close = char == '{' and '}' or ']',
                    has_content = false,
                    pending_indent = true
                }
            elseif char == '}' or char == ']' then
                local frame = current_frame()
                if frame then
                    if frame.has_content then
                        append("\n")
                        indent = math.max(indent - 1, 0)
                        append(string.rep("    ", indent))
                    else
                        indent = math.max(indent - 1, 0)
                    end
                    append(char)
                    stack[#stack] = nil
                else
                    append(char)
                end
            elseif char == ',' then
                append(char)
                local frame = current_frame()
                if frame then
                    frame.pending_indent = true
                end
            elseif char == ':' then
                append(": ")
            elseif char:match("%s") then
                -- Skip insignificant whitespace from the compact encoder.
            else
                start_value()
                append(char)
            end
        end

        return table.concat(output)
    end

    local function copyTable(source_table)
        local copied = {}
        for key, value in pairs(source_table or {}) do
            copied[key] = value
        end
        return copied
    end

    local function readJSONFile(file_path)

        --[[
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
        end]]

        local file = io.open(file_path, "r")
        if not (file and JSON) then
            return nil
        end

        local file_data = file:read("*all")
        file:close()

        if not file_data or file_data == "" or not JSON then
            return nil
        end

        return JSON:decode(file_data)
    end

    local function writeJSON(file_path, data_table)
        if not JSON then return false end

        local file_content = cleanJSON(JSON:encode(data_table))
        if not file_content then
            return false
        end

        local file = io.open(file_path, "w")
        if not file then
            return false
        end

        file:write(file_content)
        file:close()
        return true
    end

    local function buildConfigExport()
        return {
            _config_file_version = Config._config_file_version,
            _mission_version = Config._mission_version,
            _enable_external_config = true,
            Config = copyTable(Config),
            stats = copyTable(stats),
            GroupData = copyTable(GroupData),
        }
    end

    ---@param theatre_name string
    ---@return string
    function PersistenceManager:fetchDir(theatre_name)
        return lfs.writedir() .. Config.persistence.save_dir .. "Crossfire " .. theatre_name .. " (v" .. Config._mission_version .. ")/"
    end

    function PersistenceManager:loadUserOverrides()
        if not lfs or not io or not Config or not Config.persistence then return end

        local theatre_name = PersistenceManager:fetchTheatre()
        if not theatre_name then return end

        local dir = PersistenceManager:fetchDir(theatre_name)
        lfs.mkdir(dir)

        local config_path = dir .. "config.json"

        if not lfs.attributes(config_path) then
            writeJSON(config_path, buildConfigExport())
            MissionLogger:info("No user config override found, created default file at " .. config_path)
            return
        end

        local config_file = readJSONFile(config_path)

        if not config_file or type(config_file) ~= "table" then
            MissionLogger:error("User config override at " .. config_path .. " is missing or corrupt, using mission defaults.")
            trigger.action.outText("Crossfire: your config.json could not be read and was ignored. Mission defaults are in use.", 30)
            return
        end

        if not config_file._enable_external_config then
            MissionLogger:info("User config override at " .. config_path .. " is disabled via _enable_external_config, using mission defaults.")
            return
        end

        if not PersistenceManager:isCompatibleOverride(config_file, config_path) then
            return
        end

        if type(config_file.Config) ~= "table" then
            MissionLogger:error("User config override at " .. config_path .. " is missing its Config table, using mission defaults.")
            trigger.action.outText("Crossfire: your config.json is incomplete and was ignored. Mission defaults are in use.", 30)
            return
        end

        Config = config_file.Config
        stats = config_file.stats
        GroupData = config_file.GroupData
        MissionLogger:info("Loaded user config override from " .. config_path)
    end

    ---@param config_file table parsed override file
    ---@param config_path string path used for log messages
    ---@return boolean compatible true if safe to apply the override
    function PersistenceManager:isCompatibleOverride(config_file, config_path)
        local file_mission_version = config_file._mission_version
        local file_config_version = config_file._config_file_version

        if file_mission_version ~= Config._mission_version
            or file_config_version ~= Config._config_file_version then

            local detail = string.format(
                "file mission v%s / config v%s, mission expects mission v%s / config v%s",
                tostring(file_mission_version), tostring(file_config_version),
                tostring(Config._mission_version), tostring(Config._config_file_version))

            MissionLogger:warn("User config override at " .. config_path
                .. " is from an older/incompatible mission version (" .. detail
                .. "). Ignoring it and using mission defaults. Delete this file (or back up your edits) to regenerate a fresh, compatible config.")

            trigger.action.outText(
                "config.json is from an older mission version and was ignored.\n"
                .. "Delete it to regenerate a compatible config (back up your edits first).", 45)

            return false
        end

        return true
    end

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

        MissionLogger:info("Attempting save")

        PersistenceManager.data.eras = mist.utils.deepCopy(Config.era_system.eras_selected)
        PersistenceManager.data.scenario = scenario

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
                
                heli_avail = z.heli_avail or 0,
                attack_convoy = z.attack_convoy or 0,
                
                -- State tracking
                ammo_depot_intact = z.ammo_depot_intact,
                ammo_depot_time_since_destroyed = z.ammo_depot_last_destroyed and (timer.getTime() - z.ammo_depot_last_destroyed) or nil,
                local_supplies = z.local_supplies or 0,

                comms_tower_intact = z.comms_tower_intact,
                comms_tower_time_since_destroyed = z.comms_tower_last_destroyed and (timer.getTime() - z.comms_tower_last_destroyed) or nil,

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
        if Config.carrier_setup.enabled and Config.carrier_setup.carrier_unit_name then
            local carrier = Airbase.getByName(Config.carrier_setup.carrier_unit_name)
            if carrier then
                local warehouse = carrier:getWarehouse()
                if warehouse then
                    PersistenceManager.data.warehouses[Config.carrier_setup.carrier_unit_name] = warehouse:getInventory()
                end
            end
        end

        -- Save LHA warehouse
        if Config.lha_setup and Config.lha_setup.enabled and Config.lha_setup.lha_unit_name then
            local lha = Airbase.getByName(Config.lha_setup.lha_unit_name)
            if lha then
                local warehouse = lha:getWarehouse()
                if warehouse then
                    PersistenceManager.data.warehouses[Config.lha_setup.lha_unit_name] = warehouse:getInventory()
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
                        linked_zone_name = farp_data.linked_zone and farp_data.linked_zone.name or nil,
                        linked_group = farp_data.linked_group
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
                                        point = unit:getPoint(),
                                        heading = mist.getHeading(unit, true) or 0
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
                                coalition = asset.coalition,
                                heading = mist.getHeading(obj, true) or 0
                            })
                        elseif not obj:inAir() then
                            table.insert(PersistenceManager.data.placed_assets, {
                                unit_name = asset.unit_name,
                                asset_name = asset.asset_name,
                                type = asset.type,
                                point = obj:getPoint(),
                                coalition = asset.coalition or obj:getCoalition(),
                                heading = mist.getHeading(obj, true) or 0
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
                    zone_data.heli_avail = (zone_data.heli_avail or 0) + 1
                elseif enroute.ai_task_type == AITaskTypes.REINFORCEMENT_HELO
                or enroute.ai_task_type == AITaskTypes.REINFORCEMENT_CONVOY then
                    zone_data.heli_avail = (zone_data.heli_avail or 0) + 1

                    local required_supplies = (Config.operations and Config.operations.upgrade_required_supplies) or 300
                    local level = zone_data.level or 1
                    local cap = (Config.supplies and Config.supplies.supplies_cap and Config.supplies.supplies_cap[level]) or 0
                    zone_data.local_supplies = math.min((zone_data.local_supplies or 0) + required_supplies, cap)
                elseif enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    zone_data.attack_convoy = (zone_data.attack_convoy or 0) + 1
                end
            end

            -- Refund Aircraft & Payloads to the Warehouse Data
            -- (Skip ground assets that don't use warehouses)
            if enroute.ai_task_type ~= AITaskTypes.CAPTURE_HELO
            and enroute.ai_task_type ~= AITaskTypes.REINFORCEMENT_HELO
            and enroute.ai_task_type ~= AITaskTypes.REINFORCEMENT_CONVOY
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
                        local acft_name = WarehouseManager:getAircraftTypeForTask(side, enroute.ai_task_type)
                        if acft_name then
                            -- Add to "aircraft" category in save data
                            wh_root["aircraft"][acft_name] = (wh_root["aircraft"][acft_name] or 0) + 1
                        end

                        -- 2. Refund the Payload
                        if WarehouseManager.AIPayloads[enroute.side] and WarehouseManager.AIPayloads[enroute.side][enroute.ai_task_type] then
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
    end


    --- Create the folder if it doesn't exist
    function PersistenceManager:checkPath()
        if not PersistenceManager.enabled then return end
        if not Config or not Config.persistence then return end

        local theatre_name = PersistenceManager:fetchTheatre()
        if not theatre_name then return end

        -- Missions/Saves/Crossfire [theatre_name] v[version]/
        local dir = PersistenceManager:fetchDir(theatre_name)
        lfs.mkdir(dir)

        PersistenceManager.mission_save_file_path = dir .. Config.persistence.save_file
        PersistenceManager.user_data_file_path = dir .. Config.persistence.user_data_file
        return true
    end

    --- Serializes self.data and writes it to the save file.
    function PersistenceManager:saveMissionToFile()
        if not PersistenceManager.enabled then return end
        PersistenceManager:checkPath()

        self:fetchState()

        self:enroutesRefund()

        if not JSON then return end
        ---@diagnostic disable-next-line: undefined-field
        local file_content = cleanJSON(JSON:encode(PersistenceManager.data))
        if file_content then

            local file= io.open(PersistenceManager.mission_save_file_path, "w")
            if file then
                file:write(file_content)
                file:close()
                MissionLogger:info("Mission state saved to " .. PersistenceManager.mission_save_file_path)
            end

        end

    end

    ---@return boolean
    function PersistenceManager:deleteSaveFile()
        if not lfs or not io then return false end

        PersistenceManager:checkPath()

        if not PersistenceManager.mission_save_file_path then
            MissionLogger:error("Could not clear save file: path unresolved.")
            return false
        end

        local file = io.open(PersistenceManager.mission_save_file_path, "w")
        if not file then
            MissionLogger:error("Failed to clear save file at " .. PersistenceManager.mission_save_file_path)
            return false
        end

        file:close()
        MissionLogger:info("Mission save file cleared: " .. PersistenceManager.mission_save_file_path)
        return true
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
            file:close()

            if not file_data or file_data == "" then
                MissionLogger:info("Save file is empty, starting a fresh campaign.")
                return false
            end

            ---@diagnostic disable-next-line: undefined-field
            local data = JSON:decode(file_data)

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
            MissionLogger:error("PERSISTENCE RESTORE ERROR: No data loaded.")
            return false
        end
        
        MissionLogger:info("PERSISTENCE: Applying loaded mission state...")

        if not PersistenceManager.data.scenario
        or not PersistenceManager.data.scenario.name
        or not PersistenceManager.data.scenario.blue_airbase
        or not PersistenceManager.data.scenario.red_airbase then
            MissionLogger:error("PERSISTENCE RESTORE ERROR: Save file is missing scenario metadata.")
            return false
        end

        local eras_math = false
        for _, era in pairs(PersistenceManager.data.eras or {}) do
            if not utils.tableContains(Config.era_system.eras_selected, era) then
                eras_math = false
                break
            end
            eras_math = true
        end

        if not eras_math then
            env.error("PERSISTENCE RESTORE ERROR: Incompatible eras in save and config file.",true)
            PersistenceManager.enabled = false
            return false
        end

        scenario = PersistenceManager.data.scenario

        ---@type ZoneHandler[]
        local avail_zones = available_zones[PersistenceManager.data.scenario.theater]

        for _, zone in pairs(avail_zones) do
            if zone.name == PersistenceManager.data.scenario.blue_airbase then
                blue_airbase = zone
            elseif zone.name == PersistenceManager.data.scenario.red_airbase then
                red_airbase = zone
            end
            if blue_airbase and red_airbase then break end
        end
        
        if not (blue_airbase and red_airbase) then
            MissionLogger:error("PERSISTENCE RESTORE ERROR: Could not find home airbases.")
            return false
        end

        -- 2. Restore Stats
        stats = PersistenceManager.data.stats
        stats.blue_comms_antennas = 0
        stats.red_comms_antennas = 0
        stats.blue_ammo_depots = 0
        stats.red_ammo_depots = 0
        MissionLogger:info("Stats table restored.")

        -- 3. Restore Zones
        local new_zones = {}
        for _, saved_zone in pairs(PersistenceManager.data.zones) do
            local zone = ZoneHandler.getFromName(saved_zone.name)
            for _, avail_zone in pairs(avail_zones) do
                if avail_zone.name == saved_zone.name then
                    zone = avail_zone
                    break
                end
            end

            if zone then -- Ensures not available zones get ignored
                -- Restore identity & configuration
                zone.side = saved_zone.side
                zone.level = saved_zone.level
                zone.zone_type = saved_zone.zone_type
                zone.airbase_name = saved_zone.airbase_name
                zone.sam_classification = saved_zone.sam_classification
                
                -- Restore dynamic counters
                zone.heli_avail = saved_zone.heli_avail or saved_zone.capture_heli_avail or 0
                zone.attack_convoy = saved_zone.attack_convoy or 0
                
                -- Restore state tracking
                zone.ammo_depot_intact = saved_zone.ammo_depot_intact
                if saved_zone.ammo_depot_time_since_destroyed then
                    zone.ammo_depot_last_destroyed = timer.getTime() - saved_zone.ammo_depot_time_since_destroyed
                else
                    zone.ammo_depot_last_destroyed = nil
                end
                zone.local_supplies = saved_zone.local_supplies or 0
                
                zone.comms_tower_intact = saved_zone.comms_tower_intact
                if saved_zone.comms_tower_time_since_destroyed then
                    zone.comms_tower_last_destroyed = timer.getTime() - saved_zone.comms_tower_time_since_destroyed
                else
                    zone.comms_tower_last_destroyed = nil
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
                table.insert(new_zones, zone)
            else
                MissionLogger:warn("Restore skipped missing zone: " .. tostring(saved_zone.name))
            end
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
                        heading = saved_asset.heading or 0
                    })
                end
            end
        end

        -- Restore ctld.FARPs registry
        if PersistenceManager.data.ctld_farps then
            ctld.FARPs = {}
            for _, saved_farp in ipairs(PersistenceManager.data.ctld_farps) do
                local farp_name, linked_group = ctld.spawnFARPAssets(
                    saved_farp.coalition, saved_farp.point, saved_farp.farp_name)

                if farp_name then
                    ---@type ConstructedFARP
                    local farp = {
                        farp_name = farp_name,
                        display_name = saved_farp.display_name,
                        point = saved_farp.point,
                        coalition = saved_farp.coalition,
                        linked_zone = saved_farp.linked_zone_name and ZoneHandler.getFromName(saved_farp.linked_zone_name) or nil,
                        linked_group = linked_group
                    }

                    table.insert(ctld.FARPs, farp)
                    ctld.displayConstructedFarp(farp)
                else
                    MissionLogger:warn(string.format("Failed to restore CTLD FARP %s.", tostring(saved_farp.display_name or saved_farp.farp_name)))
                end
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
                                heading = unit_data.heading or 0,
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
                                unit_count = #units_table,
                                units = saved_asset.units
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
                                coalition = saved_asset.coalition,
                                heading = saved_asset.heading
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
                                            heading = saved_asset.heading or 0,
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
                                            coalition = saved_asset.coalition,
                                            heading = saved_asset.heading
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        MissionLogger:info("Mission state successfully restored.")
        --trigger.action.outText("Persistence, restored from last save.", 10)
        return true
    end

    local function constructUserData()
        local export = {}

        for player_name, user_data in pairs(ExperienceManager.user_data or {}) do
            export[player_name] = export[player_name] or {}
            export[player_name].experience_manager_data = user_data
        end

        for player_name, settings in pairs(EWRS.saved_settings or {}) do
            export[player_name] = export[player_name] or {}
            export[player_name].saved_settings = settings
        end

        return export
    end

    function PersistenceManager:saveUserDataToFile()
        if not PersistenceManager.enabled then return end
        if not PersistenceManager.user_data_file_path then return end
        if not JSON then return end

        local file_content = cleanJSON(JSON:encode(constructUserData()))

        if file_content then
            local file = io.open(PersistenceManager.user_data_file_path, "w")
            if file then
                file:write(file_content)
                file:close()
            end
        end
    end

    ---@return Theatres|nil
    function PersistenceManager:fetchTheatre()
        if env.mission and env.mission.theatre then
            for _, theatre in pairs(Theatres) do
                if theatre == env.mission.theatre then
                    return theatre
                end
            end
        end
        return nil
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
                local experience_data = {}
                local ewrs_settings = {}
                for player_name, entry in pairs(data) do
                    if type(entry) == "table" then
                        if entry.experience_manager_data then
                            experience_data[player_name] = entry.experience_manager_data
                        end
                        if entry.saved_settings then
                            ewrs_settings[player_name] = entry.saved_settings
                        end
                    end
                end

                ExperienceManager:restoreUserData(experience_data)
                EWRS:restoreSavedSettings(ewrs_settings)
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