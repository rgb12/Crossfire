--[[
    scenarios.lua
    Catalyst Mission Scenarios

]]
---@class CoalSetup
---@field initial_dist_blue_to_frontline number
---@field auto_coalition_designation boolean

---@class Scenario
---@field description string
---@field coalition_setup CoalSetup
---@field red_airbase ZoneHandler
---@field blue_airbase ZoneHandler
---@field zones ZoneHandler[]

---@type Scenario[]
Scenarios = {
    ["Neptune Protocol"] = {
        description = "A mission to regain control of lost Georgia.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 55750, --meters
            auto_coalition_designation = true,
        },
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
                name = "COMMS3",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "COMMS4",
                zone_type = ZoneTypes.COMMS
            }),
            ZoneHandler:new({
                name = "COMMS5",
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



if not Config.persistance.random_scenario_selection then
    Scenario = Scenarios[Config.persistance.scenario_selected]
    -- table.insert(zones,Scenario.zones)
    zones = mist.utils.deepCopy(Scenario.zones)

    ---@type ZoneHandler,ZoneHandler
    blue_airbase = Scenario.blue_airbase
    red_airbase = Scenario.red_airbase

    table.insert(zones,blue_airbase)
    table.insert(zones,red_airbase)
end


TheatreCommander.startMission()