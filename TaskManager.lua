---@class TaskManager
TaskManager = {}
do
    TaskManager.AWACSOrbitArea = {}

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
        local function sendText(txt)
            if user_requested then
                trigger.action.outTextForCoalition(side,txt,5)
            end
        end

        if AITaskTypes.CAS == ai_task_type and to_zone then
        
            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAS unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits.",5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.CAS}) then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAS already tasked for "..to_zone.name,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    trigger.action.outTextForCoalition(side,"CAS unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment.",5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then
                sendText("CAS required payload/armement not in warehouse.")
                return false
            end

            local new_group = mist.cloneGroup(template_gr_name,true)

            if not new_group then return false end
            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=closest_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })

            self:setCASTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.AWACS == ai_task_type and from_zone and from_zone.zone_type == ZoneTypes.AIRBASE then

            local enroutes_from_airbase = EnrouteManager:findByFromZone(from_zone,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    txt="AWACS unavailable from "..from_zone.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local in_stock, template_gr_name = WarehouseManager:checkAircraftInStock(from_zone.airbase_name,ai_task_type)
            if not in_stock then
                if user_requested then
                    txt="AWACS unavailable from "..from_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(from_zone,side,{AITaskTypes.AWACS}) then
                if user_requested then
                    txt="AWACS already tasked for "..from_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end



            local new_group = mist.cloneGroup(template_gr_name,true)
            if not new_group then return false end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = from_zone,
                side=side,
                from_zone=from_zone,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setAWACSTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.CAP == ai_task_type and to_zone then

            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    txt="CAP unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.CAP}) then
                if user_requested then
                    txt="CAP already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end

            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    txt="CAP unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("CAP required payload/armement not in warehouse.") return false end

            local new_group = mist.cloneGroup(template_gr_name,true)
            if not new_group then return false end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=closest_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setCAPTask(new_group.name,ai_enroute_data)
            return true

        elseif AITaskTypes.SEAD == ai_task_type and to_zone then

            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    txt="SEAD unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.SEAD}) then
                if user_requested then
                    txt="SEAD already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    txt="SEAD unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("SEAD required payload/armement not in warehouse.") return false end

            local new_group = mist.cloneGroup(template_gr_name,true)
            if not new_group then return false end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=closest_airbase,
                group_name=new_group.name,
                ai_task_type=ai_task_type
            })
            self:setSEADTask(new_group.name,ai_enroute_data)
            return true
        elseif AITaskTypes.STRIKE == ai_task_type and to_zone then

            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    txt="STRIKE unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.STRIKE}) then
                if user_requested then
                    txt="STRIKE already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    txt="STRIKE unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("STRIKE required payload/armement not in warehouse.") return false end

            local new_group = mist.cloneGroup(template_gr_name,true)
            if not new_group then return false end

            local ai_enroute_data = EnrouteManager:add({
                to_zone = to_zone,
                side=side,
                from_zone=closest_airbase,
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
                    txt="STRIKE tasks can only be tasked to zones with structures/buildings."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end
            local strike_point = statics_in_zone[math.random(1,#statics_in_zone)]:getPoint()

            self:setSTRIKETask(new_group.name,ai_enroute_data,strike_point)
            return true
        elseif AITaskTypes.RECON == ai_task_type and to_zone then
            local closest_airbase, template_gr_name = self:findClosestAirbaseWithAircraftInStock(to_zone,side,ai_task_type,2,ai_task_type)
            if not closest_airbase then
                if user_requested then
                    txt="RECON unavailable for "..to_zone.name..", check aircraft availability, warehouse stock and tasking limits."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone,side,{AITaskTypes.RECON}) then
                if user_requested then
                    txt="RECON already tasked for "..to_zone.name
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if not airbase then return false end


            local enroutes_from_airbase = EnrouteManager:findByFromZone(closest_airbase,side)
            if enroutes_from_airbase and #enroutes_from_airbase >= Config.tasking.max_tasks_per_airbase then
                if user_requested then
                    txt="RECON unavailable from "..closest_airbase.name..", airbase cannot handle more tasks at the moment."
                    trigger.action.outTextForCoalition(side,txt,5)
                end
                return false
            end

            if airbase and not WarehouseManager:checkIfAIPayloadInStock(airbase,ai_task_type)
            then sendText("RECON required payload/armement not in warehouse.") return false end

            local new_group = mist.cloneGroup(template_gr_name,true)
            if not new_group then return false end

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
                    txt="JTAC already tasked for "..to_zone.name
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
                groupName = GroupData.COMMON_ASSETS.BLUE.jtac,
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
            
            
            local convoy_template_gr_name
            local enemy_side
            
            if side == coalition.side.BLUE then
                convoy_template_gr_name = GroupData.COMMON_ASSETS.BLUE.attack_convoy
                enemy_side = coalition.side.RED
            elseif side == coalition.side.RED then
                convoy_template_gr_name = GroupData.COMMON_ASSETS.RED.attack_convoy
                enemy_side = coalition.side.BLUE
                
            end
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
                from_zone:drawF10()
                return true
            end
        elseif ai_task_type == AITaskTypes.CAPTURE_HELO and to_zone and from_zone then

            if prevent_duplicates and EnrouteManager:findByToZone(to_zone, side, {AITaskTypes.CAPTURE_HELO}) then
                if user_requested then
                    local txt = "Capture Helicopter already enroute to " .. to_zone.name
                    trigger.action.outTextForCoalition(side, txt, 5)
                end
                return false
            end

            local template_name
            if side == coalition.side.RED then
                template_name = GroupData.COMMON_ASSETS.RED.capture_helicopter
            elseif side == coalition.side.BLUE then
                template_name = GroupData.COMMON_ASSETS.BLUE.capture_helicopter
            end

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

            from_zone.capture_heli_avail = from_zone.capture_heli_avail - 1
            from_zone:drawF10()
            MissionLogger:info(utils.coalitionToString(side) .." heli from " ..from_zone.name .. " sent to capture zone: " .. to_zone.name)
            return true
        end

        return false
    end


    --- Returns true if max tasks reached for airbase
    ---@param airbase ZoneHandler
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return boolean
    function TaskManager:checkIfMaxTasksReached(airbase,side,ai_task_type)
        local enroutes_from_airbase = EnrouteManager:findByFromZone(airbase,side,{AITaskTypes.CAS,AITaskTypes.CAP,AITaskTypes.SEAD,AITaskTypes.STRIKE,AITaskTypes.RECON,AITaskTypes.AWACS})
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
        end

        return false
    end

    ---@param to_zone ZoneHandler
    ---@param side coalition.side
    ---@param aircraft_type string
    ---@param aircraft_amount number
    ---@param ai_task_type AITaskTypes
    ---@return ZoneHandler|nil,string|nil -- closest airbase, group name
    function TaskManager:findClosestAirbaseWithAircraftInStock(to_zone,side,aircraft_type, aircraft_amount,ai_task_type)
        local loop_prevention = 0

        local unavail_airbases = {}
        local closest_airbase = to_zone:getClosestZone(side,unavail_airbases,{ZoneTypes.AIRBASE})
        while closest_airbase and closest_airbase.airbase_name and loop_prevention < 400 do
            ---@diagnostic disable-next-line: undefined-field
            local airbase = Airbase.getByName(closest_airbase.airbase_name)
            if airbase and airbase:getCoalition() == side then
                local airbase_warehouse = airbase:getWarehouse()

                local aircraft_count = 0
                local group_name

                if WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name]
                and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side]
                and WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type] then
                    aircraft_count =airbase_warehouse:getItemCount(WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].warehouse_name)
                    group_name = WarehouseManager.AirbaseGroupData[closest_airbase.airbase_name][side][aircraft_type].group_name
                end
                -- MissionLogger:info("Airbase:" .. closest_airbase.airbase_name .. " has ".. aircraft_count .." ".. aircraft_type .." available.")  
                if aircraft_count and aircraft_count>=aircraft_amount and group_name then
                    
                    if not self:checkIfMaxTasksReached(closest_airbase,side,ai_task_type) then
                        return closest_airbase,group_name
                    else
                        MissionLogger:info("Airbase:" .. closest_airbase.airbase_name .. " has reached max task limit.")
                    end
                end
            end
            table.insert(unavail_airbases,closest_airbase.name)
            closest_airbase,_ = to_zone:getClosestZone(side,unavail_airbases,{ZoneTypes.AIRBASE})
            loop_prevention = loop_prevention+1
        end
        if loop_prevention >395 then MissionLogger:warn("Loop prevention prevented crash") end
        return nil,nil
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

        pcall(function()
            ship_controller:setOption(AI.Option.Naval.id.ROE, AI.Option.Naval.val.ROE.OPEN_FIRE)
        end)

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
        timer.scheduleFunction(startMoving, {}, timer.getTime() + 5)
    end

    ---@param convoy_gr_name string
    ---@param side coalition.side
    ---@param to_zone ZoneHandler
    ---@param from_zone ZoneHandler
    function TaskManager:setATTACKCONVOYTask(convoy_gr_name,side,to_zone, from_zone)
        timer.scheduleFunction(function ()
            local convoy_gr = Group.getByName(convoy_gr_name)
            if not convoy_gr or not convoy_gr:isExist() then MissionLogger:info("Capture Convoy spawn failed, no convoy sent") return end
    
            local enemy_units
            if side == coalition.side.BLUE then
                enemy_units = utils.getUnitsInZoneObj(to_zone, coalition.side.RED)
            elseif side == coalition.side.RED then
                enemy_units = utils.getUnitsInZoneObj(to_zone, coalition.side.BLUE)
            end

            local arrival_point
            if enemy_units and #enemy_units > 0 then
                arrival_point = enemy_units[1]:getPoint()
            else
                -- Check for statics in the zone
                for _, static_name in pairs(to_zone.linked_statics or {}) do
                    local static_obj = StaticObject.getByName(static_name)
                    if static_obj and static_obj:isExist() then
                        arrival_point = static_obj:getPoint()
                        break
                    end
                end
                if not arrival_point then
                    arrival_point = to_zone.zone.point
                end
            end
            self:ConvoyToPoint(convoy_gr,arrival_point)

            EnrouteManager:add({
                group_name = convoy_gr_name,
                to_zone = to_zone,
                from_zone = from_zone,
                side = side,
                ai_task_type = AITaskTypes.ATTACK_CONVOY,
                redirects_count = 0,
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

            -- 7. Set AI options for AWACS (run, don't fight)
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
            for _,grp_name in ipairs(groups_to_attack) do
                local grp = Group.getByName(grp_name)
                if grp and grp:isExist() then
                    table.insert(viable_ids,grp:getID())
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

            -- Waypoint 2: CAS ATTACK (Fly to target zone and execute the attack)
            table.insert(missionTask.params.route.points, {
                type = AI.Task.WaypointType.TURNING_POINT,
                x = enroute_data.to_zone.zone.point.x,
                y = enroute_data.to_zone.zone.point.z,
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
            local grp_to_attack = Group.getByName(enroute_data.to_zone.linked_groups[1])
            if not grp_to_attack or not grp_to_attack:isExist() then return false end
            local grp_to_attack_id = grp_to_attack:getID()

            local sead_gr = Group.getByName(sead_group_name)
            if not (sead_gr and sead_gr:isExist() and grp_to_attack_id) then return false end

            local ctrl = sead_gr:getController()

            -- 2. Calculate Positions
            local startPos = mist.getLeadPos(sead_group_name) -- Current Airbase pos
            if not startPos then return false end
            local targetPos = enroute_data.to_zone.zone.point -- Enemy SAM pos
            
            -- Calculate vector from Start to Target
            local vecX = targetPos.x - startPos.x
            local vecZ = targetPos.z - startPos.z
            local distance = math.sqrt(vecX^2 + vecZ^2)
            
            -- Define Standoff Distance (e.g., 25km / 25000 meters)
            -- If the total distance is short (<30km), just go 75% of the way.
            local standOffDist = 25000 
            local ratio = 0.75
            
            if distance > standOffDist then
                ratio = (distance - standOffDist) / distance
            end

            -- This is the "Launch Point" ~25km short of the SAM
            local ipPos = {
                x = startPos.x + (vecX * ratio),
                y = startPos.z + (vecZ * ratio)
            }

            -- 3. Attack Task
            local attackTask = {
                id = 'AttackGroup',
                params = {
                    groupId = grp_to_attack_id,
                    groupAttack = true,
                    expend = AI.Task.WeaponExpend.ALL,
                    altitudeEnabled = true,
                    altitude = mist.utils.feetToMeters(30000),
                    weaponType = 4161536 -- Only allow ASM (Anti-Radiation/Anti-Ship) to prevent gun runs
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
            
            -- RTB if out of Anti-Radiation Missiles
            ctrl:setOption(AI.Option.Air.id.RTB_ON_OUT_OF_AMMO, 4161536) 
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

    ---@param arrival_point vec3
    ---@param convoy_group Group
    function TaskManager:ConvoyToPoint(convoy_group,arrival_point)
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

        convoy_group:getController():setTask({ id = 'Mission', params = { route = { points = points } } })
    end

end