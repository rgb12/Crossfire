---@enum Airbases
Airbases = {
    Caucasus = {
        Anapa_Vityazevo = "Anapa-Vityazevo",
        Batumi = "Batumi",
        Beslan = "Beslan",
        Gelendzhik = "Gelendzhik",
        Gudauta = "Gudauta",
        Kobuleti = "Kobuleti",
        Krasnodar_Center = "Krasnodar-Center",
        Krasnodar_Pashkovsky = "Krasnodar-Pashkovsky",
        Krymsk = "Krymsk",
        Kutaisi = "Kutaisi",
        Maykop_Khanskaya = "Maykop-Khanskaya",
        Mineralnye_Vody = "Mineralnye Vody",
        Mozdok = "Mozdok",
        Nalchik = "Nalchik",
        Novorossiysk = "Novorossiysk",
        Senaki_Kolkhi = "Senaki-Kolkhi",
        Sochi_Adler = "Sochi-Adler",
        Soganlug = "Soganlug",
        Sukhumi_Babushara = "Sukhumi-Babushara",
        Tbilisi_Lochini = "Tbilisi-Lochini",
        Vaziani = "Vaziani"
    },
    Syria = {
        Abu_al_Duhur = "Abu al-Duhur",
        Adana_Sakirpasa = "Adana Sakirpasa",
        Akrotiri = "Akrotiri",
        Al_Qusayr = "Al Qusayr",
        Al_Dumayr = "Al-Dumayr",
        Aleppo = "Aleppo",
        An_Nasiriyah = "An Nasiriyah",
        At_Tanf = "At Tanf",
        Bassel_Al_Assad = "Bassel Al-Assad",
        Beirut_Rafic_Hariri = "Beirut-Rafic Hariri",
        Ben_Gurion = "Ben Gurion",
        Damascus = "Damascus",
        Deir_ez_Zor = "Deir ez-Zor",
        Ercan = "Ercan",
        Eyn_Shemer = "Eyn Shemer",
        Gaziantep = "Gaziantep",
        Gazipasa = "Gazipasa",
        Gecitkale = "Gecitkale",
        H = "H",
        H3 = "H3",
        H3_Northwest = "H3 Northwest",
        H3_Southwest = "H3 Southwest",
        H4 = "H4",
        Haifa = "Haifa",
        Hama = "Hama",
        Hatay = "Hatay",
        Hatzor = "Hatzor",
        Herzliya = "Herzliya",
        Incirlik = "Incirlik",
        Jirah = "Jirah",
        Khalkhalah = "Khalkhalah",
        Kharab_Ishk = "Kharab Ishk",
        King_Abdullah_II = "King Abdullah II",
        King_Hussein_Air_College = "King Hussein Air College",
        Kingsfield = "Kingsfield",
        Kiryat_Shmona = "Kiryat Shmona",
        Kuweires = "Kuweires",
        Lakatamia = "Lakatamia",
        Larnaca = "Larnaca",
        Marj_Ruhayyil = "Marj Ruhayyil",
        Marj_as_Sultan_North = "Marj as Sultan North",
        Marj_as_Sultan_South = "Marj as Sultan South",
        Marka = "Marka",
        Megiddo = "Megiddo",
        Mezzeh = "Mezzeh",
        Minakh = "Minakh",
        Muwaffaq_Salti = "Muwaffaq Salti",
        Naqoura = "Naqoura",
        Nicosia = "Nicosia",
        Palmachim = "Palmachim",
        Palmyra = "Palmyra",
        Paphos = "Paphos",
        Pinarbashi = "Pinarbashi",
        Prince_Hassan = "Prince Hassan",
        Qabr_as_Sitt = "Qabr as Sitt",
        Ramat_David = "Ramat David",
        Rayak = "Rayak",
        Rene_Mouawad = "Rene Mouawad",
        Rosh_Pina = "Rosh Pina",
        Ruwayshid = "Ruwayshid",
        Sanliurfa = "Sanliurfa",
        Sayqal = "Sayqal",
        Shayrat = "Shayrat",
        Tabqa = "Tabqa",
        Taftanaz = "Taftanaz",
        Tal_Siman = "Tal Siman",
        Tel_Nof = "Tel Nof",
        Tha_lah = "Tha'lah",
        Tiyas = "Tiyas",
        Wujah_Al_Hajar = "Wujah Al Hajar"
    }
}

---@enum SAM_TYPES
SAM_TYPES = {
    SHORT_RANGE = 1,
    MEDIUM_RANGE = 2,
    LONG_RANGE = 3
}

---@enum ZoneTypes
ZoneTypes = {
    AIRBASE = 1,
    STRONGPOINT = 2,
    FARP = 3,
    SAMSITE = 4,
    EWSITE = 5,
    LOGISTICS = 6,
    COMMS = 7,
}

-- Fill in isDefensiveOperation
---@enum AITaskTypes
AITaskTypes = {
    JTAC = "JTAC",
    CAS = "CAS",
    CAP = "CAP",
    INTERCEPT = "INTERCEPT",
    AWACS = "AWACS",
    TANKER = "TANKER",
    SEAD = "SEAD",
    STRIKE = "STRIKE",
    ATTACK_CONVOY = "ATTACK CONVOY",
    CAPTURE_HELO = "CAPTURE HELI",
    REINFORCEMENT_HELO = "REINFORCEMENT HELI",
    RESUPPLY_CARGO = "RESUPPLY CARGO",
    RECON = "RECON"
}

--- Ensure that isOffensiveOperation and isDefensiveOperation in operation manager are complete
---@enum OperationTypes
OperationTypes = {
    CAP = "CAP",
    STRIKE = "Strike",
    SEAD = "SEAD",
    DEAD = "DEAD",
    CAS = "CAS",
    RUNWAY_BOMBING = "Runway Bombing",
    RECON = "Recon",
    AIRDROP = "Airdrop",
    REINFORCEMENT = "Reinforcement",
    STRATEGIC_AIRLIFT = "Airlift",
    INTERCEPT = "Intercept",
    CSAR = "CSAR",
    DEEP_RECON = "Deep Recon",
    DEEP_STRIKE = "Deep strike"
}

---@enum UserAircraftCategories
UserAircraftCategories = {
    HELICOPTER = "helicopter",
    FIXED_WING = "fixed_wing"
}

---@enum TankerRoles
TankerRoles = {
    BOOM = "boom",
    DROGUE = "drogue"
}

---@enum OperationStatus
OperationStatus = {
    AVAILABLE = "available",
    ACTIVE = "active",
    COMPLETED = "completed",
    FAILED = "failed"
}

---@enum CargoCrates
CargoCrates = {
    CDS_BARRELS = "cds_barrels",
    --CDS_CRATES = "cds_crate",
    ContainerClean = "M92_10Ft_Container",
    MOAB = "gbu_43b_airdrop",
    LargeContainer = "iso_container",
    SmallContainer = "iso_container_small",
    SUPPLY_CRATE = "cds_crate"
}

MissionLogger = mist.Logger:new("MissionLogger", 3)