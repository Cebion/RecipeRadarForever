# CurseForge project page

Text and settings to paste into the CurseForge project form
(https://authors.curseforge.com/#/projects/create/choose-game). Not packaged.

## Form fields

| Field | Value |
|---|---|
| Game | World of Warcraft |
| Class | Addons |
| Name | Recipe Radar Forever |
| Summary | Shows every vendor-sold profession recipe, where to buy it, what it costs and which of your characters still needs it. |
| Main category | Professions |
| Additional categories | Map & Minimap, Auction & Economy |
| License | GNU General Public License version 3 (GPLv3) |
| Logo | `.github/media/logo.png` (400x400 PNG) |
| Source | https://github.com/Cebion/RecipeRadarForever |
| Issues | https://github.com/Cebion/RecipeRadarForever/issues |

## Description

Recipe Radar Forever lists every profession recipe sold by a vendor in WoW Forever.
For each recipe it shows who sells it, where the vendor stands, what it costs, and
which of your characters can learn it. Use it to find the vendor recipes you are
still missing, without checking every vendor by hand.

**What it does**

- Covers all 768 vendor recipes for Alchemy, Blacksmithing, Cooking, Enchanting,
  Engineering, First Aid, Fishing, Leatherworking and Tailoring, including the
  WoW Forever recipes: Merchant's Favor recipes and certifications from the trade
  camps, the Skyforged quartermasters, and the vendors in Mount Hyjal, Riverglades
  and Zephras Isle.
- Shows costs in gold, Merchant's Favor or token items.
- **Radar tab**: every recipe vendor in a zone, with a zone map.
  **Recipes tab**: every vendor recipe of one profession and all the places that sell it.
- Search by recipe, vendor or zone name.
- Filters by faction, profession and availability: learnable now, learnable later,
  or already known, for every character on your realm.
- Shift-click a vendor to mark it on the world map and minimap. Uses TomTom if it is
  installed, otherwise the game's own map pin and waypoint.
- Works on its own. If QuestieDB is installed, it also picks up newer vendor data
  from it automatically.

**Commands**

- `/rrf`: open or close the window (also from the minimap button, the AddOn
  compartment or a key binding)
- `/rrf options`: options
- `/rrf report`: report a bug or wrong vendor data

**Credits**

Recipe Radar Forever is a port of the 2006 addon Recipe Radar by Jay Miller,
rewritten for the WoW Forever addon API with a new recipe database. Changes from
the original: WoW Forever recipes and vendors, Merchant's Favor costs, zone maps
from the game's map art, search, QuestieDB import, and a modern options and map
pin system.

**Bugs and wrong data**

Please report them on GitHub, ideally with the details from `/rrf report`:
https://github.com/Cebion/RecipeRadarForever/issues

Source code: https://github.com/Cebion/RecipeRadarForever

## First file

- Upload the zip from the GitHub release (or let the release workflow upload it).
- Game version: 1.60.1 (WoW Forever). Add the Midnight retail version too, since the
  TOC also lists 120105.
- Release type: Release. Changelog: the 2.2.0 section of `CHANGELOG.md`.
