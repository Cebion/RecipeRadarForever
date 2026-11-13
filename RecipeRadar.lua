-- RecipeRadar.lua: main event code and general utility functions

local addonName, ns = ...

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------

function RRF_OnLoad(self)

   tinsert(UISpecialFrames, "RRFFrame")

   SLASH_RECIPERADARFOREVER1 = "/rrf"
   SlashCmdList["RECIPERADARFOREVER"] = RRF_SlashHandler

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

   local zone = RRF_Maps_GetPlayerRegion()
   if (RRF_RegionHasLearnableRecipe(zone)) then
      RRF_MinimapButton_Flash()
   end
   if (RecipeRadarForever_Options.AutoSelectRegion) then
      RRF_NewRegion(zone)
   end

end

function RRF_OnEvent(self, event, ...)

   if (event == "ADDON_LOADED") then

      if (... ~= addonName) then return end
      self:UnregisterEvent("ADDON_LOADED")

      RRF_Globals_Init()
      RRF_SkillDB_Init()
      RRF_MinimapButton_Init()
      RRF_Availability_Init()
      RRF_Maps_Init()
      RRF_MainFrame_Init()
      RRF_DropDowns_Init()
      RRF_Options_RegisterSettings()

   elseif (event == "PLAYER_LOGIN") then

      if (RecipeRadarForever_Filters.Teams["Horde"] == nil) then
         -- first run of the addon on this character: hide the other faction
         local faction = UnitFactionGroup("player")
         if (faction == "Alliance" or faction == "Horde") then
            RecipeRadarForever_Filters.Teams[faction] = false
            RecipeRadarForever_Filters.Teams[RRF_GetOpposingFaction()] = true
         end
      end

      RRF_ItemData_ApplyCache()
      RRF_Maps_BuildRegionIndex()
      RRF_SkillDB_ScanAll()
      -- item data for the tooltip scans may still be loading right after login
      C_Timer.After(5, RRF_SkillDB_RequestKnownScan)
      C_Timer.After(8, function() RRF_ItemData_ResolveSkills(RRF_RefreshIfShown) end)
      -- newer vendor data from an installed QuestieDB, read in small batches
      C_Timer.After(3, RRF_Import_Start)
      RRF_SelectFirstRecipe()

   elseif (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") then

      OnNewZone()

   elseif (event == "SKILL_LINES_CHANGED") then

      RRF_SkillDB_ScanSkills()
      RRF_SkillDB_ScanSpecialties()
      RRF_RefreshIfShown()

   elseif (event == "UPDATE_FACTION") then

      RRF_SkillDB_ScanReputation()

   elseif (event == "NEW_RECIPE_LEARNED" or event == "LEARNED_SPELL_IN_SKILL_LINE"
         or event == "TRADE_SKILL_SHOW") then

      RRF_SkillDB_RequestKnownScan()

   end

end

function RRF_OnShow(self)

   PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)

end

function RRF_OnHide(self)

   PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
   self:StopMovingOrSizing()

end

-- Recomputes cached filters and redraws, but only if the window is open
-- (RRF_Frame_Show does the same work when it opens).
function RRF_RefreshIfShown()

   if (RRFFrame and RRFFrame:IsShown()) then
      RRF_InitVendorFilters()
      RRF_InitRecipeFilters()
      RRF_FrameUpdate()
   end

end

-----------------------------------------------------------------------------
-- Slash command
-----------------------------------------------------------------------------

function RRF_SlashHandler(msg)

   local cmd, sub, rest = string.match(msg or "", "^(%w*)%s*(%w*)%s*(.*)$")
   cmd = string.lower(cmd or "")

   if (cmd == "debug") then

      if (sub == "skills") then
         RRF_SkillDB_Print(rest)
      elseif (sub == "clear") then
         RRF_SkillDB_Clear(rest)
      elseif (sub == "maps") then
         RRF_Maps_PrintRegionIndex()
      elseif (sub == "scan") then
         RRF_SkillDB_ScanAll()
         RRF_SkillDB_ScanKnownRecipes()
         RRF_Print("Recipe Radar: rescanned skills, reputation and known recipes.")
      elseif (sub == "import") then
         RRF_Import_PrintStatus()
      elseif (sub == "where") then
         -- stand on a vendor and compare with the database coordinates
         local zone = RRF_Maps_GetPlayerRegion()
         local mapID = C_Map.GetBestMapForUnit("player")
         local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
         if (pos) then
            local x, y = pos:GetXY()
            RRF_Print(string.format("%s (uiMapID %d, index %s): x = %.3f, y = %.3f",
                  zone, mapID, tostring(RRF_Maps_GetRegionMapID(zone)), x, y))
         else
            RRF_Print(zone .. ": no map position here.")
         end
      else
         RRF_Print("/rrf debug skills [name] | clear [name] | maps | scan | import | where")
      end
      return

   end

   if (cmd == "radar") then

      local region = RRF_RegionData[RRF_Maps_GetPlayerRegion()]
      if (not region) then return end

      for _, vendor in ipairs(region.Vendors) do

         local coords = vendor.Coordinates and vendor.Coordinates[1]
         local where = ""
         if (coords) then
            where = string.format(" (%d, %d)", coords.x * 100, coords.y * 100)
         end
         RRF_Print(RRF_GetColoredTeamString(
               vendor.Team, vendor.Name) .. where .. ":")

         table.sort(vendor.Recipes, RRF_CompareSkills)
         for _, recipe in ipairs(vendor.Recipes) do
            RRF_Print("   " .. RRF_GetHyperlinkByID(recipe.ID) ..
                  ", " .. RRF_GetGSCString(recipe.Cost))
         end

      end
      return

   end

   if (cmd == "report") then
      RRF_Report_Show(sub == "data" and "data" or "bug")
      return
   end

   if (cmd == "verify") then
      RRF_ItemData_Verify()
      return
   end

   if (cmd == "questie") then
      if (sub == "on" or sub == "off") then
         RecipeRadarForever_Options.UseQuestie = (sub == "on")
         RRF_Print("Recipe Radar: QuestieDB import " .. sub .. " (takes effect after /reload).")
      else
         RRF_Import_PrintStatus()
      end
      return
   end

   if (cmd == "options" or cmd == "config") then
      RRF_OptionsFrame_Toggle()
      return
   end

   RRF_Toggle()

end

-----------------------------------------------------------------------------
-- Region helpers
-----------------------------------------------------------------------------

-- Function to be called on selecting a new region to initialize the
-- main frame and any active filters.
function RRF_NewRegion(region)

   if (not region or region == "") then return end

   RecipeRadarForever_Options.CurrentRegion = region
   RecipeRadarForever_Options.CurrentContinent = RRF_GetCurrentContinent()
   RRF_InitVendorFilters()
   RRF_SelectFirstRecipe()
   RRF_FrameUpdate()

end

-- Returns whether the given region contains at least one recipe that
-- is learnable by the player or (optionally) alts
function RRF_RegionHasLearnableRecipe(region_name)

   local region_data = RRF_RegionData[region_name]
   if (not region_data) then return false end

   for _, vendor in ipairs(region_data.Vendors) do
      for _, recipe in ipairs(vendor.Recipes) do
         if (RRF_Availability_IsLearnable(recipe)) then
            return true
         end
      end
   end

   return false

end

-- Given a table of recipes, returns the number of recipes that are
-- learnable by the player or (optionally) alts.
function RRF_CountLearnableRecipes(recipes)

   if (not recipes) then return 0 end

   local total = 0
   for _, recipe in ipairs(recipes) do
      if (RRF_Availability_IsLearnable(recipe)) then
         total = total + 1
      end
   end
   return total

end

-- Returns the index of the current region's continent (1 Kalimdor,
-- 2 Eastern Kingdoms), or 0 for instances and unknown zones.
function RRF_GetCurrentContinent()

   local name = RecipeRadarForever_Options.CurrentRegion
   local region = RRF_RegionData[name]
   if (region) then
      return region.Continent
   end
   return RRF_Maps_GetContinentIndex(name) or 0

end

-----------------------------------------------------------------------------
-- Item helpers
-----------------------------------------------------------------------------

-- Returns a string describing an item link from an item ID.
function RRF_GetHyperlinkByID(id)

   local name, link, color = RRF_GetSafeItemInfo(id)
   return RRF_GetHyperlinkByParts(name, link, color)

end

-- Returns a string describing an item link from link components.
function RRF_GetHyperlinkByParts(name, link, color)

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
         RecipeRadarForever_NameCache[id] = name
      end
      -- coalesce the burst of redraws when many items arrive together
      if (not ns.redrawQueued) then
         ns.redrawQueued = true
         C_Timer.After(0.5, function()
            ns.redrawQueued = false
            RRF_RefreshIfShown()
         end)
      end
   end)

end

-- Returns name, link, colorcode, r, g, b, texture, is_cached for an item.
-- Items that are not in the client cache yet are requested; until then a
-- placeholder (or the name seen in an earlier session) is returned.
function RRF_GetSafeItemInfo(id)

   if (type(RecipeRadarForever_NameCache) ~= "table") then RecipeRadarForever_NameCache = { } end

   local name, link, rarity, _, _, _, _, _, _, texture = C_Item.GetItemInfo(id)

   if (name == nil) then

      RequestItem(id)
      name = RecipeRadarForever_NameCache[id] or RRF_S("Uncached Recipe")
      local c = RRF_Colors.UncachedRecipe
      return name, "item:" .. id, RRF_ColorToCode(c), c.r, c.g, c.b,
            C_Item.GetItemIconByID(id) or (RRF_IMAGE_ROOT .. "Misc\\QuestionMark"),
            false

   end

   RecipeRadarForever_NameCache[id] = name
   local r, g, b, colorcode = C_Item.GetItemQualityColor(rarity or 1)
   return name, link, "|c" .. colorcode, r, g, b, texture, true

end

-- Formats the subtext that applies to a few vendors.  include_parens is
-- a boolean that specifies whether the string should be in parens.
function RRF_FormatVendorNote(note, include_parens)

   if (include_parens) then
      return RRF_Parens(format(RRF_S("%s Vendor"), note))
   end
   return format(RRF_S("%s Vendor"), note)

end

-- Wraps a value in parentheses using the client's localized template.
function RRF_Parens(s)

   return format(PARENS_TEMPLATE or "(%s)", tostring(s))

end

-- Get gold, silver, copper from total copper.
function RRF_GetGSC(copper)

   copper = copper or 0
   local g = math.floor(copper / 10000)
   local s = math.floor((copper - (g * 10000)) / 100)
   local c = math.floor(copper - (g * 10000) - (s * 100))
   return g, s, c

end

-- Format text by color for gold, silver and copper.
function RRF_GetGSCString(copper)

   local GSC_GOLD = "ffd100"
   local GSC_SILVER = "e6e6e6"
   local GSC_COPPER = "c8602c"
   local GSC_FMT = "|cff%s%d|r"
   local GSC_PART = ".|cff%s%02d|r"

   local g, s, c = RRF_GetGSC(copper)

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
function RRF_GetOpposingFaction()

   local faction = UnitFactionGroup("player")
   if (faction == "Alliance") then
      return "Horde"
   elseif (faction == "Horde") then
      return "Alliance"
   end
   return "Unknown"

end

-- Formats a string in the color specified by the key 'team'.
function RRF_GetColoredTeamString(team, s)

   if (not RRF_Teams[team]) then return s end
   return RRF_ColorToCode(RRF_Teams[team].Color) ..
         s .. FONT_COLOR_CODE_CLOSE

end

-- Returns whether the skill is an applicable profession.
function RRF_IsProfession(skill_name)

   return skill_name ~= nil and RRF_Professions[skill_name] ~= nil

end

-- Returns whether the supplied faction is one that Recipe Radar cares about.
function RRF_IsKnownFaction(faction)

   for _, name in ipairs(RRF_Factions) do
      if (name == faction) then
         return true
      end
   end
   return false

end

-- Returns whether the given vendor has at least one unfiltered recipe.
function RRF_VendorHasRecipes(vendor)

   for _, recipe in ipairs(vendor.Recipes) do
      if (not RRF_IsRecipeFiltered(recipe, vendor)) then
         return true
      end
   end
   return false

end

-- Returns whether the given recipe has at least one unfiltered location.
function RRF_RecipeHasLocations(recipe)

   for _, location in ipairs(recipe.Locations) do
      if (not RRF_IsLocationHidden(recipe, location)) then
         return true
      end
   end
   return false

end

-- Returns a string describing the requirements to buy the given recipe
-- according to the recipe's Notes/Faction member, or nil.
function RRF_GetRecipeReqsString(recipe)

   if (recipe.Notes and recipe.Notes ~= "") then
      return recipe.Notes
   end
   local faction = recipe.Faction
   if (recipe.FactionID) then
      local data = C_Reputation.GetFactionDataByID(recipe.FactionID)
      faction = (data and data.name ~= "" and data.name) or faction
   end
   if (faction and faction ~= "") then
      return faction .. ", " .. (_G["FACTION_STANDING_LABEL" .. (recipe.Level or 4)] or "")
   end
   return nil

end

-- Given a recipe name of the form 'Label: Name', returns 'Name'.
function RRF_TrimRecipeLabel(recipe_name)

   local label_end = string.find(recipe_name, ":")
   if (label_end) then
      return string.sub(recipe_name, label_end + 2)
   end
   return recipe_name

end

-----------------------------------------------------------------------------
-- Sorting
-----------------------------------------------------------------------------

function RRF_SortVendors(region_data)

   if (region_data.IsVendorTableSorted) then return end
   table.sort(region_data.Vendors, RRF_CompareNames)
   region_data.IsVendorTableSorted = true

end

function RRF_SortRecipes(container)

   if (container.IsRecipeTableSorted) then return end
   table.sort(container.Recipes, RRF_CompareSkills)
   container.IsRecipeTableSorted = true

end

function RRF_SortLocations(recipe_data)

   if (recipe_data.IsLocationsTableSorted) then return end
   table.sort(recipe_data.Locations, RRF_CompareRegions)
   recipe_data.IsLocationsTableSorted = true

end

-- Required skill first, then the recipe's ID (deterministic order).
function RRF_CompareSkills(recipe1, recipe2)

   local s1, s2 = recipe1.Skill or 0, recipe2.Skill or 0
   if (s1 == s2) then
      return recipe1.ID < recipe2.ID
   end
   return s1 < s2

end

function RRF_CompareNames(vendor1, vendor2)

   return vendor1.Name < vendor2.Name

end

function RRF_CompareRegions(location1, location2)

   if (location1.Region == location2.Region) then
      return location1.Vendor < location2.Vendor
   end
   return location1.Region < location2.Region

end

-----------------------------------------------------------------------------
-- Colors and output
-----------------------------------------------------------------------------

function RRF_ColorToCode(color)

   return string.format("|cff%02x%02x%02x",
         255 * color.r, 255 * color.g, 255 * color.b)

end

-- Returns the given string surrounded by the highlighted version of base_color.
function RRF_HighlightString(s, base_color)

   local highlight = {
         r = math.min(1.0, base_color.r + RRF_Colors.Highlight),
         g = math.min(1.0, base_color.g + RRF_Colors.Highlight),
         b = math.min(1.0, base_color.b + RRF_Colors.Highlight), }
   return RRF_ColorToCode(highlight) .. s .. FONT_COLOR_CODE_CLOSE

end

function RRF_Print(msg, r, g, b)

   DEFAULT_CHAT_FRAME:AddMessage(msg,
         (r or RRF_Colors.MainFont.r),
         (g or RRF_Colors.MainFont.g),
         (b or RRF_Colors.MainFont.b))

end
