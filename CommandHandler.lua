CommandHandler = {}
do
    local player_cooldowns = {}

    CommandHandler.jtac_main_submenu = nil
    CommandHandler.tasking_main_submenu = nil

    local destroy_task_submenu
    CommandHandler.destroy_page = 1

    function CommandHandler.init()

        -- local function displayStats()
        --     local out_txt = "SITMAP\n"
        --     trigger.action.outTextForCoalition(coalition.side.BLUE,out_txt,10)
        -- end
        -- missionCommands.addCommand("Situation Map",nil,displayStats,{})
        local master_submenu = missionCommands.addSubMenu("Mission Commands",nil)

        local function sendCAScmd()
            -- TheatreCommander.sendCAS(coalition.side.BLUE)
            local to_zone = blue_airbase:getClosestZone(coalition.side.RED,nil,nil,true)
            if to_zone then
                TaskManager:initiateAITask(AITaskTypes.CAS,coalition.side.BLUE,true,to_zone,nil,true)
            end
        end
        missionCommands.addCommand("Send CAS",master_submenu, sendCAScmd,{})
        missionCommands.addCommand("Send SEAD",master_submenu,function ()
            local to_zone = ZoneHandler.getFromName("FOXTROT")
            TaskManager:initiateAITask(AITaskTypes.SEAD,coalition.side.BLUE,true,to_zone,nil,true)
        end)
        missionCommands.addCommand("Send Strike",master_submenu,function ()
            local to_zone = ZoneHandler.getFromName("DELTA")
            TaskManager:initiateAITask(AITaskTypes.STRIKE,coalition.side.BLUE,true,to_zone,nil,true)
        end)
        missionCommands.addCommand("Send Intercept",master_submenu,function ()
            local to_zone = ZoneHandler.getFromName("BRAVO")
            TaskManager:initiateAITask(AITaskTypes.INTERCEPT,coalition.side.BLUE,true,to_zone,nil,true)
        end)
        missionCommands.addCommand("destroy enroute helo",master_submenu,function ()
            for _,enroute in ipairs(EnrouteManager.enroutes) do
                if enroute.ai_task_type == AITaskTypes.CAPTURE_HELO and enroute.side == coalition.side.RED then
                    local gr = Group.getByName(enroute.group_name)
                    if gr and gr:isExist() then
                       trigger.action.explosion(gr:getUnit(1):getPoint(), 1000)
                    end
                    break
                end
            end
        end)
        missionCommands.addCommand("Send AWACS",master_submenu,function ()
            local from_zone = ZoneHandler.getFromName("VAZIANI")
            TaskManager:initiateAITask(AITaskTypes.AWACS,coalition.side.BLUE,true,nil,from_zone,true)
        end)
        missionCommands.addCommand("Send RECON",master_submenu,function ()
            local to_zone = ZoneHandler.getFromName("BRAVO")
            TaskManager:initiateAITask(AITaskTypes.INTERCEPT,coalition.side.BLUE,true,to_zone,nil,true)
        end)
        missionCommands.addCommand("Give stock",master_submenu,function ()
            MissionLogger:info("Giving stock")
            WarehouseManager:handleIncomingSupplies(coalition.side.BLUE,
            {WarehouseManager.StockTypes.AIR_GROUND_BOMBS})
            -- WarehouseManager:attributeAirbaseStock("VAZIANI",coalition.side.BLUE,
            --     {WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE})
        end)
        missionCommands.addCommand("spawn resupply",master_submenu,function ()
            MissionLogger:info("spawnign resupply")
            TheatreCommander.sendWarehouseResupply(coalition.side.BLUE)
            TheatreCommander.sendWarehouseResupply(coalition.side.RED)
        end)
        missionCommands.addCommand("test",master_submenu,function ()
            MissionLogger:info("test command")
            -- TheatreCommander:spawnCommsTowerAtZone("ALPHA",coalition.side.BLUE)
            -- CommandHandler.refreshJtacCmds(coalition.side.BLUE)
        end)
        missionCommands.addCommand("test1",master_submenu,function ()
            MissionLogger:info("test command")
            -- TheatreCommander:spawnCommsTowerAtZone("ALPHA",coalition.side.BLUE)
            -- CommandHandler.refreshJtacCmds(coalition.side.BLUE)
        end)
        missionCommands.addCommand("test2",master_submenu,function ()
            MissionLogger:info("test command")
            -- TheatreCommander:spawnCommsTowerAtZone("ALPHA",coalition.side.BLUE)
            -- CommandHandler.refreshJtacCmds(coalition.side.BLUE)
        end)
        -- destroy_main_submenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "Dev: Destroy Units", nil)
        -- Call the refresh function to build page 1.
    end

    local refresh_timer = nil
    local pending_refresh_sides = {
        [coalition.side.RED] = false,
        [coalition.side.BLUE] = false
    }
    
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

    CommandHandler.group_menus = {}

    ---@param gr Group
    function CommandHandler.initTaskingRequests(gr)
        if not gr or not gr.isExist or not gr:isExist() then return end
        local gr_id = gr:getID()

        if CommandHandler.group_menus[gr_id] then
            -- Remove existing menus
            for i = #CommandHandler.group_menus[gr_id], 1, -1 do
                if CommandHandler.group_menus[gr_id][i].type == "tasking_main" then
                    missionCommands.removeItemForGroup(gr_id, CommandHandler.group_menus[gr_id][i].path)
                    CommandHandler.group_menus[gr_id][i] = nil
                end
            end
        else
            CommandHandler.group_menus[gr_id] = {}
        end

       local tasking_main_submenu = missionCommands.addSubMenuForGroup(gr_id,"Request Tasking",nil)
        table.insert(CommandHandler.group_menus[gr_id], {path=tasking_main_submenu, type="tasking_main"})

        MissionLogger:info(tasking_main_submenu)

        ---@param unit Unit
        ---@param required_tokens number
        ---@return boolean
        local function checkTokens(unit,required_tokens)
            if not unit or not unit.isExist or not unit:isExist() then return false end
            local user = ExperienceManager:fetchUser(unit)
            if not user then return false end
            if user.tokens >= required_tokens then
                return true
            else
                trigger.action.outTextForUnit(unit:getID(),"Insufficient tokens for tasking request.",5)
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


        local cas_target_list = {}
        for _, zone in ipairs(zones) do
            -- Find enemy zones suitable for CAS
            if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name) then 
                -- Add a command for each zone
                table.insert(cas_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
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

        -- Add the CAS category to the main list if targets exist
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
        -- Build the final paginated nested menu
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

        -- If everything fits in 10 slots, just use 10
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
        -- Default to BLUE if no side provided
        if not side then side = coalition.side.BLUE end

        -- Remove old menu if it exists (Specific to the side if you want separate handles, 
        -- but based on your code structure, we clear the global handle)
        if CommandHandler.jtac_main_submenu then
            missionCommands.removeItemForCoalition(side, CommandHandler.jtac_main_submenu)
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

        CommandHandler.jtac_main_submenu = missionCommands.addSubMenuForCoalition(side, "Task JTAC", nil)

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
                    if live_comms < Config.tasking_requirements.comms_zones_required_for_jtac then
                        trigger.action.outTextForCoalition(side, "JTAC tasking requires " .. Config.tasking_requirements.comms_zones_required_for_jtac .. "/"..Config.max_comms_zones.." active COMMS antennas.", 10)
                        return
                    end

                    TaskManager:initiateAITask(AITaskTypes.JTAC, side, true, zone_check, nil, true)
                end
                
                missionCommands.addCommandForCoalition(side, zone.name, CommandHandler.jtac_main_submenu, send, zone)
            end
        end
    end 

    ---@param u Unit
    function CommandHandler.tallyZone(u)
        if not u or not u.isExist or not u:isExist() then return end
        local function checkTallyZone()
            if not u or not u.isExist or not u:isExist() then return end

            local gr = u:getGroup()
            if gr and gr.isExist and gr:isExist() and u.getCoalition then
                -- checks if the player is airborne
                if u:inAir() then
                    trigger.action.outTextForUnit(u:getID(), "Recon report\n Cannot perform recon while airborne.",10)
                    return
                end

                
                -- checks if player is on cooldown
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

                -- Formula: 3km base + 1m of range for every 1m of altitude, capped at 30km
                local dynamic_recon_range = math.min(base_range + altitude_m, max_recon_range)

                for _,zone in ipairs(zones) do
                    if mist.utils.get2DDist(zone.zone.point,u:getPoint()) < dynamic_recon_range
                    and zone.side ~= unit_coalition
                    then
                        if unit_coalition == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                            table.insert(stats.blue_discovered_zones,zone.name)
                            found_zone = true
                            zone:drawF10()
                            -- CommandHandler.refreshJtacCmds(unit_coalition)
                            CommandHandler.requestMenuRefresh(unit_coalition)
                            -- trigger.action.outTextForCoalition(unit_coalition, "Recon reports newly detected targets in: "..zone.name,15)
                        elseif unit_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                            table.insert(stats.red_discovered_zones,zone.name)
                            found_zone = true
                            zone:drawF10()
                            -- CommandHandler.refreshJtacCmds(unit_coalition)
                            CommandHandler.requestMenuRefresh(unit_coalition)
                            -- trigger.action.outTextForCoalition(unit_coalition, "Recon reports newly detected targets in: "..zone.name,15)
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
                        user.xp = user.xp + Config.reward_system.xp_per_intel_report
                        trigger.action.outTextForUnit(unit_id,"Intel report, +" .. Config.reward_system.xp_per_intel_report .. "XP",10)
                    end

                    trigger.action.outTextForCoalition(unit_coalition, "Recon report\n Newly detected ground targets displayed on your F10 map.",15)

                end
            end
        end
        missionCommands.addCommandForGroup(u:getGroup():getID(),"Intel Report",nil,checkTallyZone,{})
    end

end