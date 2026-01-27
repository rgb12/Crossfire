---@class WarehouseManager
WarehouseManager = {}
do
    
    ---@enum WarehouseManager.Flags
    WarehouseManager.Flags = {
        
    AIM_9L = "weapons.missiles.AIM-9L",
    AIM_9M = "weapons.missiles.AIM_9",
    AIM_9X = "weapons.missiles.AIM_9X",
    AIM_120C = "weapons.missiles.AIM_120C",
    AIM_120B = "weapons.missiles.AIM_120",
    AIM_7P = "weapons.missiles.AIM-7P",
    AIM_7F = "weapons.missiles.AIM-7F",
    AIM_7M = "weapons.missiles.AIM_7",
    AIM_7MH = "weapons.missiles.AIM-7MH",
    AIM_54C_MK60 = "weapons.missiles.AIM_54C_Mk60",
    AIM_54C_MK47 = "weapons.missiles.AIM_54C_Mk47",
    MISTRAL = "weapons.missiles.Mistral",

    AGM_65D = "weapons.missiles.AGM_65D",
    AGM_65E = "weapons.missiles.AGM_65E",
    AGM_65F = "weapons.missiles.AGM_65F",
    AGM_88_HARM = "weapons.missiles.AGM_88",
    AGM_154C_JSOW = "weapons.missiles.AGM_154",
    AGM_154A_JSOW = "weapons.missiles.AGM_154A",
    AGM_84H_SLAM_ER = "weapons.missiles.AGM_84H",
    AGM_84D_HARPOON = "weapons.missiles.AGM_84D",
    ADM_141_TALD = "weapons.missiles.ADM_141A",
    AGM_114L = "weapons.missiles.AGM_114",
    AGM_114K = "weapons.missiles.AGM_114K",

    CBU_87 = "weapons.bombs.CBU_87",
    CBU_97 = "weapons.bombs.CBU_97",
    CBU_99 = "weapons.bombs.CBU_99",
    CBU_105 = "weapons.bombs.CBU_105",
    CBU_103 = "weapons.bombs.CBU_103",
    
    GBU_12 = "weapons.bombs.GBU_12",
    GBU_16 = "weapons.bombs.GBU_16",
    GBU_24 = "weapons.bombs.GBU_24",
    GBU_10 = "weapons.bombs.GBU_10",
    GBU_38 = "weapons.bombs.GBU_38", --JDAM 500 lbs
    GBU_32_V_2B = "weapons.bombs.GBU_32_V_2B",
    GBU_31_V_3B = "weapons.bombs.GBU_31_V_3B",
    GBU_54_V_1B = "weapons.bombs.GBU_54_V_1B",
    GBU_43 = "weapons.bombs.GBU_43",
    
    MK_82 = "weapons.bombs.Mk_82",
    MK_83 = "weapons.bombs.Mk_83",
    MK_84 = "weapons.bombs.Mk_84",
    MK82_SNAKEEYE = "weapons.bombs.MK_82SNAKEYE",
    MK_20_ROCKEYE = "weapons.bombs.ROCKEYE",
    
    LAU_88 = "weapons.adapters.lau-88",
    AAQ_28_LITENING = "weapons.containers.AAQ-28_LITENING",
    AN_AAQ_33_SNIPER = "weapons.containers.AN_AAQ_33",
    AAQ_14_LANTIRN = "weapons.containers.F-15E_AAQ-14_LANTIRN",
    AAQ_13_LANTIRN = "weapons.containers.F-15E_AAQ-13_LANTIRN",
    F14_LANTIRN = "weapons.containers.{F14-LANTIRN-TP}",
    AN_APG_78_APACHE_RADAR = "weapons.containers.ah-64d_radar",
    AN_ASQ_228_ATFLIR = "weapons.containers.AN_ASQ_228",

    HTS_POD = "weapons.containers.16c_hts_pod",
    ALQ_184 = "weapons.containers.ALQ-184",
    
    HYDRA_70_M282_MPP_APKWS = "weapons.missiles.AGR_20_M282",
    HYDRA_70_MK5_HEAT = "weapons.nurs.HYDRA_70_MK5",
    HYDRA_70_M151_HE = "weapons.nurs.HYDRA_70_M151",
    HYDRA_70_M257 = "weapons.nurs.HYDRA_70_M257",
    HYDRA_70_M274 = "weapons.nurs.HYDRA_70_M274",
    HYDRA_70_MK1 = "weapons.nurs.HYDRA_70_MK1",
    ZUNI_127 = "weapons.nurs.Zuni_127",
    SNEB_254_SM_RED = "weapons.nurs.SNEB_TYPE254_H1_RED", -- smoke red
    SNEB_254_SM_GREEN = "weapons.nurs.SNEB_TYPE254_H1_GREEN", -- smoke green
    SNEB_251_HE = "weapons.nurs.SNEB_TYPE251_H1",
    SNEB_253_HEAT = "weapons.nurs.SNEB_TYPE253_H1",
    SNEB_259_IL = "weapons.nurs.SNEB_TYPE259E_H1", -- Illuminating


    SUPER_530D = "weapons.missiles.Matra Super 530D",
    MAGIC_II = "weapons.missiles.MMagicII",
    ECLAIR_M_60 = "weapons.containers.{EclairM_60}",
    ECLAIR_M_51 = "weapons.containers.{EclairM_51}",
    HOT3 = "weapons.missiles.HOT3_MBDA",
    
    GIAT_M621_SAPHEI = 'weapons.gunmounts.{GIAT_M621_SAPHEI}',
    GIAT_M621_APHE = 'weapons.gunmounts.{GIAT_M621_APHE}',
    GIAT_M621_HEAP = 'weapons.gunmounts.{GIAT_M621_HEAP}',
    GIAT_M621_HE = 'weapons.gunmounts.{GIAT_M621_HE}',
    GIAT_M621_AP = 'weapons.gunmounts.{GIAT_M621_AP}',
    GIAT_M261 = 'weapons.gunmounts.GIAT_M261',
    FN_HMP400_200 = 'weapons.gunmounts.{FN_HMP400_200}',
    FN_HMP400 = 'weapons.gunmounts.{FN_HMP400}',
    HMP400 = 'weapons.gunmounts.HMP400',

    IR_DEFLECTOR = "weapons.containers.IRDeflector",
    SAND_FILTER = "weapons.containers.FAS",

    VIKHR_M = "weapons.missiles.Vikhr_M",
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

    BETAB_500 = "weapons.bombs.BetAB_500",
    BETAB_500SHP = "weapons.bombs.BetAB_500ShP",
    S13_OF_122MM = "weapons.nurs.C_13",
    S24B_240MM_UnGd_Rkt = "weapons.nurs.C_24",
    S25_OFM_340MM = "weapons.nurs.C_25",
    S25_O_420MM_FRAG = "weapons.nurs.S-25-O",
    S5_OFM_340MM = "weapons.nurs.C_5",
    S8_KOM_80MM_HEAT = "weapons.nurs.C_8",
    S8_TsM_SM_ORANGE = "weapons.nurs.C_8CM",
    S8_TsM_SM_BLUE = "weapons.nurs.C_8CM_BU",
    S8_TsM_SM_GREEN = "weapons.nurs.C_8CM_GN",
    S8_TsM_SM_RED = "weapons.nurs.C_8CM_RD",
    S8_TsM_SM_VIOLET = "weapons.nurs.C_8CM_VT",
    S8_TsM_SM_WHITE = "weapons.nurs.C_8CM_WH",
    S8_TsM_SM_YELLOW = "weapons.nurs.C_8CM_YE",
    S8_OM_FP2_MPP = "weapons.nurs.C_8OM",
    S5_KP_57MM_HEAT_FRAG = "weapons.nurs.S_5KP",
    S5_M_HE = "weapons.nurs.S_5M",
    S24A = "weapons.nurs.S-24A",
    S24B = "weapons.nurs.S-24B",
    FAB_100 = "weapons.bombs.FAB_100",
    FAB_100M = "weapons.bombs.FAB_100M",
    FAB_100SV = "weapons.bombs.FAB_100SV",
    FAB_250 = "weapons.bombs.FAB_250",
    FAB_250_M62 = "weapons.bombs.FAB-250-M62",
    FAB_500 = "weapons.bombs.FAB_500",
    KH25MP_PRGS1VP = "weapons.missiles.Kh25MP_PRGS1VP",
    MERCURY_LLTV_POD = "weapons.containers.KINGAL",
    MPS_410 = "weapons.containers.MPS-410",
    RBK_250 = "weapons.bombs.RBK_250",
    RBK_250_275_AO_1SCH = "weapons.bombs.RBK_250_275_AO_1SCH",
    RBK_500AO = "weapons.bombs.RBK_500AO",
    RBK_500U = "weapons.bombs.RBK_500U",
    S25L = "weapons.missiles.S_25L",
    SAB_100MN = "weapons.bombs.SAB_100MN",
    SAB_250_200 = "weapons.bombs.SAB_250_200",
    X_25MP = "weapons.missiles.X_25MP",
    X_29L = "weapons.missiles.X_29L",
    KAB_500KR_NEW = "weapons.bombs.KAB_500Kr", -- (Note: 'KAB-500Kr' vs 'KAB_500Kr')
    R_60 = "weapons.missiles.R-60",
    RBK_500U_OAB_2_5RT = "weapons.bombs.RBK_500U_OAB_2_5RT",
    }

    ---@enum WarehouseManager.FuelTanks
    WarehouseManager.FuelTanks = {
        FPU_8A_330_GAL = "weapons.droptanks.FPU_8A",         -- FPU-8A fuel tank 330 gal for f18
        RPL_552_1300L = "weapons.droptanks.M2KC_RPL_522",         -- RPL 522 1300L for M2000C
        F15E_610_GAL = "weapons.droptanks.F-15E_Drop_Tank",
        F14_DROPTANK = "weapons.droptanks.HB_F14_EXT_DROPTANK"
        -- Fuel tanks are not currently being used in the warehouse system due to their nature and complicated way of adding them here
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
        F14B = "F-14B",
        A10C_TANK_KILLER_II = "A-10C_2",
        F15C = "F-15C",
        C17A = "C-17A",
        MiG23MLD = "MiG-23MLD",
        SU30 = "Su-30",
        SU27 = "Su-27",
        SU24M = "Su-24M",
        SU24MR = "Su-24MR",
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
        AH64D_BLKII = "AH-64D_BLK_II",
        AH1W="AH-1W",
        B1B_LANCER = "B-1B",
        C130J_30= "C-130J-30",
        IL78M = "IL-78M",
        IL76MD = "IL-76MD",
        KC135_MPRS = "KC135MPRS",
        MIRAGE_2000_5 = "Mirage 2000-5",
        S3_B_TANKER = "S-3B Tanker",
        SA342Minigun = "SA342Minigun",
        SA342L = "SA342L",
        SA342Mistral = "SA342Mistral",
        SA342M = "SA342M",
        UH_1H = "UH-1H",
        OH_58D = "OH-58D",
    }

    -- Helpers to validate warehouse item support
    function WarehouseManager:isSupportedWeapon(item_name)
        if not item_name then return false end
        return utils.tableContains(WarehouseManager.Flags, item_name)
            or utils.tableContains(WarehouseManager.FuelTanks, item_name)
    end

    function WarehouseManager:isSupportedAircraft(item_name)
        if not item_name then return false end
        return utils.tableContains(WarehouseManager.AircraftFlags, item_name)
    end
   

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
                    [AITaskTypes.CAP] = {
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
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED VAZIANI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED VAZIANI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED VAZIANI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED VAZIANI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED VAZIANI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED VAZIANI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    }
                }
            },
            [Airbases.Caucasus.Anapa_Vityazevo] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE ANAPA CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE ANAPA SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE ANAPA STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE ANAPA INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE ANAPA AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE ANAPA RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                },
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
                    [AITaskTypes.CAP] = {
                        group_name = "RED ANAPA INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED ANAPA AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED ANAPA RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                }
            },
            [Airbases.Caucasus.Krymsk] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE KRYMSK CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE KRYMSK SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE KRYMSK STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE KRYMSK INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE KRYMSK RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                },
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED KRYMSK CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED KRYMSK SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED KRYMSK STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED KRYMSK INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED KRYMSK RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                }
            },
            [Airbases.Caucasus.Krasnodar_Pashkovsky] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED KRASNODAR CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED KRASNODAR SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED KRASNODAR STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED KRASNODAR INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED KRASNODAR RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }

                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE KRASNODAR CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE KRASNODAR SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE KRASNODAR STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE KRASNODAR INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE KRASNODAR RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                }
            },
            [Airbases.Caucasus.Maykop_Khanskaya] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED MAYKOP CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED MAYKOP SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED MAYKOP STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED MAYKOP INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED MAYKOP RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED MAYKOP AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE MAYKOP CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE MAYKOP SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE MAYKOP STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE MAYKOP INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE MAYKOP AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE MAYKOP RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                }
            },
            [Airbases.Caucasus.Sochi_Adler] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED SOCHI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED SOCHI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED SOCHI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED SOCHI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED SOCHI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED SOCHI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE SOCHI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE SOCHI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE SOCHI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE SOCHI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE SOCHI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE SOCHI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                }
            },
            [Airbases.Caucasus.Gudauta] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED GUDAUTA CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED GUDAUTA INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED GUDAUTA RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE GUDAUTA RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE GUDAUTA CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE GUDAUTA INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                }
            },
            [Airbases.Caucasus.Sukhumi_Babushara] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED SUKHUMI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE SUKHUMI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                }
            },
            [Airbases.Caucasus.Senaki_Kolkhi] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED SENAKI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED SENAKI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED SENAKI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED SENAKI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED SENAKI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED SENAKI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.JTAC] = {
                        group_name = "BLUE SENAKI JTAC",
                        warehouse_name = WarehouseManager.AircraftFlags.RQ_1A_PREDATOR
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE SENAKI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE SENAKI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE SENAKI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE SENAKI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE SENAKI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE SENAKI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }

                }
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
                    [AITaskTypes.CAP] = {
                        group_name = "RED KUTAISI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED KUTAISI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED KUTAISI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.JTAC] = {
                        group_name = "BLUE KUTAISI JTAC",
                        warehouse_name = WarehouseManager.AircraftFlags.RQ_1A_PREDATOR
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE KUTAISI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE KUTAISI SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE KUTAISI STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE KUTAISI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE KUTAISI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE KUTAISI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }

                }
            },
            [Airbases.Caucasus.Kobuleti] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED KOBULETI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "RED KOBULETI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED KOBULETI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED KOBULETI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                    
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE KOBULETI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE KOBULETI CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE KOBULETI INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE KOBULETI AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.JTAC] = {
                        group_name = "BLUE KOBULETI JTAC",
                        warehouse_name = WarehouseManager.AircraftFlags.RQ_1A_PREDATOR
                    },
                    
                }
            },
            [Airbases.Caucasus.Batumi] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED BATUMI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    }
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE BATUMI RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                }
            },
            [Airbases.Caucasus.Mozdok] = {
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED MOZDOK CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED MOZDOK SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED MOZDOK STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "RED MOZDOK INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "RED MOZDOK RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED MOZDOK AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE MOZDOK CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE MOZDOK SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE MOZDOK STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE MOZDOK INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE MOZDOK AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.E3A
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE MOZDOK RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }

                }
            },
            [Airbases.Caucasus.Mineralnye_Vody] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED MINERALNYE RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "RED MINERALNYE CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "RED MINERALNYE INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE MINERALNYE RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE MINERALNYE CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "BLUE MINERALNYE INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                }
            }
            },
            [Airbases.Syria.Khalkhalah] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE KHALKHALAH CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE KHALKHALAH INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE KHALKHALAH RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
                },
                [coalition.side.RED] = {}
            },
            [Airbases.Syria.Marj_Ruhayyil] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE MARJ CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "BLUE MARJ AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                },
                [coalition.side.RED] = {
                    [AITaskTypes.CAS] = {
                        group_name = "RED MARJ CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.AWACS] = {
                        group_name = "RED MARJ AWACS",
                        warehouse_name = WarehouseManager.AircraftFlags.A50
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "RED MARJ INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                }
            },
            [Airbases.Syria.Mezzeh] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED MEZZEH RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED MEZZEH STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED MEZZEH SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                },
                [coalition.side.BLUE] = {
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE MEZZEH RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE MEZZEH STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE MEZZEH SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                }
            },
            [Airbases.Syria.Al_Dumayr] = {
                [coalition.side.RED] = {
                    [AITaskTypes.RECON] = {
                        group_name = "RED AL-DUMAYR RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24MR
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "RED AL-DUMAYR STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "RED AL-DUMAYR SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.SU24M
                    },
                    [AITaskTypes.CAS] = {
                        group_name = "RED AL-DUMAYR CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.SU25T
                    },
                    [AITaskTypes.INTERCEPT] = {
                        group_name = "RED AL-DUMAYR INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.SU27
                    },
                },
                [coalition.side.BLUE] = {}
            },
            [Airbases.Syria.Shayrat] = {
                [coalition.side.BLUE] = {
                    [AITaskTypes.CAS] = {
                        group_name = "BLUE SHAYRAT CAS",
                        warehouse_name = WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II
                    },
                    [AITaskTypes.CAP] = {
                        group_name = "BLUE SHAYRAT INTERCEPT",
                        warehouse_name = WarehouseManager.AircraftFlags.F15C
                    },
                    [AITaskTypes.RECON] = {
                        group_name = "BLUE SHAYRAT RECON",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.SEAD] = {
                        group_name = "BLUE SHAYRAT SEAD",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    },
                    [AITaskTypes.STRIKE] = {
                        group_name = "BLUE SHAYRAT STRIKE",
                        warehouse_name = WarehouseManager.AircraftFlags.F16C_BL50
                    }
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
            },
            [AITaskTypes.CAP] = {
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
            },
            [AITaskTypes.SEAD] = {
                [WarehouseManager.Flags.KH25ML] = 2 *2,
                [WarehouseManager.Flags.KH58U] = 2 *2,
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = 1 *2,
                -- 2 * Kh-25ML AS 10 Karen 300 kg ASM Semi Act Laser
                -- 2 * Kh-58U AS-11 Kilter ARM 
                -- 1 * L-081 Fantasmagoria ELINT pod
            },
            [AITaskTypes.CAP] = {
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
            [AITaskTypes.RECON] = {},
            
            [AITaskTypes.AWACS] = {}
        }
    }



    ---@enum WarehouseManager.StockTypes
    WarehouseManager.StockTypes = {
        INITIAL = 1,
        AIR_AIR_LONG_RANGE = 2,
        AIR_AIR_SHORT_RANGE = 3,
        AIR_GROUND_GUIDED_MISSILES = 4,
        AIR_GROUND_GUIDED_BOMBS = 5,
        AIR_GROUND_BOMBS = 6,
        AIR_GROUND_ROCKETS = 7,
        ECM = 8,
        TGP = 9,
        MISC = 10,
        LOGISTICS_CAPTURE = 11,
        AG_AIRCRAFT = 12,
        MULTIROLE_AIRCRAFT = 13,
        AA_AIRCRAFT = 14,
        RECON_AIRCRAFT = 15,
        CARGO_AIRCRAFT = 16,
        SU25T_BLUFOR = 17,
        FARP = 18,
        CARRIER_INITAL = 19,
    }

    WarehouseManager.Stocks = {
        [WarehouseManager.StockTypes.FARP] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.SA342L] = 2,
                [WarehouseManager.AircraftFlags.SA342M] = 2,
                [WarehouseManager.AircraftFlags.UH_1H] = 4,
                [WarehouseManager.AircraftFlags.OH_58D] = 2,
                [WarehouseManager.AircraftFlags.AH64D_BLKII] = 4,

                [WarehouseManager.Flags.MISTRAL] = 8,


                [WarehouseManager.Flags.HOT3] = math.random(16,18),
                [WarehouseManager.Flags.AGM_114K] = math.random(12,20),
                [WarehouseManager.Flags.AGM_114L] = math.random(12,20),

                [WarehouseManager.Flags.HYDRA_70_M151_HE] = math.random(50,100),
                [WarehouseManager.Flags.HYDRA_70_M257] = math.random(50,100),
                [WarehouseManager.Flags.HYDRA_70_M274] = math.random(50,100),
                [WarehouseManager.Flags.HYDRA_70_MK1] = math.random(50,100),
                [WarehouseManager.Flags.HYDRA_70_MK5_HEAT] = math.random(50,100),
                [WarehouseManager.Flags.ZUNI_127] = math.random(50,100),

                [WarehouseManager.Flags.SNEB_254_SM_RED] = math.random(20,40),
                [WarehouseManager.Flags.SNEB_254_SM_GREEN] = math.random(20,40),
                [WarehouseManager.Flags.SNEB_251_HE] = math.random(50,100),
                [WarehouseManager.Flags.SNEB_253_HEAT] = math.random(50,100),
                [WarehouseManager.Flags.SNEB_259_IL] = math.random(20,40),


                [WarehouseManager.Flags.GIAT_M621_SAPHEI] = 5,-- not working
                [WarehouseManager.Flags.GIAT_M621_APHE] = 5,-- not working
                [WarehouseManager.Flags.GIAT_M621_HEAP] = 5,-- not working
                [WarehouseManager.Flags.GIAT_M621_HE] = 5,-- not working
                [WarehouseManager.Flags.GIAT_M621_AP] = 5,-- not working
                [WarehouseManager.Flags.GIAT_M261] = 5,-- not working
                [WarehouseManager.Flags.FN_HMP400_200] = 2,-- not working
                [WarehouseManager.Flags.FN_HMP400] = 1,-- not working
                [WarehouseManager.Flags.HMP400] = 2, -- not working

                [WarehouseManager.Flags.SAND_FILTER] = 4,
                [WarehouseManager.Flags.IR_DEFLECTOR] = 4,
                [WarehouseManager.Flags.AN_APG_78_APACHE_RADAR] = 4,

            },
            [coalition.side.RED] = {}
        },

        [WarehouseManager.StockTypes.INITIAL] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AGM_65D] = math.random(8,12),
                [WarehouseManager.Flags.AGM_65E] = math.random(8,10),
                [WarehouseManager.Flags.AGM_65F] = math.random(6,8),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(4,6),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(8,10),
                [WarehouseManager.Flags.GBU_38] = math.random(8,12),
                [WarehouseManager.Flags.GBU_12] = math.random(12,16),
                [WarehouseManager.Flags.GBU_10] = math.random(4,6),
                [WarehouseManager.Flags.GBU_16] = math.random(4,6),
                [WarehouseManager.Flags.GBU_24] = math.random(4,6),
                [WarehouseManager.Flags.GBU_32_V_2B] = math.random(6,10),
                [WarehouseManager.Flags.GBU_54_V_1B] = math.random(12,18),
                [WarehouseManager.Flags.GBU_43] = math.random(2,3),

                [WarehouseManager.Flags.MK_82] = math.random(12,30),
                [WarehouseManager.Flags.MK_83] = math.random(4,8),
                [WarehouseManager.Flags.MK_84] = math.random(8,14),
                [WarehouseManager.Flags.MK82_SNAKEEYE] = math.random(12,22),
                [WarehouseManager.Flags.MK_20_ROCKEYE] = math.random(6,12),
                [WarehouseManager.Flags.LAU_88] = math.random(8,12),
                
                [WarehouseManager.Flags.HYDRA_70_M282_MPP_APKWS] = math.random(120,130),
                [WarehouseManager.Flags.HYDRA_70_M151_HE] = math.random(60,100),
                [WarehouseManager.Flags.HYDRA_70_MK5_HEAT] = math.random(60,100),
                [WarehouseManager.Flags.CBU_87] = math.random(6,12),
                [WarehouseManager.Flags.CBU_97] = math.random(6,12),
                [WarehouseManager.Flags.CBU_99] = math.random(4,8),
                [WarehouseManager.Flags.CBU_105] = math.random(4,8),
                [WarehouseManager.Flags.CBU_103] = math.random(4,8),

                [WarehouseManager.Flags.AAQ_28_LITENING] = math.random(4,6),
                [WarehouseManager.Flags.AN_AAQ_33_SNIPER] = math.random(4,5),
                [WarehouseManager.Flags.AAQ_14_LANTIRN] = math.random(6,10),
                [WarehouseManager.Flags.AAQ_13_LANTIRN] = math.random(6,10),
                [WarehouseManager.Flags.AN_ASQ_228_ATFLIR] = math.random(4,6),
                [WarehouseManager.Flags.F14_LANTIRN] = math.random(2,3),
                [WarehouseManager.Flags.ECLAIR_M_60] = math.random(2,4),
                [WarehouseManager.Flags.ECLAIR_M_51] = math.random(2,4),

                [WarehouseManager.Flags.HTS_POD] = math.random(4,6),
                [WarehouseManager.Flags.ALQ_184] = math.random(2,3),
                [WarehouseManager.Flags.ADM_141_TALD] = math.random(12,20),
                [WarehouseManager.Flags.AGM_154C_JSOW] = math.random(2,4),
                [WarehouseManager.Flags.AGM_154A_JSOW] = math.random(4,6),
                [WarehouseManager.Flags.AGM_84H_SLAM_ER] = math.random(2,4),
                [WarehouseManager.Flags.AGM_84D_HARPOON] = math.random(2,4),

                [WarehouseManager.Flags.AIM_120B] = math.random(16,20),
                [WarehouseManager.Flags.AIM_120C] = math.random(6,8),
                [WarehouseManager.Flags.AIM_9M] = math.random(20,28),
                [WarehouseManager.Flags.AIM_9X] = math.random(8,14),
                [WarehouseManager.Flags.AIM_9L] = math.random(8,14),
                [WarehouseManager.Flags.AIM_7F] = math.random(14,18),
                [WarehouseManager.Flags.AIM_7M] = math.random(14,18),
                [WarehouseManager.Flags.AIM_7P] = math.random(14,18),
                [WarehouseManager.Flags.AIM_7MH] = math.random(14,18),
                [WarehouseManager.Flags.AIM_54C_MK47] = math.random(6,10),
                [WarehouseManager.Flags.SUPER_530D] = math.random(8,14),
                [WarehouseManager.Flags.MAGIC_II] = math.random(8,14),

                [WarehouseManager.AircraftFlags.A10C_TANK_KILLER_II] = 4,
                [WarehouseManager.AircraftFlags.E3A] = 1,
                [WarehouseManager.AircraftFlags.F15E_SE] = 4,
                [WarehouseManager.AircraftFlags.F16C_BL50] = 2,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 6,
                [WarehouseManager.AircraftFlags.M2000C] = 4,
                [WarehouseManager.AircraftFlags.MIRAGE_2000_5] = 4,
                [WarehouseManager.AircraftFlags.F15C] = 4,
                [WarehouseManager.AircraftFlags.F_14A_135_GR] = 4,
                [WarehouseManager.AircraftFlags.RQ_1A_PREDATOR] = 3,
                [WarehouseManager.AircraftFlags.C130J_30] = 2,

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
                [WarehouseManager.Flags.R_60] = math.random(20,30),
                [WarehouseManager.Flags.RBK_250] = math.random(20,40),
                [WarehouseManager.Flags.RBK_250_275_AO_1SCH] = math.random(20,40),
                [WarehouseManager.Flags.RBK_500AO] = math.random(14,28),
                [WarehouseManager.Flags.RBK_500U] = math.random(14,28),
                [WarehouseManager.Flags.FAB_100] = math.random(60,120),
                [WarehouseManager.Flags.FAB_250] = math.random(40,80),
                [WarehouseManager.Flags.FAB_500] = math.random(20,40),
                [WarehouseManager.Flags.X_25MP] = math.random(10,20),
                [WarehouseManager.Flags.X_29L] = math.random(10,20),
                [WarehouseManager.Flags.S13_OF_122MM] = math.random(40,80),
                [WarehouseManager.Flags.S24A] = math.random(20,40),
                [WarehouseManager.Flags.S24B] = math.random(20,40),
                [WarehouseManager.Flags.S25_OFM_340MM] = math.random(10,20),
                [WarehouseManager.Flags.S25_O_420MM_FRAG] = math.random(6,12),
                [WarehouseManager.Flags.S5_M_HE] = math.random(60,120),
                [WarehouseManager.Flags.S5_KP_57MM_HEAT_FRAG] = math.random(60,120),

                [WarehouseManager.Flags.R60M] = math.random(20,30),
                [WarehouseManager.Flags.KAB_500KR] = math.random(20,30),

                [WarehouseManager.AircraftFlags.SU25T] = 8,
                [WarehouseManager.AircraftFlags.SU27] = 8,
                [WarehouseManager.AircraftFlags.SU24M] = 8,
                [WarehouseManager.AircraftFlags.SU33] = 10,
                [WarehouseManager.AircraftFlags.SU34] = 4,
                [WarehouseManager.AircraftFlags.A50] = 2,
                [WarehouseManager.AircraftFlags.SU24MR] = 8,

            }
                
        },
        [WarehouseManager.StockTypes.CARRIER_INITAL] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AIM_9X] = 40,
                [WarehouseManager.Flags.AIM_9M] = 60,
                [WarehouseManager.Flags.AIM_120C] = 60,
                [WarehouseManager.Flags.AIM_54C_MK47] = math.random(20,30),
                [WarehouseManager.Flags.AIM_54C_MK60] = math.random(20,30),
                [WarehouseManager.Flags.AIM_7F] = math.random(20,30),
                [WarehouseManager.Flags.AIM_7M] = math.random(20,30),
                [WarehouseManager.Flags.AIM_7P] = math.random(20,30),
                [WarehouseManager.Flags.AIM_7MH] = math.random(20,30),


                [WarehouseManager.Flags.GBU_12] = 40,
                [WarehouseManager.Flags.GBU_10] = 10,
                [WarehouseManager.Flags.GBU_16] = 20,
                [WarehouseManager.Flags.GBU_38] = 40,
                [WarehouseManager.Flags.GBU_31_V_3B] = 20,
                [WarehouseManager.Flags.AGM_154C_JSOW] = 16,

                
                [WarehouseManager.Flags.AGM_65F] = 20,
                [WarehouseManager.Flags.AGM_65E] = 20,
                [WarehouseManager.Flags.AGM_88_HARM] = 30,
                [WarehouseManager.Flags.AGM_84D_HARPOON] = 20,
                [WarehouseManager.Flags.AGM_84H_SLAM_ER] = 8,
                [WarehouseManager.Flags.AGM_154C_JSOW] = 16,

                [WarehouseManager.Flags.MK_82] = 100,
                [WarehouseManager.Flags.MK_83] = 50,
                [WarehouseManager.Flags.MK_84] = 30,
                [WarehouseManager.Flags.HYDRA_70_M151_HE] = 200,

                [WarehouseManager.Flags.F14_LANTIRN] = 10,
                [WarehouseManager.Flags.AAQ_28_LITENING] = 10,
                [WarehouseManager.Flags.AN_ASQ_228_ATFLIR] = 16,

                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 12,
                [WarehouseManager.AircraftFlags.E2C_HAWKEYE] = 2,
                [WarehouseManager.AircraftFlags.F_14A_135_GR] = 8,
                [WarehouseManager.AircraftFlags.F14B] = 6,
            },
            [coalition.side.RED] = {}
        },

        [WarehouseManager.StockTypes.SU25T_BLUFOR] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.SU25T] = 4,
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(15,30),
                [WarehouseManager.Flags.S_8O0FP2_MPP] = math.random(100,400),
                [WarehouseManager.Flags.VIKHR_M] = math.random(100,200),
                [WarehouseManager.Flags.KH_29T] = math.random(15,35),
                [WarehouseManager.Flags.BETAB_500] = math.random(10,20),
                [WarehouseManager.Flags.BETAB_500SHP] = math.random(8,16),
                [WarehouseManager.Flags.S13_OF_122MM] = math.random(20,30),
                [WarehouseManager.Flags.S24B_240MM_UnGd_Rkt] = math.random(12,20),
                [WarehouseManager.Flags.S25_OFM_340MM] = math.random(10,15),
                [WarehouseManager.Flags.S25_O_420MM_FRAG] = math.random(6,12),
                [WarehouseManager.Flags.S5_OFM_340MM] = math.random(40,60),
                [WarehouseManager.Flags.S8_KOM_80MM_HEAT] = math.random(100,150),
                [WarehouseManager.Flags.S8_TsM_SM_ORANGE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_BLUE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_GREEN] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_RED] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_VIOLET] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_WHITE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_YELLOW] = math.random(30,60),
                [WarehouseManager.Flags.S8_OM_FP2_MPP] = math.random(150,250),
                [WarehouseManager.Flags.S5_KP_57MM_HEAT_FRAG] = math.random(40,60),
                [WarehouseManager.Flags.S5_M_HE] = math.random(40,60),
                [WarehouseManager.Flags.S24A] = math.random(12,20),
                [WarehouseManager.Flags.S24B] = math.random(12,20),
                [WarehouseManager.Flags.FAB_100] = math.random(20,40),
                [WarehouseManager.Flags.FAB_100M] = math.random(20,40),
                [WarehouseManager.Flags.FAB_100SV] = math.random(20,40),
                [WarehouseManager.Flags.FAB_250] = math.random(16,32),
                [WarehouseManager.Flags.FAB_250_M62] = math.random(16,32),
                [WarehouseManager.Flags.FAB_500] = math.random(10,20),
                [WarehouseManager.Flags.KH25MP_PRGS1VP] = math.random(6,10),
                [WarehouseManager.Flags.MERCURY_LLTV_POD] = math.random(2,4),
                [WarehouseManager.Flags.MPS_410] = math.random(2,4),
                [WarehouseManager.Flags.RBK_250] = math.random(10,20),
                [WarehouseManager.Flags.RBK_250_275_AO_1SCH] = math.random(10,20),
                [WarehouseManager.Flags.RBK_500AO] = math.random(8,16),
                [WarehouseManager.Flags.RBK_500U] = math.random(8,16),
                [WarehouseManager.Flags.S25L] = math.random(4,8),
                [WarehouseManager.Flags.SAB_100MN] = math.random(10,20),
                [WarehouseManager.Flags.SAB_250_200] = math.random(8,16),
                [WarehouseManager.Flags.X_25MP] = math.random(8,12),
                [WarehouseManager.Flags.X_29L] = math.random(8,12),
                [WarehouseManager.Flags.KAB_500KR_NEW] = math.random(8,14),
                [WarehouseManager.Flags.R_60] = math.random(10,20),
                [WarehouseManager.Flags.RBK_500U_OAB_2_5RT] = math.random(8,16),
            },
            [coalition.side.RED] = {}
        },
        [WarehouseManager.StockTypes.CARGO_AIRCRAFT] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.C130J_30] = 4,
            },
            [coalition.side.RED] = {
                [WarehouseManager.AircraftFlags.IL76MD] = 4,
            }
        },

        [WarehouseManager.StockTypes.AIR_AIR_LONG_RANGE] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AIM_120B] = math.random(8,14),
                [WarehouseManager.Flags.AIM_120C] = math.random(6,10),
                [WarehouseManager.Flags.AIM_54C_MK47] = math.random(6,10),
                [WarehouseManager.Flags.AIM_54C_MK60] = math.random(6,10),
                [WarehouseManager.Flags.SUPER_530D] = math.random(8,14),
                [WarehouseManager.Flags.AIM_7F] = math.random(6,10),
                [WarehouseManager.Flags.AIM_7M] = math.random(6,10),
                [WarehouseManager.Flags.AIM_7P] = math.random(6,10),
                [WarehouseManager.Flags.AIM_7MH] = math.random(6,10),
                
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
                [WarehouseManager.Flags.AIM_9L] = math.random(6,10),
                [WarehouseManager.Flags.MAGIC_II] = math.random(8,14),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(40,60),
                [WarehouseManager.Flags.R_60] = math.random(20,30),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_BOMBS] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.MK_82] = math.random(12,18),
                [WarehouseManager.Flags.MK_83] = math.random(8,14),
                [WarehouseManager.Flags.MK_84] = math.random(6,10),
                [WarehouseManager.Flags.MK82_SNAKEEYE] = math.random(6,12),
                [WarehouseManager.Flags.MK_20_ROCKEYE] = math.random(4,8),
                [WarehouseManager.Flags.CBU_87] = math.random(4,8),
                [WarehouseManager.Flags.CBU_97] = math.random(8,16),
                [WarehouseManager.Flags.CBU_99] = math.random(4,8),
                [WarehouseManager.Flags.CBU_105] = math.random(4,8),
                [WarehouseManager.Flags.CBU_103] = math.random(4,8),
                [WarehouseManager.Flags.GBU_54_V_1B] = math.random(10,16),
                [WarehouseManager.Flags.GBU_43] = math.random(2,4),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KAB_500KR] = math.random(10,15),
                [WarehouseManager.Flags.FAB_100] = math.random(20,30),
                [WarehouseManager.Flags.FAB_250] = math.random(16,24),
                [WarehouseManager.Flags.FAB_500] = math.random(10,15),
                [WarehouseManager.Flags.RBK_250] = math.random(10,15),
                [WarehouseManager.Flags.RBK_500AO] = math.random(8,12),
                [WarehouseManager.Flags.RBK_500U] = math.random(8,12),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_BOMBS] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.GBU_38] = math.random(16,18),
                [WarehouseManager.Flags.GBU_12] = math.random(20,35),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(6,10),
                [WarehouseManager.Flags.GBU_10] = math.random(6,10),
                [WarehouseManager.Flags.GBU_16] = math.random(6,10),
                [WarehouseManager.Flags.GBU_24] = math.random(4,8),
                [WarehouseManager.Flags.GBU_32_V_2B] = math.random(4,8),
                [WarehouseManager.Flags.AGM_154C_JSOW] = math.random(4,8),
                [WarehouseManager.Flags.AGM_154A_JSOW] = math.random(4,8),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KH_29T] = math.random(10,15),
            }
        },
        [WarehouseManager.StockTypes.AIR_GROUND_GUIDED_MISSILES] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AGM_65D] = math.random(12,16),
                [WarehouseManager.Flags.AGM_65E] = math.random(6,10),
                [WarehouseManager.Flags.AGM_65F] = math.random(6,10),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(6,10),
                [WarehouseManager.Flags.AGM_84H_SLAM_ER] = math.random(2,6),
                [WarehouseManager.Flags.AGM_84D_HARPOON] = math.random(2,6),
                [WarehouseManager.Flags.ADM_141_TALD] = math.random(2,4),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.KH25ML] = math.random(10,15),
                [WarehouseManager.Flags.KH58U] = math.random(14,18),
                [WarehouseManager.Flags.X_25MP] = math.random(8,12),
                [WarehouseManager.Flags.X_29L] = math.random(8,12),
                [WarehouseManager.Flags.S25L] = math.random(4,8),
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
                [WarehouseManager.Flags.S8_OM_FP2_MPP] = math.random(150,250),
                [WarehouseManager.Flags.VIKHR_M] = math.random(100,150),
                [WarehouseManager.Flags.S13_OF_122MM] = math.random(20,30),
                [WarehouseManager.Flags.S24A] = math.random(12,20),
                [WarehouseManager.Flags.S24B] = math.random(12,20),
                [WarehouseManager.Flags.S25_OFM_340MM] = math.random(10,15),
                [WarehouseManager.Flags.S25_O_420MM_FRAG] = math.random(6,10),
                [WarehouseManager.Flags.S5_M_HE] = math.random(40,60),
                [WarehouseManager.Flags.S5_KP_57MM_HEAT_FRAG] = math.random(40,60),
                [WarehouseManager.Flags.S8_TsM_SM_ORANGE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_BLUE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_GREEN] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_RED] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_VIOLET] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_WHITE] = math.random(30,60),
                [WarehouseManager.Flags.S8_TsM_SM_YELLOW] = math.random(30,60),
            }
        },
        [WarehouseManager.StockTypes.ECM] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.ALQ_184] = math.random(2,6),
                [WarehouseManager.Flags.ECLAIR_M_60] = math.random(2,4),
                [WarehouseManager.Flags.ECLAIR_M_51] = math.random(2,4),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_LEFT] = 12,
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_RIGHT] = 12,
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(2,4),
                [WarehouseManager.Flags.MERCURY_LLTV_POD] = math.random(2,4),
                [WarehouseManager.Flags.MPS_410] = math.random(2,4),
            }
        },
        [WarehouseManager.StockTypes.TGP] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.AAQ_28_LITENING] = math.random(5,8),
                [WarehouseManager.Flags.AN_AAQ_33_SNIPER] = math.random(5,8),
                [WarehouseManager.Flags.AAQ_14_LANTIRN] = math.random(5,8),
                [WarehouseManager.Flags.AAQ_13_LANTIRN] = math.random(5,8),
                [WarehouseManager.Flags.AN_ASQ_228_ATFLIR] = math.random(4,6),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.MERCURY_LLTV_POD] = math.random(2,4),
            }

        },
        [WarehouseManager.StockTypes.MISC] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.Flags.HTS_POD] = math.random(4,6),
                [WarehouseManager.Flags.ADM_141_TALD] = math.random(16,24),
            },
            [coalition.side.RED] = {
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(4,6),
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_LEFT] = math.random(4,6),
                [WarehouseManager.Flags.L005_SORBSIYA_ECM_POD_RIGHT] = math.random(4,6),
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
                [WarehouseManager.AircraftFlags.SU24MR] = 4,
            }
        },
        [WarehouseManager.StockTypes.AA_AIRCRAFT] = {
            [coalition.side.BLUE] = {
                [WarehouseManager.AircraftFlags.F16C_BL50] = 6,
                [WarehouseManager.AircraftFlags.FA18C_HORNET] = 4,
                [WarehouseManager.AircraftFlags.M2000C] = 2,
                [WarehouseManager.AircraftFlags.F15C] = 2,
                [WarehouseManager.AircraftFlags.F_14A_135_GR] = 2,
                [WarehouseManager.AircraftFlags.E3A] = 1,
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
                [WarehouseManager.Flags.AGM_65D] = math.random(12,20),
                [WarehouseManager.Flags.AGM_65F] = math.random(8,14),
                [WarehouseManager.Flags.AGM_88_HARM] = math.random(2,6),
                [WarehouseManager.Flags.GBU_31_V_3B] = math.random(4,8),
                [WarehouseManager.Flags.GBU_38] = math.random(15,20),
                [WarehouseManager.Flags.GBU_12] = math.random(16,28),
                [WarehouseManager.Flags.LAU_88] = math.random(4,10),
                [WarehouseManager.Flags.ADM_141_TALD] = math.random(2,4),
                
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
                [WarehouseManager.Flags.R73_AA_11_ARCHER] = math.random(10,20),
                [WarehouseManager.Flags.S_8O0FP2_MPP] = math.random(100,200),
                [WarehouseManager.Flags.S8_OM_FP2_MPP] = math.random(80,160),
                [WarehouseManager.Flags.VIKHR_M] = math.random(12,16),
                [WarehouseManager.Flags.KH_29T] = math.random(6,10),
                [WarehouseManager.Flags.KH25ML] = math.random(10,15),
                [WarehouseManager.Flags.KH58U] = math.random(6,10),
                [WarehouseManager.Flags.L081_FANTASMAGORIA] = math.random(2,4),
                [WarehouseManager.Flags.R27ER] = math.random(6,10),
                [WarehouseManager.Flags.R27ET] = math.random(4,10),
                [WarehouseManager.Flags.S8_TsM_SM_ORANGE] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_BLUE] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_GREEN] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_RED] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_VIOLET] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_WHITE] = math.random(20,40),
                [WarehouseManager.Flags.S8_TsM_SM_YELLOW] = math.random(20,40),
            }
        },
     
    }

    -- Compute a scaling factor based on estimated users.
    -- Linear scaling:
    -- users=1 -> 1.0, users=4 -> 4.0 (before clamping)
    ---@param users_estimate number|nil
    function WarehouseManager:getStockScale(users_estimate)
        local baseline = 1
        local users = users_estimate or Scenario.estimated_users or 1

        if users < 0 then users = 0 end
        local scale = users / baseline
        return scale
    end

    ---@param airbase_name string
    function WarehouseManager:clearWarehouse(airbase_name)
        local airbase = Airbase.getByName(airbase_name)
        if not airbase then return end

        local warehouse = airbase:getWarehouse()
        if not warehouse then return end

        local inventory = warehouse:getInventory()
        if inventory then
            for category_name, category_items in pairs(inventory) do
                for item_name, count in pairs(category_items) do
                    warehouse:setItem(item_name, 0)
                end
            end
            MissionLogger:info("Warehouse cleared for: " .. airbase_name)
        end
    end

--- Warning: ensure the side is correctly set before execution
    ---@param airbase_name string
    ---@param side coalition.side
    ---@param stock_types WarehouseManager.StockTypes[]
    function WarehouseManager:attributeAirbaseStock(airbase_name,side,stock_types)

        local airbase = Airbase.getByName(airbase_name)
        if not airbase then MissionLogger:warn("No airbase") return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then MissionLogger:warn("No warehouse") return false end

        local added_stuff_tbl = {}
        for i,stock_type in ipairs(stock_types) do
            for stock_type_n,stock_c in pairs(WarehouseManager.Stocks) do
                if stock_type_n == stock_type then
                    if utils.tableContains({
                        WarehouseManager.StockTypes.AG_AIRCRAFT,
                        WarehouseManager.StockTypes.AA_AIRCRAFT,
                        WarehouseManager.StockTypes.MULTIROLE_AIRCRAFT,
                    }, stock_type) then
                        -- Aircraft are added without user scaling
                        local stock = stock_c[side]
                        if stock then
                            for id,amount in pairs(stock) do
                                warehouse:addItem(id, amount)
                                table.insert(added_stuff_tbl, {id, amount})
                            end
                        end
                        break
                    else
                        local stock = stock_c[side]
                        if stock then
                            local user_scale = WarehouseManager:getStockScale()
                            if side == coalition.side.RED and Config.red_stock_multiplier then
                                user_scale = user_scale * Config.red_stock_multiplier
                            end

                            for id,amount in pairs(stock) do
                                local scaled_amount = math.max(1, math.floor(amount * user_scale))
                                warehouse:addItem(id, scaled_amount)
                                table.insert(added_stuff_tbl, {id, scaled_amount})
                            end
                        end
                        break
                    end
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
            15% of supplies go to airbases level 1, divided equally
            25% of supplies go to airbases level 2, divided equally
            30% of supplies go to airbases level 3, divided equally
            30% of supplies go to airbases level 4, divided equally
            
            If no bases of one level exist, the other levels share proportionally.
        ]]

        local level_1_bases = {}
        local level_2_bases = {}
        local level_3_bases = {}
        local level_4_bases = {}

        -- 1. Find all eligible airbases and their warehouses
        for _, zone in ipairs(zones) do
            if zone.side == side and zone.zone_type == ZoneTypes.AIRBASE and zone.airbase_name then
                local airbase = Airbase.getByName(zone.airbase_name)
                if airbase then
                    local warehouse = airbase:getWarehouse()
                    if warehouse then
                        if zone.level == 1 then
                            table.insert(level_1_bases, warehouse)
                        elseif zone.level == 2 then
                            table.insert(level_2_bases, warehouse)
                        elseif zone.level == 3 then
                            table.insert(level_3_bases, warehouse)
                        elseif zone.level == 4 then
                            table.insert(level_4_bases, warehouse)
                        end
                    end
                end
            end
        end

        local count_l1 = #level_1_bases
        local count_l2 = #level_2_bases
        local count_l3 = #level_3_bases
        local count_l4 = #level_4_bases
        
        local mult_l1 = 0
        local mult_l2 = 0
        local mult_l3 = 0
        local mult_l4 = 0
        
        -- Get distribution percentages from config
        local share_l1 = Config.warehouse_supply_distribution.tier_1 or 0.15
        local share_l2 = Config.warehouse_supply_distribution.tier_2 or 0.25
        local share_l3 = Config.warehouse_supply_distribution.tier_3 or 0.30
        local share_l4 = Config.warehouse_supply_distribution.tier_4 or 0.30

        -- 2. Calculate supply multipliers based on distribution logic
        -- Calculate total available share and redistribute if any level has no bases
        local total_bases = count_l1 + count_l2 + count_l3 + count_l4
        
        if total_bases == 0 then
            MissionLogger:info("WarehouseManager:handleIncomingSupplies: No airbases found for " .. (utils.coalitionToString(side) or "Unknown Side"))
            return
        end
        
        -- Redistribute shares proportionally if any level is missing
        local available_share = 1.0
        local levels_with_bases = {}
        
        if count_l1 > 0 then table.insert(levels_with_bases, {count = count_l1, share = share_l1, level = 1}) else available_share = available_share - share_l1 end
        if count_l2 > 0 then table.insert(levels_with_bases, {count = count_l2, share = share_l2, level = 2}) else available_share = available_share - share_l2 end
        if count_l3 > 0 then table.insert(levels_with_bases, {count = count_l3, share = share_l3, level = 3}) else available_share = available_share - share_l3 end
        if count_l4 > 0 then table.insert(levels_with_bases, {count = count_l4, share = share_l4, level = 4}) else available_share = available_share - share_l4 end
        
        -- Calculate base share sum for redistribution
        local base_share_sum = 0
        for _, level_info in ipairs(levels_with_bases) do
            base_share_sum = base_share_sum + level_info.share
        end
        
        -- Distribute supplies
        for _, level_info in ipairs(levels_with_bases) do
            local adjusted_share = (level_info.share / base_share_sum) * (1.0)
            local multiplier = adjusted_share / level_info.count
            
            if level_info.level == 1 then
                mult_l1 = multiplier
            elseif level_info.level == 2 then
                mult_l2 = multiplier
            elseif level_info.level == 3 then
                mult_l3 = multiplier
            elseif level_info.level == 4 then
                mult_l4 = multiplier
            end
        end

        MissionLogger:info("HandleIncomingSupplies: Distributing to L1: " .. count_l1 .. " bases, L2: " .. count_l2 .. " bases, L3: " .. count_l3 .. " bases, L4: " .. count_l4 .. " bases.")

        -- 3. Get the full list of items to add (pre-multiplication)
        local items_to_add = {}
        local aircraft_to_add = {}
        for _, stock_type in ipairs(stock_types) do
            -- Find the correct stock definition
            if WarehouseManager.Stocks[stock_type] and WarehouseManager.Stocks[stock_type][side] then
                local stock = WarehouseManager.Stocks[stock_type][side]

                if utils.tableContains({
                    WarehouseManager.StockTypes.AG_AIRCRAFT,
                    WarehouseManager.StockTypes.AA_AIRCRAFT,
                    WarehouseManager.StockTypes.MULTIROLE_AIRCRAFT,
                }, stock_type) then
                    -- Aircraft are handled separately, user multiplier not applied
                    for id, amount in pairs(stock) do
                        aircraft_to_add[id] = (aircraft_to_add[id] or 0) + amount
                    end
                else
                    for id, amount in pairs(stock) do
                        -- Use a table to merge items if they appear in multiple stock_types
                        items_to_add[id] = (items_to_add[id] or 0) + amount
                    end
                end
            end
        end

        -- 4. Distribute items to warehouses with calculated amounts

        local user_scale = WarehouseManager:getStockScale()
        if side == coalition.side.RED and Config.red_stock_multiplier then
            user_scale = user_scale * Config.red_stock_multiplier
        end

        -- Add to tier 1 bases
        if mult_l1 > 0 then
            for _, warehouse in ipairs(level_1_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l1 * user_scale)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
                for id, amount in pairs(aircraft_to_add) do
                    warehouse:addItem(id, amount)
                end
            end
        end

        -- Add to tier 2 bases
        if mult_l2 > 0 then
            for _, warehouse in ipairs(level_2_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l2 * user_scale)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
                for id, amount in pairs(aircraft_to_add) do
                    warehouse:addItem(id, amount)
                end
            end
        end

        -- Add to tier 3 bases
        if mult_l3 > 0 then
            for _, warehouse in ipairs(level_3_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l3 * user_scale)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
                for id, amount in pairs(aircraft_to_add) do
                    warehouse:addItem(id, amount)
                end
            end
        end
        
        -- Add to tier 4 bases
        if mult_l4 > 0 then
            for _, warehouse in ipairs(level_4_bases) do
                for id, base_amount in pairs(items_to_add) do
                    local final_amount = math.ceil(base_amount * mult_l4 * user_scale)
                    if final_amount > 0 then
                        warehouse:addItem(id, final_amount)
                    end
                end
                for id, amount in pairs(aircraft_to_add) do
                    warehouse:addItem(id, amount)
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
        if not airbase or not airbase.getCoalition then 
            MissionLogger:info("[PAYLOAD CHECK] Airbase or coalition check failed")
            return false 
        end
        local airbase_coalition = airbase:getCoalition()
        
        -- Check if payload definition exists for this coalition and task type
        if not WarehouseManager.AIPayloads[airbase_coalition] then
            MissionLogger:error("[PAYLOAD CHECK] No payload definitions for coalition "..airbase_coalition)
            return false
        end
        
        if not WarehouseManager.AIPayloads[airbase_coalition][ai_task_type] then
            MissionLogger:info("[PAYLOAD CHECK] No payload definition for "..ai_task_type.." (coalition "..airbase_coalition..") - treating as NO PAYLOAD REQUIRED")
            return true  -- If no payload is defined, treat as "no requirements" = OK
        end

        local warehouse = airbase:getWarehouse()
        if not warehouse then 
            MissionLogger:error("[PAYLOAD CHECK] No warehouse for airbase")
            return false 
        end

        -- Check if the payload table is empty (no requirements)
        local has_requirements = false
        for _ in pairs(WarehouseManager.AIPayloads[airbase_coalition][ai_task_type]) do
            has_requirements = true
            break
        end
        
        if not has_requirements then
            MissionLogger:info("[PAYLOAD CHECK] Empty payload table for "..ai_task_type.." - treating as NO PAYLOAD REQUIRED")
            return true  -- Empty payload table = no requirements
        end

        -- Check each weapon requirement
        for wpn_id,amount in pairs(WarehouseManager.AIPayloads[airbase_coalition][ai_task_type]) do
            local current_count = warehouse:getItemCount(wpn_id)
            if current_count < amount then
                MissionLogger:info("[PAYLOAD CHECK] "..ai_task_type.." payload INSUFFICIENT: need "..amount.." of "..wpn_id..", have "..current_count)
                return false
            end
        end
        
        MissionLogger:info("[PAYLOAD CHECK] "..ai_task_type.." payload OK")
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
        return false
    end


end