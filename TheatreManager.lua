local ticks = 15
local ticks1m = 0
local ticks5m = 0
TheatreCommander = {}
do

    TheatreCommander.blue_op_manager = nil
    TheatreCommander.red_op_manager = nil
    TheatreCommander.zones_to_check_for_capture = {}

    ---@param to_zone ZoneHandler
    ---@param side_sending_capture coalition.side
    ---@param from_zone ZoneHandler|nil
    function TheatreCommander.sendCapture(to_zone, side_sending_capture, from_zone)
        MissionLogger:info(utils.coalitionToString(side_sending_capture).." attempting capture group for zone: " .. to_zone.name)

        ------------[check if game has been won]------------
        local zones_captured = nil
        if side_sending_capture == coalition.side.BLUE then zones_captured = stats.blue_zones
        else zones_captured = stats.red_zones end

        if zones_captured == #zones then
            MISSION_ENDED = true
            world.removeEventHandler(ev)
            return trigger.action.outText(utils.coalitionToString(side_sending_capture) .." coalition completed this scenario.", 50)
        end

        ------------[checks if capture group already enroute for side]------------
        if EnrouteManager:findByToZone(to_zone,side_sending_capture,{AITaskTypes.CAPTURE_CONVOY, AITaskTypes.CAPTURE_HELO}) then
            trigger.action.outText(utils.coalitionToString(side_sending_capture) ..
                "Capture group already enroute to: " .. to_zone.name, 10)
            return
        end




        ------------[friendly group instant spawn]------------
            
        ---@type ZoneHandler[]
        local zones_to_check
        if from_zone then
            zones_to_check = { from_zone }
        else
            zones_to_check = ZoneHandler.sortZonesByDistance(to_zone.zone.point)
        end

        for _, zone in ipairs(zones_to_check) do
            if zone.side == side_sending_capture and zone.zone_type == ZoneTypes.LOGISTICS then
                local zones_distance = mist.utils.get2DDist(to_zone.zone.point,zone.zone.point)

                if EnrouteManager:findByFromZone(zone,side_sending_capture,{AITaskTypes.CAPTURE_HELO}) then return end

                -- checks if closest zone can deploy a heli
                if zone.capture_heli_avail and zone.capture_heli_avail>0 and zones_distance <= Config.capture_helicopter_max_range then
                    -- send heli
                    TaskManager:initiateAITask(AITaskTypes.CAPTURE_HELO,side_sending_capture,true,to_zone,zone,false)
                    break
                end
            end

        end
        
    end

    ---@param zone_name string
    ---@param ignore_airborne_units boolean|nil
    ---@param ignore_statics boolean|nil
    ---@param ignore_coaliation coalition.side|nil
    function TheatreCommander.fetchUnitsInZone(zone_name, ignore_airborne_units, ignore_statics, ignore_coaliation)
        ------ [Fetches all units, and filters them based on the zone name and coalition] ------
        local all_units_in_capture_zone = nil
        if ignore_coaliation and ignore_coaliation == coalition.side.RED then
            all_units_in_capture_zone = mist.getUnitsInZones(mist.makeUnitTable({ '[blue]' }), { zone_name })
        elseif ignore_coaliation and ignore_coaliation == coalition.side.BLUE then
            all_units_in_capture_zone = mist.getUnitsInZones(mist.makeUnitTable({ '[red]' }), { zone_name })
        else
            all_units_in_capture_zone = mist.getUnitsInZones(mist.makeUnitTable({ '[all]' }), { zone_name })
        end
        if not all_units_in_capture_zone then return end

        ------ [Filter out statics, friendlies, and airborne units] ------
        for i = #all_units_in_capture_zone, 1, -1 do -- reverse loop so table.remove is safe
            local unit = all_units_in_capture_zone[i]
            -- local unit_desc = unit
            -- ignore all statics


            if unit:getCategory() == Object.Category.STATIC and ignore_statics then
                table.remove(all_units_in_capture_zone, i)

                -- ignore same-side units
            elseif unit:getCoalition() == ignore_coaliation then
                table.remove(all_units_in_capture_zone, i)

                -- ignore airborne units
            elseif unit:inAir() and ignore_airborne_units then
                table.remove(all_units_in_capture_zone, i)
            end
        end
        return all_units_in_capture_zone
    end
    -- checks if a capture group has arrived
    --- func desc
    ---@param enroute_group EnrouteObj
    function TheatreCommander.checkIfCaptureGroupArrived(enroute_group)
        if not EnrouteManager:findByGroup(enroute_group.group_name) then return false end

        local capture_group = Group.getByName(enroute_group.group_name)
        if not capture_group then return false end

        local capture_group_units = capture_group:getUnits()
        -- check if at least one convoy/heli unit is inside and no enemies remain
        local in_zone_count = utils.getUnitsInZoneObj(enroute_group.to_zone)--mist.getUnitsInZones({ convoy_unit:getName() }, { enroute_group.to_zone.zone.name })

        
        ------------[capture zone checks]------------
        -- group is in zone and capture succeeds
        if enroute_group.ai_task_type == AITaskTypes.CAPTURE_HELO then
            MissionLogger:info("Heli captured zone: " .. enroute_group.to_zone.zone.name)
            -- remove heli from enroutes
            EnrouteManager:remove(enroute_group.group_name)
        elseif enroute_group.ai_task_type == AITaskTypes.CAPTURE_CONVOY and in_zone_count == #capture_group_units then
            -- remove convoy from enroutes
            MissionLogger:info("Convoy captured zone: " .. enroute_group.to_zone.zone.name)
            EnrouteManager:remove(enroute_group.group_name)

        else
            -- MissionLogger:info("Capture group not in zone or not all units are in zone")
            return false -- capture not successful
        end

        ------------[cancelling all other enemy helicopters inbound for this zone]------------
        ------------[cancelling all other enemy convoys inbound for this zone]------------
        for _,possible_enroute in ipairs(EnrouteManager.enroutes) do
            if possible_enroute.ai_task_type == AITaskTypes.CAPTURE_HELO
            and possible_enroute.to_zone.name == enroute_group.to_zone.name then
                UnitHandler.abortHeliCapture(
                    possible_enroute.group_name,
                    possible_enroute.from_zone)
                MissionLogger:info("Aborted helicopter capture: " ..possible_enroute.group_name .." from zone: " .. possible_enroute.to_zone.zone.name)
            elseif possible_enroute.ai_task_type == AITaskTypes.CAPTURE_CONVOY
            and possible_enroute.to_zone.name == enroute_group.to_zone.name then
                local aborting_convoy_group = Group.getByName(possible_enroute.group_name)
                if aborting_convoy_group then
                    trigger.action.setGroupAIOff(aborting_convoy_group)
                    timer.scheduleFunction(function ()
                        aborting_convoy_group:destroy()
                        EnrouteManager:remove(possible_enroute.group_name)
                        MissionLogger:info("Destroyed convoy: " .. possible_enroute.group_name)
                    end, {}, timer.getTime() + math.random(15, 25))
                end
            end
        end

        -- flip zone ownership
        if enroute_group.side == coalition.side.RED then
            enroute_group.to_zone:capture(coalition.side.RED)
        elseif enroute_group.side == coalition.side.BLUE then
            enroute_group.to_zone:capture(coalition.side.BLUE)
        end
        return true
    end

    ---@param side coalition.side
    function TheatreCommander:evaluateAITasks(side)
        -- MissionLogger:info("AI Commander checking tasks for: " .. utils.coalitionToString(side))
        
        -- 1. PRE-CHECKS (Global resources)
        local side_comms_towers = 0
        if side == coalition.side.BLUE then
            side_comms_towers = stats.blue_comms_antennas
        elseif side == coalition.side.RED then
            side_comms_towers = stats.red_comms_antennas
        end

        if side_comms_towers == 0 then
            trigger.action.outTextForCoalition(side,
                "No coalition COMMS towers on the battlefield, AI tasking suspended.", 10)
            return
        end

        local enemy_side = utils.getEnemyCoalition(side)
        local home_base
        if side == coalition.side.BLUE then
            home_base = blue_airbase
            if stats.blue_airbases == 0 then
                trigger.action.outTextForCoalition(side,
                    "No coalition airbases on the battlefield, AI tasking suspended.", 10)
                return
            end
        elseif side == coalition.side.RED then
            home_base = red_airbase
            if stats.red_airbases == 0 then
                trigger.action.outTextForCoalition(side,
                    "No coalition airbases on the battlefield, AI tasking suspended.", 10)
                return
            end
        end
        
        if home_base == nil then return end
        if home_base.side ~= side then return end

        -- Calculate distances once for use in closures below
        local closest_enemy_zone, closest_dist = home_base:getClosestZone(enemy_side,nil,nil,true)
        local closest_friendly_zone, _ = home_base:getClosestZone(side,nil,nil,true)

        -- 2. DEFINE TASK LOGIC
        -- We define a list of functions. Each function returns TRUE if a task was successfully sent.
        local possible_tasks = {}

        -- [TASK: RECON]
        table.insert(possible_tasks, function()
            local recon_enroute = EnrouteManager:findByTaskType(AITaskTypes.RECON, side)
            if recon_enroute and #recon_enroute < 1
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_recon
            then
                local closest_undiscovered_zone = nil
                local current_closest_dist = 999999
                local discovered_list = (side == coalition.side.BLUE) and stats.blue_discovered_zones or stats.red_discovered_zones
                
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and not utils.tableContains(discovered_list, zone.name) then
                        local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                        if dist < current_closest_dist then
                            current_closest_dist = dist
                            closest_undiscovered_zone = zone
                        end
                    end
                end

                if closest_undiscovered_zone then
                    if not EnrouteManager:findByToZone(closest_undiscovered_zone, side, {AITaskTypes.RECON}) then
                        MissionLogger:info("AI Commander: Tasking RECON for " .. utils.coalitionToString(side) .. " to " .. closest_undiscovered_zone.name)
                        return TaskManager:initiateAITask(AITaskTypes.RECON, side, true, closest_undiscovered_zone, nil, false)
                    end
                end
            end
            return false
        end)

        -- [TASK: AWACS]
        table.insert(possible_tasks, function()
            local awacs_enroute = EnrouteManager:findByTaskType(AITaskTypes.AWACS, side)
            if #awacs_enroute == 0 and closest_dist < 75000
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_awacs then
                MissionLogger:info("AI Commander: No AWACS found for " .. utils.coalitionToString(side) .. ". Tasking one.")
                return TaskManager:initiateAITask(AITaskTypes.AWACS, side, true, nil, home_base, false)
            end
            return false
        end)

        -- [TASK: CAS]
        table.insert(possible_tasks, function()
            local cas_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAS, side)
            if #cas_enroute < 2 then 
                if closest_enemy_zone and closest_dist < Config.tasking.max_cas_range
                and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_cas then
                    if not EnrouteManager:findByToZone(closest_enemy_zone, side, {AITaskTypes.CAS}) then
                        MissionLogger:info("AI Commander: Tasking CAS for " .. utils.coalitionToString(side) .. " to " .. closest_enemy_zone.name)
                        return TaskManager:initiateAITask(AITaskTypes.CAS, side, true, closest_enemy_zone, nil, false)
                    end
                end
            end
            return false
        end)

        -- [TASK: SEAD]
        table.insert(possible_tasks, function()
            local sead_enroute = EnrouteManager:findByTaskType(AITaskTypes.SEAD, side)
            if sead_enroute and #sead_enroute < 3
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_sead
            then 
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and zone.zone_type == ZoneTypes.SAMSITE then
                        local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                           (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                        
                        if discovered then
                            if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.SEAD}) then
                                MissionLogger:info("AI Commander: Tasking SEAD for " .. utils.coalitionToString(side) .. " to " .. zone.name)
                                return TaskManager:initiateAITask(AITaskTypes.SEAD, side, true, zone, nil, false)
                            end
                        end
                    end
                end
            end
            return false
        end)

        -- [TASK: INTERCEPT]
        table.insert(possible_tasks, function()
            local intercept_enroute = EnrouteManager:findByTaskType(AITaskTypes.INTERCEPT, side)
            if intercept_enroute and #intercept_enroute < 3
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_intercept
            then 
                if closest_friendly_zone then
                    if not EnrouteManager:findByToZone(closest_friendly_zone, side, {AITaskTypes.INTERCEPT}) then
                        MissionLogger:info("AI Commander: Tasking INTERCEPT for " .. utils.coalitionToString(side) .. " to patrol " .. closest_friendly_zone.name)
                        return TaskManager:initiateAITask(AITaskTypes.INTERCEPT, side, true, closest_friendly_zone, nil, false)
                    end
                end
            end
            return false
        end)

        -- [TASK: STRIKE]
        table.insert(possible_tasks, function()
            local strike_enroute = EnrouteManager:findByTaskType(AITaskTypes.STRIKE, side)
            if strike_enroute and #strike_enroute < 2
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_strike
            then 
                local valid_strike_targets = {
                    ZoneTypes.EWSITE,
                    ZoneTypes.LOGISTICS,
                    ZoneTypes.COMMS,
                }
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and utils.tableContains(valid_strike_targets, zone.zone_type) then
                        local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                           (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                        
                        if discovered then
                            if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.STRIKE}) then
                                MissionLogger:info("AI Commander: Tasking STRIKE for " .. utils.coalitionToString(side) .. " against " .. zone.name)
                                return TaskManager:initiateAITask(AITaskTypes.STRIKE, side, true, zone, nil, false)
                            end
                        end
                    end
                end
            end
            return false
        end)

        -- 3. SHUFFLE THE TASKS
        -- Fisher-Yates shuffle to randomize the order of checks
        for i = #possible_tasks, 2, -1 do
            local j = math.random(i)
            possible_tasks[i], possible_tasks[j] = possible_tasks[j], possible_tasks[i]
        end

        -- 4. EXECUTE
        -- Run through the shuffled list. As soon as ONE task spawns (returns true), we exit the whole function.
        for _, task_func in ipairs(possible_tasks) do
            if task_func() then
                return -- Task spawned
            end
        end
    end

    ---@param zone ZoneHandler
    function TheatreCommander.sendPotentialCapture(zone)
        if zone.side ~= coalition.side.NEUTRAL then return end

        local now = timer.getTime()
        if not zone.last_capture_attempt then zone.last_capture_attempt = timer.getTime() end

        -- cooldown before sending capture group
        if now - zone.last_capture_attempt < Config.cooldown_before_capture_attempt then return end

        if EnrouteManager:findByToZone(zone, nil, {AITaskTypes.CAPTURE_CONVOY, AITaskTypes.CAPTURE_HELO}) then return end
        
        -- both sides have a chance to send capture group
        if math.random(0,100) >= Config.retry_capture_chance then return end
        local side_sending_capture = math.random(1,2)

        -- MissionLogger:info(utils.coalitionToString(side_sending_capture).." attempting capture for zone: " .. zone.name)
        zone.last_capture_attempt = now
        TheatreCommander.sendCapture(zone, side_sending_capture)
    end

    -- This function is executed every 15 seconds
    function TheatreCommander:tick()
        if MISSION_ENDED == true then return end
        

        local t1m_update = function()
            MissionLogger:info("1 minute")


    

            for _, zone in ipairs(zones) do

                    TheatreCommander.sendPotentialCapture(zone)

                    zone:checkLogisticsZone()
                    zone:checkCOMMSZone()
                    zone:checkAirbaseZone()

                    zone:addAIAssets(10) -- Supply chance every minute

                    if zone.side ~=coalition.side.NEUTRAL and zone:checkIfEmpty() then
                        
                        TheatreCommander.sendCapture(zone, utils.getEnemyCoalition(zone.side))
                        zone:capture(coalition.side.NEUTRAL)
                    end

                    -- [ this spawns an attack convoy from strongpoints periodically ] --
                    if math.random(1,100) <= 15 and zone.zone_type == ZoneTypes.STRONGPOINT
                    and zone.attack_convoy and zone.attack_convoy > 0
                    and #EnrouteManager:findByTaskType(AITaskTypes.ATTACK_CONVOY) < #zones / 4
                    then
                        TaskManager:initiateAITask(AITaskTypes.ATTACK_CONVOY,zone.side,true,nil,zone,false)
                    end

                    CommandHandler.refreshJtacCmds(zone.side)
            end
        end

        local t5m_update = function()
            MissionLogger:info("5 mins")



            timer.scheduleFunction(function () --caching and cleaning when other functions free up
                for i = #EnrouteManager.enroutes, 1, -1 do
                    local enroute = EnrouteManager.enroutes[i]
                    if enroute then
                        local grp = Group.getByName(enroute.group_name)
                        if not grp then
                            EnrouteManager:remove(enroute.group_name)
                        end
                    end
                end
                
            end,{}, timer.getTime() + 8)
        end

    --This function is executed every 15s
    local function tsec_update()
    
        timer.scheduleFunction(tsec_update, {}, timer.getTime() + 15)
        -- update every minute
        if ticks % 60 == 0 then
            ticks1m = ticks1m + 1
            t1m_update()
    
            if ticks1m % 5 == 0 then
                ticks5m = ticks5m + 1
                t5m_update()
            end
        end
    
        ticks = ticks + 15
    
        if TheatreCommander.blue_op_manager then
            TheatreCommander.blue_op_manager:tick()
        end
        if TheatreCommander.red_op_manager then
            TheatreCommander.red_op_manager:tick()
        end
        
        for i = #EnrouteManager.enroutes, 1, -1 do
            local enroute = EnrouteManager.enroutes[i]
            if enroute then -- Check if enroute object is valid

                if enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)
                    
                    if not convoy_group or not convoy_group:isExist() then
                        trigger.action.outTextForCoalition(enroute.side, "Convoy sent to attack " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager.enroutes[i] = nil -- equivalent to EnrouteManager:remove but without the logging

                    elseif not UnitHandler.checkConvoyMoving(convoy_group) then
                        -- SCENARIO 2: CONVOY STUCK (or at destination)
                        if enroute.to_zone:isPointInsideZone(mist.getLeadPos(convoy_group)) then
                            -- It's "stuck" but at the destination. This is the redirect logic.
                            MissionLogger:info("Attack convoy not moving (at destination), redirecting " .. enroute.group_name)
                            
                            local enemy_units
                            if enroute.side == coalition.side.BLUE then enemy_units = utils.getUnitsInZoneObj(enroute.to_zone, coalition.side.RED)
                            elseif enroute.side == coalition.side.RED then enemy_units = utils.getUnitsInZoneObj(enroute.to_zone, coalition.side.BLUE) end
    
                            if enemy_units and #enemy_units > 0 then
                                -- Enemies still exist, redirect to the next one
                                local arrival_point = enemy_units[1]:getPoint()
                                if not enroute.redirects_count then enroute.redirects_count = 0 else enroute.redirects_count = enroute.redirects_count + 1 end
                                TaskManager:ConvoyToPoint(convoy_group,arrival_point)
                            else
                                -- SCENARIO 3: CONVOY FINISHED (no enemies left)
                                trigger.action.outTextForCoalition(enroute.side, "Convoy sent to attack " .. enroute.to_zone.zone.name .. " has completed its mission", 10)
                                EnrouteManager.enroutes[i] = nil
                                timer.scheduleFunction(function ()
                                    if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                                end, {}, timer.getTime() + math.random(5, 10))
                            end
                        else
                            -- It's stuck *en route* (not in the zone)
                            if not enroute.stuck_since then
                                enroute.stuck_since = timer.getTime()
                                MissionLogger:info("Attack convoy " .. enroute.group_name .. " detected as stuck en route, starting timer.")
                            elseif (timer.getTime() - enroute.stuck_since) > Config.stuck_convoy_timeout then
                                -- It's been stuck for over 2 minutes, remove it
                                trigger.action.outTextForCoalition(enroute.side, "Attack convoy to " .. enroute.to_zone.zone.name .. " got stuck en route and was removed.", 10)
                                convoy_group:destroy()
                                EnrouteManager.enroutes[i] = nil
                            end
                        end
                    else
                        -- SCENARIO 4: CONVOY ALIVE AND MOVING
                        -- It's moving, so clear any stuck timer
                        enroute.stuck_since = nil
                        
                        -- Check for redirect loop
                        if enroute.redirects_count and enroute.redirects_count > 3 then
                            -- SCENARIO 5: CONVOY FINISHED (too many redirects)
                            MissionLogger:info("Attack convoy exceeded max redirects count: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                        end
                    end
                elseif enroute.ai_task_type == AITaskTypes.RECON then

                    local recon_gr = Group.getByName(enroute.group_name)
                    if recon_gr and recon_gr:isExist() then
                        local pos = mist.getLeadPos(recon_gr)
                        if mist.utils.get2DDist(pos, enroute.to_zone.zone.point) <= Config.tasking.range_for_recon_to_discover_zone then
                            -- Zone is discovered
                            local first_time_discovered = false
                            if enroute.side == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones, enroute.to_zone.name) then
                                table.insert(stats.blue_discovered_zones, enroute.to_zone.name)
                                first_time_discovered = true
                            elseif enroute.side == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones, enroute.to_zone.name) then
                                table.insert(stats.red_discovered_zones, enroute.to_zone.name)
                                first_time_discovered = true
                            end

                            if first_time_discovered then
                                enroute.to_zone:drawF10()
                                CommandHandler.refreshJtacCmds(enroute.side)
                                trigger.action.outTextForCoalition(enroute.side,"Recon group " .. enroute.group_name .. " has discovered " .. enroute.to_zone.name.."\nCheck F10 map", 10)
                                MissionLogger:info("Recon group " .. enroute.group_name .. " has discovered " .. enroute.to_zone.name.."\nCheck F10 map")
                            end
                        end

                    else
                        EnrouteManager.enroutes[i] = nil
                    end

                end
            end
        end
    end
    
    timer.scheduleFunction(tsec_update, {}, timer.getTime() + 15)
    end

    ---@param side coalition.side
    ---@param repeat_tasking boolean|nil
    function TheatreCommander.sendWarehouseResupply(side,repeat_tasking)
        -- this sends a cargo aircraft to the home airbase every BASE_RESUPPLY_TIME

        local cargo_sent_table -- This will be the table returned by mist
        local new_group_name   -- This will hold the string name
        local home_airbase     -- This will be the ZoneHandler object for the base

        if side == coalition.side.BLUE and blue_airbase.acft_resupply_point then
            if stats.blue_airbases == 0 then return end

            cargo_sent_table = mist.teleportToPoint({
                groupName = GroupData.COMMON_ASSETS.BLUE.resupply_aircraft,
                point = blue_airbase.acft_resupply_point,
                action = "clone",
                radius = 3000
            })
            
            if not cargo_sent_table or not cargo_sent_table.name then
                return MissionLogger:error("Could not send BLUE resupply cargo, spawn failed.")
            end
            
            new_group_name = cargo_sent_table.name
            home_airbase = blue_airbase
            
            if repeat_tasking then
                timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, side, timer.getTime() + Config.std_resupply_time)
            end
        
        elseif side == coalition.side.RED and red_airbase.acft_resupply_point then
            if stats.red_airbases == 0 then return end

            cargo_sent_table = mist.teleportToPoint({
                groupName = GroupData.COMMON_ASSETS.RED.resupply_aircraft,
                point = red_airbase.acft_resupply_point,
                action = "clone",
                radius = 1500
            })

            if not cargo_sent_table or not cargo_sent_table.name then 
                return MissionLogger:error("Could not send RED resupply cargo, spawn failed.")
            end

            new_group_name = cargo_sent_table.name
            home_airbase = red_airbase

            if repeat_tasking then
                timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, side, timer.getTime() + stats.red_resupply_time)
            end
        else
            -- No cargo was spawned this cycle, just return
            return
        end

        if home_airbase == nil then
            return MissionLogger:error("Resupply task: Home airbase not found")
        end
        -- Add the new group to the EnrouteManager
        EnrouteManager:add({
            group_name = new_group_name,
            to_zone = home_airbase,   -- The destination airbase
            from_zone = home_airbase, -- The "origin" (can be the same for this)
            side = side,
            ai_task_type = AITaskTypes.RESUPPLY_CARGO
        })

        timer.scheduleFunction(function ()
            local cargo_group = Group.getByName(new_group_name)
            if not cargo_group or not cargo_group:isExist() then
                MissionLogger:error("Resupply task: Group " .. new_group_name .. " not found after 12s.")
                EnrouteManager:remove(new_group_name) -- Clean up enroute task
                return 
            end
            
            local cargo_ctr = cargo_group:getController()
            local landPos = home_airbase.zone.point -- Get coords from the zone object

            if not landPos then
                MissionLogger:error("Resupply task: Could not get landing coordinates.")
                return
            end

            -- Build the explicit RTB mission
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true, -- Tell the AI it's already in the air
                        points = {
                            {
                                type = AI.Task.WaypointType.LAND,
                                x = landPos.x,
                                y = landPos.z,
                                action = AI.Task.TurnMethod.FIN_POINT,
                                alt_type = AI.Task.AltitudeType.BARO,
                                alt=6096

                            }
                        }
                    }
                }
            }

            -- Assign the mission
            cargo_ctr:setTask(missionTask)
            trigger.action.outTextForCoalition(side, "Resupply inbound", 10)
        end, {}, timer.getTime() + 12) -- Wait 12 seconds for spawn to be stable
    end


    -- AI DISPATCHER
    function TheatreCommander.dispatchAI()
            
    timer.scheduleFunction(function ()
        TheatreCommander:evaluateAITasks(coalition.side.BLUE)
        TheatreCommander:evaluateAITasks(coalition.side.RED)
        
        TheatreCommander.dispatchAI()
    end, nil, timer.getTime()+Config.tasking.dispatcher_interval)
    end


    -- Ensures a continuous chain of supplies from Home Base outwards
    function TheatreCommander.assignLogisticsChain(zone_pool, home_base, max_logistics)
        -- Safety defaults if config is missing
        local chain_gap = Scenario.logistics_setup.chain_gap or 25000
        
        local current_node = home_base
        local placed_count = 0
        
        -- Count existing fixed logistics first
        for _, z in ipairs(zone_pool) do
            if z.zone_type == ZoneTypes.LOGISTICS then placed_count = placed_count + 1 end
        end

        MissionLogger:info("Logistics Chain: Checking connectivity for " .. utils.coalitionToString(home_base.side))

        while placed_count < max_logistics do
            
            -- 1. Look ahead: Are there ANY zones in the "Gap" (e.g. 25km ring from current node)?
            local candidates = {}
            local existing_link_found = nil

            for _, zone in ipairs(zone_pool) do
                local dist = mist.utils.get2DDist(current_node.zone.point, zone.zone.point)
                
                -- Check if it's a valid next hop
                if dist > 5000 and dist <= chain_gap then
                    
                    -- If we find a hard-coded LOGISTICS zone already in the gap, use it immediately
                    if zone.zone_type == ZoneTypes.LOGISTICS then
                        existing_link_found = zone
                        -- We want the furthest one ideally, but finding any fixed one is good priority
                    elseif zone.zone_type == nil then
                        -- It's a candidate for assignment
                        table.insert(candidates, zone)
                    end
                end
            end

            -- 2. Decide next node
            if existing_link_found then
                -- We found a pre-defined logistics zone, jump to it
                current_node = existing_link_found
                MissionLogger:info("  -> Linked existing Logistics: " .. current_node.name)
            
            elseif #candidates > 0 then
                -- No existing link, we must create one. 
                -- Sort by distance (Furthest from home base preferred to maximize range)
                table.sort(candidates, function(a, b)
                    local dist_a = mist.utils.get2DDist(home_base.zone.point, a.zone.point)
                    local dist_b = mist.utils.get2DDist(home_base.zone.point, b.zone.point)
                    return dist_a > dist_b -- Descending order
                end)

                local best_zone = candidates[1]
                
                -- Assign Type
                best_zone.zone_type = ZoneTypes.LOGISTICS
                best_zone.next_level_up_avail = timer.getTime()
                best_zone.capture_heli_avail = 4
                best_zone.capture_convoy_avail = 0
                
                current_node = best_zone
                placed_count = placed_count + 1
                MissionLogger:info("  -> Created new Logistics Link: " .. current_node.name)
            else
                -- Dead end (no zones in range)
                break
            end
        end
    end

    ---@return ZoneHandler, ZoneHandler
    function TheatreCommander.establishTheatre()
        MissionLogger:info("TheatreCommander: Generating Theatre Layout...")

        -- 1. IDENTIFY HOME BASES & PREPARE POOL
        local all_other_zones = {}

        blue_airbase.side = coalition.side.BLUE
        blue_airbase.level = 4
        red_airbase.side = coalition.side.RED
        red_airbase.level = 4

        for _, zone in ipairs(zones) do
            if zone.name ~= Scenario.blue_airbase.name
            and zone.name ~= Scenario.red_airbase.name then
                -- Reset flags for a fresh generation
                if Scenario.coalition_setup.auto_coalition_designation then
                    zone.side = coalition.side.NEUTRAL
                end
                table.insert(all_other_zones, zone)
            end
        end

        if not blue_airbase or not red_airbase then return MissionLogger:error("Failed to initialize home airbases") end

        -- 2. APPLY DIFFICULTY (Zone Count) & REBUILD GLOBAL ZONES TABLE
        local diff_setting = Scenario.difficulty
        local diff_ratios = Config.theatre.zone_count_difficulty
        local active_ratio = diff_ratios[diff_setting] or 0.75

        utils.shuffleTable(all_other_zones)
        
        local active_count = math.ceil(#all_other_zones * active_ratio)
        
        -- Overwrite zones table with only active zones
        zones = {}
        table.insert(zones, blue_airbase)
        table.insert(zones, red_airbase)

        for i = 1, active_count do
            table.insert(zones, all_other_zones[i])
        end

        MissionLogger:info("Theatre Gen: Difficulty " .. diff_setting .. ". Total Zones Active: " .. #zones .. " (Includes 2 Bases). Removed " .. (#all_other_zones - active_count) .. " unused zones.")

        -- 3. ASSIGN COALITIONS (Frontline Logic)
        local blue_pool = {}
        local red_pool = {}
        if Scenario.coalition_setup.auto_coalition_designation then

            local frontline_dist = Scenario.coalition_setup.initial_dist_blue_to_frontline or 50000
            local variance = Scenario.coalition_setup.dist_variance or 0
            local actual_radius = frontline_dist + math.random(-variance, variance)

            for _, zone in ipairs(zones) do
                -- Skip home bases for pool assignment (they are already handled)
                if zone.name ~= red_airbase.name and zone.name ~= blue_airbase.name then
                    if not zone.side or zone.side == coalition.side.NEUTRAL then
                        local dist_to_blue = mist.utils.get2DDist(blue_airbase.zone.point, zone.zone.point)
                        
                        if dist_to_blue <= actual_radius then
                            zone.side = coalition.side.BLUE
                            table.insert(blue_pool, zone)
                        else
                            zone.side = coalition.side.RED
                            table.insert(red_pool, zone)
                        end
                    end
                end
            end
        else
            for _,zone in ipairs(zones) do
                if not zone.side then
                    MissionLogger:error("Zone " .. zone.name .. " has no side assigned and auto coalition designation is disabled.")
                    trigger.action.outText("ERROR: Zone " .. zone.name .. " has no side assigned and auto coalition designation is disabled.", 30)
                    break
                end
            end

        end

        -- 4. ASSIGN TYPES (Logistics & Randoms)
        local function assignTypesToPool(pool, home)
            if #pool == 0 then return end
            
            local weights = (Config.theatre and Config.theatre.zone_type_weights) or {
                [ZoneTypes.STRONGPOINT] = 60,
                [ZoneTypes.LOGISTICS] = 15,
                [ZoneTypes.SAMSITE] = 15,
                [ZoneTypes.COMMS] = 5,
                [ZoneTypes.EWSITE] = 5
            }
            local total_w = 0
            for _, w in pairs(weights) do total_w = total_w + w end
            
            local budget_logistics = math.ceil((weights[ZoneTypes.LOGISTICS]/total_w) * #pool)
            local budget_sam       = math.ceil((weights[ZoneTypes.SAMSITE]/total_w) * #pool)
            local budget_comms     = math.ceil((weights[ZoneTypes.COMMS]/total_w) * #pool)
            local budget_ew        = math.ceil((weights[ZoneTypes.EWSITE]/total_w) * #pool)

            -- A. Run Logistics Chain
            TheatreCommander.assignLogisticsChain(pool, home, budget_logistics)

            -- B. Assign Random Types
            local unassigned = {}
            for _, z in ipairs(pool) do
                if z.zone_type == nil then
                    table.insert(unassigned, z)
                end
            end
            
            utils.shuffleTable(unassigned)

            for i, zone in ipairs(unassigned) do
                if budget_sam > 0 then
                    zone.zone_type = ZoneTypes.SAMSITE
                    local r = math.random(1, 100)
                    if r < 30 then zone.sam_classification = SAM_TYPES.SHORT_RANGE
                    elseif r < 70 then zone.sam_classification = SAM_TYPES.MEDIUM_RANGE
                    else zone.sam_classification = SAM_TYPES.LONG_RANGE end
                    budget_sam = budget_sam - 1

                elseif budget_comms > 0 then
                    zone.zone_type = ZoneTypes.COMMS
                    budget_comms = budget_comms - 1

                elseif budget_ew > 0 then
                    zone.zone_type = ZoneTypes.EWSITE
                    budget_ew = budget_ew - 1
                
                else
                    zone.zone_type = ZoneTypes.STRONGPOINT
                    zone.attack_convoy = math.random(0,1)
                end
            end
        end

        MissionLogger:info("Theatre Gen: Processing Blue Pool...")
        assignTypesToPool(blue_pool, blue_airbase)
        MissionLogger:info("Theatre Gen: Processing Red Pool...")
        assignTypesToPool(red_pool, red_airbase)


        -- 5. FINAL SPAWN & DISCOVERY
        table.insert(stats.blue_discovered_zones, red_airbase.name)
        table.insert(stats.blue_discovered_zones, blue_airbase.name)
        table.insert(stats.red_discovered_zones, red_airbase.name)
        table.insert(stats.red_discovered_zones, blue_airbase.name)

        stats.blue_total_comms_zones = stats.blue_comms_zones
        stats.red_total_comms_zones = stats.red_comms_zones

        for _, zone in ipairs(zones) do
            
            -- Handle Airbase ownership
            if zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                local airbase = Airbase.getByName(zone.airbase_name)
                if airbase and zone.side ~= coalition.side.NEUTRAL then
                    airbase:autoCapture(false)
                    airbase:setCoalition(zone.side)
                end
            end

            -- Randomize level
            if not zone.level then
                local _, dist = zone:getClosestZone(utils.getEnemyCoalition(zone.side), nil, nil, false)
                if dist and dist < Config.upgrade_tier_range then
                    zone.level = math.random(2, 4)
                else
                    zone.level = 1
                end
            end

            -- Discovery
            if zone.side == coalition.side.BLUE then
                if not utils.tableContains(stats.blue_discovered_zones, zone.name) then
                    table.insert(stats.blue_discovered_zones, zone.name)
                end
            elseif zone.side == coalition.side.RED then
                if not utils.tableContains(stats.red_discovered_zones, zone.name) then
                    table.insert(stats.red_discovered_zones, zone.name)
                end
            end

            -- Spawn
            UnitHandler.initZoneUnits(zone)
            UnitHandler.initStatics(zone)
            zone:drawF10()
        end

        -- Update Ground Recon
        for _, zone in ipairs(zones) do
            zone:updateDiscoveredZones()
        end

        -- Initial Warehouses
        WarehouseManager:handleIncomingSupplies(blue_airbase.side, {WarehouseManager.StockTypes.INITIAL})
        if Config.enabled_su25t_bluefor then
            WarehouseManager:handleIncomingSupplies(blue_airbase.side, {WarehouseManager.StockTypes.SU25T_BLUEFOR})
        end
        WarehouseManager:handleIncomingSupplies(red_airbase.side, {WarehouseManager.StockTypes.INITIAL})
        return blue_airbase, red_airbase
    end

    function TheatreCommander.startMission()
        MissionLogger:info("Mission Commander: Starting Mission Setup...")

        -- Establish the theatre and get home airbases
        -- 1. Create the Persistor object
        local persistor = PersistanceManager
        

        -- 2. Try to load a saved state
        if persistor:isEnabled() and persistor:loadFromFile() then
            -- A. SAVE FILE FOUND: Apply the loaded state
            if not persistor:restoreState()then
                -- Restore failed, fallback to fresh start
                MissionLogger:error("Failed to restore state. Establishing new theatre.")
                blue_airbase, red_airbase = TheatreCommander.establishTheatre()
            end
        else
            -- B. NO SAVE FILE: Run first-time setup
            MissionLogger:info("No save file found. Establishing new theatre.")
            blue_airbase, red_airbase = TheatreCommander.establishTheatre()
        end
        
        -- 3. Start all services (these run in both cases)
        CommandHandler.init()
        CommandHandler.refreshJtacCmds(coalition.side.BLUE)
        CommandHandler.refreshJtacCmds(coalition.side.RED)

        -- Create Operation Managers for each coalition
        if blue_airbase and red_airbase then
            TheatreCommander.blue_op_manager = OperationManager:new(coalition.side.BLUE, blue_airbase)
            TheatreCommander.red_op_manager = OperationManager:new(coalition.side.RED, red_airbase)
        else
            MissionLogger:error("Could not create Operation Managers, home airbases not found.")
        end

        
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.BLUE, timer.getTime() + Config.std_resupply_time)
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.RED, timer.getTime() + Config.std_resupply_time)
        
        TheatreCommander:tick()
        
        -- AI DISPATCHER
        TheatreCommander.dispatchAI()


        EWRS_coalition = {
            [coalition.side.BLUE] = EWRS:new(coalition.side.BLUE),
            [coalition.side.RED] = EWRS:new(coalition.side.RED),
        }
        
        world.addEventHandler(ev)
        world.addEventHandler(ExperienceManager.EventHandler)
        world.addEventHandler(Jupiter)
        PersistanceManager:autoSave()
        -- trigger.action.outText("Theatre setup complete.", 5)
        MissionLogger:info("Mission Commander: Mission Setup Complete.")
    end

end