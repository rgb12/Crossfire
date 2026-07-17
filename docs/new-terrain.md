
  

## New terrain

Crossfire's script allows any terrain to work with the mission.


Follow these steps to add a new terrain
 
 1. Determine the terrain DCS name:  head into the miz file using winrar or similar, open the `mission` file and search for a field called `theatre`, next to it will be theatre name, add it into `Enums.lua` and `Theatres`
 ```lua
Theatres  = {
CAUCASUS  =  "Caucasus",
SYRIA  =  "Syria",
CWGERMANY  =  "GermanyCW"
}
 ```
 2. Copy all ground units that are late-activated. Using the multi-select tool copy all units `CTRL+C` from the `crossfire_caucasus_v?.miz`, open the new terrain mission and `CTRL+V`
 Also copy the carrier group, LHA group, REARM OUTPOST
 3. Copy all the triggers (sounds, restart trigger, script init)
 4. Setup fog of war, and mission settings
 5. Using the script below, add all the airbase names to the `Enums.lua` `Airbases`
```lua
local  airbases  =  world.getAirbases()
for  i, ab  in  ipairs(airbases) do
	env.info(ab:getName())
end
```
 6.  Add a scenario
 7. Use the `build_release.py` script to generate the compiled script file, add the script to the triggers.