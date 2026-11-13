-- AvailabilityTooltip.lua: the per-character recipe availability tooltip

local addonName, ns = ...

local MAX_LINES = 24

-- Named because other files reference it (RecipeRadarAvailabilityTooltip:Hide()).
local tip = CreateFrame("Frame", "RecipeRadarAvailabilityTooltip", UIParent, "TooltipBackdropTemplate")
tip:SetFrameStrata("TOOLTIP")
tip:SetClampedToScreen(true)
tip:Hide()
tip.Lines = 0
tip.Texts = { }

for i = 1, MAX_LINES do
   local fs = tip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
   fs:SetJustifyH("LEFT")
   if (i == 1) then
      fs:SetPoint("TOPLEFT", 10, -10)
   else
      fs:SetPoint("TOPLEFT", tip.Texts[i - 1], "BOTTOMLEFT", 0, -2)
   end
   fs:Hide()
   tip.Texts[i] = fs
end

tip:SetScript("OnHide", function()
   RecipeRadar_AvailabilityTooltip_Hide()
end)

function RecipeRadar_AvailabilityTooltip_AddLine(msg, color)

   if (tip.Lines >= MAX_LINES) then return end

   local line_num = tip.Lines + 1
   local line = tip.Texts[line_num]

   if (color) then
      line:SetTextColor(color.r, color.g, color.b)
   else
      line:SetTextColor(1, 1, 1)
   end

   if (not msg or msg == "") then
      line:SetText(" ")
   else
      line:SetText(msg)
   end
   line:Show()

   tip.Lines = line_num

end

function RecipeRadar_AvailabilityTooltip_Show(frame)

   if (not frame or tip.Lines == 0) then
      RecipeRadar_AvailabilityTooltip_Hide()
      return
   end

   local height, width = 20, 0
   for i = 1, tip.Lines do
      local line = tip.Texts[i]
      height = height + line:GetStringHeight() + 2
      width = math.max(width, line:GetStringWidth() + 20)
   end

   tip:SetSize(width, height)
   tip:ClearAllPoints()

   -- place on the left or right according to the position of the main frame
   local space_left = (frame:GetLeft() or 0) - width
   local space_right = GetScreenWidth() - (frame:GetRight() or 0) - width

   local offset = 0
   if (RecipeRadar_Options.ActiveTab == 2) then
      offset = RECIPERADAR_VENDOR_OFFSET
   end

   if (space_left < space_right) then
      if (RecipeRadarListScrollFrame:IsShown()) then
         tip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 35, 0)
      else
         tip:SetPoint("TOPLEFT", frame, "TOPRIGHT", 13, 0)
      end
   else
      tip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -33 + offset, 0)
   end

   tip:Show()

end

function RecipeRadar_AvailabilityTooltip_Hide()

   for i = 1, tip.Lines do
      tip.Texts[i]:Hide()
   end
   tip.Lines = 0

end
