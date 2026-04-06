if not __MARK_ID__ then __MARK_ID__ = 600000 end
function nextMarkId()
    __MARK_ID__ = __MARK_ID__ + 1
    return __MARK_ID__
end




---@class ZoneHandler
---@field name string
---@field side coalition.side|nil
---@field level number|nil
---@field sam_classification string|nil
---@field zone ZoneObj
---@field zone_type ZoneTypes
---@field linked_groups string[]
---@field linked_statics string[]
---@field airbase_name string|nil
---@field comms_tower_intact boolean|nil
---@field linked_comms_tower string|nil
---@field cmdc_intact boolean|nil
---@field linked_farp string|nil
ZoneHandler = {}
do
    function ZoneHandler:new(obj)
        obj = obj or {}
        obj.zone = ZoneHandler.findZoneInWorld(obj.name)
        obj.linked_groups = obj.linked_groups or {}
        obj.linked_statics = obj.linked_statics or {}

        if not obj.zone then 
            MissionLogger:error("ZoneHandler:new Could not find zone "..obj.name.." in mission triggers zones")
            return 
        end

        if obj.zone_type == ZoneTypes.SAMSITE then
            if not obj.sam_classification then 
                MissionLogger:error("ZoneHandler:new Missing/Incorrect fields - SAMSITE zone "..obj.name)
                return end
        end

        if obj.zone_type == ZoneTypes.LOGISTICS then
            if not obj.next_level_up_avail then
                obj.next_level_up_avail = timer.getTime()
            end
            obj.ammo_depot_intact = false
            obj.capture_heli_avail = obj.capture_heli_avail or 0
        end

        if obj.zone_type == ZoneTypes.STRONGPOINT then
            obj.attack_convoy = obj.attack_convoy or 0
        end

        if obj.zone_type == ZoneTypes.AIRBASE and obj.cmdc_intact == nil then
            obj.cmdc_intact = true
        end


        setmetatable(obj, self)
        self.__index = self

        -- Draw the zone, fillcolor=color
        -- if not obj.panel_only then
        --     --obj:drawF10(true)
        -- else
        --     -- obj.zone:drawF10(0, false)
        --     local marker_text = string.format("%s - Coalition %s\nCapture Helicopters: %d\nCapture Convoys: %d",
        --         obj.zone.name,
        --         utils.coalitionToString(obj.side),
        --         obj.capture_heli_avail or 0,
        --     trigger.action.markToAll(obj.zone.id, marker_text, obj.zone.point, true)
        -- end

        -- change airbase coalition based on zone

        -- checks for good zones declarations
        


        if obj.zone_type == ZoneTypes.AIRBASE and obj.airbase_name then
            local airbase = Airbase.getByName(obj.airbase_name)
            if airbase then
                airbase:autoCapture(false)
                airbase:setCoalition(obj.side)
            else
                MissionLogger:error("ZoneHandler:new - AIRBASE zone "..obj.name.." could not find airbase "..obj.airbase_name)
            end

        end


        return obj
    end
    --- Finds a zone in the mission triggers by name and returns a ZoneObj
    ---@class ZoneObj
    ---@field name string
    ---@field id number
    ---@field type number
    ---@field radius number|nil
    ---@field point vec3
    ---@field vertices vec3[]
    ---@param zone_name string
    ---@return ZoneObj|nil
    function ZoneHandler.findZoneInWorld(zone_name)
        local obj = {} -- Local declaration of obj
        obj.name = zone_name

        local zone_find = nil
        local zone_id = nil
        for k, v in ipairs(env.mission.triggers.zones) do
            if v.name == zone_name then
                zone_find = v
                zone_id = k
                break
            end
        end

        if not zone_find then
            return nil
        end

        obj.id = zone_id
        obj.type = zone_find.type -- 2 == quad, 0 == circle
        if obj.type == 2 then
            obj.vertices = {}
            for _, v in ipairs(zone_find.verticies) do
                local vertex = {
                    x = v.x,
                    y = 0,
                    z = v.y
                }
                table.insert(obj.vertices, vertex)
            end
        end

        obj.radius = zone_find.radius

        if obj.radius < 1000 then
            MissionLogger:warn(zone_name.." has a radius smaller than 1000 meters. This may cause issues.")
        end

        -- Converts the mission's file Vec2 points into Vec3
        -- Vec2: {x,y}  --> Vec3: {x, land height at (x,y), y}
        -- Be careful DCS uses Z as Y axis in 3D space (vec3)
        obj.point = {
            x = zone_find.x,
            y = land.getHeight({x=zone_find.x,y=zone_find.y}),
            z = zone_find.y
        }
        return obj
    end

    ---@param addtional_text string|nil
    function ZoneHandler:drawF10(addtional_text)
        -- 1. Define Color Palettes
        -- [Area Border, Area Fill, Text, Text Background]
        local red_palette = Config.draw_color_palette.red_palette
        local blue_palette = Config.draw_color_palette.blue_palette
        local neutral_palette = Config.draw_color_palette.neutral_palette
        
        -- Set default colors to neutral
        local border_color = neutral_palette[1]
        local fill_color   = neutral_palette[2]
        local text_color   = neutral_palette[3]
        local text_bg      = neutral_palette[4]
        local text_display = self.name
    
        if self.side == coalition.side.RED then
            border_color = red_palette[1]
            fill_color   = red_palette[2]
            text_color   = red_palette[3]
            text_bg      = red_palette[4]
        elseif self.side == coalition.side.BLUE then
            border_color = blue_palette[1]
            fill_color   = blue_palette[2]
            text_color   = blue_palette[3]
            text_bg      = blue_palette[4]
        end
        
        -- 2. Build Display Text
        if self.zone_type == ZoneTypes.STRONGPOINT then
            text_display = text_display .. "\nSTRONGPOINT"
            text_display = text_display .. "\nAttack Convoys: " .. (self.attack_convoy or 0)
        elseif self.zone_type == ZoneTypes.LOGISTICS then
            text_display = text_display .. "\nLOGISTICS"
            text_display = text_display .. "\nCapture Helicopters: " .. (self.capture_heli_avail or 0)
        elseif self.zone_type == ZoneTypes.FARP then
            text_display = text_display .. "\nFARP"
        elseif self.zone_type == ZoneTypes.SAMSITE then
            text_display = text_display .. "\nSAM SITE"
        elseif self.zone_type == ZoneTypes.EWSITE then
            text_display = text_display .. "\nEW SITE"
        elseif self.zone_type == ZoneTypes.AIRBASE then
            text_display = text_display .. "\nAIRBASE"
        elseif self.zone_type == ZoneTypes.COMMS then
            text_display = text_display .. "\nCOMMS"
        end
    
        text_display = text_display.."\nT:"..(self.level or 1).."/4"
    
        if addtional_text then
            text_display = text_display .. "\n" .. addtional_text
        end

        -- 3. Cleanup Old Marks
        self._markIds = self._markIds or {
            blue=nil, blueText=nil,
            red=nil,  redText=nil,
            neutral=nil, neutralText=nil
        }
    
        if self._markIds.blue         then trigger.action.removeMark(self._markIds.blue) end
        if self._markIds.blueText     then trigger.action.removeMark(self._markIds.blueText) end
        if self._markIds.red          then trigger.action.removeMark(self._markIds.red) end
        if self._markIds.redText      then trigger.action.removeMark(self._markIds.redText) end
        if self._markIds.neutral      then trigger.action.removeMark(self._markIds.neutral) end
        if self._markIds.neutralText  then trigger.action.removeMark(self._markIds.neutralText) end
    
        -- 4. Draw New Marks
        if self.side == coalition.side.NEUTRAL then
    
            local nCircleId = nextMarkId()
            local nTextId   = nextMarkId()
    
            if self:isCircle() then
                trigger.action.circleToAll(-1, nCircleId, self.zone.point, self.zone.radius, border_color, fill_color, 1, true)
            elseif self:isQuad() then
                trigger.action.quadToAll(-1, nCircleId, self.zone.vertices[4], self.zone.vertices[3],
                    self.zone.vertices[2], self.zone.vertices[1], border_color, fill_color, 1, true)
            end
            trigger.action.textToAll(-1, nTextId, self.zone.point, text_color, text_bg, 13, true, text_display)
    
            self._markIds.neutral = nCircleId
            self._markIds.neutralText = nTextId
        else
            -- Draw for BLUE coalition (if they discovered it)
            if utils.tableContains(stats.blue_discovered_zones, self.zone.name) then
    
                local bCircleId = nextMarkId()
                local bTextId   = nextMarkId()

                if self:isCircle() then
                    trigger.action.circleToAll(coalition.side.BLUE, bCircleId, self.zone.point, self.zone.radius, border_color, fill_color, 1, true)
                elseif self:isQuad() then
                    trigger.action.quadToAll(coalition.side.BLUE, bCircleId, self.zone.vertices[4], self.zone.vertices[3],
                        self.zone.vertices[2], self.zone.vertices[1], border_color, fill_color, 1, true)
                end
                trigger.action.textToAll(coalition.side.BLUE, bTextId, self.zone.point, text_color, text_bg, 13, true, text_display)
    
                self._markIds.blue = bCircleId
                self._markIds.blueText = bTextId
            else
                self._markIds.blue, self._markIds.blueText = nil, nil
            end
    
            -- Draw for RED coalition (if they discovered it)
            if utils.tableContains(stats.red_discovered_zones, self.zone.name) then
    
                local rCircleId = nextMarkId()
                local rTextId   = nextMarkId()

                if self:isCircle() then
                    trigger.action.circleToAll(coalition.side.RED, rCircleId, self.zone.point, self.zone.radius, border_color, fill_color, 1, true)
                elseif self:isQuad() then
                    trigger.action.quadToAll(coalition.side.RED, rCircleId, self.zone.vertices[4], self.zone.vertices[3],
                        self.zone.vertices[2], self.zone.vertices[1], border_color, fill_color, 1, true)
                end
                trigger.action.textToAll(coalition.side.RED, rTextId, self.zone.point, text_color, text_bg, 13, true, text_display)
    
                self._markIds.red = rCircleId
                self._markIds.redText = rTextId
            else
                self._markIds.red, self._markIds.redText = nil, nil
            end
        end
    end

    function ZoneHandler:isQuad()
        return self.zone.type == 2
    end

    function ZoneHandler:isCircle()
        return self.zone.type == 0
    end

    ---@param side coalition.side
    ---@param ignore_zone_names string[]|nil
    ---@param zone_types ZoneTypes[]|nil
    ---@param discovered boolean|nil
    ---@return ZoneHandler|nil, number -- returns closest zone and distance to it
    function ZoneHandler:getClosestZone(side, ignore_zone_names,zone_types,discovered)
        local closestZone = nil
        local closestDistance = math.huge
        local distance = 0

        for _, current_zone in ipairs(zones) do
            if current_zone.name ~= self.name
            and not utils.tableContains(ignore_zone_names or {}, current_zone.name)
            and (not zone_types or utils.tableContains(zone_types, current_zone.zone_type)) then
            
                local allow_discovered = false
                if discovered then
                    -- Check the discovery list of the CALLER (self.side)
                    if self.side == coalition.side.BLUE and utils.tableContains(stats.blue_discovered_zones, current_zone.name) then
                        allow_discovered = true
                    elseif self.side == coalition.side.RED and utils.tableContains(stats.red_discovered_zones, current_zone.name) then 
                        allow_discovered = true
                    end
                else 
                    allow_discovered = true -- 'discovered' check is not required
                end

                if allow_discovered then
                    distance = mist.utils.get2DDist(self.zone.point, current_zone.zone.point)
                    
                    -- Check the side of the TARGET (the 'side' parameter)
                    if distance < closestDistance and (side == current_zone.side or side == -1) then
                        closestDistance = distance
                        closestZone = current_zone
                    end
                end
            end
        end

        return closestZone, closestDistance
    end

    ---@param point vec3|vec2
    function ZoneHandler:isPointInsideZone(point)
        if self:isCircle() then
            local dist = mist.utils.get2DDist(point, self.zone.point)
            return dist < self.zone.radius
        elseif self:isQuad() then
            return mist.pointInPolygon(point, self.zone.vertices)
        end
    end

    ---@return ZoneHandler[]
    function ZoneHandler.sortZonesByDistance(point)
        local sorted_zones_simplified = {}

        for _, zone in pairs(zones) do
            local transfer_zone = { name = zone.zone.name }
            transfer_zone.distance = mist.utils.get2DDist(zone.zone.point, point)
            table.insert(sorted_zones_simplified, transfer_zone)
        end

        table.sort(sorted_zones_simplified, function(a, b) return a.distance < b.distance end)

        -- creates a table with a copy of the zones table but sorted
        local sorted_zones = {}
        for _, sorted_zone in pairs(sorted_zones_simplified) do
            for _, zone in pairs(zones) do
                if zone.zone.name == sorted_zone.name then
                    table.insert(sorted_zones, zone)
                end
            end
        end


        return sorted_zones
    end

    function ZoneHandler:updateDiscoveredZones()
        -- makes all zones under MAX_GRND_RECON_DIST added to the discoverd var
        local updated_zones = {}

        for _, other_zone in ipairs(zones) do
            if self.side ~= coalition.side.NEUTRAL and self.side ~= other_zone.side
            and mist.utils.get2DDist(self.zone.point, other_zone.zone.point) < Config.max_ground_recon_range then

                if not utils.tableContains(stats.blue_discovered_zones,other_zone.name) then
                    table.insert(stats.blue_discovered_zones,other_zone.name)
                    table.insert(updated_zones,other_zone.name)
                end

                if not utils.tableContains(stats.red_discovered_zones,other_zone.name) then
                    table.insert(stats.red_discovered_zones,other_zone.name)
                    table.insert(updated_zones,other_zone.name)
                end
            end
        end

        for _,zone_name in ipairs(updated_zones) do
            local zone = ZoneHandler.getFromName(zone_name)
            if zone then
                zone:drawF10()
            end
        end
        CommandHandler.requestMenuRefresh(coalition.side.BLUE)
        CommandHandler.requestMenuRefresh(coalition.side.RED)
    end

    function ZoneHandler:capture(side)
        if self.side == side then return end
        if MISSION_ENDED then return end

        if self.side == coalition.side.NEUTRAL then
            stats.neutral_zones = stats.neutral_zones - 1
        elseif self.side == coalition.side.RED then
            stats.red_zones = stats.red_zones - 1
        elseif self.side == coalition.side.BLUE then
            stats.blue_zones = stats.blue_zones - 1
        end



        self.side = side
        self.level = 1

        if self.side == coalition.side.RED then
            stats.red_zones = stats.red_zones + 1
        elseif self.side == coalition.side.BLUE then
            stats.blue_zones = stats.blue_zones + 1
        elseif self.side == coalition.side.NEUTRAL then
            stats.neutral_zones = stats.neutral_zones + 1
        end

        if self.zone_type == ZoneTypes.STRONGPOINT and self.side ~= coalition.side.NEUTRAL then
            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.STRONGPOINT_SITES.RED[self.level].group_name, self,true) -- level 1
                stats.red_strongpoints = stats.red_strongpoints +1
                stats.blue_strongpoints = stats.blue_strongpoints -1

            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.STRONGPOINT_SITES.BLUE[self.level].group_name, self,true)
                stats.red_strongpoints = stats.red_strongpoints -1
                stats.blue_strongpoints = stats.blue_strongpoints +1
            end
            self.attack_convoy = 0

        elseif self.zone_type == ZoneTypes.LOGISTICS and self.side ~= coalition.side.NEUTRAL then
            --TO CHANGE add looting capture logic

            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.LOGISTICS_SITES.RED[self.level].group_name, self,true)
                WarehouseManager:handleIncomingSupplies(self.side,{WarehouseManager.StockTypes.LOGISTICS_CAPTURE})
            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.LOGISTICS_SITES.BLUE[self.level].group_name, self,true)
                WarehouseManager:handleIncomingSupplies(self.side,{WarehouseManager.StockTypes.LOGISTICS_CAPTURE})
            end
            self.capture_heli_avail = 0
            -- Mark static as dead, this prevents the check function from flagging it as dead
            self.linked_ammo_depot = nil
            self.ammo_depot_intact = false
            self.ammo_depot_last_destroyed = timer.getTime()
            self.linked_statics = {}
        elseif self.zone_type == ZoneTypes.COMMS and self.side ~= coalition.side.NEUTRAL then
            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.COMMS_SITES.RED[self.level].group_name, self,true)
                stats.red_comms_zones = stats.red_comms_zones +1
                stats.blue_comms_zones = stats.blue_comms_zones -1
            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.COMMS_SITES.BLUE[self.level].group_name, self,true)
                stats.red_comms_zones = stats.red_comms_zones -1
                stats.blue_comms_zones = stats.blue_comms_zones +1
            end
            -- Mark static as dead, this prevents the check function from flagging it as dead
            self.linked_comms_tower = nil
            self.comms_tower_intact = false
            self.comms_tower_last_destroyed = timer.getTime()
            self.linked_statics = {}
        elseif self.zone_type == ZoneTypes.EWSITE and self.side ~= coalition.side.NEUTRAL then
            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.EW_SITES.RED[self.level].group_name , self,true)
                stats.red_ew_zones = stats.red_ew_zones +1
                stats.blue_ew_zones = stats.blue_ew_zones -1
            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.EW_SITES.BLUE[self.level].group_name , self,true)
                stats.red_ew_zones = stats.red_ew_zones -1
                stats.blue_ew_zones = stats.blue_ew_zones +1
            end
        elseif self.zone_type == ZoneTypes.FARP and self.side ~= coalition.side.NEUTRAL then
            -- first delete the invisiblefarp if exits
            timer.scheduleFunction(function ()
                UnitHandler.initFARP(self,false)
            end,{},timer.getTime()+5)

            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.FARP_SUPPORT.RED[self.level].group_name , self,true,100,300)
                stats.red_farp_zones = stats.red_farp_zones+1
                stats.blue_farp_zones = stats.blue_farp_zones-1
            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.FARP_SUPPORT.BLUE[self.level].group_name , self,true,100,300)
                stats.red_farp_zones = stats.red_farp_zones-1
                stats.blue_farp_zones = stats.blue_farp_zones+1
            end
        elseif self.zone_type == ZoneTypes.SAMSITE and self.side ~= coalition.side.NEUTRAL then
            local sam_spawned = nil
            local sam_spawn_options = {}
            for _, sam in pairs(GroupData.SAM_SITES_NG) do
                if sam.side == self.side and sam.sam_classification == self.sam_classification then
                    table.insert(sam_spawn_options, sam.group_name)
                end
            end
            if #sam_spawn_options > 0 then
                local chosen_sam_grname = sam_spawn_options[math.random(1, #sam_spawn_options)]
                sam_spawned = UnitHandler.clone(chosen_sam_grname , self, false)
            end
            if not sam_spawned then
                MissionLogger:warn("No SAM options found for zone: " .. self.name .. " with classification: " ..tostring(self.sam_classification))
                if self.side == coalition.side.BLUE then
                    UnitHandler.clone("BLUE GRND TEST", self, false)
                elseif self.side == coalition.side.RED then
                    UnitHandler.clone("RED GRND TEST", self, false)
                end
            end

            if self.side == coalition.side.RED then
                stats.red_sam_sites = stats.red_sam_sites +1
                stats.blue_sam_sites = stats.blue_sam_sites -1
            elseif self.side == coalition.side.BLUE then
                stats.red_sam_sites = stats.red_sam_sites -1
                stats.blue_sam_sites = stats.blue_sam_sites +1
            end

        elseif self.zone_type == ZoneTypes.AIRBASE  then
            if self.airbase_name then
                local airbase = Airbase.getByName(self.airbase_name)
                if airbase then
                    airbase:autoCapture(false)
                    airbase:setCoalition(self.side)

                    -- RESET WAREHOUSE
                    local wh = airbase:getWarehouse()
                    if wh then
                        local inv = wh:getInventory()

                        -- 1. Clear Weapons / Stores (only those we manage)
                        if inv.weapon then
                            for item_name, count in pairs(inv.weapon) do
                                if WarehouseManager:isSupportedWeapon(item_name) then
                                    wh:removeItem(item_name, count)
                                end
                            end
                        end

                        -- 2. Clear Aircraft (only those we manage)
                        if inv.aircraft then
                            for item_name, count in pairs(inv.aircraft) do
                                if WarehouseManager:isSupportedAircraft(item_name) then
                                    wh:removeItem(item_name, count)
                                end
                            end
                        end
                    end
                end
            end

            -- Mark static as dead, this prevents the check function from flagging it as dead
            self.cmdc_intact = false
            self.cmdc_last_destroyed = timer.getTime()
            self.linked_statics = {}

            if red_airbase and self.airbase_name == red_airbase.airbase_name then
                red_airbase.side = self.side
            elseif blue_airbase and self.airbase_name == blue_airbase.airbase_name then
                blue_airbase.side = self.side
            end

            if self.side == coalition.side.RED then
                UnitHandler.clone(GroupData.AIRBASE_SITES.RED[self.level].group_name , self,true)
                for _,sam in pairs(GroupData.AIRBASE_SAMS.RED) do
                    if sam.tier == self.level then
                        UnitHandler.clone(sam.group_name , self,false)
                    end
                end
                stats.red_airbases = stats.red_airbases +1
                stats.blue_airbases = stats.blue_airbases -1
            elseif self.side == coalition.side.BLUE then
                UnitHandler.clone(GroupData.AIRBASE_SITES.BLUE[self.level].group_name , self,true)
                for _,sam in pairs(GroupData.AIRBASE_SAMS.BLUE) do
                    if sam.tier == self.level then
                        UnitHandler.clone(sam.group_name , self,false)
                    end
                end
                stats.red_airbases = stats.red_airbases -1
                stats.blue_airbases = stats.blue_airbases +1
            end
        end

        -- remove potential jtacs

        -- remove potential attack convoys in zone
        for _,enroute in ipairs(EnrouteManager.enroutes) do
            if self.name == enroute.to_zone.name then
                if enroute.ai_task_type == AITaskTypes.ATTACK_CONVOY then
                    local convoy_group = Group.getByName(enroute.group_name)
                    if convoy_group and convoy_group:isExist() then
                        trigger.action.setGroupAIOff(convoy_group)
                        timer.scheduleFunction(function ()
                            convoy_group:destroy()
                        end, {}, timer.getTime() + math.random(5, 10))
                        EnrouteManager:remove(enroute.group_name)
                    end
                elseif enroute.ai_task_type == AITaskTypes.JTAC then
                    if enroute.jtac then
                        timer.scheduleFunction(function ()
                            enroute.jtac:destroy() -- this uses the custom destroy function that also removes commands
                        end, {}, timer.getTime() + math.random(5, 10))
                        EnrouteManager:remove(enroute.group_name)
                    end
                elseif enroute.ai_task_type == AITaskTypes.RESUPPLY_CARGO then
                    local cargo_group = Group.getByName(enroute.group_name)
                    if cargo_group and cargo_group:isExist() then
                        timer.scheduleFunction(function ()
                            cargo_group:destroy()
                            local enemy_side = utils.getEnemyCoalition(self.side)
                            trigger.action.outTextForCoalition(enemy_side,"SITREP: Resupply Aircraft inbound for "..enroute.to_zone.name .. " aborted!",10)
                            trigger.action.outSoundForCoalition(enemy_side,"radio_beep3.ogg")
                            EnrouteManager:remove(enroute.group_name)
                        end, {}, timer.getTime() + math.random(5, 10))
                    end
                end

            end
        end


        -- Notify players
        if self.side == coalition.side.BLUE then
            
            --Add discovered zone to blue players
            if not utils.tableContains(stats.blue_discovered_zones, self.name) then
                table.insert(stats.blue_discovered_zones, self.name)
            end
            
            trigger.action.outTextForCoalition(1,"SITEP: Allied forces lost control of " .. self.name .. ".", 15)

            trigger.action.outTextForCoalition(2,"SITREP: Allied forces have occupied " .. self.name .. ".", 15)

            -- Adds supplies on capture
            timer.scheduleFunction(function ()
                local added_supplies = Config.supplies.supplies_looted_on_destroyed + math.random(-Config.supplies.supplies_looted_on_destroyed_variance,Config.supplies.supplies_looted_on_destroyed_variance)
                stats.blue_supplies = stats.blue_supplies + added_supplies
                trigger.action.outTextForCoalition(2,"Frontline forces looted " .. added_supplies .. " supplies from "..self.name, 10)
                trigger.action.outSoundForCoalition(2, "radio_beep3.ogg")
            end,{},timer.getTime()+math.random(30,60))

        elseif self.side == coalition.side.RED then
            --Add discovered zone to blue players
            if not utils.tableContains(stats.red_discovered_zones, self.name) then
                table.insert(stats.red_discovered_zones, self.name)
            end
            -- Adds supplies on capture
            timer.scheduleFunction(function ()
                    local added_supplies = Config.supplies.supplies_looted_on_destroyed + math.random(-Config.supplies.supplies_looted_on_destroyed_variance,Config.supplies.supplies_looted_on_destroyed_variance)
                stats.red_supplies = stats.red_supplies + added_supplies
                trigger.action.outTextForCoalition(1,"Frontline forces looted " .. added_supplies .. " supplies from "..self.name, 10)
                trigger.action.outSoundForCoalition(1, "radio_beep3.ogg")
            end,{},timer.getTime()+math.random(30,60))

            trigger.action.outTextForCoalition(2,"SITEP: Allied forces lost control of " .. self.name .. ".", 15)
            
            trigger.action.outTextForCoalition(1,"SITREP: Allied forces have occupied " .. self.name .. ".", 15)
        else
            trigger.action.outText("SITREP: ".. self.name .. " is now neutral territory.", 15)
        end

        if self.side == coalition.side.NEUTRAL then
            self.last_capture_attempt = nil
            self:drawF10()
        else
            self.last_attacked_by = nil 
            self.last_capture_attempt = nil
            
            self.attack_convoy = 0
            self.capture_heli_avail = 0
            self:drawF10()
            self:updateDiscoveredZones()
            
        end

        trigger.action.outSound("radio click.ogg")
        MissionLogger:info("Zone " .. self.zone.name .. " captured by " .. utils.coalitionToString(self.side))

        -- Invalidate cached operation lists immediately after ownership changes.
        if TheatreCommander.blue_op_manager and TheatreCommander.blue_op_manager.forceRegenerateOperations then
            TheatreCommander.blue_op_manager:forceRegenerateOperations()
        end
        if TheatreCommander.red_op_manager and TheatreCommander.red_op_manager.forceRegenerateOperations then
            TheatreCommander.red_op_manager:forceRegenerateOperations()
        end

        timer.scheduleFunction(function ()
            CommandHandler.requestMenuRefresh()
            if MISSION_ENDED then return end
            if stats.blue_zones == 0 and stats.red_zones > 0 then
                MISSION_ENDED = true
                world.removeEventHandler(ev)
                trigger.action.outText("************\n\n  REDFOR achieved total domination !\n\n************", 500)
            elseif stats.red_zones == 0 and stats.blue_zones > 0 then
                MISSION_ENDED = true
                world.removeEventHandler(ev)
                trigger.action.outText("************\n\n  BLUFOR achieved total domination !\n\n************", 500)
            end
        end,nil,timer.getTime()+10)

    end

    ---@param zone_name string
    ---@return ZoneHandler|nil
    function ZoneHandler.getFromName(zone_name)
        for _, search_zone in pairs(zones) do
            if search_zone.name == zone_name then
                return search_zone
            end
        end
        return nil
    end

    function ZoneHandler:hasCaptureHeliAvailable()
        return self.capture_heli_avail > 0
    end

    function ZoneHandler:checkIfEmpty()

        local units_count=0
        for i = #self.linked_groups, 1, -1 do
            local group = Group.getByName(self.linked_groups[i])
            if group and group:isExist() then
                units_count = units_count + group:getSize()
            else 
                table.remove(self.linked_groups, i)
            end
        end

        local statics_count=0
        for i = #self.linked_statics, 1, -1 do
            local static_name = self.linked_statics[i]
            local static = StaticObject.getByName(static_name)

            if static and static.isExist and static:isExist()
            and static:getLife() > 1
            then
                statics_count = statics_count +1
            else
                table.remove(self.linked_statics, i)
            end
        end

        if units_count + statics_count == 0 then
            self.linked_statics = {}
            self.linked_groups = {}
            return true
        else
            return false
        end
    end

    function ZoneHandler:checkIfEmptyAndCapture()
        if self.side == coalition.side.NEUTRAL then return false end
        local units_in_zone = utils.getUnitsInZoneObj(self)
        local static_in_zone = utils.getStaticsInZoneObj(self)

        
        -- local units_in_zone = TheatreCommander.fetchUnitsInZone(self.zone.name, true, false,utils.getEnemyCoalition(self.side))
        -- MissionLogger:info(#units_in_zone .. " units in zone " .. self.zone.name)
        MissionLogger:info("Checking if zone "..self.name.." is empty, units found " .. (#units_in_zone or 0)..", statics found "..(#static_in_zone or 0))
        
        --check if all units are not airborne, remove them
        for i = #units_in_zone, 1, -1 do
            local unit = units_in_zone[i]
            if unit:inAir() then
                table.remove(units_in_zone, i)
            end
        end

        if static_in_zone and #static_in_zone >0 then
            return false
        end
        if units_in_zone and #units_in_zone > 0 then
            return false
        end
        -- if no units in zone, neutralise it
        self:capture(coalition.side.NEUTRAL)
        return true


        -- [ if zone empty then make it neutral]
    end

    function ZoneHandler:isPointClearOfUnits(vec3_point, min_clearance)
        local vol = { id = world.VolumeType.SPHERE, params = { point = vec3_point, radius = min_clearance } }
        local found = false
        world.searchObjects({Object.Category.UNIT, Object.Category.STATIC}, vol, function() found = true end)
        if found then return false
        else return true end
    end

    --- Adds Capture Helicopters/Convoys or Attack Convoys to zones, based on chance
    --- @param chance number Chance from 1-100 to add assets
    function ZoneHandler:addAIAssets(chance)
        if math.random(1,100) > chance then return end

        if self.zone_type == ZoneTypes.LOGISTICS then
            if self.capture_heli_avail < Config.tasking.max_capture_helicopters_per_logistics_zone then
                self.capture_heli_avail = self.capture_heli_avail +1
            end
        elseif self.zone_type == ZoneTypes.STRONGPOINT then
            if self.attack_convoy < Config.tasking.max_attack_convoys_per_strongpoint_zone then
                self.attack_convoy = self.attack_convoy +1
            end
        end
        self:drawF10()
    end

    ---@return boolean --true if zone was upgraded
    function ZoneHandler:checkLogisticsZone()
        if self.side == coalition.side.NEUTRAL then return false end
        if self.zone_type ~= ZoneTypes.LOGISTICS then return false end

        -- MissionLogger:info("Checking logistcs zone "..self.name)
        local ammo_depot = nil
        local is_alive = false
        if not self.linked_ammo_depot then
            self.ammo_depot_intact = false
        else
            ammo_depot = StaticObject.getByName(self.linked_ammo_depot)
            is_alive = ammo_depot and ammo_depot:isExist() and ammo_depot:getLife() >= 1
        end
        

        -- If the script thinks the depot is intact, but it's NOT alive, mark it as destroyed.
        if self.ammo_depot_intact and not is_alive then
            self.ammo_depot_intact = false
            self.ammo_depot_last_destroyed = timer.getTime()

            for i = #self.linked_statics, 1, -1 do
                if self.linked_statics[i] == self.linked_ammo_depot then
                    table.remove(self.linked_statics, i)
                end
            end
            self.linked_ammo_depot = nil

            -- destroy if it exists
            if ammo_depot and ammo_depot:isExist() then
                ammo_depot:destroy()
            end
            utils.editAmmoDepotsCount(self.side, -1)
            trigger.action.outTextForCoalition(self.side, "Sector ALERT: Secondary explosions confirmed at "..self.name..". The ammunition depot is a total loss",20)
            trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
            timer.scheduleFunction(function ()
                trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
            end,{},timer.getTime()+1)

        end
        if not self.ammo_depot_intact and not self.ammo_depot_last_destroyed then
            -- depot was destroyed but time not recorded, record it now
            self.ammo_depot_last_destroyed = timer.getTime()
        end

        -- checks if the ammo depot has not been destroyed, else respawn one in 
        if self.ammo_depot_last_destroyed and not self.ammo_depot_intact
        and self.ammo_depot_last_destroyed + Config.logistics_ammo_depot_respawn_time > timer.getTime() then
            MissionLogger:info(self.name .." ammo depot pending respawn")
            -- display the time remaining for spawn
            local time_remaining = math.ceil((self.ammo_depot_last_destroyed + Config.logistics_ammo_depot_respawn_time - timer.getTime())/60)
            local time_text = "Rebuild in T-"..time_remaining.." min"
            self:drawF10(time_text)

            return false
        elseif not self.ammo_depot_intact and self.ammo_depot_last_destroyed
        and self.ammo_depot_last_destroyed + Config.logistics_ammo_depot_respawn_time <= timer.getTime() then
            MissionLogger:info(self.name .." ammo depot respawn")

            
            -- respawn the ammo depot --TO CHANGE
            local country_name
            if self.side == coalition.side.BLUE then country_name = country.id.CJTF_BLUE
            else country_name = country.id.CJTF_RED end
            
            local pnt= mist.getRandomPointInZone(self.zone.name,40) or {x=self.zone.point.x-67, y=self.zone.point.z+42}

            local ammo_depot_gr = mist.dynAddStatic({
                type = ".Ammunition depot",
                country = country_name,
                category = "Warehouses",
                x = pnt.x,
                y = pnt.y})
                if ammo_depot_gr then
                    self.ammo_depot_intact = true
                    self.linked_ammo_depot = ammo_depot_gr.name
                    self.ammo_depot_last_destroyed = nil
                    utils.editAmmoDepotsCount(self.side, 1)
                    trigger.action.outSoundForCoalition(self.side,"chatter3.ogg")
                    trigger.action.outTextForCoalition(self.side, "Logistics SITREP: Logistics zone "..self.name.." has reestablished its ammunition depot.",10)
            self:drawF10()
            else                                                  
                MissionLogger:error("Could not spawn ammo depot for ".. self.name)
            end
        end

        -- Ammo depot is intact
        --First add supplies
        local supply_count = 0
        if self.side == coalition.side.BLUE then
            supply_count = stats.blue_supplies
        elseif self.side == coalition.side.RED then
            supply_count = stats.red_supplies
        end
        

        supply_count = math.min(math.min(supply_count + Config.supplies.supplies_income, utils.calculateSuppliesCAPforCoalition(self.side)), Config.supplies.absolute_max_supplies)
        
        -- Update the stats with the new supply count
        if self.side == coalition.side.BLUE then
            stats.blue_supplies = supply_count
        elseif self.side == coalition.side.RED then
            stats.red_supplies = supply_count
        end
        
        local _,dist_to_enemy_zone = self:getClosestZone(utils.getEnemyCoalition(self.side))
        if not dist_to_enemy_zone then return false end
        if dist_to_enemy_zone and dist_to_enemy_zone > Scenario.logistics_setup.max_dist_to_frontline then return false end


        if math.random(1,100) > Config.logistics_upgrade_chance then return false end

        -- Prevents level ups of zones with players assigned AIRDROP operations
        local airdop_restricted_zones = {}
        ---@type Operation[]
        local op_manager = TheatreCommander.blue_op_manager.active_operations

        if op_manager then
            for _, active_op in ipairs(op_manager) do
                if active_op.type == OperationTypes.AIRDROP then
                    table.insert(airdop_restricted_zones, active_op.target_zone_name)
                end
            end
        end

        -- levels up lowest level zones nearby
        -- allow level ups only of ammo depot intact (not destroyed)
        -- MissionLogger:info("Checking logistics zone "..self.name.." for level up")
        if self.ammo_depot_intact and self.next_level_up_avail and timer.getTime() > self.next_level_up_avail then
            -- level up nearest zone at lowest level
            local lowest_level_zone_nearby = nil
            if self.level < 4 then lowest_level_zone_nearby = self  --level up itself before others
            else
                local tried_zones = {}
                local loop_prevention = 0
                local level_zone, dist = self:getClosestZone(self.side,tried_zones)

                while level_zone and dist < Scenario.logistics_setup.upgrade_range
                and loop_prevention < 400 do

                    if (not lowest_level_zone_nearby) or (level_zone.level < lowest_level_zone_nearby.level)
                    and not utils.tableContains(airdop_restricted_zones, level_zone.name) then
                        lowest_level_zone_nearby = level_zone
                    end
                    table.insert(tried_zones,level_zone.name)
                    level_zone, dist = self:getClosestZone(self.side,tried_zones)
                    loop_prevention = loop_prevention+1
                end
                if loop_prevention > 395 then
                    MissionLogger:warn("Loop prevention prevented a crash")
                end

            end

            if lowest_level_zone_nearby and lowest_level_zone_nearby.level < 4 then

                
                -- lowest nearby level zones has been found
                lowest_level_zone_nearby.level = lowest_level_zone_nearby.level + 1
                UnitHandler.updateZoneUnits(lowest_level_zone_nearby)
                lowest_level_zone_nearby:drawF10()
                self.next_level_up_avail = timer.getTime() + Config.logistics_level_up_interval
                MissionLogger:info("Logistics zone "..self.name.." leveled up "..lowest_level_zone_nearby.name .. " to level "..lowest_level_zone_nearby.level.."/4")
                trigger.action.outSoundForCoalition(self.side,"radio_beep3.ogg")
                if self.name == lowest_level_zone_nearby.name then
                    trigger.action.outTextForCoalition(self.side, self.name.." has reached operational tier "..lowest_level_zone_nearby.level.."/4",10)
                else
                    trigger.action.outTextForCoalition(self.side,self.name.." provided additional support for "..lowest_level_zone_nearby.name.."\nT: "..lowest_level_zone_nearby.level.."/4",10)
                end
                return true
            end
        end
        return false
    end

    function ZoneHandler:checkCOMMSZone()
        if self.side == coalition.side.NEUTRAL then return end
        if self.zone_type ~= ZoneTypes.COMMS then return end

        local comms_tower = nil
        if self.linked_comms_tower then
            comms_tower = StaticObject.getByName(self.linked_comms_tower)
        end
        
        -- First, check the actual status of the tower
        local is_alive = comms_tower and comms_tower:isExist() and comms_tower:getLife() >= 1
        
        if not self.comms_tower_intact and not self.comms_tower_last_destroyed then
            -- tower was destroyed but time not recorded, record it now
            self.comms_tower_last_destroyed = timer.getTime()
        end

        -- If the script thinks the tower is intact, but it's NOT alive, mark it as destroyed.
        if self.comms_tower_intact and not is_alive then
            local dead_comms_name = self.linked_comms_tower
            self.comms_tower_intact = false
            self.comms_tower_last_destroyed = timer.getTime()
            for i = #self.linked_statics, 1, -1 do
                if self.linked_statics[i] == dead_comms_name then
                    table.remove(self.linked_statics, i)
                end
            end
            self.linked_comms_tower = nil
            utils.editCommsAntennasCount(self.side, -1)

            trigger.action.outTextForCoalition(self.side, "Sector ALERT: "..self.name.." has lost its communications tower.",20)
            trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
            timer.scheduleFunction(function ()
                trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
            end,{},timer.getTime()+1)

            -- Destroy the "dead body"
            if comms_tower and comms_tower:isExist() then
                comms_tower:destroy()
            end
        end

        -- Check if the tower is pending respawn or ready to respawn
        if self.comms_tower_last_destroyed and not self.comms_tower_intact and
        self.comms_tower_last_destroyed + (Config.comms_tower_respawn_time) > timer.getTime() then
            -- Not enough time has passed
            MissionLogger:info(self.name .." comms tower pending respawn")
            -- display remaining time in mins to zone
            local time_remaining = math.ceil((self.comms_tower_last_destroyed + (Config.comms_tower_respawn_time) - timer.getTime()) / 60)
            local time_text = "Rebuild in T-"..time_remaining.." min"
            self:drawF10(time_text)
            return
        elseif not self.comms_tower_intact and self.comms_tower_last_destroyed
        and self.comms_tower_last_destroyed + (Config.comms_tower_respawn_time) <= timer.getTime() then
            -- Respawn the tower
            MissionLogger:info(self.name .." comms tower respawn")

            local country_name
            if self.side == coalition.side.BLUE then country_name = country.id.CJTF_BLUE
            else country_name = country.id.CJTF_RED end
            
            local pnt= mist.getRandomPointInZone(self.zone.name,40) or {x=self.zone.point.x-67, y=self.zone.point.z+42}

            local comms_tower_gr = mist.dynAddStatic({
                type = "Comms tower M",
                country = country_name,
                category = "Fortifications",
                x = pnt.x,
                y = pnt.y})
            
            if comms_tower_gr then
                self.comms_tower_intact = true
                self.linked_comms_tower = comms_tower_gr.name
                self.comms_tower_last_destroyed = nil
                
                utils.editCommsAntennasCount(self.side, 1)
                self:drawF10()
                -- Every level reduces the respawn time by 10%
                local level_modifier = 1 - ((self.level -1) * 0.1)
                Config.comms_tower_respawn_time = math.floor(Config.comms_tower_respawn_time * level_modifier)

                -- Increase future respawn times
                --Config.comms_tower_respawn_time = math.floor(Config.comms_tower_respawn_time * Config.comms_tower_lost_penalty)
                MissionLogger:info("Comms tower respawn time is now "..Config.comms_tower_respawn_time)
           
                trigger.action.outSoundForCoalition(self.side,"chatter3.ogg")
                trigger.action.outTextForCoalition(self.side, "SITREP: COMMS "..self.name.." has rebuilt its communications tower.",10)
            else
                MissionLogger:error("Could not spawn comms tower for ".. self.name)
            end
        end
    end

    function ZoneHandler:checkAirbaseZone()
        if self.zone_type ~= ZoneTypes.AIRBASE then return end
        if self.side == coalition.side.NEUTRAL then return end
        if not self.airbase_name then return end

        local cmdc = nil
        local command_center_name = self.linked_statics[1]
        if command_center_name then
            cmdc = StaticObject.getByName(command_center_name)
        end
        -- First, check the actual status of the depot
        local is_alive = cmdc and cmdc:isExist() and cmdc:getLife() >= 1

        if self.cmdc_intact == false and not self.cmdc_last_destroyed then
            self.cmdc_last_destroyed = timer.getTime()
        end

        -- If the script thinks the depot is intact, but it's NOT alive, mark it as destroyed.
        if self.linked_statics[1] and not is_alive then
            self.cmdc_intact = false
            self.cmdc_last_destroyed = timer.getTime()
            for i = #self.linked_statics, 1, -1 do
                if self.linked_statics[i] == command_center_name then
                    table.remove(self.linked_statics, i)
                end
            end

            utils.editCommandPostsCount(self.side, -1)
            -- The coalition will loose 1/(# of cmd posts)of their supplies immediately
            if self.side == coalition.side.BLUE then
                local supply_loss = math.floor(stats.blue_supplies / math.max(1, stats.blue_command_posts))
                stats.blue_supplies = math.max(0, stats.blue_supplies - supply_loss)
                trigger.action.outTextForCoalition(self.side, "Sector ALERT: "..self.name.." command center has collapsed. Field reports indicate "..supply_loss.." supplies were lost in the blast and subsequent fires.",20)
                trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
                timer.scheduleFunction(function ()
                    trigger.action.outSoundForCoalition(self.side,"alert1.ogg")
                end,{},timer.getTime()+1)
            end
        end

        if not is_alive and self.cmdc_last_destroyed
        and self.cmdc_last_destroyed + Config.airbase_command_center_respawn_time > timer.getTime() then          

            MissionLogger:info(self.name .." command center pending respawn")
            local time_remaining = math.ceil((self.cmdc_last_destroyed + (Config.airbase_command_center_respawn_time) - timer.getTime()) / 60)
            local time_text = "Rebuild in T-"..time_remaining.." min"
            self:drawF10(time_text)
            return
        elseif not is_alive and self.cmdc_last_destroyed
        and self.cmdc_last_destroyed + Config.airbase_command_center_respawn_time <= timer.getTime() then

            MissionLogger:info(self.name .." command center respawn")
            self.cmdc_intact = true

            local cmdc_spawned = UnitHandler.initStatics(self)
            if cmdc_spawned then
                self.cmdc_last_destroyed = nil
                trigger.action.outSoundForCoalition(self.side,"radio_beep.ogg")
                trigger.action.outTextForCoalition(self.side, "SITREP: AIRBASE "..self.name.." has rebuilt its Command Center.",10)
            else
                MissionLogger:error("Could not spawn command center for ".. self.name)
            end
        end
    end

end