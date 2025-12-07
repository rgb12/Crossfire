CommandHandler = {}
do
    local player_cooldowns = {}

    CommandHandler.jtac_main_submenu = nil
    CommandHandler.tasking_main_submenu = nil

    -- Track group menus: group_menus[group_id] = { {path=..., type=...}, ... }
    CommandHandler.group_menus = {}

    CommandHandler.destroy_page = 1

    CommandHandler.jtac_submenu = {
        [coalition.side.RED] = nil,
        [coalition.side.BLUE] = nil
    }
    ---@param unit Unit
    function CommandHandler.init(unit)
        -- SITMAP
        if unit and unit.isExist and unit:isExist() and unit.getCoalition then
            missionCommands.addCommandForGroup(unit:getGroup():getID(), "SITMAP", nil, function()
                local out_text = "< SITAMP> \n\n"
                out_text = out_text .. "REDFOR controls " .. stats.red_zones .. " areas.\n"
                out_text = out_text .. "BLUEFOR controls " .. stats.blue_zones .. " areas.\n"
                out_text = out_text .. "Neutral areas: " .. stats.neutral_zones .. "\n\n"

                local total_zones = stats.red_zones + stats.blue_zones + stats.neutral_zones

                if unit:getCoalition() == coalition.side.RED then
                    out_text = out_text .. "Your forces control " .. stats.red_zones .. "/" .. total_zones .. " areas.\n"
                else
                    out_text = out_text .. "Your forces control " .. stats.blue_zones .. "/" .. total_zones .. " areas.\n"
                end
                trigger.action.outTextForUnit(unit:getID(), out_text, 15)
            end, nil)
        end
    end

    local refresh_timer = nil
    local pending_refresh_sides = {
        [coalition.side.RED] = false,
        [coalition.side.BLUE] = false
    }

    ---@param gr Group
    function CommandHandler.resourcesRequests(gr)

        if not gr or not gr.isExist or not gr:isExist() then return end
                local gr_id = gr:getID()

        if CommandHandler.group_menus[gr_id] then
            -- Remove existing menus. 
            for i = #CommandHandler.group_menus[gr_id], 1, -1 do
                if CommandHandler.group_menus[gr_id][i].type == "resources_main" then
                    missionCommands.removeItemForGroup(gr_id, CommandHandler.group_menus[gr_id][i].path)
                    table.remove(CommandHandler.group_menus[gr_id], i)
                end
            end
        else
            CommandHandler.group_menus[gr_id] = {}
        end

          -- Create the root menu for this update
        local resources_main_submenu = missionCommands.addSubMenuForGroup(gr_id,"Resources",nil)
        table.insert(CommandHandler.group_menus[gr_id], {path=resources_main_submenu, type="resources_main"})

        local resources = {}

        -- UPGRADE ZONES LOGIC
        local unit = gr:getUnit(1)
        if unit and unit:isExist() and unit.getCoalition then
            local side = unit:getCoalition()

            ---@param target_unit Unit
            ---@param required_tokens number
            ---@return boolean
            local function checkTokens(target_unit, required_tokens)
                if not Config.reward_system.enable then return true end
                if not target_unit or not target_unit.isExist or not target_unit:isExist() then return false end
                local user = ExperienceManager:fetchUser(target_unit)
                if not user then return false end
                if user.tokens >= required_tokens then
                    return true
                else
                    trigger.action.outTextForUnit(target_unit:getID(), "Insufficient tokens: " .. user.tokens .. "/" .. required_tokens .. " tokens required.", 5)
                    return false
                end
            end

            local upgrade_zone_list = {}

            -- Build list of friendly zones that can be upgraded
            for _, zone in ipairs(zones) do
                if zone.side == side and zone.level and zone.level < 4 then
                    local upgrade_cost = Config.zone_upgrade_costs_tokens and Config.zone_upgrade_costs_tokens[zone.level] or 100
                    
                    table.insert(upgrade_zone_list, {
                        name = zone.name .. " (T:" .. zone.level .. "/4) - Cost: " .. upgrade_cost .. " tokens",
                        func = function (args)
                            local u = args.u
                            local target_zone = args.z
                            
                            if not checkTokens(u, upgrade_cost) then return end

                            if target_zone.level < 4 then
                                target_zone.level = target_zone.level + 1
                                UnitHandler.updateZoneUnits(target_zone)
                                target_zone:drawF10()
                                
                                ExperienceManager:deductTokens(u, upgrade_cost)
                                trigger.action.outTextForUnit(u:getID(), target_zone.name .. " upgraded to Tier " .. target_zone.level .. "/4, -" .. upgrade_cost .. " tokens.", 10)
                                trigger.action.outTextForCoalition(side, target_zone.name .. " upgraded to Tier " .. target_zone.level .. "/4", 10)
                                trigger.action.outSoundForCoalition(side,"radio_beep.ogg")
                                
                                -- Refresh menus for all players in the coalition
                                CommandHandler.requestMenuRefresh(side)
                            else
                                trigger.action.outTextForUnit(u:getID(), target_zone.name .. " is already at maximum tier (4/4).", 10)
                            end
                        end,
                        arg = {u = unit, z = zone}
                    })
                end
            end

            missionCommands.addCommandForGroup(gr_id, "Request Resupply - Cost:"..Config.resupply_tokens_cost.." tokens", resources_main_submenu, function()
                if not checkTokens(unit, Config.resupply_tokens_cost) then return end
                ExperienceManager:deductTokens(unit, Config.resupply_tokens_cost)
                trigger.action.outTextForGroup(gr_id, "> Resupply requested", 10)
                TheatreCommander.sendWarehouseResupply(side, false)
            end, nil)

            local  upgrade_submenu = missionCommands.addSubMenuForGroup(gr_id, "Request Upgrade", resources_main_submenu)
            if #upgrade_zone_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, upgrade_submenu, upgrade_zone_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No Zones Available", resources_main_submenu, function() end, nil)
            end
        end

    end

    ---@param side coalition.side|nil
    function CommandHandler.requestMenuRefresh(side)
        -- Mark this side as needing a refresh
        if side then
            pending_refresh_sides[side] = true
        else
            -- If no side provided (e.g. global update), mark both
            pending_refresh_sides[coalition.side.RED] = true
            pending_refresh_sides[coalition.side.BLUE] = true
        end

        -- If a timer is already running, let it handle the pending flags when it fires
        if refresh_timer then return end

        -- Schedule the refresh for 5 seconds in the future
        refresh_timer = timer.scheduleFunction(function()
            MissionLogger:info("Executing pending menu refreshes...")
            
            -- CHECK RED
            if pending_refresh_sides[coalition.side.RED] then
                MissionLogger:info("Refreshing RED menus")
                CommandHandler.refreshJtacCmds(coalition.side.RED)
                
                local red_players = coalition.getPlayers(coalition.side.RED)
                for _, unit in ipairs(red_players) do
                    if unit and unit:isExist() then
                        local gr = unit:getGroup()
                        if gr then CommandHandler.initTaskingRequests(gr) end
                    end
                end
                
                -- Reset flag
                pending_refresh_sides[coalition.side.RED] = false
            end

            -- CHECK BLUE
            if pending_refresh_sides[coalition.side.BLUE] then
                MissionLogger:info("Refreshing BLUE menus")
                CommandHandler.refreshJtacCmds(coalition.side.BLUE)
                
                local blue_players = coalition.getPlayers(coalition.side.BLUE)
                for _, unit in ipairs(blue_players) do
                    if unit and unit:isExist() then
                        local gr = unit:getGroup()
                        if gr then CommandHandler.initTaskingRequests(gr) end
                    end
                end
                
                -- Reset flag
                pending_refresh_sides[coalition.side.BLUE] = false
            end

            refresh_timer = nil -- Allow new timer to start
        end, nil, timer.getTime() + 5)
    end

    ---@param gr Group
    function CommandHandler.initTaskingRequests(gr)
        if not gr or not gr.isExist or not gr:isExist() then return end
        local gr_id = gr:getID()

        if CommandHandler.group_menus[gr_id] then
            -- Remove existing menus. 
            for i = #CommandHandler.group_menus[gr_id], 1, -1 do
                if CommandHandler.group_menus[gr_id][i].type == "tasking_main" then
                    missionCommands.removeItemForGroup(gr_id, CommandHandler.group_menus[gr_id][i].path)
                    table.remove(CommandHandler.group_menus[gr_id], i)
                end
            end
        else
            CommandHandler.group_menus[gr_id] = {}
        end

        -- Create the root menu for this update
        local tasking_main_submenu = missionCommands.addSubMenuForGroup(gr_id,"Request Tasking",nil)
        table.insert(CommandHandler.group_menus[gr_id], {path=tasking_main_submenu, type="tasking_main"})

        ---@param unit Unit
        ---@param required_tokens number
        ---@return boolean
        local function checkTokens(unit,required_tokens)
            if not Config.reward_system.enable then return true end
            if not unit or not unit.isExist or not unit:isExist() then return false end
            local user = ExperienceManager:fetchUser(unit)
            if not user then return false end
            if user.tokens >= required_tokens then
                return true
            else
                trigger.action.outTextForUnit(unit:getID(),"Insufficient tokens for tasking request, ".. user.tokens.."/"..required_tokens.." tokens required.",5)
                return false
            end
        end

        ---@param unit Unit
        ---@param ai_task_type AITaskTypes
        ---@return boolean
        local function checkRankRequirement(unit, ai_task_type)
            if not Config.reward_system.enable then return true end
            if not unit or not unit.isExist or not unit:isExist() then return false end
            local user = ExperienceManager:fetchUser(unit)
            if not user then return false end
            local required_xp = Config.reward_system.xp_required[ai_task_type]
            if not required_xp then return true end -- No rank requirement
            if user.xp >= required_xp then
                return true
            else
                local rankreq = ExperienceManager:getRankfromXP(required_xp) or "Unknown"
                trigger.action.outTextForUnit(unit:getID(),"Insufficient rank for this tasking request. Required rank: "..rankreq..", ".. required_xp .." XP",5)
                return false
            end
        end

        local unit = gr:getUnit(1)
        if not unit or not unit:isExist() or not unit.getCoalition then return end
        local side = unit:getCoalition()
        local enemy_side = utils.getEnemyCoalition(side)
        
        local discovered_zones = {}
        if side == coalition.side.BLUE then
            discovered_zones = stats.blue_discovered_zones
        else
            discovered_zones = stats.red_discovered_zones
        end

        local main_tasking_list = {}

        -- 1. Build CAS Target List
        local cas_target_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for CAS
            if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name) then 
                table.insert(cas_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.CAS) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_cas) then return end
                        
                        if TaskManager:initiateAITask(AITaskTypes.CAS, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_cas)
                            trigger.action.outTextForUnit(u:getID(), "CAS dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_cas .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "CAS request failed (No assets available).", 10)
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        local sead_target_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for SEAD
            if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name)
            and zone.zone_type == ZoneTypes.SAMSITE
            then
                table.insert(sead_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.SEAD) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_sead) then return end

                        if TaskManager:initiateAITask(AITaskTypes.SEAD, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_sead)
                            trigger.action.outTextForUnit(u:getID(), "SEAD dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_sead .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "SEAD request failed (No assets available).", 10)
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        local capture_heli_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for HELI CAPTURE
            if zone.side == coalition.side.NEUTRAL and utils.tableContains(discovered_zones, zone.name)
            then
                table.insert(capture_heli_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.CAPTURE_HELO) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_capture_helicopter) then return end

                        -- Finds nearest blue logistics zone to the target neutral zone
                        local from_zone = nil
                        for _, log_zone in ipairs(zones) do
                            if log_zone.side == side and log_zone.zone_type == ZoneTypes.LOGISTICS
                            and log_zone.capture_heli_avail > 0 then
                                from_zone = log_zone
                                break
                            end
                        end

                        if from_zone then                        
                            if TaskManager:initiateAITask(AITaskTypes.CAPTURE_HELO, side, false, to_zone, from_zone, true) then
                                ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_capture_helicopter)
                                trigger.action.outTextForUnit(u:getID(), "> Helicopter capture dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_capture_helicopter .. " tokens.", 10)
                            else
                                trigger.action.outTextForUnit(u:getID(), "> Helicopter capture request failed (no assets available).", 10)
                            end
                        else
                            trigger.action.outTextForUnit(u:getID(), "> No logistics zones with capture helicopters available.", 10)
                        end

                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        local jtac_target_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for JTAC
            if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name) then 
                table.insert(jtac_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.JTAC) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_jtac) then return end
                        if not u.getCoalition then return end

                        local live_comms = (u:getCoalition() == coalition.side.BLUE) and stats.blue_comms_zones or stats.red_comms_zones
                        local total_comms = (u:getCoalition() == coalition.side.BLUE) and stats.blue_total_comms_zones or stats.red_total_comms_zones
                        
                        if live_comms < Config.tasking_requirements.comms_zones_required_for_jtac then
                            trigger.action.outTextForUnit(u:getID(), "JTAC tasking requires " .. total_comms .. "/"..Config.tasking_requirements.comms_zones_required_for_jtac.." active COMMS antennas.", 10)
                        return
                    end

                        if TaskManager:initiateAITask(AITaskTypes.JTAC, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_jtac)
                            trigger.action.outTextForUnit(u:getID(), "JTAC dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_jtac .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "JTAC request failed (No assets available).", 10)
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        local cap_zone_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for CAP
            if utils.tableContains(discovered_zones, zone.name) then
                table.insert(cap_zone_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.INTERCEPT) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_intercept) then return end
                        
                        if TaskManager:initiateAITask(AITaskTypes.INTERCEPT, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_intercept)
                            trigger.action.outTextForUnit(u:getID(), "CAP dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_intercept .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "CAP request failed (No assets available).", 10)
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end
        
        local strike_target_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for STRIKE
            if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name)
            and (zone.zone_type == ZoneTypes.LOGISTICS or zone.zone_type == ZoneTypes.COMMS)
            then
                table.insert(strike_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.STRIKE) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_strike) then return end
                        
                        if TaskManager:initiateAITask(AITaskTypes.STRIKE, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_strike)
                            trigger.action.outTextForUnit(u:getID(), "Strike dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_strike .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "Strike request failed (No assets available).", 10)
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        if #jtac_target_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request JTAC",
                submenu = jtac_target_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request JTAC (No Targets)",
                func = function() end,
                arg = nil
            })
        end

        if #capture_heli_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request Helicopter Capture",
                submenu = capture_heli_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request Helicopter Capture (Unavailable)",
                func = function() end,
                arg = nil
            })
        end

        if #cap_zone_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request CAP",
                submenu = cap_zone_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request CAP (No Targets)",
                func = function() end,
                arg = nil
            })
        end

        -- Add the CAS category to the main list
        if #cas_target_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request CAS",
                submenu = cas_target_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request CAS (No Targets)",
                func = function() end,
                arg = nil
            })
        end

        if #strike_target_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request Strike",
                submenu = strike_target_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request Strike (No Targets)",
                func = function() end,
                arg = nil
            })
        end

        if #sead_target_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request SEAD",
                submenu = sead_target_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request SEAD (No Targets)",
                func = function() end,
                arg = nil
            })
        end

        -- Build the final paginated nested menu under the tasking_main_submenu
        if #main_tasking_list > 0 then
            CommandHandler.buildPagedMenuForGroup(gr_id, tasking_main_submenu, main_tasking_list, 1)
        end
    end

    -- Helper function for GROUP menus (Supports Nested Menus)
    ---@param group_id number
    ---@param parent_menu any
    ---@param command_list table
    ---@param start_index number
    function CommandHandler.buildPagedMenuForGroup(group_id, parent_menu, command_list, start_index)
        start_index = start_index or 1
        local total_items = #command_list
        local remaining = total_items - start_index + 1
        local max_per_page = 9 -- Reserve 1 slot for "Next Page"

        if remaining <= 10 then
            max_per_page = 10
        end

        local end_index = math.min(start_index + max_per_page - 1, total_items)

        for i = start_index, end_index do
            local item = command_list[i]
            if item.submenu then
                -- Item is a nested menu structure
                local sub_menu = missionCommands.addSubMenuForGroup(group_id, item.name, parent_menu)
                -- Recursively build the submenu
                CommandHandler.buildPagedMenuForGroup(group_id, sub_menu, item.submenu, 1)
            else
                -- Item is a standard command
                missionCommands.addCommandForGroup(group_id, item.name, parent_menu, item.func, item.arg)
            end
        end

        -- If there are items left, create a Next Page submenu and recurse
        if end_index < total_items then
            local next_menu = missionCommands.addSubMenuForGroup(group_id, "Next Page >>", parent_menu)
            CommandHandler.buildPagedMenuForGroup(group_id, next_menu, command_list, end_index + 1)
        end
    end


    ---@param side coalition.side
    function CommandHandler.refreshJtacCmds(side)
        do return end -- JTAC disabled for now
        if not side then side = coalition.side.BLUE end

        if CommandHandler.jtac_main_submenu then
            missionCommands.removeItemForCoalition(side, CommandHandler.jtac_main_submenu)
            CommandHandler.jtac_main_submenu = nil -- Reset handle
        end

        local enemy_side = nil
        local discovered_zones = nil
        local current_comms_count = 0

        if side == coalition.side.BLUE then
            enemy_side = coalition.side.RED
            discovered_zones = stats.blue_discovered_zones
            current_comms_count = stats.blue_comms_antennas
        else
            enemy_side = coalition.side.BLUE
            discovered_zones = stats.red_discovered_zones
            current_comms_count = stats.red_comms_antennas
        end

        if current_comms_count < Config.tasking_requirements.comms_zones_required_for_jtac then
            return
        end

        -- Create root menu
        CommandHandler.jtac_main_submenu = missionCommands.addSubMenuForCoalition(side, "Task JTAC", nil)

        local valid_commands = {}

        for _, zone in ipairs(zones) do
            if zone.side == enemy_side
            and utils.tableContains(discovered_zones, zone.name)
            and not EnrouteManager:findByToZone(zone, side, {AITaskTypes.JTAC}) then
                
                local function send(to_zone)
                    local zone_check = ZoneHandler.getFromName(to_zone.name)
                    if not zone_check then return end
                    
                    if (zone_check.side == side or zone_check.side == coalition.side.NEUTRAL) then
                        trigger.action.outTextForCoalition(side, "Cannot task JTAC to a friendly or neutral zone.", 10)
                        return
                    end

                    local live_comms = (side == coalition.side.BLUE) and stats.blue_comms_zones or stats.red_comms_zones
                    local total_comms = (side == coalition.side.BLUE) and stats.blue_total_comms_zones or stats.red_total_comms_zones
                    if live_comms < Config.tasking_requirements.comms_zones_required_for_jtac then
                        trigger.action.outTextForCoalition(side, "JTAC tasking requires " .. total_comms .. "/"..Config.tasking_requirements.comms_zones_required_for_jtac.." active COMMS antennas.", 10)
                        return
                    end

                    TaskManager:initiateAITask(AITaskTypes.JTAC, side, true, zone_check, nil, true)
                end
                
                table.insert(valid_commands, {
                    name = zone.name,
                    func = send,
                    arg = zone
                })
            end
        end

        if #valid_commands > 0 then
            CommandHandler.buildPagedMenuForCoalition(side, CommandHandler.jtac_main_submenu, valid_commands, 1)
        end
    end 

    ---@param u Unit
    function CommandHandler.tallyZone(u)
        if not u or not u.isExist or not u:isExist() then return end
        local function checkTallyZone()
            if not u or not u.isExist or not u:isExist() then return end

            local gr = u:getGroup()
            if gr and gr.isExist and gr:isExist() and u.getCoalition then
                if not u:inAir() then
                    trigger.action.outTextForUnit(u:getID(), "Recon report\n Can only perform recon while airborne.",10)
                    return
                end
                
                local unit_id = u:getID()
                for i,p in ipairs(player_cooldowns) do
                    if p.id == unit_id and timer.getTime() < p.next_avail_report then
                        return trigger.action.outTextForUnit(unit_id, "Next report available shortly.",5)
                    else
                        table.remove(player_cooldowns,i)
                    end
                end

                local unit_coalition = u:getCoalition()
                local found_zone = false
                local altitude_m = u:getPoint().y
                local base_range = 3000
                local max_recon_range = 30000
                local dynamic_recon_range = math.min(base_range + altitude_m, max_recon_range)

                for _,zone in ipairs(zones) do
                    if mist.utils.get2DDist(zone.zone.point,u:getPoint()) < dynamic_recon_range
                    and zone.side ~= unit_coalition
                    then
                        local is_new = false
                        if unit_coalition == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                            table.insert(stats.blue_discovered_zones,zone.name)
                            is_new = true
                        elseif unit_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                            table.insert(stats.red_discovered_zones,zone.name)
                            is_new = true
                        end

                        if is_new then
                            found_zone = true
                            zone:drawF10()
                            CommandHandler.requestMenuRefresh(unit_coalition)
                        end
                    end
                end
                
                if not found_zone then
                    trigger.action.outTextForUnit(unit_id, "Recon report\n Nothing in the vicinity. Next report available shortly.",10)
                    for _,p in ipairs(player_cooldowns) do
                        if p.id == unit_id then return end
                    end
                    table.insert(player_cooldowns, {id=unit_id, next_avail_report=timer.getTime()+120})
                else
                    -- Add XP for intel report
                    local user = ExperienceManager:fetchUser(u)
                    if user then
                        user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_intel_report
                        
                        trigger.action.outTextForUnit(unit_id,"Intel report, +" .. Config.reward_system.xp_per_intel_report .. "XP",10)
                    end
                    trigger.action.outTextForCoalition(unit_coalition, "Recon report\n Newly detected ground targets displayed on your F10 map.",15)
                end
            end
        end
        missionCommands.addCommandForGroup(u:getGroup():getID(),"Intel Report",nil,checkTallyZone,{})
    end
end
