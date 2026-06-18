UnitComposer = {} do


    local SAM_SUPPLY_OFFSET = 100     -- m(eters) how far the resupply truck sits from the SAM it serves.

    local DEFAULT_SKILL = "High"     -- default group skill for spawned ground units.

    local GROUP_COMPOSITIONS = {
        [ZoneTypes.AIRBASE] = {
            { roles = { "SAM_IR" },  weight = 1 },   -- ex SA-19
            { roles = { "SAM_EM" },  weight = 1 },   -- ex SA-15
            { roles = { "AAA" },     weight = 2 },   -- ex ZSU-23
            { roles = { "MANPADS" }, weight = 1 },
            { roles = { "TANK" },    weight = 0 },
            { roles = { "APC", "IFV" }, weight = 1 },
            { roles = { "TRUCK" },   weight = 2 },
            { roles = { "INFANTRY" }, weight = 3 },
        },
        [ZoneTypes.STRONGPOINT] = {
            { roles = { "SAM_IR" },  weight = 1 },
            { roles = { "TANK" },    weight = 3 },
            { roles = { "IFV", "APC" }, weight = 3 },
            { roles = { "MANPADS" }, weight = 1 },
            { roles = { "INFANTRY" }, weight = 3 },
            { roles = { "ARTILLERY" }, weight = 1 },
        },
        [ZoneTypes.FARP] = {
            { roles = { "SAM_IR" },  weight = 2 },
            { roles = { "SAM_EM" },  weight = 1 },
            { roles = { "AAA" },     weight = 1 },
            { roles = { "TANK" },    weight = 1 },
            { roles = { "TRUCK" },   weight = 3 },
            { roles = { "INFANTRY" }, weight = 2 },
        },
        [ZoneTypes.LOGISTICS] = {
            { roles = { "TRUCK" },     weight = 4 },
            { roles = { "SUPPLY_TRUCK" }, weight = 2 },
            { roles = { "INFANTRY" },  weight = 2 },
            { roles = { "APC" },       weight = 1 },
        },
        [ZoneTypes.COMMS] = {
            { roles = { "INFANTRY" }, weight = 3 },
            { roles = { "TRUCK" },    weight = 1 },
            { roles = { "APC" },      weight = 1 },
        },
        [ZoneTypes.EWSITE] = {
            -- EWR unit is added explicitly (see compose); this is the guard.
            { roles = { "INFANTRY" }, weight = 2 },
            { roles = { "AAA", "MANPADS" }, weight = 1 },
            { roles = { "TRUCK" },    weight = 1 },
        },
    }

    --- Target unit count for this zone, applying composition_randomness variance.
    ---@param zone ZoneHandler
    ---@return number count (>=1)
    local function resolveUnitCount(zone)
        local level = zone.level or 1
        local base
        if zone.zone_type == ZoneTypes.AIRBASE and level == 1 then
            base = Config.era_system.airbase_tier1_units or 5
        else
            base = (Config.era_system.units_per_tier and Config.era_system.units_per_tier[level]) or 2
        end
        local variance = Config.era_system.composition_randomness or 0
        if variance > 0 then
            local delta = base * variance
            base = base + (math.random() * 2 * delta - delta)
        end
        local count = math.floor(base + 0.5)
        if count < 1 then count = 1 end
        return count
    end

    ---@param pool string[]
    ---@return table|nil entry, string|nil country
    local function pickEntryForSlot(slot, pool)
        local candidates = {}
        local cand_country = {}
        for _, role in ipairs(slot.roles) do
            for _, country in ipairs(pool) do
                local matches = EraSystem.getGroundUnits({ role = role, country = country })
                for _, e in ipairs(matches) do
                    candidates[#candidates + 1] = e
                    cand_country[#cand_country + 1] = country
                end
            end
        end
        if #candidates == 0 then return nil end
        local i = math.random(1, #candidates)
        return candidates[i], cand_country[i]
    end

    --- Build a weighted, round-robin pick order from a recipe.
    ---@param recipe table
    ---@return table[] expanded slot list (slots repeated by weight)
    local function expandRecipe(recipe)
        local expanded = {}
        local max_weight = 1
        for _, slot in ipairs(recipe) do
            if (slot.weight or 1) > max_weight then max_weight = slot.weight or 1 end
        end
 
        for tier = 1, max_weight do
            for _, slot in ipairs(recipe) do
                if (slot.weight or 1) >= tier then
                    expanded[#expanded + 1] = slot
                end
            end
        end
        return expanded
    end


    ---@param origin vec2
    ---@param placed_positions table|nil prior placed unit positions
    ---@param validTerrain table|nil mist terrain filter list
    ---@param minimum_spacing number|nil minimum distance to any prior unit (default 10)
    ---@return number x, number y
    local function scatterPos(origin, placed_positions, validTerrain, minimum_spacing)
        local terrain_filter = validTerrain or { "LAND", "ROAD" }
        local spacing = minimum_spacing or 10

        local function isFarEnough(coord)
            if not placed_positions then return true end
            for _, pos in ipairs(placed_positions) do
                local dx = coord.x - pos.x
                local dy = coord.y - pos.y
                if (dx * dx + dy * dy) < (spacing * spacing) then
                    return false
                end
            end
            return true
        end

        local unit_coord
        for _ = 1, 100 do
            unit_coord = mist.getRandPointInCircle(origin, 200)
            if mist.isTerrainValid(unit_coord, terrain_filter) and isFarEnough(unit_coord) then
                return unit_coord.x, unit_coord.y
            end
        end

        -- fallback: return origin
        return origin.x, origin.y
    end

    ---@return string
    local function uniqueStamp()
        return string.format("%d_%d", math.floor(timer.getTime()), math.random(1000, 9999))
    end


    ---@param name_prefix string
    ---@param unit_specs table[] each { type, x, y, heading }
    ---@return table|nil group_table (nil if no units)
    local function buildGroupTable(name_prefix, unit_specs)
        if #unit_specs == 0 then return nil end
        local group_name = name_prefix .. "_" .. uniqueStamp()
        local units = {}
        for i, spec in ipairs(unit_specs) do
            units[i] = {
                ["type"] = spec.type,
                ["name"] = group_name .. "_u" .. i,
                ["unitId"] = mist.getNextUnitId(),
                ["x"] = spec.x,
                ["y"] = spec.y,
                ["heading"] = spec.heading or 0,
                ["skill"] = spec.skill or DEFAULT_SKILL,
                ["playerCanDrive"] = false,
            }
        end
        return {
            ["name"] = group_name,
            ["groupId"] = mist.getNextGroupId(),
            ["task"] = "Ground Nothing",
            ["hidden"] = false,
            ["units"] = units,
        }
    end

    ---@param side number coalition.side of the zone the SAM belongs to
    ---@param origin vec2
    ---@return number|nil heading_radians
    local function enemyFacingHeading(side, origin)
        local enemy_airbase = (side == coalition.side.RED) and blue_airbase or red_airbase
        if not enemy_airbase or not enemy_airbase.zone or not enemy_airbase.zone.point then return nil end

        ---@diagnostic disable-next-line: deprecated
        return math.atan2(enemy_airbase.zone.point.z - origin.y, enemy_airbase.zone.point.x - origin.x)
    end

    ---@param entry table Stocks.GroundUnits.* with role SAM_*
    ---@param origin vec2
    ---@param facing number|nil heading (radians) for search/track radars; random when nil
    ---@return table[] unit_specs
    local function buildSAMUnitSpecs(entry, origin, facing)

        local specs = {}
        local idx = 0
        local function add(unit_type, heading)
            if not unit_type then return end
            idx = idx + 1
            local x, y = scatterPos(origin, specs, nil, 10)
            local h = heading or (math.random() * 2 * math.pi)
            specs[#specs + 1] = { type = unit_type, x = x, y = y, heading = h }
        end

        local parts = entry.sam_parts
        if parts then
            -- search & track radars face the enemy threat axis everything else
            -- keeps a random heading.
            add(parts.search_radar, facing)
            add(parts.acquisition_radar)
            add(parts.track_radar, facing)
            add(parts.optical)
            add(parts.command)
            add(parts.control)
            local n = parts.launcher_count or 2
            for _ = 1, n do add(parts.launcher) end
        else
            -- self-contained system (SA-15 / SA-8): a small battery of itself.
            local n = math.random(2, 3)
            for _ = 1, n do add(entry.type) end
        end
        return specs
    end

    local SAM_FALLBACK_ORDER = {
        SAM_TYPES.LONG_RANGE, SAM_TYPES.MEDIUM_RANGE, SAM_TYPES.SHORT_RANGE,
    }

    --- Find a SAM "system" entry for one exact classification + country pool.
    ---@param classification string SAM_TYPES.*
    ---@param pool string[]
    ---@param restrict_roles table|nil set of acceptable roles, e.g. { SAM_MR=true }
    ---@return table|nil entry, string|nil country
    local function pickSamSystemForClass(classification, pool, restrict_roles)
        -- try countries in random order so a mix doesn't always pick the first.
        local order = {}
        for i = 1, #pool do order[i] = pool[i] end
        for i = #order, 2, -1 do
            local j = math.random(1, i); order[i], order[j] = order[j], order[i]
        end
        for _, country in ipairs(order) do
            local matches = EraSystem.getGroundUnits({
                country = country, sam_classification = classification })
            local filtered = {}
            for _, e in ipairs(matches) do
                -- only true SAM "systems", not MANPADS/SAM_IR point defence,
                -- unless the caller explicitly allows them.
                local role_ok
                if restrict_roles then
                    role_ok = restrict_roles[e.role] == true
                else
                    role_ok = (e.role == "SAM_SR" or e.role == "SAM_MR"
                        or e.role == "SAM_LR" or e.role == "SAM_EM")
                end
                if role_ok then filtered[#filtered + 1] = e end
            end
            if #filtered > 0 then
                return filtered[math.random(1, #filtered)], country
            end
        end
        return nil, nil
    end

    ---@param classification SAM_TYPES
    ---@param pool string[]
    ---@param restrict_roles table|nil set of acceptable roles, e.g. { SAM_MR=true }
    ---@return table|nil entry, string|nil country
    local function pickSamSystem(classification, pool, restrict_roles)
        local entry, country = pickSamSystemForClass(classification, pool, restrict_roles)
        if entry or restrict_roles then
            return entry, country
        end

        -- requested tier unavailable: try progressively lower tiers below it.
        local seen_requested = false
        for _, class in ipairs(SAM_FALLBACK_ORDER) do
            if seen_requested and class ~= classification then
                entry, country = pickSamSystemForClass(class, pool, restrict_roles)
                if entry then
                    MissionLogger:info("[UnitComposer] No " .. tostring(classification)
                        .. " SAM available; fell back to " .. tostring(class))
                    return entry, country
                end
            end
            if class == classification then seen_requested = true end
        end
        return nil, nil
    end

    --- Find a SUPPLY_TRUCK entry valid for a country.
    ---@param country string
    ---@return table|nil entry
    local function pickSupplyTruck(country)
        local matches = EraSystem.getGroundUnits({ role = "SUPPLY_TRUCK", country = country })
        if #matches == 0 then return nil end
        return matches[math.random(1, #matches)]
    end

    ---@param recipe table
    ---@param count number
    ---@param pool string[]
    ---@param origin vec2
    ---@return table<string, table[]> specs_by_country
    local function composeFromRecipe(recipe, count, pool, origin)
        local expanded = expandRecipe(recipe)
        if #expanded == 0 then return {} end

        local specs_by_country = {}
        local placed_all = {}   -- shared across all countries for spacing checks
        local placed = 0
        local slot_i = 0
        -- iterate enough times to fill `count`, omitting unavailable slots.
        local attempts = 0
        local max_attempts = count * #expanded + #expanded

        while placed < count and attempts < max_attempts do
            attempts = attempts + 1
            slot_i = slot_i + 1

            if slot_i > #expanded then slot_i = 1 end

            local slot = expanded[slot_i]
            local entry, country = pickEntryForSlot(slot, pool)

            if entry and country then
                placed = placed + 1
                specs_by_country[country] = specs_by_country[country] or {}
                local list = specs_by_country[country]
                local x, y = scatterPos(origin, placed_all, nil, 10)
                local spec = { type = entry.type, x = x, y = y, heading = math.random() * 2 * math.pi }
                list[#list + 1] = spec
                placed_all[#placed_all + 1] = spec
            end

        end
        return specs_by_country
    end

    ---@param zone ZoneHandler
    ---@return table[] compositions (see file header for shape)
    function UnitComposer.compose(zone)
        local out = {}
        if not zone or zone.side == coalition.side.NEUTRAL then return out end

        local country_pool = Config.era_system.coalition_selector[zone.side]
        local origin = UnitHandler.findClearPoint(zone)
        local zt = zone.zone_type

        local side_tag = (zone.side == coalition.side.RED) and "RED" or "BLUE"
        local name_prefix = side_tag .. " " .. tostring(zt) .. " " .. tostring(zone.name)

        ----------------------------------------------------------------------
        -- SAMSITE: a single matching SAM system + a ~100 m supply truck.
        ----------------------------------------------------------------------
        if zt == ZoneTypes.SAMSITE then
            local entry, country = pickSamSystem(zone.sam_classification, country_pool)
            if entry and country then
                local facing = enemyFacingHeading(zone.side, origin)
                local specs = buildSAMUnitSpecs(entry, origin, facing)
                local group_table = buildGroupTable(name_prefix .. " SAM", specs)
                if group_table then
                    out[#out + 1] = { country = country, role = "primary", group_table = group_table }
                end

                -- resupply truck ~100 m from the SAM (drives the resupply ring).
                local truck = pickSupplyTruck(country)
                if truck then
                    local a = math.random() * 2 * math.pi
                    local tx = origin.x + SAM_SUPPLY_OFFSET * math.cos(a)
                    local ty = origin.y + SAM_SUPPLY_OFFSET * math.sin(a)
                    local truck_gt = buildGroupTable(name_prefix .. " SUPPLY",
                        { { type = truck.type, x = tx, y = ty, heading = 0 } })
                    if truck_gt then
                        out[#out + 1] = { country = country, role = "sam_supply", group_table = truck_gt }
                    end
                end
            else
                MissionLogger:warn("[UnitComposer] No SAM system available for zone "
                    .. tostring(zone.name) .. " (" .. tostring(zone.sam_classification) .. ")")
            end
            return out
        end

        ----------------------------------------------------------------------
        -- EWSITE: an EWR unit + minimal guard.
        ----------------------------------------------------------------------
        if zt == ZoneTypes.EWSITE then
            -- EWR unit (its own group, registered to its operator country).
            local ewr_country
            local ewr_entry
            do
                local order = {}
                for i = 1, #country_pool do order[i] = country_pool[i] end
                for _, country in ipairs(order) do
                    local m = EraSystem.getGroundUnits({ role = "EWR", country = country })
                    if #m > 0 then ewr_entry = m[math.random(1, #m)]; ewr_country = country break end
                end
            end
            if ewr_entry then
                local x, y = scatterPos(origin, nil, nil, 10)
                local gt = buildGroupTable(name_prefix .. " EWR",
                    { { type = ewr_entry.type, x = x, y = y, heading = math.random() * 2 * math.pi } })
                if gt then out[#out + 1] = { country = ewr_country, role = "primary", group_table = gt } end
            end
            -- minimal guard from the recipe.
            local guard_count = math.max(1, math.floor((resolveUnitCount(zone)) / 2))
            local specs_by_country = composeFromRecipe(GROUP_COMPOSITIONS[ZoneTypes.EWSITE], guard_count, country_pool, origin)
            for country, specs in pairs(specs_by_country) do
                local gt = buildGroupTable(name_prefix .. " GUARD " .. country, specs)
                if gt then out[#out + 1] = { country = country, role = "guard", group_table = gt } end
            end
            return out
        end

        ----------------------------------------------------------------------
        -- STRONGPOINT / AIRBASE / FARP / LOGISTICS / COMMS
        ----------------------------------------------------------------------
        local recipe = GROUP_COMPOSITIONS[zt]
        if recipe then
            local count = resolveUnitCount(zone)
            local specs_by_country = composeFromRecipe(recipe, count, country_pool, origin)
            for country, specs in pairs(specs_by_country) do
                local gt = buildGroupTable(name_prefix .. " " .. country, specs)
                if gt then out[#out + 1] = { country = country, role = "primary", group_table = gt } end
            end
        end

        ----------------------------------------------------------------------
        -- AIRBASE second group "Airbase SAMs" -- level 3 & 4, medium threat.
        ----------------------------------------------------------------------
        if zt == ZoneTypes.AIRBASE and (zone.level == 3 or zone.level == 4) then
            -- place the SAM group offset from the main origin so it forms a
            -- distinct emplacement (re-roll a clear point).
            local sam_origin = UnitHandler.findClearPoint(zone)
            local entry, country = pickSamSystem(SAM_TYPES.MEDIUM_RANGE, country_pool, { SAM_MR = true })

            if entry and country then
                local facing = enemyFacingHeading(zone.side, sam_origin)
                local specs = buildSAMUnitSpecs(entry, sam_origin, facing)
                local group_table = buildGroupTable(name_prefix .. " AIRBASE SAM", specs)

                if group_table then
                    out[#out + 1] = { country = country, role = "airbase_sam", group_table = group_table }
                end

                local truck = pickSupplyTruck(country)
                if truck then
                    local a = math.random() * 2 * math.pi
                    local tx = sam_origin.x + SAM_SUPPLY_OFFSET * math.cos(a)
                    local ty = sam_origin.y + SAM_SUPPLY_OFFSET * math.sin(a)
                    local truck_gt = buildGroupTable(name_prefix .. " AIRBASE SAM SUPPLY",{ { type = truck.type, x = tx, y = ty, heading = 0 } })

                    if truck_gt then
                        out[#out + 1] = { country = country, role = "sam_supply", group_table = truck_gt }
                    end
                end
            end
        end

        return out
    end

end
