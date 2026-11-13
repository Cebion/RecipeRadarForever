-- OptionsFrame.lua: the Recipe Radar options dialog and its Settings entry

local addonName, ns = ...

local frame = CreateFrame("Frame", "RecipeRadarOptionsFrame", UIParent, "BackdropTemplate")
frame:SetSize(330, 384)
frame:SetPoint("CENTER")
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:SetBackdrop(BACKDROP_DIALOG_32_32)
frame:Hide()
tinsert(UISpecialFrames, "RecipeRadarOptionsFrame")

local header = frame:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(256, 64)
header:SetPoint("TOP", 0, 12)
local headerText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
headerText:SetPoint("TOP", header, "TOP", 0, -14)
headerText:SetText(RRS("Recipe Radar"))

local function PlayCheckSound(checked)
   PlaySound(checked and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

local function CreateCheck(label, anchorTo, x, y, onClick)
   local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
   check:SetPoint("TOPLEFT", anchorTo, anchorTo == frame and "TOPLEFT" or "BOTTOMLEFT", x, y)
   check.Text:SetText(label)
   check:SetScript("OnClick", function(self)
      PlayCheckSound(self:GetChecked())
      onClick(self:GetChecked() and true or false)
   end)
   return check
end

local realmCheck = CreateCheck(RRS("Check Availability for Alts"), frame, 24, -30, function()
   RecipeRadar_Availability_Toggle()
end)

local minimapCheck = CreateCheck(RRS("Show Minimap Button"), realmCheck, 0, -2, function()
   RecipeRadar_MinimapButton_Toggle()
end)

local slider = CreateFrame("Slider", nil, frame, "UISliderTemplateWithLabels")
slider:SetPoint("TOP", frame, "TOP", 0, -118)
slider:SetSize(200, 17)
slider:SetMinMaxValues(0, 360)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)
slider.Text:SetText(RRS("Minimap Button Position"))
slider.Low:SetText("")
slider.High:SetText("")
slider:SetScript("OnValueChanged", function(self, value, userInput)
   if (userInput) then
      RecipeRadar_Options.MinimapButtonPosition = value
      RecipeRadar_MinimapButton_UpdatePosition()
   end
end)

local continentDropDown, regionDropDown

local autoRegionCheck = CreateCheck(RRS("Auto-select Current Region"), frame, 24, -150, function(checked)
   RecipeRadar_Options.AutoSelectRegion = checked
   if (checked) then
      RecipeRadar_NewRegion(RecipeRadar_Maps_GetPlayerRegion())
   end
   continentDropDown:SetEnabled(not checked)
   regionDropDown:SetEnabled(not checked)
   continentDropDown:GenerateMenu()
   regionDropDown:GenerateMenu()
end)

-- continent shown in the region list (may differ from the current region's)
local shownContinent

continentDropDown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
continentDropDown:SetSize(200, 22)
continentDropDown:SetPoint("TOPLEFT", autoRegionCheck, "BOTTOMLEFT", 30, -4)
continentDropDown:SetupMenu(function(_, root)
   for index = 0, 2 do
      root:CreateRadio(RecipeRadar_Continents[index],
            function(i) return i == shownContinent end,
            function(i)
               shownContinent = i
               regionDropDown:GenerateMenu()
            end,
            index)
   end
end)


regionDropDown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
regionDropDown:SetSize(200, 22)
regionDropDown:SetPoint("TOPLEFT", continentDropDown, "BOTTOMLEFT", 0, -6)
regionDropDown:SetDefaultText(RRS("Region"))
regionDropDown:SetupMenu(function(_, root)
   for _, zone in ipairs(RecipeRadar_Maps_GetZones(shownContinent or 0)) do
      -- zones without vendors are listed too (grayed), keyed by their name
      local key = zone.key or zone.name
      local radio = root:CreateRadio(zone.name,
            function(k) return k == RecipeRadar_Options.CurrentRegion end,
            function(k)
               RecipeRadar_NewRegion(k)
               RecipeRadarListScrollFrameScrollBar:SetValue(0)
            end,
            key)
      if (not zone.key) then
         radio:AddInitializer(function(button)
            button.fontString:SetTextColor(GRAY_FONT_COLOR:GetRGB())
         end)
      end
   end
   root:SetScrollMode(400)
end)

local autoMapCheck = CreateCheck(RRS("Auto-map Contributive Vendors"), frame, 24, -250, function(checked)
   RecipeRadar_Options.AutoMapVendors = checked
   if (checked) then
      RecipeRadar_InitVendorFilters()
      RecipeRadar_FrameUpdate()
   end
end)

local seasonalCheck = CreateCheck(RRS("Hide Seasonal Vendors/Recipes"), autoMapCheck, 0, -2, function(checked)
   RecipeRadar_Options.HideSeasonal = checked
   RecipeRadar_InitVendorFilters()
   RecipeRadar_InitRecipeFilters()
   RecipeRadar_FrameUpdate()
end)

local okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
okay:SetSize(100, 22)
okay:SetPoint("BOTTOM", 0, 18)
okay:SetText(OKAY)
okay:SetScript("OnClick", function()
   PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
   frame:Hide()
end)

frame:SetScript("OnShow", function()
   local opts = RecipeRadar_Options
   realmCheck:SetChecked(opts.RealmAvailability)
   minimapCheck:SetChecked(opts.ShowMinimapButton)
   slider:SetValue(opts.MinimapButtonPosition or 256)
   autoRegionCheck:SetChecked(opts.AutoSelectRegion)
   autoMapCheck:SetChecked(opts.AutoMapVendors)
   seasonalCheck:SetChecked(opts.HideSeasonal)
   shownContinent = opts.CurrentContinent or RecipeRadar_GetCurrentContinent()
   continentDropDown:SetEnabled(not opts.AutoSelectRegion)
   regionDropDown:SetEnabled(not opts.AutoSelectRegion)
   continentDropDown:GenerateMenu()
   regionDropDown:GenerateMenu()
end)

function RecipeRadar_OptionsFrame_Toggle()

   frame:SetShown(not frame:IsShown())

end

-----------------------------------------------------------------------------
-- Settings > AddOns entry: a small page with a button that opens the dialog
-----------------------------------------------------------------------------

function RecipeRadar_Options_RegisterSettings()

   if (not (Settings and Settings.RegisterCanvasLayoutCategory)) then return end

   local panel = CreateFrame("Frame")
   local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
   title:SetPoint("TOPLEFT", 16, -16)
   title:SetText(RRS("Recipe Radar") .. " " .. RECIPERADAR_VERSION)

   local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
   open:SetSize(180, 24)
   open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
   open:SetText(RRS("Options"))
   open:SetScript("OnClick", function()
      if (SettingsPanel and SettingsPanel:IsShown()) then
         SettingsPanel:Close()
      end
      frame:Show()
   end)

   local toggle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
   toggle:SetSize(180, 24)
   toggle:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -6)
   toggle:SetText(RRS("Toggle Recipe Radar"))
   toggle:SetScript("OnClick", function()
      if (SettingsPanel and SettingsPanel:IsShown()) then
         SettingsPanel:Close()
      end
      RecipeRadar_Toggle()
   end)

   local category = Settings.RegisterCanvasLayoutCategory(panel, RRS("Recipe Radar"))
   Settings.RegisterAddOnCategory(category)

end
