-- Import.lua: adds vendor recipes from an installed QuestieDB at login
--
-- The shipped data is a snapshot (tools/build_data.py). When QuestieDB is
-- installed, its current vendor data is read in small batches after login and
-- anything the snapshot lacks (new recipes, new vendors for known recipes) is
-- added in memory. Nothing is saved; the import runs again on the next login.
-- Turn it off with /rrf questie off.

local addonName, ns = ...

local CONTRACT = 4
local BATCH = 250

local PROFESSIONS = {  -- item subClass of class 9 (Recipe)
   [1] = "Leatherworking", [2] = "Tailoring", [3] = "Engineering", [4] = "Blacksmithing",
   [5] = "Cooking", [6] = "Alchemy", [7] = "First Aid", [8] = "Enchanting", [9] = "Fishing",
}

-- Items QuestieDB lists that are not sold in Forever (kept in sync with
-- tools/data/overrides.json).
local EXCLUDED = { [211247] = true, [215155] = true }

local function GetLib()

   -- QuestieDB publishes its entity readers as LibQuestieDB.Item / .Npc
   local lib = rawget(_G, "LibQuestieDB")
   if (type(lib) ~= "table" or type(lib.RequireContract) ~= "function") then return nil end
   local ok, good = pcall(lib.RequireContract, CONTRACT)
   if (not ok or not good) then return nil end
   if (type(lib.Item) ~= "table" or type(lib.Npc) ~= "table") then return nil end
   return lib

end

local function AreaToMapTable(lib)

   local ok, zdb = pcall(function() return lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB") end)
   local priv = ok and type(zdb) == "table" and zdb.private
   local map = { }
   for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
      local src = type(priv) == "table" and priv[key]
      if (type(src) == "string") then
         local fn = loadstring(src)
         local okRun, t = pcall(fn or function() end)
         src = okRun and t or nil
      end
      if (type(src) == "table") then
         for area, mapID in pairs(src) do
            if (type(mapID) == "number" and mapID > 0) then map[area] = mapID end
         end
      end
   end
   return map

end

local TEAMS = { A = "Alliance", H = "Horde" }

-- region key for a uiMapID, creating a region for zones without vendors yet
local function RegionForMap(mapID)

   for key, region in pairs(RRF_RegionData) do
      if (region.UiMapID == mapID) then return key end
   end
   local info = C_Map.GetMapInfo(mapID)
   if (not info or info.mapType ~= Enum.UIMapType.Zone) then return nil end
   RRF_Maps_RegisterRegion(info.name, { UiMapID = mapID, Vendors = { } })
   return info.name

end

local function FindVendor(region, name)

   for _, vendor in ipairs(region.Vendors) do
      if (vendor.Name == name) then return vendor end
   end
   return nil

end

local function FindRecipe(list, id)

   for _, recipe in ipairs(list) do
      if (recipe.ID == id) then return recipe end
   end
   return nil

end

-- copies the shipped facts (price, reputation...) of a recipe when present
local function NewRecipe(id, prof, template)

   local recipe = { ID = id, Type = RRF_S(prof) }
   if (template) then
      for _, k in ipairs({ "Skill", "Cost", "Currency", "Token", "Amount", "Faction",
            "FactionID", "Level", "Specialty", "Notes", "IsCertification" }) do
         recipe[k] = template[k]
      end
   end
   return recipe

end

local function Merge(lib, areaMap, id, prof, vendorIDs, stats)

   local profData = RRF_RecipeData[RRF_S(prof)]
   if (not profData) then
      profData = { Recipes = { } }
      RRF_RecipeData[RRF_S(prof)] = profData
   end
   local master = FindRecipe(profData.Recipes, id)

   for _, npcID in ipairs(vendorIDs) do
      local name = lib.Npc.Get(npcID, "name")
      local spawns = lib.Npc.Get(npcID, "spawns")
      if (type(name) == "string" and type(spawns) == "table") then
         local team = TEAMS[lib.Npc.Get(npcID, "friendlyToFaction") or ""] or "Neutral"
         for area, points in pairs(spawns) do
            local mapID = areaMap[area]
            local key = mapID and RegionForMap(mapID)
            local region = key and RRF_RegionData[key]
            if (region) then
               local vendor = FindVendor(region, name)
               if (not vendor) then
                  vendor = { Name = name, Team = team, Coordinates = { }, Recipes = { } }
                  for i = 1, math.min(#points, RRF_MaxVendorCoordinates) do
                     local p = points[i]
                     if (type(p) == "table" and p[1] and p[1] >= 0) then
                        table.insert(vendor.Coordinates, { x = p[1] / 100, y = p[2] / 100 })
                     end
                  end
                  table.insert(region.Vendors, vendor)
                  region.IsVendorTableSorted = false
                  stats.vendors = stats.vendors + 1
               end
               if (not FindRecipe(vendor.Recipes, id)) then
                  table.insert(vendor.Recipes, NewRecipe(id, prof, master))
                  vendor.IsRecipeTableSorted = false
                  if (not master) then
                     master = NewRecipe(id, prof, nil)
                     master.Locations = { }
                     table.insert(profData.Recipes, master)
                     profData.IsRecipeTableSorted = false
                     stats.recipes = stats.recipes + 1
                  end
                  table.insert(master.Locations, { Region = key, Vendor = name, Team = team })
                  master.IsLocationsTableSorted = false
                  stats.pairs = stats.pairs + 1
                  table.insert(stats.list, string.format("%s (npc %d, area %s -> %s): item %d",
                        name, npcID, tostring(area), key, id))
               end
            end
         end
      end
   end

end

function RRF_Import_Start()

   if (RecipeRadarForever_Options.UseQuestie == false or ns.importRunning) then return end
   local lib = GetLib()
   if (not lib) then return end

   ns.importRunning = true
   local areaMap = AreaToMapTable(lib)
   local ids = lib.Item.GetAllIds()
   local stats = { recipes = 0, vendors = 0, pairs = 0, list = { } }
   local index = 1

   local ticker
   ticker = C_Timer.NewTicker(0.05, function()
      local last = math.min(index + BATCH - 1, #ids)
      for i = index, last do
         local id = ids[i]
         if (not EXCLUDED[id] and lib.Item.Get(id, "class") == 9) then
            local prof = PROFESSIONS[lib.Item.Get(id, "subClass") or 0]
            local vendors = prof and lib.Item.Get(id, "vendors")
            if (type(vendors) == "table" and #vendors > 0) then
               local ok, err = pcall(Merge, lib, areaMap, id, prof, vendors, stats)
               if (not ok and not ns.importError) then
                  ns.importError = err
               end
            end
         end
      end
      index = last + 1
      if (index > #ids) then
         ticker:Cancel()
         ns.importRunning = false
         ns.importStats = stats
         if (stats.pairs > 0) then
            RRF_ItemData_Reindex()
            RRF_ItemData_ApplyCache()
            RRF_ItemData_ResolveSkills(RRF_RefreshIfShown)
            RRF_RefreshIfShown()
         end
      end
   end)

end

function RRF_Import_PrintStatus()

   local lib = GetLib()
   if (not lib) then
      RRF_Print("Recipe Radar: QuestieDB not found (or incompatible); using the shipped data only.")
   elseif (RecipeRadarForever_Options.UseQuestie == false) then
      RRF_Print("Recipe Radar: QuestieDB import is off (/rrf questie on).")
   elseif (ns.importRunning) then
      RRF_Print("Recipe Radar: QuestieDB import is running.")
   elseif (ns.importStats) then
      local s = ns.importStats
      RRF_Print(string.format(
            "Recipe Radar: QuestieDB %s added %d recipes, %d vendors, %d vendor/recipe pairs beyond the shipped data.",
            tostring(C_AddOns.GetAddOnMetadata("QuestieDB", "Version")), s.recipes, s.vendors, s.pairs))
      for i = 1, math.min(#s.list, 20) do RRF_Print("   " .. s.list[i]) end
      if (#s.list > 20) then RRF_Print(string.format("   ... and %d more", #s.list - 20)) end
   end
   if (ns.importError) then
      RRF_Print("Recipe Radar: first import error: " .. tostring(ns.importError))
   end

end
