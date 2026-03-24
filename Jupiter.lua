--[[
    Jupiter is desiged to help missions admins and developers by implementing tools directly in game.
]]
Jupiter = {}

-- Helper to get Color Enums safely
local function getSmokeColor(colorStr)
    local c = colorStr and colorStr:lower() or "red"
    if c == "green" then return trigger.smokeColor.Green
    elseif c == "white" then return trigger.smokeColor.White
    elseif c == "orange" then return trigger.smokeColor.Orange
    elseif c == "blue" then return trigger.smokeColor.Blue
    else return trigger.smokeColor.Red end
end

local function getFlareColor(colorStr)
    local c = colorStr and colorStr:lower() or "red"
    if c == "green" then return trigger.flareColor.Green
    elseif c == "white" then return trigger.flareColor.White
    elseif c == "yellow" then return trigger.flareColor.Yellow
    else return trigger.flareColor.Red end
end

local function getClosestZone(vec3)
    local closest_zone = nil
    local closest_dist = math.huge
    for _, zone in pairs(zones) do
        local dist = mist.utils.get2DDist(vec3, zone.zone.point)
        if dist < closest_dist then
            closest_dist = dist
            closest_zone = zone
        end
    end
    return closest_zone, closest_dist
end

Jupiter.user_ids = {}

function Jupiter:onEvent(event)
    -- Only handle Mark Added events
    if event.id == world.event.S_EVENT_MARK_CHANGE then
        
        local text = event.text
        local vec3 = event.pos
        local markId = event.idx
        MissionLogger:info(text)

        -- 1. Check for password if set
        if Config.jupiter_password and Config.jupiter_password ~= "" then
            local password_prefix = Config.jupiter_password .. "-"
            if text:sub(1, #password_prefix) ~= password_prefix then
                return
            else
                text = "-" .. text:sub(#password_prefix + 1)
            end
        end

        -- 2. Validation: Must have text and start with "-"
        if not text or text:sub(1, 1) ~= "-" then
            return
        end

        -- 3. Parse command and arguments
        -- e.g., "-explosion 300" becomes {"-explosion", "300"}
        local args = {}
        for word in text:gmatch("%S+") do
            table.insert(args, word)
        end
        
        local command = args[1]:lower()
        local param1 = args[2]
        
        local cmd_executed = false

        if command == "-explosion" then
            local power = tonumber(param1) or 100 -- Default 100kg HE
            trigger.action.explosion(vec3, power)
            trigger.action.outText(string.format("Jupiter: Boom! Power: %d", power), 5)
            cmd_executed = true

        elseif command == "-smoke" then
            local color = getSmokeColor(param1)
            trigger.action.smoke(vec3, color)
            trigger.action.outText("Jupiter: Smoke marker deployed.", 5)
            cmd_executed = true

        elseif command == "-flare" then
            local color = getFlareColor(param1)
            local azimuth = 0
            trigger.action.signalFlare(vec3, color, azimuth)
            trigger.action.outText("Jupiter: Flare deployed.", 5)
            cmd_executed = true
        elseif command == "-levelup" then
            -- Level up the closest zone within 10km
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                closest_zone.level = closest_zone.level + 1
                UnitHandler.updateZoneUnits(closest_zone)
                closest_zone:drawF10()
                trigger.action.outText("Jupiter: Leveled up zone: "..closest_zone.name, 5)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km to level up.", 5)
            end
        elseif command == "-addsuppliesblue" then
            local supplies_to_add = tonumber(param1) or 500
            stats.blue_supplies = stats.blue_supplies + supplies_to_add
            trigger.action.outText("Jupiter: Added "..supplies_to_add.." supplies to BLUE coalition. Total: "..stats.blue_supplies, 5)
            cmd_executed = true
        elseif command == "-addsuppliesred" then
            local supplies_to_add = tonumber(param1) or 500
            stats.red_supplies = stats.red_supplies + supplies_to_add
            trigger.action.outText("Jupiter: Added "..supplies_to_add.." supplies to RED coalition. Total: "..stats.red_supplies, 5)
            cmd_executed = true
        elseif command == "-setlevel" then
            local level = tonumber(param1) or 1
            -- Set level of the closest zone within 10km
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                closest_zone.level = level
                UnitHandler.updateZoneUnits(closest_zone)
                closest_zone:drawF10()
                trigger.action.outText("Jupiter: Set zone "..closest_zone.name.." to level: "..level, 5)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km to set level.", 5)
            end
        elseif command == "-clearctldassets" then
            ctld.placed_assets = {}
            ctld.FARPs = {}
            trigger.action.outText("Jupiter: Cleared all CTLD cached placed assets.", 5)
            cmd_executed = true
        elseif command == "-logstats" then
            MissionLogger:info(stats)
            cmd_executed = true
        elseif command == "-discover" then
            -- Add all zones to discovered_zones within radius
            local radius = tonumber(param1) or 10000 -- Default 10km radius
            if type(param1) == "string" and param1:lower() == "all" then
                radius = math.huge
            end
            for _, zone in pairs(zones) do
                if mist.utils.get2DDist(vec3, zone.zone.point) <= radius then
                    if not utils.tableContains(stats.blue_discovered_zones,zone.name) then
                        table.insert(stats.blue_discovered_zones,zone.name)
                        zone:drawF10()
                        CommandHandler.requestMenuRefresh(coalition.side.BLUE)
                        cmd_executed = true
                    elseif not utils.tableContains(stats.red_discovered_zones,zone.name) then
                        table.insert(stats.red_discovered_zones,zone.name)
                        zone:drawF10()
                        CommandHandler.requestMenuRefresh(coalition.side.RED)
                        cmd_executed = true
                        -- trigger.action.outTextForCoalition(unit_coalition, "Recon reports newly detected targets in: "..zone.name,15)
                    end
                end
            end
        elseif command == "-dispatch" then
            TheatreCommander:evaluateAITasks(coalition.side.BLUE)
            TheatreCommander:evaluateAITasks(coalition.side.RED)
            cmd_executed = true
        elseif command == "-save" then
            PersistenceManager:saveMissionToFile()
            PersistenceManager:saveUserDataToFile()
            trigger.action.outText("Jupiter: Mission saved.", 15)
            cmd_executed = true
        elseif command == "-sendattackconvoy" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.ATTACK_CONVOY,closest_zone.side,true,nil,closest_zone,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for Attack Convoy tasking.", 5)
            end
        elseif command == "-additemwarehouse" then
            local item_flag = param1
            local quantity = tonumber(args[3]) or 10
            if item_flag then
                for _, zone in pairs(zones) do
                    if mist.utils.get2DDist(vec3, zone.zone.point) <= 2000 and zone.zone_type == ZoneTypes.AIRBASE then
                        local airbase = Airbase.getByName(zone.airbase_name)
                        if airbase then
                            local wh = airbase:getWarehouse()
                            wh:addItem(item_flag, quantity)
                        end
                        trigger.action.outText("Jupiter: Added "..quantity.." of "..item_flag.." to "..zone.airbase_name.." warehouse.", 5)
                        cmd_executed = true
                    end
                end
            end
        elseif command == "-getwarehouse" then
            param1 = Airbases.Caucasus.Beslan
            if param1 then
                local airbase = Airbase.getByName(param1)
                if airbase then
                    local wh = airbase:getWarehouse():getInventory()
                    MissionLogger:info(wh)
                    trigger.action.outText("Jupiter: warehouse inventory logged", 5)
                    trigger.action.outText(mist.utils.tableShow(wh),25)
                    cmd_executed = true
                else
                    trigger.action.outText("Jupiter: No airbase found for airbase "..param1, 5)
                end
            end
            if not cmd_executed then
                for _, zone in pairs(zones) do
                    if mist.utils.get2DDist(vec3, zone.zone.point) <= 2000 and zone.zone_type == ZoneTypes.AIRBASE then
                        local airbase = Airbase.getByName(zone.airbase_name)
                        if airbase then
                            local wh = airbase:getWarehouse():getInventory()
                            MissionLogger:info("Warehouse inventory for "..zone.airbase_name..":")
                            MissionLogger:info(wh)
                            trigger.action.outText("Jupiter: .."..zone.name.." warehouse inventory", 5)
                            trigger.action.outText(mist.utils.tableShow(wh),25)
                            cmd_executed = true
                        end
                    end
                end
            end

        elseif command == "-logzones" then
            MissionLogger:info(zones)
            cmd_executed = true
        elseif command == "-logenroutes" then
            MissionLogger:info(EnrouteManager.enroutes)
            cmd_executed = true
        elseif command == "-logtriggerzones" then
            local zone_names = {}
            for k, v in ipairs(env.mission.triggers.zones) do
                table.insert(zone_names, v.name)
            end
            MissionLogger:info(zone_names)
            cmd_executed = true
        elseif command == "-activeunits" then
            local b_gr = coalition.getGroups(coalition.side.BLUE)
            local r_gr = coalition.getGroups(coalition.side.RED)

            local units = 0
            for _,gr in pairs(b_gr) do
                if gr and gr.isExist and gr:isExist() then
                    units = units + #gr:getUnits()
                end
            end
            for _,gr in pairs(r_gr) do
                if gr and gr.isExist and gr:isExist() then
                    units = units + #gr:getUnits()
                end
            end

            trigger.action.outText("Active groups: "..#b_gr+#r_gr.."\nActive units: "..units,15)
            cmd_executed = true

        elseif command == "-destroy" then
            local radius = tonumber(param1) or 5000 -- Default 5000m radius
            local count = 0
            
            -- Define search volume
            local volS = {
                id = world.VolumeType.SPHERE,
                params = { point = vec3, radius = radius }
            }
            
            -- Callback function to destroy found objects
            local function killObject(obj, val)
                if obj and obj:isExist() then
                    obj:destroy()
                    count = count + 1
                end
                return true
            end
            
            world.searchObjects({Object.Category.UNIT,Object.Category.STATIC}, volS, killObject)
            
            trigger.action.outText(string.format("Jupiter: Destroyed %d objects in %dm radius.", count, radius), 5)
            cmd_executed = true
        elseif command == "-sendcas" then
            local side_sending = coalition.side.BLUE
            if param1 == "blue" then
                side_sending = coalition.side.BLUE
            elseif param1 == "red" then
                side_sending = coalition.side.RED
            end
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 and side_sending ~= closest_zone.side then
                TaskManager:initiateAITask(AITaskTypes.CAS,side_sending,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for CAS tasking.", 5)
            end
        elseif command == "-sendjtac" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.JTAC,coalition.side.BLUE,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for JTAC tasking.", 5)
            end
        elseif command == "-sendstrike" then
            local side_sending = coalition.side.BLUE
            if param1 == "blue" then
                side_sending = coalition.side.BLUE
            elseif param1 == "red" then
                side_sending = coalition.side.RED
            end
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.STRIKE,side_sending,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for Strike tasking.", 5)
            end
        elseif command == "-sendsead" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.SEAD,coalition.side.BLUE,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for SEAD tasking.", 5)
            end
        elseif command == "-sendcap" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.CAP,coalition.side.BLUE,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for CAP tasking.", 5)
            end
        elseif command == "-sendawacs" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.AWACS,coalition.side.BLUE,true,nil,closest_zone,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for AWACS tasking.", 5)
            end
        elseif command == "-sendrecon" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                TaskManager:initiateAITask(AITaskTypes.RECON,coalition.side.BLUE,true,closest_zone,nil,true)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for Recon tasking.", 5)
            end
        elseif command == "-sendresupply" then
            TheatreCommander.sendWarehouseResupply(coalition.side.BLUE,false)
            TheatreCommander.sendWarehouseResupply(coalition.side.RED,false)
            cmd_executed = true
        elseif command == "-resupply" then
            if param1 == "help" then
                trigger.action.outText(mist.utils.tableShow(WarehouseManager.StockTypes),25)
                cmd_executed = true
            else
                local stocktype_num = tonumber(param1) or 1
                local closest_zone, dist = getClosestZone(vec3)
                if closest_zone and dist <= 10000 and closest_zone.airbase_name then
                    WarehouseManager:attributeAirbaseStock(closest_zone.airbase_name,coalition.side.BLUE,
                        {stocktype_num})
                    cmd_executed = true
                else
                    trigger.action.outText("Jupiter: No airbase found within 10km for giving stock.", 5)
                end
            end
        elseif command == "-capture" then
            local closest_zone, dist = getClosestZone(vec3)
            if closest_zone and dist <= 10000 then
                closest_zone:capture(param1 == "red" and coalition.side.RED or coalition.side.BLUE)
                cmd_executed = true
            else
                trigger.action.outText("Jupiter: No zone found within 10km for capture.", 5)
            end
        elseif command == "-scalewarehouse" then
            local scale = tonumber(param1) or 1.0
            Scenario.estimated_users = math.max(1,scale)
            trigger.action.outText(string.format("Jupiter: Scaled warehouse stock calculations for %d users.", Scenario.estimated_users), 5)
            cmd_executed = true
        elseif command == "-addxp" then
            local xp_to_add = tonumber(param1) or 1000
            -- Find all players within 500m of the marker
            local volS = {
                id = world.VolumeType.SPHERE,
                params = { point = vec3, radius = 500 }
            }
            local players_found = 0
            local total_units = 0
            local function addXPToPlayer(obj, val)
                total_units = total_units + 1
                if obj and obj:isExist() and obj.getPlayerName then
                    local player_name = obj:getPlayerName()
                    if player_name then
                        local user = ExperienceManager:fetchUser(obj)
                        if user then
                            if ExperienceManager:addXP(user, xp_to_add) then
                                trigger.action.outTextForUnit(obj:getID(), string.format("Jupiter: You have been awarded %d XP!", xp_to_add), 10)
                                players_found = players_found + 1
                            end
                        end
                    end
                end
                return true
            end
            
            world.searchObjects({Object.Category.UNIT}, volS, addXPToPlayer)
            MissionLogger:info(string.format("Jupiter -addxp: Found %d units, %d were players", total_units, players_found))
            trigger.action.outText(string.format("Jupiter: Added %d XP to %d players within 500m. (Found %d units total)", xp_to_add, players_found, total_units), 5)
            cmd_executed = true
        end
        -- 3. Cleanup: Remove the map marker if a command was recognized
        timer.scheduleFunction(function()
            if cmd_executed then
                trigger.action.removeMark(markId)
            end
        end, {}, timer.getTime() + 2) -- slight delay to ensure command processes before removal
    end
end

-- Register the event handler
world.addEventHandler(Jupiter)
--trigger.action.outText("< Jupiter Command Handler Loaded >", 3)