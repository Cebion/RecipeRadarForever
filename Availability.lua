
-- Availability.lua: logic for the availability of recipes to characters

local addonName, ns = ...

-----------------------------------------------------------------------------
-- Generic, abstracted availability entry points
-----------------------------------------------------------------------------

function RRF_Availability_Init()

   if (RecipeRadarForever_Options.RealmAvailability) then
      RRF_RealmAvailDropDown:Show()
      RRF_PersonAvailDropDown:Hide()
   else
      RRF_PersonAvailDropDown:Show()
      RRF_RealmAvailDropDown:Hide()
   end

end

function RRF_Availability_Toggle()

   if (RRF_RealmAvailDropDown:IsVisible()) then
      RRF_PersonAvailDropDown:Show()
      RRF_RealmAvailDropDown:Hide()
      RecipeRadarForever_Options.RealmAvailability = false
   else
      RRF_RealmAvailDropDown:Show()
      RRF_PersonAvailDropDown:Hide()
      RecipeRadarForever_Options.RealmAvailability = true
   end
   
   RRF_FrameUpdate()

end

-----------------------------------------------------------------------------
-- Indicator for vendor/recipe item lists
-----------------------------------------------------------------------------

-- Returns a colored indication of a recipe's availability.
function RRF_Availability_GetIndicator(recipe)

   if (RecipeRadarForever_Options.RealmAvailability) then
      return RRF_RealmAvail_GetIndicator(recipe)
   else
      return RRF_PersonAvail_GetIndicator(recipe)
   end

end

-- Returns a string with the recipe's skill in parens.
function RRF_PersonAvail_GetIndicator(recipe)

   return RRF_Parens(recipe.Skill or "?")

end

-- Returns a string with a little colored realm-wide availability
-- indicator for the main vendor/recipe list.
function RRF_RealmAvail_GetIndicator(recipe)

   local key = RRF_Availability_GetKey(recipe)
   if (not key) then return "" end

   return RRF_ColorToCode(RRF_Availabilities[key].Color) ..
         "*" .. FONT_COLOR_CODE_CLOSE
   
end

-----------------------------------------------------------------------------
-- Availability tooltip code
-----------------------------------------------------------------------------

-- Populates the tooltip that displays on recipe button mouseover.
function RRF_Availability_CreateTooltip(recipe)

   local recipe_name = RRF_GetSafeItemInfo(recipe.ID)

   if (recipe_name == RRF_S("Uncached Recipe")) then

      -- the client is still loading this item from the server
      local tooltip = {
            { text = RRF_S("Uncached Recipe"), color = RRF_Colors.UncachedRecipe },
            { text = "", color = nil },
            { text = RRF_S("Item data is loading,"), color = RRF_Colors.TooltipHeading },
            { text = RRF_S("hover again in a moment."), color = RRF_Colors.TooltipHeading }, }
      for _, line in ipairs(tooltip) do
         RRF_AvailabilityTooltip_AddLine(line.text, line.color)
      end
      return

   end

   local avail, prosp, known = { }, { }, { }
   local num_avail, num_prosp, num_known = 0, 0, 0

   -- recipe labels are not saved in the skill database
   recipe_name = RRF_TrimRecipeLabel(recipe_name)

   -- iterate through each character on this realm
   for player, player_info in pairs(RecipeRadarForever_SkillDB[GetRealmName()]) do

      -- do the rest only if the character has the profession
      if (player_info.Professions and player_info.Professions[recipe.Type] and
            (player_info.Professions[recipe.Type].Rank or 0) > 0) then

         -- get player's rank
         local rank = player_info.Professions[recipe.Type].Rank or 0
         
         -- get player's relevant faction standing, if any
         local rep = nil
         local rep_key = recipe.FactionID or recipe.Faction
         local standing = rep_key and (player_info.Factions[rep_key]
               or (recipe.Faction and player_info.Factions[recipe.Faction]))
         if (standing) then
            rep = _G["FACTION_STANDING_LABEL" .. standing]
         end

         -- get player's specialty, if any
         local spec = nil
         if (recipe.Specialty) then
            spec = player_info.Professions[recipe.Type].Specialty
         end

         -- now test all of the possible recipe statuses
         if (RRF_Availability_IsAvailable(player, recipe)) then
            num_avail = num_avail + 1
            avail[num_avail] = {
                  Name = player, Rank = rank, Rep = rep, Spec = spec }

         elseif (RRF_Availability_IsProspect(player, recipe)) then
            num_prosp = num_prosp + 1
            prosp[num_prosp] = {
                  Name = player, Rank = rank, Rep = rep, Spec = spec }

         elseif (RRF_Availability_IsKnown(player, recipe)) then
            num_known = num_known + 1
            known[num_known] = {
                  Name = player, Rank = rank, Rep = rep, Spec = spec }

         end
         
      end

   end

   -- populate the "available now" entries
   if (num_avail > 0) then

      RRF_AvailabilityTooltip_AddLine(
            RRF_Availabilities["LearnableByPlayer"].Tooltip.Heading,
            RRF_Colors.TooltipHeading)
      table.sort(avail, RRF_Availability_NameSort)

      for _, line in ipairs(avail) do

         local color = RRF_Colors.LearnableByAlt
         if (line.Name == UnitName("player")) then
            color = RRF_Colors.LearnableByPlayer
         end

         local rank_suffix = line.Rank
         if (line.Rep) then  -- reputation is relevant to this line
            rank_suffix = rank_suffix .. " - " .. line.Rep
         end
         rank_suffix = RRF_Parens(rank_suffix)

         RRF_AvailabilityTooltip_AddLine(
               "   " .. line.Name .. " " .. rank_suffix, color)

      end

   end

   -- populate the "available soon" entries
   if (num_prosp > 0) then

      if (num_avail > 0) then
         RRF_AvailabilityTooltip_AddLine()
      end
      RRF_AvailabilityTooltip_AddLine(
            RRF_Availabilities["ProspectForPlayer"].Tooltip.Heading,
            RRF_Colors.TooltipHeading)
      table.sort(prosp, RRF_Availability_NameSort)

      for _, line in ipairs(prosp) do

         local color = RRF_Colors.ProspectForAlt
         if (line.Name == UnitName("player")) then
            color = RRF_Colors.ProspectForPlayer
         end

         local factors = RRF_Availability_GetLimitingFactors(
               line.Name, recipe)

         local rank = string.format(RRF_S("%d of %s"), line.Rank, tostring(recipe.Skill or "?"))
         if (factors["rank"]) then
            rank = RRF_HighlightString(rank, color)
         end
         local suffix = rank  -- always include rank in the tooltip

         if (line.Rep) then
            local rep = line.Rep
            if (factors["rep"]) then
               rep = RRF_HighlightString(rep, color)
            end
            suffix = suffix .. " - " .. rep
         end
         
         if (line.Spec) then
            local spec = line.Spec
            if (factors["spec"]) then
               spec = RRF_HighlightString(spec, color)
            end
            suffix = suffix .. " - " .. spec
         end

         suffix = RRF_Parens(suffix)
         RRF_AvailabilityTooltip_AddLine(
               "   " .. line.Name .. " " .. suffix, color)
               
      end

   end

   -- populate the "already known" entries
   if (num_known > 0) then

      if (num_prosp > 0 or num_avail > 0) then
         RRF_AvailabilityTooltip_AddLine()
      end
      RRF_AvailabilityTooltip_AddLine(
            RRF_Availabilities["KnownByPlayer"].Tooltip.Heading,
            RRF_Colors.TooltipHeading)
      table.sort(known, RRF_Availability_NameSort)

      for _, line in ipairs(known) do

         local color = RRF_Colors.KnownByAlt
         if (line.Name == UnitName("player")) then
            color = RRF_Colors.KnownByPlayer
         end

         local rank_suffix = line.Rank
         if (line.Rep) then  -- reputation is relevant to this line
            rank_suffix = rank_suffix .. " - " .. line.Rep
         end
         rank_suffix = RRF_Parens(rank_suffix)

         RRF_AvailabilityTooltip_AddLine(
               "   " .. line.Name .. " " .. rank_suffix, color)

      end

   end

end

-- Boolean test for availability used by CreateTooltip(), above
function RRF_Availability_NameSort(line1, line2)

   return line1.Name < line2.Name

end

-- Returns a set of booleans from which one can derive the availability
-- of any recipe relative to any player.
function RRF_Availability_GetBooleans(player, recipe)

   local info = RRF_SkillDB_GetSafePlayerDB(player)

   -- if the player doesn't even have the profession, just return
   if (not info.Professions[recipe.Type]) then return false end

   local recipe_name = RRF_GetSafeItemInfo(recipe.ID)
   recipe_name = RRF_TrimRecipeLabel(recipe_name)

   if (recipe_name == RRF_S("Uncached Recipe")) then
      return nil
   end

   -- otherwise, get the other relevant booleans
   local has_rec = (info.Professions[recipe.Type].Recipes or { })[recipe_name]
   -- unknown required skill (not resolved from the tooltip yet) counts as met
   local has_rank = (info.Professions[recipe.Type].Rank or 0) >= (recipe.Skill or 0)
   local has_rep = RRF_SkillDB_HasRep(player, recipe)
   local has_spec = RRF_SkillDB_HasSpec(player, recipe)

   return true, has_rec, has_rank, has_rep, has_spec

end

-- Boolean test for availability used by CreateTooltip() and GetKey()
function RRF_Availability_IsAvailable(player, recipe)

   local has_prof, has_rec, has_rank, has_rep, has_spec =
         RRF_Availability_GetBooleans(player, recipe)

   return (has_prof and not has_rec and has_rank and has_rep and has_spec)

end

-- Boolean test for availability used by CreateTooltip() and GetKey()
function RRF_Availability_IsProspect(player, recipe)

   local has_prof, has_rec, has_rank, has_rep, has_spec =
         RRF_Availability_GetBooleans(player, recipe)
         
   return (has_prof and not has_rec and
         (not has_rank or not has_rep or not has_spec))

end

-- Boolean test for availability used by CreateTooltip() and GetKey()
function RRF_Availability_IsKnown(player, recipe)

   local has_prof, has_rec, has_rank, has_rep, has_spec =
         RRF_Availability_GetBooleans(player, recipe)

   return (has_prof and has_rec and has_rank and has_rep and has_spec)

end

-- Returns a table of strings that specify why the given recipe is not
-- available to the given player.
function RRF_Availability_GetLimitingFactors(player, recipe)

   local has_prof, has_rec, has_rank, has_rep, has_spec =
         RRF_Availability_GetBooleans(player, recipe)
   local factors = { }
         
   if (not has_prof) then factors["prof"] = 1 end
   if (not has_rec) then factors["rec"] = 1 end
   if (not has_rank) then factors["rank"] = 1 end
   if (not has_rep) then factors["rep"] = 1 end
   if (not has_spec) then factors["spec"] = 1 end

   return factors

end

-----------------------------------------------------------------------------
-- Availability testing for filtering and dropdowns
-----------------------------------------------------------------------------

-- This function tests whether the recipe is learnable either by
-- the player or an alt if realm-wide availability is on.
function RRF_Availability_IsLearnable(recipe, set_filter)

   local avail = RRF_Availability_GetKey(recipe)
   if (not avail) then return false end
   
   if (set_filter) then
      recipe.IsFilteredByAvailability =
            RRF_IsAvailabilityFiltered(avail)
   end
   
   if (RecipeRadarForever_Options.RealmAvailability) then
      return avail == "LearnableByPlayer" or avail == "LearnableByAlt"
   else
      return avail == "LearnableByPlayer"
   end

end

-- Wrapper for the above that makes its functionality clearer.
function RRF_Availability_SetAvailabilityFilter(recipe)

   RRF_Availability_IsLearnable(recipe, true)

end

-- Generic function returns the key to the RRF_Availabilities
-- table so the caller can get whatever related info she needs.
function RRF_Availability_GetKey(recipe)

   if (RRF_Availability_IsAvailable(nil, recipe)) then
      return "LearnableByPlayer"

   elseif (RecipeRadarForever_Options.RealmAvailability and
         RRF_Availability_IsSatisfiedByAlt(recipe,
         RRF_Availability_IsAvailable)) then
      return "LearnableByAlt"

   elseif (RRF_Availability_IsProspect(nil, recipe)) then
      return "ProspectForPlayer"

   elseif (RecipeRadarForever_Options.RealmAvailability and
         RRF_Availability_IsSatisfiedByAlt(recipe,
         RRF_Availability_IsProspect)) then
      return "ProspectForAlt"

   elseif (RRF_Availability_IsKnown(nil, recipe)) then
      return "KnownByPlayer"

   elseif (RecipeRadarForever_Options.RealmAvailability and
         RRF_Availability_IsSatisfiedByAlt(recipe,
         RRF_Availability_IsKnown)) then
      return "KnownByAlt"

   else
      return "NotApplicable"
   end

end

-- Boolean test for availability used by GetKey(), above.
function RRF_Availability_IsSatisfiedByAlt(recipe, sat_func)

   for player, player_info in pairs(RecipeRadarForever_SkillDB[GetRealmName()]) do

      if (player_info.Team ~= RRF_GetOpposingFaction("player") and
            player ~= UnitName("player") and
            sat_func(player, recipe)) then
         return true
      end
   
   end
   return false

end
