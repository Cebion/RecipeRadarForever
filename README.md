# Recipe Radar for WoW Forever

Recipe Radar is a World of Warcraft addon that helps you find recipes. It knows
which vendors sell recipes in each zone or for each profession, tracks which
recipes your characters already know, and can mark vendors on the map.

This is a port of **Recipe Radar** by **Jay Miller** to **WoW Forever**
(client 1.60.x, the Midnight addon API). It also loads on Midnight retail.

## Features

- **Radar tab**: every recipe vendor in the selected zone, with their recipes.
- **Recipes tab**: every vendor recipe for one profession, with all locations.
- Filters by faction, profession and availability (learnable now, future
  prospect, already known, other professions).
- Availability across all characters on the realm, including your alts'
  skill ranks, reputation and specializations.
- Vendor locations shown on a zone map inside the window. Shift-click a vendor
  to mark it on the world map and minimap.
- Optional: hide seasonal vendors and auto-map vendors with learnable recipes.

## Installation

Copy or link the `RecipeRadar` folder into
`World of Warcraft\_forever_\Interface\AddOns\`.

**Map pins:** if [TomTom](https://www.curseforge.com/wow/addons/tomtom) is
installed, Recipe Radar uses it for minimap and world map pins plus the arrow.
Without TomTom, mapped vendors show on the world map and the most recently mapped
vendor gets the built-in Blizzard waypoint.

## Usage

| Command | Action |
|---|---|
| `/rrdr` or `/reciperadar` | Toggle the window |
| `/rrdr options` | Options dialog |
| `/rrdr radar` | Print the vendors in your current zone to chat |
| `/rrdr debug skills [name]` | Show stored professions, specializations and reputation |
| `/rrdr debug scan` | Rescan skills, reputation and known recipes |
| `/rrdr debug maps` | Show which zones resolved to a game map |
| `/rrdr debug where` | Print your map position (for checking vendor coordinates) |
| `/rrdr debug clear [name]` | Forget stored data for one character or the realm |

You can also open the window from the minimap button, the AddOn compartment, or a
key binding (Key Bindings > AddOns > Recipe Radar). Right-click the minimap
button to open the options.

Log in once on each character so that your alts show up in the availability
tooltips.

## Credits

- Original addon and vendor database: Jay Miller.
- See `PORTING.md` for what changed in the WoW Forever port.
