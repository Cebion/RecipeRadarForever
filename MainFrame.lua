-- MainFrame.lua: main Recipe Radar window code

local addonName, ns = ...

-- Lookup helpers for the numbered list buttons defined in RecipeRadar.xml.
function RecipeRadar_GetListButton(index)
   return _G["RecipeRadarVendor" .. index]
end

function RecipeRadar_GetMapScroll(index)
   return _G["RecipeRadarScroll" .. index]
end

function RecipeRadar_MainFrame_Init()

   RecipeRadarFrame:RegisterForDrag("LeftButton")

   RecipeRadarListScrollFrameScrollBar:SetMinMaxValues(0, 0)
   RecipeRadarListScrollFrameScrollBar:SetValue(0)

   RecipeRadarOptionsButton:SetText(RRS("Options"))
   RecipeRadarMapVendorIndicatorText:SetText(RRS("Locate Vendor on Map"))
   RecipeRadar_UpdateLock()

   if (RecipeRadar_Options.ActiveTab == 2) then
      RecipeRadar_RecipesTab_Init()
   else
      RecipeRadar_RadarTab_Init()
   end

end

-- Also the TOC AddonCompartmentFunc and the key binding.
function RecipeRadar_Toggle()

   if (RecipeRadarFrame:IsShown()) then
      RecipeRadarFrame:Hide()
   else
      RecipeRadar_Frame_Show()
   end

end

function RecipeRadar_Frame_Show()

   RecipeRadarFrame:Show()

   -- the scanners are cheap; run them so the lists are current on open
   RecipeRadar_SkillDB_ScanAll()
   RecipeRadar_SkillDB_ScanKnownRecipes()

   RecipeRadar_InitVendorFilters()
   RecipeRadar_InitRecipeFilters()
   RecipeRadar_FrameUpdate()

end

function RecipeRadar_FrameUpdate()

   if (not RecipeRadarFrame:IsShown()) then return end

   if (RecipeRadar_Options.ActiveTab == 1) then
      RecipeRadar_RadarTab_Update()
   else
      RecipeRadar_RecipesTab_Update()
   end

end

------------------------------------------------------------------------
-- Tab code
------------------------------------------------------------------------

-- Draws the borders around each tab according to which is active.
function RecipeRadar_SetActiveTab(id)

   local active_tab_height, background_tab_height = 33, 29

   if (id == 1) then
      RecipeRadarRadarTabFrameMiddle:SetHeight(active_tab_height)
      RecipeRadarRadarTabFrameRight:SetHeight(active_tab_height)
      RecipeRadarRecipesTabFrameLeft:SetHeight(background_tab_height)
      RecipeRadarRecipesTabFrameMiddle:SetHeight(background_tab_height)
      RecipeRadarRecipesTabFrameRight:SetHeight(background_tab_height)
   else
      RecipeRadarRadarTabFrameMiddle:SetHeight(background_tab_height)
      RecipeRadarRadarTabFrameRight:SetHeight(background_tab_height)
      RecipeRadarRecipesTabFrameLeft:SetHeight(active_tab_height)
      RecipeRadarRecipesTabFrameMiddle:SetHeight(active_tab_height)
      RecipeRadarRecipesTabFrameRight:SetHeight(active_tab_height)
   end
   RecipeRadar_Options.ActiveTab = id

end

local function Brighten(v)
   return math.min(1, v + RecipeRadar_Colors.Highlight)
end

-- Sets the button text color; the hover tint is derived from it.
function RecipeRadar_SetButtonColors(button, text_color)

   button.textColor = text_color
   local tint = button.isHovered and Brighten or function(v) return v end
   button:GetFontString():SetTextColor(tint(text_color.r), tint(text_color.g), tint(text_color.b))

end

function RecipeRadar_VendorButton_OnEnter(self)

   self.isHovered = true
   local c = self.textColor
   if (c) then
      self:GetFontString():SetTextColor(Brighten(c.r), Brighten(c.g), Brighten(c.b))
   end
   if (self.r) then
      self.SubText:SetTextColor(Brighten(self.r), Brighten(self.g), Brighten(self.b))
   end
   if (RecipeRadar_Options.RealmAvailability and self.Recipe) then
      RecipeRadar_AvailabilityTooltip_Hide()
      RecipeRadar_Availability_CreateTooltip(self.Recipe)
      RecipeRadar_AvailabilityTooltip_Show(self)
   end

end

function RecipeRadar_VendorButton_OnLeave(self)

   self.isHovered = false
   local c = self.textColor
   if (c) then
      self:GetFontString():SetTextColor(c.r, c.g, c.b)
   end
   if (self.r) then
      self.SubText:SetTextColor(self.r, self.g, self.b)
   end
   RecipeRadarAvailabilityTooltip:Hide()

end

-- Common drawing code for list items in the scroll frame.
function RecipeRadar_DrawListItem(index, recipe)

   local button = RecipeRadar_GetListButton(index)

   -- get and set the text color according to recipe availability
   local name, _, _, _, _, _, _, cached = RecipeRadar_GetSafeItemInfo(recipe.ID)
   local indicator = RecipeRadar_Availability_GetIndicator(recipe)

   if (not cached) then
      RecipeRadar_SetButtonColors(button, RecipeRadar_Colors.UncachedRecipe)
   else
      RecipeRadar_SetButtonColors(button, RecipeRadar_Colors.LightGray)
   end

   if (RecipeRadar_Options.RealmAvailability) then
      button:SetText(name .. indicator)
   else
      button:SetText(name)
   end
   button:SetID(index)
   button:Show()

   -- drawing code for the little subtext field
   local subtext = button.SubText
   if (not RecipeRadar_Options.RealmAvailability) then
      local avail = RecipeRadar_Availability_GetKey(recipe)
      local color = avail and RecipeRadar_Availabilities[avail].Color
            or RecipeRadar_Colors.UncachedRecipe
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
function RecipeRadar_VendorButton_OnClick(self, button)

   local offset = FauxScrollFrame_GetOffset(RecipeRadarListScrollFrame)
   local index = self:GetID() + offset

   RecipeRadar_ServiceClickIndex(index, button, self)

   if (button == "LeftButton") then
      RecipeRadar_FrameUpdate()
   end

end

-- Selects the first visible recipe (not vendor).
function RecipeRadar_SelectFirstRecipe()

   RecipeRadar_ServiceClickIndex(-1)

end

-- Abstracts front for click handlers. owner is the clicked list button
-- (used to anchor context menus).
function RecipeRadar_ServiceClickIndex(index, button, owner)

   if (RecipeRadar_Options.ActiveTab == 1) then
      RecipeRadar_RadarTab_ServiceClickIndex(index, button, owner)
   else
      RecipeRadar_RecipesTab_ServiceClickIndex(index, button, owner)
   end

end

------------------------------------------------------------------------
-- Recipe details and map frames
------------------------------------------------------------------------

-- Text shown instead of the money frame for non-gold or unknown prices.
function RecipeRadar_GetCostText()

   if (not ns.costText) then
      ns.costText = RecipeRadarDetailFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      ns.costText:SetPoint("LEFT", RecipeDetailCostText, "RIGHT", 5, 0)
      ns.costText:Hide()
   end
   return ns.costText

end

function RecipeRadar_ShowRecipeDetails()

   RecipeDetailName:Show()
   RecipeDetailIcon:Show()
   RecipeDetailCostText:Show()

end

function RecipeRadar_HideRecipeDetails()

   RecipeDetailName:Hide()
   RecipeDetailIcon:Hide()
   RecipeDetailCostText:Hide()
   RecipeDetailMoneyFrame:Hide()
   RecipeRadar_GetCostText():Hide()
   RecipeDetailNoteText:Hide()
   RecipeDetailRequirements:Hide()
   RecipeRadarRegionMap:Hide()
   RecipeRadar_Maps_HideZoneArt()

   -- reset the mapped indicator to red/off
   RecipeRadarMapVendorIndicator:SetVertexColor(1.0, 0, 0)

   for i = 1, RecipeRadar_MaxVendorCoordinates do
      RecipeRadar_GetMapScroll(i):Hide()
   end

end

-- When a recipe is actually selected, this function handles the
-- subsequent drawing in the lower details and map frames.
function RecipeRadar_SetSelection(vendor, recipe, region_name)

   local name, link, colorcode, _, _, _, texture, cached =
         RecipeRadar_GetSafeItemInfo(recipe.ID)

   RecipeDetailName:SetText(name)

   RecipeDetailIcon:SetNormalTexture(texture)
   RecipeDetailIcon.NeedsUpdate = not cached
   RecipeDetailIcon.ItemID = recipe.ID
   RecipeDetailIcon.Hyperlink = RecipeRadar_GetHyperlinkByParts(name, link, colorcode)

   -- gold price in the money frame; currencies, tokens and unknown prices as text
   local cost = RecipeRadar_GetRecipeCost(recipe)
   if (type(cost) == "number") then
      SetMoneyFrameColor("RecipeDetailMoneyFrame", GetMoney() >= cost and "default" or "red")
      MoneyFrame_Update("RecipeDetailMoneyFrame", cost)
      RecipeDetailMoneyFrame:Show()
      RecipeRadar_GetCostText():Hide()
   else
      RecipeDetailMoneyFrame:Hide()
      RecipeRadar_GetCostText():SetText(cost)
      RecipeRadar_GetCostText():Show()
   end

   -- some vendors have special requirements
   local reqs = RecipeRadar_GetRecipeReqsString(recipe)
   if (reqs) then
      RecipeDetailRequirements:SetText(reqs)
      RecipeDetailNoteText:Show()
      RecipeDetailRequirements:Show()
   else
      RecipeDetailNoteText:Hide()
      RecipeDetailRequirements:Hide()
   end

   if (vendor.IsMapped) then
      RecipeRadarMapVendorIndicator:SetVertexColor(0, 1.0, 0)
   else
      RecipeRadarMapVendorIndicator:SetVertexColor(1.0, 0, 0)
   end

   local region = RecipeRadar_RegionData[region_name or RecipeRadar_Options.CurrentRegion]

   if (vendor.Coordinates and region and
         RecipeRadar_Maps_DrawZoneArt(RecipeRadarMapFrame, region.UiMapID)) then

      -- one icon per known location (roaming vendors have several)
      for i = 1, RecipeRadar_MaxVendorCoordinates do
         local scroll_icon = RecipeRadar_GetMapScroll(i)
         local coords = vendor.Coordinates[i]
         if (not coords) then
            scroll_icon:Hide()
         else
            local x = RecipeRadarMapFrame:GetWidth() * coords.x
            local y = RecipeRadarMapFrame:GetHeight() * -coords.y
            scroll_icon.Vendor = vendor
            scroll_icon:ClearAllPoints()
            scroll_icon:SetPoint("CENTER", RecipeRadarMapFrame, "TOPLEFT", x, y)
            scroll_icon:Show()
         end
      end

   else  -- no coordinates or no map art (instances): no map

      RecipeRadar_Maps_HideZoneArt()
      for i = 1, RecipeRadar_MaxVendorCoordinates do
         RecipeRadar_GetMapScroll(i):Hide()
      end

   end

end

function RecipeRadar_RecipeDetailIcon_OnEnter(self)

   GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
   if (self.ItemID) then
      GameTooltip:SetItemByID(self.ItemID)
   end
   GameTooltip:Show()

end

function RecipeRadar_RecipeDetailIcon_OnLeave(self)

   if (self.NeedsUpdate) then
      self.NeedsUpdate = false
      RecipeRadar_FrameUpdate()
   end
   GameTooltip:Hide()

end

function RecipeRadar_RecipeDetailIcon_OnClick(self, button)

   if (button == "LeftButton" and IsModifiedClick("CHATLINK") and self.Hyperlink) then
      ChatFrameUtil.InsertLink(self.Hyperlink)
   end

end

-------------------------------------------------------------------------
-- Frame Movement
-------------------------------------------------------------------------

function RecipeRadar_ToggleLock()

   RecipeRadar_Options.Locked = not RecipeRadar_Options.Locked
   RecipeRadar_UpdateLock()

end

function RecipeRadar_UpdateLock()

   if (RecipeRadar_Options.Locked) then
      RecipeRadarLockNormal:SetTexture(RECIPERADAR_IMAGE_ROOT .. "Frame\\LockButton-Locked-Up")
      RecipeRadarLockPushed:SetTexture(RECIPERADAR_IMAGE_ROOT .. "Frame\\LockButton-Locked-Down")
   else
      RecipeRadarLockNormal:SetTexture(RECIPERADAR_IMAGE_ROOT .. "Frame\\LockButton-Unlocked-Up")
      RecipeRadarLockPushed:SetTexture(RECIPERADAR_IMAGE_ROOT .. "Frame\\LockButton-Unlocked-Down")
   end

end

function RecipeRadar_StartMoving()

   if (not RecipeRadar_Options.Locked) then
      RecipeRadarFrame:StartMoving()
   end

end
