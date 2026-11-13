-- SkillDB.lua: per-character database of professions, recipes and reputation
--
-- Layout (unchanged from 1.x so existing saved data keeps working):
-- RecipeRadarForever_SkillDB[realm][character] = {
--    Team = "Alliance" | "Horde",
--    Professions = { [profName] = { Rank = n, Specialty = name?, Recipes = { [recipeName] = 1 } } },
--    Factions = { [factionName] = standingIndex },
-- }

local addonName, ns = ...

function RRF_SkillDB_Init()

   if (type(RecipeRadarForever_SkillDB) ~= "table") then
      RecipeRadarForever_SkillDB = { }
   end
   if (type(RecipeRadarForever_NameCache) ~= "table") then
      RecipeRadarForever_NameCache = { }
   end

   local realm = GetRealmName()
   if (not RecipeRadarForever_SkillDB[realm]) then
      RecipeRadarForever_SkillDB[realm] = { }
   end

   -- drop professions that this data set does not know about
   for _, player_info in pairs(RecipeRadarForever_SkillDB[realm]) do
      if (type(player_info.Professions) == "table") then
         for prof in pairs(player_info.Professions) do
            if (not RRF_IsProfession(prof)) then
               player_info.Professions[prof] = nil
            end
         end
      end
   end

end

-- Returns the character's personal database, creating it when needed.
-- If no player is supplied, the current player is assumed.
function RRF_SkillDB_GetSafePlayerDB(player)

   if (not RecipeRadarForever_SkillDB) then
      RRF_SkillDB_Init()
   end

   local is_me = (not player or player == UnitName("player"))
   if (not player) then player = UnitName("player") end

   local db = RecipeRadarForever_SkillDB[GetRealmName()]
   if (not db[player]) then db[player] = { } end
   local info = db[player]

   if (not info.Team and is_me) then info.Team = UnitFactionGroup("player") end
   if (not info.Professions) then info.Professions = { } end
   if (not info.Factions) then info.Factions = { } end

   return info

end

function RRF_SkillDB_GetPlayerTeam(player)
   return RRF_SkillDB_GetSafePlayerDB(player).Team
end

function RRF_SkillDB_GetPlayerProfessions(player)
   return RRF_SkillDB_GetSafePlayerDB(player).Professions
end

function RRF_SkillDB_GetPlayerFactions(player)
   return RRF_SkillDB_GetSafePlayerDB(player).Factions
end

local function GetProfEntry(profs, name)

   if (not profs[name]) then profs[name] = { Rank = 0 } end
   if (not profs[name].Recipes) then profs[name].Recipes = { } end
   return profs[name]

end

-----------------------------------------------------------------------------
-- Scanners (replace the 1.x frame scraping and chat parsing)
-----------------------------------------------------------------------------

-- Professions and ranks from the skill list (C_SkillInfo, verified in the
-- Forever API docs). Professions that are no longer listed get removed.
function RRF_SkillDB_ScanSkills()

   if (not (C_SkillInfo and C_SkillInfo.GetNumSkillLines)) then return end

   local profs = RRF_SkillDB_GetPlayerProfessions()
   local seen = { }

   for i = 1, C_SkillInfo.GetNumSkillLines() do
      local info = C_SkillInfo.GetSkillLineInfo(i)
      if (info and not info.isHeader and RRF_IsProfession(info.name)) then
         local entry = GetProfEntry(profs, info.name)
         entry.Rank = info.rank
         entry.MaxRank = info.maxRank
         seen[info.name] = true
         RRF_SkillDB_HandleSpecialCase(profs, info.name, info.maxRank)
      end
   end

   -- an empty list usually means the skill data isn't ready yet
   if (next(seen)) then
      for name in pairs(profs) do
         if (not seen[name]) then profs[name] = nil end
      end
   end

end

-- Trade specializations, checked by spell ID.
function RRF_SkillDB_ScanSpecialties()

   if (not (C_SpellBook and C_SpellBook.IsSpellKnown)) then return end

   local profs = RRF_SkillDB_GetPlayerProfessions()
   for spec, spellID in pairs(ns.SpecialtySpells) do
      local prof = RRF_Specialties[spec]
      if (profs[prof]) then
         if (C_SpellBook.IsSpellKnown(spellID)) then
            profs[prof].Specialty = spec
         elseif (profs[prof].Specialty == spec) then
            profs[prof].Specialty = nil
         end
      end
   end

end

-- Standings with the factions that sell recipes.
function RRF_SkillDB_ScanReputation()

   if (not (C_Reputation and C_Reputation.GetNumFactions)) then return end

   -- look up exactly the factions the recipe data needs, so collapsed
   -- headers in the reputation list don't hide any of them
   if (not ns.neededFactions) then
      ns.neededFactions = { }
      for _, prof in pairs(RRF_RecipeData) do
         for _, recipe in ipairs(prof.Recipes) do
            if (recipe.FactionID) then ns.neededFactions[recipe.FactionID] = true end
         end
      end
   end

   local factions = RRF_SkillDB_GetPlayerFactions()
   for id in pairs(ns.neededFactions) do
      local data = C_Reputation.GetFactionDataByID(id)
      if (data and data.name and data.name ~= "") then
         factions[id] = data.reaction
         factions[data.name] = data.reaction  -- 1.x layout, keyed by name
      end
   end

end

function RRF_SkillDB_ScanAll()

   RRF_SkillDB_ScanSkills()
   RRF_SkillDB_ScanSpecialties()
   RRF_SkillDB_ScanReputation()

end

-- Adds unlisted/implied "recipes" (expert books) to the skill DB.
function RRF_SkillDB_HandleSpecialCase(profs, prof_name, max_rank)

   if (not max_rank or max_rank <= 150) then return end

   local books = {
      [RRF_S("First Aid")] = 16084,  -- Expert First Aid - Under Wraps
      [RRF_S("Fishing")] = 16083,    -- Expert Fishing - The Bass and You
      [RRF_S("Cooking")] = 16072,    -- Expert Cookbook
   }
   local id = books[prof_name]
   if (not id) then return end

   local name, _, _, _, _, _, _, cached = RRF_GetSafeItemInfo(id)
   if (cached) then
      GetProfEntry(profs, prof_name).Recipes[name] = 1
   end

end

local ITEM_KNOWN = ITEM_SPELL_KNOWN or "Already known"

-- Returns true if the item tooltip of a cached item says "Already known".
local function TooltipSaysKnown(id)

   local data = C_TooltipInfo.GetItemByID(id)
   if (not data or not data.lines) then return false end
   for _, line in ipairs(data.lines) do
      if (line.leftText == ITEM_KNOWN) then
         return true
      end
   end
   return false

end

-- Marks as known every recipe that the game flags as "Already known" in its
-- item tooltip. Only recipes the DB considers learnable by the current
-- player are checked. Returns true if the DB changed.
function RRF_SkillDB_ScanKnownRecipes()

   if (not (C_TooltipInfo and C_TooltipInfo.GetItemByID)) then return false end

   local profs = RRF_SkillDB_GetPlayerProfessions()
   local changed = false

   for _, prof_data in pairs(RRF_RecipeData) do
      for _, recipe in ipairs(prof_data.Recipes) do
         local p = profs[recipe.Type]
         if (p and p.Recipes and C_Item.GetItemInfo(recipe.ID) and
               RRF_Availability_GetKey(recipe) == "LearnableByPlayer" and
               TooltipSaysKnown(recipe.ID)) then
            local name = RRF_TrimRecipeLabel(C_Item.GetItemInfo(recipe.ID))
            p.Recipes[name] = 1
            changed = true
         end
      end
   end

   return changed

end

-- Schedules one known-recipe scan; bursts of learn events collapse into it.
function RRF_SkillDB_RequestKnownScan()

   if (ns.knownScanQueued) then return end
   ns.knownScanQueued = true
   C_Timer.After(1, function()
      ns.knownScanQueued = false
      RRF_SkillDB_ScanSkills()
      RRF_SkillDB_ScanKnownRecipes()
      RRF_RefreshIfShown()
   end)

end

-----------------------------------------------------------------------------
-- Queries
-----------------------------------------------------------------------------

function RRF_SkillDB_GetRank(prof)

   local prof_db = RRF_SkillDB_GetPlayerProfessions()[prof]
   if (not prof_db) then return 0 end
   return prof_db.Rank or 0

end

-- Does a character in the DB have the reputation needed for the recipe?
function RRF_SkillDB_HasRep(player, recipe)

   local key = recipe.FactionID or recipe.Faction
   if (not key or key == "") then return true end

   local factions = RRF_SkillDB_GetPlayerFactions(player)
   local standing = factions[key] or (recipe.Faction and factions[recipe.Faction])
   if (not standing) then return false end
   return standing >= (recipe.Level or 4)

end

-- Does a character in the DB have the specialty needed for the recipe?
function RRF_SkillDB_HasSpec(player, recipe)

   if (not recipe.Specialty or recipe.Specialty == "") then return true end

   local db = RRF_SkillDB_GetPlayerProfessions(player)
   if (not db[recipe.Type]) then return false end
   return recipe.Specialty == db[recipe.Type].Specialty

end

-----------------------------------------------------------------------------
-- Debug commands
-----------------------------------------------------------------------------

function RRF_SkillDB_Clear(player)

   local realm_db = RecipeRadarForever_SkillDB[GetRealmName()]
   if (player and player ~= "" and realm_db[player]) then
      RRF_Print("Clearing all known recipes for " .. player .. ".")
      realm_db[player] = nil
   else
      RRF_Print("Clearing all known recipes on this realm.")
      RecipeRadarForever_SkillDB[GetRealmName()] = { }
   end
   RRF_SkillDB_ScanAll()

end

function RRF_SkillDB_Print(player)

   RRF_Print("Realm: " .. GetRealmName())
   for player_name, info in pairs(RecipeRadarForever_SkillDB[GetRealmName()]) do
      if (not player or player == "" or player == player_name) then
         RRF_Print("   " .. player_name .. " (" .. tostring(info.Team) .. ")")
         for prof_name, prof in pairs(info.Professions or { }) do
            local count = 0
            for _ in pairs(prof.Recipes or { }) do count = count + 1 end
            RRF_Print(string.format("      %s %d%s - %d recipes known",
                  prof_name, prof.Rank or 0,
                  prof.Specialty and (" [" .. prof.Specialty .. "]") or "", count))
         end
         for faction, standing in pairs(info.Factions or { }) do
            RRF_Print("      " .. faction .. ": " ..
                  (_G["FACTION_STANDING_LABEL" .. standing] or standing))
         end
      end
   end

end
