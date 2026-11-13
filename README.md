# Recipe Radar Forever

Recipe Radar Forever shows every profession recipe sold by a vendor in **WoW Forever**,
who sells it, where they stand, what it costs, and which of your characters can
learn it. Use it to see which vendor recipes you're still missing.

This is a port of the 2006 addon **Recipe Radar** by **Jay Miller** to WoW Forever
(client 1.60.x, the Midnight addon API). It also loads on Midnight retail.

It is not related to the CurseForge addon "RecipeRadar" by rakstar91. The two use
different folders, saved variables and slash commands, so they can be installed side
by side.

## What's in it

- **768 vendor recipes** across Alchemy, Blacksmithing, Cooking, Enchanting,
  Engineering, First Aid, Fishing, Leatherworking and Tailoring:
  - the original vanilla vendor recipes,
  - **462 Forever-new recipes**, including all **320 Merchant's Favor** recipes and
    certifications from the trade camps (Azeroth Commerce Authority in Redridge,
    Durotar Supply and Logistics in the Barrens), the Skyforged quartermasters,
    Mount Hyjal, Riverglades and Zephras Isle vendors, and new city recipe vendors.
- Costs in gold, **Merchant's Favor** or token items.
- **Radar tab**: every recipe vendor in a zone. **Recipes tab**: every vendor recipe
  of one profession with all its locations.
- Filters by faction, profession and availability (learnable now, future prospect,
  already known), across all characters on the realm.
- Zone maps drawn from the game's own map art, so the new Forever zones work too.
- Shift-click a vendor to mark it on the world map and minimap (TomTom if
  installed, otherwise world map pins plus the Blizzard waypoint).

## Always up to date with Questie

The addon works standalone with its built-in data. If **Questie** (QuestieDB) is
installed, Recipe Radar also reads its current vendor data after login and adds
anything newer, such as recipes or vendors added in a patch. `/rrdr questie off`
turns this off.

Things the data can't know yet fill themselves in as you play:
- **Required skill** for new recipes is read from the item tooltip.
- **Prices** are recorded whenever you open the vendor's merchant window.

## Installation

Copy or link the `RecipeRadarForever` folder into
`World of Warcraft\_forever_\Interface\AddOns\`.

## Usage

| Command | Action |
|---|---|
| `/rrdr` | Toggle the window |
| `/rrdr options` | Options dialog |
| `/rrdr radar` | Print the vendors in your current zone to chat |
| `/rrdr verify` | Ask the server about every recipe item and fill in required skills |
| `/rrdr questie [on\|off]` | QuestieDB import status, or turn it on/off |
| `/rrdr debug skills [name]` | Stored professions, specializations and reputation |
| `/rrdr debug scan` | Rescan skills, reputation and known recipes |
| `/rrdr debug maps` | Check that every zone resolves to a game map |
| `/rrdr debug where` | Print your map position (for checking vendor coordinates) |
| `/rrdr debug clear [name]` | Forget stored data for one character or the realm |

The window also opens from the minimap button, the AddOn compartment, or a key
binding (Key Bindings > AddOns > Recipe Radar Forever). Right-click the minimap button
for the options.

## Updating the data

`tools/build_data.py` regenerates `RegionData.lua` and `RecipeData.lua` from an
installed QuestieDB and AllTheThings:

```
pip install cbor2
python tools/build_data.py --questiedb ".../AddOns/QuestieDB/QuestieDB_Forever.toc" \
    --att ".../AddOns/AllTheThings/db/Camelot/Categories"
```

## License and credits

GPLv3, see `LICENSE.md`. Original addon and vanilla vendor database by Jay Miller.
Forever vendor data from QuestieDB and AllTheThings; see `NOTICE.md`.
