--[[
    DCS CATALYST MISSION CONFIG FILE

    do not remove the commas at the end of each line
    make sure not to edit anything outside the config table below

]]


Config = {
    fog_of_war = true,

    persistance = {
        enable = false,
        save_interval = 30,--5*60, -- (seconds) interval at which the mission state is saved
        save_dir = "Missions/Saves/",
        save_file = "mission.json",

        enable_user_data_persistance = true, --persistance.enable has authority over this
        user_data_file = "user_data.json",

        
        random_scenario_selection = false,
        scenario_selected = "Neptune Protocol",
    },  

    std_resupply_time = 20*60, -- (seconds) respawn resupply aircraft delay
    cooldown_before_capture_attempt = 3*60, -- (seconds)
    retry_capture_chance = 50, -- (%)

    allow_resupply = true, -- this will enable/disable resupply aircrafts, this will make the misison significantly harder


    reward_system = {
        enable = true,
        xp_per_mission_completed = 100,
        xp_per_aircraft_destroyed = 25,
        xp_per_helicopter_destroyed = 20,
        xp_per_infantry_kill = 1,
        xp_per_vehicle_destroyed = 5,
        xp_per_sam_destroyed = 10,
        xp_per_structure_destroyed = 40,
        xp_per_ship_sunk = 150,
        xp_per_intel_report = 25,
        token_per_mission_completed = 5,
        landing_time = 15, -- (seconds) the time the player has to stay on the ground to be rewarded

        ranks = {
            [1] = { name = "Airman",       xp_required = 0 },
            [2] = { name = "Sergeant",     xp_required = 1000 },
            [3] = { name = "Lieutenant",   xp_required = 5000 },
            [4] = { name = "Captain",      xp_required = 10000 },
            [5] = { name = "Major",        xp_required = 20000 },
            [6] = { name = "Colonel",      xp_required = 40000 },
            [7] = { name = "General",      xp_required = 60000 },
            [8] = { name = "Marshal",      xp_required = 100000 },
            [9] = { name = "Field Marshal",xp_required = 150000 },
            [10] = { name = "Commander", xp_required = 200000 }
        }

    },

    max_comms_zones = 5,
    tasking_requirements = {
        comms_zones_required_for_jtac = 2,
        comms_zones_required_for_cas = 2,
        comms_zones_required_for_sead = 3,
        comms_zones_required_for_strike = 2,
        comms_zones_required_for_intercept = 1,
        comms_zones_required_for_awacs = 3,
        comms_zones_required_for_recon = 1
    },
    comms_tower_respawn_time = 120,--TO CHANGE 20*60, -- (seconds), the timer decreases by 25% for every level
    comms_tower_lost_penalty = 1.5, -- the respawn time is multiplied by this much when a comms tower is lost

    tasking = {
        enable = true,
        dispatcher_interval = 5*60, -- (seconds)
        max_tasks_per_airbase = 4,
        max_jtac_per_airbase = 2,
        max_cas_per_airbase = 2,
        max_sead_per_airbase = 2,
        max_strike_per_airbase = 2,
        max_intercept_per_airbase = 2,
        max_awacs_per_airbase = 1,
        max_recon_per_airbase = 2,

        max_awacs_theatre = 2,


        max_cas_range = 150*1000, -- (meters)
        min_cleareance_dist_for_awacs = 70*1000 -- (meters) from the nearest enemy zone
    },
    tasking_max_groups_per_airbase = 4,


    capture_helicopter_max_range = 100*1000 , -- (meters)
    capture_convoy_max_range = 100,--25*1000, -- (meters)


    max_ground_recon_range = 15000, -- (meters)
    --[[
        the range at which enemy zones will be discovered from friendly zones
    ]]
    stuck_convoy_timeout = 8*60, -- (seconds) time without movement after which a convoy is considered stuck and will be removed
    attack_convoy_range = 30000, -- (meters)

    jtac_smoke_stock = 4,
    ewrs_standard_refresh_time = 20, -- (seconds)

    logistics_upgrade_range = 30000, -- (meters)
    logistics_upgrade_chance = 100,--10, -- (%) every minute the dice is rolled
    logistics_level_up_interval = 5*60, -- (seconds) minimum time between level ups
    logistics_ammo_depot_respawn_time = 7*60, -- (seconds) time it takes for an ammo depot to respawn after being destroyed


    upgrade_tier_range = 50000,

    messages = {
        enable_capture = true,
        enable_level_up = true,
        enable_resupply = true,
        ai_dispatcher = true,
    },


}

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

    blue_retry_capture_chance = 50,
    blue_capture_lost_zone_chance = 30,
    blue_discovered_zones = {},
    blue_enroute_resupply = {},
    blue_resupply_step = 1, -- prevents random resupply type repetition

    red_sam_sites = 0,
    red_logistics_zone = 0,
    red_farp_zones = 0,
    red_comms_zones = 0,
    red_airbases = 0,
    red_ew_zones = 0,
    red_strongpoints = 0,

    red_retry_capture_chance = 50,
    red_capture_lost_zone_chance = 30,
    red_discovered_zones = {},
    red_enroute_resupply = {},
    red_resupply_step = 1 -- prevents random resupply type repetition

}





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

    SAM_SITES = {
        SA2_LEVEL_1 = {
            group_name = "RED SAM SA2 TIER 1",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 1,
            threat_dist = 45 --stands for the high threat radius in km
        },
        SA2_LEVEL_2 = {
            group_name = "RED SAM SA2 TIER 2",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 2,
            threat_dist = 45
        },
        SA2_LEVEL_3 = {
            group_name = "RED SAM SA2 TIER 3",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 3,
            threat_dist = 45
        },
        SA2_LEVEL_4 = {
            group_name = "RED SAM SA2 TIER 4",
            side = coalition.side.RED,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 4,
            threat_dist = 45
        },
    
        HAWK_LEVEL_1 = {
            group_name = "BLUE SAM HAWK TIER 1",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 1,
            threat_dist = 40 --stands for the high threat radius in km
        },
        HAWK_LEVEL_2 = {
            group_name = "BLUE SAM HAWK TIER 2",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 2,
            threat_dist = 40 --stands for the high threat radius in km
        },
        HAWK_LEVEL_3 = {
            group_name = "BLUE SAM HAWK TIER 3",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 3,
            threat_dist = 40 --stands for the high threat radius in km
        },
        HAWK_LEVEL_4 = {
            group_name = "BLUE SAM HAWK TIER 4",
            side = coalition.side.BLUE,
            sam_classification = SAM_TYPES.MEDIUM_RANGE,
            level = 4,
            threat_dist = 40 --stands for the high threat radius in km
        },
        -- SA3 = {
        --     name = "SA3",
        --     group_name = "SAM SA3",
        --     threat_dist = 20
        -- },
        -- SA6 = {
        --     name = "SA6",
        --     group_name = "SAM SA6",
        --     threat_dist = 26
        -- },
        -- SA5 = {
        --     name = "SA5",
        --     group_name = "SAM SA5",
        --     threat_dist = 250
        -- }
    },

    AIRBASE_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            }
        }
    },

    LOGISTICS_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            }
        }
    },

    COMMS_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE GRND TEST"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            }
        }
    },

    EW_SITES = {
        BLUE = {
            [1] = {
                level = 1,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR"
            },
            [2] = {
                level = 2,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR"
            },
            [3] = {
                level = 3,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR"
            },
            [4] = {
                level = 4,
                side = coalition.side.BLUE,
                group_name = "BLUE EWR"
            }
        },
        RED = {
            [1] = {
                level = 1,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [2] = {
                level = 2,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [3] = {
                level = 3,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            },
            [4] = {
                level = 4,
                side = coalition.side.RED,
                group_name = "RED GRND TEST"
            }
        }
    }


}







MissionLogger = mist.Logger:new("MissionLogger", 3)