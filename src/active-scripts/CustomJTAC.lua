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
---@field priority_targets Unit[]|nil
---@field target Unit|StaticObject|nil
---@field laser_code number|nil
---@field search_index number|nil
---@field is_destroyed boolean true once the JTAC has been torn down
---@field jtac_main_submenu table|nil
---@field group_menus table<number, table> this JTAC's F10 menu path, per player group id
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
        obj.smoke_count = obj.smoke_count or Config.jtac_smoke_stock
        ---@type JTACLasers
        obj.lasers = {}
        obj.viable_targets = {}
        obj.priority_targets = {}
        obj.is_destroyed = false
        obj.group_menus = {}
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
            if jtac_obj.is_destroyed then return end
            jtac_obj:searchTarget(false) -- Allow first search to speak if empty
            jtac_obj:startLasing(1688)
            jtac_obj:startAutoLoop() -- Start the status monitor
        end, obj, timer.getTime() + 50)

        return obj
    end

    --- The JTAC aircraft, or nil once it no longer exists (shot down, crashed, despawned)
    ---@return Unit|nil
    function JTAC:getUnit()
        if self.is_destroyed or not self.jtac_gr_name then return nil end
        local jtac_gr = Group.getByName(self.jtac_gr_name)
        if not (jtac_gr and jtac_gr:isExist()) then return nil end
        local unit = jtac_gr:getUnit(1)
        if not (unit and unit.isExist and unit:isExist()) then return nil end
        return unit
    end

    --- The JTAC aircraft, but only while it is airborne and able to work
    ---@return Unit|nil
    function JTAC:getAirborneUnit()
        local unit = self:getUnit()
        if unit and unit:inAir() then return unit end
        return nil
    end

    function JTAC:startAutoLoop()
        timer.scheduleFunction(function(jtac_obj)
            if jtac_obj.is_destroyed then return end

            if not jtac_obj:getUnit() then
                -- Aircraft is gone without a death event having reached us
                jtac_obj:reportLost()
                return
            end

            local zone = ZoneHandler.getFromName(jtac_obj.to_zone.name)
            if not zone then return timer.getTime() + 10 end
            if zone.side == jtac_obj.side or zone.side == coalition.side.NEUTRAL then
                -- Nothing left to work on: recall the JTAC and hand the tasking supplies back
                jtac_obj:rtb(10)
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
        local unit = self:getAirborneUnit()
        if not (unit and self.to_zone and self.target) then return end

        self.laser_code = code or 1688

        self:destroyLasers()

        self.lasers.laser = Spot.createLaser(unit,{ x = 0, y = 1, z = 0 },self.target:getPoint(), self.laser_code)
        self.lasers.ir = Spot.createInfraRed(unit, { x = 0, y = 1, z = 0 }, self.target:getPoint())

        ---@type string
        local target_name = self.target:getTypeName()
        if target_name:sub(1,1) == "." then target_name = target_name:sub(2) end

        trigger.action.outTextForCoalition(self.side, self.callsign.." JTAC targeting ".. target_name .."\nLaser Code: "..self.laser_code, 10)
        trigger.action.outSoundForCoalition(self.side, "radio_beep4.ogg")
    end

    --- Shut down the laser and IR spots. Wrapped in pcall so a spot whose emitting
    --- unit already died can never break the rest of the teardown.
    function JTAC:destroyLasers()
        self.lasers = self.lasers or {}
        for key, spot in pairs(self.lasers) do
            if spot then pcall(function() spot:destroy() end) end
            self.lasers[key] = nil
        end
    end

    function JTAC:clearTarget()
        self.target = nil
        self:destroyLasers()
    end

    function JTAC:setTarget(unit)
        self:clearTarget()
        self.target = unit
    end
    function JTAC:searchTarget(quiet)
        if self.is_destroyed then return end

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

    --- Is any JTAC still on station for that coalition? Used to know when the
    --- JTAC root menu can go away.
    ---@param side coalition.side
    ---@param ignored JTAC|nil JTAC left out of the count, typically one being torn down
    ---@return boolean
    function JTAC.anyActiveForSide(side, ignored)
        for _, enroute in ipairs(EnrouteManager.enroutes) do
            if enroute.ai_task_type == AITaskTypes.JTAC and enroute.jtac and enroute.jtac ~= ignored
            and enroute.jtac.side == side and not enroute.jtac.is_destroyed then
                return true
            end
        end
        return false
    end

    --- Every group of that coalition currently occupied by a player
    ---@param side coalition.side
    ---@return Group[]
    function JTAC.getPlayerGroups(side)
        local groups = {}
        local seen = {}
        for _, unit in pairs(coalition.getPlayers(side) or {}) do
            if unit and unit.isExist and unit:isExist() and unit.getGroup then
                local gr = unit:getGroup()
                if gr and gr.isExist and gr:isExist() then
                    local gr_id = gr:getID()
                    if gr_id and not seen[gr_id] then
                        seen[gr_id] = true
                        table.insert(groups, gr)
                    end
                end
            end
        end
        return groups
    end

    ---@param gr_id number
    function JTAC.forgetGroupMenus(gr_id)
        if not gr_id then return end
        for _, roots_by_group in pairs(CommandHandler.jtac_submenu) do
            roots_by_group[gr_id] = nil
        end
        for _, enroute in ipairs(EnrouteManager.enroutes) do
            if enroute.ai_task_type == AITaskTypes.JTAC and enroute.jtac and enroute.jtac.group_menus then
                enroute.jtac.group_menus[gr_id] = nil
            end
        end
    end

    function JTAC:removeCommands()
        self.group_menus = self.group_menus or {}
        for gr_id, menu_path in pairs(self.group_menus) do
            missionCommands.removeItemForGroup(gr_id, menu_path)
            self.group_menus[gr_id] = nil
        end

        if JTAC.anyActiveForSide(self.side, self) then return end

        for gr_id, root_menu in pairs(CommandHandler.jtac_submenu[self.side] or {}) do
            missionCommands.removeItemForGroup(gr_id, root_menu)
            CommandHandler.removeTrackedMenuPath(gr_id, root_menu)
            CommandHandler.jtac_submenu[self.side][gr_id] = nil
        end
    end

    function JTAC:destroy()
        if self.is_destroyed then return end
        self.is_destroyed = true -- every scheduled callback bails out on this flag

        self:clearTarget()
        self:removeCommands()

        if self.jtac_gr_name then
            -- Cannot recurse back into destroy(): is_destroyed is already set
            EnrouteManager:remove(self.jtac_gr_name)

            local jtac_gr = Group.getByName(self.jtac_gr_name)
            if jtac_gr and jtac_gr:isExist() then
                jtac_gr:destroy()
            end
        end

        self.viable_targets = {}
        self.priority_targets = {}

        MissionLogger:info("JTAC "..tostring(self.callsign).." removed from "..tostring(self.to_zone and self.to_zone.name))
    end

    --- A recalled JTAC hands its tasking cost to the closest friendly airbase that can
    --- store it, which is also where a replacement would be tasked from.
    ---@return number refunded supplies actually credited back
    ---@return ZoneHandler|nil airbase that received them
    function JTAC:refundSupplies()
        local cost = Config.supplies.tasking_costs.JTAC or 0
        if cost <= 0 or not self.to_zone then return 0, nil end

        local airbase = self.to_zone:getClosestZone(self.side, nil, {ZoneTypes.AIRBASE})
        if not airbase or airbase.ammo_depot_intact ~= true then return 0, nil end

        local cap = (Config.supplies.supplies_cap and Config.supplies.supplies_cap[airbase.level or 1]) or 0
        local before = airbase.local_supplies or 0
        airbase.local_supplies = math.min(before + cost, cap)

        return airbase.local_supplies - before, airbase
    end

    --- Recall the JTAC: refund the tasking supplies and stand it down.
    ---@param message_delay number|nil seconds before the RTB call goes out (default: at once)
    function JTAC:rtb(message_delay)
        if self.is_destroyed then return end -- also keeps the refund to a single payout
        local side, callsign = self.side, self.callsign
        local refunded, refund_airbase = self:refundSupplies()

        self:destroy()

        local out_text = callsign.." JTAC: RTB"
        if refunded > 0 and refund_airbase then
            out_text = out_text.."\n Supplies returned to "..refund_airbase.name.."."
        end

        local function callRTB()
            trigger.action.outTextForCoalition(side, out_text, 10)
            trigger.action.outSoundForCoalition(side, "radio_beep4.ogg")
        end

        if message_delay and message_delay > 0 then
            timer.scheduleFunction(callRTB, {}, timer.getTime() + message_delay)
        else
            callRTB()
        end
    end

    --- A lost JTAC never comes home, so its tasking supplies are not refunded
    function JTAC:reportLost()
        if self.is_destroyed then return end
        local side, callsign = self.side, self.callsign

        self:destroy()

        trigger.action.outTextForCoalition(side, "SITREP: Lost contact with JTAC "..callsign, 10)
        trigger.action.outSoundForCoalition(side, "radio_beep3.ogg")
    end


    ---@param group_name string|nil
    ---@return boolean handled true when the group was a tracked JTAC
    function JTAC.reportLostByGroup(group_name)
        if not group_name then return false end
        local enroute = EnrouteManager:findByGroup(group_name)
        if not (enroute and enroute.ai_task_type == AITaskTypes.JTAC and enroute.jtac) then return false end
        enroute.jtac:reportLost()
        return true
    end

    ---@param side coalition.side
    ---@param gr_id number
    ---@return table menu path
    local function groupRootMenu(side, gr_id)
        local roots_by_group = CommandHandler.jtac_submenu[side]
        if not roots_by_group then
            roots_by_group = {}
            CommandHandler.jtac_submenu[side] = roots_by_group
        end

        if not roots_by_group[gr_id] then
            roots_by_group[gr_id] = missionCommands.addSubMenuForGroup(gr_id, "JTAC", nil)
            -- Tracked so the group teardown on slot change takes it down with the rest
            CommandHandler.addToMenuTracking(gr_id, roots_by_group[gr_id], "jtac")
        end
        return roots_by_group[gr_id]
    end

    ---@param gr Group
    ---@param side coalition.side|nil the group's coalition, read from the group when omitted
    function JTAC:setupCommandsForGroup(gr, side)
        if self.is_destroyed then return end
        if not gr or not gr.isExist or not gr:isExist() then return end

        local gr_id = gr:getID()
        if not gr_id then return end
        if (side or gr:getCoalition()) ~= self.side then return end

        self.group_menus = self.group_menus or {}
        if self.group_menus[gr_id] then return end -- already built for that group

        local jtac_menu = missionCommands.addSubMenuForGroup(gr_id, self.callsign..' JTAC '..self.to_zone.name, groupRootMenu(self.side, gr_id))
        self.group_menus[gr_id] = jtac_menu
        MissionLogger:info("JTAC "..tostring(self.callsign).." menu built for group "..tostring(gr:getName()).." ("..gr_id..")")

        missionCommands.addCommandForGroup(gr_id, "Next Target", jtac_menu, function (jtac)
            if jtac:getAirborneUnit() then

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
                jtac:destroy()
            end
        end, self)

        missionCommands.addCommandForGroup(gr_id, "Request 9-Line", jtac_menu, function (jtac)
            if jtac:getAirborneUnit() then
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
                jtac:destroy()
            end
        end,self)

        missionCommands.addCommandForGroup(gr_id, "Intelligence Report", jtac_menu, function (jtac)
            if jtac:getAirborneUnit() then
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

                trigger.action.outTextForCoalition(jtac.side, outtxt, 10)
                trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
            else
                jtac:destroy()
            end
        end,self)

        missionCommands.addCommandForGroup(gr_id, "Mark Target (Red)", jtac_menu, function (jtac)
            local u = jtac:getAirborneUnit()
            if u then
                if not (jtac.target and jtac.target:isExist()) then
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: No active target for smoke.', 5)
                end

                if jtac.smoke_count <= 0 then
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                    return trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Out of smoke canisters.', 5)
                end

                if mist.utils.get2DDist(u:getPoint(), jtac.target:getPoint()) < 20000 then
                    jtac.smoke_count = jtac.smoke_count -1
                    trigger.action.smoke(jtac.target:getPosition().p, trigger.smokeColor.Red)
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign.." JTAC: Smoke marker in effect, "..jtac.smoke_count.." left in stock", 10)
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                else
                    trigger.action.outTextForCoalition(jtac.side, jtac.callsign..' JTAC: Too far to deploy smoke accurately.', 10)
                    trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")
                end
            else
                jtac:destroy()
            end
        end,self)

        missionCommands.addCommandForGroup(gr_id, "RTB", jtac_menu, function (jtac)
            jtac:rtb()
        end,self)

        -- enables the player to designate a category as priority
        local priority_menu = missionCommands.addSubMenuForGroup(gr_id, "Set Priority", jtac_menu)
        for category_name, _ in pairs(self.categories) do
            missionCommands.addCommandForGroup(gr_id, category_name, priority_menu, function(jtac)
                if jtac:getAirborneUnit() then
                    jtac.priority = category_name
                    jtac.search_index = 1 -- Reset index on priority switch

                    local out_text = jtac.callsign .. " JTAC priority updated: " .. category_name
                    trigger.action.outTextForCoalition(jtac.side, out_text, 5)

                    jtac:clearTarget()
                    jtac:searchTarget(false)
                    jtac:startLasing(1688)
                else
                    jtac:destroy()
                end
            end,self)
        end
        missionCommands.addCommandForGroup(gr_id, "Clear Priority", priority_menu, function(jtac)
            if jtac:getAirborneUnit() then
                jtac.priority = nil
                jtac.search_index = 1 -- Reset index on priority switch
                trigger.action.outTextForCoalition(jtac.side, jtac.callsign .. " JTAC priority cleared.", 5)
                trigger.action.outSoundForCoalition(jtac.side, "radio_beep4.ogg")

                jtac:clearTarget()
                jtac:searchTarget(false)
                jtac:startLasing(1688)
            else
                jtac:destroy()
            end
        end,self)
    end

    function JTAC:setupCommands()
        for _, gr in ipairs(JTAC.getPlayerGroups(self.side)) do
            self:setupCommandsForGroup(gr, self.side)
        end
    end

    ---@param gr Group
    ---@param side coalition.side
    function JTAC.buildMenusForGroup(gr, side)
        if not gr or not gr.isExist or not gr:isExist() then return end

        local built = 0
        for _, enroute in ipairs(EnrouteManager.enroutes) do
            local jtac = enroute.jtac
            if enroute.ai_task_type == AITaskTypes.JTAC and jtac
            and jtac.side == side and not jtac.is_destroyed then
                jtac:setupCommandsForGroup(gr, side)
                built = built + 1
            end
        end

        MissionLogger:info("JTAC menus rebuilt for group "..tostring(gr:getName())..": "..built.." JTAC(s) on station")
    end
end