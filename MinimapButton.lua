-- MinimapButton.lua: the little Recipe Radar button on the minimap edge

local addonName, ns = ...

local FLASH_HALF_PERIOD = 0.5
local FLASH_DURATION = 4

function RRF_MinimapButton_OnLoad(self)

   self:RegisterForClicks("LeftButtonUp", "RightButtonUp")

end

function RRF_MinimapButton_OnClick(self, button)

   if (button == "RightButton") then
      RRF_OptionsFrame_Toggle()
   else
      RRF_Toggle()
   end

end

function RRF_MinimapButton_OnEnter(self)

   GameTooltip:SetOwner(self, "ANCHOR_LEFT")
   GameTooltip:SetText(RRF_S("Recipe Radar Forever"))
   GameTooltip:AddLine(RRF_S("Left-click: open") .. "\n" .. RRF_S("Right-click: options"), 1, 1, 1)
   GameTooltip:Show()

end

function RRF_MinimapButton_Init()

   RRFMinimapButton:SetShown(RecipeRadarForever_Options.ShowMinimapButton)
   RRF_MinimapButton_UpdatePosition()

end

function RRF_MinimapButton_Toggle()

   RecipeRadarForever_Options.ShowMinimapButton = not RRFMinimapButton:IsShown()
   RRFMinimapButton:SetShown(RecipeRadarForever_Options.ShowMinimapButton)

end

-- Flash: toggles the highlight every half second for a few seconds. The
-- OnUpdate script only exists while the flash runs.
local function FlashOnUpdate(self, elapsed)

   self.flashTotal = self.flashTotal + elapsed
   self.flashPhase = self.flashPhase + elapsed
   if (self.flashPhase > FLASH_HALF_PERIOD) then
      self.flashPhase = self.flashPhase % FLASH_HALF_PERIOD
      self.flashOn = not self.flashOn
      if (self.flashOn) then self:LockHighlight() else self:UnlockHighlight() end
   end

   if (self.flashTotal > FLASH_DURATION) then
      self:UnlockHighlight()
      self:SetScript("OnUpdate", nil)
   end

end

function RRF_MinimapButton_Flash()

   local button = RRFMinimapButton
   button.flashTotal, button.flashPhase, button.flashOn = 0, 0, true
   button:LockHighlight()
   button:SetScript("OnUpdate", FlashOnUpdate)

end

-- Places the button on the minimap edge at the configured angle (degrees).
function RRF_MinimapButton_UpdatePosition()

   local angle = math.rad(RecipeRadarForever_Options.MinimapButtonPosition or 256)
   local radius = (Minimap:GetWidth() / 2) + 5
   local x, y = math.cos(angle) * radius, math.sin(angle) * radius

   RRFMinimapButton:ClearAllPoints()
   RRFMinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)

end
