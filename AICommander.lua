---@class AICommander
AICommander = {}
do
    -- group_name -> target player name
    ---@type table<string, string>
    AICommander.active_hunts = {}


    AICommander.hunting_side = coalition.side.RED

    ---Count current active hunt flights, pruning any whose group is gone.
    ---@return number
    function AICommander:countActiveHunts()
        local count = 0
        for group_name, _ in pairs(self.active_hunts) do
            local grp = Group.getByName(group_name)
            if grp and grp:isExist() then
                count = count + 1
            else
                self.active_hunts[group_name] = nil
            end
        end
        return count
    end

    ---Is this player already being hunted?
    ---@param player_name string
    ---@return boolean
    function AICommander:isPlayerHunted(player_name)
        for group_name, hunted_name in pairs(self.active_hunts) do
            if hunted_name == player_name then
                local grp = Group.getByName(group_name)
                if grp and grp:isExist() then
                    return true
                else
                    self.active_hunts[group_name] = nil
                end
            end
        end
        return false
    end


    ---@param user UserData
    ---@return Unit|nil
    function AICommander:resolvePlayerUnit(user)
        if not user then return nil end

        local players = coalition.getPlayers(utils.getEnemyCoalition(self.hunting_side))
        for _, p in ipairs(players) do
            if p and p.isExist and p:isExist() and p.getPlayerName and p:getPlayerName() == user.name then
                return p
            end
        end
        return nil
    end

    ---@return table[] list of { user = UserData, unit = Unit, dist = number }
    function AICommander:findHuntTargets()
        local targets = {}

        local home_base = red_airbase
        if self.hunting_side == coalition.side.BLUE then
            home_base = blue_airbase
        end
        if not home_base or not home_base.zone then return targets end

        for _, user in pairs(ExperienceManager.user_data) do
            if user and (user.unclaimed_xp or 0) >= Config.hunt.unclaimed_xp_for_hunt then
                local unit = self:resolvePlayerUnit(user)
                if unit and unit:inAir() and not self:isPlayerHunted(user.name) then
                    local pos = unit:getPoint()
                    local dist = mist.utils.get2DDist(home_base.zone.point, pos)
                    if dist <= Config.hunt.max_hunt_range then
                        table.insert(targets, { user = user, unit = unit, dist = dist })
                    end
                end
            end
        end

        table.sort(targets, function(a, b)
            return (a.user.unclaimed_xp or 0) > (b.user.unclaimed_xp or 0)
        end)
        return targets
    end

    ---@return EnrouteObj|nil, Group|nil
    function AICommander:findRedirectableCAP()
        local cap_enroutes = EnrouteManager:findByTaskType(AITaskTypes.CAP, self.hunting_side)
        for _, enroute in ipairs(cap_enroutes) do
            if not self.active_hunts[enroute.group_name] then
                local grp = Group.getByName(enroute.group_name)
                if grp and grp:isExist() then
                    return enroute, grp
                end
            end
        end
        return nil, nil
    end

    ---@param hunter_group Group
    ---@param target_unit Unit
    ---@param target_name string
    function AICommander:assignHuntTask(hunter_group, target_unit, target_name)
        if not (hunter_group and hunter_group:isExist()) then return false end
        if not (target_unit and target_unit:isExist()) then return false end

        local ctrl = hunter_group:getController()
        local target_group = target_unit:getGroup()
        local target_pos = target_unit:getPoint()

        local tasks = {}

        if target_group and target_group:isExist() then
            table.insert(tasks, {
                id = 'EngageGroup',
                params = {
                    groupId = target_group:getID(),
                    priority = 0,
                }
            })
        end

        table.insert(tasks, {
            id = 'EngageTargets',
            params = {
                targetTypes = { 'Planes', 'Helicopters' },
                maxDist = 100000,
                maxDistEnabled = true,
                priority = 1,
            }
        })

        table.insert(tasks, {
            id = 'Orbit',
            params = {
                pattern = AI.Task.OrbitPattern.CIRCLE,
                point = { x = target_pos.x, y = target_pos.z },
                speed = 250,
                altitude = mist.utils.feetToMeters(20000),
                priority = 2,
            }
        })

        local comboTask = {
            id = 'ComboTask',
            params = { tasks = tasks }
        }

        ctrl:setTask(comboTask)

        -- Aggressive air-to-air posture for the hunt.
        ctrl:setOption(AI.Option.Air.id.PROHIBIT_AG, true)
        ctrl:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE)
        ctrl:setOption(AI.Option.Air.id.JETT_TANKS_IF_EMPTY, true)
        ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)
        ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)
        ctrl:setOption(AI.Option.Air.id.MISSILE_ATTACK, AI.Option.Air.val.MISSILE_ATTACK.HALF_WAY_RMAX_NEZ)

        local aa_weapons = 268402688 -- AnyMissile
        ctrl:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, aa_weapons)
        ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

        self.active_hunts[hunter_group:getName()] = target_name
        MissionLogger:info(string.format("[HUNT] %s tasked to hunt player '%s' (%d unclaimed XP)",
            hunter_group:getName(), target_name,
            (ExperienceManager.user_data[target_name] and ExperienceManager.user_data[target_name].unclaimed_xp) or 0))
        return true
    end

    ---@param target_unit Unit
    ---@param target_name string
    ---@return boolean
    function AICommander:spawnHunterFor(target_unit, target_name)
        if not Config.hunt.spawn_if_no_cap then return false end
        if not EraSystem.isTaskTypeAllowed(AITaskTypes.CAP) then return false end
        if not (target_unit and target_unit:isExist()) then return false end

        local side = self.hunting_side
        local target_pos = target_unit:getPoint()

        local source_airbase = TaskManager:findClosestAirbaseWithAircraftInStock(
            nil, side, AITaskTypes.CAP, 2, AITaskTypes.CAP, target_pos)
        if not source_airbase then
            MissionLogger:info("[HUNT] No airbase with CAP aircraft in stock to spawn a hunter.")
            return false
        end

        local airbase = Airbase.getByName(source_airbase.airbase_name)
        if not airbase then return false end

        if not WarehouseManager:checkIfAIPayloadInStock(airbase, AITaskTypes.CAP) then
            MissionLogger:info("[HUNT] CAP payload not in warehouse at " .. source_airbase.name)
            return false
        end

        local side_assets = side == coalition.side.BLUE and GroupData.COMMON_ASSETS.BLUE or GroupData.COMMON_ASSETS.RED
        if not side_assets then return false end
        local template_name = EraSystem.resolveTaskTemplateName(side_assets.cap)
        if not template_name then return false end

        local new_group = TaskManager:spawnAIFlightFromParking(template_name, airbase)
        if not new_group then
            MissionLogger:info("[HUNT] Failed to spawn hunter CAP flight from " .. source_airbase.name)
            return false
        end

        EnrouteManager:add({
            to_zone = source_airbase, -- loiters near target; home is the source
            side = side,
            from_zone = source_airbase,
            group_name = new_group.name,
            ai_task_type = AITaskTypes.CAP,
        })

        timer.scheduleFunction(function()
            local hunter = Group.getByName(new_group.name)
            local tgt = Unit.getByName(target_unit:getName())
            if not (hunter and hunter:isExist()) then return end
            if not (tgt and tgt:isExist()) then
                -- Target gone (landed/died); leave the flight as a normal CAP.
                MissionLogger:info("[HUNT] Target '" .. target_name .. "' gone before hunter ready; flight reverts to CAP.")
                return
            end
            AICommander:assignHuntTask(hunter, tgt, target_name)
            trigger.action.outTextForCoalition(side,
                "Hunter CAP launched from " .. source_airbase.name, 10)
            trigger.action.outSoundForCoalition(side, "transmission1.ogg")
        end, {}, timer.getTime() + 12)

        MissionLogger:info(string.format("[HUNT] Spawned dedicated hunter from %s for '%s'",
            source_airbase.name, target_name))
        return true
    end

    ---Main evaluator: find experienced enemy players and task RED CAP to hunt.
    function AICommander:huntExperiencedPlayers()
        if not Config.tasking.enable then return end
        if not Config.reward_system.enable then return end
        if not Config.hunt.enable_hunt_experienced_players then return end

        if self:countActiveHunts() >= Config.hunt.max_hunt_flights then
            return
        end

        local targets = self:findHuntTargets()
        if #targets == 0 then return end

        for _, t in ipairs(targets) do
            if self:countActiveHunts() >= Config.hunt.max_hunt_flights then
                break
            end

            -- 1. Try to redirect an existing, alive RED CAP flight.
            local _, hunter_group = self:findRedirectableCAP()
            if hunter_group then
                if self:assignHuntTask(hunter_group, t.unit, t.user.name) then
                    MissionLogger:info("[HUNT] Redirected existing CAP " .. hunter_group:getName() ..
                        " onto '" .. t.user.name .. "'")
                end
            elseif Config.hunt.spawn_if_no_cap then
                -- 2. No CAP available: spawn one outside the dispatcher.
                self:spawnHunterFor(t.unit, t.user.name)
            end
        end
    end

    ---Self-scheduling hunt loop.
    function AICommander.dispatchHunt()
        local interval = Config.hunt.hunt_dispatcher_interval or (5 * 60 + 7)
        timer.scheduleFunction(function()
            if MISSION_ENDED == true then return end
            local ok, err = pcall(function()
                AICommander:huntExperiencedPlayers()
            end)
            if not ok then
                MissionLogger:error("[HUNT] Evaluator error: " .. tostring(err))
            end
            AICommander.dispatchHunt()
        end, nil, timer.getTime() + interval)
    end

    -- AI DISPATCHER
    -- Moved here from TheatreCommander. Routine per-coalition zone-based tasking.

    ---@param side coalition.side
    function AICommander:evaluateAITasks(side)
        if not Config.tasking.enable then return end
        MissionLogger:info("Evaluating "..utils.coalitionToString(side) .." AI tasks..")

        local side_comms_towers = 0
        if side == coalition.side.BLUE then
            side_comms_towers = stats.blue_comms_antennas
        elseif side == coalition.side.RED then
            side_comms_towers = stats.red_comms_antennas
        end

        if side_comms_towers == 0 then
            trigger.action.outTextForCoalition(side,"No coalition COMMS towers active, AI tasking suspended.", 10)
            trigger.action.outSoundForCoalition(side, "radio_beep3.ogg")
            return
        end

        local active_zones = {}  -- Prevents AI from being tasked to where players are tasked
        local enemy_side = utils.getEnemyCoalition(side)
        local home_base
        if side == coalition.side.BLUE then
            home_base = blue_airbase
            if stats.blue_airbases == 0 then
                trigger.action.outTextForCoalition(side,"No coalition airbases active, AI tasking suspended.", 10)
                trigger.action.outSoundForCoalition(side, "radio_beep3.ogg")
                return
            end

            for _,operation in pairs(TheatreCommander.blue_op_manager.active_operations) do
                table.insert(active_zones, operation.target_zone_name)
            end

        elseif side == coalition.side.RED then
            home_base = red_airbase
            if stats.red_airbases == 0 then
                trigger.action.outTextForCoalition(side,"No coalition airbases active, AI tasking suspended.", 10)
                trigger.action.outSoundForCoalition(side, "radio_beep3.ogg")
                return
            end

            for _,operation in pairs(TheatreCommander.red_op_manager.active_operations) do
                table.insert(active_zones, operation.target_zone_name)
            end
        end

        if home_base == nil then return end
        if home_base.side ~= side then return end

        -- Calculate distances once for use in closures below
        local closest_enemy_zone, closest_dist = home_base:getClosestZone(enemy_side,nil,nil,true)

        -- Each function returns TRUE if a task was successfully sent.
        local possible_tasks = {}

        local function addTask(ai_task_type, task_func)
            if EraSystem.isTaskTypeAllowed(ai_task_type) then -- for era compatibility
                table.insert(possible_tasks, task_func)
            end
        end

        -- [TASK: RECON]
        addTask(AITaskTypes.RECON, function()
            local recon_enroute = EnrouteManager:findByTaskType(AITaskTypes.RECON, side)
            if recon_enroute and #recon_enroute >= Config.tasking.max_recon_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_recon then
                return false
            end

            local closest_undiscovered_zone = nil
            local current_closest_dist = 999999
            local discovered_list = (side == coalition.side.BLUE) and stats.blue_discovered_zones or stats.red_discovered_zones

            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and not utils.tableContains(discovered_list, zone.name)
                and not utils.tableContains(active_zones, zone.name) then
                    local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                    if dist < current_closest_dist then
                        current_closest_dist = dist
                        closest_undiscovered_zone = zone
                    end
                end
            end

            if closest_undiscovered_zone then
                if not EnrouteManager:findByToZone(closest_undiscovered_zone, side, {AITaskTypes.RECON}) then
                    return TaskManager:initiateAITask(AITaskTypes.RECON, side, true, closest_undiscovered_zone, nil, false)
                end
            end
            return false
        end)

        -- [TASK: AWACS]
        addTask(AITaskTypes.AWACS, function()
            local awacs_enroute = EnrouteManager:findByTaskType(AITaskTypes.AWACS, side)
            if awacs_enroute and #awacs_enroute >= 1 then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_awacs then
                return false
            end
            if closest_dist and closest_dist > Config.tasking.min_cleareance_dist_for_awacs then
                MissionLogger:info("[AWACS] Attempting for " .. utils.coalitionToString(side))
                return TaskManager:initiateAITask(AITaskTypes.AWACS, side, true, nil, home_base, false)
            end
            return false
        end)

        -- [TASK: CAS]
        addTask(AITaskTypes.CAS, function()
            MissionLogger:info("[CAS] Checking CAS tasks")
            local cas_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAS, side)
            if #cas_enroute >= Config.tasking.max_cas_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cas then
                return false
            end
            local potential_zones = {}
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and not utils.tableContains(active_zones, zone.name) then
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                       (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                    if discovered and not EnrouteManager:findByToZone(zone, side, {AITaskTypes.CAS}) then
                        local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                        if dist < Config.tasking.max_cas_range then
                            table.insert(potential_zones, {distance=dist, zone=zone})
                        end
                    end
                end
            end

            -- Sort zones by distance
            table.sort(potential_zones, function(a,b)
                return a.distance < b.distance
            end)
            if #potential_zones == 0 then
                MissionLogger:info("[CAS]: No valid target zones.")
                return false
                end

            for _,p in ipairs(potential_zones) do
                MissionLogger:info("[CAS]: Attempting to initiate CAS task to " .. p.zone.name)
                return TaskManager:initiateAITask(AITaskTypes.CAS, side, true, p.zone, nil, false)
            end
            return false
        end)

        -- [TASK: SEAD]
        addTask(AITaskTypes.SEAD, function()
            MissionLogger:info("[SEAD] %s checking SEAD tasks.")
            local sead_enroute = EnrouteManager:findByTaskType(AITaskTypes.SEAD, side)
            if sead_enroute and #sead_enroute >= Config.tasking.max_sead_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_sead then
                return false
            end

            local potential_zones = {}
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and zone.zone_type == ZoneTypes.SAMSITE
                and not utils.tableContains(active_zones, zone.name)
                and mist.utils.get2DDist(home_base.zone.point, zone.zone.point) < Config.tasking.max_sead_range then
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                        (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))

                    if discovered then
                        if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.SEAD}) then
                            local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                            table.insert(potential_zones, {distance=dist, zone=zone})
                        end
                    end
                end
            end

              -- Sort zones by distance
            table.sort(potential_zones, function(a,b)
                return a.distance < b.distance
            end)
            if #potential_zones == 0 then
                MissionLogger:info("[SEAD]: No valid target zones.")
                return false
            end

            for _,p in ipairs(potential_zones) do
                MissionLogger:info("[SEAD]: Attempting to initiate SEAD task to " .. p.zone.name)
                return TaskManager:initiateAITask(AITaskTypes.SEAD, side, true, p.zone, nil, false)
            end
            return false
        end)

        -- [TASK: CAP]
        addTask(AITaskTypes.CAP, function()
            local cap_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAP, side)
            if cap_enroute and #cap_enroute >= Config.tasking.max_cap_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cap then
                return false
            end

            local potential_zones = {}
            for _, zone in ipairs(zones) do
                if zone.side == side and zone.zone_type ~= ZoneTypes.AIRBASE then
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                        (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                    local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)

                    if discovered and not EnrouteManager:findByToZone(zone, side, {AITaskTypes.CAP}) then
                        table.insert(potential_zones, {distance=dist, zone=zone})

                    end
                end
            end

            -- Sort zones by distance, reverse order for CAP
            table.sort(potential_zones, function(a,b)
                return a.distance > b.distance
            end)
            if #potential_zones == 0 then return false end

            for _,p in ipairs(potential_zones) do
                MissionLogger:info(string.format("[CAP] %s: Attempting to initiate CAP task to %s",
                        utils.coalitionToString(side), p.zone.name))
                return TaskManager:initiateAITask(AITaskTypes.CAP, side, true, p.zone, nil, false)
            end
            return false
        end)

        -- [TASK: STRIKE]
        addTask(AITaskTypes.STRIKE, function()
            local strike_enroute = EnrouteManager:findByTaskType(AITaskTypes.STRIKE, side)
            MissionLogger:info(string.format("[STRIKE] %s checking STRIKE tasks. Current enroute: %d, max: %d",
                utils.coalitionToString(side), strike_enroute and #strike_enroute or 0, Config.tasking.max_strike_theatre))
            if strike_enroute and #strike_enroute < Config.tasking.max_strike_theatre
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_strike
            then
                local valid_strike_targets = {
                    ZoneTypes.LOGISTICS,
                    ZoneTypes.COMMS,
                    ZoneTypes.AIRBASE
                }
                local potential_zones = {}
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and utils.tableContains(valid_strike_targets, zone.zone_type)
                    and not utils.tableContains(active_zones, zone.name)
                    and mist.utils.get2DDist(home_base.zone.point, zone.zone.point) < Config.tasking.max_strike_range then

                        -- Checks if statics are alive
                        if zone.linked_statics and #zone.linked_statics >= 1 then

                            local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                            (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))

                            if discovered then
                                if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.STRIKE}) then
                                    local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                                    table.insert(potential_zones, {distance=dist, zone=zone})
                                end
                            end
                        end
                    end
                end

                -- Sort zones by distance
                table.sort(potential_zones, function(a,b)
                    return a.distance < b.distance
                end)
                if #potential_zones == 0 then
                    MissionLogger:info(string.format("[STRIKE] %s: No valid target zones.",
                        utils.coalitionToString(side)))
                    return false
                end

                for _,p in ipairs(potential_zones) do
                    MissionLogger:info(string.format("[STRIKE] %s: Attempting to initiate STRIKE task to %s",
                        utils.coalitionToString(side), p.zone.name))
                    return TaskManager:initiateAITask(AITaskTypes.STRIKE, side, true, p.zone, nil, false)
                end
                return false

            else
                if strike_enroute and #strike_enroute >= Config.tasking.max_strike_theatre then
                    MissionLogger:info(string.format("[STRIKE] %s: Max STRIKE tasks reached", utils.coalitionToString(side)))
                elseif side_comms_towers < Config.tasking_requirements.comms_zones_required_for_strike then
                    MissionLogger:info(string.format("[STRIKE] %s: Not enough COMMS towers (%d < %d)",
                        utils.coalitionToString(side), side_comms_towers, Config.tasking_requirements.comms_zones_required_for_strike))
                end
            end
            MissionLogger:info(string.format("[STRIKE] %s: No valid STRIKE targets found", utils.coalitionToString(side)))
            return false
        end)


        utils.shuffleTable(possible_tasks)
        -- Run through the shuffled list. As soon as one task spawns (returns true), stop.
        for _, task_func in ipairs(possible_tasks) do
            if task_func() then
                MissionLogger:info("Tasking succeeded for " .. utils.coalitionToString(side))
                return -- Task spawned
            end
        end
        MissionLogger:info("No tasks spawned for " .. utils.coalitionToString(side))
    end

    ---Self-scheduling dispatch loop for the routine AI dispatcher.
    ---@param side coalition.side
    function AICommander.dispatchAI(side)

        local next_interval = 999999
        if side == coalition.side.BLUE then
            next_interval = Config.tasking.BLUFOR_dispatcher_interval
        else
            next_interval = Config.tasking.REDFOR_dispatcher_interval
        end
        timer.scheduleFunction(function ()
            if MISSION_ENDED == true then return end
            AICommander:evaluateAITasks(side)

            AICommander.dispatchAI(side)
        end, nil, timer.getTime() + next_interval)

    end

    ---Start the AICommander loops. Call once at mission init.
    function AICommander.init()
        -- Routine AI dispatcher (always on when tasking is enabled).
        AICommander.dispatchAI(coalition.side.BLUE)
        AICommander.dispatchAI(coalition.side.RED)

        -- Hunt experienced players (optional feature).
        if Config.hunt and Config.hunt.enable_hunt_experienced_players then
            MissionLogger:info("[AICommander] Hunt experienced players enabled.")
            AICommander.dispatchHunt()
        else
            MissionLogger:info("[AICommander] Hunt experienced players disabled.")
        end
    end
end
