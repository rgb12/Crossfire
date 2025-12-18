ev = {}
function ev:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition then

       

            -- Check if the spawned unit is a radar
            if unit:hasAttribute("SAM SR") or unit:hasAttribute("EWR") or unit:hasAttribute("AWACS") then
                local side = unit:getCoalition()
                if EWRS_coalition[side] then
                    table.insert(EWRS_coalition[side].radars, unit)
                    MissionLogger:info("EWRS: Added new radar unit " .. unit:getName() .. " to cache.")
                end
            end
        end
    end

    if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition and unit.isExist
        and unit:isExist() and unit.getPlayerName then

            local unit_coalition = unit:getCoalition()

            -- Checks if the player has the rigt to spawn in the airbase
            for _,zone in ipairs(zones) do
                if zone:isPointInsideZone(unit:getPoint()) then

                    -- checks if aircraft/helicopter in airbase or farp stock
                    local can_spawn = false
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
                                MissionLogger:info(warehouse:getInventory())
                                if warehouse then
                                    local acft_count = warehouse:getItemCount(acft_name)
                                    if acft_count > 0 then
                                        can_spawn = true
                                        
                                        if acft_name == WarehouseManager.AircraftFlags.C130J_30 or
                                        zone.zone_type == ZoneTypes.FARP then
                                            warehouse:removeItem(acft_name,1)
                                        end

                                    else
                                        can_spawn = false
                                        warehouse:addItem(acft_name,1)
                                    end
                                end
                            end
                        end

                    end

                    if zone.side ~= unit_coalition then
                        can_spawn = false
                    end
                    if zone.zone_type ~= ZoneTypes.AIRBASE and zone.zone_type~=ZoneTypes.FARP then
                        can_spawn = false
                    end

                    MissionLogger:info("Player "..unit:getPlayerName().." spawned in zone "..zone.name..". Can spawn: "..tostring(can_spawn))
                    if not can_spawn then

                        -- not allowed, destroy the unit
                        local unit_id = unit:getID()
                        trigger.action.outSoundForUnit(unit_id, "error.ogg")
                        trigger.action.outTextForUnit(unit_id, "****************\n\nThis slot is not allowed! Consult F10 map and warehouse stocks.\n\n****************", 20)
                        timer.scheduleFunction(function ()
                            if unit and unit:isExist() then
                                unit:destroy()
                            end
                        end, {}, timer.getTime() + 2)
                    end
                end
            end

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
                    local rank_name = "Unranked"
                    local next_rank_xp = 999999
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
                    local out_text = string.format("< XP and Rank >\n\nRank: %s\n\nTokens: %d (+%d)\nXP: %d (+%d)\nMissions Completed: %d\n\nNext Rank: %s\n  %s XP",
                        rank_name, user.tokens, user.unclaimed_tokens, user.xp, user.unclaimed_xp, user.missions_completed, next_rank, next_rank_xp)
                    trigger.action.outTextForGroup(group_id, out_text, 15)
                end
            end)
            CommandHandler.addToMenuTracking(group_id, xprank_root, "xp_rank_menu")
        
            
            -- 2. Now initialize the fresh menus
            CommandHandler.init(unit)
            CommandHandler.resourcesRequests(group)
            CommandHandler.initTaskingRequests(group)
            CommandHandler.tallyZone(unit)
            local ew = EWRS_coalition[unit_coalition]
            ew:addRadioMenuForUser(unit)
            --  CommandHandler.initCommandsForGroup(unit:getGroup())

        end
    end

    if event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition and unit.isExist
        and unit:isExist() and unit.getPlayerName then
            -- Clear F10 menus
            local group = unit:getGroup()
            if group then
                CommandHandler.clearF10(group)
            end

        end
    end

    if event.id == world.event.S_EVENT_CRASH and event.initiator then


        -- removes from enroutes
        local group_name = event.initiator:getGroup():getName()
        if EnrouteManager:findByGroup(group_name) then EnrouteManager:remove(group_name) end

        -- [checks if a capture heli crashed, if yes, remove it from enroute_capture_heli]
        local enroute_crash = EnrouteManager:findByGroup(event.initiator:getGroup():getName())
        if enroute_crash then

            EnrouteManager:remove(enroute_crash.group_name)
            MissionLogger:info("Removed CRASHED" ..enroute_crash.ai_task_type.." from enroutes: " .. enroute_crash.group_name)
            
        end



    end

    if event.id == world.event.S_EVENT_AI_ABORT_MISSION and event.initiator then

        
        local unit = event.initiator
        if unit and unit.isExist and unit:isExist() and unit.getGroup then
            local group_name = unit:getGroup():getName()
            -- checks if a capture heli aborted, if yes, remove it from enroute_capture_heli
            MissionLogger:info("AI unit aborted mission: " .. unit:getName())

            local enroute_aborted = EnrouteManager:findByGroup(group_name)
            if enroute_aborted then

                timer.scheduleFunction(function ()
                    local gr = Group.getByName(group_name)
                    if gr and gr.isExist and gr:isExist() then
                        trigger.action.explosion(gr:getUnit(1):getPoint(), 200)
                        EnrouteManager:remove(group_name)
                        MissionLogger:info("Removed damaged AI "..enroute_aborted.ai_task_type.." from enroutes: " .. group_name)
                    end

                end, {}, timer.getTime() + math.random(30,120))
            end
            
        end
    end

    if event.id == world.event.S_EVENT_ENGINE_SHUTDOWN and event.initiator then
        -- Make sure its AI
        local unit = event.initiator
        if event.place and unit.getPlayerName and not unit:getPlayerName() then
            local gr = unit:getGroup()
            if not gr then return end

            local gr_name = gr:getName()
            local gr_coalition = gr:getCoalition()
            local airbase_name = event.place:getName()
            local unit_type = unit:getTypeName()

            MissionLogger:info("Unit shutdown: " .. unit_type .. " at " .. airbase_name)
            

        end
    end

    if event.id == world.event.S_EVENT_LAND and event.initiator then
        -- checks if player landed
        local unit = event.initiator
        -- if unit and unit.getPlayerName and unit:getPlayerName() then trigger.action.outText(unit:getTypeName() .. " landed", 10) end
        
        if not unit or not unit.isExist or not unit:isExist() then return end
        local group_name = unit:getGroup():getName()
        
        local desc = unit:getDesc()
        
        if desc.category == Unit.Category.HELICOPTER then
            MissionLogger:info("Helicopter landed: " .. unit:getName())

            -- ABORTED HELI
            local enroute_heli = EnrouteManager:findByGroup(group_name)
            local group_pos = mist.getLeadPos(group_name)
            if enroute_heli and enroute_heli.aborted and group_pos and enroute_heli.from_zone:isPointInsideZone(group_pos) then
                EnrouteManager:remove(group_name)
                MissionLogger:info("Removed LANDED aborted heli from enroutes: " .. group_name)
                    timer.scheduleFunction(function ()
                        unit:getGroup():destroy()
                    end, {}, timer.getTime() + 10)

                    -- add back the heli to the zone
                    -- WARN is this necessary, does changing in enroute change in zones as well?
                    -- local heli_original_zone = ZoneHandler.getFromName(enroute_heli.from_zone.name) -- this checks the side

                    if enroute_heli.from_zone.capture_heli_avail and enroute_heli.side == unit:getCoalition() then
                        MissionLogger:info("Adding back heli to zone: " .. enroute_heli.from_zone.name)
                        enroute_heli.from_zone.capture_heli_avail = enroute_heli.from_zone.capture_heli_avail + 1
                        enroute_heli.from_zone:drawF10()
                    end
            elseif enroute_heli then
                -- POSSIBLE CAPTURE HELI
                    --check if in zone, if yes abort all ot hers inbound to the zone
                    if  TheatreCommander.checkIfCaptureGroupArrived(enroute_heli) then
                        timer.scheduleFunction(function ()
                            unit:getGroup():destroy()
                        end, {}, timer.getTime() + 10)
                    end
            end

            if unit and unit.getPlayerName and unit:getPlayerName() then
                local unit_coalition = unit:getCoalition()
                -- check if heli landed in neutral zone
                for _,zone in ipairs(zones) do
                    if zone.side == coalition.side.NEUTRAL and zone:isPointInsideZone(unit:getPoint()) then
                        trigger.action.outTextForCoalition(unit_coalition, "> You have captured ".. zone.name, 15)
                        trigger.action.outSoundForCoalition(unit_coalition, "radio_beep2.ogg")
                        
                        zone:capture(unit_coalition)
                    end
                end
                
            end


        elseif desc.category == Unit.Category.AIRPLANE then

            MissionLogger:info("Aircraft landed: " .. group_name)
            local enroute_task = EnrouteManager:findByGroup(group_name)
            if enroute_task then
                local landed_gr_name = enroute_task.group_name

 
                if enroute_task.ai_task_type == AITaskTypes.RESUPPLY_CARGO then
                    
                    trigger.action.outTextForCoalition(enroute_task.side, "RESUPPLY CARGO has landed", 10)
                    
                    local enroute_task_side = enroute_task.side
                    -- Schedule the supply addition
                    timer.scheduleFunction(function ()
                    
                        if enroute_task_side == coalition.side.RED then
                            WarehouseManager:handleIncomingSupplies(coalition.side.RED, {WarehouseManager.StockTypes.INITIAL})
                        else
                            if Config.enabled_su25t_bluefor then
                                WarehouseManager:handleIncomingSupplies(coalition.side.BLUE, {WarehouseManager.StockTypes.SU25T_BLUEFOR, WarehouseManager.StockTypes.INITIAL})
                            else
                                WarehouseManager:handleIncomingSupplies(coalition.side.BLUE, {WarehouseManager.StockTypes.INITIAL})


                            end
                        end
                    
                    end,{},timer.getTime()+10)
    
                end


                EnrouteManager:remove(group_name)
                
                timer.scheduleFunction(function ()
                    local gr = Group.getByName(landed_gr_name)
                    if gr and gr.isExist and gr:isExist() then
                        gr:destroy()
                    end

                end, {}, timer.getTime() + 300)
                -- MissionLogger:info("Removed LANDED"..enroute_task.ai_task_type.." from enroutes: " .. group_name)
                return
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
                -- Iterate backwards to safely remove
                for i = #radar_list, 1, -1 do
                    local radar = radar_list[i]
                    if radar and radar.isExist and radar:isExist() and radar.getID then
                        if radar:getID() == unit:getID() then
                            table.remove(radar_list, i)
                            MissionLogger:info("EWRS: Removed destroyed/dead radar unit " .. unit:getName() .. " from cache.")
                            break -- Exit loop once found
                        end
                    else
                        -- Clean up non-existing radar entries
                        table.remove(radar_list, i)
                    end
                end
            end
        end

        if unit and Object.getCategory(unit) == Object.Category.STATIC then
            MissionLogger:info("Static unit destroyed: " .. unit:getName())

        end


    end
end