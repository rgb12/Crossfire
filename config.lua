--[[
    DCS CROSSFIRE MISSION CONFIG FILE

    This file allows you to edit how the mission responds, how AI behaves depending on multiple variables.

    Not all settings are editable from this file, some are hardcoded to ensure mission stability.

    Some values contain *, this symbol represents multiplication.
    Ex: 5*60 = 300 seconds, or 5 minutes.

    Do not remove the commas at the end of each line. For example: 
        enable = true,  <--- comma must be here
    Refer to the comments for details on each field
    Comments start with "--"

    It is recommended to use a code editor such as VSCode, Notepad++, Sublime Text, etc. to edit this file.
]]
Config = {
    persistence = {
        enable =  false, -- enables or not persistence, has authority over everything below in this section
        save_interval = 5*51, -- (seconds) interval at which the mission state is saved
        -- You can use fixed values or multiplications like above
        -- 51 seconds is used to avoid multiples of 15 to reduce lag spikes
        save_dir = "Missions/Saves/Crossfire Syrian Resolve/", -- this is your saves directory in Saved Games
        -- If you would like to create a new mission, simple change the last folder name
        save_file = "mission.json", -- this is the name of the mission file
        user_data_file = "user_data.json", -- this is the name of user data only file, note that this only saves user xp and rank

        enable_ctld_persistence = true, -- enables/disables CTLD placed asset persistence


        -- scenario_selected = "Georgia Liberation", -- select a scenario from the scenarios found below
        scenario_selected = "Syrian Resolve", -- select a scenario from the scenarios found below
    },
    operations = {
        recon_duration = 120, -- (seconds)
        recon_distance_from_zone = 20000, -- (meters)
        cap_duration = 8*60, -- (seconds)
        cap_max_radius_from_zone = 28*1000, -- (meters)
        max_distance_to_frontline_for_airdrops = 300*1000, -- (meters)
        airdrop_min_crates_landed = 6, -- minimum number of crates that must land to consider the airdrop successful
        csar_rescue_radius = 50, -- (meters) distance from downed pilot required to complete rescue
        intercept_required_kills = 2, -- number of aircraft/helicopters to destroy to complete INTERCEPT
        intercept_max_distance_to_enemy = 200*1000, -- (meters) max distance from friendly zone to enemy zone for INTERCEPT to be proposed
        attributes_for_SEAD_targeting = { 'SAM SR', 'SAM TR', 'IR Guided SAM', 'EWR' }, -- unit attributes that make them valid SEAD targets

        operation_refresh_time = 30, --(seconds) this is to set a cooldown for generating operations

        
        aircraft_filter = {
            [OperationTypes.CSAR] = {
                "UH-1H",
                "Mi-8MT",
                "Mi-24P",
                "CH-47Fbl1",
                "SA342L",
                "SA342M",
                "SA342Mistral",
                "SA342Minigun",
                "UH-60L",
                "AH-64D_BLK_II"
            },
            [OperationTypes.AIRDROP] = {
                "C-130J-30",
            },
            [OperationTypes.CAS] = {
                "A-10C_2",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "Su-25T",
                "F-14A-135-GR",
                "AH-64D_BLK_II",
                "SA342L",
                "SA342M",
            },
            [OperationTypes.DEAD] = {
                "A-10C_2",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "Su-25T",
            },
            [OperationTypes.STRIKE] = {
                "A-10C_2",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "Su-25T",
                "AH-64D_BLK_II",
            },
            [OperationTypes.CAP] = {
                "F-15C",
                "F-14A-135-GR",
                "F-16C_50",
                "M-2000C",
                "F-14B",
                "F-15ESE",
                "FA-18C_hornet",
            },
            [OperationTypes.INTERCEPT] = {
                "F-15C",
                "F-14A-135-GR",
                "F-16C_50",
                "M-2000C",
                "F-14B",
                "F-15ESE",
                "FA-18C_hornet"
            },
            [OperationTypes.SEAD] = {
                "F-16C_50",
                "FA-18C_hornet",
                "A-10C_2",
            }
        },
        -- Co-op operation settings
        coop_max_members = 4, -- maximum number of players (including leader) in a co-op operation
    },
    jupiter_enabled = true, -- enables/disables the Jupiter command system
    jupiter_password = "", -- password required before the -, example password = 12 then the command is 12-discover

    allow_air_spawn = true, -- prevents or not air spawns for players
    enable_slot_blocker = true, -- enables/disables the slot blocker system to prevent players spawning in enemy airbases
    enable_warehouse = true, -- this does not disable/enable the system, but stocks will be nearly unlimited if disabled
    allow_resupply = true, -- this will enable/disable resupply aircrafts, this will make the misison significantly harder
    enabled_su25t_blufor = true, -- adds the SU-25T to the blufor warehouse inventory

    red_stock_multiplier = 50, -- multiplier for redfor only warehouse stocks

    cooldown_before_capture_attempt = 10*60, -- (seconds)
    retry_capture_chance = 50, -- (%) Every minute, subject to various checks and conditions
    
    std_resupply_time = 45*60, -- (seconds) periodic resupply aircraft time interval
    random_resupply_types = true , -- enables/disables random resupply types, if disabled only INITIAL resupplies will arrive
    -- INITIAL resupply is equivalent to what the warehouses were given at mission start

    supplies = {
        initial_stock = 1000, -- starting supplies per coalition
        supplies_income = 20, -- supplies gained per minute from each alive ammo depot in logistics zones
        supplies_looted_on_destroyed = 500, -- supplies gained when capturing an enemy zone
        supplies_looted_on_destroyed_variance = 200, -- (+/-) supplies variance when capturing an enemy zone
        supplies_cap_for_command_post = 5000, -- maximum supplies a command post can hold
        absolute_max_supplies = 40000, -- maximum supplies a coalition can hold no matter what

        resupply_costs = {
            -- Warehouse aircraft resupply costs (balance: 1-2 aircraft per 5 minutes of income)
            INITIAL = 8000,           -- Full initial warehouse stock restoration
            FARP = 2500,              -- FARP complete resupply
            
            AA_AIRCRAFT = 4000,       -- Air-to-air focused aircraft
            AG_AIRCRAFT = 4500,       -- Air-to-ground focused aircraft
            CARGO_AIRCRAFT = 3000,    -- Transport/utility aircraft
            
            -- Weapons resupply costs (balance: 2-4 loadouts per 5 minutes of income)
            AIR_AIR_LONG_RANGE = 2000,            -- AIM-120, AIM-54, etc.
            AIR_AIR_SHORT_RANGE = 1500,           -- AIM-9, R-73, etc.
            
            AIR_GROUND_GUIDED_MISSILES = 3000,   -- AGM-65, Hellfire, etc.
            AIR_GROUND_GUIDED_BOMBS = 1500,       -- GBU-12, GBU-38, etc.
            AIR_GROUND_BOMBS = 900,              -- Mk-82, Mk-84, etc.
            AIR_GROUND_ROCKETS = 500,            -- Hydra, S-8, etc.
            
            ECM = 5000,                -- Jamming pods, countermeasures
            TGP_MISC = 4000,           -- Targeting pods, misc equipment
        },
        tasking_costs = {
            JTAC = 600,
            CAS = 2000,
            SEAD = 1500,
            STRIKE = 1200,
            CAP = 1000,
            AWACS = 600,
            RECON = 1000,
            CAPTURE_HELO = 400,
        }
    },

    reward_system = {
        enable = true, -- completely enables/disables the reward system
        xp_per_aircraft_destroyed = 100,
        xp_per_helicopter_destroyed = 75,
        xp_per_infantry_kill = 5,
        xp_per_vehicle_destroyed = 15,
        xp_per_sam_destroyed = 50,
        xp_per_ship_sunk = 300,
        xp_per_intel_report = 50,
        landing_time = 15, -- (seconds) the time the player has to stay on the ground to be rewarded

        
        -- Co-op reward bonuses
        coop_xp_bonus = 0.25, -- (%) bonus to XP and tokens when playing co-op operations (multiplier applied to XP)

        xp_required = {
            [AITaskTypes.JTAC]           = 0,
            [AITaskTypes.RECON]          = 2000,
            [AITaskTypes.CAP]            = 5000,
            [AITaskTypes.CAS]            = 10000,  -- (Major milestone)
            [AITaskTypes.STRIKE]         = 15000,
            [AITaskTypes.SEAD]           = 20000,  -- ~25 hours
            [AITaskTypes.CAPTURE_HELO]   = 5000,
            [AITaskTypes.RESUPPLY_CARGO] = 40000,
            [AITaskTypes.AWACS]          = 60000,  -- ~70 hours
        },

        ranks = {
            [1]  = { name = "Airman Basic",      xp_required = 0 },
            [2]  = { name = "Airman",            xp_required = 1000 },
            [3]  = { name = "Airman First Class",xp_required = 2500 },
            [4]  = { name = "Senior Airman",     xp_required = 5000 },
            [5]  = { name = "Staff Sergeant",    xp_required = 8000 },
            [6]  = { name = "Technical Sergeant",xp_required = 12000 },
            [7]  = { name = "Master Sergeant",   xp_required = 16000 },
            [8]  = { name = "Senior Master Sergeant", xp_required = 20000 },
            [9]  = { name = "Chief Master Sergeant",  xp_required = 25000 },

            [10] = { name = "Second Lieutenant", xp_required = 32000 },
            [11] = { name = "First Lieutenant",  xp_required = 40000 },
            [12] = { name = "Captain",           xp_required = 48000 },
            [13] = { name = "Major",             xp_required = 58000 },
            [14] = { name = "Lieutenant Colonel",xp_required = 68000 },
            [15] = { name = "Colonel",           xp_required = 78000 },
            [16] = { name = "Brigadier General", xp_required = 85000 },
            [17] = { name = "Major General",     xp_required = 90000 },
            [18] = { name = "Lieutenant General",xp_required = 95000 },
            [19] = { name = "General",           xp_required = 98000 },
            [20] = { name = "Commander",         xp_required = 100000 },
        }

    },
    theatre = {

        -- Weights for random generation (Airbases are excluded)
        -- 50% of zones will be strongpoints
        -- 20% logistics   
        zone_type_weights = {
            [ZoneTypes.STRONGPOINT] = 50,
            [ZoneTypes.LOGISTICS]   = 20,
            [ZoneTypes.SAMSITE]     = 15,
            [ZoneTypes.COMMS]       = 10,
            [ZoneTypes.EWSITE]      = 5,
        },
        -- The script ensures all essential zone types are present, bypassing the above if needed

    },
    tasking_requirements = {
        --*checks if rnough antennas are alive, not the zones themselves
        comms_zones_required_for_jtac = 0,
        comms_zones_required_for_cas = 2,
        comms_zones_required_for_sead = 2,
        comms_zones_required_for_strike = 2,
        comms_zones_required_for_cap = 1,
        comms_zones_required_for_awacs = 2,
        comms_zones_required_for_recon = 1,
    },
    comms_tower_respawn_time = 45*60, -- (seconds)
    
    comms_tower_lost_penalty = 1.1, -- the respawn time is multiplied by this much when a comms tower is lost @depracted

    tasking = {
        enable = true, -- enables/disables AI tasking system, does not affect resupply and capture mechanics
        dispatcher_interval = 10*60+8,--5*60, -- (seconds), avoid multiples of 15 to reduce lag spikes
        max_tasks_per_airbase = 4, -- maximum number of concurrent tasks per airbase

        max_jtac_per_airbase = 2,
        max_cas_per_airbase = 1,
        max_sead_per_airbase = 2,
        max_strike_per_airbase = 2,
        max_cap_per_airbase = 2,
        max_awacs_per_airbase = 1,
        max_recon_per_airbase = 2,

        max_jtac_theatre = 4, -- per coalition, only for AI auto tasking
        max_cas_theatre = 4,-- per coalition, only for AI auto tasking
        max_sead_theatre = 4,-- per coalition , only for AI auto tasking
        max_strike_theatre = 4,-- per coalition, only for AI auto tasking
        max_cap_theatre = 6,-- per coalition, only for AI auto tasking
        max_recon_theatre = 4,-- per coalition, only for AI auto tasking
        max_awacs_per_theatre = 2,-- per coalition, only for AI auto tasking
        max_attack_convoy_per_theatre = 3,-- per coalition, only for AI auto tasking

        max_capture_helicopters_per_logistics_zone = 4,
        max_attack_convoys_per_strongpoint_zone = 2,
        max_awacs_theatre = 2,

        range_for_recon_to_discover_zone = 15*1000, -- (meters)
        max_cas_range = 200*1000, -- (meters)
        min_cleareance_dist_for_awacs = 70*1000 -- (meters) from the nearest enemy zone
    },

    ctld = {
        unpacked_asset_prefix = "unpacked_",
        packed_asset_prefix = "packed_",
        max_placed_assets = 300,  -- Global limit for all placed assets
        allowed_load_zones = {ZoneTypes.FARP, ZoneTypes.AIRBASE, ZoneTypes.LOGISTICS},
        allow_load_anywhere = false,  -- If true, players can load/unload assets anywhere, ignoring allowed_load_zones
        cargo_crate_template = "container_cargo",
        search_radius = 100,  -- (meters)
        random_crate_spacing = 6,  -- (meters)
        allow_unpacking_in_zones = true,
        allow_unloading_in_zones = true,
        enable_weighted_loading = false,

        FARP_names = {
            "Elara",
            "Io",
            "Ariel",
            "Europa",
            "Mars",
            "Jupiter",
            "Phobos",
            "Deimos",
            "Callisto",
            "Iocaste"
        }
    },

    capture_helicopter_max_range = 100*1000 , -- (meters)

    max_ground_recon_range = 30000, -- (meters) the range at which enemy zones will be discovered from friendly zones

    stuck_convoy_timeout = 8*60, -- (seconds) time without movement after which a convoy is considered stuck and will be removed
    attack_convoy_range = 30000, -- (meters)

    jtac_smoke_stock = 8,

    -- logistics_upgrade_range = 30000, -- (meters)
    logistics_upgrade_chance = 30, -- (%) every minute the dice is rolled
    logistics_level_up_interval = 16*60, -- (seconds) minimum time between level ups
    logistics_ammo_depot_respawn_time = 45*60, -- (seconds) time it takes for an ammo depot to respawn after being destroyed
    airbase_command_center_respawn_time = 15*60, -- (seconds) time it takes for a command center to respawn after being destroyed

    -- Warehouse supply distribution percentages by airbase tier, make sure they add up to 1.0 exactly
    warehouse_supply_distribution = {
        tier_1 = 0.15, -- % of supplies to tier 1 airbases
        tier_2 = 0.20, -- % of supplies to tier 2 airbases
        tier_3 = 0.25, -- % of supplies to tier 3 airbases
        tier_4 = 0.40, -- % of supplies to tier 4 airbases
    },

    upgrade_tier_range = 50000, -- (meters) Zones must be within this distance from logistics zones in order to allow tier upgrades

    EWRS = {
        enable = true, -- enables/disables the EWRS system
        standard_refresh_time = 20, -- (seconds)
        max_aircraft_per_text = 6, -- maximum number of aircraft displayed per message
    },

    draw_color_palette = {
        -- for rgb, divide values by 255 to get 0-1 range
        red_palette = {
            {0.7, 0, 0, 0.9},   -- Border color (r g b: values from 0 to 1, a: transparency from 0 to 1)
            {0.7, 0, 0, 0.25},  -- Fill color
            {0.5, 0.1, 0.1, 1},   -- Text color
            {1, 0.5, 0.5, 0.3}    -- Text background
        },
        blue_palette = {
            {0, 0.2, 0.8, 0.9},
            {0, 0.2, 0.8, 0.25},
            {0, 0.1, 0.5, 1},
            {0.5, 0.8, 1, 0.3}
        },
        neutral_palette = {
            {0.4, 0.4, 0.4, 0.8},
            {0.4, 0.4, 0.4, 0.2},
            {1, 1, 1, 1},
            {0, 0, 0, 0.2}
        }
    },

}

-- Stats tracking table should not be edited unless comprehensively understood
stats = {
    neutral_zones = 0,
    red_zones = 0,
    blue_zones = 0,

    blue_sam_sites = 0,
    blue_logistics_zone = 0,
    blue_farp_zones = 0,
    blue_comms_zones = 0,
    blue_airbases = 0,
    blue_ew_zones = 0,
    blue_strongpoints = 0,
    blue_total_comms_zones = 0,

    blue_ammo_depots = 0,
    blue_command_posts = 0,
    blue_comms_antennas = 0,
    blue_discovered_zones = {},
    blue_enroute_resupply = {},
    blue_supplies = Config.supplies.initial_stock,

    red_sam_sites = 0,
    red_farp_zones = 0,
    red_logistics_zone = 0,
    red_comms_zones = 0,
    red_airbases = 0,
    red_ew_zones = 0,
    red_strongpoints = 0,
    red_total_comms_zones = 0,

    red_ammo_depots = 0,
    red_command_posts = 0,
    red_comms_antennas = 0,
    red_discovered_zones = {},
    red_enroute_resupply = {},
    red_supplies = Config.supplies.initial_stock,
}




-- This table allows you to link the in-mission groups to the script logic
-- Group names from the mission editor. They MUST BE EXACTLY THE SAME.
GroupData = {
    COMMON_ASSETS = {
        BLUE = {
            resupply_aircraft = "C130",
            capture_helicopter = "BLUE Capture Helo",
            attack_convoy = "BLUE Attack Convoy",
            jtac = "BLUE JTAC",
            farp = "BLUE FARP VEHICLES"
        },
    
        RED = {
            resupply_aircraft = "IL76",
            capture_helicopter = "RED Capture Helo",
            attack_convoy = "RED Attack Convoy",
            farp = "RED FARP VEHICLES",
        }
    },

    STRONGPOINT_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE STRONGPOINT TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE STRONGPOINT TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE STRONGPOINT TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE STRONGPOINT TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED STRONGPOINT TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED STRONGPOINT TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED STRONGPOINT TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED STRONGPOINT TIER 4"
            }
        }
    },

    --[[
        SAM Classifications:
            SAM_TYPES.SHORT_RANGE
            SAM_TYPES.MEDIUM_RANGE
            SAM_TYPES.LONG_RANGE
    ]]
    SAM_SITES_NG = {
        {
            group_name= "RED SA5",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.LONG_RANGE,
        },
        {
            group_name = "RED SA10",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.LONG_RANGE,
        },
        {
            group_name = "RED SA11",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.LONG_RANGE,
        },
        {
            group_name= "RED SA2",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
        },
        {
            group_name= "RED SA6",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
        },
        {
            group_name = "RED SA3",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.SHORT_RANGE,
        },
        {
            group_name = "BLUE PATRIOT",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.LONG_RANGE,
        },
        {
            group_name = "BLUE HAWK",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
        },
        {
            group_name = "BLUE IRIS-T",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
        },
        {
            group_name = "BLUE NASAMS",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.SHORT_RANGE,
        }



    },

    AIRBASE_SAMS = {
        BLUE = {
            {
                tier = 3,
                group_name = "BLUE AIRBASE SAM TIER 3"
            },
            {
                tier = 4,
                group_name = "BLUE AIRBASE SAM TIER 4"
            }
        },
        RED = {
            {
                tier = 3,
                group_name = "RED AIRBASE SAM TIER 3"
            },
            {
                tier = 4,
                group_name = "RED AIRBASE SAM TIER 4"
            }
        }
    },

    AIRBASE_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE AIRBASE TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE AIRBASE TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE AIRBASE TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE AIRBASE TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED AIRBASE TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED AIRBASE TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED AIRBASE TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED AIRBASE TIER 4"
            }
        }
    },

    LOGISTICS_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE LOGISTICS TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE LOGISTICS TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE LOGISTICS TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE LOGISTICS TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED LOGISTICS TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED LOGISTICS TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED LOGISTICS TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED LOGISTICS TIER 4"
            }
        }
    },

    COMMS_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE COMMS TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE COMMS TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE COMMS TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE COMMS TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED COMMS TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED COMMS TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED COMMS TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED COMMS TIER 4"
            }
        }
    },

    EW_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED EWR TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED EWR TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED EWR TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED EWR TIER 4"
            }
        }
    },
    
    FARP_SUPPORT = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE FARP SUPPORT TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE FARP SUPPORT TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE FARP SUPPORT TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE FARP SUPPORT TIER 4"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED FARP SUPPORT TIER 1"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED FARP SUPPORT TIER 2"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED FARP SUPPORT TIER 3"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED FARP SUPPORT TIER 4"
            }
        }
    }

}