
## Adding zones

  

Areas/zones are added via trigger zones. The name must match exactly the one inside the script.

  

1. Make sure the center of every zone is clear of any objects, this is to prevent helis from blowing up on spawn and landing.
2. Leave at least a 150m radius clear for FARP zones
3. Airbases should use a quad-point trigger zone and normal zones circles
4. Make sure the area is (relatively) flat, you can see the elevation of an area by hovering over it
5. Add the zone in `scenarios.lua`; if the zone is an airbase, assign the airbase name and airbase zone type
6. Placing the zone, or parts of it inside a forest makes units hard to spot and hard to kill

If a theatre is missing refer to new terrain details

Airbases must contain `airbase_name` and `zone_type  =  ZoneTypes.AIRBASE`

---

Example of zones

``` lua

available_zones  = {

[Theatres.CAUCASUS] =  passUnknown(

ZoneHandler:new({name  =  "VAZIANI", zone_type  =  ZoneTypes.AIRBASE, airbase_name  =  Airbases.Caucasus.Vaziani}),

ZoneHandler:new({name  =  "BESLAN", zone_type  =  ZoneTypes.AIRBASE, airbase_name  =  Airbases.Caucasus.Beslan}),

ZoneHandler:new({name  =  "MOZDOK", zone_type  =  ZoneTypes.AIRBASE, airbase_name  =  Airbases.Caucasus.Mozdok}),

ZoneHandler:new({name  =  "ALPHA"}),

ZoneHandler:new({name  =  "JOKER"}),

ZoneHandler:new({name  =  "EDISA"}),

ZoneHandler:new({name  =  "GVERKI"}),

), -- [Theaters.CAUCASUS]

[Theatres.SYRIA] =  passUnknown(

ZoneHandler:new({name  =  "KHALKHALAH", zone_type  =  ZoneTypes.AIRBASE, airbase_name  =  Airbases.Syria.Khalkhalah}),

ZoneHandler:new({name  =  "JABAB"}),

ZoneHandler:new({name  =  "ALPHA"}),

ZoneHandler:new({name  =  "BURAQ"}),

ZoneHandler:new({name  =  "CHARLIE"}),
)}

```