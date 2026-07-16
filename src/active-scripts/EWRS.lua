---@class EW
---@field side coalition.side
---@field enemy_side coalition.side
---@field users EWRSUsers
---@field radars Unit[]
---@field refresh_time number seconds>0
---@field picture table
EWRS = {}
do
    ---@class EWRSSavedSettings
    ---@field enabled boolean whether the player had EWRS reports enabled
    ---@field view_radius number last chosen detection radius in meters

    ---@type table<string, EWRSSavedSettings>
    EWRS.saved_settings = {}

    --- Store a player's EWRS preference so it can be persisted and re-applied.
    ---@param unit Unit
    ---@param enabled boolean
    ---@param view_radius number|nil
    local function rememberSetting(unit, enabled, view_radius)
        if not unit.getPlayerName then return end
        local player_name = unit:getPlayerName()
        if not player_name then return end

        local setting = EWRS.saved_settings[player_name] or {}
        setting.enabled = enabled
        if view_radius then
            setting.view_radius = view_radius
        end
        EWRS.saved_settings[player_name] = setting
    end

    ---@param side coalition.side
    function EWRS:new(side)
        local obj = {}
        obj.side = side
        obj.refresh_time = Config.EWRS.standard_refresh_time
        obj.enemy_side = utils.getEnemyCoalition(side)
        obj.users = {}
        obj.radars = {}
        obj.picture = {}
        setmetatable(obj,self)
        self.__index = self

        obj:cacheRadars()
        obj:startSearch()

        return obj
    end

    ---@param name string
    ---@param unit Unit
    ---@param view_radius number meters>0
    function EWRS:addUser(name,unit,view_radius)
        if not unit or not unit:isExist() then return end

        ---@class EWRSUsers
        ---@field unit Unit
        ---@field view_radius number
        self.users[name] = {
            unit = unit,
            view_radius = view_radius
        }
        rememberSetting(unit, true, view_radius)
        local u_id = unit:getGroup():getID()
        MissionLogger:info(unit:getID())
        trigger.action.outTextForGroup(unit:getGroup():getID(),"EWRS enabled, detection radius set to "..mist.utils.metersToNM(view_radius).." NM",5)
        trigger.action.outSoundForGroup(u_id,"radio_txrx.ogg")

    end

    ---@param name string
    ---@param unit Unit
    function EWRS:removeUser(name,unit)
        self.users[name] = nil
        rememberSetting(unit, false)
        local gr_id = unit:getGroup():getID()
        trigger.action.outTextForGroup(gr_id,"EWRS reports hidden.",5)
        trigger.action.outSoundForGroup(gr_id,"radio_txrx.ogg")
    end

    function EWRS:cacheRadars()
        self.radars = {}

        -- Loop through all coalitions
        for _, coalition_id in ipairs({coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}) do
            
            local groups = coalition.getGroups(coalition_id)
            for _, group in ipairs(groups) do

                local units = group:getUnits()
                for _, unit in ipairs(units) do

                    if unit and unit:isExist() and unit:isActive() then
                        -- Check if unit has one of the radar attributes
                        if unit:hasAttribute("SAM SR")
                        or unit:hasAttribute("EWR")
                        or unit:hasAttribute("AWACS") then
                            table.insert(self.radars, unit)
                        end
                    end
                end
            end
        end
        
        
    end

    function EWRS:searchTheatre()
        self.picture = {}

        for _,radar_unit in ipairs(self.radars) do

            if radar_unit:isExist() and radar_unit:getLife() > 1 then
                local detected_targets = radar_unit:getController():getDetectedTargets(Controller.Detection.RADAR)
                -- MissionLogger:info("Detected targets")
                -- MissionLogger:info(detected_targets)

                for _,target in ipairs(detected_targets) do

                    if target and target.object and target.object.isExist and target.object:isExist()
                    and Object.getCategory(target.object) == Object.Category.UNIT
                    and target.object.getCoalition
                    and target.object:getCoalition() == self.enemy_side then
                        -- MissionLogger:info("Target name: " .. tostring(target.object:getName()))
                        if not self.picture[target.object:getName()] then
                            self.picture[target.object:getName()] = target.object
                        end
                    end
            
                end

            end
        end
        -- MissionLogger:info("Picture")
        -- MissionLogger:info(self.picture)
    end

    --- Determine target aspect (Hot / Flanking / Beaming / Cold)
    --- @param user_point vec3  
    --- @param target_point vec3      
    --- @param target_velocity any
    --- @return string aspect
    function EWRS:aspect(user_point, target_point,target_velocity)
        -- helper: convert radians to degrees (0–360)
        local function rad2deg(rad)
            local deg = math.deg(rad)
            return (deg % 360 + 360) % 360
        end
    
        -- bearing from target to user
        local dx = user_point.x - target_point.x
        local dz = user_point.z - target_point.z
        ---@diagnostic disable-next-line: deprecated
        local bearing = rad2deg(math.atan2(dx, dz))
    
        -- for lack of real heading data, assume target heading = north (0°)
        ---@diagnostic disable-next-line: deprecated
        local target_heading = math.deg(math.atan2(target_velocity.x, target_velocity.z)) % 360
    
        -- difference between assumed heading and bearing to user
        local diff = math.abs(((target_heading - bearing + 180) % 360) - 180)
    
        if diff <= 30 then
            return "Hot"
        elseif diff <= 60 then
            return "Flanking"
        elseif diff <= 120 then
            return "Beaming"
        else
            return "Cold"
        end
    end

    function EWRS:displayForUsers()
        for name,data in pairs(self.users) do
            if data.unit and data.unit:isExist() then
                local nearby_units = {}
                
                for _,detected_target in pairs(self.picture) do
                    if detected_target:isExist() then
                        local user_point = data.unit:getPoint()
                        local target_point = detected_target:getPoint()
                        local range = mist.utils.get2DDist(user_point,target_point)
                        if range <= data.view_radius then
                            

                            ---@diagnostic disable-next-line: deprecated
                            local bearing = math.deg(math.atan2(target_point.z - user_point.z, target_point.x - user_point.x))
                            if bearing < 0 then bearing = bearing + 360 end

                            table.insert(nearby_units,{
                                type = detected_target:getDesc().typeName,
                                range = range,
                                bearing = bearing,
                                altitude = target_point.y,
                                aspect = self:aspect(user_point, target_point,detected_target:getVelocity())
                            })
                        end
                    end
                end
                -- sort by range
                if #nearby_units ==0 then
                    trigger.action.outTextForGroup(data.unit:getGroup():getID(),"EWRS Report\n\n PICTURE CLEAR",15)
                else
                    table.sort(nearby_units, function(a, b) return a.range < b.range end)

                    local report = "EWRS Report\n\n"

                    for i = 1, math.min(#nearby_units, Config.EWRS.max_aircraft_per_text) do

                        local txt=""
                        if nearby_units[i].range > 1500 then
                            txt = string.format("%-16s BRAA %03.0f° / %2.0fnm  ALT %-13s ASPECT %-14s",
                            nearby_units[i].type,
                            nearby_units[i].bearing,
                            mist.utils.metersToNM(nearby_units[i].range),
                            math.floor((mist.utils.metersToFeet(nearby_units[i].altitude)+500)/1000)*1000,
                            nearby_units[i].aspect)
                        else
                            txt=string.format("%-16s  MERGED",nearby_units[i].type)
                        end
                        report = report .. txt .. "\n"

                    end
                    trigger.action.outTextForGroup(data.unit:getGroup():getID(),report,15)

                end


            else
                self.users[name] = nil
            end
        end
    end

    function EWRS:startSearch()
        timer.scheduleFunction(function ()
            if MISSION_ENDED then return end
            
            self:searchTheatre()
            self:displayForUsers()

            self:startSearch() -- continue loop

        end,{},timer.getTime() + self.refresh_time)
    end

    ---@param unit Unit
    function EWRS:addRadioMenuForUser(unit)

        --[[
            Activate : adds user to self.users
            Set radius: a submenu with choices of 10NM, 20NM, 40NM, 80NM, 160NM to set view_radius for user
            Hide Reports: remove user from self.users
        ]]

        if not unit or not unit:isExist() then return end
        local gr_id = unit:getGroup():getID()

        -- Root menu for the unit
        local rootPath = missionCommands.addSubMenuForGroup(gr_id, "EWRS")
        CommandHandler.addToMenuTracking(gr_id, rootPath, "ewrs_menu")

        -- Enable
        missionCommands.addCommandForGroup(gr_id, "Enable EWRS reports", rootPath, function()
            self:addUser(unit:getName(), unit, mist.utils.NMToMeters(40)) -- default 40nm
        end)

        -- Set Radius submenu
        local radiusMenu = missionCommands.addSubMenuForGroup(gr_id, "Set Radius", rootPath)

        local choices = {10, 20, 40, 80, 160} -- NM
        for _, nm in ipairs(choices) do
            missionCommands.addCommandForGroup(gr_id, nm .. " NM", radiusMenu, function()
                self:addUser(unit:getName(), unit, mist.utils.NMToMeters(nm))
            end)
        end

        -- Disable
        missionCommands.addCommandForGroup(gr_id, "Hide EWRS reports", rootPath, function()
            self:removeUser(unit:getName(), unit)
        end)

    end

    ---@param unit Unit
    function EWRS:applySavedSetting(unit)
        if not unit.getPlayerName then return end
        local player_name = unit:getPlayerName()
        if not player_name then return end

        local setting = EWRS.saved_settings[player_name]
        if setting and setting.enabled then
            self:addUser(unit:getName(), unit, setting.view_radius or mist.utils.NMToMeters(40))
        end
    end

    ---@param data table<string, EWRSSavedSettings>|nil
    function EWRS:restoreSavedSettings(data)
        if type(data) ~= "table" then return end
        EWRS.saved_settings = data
    end

end