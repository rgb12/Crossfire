---@class AICommander
AICommander = {}
do
    -- group_name -> { target = player name, side = hunting coalition }
    ---@type table<string, {target: string, side: number}>
    AICommander.active_hunts = {}


    ---@param side coalition.side
    ---@return boolean
    function AICommander:isHuntEnabledForSide(side)
        local sides = Config.hunt.sides
        if not sides then return side == coalition.side.RED end
        if side == coalition.side.BLUE then return sides.blue == true end
        return sides.red == true
    end

    ---Count current active hunt flights for a side, pruning any whose group is gone.
    ---@param side coalition.side
    ---@return number
    function AICommander:countActiveHunts(side)
        local count = 0
        for group_name, hunt in pairs(self.active_hunts) do
            local grp = Group.getByName(group_name)
            if grp and grp:isExist() then
                if hunt.side == side then
                    count = count + 1
                end
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
        for group_name, hunt in pairs(self.active_hunts) do
            if hunt.target == player_name then
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
    ---@param side coalition.side hunting side
    ---@return Unit|nil
    function AICommander:resolvePlayerUnit(user, side)
        if not user then return nil end

        local players = coalition.getPlayers(utils.getEnemyCoalition(side))
        for _, p in ipairs(players) do
            if p and p.isExist and p:isExist() and p.getPlayerName and p:getPlayerName() == user.name then
                return p
            end
        end
        return nil
    end

    ---@param side coalition.side hunting side
    ---@return table[] list of { user = UserData, unit = Unit, dist = number }
    function AICommander:findHuntTargets(side)
        local targets = {}

        local home_base = red_airbase
        if side == coalition.side.BLUE then
            home_base = blue_airbase
        end
        if not home_base or not home_base.zone then return targets end

        for _, user in pairs(ExperienceManager.user_data) do
            if user and (user.unclaimed_xp or 0) >= Config.hunt.unclaimed_xp_for_hunt then
                local unit = self:resolvePlayerUnit(user, side)
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

    ---@param side coalition.side hunting side
    ---@return EnrouteObj|nil, Group|nil
    function AICommander:findRedirectableCAP(side)
        local cap_enroutes = EnrouteManager:findByTaskType(AITaskTypes.CAP, side)
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
    ---@param side coalition.side hunting side
    function AICommander:assignHuntTask(hunter_group, target_unit, target_name, side)
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

        -- Fallback to orbit near frontline
        local hunter_home = side == coalition.side.BLUE and blue_airbase or red_airbase
        local enemy_side_for_hunt = utils.getEnemyCoalition(side)
        if not hunter_home then return false end
        local closest_enemy_zone, _ = hunter_home:getClosestZone(enemy_side_for_hunt,nil,nil,false)
        local closest_friendly_zone_to_frontline = closest_enemy_zone and closest_enemy_zone:getClosestZone(side,nil,nil,false)

        if closest_friendly_zone_to_frontline then
            target_pos = closest_friendly_zone_to_frontline.zone.point
        end
        table.insert(tasks, {
            id = 'Orbit',
            params = {
                pattern = AI.Task.OrbitPattern.CIRCLE,
                point = { x = target_pos.x, y = target_pos.z },
                speed = 250,
                altitude = mist.utils.feetToMeters(math.random(10000, 20000)),
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

        self.active_hunts[hunter_group:getName()] = { target = target_name, side = side }
        MissionLogger:info(string.format("[HUNT] %s %s tasked to hunt player '%s' (%d unclaimed XP)",
            utils.coalitionToString(side), hunter_group:getName(), target_name,
            (ExperienceManager.user_data[target_name] and ExperienceManager.user_data[target_name].unclaimed_xp) or 0))
        return true
    end

    ---@param target_unit Unit
    ---@param target_name string
    ---@param side coalition.side hunting side
    ---@return boolean
    function AICommander:spawnHunterFor(target_unit, target_name, side)
        if not Config.hunt.spawn_if_no_cap then return false end
        if not EraSystem.isTaskTypeAllowed(AITaskTypes.CAP) then return false end
        if not (target_unit and target_unit:isExist()) then return false end

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
            to_zone = source_airbase,
            side = side,
            from_zone = source_airbase,
            group_name = new_group.name,
            ai_task_type = AITaskTypes.CAP,
        })
        self.active_hunts[new_group.name] = { target = target_name, side = side }

        timer.scheduleFunction(function()
            local hunter = Group.getByName(new_group.name)
            local tgt = Unit.getByName(target_unit:getName())
            if not (hunter and hunter:isExist()) then
                self.active_hunts[new_group.name] = nil
                return
            end
            if not (tgt and tgt:isExist()) then
                -- Target gone (landed/died); leave the flight as a normal CAP.
                self.active_hunts[new_group.name] = nil
                MissionLogger:info("[HUNT] Target '" .. target_name .. "' gone before hunter ready; flight reverts to CAP.")
                return
            end
            AICommander:assignHuntTask(hunter, tgt, target_name, side)
            trigger.action.outTextForCoalition(side,
                "Hunter CAP launched from " .. source_airbase.name, 10)
            trigger.action.outSoundForCoalition(side, "transmission1.ogg")
        end, {}, timer.getTime() + 12)

        MissionLogger:info(string.format("[HUNT] Spawned dedicated %s hunter from %s for '%s'",
            utils.coalitionToString(side), source_airbase.name, target_name))
        return true
    end

    ---Main evaluator: find experienced enemy players and task this side's CAP to hunt.
    ---@param side coalition.side hunting side
    function AICommander:huntExperiencedPlayers(side)
        if not Config.tasking.enable then return end
        if not Config.reward_system.enable then return end
        if not Config.hunt.enable_hunt_experienced_players then return end
        if not self:isHuntEnabledForSide(side) then return end

        if self:countActiveHunts(side) >= Config.hunt.max_hunt_flights then
            return
        end

        local targets = self:findHuntTargets(side)
        if #targets == 0 then return end

        for _, t in ipairs(targets) do
            if self:countActiveHunts(side) >= Config.hunt.max_hunt_flights then
                break
            end

            -- 1. Try to redirect an existing, alive CAP flight of this side.
            local _, hunter_group = self:findRedirectableCAP(side)
            if hunter_group then
                if self:assignHuntTask(hunter_group, t.unit, t.user.name, side) then
                    MissionLogger:info("[HUNT] Redirected existing CAP " .. hunter_group:getName() .." onto '" .. t.user.name .. "'")
                end
            elseif Config.hunt.spawn_if_no_cap then
                -- 2. No CAP available: spawn one outside the dispatcher.
                self:spawnHunterFor(t.unit, t.user.name, side)
            end
        end
    end

    ---Self-scheduling hunt loop for one side.
    ---@param side coalition.side hunting side
    ---@param delay number|nil (seconds) delay before the first run, defaults to the interval
    function AICommander.dispatchHunt(side, delay)
        local interval = Config.hunt.hunt_dispatcher_interval or (5 * 60 + 7)
        timer.scheduleFunction(function()
            if MISSION_ENDED == true then return end
            AICommander:huntExperiencedPlayers(side)
            AICommander.dispatchHunt(side)
        end, nil, timer.getTime() + (delay or interval))
    end

    ---@class PlannedFlight
    ---@field id number
    ---@field side coalition.side
    ---@field ai_task_type AITaskTypes
    ---@field to_zone ZoneHandler|nil
    ---@field from_zone ZoneHandler|nil
    ---@field planned_at number mission time (timer.getTime) the flight was planned
    ---@field launch_time number mission time (timer.getTime) the flight launches
    ---@field launch_abs_time number in-game time of day (timer.getAbsTime) the flight launches, for briefings
    ---@field group_name string|nil set once the flight has launched
    ---@field on_cancelled fun(flight: PlannedFlight, reason: string)|nil called when the final check or the spawn fails
    ---@field on_launched fun(flight: PlannedFlight)|nil called once the flight has spawned

    ---@type table<coalition.side, PlannedFlight[]>
    AICommander.planned_flights = {
        [coalition.side.BLUE] = {},
        [coalition.side.RED] = {},
    }
    local next_planned_flight_id = 0

    ---All queued (not yet launched) flights for a side, optionally filtered by task type.
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes|nil
    ---@return PlannedFlight[]
    function AICommander:getPlannedFlights(side, ai_task_type)
        local results = {}
        for _, flight in ipairs(self.planned_flights[side] or {}) do
            if not ai_task_type or flight.ai_task_type == ai_task_type then
                table.insert(results, flight)
            end
        end
        return results
    end

    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return number
    function AICommander:countPlannedFlights(side, ai_task_type)
        return #self:getPlannedFlights(side, ai_task_type)
    end

    ---Is a flight of this task type already queued toward this zone?
    ---@param zone ZoneHandler
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return boolean
    function AICommander:isZonePlanned(zone, side, ai_task_type)
        for _, flight in ipairs(self.planned_flights[side] or {}) do
            if flight.ai_task_type == ai_task_type and flight.to_zone == zone then
                return true
            end
        end
        return false
    end

    ---Queue a flight to launch after the planning lead time.
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@param to_zone ZoneHandler|nil
    ---@param from_zone ZoneHandler|nil
    ---@return PlannedFlight
    function AICommander:planFlight(side, ai_task_type, to_zone, from_zone)
        local lead = Config.tasking.flight_planning_lead_time or (10 * 60 + 3)
        local now = timer.getTime()
        next_planned_flight_id = next_planned_flight_id + 1

        ---@type PlannedFlight
        local flight = {
            id = next_planned_flight_id,
            side = side,
            ai_task_type = ai_task_type,
            to_zone = to_zone,
            from_zone = from_zone,
            planned_at = now,
            launch_time = now + lead,
            launch_abs_time = timer.getAbsTime() + lead,
        }
        table.insert(self.planned_flights[side], flight)

        timer.scheduleFunction(function()
            if MISSION_ENDED == true then return end
            AICommander:dispatchDueFlights(side)
        end, nil, flight.launch_time)

        MissionLogger:info(string.format("[DISPATCH] %s planned %s #%d to %s, launch in %ds",
            utils.coalitionToString(side), ai_task_type, flight.id,
            (to_zone and to_zone.name) or (from_zone and from_zone.name) or "?", lead))
        return flight
    end

    ---@param flight PlannedFlight
    function AICommander:removePlannedFlight(flight)
        local queue = self.planned_flights[flight.side]
        if not queue then return end
        for i = #queue, 1, -1 do
            if queue[i] == flight then
                table.remove(queue, i)
                return
            end
        end
    end

    ---Remove a queued flight and tell whoever is attached to it why.
    ---@param flight PlannedFlight
    ---@param reason string
    function AICommander:cancelPlannedFlight(flight, reason)
        self:removePlannedFlight(flight)
        MissionLogger:info(string.format("[DISPATCH] %s %s #%d cancelled: %s",
            utils.coalitionToString(flight.side), flight.ai_task_type, flight.id, reason))
        if flight.on_cancelled then
            flight.on_cancelled(flight, reason)
        end
    end

    ---Flights whose launch time has been reached, earliest first.
    ---This is the only thing the dispatcher reads to decide what to launch.
    ---@param side coalition.side
    ---@return PlannedFlight[]
    function AICommander:dispatchableFlights(side)
        local now = timer.getTime()
        local due = {}
        for _, flight in ipairs(self.planned_flights[side] or {}) do
            if flight.launch_time <= now then
                table.insert(due, flight)
            end
        end
        table.sort(due, function(a, b) return a.launch_time < b.launch_time end)
        return due
    end

    ---Final check before launch: tasking limits and warehouse stock.
    ---Call it after the flight has left the queue, so it does not count itself.
    ---@param flight PlannedFlight
    ---@return boolean ok, string|nil reason shown to users when not ok
    function AICommander:finalFlightCheck(flight)
        local side = flight.side
        local task = flight.ai_task_type

        if not Config.tasking.enable then
            return false, "AI tasking is disabled"
        end
        if not EraSystem.isTaskTypeAllowed(task) then
            return false, task .. " is not available in this era"
        end

        -- Tasking limits
        local limit = Config.tasking.theatre_limits[task]
        local enroute = EnrouteManager:findByTaskType(task, side)
        if limit and #enroute >= limit then
            return false, string.format("%s theatre limit reached (%d)", task, limit)
        end

        local to_zone = flight.to_zone
        if to_zone then
            if EnrouteManager:findByToZone(to_zone, side, {task}) then
                return false, task .. " already tasked to " .. to_zone.name
            end
            -- CAP covers friendly zones; every other zone task targets the enemy.
            local expected_side = (task == AITaskTypes.CAP) and side or utils.getEnemyCoalition(side)
            if to_zone.side ~= expected_side then
                return false, to_zone.name .. " changed sides"
            end
        end

        -- Warehouse stock (same lookups initiateAITask uses)
        if to_zone then
            if not TaskManager:findClosestAirbaseWithAircraftInStock(to_zone, side, task, 2, task) then
                return false, "no airbase with aircraft in stock, operable runway and free tasking slots"
            end
        elseif flight.from_zone then
            local from_zone = flight.from_zone --[[@as ZoneHandler]]
            if from_zone.side ~= side then
                return false, from_zone.name .. " is no longer friendly"
            end
            if not TaskManager:isAirbaseRunwayOperational(from_zone) then
                return false, "runway at " .. from_zone.name .. " is inoperable"
            end
            if not WarehouseManager:checkAircraftInStock(from_zone.airbase_name, task) then
                return false, "no aircraft in stock at " .. from_zone.name
            end
        end

        return true, nil
    end

    ---Find the group a flight just spawned as (newest matching enroute).
    ---@param flight PlannedFlight
    ---@return string|nil
    local function findLaunchedGroupName(flight)
        local target = flight.to_zone or flight.from_zone
        for i = #EnrouteManager.enroutes, 1, -1 do
            local enroute = EnrouteManager.enroutes[i]
            if enroute.side == flight.side and enroute.ai_task_type == flight.ai_task_type
            and enroute.to_zone == target then
                return enroute.group_name
            end
        end
        return nil
    end

    ---Dispatcher: launch every due flight that passes the final check.
    ---Runs from one-shot timers set at each flight's launch time.
    ---@param side coalition.side
    function AICommander:dispatchDueFlights(side)
        for _, flight in ipairs(self:dispatchableFlights(side)) do
            self:removePlannedFlight(flight)

            local ok, reason = self:finalFlightCheck(flight)
            if ok then
                ok = TaskManager:initiateAITask(flight.ai_task_type, side, true, flight.to_zone, flight.from_zone, false)
                if not ok then
                    reason = "flight failed to spawn (payload not in warehouse or no free parking)"
                end
            end

            if ok then
                flight.group_name = findLaunchedGroupName(flight)
                MissionLogger:info(string.format("[DISPATCH] %s launched %s #%d (%s)",
                    utils.coalitionToString(side), flight.ai_task_type, flight.id, tostring(flight.group_name)))
                if flight.on_launched then
                    flight.on_launched(flight)
                end
            else
                self:cancelPlannedFlight(flight, reason or "unknown reason")
            end
        end
    end

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
        local closest_enemy_zone, closest_dist = home_base:getClosestZone(enemy_side,nil,nil,true)   -- Source airbase eligibility (runway, aircraft stock, per-airbase limits) does not depend
        -- on the target zone, so check once instead of failing the same lookup for every zone.
        local function hasSourceAirbase(ai_task_type)
            if TaskManager:findClosestAirbaseWithAircraftInStock(nil, side, ai_task_type, 2, ai_task_type, home_base.zone.point) then
                return true
            end
            MissionLogger:info(string.format("[%s] %s: No airbase with required aircraft in stock and runway operable, skipping.",
                ai_task_type, utils.coalitionToString(side)))
            return false
        end

        -- Each function returns TRUE if a task was successfully sent.
        local possible_tasks = {}

        local function addTask(ai_task_type, task_func)
            if EraSystem.isTaskTypeAllowed(ai_task_type) then -- for era compatibility
                table.insert(possible_tasks, task_func)
            end
        end

        -- Launched + queued flights of a task type, checked against theatre limits.
        local function committedCount(ai_task_type)
            return #EnrouteManager:findByTaskType(ai_task_type, side) + AICommander:countPlannedFlights(side, ai_task_type)
        end

        -- A flight of this task type is already launched or queued toward the zone.
        local function isZoneTasked(zone, ai_task_type)
            return EnrouteManager:findByToZone(zone, side, {ai_task_type}) ~= nil
                or AICommander:isZonePlanned(zone, side, ai_task_type)
        end

        -- Queue the flight; the dispatcher launches it after the lead time.
        local function plan(ai_task_type, to_zone, from_zone)
            AICommander:planFlight(side, ai_task_type, to_zone, from_zone)
            return true
        end

        -- [TASK: RECON]
        addTask(AITaskTypes.RECON, function()
            if committedCount(AITaskTypes.RECON) >= Config.tasking.theatre_limits[AITaskTypes.RECON] then
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
                if not isZoneTasked(closest_undiscovered_zone, AITaskTypes.RECON) then
                    return plan(AITaskTypes.RECON, closest_undiscovered_zone, nil)
                end
            end
            return false
        end)

        -- [TASK: AWACS]
        addTask(AITaskTypes.AWACS, function()
            if committedCount(AITaskTypes.AWACS) >= 1 then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_awacs then
                return false
            end
            if closest_dist and closest_dist > Config.tasking.min_cleareance_dist_for_awacs then
                MissionLogger:info("[AWACS] Planning for " .. utils.coalitionToString(side))
                return plan(AITaskTypes.AWACS, nil, home_base)
            end
            return false
        end)

        -- [TASK: CAS]
        addTask(AITaskTypes.CAS, function()
            MissionLogger:info("[CAS] Checking CAS tasks")
            if committedCount(AITaskTypes.CAS) >= Config.tasking.theatre_limits[AITaskTypes.CAS] then
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
                    if discovered and not isZoneTasked(zone, AITaskTypes.CAS) then
                        if Frontline.distanceToFrontline(zone.zone.point) < Config.tasking.max_distance_to_frontline_for_offensive then
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
                MissionLogger:info("[CAS]: No valid target zones.")
                return false
                end
            if not hasSourceAirbase(AITaskTypes.CAS) then return false end

            MissionLogger:info("[CAS]: Planning CAS task to " .. potential_zones[1].zone.name)
            return plan(AITaskTypes.CAS, potential_zones[1].zone, nil)
        end)

        -- [TASK: SEAD]
        addTask(AITaskTypes.SEAD, function()
            MissionLogger:info("[SEAD] %s checking SEAD tasks.")
            if committedCount(AITaskTypes.SEAD) >= Config.tasking.theatre_limits[AITaskTypes.SEAD] then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_sead then
                return false
            end

            local potential_zones = {}
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and zone.zone_type == ZoneTypes.SAMSITE
                and not utils.tableContains(active_zones, zone.name)
                and Frontline.distanceToFrontline(zone.zone.point) < Config.tasking.max_distance_to_frontline_for_offensive then
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                        (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))

                    if discovered then
                        if not isZoneTasked(zone, AITaskTypes.SEAD) then
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
            if not hasSourceAirbase(AITaskTypes.SEAD) then return false end

            MissionLogger:info("[SEAD]: Planning SEAD task to " .. potential_zones[1].zone.name)
            return plan(AITaskTypes.SEAD, potential_zones[1].zone, nil)
        end)

        -- [TASK: CAP]
        addTask(AITaskTypes.CAP, function()
            if committedCount(AITaskTypes.CAP) >= Config.tasking.theatre_limits[AITaskTypes.CAP] then
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
                    local front_dist = Frontline.distanceToFrontline(zone.zone.point)

                    if discovered
                    and front_dist < Config.tasking.max_distance_to_frontline_for_offensive
                    and not isZoneTasked(zone, AITaskTypes.CAP) then
                        table.insert(potential_zones, {distance=front_dist, zone=zone})

                    end
                end
            end

            -- Sort friendly zones by proximity to the frontline
            table.sort(potential_zones, function(a,b)
                return a.distance < b.distance
            end)
            if #potential_zones == 0 then return false end
            if not hasSourceAirbase(AITaskTypes.CAP) then return false end

            MissionLogger:info(string.format("[CAP] %s: Planning CAP task to %s",
                    utils.coalitionToString(side), potential_zones[1].zone.name))
            return plan(AITaskTypes.CAP, potential_zones[1].zone, nil)
        end)

        -- [TASK: STRIKE]
        addTask(AITaskTypes.STRIKE, function()
            if not Config.tasking.enable_auto_strike then return false end
            local strike_committed = committedCount(AITaskTypes.STRIKE)
            MissionLogger:info(string.format("[STRIKE] %s checking STRIKE tasks. Current enroute+planned: %d, max: %d",
                utils.coalitionToString(side), strike_committed, Config.tasking.theatre_limits[AITaskTypes.STRIKE]))
            if strike_committed < Config.tasking.theatre_limits[AITaskTypes.STRIKE]
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_strike
            then
                if not hasSourceAirbase(AITaskTypes.STRIKE) then return false end

                local valid_strike_targets = {
                    ZoneTypes.LOGISTICS,
                    ZoneTypes.COMMS,
                    ZoneTypes.AIRBASE
                }
                local potential_zones = {}
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and utils.tableContains(valid_strike_targets, zone.zone_type)
                    and not utils.tableContains(active_zones, zone.name)
                    and Frontline.distanceToFrontline(zone.zone.point) < Config.tasking.max_distance_to_frontline_for_offensive then

                        -- Checks non-neutral structures (neutral depots/comms towers are left to players)
                        if #TaskManager.getStrikeTargets(zone, side) >= 1 then

                            local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                            (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))

                            if discovered then
                                if not isZoneTasked(zone, AITaskTypes.STRIKE) then
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

                MissionLogger:info(string.format("[STRIKE] %s: Planning STRIKE task to %s",
                    utils.coalitionToString(side), potential_zones[1].zone.name))
                return plan(AITaskTypes.STRIKE, potential_zones[1].zone, nil)

            else
                if strike_committed >= Config.tasking.theatre_limits[AITaskTypes.STRIKE] then
                    MissionLogger:info(string.format("[STRIKE] %s: Max STRIKE tasks reached", utils.coalitionToString(side)))
                elseif side_comms_towers < Config.tasking_requirements.comms_zones_required_for_strike then
                    MissionLogger:info(string.format("[STRIKE] %s: Not enough COMMS towers (%d < %d)",
                        utils.coalitionToString(side), side_comms_towers, Config.tasking_requirements.comms_zones_required_for_strike))
                end
                return false
            end
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
    ---Number of real players on a coalition.
    ---@param side coalition.side
    ---@return number
    function AICommander.countPlayers(side)
        local players = coalition.getPlayers(side)
        return (players and #players) or 0
    end

    ---Compute this side's dispatcher interval, scaled by how many real players
    ---are on the ENEMY coalition (more enemy players => faster tasking).
    ---@param side coalition.side
    ---@return number seconds
    function AICommander.getDispatchInterval(side)
        local base
        if side == coalition.side.BLUE then
            base = Config.tasking.BLUFOR_dispatcher_interval
        else
            base = Config.tasking.REDFOR_dispatcher_interval
        end

        local scale_cfg = Config.tasking.scale_by_player_count
        if not (scale_cfg and scale_cfg.enable) then
            return base
        end

        local enemy_players = AICommander.countPlayers(utils.getEnemyCoalition(side))
        if enemy_players <= 0 then
            return base
        end

        local per_player = scale_cfg.speedup_per_enemy_player or 0
        local min_mult = scale_cfg.min_interval_multiplier or 0.4
        local multiplier = 1 / (1 + per_player * enemy_players)
        if multiplier < min_mult then multiplier = min_mult end

        local scaled = math.floor(base * multiplier)
        MissionLogger:info(string.format("[DISPATCH] %s interval %ds -> %ds (%d enemy players)",
            utils.coalitionToString(side), base, scaled, enemy_players))
        return scaled
    end

    ---@param side coalition.side
    function AICommander.dispatchAI(side)

        local next_interval = AICommander.getDispatchInterval(side)
        timer.scheduleFunction(function ()
            if MISSION_ENDED == true then return end
            AICommander:evaluateAITasks(side)

            AICommander.dispatchAI(side)
        end, nil, timer.getTime() + next_interval)

    end

    -- MAJOR OFFENSIVE
    -- Every few hours each enabled coalition launches a big coordinated strike
    -- package against the enemy.
    ---@param side coalition.side
    ---@return boolean
    function AICommander:isOffensiveEnabled(side)
        if side == coalition.side.BLUE then return Config.major_offensive.enable_blue == true end
        if side == coalition.side.RED then return Config.major_offensive.enable_red == true end
        return false
    end

    ---Gather the launching side's home base and basic gating info.
    ---@param side coalition.side
    ---@return ZoneHandler|nil home_base, number comms_towers, number airbases
    function AICommander:offensiveContext(side)
        if side == coalition.side.BLUE then
            return blue_airbase, stats.blue_comms_antennas, stats.blue_airbases
        else
            return red_airbase, stats.red_comms_antennas, stats.red_airbases
        end
    end

    ---Discovered enemy zones within range of the frontline, closest to home_base first.
    ---@param side coalition.side
    ---@param home_base ZoneHandler
    ---@param zone_types ZoneTypes[]|nil restrict to these zone types
    ---@return ZoneHandler[]
    function AICommander:offensiveTargets(side, home_base, zone_types)
        local enemy_side = utils.getEnemyCoalition(side)
        local discovered = (side == coalition.side.BLUE) and stats.blue_discovered_zones or stats.red_discovered_zones
        local results = {}

        for _, zone in ipairs(zones) do
            if zone.side == enemy_side
            and (not zone_types or utils.tableContains(zone_types, zone.zone_type))
            and utils.tableContains(discovered, zone.name) then
                if Frontline.distanceToFrontline(zone.zone.point) <= Config.tasking.max_distance_to_frontline_for_offensive then
                    local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                    table.insert(results, { zone = zone, dist = dist })
                end
            end
        end

        table.sort(results, function(a, b) return a.dist < b.dist end)

        local zones_only = {}
        for _, r in ipairs(results) do table.insert(zones_only, r.zone) end
        return zones_only
    end

    ---@param side coalition.side
    ---@return table plan
    function AICommander:newOffensivePlan(side)
        local airbases = {}
        for _, zone in ipairs(zones) do
            if zone.zone_type == ZoneTypes.AIRBASE and zone.side == side and zone.airbase_name
            and TaskManager:isAirbaseRunwayOperational(zone) then
                table.insert(airbases, zone)
            end
        end
        return { side = side, airbases = airbases, planned = {}, planned_acft = {} }
    end

    ---@param plan table
    ---@param airbase_zone ZoneHandler
    ---@return number
    function AICommander:plannedTaskCount(plan, airbase_zone)
        local existing = EnrouteManager:findByFromZone(airbase_zone, plan.side,
            { AITaskTypes.CAS, AITaskTypes.CAP, AITaskTypes.SEAD, AITaskTypes.STRIKE,
              AITaskTypes.RECON, AITaskTypes.AWACS, AITaskTypes.TANKER })
        local existing_n = existing and #existing or 0
        local planned_n = (plan.planned[airbase_zone.name] and plan.planned[airbase_zone.name].total) or 0
        return existing_n + planned_n
    end

    ---Per-type committed count (existing enroutes + plan) from an airbase.
    ---@param plan table
    ---@param airbase_zone ZoneHandler
    ---@param task_type AITaskTypes
    ---@return number
    function AICommander:plannedTypeCount(plan, airbase_zone, task_type)
        local existing = EnrouteManager:findByFromZone(airbase_zone, plan.side, { task_type })
        local existing_n = existing and #existing or 0
        local planned_n = (plan.planned[airbase_zone.name] and plan.planned[airbase_zone.name][task_type]) or 0
        return existing_n + planned_n
    end

    ---Per-type max-per-airbase cap from config (mirrors checkIfMaxTasksReached).
    ---@param task_type AITaskTypes
    ---@return number
    function AICommander:perAirbaseTypeCap(task_type)
        return Config.tasking.airbase_limits[task_type] or math.huge
    end

    ---@param plan table
    ---@param airbase_zone ZoneHandler
    ---@param task_type AITaskTypes
    ---@return number available, string|nil acft_type
    function AICommander:plannedAircraftAvailable(plan, airbase_zone, task_type)
        local airbase = Airbase.getByName(airbase_zone.airbase_name)
        if not airbase or airbase:getCoalition() ~= plan.side then return 0, nil end
        local warehouse = airbase:getWarehouse()
        if not warehouse then return 0, nil end

        local acft_type = WarehouseManager:getAircraftTypeForTask(plan.side, task_type)
        if not acft_type then return 0, nil end

        local count = warehouse:getItemCount(acft_type) or 0
        local reserve = WarehouseManager:getAircraftReserveThreshold()
        local committed = (plan.planned_acft[airbase_zone.name] and plan.planned_acft[airbase_zone.name][acft_type]) or 0
        return math.max(count - reserve - committed, 0), acft_type
    end

    ---@param plan table
    ---@param task_type AITaskTypes
    ---@param sort_point vec3|vec2
    ---@return ZoneHandler|nil
    function AICommander:pickSourceAirbase(plan, task_type, sort_point)
        local candidates = {}
        for _, ab in ipairs(plan.airbases) do
            local avail, acft_type = self:plannedAircraftAvailable(plan, ab, task_type)
            local under_total = self:plannedTaskCount(plan, ab) < (Config.tasking.max_tasks_per_airbase or math.huge)
            local under_type = self:plannedTypeCount(plan, ab, task_type) < self:perAirbaseTypeCap(task_type)
            if avail >= 1 and under_total and under_type then
                table.insert(candidates, {
                    zone = ab,
                    acft_type = acft_type,
                    dist = sort_point and mist.utils.get2DDist(sort_point, ab.zone.point) or 0
                })
            end
        end
        table.sort(candidates, function(a, b) return a.dist < b.dist end)

        local best = candidates[1]
        if not best then return nil end

        -- Commit to the plan.
        local name = best.zone.name
        plan.planned[name] = plan.planned[name] or { total = 0 }
        plan.planned[name].total = plan.planned[name].total + 1
        plan.planned[name][task_type] = (plan.planned[name][task_type] or 0) + 1
        plan.planned_acft[name] = plan.planned_acft[name] or {}
        plan.planned_acft[name][best.acft_type] = (plan.planned_acft[name][best.acft_type] or 0) + 1

        return best.zone
    end

    ---Launch a major offensive for one side, staggering each flight.
    ---@param side coalition.side
    ---@param force boolean|nil bypass the per-side enable toggle (e.g. Jupiter command)
    function AICommander:launchOffensive(side, force)
        if not Config.tasking.enable then return end
        if not force and not self:isOffensiveEnabled(side) then return end

        local cfg = Config.major_offensive
        local home_base, comms_towers, airbases = self:offensiveContext(side)

        if not home_base or home_base.side ~= side then return end
        if cfg.require_comms_and_airbase and (comms_towers == 0 or airbases == 0) then
            MissionLogger:info("[OFFENSIVE] "..utils.coalitionToString(side)..
                " offensive skipped (no comms/airbase).")
            return
        end

        local pkg = cfg.package or {}

        -- Targets per task type. CAS/STRIKE go after ground; SEAD after SAM
        -- sites; CAP escorts toward the closest enemy zones.
        local strike_targets = self:offensiveTargets(side, home_base,
            { ZoneTypes.LOGISTICS, ZoneTypes.COMMS, ZoneTypes.AIRBASE })
        local cas_targets = self:offensiveTargets(side, home_base, nil)
        local sead_targets = self:offensiveTargets(side, home_base, { ZoneTypes.SAMSITE })
        local cap_targets = self:offensiveTargets(side, home_base, nil)

        -- Build an ordered launch list of {task_type, to_zone, from_zone}.
        local launches = {}

        local distribute = cfg.distribute_across_airbases ~= false
        local plan = distribute and self:newOffensivePlan(side) or nil

        local function queue(count, task_type, target_list, use_home_as_from)
            count = count or 0
            for i = 1, count do
                if use_home_as_from then
                    -- AWACS launches from an airbase, no target zone.
                    local from = home_base
                    if plan then
                        from = self:pickSourceAirbase(plan, task_type, home_base.zone.point) or home_base
                    end
                    table.insert(launches, { type = task_type, to_zone = nil, from_zone = from })
                elseif #target_list > 0 then
                    -- Spread across available targets, wrapping round-robin.
                    local tgt = target_list[((i - 1) % #target_list) + 1]
                    local from = nil
                    if plan then
                        from = self:pickSourceAirbase(plan, task_type, tgt.zone.point)
                        if not from then
                            -- No airbase can take this flight; skip it instead of
                            -- piling onto the closest one.
                            MissionLogger:info(string.format(
                                "[OFFENSIVE] %s: no airbase with stock/capacity for %s, skipping a flight.",
                                utils.coalitionToString(side), tostring(task_type)))
                        else
                            table.insert(launches, { type = task_type, to_zone = tgt, from_zone = from })
                        end
                    else
                        table.insert(launches, { type = task_type, to_zone = tgt, from_zone = nil })
                    end
                end
            end
        end

        -- SEAD first (clear the way), then strike, CAS, CAP escort, AWACS support.
        queue(pkg.sead,   AITaskTypes.SEAD,   sead_targets,   false)
        queue(pkg.cas,    AITaskTypes.CAS,    cas_targets,    false)
        queue(pkg.cap,    AITaskTypes.CAP,    cap_targets,    false)
        queue(pkg.awacs,  AITaskTypes.AWACS,  nil,            true)

        if #launches == 0 then
            MissionLogger:info("[OFFENSIVE] "..utils.coalitionToString(side)..
                ": no valid targets/package, offensive aborted.")
            return
        end

        MissionLogger:info(string.format("[OFFENSIVE] %s launching major offensive: %d flights queued.",utils.coalitionToString(side), #launches))
        local enemy_side = utils.getEnemyCoalition(side)

        trigger.action.outTextForCoalition(enemy_side,"Large enemy offensive inbound!", 15)
        trigger.action.outSoundForCoalition(enemy_side,"alert1.ogg")
        timer.scheduleFunction(function ()
            trigger.action.outSoundForCoalition(enemy_side,"alert1.ogg")
        end,{},timer.getTime()+1)

        -- Stagger the launches so they don't all spawn at once.
        local stagger = cfg.launch_stagger or 11
        for idx, launch in ipairs(launches) do
            timer.scheduleFunction(function()
                if MISSION_ENDED == true then return end
                MissionLogger:info(string.format("[OFFENSIVE] %s launching %s from %s to %s (%d/%d)",
                    utils.coalitionToString(side), tostring(launch.type),
                    launch.from_zone and launch.from_zone.name or "home base",
                    launch.to_zone and launch.to_zone.name or "unknown target",
                    idx, #launches))
                TaskManager:initiateAITask(launch.type, side, true, launch.to_zone, launch.from_zone, false)
            end, {}, timer.getTime() + (idx - 1) * stagger)
        end
    end

    ---@param side coalition.side
    function AICommander.dispatchOffensive(side)
        local cfg = Config.major_offensive
        local min_i = cfg.min_interval or (2*60*60)
        local max_i = cfg.max_interval or (3*60*60)
        if max_i < min_i then max_i = min_i end
        local delay = math.random(min_i, max_i)

        timer.scheduleFunction(function()
            if MISSION_ENDED == true then return end
            AICommander:launchOffensive(side)
            AICommander.dispatchOffensive(side)
        end, nil, timer.getTime() + delay)
    end

    ---Start the AICommander loops. Call once at mission init.
    function AICommander.init()
        -- Routine AI dispatcher (always on when tasking is enabled).
        AICommander.dispatchAI(coalition.side.BLUE)
        AICommander.dispatchAI(coalition.side.RED)

        -- Hunt experienced players (optional feature).
        if Config.hunt and Config.hunt.enable_hunt_experienced_players then
            local interval = Config.hunt.hunt_dispatcher_interval or (5 * 60 + 7)
            if AICommander:isHuntEnabledForSide(coalition.side.RED) then
                MissionLogger:info("[AICommander] Hunt experienced players enabled for RED.")
                AICommander.dispatchHunt(coalition.side.RED, interval)
            end
            if AICommander:isHuntEnabledForSide(coalition.side.BLUE) then
                MissionLogger:info("[AICommander] Hunt experienced players enabled for BLUE.")
                -- Offset from RED so both evaluators don't run on the same tick.
                AICommander.dispatchHunt(coalition.side.BLUE, interval + 31)
            end
        else
            MissionLogger:info("[AICommander] Hunt experienced players disabled.")
        end

        -- Major offensives (optional, per-side).
        if Config.major_offensive then
            if AICommander:isOffensiveEnabled(coalition.side.BLUE) then
                MissionLogger:info("[AICommander] Major offensive enabled for BLUE.")
                AICommander.dispatchOffensive(coalition.side.BLUE)
            end
            if AICommander:isOffensiveEnabled(coalition.side.RED) then
                MissionLogger:info("[AICommander] Major offensive enabled for RED.")
                AICommander.dispatchOffensive(coalition.side.RED)
            end
        end
    end
end
