-- Globals.lua: saved variables, constants and option defaults

local addonName, ns = ...

RRF_VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

-- bump this when the saved variable layout changes (see RRF_Globals_Init)
local DB_VERSION = 3

RRF_VENDORS_DISPLAYED = 8
RRF_VENDOR_HEIGHT = 16
RRF_VENDOR_OFFSET = 20
RRF_IMAGE_ROOT = "Interface\\AddOns\\RecipeRadarForever\\Images\\"

BINDING_HEADER_RECIPERADARFOREVER_HEADER = RRF_S("Recipe Radar Forever")
BINDING_NAME_RECIPERADARFOREVER_TOGGLE = RRF_S("Toggle Recipe Radar")

-- SavedVariablesPerCharacter defaults (replaced by saved data after ADDON_LOADED)
RecipeRadarForever_Options = { }

RecipeRadarForever_Filters = {
   Teams = { },
   Professions = { },
   RealmAvails = { },
   PersonAvails = { },
}

RRF_Colors = {

   MainFont           = { r = 1.0, g = 0.75, b = 0.0 },
   Alliance           = { r = 0.5, g = 0.625, b = 1.0 },
   Horde              = { r = 1.0, g = 0.125, b = 0.25 },
   Neutral            = { r = 1.0, g = 0.82, b = 0.0 },
   LightGray          = { r = 0.9, g = 0.9, b = 0.9 },
   UncachedRecipe     = { r = 0.75, g = 0.75, b = 0.75 },
   DisabledGray       = { r = 0.5, g = 0.5, b = 0.5 },

   TooltipHeading     = { r = 0.9, g = 0.9, b = 0.9 },
   TooltipWarning     = { r = 1.0, g = 0.3, b = 0.3 },

   -- realm-wide availability tooltip/indicator colors
   LearnableByPlayer  = { r = 0.0, g = 1.0, b = 0.0 },
   LearnableByAlt     = { r = 0.0, g = 0.8, b = 0.0 },
   ProspectForPlayer  = { r = 1.0, g = 0.2, b = 0.2 },
   ProspectForAlt     = { r = 0.8, g = 0.2, b = 0.2 },
   KnownByPlayer      = { r = 0.7, g = 0.7, b = 0.7 },
   KnownByAlt         = { r = 0.5, g = 0.5, b = 0.5 },
   NotApplicable      = { r = 0.5, g = 0.5, b = 0.5 },

   -- amount that colors will be phased to highlight the text
   Highlight          = 0.2,

}

RRF_Continents = {

   [0] = RRF_S("Instances"),
   [1] = RRF_S("Kalimdor"),
   [2] = RRF_S("Eastern Kingdoms"),

}

RRF_Teams = {

   ["Alliance"] = {
      Name = FACTION_ALLIANCE,
      Color = RRF_Colors.Alliance,
   },
   ["Horde"] = {
      Name = FACTION_HORDE,
      Color = RRF_Colors.Horde,
   },
   ["Neutral"] = {
      Name = RRF_S("Neutral"),
      Color = RRF_Colors.Neutral,
   },

}

local function Prof(name, icon)
   return { Name = RRF_S(name), Icon = RRF_IMAGE_ROOT .. "Icons\\" .. icon }
end

RRF_Professions = {
   [RRF_S("Alchemy")]        = Prof("Alchemy", "Alchemy"),
   [RRF_S("Blacksmithing")]  = Prof("Blacksmithing", "Blacksmithing"),
   [RRF_S("Cooking")]        = Prof("Cooking", "Cooking"),
   [RRF_S("Enchanting")]     = Prof("Enchanting", "Enchanting"),
   [RRF_S("Engineering")]    = Prof("Engineering", "Engineering"),
   [RRF_S("First Aid")]      = Prof("First Aid", "First-Aid"),
   [RRF_S("Fishing")]        = Prof("Fishing", "Fishing"),
   [RRF_S("Leatherworking")] = Prof("Leatherworking", "Leatherworking"),
   [RRF_S("Tailoring")]      = Prof("Tailoring", "Tailoring"),
}

-- Specialty name -> parent profession.
RRF_Specialties = {
   [RRF_S("Gnomish Engineer")] = RRF_S("Engineering"),
   [RRF_S("Goblin Engineer")] = RRF_S("Engineering"),
   [RRF_S("Tribal Leatherworking")] = RRF_S("Leatherworking"),
   [RRF_S("Elemental Leatherworking")] = RRF_S("Leatherworking"),
   [RRF_S("Dragonscale Leatherworking")] = RRF_S("Leatherworking"),
   [RRF_S("Armorsmith")] = RRF_S("Blacksmithing"),
   [RRF_S("Weaponsmith")] = RRF_S("Blacksmithing"),
   [RRF_S("Master Axesmith")] = RRF_S("Blacksmithing"),
   [RRF_S("Master Swordsmith")] = RRF_S("Blacksmithing"),
   [RRF_S("Master Hammersmith")] = RRF_S("Blacksmithing"),
}

-- Specialty name -> spell ID of the specialization spell (vanilla IDs).
-- Checked with C_SpellBook.IsSpellKnown instead of scanning the spellbook.
ns.SpecialtySpells = {
   [RRF_S("Gnomish Engineer")] = 20219,
   [RRF_S("Goblin Engineer")] = 20222,
   [RRF_S("Dragonscale Leatherworking")] = 10656,
   [RRF_S("Elemental Leatherworking")] = 10658,
   [RRF_S("Tribal Leatherworking")] = 10660,
   [RRF_S("Armorsmith")] = 9788,
   [RRF_S("Weaponsmith")] = 9787,
   [RRF_S("Master Axesmith")] = 17041,
   [RRF_S("Master Swordsmith")] = 17039,
   [RRF_S("Master Hammersmith")] = 17040,
}

RRF_Factions = {
   RRF_S("Argent Dawn"),
   RRF_S("Cenarion Circle"),
   RRF_S("Thorium Brotherhood"),
   RRF_S("Timbermaw Hold"),
   RRF_S("Zandalar Tribe"),
}

RRF_Availabilities = {

   ["LearnableByPlayer"] = {
      Text = RRF_S("Available Now (Player)"),
      Tooltip = { Group = 1, Heading = RRF_S("Available For:") },
      DropDown = { POrder = 1, ROrder = 1 },
      Color = RRF_Colors.LearnableByPlayer,
   },
   ["LearnableByAlt"] = {
      Text = RRF_S("Available Now (Alts)"),
      Tooltip = { Group = 1, Heading = RRF_S("Available For:") },
      DropDown = { POrder = nil, ROrder = 2 },
      Color = RRF_Colors.LearnableByAlt,
   },
   ["ProspectForPlayer"] = {
      Text = RRF_S("Future Prospect (Player)"),
      Tooltip = { Group = 2, Heading = RRF_S("Future Prospect For:") },
      DropDown = { POrder = 2, ROrder = 3 },
      Color = RRF_Colors.ProspectForPlayer,
   },
   ["ProspectForAlt"] = {
      Text = RRF_S("Future Prospect (Alts)"),
      Tooltip = { Group = 2, Heading = RRF_S("Future Prospect For:") },
      DropDown = { POrder = nil, ROrder = 4 },
      Color = RRF_Colors.ProspectForAlt,
   },
   ["KnownByPlayer"] = {
      Text = RRF_S("Already Known (Player)"),
      Tooltip = { Group = 3, Heading = RRF_S("Already Known By:") },
      DropDown = { POrder = 3, ROrder = 5 },
      Color = RRF_Colors.KnownByPlayer,
   },
   ["KnownByAlt"] = {
      Text = RRF_S("Already Known (Alts)"),
      Tooltip = { Group = 3, Heading = RRF_S("Already Known By:") },
      DropDown = { POrder = nil, ROrder = 6 },
      Color = RRF_Colors.KnownByAlt,
   },
   ["NotApplicable"] = {
      Text = RRF_S("Inapplicable Professions"),
      Tooltip = { Group = 0 },  -- do not show in tooltip
      DropDown = { POrder = 4, ROrder = 7 },
      Color = RRF_Colors.NotApplicable,
   },

}

-----------------------------------------------------------------------------
-- Saved variable initialization and migration
-----------------------------------------------------------------------------

local function SetDefault(t, key, value)
   if (t[key] == nil) then t[key] = value end
end

-- Called once on ADDON_LOADED, after the saved variables are available.
function RRF_Globals_Init()

   if (type(RecipeRadarForever_Options) ~= "table") then RecipeRadarForever_Options = { } end
   if (type(RecipeRadarForever_Filters) ~= "table") then RecipeRadarForever_Filters = { } end
   local opts, filters = RecipeRadarForever_Options, RecipeRadarForever_Filters

   for _, key in ipairs({ "Teams", "Professions", "RealmAvails", "PersonAvails" }) do
      if (type(filters[key]) ~= "table") then filters[key] = { } end
   end

   -- migration from the 1.x layout (string Version compare, other data sets)
   if ((opts.dbVersion or 1) < DB_VERSION) then
      for prof in pairs(filters.Professions) do
         if (not RRF_Professions[prof]) then
            filters.Professions[prof] = nil
         end
      end
      if (opts.CurrentRegion and not RRF_RegionData[opts.CurrentRegion]) then
         opts.CurrentRegion = nil
      end
      opts.PositionDebug = nil
      opts.dbVersion = DB_VERSION
   end
   opts.Version = RRF_VERSION

   SetDefault(opts, "MinimapButtonPosition", 256)
   SetDefault(opts, "ShowMinimapButton", true)
   SetDefault(opts, "RealmAvailability", true)
   SetDefault(opts, "Locked", false)
   SetDefault(opts, "AutoSelectRegion", true)
   SetDefault(opts, "AutoMapVendors", false)
   SetDefault(opts, "HideSeasonal", false)
   SetDefault(opts, "ActiveTab", 1)
   SetDefault(opts, "UseQuestie", true)

   if (not RRF_IsProfession(opts.CurrentProfession)) then
      opts.CurrentProfession = RRF_S("Cooking")
   end

end
