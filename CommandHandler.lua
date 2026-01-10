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
                local out_text = "< SITMAP > \n\n"
                out_text = out_text .. "REDFOR controls " .. stats.red_zones .. " areas.\n"
                out_text = out_text .. "BLUFOR controls " .. stats.blue_zones .. " areas.\n"
                out_text = out_text .. "Neutral areas: " .. stats.neutral_zones .. "\n\n"

                local total_zones = stats.red_zones + stats.blue_zones + stats.neutral_zones

                if unit:getCoalition() == coalition.side.RED then
                    out_text = out_text .. "Your forces control " .. stats.red_zones .. "/" .. total_zones .. " areas.\n"
                else
                    out_text = out_text .. "Your forces control " .. stats.blue_zones .. "/" .. total_zones .. " areas.\n"
                end
                trigger.action.outTextForUnit(unit:getID(), out_text, 15)
            end, nil)

            CommandHandler.addToMenuTracking(group_id, sitmap_path, "sitmap")

                            
            local CTLD_submenu = missionCommands.addSubMenuForGroup(group_id, "CTLD", nil)
            ctld.initF10RadioMenu(CTLD_submenu, group)

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
                            function(code,unit)
                                
                                if unit and unit:getCoalition() == operation_manager.side then
                                    operation_manager:activateOperation(unit, code)
                                end
                            end, code, unit)
                    end
                end
            end

            -- Co-op Operations Menu
            local join_coop_menu = missionCommands.addSubMenuForGroup(group_id, "Join Co-op", missions_submenu)
            
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

            missionCommands.addCommandForGroup(group_id, "Leave Co-op", missions_submenu, function()
                operation_manager:leaveCoopOperation(unit)
            end)

            missionCommands.addCommandForGroup(group_id, "Co-op Status", missions_submenu, function()
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
            ---------------------------------------------------------------
            -- CARGO CRATES LOGIC
            
            -- ---@param u Unit
            -- ---@return boolean
            -- local function checkAircraftIsCargoCapable(u)
            --     if not u or not u.isExist or not u:isExist() then return false end
            --     local type_name = u:getTypeName()
            --     for _, cargo_aircraft in ipairs(Config.cargo_aircraft) do
            --         if type_name == cargo_aircraft then
            --             return true
            --         end
            --     end
            --     return false
            -- end

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


            -- local cargo_crates_submenu = missionCommands.addSubMenuForGroup(gr_id, "Cargo Crates", logistics_main_submenu)

            --  missionCommands.addCommandForGroup(gr_id, "Supplies Crate", cargo_crates_submenu, function()
            --     local u = gr:getUnit(1)
            --     if not u or not u:isExist() then return end
            --     if not u.getTypeName or not u:getTypeName() then return end

            --     if not checkAircraftIsCargoCapable(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Cargo crates cannot be deployed from this aircraft.", 10)
            --         return
            --     end

            --     if aircraftMoving(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Aircraft must be stationary to deploy cargo crates.", 10)
            --         return
            --     end

            --     UnitHandler.staticCargoSpawn(u, CargoCrates.SuppliesCrate)
            -- end, nil)

            -- missionCommands.addCommandForGroup(gr_id, "CDS Barrels", cargo_crates_submenu, function()
            --     local u = gr:getUnit(1)
            --     if not u or not u:isExist() then return end
            --     if not u.getTypeName or not u:getTypeName() then return end

            --     if not checkAircraftIsCargoCapable(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Cargo crates cannot be deployed from this aircraft.", 10)
            --         return
            --     end

            --     if aircraftMoving(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Aircraft must be stationary to deploy cargo crates.", 10)
            --         return
            --     end

            --     UnitHandler.staticCargoSpawn(u, CargoCrates.CDS_BARRELS)
            -- end, nil)

            -- missionCommands.addCommandForGroup(gr_id, "CDS Crates", cargo_crates_submenu, function()
            --     local u = gr:getUnit(1)
            --     if not u or not u:isExist() then return end
            --     if not u.getTypeName or not u:getTypeName() then return end

            --     if not checkAircraftIsCargoCapable(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Cargo crates cannot be deployed from this aircraft.", 10)
            --         return
            --     end

            --     if aircraftMoving(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Aircraft must be stationary to deploy cargo crates.", 10)
            --         return
            --     end

            --     UnitHandler.staticCargoSpawn(u, CargoCrates.CDS_CRATES)
            -- end, nil)

            -- missionCommands.addCommandForGroup(gr_id, "Equipment Container", cargo_crates_submenu, function()
            --     local u = gr:getUnit(1)
            --     if not u or not u:isExist() then return end
            --     if not u.getTypeName or not u:getTypeName() then return end

            --     if not checkAircraftIsCargoCapable(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Cargo crates cannot be deployed from this aircraft.", 10)
            --         return
            --     end

            --     if aircraftMoving(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Aircraft must be stationary to deploy cargo crates.", 10)
            --         return
            --     end

            --     UnitHandler.staticCargoSpawn(u, CargoCrates.ContainerClean)
            -- end, nil)

            -- missionCommands.addCommandForGroup(gr_id, "MOAB", cargo_crates_submenu, function()
            --     local u = gr:getUnit(1)
            --     if not u or not u:isExist() then return end
            --     if not u.getTypeName or not u:getTypeName() then return end

            --     if not checkAircraftIsCargoCapable(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Cargo crates cannot be deployed from this aircraft.", 10)
            --         return
            --     end

            --     if aircraftMoving(u) then
            --         trigger.action.outTextForUnit(u:getID(), "> Aircraft must be stationary to deploy cargo crates.", 10)
            --         return
            --     end

            --     -- Checks if MOAB in warehouse
            --     local airbase = utils.getZoneOfUnitFromPosition(u:getPoint())
            --     if not airbase or not airbase.airbase_name then
            --         trigger.action.outTextForUnit(u:getID(), "> Unable to determine airbase for MOAB deployment.", 10)
            --         return
            --     end
            --     local in_stock = false
            --     ab = Airbase.getByName(airbase.airbase_name)
            --     if ab then
            --         local warehouse = ab:getWarehouse()
            --             local moab_count = warehouse:getItemCount(WarehouseManager.Flags.GBU_43)
            --             if moab_count and moab_count > 0 then
            --                 in_stock = true
            --                 warehouse:removeItem(WarehouseManager.Flags.GBU_43, 1)
            --             end
            --     end
            --     if not in_stock then
            --         trigger.action.outTextForUnit(u:getID(), "> No MOABs available in warehouse for deployment.", 10)
            --         return
            --     end

            --     UnitHandler.staticCargoSpawn(u, CargoCrates.MOAB)
            -- end, nil)

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
                            local token_cost = args.cost
                            if not checkTokens(u, token_cost) then return end
                            ExperienceManager:deductTokens(u, token_cost)
                            TheatreCommander.sendWarehouseResupply(side, false, stock, target_zone)
                            trigger.action.outTextForGroup(gr_id, "> " .. args.stock_name .. " resupply requested for " .. target_zone.name .. ", -" .. token_cost .. " tokens.", 10)
                        end,
                        arg = {u = unit, target_zone = ab_zone, stock_types = stock_types, cost = cost, stock_name = stock_name}
                    })
                end
                return airbase_list
            end

            local resupply_menu = missionCommands.addSubMenuForGroup(gr_id, "Request Resupply", logistics_main_submenu)
            
            local resupply_stock_list = {}
            
            -- Initial Stock
            local initial_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.INITIAL}, Config.resupply_costs.INITIAL, "Initial Stock")
            if #initial_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Initial Stock - " .. Config.resupply_costs.INITIAL .. " tokens",
                    submenu = initial_airbases
                })
            end
            
            -- AA Aircraft
            local aa_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AA_AIRCRAFT}, Config.resupply_costs.AA_AIRCRAFT, "AA Aircraft")
            if #aa_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AA Aircraft - " .. Config.resupply_costs.AA_AIRCRAFT .. " tokens",
                    submenu = aa_aircraft_airbases
                })
            end
            
            -- AG Aircraft
            local ag_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AG_AIRCRAFT}, Config.resupply_costs.AG_AIRCRAFT, "AG Aircraft")
            if #ag_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Aircraft - " .. Config.resupply_costs.AG_AIRCRAFT .. " tokens",
                    submenu = ag_aircraft_airbases
                })
            end
            
            -- Cargo Aircraft
            local cargo_aircraft_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.CARGO_AIRCRAFT}, Config.resupply_costs.CARGO_AIRCRAFT, "Cargo Aircraft")
            if #cargo_aircraft_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Cargo Aircraft - " .. Config.resupply_costs.CARGO_AIRCRAFT .. " tokens",
                    submenu = cargo_aircraft_airbases
                })
            end
            
            -- Long Range AA
            local aa_lr_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE}, Config.resupply_costs.AIR_AIR_LONG_RANGE, "Long Range AA")
            if #aa_lr_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Long Range AA - " .. Config.resupply_costs.AIR_AIR_LONG_RANGE .. " tokens",
                    submenu = aa_lr_airbases
                })
            end
            
            -- Short Range AA
            local aa_sr_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE}, Config.resupply_costs.AIR_AIR_SHORT_RANGE, "Short Range AA")
            if #aa_sr_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "Short Range AA - " .. Config.resupply_costs.AIR_AIR_SHORT_RANGE .. " tokens",
                    submenu = aa_sr_airbases
                })
            end
            
            -- AG Bombs
            local ag_bombs_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_BOMBS}, Config.resupply_costs.AIR_GROUND_BOMBS, "AG Bombs")
            if #ag_bombs_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Bombs - " .. Config.resupply_costs.AIR_GROUND_BOMBS .. " tokens",
                    submenu = ag_bombs_airbases
                })
            end
            
            -- AG Rockets
            local ag_rockets_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_ROCKETS}, Config.resupply_costs.AIR_GROUND_ROCKETS, "AG Rockets")
            if #ag_rockets_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Rockets - " .. Config.resupply_costs.AIR_GROUND_ROCKETS .. " tokens",
                    submenu = ag_rockets_airbases
                })
            end
            
            -- AG Guided Bombs
            local ag_guided_bombs_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS}, Config.resupply_costs.AIR_GROUND_GUIDED_BOMBS, "AG Guided Bombs")
            if #ag_guided_bombs_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Guided Bombs - " .. Config.resupply_costs.AIR_GROUND_GUIDED_BOMBS .. " tokens",
                    submenu = ag_guided_bombs_airbases
                })
            end
            
            -- AG Missiles
            local ag_missiles_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES}, Config.resupply_costs.AIR_GROUND_GUIDED_MISSILES, "AG Missiles")
            if #ag_missiles_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "AG Missiles - " .. Config.resupply_costs.AIR_GROUND_GUIDED_MISSILES .. " tokens",
                    submenu = ag_missiles_airbases
                })
            end
            
            -- ECM
            local ecm_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.ECM}, Config.resupply_costs.ECM, "ECM")
            if #ecm_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "ECM - " .. Config.resupply_costs.ECM .. " tokens",
                    submenu = ecm_airbases
                })
            end
            
            -- TGP, Misc
            local tgp_misc_airbases = buildAirbaseSubmenu({WarehouseManager.StockTypes.TGP, WarehouseManager.StockTypes.MISC}, Config.resupply_costs.TGP_MISC, "TGP/Misc")
            if #tgp_misc_airbases > 0 then
                table.insert(resupply_stock_list, {
                    name = "TGP, Misc - " .. Config.resupply_costs.TGP_MISC .. " tokens",
                    submenu = tgp_misc_airbases
                })
            end
            
            if #resupply_stock_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, resupply_menu, resupply_stock_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No Airbases Available", resupply_menu, function() end, nil)
            end
        


            local farps_resupply_list = {}
            for _,zone in ipairs(zones) do
                if zone.side == side and zone.zone_type == ZoneTypes.FARP and zone.linked_farp then
                    table.insert(farps_resupply_list, {
                        name = zone.name .. " - " .. Config.resupply_costs.FARP .. " tokens",
                        func = function (args)
                            local coal = args.side
                            local farp = args.farp_name
                            local unit = args.u
                            if not checkTokens(unit, Config.resupply_costs.FARP) then return end
                            ExperienceManager:deductTokens(unit, Config.resupply_costs.FARP)
                            WarehouseManager:attributeAirbaseStock(farp,coal, {WarehouseManager.StockTypes.FARP})
                            trigger.action.outTextForCoalition(coal, "> FARP " .. farp .. " resupplied.", 10)
                        end,
                        arg = {side = side, farp_name = zone.linked_farp,u=unit}})
                end
            end

            local farp_resupply_menu = missionCommands.addSubMenuForGroup(gr_id,"FARP Resupply", logistics_main_submenu)
            if #farps_resupply_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, farp_resupply_menu, farps_resupply_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No FARPs Available", logistics_main_submenu, function() end, nil)
            end


            local  upgrade_submenu = missionCommands.addSubMenuForGroup(gr_id, "Request Upgrade", logistics_main_submenu)
            if #upgrade_zone_list > 0 then
                CommandHandler.buildPagedMenuForGroup(gr_id, upgrade_submenu, upgrade_zone_list, 1)
            else
                missionCommands.addCommandForGroup(gr_id, "No Zones Available", logistics_main_submenu, function() end, nil)
            end

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
                        trigger.action.outTextForGroup(gr_id, "> Restock aborted: Aircraft is not stationary.", 10)
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
                            trigger.action.outTextForGroup(gr_id, "> Restock aborted: Aircraft is not on carrier deck.", 10)
                            return
                        end
                    else
                        trigger.action.outTextForGroup(gr_id, "> Restock aborted: Carrier unit not found.", 10)
                        return
                    end
                end
                trigger.action.outTextForGroup(gr_id, "> Aircraft will be restocked to warehouse in 10 seconds...", 10)
                timer.scheduleFunction(function()

                    -- Add the aircraft back to the warehouse
                    if on_carrier then
                        if gr and gr:isExist() then
                            gr:destroy()
                        end
                    else
                        for _,zone in ipairs(zones) do
                            if (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP) and zone.side == side
                            and zone:isPointInsideZone(point)then
                                if gr and gr:isExist() then
                                    gr:destroy()
                                end
                            end
                        end

                    end
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
                CommandHandler.refreshJtacCmds(coalition.side.RED)
                
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
                CommandHandler.refreshJtacCmds(coalition.side.BLUE)
                
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

        local function getSideCommsTowers(coal)
            local side_comms_towers = 0
            if coal == coalition.side.BLUE then
                side_comms_towers = stats.blue_comms_antennas
            elseif coal == coalition.side.RED then
                side_comms_towers = stats.red_comms_antennas
            end
            return side_comms_towers
        end

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
                trigger.action.outTextForUnit(unit:getID(),"Insufficient rank for this tasking request.\nRequired rank: "..rankreq..", ".. required_xp .." XP",5)
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
                        
                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cas then
                            trigger.action.outTextForUnit(u:getID(), "CAS tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_cas.." active COMMS towers.", 10)
                            return
                        end

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

        local awacs_airbase_list = {}
        for _, zone in ipairs(zones) do
            -- Find friendly airbases suitable for AWACS
            if zone.side == side and zone.zone_type == ZoneTypes.AIRBASE
            then
                table.insert(awacs_airbase_list, {
                    name = zone.name,
                    func = function (args)
                        local u = args.u
                        local from_zone = args.z
                        if not checkRankRequirement(u, AITaskTypes.AWACS) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_awacs) then return end

                        -- check comms towers requirement
                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_awacs then
                            trigger.action.outTextForUnit(u:getID(), "AWACS tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_awacs.." active COMMS towers.", 10)
                            return
                        end

                        if TaskManager:initiateAITask(AITaskTypes.AWACS, side, false, nil, from_zone, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_awacs)
                            trigger.action.outTextForUnit(u:getID(), "AWACS dispatched from " .. from_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_awacs .. " tokens.", 10)
                        else
                            trigger.action.outTextForUnit(u:getID(), "AWACS request failed (No assets available).", 10)
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

                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_sead then
                            trigger.action.outTextForUnit(u:getID(), "SEAD tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_sead.." active COMMS towers.", 10)
                            return
                        end

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


                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_jtac then
                            trigger.action.outTextForUnit(u:getID(), "JTAC tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_jtac.." active COMMS towers.", 10)
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
                        if not checkRankRequirement(u, AITaskTypes.CAP) then return end
                        if not checkTokens(u, Config.tasking_requirements.tokens_required_for_cap) then return end
                        
                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_cap then
                            trigger.action.outTextForUnit(u:getID(), "CAP tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_cap.." active COMMS towers.", 10)
                            return
                        end

                        if TaskManager:initiateAITask(AITaskTypes.CAP, side, false, to_zone, nil, true) then
                            ExperienceManager:deductTokens(u, Config.tasking_requirements.tokens_required_for_cap)
                            trigger.action.outTextForUnit(u:getID(), "CAP dispatched to " .. to_zone.name .. ", -" .. Config.tasking_requirements.tokens_required_for_cap .. " tokens.", 10)
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
                        
                        local side_comms_towers = getSideCommsTowers(side)
                        if side_comms_towers < Config.tasking_requirements.comms_zones_required_for_strike then
                            trigger.action.outTextForUnit(u:getID(), "Strike tasking requires " .. side_comms_towers .. "/"..Config.tasking_requirements.comms_zones_required_for_strike.." active COMMS towers.", 10)
                            return
                        end

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
                    trigger.action.outTextForUnit(u:getID(), "Recon report\n> Can only perform recon while airborne.",10)
                    return
                end
                
                local unit_id = u:getID()
                for i,p in ipairs(player_cooldowns) do
                    if p.id == unit_id and timer.getTime() < p.next_avail_report then
                        return trigger.action.outTextForUnit(unit_id, "Recon report\n> Next report available shortly.",5)
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
                    trigger.action.outTextForUnit(unit_id, "Recon report\n> Nothing in the vicinity. Next report available shortly.",10)
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
                    trigger.action.outTextForCoalition(unit_coalition, "Recon report\n> Newly detected ground targets displayed on your F10 map.",15)
                end
            end
        end
        local gr = u:getGroup()
        if not gr then return end
        local intel_path = missionCommands.addCommandForGroup(gr:getID(),"Intel Report",nil,checkTallyZone,{})
        CommandHandler.addToMenuTracking(gr:getID(), intel_path, "intel_report")
    end
end
