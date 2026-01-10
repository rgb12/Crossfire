--[[
    DCS CROSSFIRE MISSION CONFIG FILE

    This file allows you to edit how the mission responds, how AI behaves depending on multiple variables.

    Not all settings are editable from this file, some are hardcoded to ensure mission stability.

    Do not remove the commas at the end of each line.
    Refer to the comments for details on each field

]]
Config = {
    persistence = {
        enable = true, -- enables or not persistence, has authority over everything below in this section
        save_interval = 5*51, -- (seconds) interval at which the mission state is saved
        -- You can use fixed values or multiplications like above
        -- 51 seconds is used to avoid multiples of 15 to reduce lag spikes
        save_dir = "Missions/Saves/Crossfire/", -- this is your saves directory in Saved Games
        save_file = "mission.json", -- this is the name of the mission file
        user_data_file = "user_data.json", -- this is the name of user data only file, note that this only saves user xp, tokens ans rank

        enable_ctld_persistence = true, -- enables/disables CTLD placed asset persistence

        random_scenario_selection = false, -- allows the script to randomly choose a random scenario, authority over scenario selection
        scenario_selected = "Eastbound", -- subject to the field above, choose your own scenario 
    },
    operations = {
        recon_minimum_altitude = 1524, -- (meters)
        recon_duration = 120, -- (seconds)
        recon_distance_from_zone = 20000, -- (meters)
        cap_duration = 8*60, -- (seconds)
        cap_max_radius_from_zone = 28*1000, -- (meters)
        max_distance_to_frontline_for_airdrops = 300*1000, -- (meters)
        airdrop_min_crates_landed = 6, -- minimum number of crates that must land to consider the airdrop successful
        csar_rescue_radius = 50, -- (meters) distance from downed pilot required to complete rescue
        intercept_required_kills = 2, -- number of aircraft/helicopters to destroy to complete INTERCEPT
        intercept_max_distance_to_enemy = 200*1000, -- (meters) max distance from friendly zone to enemy zone for INTERCEPT to be proposed

        
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
                "F-14A-135-GR"
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
            },
            [OperationTypes.CAP] = {
                "F-15C",
                "F-14A-135-GR",
                "F-16C_50",
                "M-2000C",
                "F-14B",
                "F-15ESE",
            },
            [OperationTypes.INTERCEPT] = {
                "F-15C",
                "F-14A-135-GR",
                "F-16C_50",
                "M-2000C",
                "F-14B",
                "F-15ESE",
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
    allow_air_spawn = true, -- prevents or not air spawns for players
    enabled_su25t_blufor = true, -- adds the SU-25T to the blufor warehouse inventory

    red_stock_multiplier = 8, -- multiplier for redfor warehouse stocks, compared to blufor

    cooldown_before_capture_attempt = 10*60, -- (seconds)
    retry_capture_chance = 50, -- (%)
    
    allow_resupply = true, -- this will enable/disable resupply aircrafts, this will make the misison significantly harder
    std_resupply_time = 45*60, -- (seconds) respawn resupply aircraft delay
    random_resupply_types = true , -- enables/disables random resupply types, if disabled only INITIAL resupplies will arrive
    -- INITIAL resupply is equivalent to what the warehouses were given at mission start

    zone_upgrade_costs_tokens = {
        [1] = 40, -- cost to upgrade from tier 1 to tier 2
        [2] = 60, -- cost to upgrade from tier 2 to tier 3
        [3] = 80, -- cost to upgrade from tier 3 to tier 4
    },
    resupply_costs = {

        INITIAL = 400,
        FARP = 100,

        AA_AIRCRAFT = 100,
        AG_AIRCRAFT = 120,
        CARGO_AIRCRAFT = 80,

        AIR_AIR_LONG_RANGE = 50,
        AIR_GROUND_GUIDED_MISSILES = 60,
        AIR_GROUND_GUIDED_BOMBS = 50,
        ECM = 40,
        TGP_MISC = 40,

        AIR_AIR_SHORT_RANGE = 30,
        AIR_GROUND_BOMBS = 20,
        AIR_GROUND_ROCKETS = 15,
    },

    reward_system = {
        enable = true, -- completely enables/disables the reward system
        xp_per_mission_completed = 500,
        xp_per_aircraft_destroyed = 100,
        xp_per_helicopter_destroyed = 75,
        xp_per_infantry_kill = 5,
        xp_per_vehicle_destroyed = 15,
        xp_per_sam_destroyed = 50,
        xp_per_structure_destroyed = 60,
        xp_per_ship_sunk = 300,
        xp_per_intel_report = 50,
        landing_time = 15, -- (seconds) the time the player has to stay on the ground to be rewarded

        tokens_on_rank_up = 20, -- random between tokens awarded on rank up
        tokens_on_rank_up_variance = 10,
        
        -- Co-op reward bonuses
        coop_xp_bonus = 0.20, -- 20% bonus to XP and tokens when playing co-op operations (multiplier applied to both XP and tokens)

        tokens_mission_complete = {
            [OperationTypes.AIRDROP] = 20,
            [OperationTypes.CAP] = 5,
            [OperationTypes.CAS] = 20,
            [OperationTypes.SEAD] = 15,
            [OperationTypes.STRIKE] = 15,
            [OperationTypes.DEAD] = 30,
            [OperationTypes.RECON] = 10,
            [OperationTypes.INTERCEPT] = 10,
            [OperationTypes.CSAR] = 30
        },

        xp_required = {
            [AITaskTypes.JTAC]           = 0,
            [AITaskTypes.RECON]          = 2000,   -- ~2-3 hours
            [AITaskTypes.CAP]            = 5000,   -- ~5-8 hours
            [AITaskTypes.CAS]            = 10000,  -- ~10-15 hours (Major milestone)
            [AITaskTypes.STRIKE]         = 15000,  -- ~20 hours
            [AITaskTypes.SEAD]           = 20000,  -- ~25 hours
            [AITaskTypes.CAPTURE_HELO]   = 30000,
            [AITaskTypes.RESUPPLY_CARGO] = 40000,
            [AITaskTypes.AWACS]          = 60000,  -- High level role (~70 hours)
        },

        ranks = {
            [1]  = { name = "Airman Basic",      xp_required = 0 },
            [2]  = { name = "Airman",            xp_required = 1000 },  -- 1 Hour
            [3]  = { name = "Airman First Class",xp_required = 2500 },
            [4]  = { name = "Senior Airman",     xp_required = 5000 },  -- ~5 Hours
            [5]  = { name = "Staff Sergeant",    xp_required = 8000 },
            [6]  = { name = "Technical Sergeant",xp_required = 12000 },
            [7]  = { name = "Master Sergeant",   xp_required = 16000 },
            [8]  = { name = "Senior Master Sergeant", xp_required = 20000 }, -- ~20-25 Hours
            [9]  = { name = "Chief Master Sergeant",  xp_required = 25000 },

            [10] = { name = "Second Lieutenant", xp_required = 32000 },
            [11] = { name = "First Lieutenant",  xp_required = 40000 },
            [12] = { name = "Captain",           xp_required = 48000 }, -- ~50 Hours (Halfway)
            [13] = { name = "Major",             xp_required = 58000 },
            [14] = { name = "Lieutenant Colonel",xp_required = 68000 },
            [15] = { name = "Colonel",           xp_required = 78000 },
            [16] = { name = "Brigadier General", xp_required = 85000 },
            [17] = { name = "Major General",     xp_required = 90000 },
            [18] = { name = "Lieutenant General",xp_required = 95000 },
            [19] = { name = "General",           xp_required = 98000 },
            [20] = { name = "Commander",         xp_required = 100000 }, -- ~100 Hours
        }

    },
    theatre = {

        -- Weights for random generation (Airbases are excluded)
        -- 60% of zones will be strongpoints
        -- 15% logistics
        -- etc.
        zone_type_weights = {
            [ZoneTypes.STRONGPOINT] = 50,
            [ZoneTypes.LOGISTICS]   = 20,
            [ZoneTypes.SAMSITE]     = 15,
            [ZoneTypes.COMMS]       = 10,
            [ZoneTypes.EWSITE]      = 5,
        },

    },
    tasking_requirements = {
        comms_zones_required_for_jtac = 0,
        comms_zones_required_for_cas = 2,
        comms_zones_required_for_sead = 3,
        comms_zones_required_for_strike = 2,
        comms_zones_required_for_cap = 1,
        comms_zones_required_for_awacs = 3,
        comms_zones_required_for_recon = 1,

        tokens_required_for_jtac = 5,
        tokens_required_for_cas = 10,
        tokens_required_for_sead = 15,
        tokens_required_for_strike = 15,
        tokens_required_for_cap = 10,
        tokens_required_for_awacs = 30,
        tokens_required_for_recon = 10,
        tokens_required_for_capture_helicopter = 10,
    },
    comms_tower_respawn_time = 40*60, -- (seconds), the timer decreases by 25% for every level
    comms_tower_lost_penalty = 1, -- the respawn time is multiplied by this much when a comms tower is lost
    -- the penalty is disabled by default to avoid excessive respawn times

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
    cargo_aircraft = {
        "C-130J-30",
        "SA342Minigun",
        "SA342L",
        "SA342Mistral",
        "SA342M",
        "UH-1H",
    },
    crates_spawn_params = { -- not functional anymore
        cargo_crates_spawn_radius_max = 35,
        cargo_crates_spawn_radius_min = 20,
    },


    capture_helicopter_max_range = 100*1000 , -- (meters)

    max_ground_recon_range = 30000, -- (meters) the range at which enemy zones will be discovered from friendly zones

    stuck_convoy_timeout = 8*60, -- (seconds) time without movement after which a convoy is considered stuck and will be removed
    attack_convoy_range = 30000, -- (meters)

    jtac_smoke_stock = 8,

    -- logistics_upgrade_range = 30000, -- (meters)
    logistics_upgrade_chance = 30, -- (%) every minute the dice is rolled
    logistics_level_up_interval = 16*60, -- (seconds) minimum time between level ups
    logistics_ammo_depot_respawn_time = 25*60, -- (seconds) time it takes for an ammo depot to respawn after being destroyed
    airbase_command_center_respawn_time = 15*60, -- (seconds) time it takes for a command center to respawn after being destroyed

    -- Warehouse supply distribution percentages by airbase tier, make sure they add up to 1.0 exactly
    warehouse_supply_distribution = {
        tier_1 = 0.5, -- % of supplies to tier 1 airbases
        tier_2 = 0.10, -- % of supplies to tier 2 airbases
        tier_3 = 0.15, -- % of supplies to tier 3 airbases
        tier_4 = 0.70, -- % of supplies to tier 4 airbases
    },

    upgrade_tier_range = 50000,

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
            {1, 0.5, 0.5, 0.3}    -- Text BG
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
    }

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

    blue_comms_antennas = 0,
    blue_discovered_zones = {},
    blue_enroute_resupply = {},
    blue_supplies = 1000,

    red_sam_sites = 0,
    red_farp_zones = 0,
    red_logistics_zone = 0,
    red_comms_zones = 0,
    red_airbases = 0,
    red_ew_zones = 0,
    red_strongpoints = 0,
    red_total_comms_zones = 0,

    red_comms_antennas = 0,
    red_discovered_zones = {},
    red_enroute_resupply = {},
    red_supplies = 1000
}




-- This table allows you to link the in-mission groups to the script logic
-- Group names from the mission editor. They must be exactly the same.
GroupData = {
    COMMON_ASSETS = {
        BLUE = {
            resupply_aircraft = "C130",
            capture_convoy = "BLUE Capture Convoy",
            capture_helicopter = "BLUE Capture Helo",
            attack_convoy = "BLUE Attack Convoy",
            jtac = "BLUE JTAC",
            farp = "BLUE FARP VEHICLES"
        },
    
        RED = {
            resupply_aircraft = "IL76",
            capture_convoy = "RED Capture Convoy",
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