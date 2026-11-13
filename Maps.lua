-- Maps.lua: region -> uiMapID index and vendor map pins
--
-- Pins are shown through TomTom when it is loaded (minimap + world map +
-- arrow). Without TomTom the addon draws its own world map pins through a
-- MapCanvas data provider and sets the Blizzard user waypoint on the most
-- recently mapped vendor, which gives a minimap pin and the supertrack arrow.

local addonName, ns = ...

-- region name -> uiMapID, continent index (1 Kalimdor, 2 Eastern Kingdoms) -> uiMapID
local regionMapIDs, continentMapIDs, continentOfZone = { }, { }, { }
local zonesByContinent = { [1] = { }, [2] = { } }
local indexBuilt = false

-- vendor table -> { region = name, uid = TomTom uid }
local mapped = { }

local function HasTomTom()
   return TomTom and type(TomTom.AddWaypoint) == "function"
end

-----------------------------------------------------------------------------
-- Region index
-----------------------------------------------------------------------------

-- Walks up from a map until a map of the given type is found.
local function FindAncestor(mapID, mapType)
   local info = mapID and C_Map.GetMapInfo(mapID)
   while (info) do
      if (info.mapType == mapType) then return info.mapID end
      if (not info.parentMapID or info.parentMapID == 0) then return nil end
      info = C_Map.GetMapInfo(info.parentMapID)
   end
   return nil
end

-- Builds the index from the world the player is in, so that only the maps
-- the client actually uses for this game are matched by name.
function RecipeRadar_Maps_BuildRegionIndex()

   local playerMap = C_Map.GetBestMapForUnit("player")
   local worldID = FindAncestor(playerMap, Enum.UIMapType.World)
         or FindAncestor(playerMap, Enum.UIMapType.Cosmic)
   if (not worldID) then return end  -- try again on the next zone change

   local kalimdor, eastern = RRS("Kalimdor"), RRS("Eastern Kingdoms")
   for _, cont in ipairs(C_Map.GetMapChildrenInfo(worldID, Enum.UIMapType.Continent, true) or { }) do
      if (cont.name == kalimdor) then
         continentMapIDs[1] = cont.mapID
      elseif (cont.name == eastern) then
         continentMapIDs[2] = cont.mapID
      end
   end

   for index, contID in pairs(continentMapIDs) do
      for _, zone in ipairs(C_Map.GetMapChildrenInfo(contID, Enum.UIMapType.Zone, true) or { }) do
         -- first match wins: direct children are listed before deeper maps
         if (not regionMapIDs[zone.name]) then
            regionMapIDs[zone.name] = zone.mapID
            continentOfZone[zone.name] = index
            table.insert(zonesByContinent[index], zone.name)
         end
      end
      table.sort(zonesByContinent[index])
   end

   indexBuilt = next(regionMapIDs) ~= nil
   if (indexBuilt) then
      RecipeRadar_Maps_RestorePins()
   end

end

function RecipeRadar_Maps_GetRegionMapID(region_name)

   if (not indexBuilt) then RecipeRadar_Maps_BuildRegionIndex() end
   return regionMapIDs[region_name]

end

function RecipeRadar_Maps_GetContinentIndex(region_name)

   if (not indexBuilt) then RecipeRadar_Maps_BuildRegionIndex() end
   return continentOfZone[region_name]

end

-- Sorted zone names of a continent index, for the options dropdown.
function RecipeRadar_Maps_GetZones(continent)

   if (not indexBuilt) then RecipeRadar_Maps_BuildRegionIndex() end
   return zonesByContinent[continent] or { }

end

function RecipeRadar_Maps_PrintRegionIndex()

   if (not indexBuilt) then RecipeRadar_Maps_BuildRegionIndex() end
   RecipeRadar_Print(string.format("Recipe Radar maps: Kalimdor=%s, Eastern Kingdoms=%s",
         tostring(continentMapIDs[1]), tostring(continentMapIDs[2])))

   local missing = { }
   for name, region in pairs(RecipeRadar_RegionData) do
      if (region.Continent ~= 0 and not regionMapIDs[name]) then
         table.insert(missing, name)
      end
   end
   table.sort(missing)
   if (#missing == 0) then
      RecipeRadar_Print("All vendor regions resolved to a map.")
   else
      RecipeRadar_Print("Regions without a map: " .. table.concat(missing, ", "))
   end
   RecipeRadar_Print("Pins: " .. (HasTomTom() and "TomTom" or "world map + Blizzard waypoint"))

end

-----------------------------------------------------------------------------
-- World map pins (used when TomTom is not loaded)
-----------------------------------------------------------------------------

-- Global because the XML pin template names it. The MapCanvas base methods
-- are copied in when the world map is first used (Blizzard_MapCanvas is a
-- load-on-demand dependency of the world map).
RecipeRadarWorldMapPinMixin = { }

function RecipeRadarWorldMapPinMixin:OnLoad()
   self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
   self:SetScalingLimits(1, 1.0, 1.2)
end

function RecipeRadarWorldMapPinMixin:OnAcquired(vendor, x, y)
   self.Vendor = vendor
   self:SetPosition(x, y)
end

function RecipeRadarWorldMapPinMixin:OnMouseEnter()
   RecipeRadar_Maps_SetTooltip(GameTooltip, self)
end

function RecipeRadarWorldMapPinMixin:OnMouseLeave()
   GameTooltip:Hide()
end

function RecipeRadarWorldMapPinMixin:OnClick(button)
   if (button == "RightButton") then
      RecipeRadar_Maps_ShowContextMenu(self, self.Vendor)
   end
end

local provider = { }

-- Fills in base-class methods we did not override. Returns false while the
-- MapCanvas code is not loaded yet.
local function CompleteMixins()
   if (not (MapCanvasPinMixin and MapCanvasDataProviderMixin)) then return false end
   for k, v in pairs(MapCanvasPinMixin) do
      if (RecipeRadarWorldMapPinMixin[k] == nil) then RecipeRadarWorldMapPinMixin[k] = v end
   end
   for k, v in pairs(MapCanvasDataProviderMixin) do
      if (provider[k] == nil) then provider[k] = v end
   end
   return true
end

function provider:RemoveAllData()
   self:GetMap():RemoveAllPinsByTemplate("RecipeRadarWorldMapPinTemplate")
end

function provider:RefreshAllData()

   self:RemoveAllData()
   if (HasTomTom()) then return end  -- TomTom draws its own pins

   local shownMap = self:GetMap():GetMapID()
   if (not shownMap) then return end

   for vendor, entry in pairs(mapped) do
      local coords = vendor.Coordinates and vendor.Coordinates[1]
      local zoneID = RecipeRadar_Maps_GetRegionMapID(entry.region)
      if (coords and zoneID) then
         local x, y
         if (zoneID == shownMap) then
            x, y = coords.x, coords.y
         else
            -- translate through world coordinates for parent/neighbor maps
            local contID, worldPos = C_Map.GetWorldPosFromMapPos(zoneID, CreateVector2D(coords.x, coords.y))
            if (contID and worldPos) then
               local _, pos = C_Map.GetMapPosFromWorldPos(contID, worldPos, shownMap)
               if (pos) then x, y = pos:GetXY() end
            end
         end
         if (x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1) then
            self:GetMap():AcquirePin("RecipeRadarWorldMapPinTemplate", vendor, x, y)
         end
      end
   end

end

local providerAdded = false
local function RefreshWorldMap()

   if (not providerAdded and WorldMapFrame and WorldMapFrame.AddDataProvider and CompleteMixins()) then
      WorldMapFrame:AddDataProvider(provider)
      providerAdded = true
   end
   if (providerAdded and provider:GetMap()) then
      provider:RefreshAllData()
   end

end

-----------------------------------------------------------------------------
-- Blizzard user waypoint fallback
-----------------------------------------------------------------------------

local function SetBlizzardWaypoint(vendor, region)

   local coords = vendor.Coordinates and vendor.Coordinates[1]
   local mapID = RecipeRadar_Maps_GetRegionMapID(region)
   if (not coords or not mapID) then return end
   if (not C_Map.CanSetUserWaypointOnMap(mapID)) then return end

   C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, coords.x, coords.y))
   if (C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint) then
      C_SuperTrack.SetSuperTrackedUserWaypoint(true)
   end
   ns.waypointVendor = vendor

end

local function ClearBlizzardWaypoint(vendor)

   if (ns.waypointVendor == vendor) then
      C_Map.ClearUserWaypoint()
      ns.waypointVendor = nil
   end

end

-----------------------------------------------------------------------------
-- Public mapping API (used by the tabs and the auto-map option)
-----------------------------------------------------------------------------

function RecipeRadar_Maps_Init()

   wipe(mapped)

end

local function ShowVendor(vendor, entry)

   local coords = vendor.Coordinates and vendor.Coordinates[1]
   local mapID = RecipeRadar_Maps_GetRegionMapID(entry.region)
   if (not coords or not mapID) then return end

   if (HasTomTom()) then
      if (not entry.uid) then
         entry.uid = TomTom:AddWaypoint(mapID, coords.x, coords.y, {
               title = vendor.Name, persistent = false,
               minimap = true, world = true, from = "Recipe Radar" })
      end
   else
      SetBlizzardWaypoint(vendor, entry.region)
   end

end

-- Re-creates waypoints after the region index becomes available.
function RecipeRadar_Maps_RestorePins()

   for vendor, entry in pairs(mapped) do
      ShowVendor(vendor, entry)
   end
   RefreshWorldMap()

end

-- Add the given vendor to the list of mapped vendors.
function RecipeRadar_Maps_AddVendor(vendor, region)

   if (vendor.IsMapped) then return end
   local region_data = RecipeRadar_RegionData[region]
   if (not region_data or region_data.Continent == 0) then return end  -- instance vendor
   if (not vendor.Coordinates) then return end

   local entry = { region = region }
   mapped[vendor] = entry
   vendor.IsMapped = true

   ShowVendor(vendor, entry)
   RefreshWorldMap()

end

-- Unmap the vendor.
function RecipeRadar_Maps_RemoveVendor(vendor)

   local entry = mapped[vendor]
   if (entry and entry.uid and HasTomTom() and TomTom.RemoveWaypoint) then
      TomTom:RemoveWaypoint(entry.uid)
   end
   ClearBlizzardWaypoint(vendor)

   mapped[vendor] = nil
   vendor.IsMapped = false
   RefreshWorldMap()

end

-----------------------------------------------------------------------------
-- Tooltip and context menu shared by all map icons
-----------------------------------------------------------------------------

-- Fills a tooltip for a map icon. frame.Vendor must be set.
function RecipeRadar_Maps_SetTooltip(tooltip, frame)

   local vendor = frame.Vendor
   if (not vendor) then return end

   local count = #vendor.Recipes
   local line2
   if (count == 1) then
      line2 = RRS("1 recipe")
   else
      line2 = string.format(RRS("%d recipes"), count)
   end
   line2 = line2 .. " " .. RecipeRadar_Parens(string.format(RRS("%d learnable"),
         RecipeRadar_CountLearnableRecipes(vendor.Recipes)))

   local anchor = "ANCHOR_BOTTOMLEFT"
   if ((frame:GetLeft() or 0) < 200) then
      anchor = "ANCHOR_RIGHT"
   end

   tooltip:SetOwner(frame, anchor)
   tooltip:SetText(RecipeRadar_GetColoredTeamString(vendor.Team, vendor.Name))
   tooltip:AddLine(line2)
   if (vendor.Notes and vendor.Notes ~= "") then
      tooltip:AddLine(RecipeRadar_FormatVendorNote(vendor.Notes, true))
   end
   tooltip:Show()

end

function RecipeRadar_Maps_ShowContextMenu(owner, vendor)

   MenuUtil.CreateContextMenu(owner, function(_, root)
      root:CreateTitle(vendor.Name)
      root:CreateButton(RRS("Unmap Vendor"), function()
         RecipeRadar_Maps_RemoveVendor(vendor)
         RecipeRadar_FrameUpdate()
      end)
   end)

end
