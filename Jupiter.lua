-- This file allows easy dev commands to be run directly from DCS
Jupiter = {}

-- Helper to get Color Enums safely
local function getSmokeColor(colorStr)
    local c = colorStr and colorStr:lower() or "red"
    if c == "green" then return trigger.smokeColor.GREEN
    elseif c == "white" then return trigger.smokeColor.WHITE
    elseif c == "orange" then return trigger.smokeColor.ORANGE
    elseif c == "blue" then return trigger.smokeColor.BLUE
    else return trigger.smokeColor.RED end
end

local function getFlareColor(colorStr)
    local c = colorStr and colorStr:lower() or "red"
    if c == "green" then return trigger.flareColor.GREEN
    elseif c == "white" then return trigger.flareColor.WHITE
    elseif c == "yellow" then return trigger.flareColor.YELLOW
    else return trigger.flareColor.RED end
end

function Jupiter:onEvent(event)
    -- Only handle Mark Added events
    if event.id == world.event.S_EVENT_MARK_CHANGE then
        
        local text = event.text
        local vec3 = event.pos
        local markId = event.idx
        MissionLogger:info(text)
        -- 1. Validation: Must have text and start with "-"
        if not text or text:sub(1, 1) ~= "-" then
            return 
        end

        -- 2. Parse command and arguments
        -- e.g., "-explosion 300" becomes {"-explosion", "300"}
        local args = {}
        for word in text:gmatch("%S+") do
            table.insert(args, word)
        end
        
        local command = args[1]:lower()
        local param1 = args[2]
        
        local cmd_executed = false

        -- === COMMAND: EXPLOSION ===
        if command == "-explosion" then
            local power = tonumber(param1) or 100 -- Default 100kg HE
            trigger.action.explosion(vec3, power)
            trigger.action.outText(string.format("Jupiter: Boom! Power: %d", power), 5)
            cmd_executed = true

        -- === COMMAND: SMOKE ===
        elseif command == "-smoke" then
            local color = getSmokeColor(param1)
            trigger.action.smoke(vec3, color)
            trigger.action.outText("Jupiter: Smoke marker deployed.", 5)
            cmd_executed = true

        -- === COMMAND: FLARE ===
        elseif command == "-flare" then
            local color = getFlareColor(param1)
            local azimuth = 0
            trigger.action.signalFlare(vec3, color, azimuth)
            trigger.action.outText("Jupiter: Flare deployed.", 5)
            cmd_executed = true

        elseif command == "-discover" then
            -- Add all zones to discovered_zones within radius
            local radius = tonumber(param1) or 10000 -- Default 10km radius
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
        elseif command == "-getwarehouse" then
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
                    else
                        trigger.action.outText("Jupiter: No airbase found for zone "..zone.name, 5)
                    end
                end
            end

        elseif command == "-logzones" then
            MissionLogger:info(zones)
            cmd_executed = true
        elseif command == "-logenroutes" then
            MissionLogger:info(EnrouteManager.enroutes)
            cmd_executed = true
        elseif command == "-addtokens" then
            local tokens_to_add = tonumber(param1) or 10
            -- Find all players within 500m of the marker
            local volS = {
                id = world.VolumeType.SPHERE,
                params = { point = vec3, radius = 500 }
            }
            local players_found = 0
            local function addTokensToPlayer(obj, val)
                if obj and obj:isExist() and obj.getPlayerName then
                    local user = ExperienceManager:fetchUser(obj)
                    if user then
                        user.tokens = user.tokens + tokens_to_add
                        trigger.action.outTextForUnit(user.id, string.format("Jupiter: You have been awarded %d tokens!", tokens_to_add), 10)
                        players_found = players_found + 1
                    end
                end
                return true
            end
            
            world.searchObjects({Object.Category.UNIT}, volS, addTokensToPlayer)
            trigger.action.outText(string.format("Jupiter: Added %d tokens to %d players within 500m.", tokens_to_add, players_found), 5)
            cmd_executed = true

        -- === COMMAND: DESTROY (Area of Effect) ===
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
trigger.action.outText("Jupiter Command Handler Loaded. Use markers starting with '-' on F10 map.", 10)