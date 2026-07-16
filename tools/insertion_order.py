import os

HERE = os.path.dirname(os.path.abspath(__file__))          # tools/
REPO_ROOT = os.path.dirname(HERE)                          # repo root

SKELETON_FILE = os.path.join(HERE, "crossfire_compiled_sleketon.lua")
COMPILED_SCRIPT = os.path.join(HERE, "crossfire_script.lua")

SRC_DIR = os.path.join(REPO_ROOT, "src")
ACTIVE_DIR = os.path.join(SRC_DIR, "active-scripts")
UNUSED_DIR = os.path.join(SRC_DIR, "unused-scripts")

RELEASE_DIR = os.path.join(SRC_DIR, "release-scripts")

INSERTION_ORDER = [
    ("--**ENUMS**--", "Enums", ACTIVE_DIR),
    ("--**CONFIG**--", "config", ACTIVE_DIR),
    ("--**UTILS**--", "Utils", ACTIVE_DIR),
    ("--**ERAEQUIPMENT**--", "EraEquipment", ACTIVE_DIR),
    ("--**CTLD**--", "CTLD", ACTIVE_DIR),
    ("--**COMMAND HANDLER**--", "CommandHandler", ACTIVE_DIR),
    ("--**AI COMMANDER**--", "AICommander", ACTIVE_DIR),
    ("--**JTAC**--", "CustomJTAC", ACTIVE_DIR),
    ("--**ENROUTE MANAGER**--", "EnrouteManager", ACTIVE_DIR),
    ("--**EVENT HANDLER**--", "EventHandler", ACTIVE_DIR),
    ("--**PERSISTENCE MANAGER**--", "PersistenceManager", ACTIVE_DIR),
    ("--**TASK MANAGER**--", "TaskManager", ACTIVE_DIR),
    ("--**THEATRE MANAGER**--", "TheatreManager", ACTIVE_DIR),
    ("--**OPERATION MANAGER**--", "OperationManager", ACTIVE_DIR),
    ("--**EXPERIENCE MANAGER**--", "ExperienceManager", ACTIVE_DIR),
    ("--**FRONTLINE**--", "Frontline", ACTIVE_DIR),
    ("--**EWRS**--", "EWRS", ACTIVE_DIR),
    ("--**JUPITER**--", "Jupiter", ACTIVE_DIR),
    ("--**UNIT HANDLER**--", "UnitHandler", ACTIVE_DIR),
    ("--**WAREHOUSE MANAGER**--", "WarehouseManager", ACTIVE_DIR),
    ("--**ZONE HANDLER**--", "ZoneHandler", ACTIVE_DIR),
    ("--**UNIT COMPOSER**--", "UnitComposer", ACTIVE_DIR),
    ("--**SCENARIOS**--", "scenarios", ACTIVE_DIR),
]
