-- For a more human-readable version of what's going on here, scroll to the bottom of the file, I have short explanations of my thought process there.
local ItemLib = include("lib.itemLib")
local sfx = SFXManager()
local function TriggerEffect(player) -- Triggers the effect of USS on the player [adding cache flags and stuff]
    local data = player:GetData()
    data.timer = data.timer + 1800   -- 1800 frames, or exactly 30 seconds at 60 FPS

    data.spicybuff = true
    player:AddCacheFlags(CacheFlag.CACHE_SPEED, true)
    player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE, true)
    return true
end

local function EvalCache(_, player, cacheFlag) -- Applies stat changes. [increase in move speed & fire rate / damage up]
    local data = player:GetData()
    if data.spicybuff then
        if cacheFlag == CacheFlag.CACHE_SPEED then player.MoveSpeed = player.MoveSpeed + 0.3 end
        if cacheFlag == CacheFlag.CACHE_FIREDELAY then player.MaxFireDelay = player.MaxFireDelay / 3 end
        if cacheFlag == CacheFlag.CACHE_DAMAGE then player.Damage = player.Damage * 2 end
    end
end

local function PlayerUpdate(_, player) -- Timer logic
    if (player == nil) then return end
    local data = player:GetData()
    if not data.timer then data.timer = 0 end
    -- Spicy spray timer
    if data.spicybuff then
        data.timer = data.timer - 1
        if data.timer < 1 then -- Timer has expired
            data.spicybuff = false
            player:AddCacheFlags(CacheFlag.CACHE_SPEED, true)
            player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE, true)
        else -- Timer is still running
            data.spicybuff = true
            player:AddCacheFlags(CacheFlag.CACHE_SPEED, true)
            player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY, true)
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE, true)
        end
    end
    if not data.timer == nil then
        data.timer = math.max(data.timer, 0); -- make sure the timer doesn't fall under 0
    end
end

local function ppr(_, player) -- sfx & flashing
    local data = player:GetData()
    if data.spicybuff then
        if not sfx:IsPlaying(Isaac.GetSoundIdByName("ussloop")) then
            sfx:Play(Isaac.GetSoundIdByName("ussloop"), 0.8, 0, true, 1, 0)
        end
        player:GetSprite().Color = Color((math.random(100, 150)) / 100, math.random(60, 100) / 100,
            math.random(60, 100) / 100, 1, 0, 0, 0)                                                                                         -- Sprite flickering
    else
        sfx:Stop(Isaac.GetSoundIdByName("ussloop"))
        if data.shouldPlaySadSound then
            if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp") or player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) or player:GetPlayerType() == Isaac.GetPlayerTypeByName("Tarnished Amp") then
                sfx:Play(Isaac.GetSoundIdByName("ussoff"), 0.8, 0, false, 1, 0) -- Amp [play whine noise]
            else
                player:AnimateSad()                                             -- not Amp [play sad animation instead]
            end
            player:GetSprite().Color = Color.Default                            -- reset sprite color
            data.shouldPlaySadSound = false
        end
    end
end

local function invoke(_, type, rng, player) -- Invokes the effect of the item.
    local data = player:GetData()
    if table.contains(player:GetVoidedCollectiblesList(), (Isaac.GetItemIdByName("Ultra-Spicy Spray"))) and player:GetActiveItemSlot(CollectibleType.COLLECTIBLE_VOID) ~= nil then return end
    -- Above: Check if USS is being invoked by Void and abort if it's being used
    if type == Isaac.GetItemIdByName("Ultra-Spicy Spray") then
        local effects = player:GetEffects()
        effects:AddCollectibleEffect(Isaac.GetItemIdByName("Ultra-Spicy Spray"), false, 1)
        TriggerEffect(player)
        player:AddActiveCharge(-12, player:GetActiveItemSlot(Isaac.GetItemIdByName("Ultra-Spicy Spray")), false, true,
            false)                                                 -- Workaround for issue with charge not draining on use
        if type == Isaac.GetItemIdByName("Ultra-Spicy Spray") then -- For some reason I have to do this again or else it'll play the sound for any random active you use?? Amazing modding API, nicalis
            sfx:Play(Isaac.GetSoundIdByName("uss"), 0.8, 0, false, 1, 0)
        end
        if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp") or player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) or player:GetPlayerType() == Isaac.GetPlayerTypeByName("Tarnished Amp") then
            sfx:Play(Isaac.GetSoundIdByName("usson"), 0.8, 0, false, 1, 0) -- Amp's winding up sound
        end
        data.shouldPlaySadSound = true                                     -- Preparing to play sound when spray wears off.
        return { Discharge = true, Remove = false, ShowAnim = true }
    end
end
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

ItemLib:add(ModCallbacks.MC_USE_ITEM, invoke)
ItemLib:add(ModCallbacks.MC_POST_PLAYER_UPDATE, PlayerUpdate)
ItemLib:add(ModCallbacks.MC_EVALUATE_CACHE, EvalCache)
ItemLib:add(ModCallbacks.MC_POST_PLAYER_RENDER, ppr)

return ItemLib

--[[
    When Amp, or anyone, uses Ultra-Spicy Spray, they gain double damage, a ~2.5x fire rate up, and +0.3 speed for 30 seconds.

    Invoke() is what is actually running when you press your active item button, and handles stuff like the sound of the spray itself & Amp's whine, if you're playing them.
    PlayerUpdate() simply handles the logic for the spray's timer.
    EvalCache() is what actually applies the stat boosts.
     * Fire delay uses the Afterbirth+ formula internally. Dividing by 3 gives a roughly 2.5x boost to Isaac's fire rate.
    ppr() [Post Player Render] handles the whining sound effect when the spray is active, and the flickering of the player's sprite.

    I use entity data on the player to keep track of everything as it's much less of a headache compared to using tables and having to factor in every possible combination of players. This has the added benefit of dealing with characters that have two separate sub-characters. [Jacob & Esau, Tainted Lazarus, and to an extent Tainted Forgotten]. The issues with entity data that normally discourage its use don't really affect me here as I don't need or want any of the effects to persist across runs or the like.
]]
