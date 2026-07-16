ATIS = {}

ATIS.functional = false

-- NATO phonetic alphabet for ATIS information letters
ATIS.nato_alphabet = {
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot",
    "Golf", "Hotel", "India", "Juliett", "Kilo", "Lima",
    "Mike", "November", "Oscar", "Papa", "Quebec", "Romeo",
    "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "Xray",
    "Yankee", "Zulu"
}

-- Tracks current information letter for each airbase by name
ATIS.airbaseInformation = {}

-- ATIS information letter changes every mission hour.
ATIS.info_change_interval_seconds = 30*60

-- Sound durations extracted from MOOSE ATIS.Sound table
ATIS.soundDurations = {
    ["ATIS/ActiveRunway.ogg"] = 0.85,
    ["ATIS/ActiveRunwayDeparture.ogg"] = 1.50,
    ["ATIS/ActiveRunwayArrival.ogg"] = 1.38,
    ["ATIS/AdviceOnInitial.ogg"] = 2.98,
    ["ATIS/Airport.ogg"] = 0.55,
    ["ATIS/Altimeter.ogg"] = 0.91,
    ["ATIS/At.ogg"] = 0.32,
    ["ATIS/CloudBase.ogg"] = 0.69,
    ["ATIS/CloudCeiling.ogg"] = 0.53,
    ["ATIS/CloudsBroken.ogg"] = 0.81,
    ["ATIS/CloudsFew.ogg"] = 0.74,
    ["ATIS/CloudsNo.ogg"] = 0.69,
    ["ATIS/CloudsNotAvailable.ogg"] = 2.64,
    ["ATIS/CloudsOvercast.ogg"] = 0.82,
    ["ATIS/CloudsScattered.ogg"] = 0.89,
    ["ATIS/Decimal.ogg"] = 0.71,
    ["ATIS/DegreesCelsius.ogg"] = 1.08,
    ["ATIS/DegreesFahrenheit.ogg"] = 1.07,
    ["ATIS/DewPoint.ogg"] = 0.59,
    ["ATIS/Dust.ogg"] = 0.37,
    ["ATIS/Elevation.ogg"] = 0.92,
    ["ATIS/EndOfInformation.ogg"] = 1.24,
    ["ATIS/Feet.ogg"] = 0.34,
    ["ATIS/Fog.ogg"] = 0.41,
    ["ATIS/Gusting.ogg"] = 0.58,
    ["ATIS/HectoPascal.ogg"] = 0.92,
    ["ATIS/Hundred.ogg"] = 0.53,
    ["ATIS/ILSFrequency.ogg"] = 1.30,
    ["ATIS/InchesOfMercury.ogg"] = 1.26,
    ["ATIS/Information.ogg"] = 0.99,
    ["ATIS/InnerNDBFrequency.ogg"] = 1.69,
    ["ATIS/Kilometers.ogg"] = 0.93,
    ["ATIS/Knots.ogg"] = 0.46,
    ["ATIS/Left.ogg"] = 0.41,
    ["ATIS/MegaHertz.ogg"] = 0.83,
    ["ATIS/Meters.ogg"] = 0.55,
    ["ATIS/MetersPerSecond.ogg"] = 1.03,
    ["ATIS/Miles.ogg"] = 0.44,
    ["ATIS/MillimetersOfMercury.ogg"] = 1.59,
    ["ATIS/Minus.ogg"] = 0.55,
    ["ATIS/N0.ogg"] = 0.52,
    ["ATIS/N1.ogg"] = 0.35,
    ["ATIS/N2.ogg"] = 0.41,
    ["ATIS/N3.ogg"] = 0.34,
    ["ATIS/N4.ogg"] = 0.37,
    ["ATIS/N5.ogg"] = 0.40,
    ["ATIS/N6.ogg"] = 0.46,
    ["ATIS/N7.ogg"] = 0.52,
    ["ATIS/N8.ogg"] = 0.36,
    ["ATIS/N9.ogg"] = 0.51,
    ["ATIS/NauticalMiles.ogg"] = 0.93,
    ["ATIS/None.ogg"] = 0.33,
    ["ATIS/OuterNDBFrequency.ogg"] = 1.70,
    ["ATIS/PRMGChannel.ogg"] = 1.27,
    ["ATIS/QFE.ogg"] = 0.90,
    ["ATIS/QNH.ogg"] = 0.94,
    ["ATIS/Rain.ogg"] = 0.35,
    ["ATIS/Right.ogg"] = 0.31,
    ["ATIS/RSBNChannel.ogg"] = 1.26,
    ["ATIS/RunwayLength.ogg"] = 0.81,
    ["ATIS/Snow.ogg"] = 0.40,
    ["ATIS/SnowStorm.ogg"] = 0.73,
    ["ATIS/StatuteMiles.ogg"] = 0.90,
    ["ATIS/SunriseAt.ogg"] = 0.82,
    ["ATIS/SunsetAt.ogg"] = 0.87,
    ["ATIS/TACANChannel.ogg"] = 0.81,
    ["ATIS/Temperature.ogg"] = 0.70,
    ["ATIS/Thousand.ogg"] = 0.58,
    ["ATIS/ThunderStorm.ogg"] = 0.79,
    ["ATIS/TimeLocal.ogg"] = 0.83,
    ["ATIS/TimeZulu.ogg"] = 0.83,
    ["ATIS/TowerFrequency.ogg"] = 1.05,
    ["ATIS/Visibility.ogg"] = 1.16,
    ["ATIS/VORFrequency.ogg"] = 1.28,
    ["ATIS/WeatherPhenomena.ogg"] = 1.09,
    ["ATIS/WindFrom.ogg"] = 0.63,
    ["ATIS/Zulu.ogg"] = 0.51,
    ["ATIS/Caucasus/Vaziani.ogg"] = 1.3,
    -- MOOSE 73257
}

function ATIS:init()
    if Config.ATIS_enabled == false then
        return
    end

    -- Register sound durations with SoundQueuer
    local stagger_delay = 0

    SoundQueuer:setDurations(self.soundDurations)
    for _,zone in ipairs(zones) do
        if zone.zone_type == ZoneTypes.AIRBASE then
            if Config.ATIS_frequencies[zone.airbase_name] then
                local freq = Config.ATIS_frequencies[zone.airbase_name]
                self:startAirbaseLoop(zone, freq, stagger_delay)

                stagger_delay = stagger_delay +3
            end
        end
    end
end

---@param report_sequence string[]
---@return number
function ATIS:getSequenceCycleInterval(report_sequence)
    local sequence_duration = 0
    for _, sound in ipairs(report_sequence) do
        local duration = SoundQueuer.sound_lengths[sound] or SoundQueuer.default_duration
        sequence_duration = sequence_duration + duration + SoundQueuer.default_gap
    end

    -- Keep the same spacing behavior as SoundQueuer's internal loop scheduling.
    return 5 + sequence_duration + 5
end

---@param airbase_name string
---@return string
function ATIS:getInformationLetter(airbase_name)
    local mission_hours_elapsed = math.floor(timer.getTime() / self.info_change_interval_seconds)
    local airbase_offset = self.airbaseInformation[airbase_name] or 0
    local information_index = ((mission_hours_elapsed + airbase_offset) % #self.nato_alphabet) + 1
    return self.nato_alphabet[information_index]
end

---@param zone ZoneHandler
---@param freq number Hz
---@param start_delay number|nil
function ATIS:startAirbaseLoop(zone, freq, start_delay)
    local cycle_interval = self:reportAirbase(zone, freq, start_delay)
    if not cycle_interval then return end

    timer.scheduleFunction(function()
        ATIS:startAirbaseLoop(zone, freq, 0)
    end, nil, timer.getTime() + cycle_interval)
end

---@class ATISREPORT
---@field active_runway number
---@field wind_direction number 1-360
---@field wind_velocity number in m/s
---@field cloud_cover number in octas
---@field temperature number in celcius
---@field qnh number
---@field information string NATO alphabet


ATIS.weather = {}

---@param airbase_zone ZoneHandler
function ATIS:fetchWeather(airbase_zone)
    if not env.mission.weather then return end
    if env.mission.weather and env.mission.weather.clouds then

        if not airbase_zone.airbase_name then return end
        local airbase = Airbase.getByName(airbase_zone.airbase_name)
        if not airbase then return end

      local wind = atmosphere.getWind(airbase:getPoint())

        ---Credits to funkyfranky for wind direction calculation
        ---@diagnostic disable-next-line: deprecated
        local wind_direction = math.deg(math.atan2(wind.z, wind.x))

        if wind_direction < 0 then
            wind_direction = wind_direction + 360
        end
        
        -- Convert TO direction to FROM direction. 
        if wind_direction > 180 then
            wind_direction = wind_direction-180
        else
            wind_direction = wind_direction+180
        end
        

        local wind_velocity = math.sqrt((wind.x)^2+(wind.z)^2)
        local temperature = env.mission.weather.temperature or 15  -- Default 15°C if not available
        local qnh = env.mission.weather.qnh or 1013  -- Default 1013 hPa if not available

        local runways = airbase:getRunways()
        local active_runway = nil
        
        -- Select runway with best headwind alignment
        if runways then
            local best_runway = nil
            local best_headwind_alignment = math.huge
            
            for _, runway in ipairs(runways) do
                -- Skip helipads and short strips disguised as runways
                if runway.length and runway.length > 500 then
                    
                    local heading1 = mist.utils.toDegree(-1*runway.course) % 360
                    if heading1 <= 0 then
                        heading1 = heading1 + 360
                    end
                    local heading2 = (heading1 + 180) % 360
                    
                    -- Calculate shortest angular distance for each direction
                    local function angleDiff(angle1, angle2)
                        local diff = math.abs(angle1 - angle2)
                        return math.min(diff, 360 - diff)
                    end
                    
                    local diff1 = angleDiff(wind_direction, heading1)
                    local diff2 = angleDiff(wind_direction, heading2)
                    
                    if diff1 < best_headwind_alignment then
                        best_headwind_alignment = diff1
                        best_runway = heading1
                    end
                    
                    if diff2 < best_headwind_alignment then
                        best_headwind_alignment = diff2
                        best_runway = heading2
                    end
                end
            end
            active_runway = best_runway
        end

        -- Get cloud cover (octas: 0-8)
        local cloud_cover = 0
        if env.mission.weather.clouds.density then
            cloud_cover = env.mission.weather.clouds.density
        end

        local information = self:getInformationLetter(airbase_zone.airbase_name)

        ---@type ATISREPORT
        return {
            active_runway = active_runway or 360,
            wind_direction = wind_direction,
            wind_velocity = wind_velocity,
            cloud_cover = cloud_cover,
            temperature = temperature,
            qnh = qnh,
            information = information
        }
    end
end


---@param zone ZoneHandler
---@param freq number Hz
---@param start_delay number|nil
function ATIS:reportAirbase(zone,freq,start_delay)
    if zone.zone_type ~= ZoneTypes.AIRBASE then return end

    --if zone.name ~= "VAZIANI" then return end
    -- Fetch weather data
    local report = self:fetchWeather(zone)
    if not report then
        trigger.action.outText("Failed to fetch ATIS weather data", 10)
        return
    end
    --MissionLogger:info(report)

    -- Build sound sequence from report
    local sequence = {}

    table.insert(sequence, "ATIS/Caucasus/"..zone.airbase_name..".ogg")
    table.insert(sequence, "ATIS/Information.ogg")
    table.insert(sequence, "ATIS/NATO Alphabet/"..report.information..".ogg")

    -- Active runway
    table.insert(sequence, "ATIS/ActiveRunway.ogg")
    local runway_heading = math.floor(report.active_runway/10)
    -- MissionLogger:info("Report heading "..report.active_runway)
    -- MissionLogger:info("Runway heading "..runway_heading)
    if runway_heading == 0 then
        runway_heading = 360
    end
    local active_runway_two_digits = string.format("%02d", runway_heading)

    for digit in active_runway_two_digits:gmatch(".") do
        table.insert(sequence, "ATIS/N-" .. digit .. ".ogg")
    end


    -- Add wind
    table.insert(sequence, "ATIS/WindFrom.ogg")
    -- Wind direction digits
    local windDirStr = string.format("%03d", math.floor(report.wind_direction))
    for digit in windDirStr:gmatch(".") do
        table.insert(sequence, "ATIS/N-" .. digit .. ".ogg")
    end

    -- Wind speed
    table.insert(sequence, "ATIS/At.ogg")

    local windSpeed = mist.utils.mpsToKnots(report.wind_velocity)
    local speedStr = string.format("%d", windSpeed)
    for digit in speedStr:gmatch(".") do
        table.insert(sequence, "ATIS/N-" .. digit .. ".ogg")
    end
    table.insert(sequence, "ATIS/Knots.ogg")
    
    -- Temperature
    table.insert(sequence, "ATIS/Temperature.ogg")
    if report.temperature then
        local tempStr = string.format("%d", math.floor(report.temperature))
        for digit in tempStr:gmatch(".") do
            table.insert(sequence, "ATIS/N-" .. digit .. ".ogg")
        end
        table.insert(sequence, "ATIS/DegreesCelsius.ogg")
    end
    
    -- QNH
    table.insert(sequence, "ATIS/QNH.ogg")
    if report.qnh then
        local qnhStr = string.format("%d", math.floor(report.qnh))
        for digit in qnhStr:gmatch(".") do
            table.insert(sequence, "ATIS/N-" .. digit .. ".ogg")
        end
        table.insert(sequence, "ATIS/HectoPascal.ogg")
    end
    
    -- End
    table.insert(sequence, "ATIS/AdviceOnInitial.ogg")
    table.insert(sequence, "ATIS/NATO Alphabet/"..report.information..".ogg")
    table.insert(sequence, "ATIS/EndOfInformation.ogg")

    SoundQueuer:enqueueSequence(sequence,zone.zone.point,radio.modulation.AM,freq,10,false,start_delay)

    return self:getSequenceCycleInterval(sequence)
end