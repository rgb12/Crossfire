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
---@field is_joint_op boolean -- Whether this operation supports joint operations
---@field joint_op_leader_id number | nil -- Unit ID of the player who created the operation
---@field joint_op_leader_name string | nil -- Name of the unit who created the operation
---@field joint_op_members table<number, string> -- Map of unit IDs to unit names
---@field joint_op_join_code number | nil -- Code for other players to join this joint operation
---@field pilot_position vec3 | nil -- For CSAR operations: position of downed pilot
---@field smoke_spawned boolean | nil -- For CSAR operations: whether smoke has been spawned
---@field load_zone_name string | nil -- For Strategic Airlift operations
---@field strategic_manifest table[] | nil -- Requested CTLD parts for Strategic Airlift
---@field strategic_manifest_text string | nil -- Human-readable manifest
---@field aircraft_category string | nil -- helicopter|fixed_wing selected at activation
---@field time_limit_seconds number | nil -- Mission timer for Strategic Airlift
---@field deadline_time number | nil -- Absolute mission deadline for Strategic Airlift
---@field operation_id string | nil -- Runtime unique id for temporary asset tracking

---@class OperationManager
---@field side coalition.side
---@field home_airbase ZoneHandler
---@field last_generation_time number
---@field generation_cooldown number seconds>0
---@field downed_pilots vec3[]
---@field available_operations Operation[]
---@field active_operations Operation[]
OperationManager = {}
do

    OperationManager.instances = {}

    OperationManager.EventHandler = {}

   ---@param event table
    function OperationManager.EventHandler:onEvent(event)
        if not OperationManager.instances then return end
        for _, instance in ipairs(OperationManager.instances) do
            instance:onEvent(event)
        end
    end


    function OperationManager:new(side, home_airbase)
        self.__index = self
        local obj = {
            side = side,
            home_airbase = home_airbase,
            downed_pilots = {},
            available_operations = {},
            active_operations = {},
            last_generation_time = 0, -- Cache timestamp
            generation_cooldown = Config.operations.operation_refresh_time or 30, -- seconds
        }
        setmetatable(obj, self)
        table.insert(OperationManager.instances, obj)
        world.addEventHandler(OperationManager.EventHandler)
        return obj
    end


    ---@param unit Unit
    function OperationManager:showActiveOperation(unit)
        if not unit or not unit.getPlayerName then return end
        local unit_id = unit:getID()

        local active_mission = nil
        for _, op in ipairs(self.active_operations) do
            -- Check if player is the leader
            if op.assigned_player_id == unit:getID() then
                active_mission = op
                break
            end
            -- Check if player is a joint operation member
            if op.is_joint_op and op.joint_op_members and op.joint_op_members[unit:getID()] then
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
        if event.id == world.event.S_EVENT_DEAD or event.id == world.event.S_EVENT_CRASH or event.id == world.event.S_EVENT_PILOT_DEAD then
            if event.initiator and event.initiator.getPlayerName then
                local dead_unit_name = event.initiator.unit_name or event.initiator:getName()
                local dead_unit_id = event.initiator:getID()

                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    
                    -- Check if dead player is the leader
                    if op.assigned_unit_name == dead_unit_name then
                        -- If joint operation and there are members, transfer leadership to first active member
                        if op.is_joint_op and op.joint_op_members then
                            local new_leader_found = false
                            for member_id, member_unit_name in pairs(op.joint_op_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    -- Transfer leadership
                                    op.assigned_player_id = member_id
                                    op.assigned_unit_name = member_unit_name
                                    op.joint_op_leader_id = member_id
                                    op.joint_op_leader_name = member_unit_name

                                    -- Remove from members list
                                    op.joint_op_members[member_id] = nil
                                    
                                    -- Notify remaining participants
                                    trigger.action.outTextForUnit(member_id, "You are now the operation leader!", 10)
                                    trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")

                                    for remaining_id, _ in pairs(op.joint_op_members) do
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
                                end
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, "SITREP: " .. op.operation_name .. " operation failed!.", 15)
                            if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                self:cancelStrategicAirliftOperation(op, true)
                            end
                            table.remove(self.active_operations, i)
                        end
                    else
                        -- Check if dead player is a joint op member
                        if op.is_joint_op and op.joint_op_members and op.joint_op_members[dead_unit_id] then
                            op.joint_op_members[dead_unit_id] = nil

                            -- Notify remaining participants
                            local leader_unit = Unit.getByName(op.assigned_unit_name)
                            if leader_unit and leader_unit:isExist() then
                                trigger.action.outTextForUnit(op.assigned_player_id, "A joint operation member has been lost.", 10)
                                trigger.action.outSoundForUnit(op.assigned_player_id, "radio_txrx.ogg")

                            end
                            for member_id, _ in pairs(op.joint_op_members) do
                                trigger.action.outTextForUnit(member_id, "A joint operation member has been lost.", 10)
                                trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")

                            end
                        end
                    end
                end
            end
        elseif event.id == world.event.S_EVENT_KILL then
            -- Handle kill events for INTERCEPT operations
            if event.initiator and event.target and event.initiator.getName then
                for _, op in ipairs(self.active_operations) do
                    if op.type == OperationTypes.INTERCEPT and op.is_joint_op then
                        -- Check if killer is the leader or any joint operation_type member
                        local killer_unit_name = event.initiator:getName()
                        local is_participant = false
                        
                        if killer_unit_name == op.assigned_unit_name then
                            is_participant = true
                        elseif op.joint_op_members then
                            for _, member_unit_name in pairs(op.joint_op_members) do
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
                        -- Non joint op intercept - original behavior
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
        elseif event.id == world.event.S_EVENT_SHOT and event.weapon then
            if not event.weapon.getDesc then return end
            local weapon_desc = event.weapon:getDesc()
            if not weapon_desc or not weapon_desc.category then return end

            local is_bomb_or_rocket = weapon_desc.category == Weapon.Category.BOMB
                                       --or weapon_desc.category == Weapon.Category.ROCKET)
            if not is_bomb_or_rocket then return end

            local release_point = event.weapon:getPoint()
            if not release_point then return end

            local lock_duration = Config.operations.runway_destroyed_duration or 3600
            for _, zone in ipairs(zones) do
                if zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name and not zone:isRunwayDisabled() then
                    local airbase = Airbase.getByName(zone.airbase_name)
                    if airbase and airbase.getRunways then
                        local runways = airbase:getRunways()
                        if runways then
                            for _, runway in pairs(runways) do
                                if runway.position and runway.course and runway.length and runway.width then
                                    local dx = release_point.x - runway.position.x
                                    local dz = release_point.z - runway.position.z
                                    local course = runway.course
                                    if course > (2 * math.pi) then
                                        course = math.rad(course)
                                    end
                                    local cos_course = math.cos(course)
                                    local sin_course = math.sin(course)

                                    local local_x = dx * sin_course + dz * cos_course
                                    local local_z = dx * cos_course - dz * sin_course

                                    if math.abs(local_x) <= ((runway.width / 2) + 150)
                                    and math.abs(local_z) <= ((runway.length / 2) + 150) then
                                        MissionLogger:info("Inside")
                                        zone:markRunwayDisabled(lock_duration)
                                        zone:drawF10()

                                        trigger.action.outTextForCoalition(zone.side, "Sector ALERT: RUNWAY at " .. zone.name .. " is inoperative !", 15)
                                        trigger.action.outSoundForCoalition(zone.side, "alert1.ogg")

                                        local attacker_side = nil
                                        if event.initiator and event.initiator.getCoalition then
                                            attacker_side = event.initiator:getCoalition()
                                        end
                                        if attacker_side and attacker_side ~= zone.side then
                                            trigger.action.outTextForCoalition(attacker_side, "SITREP: RUNWAY strike successful at " .. zone.name, 12)
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
            if event.initiator and event.initiator.getName then
                local unit_name = event.initiator:getName()
                local unit_id = event.initiator:getID()
                
                for i = #self.active_operations, 1, -1 do
                    local op = self.active_operations[i]
                    
                    -- Check if leaving player is the leader
                    if op.assigned_unit_name == unit_name then
                        -- If joint operation and there are members, transfer leadership
                        if op.is_joint_op and op.joint_op_members then
                            local new_leader_found = false
                            for member_id, member_unit_name in pairs(op.joint_op_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    -- Transfer leadership
                                    op.assigned_player_id = member_id
                                    op.assigned_unit_name = member_unit_name
                                    op.joint_op_leader_id = member_id
                                    op.joint_op_leader_name = member_unit_name

                                    -- Remove from members list
                                    op.joint_op_members[member_id] = nil
                                    
                                    -- Notify remaining participants
                                    trigger.action.outTextForUnit(member_id, "You are now the operation leader!", 10)
                                    trigger.action.outSoundForUnit(member_id, "radio_txrx.ogg")
                                    for remaining_id, _ in pairs(op.joint_op_members) do
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
                                end
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, op.type .. " " .. op.operation_name .. " operation failed, operative left.", 15)
                            if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                self:cancelStrategicAirliftOperation(op, true)
                            end
                            table.remove(self.active_operations, i)
                        end
                    else
                        -- Check if leaving player is a joint operation member
                        if op.is_joint_op and op.joint_op_members and op.joint_op_members[unit_id] then
                            op.joint_op_members[unit_id] = nil

                            -- Notify remaining participants
                            local leader_unit = Unit.getByName(op.assigned_unit_name)
                            if leader_unit and leader_unit:isExist() then
                                trigger.action.outTextForUnit(op.assigned_player_id, "A joint operation member has left the operation.", 10)
                                trigger.action.outSoundForUnit(op.assigned_player_id, "radio_txrx.ogg")
                            end
                            for member_id, _ in pairs(op.joint_op_members) do
                                trigger.action.outTextForUnit(member_id, "A joint operation member has left the operation.", 10)
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
        -- Allow first generation (last_generation_time == 0) or if cooldown has elapsed
        if self.last_generation_time > 0 and (current_time - self.last_generation_time < self.generation_cooldown) then
            return -- Use cached operations
        end
        MissionLogger:info("Regenerating operations")
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

                -- AIRDROP or REINFORCEMENT over friendly zones (mutually exclusive)
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] and zone.level < 4 then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist  then
                        if math.random(0,100) > 50 and dist < Config.operations.max_distance_to_frontline_for_airdrops then
                            local op = self:createAIRDROPOperation(zone)
                            table.insert(self.available_operations, op)
                        elseif dist < Config.operations.reinforcement_max_range then
                            local op = self:createREINFORCEMENTOperation(zone)
                            table.insert(self.available_operations, op)
                        end
                    end
                end

                
                -- STRATEGIC AIRLIFT from any friendly zone to friendly airbase/FARP destinations
                if Config.operations.strategic_airlift.enabled
                and zone.side == friendly_coalition
                and discovered_zones_set[zone.name] then
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
        local cfg = Config.operations.strategic_airlift or {}
        local dist_m = mist.utils.get2DDist(load_zone.zone.point, target_zone.zone.point)
        local sec_per_km = cfg.seconds_per_km or 65
        local raw = math.floor((dist_m / 1000) * sec_per_km)
        local min_time = cfg.min_time or 0
        local max_time = cfg.max_time or raw
        return math.max(min_time, math.min(raw, max_time))
    end

    ---@param load_zone ZoneHandler
    ---@param target_zone ZoneHandler
    ---@param aircraft_category UserAircraftCategories
    ---@return number
    function OperationManager:computeStrategicAirliftReward(load_zone, target_zone, aircraft_category)
        local base_xp = Config.operations.strategic_airlift.base_xp or 1200
        local xp_per_km = Config.operations.strategic_airlift.xp_per_km or 2
        local dist_m = mist.utils.get2DDist(load_zone.zone.point, target_zone.zone.point)
        local reward = (base_xp + math.floor((dist_m / 1000) * xp_per_km))
        return math.floor(reward)
    end

    ---@param zone ZoneHandler|nil
    ---@return boolean
    function OperationManager:isStrategicAirliftTargetZone(zone)
        if not zone then return false end
        return zone.zone_type == ZoneTypes.AIRBASE or zone.zone_type == ZoneTypes.FARP
    end

    ---@param load_zone ZoneHandler
    ---@param friendly_coalition coalition.side
    ---@param discovered_set table<string, boolean>
    ---@return ZoneHandler|nil
    function OperationManager:findStrategicAirliftTargetZone(load_zone, friendly_coalition, discovered_set)
        local candidates = {}
        for _, zone in ipairs(zones) do
            if zone.name ~= load_zone.name
            and zone.side == friendly_coalition
            and self:isStrategicAirliftTargetZone(zone)
            and discovered_set[zone.name] then
                local dist = mist.utils.get2DDist(load_zone.zone.point, zone.zone.point)
                if dist >= Config.operations.strategic_airlift.min_route_distance and dist <= Config.operations.strategic_airlift.max_route_distance then
                    table.insert(candidates, { zone = zone, dist = dist })
                end
            end
        end

        if #candidates == 0 then return nil end

        table.sort(candidates, function(a, b) return a.dist < b.dist end)
        local pick_idx = math.random(1, #candidates)
        return candidates[pick_idx].zone
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
                if part.weight and part.weight > 2000 then
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

    ---@class Manifest
    ---@field part_name string
    ---@field part_desc string
    ---@field part_type AssetTypes
    ---@field quantity number

    ---@return Manifest[]
    function OperationManager:buildStrategicAirliftManifest()
        local total_items = math.random(Config.operations.strategic_airlift.min_manifest_items, Config.operations.strategic_airlift.max_manifest_items)

        local eligible = self:getStrategicAirliftEligibleParts()
        local troops = self:filterPartsByType(eligible, ctld.AssetTypes.TROOPS)
        local crates = self:filterPartsByType(eligible, ctld.AssetTypes.CARGO_CRATES)
        local vehicles = self:filterPartsByType(eligible, ctld.AssetTypes.VEHICLES)

        local troops_weight = Config.operations.strategic_airlift.category_weights.troops
        local crates_weight = Config.operations.strategic_airlift.category_weights.crates
        local vehicles_weight = Config.operations.strategic_airlift.category_weights.vehicles

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

        ---@type Manifest[]
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

    ---@param operation Operation|nil
    ---@param zone ZoneHandler|nil
    ---@return boolean, table<string, number>, table<string, Object[]>
    function OperationManager:isStrategicAirliftManifestBoardedInZone(operation, zone)
        local delivered = {}
        local delivered_objects = {}
        if not operation or not zone then return false, delivered, delivered_objects end

        local required = {}
        for _, req in ipairs(operation.strategic_manifest or {}) do
            required[req.part_name] = req.quantity or 0
        end
        local objects_in_zone = UnitHandler.findObjectsInZone(zone)
        for _, obj in pairs(objects_in_zone) do
            if obj and obj:isExist() then
                local asset_name = obj:getName()
                local part_name = asset_name and ctld.getPackedPartName(asset_name) or nil
                if part_name and required[part_name] then
                    local point = obj:getPoint()
                    if point then
                        local ground_y = land.getHeight({ x = point.x, y = point.z })
                        if point.y > (ground_y + Config.operations.strategic_airlift.boarded_object_height_agl) then
                            delivered[part_name] = (delivered[part_name] or 0) + 1
                            delivered_objects[part_name] = delivered_objects[part_name] or {}
                            table.insert(delivered_objects[part_name], obj)
                        end
                    end
                end
            end
        end
        for _, req in ipairs(operation.strategic_manifest or {}) do
            if (delivered[req.part_name] or 0) < (req.quantity or 0) then
                return false, delivered, delivered_objects
            end
        end

        return true, delivered, delivered_objects
    end

    ---@param operation Operation
    ---@param cleanup_assets boolean
    function OperationManager:cancelStrategicAirliftOperation(operation, cleanup_assets)
        if not operation then return end

        if operation.operation_id then
            ctld.clearOperationLoads(operation.operation_id)
            ctld.clearOperationContextForOperation(operation.operation_id)
            if cleanup_assets then
                ctld.clearOperationAssets(operation.operation_id)
            end
        end
    end

    function OperationManager:createCASOperation(target_zone)
        ---@type Operation
        local op = {
            type = OperationTypes.CAS,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            xp_reward = math.random(10,13)*100,
            is_joint_op = true,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            xp_reward = math.random(12,18)*100,
            target_zone_name = "CSAR Location", -- Special identifier for CSAR
            operation_name = operations_name[math.random(#operations_name)],
            pilot_position = pilot_pos, -- Store the actual position
            smoke_spawned = false, -- Track if smoke has been spawned
            is_joint_op = false, -- CSAR is typically solo but can be changed
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            xp_reward = math.random(9,12)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = true,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
        local required_supplies = Config.operations.upgrade_required_supplies
        local supplies_per_crate = Config.ctld.supply_crate_supplies
        local required_crates = math.ceil(required_supplies / math.max(supplies_per_crate, 1))
        ---@type Operation
        local op = {
            type = OperationTypes.AIRDROP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = math.random(9,12)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
            objectives = {
                {
                    description = "Successfully deliver supply crates (x"..required_crates..") to " .. target_zone.name .. " via air drop.",
                    completed = false,
                    check = function(self, player_unit)
                        local zone = ZoneHandler.getFromName(target_zone.name)
                        if not zone then return false end

                            local volume = {
                                id = world.VolumeType.SPHERE,
                                params = {
                                    point = zone.zone.point,
                                    radius = zone.zone.radius
                                }
                            }

                            local supply_crate_objs = {}
                            world.searchObjects({Object.Category.CARGO}, volume, function(obj)
                                if obj and obj:isExist() and obj.getVelocity and obj.getName and obj.getTypeName then
                                    -- Only supply crates count toward reinforcement upgrades.
                                    if ctld.isSupplyCrate(obj:getName()) then
                                        local vel = obj:getVelocity()
                                        local speed = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                                        if speed < 1 then
                                            table.insert(supply_crate_objs, obj)
                                        end
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
                                    trigger.action.outTextForCoalition(zone.side, "SITREP: Successful chute deployment over " .. zone.name .. ". Airdrop supplies have been processed, upgrading the sector to operational tier " .. zone.level .. " / 4",10)
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

    ---@param target_zone ZoneHandler
    function OperationManager:createREINFORCEMENTOperation(target_zone)
        local required_supplies = Config.operations.upgrade_required_supplies
        local supplies_per_crate = Config.ctld.supply_crate_supplies
        local required_crates = math.ceil(required_supplies / math.max(supplies_per_crate, 1))

        ---@type Operation
        local op = {
            type = OperationTypes.REINFORCEMENT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = math.random(8,11)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
            objectives = {
                {
                    description = "Unload x"..required_crates.. " supply crates at "..target_zone.name,
                    completed = false,
                    check = function(self_obj, player_unit)
                        if not player_unit or not player_unit:isExist() then return false end
                        if player_unit:inAir() then return false end

                        if not target_zone:isPointInsideZone(player_unit:getPoint()) then return false end

                        local objects = UnitHandler.findObjectsInZone(target_zone)
                        if #objects == 0 then return false end
                        ---@type Object[]
                        local supply_crates_in_zone = {}
                        for _,obj in pairs(objects) do
                            MissionLogger:info(obj:getName())
                            MissionLogger:info(ctld.isSupplyCrate(obj:getName()))
                            if obj:isExist() and ctld.isSupplyCrate(obj:getName()) then

                                local vel = obj:getVelocity()
                                local speed = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                                local point = obj:getPoint()

                                local speed_ok = speed < 1

                                MissionLogger:info(speed_ok)
                                if speed_ok then
                                    table.insert(supply_crates_in_zone,obj)
                                end

                            end
                        end

                        if #supply_crates_in_zone < required_crates then
                            return false
                        end

                        -- Consume the required supply crates for the upgrade.
                        for i = 1, required_crates do
                            local crate_obj = supply_crates_in_zone[i]
                            if crate_obj and crate_obj:isExist() then
                                crate_obj:destroy()
                            end
                        end

                        if target_zone.level < 4 then
                            target_zone.level = target_zone.level + 1
                            UnitHandler.updateZoneUnits(target_zone)
                            target_zone:drawF10()
                            target_zone.next_level_up_avail = timer.getTime() + Config.logistics_level_up_interval
                            trigger.action.outTextForCoalition(target_zone.side,"SITREP: " .. target_zone.name .. " has reached operational tier " .. target_zone.level.." / 4", 10)
                            trigger.action.outSoundForCoalition(target_zone.side, "radio_beep.ogg")
                        else
                            trigger.action.outTextForUnit(player_unit:getID(), "REINFORCEMENT: "..target_zone.name.." is already at tier 4/4.", 10)
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
        local manifest = self:buildStrategicAirliftManifest()
        if not manifest or #manifest == 0 then return nil end

        local hold_duration = Config.operations.strategic_airlift.stage_hold_duration

        ---@type Operation
        local op = {
            type = OperationTypes.STRATEGIC_AIRLIFT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            xp_reward = Config.operations.strategic_airlift.base_xp,
            load_zone_name = load_zone.name,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
            strategic_manifest = manifest,
            strategic_manifest_text = self:formatStrategicAirliftManifest(manifest),
            objectives = {
                {
                    description = string.format('Load manifest via CTLD at %s', load_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit,active_user_operation)
                        if not player_unit or not player_unit:isExist() then return false end
                        if player_unit:inAir() then return false end
                        if mist.vec.mag(player_unit:getVelocity()) > 1 then return false end

                        if not active_user_operation then return false end
                        local load_zone_op = ZoneHandler.getFromName(active_user_operation.load_zone_name)
                        if not load_zone_op then return false end

                        if not load_zone_op:isPointInsideZone(player_unit:getPoint()) then return false end

                        local is_manifest_boarded = self:isStrategicAirliftManifestBoardedInZone(active_user_operation, load_zone_op)
                        if not is_manifest_boarded then return false end

                        trigger.action.outTextForUnit(player_unit:getID(), "Manifest loaded. Proceed to target area for unloading.", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")
                        return true
                    end
                },
                {
                    description = "Hold position on the ground, at the unloading area.",
                    completed = false,
                    start_time = nil,
                    check = function(self_obj, player_unit,active_user_operation)
                        if not player_unit or not player_unit:isExist() then
                            self_obj.start_time = nil
                            return false
                        end
                        if player_unit:inAir() then
                            self_obj.start_time = nil
                            return false
                        end
                        if mist.vec.mag(player_unit:getVelocity()) > 1 then
                            self_obj.start_time = nil
                            return false
                        end
                        if not active_user_operation then
                            self_obj.start_time = nil
                            return false
                        end

                        local zone = ZoneHandler.getFromName(active_user_operation.target_zone_name)
                        if not zone then
                            self_obj.start_time = nil
                            return false
                        end

                        if not zone:isPointInsideZone(player_unit:getPoint()) then
                            self_obj.start_time = nil
                            return false
                        end

                
                        if not self_obj.start_time then
                            self_obj.start_time = timer.getTime()
                            return false
                        end

                        return (timer.getTime() - self_obj.start_time) >= (hold_duration or 45)
                    end
                },
                {
                    description = string.format("Hold position on the ground at %s until the cargo is extracted.", target_zone.name),
                    completed = false,
                    check = function(self_obj, player_unit,user_operation)
                        if not player_unit or not player_unit:isExist() then return false end
                        if player_unit:inAir() then return false end

                        if mist.vec.mag(player_unit:getVelocity()) > 1 then return false end

                        if not user_operation then return false end

                        local unload_zone = ZoneHandler.getFromName(user_operation.target_zone_name)
                        if not unload_zone then return false end
                        if not unload_zone:isPointInsideZone(player_unit:getPoint()) then return false end

                        local is_manifest_boarded, _, delivered_objects = self:isStrategicAirliftManifestBoardedInZone(user_operation, unload_zone)
                        if not is_manifest_boarded then return false end

                        trigger.action.outTextForUnit(player_unit:getID(), "Strategic Airlift: Hold position. Ground crews are extracting the cargo...", 10)
                        trigger.action.outSoundForUnit(player_unit:getID(), "radio_txrx.ogg")

                        return true
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
            xp_reward = math.random(11,14)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = true,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            xp_reward = math.random(12,15)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = true,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            is_joint_op = true,
            xp_reward = math.random(12,16)*100,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            is_joint_op = true,
            xp_reward = math.random(18,22)*100,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
            objectives = {
                {
                    description = "Release bombs or rockets above any " .. target_zone.name .. " runway to render it inoperable",
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
            xp_reward = math.random(5,7)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            xp_reward = math.random(15,18)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
            xp_reward = math.random(7,9)*100,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_joint_op = false,
            joint_op_leader_id = nil,
            joint_op_leader_name = nil,
            joint_op_members = {},
            joint_op_join_code = nil,
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
    ---@param show_joint_op_only boolean|nil -- If true, only show operations that support joint operations
    function OperationManager:showAvailableOperations(unit, show_joint_op_only)
        if not unit or not unit:isExist() or not unit.getPlayerName or not unit.hasAttribute then return end

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
            if show_joint_op_only and not op.is_joint_op then
                -- Skip non-joint operations if filtering for joint ops only
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
        local unit_id = unit:getID()

        for i, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() then
                -- Leader is cancelling - notify all joint op members if applicable
                if active_op.is_joint_op and active_op.joint_op_members then
                    for member_id, _ in pairs(active_op.joint_op_members) do
                        trigger.action.outTextForUnit(member_id, "Operation " .. active_op.operation_name .. " has been cancelled by the leader.", 10)
                        trigger.action.outSoundForUnit(member_id, "chatter3.ogg")
                    end
                end

                if active_op.type == OperationTypes.STRATEGIC_AIRLIFT then
                    self:cancelStrategicAirliftOperation(active_op, true)
                elseif active_op.operation_id then
                    ctld.clearOperationContextForOperation(active_op.operation_id)
                end
                
                table.remove(self.active_operations, i)
                trigger.action.outSoundForUnit(unit_id,"chatter3.ogg")
                trigger.action.outTextForUnit(unit_id, "Operation " .. active_op.operation_name .. " cancelled.", 10)
                return
            end
            
            -- Check if this player is a joint op member
            if active_op.is_joint_op and active_op.joint_op_members and active_op.joint_op_members[unit_id] then
                self:leaveJointOperation(unit, active_op)
                return
            end
        end

        trigger.action.outTextForUnit(unit_id, "You have no active operation to cancel.", 10)
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
    end

    ---@param unit Unit
    ---@param join_code number
    function OperationManager:joinJointOperation(unit, join_code)
        if not unit or not unit.getPlayerName then return end
        local unit_id = unit:getID()

        -- Check if player already has an active operation
        for _, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit_id or 
               (active_op.joint_op_members and active_op.joint_op_members[unit_id]) then
                trigger.action.outTextForUnit(unit_id, "An operation is already active.", 10)
                trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
                return
            end
        end
        
        -- Find the operation with matching join code
        local target_op = nil
        for _, active_op in ipairs(self.active_operations) do
            if active_op.is_joint_op and active_op.joint_op_join_code == join_code then
                target_op = active_op
                break
            end
        end
        
        if not target_op then
            trigger.action.outTextForUnit(unit_id, "Invalid joint operation join code.", 10)
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
        
        -- Check max joint operation members
        local current_members = 1 -- leader
        if target_op.joint_op_members then
            for _ in pairs(target_op.joint_op_members) do
                current_members = current_members + 1
            end
        end
        
        local max_members = Config.operations.joint_op_max_members or 4
        if current_members >= max_members then
            trigger.action.outTextForUnit(unit_id, "Joint operation is at maximum operating capacity.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Add player to joint operation members
        if not target_op.joint_op_members then
            target_op.joint_op_members = {}
        end
        target_op.joint_op_members[unit_id] = unit:getName()
        
        -- Notify all participants
        local join_msg = string.format("%s has joined Operation %s", unit:getPlayerName(), target_op.operation_name)
        trigger.action.outTextForUnit(target_op.assigned_player_id, join_msg, 10)
        for member_id, _ in pairs(target_op.joint_op_members) do
            trigger.action.outTextForUnit(member_id, join_msg, 10)
            trigger.action.outSoundForUnit(member_id,"radio_txrx.ogg")
        end
        
        trigger.action.outSoundForUnit(unit_id,"chatter1.ogg")
        self:showActiveOperation(unit)
    end
    
    ---@param unit Unit
    ---@param operation Operation|nil
    function OperationManager:leaveJointOperation(unit, operation)
        if not unit or not unit.getPlayerName then return end
        local unit_id = unit:getID()

        local target_op = operation
        if not target_op then
            -- Find the operation this player is in
            for _, active_op in ipairs(self.active_operations) do
                if active_op.joint_op_members and active_op.joint_op_members[unit_id] then
                    target_op = active_op
                    break
                end
            end
        end
        
        if not target_op or not target_op.joint_op_members or not target_op.joint_op_members[unit_id] then
            trigger.action.outTextForUnit(unit_id, "You are not in a joint operation.", 10)
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            return
        end
        
        -- Remove player from joint operation members
        target_op.joint_op_members[unit_id] = nil
        
        -- Notify all participants
        local leave_msg = string.format("%s has left Operation %s", unit:getPlayerName(), target_op.operation_name)
        
        -- Notify leader if still exists
        local leader_unit = Unit.getByName(target_op.assigned_unit_name)
        if leader_unit and leader_unit:isExist() then
            trigger.action.outTextForUnit(target_op.assigned_player_id, leave_msg, 10)
        end
        
        -- Notify remaining members
        for member_id, _ in pairs(target_op.joint_op_members) do
            trigger.action.outTextForUnit(member_id, leave_msg, 10)
            trigger.action.outSoundForUnit(member_id,"radio_txrx.ogg")
        end
        
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
        trigger.action.outTextForUnit(unit_id, "You have left the joint operation.", 10)
    end
    
    ---@param unit Unit
    function OperationManager:showJointOperationStatus(unit)
        if not unit or not unit.getPlayerName then return end
        local unit_id = unit:getID()

        -- Find if player is leader or member of a joint operation
        local player_op = nil
        local is_leader = false
        
        for _, active_op in ipairs(self.active_operations) do
            if active_op.is_joint_op then
                if active_op.assigned_player_id == unit_id then
                    player_op = active_op
                    is_leader = true
                    break
                elseif active_op.joint_op_members and active_op.joint_op_members[unit_id] then
                    player_op = active_op
                    is_leader = false
                    break
                end
            end
        end
        
        if not player_op then
            trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
            trigger.action.outTextForUnit(unit_id, "You are not in a joint operation.", 10)
            return
        end
        
        local outtext = string.format("Joint Operation %s\nType: %s", player_op.operation_name, player_op.type)
        
        if is_leader then
            outtext = outtext .. string.format("\n\nJoin Code: %d", player_op.joint_op_join_code)
        end
        
        -- List all participants
        outtext = outtext .. string.format("\n\nLeader: %s", player_op.joint_op_leader_name)
        
        if player_op.joint_op_members then
            local member_count = 0
            for member_id, member_name in pairs(player_op.joint_op_members) do
                member_count = member_count + 1
                local member_unit = Unit.getByName(member_name)
                if member_unit and member_unit:isExist() and member_unit.getPlayerName then
                    outtext = outtext .. string.format("\nParticipant %d: %s", member_count, member_unit:getPlayerName())
                end
            end
        end
        
        -- Show bonus info
        local joint_op_bonus_pct = (Config.reward_system.joint_op_xp_bonus or 0.25) * 100
        outtext = outtext .. string.format("\n\nJoint Operation bonus: +%d%% XP", joint_op_bonus_pct)
        
        trigger.action.outTextForUnit(unit_id, outtext, 30)
        trigger.action.outSoundForUnit(unit_id,"radio_txrx.ogg")
    end

    ---@param zone_name any
    function OperationManager:isZoneActive(zone_name)
        return false
        -- for _, op in ipairs(self.active_operations) do
        --     if op.target_zone_name == zone_name then
        --         return true
        --     end
        -- end
        -- return false
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
    function OperationManager:initiateOperation(unit, code)
        if not unit then return end
        if not unit.getPlayerName then return end
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
        accepted_mission.operation_id = string.format("airlift_%d_%d", accepted_mission.code or 0, math.floor(timer.getTime()))
        
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

            ctld.setOperationContextForUnit(unit, {
                operation_id = accepted_mission.operation_id,
                operation_type = accepted_mission.type,
                load_zone_name = accepted_mission.load_zone_name,
                target_zone_name = accepted_mission.target_zone_name,
            })

            ctld.airlift_operation_tracking[unit_id] = {
                operation_id = accepted_mission.operation_id,
                operation_type = accepted_mission.type,
                load_zone_name = accepted_mission.load_zone_name,
                target_zone_name = accepted_mission.target_zone_name,
                manifest = accepted_mission.strategic_manifest,
                loaded_parts = {}
            }
        end

        if accepted_mission.type == OperationTypes.REINFORCEMENT then
            accepted_mission.operation_id = string.format("reinforce_%d_%d", accepted_mission.code or 0, math.floor(timer.getTime()))
            ctld.setOperationContextForUnit(unit, {
                operation_id = accepted_mission.operation_id,
                operation_type = accepted_mission.type,
                target_zone_name = accepted_mission.target_zone_name,
            })
        end
        
        -- Initialize joint operation fields if this is a joint operation
        if accepted_mission.is_joint_op then
            accepted_mission.joint_op_leader_id = unit_id
            accepted_mission.joint_op_leader_name = unit:getName()
            accepted_mission.joint_op_join_code = self:createOperationCode()
            if not accepted_mission.joint_op_members then
                accepted_mission.joint_op_members = {}
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
            outtxt = outtxt .. string.format("\n\nApproximate pilot location:\n%s\n%s\nMGRS: %s", 
                mist.tostringLL(lat, lon, 4), mist.tostringLL(lat, lon, 4, true), mist.tostringMGRS(mgrs, 4))
            outtxt = outtxt .. "\n\nSmoke has been deployed near the pilot's location."
            outtxt = outtxt .. string.format("\n\nLand within %dm of the pilot to complete the rescue.", Config.operations.csar_rescue_radius or 50)
        elseif accepted_mission.type == OperationTypes.STRATEGIC_AIRLIFT then


            local load_zone = ZoneHandler.getFromName(accepted_mission.load_zone_name)
            local unload_zone = ZoneHandler.getFromName(accepted_mission.target_zone_name)
            if not (load_zone and unload_zone) then return end

            local slat, slon = coord.LOtoLL(load_zone.zone.point)
            local smgrs = coord.LLtoMGRS(slat, slon)
           
            
            local lat, lon = coord.LOtoLL(unload_zone.zone.point)
            local mgrs = coord.LLtoMGRS(lat, lon)

            outtxt = outtxt .. string.format("\n\nLoad Area: %s", accepted_mission.load_zone_name)
            outtxt = outtxt .. string.format("\nUnload Area: %s", accepted_mission.target_zone_name)
            outtxt = outtxt .. string.format("\n\nLoad Coordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(slat, slon, 4), mist.tostringLL(slat, slon, 4, true), mist.tostringMGRS(smgrs, 4))
            outtxt = outtxt .. string.format("\n\nUnload coordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(lat, lon, 4), mist.tostringLL(lat, lon, 4, true), mist.tostringMGRS(mgrs, 4))

            outtxt = outtxt .. string.format("\n\nTime limit: %d minutes", math.floor((accepted_mission.time_limit_seconds or 0) / 60))
            outtxt = outtxt .. string.format("\nExpected reward: %d XP", accepted_mission.xp_reward or 0)
            outtxt = outtxt .. "\n\nManifest:\n" .. (accepted_mission.strategic_manifest_text or "- None")
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
        end

        -- Add joint operation join code if this is a joint operation
        if accepted_mission.is_joint_op then
            outtxt = outtxt .. string.format("\n\nJoint operation code: %d", accepted_mission.joint_op_join_code)
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

                            if obj.check(obj, player_unit,op) then
                                obj.completed = true
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
                        
                        -- Add joint operation members if alive and existing
                        if op.is_joint_op and op.joint_op_members then
                            for _, member_unit_name in pairs(op.joint_op_members) do
                                local member_unit = Unit.getByName(member_unit_name)
                                if member_unit and member_unit:isExist() and member_unit:isActive() then
                                    table.insert(participants_to_reward, member_unit)
                                end
                            end
                        end

                        -- Count actual participants and determine bonus
                        local joint_op_participant_count = #participants_to_reward

                        -- If no participants are alive, operation fails silently
                        if joint_op_participant_count == 0 then
                            table.remove(self.active_operations, i)
                        else

                            -- Mark operation as completed only if we have participants
                            op.status = OperationStatus.COMPLETED

                            local joint_op_bonus_multiplier = 1.0

                            -- Only apply bonus if 2 or more players are actually participating
                            if joint_op_participant_count >= 2 then
                                joint_op_bonus_multiplier = 1.0 + (Config.reward_system.joint_op_xp_bonus or 0.25)
                            end

                            -- Award XP to all participants
                            for _, participant_unit in ipairs(participants_to_reward) do
                                local participant_unit_id = participant_unit:getID()
                                trigger.action.outTextForUnit(participant_unit_id, "Operation " .. op.operation_name .. " completed !", 20)
                                trigger.action.outSoundForUnit(participant_unit_id,"chatter2.ogg")

                                local user = ExperienceManager:fetchUser(participant_unit)
                                if user then
                                    user.missions_completed = user.missions_completed + 1

                                    -- Apply base XP with joint operation bonus (only if 2+ players)
                                    local base_xp = op.xp_reward or 500
                                    local total_xp = math.floor(base_xp * joint_op_bonus_multiplier)
                                    user.unclaimed_xp = user.unclaimed_xp + total_xp

                                    local reward_msg = "+" .. total_xp .. " XP"

                                    -- Only show bonus message if there were actually 2+ players
                                    if joint_op_participant_count >= 2 then
                                        local bonus_pct = math.floor((joint_op_bonus_multiplier - 1.0) * 100)
                                        reward_msg = reward_msg .. string.format("\n[+%d%% Joint Operation Bonus with %d players]", bonus_pct, joint_op_participant_count)
                                    end

                                    reward_msg = reward_msg .. "\nReturn to base to claim your rewards."

                                    trigger.action.outTextForUnit(participant_unit_id, reward_msg, 10)
                                end
                            end

                            if op.type == OperationTypes.STRATEGIC_AIRLIFT then
                                local target_zone = ZoneHandler.getFromName(op.target_zone_name)
                                if target_zone then
                                    local bonus = Config.operations.strategic_airlift.completion_supply_bonus
                                    local variance = Config.operations.strategic_airlift.completion_supply_bonus_variance
                                    if variance > 0 then
                                        bonus = bonus + math.random(-variance, variance)
                                    end
                                    bonus = math.max(0, bonus)

                                    if bonus > 0 and target_zone.ammo_depot_intact == true then
                                        local local_cap = Config.supplies.supplies_cap[target_zone.level or 1] or 0
                                        target_zone.local_supplies = math.min((target_zone.local_supplies or 0) + bonus, local_cap)
                                        target_zone:drawF10()

                                        trigger.action.outTextForCoalition(self.side,string.format("Airlift delivered %d supplies to %s", bonus, target_zone.name), 12)
                                        trigger.action.outSoundForCoalition(self.side, "radio_beep3.ogg")

                                    end
                                end

                                self:cancelStrategicAirliftOperation(op, true)
                            end

                        if op.operation_id then
                            ctld.clearOperationContextForOperation(op.operation_id)
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

                            table.remove(self.active_operations, i)
                        end

                    end
                end
            end
        end
    end

    function OperationManager:tick()
        self:checkObjectives()
    end
    
    -- Force regeneration of operations (call when zones change ownership)
    function OperationManager:forceRegenerateOperations()
        self.available_operations = {}
        self.last_generation_time = 0
        self:generateOperations()
    end
end