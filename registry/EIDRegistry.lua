local EIDRegistry = {}

---register items to EID
---@param itemRegistry ItemRegistry
function EIDRegistry.register(itemRegistry)
  if EID then
    EID:addCollectible(itemRegistry.Spicy, "{{Timer}} Receive for 30 seconds:#↑ 2x Damage multiplier#↑ 2.5x Fire rate multiplier#↑ +0.3 Speed up")
  end
end

return EIDRegistry
