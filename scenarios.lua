--[[
    scenarios.lua
    Catalyst Mission Scenarios

]]
---@class CoalSetup
---@field initial_dist_blue_to_frontline number
---@field auto_coalition_designation boolean
---@field dist_variance number

---@class LogisticsSetup
---@field upgrade_range number
---@field heli_capture_range number
---@field max_dist_to_frontline number

---@class Resupply
---@field blue_point vec3
---@field red_point vec3

---@class Scenario
---@field name string
---@field difficulty ScenarioDifficulty
---@field description string
---@field coalition_setup CoalSetup
---@field red_airbase ZoneHandler|nil
---@field blue_airbase ZoneHandler|nil
---@field logistics_setup LogisticsSetup
---@field resupply Resupply
---@field zones ZoneHandler[]

---@type Scenario[]
Scenarios = {
    {
        name = "Neptune Protocol1",
        description = "Regain control of lost Georgia.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 55750, --meters
            dist_variance = 5000, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 50000, --meters
            heli_capture_range = 100000, --meters
            max_dist_to_frontline = 65000 --meters
        },
        resupply = {
            red_point = { x = 00006923, y = 6096, z = 00079849 },
            blue_point = { x = -00326782, y = 6096, z = 00932890 }
        },
        difficulty = ScenarioDifficulty.HARD,
        red_airbase = ZoneHandler:new({
            name = "ANAPA",
            airbase_name = Airbases.Caucasus.Anapa_Vityazevo,
            zone_type = ZoneTypes.AIRBASE}),
        blue_airbase =  ZoneHandler:new({
            name = "VAZIANI",
            zone_type = ZoneTypes.AIRBASE,
            airbase_name = Airbases.Caucasus.Vaziani,}),
        zones = {
            ZoneHandler:new({
                name = "ALPHA",
                zone_type = ZoneTypes.STRONGPOINT
            }),
            ZoneHandler:new({
                name = "KUTAISI",
                zone_type = ZoneTypes.AIRBASE,
                airbase_name = Airbases.Caucasus.Kutaisi,
            }),

        }
    },
    {
        name = "Neptune Protocol",
        description = "Regain control of lost Georgia.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 55750, --meters
            dist_variance = 5000, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 50000, --meters
            heli_capture_range = 100000, --meters
            max_dist_to_frontline = 65000 --meters
        },
        resupply = {
            blue_point = { x = 00006923, y = 6096, z = 00079849 },
            red_point = { x = -00326782, y = 6096, z = 00932890 }
        },
        difficulty = ScenarioDifficulty.HARD,
        red_airbase = ZoneHandler:new({
            name = "ANAPA",
            airbase_name = Airbases.Caucasus.Anapa_Vityazevo,
            zone_type = ZoneTypes.AIRBASE,
            acft_resupply_point = {
                x = 00006923,
                y = 6096, 
                z = 00079849
            }}),
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
            ZoneHandler:new({
                name = "LOGIS",
                zone_type = ZoneTypes.LOGISTICS,
        
                next_level_up_avail = timer.getTime(),
        
                capture_convoy_avail = 1,
                capture_heli_avail = 2
                --init_groups = { "RED GRND TEST" },
                -- panel_only = true
            }),
            ZoneHandler:new({
                name = "ALPHA",
                zone_type = ZoneTypes.STRONGPOINT
            }),
            ZoneHandler:new({
                name = "TEST",
                zone_type = ZoneTypes.STRONGPOINT
            }),
            ZoneHandler:new({
                name = "BRAVO",
                zone_type = ZoneTypes.STRONGPOINT
            }),
            ZoneHandler:new({
                name = "SAMH",
                zone_type = ZoneTypes.SAMSITE,
                sam_classification = SAM_TYPES.MEDIUM_RANGE,
            }),
            ZoneHandler:new({
                name = "CHARLIE",
                zone_type = ZoneTypes.SAMSITE,
                sam_classification = SAM_TYPES.MEDIUM_RANGE,
            }),
            ZoneHandler:new({
                name = "DELTA",
                zone_type = ZoneTypes.SAMSITE,
                sam_classification = SAM_TYPES.LONG_RANGE,
            }),
            ZoneHandler:new({
                name = "DELTA-1",
                zone_type = ZoneTypes.LOGISTICS,
                
                next_level_up_avail = timer.getTime(),
        
                -- capture_convoy_avail = 1,
                capture_heli_avail = 6
            }),
            ZoneHandler:new({
                name = "COMMS1",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "COMMS2",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "SUKHUMI",
                zone_type = ZoneTypes.AIRBASE,
                airbase_name = Airbases.Caucasus.Sukhumi_Babushara,
                acft_resupply_point = { --TO CHANGE
                    x = -00326782,
                    y = 6096, --20k ft
                    z = 00932890
                }
            }),
            -- ZoneHandler:new({
            --     name = "COMMS3",
            --     zone_type = ZoneTypes.COMMS
            -- }),
            -- ZoneHandler:new({
            --     name = "COMMS4",
            --     zone_type = ZoneTypes.COMMS
            -- }),
            -- ZoneHandler:new({
            --     name = "COMMS5",
            --     zone_type = ZoneTypes.COMMS
            -- }),
            ZoneHandler:new({
                name = "KUTAISI",
                zone_type = ZoneTypes.AIRBASE,
                airbase_name = Airbases.Caucasus.Kutaisi,
                acft_resupply_point = { --TO CHANGE
                    x = -00326782,
                    y = 6096, --20k ft
                    z = 00932890
                }
            }),
            ZoneHandler:new({
                name = "SENAKI",
                zone_type = ZoneTypes.AIRBASE,
                airbase_name = Airbases.Caucasus.Senaki_Kolkhi,
                acft_resupply_point = { --TO CHANGE
                    x = -00326782,
                    y = 6096, --20k ft
                    z = 00932890
                }
            }),
            ZoneHandler:new({
                name = "RED COMMS1",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "RED COMMS2",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "RED COMMS3",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "RED COMMS4",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "RED COMMS5",
                zone_type = ZoneTypes.COMMS
            }),

        }
    },
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
            ZoneHandler:new({ name = "INDIA" }),
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
            ZoneHandler:new({ name = "GUDATA" }),
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
            ZoneHandler:new({ name = "LAILASHI" }),
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
            ZoneHandler:new({ name = "USAHELO" }),
            ZoneHandler:new({ name = "ATOTSI" }),
            ZoneHandler:new({ name = "ABISI" }),
            ZoneHandler:new({ name = "ALAGIR" }),
            ZoneHandler:new({ name = "TRAINING-AIRFIELD" }),
            
            -- Logistics
            ZoneHandler:new({ name = "LOGIS" }),
            ZoneHandler:new({ name = "DELTA-1" }),
            
            -- SAM Sites
            ZoneHandler:new({ name = "SAMH" }),
            
            -- Comms
            ZoneHandler:new({ name = "COMMS1" }),
            ZoneHandler:new({ name = "COMMS2" }),
            ZoneHandler:new({ name = "COMMS3" }),
            ZoneHandler:new({ name = "COMMS4" }),
            ZoneHandler:new({ name = "COMMS5" }),
            ZoneHandler:new({ name = "RED COMMS1" }),
            ZoneHandler:new({ name = "RED COMMS2" }),
            ZoneHandler:new({ name = "RED COMMS3" }),
            ZoneHandler:new({ name = "RED COMMS4" }),
            ZoneHandler:new({ name = "RED COMMS5" }),
            
            -- Checkpoints
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
            
            -- Outposts
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
    }
}

-- ZoneHandler:new({
    --     name = "JULIET",
    --     side = coalition.side.NEUTRAL,
    --     zone_type = ZoneTypes.SAMSITE,
    --     sam_classification = SAM_TYPES.MEDIUM_RANGE,
    --     level = 1
    -- }),



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
        if scenario.name == Config.persistance.scenario_selected then
            Scenario = scenario
            break
        end
    end
    if Config.persistance.random_scenario_selection == true then
        Scenario = Scenarios[math.random(1,#Scenarios)]
    end

    if Scenario == nil then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistance.scenario_selected .. "' not found! Check your config.", 120)
    elseif not Scenario.blue_airbase or not Scenario.red_airbase then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistance.scenario_selected .. "' is missing airbase definitions! Check your config.", 120)
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