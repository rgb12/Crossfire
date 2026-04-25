CommandHandler = {}
do
    local player_cooldowns = {}

    CommandHandler.jtac_main_submenu = nil
    CommandHandler.tasking_main_submenu = nil

    -- Track group menus: group_menus[group_id] = { {path=..., type=...}, ... }
    CommandHandler.group_menus = {}
    CommandHandler.temp_select_menu = {}

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

        if type == "tasking_main" or type == "tasking_temp_zone" then
            CommandHandler.destroySelectMenu(gr_id)
        end

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

        CommandHandler.destroySelectMenu(gr_id)

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

    ---@param gr_id number
    ---@param menu_path any
    function CommandHandler.removeTrackedMenuPath(gr_id, menu_path)
        local tracked_menus = CommandHandler.group_menus[gr_id]
        if not tracked_menus then return end

        for i = #tracked_menus, 1, -1 do
            if tracked_menus[i].path == menu_path then
                table.remove(tracked_menus, i)
                break
            end
        end
    end

    ---@param gr_id number
    function CommandHandler.destroySelectMenu(gr_id)
        local select_menu = CommandHandler.temp_select_menu[gr_id]
        if not select_menu then return end

        missionCommands.removeItemForGroup(gr_id, select_menu.path)
        CommandHandler.removeTrackedMenuPath(gr_id, select_menu.path)
        CommandHandler.temp_select_menu[gr_id] = nil
    end

    ---@param gr_id number
    ---@param token number
    ---@param ttl_sec number
    function CommandHandler.scheduleTempRequestSubmenuCleanup(gr_id, token, ttl_sec)
        timer.scheduleFunction(function(args)
            local select_menu = CommandHandler.temp_select_menu[args.gr_id]
            if not select_menu then return end
            if select_menu.token ~= args.token then return end
            CommandHandler.destroySelectMenu(args.gr_id)
        end, {gr_id = gr_id, token = token}, timer.getTime() + ttl_sec)
    end

    ---@param unit Unit|nil
    ---@param gr_id number|nil
    ---@return boolean
    function CommandHandler.isGrounded(unit, gr_id)
        if not unit or not unit.isExist or not unit:isExist() then
            return false
        end

        if unit:inAir() then
            local message = "CMD-HQ - Negative, unavailable while airborne."
            if gr_id then
                trigger.action.outTextForGroup(gr_id, message, 8)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
            return false
        end

        return true
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
            local group_name = gr:getName()

            local function getCurrentPlayerUnit()
                local live_group = Group.getByName(group_name)
                if not live_group or not live_group.isExist or not live_group:isExist() then
                    return nil
                end

                local group_size = live_group:getSize() or 0
                for i = 1, group_size do
                    local member = live_group:getUnit(i)
                    if member and member:isExist() and member.getPlayerName and member:getPlayerName() then
                        return member
                    end
                end

                local fallback = live_group:getUnit(1)
                if fallback and fallback:isExist() then
                    return fallback
                end
                return nil
            end

            local missions_submenu = missionCommands.addSubMenuForGroup(group_id, "Operations")
            CommandHandler.addToMenuTracking(group_id, missions_submenu, "operations_menu")

            missionCommands.addCommandForGroup(group_id, "Available Operations", missions_submenu,function()
                local live_unit = getCurrentPlayerUnit()
                if live_unit then
                    operation_manager:showAvailableOperations(live_unit)
                end
            end)

            missionCommands.addCommandForGroup(group_id, "Active Operation", missions_submenu,function()
                local live_unit = getCurrentPlayerUnit()
                if live_unit then
                    operation_manager:showActiveOperation(live_unit)
                end
            end)
            local cancel_op_menu = missionCommands.addSubMenuForGroup(group_id, "Cancel Active Operation",missions_submenu)

            missionCommands.addCommandForGroup(group_id, "Confirm (Cancel Active Operation)", cancel_op_menu,function()
                local live_unit = getCurrentPlayerUnit()
                if live_unit then
                    operation_manager:cancelOperation(live_unit)
                end
            end)


            local join_operation_menu = missionCommands.addSubMenuForGroup(group_id, "Initiate Operation", missions_submenu)

            -- Aligned with F-keys: F1..F9 = 1..9, F10 = 0
            local digit_order = {1, 2, 3, 4, 5, 6, 7, 8, 9, 0}
            for i1 = 1, 9 do
                local digit1 = missionCommands.addSubMenuForGroup(group_id, i1 .. ' _ _', join_operation_menu)

                for _, i2 in ipairs(digit_order) do
                    local digit2 = missionCommands.addSubMenuForGroup(group_id, i1 .. i2 .. ' _', digit1)
                    for _, i3 in ipairs(digit_order) do
                        local code = tonumber(i1 .. i2 .. i3)
                        missionCommands.addCommandForGroup(group_id,tostring(code), digit2,
                            function(c)
                                local live_unit = getCurrentPlayerUnit()
                                if live_unit and live_unit:getCoalition() == operation_manager.side then
                                    operation_manager:activateOperation(live_unit, c)
                                end
                            end, code)
                    end
                end
            end

            -- Co-op Operations Menu
            local coop_submenu = missionCommands.addSubMenuForGroup(group_id, "CO-OP Operations", missions_submenu)

            local join_coop_menu = missionCommands.addSubMenuForGroup(group_id, "Join CO-OP", coop_submenu)
            
            for i1 = 1, 9 do
                local digit1 = missionCommands.addSubMenuForGroup(group_id, i1 .. ' _ _', join_coop_menu)
                for _, i2 in ipairs(digit_order) do
                    local digit2 = missionCommands.addSubMenuForGroup(group_id, i1 .. i2 .. ' _', digit1)
                    for _, i3 in ipairs(digit_order) do
                        local join_code = tonumber(i1 .. i2 .. i3)
                        missionCommands.addCommandForGroup(group_id, tostring(join_code), digit2,
                            function(code)
                                local live_unit = getCurrentPlayerUnit()
                                if live_unit and live_unit:getCoalition() == operation_manager.side then
                                    operation_manager:joinCoopOperation(live_unit, code)
                                end
                            end, join_code)
                    end
                end
            end

            missionCommands.addCommandForGroup(group_id, "Leave CO-OP", coop_submenu, function()
                local live_unit = getCurrentPlayerUnit()
                if live_unit then
                    operation_manager:leaveCoopOperation(live_unit)
                end
            end)

            missionCommands.addCommandForGroup(group_id, "CO-OP Status", coop_submenu, function()
                local live_unit = getCurrentPlayerUnit()
                if live_unit then
                    operation_manager:showCoopOperationStatus(live_unit)
                end
            end)
        end
    end


    ---@param gr Group
    function CommandHandler.resourcesRequests(gr)

        if not gr or not gr.isExist or not gr:isExist() then return end
        local gr_id = gr:getID()
        local group_name = gr:getName()

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
                            if not CommandHandler.isGrounded(unit,gr_id) then return end

                            -- Check if airbase is still friendly before sending 
                            local ab = ZoneHandler.getFromName(target_zone.name)
                            if not ab then return end
                            if ab.side ~= side then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative resupply response for " .. target_zone.name .. ": area lost. Stand by for next resupply or capture additional zones.",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end

                            local supplies_zone = utils.fetchSuppliesZoneFromUnit(u)
                            if not supplies_zone then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - CMD-HQ - Negative, action cannot be executed from your position.",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end

                            if supplies_zone.ammo_depot_intact ~= true then
                                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, no operational Ammunition Depot in your current supply zone.", 8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end

                            local local_supplies = supplies_zone.local_supplies or 0
                            if local_supplies < cost then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - CMD-HQ - Negative resupply response for " .. target_zone.name .. ", not enough supplies    (" .. local_supplies .. "/" .. cost .. ")",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            else
                                supplies_zone.local_supplies = math.max(supplies_zone.local_supplies-cost,0)
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
                            if not CommandHandler.isGrounded(unit,gr_id) then return end
                            local coal = args.side
                            local farp = args.farp_name
                            local name = args.name

                            local supplies_zone = utils.fetchSuppliesZoneFromUnit(unit)
                            if not supplies_zone then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative, action cannot be executed from your position.",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end

                            local local_supplies = supplies_zone.local_supplies or 0
                            if local_supplies < Config.supplies.resupply_costs.FARP then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative resupply response for " .. name .. ", not enough supplies    (" .. local_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. ")",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            else
                                supplies_zone.local_supplies = math.max(local_supplies - Config.supplies.resupply_costs.FARP,0)
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
                            if not CommandHandler.isGrounded(unit,gr_id) then return end
                            local coal = args.side
                            local farp_name = args.farp_name
                            local name = args.name

                            local supplies_zone = utils.fetchSuppliesZoneFromUnit(unit)
                            if not supplies_zone then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative, action cannot be executed from your position.",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            end

                            local local_supplies = supplies_zone.local_supplies or 0
                            if local_supplies < Config.supplies.resupply_costs.FARP then
                                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative resupply response for " .. name .. ", not enough supplies    (" .. local_supplies .. "/" .. Config.supplies.resupply_costs.FARP .. ")",8)
                                trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                                return
                            else
                                supplies_zone.local_supplies = math.max(local_supplies - Config.supplies.resupply_costs.FARP,0)
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

            ---------------------------------------------------------------
            -- Restock Aircraft
            local restock_submenu = missionCommands.addSubMenuForGroup(gr_id, "Restock Aircraft", logistics_main_submenu)
            missionCommands.addCommandForGroup(gr_id, "Confirm (destroy)", restock_submenu, function(gr_name)
                if not CommandHandler.isGrounded(unit,gr_id) then return end
                local restock_gr = Group.getByName(gr_name)
                if not (restock_gr and restock_gr:isExist()) then return end

                local restock_unit = restock_gr:getUnit(1)
                if not (restock_unit and restock_unit:isExist()) then return end

                local point = restock_unit:getPoint()

                -- Checks if aircraft is not moving and on ground
                local aircraft_on_carrier = false
                local on_carrier = false

                if land.getSurfaceType{ x = point.x, y = point.z } == land.SurfaceType.WATER and not restock_unit:inAir() then
                    aircraft_on_carrier = true
                end

                if (not aircraft_on_carrier) and (aircraftMoving(restock_unit) or restock_unit:inAir()) then
                    trigger.action.outTextForGroup(gr_id, "Restock aborted: Aircraft is not stationary.", 10)
                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                    return
                end

                if aircraft_on_carrier then
                    local carrier_unit = nil
                    if Scenario and Scenario.carrier_setup and Scenario.carrier_setup.carrier_unit_name then
                        carrier_unit = Unit.getByName(Scenario.carrier_setup.carrier_unit_name)
                    end

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

                    local function restock_acft()
                        MissionLogger:info("Attempting restock")
                        if restock_gr and restock_gr:isExist() then
                            MissionLogger:info("Executing restock for group")
                            restock_gr:destroy()
                        end
                        if restock_unit and restock_unit:isExist() then
                            MissionLogger:info("Executing restock for unit")
                            restock_unit:destroy()
                            return
                        else
                            MissionLogger:info("Completed restock")
                            return
                        end
                    end

                    -- Add the aircraft back to the warehouse
                    if on_carrier then
                        return restock_acft()
                    else
                        MissionLogger:info("Attempting restock on land")

                        for _,zone in ipairs(zones) do
                            if (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP) and zone.side == side
                            and zone:isPointInsideZone(point)then
                                MissionLogger:info("Restock airbase found")
                                return restock_acft()
                            end
                        end

                    end
                    trigger.action.outTextForGroup(gr_id, "Restock aborted: No friendly airbase or FARP nearby.", 10)
                    trigger.action.outSoundForGroup(gr_id, "radio_beep3.ogg")
                end, {}, timer.getTime() + 10)
            end, group_name)

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
        local unit = gr:getUnit(1)

        local function getSideCommsTowers()
            if side == coalition.side.BLUE then
                return stats.blue_comms_antennas
            elseif side == coalition.side.RED then
                return stats.red_comms_antennas
            end
            return 0
        end

        ---@param requesting_unit Unit
        ---@param required_supplies number
        ---@param supplies_zone ZoneHandler|nil
        ---@return boolean
        local function deductSupplies(requesting_unit, required_supplies, supplies_zone)
            supplies_zone = supplies_zone or utils.fetchSuppliesZoneFromUnit(requesting_unit)
            if not supplies_zone then return false end
            supplies_zone.local_supplies = math.max((supplies_zone.local_supplies or 0) - required_supplies,0)
            return true
        end

        ---@param requesting_unit Unit
        ---@param required_supplies number
        ---@param supplies_zone ZoneHandler|nil
        ---@return boolean
        local function checkSupplies(requesting_unit, required_supplies, supplies_zone)
            supplies_zone = supplies_zone or utils.fetchSuppliesZoneFromUnit(requesting_unit)
            if not supplies_zone then
                trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative, action cannot be executed from your position.",5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return false
            end

            if supplies_zone.ammo_depot_intact ~= true then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, no operational Ammunition Depot in your current supply zone.", 5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return false
            end

            local local_supplies = supplies_zone.local_supplies or 0
            if local_supplies >= required_supplies then
                return true
            end

            trigger.action.outTextForGroup(gr_id,"CMD-HQ - Negative,  not enough supplies  (" .. local_supplies .. "/" .. required_supplies .. ")",5)
            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            return false
        end

        ---@param to_zone ZoneHandler|nil
        ---@param ai_task_type AITaskTypes
        ---@return ZoneHandler|nil
        local function resolveAirbaseSupplyZone(to_zone, ai_task_type)
            if not to_zone then return nil end
            local source_airbase, _ = TaskManager:findClosestAirbaseWithAircraftInStock(to_zone, side, ai_task_type, 2, ai_task_type)
            return source_airbase
        end

        ---@param requesting_unit Unit
        ---@param task_label string
        ---@return ZoneHandler|nil
        local function resolveRequestingAirbaseZone(requesting_unit, task_label)
            local supply_zone = utils.fetchSuppliesZoneFromUnit(requesting_unit)
            if not supply_zone then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, " .. task_label .. " can only be requested while at a friendly airbase.", 5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return nil
            end

            if supply_zone.zone_type ~= ZoneTypes.AIRBASE then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, " .. task_label .. " can only be requested while at a friendly airbase.", 5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return nil
            end

            return supply_zone
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
                trigger.action.outTextForUnit(unit:getID(),"CMD-HQ - Negative, insufficient rank for this tasking request.\nRequired rank: "..rankreq..", ".. required_xp .." XP",5)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return false
            end
        end

        unit = unit or gr:getUnit(1)
        if not unit or not unit:isExist() or not unit.getCoalition then return end
        local enemy_side = utils.getEnemyCoalition(side)

        local function getDiscoveredZones()
            if side == coalition.side.BLUE then
                return stats.blue_discovered_zones
            end
            return stats.red_discovered_zones
        end

        local function executeCASRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_cas then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, CAS tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_cas.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveRequestingAirbaseZone(u, "CAS")
            if not supply_zone then return end
            if not checkRankRequirement(u, AITaskTypes.CAS) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.CAS, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.CAS, side, false, to_zone, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.CAS, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, CAS dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.CAS.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "CAS request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeNavalStrikeRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local attack_ship_name = Scenario.carrier_setup.tomahawk_launcher_unit_name
            if not (Scenario.carrier_setup.enabled and attack_ship_name) then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, Naval strike unavailable.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            local u_xp = ExperienceManager:fetchUser(u)
            if not u_xp then
                trigger.action.outTextForGroup(gr_id,"Could not fetch user data",10)
                return
            end

            if u_xp.xp < Config.reward_system.naval_stike_xp_required then
                trigger.action.outTextForGroup(gr_id,"Not authorized, required rank: "..ExperienceManager:getRankfromXP(Config.reward_system.naval_stike_xp_required),10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            local supply_zone = resolveAirbaseSupplyZone(to_zone, AITaskTypes.CAS)
            if not checkRankRequirement(u, AITaskTypes.CAS) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.NAVAL_STRIKE, supply_zone) then return end

            local ship_unit = Unit.getByName(attack_ship_name)
            if not (ship_unit and ship_unit.isExist and ship_unit:isExist()) then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, Naval capable asset unavailable.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            deductSupplies(u, Config.supplies.tasking_costs.NAVAL_STRIKE, supply_zone)
            TaskManager:requestNavalStrike(to_zone,ship_unit)
        end

        local function executeAWACSRequest(u, from_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_awacs then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, AWACS tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_awacs.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveRequestingAirbaseZone(u, "AWACS")
            if not supply_zone then return end
            if from_zone ~= supply_zone then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, AWACS must launch from your current airbase (" .. supply_zone.name .. ").", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            if not checkRankRequirement(u, AITaskTypes.AWACS) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.AWACS, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.AWACS, side, false, nil, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.AWACS, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, AWACS dispatched from " .. supply_zone.name .. ", "..Config.supplies.tasking_costs.AWACS.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "AWACS request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeTankerRequest(u, from_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_tanker then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, TANKER tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_tanker.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            local supply_zone = resolveRequestingAirbaseZone(u, "TANKER")
            if not supply_zone then return end

            if from_zone ~= supply_zone then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, TANKER package must launch from your current airbase (" .. supply_zone.name .. ").", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            if not checkRankRequirement(u, AITaskTypes.TANKER) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.TANKER, supply_zone) then return end

            if TaskManager:initiateAITask(AITaskTypes.TANKER, side, false, nil, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.TANKER, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, TANKER package dispatched from " .. supply_zone.name .. ", "..Config.supplies.tasking_costs.TANKER.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "TANKER request failed.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeSEADRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_sead then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, SEAD tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_sead.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveRequestingAirbaseZone(u, "SEAD")
            if not supply_zone then return end
            if not checkRankRequirement(u, AITaskTypes.SEAD) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.SEAD, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.SEAD, side, false, to_zone, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.SEAD, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, SEAD dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.SEAD.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "SEAD request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeCaptureHeloRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            if not checkRankRequirement(u, AITaskTypes.CAPTURE_HELO) then return end

            local from_zone = nil
            for _, log_zone in ipairs(zones) do
                if log_zone.side == side and log_zone.zone_type == ZoneTypes.LOGISTICS and (log_zone.heli_avail or 0) > 0 then
                    from_zone = log_zone
                    break
                end
            end

            if not checkSupplies(u, Config.supplies.tasking_costs.CAPTURE_HELO, from_zone) then return end

            if from_zone and TaskManager:initiateAITask(AITaskTypes.CAPTURE_HELO, side, false, to_zone, from_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.CAPTURE_HELO, from_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, Helicopter capture dispatched to " .. to_zone.name .. ", " .. Config.supplies.tasking_costs.CAPTURE_HELO .. " supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "Helicopter capture request failed (no assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeReinforcementHeloRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit, gr_id) then return end

            local required_supplies = (Config.operations and Config.operations.reinforcement_required_supplies) or 300

            local from_zone = nil
            for _, log_zone in ipairs(zones) do
                if log_zone.side == side
                and log_zone.zone_type == ZoneTypes.LOGISTICS
                and (log_zone.heli_avail or 0) > 0
                then
                    from_zone = log_zone
                    break
                end
            end

            if not checkSupplies(u, required_supplies, from_zone) then return end

            if from_zone and TaskManager:initiateAITask(AITaskTypes.REINFORCEMENT_HELO, side, false, to_zone, from_zone, true) then
                deductSupplies(u, required_supplies, from_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, Reinforcement helicopter dispatched to " .. to_zone.name .. ", " .. required_supplies .. " supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "Reinforcement helicopter request failed (no assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeJTACRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_jtac then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, JTAC tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_jtac.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveAirbaseSupplyZone(to_zone, AITaskTypes.JTAC)
            if not checkRankRequirement(u, AITaskTypes.JTAC) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.JTAC, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.JTAC, side, false, to_zone, nil, true) then
                deductSupplies(u, Config.supplies.tasking_costs.JTAC, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, JTAC dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.JTAC.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "JTAC request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeCAPRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_cap then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, CAP tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_cap.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveRequestingAirbaseZone(u, "CAP")
            if not supply_zone then return end
            if not checkRankRequirement(u, AITaskTypes.CAP) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.CAP, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.CAP, side, false, to_zone, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.CAP, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, CAP dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.CAP.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "CAP request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        local function executeStrikeRequest(u, to_zone)
            if not CommandHandler.isGrounded(unit,gr_id) then return end
            local comms = getSideCommsTowers()
            if comms < Config.tasking_requirements.comms_zones_required_for_strike then
                trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, STRIKE tasking requires " .. comms .. "/"..Config.tasking_requirements.comms_zones_required_for_strike.." active COMMS towers.", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end
            local supply_zone = resolveRequestingAirbaseZone(u, "STRIKE")
            if not supply_zone then return end
            if not checkRankRequirement(u, AITaskTypes.STRIKE) then return end
            if not checkSupplies(u, Config.supplies.tasking_costs.STRIKE, supply_zone) then return end
            if TaskManager:initiateAITask(AITaskTypes.STRIKE, side, false, to_zone, supply_zone, true) then
                deductSupplies(u, Config.supplies.tasking_costs.STRIKE, supply_zone)
                trigger.action.outTextForCoalition(side, "Request accepted, STRIKE dispatched to " .. to_zone.name .. ", "..Config.supplies.tasking_costs.STRIKE.." supplies used.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            else
                trigger.action.outTextForGroup(gr_id, "STRIKE request failed (No assets available).", 10)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
            end
        end

        ---@param additional_check_function function
        ---@param execute_function function
        local function buildZoneCommandList(additional_check_function, execute_function)
            local discovered_zones = getDiscoveredZones()
            local command_list = {}

            for _, zone in ipairs(zones) do
                if additional_check_function(zone, discovered_zones) then
                    table.insert(command_list, {
                        name = zone.name,
                        func = function(args)
                            args.execute(args.u, args.z) -- this executes the function (ex executeCASRequest)
                            CommandHandler.destroySelectMenu(args.gr_id) -- destroy the submenu after use
                        end,
                        arg = {u = unit, z = zone, execute = execute_function, gr_id = gr_id}
                    })
                end
            end
            return command_list
        end

        ---@param commands any[]
        ---@param no_target_message string
        local function createSelectAreaMenu(commands, no_target_message)
            local previous_select_menu = CommandHandler.temp_select_menu[gr_id]
            CommandHandler.destroySelectMenu(gr_id)

            if #commands == 0 then
                trigger.action.outTextForGroup(gr_id, no_target_message, 8)
                trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                return
            end

            trigger.action.outTextForGroup(gr_id, "CMD-HQ - Select target area with the F10 Radio Menu", 8)
            trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")

            local temp_submenu = missionCommands.addSubMenuForGroup(gr_id, "(#) Select Area")
            CommandHandler.addToMenuTracking(gr_id, temp_submenu, "tasking_temp_zone")

            local token = 1 -- this prevents a new select menu from being removed by an old timer.
            if previous_select_menu and previous_select_menu.token then
                token = previous_select_menu.token + 1
            end
            CommandHandler.temp_select_menu[gr_id] = {
                path = temp_submenu,
                token = token,
            }

            CommandHandler.buildPagedMenuForGroup(gr_id, temp_submenu, commands, 1)
            CommandHandler.scheduleTempRequestSubmenuCleanup(gr_id, token, 120)
        end

        local main_tasking_list = {
            {
                name = "Request JTAC",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == enemy_side and utils.tableContains(discovered, zone.name)
                    end, executeJTACRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative JTAC tasking. No confirmed hostile sectors. Continue recon and standby.")
                end,
                arg = nil
            },
            {
                name = "Request Naval Strike",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        if not (Scenario.carrier_setup.enabled and Scenario.carrier_setup.tomahawk_launcher_unit_name) then
                            return false
                        end
                        return zone.side == enemy_side and utils.tableContains(discovered, zone.name)
                    end, executeNavalStrikeRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative naval strike. No valid target areas currently designated.")
                end,
                arg = nil
            },
            {
                name = "Request Helicopter Capture",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == coalition.side.NEUTRAL and utils.tableContains(discovered, zone.name)
                    end, executeCaptureHeloRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative capture tasking. No neutral zones are currently identified.")
                end,
                arg = nil
            },
            {
                name = "Request Helicopter Reinforcement",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == side
                            and zone.level and zone.level < 4
                            and utils.tableContains(discovered, zone.name)
                    end, executeReinforcementHeloRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative reinforcement tasking. No eligible friendly sectors are currently identified.")
                end,
                arg = nil
            },
            {
                name = "Request CAP",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return utils.tableContains(discovered, zone.name)
                    end, executeCAPRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative CAP assignment. No sectors available for patrol at this time.")
                end,
                arg = nil
            },
            {
                name = "Request CAS",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == enemy_side and utils.tableContains(discovered, zone.name)
                    end, executeCASRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative CAS tasking. No confirmed hostile zones available. Continue recon.")
                end,
                arg = nil
            },
            {
                name = "Request AWACS",
                func = function()
                    local requesting_airbase = utils.fetchSuppliesZoneFromUnit(unit)
                    if not requesting_airbase or requesting_airbase.zone_type ~= ZoneTypes.AIRBASE then
                        trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, AWACS can only be requested while at a friendly airbase.", 8)
                        trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                        return
                    end
                    local commands = buildZoneCommandList(function(zone)
                        return zone == requesting_airbase
                    end, executeAWACSRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative AWACS launch. No friendly airbase is available for departure.")
                end,
                arg = nil
            },
            {
                name = "Request Tanker",
                func = function()
                    local requesting_airbase = utils.fetchSuppliesZoneFromUnit(unit)
                    if not requesting_airbase or requesting_airbase.zone_type ~= ZoneTypes.AIRBASE then
                        trigger.action.outTextForGroup(gr_id, "CMD-HQ - Negative, Tanker sectors can only be requested while at a friendly airbase.", 8)
                        trigger.action.outSoundForGroup(gr_id, "Radio squelch.ogg")
                        return
                    end
                    local commands = buildZoneCommandList(function(zone)
                        return zone == requesting_airbase
                    end, executeTankerRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative tanker launch. No friendly airbase is available for departure.")
                end,
                arg = nil
            },
            {
                name = "Request Strike",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == enemy_side and utils.tableContains(discovered, zone.name)
                            and (zone.zone_type == ZoneTypes.LOGISTICS or zone.zone_type == ZoneTypes.COMMS)
                    end, executeStrikeRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative strike package. No validated enemy infrastructure targets are available.")
                end,
                arg = nil
            },
            {
                name = "Request SEAD",
                func = function()
                    local commands = buildZoneCommandList(function(zone, discovered)
                        return zone.side == enemy_side and utils.tableContains(discovered, zone.name)
                            and zone.zone_type == ZoneTypes.SAMSITE
                    end, executeSEADRequest)
                    createSelectAreaMenu(commands, "CMD-HQ Negative SEAD tasking. No active enemy SAM sectors are currently identified.")
                end,
                arg = nil
            },
        }

        CommandHandler.buildPagedMenuForGroup(gr_id, tasking_main_submenu, main_tasking_list, 1)

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
                local base_range = 8000
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
