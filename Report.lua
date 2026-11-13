-- Report.lua: "Report a problem" window with a GitHub issue link and copyable details
--
-- Addons cannot open a browser, so the window shows the issue link and a
-- prepared details block for the player to copy (Ctrl+C) into the issue.
-- The details contain no character or realm names.

local addonName, ns = ...

local ISSUES_URL = "https://github.com/Cebion/RecipeRadarForever/issues/new"
local TEMPLATES = { bug = "bug_report.md", data = "data_problem.md" }

local frame

local function AddonVersion(name)
   if (not C_AddOns.IsAddOnLoaded(name)) then return "not loaded" end
   return C_AddOns.GetAddOnMetadata(name, "Version") or "?"
end

local function CountData()
   local recipes, regions = 0, 0
   for _, prof in pairs(RRF_RecipeData) do recipes = recipes + #prof.Recipes end
   for _ in pairs(RRF_RegionData) do regions = regions + 1 end
   return recipes, regions
end

local function PlayerPosition()
   local mapID = C_Map.GetBestMapForUnit("player")
   local info = mapID and C_Map.GetMapInfo(mapID)
   local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
   local where = string.format("%s (uiMapID %s)", info and info.name or "?", tostring(mapID))
   if (pos) then
      local x, y = pos:GetXY()
      where = where .. string.format(", position %.1f, %.1f", x * 100, y * 100)
   end
   return where
end

-- vendor: optional vendor table; region: its region key; recipe: optional
local function BuildDetails(kind, vendor, region, recipe)

   local version, build, _, toc = GetBuildInfo()
   local recipes, regions = CountData()
   local s = ns.importStats
   local lines = {
      "Recipe Radar Forever " .. tostring(RRF_VERSION),
      string.format("Client: %s (%s), interface %s, locale %s", version, build, tostring(toc), GetLocale()),
      string.format("Data: %d recipes, %d regions", recipes, regions),
      "QuestieDB: " .. AddonVersion("QuestieDB") .. (s and string.format(
            " (import added %d recipes, %d vendors, %d pairs)", s.recipes, s.vendors, s.pairs) or ""),
      "TomTom: " .. AddonVersion("TomTom"),
      "Player location: " .. PlayerPosition(),
   }
   if (vendor) then
      local coords = vendor.Coordinates and vendor.Coordinates[1]
      table.insert(lines, "")
      table.insert(lines, string.format("Vendor: %s (%s) in %s", vendor.Name, tostring(vendor.Team), tostring(region)))
      if (coords) then
         table.insert(lines, string.format("Vendor position in the data: %.1f, %.1f", coords.x * 100, coords.y * 100))
      end
      if (recipe) then
         local name = RRF_GetSafeItemInfo(recipe.ID)
         local cost = RRF_GetRecipeCost(recipe)
         table.insert(lines, string.format("Recipe: %d %s, skill %s, cost %s", recipe.ID, name,
               tostring(recipe.Skill or "?"), type(cost) == "number" and RRF_GetGSCString(cost):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or tostring(cost)))
      end
   end
   table.insert(lines, "")
   if (kind == "data") then
      table.insert(lines, "What is wrong (wrong place, not sold here, wrong price, missing recipe...):")
   else
      table.insert(lines, "What happened, and what did you expect?")
      table.insert(lines, "")
      table.insert(lines, "Lua error (from BugSack or /console scriptErrors 1), if any:")
   end
   table.insert(lines, "")
   return table.concat(lines, "\n")

end

local function CreateWindow()

   frame = CreateFrame("Frame", "RRFReportFrame", UIParent, "BackdropTemplate")
   frame:SetSize(480, 360)
   frame:SetPoint("CENTER")
   frame:SetFrameStrata("DIALOG")
   frame:SetToplevel(true)
   frame:SetMovable(true)
   frame:EnableMouse(true)
   frame:RegisterForDrag("LeftButton")
   frame:SetScript("OnDragStart", frame.StartMoving)
   frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
   frame:SetBackdrop(BACKDROP_DIALOG_32_32)
   tinsert(UISpecialFrames, "RRFReportFrame")

   local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
   title:SetPoint("TOP", 0, -18)
   title:SetText(RRF_S("Report a problem"))

   local help = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
   help:SetPoint("TOPLEFT", 24, -44)
   help:SetPoint("RIGHT", -24, 0)
   help:SetJustifyH("LEFT")
   help:SetText(RRF_S("1. Copy this link (Ctrl+C) and open it in your browser (needs a GitHub account):"))

   local url = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
   url:SetSize(420, 20)
   url:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 6, -6)
   url:SetAutoFocus(false)
   url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
   url:SetScript("OnTextChanged", function(self, userInput)
      if (userInput) then self:SetText(self.fixedText or "") self:HighlightText() end
   end)
   frame.url = url

   local help2 = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
   help2:SetPoint("TOPLEFT", url, "BOTTOMLEFT", -6, -10)
   help2:SetPoint("RIGHT", -24, 0)
   help2:SetJustifyH("LEFT")
   help2:SetText(RRF_S("2. Copy these details into the issue and add what went wrong:"))

   local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
   scroll:SetPoint("TOPLEFT", help2, "BOTTOMLEFT", 0, -6)
   scroll:SetPoint("BOTTOMRIGHT", -42, 52)
   local bg = scroll:CreateTexture(nil, "BACKGROUND")
   bg:SetPoint("TOPLEFT", -4, 4)
   bg:SetPoint("BOTTOMRIGHT", 4, -4)
   bg:SetColorTexture(0, 0, 0, 0.5)

   local details = CreateFrame("EditBox", nil, scroll)
   details:SetMultiLine(true)
   details:SetFontObject("ChatFontSmall")
   details:SetWidth(400)
   details:SetAutoFocus(false)
   details:SetScript("OnEscapePressed", function() frame:Hide() end)
   details:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
   scroll:SetScrollChild(details)
   frame.details = details

   local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
   selectAll:SetSize(120, 22)
   selectAll:SetPoint("BOTTOMLEFT", 24, 18)
   selectAll:SetText(RRF_S("Select details"))
   selectAll:SetScript("OnClick", function()
      details:SetFocus()
      details:HighlightText()
   end)

   local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
   close:SetSize(100, 22)
   close:SetPoint("BOTTOMRIGHT", -24, 18)
   close:SetText(CLOSE)
   close:SetScript("OnClick", function() frame:Hide() end)

end

-- kind: "bug" (default) or "data"; vendor/region/recipe: optional context
function RRF_Report_Show(kind, vendor, region, recipe)

   if (not frame) then CreateWindow() end
   kind = (kind == "data") and "data" or "bug"
   local link = ISSUES_URL .. "?template=" .. TEMPLATES[kind]
   frame.url.fixedText = link
   frame.url:SetText(link)
   frame.url:SetCursorPosition(0)
   frame.details:SetText(BuildDetails(kind, vendor, region, recipe))
   frame.details:SetCursorPosition(0)
   frame:Show()
   frame.url:SetFocus()

end
