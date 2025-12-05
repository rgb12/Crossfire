ev = {}
function ev:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH then
        ---@type Unit
        local unit = event.initiator
        if unit and unit.getCategory and unit:getCategory() == Object.Category.UNIT and unit.getCoalition then
            local unit_coalition = unit:getCoalition()
                
                --init commands
                CommandHandler.tallyZone(unit)
    
                local ew = EWRS_coalition[unit_coalition]
                ew:addRadioMenuForUser(unit)
                --  CommandHandler.initCommandsForGroup(unit:getGroup())
                
       

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
            trigger.action.outText(unit:getTypeName() .. " entered", 10)
            -- Checks if the player has the rigt to spawn in the airbase
            for _,zone in ipairs(zones) do
                if zone:isPointInsideZone(unit:getPoint()) then
                    if zone.side ~= unit_coalition then
                        -- not allowed, destroy the unit
                        local unit_id = unit:getID()
                        trigger.action.outSoundForUnit(unit_id, "error.ogg")
                        trigger.action.outTextForUnit(unit_id, "****************\n\nThis slot is not allowed at the moment! Consult F10 map.\n\n****************", 20)
                        timer.scheduleFunction(function ()
                            if unit and unit:isExist() then
                                unit:destroy()
                            end
                        end, {}, timer.getTime() + 2)
                        return
                    end
                end
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
            
            -- Check if this group is a tracked resupply mission
            local enroute_task = EnrouteManager:findByGroup(gr_name)

            if enroute_task and enroute_task.ai_task_type == AITaskTypes.RESUPPLY_CARGO then
                
                trigger.action.outText(gr_name.. " has shut down at ramp", 10)
                
                -- Destroy the aircraft unit
                unit:destroy()

                -- Schedule the supply addition
                timer.scheduleFunction(function ()
                
                    -- 1. Get the correct step and cycle
                    local current_step

                    if gr_coalition == coalition.side.BLUE then
                        current_step = stats.blue_resupply_step
                        -- Increment and wrap for next time
                        stats.blue_resupply_step = stats.blue_resupply_step + 1
                        if stats.blue_resupply_step > #WarehouseManager.ResupplyCycle then
                            stats.blue_resupply_step = 1
                        end
                    else -- Must be RED
                        current_step = stats.red_resupply_step
                        -- Increment and wrap for next time
                        stats.red_resupply_step = stats.red_resupply_step + 1
                        if stats.red_resupply_step > #WarehouseManager.ResupplyCycle then
                            stats.red_resupply_step = 1
                        end
                    end

                    -- 2. Get the supplies from the cycle
                    local restock_types = WarehouseManager.ResupplyCycle[current_step].types
                    local restock_txt = WarehouseManager.ResupplyCycle[current_step].text

                    -- 3. Distribute the supplies to ALL eligible L3/L4 bases
                    MissionLogger:info("Cargo aircraft arrived, supplying "..restock_txt.." into airfield warehouses...")
                    trigger.action.outTextForCoalition(gr_coalition, "Cargo aircraft arrived, supplying "..restock_txt.." into airfield warehouses...",10)
                    
                    WarehouseManager:handleIncomingSupplies(gr_coalition, restock_types)

                    -- 4. Remove the task from the manager

                
                end,{},timer.getTime()+10)

                
                EnrouteManager:remove(gr_name)
                return
            end
        end
    end

    if event.id == world.event.S_EVENT_LAND and event.initiator then
        -- checks if player landed
        local unit = event.initiator
        if unit and unit.getPlayerName and unit:getPlayerName() then trigger.action.outText(unit:getTypeName() .. " landed", 10) end
        
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
                    return
            elseif enroute_heli then 
                -- POSSIBLE CAPTURE HELI
                    --check if in zone, if yes abort all ot hers inbound to the zone
                    if  TheatreCommander.checkIfCaptureGroupArrived(enroute_heli) then
                        timer.scheduleFunction(function ()
                            unit:getGroup():destroy()
                        end, {}, timer.getTime() + 10)
                    end
                    return
                
            end

        elseif desc.category == Unit.Category.AIRPLANE then

            local enroute_task = EnrouteManager:findByGroup(group_name)
            if enroute_task then
                EnrouteManager:remove(group_name)
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