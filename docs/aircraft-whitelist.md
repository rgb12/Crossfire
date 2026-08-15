# Restricting which aircraft appear in warehouses

The mission has a per-coalition whitelist.
The config field is defined as:

`Config.era_system.enabled_aircraft` in `src/active-scripts/config.lua`.

```lua
enabled_aircraft = {
    red_coalition  = { "MiG-29S", "Su-27", "Su-25T" },
    blue_coalition = { "FA-18C_hornet", "F-15ESE", "F-16C_50", "A-10C_2" },
},
```

Each coalition is whitelisted independently. An empty list is ignored for that
coalition, so every era-appropriate airframe is stocked for it. With the example
above, red airbases stock only the three listed types while blue airbases stock
only the four listed types.

Aircraft that are not valid in the selected era(s) are dropped and reported in
the log.

Weapon stocks follow the same split: a coalition that whitelists aircraft only
gets the weapons those airframes can carry (era-valid and not in
`restricted_weapons`). You MUST update/keep up-to-date `EraEquipment.AircraftLoads`
in `src/active-scripts/EraEquipment.lua`, this tells the script which
weapons/stores to add for each enabled aircraft.
