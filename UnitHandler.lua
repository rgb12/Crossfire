UnitHandler = {}
do
    ---@param zone ZoneHandler
    ---@param max_tries number|nil
    ---@param clear_radius number|nil
    ---@param runway_clear_radius number|nil -- for taxiways also
    ---@return vec2
    function UnitHandler.findClearPoint(zone, max_tries, clear_radius, runway_clear_radius)
        max_tries = max_tries or 6
        clear_radius = clear_radius or 50
        local last
        for i = 1, max_tries do
            local candidate = mist.getRandomPointInZone(zone.name,Config.spawn_inner_radius)

            if candidate and mist.isTerrainValid(candidate,{"LAND"}) then
                last = candidate
                local is_runway = false

                if runway_clear_radius and runway_clear_radius > 0 then
                    local r = runway_clear_radius
                    local sample_point = {x = candidate.x, y = candidate.y}
                    if land.getSurfaceType(candidate) == land.SurfaceType.RUNWAY then
                        is_runway = true
                    else
                        sample_point.x = candidate.x - r
                        sample_point.y = candidate.y + r
                        if land.getSurfaceType(sample_point) == land.SurfaceType.RUNWAY then
                            is_runway = true
                        else
                            sample_point.x = candidate.x - r
                            sample_point.y = candidate.y - r
                            if land.getSurfaceType(sample_point) == land.SurfaceType.RUNWAY then
                                is_runway = true
                            else
                                sample_point.x = candidate.x + r
                                sample_point.y = candidate.y + r
                                if land.getSurfaceType(sample_point) == land.SurfaceType.RUNWAY then
                                    is_runway = true
                                else
                                    sample_point.x = candidate.x + r
                                    sample_point.y = candidate.y - r
                                    if land.getSurfaceType(sample_point) == land.SurfaceType.RUNWAY then
                                        is_runway = true
                                    end
                                end
                            end
                        end
                    end
                end

                if not is_runway then
                    local found = false

                    if clear_radius then
                        local vol = { id = world.VolumeType.SPHERE, params = { point = candidate, radius = clear_radius } }
                        world.searchObjects({Object.Category.UNIT,Object.Category.STATIC}, vol, function() found = true return false end)
                    end

                    if not found then return candidate end
                end
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

    -- Set once the first time a composed group lands on the WRONG coalition
    -- (the picked country is not registered on the zone's side in the .miz).
    -- Used to throw the user-facing message box only a single time.
    local side_mismatch_notified = false

    -- Per-(zone_type, side) stat counter increment, identical to the legacy
    -- initZoneUnits/capture behaviour. Called ONCE per zone when its primary
    -- group(s) spawn successfully.
    local function bumpZoneStat(zone, spawned_any)
        if not spawned_any then return end
        local red = (zone.side == coalition.side.RED)
        local zt = zone.zone_type
        if zt == ZoneTypes.STRONGPOINT then
            if red then stats.red_strongpoints = stats.red_strongpoints + 1
            else stats.blue_strongpoints = stats.blue_strongpoints + 1 end
        elseif zt == ZoneTypes.LOGISTICS then
            if red then stats.red_logistics_zone = stats.red_logistics_zone + 1
            else stats.blue_logistics_zone = stats.blue_logistics_zone + 1 end
        elseif zt == ZoneTypes.SAMSITE then
            if red then stats.red_sam_sites = stats.red_sam_sites + 1
            else stats.blue_sam_sites = stats.blue_sam_sites + 1 end
        elseif zt == ZoneTypes.COMMS then
            if red then stats.red_comms_zones = stats.red_comms_zones + 1
            else stats.blue_comms_zones = stats.blue_comms_zones + 1 end
        elseif zt == ZoneTypes.EWSITE then
            if red then stats.red_ew_zones = stats.red_ew_zones + 1
            else stats.blue_ew_zones = stats.blue_ew_zones + 1 end
        elseif zt == ZoneTypes.AIRBASE then
            if red then stats.red_airbases = stats.red_airbases + 1
            else stats.blue_airbases = stats.blue_airbases + 1 end
        elseif zt == ZoneTypes.FARP then
            if red then stats.red_farp_zones = stats.red_farp_zones + 1
            else stats.blue_farp_zones = stats.blue_farp_zones + 1 end
        end
    end

    --- Spawn the dynamically-composed ground units for a zone.
    --- Ground units are FULLY SCRIPTED: UnitComposer builds native group tables
    --- and we spawn each via coalition.addGroup. Every live group name is
    --- recorded in zone.linked_groups (capture / persistence / cleanup depend
    --- on it). The same stats.* counters the legacy code maintained are kept.
    ---@param zone ZoneHandler
    function UnitHandler.initZoneUnits(zone)
        if not zone or zone.side == coalition.side.NEUTRAL then return end
        if zone.zone_type == nil then return end

        local compositions = UnitComposer.compose(zone)
        local spawned_any = false

        for _, comp in ipairs(compositions) do
            local gt = comp.group_table
            if gt and gt.units and #gt.units > 0 then
                local country_id = comp.country
                local grp = coalition.addGroup(country_id, Group.Category.GROUND, gt)
                if grp and grp:getUnit(1) then
                    -- DCS binds a group to the coalition its country belongs to
                    -- in the .miz, NOT to the side we intended. If the picked
                    -- country is not registered on this zone's side, the group
                    -- spawns on the wrong coalition. Detect it and notify ONCE.
                    local actual_country = grp:getUnit(1):getCountry()

                    if not utils.tableContains(Config.era_system.coalition_selector[zone.side], actual_country) then

                        MissionLogger:error("[UnitHandler] " .. tostring(gt.name).. " spawned on country " .. tostring(actual_country).. " but zone " .. tostring(zone.name) .. " is side "
                            .. tostring(zone.side) .. " -- country " .. tostring(country_id)
                            .. " is not registered on that side in the .miz.")
                        if not side_mismatch_notified then
                            side_mismatch_notified = true
                            env.error("CONFIG ERROR: coalition_selector country ".. tostring(country.name[country_id]) .. " is not on the intended coalition in this mission. Ground units are spawning with the wrong country. Add that country to the correct coalition in the Mission Editor.", true)
                        end
                    end
                    table.insert(zone.linked_groups, gt.name)
                    spawned_any = true
                else
                    MissionLogger:error("[UnitHandler] addGroup failed for "
                        .. tostring(gt.name) .. " (" .. tostring(comp.country) .. ")")
                end
            end
        end

        bumpZoneStat(zone, spawned_any)
    end

    ---@param zone ZoneHandler
    ---@return boolean
    function UnitHandler.initStatics(zone)
        if zone.side == coalition.side.NEUTRAL then return false end
        local country_name
        if zone.side == coalition.side.BLUE then country_name = country.id.CJTF_BLUE
        else country_name = country.id.CJTF_RED end

        if zone.zone_type == ZoneTypes.LOGISTICS or zone.zone_type == ZoneTypes.AIRBASE
        or zone.zone_type == ZoneTypes.FARP then
            if zone.ammo_depot_intact == false then return false end

            local depot_point = UnitHandler.findClearPoint(zone,30,200,40)
            
            local ammo_depot = mist.dynAddStatic({
                type = ".Ammunition depot",
                country = country_name,
                category = "Warehouses",
                x = depot_point.x,
                y = depot_point.y
            })
            if ammo_depot then
                zone.ammo_depot_intact = true
                zone.linked_ammo_depot = ammo_depot.name
                zone.ammo_depot_last_destroyed = nil
                table.insert(zone.linked_statics, ammo_depot.name)
                return true
            end

        elseif zone.zone_type == ZoneTypes.COMMS then
            if zone.comms_tower_intact == false then return false end
            local point = mist.getRandomPointInZone(zone.name,Config.spawn_inner_radius) or {x=zone.zone.point.x+25,y=zone.zone.point.z-19}

            local comms_tower = mist.dynAddStatic({
                type = "Comms tower M",
                country = country_name,
                category = "Fortifications",
                x = point.x,
                y = point.y})
            if comms_tower then
                zone.comms_tower_intact = true
                zone.linked_comms_tower = comms_tower.name
                
                utils.editCommsAntennasCount(zone.side, 1)
               
                table.insert(zone.linked_statics, comms_tower.name)
                return true
            else
                MissionLogger:error("Could not spawn comms tower for ".. zone.name)
            end
        end
        return false
    end

    --- Build a set of every LATE-ACTIVATED group name present in the mission,
    --- using ONLY native DCS data (env.mission) -- no mist. The template groups
    --- the framework clones (GroupData.COMMON_ASSETS) are late-activated ME
    --- groups; this walk lets us verify they exist BEFORE anything tries to clone
    --- them (mist.teleportToPoint indexes nil and hard-errors when the group is
    --- missing -- see the UnitHandler.initFARP crash).
    ---@return table<string, boolean> set of late-activated group names -> true
    local function getLateActivatedGroupNames()
        local names = {}
        local mission = env and env.mission
        local coalitions = mission and mission.coalition
        if not coalitions then return names end
        for _, coal in pairs(coalitions) do
            if type(coal) == "table" and coal.country then
                for _, country in pairs(coal.country) do
                    if type(country) == "table" then
                        -- Group categories: plane, helicopter, vehicle, ship,
                        -- static. Each holds a .group array of ME templates.
                        for _, cat in pairs(country) do
                            if type(cat) == "table" and cat.group then
                                for _, group in pairs(cat.group) do
                                    if type(group) == "table" and group.name
                                       and group.lateActivation then
                                        names[group.name] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return names
    end

    --- Logistics assets that are NOT flown in some eras (the capture/resupply
    --- mechanics resolve INSTANTLY when no era-appropriate transport exists, e.g.
    --- WW2). For those we must not validate a template that will never be cloned.
    --- Maps the COMMON_ASSETS asset key -> a predicate that returns true when the
    --- asset IS actually used for the active era.
    local function isLogisticsAssetUsed(asset_key)
        if asset_key == "capture_helicopter"
        or asset_key == "reinforcement_helicopter"
        or asset_key == "LHA_capture_helicopter" then
            return EraSystem.isHelicopterEraCapable()
        end
        if asset_key == "resupply_aircraft" then
            return EraSystem.isAirResupplyEraCapable()
        end
        return true
    end

    --- Collect the group name that EACH GroupData.COMMON_ASSETS asset will
    --- actually clone for the ACTIVE era, paired with a human-readable path and a
    --- flag for whether that name came from the active era's OWN entry or from a
    --- fallback (MODERN / any other era).
    ---
    --- We validate the REAL spawn target: resolveTaskTemplateName returns exactly
    --- the name the spawn path will clone (active era's own entry if present,
    --- otherwise the MODERN/base fallback). This gives full crash protection. The
    --- `own_entry` flag lets the reporter tailor the fix advice -- a missing OWN
    --- entry means "build that ME group or remove the per-era entry to fall back";
    --- a missing FALLBACK name means the base/MODERN group itself is wrong.
    --- Logistics assets that resolve to an INSTANT mechanic in the active era are
    --- skipped (they are never cloned -- see isLogisticsAssetUsed).
    ---@return table[] list of { name=string, path=string, own_entry=boolean }
    local function collectCommonAssetTemplateRefs()
        local refs = {}
        local assets = GroupData and GroupData.COMMON_ASSETS
        if not assets then return refs end
        for side_key, side_tbl in pairs(assets) do
            if type(side_tbl) == "table" then
                for asset_key, asset_val in pairs(side_tbl) do
                    if isLogisticsAssetUsed(asset_key) then
                        -- The actual spawn target (with fallback) ...
                        local resolved = EraSystem.resolveTaskTemplateName(asset_val)
                        -- ... and whether it is the active era's OWN entry.
                        local strict = EraSystem.resolveTaskTemplateNameStrict(asset_val)
                        if type(resolved) == "string" then
                            refs[#refs + 1] = {
                                name = resolved,
                                path = "COMMON_ASSETS." .. tostring(side_key) .. "." .. tostring(asset_key),
                                own_entry = (strict ~= nil),
                            }
                        end
                    end
                end
            end
        end
        return refs
    end

    --- Preflight check, run ONCE at mission start (before any spawning), that
    --- every late-activated template group referenced by GroupData.COMMON_ASSETS
    --- actually exists in the mission. Missing groups are almost always a typo or
    --- a forgotten/renamed ME group; each one is surfaced to the user with
    --- env.error(..., true) (the second arg pops the in-game error box) so the
    --- mistake is visible immediately instead of as a later mist index crash.
    ---@return boolean ok true when every referenced group was found
    function UnitHandler.validateGroupTemplates()
        local present = getLateActivatedGroupNames()
        local refs = collectCommonAssetTemplateRefs()

        -- De-duplicate: the same group name may be referenced from several paths
        -- (e.g. an era table whose entries all point at one base group). Report
        -- each MISSING name once, listing every config path that needs it. Track
        -- whether the name comes from the active era's OWN entry so the fix advice
        -- can be tailored.
        local missing_paths = {}   -- name -> { path, ... }
        local missing_own = {}     -- name -> boolean (any ref was an own-entry)
        local missing_order = {}   -- preserves first-seen order for stable output
        for _, ref in ipairs(refs) do
            if not present[ref.name] then
                if not missing_paths[ref.name] then
                    missing_paths[ref.name] = {}
                    missing_order[#missing_order + 1] = ref.name
                end
                table.insert(missing_paths[ref.name], ref.path)
                missing_own[ref.name] = missing_own[ref.name] or ref.own_entry
            end
        end

        if #missing_order == 0 then
            MissionLogger:info("Group template validation passed: all referenced late-activated groups exist.")
            return true
        end

        for _, name in ipairs(missing_order) do
            local paths = table.concat(missing_paths[name], ", ")
            -- Tailor the fix advice: an OWN per-era entry that points at a missing
            -- group is most often an era template you have not built yet -- the
            -- user can either create it OR remove that era entry so the asset
            -- falls back to the base/MODERN group. A missing fallback name means
            -- the base/MODERN group itself is wrong.
            local advice
            if missing_own[name] then
                advice = "Create that group in the mission editor (Late Activation, exact name), "
                    .. "OR remove the per-era entry so it falls back to the base/MODERN group."
            else
                advice = "Check the mission editor for a missing/renamed/typo group name. "
                    .. "It must match EXACTLY and be set to Late Activation."
            end
            env.error(string.format(
                "CONFIG ERROR: late-activated group '%s' referenced by %s was not found in the mission. %s",
                tostring(name), paths, advice), true)
        end

        MissionLogger:error(string.format(
            "Group template validation FAILED: %d referenced group(s) missing from the mission.", #missing_order))
        return false
    end

    ---@param zone ZoneHandler
    ---@param restock boolean
    function UnitHandler.initFARP(zone,restock)
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
            -- { type = "FARP", category = "Heliports", shape_name = "FARPS", offset_x = 0, offset_y = 0 },

            -- Tents (clustered NE of the pad)
            { type = "FARP Tent", category = "Fortifications", offset_x = 90, offset_y = 95 },
            { type = "FARP Tent", category = "Fortifications", offset_x = 110, offset_y = 95 },

            -- Ammo Storage (NW corner)
            { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = -95, offset_y = 90 },
            { type = "FARP Ammo Dump Coating", category = "Fortifications", offset_x = -95, offset_y = 100 },


            -- Fuel Depots (SE corner)
            { type = "FARP Fuel Depot", category = "Fortifications", offset_x = 90, offset_y = -95 },
            { type = "FARP Fuel Depot", category = "Fortifications", offset_x = 100, offset_y = -95 },
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
 
                if static_data.type ~= "Invisible FARP" then
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
                        table.insert(zone.linked_statics, new_static.name)
                    end
                else
                    local new_static = coalition.addStaticObject(country_name_id, {
                        ["category"] = static_data.category,
                        ["shape_name"] = static_data.shape_name,
                        ["type"] = static_data.type,
                        ["unitId"] = mist.getNextUnitId(),
                        ["x"] = static_point.x,
                        ["y"] = static_point.y,
                        ["name"] = "FARP " .. zone.name,
                        ["heading"] = 0,
                        ["dead"] = false,
                        ["dynamicSpawn"] = true,
                        ["allowHotStart"] = true
                    })

                    if new_static and new_static.getName then
                        zone.linked_farp = new_static:getName()
                    end
                end
            end
        end

        -- Add to warehouse
        if zone.linked_farp and restock then
            timer.scheduleFunction(function()
                WarehouseManager:clearWarehouse(zone.linked_farp)
                WarehouseManager:attributeAirbaseStock(zone.linked_farp, zone.side, {StockTypes.FARP})
            end, {}, timer.getTime()+1)
        end


        local group_offset_x = -95
        local group_offset_y = -95
        local group_spawn_point = {
            x = base_x + group_offset_x,
            y = base_y + group_offset_y
        }
        
        -- Vehicle group
        local group_template_name_side
        if zone.side == coalition.side.RED then
            group_template_name_side = GroupData.COMMON_ASSETS.RED.farp
        else
            group_template_name_side = GroupData.COMMON_ASSETS.BLUE.farp
        end
        local group_template_name = EraSystem.resolveTaskTemplateName(group_template_name_side)

        if group_template_name then
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
            end
        end
    end

    function UnitHandler.carrierCheck()

        local function destroyShip(unit_name, label)
            if not unit_name then return end

            local ship_unit = Unit.getByName(unit_name)
            if not ship_unit or not ship_unit:isExist() then return end

            local ship_group = ship_unit:getGroup()
            if ship_group and ship_group:isExist() then
                MissionLogger:info("Destroying " .. label .. " as per scenario settings...")
                ship_group:destroy()
            end
        end

        local carrier_data = Config.carrier_setup
        if carrier_data and not carrier_data.enabled then
            destroyShip(carrier_data.carrier_unit_name, "carrier")
        end

        local lha_data = Config.lha_setup
        if lha_data and not lha_data.enabled then
            destroyShip(lha_data.lha_unit_name, "LHA")
        end
    end

    ---@param group_name string|nil cargo group to despawn after the drop; nil for an instant (aircraft-less) resupply
    ---@param airbase_name string
    ---@param side coalition.side
    ---@param stock_types StockTypes[]|nil if none are provided, a random stock type will be chosen
    function UnitHandler.simulateResupply(group_name,airbase_name, side, stock_types)
        local possible_stocks_rnd =
            {
                {
                    out_text = "AA Aircraft, AA Long Range and AA Short Range missiles",
                    stocks = {
                        StockTypes.AA_AIRCRAFT,
                        StockTypes.AIR_AIR_LONG_RANGE,
                        StockTypes.AIR_AIR_SHORT_RANGE,
                    },
                },
                {
                    out_text = "AG and Cargo Aircraft",
                    stocks = {
                        StockTypes.CARGO_AIRCRAFT,
                        StockTypes.AG_AIRCRAFT,
                    },
                },
                {
                    out_text = "AG Missiles and Rockets",
                    stocks = {
                        StockTypes.AIR_GROUND_GUIDED_MISSILES,
                        StockTypes.AIR_GROUND_ROCKETS,
                    },
                },
                {
                    out_text = "AG Unguided and Guided Bombs",
                    stocks = {
                        StockTypes.AIR_GROUND_BOMBS,
                        StockTypes.AIR_GROUND_GUIDED_BOMBS,
                    },
                },
                {
                    out_text = "ECM, TGPs and Misc Equipment",
                    stocks = {
                        StockTypes.ECM,
                        StockTypes.TGP,
                        StockTypes.MISC,
                    },
                },
            }

        if not stock_types then
            stock_types = stock_types or {}
        end

        local stock_type_choice = possible_stocks_rnd[math.random(1,#possible_stocks_rnd)]

        local out_text = ""
        local chosen_stocks = {}
        if #stock_types == 0 and Config.random_resupply_types then
            chosen_stocks = stock_type_choice.stocks
            out_text = stock_type_choice.out_text
        elseif #stock_types == 0 and not Config.random_resupply_types then
            chosen_stocks = {StockTypes.INITIAL}
            out_text = "Initial Stock Package"
        else
            chosen_stocks = mist.utils.deepCopy(stock_types)
            local stock_descs = {
                [StockTypes.AA_AIRCRAFT] = "AA Aircraft",
                [StockTypes.AIR_AIR_LONG_RANGE] = "AA Long Range Missiles",
                [StockTypes.AIR_AIR_SHORT_RANGE] = "AA Short Range Missiles",
                [StockTypes.CARGO_AIRCRAFT] = "Cargo Aircraft",
                [StockTypes.AG_AIRCRAFT] = "AG Aircraft",
                [StockTypes.AIR_GROUND_GUIDED_MISSILES] = "AG Missiles",
                [StockTypes.AIR_GROUND_ROCKETS] = "AG Rockets",
                [StockTypes.AIR_GROUND_BOMBS] = "AG Unguided Bombs",
                [StockTypes.AIR_GROUND_GUIDED_BOMBS] = "AG Guided Bombs",
                [StockTypes.ECM] = "ECM Equipment",
                [StockTypes.TGP] = "TGPs",
                [StockTypes.MISC] = "Misc Equipment",
                [StockTypes.INITIAL] = "Initial Stock Package",
            }
            for _, stock in ipairs(chosen_stocks) do
                if out_text ~= "" then out_text = out_text .. ", " end
                out_text = out_text .. (stock_descs[stock] or "Unknown Stock Type")
            end
        end
        if #chosen_stocks ~= 0 then
            local prefix = (side == coalition.side.RED) and "RED" or "BLUE"
            trigger.action.outTextForCoalition(side, "RESUPPLY Airdrop packaged secured at " .. airbase_name.."\nAssets received: " ..out_text, 10)
            trigger.action.outSoundForCoalition(side, "supply_package_received.ogg")

            MissionLogger:info(prefix .. " Resupply airdrop delivered at " .. airbase_name)

            
            if side == coalition.side.RED then
                WarehouseManager:attributeAirbaseStock(airbase_name, coalition.side.RED, chosen_stocks or {StockTypes.INITIAL})
            else
                local stocks = chosen_stocks or {StockTypes.INITIAL}
                WarehouseManager:attributeAirbaseStock(airbase_name, coalition.side.BLUE, stocks)
            end
        end
        -- group_name is nil for an instant (aircraft-less) resupply: nothing to
        -- de-register or despawn in that case.
        if group_name then
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

function UnitHandler.checkCarrierEra()
    local is_allowed = false
    if Config.carrier_setup and Config.carrier_setup.enabled then
        for _, era in pairs(Config.era_system.eras_selected) do
            if utils.tableContains(Config.era_system.carrier_eras_allowed, era) then
                is_allowed = true
                break
            end
        end
        if not is_allowed then
            MissionLogger:info("CARRIER NOT ALLOWED")
            local carrier = Unit.getByName(Config.carrier_setup.carrier_unit_name)
            if carrier and carrier.isExist and carrier:isExist() then
                local group = carrier:getGroup()
                if group and group:isExist() then
                    group:destroy()
                else
                    carrier:destroy()
                end
                Config.carrier_setup.enabled = false
            end
        end
    end
end
function UnitHandler.checkLHAEra()
    local is_allowed = false
    if Config.lha_setup and Config.lha_setup.enabled then
        for _, era in pairs(Config.era_system.eras_selected) do
            if utils.tableContains(Config.era_system.lha_eras_allowed, era) then
                is_allowed = true
                break
            end
        end
        if not is_allowed then
            local lha = Unit.getByName(Config.lha_setup.lha_unit_name)
            if lha and lha.isExist and lha:isExist() then
                local group = lha:getGroup()
                if group and group:isExist() then
                    group:destroy()
                else
                    lha:destroy()
                end
                Config.lha_setup.enabled = false
            end
        end
    end
end


---@param zone ZoneHandler
---@return Object[]
function UnitHandler.findObjectsInZone(zone)
    local objects = {}
    local volume = zone:calcVolume()
    if not volume then return objects end
    world.searchObjects({Object.Category.CARGO, Object.Category.UNIT, Object.Category.STATIC}, volume, function(obj)
        if obj and obj:isExist() and obj.getVelocity and obj.getTypeName then
            table.insert(objects,obj)
        end
        return true
    end)
    return objects
end