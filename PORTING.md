# Porting notes: Recipe Radar 1.x (WoW 1.12) to WoW Forever

Target: WoW Forever 1.60.x (`## Interface: 16001`), which runs the Midnight 12.1.5
Mainline addon API. The TOC also lists `120105` so the addon loads on Midnight.

Kept unchanged: addon name and folder (`RecipeRadar`), SavedVariables
(`RecipeRadar_SkillDB`, `RecipeRadar_NameCache`, `RecipeRadar_Options`,
`RecipeRadar_Filters`), slash commands (`/rrdr`, `/reciperadar`), key binding,
the window layout and art.

## Data

- Vendor and recipe database: the original vanilla data set (Jay Miller, v1.16
  data): 217 vendors and 305 recipes across 9 professions.
- Coordinates for 152 vendors were updated from a later, more accurate revision,
  but only in zones whose map framing (MapScale) matched the original. Stormwind
  City and Stonetalon Mountains kept the original coordinates.
- Instance maps for Gnomeregan, Blackrock Depths and Dire Maul were added, along
  with coordinates for their 4 vendors.
- `MapScale`/`MapOffset` in RegionData.lua are no longer used (C_Map does the
  conversion). They are left in so the data file stays easy to diff.
- NameMap.lua (craft window name to item name map) was removed. Known recipes
  are now matched by item name from the tooltip scan.

## What changed in the code

| Area | 1.x | Forever |
|---|---|---|
| Lua | Lua 5.0 (`this`, `arg1`, `for k,v in t`, `table.getn`, `table.foreach`, `getglobal`, `mod`) | Lua 5.1, handler parameters, `ipairs`/`pairs`, `#`, `_G[...]`, `%`. `local addonName, ns = ...` in every file |
| Load | `VARIABLES_LOADED` | `ADDON_LOADED` (own addon) + `PLAYER_LOGIN` |
| Skill ranks | `CHAT_MSG_SKILL` parsing, opening CharacterFrame and scraping `GetSkillLineInfo` | `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` on `SKILL_LINES_CHANGED` |
| Known recipes | Craft/trade window scan (`GetTradeSkillInfo`, `GetCraftInfo`), `CHAT_MSG_SYSTEM` parsing, hidden GameTooltip scan | `C_TooltipInfo.GetItemByID` "Already known" check, on `NEW_RECIPE_LEARNED`, `LEARNED_SPELL_IN_SKILL_LINE`, `TRADE_SKILL_SHOW`, login and window open (throttled) |
| Specializations | Opening the spellbook and calling `CastSpell` on every profession (protected) | `C_SpellBook.IsSpellKnown(spellID)` with a table of specialization spell IDs (`ns.SpecialtySpells` in Globals.lua) |
| Reputation | Opening ReputationFrame and scraping `GetFactionInfo` | `C_Reputation.GetNumFactions/GetFactionDataByIndex` on `UPDATE_FACTION` |
| Item info | `GetItemInfo`, "Uncached Recipe" disconnect warning | `C_Item.GetItemInfo`, `Item:ContinueOnItemLoad` loads missing items and redraws, `C_Item.GetItemIconByID` for the icon |
| Zone lookup | `GetMapZones`, `GetMapContinents`, `RegionNameToID` | Region index built from `C_Map.GetMapChildrenInfo` under the player's world map, matched by zone name |
| Minimap pins | 20 hand-placed buttons, MapNotes scale tables, indoor zoom CVar hack, `GetPlayerMapPosition` polling every 0.1 s | TomTom waypoints if TomTom is loaded, otherwise the Blizzard user waypoint (`C_Map.SetUserWaypoint` + supertrack) |
| World map pins | 20 buttons on `WorldMapDetailFrame`, `WORLD_MAP_UPDATE`, replaced `WorldMapFrame` OnHide | TomTom, or a `MapCanvasDataProviderMixin` provider with a pin template (`RecipeRadarWorldMapPinTemplate`). Pins also show on continent and neighbouring maps via world coordinates |
| Dropdowns | `UIDropDownMenu*` | `WowStyle1DropdownTemplate` + `SetupMenu` (checkbox/radio menus) |
| Context menus | `UIDropDownMenu` "MENU" frames | `MenuUtil.CreateContextMenu` |
| Options | XML frame with `<Backdrop>`, `OptionsCheckButtonTemplate`, `OptionsSliderTemplate` | Lua frame with `BackdropTemplate`, `UICheckButtonTemplate`, `UISliderTemplateWithLabels`, plus a Settings > AddOns page with buttons that open it |
| Availability tooltip | `GameTooltipTemplate` + `SetBackdropColor` | `TooltipBackdropTemplate` frame, 24 lines (the old code allowed 24 but defined only 16) |
| List buttons | `NormalText`/`HighlightText` XML elements (removed from the schema), `SetHighlightTextColor` | `ButtonText` + `NormalFont`; the hover tint is applied in Lua so shared font objects are never changed |
| Sounds | `PlaySound("igMainMenuOption...")` | `PlaySound(SOUNDKIT.*)` |
| Chat link | `ChatFrameEditBox:Insert` | `ChatFrameUtil.InsertLink` with `IsModifiedClick("CHATLINK")` |
| Window | `ShowUIPanel`/`HideUIPanel` | plain `Show`/`Hide`, still closes with Escape (`UISpecialFrames`) |
| Minimap button | shape checks for third-party minimap addons, permanent `OnUpdate` | Round placement only. `OnUpdate` exists only while the button flashes. Right-click opens the options |
| Saved data | String compare of `Options.Version` | `RecipeRadar_Options.dbVersion = 2` with a migration that drops unknown professions and regions from old saves |

New: `/rrdr options`, `/rrdr debug maps`, `/rrdr debug scan`, `/rrdr debug where`,
AddOn compartment entry, `## IconTexture`.

## Removed and why

- **Spellbook, CharacterFrame and ReputationFrame scraping, `CastSpell` on professions**:
  protected or taint-prone and no longer needed; replaced by the APIs above.
- **Chat message parsing** (`CHAT_MSG_SKILL`, `CHAT_MSG_SYSTEM`): replaced by
  events. Chat payloads can also be secret inside instances on Forever.
- **MapNotes-style minimap math and the world map button overlay**: the 1.12 map
  API is gone. TomTom or the Blizzard waypoint replaces it.
- **Third-party hooks** (EnhTooltip, RecipeBook, minimap shape addons):
  those addons don't exist on Forever.
- **`/rrdr debug vendor`**: replaced by `/rrdr debug where`.
- **Professions, regions and vendors that are not in the vanilla game** were
  dropped from the data. Old saved data for them is removed by the migration.

## Globals

Besides SavedVariables, slash and binding entries, the addon keeps its original
`RecipeRadar_*` function names and the `RECIPERADAR_*` constants. They are
referenced from XML handlers and across files, and they all use the addon's own
prefix. `RRS` (the localization lookup) is unchanged. `RecipeRadarWorldMapPinMixin`
is global because the XML pin template names it. Nothing else is added.

## Combat and secret values

The addon reads no combat, unit, aura or chat data. Nothing touches secure frames.
Map waypoints and window show/hide are not protected.

## Needs in-game verification

1. `/dump select(4, GetBuildInfo())`: confirm 16001.
2. `/rrdr debug maps`: every vendor zone resolves to a uiMapID. The Kalimdor and
   Eastern Kingdoms continent names must match `RRS("Kalimdor")` and
   `RRS("Eastern Kingdoms")` on non-English clients.
3. Vendor coordinates on Forever's zone maps: stand on a few vendors, run
   `/rrdr debug where` and compare with the in-window map and the pin. Pay
   particular attention to Stormwind City and Stonetalon Mountains (original 2006 coordinates).
4. Specialization spell IDs in `ns.SpecialtySpells` (Globals.lua) with
   `/dump C_SpellBook.IsSpellKnown(9788)` etc. on a specialized character.
5. Skill names returned by `C_SkillInfo.GetSkillLineInfo(i).name` match the
   profession names (`/rrdr debug skills`).
6. Reputation standings for Argent Dawn, Cenarion Circle, Thorium Brotherhood,
   Timbermaw Hold and Zandalar Tribe appear in `/rrdr debug skills`.
7. "Already known" detection: learn a vendor recipe, and within a second it moves
   from "Available Now" to "Already Known".
8. TomTom (if used): `TomTom:AddWaypoint(mapID, x, y, opts)` works on Forever and
   pins show on the minimap and world map. Without TomTom: world map pin plus the Blizzard waypoint.
9. Dropdowns: the checkbox menus keep open while you click, filters apply, and
   the recipes tab radio list switches profession.
10. Seasonal vendors hide or show with the option.
11. Old saved variables from 1.x load without errors (the dbVersion migration).
