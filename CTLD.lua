ctld = {}

ctld.load_cooldown_seconds = 1  -- Cooldown between load commands per player
ctld.player_cooldowns = {}  -- store for player cooldowns

---@enum AssetTypes
ctld.AssetTypes = {
    TROOPS = "Troops",
    CARGO_CRATES = "CARGO_CRATES",
    VEHICLES = "Vehicles",
    SAM = "SAM",
    STATIC = "STATIC"
}

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
    {aircraft_type = "UH-60L",      max_parts = 2,  max_troops = 8, weight_limit = 2000},
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
---@field category string|nil
---@field shape_name string|nil

---@type Asset[]
ctld.placed_assets = {} -- store for persistence, save function will check all units and statics are alive before saving



-- Tracks operation load actions by unit id.
-- [unit_id] = { [part_name] = count }
---@class AirliftOperationTracking
---@field operation_type OperationTypes,
---@field load_zone_name string
---@field target_zone_name string
---@field manifest Manifest
---@field loaded_parts table<string,number>

---@type table<number,AirliftOperationTracking>
ctld.airlift_operation_tracking = {}

---@class OperationContext
---@field operation_id string|nil
---@field operation_type OperationTypes|nil
---@field load_zone_name string|nil
---@field target_zone_name string|nil

---@type table<number,OperationContext>
ctld.operation_contexts = {}

---@class OperationAsset
---@field unit_name string
---@field part_name string
---@field object_type string
---@field point vec3|nil
---@field coalition any|nil
---@field operation_id string|nil

---@type table<string,OperationAsset[]>
ctld.operation_assets = {}

---@class ConstructedFARP
---@field farp_name string
---@field point vec3
---@field coalition any
---@field linked_zone ZoneHandler|nil
---@field display_name string|nil
---@field mark_id any|nil

---@type ConstructedFARP[]
ctld.FARPs = {} -- store for persistence


ctld.dynamic_cargo_capable_units = {
    -- "CH-47Fbl1",
    -- "UH-1H",
    -- "Mi-8MT",
    -- "Mi-24P",
    "C-130J-30"
}

-- Required unpacked vehicles to assemble a CTLD-built FARP.
ctld.farp_vehicle_requirements = {
    "Hummer",
    "M 818",
    "M978 HEMTT Tanker"
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
---@field supply_amount number|nil
---@field squad_id string|nil
---@field troop_slots number|nil

---@type part[]
ctld.parts = {
    {name = "Hawk ln",          desc = "HAWK Launcher",       weight = 2000, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 100},
    {name = "Hawk tr",          desc = "HAWK Track Radar",    weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 400},
    {name = "Hawk sr",          desc = "HAWK Search Radar",   weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 400},
    {name = "Hawk pcp",         desc = "HAWK PCP",            weight = 200, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 100},
    {name = "Hawk cwar",        desc = "HAWK CWAR",           weight = 200, type = ctld.AssetTypes.SAM, group_requirement = "Hawk Battery", req_supplies = 100},


    {name = "NASAMS_LN_C",          desc = "NASAMS Launcher 120C",       weight = 2000, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 100},
    {name = "NASAMS_Radar_MPQ64F1",          desc = "NASAMS Search/Track Radar",    weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 400},
    {name = "NASAMS_Command_Post",          desc = "NASAMS Command Post",   weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "NASAMS System", req_supplies = 50},

    {name = "Patriot ln", desc = "Patriot Launcher",    weight = 2000, type = ctld.AssetTypes.SAM, group_requirement = "Patriot Battery", req_supplies = 150},
    {name = "Patriot str", desc = "Patriot Radar", weight = 1000, type = ctld.AssetTypes.SAM, group_requirement = "Patriot Battery", req_supplies = 600},
    {name = "Patriot ECS", desc = "Patriot ECS", weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Patriot Battery", req_supplies = 150},
    {name = "Patriot AMG", desc = "Patriot AMG (optional)", weight = 500, type = ctld.AssetTypes.SAM, group_requirement = "Patriot Battery", req_supplies = 150},


    {name = "Soldier stinger",  desc = "Stinger",     weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},
    {name = "Soldier M4 GRG", desc = "Soldier", weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},
    {name = "Soldier M249", desc = "Soldier M249", weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},
    {name = "Paratrooper RPG-16", desc = "Paratrooper RPG-16", weight = 100, type = ctld.AssetTypes.TROOPS, req_supplies = 5},


    {name = "M1097 Avenger", desc="M1097 Avenger", weight = 3900, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 300},
    {name = "Roland ADS", desc="Roland ADS", weight = 5000, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 400},
    {name = "Gepard", desc="Gepard AAA", weight = 5000, type = ctld.AssetTypes.SAM, crates_required = 2, can_move = true, req_supplies = 400},
    {name = "HEMTT_C-RAM_Phalanx", desc="LPWS C-RAM", weight = 7000, type = ctld.AssetTypes.SAM, crates_required = 3, can_move = true, req_supplies = 600},

    {name = "M1043 HMMWV Armament", desc="Humvee - MG", weight = 2000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 150},
    {name = "M1045 HMMWV TOW", desc="Humvee - TOW", weight = 2000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 200},
    {name = "MaxxPro_MRAP", desc="Light Tank - MRAP", weight = 14500, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 300, crates_required = 2},

    {name = "LAV-25", desc="Med Tank - LAV-25", weight = 12800, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 100, crates_required = 3},
    
    {name = "M-1 Abrams", desc="Heavy Tank - Abrams", weight = 10000, type = ctld.AssetTypes.VEHICLES, crates_required = 4, can_move = true, req_supplies = 150},

    {name = "Hummer", desc="Hummer - JTAC", weight = 1000, type = ctld.AssetTypes.VEHICLES, req_supplies = 50},
    {name = "M 818", desc="M-818 Ammo Truck", weight = 1000, type = ctld.AssetTypes.VEHICLES, req_supplies = 80},
    {name = "M978 HEMTT Tanker", desc="M978 HEMTT Tanker", weight = 1000, type = ctld.AssetTypes.VEHICLES, req_supplies = 80},

    {name = "FPS-117", desc="EWR Radar", weight = 10000, type = ctld.AssetTypes.VEHICLES, crates_required = 5, req_supplies = 800},

    {name = "MLRS", desc="MLRS", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 100},
    {name = "SpGH_Dana", desc="SpGH DANA", weight = 1000, type = ctld.AssetTypes.VEHICLES, can_move = true, req_supplies = 100},


    {name = CargoCrates.SUPPLY_CRATE, desc = "Supply Crate", weight = 100, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = Config.ctld.supply_crate_supplies, supply_amount = Config.ctld.supply_crate_supplies},
    {name = "container_cargo",  desc = "Cargo Container",               weight = 1000, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    {name = "iso_container",    desc = "Large Container",     weight = 4000, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    {name = "iso_container_small",desc = "Small Container",   weight = 2000, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    {name = "M92_10Ft_Container",desc = "Clean Container",    weight = 1500, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    {name = "gbu_43b_airdrop",  desc = "MOAB",                 weight = 9000, type = ctld.AssetTypes.CARGO_CRATES},
    {name = "cds_barrels",     desc = "CDS Barrels",        weight = 200, type = ctld.AssetTypes.CARGO_CRATES, req_supplies = 5},
    --{name = "cds_crate",       desc = "CDS Crate",           weight = 200, type = ctld.AssetTypes.CARGO_CRATES},
}

InfantrySquads = {} do

    InfantrySquads.PREFIX = "squad_"   -- spawned group name prefix

    ---@type table<string, table>
    InfantrySquads.active = {}

    ---@enum SquadIds
    InfantrySquads.SquadIds = {
        ASSAULT  = "assault",
        MORTAR   = "mortar",
        ENGINEER = "engineer",
        SABOTAGE = "sabotage",
        STINGER  = "stinger",
        CAPTURE  = "capture",
        JTAC     = "jtac",
    }

    InfantrySquads.SQUAD_DEFS = {
        {
            id = InfantrySquads.SquadIds.ASSAULT,
            desc = "Assault Squad",
            roles = { "INFANTRY_AT", "INFANTRY", "INFANTRY", "INFANTRY" },
            behaviour = "assault",
        },
        {
            id = InfantrySquads.SquadIds.MORTAR,
            desc = "Mortar Team",
            roles = { "MORTAR" },
            behaviour = "mortar",
        },
        {
            id = InfantrySquads.SquadIds.ENGINEER,
            desc = "Engineers (+supply)",
            roles = { "INFANTRY" },
            behaviour = "engineer",
        },
        {
            id = InfantrySquads.SquadIds.SABOTAGE,
            desc = "Sabotage Team (-supply)",
            roles = { "INFANTRY_AT", "INFANTRY" },
            behaviour = "sabotage",
        },
        {
            id = InfantrySquads.SquadIds.STINGER,
            desc = "Stinger AD",
            roles = { "MANPADS" },
            behaviour = "static",
        },
        {
            id = InfantrySquads.SquadIds.CAPTURE,
            desc = "Capture Team",
            roles = { "INFANTRY_AT", "INFANTRY" },
            behaviour = "capture",
        },
        {
            id = InfantrySquads.SquadIds.JTAC,
            desc = "JTAC (ground FAC)",
            roles = { "INFANTRY" },
            behaviour = "jtac",
        },
    }

    ---@param squad_id SquadIds
    ---@return table|nil def
    function InfantrySquads.getDef(squad_id)
        for _, def in ipairs(InfantrySquads.SQUAD_DEFS) do
            if def.id == squad_id then return def end
        end
        return nil
    end

    ---@param squad_id SquadIds
    ---@return table cfg per-squad config block (Config.squads[squad_id]) or {}
    function InfantrySquads.cfg(squad_id)
        local squads = Config.squads or {}
        local block = squads[squad_id]
        if type(block) == "table" then return block end
        return {}
    end

    --- Country pool of the given coalition (from the era system selector).
    ---@param side coalition.side
    ---@return number[]
    local function countryPool(side)
        local selector = Config.era_system and Config.era_system.coalition_selector
        if selector and selector[side] then return selector[side] end
        return {}
    end

    ---@param role string
    ---@param pool number[]
    ---@return string|nil dcs_type
    local function pickTypeForRole(role, pool)
        local candidates = {}
        for _, country_id in ipairs(pool) do
            local entries = EraSystem.getGroundUnits({ role = role, country = country_id })
            for _, entry in ipairs(entries) do
                candidates[entry.type] = true
            end
        end
        local list = {}
        for dcs_type in pairs(candidates) do list[#list + 1] = dcs_type end
        if #list == 0 then return nil end
        return list[math.random(#list)]
    end

    --- True if every role the squad needs can be filled for this side+era.
    ---@param def table squad definition
    ---@param side coalition.side
    ---@return boolean
    function InfantrySquads.isAvailable(def, side)
        if not (Config.squads and Config.squads.enabled) then return false end
        local pool = countryPool(side)
        if #pool == 0 then return false end
        local seen = {}
        for _, role in ipairs(def.roles) do
            if not seen[role] then
                seen[role] = true
                if not pickTypeForRole(role, pool) then return false end
            end
        end
        return true
    end

    ---@param def table
    ---@param side coalition.side
    ---@return string[]|nil dcs_types (one per soldier) or nil if a role is unfillable
    function InfantrySquads.composeTypes(def, side)
        local cfg = InfantrySquads.cfg(def.id)
        local soldiers = cfg.soldiers or #def.roles
        local pool = countryPool(side)
        local types = {}
        for i = 1, soldiers do
            local role = def.roles[((i - 1) % #def.roles) + 1]
            local dcs_type = pickTypeForRole(role, pool)
            if not dcs_type then return nil end
            types[#types + 1] = dcs_type
        end
        return types
    end

    ---@param def table
    ---@param side coalition.side
    ---@param point vec3
    ---@return boolean ok, ZoneHandler|nil zone, string|nil err
    function InfantrySquads.validateDeploy(def, side, point)
        local b = def.behaviour

        if b == "engineer" then
            -- Must be inside a friendly zone.
            for _, zone in ipairs(zones) do
                if zone.side == side and zone:isPointInsideZone(point) then
                    return true, zone, nil
                end
            end
            return false, nil, "Engineers must be deployed inside a friendly zone."

        elseif b == "sabotage" then
            -- Within configured range of an ENEMY zone.
            local cfg = InfantrySquads.cfg(def.id)
            local range = cfg.range or 2000
            local best, best_d
            for _, zone in ipairs(zones) do
                if zone.side ~= side and zone.side ~= coalition.side.NEUTRAL then
                    local d = mist.utils.get2DDist(point, zone.zone.point)
                    if d <= range and (not best_d or d < best_d) then
                        best, best_d = zone, d
                    end
                end
            end
            if best then return true, best, nil end
            return false, nil, string.format(
                "Sabotage team must be deployed within %d m of an enemy zone.", range)

        elseif b == "capture" then
            -- Inside a NEUTRAL zone.
            for _, zone in ipairs(zones) do
                if zone.side == coalition.side.NEUTRAL and zone:isPointInsideZone(point) then
                    return true, zone, nil
                end
            end
            return false, nil, "Capture team must be deployed inside a neutral zone."
        end

        -- assault / mortar / static / jtac: no placement restriction.
        return true, nil, nil
    end

    ---@param group_name string
    ---@return string|nil squad_id
    function InfantrySquads.squadIdFromGroupName(group_name)
        local marker = InfantrySquads.PREFIX
        local s = string.find(group_name, marker, 1, true)
        if not s then return nil end
        local rest = string.sub(group_name, s + #marker)        -- "<id>_<gid>"
        local id = string.match(rest, "^(%a+)_%d+$")
        return id
    end

    ---@param def table squad definition
    ---@param unit Unit deploying carrier
    ---@return string|nil group_name, string|nil err
    function InfantrySquads.spawnInactive(def, unit)
        local side = unit:getCoalition()
        local types = InfantrySquads.composeTypes(def, side)
        if not types or #types == 0 then
            return nil, "No era-eligible units to form this squad."
        end

        local base = ctld.getPointAt12Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
        if unit:getTypeName() == "C-130J-30" then
            base = ctld.getPointAt6Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
        end

        local heading = mist.getHeading(unit) or 0
        local group_name = Config.ctld.packed_asset_prefix .. InfantrySquads.PREFIX
            .. def.id .. "_" .. ctld.getNextGroupId()

        local units_spec = {}
        for i, dcs_type in ipairs(types) do
            local u_id = mist.getNextUnitId()
            local a = (i / #types) * 2 * math.pi
            units_spec[i] = {
                type = dcs_type,
                unitId = u_id,
                name = group_name .. "_u" .. i .. "_" .. u_id,
                x = base.x + 6 * math.cos(a),
                y = base.z + 6 * math.sin(a),
                heading = heading,
            }
        end

        local spawned = mist.dynAdd({
            units = units_spec,
            groupName = group_name,
            country = unit:getCountry(),
            category = Group.Category.GROUND,
        })
        if not spawned then return nil, "Failed to spawn squad." end

        local op_context = ctld.fetchOperationContextForUnit(unit)
        if op_context and op_context.operation_id then
            ctld.registerOperationAsset(op_context.operation_id, {
                unit_name = group_name,
                part_name = def.id,
                point = base,
                object_type = "group",
                coalition = side,
            })
        else
            table.insert(ctld.placed_assets, {
                is_group = true,
                group_name = group_name,
                asset_name = def.id,
                type = ctld.AssetTypes.TROOPS,
                point = base,
                coalition = side,
                unit_count = #units_spec,
            })
        end

        return group_name, nil
    end

    ---@param group_name string
    ---@return boolean ok, string|nil message
    function InfantrySquads.activate(group_name)
        if InfantrySquads.active[group_name] then
            return false, "Squad already active."
        end
        local gr = Group.getByName(group_name)
        if not (gr and gr:isExist() and gr:getSize() > 0) then
            return false, "Squad group not found."
        end
        local squad_id = InfantrySquads.squadIdFromGroupName(group_name)
        local def = squad_id and InfantrySquads.getDef(squad_id) or nil
        if not def then return false, "Unknown squad type." end

        local side = gr:getUnit(1):getCoalition()
        local lead = mist.getLeadPos(group_name)
        if not lead then return false, "Squad position unavailable." end

        local ok, zone, err = InfantrySquads.validateDeploy(def, side, lead)
        if not ok then return false, err end

        InfantrySquads.startBehaviour(def, group_name, side, zone)
        return true, def.desc .. " active."
    end

    ----------------------------------------------------------------------------
    -- Behaviours
    ----------------------------------------------------------------------------
    ---@param def table
    ---@param group_name string
    ---@param side coalition.side
    ---@param zone ZoneHandler|nil resolved at deploy time (engineer/sabotage/capture)
    function InfantrySquads.startBehaviour(def, group_name, side, zone)
        local b = def.behaviour
        local cfg = InfantrySquads.cfg(def.id)
        local state = {
            squad_id = def.id,
            behaviour = b,
            side = side,
            group_name = group_name,
            zone_name = zone and zone.name or nil,
        }

        local gr = Group.getByName(group_name)

        if b == "static" then
            -- Stinger / plain AD: hold position, weapons free.
            if gr then
                local ctrl = gr:getController()
                if ctrl then
                    ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
                    ctrl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
                end
            end

        elseif b == "assault" then
            if gr then
                local ctrl = gr:getController()
                if ctrl then
                    ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
                    ctrl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
                end
            end
            InfantrySquads._assaultRetask(group_name, side)

        elseif b == "mortar" then
            state.ammo = cfg.ammo or 20

        elseif b == "engineer" then
            if zone then
                zone.production_ration = cfg.production_ration or 1.5
                zone.production_ration_until = timer.getTime() + (cfg.duration or 3*60*60)
                zone.name_suffix = " (+)"
                if zone.drawF10 then zone:drawF10() end
                -- Red smoke ~20 m from the squad position.
                local p = mist.getLeadPos(group_name)
                if p then
                    trigger.action.smoke(
                        { x = p.x + 20, y = land.getHeight({ x = p.x + 20, y = p.z }), z = p.z },
                        trigger.smokeColor.Red)
                end
                trigger.action.outTextForCoalition(side,
                    string.format("Engineers deployed at %s: supply production boosted.", zone.name), 10)
            end

        elseif b == "sabotage" then
            if zone then
                zone.production_ration = cfg.production_ration or 0.5
                zone.production_ration_until = timer.getTime() + (cfg.duration or 3*60*60)
                zone.name_suffix = " (-)"
                if zone.drawF10 then zone:drawF10() end
                trigger.action.outTextForCoalition(side,
                    string.format("Sabotage team active near %s: enemy production disrupted.", zone.name), 10)
                if cfg.can_destroy_comms ~= false then
                    InfantrySquads._sabotageComms(zone, side)
                end
            end

        elseif b == "capture" then
            -- Capture handled on the behaviour tick (squad must survive in-zone).

        elseif b == "jtac" then
            InfantrySquads._jtacRetask(group_name, side)
        end

        InfantrySquads.active[group_name] = state
        InfantrySquads.ensureTicker()
    end

    --- Assault: route the squad to the nearest discovered enemy zone.
    ---@param group_name string
    ---@param side coalition.side
    function InfantrySquads._assaultRetask(group_name, side)
        local gr = Group.getByName(group_name)
        if not (gr and gr:isExist()) then return end
        local lead = mist.getLeadPos(group_name)
        if not lead then return end

        local enemy = utils.getEnemyCoalition(side)
        local target, best_d
        for _, zone in ipairs(zones) do
            if zone.side == enemy then
                local d = mist.utils.get2DDist(lead, zone.zone.point)
                if not best_d or d < best_d then target, best_d = zone, d end
            end
        end
        if not target then return end

        local path = {
            mist.ground.buildWP({ x = lead.x, z = lead.z }, "Off Road", 20),
            mist.ground.buildWP({ x = target.zone.point.x, z = target.zone.point.z }, "Off Road", 20),
        }
        mist.goRoute(group_name, path)
    end

    ---@param zone ZoneHandler
    ---@param side coalition.side
    function InfantrySquads._sabotageComms(zone, side)
        local tower_name = zone.linked_comms_tower
        if not tower_name then return end
        local tower = StaticObject.getByName(tower_name)
        if tower and tower:isExist() then
            trigger.action.explosion(tower:getPoint(), 500)
            trigger.action.outTextForCoalition(side,
                string.format("Sabotage team destroyed the COMMS tower at %s.", zone.name), 10)
        end
    end

    ---@param group_name string
    ---@param side coalition.side
    function InfantrySquads._jtacRetask(group_name, side)
        local gr = Group.getByName(group_name)
        if not (gr and gr:isExist()) then return end
        local ctrl = gr:getController()
        if not ctrl then return end
        local lead = mist.getLeadPos(group_name)
        if not lead then return end

        -- Find the nearest live enemy ground group.
        local enemy = utils.getEnemyCoalition(side)
        local target_group, best_d
        for _, eg in ipairs(coalition.getGroups(enemy, Group.Category.GROUND)) do
            if eg and eg:isExist() and eg:getSize() > 0 then
                local u = eg:getUnit(1)
                if u and u:isExist() then
                    local d = mist.utils.get2DDist(lead, u:getPoint())
                    if not best_d or d < best_d then target_group, best_d = eg, d end
                end
            end
        end
        if not target_group then return end

        ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.RETURN_FIRE)
        ctrl:setTask({
            id = "FAC_AttackGroup",
            params = {
                groupId = target_group:getID(),
                designation = AI.Task.Designation.AUTO,
            },
        })
    end

    function InfantrySquads.ensureTicker()
        if InfantrySquads._ticking then return end
        InfantrySquads._ticking = true
        local interval = (Config.squads and Config.squads.behaviour_tick) or 30
        timer.scheduleFunction(function()
            InfantrySquads.tick()
            if next(InfantrySquads.active) == nil then
                InfantrySquads._ticking = false
                return nil
            end
            return timer.getTime() + interval
        end, {}, timer.getTime() + interval)
    end

    function InfantrySquads.tick()
        for group_name, state in pairs(InfantrySquads.active) do
            local gr = Group.getByName(group_name)
            if not (gr and gr:isExist() and gr:getSize() > 0) then
                -- Squad destroyed/removed: clear any production modifier it set.
                if state.zone_name and (state.behaviour == "engineer" or state.behaviour == "sabotage") then
                    local zone = ZoneHandler.getFromName(state.zone_name)
                    if zone then
                        zone.production_ration = nil
                        zone.production_ration_until = nil
                        zone.name_suffix = nil
                        if zone.drawF10 then zone:drawF10() end
                    end
                end
                InfantrySquads.active[group_name] = nil
            elseif state.behaviour == "mortar" then
                InfantrySquads._mortarTick(group_name, state)
            elseif state.behaviour == "assault" then
                InfantrySquads._assaultRetask(group_name, state.side)
            elseif state.behaviour == "jtac" then
                InfantrySquads._jtacRetask(group_name, state.side)
            elseif state.behaviour == "capture" then
                local zone = state.zone_name and ZoneHandler.getFromName(state.zone_name) or nil
                if zone and zone.side == coalition.side.NEUTRAL then
                    local lead = mist.getLeadPos(group_name)
                    if lead and zone:isPointInsideZone(lead) and zone.capture then
                        zone:capture(state.side)
                        trigger.action.outTextForCoalition(state.side,
                            string.format("%s captured by ground forces.", zone.name), 10)
                        InfantrySquads.active[group_name] = nil
                    end
                end
            end
        end
    end

    --- Mortar: fire one round at the nearest enemy unit/static within range.
    ---@param group_name string
    ---@param state table
    function InfantrySquads._mortarTick(group_name, state)
        if (state.ammo or 0) <= 0 then return end
        local cfg = InfantrySquads.cfg(InfantrySquads.SquadIds.MORTAR)

        -- Respect the mortar's own fire interval (the behaviour ticker may run more
        -- often than the configured cadence).
        local now = timer.getTime()
        if state.next_fire and now < state.next_fire then return end

        local gr = Group.getByName(group_name)
        if not (gr and gr:isExist()) then return end
        local ctrl = gr:getController()
        if not ctrl then return end
        local lead = mist.getLeadPos(group_name)
        if not lead then return end

        local range = cfg.range or 5000
        local enemy = utils.getEnemyCoalition(state.side)

        -- One target per shot: nearest live enemy unit or static within range.
        local target_point, best_d
        local function consider(p)
            local d = mist.utils.get2DDist(lead, p)
            if d <= range and (not best_d or d < best_d) then
                target_point, best_d = p, d
            end
        end
        for _, zone in ipairs(zones) do
            if zone.side == enemy then
                for _, gname in ipairs(zone.linked_groups or {}) do
                    local g = Group.getByName(gname)
                    if g and g:isExist() and g:getSize() > 0 then
                        local u = g:getUnit(1)
                        if u and u:isExist() then consider(u:getPoint()) end
                    end
                end
                for _, sname in ipairs(zone.linked_statics or {}) do
                    local s = StaticObject.getByName(sname)
                    if s and s:isExist() then consider(s:getPoint()) end
                end
            end
        end
        if not target_point then return end

        ctrl:pushTask({
            id = "FireAtPoint",
            params = {
                point = mist.utils.makeVec2(target_point),
                radius = 2,
                expendQty = 1,
                expendQtyEnabled = true,
            },
        })
        state.ammo = state.ammo - 1
        state.next_fire = now + (cfg.fire_interval or 30)
    end

    function InfantrySquads.registerParts()
        if not (Config.squads and Config.squads.enabled) then return end
        for _, def in ipairs(InfantrySquads.SQUAD_DEFS) do
            local cfg = InfantrySquads.cfg(def.id)
            local soldiers = cfg.soldiers or #def.roles
            table.insert(ctld.parts, {
                name = InfantrySquads.PREFIX .. def.id,   -- identifier (not a DCS type)
                desc = def.desc,
                weight = 100 * soldiers,
                type = ctld.AssetTypes.TROOPS,
                req_supplies = cfg.req_supplies or 0,
                squad_id = def.id,
                troop_slots = cfg.troop_slots or soldiers,
            })
        end
    end
end

InfantrySquads.registerParts()


---@param group Group
function ctld.initF10RadioMenu(group)
    local gr_id = group:getID()
    local unit = group:getUnit(1)
    if not unit then return end

    local aircraft_limit = ctld.getAircraftLimit(unit)
    if aircraft_limit then
        local root_menu = missionCommands.addSubMenuForGroup(gr_id, "CTLD", nil)
        CommandHandler.addToMenuTracking(gr_id, root_menu, "ctld_menu")
        local load_submenu = missionCommands.addSubMenuForGroup(gr_id, "Load", root_menu)
    
        local load_troops_submenu = missionCommands.addSubMenuForGroup(gr_id, "Troops", load_submenu)

        local load_CARGO_CRATES_submenu = missionCommands.addSubMenuForGroup(gr_id, "Crates", load_submenu)
        local load_vehicles_submenu = missionCommands.addSubMenuForGroup(gr_id, "Vehicles", load_submenu)
        local load_sam_submenu = missionCommands.addSubMenuForGroup(gr_id, "SAM", load_submenu)


        missionCommands.addCommandForGroup(gr_id, "Unload", root_menu, function ()
            ctld.unload(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Unpack", root_menu, function ()
            ctld.unpack(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Unit Attack", root_menu, function ()
            ctld.unitAttack(unit)
        end)
    
        missionCommands.addCommandForGroup(gr_id, "Construct FARP", root_menu, function ()
            -- Check if nearby unpacked support vehicles can assemble a FARP.
            ctld.tryConstructFARP(unit)
        end)

        missionCommands.addCommandForGroup(gr_id, "List Loaded Cargo", root_menu, function ()
            ctld.listOnboardCargo(unit)
        end)

         local troop_commands = {}
        local cargo_crate_commands = {}
        local vehicle_commands = {}
        local sam_commands = {}

        local unit_side = unit:getCoalition()

        for _, part in ipairs(ctld.parts) do
            if part.type == ctld.AssetTypes.TROOPS then
                -- Squad parts are only offered when their required roles can be
                -- filled for this carrier's coalition under the active eras.
                local skip = false
                if part.squad_id then
                    local def = InfantrySquads.getDef(part.squad_id)
                    if not (def and InfantrySquads.isAvailable(def, unit_side)) then
                        skip = true
                    end
                end
                if not skip then
                    table.insert(troop_commands, {
                        name = part.desc .. " ("..(part.req_supplies or 0)..")",
                        func = function ()
                            ctld.load(part, unit)
                        end,
                        arg = nil
                    })
                end
            elseif part.type == ctld.AssetTypes.CARGO_CRATES then
                table.insert(cargo_crate_commands, {
                    name = part.desc .. " ("..(part.req_supplies or 0)..")",
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            elseif part.type == ctld.AssetTypes.VEHICLES then
                table.insert(vehicle_commands, {
                    name = part.desc .. " ("..(part.req_supplies or 0)..")",
                    func = function ()
                        ctld.load(part, unit)
                    end,
                    arg = nil
                })
            elseif part.type == ctld.AssetTypes.SAM then
                table.insert(sam_commands, {
                    name = part.desc .. " ("..(part.req_supplies or 0)..")",
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

end


---@param part part
---@param unit Unit
function ctld.load(part, unit)
    -- If the unit is dynamic cargo capable, then spawn a cargo crate nearby, otherwise store in ctld.users
    local unit_id = unit:getID()

    
    local airlift_operation = ctld.airlift_operation_tracking[unit_id]

    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Cannot load while airborne.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    local unit_pos = unit:getPoint()
    local unit_zone = nil
    for _,zone in ipairs(zones) do
        if zone:isPointInsideZone(unit_pos) then
            unit_zone = zone
            break
        end
    end
    if not unit_zone then
        trigger.action.outTextForUnit(unit_id,"Cannot load: Not in a valid load zone.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    if not airlift_operation and not Config.ctld.allow_load_anywhere then
        if not utils.tableContains(Config.ctld.allowed_load_zones, unit_zone.zone_type) then
            trigger.action.outTextForUnit(unit_id,"Cannot load: Not in a valid load zone.", 5)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end
    end

    if ctld.player_cooldowns[unit_id] == nil then
        ctld.player_cooldowns[unit_id] = 0
    end

    local current_time = timer.getTime()
    if current_time < ctld.player_cooldowns[unit_id] then
        local wait_time = math.ceil(ctld.player_cooldowns[unit_id] - current_time)
        trigger.action.outTextForUnit(unit_id, "Cannot load: Wait "..wait_time.." seconds before loading again.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
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
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    if airlift_operation then
        if airlift_operation.load_zone_name and unit_zone and unit_zone.name ~= airlift_operation.load_zone_name then
            trigger.action.outTextForUnit(unit_id, "Airlift load must be performed at " .. airlift_operation.load_zone_name, 8)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end

        local manifest = airlift_operation.manifest
        if not manifest or #manifest == 0 then
            trigger.action.outTextForUnit(unit_id, "Airlift manifest is unavailable.", 8)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end

        local is_requested_part = false
        local requested_quantity = 0
        for _, req in ipairs(manifest) do
            if req.part_name == part.name then
                is_requested_part = true
                requested_quantity = req.quantity or 0
                break
            end
        end

        if not is_requested_part then
            trigger.action.outTextForUnit(unit_id, "Airlift does not request " .. part.desc .. ".", 8)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end

        if (airlift_operation.loaded_parts[part.name] or 0) >= requested_quantity then
            trigger.action.outTextForUnit(unit_id, "Airlift already has enough " .. part.desc .. " loaded.", 8)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end
    end

    if not airlift_operation then
        if unit_zone.ammo_depot_intact ~= true then
            trigger.action.outTextForUnit(unit_id, "Cannot load: ammunition depot is required to access supplies in this zone.", 10)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end

        -- check local supplies
        local supply_count = unit_zone.local_supplies or 0
        if part.req_supplies then
            if supply_count < part.req_supplies then
                trigger.action.outTextForUnit(unit_id, "Cannot load: Not enough supplies for "..part.desc..". Requires "..part.req_supplies.." supplies.", 10)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                return
            end
        end

        -- check max parts
        if part.type == ctld.AssetTypes.CARGO_CRATES or part.type == ctld.AssetTypes.VEHICLES or part.type == ctld.AssetTypes.SAM then
            if #user.parts >= aircraft_limit.max_parts then
                trigger.action.outTextForUnit(unit_id,"Negative, cannot load part: "..part.desc..". Max parts limit reached.", 5)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                return
            end
        elseif part.type == ctld.AssetTypes.TROOPS then
            -- Each troop part consumes its troop_slots (squads consume several;
            -- regular troops default to 1).
            local current_troops = 0
            for _, p in ipairs(user.parts) do
                if p.type == ctld.AssetTypes.TROOPS then
                    current_troops = current_troops + (p.troop_slots or 1)
                end
            end
            local part_slots = part.troop_slots or 1
            if (current_troops + part_slots) > aircraft_limit.max_troops then
                trigger.action.outTextForUnit(unit_id,"Negative, cannot load troop: "..part.desc..". Max troops limit reached ("..aircraft_limit.max_troops..").", 5)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                return
            end
        end
    end

    -- Checks weight limit
    if Config.ctld.enable_weighted_loading then
        if not ctld.isDynamicCargoCapable(unit) then
            local total_weight = 0
            for _, p in ipairs(user.parts) do
                total_weight = total_weight + p.weight
            end
            total_weight = total_weight + part.weight
            if total_weight > aircraft_limit.weight_limit then
                trigger.action.outTextForUnit(unit_id,"Negative, cannot load: "..part.desc..", weight limit exceeded ("..aircraft_limit.weight_limit.." kg)", 5)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                return
            end
        end
    end

    -- Check if MOAB in stock
     -- Checks if MOAB in warehouse
    if part.name == CargoCrates.MOAB then
        local airbase = utils.getZoneOfUnitFromPosition(unit:getPoint())
        if not airbase or not airbase.airbase_name then
            trigger.action.outTextForUnit(unit_id, "Negative, unable to determine airbase for MOAB deployment.", 10)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end
        local in_stock = false
        ab = Airbase.getByName(airbase.airbase_name)
        if ab then
            local warehouse = ab:getWarehouse()
                local moab_count = warehouse:getItemCount(Stocks.Equipment.GBU_43)
                if moab_count and moab_count > 0 then
                    in_stock = true
                    warehouse:removeItem(Stocks.Equipment.GBU_43, 1)
                end
        end
        if not in_stock then
            trigger.action.outTextForUnit(unit_id, "Negative, no MOABs available in warehouse for deployment.", 10)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end
    end

    -- Add part to user's cargo
    if not airlift_operation then
        unit_zone.local_supplies = math.max((unit_zone.local_supplies or 0) - (part.req_supplies or 0),0)
    end

    table.insert(user.parts, part)

    if airlift_operation then
        airlift_operation.loaded_parts[part.name] = (airlift_operation.loaded_parts[part.name] or 0) + 1
    end

    if user.is_dynamic_cargo then

        if part.squad_id then
            -- Squads deploy as a multi-soldier group (inactive until unpacked).
            local def = InfantrySquads.getDef(part.squad_id)
            if def then InfantrySquads.spawnInactive(def, unit) end
            for i = #user.parts, 1, -1 do
                if user.parts[i] == part then table.remove(user.parts, i) break end
            end
            trigger.action.outTextForUnit(unit_id, def and (def.desc .. " deployed (Unpack to activate).") or "Squad deployed.", 6)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        elseif part.type == ctld.AssetTypes.TROOPS then
            ctld.spawnTroop(unit, part)
            trigger.action.outTextForUnit(unit_id, "Troop deployed.", 5)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        elseif part.type == ctld.AssetTypes.CARGO_CRATES or part.type == ctld.AssetTypes.VEHICLES or part.type == ctld.AssetTypes.SAM then
            -- spawn cargo crate nearby 
            ctld.spawnCargoCrate(unit, part)
            trigger.action.outTextForUnit(unit_id, string.format("A %s crate weighing %d kg has been brought out and is at your 12 or 6 o'clock", part.desc, part.weight), 5)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        end
    else
        trigger.action.outTextForUnit(unit_id, "Loaded: "..part.desc, 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
    end
end

---@param unit Unit
function ctld.unpack(unit)
    MissionLogger:info("Unpacking")
    local unit_id = unit:getID()
    local unit_pos = unit:getPoint()
    local unpack_heading = mist.getHeading(unit, true) or 0

    local operation_context = ctld.fetchOperationContextForUnit(unit)
    if operation_context and operation_context.operation_type == OperationTypes.STRATEGIC_AIRLIFT then
        trigger.action.outTextForUnit(unit_id, "Negative, cannot unpack during Strategic Airlift operations.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Negative, cannot unpack while airborne.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    if utils.getZoneOfUnitFromPosition(unit_pos) and not Config.ctld.allow_unpacking_in_zones then
        trigger.action.outTextForUnit(unit_id,"Negative, cannot unpack in this area.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end


    if Config.squads and Config.squads.enabled then
        local squad_vol = {
            id = world.VolumeType.SPHERE,
            params = { point = unit_pos, radius = Config.ctld.search_radius }
        }
        local found_squad_group, found_dist
        world.searchObjects(Object.Category.UNIT, squad_vol, function(obj)
            if obj and obj:isExist() and obj.getGroup and obj:getCoalition() == unit:getCoalition() then
                local g = obj:getGroup()
                if g and g:isExist() then
                    local gname = g:getName()
                    if InfantrySquads.squadIdFromGroupName(gname)
                    and not InfantrySquads.active[gname] then
                        local d = mist.utils.get2DDist(unit_pos, obj:getPoint())
                        if not found_dist or d < found_dist then
                            found_squad_group, found_dist = gname, d
                        end
                    end
                end
            end
            return true
        end)
        if found_squad_group then
            local ok, msg = InfantrySquads.activate(found_squad_group)
            trigger.action.outTextForUnit(unit_id, ok and msg or ("Cannot activate squad: "..(msg or "unknown error")), 8)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return
        end
    end

    -- search for crates nearby and unpack them
    local vol = {
        id = world.VolumeType.SPHERE,
        params = {
            point = unit_pos,
            radius = Config.ctld.search_radius
        }
    }

    -- Finds nearby unpacked and packed assets
    local unpacked_assets_nearby = {}
    local packed_assets_nearby = {}
    world.searchObjects({Object.Category.CARGO, Object.Category.UNIT}, vol, function(obj)
        if obj and obj:isExist() and obj.getName then
            local cargo_name = obj:getName()
            if obj:getCoalition() ~= unit:getCoalition() then
                return true
            end

            local point = obj:getPoint()
            if land.getSurfaceType({x = point.x, y = point.z}) == land.SurfaceType.WATER then
                return true
            end

            if ctld.isUnpackedAsset(cargo_name) then
                table.insert(unpacked_assets_nearby, obj)
                return true
            end
            if ctld.isPackedAsset(cargo_name) then
                table.insert(packed_assets_nearby, obj)
                return true
            end
        end
        return true
    end)

    -- Find the assets part descriptions for unpacked assets
    local unpacked_parts = {}
    for _, asset in ipairs(unpacked_assets_nearby) do
        local asset_name = asset:getName()
        local part_name = ctld.getUnpackedPartName(asset_name)
        if part_name then
            for _, part in ipairs(ctld.parts) do
                if part.name == part_name then
                    table.insert(unpacked_parts, {part = part, obj = asset})
                    break
                end
            end
        end
    end

    -- Find the assets part descriptions for packed assets
    local packed_parts = {}
    for _, asset in ipairs(packed_assets_nearby) do
        local asset_name = asset:getName()
        local part_name = ctld.getPackedPartName(asset_name)
        if part_name then
            for _, part in ipairs(ctld.parts) do
                if part.name == part_name then
                    table.insert(packed_parts, {part = part, obj = asset})
                    break
                end
            end
        end
    end

    -- Group packed parts by part name to check for crate requirements
    local packed_parts_by_name = {}
    for _, part_data in ipairs(packed_parts) do
        local part_name = part_data.part.name
        if not packed_parts_by_name[part_name] then
            packed_parts_by_name[part_name] = {objs = {}, part = part_data.part}
        end
        table.insert(packed_parts_by_name[part_name].objs, part_data.obj)
    end

    local op_context = ctld.fetchOperationContextForUnit(unit)

    -- First pass: Collect all SAM units to be created, grouped by group_requirement
    local sam_groups_to_spawn = {}  -- {group_requirement = {units = {...}, existing_group = group_obj}}
    local vehicles_to_spawn = {}  -- Regular vehicles spawn immediately

    -- Collect all units to unpack
    for part_name, crate_data in pairs(packed_parts_by_name) do
        ---@type part
        local part = crate_data.part
        local crates_required = part.crates_required or 1
        local available_crates = #crate_data.objs

        if part.name == CargoCrates.SUPPLY_CRATE and (part.supply_amount or 0) > 0 then
            for _, crate_obj in ipairs(crate_data.objs) do
                if crate_obj and crate_obj:isExist() then
                    local crate_point = crate_obj:getPoint()
                    local target_zone = utils.fetchSuppliesZoneFromPoint(crate_point, unit:getCoalition())
                    if not target_zone then
                        trigger.action.outTextForUnit(unit_id, "Negative, cannot unpack supply crate in this area.", 5)
                        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                    elseif target_zone.ammo_depot_intact ~= true then
                        trigger.action.outTextForUnit(unit_id, "Negative, cannot unpack supply crate.", 5)
                        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                    else
                        local zone_level = target_zone.level or 1
                        local zone_cap = Config.supplies.supplies_cap[zone_level] or 0
                        local current_supplies = target_zone.local_supplies or 0
                        local amount = part.supply_amount or 0
                        if current_supplies + amount > zone_cap then
                            trigger.action.outTextForUnit(unit_id, string.format("Negative, cannot unpack supply crate: %s can not hold more supplies.", target_zone.name), 5)
                            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                        else
                            target_zone.local_supplies = current_supplies + amount
                            trigger.action.outTextForUnit(unit_id, string.format("Unpacked %s and restored %d supplies to %s.", part.desc, amount, target_zone.name), 5)
                            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                            crate_obj:destroy()
                        end
                    end
                end
            end
        elseif available_crates < crates_required then
            trigger.action.outTextForUnit(unit_id,
                string.format("Negative, %s requires %d crates, only %d available.", part.desc, crates_required, available_crates), 5)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        else
            -- Calculate how many units we can spawn
            local units_to_create = math.floor(available_crates / crates_required)

            for i = 1, units_to_create do
                local crate_idx = (i - 1) * crates_required + 1
                local pos = crate_data.objs[crate_idx]:getPoint()

                if part.type == ctld.AssetTypes.VEHICLES then
                    -- Store vehicle to spawn immediately
                    table.insert(vehicles_to_spawn, {
                        part = part,
                        pos = pos,
                        crate_idx = crate_idx,
                        crates_required = crates_required,
                        crate_objs = crate_data.objs
                    })

                elseif part.type == ctld.AssetTypes.SAM then

                    local group_req = part.group_requirement or part.name

                    -- Initialize SAM group if not exists
                    if not sam_groups_to_spawn[group_req] then
                        sam_groups_to_spawn[group_req] = {
                            units = {},
                            existing_group = nil,
                            group_requirement = group_req
                        }

                        -- Check for existing unpacked SAM group with same requirement
                        for _, existing_asset in ipairs(unpacked_parts) do
                            if existing_asset.part.type == ctld.AssetTypes.SAM and
                               existing_asset.part.group_requirement == group_req then
                                local existing_unit = existing_asset.obj
                                if existing_unit and existing_unit:isExist() then
                                    sam_groups_to_spawn[group_req].existing_group = existing_unit:getGroup()
                                    break
                                end
                            end
                        end
                    end

                    -- Add unit to spawn list
                    local u_id = mist.getNextUnitId()
                    local unit_table = {
                        type = part.name,
                        unitId = u_id,
                        name = Config.ctld.unpacked_asset_prefix..part.name.."_"..u_id,
                        x = pos.x,
                        y = pos.z,
                        heading = unpack_heading,
                    }
                    table.insert(sam_groups_to_spawn[group_req].units, {
                        unit_data = unit_table,
                        part = part,
                        pos = pos,
                        crate_idx = crate_idx,
                        crates_required = crates_required,
                        crate_objs = crate_data.objs
                    })
                end
            end
        end
    end

    -- Spawn vehicles immediately
    for _, vehicle_data in ipairs(vehicles_to_spawn) do
        local u_id = mist.getNextUnitId()
        local unit_table = {
            type = vehicle_data.part.name,
            unitId = u_id,
            name = Config.ctld.unpacked_asset_prefix..vehicle_data.part.name .. "_" .. u_id,
            x = vehicle_data.pos.x,
            y = vehicle_data.pos.z,
            heading = unpack_heading,
        }
        local group_name = "ctld_gr_"..mist.getNextGroupId()
        local spawned_group = mist.dynAdd({
            units = {unit_table},
            groupName = group_name,
            country = unit:getCountry(),
            category = Group.Category.GROUND,
        })

        if spawned_group then
            if op_context and op_context.operation_id then
                ctld.registerOperationAsset(op_context.operation_id, {
                    unit_name = unit_table.name,
                    part_name = vehicle_data.part.name,
                    point = vehicle_data.pos,
                    object_type = "unit",
                    coalition = unit:getCoalition()
                })
            else
                table.insert(ctld.placed_assets, {
                    unit_name = unit_table.name,
                    asset_name = vehicle_data.part.name,
                    part_name = vehicle_data.part.name,
                    point = vehicle_data.pos,
                    heading = unpack_heading,
                    type = vehicle_data.part.type,
                    coalition = unit:getCoalition(),
                    is_group = false
                })
            end

            trigger.action.outTextForUnit(unit_id, 
                string.format("Unpacked %s, used %d crate(s)", vehicle_data.part.desc, vehicle_data.crates_required), 3)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            end

        -- Destroy crates
        for j = vehicle_data.crate_idx, math.min(vehicle_data.crate_idx + vehicle_data.crates_required - 1, #vehicle_data.crate_objs) do
            if vehicle_data.crate_objs[j] and vehicle_data.crate_objs[j]:isExist() then
                vehicle_data.crate_objs[j]:destroy()
            end
        end
    end

    -- Now spawn/respawn all SAM groups at the end
    for group_req, sam_data in pairs(sam_groups_to_spawn) do
        if #sam_data.units > 0 then
            local group_units = {}

            -- If existing group, get its units first
            if sam_data.existing_group and sam_data.existing_group:isExist() then
                local existing_units = sam_data.existing_group:getUnits()
                for _, gu in ipairs(existing_units) do
                    table.insert(group_units, {
                        type = gu:getTypeName(),
                        unitId = gu:getID(),
                        name = gu:getName(),
                        x = gu:getPoint().x,
                        y = gu:getPoint().z,
                        heading = mist.getHeading(gu) or 0,
                    })
                end
                -- Destroy old group before respawning
                sam_data.existing_group:destroy()
            else
                MissionLogger:info("Creating new SAM group: "..group_req)
            end
            
            -- Add all new units
            for _, unit_data in ipairs(sam_data.units) do
                table.insert(group_units, unit_data.unit_data)
            end
            
            -- Spawn the complete group
            local gr_name = "ctld_gr_"..mist.getNextGroupId()
            local spawned_group = mist.dynAdd({
                units = group_units,
                country = unit:getCountry(),
                category = Group.Category.GROUND,
                groupName = gr_name
            })
            
            if spawned_group then
                -- Record all newly added units in placed_assets, unless this is operation cargo
                for _, unit_data in ipairs(sam_data.units) do
                    if op_context and op_context.operation_id then
                        ctld.registerOperationAsset(op_context.operation_id, {
                            unit_name = unit_data.unit_data.name,
                            part_name = unit_data.part.name,
                            point = unit_data.pos,
                            object_type = "unit",
                            coalition = unit:getCoalition()
                        })
                    else
                        table.insert(ctld.placed_assets, {
                            unit_name = unit_data.unit_data.name,
                            asset_name = unit_data.part.name,
                            part_name = unit_data.part.name,
                            point = unit_data.pos,
                            heading = unit_data.unit_data.heading,
                            type = ctld.AssetTypes.SAM,
                            coalition = unit:getCoalition(),
                            is_group = true,
                            unit_count = #group_units,
                            group_name = gr_name
                        })
                    end
                    
                    -- Destroy crates
                    for j = unit_data.crate_idx, math.min(unit_data.crate_idx + unit_data.crates_required - 1, #unit_data.crate_objs) do
                        if unit_data.crate_objs[j] and unit_data.crate_objs[j]:isExist() then
                            unit_data.crate_objs[j]:destroy()
                        end
                    end
                end
                
                trigger.action.outTextForUnit(unit_id,
                    string.format("Unpacked %s with %d unit(s) total", group_req, #group_units), 3)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            end
        end
    end



end

function ctld.unload(unit)
    -- body
    local unit_id = unit:getID()
    if unit:inAir() then
        trigger.action.outTextForUnit(unit_id,"Cannot unload while airborne.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end
    local unit_pos = unit:getPoint()
    local unit_zone = utils.getZoneOfUnitFromPosition(unit_pos)
    local is_in_zone = unit_zone ~= nil


    if is_in_zone and not Config.ctld.allow_unloading_in_zones then
        trigger.action.outTextForUnit(unit_id,"Cannot unload in this area.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end


    if ctld.isDynamicCargoCapable(unit) then
        trigger.action.outTextForUnit(unit_id,"Cannot unload using CTLD, use native unloading.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    local user = ctld.users[unit_id]
    if user == nil or #user.parts == 0 then
        trigger.action.outTextForUnit(unit_id,"Negative, no cargo to unload.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return
    end

    local part_to_spawn = user.parts[#user.parts]
    if part_to_spawn.squad_id then
        local def = InfantrySquads.getDef(part_to_spawn.squad_id)
        if def then
            local _, err = InfantrySquads.spawnInactive(def, unit)
            if err then
                trigger.action.outTextForUnit(unit_id, "Cannot unload squad: "..err, 8)
                trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
                return
            end
        end
    elseif part_to_spawn.type == ctld.AssetTypes.TROOPS then
        ctld.spawnTroop(unit, part_to_spawn)
    else
        ctld.spawnCargoCrate(unit, part_to_spawn)
    end

    local part = table.remove(user.parts)

    if part.squad_id then
        trigger.action.outTextForUnit(unit_id, "Deployed "..part.desc.." (Unpack to activate).", 6)
    else
        trigger.action.outTextForUnit(unit_id,"Unloaded "..part.desc, 5)
    end
    trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
end


function ctld.unitAttack(unit)
    -- Find nearby vehicles and assigns them a route for the nearest enemy zone
    local vol =
    {
        id = world.VolumeType.SPHERE,
        params =
        {
            point = unit:getPoint(),
            radius = Config.ctld.search_radius
        }
    }

    local closest_enemy_zone = nil
    local min_dist = 999999
    local unit_pos = unit:getPoint()
    local unit_coalition = unit:getCoalition()
    for _, zone in ipairs(zones) do
        if zone.side ~= unit_coalition and utils.tableContains(stats.blue_discovered_zones, zone.name) then
            local dist = mist.utils.get2DDist(unit_pos, zone.zone.point)
            if dist < min_dist then
                min_dist = dist
                closest_enemy_zone = zone
            end
        end
    end
    if not closest_enemy_zone then return trigger.action.outTextForUnit(unit:getID(), "No enemy assets nearby.", 5) end


    world.searchObjects({Object.Category.UNIT}, vol, function(obj)
        if obj and obj:isExist() and obj.getName then
            --starts with unpacked
            if obj:getName():match("^unpacked.+") == nil then
                return true
            end

            local objType = obj:getTypeName()
            for _,part in ipairs(ctld.parts) do
                if part.can_move and objType == part.name then
                
                    local gr = obj:getGroup()
                    if not gr or not gr:isExist() then return true end
                    local controller = gr:getController()
                    if not controller then return true end

                    local groups_to_attack = closest_enemy_zone.linked_groups
                    if not groups_to_attack or #groups_to_attack == 0 then return true end

                    local targetGroup = Group.getByName(groups_to_attack[math.random(1, #groups_to_attack)])
                    if not targetGroup or not targetGroup:isExist() then return true end
                    MissionLogger:info("Assigning "..part.desc.." to attack "..closest_enemy_zone.name.. " group: ".. targetGroup:getName())
                    -- assign attack route to closest enemy zone
                    -- Define the task
                    controller:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
                    controller:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)

                    timer.scheduleFunction(function()
                        mist.groupToPoint(gr, mist.getLeadPos(targetGroup))
                    end, {}, timer.getTime() + 1)

                    local u_id = unit:getID()
                    trigger.action.outTextForUnit(u_id,
                        string.format("Assigned %s to attack %s", part.desc, closest_enemy_zone.name), 5)
                    trigger.action.outSoundForUnit(u_id, "Radio squelch.ogg")
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
    local unit_point = unit:getPoint()
    local u_id = unit:getID()

    local txt_heading = "Logistics SITREP:\n"
    local txt_body = "\n"
    local coalition_supplies = 0
    local relevant_zones = 0

    -- Detail the production rates
    local sorted_zones = {}
    for _, zone in ipairs(zones) do
        if zone.side == unit_coalition and (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.LOGISTICS
        or zone.zone_type == ZoneTypes.FARP) then
            table.insert(sorted_zones, zone)
        end
    end

    table.sort(sorted_zones, function(a, b)
        local a_level = a.level or 1
        local b_level = b.level or 1
        if a_level == b_level then
            return (a.name or "") < (b.name or "")
        end
        return a_level > b_level
    end)

    for _, zone in ipairs(sorted_zones) do

            local zone_level = zone.level or 1
            local zone_has_depot = zone.linked_statics and #zone.linked_statics > 0 and zone.ammo_depot_intact == true

            local current_cap = 0

            local zone_production = 0
            if zone_has_depot then
                current_cap = Config.supplies.supplies_cap[zone_level] or 0

                zone_production = Config.supplies.supplies_production[zone_level] or 0

                if zone.zone_type == ZoneTypes.LOGISTICS then
                    zone_production = zone_production * (Config.supplies.logistics_mult or 2)
                end
            end

            local zone_supplies = zone.local_supplies or 0

            if zone_supplies > 0 or zone_production > 0 then
                relevant_zones = relevant_zones + 1
                coalition_supplies = coalition_supplies + zone_supplies

                if zone:isPointInsideZone(unit_point) then
                    txt_heading = "Logistics SITREP\n\n".. zone_supplies .. " / " .. current_cap .. " local available supplies.\n"
                end

                txt_body = txt_body .. "\n - ".. zone.name .. "            "..zone_supplies.."/"..current_cap.."      +".. zone_production .. " / minute"
            end
    end

    if relevant_zones == 0 then
        txt_body = txt_body .. "\nNo friendly zones currently have supplies or production."
    else
        txt_heading = txt_heading .. string.format("%d supplies across %d zone(s).\n", coalition_supplies, relevant_zones)
    end

    trigger.action.outTextForUnit(u_id, txt_heading..txt_body, 20)
    trigger.action.outSoundForUnit(u_id, "Radio squelch.ogg")

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
        local supply_amount = nil
        for _, part in ipairs(ctld.parts) do
            if part.desc == part_desc then
                crates_required = part.crates_required or 1
                supply_amount = part.supply_amount
                break
            end
        end

        if supply_amount then
            cargo_list = cargo_list .. string.format("%s x%d (stores: %d supplies)\n", part_desc, count, supply_amount)
        else
            cargo_list = cargo_list .. string.format("%s x%d (required: %s)\n", part_desc, count,crates_required)
        end
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
    trigger.action.outSoundForUnit(unit_id, "Radio squelch.ogg")
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

    local randomOffsetX = math.random(0, Config.ctld.random_crate_spacing * 2) - Config.ctld.random_crate_spacing
    local randomOffsetZ = math.random(0, Config.ctld.random_crate_spacing)

    local position = unit:getPosition()
    
    ---@diagnostic disable-next-line: deprecated
    local angle    = math.atan2(position.x.z, position.x.x) + direction_in_radian
    local xOffset  = math.cos(angle) * (offset + randomOffsetX)
    local zOffset  = math.sin(angle) * (offset + randomOffsetZ)
    local point    = unit:getPoint()
    return { x = point.x + xOffset, z = point.z + zOffset, y = point.y }
end

---@param point vec3
---@param coalition_side coalition.side
---@param radius number
---@return table<string, Unit>
function ctld.findNearbyFARPRequirementVehicles(point, coalition_side, radius)
    local found_by_part = {}
    local required_lookup = {}
    for _, part_name in ipairs(ctld.farp_vehicle_requirements) do
        required_lookup[part_name] = true
    end

    local vol = {
        id = world.VolumeType.SPHERE,
        params = {
            point = point,
            radius = radius
        }
    }

    world.searchObjects({Object.Category.UNIT}, vol, function(obj)
        if obj and obj:isExist() and obj.getName and obj.getCoalition and obj:getCoalition() == coalition_side then
            local obj_name = obj:getName()
            if ctld.isUnpackedAsset(obj_name) then
                local part_name = ctld.getUnpackedPartName(obj_name)
                if part_name and required_lookup[part_name] and not found_by_part[part_name] then
                    found_by_part[part_name] = obj
                end
            end
        end
        return true
    end)

    return found_by_part
end

---@param unit Unit
---@param center_point vec3
---@param linked_zone ZoneHandler|nil
---@return ConstructedFARP|nil
function ctld.buildFARP(unit, center_point,linked_zone)
    local country_name_id = country.id.CJTF_BLUE
    if unit:getCoalition() == coalition.side.RED then
        country_name_id = country.id.CJTF_RED
    end

    local base_x = center_point.x
    local base_y = center_point.z

    local farp_statics_to_spawn = {
        { type = "Invisible FARP", category = "Heliports", shape_name = "invisiblefarp", offset_x = 0, offset_y = 0 },
        { type = "FARP Tent", category = "Fortifications", offset_x = 5, offset_y = 55 },
        { type = "FARP Tent", category = "Fortifications", offset_x = -15, offset_y = 55 },
        { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = 30, offset_y = 5 },
        { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = 30, offset_y = -5 },
        { type = "FARP Fuel Depot", category = "Fortifications", offset_x = 5, offset_y = -60 },
        { type = "FARP Fuel Depot", category = "Fortifications", offset_x = -5, offset_y = -60 },
    }

    local farp_name = nil
    local assigned_name = nil

    for _, static_data in ipairs(farp_statics_to_spawn) do
        local static_point = {
            x = base_x + static_data.offset_x,
            y = base_y + static_data.offset_y
        }

        local new_static = mist.dynAddStatic({
            type = static_data.type,
            shape_name = static_data.shape_name,
            name = string.format("ctld_farp_%d", ctld.getNextGroupId()),
            country = country_name_id,
            category = static_data.category,
            x = static_point.x,
            y = static_point.y,
            heading = 0
        })
        
        -- Assign custom display name to FARP (unique among active FARPs)
        if static_data.type == "Invisible FARP" then
            local failsafe = 0
            while failsafe < 1000 and not assigned_name do
                failsafe = failsafe + 1
                local candidate = Config.ctld.FARP_names[math.random(1, #Config.ctld.FARP_names)]
                local taken = false
                for _, farp in ipairs(ctld.FARPs) do
                    if farp.display_name == candidate then
                        taken = true
                        break
                    end
                end
                if not taken then
                    assigned_name = candidate
                end
            end
            -- Fallback if all names are already in use
            if not assigned_name then
                assigned_name = string.format("FARP %d", #ctld.FARPs + 1)
            else
                assigned_name = "FARP "..assigned_name
            end
        end

        if new_static and new_static.name then
            table.insert(ctld.placed_assets, {
                unit_name = new_static.name,
                asset_name = static_data.type,
                category = static_data.category,
                shape_name = static_data.shape_name,
                point = { x = static_point.x, y = land.getHeight({x = static_point.x, y = static_point.y}), z = static_point.y },
                type = ctld.AssetTypes.STATIC,
                coalition = unit:getCoalition()
            })
            
            if static_data.type == "Invisible FARP" then
                farp_name = new_static.name
            end
        end

    end

    if not farp_name then
        MissionLogger:error("CTLD: Failed to construct FARP, no Invisible FARP spawned.")
        return nil
    end

    -- timer.scheduleFunction(function()
    --     WarehouseManager:clearWarehouse(farp_name)
    --     WarehouseManager:attributeAirbaseStock(farp_name, unit:getCoalition(), {StockTypes.FARP})
    -- end, {}, timer.getTime() + 1)

    ---@type ConstructedFARP
    local farp = {
        farp_name = farp_name,
        display_name = assigned_name,
        point = center_point,
        coalition = unit:getCoalition(),
        linked_zone = linked_zone
    }
    table.insert(ctld.FARPs, farp)

    -- Refresh resupply menus
    CommandHandler.requestMenuRefresh(farp.coalition)

    return farp
end

---@param unit Unit
---@return boolean
function ctld.tryConstructFARP(unit)
    local unit_id = unit:getID()
    local unit_pos = unit:getPoint()
    local coalition_side = unit:getCoalition()
    local search_radius = Config.ctld.search_radius or 100
    local current_zone = utils.getZoneOfUnitFromPosition(unit_pos)

    local found_parts = ctld.findNearbyFARPRequirementVehicles(unit_pos, coalition_side, search_radius)
    local missing_parts = {}
    for _, required_part_name in ipairs(ctld.farp_vehicle_requirements) do
        if not found_parts[required_part_name] then
            table.insert(missing_parts, required_part_name)
        end
    end

    if #missing_parts > 0 then
        local out_text = "Cannot construct FARP. Missing required assets:\n"
        for _, part_name in ipairs(missing_parts) do
            local part_desc = part_name
            for _, part in ipairs(ctld.parts) do
                if part.name == part_name then
                    part_desc = part.desc
                    break
                end
            end
            out_text = out_text .. "- " .. part_desc .. "\n"
        end
        trigger.action.outTextForUnit(unit_id, out_text, 10)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return false
    end

    if current_zone and current_zone.zone_type == ZoneTypes.FARP and current_zone.linked_farp then
        local existing_farp = Airbase.getByName(current_zone.linked_farp)
        if existing_farp then
            trigger.action.outTextForUnit(unit_id, "Negative, this FARP zone is already operational.", 5)
            trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
            return false
        end
        current_zone.linked_farp = nil
    end

    local center = { x = 0, y = 0, z = 0 }
    local count = 0
    for _, required_part_name in ipairs(ctld.farp_vehicle_requirements) do
        local req_obj = found_parts[required_part_name]
        if req_obj and req_obj:isExist() then
            local p = req_obj:getPoint()
            center.x = center.x + p.x
            center.z = center.z + p.z
            count = count + 1
        end
    end

    if count == 0 then
        return false
    end

    center.x = center.x / count
    center.z = center.z / count
    center.y = land.getHeight({x = center.x, y = center.z})


    local farp = ctld.buildFARP(unit, center, current_zone)
    if not farp then
        trigger.action.outTextForUnit(unit_id, "Negative, failed to construct FARP.", 5)
        trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
        return false
    end

    for _, required_part_name in ipairs(ctld.farp_vehicle_requirements) do
        local req_obj = found_parts[required_part_name]
        if req_obj and req_obj:isExist() then
            req_obj:destroy()
        end
    end


    ctld.displayConstructedFarp(farp, unit_id)
    return true
end

-- Sounds and text included
---@param farp ConstructedFARP
---@param unit_id any|nil    
function ctld.displayConstructedFarp(farp, unit_id)
    if not farp then return end
    if farp.linked_zone then
        farp.linked_zone:drawF10(string.format("%s Operational", farp.display_name or farp.farp_name))

        if unit_id then
        trigger.action.outTextForUnit(unit_id,string.format("FARP constructed at %s and active.", farp.linked_zone.name),10)
        end
    else
        if farp.mark_id then
            trigger.action.removeMark(farp.mark_id)
        end
        local next_id = nextMarkId()
        farp.mark_id = next_id

        if unit_id then
        trigger.action.outTextForUnit(unit_id,"FARP constructed and active.",10)
        end
        trigger.action.textToAll(farp.coalition,next_id,farp.point,{0, 0.1, 0.5, 1},{0.5, 0.8, 1, 0.3},13,true,string.format(" %s", farp.display_name or farp.farp_name))
    end

    if not unit_id then return end
    trigger.action.outSoundForUnit(unit_id, "transmission1.ogg")
end

---@param unit Unit
---@param part part
function ctld.spawnCargoCrate(unit,part)
    local op_context = ctld.fetchOperationContextForUnit(unit)

    if (not op_context or not op_context.operation_id)
    and #ctld.placed_assets >= Config.ctld.max_placed_assets then
        trigger.action.outTextForUnit(unit:getID(), "Cannot load: Maximum placed assets limit reached ("..Config.ctld.max_placed_assets..").", 5)
        return
    end


    local point = ctld.getPointAt12Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    if unit:getTypeName() == "C-130J-30" then
        point = ctld.getPointAt6Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    end
    MissionLogger:info(string.format("Spawning cargo crate %s", part.name))

    local type_to_spawn = Config.ctld.cargo_crate_template
    if utils.tableContains(CargoCrates, part.name) then
        type_to_spawn = part.name
    end

    local crate = mist.dynAddStatic({
        type = type_to_spawn,
        name = Config.ctld.packed_asset_prefix..part.name.."_"..ctld.getNextGroupId(),
        country = unit:getCountry(),
        category = "Cargos",
        x = point.x,
        y = point.z
    })
    if crate then
        if op_context and op_context.operation_id then
            ctld.registerOperationAsset(op_context.operation_id, {
                unit_name = crate.name,
                part_name = part.name,
                point = point,
                object_type = "static",
                coalition = unit:getCoalition()
            })
        else
            table.insert(ctld.placed_assets, {
                unit_name = crate.name,
                asset_name = type_to_spawn,
                part_name = part.name,
                point = point,
                type = ctld.AssetTypes.CARGO_CRATES,
                coalition = unit:getCoalition()
            })
        end
    end
end

---@param unit Unit
---@param part part
function ctld.spawnTroop(unit,part)
    local op_context = ctld.fetchOperationContextForUnit(unit)

    if (not op_context or not op_context.operation_id)
    and #ctld.placed_assets >= Config.ctld.max_placed_assets then
        trigger.action.outTextForUnit(unit:getID(), "Cannot load: Maximum placed assets limit reached ("..Config.ctld.max_placed_assets..").", 5)
        return
    end

    local point = ctld.getPointAt12Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    if unit:getTypeName() == "C-130J-30" then
        point = ctld.getPointAt6Oclock(unit, ctld.getSecureDistanceFromUnit(unit))
    end
    local spawn_heading = mist.getHeading(unit) or 0

    local u_id = mist.getNextUnitId()
    local unit_name = Config.ctld.packed_asset_prefix .. part.name .. "_" .. u_id
    local troop = mist.dynAdd({
    units = {
        {
        type = part.name,
        unitId = u_id,
        name = unit_name,
        x = point.x,
        y = point.z,
        heading = spawn_heading,
    }
    },
    country = unit:getCountry(),
    category = Group.Category.GROUND,
    })
    if troop then
        if op_context and op_context.operation_id then
            ctld.registerOperationAsset(op_context.operation_id, {
                unit_name = unit_name,
                part_name = part.name,
                point = point,
                object_type = "unit",
                coalition = unit:getCoalition()
            })
        else
            table.insert(ctld.placed_assets, {
                unit_name = unit_name,
                asset_name = part.name,
                part_name = part.name,
                point = point,
                heading = spawn_heading,
                type = ctld.AssetTypes.TROOPS,
                coalition = unit:getCoalition()
            })
        end
    end
end

--- Performance-friendly periodic check for destroyed FARPs
--- Monitors Invisible FARP markers; if destroyed, removes FARP and notifies coalition
function ctld.monitorFARPDestruction()
    if not ctld.FARPs or #ctld.FARPs == 0 then
        return
    end

    local destroyed_farps = {}
    for i, farp in ipairs(ctld.FARPs) do
        -- Check if any units are near the FARP
        local invisible_farp = StaticObject.getByName(farp.farp_name)
        if not invisible_farp or not invisible_farp:isExist() then
            table.insert(destroyed_farps, i)
        else
            local sphere = {
                id = world.VolumeType.SPHERE,
                params = {
                    point = farp.point,
                    radius = 200 -- Check within 200m for any units (to catch FARPs that are heavily damaged but not fully destroyed)
                }
            }
            local units_nearby = false
            world.searchObjects({Object.Category.UNIT, Object.Category.STATIC}, sphere, function(obj)
                if obj and obj:isExist() then
                    units_nearby = true
                    return false -- Stop searching, we found a unit near the FARP
                end
                return true
            end)
            if not units_nearby then
                table.insert(destroyed_farps, i)
            end
        end


    end

    -- Remove destroyed FARPs (iterate in reverse to avoid index shifts)
    for i = #destroyed_farps, 1, -1 do
        local idx = destroyed_farps[i]
        local farp = ctld.FARPs[idx]
        if farp then
            local farp_display_name = farp.display_name or farp.farp_name
            
            MissionLogger:info(string.format("FARP %s destroyed. Removing from active FARPs.", farp_display_name))
            
            -- Broadcast to coalition
            trigger.action.outTextForCoalition(farp.coalition,string.format("Sector ALERT: %s FARP has been destroyed.", farp_display_name),10)
            trigger.action.outSoundForCoalition(farp.coalition,"alert1.ogg")
            timer.scheduleFunction(function ()
                trigger.action.outSoundForCoalition(farp.coalition,"alert1.ogg")
            end,{},timer.getTime()+1)

            -- Remove FARP from registry
            table.remove(ctld.FARPs, idx)
            -- Remove FARP from ctld assets table
            for j = #ctld.placed_assets, 1, -1 do
                local asset = ctld.placed_assets[j]
                if asset.unit_name == farp.farp_name then
                    table.remove(ctld.placed_assets, j)
                end
            end

            -- Remove invisible farp
            local invisible_farp = StaticObject.getByName(farp.farp_name)
            if invisible_farp and invisible_farp:isExist() then
                invisible_farp:destroy()
            end

            -- Update linked zone if applicable
            if farp.linked_zone then
                farp.linked_zone:drawF10()
            elseif farp.mark_id then
                trigger.action.removeMark(farp.mark_id)
            end
        end
    end
end

function ctld.isPackedAsset(asset_name)
    -- Matches with prefix in config
    return string.sub(asset_name, 1, #Config.ctld.packed_asset_prefix) == Config.ctld.packed_asset_prefix
end

function ctld.isUnpackedAsset(asset_name)
    -- Matches with prefix in config
    return string.sub(asset_name, 1, #Config.ctld.unpacked_asset_prefix) == Config.ctld.unpacked_asset_prefix
end

function ctld.getUnpackedPartName(asset_name)
    return asset_name:match("^" .. Config.ctld.unpacked_asset_prefix .. "(.+)_%d+$")
end

function ctld.getPackedPartName(asset_name)
    if not asset_name then return nil end
    asset_name = asset_name:gsub("^CRG:", "")
    return asset_name:match("^" .. Config.ctld.packed_asset_prefix .. "(.+)_%d+$")
end


---@param part_name string
---@return part|nil
function ctld.findPartByName(part_name)
    for _, part in ipairs(ctld.parts) do
        if part.name == part_name then
            return part
        end
    end
    return nil
end



---@param unit Unit|nil
---@return OperationContext|nil
function ctld.fetchOperationContextForUnit(unit)
    if not unit then return nil end
    return ctld.operation_contexts[unit:getID()]
end

---@param unit Unit|nil
---@param context OperationContext|nil
function ctld.setOperationContextForUnit(unit, context)
    if not unit then return end
    ctld.operation_contexts[unit:getID()] = context
end

---@param unit Unit|nil
function ctld.clearOperationContextForUnit(unit)
    if not unit then return end
    local unit_id = unit:getID()
    ctld.operation_contexts[unit_id] = nil
    ctld.airlift_operation_tracking[unit_id] = nil
end

---@param operation_id string|nil
function ctld.clearOperationContextForOperation(operation_id)
    if not operation_id then return end

    for unit_id, context in pairs(ctld.operation_contexts) do
        if context and context.operation_id == operation_id then
            ctld.operation_contexts[unit_id] = nil
            ctld.airlift_operation_tracking[unit_id] = nil
        end
    end
end

---@param operation_id string|nil
---@param asset OperationAsset|nil
function ctld.registerOperationAsset(operation_id, asset)
    if not operation_id or not asset then return end
    if not ctld.operation_assets[operation_id] then
        ctld.operation_assets[operation_id] = {}
    end
    asset.operation_id = operation_id
    table.insert(ctld.operation_assets[operation_id], asset)
end

---@param operation_id string|nil
---@return OperationAsset[]
function ctld.fetchOperationAssets(operation_id)
    if not operation_id then return {} end
    return ctld.operation_assets[operation_id] or {}
end

---@param operation_id string|nil
function ctld.clearOperationAssets(operation_id)
    if not operation_id then return end

    local assets = ctld.operation_assets[operation_id]
    if not assets then
        return
    end

    for _, asset in ipairs(assets) do
        local obj = nil
        if asset.object_type == "static" then
            obj = StaticObject.getByName(asset.unit_name)
        elseif asset.object_type == "group" then
            obj = Group.getByName(asset.unit_name)
        else
            obj = Unit.getByName(asset.unit_name)
        end

        if obj and obj:isExist() then
            obj:destroy()
        end
    end

    ctld.operation_assets[operation_id] = nil
end

---@param operation_id string|nil
---@return table<string, number>
function ctld.getOperationLoads(operation_id)
    local counts = {}
    if not operation_id then return counts end

    for unit_id, context in pairs(ctld.operation_contexts) do
        if context and context.operation_id == operation_id then
            local user = ctld.users[unit_id]
            if user and user.parts then
                for _, part in ipairs(user.parts) do
                    counts[part.name] = (counts[part.name] or 0) + 1
                end
            end
        end
    end

    return counts
end

---@param operation_id string|nil
function ctld.clearOperationLoads(operation_id)
    if not operation_id then return end

    for unit_id, context in pairs(ctld.operation_contexts) do
        if context and context.operation_id == operation_id then
            local user = ctld.users[unit_id]
            if user then
                user.parts = {}
            end
            ctld.airlift_operation_tracking[unit_id] = nil
            ctld.operation_contexts[unit_id] = nil
        end
    end
end

---@param object_name string
---@return boolean
function ctld.isSupplyCrate(object_name)
    local packed_name = ctld.getPackedPartName(object_name)
    if packed_name and packed_name == CargoCrates.SUPPLY_CRATE then
        return true
    end

    -- Fallback: require packed prefix and supply crate key in name
    local cleaned = tostring(object_name):gsub("^CRG:", "")
    if not string.find(cleaned, Config.ctld.packed_asset_prefix, 1, true) then
        return false
    end
    return string.find(cleaned, CargoCrates.SUPPLY_CRATE, 1, true) ~= nil
end