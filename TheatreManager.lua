local ticks = 15
local ticks1m = 0
local ticks5m = 0
TheatreCommander = {}
do

    TheatreCommander.blue_op_manager = nil
    TheatreCommander.red_op_manager = nil

    ---@param to_zone ZoneHandler
    ---@param side_sending_capture coalition.side
    function TheatreCommander.sendCapture(to_zone, side_sending_capture)
        if side_sending_capture == coalition.side.NEUTRAL then return end

        -- Prevent multiple helis being sent to the same target from different source zones
        if EnrouteManager:findByToZone(to_zone, side_sending_capture, {AITaskTypes.CAPTURE_HELO}) then
            return
        end

        -- Capture Helicopter spawn

        timer.scheduleFunction(function ()
            ---@type ZoneHandler[]
            local zones_to_check = ZoneHandler.sortZonesByDistance(to_zone.zone.point)

            for _, zone in ipairs(zones_to_check) do
                if zone.side == side_sending_capture and zone.zone_type == ZoneTypes.LOGISTICS then
                    local zones_distance = mist.utils.get2DDist(to_zone.zone.point,zone.zone.point)
    
                    if EnrouteManager:findByFromZone(zone,side_sending_capture,{AITaskTypes.CAPTURE_HELO}) then return end
    
                    -- checks if closest zone can deploy a heli
                    if zone.capture_heli_avail and zone.capture_heli_avail>0 and zones_distance <= Config.capture_helicopter_max_range then
                        -- send heli
                        TaskManager:initiateAITask(AITaskTypes.CAPTURE_HELO,side_sending_capture,true,to_zone,zone,false)
                        return
                    end
                end
    
            end
        end,nil,timer.getTime()+math.random(10,30))
        
    end

    -- checks if a capture group has arrived
    --- func desc
    ---@param enroute_group EnrouteObj
    function TheatreCommander.checkIfCaptureGroupArrived(enroute_group)

        local zone_coal_check = ZoneHandler.getFromName(enroute_group.to_zone.name)
        if not zone_coal_check then return false end
        if zone_coal_check.side ~= coalition.side.NEUTRAL then return false end

        local capture_group = Group.getByName(enroute_group.group_name)
        if not capture_group or not capture_group:isExist() then return false end

        ------------[capture zone checks]------------
        -- group is in zone and capture succeeds
        if enroute_group.ai_task_type == AITaskTypes.CAPTURE_HELO then
            MissionLogger:info("Heli captured zone: " .. enroute_group.to_zone.zone.name)
            -- remove heli from enroutes
            EnrouteManager:remove(enroute_group.group_name)
        else
            -- MissionLogger:info("Capture group not in zone or not all units are in zone")
            return false -- capture not successful
        end

        ------------[cancelling all other enemy helicopters inbound for this zone]------------

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

        -- [TASK: RECON]
        table.insert(possible_tasks, function()
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
        table.insert(possible_tasks, function()
            local awacs_enroute = EnrouteManager:findByTaskType(AITaskTypes.AWACS, side)
            if awacs_enroute and #awacs_enroute >= 1 then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_awacs then
                return false
            end
            if closest_dist and closest_dist > Config.tasking.min_cleareance_dist_for_awacs then
                MissionLogger:info("Initiating AWACS for " .. utils.coalitionToString(side))
                return TaskManager:initiateAITask(AITaskTypes.AWACS, side, true, nil, home_base, false)
            end
            return false
        end)

        -- [TASK: CAS]
        table.insert(possible_tasks, function()
            local cas_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAS, side)
            if #cas_enroute >= Config.tasking.max_cas_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cas then
                return false
            end
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and not utils.tableContains(active_zones, zone.name) then
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                       (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                    if discovered and not EnrouteManager:findByToZone(zone, side, {AITaskTypes.CAS}) then
                        local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                        if dist < Config.tasking.max_cas_range then
                            return TaskManager:initiateAITask(AITaskTypes.CAS, side, true, zone, nil, false)
                        end
                    end
                end
            end
            return false
        end)

        -- [TASK: SEAD]
        table.insert(possible_tasks, function()

            local sead_enroute = EnrouteManager:findByTaskType(AITaskTypes.SEAD, side)
            if sead_enroute and #sead_enroute >= Config.tasking.max_sead_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_sead then
                return false
            end
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and zone.zone_type == ZoneTypes.SAMSITE 
                    and not utils.tableContains(active_zones, zone.name) 
                    and mist.utils.get2DDist(home_base.zone.point, zone.zone.point) < Config.tasking.max_sead_range then
                        local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                           (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                        
                        if discovered then
                            if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.SEAD}) then
                                return TaskManager:initiateAITask(AITaskTypes.SEAD, side, true, zone, nil, false)
                            end
                        end
                    end
                end
            return false
        end)

        -- [TASK: CAP]
        table.insert(possible_tasks, function()
            local cap_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAP, side)
            if cap_enroute and #cap_enroute >= Config.tasking.max_cap_theatre then
                return false
            end
            if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cap then
                return false
            end

                for _, zone in ipairs(zones) do
                    if zone.side == side and zone.zone_type ~= ZoneTypes.AIRBASE then
                        local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                           (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                        local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)

                        if dist < 75000 and discovered then
                            if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.CAP}) then
                                return TaskManager:initiateAITask(AITaskTypes.CAP, side, true, zone, nil, false)
                            end
                        end
                    end
                end
            return false
        end)

        -- [TASK: STRIKE]
        table.insert(possible_tasks, function()
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
                for _, zone in ipairs(zones) do
                    if zone.side == enemy_side and utils.tableContains(valid_strike_targets, zone.zone_type) 
                    and not utils.tableContains(active_zones, zone.name)
                    and mist.utils.get2DDist(home_base.zone.point, zone.zone.point) < Config.tasking.max_strike_range then
                        local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                           (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                        
                        if discovered then
                            if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.STRIKE}) then
                                MissionLogger:info(string.format("[STRIKE] %s: Attempting to initiate STRIKE task to %s", 
                                    utils.coalitionToString(side), zone.name))
                                return TaskManager:initiateAITask(AITaskTypes.STRIKE, side, true, zone, nil, false)
                            end
                        end
                    end
                end
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


        -- Fisher-Yates shuffle to randomize the order of checks
        for i = #possible_tasks, 2, -1 do
            local j = math.random(i)
            possible_tasks[i], possible_tasks[j] = possible_tasks[j], possible_tasks[i]
        end

        -- Run through the shuffled list. As soon as one task spawns (returns true), exit the whole function.
        for _, task_func in ipairs(possible_tasks) do
            if task_func() then
                MissionLogger:info("Tasking succeeded for " .. utils.coalitionToString(side))
                return -- Task spawned
            end
        end
        MissionLogger:info("No tasks spawned for " .. utils.coalitionToString(side))
    end

    ---@param zone ZoneHandler
    ---@return boolean
    function TheatreCommander.sendPotentialCapture(zone)
        if zone.side ~= coalition.side.NEUTRAL then return false end

        local now = timer.getTime()
        if not zone.last_capture_attempt then zone.last_capture_attempt = timer.getTime() end

        -- cooldown before sending capture group
        if now - zone.last_capture_attempt < Config.cooldown_before_capture_attempt then return false end

        if EnrouteManager:findByToZone(zone, nil, {AITaskTypes.CAPTURE_HELO}) then return false end
        if EnrouteManager:findByFromZone(zone, nil, {AITaskTypes.CAPTURE_HELO}) then return false end

        -- both sides have a chance to send capture group
        if math.random(0,100) >= Config.retry_capture_chance then return false end
        local side_sending_capture = math.random(1,2)

        -- MissionLogger:info(utils.coalitionToString(side_sending_capture).." attempting capture for zone: " .. zone.name)
        zone.last_capture_attempt = now
        TheatreCommander.sendCapture(zone, side_sending_capture)
        return true
    end

    -- This function is executed every 15 seconds
    function TheatreCommander:tick()
        if MISSION_ENDED == true then return end
        

        local t1m_update = function()
            MissionLogger:info("1 minute")


    
            local upgraded_zone = false
            local capture_helicopter_sent = false
            for _, zone in ipairs(zones) do

                    capture_helicopter_sent = TheatreCommander.sendPotentialCapture(zone)

                    if not upgraded_zone then
                        upgraded_zone = zone:checkLogisticsZone()
                    end
                    zone:checkCOMMSZone()
                    zone:checkAirbaseZone()

                    zone:addAIAssets(10) -- Supply chance every minute

                    if not capture_helicopter_sent and zone.side ~=coalition.side.NEUTRAL
                    and zone:checkIfEmpty() then
                        local capturing_side = utils.getEnemyCoalition(zone.side)
                        zone:capture(coalition.side.NEUTRAL)
                        -- Send a capture helicopter+
                        TheatreCommander.sendCapture(zone, capturing_side)
                    end

                    -- this spawns an attack convoy from strongpoints
                    if math.random(1,100) <= 15 and zone.zone_type == ZoneTypes.STRONGPOINT
                    and zone.attack_convoy and zone.attack_convoy > 0
                    and #EnrouteManager:findByTaskType(AITaskTypes.ATTACK_CONVOY,zone.side) < Config.tasking.max_attack_convoy_per_theatre
                    and not EnrouteManager:findByToZone(zone,zone.side,{AITaskTypes.ATTACK_CONVOY})
                    then
                        TaskManager:initiateAITask(AITaskTypes.ATTACK_CONVOY,zone.side,true,nil,zone,false)
                    end

                    
            end
            ctld.monitorFARPDestruction()
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

        local t10m_update = function()
            TheatreCommander:smokeFrontline()
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

            if ticks1m % 10 == 0 then
                t10m_update()
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
                        -- SCENARIO 1: CONVOY Dead (or at destination)
                        trigger.action.outTextForCoalition(enroute.side, "Convoy sent to attack " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager.enroutes[i] = nil

                    elseif not UnitHandler.checkConvoyMoving(convoy_group) then
                        -- SCENARIO 2: CONVOY STUCK (or at destination)
                        local convoy_pos = mist.getLeadPos(convoy_group)
                        if convoy_pos and enroute.to_zone:isPointInsideZone(convoy_pos) then
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
                            -- It's stuck en route (not in the zone)
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
                        enroute.stuck_since = nil
                        
                        -- Check for redirect loop
                        if enroute.redirects_count and enroute.redirects_count > 3 then
                            -- SCENARIO 5: CONVOY FINISHED (too many redirects)
                            MissionLogger:info("Attack convoy exceeded max redirects count: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                        end

                        -- Checks if destination zone has been captured by friendly side
                        local zone_coal_check = ZoneHandler.getFromName(enroute.to_zone.name)
                        if zone_coal_check and (zone_coal_check.side == enroute.side or zone_coal_check.side == coalition.side.NEUTRAL) then
                            MissionLogger:info("Attack convoy destination captured by friendly side, removing: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                        end

                    end
                elseif enroute.ai_task_type == AITaskTypes.RECON then

                    local recon_gr = Group.getByName(enroute.group_name)
                    if recon_gr and recon_gr:isExist() then
                        local pos = mist.getLeadPos(recon_gr)
                        if pos and mist.utils.get2DDist(pos, enroute.to_zone.zone.point) <= Config.tasking.range_for_recon_to_discover_zone then
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
                                CommandHandler.requestMenuRefresh(enroute.side)
                                trigger.action.outTextForCoalition(enroute.side,"Recon task has discovered " .. enroute.to_zone.name.."\nCheck F10 map", 10)
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
    ---@param stock_types WarehouseManager.StockTypes[]|nil
    ---@param target_airbase ZoneHandler|nil Optional target airbase zone, defaults to home airbase
    function TheatreCommander.sendWarehouseResupply(side, repeat_tasking, stock_types, target_airbase)
        local cargo_sent_table
        local new_group_name
        local destination_airbase

        local blue_airbases = {}
        local red_airbases = {}
        for _, zone in ipairs(zones) do
            if zone.zone_type == ZoneTypes.AIRBASE and zone.side == coalition.side.BLUE then
                table.insert(blue_airbases, zone)
            elseif zone.zone_type == ZoneTypes.AIRBASE and zone.side == coalition.side.RED then
                table.insert(red_airbases, zone)
            end
        end

        if side == coalition.side.BLUE and Scenario.resupply.blue_point then
            if #blue_airbases == 0 then return end
            destination_airbase = target_airbase or blue_airbases[math.random(#blue_airbases)]

            if not destination_airbase or destination_airbase.side ~= side then
                return MissionLogger:warn("Invalid BLUE resupply destination airbase")
            end
            cargo_sent_table = mist.teleportToPoint({
                groupName = GroupData.COMMON_ASSETS.BLUE.resupply_aircraft,
                point = Scenario.resupply.blue_point,
                action = "clone",
                radius = 10000
            })
            if not cargo_sent_table or not cargo_sent_table.name then return MissionLogger:error("Could not send BLUE resupply.") end
            new_group_name = cargo_sent_table.name

        elseif side == coalition.side.RED and Scenario.resupply.red_point then
            if #red_airbases == 0 then return end
            destination_airbase = target_airbase or red_airbases[math.random(#red_airbases)]

            if not destination_airbase or destination_airbase.side ~= side then
                return MissionLogger:warn("Invalid RED resupply destination airbase")
            end
            cargo_sent_table = mist.teleportToPoint({
                groupName = GroupData.COMMON_ASSETS.RED.resupply_aircraft,
                point = Scenario.resupply.red_point,
                action = "clone",
                radius = 10000
            })
            if not cargo_sent_table or not cargo_sent_table.name then return MissionLogger:error("Could not send RED resupply.") end
            new_group_name = cargo_sent_table.name

        else
            return
        end
        
        if destination_airbase == nil then return MissionLogger:error("Resupply task: Destination airbase not found") end
        if not destination_airbase.airbase_name then return MissionLogger:error("Resupply task: Destination airbase has no airbase name") end
        local destination_airbase_obj = Airbase.getByName(destination_airbase.airbase_name)
        if destination_airbase_obj and destination_airbase_obj:getCoalition() ~= side then
            return MissionLogger:warn("Resupply task: Destination airbase coalition mismatch")
        end

        EnrouteManager:add({
            group_name = new_group_name,
            to_zone = destination_airbase,
            from_zone = destination_airbase,
            side = side,
            ai_task_type = AITaskTypes.RESUPPLY_CARGO
        })
        
        timer.scheduleFunction(function ()
            local cargo_group = Group.getByName(new_group_name)
            if not cargo_group or not cargo_group:isExist() then return end
            
            -- Check if in this short time the airbase has been lost
            local airbase_obj = Airbase.getByName(destination_airbase.airbase_name)
            if not airbase_obj then
                cargo_group:destroy()
                EnrouteManager:remove(new_group_name)
                return
            end
            if airbase_obj:getCoalition() ~= side then
                cargo_group:destroy()
                EnrouteManager:remove(new_group_name)
                return
            end

            local cargo_ctr = cargo_group:getController()
            local landPos = destination_airbase.zone.point
            
            local alignX, alignZ   -- WP1: 15km out (Alignment)
            local startX, startZ   -- WP2: Runway Threshold (Stabilize)
            local dropX, dropZ     -- WP3: Runway End (Drop Trigger)
            local exitX, exitZ     -- WP4: 10km out (Exit)
            local airdropAlt = 0
            
            local airbase = Airbase.getByName(destination_airbase.airbase_name)
            
            if airbase then
                local runways = airbase:getRunways()
                if runways and runways[1] then
                    local rwy = runways[1]
                    local course = rwy.course * -1 -- Invert for calculation
                    local halfLen = rwy.length / 2
                    
                    local alignDist = halfLen + 15000
                    alignX = rwy.position.x + (alignDist * math.cos(course + math.pi))
                    alignZ = rwy.position.z + (alignDist * math.sin(course + math.pi))
                    
                    
                    local startDist = halfLen
                    startX = rwy.position.x + (startDist * math.cos(course + math.pi))
                    startZ = rwy.position.z + (startDist * math.sin(course + math.pi))
                    
                    
                    local dropDist = halfLen
                    dropX = rwy.position.x + (dropDist * math.cos(course))
                    dropZ = rwy.position.z + (dropDist * math.sin(course))
                    
                    local exitDist = halfLen + 10000
                    exitX = rwy.position.x + (exitDist * math.cos(course))
                    exitZ = rwy.position.z + (exitDist * math.sin(course))
                end
                
                local groundHeight = land.getHeight({x=landPos.x, y=landPos.z})
                airdropAlt = groundHeight + 305
            end
            
            -- Fallback coordinates if airbase data fails
            if not alignX then
                alignX = landPos.x - 15000
                alignZ = landPos.z
                startX = landPos.x - 1000
                startZ = landPos.z
                dropX  = landPos.x + 1000
                dropZ  = landPos.z
                exitX  = landPos.x + 10000
                exitZ  = landPos.z
            end
            
            local stock_types_str = "{}"
            if stock_types ~= nil and #stock_types > 0 then
                stock_types_str = "{" .. table.concat(stock_types, ", ") .. "}"
            end
            
            local scriptCommand = string.format("UnitHandler.simulateResupply('%s', '%s', %d, %s)", new_group_name, destination_airbase.airbase_name, side, stock_types_str)
            local waypointScriptTask = {
                id = "ComboTask",
                params = {
                    tasks = {
                        [1] = {
                            enabled = true,
                            auto = false,
                            id = "WrappedAction",
                            number = 1,
                            params = { action = { id = "Script", params = { command = scriptCommand } } }
                        }
                    }
                }
            }
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {
                            -- WP1: Alignment (Far out)
                            {
                                type = AI.Task.WaypointType.TURNING_POINT,
                                action = AI.Task.TurnMethod.TURNING_POINT,
                                x = alignX,
                                y = alignZ,
                                alt = airdropAlt,
                                alt_type = AI.Task.AltitudeType.RADIO,
                                speed = 150
                            },
                            -- WP2: Runway Start (Forces straight flight)
                            {
                                type = AI.Task.WaypointType.TURNING_POINT,
                                action = AI.Task.TurnMethod.FLY_OVER_POINT, -- Fly exactly over this
                                x = startX,
                                y = startZ,
                                alt = airdropAlt,
                                alt_type = AI.Task.AltitudeType.RADIO,
                                speed = 150
                            },
                            -- WP3: Runway End -> TRIGGER DROP
                            {
                                type = AI.Task.WaypointType.TURNING_POINT,
                                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                                x = dropX,
                                y = dropZ,
                                alt = airdropAlt,
                                alt_type = AI.Task.AltitudeType.RADIO,
                                speed = 150,
                                task = waypointScriptTask
                            },
                            -- WP4: Exit Vector
                            {
                                type = AI.Task.WaypointType.TURNING_POINT,
                                action = AI.Task.TurnMethod.FIN_POINT,
                                x = exitX,
                                y = exitZ,
                                alt = 2000,
                                alt_type = AI.Task.AltitudeType.BARO,
                                speed = 250
                            }
                        }
                    }
                }
            }
            
            cargo_ctr:setTask(missionTask)
            trigger.action.outTextForCoalition(side, "RESUPPLY Cargo aircraft inbound for " .. destination_airbase.name, 10)
            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
        end, {}, timer.getTime() + 12) -- Short delay to ensure unit is ready

        if repeat_tasking then
            timer.scheduleFunction(function ()
                TheatreCommander.sendWarehouseResupply(side, true)
            end,nil, timer.getTime() + Config.std_resupply_time)
        end
    end
    
    
    -- AI DISPATCHER

    ---@param side coalition.side
    function TheatreCommander.dispatchAI(side)

        local next_interval = 999999
        if side == coalition.side.BLUE then
            next_interval = Config.tasking.BLUFOR_dispatcher_interval
        else
            next_interval = Config.tasking.REDFOR_dispatcher_interval
        end
        timer.scheduleFunction(function ()
            if MISSION_ENDED == true then return end
            TheatreCommander:evaluateAITasks(side)
            
            TheatreCommander.dispatchAI(side)
        end, nil, timer.getTime() + next_interval)

    end

    function TheatreCommander.checkAirbasesCoalition()

        -- MissionLogger:info(blue_airbase)
        local b_airbase = Airbase.getByName(blue_airbase.airbase_name)
        if b_airbase then
            b_airbase:autoCapture(false)
            b_airbase:setCoalition(blue_airbase.side)
        end
        local r_airbase = Airbase.getByName(red_airbase.airbase_name)
        if r_airbase then
            r_airbase:autoCapture(false)
            r_airbase:setCoalition(red_airbase.side)
        end
        
    end

    local smoke_id = 0
    --[[
    
        1 = small smoke and fire
        2 = medium smoke and fire
        3 = large smoke and fire
        4 = huge smoke and fire
        5 = small smoke
        6 = medium smoke 
        7 = large smoke
        8 = huge smoke ]]

    -- Create 2-4 smokes near the frontline (closes red base), with varying size and duration
    function TheatreCommander:smokeFrontline()
        -- Closest enemy zone distance
        local closest_zone, frontline_dist = blue_airbase:getClosestZone(coalition.side.RED)
        local variance = 20000
        if closest_zone and frontline_dist then
            ---@type vec3[]
            local smoke_points = {}

            for i=0, math.random(2,4) do
            local point = {
                x = closest_zone.zone.point.x + frontline_dist + math.random(-variance, variance),
                y = closest_zone.zone.point.y + frontline_dist + math.random(-variance, variance)
            }
                table.insert(smoke_points, mist.utils.makeVec3(point))
            end


            for _, point in ipairs(smoke_points) do
                smoke_id = smoke_id + 1
                local smoke_string = "TheatreSmoke" .. smoke_id
                local smoke_type = math.random(5,8) -- Only smoke (no fire)
                local duration = math.random(120, 300) -- 2-5 minutes
                trigger.action.effectSmokeBig(point,math.random(1,8),1,smoke_string)

                timer.scheduleFunction(function ()
                    trigger.action.effectSmokeStop(smoke_string)
                end, nil, timer.getTime() + duration)
            end

        end

    end

    ---@return ZoneHandler, ZoneHandler
    function TheatreCommander.establishTheatre()
        MissionLogger:info("TheatreCommander: Generating Theatre Layout...")

        if not (blue_airbase and red_airbase) then
            return MissionLogger:error("Could not initialize blue_airbase or/and red_airbase")
        end

        -- All zones except home airbases
        local all_other_zones = {}

        blue_airbase.side = coalition.side.BLUE
        blue_airbase.level = 4
        red_airbase.side = coalition.side.RED
        red_airbase.level = 4
        for _, zone in ipairs(zones) do
            if zone.name ~= blue_airbase.name
            and zone.name ~= red_airbase.name then
                -- Reset flags for a fresh generation
                if Scenario.coalition_setup.auto_coalition_designation and not zone.side then
                    zone.side = coalition.side.NEUTRAL
                end
                table.insert(all_other_zones, zone)
            end
        end

        -- 2. APPLY DIFFICULTY (Zone Count) & REBUILD GLOBAL ZONES TABLE
        local diff_setting = Scenario.difficulty
        local active_ratio = 1

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

            stats.blue_zones = 0
            stats.red_zones = 0
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
                if zone.side == coalition.side.BLUE then
                    stats.blue_zones = stats.blue_zones + 1
                elseif zone.side == coalition.side.RED then
                    stats.red_zones = stats.red_zones + 1
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
            
            -- Find unassigned zones first to calculate budgets correctly
            local unassigned = {}
            for _, z in ipairs(pool) do
                if z.zone_type == nil then
                    table.insert(unassigned, z)
                end
            end
            
            if #unassigned == 0 then return end -- All zones already have types assigned
            
            -- Shuffle for randomness
            utils.shuffleTable(unassigned)
            
            -- Guarantee at least 1 of each zone type (if enough zones available)
            local idx = 1
            local assigned_guaranteed = 0
            
            -- COMMS (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.COMMS
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- LOGISTICS (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.LOGISTICS
                unassigned[idx].next_level_up_avail = timer.getTime()
                unassigned[idx].capture_heli_avail = 4
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- SAMSITE (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.SAMSITE
                local r = math.random(1, 100)
                if r < 15 then unassigned[idx].sam_classification = SAM_TYPES.SHORT_RANGE
                elseif r < 60 then unassigned[idx].sam_classification = SAM_TYPES.MEDIUM_RANGE
                else unassigned[idx].sam_classification = SAM_TYPES.LONG_RANGE end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- EWSITE (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.EWSITE
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- STRONGPOINT (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                unassigned[idx].attack_convoy = math.random(0,1)
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- Now handle remaining zones with weighted budgets
            local remaining_zones = #unassigned - assigned_guaranteed
            
            if remaining_zones > 0 then
                local weights = (Config.theatre and Config.theatre.zone_type_weights) or {
                    [ZoneTypes.STRONGPOINT] = 50,
                    [ZoneTypes.LOGISTICS] = 15,
                    [ZoneTypes.SAMSITE] = 10,
                    [ZoneTypes.COMMS] = 10,
                    [ZoneTypes.EWSITE] = 5
                }
                local total_w = 0
                for _, w in pairs(weights) do total_w = total_w + w end
                
                -- Calculate budgets for remaining zones only
                local budget_logistics = math.ceil((weights[ZoneTypes.LOGISTICS]/total_w) * remaining_zones)
                local budget_sam       = math.ceil((weights[ZoneTypes.SAMSITE]/total_w) * remaining_zones)
                local budget_comms     = math.ceil((weights[ZoneTypes.COMMS]/total_w) * remaining_zones)
                local budget_ew        = math.ceil((weights[ZoneTypes.EWSITE]/total_w) * remaining_zones)
                
                local pre_assigned_count = #pool - #unassigned
                MissionLogger:info("Theatre Gen: Assigning Types for " .. utils.coalitionToString(home.side) .. " Pool. Total Zones: " .. #pool ..
                    " (Pre-assigned: " .. pre_assigned_count .. ", Guaranteed: " .. assigned_guaranteed .. ", Remaining: " .. remaining_zones .. ")" ..
                    " | Logistics: " .. budget_logistics .. ", SAM: " .. budget_sam .. ", COMMS: " .. budget_comms .. ", EW: " .. budget_ew)

                -- Assign remaining zones using budgets
                for i = idx, #unassigned do
                    local zone = unassigned[i]
                    
                    if budget_comms > 0 then
                        zone.zone_type = ZoneTypes.COMMS
                        budget_comms = budget_comms - 1
                    elseif budget_logistics > 0 then
                        zone.zone_type = ZoneTypes.LOGISTICS
                        zone.next_level_up_avail = timer.getTime()
                        zone.capture_heli_avail = 4
                        budget_logistics = budget_logistics - 1
                    elseif budget_ew > 0 then
                        zone.zone_type = ZoneTypes.EWSITE
                        budget_ew = budget_ew - 1
                    elseif budget_sam > 0 then
                        zone.zone_type = ZoneTypes.SAMSITE
                        local r = math.random(1, 100)
                        if r < 15 then zone.sam_classification = SAM_TYPES.SHORT_RANGE
                        elseif r < 60 then zone.sam_classification = SAM_TYPES.MEDIUM_RANGE
                        else zone.sam_classification = SAM_TYPES.LONG_RANGE end
                        budget_sam = budget_sam - 1
                    else
                        zone.zone_type = ZoneTypes.STRONGPOINT
                        zone.attack_convoy = math.random(0,1)
                    end
                end
            else
                local pre_assigned_count = #pool - #unassigned
                MissionLogger:info("Theatre Gen: Assigning Types for " .. utils.coalitionToString(home.side) .. " Pool. Total Zones: " .. #pool ..
                    " (Pre-assigned: " .. pre_assigned_count .. ", Guaranteed: " .. assigned_guaranteed .. ", Remaining: 0)")
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

            if zone.zone_type == ZoneTypes.AIRBASE then
                if not utils.tableContains(stats.blue_discovered_zones, zone.name) then
                    table.insert(stats.blue_discovered_zones, zone.name)
                end
                if not utils.tableContains(stats.red_discovered_zones, zone.name) then
                    table.insert(stats.red_discovered_zones, zone.name)
                end
            end

            -- Spawn
            UnitHandler.initZoneUnits(zone)
            UnitHandler.initStatics(zone)
            UnitHandler.initFARP(zone)
            zone:drawF10()
        end

        -- Update Ground Recon
        for _, zone in ipairs(zones) do
            zone:updateDiscoveredZones()
        end

        -- Initial Warehouses
        WarehouseManager:handleIncomingSupplies(blue_airbase.side, {WarehouseManager.StockTypes.INITIAL})
        if Config.enabled_su25t_blufor then
            WarehouseManager:handleIncomingSupplies(blue_airbase.side, {WarehouseManager.StockTypes.SU25T_BLUFOR})
        end
        WarehouseManager:handleIncomingSupplies(red_airbase.side, {WarehouseManager.StockTypes.INITIAL})

        -- Carrier warehouse
        if Scenario.carrier_setup then
            if Scenario.carrier_setup.enabled
            and Scenario.carrier_setup.carrier_unit_name then
                WarehouseManager:attributeAirbaseStock(Scenario.carrier_setup.carrier_unit_name, coalition.side.BLUE, {WarehouseManager.StockTypes.CARRIER_INITAL})
            end
        end
        UnitHandler.carrierCheck()

        return blue_airbase, red_airbase
    end

    function TheatreCommander.startMission()
        MissionLogger:info("Mission Commander: Starting Mission Setup...")

        -- Establish the theatre and get home airbases
        local persistor = PersistenceManager

        world.addEventHandler(ev)
        local persistence_enabled = persistor:isEnabled()

        if persistence_enabled and persistor:loadUserData() and persistor:loadFromFile() then
            if not persistor:restoreState()then
                MissionLogger:error("Failed to restore state. Establishing new theatre.")
                trigger.action.outText("Failed to restore state. Establishing new theatre. Check logs",60)
                blue_airbase, red_airbase = TheatreCommander.establishTheatre()
            end
        else
            MissionLogger:info("No save file found. Establishing new theatre.")
            blue_airbase, red_airbase = TheatreCommander.establishTheatre()
        end
        
        if not (blue_airbase and red_airbase) then
            return trigger.action.outText("ERROR: Mission theatre setup failed. Check logs (dcs.log) and config.", 30)
        end

        if persistence_enabled then
            persistor:autoSave()
            timer.scheduleFunction(function() trigger.action.outText("Persistence enabled.",30) end, {}, timer.getTime() + 2)
        end

        TheatreCommander.checkAirbasesCoalition()

        -- Create Operation Managers for each coalition
        TheatreCommander.blue_op_manager = OperationManager:new(coalition.side.BLUE, blue_airbase)
        TheatreCommander.red_op_manager = OperationManager:new(coalition.side.RED, red_airbase)

        
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.BLUE, timer.getTime() + Config.std_resupply_time)
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.RED, timer.getTime() + Config.std_resupply_time)
        
        TheatreCommander:tick()
        
        -- AI DISPATCHER
        TheatreCommander.dispatchAI(coalition.side.BLUE)
        TheatreCommander.dispatchAI(coalition.side.RED)


        EWRS_coalition = {
            [coalition.side.BLUE] = EWRS:new(coalition.side.BLUE),
            [coalition.side.RED] = EWRS:new(coalition.side.RED),
        }
        
        world.addEventHandler(ExperienceManager.EventHandler)

        if Config.jupiter_enabled then
            world.addEventHandler(Jupiter)
        end
        
        -- trigger.action.outText("Theatre setup complete.", 5)
        MissionLogger:info("Mission Commander: Mission Setup Complete.")
        timer.scheduleFunction(function()
        trigger.action.outText("Assets initialized.",5)
        end, {}, timer.getTime() + 15)
    end

end