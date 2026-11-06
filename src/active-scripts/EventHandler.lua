ev = {}
function ev:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition then

            -- Check if the spawned unit is a radar
            if unit:hasAttribute("SAM SR") or unit:hasAttribute("EWR") or unit:hasAttribute("AWACS") then
                local side = unit:getCoalition()
                if EWRS_coalition and EWRS_coalition[side] then
                    table.insert(EWRS_coalition[side].radars, unit)
                    MissionLogger:info("EWRS: Added new radar unit " .. unit:getName() .. " to cache.")
                end
            end
        end

        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition and unit.isExist
        and unit:isExist() and unit.getPlayerName and unit:getPlayerName() then

            local function checkSpawnAllowed() -- Slot blocker
                if not unit or not unit.isExist or not unit:isExist() or not unit.getCoalition then return end
                MissionLogger:info("Slot blocker checking for ".. unit:getName())
                local unit_pos = unit:getPoint()
                local unit_coalition = unit:getCoalition()
                -- Checks if the player has the right to spawn in the airbase
                local can_spawn = false
                for _,zone in ipairs(zones) do
                    if zone:isPointInsideZone(unit_pos) then
                        -- Only check warehouse if zone belongs to player's coalition and is airbase/FARP
                        if zone.side == unit_coalition and (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP) then
                            if unit.getTypeName and unit:getTypeName() then
                                local acft_name = unit:getTypeName()

                                local wh_name = nil
                                if zone.zone_type == ZoneTypes.FARP and zone.linked_farp then
                                    wh_name = zone.linked_farp
                                elseif zone.zone_type == ZoneTypes.AIRBASE then
                                    wh_name = zone.airbase_name
                                end

                                if wh_name then
                                    local airbase = Airbase.getByName(wh_name)
                                    if airbase then
                                        local warehouse = airbase:getWarehouse()
                                        if warehouse then
                                            --MissionLogger:info(warehouse:getInventory())
                                            local acft_count = (warehouse:getItemCount(acft_name) or 0)+1
                                            --MissionLogger:info(acft_count)
                                            if acft_count >= 1 then -- the airplane gets used before this script is executed, this is a must
                                                can_spawn = true
                                            else
                                                MissionLogger:info(string.format(
                                                    "Slot blocked:  %s at %s (stock=%d)",
                                                    acft_name,
                                                    wh_name,
                                                    acft_count
                                                ))

                                                can_spawn = false
                                                warehouse:addItem(acft_name,1)
                                            end
                                        end
                                    end
                                end

                            end
                            break
                        end

                    end
                end

                if not Config.enable_slot_blocker then
                    can_spawn = true
                end

                -- Allows player redfor for dev purposes
                if unit:getCoalition() == coalition.side.RED then
                    can_spawn = true
                end
                -- Allows carrier spawn
                local land_type = land.getSurfaceType({x = unit_pos.x, y = unit_pos.z})
                if land_type == land.SurfaceType.WATER then
                    can_spawn = true
                end

                -- Allows airborne units
                if unit:inAir() and Config.allow_air_spawn then
                    can_spawn = true
                end


                if not can_spawn then

                    local unit_id = unit:getID()

                    -- not allowed, destroy the unit
                    trigger.action.outSoundForUnit(unit_id, "error.ogg")
                    trigger.action.outTextForUnit(unit_id, "****************\n\nThis slot is not allowed! Consult F10 map and warehouse stocks.\n\n****************", 20)

                    timer.scheduleFunction(function ()
                        if unit and unit:isExist() then
                            unit:destroy()
                        end
                    end, {}, timer.getTime() + 1)
                else
                    local group = unit:getGroup()
                    if not group then return end

                    -- Init Commands
                    CommandHandler.clearF10(group)

                    -- Initiate the command menus for the player
                    ExperienceManager:addUser(unit)
                    local group_id = group:getID()
                    local xprank_root = missionCommands.addCommandForGroup(group_id, "XP/Rank", nil, function()
                        local user = ExperienceManager:fetchUser(unit)

                        if user then
                        local unit_id = unit:getID()

                            local rank_name = "Unranked"
                            local next_rank_xp = nil
                            local next_rank = "..."

                            for i = #Config.reward_system.ranks, 1, -1 do
                                local rank = Config.reward_system.ranks[i]
                                if user.xp >= rank.xp_required then
                                    rank_name = rank.name
                                    if i < #Config.reward_system.ranks then
                                        next_rank_xp = Config.reward_system.ranks[i + 1].xp_required
                                        next_rank = Config.reward_system.ranks[i + 1].name
                                    end
                                    break
                                end
                            end

                            if not next_rank then next_rank = "No Next Rank" end
                            local out_text = "N/A"
                            if not next_rank_xp then
                                out_text = "< XP and Rank >\n\nRank: "..rank_name.."\n\nXP: "..user.xp.." (+"..user.unclaimed_xp..")\nMissions Completed: "..user.missions_completed
                            else
                                out_text = "< XP and Rank >\n\nRank: "..rank_name.."\n\nXP: "..user.xp.." (+"..user.unclaimed_xp..")\nMissions Completed: "..user.missions_completed.."\n\nNext Rank: "..next_rank.."\n  "..next_rank_xp.." XP"
                            end
                            trigger.action.outTextForUnit(unit_id, out_text, 15)
                            trigger.action.outSoundForUnit(unit_id, "radio_beep4.ogg")
                        end
                    end)
                    CommandHandler.addToMenuTracking(group_id, xprank_root, "xp_rank_menu")
                    CommandHandler.init(unit)
                    CommandHandler.resourcesRequests(group)
                    CommandHandler.initTaskingRequests(group)
                    CommandHandler.operationsMenu(group,unit)
                    CommandHandler.tallyZone(unit)

                    JTAC.buildMenusForGroup(group, unit_coalition)

                    local ew = EWRS_coalition[unit_coalition]
                    ew:addRadioMenuForUser(unit)
                    ew:applySavedSetting(unit)
                end
            end

            checkSpawnAllowed()

        end
    end

    if event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT and event.initiator then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition and unit.isExist
        and unit:isExist() and unit.getPlayerName and unit:getPlayerName() then
            MissionLogger:info("Player " .. unit:getPlayerName() .. " leaving unit " .. unit:getName())
            -- Clear F10 menus
            local group = unit:getGroup()
            if group then
                CommandHandler.clearF10(group)
            end

        end
    end

    if event.id == world.event.S_EVENT_CRASH and event.initiator then
        if event.initiator.getGroup then
            local crashed_gr = event.initiator:getGroup()
            local crashed_gr_name = crashed_gr and crashed_gr.getName and crashed_gr:getName()

            -- A lost JTAC is reported to its coalition and torn down by JTAC:reportLost(),
            -- which also de-registers the enroute
            if crashed_gr_name and not JTAC.reportLostByGroup(crashed_gr_name) then
                local enroute_crash = EnrouteManager:findByGroup(crashed_gr_name)
                if enroute_crash then
                    EnrouteManager:remove(enroute_crash.group_name)
                    MissionLogger:info("Removed CRASHED " ..enroute_crash.ai_task_type.." from enroutes: " .. enroute_crash.group_name)
                end
            end
        end
    end

    if event.id == world.event.S_EVENT_AI_ABORT_MISSION and event.initiator then


        local unit = event.initiator
        if unit and unit.isExist and unit:isExist() and unit.getGroup then
            local abort_gr = unit:getGroup()
            if not abort_gr or not abort_gr.isExist or not abort_gr:isExist() then return end
            local group_name = abort_gr:getName()
            MissionLogger:info("AI unit aborted mission: " .. unit:getName())

            local enroute_aborted = EnrouteManager:findByGroup(group_name)
            if enroute_aborted then

                timer.scheduleFunction(function ()
                    local gr = Group.getByName(group_name)
                    if gr and gr.isExist and gr:isExist() then
                        trigger.action.explosion(gr:getUnit(1):getPoint(), 250)
                        EnrouteManager:remove(group_name)
                        MissionLogger:info("Removed damaged AI "..enroute_aborted.ai_task_type.." from enroutes: " .. group_name)
                    end

                end, {}, timer.getTime() + math.random(30,120))
            end
            
        end
    end

    if event.id == world.event.S_EVENT_LAND and event.initiator then
        -- Player related landings are handled in the ExperienceManager
        local unit = event.initiator
        if not unit or not unit.isExist or not unit:isExist() then return end
        local gr = unit:getGroup()
        if not gr or not gr.isExist or not gr:isExist() then return end
        local group_name = gr:getName()
        local desc = unit:getDesc()

        if desc.category == Unit.Category.HELICOPTER then
            MissionLogger:info("Helicopter landed: " .. unit:getName())

            -- ABORTED HELI
            local enroute_heli = EnrouteManager:findByGroup(group_name)
            if enroute_heli then
                local group_pos = mist.getLeadPos(group_name)
                EnrouteManager:handleHeloLanding(enroute_heli, unit, group_pos)
            end

            if unit and unit.getPlayerName and unit:getPlayerName() then
                local unit_coalition = unit:getCoalition()
                local u_id = unit:getID()
                local unit_name = unit:getName()
                local player_name = unit:getPlayerName()
                local landing_time = timer.getTime()
                -- check if heli landed in neutral zone
                for _,zone in ipairs(zones) do
                    if zone.side == coalition.side.NEUTRAL and zone:isPointInsideZone(unit:getPoint()) then
                        trigger.action.outTextForUnit(u_id, "Allied forces deployed at ".. zone.name..". Hold position.", 15)
                        trigger.action.outSoundForUnit(u_id, "radio click.ogg")

                        timer.scheduleFunction(function ()
                            local was_neutral = zone.side == coalition.side.NEUTRAL
                            zone:capture(unit_coalition)

                            local unit_check = Unit.getByName(unit_name)
                            if not (unit_check and unit_check:isExist() and unit_check:getLife() > 0) then return end
                            if unit_check:getPlayerName() ~= player_name or unit_check:inAir() then return end
                            if zone.side ~= unit_coalition or not zone:isPointInsideZone(unit_check:getPoint()) then return end

                            local user = ExperienceManager:fetchUser(unit_check)
                            if not user then return end
                            local capture_xp = Config.reward_system.xp_per_zone_captured or 0
                            if was_neutral and capture_xp > 0 then
                                trigger.action.outTextForUnit(u_id, "Captured, +" .. capture_xp .. "XP", 5)
                                user.unclaimed_xp = user.unclaimed_xp + capture_xp
                            end
                            if zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP then
                                ExperienceManager:debrief(unit_check, landing_time)
                            end
                        end, {}, timer.getTime() + math.random(50,60))
                        break
                    end
                end

            end

        elseif desc.category == Unit.Category.AIRPLANE then
            local enroute_task = EnrouteManager:findByGroup(group_name)
            if enroute_task and enroute_task.ai_task_type == AITaskTypes.RESUPPLY_CARGO then
                local landed_gr_name = enroute_task.group_name

                timer.scheduleFunction(function ()
                    EnrouteManager:remove(group_name)
                    MissionLogger:info("destroying landed cargo")
                    local gr = Group.getByName(landed_gr_name)
                    if gr and gr.isExist and gr:isExist() then
                        gr:destroy()
                    end
                end, {}, timer.getTime() + 120)
            end
        end
    elseif event.id == world.event.S_EVENT_DEAD and event.initiator then

        local unit = event.initiator

        -- Check if the dead unit was a radar (ground or air)
        if unit.hasAttribute and (unit:hasAttribute("SAM SR") or unit:hasAttribute("EWR") or unit:hasAttribute("AWACS"))
        and unit.getCoalition then
            local side = unit:getCoalition()
            if EWRS_coalition[side] then
                local radar_list = EWRS_coalition[side].radars
                for i = #radar_list, 1, -1 do
                    local radar = radar_list[i]
                    if radar and radar.isExist and radar:isExist() and radar.getID then
                        if radar:getID() == unit:getID() then
                            table.remove(radar_list, i)
                            MissionLogger:info("EWRS: Removed destroyed/dead radar unit " .. unit:getName() .. " from cache.")
                            break
                        end
                    else
                        -- Clean up non-existing radar entries
                        table.remove(radar_list, i)
                    end
                end
            end
        end

        if unit and unit.getName and Object.getCategory(unit) == Object.Category.STATIC then
            MissionLogger:info("Static unit destroyed: " .. unit:getName())
        end
    elseif event.id == world.event.S_EVENT_SHOT and event.weapon then
        if Config.moab and Config.moab.enabled and moabIsMoabWeapon(event.weapon) then
            local dropper = moabFindDropper(event.weapon:getPoint())
            local player_name, side = nil, nil
            if dropper then
                player_name = dropper:getPlayerName()
                side = dropper:getCoalition()
            end
            MissionLogger:info("MOAB released: " .. event.weapon:getTypeName() .. " by " .. tostring(player_name))
            moabTrackWeapon(event.weapon, player_name, side)
        end
    end
end

--------------------------------------------------------------------------------
-- MOAB (GBU-43) airdrop: scripted blast with a rolling shockwave
--------------------------------------------------------------------------------

---@param weapon Weapon
---@return boolean
function moabIsMoabWeapon(weapon)
    if not weapon or not weapon.getTypeName then return false end
    local type_name = string.lower(weapon:getTypeName() or "")
    for _, wanted in ipairs(Config.moab.weapon_types or {}) do
        if string.find(type_name, string.lower(wanted), 1, true) then return true end
    end
    return false
end

--- Closest airborne player unit to the release point (within dropper_search_radius).
---@param point table vec3
---@return Unit|nil
function moabFindDropper(point)
    local best, best_dist = nil, Config.moab.dropper_search_radius or 3000
    for _, s in ipairs({ coalition.side.BLUE, coalition.side.RED }) do
        for _, u in ipairs(coalition.getPlayers(s) or {}) do
            if u and u:isExist() and u:inAir() and u:getTypeName() == Stocks.Aircraft.C130J_30 then
                local p = u:getPoint()
                local d = math.sqrt((p.x - point.x) ^ 2 + (p.y - point.y) ^ 2 + (p.z - point.z) ^ 2)
                if d < best_dist then best, best_dist = u, d end
            end
        end
    end
    return best
end

--- Follows the bomb down and detonates at its last known position.
---@param weapon Weapon
---@param player_name string|nil
---@param side number|nil
function moabTrackWeapon(weapon, player_name, side)
    local last = weapon:getPoint()
    timer.scheduleFunction(function(_, time)
        if weapon:isExist() then
            last = weapon:getPoint()
            return time + 0.1
        end
        local gz = { x = last.x, y = land.getHeight({ x = last.x, y = last.z }), z = last.z }
        moabDetonate(gz, player_name, side)
        return nil
    end, nil, timer.getTime() + 0.1)
end

-- Linear interpolation over a list of {x, y} pairs (extrapolates with the last segment).
local function moabInterpolate(curve, value, from, to)
    if value <= curve[1][from] then return curve[1][to] end
    for i = 2, #curve do
        local a, b = curve[i - 1], curve[i]
        if value <= b[from] then
            return a[to] + (b[to] - a[to]) * (value - a[from]) / (b[from] - a[from])
        end
    end
    local a, b = curve[#curve - 1], curve[#curve]
    return b[to] + (value - b[from]) * (b[to] - a[to]) / (b[from] - a[from])
end

-- Shockwave arrival time (s) at a given distance (m)
local function moabTimeAt(distance) return moabInterpolate(Config.moab.shockwave_curve, distance, 1, 2) end

---@return string|nil kind, number xp
local function moabClassify(obj)
    local cat = Object.getCategory(obj)
    if cat == Object.Category.SCENERY then return "scenery", 0 end
    if cat == Object.Category.STATIC or cat == Object.Category.CARGO then return "static", 0 end
    if cat ~= Object.Category.UNIT then return nil, 0 end

    local rs = Config.reward_system
    if obj:hasAttribute("Planes") or obj:hasAttribute("Helicopters") then
        local xp = obj:hasAttribute("Planes") and rs.xp_per_aircraft_destroyed or rs.xp_per_helicopter_destroyed
        if obj:inAir() then return "air", xp end
        return "parked_aircraft", xp
    end
    if obj:hasAttribute("Infantry") then return "infantry", rs.xp_per_infantry_kill end
    if obj:hasAttribute("Ships") then return "ship", rs.xp_per_ship_sunk end
    if obj:hasAttribute("Tanks") then return "tank", rs.xp_per_vehicle_destroyed end
    if obj:hasAttribute("IFV") or obj:hasAttribute("APC") then return "ifv_apc", rs.xp_per_vehicle_destroyed end
    if obj:hasAttribute("SAM SR") or obj:hasAttribute("SAM TR") or obj:hasAttribute("IR Guided SAM") then
        return "truck_sam_aaa", rs.xp_per_sam_destroyed
    end
    return "truck_sam_aaa", rs.xp_per_vehicle_destroyed
end


local function moabIsAlive(obj, kind)
    if not (obj and obj:isExist()) then return false end
    local life = obj:getLife() or 0
    if kind == "static" or kind == "scenery" then return life > 0 end
    return life >= 1
end

local function moabEffects(gz)
    local now = timer.getTime()
    local id = math.floor(now * 1000)

    -- Ground-level big smoke that starts after `start` seconds and stops `duration` seconds later.
    -- Presets: 1-4 smoke+fire (small..huge), 5-8 smoke only (small..huge)
    local function smokeFor(name, x, z, preset, density, start, duration)
        timer.scheduleFunction(function()
            trigger.action.effectSmokeBig({ x = x, y = land.getHeight({ x = x, y = z }), z = z }, preset, density, name)
        end, nil, now + start)
        timer.scheduleFunction(function()
            trigger.action.effectSmokeStop(name)
        end, nil, now + start + duration)
    end

    if Config.moab.effect_fireball then
        -- Tight cluster of detonations: one fireball and one crater, not scattered pops
        for i = 0, 5 do
            timer.scheduleFunction(function()
                local a, r = math.random() * 2 * math.pi, (i == 0) and 0 or math.random(5, 35)
                trigger.action.explosion({ x = gz.x + r * math.cos(a), y = gz.y + math.random(0, 15), z = gz.z + r * math.sin(a) }, 500)
            end, nil, now + i * 0.1)
        end
    end

    if Config.moab.effect_column then
        -- Fireball lifting off the ground during the first seconds, before the cloud takes over
        for i = 0, 5 do
            timer.scheduleFunction(function()
                trigger.action.explosion({ x = gz.x + math.random(-10, 10), y = gz.y + 30 + i * 40, z = gz.z + math.random(-10, 10) }, 20)
            end, nil, now + 0.4 + i * 0.25)
        end
    end

    if Config.moab.effect_cloud then
        -- Several plumes packed close together so they merge into one wide cloud,
        -- decaying through the configured stages (each overlaps the next so it never pops out)
        local plumes = { { gz.x, gz.z } }
        local n, r = Config.moab.cloud_plumes or 4, Config.moab.cloud_radius or 60
        for i = 1, n do
            local a = (i / n) * 2 * math.pi + math.random() * 0.5
            local d = r * (0.6 + math.random() * 0.4)
            table.insert(plumes, { gz.x + d * math.cos(a), gz.z + d * math.sin(a) })
        end
        local stages = Config.moab.cloud_stages or { { 8, 1, 90 }, { 7, 0.9, 150 }, { 6, 0.6, 240 } }
        local start = 0.5
        for s, stage in ipairs(stages) do
            local overlap = (s < #stages) and 5 or 0
            for p, xz in ipairs(plumes) do
                smokeFor("MoabCloud" .. id .. "_" .. s .. "_" .. p, xz[1], xz[2], stage[1], stage[2], start, stage[3] + overlap)
            end
            start = start + stage[3]
        end
    end

    if Config.moab.effect_fires then
        -- A few small scattered grass fires; the explosive itself burns out in the fireball
        for i = 1, Config.moab.fire_count or 4 do
            local a, d = math.random() * 2 * math.pi, math.random(20, Config.moab.fire_radius or 150)
            smokeFor("MoabFire" .. id .. "_" .. i, gz.x + d * math.cos(a), gz.z + d * math.sin(a),
                1, 0.5 + math.random() * 0.3, 1 + math.random() * 3, (Config.moab.fire_duration or 240) * (0.5 + math.random() * 0.5))
        end
    end
end

--- Detonates a MOAB at ground zero. Hits everything in range, friendlies included.
---@param gz table vec3 ground zero
---@param player_name string|nil player credited with enemy kills (nil = no XP, e.g. Jupiter)
---@param side number|nil coalition of the dropper, used to decide what counts as an enemy
function moabDetonate(gz, player_name, side)
    local now = timer.getTime()
    MissionLogger:info(string.format("MOAB detonation at x=%.0f z=%.0f (player: %s)", gz.x, gz.z, tostring(player_name)))

    moabEffects(gz)

    local enemy_side = nil
    if side == coalition.side.BLUE then enemy_side = coalition.side.RED
    elseif side == coalition.side.RED then enemy_side = coalition.side.BLUE end

    local enemies = {} -- { obj, xp } enemy units that should be counted for XP
    local last_hit = 0

    local function hit(obj, kind, xp)
        local p = obj:getPoint()
        local d2 = math.sqrt((p.x - gz.x) ^ 2 + (p.z - gz.z) ^ 2)
        local d = (kind == "air") and math.sqrt(d2 ^ 2 + (p.y - gz.y) ^ 2) or d2
        if d > Config.moab.light_damage_radius then return end

        local kill_r = math.max(Config.moab.kill_radius[kind] or 0, Config.moab.fireball_radius)
        local t = moabTimeAt(d)
        if t > last_hit then last_hit = t end

        if enemy_side and kind ~= "scenery" and kind ~= "static" and obj:getCoalition() == enemy_side then
            table.insert(enemies, { obj = obj, xp = xp })
        end

        timer.scheduleFunction(function()
            if not moabIsAlive(obj, kind) then return end
            local pos = obj:getPoint()
            if d <= kill_r then
                trigger.action.explosion(pos, Config.moab.kill_power)
                if kind ~= "scenery" then
                    timer.scheduleFunction(function()
                        if moabIsAlive(obj, kind) then obj:destroy() end
                    end, nil, timer.getTime() + 0.5)
                end
            else
                local frac = (d - kill_r) / math.max(Config.moab.light_damage_radius - kill_r, 1)
                local power = Config.moab.damage_power_min + (Config.moab.damage_power_max - Config.moab.damage_power_min) * (1 - frac) ^ 2
                trigger.action.explosion(pos, power)
            end
        end, nil, now + t)
    end

    local volume = { id = world.VolumeType.SPHERE, params = { point = gz, radius = Config.moab.light_damage_radius } }
    world.searchObjects({ Object.Category.UNIT, Object.Category.STATIC, Object.Category.CARGO }, volume, function(obj)
        if obj and obj:isExist() then
            local kind, xp = moabClassify(obj)
            if kind then hit(obj, kind, xp) end
        end
        return true
    end)

    if Config.moab.destroy_scenery then
        local scenery_volume = { id = world.VolumeType.SPHERE, params = { point = gz, radius = Config.moab.kill_radius.scenery } }
        world.searchObjects(Object.Category.SCENERY, scenery_volume, function(obj)
            if obj then hit(obj, "scenery", 0) end
            return true
        end)
    end

    -- After the shockwave has passed: update zone structures and award XP
    timer.scheduleFunction(function()
        for _, zone in ipairs(zones) do
            if zone.zone and zone.zone.point and mist.utils.get2DDist(gz, zone.zone.point) <= Config.moab.light_damage_radius then
                zone:checkCOMMSZone()
                zone:checkSUPPLIES()
            end
        end

        if not player_name then return end
        local kills, xp_total = 0, 0
        for _, e in ipairs(enemies) do
            if not moabIsAlive(e.obj) then
                kills = kills + 1
                xp_total = xp_total + (e.xp or 0)
            end
        end
        MissionLogger:info(string.format("MOAB result for %s: %d enemy kills, %d XP", player_name, kills, xp_total))

        local user = Config.reward_system.enable and ExperienceManager.user_data[player_name] or nil
        if user then
            user.unclaimed_xp = (user.unclaimed_xp or 0) + xp_total
            if user.id then
                trigger.action.outTextForUnit(user.id, string.format("MOAB: %d enemy kills, +%d XP pending - land to claim", kills, xp_total), 15)
            end
        end
    end, nil, now + last_hit + 2.5)
end