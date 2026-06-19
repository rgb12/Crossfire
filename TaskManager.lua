---@class TaskManager
TaskManager = {}
do
    TaskManager.AWACSOrbitArea = {}
    TaskManager.TankerSectors = {}
    TaskManager._tankerSerial = {
        [coalition.side.BLUE] = 0,
        [coalition.side.RED] = 0,
    }
    ---@type number[]
    TaskManager.assignedFrequencies = {}
    ---@type table<number, boolean>
    TaskManager.assignedTACANS = {}

    ---@param template_name string
    ---@param airbase Airbase
    ---@return table|boolean
    function TaskManager:spawnAIFlightFromParking(template_name, airbase)
        if not airbase then return false end

        local group_data = mist.getGroupData(template_name)
        if not group_data then
            MissionLogger:info("[Spawn] ERROR: Template group '" .. template_name .. "' not found in mission.")
            return false
        end
        -- Deep-copy so we never mutate the MIST database entry
        group_data = mist.utils.deepCopy(group_data)

        group_data.clone = true
        group_data.groupId = nil
        for _, unit in ipairs(group_data.units or {}) do
            unit.unitId = nil
        end

        -- Clear late-activation / uncontrolled flags
        group_data.lateActivation = false
        group_data.uncontrolled   = false

        -- Air-spawn groups have no route table; initialise safely
        if not group_data.route        then group_data.route        = {} end
        if not group_data.route.points then group_data.route.points = {} end

        -- Replace first waypoint with a cold-start parking point at the target airbase
        local base_pt = airbase:getPoint()
        group_data.route.points[1] = {
            alt                = 0,           -- ground level; DCS fills real terrain elevation
            alt_type           = "BARO",
            type               = "TakeOffParking",
            action             = "From Parking Area",  -- cold & dark (engines OFF)
            airdromeId         = airbase:getID(),
            x                  = base_pt.x,
            y                  = base_pt.z,   -- DCS world Z -> mission Y (2-D map)
            speed              = 0,
            formation_template = "",
            properties         = {},
            name               = "Spawn " .. airbase:getName(),
        }

        -- Unique names prevent collisions on repeat / simultaneous spawns
        local stamp    = string.format("%d_%d", math.floor(timer.getTime()), math.random(100, 999))
        group_data.name = template_name .. "_" .. stamp
        for i, unit in ipairs(group_data.units) do
            unit.name = group_data.name .. "_u" .. i
        end

        local new_group = mist.dynAdd(group_data)
        if not new_group then
            MissionLogger:info("[AI SPAWN] mist.dynAdd returned nil for '" .. template_name .. "' at " .. airbase:getName())
            return false
        end

        -- Post-spawn sanity check: DCS schedules group creation for the next simulation frame,
        -- so verify after 3 s that the group appeared.  A missing or empty group means the
        -- airbase had no parking spot compatible with this aircraft type (e.g. AWACS at a
        -- small airbase).
        local spawned_name = new_group.name
        local airbase_name = airbase:getName()
        local side         = airbase:getCoalition()
        timer.scheduleFunction(function()
            local grp = Group.getByName(spawned_name)
            if not grp or not grp:isExist() or grp:getSize() == 0 then
                MissionLogger:info("[AI Spawn] '" .. spawned_name .. "' failed at " .. airbase_name
                    .. " - no suitable parking spot (airbase may be too small for " .. template_name .. ").")
                trigger.action.outTextForCoalition(side,
                    "[AI Spawn] Spawn failed at " .. airbase_name .. ": no suitable parking for this aircraft type.", 8)
                if grp then grp:destroy() end
            end
        end, {}, timer.getTime() + 3)

        return new_group
    end

    ---@param ai_task_type AITaskTypes
    ---@param side coalition.side
    ---@param prevent_duplicates boolean
    ---@param to_zone ZoneHandler|nil
    ---@param from_zone ZoneHandler|nil
    ---@param user_requested boolean
    ---@return boolean
    function TaskManager:initiateAITask(ai_task_type,side,prevent_duplicates,to_zone,from_zone,user_requested)

        --[[
        1. Find closest airbase available to spawn
        2. Check if payload in stock
        3. Spawn the aircraft
        4. Assign AI Task
        ]]

        if not EraSystem.isTaskTypeAllowed(ai_task_type) then
            MissionLogger:info("[Era] Task '"..tostring(ai_task_type).."' is not available in the selected era(s); skipping.")
            if user_requested then
                trigger.action.outTextForCoalition(side, tostring(ai_task_type).." not available in this era", 10)
            end
            return false
        end

        local function sendText(txt)
            if user_requested then
                trigger.action.outTextForCoalition(side,txt,5)
            end
        end

        ---@param ai_task_type AITaskTypes
        ---@return string|nil
        local function findGroupName(ai_task_type)
            local side_assets = side == coalition.side.BLUE and GroupData.COMMON_ASSETS.BLUE or GroupData.COMMON_ASSETS.RED
            if not side_assets then return nil end

            local base_name = nil
            if ai_task_type == AITaskTypes.CAS then
                base_name = side_assets.cas
            elseif ai_task_type == AITaskTypes.CAP then
                base_name = side_assets.cap
            elseif ai_task_type == AITaskTypes.SEAD then
                base_name = side_assets.sead
            elseif ai_task_type == AITaskTypes.STRIKE then
                base_name = side_assets.strike
            elseif ai_task_type == AITaskTypes.AWACS then
                base_name = side_assets.awacs
            elseif ai_task_type == AITaskTypes.RECON then
                base_name = side_assets.recon
            end
            return EraSystem.resolveTaskTemplateName(base_name)
        end

        ---@param task_label string
        ---@return ZoneHandler|nil, string|nil
        local function resolveSourceAirbase(task_label)
            if from_zone and from_zone.zone_type == ZoneTypes.AIRBASE then
                if not self:isAirbaseRunwayOperational(from_zone) then
                    MissionLogger:info("["..task_label.."] Runway inoperable at "..from_zone.name)
                    sendText(task_label.." unavailable from "..from_zone.name..", runway is inporable.")
                    return nil, nil
                end

                local in_stock, template_gr_name = WarehouseManager:checkAircraftInStock(from_zone.airbase_name, ai_task_type)
                if not in_stock then
                    MissionLogger:info("["..task_label.."] Required aircraft not in stock at "..from_zone.name)
                    sendText(task_label.." unavailable from "..from_zone.name..", check aircraft availability, warehouse stock and tasking limits.")
                    return nil, nil
                end
                return from_zone, template_gr_name
            end

            if not to_zone then
                return nil, nil
            end

            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                MissionLogger:info("["..task_label.."] No airbase with required aircraft in stock and runway operable found for "..to_zone.name)
                sendText(task_label.." unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits.")
                return nil, nil
            end
            return closest_airbase, template_gr_name
        end

        if AITaskTypes.CAS == ai_task_type and to_zone then

            local source_airbase = resolveSourceAirbase("CAS")
            if not source_airbase then
                MissionLogger:info("[CAS] Could not resolve airbase")
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.CAS}) then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAS already tasked for "..to_zone.name,5)
                end
                MissionLogger:info("[CAS] CAS already tasked for "..to_zone.name.." (side "..tostring(side)..")")
                return false
            end

            local airbase = Airbase.getByName(source_airbase.airbase_name)
            if not airbase then return false end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(source_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAS unavailable from "..source_airbase.name..", airbase cannot handle more tasks at the moment.",5)
                end
                MissionLogger:info("[CAS] CAS unavailable from "..source_airbase.name..", airbase cannot handle more tasks at the moment.")
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then
                MissionLogger:info("[CAS] Required payload/armament not in warehouse for CAS from "..source_airbase.name)
                sendText("CAS required payload/armement not in warehouse.")
                return false
            end

            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local new_group = self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then
                MissionLogger:info("[CAS] Failed to spawn CAS flight from "..source_airbase.name.." (possibly airbase parking too small).")
                sendText("CAS failed to spawn (possibly airbase "..source_airbase.name.." parking too small).")
                return false
            end
            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=source_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })

            self:setCASTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.AWACS == ai_task_type and from_zone and from_zone.zone_type == ZoneTypes.AIRBASE then

            if not self:isAirbaseRunwayOperational(from_zone) then
                sendText("AWACS unavailable from "..from_zone.name..", runway is inoperable.")
                MissionLogger:info("[AWACS] Runway inoperable at "..from_zone.name)
                return false
            end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(from_zone,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"AWACS unavailable from "..from_zone.name..", airbase cannot handle more tasks at the moment.",5)
                end
                MissionLogger:info("[AWACS] AWACS unavailable from "..from_zone.name..", airbase cannot handle more tasks at the moment.")
                return false
            end

            local in_stock, _ = WarehouseManager:checkAircraftInStock(from_zone.airbase_name,ai_task_type)
            if not in_stock then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"AWACS unavailable from "..from_zone.name..", check aircraft availability, warehouse stock and tasking limits.",5)
                end
                MissionLogger:info("[AWACS] Required aircraft not in stock at "..from_zone.name)
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(from_zone,side,{AITaskTypes.AWACS}) then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"AWACS already tasked for "..from_zone.name,5)
                end
                MissionLogger:info("[AWACS] AWACS already tasked for "..from_zone.name)
                return false
            end


            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local airbase = Airbase.getByName(from_zone.airbase_name)
            local new_group = airbase and self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then
                MissionLogger:info("[AWACS] Failed to spawn AWACS flight from "..from_zone.name.." (possibly airbase parking too small).")
                sendText("CAS failed to spawn (possibly airbase "..from_zone.name.." parking too small).")
                return false
            end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = from_zone,
                side=side,
                from_zone=from_zone,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setAWACSTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.TANKER == ai_task_type and from_zone and from_zone.zone_type == ZoneTypes.AIRBASE then

            if not self:isAirbaseRunwayOperational(from_zone) then
                sendText("TANKER unavailable from "..from_zone.name..", runway is inoperable.")
                MissionLogger:info("[TANKER] Runway inoperable at "..from_zone.name)
                return false
            end

            local max_tanker_theatre = Config.tasking.max_tanker_per_theatre or 2
            if self:countActiveTankerSectors(side) >= max_tanker_theatre then
                sendText("TANKER unavailable, maximum active tanker sectors reached.")
                MissionLogger:info("[TANKER] Maximum active tanker sectors reached.")
                return false
            end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(from_zone,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    local txt="TANKER unavailable from "..from_zone.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                    MissionLogger:info("[TANKER] Airbase cannot handle more tasks at the moment.")
                end
                return false
            end

            local tanker_from_airbase = self:countActiveTankerSectorsFromAirbase(from_zone, side)
            if tanker_from_airbase >=Config.tasking.max_tanker_per_airbase then
                sendText("TANKER unavailable from "..from_zone.name..", max tanker sectors from this airbase reached.")
                MissionLogger:info("[TANKER] Maximum tanker sectors from "..from_zone.name.." reached.")
                return false
            end

            local enemy_side = utils.getEnemyCoalition(side)
            local nearest_enemy_zone, nearest_enemy_dist = from_zone:getClosestZone(enemy_side,nil,nil,false)
            if not nearest_enemy_zone or not nearest_enemy_dist or nearest_enemy_dist == math.huge then
                sendText("TANKER unavailable, no enemy zone found for sector placement.")
                MissionLogger:info("[TANKER] No enemy zone found for sector placement.")
                return false
            end

            local min_enemy_distance = Config.tanker.minimum_enemy_distance
            if nearest_enemy_dist < min_enemy_distance then
                sendText("TANKER unavailable, nearest enemy area is too close to "..from_zone.name.." (minimum "..math.floor(min_enemy_distance/1000).."km)")
                MissionLogger:info("[TANKER] Nearest enemy area is too close for sector placement (distance: "..math.floor(nearest_enemy_dist/1000).."km).")
                return false
            end
            MissionLogger:info("Attempting tanker spawn")
            local center_point = utils.pointAlongSegment(from_zone.zone.point, nearest_enemy_zone.zone.point, Config.tanker.midpoint_ratio)

            local path_dx = nearest_enemy_zone.zone.point.x - from_zone.zone.point.x
            local path_dz = nearest_enemy_zone.zone.point.z - from_zone.zone.point.z
            local path_len = math.sqrt(path_dx * path_dx + path_dz * path_dz)
            if path_len < 1 then
                sendText("TANKER unavailable, invalid sector geometry.")
                return false
            end

            local ux = path_dx / path_len
            local uz = path_dz / path_len
            local leg_ux = -uz
            local leg_uz = ux
            local half_leg = (Config.tanker.leg_length or (70*1000)) * 0.5

            local wp1 = {
                x = center_point.x - (leg_ux * half_leg),
                y = land.getHeight({ x = center_point.x - (leg_ux * half_leg), y = center_point.z - (leg_uz * half_leg) }),
                z = center_point.z - (leg_uz * half_leg)
            }
            local wp2 = {
                x = center_point.x + (leg_ux * half_leg),
                y = land.getHeight({ x = center_point.x + (leg_ux * half_leg), y = center_point.z + (leg_uz * half_leg) }),
                z = center_point.z + (leg_uz * half_leg)
            }


            local side_assets = side == coalition.side.BLUE and GroupData.COMMON_ASSETS.BLUE or GroupData.COMMON_ASSETS.RED
            -- [Era] The flying-boom tanker is restricted to Late Cold War+; in
            -- earlier tanker eras (Early Cold War) the sector is drogue-only.
            local boom_capable = EraSystem.isBoomTankerEraCapable()
            -- Always need the drogue template; the boom template is only required
            -- when the era can field a boom tanker.
            if not side_assets or not side_assets.tanker_drogue
               or (boom_capable and not side_assets.tanker_boom) then
                sendText("TANKER unavailable, tanker template names are missing from GroupData.COMMON_ASSETS.")
                return false
            end

            self._tankerSerial[side] = (self._tankerSerial[side] or 0) + 1
            local serial_number = self._tankerSerial[side]

            local sector_id = string.format("TANKER_%d_%d_%d", side, math.floor(timer.getTime()), math.random(1000, 9999))
            self.TankerSectors[sector_id] = {
                id = sector_id,
                serial = serial_number,
                side = side,
                from_zone = from_zone,
                enemy_zone = nearest_enemy_zone,
                center_point = center_point,
                waypoint_1 = wp1,
                waypoint_2 = wp2,
                -- [Era] When false the sector is drogue-only (no flying boom).
                boom_capable = boom_capable,
                frequencies = {
                    [TankerRoles.BOOM] = self:createFrequency(225,398), -- in MHz
                    [TankerRoles.DROGUE] = self:createFrequency(225,398), -- in MHz
                },
                tacan = {
                    [TankerRoles.BOOM] = self:createTACAN(50,80),
                    [TankerRoles.DROGUE] = self:createTACAN(50,80)
                },
                route_targets = {
                    boom = 2,
                    drogue = 1,
                },
                mark_ids = {
                    lines = {},
                    text = nil,
                },
                active = true,
            }

            local delay_min = Config.tanker.spawn_delay_min or 120
            local delay_max = Config.tanker.spawn_delay_max or 300
            if delay_max < delay_min then
                delay_max = delay_min
            end
            local spawn_delay = 2--math.random(delay_min, delay_max)

           timer.scheduleFunction(function()
                MissionLogger:info("spawn delay")
                local sector = self.TankerSectors[sector_id]
                if not sector or not sector.active then return end
                MissionLogger:info("spawn delay pass 2")

                local boom_alt = mist.utils.feetToMeters(Config.tanker.boom.altitude_ft)
                local drogue_alt = mist.utils.feetToMeters(Config.tanker.drogue.altitude_ft)

                local boom_lane_wp1, boom_lane_wp2 = self:getTankerLaneWaypoints(sector, "boom")
                local drogue_lane_wp1, drogue_lane_wp2 = self:getTankerLaneWaypoints(sector, "drogue")

                local drogue_spawn = {
                    x = drogue_lane_wp1.x,
                    y = drogue_alt,
                    z = drogue_lane_wp1.z
                }
                local boom_spawn = {
                    x = boom_lane_wp1.x,
                    y = boom_alt,
                    z = boom_lane_wp1.z
                }

                -- [Era] Only spawn the boom tanker when the era can field one.
                local boom_group = nil
                if boom_capable then
                    boom_group = mist.teleportToPoint({
                        groupName = EraSystem.resolveTaskTemplateName(side_assets.tanker_boom),
                        point = boom_spawn,
                        action = "clone",
                        radius=0
                    })
                end
                local drogue_group = mist.teleportToPoint({
                    groupName = EraSystem.resolveTaskTemplateName(side_assets.tanker_drogue),
                    point = drogue_spawn,
                    action = "clone",
                    radius=0
                })

                -- The drogue is always required; the boom only when era-capable.
                if not drogue_group or (boom_capable and not boom_group) then
                    self:cleanupTankerSectorById(sector_id, true)
                    trigger.action.outTextForCoalition(side, "TANKER spawn failed, verify tanker template groups.", 10)
                    return
                end

                if boom_group then
                    sector.boom_group_name = boom_group.name
                end
                sector.drogue_group_name = drogue_group.name

                if boom_group then
                    EnrouteManager:add({
                        to_zone = from_zone,
                        side = side,
                        from_zone = from_zone,
                        group_name = boom_group.name,
                        ai_task_type = AITaskTypes.TANKER,
                        tanker_sector_id = sector_id,
                        tanker_role = "boom",
                    })
                end
                EnrouteManager:add({
                    to_zone = from_zone,
                    side = side,
                    from_zone = from_zone,
                    group_name = drogue_group.name,
                    ai_task_type = AITaskTypes.TANKER,
                    tanker_sector_id = sector_id,
                    tanker_role = "drogue",
                })

                self:drawTankerSector(sector)

                timer.scheduleFunction(function ()
                    if boom_group then
                        self:assignTankerLeg(sector, TankerRoles.BOOM)
                    end
                    self:assignTankerLeg(sector, TankerRoles.DROGUE)
                end,{}, timer.getTime()+12)

                trigger.action.outTextForCoalition(side, "TANKER package on station from "..from_zone.name..".", 10)
                trigger.action.outSoundForCoalition(side, "transmission1.ogg")
            end, {}, timer.getTime() + spawn_delay)

            if user_requested then
                trigger.action.outTextForCoalition(side, "TANKER package preparing, active in "..delay_min.."-"..delay_max.." seconds.", 10)
                trigger.action.outSoundForCoalition(side, "Radio squelch.ogg")
            end

            return true
        elseif AITaskTypes.CAP == ai_task_type and to_zone then

            local source_airbase, _ = resolveSourceAirbase("CAP")
            if not source_airbase then return false end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.CAP}) then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAP already tasked for "..to_zone.name,5)
                end
                MissionLogger:info("[CAP] CAP already tasked for "..to_zone.name.." (side "..tostring(side)..")")
                return false
            end

            local airbase = Airbase.getByName(source_airbase.airbase_name)
            if not airbase then return false end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(source_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    local txt="CAP unavailable from "..source_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                MissionLogger:info("[CAP] Airbase "..source_airbase.name.." cannot handle more tasks at the moment.")
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("CAP required payload/armement not in warehouse.") return false end

            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local new_group = self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then
                MissionLogger:info("[CAP] Failed to spawn CAP flight (possibly airbase "..source_airbase.name.." parking too small).")
                return false
            end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=source_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setCAPTask(new_group.name,ai_enroute_data)
            return true

        elseif AITaskTypes.SEAD == ai_task_type and to_zone then

            local source_airbase, _ = resolveSourceAirbase("SEAD")
            if not source_airbase then return false end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.SEAD}) then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"SEAD already tasked for "..to_zone.name,5)
                end
                MissionLogger:info("[SEAD] SEAD already tasked for "..to_zone.name.." (side "..tostring(side)..")")
                return false
            end

            local airbase = Airbase.getByName(source_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(source_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"SEAD unavailable from "..source_airbase.name..", airbase cannot handle more tasks at the moment.",5)
                end
                MissionLogger:info("[SEAD] Airbase "..source_airbase.name.." cannot handle more tasks at the moment.")
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("SEAD required payload/armement not in warehouse.") return false end

            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local new_group = self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then 
                MissionLogger:info("[SEAD] Failed to spawn SEAD flight (possibly airbase "..source_airbase.name.." parking too small).")
                return false 
            end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=source_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setSEADTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.STRIKE == ai_task_type and to_zone then

            local source_airbase, _ = resolveSourceAirbase("STRIKE")
            if not source_airbase then return false end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.STRIKE}) then
                if user_requested then
                    local txt="STRIKE already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(source_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(source_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    local txt="STRIKE unavailable from "..source_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("STRIKE required payload/armement not in warehouse.") return false end

            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local new_group = self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then 
                MissionLogger:info("[STRIKE] Failed to spawn STRIKE flight (possibly airbase "..source_airbase.name.." parking too small).")
                return false
            end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=source_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            local statics_in_zone = utils.getStaticsInZoneObj(to_zone)
            --Backup check
            if #statics_in_zone == 0 then
                for _,static_name in pairs(to_zone.linked_statics) do
                    local static_obj = StaticObject.getByName(static_name)
                    if static_obj and static_obj:isExist() then
                        table.insert(statics_in_zone,static_obj)
                    end
                end
            end

            if #statics_in_zone == 0 then
                if user_requested then
                    local txt="STRIKE tasks can only be tasked to zones with structures/buildings."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end
            local strike_point = statics_in_zone[math.random(1,#statics_in_zone)]:getPoint()

            self:setSTRIKETask(new_group.name,ai_enroute_data,strike_point)
            return true
        elseif AITaskTypes.RECON == ai_task_type and to_zone then
            local closest_airbase, _ = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    local txt="RECON unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.RECON}) then
                if user_requested then
                    local txt="RECON already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    local txt="RECON unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("RECON required payload/armement not in warehouse.") return false end

            local template_name = findGroupName(ai_task_type)
            if not template_name then return false end

            local new_group = self:spawnAIFlightFromParking(template_name, airbase)
            if not new_group then
                MissionLogger:info("[RECON] Failed to spawn RECON flight (possibly airbase "..closest_airbase.name.." parking too small).")
                return false
            end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=closest_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setRECONTask(new_group.name,ai_enroute_data)
            return true


        elseif AITaskTypes.JTAC == ai_task_type and to_zone then
            -- JTAC does not follow classic spawn from airbase, it instead spawns in the air near the target zone and orbits there
            -- Currently only works for blue

            if EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.JTAC}) then
                if user_requested then
                    local txt="JTAC already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local spawn_point = {
                x = to_zone.zone.point.x + math.random(-5000, 5000),
                y = mist.utils.feetToMeters(25000),               -- y is ALTITUDE
                z = to_zone.zone.point.z + math.random(-5000, 5000)
            }
            if not blue_airbase then return false end

            local new_group = mist.teleportToPoint({
                groupName = EraSystem.resolveTaskTemplateName(GroupData.COMMON_ASSETS.BLUE.jtac),
                point = spawn_point,
                action = "clone"
            })
            if not new_group then return false end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=blue_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setJTACTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.ATTACK_CONVOY == ai_task_type and from_zone then
            -- Ground convoy
            
            
            local convoy_template_gr_name_side
            local enemy_side
            
            if side == coalition.side.BLUE then
                convoy_template_gr_name_side = GroupData.COMMON_ASSETS.BLUE.attack_convoy
                enemy_side = coalition.side.RED
            elseif side == coalition.side.RED then
                convoy_template_gr_name_side = GroupData.COMMON_ASSETS.RED.attack_convoy
                enemy_side = coalition.side.BLUE

            end
            local convoy_template_gr_name = EraSystem.resolveTaskTemplateName(convoy_template_gr_name_side)
            if not convoy_template_gr_name then return false end

            to_zone, _ = from_zone:getClosestZone(enemy_side,nil,nil,true)
            if to_zone and to_zone.side == enemy_side
            and mist.utils.get2DDist(from_zone.zone.point, to_zone.zone.point) < Config.attack_convoy_range then
                
                if prevent_duplicates and EnrouteManager:findByToZone(to_zone,nil,{ai_task_type}) then
                    if user_requested then
                        txt="Unable to task "..ai_task_type.." ,already tasked for this area"
                        trigger.action.outTextForCoalition(side,txt,5)
                    end
                    return false
                end

                local convoy_sent = mist.cloneInZone(convoy_template_gr_name, from_zone.zone.name)
                if not convoy_sent then MissionLogger:info("Attack Convoy spawn failed, no convoy sent") return false end
              
                self:setATTACKCONVOYTask(convoy_sent.name,side,to_zone,from_zone)
                from_zone.attack_convoy = from_zone.attack_convoy - 1
                if from_zone and type(from_zone.drawF10) == "function" then
                    from_zone:drawF10()
                end
                return true
            end
        elseif AITaskTypes.CAPTURE_CONVOY == ai_task_type and to_zone and from_zone then
            if to_zone.side ~= coalition.side.NEUTRAL then return false end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone, nil, {ai_task_type}) then
                sendText("Capture convoy already enroute to " .. to_zone.name)
                return false
            end

            local convoy_template_gr_name_side
            if side == coalition.side.BLUE then
                convoy_template_gr_name_side = GroupData.COMMON_ASSETS.BLUE.capture_convoy
            elseif side == coalition.side.RED then
                convoy_template_gr_name_side = GroupData.COMMON_ASSETS.RED.capture_convoy
            end
            local convoy_template_gr_name = EraSystem.resolveTaskTemplateName(convoy_template_gr_name_side)
            if not convoy_template_gr_name then return false end

            local convoy_sent = mist.cloneInZone(convoy_template_gr_name, from_zone.zone.name)
            if not convoy_sent then MissionLogger:info("Capture Convoy spawn failed, no convoy sent") return false end

            self:setCAPTURECONVOYTask(convoy_sent.name, side, to_zone, from_zone)
            from_zone.attack_convoy = (from_zone.attack_convoy or 0) - 1
            if type(from_zone.drawF10) == "function" then from_zone:drawF10() end
            MissionLogger:info(utils.coalitionToString(side) .. " capture convoy from " .. from_zone.name .. " sent to capture zone: " .. to_zone.name)
            return true
        elseif ai_task_type == AITaskTypes.CAPTURE_HELO and to_zone and from_zone then

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone, side, {AITaskTypes.CAPTURE_HELO}) then
                if user_requested then
                    local txt = "Capture Helicopter already enroute to " .. to_zone.name
                    trigger.action.outTextForCoalition(side, txt, 5)
                end
                return false
            end

            -- [Era] In a pre-helicopter era (WW2) no airframe is flown; the zone
            -- is captured INSTANTLY instead, so the capture loop still works.
            if not EraSystem.isHelicopterEraCapable() then
                if to_zone.side ~= coalition.side.NEUTRAL then return false end
                to_zone:capture(side)
                if not (from_zone and from_zone.lha_source) then
                    from_zone.heli_avail = (from_zone.heli_avail or 0) - 1
                    if type(from_zone.drawF10) == "function" then from_zone:drawF10() end
                end
                if user_requested then
                    trigger.action.outTextForCoalition(side, to_zone.name .. " captured (ground forces moved in).", 10)
                end
                MissionLogger:info(utils.coalitionToString(side) .." instant-captured zone (pre-helicopter era): " .. to_zone.name)
                return true
            end

            local template_name
            if from_zone and from_zone.lha_source and side == coalition.side.BLUE then
                template_name = GroupData.COMMON_ASSETS.BLUE.LHA_capture_helicopter
            elseif side == coalition.side.RED then
                template_name = GroupData.COMMON_ASSETS.RED.capture_helicopter
            elseif side == coalition.side.BLUE then
                template_name = GroupData.COMMON_ASSETS.BLUE.capture_helicopter
            end
            template_name = EraSystem.resolveTaskTemplateName(template_name)
            if not template_name then return false end

            local helo_sent = mist.teleportToPoint({
                groupName = template_name,
                point = from_zone.zone.point,
                action = "clone"
            })

            if not helo_sent then MissionLogger:info("Capture Heli spawn failed, no heli sent") return false end

            EnrouteManager:add({
                group_name = helo_sent.name,
                to_zone = to_zone,
                from_zone = from_zone,
                side = side,
                ai_task_type = AITaskTypes.CAPTURE_HELO,
                aborted = false
            })

            self:setCAPTUREHELITask(helo_sent.name,side,to_zone,from_zone)

            if not (from_zone and from_zone.lha_source) then
                from_zone.heli_avail = (from_zone.heli_avail or 0) - 1
                if from_zone and type(from_zone.drawF10) == "function" then
                    from_zone:drawF10()
                end
            end
            MissionLogger:info(utils.coalitionToString(side) .." heli from " ..from_zone.name .. " sent to capture zone: " .. to_zone.name)
            return true
        elseif ai_task_type == AITaskTypes.REINFORCEMENT_HELO and to_zone and from_zone then

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone, side, {AITaskTypes.REINFORCEMENT_HELO}) then
                if user_requested then
                    local txt = "Reinforcement helicopter already enroute to " .. to_zone.name
                    trigger.action.outTextForCoalition(side, txt, 5)
                end
                return false
            end

            -- [Era] In a pre-helicopter era (WW2) no airframe is flown; the
            -- target zone is reinforced (tier bump) INSTANTLY, mirroring the
            -- reinforcement-arrival effect in EnrouteManager.
            if not EraSystem.isHelicopterEraCapable() then
                if to_zone.side == side and (to_zone.level or 1) < 4 then
                    to_zone.level = (to_zone.level or 1) + 1
                    to_zone.next_level_up_avail = timer.getTime() + (Config.logistics_level_up_interval or (16 * 60))
                    UnitHandler.updateZoneUnits(to_zone)
                    to_zone:drawF10()
                    trigger.action.outTextForCoalition(side,
                        string.format("SITREP: %s has reached operational tier %d/4 ", to_zone.name, to_zone.level), 10)
                    trigger.action.outSoundForCoalition(side, "radio_beep3.ogg")
                end
                if not (from_zone and from_zone.lha_source) then
                    from_zone.heli_avail = (from_zone.heli_avail or 0) - 1
                    if type(from_zone.drawF10) == "function" then from_zone:drawF10() end
                end
                MissionLogger:info(utils.coalitionToString(side) .." instant-reinforced zone (pre-helicopter era): " .. to_zone.name)
                return true
            end

            local template_name = nil
            if side == coalition.side.RED then
                template_name = GroupData.COMMON_ASSETS.RED.reinforcement_helicopter or GroupData.COMMON_ASSETS.RED.capture_helicopter
            elseif side == coalition.side.BLUE then
                template_name = GroupData.COMMON_ASSETS.BLUE.reinforcement_helicopter or GroupData.COMMON_ASSETS.BLUE.capture_helicopter
            end
            template_name = EraSystem.resolveTaskTemplateName(template_name)

            if not template_name then
                MissionLogger:info("Reinforcement Helo spawn failed: missing template name.")
                return false
            end

            local helo_sent = mist.teleportToPoint({
                groupName = template_name,
                point = from_zone.zone.point,
                action = "clone"
            })

            if not helo_sent then
                MissionLogger:info("Reinforcement Helo spawn failed, no heli sent")
                return false
            end

            EnrouteManager:add({
                group_name = helo_sent.name,
                to_zone = to_zone,
                from_zone = from_zone,
                side = side,
                ai_task_type = AITaskTypes.REINFORCEMENT_HELO,
                aborted = false
            })

            self:setCAPTUREHELITask(helo_sent.name, side, to_zone, from_zone)

            if not (from_zone and from_zone.lha_source) then
                from_zone.heli_avail = (from_zone.heli_avail or 0) - 1
                if from_zone and type(from_zone.drawF10) == "function" then
                    from_zone:drawF10()
                end
            end
            MissionLogger:info(utils.coalitionToString(side) .." reinforcement heli from " .. from_zone.name .. " sent to " .. to_zone.name)
            return true
        end

        return false
    end

    ---@param airbase_zone ZoneHandler|nil
    ---@return boolean
    function TaskManager:isAirbaseRunwayOperational(airbase_zone)
        if not airbase_zone then return false end
        if airbase_zone.zone_type ~= ZoneTypes.AIRBASE then return true end
        if not airbase_zone.isRunwayDisabled then return true end
        return not airbase_zone:isRunwayDisabled()
    end


    --- Returns true if max tasks reached for airbase
    ---@param airbase ZoneHandler
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return boolean
    function TaskManager:checkIfMaxTasksReached(airbase,side,ai_task_type)
        local enroutes_from_airbase = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.CAS,AITaskTypes.CAP,AITaskTypes.SEAD,AITaskTypes.STRIKE,AITaskTypes.RECON,AITaskTypes.AWACS,AITaskTypes.TANKER})
        if not enroutes_from_airbase then return false end

        if #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then return true end

        if ai_task_type == AITaskTypes.CAS then
            local cas_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.CAS})
            if cas_enroutes and #cas_enroutes >= Config.tasking.max_cas_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.CAP then
            local cap_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.CAP})
            if cap_enroutes and #cap_enroutes >= Config.tasking.max_cap_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.SEAD then
            local sead_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.SEAD})
            if sead_enroutes and #sead_enroutes >= Config.tasking.max_sead_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.STRIKE then
            local strike_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.STRIKE})
            if strike_enroutes and #strike_enroutes >= Config.tasking.max_strike_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.RECON then
            local recon_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.RECON})
            if recon_enroutes and #recon_enroutes >= Config.tasking.max_recon_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.AWACS then
            local awacs_enroutes = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.AWACS})
            if awacs_enroutes and #awacs_enroutes >= Config.tasking.max_awacs_per_airbase then
                return true
            end
        elseif ai_task_type == AITaskTypes.TANKER then
            if self:countActiveTankerSectorsFromAirbase(airbase, side) >= (Config.tasking.max_tanker_per_airbase or 2) then
                return true
            end
        end

        return false
    end

    ---@param to_zone ZoneHandler|nil
    ---@param side coalition.side
    ---@param aircraft_type string
    ---@param aircraft_amount number
    ---@param ai_task_type AITaskTypes
    ---@param reference_point vec3|vec2|nil optional point to sort by instead of to_zone (e.g. requesting unit position when there is no target zone)
    ---@return ZoneHandler|nil
    function TaskManager:findClosestAirbaseWithAircraftInStock(to_zone, side, aircraft_type, aircraft_amount, ai_task_type, reference_point)

        -- Loop through all zones, check if in stock and then sort by distance
        local sort_point = reference_point or (to_zone and to_zone.zone.point)
        if not sort_point then return nil end
        local candidates = {}

        for _,zone in ipairs(zones) do
            if zone.zone_type == ZoneTypes.AIRBASE and zone.side == side and zone.airbase_name then
                if self:isAirbaseRunwayOperational(zone)
                and not self:checkIfMaxTasksReached(zone, side, ai_task_type) then
                    local airbase = Airbase.getByName(zone.airbase_name)
                    local warehouse = (airbase and airbase:getCoalition() == side) and airbase:getWarehouse() or nil
                    local aircraft_count = 0

                    if warehouse then
                        local acft_type = WarehouseManager:getAircraftTypeForTask(side, ai_task_type)
                        if acft_type then
                            aircraft_count = warehouse:getItemCount(acft_type)
                        end
                    end

                    local aircraft_reserve = WarehouseManager:getAircraftReserveThreshold()
                    if aircraft_count
                    and math.max(aircraft_count - aircraft_reserve, 0) >= aircraft_amount then
                        table.insert(candidates,{
                            zone = zone,
                            dist = mist.utils.get2DDist(sort_point,zone.zone.point)
                        })
                    end
                end
            end
        end
        table.sort(candidates, function(a, b)
            return a.dist < b.dist
        end)

        if #candidates > 0 then
            return candidates[1].zone
        end
        return nil
    end

    ---@param to_zone ZoneHandler
    ---@param unit_attacking Unit
    function TaskManager:requestNavalStrike(to_zone,unit_attacking)
        if not to_zone or not to_zone.zone then
            MissionLogger:error("Naval strike failed: missing target zone.")
            return false
        end

        if not (unit_attacking and unit_attacking.isExist and unit_attacking:isExist()) then
            MissionLogger:error("Naval strike failed: attacking unit missing or dead.")
            return false
        end

        local desc = unit_attacking:getDesc()
        if not (desc and desc.category == Unit.Category.SHIP) then
            MissionLogger:error("Naval strike failed: attacker is not a ship.")
            return false
        end

        local ship_group = unit_attacking:getGroup()
        if not ship_group then
            MissionLogger:error("Naval strike failed: attacker has no group.")
            return false
        end

        local ship_controller = ship_group:getController()
        if not ship_controller then
            MissionLogger:error("Naval strike failed: ship controller unavailable.")
            return false
        end



        local ship_name = unit_attacking:getName()
        local coalition_side = unit_attacking:getCoalition()

        local salvo_size = Config.naval_ground_strike.naval_strike_salvo_size or 4
        local launch_interval_seconds = Config.naval_ground_strike.naval_strike_launch_interval or 5

        if salvo_size < 1 then
            salvo_size = 1
        end

        -- CruiseMissile weapon flag from DCS weapon flags enum.
        local tomahawk_weapon_flag = 2097152

        ship_controller:setOption(AI.Option.Naval.id.ROE, AI.Option.Naval.val.ROE.OPEN_FIRE)

        local target_points = {}

        -- Units
        for _,gr_name in pairs(to_zone.linked_groups) do
            local gr = Group.getByName(gr_name)
            if gr and gr.isExist and gr:isExist() then
                for _,u in pairs(gr:getUnits()) do
                    table.insert(target_points, mist.utils.makeVec2(u:getPoint()))
                end
            end
        end
        -- Statics
        for _,static_name in pairs(to_zone.linked_statics) do
            local static = StaticObject.getByName(static_name)
            if static and static.isExist and static:isExist() then
                table.insert(target_points, mist.utils.makeVec2(static:getPoint()))
                table.insert(target_points, mist.utils.makeVec2(static:getPoint()))
                -- Some statics require big boom to go down
            end
        end

        utils.shuffleTable(target_points)

        for i = 1, math.max(salvo_size, #target_points) do
            timer.scheduleFunction(function()
                local ship = Unit.getByName(ship_name)
                if not (ship and ship:isExist()) then return end

                local ctrl = ship:getGroup() and ship:getGroup():getController() or nil
                if not ctrl then return end

                local fire_task = {
                    id = 'FireAtPoint',
                    params = {
                        point = target_points[i],
                        radius = 10,
                        expendQty = 1,
                        expendQtyEnabled = true,
                        weaponType = tomahawk_weapon_flag
                    }
                }


                ctrl:pushTask(fire_task)

                MissionLogger:info("Naval strike " .. ship_name .. " launched BGM at " .. to_zone.name .. " (" .. i .. "/" .. salvo_size .. ").")
            end, {}, timer.getTime() + ((i - 1) * launch_interval_seconds))
        end

        trigger.action.outTextForCoalition(coalition_side,"Naval strike initiated, designated area: " .. to_zone.name .. ".", 8)
        trigger.action.outSoundForCoalition(coalition_side, "Radio squelch.ogg")

        return true
    end

    ---@param cap_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setCAPTask(cap_group_name, enroute_data)
        timer.scheduleFunction(function()
            local cap_gr = Group.getByName(cap_group_name)
            if not (cap_gr and cap_gr:isExist() and enroute_data.to_zone) then
                MissionLogger:error("CAP task failed: group or to_zone missing.")
                return false
            end

            local ctrl = cap_gr:getController()

            -- 1. Get the group's current position (at the airbase)
            local startPos = mist.getLeadPos(cap_group_name)
            if not startPos then
                MissionLogger:error("CAP task failed: could not get group position.")
                return false
            end
            
            -- 2. Define the CAP/Intercept tasks
            
            -- Task to engage any enemy aircraft
            local engageTask = {
                id = 'EngageTargets',
                params = {
                    targetTypes = {'Planes', 'Helicopters'},
                    -- Search in a 100km radius around the orbit point
                    maxDist = 100000 
                }
            }

            -- Task to orbit over the target zone
            local orbitTask = {
                id = 'Orbit',
                params = {
                    pattern = 'Circle',
                    point = {
                        x = enroute_data.to_zone.zone.point.x,
                        y = enroute_data.to_zone.zone.point.z
                    },
                    speed = 200, -- m/s
                    altitude = 6096 -- 20k ft
                }
            }

            -- Combine them so the AI orbits AND engages
            local comboTask = {
                id = 'ComboTask',
                params = {
                    tasks = { engageTask, orbitTask }
                }
            }

            -- 3. Build the full 'Mission' wrapper
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF (from current position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- Waypoint 2: CAP ORBIT (Fly to target zone and execute the ComboTask)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = enroute_data.to_zone.zone.point.x,
                y = enroute_data.to_zone.zone.point.z,
                speed = 257, -- m/s (approx 500 kts)
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = 6096, -- 20k ft
                alt_type = AI.Task.AltitudeType.BARO,
                task = comboTask -- Attach the CAP/Engage task
            })

            -- Waypoint 3: LAND (Return to the starting position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })
            
            -- 4. Set the complete mission
            ctrl:setTask(missionTask)

            -- 5. Set the correct AI options (based on Pretense 'setDefaultAA')
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_AG, true)
            ctrl:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE)

            ctrl:setOption(AI.Option.Air.id.JETT_TANKS_IF_EMPTY, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)
            ctrl:setOption(AI.Option.Air.id.MISSILE_ATTACK, AI.Option.Air.val.MISSILE_ATTACK.HALF_WAY_RMAX_NEZ)

            -- RTB on out of Air-to-Air missiles
            local aa_weapons = 268402688  -- AnyMissile
            ctrl:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, aa_weapons)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

            trigger.action.outTextForCoalition(enroute_data.side, "CAP mission tasked for: "..enroute_data.to_zone.name, 10)
            trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("CAP mission tasked, engaging targets near: "..enroute_data.to_zone.name)
        end, {}, timer.getTime() + 12)
    end

    ---@param heli_gr_name string
    ---@param side coalition.side
    ---@param to_zone ZoneHandler
    ---@param from_zone ZoneHandler
    function TaskManager:setCAPTUREHELITask(heli_gr_name,side,to_zone,from_zone)
        local helo_group = Group.getByName(heli_gr_name)
        if not helo_group or not helo_group:isExist() then return end

        -- prevents a potential crash, using delay
        local function startMoving()
            if not (helo_group and helo_group.isExist and helo_group:isExist()) then return end
            local helo_controller = helo_group:getController()
            helo_controller:setTask({
                id = "Land",
                params = {
                    x = to_zone.zone.point.x,
                    y = to_zone.zone.point.z
                }
            })

            helo_controller:setOption(AI.Option.Air.id.REACTION_ON_THREAT,
                AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)

            end
        timer.scheduleFunction(startMoving, {}, timer.getTime() + 14)
    end


    ---@param to_zone ZoneHandler
    ---@param side coalition.side
    ---@param approach_from vec3 where the convoy is coming from (stand-off goes on the near side)
    ---@return table[] waypoints engagement waypoints (empty if nothing to engage)
    function TaskManager:findATTACKCONVOYTasks(to_zone, side, approach_from)
        local enemy_side = utils.getEnemyCoalition(side)
        local targets = {}

        for _, un in ipairs(utils.getUnitsInZoneObj(to_zone, enemy_side)) do
            targets[#targets + 1] = un:getPoint()
        end
        for _, st in ipairs(utils.getStaticsInZoneObj(to_zone)) do
            if st:getCoalition() == enemy_side then
                targets[#targets + 1] = st:getPoint()
            end
        end

        if #targets == 0 then return {} end

        -- Engage the closest targets first, so the convoy advances inward through the zone.
        table.sort(targets, function(a, b)
            return mist.utils.get2DDist(approach_from, a) < mist.utils.get2DDist(approach_from, b)
        end)

        local standoff = Config.attack_convoy_standoff or 50
        local max_targets = Config.attack_convoy_max_targets or 6
        local waypoints = {}
        local prev = approach_from

        for _, tgt in ipairs(targets) do
            if #waypoints >= max_targets then break end

            -- Stop a stand-off distance short of the target, on the approach side.
            local dx, dz = tgt.x - prev.x, tgt.z - prev.z
            local dist = math.sqrt(dx * dx + dz * dz)
            local wp_x, wp_z = prev.x, prev.z
            if dist > standoff then
                wp_x = tgt.x - dx / dist * standoff
                wp_z = tgt.z - dz / dist * standoff
            end

            waypoints[#waypoints + 1] = {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = wp_x,
                y = wp_z,
                speed = 100,
                action = AI.Task.VehicleFormation.OFF_ROAD,
                task = {
                    id = 'FireAtPoint',
                    params = {
                        point = { x = tgt.x, y = tgt.z },
                        radius = 1,
                        expendQty = 10,
                        expendQtyEnabled = true,
                    },
                },
            }
            prev = tgt
        end

        return waypoints
    end

    ---@param convoy_gr_name string
    ---@param side coalition.side
    ---@param to_zone ZoneHandler
    ---@param from_zone ZoneHandler
    function TaskManager:setATTACKCONVOYTask(convoy_gr_name,side,to_zone, from_zone)
        timer.scheduleFunction(function ()
            local convoy_gr = Group.getByName(convoy_gr_name)
            if not convoy_gr or not convoy_gr:isExist() then MissionLogger:info("Capture Convoy spawn failed, no convoy sent") return end

            local ctrl = convoy_gr:getController()
            if ctrl then
                -- Let the convoy engage anything it can see on the way to / inside the zone
                ctrl:setOption(AI.Option.Ground.id.ROE, AI.Option.Ground.val.ROE.OPEN_FIRE)
                ctrl:setOption(AI.Option.Ground.id.ALARM_STATE, AI.Option.Ground.val.ALARM_STATE.RED)
            end

            -- Route on-road toward the zone, then drive up to each defender and engage it
            local gr_pos = mist.getLeadPos(convoy_gr) or to_zone.zone.point
            local engage_waypoints = self:findATTACKCONVOYTasks(to_zone, side, gr_pos)
            self:ConvoyToPoint(convoy_gr, to_zone.zone.point, engage_waypoints)

            EnrouteManager:add({
                group_name = convoy_gr_name,
                to_zone = to_zone,
                from_zone = from_zone,
                side = side,
                ai_task_type = AITaskTypes.ATTACK_CONVOY,
            })

            --- [ check if convoy is moving after 2 mins, if not, respawn it ]
            timer.scheduleFunction(function ()
                if not convoy_gr or not convoy_gr:isExist() then return end
                if not UnitHandler.checkConvoyMoving(convoy_gr) then
                    MissionLogger:info("Convoy:" .. convoy_gr_name .. " not moving")
                    convoy_gr:destroy()

                    from_zone.attack_convoy = from_zone.attack_convoy+1
                    from_zone:drawF10()

                    EnrouteManager:remove(convoy_gr_name)

                end
            end,{},timer.getTime()+120)

        
        end,{},timer.getTime()+5)
    end

    ---@param convoy_gr_name string
    ---@param side number
    ---@param to_zone ZoneHandler
    ---@param from_zone ZoneHandler
    function TaskManager:setCAPTURECONVOYTask(convoy_gr_name, side, to_zone, from_zone)
        timer.scheduleFunction(function ()
            local convoy_gr = Group.getByName(convoy_gr_name)
            if not convoy_gr or not convoy_gr:isExist() then MissionLogger:info("Capture Convoy spawn failed, no convoy sent") return end

            self:ConvoyToPoint(convoy_gr, to_zone.zone.point)

            EnrouteManager:add({
                group_name = convoy_gr_name,
                to_zone = to_zone,
                from_zone = from_zone,
                side = side,
                ai_task_type = AITaskTypes.CAPTURE_CONVOY,
            })

            --- [ if convoy is not moving after 2 mins, refund the slot and remove it ]
            timer.scheduleFunction(function ()
                if not convoy_gr or not convoy_gr:isExist() then return end
                if not UnitHandler.checkConvoyMoving(convoy_gr) then
                    MissionLogger:info("Capture Convoy:" .. convoy_gr_name .. " not moving")
                    convoy_gr:destroy()
                    from_zone.attack_convoy = (from_zone.attack_convoy or 0) + 1
                    from_zone:drawF10()
                    EnrouteManager:remove(convoy_gr_name)
                end
            end,{},timer.getTime()+120)
        end,{},timer.getTime()+5)
    end

    ---@param jtac_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setJTACTask(jtac_group_name,enroute_data)
        timer.scheduleFunction(function()
            local jtac_gr = Group.getByName(jtac_group_name)
            if not (jtac_gr and jtac_gr:isExist() and enroute_data.to_zone) then return end
            local ctrl = jtac_gr:getController()
            if not ctrl then return end

            ctrl:setCommand({
                id = "SetInvisible",
                params = { value = false }
            })

            ctrl:setOption(AI.Option.Air.id.ROE, AI.Option.Air.val.ROE.WEAPON_FREE) --has to be, return fire does not work
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)
            ctrl:setCommand({
                id = "EPLRS",
                params = {
                    value = true,
                    groupId = jtac_gr:getID(),
                }})

            
            ctrl:setTask({
                id = 'Orbit',
                params = {
                    pattern = 'Circle',
                    point = {
                        x = enroute_data.to_zone.zone.point.x+math.random(-300,300),
                        y = enroute_data.to_zone.zone.point.z+math.random(-300,300)},
                    speed = 45, --in m/s
                    altitude = mist.utils.feetToMeters(25000)
                }})

            local jtac = JTAC:new({
                jtac_gr_name = jtac_group_name,
                side = enroute_data.side,
                to_zone = enroute_data.to_zone,
                smoke_count = Config.jtac_smoke_stock,
            })
            enroute_data.jtac = jtac
        end, {}, timer.getTime() + 12)
    end

    ---@param awacs_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setAWACSTask(awacs_group_name, enroute_data)
        timer.scheduleFunction(function()
            local awacs_gr = Group.getByName(awacs_group_name)
            if not (awacs_gr and awacs_gr:isExist()) then return end

            local ctrl = awacs_gr:getController()
            local group_id = awacs_gr:getID()

            -- 1. Get the group's current position (at the airbase)
            local startPos = mist.getLeadPos(awacs_group_name)
            if not startPos then return end
            -- 2. Calculate Racetrack center point (5-15km from base)
            local center_dist = math.random(5000, 12500)
            local center_angle = math.random() * 2 * math.pi
            local racetrack_center = {
                x = startPos.x + center_dist * math.cos(center_angle),
                z = startPos.z + center_dist * math.sin(center_angle)
            }

            -- 3. Calculate the two racetrack points (10km separation)
            local leg_angle = math.random() * 2 * math.pi -- Random orientation for the racetrack
            local distFromCenter = 5000 -- 10km / 2
            local dx = distFromCenter * math.cos(leg_angle)
            local dz = distFromCenter * math.sin(leg_angle)

            local pos1 = { x = racetrack_center.x + dx, y = racetrack_center.z + dz }
            local pos2 = { x = racetrack_center.x - dx, y = racetrack_center.z - dz }

            -- 4. Define the AWACS tasks
            local awacsTask = { id = 'AWACS' }
            
            local eplrsTask = {
                id = "WrappedAction",
                params = {
                    action = {
                        id = "EPLRS",
                        params = { value = true, groupId = group_id }
                    }
                }
            }

            local orbitTask = {
                id = 'Orbit',
                params = {
                    pattern = 'Race-Track',
                    point = pos1,
                    point2 = pos2,
                    speed = 180, -- m/s (~350 kts)
                    altitude = 9144 -- 30k ft
                }
            }
            
            -- Combine them so the AI orbits, enables AWACS, and enables EPLRS
            local comboTask = {
                id = 'ComboTask',
                params = {
                    tasks = { awacsTask, eplrsTask, orbitTask }
                }
            }

            -- 5. Build the full 'Mission' wrapper
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF (from current position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- Waypoint 2: AWACS ORBIT (Fly to the first racetrack point)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = pos1.x,
                y = pos1.y,
                speed = 257, -- m/s (approx 500 kts)
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = 9144, -- 30k ft
                alt_type = AI.Task.AltitudeType.BARO,
                task = comboTask -- Attach the AWACS/Orbit/EPLRS combo task
            })

            -- Waypoint 3: LAND (Return to the starting position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })
            
            -- 6. Set the complete mission
            ctrl:setTask(missionTask)

            -- 7. Set AI options for AWACS
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_AG, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)
            ctrl:setOption(AI.Option.Air.id.JETT_TANKS_IF_EMPTY, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)

            trigger.action.outTextForCoalition(enroute_data.side, "AWACS mission tasked, enroute to station.", 10)
            trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("AWACS mission tasked, establishing orbit.")
        end, {}, timer.getTime() + 12)
    end


    ---@param cas_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setCASTask(cas_group_name,enroute_data)
        timer.scheduleFunction(function()

            local groups_to_attack = enroute_data.to_zone.linked_groups
            if not groups_to_attack or #groups_to_attack == 0 then
                MissionLogger:error("Could not send CAS: No linked enemy groups found in zone "..enroute_data.to_zone.name)
                return false
            end
            local viable_ids ={}
            local target_1_point
            for _,grp_name in ipairs(groups_to_attack) do
                local grp = Group.getByName(grp_name)
                if grp and grp:isExist() then
                    table.insert(viable_ids,grp:getID())
                    if not target_1_point then
                        local u = grp:getUnits()[1]
                        if u and u:isExist() then
                            target_1_point = u:getPoint()
                        end
                    end
                end
            end
            if #viable_ids==0 then
                MissionLogger:error("Could not send CAS: No linked enemy groups exist in zone "..enroute_data.to_zone.name)
                return false
            end

            local cas_gr = Group.getByName(cas_group_name)
            if not (cas_gr and cas_gr:isExist()) then
                MissionLogger:error("Could not send CAS: Group or target ID missing.")
                return false
            end

            local ctrl = cas_gr:getController()

            -- 1. Get the group's current position (at the airbase)
            local startPos = mist.getLeadPos(cas_group_name)
            if not startPos then
                MissionLogger:error("CAS task failed: could not get group position.")
                return false
            end

            -- 2. Calculate the 75% distance Initial Point (IP)
            local diff_x = target_1_point.x - startPos.x
            local diff_z = target_1_point.z - startPos.z
            local ip_pos = {
                x = startPos.x + diff_x * 0.75,
                y = startPos.z + diff_z * 0.75
            }

            local tasks = {}
            for i, target_group_id in ipairs(viable_ids) do
               local attackTask = {
                    enabled = true,
                    auto = false,
                    id = 'AttackGroup',
                    number = i,
                    params = {
                        groupId = target_group_id,
                        groupAttack = true,
                    }
                }
                table.insert(tasks, attackTask)
            end

            local comboTask = {
                id = 'ComboTask',
                params = {
                    tasks = tasks
                }
            }
     
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF (from current position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- WAYPOINT 2: Start attack at 75% of the way to the target, to not start directly above
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = ip_pos.x,
                y = ip_pos.y,
                speed = 200, -- m/s (approx 400 kts)
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = 4000, -- 13k ft
                alt_type = AI.Task.AltitudeType.BARO,
                task = comboTask
            })

            -- Waypoint 3: LAND (Return to the starting position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })
            
            -- 4. Set the complete mission
            ctrl:setTask(missionTask)

            -- 5. Set the correct AI options
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)
            -- ctrl:setOption(AI.Option.Air.id.PROHIBIT_AA, true) -- Prohibit Air-to-Air

            ctrl:setOption(AI.Option.Air.id.JETT_TANKS_IF_EMPTY, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)

            local ag_weapons = 2147485694 + 30720 + 4161536 -- AnyBomb + AnyRocket + AnyASM
            ctrl:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, ag_weapons)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

            trigger.action.outTextForCoalition(enroute_data.side, "CAS mission tasked, engaging: "..enroute_data.to_zone.name,10)
            trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("CAS flight tasked, engaging: "..enroute_data.to_zone.name)
        end, {}, timer.getTime() + 12)
    end

    --- Exactly the same as setCASTask
    ---@param sead_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setSEADTask(sead_group_name, enroute_data)
        timer.scheduleFunction(function()

            -- 1. Validation
            if not enroute_data.to_zone or #enroute_data.to_zone.linked_groups == 0 then return false end

            -- Attributes that make a group a priority SEAD target (radars first)
            local priority_attributes = { 'SAM SR', 'SAM TR' }

            -- Gather all viable target groups, flagging the ones with search/track radars
            local priority_targets = {} -- groups containing SAM SR/TR units
            local other_targets = {}    -- remaining viable groups (launchers, etc.)
            for _, grp_name in ipairs(enroute_data.to_zone.linked_groups) do
                local grp = Group.getByName(grp_name)
                if grp and grp:isExist() then
                    local is_priority = false
                    for _, unit in ipairs(grp:getUnits()) do
                        if unit and unit:isExist() then
                            for _, attr in ipairs(priority_attributes) do
                                if unit:hasAttribute(attr) then
                                    is_priority = true
                                    break
                                end
                            end
                        end
                        if is_priority then break end
                    end
                    if is_priority then
                        table.insert(priority_targets, grp:getID())
                    else
                        table.insert(other_targets, grp:getID())
                    end
                end
            end

            -- Radars first, then everything else
            local viable_ids = {}
            for _, id in ipairs(priority_targets) do table.insert(viable_ids, id) end
            for _, id in ipairs(other_targets) do table.insert(viable_ids, id) end

            if #viable_ids == 0 then
                MissionLogger:error("Could not send SEAD: No linked enemy groups exist in zone "..enroute_data.to_zone.name)
                return false
            end

            local sead_gr = Group.getByName(sead_group_name)
            if not (sead_gr and sead_gr:isExist()) then return false end

            local ctrl = sead_gr:getController()

            -- 2. Calculate Positions
            local startPos = mist.getLeadPos(sead_group_name) -- Current Airbase pos
            if not startPos then return false end
            local targetPos = enroute_data.to_zone.zone.point -- Enemy SAM pos

            -- Calculate vector from Start to Target
            local vecX = targetPos.x - startPos.x
            local vecZ = targetPos.z - startPos.z
            local distance = math.sqrt(vecX^2 + vecZ^2)

            local stand_off_dist = 35000
            local ratio = 0.75

            if distance > stand_off_dist then
                ratio = (distance - stand_off_dist) / distance
            end

            -- This is the "Launch Point" ~25km short of the SAM
            local ipPos = {
                x = startPos.x + (vecX * ratio),
                y = startPos.z + (vecZ * ratio)
            }

            -- 3. Attack Tasks (radars first), combined into a single ComboTask
            local tasks = {}
            for i, target_group_id in ipairs(viable_ids) do
                local attackTask = {
                    enabled = true,
                    auto = false,
                    id = 'AttackGroup',
                    number = i,
                    params = {
                        groupId = target_group_id,
                        groupAttack = true,
                        expend = AI.Task.WeaponExpend.ALL,
                        altitudeEnabled = true,
                        altitude = mist.utils.feetToMeters(30000),
                    }
                }
                table.insert(tasks, attackTask)
            end

            local attackTask = {
                id = 'ComboTask',
                params = {
                    tasks = tasks
                }
            }

            -- 4. Build the Mission
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- Waypoint 2: STANDOFF LAUNCH POINT
            -- The AI flies here. Once reached (or enroute), they execute the 'task'.
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = ipPos.x,
                y = ipPos.y,
                speed = 257, 
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = mist.utils.feetToMeters(30000),
                alt_type = AI.Task.AltitudeType.BARO,
                task = attackTask 
            })

            -- Waypoint 3: LAND 
            -- They will turn back after the attack (or if out of ammo)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- 5. Set Task & Options
            ctrl:setTask(missionTask)

            -- IMPORTANT: Passive Defence allows them to pop flares but MAINTAIN course/lock. 
            -- 'Evade Fire' makes them turn cold immediately, ruining the HARM shot.
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)

            ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)

            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

            trigger.action.outTextForCoalition(enroute_data.side, "SEAD tasked. Engaging from standoff range: "..enroute_data.to_zone.name, 10)
            trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("SEAD engaging " .. enroute_data.to_zone.name .. " from IP distance.")
        end, {}, timer.getTime() + 12)
    end

    --- Exactly the same as setCASTask
    ---@param strike_group_name string
    ---@param enroute_data EnrouteObj
    ---@param target_p vec3
    function TaskManager:setSTRIKETask(strike_group_name,enroute_data,target_p)
        timer.scheduleFunction(function()

            local strike_gr = Group.getByName(strike_group_name)
            if not (strike_gr and strike_gr:isExist() and target_p) then return false end

            local ctrl = strike_gr:getController()

            -- 1. Get the takeoff position from the 'from_zone' (the airbase)
            local startPos = enroute_data.from_zone.zone.point

            -- 2. Calculate the 75% distance Initial Point (IP)
            local diff_x = target_p.x - startPos.x
            local diff_z = target_p.z - startPos.z
            local ip_pos = {
                x = startPos.x + diff_x * 0.75,
                y = startPos.z + diff_z * 0.75
            }


            -- 2. Define the specific 'Bombing' task
            local attackTask = {
                id = 'Bombing',
                params = {
                    point = {
                        x = target_p.x,
                        y = target_p.z
                    },
                    attackQty = 1,
                    ---@diagnostic disable-next-line: undefined-field
                    weaponType = 3221225470 , -- Any weapon

                    expend = AI.Task.WeaponExpend.ALL,
                    groupAttack = true,
                    altitude = 5791, -- 19k ft
                    altitudeEnabled = true,
                }
            }
     
            -- 3. Build the full 'Mission' wrapper (based on Pretense logic)
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true, -- The route is for an airborne group
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF (from the airbase)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO,
                alt=5791
            })

            -- Waypoint 2: BOMBING RUN (Fly to target and execute the attack)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = ip_pos.x,
                y = ip_pos.y,
                speed = 257, -- m/s (approx 500 kts)
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = 5791, -- 19k ft
                alt_type = AI.Task.AltitudeType.BARO,
                task = attackTask 
            })

            -- Waypoint 3: LAND (Return to the original airbase)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- 4. Set the complete mission
            ctrl:setTask(missionTask)

            -- 5. Set the correct AI options
            -- *** DO NOT SET ROE TO WEAPON_FREE ***
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.EVADE_FIRE)
            ctrl:setOption(AI.Option.Air.id.JETT_TANKS_IF_EMPTY, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_JETT, true)

            -- Set RTB on out of Air-to-Ground weapons
            local ag_weapons = 2147485694 + 30720 + 4161536 -- AnyBomb + AnyRocket + AnyASM
            ctrl:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, ag_weapons)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

            MissionLogger:info(ctrl:hasTask())
            trigger.action.outTextForCoalition(enroute_data.side, "STRIKE mission tasked, engaging: "..enroute_data.to_zone.name,10)
            trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("STRIKE mission tasked, engaging: "..enroute_data.to_zone.name)
        end, {}, timer.getTime() + 12)
    end

    ---@param recon_group_name string
    ---@param enroute_data EnrouteObj
    function TaskManager:setRECONTask(recon_group_name, enroute_data)
        timer.scheduleFunction(function()
            local recon_gr = Group.getByName(recon_group_name)
            if not (recon_gr and recon_gr:isExist()) then return end

            local ctrl = recon_gr:getController()

            -- 1. Get the group's current position (at the airbase)
            local startPos = mist.getLeadPos(recon_group_name)
            if not startPos then return end
            
            -- 2. Define the Orbit task
            local orbitTask = {
                id = 'Orbit',
                params = {
                    pattern = 'Circle',
                    point = enroute_data.to_zone.zone.point,
                    speed = 200, -- m/s (~390 kts)
                    altitude = 7620 -- 25k ft
                }
            }
            
            -- 3. Build the full 'Mission' wrapper
            local missionTask = {
                id = 'Mission',
                params = {
                    route = {
                        airborne = true,
                        points = {}
                    }
                }
            }

            -- Waypoint 1: TAKEOFF (from current position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TAKEOFF,
                x = startPos.x,
                y = startPos.z,
                action = AI.Task.TurnMethod.FIN_POINT,
                alt_type = AI.Task.AltitudeType.RADIO
            })

            -- Waypoint 2: RECON ORBIT (Fly to the target zone)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = enroute_data.to_zone.zone.point.x,
                y = enroute_data.to_zone.zone.point.z,
                speed = 257, -- m/s (approx 500 kts)
                action = AI.Task.TurnMethod.FLY_OVER_POINT,
                alt = 7620, -- 25k ft
                alt_type = AI.Task.AltitudeType.BARO,
                --task = orbitTask
            })

            -- Waypoint 3: LAND (Return to the starting position)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.LAND,
                x = startPos.x,
                y = startPos.z,
                speed = 257, -- m/s (approx 500 kts)
                action = AI.Task.TurnMethod.FIN_POINT,
                alt = mist.utils.feetToMeters(21000),
                alt_type = AI.Task.AltitudeType.BARO,
            })
            
            -- 4. Set the complete mission
            ctrl:setTask(missionTask)

            -- 5. Set AI options for RECON
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_AG, true)
            ctrl:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
            ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
            ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

            --trigger.action.outTextForCoalition(enroute_data.side, "RECON flight tasked.", 10)
            --trigger.action.outSoundForCoalition(enroute_data.side, "transmission1.ogg")
            MissionLogger:info("RECON flight tasked to " .. enroute_data.to_zone.name)
        end, {}, timer.getTime() + 12)
    end

    ---@param side coalition.side|nil
    ---@return number
    function TaskManager:countActiveTankerSectors(side)
        local count = 0
        for _, sector in pairs(self.TankerSectors) do
            if sector and sector.active and (not side or sector.side == side) then
                count = count + 1
            end
        end
        return count
    end

    ---@param airbase ZoneHandler
    ---@param side coalition.side
    ---@return number
    function TaskManager:countActiveTankerSectorsFromAirbase(airbase, side)
        local count = 0
        for _, sector in pairs(self.TankerSectors) do
            if sector and sector.active and sector.side == side and sector.from_zone == airbase then
                count = count + 1
            end
        end
        return count
    end

    ---@param sector any
    function TaskManager:drawTankerSector(sector)
        if not sector then return end
        MissionLogger:info("drawing tanker sector")


        sector.mark_ids = sector.mark_ids or { lines = {}, text = nil }

        if sector.mark_ids.text then
            trigger.action.removeMark(sector.mark_ids.text)
            sector.mark_ids.text = nil
        end
        if sector.mark_ids.lines then
            for _, mark_id in ipairs(sector.mark_ids.lines) do
                trigger.action.removeMark(mark_id)
            end
            sector.mark_ids.lines = {}
        end

        local line_color = Config.tanker.line_color
        local text_color = Config.tanker.text_color
        local text_bg = Config.tanker.text_background

        local path_points = utils.buildRoundedRectAroundSegment(
            sector.waypoint_1,
            sector.waypoint_2,
            Config.tanker.sector_width or (24*1000),
            Config.tanker.rounded_corner_radius or 5000,
            Config.tanker.rounded_corner_segments or 5
        )

        for i = 1, #path_points do
            local p1 = path_points[i]
            local p2 = path_points[(i % #path_points) + 1]
            local mark_id = nextMarkId()
            trigger.action.lineToAll(sector.side, mark_id, p1, p2, line_color, utils.LineStyle.DOTTED, true)
            table.insert(sector.mark_ids.lines, mark_id)
        end

        -- [Era] Drogue-only sectors omit the BOOM line so players don't tune a
        -- boom tanker that isn't on station.
        local text_display
        if sector.boom_capable == false then
            text_display = string.format(
                "%s #%d\nDROGUE: %s AM / %sX",
                Config.tanker.text_title or "Tanker Sector",
                sector.serial or 1,
                tostring(sector.frequencies[TankerRoles.DROGUE] or "U"), -- drogue freq
                tostring(sector.tacan[TankerRoles.DROGUE] or "U") -- drogue tacan
            )
        else
            text_display = string.format(
                "%s #%d\nDROGUE: %s AM / %sX\nBOOM: %s AM / %sX",
                Config.tanker.text_title or "Tanker Sector",
                sector.serial or 1,
                tostring(sector.frequencies[TankerRoles.DROGUE] or "U"), -- drogue freq
                tostring(sector.tacan[TankerRoles.DROGUE] or "U"), -- drogue tacan
                tostring(sector.frequencies[TankerRoles.BOOM] or "U"), -- boom freq
                tostring(sector.tacan[TankerRoles.BOOM] or "U") -- boom tacan
            )
        end

        sector.mark_ids.text = nextMarkId()
        trigger.action.textToAll(sector.side, sector.mark_ids.text, sector.center_point, text_color, text_bg, 13, true, text_display)
    end

    ---@param sector any
    ---@param role string
    ---@return table, table
    function TaskManager:getTankerLaneWaypoints(sector, role)
        local p1 = sector.waypoint_1
        local p2 = sector.waypoint_2

        local dx = p2.x - p1.x
        local dz = p2.z - p1.z
        local len = math.sqrt((dx * dx) + (dz * dz))
        if len < 1 then
            return p1, p2
        end

        local nx = -dz / len
        local nz = dx / len
        local edge_inset = Config.tanker.edge_inset
        local max_inset = math.max(0, (len * 0.5) - 1)
        local inset = math.min(edge_inset, max_inset)
        local start_x = p1.x + (dx / len) * inset
        local start_z = p1.z + (dz / len) * inset
        local end_x = p2.x - (dx / len) * inset
        local end_z = p2.z - (dz / len) * inset
        local lane_sep = 3000
        local lane_offset = lane_sep * 0.5
        local sign = role == "drogue" and 1 or -1

        local lane_p1 = {
            x = start_x + (nx * lane_offset * sign),
            y = p1.y,
            z = start_z + (nz * lane_offset * sign)
        }
        local lane_p2 = {
            x = end_x + (nx * lane_offset * sign),
            y = p2.y,
            z = end_z + (nz * lane_offset * sign)
        }

        return lane_p1, lane_p2
    end

---@param sector any
    ---@param role string
    function TaskManager:assignTankerLeg(sector, role)
        if not sector or not sector.active then return end

        local group_name = nil
        if role == TankerRoles.BOOM then
            group_name = sector.boom_group_name
        elseif role == TankerRoles.DROGUE then
            group_name = sector.drogue_group_name
        end

        if not group_name then return end

        local tanker_group = Group.getByName(group_name)
        if not (tanker_group and tanker_group:isExist()) then return end
        MissionLogger:info("Assigning tanker legs")

        local ctrl = tanker_group:getController()
        if not ctrl then return end

        local role_config = role == "boom" and (Config.tanker.boom or {}) or (Config.tanker.drogue or {})
        local altitude = mist.utils.feetToMeters(role_config.altitude_ft or 22000)
        local lane_wp1, lane_wp2 = self:getTankerLaneWaypoints(sector, role)

        local orbit_point = role == "drogue" and lane_wp1 or lane_wp2
        local orbit_point2 = role == "drogue" and lane_wp2 or lane_wp1

        local clock_wise = true
        if role == TankerRoles.BOOM then
            clock_wise = false
        end

        local freq = sector.frequencies[TankerRoles.BOOM]*1e6
        if role == TankerRoles.DROGUE then
            freq = sector.frequencies[TankerRoles.DROGUE]*1e6
        end
        local tacan = sector.tacan[TankerRoles.BOOM]
        if role == TankerRoles.DROGUE then
            tacan = sector.tacan[TankerRoles.DROGUE]
        end

        local tankerTask = { id = 'Tanker', params = {} }
            
        local eplrsTask = {
            id = "WrappedAction",
            params = {
                action = {
                    id = "EPLRS",
                    params = { value = true, groupId = tanker_group:getID() }
                }
            }
        }

        local frequencyTask = {
            id = 'SetFrequency',
            params = {
                frequency = freq,
                modulation = radio.modulation.AM,
                power = 50,
            }
        }
        local tacanTask = {
            id = "ActivateBeacon",
            params = {
                type = 4, -- TACAN
                AA = true,
                unitId = tanker_group:getID(),
                modeChannel = "X",
                channel = tacan,
                system = 4,
                callsign = "TKR",
                bearing = true,
                frequency = math.random(1000e6,2000e6)

            }
        }


        local orbitTask = {
           id = 'Orbit',
            params = {
                pattern = AI.Task.OrbitPattern.RACE_TRACK,
                point = mist.utils.makeVec2(orbit_point2),
                point2= mist.utils.makeVec2(orbit_point),
                speed = role_config.speed, --in m/s
                altitude = altitude,
                clockWise = clock_wise
            }
        }
        
        local comboTask = {
            id = 'ComboTask',
            params = {
                tasks = { tankerTask, eplrsTask, orbitTask }
            }
        }
        ctrl:setCommand(frequencyTask)
        ctrl:setCommand(tacanTask)
        ctrl:setTask(comboTask)

        ctrl:setOption(AI.Option.Air.id.PROHIBIT_AG, true)
        ctrl:setOption(AI.Option.Air.id.PROHIBIT_AA, true)
        ctrl:setOption(AI.Option.Air.id.REACTION_ON_THREAT, AI.Option.Air.val.REACTION_ON_THREAT.PASSIVE_DEFENCE)
        ctrl:setOption(AI.Option.Air.id.RTB_ON_BINGO, true)

        sector.last_task_time = sector.last_task_time or {}
        sector.last_task_time[role] = timer.getTime()
        MissionLogger:info("Tanker legs assigned")

    end

    ---@param sector_id string
    ---@param destroy_groups boolean|nil
    function TaskManager:cleanupTankerSectorById(sector_id, destroy_groups)
        local sector = self.TankerSectors[sector_id]
        if not sector then return end

        sector.active = false

        if sector.mark_ids then
            if sector.mark_ids.text then
                trigger.action.removeMark(sector.mark_ids.text)
            end
            if sector.mark_ids.lines then
                for _, mark_id in ipairs(sector.mark_ids.lines) do
                    trigger.action.removeMark(mark_id)
                end
            end
        end

        if destroy_groups then
            local boom_group = Group.getByName(sector.boom_group_name or "")
            if boom_group and boom_group:isExist() then
                boom_group:destroy()
            end

            local drogue_group = Group.getByName(sector.drogue_group_name or "")
            if drogue_group and drogue_group:isExist() then
                drogue_group:destroy()
            end
        end

        for i = #EnrouteManager.enroutes, 1, -1 do
            local enroute = EnrouteManager.enroutes[i]
            if enroute
            and enroute.ai_task_type == AITaskTypes.TANKER
            and enroute.tanker_sector_id == sector_id then
                table.remove(EnrouteManager.enroutes, i)
            end
        end

        self.TankerSectors[sector_id] = nil
    end

    function TaskManager:checkTankerSectors()
        local sectors_to_cleanup = {}

        for sector_id, sector in pairs(self.TankerSectors) do
            if sector and sector.active then
                local drogue_group = Group.getByName(sector.drogue_group_name or "")
                local drogue_ok = drogue_group and drogue_group:isExist()

                -- [Era] A drogue-only sector has no boom group; only require the
                -- boom to exist when the sector is boom-capable.
                local boom_ok = true
                if sector.boom_capable ~= false then
                    local boom_group = Group.getByName(sector.boom_group_name or "")
                    boom_ok = boom_group and boom_group:isExist()
                end

                if not (drogue_ok and boom_ok) then
                    table.insert(sectors_to_cleanup, sector_id)
                end
            else
                table.insert(sectors_to_cleanup, sector_id)
            end
        end

        for _, sector_id in ipairs(sectors_to_cleanup) do
            self:cleanupTankerSectorById(sector_id, true)
        end
    end

    ---@param convoy_group Group
    ---@param arrival_point vec3
    ---@param engage_waypoints table[]|nil optional engagement waypoints appended after the approach
    function TaskManager:ConvoyToPoint(convoy_group,arrival_point,engage_waypoints)
        local gr_pos = mist.getLeadPos(convoy_group)
        if not gr_pos then return end
        local roadless = false
        if mist.utils.get2DDist(gr_pos,arrival_point) < 2500 then roadless = true end

        --closest point to closest zone
        local arrival_road_x, arrival_road_y = land.getClosestPointOnRoads('roads', arrival_point.x,
        arrival_point.z)

        --closest to convoy
        local start_road_x, start_road_y = land.getClosestPointOnRoads('roads', gr_pos.x, gr_pos.z)

        local points = {
            [1] = { type = AI.Task.WaypointType.TURNING_POINT, x = gr_pos.x, y = gr_pos.z, speed = 100, action = AI.Task.VehicleFormation.OFF_ROAD }
        }
        if not roadless and start_road_x and start_road_y and arrival_road_x and arrival_road_y then
            points[2] = {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = start_road_x,
                y = start_road_y,
                speed = 100,
                action =
                    AI.Task.VehicleFormation.ON_ROAD
            }
            points[3] = {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = arrival_road_x,
                y = arrival_road_y,
                speed = 100,
                action =
                    AI.Task.VehicleFormation.ON_ROAD
            }
            points[4] = {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = arrival_point.x,
                y = arrival_point.z,
                speed = 100,
                action = AI.Task.VehicleFormation.OFF_ROAD
            }
        else
            -- roadless fallback
            points[2] = {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = arrival_point.x,
                y = arrival_point.z,
                speed = 100,
                action = AI.Task.VehicleFormation.OFF_ROAD
            }
        end

        if engage_waypoints then
            for _, wp in ipairs(engage_waypoints) do
                points[#points + 1] = wp
            end
        end

        convoy_group:getController():setTask({ id = 'Mission', params = { route = { points = points } } })
    end

    ---@param min_Mhz number
    ---@param max_Mhz number
    ---@param c number|nil
    function TaskManager:createFrequency(min_Mhz,max_Mhz,c)
        if not c then c=0 end
        if c>1000 then return min_Mhz end
        local freq = math.random(min_Mhz,max_Mhz)
        if not TaskManager.assignedFrequencies[utils.MHztoHz(freq)] then
            table.insert(TaskManager.assignedFrequencies,freq )
            return freq
        end
        return TaskManager:createFrequency(min_Mhz,max_Mhz,c+1)
    end

    ---@param min_ch number
    ---@param max_ch number
    ---@param c number|nil
    function TaskManager:createTACAN(min_ch,max_ch,c)
        if not c then c=0 end
        if c>1000 then return min_ch end
        local ch = math.random(min_ch,max_ch)
        if not TaskManager.assignedTACANS[ch] then
            TaskManager.assignedTACANS[ch] = true
            return ch
        end
        return TaskManager:createTACAN(min_ch,max_ch,c+1)

    end

end