-- DropDowns.lua: filter dropdowns (Menu API) and the corresponding filters

local addonName, ns = ...

-- Builds a menu of checkboxes. entries = { { key =, text = }, ... };
-- a checked box means "shown" (the saved filter table stores "filtered").
local function SetupCheckboxDropdown(dropdown, title, getEntries, isFiltered, setFiltered)

   -- multi-select: always show the title instead of the checked entries
   dropdown:OverrideText(title)
   dropdown:SetupMenu(function(_, root)
      for _, entry in ipairs(getEntries()) do
         root:CreateCheckbox(entry.text,
               function(key) return not isFiltered(key) end,
               function(key)
                  setFiltered(key, not isFiltered(key))
                  RRFListScrollFrameScrollBar:SetValue(0)
               end,
               entry.key)
      end
   end)

end

local function SortedKeys(t)

   local keys = { }
   for k in pairs(t) do table.insert(keys, k) end
   table.sort(keys)
   return keys

end

local function AvailabilityEntries(order_field)

   local entries = { }
   for key, info in pairs(RRF_Availabilities) do
      local order = info.DropDown[order_field]
      if (order) then
         entries[order] = { key = key,
               text = RRF_ColorToCode(info.Color) .. info.Text .. FONT_COLOR_CODE_CLOSE }
      end
   end
   return entries

end

function RRF_DropDowns_Init()

   SetupCheckboxDropdown(RRF_RealmAvailDropDown, RRF_S("Availability"),
         function() return AvailabilityEntries("ROrder") end,
         RRF_IsRealmAvailFiltered, RRF_SetRealmAvailFilter)

   SetupCheckboxDropdown(RRF_PersonAvailDropDown, RRF_S("Availability"),
         function() return AvailabilityEntries("POrder") end,
         RRF_IsPersonAvailFiltered, RRF_SetPersonAvailFilter)

   SetupCheckboxDropdown(RRF_TeamDropDown, RRF_S("Factions"),
         function()
            local entries = { }
            for _, key in ipairs(SortedKeys(RRF_Teams)) do
               local info = RRF_Teams[key]
               table.insert(entries, { key = key,
                     text = RRF_ColorToCode(info.Color) .. info.Name .. FONT_COLOR_CODE_CLOSE })
            end
            return entries
         end,
         RRF_IsTeamFiltered, RRF_SetTeamFilter)

   SetupCheckboxDropdown(RRF_Prof1DropDown, RRF_S("Professions"),
         function()
            local entries = { }
            for _, key in ipairs(SortedKeys(RRF_Professions)) do
               table.insert(entries, { key = key, text = RRF_Professions[key].Name })
            end
            return entries
         end,
         RRF_IsProfFiltered, RRF_SetProfFilter)

   -- single-select profession list for the recipes tab
   RRF_Prof2DropDown:SetupMenu(function(_, root)
      for _, key in ipairs(SortedKeys(RRF_Professions)) do
         root:CreateRadio(RRF_Professions[key].Name,
               RRF_IsCurrentProfession,
               function(prof)
                  RRF_SetProf2Filter(prof)
                  RRFListScrollFrameScrollBar:SetValue(0)
               end,
               key)
      end
   end)

   RRF_SetProf2Filter(RecipeRadarForever_Options.CurrentProfession)

end

-----------------------------------------------------------------------------
-- Filter state
-----------------------------------------------------------------------------

function RRF_IsRealmAvailFiltered(avail)
   return RecipeRadarForever_Filters.RealmAvails[avail]
end

function RRF_SetRealmAvailFilter(avail, is_filtered)

   RecipeRadarForever_Filters.RealmAvails[avail] = is_filtered
   RRF_FilterVendors("avail", avail, is_filtered)
   RRF_FilterRecipes("avail", avail, is_filtered)
   RRF_FrameUpdate()

end

function RRF_IsPersonAvailFiltered(avail)
   return RecipeRadarForever_Filters.PersonAvails[avail]
end

function RRF_SetPersonAvailFilter(avail, is_filtered)

   RecipeRadarForever_Filters.PersonAvails[avail] = is_filtered
   RRF_FilterVendors("avail", avail, is_filtered)
   RRF_FilterRecipes("avail", avail, is_filtered)
   RRF_FrameUpdate()

end

-- Generic tester for those who don't care about the current mode.
function RRF_IsAvailabilityFiltered(avail)

   if (RecipeRadarForever_Options.RealmAvailability) then
      return RRF_IsRealmAvailFiltered(avail)
   end
   return RRF_IsPersonAvailFiltered(avail)

end

function RRF_IsTeamFiltered(team)
   return RecipeRadarForever_Filters.Teams[team]
end

function RRF_SetTeamFilter(team, is_filtered)

   RecipeRadarForever_Filters.Teams[team] = is_filtered
   RRF_FilterVendors("team", team, is_filtered)
   RRF_FilterRecipes("team", team, is_filtered)
   RRF_FrameUpdate()

end

function RRF_IsProfFiltered(prof)
   return RecipeRadarForever_Filters.Professions[prof]
end

function RRF_SetProfFilter(prof, is_filtered)

   RecipeRadarForever_Filters.Professions[prof] = is_filtered
   RRF_FilterVendors("prof", prof, is_filtered)
   RRF_FrameUpdate()

end

function RRF_IsCurrentProfession(prof)
   return RecipeRadarForever_Options.CurrentProfession == prof
end

function RRF_SetProf2Filter(prof)

   if (not RRF_Professions[prof]) then return end
   RRFRecipesTabFrame:SetNormalTexture(RRF_Professions[prof].Icon)
   RecipeRadarForever_Options.CurrentProfession = prof
   RRF_InitRecipeFilters()
   RRF_FrameUpdate()

end

-----------------------------------------------------------------------------
-- Radar tab filtering code
-----------------------------------------------------------------------------

function RRF_IsRecipeFiltered(recipe)

   return recipe.IsFilteredByTeam or recipe.IsFilteredByProfession or
         recipe.IsFilteredByAvailability

end

-- Sets the filter state on the current region's vendors or recipes.
-- filter_type is 'team', 'prof' or 'avail'; filter_on is the key (eg. "Horde").
function RRF_FilterVendors(filter_type, filter_on, is_filtered)

   local region = RRF_RegionData[RecipeRadarForever_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do

      if (filter_type == "team" and filter_on == vendor.Team) then

         vendor.IsFiltered = is_filtered
         if (RRFRadarTabFrame.SelectedVendor == vendor) then
            RRF_RadarTab_ClearSelection()
         end

      elseif (filter_type == "prof" or filter_type == "avail") then

         for _, recipe in ipairs(vendor.Recipes) do
            local matches
            if (filter_type == "prof") then
               matches = (filter_on == recipe.Type)
            else
               matches = (filter_on == RRF_Availability_GetKey(recipe))
            end
            if (matches) then
               if (filter_type == "prof") then
                  recipe.IsFilteredByProfession = is_filtered
               else
                  recipe.IsFilteredByAvailability = is_filtered
               end
               if (RRFRadarTabFrame.SelectedRecipe == recipe) then
                  RRF_RadarTab_ClearSelection()
               end
            end
         end

      end

   end

end

local function IsSeasonalHidden(vendor)
   return RecipeRadarForever_Options.HideSeasonal and vendor and vendor.Notes == RRF_S("Seasonal")
end

-- Initializes vendor/recipe filters according to saved filter settings.
function RRF_InitVendorFilters()

   local region = RRF_RegionData[RecipeRadarForever_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do

      vendor.IsFiltered = RRF_IsTeamFiltered(vendor.Team) or IsSeasonalHidden(vendor)

      for _, recipe in ipairs(vendor.Recipes) do
         recipe.IsFilteredByProfession = RRF_IsProfFiltered(recipe.Type)
         -- sets the availability filter and auto-maps if requested
         if (RRF_Availability_IsLearnable(recipe, true) and
               RecipeRadarForever_Options.AutoMapVendors) then
            RRF_Maps_AddVendor(vendor, RecipeRadarForever_Options.CurrentRegion)
         end
      end

   end

end

-----------------------------------------------------------------------------
-- Recipes tab filtering code
-----------------------------------------------------------------------------

function RRF_FilterRecipes(filter_type, filter_on, is_filtered)

   local prof = RRF_RecipeData[RecipeRadarForever_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do

      if (filter_type == "avail" and
            filter_on == RRF_Availability_GetKey(recipe)) then

         recipe.IsFilteredByAvailability = is_filtered
         if (RRFRecipesTabFrame.SelectedRecipe == recipe) then
            RRF_RecipesTab_ClearSelection()
         end

      elseif (filter_type == "team") then

         for _, location in ipairs(recipe.Locations) do
            if (filter_on == location.Team) then
               location.IsFiltered = is_filtered
               if (RRFRecipesTabFrame.SelectedLocation == location.Region) then
                  RRF_RecipesTab_ClearSelection()
               end
            end
         end

      end

   end

end

function RRF_InitRecipeFilters()

   local prof = RRF_RecipeData[RecipeRadarForever_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do

      RRF_Availability_SetAvailabilityFilter(recipe)

      for _, location in ipairs(recipe.Locations) do
         local vendor = RRF_RecipesTab_FindVendor(location.Region, location.Vendor)
         location.IsFiltered = RRF_IsTeamFiltered(location.Team) or IsSeasonalHidden(vendor)
      end

   end

end
