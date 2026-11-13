-- Maps.lua: region index, in-window zone map art and vendor map pins
--
-- Pins are shown through TomTom when it is loaded (minimap + world map +
-- arrow). Without TomTom the addon draws its own world map pins through a
-- MapCanvas data provider and sets the Blizzard user waypoint on the most
-- recently mapped vendor, which gives a minimap pin and the supertrack arrow.

local addonName, ns = ...

-- Region keys in RecipeRadar_RegionData are English zone names; every zone
-- region carries the client's uiMapID (Forever uses the Classic Era map IDs).
local KALIMDOR_MAP, EASTERN_KINGDOMS_MAP = 1414, 1415
local continentMapIDs = { [1] = KALIMDOR_MAP, [2] = EASTERN_KINGDOMS_MAP }

local regionByMapID = { }          -- uiMapID -> region key
local regionByLocalName = { }      -- localized zone/instance name -> region key
local zonesByContinent = { }       -- continent index -> sorted { { name = localized, key = region key or nil } }
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

local function ContinentIndexOfMap(mapID)
   local cont = FindAncestor(mapID, Enum.UIMapType.Continent)
   for index, id in pairs(continentMapIDs) do
      if (id == cont) then return index end
   end
   return nil
end

-- Adds a region (also used at runtime by the QuestieDB import for zones the
-- shipped data has no vendors in yet).
function RecipeRadar_Maps_RegisterRegion(key, region)

   RecipeRadar_RegionData[key] = region
   if (region.UiMapID) then
      regionByMapID[region.UiMapID] = key
      local info = C_Map.GetMapInfo(region.UiMapID)
      if (info) then regionByLocalName[info.name] = key end
      if (region.Continent == nil) then
         region.Continent = ContinentIndexOfMap(region.UiMapID) or 2
      end
   end
   regionByLocalName[RRS(key)] = key
   regionByLocalName[key] = key

end

function RecipeRadar_Maps_BuildRegionIndex()

   wipe(regionByMapID)
   wipe(regionByLocalName)
   for key, region in pairs(RecipeRadar_RegionData) do
      RecipeRadar_Maps_RegisterRegion(key, region)
   end

   -- every zone of both continents, for the options dropdown
   for index, contID in pairs(continentMapIDs) do
      local list, seen = { }, { }
      for _, zone in ipairs(C_Map.GetMapChildrenInfo(contID, Enum.UIMapType.Zone, true) or { }) do
         if (not seen[zone.name]) then
            seen[zone.name] = true
            table.insert(list, { name = zone.name, key = regionByMapID[zone.mapID] })
         end
      end
      table.sort(list, function(a, b) return a.name < b.name end)
      zonesByContinent[index] = list
   end
   local instances = { }
   for key, region in pairs(RecipeRadar_RegionData) do
      if (region.Continent == 0) then
         table.insert(instances, { name = RecipeRadar_GetRegionDisplayName(key), key = key })
      end
   end
   table.sort(instances, function(a, b) return a.name < b.name end)
   zonesByContinent[0] = instances

   indexBuilt = true
   RecipeRadar_Maps_RestorePins()

end

local function EnsureIndex()
   if (not indexBuilt) then RecipeRadar_Maps_BuildRegionIndex() end
end

function RecipeRadar_Maps_GetRegionMapID(region_key)

   local region = RecipeRadar_RegionData[region_key]
   return region and region.UiMapID

end

-- Localized name for a region key (falls back to the localization table).
function RecipeRadar_GetRegionDisplayName(region_key)

   local region = RecipeRadar_RegionData[region_key]
   local info = region and region.UiMapID and C_Map.GetMapInfo(region.UiMapID)
   return (info and info.name) or RRS(region_key)

end

-- Region key (or the plain localized zone name if the zone has no vendors)
-- for the player's current location.
function RecipeRadar_Maps_GetPlayerRegion()

   EnsureIndex()
   local mapID = C_Map.GetBestMapForUnit("player")
   local info = mapID and C_Map.GetMapInfo(mapID)
   while (info) do
      if (regionByMapID[info.mapID]) then return regionByMapID[info.mapID] end
      if (info.mapType <= Enum.UIMapType.Zone) then break end
      info = info.parentMapID and info.parentMapID ~= 0 and C_Map.GetMapInfo(info.parentMapID)
   end
   local zone = GetRealZoneText()
   return regionByLocalName[zone] or zone

end

function RecipeRadar_Maps_GetContinentIndex(region_key)

   local region = RecipeRadar_RegionData[region_key]
   return region and region.Continent

end

-- Zones of a continent index (0 = instances) for the options dropdown.
function RecipeRadar_Maps_GetZones(continent)

   EnsureIndex()
   return zonesByContinent[continent] or { }

end

function RecipeRadar_Maps_PrintRegionIndex()

   EnsureIndex()
   local missing, count = { }, 0
   for key, region in pairs(RecipeRadar_RegionData) do
      count = count + 1
      if (region.Continent ~= 0 and not (region.UiMapID and C_Map.GetMapInfo(region.UiMapID))) then
         table.insert(missing, key)
      end
   end
   table.sort(missing)
   RecipeRadar_Print(string.format("Recipe Radar: %d regions.", count))
   if (#missing == 0) then
      RecipeRadar_Print("All vendor regions resolved to a game map.")
   else
      RecipeRadar_Print("Regions without a game map: " .. table.concat(missing, ", "))
   end
   RecipeRadar_Print("Pins: " .. (HasTomTom() and "TomTom" or "world map + Blizzard waypoint"))

end

-----------------------------------------------------------------------------
-- In-window zone map, drawn from the client's own map tiles
-----------------------------------------------------------------------------

local tilePool = { }

-- Draws the art of uiMapID stretched over `frame`. Returns true if it has art.
function RecipeRadar_Maps_DrawZoneArt(frame, mapID)

   for _, tex in ipairs(tilePool) do tex:Hide() end
   local layers = mapID and C_Map.GetMapArtLayers(mapID)
   local layer = layers and layers[1]
   if (not layer) then return false end

   local textures = C_Map.GetMapArtLayerTextures(mapID, 1)
   if (not textures or #textures == 0) then return false end

   local cols = math.ceil(layer.layerWidth / layer.tileWidth)
   local rows = math.ceil(layer.layerHeight / layer.tileHeight)
   local scaleX = frame:GetWidth() / layer.layerWidth
   local scaleY = frame:GetHeight() / layer.layerHeight

   local n = 0
   for row = 1, rows do
      for col = 1, cols do
         n = n + 1
         local tex = tilePool[n]
         if (not tex) then
            tex = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
            tilePool[n] = tex
         end
         -- crop the last column/row to the layer size instead of overflowing
         local w = math.min(layer.tileWidth, layer.layerWidth - (col - 1) * layer.tileWidth)
         local h = math.min(layer.tileHeight, layer.layerHeight - (row - 1) * layer.tileHeight)
         tex:SetTexture(textures[(row - 1) * cols + col], nil, nil, "TRILINEAR")
         tex:SetTexCoord(0, w / layer.tileWidth, 0, h / layer.tileHeight)
         tex:SetSize(w * scaleX, h * scaleY)
         tex:ClearAllPoints()
         tex:SetPoint("TOPLEFT", frame, "TOPLEFT",
               (col - 1) * layer.tileWidth * scaleX, -(row - 1) * layer.tileHeight * scaleY)
         tex:Show()
      end
   end
   return true

end

function RecipeRadar_Maps_HideZoneArt()

   for _, tex in ipairs(tilePool) do tex:Hide() end

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
