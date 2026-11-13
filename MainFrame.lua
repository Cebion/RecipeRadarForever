-- MainFrame.lua: main Recipe Radar window code

local addonName, ns = ...

-- Lookup helpers for the numbered list buttons defined in RecipeRadar.xml.
function RRF_GetListButton(index)
   return _G["RRFVendor" .. index]
end

function RRF_GetMapScroll(index)
   return _G["RRFScroll" .. index]
end

function RRF_MainFrame_Init()

   RRFFrame:RegisterForDrag("LeftButton")

   RRFListScrollFrameScrollBar:SetMinMaxValues(0, 0)
   RRFListScrollFrameScrollBar:SetValue(0)

   RRFOptionsButton:SetText(RRF_S("Options"))
   -- the radio icon keeps its tooltip; its label makes room for the search box
   RRFMapVendorIndicatorText:Hide()
   RRFMapVendorIndicatorFrame:SetHitRectInsets(0, 0, 0, 0)

   local search = CreateFrame("EditBox", "RRFSearchBox", RRFFrame, "SearchBoxTemplate")
   search:SetSize(150, 20)
   search:SetPoint("LEFT", RRFMapVendorIndicatorFrame, "RIGHT", 8, 0)
   search:SetMaxLetters(40)
   -- short hint on one line; the full explanation is in the tooltip
   search.Instructions:SetText(RRF_S("Search"))
   search.Instructions:SetWordWrap(false)
   search:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(RRF_S("Search"))
      GameTooltip:AddLine(RRF_S("Filters the list by recipe, vendor or zone name."), 1, 1, 1, true)
      GameTooltip:Show()
   end)
   search:HookScript("OnLeave", GameTooltip_Hide)
   search:HookScript("OnTextChanged", function(self)
      RRF_SetSearch(self:GetText())
      RRF_RadarTab_ClearSelection()
      RRF_RecipesTab_ClearSelection()
      RRFListScrollFrameScrollBar:SetValue(0)
      RRF_SelectFirstRecipe()
      RRF_FrameUpdate()
   end)

   RRF_UpdateLock()

   if (RecipeRadarForever_Options.ActiveTab == 2) then
      RRF_RecipesTab_Init()
   else
      RRF_RadarTab_Init()
   end

end

-- Also the TOC AddonCompartmentFunc and the key binding.
function RRF_Toggle()

   if (RRFFrame:IsShown()) then
      RRFFrame:Hide()
   else
      RRF_Frame_Show()
   end

end

function RRF_Frame_Show()

   RRFFrame:Show()

   -- the scanners are cheap; run them so the lists are current on open
   RRF_SkillDB_ScanAll()
   RRF_SkillDB_ScanKnownRecipes()

   RRF_InitVendorFilters()
   RRF_InitRecipeFilters()
   RRF_FrameUpdate()

end

function RRF_FrameUpdate()

   if (not RRFFrame:IsShown()) then return end

   if (RecipeRadarForever_Options.ActiveTab == 1) then
      RRF_RadarTab_Update()
   else
      RRF_RecipesTab_Update()
   end

end

------------------------------------------------------------------------
-- Tab code
------------------------------------------------------------------------

-- Draws the borders around each tab according to which is active.
function RRF_SetActiveTab(id)

   local active_tab_height, background_tab_height = 33, 29

   if (id == 1) then
      RRFRadarTabFrameMiddle:SetHeight(active_tab_height)
      RRFRadarTabFrameRight:SetHeight(active_tab_height)
      RRFRecipesTabFrameLeft:SetHeight(background_tab_height)
      RRFRecipesTabFrameMiddle:SetHeight(background_tab_height)
      RRFRecipesTabFrameRight:SetHeight(background_tab_height)
   else
      RRFRadarTabFrameMiddle:SetHeight(background_tab_height)
      RRFRadarTabFrameRight:SetHeight(background_tab_height)
      RRFRecipesTabFrameLeft:SetHeight(active_tab_height)
      RRFRecipesTabFrameMiddle:SetHeight(active_tab_height)
      RRFRecipesTabFrameRight:SetHeight(active_tab_height)
   end
   RecipeRadarForever_Options.ActiveTab = id

end

local function Brighten(v)
   return math.min(1, v + RRF_Colors.Highlight)
end

-- Sets the button text color; the hover tint is derived from it.
function RRF_SetButtonColors(button, text_color)

   button.textColor = text_color
   local tint = button.isHovered and Brighten or function(v) return v end
   button:GetFontString():SetTextColor(tint(text_color.r), tint(text_color.g), tint(text_color.b))

end

function RRF_VendorButton_OnEnter(self)

   self.isHovered = true
   local c = self.textColor
   if (c) then
      self:GetFontString():SetTextColor(Brighten(c.r), Brighten(c.g), Brighten(c.b))
   end
   if (self.r) then
      self.SubText:SetTextColor(Brighten(self.r), Brighten(self.g), Brighten(self.b))
   end
   if (RecipeRadarForever_Options.RealmAvailability and self.Recipe) then
      RRF_AvailabilityTooltip_Hide()
      RRF_Availability_CreateTooltip(self.Recipe)
      RRF_AvailabilityTooltip_Show(self)
   end

end

function RRF_VendorButton_OnLeave(self)

   self.isHovered = false
   local c = self.textColor
   if (c) then
      self:GetFontString():SetTextColor(c.r, c.g, c.b)
   end
   if (self.r) then
      self.SubText:SetTextColor(self.r, self.g, self.b)
   end
   RRFAvailabilityTooltip:Hide()

end

-- Common drawing code for list items in the scroll frame.
function RRF_DrawListItem(index, recipe)

   local button = RRF_GetListButton(index)

   -- get and set the text color according to recipe availability
   local name, _, _, _, _, _, _, cached = RRF_GetSafeItemInfo(recipe.ID)
   local indicator = RRF_Availability_GetIndicator(recipe)

   if (not cached) then
      RRF_SetButtonColors(button, RRF_Colors.UncachedRecipe)
   else
      RRF_SetButtonColors(button, RRF_Colors.LightGray)
   end

   if (RecipeRadarForever_Options.RealmAvailability) then
      button:SetText(name .. indicator)
   else
      button:SetText(name)
   end
   button:SetID(index)
   button:Show()

   -- drawing code for the little subtext field
   local subtext = button.SubText
   if (not RecipeRadarForever_Options.RealmAvailability) then
      local avail = RRF_Availability_GetKey(recipe)
      local color = avail and RRF_Availabilities[avail].Color
            or RRF_Colors.UncachedRecipe
      button.r, button.g, button.b = color.r, color.g, color.b
      subtext:SetText(indicator)
      subtext:SetTextColor(button.r, button.g, button.b)
      subtext:SetPoint("LEFT", button:GetFontString(), "RIGHT", 10, 0)
      subtext:Show()
   else
      button.r = nil
      subtext:Hide()
   end

   -- provide information for the availability tooltip
   button.Recipe = recipe

end

------------------------------------------------------------------------
-- Base vendor/recipe selection code
------------------------------------------------------------------------

-- OnClick handler for the vendor/recipe buttons in the scroll frame.
function RRF_VendorButton_OnClick(self, button)

   local offset = FauxScrollFrame_GetOffset(RRFListScrollFrame)
   local index = self:GetID() + offset

   RRF_ServiceClickIndex(index, button, self)

   if (button == "LeftButton") then
      RRF_FrameUpdate()
   end

end

-- Selects the first visible recipe (not vendor).
function RRF_SelectFirstRecipe()

   RRF_ServiceClickIndex(-1)

end

-- Abstracts front for click handlers. owner is the clicked list button
-- (used to anchor context menus).
function RRF_ServiceClickIndex(index, button, owner)

   if (RecipeRadarForever_Options.ActiveTab == 1) then
      RRF_RadarTab_ServiceClickIndex(index, button, owner)
   else
      RRF_RecipesTab_ServiceClickIndex(index, button, owner)
   end

end

------------------------------------------------------------------------
-- Recipe details and map frames
------------------------------------------------------------------------

-- Text shown instead of the money frame for non-gold or unknown prices.
function RRF_GetCostText()

   if (not ns.costText) then
      ns.costText = RRFDetailFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      ns.costText:SetPoint("LEFT", RRFRecipeDetailCostText, "RIGHT", 5, 0)
      ns.costText:Hide()
   end
   return ns.costText

end

function RRF_ShowRecipeDetails()

   RRFRecipeDetailName:Show()
   RRFRecipeDetailIcon:Show()
   RRFRecipeDetailCostText:Show()

end

function RRF_HideRecipeDetails()

   RRFRecipeDetailName:Hide()
   RRFRecipeDetailIcon:Hide()
   RRFRecipeDetailCostText:Hide()
   RRFRecipeDetailMoneyFrame:Hide()
   RRF_GetCostText():Hide()
   RRFRecipeDetailNoteText:Hide()
   RRFRecipeDetailRequirements:Hide()
   RRFRegionMap:Hide()
   RRF_Maps_HideZoneArt()

   -- reset the mapped indicator to red/off
   RRFMapVendorIndicator:SetVertexColor(1.0, 0, 0)

   for i = 1, RRF_MaxVendorCoordinates do
      RRF_GetMapScroll(i):Hide()
   end

end

-- When a recipe is actually selected, this function handles the
-- subsequent drawing in the lower details and map frames.
function RRF_SetSelection(vendor, recipe, region_name)

   local name, link, colorcode, _, _, _, texture, cached =
         RRF_GetSafeItemInfo(recipe.ID)

   RRFRecipeDetailName:SetText(name)

   RRFRecipeDetailIcon:SetNormalTexture(texture)
   RRFRecipeDetailIcon.NeedsUpdate = not cached
   RRFRecipeDetailIcon.ItemID = recipe.ID
   RRFRecipeDetailIcon.Hyperlink = RRF_GetHyperlinkByParts(name, link, colorcode)

   -- gold price in the money frame; currencies, tokens and unknown prices as text
   local cost = RRF_GetRecipeCost(recipe)
   if (type(cost) == "number") then
      SetMoneyFrameColor("RRFRecipeDetailMoneyFrame", GetMoney() >= cost and "default" or "red")
      MoneyFrame_Update("RRFRecipeDetailMoneyFrame", cost)
      RRFRecipeDetailMoneyFrame:Show()
      RRF_GetCostText():Hide()
   else
      RRFRecipeDetailMoneyFrame:Hide()
      RRF_GetCostText():SetText(cost)
      RRF_GetCostText():Show()
   end

   -- some vendors have special requirements
   local reqs = RRF_GetRecipeReqsString(recipe)
   if (reqs) then
      RRFRecipeDetailRequirements:SetText(reqs)
      RRFRecipeDetailNoteText:Show()
      RRFRecipeDetailRequirements:Show()
   else
      RRFRecipeDetailNoteText:Hide()
      RRFRecipeDetailRequirements:Hide()
   end

   if (vendor.IsMapped) then
      RRFMapVendorIndicator:SetVertexColor(0, 1.0, 0)
   else
      RRFMapVendorIndicator:SetVertexColor(1.0, 0, 0)
   end

   local region = RRF_RegionData[region_name or RecipeRadarForever_Options.CurrentRegion]

   if (vendor.Coordinates and region and
         RRF_Maps_DrawZoneArt(RRFMapFrame, region.UiMapID)) then

      -- one icon per known location (roaming vendors have several)
      for i = 1, RRF_MaxVendorCoordinates do
         local scroll_icon = RRF_GetMapScroll(i)
         local coords = vendor.Coordinates[i]
         if (not coords) then
            scroll_icon:Hide()
         else
            local x = RRFMapFrame:GetWidth() * coords.x
            local y = RRFMapFrame:GetHeight() * -coords.y
            scroll_icon.Vendor = vendor
            scroll_icon:ClearAllPoints()
            scroll_icon:SetPoint("CENTER", RRFMapFrame, "TOPLEFT", x, y)
            scroll_icon:Show()
         end
      end

   else  -- no coordinates or no map art (instances): no map

      RRF_Maps_HideZoneArt()
      for i = 1, RRF_MaxVendorCoordinates do
         RRF_GetMapScroll(i):Hide()
      end

   end

end

function RRF_RecipeDetailIcon_OnEnter(self)

   GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
   if (self.ItemID) then
      GameTooltip:SetItemByID(self.ItemID)
   end
   GameTooltip:Show()

end

function RRF_RecipeDetailIcon_OnLeave(self)

   if (self.NeedsUpdate) then
      self.NeedsUpdate = false
      RRF_FrameUpdate()
   end
   GameTooltip:Hide()

end

function RRF_RecipeDetailIcon_OnClick(self, button)

   if (button == "LeftButton" and IsModifiedClick("CHATLINK") and self.Hyperlink) then
      ChatFrameUtil.InsertLink(self.Hyperlink)
   end

end

-------------------------------------------------------------------------
-- Frame Movement
-------------------------------------------------------------------------

function RRF_ToggleLock()

   RecipeRadarForever_Options.Locked = not RecipeRadarForever_Options.Locked
   RRF_UpdateLock()

end

function RRF_UpdateLock()

   if (RecipeRadarForever_Options.Locked) then
      RRFLockNormal:SetTexture(RRF_IMAGE_ROOT .. "Frame\\LockButton-Locked-Up")
      RRFLockPushed:SetTexture(RRF_IMAGE_ROOT .. "Frame\\LockButton-Locked-Down")
   else
      RRFLockNormal:SetTexture(RRF_IMAGE_ROOT .. "Frame\\LockButton-Unlocked-Up")
      RRFLockPushed:SetTexture(RRF_IMAGE_ROOT .. "Frame\\LockButton-Unlocked-Down")
   end

end

function RRF_StartMoving()

   if (not RecipeRadarForever_Options.Locked) then
      RRFFrame:StartMoving()
   end

end
