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