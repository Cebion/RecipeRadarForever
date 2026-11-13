-- RecipeRadar.lua: main event code and general utility functions

local addonName, ns = ...

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------

function RecipeRadar_OnLoad(self)

   tinsert(UISpecialFrames, "RecipeRadarFrame")

   SLASH_RecipeRadar1 = "/rrdr"
   SLASH_RecipeRadar2 = "/reciperadar"
   SlashCmdList["RecipeRadar"] = RecipeRadar_SlashHandler

   self:RegisterEvent("ADDON_LOADED")
   self:RegisterEvent("PLAYER_LOGIN")
   self:RegisterEvent("PLAYER_ENTERING_WORLD")
   self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
   self:RegisterEvent("SKILL_LINES_CHANGED")
   self:RegisterEvent("UPDATE_FACTION")
   self:RegisterEvent("NEW_RECIPE_LEARNED")
   self:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
   self:RegisterEvent("TRADE_SKILL_SHOW")

end

local function OnNewZone()

   local zone = GetRealZoneText()
   if (RecipeRadar_RegionHasLearnableRecipe(zone)) then
      RecipeRadar_MinimapButton_Flash()
   end
   if (RecipeRadar_Options.AutoSelectRegion) then
      RecipeRadar_NewRegion(zone)
   end

end

function RecipeRadar_OnEvent(self, event, ...)

   if (event == "ADDON_LOADED") then

      if (... ~= addonName) then return end
      self:UnregisterEvent("ADDON_LOADED")

      RecipeRadar_Globals_Init()
      RecipeRadar_SkillDB_Init()
      RecipeRadar_MinimapButton_Init()
      RecipeRadar_Availability_Init()
      RecipeRadar_Maps_Init()
      RecipeRadar_MainFrame_Init()
      RecipeRadar_DropDowns_Init()
      RecipeRadar_Options_RegisterSettings()

   elseif (event == "PLAYER_LOGIN") then

      if (RecipeRadar_Filters.Teams["Horde"] == nil) then
         -- first run of the addon on this character: hide the other faction
         local faction = UnitFactionGroup("player")
         if (faction == "Alliance" or faction == "Horde") then
            RecipeRadar_Filters.Teams[faction] = false
            RecipeRadar_Filters.Teams[RecipeRadar_GetOpposingFaction()] = true
         end
      end

      RecipeRadar_Maps_BuildRegionIndex()
      RecipeRadar_SkillDB_ScanAll()
      -- item data for the tooltip scan may still be loading right after login
      C_Timer.After(5, RecipeRadar_SkillDB_RequestKnownScan)
      RecipeRadar_SelectFirstRecipe()

   elseif (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") then

      OnNewZone()

   elseif (event == "SKILL_LINES_CHANGED") then

      RecipeRadar_SkillDB_ScanSkills()
      RecipeRadar_SkillDB_ScanSpecialties()
      RecipeRadar_RefreshIfShown()

   elseif (event == "UPDATE_FACTION") then

      RecipeRadar_SkillDB_ScanReputation()

   elseif (event == "NEW_RECIPE_LEARNED" or event == "LEARNED_SPELL_IN_SKILL_LINE"
         or event == "TRADE_SKILL_SHOW") then

      RecipeRadar_SkillDB_RequestKnownScan()

   end

end

function RecipeRadar_OnShow(self)

   PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)

end

function RecipeRadar_OnHide(self)

   PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
   self:StopMovingOrSizing()

end

-- Recomputes cached filters and redraws, but only if the window is open
-- (RecipeRadar_Frame_Show does the same work when it opens).
function RecipeRadar_RefreshIfShown()

   if (RecipeRadarFrame and RecipeRadarFrame:IsShown()) then
      RecipeRadar_InitVendorFilters()
      RecipeRadar_InitRecipeFilters()
      RecipeRadar_FrameUpdate()
   end

end

-----------------------------------------------------------------------------
-- Slash command
-----------------------------------------------------------------------------

function RecipeRadar_SlashHandler(msg)

   local cmd, sub, rest = string.match(msg or "", "^(%w*)%s*(%w*)%s*(.*)$")
   cmd = string.lower(cmd or "")

   if (cmd == "debug") then

      if (sub == "skills") then
         RecipeRadar_SkillDB_Print(rest)
      elseif (sub == "clear") then
         RecipeRadar_SkillDB_Clear(rest)
      elseif (sub == "maps") then
         RecipeRadar_Maps_PrintRegionIndex()
      elseif (sub == "scan") then
         RecipeRadar_SkillDB_ScanAll()
         RecipeRadar_SkillDB_ScanKnownRecipes()
         RecipeRadar_Print("Recipe Radar: rescanned skills, reputation and known recipes.")
      elseif (sub == "where") then
         -- stand on a vendor and compare with the database coordinates
         local zone = GetRealZoneText()
         local mapID = C_Map.GetBestMapForUnit("player")
         local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
         if (pos) then
            local x, y = pos:GetXY()
            RecipeRadar_Print(string.format("%s (uiMapID %d, index %s): x = %.3f, y = %.3f",
                  zone, mapID, tostring(RecipeRadar_Maps_GetRegionMapID(zone)), x, y))
         else
            RecipeRadar_Print(zone .. ": no map position here.")
         end
      else
         RecipeRadar_Print("/rrdr debug skills [name] | clear [name] | maps | scan | where")
      end
      return

   end

   if (cmd == "radar") then

      local region = RecipeRadar_RegionData[GetRealZoneText()]
      if (not region) then return end

      for _, vendor in ipairs(region.Vendors) do

         local coords = vendor.Coordinates and vendor.Coordinates[1]
         local where = ""
         if (coords) then
            where = string.format(" (%d, %d)", coords.x * 100, coords.y * 100)
         end
         RecipeRadar_Print(RecipeRadar_GetColoredTeamString(
               vendor.Team, vendor.Name) .. where .. ":")

         table.sort(vendor.Recipes, RecipeRadar_CompareSkills)
         for _, recipe in ipairs(vendor.Recipes) do
            RecipeRadar_Print("   " .. RecipeRadar_GetHyperlinkByID(recipe.ID) ..
                  ", " .. RecipeRadar_GetGSCString(recipe.Cost))
         end

      end
      return

   end

   if (cmd == "options" or cmd == "config") then
      RecipeRadar_OptionsFrame_Toggle()
      return
   end

   RecipeRadar_Toggle()

end

-----------------------------------------------------------------------------
-- Region helpers
-----------------------------------------------------------------------------

-- Function to be called on selecting a new region to initialize the
-- main frame and any active filters.
function RecipeRadar_NewRegion(region)

   if (not region or region == "") then return end

   RecipeRadar_Options.CurrentRegion = region
   RecipeRadar_Options.CurrentContinent = RecipeRadar_GetCurrentContinent()
   RecipeRadar_InitVendorFilters()
   RecipeRadar_SelectFirstRecipe()
   RecipeRadar_FrameUpdate()

end

-- Returns whether the given region contains at least one recipe that
-- is learnable by the player or (optionally) alts
function RecipeRadar_RegionHasLearnableRecipe(region_name)

   local region_data = RecipeRadar_RegionData[region_name]
   if (not region_data) then return false end

   for _, vendor in ipairs(region_data.Vendors) do
      for _, recipe in ipairs(vendor.Recipes) do
         if (RecipeRadar_Availability_IsLearnable(recipe)) then
            return true
         end
      end
   end

   return false

end

-- Given a table of recipes, returns the number of recipes that are
-- learnable by the player or (optionally) alts.
function RecipeRadar_CountLearnableRecipes(recipes)

   if (not recipes) then return 0 end

   local total = 0
   for _, recipe in ipairs(recipes) do
      if (RecipeRadar_Availability_IsLearnable(recipe)) then
         total = total + 1
      end
   end
   return total

end

-- Returns the index of the current region's continent (1 Kalimdor,
-- 2 Eastern Kingdoms), or 0 for instances and unknown zones.
function RecipeRadar_GetCurrentContinent()

   local name = RecipeRadar_Options.CurrentRegion
   local region = RecipeRadar_RegionData[name]
   if (region) then
      return region.Continent
   end
   return RecipeRadar_Maps_GetContinentIndex(name) or 0

end

-----------------------------------------------------------------------------
-- Item helpers
-----------------------------------------------------------------------------

-- Returns a string describing an item link from an item ID.
function RecipeRadar_GetHyperlinkByID(id)

   local name, link, color = RecipeRadar_GetSafeItemInfo(id)
   return RecipeRadar_GetHyperlinkByParts(name, link, color)

end

-- Returns a string describing an item link from link components.
function RecipeRadar_GetHyperlinkByParts(name, link, color)

   if (string.find(link, "^|c")) then
      return link  -- already a full hyperlink from C_Item.GetItemInfo
   end
   return string.format("%s|H%s|h[%s]|h|r", color, link, name)

end

local pendingItems = { }

-- Asks the client to load an item and redraws once it arrives.
local function RequestItem(id)

   if (pendingItems[id]) then return end
   pendingItems[id] = true

   local item = Item:CreateFromItemID(id)
   item:ContinueOnItemLoad(function()
      pendingItems[id] = nil
      local name = C_Item.GetItemInfo(id)
      if (name) then
         RecipeRadar_NameCache[id] = name
      end
      -- coalesce the burst of redraws when many items arrive together
      if (not ns.redrawQueued) then
         ns.redrawQueued = true
         C_Timer.After(0.5, function()
            ns.redrawQueued = false
            RecipeRadar_RefreshIfShown()
         end)
      end
   end)

end

-- Returns name, link, colorcode, r, g, b, texture, is_cached for an item.
-- Items that are not in the client cache yet are requested; until then a
-- placeholder (or the name seen in an earlier session) is returned.
function RecipeRadar_GetSafeItemInfo(id)

   if (type(RecipeRadar_NameCache) ~= "table") then RecipeRadar_NameCache = { } end

   local name, link, rarity, _, _, _, _, _, _, texture = C_Item.GetItemInfo(id)

   if (name == nil) then

      RequestItem(id)
      name = RecipeRadar_NameCache[id] or RRS("Uncached Recipe")
      local c = RecipeRadar_Colors.UncachedRecipe
      return name, "item:" .. id, RecipeRadar_ColorToCode(c), c.r, c.g, c.b,
            C_Item.GetItemIconByID(id) or (RECIPERADAR_IMAGE_ROOT .. "Misc\\QuestionMark"),
            false

   end

   RecipeRadar_NameCache[id] = name
   local r, g, b, colorcode = C_Item.GetItemQualityColor(rarity or 1)
   return name, link, "|c" .. colorcode, r, g, b, texture, true

end

-- Formats the subtext that applies to a few vendors.  include_parens is
-- a boolean that specifies whether the string should be in parens.
function RecipeRadar_FormatVendorNote(note, include_parens)

   if (include_parens) then
      return RecipeRadar_Parens(format(RRS("%s Vendor"), note))
   end
   return format(RRS("%s Vendor"), note)

end

-- Wraps a value in parentheses using the client's localized template.
function RecipeRadar_Parens(s)

   return format(PARENS_TEMPLATE or "(%s)", tostring(s))

end

-- Get gold, silver, copper from total copper.
function RecipeRadar_GetGSC(copper)

   copper = copper or 0
   local g = math.floor(copper / 10000)
   local s = math.floor((copper - (g * 10000)) / 100)
   local c = math.floor(copper - (g * 10000) - (s * 100))
   return g, s, c

end

-- Format text by color for gold, silver and copper.
function RecipeRadar_GetGSCString(copper)

   local GSC_GOLD = "ffd100"
   local GSC_SILVER = "e6e6e6"
   local GSC_COPPER = "c8602c"
   local GSC_FMT = "|cff%s%d|r"
   local GSC_PART = ".|cff%s%02d|r"

   local g, s, c = RecipeRadar_GetGSC(copper)

   if (g > 0) then
      local gsc = string.format(GSC_FMT, GSC_GOLD, g)
      if (s > 0) then
         gsc = gsc .. string.format(GSC_PART, GSC_SILVER, s)
      end
      return gsc
   elseif (s > 0) then
      local gsc = string.format(GSC_FMT, GSC_SILVER, s)
      if (c > 0) then
         gsc = gsc .. string.format(GSC_PART, GSC_COPPER, c)
      end
      return gsc
   elseif (c > 0) then
      return string.format(GSC_FMT, GSC_COPPER, c)
   end
   return "|cffa0a0a00|r"

end

-----------------------------------------------------------------------------
-- Misc lookups
-----------------------------------------------------------------------------

-- Returns the name of the player's opposing faction.
function RecipeRadar_GetOpposingFaction()

   local faction = UnitFactionGroup("player")
   if (faction == "Alliance") then
      return "Horde"
   elseif (faction == "Horde") then
      return "Alliance"
   end
   return "Unknown"

end

-- Formats a string in the color specified by the key 'team'.
function RecipeRadar_GetColoredTeamString(team, s)

   if (not RecipeRadar_Teams[team]) then return s end
   return RecipeRadar_ColorToCode(RecipeRadar_Teams[team].Color) ..
         s .. FONT_COLOR_CODE_CLOSE

end

-- Returns whether the skill is an applicable profession.
function RecipeRadar_IsProfession(skill_name)

   return skill_name ~= nil and RecipeRadar_Professions[skill_name] ~= nil

end

-- Returns whether the supplied faction is one that Recipe Radar cares about.
function RecipeRadar_IsKnownFaction(faction)

   for _, name in ipairs(RecipeRadar_Factions) do
      if (name == faction) then
         return true
      end
   end
   return false

end

-- Returns whether the given vendor has at least one unfiltered recipe.
function RecipeRadar_VendorHasRecipes(vendor)

   for _, recipe in ipairs(vendor.Recipes) do
      if (not RecipeRadar_IsRecipeFiltered(recipe)) then
         return true
      end
   end
   return false

end

-- Returns whether the given recipe has at least one unfiltered location.
function RecipeRadar_RecipeHasLocations(recipe)

   for _, location in ipairs(recipe.Locations) do
      if (not location.IsFiltered) then
         return true
      end
   end
   return false

end

-- Returns a string describing the requirements to buy the given recipe
-- according to the recipe's Notes/Faction member, or nil.
function RecipeRadar_GetRecipeReqsString(recipe)

   if (recipe.Notes and recipe.Notes ~= "") then
      return recipe.Notes
   end
   if (recipe.Faction and recipe.Faction ~= "") then
      return recipe.Faction .. ", " ..
            (_G["FACTION_STANDING_LABEL" .. recipe.Level] or "")
   end
   return nil

end

-- Given a recipe name of the form 'Label: Name', returns 'Name'.
function RecipeRadar_TrimRecipeLabel(recipe_name)

   local label_end = string.find(recipe_name, ":")
   if (label_end) then
      return string.sub(recipe_name, label_end + 2)
   end
   return recipe_name

end

-----------------------------------------------------------------------------
-- Sorting
-----------------------------------------------------------------------------

function RecipeRadar_SortVendors(region_data)

   if (region_data.IsVendorTableSorted) then return end
   table.sort(region_data.Vendors, RecipeRadar_CompareNames)
   region_data.IsVendorTableSorted = true

end

function RecipeRadar_SortRecipes(container)

   if (container.IsRecipeTableSorted) then return end
   table.sort(container.Recipes, RecipeRadar_CompareSkills)
   container.IsRecipeTableSorted = true

end

function RecipeRadar_SortLocations(recipe_data)

   if (recipe_data.IsLocationsTableSorted) then return end
   table.sort(recipe_data.Locations, RecipeRadar_CompareRegions)
   recipe_data.IsLocationsTableSorted = true

end

-- Required skill first, then the recipe's ID (deterministic order).
function RecipeRadar_CompareSkills(recipe1, recipe2)

   if (recipe1.Skill == recipe2.Skill) then
      return recipe1.ID < recipe2.ID
   end
   return recipe1.Skill < recipe2.Skill

end

function RecipeRadar_CompareNames(vendor1, vendor2)

   return vendor1.Name < vendor2.Name

end

function RecipeRadar_CompareRegions(location1, location2)

   if (location1.Region == location2.Region) then
      return location1.Vendor < location2.Vendor
   end
   return location1.Region < location2.Region

end

-----------------------------------------------------------------------------
-- Colors and output
-----------------------------------------------------------------------------

function RecipeRadar_ColorToCode(color)

   return string.format("|cff%02x%02x%02x",
         255 * color.r, 255 * color.g, 255 * color.b)

end

-- Returns the given string surrounded by the highlighted version of base_color.
function RecipeRadar_HighlightString(s, base_color)

   local highlight = {
         r = math.min(1.0, base_color.r + RecipeRadar_Colors.Highlight),
         g = math.min(1.0, base_color.g + RecipeRadar_Colors.Highlight),
         b = math.min(1.0, base_color.b + RecipeRadar_Colors.Highlight), }
   return RecipeRadar_ColorToCode(highlight) .. s .. FONT_COLOR_CODE_CLOSE

end

function RecipeRadar_Print(msg, r, g, b)

   DEFAULT_CHAT_FRAME:AddMessage(msg,
         (r or RecipeRadar_Colors.MainFont.r),
         (g or RecipeRadar_Colors.MainFont.g),
         (b or RecipeRadar_Colors.MainFont.b))

end
