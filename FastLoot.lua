local _,FT=...
-- Faster looting: when auto loot is on (the game option, or holding its
-- modifier key), take every item as soon as the loot is ready instead of
-- waiting for the loot window to open slot by slot. It only speeds up what
-- auto loot already does; Blizzard still asks before binding items.
local Loot={}
local last=0
local function locked(slot)
    if not GetLootSlotInfo then return false end
    local ok,_,_,_,_,_,isLocked=pcall(GetLootSlotInfo,slot)
    return ok and isLocked==true
end
function Loot:Take(autoloot)
    local s=FT.modules.System and FT.modules.System:Settings()
    if not s or not s.fastLoot or not autoloot then return end
    if type(GetNumLootItems)~="function" or type(LootSlot)~="function" then return end
    local now=GetTime()
    if now-last<.3 then return end -- the event can arrive twice for one corpse
    last=now
    for slot=GetNumLootItems(),1,-1 do
        if not locked(slot) then pcall(LootSlot,slot) end
    end
end
FT:RegisterModule("FastLoot",Loot)
local events=CreateFrame("Frame")
events:RegisterEvent("LOOT_READY")
events:SetScript("OnEvent",function(_,_,autoloot)
    if FT.dbReady and (not issecretvalue or not issecretvalue(autoloot)) then Loot:Take(autoloot==true) end
end)
