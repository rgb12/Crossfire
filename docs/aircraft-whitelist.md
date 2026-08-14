# Restricting which aircraft appear in warehouses

The mission has a mission-wide whitelist.
The config field is defined as:

`Config.era_system.enabled_aircraft` in `src/active-scripts/config.lua`.

```lua
enabled_aircraft = { "FA-18C_hornet", "F-15ESE", "F-16C_50", "A-10C_2" },
```

Empty table is ignored, every era-appropriate airframe is stocked.
You MUST update/keep up-to-date `EraEquipment.AircraftLoads` in `src/active-scripts/EraEquipment.lua`,
this tells the script which weapons/stores to add for each enabled aircraft.