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
                  RecipeRadarListScrollFrameScrollBar:SetValue(0)
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
   for key, info in pairs(RecipeRadar_Availabilities) do
      local order = info.DropDown[order_field]
      if (order) then
         entries[order] = { key = key,
               text = RecipeRadar_ColorToCode(info.Color) .. info.Text .. FONT_COLOR_CODE_CLOSE }
      end
   end
   return entries

end

function RecipeRadar_DropDowns_Init()

   SetupCheckboxDropdown(RecipeRadar_RealmAvailDropDown, RRS("Availability"),
         function() return AvailabilityEntries("ROrder") end,
         RecipeRadar_IsRealmAvailFiltered, RecipeRadar_SetRealmAvailFilter)

   SetupCheckboxDropdown(RecipeRadar_PersonAvailDropDown, RRS("Availability"),
         function() return AvailabilityEntries("POrder") end,
         RecipeRadar_IsPersonAvailFiltered, RecipeRadar_SetPersonAvailFilter)

   SetupCheckboxDropdown(RecipeRadar_TeamDropDown, RRS("Factions"),
         function()
            local entries = { }
            for _, key in ipairs(SortedKeys(RecipeRadar_Teams)) do
               local info = RecipeRadar_Teams[key]
               table.insert(entries, { key = key,
                     text = RecipeRadar_ColorToCode(info.Color) .. info.Name .. FONT_COLOR_CODE_CLOSE })
            end
            return entries
         end,
         RecipeRadar_IsTeamFiltered, RecipeRadar_SetTeamFilter)

   SetupCheckboxDropdown(RecipeRadar_Prof1DropDown, RRS("Professions"),
         function()
            local entries = { }
            for _, key in ipairs(SortedKeys(RecipeRadar_Professions)) do
               table.insert(entries, { key = key, text = RecipeRadar_Professions[key].Name })
            end
            return entries
         end,
         RecipeRadar_IsProfFiltered, RecipeRadar_SetProfFilter)

   -- single-select profession list for the recipes tab
   RecipeRadar_Prof2DropDown:SetupMenu(function(_, root)
      for _, key in ipairs(SortedKeys(RecipeRadar_Professions)) do
         root:CreateRadio(RecipeRadar_Professions[key].Name,
               RecipeRadar_IsCurrentProfession,
               function(prof)
                  RecipeRadar_SetProf2Filter(prof)
                  RecipeRadarListScrollFrameScrollBar:SetValue(0)
               end,
               key)
      end
   end)

   RecipeRadar_SetProf2Filter(RecipeRadar_Options.CurrentProfession)

end

-----------------------------------------------------------------------------
-- Filter state
-----------------------------------------------------------------------------

function RecipeRadar_IsRealmAvailFiltered(avail)
   return RecipeRadar_Filters.RealmAvails[avail]
end

function RecipeRadar_SetRealmAvailFilter(avail, is_filtered)

   RecipeRadar_Filters.RealmAvails[avail] = is_filtered
   RecipeRadar_FilterVendors("avail", avail, is_filtered)
   RecipeRadar_FilterRecipes("avail", avail, is_filtered)
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_IsPersonAvailFiltered(avail)
   return RecipeRadar_Filters.PersonAvails[avail]
end

function RecipeRadar_SetPersonAvailFilter(avail, is_filtered)

   RecipeRadar_Filters.PersonAvails[avail] = is_filtered
   RecipeRadar_FilterVendors("avail", avail, is_filtered)
   RecipeRadar_FilterRecipes("avail", avail, is_filtered)
   RecipeRadar_FrameUpdate()

end

-- Generic tester for those who don't care about the current mode.
function RecipeRadar_IsAvailabilityFiltered(avail)

   if (RecipeRadar_Options.RealmAvailability) then
      return RecipeRadar_IsRealmAvailFiltered(avail)
   end
   return RecipeRadar_IsPersonAvailFiltered(avail)

end

function RecipeRadar_IsTeamFiltered(team)
   return RecipeRadar_Filters.Teams[team]
end

function RecipeRadar_SetTeamFilter(team, is_filtered)

   RecipeRadar_Filters.Teams[team] = is_filtered
   RecipeRadar_FilterVendors("team", team, is_filtered)
   RecipeRadar_FilterRecipes("team", team, is_filtered)
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_IsProfFiltered(prof)
   return RecipeRadar_Filters.Professions[prof]
end

function RecipeRadar_SetProfFilter(prof, is_filtered)

   RecipeRadar_Filters.Professions[prof] = is_filtered
   RecipeRadar_FilterVendors("prof", prof, is_filtered)
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_IsCurrentProfession(prof)
   return RecipeRadar_Options.CurrentProfession == prof
end

function RecipeRadar_SetProf2Filter(prof)

   if (not RecipeRadar_Professions[prof]) then return end
   RecipeRadarRecipesTabFrame:SetNormalTexture(RecipeRadar_Professions[prof].Icon)
   RecipeRadar_Options.CurrentProfession = prof
   RecipeRadar_InitRecipeFilters()
   RecipeRadar_FrameUpdate()

end

-----------------------------------------------------------------------------
-- Radar tab filtering code
-----------------------------------------------------------------------------

function RecipeRadar_IsRecipeFiltered(recipe)

   return recipe.IsFilteredByTeam or recipe.IsFilteredByProfession or
         recipe.IsFilteredByAvailability

end

-- Sets the filter state on the current region's vendors or recipes.
-- filter_type is 'team', 'prof' or 'avail'; filter_on is the key (eg. "Horde").
function RecipeRadar_FilterVendors(filter_type, filter_on, is_filtered)

   local region = RecipeRadar_RegionData[RecipeRadar_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do

      if (filter_type == "team" and filter_on == vendor.Team) then

         vendor.IsFiltered = is_filtered
         if (RecipeRadarRadarTabFrame.SelectedVendor == vendor) then
            RecipeRadar_RadarTab_ClearSelection()
         end

      elseif (filter_type == "prof" or filter_type == "avail") then

         for _, recipe in ipairs(vendor.Recipes) do
            local matches
            if (filter_type == "prof") then
               matches = (filter_on == recipe.Type)
            else
               matches = (filter_on == RecipeRadar_Availability_GetKey(recipe))
            end
            if (matches) then
               if (filter_type == "prof") then
                  recipe.IsFilteredByProfession = is_filtered
               else
                  recipe.IsFilteredByAvailability = is_filtered
               end
               if (RecipeRadarRadarTabFrame.SelectedRecipe == recipe) then
                  RecipeRadar_RadarTab_ClearSelection()
               end
            end
         end

      end

   end

end

local function IsSeasonalHidden(vendor)
   return RecipeRadar_Options.HideSeasonal and vendor and vendor.Notes == RRS("Seasonal")
end

-- Initializes vendor/recipe filters according to saved filter settings.
function RecipeRadar_InitVendorFilters()

   local region = RecipeRadar_RegionData[RecipeRadar_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do

      vendor.IsFiltered = RecipeRadar_IsTeamFiltered(vendor.Team) or IsSeasonalHidden(vendor)

      for _, recipe in ipairs(vendor.Recipes) do
         recipe.IsFilteredByProfession = RecipeRadar_IsProfFiltered(recipe.Type)
         -- sets the availability filter and auto-maps if requested
         if (RecipeRadar_Availability_IsLearnable(recipe, true) and
               RecipeRadar_Options.AutoMapVendors) then
            RecipeRadar_Maps_AddVendor(vendor, RecipeRadar_Options.CurrentRegion)
         end
      end

   end

end

-----------------------------------------------------------------------------
-- Recipes tab filtering code
-----------------------------------------------------------------------------

function RecipeRadar_FilterRecipes(filter_type, filter_on, is_filtered)

   local prof = RecipeRadar_RecipeData[RecipeRadar_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do

      if (filter_type == "avail" and
            filter_on == RecipeRadar_Availability_GetKey(recipe)) then

         recipe.IsFilteredByAvailability = is_filtered
         if (RecipeRadarRecipesTabFrame.SelectedRecipe == recipe) then
            RecipeRadar_RecipesTab_ClearSelection()
         end

      elseif (filter_type == "team") then

         for _, location in ipairs(recipe.Locations) do
            if (filter_on == location.Team) then
               location.IsFiltered = is_filtered
               if (RecipeRadarRecipesTabFrame.SelectedLocation == location.Region) then
                  RecipeRadar_RecipesTab_ClearSelection()
               end
            end
         end

      end

   end

end

function RecipeRadar_InitRecipeFilters()

   local prof = RecipeRadar_RecipeData[RecipeRadar_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do

      RecipeRadar_Availability_SetAvailabilityFilter(recipe)

      for _, location in ipairs(recipe.Locations) do
         local vendor = RecipeRadar_RecipesTab_FindVendor(location.Region, location.Vendor)
         location.IsFiltered = RecipeRadar_IsTeamFiltered(location.Team) or IsSeasonalHidden(vendor)
      end

   end

end
