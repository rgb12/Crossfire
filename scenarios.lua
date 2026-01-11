--[[
    scenarios.lua
    Crossfire Mission Scenarios

]]
---@class CoalSetup
---@field initial_dist_blue_to_frontline number
---@field auto_coalition_designation boolean
---@field dist_variance number

---@class LogisticsSetup
---@field upgrade_range number
---@field heli_capture_range number
---@field max_dist_to_frontline number

---@class CarrierSetup
---@field carrier_unit_name string
---@field enabled boolean

---@class Resupply
---@field blue_point vec3
---@field red_point vec3

---@class Scenario
---@field name string
---@field difficulty ScenarioDifficulty
---@field description string
---@field estimated_users number
---@field coalition_setup CoalSetup
---@field red_airbase ZoneHandler|nil
---@field blue_airbase ZoneHandler|nil
---@field logistics_setup LogisticsSetup
---@field carrier_setup CarrierSetup|nil
---@field resupply Resupply
---@field zones ZoneHandler[]

---@type Scenario[]
Scenarios = {
    {
        name = "Mercury Rising",
        description = "Full map takeover of Caucasus.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 75000, --meters
            dist_variance = 10000, --meters
            auto_coalition_designation = true, -- overrides the above if false
        },
        logistics_setup = {
            upgrade_range = 40000, --meters
            heli_capture_range = 120000, --meters
            max_dist_to_frontline = 65000 --meters
        },
        resupply = {
            blue_point = { x = 00006923, y = 6096, z = 00079849 },
            red_point = { x = -00326782, y = 6096, z = 00932890 }
        },
        estimated_users = 1,
        difficulty = ScenarioDifficulty.EXPERT,
        red_airbase = ZoneHandler:new({
            name = "ANAPA",
            airbase_name = Airbases.Caucasus.Anapa_Vityazevo,
            zone_type = ZoneTypes.AIRBASE,
            acft_resupply_point = {
                x = 00006923,
                y = 6096, 
                z = 00079849
            }
            }),
        blue_airbase =  ZoneHandler:new({
            name = "VAZIANI",
            zone_type = ZoneTypes.AIRBASE,
            airbase_name = Airbases.Caucasus.Vaziani,
            acft_resupply_point = {
                x = -00326782,
                y = 6096, --20k ft
                z = 00932890
            }
            }),
        zones = {
            -- Airbases
            ZoneHandler:new({ name = "BESLAN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Beslan }),
            ZoneHandler:new({ name = "MOZDOK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Mozdok }),
            ZoneHandler:new({ name = "NALCHIK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Nalchik }),
            ZoneHandler:new({ name = "MINERALNYE-VODY", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Mineralnye_Vody }),
            ZoneHandler:new({ name = "SOCHI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sochi_Adler }),
            ZoneHandler:new({ name = "SUKHUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sukhumi_Babushara }),
            ZoneHandler:new({ name = "SENAKI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Senaki_Kolkhi }),
            ZoneHandler:new({ name = "KUTAISI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kutaisi }),
            ZoneHandler:new({ name = "BATUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Batumi }),
            ZoneHandler:new({ name = "KRYMSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krymsk }),
            ZoneHandler:new({ name = "KOBULETI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kobuleti }),
            ZoneHandler:new({ name = "MAYKOP", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Maykop_Khanskaya }),
            ZoneHandler:new({ name = "KRASNODAR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krasnodar_Pashkovsky }),
            ZoneHandler:new({ name = "NOVOROSSIYSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Novorossiysk }),
            ZoneHandler:new({ name = "GELENDZHIK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Gelendzhik }),
            
            -- Strongpoints
            ZoneHandler:new({ name = "ALPHA" }),
            ZoneHandler:new({ name = "BRAVO" }),
            ZoneHandler:new({ name = "CHARLIE" }),
            ZoneHandler:new({ name = "DELTA" }),
            ZoneHandler:new({ name = "ECHO" }),
            ZoneHandler:new({ name = "FOXTROT" }),
            ZoneHandler:new({ name = "GOLF" }),
            ZoneHandler:new({ name = "HOTEL" }),
            ZoneHandler:new({ name = "JULIETT" }),
            ZoneHandler:new({ name = "KILO" }),
            ZoneHandler:new({ name = "LIMA" }),
            ZoneHandler:new({ name = "MIKE" }),
            ZoneHandler:new({ name = "NOVEMBER" }),
            ZoneHandler:new({ name = "OSCAR" }),
            ZoneHandler:new({ name = "PAPA" }),
            ZoneHandler:new({ name = "QUEBEC" }),
            ZoneHandler:new({ name = "ROMEO" }),
            ZoneHandler:new({ name = "TANGO" }),
            ZoneHandler:new({ name = "UNIFORM" }),
            ZoneHandler:new({ name = "VICTOR" }),
            ZoneHandler:new({ name = "WHISKEY" }),
            ZoneHandler:new({ name = "XRAY" }),
            ZoneHandler:new({ name = "YANKEE" }),
            ZoneHandler:new({ name = "ZULU" }),
            ZoneHandler:new({ name = "FIELDS" }),
            ZoneHandler:new({ name = "TEST" }),
            ZoneHandler:new({ name = "GOLD" }),
            ZoneHandler:new({ name = "GUDAUTA" }),
            ZoneHandler:new({ name = "ONI" }),
            ZoneHandler:new({ name = "AIRFIELD" }),
            ZoneHandler:new({ name = "FARM" }),
            ZoneHandler:new({ name = "SENAKI-CENTER" }),
            ZoneHandler:new({ name = "LAKE" }),
            ZoneHandler:new({ name = "AHALSOPELI" }),
            ZoneHandler:new({ name = "SEASIDE" }),
            ZoneHandler:new({ name = "PEREDOVAYA" }),
            ZoneHandler:new({ name = "OUTPOST" }),
            ZoneHandler:new({ name = "VALLEY" }),
            ZoneHandler:new({ name = "MOUNTAIN" }),
            ZoneHandler:new({ name = "GRIGOLISHI" }),
            ZoneHandler:new({ name = "HOUSES" }),
            ZoneHandler:new({ name = "ASSOKOLAY" }),
            ZoneHandler:new({ name = "LESOGORSKAYA" }),
            ZoneHandler:new({ name = "ACE" }),
            ZoneHandler:new({ name = "JOKER" }),
            ZoneHandler:new({ name = "ABINSK" }),
            ZoneHandler:new({ name = "JACK" }),
            ZoneHandler:new({ name = "HEVSHA" }),
            ZoneHandler:new({ name = "EDISA" }),
            ZoneHandler:new({ name = "GVERKI" }),
            ZoneHandler:new({ name = "SACHHERE" }),
            ZoneHandler:new({ name = "HEART" }),
            ZoneHandler:new({ name = "CLUB" }),
            ZoneHandler:new({ name = "PORT" }),
            ZoneHandler:new({ name = "BAY" }),
            ZoneHandler:new({ name = "STRONGHOLD" }),
            ZoneHandler:new({ name = "REFUGE" }),
            ZoneHandler:new({ name = "OBSERVATORY" }),
            ZoneHandler:new({ name = "COAST" }),
            ZoneHandler:new({ name = "VARDANE" }),
            ZoneHandler:new({ name = "LOO" }),
            ZoneHandler:new({ name = "SOCHI-CENTER" }),
            ZoneHandler:new({ name = "HOSTA" }),
            ZoneHandler:new({ name = "GUBSKAYA" }),
            ZoneHandler:new({ name = "TOWN" }),
            ZoneHandler:new({ name = "PSEBAY" }),
            ZoneHandler:new({ name = "DIAMOND" }),
            ZoneHandler:new({ name = "SPADE" }),
            ZoneHandler:new({ name = "QUEEN" }),
            ZoneHandler:new({ name = "KING" }),
            ZoneHandler:new({ name = "DEHVIRI" }),
            ZoneHandler:new({ name = "ABANOETI" }),
            ZoneHandler:new({ name = "LEDGEBE" }),
            ZoneHandler:new({ name = "KOKI" }),
            ZoneHandler:new({ name = "GALI" }),
            ZoneHandler:new({ name = "LABRA" }),
            ZoneHandler:new({ name = "ARADU" }),
            ZoneHandler:new({ name = "TKVARCHELI" }),
            ZoneHandler:new({ name = "HURZUK" }),
            ZoneHandler:new({ name = "KARACHAEVSK" }),
            ZoneHandler:new({ name = "SADON" }),
            ZoneHandler:new({ name = "VERHNIY" }),
            ZoneHandler:new({ name = "BURON" }),
            ZoneHandler:new({ name = "GLOLA" }),
            ZoneHandler:new({ name = "KEVIN" }),
            ZoneHandler:new({ name = "BYLYM" }),
            ZoneHandler:new({ name = "TEBERDA" }),
            ZoneHandler:new({ name = "SUBURBS" }),
            ZoneHandler:new({ name = "ATOTSI" }),
            ZoneHandler:new({ name = "ABISI" }),
            ZoneHandler:new({ name = "ALAGIR" }),
            ZoneHandler:new({ name = "TRAINING-AIRFIELD" }),
            ZoneHandler:new({ name = "LOG" }),
            ZoneHandler:new({ name = "CHECKPOINT-NORTH" }),
            ZoneHandler:new({ name = "CHECKPOINT-EAST" }),
            ZoneHandler:new({ name = "CHECKPOINT-WEST" }),
            ZoneHandler:new({ name = "CHECKPOINT-SOUTH" }),
            ZoneHandler:new({ name = "CHECKPOINT-ALPHA" }),
            ZoneHandler:new({ name = "CHECKPOINT-BRAVO" }),
            ZoneHandler:new({ name = "CHECKPOINT-CHARLIE" }),
            ZoneHandler:new({ name = "CHECKPOINT-DELTA" }),
            ZoneHandler:new({ name = "CHECKPOINT-ECHO" }),
            ZoneHandler:new({ name = "CHECKPOINT-FOXTROT" }),
            ZoneHandler:new({ name = "CHECKPOINT-GOLF" }),
            ZoneHandler:new({ name = "CHECKPOINT-HOTEL" }),
            ZoneHandler:new({ name = "CHECKPOINT-INDIA" }),
            ZoneHandler:new({ name = "CHECKPOINT-JULIETT" }),
            ZoneHandler:new({ name = "CHECKPOINT-KILO" }),
            ZoneHandler:new({ name = "CHECKPOINT-LIMA" }),
            ZoneHandler:new({ name = "CHECKPOINT-MIKE" }),
            ZoneHandler:new({ name = "CHECKPOINT-NOVEMBER" }),
            ZoneHandler:new({ name = "CHECKPOINT-OSCAR" }),
            ZoneHandler:new({ name = "CHECKPOINT-PAPA" }),
            ZoneHandler:new({ name = "CHECKPOINT-QUEBEC" }),
            ZoneHandler:new({ name = "CHECKPOINT-ROMEO" }),
            ZoneHandler:new({ name = "CHECKPOINT-SIERRA" }),
            ZoneHandler:new({ name = "CHECKPOINT-TANGO" }),
            ZoneHandler:new({ name = "CHECKPOINT-UNIFORM" }),
            ZoneHandler:new({ name = "CHECKPOINT-VICTOR" }),
            ZoneHandler:new({ name = "CHECKPOINT-WHISKEY" }),
            ZoneHandler:new({ name = "CHECKPOINT-XRAY" }),
            ZoneHandler:new({ name = "CHECKPOINT-YANKEE" }),
            ZoneHandler:new({ name = "CHECKPOINT-ZULU" }),
            ZoneHandler:new({ name = "OUTPOST-ALPHA" }),
            ZoneHandler:new({ name = "OUTPOST-BRAVO" }),
            ZoneHandler:new({ name = "OUTPOST-CHARLIE" }),
            ZoneHandler:new({ name = "OUTPOST-DELTA" }),
            ZoneHandler:new({ name = "OUTPOST-ECHO" }),
            ZoneHandler:new({ name = "OUTPOST-FOXTROT" }),
            ZoneHandler:new({ name = "OUTPOST-GOLF" }),
            ZoneHandler:new({ name = "OUTPOST-HOTEL" }),
            ZoneHandler:new({ name = "OUTPOST-INDIA" }),
            ZoneHandler:new({ name = "OUTPOST-JULIETT" }),
            ZoneHandler:new({ name = "OUTPOST-KILO" }),
            ZoneHandler:new({ name = "OUTPOST-LIMA" }),
            ZoneHandler:new({ name = "OUTPOST-MIKE" }),
            ZoneHandler:new({ name = "OUTPOST-NOVEMBER" }),
            ZoneHandler:new({ name = "OUTPOST-OSCAR" }),
            ZoneHandler:new({ name = "OUTPOST-ZULU" }),
            ZoneHandler:new({ name = "OUTPOST-DECEMBER" }),
            ZoneHandler:new({ name = "OUTPOST-SEPTEMBER" }),
        }
    },
    {
        name = "Georgia Liberation",
        description = "Liberate Georgia from invading forces.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 80000, --meters
            dist_variance = 5000, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 60000, --meters
            heli_capture_range = 150000, --meters
            max_dist_to_frontline = 80000 --meters
        },
        resupply = {
            --blue_point = { x=-00310000, y=2000,z=00901479}, --for dev
            blue_point = { x = -00318568, y = 6096, z = 00991378 },
            red_point = { x = -00290581, y = 6096, z = 00569411 }
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            enabled = true
        },
        estimated_users = 1,
        difficulty = ScenarioDifficulty.MEDIUM,
        red_airbase = ZoneHandler:new({
            name = "SENAKI",
            airbase_name = Airbases.Caucasus.Senaki_Kolkhi,
            zone_type = ZoneTypes.AIRBASE}),
        blue_airbase =  ZoneHandler:new({
            name = "VAZIANI",
            airbase_name = Airbases.Caucasus.Vaziani,
            zone_type = ZoneTypes.AIRBASE}),
        zones = {
            ZoneHandler:new({name = "OUTPOST-SEPTEMBER"}),
            ZoneHandler:new({name = "OUTPOST-NOVEMBER"}),
            ZoneHandler:new({name = "OUTPOST-DECEMBER"}),
            ZoneHandler:new({name = "JULIETT"}),
            ZoneHandler:new({name = "FOXTROT"}),
            ZoneHandler:new({name = "OUTPOST-OSCAR"}),
            ZoneHandler:new({name = "STRONGHOLD-BRAVO"}),
            ZoneHandler:new({name = "ALPHA"}),
            ZoneHandler:new({name = "STRONGHOLD-CHARLIE"}),
            ZoneHandler:new({name = "VICTOR"}),
            ZoneHandler:new({name = "HEVSHA"}),
            ZoneHandler:new({name = "WHISKEY"}),
            ZoneHandler:new({name = "EDISA"}),
            ZoneHandler:new({name = "GOLF"}),
            ZoneHandler:new({name = "ONI"}),
            ZoneHandler:new({name = "GLOLA"}),
            ZoneHandler:new({name = "SACHHERE"}),
            ZoneHandler:new({name = "LAKE"}),
            ZoneHandler:new({name = "OSCAR"}),
            ZoneHandler:new({name = "DEHVIRI"}),
            ZoneHandler:new({name = "GVERKI"}),
            ZoneHandler:new({name = "OUTPOST-INDIA"}),
            ZoneHandler:new({name = "AIRFIELD"}),
            ZoneHandler:new({name = "SUBURBS"}),
            ZoneHandler:new({name = "YANKEE"}),
            ZoneHandler:new({name = "FARM"}),
            ZoneHandler:new({name = "FIELDS"}),
            ZoneHandler:new({name = "CHECKPOINT-PAPA"}),
            ZoneHandler:new({name = "UNIFORM"}),
            ZoneHandler:new({name = "GRIGOLISHI"}),
            ZoneHandler:new({name = "NOVEMBER"}),
            ZoneHandler:new({name = "KOKI"}),
            ZoneHandler:new({name = "CHECKPOINT-QUEBEC"}),
            ZoneHandler:new({name = "TKVARCHELI"}),
            ZoneHandler:new({name = "LABRA"}),
            ZoneHandler:new({name = "BRAVO", zone_type = ZoneTypes.FARP,}),
            ZoneHandler:new({name = "DELTA", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "TRAINING-AIRFIELD", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "SEASIDE", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "GUDAUTA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Gudauta}),
            ZoneHandler:new({name = "SUKHUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sukhumi_Babushara}),
            ZoneHandler:new({name = "BATUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Batumi}),
            ZoneHandler:new({name = "KOBULETI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kobuleti}),
            ZoneHandler:new({name = "KUTAISI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kutaisi}),
        } -- 43 zones
    },
     {
        name = "Eastbound",
        description = "Achieve control over the the Russian Caucasus area.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 27000, --meters
            dist_variance = 0, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 30000, --meters
            heli_capture_range = 60000, --meters
            max_dist_to_frontline = 40000 --meters
        },
        resupply = {
            --blue_point = { x=-00005476, y=2000,z=00224066}, --for dev
            -- Metric: X-00005476 Z+00224066

            blue_point = { x = -2839, y = 6096, z = 192302 },
            red_point = { x = 42692, y = 6096, z = 429197 }
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            enabled = true
        },
        estimated_users = 1,
        difficulty = ScenarioDifficulty.EASY,
        red_airbase = ZoneHandler:new({
            name = "KRASNODAR",
            airbase_name = Airbases.Caucasus.Krasnodar_Pashkovsky,
            zone_type = ZoneTypes.AIRBASE}),
        blue_airbase =  ZoneHandler:new({
            name = "ANAPA",
            airbase_name = Airbases.Caucasus.Anapa_Vityazevo,
            zone_type = ZoneTypes.AIRBASE}),
        zones = {
            ZoneHandler:new({name = "NORTH-FIELDS"}),
            ZoneHandler:new({name = "KING"}),
            ZoneHandler:new({name = "JACK"}),
            ZoneHandler:new({name = "SUKKO"}),
            ZoneHandler:new({name = "PORT"}),
            ZoneHandler:new({name = "SUPSEH"}),
            ZoneHandler:new({name = "NORTH-BAY"}),
            ZoneHandler:new({name = "OUTPOST-CHARLIE"}),
            ZoneHandler:new({name = "CLUB"}),
            ZoneHandler:new({name = "QUEEN"}),
            ZoneHandler:new({name = "ABINSK"}),
            ZoneHandler:new({name = "OUTPOST-BRAVO"}),
            ZoneHandler:new({name = "STRONGHOLD"}),
            ZoneHandler:new({name = "SPADE"}),
            ZoneHandler:new({name = "JOKER"}),
            ZoneHandler:new({name = "CHECKPOINT-UNIFORM"}),
            ZoneHandler:new({name = "CHECKPOINT-TANGO"}),
            ZoneHandler:new({name = "CHECKPOINT-YANKEE"}),
            ZoneHandler:new({name = "OUTPOST-DELTA"}),
            ZoneHandler:new({name = "ACE"}),
            
            ZoneHandler:new({name = "HEART", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "FARP-A1", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "KRYMSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krymsk}),
        }
    }
}
--[[
####################################################
    MISSION START SCRIPT
####################################################
]]

---@type ZoneHandler[]
zones = {}



    ---@type Scenario|nil
    Scenario = nil
    for _,scenario in pairs(Scenarios) do
        if scenario.name == Config.persistence.scenario_selected then
            Scenario = scenario
            break
        end
    end
    if Config.persistence.random_scenario_selection == true then
        Scenario = Scenarios[math.random(1,#Scenarios)]
    end

    if Scenario == nil then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistence.scenario_selected .. "' not found! Check your config.", 120)
    elseif not Scenario.blue_airbase or not Scenario.red_airbase then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistence.scenario_selected .. "' is missing airbase definitions! Check your config.", 120)
    else
        -- table.insert(zones,Scenario.zones)
        zones = mist.utils.deepCopy(Scenario.zones)
    
        ---@type ZoneHandler,ZoneHandler
        blue_airbase = Scenario.blue_airbase
        red_airbase = Scenario.red_airbase
    
        table.insert(zones,blue_airbase)
        table.insert(zones,red_airbase)
    end


TheatreCommander.startMission()