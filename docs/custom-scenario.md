## Custom scenario

A scenario determines which zones will be active and what coalition they will start as.
This requires editing the `crossfire_script.lua`. You can download the script directly from the mission `.miz` file, by extracting it (using WINRAR, 7zip or similar), heading into `l10n/DEFAULT`.

1. Search for the `scenarios = { ... }` table, it's near the end of the file.
The overall structure looks like this:
```lua
scenarios = {
	{ .. } -- one for caucasus
	{ .. } -- another one for caucasus
	{ .. } -- syria
	...
}
``` 
1. Edit the following template
```lua
{

theater  =  "Caucasus",

blue_airbase  =  "SOCHI", -- trigger zone name

red_airbase  =  "KRYMSK", -- trigger zone name

-- Hand-authored layout

assigned_zones  = {

blue  = {

"SOCHI", "GUDAUTA", "SUKHUMI", "SENAKI", -- all trigger zone names, must match exactly
},

red  = {

"NOVOROSSIYSK", "GELENDZHIK", "KRYMSK", -- same here

},

},

resupply  = {

blue_point  = { x  =  -00391799, y  =  6096, z  =  01040738 },
--Metric point: X-00391799 Z+01040738

red_point  = { x  =  00014496, y  =  6096, z  =  00119373 },
-- Metric point: X+00014496 Z+00119373

  

},

name  =  "Caucasus at War",

description  =  "Full-scale war in the Caucasus.",

},
```
Terrain names are:
```lua
CAUCASUS  =  "Caucasus",
SYRIA  =  "Syria",
CW GERMANY  =  "GermanyCW",
MARIANA ISLANDS  =  "MarianaIslands",
SOUTH ATLANTIC  =  "SouthAtlantic",
SINAI  =  "Sinai",
KOLA  =  "Kola",
AFGHANISTAN  =  "Afghanistan",
NEVADA  =  "Nevada",
PERSIAN GULF  =  "PersianGulf",
NORMANDY  =  "Normandy",
THE CHANNEL  =  "TheChannel"
```
3. Insert the template just under the decleration line:
```lua
scenarios = {
{
... your block here ...
}, -- comma must be here


```
4. Use the seed finder in `tools/seed_finder.py` to determine the seed for your new scenario