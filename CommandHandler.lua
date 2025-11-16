CommandHandler = {}
do
    local player_cooldowns = {}

    local destroy_task_submenu
    CommandHandler.destroy_page = 1

    function CommandHandler.init()
        local function displayStats()
            local out_txt = "SITMAP\n"
            trigger.action.outTextForCoalition(coalition.side.BLUE,out_txt,10)
        end
        missionCommands.addCommand("Situation Map",nil,displayStats,{})
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
        missionCommands.addCommand("Send AWACS",master_submenu,function ()
            local from_zone = ZoneHandler.getFromName("VAZIANI")
            TaskManager:initiateAITask(AITaskTypes.AWACS,coalition.side.BLUE,true,nil,from_zone,true)
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


        -- missionCommands.addCommand("destroy",master_submenu,function ( )
        --     local units = utils.getUnitsInZoneObj(ZoneHandler.getFromName("ECHO"),coalition.side.RED)
        --     for _, unit in ipairs(units) do
        --         if unit and unit.isExist and unit:isExist() then
        --             MissionLogger:info("Destroying unit: " .. unit:getName())
        --             local p = unit:getPoint()
        --             if p then
        --                 trigger.action.explosion(p, 100)
        --             end
        --         end
        --     end
        -- end)



        missionCommands.addCommand("destroy comms", nil, function()
            for _,zone in ipairs(zones) do
                if zone.zone_type == ZoneTypes.COMMS then
                    local comms_tower = StaticObject.getByName(zone.linked_statics[1])
                    if comms_tower and comms_tower:isExist() then
                        trigger.action.explosion(comms_tower:getPoint(), 20000)
                        break
                    end
                end
            end

        local ammo_depot = ZoneHandler.getFromName("LOGIS").linked_ammo_depot

        trigger.action.explosion(
        StaticObject.getByName(ammo_depot):getPoint(),20000)
        end)
        -- missionCommands.addCommand("destroy kjtac",nil, function ()
        --     for i,jtac in ipairs(enroute_jtac) do
        --         local jtac_gr = Group.getByName(jtac.jtac_gr_name)
        --         trigger.action.explosion(jtac_gr:getUnit(1):getPoint(), 1)

        --         -- table.remove(enroute_jtac,i)
        --     end
        -- end,{})


        -- destroy_main_submenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE, "Dev: Destroy Units", nil)
        -- Call the refresh function to build page 1.
        CommandHandler.refreshDestroyZoneMenu()



    end


    function CommandHandler.refreshDestroyZoneMenu()
        -- 1. (SPECIFIC) Clear the old menu
        if destroy_task_submenu then
            missionCommands.removeItemForCoalition(coalition.side.BLUE, destroy_task_submenu)
        end

        -- 2. (SPECIFIC) Collect all valid zones to list
        local valid_zones = {}
        for _, zone in ipairs(zones) do
            -- Add all zones to the list
            table.insert(valid_zones, zone)
        end
        
        -- 3. (SPECIFIC) Define what to do when an item is clicked
        local function onDestroyZoneClick(zone)
            trigger.action.outTextForCoalition(coalition.side.BLUE, "Executing... Destroying all units in " .. zone.name, 5)
            
            -- Get all units in the zone, regardless of side
            local units_in_zone = utils.getUnitsInZoneObj(zone)
            
            if #units_in_zone == 0 then
                trigger.action.outTextForCoalition(coalition.side.BLUE, "No units found in " .. zone.name, 5)
                return
            end

            -- Loop and destroy with explosions
            for _, unit in ipairs(units_in_zone) do
                if unit and unit:isExist() then
                    local p = unit:getPoint()
                    if p then
                        trigger.action.explosion(p, 100) 
                    end
                end
            end
            trigger.action.outTextForCoalition(coalition.side.BLUE, "Destroyed " .. #units_in_zone .. " units in " .. zone.name, 7)
        end

        -- 4. (SPECIFIC) Define how to display an item
        local function displayDestroyZone(item)
            -- Show the zone name and its current side
            return item.name .. " (" .. utils.coalitionToString(item.side) .. ")"
        end

        -- 5. (GENERIC) Call the builder
        destroy_task_submenu = CommandHandler.buildPaginatedMenu({
            coalition = coalition.side.BLUE,
            parentMenu = nil,
            submenuTitle = "Dev: Destroy Units",
            itemList = valid_zones,
            pageTrackerTable = CommandHandler,
            pageTrackerKey = "destroy_page",
            itemDisplayFunc = displayDestroyZone,
            itemClickFunc = onDestroyZoneClick,
            rebuildFunc = CommandHandler.refreshDestroyZoneMenu,
            noItemsText = "(No Zones Found)"
        })
    end

    ---
    --- GENERIC FUNCTION: Builds a paginated F10 menu.
    ---
    ---@param config table Configuration table for the menu
    ---  - coalition: (coalition.side) The coalition to show the menu to
    ---  - parentMenu: (table) The parent menu handle (e.g., CommandHandler.jtac_main_submenu)
    ---  - submenuTitle: (string) The title for the new submenu (e.g., "Task JTAC")
    ---  - itemList: (table) The pre-filtered list of items to display (e.g., valid_zones)
    ---  - pageTrackerTable: (table) The table holding the page variable (e.g., CommandHandler)
    ---  - pageTrackerKey: (string) The key for the page variable (e.g., "jtac_page_blue")
    ---  - itemDisplayFunc: (function) Takes one item, returns string to display (e.g., function(item) return item.name end)
    ---  - itemClickFunc: (function) The function to call when an item is clicked
    ---  - rebuildFunc: (function) The function to call to rebuild this menu (e.g., CommandHandler.refreshAvailZonesJTAC)
    ---  - noItemsText: (string) (Optional) Text to show if itemList is empty
    ---  - itemsPerPage: (number) (Optional) Max items per page
    ---@return table The handle for the newly created submenu
    function CommandHandler.buildPaginatedMenu(config)
        -- 1. Unpack config and set defaults
        local cfg = config
        local items_per_page = cfg.itemsPerPage or 8
        local no_items_text = cfg.noItemsText or "(No Items)"
        local page_tracker_table = cfg.pageTrackerTable
        local page_tracker_key = cfg.pageTrackerKey

        -- 2. Initialize page tracker if it doesn't exist
        if not page_tracker_table[page_tracker_key] then
            page_tracker_table[page_tracker_key] = 1
        end

        -- 3. Calculate page numbers
        local item_list = cfg.itemList
        local total_items = #item_list
        local total_pages = math.ceil(total_items / items_per_page)
        if total_pages == 0 then total_pages = 1 end

        -- 4. Validate current page (it might be out of bounds if items were removed)
        if page_tracker_table[page_tracker_key] > total_pages then
            page_tracker_table[page_tracker_key] = total_pages
        end
        if page_tracker_table[page_tracker_key] < 1 then
            page_tracker_table[page_tracker_key] = 1
        end
        
        local page = page_tracker_table[page_tracker_key]
        local start_index = ((page - 1) * items_per_page) + 1
        local end_index = math.min(page * items_per_page, total_items)

        -- 5. Create the new submenu
        local new_submenu = missionCommands.addSubMenuForCoalition(cfg.coalition, cfg.submenuTitle, cfg.parentMenu)

        -- 6. Add the item commands for the current page
        if total_items > 0 then
            for i = start_index, end_index do
                local item = item_list[i]
                -- Get the display text from the provided function
                local display_text = cfg.itemDisplayFunc(item)
                
                -- We must wrap the click function to pass the item
                local function item_click_wrapper()
                    cfg.itemClickFunc(item)
                end
                missionCommands.addCommandForCoalition(cfg.coalition, display_text, new_submenu, item_click_wrapper)
            end
        else
            missionCommands.addCommandForCoalition(cfg.coalition, no_items_text, new_submenu, function() end)
        end

        -- 7. Add Page Navigation commands
        local page_text = " (Page " .. page .. "/" .. total_pages .. ")"

        if page > 1 then
            local function prev_page()
                page_tracker_table[page_tracker_key] = page_tracker_table[page_tracker_key] - 1
                cfg.rebuildFunc() -- Rebuild the menu
            end
            missionCommands.addCommandForCoalition(cfg.coalition, "... (Previous)" .. page_text, new_submenu, prev_page)
        end

        if end_index < total_items then
            local function next_page()
                page_tracker_table[page_tracker_key] = page_tracker_table[page_tracker_key] + 1
                cfg.rebuildFunc() -- Rebuild the menu
            end
            missionCommands.addCommandForCoalition(cfg.coalition, "... (Next)" .. page_text, new_submenu, next_page)
        end
        
        if page > 1 and total_pages > 1 then
            local function first_page()
                page_tracker_table[page_tracker_key] = 1
                cfg.rebuildFunc() -- Rebuild the menu
            end
            missionCommands.addCommandForCoalition(cfg.coalition, "... (Back to Page 1)", new_submenu, first_page)
        end
        
        return new_submenu
    end


    CommandHandler.jtac_main_submenu = nil
    local jtac_task_submenu
    function CommandHandler.initJTAC() --WARN this neeeds to be called every time a new zone is discovered  
        CommandHandler.jtac_main_submenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE,"JTAC",nil)
        jtac_task_submenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE,"Task JTAC",CommandHandler.jtac_main_submenu)
        CommandHandler.refreshAvailZonesJTAC()

    end

    ---Adds all discovered enemy zones to a submenu 
    ---@param friendly_side coalition.side
    ---@param submenu table
    ---@param func function 
    ---@param vars table
    function CommandHandler.addEnemyZonesToMenu(friendly_side,submenu,func,vars)
        for _,zone in ipairs(zones) do
            local discovered = false
            if zone.side == coalition.side.BLUE then discovered = utils.tableContains(stats.blue_discovered_zones,zone.name)
            elseif zone.side == coalition.side.RED then discovered = utils.tableContains(stats.red_discovered_zones,zone.name) end

            if zone.side == friendly_side and discovered
            and not EnrouteManager:findByToZone(zone) then
                missionCommands.addCommandForCoalition(coalition.side.BLUE,zone.name,submenu,func,vars)
            end
        end
    end

    function CommandHandler.refreshAvailZonesJTAC()
        if CommandHandler.jtac_main_submenu then
            missionCommands.removeItemForCoalition(coalition.side.BLUE,jtac_task_submenu)
        end

        jtac_task_submenu = missionCommands.addSubMenuForCoalition(coalition.side.BLUE,"Task JTAC",CommandHandler.jtac_main_submenu)

        for _,zone in ipairs(zones) do
            if zone.side == coalition.side.RED and utils.tableContains(stats.blue_discovered_zones,zone.name)
            and not EnrouteManager:findByToZone(zone,zone.side,{AITaskTypes.JTAC}) then
                local function send(to_zone)
                    TaskManager:initiateAITask(AITaskTypes.JTAC,coalition.side.BLUE,true,to_zone,nil,true)
                end
                missionCommands.addCommandForCoalition(coalition.side.BLUE,zone.name,jtac_task_submenu,send,zone)
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
                            -- trigger.action.outTextForCoalition(unit_coalition, "Recon reports newly detected targets in: "..zone.name,15)
                        elseif unit_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                            table.insert(stats.red_discovered_zones,zone.name)
                            found_zone = true
                            zone:drawF10()
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