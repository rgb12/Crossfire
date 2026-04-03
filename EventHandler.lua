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
                                            
                                            if acft_count >= 1 then -- the airplane gets used before this script is executed
                                                can_spawn = true
                                                
                                                -- Due to the size of the C130, certain bases do not have spawn slots.
                                                -- The workaround is to spawn them as taking off from ground, but the script has to check for this case specifically
                                                if acft_name == WarehouseManager.AircraftFlags.C130J_30 or
                                                zone.zone_type == ZoneTypes.FARP then
                                                    warehouse:removeItem(acft_name,1)
                                                end

                                            else
                                                MissionLogger:info(string.format(
                                                    "Slot blocked:  %s at %s (stock=%d)",
                                                    acft_name,
                                                    wh_name,
                                                    acft_count
                                                ))

                                                can_spawn = false
                                                --warehouse:addItem(acft_name,1)
                                                if acft_name == WarehouseManager.AircraftFlags.C130J_30 then
                                                    trigger.action.outTextForUnit(unit:getID(), "C130J-30 user; If you tried spawning right after mission start, please wait a moment and try again.",30)
                                                end
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
                            local out_text = string.format("< XP and Rank >\n\nRank: %s\n\nXP: %d (+%d)\nMissions Completed: %d\n\nNext Rank: %s\n  %s XP",
                                rank_name, user.xp, user.unclaimed_xp, user.missions_completed, next_rank, next_rank_xp)
                            trigger.action.outTextForGroup(group_id, out_text, 15)
                            trigger.action.outSoundForGroup(group_id, "radio_beep4.ogg")
                        end
                    end)
                    CommandHandler.addToMenuTracking(group_id, xprank_root, "xp_rank_menu")
                  
                    CommandHandler.init(unit)
                    CommandHandler.resourcesRequests(group)
                    CommandHandler.initTaskingRequests(group)
                    CommandHandler.operationsMenu(group,unit)
                    CommandHandler.tallyZone(unit)

                    local ew = EWRS_coalition[unit_coalition]
                    ew:addRadioMenuForUser(unit)
                end
            end

            if timer.getTime() < 15 then
                -- wait for mission to initialize, 15 seconds is just what I found to work during testing, this needs to be improved
                trigger.action.outTextForUnit(unit:getID(), "Assets and warehouses are still loading; if your slot is blocked, try again in a moment.",20)
                timer.scheduleFunction(function ()
                    checkSpawnAllowed()
                end, {}, timer.getTime() + 15)
            else
                checkSpawnAllowed()
            end
            -- checkSpawnAllowed()

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
                        trigger.action.explosion(gr:getUnit(1):getPoint(), 250)
                        EnrouteManager:remove(group_name)
                        MissionLogger:info("Removed damaged AI "..enroute_aborted.ai_task_type.." from enroutes: " .. group_name)
                    end

                end, {}, timer.getTime() + math.random(30,120))
            end
            
        end
    end

    if event.id == world.event.S_EVENT_LAND and event.initiator then
        local unit = event.initiator
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
                    --check if in zone, if so abort all others inbound to the zone
                    if  TheatreCommander.checkIfCaptureGroupArrived(enroute_heli) then
                        timer.scheduleFunction(function ()
                            unit:getGroup():destroy()
                        end, {}, timer.getTime() + 10)
                    else
                        timer.scheduleFunction(function ()
                            unit:getGroup():destroy()
                        end, {}, timer.getTime() + 10)

                    end
            end

            if unit and unit.getPlayerName and unit:getPlayerName() then
                local unit_coalition = unit:getCoalition()
                local u_id = unit:getID()
                -- check if heli landed in neutral zone
                for _,zone in ipairs(zones) do
                    if zone.side == coalition.side.NEUTRAL and zone:isPointInsideZone(unit:getPoint()) then
                        trigger.action.outTextForUnit(u_id, "Allied forces deployed at ".. zone.name..". Great work.", 15)
                        trigger.action.outSoundForUnit(u_id, "radio click.ogg")
                        
                        timer.scheduleFunction(function ()
                            zone:capture(unit_coalition)
                        end, {}, timer.getTime() + math.random(10,30))
                    end
                end
                
            end


        elseif desc.category == Unit.Category.AIRPLANE then
            local enroute_task = EnrouteManager:findByGroup(group_name)
            if enroute_task then
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

        if unit and Object.getCategory(unit) == Object.Category.STATIC then
            MissionLogger:info("Static unit destroyed: " .. unit:getName())
        end
    end
end