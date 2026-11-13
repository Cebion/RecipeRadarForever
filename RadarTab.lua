-- RadarTab.lua: handles clicking and drawing for the Radar tab

local addonName, ns = ...

-- per-update drawing state
local row, last_button = 0, ""
local has_expanded, has_collapsed = false, false

function RecipeRadar_RadarTab_Init()

   RecipeRadar_Prof1DropDown:Show()
   RecipeRadar_Prof2DropDown:Hide()

   RecipeRadar_SetActiveTab(1)

   RecipeRadar_RadarTab_Update()
   RecipeRadarListScrollFrameScrollBar:SetValue(RecipeRadarRadarTabFrame.ScrollValue or 0)

end

function RecipeRadar_RadarTab_OnClick()

   if (RecipeRadar_Options.ActiveTab == 1) then return end

   PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
   RecipeRadar_RadarTab_Init()

end

function RecipeRadar_RadarTab_ExpandAll(expand)

   local region = RecipeRadar_RegionData[RecipeRadar_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do
      vendor.IsExpanded = expand
   end

   RecipeRadar_SelectFirstRecipe()
   RecipeRadar_FrameUpdate()

end

local function SetButtonWidths()

   local wide = not RecipeRadarListScrollFrame:IsShown()
   for i = 1, RECIPERADAR_VENDORS_DISPLAYED do
      local button = RecipeRadar_GetListButton(i)
      if (i > row) then
         button:Hide()
      elseif (button.Recipe) then
         button:SetWidth((wide and 384 or 361) - RECIPERADAR_VENDOR_OFFSET)
      else
         button:SetWidth(wide and 384 or 361)
      end
   end

end

-- Positions list button `index`; kind is "vendor" or "recipe".
local function AnchorButton(button, index, kind)

   button:ClearAllPoints()
   if (index == 1) then
      local x = (kind == "recipe") and (22 + RECIPERADAR_VENDOR_OFFSET) or 22
      button:SetPoint("TOPLEFT", RecipeRadarFrame, "TOPLEFT", x, -96)
   else
      local prev = RecipeRadar_GetListButton(index - 1)
      local x = 0
      if (last_button == "recipe" and kind == "vendor") then
         x = -RECIPERADAR_VENDOR_OFFSET
      elseif (last_button == "vendor" and kind == "recipe") then
         x = RECIPERADAR_VENDOR_OFFSET
      end
      button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x, 0)
   end
   last_button = kind

end

-- Adds the vendor and her recipes, if appropriate, to the scroll frame.
local function AddVendor(vendor)

   -- don't add the vendor if she or her recipes are filtered
   if (vendor.IsFiltered or not RecipeRadar_VendorHasRecipes(vendor)) then
      if (vendor.IsMapped) then
         RecipeRadar_Maps_RemoveVendor(vendor)
      end
      return
   end

   row = row + 1

   local offset = FauxScrollFrame_GetOffset(RecipeRadarListScrollFrame)
   local index = row - offset

   -- reset our radio button to red/off in case there are no listed vendors
   RecipeRadarMapVendorIndicator:SetVertexColor(1.0, 0, 0)

   local team_color = RecipeRadar_Teams[vendor.Team].Color

   if (index > 0 and index <= RECIPERADAR_VENDORS_DISPLAYED) then

      local button = RecipeRadar_GetListButton(index)
      AnchorButton(button, index, "vendor")

      button:UnlockHighlight()
      button:SetText(vendor.Name)
      RecipeRadar_SetButtonColors(button, team_color)
      button:SetID(index)
      button:Show()

      local subtext = button.SubText
      if (vendor.Notes and vendor.Notes ~= "") then
         local note = RecipeRadar_FormatVendorNote(vendor.Notes, true)
         VendorNameDummySubText:SetText(note .. "    ")
         subtext:SetText(note)
         button.r, button.g, button.b = team_color.r, team_color.g, team_color.b
         subtext:SetTextColor(team_color.r, team_color.g, team_color.b)
         subtext:SetPoint("LEFT", button:GetFontString(), "RIGHT", 10, 0)
         subtext:Show()
      else
         button.r = nil
         subtext:Hide()
      end

      -- the little "mapped" check mark
      local check = button.Check
      if (vendor.IsMapped) then
         VendorNameDummyText:SetText(vendor.Name .. "  ")
         local check_offset = VendorNameDummyText:GetStringWidth() + 24
         if (vendor.Notes and vendor.Notes ~= "") then
            check_offset = check_offset + VendorNameDummySubText:GetStringWidth()
         end
         check:SetPoint("TOPLEFT", button, "TOPLEFT", check_offset, 0)
         check:Show()
      else
         check:Hide()
      end

      -- unset to indicate this is a vendor header for the tooltip stuff
      button.Recipe = nil

      button:GetHighlightTexture():SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")

      if (vendor.IsExpanded ~= false) then
         has_expanded = true
         button:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
      else
         has_collapsed = true
         button:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
         return
      end

   else

      -- if the vendor is collapsed, we don't need to count her recipes
      if (vendor.IsExpanded == false) then
         has_collapsed = true
         return
      end
      has_expanded = true

   end

   RecipeRadar_SortRecipes(vendor)

   for _, recipe in ipairs(vendor.Recipes) do
      if (not RecipeRadar_IsRecipeFiltered(recipe)) then

         row = row + 1
         index = row - offset

         if (index > 0 and index <= RECIPERADAR_VENDORS_DISPLAYED) then

            local button = RecipeRadar_GetListButton(index)
            AnchorButton(button, index, "recipe")

            RecipeRadar_DrawListItem(index, recipe)

            button:SetNormalTexture(RecipeRadar_Professions[recipe.Type].Icon)
            button.Check:Hide()
            button:GetHighlightTexture():SetTexture(RECIPERADAR_IMAGE_ROOT .. "Icons\\Highlight")

            if (RecipeRadarRadarTabFrame.SelectedRecipe == recipe) then
               RecipeRadarHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -22, 0)
               RecipeRadarHighlightFrame:Show()
               button:LockHighlight()
            else
               button:UnlockHighlight()
            end

         end

      end
   end

end

function RecipeRadar_RadarTab_Update()

   if (RecipeRadar_Options.ActiveTab ~= 1) then return end

   local title = RRS("Recipe Radar")
   if (RecipeRadar_Options.CurrentRegion) then
      title = title .. " - " .. RecipeRadar_GetRegionDisplayName(RecipeRadar_Options.CurrentRegion)
      local parens = string.find(title, " %(")
      if (parens) then  -- remove parenthesized zone title
         title = string.sub(title, 1, parens - 1)
      end
   end
   TitleBarText:SetText(title)

   row, last_button = 0, ""
   has_expanded, has_collapsed = false, false

   RecipeRadarHighlightFrame:Hide()

   local region = RecipeRadar_RegionData[RecipeRadar_Options.CurrentRegion]
   if (region) then
      RecipeRadar_SortVendors(region)
      for _, vendor in ipairs(region.Vendors) do
         AddVendor(vendor)
      end
   end

   FauxScrollFrame_Update(RecipeRadarListScrollFrame, row,
         RECIPERADAR_VENDORS_DISPLAYED, RECIPERADAR_VENDOR_HEIGHT,
         nil, nil, nil, RecipeRadarHighlightFrame, 361, 384)

   SetButtonWidths()

   if (not region or not RecipeRadarRadarTabFrame.SelectedRecipe) then
      RecipeRadar_HideRecipeDetails()
   elseif (RecipeRadarRadarTabFrame.SelectedVendor) then
      RecipeRadar_SetSelection(RecipeRadarRadarTabFrame.SelectedVendor,
            RecipeRadarRadarTabFrame.SelectedRecipe)
      RecipeRadar_ShowRecipeDetails()
   end

end

local function ToggleMapped(vendor)

   if (vendor.IsMapped) then
      RecipeRadar_Maps_RemoveVendor(vendor)
   else
      RecipeRadar_Maps_AddVendor(vendor, RecipeRadar_Options.CurrentRegion)
   end

end

local function ShowContextMenu(owner, vendor)

   MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(vendor.Name)
      root:CreateButton(vendor.IsMapped and RRS("Unmap Vendor") or RRS("Map Vendor"), function()
         ToggleMapped(vendor)
         RecipeRadar_FrameUpdate()
      end)
      local expand = root:CreateButton(RRS("Expand All"), function()
         RecipeRadar_RadarTab_ExpandAll(true)
      end)
      expand:SetEnabled(has_collapsed)
      local collapse = root:CreateButton(RRS("Collapse All"), function()
         RecipeRadar_RadarTab_ExpandAll(false)
      end)
      collapse:SetEnabled(has_expanded)
   end)

end

-- Handles a vendor/recipe button click in the main scroll frame. index is
-- row + offset in the scroll frame, or -1 to select the first visible recipe.
function RecipeRadar_RadarTab_ServiceClickIndex(index, button, owner)

   local region = RecipeRadar_RegionData[RecipeRadar_Options.CurrentRegion]
   if (not region) then return end

   button = button or "LeftButton"
   RecipeRadarRadarTabFrame.SelectedIndex = index

   RecipeRadar_SortVendors(region)
   local count = 0

   for _, vendor in ipairs(region.Vendors) do

      if (not vendor.IsFiltered and RecipeRadar_VendorHasRecipes(vendor)) then

         count = count + 1

         if (count == index) then
            if (button == "LeftButton") then
               if (IsShiftKeyDown()) then
                  ToggleMapped(vendor)  -- shift-click (un)maps the vendor
               else
                  RecipeRadar_RadarTab_ToggleExpanded(vendor)
               end
            elseif (button == "RightButton" and owner) then
               ShowContextMenu(owner, vendor)
            end
            return
         end

         if (vendor.IsExpanded ~= false) then

            RecipeRadar_SortRecipes(vendor)

            for _, recipe in ipairs(vendor.Recipes) do
               if (not RecipeRadar_IsRecipeFiltered(recipe)) then

                  count = count + 1

                  -- if index is -1, this catches on the first recipe
                  if (count == index or index == -1) then
                     if (button == "LeftButton") then
                        if (IsShiftKeyDown()) then
                           ToggleMapped(vendor)
                        end
                        RecipeRadarRadarTabFrame.SelectedVendor = vendor
                        RecipeRadarRadarTabFrame.SelectedRecipe = recipe
                        RecipeRadar_SetSelection(vendor, recipe)
                        RecipeRadar_ShowRecipeDetails()
                     elseif (button == "RightButton" and owner) then
                        ShowContextMenu(owner, vendor)
                     end
                     return
                  end

               end
            end

         end

      end

   end

   -- if the index was not found, select nothing
   RecipeRadar_RadarTab_ClearSelection()
   RecipeRadar_HideRecipeDetails()

end

function RecipeRadar_RadarTab_ToggleExpanded(vendor)

   vendor.IsExpanded = (vendor.IsExpanded == false)
   RecipeRadar_RadarTab_ClearSelection()
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_RadarTab_ClearSelection()

   RecipeRadarRadarTabFrame.SelectedVendor = nil
   RecipeRadarRadarTabFrame.SelectedRecipe = nil

end
