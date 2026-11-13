-- RecipesTab.lua: handles clicking and drawing for the Recipes tab

local addonName, ns = ...

-- per-update drawing state
local row = 0
local has_expanded, has_collapsed = false, false

function RecipeRadar_RecipesTab_Init()

   -- reset the list layout used by the radar tab (no indentation here)
   for i = 1, RECIPERADAR_VENDORS_DISPLAYED do
      local button = RecipeRadar_GetListButton(i)
      button:ClearAllPoints()
      if (i == 1) then
         button:SetPoint("TOPLEFT", RecipeRadarFrame, "TOPLEFT", 22, -96)
      else
         button:SetPoint("TOPLEFT", RecipeRadar_GetListButton(i - 1), "BOTTOMLEFT", 0, 0)
      end
      button.Check:Hide()
      button.Recipe = nil
   end

   RecipeRadar_Prof1DropDown:Hide()
   RecipeRadar_Prof2DropDown:Show()

   RecipeRadar_SetActiveTab(2)

   RecipeRadar_RecipesTab_Update()
   RecipeRadarListScrollFrameScrollBar:SetValue(RecipeRadarRecipesTabFrame.ScrollValue or 0)

end

function RecipeRadar_RecipesTab_OnClick()

   if (RecipeRadar_Options.ActiveTab == 2) then return end

   PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
   RecipeRadar_RecipesTab_Init()

end

function RecipeRadar_RecipesTab_ExpandAll(expand)

   local prof = RecipeRadar_RecipeData[RecipeRadar_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do
      recipe.IsExpanded = expand
   end

   RecipeRadar_SelectFirstRecipe()
   RecipeRadar_FrameUpdate()

end

-- Retrieves a vendor's info table from her name and region.
function RecipeRadar_RecipesTab_FindVendor(region_name, vendor_name)

   local region_data = RecipeRadar_RegionData[region_name]
   if (not region_data) then return nil end

   for _, vendor in ipairs(region_data.Vendors) do
      if (vendor.Name == vendor_name) then
         return vendor
      end
   end
   return nil

end

local function AddRecipe(recipe)

   if (RecipeRadar_IsRecipeFiltered(recipe) or
         not RecipeRadar_RecipeHasLocations(recipe)) then
      return
   end

   row = row + 1

   local offset = FauxScrollFrame_GetOffset(RecipeRadarListScrollFrame)
   local index = row - offset

   if (index > 0 and index <= RECIPERADAR_VENDORS_DISPLAYED) then

      local button = RecipeRadar_GetListButton(index)

      RecipeRadar_DrawListItem(index, recipe)

      button:UnlockHighlight()
      button.Check:Hide()
      button:GetHighlightTexture():SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")

      if (recipe.IsExpanded) then
         has_expanded = true
         button:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
      else
         has_collapsed = true
         button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
         return
      end

   else

      if (recipe.IsExpanded) then
         has_expanded = true
      else
         has_collapsed = true
         return
      end

   end

   RecipeRadar_SortLocations(recipe)

   for _, location in ipairs(recipe.Locations) do

      local vendor = RecipeRadar_RecipesTab_FindVendor(location.Region, location.Vendor)

      if (location.IsFiltered or not vendor) then

         -- unmap vendors that are filtered out
         if (vendor and vendor.IsMapped) then
            RecipeRadar_Maps_RemoveVendor(vendor)
         end

      else

         row = row + 1
         index = row - offset

         if (index > 0 and index <= RECIPERADAR_VENDORS_DISPLAYED) then

            local button = RecipeRadar_GetListButton(index)

            button:ClearNormalTexture()
            button:GetHighlightTexture():SetTexture(nil)

            local region_name = RecipeRadar_GetRegionDisplayName(location.Region)
            button:SetText(region_name)
            VendorNameDummyText:SetText(region_name)
            RecipeRadar_SetButtonColors(button, RecipeRadar_Colors.LightGray)
            button:SetID(index)
            button:Show()

            local subtext = button.SubText
            local content = location.Vendor
            if (vendor.Notes and vendor.Notes ~= "") then
               content = content .. " - " .. RecipeRadar_FormatVendorNote(vendor.Notes)
            end
            content = RecipeRadar_Parens(content)
            subtext:SetText(content)
            VendorNameDummySubText:SetText(content)

            local team_color = RecipeRadar_Teams[vendor.Team].Color
            button.r, button.g, button.b = team_color.r, team_color.g, team_color.b
            subtext:SetTextColor(team_color.r, team_color.g, team_color.b)
            subtext:SetPoint("LEFT", button:GetFontString(), "RIGHT", 10, 0)
            subtext:Show()

            -- unset to indicate this is a vendor item for the tooltip stuff
            button.Recipe = nil

            local check = button.Check
            if (vendor.IsMapped) then
               local check_offset = VendorNameDummyText:GetStringWidth() + 42
                     + VendorNameDummySubText:GetStringWidth()
               check:SetPoint("TOPLEFT", button, "TOPLEFT", check_offset, 0)
               check:Show()
            else
               check:Hide()
            end

            local frame = RecipeRadarRecipesTabFrame
            if (frame.SelectedLocation == location.Region and
                  frame.SelectedRecipe == recipe and
                  frame.SelectedVendor and frame.SelectedVendor.Name == location.Vendor) then
               RecipeRadarHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 0)
               RecipeRadarHighlightFrame:Show()
               button:LockHighlight()
            else
               button:UnlockHighlight()
            end

         end

      end

   end

end

function RecipeRadar_RecipesTab_Update()

   if (RecipeRadar_Options.ActiveTab ~= 2) then return end

   local prof = RecipeRadar_Options.CurrentProfession
   local prof_data = RecipeRadar_RecipeData[prof]

   TitleBarText:SetText(RRS("Recipe Radar") .. " - " .. prof .. " " ..
         RecipeRadar_Parens(RecipeRadar_SkillDB_GetRank(prof)))

   row = 0
   has_expanded, has_collapsed = false, false

   RecipeRadarHighlightFrame:Hide()

   if (prof_data) then
      RecipeRadar_SortRecipes(prof_data)
      for _, recipe in ipairs(prof_data.Recipes) do
         AddRecipe(recipe)
      end
   end

   FauxScrollFrame_Update(RecipeRadarListScrollFrame, row,
         RECIPERADAR_VENDORS_DISPLAYED, RECIPERADAR_VENDOR_HEIGHT,
         nil, nil, nil, RecipeRadarHighlightFrame, 361, 384)

   local wide = not RecipeRadarListScrollFrame:IsShown()
   for i = 1, RECIPERADAR_VENDORS_DISPLAYED do
      local button = RecipeRadar_GetListButton(i)
      if (i > row) then
         button:Hide()
      else
         button:SetWidth(wide and 384 or 361)
      end
   end

   if (not prof_data or not RecipeRadarRecipesTabFrame.SelectedRecipe) then
      RecipeRadar_HideRecipeDetails()
   elseif (RecipeRadarRecipesTabFrame.SelectedVendor) then
      RecipeRadar_SetSelection(RecipeRadarRecipesTabFrame.SelectedVendor,
            RecipeRadarRecipesTabFrame.SelectedRecipe,
            RecipeRadarRecipesTabFrame.SelectedLocation)
      RecipeRadar_ShowRecipeDetails()
   end

end

local function ShowContextMenu(owner, location)

   MenuUtil.CreateContextMenu(owner, function(_, root)
      if (location) then
         local vendor = RecipeRadar_RecipesTab_FindVendor(location.Region, location.Vendor)
         if (vendor) then
            root:CreateTitle(location.Vendor)
            root:CreateButton(vendor.IsMapped and RRS("Unmap Vendor") or RRS("Map Vendor"), function()
               if (vendor.IsMapped) then
                  RecipeRadar_Maps_RemoveVendor(vendor)
               else
                  RecipeRadar_Maps_AddVendor(vendor, location.Region)
               end
               RecipeRadar_FrameUpdate()
            end)
         end
      end
      local expand = root:CreateButton(RRS("Expand All"), function()
         RecipeRadar_RecipesTab_ExpandAll(true)
      end)
      expand:SetEnabled(has_collapsed)
      local collapse = root:CreateButton(RRS("Collapse All"), function()
         RecipeRadar_RecipesTab_ExpandAll(false)
      end)
      collapse:SetEnabled(has_expanded)
   end)

end

-- Handles a recipe/location click in the main scroll frame. index is
-- row + offset in the scroll frame, or -1 to select the first visible location.
function RecipeRadar_RecipesTab_ServiceClickIndex(index, button, owner)

   local prof_data = RecipeRadar_RecipeData[RecipeRadar_Options.CurrentProfession]
   if (not prof_data) then return end

   button = button or "LeftButton"
   RecipeRadarRecipesTabFrame.SelectedIndex = index

   RecipeRadar_SortRecipes(prof_data)
   local count = 0

   for _, recipe in ipairs(prof_data.Recipes) do

      if (not RecipeRadar_IsRecipeFiltered(recipe) and
            RecipeRadar_RecipeHasLocations(recipe)) then

         count = count + 1

         if (count == index) then
            if (button == "LeftButton") then
               RecipeRadar_RecipesTab_ToggleExpanded(recipe)
            elseif (button == "RightButton" and owner) then
               ShowContextMenu(owner, nil)
            end
            return
         end

         if (recipe.IsExpanded) then

            RecipeRadar_SortLocations(recipe)

            for _, location in ipairs(recipe.Locations) do
               local vendor = RecipeRadar_RecipesTab_FindVendor(location.Region, location.Vendor)
               if (not location.IsFiltered and vendor) then

                  count = count + 1

                  if (count == index or index == -1) then
                     if (button == "LeftButton") then
                        if (IsShiftKeyDown()) then
                           if (vendor.IsMapped) then
                              RecipeRadar_Maps_RemoveVendor(vendor)
                           else
                              RecipeRadar_Maps_AddVendor(vendor, location.Region)
                           end
                        end
                        RecipeRadarRecipesTabFrame.SelectedVendor = vendor
                        RecipeRadarRecipesTabFrame.SelectedRecipe = recipe
                        RecipeRadarRecipesTabFrame.SelectedLocation = location.Region
                        RecipeRadar_SetSelection(vendor, recipe, location.Region)
                        RecipeRadar_ShowRecipeDetails()
                     elseif (button == "RightButton" and owner) then
                        ShowContextMenu(owner, location)
                     end
                     return
                  end

               end
            end

         end

      end

   end

   RecipeRadar_RecipesTab_ClearSelection()
   RecipeRadar_HideRecipeDetails()

end

function RecipeRadar_RecipesTab_ToggleExpanded(recipe)

   recipe.IsExpanded = not recipe.IsExpanded
   RecipeRadar_RecipesTab_ClearSelection()
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_RecipesTab_ClearSelection()

   RecipeRadarRecipesTabFrame.SelectedVendor = nil
   RecipeRadarRecipesTabFrame.SelectedRecipe = nil
   RecipeRadarRecipesTabFrame.SelectedLocation = nil

end
