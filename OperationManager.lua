

---@class Operation
---@field type OperationTypes
---@field code number
---@field status OperationStatus
---@field target_zone_name string
---@field operation_name string
---@field assigned_player_id string | nil
---@field assigned_unit_name string | nil
---@field objectives table

---@class OperationManager
---@field side coalition.side
---@field home_airbase ZoneHandler
---@field available_operations Operation[]
---@field active_operations Operation[]
OperationManager = {}
do
    OperationManager.__index = OperationManager

    -- Static list to hold all manager instances
    OperationManager.instances = {}

    -- The single, global event handler table that DCS will call
    OperationManager.EventHandler = {}

    --- The onEvent method for the global handler. It dispatches events to all instances.
    ---@param event table
    function OperationManager.EventHandler:onEvent(event)
        if not OperationManager.instances then return end
        for _, instance in ipairs(OperationManager.instances) do
            pcall(function() instance:onEvent(event) end)
        end
    end


    function OperationManager:new(side, home_airbase)
        local obj = {
            side = side,
            home_airbase = home_airbase,
            available_operations = {},
            active_operations = {}
        }
        setmetatable(obj, self)
        table.insert(OperationManager.instances, obj) -- Add this new instance to our list
        world.addEventHandler(OperationManager.EventHandler)
        return obj
    end


    ---@param unit Unit
    function OperationManager:showActiveOperation(unit)
        if not unit or not unit.getPlayerName then return end

        local active_mission = nil
        for _, op in ipairs(self.active_operations) do
            if op.assigned_player_id == unit:getID() then
                active_mission = op
                break
            end
        end

        if not active_mission then
            trigger.action.outTextForUnit(unit:getID(), "No active operation.", 10)
            return
        end

        local zone_tgt = ZoneHandler.getFromName(active_mission.target_zone_name)
        if not zone_tgt then
            trigger.action.outTextForUnit(unit:getID(), "Target zone not found for this operation.", 10)
            OperationManager:cancelOperation(unit)
            return
        end

        local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
        local mgrs = coord.LLtoMGRS(lat, lon)

        local outtxt = ""
        if active_mission.type == OperationTypes.RECON then
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s\nTarget: ????",
            active_mission.operation_name, active_mission.type)
        else     
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s\nTarget: %s",
                active_mission.operation_name, active_mission.type, active_mission.target_zone_name)
        end
        
        outtxt = outtxt .. string.format("\n\nTarget Coordinates:\n%s\n%s\nMGRS: %s", 
            mist.tostringLL(lat, lon, 1), mist.tostringLL(lat, lon, 1, true), mist.tostringMGRS(mgrs, 3))

        outtxt = outtxt .. "\n\nObjectives:"
        for i, obj in ipairs(active_mission.objectives) do
            local status = obj.completed and "[COMPLETE]" or "[PENDING]"
            outtxt = outtxt .. string.format("\n%d. %s %s", i, obj.description, status)
        end

        trigger.action.outTextForUnit(unit:getID(), outtxt, 20)
    end

    --- Handles DCS events to check for mission success or failure.
    --- @param event table The DCS event table.
    function OperationManager:onEvent(event)
        if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH or event.id == world.event.S_EVENT_PILOT_DEAD then
            -- An initiator is the object that was destroyed/killed/crashed.
            if event.initiator and event.initiator.getPlayerName then
                local dead_unit_name = event.initiator.unit_name or event.initiator:getName()

                -- 1. Check if the dead unit was a player on a mission.
                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    if op.assigned_unit_name == dead_unit_name then
                        op.status = OperationStatus.FAILED
                        trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: operative lost.", 15)
                        table.remove(self.active_operations, i)
                        break
                    end
                end


            end
        elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
            if event.initiator then
                local unit_name = event.initiator:getName()
                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    if op.assigned_unit_name == unit_name then
                        op.status = OperationStatus.FAILED
                        trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: operative lost.", 15)
                        table.remove(self.active_operations, i)
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_BIRTH and event.initiator then
            if event.initiator.getPlayerName and event.initiator:getPlayerName() then

                if event.initiator.getCoalition and event.initiator:getCoalition() ~= self.side then
                    return
                end

                local group_id = event.initiator:getGroup():getID()

                local missions_submenu = missionCommands.addSubMenuForGroup(group_id, "Operations")
                
                missionCommands.addCommandForGroup(group_id, "Recommended Operations", missions_submenu,function()
                    self:showAvailableOperations(event.initiator)
                end)

                missionCommands.addCommandForGroup(group_id, "Active Operation", missions_submenu,function()
                    self:showActiveOperation(event.initiator)
                end)
                missionCommands.addCommandForGroup(group_id, "Cancel Active Operation", missions_submenu,function()
                    self:cancelOperation(event.initiator)
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
                                    
                                    if unit and unit:getCoalition() == self.side then
                                        self:activateOperation(unit, code)
                                    end
                                end, code, event.initiator)
                        end
                    end
                end


            end

        end
    end

    local operations_name = {
        "Steel Horizon",
        "Thunder Spear",
        "Phantom Dagger",
        "Nightfire",
        "Stormbreaker",
        "Ember Strike",
        "Black Echo",
        "Granite Shield",
        "Stormfront",
        "Sunfire",
        "Silent Avalanche",
        "Ghost Veil",
        "Eclipse Fury",
        "Diamond Spear",
        "Radiant Dagger",
        "Cerulean Shield"
    }

    function OperationManager:generateOperations()
        local reference_pos = self.home_airbase.zone.point
        local friendly_coalition = self.side
        local enemy_coalition = utils.getEnemyCoalition(friendly_coalition)
        -- STEP 1: MAINTENANCE
        -- Remove operations from the 'available' list if they are now active (taken by someone else)
        -- or if the target zone is no longer valid (e.g. destroyed by random event).

        local discovered_zones = {}
        if self.side == coalition.side.BLUE then
            discovered_zones = stats.blue_discovered_zones
        elseif self.side ==coalition.side.RED then
            discovered_zones = stats.red_discovered_zones
        end

        for i = #self.available_operations, 1, -1 do
            local op = self.available_operations[i]
            
            -- If this zone is now Active (taken by a player), remove it from Available
            if self:isZoneActive(op.target_zone_name) then
                table.remove(self.available_operations, i)
            end
            
            local zone = ZoneHandler.getFromName(op.target_zone_name)
            if not zone then
                table.remove(self.available_operations, i)
            end
            if zone and zone.side ~= self.side then
                table.remove(self.available_operations, i)
            end

            if not utils.tableContains(discovered_zones, op.target_zone_name) then
                table.remove(self.available_operations, i)
            end

        end

        local sorted_zones = ZoneHandler.sortZonesByDistance(reference_pos)
        for _, zone in ipairs(sorted_zones) do

            if not self:isZoneActive(zone.name) and not self:isMissionProposed(zone.name)
            then
                if zone.side == enemy_coalition and utils.tableContains(discovered_zones, zone.name) then
                    -- CAS against a STRONGPOINT
                    if zone.zone_type == ZoneTypes.STRONGPOINT then
                        local op = self:createCASOperation(zone)
                        table.insert(self.available_operations, op)
                    end

                    -- SEAD/DEAD against a SAMSITE
                    if zone.zone_type == ZoneTypes.SAMSITE then
                        local sead_op = self:createSEADOperation(zone)
                        table.insert(self.available_operations, sead_op)
                        local dead_op = self:createDEADOperation(zone)
                        table.insert(self.available_operations, dead_op)
                    end

                    -- STRIKE against COMMS or LOGISTICS
                    if zone.zone_type == ZoneTypes.COMMS and zone.comms_tower_intact then
                        local strike_op = self:createStrikeOperation(zone, "COMMS")
                        table.insert(self.available_operations, strike_op)
                    end

                    if zone.zone_type == ZoneTypes.LOGISTICS and zone.ammo_depot_intact then
                        local strike_op = self:createStrikeOperation(zone, "LOGISTICS")
                        table.insert(self.available_operations, strike_op)
                    end
                end

                -- CAP over a friendly zone
                if zone.side == friendly_coalition and utils.tableContains(discovered_zones, zone.name) then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < 50000 then
                        local op = self:createCAPOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                -- RECON over enemy zones
                if zone.side == enemy_coalition and not utils.tableContains(discovered_zones, zone.name) then
                    local op = self:createRECONOperation(zone)
                    table.insert(self.available_operations, op)
                end

            end
        end
    end

    function OperationManager:createOperationCode()
        local function codeExists(code)
            if code == 0 then return true end
            for _, op in ipairs(self.available_operations) do
                if op.code == code then return true end
            end
            for _, op in ipairs(self.active_operations) do
                if op.code == code then return true end
            end
            return false
        end

        local code = 0
        while codeExists(code) do
            code = math.random(100, 999)
        end
        return code
    end

    function OperationManager:createCASOperation(target_zone)
        local op = {
            type = OperationTypes.CAS,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Clear Strongpoint "..target_zone.name.." of all units.",
                    completed = false,
                    check = function()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        return zone.side ~= utils.getEnemyCoalition(zone.side) -- if it's neutral or friendly, it's cleared
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createSEADOperation(target_zone)
        -- This is a simplified check. A real implementation would need to identify SR/TR units.
        local op = {
            type = OperationTypes.SEAD,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Take down critical radar components of SAM site situated near " .. target_zone.name,
                    completed = false,
                    check = function()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        if #zone.linked_groups == 0 then return true end
                        local sam_units_alive = false
                        for _, gr in ipairs(zone.linked_groups) do
                            local group_obj = Group.getByName(gr)
                            if group_obj and group_obj:isExist() then
                                local units = group_obj:getUnits()
                                for _, unit in ipairs(units) do
                                    if unit:hasAttribute('SAM SR') or unit:hasAttribute('SAM TR')
                                     or unit:hasAttribute('IR Guided SAM') or unit:hasAttribute("EWR")
                                     then
                                        sam_units_alive = true
                                        break
                                    end
                                end
                            end
                        end
                        if not sam_units_alive then return true end
                        return false
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createDEADOperation(target_zone)
        local op = {
            type = OperationTypes.DEAD,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Clear " .. target_zone.name.. " of all SAM and support units.",
                    completed = false,
                    check = function()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        return zone.side == coalition.side.NEUTRAL
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createStrikeOperation(target_zone, strike_type)
        local target_desc = ""
        local check_func = function () end
        if strike_type == "COMMS" then
            target_desc = "Communications Tower"
            check_func = function()
                local zone = ZoneHandler.getFromName(target_zone.name)
                if not zone then return false end
                return not zone.comms_tower_intact
            end
        elseif strike_type == "LOGISTICS" then
            target_desc = "Ammunition Depot"
            check_func = function()
                local zone = ZoneHandler.getFromName(target_zone.name)
                if not zone then return false end
                return not zone.ammo_depot_intact
            end
        end

        local op = {
            type = OperationTypes.STRIKE,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Destroy the " .. target_desc .. " at " .. target_zone.name,
                    completed = false,
                    check = check_func
                }
            }
        }
        return op
    end

    function OperationManager:createCAPOperation(target_zone)
        local op = {
            type = OperationTypes.CAP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Patrol the airspace above " .. target_zone.name .. " for 5 minutes.",
                    completed = false,
                    start_time = nil,
                    duration = 300, -- 5 minutes
                    radius = 10000, -- 10km
                    check = function(self, player_unit)
                        local player_pos = player_unit:getPoint()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end

                        if not self.start_time then

                            if mist.utils.get2DDist(zone.zone.point,player_pos) <= self.radius then
                                self.start_time = timer.getTime()
                            end

                        else

                            if mist.utils.get2DDist(zone.zone.point,player_pos) > self.radius then
                                trigger.action.outTextForUnit(player_unit:getID(), "CAP timer reset, stay near: "..zone.name, 10)
                                self.start_time = nil
                                return false
                            end

                            if timer.getTime() - self.start_time < self.duration then
                                trigger.action.outTextForUnit(player_unit:getID(), "CAP in progress: "..math.floor(((timer.getTime() - self.start_time)/self.duration)*100).."%", 10)
                                return false
                            end

                            if timer.getTime() - self.start_time >= self.duration then
                                return true
                            end
                        end
                        return false
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createRECONOperation(target_zone)
        local op = {
            type = OperationTypes.RECON,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            objectives = {
                {
                    description = "Conduct aerial reconnaissance near given coordinates",
                    completed = false,
                    start_time = nil,
                    duration = Config.operations.recon_duration,
                    radius = Config.operations.recon_distance_from_zone,
                    check = function(self, player_unit)

                        local player_pos = player_unit:getPoint()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone or not player_pos or not player_unit.getCoalition then return false end


                        

                        if not self.start_time then
                            if mist.utils.get2DDist(zone.zone.point,player_pos) <= self.radius then

                                self.start_time = timer.getTime()
                            end

                        else

                            local lat, lon = coord.LOtoLL(target_zone.zone.point)
                            local mgrs = coord.LLtoMGRS(lat, lon)
                    
                            local outtxt = ""
                            outtxt = outtxt .. string.format("\n\n%s\n%s\nMGRS: %s", 
                            mist.tostringLL(lat, lon, 1), mist.tostringLL(lat, lon, 1, true), mist.tostringMGRS(mgrs, 3))

                            if mist.utils.get2DDist(zone.zone.point,player_pos) > self.radius then
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon aerial imagery lost, remain near:"..outtxt, 3)
                                self.start_time = nil
                                return false
                            end

                            if player_pos.y < Config.operations.recon_minimum_altitude then
                                trigger.action.outTextForUnit(player_unit:getID(),"Recon operation: maintain alt above "..mist.utils.metersToFeet(Config.operations.recon_minimum_altitude).." ft", 5)
                                self.start_time = nil
                                return false
                            end

                            if timer.getTime() - self.start_time < self.duration then
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon in progress: "..math.floor(((timer.getTime() - self.start_time)/self.duration)*100).."%", 5)
                                return false
                            end

                            if timer.getTime() - self.start_time >= self.duration then
                                local player_coalition = player_unit:getCoalition()
                                if player_coalition == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                                    table.insert(stats.blue_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.refreshJtacCmds(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon reports detected targets near "..zone.name,15)
                                elseif player_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                                    table.insert(stats.red_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.refreshJtacCmds(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon reports detected targets near "..zone.name,15)
                                end


                                return true
                            end
                        end

                        return false
                    end
                }
            }
        }
        return op
    end

    ---@param unit Unit
    function OperationManager:showAvailableOperations(unit)
        if not unit or not unit:isExist() or not unit:getPlayerName() then return end

        self:generateOperations()

        
        local outtext = "Recommended Operations"
        if #self.available_operations == 0 then
            outtext = "No operations available at this time."
        end
        
        local operations_displayed = 0
        for _, op in ipairs(self.available_operations) do
            if operations_displayed >= 5 then
                break
            end

            if op.type == OperationTypes.RECON then
                outtext = outtext .. string.format("\n\n %s - ????", op.type)

            else
                outtext = outtext .. string.format("\n\n %s - %s", op.type, op.target_zone_name)
            end
            for _, obj in ipairs(op.objectives) do
                outtext = outtext .. "\n - " .. obj.description
            end
            outtext = outtext .. "\n Operation code: " .. op.code
            operations_displayed = operations_displayed + 1
        end
        trigger.action.outTextForUnit(unit:getID(), outtext, 30)
    end

    ---@param unit Unit
    function OperationManager:cancelOperation(unit)
        if not unit then return end
        if not unit.getPlayerName then return end

        for i, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() then

                table.remove(self.active_operations, i)
                trigger.action.outTextForUnit(unit:getID(), "Operation " .. active_op.operation_name .. " cancelled.", 10)
                return
            end
        end

    end

    ---@param zone_name any
    function OperationManager:isZoneActive(zone_name)
        for _, op in ipairs(self.active_operations) do
            if op.target_zone_name == zone_name then
                return true
            end
        end
        return false
    end

    ---@param zone_name string
        function OperationManager:isMissionProposed(zone_name)
            for _, op in ipairs(self.available_operations) do
                if op.target_zone_name == zone_name then
                    return true
                end
            end
            return false
        end

    function OperationManager:activateOperation(unit, code)
        if not unit then return end
        if not unit.getPlayerName then return end   

        -- Check if player already has a mission
        for _, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() then
                trigger.action.outTextForUnit(unit:getID(), "You are already on an operation: " .. active_op.operation_name, 10)
                return
            end
        end

        local accepted_mission = nil
        local mission_index = nil
        for i, mission in ipairs(self.available_operations) do
            if mission.code == code then
                accepted_mission = mission
                mission_index = i
                break
            end
        end

        if not accepted_mission then
            trigger.action.outTextForUnit(unit:getID(), "Invalid operation code.", 10)
            return
        end

        

        -- Check if the target zone was taken by someone else between the time the menu was generated and now.
        if self:isZoneActive(accepted_mission.target_zone_name) then
            trigger.action.outTextForUnit(unit:getID(), "Operation Aborted: Target zone " .. accepted_mission.target_zone_name .. " is already being engaged by another unit.", 10)
            
            -- Optional: Remove it from available list so they don't try again immediately
            table.remove(self.available_operations, mission_index)
            return
        end

        local zone_tgt = ZoneHandler.getFromName(accepted_mission.target_zone_name)
        if not zone_tgt then
            trigger.action.outTextForUnit(unit:getID(), "Target zone not found for this operation.", 10)
            return
        end

        -- Move from available to active
        table.remove(self.available_operations, mission_index)
        accepted_mission.status = OperationStatus.ACTIVE
        accepted_mission.assigned_player_id = unit:getID()
        accepted_mission.assigned_unit_name = unit:getName()
        table.insert(self.active_operations, accepted_mission)

        local outtxt = string.format("\n%s Operation %s Initiated", accepted_mission.type, accepted_mission.operation_name)
        local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
        local mgrs = coord.LLtoMGRS(lat, lon)
        outtxt = outtxt .. "\n\nTarget area: " .. accepted_mission.target_zone_name
        outtxt = outtxt .. string.format("\n\nApproximate location coordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(lat, lon, 1), mist.tostringLL(lat, lon, 1, true), mist.tostringMGRS(mgrs, 3))

        trigger.action.outTextForUnit(unit:getID(), outtxt, 25)
        -- Create briefing/markers if needed
    end

    function OperationManager:checkObjectives(player_unit_for_cap)
        for i = #self.active_operations, 1, -1 do
            local op = self.active_operations[i]
            if op then
                local all_objectives_complete = true

                ---@type Unit
                local player_unit = player_unit_for_cap or Unit.getByName(op.assigned_unit_name)

                if not player_unit or not player_unit:isExist() then

                else
                    for _, obj in ipairs(op.objectives) do
                        if not obj.completed then

                            -- CAP requires unit to check position
                            if obj.check(obj, player_unit) then
                                obj.completed = true
                                -- trigger.action.outTextForUnit(player_unit:getID(), "Objective complete: " .. obj.description, 15)
                            else
                                all_objectives_complete = false
                            end
                        end
                    end

                    if all_objectives_complete then
                        op.status = OperationStatus.COMPLETED
                        trigger.action.outTextForUnit(player_unit:getID(), "Operation " .. op.operation_name .. " completed !", 20)
                        local user = ExperienceManager:fetchUser(player_unit)
                        if user then
                            user.missions_completed = user.missions_completed + 1
                            user.unclaimed_xp = user.unclaimed_xp + Config.reward_system.xp_per_mission_completed
                            user.unclaimed_tokens = user.unclaimed_tokens + Config.reward_system.token_per_mission_completed
                            trigger.action.outTextForUnit(player_unit:getID(), "+" .. Config.reward_system.xp_per_mission_completed .. " XP; +" .. Config.reward_system.token_per_mission_completed .. " Tokens.\nReturn to base to claim your rewards.", 10)
                        end


                        table.remove(self.active_operations, i)
                    end
                end
            end
        end
    end

    function OperationManager:checkCapOperations()
        for i = #self.active_operations, 1, -1 do
            local op = self.active_operations[i]
            if op.type == OperationTypes.CAP then
                local player_unit = Unit.getByName(op.assigned_unit_name)

                if not player_unit or not player_unit:isExist() or not player_unit:getPlayerName() then
                    -- Player left server, died, or is no longer in the unit. Abort mission.
                    -- This is a fallback; events should catch this first.
                    op.status = OperationStatus.FAILED
                    trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: operative lost.", 15)
                    table.remove(self.active_operations, i)
                else
                    -- Check only this specific CAP operation
                    self:checkObjectives(player_unit)
                end
            end
        end
    end

    function OperationManager:tick()
        -- The tick now only needs to check for time-based objectives like CAP
        -- self:checkCapOperations()
        self:checkObjectives()
    end
end


