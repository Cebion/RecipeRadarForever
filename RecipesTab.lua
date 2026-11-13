-- RecipesTab.lua: handles clicking and drawing for the Recipes tab

local addonName, ns = ...

-- per-update drawing state
local row = 0
local has_expanded, has_collapsed = false, false

function RRF_RecipesTab_Init()

   -- reset the list layout used by the radar tab (no indentation here)
   for i = 1, RRF_VENDORS_DISPLAYED do
      local button = RRF_GetListButton(i)
      button:ClearAllPoints()
      if (i == 1) then
         button:SetPoint("TOPLEFT", RRFFrame, "TOPLEFT", 22, -96)
      else
         button:SetPoint("TOPLEFT", RRF_GetListButton(i - 1), "BOTTOMLEFT", 0, 0)
      end
      button.Check:Hide()
      button.Recipe = nil
   end

   RRF_Prof1DropDown:Hide()
   RRF_Prof2DropDown:Show()

   RRF_SetActiveTab(2)

   RRF_RecipesTab_Update()
   RRFListScrollFrameScrollBar:SetValue(RRFRecipesTabFrame.ScrollValue or 0)

end

function RRF_RecipesTab_OnClick()

   if (RecipeRadarForever_Options.ActiveTab == 2) then return end

   PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
   RRF_RecipesTab_Init()

end

function RRF_RecipesTab_ExpandAll(expand)

   local prof = RRF_RecipeData[RecipeRadarForever_Options.CurrentProfession]
   if (not prof) then return end

   for _, recipe in ipairs(prof.Recipes) do
      recipe.IsExpanded = expand
   end

   RRF_SelectFirstRecipe()
   RRF_FrameUpdate()

end

-- Retrieves a vendor's info table from her name and region.
function RRF_RecipesTab_FindVendor(region_name, vendor_name)

   local region_data = RRF_RegionData[region_name]
   if (not region_data) then return nil end

   for _, vendor in ipairs(region_data.Vendors) do
      if (vendor.Name == vendor_name) then
         return vendor
      end
   end
   return nil

end

local function AddRecipe(recipe)

   if (RRF_IsRecipeFiltered(recipe) or
         not RRF_RecipeHasLocations(recipe)) then
      return
   end

   row = row + 1

   local offset = FauxScrollFrame_GetOffset(RRFListScrollFrame)
   local index = row - offset

   if (index > 0 and index <= RRF_VENDORS_DISPLAYED) then

      local button = RRF_GetListButton(index)

      RRF_DrawListItem(index, recipe)

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

   RRF_SortLocations(recipe)

   for _, location in ipairs(recipe.Locations) do

      local vendor = RRF_RecipesTab_FindVendor(location.Region, location.Vendor)

      if (location.IsFiltered or not vendor) then

         -- unmap vendors that are filtered out
         if (vendor and vendor.IsMapped) then
            RRF_Maps_RemoveVendor(vendor)
         end

      else

         row = row + 1
         index = row - offset

         if (index > 0 and index <= RRF_VENDORS_DISPLAYED) then

            local button = RRF_GetListButton(index)

            button:ClearNormalTexture()
            button:GetHighlightTexture():SetTexture(nil)

            local region_name = RRF_GetRegionDisplayName(location.Region)
            button:SetText(region_name)
            RRFVendorNameDummyText:SetText(region_name)
            RRF_SetButtonColors(button, RRF_Colors.LightGray)
            button:SetID(index)
            button:Show()

            local subtext = button.SubText
            local content = location.Vendor
            if (vendor.Notes and vendor.Notes ~= "") then
               content = content .. " - " .. RRF_FormatVendorNote(vendor.Notes)
            end
            content = RRF_Parens(content)
            subtext:SetText(content)
            RRFVendorNameDummySubText:SetText(content)

            local team_color = RRF_Teams[vendor.Team].Color
            button.r, button.g, button.b = team_color.r, team_color.g, team_color.b
            subtext:SetTextColor(team_color.r, team_color.g, team_color.b)
            subtext:SetPoint("LEFT", button:GetFontString(), "RIGHT", 10, 0)
            subtext:Show()

            -- unset to indicate this is a vendor item for the tooltip stuff
            button.Recipe = nil

            local check = button.Check
            if (vendor.IsMapped) then
               local check_offset = RRFVendorNameDummyText:GetStringWidth() + 42
                     + RRFVendorNameDummySubText:GetStringWidth()
               check:SetPoint("TOPLEFT", button, "TOPLEFT", check_offset, 0)
               check:Show()
            else
               check:Hide()
            end

            local frame = RRFRecipesTabFrame
            if (frame.SelectedLocation == location.Region and
                  frame.SelectedRecipe == recipe and
                  frame.SelectedVendor and frame.SelectedVendor.Name == location.Vendor) then
               RRFHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 0)
               RRFHighlightFrame:Show()
               button:LockHighlight()
            else
               button:UnlockHighlight()
            end

         end

      end

   end

end

function RRF_RecipesTab_Update()

   if (RecipeRadarForever_Options.ActiveTab ~= 2) then return end

   local prof = RecipeRadarForever_Options.CurrentProfession
   local prof_data = RRF_RecipeData[prof]

   RRFTitleBarText:SetText(RRF_S("Recipe Radar Forever") .. " - " .. prof .. " " ..
         RRF_Parens(RRF_SkillDB_GetRank(prof)))

   row = 0
   has_expanded, has_collapsed = false, false

   RRFHighlightFrame:Hide()

   if (prof_data) then
      RRF_SortRecipes(prof_data)
      for _, recipe in ipairs(prof_data.Recipes) do
         AddRecipe(recipe)
      end
   end

   FauxScrollFrame_Update(RRFListScrollFrame, row,
         RRF_VENDORS_DISPLAYED, RRF_VENDOR_HEIGHT,
         nil, nil, nil, RRFHighlightFrame, 361, 384)

   local wide = not RRFListScrollFrame:IsShown()
   for i = 1, RRF_VENDORS_DISPLAYED do
      local button = RRF_GetListButton(i)
      if (i > row) then
         button:Hide()
      else
         button:SetWidth(wide and 384 or 361)
      end
   end

   if (not prof_data or not RRFRecipesTabFrame.SelectedRecipe) then
      RRF_HideRecipeDetails()
   elseif (RRFRecipesTabFrame.SelectedVendor) then
      RRF_SetSelection(RRFRecipesTabFrame.SelectedVendor,
            RRFRecipesTabFrame.SelectedRecipe,
            RRFRecipesTabFrame.SelectedLocation)
      RRF_ShowRecipeDetails()
   end

end

local function ShowContextMenu(owner, location)

   MenuUtil.CreateContextMenu(owner, function(_, root)
      if (location) then
         local vendor = RRF_RecipesTab_FindVendor(location.Region, location.Vendor)
         if (vendor) then
            root:CreateTitle(location.Vendor)
            root:CreateButton(vendor.IsMapped and RRF_S("Unmap Vendor") or RRF_S("Map Vendor"), function()
               if (vendor.IsMapped) then
                  RRF_Maps_RemoveVendor(vendor)
               else
                  RRF_Maps_AddVendor(vendor, location.Region)
               end
               RRF_FrameUpdate()
            end)
         end
      end
      local expand = root:CreateButton(RRF_S("Expand All"), function()
         RRF_RecipesTab_ExpandAll(true)
      end)
      expand:SetEnabled(has_collapsed)
      local collapse = root:CreateButton(RRF_S("Collapse All"), function()
         RRF_RecipesTab_ExpandAll(false)
      end)
      collapse:SetEnabled(has_expanded)
   end)

end

-- Handles a recipe/location click in the main scroll frame. index is
-- row + offset in the scroll frame, or -1 to select the first visible location.
function RRF_RecipesTab_ServiceClickIndex(index, button, owner)

   local prof_data = RRF_RecipeData[RecipeRadarForever_Options.CurrentProfession]
   if (not prof_data) then return end

   button = button or "LeftButton"
   RRFRecipesTabFrame.SelectedIndex = index

   RRF_SortRecipes(prof_data)
   local count = 0

   for _, recipe in ipairs(prof_data.Recipes) do

      if (not RRF_IsRecipeFiltered(recipe) and
            RRF_RecipeHasLocations(recipe)) then

         count = count + 1

         if (count == index) then
            if (button == "LeftButton") then
               RRF_RecipesTab_ToggleExpanded(recipe)
            elseif (button == "RightButton" and owner) then
               ShowContextMenu(owner, nil)
            end
            return
         end

         if (recipe.IsExpanded) then

            RRF_SortLocations(recipe)

            for _, location in ipairs(recipe.Locations) do
               local vendor = RRF_RecipesTab_FindVendor(location.Region, location.Vendor)
               if (not location.IsFiltered and vendor) then

                  count = count + 1

                  if (count == index or index == -1) then
                     if (button == "LeftButton") then
                        if (IsShiftKeyDown()) then
                           if (vendor.IsMapped) then
                              RRF_Maps_RemoveVendor(vendor)
                           else
                              RRF_Maps_AddVendor(vendor, location.Region)
                           end
                        end
                        RRFRecipesTabFrame.SelectedVendor = vendor
                        RRFRecipesTabFrame.SelectedRecipe = recipe
                        RRFRecipesTabFrame.SelectedLocation = location.Region
                        RRF_SetSelection(vendor, recipe, location.Region)
                        RRF_ShowRecipeDetails()
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

   RRF_RecipesTab_ClearSelection()
   RRF_HideRecipeDetails()

end

function RRF_RecipesTab_ToggleExpanded(recipe)

   recipe.IsExpanded = not recipe.IsExpanded
   RRF_RecipesTab_ClearSelection()
   RRF_FrameUpdate()

end

function RRF_RecipesTab_ClearSelection()

   RRFRecipesTabFrame.SelectedVendor = nil
   RRFRecipesTabFrame.SelectedRecipe = nil
   RRFRecipesTabFrame.SelectedLocation = nil

end
