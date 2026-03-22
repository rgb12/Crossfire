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
            local group = unit:getGroup()
            if not group then return end
            local group_id = group:getID()
            if not group_id then return end
    
            local sitmap_path = missionCommands.addCommandForGroup(group_id, "SITMAP", nil, function()
                local out_text = "SITMAP\n\n"
                out_text = out_text .. "REDFOR controls " .. stats.red_zones .. " areas.\n"
                out_text = out_text .. "BLUFOR controls " .. stats.blue_zones .. " areas.\n"
                out_text = out_text .. "Neutral areas: " .. stats.neutral_zones .. "\n\n"

                local total_zones = stats.red_zones + stats.blue_zones + stats.neutral_zones

                if unit:getCoalition() == coalition.side.RED then
                    out_text = out_text .. "Your forces control " .. stats.red_zones .. "/" .. total_zones .. " areas.\n"
                else
                    out_text = out_text .. "Your forces control " .. stats.blue_zones .. "/" .. total_zones .. " areas.\n"
                end
                trigger.action.outTextForGroup(group_id, out_text, 15)
                trigger.action.outSoundForGroup(group_id, "Radio squelch.ogg")
            end, nil)

            CommandHandler.addToMenuTracking(group_id, sitmap_path, "sitmap")

            ctld.initF10RadioMenu(group)
        end
    end

    local refresh_timer = nil
    local pending_refresh_sides = {
        [coalition.side.RED] = false,
        [coalition.side.BLUE] = false
    }

    function CommandHandler.clearMenu(gr, type)
        if not gr then return end
        local gr_id = gr:getID()

        if CommandHandler.group_menus[gr_id] then
            -- Remove existing menus. 
            for i = #CommandHandler.group_menus[gr_id], 1, -1 do
                if CommandHandler.group_menus[gr_id][i].type == type then
                    missionCommands.removeItemForGroup(gr_id, CommandHandler.group_menus[gr_id][i].path)
                    table.remove(CommandHandler.group_menus[gr_id], i)
                end
            end
        end
    end

    ---@param gr Group
    function CommandHandler.clearF10(gr)
        if not gr or not gr.isExist or not gr:isExist() then return end
        local gr_id = gr:getID()

        if CommandHandler.group_menus[gr_id] then
            -- Remove existing menus. 
            for i = #CommandHandler.group_menus[gr_id], 1, -1 do
                missionCommands.removeItemForGroup(gr_id, CommandHandler.group_menus[gr_id][i].path)
                table.remove(CommandHandler.group_menus[gr_id], i)
            end
        end
    end

    function CommandHandler.addToMenuTracking(gr_id, menu_path, menu_type)
        if not CommandHandler.group_menus[gr_id] then
            CommandHandler.group_menus[gr_id] = {}
        end
        table.insert(CommandHandler.group_menus[gr_id], {path=menu_path, type=menu_type})
    end

    ---@param gr Group
    ---@param unit Unit
    function CommandHandler.operationsMenu(gr,unit)
        if not gr or not gr.isExist or not gr:isExist() then return end
        if not unit or not unit:isExist() then return end
        if unit.getPlayerName and unit:getPlayerName() and unit.getCoalition then

            local operation_manager = nil
            if unit:getCoalition() == coalition.side.RED then
                operation_manager = TheatreCommander.red_op_manager
            elseif unit:getCoalition() == coalition.side.BLUE then
                operation_manager = TheatreCommander.blue_op_manager
            end
            if not operation_manager then return end

            local group_id = gr:getID()

            local missions_submenu = missionCommands.addSubMenuForGroup(group_id, "Operations")
            CommandHandler.addToMenuTracking(group_id, missions_submenu, "operations_menu")

            missionCommands.addCommandForGroup(group_id, "Available Operations", missions_submenu,function()
                operation_manager:showAvailableOperations(unit)
            end)

            missionCommands.addCommandForGroup(group_id, "Active Operation", missions_submenu,function()
                operation_manager:showActiveOperation(unit)
            end)
            local cancel_op_menu = missionCommands.addSubMenuForGroup(group_id, "Cancel Active Operation",missions_submenu)

            missionCommands.addCommandForGroup(group_id, "Confirm (Cancel Active Operation)", cancel_op_menu,function()
                operation_manager:cancelOperation(unit)
            end)


            local join_operation_menu = missionCommands.addSubMenuForGroup(group_id, "Initiate Operation", missions_submenu)

            for i1 = 1, 9 do
                local digit1 = missionCommands.addSubMenuForGroup(group_id, i1 .. ' _ _', join_operation_menu)
                for i2 = 0, 9 do
                    local digit2 = missionCommands.addSubMenuForGroup(group_id, i1 .. i2 .. ' _', digit1)
                    for i3 = 0, 9 do
                        local code = tonumber(i1 .. i2 .. i3)
                        missionCommands.addCommandForGroup(group_id,tostring(code), digit2,
                            function(c,u)
                                
                                if u and u:getCoalition() == operation_manager.side then
                                    operation_manager:activateOperation(u, c)
                                end
                            end, code, unit)
                    end
                end
            end

            -- Co-op Operations Menu
            local coop_submenu = missionCommands.addSubMenuForGroup(group_id, "Co-op Operations", missions_submenu)

            local join_coop_menu = missionCommands.addSubMenuForGroup(group_id, "Join CO-OP", coop_submenu)
            
            for i1 = 1, 9 do
                local digit1 = missionCommands.addSubMenuForGroup(group_id, i1 .. ' _ _', join_coop_menu)
                for i2 = 0, 9 do
                    local digit2 = missionCommands.addSubMenuForGroup(group_id, i1 .. i2 .. ' _', digit1)
                    for i3 = 0, 9 do
                        local join_code = tonumber(i1 .. i2 .. i3)
                        missionCommands.addCommandForGroup(group_id, tostring(join_code), digit2,
                            function(code, unit)
                                if unit and unit:getCoalition() == operation_manager.side then
                                    operation_manager:joinCoopOperation(unit, code)
                                end
                            end, join_code, unit)
                    end
                end
            end

            missionCommands.addCommandForGroup(group_id, "Leave CO-OP", coop_submenu, function()
                operation_manager:leaveCoopOperation(unit)
            end)

            missionCommands.addCommandForGroup(group_id, "CO-OP Status", coop_submenu, function()
                operation_manager:showCoopOperationStatus(unit)
            end)
        end
    end

    ---@param gr Group
    function CommandHandler.resourcesRequests(gr)

        if not gr or not gr.isExist or not gr:isExist() then return end
        local gr_id = gr:getID()

        -- Clear existing resources menu before rebuilding
        CommandHandler.clearMenu(gr, "logistics_main")

          -- Create the root menu for this update
        local logistics_main_submenu = missionCommands.addSubMenuForGroup(gr_id,"Logistics",nil)
        CommandHandler.addToMenuTracking(gr_id, logistics_main_submenu, "logistics_main")
        local unit = gr:getUnit(1)
        if unit and unit:isExist() and unit.getCoalition then
            local side = unit:getCoalition()

            --- returns true if aircraft is moving
            ---@param u Unit
            ---@return boolean
            local function aircraftMoving(u)
                if not u or not u.isExist or not u:isExist() then return false end
                local speed = u:getVelocity()
                local horizontal_speed = math.sqrt(speed.x^2 + speed.z^2)
                if horizontal_speed > 1 then -- 1 m/s threshold
                    return true
                end
                return false
            end


            missionCommands.addCommandForGroup(gr_id, "List Supplies", logistics_main_submenu, function ()
                ctld.listSupplies(unit)
            end)

            -----------------------------------------------------------------------
            -- RESUPPLY REQUEST LOGIC
            
            -- Build list of friendly airbases for resupply target selection
            local friendly_airbases = {}
            for _, zone in ipairs(zones) do
                if zone.side == side and zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                    table.insert(friendly_airbases, zone)
                end
            end

            -- Helper function to build airbase submenu for a stock type
            local function buildAirbaseSubmenu(stock_types, cost, stock_name)
                local airbase_list = {}
                for _, ab_zone in ipairs(friendly_airbases) do
                    table.insert(airbase_list, {
                        name = ab_zone.name,
                        func = function(args)
                            local u = args.u
                            local target_zone = args.target_zone
                            local stock = args.stock_types
                            local cost = args.cost

                            -- Check if airbase is still friendly before sending 
                            local ab = ZoneHandler.getFromName(target_zone.name)
                            if not ab then return end
                            if ab.side ~= side then
                                trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. target_zone.name .. ": area lost. Stand by for next resupply or capture additional zones.",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end


                            if side == 2 then
                                if stats.blue_supplies < cost then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. target_zone.name .. ": supplies low (" .. stats.blue_supplies .. "/" .. cost .. "). Stand by for next resupply or capture additional zones.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                                else
                                    stats.blue_supplies = math.max(stats.blue_supplies - cost,0)
                                end
                            elseif side == 1 then
                               if stats.red_supplies < cost then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. target_zone.name .. ": supplies low (" .. stats.red_supplies .. "/" .. cost .. "). Stand by for next convoy or secure more territory.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                               else
                                    stats.red_supplies = math.max(stats.red_supplies - cost,0)
                                end
                            end
                            TheatreCommander.sendWarehouseResupply(side, false, stock, target_zone)
                            trigger.action.outTextForGroup(gr_id,"HQ Resupply dispatched for " .. target_zone.name .. ": " .. args.stock_name .. ".",10)
                            trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                        end,
                        arg = {u = unit, target_zone = ab_zone, stock_types = stock_types, cost = cost, stock_name = stock_name}
                    })
                end
                return airbase_list
            end

            local resupply_menu = missionCommands.addSubMenuForGroup(gr_id, "Request Resupply", logistics_main_submenu)
            
            local resupply_stock_list = {}
            
            
            -- AA Aircraft
            local aa_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AA_AIRCRAFT}, Config.supplies.resupply_costs.AA_AIRCRAFT, "AA Aircraft")
            if #aa_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AA Aircraft - " .. Config.supplies.resupply_costs.AA_AIRCRAFT .. " supplies",
                    submenu = aa_aircraft_airbases
                })
            end
            
            -- AG Aircraft
            local ag_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AG_AIRCRAFT}, Config.supplies.resupply_costs.AG_AIRCRAFT, "AG Aircraft")
            if #ag_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Aircraft - " .. Config.supplies.resupply_costs.AG_AIRCRAFT .. " supplies",
                    submenu = ag_aircraft_airbases
                })
            end
            
            -- Cargo Aircraft
            local cargo_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.CARGO_AIRCRAFT}, Config.supplies.resupply_costs.CARGO_AIRCRAFT, "Cargo Aircraft")
            if #cargo_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Cargo Aircraft - " .. Config.supplies.resupply_costs.CARGO_AIRCRAFT .. " supplies",
                    submenu = cargo_aircraft_airbases
                })
            end
            
            -- Long Range AA
            local aa_lr_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE}, Config.supplies.resupply_costs.AIR_AIR_LONG_RANGE, "Long Range AA")
            if #aa_lr_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Long Range AA - " .. Config.supplies.resupply_costs.AIR_AIR_LONG_RANGE .. " supplies",
                    submenu = aa_lr_airbases
                })
            end
            
            -- Short Range AA
            local aa_sr_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE}, Config.supplies.resupply_costs.AIR_AIR_SHORT_RANGE, "Short Range AA")
            if #aa_sr_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Short Range AA - " .. Config.supplies.resupply_costs.AIR_AIR_SHORT_RANGE .. " supplies",
                    submenu = aa_sr_airbases
                })
            end
            
            -- AG Bombs
            local ag_bombs_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_BOMBS}, Config.supplies.resupply_costs.AIR_GROUND_BOMBS, "AG Bombs")
            if #ag_bombs_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Bombs - " .. Config.supplies.resupply_costs.AIR_GROUND_BOMBS .. " supplies",
                    submenu = ag_bombs_airbases
                })
            end
            
            -- AG Rockets
            local ag_rockets_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_ROCKETS}, Config.supplies.resupply_costs.AIR_GROUND_ROCKETS, "AG Rockets")
            if #ag_rockets_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Rockets - " .. Config.supplies.resupply_costs.AIR_GROUND_ROCKETS .. " supplies",
                    submenu = ag_rockets_airbases
                })
            end
            
            -- AG Guided Bombs
            local ag_guided_bombs_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS}, Config.supplies.resupply_costs.AIR_GROUND_GUIDED_BOMBS, "AG Guided Bombs")
            if #ag_guided_bombs_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Guided Bombs - " .. Config.supplies.resupply_costs.AIR_GROUND_GUIDED_BOMBS .. " supplies",
                    submenu = ag_guided_bombs_airbases
                })
            end
            
            -- AG Missiles
            local ag_missiles_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES}, Config.supplies.resupply_costs.AIR_GROUND_GUIDED_MISSILES, "AG Missiles")
            if #ag_missiles_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Missiles - " .. Config.supplies.resupply_costs.AIR_GROUND_GUIDED_MISSILES .. " supplies",
                    submenu = ag_missiles_airbases
                })
            end
            
            -- ECM
            local ecm_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.ECM}, Config.supplies.resupply_costs.ECM, "ECM")
            if #ecm_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "ECM - " .. Config.supplies.resupply_costs.ECM .. " supplies",
                    submenu = ecm_airbases
                })
            end
            
            -- TGP, Misc
            local tgp_misc_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.TGP, WarehouseManager.StockTypes.MISC}, Config.supplies.resupply_costs.TGP_MISC, "TGP/Misc")
            if #tgp_misc_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "TGP, Misc - " .. Config.supplies.resupply_costs.TGP_MISC .. " supplies",
                    submenu = tgp_misc_airbases
                })
            end
            
            -- Initial Stock
            local initial_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.INITIAL}, Config.supplies.resupply_costs.INITIAL, "Initial Stock")
            if #initial_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Initial Stock - " .. Config.supplies.resupply_costs.INITIAL .. " supplies",
                    submenu = initial_airbases
                })
            end
            
            if #resupply_stock_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, resupply_menu, resupply_stock_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No Airbases Available", resupply_menu, function() end, nil)
            end
            
            
            
            local farps_resupply_list = {}
            -- Add FARP zones
            for _,zone in ipairs(zones) do
                if zone.side == side and zone.zone_type == ZoneTypes.FARP and zone.linked_farp then
                    table.insert(farps_resupply_list, {
                        name = zone.name .. " - " .. Config.supplies.resupply_costs.FARP .. " supplies",
                        func = function (args)
                            local coal = args.side
                            local farp = args.farp_name
                            local name = args.name

                            if side == 2 then
                                if stats.blue_supplies < Config.supplies.resupply_costs.FARP then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. name .. ": supplies low (" .. stats.blue_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. "). Stand by for next resupply or capture additional zones.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                                else
                                    stats.blue_supplies = math.max(stats.blue_supplies - Config.supplies.resupply_costs.FARP,0)
                                end
                            elseif side == 1 then
                               if stats.red_supplies < Config.supplies.resupply_costs.FARP then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. name .. ": supplies low (" .. stats.red_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. "). Stand by for next convoy or secure more territory.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                               else
                                    stats.red_supplies = math.max(stats.red_supplies - Config.supplies.resupply_costs.FARP,0)
                               end
                            end
                            WarehouseManager:attributeAirbaseStock(farp,coal, {WarehouseManager.StockTypes.FARP})
                            trigger.action.outTextForCoalition(coal, "FARP " .. name .. " has been resupplied.", 10)
                            trigger.action.outSoundForCoalition(coal,"radio_txrx.ogg")
                        end,
                        arg = {side = side, farp_name = zone.linked_farp,name = zone.name}})
                end
            end
            -- Add CTLD FARPs
            for _,farp in ipairs(ctld.FARPs) do
                if farp.coalition == side then
                    table.insert(farps_resupply_list, {
                        name = farp.display_name .. " - " .. Config.supplies.resupply_costs.FARP .. " supplies",
                        func = function (args)
                            local coal = args.side
                            local farp_name = args.farp_name
                            local name = args.name

                            if side == 2 then
                                if stats.blue_supplies < Config.supplies.resupply_costs.FARP then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. name .. ": supplies low (" .. stats.blue_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. "). Stand by for next resupply or capture additional zones.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                                else
                                    stats.blue_supplies = math.max(stats.blue_supplies - Config.supplies.resupply_costs.FARP,0)
                                end
                            elseif side == 1 then
                               if stats.red_supplies < Config.supplies.resupply_costs.FARP then
                                    trigger.action.outTextForGroup(gr_id,"HQ Negative resupply response for " .. name .. ": supplies low (" .. stats.red_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. "). Stand by for next convoy or secure more territory.",8)
                                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                    return
                               else
                                    stats.red_supplies = math.max(stats.red_supplies - Config.supplies.resupply_costs.FARP,0)
                               end
                            end
                            WarehouseManager:attributeAirbaseStock(farp_name,coal, {WarehouseManager.StockTypes.FARP})
                            trigger.action.outTextForCoalition(coal,name .. " has been resupplied.", 10)
                            trigger.action.outSoundForCoalition(coal,"radio_txrx.ogg")
                        end,
                        arg = {side = side, farp_name = farp.farp_name,name = farp.display_name}})
                end
            end

            local farp_resupply_menu = missionCommands.addSubMenuForGroup(gr_id,"FARP Resupply", logistics_main_submenu)
            if #farps_resupply_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, farp_resupply_menu, farps_resupply_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No FARPs Available", logistics_main_submenu, function() end, nil)
            end


            -- local  upgrade_submenu = missionCommands.addSubMenuForGroup(gr_id, "Request Upgrade", logistics_main_submenu)
            -- if #upgrade_zone_list > 0 then
            --     CommandHandler.buildPagedMenuForGroup(gr_id, upgrade_submenu, upgrade_zone_list, 1)
            -- else
            --     missionCommands.addCommandForGroup(gr_id, "No Zones Available", logistics_main_submenu, function() end, nil)
            -- end

            ---------------------------------------------------------------
            -- Restock Aircraft
            local restock_submenu = missionCommands.addSubMenuForGroup(gr_id, "Restock Aircraft", logistics_main_submenu)
            missionCommands.addCommandForGroup(gr_id, "Confirm (destroy)", restock_submenu, function()
                local point = unit:getPoint()
                -- Checks if aircraft is not moving and on ground
                local aircraft_on_carrier = false
                local on_carrier = false
                if  land.getSurfaceType{ x = point.x, y = point.z } == land.SurfaceType.WATER
                and not unit:inAir() then
                    aircraft_on_carrier = true
                end

                if not aircraft_on_carrier then
                    if aircraftMoving(unit) or unit:inAir() then
                        trigger.action.outTextForGroup(gr_id, "Restock aborted: Aircraft is not stationary.", 10)
                        trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                        return
                    end
                else
                    local carrier_unit = Unit.getByName("Carrier")
                    if carrier_unit and carrier_unit:isExist() then
                        local carrier_point = carrier_unit:getPoint()
                        local dist_to_carrier = mist.utils.get2DDist(point, carrier_point)
                        if dist_to_carrier <= 500 then
                            on_carrier = true
                        else
                            trigger.action.outTextForGroup(gr_id, "Restock aborted: Aircraft is not on carrier deck.", 10)
                            trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                            return
                        end
                    else
                        trigger.action.outTextForGroup(gr_id, "Restock aborted: Carrier unit not found.", 10)
                        trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                        return
                    end
                end
                trigger.action.outTextForGroup(gr_id, "Aircraft and loaded equipment will be restocked in the warehouse in 10 seconds…", 10)
                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                timer.scheduleFunction(function()

                    -- Add the aircraft back to the warehouse
                    if on_carrier then
                        if gr and gr:isExist() then
                            return gr:destroy()
                        end
                    else
                        for _,zone in ipairs(zones) do
                            if (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP) and zone.side == side
                            and zone:isPointInsideZone(point)then
                                if gr and gr:isExist() then
                                    return gr:destroy()
                                end
                            end
                        end

                    end
                    trigger.action.outTextForGroup(gr_id, "Restock aborted: No friendly airbase or FARP nearby.", 10)
                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                end, {}, timer.getTime() + 10)
            end, nil)

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
                
                local red_players = coalition.getPlayers(coalition.side.RED)
                for _, unit in ipairs(red_players) do
                    if unit and unit:isExist() then
                        local gr = unit:getGroup()
                        if gr then
                            CommandHandler.initTaskingRequests(gr)
                            CommandHandler.resourcesRequests(gr)
                        end
                    end
                end
                
                -- Reset flag
                pending_refresh_sides[coalition.side.RED] = false
            end

            -- CHECK BLUE
            if pending_refresh_sides[coalition.side.BLUE] then
                MissionLogger:info("Refreshing BLUE menus")
                
                local blue_players = coalition.getPlayers(coalition.side.BLUE)
                for _, unit in ipairs(blue_players) do
                    if unit and unit:isExist() then
                        local gr = unit:getGroup()
                        if gr then
                            CommandHandler.initTaskingRequests(gr)
                            CommandHandler.resourcesRequests(gr)
                        end
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

        CommandHandler.clearMenu(gr, "tasking_main")

        -- Create the root menu for this update
        local tasking_main_submenu = missionCommands.addSubMenuForGroup(gr_id,"Request Tasking",nil)
        CommandHandler.addToMenuTracking(gr_id, tasking_main_submenu, "tasking_main")


        local side = gr:getCoalition()
        local side_comms_towers = 0
        if side == coalition.side.BLUE then
            side_comms_towers = stats.blue_comms_antennas
        elseif side == coalition.side.RED then
            side_comms_towers = stats.red_comms_antennas
        end

        local function deductSupplies(required_supplies)
            if side == coalition.side.BLUE then
                stats.blue_supplies = math.max(stats.blue_supplies - required_supplies,0)
            elseif side == coalition.side.RED then
                stats.red_supplies = math.max(stats.red_supplies - required_supplies,0)
            end
        end

        local function checkSupplies(unit, required_supplies)
            if side == coalition.side.BLUE  then
                if stats.blue_supplies >= required_supplies then
                    return true
                else
                    trigger.action.outTextForGroup(gr_id,"Negative, coalition lacks the necessary supplies to support this mission. ".. stats.blue_supplies.."/"..required_supplies,5)
                    trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                    return false
                end
            elseif side == coalition.side.RED then
                if stats.red_supplies >= required_supplies then
                    return true
                else
                    trigger.action.outTextForGroup(gr_id,"Negative, coalition lacks the necessary supplies to support this mission. ".. stats.red_supplies.."/"..required_supplies,5)
                    trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                    return false
                end
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
                trigger.action.outTextForUnit(unit:getID(),"Negative, insufficient rank for this tasking request.\nRequired rank: "..rankreq..", ".. required_xp .." XP",5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return false
            end
        end

        local unit = gr:getUnit(1)
        if not unit or not unit:isExist() or not unit.getCoalition then return end
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
                table.insert(cas_target_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cas then
                            trigger.action.outTextForGroup(gr_id, "Negative, CAS tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_cas.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.CAS) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.CAS) then return end

                        if TaskManager:initiateAITask(AITaskTypes.CAS, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.CAS)
                            trigger.action.outTextForCoalition(side, "Request accepted, CAS dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.CAS.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "CAS request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                        end
                    end,
                    arg = {u = unit, z = zone}
                })
            end
        end

        local attack_ship_name = Scenario.carrier_setup.tomahawk_launcher_unit_name
        local naval_strike_list = {}
        if Scenario.carrier_setup.enabled and attack_ship_name then
                for _, zone in ipairs(zones) do
                -- Find enemy zones suitable for CAS
                if zone.side == enemy_side and utils.tableContains(discovered_zones, zone.name) then 
                    table.insert(naval_strike_list, {
                        name = zone.name,
                        func = function (args)
                            local u = args.u
                            local to_zone = args.z
    
                            local u_xp = ExperienceManager:fetchUser(u)
                            if not u_xp then
                                trigger.action.outTextForGroup(gr_id,"Could not fetch user data",10)
                                return
                            end

                            if u_xp and u_xp.xp < Config.reward_system.naval_stike_xp_required then
                                trigger.action.outTextForGroup(gr_id,"Not authorized, required rank: "..ExperienceManager:getRankfromXP(Config.reward_system.naval_stike_xp_required),10)
                                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                                return
                            end

                            if not checkRankRequirement(u, AITaskTypes.CAS) then return end
                            if not checkSupplies(u, Config.supplies.tasking_costs.NAVAL_STRIKE) then return end

                            local ship_unit = Unit.getByName(attack_ship_name)
                            if not (ship_unit and ship_unit.isExist and ship_unit:isExist()) then
                                trigger.action.outTextForGroup(gr_id, "Negative, Naval capable asset unavailable.", 10)
                                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                            end

                            TaskManager:requestNavalStrike(to_zone,ship_unit)
                        end,
                        arg = {u = unit, z = zone}
                    })
                end
            end
        end

        local awacs_airbase_list = {}
        for _, zone in ipairs(zones) do
            -- Find friendly airbases suitable for AWACS
            if zone.side == side and zone.zone_type == ZoneTypes.AIRBASE
            then
                table.insert(awacs_airbase_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local to_zone = args.z
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_awacs then
                            trigger.action.outTextForGroup(gr_id, "Negative, AWACS tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_awacs.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.AWACS) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.AWACS) then return end

                        if TaskManager:initiateAITask(AITaskTypes.AWACS, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.AWACS)
                            trigger.action.outTextForCoalition(side, "Request accepted, AWACS dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.AWACS.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "AWACS request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_sead then
                            trigger.action.outTextForGroup(gr_id, "Negative, SEAD tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_sead.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.SEAD) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.SEAD) then return end

                        if TaskManager:initiateAITask(AITaskTypes.SEAD, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.SEAD)
                            trigger.action.outTextForCoalition(side, "Request accepted, SEAD dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.SEAD.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "SEAD request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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
                        if not checkSupplies(u, Config.supplies.tasking_costs.CAPTURE_HELO) then return end
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
                                deductSupplies(Config.supplies.tasking_costs.CAPTURE_HELO)
                                trigger.action.outTextForCoalition(side, "Request accepted, Helicopter capture dispatched to " .. to_zone.name .. ", " .. Config.supplies.tasking_costs.CAPTURE_HELO .. " supplies used.", 10)
                                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                            else
                                trigger.action.outTextForGroup(gr_id, "Helicopter capture request failed (no assets available).", 10)
                                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            end
                        else
                            trigger.action.outTextForGroup(gr_id, "Helicopter capture request failed (no assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_jtac then
                            trigger.action.outTextForGroup(gr_id, "Negative, JTAC tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_jtac.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.JTAC) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.JTAC) then return end



                        if TaskManager:initiateAITask(AITaskTypes.JTAC, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.JTAC)
                            trigger.action.outTextForCoalition(side, "Request accepted, JTAC dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.JTAC.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "JTAC request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cap then
                            trigger.action.outTextForGroup(gr_id, "Negative, CAP tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_cap.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.CAP) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.CAP) then return end


                        if TaskManager:initiateAITask(AITaskTypes.CAP, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.CAP)
                            trigger.action.outTextForCoalition(side, "Request accepted, CAP dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.CAP.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "CAP request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_strike then
                            trigger.action.outTextForGroup(gr_id, "Negative, STRIKE tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_strike.." active COMMS towers.", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                            return
                        end

                        if not checkRankRequirement(u, AITaskTypes.STRIKE) then return end
                        if not checkSupplies(u, Config.supplies.tasking_costs.STRIKE) then return end

                        if TaskManager:initiateAITask(AITaskTypes.STRIKE, side, false, to_zone, nil, true) then
                            deductSupplies(Config.supplies.tasking_costs.STRIKE)
                            trigger.action.outTextForCoalition(side, "Request accepted, STRIKE dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.STRIKE.." supplies used.", 10)
                            trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
                        else
                            trigger.action.outTextForGroup(gr_id, "STRIKE request failed (No assets available).", 10)
                            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
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

        if #naval_strike_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request Naval Strike",
                submenu = naval_strike_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request Naval Strike (No Targets)",
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

        if #awacs_airbase_list > 0 then
            table.insert(main_tasking_list, {
                name = "Request AWACS",
                submenu = awacs_airbase_list
            })
        else
             table.insert(main_tasking_list, {
                name = "Request AWACS (No Airbases)",
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

    ---@class CommandItemPagedMenu
    ---@field submenu any
    ---@field name string
    ---@field func function|nil
    ---@field arg any|nil

    -- Helper function for GROUP menus (Supports Nested Menus)
    ---@param group_id number
    ---@param parent_menu any
    ---@param command_list CommandItemPagedMenu[]
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



    ---@param u Unit
    function CommandHandler.tallyZone(u)
        if not u or not u.isExist or not u:isExist() then return end
        local function checkTallyZone()
            if not u or not u.isExist or not u:isExist() then return end
            local unit_id = u:getID()

            local gr = u:getGroup()
            if gr and gr.isExist and gr:isExist() and u.getCoalition then
                if not u:inAir() then
                    trigger.action.outSoundForUnit(unit_id, "radio click.ogg")
                    trigger.action.outTextForUnit(unit_id, "Recon report\n Can only perform recon while airborne.",10)
                    return
                end
                
                for i,p in ipairs(player_cooldowns) do
                    if p.id == unit_id and timer.getTime() < p.next_avail_report then
                        trigger.action.outSoundForUnit(unit_id, "radio click.ogg")
                        return trigger.action.outTextForUnit(unit_id, "Recon report\n Next report available shortly.",5)
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
                    trigger.action.outSoundForUnit(unit_id, "radio click.ogg")
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
                    trigger.action.outSoundForCoalition(unit_coalition, "radio click.ogg")
                end
            end
        end
        local gr = u:getGroup()
        if not gr then return end
        local intel_path = missionCommands.addCommandForGroup(gr:getID(),"Intel Report",nil,checkTallyZone,{})
        CommandHandler.addToMenuTracking(gr:getID(), intel_path, "intel_report")
    end
end
