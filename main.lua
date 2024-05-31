-- Imports --
local characters = include("mod.stats")
-- file loc
local _, _err = pcall(require, "")
---@type string
local modName = _err:match("/mods/(.*)/%.lua")

-- Init --
local mod = RegisterMod(modName, 1)
-- CODE --
local config = Isaac.GetItemConfig()
local game = Game()
local pool = game:GetItemPool()
local game_started = false -- a hacky check for if the game is continued.
local is_continued = false -- a hacky check for if the game is continued.

-- Repentogon check - display a warning message if it's not present
mod:AddCallback(ModCallbacks.MC_POST_RENDER, function()
    if not REPENTOGON then
        local f = Font()
        f:Load("resources/font/pftempestasevencondensed.fnt")
        f:DrawString("The REPENTOGON script extender is required for Amp.", 40, 40, KColor(1, 0.5, 0.5, 1))
    end
end)

-- Utility Functions
  
local function length(table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end
  
local function runUpdates(tab)
    for i = #tab, 1, -1 do
        local f = tab[i]
        f.Delay = f.Delay - 1
        if f.Delay <= 0 then
            f.Func()
            table.remove(tab, i)
        end
    end
end

mod.delayedFuncs = {}
function mod.scheduleForUpdate(foo, delay, callback, noCancelOnNewRoom)
    callback = callback or ModCallbacks.MC_POST_UPDATE
    if not mod.delayedFuncs[callback] then
        mod.delayedFuncs[callback] = {}
        mod:AddCallback(callback, function()
            runUpdates(mod.delayedFuncs[callback])
        end)
    end

    table.insert(mod.delayedFuncs[callback], { Func = foo, Delay = delay, NoCancel = noCancelOnNewRoom })
end

---converts tearRate to the FireDelay formula, then modifies the FireDelay by the request amount, returns Modified FireDelay
---@param currentTearRate number
---@param offsetBy number
---@return number
local function calculateNewFireDelay(currentTearRate, offsetBy)
    local currentTears = 30 / (currentTearRate + 1)
    local newTears = currentTears + offsetBy
    return math.max((30 / newTears) - 1, -0.9999)
end

-- Character Code

---@param _ any
---@param player EntityPlayer
---@param cache CacheFlag | BitSet128
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cache)
    if not (characters:isACharacterDescription(player)) then return end

    local playerStat = characters:getCharacterDescription(player).stats

    if (playerStat.Damage and cache & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE) then
        player.Damage = player.Damage + playerStat.Damage
    end

    if (playerStat.Firedelay and cache & CacheFlag.CACHE_FIREDELAY == CacheFlag.CACHE_FIREDELAY) then
        player.MaxFireDelay = calculateNewFireDelay(player.MaxFireDelay, playerStat.Firedelay)
    end

    if (playerStat.Shotspeed and cache & CacheFlag.CACHE_SHOTSPEED == CacheFlag.CACHE_SHOTSPEED) then
        player.ShotSpeed = player.ShotSpeed + playerStat.Shotspeed
    end

    if (playerStat.Range and cache & CacheFlag.CACHE_RANGE == CacheFlag.CACHE_RANGE) then
        player.TearRange = player.TearRange + playerStat.Range
    end

    if (playerStat.Speed and cache & CacheFlag.CACHE_SPEED == CacheFlag.CACHE_SPEED) then
        player.MoveSpeed = player.MoveSpeed + playerStat.Speed
    end

    if (playerStat.Luck and cache & CacheFlag.CACHE_LUCK == CacheFlag.CACHE_LUCK) then
        player.Luck = player.Luck + playerStat.Luck
    end

    if (cache & CacheFlag.CACHE_FLYING == CacheFlag.CACHE_FLYING and playerStat.Flying == true) then player.CanFly = true end

    if (playerStat.Tearflags and cache & CacheFlag.CACHE_TEARFLAG == CacheFlag.CACHE_TEARFLAG) then
        player.TearFlags = player.TearFlags | playerStat.Tearflags
    end

    if (playerStat.Tearcolor and cache & CacheFlag.CACHE_TEARCOLOR == CacheFlag.CACHE_TEARCOLOR) then
        player.TearColor = playerStat.Tearcolor
    end
end)

---applies the costume to the player
---@param CostumeName string
---@param player EntityPlayer
local function applyCostume(CostumeName, player) -- actually adds the costume.
    local cost = Isaac.GetCostumeIdByPath("gfx/characters/" .. CostumeName .. ".anm2")
    if (cost ~= -1) then player:AddNullCostume(cost) end
end

---goes through each costume and applies it
---@param AppliedCostume table
---@param player EntityPlayer
local function addCostumes(AppliedCostume, player) -- costume logic
    if #AppliedCostume == 0 then return end
    if (type(AppliedCostume) == "table") then
        for i = 1, #AppliedCostume do
            applyCostume(AppliedCostume[i], player)
        end
    end
end

-- I have no idea what this does lmao
---@param player EntityPlayer
local function CriticalHitCacheCallback(player)
    if not (characters:isACharacterDescription(player)) then return end

    local playerStat = characters:getCharacterDescription(player).stats
    local data = player:GetData()

    if (playerStat.criticalChance) then
        data.critChance = data.critChance + playerStat.criticalChance
    end

    if (playerStat.criticalMultiplier) then
        data.critMultiplier = data.critMultiplier + playerStat.criticalMultiplier
    end
end

---@param player EntityPlayer
local function postPlayerInitLate(player)
    player = player or Isaac.GetPlayer()
    if not (characters:isACharacterDescription(player)) then return end
    local statTable = characters:getCharacterDescription(player)
    if statTable == nil then return end
    -- Costume
    addCostumes(statTable.costume, player)

    local items = statTable.items
    if (#items > 0) then
        for i, v in ipairs(items) do
            player:AddCollectible(v[1])
            if (v[2]) then
                local ic = config:GetCollectible(v[1])
                player:RemoveCostume(ic)
            end
        end
        local charge = statTable.charge
        if (charge and player:GetActiveItem()) then
            if (charge == true) then
                player:FullCharge()
            else
                player:SetActiveCharge(charge)
            end
        end
    end

    local trinket = statTable.trinket
    if (trinket) then player:AddTrinket(trinket, true) end

    if (statTable.PocketItem) then
        if statTable.isPill then
            player:SetPill(0, pool:ForceAddPillEffect(statTable.PocketItem))
        else
            player:SetCard(0, statTable.PocketItem)
        end
    end

    if CriticalHit then
        CriticalHit:AddCacheCallback(CriticalHitCacheCallback)
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        player:EvaluateItems()
    end
end

---@param _ any
---@param Is_Continued boolean
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, Is_Continued)
    if (not Is_Continued) then
        is_continued = false
        postPlayerInitLate()
    end
    game_started = true
end)

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
    game_started = false
end)

---@param _ any
---@param player EntityPlayer
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player)
    if (game_started == false) then return end
    if (not is_continued) then
        postPlayerInitLate(player)
    end
end)

----- EVERYTHING BELOW HERE IS MY OWN CODE, EVERYTHING ABOVE IS PART OF THE TEMPLATE I USED.

-- Convenience function - check if this player is one of Amp's variants.
---@param player EntityPlayer
local function isAmp(player)
    return player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp") or player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true);
end

-- Death sound
local sfx = SFXManager();
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if not isAmp(player) then return end
    -- normal & tarnished amp
    if (player:GetSprite():IsPlaying("Death")) and sfx:IsPlaying(SoundEffect.SOUND_ISAACDIES) then
        sfx:Stop(SoundEffect.SOUND_ISAACDIES);
        sfx:Play(Isaac.GetSoundIdByName("AmpDies"), 0.8, 0, false, 1);
    elseif (player:GetSprite():IsPlaying("LostDeath") or player:GetSprite():IsPlaying("HoleDeath")) and sfx:IsPlaying(SoundEffect.SOUND_ISAACDIES) then
        sfx:Stop(SoundEffect.SOUND_ISAACDIES);
        sfx:Play(Isaac.GetSoundIdByName("TAmpDies"), 0.8, 0, false, 1);
        -- Play Tainted Amp's death sound with a reduced delay to account for the lack of fall animation
    end
end)

-- Hurt sounds
local function ampHurts(_, entity, amount, flags)
    if amount < 1 then return end
    local player = entity:ToPlayer();
    if isAmp(player) then
        mod.scheduleForUpdate(function() sfx:Stop(SoundEffect.SOUND_ISAAC_HURT_GRUNT) end, 1);
        sfx:Play(Isaac.GetSoundIdByName("pikhurt"), 0.8, 0, false, 1);
    end
end
mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, ampHurts, 1);

-- Stage API [Revelations floors, Boiler, etc]
if StageAPI and StageAPI.Loaded then
    StageAPI.AddPlayerGraphicsInfo(Isaac.GetPlayerTypeByName("Amp"), { -- normal
        Name = "gfx/ui/boss/playername_16_Amp.png",
        Portrait = "gfx/ui/boss/playerportrait_14_Amp.png",
        NoShake = false
    })
    StageAPI.AddPlayerGraphicsInfo(Isaac.GetPlayerTypeByName("Amp", true), { -- tainted
        Name = "gfx/ui/boss/playername_16_Amp.png",
        Portrait = "gfx/ui/boss/playerportrait_14_Ampsoul.png",
        NoShake = false
    })
    StageAPI.AddPlayerGraphicsInfo(Isaac.GetPlayerTypeByName("Tarnished Amp", false), { -- tarnished
        Name = "gfx/ui/boss/playername_16_Amp.png",
        Portrait = "gfx/ui/tr/stage/playerportrait_amp.png",
        NoShake = false
    })
end

-- Custom co-op death ghosts
function mod:addCustomCoopGhostCompatibility()
    if not CustomCoopGhost then return end
    CustomCoopGhost.ChangeSkin(Isaac.GetPlayerTypeByName("Amp"), "gfx/characters/ghostamp.png");
    CustomCoopGhost.ChangeSkin(Isaac.GetPlayerTypeByName("Amp", true), "gfx/characters/ghostamp.png");
    CustomCoopGhost.ChangeSkin(Isaac.GetPlayerTypeByName("Tarnished Amp", false), "gfx/characters/ghostamp.png");
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, mod.addCustomCoopGhostCompatibility);

-- Tainted Amp's death animation [force LostDeath instead of the regular death animation, the latter looks Wrong]
---@param player EntityPlayer
local DeathAnimEntity = Isaac.GetEntityTypeByName("TAmp Death");
local function AmpDeath(_, player)
    local playerData = player:GetData();
    if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then
        if player:GetSprite():IsPlaying("Death") then
            if not playerData.dying then
                local death = Isaac.Spawn(DeathAnimEntity, 0, 0, player.Position, Vector(0, 0), player):ToNPC();
                death.Parent = player;
                death:ClearEntityFlags(EntityFlag.FLAG_APPEAR);
                death:GetSprite():Play("Death", true);
                death.CanShutDoors = false;
                playerData.dying = true;
            end
            player.Visible = false;
        elseif playerData.dying then
            playerData.dying = false;
            player.Visible = true;
        end
    else
        if not player:GetSprite():IsPlaying("Death") and playerData.dying then
            playerData.dying = false;
            player.Visible = true;
        end
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, AmpDeath);

--- Add 120 Volt as an innate item so that it cannot be rerolled by D4/D100
--- @param player EntityPlayer
local function AddItems(_, player)
    if isAmp(player) then -- Check to make sure we're Amp
        if not player:HasCollectible(CollectibleType.COLLECTIBLE_120_VOLT) then
            player:AddInnateCollectible(CollectibleType.COLLECTIBLE_120_VOLT, 1);
            player:RemoveCostume(Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_120_VOLT));
        end
    end
    if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Tarnished Amp") then
        player:AddInnateCollectible(CollectibleType.COLLECTIBLE_SPIRIT_SWORD, 1);
    end
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, AddItems);

-- EIDs
if EID then
    EID:addBirthright(Isaac.GetPlayerTypeByName("Amp"), "Gives 'Ultra-Spicy Spray' as a pocket active, which gives a stat boost for 30 seconds when used");
    EID:addBirthright(Isaac.GetPlayerTypeByName("Amp", true), "Each electronic or electricity-related item Amp carries provides +50% damage and +10% fire rate#Each electronic or electricity-related trinket Amp carries provides +35% damage and +8% fire rate#Multiple copies of the same item or trinket stack the bonus");

    -- The EID icons are completely fecked at the moment and I don't know how to fix them so they're just not gonna get loaded for now

    -- USS
    EID:addCollectible(Isaac.GetItemIdByName("Ultra-Spicy Spray"), "{{Timer}} Receive for 30 seconds:#↑ 2x Damage multiplier#↑ 2.5x Fire rate multiplier#↑ +0.3 Speed up")
end

-- Normal Amp's birthright [Spicy Spray]
local items = { -- list of file names in the items folder, so it can go through each one and run their callbacks
    "SpicySpray"
}

local function registerCallback(callback, f, opt) -- register a callback function
    if opt then
        mod:AddCallback(callback, f, opt) -- add the callback + optional filter
    else
        mod:AddCallback(callback, f) -- add the callback
    end
end

-- go through each item and run its callbacks
for i = 1, #items do
    local item = include("items." .. items[i]) -- get the item file
    for c = 1, #item.callbacks do -- for each one of the callbacks
        local cb = item.callbacks[c] -- get the callback
        registerCallback(cb.callback, cb.func, cb.opt) -- register the callback
    end
end
-- handle normal Amp's birthright and whether or not we have it
---@param player EntityPlayer
local function ampBirthright(_, player)
    if not player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp") then return end -- Amp check
    if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then return end -- hack-fix for tainted amp
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT, true) then return end -- Birthright check
    if player:GetActiveItemSlot(Isaac.GetItemIdByName("Ultra-Spicy Spray")) == ActiveSlot.SLOT_POCKET then return end -- Pocket USS check

    player:SetPocketActiveItem(Isaac.GetItemIdByName("Ultra-Spicy Spray"), ActiveSlot.SLOT_POCKET, true);
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, ampBirthright)

--------------------------------

-- Array of item IDs for Tainted Amp's electric resonance
local tAmpBrItems = {
    CollectibleType.COLLECTIBLE_BATTERY,
    CollectibleType.COLLECTIBLE_TECHNOLOGY,
    CollectibleType.COLLECTIBLE_ROBO_BABY,
    CollectibleType.COLLECTIBLE_9_VOLT,
    CollectibleType.COLLECTIBLE_TECHNOLOGY_2,
    CollectibleType.COLLECTIBLE_SHARP_PLUG,
    CollectibleType.COLLECTIBLE_TECH_5,
    CollectibleType.COLLECTIBLE_ROBO_BABY_2,
    CollectibleType.COLLECTIBLE_CAR_BATTERY,
    CollectibleType.COLLECTIBLE_CHARGED_BABY,
    CollectibleType.COLLECTIBLE_TECH_X,
    CollectibleType.COLLECTIBLE_TRACTOR_BEAM,
    CollectibleType.COLLECTIBLE_SPIDER_MOD,
    CollectibleType.COLLECTIBLE_JACOBS_LADDER,
    CollectibleType.COLLECTIBLE_BROKEN_MODEM,
    CollectibleType.COLLECTIBLE_JUMPER_CABLES,
    CollectibleType.COLLECTIBLE_TECHNOLOGY_ZERO,
    CollectibleType.COLLECTIBLE_120_VOLT,
    CollectibleType.COLLECTIBLE_BATTERY_PACK,
    CollectibleType.COLLECTIBLE_BOT_FLY,
    CollectibleType.COLLECTIBLE_4_5_VOLT,

    -- Fiend Folio
    Isaac.GetItemIdByName("Bzzt!"),
    Isaac.GetItemIdByName("Dad's Battery"),
    Isaac.GetItemIdByName("Infinity Volt"),
    Isaac.GetItemIdByName("Robo Baby 3.0"),
    
    -- Community Remix
    Isaac.GetItemIdByName("Box of Wires"),

    -- Epiphany
    Isaac.GetItemIdByName("Printer")
}

-- Ditto for trinkets
local tAmpBrTrinkets = {
    TrinketType.TRINKET_AAA_BATTERY,
    TrinketType.TRINKET_WATCH_BATTERY,
    TrinketType.TRINKET_VIBRANT_BULB,
    TrinketType.TRINKET_DIM_BULB,
    TrinketType.TRINKET_HAIRPIN,
    TrinketType.TRINKET_EXTENSION_CORD,
    TrinketType.TRINKET_OLD_CAPACITOR,

    -- Fiend Folio
    Isaac.GetTrinketIdByName("Eternal Car Battery"),
    Isaac.GetTrinketIdByName("Faulty Fuse"),
    Isaac.GetTrinketIdByName("Electrum")
}

-- Tainted Amp birthright math handlers, called whenever their cache is evaluated to update their damage & fire rate accordingly
-- There's probably a better way to do this lol
---@param player EntityPlayer
local function tAmpBirthrightDamage(player)
    if not player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then return end
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then return end
    local damage = 1; -- multiplier

    for i = 1, length(tAmpBrItems) do
        if player:GetCollectibleNum(tAmpBrItems[i], true) then
            for j = 1, player:GetCollectibleNum(tAmpBrItems[i], true) do
                damage = damage * 1.5
            end
        end
    end

    for i = 1, length(tAmpBrTrinkets) do
        if player:GetTrinketMultiplier(tAmpBrTrinkets[i]) > 0 and player:GetTrinketMultiplier(tAmpBrTrinkets[i]) < 10 then
            for j = 1, player:GetTrinketMultiplier(tAmpBrTrinkets[i]) do
                damage = damage * 1.35
            end
        end
    end
    return damage
end

---@param player EntityPlayer
local function tAmpBirthrightFireDelay(player)
    if not player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then return end
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then return end
    local firerate = 1; -- multiplier

    for i = 1, length(tAmpBrItems) do
        if player:GetCollectibleNum(tAmpBrItems[i], true) then
            for j = 1, player:GetCollectibleNum(tAmpBrItems[i], true) do
                firerate = firerate * 1.15
            end
        end
    end

    for i = 1, length(tAmpBrTrinkets) do
        if player:GetTrinketMultiplier(tAmpBrTrinkets[i]) > 0 and player:GetTrinketMultiplier(tAmpBrTrinkets[i]) < 10 then
            for j = 1, player:GetTrinketMultiplier(tAmpBrTrinkets[i]) do
                firerate = firerate * 1.08
            end
        end
    end
    return firerate
end

-- Update stats for resonance
---@param _ any
---@param player EntityPlayer
---@param flag CacheFlag
local function tAmpBrStatUpdate(_, player, flag)
    if not player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then return end -- Amp check
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then return end -- Birthright check
    if flag == CacheFlag.CACHE_DAMAGE then player.Damage = player.Damage * tAmpBirthrightDamage(player) end
    if flag == CacheFlag.CACHE_FIREDELAY then player.MaxFireDelay = player.MaxFireDelay / tAmpBirthrightFireDelay(player) end
end
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, tAmpBrStatUpdate)

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player) 
    if not player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then return end -- Amp check
    if not player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then return end -- Birthright check
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY, true)
end)
