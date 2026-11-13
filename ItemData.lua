-- ItemData.lua: per-recipe facts the shipped data may lack, filled from the game
--
--  * Required skill: read from the recipe item's tooltip ("Requires Tailoring (100)")
--    once the client has the item, then cached in RecipeRadarForever_ItemCache.
--  * Price: recorded from the merchant window when you visit a vendor that sells
--    the recipe (gold, Merchant's Favor or token items), then cached.
--  * /rrdr verify: asks the server for every recipe item and reports IDs it
--    does not know.

local addonName, ns = ...

local byID          -- itemID -> { recipe tables } (RegionData and RecipeData copies)

local function Index()

   if (byID) then return byID end
   byID = { }
   local function add(recipe)
      local list = byID[recipe.ID]
      if (not list) then list = { }; byID[recipe.ID] = list end
      table.insert(list, recipe)
   end
   for _, region in pairs(RRF_RegionData) do
      for _, vendor in ipairs(region.Vendors) do
         for _, recipe in ipairs(vendor.Recipes) do add(recipe) end
      end
   end
   for _, prof in pairs(RRF_RecipeData) do
      for _, recipe in ipairs(prof.Recipes) do add(recipe) end
   end
   return byID

end

-- Call after adding recipes at runtime (QuestieDB import).
function RRF_ItemData_Reindex()
   byID = nil
end

local function Cache(id)

   if (type(RecipeRadarForever_ItemCache) ~= "table") then RecipeRadarForever_ItemCache = { } end
   local c = RecipeRadarForever_ItemCache[id]
   if (not c) then c = { }; RecipeRadarForever_ItemCache[id] = c end
   return c

end

local function Apply(id, fields)

   for _, recipe in ipairs(Index()[id] or { }) do
      for k, v in pairs(fields) do recipe[k] = v end
   end

end

-- Replaces all price fields (nil values clear the old ones).
local function SetPrice(id, cost, currency, token, amount)

   for _, recipe in ipairs(Index()[id] or { }) do
      recipe.Cost, recipe.Currency, recipe.Token, recipe.Amount = cost, currency, token, amount
   end

end

-----------------------------------------------------------------------------
-- Required skill
-----------------------------------------------------------------------------

-- "Requires %s (%d)" -> Lua pattern capturing the skill name and rank
local function BuildSkillPattern(fmt)
   -- escape magic characters except %, then turn %s / %d into captures
   local p = fmt:gsub("([%(%)%.%-%+%[%]%^%$%?%*])", "%%%1")
   p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
   return "^" .. p .. "$"
end
local SKILL_PATTERN = BuildSkillPattern(ITEM_MIN_SKILL or "Requires %s (%d)")

function RRF_GetSkill(recipe)

   return recipe.Skill

end

local function ReadSkillFromTooltip(id)

   local data = C_TooltipInfo.GetItemByID(id)
   for _, line in ipairs(data and data.lines or { }) do
      -- unmet requirements are colored red: strip |cAARRGGBB ... |r first
      local text = line.leftText and line.leftText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      if (text) then
         local _, rank = string.match(text, SKILL_PATTERN)
         if (rank) then return tonumber(rank) end
      end
   end
   return nil

end

-- Loads every recipe item whose required skill is unknown and reads it.
function RRF_ItemData_ResolveSkills(on_done)

   local pending = 0
   for id, list in pairs(Index()) do
      if (not list[1].Skill) then
         pending = pending + 1
         Item:CreateFromItemID(id):ContinueOnItemLoad(function()
            local rank = ReadSkillFromTooltip(id)
            if (rank) then
               Cache(id).skill = rank
               Apply(id, { Skill = rank })
            end
            pending = pending - 1
            if (pending == 0 and on_done) then on_done() end
         end)
      end
   end
   if (pending == 0 and on_done) then on_done() end

end

-----------------------------------------------------------------------------
-- Prices from merchant windows
-----------------------------------------------------------------------------

local function RecordMerchant()

   local changed = false
   for i = 1, GetMerchantNumItems() do
      local id = GetMerchantItemID(i)
      if (id and Index()[id]) then
         local info = C_MerchantFrame.GetItemInfo(i)
         local fields = { }
         if (info and info.hasExtendedCost and GetMerchantItemCostInfo(i) > 0) then
            local _, value, link = GetMerchantItemCostItem(i, 1)
            local currency = link and tonumber(string.match(link, "currency:(%d+)"))
            local token = link and tonumber(string.match(link, "item:(%d+)"))
            if (currency) then
               fields.Currency, fields.Amount = currency, value
            elseif (token) then
               fields.Token, fields.Amount = token, value
            end
            if (info.price and info.price > 0) then fields.Cost = info.price end
         elseif (info and info.price and info.price > 0) then
            fields.Cost = info.price
         end
         if (fields.Cost or fields.Currency or fields.Token) then
            local c = Cache(id)
            c.cost, c.currency, c.token, c.amount = fields.Cost, fields.Currency, fields.Token, fields.Amount
            SetPrice(id, fields.Cost, fields.Currency, fields.Token, fields.Amount)
            changed = true
         end
      end
   end
   if (changed) then RRF_RefreshIfShown() end

end

-----------------------------------------------------------------------------
-- Cost formatting
-----------------------------------------------------------------------------

-- Returns copper (number) for gold prices, otherwise a display string.
function RRF_GetRecipeCost(recipe)

   if (recipe.Currency) then
      local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(recipe.Currency)
      local name = (info and info.name) or RRF_S("Merchant's Favor")
      local icon = info and info.iconFileID and ("|T" .. info.iconFileID .. ":0|t ") or ""
      return string.format("%d %s%s", recipe.Amount or 0, icon, name)
   end
   if (recipe.Token) then
      local name = C_Item.GetItemInfo(recipe.Token) or ("item " .. recipe.Token)
      local icon = C_Item.GetItemIconByID(recipe.Token)
      return string.format("%d %s%s", recipe.Amount or 0, icon and ("|T" .. icon .. ":0|t ") or "", name)
   end
   if (recipe.Cost) then
      return recipe.Cost
   end
   return RRF_S("Price unknown (visit the vendor)")

end

-----------------------------------------------------------------------------
-- Verify
-----------------------------------------------------------------------------

function RRF_ItemData_Verify()

   local total, unknown = 0, { }
   for id in pairs(Index()) do
      total = total + 1
      if (not C_Item.DoesItemExistByID(id)) then table.insert(unknown, id) end
   end
   table.sort(unknown)
   RRF_Print(string.format("Recipe Radar: %d recipes checked, %d unknown to the server.",
         total, #unknown))
   if (#unknown > 0) then
      RRF_Print("Unknown item IDs: " .. table.concat(unknown, ", "))
   end
   RRF_ItemData_ResolveSkills(function()
      local missing = { }
      for id, list in pairs(Index()) do
         if (not list[1].Skill) then
            table.insert(missing, string.format("%d %s", id, C_Item.GetItemInfo(id) or "?"))
         end
      end
      table.sort(missing)
      RRF_Print(string.format("Recipe Radar: required skill known for all but %d recipes.", #missing))
      for _, line in ipairs(missing) do RRF_Print("   " .. line) end
      RRF_RefreshIfShown()
   end)

end

-----------------------------------------------------------------------------
-- Init
-----------------------------------------------------------------------------

-- Applies cached skills and prices to the data tables (called on login and
-- after a QuestieDB import).
function RRF_ItemData_ApplyCache()

   if (type(RecipeRadarForever_ItemCache) ~= "table") then RecipeRadarForever_ItemCache = { } end
   for id, c in pairs(RecipeRadarForever_ItemCache) do
      if (c.skill) then Apply(id, { Skill = c.skill }) end
      if (c.cost or c.currency or c.token) then
         SetPrice(id, c.cost, c.currency, c.token, c.amount)
      end
   end

end

local events = CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:SetScript("OnEvent", function()
   -- MERCHANT_UPDATE fires repeatedly while item data arrives; record once per burst
   if (ns.merchantQueued) then return end
   ns.merchantQueued = true
   C_Timer.After(0.3, function()
      ns.merchantQueued = false
      if (MerchantFrame and MerchantFrame:IsShown()) then RecordMerchant() end
   end)
end)
