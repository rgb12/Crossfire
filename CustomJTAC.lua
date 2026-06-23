--- Parts of this code belongs to Dzsekeb's very well designed JTAC

local used_jtac_callsign_index = 1

---@class JTACLasers
---@field laser Spot|nil
---@field ir Spot|nil

---@class JTAC
---@field jtac_gr_name string
---@field callsigns string[]|nil
---@field callsign string|nil
---@field side coalition.side
---@field to_zone ZoneHandler
---@field priority string|nil
---@field lasers JTACLasers|nil
---@field smoke_count number
---@field viable_targets Unit[]|nil
---@field jtac_main_submenu table|nil
---@field jtac_menu table|nil
JTAC = {}
do
    JTAC.callsigns = {
        [1] = "Havoc 1-1",
        [2] = "Reaper 2-1",
        [3] = "Viper 3-2",
        [4] = "Warhammer 3-1",
        [5] = "Spectre 1-2",
        [6] = "Raptor 5-1",
        [7] = "Falcon 2-2",
        [8] = "Talon 3-1",
        [9] = "Grizzly 4-2",
        [10] = "Raven 5-2"
    }

    JTAC.categories = {}
    JTAC.categories['SAM'] = {'SAM SR', 'SAM TR', 'IR Guided SAM','SAM LL','SAM CC'}
    JTAC.categories['Infantry'] = {'Infantry'}
    JTAC.categories['Armor'] = {'Tanks','IFV','APC'}
    JTAC.categories['Support'] = {'Unarmed vehicles','Artillery'}
    JTAC.categories['Structures'] = {'Buildings'}

    ---@return JTAC
    function JTAC:new(obj)
        obj = obj or {}
        obj.callsign = obj.callsign or JTAC.callsigns[used_jtac_callsign_index]
        obj.smoke_count = Config.jtac_smoke_stock
        ---@type JTACLasers
        obj.lasers = {}
        obj.viable_targets = {}
        obj.jtac_main_submenu = CommandHandler.jtac_main_submenu
        if not obj.to_zone or not obj.side then return MissionLogger:error("Missing field(s) for JTAC") end

        setmetatable(obj, self)
        self.__index = self
        
        used_jtac_callsign_index = (used_jtac_callsign_index % #JTAC.callsigns) + 1
        trigger.action.outSoundForCoalition(obj.side, "transmission1.ogg")
        trigger.action.outTextForCoalition(obj.side, obj.callsign.." JTAC on station at "..obj.to_zone.name..".", 10)
        
        obj:setupCommands()

        -- Auto-start targeting after a short delay to allow unit to settle
        timer.scheduleFunction(function(jtac_obj)
            if jtac_obj and jtac_obj.searchTarget then
                jtac_obj:searchTarget(false) -- Allow first search to speak if empty
                jtac_obj:startLasing(1688)
                jtac_obj:startAutoLoop() -- Start the status monitor
            end
        end, obj, timer.getTime() + 50)

        return obj
    end

    function JTAC:startAutoLoop()
        timer.scheduleFunction(function(jtac_obj)
            local jtac_gr = Group.getByName(jtac_obj.jtac_gr_name)
            if not jtac_gr or not jtac_gr:isExist() then return end

            local zone = ZoneHandler.getFromName(jtac_obj.to_zone.name)
            if not zone then return end
            if zone.side == jtac_obj.side or zone.side == coalition.side.NEUTRAL then
                EnrouteManager:remove(jtac_obj.jtac_gr_name)
                jtac_obj:destroy()
                timer.scheduleFunction(function ()
                    trigger.action.outTextForCoalition(jtac_obj.side, jtac_obj.callsign.." JTAC: RTB", 10)
                    trigger.action.outSoundForCoalition(jtac_obj.side,"radio_beep4.ogg")
                end, {}, timer.getTime() + 10)
                return
            end

            if jtac_obj.target then
                if not jtac_obj.target:isExist() or jtac_obj.target:getLife() < 1 then
                    --trigger.action.outTextForCoalition(jtac_obj.side, jtac_obj.callsign.." JTAC: Target destroyed.", 10)
                    jtac_obj:clearTarget()
                    jtac_obj:searchTarget(true)
                    jtac_obj:startLasing(1688)
                end
            else
                -- No target currently selected, try to find one
                jtac_obj:searchTarget(true)
                if jtac_obj.target then
                    jtac_obj:startLasing(1688)
                end
            end

            return timer.getTime() + 10
        end, self, timer.getTime() + 10)
    end

    function JTAC:startLasing(code)
        local jtac_gr = Group.getByName(self.jtac_gr_name)
        if not (jtac_gr and jtac_gr:isExist() and self.to_zone) then return end
        local unit = jtac_gr:getUnit(1)

        if unit and unit.isExist and unit:isExist() and unit:inAir() then
            if not self.target then return end

            self.laser_code = code or 1688

            if self.lasers.laser then self.lasers.laser:destroy() end
            if self.lasers.ir then self.lasers.ir:destroy() end

            self.lasers.laser = Spot.createLaser(unit,{ x = 0, y = 1, z = 0 },self.target:getPoint(), self.laser_code)
            self.lasers.ir = Spot.createInfraRed(unit, { x = 0, y = 1, z = 0 }, self.target:getPoint())
    
            ---@type string
            local target_name = self.target:getTypeName()
            if target_name:sub(1,1) == "." then target_name = target_name:sub(2) end

            trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC targeting ".. target_name .."\nLaser Code: "..self.laser_code, 10)
            trigger.action.outSoundForCoalition(self.side, "radio_beep4.ogg")
        end
    end

    function JTAC:clearTarget()
        self.target = nil
    
        if self.lasers.laser then
            self.lasers.laser:destroy()
            self.lasers.laser = nil
        end
        
        if self.lasers.ir then
            self.lasers.ir:destroy()
            self.lasers.ir = nil
        end
    end

    function JTAC:setTarget(unit)
        self:clearTarget()
        self.target = unit
    end
    function JTAC:searchTarget(quiet)

        self.viable_targets = {}
        self.priority_targets = {}
    
        local zone = ZoneHandler.getFromName(self.to_zone.name)
        if not zone then return end
        for _,gr_name in pairs(zone.linked_groups) do
            local gr = Group.getByName(gr_name)
            if gr and gr:isExist() then
                for _,unit in pairs(gr:getUnits()) do
                    if unit and unit.isExist and unit:isExist() and unit:getLife() >= 1 and unit:isActive() then
                        if unit:getCoalition() ~= self.side then
                            --table.insert(self.units_in_zone, unit)
                            table.insert(self.viable_targets,unit)
                        end
                    end
                end
            end
        end
        for _,static_name in pairs(zone.linked_statics) do
            local static = StaticObject.getByName(static_name)
            if static and static.isExist and static:isExist() then
                if static:getCoalition() ~= self.side then
                    table.insert(self.viable_targets,static)
                end
            end
        end

        -- Build priority_targets if priority is set
        if self.priority then
            for _,unit in ipairs(self.viable_targets) do
                for _,priority in ipairs(self.categories[self.priority]) do
                    if unit:hasAttribute(priority) then
                        table.insert(self.priority_targets, unit)
                        break
                    end
                end
            end
        end
    
        -- Choose which list to use for targeting
        local target_list = self.viable_targets -- Default to all
        
        if self.priority then
            if #self.priority_targets > 0 then
                target_list = self.priority_targets
            else
                trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC: No targets found for priority '"..self.priority.."'. Engaging targets of opportunity.", 5)
                self.priority = nil
            end
        end
    
        -- Set or wrap search_index
        if not self.search_index or self.search_index > #target_list then
            self.search_index = 1
        end
    
        if #target_list == 0 then
            self.target = nil
            if not quiet then
                trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC: No targets found at ".. self.to_zone.name..", standing by.", 10)
            end
        elseif target_list then
            self:setTarget(target_list[self.search_index])
        end
    end

    function JTAC:destroy()
        if self.jtac_gr_name then
            local jtac_gr = Group.getByName(self.jtac_gr_name)
            if jtac_gr and jtac_gr:isExist() then
                jtac_gr:destroy()
            end
        end

        self:clearTarget()

        if self.jtac_menu then
            missionCommands.removeItemForCoalition(self.side, self.jtac_menu)
            self.jtac_menu = nil
        end
        self.target = nil
        self.viable_targets = {}
    end

    function JTAC:setupCommands()
        if CommandHandler.jtac_submenu[self.side] == nil then
            CommandHandler.jtac_submenu[self.side] = missionCommands.addSubMenuForCoalition(self.side,"JTAC", nil)
        end
        self.jtac_menu = missionCommands.addSubMenuForCoalition(self.side, self.callsign..' JTAC '..self.to_zone.name,CommandHandler.jtac_submenu[self.side])

        missionCommands.addCommandForCoalition(self.side, "Next Target", self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            local u = jtac_gr and jtac_gr:getUnit(1)
            if u and u:inAir() then

                jtac:searchTarget(false)

                -- Determine which list we are using
                local target_list = jtac.viable_targets
                if jtac.priority and #jtac.priority_targets > 0 then
                    target_list = jtac.priority_targets
                end

                if #target_list > 0 then
                    jtac.search_index = (jtac.search_index or 1) + 1
                    if jtac.search_index > #target_list then jtac.search_index = 1 end

                    jtac:setTarget(target_list[jtac.search_index])
                    jtac:startLasing(1688)
                else
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: No targets available', 10)
                end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end, self)

        missionCommands.addCommandForCoalition(self.side,"Request 9-Line",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            local u = jtac_gr and jtac_gr:getUnit(1)
            if u and u:inAir() then
                if not jtac.target or not jtac.target:isExist() then
                    jtac:searchTarget(false)
                    if jtac.target then jtac:startLasing(1688) end
                end

                if not jtac.target then
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC scanning... No targets locked.', 10)
                end

                local toprint = jtac.callsign.." JTAC\n"
                if jtac.priority then toprint = toprint..'Priority: '..jtac.priority..'\n' end

                ---@type string
                local target_name = jtac.target:getTypeName()
                if target_name:sub(1,1) == "." then target_name = target_name:sub(2) end

                toprint = toprint..'Target: '.. target_name ..'\n'
                toprint = toprint..'Laser Code: '..jtac.laser_code..'\n'

                local lat,lon,alt = coord.LOtoLL(jtac.target:getPoint())
                local mgrs = coord.LLtoMGRS(coord.LOtoLL(jtac.target:getPoint()))
                toprint = toprint..'\nDDM:  '.. mist.tostringLL(lat,lon,3)
                toprint = toprint..'\nDMS:  '.. mist.tostringLL(lat,lon,2,true)
                toprint = toprint..'\nMGRS: '.. mist.tostringMGRS(mgrs, 5)
                toprint = toprint..'\nAlt: '..math.floor(alt)..'m'..' | '..math.floor(alt*3.280839895)..'ft'

                trigger.action.outTextForCoalition(jtac.side, toprint, 20)

            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)

        missionCommands.addCommandForCoalition(self.side, "Intelligence Report", self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            local u = jtac_gr and jtac_gr:getUnit(1)
            if u and u:inAir() then
                local zone = ZoneHandler.getFromName(jtac.to_zone.name)
                if not zone then return end

                local outtxt = jtac.callsign.." JTAC Intelligence Report\n"
                outtxt = outtxt.."Zone: "..jtac.to_zone.name.."\n\n"
                
                local unit_count = 0
                local unit_types = {}
                
                for _,gr_name in pairs(zone.linked_groups) do
                    local gr = Group.getByName(gr_name)
                    if gr and gr:isExist() then
                        for _,unit in pairs(gr:getUnits()) do
                            if unit and unit.isExist and unit:isExist() and unit:getLife() >= 1 then
                                local type_name = unit:getTypeName()
                                unit_types[type_name] = (unit_types[type_name] or 0) + 1
                                unit_count = unit_count + 1
                            end
                        end
                    end
                end
                for _,static_name in pairs(zone.linked_statics) do
                    local static_obj = StaticObject.getByName(static_name)
                    if static_obj and static_obj.isExist and static_obj:isExist() then
                        unit_types["Structure"] = (unit_types["Structure"] or 0) + 1
                        unit_count = unit_count + 1
                    end
                end
                
                if unit_count == 0 then
                    outtxt = outtxt.."Area appears clear. No enemy contacts."
                else
                    outtxt = outtxt.."Visual confirmation of hostiles in AO:\n"
                    for type_name, count in pairs(unit_types) do
                        if count == 1 then
                            outtxt = outtxt.."- "..type_name.."\n"
                        else
                            outtxt = outtxt.."- "..count.."x "..type_name.."\n"
                        end
                    end
                end

                trigger.action.outTextForCoalition(jtac.side, outtxt, 15)
                trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)

        missionCommands.addCommandForCoalition(self.side, "Mark Target (Red)",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            local u = jtac_gr and jtac_gr:getUnit(1)
            if u and u:inAir() then
                if not (jtac.target and jtac.target:isExist()) then 
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: No active target for smoke.', 5)
                end

                if self.smoke_count <= 0 then
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Out of smoke canisters.', 5)
                end

                if u and mist.utils.get2DDist(u:getPoint(), jtac.target:getPoint()) < 20000 then
                    self.smoke_count = self.smoke_count -1
                    trigger.action.smoke(jtac.target:getPosition().p, trigger.smokeColor.Red)
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign.." JTAC: RED smoke marker in effect ("..self.smoke_count.." left)", 10)
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                else
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Too far to deploy smoke accurately.', 10)
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)

        missionCommands.addCommandForCoalition(self.side, "RTB",self.jtac_menu, function (jtac)
            EnrouteManager:remove(jtac.jtac_gr_name)
            jtac:destroy()
        end,self)

        -- enables the player to designate a category as priority
        local priority_menu = missionCommands.addSubMenuForCoalition(self.side, "Set Priority", self.jtac_menu)
        for category_name, _ in pairs(self.categories) do
            missionCommands.addCommandForCoalition(self.side, category_name, priority_menu, function(jtac)
                local jtac_gr = Group.getByName(jtac.jtac_gr_name)
                local u = jtac_gr and jtac_gr:getUnit(1)
                if u and u:inAir() then
                    jtac.priority = category_name
                    jtac.search_index = 1 -- Reset index on priority switch

                    local out_text = jtac.callsign .. " JTAC priority updated: " .. category_name
                    trigger.action.outTextForCoalition(jtac.side, out_text, 5)
               
                    jtac:clearTarget()
                    jtac:searchTarget(false)
                    jtac:startLasing(1688)
                else
                    missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                    jtac.jtac_menu = nil
                end
            end,self)
        end
        missionCommands.addCommandForCoalition(self.side, "Clear Priority", priority_menu, function(jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            local u = jtac_gr and jtac_gr:getUnit(1)
            if u and u:inAir() then
                jtac.priority = nil
                jtac.search_index = 1 -- Reset index on priority switch
                trigger.action.outTextForCoalition(jtac.side, jtac.callsign .. " JTAC priority cleared.", 5)
                trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
           
                jtac:clearTarget()
                jtac:searchTarget(false)
                jtac:startLasing(1688)
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)
    end
end