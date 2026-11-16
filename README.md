<h1 align="center">Charger</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=hXi4Xns7GmI"><img src="https://img.youtube.com/vi/hXi4Xns7GmI/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin adds a fully dynamic charger system to Counter-Strike 1.6.
Chargers can be placed, managed and configured during gameplay with full runtime control over visibility, team access, spawn behavior and activation states.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove chargers during gameplay via an in-game menu
- Multiple charger types: Health, HEV, and Civilian Chargers with individual models and features
- Players interact with chargers by pressing E (+use) within a configurable distance range
- Configurable per charger: capacity, usage limit, rate, cooldown, refill delay, team restriction, and sound set
- Breakable and explosive chargers with custom health, overload-based break chance, and explosion stats
- Delayed and timed activation with random ranges for round-based gameplay
- Distinct Health and HEV sound sets, including charge, depletion, and flicker/metal-break sounds
- Noclip and intuitive ghost preview tracking for natural alignment with grounds and walls

## 📋 Requirements
- ReGameDLL
- AMX Mod X 1.10+

## 💬 Commands
- `say /charger` - Opens the charger menu.
- `say_team /charger` - Opens the charger menu.
- `charger_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# [Main Settings]
# SETTING_DEFAULT_MODEL           = Default charger model path
# SETTING_DEFAULT_GIB             = Default break gibs model path
# SETTING_DEFAULT_CLASS           = Default class (0 - Health Charger, 1 - HEV Charger, 2 - CIV Charger)
# SETTING_DEFAULT_FLAGS           = Default flags (a - Breakable, b - Explosive, c - Wear, d - Refill, e - Active Delay, f - Active Duration)
# SETTING_DEFAULT_TEAM            = Default team (0 - None, 1 - Terrorist, 2 - Counter-Terrorist, 3 - Both)
# SETTING_DEFAULT_SOUND           = Default sound set (0 - Health Sound, 1 - HEV Sound)
# SETTING_DEFAULT_MODE            = Default mode (0 - Health Mode, 1 - Armor Mode)
# SETTING_DEFAULT_CAPACITY        = Default initial amount of Health/Armor available
# SETTING_DEFAULT_LIMIT           = Default player usage limit
# SETTING_DEFAULT_RATE            = Default minimum and maximum amount of Health/Armor given per use
# SETTING_DEFAULT_REFILL          = Default minimum and maximum refill delay (requires flag d)
# SETTING_DEFAULT_COOLDOWN        = Default minimum and maximum delay between each use
# SETTING_DEFAULT_SPAWN_MODE      = Default spawn mode (0 - Never, 1 - Delayed, 2 - Round Start)
# SETTING_DEFAULT_SPAWN           = Default minimum and maximum spawn time
# SETTING_DEFAULT_SPAWN_CHANCE    = Default chance to spawn (0.0 - 1.0)
# SETTING_DEFAULT_ACTIVE_DELAY    = Default activation delay after round start (min - max, requires flag e)
# SETTING_DEFAULT_ACTIVE_DURATION = Default active state duration (min - max)
# SETTING_DEFAULT_ACTIVE_COOLDOWN = Default cooldown before reactivation (min - max)
# SETTING_DEFAULT_HEALTH          = Default charger health range (min - max)
# SETTING_DEFAULT_EXPLODE_DAMAGE  = Default explosion damage range (min - max)
# SETTING_DEFAULT_EXPLODE_RADIUS  = Default explosion radius range (min - max)
# SETTING_DEFAULT_BREAK_RATIO     = Default overload added per use (requires flag a)
# SETTING_DEFAULT_BREAK_THRESHOLD = Default overload value required before a break check
# SETTING_DEFAULT_BREAK_CHANCE    = Default chance to break once the threshold is reached
# Per-charger settings (defined under each [Charger Name] section):
# CHARGER_FLAGS        = a - Breakable, b - Explosive, c - Wear, d - Refill, e - Active Delay, f - Active Duration
# CHARGER_CLASS        = 0 - Health Charger, 1 - HEV Charger, 2 - CIV Charger
# CHARGER_TEAM         = 0 - None, 1 - Terrorist, 2 - Counter-Terrorist, 3 - Both
# CHARGER_SPAWN_MODE   = 0 - Never, 1 - Delayed, 2 - Round Start
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v1.1: Simplified BBox.
* v1.2: Manual rotation (no floor placement), improved readability.
* v1.3: Refills after a certain duration, used by a single player at a time, all charger sounds are emitted from charger entities.
* v1.4: Bug fixes, chargers can be placed against any surface, supports ROLL rotation.
* v1.5: Optimized code with fixed bugs, added activation delay after round start, chargers can break or explode from damage, charger might break or explode after a certain amount of uses when it starts flickering.
* v1.6: Improved charger placement logic for natural alignment with ground and walls.
* v2.0: Redesigned charger architecture for full dynamic control, runtime management of visibility, team and spawn settings.
* v2.1: Bug fixes and config improvements.
* v2.2: Added FLAG_ACTIVE_DURATION, improved round-start logic.
```

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=hXi4Xns7GmI)
