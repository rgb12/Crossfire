---@class Operation
---@field type OperationTypes
---@field code number
---@field status OperationStatus
---@field target_zone_name string
---@field operation_name string
---@field assigned_player_id number | nil
---@field assigned_unit_name string | nil
---@field xp_reward number
---@field objectives table
---@field is_coop boolean -- Whether this operation supports co-op
---@field coop_leader_id number | nil -- Unit ID of the player who created the operation
---@field coop_leader_name string | nil -- Name of the unit who created the operation
---@field coop_members table<number, string> -- Map of unit IDs to unit names
---@field coop_join_code number | nil -- Code for other players to join this co-op operation
---@field pilot_position vec3 | nil -- For CSAR operations: position of downed pilot
---@field smoke_spawned boolean | nil -- For CSAR operations: whether smoke has been spawned
---@field load_zone_name string | nil -- For Strategic Airlift operations
---@field strategic_manifest table[] | nil -- Requested CTLD parts for Strategic Airlift
---@field strategic_manifest_text string | nil -- Human-readable manifest
---@field delivery_radius number | nil -- Delivery validation radius for Strategic Airlift
---@field hold_duration number | nil -- Hold duration near destination for Strategic Airlift
---@field aircraft_category string | nil -- helicopter|fixed_wing selected at activation
---@field time_limit_seconds number | nil -- Mission timer for Strategic Airlift
---@field deadline_time number | nil -- Absolute mission deadline for Strategic Airlift
---@field operation_uid string | nil -- Runtime unique id for temporary asset tracking
---@field required_recover_crates number | nil -- Required crate count for Recover operations
---@field recover_op_tag string | nil -- OPID tag used for Recover crate naming

---@class OperationManager
---@field side coalition.side
---@field home_airbase ZoneHandler|nil
---@field last_generation_time number
---@field generation_cooldown number seconds>0
---@field downed_pilots vec3[]
---@field available_operations Operation[]
---@field active_operations Operation[]
---@field blue_downed_pilots vec3[]
---@field red_downed_pilots vec3[]
---@field blue_available_operations Operation[]
---@field red_available_operations Operation[]
---@field blue_active_operations Operation[]
---@field red_active_operations Operation[]
OperationManager = {}
do
    OperationManager.__index = OperationManager

    OperationManager.instance = nil
    OperationManager.event_handler_registered = false

    OperationManager.EventHandler = {}

    ---@param event table
    function OperationManager.EventHandler:onEvent(event)
        local instance = OperationManager.instance
        if not instance then return end
        pcall(function() instance:onEvent(event) end)
    end

    ---@param side coalition.side
    function OperationManager:setCoalitionScope(side)
        if side ~= coalition.side.BLUE and side ~= coalition.side.RED then
            return
        end

        self.side = side
        self.home_airbase = (side == coalition.side.BLUE and blue_airbase) or red_airbase or self.home_airbase
        self.downed_pilots = (side == coalition.side.BLUE and self.blue_downed_pilots) or self.red_downed_pilots
        self.available_operations = (side == coalition.side.BLUE and self.blue_available_operations) or self.red_available_operations
        self.active_operations = (side == coalition.side.BLUE and self.blue_active_operations) or self.red_active_operations
    end

    ---@param unit Unit|nil
    function OperationManager:setCoalitionScopeForUnit(unit)
        if not unit or not unit.getCoalition then return end
        self:setCoalitionScope(unit:getCoalition())
    end

    ---@param coalition_side coalition.side
    ---@return Operation[]
    function OperationManager:getActiveOperationsForSide(coalition_side)
        if coalition_side == coalition.side.BLUE then
            return self.blue_active_operations
        end
        if coalition_side == coalition.side.RED then
            return self.red_active_operations
        end
        return {}
    end

    function OperationManager:new(blue_home_airbase, red_home_airbase)
        if OperationManager.instance then
            OperationManager.instance.home_airbase = blue_home_airbase or OperationManager.instance.home_airbase
            OperationManager.instance.blue_home_airbase = blue_home_airbase or OperationManager.instance.blue_home_airbase
            OperationManager.instance.red_home_airbase = red_home_airbase or OperationManager.instance.red_home_airbase
            return OperationManager.instance
        end

        local obj = {
            side = coalition.side.BLUE,
            home_airbase = blue_home_airbase,
            blue_home_airbase = blue_home_airbase,
            red_home_airbase = red_home_airbase,
            downed_pilots = {},
            available_operations = {},
            active_operations = {},
            blue_downed_pilots = {},
            red_downed_pilots = {},
            blue_available_operations = {},
            red_available_operations = {},
            blue_active_operations = {},
            red_active_operations = {},
            blue_last_generation_time = 0,
            red_last_generation_time = 0,
            last_generation_time = 0, -- Cache timestamp
            generation_cooldown = Config.operations.operation_refresh_time or 30, -- seconds
        }
        setmetatable(obj, self)
        obj:setCoalitionScope(coalition.side.BLUE)
        OperationManager.instance = obj
        if not OperationManager.event_handler_registered then
            world.addEventHandler(OperationManager.EventHandler)
            OperationManager.event_handler_registered = true
        end
        return obj
    end


    ---@param unit Unit
    function OperationManager:showActiveOperation(unit)
        if not unit or not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        local active_mission = nil
        for _, op in ipairs(self.active_operations) do
            -- Check if player is the leader
            if op.assigned_player_id == unit:getID() then
                active_mission = op
                break
            end
            -- Check if player is a co-op member
            if op.is_coop and op.coop_members and op.coop_members[unit:getID()] then
                active_mission = op
                break
            end
        end

        if not active_mission then
            trigger.action.outTextForUnit(unit_id, "No active operation.", 10)
            trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
            return
        end

        -- Handle CSAR operations differently
        if active_mission.type == OperationTypes.CSAR then
            if not active_mission.pilot_position then
                trigger.action.outTextForUnit(unit_id, "Pilot position not found.", 10)
                self:cancelOperation(unit)
                return
            end
            
            local lat, lon = coord.LOtoLL(active_mission.pilot_position)
            local mgrs = coord.LLtoMGRS(lat, lon)
            
            local outtxt = string.format("ACTIVE OPERATION: %s\nType: %s\n\nMission: Rescue downed pilot",
                active_mission.operation_name, active_mission.type)
            
            outtxt = outtxt .. string.format("\n\nDowned pilot location:\n%s\n%s\nMGRS: %s",
                mist.tostringLL(lat, lon, 2), mist.tostringLL(lat, lon, 2, true), mist.tostringMGRS(mgrs, 3))
            
            outtxt = outtxt .. "\n\nObjectives:"
            for i, obj in ipairs(active_mission.objectives) do
                local status = ""--obj.completed and "[Completed]" or "[Pending]"
                outtxt = outtxt .. string.format("\n%d. %s %s", i, obj.description, status)
            end
            
            -- Show distance to pilot
            local player_pos = unit:getPoint()
            if player_pos and active_mission.pilot_position then
                local dist = mist.utils.get2DDist(player_pos, active_mission.pilot_position)
                outtxt = outtxt .. string.format("\n\nDistance to pilot: %.0fm", dist)
                outtxt = outtxt .. string.format("\nRequired proximity: %dm", Config.operations.csar_rescue_radius or 50)
            end
            trigger.action.outTextForUnit(unit_id, outtxt, 120)
            trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
            return
        end

        local zone_tgt = ZoneHandler.getFromName(active_mission.target_zone_name)
        if not zone_tgt or not zone_tgt.zone or not zone_tgt.zone.point then
            trigger.action.outTextForUnit(unit_id, "Target zone not found for this operation.", 10)
            self:cancelOperation(unit)
            return
        end

        local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
        local mgrs = coord.LLtoMGRS(lat, lon)

        local outtxt = ""
        if active_mission.type == OperationTypes.RECON or active_mission.type == OperationTypes.DEEP_RECON
        or active_mission.type == OperationTypes.INTERCEPT then
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s",
            active_mission.operation_name, active_mission.type)
        else
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s\nTarget: %s",
                active_mission.operation_name, active_mission.type, active_mission.target_zone_name)
        end
        
        if active_mission.type ~= OperationTypes.INTERCEPT then
            outtxt = outtxt .. string.format("\n\nCoordinates:\n%s\n%s\nMGRS: %s",
                mist.tostringLL(lat, lon, 5), mist.tostringLL(lat, lon, 5, true), mist.tostringMGRS(mgrs, 5))
        end

        outtxt = outtxt .. "\n\nObjectives:"
        for i, obj in ipairs(active_mission.objectives) do
            -- local status = obj.completed and "[Completed]" or "[Pending]"
            local status = ""
            outtxt = outtxt .. string.format("\n%d. %s %s", i, obj.description, status)
        end

        trigger.action.outTextForUnit(unit_id, outtxt, 120)
        trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
    end

    --- @param event table
    function OperationManager:onEvent(event)
        if event and event.initiator and event.initiator.getCoalition then
            self:setCoalitionScope(event.initiator:getCoalition())
        end

        if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH or event.id == world.event.S_EVENT_PILOT_DEAD then
            if event.initiator and event.initiator.getPlayerName then
                local dead_unit_name = event.initiator.unit_name or event.initiator:getName()
                local dead_unit_id = event.initiator:getID()

                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    
                    -- Check if dead player is the leader
                    if op.assigned_unit_name == dead_unit_name then
                        -- If co-op operation and there are members, transfer leadership to first active member
                        if op.is_coop and op.coop_members then
                            local new_leader_found = false
                            for member_id, member_unit_name in pairs(op.coop_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    -- Transfer leadership
                                    op.assigned_player_id = member_id
                                    op.assigned_unit_name = member_unit_name
                                    op.coop_leader_id = member_id
                                    op.coop_leader_name = member_unit_name
                                    
                                    -- Remove from members list
                                    op.coop_members[member_id] = nil
                                    
                                    -- Notify remaining participants
                                    trigger.action.outTextForUnit(member_id, "You are now the operation leader!", 10)
                                    trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")

                                    for remaining_id, _ in pairs(op.coop_members) do
                                        trigger.action.outTextForUnit(remaining_id, member_unit:getPlayerName() .. " is now the operation leader.", 10)
                                        trigger.action.outSoundForUnit(remaining_id, "radio_txrx.ogg")
                                    end
                                    
                                    new_leader_found = true
                                    break
                                end
                            end
                            
                            -- If no new leader found, fail the operation
                            if not new_leader_found then
                                op.status = OperationStatus.FAILED
                                trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: all operatives lost.", 15)
                                if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                    self:cancelStrategicAirliftOperation(op, true)
                                elseif op.type == OperationTypes.RECOVER then
                                    self:cancelRecoverOperation(op, true)
                                end
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, "SITREP: " .. op.operation_name .. " operation failed!.", 15)
                            if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                self:cancelStrategicAirliftOperation(op, true)
                            elseif op.type == OperationTypes.RECOVER then
                                self:cancelRecoverOperation(op, true)
                            end
                            table.remove(self.active_operations, i)
                        end
                    else
                        -- Check if dead player is a co-op member
                        if op.is_coop and op.coop_members and op.coop_members[dead_unit_id] then
                            op.coop_members[dead_unit_id] = nil
                            
                            -- Notify remaining participants
                            local leader_unit = Unit.getByName(op.assigned_unit_name)
                            if leader_unit and leader_unit:isExist() then
                                trigger.action.outTextForUnit(op.assigned_player_id, "A co-op member has been lost.", 10)
                                trigger.action.outSoundForUnit(op.assigned_player_id, "radio_txrx.ogg")

                            end
                            for member_id, _ in pairs(op.coop_members) do
                                trigger.action.outTextForUnit(member_id, "A co-op member has been lost.", 10)
                                trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")

                            end
                        end
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_KILL then
            -- Handle kill events for INTERCEPT operations
            if event.initiator and event.target then
                for _, op in ipairs(self.active_operations) do
                    if op.type == OperationTypes.INTERCEPT and op.is_coop then
                        -- Check if killer is the leader or any co-op member
                        local killer_unit_name = event.initiator:getName()
                        local is_participant = false
                        
                        if killer_unit_name == op.assigned_unit_name then
                            is_participant = true
                        elseif op.coop_members then
                            for _, member_unit_name in pairs(op.coop_members) do
                                if killer_unit_name == member_unit_name then
                                    is_participant = true
                                    break
                                end
                            end
                        end
                        
                        if is_participant then
                            for _, obj in ipairs(op.objectives) do
                                if obj.onKill and not obj.completed then
                                    -- Pass the actual killer unit instead of just the leader
                                    obj:onKill(event, event.initiator, op.target_zone_name)
                                end
                            end
                        end
                    elseif op.type == OperationTypes.INTERCEPT then
                        -- Non-coop intercept - original behavior
                        local player_unit = Unit.getByName(op.assigned_unit_name)
                        if player_unit and player_unit:isExist() then
                            for _, obj in ipairs(op.objectives) do
                                if obj.onKill and not obj.completed then
                                    obj:onKill(event, player_unit, op.target_zone_name)
                                end
                            end
                        end
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_HIT and event.weapon then
            local weapon_desc = event.weapon:getDesc()
            if not weapon_desc or not weapon_desc.category then return end

            local is_bomb_or_rocket = (weapon_desc.category == Weapon.Category.BOMB
                                       or weapon_desc.category == Weapon.Category.ROCKET)
            if not is_bomb_or_rocket then return end

            local hit_point = event.weapon:getPoint()
            if not hit_point then return end

            local lock_duration = Config.operations.runway_destroyed_duration or 3600
            for _, zone in ipairs(zones) do
                if zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name and not zone:isRunwayDisabled() then
                    local airbase = Airbase.getByName(zone.airbase_name)
                    if airbase and airbase.getRunways then
                        local runways = airbase:getRunways()
                        if runways then
                            for _, runway in pairs(runways) do
                                if runway.position and runway.course and runway.length and runway.width then
                                    local dx = hit_point.x - runway.position.x
                                    local dz = hit_point.z - runway.position.z
                                    local cos_course = math.cos(runway.course)
                                    local sin_course = math.sin(runway.course)

                                    local local_x = dx * cos_course + dz * sin_course
                                    local local_z = -dx * sin_course + dz * cos_course

                                    if math.abs(local_x) <= (runway.length / 2)
                                    and math.abs(local_z) <= (runway.width / 2) then
                                        zone:markRunwayDisabled(lock_duration)
                                        zone:drawF10()

                                        trigger.action.outTextForCoalition(zone.side, "Sector ALERT: Runway at " .. zone.name .. " is inoperative.", 15)
                                        trigger.action.outSoundForCoalition(zone.side, "alert1.ogg")

                                        local attacker_side = nil
                                        if event.initiator and event.initiator.getCoalition then
                                            attacker_side = event.initiator:getCoalition()
                                        end
                                        if attacker_side and attacker_side ~= zone.side then
                                            trigger.action.outTextForCoalition(attacker_side, "SITREP: Runway strike successful at " .. zone.name .. ".", 12)
                                            trigger.action.outSoundForCoalition(attacker_side, "chatter2.ogg")
                                        end

                                        MissionLogger:info("Runway disabled at " .. zone.name)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_PLAYER_LEAVE_UNIT then
            if event.initiator then
                local unit_name = event.initiator:getName()
                local unit_id = event.initiator:getID()
                
                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    
                    -- Check if leaving player is the leader
                    if op.assigned_unit_name == unit_name then
                        -- If co-op operation and there are members, transfer leadership
                        if op.is_coop and op.coop_members then
                            local new_leader_found = false
                            for member_id, member_unit_name in pairs(op.coop_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    -- Transfer leadership
                                    op.assigned_player_id = member_id
                                    op.assigned_unit_name = member_unit_name
                                    op.coop_leader_id = member_id
                                    op.coop_leader_name = member_unit_name
                                    
                                    -- Remove from members list
                                    op.coop_members[member_id] = nil
                                    
                                    -- Notify remaining participants
                                    trigger.action.outTextForUnit(member_id, "You are now the operation leader!", 10)
                                    trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")
                                    for remaining_id, _ in pairs(op.coop_members) do
                                        trigger.action.outTextForUnit(remaining_id, member_unit:getPlayerName() .. " is now the operation leader.", 10)
                                        trigger.action.outSoundForUnit(remaining_id, "radio_txrx.ogg")
                                    end
                                    
                                    new_leader_found = true
                                    break
                                end
                            end
                            
                            if not new_leader_found then
                                op.status = OperationStatus.FAILED
                                trigger.action.outTextForCoalition(self.side, op.type .. " Operation " .. op.operation_name .. " failed: all operatives left.", 15)
                                trigger.action.outSoundForCoalition(self.side, "radio_txrx.ogg")
                                
                                if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                    self:cancelStrategicAirliftOperation(op, true)
                                elseif op.type == OperationTypes.RECOVER then
                                    self:cancelRecoverOperation(op, true)
                                end
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, op.type .. " " .. op.operation_name .. " operation failed, operative left.", 15)
                            if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                self:cancelStrategicAirliftOperation(op, true)
                            elseif op.type == OperationTypes.RECOVER then
                                self:cancelRecoverOperation(op, true)
                            end
                            table.remove(self.active_operations, i)
                        end
                    else
                        -- Check if leaving player is a co-op member
                        if op.is_coop and op.coop_members and op.coop_members[unit_id] then
                            op.coop_members[unit_id] = nil
                            
                            -- Notify remaining participants
                            local leader_unit = Unit.getByName(op.assigned_unit_name)
                            if leader_unit and leader_unit:isExist() then
                                trigger.action.outTextForUnit(op.assigned_player_id, "A co-op member has left the operation.", 10)
                                trigger.action.outSoundForUnit(op.assigned_player_id, "radio_txrx.ogg")
                            end
                            for member_id, _ in pairs(op.coop_members) do
                                trigger.action.outTextForUnit(member_id, "A co-op member has left the operation.", 10)
                                trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")
                            end
                        end
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_EJECTION and event.initiator then
            local eject_unit = event.initiator
            if eject_unit and eject_unit.getPoint and eject_unit.getCoalition then
                local eject_pos = eject_unit:getPoint()

                if self.side == eject_unit:getCoalition() then
                    table.insert(self.downed_pilots, eject_pos)
                    MissionLogger:info("Recorded downed pilot")
                    MissionLogger:info(eject_pos)
                end
            end
        end
    end

    local operations_name = {
    "Direct Resolve", "Rapid Talon", "Iron Sabre", "Titan Hammer",
    "Apex Strike", "Vanguard Fury", "Bold Predator", "Crimson Dagger",
    "Sincere Accord", "Quiet Vigil", "Noble Support", "Unified Assistance",
    "Guardian Shield", "Steady Anchor", "Pacific Relief", "Kindred Spirit",
    "Distant Horizon", "Indigo Prism", "Obsidian Lens", "Silent Echo",
    "Amber Signal", "Vector Trace", "Canyon Mist", "Arctic Frontier",
    "Desert Pulse", "Oceanic Surge", "Mountain Path", "Savanna Gate",
    "Global Sentinel", "Atlantic Link","Kinetic Flow","Rolling Thunder",
    "Copper Shield","Desert Sentry"
}

    function OperationManager:generateOperations()
        -- Performance optimization: Use cached operations if recently generated
        local current_time = timer.getTime()
        local last_generation_time = (self.side == coalition.side.BLUE and self.blue_last_generation_time) or self.red_last_generation_time
        
        -- Allow first generation (last_generation_time == 0) or if cooldown has elapsed
        if last_generation_time > 0 and (current_time - last_generation_time < self.generation_cooldown) then
            return -- Use cached operations
        end
        MissionLogger:info("Regenerating operations")
        if self.side == coalition.side.BLUE then
            self.blue_last_generation_time = current_time
        else
            self.red_last_generation_time = current_time
        end
        self.last_generation_time = current_time
        
        local reference_pos = self.home_airbase.zone.point
        local friendly_coalition = self.side
        local enemy_coalition = utils.getEnemyCoalition(friendly_coalition)

        local function isOffensiveOperation(op_type)
            return op_type == OperationTypes.RECON
                or op_type == OperationTypes.DEEP_RECON
                or op_type == OperationTypes.CAS
                or op_type == OperationTypes.SEAD
                or op_type == OperationTypes.DEAD
                or op_type == OperationTypes.RUNWAY_BOMBING
                or op_type == OperationTypes.STRIKE
        end

        local function isDefensiveOperation(op_type)
            return op_type == OperationTypes.CAP
                or op_type == OperationTypes.INTERCEPT
                or op_type == OperationTypes.AIRDROP
                or op_type == OperationTypes.RECOVER
                or op_type == OperationTypes.STRATEGIC_AIRLIFT
        end

        local discovered_zones = {}
        if self.side == coalition.side.BLUE then
            discovered_zones = stats.blue_discovered_zones
        elseif self.side ==coalition.side.RED then
            discovered_zones = stats.red_discovered_zones
        end

        -- Convert discovered_zones to a hash table for O(1) lookup instead of O(n)
        local discovered_zones_set = {}
        for _, zone_name in ipairs(discovered_zones) do
            discovered_zones_set[zone_name] = true
        end

        for i = #self.available_operations, 1, -1 do
            local op = self.available_operations[i]

            local remove_op = false

            -- If this zone is now Active (taken by a player), remove it from Available.
            if self:isZoneActive(op.target_zone_name) then
                remove_op = true
            elseif op.type ~= OperationTypes.CSAR then
                local zone = ZoneHandler.getFromName(op.target_zone_name)
                if not zone then
                    remove_op = true
                else
                    -- Keep cached ops aligned with their intended target ownership.
                    if isOffensiveOperation(op.type) and zone.side ~= enemy_coalition then
                        remove_op = true
                    elseif isDefensiveOperation(op.type) and zone.side ~= self.side then
                        remove_op = true
                    end

                    -- RECON is only valid for undiscovered enemy zones.
                    local is_discovered = discovered_zones_set[op.target_zone_name] == true
                    if (op.type == OperationTypes.RECON or op.type == OperationTypes.DEEP_RECON) and is_discovered then
                        remove_op = true
                    elseif op.type ~= OperationTypes.RECON and op.type ~= OperationTypes.DEEP_RECON and not is_discovered then
                        remove_op = true
                    end
                end
            end

            if remove_op then
                table.remove(self.available_operations, i)
            end
        end

        local sorted_zones = ZoneHandler.sortZonesByDistance(reference_pos)
        for _, zone in ipairs(sorted_zones) do

            if not self:isZoneActive(zone.name) and not self:isMissionProposed(zone.name)
            then
                -- RECON over enemy zones
                if zone.side == enemy_coalition and not discovered_zones_set[zone.name] then

                    local closest_enemy_zone,d = self.home_airbase:getClosestZone(enemy_coalition)


                    if closest_enemy_zone and d and mist.utils.get2DDist(reference_pos, zone.zone.point) > 2*d then
                        local op = self:createDEEPRECONOperation(zone)
                        table.insert(self.available_operations, op)
                    else
                        local op = self:createRECONOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                if zone.side == enemy_coalition and discovered_zones_set[zone.name] then
                    -- CAS against a STRONGPOINT
                    if zone.zone_type == ZoneTypes.STRONGPOINT then
                        local op = self:createCASOperation(zone)
                        table.insert(self.available_operations, op)
                    end

                    -- SEAD/DEAD against a SAMSITE
                    if zone.zone_type == ZoneTypes.SAMSITE then
                        -- Check if SAM site still has active radar units
                        if UnitHandler.checkIfZoneHasUnitWithAttributes(zone, Config.operations.attributes_for_SEAD_targeting) == true then
                            local sead_op = self:createSEADOperation(zone)
                            table.insert(self.available_operations, sead_op)
                        else
                            local dead_op = self:createDEADOperation(zone)
                            table.insert(self.available_operations, dead_op)
                        end

                    end

                    if zone.zone_type == ZoneTypes.AIRBASE then
                        local op = self:createCASOperation(zone)
                        table.insert(self.available_operations, op)

                        if not zone:isRunwayDisabled() then
                            local runway_op = self:createRunwayBombingOperation(zone)
                            table.insert(self.available_operations, runway_op)
                        end
                    end
                    -- STRIKE against COMMS or LOGISTICS
                    if zone.zone_type == ZoneTypes.COMMS then
                        if zone.comms_tower_intact then
                            local strike_op = self:createStrikeOperation(zone, "COMMS")
                            table.insert(self.available_operations, strike_op)
                        else
                            local op = self:createCASOperation(zone)
                            table.insert(self.available_operations, op)
                        end
                    end

                    if zone.zone_type == ZoneTypes.EWSITE then
                        local op = self:createCASOperation(zone)
                        table.insert(self.available_operations, op)
                    end

                    if zone.zone_type == ZoneTypes.FARP then
                        if zone.linked_statics and #zone.linked_statics > 0 then
                            local strike_op = self:createStrikeOperation(zone, "FARP")
                            table.insert(self.available_operations, strike_op)
                        else
                            local op = self:createCASOperation(zone)
                            table.insert(self.available_operations, op)
                        end
                    end

                    if zone.zone_type == ZoneTypes.LOGISTICS then
                        if zone.ammo_depot_intact then
                            local strike_op = self:createStrikeOperation(zone, "LOGISTICS")
                            table.insert(self.available_operations, strike_op)
                        else
                            local op = self:createCASOperation(zone)
                            table.insert(self.available_operations, op)
                        end
                    end
                end

                -- CAP over a friendly zone
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < 50000 then
                        local op = self:createCAPOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                -- INTERCEPT near friendly zones close to enemy territory
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < (Config.operations.intercept_max_distance_to_enemy or 75000) then
                        local op = self:createINTERCEPTOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                -- AIRDROP over friendly zones
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] and zone.level < 4 then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < Config.operations.max_distance_to_frontline_for_airdrops then
                        local op = self:createAIRDROPOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                -- REINFORCEMENT (helicopter) over friendly zones
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] and zone.level < 4 then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < Config.operations.max_distance_to_frontline_for_airdrops then
                        local op = self:createREINFORCEMENTOperation(zone)
                        table.insert(self.available_operations, op)
                    end
                end

                -- RECOVER operation from frontline defensive sites to friendly AIRBASE/FARP
                if Config.operations.recover and Config.operations.recover.enabled
                and zone.side == friendly_coalition
                and discovered_zones_set[zone.name]
                and utils.tableContains({ZoneTypes.STRONGPOINT, ZoneTypes.SAMSITE, ZoneTypes.EWSITE}, zone.zone_type) then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < (Config.operations.recover.max_distance_to_frontline or Config.operations.max_distance_to_frontline_for_airdrops) then
                        local recover_target = self:findRecoverTargetZone(zone, friendly_coalition, discovered_zones_set)
                        if recover_target and not self:isMissionProposed(recover_target.name) and not self:isZoneActive(recover_target.name) then
                            local op = self:createRECOVEROperation(zone, recover_target)
                            if op then
                                table.insert(self.available_operations, op)
                            end
                        end
                    end
                end

                -- STRATEGIC AIRLIFT between friendly logistics zones
                if Config.operations.strategic_airlift.enabled
                and zone.side == friendly_coalition and discovered_zones_set[zone.name] then
                    local target_zone = self:findStrategicAirliftTargetZone(zone, friendly_coalition, discovered_zones_set)
                    if target_zone and not self:isMissionProposed(target_zone.name) and not self:isZoneActive(target_zone.name) then
                        local op = self:createSTRATEGICAIRLIFTOperation(zone, target_zone)
                        if op then
                            table.insert(self.available_operations, op)
                        end
                    end
                end
            end
        end
        
        -- CSAR operations for downed pilots
        if #self.downed_pilots > 0 then
            -- Check if we already have a CSAR operation for each downed pilot
            local csar_count = 0
            for _, op in ipairs(self.available_operations) do
                if op.type == OperationTypes.CSAR then
                    csar_count = csar_count + 1
                end
            end
            for _, active_op in ipairs(self.active_operations) do
                if active_op.type == OperationTypes.CSAR then
                    csar_count = csar_count + 1
                end
            end
            
            -- Create CSAR operations for pilots that don't have one yet
            while csar_count < #self.downed_pilots do
                local csar_op = self:createCSAROperation()
                if csar_op then
                    table.insert(self.available_operations, csar_op)
                    csar_count = csar_count + 1
                else
                    break
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

    ---@param load_zone ZoneHandler
    ---@param target_zone ZoneHandler
    ---@param aircraft_category UserAircraftCategories
    ---@return number
    function OperationManager:computeStrategicAirliftTimeLimit(load_zone, target_zone, aircraft_category)
        local dist_m = mist.utils.get2DDist(load_zone.zone.point, target_zone.zone.point)
        local raw = math.floor((dist_m / 1000) * Config.operations.strategic_airlift.seconds_per_km[aircraft_category])
        return math.max(Config.operations.strategic_airlift.min_time[aircraft_category], math.min(raw, Config.operations.strategic_airlift.max_time[aircraft_category]))
    end

    ---@param load_zone ZoneHandler
    ---@param target_zone ZoneHandler
    ---@param aircraft_category UserAircraftCategories
    ---@return number
    function OperationManager:computeStrategicAirliftReward(load_zone, target_zone, aircraft_category)
        local base_xp = Config.operations.strategic_airlift.base_xp or 1200
        local xp_per_km = Config.operations.strategic_airlift.xp_per_km or 2
        local aircraft_category_mult = 1
        aircraft_category_mult = Config.operations.strategic_airlift.xp_aircraft_category_multiplier[aircraft_category]
        local dist_m = mist.utils.get2DDist(load_zone.zone.point, target_zone.zone.point)
        local reward = (base_xp + math.floor((dist_m / 1000) * xp_per_km)) * aircraft_category_mult
        return math.floor(reward)
    end

    ---@param load_zone ZoneHandler
    ---@param friendly_coalition coalition.side
    ---@param discovered_set table<string, boolean>
    ---@return ZoneHandler|nil
    function OperationManager:findStrategicAirliftTargetZone(load_zone, friendly_coalition, discovered_set)
        local min_heli = Config.operations.strategic_airlift.min_route_distance.helicopter
        local max_fixed = Config.operations.strategic_airlift.max_route_distance.fixed_wing

        local candidates = {}
        for _, zone in ipairs(zones) do
            if zone.name ~= load_zone.name
            and zone.side == friendly_coalition
            and discovered_set[zone.name] then
                local dist = mist.utils.get2DDist(load_zone.zone.point, zone.zone.point)
                if dist >= min_heli and dist <= max_fixed then
                    table.insert(candidates, { zone = zone, dist = dist })
                end
            end
        end

        if #candidates == 0 then return nil end

        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        local pick_idx = math.random(1, #candidates)
        return candidates[pick_idx].zone
    end

    ---@param source_zone ZoneHandler
    ---@param friendly_coalition coalition.side
    ---@param discovered_set table<string, boolean>
    ---@return ZoneHandler|nil
    function OperationManager:findRecoverTargetZone(source_zone, friendly_coalition, discovered_set)
        local candidates = {}
        for _, zone in ipairs(zones) do
            if zone.name ~= source_zone.name
            and zone.side == friendly_coalition
            and discovered_set[zone.name]
            and (zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP) then
                table.insert(candidates, zone)
            end
        end

        if #candidates == 0 then return nil end
        return candidates[math.random(1, #candidates)]
    end

    ---@param op Operation
    ---@param source_zone ZoneHandler
    function OperationManager:spawnRecoverSourceCrates(op, source_zone)
        if not op or not op.operation_uid or not source_zone or not source_zone.zone then return end
        local recover_cfg = (Config.operations and Config.operations.recover) or {}
        local min_dist = recover_cfg.min_spawn_distance or 200
        local max_dist = recover_cfg.max_spawn_distance or 300
        local count = op.required_recover_crates or 2
        local op_tag = op.recover_op_tag or "OPID"

        for i = 1, count do
            local theta = math.random() * 2 * math.pi
            local dist = math.random(min_dist, max_dist)
            local x = source_zone.zone.point.x + (math.cos(theta) * dist)
            local z = source_zone.zone.point.z + (math.sin(theta) * dist)
            local name = string.format("%s%s_%d", Config.ctld.packed_asset_prefix, op_tag, ctld.getNextGroupId())

            local spawned = mist.dynAddStatic({
                type = CargoCrates.SuppliesCrate,
                name = name,
                country = self.side == coalition.side.BLUE and country.id.USA or country.id.RUSSIA,
                category = "Cargos",
                x = x,
                y = z
            })

            if spawned then
                ctld.registerOperationAsset(op.operation_uid, {
                    unit_name = name,
                    part_name = CargoCrates.SuppliesCrate,
                    point = { x = x, y = land.getHeight({ x = x, y = z }), z = z },
                    object_type = "static",
                    coalition = self.side
                })
            end
        end
    end

    ---@return part[]
    function OperationManager:getStrategicAirliftEligibleParts()
        local eligible = {}
        for _, part in ipairs(ctld.parts or {}) do
            if part.type == ctld.AssetTypes.TROOPS
            or part.type == ctld.AssetTypes.CARGO_CRATES
            or part.type == ctld.AssetTypes.VEHICLES then
                local valid = true
                if part.type == ctld.AssetTypes.VEHICLES then
                    if (part.crates_required or 1) > Config.operations.strategic_airlift.max_vehicle_crates_required then
                        valid = false
                    end
                end
                if part.weight and part.weight > 10000 then
                    valid = false
                end
                if valid then
                    table.insert(eligible, part)
                end
            end
        end
        return eligible
    end

    ---@param entries part[]
    ---@param part_type string
    ---@return part[]
    function OperationManager:filterPartsByType(entries, part_type)
        local out = {}
        for _, entry in ipairs(entries) do
            if entry.type == part_type then
                table.insert(out, entry)
            end
        end
        return out
    end

    ---@return table[]
    function OperationManager:buildStrategicAirliftManifest()
        local cfg = Config.operations.strategic_airlift or {}
        local min_items = cfg.min_manifest_items or 3
        local max_items = cfg.max_manifest_items or 6
        local total_items = math.random(min_items, max_items)

        local eligible = self:getStrategicAirliftEligibleParts()
        local troops = self:filterPartsByType(eligible, ctld.AssetTypes.TROOPS)
        local crates = self:filterPartsByType(eligible, ctld.AssetTypes.CARGO_CRATES)
        local vehicles = self:filterPartsByType(eligible, ctld.AssetTypes.VEHICLES)

        local troops_weight = (cfg.category_weights and cfg.category_weights.troops) or 35
        local crates_weight = (cfg.category_weights and cfg.category_weights.crates) or 40
        local vehicles_weight = (cfg.category_weights and cfg.category_weights.vehicles) or 25

        local function pick_category()
            local total = troops_weight + crates_weight + vehicles_weight
            local r = math.random(1, total)
            if r <= troops_weight then return ctld.AssetTypes.TROOPS end
            if r <= (troops_weight + crates_weight) then return ctld.AssetTypes.CARGO_CRATES end
            return ctld.AssetTypes.VEHICLES
        end

        local manifest_by_name = {}
        for _ = 1, total_items do
            local category = pick_category()
            local pool = troops
            if category == ctld.AssetTypes.CARGO_CRATES then pool = crates end
            if category == ctld.AssetTypes.VEHICLES then pool = vehicles end

            if #pool > 0 then
                local picked = pool[math.random(1, #pool)]
                if not manifest_by_name[picked.name] then
                    manifest_by_name[picked.name] = {
                        part_name = picked.name,
                        part_desc = picked.desc,
                        part_type = picked.type,
                        quantity = 0
                    }
                end
                manifest_by_name[picked.name].quantity = manifest_by_name[picked.name].quantity + 1
            end
        end

        local manifest = {}
        for _, row in pairs(manifest_by_name) do
            table.insert(manifest, row)
        end
        table.sort(manifest, function(a, b) return a.part_desc < b.part_desc end)
        return manifest
    end

    ---@param manifest table[]
    ---@return string
    function OperationManager:formatStrategicAirliftManifest(manifest)
        local lines = {}
        for _, row in ipairs(manifest or {}) do
            table.insert(lines, string.format("- %s x%d", row.part_desc, row.quantity))
        end
        return table.concat(lines, "\n")
    end

    ---@param operation Operation
    ---@return table<string, number>
    function OperationManager:getStrategicAirliftDeliveredCounts(operation)
        local counts = {}
        if not operation or not operation.operation_uid then return counts end

        local assets = ctld.getOperationAssets(operation.operation_uid)
        local target_zone = ZoneHandler.getFromName(operation.target_zone_name)
        if not target_zone then return counts end
        local delivery_radius = operation.delivery_radius or ((Config.operations.strategic_airlift and Config.operations.strategic_airlift.delivery_radius) or 1200)

        for _, asset in ipairs(assets) do
            local obj = nil
            if asset.object_type == "static" then
                obj = StaticObject.getByName(asset.unit_name)
            else
                obj = Unit.getByName(asset.unit_name)
            end

            if obj and obj:isExist() and obj.getPoint then
                local point = obj:getPoint()
                if mist.utils.get2DDist(point, target_zone.zone.point) <= delivery_radius then
                    counts[asset.part_name] = (counts[asset.part_name] or 0) + 1
                end
            end
        end

        return counts
    end

    ---@param operation Operation
    ---@param cleanup_assets boolean
    function OperationManager:cancelStrategicAirliftOperation(operation, cleanup_assets)
        if not operation then return end

        local leader = nil
        if operation.assigned_unit_name then
            leader = Unit.getByName(operation.assigned_unit_name)
        end
        if leader and leader:isExist() then
            ctld.clearOperationTaskingForUnit(leader)
        end

        if operation.operation_uid then
            if cleanup_assets then
                ctld.clearOperationAssets(operation.operation_uid)
            else
                ctld.clearOperationLoads(operation.operation_uid)
            end
        end
    end

    ---@param operation Operation
    ---@param cleanup_assets boolean
    function OperationManager:cancelRecoverOperation(operation, cleanup_assets)
        if not operation then return end

        local leader = nil
        if operation.assigned_unit_name then
            leader = Unit.getByName(operation.assigned_unit_name)
        end
        if leader and leader:isExist() then
            ctld.clearOperationTaskingForUnit(leader)
        end

        if operation.operation_uid then
            if cleanup_assets then
                ctld.clearOperationAssets(operation.operation_uid)
            else
                ctld.clearOperationLoads(operation.operation_uid)
            end
        end
    end

    ---@param source_zone ZoneHandler
    ---@param target_zone ZoneHandler
    ---@return Operation
    function OperationManager:createRECOVEROperation(source_zone, target_zone)
        local manager = self
        local recover_cfg = (Config.operations and Config.operations.recover) or {}
        local min_crates = recover_cfg.min_crates or 2
        local max_crates = recover_cfg.max_crates or 4
        local required_crates = math.random(min_crates, max_crates)

        ---@type Operation
        local op = {
            type = OperationTypes.RECOVER,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = recover_cfg.xp_reward or 700,
            load_zone_name = source_zone.name,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            required_recover_crates = required_crates,
            delivery_radius = recover_cfg.delivery_radius or 1200,
            objectives = {
                {
                    description = string.format("Load %d recover crates at %s", required_crates, source_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end

                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.RECOVER then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op or not owner_op.operation_uid then return false end

                        local loaded = ctld.getOperationLoads(owner_op.operation_uid)
                        if (loaded[CargoCrates.SuppliesCrate] or 0) < (owner_op.required_recover_crates or required_crates) then
                            return false
                        end

                        trigger.action.outTextForUnit(player_unit:getID(), "Recover: cargo loaded. Proceed to destination and unload.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                },
                {
                    description = string.format("Unload recover crates at %s", target_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end

                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.RECOVER then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op then return false end

                        local delivered = manager:getStrategicAirliftDeliveredCounts(owner_op)
                        if (delivered[CargoCrates.SuppliesCrate] or 0) < (owner_op.required_recover_crates or required_crates) then
                            return false
                        end

                        trigger.action.outTextForUnit(player_unit:getID(), "Recover: delivery confirmed. Supplies are available for unpack.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                }
            }
        }

        return op
    end

    function OperationManager:createCASOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.CAS,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            xp_reward = 750,
            is_coop = true,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Clear Strongpoint "..target_zone.name.." of all units.",
                    completed = false,
                    check = function(self, player_unit)
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        return zone.side == player_unit:getCoalition()
                        or zone.side == coalition.side.NEUTRAL
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createCSAROperation()
        if #self.downed_pilots == 0 then return nil end

        -- Get the first downed pilot position
        local pilot_pos = self.downed_pilots[1]
        -- set the y coord to ground level
        pilot_pos.y = land.getHeight({x = pilot_pos.x, y = pilot_pos.z})

        ---@type Operation
        local op = {
            type = OperationTypes.CSAR,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 600,
            target_zone_name = "CSAR Location", -- Special identifier for CSAR
            operation_name = operations_name[math.random(#operations_name)],
            pilot_position = pilot_pos, -- Store the actual position
            smoke_spawned = false, -- Track if smoke has been spawned
            is_coop = false, -- CSAR is typically solo but can be changed
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Locate and rescue the downed pilot",
                    completed = false,
                    rescue_radius = Config.operations.csar_rescue_radius or 50,
                    check = function(self, player_unit)
                        local player_pos = player_unit:getPoint()
                        if not player_pos then return false end

                        -- Check distance from downed pilot
                        local dist = mist.utils.get3DDist(pilot_pos, player_pos)
                        if dist <= self.rescue_radius then
                            -- Player is close enough - rescue successful
                            return true
                        end

                        return false
                    end
                }
            }
        }
        return op
    end



    function OperationManager:createINTERCEPTOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.INTERCEPT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 750,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Intercept and destroy 2 enemy aircraft or helicopters",
                    completed = false,
                    kills = 0,
                    required_kills = Config.operations.intercept_required_kills or 2,
                    check = function(self, player_unit)
                        if self.kills >= self.required_kills then
                            return true
                        end
                        return false
                    end,
                    ---@param event table
                    onKill = function(self, event, player_unit, target_zone_name)
                        -- Called by OperationManager when a kill event occurs
                        if not event.initiator or not event.target then return end
                        
                        -- Check if killer is our assigned player
                        if event.initiator:getName() ~= player_unit:getName() then return end
                        
                        -- Check if target is an aircraft or helicopter
                        local target = event.target
                        if not target.hasAttribute then return end
                        if not (target:hasAttribute("Planes") or target:hasAttribute("Helicopters")) then return end
                        
                        -- Check if target is enemy
                        if target:getCoalition() == player_unit:getCoalition() then return end
                        
                        -- Check if kill is within operation radius of target zone
                        local zone = ZoneHandler.getFromName(target_zone_name)
                        if not zone then return end
                        
                        -- Valid kill - increment counter
                        self.kills = self.kills + 1
                        trigger.action.outTextForUnit(player_unit:getID(), 
                            string.format("Intercept - Confirmed kill (%d/%d)", self.kills, self.required_kills), 10)
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createAIRDROPOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.AIRDROP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 1000,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Successfully deliver supply crates (".. (Config.operations.reinforcement_required_supplies or 300) .." supplies) to " .. target_zone.name .. " via air drop.",
                    completed = false,
                    check = function(self, player_unit)
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                            local required_supplies = Config.operations.reinforcement_required_supplies
                            local supplies_per_crate = Config.ctld.supply_crate_supplies
                            local required_crates = math.ceil(required_supplies / math.max(supplies_per_crate, 1))

                            local volume = {
                                id = world.VolumeType.SPHERE,
                                params = {
                                    point = zone.zone.point,
                                    radius = zone.zone.radius
                                }
                            }

                            local supply_crate_objs = {}
                            local supply_crate_names = {}
                            world.searchObjects({Object.Category.CARGO}, volume, function(obj)
                                if obj and obj:isExist() and obj.getVelocity and obj.getName and obj.getTypeName then
                                    -- Only supply crates count toward reinforcement upgrades.
                                    if obj:getTypeName() ~= CargoCrates.SuppliesCrate then
                                        return true
                                    end

                                    local vel = obj:getVelocity()
                                    local speed = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                                    if speed < 1 then
                                        table.insert(supply_crate_objs, obj)
                                        table.insert(supply_crate_names, obj:getName())
                                    end
                                end
                                return true
                            end)

                            if #supply_crate_objs >= required_crates then
                                MissionLogger:info("Airdrop objective completed! Supply crates in zone: "..#supply_crate_objs)

                                -- Consume the required supply crates for the upgrade.
                                for i = 1, required_crates do
                                    local crate_obj = supply_crate_objs[i]
                                    if crate_obj and crate_obj:isExist() then
                                        crate_obj:destroy()
                                    end
                                end

                                if zone.level < 4 then
                                    zone.level = zone.level + 1
                                    UnitHandler.updateZoneUnits(zone)
                                    zone:drawF10()
                                    zone.next_level_up_avail = timer.getTime() + Config.logistics_level_up_interval
                                    trigger.action.outSoundForCoalition(zone.side,"radio_beep.ogg")
                                    trigger.action.outTextForCoalition(zone.side, "SITREP: Successful chute deployment over " .. zone.name .. ". Airdrop supplies have been processed, upgrading the sector to Tier " .. zone.level .. " of the 4-tier standard.",10)

                                else
                                    trigger.action.outTextForUnit(player_unit:getID(), "AIRDROP: "..zone.name.." is already at tier 4/4.",10)
                                end

                                return true
                            end
                        return false
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createREINFORCEMENTOperation(target_zone)
        local manager = self

        ---@type Operation
        local op = {
            type = OperationTypes.REINFORCEMENT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 1000,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = string.format("Load supply crates totaling %d supplies", (Config.operations.reinforcement_required_supplies or 300)),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end

                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.REINFORCEMENT then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op or not owner_op.operation_uid then return false end

                        local required_supplies = (Config.operations and Config.operations.reinforcement_required_supplies) or 300
                        local supplies_per_crate = (Config.ctld and Config.ctld.supply_crate_supplies) or 50
                        local required_crates = math.ceil(required_supplies / math.max(supplies_per_crate, 1))

                        local loaded = ctld.getOperationLoads(owner_op.operation_uid)
                        if (loaded[CargoCrates.SuppliesCrate] or 0) < required_crates then
                            return false
                        end

                        trigger.action.outTextForUnit(player_unit:getID(), "Reinforcement: Supplies loaded. Proceed to target area for delivery.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                },
                {
                    description = string.format("Unload supply crates to %s", target_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end
                        if player_unit:inAir() then return false end

                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.REINFORCEMENT then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op then return false end

                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end

                        if not zone:isPointInsideZone(player_unit:getPoint()) then
                            return false
                        end

                        local required_supplies = (Config.operations and Config.operations.reinforcement_required_supplies) or 300
                        local supplies_per_crate = (Config.ctld and Config.ctld.supply_crate_supplies) or 50
                        local required_crates = math.ceil(required_supplies / math.max(supplies_per_crate, 1))

                        local volume = {
                            id = world.VolumeType.SPHERE,
                            params = {
                                point = zone.zone.point,
                                radius = zone.zone.radius
                            }
                        }

                        local supply_crate_objs = {}
                        world.searchObjects({Object.Category.CARGO}, volume, function(obj)
                            if obj and obj:isExist() and obj.getVelocity and obj.getTypeName then
                                if obj:getTypeName() ~= CargoCrates.SuppliesCrate then
                                    return true
                                end
                                local vel = obj:getVelocity()
                                local speed = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                                if speed < 1 then
                                    table.insert(supply_crate_objs, obj)
                                end
                            end
                            return true
                        end)

                        if #supply_crate_objs < required_crates then
                            return false
                        end

                        -- Consume the required supply crates for the upgrade.
                        for i = 1, required_crates do
                            local crate_obj = supply_crate_objs[i]
                            if crate_obj and crate_obj:isExist() then
                                crate_obj:destroy()
                            end
                        end

                        if zone.level < 4 then
                            zone.level = zone.level + 1
                            UnitHandler.updateZoneUnits(zone)
                            zone:drawF10()
                            zone.next_level_up_avail = timer.getTime() + (Config.logistics_level_up_interval or (16 * 60))
                            trigger.action.outSoundForCoalition(zone.side, "radio_beep.ogg")
                            trigger.action.outTextForCoalition(zone.side,
                                "SITREP: Reinforcement supplies delivered to " .. zone.name .. ". The sector has been upgraded to Tier " .. zone.level .. " of the 4-tier standard.", 10)
                        else
                            trigger.action.outTextForUnit(player_unit:getID(), "REINFORCEMENT: "..zone.name.." is already at tier 4/4.", 10)
                        end

                        return true
                    end
                }
            }
        }
        return op
    end

    ---@param load_zone ZoneHandler
    ---@param target_zone ZoneHandler
    ---@return Operation|nil
    function OperationManager:createSTRATEGICAIRLIFTOperation(load_zone, target_zone)
        local manager = self
        local manifest = self:buildStrategicAirliftManifest()
        if not manifest or #manifest == 0 then return nil end

        local delivery_radius = (Config.operations.strategic_airlift and Config.operations.strategic_airlift.delivery_radius) or 1200
        local hold_duration = (Config.operations.strategic_airlift and Config.operations.strategic_airlift.stage_hold_duration) or 45

        ---@type Operation
        local op = {
            type = OperationTypes.STRATEGIC_AIRLIFT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = (Config.operations.strategic_airlift and Config.operations.strategic_airlift.base_xp) or 1200,
            load_zone_name = load_zone.name,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            delivery_radius = delivery_radius,
            hold_duration = hold_duration,
            strategic_manifest = manifest,
            strategic_manifest_text = self:formatStrategicAirliftManifest(manifest),
            objectives = {
                {
                    description = string.format("Load manifest via CTLD at %s", load_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end
                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op then return false end

                        local load_z = ZoneHandler.getFromName(owner_op.load_zone_name)
                        if not load_z then return false end

                        local loaded = ctld.getOperationLoads(owner_op.operation_uid)
                        for _, req in ipairs(owner_op.strategic_manifest or {}) do
                            if (loaded[req.part_name] or 0) < req.quantity then
                                return false
                            end
                        end

                        trigger.action.outTextForUnit(player_unit:getID(), "Strategic Airlift: Manifest loaded. Proceed to destination for delivery.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                },
                {
                    description = string.format("Unload requested manifest to %s", target_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end
                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op then return false end

                        local delivered = manager:getStrategicAirliftDeliveredCounts(owner_op)
                        for _, req in ipairs(owner_op.strategic_manifest or {}) do
                            if (delivered[req.part_name] or 0) < req.quantity then
                                return false
                            end
                        end

                        trigger.action.outTextForUnit(player_unit:getID(), "Strategic Airlift: Manifest delivery confirmed. Hold position.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                },
                {
                    description = "Hold near destination to finalize delivery handoff",
                    completed = false,
                    start_time = nil,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end
                        local owner_op = nil
                        for _, active_op in ipairs(manager.active_operations) do
                            if active_op.assigned_unit_name == player_unit:getName()
                            and active_op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                owner_op = active_op
                                break
                            end
                        end
                        if not owner_op then return false end

                        local target = ZoneHandler.getFromName(owner_op.target_zone_name)
                        if not target then return false end

                        local dist = mist.utils.get2DDist(player_unit:getPoint(), target.zone.point)
                        if dist > owner_op.delivery_radius then
                            self_obj.start_time = nil
                            return false
                        end

                        if not self_obj.start_time then
                            self_obj.start_time = timer.getTime()
                            return false
                        end

                        return (timer.getTime() - self_obj.start_time) >= (owner_op.hold_duration or 45)
                    end
                }
            }
        }

        return op
    end

    function OperationManager:createSEADOperation(target_zone)
        -- This is a simplified check. A real implementation would need to identify SR/TR units.
        ---@type Operation
        local op = {
            type = OperationTypes.SEAD,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 500,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Clear all SAM SR, SAM TR, IR Guided SAM and/or EWR components of SAM site situated near " .. target_zone.name,
                    completed = false,
                    check = function()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        if #zone.linked_groups == 0 then return true end

                        if UnitHandler.checkIfZoneHasUnitWithAttributes(zone, Config.operations.attributes_for_SEAD_targeting) == false then
                            return true
                        end
                        return false
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createDEADOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.DEAD,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 800,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
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
        elseif strike_type == "FARP" then
            target_desc = "FARP Assets"
            check_func = function()
                local zone = ZoneHandler.getFromName(target_zone.name)
                if not zone then return false end
                return zone.linked_statics and #zone.linked_statics == 0
            end
        else
            target_desc = "Target"
            check_func = function()
                local zone = ZoneHandler.getFromName(target_zone.name)
                if not zone then return false end
                return zone.side == coalition.side.NEUTRAL
            end
        end

        ---@type Operation
        local op = {
            type = OperationTypes.STRIKE,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
            xp_reward = 1000,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
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

    function OperationManager:createRunwayBombingOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.RUNWAY_BOMBING,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
            xp_reward = 1000,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Render any " .. target_zone.name .." runway inoperable",
                    completed = false,
                    check = function()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end
                        return zone:isRunwayDisabled()
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createCAPOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.CAP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 500,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Patrol the airspace above " .. target_zone.name .. " for 5 minutes.",
                    completed = false,
                    start_time = nil,
                    duration = Config.operations.cap_duration,
                    radius = Config.operations.cap_max_radius_from_zone,
                    check = function(self, player_unit)
                        local player_pos = player_unit:getPoint()
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end

                        if not self.start_time then

                            if mist.utils.get2DDist(zone.zone.point,player_pos) <= self.radius then
                                self.start_time = timer.getTime()
                            end

                        else

                            if player_unit.inAir and not player_unit:inAir() then return false end

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

    function OperationManager:createDEEPRECONOperation(target_zone)
      ---@type Operation
        local op = {
            type = OperationTypes.DEEP_RECON,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 1500,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Conduct aerial reconnaissance deep inside enemy territory near given coordinates",
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
                            if mist.utils.get2DDist(zone.zone.point,player_pos) > self.radius then
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon aerial imagery lost, remain near given coordinates",3)
                                self.start_time = nil
                                return false
                            end

                            -- check for line of sight
                            if not land.isVisible(player_pos, target_zone.zone.point) then
                                trigger.action.outTextForUnit(player_unit:getID(),"Recon aerial imagery lost, maintain line of sight to target area", 5)
                                self.start_time = nil
                                return false
                            end

                            if timer.getTime() - self.start_time < self.duration then
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon aerial imagery in progress: "..math.floor(((timer.getTime() - self.start_time)/self.duration)*100).."%", 5)
                                return false
                            end

                            if timer.getTime() - self.start_time >= self.duration then
                                local player_coalition = player_unit:getCoalition()
                                if player_coalition == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                                    table.insert(stats.blue_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.requestMenuRefresh(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon aerial imagery concluded, found targets near "..zone.name,15)
                                elseif player_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                                    table.insert(stats.red_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.requestMenuRefresh(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon aerial imagery concluded, found targets near "..zone.name,15)
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

    function OperationManager:createRECONOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.RECON,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = 750,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
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
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon aerial imagery lost, remain near given coordinates",3)
                                self.start_time = nil
                                return false
                            end

                            -- check for line of sight
                            if not land.isVisible(player_pos, target_zone.zone.point) then
                                trigger.action.outTextForUnit(player_unit:getID(),"Recon aerial imagery lost, maintain line of sight to target area", 5)
                                self.start_time = nil
                                return false
                            end

                            if timer.getTime() - self.start_time < self.duration then
                                trigger.action.outTextForUnit(player_unit:getID(), "Recon aerial imagery in progress: "..math.floor(((timer.getTime() - self.start_time)/self.duration)*100).."%", 5)
                                return false
                            end

                            if timer.getTime() - self.start_time >= self.duration then
                                local player_coalition = player_unit:getCoalition()
                                if player_coalition == coalition.side.BLUE and not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                                    table.insert(stats.blue_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.requestMenuRefresh(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon aerial imagery concluded, found targets near "..zone.name,15)
                                elseif player_coalition == coalition.side.RED and not utils.tableContains(stats.red_discovered_zones,zone.name) then
                                    table.insert(stats.red_discovered_zones,zone.name)

                                    zone:drawF10()
                                    CommandHandler.requestMenuRefresh(player_coalition)
                                    trigger.action.outTextForCoalition(player_coalition, "Recon aerial imagery concluded, found targets near "..zone.name,15)
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
    ---@param show_coop_only boolean|nil -- If true, only show operations that support co-op
    function OperationManager:showAvailableOperations(unit, show_coop_only)
        if not unit or not unit:isExist() or not unit.getPlayerName or not unit.hasAttribute then return end
        self:setCoalitionScopeForUnit(unit)

        self:generateOperations()

        ---@type Operation[]
        local unit_supported_operations = {}
        local unit_type = unit:getTypeName()
        
        -- Filter operations based on distance from home base
        table.sort(self.available_operations, function(a, b)
            local zone_a = ZoneHandler.getFromName(a.target_zone_name)
            local zone_b = ZoneHandler.getFromName(b.target_zone_name)
            if not zone_a or not zone_b then return false end
            local dist_a = mist.utils.get2DDist(self.home_airbase.zone.point, zone_a.zone.point)
            local dist_b = mist.utils.get2DDist(self.home_airbase.zone.point, zone_b.zone.point)
            return dist_a < dist_b
        end)

        -- Filter operations based on aircraft_filter configuration
        for _, op in ipairs(self.available_operations) do
            local is_allowed = true
            
            -- Check if there's a filter for this operation type
            if Config.operations.aircraft_filter and Config.operations.aircraft_filter[op.type] then
                -- Filter exists for this operation type, check if unit type is in the list
                is_allowed = false
                for _, allowed_type in ipairs(Config.operations.aircraft_filter[op.type]) do
                    if unit_type == allowed_type then
                        is_allowed = true
                        break
                    end
                end
            end
            -- If no filter exists for this operation type, all aircraft are allowed (is_allowed remains true)
            
            if is_allowed then
                table.insert(unit_supported_operations, op)
            end
        end
        

        local outtext = "Available Operations"
        if #unit_supported_operations == 0 then
            outtext = "No operations available at this time."
        end
        

        local operation_types_displayed = {}
        local operations_displayed = 0
        for _, op in ipairs(unit_supported_operations) do
            if operations_displayed >= 8 then
                break
            end
            if show_coop_only and not op.is_coop then
                -- Skip non-coop operations if filtering for coop only
            elseif not utils.tableContains(operation_types_displayed, op.type) then
                local tgt_zone = op.target_zone_name
                if op.type == OperationTypes.RECON or op.type == OperationTypes.DEEP_RECON then
                    tgt_zone = "Undiscovered Location"
                elseif op.type == OperationTypes.CSAR then
                    tgt_zone = "Emergency Rescue"
                end

                outtext = outtext .. string.format("\n\n %s - %s", op.type, tgt_zone)

                for _, obj in ipairs(op.objectives) do
                    outtext = outtext .. "\n - " .. obj.description
                end

                outtext = outtext .. "\n Reward: " .. (op.xp_reward or 500) .. " XP"
                outtext = outtext .. "\n Operation code: " .. op.code
                operations_displayed = operations_displayed + 1
                table.insert(operation_types_displayed, op.type)
            end
        end
        local unit_id = unit:getID()
        trigger.action.outTextForUnit(unit_id, outtext, 30)
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
    end

    ---@param unit Unit
    function OperationManager:cancelOperation(unit)
        if not unit then return end
        if not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        for i, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() then
                -- Leader is cancelling - notify all co-op members if applicable
                if active_op.is_coop and active_op.coop_members then
                    for member_id, _ in pairs(active_op.coop_members) do
                        trigger.action.outTextForUnit(member_id, "Operation " .. active_op.operation_name .. " has been cancelled by the leader.", 10)
                        trigger.action.outSoundForUnit(member_id, "chatter3.ogg")
                    end
                end

                if active_op.type == OperationTypes.STRATEGIC_AIRLIFT then
                    self:cancelStrategicAirliftOperation(active_op, true)
                elseif active_op.type == OperationTypes.RECOVER then
                    self:cancelRecoverOperation(active_op, true)
                end
                
                table.remove(self.active_operations, i)
                trigger.action.outSoundForUnit(unit_id,"chatter3.ogg")
                trigger.action.outTextForUnit(unit_id, "Operation " .. active_op.operation_name .. " cancelled.", 10)
                return
            end
            
            -- Check if this player is a co-op member
            if active_op.is_coop and active_op.coop_members and active_op.coop_members[unit_id] then
                self:leaveCoopOperation(unit, active_op)
                return
            end
        end

        trigger.action.outTextForUnit(unit_id, "You have no active operation to cancel.", 10)
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
    end

    ---@param unit Unit
    ---@param join_code number
    function OperationManager:joinCoopOperation(unit, join_code)
        if not unit or not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        -- Check if player already has an active operation
        for _, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit_id or 
               (active_op.coop_members and active_op.coop_members[unit_id]) then
                trigger.action.outTextForUnit(unit_id, "An operation is already active.", 10)
                trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
                return
            end
        end
        
        -- Find the operation with matching join code
        local target_op = nil
        for _, active_op in ipairs(self.active_operations) do
            if active_op.is_coop and active_op.coop_join_code == join_code then
                target_op = active_op
                break
            end
        end
        
        if not target_op then
            trigger.action.outTextForUnit(unit_id, "Invalid CO-OP join code.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Check if operation is still active (not completed/failed)
        if target_op.status ~= OperationStatus.ACTIVE then
            trigger.action.outTextForUnit(unit_id, "Operation is no longer active.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Verify leader still exists
        local leader_unit = Unit.getByName(target_op.assigned_unit_name)
        if not leader_unit or not leader_unit:isExist() then
            trigger.action.outTextForUnit(unit_id, "Operation leader is no longer available.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Check max co-op members
        local current_members = 1 -- leader
        if target_op.coop_members then
            for _ in pairs(target_op.coop_members) do
                current_members = current_members + 1
            end
        end
        
        local max_members = Config.operations.coop_max_members or 4
        if current_members >= max_members then
            trigger.action.outTextForUnit(unit_id, "CO-OP operation is at maximum operating capicity.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Add player to co-op members
        if not target_op.coop_members then
            target_op.coop_members = {}
        end
        target_op.coop_members[unit_id] = unit:getName()
        
        -- Notify all participants
        local join_msg = string.format("%s has joined Operation %s", unit:getPlayerName(), target_op.operation_name)
        trigger.action.outTextForUnit(target_op.assigned_player_id, join_msg, 10)
        for member_id, _ in pairs(target_op.coop_members) do
            trigger.action.outTextForUnit(member_id, join_msg, 10)
            trigger.action.outSoundForUnit(member_id,"radio_txrx.ogg")
        end
        
        trigger.action.outSoundForUnit(unit_id,"chatter1.ogg")
        self:showActiveOperation(unit)
    end
    
    ---@param unit Unit
    ---@param operation Operation|nil
    function OperationManager:leaveCoopOperation(unit, operation)
        if not unit or not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        local target_op = operation
        if not target_op then
            -- Find the operation this player is in
            for _, active_op in ipairs(self.active_operations) do
                if active_op.coop_members and active_op.coop_members[unit_id] then
                    target_op = active_op
                    break
                end
            end
        end
        
        if not target_op or not target_op.coop_members or not target_op.coop_members[unit_id] then
            trigger.action.outTextForUnit(unit_id, "You are not in a CO-OP operation.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Remove player from co-op members
        target_op.coop_members[unit_id] = nil
        
        -- Notify all participants
        local leave_msg = string.format("%s has left Operation %s", unit:getPlayerName(), target_op.operation_name)
        
        -- Notify leader if still exists
        local leader_unit = Unit.getByName(target_op.assigned_unit_name)
        if leader_unit and leader_unit:isExist() then
            trigger.action.outTextForUnit(target_op.assigned_player_id, leave_msg, 10)
        end
        
        -- Notify remaining members
        for member_id, _ in pairs(target_op.coop_members) do
            trigger.action.outTextForUnit(member_id, leave_msg, 10)
            trigger.action.outSoundForUnit(member_id,"radio_txrx.ogg")
        end
        
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
        trigger.action.outTextForUnit(unit_id, "You have left the CO-OP operation.", 10)
    end
    
    ---@param unit Unit
    function OperationManager:showCoopOperationStatus(unit)
        if not unit or not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        -- Find if player is leader or member of a co-op operation
        local player_op = nil
        local is_leader = false
        
        for _, active_op in ipairs(self.active_operations) do
            if active_op.is_coop then
                if active_op.assigned_player_id == unit_id then
                    player_op = active_op
                    is_leader = true
                    break
                elseif active_op.coop_members and active_op.coop_members[unit_id] then
                    player_op = active_op
                    is_leader = false
                    break
                end
            end
        end
        
        if not player_op then
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            trigger.action.outTextForUnit(unit_id, "You are not in a co-op operation.", 10)
            return
        end
        
        local outtext = string.format("CO-OP Operation %s\nType: %s", player_op.operation_name, player_op.type)
        
        if is_leader then
            outtext = outtext .. string.format("\n\nJoin Code: %d", player_op.coop_join_code)
        end
        
        -- List all participants
        outtext = outtext .. string.format("\n\nLeader: %s", player_op.coop_leader_name)
        
        if player_op.coop_members then
            local member_count = 0
            for member_id, member_name in pairs(player_op.coop_members) do
                member_count = member_count + 1
                local member_unit = Unit.getByName(member_name)
                if member_unit and member_unit:isExist() and member_unit.getPlayerName then
                    outtext = outtext .. string.format("\nParticipant %d: %s", member_count, member_unit:getPlayerName())
                end
            end
        end
        
        -- Show bonus info
        local coop_bonus_pct = (Config.reward_system.coop_xp_bonus or 0.25) * 100
        outtext = outtext .. string.format("\n\nCO-OP Bonus: +%d%% XP and Tokens", coop_bonus_pct)
        
        trigger.action.outTextForUnit(unit_id, outtext, 30)
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
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

    ---@param unit Unit
    ---@param code any
    function OperationManager:activateOperation(unit, code)
        if not unit then return end
        if not unit.getPlayerName then return end
        self:setCoalitionScopeForUnit(unit)
        local unit_id = unit:getID()

        -- Check if player already has a mission
        for _, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit_id then
                trigger.action.outTextForUnit(unit_id, "You are already on an operation: " .. active_op.operation_name, 10)
                trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
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
            trigger.action.outTextForUnit(unit_id, "Invalid operation code.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end

        

        -- Check if the target zone was taken by someone else between the time the menu was generated and now.
        -- Skip this check for CSAR operations
        if accepted_mission.type ~= OperationTypes.CSAR and self:isZoneActive(accepted_mission.target_zone_name) then
            trigger.action.outTextForUnit(unit_id, "Operation Aborted: Target zone " .. accepted_mission.target_zone_name .. " is already being engaged by another unit.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")

            table.remove(self.available_operations, mission_index)
            return
        end

        -- Recon operations are only valid on undiscovered enemy zones.
        if accepted_mission.type == OperationTypes.RECON or accepted_mission.type == OperationTypes.DEEP_RECON then
            local is_discovered = false
            if self.side == coalition.side.BLUE then
                is_discovered = utils.tableContains(stats.blue_discovered_zones, accepted_mission.target_zone_name)
            elseif self.side == coalition.side.RED then
                is_discovered = utils.tableContains(stats.red_discovered_zones, accepted_mission.target_zone_name)
            end

            if is_discovered then
                trigger.action.outTextForUnit(unit_id, "Operation Aborted: target is already discovered.", 10)
                trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
                table.remove(self.available_operations, mission_index)
                self:forceRegenerateOperations()
                return
            end
        end

        if accepted_mission.type == OperationTypes.STRATEGIC_AIRLIFT then
            if not ctld or not ctld.getAircraftLimit then
                trigger.action.outTextForUnit(unit_id, "Strategic Airlift unavailable: CTLD is not initialized.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end

            local acft_limit = ctld.getAircraftLimit(unit)
            if not acft_limit then
                trigger.action.outTextForUnit(unit_id, "Strategic Airlift requires a CTLD-supported transport aircraft.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end
        end

        if accepted_mission.type == OperationTypes.REINFORCEMENT then
            if not ctld or not ctld.getAircraftLimit then
                trigger.action.outTextForUnit(unit_id, "Reinforcement unavailable: CTLD is not initialized.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end

            local desc = unit:getDesc()
            if not (desc and desc.category == Unit.Category.HELICOPTER) then
                trigger.action.outTextForUnit(unit_id, "Reinforcement requires a helicopter.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end

            local acft_limit = ctld.getAircraftLimit(unit)
            if not acft_limit then
                trigger.action.outTextForUnit(unit_id, "Reinforcement requires a CTLD-supported helicopter.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end
        end

        if accepted_mission.type == OperationTypes.RECOVER then
            if not ctld or not ctld.getAircraftLimit then
                trigger.action.outTextForUnit(unit_id, "Recover unavailable: CTLD is not initialized.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end

            local desc = unit:getDesc()
            local is_heli = desc and desc.category == Unit.Category.HELICOPTER
            local is_c130 = unit:getTypeName() == "C-130J-30"
            if not is_heli and not is_c130 then
                trigger.action.outTextForUnit(unit_id, "Recover requires C-130 or a helicopter.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end

            local acft_limit = ctld.getAircraftLimit(unit)
            if not acft_limit then
                trigger.action.outTextForUnit(unit_id, "Recover requires a CTLD-supported transport aircraft.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                return
            end
        end

        -- For CSAR operations, handle differently
        local zone_tgt = nil
        if accepted_mission.type == OperationTypes.CSAR then
            -- CSAR doesn't need a zone, it uses pilot_position
            if not accepted_mission.pilot_position then
                trigger.action.outTextForUnit(unit_id, "Error: Pilot position not found.", 10)
                return
            end
        else
            zone_tgt = ZoneHandler.getFromName(accepted_mission.target_zone_name)
        end

        -- Move from available to active
        table.remove(self.available_operations, mission_index)
        accepted_mission.status = OperationStatus.ACTIVE
        accepted_mission.assigned_player_id = unit_id
        accepted_mission.assigned_unit_name = unit:getName()

        if accepted_mission.type == OperationTypes.STRATEGIC_AIRLIFT then
            local load_zone = ZoneHandler.getFromName(accepted_mission.load_zone_name)
            local target_zone = ZoneHandler.getFromName(accepted_mission.target_zone_name)
            if not load_zone or not target_zone then
                trigger.action.outTextForUnit(unit_id, "Strategic Airlift aborted: area unavailable.", 10)
                trigger.action.outSoundForUnit(unit_id, "radio_txrx.ogg")
                accepted_mission.status = OperationStatus.AVAILABLE
                table.insert(self.available_operations, accepted_mission)
                return
            end

            local aircraft_category = nil
            if unit and unit.hasAttribute and unit:hasAttribute("Helicopters") then
                aircraft_category = UserAircraftCategories.HELICOPTER
            else
                aircraft_category = UserAircraftCategories.FIXED_WING
            end

            if not aircraft_category then return end


            accepted_mission.aircraft_category = aircraft_category
            accepted_mission.time_limit_seconds = self:computeStrategicAirliftTimeLimit(load_zone, target_zone, aircraft_category)
            accepted_mission.deadline_time = timer.getTime() + accepted_mission.time_limit_seconds
            accepted_mission.xp_reward = self:computeStrategicAirliftReward(load_zone, target_zone, aircraft_category)
            accepted_mission.operation_uid = string.format("airlift_%d_%d", accepted_mission.code or 0, math.floor(timer.getTime()))

            ctld.setOperationTaskingForUnit(unit, {
                operation_id = accepted_mission.operation_uid,
                operation_type = accepted_mission.type,
                load_zone_name = accepted_mission.load_zone_name,
                target_zone_name = accepted_mission.target_zone_name,
            })
        end

        if accepted_mission.type == OperationTypes.REINFORCEMENT then
            accepted_mission.operation_uid = string.format("reinforce_%d_%d", accepted_mission.code or 0, math.floor(timer.getTime()))
            ctld.setOperationTaskingForUnit(unit, {
                operation_id = accepted_mission.operation_uid,
                operation_type = accepted_mission.type,
                target_zone_name = accepted_mission.target_zone_name,
            })
        end

        if accepted_mission.type == OperationTypes.RECOVER then
            accepted_mission.operation_uid = string.format("recover_%d_%d", accepted_mission.code or 0, math.floor(timer.getTime()))
            accepted_mission.recover_op_tag = string.format("[OPID%d]", accepted_mission.code or 0)
            ctld.setOperationTaskingForUnit(unit, {
                operation_id = accepted_mission.operation_uid,
                operation_type = accepted_mission.type,
                load_zone_name = accepted_mission.load_zone_name,
                target_zone_name = accepted_mission.target_zone_name,
                operation_tag = accepted_mission.recover_op_tag,
            })

            local source_zone = ZoneHandler.getFromName(accepted_mission.load_zone_name)
            if source_zone then
                self:spawnRecoverSourceCrates(accepted_mission, source_zone)
            end
        end
        
        -- Initialize co-op fields if this is a co-op operation
        if accepted_mission.is_coop then
            accepted_mission.coop_leader_id = unit_id
            accepted_mission.coop_leader_name = unit:getName()
            accepted_mission.coop_join_code = self:createOperationCode()
            if not accepted_mission.coop_members then
                accepted_mission.coop_members = {}
            end
        end
        
        table.insert(self.active_operations, accepted_mission)

        local outtxt = string.format("\n%s Operation %s Initiated", accepted_mission.type, accepted_mission.operation_name)

        -- Handle CSAR-specific activation
        if accepted_mission.type == OperationTypes.CSAR then
            -- Spawn smoke at pilot location
            if not accepted_mission.smoke_spawned then
                trigger.action.smoke(accepted_mission.pilot_position, trigger.smokeColor.Blue)
                accepted_mission.smoke_spawned = true
            end
            
            local lat, lon = coord.LOtoLL(accepted_mission.pilot_position)
            local mgrs = coord.LLtoMGRS(lat, lon)
            outtxt = outtxt .. string.format("\n\nDowned pilot location (approximate):\n%s\n%s\nMGRS: %s", 
                mist.tostringLL(lat, lon, 4), mist.tostringLL(lat, lon, 4, true), mist.tostringMGRS(mgrs, 4))
            outtxt = outtxt .. "\n\nGreen smoke has been deployed at the pilot's location."
            outtxt = outtxt .. string.format("\n\nLand within %dm of the pilot to complete the rescue.", Config.operations.csar_rescue_radius or 50)
        else
            if not zone_tgt then
                trigger.action.outTextForUnit(unit_id, "Target zone not found for this operation.", 10)
                return
            end
            local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
            local mgrs = coord.LLtoMGRS(lat, lon)

            if not utils.tableContains({OperationTypes.RECON, OperationTypes.DEEP_RECON, OperationTypes.INTERCEPT}, accepted_mission.type) then
                outtxt = outtxt .. "\n\nArea: " .. accepted_mission.target_zone_name
            end

            if accepted_mission.type ~= OperationTypes.INTERCEPT then
                outtxt = outtxt .. string.format("\n\nApproximate location coordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(lat, lon, 4), mist.tostringLL(lat, lon, 4, true), mist.tostringMGRS(mgrs, 4))
            end

            if accepted_mission.type == OperationTypes.STRATEGIC_AIRLIFT then
                local load_zone = ZoneHandler.getFromName(accepted_mission.load_zone_name)
                local source_text = accepted_mission.load_zone_name or "Unknown"
                local source_coords = ""
                if load_zone and load_zone.zone and load_zone.zone.point then
                    local slat, slon = coord.LOtoLL(load_zone.zone.point)
                    local smgrs = coord.LLtoMGRS(slat, slon)
                    source_coords = string.format("\n\nCoordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(slat, slon, 4), mist.tostringLL(slat, slon, 4, true), mist.tostringMGRS(smgrs, 4))
                end

                outtxt = outtxt .. string.format("\n\nLoad Area: %s", source_text)
                outtxt = outtxt .. source_coords
                outtxt = outtxt .. string.format("\n\nTime limit: %d minutes", math.floor((accepted_mission.time_limit_seconds or 0) / 60))
                outtxt = outtxt .. string.format("\nExpected reward: %d XP", accepted_mission.xp_reward or 0)
                outtxt = outtxt .. "\n\nManifest:\n" .. (accepted_mission.strategic_manifest_text or "- None")
            end

            if accepted_mission.type == OperationTypes.RECOVER then
                local load_zone = ZoneHandler.getFromName(accepted_mission.load_zone_name)
                if load_zone and load_zone.zone and load_zone.zone.point then
                    local slat, slon = coord.LOtoLL(load_zone.zone.point)
                    local smgrs = coord.LLtoMGRS(slat, slon)
                    outtxt = outtxt .. string.format("\n\nSource Area: %s", accepted_mission.load_zone_name or "Unknown")
                    outtxt = outtxt .. string.format("\nCoordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(slat, slon, 4), mist.tostringLL(slat, slon, 4, true), mist.tostringMGRS(smgrs, 4))
                end
                outtxt = outtxt .. string.format("\n\nRecover ID: %s", accepted_mission.recover_op_tag or "[OPID]")
                outtxt = outtxt .. "\nUnload delivered crates and unpack them to convert into supplies."
            end
        end

        -- Add co-op join code if this is a co-op operation
        if accepted_mission.is_coop then
            outtxt = outtxt .. string.format("\n\nCO-OP Join Code: %d", accepted_mission.coop_join_code)
        end
        trigger.action.outTextForUnit(accepted_mission.assigned_player_id, outtxt, 60)

        -- Text for coalition
        trigger.action.outSoundForCoalition(self.side,"chatter1.ogg")
        trigger.action.outTextForCoalition(self.side, accepted_mission.type .. " Operation " .. accepted_mission.operation_name .. " has been initiated.", 15)
        -- Create briefing/markers if needed
    end

    function OperationManager:checkObjectives(player_unit_for_cap)
        for i = #self.active_operations, 1, -1 do
            local op = self.active_operations[i]
            if op then
                local all_objectives_complete = true
                local skip_operation = false

                if op.type == OperationTypes.STRATEGIC_AIRLIFT
                and op.deadline_time
                and timer.getTime() > op.deadline_time then
                    local leader_unit = Unit.getByName(op.assigned_unit_name)
                    if leader_unit and leader_unit:isExist() then
                        trigger.action.outTextForUnit(leader_unit:getID(), "Strategic Airlift failed: mission timer expired.", 12)
                        trigger.action.outSoundForUnit(leader_unit:getID(), "chatter3.ogg")
                    end
                    self:cancelStrategicAirliftOperation(op, true)
                    table.remove(self.active_operations, i)
                    skip_operation = true
                end

                ---@type Unit
                local player_unit = player_unit_for_cap or Unit.getByName(op.assigned_unit_name)

                -- AIRDROP operations can be checked even if player unit doesn't exist
                -- (crates can land after player RTB/ejects/crashes)
                local can_check_objectives = (player_unit and player_unit:isExist()) or op.type == OperationTypes.AIRDROP
                
                if can_check_objectives and not skip_operation then
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
                        -- Collect all active participants at completion time (only those alive and existing)
                        local participants_to_reward = {}
                        
                        -- Add leader if alive
                        if player_unit and player_unit:isExist() and player_unit:isActive() then
                            table.insert(participants_to_reward, player_unit)
                        end
                        
                        -- Add co-op members if alive and existing
                        if op.is_coop and op.coop_members then
                            for _, member_unit_name in pairs(op.coop_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    table.insert(participants_to_reward, member_unit)
                                end
                            end
                        end
                        
                        -- Count actual participants and determine bonus
                        local coop_participant_count = #participants_to_reward
                        
                        -- If no participants are alive, operation fails silently
                        if coop_participant_count == 0 then
                            table.remove(self.active_operations, i)
                            return
                        end
                        
                        -- Mark operation as completed only if we have participants
                        op.status = OperationStatus.COMPLETED
                        
                        local coop_bonus_multiplier = 1.0
                        
                        -- Only apply bonus if 2 or more players are actually participating
                        if coop_participant_count >= 2 then
                            coop_bonus_multiplier = 1.0 + (Config.reward_system.coop_xp_bonus or 0.25)
                        end
                        
                        -- Award XP and tokens to all participants
                        for _, participant_unit in ipairs(participants_to_reward) do
                            local participant_unit_id = participant_unit:getID()
                            trigger.action.outTextForUnit(participant_unit_id, "Operation " .. op.operation_name .. " completed !", 20)
                            trigger.action.outSoundForUnit(participant_unit_id,"chatter2.ogg")
                            
                            local user = ExperienceManager:fetchUser(participant_unit)
                            if user then
                                user.missions_completed = user.missions_completed + 1
                                
                                -- Apply base XP with co-op bonus (only if 2+ players)
                                local base_xp = op.xp_reward or 500
                                local total_xp = math.floor(base_xp * coop_bonus_multiplier)
                                user.unclaimed_xp = user.unclaimed_xp + total_xp

                                local reward_msg = "+" .. total_xp .. " XP"
                                
                                -- Only show bonus message if there were actually 2+ players
                                if coop_participant_count >= 2 then
                                    local bonus_pct = math.floor((coop_bonus_multiplier - 1.0) * 100)
                                    reward_msg = reward_msg .. string.format("\n[+%d%% CO-OP Bonus with %d players]", bonus_pct, coop_participant_count)
                                end
                                
                                reward_msg = reward_msg .. "\nReturn to base to claim your rewards."
                                
                                trigger.action.outTextForUnit(participant_unit_id, reward_msg, 10)
                            end
                        end

                        -- For CSAR operations, remove the rescued pilot from the downed_pilots list
                        if op.type == OperationTypes.CSAR and op.pilot_position then
                            for j = #self.downed_pilots, 1, -1 do
                                local pilot_pos = self.downed_pilots[j]
                                -- Check if this is the same pilot (within 1 meter tolerance)
                                if pilot_pos and mist.utils.get3DDist(pilot_pos, op.pilot_position) < 1 then
                                    table.remove(self.downed_pilots, j)
                                    MissionLogger:info("Removed rescued pilot from downed_pilots list")
                                    break
                                end
                            end
                        end

                        if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                            local op_uid = op.operation_uid
                            self:cancelStrategicAirliftOperation(op, false)
                            timer.scheduleFunction(function()
                                if op_uid then
                                    ctld.clearOperationAssets(op_uid)
                                end
                            end, {}, timer.getTime() + Config.operations.strategic_airlift.cleanup_delay)
                        elseif op.type == OperationTypes.RECOVER then
                            -- Keep delivered crates available so players can unpack them manually.
                            self:cancelRecoverOperation(op, false)
                        end

                        table.remove(self.active_operations, i)
                    end
                end
            end
        end
    end

    function OperationManager:tick()
        self:setCoalitionScope(coalition.side.BLUE)
        self:checkObjectives()
        self:setCoalitionScope(coalition.side.RED)
        self:checkObjectives()
    end
    
    -- Force regeneration of operations (call when zones change ownership)
    function OperationManager:forceRegenerateOperations()
        self.blue_last_generation_time = 0
        self.red_last_generation_time = 0
        self.last_generation_time = 0
        self:setCoalitionScope(coalition.side.BLUE)
        self:generateOperations()
        self:setCoalitionScope(coalition.side.RED)
        self:generateOperations()
    end
end