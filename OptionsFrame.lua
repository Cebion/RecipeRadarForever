-- OptionsFrame.lua: the Recipe Radar options dialog and its Settings entry

local addonName, ns = ...

local frame = CreateFrame("Frame", "RRFOptionsFrame", UIParent, "BackdropTemplate")
frame:SetSize(330, 430)
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
tinsert(UISpecialFrames, "RRFOptionsFrame")

local header = frame:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetSize(256, 64)
header:SetPoint("TOP", 0, 12)
local headerText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
headerText:SetPoint("TOP", header, "TOP", 0, -14)
headerText:SetText(RRF_S("Recipe Radar Forever"))

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

local realmCheck = CreateCheck(RRF_S("Check Availability for Alts"), frame, 24, -30, function()
   RRF_Availability_Toggle()
end)

local minimapCheck = CreateCheck(RRF_S("Show Minimap Button"), realmCheck, 0, -2, function()
   RRF_MinimapButton_Toggle()
end)

local slider = CreateFrame("Slider", nil, frame, "UISliderTemplateWithLabels")
slider:SetPoint("TOP", frame, "TOP", 0, -118)
slider:SetSize(200, 17)
slider:SetMinMaxValues(0, 360)
slider:SetValueStep(1)
slider:SetObeyStepOnDrag(true)
slider.Text:SetText(RRF_S("Minimap Button Position"))
slider.Low:SetText("")
slider.High:SetText("")
slider:SetScript("OnValueChanged", function(self, value, userInput)
   if (userInput) then
      RecipeRadarForever_Options.MinimapButtonPosition = value
      RRF_MinimapButton_UpdatePosition()
   end
end)

local continentDropDown, regionDropDown

local autoRegionCheck = CreateCheck(RRF_S("Auto-select Current Region"), frame, 24, -150, function(checked)
   RecipeRadarForever_Options.AutoSelectRegion = checked
   if (checked) then
      RRF_NewRegion(RRF_Maps_GetPlayerRegion())
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
      root:CreateRadio(RRF_Continents[index],
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
regionDropDown:SetDefaultText(RRF_S("Region"))
regionDropDown:SetupMenu(function(_, root)
   for _, zone in ipairs(RRF_Maps_GetZones(shownContinent or 0)) do
      -- zones without vendors are listed too (grayed), keyed by their name
      local key = zone.key or zone.name
      local radio = root:CreateRadio(zone.name,
            function(k) return k == RecipeRadarForever_Options.CurrentRegion end,
            function(k)
               RRF_NewRegion(k)
               RRFListScrollFrameScrollBar:SetValue(0)
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

local autoMapCheck = CreateCheck(RRF_S("Auto-map Contributive Vendors"), frame, 24, -250, function(checked)
   RecipeRadarForever_Options.AutoMapVendors = checked
   if (checked) then
      RRF_InitVendorFilters()
      RRF_FrameUpdate()
   end
end)

local seasonalCheck = CreateCheck(RRF_S("Hide Seasonal Vendors/Recipes"), autoMapCheck, 0, -2, function(checked)
   RecipeRadarForever_Options.HideSeasonal = checked
   RRF_InitVendorFilters()
   RRF_InitRecipeFilters()
   RRF_FrameUpdate()
end)

-----------------------------------------------------------------------------
-- Character data: delete what is stored for a character on this realm
-----------------------------------------------------------------------------

local charLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
charLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 28, -318)
charLabel:SetText(RRF_S("Stored character data (this realm)"))

local selectedChar

local charDropDown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
charDropDown:SetSize(170, 22)
charDropDown:SetPoint("TOPLEFT", charLabel, "BOTTOMLEFT", 0, -6)
charDropDown:SetDefaultText(RRF_S("Choose a character"))
charDropDown:SetupMenu(function(_, root)
   local names = { }
   for name in pairs(RecipeRadarForever_SkillDB[GetRealmName()] or { }) do
      table.insert(names, name)
   end
   table.sort(names)
   for _, name in ipairs(names) do
      local label = name
      if (name == UnitName("player")) then label = name .. " " .. RRF_Parens(RRF_S("this character")) end
      root:CreateRadio(label, function(n) return n == selectedChar end,
            function(n) selectedChar = n end, name)
   end
end)

local deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
deleteButton:SetSize(80, 22)
deleteButton:SetPoint("LEFT", charDropDown, "RIGHT", 6, 0)
deleteButton:SetText(DELETE)
deleteButton:SetScript("OnClick", function()
   if (selectedChar) then
      StaticPopup_Show("RRF_DELETE_CHARACTER", selectedChar, nil, selectedChar)
   end
end)

StaticPopupDialogs["RRF_DELETE_CHARACTER"] = {
   text = RRF_S("Delete all Recipe Radar Forever data stored for %s?"),
   button1 = YES,
   button2 = NO,
   OnAccept = function(_, name)
      local realm = RecipeRadarForever_SkillDB[GetRealmName()]
      if (realm and name) then
         realm[name] = nil
         RRF_Print(string.format(RRF_S("Recipe Radar Forever: deleted the data for %s."), name))
         if (name == UnitName("player")) then RRF_SkillDB_ScanAll() end
      end
      selectedChar = nil
      charDropDown:GenerateMenu()
      RRF_RefreshIfShown()
   end,
   timeout = 0,
   whileDead = true,
   hideOnEscape = true,
}

local report = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
report:SetSize(130, 22)
report:SetPoint("BOTTOMLEFT", 24, 18)
report:SetText(RRF_S("Report a problem"))
report:SetScript("OnClick", function()
   frame:Hide()
   RRF_Report_Show()
end)

local okay = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
okay:SetSize(100, 22)
okay:SetPoint("BOTTOMRIGHT", -24, 18)
okay:SetText(OKAY)
okay:SetScript("OnClick", function()
   PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
   frame:Hide()
end)

frame:SetScript("OnShow", function()
   local opts = RecipeRadarForever_Options
   realmCheck:SetChecked(opts.RealmAvailability)
   minimapCheck:SetChecked(opts.ShowMinimapButton)
   slider:SetValue(opts.MinimapButtonPosition or 256)
   autoRegionCheck:SetChecked(opts.AutoSelectRegion)
   autoMapCheck:SetChecked(opts.AutoMapVendors)
   seasonalCheck:SetChecked(opts.HideSeasonal)
   shownContinent = opts.CurrentContinent or RRF_GetCurrentContinent()
   continentDropDown:SetEnabled(not opts.AutoSelectRegion)
   regionDropDown:SetEnabled(not opts.AutoSelectRegion)
   continentDropDown:GenerateMenu()
   regionDropDown:GenerateMenu()
   selectedChar = nil
   charDropDown:GenerateMenu()
end)

function RRF_OptionsFrame_Toggle()

   frame:SetShown(not frame:IsShown())

end

-----------------------------------------------------------------------------
-- Settings > AddOns entry: a small page with a button that opens the dialog
-----------------------------------------------------------------------------

function RRF_Options_RegisterSettings()

   if (not (Settings and Settings.RegisterCanvasLayoutCategory)) then return end

   local panel = CreateFrame("Frame")
   local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
   title:SetPoint("TOPLEFT", 16, -16)
   title:SetText(RRF_S("Recipe Radar Forever") .. " " .. RRF_VERSION)

   local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
   open:SetSize(180, 24)
   open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
   open:SetText(RRF_S("Options"))
   open:SetScript("OnClick", function()
      if (SettingsPanel and SettingsPanel:IsShown()) then
         SettingsPanel:Close()
      end
      frame:Show()
   end)

   local toggle = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
   toggle:SetSize(180, 24)
   toggle:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -6)
   toggle:SetText(RRF_S("Toggle Recipe Radar"))
   toggle:SetScript("OnClick", function()
      if (SettingsPanel and SettingsPanel:IsShown()) then
         SettingsPanel:Close()
      end
      RRF_Toggle()
   end)

   local category = Settings.RegisterCanvasLayoutCategory(panel, RRF_S("Recipe Radar Forever"))
   Settings.RegisterAddOnCategory(category)

end
