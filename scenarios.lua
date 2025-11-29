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
---@field chain_gap number
---@field heli_capture_range number

---@class Scenario
---@field name string
---@field difficulty ScenarioDifficulty
---@field description string
---@field coalition_setup CoalSetup
---@field red_airbase ZoneHandler|nil
---@field blue_airbase ZoneHandler|nil
---@field logistics_setup LogisticsSetup
---@field zones ZoneHandler[]

---@type Scenario[]
Scenarios = {
    {
        name = "Neptune Protocol",
        description = "Regain control of lost Georgia.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 55750, --meters
            dist_variance = 5000, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 30000, --meters
            heli_capture_range = 100000, --meters
            chain_gap = 25000 --meters
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
                zone_type = ZoneTypes.STRONGPOINT,
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