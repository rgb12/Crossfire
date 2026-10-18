# Seed

A seed is a number that determines which scenario will be selected and what zone types each zone will be assigned.

```bash
# List all scenarios
cd tools
python seed_finder.py --list
```
Example:
```
CAUCASUS:
  1. Georgia Liberation
  2. High Caucasus Conflict
  3. Eastbound
  4. Caucasus at War
  5. Sochi Liberation
SYRIA:
  1. Syrian Resolve
  2. North Syria
  3. South Syria

CWGERMANY:
  1. Mahlwinkel - WUNSTORF
```

If you want the "North Syria" scenario for the Syria terrain, the command below will give possible seed(s) for this scenario:

```bash
cd tools
python seed_finder.py SRYIA 2
```

Output:
```
Target: SYRIA[2] = "North Syria" (of 4 eligible scenarios)
Matching seeds: 36, 37, 38, 39, 40
```