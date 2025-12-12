
--[[
    DCS CROSSFIRE MISSION CONFIG FILE

    This file allows you to edit how the mission responds, how AI behaved depending on multiple variables.


    do not remove the commas at the end of each line
    Refer to documenation for details on each setting

]]


Config = {
    persistence = {
        enable = true, -- enables or not persistence, has authority over everything below in this section
        save_interval = 5*51, -- (seconds) interval at which the mission state is saved
        save_dir = "Missions/Saves/Crossfire/", -- this is your saves directory in Saved Games
        save_file = "mission.json", -- this is the name of the mission file
        user_data_file = "user_data.json", -- this is the name of user data only file, note that this only records user xp, tokens ans rank

        
        random_scenario_selection = false, -- allows the script to randomly choose a random scenario, authority over scenario selection
        scenario_selected = "Georgia Liberation", -- subject to the field above, choose your own scenario 
    },
    operations = {
        recon_minimum_altitude = 1524, -- (meters)
        recon_duration = 120, -- (seconds)
        recon_distance_from_zone = 20000, -- (meters)
        cap_duration = 8*60, -- (seconds)
        cap_max_radius_from_zone = 28*1000, -- (meters)
        max_distance_to_frontline_for_airdrops = 300*1000, -- (meters)
        airdrop_min_crates_landed = 6 -- minimum number of crates that must land to consider the airdrop successful

    },
    jupiter_enabled = true, -- enables/disables the Jupiter command system

    enabled_su25t_bluefor = true, -- adds the SU-25T to the bluefor warehouse inventory

    estimated_users = 1, -- used to scale warehouse stocks and resupply quantities
    red_stock_multiplier = 10, -- multiplier for redfor warehouse stocks, compared to bluefor

    std_resupply_time = 20*60, -- (seconds) respawn resupply aircraft delay
    cooldown_before_capture_attempt = 3*60, -- (seconds)
    retry_capture_chance = 50, -- (%)

    allow_resupply = true, -- this will enable/disable resupply aircrafts, this will make the misison significantly harder

    zone_upgrade_costs_tokens = {
        [1] = 10, -- cost to upgrade from tier 1 to tier 2
        [2] = 30, -- cost to upgrade from tier 2 to tier 3
        [3] = 40, -- cost to upgrade from tier 3 to tier 4
    },
    resupply_tokens_cost = 50, -- cost in tokens to request a resupply aircraft

    reward_system = {
        enable = true, -- completely enables/disables the reward system
        xp_per_mission_completed = 100,
        xp_per_aircraft_destroyed = 25,
        xp_per_helicopter_destroyed = 20,
        xp_per_infantry_kill = 1,
        xp_per_vehicle_destroyed = 5,
        xp_per_sam_destroyed = 10,
        xp_per_structure_destroyed = 40,
        xp_per_ship_sunk = 150,
        xp_per_intel_report = 25,
        landing_time = 15, -- (seconds) the time the player has to stay on the ground to be rewarded

        tokens_on_rank_up = 20, -- random between tokens awarded on rank up
        tokens_on_rank_up_variance = 10,

        tokens_mission_complete = {
            [OperationTypes.AIRDROP] = 15,
            [OperationTypes.CAP] = 10,
            [OperationTypes.CAS] = 20,
            [OperationTypes.SEAD] = 15,
            [OperationTypes.STRIKE] = 15,
            [OperationTypes.DEAD] = 30,
            [OperationTypes.RECON] = 10,
        },

        xp_required = {
            [AITaskTypes.JTAC]           = 3000,
            [AITaskTypes.RECON]          = 6000,
            [AITaskTypes.INTERCEPT]      = 10000,
            [AITaskTypes.CAS]            = 15000,
            [AITaskTypes.STRIKE]         = 20000,
            [AITaskTypes.SEAD]           = 25000,
            [AITaskTypes.CAPTURE_HELO]   = 30000,
            [AITaskTypes.RESUPPLY_CARGO] = 50000,
            [AITaskTypes.AWACS]          = 120000,
        },

        ranks = {
            [1]  = { name = "Airman Basic",      xp_required = 0 },
            [2]  = { name = "Airman",            xp_required = 1000 },
            [3]  = { name = "Airman First Class",xp_required = 3000 },
            [4]  = { name = "Senior Airman",     xp_required = 6000 },
            [5]  = { name = "Staff Sergeant",    xp_required = 10000 },
            [6]  = { name = "Technical Sergeant",xp_required = 15000 },
            [7]  = { name = "Master Sergeant",   xp_required = 20000 },
            [8]  = { name = "Senior Master Sergeant", xp_required = 25000 },
            [9]  = { name = "Chief Master Sergeant",  xp_required = 30000 },

            -- Officer Ranks (Officiers)
            [10] = { name = "Second Lieutenant", xp_required = 40000 },
            [11] = { name = "First Lieutenant",  xp_required = 50000 },
            [12] = { name = "Captain",           xp_required = 60000 },
            [13] = { name = "Major",             xp_required = 90000 },
            [14] = { name = "Lieutenant Colonel",xp_required = 100000 },
            [15] = { name = "Colonel",          xp_required = 120000 },
            [16] = { name = "Brigadier General",xp_required = 140000 },
            [17] = { name = "Major General",    xp_required = 160000 },
            [18] = { name = "Lieutenant General",xp_required = 200000 },
            [19] = { name = "General",          xp_required = 300000 },
            [20] = { name = "Commander",       xp_required = 1000000 },
        }

    },
    theatre = {

        -- Weights for random generation (Airbases are excluded)
        zone_type_weights = {
            [ZoneTypes.STRONGPOINT] = 60,
            [ZoneTypes.LOGISTICS]   = 15,
            [ZoneTypes.SAMSITE]     = 15,
            [ZoneTypes.COMMS]       = 5,
            [ZoneTypes.EWSITE]      = 5,
        },

    },
    tasking_requirements = {
        comms_zones_required_for_jtac = 2,
        comms_zones_required_for_cas = 2,
        comms_zones_required_for_sead = 3,
        comms_zones_required_for_strike = 2,
        comms_zones_required_for_intercept = 1,
        comms_zones_required_for_awacs = 3,
        comms_zones_required_for_recon = 1,

        tokens_required_for_jtac = 5,
        tokens_required_for_cas = 10,
        tokens_required_for_sead = 15,
        tokens_required_for_strike = 15,
        tokens_required_for_intercept = 10,
        tokens_required_for_awacs = 30,
        tokens_required_for_recon = 10,
        tokens_required_for_capture_helicopter = 10,
    },
    comms_tower_respawn_time = 120,--TO CHANGE 20*60, -- (seconds), the timer decreases by 25% for every level
    comms_tower_lost_penalty = 1.5, -- the respawn time is multiplied by this much when a comms tower is lost

    tasking = {
        enable = true, -- enables/disables AI tasking system, does not affect resupply and capture mechanics
        dispatcher_interval = 10*60+8,--5*60, -- (seconds), avoid multiples of 15 to reduce lag spikes
        max_tasks_per_airbase = 4, -- maximum number of concurrent tasks per airbase

        max_jtac_per_airbase = 2,
        max_cas_per_airbase = 1,
        max_sead_per_airbase = 2,
        max_strike_per_airbase = 2,
        max_intercept_per_airbase = 2,
        max_awacs_per_airbase = 1,
        max_recon_per_airbase = 2,

        max_jtac_theatre = 4, -- per coalition, only for AI auto tasking
        max_cas_theatre = 4,-- per coalition, only for AI auto tasking
        max_sead_theatre = 4,-- per coalition , only for AI auto tasking
        max_strike_theatre = 4,-- per coalition, only for AI auto tasking
        max_intercept_theatre = 6,-- per coalition, only for AI auto tasking
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
    cargo_aicraft = {
        "C-130J-30"
    },

    capture_helicopter_max_range = 100*1000 , -- (meters)

    max_ground_recon_range = 30000, -- (meters) the range at which enemy zones will be discovered from friendly zones

    stuck_convoy_timeout = 8*60, -- (seconds) time without movement after which a convoy is considered stuck and will be removed
    attack_convoy_range = 30000, -- (meters)

    jtac_smoke_stock = 4,

    -- logistics_upgrade_range = 30000, -- (meters)
    logistics_upgrade_chance = 100,--10, -- (%) every minute the dice is rolled
    logistics_level_up_interval = 5*60, -- (seconds) minimum time between level ups
    logistics_ammo_depot_respawn_time = 7*60, -- (seconds) time it takes for an ammo depot to respawn after being destroyed
    airbase_command_center_respawn_time = 70, -- (seconds) time it takes for a command center to respawn after being destroyed

    upgrade_tier_range = 50000,

    EWRS = {
        enable = true, -- enables/disables the EWRS system
        standard_refresh_time = 20, -- (seconds)
        max_aircraft_per_text = 8, -- maximum number of aircraft displayed per message
    },

    draw_color_palette = {
        -- for rgb, divide values by 255 to get 0-1 range
        red_palette = {
            {0.7, 0, 0, 0.9},   -- Border color (r g b: values from 0 to 1, a: alpha from 0 to 1)
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
    blue_resupply_step = 1, -- prevents random resupply type repetition

    red_sam_sites = 0,
    red_logistics_zone = 0,
    red_comms_zones = 0,
    red_airbases = 0,
    red_ew_zones = 0,
    red_strongpoints = 0,
    red_total_comms_zones = 0,

    red_comms_antennas = 0,
    red_discovered_zones = {},
    red_enroute_resupply = {},
    red_resupply_step = 1 -- prevents random resupply type repetition

}




-- This table allows you to link the in-mission groups to the script logic
-- Group names from the mission editor. They must be exactly the same.
GroupData = {
    COMMON_ASSETS = {
        BLUE = {
            resupply_aircraft = "C130",
            capture_convoy = "BLUE Capture Convoy",
            capture_helicopter = "BLUE Capture Helo",
            attack_convoy = "BLUE Attack Convoy"
        },
    
        RED = {
            resupply_aircraft = "IL76",
            capture_convoy = "RED Capture Convoy",
            capture_helicopter = "RED Capture Helo",
            attack_convoy = "RED Attack Convoy"
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
    }


}