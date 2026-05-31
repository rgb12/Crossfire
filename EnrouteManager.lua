
---@class EnrouteObj
---@field from_zone ZoneHandler
---@field to_zone ZoneHandler
---@field side coalition.side
---@field ai_task_type AITaskTypes
---@field group_name string
---@field jtac JTAC|nil
---@field aborted boolean|nil for aboted heli
---@field redirects_count number|nil for attack convoy
---@field stuck_since number|nil timestamp when the enroute got stuck
---@field tanker_sector_id string|nil
---@field tanker_role string|nil
---@field last_pos vec3|nil last observed position for landing checks
---@field last_pos_time number|nil timestamp of last observed position
---@field landed_candidate_since number|nil timestamp when landing conditions started
---@field has_been_airborne boolean|nil true after the heli has lifted off at least once

---@class EnrouteManager
---@field enroutes EnrouteObj[]
EnrouteManager = {}
do
    EnrouteManager.enroutes = {}

    ---Add an object to enroute list
    ---@param obj EnrouteObj
    ---@return EnrouteObj
    function EnrouteManager:add(obj)
        table.insert(self.enroutes, obj)
        return obj
    end

    ---Remove an enroute by group name
    ---@param group_name string
    function EnrouteManager:remove(group_name)
        for i, enroute in ipairs(self.enroutes) do
            if enroute.group_name == group_name then
                
                if enroute.ai_task_type == AITaskTypes.JTAC and enroute.jtac then
                    missionCommands.removeItemForCoalition(enroute.jtac.side, enroute.jtac.jtac_menu)
                    enroute.jtac.jtac_menu = nil
                end

                table.remove(self.enroutes, i)
                
                MissionLogger:info("EnrouteManager: Removed "..enroute.ai_task_type.." from enroutes: " .. group_name)
                return true
            end
        end
        return false
    end
    
    ---Find an enroute by group name
    ---@param group_name string
    ---@return EnrouteObj|nil
    function EnrouteManager:findByGroup(group_name)
        for _, enroute in ipairs(self.enroutes) do
            if enroute.group_name == group_name then
                return enroute
            end
        end
        return nil
    end
    
    ---Find all enroutes going to a specific zone
    ---@param zone ZoneHandler
    ---@param side coalition.side|nil
    ---@param ai_task_type AITaskTypes[]|nil
    ---@return EnrouteObj[]|nil
    function EnrouteManager:findByToZone(zone,side,ai_task_type)
        local results = {}
        for i, enroute in ipairs(self.enroutes) do
            if enroute.to_zone == zone then

                ---@type EnrouteObj|nil
                local candidate = enroute

                if side and side ~= enroute.side then
                    candidate = nil
                end

                if ai_task_type and not utils.tableContains(ai_task_type,enroute.ai_task_type) then
                    candidate = nil
                end

                if candidate then
                    table.insert(results,candidate)
                end

            end
        end
        if #results == 0 then return nil end --WARN changing the return nil to {} will cause issues
        return results
    end
    
    ---Find all enroutes coming from a specific zone
    ---@param zone ZoneHandler
    ---@param side coalition.side|nil
    ---@param ai_task_types AITaskTypes[]|nil
    ---@return EnrouteObj[]|nil
    function EnrouteManager:findByFromZone(zone,side,ai_task_types)
        local results = {}
        for i, enroute in ipairs(self.enroutes) do
            if enroute.from_zone == zone then

                ---@type EnrouteObj|nil
                local candidate = enroute

                if side and side ~= enroute.side then
                    candidate = nil
                end

                if ai_task_types and not utils.tableContains(ai_task_types, enroute.ai_task_type) then
                    candidate = nil
                end

                if candidate then
                    table.insert(results,candidate)
                end

            end
        end
        if #results == 0 then return nil end
        return results
    end

    ---@param ai_task_type AITaskTypes 
    ---@param side coalition.side|nil
    ---@return EnrouteObj[]
    function EnrouteManager:findByTaskType(ai_task_type,side)
        local results = {}
        for i, enroute in ipairs(self.enroutes) do
            if enroute.ai_task_type == ai_task_type then

                ---@type EnrouteObj|nil
                local candidate = enroute

                if side and side ~= enroute.side then
                    candidate = nil
                end

                if candidate then
                    table.insert(results,candidate)
                end

            end
        end
        return results
    end

    function EnrouteManager:checkEnroutes()
        local enroutes = self.enroutes
        for i = #enroutes, 1, -1 do
            local enroute = enroutes[i]
            if not enroute then
                table.remove(enroutes, i)
            else
                local grp = Group.getByName(enroute.group_name)
                if not grp or not grp:isExist() then
                    if enroute.ai_task_type == AITaskTypes.JTAC and enroute.jtac then
                        missionCommands.removeItemForCoalition(enroute.jtac.side, enroute.jtac.jtac_menu)
                        enroute.jtac.jtac_menu = nil
                    end

                    table.remove(enroutes, i)
                    MissionLogger:info("EnrouteManager: Removed "..enroute.ai_task_type.." from enroutes: " .. enroute.group_name)
                end
            end
        end
    end

    ---Handle AI helicopter landing logic (event + periodic check)
    ---@param enroute_heli EnrouteObj
    ---@param unit Unit
    ---@param group_pos vec3
    function EnrouteManager:handleHeloLanding(enroute_heli, unit, group_pos)
        if not enroute_heli or not unit or not unit.isExist or not unit:isExist() then return end

        local group_name = enroute_heli.group_name
        local landed_pos = group_pos or unit:getPoint()

        -- ABORTED HELI
        if enroute_heli.aborted and landed_pos then
            local landed_in_source = false
            if enroute_heli.from_zone and type(enroute_heli.from_zone.isPointInsideZone) == "function" then
                landed_in_source = enroute_heli.from_zone:isPointInsideZone(landed_pos)
            elseif enroute_heli.from_zone and enroute_heli.from_zone.lha_source then
                local lha_unit = Unit.getByName(enroute_heli.from_zone.name)
                if lha_unit and lha_unit:isExist() then
                    local lpt = lha_unit:getPoint()
                    if lpt then
                        local d = mist.utils.get2DDist(lpt, landed_pos)
                        if d and d < 500 then landed_in_source = true end
                    end
                end
            end
            if landed_in_source then
                EnrouteManager:remove(group_name)
                MissionLogger:info("Removed LANDED aborted heli from enroutes: " .. group_name)
                timer.scheduleFunction(function ()
                    unit:getGroup():destroy()
                end, {}, timer.getTime() + 10)

                if enroute_heli.from_zone.heli_avail and enroute_heli.side == unit:getCoalition() and not enroute_heli.from_zone.lha_source then
                    MissionLogger:info("Adding back heli to zone: " .. enroute_heli.from_zone.name)
                    enroute_heli.from_zone.heli_avail = enroute_heli.from_zone.heli_avail + 1
                    if type(enroute_heli.from_zone.drawF10) == "function" then
                        enroute_heli.from_zone:drawF10()
                    end
                end
                return
            end
        end

        if enroute_heli.ai_task_type == AITaskTypes.CAPTURE_HELO then
            TheatreCommander.checkIfCaptureGroupArrived(enroute_heli)
        elseif enroute_heli.ai_task_type == AITaskTypes.REINFORCEMENT_HELO then
            local zone_coal_check = ZoneHandler.getFromName(enroute_heli.to_zone.name)

            if zone_coal_check
            and zone_coal_check.side == enroute_heli.side
            and landed_pos
            and zone_coal_check:isPointInsideZone(landed_pos)
            then
                if (zone_coal_check.level or 1) < 4 then
                    zone_coal_check.level = (zone_coal_check.level or 1) + 1
                    zone_coal_check.next_level_up_avail = timer.getTime() + (Config.logistics_level_up_interval or (16 * 60))
                    UnitHandler.updateZoneUnits(zone_coal_check)
                    zone_coal_check:drawF10()

                    trigger.action.outTextForCoalition(enroute_heli.side,
                        string.format("SITREP: %s has reached operational tier %d/4 ", zone_coal_check.name, zone_coal_check.level), 10)
                    trigger.action.outSoundForCoalition(enroute_heli.side, "radio_beep3.ogg")
                end

                EnrouteManager:remove(group_name)
            end
        end

        timer.scheduleFunction(function ()
            unit:getGroup():destroy()
        end, {}, timer.getTime() + 10)
    end

    ---Periodic AI helicopter landing check for slope cases
    function EnrouteManager:checkAiHeloLandings()
        local enroutes = self.enroutes
        if #enroutes == 0 then return end

        local now = timer.getTime()
        for i = #enroutes, 1, -1 do
            local enroute = enroutes[i]
            if enroute
            and (enroute.ai_task_type == AITaskTypes.CAPTURE_HELO or enroute.ai_task_type == AITaskTypes.REINFORCEMENT_HELO or enroute.aborted) then
                local grp = Group.getByName(enroute.group_name)
                if grp and grp.isExist and grp:isExist() then
                    local unit = grp:getUnit(1)
                    local is_player = unit and unit.getPlayerName and unit:getPlayerName()

                    if unit and unit.isExist and unit:isExist()
                    and not is_player
                    and unit.getDesc and unit:getDesc().category == Unit.Category.HELICOPTER
                    then
                        local pos = unit:getPoint()
                        if pos then
                            if not enroute.has_been_airborne then
                                if unit:inAir() then
                                    enroute.has_been_airborne = true
                                else
                                    enroute.landed_candidate_since = nil
                                    enroute.last_pos = { x = pos.x, y = pos.y, z = pos.z }
                                    enroute.last_pos_time = now
                                end
                            end

                            if enroute.has_been_airborne then
                                local ground = land.getHeight({x = pos.x, y = pos.z})
                                local agl = pos.y - ground
                                local last_pos = enroute.last_pos
                                local handled = false

                                if last_pos then
                                    local dx = pos.x - last_pos.x
                                    local dz = pos.z - last_pos.z
                                    local dist_sq = (dx * dx) + (dz * dz)

                                    if dist_sq <= 100 and agl <= 5 then
                                        enroute.landed_candidate_since = enroute.landed_candidate_since or now
                                        if (now - enroute.landed_candidate_since) >= 15 then
                                            MissionLogger:info("AI Helicopter " .. enroute.group_name .. " considered landed")
                                            self:handleHeloLanding(enroute, unit, pos)
                                            handled = true
                                        end
                                    else
                                        enroute.landed_candidate_since = nil
                                    end
                                end

                                if not handled then
                                    enroute.last_pos = { x = pos.x, y = pos.y, z = pos.z }
                                    enroute.last_pos_time = now
                                end
                            end
                        end
                    end
                end
            end
        end
    end

end