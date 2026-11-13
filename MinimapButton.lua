-- MinimapButton.lua: the little Recipe Radar button on the minimap edge

local addonName, ns = ...

local FLASH_HALF_PERIOD = 0.5
local FLASH_DURATION = 4

function RecipeRadar_MinimapButton_OnLoad(self)

   self:RegisterForClicks("LeftButtonUp", "RightButtonUp")

end

function RecipeRadar_MinimapButton_OnClick(self, button)

   if (button == "RightButton") then
      RecipeRadar_OptionsFrame_Toggle()
   else
      RecipeRadar_Toggle()
   end

end

function RecipeRadar_MinimapButton_OnEnter(self)

   GameTooltip:SetOwner(self, "ANCHOR_LEFT")
   GameTooltip:SetText(RRS("Recipe Radar"))
   GameTooltip:AddLine(RRS("Left-click: open") .. "\n" .. RRS("Right-click: options"), 1, 1, 1)
   GameTooltip:Show()

end

function RecipeRadar_MinimapButton_Init()

   RecipeRadarMinimapButton:SetShown(RecipeRadar_Options.ShowMinimapButton)
   RecipeRadar_MinimapButton_UpdatePosition()

end

function RecipeRadar_MinimapButton_Toggle()

   RecipeRadar_Options.ShowMinimapButton = not RecipeRadarMinimapButton:IsShown()
   RecipeRadarMinimapButton:SetShown(RecipeRadar_Options.ShowMinimapButton)

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

function RecipeRadar_MinimapButton_Flash()

   local button = RecipeRadarMinimapButton
   button.flashTotal, button.flashPhase, button.flashOn = 0, 0, true
   button:LockHighlight()
   button:SetScript("OnUpdate", FlashOnUpdate)

end

-- Places the button on the minimap edge at the configured angle (degrees).
function RecipeRadar_MinimapButton_UpdatePosition()

   local angle = math.rad(RecipeRadar_Options.MinimapButtonPosition or 256)
   local radius = (Minimap:GetWidth() / 2) + 5
   local x, y = math.cos(angle) * radius, math.sin(angle) * radius

   RecipeRadarMinimapButton:ClearAllPoints()
   RecipeRadarMinimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)

end
