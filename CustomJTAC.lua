--- Parts of this code belongs to Dzsek’s very well designed JTAC

enroute_jtac = {} --TO CHANGE
pending_jtac_zones = {} --TO CHANGE
used_jtac_callsign_index = 1 --TO CHANGE

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
	JTAC.categories['Structures'] = {'StaticObjects'}

    ---@return JTAC
    function JTAC:new(obj)
        obj = obj or {}
        obj.callsign = obj.callsign or JTAC.callsigns[used_jtac_callsign_index]
        obj.smoke_count = Config.jtac_smoke_stock
        ---@type JTACLasers
        obj.lasers = {}
        obj.viable_targets = {}
        obj.jtac_main_submenu = CommandHandler.jtac_main_submenu
        if not obj.to_zone
        or not obj.side then return MissionLogger:error("Missing field(s) for JTAC") end

        setmetatable(obj, self)
		self.__index = self
        
        used_jtac_callsign_index = (used_jtac_callsign_index % #JTAC.callsigns) + 1
        trigger.action.outTextForCoalition(obj.side, obj.callsign.." JTAC tasked, enroute to "..obj.to_zone.name,10)
        obj:setupCommands()

        return obj
    end

    function JTAC:startLasing(code)
        local jtac_gr = Group.getByName(self.jtac_gr_name)
        if not (jtac_gr and jtac_gr:isExist() and self.to_zone) then return end
        local unit = jtac_gr:getUnit(1)

        if unit and unit:isExist() and unit:inAir() then
            if not self.target then return end

            self.laser_code = code or math.random(1111,1788)
            self.lasers.laser = Spot.createLaser(unit,{ x = 0, y = 1, z = 0 },self.target:getPoint(), self.laser_code)
            self.lasers.ir = Spot.createInfraRed(unit, { x = 0, y = 1, z = 0 }, self.target:getPoint())
    
            trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC lasing target, code: "..self.laser_code,3)
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
		
		if self.lasers.laser then
			self.lasers.laser:destroy()
			self.lasers.laser = nil
		end
		
		if self.lasers.ir then
			self.lasers.ir:destroy()
			self.lasers.ir = nil
		end

		self.target = unit
        trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC: Target selected.",3)
	end

    function JTAC:searchTarget()
        MissionLogger:info("Searching targets")
    
        self.viable_targets = {}
        self.priority_targets = {}
    
        -- Get enemy units in zone
        if self.side == coalition.side.RED then
            self.units_in_zone = mist.getUnitsInZones(mist.makeUnitTable({'[blue]'}), {self.to_zone.name})
        elseif self.side == coalition.side.BLUE then
            self.units_in_zone = mist.getUnitsInZones(mist.makeUnitTable({'[red]'}), {self.to_zone.name})
        end
    
        -- Filter for alive units
        for _,unit in ipairs(self.units_in_zone) do
            if unit and unit:isExist() and unit:getLife() >= 1 then
                table.insert(self.viable_targets,unit)
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
        local target_list = self.priority and self.priority_targets or self.viable_targets
    
        -- Set or wrap search_index
        if not self.search_index or self.search_index > #target_list then
            self.search_index = 1
        end
    
        if target_list and #target_list == 0 then
            self.target = nil
            trigger.action.outTextForCoalition(self.side,"JTAC: No targets found at ".. self.to_zone.name..".",5)
        elseif target_list and #target_list > 0 then
            self:setTarget(target_list[self.search_index])
        end
    end


    function JTAC:RTB()
        local jtac_gr = Group.getByName(self.jtac_gr_name)
        if not (jtac_gr and jtac_gr:isExist() and self.to_zone) then return end

        local ctrl = jtac_gr:getController()

        ctrl:resetTask()
        MissionLogger:info(ctrl:hasTask())
        trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC RTB ("..blue_airbase.name..")",10)
    
        missionCommands.removeItemForCoalition(self.side, self.jtac_menu)
        self.jtac_menu = nil
    end

    function JTAC:setupCommands()

        self.jtac_menu = missionCommands.addSubMenuForCoalition(self.side, self.callsign..' JTAC '..self.to_zone.name,nil)

        self.select_target_menu = missionCommands.addCommandForCoalition(self.side,"Select target / Start lasing",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            if jtac_gr then

                if self.target then return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Target already selected, check JTAC Status.', 10) end
                if jtac_gr:getUnit(1):inAir() then
                    if not self.target and mist.utils.get3DDist(self.to_zone.zone.point,jtac_gr:getUnit(1):getPoint()) < 15000 then
                        jtac:searchTarget()
                        jtac:startLasing(1686)
                        missionCommands.removeItemForCoalition(jtac.side, jtac.select_target_menu)
                    else
                        trigger.action.outTextForCoalition(self.side,self.callsign.." JTAC is out of range",10)
                    end
                else trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5) end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)

        missionCommands.addCommandForCoalition(self.side, "Next target", self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            if jtac_gr then
                if jtac_gr:getUnit(1):inAir() then
                    if not self.target then return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: No selected target.', 10) end
        
                    jtac:clearTarget()

                    jtac:searchTarget()
                    local target_list = jtac.priority and jtac.priority_targets or jtac.viable_targets
                    MissionLogger:info("Target list")
                    MissionLogger:info(target_list)

                    if target_list and #target_list > 0 then
                        if #target_list == 1 then
                            jtac.search_index = 1
                            
                        else
                            jtac.search_index = (jtac.search_index or 1) + 1
                            if jtac.search_index > #target_list then jtac.search_index = 1 end
                        end

                        jtac:setTarget(target_list[jtac.search_index])
                        jtac:startLasing(1686)
                    end
                else
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5)
                end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end, self)

        missionCommands.addCommandForCoalition(self.side,"JTAC target data",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            if jtac_gr then
                if jtac_gr:getUnit(1):inAir() then
                    if not self.target or not self.target:isExist() then return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is standing by for orders.', 10) end


                    local toprint = self.callsign.." JTAC\n"
                    if self.priority then toprint = toprint..'Priority targets: '..self.priority..'\n' end

                    
                    toprint = toprint..'Lasing at '..self.to_zone.name..'\nCode: '..self.laser_code..'\n'
                    local lat,lon,alt = coord.LOtoLL(self.target:getPoint())
                    local mgrs = coord.LLtoMGRS(coord.LOtoLL(self.target:getPoint()))
                    toprint = toprint..'\nDDM:  '.. mist.tostringLL(lat,lon,3)
                    toprint = toprint..'\nDMS:  '.. mist.tostringLL(lat,lon,2,true)
                    toprint = toprint..'\nMGRS: '.. mist.tostringMGRS(mgrs, 5)
                    toprint = toprint..'\nAlt: '..math.floor(alt)..'m'..' | '..math.floor(alt*3.280839895)..'ft'

                    trigger.action.outTextForCoalition(jtac.side, toprint, 20)

                else trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5) end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
        end,self)

        missionCommands.addCommandForCoalition(self.side, "Deploy smoke",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            if jtac_gr then
                if jtac_gr:getUnit(1):inAir() then
                    if not (jtac.target and jtac.target:isExist()) then 
                        return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Current target not found or selected.', 5)
                    end
                    if self.smoke_count <= 0 then
                        return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Out of stock.', 5)
                    else
                        self.smoke_count = self.smoke_count -1
                    end


                        if mist.utils.get2DDist(jtac_gr:getUnit(1):getPoint(), jtac.target:getPoint()) < 15000 then
                            trigger.action.smoke(jtac.target:getPosition().p, 1)
                            trigger.action.outTextForCoalition(jtac.side, jtac.callsign.." JTAC: Target marked with RED smoke. ("..self.smoke_count.."/"..Config.jtac_smoke_stock..")", 10)
                        else
                            trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Target is not in range.', 10)
                        end
                    
                else
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5)
                end
            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
                
        end,self)

        missionCommands.addCommandForCoalition(self.side, "RTB",self.jtac_menu, function (jtac)
            local jtac_gr = Group.getByName(jtac.jtac_gr_name)
            if jtac_gr then
                if not jtac_gr:getUnit(1):inAir() then
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5)
                end

                jtac:RTB()

            else
                missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                jtac.jtac_menu = nil
            end
                
        end,self)


        -- enables the player to designate a category as priority
        local priority_menu = missionCommands.addSubMenuForCoalition(self.side, "Set priority", self.jtac_menu)
        for category_name, _ in pairs(self.categories) do
            missionCommands.addCommandForCoalition(self.side,category_name,priority_menu,function(jtac)
                local jtac_gr = Group.getByName(jtac.jtac_gr_name)
                if jtac_gr then
                    if jtac_gr:getUnit(1):inAir() then
                        jtac.priority = category_name
    
    
                        local out_text = jtac.callsign .. " JTAC priority set to: " .. category_name
                        if not self.target then
                            out_text = out_text.."\nSelect target to start lasing"
                            return trigger.action.outTextForCoalition(jtac.side,out_text,5)

                        end
                        trigger.action.outTextForCoalition(jtac.side,out_text,2)
                   
                        jtac:searchTarget()
                        jtac:startLasing(1686)
    
                    else
                        trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC is not airborne.', 5)

                    end


                else
                    missionCommands.removeItemForCoalition(jtac.side, jtac.jtac_menu)
                    jtac.jtac_menu = nil
                end
            end,self)
        end
    end
end