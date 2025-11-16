
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

end