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
    }
}



---@enum SAM_TYPES
SAM_TYPES = {
    SHORT_RANGE = 1,
    MEDIUM_RANGE = 2,
    LONG_RANGE = 3
}


---@enum ScenarioDifficulty
ScenarioDifficulty = {
    EASY = 1,
    MEDIUM = 2,
    HARD = 3,
    EXPERT = 4
}


---@enum ZoneTypes
ZoneTypes = {
    AIRBASE = 1,
    STRONGPOINT = 2,
    FARP = 3,
    SAMSITE = 4,
    EWSITE = 5,
    LOGISTICS = 6,
    COMMS = 7
}

---@enum AITaskTypes
AITaskTypes = {
    JTAC = "JTAC",
    CAS = "CAS",
    CAP = "CAP",
    INTERCEPT = "INTERCEPT",
    AWACS = "AWACS",
    SEAD = "SEAD",
    STRIKE = "STRIKE",
    ATTACK_CONVOY = "ATTACK CONVOY",
    CAPTURE_HELO = "CAPTURE HELI",
    CAPTURE_CONVOY = "CAPTURE CONVOY",
    RESUPPLY_CARGO = "RESUPPLY CARGO",
    RECON = "RECON"
}

---@enum OperationTypes
OperationTypes = {
    CAP = "CAP",
    STRIKE = "Strike",
    SEAD = "SEAD",
    DEAD = "DEAD",
    CAS = "CAS",
    RECON = "Recon",
    AIRDROP = "Airdrop",
    INTERCEPT = "Intercept"
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
    CDS_CRATES = "cds_crate",
    ContainerClean = "M92_10Ft_Container",
    MOAB = "gbu_43b_airdrop",
    LargeContainer = "iso_container",
    SmallContainer = "iso_container_small"



}

MissionLogger = mist.Logger:new("MissionLogger", 3)