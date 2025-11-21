---@class WarehouseManager
WarehouseManager = {}
do

    ---@enum WarehouseManager.Flags
    WarehouseManager.Flags = {
    GBU_12 = "weapons.bombs.GBU_12",
    VIKHR_M = "weapons.missiles.Vikhr_M",
    AIM_9L = "weapons.missiles.AIM-9L",
    AIM_9M = "weapons.missiles.AIM_9",
    AIM_9X = "weapons.missiles.AIM_9X",
    AIM_120C = "weapons.missiles.AIM_120C",
    AIM_120B = "weapons.missiles.AIM_120",
    AIM_54 = "weapons.missiles.AIM_54C_Mk47",
    AGM_65D = "weapons.missiles.AGM_65D",
    AGM_65E = "weapons.missiles.AGM_65E",
    AGM_88_HARM = "weapons.missiles.AGM_88",
    MK_82 = "weapons.bombs.Mk_82",
    GBU_38 = "weapons.bombs.GBU_38", --JDAM 500 lbs
    LAU_88 = "weapons.adapters.lau-88",
    AAQ_28_LITENING = "weapons.containers.AAQ-28_LITENING",
    AN_AAQ_33_SNIPER = "weapons.containers.AN_AAQ_33",
    GBU_31_V_3B = "weapons.bombs.GBU_31_V_3B",
    HTS_POD = "weapons.containers.16c_hts_pod",
    ALQ_184 = "weapons.containers.ALQ-184",
    HYDRA_70_M282_MPP_APKWS = "weapons.missiles.AGR_20_M282",
    SUPER_530D = "weapons.missiles.Matra Super 530D",
    MAGIC_II = "weapons.missiles.MMagicII",
    ECLAIR_M_60 = "weapons.containers.{EclairM_60}",
    ECLAIR_M_51 = "weapons.containers.{EclairM_51}",
    HYDRA_70_MK5_HEAT = "weapons.nurs.HYDRA_70_MK5",
    HYDRA_70_M151_HE = "weapons.nurs.HYDRA_70_M151",
    KAB_500KR = "weapons.bombs.KAB-500Kr",
    R27ER = "weapons.missiles.P_27PE",
    R27ET = "weapons.missiles.P_27TE",
    R73_AA_11_ARCHER = "weapons.missiles.P_73",
    S_8O0FP2_MPP = "weapons.nurs.C_8OFP2",
    L081_FANTASMAGORIA = "weapons.containers.Fantasm",
    R60M = "weapons.missiles.P_60",
    KH_29T = "weapons.missiles.X_29T",
    KH25ML = "weapons.missiles.X_25ML",
    KH58U = "weapons.missiles.X_58",
    L005_SORBSIYA_ECM_POD_LEFT = "weapons.containers.SORBCIJA_L",
    L005_SORBSIYA_ECM_POD_RIGHT = "weapons.containers.SORBCIJA_R",
    }

    ---@enum WarehouseManager.FuelTanks
    WarehouseManager.FuelTanks = {
        FPU_8A_330_GAL = "weapons.droptanks.FPU_8A",         -- FPU-8A fuel tank 330 gal for f18
        RPL_552_1300L = "weapons.droptanks.M2KC_RPL_522",         -- RPL 522 1300L for M2000C
        F15E_610_GAL = "weapons.droptanks.F-15E_Drop_Tank",
        F14_DROPTANK = "weapons.droptanks.HB_F14_EXT_DROPTANK"
        -- fuel tank 300 gal for F-16C
        -- fuel tank 370 gal for F-16C

        -- fuel tank 610 gal for f15e
        -- Fuel tank FT600 for A10CII

        -- Fuel tank 800L Wing for SU25T
    }
    ---@enum WarehouseManager.AircraftFlags
    WarehouseManager.AircraftFlags = {
        SU25T = "Su-25T",
        E3A = "E-3A",
        MQ9_REAPER = "MQ-9 Reaper",
        F15E_SE = "F-15ESE",
        E2C_HAWKEYE = "E-2C",
        RQ_1A_PREDATOR = "RQ-1A Predator",
        KC130 = "KC130",
        F16C_BL50 = "F-16C_50",
        M2000C = "M-2000C",
        FA18C_HORNET = "FA-18C_hornet",
        F_14A_135_GR = "F-14A-135-GR",
        A10C_TANK_KILLER_II = "A-10C_2",
        F15C = "F-15C",
        C17A = "C-17A",
        MiG23MLD = "MiG-23MLD",
        SU30 = "Su-30",
        SU27 = "Su-27",
        SU24M = "Su-24M",
        SU34 = "Su-34",
        SU33 = "Su-33",
        MI8MT = "Mi-8MT",
        TU_160 = "Tu-160",
        TU_142 = "Tu-142",
        MIG19P = "MiG-19P",
        MIG25PD = "MiG-25PD",
        MIG25RBT = "MiG-25RBT",
        MIG29A = "MiG-29A",
        MIG29G = "MiG-29G",
        MIG31 = "MiG-31",
        MIG21BIS = "MiG-21Bis",
        MIG29S = "MiG-29S",
        MIG29_FULCRUM = "MiG-29 Fulcrum",
        TU_95MS = "Tu-95MS",
        TU_22M3 = "Tu-22M3",
        A50 = "A-50",


    }
   

    WarehouseManager.AirbaseGroupData = {
            [Airbases.Caucasus.Vaziani] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.JTAC] = {
                        group_name = "BLUE VAZIANI JTAC",
                        warehouse_name = WarehouseManager.AircraftFlags.RQ_1A_PREDATOR
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE VAZIANI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE VAZIANI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE VAZIANI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "BLUE VAZIANI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE VAZIANI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE VAZIANI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                },
                -- [coalition.side.RED] = {
                --     [AITaskTypes.JTAC] = {
                --         group_name = "RED JTAC",--TO CHANGE
                --         warehouse_name = "RQ-1A Predator"
                --     }
                -- },
            },
            [Airbases.Caucasus.Kutaisi] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED KUTAISI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED KUTAISI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED KUTAISI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "RED KUTAISI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED KUTAISI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },

                    
                }
            },
            [Airbases.Caucasus.Anapa_Vityazevo] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED ANAPA CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED ANAPA SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED ANAPA STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "RED ANAPA INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED ANAPA AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                }
            }
    }

    WarehouseManager.AIPayloads = {
        [coalition.side.BLUE] = {
            [AITaskTypes.CAS] = {
                [WarehouseManager.Flags.LAU_88] = 2 *2, -- accounts for both aircrafts
                [WarehouseManager.Flags.AGM_65D] = 4 *2,
                [WarehouseManager.Flags.AAQ_28_LITENING] = 1 *2,
                [WarehouseManager.Flags.AIM_9M] = 1 *2,
                [WarehouseManager.Flags.HYDRA_70_M282_MPP_APKWS] = 7 *2
                --WARN Missing items
            },
            [AITaskTypes.INTERCEPT] = {
                [WarehouseManager.Flags.AIM_120C] = 4 *2,
                [WarehouseManager.Flags.AIM_9M] = 2 *2
            },
            [AITaskTypes.STRIKE] = {
                [WarehouseManager.Flags.AIM_120B] = 2 *2,
                [WarehouseManager.Flags.AIM_9X] = 2 *2,
                [WarehouseManager.Flags.GBU_31_V_3B] = 2 *2,
                [WarehouseManager.Flags.AAQ_28_LITENING] = 1 *2,
            },
            [AITaskTypes.SEAD] = {
                [WarehouseManager.Flags.AIM_120B] = 2 *2,
                [WarehouseManager.Flags.AIM_9X] = 2 *2,
                [WarehouseManager.Flags.AGM_88_HARM] = 2 *2,
                [WarehouseManager.Flags.HTS_POD] = 1 *2,
                [WarehouseManager.Flags.ALQ_184] = 1 *2,
            },
            [AITaskTypes.RECON] = {
                [WarehouseManager.Flags.AAQ_28_LITENING] = 1 *2,
                [WarehouseManager.Flags.AIM_120C] = 2 *2,
                [WarehouseManager.Flags.AIM_9X] = 2 *2,
            },
            [AITaskTypes.AWACS] = {},
            [AITaskTypes.JTAC] = {},
        },
        [coalition.side.RED] = {
            [AITaskTypes.CAS] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = 2 *2,
                [WarehouseManager.Flags.S_8O0FP2_MPP] = 2*20 *2,
                [WarehouseManager.Flags.VIKHR_M] = 2*8 *2,
                [WarehouseManager.Flags.KH_29T] = 2 *2,
                -- 2 * R-73 AA 11 Archer
                -- 2 * B-8M1 20*UnGd Rkts 80mm S-80FP2 MPP
                -- 2 * APU-8 8* 9M127 Vikhr ATGM
                -- 2 * Kh-29T AS-14 Kedge

            },
            [AITaskTypes.SEAD] = {
                [WarehouseManager.Flags.KH25ML] = 2 *2,
                [WarehouseManager.Flags.KH58U] = 2 *2,
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = 1 *2,
                -- 2 * Kh-25ML AS 10 Karen 300 kg ASM Semi Act Laser
                -- 2 * Kh-58U AS-11 Kilter ARM 
                -- 1 * L-081 Fantasmagoria ELINT pod
            },
            [AITaskTypes.INTERCEPT] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = 2 *2,
                [WarehouseManager.Flags.R27ER] = 2 *2,
                [WarehouseManager.Flags.R27ET] = 2 *2,
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_LEFT] = 1 *2,
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_RIGHT] = 1 *2,
                -- 2 * R-73 AA 11 Archer
                -- 2 * R-27 ER
                -- 2 * R-27 ET
                -- 2 * L005 Sorbtsiya ECM pod
            },
            [AITaskTypes.STRIKE] = {
                [WarehouseManager.Flags.KAB_500KR] = 2 *2,
                [WarehouseManager.Flags.KH_29T] = 2 *2,
                [WarehouseManager.Flags.R60M] = 1 *2,
                -- 2 * KAB-500Kr AS-5K 'KAB-500Kr' TV Guided Bomb
                -- 2 * Kh-29T AS-14 Kedge
                -- 1 * APU-60-1M with 1 * R-60M
            },

            
            [AITaskTypes.AWACS] = {}
        }
    }



    ---@enum WarehouseManager.StockTypes
    WarehouseManager.StockTypes = {
        INITIAL = 1,
        LOGISTICS_CAPTURE = 100,

        AIR_AIR_LONG_RANGE = 2,
        AIR_AIR_SHORT_RANGE = 3,
        AIR_GROUND_GUIDED_MISSILES = 4,
        AIR_GROUND_GUIDED_BOMBS = 5,
        AIR_GROUND_BOMBS = 6,
        AIR_GROUND_ROCKETS = 7,
        ECM = 8,
        TGP = 9,
        MISC = 10,
        
        AG_AIRCRAFT = 21,
        MULTIROLE_AIRCRAFT = 22,
        AA_AIRCRAFT = 22,
        RECON_AIRCRAFT = 23,
        CARGO_AIRCRAFT = 24
    }

    WarehouseManager.Stocks = {
        [WarehouseManager.StockTypes.INITIAL] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AGM_65D] = math.random(14,18),
                [WarehouseManager.Flags.AGM_65E] = math.random(8,10),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(4,10),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(1,4),
                [WarehouseManager.Flags.GBU_38] = math.random(15,20),
                [WarehouseManager.Flags.GBU_12] = math.random(20,35),
                [WarehouseManager.Flags.MK_82] = math.random(30,50),
                [WarehouseManager.Flags.LAU_88] = math.random(14,20),
                
                [WarehouseManager.Flags.HYDRA_70_M282_MPP_APKWS] = math.random(38,58),
                [WarehouseManager.Flags.HYDRA_70_M151_HE] = math.random(60,100),
                [WarehouseManager.Flags.HYDRA_70_MK5_HEAT] = math.random(60,100),

                [WarehouseManager.Flags.AAQ_28_LITENING] = math.random(7,10),
                [WarehouseManager.Flags.AN_AAQ_33_SNIPER] = math.random(7,10),
                [WarehouseManager.Flags.HTS_POD] = math.random(4,6),
                [WarehouseManager.Flags.ALQ_184] = math.random(3,5),

                [WarehouseManager.Flags.AIM_120B] = math.random(16,22),
                [WarehouseManager.Flags.AIM_120C] = math.random(12,20),
                [WarehouseManager.Flags.AIM_9M] = math.random(20,28),
                [WarehouseManager.Flags.AIM_9X] = math.random(8,14),
                [WarehouseManager.Flags.SUPER_530D] = math.random(8,14),
                [WarehouseManager.Flags.MAGIC_II] = math.random(8,14),

                [WarehouseManager.FuelTanks.FPU_8A_330_GAL] = 200,
                [WarehouseManager.FuelTanks.F14_DROPTANK] = 200,
                [WarehouseManager.FuelTanks.F15E_610_GAL] = 200,
                [WarehouseManager.FuelTanks.RPL_552_1300L] = 200,

                [WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II] = 14,
                [WarehouseManager.AircraftFlags.E3A] = 2,
                [WarehouseManager.AircraftFlags.F15E_SE] = 8,
                [WarehouseManager.AircraftFlags.F16C_BL50] = 18,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 16,
                [WarehouseManager.AircraftFlags.M2000C] = 4,
                [WarehouseManager.AircraftFlags.F15C] = 12,
                [WarehouseManager.AircraftFlags.RQ_1A_PREDATOR] = 3,

            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(80,90),
                [WarehouseManager.Flags.S_8O0FP2_MPP] = math.random(400,600),
                [WarehouseManager.Flags.VIKHR_M] = math.random(200,300),
                [WarehouseManager.Flags.KH_29T] = math.random(20,35),
                [WarehouseManager.Flags.KH25ML] = math.random(20,30),
                [WarehouseManager.Flags.KH58U] = math.random(28,32),
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(4,6),
                [WarehouseManager.Flags.R27ER] = math.random(42,68),
                [WarehouseManager.Flags.R27ET] = math.random(28,32),
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_LEFT] = math.random(3,5),
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_RIGHT] = math.random(3,5),

                [WarehouseManager.AircraftFlags.SU25T] = 18,
                [WarehouseManager.AircraftFlags.SU27] = 8,
                [WarehouseManager.AircraftFlags.SU24M] = 16,

            }
                
        },
        [WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AIM_120B] = math.random(8,14),
                [WarehouseManager.Flags.AIM_120C] = math.random(6,10),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.R27ER] = math.random(20,30),
                [WarehouseManager.Flags.R27ET] = math.random(12,20),
            }
        },
        [WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AIM_9M] = math.random(8,14),
                [WarehouseManager.Flags.AIM_9X] = math.random(6,10),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(40,60),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_BOMBS] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.MK_82] = math.random(12,18),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KAB_500KR] = math.random(10,15),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.GBU_38] = math.random(8,14),
                [WarehouseManager.Flags.GBU_12] = math.random(6,10),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(6,10),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KH_29T] = math.random(10,15),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AGM_65D] = math.random(12,16),
                [WarehouseManager.Flags.AGM_65E] = math.random(6,10),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(6,10),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KH25ML] = math.random(10,15),
                [WarehouseManager.Flags.KH58U] = math.random(14,18),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_ROCKETS] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.HYDRA_70_M282_MPP_APKWS] = math.random(38,58),
                [WarehouseManager.Flags.HYDRA_70_M151_HE] = math.random(60,100),
                [WarehouseManager.Flags.HYDRA_70_MK5_HEAT] = math.random(60,100),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.S_8O0FP2_MPP] = math.random(200,300),
                [WarehouseManager.Flags.VIKHR_M] = math.random(100,150),
            }
        },
        [WarehouseManager.StockTypes.ECM] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.ALQ_184] = math.random(2,6),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_LEFT] = math.random(3,5),
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_RIGHT] = math.random(3,5),
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(2,4),
            }
        },
        [WarehouseManager.StockTypes.TGP] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AAQ_28_LITENING] = math.random(5,8),
                [WarehouseManager.Flags.AN_AAQ_33_SNIPER] = math.random(5,8),
            },

        },
        [WarehouseManager.StockTypes.MISC] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.HTS_POD] = math.random(4,6),
            }
        },
        
        [WarehouseManager.StockTypes.MULTIROLE_AIRCRAFT] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.F16C_BL50] = 6,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 4,
                [WarehouseManager.AircraftFlags.M2000C] = 2,
                [WarehouseManager.AircraftFlags.F15E_SE] = 2,
            },
            [coalition.side.RED] = {
                [WarehouseManager.AircraftFlags.MIG29S] = 6,
                [WarehouseManager.AircraftFlags.SU27] = 4,
                [WarehouseManager.AircraftFlags.SU30] = 2,
                [WarehouseManager.AircraftFlags.SU25T] = 2,
            }
        },
        [WarehouseManager.StockTypes.AA_AIRCRAFT] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.F16C_BL50] = 6,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 4,
                [WarehouseManager.AircraftFlags.M2000C] = 2,
                [WarehouseManager.AircraftFlags.F15C] = 2,
            },
            [coalition.side.RED] = {
                [WarehouseManager.AircraftFlags.MIG29S] = 6,
                [WarehouseManager.AircraftFlags.SU27] = 4,
                [WarehouseManager.AircraftFlags.MIG29A] = 2,
                [WarehouseManager.AircraftFlags.MIG31] = 2,
            }
        },        
        [WarehouseManager.StockTypes.AG_AIRCRAFT] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.F16C_BL50] = 2,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 2,
                [WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II] = 4,
                [WarehouseManager.AircraftFlags.F15E_SE] = 4,
                [WarehouseManager.AircraftFlags.SU25T] = 4,
            },
            [coalition.side.RED] = {
                [WarehouseManager.AircraftFlags.SU25T] = 4,
                [WarehouseManager.AircraftFlags.SU24M] = 4,
                [WarehouseManager.AircraftFlags.MIG29S] = 2,
                [WarehouseManager.AircraftFlags.SU27] = 2,
            }
        },
        
        [WarehouseManager.StockTypes.LOGISTICS_CAPTURE] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AGM_65D] = math.random(6,10),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(2,6),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(1,2),
                [WarehouseManager.Flags.GBU_38] = math.random(15,20),
                [WarehouseManager.Flags.GBU_12] = math.random(16,22),
                [WarehouseManager.Flags.LAU_88] = math.random(4,10),
                
                [WarehouseManager.Flags.HYDRA_70_M282_MPP_APKWS] = math.random(20,40),
                [WarehouseManager.Flags.HYDRA_70_M151_HE] = math.random(20,40),
                [WarehouseManager.Flags.HYDRA_70_MK5_HEAT] = math.random(20,40),

                [WarehouseManager.Flags.AAQ_28_LITENING] = math.random(1,3),
                [WarehouseManager.Flags.AN_AAQ_33_SNIPER] = 1,
                [WarehouseManager.Flags.HTS_POD] = math.random(1,3),
                [WarehouseManager.Flags.ALQ_184] = math.random(1,3),

                [WarehouseManager.Flags.AIM_120B] = math.random(6,12),
                [WarehouseManager.Flags.AIM_120C] = math.random(4,10),
                [WarehouseManager.Flags.AIM_9M] = math.random(6,8),
                [WarehouseManager.Flags.AIM_9X] = math.random(8,14),
                [WarehouseManager.Flags.SUPER_530D] = math.random(2,4),
                [WarehouseManager.Flags.MAGIC_II] = math.random(2,4),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(40,60),
                [WarehouseManager.Flags.S_8O0FP2_MPP] = math.random(100,200),
                [WarehouseManager.Flags.VIKHR_M] = math.random(100,150),
                [WarehouseManager.Flags.KH_29T] = math.random(10,15),
                [WarehouseManager.Flags.KH25ML] = math.random(10,15),
                [WarehouseManager.Flags.KH58U] = math.random(14,18),
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(2,4),
                [WarehouseManager.Flags.R27ER] = math.random(20,30),
                [WarehouseManager.Flags.R27ET] = math.random(12,20),
            }
        },
     
    }

    WarehouseManager.ResupplyCycle = {
        -- Step 1: Air-to-Air
        {
            types = {
                WarehouseManager.StockTypes.AIR_AIR_SHORT_RANGE,
                WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE,
            },
            text = "Air-to-Air Munitions"
        },
        -- Step 2: Air-to-Ground
        {
            types = {
                WarehouseManager.StockTypes.AIR_GROUND_BOMBS,
                WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS,
                WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES,
                WarehouseManager.StockTypes.AIR_GROUND_ROCKETS,
            },
            text = "Air-to-Ground Munitions"
        },
        -- Step 3: Support
        {
            types = {
                WarehouseManager.StockTypes.ECM,
                WarehouseManager.StockTypes.TGP,
                WarehouseManager.StockTypes.MISC,
            },
            text = "Support Equipment"
        }
    }



    --- Warning: ensure the side is correctly set before execution
    ---@param airbase_name string
    ---@param coalition coalition.side
    ---@param stock_types WarehouseManager.StockTypes[]
    function WarehouseManager:attributeAirbaseStock(airbase_name,coalition,stock_types)

        local airbase = Airbase.getByName(airbase_name)
        if not airbase then MissionLogger:warn("No airbase") return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then MissionLogger:warn("No warehouse") return false end

        -- if utils.tableContains(stock_types,WarehouseManager.StockTypes.INITIAL) then
        --     MissionLogger:info(warehouse:getInventory())
        -- end

        local added_stuff_tbl = {}
        for i,stock_type in ipairs(stock_types) do
            for stock_type_n,stock_c in pairs(WarehouseManager.Stocks) do
                if stock_type_n == stock_type then
                    local stock = stock_c[coalition]
                    for id,amount in pairs(stock) do
                        warehouse:addItem(id,amount)
                        table.insert(added_stuff_tbl, {id,amount})
                    end
                    break
                end
    
            end
        end
        return added_stuff_tbl

    end

    ---@param side coalition.side
    ---@param stock_types WarehouseManager.StockTypes[]
    function WarehouseManager:handleIncomingSupplies(side,stock_types)

        --[[
            tier = level
            75% of supplies go to airbases level 4, divided equally
            25% of supplies go to airbases level 3, divided equally
            0% for airbases level 1 and 2
            
            If no bases of one level exist, the other level gets its share.
        ]]

        local level_4_bases = {}
        local level_3_bases = {}

        -- 1. Find all eligible airbases and their warehouses
        for _, zone in ipairs(zones) do
            if zone.side == side and zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                local airbase = Airbase.getByName(zone.airbase_name)
                if airbase then
                    local warehouse = airbase:getWarehouse()
                    if warehouse then
                        if zone.level == 4 then
                            table.insert(level_4_bases, warehouse)
                        elseif zone.level == 3 then
                            table.insert(level_3_bases, warehouse)
                        end
                    end
                end
            end
        end

        local count_l4 = #level_4_bases
        local count_l3 = #level_3_bases
        
        local mult_l4 = 0
        local mult_l3 = 0
        
        local share_l4 = 0.75
        local share_l3 = 0.25

        -- 2. Calculate supply multipliers based on distribution logic
        if count_l4 == 0 and count_l3 > 0 then
            -- No L4 bases, L3 bases get 100% of the supplies, divided equally
            mult_l3 = 1.0 / count_l3
            MissionLogger:info("HandleIncomingSupplies: No tier 4 bases found. Distributing 100% to " .. count_l3 .. " tier 3 bases.")
        elseif count_l3 == 0 and count_l4 > 0 then
            -- No L3 bases, L4 bases get 100% of the supplies, divided equally
            mult_l4 = 1.0 / count_l4
            MissionLogger:info("HandleIncomingSupplies: No tier 3 bases found. Distributing 100% to " .. count_l4 .. " tier 4 bases.")
        elseif count_l4 > 0 and count_l3 > 0 then
            -- Standard split: 75% to L4, 25% to L3
            mult_l4 = share_l4 / count_l4
            mult_l3 = share_l3 / count_l3
            MissionLogger:info("HandleIncomingSupplies: Splitting 75% to " .. count_l4 .. " tier 4 bases, 25% to " .. count_l3 .. " tier 3 bases.")
        else
            -- No L3 or L4 bases found for this side.
            MissionLogger:info("WarehouseManager:handleIncomingSupplies: No tier 3 or tier 4 airbases found for " .. (utils.coalitionToString(side) or "Unknown Side"))
            return
        end

        -- 3. Get the full list of items to add (pre-multiplication)
        local items_to_add = {}
        for _, stock_type in ipairs(stock_types) do
            -- Find the correct stock definition
            if WarehouseManager.Stocks[stock_type] and WarehouseManager.Stocks[stock_type][side] then
                local stock = WarehouseManager.Stocks[stock_type][side]
                for id, amount in pairs(stock) do
                    -- Use a table to merge items if they appear in multiple stock_types
                    items_to_add[id] = (items_to_add[id] or 0) + amount
                end
            end
        end

        -- 4. Distribute items to warehouses with calculated amounts

        -- Add to tier 4 bases
        if mult_l4 > 0 then
            for _, warehouse in ipairs(level_4_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l4)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
            end
        end
        
        -- Add to tier 3 bases
        if mult_l3 > 0 then
            for _, warehouse in ipairs(level_3_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l3)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
            end
        end
        trigger.action.outTextForCoalition(side, "Arriving supplies distributed to airbases.", 10)

        MissionLogger:info("HandleIncomingSupplies: Supply distribution complete for " .. (utils.coalitionToString(side) or "Unknown Side"))
    end

    ---@param airbase Airbase
    ---@param ai_task_type AITaskTypes
    ---@return boolean, string|nil
    function WarehouseManager:checkIfAIPayloadInStock(airbase, ai_task_type)
        if not airbase or not airbase.getCoalition then return false end
        local airbase_coalition = airbase:getCoalition()
        if not WarehouseManager.AIPayloads[airbase_coalition][ai_task_type] then return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then return false end

        for wpn_id,amount in pairs(WarehouseManager.AIPayloads[airbase_coalition][ai_task_type]) do
            if warehouse:getItemCount(wpn_id) < amount then
                -- MissionLogger:info("Checking warehouse for "..ai_task_type.." payloads, payload INSUFFICIENT")
                return false
            end
        end
        -- MissionLogger:info("Checking warehouse for "..ai_task_type.." payloads, payload OK")
        return true

    end

    function WarehouseManager:checkAircraftInStock(airbase_name,ai_task_type)

        local airbase = Airbase.getByName(airbase_name)
        if not airbase then return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then return false end

        if not airbase:getCoalition() then return false end
        local side = airbase:getCoalition()

        if WarehouseManager.AirbaseGroupData[airbase_name]
        and WarehouseManager.AirbaseGroupData[airbase_name][side]
        and WarehouseManager.AirbaseGroupData[airbase_name][side][ai_task_type]
        then
            -- group_name = "BLUE JTAC VAZIANI",
            --warehouse_name =
            local acft_name = WarehouseManager.AirbaseGroupData[airbase_name][side][ai_task_type].warehouse_name
            local template_gr_name = WarehouseManager.AirbaseGroupData[airbase_name][side][ai_task_type].group_name
            if warehouse:getItemCount(acft_name) > 0 then
                return true, template_gr_name
            else
                return false
            end
        end
    end


end