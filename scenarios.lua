---@class CoalSetup
---@field initial_dist_blue_to_frontline number
---@field auto_coalition_designation boolean
---@field dist_variance number

---@class CarrierSetup
---@field carrier_unit_name string
---@field tomahawk_launcher_unit_name string|nil
---@field enabled boolean

---@class LhaSetup
---@field lha_unit_name string
---@field enabled boolean
---@field heli_avail number|nil
---@field local_supplies number|nil
---@field lha_source boolean|nil
---@field name string|nil
---@field side coalition.side|nil
---@field zone_type ZoneTypes|nil
---@field ammo_depot_intact boolean|nil
---@field zone { point: vec3 }|nil

---@class Resupply
---@field blue_point vec3
---@field red_point vec3

---@class Scenario
---@field name string
---@field description string
---@field coalition_setup CoalSetup
---@field red_airbase ZoneHandler|nil
---@field blue_airbase ZoneHandler|nil
---@field carrier_setup CarrierSetup|nil
---@field lha_setup LhaSetup|nil
---@field resupply Resupply
---@field zones ZoneHandler[]

---@type Scenario[]
Scenarios = {
    {
        name = "Eastbound",
        description = "Achieve control over the the Russian Caucasus area.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 33000, -- (meters) all zones under that distance from the main airbase will be blue
            dist_variance = 0, -- (meters) add +/- variance to the field above
            auto_coalition_designation = true, -- overrides the above
        },
        resupply = {
            --blue_point = { x=-00005476, y=2000,z=00224066}, --for dev
            -- Metric: X-00005476 Z+00224066

            -- This is where the resupply C130J will spawn
            blue_point = { x = -2839, y = 6096, z = 192302 },
            red_point = { x = 42692, y = 6096, z = 429197 },
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            enabled = true
        },
        -- lha_setup = {
        --     lha_unit_name = "LHA",
        --     enabled = false
        -- },
        
        -- MAIN RED AIRBASE
        red_airbase = ZoneHandler:new({
            name = "KRASNODAR", -- must match EXACTLY the trigger zone name
            airbase_name = Airbases.Caucasus.Krasnodar_Pashkovsky,
            zone_type = ZoneTypes.AIRBASE}),

        -- MAIN BLUE AIRBASE
        blue_airbase =  ZoneHandler:new({
            name = "ANAPA",  -- must match EXACTLY the trigger zone name
            airbase_name = Airbases.Caucasus.Anapa_Vityazevo,
            zone_type = ZoneTypes.AIRBASE}),


        -- Sets up the zones that will generate, make sure the trigger zone names match exactly with the names below
        zones = {
            ZoneHandler:new({name = "NORTH-FIELDS"}),
            ZoneHandler:new({name = "KING"}),            
            ZoneHandler:new({name = "JACK"}),

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
            ZoneHandler:new({name = "HEART", zone_type = ZoneTypes.FARP}), -- make sure you add aircraft clients so users can spawn
            ZoneHandler:new({name = "LONDON", zone_type = ZoneTypes.FARP}),
            ZoneHandler:new({name = "KRYMSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krymsk}),
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
        resupply = {
            --blue_point = { x=-00310000, y=2000,z=00901479}, --for dev
            blue_point = { x = -00318568, y = 6096, z = 00991378 },
            red_point = { x = -00290581, y = 6096, z = 00569411 }
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            tomahawk_launcher_unit_name = "Naval Launcher",
            enabled = true
        },
        lha_setup = {
            lha_unit_name = "LHA",
            enabled = true
        },
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
            ZoneHandler:new({name = "BRAVO", zone_type = ZoneTypes.FARP, linked_farp="BRAVO FARP"}),
            ZoneHandler:new({name = "DELTA", zone_type = ZoneTypes.FARP, linked_farp="DELTA FARP"}),
            ZoneHandler:new({name = "TRAINING-AIRFIELD", zone_type = ZoneTypes.FARP,linked_farp="TA FARP"}),
            ZoneHandler:new({name = "SEASIDE", zone_type = ZoneTypes.FARP, linked_farp="SEASIDE FARP"}),
            ZoneHandler:new({name = "GUDAUTA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Gudauta}),
            ZoneHandler:new({name = "SUKHUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sukhumi_Babushara}),
            ZoneHandler:new({name = "BATUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Batumi}),
            ZoneHandler:new({name = "KOBULETI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kobuleti}),
            ZoneHandler:new({name = "KUTAISI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kutaisi}),
        } -- 43 zones
    },
    {
        name = "Syrian Resolve",
        description = "Dedicated scenario set in Syria.",
        coalition_setup = {
            initial_dist_blue_to_frontline = 45000, --meters
            dist_variance = 0, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        resupply = {
            blue_point = { x = 00029810, y = 6096, z = 00156947 },
            red_point = { x = -00248765, y = 6096, z = 00134754 }
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            tomahawk_launcher_unit_name = "Naval Launcher",
            enabled = true
        },
        lha_setup = {
            lha_unit_name = "LHA",
            enabled = false
        },
        blue_airbase = ZoneHandler:new({
            name = "SHAYRAT",
            airbase_name = Airbases.Syria.Shayrat,
            zone_type = ZoneTypes.AIRBASE}),
        red_airbase =  ZoneHandler:new({
            name = "AL-DUMAYR",
            airbase_name = Airbases.Syria.Al_Dumayr,
            zone_type = ZoneTypes.AIRBASE}),
        zones = {
            ZoneHandler:new({name = "JULIETT"}),
            ZoneHandler:new({name = "HOMS"}),
            ZoneHandler:new({name = "KILO"}),
            ZoneHandler:new({name = "LIMA"}),
            ZoneHandler:new({name = "SEASIDE"}),
            ZoneHandler:new({name = "ROMEO"}),
            ZoneHandler:new({name = "PAPA"}),
            ZoneHandler:new({name = "MIKE"}),
            ZoneHandler:new({name = "OSCAR"}),
            ZoneHandler:new({name = "HOTEL"}),
            ZoneHandler:new({name = "OUTPOST"}),
            ZoneHandler:new({name = "STRONGHOLD"}),
            ZoneHandler:new({name = "STREAM"}),
            ZoneHandler:new({name = "NOVEMBER", zone_type = ZoneTypes.FARP, linked_farp = "NOVEMBER FARP"}),
            ZoneHandler:new({name = "GREEN", zone_type = ZoneTypes.FARP, linked_farp = "GREEN FARP"}),
            ZoneHandler:new({name = "MAQNE", zone_type = ZoneTypes.FARP, linked_farp = "MA FARP"}),
            ZoneHandler:new({name = "QUEBEC", zone_type = ZoneTypes.FARP, linked_farp = "Q FARP"}),

            ZoneHandler:new({name = "AN NASIRIYAH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.An_Nasiriyah}),
            ZoneHandler:new({name = "RAYAK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Rayak}),
        }
    }
}


-- [INSERT CUSTOM SCENARIO HERE]

-- [**********]

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
    
    if Scenario == nil then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistence.scenario_selected .. "' not found! Check your config.", 120)
    elseif not Scenario.blue_airbase or not Scenario.red_airbase then
        trigger.action.outText("ERROR: Scenario '" .. Config.persistence.scenario_selected .. "' is missing blue and red airbase definitions! Check your config.", 120)
    else
        -- table.insert(zones,Scenario.zones)
        -- Prevents lost indexes
        zones = utils.compactZoneList(mist.utils.deepCopy(Scenario.zones))
        MissionLogger:info("Total zones loaded for scenario '" .. Scenario.name .. "': " .. #zones)
        ---@type ZoneHandler,ZoneHandler
        blue_airbase = Scenario.blue_airbase
        red_airbase = Scenario.red_airbase

        table.insert(zones,blue_airbase)
        table.insert(zones,red_airbase)
    end
TheatreCommander.startMission()