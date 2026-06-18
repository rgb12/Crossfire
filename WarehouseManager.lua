---@class WarehouseManager
WarehouseManager = {}
do
    -- Helpers to validate warehouse item support
    function WarehouseManager:isSupportedWeapon(item_name)
        if not item_name then return false end
        return utils.tableContains(Stocks.Equipment, item_name)
    end

    function WarehouseManager:isSupportedAircraft(item_name)
        if not item_name then return false end
        return utils.tableContains(Stocks.Aircraft, item_name)
    end
   

    --- Resolves the aircraft type name (warehouse key) for a given side+task
    --- by reading the first unit of the in-mission template group via native DCS API.
    ---@param side coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return string|nil
    function WarehouseManager:getAircraftTypeForTask(side, ai_task_type)
        local side_assets = (side == coalition.side.BLUE)
            and GroupData.COMMON_ASSETS.BLUE
            or  GroupData.COMMON_ASSETS.RED
        if not side_assets then return nil end

        -- AITaskTypes values are uppercase (e.g. "CAS") COMMON_ASSETS keys are lowercase (e.g. "cas")
        local template_task_type = side_assets[string.lower(ai_task_type)]
        if not template_task_type then return nil end

        -- Resolve to the per-era template (e.g. "BLUE WW2 CAS") when present so
        -- the stock check reads the SAME aircraft type that TaskManager spawns.
        local template_name = EraSystem.resolveTaskTemplateName(template_task_type)

        if not template_name then return nil end
        local group = Group.getByName(template_name)
        if not group then return nil end

        local units = group:getUnits()
        if not units or not units[1] then return nil end

        return units[1]:getTypeName()
    end
    --[[ ========================================================================
        AIPayloads -- the Lua mirror of what each AI flight actually carries.
        ------------------------------------------------------------------------
        For every AI air template you place in the mission editor, declare here
        the weapons that template is loaded with (the SAME stores you set on the
        pylons in the ME). Before an AI task launches, checkIfAIPayloadInStock()
        verifies the airbase warehouse holds enough of each declared store; if
        not, the task is skipped. This keeps AI flights from spawning "for free"
        once a warehouse runs dry, and lets warehouse stock actually limit sortie
        generation.

        ERA SUPPORT
        -----------
        The table is keyed [coalition][AITaskTypes]. To give a DIFFERENT loadout
        to a per-era template (e.g. the "BLUE WW2 CAS" P-47 flight carries bombs
        and rockets, not Mavericks + Litening), add an optional era sub-table:

            [coalition.side.BLUE] = {
                [AITaskTypes.CAS] = { ...modern default... },
                [Eras.WW2] = {                      -- per-era overrides
                    [AITaskTypes.CAS] = {
                        [Stocks.Equipment.MK_82]    = 2 *2,
                        [Stocks.Equipment.HVAR ...] = 8 *2,
                    },
                },
            }

        Resolution (getAIPayload below): for the ACTIVE era, an
        [coalition][Eras.X][task] entry is used when present; otherwise it falls
        back to the plain [coalition][task] entry. This mirrors how AI templates
        resolve "BLUE WW2 CAS" -> "BLUE CAS" via EraSystem.resolveTaskTemplateName,
        so the stock GATE and the spawned FLIGHT always agree.

        The Eras.* keys are tables, so they never collide with AITaskTypes string
        keys ("CAS", "CAP", ...) sitting alongside them in the same table.
       ======================================================================== ]]
    WarehouseManager.AIPayloads = {
        [coalition.side.BLUE] = {
            [Eras.MODERN] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.LAU_88] = 2 *2, -- accounts for both aircrafts
                    [Stocks.Equipment.AGM_65D] = 4 *2,
                    [Stocks.Equipment.AAQ_28_LITENING] = 1 *2,
                    [Stocks.Equipment.AIM_9M] = 1 *2,
                    [Stocks.Equipment.HYDRA_70_M282_MPP_APKWS] = 7 *2
                },
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.AIM_120C] = 4 *2,
                    [Stocks.Equipment.AIM_9M] = 2 *2
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.AIM_120B] = 2 *2,
                    [Stocks.Equipment.AIM_9X] = 2 *2,
                    [Stocks.Equipment.GBU_31_V_3B] = 2 *2,
                    [Stocks.Equipment.AAQ_28_LITENING] = 1 *2,
                },
                [AITaskTypes.SEAD] = {
                    [Stocks.Equipment.AIM_120B] = 2 *2,
                    [Stocks.Equipment.AIM_9X] = 2 *2,
                    [Stocks.Equipment.AGM_88_HARM] = 2 *2,
                    [Stocks.Equipment.HTS_POD] = 1 *2,
                    [Stocks.Equipment.ALQ_184] = 1 *2,
                },
                [AITaskTypes.RECON] = {
                    [Stocks.Equipment.AAQ_28_LITENING] = 1,
                    [Stocks.Equipment.AIM_120C] = 2,
                    [Stocks.Equipment.AIM_9X] = 2,
                },
                [AITaskTypes.AWACS] = {},
                [AITaskTypes.JTAC] = {},
            },
            [Eras.LATECOLDWAR] = {
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.AIM_9L] = 4 *2,
                    [Stocks.Equipment.AIM_7F] = 4 *2,
                },
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.AGM_65D] = 4 *2,
                    [Stocks.Equipment.MK_82] = 4 *2,
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.AIM_9L] = 2 *2,
                    [Stocks.Equipment.GBU_16] = 2 *2,
                },
                [AITaskTypes.SEAD] = {
                    [Stocks.Equipment.AGM_88_HARM] = 2 *2,
                    [Stocks.Equipment.AIM_9L] = 2 *2,
                },
                [AITaskTypes.RECON] = {
                    [Stocks.Equipment.R_550] = 2
                },
                [AITaskTypes.AWACS] = {},
            },
            [Eras.WW2] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.AN_M57] = 1 *2,
                    [Stocks.Equipment.HVAR]  = 10 *2,
                },
                [AITaskTypes.CAP] = {},
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.AN_M65] = 1 *2,
                },
                [AITaskTypes.RECON] = {},
            },
            [Eras.EARLYCOLDWAR] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.AGM_12A] = 2 *2,
                    [Stocks.Equipment.MK_82] = 6 *2,
                    
                },
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.AIM_9B] = 2 *2
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.MK_83] = 4 *2

                },
                [AITaskTypes.RECON] = {},
            }
        },
        [coalition.side.RED] = {
            [Eras.MODERN] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.R73_AA_11_ARCHER] = 2 *2,
                    [Stocks.Equipment.S_8O0FP2_MPP] = 2*20 *2,
                    [Stocks.Equipment.VIKHR_M] = 2*8 *2,
                    [Stocks.Equipment.KH_29T] = 2 *2,
                },
                [AITaskTypes.SEAD] = {
                    [Stocks.Equipment.KH25ML] = 2 *2,
                    [Stocks.Equipment.KH58U] = 2 *2,
                    [Stocks.Equipment.L081_FANTASMAGORIA] = 1 *2,
                },
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.R73_AA_11_ARCHER] = 2 *2,
                    [Stocks.Equipment.R27ER] = 2 *2,
                    [Stocks.Equipment.R27ET] = 2 *2,
                    [Stocks.Equipment.L005_SORBSIYA_ECM_POD_LEFT] = 1 *2,
                    [Stocks.Equipment.L005_SORBSIYA_ECM_POD_RIGHT] = 1 *2,

                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.KAB_1500LG] = 2 *2,
                    [Stocks.Equipment.R_60M] = 1 *2,
                },
                [AITaskTypes.RECON] = {},
    
                [AITaskTypes.AWACS] = {},
            },
            [Eras.EARLYCOLDWAR] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.OFAB_250_270] = 2 *2,
                    [Stocks.Equipment.S_5M] = 16 *2,
                },
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.R_3S] = 2 *2,
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.OFAB_250_270] = 2 *2
                },
                [AITaskTypes.RECON] = {},
            },
            [Eras.LATECOLDWAR] = {
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.FAB_250_M62] = 2 *2,
                    [Stocks.Equipment.VIKHR_M] = 16 *2,
                    [Stocks.Equipment.S_8O0FP2_MPP] = 40 *2,
                },
                [AITaskTypes.CAP] = {
                    [Stocks.Equipment.R73_AA_11_ARCHER] = 4 *2,
                    [Stocks.Equipment.R_27R] = 2 *2,
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.BETAB_500] = 4 *2,
                    [Stocks.Equipment.R73_AA_11_ARCHER] = 2 *2
                },
                [AITaskTypes.RECON] = {
                    [Stocks.Equipment.R_60M] = 4,
                },
                [AITaskTypes.AWACS] = {},
                [AITaskTypes.SEAD] = {
                    [Stocks.Equipment.KH58U] = 2 *2,
                    [Stocks.Equipment.R_60M] = 2 *2,
                }
            },
            [Eras.WW2] = {
                [AITaskTypes.CAP] = {},
                [AITaskTypes.RECON] = {},
                [AITaskTypes.CAS] = {
                    [Stocks.Equipment.R4M] = 26 *2
                },
                [AITaskTypes.STRIKE] = {
                    [Stocks.Equipment.SC_500_J] = 1 *2
                }
            }

            --[[ ----------------------------------------------------------------
                PER-ERA RED PAYLOAD OVERRIDES (example -- copy into the live
                table to use). Layout is [side][Eras.X][task]; it only applies
                when that era is ACTIVE and the matching per-era ME template
                (e.g. "RED EARLYCOLDWAR CAP") exists.
            [Eras.EARLYCOLDWAR] = {
                [AITaskTypes.CAP] = {              -- e.g. a MiG-21 flight
                    [Stocks.Equipment.R_3S] = 2 *2,
                },
            },
            ---------------------------------------------------------------- ]]
        },

        --[[ --------------------------------------------------------------------
            PER-ERA BLUE PAYLOAD OVERRIDES (example -- copy into the live table
            to use). Layout is [side][Eras.X][task]: a per-era entry wins for the
            active era, otherwise the plain [side][task] payload above is used
        (see WarehouseManager:getAIPayload). The amounts must match the
            stores you loaded on those flights' pylons in the mission editor
            ("*2" = a two-ship flight).

        [Eras.WW2] = {
            [AITaskTypes.CAS] = {                  -- e.g. a P-47 flight
                [Stocks.Equipment.MK_82] = 2 *2,
                [Stocks.Equipment.HVAR]  = 8 *2,
            },
            [AITaskTypes.CAP] = {},                -- guns only, no missiles
            [AITaskTypes.STRIKE] = {
                [Stocks.Equipment.MK_82] = 2 *2,
            },
        },
        [Eras.EARLYCOLDWAR] = {
            [AITaskTypes.CAP] = {                  -- e.g. an F-5E flight
                [Stocks.Equipment.AIM_9P] = 2 *2,
            },
        },
        -------------------------------------------------------------------- ]]
    }

    -- The set of weapon (non-aircraft) stock types
    WarehouseManager.EquipmentNonAircraftStockTypes = {
        StockTypes.AIR_AIR_LONG_RANGE,
        StockTypes.AIR_AIR_SHORT_RANGE,
        StockTypes.AIR_GROUND_GUIDED_MISSILES,
        StockTypes.AIR_GROUND_GUIDED_BOMBS,
        StockTypes.AIR_GROUND_BOMBS,
        StockTypes.AIR_GROUND_ROCKETS,
        StockTypes.ECM,
        StockTypes.TGP,
        StockTypes.MISC,
        StockTypes.FARP_MISSILES,
        StockTypes.FARP_AG_ROCKETS,
        StockTypes.FARP_MISC,
        StockTypes.FARP_GUNS,
        StockTypes.FUEL_TANKS
    }

    -- Which weapon stock types a composite/bespoke package draws from. Keys and
    -- values are BOTH StockTypes enum values (no strings). Single-stock-type
    -- packages (e.g. AIR_GROUND_BOMBS) are not listed: they resolve implicitly
    -- to themselves.
    WarehouseManager.StockTypeContents = {
        [StockTypes.INITIAL] = {
            StockTypes.AIR_AIR_LONG_RANGE, StockTypes.AIR_AIR_SHORT_RANGE,
            StockTypes.AIR_GROUND_GUIDED_MISSILES, StockTypes.AIR_GROUND_GUIDED_BOMBS,
            StockTypes.AIR_GROUND_BOMBS, StockTypes.AIR_GROUND_ROCKETS,
            StockTypes.ECM, StockTypes.TGP, StockTypes.MISC,
            StockTypes.AG_AIRCRAFT, StockTypes.AA_AIRCRAFT, StockTypes.MULTIROLE_AIRCRAFT,
            StockTypes.RECON_AIRCRAFT, StockTypes.CARGO_AIRCRAFT, StockTypes.LOGISTICS_HELICOPTER,
        },
        [StockTypes.CARRIER_INITAL] = {
            StockTypes.AIR_AIR_LONG_RANGE, StockTypes.AIR_AIR_SHORT_RANGE,
            StockTypes.AIR_GROUND_GUIDED_MISSILES, StockTypes.AIR_GROUND_GUIDED_BOMBS,
            StockTypes.AIR_GROUND_BOMBS, StockTypes.AIR_GROUND_ROCKETS, StockTypes.TGP,
            StockTypes.AG_AIRCRAFT, StockTypes.AA_AIRCRAFT, StockTypes.MULTIROLE_AIRCRAFT,
            StockTypes.RECON_AIRCRAFT, StockTypes.CARGO_AIRCRAFT,
        },
        [StockTypes.LOGISTICS_CAPTURE] = {
            StockTypes.AIR_AIR_LONG_RANGE, StockTypes.AIR_AIR_SHORT_RANGE,
            StockTypes.AIR_GROUND_GUIDED_MISSILES, StockTypes.AIR_GROUND_GUIDED_BOMBS,
            StockTypes.AIR_GROUND_BOMBS, StockTypes.AIR_GROUND_ROCKETS,
            StockTypes.ECM, StockTypes.TGP, StockTypes.MISC,
            StockTypes.AG_AIRCRAFT, StockTypes.AA_AIRCRAFT, StockTypes.MULTIROLE_AIRCRAFT,
            StockTypes.RECON_AIRCRAFT, StockTypes.CARGO_AIRCRAFT,
            StockTypes.ATTACK_HELICOPTER, StockTypes.LOGISTICS_HELICOPTER,
        },
        [StockTypes.FARP] = {
            StockTypes.FARP_AG_ROCKETS, StockTypes.FARP_MISC, StockTypes.FARP_MISSILES, StockTypes.FARP_GUNS,
            StockTypes.ATTACK_HELICOPTER, StockTypes.LOGISTICS_HELICOPTER,
        },
    }

    -- The aircraft (role) stock types whose lists are built dynamically from
    -- EraSystem.getEnabledAircraft() rather than read from a static table.
    WarehouseManager.AircraftStockTypes = {
        StockTypes.AG_AIRCRAFT,
        StockTypes.AA_AIRCRAFT,
        StockTypes.MULTIROLE_AIRCRAFT,
        StockTypes.RECON_AIRCRAFT,
        StockTypes.CARGO_AIRCRAFT,
        StockTypes.ATTACK_HELICOPTER,
        StockTypes.LOGISTICS_HELICOPTER,
    }

    -- Round half-up to an integer (Lua 5.1 has no integer division/round).
    local function roundInt(x)
        return math.floor(x + 0.5)
    end

    -- Which weapon stock types feed a given stock type. Composite/bespoke types
    -- are listed in StockTypeContents; a single weapon stock type resolves to
    -- itself; anything else (e.g. an aircraft stock type) yields none.
    ---@param stock_type StockTypes
    ---@return StockTypes[] list of weapon stock type enum values
    local function weaponStockTypesFor(stock_type)
        local composite = WarehouseManager.StockTypeContents[stock_type]
        if composite then return composite end
        if utils.tableContains(WarehouseManager.EquipmentNonAircraftStockTypes, stock_type) then
            return { stock_type }
        end
        return {}
    end


    local UNTRACKABLE_WEAPON_PREFIXES = {
    }
    ---@param clsid string weapon clsid
    ---@return boolean trackable whether the DCS warehouse API can hold/count it
    local function isWarehouseTrackable(clsid)
        if utils.tableContains(UNTRACKABLE_WEAPON_PREFIXES, clsid) then
            return false
        end
        return true
    end
    WarehouseManager.isWarehouseTrackable = isWarehouseTrackable

 
    ---@param dcs_type string
    ---@return StockTypes role
    function WarehouseManager:classifyAircraftRole(dcs_type)
        -- Known explicit mapping (overrides attribute heuristics).
        local cached_types = {
            [Stocks.Aircraft.A10C]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.A10C_TANK_KILLER_II]  = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.A10A]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU25]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU25T]                = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU25TM]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU24M]                = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU34]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.SU17M4]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MIG27K]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.AV8BNA]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.A6E]                  = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.A20G]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.AJS37]                = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.S3B]                  = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.L39ZA]                = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.HAWK]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MB339A]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MB339APAN]            = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.C101EB]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.C101CC]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TORNADO_IDS]          = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TORNADO_GR4]          = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1AD]          = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1AZ]          = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.F117A]                = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.MOSQUITO]             = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.P47D_30]              = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.P47D_30BL1]           = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.P47D_40]              = StockTypes.AG_AIRCRAFT,

            [Stocks.Aircraft.B1B_LANCER]           = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.B52H]                 = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TU_160]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TU_95MS]              = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TU_22M3]              = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.TU_142]               = StockTypes.AG_AIRCRAFT,
            [Stocks.Aircraft.H6J]                  = StockTypes.AG_AIRCRAFT,

            [Stocks.Aircraft.F15C]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F14B]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F_14A_135_GR]         = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F14A_EARLY]           = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F14A]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG29A]               = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG29S]               = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG29G]               = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG29_FULCRUM]        = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG31]                = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG25PD]              = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MiG23MLD]             = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG21BIS]             = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG19P]               = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG15BIS]             = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIG15BIS_FC]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.SU27]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.SU33]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.J11A]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F86F_SABRE]           = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F86F_FC]              = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F5E]                  = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F5E_3]                = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F5E_3_FC]             = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.F16A]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1C]           = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CE]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1C_200]       = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CG]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CH]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CJ]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CK]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CZ]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1EH]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1JA]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.QF4E]                 = StockTypes.AA_AIRCRAFT,

            [Stocks.Aircraft.BF109K4]              = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.FW190A8]              = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.FW190D9]              = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.SPITFIRE_LF]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.SPITFIRE_CW]          = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.P51D]                 = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.P51D_30_NA]           = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.TF51D]                = StockTypes.AA_AIRCRAFT,
            [Stocks.Aircraft.I16]                  = StockTypes.AA_AIRCRAFT,

            [Stocks.Aircraft.F16C_BL50]            = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F16C_BL52D]           = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.FA18C_HORNET]         = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.FA18C]                = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.FA18A]                = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F15E_SE]              = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F15E]                 = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.M2000C]               = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_2000_5]        = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.SU30]                 = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.JF17]                 = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F4E]                  = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F4E_45MC]             = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CT]          = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1EQ]          = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1EE]          = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1ED]          = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1EDA]         = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1M_CE]        = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1M_EE]        = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F4U1D]                = StockTypes.MULTIROLE_AIRCRAFT,
            [Stocks.Aircraft.F4U1D_CW]             = StockTypes.MULTIROLE_AIRCRAFT,

            [Stocks.Aircraft.SU24MR]               = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.MIG25RBT]             = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.MIRAGE_F1CR]          = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.RQ_1A_PREDATOR]       = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.MQ9_REAPER]           = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.WINGLOONG_I]          = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.E3A]                  = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.E2C_HAWKEYE]          = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.A50]                  = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.KJ2000]               = StockTypes.RECON_AIRCRAFT,
            [Stocks.Aircraft.AN30M]                = StockTypes.RECON_AIRCRAFT,

            [Stocks.Aircraft.C130J_30]             = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.C130]                 = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.C17A]                 = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.IL76MD]               = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.AN26B]                = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.YAK40]                = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.KC135]                = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.KC135_MPRS]           = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.KC130]                = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.IL78M]                = StockTypes.CARGO_AIRCRAFT,
            [Stocks.Aircraft.S3_B_TANKER]          = StockTypes.CARGO_AIRCRAFT,

            [Stocks.Aircraft.UH_1H]                = StockTypes.LOGISTICS_HELICOPTER,
            [Stocks.Aircraft.MI8MT]                = StockTypes.LOGISTICS_HELICOPTER,
            [Stocks.Aircraft.MI24P]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.CH47D]                = StockTypes.LOGISTICS_HELICOPTER,
            [Stocks.Aircraft.CH47F_BL1]                = StockTypes.LOGISTICS_HELICOPTER,
            [Stocks.Aircraft.SA342L]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.SA342M]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.SA342Minigun]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.SA342Mistral]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.OH58D_R]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.OH_58D]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.AH1W]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.AH64D_BLKII]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.AH64A]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.AH64D]                = StockTypes.ATTACK_HELICOPTER,
            [Stocks.Aircraft.UH_60L]                = StockTypes.LOGISTICS_HELICOPTER,
        }
        if cached_types[dcs_type] then return cached_types[dcs_type] end

        -- Unknown airframe: treat as multirole 
        return StockTypes.MULTIROLE_AIRCRAFT
    end


    ---@param stock_type StockTypes
    ---@param side coalition.side
    ---@return table<string, integer>
    function WarehouseManager:generateStock(stock_type, side)
        local stock = {}
        local _ = side  -- reserved (see note above)

        local contained_stock_types = weaponStockTypesFor(stock_type) -- INITIAL -> {AIR_AIR_LONG_RANGE, AIR_GROUND_BOMBS, ...}
        if #contained_stock_types == 0 then return stock end

        -- Set of weapon stock types this package accepts (fast membership test).
        local contained_stock_types_lookup = {}
        for _, st in ipairs(contained_stock_types) do contained_stock_types_lookup[st] = true end

        local default = Stocks.EquipmentDataDefault

        for clsid, equipment_data in pairs(Stocks.EquipmentData) do

            local equipment_stock_types = {}
            if equipment_data.stock_type then equipment_stock_types = { equipment_data.stock_type } end
            if equipment_data.stock_types then equipment_stock_types = equipment_data.stock_types end


            local stock_type_matched
            for _, data_stock_type in ipairs(equipment_stock_types) do

                if contained_stock_types_lookup[data_stock_type] then
                    stock_type_matched = data_stock_type
                    break
                end
            end


            if stock_type_matched and isWarehouseTrackable(clsid) and EraSystem.isWeaponEnabled(clsid) then
                local base_qty
                if type(equipment_data.base_qty) == "number" then
                    base_qty = equipment_data.base_qty or 0
                elseif type(equipment_data.base_qty) == "table" then
                    base_qty = equipment_data.base_qty[stock_type_matched] or 0
                end
                if not base_qty then base_qty = default.base_qty or 6 end


                local variance = default.variance or Stocks.STOCK_VARIANCE or 0.15

                -- variance in [1-variance, 1+variance]
                local jitter = 1 + ((math.random() * 2 * variance) - variance)

                local amount = base_qty * jitter
                amount = roundInt(amount)
                if amount < 1 then amount = 1 end
                stock[clsid] = amount
            end
        end

        return stock
    end


    ---@param stock_type StockTypes
    ---@param side coalition.side
    ---@return table<string, integer>
    function WarehouseManager:generateAircraftStock(stock_type, side)
        local stock = {}
        local _ = side  -- reserved (see note above)
        if not utils.tableContains(WarehouseManager.AircraftStockTypes, stock_type) then
            return stock
        end

        -- A small per-role default quantity (how many airframes a base of that
        -- role-type holds). Kept modest, matching the old hardcoded 2..8 range.
        local role_qty = {
            [StockTypes.AG_AIRCRAFT]          = {min=10, max=14},
            [StockTypes.AA_AIRCRAFT]          = {min=10, max=14},
            [StockTypes.MULTIROLE_AIRCRAFT]   = {min=10, max=14},
            [StockTypes.RECON_AIRCRAFT]       = {min=4, max=6},
            [StockTypes.CARGO_AIRCRAFT]       = {min=10, max=14},
            [StockTypes.ATTACK_HELICOPTER]    = {min=8, max=10},
            [StockTypes.LOGISTICS_HELICOPTER] = {min=10, max=12},
        }
        local qty = role_qty[stock_type] or {min=2, max=4}

        for aircraft_type in pairs(EraSystem.getEnabledAircraft()) do
            if WarehouseManager:classifyAircraftRole(aircraft_type) == stock_type then
                stock[aircraft_type] = math.random(qty.min,qty.max)
            end
        end
        return stock
    end

    ---@param users_estimate number|nil
    ---@return number scale
    function WarehouseManager:getStockScale(users_estimate)
        -- Warehouse "disabled" means effectively infinite stock, regardless of
        -- auto scaling.
        if not Config.enable_warehouse then
            return 10000
        end

        local cfg = Config.auto_scaling or {}

        if cfg.enable == false then
            return 1
        end

        local min_users      = cfg.min_users or 1
        local max_users      = cfg.max_users or math.huge
        local users_per_unit = cfg.users_per_unit or 1
        if users_per_unit < 1 then users_per_unit = 1 end

        -- Determine the player count: explicit estimate, else live BLUE players.
        local users = users_estimate
        if not users then
            local players = coalition.getPlayers(coalition.side.BLUE)
            users = (players and #players) or 0
        end

        if users < min_users then users = min_users end
        if users > max_users then users = max_users end

        local scale = users / users_per_unit
        if scale < 1 then scale = 1 end
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

    -- Expand any composite stock types in the list to their individual sub-types.
    local function expandStockTypes(stock_types)
        local expanded = {}
        for _, st in ipairs(stock_types) do
            local composite = WarehouseManager.StockTypeContents[st]
            if composite then
                for _, sub_st in ipairs(composite) do
                    table.insert(expanded, sub_st)
                end
            else
                table.insert(expanded, st)
            end
        end
        return expanded
    end

--- Warning: ensure the side is correctly set before execution
    ---@param airbase_name string
    ---@param side coalition.side
    ---@param stock_types StockTypes[]
    function WarehouseManager:attributeAirbaseStock(airbase_name,side,stock_types)

        local airbase = Airbase.getByName(airbase_name)
        if not airbase then MissionLogger:warn("No airbase") return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then MissionLogger:warn("No warehouse") return false end

        stock_types = expandStockTypes(stock_types)

        local added_stuff_tbl = {}
        for i,stock_type in ipairs(stock_types) do
            if utils.tableContains(WarehouseManager.AircraftStockTypes, stock_type) then
                -- Aircraft availability is derived from the enabled aircraft set
                -- (era/config aware) and added WITHOUT user scaling, as before.
                local stock = WarehouseManager:generateAircraftStock(stock_type, side)
                for id,amount in pairs(stock) do
                    warehouse:addItem(id, amount)
                    table.insert(added_stuff_tbl, {id, amount})
                end
            else
                -- Weapon stock types are generated from the cost/usefulness
                -- economy (only enabled weapons appear), then user-scaled.
                local stock = WarehouseManager:generateStock(stock_type, side)
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
        end


        if utils.tableContains(stock_types, StockTypes.FARP) then
            -- add liquids
            local scale = WarehouseManager:getStockScale()
            if side == coalition.side.RED and Config.red_stock_multiplier then
                scale = scale * Config.red_stock_multiplier
            end
            --[[
            0    : jetfuel
            1    : Aviation gasoline
            2    : MW50
            3    : Diesel
            ]]
            warehouse:addLiquid(0, 50000 * scale) -- jetfuel
            warehouse:addLiquid(1, 20000 * scale) -- avgas  
            warehouse:addLiquid(2, 5000 * scale)  -- MW50
            warehouse:addLiquid(3, 10000 * scale) -- diesel
        end

        return added_stuff_tbl
    end

    ---@param side coalition.side
    ---@param stock_types StockTypes[]
    function WarehouseManager:handleIncomingSupplies(side,stock_types)

        stock_types = expandStockTypes(stock_types)

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

        MissionLogger:info("HandleIncomingSupplies: Distributing to T1: " .. count_l1 .. " bases, T2: " .. count_l2 .. " bases, T3: " .. count_l3 .. " bases, T4: " .. count_l4 .. " bases.")

        -- 3. Get the full list of items to add (pre-multiplication). Generated
        --    ONCE here per supply event so the per-tier amounts below are
        --    derived from a single deterministic snapshot.
        local items_to_add = {}
        local aircraft_to_add = {}
        for _, stock_type in ipairs(stock_types) do
            if utils.tableContains(WarehouseManager.AircraftStockTypes, stock_type) then
                -- Aircraft are handled separately, user multiplier not applied.
                local stock = WarehouseManager:generateAircraftStock(stock_type, side)
                for id, amount in pairs(stock) do
                    aircraft_to_add[id] = (aircraft_to_add[id] or 0) + amount
                end
            else
                local stock = WarehouseManager:generateStock(stock_type, side)
                for id, amount in pairs(stock) do
                    -- Use a table to merge items if they appear in multiple stock_types
                    items_to_add[id] = (items_to_add[id] or 0) + amount
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
                        if id == "weapons.nurs.HYDRA_70_M151" then
                            MissionLogger:info("ROCKETS TO BE ADDED "..final_amount)
                        end
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

    --- Resolve the declared payload for a coalition + task, honouring per-era
    --- overrides. For the ACTIVE era, an [coalition][Eras.X][task] entry wins;
    --- otherwise we fall back to the plain [coalition][task] entry. Mirrors
    --- EraSystem.resolveTaskTemplateName so the stock gate matches the flight
    --- that TaskManager actually spawns.
    ---@param airbase_coalition coalition.side
    ---@param ai_task_type AITaskTypes
    ---@return table|nil payload  { [weapon_clsid] = amount } or nil if none declared
    function WarehouseManager:getAIPayload(airbase_coalition, ai_task_type)
        local side_payloads = WarehouseManager.AIPayloads[airbase_coalition]
        if not side_payloads then return nil end

        local active_era = EraSystem and EraSystem.getActiveEra and EraSystem.getActiveEra()
        if active_era then
            local era_payloads = side_payloads[active_era]
            if era_payloads and era_payloads[ai_task_type] then
                return era_payloads[ai_task_type]
            end
        end

        return nil
    end

    ---@param airbase Airbase
    ---@param ai_task_type AITaskTypes
    ---@return boolean, string|nil
    function WarehouseManager:checkIfAIPayloadInStock(airbase, ai_task_type)
        if Config.enable_ai_payload_checks == false then
            MissionLogger:info("[PAYLOAD CHECK] AI payload checks disabled in config")
            return true
        end
        if not airbase or not airbase.getCoalition then 
            MissionLogger:info("[PAYLOAD CHECK] Airbase or coalition check failed")
            return false 
        end
        local airbase_coalition = airbase:getCoalition()

        -- Check if payload definition exists for this coalition and task type
        if not WarehouseManager.AIPayloads[airbase_coalition] then
            MissionLogger:info("[PAYLOAD CHECK] No payload definitions for coalition "..airbase_coalition)
            return false
        end

        -- Resolve the active-era payload (falls back to the base task payload).
        local payload = WarehouseManager:getAIPayload(airbase_coalition, ai_task_type)
        if not payload then
            MissionLogger:info("[PAYLOAD CHECK] No payload definition for "..ai_task_type.." (coalition "..airbase_coalition..") - treating as NO PAYLOAD REQUIRED")
            return true  -- If no payload is defined, treat as "no requirements" = OK
        end

        local warehouse = airbase:getWarehouse()
        if not warehouse then
            MissionLogger:info("[PAYLOAD CHECK] No warehouse for airbase")
            return false
        end

        -- Check if the payload table is empty (no requirements)
        local has_requirements = false
        for _ in pairs(payload) do
            has_requirements = true
            break
        end

        if not has_requirements then
            MissionLogger:info("[PAYLOAD CHECK] Empty payload table for "..ai_task_type.." - treating as NO PAYLOAD REQUIRED")
            return true  -- Empty payload table = no requirements
        end

        -- Check each weapon requirement
        for wpn_id,amount in pairs(payload) do
            -- Skip weapons the warehouse API cannot hold/count (unguided rockets,
            -- gun shells, drop tanks, ...). getItemCount stays 0 for these forever,
            -- so requiring them would block the task PERMANENTLY. They are not
            -- warehouse-limited, so treat them as always available.
            if isWarehouseTrackable(wpn_id) then
                local current_count = warehouse:getItemCount(wpn_id)
                local critical_amount = math.max(current_count-2,0)
                if critical_amount < amount then
                    MissionLogger:info("[PAYLOAD CHECK] "..ai_task_type.." payload INSUFFICIENT: need "..amount.." of "..wpn_id..", have "..critical_amount)
                    return false
                end
            else
                MissionLogger:info("[PAYLOAD CHECK] "..ai_task_type.." skipping untrackable weapon "..wpn_id.." (not warehouse-manageable)")
            end
        end
        
        MissionLogger:info("[PAYLOAD CHECK] "..ai_task_type.." payload OK")
        return true

    end

    function WarehouseManager:getAircraftReserveThreshold()
        return Config.tasking.warehouse_aircraft_reserve or 2
    end

    ---@param airbase_name string
    ---@param ai_task_type AITaskTypes
    ---@return boolean
    function WarehouseManager:checkAircraftInStock(airbase_name,ai_task_type)

        local airbase = Airbase.getByName(airbase_name)
        if not airbase then return false end

        local warehouse = airbase:getWarehouse()
        if not warehouse then return false end

        if not airbase:getCoalition() then return false end
        local side = airbase:getCoalition()

        local acft_name = self:getAircraftTypeForTask(side, ai_task_type)
        if acft_name then
            if warehouse:getItemCount(acft_name) > self:getAircraftReserveThreshold() then
                return true
            else
                return false
            end
        end
        return false
    end

end
