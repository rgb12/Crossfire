# Select Era(s)

Available eras are:
- Modern (1989 -)
- Late Cold War (1969 - 1989)
- Early Cold War (1947 - 1969)
- WW2 (- 1947)

This only requires a simple config file change.

### #1 Backup your mission

Before changing the era, back up your current mission in  `%USERPROFILE%\Saved Games\DCS\Missions\Saves`.
You can copy the whole mission folder or just `mission.json`, which holds all of the mission data.

Changing the era alters the mission content (zones, units, stocks), so the mission must be restarted from scratch with the new era for the change to apply. Changing the era mid-campaign without doing so will break the mission.

### #2 Change the era inside the config

Open `config.json`

Find the following section:
```json
 "era_system": {
          .....
        },
```
The setting that changes era is `eras_selected`.


For Modern set the following:
```json
"eras_selected": [
                "Modern"
            ],
```

For Late Cold War set the following:
```json
"eras_selected": [
                "Late Cold War"
            ],
```
For Early Cold War set the following:
```json
"eras_selected": [
                "Early Cold War"
            ],
```
For WW2 set the following:
```json
"eras_selected": [
                "WW2"
            ],
```


You can combine multiple eras. For example Early and Late Cold War:
```json
"eras_selected": [
                "Early Cold War",
                "Late Cold War"
            ],
```

**Save the config file**

### #3 Launch the mission


