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
-- (value)
Config = {
    -- (int) config version should not be edited unless comprehensively understood
    _config_file_version = 1,
    -- (int) scenario file version should not be edited unless comprehensively
    -- understood
    _scenario_file_version = 1,
    -- (int) mission version should not be edited unless comprehensively understood
    _mission_version = 6,
    -- (bool) development setting, set to false to prevent the mission from loading
    -- this config (will use default values instead)
    _enable_external_config = false,
    -- (int) (meters) max distance a frontline segment may extend from the midpoint
    -- between the two opposing zones that generate it
    frontline_max_extent = 35000,
    -- (table)
    persistence = {
        -- (bool) enables or not persistence, has authority over everything below in
        -- this section
        enable =  false,
        -- (int) (seconds) interval at which the mission state is saved You can use
        -- fixed values or multiplications like above 51 seconds is used to avoid
        -- multiples of 15 to reduce lag spikes
        save_interval = 4*51,

        -- (string) this is your Saves directory in Saved Games save_dir =
        -- "Missions/Saves/Crossfire Syrian Resolve v5/", If you would like to create a
        -- new mission, simple change the last folder name
        save_dir = "Missions/Saves/",

        -- (string) this is the name of the mission file
        save_file = "mission.json",
        -- (string) this is the name of user data only file, note that this only saves
        -- user xp and rank
        user_data_file = "user_data.json",

        -- (bool) enables/disables CTLD placed asset persistence
        enable_ctld_persistence = true,

        -- scenario_selected is no longer used. Theatre is auto-detected from env.mission.theatre;
    },

    -- (table) server-only behaviours
    server = {
        -- (bool) when a coalition wins, delete the mission
        -- progress save file (user XP/rank data is kept) and restart the mission.
        -- Intended for dedicated servers running the mission on a loop.
        reset_on_mission_end = false,

        -- (int) (seconds) delay between the win announcement and the restart, so
        -- players can read the result before the mission reloads
        reset_delay = 60,
    },

    -- (table)
    era_system = {

        -- (table<enum>) REQUIRES MISSION RESTART. You can choose one or more eras to be active in the mission.
        -- "WW2" -1947
        -- "Early Cold War" 1947-1969
        -- "Late Cold War" 1969-1989
        -- "Modern" 1989-
        eras_selected = { Eras.LATECOLDWAR},

        -- (table<...>) When this is empty, the script considers all modules flyable.
        -- To restrict to a specific set of aircraft, list them
        -- explicitly by type name for example: enabled_aircraft = { "FA-18C_hornet", "F-15ESE",
        -- "F-16C_50", "A-10C_2", },
        enabled_aircraft = {},

        -- (table<string>)
        restricted_weapons = {
            "weapons.bombs.RN-24",
            "weapons.bombs.RN-28"
        },

        -- (table<enum>)
        carrier_eras_allowed = { Eras.LATECOLDWAR, Eras.MODERN},
        -- (table<enum>)
        lha_eras_allowed = { Eras.LATECOLDWAR, Eras.MODERN},

        -- (table<enum,table<enum>>) Country composition used when
        -- generating ground units for each coalition. The values are country ids (https://wiki.hoggitworld.com/view/DCS_enum_country)
        coalition_selector = {
            -- (table<enum>) BLU COALITION, NATO MIX
            [coalition.side.BLUE] = { country.id["USA"], country.id["UK"], country.id["FRANCE"], country.id["GERMANY"], country.id["ITALY"] },
            -- (table<enum>) RED COALITION Russia only
            [coalition.side.RED] = {country.id["RUSSIA"]},
        },
        -- (table<enum,table<enum>>) REQUIRES MISSION RESTART. Disable certain zone types for certain eras.
        -- Select from: "SAMSITE", "EWSITE", "FARP", "AIRBASE", "LOGISTICS", "STRONGPOINT", "COMMS"
        disable_zone_types_for_era = {
            -- (table<enum>)
            [Eras.WW2]          = { ZoneTypes.SAMSITE, ZoneTypes.EWSITE, ZoneTypes.FARP},
            -- (table<enum>)
            [Eras.EARLYCOLDWAR] = { ZoneTypes.SAMSITE },
            [Eras.LATECOLDWAR] = {},
            [Eras.MODERN] = {},
        },

        -- (table<int,int>) Approximate number of ground units to spawn per zone, keyed
        -- by zone tier (1..4). Airbases are handled separately (see
        -- airbase_tier1_units below).
        units_per_tier = {
            -- (int) level 1: ~2 units (1 infantry + 1 truck); airbases override to ~5 (see
            -- airbase_tier1_units)
            [1] = 2,
            -- (int) level 2: ~6 units
            [2] = 6,
            -- (int) level 3: ~10 units
            [3] = 10,
            -- (int) level 4: ~15 units
            [4] = 15,
        },
        -- (int) number of ground units used for a level 1 airbase zone (overrides
        -- units_per_tier[1] for airbases)
        airbase_tier1_units = 5,
        -- (number) fractional +/- variance applied to per-zone unit counts so groups
        -- are not identical every spawn (0.2 = +/-20%)
        composition_randomness = 0.2,
    },
    -- (table)
    operations = {
        -- (int) (seconds)
        recon_duration = 120,
        -- (int) (meters)
        recon_distance_from_zone = 20000,
        -- (int) (seconds)
        cap_duration = 8*60,
        -- (int) (meters)
        cap_max_radius_from_zone = 28*1000,
        -- (int) (meters)
        max_distance_to_frontline_for_airdrops = 100*1000,
        -- (int) (meters) distance from downed pilot required to complete rescue
        csar_rescue_radius = 50,
        -- (int) number of aircraft/helicopters to destroy to complete INTERCEPT
        intercept_required_kills = 2,
        -- (int) (meters) max distance from friendly zone to enemy zone for INTERCEPT
        -- to be proposed
        intercept_max_distance_to_enemy = 200*1000,
        -- (table<string>) unit attributes that make them valid SEAD targets
        attributes_for_SEAD_targeting = { 'SAM SR', 'SAM TR', 'IR Guided SAM', 'EWR' },
        -- (int) (seconds) runtime-only runway disable duration
        runway_destroyed_duration = 60*60,
        
        -- (int) (meters)
        reinforcement_max_range = 50*1000,
        -- (int) supplies required to upgrade a zone via AIRDROP / REINFORCEMENT (ex:
        -- 300 with 50/crate => 6 supply crates)
        upgrade_required_supplies = 300,

        -- (table)
        strategic_airlift = {
            -- (bool)
            enabled = true,
            -- (number) (meters) packed object is considered boarded when above this AGL
            -- threshold
            boarded_object_height_agl = 0.5,
            -- (int) (seconds) hold near destination before completion
            stage_hold_duration = 45,
            -- (int) supplies granted to the destination area when strategic airlift
            -- completes
            completion_supply_bonus = 900,
            -- (int) random variance applied to the completion supply bonus
            completion_supply_bonus_variance = 150,

            -- (int)
            min_manifest_items = 3,
            -- (int)
            max_manifest_items = 6,
            -- (table)
            category_weights = {
                -- (int)
                troops = 35,
                -- (int)
                crates = 40,
                -- (int)
                vehicles = 25,
            },
            -- (int) avoids very heavy/slow manifests for this operation type
            max_vehicle_crates_required = 3,



            -- (int)
            min_route_distance = 20*1000,
            -- (int)
            max_route_distance = 200*1000,

            -- (int)
            seconds_per_km = 65,
            -- (int)
            min_time = 20*60,
            -- (int)
            max_time = 90*60,
            -- (int)
            supplies_per_asset = 180,
            -- (int)
            base_xp = 1200,
            -- (int)
            xp_per_km = 2,
        },

        -- (int) (seconds) this is to set a cooldown for generating operations
        operation_refresh_time = 30,

        
        -- (table<enum,table<string>>)
        aircraft_filter = {
            -- (table<string>)
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
            -- (table<string>)
            [OperationTypes.AIRDROP] = {
                "C-130J-30",
            },
            -- (table<string>)
            [OperationTypes.STRATEGIC_AIRLIFT] = {
                "C-130J-30",
            },
            -- (table<string>)
            [OperationTypes.REINFORCEMENT] = {
                "CH-47Fbl1",
                "UH-1H",
                "Mi-8MT",
                "Mi-24P",
                "SA342L",
                "SA342M",
                "SA342Mistral",
                "SA342Minigun",
                "UH-60L",
            },
            -- (table<string>)
            [OperationTypes.CAS] = {
                "A-10C_2",
                "Su-25T",
                "AV8BNA",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "F-14A-135-GR",
                "JF-17",
                "AH-64D_BLK_II",
                "Ka-50_3",
                "Mi-24P",
                "SA342L",
                "SA342M",
                "Su-25",
                "A-10A",
                "AJS37",
                "F-5E-3",
                "F-5E-3_FC",
                "F-4E-45MC",
                "F-100D",
                "Mirage-F1CE",
                "Mirage-F1EE",
                "MiG-21Bis",
                "L-39ZA",
                "C-101CC",
                "MB-339A",
                "MB-339APAN",
                "P-47D-30",
                "P-47D-40",
                "P-51D",
                "P-51D-30-NA",
                "F4U-1D",
                "F4U-1D_CW",
                "FW-190A8",
                "FW-190D9",
                "Bf-109K-4",
                "SpitfireLFMkIX",
                "SpitfireLFMkIXCW",
                "MosquitoFBMkVI",
                "I-16",
                "La-7",
            },
            -- (table<string>)
            [OperationTypes.DEAD] = {
                "A-10C_2",
                "Su-25T",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "AV8BNA",
                "JF-17",
                "Su-25",
                "A-10A",
                "AJS37",
                "F-4E-45MC",
                "Mirage-F1CE",
                "Mirage-F1EE",
            },
            -- (table<string>)
            [OperationTypes.STRIKE] = {
                "A-10C_2",
                "Su-25T",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "AV8BNA",
                "JF-17",
                "AH-64D_BLK_II",
                "Su-25",
                "A-10A",
                "AJS37",
                "F-5E-3",
                "F-5E-3_FC",
                "F-4E-45MC",
                "F-100D",
                "Mirage-F1CE",
                "Mirage-F1EE",
                "L-39ZA",
                "C-101CC",
                "MB-339A",
                "MB-339APAN",
                "P-47D-30",
                "P-47D-40",
                "P-51D",
                "P-51D-30-NA",
                "F4U-1D",
                "F4U-1D_CW",
                "FW-190A8",
                "FW-190D9",
                "Bf-109K-4",
                "SpitfireLFMkIX",
                "SpitfireLFMkIXCW",
                "MosquitoFBMkVI",
                "I-16",
                "La-7",
            },
            -- (table<string>)
            [OperationTypes.RUNWAY_BOMBING] = {
                "F-14A-135-GR",
                "F-14B",
                "M-2000C",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "AJS37",
                "JF-17",
                "AV8BNA",
                "F-100D",
                "F-4E-45MC",
                "Mirage-F1CE",
                "Mirage-F1EE",
                "A-10A",
                "Su-25",
                "MosquitoFBMkVI",
                "P-47D-30",
                "P-47D-40",
            },
            -- (table<string>)
            [OperationTypes.CAP] = {
                "F-15C",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "F-14A-135-GR",
                "F-14B",
                "MiG-29A",
                "JF-17",
                "MiG-21Bis",
                "MiG-19P",
                "MiG-15bis",
                "MiG-15bis_FC",
                "F-5E-3",
                "F-5E-3_FC",
                "F-4E-45MC",
                "F-86F Sabre",
                "F-86F_FC",
                "F-100D",
                "Mirage-F1CE",
                "Mirage-F1EE",
                "P-51D",
                "P-51D-30-NA",
                "TF-51D",
                "P-47D-30",
                "P-47D-40",
                "F4U-1D",
                "F4U-1D_CW",
                "FW-190A8",
                "FW-190D9",
                "Bf-109K-4",
                "SpitfireLFMkIX",
                "SpitfireLFMkIXCW",
                "MosquitoFBMkVI",
                "I-16",
                "La-7",
            },
            -- (table<string>)
            [OperationTypes.INTERCEPT] = {
                "F-15C",
                "F-15ESE",
                "F-16C_50",
                "FA-18C_hornet",
                "M-2000C",
                "F-14A-135-GR",
                "F-14B",
                "MiG-29A",
                "JF-17",
                "MiG-21Bis",
                "MiG-19P",
                "MiG-15bis",
                "MiG-15bis_FC",
                "F-5E-3",
                "F-5E-3_FC",
                "F-4E-45MC",
                "F-86F Sabre",
                "F-86F_FC",
                "F-100D",
                "Mirage-F1CE",
                "Mirage-F1EE",
                "P-51D",
                "P-51D-30-NA",
                "TF-51D",
                "P-47D-30",
                "P-47D-40",
                "F4U-1D",
                "F4U-1D_CW",
                "FW-190A8",
                "FW-190D9",
                "Bf-109K-4",
                "SpitfireLFMkIX",
                "SpitfireLFMkIXCW",
                "I-16",
                "La-7",
            },
            -- (table<string>)
            [OperationTypes.SEAD] = {
                "F-16C_50",
                "FA-18C_hornet",
                "A-10C_2",
                "Su-25T",
                "AJS37",
                "JF-17",
                "AV8BNA",
                "Su-25",
                "A-10A",
                "F-4E-45MC",
                "Mirage-F1CE",
                "Mirage-F1EE",
            },
        },
        -- (int) maximum number of players (including leader) in a joint operation
        joint_op_max_members = 8,
    },
    -- (bool) enables/disables the Jupiter command system
    jupiter_enabled = true,
    -- (string) password required before the -, example password = "12" then the
    -- command is 12-discover
    jupiter_password = "",

    -- (bool) prevents or not air spawns for players
    allow_air_spawn = true,
    -- (bool) enables/disables the slot blocker system to prevent players spawning
    -- in enemy airbases
    enable_slot_blocker = true,
    -- (bool) this does not disable/enable the system, but stocks will be nearly
    -- unlimited if disabled
    enable_warehouse = true,
    -- (bool) this will enable/disable resupply aircrafts, this will make the
    -- misison significantly harder
    allow_resupply = true,
    -- (bool) adds the SU-25T to the blufor warehouse inventory
    enabled_su25t_blufor = true,

    -- (int) multiplier for redfor only warehouse stocks
    red_stock_multiplier = 50,
    -- (bool) enables/disables AI payload checks, this will prevent AI from
    -- spawning with no weapons You must turn this off if you change AI aircraft
    -- loadouts. Alternatively, you can edit the loadouts in the WarehouseManager
    -- to match your custom loadouts.
    enable_ai_payload_checks = true,

    -- (table) Auto scaling of warehouse weapon stocks to the number of human
    -- players. When enabled, generated weapon quantities are multiplied by the
    -- live player count so a busy server keeps more stock and a quiet one keeps
    -- less. When disabled, stocks are generated for a single player's worth (scale
    -- 1).
    auto_scaling = {
        -- (bool) on/off switch for player-count based stock scaling
        enable = true,
        -- (int) never scale below this many players' worth of stock
        min_users = 1,
        -- (int) cap the scaling so a full server cannot explode stock
        max_users = 16,
        -- (int) players represented by one "unit" of base stock (1 = linear per
        -- player)
        users_per_unit = 1,
    },

    -- (int) (seconds)
    cooldown_before_capture_attempt = 10*60,
    -- (int) (%) Every minute, subject to various checks and conditions
    retry_capture_chance = 50,
    -- (int) (%) for every minute
    reinforcement_chance = 3,

    -- (int) (seconds) periodic resupply aircraft time interval
    std_resupply_time = 45*60,
    -- (bool) enables/disables random resupply types, if disabled only INITIAL
    -- resupplies will arrive INITIAL resupply is equivalent to what the warehouses
    -- were given at mission start
    random_resupply_types = true ,

    -- (table)
    supplies = {
        -- (int) starting supplies per zone (only for Airbases and FARPs)
        initial_stock = 1000,
        -- (int) supplies gained per minute from each alive ammo depot in logistics
        -- zones
        supplies_income = 20,
        -- (int) supplies gained when capturing an enemy zone
        supplies_looted_on_destroyed = 500,
        -- (int) (+/-) supplies variance when capturing an enemy zone
        supplies_looted_on_destroyed_variance = 200,

        -- (table)
        resupply_costs = {

            -- (int) Full initial warehouse stock restoration
            INITIAL = 10000,
            -- (int) FARP complete resupply
            FARP = 2500,
            
            -- (int) Air-to-air focused aircraft
            AA_AIRCRAFT = 750,
            -- (int) Air-to-ground focused aircraft
            AG_AIRCRAFT = 750,
            -- (int) Multirole aircraft
            MULTIROLE_AIRCRAFT = 900,
            -- (int) Reconnaissance aircraft
            RECON_AIRCRAFT = 500,
            -- (int) Transport/utility aircraft
            CARGO_AIRCRAFT = 500,
            -- (int) NOT YET ADDED. Attack helicopters
            ATTACK_HELICOPTER = 900,
            -- (int) NOT YET ADDED. Transport/logistics helicopters
            LOGISTICS_HELICOPTER = 400,


            -- (int) AIM-120, AIM-54, etc.
            AIR_AIR_LONG_RANGE = 750,
            -- (int) AIM-9, R-73, etc.
            AIR_AIR_SHORT_RANGE = 500,
            
            -- (int) AGM-65, Hellfire, etc.
            AIR_GROUND_GUIDED_MISSILES = 750,
            -- (int) GBU-12, GBU-38, etc.
            AIR_GROUND_GUIDED_BOMBS = 600,
            -- (int) Mk-82, Mk-84, etc.
            AIR_GROUND_BOMBS = 250,
            -- (int) Hydra, S-8, etc.
            AIR_GROUND_ROCKETS = 150,

            -- (int) NOT YET ADDED. External fuel/drop tanks
            FUEL_TANKS = 600,

            -- (int) Jamming pods, countermeasures
            ECM = 2500,
            -- (int) Targeting pods, misc equipment
            TGP_MISC = 2000,
        },
        -- (table)
        tasking_costs = {
            -- (int)
            JTAC = 250,
            -- (int)
            CAS = 500,
            -- (int)
            SEAD = 600,
            -- (int)
            STRIKE = 500,
            -- (int)
            CAP = 400,
            -- (int)
            AWACS = 350,
            -- (int)
            TANKER = 400,
            -- (int)
            RECON = 300,
            -- (int)
            CAPTURE_HELO = 150,
            -- (int)
            NAVAL_STRIKE = 3500
        },
        -- (table<int,int>)
        supplies_production = {
            -- (int)
            [1] = 5,
            -- (int)
            [2] = 10,
            -- (int)
            [3] = 20,
            -- (int)
            [4] = 25
        },
        -- (int)
        logistics_mult = 2,
        -- (table<int,int>) per zone level
        supplies_cap = {
            -- (int)
            [1] = 1500,
            -- (int)
            [2] = 2500,
            -- (int)
            [3] = 3500,
            -- (int)
            [4] = 5000,
        },
    },

    -- (table)
    reward_system = {
        -- (bool) completely enables/disables the reward system
        enable = true,
        -- (int)
        xp_per_aircraft_destroyed = 100,
        -- (int)
        xp_per_helicopter_destroyed = 75,
        -- (int)
        xp_per_infantry_kill = 5,
        -- (int)
        xp_per_vehicle_destroyed = 15,
        -- (int)
        xp_per_sam_destroyed = 50,
        -- (int)
        xp_per_ship_sunk = 300,
        -- (int)
        xp_per_intel_report = 50,
        -- (int) (seconds) the time the player has to stay on the ground to be rewarded
        landing_time = 15,
        -- (number) (fraction) portion of unclaimed XP awarded on ejection (0.20 =
        -- 20%), set to 0 to disable
        eject_xp_payout = 0.20,

        -- (int)
        xp_lost_per_kill_fatricide = 1000,

        -- (int)
        naval_stike_xp_required = 8000,

        -- (number) Joint operation reward bonuses (%) bonus to XP and tokens when
        -- playing joint operations (multiplier applied to XP)
        joint_op_xp_bonus = 0.25,

        -- (table<enum,int>)
        xp_required = {
            -- (int)
            [AITaskTypes.JTAC]           = 0,
            -- (int)
            [AITaskTypes.RECON]          = 2000,
            -- (int)
            [AITaskTypes.CAP]            = 5000,
            -- (int) (Major milestone)
            [AITaskTypes.CAS]            = 10000,
            -- (int) Technical Sergeant
            [AITaskTypes.TANKER]         = 12000,
            -- (int)
            [AITaskTypes.STRIKE]         = 15000,
            -- (int) ~25 hours
            [AITaskTypes.SEAD]           = 20000,
            -- (int)
            [AITaskTypes.CAPTURE_HELO]   = 5000,
            -- (int)
            [AITaskTypes.RESUPPLY_CARGO] = 40000,
            -- (int) ~70 hours
            [AITaskTypes.AWACS]          = 60000,
        },

        -- (table<int,table>)
        ranks = {
            -- (table)
            [1]  = { name = "Airman Basic",      xp_required = 0 },
            -- (table)
            [2]  = { name = "Airman",            xp_required = 1000 },
            -- (table)
            [3]  = { name = "Airman First Class",xp_required = 2500 },
            -- (table)
            [4]  = { name = "Senior Airman",     xp_required = 5000 },
            -- (table)
            [5]  = { name = "Staff Sergeant",    xp_required = 8000 },
            -- (table)
            [6]  = { name = "Technical Sergeant",xp_required = 12000 },
            -- (table)
            [7]  = { name = "Master Sergeant",   xp_required = 16000 },
            -- (table)
            [8]  = { name = "Senior Master Sergeant", xp_required = 20000 },
            -- (table)
            [9]  = { name = "Chief Master Sergeant",  xp_required = 25000 },

            -- (table)
            [10] = { name = "Second Lieutenant", xp_required = 32000 },
            -- (table)
            [11] = { name = "First Lieutenant",  xp_required = 40000 },
            -- (table)
            [12] = { name = "Captain",           xp_required = 48000 },
            -- (table)
            [13] = { name = "Major",             xp_required = 58000 },
            -- (table)
            [14] = { name = "Lieutenant Colonel",xp_required = 68000 },
            -- (table)
            [15] = { name = "Colonel",           xp_required = 78000 },
            -- (table)
            [16] = { name = "Brigadier General", xp_required = 85000 },
            -- (table)
            [17] = { name = "Major General",     xp_required = 90000 },
            -- (table)
            [18] = { name = "Lieutenant General",xp_required = 95000 },
            -- (table)
            [19] = { name = "General",           xp_required = 98000 },
            -- (table)
            [20] = { name = "Commander",         xp_required = 100000 },
        }

    },
    -- (table)
    theatre = {

        -- (table<enum,int>) Weights for random generation (Airbases are excluded) 50%
        -- of zones will be strongpoints 20% logistics
        zone_type_weights = {
            -- (int)
            [ZoneTypes.STRONGPOINT] = 50,
            -- (int)
            [ZoneTypes.LOGISTICS]   = 20,
            -- (int)
            [ZoneTypes.FARP]        = 5,
            -- (int)
            [ZoneTypes.SAMSITE]     = 15,
            -- (int)
            [ZoneTypes.COMMS]       = 10,
            -- (int)
            [ZoneTypes.EWSITE]      = 5,
        },
        -- (int) seed determines scenario selection, zone types and levels. Use -1 for random seed
        seed = -1,
        -- (table)
        sam_classification_thresholds = {
            -- (int) (%) rolls below this : SHORT RANGE SAM
            short_range  = 15,
            -- (int) (%) rolls below this (and above short_range) : MEDIUM RANGE SAM above
            -- medium_range threshold : LONG_RANGE SAM
            medium_range = 60,
        },

    },
    -- (table) *checks if rnough antennas are alive, not the zones themselves
    tasking_requirements = {
        -- (int)
        comms_zones_required_for_jtac = 0,
        -- (int)
        comms_zones_required_for_cas = 2,
        -- (int)
        comms_zones_required_for_sead = 2,
        -- (int)
        comms_zones_required_for_strike = 2,
        -- (int)
        comms_zones_required_for_cap = 1,
        -- (int)
        comms_zones_required_for_awacs = 2,
        -- (int)
        comms_zones_required_for_tanker = 2,
        -- (int)
        comms_zones_required_for_recon = 1,
    },
    
    -- (table)
    tasking = {
        -- (bool) enables/disables AI tasking system, does not affect resupply and
        -- capture mechanics
        enable = true,
        
        -- (int) (seconds), avoid multiples of 15 to reduce lag spikes
        BLUFOR_dispatcher_interval = 10*60+8,
        -- (int) (seconds), avoid multiples of 15 to reduce lag spikes
        REDFOR_dispatcher_interval = 8*60+8,
        -- (int) maximum number of concurrent tasks per airbase
        max_tasks_per_airbase = 4,
        -- (int) minimum aircraft to leave in stock so AI does not empty the warehouse
        warehouse_aircraft_reserve = 2,
        
        -- (int)
        max_jtac_per_airbase = 2,
        -- (int)
        max_cas_per_airbase = 1,
        -- (int)
        max_sead_per_airbase = 2,
        -- (int)
        max_strike_per_airbase = 2,
        -- (int)
        max_cap_per_airbase = 2,
        -- (int)
        max_awacs_per_airbase = 1,
        -- (int)
        max_tanker_per_airbase = 1,
        -- (int)
        max_recon_per_airbase = 1,
        
        -- (int) per coalition, only for AI auto tasking
        max_jtac_theatre = 4,
        -- (int) per coalition, only for AI auto tasking
        max_cas_theatre = 4,
        -- (int) per coalition , only for AI auto tasking
        max_sead_theatre = 4,
        -- (int) per coalition, only for AI auto tasking
        max_strike_theatre = 4,
        -- (int) per coalition, only for AI auto tasking
        max_cap_theatre = 6,
        -- (int) per coalition, only for AI auto tasking
        max_recon_theatre = 4,
        -- (int) per coalition, only for AI auto tasking
        max_awacs_per_theatre = 2,
        -- (int) per coalition
        max_tanker_per_theatre = 2,
        -- (int) per coalition, only for AI auto tasking
        max_attack_convoy_per_theatre = 3,
        -- (int) per coalition, WW2-only ground capture convoys (replaces capture helos)
        max_capture_convoy_per_theatre = 3,
        -- (int) per coalition, max resupply aircraft 
        max_resupply_per_theatre = 2,

        -- (int)
        max_capture_helicopters_per_logistics_zone = 4,
        -- (int)
        max_attack_convoys_per_strongpoint_zone = 2,
        -- (int)
        max_awacs_theatre = 2,
        
        -- (int) (meters)
        range_for_recon_to_discover_zone = 15*1000,
        -- (int) (meters)
        max_cas_range = 200*1000,
        -- (int) (meters)
        max_strike_range = 200*1000,
        -- (int) (meters)
        max_sead_range = 200*1000,
        -- (int) (meters) from the nearest enemy zone
        min_cleareance_dist_for_awacs = 70*1000
    },

    -- (table)
    tanker = {
        -- (int) (seconds)
        spawn_delay_min = 12,
        -- (int) (seconds)
        spawn_delay_max = 12,
        -- (int) (meters) nearest enemy zone to source airbase
        minimum_enemy_distance = 10*1000,
        -- (number) place tanker sector at this ratio from source toward nearest enemy
        -- zone
        midpoint_ratio = 0.5,
        -- (int) (meters) switch leg when this close to endpoint
        route_switch_distance = 3000,
        -- (int) (meters) straight refuel leg length
        leg_length = 100*1000,
        -- (int) (meters) width of drawn sector corridor
        sector_width = 40*1000,
        -- (int) (meters)
        rounded_corner_radius = 5000,
        -- (int) number of segments per corner arc
        rounded_corner_segments = 5,
        -- (int)
        edge_inset = 10*1000,


        -- (string)
        text_title = "Tanker Sector",
        -- (table<number>)
        text_color = {56/255,56/255,56/255,1},
        -- (table<number>)
        text_background = {156/255,156/255,156/255,0.6},
        -- (table<number>)
        line_color = {156/255,156/255,156/255,1},

        -- (table)
        drogue = {
            -- (int) feet
            altitude_ft = 23000,
            -- (int) m/s
            speed = 232,
        },
        -- (table)
        boom = {
            -- (int)
            altitude_ft = 20000,
            -- (int) m/s
            speed = 220,
        },
        -- (table)
        frequencies = {
            -- (int)
            min_MHz = 296,
            -- (int)
            max_MHz = 302
        },
        -- (table)
        tacan = {
            -- (int)
            min_ch = 50,
            -- (int)
            max_ch = 80
        } -- __X, the Y channel cannot be set via script (DCS Core issue)
    },
    
    -- (table)
    ctld = {
        -- (string)
        unpacked_asset_prefix = "unpacked_",
        -- (string)
        packed_asset_prefix = "packed_",
        -- (int) Global limit for all placed assets
        max_placed_assets = 300,
        -- (table<enum>)
        allowed_load_zones = {ZoneTypes.FARP, ZoneTypes.AIRBASE, ZoneTypes.LOGISTICS},
        -- (int) supplies carried by a supply crate
        supply_crate_supplies = 75,
        -- (string)
        cargo_crate_template = "container_cargo",
        -- (int) (meters)
        search_radius = 100,
        -- (int) (meters)
        random_crate_spacing = 6,
        -- (bool)
        allow_unpacking_in_zones = true,
        -- (bool)
        allow_unloading_in_zones = true,
        -- (bool)
        enable_weighted_loading = false,
        
        -- (table<string>)
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

    -- (int) (meters)
    capture_helicopter_max_range = 100*1000 ,

    -- (int) (meters) the range at which enemy zones will be discovered from
    -- friendly zones
    max_ground_recon_range = 30000,

    -- (int) (seconds) time without movement after which a convoy is considered
    -- stuck and will be removed
    stuck_convoy_timeout = 8*60,
    -- (int) (meters)
    attack_convoy_range = 30000,
    -- (int) (meters) stand-off distance an attack convoy stops at from each target before firing
    attack_convoy_standoff = 50,
    -- (int) max number of targets an attack convoy will move up to and engage in sequence
    attack_convoy_max_targets = 15,
    -- (int) (meters) max distance a strongpoint will send a capture convoy to a neutral zone
    capture_convoy_range = 100000,
    -- (int) The amount of convoys given to every STRONGPOINT when starting the mission
    base_convoy_count = 2,

    --- (string) Skill of AI: "Average", "Good", "High", "Excellent"
    ground_units_skill = "High",

    -- (int)
    jtac_smoke_stock = 8,

    -- (table)
    naval_ground_strike = {
        -- (int) (seconds)
        naval_strike_launch_interval = 10,
        -- (int)
        naval_strike_salvo_size = 10,
    },

    -- (int) - (meters) minimum distance from zone center for spawned units and
    -- statics
    spawn_inner_radius = 100,

    -- (int) (seconds) minimum time between level ups
    logistics_level_up_interval = 16*60,
    -- (int) (seconds) time it takes for an ammo depot to respawn after being
    -- destroyed
    logistics_ammo_depot_respawn_time = 45*60,
    -- (int) supplies required in a LOGISTICS zone stock to be eligible for auto
    -- upgrade
    logistics_auto_upgrade_required_supplies = 300,
    -- (int) (%) evaluated at the 5-minute tick for eligible LOGISTICS zones
    logistics_auto_upgrade_chance = 25,
    -- (int) (seconds)
    comms_tower_respawn_time = 55*60,

    -- (table) Warehouse supply distribution percentages by airbase tier, make sure
    -- they add up to 1.0 exactly, this runs rarely.
    warehouse_supply_distribution = {
        -- (number) % of supplies to tier 1 airbases
        tier_1 = 0.15,
        -- (number) % of supplies to tier 2 airbases
        tier_2 = 0.20,
        -- (number) % of supplies to tier 3 airbases
        tier_3 = 0.25,
        -- (number) % of supplies to tier 4 airbases
        tier_4 = 0.40,
    },

    -- (int) (meters) Zones must be within this distance from logistics zones in
    -- order to allow tier upgrades
    upgrade_tier_range = 50000,

    -- (table)
    EWRS = {
        -- (bool) enables/disables the EWRS system
        enable = true,
        -- (int) (seconds)
        standard_refresh_time = 20,
        -- (int) maximum number of aircraft displayed per message
        max_aircraft_per_text = 6,
    },

    -- (bool) enables/disables the ATIS system
    -- ATIS HAS BEEN DISABLED AS IT CAUSES DCS CRASHES
    ATIS_enabled = false,
    -- (table<enum,int>)
    -- ATIS HAS BEEN DISABLED AS IT CAUSES DCS CRASHES
    ATIS_frequencies = {
        -- (int) (Hertz)
        [Airbases.Caucasus.Vaziani] = 127.5*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Batumi] = 118.250*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Kutaisi] = 118.600*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Senaki_Kolkhi] = 119.100*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Kobuleti] = 119.450*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Sukhumi_Babushara] = 120.250*1e6,
        -- (int) (Hertz)
        [Airbases.Caucasus.Gudauta] = 120.750*1e6,

        -- (int) (Hertz)
        [Airbases.Syria.An_Nasiriyah] = 118.600*1e6,
        -- (int) (Hertz)
        [Airbases.Syria.Shayrat] = 127.5*1e6,
        -- (int) (Hertz)
        [Airbases.Syria.Rayak] = 119.450*1e6,
    },




    -- (table) Carrier and LHA are always enabled by default. They are global
    -- assets, not scenario-specific.
    carrier_setup = {
        -- (string)
        carrier_unit_name = "Carrier",
        -- (string) set to nil if no Tomahawk launcher in the mission
        tomahawk_launcher_unit_name = "Naval Launcher",
        -- (bool)
        enabled = true,
    },

    -- (table)
    lha_setup = {
        -- (string)
        lha_unit_name = "LHA",
        -- (bool)
        enabled = true,
    },

-- (table)
draw_color_palette = {

    -- (table<...>)
    red_palette = {
            {0.8, 0.1, 0.1, 0.9},  -- Border: Bright, distinct red for clear boundary definition
            {0.8, 0.1, 0.1, 0.2},  -- Fill: Subtle red tint, slightly reduced opacity to preserve map detail
            {1.0, 1.0, 1.0, 1.0},  -- Text: Pure white for maximum contrast and legibility
            {0.4, 0.0, 0.0, 0.4}   -- Text background: Deep, moderately opaque red to ground the white text
        },
        -- (table<...>)
        blue_palette = {
            {0.1, 0.3, 0.9, 0.9},  -- Border: Bright, distinct blue
            {0.1, 0.3, 0.9, 0.2},  -- Fill: Subtle blue tint
            {1.0, 1.0, 1.0, 1.0},  -- Text: Pure white
            {0.0, 0.1, 0.4, 0.4}   -- Text background: Deep, moderately opaque blue
        },
        -- (table<...>)
        neutral_palette = {
            {0.5, 0.5, 0.5, 0.9},  -- Border: Solid neutral grey
            {0.5, 0.5, 0.5, 0.2},  -- Fill: Subtle grey tint
            {1.0, 1.0, 1.0, 1.0},  -- Text: Pure white
            {0.2, 0.2, 0.2, 0.6}   -- Text background: Dark grey to frame the text
        },

    -- (table<number>)
    frontline_color = {0.90, 0.90, 0.90, 0.85},
    -- (int)
    frontline_linestyle = 1
}

}

-- (ignore)
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
    blue_comms_antennas = 0,
    blue_discovered_zones = {},
    blue_enroute_resupply = {},
    red_sam_sites = 0,
    red_farp_zones = 0,
    red_logistics_zone = 0,
    red_comms_zones = 0,
    red_airbases = 0,
    red_ew_zones = 0,
    red_strongpoints = 0,
    red_total_comms_zones = 0,

    red_ammo_depots = 0,
    red_comms_antennas = 0,
    red_discovered_zones = {},
    red_enroute_resupply = {},
}


-- This table allows you to link the in-mission groups to the script logic
-- Group names from the mission editor. 

-- V6 change: every COMMON_ASSET below is keyed by ERA so the exact mission-editor
-- group name for each era is spelled out explicitly. Create the ME group whose
-- name matches the era you intend to run. The script picks the entry for the
-- active era (Config.era_system.eras_selected[1]); if that era's entry is left
-- empty it falls back to the MODERN entry, then to any entry that is filled, so
-- you only NEED to author the eras you actually play.
--
-- Naming convention: "<SIDE> <ERA TOKEN> <TASK>", era tokens are
-- WW2 / EARLYCOLDWAR / LATECOLDWAR / MODERN. Example: a BLUE WW2 CAP group must
-- be named exactly "BLUE WW2 CAP". You may rename these to anything you like as
-- long as the ME group name matches the string here.
GroupData = {
    COMMON_ASSETS = {
        BLUE = {
            resupply_aircraft = {
                WW2          = "C130",
                EARLYCOLDWAR = "C130 Early",
                LATECOLDWAR  = "C130 Early",
                MODERN       = "C130",
            },
            capture_helicopter = {
                WW2          = "BLUE Capture Helo",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR Reinforcement Helicopter",
                LATECOLDWAR  = "BLUE Capture Helo",
                MODERN       = "BLUE Capture Helo",
            },
            reinforcement_helicopter = {
                WW2          = "BLUE EARLYCOLDWAR Reinforcement Helicopter",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR Reinforcement Helicopter",
                LATECOLDWAR  = "BLUE LCW Reinforcement Helo",
                MODERN       = "BLUE Reinforcement Helo",
            },
            LHA_capture_helicopter = {
                WW2          = "LHA Capture Helicopter",
                EARLYCOLDWAR = "LHA Capture Helicopter",
                LATECOLDWAR  = "LHA Capture Helicopter",
                MODERN       = "LHA Capture Helicopter",
            },
            attack_convoy = {
                WW2          = "BLUE WW2 Attack Convoy",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR Attack Convoy",
                LATECOLDWAR  = "BLUE LATECOLDWAR Attack Convoy",
                MODERN       = "BLUE MODERN Attack Convoy",
            },
            capture_convoy = {
                WW2          = "BLUE WW2 Convoy",
            },
            -- JTAC is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            jtac = {
                LATECOLDWAR  = "BLUE LATECOLDWAR JTAC",
                MODERN       = "BLUE JTAC",
            },
            farp = {
                WW2          = "BLUE FARP VEHICLES",
                EARLYCOLDWAR = "BLUE FARP VEHICLES",
                LATECOLDWAR  = "BLUE FARP VEHICLES",
                MODERN       = "BLUE FARP VEHICLES",
            },
            tanker_drogue = {
                WW2          = "BLUE DROGUE TANKER",
                EARLYCOLDWAR = "BLUE DROGUE TANKER",
                LATECOLDWAR  = "BLUE DROGUE TANKER",
                MODERN       = "BLUE DROGUE TANKER",
            },
            tanker_boom = {
                WW2          = "BLUE BOOM TANKER",
                EARLYCOLDWAR = "BLUE BOOM TANKER",
                LATECOLDWAR  = "BLUE BOOM TANKER",
                MODERN       = "BLUE BOOM TANKER",
            },

            cas = {
                WW2          = "BLUE WW2 CAS",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR CAS",
                LATECOLDWAR  = "BLUE LATECOLDWAR CAS",
                MODERN       = "BLUE CAS",
            },
            -- SEAD is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            sead = {
                LATECOLDWAR  = "BLUE LATECOLDWAR SEAD",
                MODERN       = "BLUE SEAD",
            },
            strike = {
                WW2          = "BLUE WW2 STRIKE",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR STRIKE",
                LATECOLDWAR  = "BLUE LATECOLDWAR STRIKE",
                MODERN       = "BLUE STRIKE",
            },
            cap = {
                WW2          = "BLUE WW2 CAP",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR CAP",
                LATECOLDWAR  = "BLUE LATECOLDWAR CAP",
                MODERN       = "BLUE CAP",
            },
            -- AWACS is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            awacs = {
                LATECOLDWAR  = "BLUE LATECOLDWAR AWACS",
                MODERN       = "BLUE AWACS",
            },
            recon = {
                WW2          = "BLUE WW2 RECON",
                EARLYCOLDWAR = "BLUE EARLYCOLDWAR RECON",
                LATECOLDWAR  = "BLUE LATECOLDWAR RECON",
                MODERN       = "BLUE RECON",
            },
        },

        RED = {
            resupply_aircraft = {
                WW2          = "IL76",
                EARLYCOLDWAR = "AN26B",
                LATECOLDWAR  = "IL76",
                MODERN       = "IL76",
            },
            capture_helicopter = {
                WW2          = "RED Capture Helo",
                EARLYCOLDWAR = "RED Capture Helo",
                LATECOLDWAR  = "RED Capture Helo",
                MODERN       = "RED Capture Helo",
            },
            reinforcement_helicopter = {
                WW2          = "RED Reinforcement Helo",
                EARLYCOLDWAR = "RED Reinforcement Helo",
                LATECOLDWAR  = "RED Reinforcement Helo",
                MODERN       = "RED Reinforcement Helo",
            },
            attack_convoy = {
                WW2          = "RED WW2 Attack Convoy",
                EARLYCOLDWAR = "RED EARLYCOLDWAR Attack Convoy",
                LATECOLDWAR  = "RED LATECOLDWAR Attack Convoy",
                MODERN       = "RED MODERN Attack Convoy",
            },
            capture_convoy = {
                WW2          = "RED WW2 Convoy",
            },
            -- JTAC is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            jtac = {
                LATECOLDWAR  = "RED JTAC",
                MODERN       = "RED JTAC",
            },
            farp = {
                WW2          = "RED FARP VEHICLES",
                EARLYCOLDWAR = "RED FARP VEHICLES",
                LATECOLDWAR  = "RED FARP VEHICLES",
                MODERN       = "RED FARP VEHICLES",
            },
            tanker_drogue = {
                WW2          = "RED DROGUE TANKER",
                EARLYCOLDWAR = "RED DROGUE TANKER",
                LATECOLDWAR  = "RED DROGUE TANKER",
                MODERN       = "RED DROGUE TANKER",
            },
            tanker_boom = {
                WW2          = "RED BOOM TANKER",
                EARLYCOLDWAR = "RED BOOM TANKER",
                LATECOLDWAR  = "RED BOOM TANKER",
                MODERN       = "RED BOOM TANKER",
            },
            cas = {
                WW2          = "RED WW2 CAS",
                EARLYCOLDWAR = "RED EARLYCOLDWAR CAS",
                LATECOLDWAR  = "RED LATECOLDWAR CAS",
                MODERN       = "RED CAS",
            },
            -- SEAD is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            sead = {
                LATECOLDWAR  = "RED LATECOLDWAR SEAD",
                MODERN       = "RED SEAD",
            },
            strike = {
                WW2          = "RED WW2 STRIKE",
                EARLYCOLDWAR = "RED EARLYCOLDWAR STRIKE",
                LATECOLDWAR  = "RED LATECOLDWAR STRIKE",
                MODERN       = "RED STRIKE",
            },
            cap = {
                WW2          = "RED WW2 CAP",
                EARLYCOLDWAR = "RED EARLYCOLDWAR CAP",
                LATECOLDWAR  = "RED LATECOLDWAR CAP",
                MODERN       = "RED CAP",
            },
            -- AWACS is disabled in WW2/EARLYCOLDWAR (see EraSystem.isTaskTypeAllowed),
            -- so only the LATECOLDWAR+ templates are ever used.
            awacs = {
                LATECOLDWAR  = "RED AWACS",
                MODERN       = "RED AWACS",
            },
            recon = {
                WW2          = "RED WW2 RECON",
                EARLYCOLDWAR = "RED EARLYCOLDWAR RECON",
                LATECOLDWAR  = "RED LATECOLDWAR RECON",
                MODERN       = "RED RECON",
            },
        }
    },
}