-- Globals.lua: saved variables, constants and option defaults

local addonName, ns = ...

RECIPERADAR_VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

-- bump this when the saved variable layout changes (see RecipeRadar_Globals_Init)
local DB_VERSION = 3

RECIPERADAR_VENDORS_DISPLAYED = 8
RECIPERADAR_VENDOR_HEIGHT = 16
RECIPERADAR_VENDOR_OFFSET = 20
RECIPERADAR_IMAGE_ROOT = "Interface\\AddOns\\RecipeRadar\\Images\\"

BINDING_HEADER_RECIPERADAR_HEADER = RRS("Recipe Radar")
BINDING_NAME_RECIPERADAR_TOGGLE = RRS("Toggle Recipe Radar")

-- SavedVariablesPerCharacter defaults (replaced by saved data after ADDON_LOADED)
RecipeRadar_Options = { }

RecipeRadar_Filters = {
   Teams = { },
   Professions = { },
   RealmAvails = { },
   PersonAvails = { },
}

RecipeRadar_Colors = {

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

RecipeRadar_Continents = {

   [0] = RRS("Instances"),
   [1] = RRS("Kalimdor"),
   [2] = RRS("Eastern Kingdoms"),

}

RecipeRadar_Teams = {

   ["Alliance"] = {
      Name = FACTION_ALLIANCE,
      Color = RecipeRadar_Colors.Alliance,
   },
   ["Horde"] = {
      Name = FACTION_HORDE,
      Color = RecipeRadar_Colors.Horde,
   },
   ["Neutral"] = {
      Name = RRS("Neutral"),
      Color = RecipeRadar_Colors.Neutral,
   },

}

local function Prof(name, icon)
   return { Name = RRS(name), Icon = RECIPERADAR_IMAGE_ROOT .. "Icons\\" .. icon }
end

RecipeRadar_Professions = {
   [RRS("Alchemy")]        = Prof("Alchemy", "Alchemy"),
   [RRS("Blacksmithing")]  = Prof("Blacksmithing", "Blacksmithing"),
   [RRS("Cooking")]        = Prof("Cooking", "Cooking"),
   [RRS("Enchanting")]     = Prof("Enchanting", "Enchanting"),
   [RRS("Engineering")]    = Prof("Engineering", "Engineering"),
   [RRS("First Aid")]      = Prof("First Aid", "First-Aid"),
   [RRS("Fishing")]        = Prof("Fishing", "Fishing"),
   [RRS("Leatherworking")] = Prof("Leatherworking", "Leatherworking"),
   [RRS("Tailoring")]      = Prof("Tailoring", "Tailoring"),
}

-- Specialty name -> parent profession.
RecipeRadar_Specialties = {
   [RRS("Gnomish Engineer")] = RRS("Engineering"),
   [RRS("Goblin Engineer")] = RRS("Engineering"),
   [RRS("Tribal Leatherworking")] = RRS("Leatherworking"),
   [RRS("Elemental Leatherworking")] = RRS("Leatherworking"),
   [RRS("Dragonscale Leatherworking")] = RRS("Leatherworking"),
   [RRS("Armorsmith")] = RRS("Blacksmithing"),
   [RRS("Weaponsmith")] = RRS("Blacksmithing"),
   [RRS("Master Axesmith")] = RRS("Blacksmithing"),
   [RRS("Master Swordsmith")] = RRS("Blacksmithing"),
   [RRS("Master Hammersmith")] = RRS("Blacksmithing"),
}

-- Specialty name -> spell ID of the specialization spell (vanilla IDs).
-- Checked with C_SpellBook.IsSpellKnown instead of scanning the spellbook.
ns.SpecialtySpells = {
   [RRS("Gnomish Engineer")] = 20219,
   [RRS("Goblin Engineer")] = 20222,
   [RRS("Dragonscale Leatherworking")] = 10656,
   [RRS("Elemental Leatherworking")] = 10658,
   [RRS("Tribal Leatherworking")] = 10660,
   [RRS("Armorsmith")] = 9788,
   [RRS("Weaponsmith")] = 9787,
   [RRS("Master Axesmith")] = 17041,
   [RRS("Master Swordsmith")] = 17039,
   [RRS("Master Hammersmith")] = 17040,
}

RecipeRadar_Factions = {
   RRS("Argent Dawn"),
   RRS("Cenarion Circle"),
   RRS("Thorium Brotherhood"),
   RRS("Timbermaw Hold"),
   RRS("Zandalar Tribe"),
}

RecipeRadar_Availabilities = {

   ["LearnableByPlayer"] = {
      Text = RRS("Available Now (Player)"),
      Tooltip = { Group = 1, Heading = RRS("Available For:") },
      DropDown = { POrder = 1, ROrder = 1 },
      Color = RecipeRadar_Colors.LearnableByPlayer,
   },
   ["LearnableByAlt"] = {
      Text = RRS("Available Now (Alts)"),
      Tooltip = { Group = 1, Heading = RRS("Available For:") },
      DropDown = { POrder = nil, ROrder = 2 },
      Color = RecipeRadar_Colors.LearnableByAlt,
   },
   ["ProspectForPlayer"] = {
      Text = RRS("Future Prospect (Player)"),
      Tooltip = { Group = 2, Heading = RRS("Future Prospect For:") },
      DropDown = { POrder = 2, ROrder = 3 },
      Color = RecipeRadar_Colors.ProspectForPlayer,
   },
   ["ProspectForAlt"] = {
      Text = RRS("Future Prospect (Alts)"),
      Tooltip = { Group = 2, Heading = RRS("Future Prospect For:") },
      DropDown = { POrder = nil, ROrder = 4 },
      Color = RecipeRadar_Colors.ProspectForAlt,
   },
   ["KnownByPlayer"] = {
      Text = RRS("Already Known (Player)"),
      Tooltip = { Group = 3, Heading = RRS("Already Known By:") },
      DropDown = { POrder = 3, ROrder = 5 },
      Color = RecipeRadar_Colors.KnownByPlayer,
   },
   ["KnownByAlt"] = {
      Text = RRS("Already Known (Alts)"),
      Tooltip = { Group = 3, Heading = RRS("Already Known By:") },
      DropDown = { POrder = nil, ROrder = 6 },
      Color = RecipeRadar_Colors.KnownByAlt,
   },
   ["NotApplicable"] = {
      Text = RRS("Inapplicable Professions"),
      Tooltip = { Group = 0 },  -- do not show in tooltip
      DropDown = { POrder = 4, ROrder = 7 },
      Color = RecipeRadar_Colors.NotApplicable,
   },

}

-----------------------------------------------------------------------------
-- Saved variable initialization and migration
-----------------------------------------------------------------------------

local function SetDefault(t, key, value)
   if (t[key] == nil) then t[key] = value end
end

-- Called once on ADDON_LOADED, after the saved variables are available.
function RecipeRadar_Globals_Init()

   if (type(RecipeRadar_Options) ~= "table") then RecipeRadar_Options = { } end
   if (type(RecipeRadar_Filters) ~= "table") then RecipeRadar_Filters = { } end
   local opts, filters = RecipeRadar_Options, RecipeRadar_Filters

   for _, key in ipairs({ "Teams", "Professions", "RealmAvails", "PersonAvails" }) do
      if (type(filters[key]) ~= "table") then filters[key] = { } end
   end

   -- migration from the 1.x layout (string Version compare, other data sets)
   if ((opts.dbVersion or 1) < DB_VERSION) then
      for prof in pairs(filters.Professions) do
         if (not RecipeRadar_Professions[prof]) then
            filters.Professions[prof] = nil
         end
      end
      if (opts.CurrentRegion and not RecipeRadar_RegionData[opts.CurrentRegion]) then
         opts.CurrentRegion = nil
      end
      opts.PositionDebug = nil
      opts.dbVersion = DB_VERSION
   end
   opts.Version = RECIPERADAR_VERSION

   SetDefault(opts, "MinimapButtonPosition", 256)
   SetDefault(opts, "ShowMinimapButton", true)
   SetDefault(opts, "RealmAvailability", true)
   SetDefault(opts, "Locked", false)
   SetDefault(opts, "AutoSelectRegion", true)
   SetDefault(opts, "AutoMapVendors", false)
   SetDefault(opts, "HideSeasonal", false)
   SetDefault(opts, "ActiveTab", 1)
   SetDefault(opts, "UseQuestie", true)

   if (not RecipeRadar_IsProfession(opts.CurrentProfession)) then
      opts.CurrentProfession = RRS("Cooking")
   end

end
