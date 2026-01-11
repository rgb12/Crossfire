ctld = {}


ctld.max_placed_assets = 500  -- Global limit for all placed assets
ctld.load_cooldown_seconds = 1  -- Cooldown between load commands per player
ctld.player_cooldowns = {}  -- store for player cooldowns
ctld.supplies_cap = 10000  -- Max supplies per coalition

---@enum AssetTypes
ctld.AssetTypes = {
    TROOPS = "Troops",
    CARGO_CRATES = "CARGO_CRATES",
    VEHICLES = "Vehicles",
    SAM = "SAM",
}
---@enum ctld.CargoCrates
ctld.CargoCrates = {
    CDS_BARRELS = "cds_barrels",
    CDS_CRATES = "cds_crate",
    ContainerClean = "M92_10Ft_Container",
    MOAB = "gbu_43b_airdrop",
    LargeContainer = "iso_container",
    SmallContainer = "iso_container_small",
    SuppliesCrate = "container_cargo"
}

ctld.allowed_load_zones = {ZoneTypes.FARP, ZoneTypes.AIRBASE, ZoneTypes.LOGISTICS}

---@class acft_limits
---@field aircraft_type string
---@field max_parts number
---@field max_troops number
---@field weight_limit number

---@type acft_limits[]
ctld.aircraft_limits = {
    {aircraft_type = "UH-1H",       max_parts = 2,  max_troops = 8, weight_limit = 2000},
    {aircraft_type = "Mi-8MT",      max_parts = 3,  max_troops = 12, weight_limit = 2000},
    {aircraft_type = "Mi-24P",     max_parts = 2,  max_troops = 8, weight_limit = 2500},
    {aircraft_type = "CH-47Fbl1",   max_parts = 6,  max_troops = 30, weight_limit = 10000},
    {aircraft_type = "C-130J-30",   max_parts = 12, max_troops = 60, weight_limit = 20000},
    {aircraft_type = "SA342L",     max_parts = 1,  max_troops = 4, weight_limit = 800},
    {aircraft_type = "SA342M",     max_parts = 1,  max_troops = 4, weight_limit = 800},
    {aircraft_type = "SA342Mistral",max_parts = 1,  max_troops = 4, weight_limit = 800},
    {aircraft_type = "SA342Minigun",max_parts = 1,  max_troops = 4, weight_limit = 800},
}

---@class Asset
---@field unit_name string|nil
---@field group_name string|nil
---@field asset_name string
---@field type AssetTypes
---@field point vec3
---@field coalition any
---@field is_group boolean|nil
---@field unit_count number|nil

---@type Asset[]
ctld.placed_assets = {} -- store for persistence, save function will check all units and statics are alive before saving

ctld.cargo_crate_template = "container_cargo"
ctld.search_radius = 50  -- meters
ctld.random_crate_spacing = 10  -- meters
ctld.allow_unpacking_in_zones = false
ctld.supplies_per_minute_per_ammo_depot = 50
ctld.enable_weighted_loading = false

ctld.dynamic_cargo_capable_units = {
--    "CH-47Fbl1",
--    "UH-1H",
--    "Mi-8MT",
--    "Mi-24P",
   "C-130J-30"
}

---@class ctld_user
---@field parts part[]
---@field unit Unit
---@field is_dynamic_cargo boolean

---@type ctld_user[]
ctld.users = {}


ctld.nextGroupId = 1
ctld.getNextGroupId = function()
    ctld.nextGroupId = ctld.nextGroupId + 1
    return ctld.nextGroupId
end

---@class part
---@field name string
---@field desc string
---@field weight number
---@field type string
---@field crates_required number|nil 
---@field group_requirement string|nil
---@field can_move boolean|nil
---@field req_supplies number|nil

---@type part[]
ctld.parts = {
    {name = "Hawk ln",          desc = "HAWK Launcher",       weight = 2000, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 400},
    {name = "Hawk tr",          desc = "HAWK Track Radar",    weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 200},
    {name = "Hawk sr",          desc = "HAWK Search Radar",   weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 200},
    {name = "Hawk pcp",         desc = "HAWK PCP",            weight = 200, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 200},
    {name = "Hawk cwar",        desc = "HAWK CWAR",           weight = 200, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 200},


    {name = "NASAMS_LN_C",          desc = "NASAMS Launcher 120C",       weight = 2000, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 400},
    {name = "NASAMS_Radar_MPQ64F1",          desc = "NASAMS Search/Track Radar",    weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 200},
    {name = "NASAMS_Command_Post",          desc = "NASAMS Command Post",   weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 200},


    {name = "Soldier stinger",  desc = "Soldier Stinger",     weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},
    {name = "Soldier M4 GRG", desc = "Soldier", weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},

    {name = "M1097 Avenger", desc="M1097 Avenger", weight = 3900, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 300},
    {name = "Roland ADS", desc="Roland ADS", weight = 5000, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 400},
    {name = "Gepard", desc="Gepard AAA", weight = 5000, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 400},
    {name = "HEMTT_C-RAM_Phalanx", desc="LPWS C-RAM", weight = 7000, type = ctld.AssetTypes.SAM, crates_required = 3, can_move = true, req_supplies = 600},

    {name = "M1043 HMMWV Armament", desc="Humvee - MG", weight = 4000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 150},
    {name = "M1045 HMMWV TOW", desc="Humvee - TOW", weight = 4000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 200},
    {name = "MaxxPro_MRAP", desc="Light Tank - MRAP", weight = 14500, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 300},

    {name = "LAV-25", desc="Med Tank - LAV-25", weight = 12800, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 400},
    
    {name = "M-1 Abrams", desc="Heavy Tank - Abrams", weight = 10000, type = ctld.AssetTypes.VEHICLES, crates_required = 4, can_move = true, req_supplies = 700},

    {name = "Hummer - JTAC", desc="Hummer", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 50},
    {name = "M 818", desc="M-818 Ammo Truck", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 80},
    {name = "M978 HEMTT Tanker", desc="M978 HEMTT Tanker", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 80},

    {name = "FPS-117", desc="EWR Radar", weight = 10000, type = ctld.AssetTypes.VEHICLES, crates_required = 5, req_supplies = 800},

    {name = "MLRS", desc="MLRS", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 600},
    {name = "SpGH_Dana", desc="SpGH DANA", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 500},


    --{name = "container_cargo",  desc = "Crate",               weight = 1000, type = ctld.AssetTypes.CARGO_CRATES},
    {name = "iso_container",    desc = "Large Container",     weight = 4000, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 25},
    {name = "iso_container_small",desc = "Small Container",   weight = 2000, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 15},
    {name = "M92_10Ft_Container",desc = "Clean Container",    weight = 1500, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 10},
    {name = "gbu_43b_airdrop",  desc = "MOAB",                 weight = 9000, type = ctld.AssetTypes.CARGO_CRATES},
    {name = "cds_barrels",     desc = "CDS Barrels",        weight = 200, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    {name = "cds_crate",       desc = "CDS Crate",           weight = 200, type = ctld.AssetTypes.CARGO_CRATES},
}


---@param root_menu any
---@param group Group
function ctld.initF10RadioMenu(root_menu, group)
    local gr_id = group:getID()
    local unit = group:getUnit(1)
    if not unit then return end

    local aircraft_limit = ctld.getAircraftLimit(unit)
    if aircraft_limit then
        local load_submenu = missionCommands.addSubMenuForGroup(gr_id, "Load", root_menu)
    
        local load_troops_submenu = missionCommands.addSubMenuForGroup(gr_id, "Troops", load_submenu)
        
        local load_CARGO_CRATES_submenu = missionCommands.addSubMenuForGroup(gr_id, "Cargo Crates", load_submenu)
        local load_vehicles_submenu = missionCommands.addSubMenuForGroup(gr_id, "Vehicles", load_submenu)
        local load_sam_submenu = missionCommands.addSubMenuForGroup(gr_id, "SAM", load_submenu)
    
    
        missionCommands.addCommandForGroup(gr_id, "Unload", root_menu, function ()
            ctld.unload(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Unpack", root_menu, function ()
            ctld.unpack(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Load Nearby Crate", root_menu, function ()
            ctld.loadNearbyCrate(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Unit Attack", root_menu, function ()
            ctld.unitAttack(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "List Loaded Cargo", root_menu, function ()
            ctld.listOnboardCargo(unit)
        end)

         local troop_commands = {}
        local cargo_crate_commands = {}
        local vehicle_commands = {}
        local sam_commands = {}

        for _, part in ipairs(ctld.parts) do
            if part.type == ctld.AssetTypes.TROOPS then
                table.insert(troop_commands, {
                    name = part.desc,
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            elseif part.type == ctld.AssetTypes.CARGO_CRATES then
                table.insert(cargo_crate_commands, {
                    name = part.desc,
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            elseif part.type == ctld.AssetTypes.VEHICLES then
                table.insert(vehicle_commands, {
                    name = part.desc,
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            elseif part.type == ctld.AssetTypes.SAM then
                table.insert(sam_commands, {
                    name = part.desc,
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            end
        end

        CommandHandler.buildPagedMenuForGroup(gr_id, load_troops_submenu, troop_commands, 1)
        CommandHandler.buildPagedMenuForGroup(gr_id, load_CARGO_CRATES_submenu, cargo_crate_commands, 1)
        CommandHandler.buildPagedMenuForGroup(gr_id, load_vehicles_submenu, vehicle_commands, 1)
        CommandHandler.buildPagedMenuForGroup(gr_id, load_sam_submenu, sam_commands, 1)
    end
    missionCommands.addCommandForGroup(gr_id, "List Supplies", root_menu, function ()
        ctld.listSupplies(unit)
    end)

end


---@param part part
---@param unit Unit
function ctld.load(part, unit)
    -- If the unit is dynamic cargo capable, then spawn a cargo crate nearby, otherwise store in ctld.users
    local unit_id = unit:getID()

    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Cannot load while in air.", 5)
        return
    end

    local is_in_ctld_zone = false
    for _,zone in ipairs(zones) do
        if zone:isPointInsideZone(unit:getPoint()) then
            if utils.tableContains(ctld.allowed_load_zones, zone.zone_type) then
                is_in_ctld_zone = true
                break
            end
        end
    end
    if not is_in_ctld_zone then
        trigger.action.outTextForUnit(unit_id,"Cannot load: Not in a valid load zone.", 5)
        return
    end

    if ctld.player_cooldowns[unit_id] == nil then
        ctld.player_cooldowns[unit_id] = 0
    end

    local current_time = timer.getTime()
    if current_time < ctld.player_cooldowns[unit_id] then
        local wait_time = math.ceil(ctld.player_cooldowns[unit_id] - current_time)
        trigger.action.outTextForUnit(unit_id, "Cannot load: Wait "..wait_time.." seconds before loading again.", 5)
        return
    end
    ctld.player_cooldowns[unit_id] = current_time + ctld.load_cooldown_seconds

    local user = ctld.users[unit_id]
    if user == nil then
        ctld.users[unit_id] = {
            parts = {},
            unit = unit,
            is_dynamic_cargo = ctld.isDynamicCargoCapable(unit)
        }
        user = ctld.users[unit_id]
    end
    if not user then return end
    -- Checks weight and max parts / troops limits
    local aircraft_limit = ctld.getAircraftLimit(unit)
    if not aircraft_limit then
        trigger.action.outTextForUnit(unit_id, "Aircraft type not supported.", 5)
        return
    end

    -- check coalition supplies
    local unit_coal = unit:getCoalition()
    local supply_count = 0
    if unit_coal == coalition.side.BLUE then
        supply_count = stats.blue_supplies
    elseif unit_coal == coalition.side.RED then
        supply_count = stats.red_supplies
    end
    if part.req_supplies then
        if supply_count < part.req_supplies then
            trigger.action.outTextForUnit(unit_id, "Cannot load: Not enough supplies for "..part.desc..". Requires "..part.req_supplies.." supplies.", 10)
            return
        end
    end

    -- check max parts
    if part.type == ctld.AssetTypes.CARGO_CRATES or part.type == ctld.AssetTypes.VEHICLES or part.type == ctld.AssetTypes.SAM then
        if #user.parts >= aircraft_limit.max_parts then
            trigger.action.outTextForUnit(unit_id,"Cannot load part: "..part.desc..". Max parts limit reached.", 5)
            return
        end
    elseif part.type == ctld.AssetTypes.TROOPS then
        local current_troops = 0
        for _, p in ipairs(user.parts) do
            if p.type == ctld.AssetTypes.TROOPS then
                current_troops = current_troops + 1
            end
        end
        if (current_troops + 1) > aircraft_limit.max_troops then
            trigger.action.outTextForUnit(unit_id,"Cannot load troop: "..part.desc..". Max troops limit reached ("..aircraft_limit.max_troops..").", 5)
            return
        end
    end

    -- Checks weight limit
    if ctld.enable_weighted_loading then
        if not ctld.isDynamicCargoCapable(unit) then
            local total_weight = 0
            for _, p in ipairs(user.parts) do
                total_weight = total_weight + p.weight
            end
            total_weight = total_weight + part.weight
            if total_weight > aircraft_limit.weight_limit then
                trigger.action.outTextForUnit(unit_id,"Cannot load: "..part.desc..". Weight limit exceeded ("..aircraft_limit.weight_limit.." kg)", 5)
                return
            end
        end
    end

    -- Check if MOAB in stock
     -- Checks if MOAB in warehouse
    if part.name == ctld.CargoCrates.MOAB then
        local airbase = utils.getZoneOfUnitFromPosition(unit:getPoint())
        if not airbase or not airbase.airbase_name then
            trigger.action.outTextForUnit(unit_id, "> Unable to determine airbase for MOAB deployment.", 10)
            return
        end
        local in_stock = false
        ab = Airbase.getByName(airbase.airbase_name)
        if ab then
            local warehouse = ab:getWarehouse()
                local moab_count = warehouse:getItemCount(WarehouseManager.Flags.GBU_43)
                if moab_count and moab_count > 0 then
                    in_stock = true
                    warehouse:removeItem(WarehouseManager.Flags.GBU_43, 1)
                end
        end
        if not in_stock then
            trigger.action.outTextForUnit(unit_id, "> No MOABs available in warehouse for deployment.", 10)
            return
        end
    end

    -- Add part to user's cargo
    if unit:getCoalition() == coalition.side.BLUE then
        if part.req_supplies then
            stats.blue_supplies = stats.blue_supplies - part.req_supplies
        end
    elseif unit:getCoalition() == coalition.side.RED then
        if part.req_supplies then
            stats.red_supplies = stats.red_supplies - part.req_supplies
        end
    end

    table.insert(user.parts, part)
    if user.is_dynamic_cargo then

        if part.type == ctld.AssetTypes.TROOPS then
            ctld.spawnTroop(unit, part)
            trigger.action.outTextForUnit(unit_id, "Troop deployed.", 5)
        elseif part.type == ctld.AssetTypes.CARGO_CRATES or part.type == ctld.AssetTypes.VEHICLES or part.type == ctld.AssetTypes.SAM then
            -- spawn cargo crate nearby 
            ctld.spawnCargoCrate(unit, part)
            trigger.action.outTextForUnit(unit_id, string.format("A %s crate weighing %d kg has been brought out and is at your 12 or 6 o'clock", part.desc, part.weight), 5)
        end
    else
        trigger.action.outTextForUnit(unit_id, "Loaded: "..part.desc, 5)
    end
end

---@param unit Unit
function ctld.unpack(unit)
    --[[
        Finds all nearby crates that belong to ctld (name starts with CTLD_)
    ]]

    local unit_pos = unit:getPoint()
    if unit:inAir() then
        trigger.action.outTextForUnit(unit:getID(),"Cannot unpack while in air.", 5)
        return
    end

    local is_in_ctld_zone = utils.getZoneOfUnitFromPosition(unit_pos) ~= nil
    if not is_in_ctld_zone and not ctld.allow_unpacking_in_zones then
        trigger.action.outTextForUnit(unit:getID(),"Cannot unpack in this area.", 5)
        return
    end

    -- search for crates nearby and unpack them
    local vol = {
        id = world.VolumeType.SPHERE,
        params = {
            point = unit_pos,
            radius = ctld.search_radius
        }
    }

    -- Group crates by unit type
    local crates_by_type = {}  -- {unit_name = {objs = {obj1, obj2}, points = {p1, p2}}}  

    local crates_nearby = {}
    world.searchObjects({Object.Category.CARGO}, vol, function(obj)
        if obj and obj:isExist() and obj.getName then
            local cargoName = obj:getName()
            if not obj:getCoalition() == unit:getCoalition() then
                return true
            end

            local point = obj:getPoint()
            if land.getSurfaceType({x = point.x, y = point.z}) == land.SurfaceType.WATER then
                return true
            end


            -- checks if cargo is starting with "CTLD_" to identify it as a valid crate

            if not cargoName:match("^CTLD_.+_%d+$") then
                return true
            end

            -- name is as follows:  string.format("CTLD_%s_%d", part.name, ctld.getNextGroupId()),
            local unit_name = cargoName:match("^CTLD_(.+)_%d+$")
            MissionLogger:info(unit_name)
            
            if utils.tableContains(ctld.CargoCrates, unit_name) then
                return true
            end
            table.insert(crates_nearby, obj)
            -- Group crates by type
            if not crates_by_type[unit_name] then
                crates_by_type[unit_name] = {objs = {}, points = {}}
            end
            table.insert(crates_by_type[unit_name].objs, obj)
            table.insert(crates_by_type[unit_name].points, point)
        end
        return true
    end)

    -- First, identify all groups and check if they have all required parts
    local groups_to_process = {}  -- {group_name = {parts = {part1, part2}, all_present = true}}
    local standalone_parts = {}   -- Parts without group_requirement
    
    -- Build group requirements map
    local group_requirements = {}  -- {group_name = {part1_name, part2_name, ...}}
    for _, part in ipairs(ctld.parts) do
        if part.group_requirement then
            if not group_requirements[part.group_requirement] then
                group_requirements[part.group_requirement] = {}
            end
            table.insert(group_requirements[part.group_requirement], part.name)
        end
    end
    
    -- Check which groups have all parts present
    for group_name, required_part_names in pairs(group_requirements) do
        local all_present = true

        local missing_parts = {}
        for _, required_part_name in ipairs(required_part_names) do
            if not crates_by_type[required_part_name] then
                all_present = false
                -- Find the part def for nice description
                for _, part in ipairs(ctld.parts) do
                    if part.name == required_part_name then
                        table.insert(missing_parts, part.desc)

                        break
                    end
                end
            end
        end
        
        if all_present then
            groups_to_process[group_name] = {parts = required_part_names, all_present = true}
        else
            -- Do not show the message if no crates of any required parts are present
            if #missing_parts ~= #required_part_names then
                trigger.action.outTextForUnit(unit:getID(),
                    string.format("%s incomplete. Missing : %s", group_name, table.concat(missing_parts, ", ")), 5)
            end

        end
    end
    
    -- Identify standalone parts (no group_requirement)
    for unit_name, crate_data in pairs(crates_by_type) do
        local part_def = nil
        for _, part in ipairs(ctld.parts) do
            if part.name == unit_name then
                part_def = part
                break
            end
        end
        
        if part_def and not part_def.group_requirement then
            table.insert(standalone_parts, unit_name)
        end
    end

    -- Process standalone parts first (spawn individually)
    for _, unit_name in ipairs(standalone_parts) do
        local crate_data = crates_by_type[unit_name]
        local part_def = nil
        for _, part in ipairs(ctld.parts) do
            if part.name == unit_name then
                part_def = part
                break
            end
        end

        if part_def then
            local crates_required = part_def.crates_required or 1
            local available_crates = #crate_data.objs

            if available_crates < crates_required then
                trigger.action.outTextForUnit(unit:getID(), string.format("%s requires %d crates, only %d available.",part_def.desc, crates_required, available_crates), 5)
            else
                -- Calculate how many units we can spawn
                local units_to_create = math.floor(available_crates / crates_required)

                for i = 1, units_to_create do
                    -- Find closest crate for this unit
                    local start_idx = (i - 1) * crates_required + 1
                    local closest_point = crate_data.points[start_idx]
                    local min_dist = 999999
                    
                    for j = start_idx, start_idx + crates_required - 1 do
                        local dist = mist.utils.get2DDist(unit_pos, crate_data.points[j])
                        if dist < min_dist then
                            min_dist = dist
                            closest_point = crate_data.points[j]
                        end
                    end

                    -- Spawn at closest crate location
                    local u_id = mist.getNextUnitId()
                    local unit_table = {
                        type = unit_name,
                        unitId = u_id,
                        name = "unpacked"..unit_name .. "_" .. u_id,
                        x = closest_point.x,
                        y = closest_point.z,
                    }
                    
                    -- Spawn as individual group
                    local spawned_group = mist.dynAdd({
                        units = {unit_table},
                        country = unit:getCountry(),
                        category = Group.Category.GROUND,
                    })
                    
                    if spawned_group then
                        table.insert(ctld.placed_assets, {
                            unit_name = unit_table.name,
                            asset_name = unit_name,
                            point = closest_point,
                            type = part_def.type or ctld.AssetTypes.VEHICLES,
                            coalition = unit:getCoalition(),
                            is_group = false
                        })
                    end

                    -- Destroy the crates used for this unit
                    for j = start_idx, start_idx + crates_required - 1 do
                        if crate_data.objs[j] then
                            if crate_data.objs[j].isExist and crate_data.objs[j]:isExist() then
                                crate_data.objs[j]:destroy()
                            end
                        end
                    end

                    trigger.action.outTextForUnit(unit:getID(),string.format("Unpacked: %s (used %d crates)", part_def.desc, crates_required), 2)
                end
            end
        end
    end
    
    -- Process groups that have all required parts
    for group_name, group_data in pairs(groups_to_process) do
        if group_data.all_present then
            local group_units = {}  -- All units for this SAM group
            local group_centroid_x, group_centroid_z = 0, 0
            local total_parts = 0
            
            -- Build units array for the SAM group
            for _, part_name in ipairs(group_data.parts) do
                local crate_data = crates_by_type[part_name]
                if crate_data then
                    local part_def = nil
                    for _, part in ipairs(ctld.parts) do
                        if part.name == part_name then
                            part_def = part
                            break
                        end
                    end
                    
                    if part_def then
                        local crates_required = part_def.crates_required or 1
                        local available_crates = #crate_data.objs
                        
                        -- Calculate how many of this part we can spawn (allows multiple launchers)
                        local parts_to_spawn = math.floor(available_crates / crates_required)
                        
                        for i = 1, parts_to_spawn do
                            -- Use crate location for each instance
                            local crate_idx = (i - 1) * crates_required + 1
                            local spawn_point = crate_data.points[crate_idx]
                            
                            local u_id = mist.getNextUnitId()
                            local unit_table = {
                                type = part_name,
                                unitId = u_id,
                                name = string.format("%s_%s_%d", group_name, part_name, u_id),
                                x = spawn_point.x,
                                y = spawn_point.z,
                            }
                            table.insert(group_units, unit_table)
                            
                            group_centroid_x = group_centroid_x + spawn_point.x
                            group_centroid_z = group_centroid_z + spawn_point.z
                            total_parts = total_parts + 1
                        end
                        
                        -- Destroy all crates used
                        local crates_to_destroy = parts_to_spawn * crates_required
                        for j = 1, crates_to_destroy do
                            if crate_data.objs[j] then
                                if crate_data.objs[j].isExist and crate_data.objs[j]:isExist() then
                                    crate_data.objs[j]:destroy()
                                end
                            end
                        end
                    end
                end
            end
            
            -- Spawn the entire SAM group as one unit
            if #group_units > 0 then
                group_centroid_x = group_centroid_x / total_parts
                group_centroid_z = group_centroid_z / total_parts
                
                local group_id = mist.getNextGroupId()
                local sam_group_name = string.format("CTLD_%s_%d", group_name:gsub(" ", "_"), group_id)
                
                local spawned_group = mist.dynAdd({
                    units = group_units,
                    country = unit:getCountry(),
                    category = Group.Category.GROUND,
                    groupName = sam_group_name,
                })
                
                if spawned_group then
                    -- Track the GROUP for persistence (critical for SAM systems)
                    table.insert(ctld.placed_assets, {
                        group_name = sam_group_name,
                        asset_name = group_name,
                        point = {x = group_centroid_x, y = 0, z = group_centroid_z},
                        type = ctld.AssetTypes.SAM,
                        coalition = unit:getCoalition(),
                        is_group = true,
                        unit_count = #group_units
                    })
                    
                    trigger.action.outTextForUnit(unit:getID(),
                        string.format("Unpacked %s with %d units", group_name, #group_units), 5)
                else
                    trigger.action.outTextForUnit(unit:getID(), 
                        string.format("Failed to spawn %s", group_name), 5)
                end
            end
        end
    end
end

function ctld.unload(unit)
    -- body
    local unit_id = unit:getID()
    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Cannot unload while in air.", 5)
        return
    end

    if ctld.isDynamicCargoCapable(unit) then
        -- reject, user has to unload using dcs cargo system
        trigger.action.outTextForUnit(unit_id,"Cannot unload using CTLD. Use dynamic cargo system to unload.", 5)
    else
        -- remove part from ctld.users and
        -- spawn the cratre
        local user = ctld.users[unit_id]
        if user == nil or #user.parts == 0 then
            trigger.action.outTextForUnit(unit_id,"No cargo to unload.", 5)
            return
        end
        local part_to_spawn = user.parts[#user.parts]
        if part_to_spawn.type == ctld.AssetTypes.TROOPS then
            ctld.spawnTroop(unit, part_to_spawn)
        else
            ctld.spawnCargoCrate(unit, part_to_spawn)
        end

        local part = table.remove(user.parts)
        
        trigger.action.outTextForUnit(unit_id,"Unloaded "..part.desc, 5)
    end
end

function ctld.loadNearbyCrate(unit)
    local unit_id = unit:getID()

    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Cannot load while in air.", 5)
        return
    end

    if ctld.isDynamicCargoCapable(unit) then
        trigger.action.outTextForUnit(unit_id,"Cannot load nearby crate: Use dynamic cargo system to load crates.", 5)
        return
    end

    -- Get aircraft limits
    local aircraft_limit = ctld.getAircraftLimit(unit)
    if not aircraft_limit then
        trigger.action.outTextForUnit(unit_id, "Aircraft type not supported.", 5)
        return
    end

    -- search for crates nearby
    local vol = {
        id = world.VolumeType.SPHERE,
        params = {
            point = unit:getPoint(),
            radius = ctld.search_radius
        }
    }
    local crates_nearby = {}
    world.searchObjects({Object.Category.CARGO}, vol, function(obj)
        if obj and obj:isExist() and obj.getName then
            local cargoName = obj:getName()
            -- Check coalition match
            if obj:getCoalition() ~= unit:getCoalition() then
                return true
            end
            -- checks if cargo is starting with "CTLD_" to identify it as a valid crate
            if cargoName:match("^CTLD_.+_%d+$") then
                table.insert(crates_nearby, obj)
            end
        end
        return true
    end)

    local sorted_crates_by_distance = {}
    for _, crate in ipairs(crates_nearby) do
        if crate and crate:isExist() then
            local dist = mist.utils.get2DDist(unit:getPoint(), crate:getPoint())
            table.insert(sorted_crates_by_distance, {crate = crate, distance = dist})
        end
    end
    table.sort(sorted_crates_by_distance, function(a,b) return a.distance < b.distance end)
    if #sorted_crates_by_distance == 0 then
        trigger.action.outTextForUnit(unit_id,"No crates nearby to load.", 5)
        return
    end
    local closest_crate = sorted_crates_by_distance[1].crate
    
    -- Initialize user if needed
    ctld.users[unit_id] = ctld.users[unit_id] or {
        parts = {},
        unit = unit,
        is_dynamic_cargo = false
    }
    local user = ctld.users[unit_id]
    
    local crate_name = closest_crate:getName()
    local part_name = crate_name:match("^CTLD_(.+)_%d+$")
    local part_def = nil
    for _, part in ipairs(ctld.parts) do
        if part.name == part_name then
            part_def = part
            break
        end
    end
    
    if part_def == nil then return end

    -- Check max parts/troops limits
    if part_def.type == ctld.AssetTypes.CARGO_CRATES or part_def.type == ctld.AssetTypes.VEHICLES or part_def.type == ctld.AssetTypes.SAM then
        if #user.parts >= aircraft_limit.max_parts then
            trigger.action.outTextForUnit(unit_id,"Cannot load crate: Max parts limit reached.", 5)
            return
        end
    elseif part_def.type == ctld.AssetTypes.TROOPS then
        local current_troops = 0
        for _, p in ipairs(user.parts) do
            if p.type == ctld.AssetTypes.TROOPS then
                current_troops = current_troops + 1
            end
        end
        if (current_troops + 1) > aircraft_limit.max_troops then
            trigger.action.outTextForUnit(unit_id,"Cannot load troop: Max troops limit reached ("..aircraft_limit.max_troops..").", 5)
            return
        end
    end

    -- Check weight limit
    local total_weight = 0
    for _, p in ipairs(user.parts) do
        total_weight = total_weight + p.weight
    end
    total_weight = total_weight + part_def.weight
    if total_weight > aircraft_limit.weight_limit then
        trigger.action.outTextForUnit(unit_id,"Cannot load: Weight limit exceeded ("..aircraft_limit.weight_limit.." kg)", 5)
        return
    end

    -- All checks passed - load the crate
    if closest_crate:isExist() then
        table.insert(user.parts, part_def)
        closest_crate:destroy()
        trigger.action.outTextForUnit(unit_id, "Loaded: "..part_def.desc, 5)
    end
end

function ctld.unitAttack(unit)
    -- Find nearby vehicles and assigns them a route for the nearest enemy zone
    local vol =
    {
        id = world.VolumeType.SPHERE,
        params =
        {
            point = unit:getPoint(),
            radius = ctld.search_radius
        }
    }

    local closest_enemy_zone = nil
    local min_dist = 999999
    local unit_pos = unit:getPoint()
    local unit_coalition = unit:getCoalition()
    for _, zone in ipairs(zones) do
        if zone.side ~= unit_coalition then
            local dist = mist.utils.get2DDist(unit_pos, zone.zone.point)
            if dist < min_dist then
                min_dist = dist
                closest_enemy_zone = zone
            end
        end
    end
    if not closest_enemy_zone then return end


    world.searchObjects({Object.Category.UNIT}, vol, function(obj)
        if obj and obj:isExist() and obj.getName then
            --starts with unpacked
            if obj:getName():match("^unpacked.+") == nil then
                return true
            end

            local objType = obj:getTypeName()
            for _,part in ipairs(ctld.parts) do
                if part.can_move and objType == part.name then
                    mist.groupToPoint(obj:getGroup(), closest_enemy_zone.zone.point)
                    trigger.action.outTextForUnit(unit:getID(),
                        string.format("Assigned %s to attack %s", part.desc, closest_enemy_zone.name), 5)
                    return false
                end
            end
        end
        return true
    end)

end


---@param unit Unit
function ctld.listSupplies(unit)
    --List the supplies in the zone
    local unit_coalition = unit:getCoalition()
    local supply_count = 0
    if unit_coalition == coalition.side.BLUE then
        supply_count = stats.blue_supplies
    elseif unit_coalition == coalition.side.RED then
        supply_count = stats.red_supplies
    end

    trigger.action.outTextForUnit(unit:getID(), "Coalition has ".. supply_count .. " supplies.", 10)
        

end

function ctld.getAircraftLimit(unit)
    for _, acft_limit in ipairs(ctld.aircraft_limits) do
        if unit:getTypeName() == acft_limit.aircraft_type then
            return acft_limit
        end
    end
    return nil
end

function ctld.listOnboardCargo(unit)
    local unit_id = unit:getID()
    local user = ctld.users[unit_id]
    if ctld.isDynamicCargoCapable(unit) then
        trigger.action.outTextForUnit(unit_id,"Cannot list cargo using CTLD. Use dynamic cargo system to see onboard cargo.", 15)
        return
    end

    if user == nil or #user.parts == 0 then
        trigger.action.outTextForUnit(unit_id,"No cargo onboard.", 15)
        return
    end
    local cargo_list = "Loaded Cargo:\n"
    local part_count = {}
    for _, part in ipairs(user.parts) do
        if part_count[part.desc] == nil then
            part_count[part.desc] = 1
        else
            part_count[part.desc] = part_count[part.desc] + 1
        end
    end
    for part_desc, count in pairs(part_count) do
        -- find the amount of crates required to build
        local crates_required = 1
        for _, part in ipairs(ctld.parts) do
            if part.desc == part_desc then
                crates_required = part.crates_required or 1
                break
            end
        end

        cargo_list = cargo_list .. string.format("%s x%d (required: %s)\n", part_desc, count,crates_required)
    end

    --weight
    local max_weight = ctld.getAircraftLimit(unit).weight_limit or 0
    local total_weight = 0
    for _, part in ipairs(user.parts) do
        total_weight = total_weight + part.weight
    end
    cargo_list = cargo_list .. string.format("Total Weight: %d / %d kg", total_weight, max_weight
    )

    trigger.action.outTextForUnit(unit_id, cargo_list, 30)
end

function ctld.isDynamicCargoCapable(unit)
    local unitType = unit:getTypeName()
    for _, cargoUnit in ipairs(ctld.dynamic_cargo_capable_units) do
        if unitType == cargoUnit then
            return true
        end
    end
    return false
end

function ctld.getSecureDistanceFromUnit(unit)
    local rotor_diameter = 19    -- meters  -- ok for UH & CH47
    local secure_dist_from_unit = rotor_diameter
    if unit then
        local unitUserBox = unit:getDesc().box
        if unitUserBox then
            if math.abs(unitUserBox.max.x) >= math.abs(unitUserBox.min.x) then
                secure_dist_from_unit = math.abs(unitUserBox.max.x) + (rotor_diameter/2)
            else
                secure_dist_from_unit = math.abs(unitUserBox.min.x) + (rotor_diameter/2)
            end
	    end
	end
    return secure_dist_from_unit
end

function ctld.getPointAt12Oclock(unit, offset)
    return ctld.getPointAtDirection(unit, offset, 0)
end
function ctld.getPointAt6Oclock(unit, offset)
    return ctld.getPointAtDirection(unit, offset, math.pi)
end

function ctld.getPointAtDirection(unit, offset, direction_in_radian)
    if offset == nil then
        offset = ctld.getSecureDistanceFromUnit(unit)
    end

    local randomOffsetX = math.random(0, ctld.random_crate_spacing * 2) - ctld.random_crate_spacing
    local randomOffsetZ = math.random(0, ctld.random_crate_spacing)

    local position = unit:getPosition()
    
    ---@diagnostic disable-next-line: deprecated
    local angle    = math.atan2(position.x.z, position.x.x) + direction_in_radian
    local xOffset  = math.cos(angle) * (offset + randomOffsetX)
    local zOffset  = math.sin(angle) * (offset + randomOffsetZ)
    local point    = unit:getPoint()
    return { x = point.x + xOffset, z = point.z + zOffset, y = point.y }
end


---@param unit Unit
---@param part part
function ctld.spawnCargoCrate(unit,part)
    if #ctld.placed_assets >= ctld.max_placed_assets then
        trigger.action.outTextForUnit(unit:getID(), "Cannot load: Maximum placed assets limit reached ("..ctld.max_placed_assets..").", 5)
        return
    end


    local point = ctld.getPointAt12Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    if unit:getTypeName() == "C-130J-30" then
        point = ctld.getPointAt6Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    end
    MissionLogger:info(string.format("Spawning cargo crate %s", part.name))

    local type_to_spawn = ctld.CargoCrates.SuppliesCrate
    if utils.tableContains(ctld.CargoCrates, part.name) then
        type_to_spawn = part.name
    end

    local crate = mist.dynAddStatic({
        type = type_to_spawn,
        name = string.format("CTLD_%s_%d", part.name, ctld.getNextGroupId()),
        country = unit:getCountry(),
        category = "Cargos",
        x = point.x,
        y = point.z
    })
    if crate then
        table.insert(ctld.placed_assets, {
            unit_name = crate.name,
            asset_name = type_to_spawn,
            point = point,
            type = ctld.AssetTypes.CARGO_CRATES,
            coalition = unit:getCoalition()
        })
    end
end

---@param unit Unit
---@param part part
function ctld.spawnTroop(unit,part)
    if #ctld.placed_assets >= ctld.max_placed_assets then
        trigger.action.outTextForUnit(unit:getID(), "Cannot load: Maximum placed assets limit reached ("..ctld.max_placed_assets..").", 5)
        return
    end

    local point = ctld.getPointAt12Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    if unit:getTypeName() == "C-130J-30" then
        point = ctld.getPointAt6Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    end

    local u_id = mist.getNextUnitId()
    local unit_name = part.name .. "_" .. u_id
    local troop = mist.dynAdd({
    units = {
        {
        type = part.name,
        unitId = u_id,
        name = unit_name,
        x = point.x,
        y = point.z,
    }
    },
    country = unit:getCountry(),
    category = Group.Category.GROUND,
    })
    if troop then
        table.insert(ctld.placed_assets, {
            unit_name = unit_name,
            asset_name = part.name,
            point = point,
            type = ctld.AssetTypes.TROOPS,
            coalition = unit:getCoalition()
        })
    end
end