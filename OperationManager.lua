---@class Operation
---@field type OperationTypes
---@field code number
---@field status OperationStatus
---@field target_zone_name string
---@field operation_name string
---@field assigned_player_id number | nil
---@field assigned_unit_name string | nil
---@field objectives table
---@field is_coop boolean -- Whether this operation supports co-op
---@field coop_leader_id number | nil -- Unit ID of the player who created the operation
---@field coop_leader_name string | nil -- Name of the unit who created the operation
---@field coop_members table<number, string> -- Map of unit IDs to unit names
---@field coop_join_code number | nil -- Code for other players to join this co-op operation
---@field pilot_position vec3 | nil -- For CSAR operations: position of downed pilot
---@field smoke_spawned boolean | nil -- For CSAR operations: whether smoke has been spawned

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
    OperationManager.__index = OperationManager

    OperationManager.instances = {}

    OperationManager.EventHandler = {}

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
            downed_pilots = {},
            available_operations = {},
            active_operations = {},
            last_generation_time = 0, -- Cache timestamp
            generation_cooldown = Config.operations.operation_refresh_time or 30, -- seconds
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
            trigger.action.outTextForUnit(unit:getID(), "No active operation.", 10)
            return
        end

        -- Handle CSAR operations differently
        if active_mission.type == OperationTypes.CSAR then
            if not active_mission.pilot_position then
                trigger.action.outTextForUnit(unit:getID(), "Error: Pilot position not found.", 10)
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
                local status = obj.completed and "[Completed]" or "[Pending]"
                outtxt = outtxt .. string.format("\n%d. %s %s", i, obj.description, status)
            end
            
            -- Show distance to pilot
            local player_pos = unit:getPoint()
            if player_pos and active_mission.pilot_position then
                local dist = mist.utils.get2DDist(player_pos, active_mission.pilot_position)
                outtxt = outtxt .. string.format("\n\nDistance to pilot: %.0fm", dist)
                outtxt = outtxt .. string.format("\nRequired proximity: %dm", Config.operations.csar_rescue_radius or 50)
            end
            
            trigger.action.outTextForUnit(unit:getID(), outtxt, 120)
            return
        end

        local zone_tgt = ZoneHandler.getFromName(active_mission.target_zone_name)
        if not zone_tgt or not zone_tgt.zone or not zone_tgt.zone.point then
            trigger.action.outTextForUnit(unit:getID(), "Target zone not found for this operation.", 10)
            self:cancelOperation(unit)
            return
        end

        local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
        local mgrs = coord.LLtoMGRS(lat, lon)

        local outtxt = ""
        if active_mission.type == OperationTypes.RECON or active_mission.type == OperationTypes.INTERCEPT then
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s",
            active_mission.operation_name, active_mission.type)
        else
            outtxt = string.format("ACTIVE OPERATION: %s\nType: %s\nTarget: %s",
                active_mission.operation_name, active_mission.type, active_mission.target_zone_name)
        end
        
        if not active_mission.type == OperationTypes.INTERCEPT then
            outtxt = outtxt .. string.format("\n\nCoordinates:\n%s\n%s\nMGRS: %s",
                mist.tostringLL(lat, lon, 2), mist.tostringLL(lat, lon, 2, true), mist.tostringMGRS(mgrs, 3))
        end

        outtxt = outtxt .. "\n\nObjectives:"
        for i, obj in ipairs(active_mission.objectives) do
            local status = obj.completed and "[Completed]" or "[Pending]"
            outtxt = outtxt .. string.format("\n%d. %s %s", i, obj.description, status)
        end

        trigger.action.outTextForUnit(unit:getID(), outtxt, 120)
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
                                    for remaining_id, _ in pairs(op.coop_members) do
                                        trigger.action.outTextForUnit(remaining_id, member_unit:getPlayerName() .. " is now the operation leader.", 10)
                                    end
                                    
                                    new_leader_found = true
                                    break
                                end
                            end
                            
                            -- If no new leader found, fail the operation
                            if not new_leader_found then
                                op.status = OperationStatus.FAILED
                                trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: all operatives lost.", 15)
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: operative lost.", 15)
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
                            end
                            for member_id, _ in pairs(op.coop_members) do
                                trigger.action.outTextForUnit(member_id, "A co-op member has been lost.", 10)
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
                                    for remaining_id, _ in pairs(op.coop_members) do
                                        trigger.action.outTextForUnit(remaining_id, member_unit:getPlayerName() .. " is now the operation leader.", 10)
                                    end
                                    
                                    new_leader_found = true
                                    break
                                end
                            end
                            
                            if not new_leader_found then
                                op.status = OperationStatus.FAILED
                                trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: all operatives left.", 15)
                                table.remove(self.active_operations, i)
                            end
                        else
                            -- Solo operation - fail it
                            op.status = OperationStatus.FAILED
                            trigger.action.outTextForCoalition(self.side, "Operation " .. op.operation_name .. " failed: operative left.", 15)
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
                            end
                            for member_id, _ in pairs(op.coop_members) do
                                trigger.action.outTextForUnit(member_id, "A co-op member has left the operation.", 10)
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
        "Cerulean Shield",
        "Iron Fist",
        "Crimson Dawn",
        "Viper Strike",
        "Obsidian Shadow",
        "Blazing Inferno",
        "Midnight Valor",
        "Silver Talon",
        "Tempest Fury",
        "Scarlet Thunder",
        "Arctic Serpent",
        "Infernal Hammer",
        "Sovereign Blade",
        "Raven Descent",
        "Titan's Roar",
        "Phantom Echo",
        "Nemesis Rising",
        "Wildfire Assault",
        "Frostbite",
        "Thunderstorm",
        "Inferno Blaze",
        "Shadow Strike",
        "Golden Eagle",
        "Crimson Force",
        "Venom Fang",
        "Apex Predator",
        "Forge Hammer",
        "Eternal Storm",
        "Midnight Blade",
        "Valkyrie Wings",
        "Serpent's Wrath",
        "Avalanche Force",
        "Crimson Shield",
        "Thunderbolt",
        "Obsidian Spear",
        "Infernal Reign",
        "Midnight Storm",
        "Raging Inferno",
        "Victory Rising",
        "Phantom Assault",
        "Vengeance Strike",
        "Steel Fury",
        "Blazing Justice",
        "Nexus Hammer",
        "Primal Fury",
        "Titan Force",
        "Void Strike",
        "Savage Talon",
        "Vortex Fury"
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

            if not discovered_zones_set[op.target_zone_name] then
                table.remove(self.available_operations, i)
            end

        end

        local sorted_zones = ZoneHandler.sortZonesByDistance(reference_pos)
        for _, zone in ipairs(sorted_zones) do

            if not self:isZoneActive(zone.name) and not self:isMissionProposed(zone.name)
            then
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
                            local dead_op = self:createDEADOperation(zone)
                            table.insert(self.available_operations, dead_op)
                        end

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

                -- RECON over enemy zones
                if zone.side == enemy_coalition and not discovered_zones_set[zone.name] then
                    local op = self:createRECONOperation(zone)
                    table.insert(self.available_operations, op)
                end

                -- AIRDROP over friendly zones
                if zone.side == friendly_coalition and discovered_zones_set[zone.name] and zone.level < 4 then
                    local closest_enemy_zone, dist = zone:getClosestZone(enemy_coalition)
                    if closest_enemy_zone and dist and dist < Config.operations.max_distance_to_frontline_for_airdrops then
                        local op = self:createAIRDROPOperation(zone)
                        table.insert(self.available_operations, op)
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

    function OperationManager:createCASOperation(target_zone)
        local op = {
            type = OperationTypes.CAS,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
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

        local op = {
            type = OperationTypes.CSAR,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
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
        local op = {
            type = OperationTypes.INTERCEPT,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
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
                            string.format("Intercept - Aircraft destroyed! (%d/%d)", self.kills, self.required_kills), 10)
                    end
                }
            }
        }
        return op
    end

    function OperationManager:createAIRDROPOperation(target_zone)
        local op = {
            type = OperationTypes.AIRDROP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = false,
            coop_leader_id = nil,
            coop_leader_name = nil,
            coop_members = {},
            coop_join_code = nil,
            objectives = {
                {
                    description = "Successfully deliver ".. Config.operations.airdrop_min_crates_landed .. "x CDS CRATES to " .. target_zone.name .. " via air drop.",
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

                            local cargo_names = {}
                            local foundCargo = false
                            local cargo_count = 0
                            world.searchObjects({Object.Category.CARGO}, volume, function(obj)
                                if obj and obj:isExist() and obj.getVelocity and obj.getName then
                                    table.insert(cargo_names, obj:getName())
                                    MissionLogger:info("Found cargo: "..obj:getName())

                                    local vel = obj:getVelocity()
                                    -- Checks if cargo has landed
                                    local speed = math.sqrt(vel.x^2 + vel.y^2 + vel.z^2)
                                    if speed < 1 then
                                        cargo_count = cargo_count + 1
                                        if cargo_count >= Config.operations.airdrop_min_crates_landed then
                                            foundCargo = true
                                        end
                                    end
                                end
                                return true
                            end)
                            
                            if foundCargo then
                                MissionLogger:info("Airdrop objective completed! Cargo landed count: "..cargo_count)
                                if zone.level < 4 then
                                    zone.level = zone.level + 1
                                    UnitHandler.updateZoneUnits(zone)
                                    zone:drawF10()
                                    zone.next_level_up_avail = timer.getTime() + Config.logistics_level_up_interval
                                    trigger.action.outSoundForCoalition(zone.side,"radio_beep.ogg")
                                    trigger.action.outTextForCoalition(zone.side, "> AIRDROP: "..zone.name.." has been upgraded to tier "..zone.level.."/4",10)
                                    
                                else 
                                    trigger.action.outTextForCoalition(zone.side, "> AIRDROP: "..zone.name.." is already at tier 4/4.",10)
                                end

                                -- Delete cargo crates from world
                                timer.scheduleFunction(function ()
                                    MissionLogger:info("Removing cargo crates for airdrop objective.")
                                    for _, cname in ipairs(cargo_names) do
                                        -- MissionLogger:info("Looking for cargo: "..cname)
                                        local cargo_obj = StaticObject.getByName(cname)
                                        if cargo_obj and cargo_obj:isExist() then
                                            -- MissionLogger:info("Destroying cargo: "..cname)
                                            cargo_obj:destroy()
                                        end
                                    end

                                end, {}, timer.getTime() + 120)

                                return true
                            end
                        return false
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
        local op = {
            type = OperationTypes.DEAD,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
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
        end

        local op = {
            type = OperationTypes.STRIKE,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
            target_zone_name = target_zone.name,
            operation_name = operations_name[math.random(#operations_name)],
            is_coop = true,
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

    function OperationManager:createCAPOperation(target_zone)
        local op = {
            type = OperationTypes.CAP,
            code = self:createOperationCode(),
            status = OperationStatus.AVAILABLE,
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
    ---@param show_coop_only boolean|nil -- If true, only show operations that support co-op
    function OperationManager:showAvailableOperations(unit, show_coop_only)
        if not unit or not unit:isExist() or not unit.getPlayerName or not unit.hasAttribute then return end

        self:generateOperations()

        local unit_supported_operations = {}
        local unit_type = unit:getTypeName()
        
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
                if op.type == OperationTypes.RECON then
                    tgt_zone = "Undiscovered Location"
                elseif op.type == OperationTypes.CSAR then
                    tgt_zone = "Emergency Rescue"
                end

                outtext = outtext .. string.format("\n\n %s - %s", op.type, tgt_zone)

                for _, obj in ipairs(op.objectives) do
                    outtext = outtext .. "\n - " .. obj.description
                end

                outtext = outtext .. "\n Reward: " .. (Config.reward_system.xp_per_mission_completed or 100) .. " XP, " .. (Config.reward_system.tokens_mission_complete[op.type] or 0) .. " tokens"
                outtext = outtext .. "\n Operation code: " .. op.code
                operations_displayed = operations_displayed + 1
                table.insert(operation_types_displayed, op.type)
            end
        end
        trigger.action.outTextForUnit(unit:getID(), outtext, 30)
    end

    ---@param unit Unit
    function OperationManager:cancelOperation(unit)
        if not unit then return end
        if not unit.getPlayerName then return end

        for i, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() then
                -- Leader is cancelling - notify all co-op members if applicable
                if active_op.is_coop and active_op.coop_members then
                    for member_id, _ in pairs(active_op.coop_members) do
                        trigger.action.outTextForUnit(member_id, "Operation " .. active_op.operation_name .. " has been cancelled by the leader.", 10)
                        trigger.action.outSoundForUnit(member_id, "chatter3.ogg")
                    end
                end
                
                table.remove(self.active_operations, i)
                trigger.action.outSoundForUnit(unit:getID(),"chatter3.ogg")
                trigger.action.outTextForUnit(unit:getID(), "Operation " .. active_op.operation_name .. " cancelled.", 10)
                return
            end
            
            -- Check if this player is a co-op member
            if active_op.is_coop and active_op.coop_members and active_op.coop_members[unit:getID()] then
                self:leaveCoopOperation(unit, active_op)
                return
            end
        end

    end

    ---@param unit Unit
    ---@param join_code number
    function OperationManager:joinCoopOperation(unit, join_code)
        if not unit or not unit.getPlayerName then return end
        
        -- Check if player already has an active operation
        for _, active_op in ipairs(self.active_operations) do
            if active_op.assigned_player_id == unit:getID() or 
               (active_op.coop_members and active_op.coop_members[unit:getID()]) then
                trigger.action.outTextForUnit(unit:getID(), "You are already on an operation.", 10)
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
            trigger.action.outTextForUnit(unit:getID(), "Invalid co-op join code.", 10)
            return
        end
        
        -- Check if operation is still active (not completed/failed)
        if target_op.status ~= OperationStatus.ACTIVE then
            trigger.action.outTextForUnit(unit:getID(), "Operation is no longer active.", 10)
            return
        end
        
        -- Verify leader still exists
        local leader_unit = Unit.getByName(target_op.assigned_unit_name)
        if not leader_unit or not leader_unit:isExist() then
            trigger.action.outTextForUnit(unit:getID(), "Operation leader is no longer available.", 10)
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
            trigger.action.outTextForUnit(unit:getID(), "Co-op operation is full.", 10)
            return
        end
        
        -- Add player to co-op members
        if not target_op.coop_members then
            target_op.coop_members = {}
        end
        target_op.coop_members[unit:getID()] = unit:getName()
        
        -- Notify all participants
        local join_msg = string.format("%s has joined Operation %s", unit:getPlayerName(), target_op.operation_name)
        trigger.action.outTextForUnit(target_op.assigned_player_id, join_msg, 10)
        for member_id, _ in pairs(target_op.coop_members) do
            trigger.action.outTextForUnit(member_id, join_msg, 10)
        end
        
        trigger.action.outSoundForUnit(unit:getID(),"chatter1.ogg")
        self:showActiveOperation(unit)
    end
    
    ---@param unit Unit
    ---@param operation Operation|nil
    function OperationManager:leaveCoopOperation(unit, operation)
        if not unit or not unit.getPlayerName then return end
        
        local target_op = operation
        if not target_op then
            -- Find the operation this player is in
            for _, active_op in ipairs(self.active_operations) do
                if active_op.coop_members and active_op.coop_members[unit:getID()] then
                    target_op = active_op
                    break
                end
            end
        end
        
        if not target_op or not target_op.coop_members or not target_op.coop_members[unit:getID()] then
            trigger.action.outTextForUnit(unit:getID(), "You are not in a co-op operation.", 10)
            return
        end
        
        -- Remove player from co-op members
        target_op.coop_members[unit:getID()] = nil
        
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
        end
        
        trigger.action.outTextForUnit(unit:getID(), "You have left the co-op operation.", 10)
    end
    
    ---@param unit Unit
    function OperationManager:showCoopOperationStatus(unit)
        if not unit or not unit.getPlayerName then return end
        
        -- Find if player is leader or member of a co-op operation
        local player_op = nil
        local is_leader = false
        
        for _, active_op in ipairs(self.active_operations) do
            if active_op.is_coop then
                if active_op.assigned_player_id == unit:getID() then
                    player_op = active_op
                    is_leader = true
                    break
                elseif active_op.coop_members and active_op.coop_members[unit:getID()] then
                    player_op = active_op
                    is_leader = false
                    break
                end
            end
        end
        
        if not player_op then
            trigger.action.outTextForUnit(unit:getID(), "You are not in a co-op operation.", 10)
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
        outtext = outtext .. string.format("\n\nCo-op Bonus: +%d%% XP and Tokens", coop_bonus_pct)
        
        trigger.action.outTextForUnit(unit:getID(), outtext, 30)
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
        -- Skip this check for CSAR operations
        if accepted_mission.type ~= OperationTypes.CSAR and self:isZoneActive(accepted_mission.target_zone_name) then
            trigger.action.outTextForUnit(unit:getID(), "Operation Aborted: Target zone " .. accepted_mission.target_zone_name .. " is already being engaged by another unit.", 10)
            
            -- Optional: Remove it from available list so they don't try again immediately
            table.remove(self.available_operations, mission_index)
            return
        end

        -- For CSAR operations, handle differently
        local zone_tgt = nil
        if accepted_mission.type == OperationTypes.CSAR then
            -- CSAR doesn't need a zone, it uses pilot_position
            if not accepted_mission.pilot_position then
                trigger.action.outTextForUnit(unit:getID(), "Error: Pilot position not found.", 10)
                return
            end
        else
            zone_tgt = ZoneHandler.getFromName(accepted_mission.target_zone_name)

        end

        -- Move from available to active
        table.remove(self.available_operations, mission_index)
        accepted_mission.status = OperationStatus.ACTIVE
        accepted_mission.assigned_player_id = unit:getID()
        accepted_mission.assigned_unit_name = unit:getName()
        
        -- Initialize co-op fields if this is a co-op operation
        if accepted_mission.is_coop then
            accepted_mission.coop_leader_id = unit:getID()
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
                mist.tostringLL(lat, lon, 1), mist.tostringLL(lat, lon, 1, true), mist.tostringMGRS(mgrs, 3))
            outtxt = outtxt .. "\n\nGreen smoke has been deployed at the pilot's location."
            outtxt = outtxt .. string.format("\n\nLand within %dm of the pilot to complete the rescue.", Config.operations.csar_rescue_radius or 50)
        else
            if not zone_tgt then
                trigger.action.outTextForUnit(unit:getID(), "Target zone not found for this operation.", 10)
                return
            end
            local lat, lon = coord.LOtoLL(zone_tgt.zone.point)
            local mgrs = coord.LLtoMGRS(lat, lon)

            if not utils.tableContains({OperationTypes.RECON, OperationTypes.INTERCEPT}, accepted_mission.type) then
                outtxt = outtxt .. "\n\nTarget area: " .. accepted_mission.target_zone_name
            end

            if accepted_mission.type ~= OperationTypes.INTERCEPT then
                outtxt = outtxt .. string.format("\n\nApproximate location coordinates:\n%s\n%s\nMGRS: %s", mist.tostringLL(lat, lon, 1), mist.tostringLL(lat, lon, 1, true), mist.tostringMGRS(mgrs, 3))
            end
        end

        -- Add co-op join code if this is a co-op operation
        if accepted_mission.is_coop then
            outtxt = outtxt .. string.format("\n\nCO-OP Join Code: %d\nShare this code with other players to join this operation.", accepted_mission.coop_join_code)
        end

        trigger.action.outTextForUnit(accepted_mission.assigned_player_id, outtxt, 25)

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

                ---@type Unit
                local player_unit = player_unit_for_cap or Unit.getByName(op.assigned_unit_name)

                -- AIRDROP operations can be checked even if player unit doesn't exist
                -- (crates can land after player RTB/ejects/crashes)
                local can_check_objectives = (player_unit and player_unit:isExist()) or op.type == OperationTypes.AIRDROP
                
                if can_check_objectives then
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
                            trigger.action.outTextForUnit(participant_unit:getID(), "Operation " .. op.operation_name .. " completed !", 20)
                            trigger.action.outSoundForUnit(participant_unit:getID(),"chatter2.ogg")
                            
                            local user = ExperienceManager:fetchUser(participant_unit)
                            if user then
                                user.missions_completed = user.missions_completed + 1
                                
                                -- Apply base XP with co-op bonus (only if 2+ players)
                                local base_xp = Config.reward_system.xp_per_mission_completed
                                local total_xp = math.floor(base_xp * coop_bonus_multiplier)
                                user.unclaimed_xp = user.unclaimed_xp + total_xp

                                -- Apply token reward with co-op bonus (only if 2+ players)
                                local base_tokens = 0
                                if Config.reward_system.tokens_mission_complete[op.type] then
                                    base_tokens = Config.reward_system.tokens_mission_complete[op.type]
                                else
                                    base_tokens = 5 -- default
                                end
                                local total_tokens = math.floor(base_tokens * coop_bonus_multiplier)
                                user.unclaimed_tokens = user.unclaimed_tokens + total_tokens

                                local reward_msg = "+" .. total_xp .. " XP; +" .. total_tokens .. " Tokens."
                                
                                -- Only show bonus message if there were actually 2+ players
                                if coop_participant_count >= 2 then
                                    local bonus_pct = math.floor((coop_bonus_multiplier - 1.0) * 100)
                                    reward_msg = reward_msg .. string.format("\n[+%d%% Co-op Bonus with %d players]", bonus_pct, coop_participant_count)
                                end
                                
                                reward_msg = reward_msg .. "\nReturn to base to claim your rewards."
                                
                                trigger.action.outTextForUnit(participant_unit:getID(), reward_msg, 10)
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

                        table.remove(self.active_operations, i)
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
        self.last_generation_time = 0
        self:generateOperations()
    end
end