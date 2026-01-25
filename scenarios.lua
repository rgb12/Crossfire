--[[
    scenarios.lua
    Crossfire Mission Scenarios

]]

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
        logistics_setup = {
            upgrade_range = 30000, -- (meters) maximum range at which a logistics zone can upgrade a zone nearby
            heli_capture_range = 60000, -- (meters) max range for capture AI helicopters
            max_dist_to_frontline = 40000 -- (meters) Logistics zones will not upgrade other zones if the nearest enemy zone is further than this distance
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
        estimated_users = 1, -- IMPORTANT: if you plan on using multiplayer, set this value accordingly, it will scale the warehouse stocks
        difficulty = ScenarioDifficulty.EASY, -- no function
        
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
          name = "Syria",
        description = "test",
        coalition_setup = {
            initial_dist_blue_to_frontline = 16000, --meters
            dist_variance = 0, --meters
            auto_coalition_designation = true, -- overrides the above
        },
        logistics_setup = {
            upgrade_range = 30000, --meters
            heli_capture_range = 150000, --meters
            max_dist_to_frontline = 50000 --meters
        },
        resupply = {
            --blue_point = { x=-00310000, y=2000,z=00901479}, --for dev
            blue_point = { x = -00212555, y = 6096, z = 00151669 },
            red_point = { x = -00025609, y = 6096, z = 00118626 }
        },
        carrier_setup = {
            carrier_unit_name = "Carrier",
            enabled = false
        },
        estimated_users = 1,
        difficulty = ScenarioDifficulty.MEDIUM,
        blue_airbase = ZoneHandler:new({
            name = "KHALKHALAH",
            airbase_name = Airbases.Syria.Khalkhalah,
            zone_type = ZoneTypes.AIRBASE}),
        red_airbase =  ZoneHandler:new({
            name = "AL-DUMAYR",
            airbase_name = Airbases.Syria.Al_Dumayr,
            zone_type = ZoneTypes.AIRBASE}),
        zones = {
            ZoneHandler:new({name = "BURAQ"}),
            ZoneHandler:new({name = "DELTA"}),
            ZoneHandler:new({name = "BRAVO"}),
            ZoneHandler:new({name = "EASTPOINT"}),
            ZoneHandler:new({name = "SOUTHPOINT"}),
            ZoneHandler:new({name = "ALPHA"}),
            ZoneHandler:new({name = "SAND"}),
            ZoneHandler:new({name = "HOTEL"}),
            ZoneHandler:new({name = "FOXTROT"}),
            ZoneHandler:new({name = "LAGOON", zone_type = ZoneTypes.FARP,}),
            ZoneHandler:new({name = "GOLF", zone_type = ZoneTypes.FARP,}),
            ZoneHandler:new({name = "CHARLIE", zone_type = ZoneTypes.FARP,}),
            ZoneHandler:new({name = "MARJ-RUHAYYIL", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Marj_Ruhayyil}),
            ZoneHandler:new({name = "MEZZEH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Mezzeh}),

        } -- 43 zones
    }
}

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
        MissionLogger:info("Total zones loaded for scenario '" .. Scenario.name .. "': " .. #zones)
        ---@type ZoneHandler,ZoneHandler
        blue_airbase = Scenario.blue_airbase
        red_airbase = Scenario.red_airbase
    
        table.insert(zones,blue_airbase)
        table.insert(zones,red_airbase)
    end


TheatreCommander.startMission()