local ItemLib = include("lib.itemLib")
local game = Game()
local function resetStats(_, player)
    if not player:GetData().seedlingRevive then return end
    if player:GetMaxHearts() > 0 then
        player:AddMaxHearts(-24) -- remove all health
        player:AddMaxHearts(4) -- give two red hearts
        player:SetFullHearts()
    elseif player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then
        player:AddSoulHearts(5)
    end
end

local function seedlingRevive(_, player)
    if not player:HasCollectible(Isaac.GetItemIdByName("Seedling")) then return end
    player:RemoveCollectible(Isaac.GetItemIdByName("Seedling"))
    local data = player:GetData()
    data.seedlingRevive = true
    if player:GetPlayerType() == Isaac.GetPlayerTypeByName("Amp", true) then -- Tainted Amp simply revives w/o changing back to normal
        player:Revive();
    else
        player:ChangePlayerType(Isaac.GetPlayerTypeByName("Amp"));
        player:Revive();
    end

    -- all following code shamelessly lifted from fiend folio because there's no "go back to the last room" function lmao
    local level = game:GetLevel()
    local room = game:GetRoom()

    local enterDoorIndex = level.EnterDoor
    if enterDoorIndex == -1 or room:GetDoor(enterDoorIndex) == nil or level:GetCurrentRoomIndex() == level:GetPreviousRoomIndex() then
        game:StartRoomTransition(level:GetCurrentRoomIndex(), Direction.NO_DIRECTION, RoomTransitionAnim.ANKH)
    else
        local enterDoor = room:GetDoor(enterDoorIndex)
        local targetRoomIndex = enterDoor.TargetRoomIndex
        local targetRoomDirection = enterDoor.Direction
        level.LeaveDoor = -1 -- whoever wrote devils harvest in fiend folio was confused about this and i am too
        game:StartRoomTransition(targetRoomIndex, targetRoomDirection, RoomTransitionAnim.ANKH)
    end
end

ItemLib:add(ModCallbacks.MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES, seedlingRevive);
ItemLib:add(ModCallbacks.MC_POST_PLAYER_REVIVE, resetStats)
return ItemLib