# Crossfire

Crossfire mission and documentation is available from the user files:

- Caucasus — https://files.digitalcombatsimulator.com/en/files/3347986/
- Syria — https://files.digitalcombatsimulator.com/en/files/3349303/

If you find value in this work and would like to contribute to its development, please consider supporting the project. Greatly appreciated; https://buymeacoffee.com/radientaero

# Contributing

*Contributions of any size are a huge help — thank you.*

Contributions can be made using pull requests.

## Repository layout

```
src/
  active-scripts/    Modules that make up the mission
  unused-scripts/    
  release-scripts/   Compiled per-era output (git-ignored)
  mist_4_5_126_modified.lua   Modified MIST
tools/               Release scripts and config wizard
assets/              Sound files, images, ATIS audio
briefing/            Per-theatre briefings
docs/                Release checklist and notes
```

## Environment setup

In the mission editor after uploading a script, if changes are made to this script the mission will still use the old version. Uploading the script again is necessary to take into account these changes. To get around this a debug script loads files directly and simply restarting the mission will apply the changes; very useful for development.

Copy the `tools/debug_script.lua.example` file and rename it to `tools/debug_script.lua`. 
Ensure that you have the right path inside the file.
Head into the DCS mission editor, inside the triggers menu (three large columns), select the first row and replace the `crossfire_.lua` script with this debug script

MIST should be loaded by default.

## Lua definitions (optional)

For autocomplete and error checking in VS Code, I recommend https://github.com/omltcat/dcs-lua-definitions

## Guidelines

- Edit only the modules under `src/active-scripts/`
- Adding a module requires registering it in
  [`tools/insertion_order.py`](tools/insertion_order.py) and `debug_script.lua`
- Reuse existing helper functions where you can
- Avoid tight loops with short refresh intervals
- New features should be performance-aware, avoid hundreds of units and other ways scripting could affect performance
- Add config options if possible
- MIST is modified, DBs and some other functions will not work

## Reporting issues

Report it in the [discord server](https://discord.gg/QgRRqwNegE) or open an issue in the issues section. Include the `dcs.log` if you can.
