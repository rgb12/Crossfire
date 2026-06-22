---@class CoalSetup
---@field initial_dist_blue_to_frontline number
---@field auto_coalition_designation boolean
---@field dist_variance number

---@class CarrierSetup
---@field carrier_unit_name string
---@field tomahawk_launcher_unit_name string|nil
---@field enabled boolean

---@class LHASetup
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

---@class MapSetup
---@field width_factor number
---@field corridor_half_width number
---@field airbase_influence number
---@field red_distribution number


---@class Resupply
---@field blue_point vec3
---@field red_point vec3

-- Prevents unknown zones from being passed as nil and skipping other zones
local function passUnknown(...)
    local zones = {}
    local count = select("#", ...)

    for index = 1, count do
        local zone = select(index, ...)
        if zone then
            zones[#zones + 1] = zone
        end
    end

    return zones
end

-- Theater-keyed zone pool. Add zones for each theater you support.
-- Zones with an explicit zone_type are pre-typed and the generator will not reassign them.
-- FARPs with dedicated helipad infrastructure in the ME should be pre-typed as ZoneTypes.FARP.
---@type table<string, ZoneHandler[]>
available_zones = {
    [Theatres.CAUCASUS] = passUnknown(
    ZoneHandler:new({name = "VAZIANI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Vaziani}),
    ZoneHandler:new({name = "BESLAN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Beslan}),
    ZoneHandler:new({name = "MOZDOK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Mozdok}),
    ZoneHandler:new({name = "NALCHIK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Nalchik}),
    ZoneHandler:new({name = "MINERALNYE-VODY", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Mineralnye_Vody}),
    ZoneHandler:new({name = "SOCHI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sochi_Adler}),
    ZoneHandler:new({name = "SUKHUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Sukhumi_Babushara}),
    ZoneHandler:new({name = "SENAKI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Senaki_Kolkhi}),
    ZoneHandler:new({name = "KUTAISI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kutaisi}),
    ZoneHandler:new({name = "BATUMI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Batumi}),
    ZoneHandler:new({name = "ANAPA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Anapa_Vityazevo}),
    ZoneHandler:new({name = "KRYMSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krymsk}),
    ZoneHandler:new({name = "KOBULETI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Kobuleti}),
    ZoneHandler:new({name = "MAYKOP", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Maykop_Khanskaya}),
    ZoneHandler:new({name = "KRASNODAR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Krasnodar_Pashkovsky}),
    ZoneHandler:new({name = "NOVOROSSIYSK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Novorossiysk}),
    ZoneHandler:new({name = "GELENDZHIK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Gelendzhik}),
    ZoneHandler:new({name = "GUDAUTA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Caucasus.Gudauta}),
    ZoneHandler:new({name = "ALPHA"}),
    ZoneHandler:new({name = "BRAVO"}),
    ZoneHandler:new({name = "CHARLIE"}),
    ZoneHandler:new({name = "DELTA"}),
    ZoneHandler:new({name = "FIELDS"}),
    ZoneHandler:new({name = "ECHO"}),
    ZoneHandler:new({name = "STRONGHOLD-CHARLIE"}),
    ZoneHandler:new({name = "FOXTROT"}),
    ZoneHandler:new({name = "GOLF"}),
    ZoneHandler:new({name = "HOTEL"}),
    ZoneHandler:new({name = "INDIA"}),
    ZoneHandler:new({name = "ONI"}),
    ZoneHandler:new({name = "OSCAR"}),
    ZoneHandler:new({name = "AIRFIELD"}),
    ZoneHandler:new({name = "FARM"}),
    ZoneHandler:new({name = "AHALSOPELI"}),
    ZoneHandler:new({name = "SEASIDE"}),
    ZoneHandler:new({name = "CHECKPOINT-NORTH"}),
    ZoneHandler:new({name = "CHECKPOINT-EAST"}),
    ZoneHandler:new({name = "CHECKPOINT-WEST"}),
    ZoneHandler:new({name = "XRAY"}),
    ZoneHandler:new({name = "MIKE"}),
    ZoneHandler:new({name = "ZULU"}),
    ZoneHandler:new({name = "LIMA"}),
    ZoneHandler:new({name = "OUTPOST"}),
    ZoneHandler:new({name = "VALLEY"}),
    ZoneHandler:new({name = "MOUNTAIN"}),
    ZoneHandler:new({name = "GRIGOLISHI"}),
    ZoneHandler:new({name = "NOVEMBER"}),
    ZoneHandler:new({name = "QUEBEC"}),
    ZoneHandler:new({name = "YANKEE"}),
    ZoneHandler:new({name = "UNIFORM"}),
    ZoneHandler:new({name = "ROMEO"}),
    ZoneHandler:new({name = "JULIETT"}),
    ZoneHandler:new({name = "PAPA"}),
    ZoneHandler:new({name = "VICTOR"}),
    ZoneHandler:new({name = "WHISKEY"}),
    ZoneHandler:new({name = "TANGO"}),
    ZoneHandler:new({name = "KILO"}),
    ZoneHandler:new({name = "HOUSES"}),
    ZoneHandler:new({name = "ASSOKOLAY"}),
    ZoneHandler:new({name = "LESOGORSKAYA"}),
    ZoneHandler:new({name = "ACE"}),
    ZoneHandler:new({name = "JOKER"}),
    ZoneHandler:new({name = "ABINSK"}),
    ZoneHandler:new({name = "JACK"}),
    ZoneHandler:new({name = "HEVSHA"}),
    ZoneHandler:new({name = "EDISA"}),
    ZoneHandler:new({name = "GVERKI"}),
    ZoneHandler:new({name = "SACHHERE"}),
    ZoneHandler:new({name = "HEART"}),
    ZoneHandler:new({name = "CLUB"}),
    ZoneHandler:new({name = "PORT"}),
    ZoneHandler:new({name = "BAY"}),
    ZoneHandler:new({name = "STRONGHOLD"}),
    ZoneHandler:new({name = "REFUGE"}),
    ZoneHandler:new({name = "OBSERVATORY"}),
    ZoneHandler:new({name = "COAST"}),
    ZoneHandler:new({name = "VARDANE"}),
    ZoneHandler:new({name = "LOO"}),
    ZoneHandler:new({name = "ESTO"}),
    ZoneHandler:new({name = "GAGRA"}),
    ZoneHandler:new({name = "SOCHI-CENTER"}),
    ZoneHandler:new({name = "GUBSKAYA"}),
    ZoneHandler:new({name = "TOWN"}),
    ZoneHandler:new({name = "PSEBAY"}),
    ZoneHandler:new({name = "DIAMOND"}),
    ZoneHandler:new({name = "SPADE"}),
    ZoneHandler:new({name = "QUEEN"}),
    ZoneHandler:new({name = "KING"}),
    ZoneHandler:new({name = "CHECKPOINT-SOUTH"}),
    ZoneHandler:new({name = "DEHVIRI"}),
    ZoneHandler:new({name = "ABANOETI"}),
    ZoneHandler:new({name = "LEDGEBE"}),
    ZoneHandler:new({name = "KOKI"}),
    ZoneHandler:new({name = "GALI"}),
    ZoneHandler:new({name = "LABRA"}),
    ZoneHandler:new({name = "ARADU"}),
    ZoneHandler:new({name = "TKVARCHELI"}),
    ZoneHandler:new({name = "HURZUK"}),
    ZoneHandler:new({name = "KARACHAEVSK"}),
    ZoneHandler:new({name = "CHECKPOINT-ALPHA"}),
    ZoneHandler:new({name = "CHECKPOINT-BRAVO"}),
    ZoneHandler:new({name = "CHECKPOINT-CHARLIE"}),
    ZoneHandler:new({name = "CHECKPOINT-DELTA"}),
    ZoneHandler:new({name = "CHECKPOINT-ECHO"}),
    ZoneHandler:new({name = "CHECKPOINT-FOXTROT"}),
    ZoneHandler:new({name = "CHECKPOINT-GOLF"}),
    ZoneHandler:new({name = "CHECKPOINT-HOTEL"}),
    ZoneHandler:new({name = "CHECKPOINT-INDIA"}),
    ZoneHandler:new({name = "CHECKPOINT-JULIETT"}),
    ZoneHandler:new({name = "CHECKPOINT-ROMEO"}),
    ZoneHandler:new({name = "CHECKPOINT-KILO"}),
    ZoneHandler:new({name = "CHECKPOINT-LIMA"}),
    ZoneHandler:new({name = "CHECKPOINT-MIKE"}),
    ZoneHandler:new({name = "CHECKPOINT-NOVEMBER"}),
    ZoneHandler:new({name = "CHECKPOINT-OSCAR"}),
    ZoneHandler:new({name = "CHECKPOINT-PAPA"}),
    ZoneHandler:new({name = "TRAINING-AIRFIELD"}),
    ZoneHandler:new({name = "CHECKPOINT-QUEBEC"}),
    ZoneHandler:new({name = "SADON"}),
    ZoneHandler:new({name = "BURON"}),
    ZoneHandler:new({name = "GLOLA"}),
    ZoneHandler:new({name = "KEVIN"}),
    ZoneHandler:new({name = "CHECKPOINT-SIERRA"}),
    ZoneHandler:new({name = "CHECKPOINT-ZULU"}),
    ZoneHandler:new({name = "CHECKPOINT-XRAY"}),
    ZoneHandler:new({name = "BYLYM"}),
    ZoneHandler:new({name = "TEBERDA"}),
    ZoneHandler:new({name = "CHECKPOINT-VICTOR"}),
    ZoneHandler:new({name = "CHECKPOINT-WHISKEY"}),
    ZoneHandler:new({name = "OUTPOST-ALPHA"}),
    ZoneHandler:new({name = "OUTPOST-BRAVO"}),
    ZoneHandler:new({name = "OUTPOST-CHARLIE"}),
    ZoneHandler:new({name = "CHECKPOINT-UNIFORM"}),
    ZoneHandler:new({name = "CHECKPOINT-TANGO"}),
    ZoneHandler:new({name = "CHECKPOINT-YANKEE"}),
    ZoneHandler:new({name = "OUTPOST-DELTA"}),
    ZoneHandler:new({name = "OUTPOST-ECHO"}),
    ZoneHandler:new({name = "OUTPOST-FOXTROT"}),
    ZoneHandler:new({name = "OUTPOST-GOLF"}),
    ZoneHandler:new({name = "OUTPOST-HOTEL"}),
    ZoneHandler:new({name = "OUTPOST-ZULU"}),
    ZoneHandler:new({name = "SUBURBS"}),
    ZoneHandler:new({name = "OUTPOST-INDIA"}),
    ZoneHandler:new({name = "OUTPOST-JULIETT"}),
    ZoneHandler:new({name = "OUTPOST-KILO"}),
    ZoneHandler:new({name = "OUTPOST-LIMA"}),
    ZoneHandler:new({name = "OUTPOST-MIKE"}),
    ZoneHandler:new({name = "ALAGIR"}),
    ZoneHandler:new({name = "OUTPOST-NOVEMBER"}),
    ZoneHandler:new({name = "OUTPOST-DECEMBER"}),
    ZoneHandler:new({name = "OUTPOST-SEPTEMBER"}),
    ZoneHandler:new({name = "OUTPOST-OSCAR"}),
    ZoneHandler:new({name = "STRONGHOLD-ALPHA"}),
    ZoneHandler:new({name = "STRONGHOLD-BRAVO"}),
    ZoneHandler:new({name = "NORTH-BAY"}),
    ZoneHandler:new({name = "SUPSEH"}),
    ZoneHandler:new({name = "NORTH-FIELDS"}),
    ZoneHandler:new({name = "LONDON"})
    ), -- [Theaters.CAUCASUS]
    [Theatres.SYRIA] = passUnknown(
        ZoneHandler:new({name = "KHALKHALAH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Khalkhalah}),
        ZoneHandler:new({name = "JABAB"}),
        ZoneHandler:new({name = "ALPHA"}),
        ZoneHandler:new({name = "BURAQ"}),
        ZoneHandler:new({name = "CHARLIE"}),
        ZoneHandler:new({name = "DELTA"}),
        ZoneHandler:new({name = "SOUTHPOINT"}),
        ZoneHandler:new({name = "MARJ-RUHAYYIL", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Marj_Ruhayyil}),
        ZoneHandler:new({name = "BRAVO"}),
        ZoneHandler:new({name = "AL-DUMAYR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Al_Dumayr}),
        ZoneHandler:new({name = "SAYQAL", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Sayqal}),
        ZoneHandler:new({name = "RAYAK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Rayak}),
        ZoneHandler:new({name = "MEZZEH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Mezzeh}),
        ZoneHandler:new({name = "ECHO"}),
        ZoneHandler:new({name = "FOXTROT"}),
        ZoneHandler:new({name = "GOLF"}),
        ZoneHandler:new({name = "RESORT"}),
        ZoneHandler:new({name = "HOTEL"}),
        ZoneHandler:new({name = "INDIA"}),
        ZoneHandler:new({name = "SAND"}),
        ZoneHandler:new({name = "EASTPOINT"}),
        ZoneHandler:new({name = "SHAYRAT", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Shayrat}),
        ZoneHandler:new({name = "AN NASIRIYAH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.An_Nasiriyah}),
        ZoneHandler:new({name = "JULIETT"}),
        ZoneHandler:new({name = "GREEN"}),
        ZoneHandler:new({name = "KILO"}),
        ZoneHandler:new({name = "LIMA"}),
        ZoneHandler:new({name = "MIKE"}),
        ZoneHandler:new({name = "NOVEMBER"}),
        ZoneHandler:new({name = "OSCAR"}),
        ZoneHandler:new({name = "PAPA"}),
        ZoneHandler:new({name = "STREAM"}),
        ZoneHandler:new({name = "MAQNE"}),
        ZoneHandler:new({name = "QUEBEC"}),
        ZoneHandler:new({name = "HOMS"}),
        ZoneHandler:new({name = "ROMEO"}),
        ZoneHandler:new({name = "SEASIDE"}),
        ZoneHandler:new({name = "OUTPOST"}),
        ZoneHandler:new({name = "STRONGHOLD"}),
        ZoneHandler:new({name = "TIYAS", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Tiyas}),
        ZoneHandler:new({name = "PALMYRA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Palmyra}),
        ZoneHandler:new({name = "THALAH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Tha_lah}),
        ZoneHandler:new({name = "KING HUSSEIN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.King_Hussein_Air_College}),
        ZoneHandler:new({name = "KING ABDULLAH II", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.King_Abdullah_II}),
        ZoneHandler:new({name = "MARKA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Marka}),
        ZoneHandler:new({name = "NEVATIM", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Nevatim}),
        ZoneHandler:new({name = "HATZERIM", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Hatzerim}),
        ZoneHandler:new({name = "HATZOR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Hatzor}),
        ZoneHandler:new({name = "PRINCE HASSAN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Prince_Hassan}),
        ZoneHandler:new({name = "RUWAYSHID", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Ruwayshid}),
        ZoneHandler:new({name = "TEL NOF", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Tel_Nof}),
        ZoneHandler:new({name = "PALMACHIM", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Palmachim}),
        ZoneHandler:new({name = "HERZLIYA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Herzliya}),
        ZoneHandler:new({name = "RAMAT DAVID", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Ramat_David}),
        ZoneHandler:new({name = "KIRYAT SHMONA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Kiryat_Shmona}),
        ZoneHandler:new({name = "RENE MOUAWAD", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Rene_Mouawad}),
        ZoneHandler:new({name = "AL QUSAYR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Al_Qusayr}),
        ZoneHandler:new({name = "HAMA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Hama}),
        ZoneHandler:new({name = "BASSEL AL-ASSAD", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Bassel_Al_Assad}),
        ZoneHandler:new({name = "INCIRLIK", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Incirlik}),
        ZoneHandler:new({name = "KONYA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Konya}),
        ZoneHandler:new({name = "GAZIPASA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Gazipasa}),
        ZoneHandler:new({name = "LARNACA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Larnaca}),
        ZoneHandler:new({name = "AKROTIRI", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Akrotiri}),
        ZoneHandler:new({name = "ERCAN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Ercan}),
        ZoneHandler:new({name = "KAHRAMANMARAS", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Kahramanmaras}),
        ZoneHandler:new({name = "ADIYAMAN", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Adiyaman}),
        ZoneHandler:new({name = "SANLIURFA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Sanliurfa}),
        ZoneHandler:new({name = "DIYARBAKIR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Diyarbakir}),
        ZoneHandler:new({name = "HATAY", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Hatay}),
        ZoneHandler:new({name = "ALEPPO", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Aleppo}),
        ZoneHandler:new({name = "ABU AL-DUHUR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Abu_al_Duhur}),
        ZoneHandler:new({name = "TABQA", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Tabqa}),
        ZoneHandler:new({name = "DEIR EZ-ZOR", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Deir_ez_Zor}),
        ZoneHandler:new({name = "A1"}),
        ZoneHandler:new({name = "A2"}),
        ZoneHandler:new({name = "A3"}),
        ZoneHandler:new({name = "A4"}),
        ZoneHandler:new({name = "A5"}),
        ZoneHandler:new({name = "A6"}),
        ZoneHandler:new({name = "A7"}),
        ZoneHandler:new({name = "A8"}),
        ZoneHandler:new({name = "A9"}),
        ZoneHandler:new({name = "A10"}),
        ZoneHandler:new({name = "AKSIFAT DAM"}),
        ZoneHandler:new({name = "A11"}),
        ZoneHandler:new({name = "A12"}),
        ZoneHandler:new({name = "A13"}),
        ZoneHandler:new({name = "A14"}),
        ZoneHandler:new({name = "A15"}),
        ZoneHandler:new({name = "B1"}),
        ZoneHandler:new({name = "B2"}),
        ZoneHandler:new({name = "B3"}),
        ZoneHandler:new({name = "B4"}),
        ZoneHandler:new({name = "B5"}),
        ZoneHandler:new({name = "B6"}),
        ZoneHandler:new({name = "MINAKH", zone_type = ZoneTypes.AIRBASE, airbase_name = Airbases.Syria.Minakh}),
        ZoneHandler:new({name = "B7"}),
        ZoneHandler:new({name = "B8"}),
        ZoneHandler:new({name = "B9"}),
        ZoneHandler:new({name = "B10"}),
        ZoneHandler:new({name = "B11"}),
        ZoneHandler:new({name = "C1"}),
        ZoneHandler:new({name = "C2"}),
        ZoneHandler:new({name = "C3"}),
        ZoneHandler:new({name = "C4"}),
        ZoneHandler:new({name = "C5"}),
        ZoneHandler:new({name = "C6"}),
        ZoneHandler:new({name = "D1"}),
        ZoneHandler:new({name = "D2"}),
        ZoneHandler:new({name = "D3"}),
        ZoneHandler:new({name = "D4"}),
        ZoneHandler:new({name = "D5"}),
        ZoneHandler:new({name = "D6"}),
        ZoneHandler:new({name = "D7"}),
        ZoneHandler:new({name = "E1"}),
        ZoneHandler:new({name = "E2"}),
        ZoneHandler:new({name = "E3"}),
        ZoneHandler:new({name = "E4"}),
        ZoneHandler:new({name = "E5"}),
        ZoneHandler:new({name = "E6"}),
        ZoneHandler:new({name = "E7"}),
        ZoneHandler:new({name = "E8"}),
        ZoneHandler:new({name = "E9"}),
        ZoneHandler:new({name = "F1"}),
        ZoneHandler:new({name = "F2"}),
        ZoneHandler:new({name = "F3"}),
        ZoneHandler:new({name = "F4"}),
        ZoneHandler:new({name = "F5"}),
        ZoneHandler:new({name = "F6"}),
        ZoneHandler:new({name = "F7"}),
        ZoneHandler:new({name = "F8"}),
        ZoneHandler:new({name = "G1"}),
        ZoneHandler:new({name = "G2"}),
        ZoneHandler:new({name = "G3"}),
        ZoneHandler:new({name = "G4"}),
        ZoneHandler:new({name = "G5"}),
        ZoneHandler:new({name = "G6"}),
        ZoneHandler:new({name = "G7"}),
        ZoneHandler:new({name = "H1"}),
        ZoneHandler:new({name = "H2"}),
        ZoneHandler:new({name = "H3"}),
        ZoneHandler:new({name = "J1"}),
        ZoneHandler:new({name = "J2"}),
        ZoneHandler:new({name = "J3"}),
        ZoneHandler:new({name = "J4"}),
        ZoneHandler:new({name = "K1"}),
        ZoneHandler:new({name = "K2"}),
        ZoneHandler:new({name = "K3"}),
        ZoneHandler:new({name = "K4"}),
        ZoneHandler:new({name = "K5"}),
        ZoneHandler:new({name = "K6"}),
        ZoneHandler:new({name = "K7"}),
        ZoneHandler:new({name = "K8"}),
        ZoneHandler:new({name = "K9"}),
        ZoneHandler:new({name = "K10"}),
        ZoneHandler:new({name = "L1"}),
        ZoneHandler:new({name = "L2"}),
        ZoneHandler:new({name = "L3"}),
        ZoneHandler:new({name = "L4"}),
        ZoneHandler:new({name = "L5"}),
        ZoneHandler:new({name = "L6"}),
        ZoneHandler:new({name = "L7"}),
        ZoneHandler:new({name = "L8"}),
        ZoneHandler:new({name = "L9"}),
        ZoneHandler:new({name = "N1"}),
        ZoneHandler:new({name = "N2"}),
        ZoneHandler:new({name = "N3"}),
        ZoneHandler:new({name = "N4"}),
        ZoneHandler:new({name = "N5"}),
        ZoneHandler:new({name = "N6"}),
        ZoneHandler:new({name = "N7"}),
        ZoneHandler:new({name = "N8"}),
        ZoneHandler:new({name = "N9"}),
        ZoneHandler:new({name = "N10"}),
        ZoneHandler:new({name = "O1"}),
        ZoneHandler:new({name = "O2"}),
        ZoneHandler:new({name = "O3"}),
        ZoneHandler:new({name = "O4"}),
        ZoneHandler:new({name = "O5"}),
        ZoneHandler:new({name = "P1"}),
        ZoneHandler:new({name = "P2"}),
        ZoneHandler:new({name = "P3"}),
        ZoneHandler:new({name = "P4"}),
        ZoneHandler:new({name = "P5"}),
        ZoneHandler:new({name = "Q1"}),
        ZoneHandler:new({name = "Q2"}),
        ZoneHandler:new({name = "Q3"}),
        ZoneHandler:new({name = "Q4"}),
        ZoneHandler:new({name = "Q5"}),
        ZoneHandler:new({name = "Q6"}),
        ZoneHandler:new({name = "Q7"}),
        ZoneHandler:new({name = "Q8"}),
        ZoneHandler:new({name = "Q9"}),
        ZoneHandler:new({name = "Q10"}),
        ZoneHandler:new({name = "R1"}),
        ZoneHandler:new({name = "R2"}),
        ZoneHandler:new({name = "R3"}),
        ZoneHandler:new({name = "R4"}),
        ZoneHandler:new({name = "R5"}),
        ZoneHandler:new({name = "R6"})
    ), -- [Theaters.SYRIA]
}


---@class GeneratedScenario
---@field theater string            Theatre enum value (e.g. Theaters.CAUCASUS)
---@field blue_airbase string       Zone name of the BLUE main airbase (must be in available_zones)
---@field red_airbase string        Zone name of the RED main airbase (must be in available_zones)
---@field map_setup MapSetup           Configuration for the map setup
---@field resupply Resupply         Resupply aircraft spawn points
---@field name string               Human-readable scenario name
---@field description string

---@type GeneratedScenario[]
scenarios = {
    {
        theater      = Theatres.CAUCASUS,
        blue_airbase = "VAZIANI", -- trigger zone name
        red_airbase  = "SENAKI", -- trigger zone name
        map_setup = {
            width_factor = 1.5, -- ellipse corridor width factor (1.0 = line, 1.3 = natural corridor, 2.0 = wide)
            corridor_half_width = 0.38, -- fraction of the main airbase-to-airbase distance used as half-width
            airbase_influence = 40000, -- meters; zones near either home airbase are forced into that coalition
            red_distribution = 0.75, -- fraction of the airbase-to-airbase distance assigned to RED starting territory
        },
        resupply = {
            blue_point = { x = -00318568, y = 6096, z = 00991378 },
            red_point  = { x = -00290581, y = 6096, z = 00569411 },
        },
        name        = "Georgia Liberation",
        description = "Liberate Georgia from invading forces.",
    },
    {
        theater      = Theatres.CAUCASUS,
        blue_airbase = "SOCHI", -- trigger zone name
        red_airbase  = "MOZDOK", -- trigger zone name
        map_setup = {
            width_factor = 1.3,
            corridor_half_width = 0.20,
            airbase_influence = 20*1000,
            red_distribution = 0.75,
        },
        resupply = {
            blue_point = { x = -00254027, y = 6096, z = 00386114 }, -- X-00254027 Z+00386114
            red_point  = { x = -00176003, y = 6096, z = 00915961 }, --  X-00176003 Z+00915961

        },
        name        = "High Caucasus Conflict",
        description = "Capture key airbases in a mountainous Caucasus conflict.",
    },
    {
        theater      = Theatres.CAUCASUS,
        blue_airbase = "ANAPA", -- trigger zone name
        red_airbase  = "MAYKOP", -- trigger zone name
        map_setup = {
            width_factor = 1.3,
            corridor_half_width = 0.20,
            airbase_influence = 20*1000,
            red_distribution = 0.75,
        },
        resupply = {
            blue_point = { x = -00020025, y = 6096, z = 00120993 }, --Metric: X-00020025 Z+00120993

            red_point  = { x = 00012019, y = 6096, z = 00584430 }, --  Metric: X+00012019 Z+00584430


        },
        name        = "Eastbound",
        description = "High intensity conflict in the western Caucasus.",
    },
    {
        theater      = Theatres.CAUCASUS,
        blue_airbase = "VAZIANI", -- trigger zone name
        red_airbase  = "ANAPA", -- trigger zone name
        map_setup = {
            width_factor = 1.3,
            corridor_half_width = 0.20,
            airbase_influence = 20*1000,
            red_distribution = 0.90,
        },
        resupply = {
            blue_point = { x = -00391799, y = 6096, z = 01040738 }, --Metric: X-00391799 Z+01040738
            red_point  = { x = 00014496, y = 6096, z = 00119373 }, --  Metric: X+00014496 Z+00119373

        },
        name        = "Caucasus at War",
        description = "Full-scale war in the Caucasus.",
    },
    {
        theater      = Theatres.CAUCASUS,
        blue_airbase = "SENAKI", -- trigger zone name
        red_airbase  = "SOCHI", -- trigger zone name
        map_setup = {
            width_factor = 1.2,
            corridor_half_width = 0.20,
            airbase_influence = 20000,
            red_distribution = 0.80,
        },
        resupply = {
            blue_point = { x = -00282727,  y = 6096, z = 00813147 }, --Metric: X-00282727 Z+00813147
            red_point  = { x = -00097695, y = 6096, z = 00346531 }, --Metric: X-00097695 Z+00346531

        },
        name        = "Sochi Liberation",
        description = "Liberate Sochi and invading forces.",
    },
    {
        theater      = Theatres.SYRIA,
        blue_airbase = "SHAYRAT", -- trigger zone name
        red_airbase  = "AL-DUMAYR", -- trigger zone name
        map_setup = {
            width_factor = 1.3,
            corridor_half_width = 0.20,
            airbase_influence = 40000,
            red_distribution = 0.75,
        },
        resupply = {
            blue_point = { x = 00029810,  y = 6096, z = 00156947 },
            red_point  = { x = -00248765, y = 6096, z = 00134754 },
        },
        name        = "Syrian Resolve",
        description = "Dedicated scenario set in Syria.",
    },
    {
        theater      = Theatres.SYRIA,
        blue_airbase = "DIYARBAKIR", -- trigger zone name
        red_airbase  = "KONYA", -- trigger zone name
        map_setup = {
            width_factor = 1.3,
            corridor_half_width = 0.20,
            airbase_influence = 75000,
            red_distribution = 0.75,
        },
        resupply = {
            blue_point = { x = 00168030,  y = 6096, z = 00454748 },
            red_point  = { x = 00208450, y = 6096, z = -00366546 },
        },
        name        = "North Syria",
        description = "Conflict in northern Syria.",
    },
}



-- Zone pool, scenario, and home airbases are now populated by
-- TheatreCommander.generateTheatre() inside startMission().
---@type ZoneHandler[]
zones = {}

---@type GeneratedScenario|nil
scenario = nil

---@type ZoneHandler|nil
blue_airbase = nil

---@type ZoneHandler|nil
red_airbase = nil

TheatreCommander.startMission()