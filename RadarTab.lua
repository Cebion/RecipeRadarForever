-- RadarTab.lua: handles clicking and drawing for the Radar tab

local addonName, ns = ...

-- per-update drawing state
local row, last_button = 0, ""
local has_expanded, has_collapsed = false, false

function RRF_RadarTab_Init()

   RRF_Prof1DropDown:Show()
   RRF_Prof2DropDown:Hide()

   RRF_SetActiveTab(1)

   RRF_RadarTab_Update()
   RRFListScrollFrameScrollBar:SetValue(RRFRadarTabFrame.ScrollValue or 0)

end

function RRF_RadarTab_OnClick()

   if (RecipeRadarForever_Options.ActiveTab == 1) then return end

   PlaySound(SOUNDKIT.IG_SPELLBOOK_CLOSE)
   RRF_RadarTab_Init()

end

function RRF_RadarTab_ExpandAll(expand)

   local region = RRF_RegionData[RecipeRadarForever_Options.CurrentRegion]
   if (not region) then return end

   for _, vendor in ipairs(region.Vendors) do
      vendor.IsExpanded = expand
   end

   RRF_SelectFirstRecipe()
   RRF_FrameUpdate()

end

local function SetButtonWidths()

   local wide = not RRFListScrollFrame:IsShown()
   for i = 1, RRF_VENDORS_DISPLAYED do
      local button = RRF_GetListButton(i)
      if (i > row) then
         button:Hide()
      elseif (button.Recipe) then
         button:SetWidth((wide and 384 or 361) - RRF_VENDOR_OFFSET)
      else
         button:SetWidth(wide and 384 or 361)
      end
   end

end

-- Positions list button `index`; kind is "vendor" or "recipe".
local function AnchorButton(button, index, kind)

   button:ClearAllPoints()
   if (index == 1) then
      local x = (kind == "recipe") and (22 + RRF_VENDOR_OFFSET) or 22
      button:SetPoint("TOPLEFT", RRFFrame, "TOPLEFT", x, -96)
   else
      local prev = RRF_GetListButton(index - 1)
      local x = 0
      if (last_button == "recipe" and kind == "vendor") then
         x = -RRF_VENDOR_OFFSET
      elseif (last_button == "vendor" and kind == "recipe") then
         x = RRF_VENDOR_OFFSET
      end
      button:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", x, 0)
   end
   last_button = kind

end

-- Adds the vendor and her recipes, if appropriate, to the scroll frame.
local function AddVendor(vendor)

   -- don't add the vendor if she or her recipes are filtered
   if (vendor.IsFiltered or not RRF_VendorHasRecipes(vendor)) then
      if (vendor.IsMapped) then
         RRF_Maps_RemoveVendor(vendor)
      end
      return
   end

   row = row + 1

   local offset = FauxScrollFrame_GetOffset(RRFListScrollFrame)
   local index = row - offset

   -- reset our radio button to red/off in case there are no listed vendors
   RRFMapVendorIndicator:SetVertexColor(1.0, 0, 0)

   local team_color = RRF_Teams[vendor.Team].Color

   if (index > 0 and index <= RRF_VENDORS_DISPLAYED) then

      local button = RRF_GetListButton(index)
      AnchorButton(button, index, "vendor")

      button:UnlockHighlight()
      button:SetText(vendor.Name)
      RRF_SetButtonColors(button, team_color)
      button:SetID(index)
      button:Show()

      local subtext = button.SubText
      if (vendor.Notes and vendor.Notes ~= "") then
         local note = RRF_FormatVendorNote(vendor.Notes, true)
         RRFVendorNameDummySubText:SetText(note .. "    ")
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
         RRFVendorNameDummyText:SetText(vendor.Name .. "  ")
         local check_offset = RRFVendorNameDummyText:GetStringWidth() + 24
         if (vendor.Notes and vendor.Notes ~= "") then
            check_offset = check_offset + RRFVendorNameDummySubText:GetStringWidth()
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

   RRF_SortRecipes(vendor)

   for _, recipe in ipairs(vendor.Recipes) do
      if (not RRF_IsRecipeFiltered(recipe)) then

         row = row + 1
         index = row - offset

         if (index > 0 and index <= RRF_VENDORS_DISPLAYED) then

            local button = RRF_GetListButton(index)
            AnchorButton(button, index, "recipe")

            RRF_DrawListItem(index, recipe)

            button:SetNormalTexture(RRF_Professions[recipe.Type].Icon)
            button.Check:Hide()
            button:GetHighlightTexture():SetTexture(RRF_IMAGE_ROOT .. "Icons\\Highlight")

            if (RRFRadarTabFrame.SelectedRecipe == recipe) then
               RRFHighlightFrame:SetPoint("TOPLEFT", button, "TOPLEFT", -22, 0)
               RRFHighlightFrame:Show()
               button:LockHighlight()
            else
               button:UnlockHighlight()
            end

         end

      end
   end

end

function RRF_RadarTab_Update()

   if (RecipeRadarForever_Options.ActiveTab ~= 1) then return end

   local title = RRF_S("Recipe Radar Forever")
   if (RecipeRadarForever_Options.CurrentRegion) then
      title = title .. " - " .. RRF_GetRegionDisplayName(RecipeRadarForever_Options.CurrentRegion)
      local parens = string.find(title, " %(")
      if (parens) then  -- remove parenthesized zone title
         title = string.sub(title, 1, parens - 1)
      end
   end
   RRFTitleBarText:SetText(title)

   row, last_button = 0, ""
   has_expanded, has_collapsed = false, false

   RRFHighlightFrame:Hide()

   local region = RRF_RegionData[RecipeRadarForever_Options.CurrentRegion]
   if (region) then
      RRF_SortVendors(region)
      for _, vendor in ipairs(region.Vendors) do
         AddVendor(vendor)
      end
   end

   FauxScrollFrame_Update(RRFListScrollFrame, row,
         RRF_VENDORS_DISPLAYED, RRF_VENDOR_HEIGHT,
         nil, nil, nil, RRFHighlightFrame, 361, 384)

   SetButtonWidths()

   if (not region or not RRFRadarTabFrame.SelectedRecipe) then
      RRF_HideRecipeDetails()
   elseif (RRFRadarTabFrame.SelectedVendor) then
      RRF_SetSelection(RRFRadarTabFrame.SelectedVendor,
            RRFRadarTabFrame.SelectedRecipe)
      RRF_ShowRecipeDetails()
   end

end

local function ToggleMapped(vendor)

   if (vendor.IsMapped) then
      RRF_Maps_RemoveVendor(vendor)
   else
      RRF_Maps_AddVendor(vendor, RecipeRadarForever_Options.CurrentRegion)
   end

end

local function ShowContextMenu(owner, vendor)

   MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(vendor.Name)
      root:CreateButton(vendor.IsMapped and RRF_S("Unmap Vendor") or RRF_S("Map Vendor"), function()
         ToggleMapped(vendor)
         RRF_FrameUpdate()
      end)
      local expand = root:CreateButton(RRF_S("Expand All"), function()
         RRF_RadarTab_ExpandAll(true)
      end)
      expand:SetEnabled(has_collapsed)
      local collapse = root:CreateButton(RRF_S("Collapse All"), function()
         RRF_RadarTab_ExpandAll(false)
      end)
      collapse:SetEnabled(has_expanded)
   end)

end

-- Handles a vendor/recipe button click in the main scroll frame. index is
-- row + offset in the scroll frame, or -1 to select the first visible recipe.
function RRF_RadarTab_ServiceClickIndex(index, button, owner)

   local region = RRF_RegionData[RecipeRadarForever_Options.CurrentRegion]
   if (not region) then return end

   button = button or "LeftButton"
   RRFRadarTabFrame.SelectedIndex = index

   RRF_SortVendors(region)
   local count = 0

   for _, vendor in ipairs(region.Vendors) do

      if (not vendor.IsFiltered and RRF_VendorHasRecipes(vendor)) then

         count = count + 1

         if (count == index) then
            if (button == "LeftButton") then
               if (IsShiftKeyDown()) then
                  ToggleMapped(vendor)  -- shift-click (un)maps the vendor
               else
                  RRF_RadarTab_ToggleExpanded(vendor)
               end
            elseif (button == "RightButton" and owner) then
               ShowContextMenu(owner, vendor)
            end
            return
         end

         if (vendor.IsExpanded ~= false) then

            RRF_SortRecipes(vendor)

            for _, recipe in ipairs(vendor.Recipes) do
               if (not RRF_IsRecipeFiltered(recipe)) then

                  count = count + 1

                  -- if index is -1, this catches on the first recipe
                  if (count == index or index == -1) then
                     if (button == "LeftButton") then
                        if (IsShiftKeyDown()) then
                           ToggleMapped(vendor)
                        end
                        RRFRadarTabFrame.SelectedVendor = vendor
                        RRFRadarTabFrame.SelectedRecipe = recipe
                        RRF_SetSelection(vendor, recipe)
                        RRF_ShowRecipeDetails()
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
   RRF_RadarTab_ClearSelection()
   RRF_HideRecipeDetails()

end

function RRF_RadarTab_ToggleExpanded(vendor)

   vendor.IsExpanded = (vendor.IsExpanded == false)
   RRF_RadarTab_ClearSelection()
   RRF_FrameUpdate()

end

function RRF_RadarTab_ClearSelection()

   RRFRadarTabFrame.SelectedVendor = nil
   RRFRadarTabFrame.SelectedRecipe = nil

end
