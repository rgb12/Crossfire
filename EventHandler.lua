ev = {}
function ev:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if unit and unit:getCategory() == Object.Category.UNIT then

            -- [player specific code]
            if unit.getPlayerName and unit:getPlayerName() then
                trigger.action.outText(unit:getTypeName() .. " entered", 10)
                --init commands
                CommandHandler.tallyZone(unit)
    
                local ew = EWRS_coalition[unit:getCoalition()]
                ew:addRadioMenuForUser(unit)
                --  CommandHandler.initCommandsForGroup(unit:getGroup())
                
            end

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

    if event.id == world.event.S_EVENT_TAKEOFF then
        local unit = event.initiator
        if unit and unit:getCategory() == Object.Category.UNIT then
            trigger.action.outText(unit:getTypeName() .. " took off", 10)
            -- MissionLogger:info("Event place:")
            -- MissionLogger:info(event.place:getName())
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
        local group_name = unit:getGroup():getName()
        
        
        -- checks if a capture heli aborted, if yes, remove it from enroute_capture_heli
        MissionLogger:info("AI unit aborted mission: " .. unit:getName())
        MissionLogger:info(EnrouteManager.enroutes)
        for k,v in pairs(EnrouteManager.enroutes) do
            MissionLogger:info("Enroute tracked: " .. v.group_name .. " for task type: " .. v.ai_task_type)
        end
        local enroute_aborted = EnrouteManager:findByGroup(group_name)
        MissionLogger:info(enroute_aborted)
        if enroute_aborted then
            if enroute_aborted.ai_task_type == AITaskTypes.CAPTURE_HELO then
                -- give the heli 2 minutes to land or be destroyed
                timer.scheduleFunction(function ()
                    local gr = Group.getByName(group_name)
                    if gr and gr:isExist() then
                        trigger.action.explosion(gr:getUnit(1):getPoint(), 100)
                        EnrouteManager:remove(group_name)
                        MissionLogger:info("Removed damaged AI Heli from enroutes: " .. group_name)
                    end
                end, {}, timer.getTime() + 120)
            elseif enroute_aborted.ai_task_type == AITaskTypes.JTAC then
                EnrouteManager:remove(group_name)
                MissionLogger:info("Removed aborted JTAC from enroutes: " .. group_name)
            else
                EnrouteManager:remove(group_name)
            end
        end
        
        -- -- check if capture heli, if yes, remove it from enroute_capture_heli
        -- for i, heli_aborted in ipairs(enroute_capture_heli) do
        --     if heli_aborted.group_name == group_name then
        --         -- give the heli 2 minutes to land or be destroyed
        --         local function destroy_heli()
        --             if unit and unit:isExist() then
        --                 trigger.action.explosion(unit:getPoint(), 100)
        --                 table.remove(enroute_capture_heli, i)
        --                 MissionLogger:info("Removed damaged AI Heli from enroutes: " .. heli_aborted.group_name)
        --             end
        --         end
        --         mist.scheduleFunction(destroy_heli, {}, timer.getTime() + 120)
        --     end
        -- end

        -- check it its a JTAC
        -- for i,jtac in ipairs(enroute_jtac) do

        --     if jtac.jtac_gr_name == group_name then
        --         missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
        --         jtac.jtac_menu = nil
        --         MissionLogger:info("Removed aborted JTAC from enroutes: " .. jtac.jtac_gr_name)
        --         table.remove(enroute_jtac,i)
        --     end
            
        -- end


        -- for i,recon_gr_name in ipairs(enroute_recon) do
        --     if recon_gr_name == group_name then
        --         -- give the recon aircraft 5 minutes to land or be destroyed
        --         local function destroy_heli()
        --             if unit and unit:isExist() then
        --                 trigger.action.explosion(unit:getPoint(), 100)
        --                 table.remove(enroute_recon, i)
        --                 MissionLogger:info("Removed aborted recon aircraft from enroutes: " .. recon_gr_name)
        --             end
        --         end
        --         mist.scheduleFunction(destroy_heli, {}, timer.getTime() + 5*60)
        --     end
        -- end
    end




    if event.id == world.event.S_EVENT_KILL and event.target and event.initiator then
        MissionLogger:info("S_EVENT_KILL fired")

        local target = event.target
        local initiator = event.initiator
        
        if not target then return end
        if not target.getCoalition then return end
        if not initiator then return end
        if not initiator.getCoalition then return end

        -- Check if the target is a UNIT or STATIC
        if target and (Object.getCategory(target) == Object.Category.UNIT or Object.getCategory(target) == Object.Category.STATIC) then
            
            -- Find what zone the unit died in
            local zone_of_dead_unit = utils.getZoneOfUnitFromPosition(target:getPoint())
            
            if zone_of_dead_unit then
                -- Check if the zone is not already neutral
                if zone_of_dead_unit.side ~= coalition.side.NEUTRAL then
                    
                    -- if a bomb drops and kills a dozen, this prevents to fire world.searchObjects multiple times for the same zo

                    -- Add this zone to our "to-do" list.
                    -- Using the zone name as a key prevents duplicates.
                    -- MissionLogger:info("Unit added to capture check: " .. zone_of_dead_unit.name)
                    TheatreCommander.zones_to_check_for_capture[zone_of_dead_unit.name] = zone_of_dead_unit
                end

                if zone_of_dead_unit.side == coalition.side.BLUE then
                    zone_of_dead_unit.last_attacked_by = coalition.side.RED
                elseif zone_of_dead_unit.side == coalition.side.RED then
                    zone_of_dead_unit.last_attacked_by = coalition.side.BLUE
                end
                
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
                    EnrouteManager:remove(gr_name)
                
                end,{},timer.getTime()+10)

                
                return
            end

            
        end
    end

    if event.id == world.event.S_EVENT_LAND and event.initiator then
        -- checks if player landed
        local unit = event.initiator
        local group_name = unit:getGroup():getName()
        if unit and unit.getPlayerName and unit:getPlayerName() then trigger.action.outText(unit:getTypeName() .. " landed", 10) end
        
        local desc = unit:getDesc()
        
        if desc.category == Unit.Category.HELICOPTER then
            MissionLogger:info("Helicopter landed: " .. unit:getName())

            -- ABORTED HELI
            local enroute_heli = EnrouteManager:findByGroup(group_name)
            if enroute_heli and enroute_heli.aborted and enroute_heli.from_zone:isPointInsideZone(mist.getLeadPos(group_name)) then
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

            -- for i, cargo in ipairs(stats.blue_enroute_resupply) do
            --     if cargo == unit:getGroup():getName() then
            --         MissionLogger:info("BLUE cargo landed, adding resources")
            --         trigger.action.outTextForCoalition(unit:getGroup():getCoalition(), "Cargo aircraft has landed",10)
            --         --TO CHANGE add items to home airbase as cargo landed



            --         break
            --     end
            -- end
            -- for i, cargo in ipairs(stats.red_enroute_resupply) do
            --     if cargo == unit:getGroup():getName() then
            --         MissionLogger:info("RED cargo landed, adding resources")
            --         trigger.action.outTextForCoalition(unit:getGroup():getCoalition(), "Cargo aircraft has landed",10)
            --         break
            --         --TO CHANGE add items to red airbase as cargo landed

            --     end
            -- end

            for i,jtac in ipairs(enroute_jtac) do
                if jtac.jtac_gr_name == unit:getGroup():getName() then
                    table.remove(enroute_jtac,i)
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign.." JTAC landed, end of task.",5)
                    break
                end
            end

        end
    elseif event.id == world.event.S_EVENT_DEAD and event.initiator then

        local unit = event.initiator
        
        -- Check if the dead unit was a radar (ground or air)
        if unit.hasAttribute and (unit:hasAttribute("SAM SR") or unit:hasAttribute("EWR") or unit:hasAttribute("AWACS")) then
            local side = unit:getCoalition()
            if EWRS_coalition[side] then
                local radar_list = EWRS_coalition[side].radars
                -- Iterate backwards to safely remove
                for i = #radar_list, 1, -1 do 
                    if radar_list[i]:getID() == unit:getID() then
                        table.remove(radar_list, i)
                        MissionLogger:info("EWRS: Removed destroyed/dead radar unit " .. unit:getName() .. " from cache.")
                        break -- Exit loop once found
                    end
                end
            end
        end

        -- Check if the target is a UNIT or STATIC
        if unit and (Object.getCategory(unit) == Object.Category.UNIT or Object.getCategory(unit) == Object.Category.STATIC) then
            
            -- Find what zone the unit died in
            local zone_of_dead_unit = utils.getZoneOfUnitFromPosition(unit:getPoint())
            
            if zone_of_dead_unit then
                -- Check if the zone is not already neutral
                if zone_of_dead_unit.side ~= coalition.side.NEUTRAL then
                    
                    -- if a bomb drops and kills a dozen, this prevents to fire world.searchObjects multiple times for the same zo

                    -- Add this zone to our "to-do" list.
                    -- Using the zone name as a key prevents duplicates.
                    -- MissionLogger:info("Unit added to capture check: " .. zone_of_dead_unit.name)
                    TheatreCommander.zones_to_check_for_capture[zone_of_dead_unit.name] = zone_of_dead_unit
                end

                if zone_of_dead_unit.side == coalition.side.BLUE then
                    zone_of_dead_unit.last_attacked_by = coalition.side.RED
                elseif zone_of_dead_unit.side == coalition.side.RED then
                    zone_of_dead_unit.last_attacked_by = coalition.side.BLUE
                end
                
            end
        end

        if unit and Object.getCategory(unit) == Object.Category.STATIC then
            MissionLogger:info("Static unit destroyed: " .. unit:getName())

            -- -- WARN could store the ew sites in a variable
            -- for _,zone in ipairs(zones) do
            --     if zone.zone_type == ZoneTypes.EWSITE and zone.comms_tower_intact and zone.linked_comms_tower == unit:getName() then
            --         MissionLogger:info("EW Site destroyed in zone: " .. zone.name)
            --         zone.comms_tower_intact = false

            --         break

            --     end
            -- end

        end


    end
end