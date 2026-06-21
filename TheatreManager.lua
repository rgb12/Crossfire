local ticks = 15
local ticks1m = 0
local ticks5m = 0
TheatreCommander = {}
do

    ---@type OperationManager
    TheatreCommander.blue_op_manager = nil
    ---@type OperationManager
    TheatreCommander.red_op_manager = nil

    ---@param to_zone ZoneHandler
    ---@param side_sending_capture coalition.side
    function TheatreCommander.sendCapture(to_zone, side_sending_capture)
        if side_sending_capture == coalition.side.NEUTRAL then return end

        if not EraSystem.isHelicopterEraCapable() then return end

        -- Prevent multiple helis being sent to the same target from different source zones
        if EnrouteManager:findByToZone(to_zone, side_sending_capture, {AITaskTypes.CAPTURE_HELO}) then
            return
        end

        -- Capture Helicopter spawn

        timer.scheduleFunction(function ()
            local from_zone = utils.findClosestCaptureHeloSource(to_zone, side_sending_capture, Config.capture_helicopter_max_range)
            if not from_zone then return end

            if EnrouteManager:findByFromZone(from_zone, side_sending_capture, {AITaskTypes.CAPTURE_HELO}) then return end

            TaskManager:initiateAITask(AITaskTypes.CAPTURE_HELO, side_sending_capture, true, to_zone, from_zone, false)
        end,nil,timer.getTime()+math.random(10,30))
        
    end

    -- checks if a capture group has arrived
    --- func desc
    ---@param enroute_group EnrouteObj
    function TheatreCommander.checkIfCaptureGroupArrived(enroute_group)

        local zone_coal_check = ZoneHandler.getFromName(enroute_group.to_zone.name)
        if not zone_coal_check then return false end

        local helo_group = Group.getByName(enroute_group.group_name)
        if not helo_group or not helo_group:isExist() then return false end

        if enroute_group.ai_task_type == AITaskTypes.CAPTURE_HELO then
            if zone_coal_check.side ~= coalition.side.NEUTRAL then return false end

            MissionLogger:info("Heli captured zone: " .. enroute_group.to_zone.zone.name)
            EnrouteManager:remove(enroute_group.group_name)

            if enroute_group.side == coalition.side.RED then
                enroute_group.to_zone:capture(coalition.side.RED)
            elseif enroute_group.side == coalition.side.BLUE then
                enroute_group.to_zone:capture(coalition.side.BLUE)
            end
            return true
        end

        return false
    end

    ---@param zone ZoneHandler
    ---@return boolean
    function TheatreCommander.sendPotentialCapture(zone)
        if zone.side ~= coalition.side.NEUTRAL then return false end

        -- WW2 has no capture helos; captures are handled by ground convoys
        if not EraSystem.isHelicopterEraCapable() then return false end

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

    function TheatreCommander:tick_1m()
 MissionLogger:info("1 minute")

            local capture_helicopter_sent = false
            for _, zone in ipairs(zones) do

                    capture_helicopter_sent = TheatreCommander.sendPotentialCapture(zone)

                    zone:checkSUPPLIES()
                    zone:checkCOMMSZone()
                    zone:checkRunwayStatus()
                    zone:addAIAssets(5) -- Supply chance every minute

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

                    -- WW2 ground capture convoy: strongpoints send a convoy to the
                    -- nearest neutral zone in range to capture it (replaces capture helos).
                    if not EraSystem.isHelicopterEraCapable()
                    and math.random(1,100) <= Config.retry_capture_chance
                    and zone.zone_type == ZoneTypes.STRONGPOINT and zone.side ~= coalition.side.NEUTRAL
                    and zone.attack_convoy and zone.attack_convoy > 0
                    and #EnrouteManager:findByTaskType(AITaskTypes.CAPTURE_CONVOY, zone.side) < Config.tasking.max_capture_convoy_per_theatre
                    and not EnrouteManager:findByFromZone(zone, zone.side, {AITaskTypes.CAPTURE_CONVOY})
                    then
                        local target_zone, target_dist = zone:getClosestZone(coalition.side.NEUTRAL, nil, nil, true)
                        if target_zone and target_dist <= Config.capture_convoy_range
                        and not EnrouteManager:findByToZone(target_zone, nil, {AITaskTypes.CAPTURE_CONVOY, AITaskTypes.CAPTURE_HELO})
                        then
                            TaskManager:initiateAITask(AITaskTypes.CAPTURE_CONVOY, zone.side, true, target_zone, zone, false)
                        end
                    end

                    -- this spawns a reinforcement helicopter
                    if math.random(1,100) <= Config.reinforcement_chance and zone.zone_type == ZoneTypes.LOGISTICS
                    and zone.heli_avail > 0
                    and (#EnrouteManager:findByTaskType(AITaskTypes.REINFORCEMENT_HELO,zone.side)
                        + #EnrouteManager:findByTaskType(AITaskTypes.REINFORCEMENT_CONVOY,zone.side)) < 2
                    and not EnrouteManager:findByFromZone(zone,zone.side,{AITaskTypes.REINFORCEMENT_HELO, AITaskTypes.REINFORCEMENT_CONVOY, AITaskTypes.CAPTURE_HELO})
                    -- don't dispatch from a logistics zone that itself has a reinforcement/capture helo inbound
                    and not EnrouteManager:findByToZone(zone,zone.side,{AITaskTypes.REINFORCEMENT_HELO, AITaskTypes.REINFORCEMENT_CONVOY, AITaskTypes.CAPTURE_HELO})
                    then
                        -- candidate targets include other LOGISTICS zones (any friendly discovered zone below tier 4)
                        local zones_to_upgrade = zone:filterZonesByDistance(zone.side,{},{},true)
                        local zone_to_upgrade = nil
                        if #zones_to_upgrade > 0 then
                            local max_dist_to_frontline = Config.operations.reinforcement_max_distance_to_frontline or math.huge
                            for _,zone_t_u in ipairs(zones_to_upgrade) do
                                if zone_t_u.level < 4
                                and Frontline.distanceToFrontline(zone_t_u.zone.point) <= max_dist_to_frontline
                                and not EnrouteManager:findByToZone(zone_t_u,zone.side,{AITaskTypes.REINFORCEMENT_HELO, AITaskTypes.REINFORCEMENT_CONVOY, AITaskTypes.CAPTURE_HELO}) then
                                    zone_to_upgrade = zone_t_u
                                    break
                                end
                            end
                        end

                        if zone_to_upgrade then
                            TaskManager:initiateAITask(AITaskTypes.REINFORCEMENT_HELO,zone.side,true,zone_to_upgrade,zone,false)
                        end
                    end
                    
                end
            EnrouteManager:checkEnroutes()
            ctld.monitorFARPDestruction()

            Frontline.drawFrontline()
    end

    function TheatreCommander:tick_5m()
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

    function TheatreCommander:tick_10m()
        MissionLogger:info("10 mins")
        TheatreCommander:smokeFrontline()
    end

    function TheatreCommander:tick_15s(loop)
        if loop then
            timer.scheduleFunction(function ()
                self:tick_15s(true)
            end, {}, timer.getTime() + 15)

            -- update every minute
            if ticks % 60 == 0 then
                ticks1m = ticks1m + 1
                self:tick_1m()
        
                if ticks1m % 5 == 0 then
                    ticks5m = ticks5m + 1
                    self:tick_5m()
                end

                if ticks1m % 10 == 0 then
                    self:tick_10m()
                end
            end
        
            ticks = ticks + 15
        end

        if TheatreCommander.blue_op_manager then
            TheatreCommander.blue_op_manager:tick()
        end
        if TheatreCommander.red_op_manager then
            TheatreCommander.red_op_manager:tick()
        end

        TaskManager:checkTankerSectors()
        
        for i = #EnrouteManager.enroutes, 1, -1 do
            local enroute = EnrouteManager.enroutes[i]
            if enroute then -- Check if enroute object is valid

                if enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)

                    if not convoy_group or not convoy_group:isExist() then
                        -- Convoy destroyed
                        trigger.action.outTextForCoalition(enroute.side, "Convoy sent to attack " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager.enroutes[i] = nil
                    else
                        -- Destination captured by friendly side (or gone neutral): stand down
                        local zone_coal_check = ZoneHandler.getFromName(enroute.to_zone.name)
                        if zone_coal_check and (zone_coal_check.side == enroute.side or zone_coal_check.side == coalition.side.NEUTRAL) then
                            MissionLogger:info("Attack convoy destination captured by friendly side, removing: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                        else
                            local convoy_pos = mist.getLeadPos(convoy_group)
                            if convoy_pos and enroute.to_zone:isPointInsideZone(convoy_pos) then
                                -- Arrived in the zone: the convoy now engages via its FireAtPoint task.
                                -- Mission is complete once no enemies remain to engage.
                                enroute.stuck_since = nil
                                local enemy_units = utils.getUnitsInZoneObj(enroute.to_zone, utils.getEnemyCoalition(enroute.side))
                                if not enemy_units or #enemy_units == 0 then
                                    trigger.action.outTextForCoalition(enroute.side, "Attack convoy sent to " .. enroute.to_zone.zone.name .. " has completed its mission", 10)
                                    EnrouteManager.enroutes[i] = nil
                                    timer.scheduleFunction(function ()
                                        if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                                    end, {}, timer.getTime() + math.random(50, 60))
                                end
                            elseif not UnitHandler.checkConvoyMoving(convoy_group) then
                                -- Stuck en route (not in zone, not moving): time it out
                                if not enroute.stuck_since then
                                    enroute.stuck_since = timer.getTime()
                                    MissionLogger:info("Attack convoy " .. enroute.group_name .. " detected as stuck en route, starting timer.")
                                elseif (timer.getTime() - enroute.stuck_since) > Config.stuck_convoy_timeout then
                                    trigger.action.outTextForCoalition(enroute.side, "Attack convoy to " .. enroute.to_zone.zone.name .. " got stuck en route and was removed.", 10)
                                    convoy_group:destroy()
                                    EnrouteManager.enroutes[i] = nil
                                end
                            else
                                enroute.stuck_since = nil
                            end
                        end
                    end
                elseif enroute.ai_task_type == AITaskTypes.CAPTURE_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)

                    if not convoy_group or not convoy_group:isExist() then
                        -- Convoy destroyed enroute
                        trigger.action.outTextForCoalition(enroute.side, "Capture convoy sent to " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager.enroutes[i] = nil
                    else
                        local zone_coal_check = ZoneHandler.getFromName(enroute.to_zone.name)
                        if not zone_coal_check or zone_coal_check.side ~= coalition.side.NEUTRAL then
                            -- Target no longer neutral (captured/lost by someone else): stand down
                            MissionLogger:info("Capture convoy target no longer neutral, removing: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            timer.scheduleFunction(function ()
                                if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                            end, {}, timer.getTime() + math.random(5, 10))
                        else
                            local convoy_pos = mist.getLeadPos(convoy_group)
                            if convoy_pos and enroute.to_zone:isPointInsideZone(convoy_pos) then
                                -- Arrived inside the neutral zone: capture it
                                MissionLogger:info(utils.coalitionToString(enroute.side) .. " capture convoy captured zone: " .. enroute.to_zone.zone.name)
                                enroute.to_zone:capture(enroute.side)
                                EnrouteManager.enroutes[i] = nil
                                timer.scheduleFunction(function ()
                                    if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                                end, {}, timer.getTime() + math.random(10, 20))
                            elseif not UnitHandler.checkConvoyMoving(convoy_group) then
                                -- Stuck enroute: time it out (mirrors attack convoy)
                                if not enroute.stuck_since then
                                    enroute.stuck_since = timer.getTime()
                                elseif (timer.getTime() - enroute.stuck_since) > Config.stuck_convoy_timeout then
                                    trigger.action.outTextForCoalition(enroute.side, "Capture convoy to " .. enroute.to_zone.zone.name .. " got stuck en route and was removed.", 10)
                                    convoy_group:destroy()
                                    EnrouteManager.enroutes[i] = nil
                                end
                            else
                                enroute.stuck_since = nil
                            end
                        end
                    end
                elseif enroute.ai_task_type == AITaskTypes.REINFORCEMENT_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)

                    if not convoy_group or not convoy_group:isExist() then
                        -- Convoy destroyed enroute
                        trigger.action.outTextForCoalition(enroute.side, "Reinforcement convoy sent to " .. enroute.to_zone.zone.name .. " has been destroyed", 10)
                        EnrouteManager.enroutes[i] = nil
                    else
                        local zone_coal_check = ZoneHandler.getFromName(enroute.to_zone.name)
                        if not zone_coal_check or zone_coal_check.side ~= enroute.side then
                            -- Target no longer friendly (lost to the enemy): stand down
                            MissionLogger:info("Reinforcement convoy target no longer friendly, removing: " .. enroute.group_name)
                            EnrouteManager.enroutes[i] = nil
                            timer.scheduleFunction(function ()
                                if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                            end, {}, timer.getTime() + math.random(5, 10))
                        else
                            local convoy_pos = mist.getLeadPos(convoy_group)
                            if convoy_pos and enroute.to_zone:isPointInsideZone(convoy_pos) then
                                -- Arrived inside the friendly zone: bump its tier
                                if (zone_coal_check.level or 1) < 4 then
                                    zone_coal_check.level = (zone_coal_check.level or 1) + 1
                                    UnitHandler.updateZoneUnits(zone_coal_check)
                                    zone_coal_check:drawF10()
                                    trigger.action.outTextForCoalition(enroute.side,
                                        string.format("SITREP: %s has reached operational tier %d/4 ", zone_coal_check.name, zone_coal_check.level), 10)
                                    trigger.action.outSoundForCoalition(enroute.side, "radio_beep3.ogg")
                                end
                                MissionLogger:info(utils.coalitionToString(enroute.side) .. " reinforcement convoy reinforced zone: " .. enroute.to_zone.zone.name)
                                EnrouteManager.enroutes[i] = nil
                                timer.scheduleFunction(function ()
                                    if convoy_group and convoy_group:isExist() then convoy_group:destroy() end
                                end, {}, timer.getTime() + math.random(10, 20))
                            elseif not UnitHandler.checkConvoyMoving(convoy_group) then
                                -- Stuck enroute: time it out (mirrors capture convoy)
                                if not enroute.stuck_since then
                                    enroute.stuck_since = timer.getTime()
                                elseif (timer.getTime() - enroute.stuck_since) > Config.stuck_convoy_timeout then
                                    trigger.action.outTextForCoalition(enroute.side, "Reinforcement convoy to " .. enroute.to_zone.zone.name .. " got stuck en route and was removed.", 10)
                                    convoy_group:destroy()
                                    EnrouteManager.enroutes[i] = nil
                                end
                            else
                                enroute.stuck_since = nil
                            end
                        end
                    end
                elseif enroute.ai_task_type == AITaskTypes.RECON then

                    local recon_gr = Group.getByName(enroute.group_name)
                    if recon_gr and recon_gr:isExist() then

                        local side_op_manager = (enroute.side == coalition.side.BLUE)
                            and TheatreCommander.blue_op_manager or TheatreCommander.red_op_manager
                        local player_recon_active = side_op_manager
                            and side_op_manager:hasActiveReconOnZone(enroute.to_zone.name)

                        local pos = mist.getLeadPos(recon_gr)
                        if not player_recon_active and pos and mist.utils.get2DDist(pos, enroute.to_zone.zone.point) <= Config.tasking.range_for_recon_to_discover_zone then
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

        EnrouteManager:checkAiHeloLandings()
    end

    -- This function starts the tick loop
    function TheatreCommander:tick()
        if MISSION_ENDED == true then return end
          
    
        timer.scheduleFunction(function ()
            self:tick_15s(true)
        end, {}, timer.getTime() + 15)
    end

    function TheatreCommander:restartMission()
        trigger.action.setUserFlag("MISSIONEND",10)
    end

    function TheatreCommander:initMOTD()
        if not Config.motd.enable then return end

        local function sendMessage(loop)
            trigger.action.outText(Config.motd.message, Config.motd.display_time)
            if loop then
                timer.scheduleFunction(function ()
                    sendMessage(true)
                end, {}, timer.getTime() + Config.motd.period)
            end
        end

        if Config.motd.period <= 0 then
            sendMessage(false)
            return
        end 
        sendMessage(true)
    end

    ---@param side coalition.side
    ---@param repeat_tasking boolean|nil
    ---@param stock_types StockTypes[]|nil
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


        if not EraSystem.isAirResupplyEraCapable() then
            local allowed_stock_types = mist.utils.deepCopy(stock_types)

            if EraSystem.getActiveEra() == Eras.WW2 then
                allowed_stock_types = {
                    StockTypes.AA_AIRCRAFT,
                    StockTypes.AG_AIRCRAFT,
                    StockTypes.AIR_GROUND_BOMBS,
                    StockTypes.AIR_GROUND_ROCKETS
                }
            end

            local airbase_pool = (side == coalition.side.BLUE) and blue_airbases or red_airbases
            destination_airbase = target_airbase or (airbase_pool[1] and airbase_pool[math.random(#airbase_pool)])
            if destination_airbase and destination_airbase.side == side and destination_airbase.airbase_name then
                UnitHandler.simulateResupply(nil, destination_airbase.airbase_name, side, {allowed_stock_types[math.random(1, #allowed_stock_types)]})
            end
            if repeat_tasking then
                timer.scheduleFunction(function ()
                    TheatreCommander.sendWarehouseResupply(side, true, {allowed_stock_types[math.random(1, #allowed_stock_types)]})
                end, nil, timer.getTime() + Config.std_resupply_time)
            end
            return
        end

        if side == coalition.side.BLUE and scenario.resupply.blue_point then
            if #blue_airbases == 0 then return end
            destination_airbase = target_airbase or blue_airbases[math.random(#blue_airbases)]

            if not destination_airbase or destination_airbase.side ~= side then
                return MissionLogger:warn("Invalid BLUE resupply destination airbase")
            end
            cargo_sent_table = mist.teleportToPoint({
                groupName = EraSystem.resolveTaskTemplateName(GroupData.COMMON_ASSETS.BLUE.resupply_aircraft),
                point = scenario.resupply.blue_point,
                action = "clone",
                radius = 10000
            })
            if not cargo_sent_table or not cargo_sent_table.name then return MissionLogger:error("Could not send BLUE resupply.") end
            new_group_name = cargo_sent_table.name

        elseif side == coalition.side.RED and scenario.resupply.red_point then
            if #red_airbases == 0 then return end
            destination_airbase = target_airbase or red_airbases[math.random(#red_airbases)]

            if not destination_airbase or destination_airbase.side ~= side then
                return MissionLogger:warn("Invalid RED resupply destination airbase")
            end
            cargo_sent_table = mist.teleportToPoint({
                groupName = EraSystem.resolveTaskTemplateName(GroupData.COMMON_ASSETS.RED.resupply_aircraft),
                point = scenario.resupply.red_point,
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
    
    
    -- AI DISPATCHER moved to AICommander.lua (AICommander.dispatchAI / evaluateAITasks)

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
                x = closest_zone.zone.point.x  + math.random(-variance, variance),
                y = closest_zone.zone.point.z  + math.random(-variance, variance)
            }
            table.insert(smoke_points, mist.utils.makeVec3GL(point))
        end
        
        for _, point in ipairs(smoke_points) do
            smoke_id = smoke_id + 1
            local smoke_string = "TheatreSmoke" .. smoke_id
            local duration = math.random(8*60, 16*60) -- 8-16 minutes
            trigger.action.effectSmokeBig(point,math.random(5,8),1,smoke_string)

                timer.scheduleFunction(function ()
                    trigger.action.effectSmokeStop(smoke_string)
                end, nil, timer.getTime() + duration)
            end
            MissionLogger:info("Added smokes near frontline")
        end
    end

    ---@return ZoneHandler|nil, ZoneHandler|nil
    function TheatreCommander.establishTheatre()
        MissionLogger:info("Starting theatre establishment process...")

        -- Deterministic PRNG for zone assignments when a seed is provided.

        local use_deterministic_rng = Config.theatre.seed ~= -1
        local prng_seed = Config.theatre.seed or 0
        local function prng_next()
            -- 32-bit LCG (constants from Numerical Recipes)
            prng_seed = (1664525 * prng_seed + 1013904223) % 4294967296
            return prng_seed / 4294967296
        end
        local function rng_int(a,b)
            if not a then a = 0 end
            if not b then b = 1 end
            if use_deterministic_rng then
                return math.floor(prng_next() * (b - a + 1)) + a
            else
                return math.random(a,b)
            end
        end
        local function rng_shuffle(t)
            if use_deterministic_rng then
                for i = #t, 2, -1 do
                    local j = rng_int(1, i)
                    t[i], t[j] = t[j], t[i]
                end
            else
                utils.shuffleTable(t)
            end
        end

        local current_theatre = PersistenceManager:fetchTheatre()

        local eligible_scenarios = {}
        for _, scenario in ipairs(scenarios) do
            if scenario.theater == current_theatre then
                table.insert(eligible_scenarios, scenario)
            end
        end

        if #eligible_scenarios == 0 then
            trigger.action.outText("CRITICAL MISSION ERROR: No eligible scenarios found for theatre: " .. tostring(current_theatre), 30)
            env.error("CRITICAL MISSION ERROR: No eligible scenarios found for theatre: " .. tostring(current_theatre),true)
            return 
        end
        
        
        -- Fetch the available zones for this theatre
        ---@type ZoneHandler[]
        local theatre_zones = available_zones[current_theatre]
        
        if not theatre_zones then
            trigger.action.outText("CRITICAL MISSION ERROR: No available zones defined for theatre: " .. tostring(current_theatre), 30)
            env.error("CRITICAL MISSION ERROR: No available zones defined for theatre: " .. tostring(current_theatre),true)
            return
        end

        -- Pick a random scenario from the eligible list
        ---@type GeneratedScenario
        scenario = eligible_scenarios[rng_int(1, #eligible_scenarios)]

        
        local theatre_config = scenario.map_setup

        MissionLogger:info("Selected scenario: " .. scenario.name)
        MissionLogger:info(scenario.blue_airbase .. " (BLUE), " .. scenario.red_airbase .. " (RED)")

        -- All zones except home airbases
        ---@type ZoneHandler[]
        local all_other_zones = {}

        for _, zone in ipairs(theatre_zones) do
            
            if zone.name == scenario.blue_airbase then
                blue_airbase = zone
            elseif zone.name == scenario.red_airbase then
                red_airbase = zone
            else
                if not zone.side then zone.side = coalition.side.NEUTRAL end
                table.insert(all_other_zones, zone)
            end
        end

        blue_airbase.side = coalition.side.BLUE
        blue_airbase.level = 4
        red_airbase.side = coalition.side.RED
        red_airbase.level = 4

        if not (blue_airbase and red_airbase) then
            trigger.action.outText("CRITICAL MISSION ERROR: blue_airbase and/or red_airbase not defined in config for theater: " .. tostring(current_theatre), 30)
            env.error("CRITICAL MISSION ERROR: blue_airbase and/or red_airbase not defined in config for theater: " .. tostring(current_theatre),true)
            return
        end
        MissionLogger:info("BLUE and RED AIRBASES identified: " .. blue_airbase.name .. " (BLUE), " .. red_airbase.name .. " (RED)")

        local blue_x = blue_airbase.zone.point.x
        local blue_z = blue_airbase.zone.point.z
        local red_x = red_airbase.zone.point.x
        local red_z = red_airbase.zone.point.z

        local distance_main = math.sqrt((blue_x - red_x)^2 + (blue_z - red_z)^2)

        local width_factor = theatre_config.width_factor or 1.3 -- legacy parameter
        local max_allowed_sum = distance_main * width_factor
        local corridor_half_width_frac = theatre_config.corridor_half_width  or 0.20
        local corridor_half_width = distance_main * corridor_half_width_frac
        local airbase_padding = theatre_config.airbase_influence or 20000

        ---@type ZoneHandler[]
        local active_zones = {}

        for _, zone in ipairs(all_other_zones) do
            local zx = zone.zone.point.x
            local zz = zone.zone.point.z

            local dist_to_blue = mist.utils.get2DDist(zone.zone.point, blue_airbase.zone.point)
            local dist_to_red = mist.utils.get2DDist(zone.zone.point, red_airbase.zone.point)

            -- If zone is within airbase padding of either home airbase, include it unconditionally
            if dist_to_blue <= airbase_padding or dist_to_red <= airbase_padding then
                table.insert(active_zones, zone)
            else
                -- Compute perpendicular distance to the line between airbases
                local dx = red_x - blue_x
                local dz = red_z - blue_z
                local len = distance_main
                if len == 0 then len = 1 end
                local vx = zx - blue_x
                local vz = zz - blue_z
                -- projection along the line (0..1 between blue and red)
                local proj = (vx * dx + vz * dz) / (len * len)
                -- perpendicular distance from point to line (meters)
                local perp = math.abs(dx * vz - dz * vx) / len

                -- Reduce endpoint margin to avoid including distant clusters beyond the bases
                local end_margin = 0.05

                -- Prefer strict perpendicular corridor check for normal/large maps.
                -- For very small maps (short airbase separation) fall back to legacy ellipse.
                local use_ellipse_fallback = distance_main < 50000 -- meters (50 km)

                if use_ellipse_fallback then
                    if (dist_to_blue + dist_to_red) <= max_allowed_sum then
                        table.insert(active_zones, zone)
                    end
                else
                    if (proj >= -end_margin and proj <= 1 + end_margin and perp <= corridor_half_width) then
                        table.insert(active_zones, zone)
                    end
                end
            end
        end

        MissionLogger:info(string.format("Elliptical Corridor selection complete. %d zones activated out of %d.", #active_zones, #all_other_zones))
        MissionLogger:info("Assigning coalitions based on distance to frontline...")

        -- Coalition Assignment via Radial Frontline
        local frontline_distribution = theatre_config.red_distribution or 0.75
        local frontline_radius = distance_main * frontline_distribution
        MissionLogger:info(string.format("Frontline radius set to %.1f%% of main airbase distance: %.0f meters", frontline_distribution*100, frontline_radius))

        stats.blue_zones = 1 -- counting the blue airbase
        stats.red_zones = 1 -- counting the red airbase
        ---@type ZoneHandler[]
        local blue_pool = {}
        ---@type ZoneHandler[]
        local red_pool = {}

        for _, zone in ipairs(active_zones) do
            local dist_to_red = mist.utils.get2DDist(zone.zone.point, red_airbase.zone.point)
            local dist_to_blue = mist.utils.get2DDist(zone.zone.point, blue_airbase.zone.point)

            -- Priority: if zone is within airbase padding of a home airbase,
            -- force it to that coalition. Otherwise use the frontline radius.
            if dist_to_blue <= airbase_padding then
                zone.side = coalition.side.BLUE
                stats.blue_zones = stats.blue_zones + 1
                if not zone.zone_type then table.insert(blue_pool, zone) end

            elseif dist_to_red <= airbase_padding then
                zone.side = coalition.side.RED
                stats.red_zones = stats.red_zones + 1
                if not zone.zone_type then table.insert(red_pool, zone) end

            elseif dist_to_red <= frontline_radius then
                zone.side = coalition.side.RED
                stats.red_zones = stats.red_zones + 1
                if not zone.zone_type then table.insert(red_pool, zone) end

            else
                zone.side = coalition.side.BLUE
                stats.blue_zones = stats.blue_zones + 1
                if not zone.zone_type then table.insert(blue_pool, zone) end
            end
        end

        -- Assign zone types (Logistics & Randoms)
        local function assignTypesToPool(pool, home)
            if #pool == 0 then return end

            -- Per-era zone-type blacklist (see Config.era_system.disable_zone_types_for_era).
            -- Disallowed zone types are never generated and fall back to STRONGPOINT.
            local allow_sam_sites = EraSystem.isZoneTypeAllowed(ZoneTypes.SAMSITE)
            local allow_ew_sites  = EraSystem.isZoneTypeAllowed(ZoneTypes.EWSITE)
            local allow_farp      = EraSystem.isZoneTypeAllowed(ZoneTypes.FARP)
            local allow_comms     = EraSystem.isZoneTypeAllowed(ZoneTypes.COMMS)
            local allow_logistics = EraSystem.isZoneTypeAllowed(ZoneTypes.LOGISTICS)

            -- Find unassigned zones first to calculate budgets correctly
            ---@type ZoneHandler[]
            local unassigned = {}
            for _, z in ipairs(pool) do
                if z.zone_type == nil then
                    table.insert(unassigned, z)
                end
            end
            
            if #unassigned == 0 then return end -- All zones already have types assigned
            
            -- Shuffle for randomness (use deterministic shuffle if seeded)
            rng_shuffle(unassigned)
            
            -- Guarantee at least 1 of each zone type (if enough zones available)
            local idx = 1
            local assigned_guaranteed = 0
            
            -- COMMS (guaranteed)
            if idx <= #unassigned then
                if allow_comms then
                    unassigned[idx].zone_type = ZoneTypes.COMMS
                else
                    unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                    unassigned[idx].attack_convoy = Config.base_convoy_count
                end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end

            -- LOGISTICS (guaranteed)
            if idx <= #unassigned then
                if allow_logistics then
                    unassigned[idx].zone_type = ZoneTypes.LOGISTICS
                    unassigned[idx].heli_avail = 4
                else
                    unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                    unassigned[idx].attack_convoy = Config.base_convoy_count
                end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end

            -- FARP (guaranteed)
            if idx <= #unassigned then
                if allow_farp then
                    unassigned[idx].zone_type = ZoneTypes.FARP
                else
                    unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                    unassigned[idx].attack_convoy = Config.base_convoy_count
                end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end

            -- SAMSITE (guaranteed)
            if idx <= #unassigned then
                if allow_sam_sites then
                    unassigned[idx].zone_type = ZoneTypes.SAMSITE
                    local r = rng_int(1, 100)
                    if r < Config.theatre.sam_classification_thresholds.short_range then unassigned[idx].sam_classification = SAM_TYPES.SHORT_RANGE
                    elseif r < Config.theatre.sam_classification_thresholds.medium_range then unassigned[idx].sam_classification = SAM_TYPES.MEDIUM_RANGE
                    else unassigned[idx].sam_classification = SAM_TYPES.LONG_RANGE end
                else
                    unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                    unassigned[idx].attack_convoy = Config.base_convoy_count
                end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end

            -- EWSITE (guaranteed)
            if idx <= #unassigned then
                if allow_ew_sites then
                    unassigned[idx].zone_type = ZoneTypes.EWSITE
                else
                    unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                    unassigned[idx].attack_convoy = Config.base_convoy_count
                end
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- STRONGPOINT (guaranteed)
            if idx <= #unassigned then
                unassigned[idx].zone_type = ZoneTypes.STRONGPOINT
                unassigned[idx].attack_convoy = Config.base_convoy_count
                idx = idx + 1
                assigned_guaranteed = assigned_guaranteed + 1
            end
            
            -- Now handle remaining zones with weighted budgets
            local remaining_zones = #unassigned - assigned_guaranteed
            
            if remaining_zones > 0 then
                local weights = Config.theatre.zone_type_weights
                local total_w = 0
                for _, w in pairs(weights) do total_w = total_w + w end
                
                -- Calculate budgets for remaining zones only. Era-blacklisted zone
                -- types get a zero budget so their share falls through to STRONGPOINT.
                local budget_logistics = allow_logistics and math.ceil((weights[ZoneTypes.LOGISTICS]/total_w) * remaining_zones) or 0
                local budget_farp      = allow_farp and math.ceil((weights[ZoneTypes.FARP]/total_w) * remaining_zones) or 0
                local budget_sam       = allow_sam_sites and math.ceil((weights[ZoneTypes.SAMSITE]/total_w) * remaining_zones) or 0
                local budget_comms     = allow_comms and math.ceil((weights[ZoneTypes.COMMS]/total_w) * remaining_zones) or 0
                local budget_ew        = allow_ew_sites and math.ceil((weights[ZoneTypes.EWSITE]/total_w) * remaining_zones) or 0
                
                local pre_assigned_count = #pool - #unassigned
                MissionLogger:info("Assigning Types for " .. utils.coalitionToString(home.side) .. ". Total Zones: " .. #pool ..
                    " (Pre-assigned: " .. pre_assigned_count .. ", Guaranteed: " .. assigned_guaranteed .. ", Remaining: " .. remaining_zones .. ")" ..
                    " | Logistics: " .. budget_logistics .. ", FARP: " .. budget_farp .. ", SAM: " .. budget_sam .. ", COMMS: " .. budget_comms .. ", EW: " .. budget_ew)

                -- Assign remaining zones using budgets
                for i = idx, #unassigned do
                    local zone = unassigned[i]
                    
                    if budget_comms > 0 then
                        zone.zone_type = ZoneTypes.COMMS
                        budget_comms = budget_comms - 1
                    elseif budget_logistics > 0 then
                        zone.zone_type = ZoneTypes.LOGISTICS
                        zone.heli_avail = 4
                        budget_logistics = budget_logistics - 1
                    elseif budget_farp > 0 then
                        zone.zone_type = ZoneTypes.FARP
                        budget_farp = budget_farp - 1
                    elseif budget_ew > 0 then
                        zone.zone_type = ZoneTypes.EWSITE
                        budget_ew = budget_ew - 1
                    elseif budget_sam > 0 then
                        zone.zone_type = ZoneTypes.SAMSITE
                        local r = rng_int(1, 100)
                        if r < Config.theatre.sam_classification_thresholds.short_range then zone.sam_classification = SAM_TYPES.SHORT_RANGE
                        elseif r < Config.theatre.sam_classification_thresholds.medium_range then zone.sam_classification = SAM_TYPES.MEDIUM_RANGE
                        else zone.sam_classification = SAM_TYPES.LONG_RANGE end
                        budget_sam = budget_sam - 1
                    else
                        zone.zone_type = ZoneTypes.STRONGPOINT
                        zone.attack_convoy = rng_int(0,1)
                    end
                end
            else
                local pre_assigned_count = #pool - #unassigned
                MissionLogger:info("Assigning Types for " .. utils.coalitionToString(home.side) .. " Pool. Total Zones: " .. #pool ..
                    " (Pre-assigned: " .. pre_assigned_count .. ", Guaranteed: " .. assigned_guaranteed .. ", Remaining: 0)")
            end
        end

        MissionLogger:info("Processing Blue Pool...")
        assignTypesToPool(blue_pool, blue_airbase)
        MissionLogger:info("Processing Red Pool...")
        assignTypesToPool(red_pool, red_airbase)

        zones = mist.utils.deepCopy(active_zones)
        table.insert(zones, blue_airbase)
        table.insert(zones, red_airbase)


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
                if dist and dist < 50000 then
                    local rnd = rng_int(1,100)
                    if rnd > 90 then
                        zone.level = 4
                    elseif rnd > 75 then
                        zone.level = 3
                    else
                        zone.level = 2
                    end
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

            -- Makes all airbases visible
            if zone.zone_type == ZoneTypes.AIRBASE then
                if not utils.tableContains(stats.blue_discovered_zones, zone.name) then
                    table.insert(stats.blue_discovered_zones, zone.name)
                end
                if not utils.tableContains(stats.red_discovered_zones, zone.name) then
                    table.insert(stats.red_discovered_zones, zone.name)
                end
            end

            -- Initial supply stock
            if zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP then
                zone.local_supplies = Config.supplies.initial_stock
            end

            -- Spawn
            UnitHandler.initZoneUnits(zone)
            UnitHandler.initStatics(zone)
            UnitHandler.initFARP(zone,true)
            zone:drawF10()
        end

        -- Update Ground Recon
        for _, zone in ipairs(zones) do
            zone:updateDiscoveredZones()
        end

        -- Initial Warehouses
        WarehouseManager:handleIncomingSupplies(blue_airbase.side, {StockTypes.INITIAL})

        WarehouseManager:handleIncomingSupplies(red_airbase.side, {StockTypes.INITIAL})

        -- Carrier warehouse
        if Config.carrier_setup then
            if Config.carrier_setup.enabled
            and Config.carrier_setup.carrier_unit_name then
                WarehouseManager:attributeAirbaseStock(Config.carrier_setup.carrier_unit_name, coalition.side.BLUE, {StockTypes.CARRIER_INITAL})
                ---@type table
                local carrier_setup = Config.carrier_setup
                carrier_setup.name = carrier_setup.carrier_unit_name
                carrier_setup.side = coalition.side.BLUE
                carrier_setup.zone_type = ZoneTypes.LOGISTICS
                carrier_setup.ammo_depot_intact = true
                carrier_setup.heli_avail = carrier_setup.heli_avail or Config.tasking.max_capture_helicopters_per_logistics_zone
                carrier_setup.local_supplies = carrier_setup.local_supplies or (Config.supplies and Config.supplies.initial_stock or 0)
            end
        end

        if Config.lha_setup then
            if Config.lha_setup.enabled
            and Config.lha_setup.lha_unit_name then
                ---@type LHASetup
                local lha_setup = Config.lha_setup
                MissionLogger:info("Attempting LHA restock")
                WarehouseManager:attributeAirbaseStock(Config.lha_setup.lha_unit_name, coalition.side.BLUE, {StockTypes.FARP,StockTypes.FARP,StockTypes.FARP})
                lha_setup.name = lha_setup.lha_unit_name
                lha_setup.side = coalition.side.BLUE
                lha_setup.zone_type = ZoneTypes.LOGISTICS
                lha_setup.ammo_depot_intact = true
                lha_setup.heli_avail = lha_setup.heli_avail or Config.tasking.max_capture_helicopters_per_logistics_zone
                lha_setup.local_supplies = lha_setup.local_supplies or (Config.supplies and Config.supplies.initial_stock or 0)
            end
        end
        UnitHandler.carrierCheck()

        return blue_airbase, red_airbase
    end

    function TheatreCommander.startMission()
        MissionLogger:info("Starting Mission Setup...")

        -- Establish the theatre and get home airbases

        if not PersistenceManager:fetchTheatre() then
            return trigger.action.outText("CRITICAL MISSION ERROR: this terrain is not supported.", 60)
        end

        if Config._enable_external_config then
            PersistenceManager:loadUserOverrides()
        end

        UnitHandler.validateGroupTemplates()

        UnitHandler.checkCarrierEra()
        UnitHandler.checkLHAEra()
        world.addEventHandler(ev)
        local persistence_enabled = PersistenceManager:isEnabled()

        if persistence_enabled and PersistenceManager:loadUserData() and PersistenceManager:loadFromFile() then
            if not PersistenceManager:restoreState()then
                MissionLogger:error("Failed to restore state. Establishing new theatre.")
                trigger.action.outText("Failed to restore state. Establishing new theatre. Check logs",60)
                TheatreCommander.establishTheatre()
            end
        else
            MissionLogger:info("No save file found. Establishing new theatre.")
            TheatreCommander.establishTheatre()
        end
        
        if not (blue_airbase and red_airbase) then
            return trigger.action.outText("ERROR: Mission theatre setup failed. Check logs (dcs.log) and config.", 30)
        end


        TheatreCommander.checkAirbasesCoalition()

        -- Create Operation Managers for each coalition
        TheatreCommander.blue_op_manager = OperationManager:new(coalition.side.BLUE, blue_airbase)
        TheatreCommander.red_op_manager = OperationManager:new(coalition.side.RED, red_airbase)


        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.BLUE, timer.getTime() + Config.std_resupply_time)
        timer.scheduleFunction(TheatreCommander.sendWarehouseResupply, coalition.side.RED, timer.getTime() + Config.std_resupply_time)

        ATIS:init()
        TheatreCommander:tick()

        -- AI DISPATCHER + AI COMMANDER (both owned by AICommander.lua)
        if AICommander and AICommander.init then
            AICommander.init()
        else
            MissionLogger:error("AICommander not loaded; AI dispatcher will not run. Add AICommander.lua to the mission.")
        end

        TheatreCommander:initMOTD()

        EWRS_coalition = {
            [coalition.side.BLUE] = EWRS:new(coalition.side.BLUE),
            [coalition.side.RED] = EWRS:new(coalition.side.RED),
        }

        world.addEventHandler(ExperienceManager.EventHandler)

        if Config.jupiter_enabled then
            world.addEventHandler(Jupiter)
        end

        Frontline.drawFrontline()

        -- trigger.action.outText("Theatre setup complete.", 5)
        MissionLogger:info("THEATRE SETUP COMPLETE")
        timer.scheduleFunction(function()
            if persistence_enabled then
                PersistenceManager:saveMissionToFile()
                PersistenceManager:saveUserDataToFile()
                PersistenceManager:autoSave()
                trigger.action.outText("Persistence enabled.",30)
            end
        end, {}, timer.getTime() + 3)
    end

end