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
                MissionLogger:info("Slot blocker checking for ".. unit:getName())
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
                                            if acft_count >= 1 then -- the airplane gets used before this script is executed, this is a must
                                                can_spawn = true
                                            else
                                                MissionLogger:info(string.format(
                                                    "Slot blocked:  %s at %s (stock=%d)",
                                                    acft_name,
                                                    wh_name,
                                                    acft_count
                                                ))

                                                can_spawn = false
                                                warehouse:addItem(acft_name,1)
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
                        local unit_id = unit:getID()

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
                            local out_text = "N/A"
                            if not next_rank_xp then
                                out_text = "< XP and Rank >\n\nRank: "..rank_name.."\n\nXP: "..user.xp.." (+"..user.unclaimed_xp..")\nMissions Completed: "..user.missions_completed
                            else
                                out_text = "< XP and Rank >\n\nRank: "..rank_name.."\n\nXP: "..user.xp.." (+"..user.unclaimed_xp..")\nMissions Completed: "..user.missions_completed.."\n\nNext Rank: "..next_rank.."\n  "..next_rank_xp.." XP"
                            end
                            trigger.action.outTextForUnit(unit_id, out_text, 15)
                            trigger.action.outSoundForUnit(unit_id, "radio_beep4.ogg")
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
                    ew:applySavedSetting(unit)
                end
            end

            checkSpawnAllowed()

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
        if event.initiator.getGroup then
            local enroute_crash = EnrouteManager:findByGroup(event.initiator:getGroup():getName())
            if enroute_crash then
                EnrouteManager:remove(enroute_crash.group_name)
                MissionLogger:info("Removed CRASHED" ..enroute_crash.ai_task_type.." from enroutes: " .. enroute_crash.group_name)
            
            end
        end
    end

    if event.id == world.event.S_EVENT_AI_ABORT_MISSION and event.initiator then


        local unit = event.initiator
        if unit and unit.isExist and unit:isExist() and unit.getGroup then
            local group_name = unit:getGroup():getName()
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
            if enroute_heli then
                local group_pos = mist.getLeadPos(group_name)
                EnrouteManager:handleHeloLanding(enroute_heli, unit, group_pos)
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
            if enroute_task and enroute_task.ai_task_type == AITaskTypes.RESUPPLY_CARGO then
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

        if unit and unit.getName and Object.getCategory(unit) == Object.Category.STATIC then
            MissionLogger:info("Static unit destroyed: " .. unit:getName())
        end
    end
end