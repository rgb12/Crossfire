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
        MissionLogger:info("AI Commander checking tasks for: " .. utils.coalitionToString(side))
        
        local side_comms_towers = 0
        if side == coalition.side.BLUE then
            side_comms_towers = stats.blue_comms_zones
        elseif side == coalition.side.RED then
            side_comms_towers = stats.red_comms_zones
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

        -- Missions are decided upon the distance from the home airbase
        local closest_enemy_zone, closest_dist = home_base:getClosestZone(enemy_side,nil,nil,true)
        local closest_friendly_zone, _ = home_base:getClosestZone(side,nil,nil,true)


        -- 0. RECON CHECK
        -- Check if we are already running a RECON mission
        local recon_enroute = EnrouteManager:findByTaskType(AITaskTypes.RECON, side)
        if recon_enroute and #recon_enroute < 1
        and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_recon
        then
            -- Find the closest *undiscovered* enemy zone
            local closest_undiscovered_zone = nil
            local closest_dist = 999999
            local discovered_list = (side == coalition.side.BLUE) and stats.blue_discovered_zones or stats.red_discovered_zones
            
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and not utils.tableContains(discovered_list, zone.name) then
                    local dist = mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                    if dist < closest_dist then
                        closest_dist = dist
                        closest_undiscovered_zone = zone
                    end
                end
            end

            if closest_undiscovered_zone then
                -- Found one, check if a RECON mission is already going to it
                if not EnrouteManager:findByToZone(closest_undiscovered_zone, side, {AITaskTypes.RECON}) then
                    MissionLogger:info("AI Commander: Tasking RECON for " .. utils.coalitionToString(side) .. " to " .. closest_undiscovered_zone.name)
                    local task_sent = TaskManager:initiateAITask(AITaskTypes.RECON, side, true, closest_undiscovered_zone, nil, false)
                    if task_sent then return end -- Only launch one recon mission per 5-minute tick
                end
            end
        end



        -- 1. AWACS CHECK
        -- Check if an AWACS is already airborne for this side
        local awacs_enroute = EnrouteManager:findByTaskType(AITaskTypes.AWACS, side)
        if #awacs_enroute == 0 and closest_dist < 75000
        and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_awacs then
            -- No AWACS is up, let's launch one from the home base
            MissionLogger:info("AI Commander: No AWACS found for " .. utils.coalitionToString(side) .. ". Tasking one.")
            local task_sent = TaskManager:initiateAITask(AITaskTypes.AWACS, side, true, nil, home_base, false)
            if task_sent then return end
        end


        -- 2. CAS CHECK
        local cas_enroute = EnrouteManager:findByTaskType(AITaskTypes.CAS, side)
        if #cas_enroute < 2 then -- Only allow 2 auto-CAS missions at a time
   
            if closest_enemy_zone and closest_dist < Config.tasking.max_cas_range
            and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_cas then -- Only attack targets within 150km
                -- Check if a CAS mission is ALREADY going to this specific zone
                if not EnrouteManager:findByToZone(closest_enemy_zone, side, {AITaskTypes.CAS}) then
                    MissionLogger:info("AI Commander: Tasking CAS for " .. utils.coalitionToString(side) .. " to " .. closest_enemy_zone.name)
                    local task_sent = TaskManager:initiateAITask(AITaskTypes.CAS, side, true, closest_enemy_zone, nil, false)
                    if task_sent then return end
                end
            end
        end


        -- 3. SEAD CHECK
        -- Check if we are already running the max number of SEAD missions
        local sead_enroute = EnrouteManager:findByTaskType(AITaskTypes.SEAD, side)
        if sead_enroute and #sead_enroute < 3
        and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_sead 
        then -- Only allow 3 auto-SEAD missions at a time
        
            -- Find a discovered enemy SAM site
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and zone.zone_type == ZoneTypes.SAMSITE then
                    -- Check if this zone is discovered
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                       (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                    
                    if discovered then
                        -- Found a discovered SAM site. Check if SEAD is already enroute to it
                        if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.SEAD}) then
                            MissionLogger:info("AI Commander: Tasking SEAD for " .. utils.coalitionToString(side) .. " to " .. zone.name)
                            local task_sent = TaskManager:initiateAITask(AITaskTypes.SEAD, side, true, zone, nil, false)
                            -- Only launch one SEAD mission per 5-minute tick
                            if task_sent then return end
                        end
                    end
                end
            end
        end

        -- 4. INTERCEPT CHECK
        -- Check if we are already running the max number of INTERCEPT missions
        local intercept_enroute = EnrouteManager:findByTaskType(AITaskTypes.INTERCEPT, side)
        if intercept_enroute and #intercept_enroute < 3
        and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_intercept
        then -- Only allow 3 auto-INTERCEPT mission
            -- Find a friendly frontline zone to patrol
            -- We'll pick the friendly zone closest to the ENEMY home base
            if closest_friendly_zone then
                -- Check if an INTERCEPT mission is already patrolling this zone
                if not EnrouteManager:findByToZone(closest_friendly_zone, side, {AITaskTypes.INTERCEPT}) then
                    MissionLogger:info("AI Commander: Tasking INTERCEPT for " .. utils.coalitionToString(side) .. " to patrol " .. closest_friendly_zone.name)
                    local task_sent = TaskManager:initiateAITask(AITaskTypes.INTERCEPT, side, true, closest_friendly_zone, nil, false)
                    if task_sent then return end
                end
            end
        end

        -- 5. STRIKE CHECK
        -- Check if we are already running the max number of STRIKE missions
        local strike_enroute = EnrouteManager:findByTaskType(AITaskTypes.STRIKE, side)
        if strike_enroute and #strike_enroute < 2 
        and side_comms_towers >= Config.tasking_requirements.comms_zones_required_for_strike
        then -- Only allow 2 auto-STRIKE missions
            
            -- Define high-value static targets
            local valid_strike_targets = {
                ZoneTypes.EWSITE,
                ZoneTypes.LOGISTICS,
                ZoneTypes.COMMS,
            }

            -- Find a discovered, valid enemy static zone
            for _, zone in ipairs(zones) do
                if zone.side == enemy_side and utils.tableContains(valid_strike_targets, zone.zone_type) then
                    -- Check if this zone is discovered
                    local discovered = (side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, zone.name)) or
                                       (side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, zone.name))
                    
                    if discovered then
                        -- Found a valid, discovered target. Check if STRIKE is already enroute TO IT
                        if not EnrouteManager:findByToZone(zone, side, {AITaskTypes.STRIKE}) then
                            MissionLogger:info("AI Commander: Tasking STRIKE for " .. utils.coalitionToString(side) .. " against " .. zone.name)
                            local task_sent = TaskManager:initiateAITask(AITaskTypes.STRIKE, side, true, zone, nil, false)
                            if task_sent then return end -- Only launch one STRIKE mission per 5-minute tick
                        end
                    end
                end
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

        MissionLogger:info(utils.coalitionToString(side_sending_capture).." attempting capture for zone: " .. zone.name)
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

            TheatreCommander:evaluateAITasks(coalition.side.BLUE)
            TheatreCommander:evaluateAITasks(coalition.side.RED)

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
                
            end,{}, timer.getTime() + 22)
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
    
                if enroute.ai_task_type == AITaskTypes.CAPTURE_CONVOY then
                    local capture_convoy_gr = Group.getByName(enroute.group_name)
                    
                    if not capture_convoy_gr or not capture_convoy_gr:isExist() then
                        -- SCENARIO 1: CONVOY DESTROYED
                        trigger.action.outTextForCoalition(enroute.side, "Convoy sent to capture " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager:remove(enroute.group_name)
    
                    elseif TheatreCommander.checkIfCaptureGroupArrived(enroute) then
                        -- SCENARIO 2: CONVOY FINISHED (ARRIVED)
                        trigger.action.setGroupAIOff(capture_convoy_gr)
                        timer.scheduleFunction(function ()
                            if capture_convoy_gr and capture_convoy_gr:isExist() then capture_convoy_gr:destroy() end
                        end, {}, timer.getTime() + math.random(15, 25))
                    
                    elseif not UnitHandler.checkConvoyMoving(capture_convoy_gr) then
                        -- SCENARIO 3: CONVOY STUCK
                        if not enroute.stuck_since then
                            -- First time we've seen it stuck, start the timer
                            enroute.stuck_since = timer.getTime()
                            MissionLogger:info("Capture convoy " .. enroute.group_name .. " detected as stuck, starting timer.")
                        elseif (timer.getTime() - enroute.stuck_since) > Config.stuck_convoy_timeout then
                            -- It's been stuck for over 2 minutes, remove it
                            trigger.action.outTextForCoalition(enroute.side, "Capture convoy to " .. enroute.to_zone.zone.name .. " got stuck and was removed.", 10)
                            capture_convoy_gr:destroy()
                            EnrouteManager:remove(enroute.group_name)
                        end
                    else
                        -- SCENARIO 4: CONVOY ALIVE AND MOVING
                        -- It's moving, so clear any stuck timer
                        enroute.stuck_since = nil
                    end
                
                
                elseif enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)
                    
                    if not convoy_group or not convoy_group:isExist() then
                        -- SCENARIO 1: CONVOY DESTROYED
                        trigger.action.outTextForCoalition(enroute.side, "Convoy sent to attack " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager:remove(enroute.group_name)

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
                                EnrouteManager:remove(enroute.group_name)
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
                                EnrouteManager:remove(enroute.group_name)
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
                            EnrouteManager:remove(enroute.group_name)
                            if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                        end
                    end
                end
            end -- end if enroute
        end
    end
    
    timer.scheduleFunction(tsec_update, {}, timer.getTime() + 15)
    end

    function TheatreCommander.sendWarehouseResupply(side)
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
            
            timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, side, timer.getTime() + stats.blue_resupply_time)
        
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

            timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, side, timer.getTime() + stats.red_resupply_time)
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



    ---@return ZoneHandler,ZoneHandler
    function TheatreCommander.establishTheatre()

        MissionLogger:info(zones)
        

        for _,zone in ipairs(zones) do
            if zone.name == Scenario.blue_airbase.name
            and zone.zone_type == ZoneTypes.AIRBASE then
                zone.side = coalition.side.BLUE
                zone.level = 4
                home_base = mist.utils.deepCopy(zone)
                -- MissionLogger:info(zone.airbase_name)
                -- Airbase.getByName(zone.airbase_name):autoCapture(false):setCoalition(zone.side)
            elseif zone.name == Scenario.red_airbase.name
            and zone.zone_type == ZoneTypes.AIRBASE then
                zone.side = coalition.side.RED
                zone.level = 4
                red_base = mist.utils.deepCopy(zone)

                -- Airbase.getByName(zone.airbase_name):autoCapture(false):setCoalition(zone.side)

            end
        end
        if not (home_base and red_base) then return MissionLogger:error("Failed to initialize home airbases") end


        -- enables both coalitions to see the opposing main airbase
        table.insert(stats.blue_discovered_zones,red_base.name)
        table.insert(stats.blue_discovered_zones,home_base.name)
        table.insert(stats.red_discovered_zones,red_base.name)
        table.insert(stats.red_discovered_zones,home_base.name)


        if stats.blue_comms_zones+stats.red_comms_zones> Config.max_comms_zones then
            return MissionLogger:error("Total COMMS Zones exceeded to max amount allowed")
        end

        -- increase capture spawn chance based on comms zone amount
        stats.blue_capture_lost_zone_chance = stats.blue_capture_lost_zone_chance+(10*stats.blue_comms_zones)
        stats.red_capture_lost_zone_chance = stats.red_capture_lost_zone_chance+(10*stats.red_comms_zones)
        stats.blue_retry_capture_chance = stats.blue_retry_capture_chance+(10*stats.blue_comms_zones)
        stats.red_retry_capture_chance = stats.red_retry_capture_chance+(10*stats.red_comms_zones)
        
        -- reduce resupply time
        stats.blue_resupply_time = Config.std_resupply_time *(1-(0.10*stats.blue_comms_zones))
        stats.red_resupply_time = Config.std_resupply_time *(1-(0.10*stats.red_comms_zones))


        --WARN the following need serious perfomance improvements

        -- get all zones within 50 km and turn them blue
        MissionLogger:info("Initializing zones (Pass 1: Assigning Sides)...")
        -- ### PASS 1: Assign Sides to all zones ###
        if Scenario.coalition_setup.auto_coalition_designation then
            for _, zone in ipairs(zones) do
                if not (zone.name == home_base.name or zone.name == red_base.name) then
                    -- Only assign a side if one isn't hard-coded
                    if not zone.side then
                        if mist.utils.get2DDist(home_base.zone.point, zone.zone.point)
                         < Scenario.coalition_setup.initial_dist_blue_to_frontline then
                            zone.side = coalition.side.BLUE
                        else
                            zone.side = coalition.side.RED
                        end
                    end
                end
                
                if zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                    local airbase = Airbase.getByName(zone.airbase_name)
                    if airbase then
                        airbase:autoCapture(false)
                        airbase:setCoalition(zone.side)
                    end
                end
            end
        end

        MissionLogger:info("Initializing zones (Pass 2: Setting Levels and Spawning Units)...")
        -- ### PASS 2: Assign Levels, Spawn Units, and Update Discovery ###
        for _, zone in ipairs(zones) do
            if not (zone.name == home_base.name or zone.name == red_base.name) then
                -- Now that all sides are set, this call is safe
                local _, dist = zone:getClosestZone(utils.getEnemyCoalition(zone.side), nil, nil, false)

                if not zone.level then
                    if dist and dist < Config.upgrade_tier_range then
                        zone.level = math.random(2,4)
                    else
                        zone.level = 1
                    end
                end
            end

            -- Update discovered list based on final side
            if zone.side == coalition.side.BLUE then
                if not utils.tableContains(stats.blue_discovered_zones, zone.name) then
                    table.insert(stats.blue_discovered_zones, zone.name)
                end
            elseif zone.side == coalition.side.RED then
                if not utils.tableContains(stats.red_discovered_zones, zone.name) then
                    table.insert(stats.red_discovered_zones, zone.name)
                end
            end



            -- Spawn units and statics
            UnitHandler.initZoneUnits(zone)
            UnitHandler.initStatics(zone)
        end

        -- makes all zones under MAX_GRND_RECON_DIST added to the discoverd var
        for _,zone in ipairs(zones) do
            for _, other_zone in ipairs(zones) do
                if zone.side ~= other_zone.side
                and mist.utils.get2DDist(zone.zone.point, other_zone.zone.point) < Config.max_ground_recon_range then

                    if not utils.tableContains(stats.blue_discovered_zones,other_zone.name) then
                    table.insert(stats.blue_discovered_zones,other_zone.name) end

                    if not utils.tableContains(stats.red_discovered_zones,other_zone.name) then
                    table.insert(stats.red_discovered_zones,other_zone.name) end
                end
            end
        end

        -- draw zones
        for _,zone in ipairs(zones) do
            zone:drawF10()
        end

        -- assign airbase warehouses
        WarehouseManager:handleIncomingSupplies(home_base.side,
            {WarehouseManager.StockTypes.INITIAL}  )
        
        -- Also assign initial supplies for the RED base
        WarehouseManager:handleIncomingSupplies(red_base.side,
            {WarehouseManager.StockTypes.INITIAL}  )

        return home_base, red_base
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

        
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.BLUE, timer.getTime() + stats.blue_resupply_time)
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.RED, timer.getTime() + stats.red_resupply_time)
        
        TheatreCommander:tick()
        
        EWRS_coalition = {
            [coalition.side.BLUE] = EWRS:new(coalition.side.BLUE),
            [coalition.side.RED] = EWRS:new(coalition.side.RED),
        }
        
        world.addEventHandler(ev)
        world.addEventHandler(ExperienceManager.EventHandler)
        world.addEventHandler(Jupiter)
        PersistanceManager:autoSave()

        local airb = ZoneHandler.getFromName("VAZIANI")
        local wh = Airbase.getByName(airb.airbase_name):getWarehouse():getInventory()
        MissionLogger:info("VAZIANI INV")
        MissionLogger:info(wh)


        -- trigger.action.outText("Theatre setup complete.", 5)
        MissionLogger:info("Mission Commander: Mission Setup Complete.")
    end

end