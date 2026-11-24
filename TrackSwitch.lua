local _,FT=...
-- Herbs and minerals (System > Minimap > Herbs and minerals, off by default).
-- Only the game's own minimap tracking changes; nothing else is cast.
--   swap     : switch between Find Herbs and Find Minerals every few seconds
--              or minutes while you travel, so both show up.
--   herbs    : keep Find Herbs on. Turned back on when it's off (after you
--   minerals : keep Find Minerals on.   die, log in, or pick something else).
-- Waits in fights, while dead, casting or channeling (fishing too) and on
-- flights. Switching also waits while looting, in dungeons and towns, with
-- the mouse over the minimap and (unless chosen) while standing still.
local T={}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local HERBS,MINERALS=2383,2580
local function settings() return FT.modules.System and FT.modules.System:Settings() or {} end
-- Minimap tracking index for a spell, and whether it's on.
local function find(spellID)
    local M=C_Minimap
    if not (M and M.GetNumTrackingTypes and M.GetTrackingInfo) then return nil end
    local ok,n=pcall(M.GetNumTrackingTypes); if not ok or not plain(n) or type(n)~="number" then return nil end
    local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or (GetSpellInfo and GetSpellInfo(spellID))
    for i=1,n do
        local okI,info=pcall(M.GetTrackingInfo,i)
        if okI and type(info)=="table" and ((plain(info.spellID) and info.spellID==spellID) or (name and plain(info.name) and info.name==name)) then
            return i,plain(info.active) and info.active==true
        end
    end
end
-- "off", "swap", "herbs" or "minerals" (1.11 test builds: trackSwitch=true is swap).
function T:Mode()
    local s=settings()
    local m=s.trackMode
    if m=="swap" or m=="herbs" or m=="minerals" or m=="off" then return m end
    return s.trackSwitch==true and "swap" or "off"
end
T.EVERY={{2,"2 seconds"},{3,"3 seconds"},{5,"5 seconds"},{10,"10 seconds"},{30,"30 seconds"},{60,"1 minute"},{120,"2 minutes"},{300,"5 minutes"}}
function T:Every() local n=tonumber(settings().trackSwitchEvery); return n and n>=2 and n or 3 end
function T:EveryText() local n=self:Every(); for _,e in ipairs(self.EVERY) do if e[1]==n then return e[2] end end; return n.." seconds" end
-- Does this character have what the mode needs?
function T:Known(mode)
    mode=mode or self:Mode()
    if mode=="herbs" then return find(HERBS)~=nil end
    if mode=="minerals" then return find(MINERALS)~=nil end
    return find(HERBS)~=nil and find(MINERALS)~=nil
end
-- Why it waits right now (nil = go ahead). keep=true: only what blocks
-- turning tracking back on.
function T:Paused(keep)
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then return "fight" end
    if UnitCastingInfo("player") or UnitChannelInfo("player") then return "casting" end
    if UnitOnTaxi and UnitOnTaxi("player") then return "flight" end
    if keep then return nil end
    if IsResting and IsResting() then return "town" end
    local inInstance=IsInInstance and IsInInstance()
    if plain(inInstance) and inInstance then return "dungeon" end
    if LootFrame and LootFrame:IsShown() then return "loot" end
    if Minimap and Minimap:IsMouseOver() then return "minimap" end
    if settings().trackSwitchStill~=true then
        local speed=GetUnitSpeed and GetUnitSpeed("player")
        if not (plain(speed) and type(speed)=="number" and speed>0) then return "still" end
    end
end
local function set(index) if C_Minimap and C_Minimap.SetTracking then pcall(C_Minimap.SetTracking,index,true) end end
function T:Switch()
    local herbs,herbsOn=find(HERBS)
    local minerals,mineralsOn=find(MINERALS)
    if not herbs or not minerals then return end
    -- The game can track both at once: nothing to switch.
    if herbsOn and mineralsOn then return end
    set(herbsOn and minerals or herbs)
end
function T:Keep(mode)
    local index,on=find(mode=="herbs" and HERBS or MINERALS)
    if index and not on then set(index) end
end
local timer=0
local frame=CreateFrame("Frame")
frame:Hide()
frame:SetScript("OnUpdate",function(_,dt)
    timer=timer+dt
    local mode=T:Mode()
    if mode=="swap" then
        local every=T:Every()
        if timer<every then return end
        -- Waiting: try again in half a second, not a full round.
        if T:Paused() then timer=every-.5; return end
        timer=0; T:Switch()
    else
        -- Keep one on: a cheap look every 2 seconds.
        if timer<2 then return end
        timer=0
        if not T:Paused(true) then T:Keep(mode) end
    end
end)
function T:Apply()
    local mode=self:Mode()
    local on=FT.dbReady and mode~="off" and self:Known(mode)
    if on and not frame:IsShown() then timer=0 end
    frame:SetShown(on and true or false)
end
FT:RegisterModule("TrackSwitch",T)
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","SPELLS_CHANGED","LEARNED_SPELL_IN_TAB","SKILL_LINES_CHANGED"}) do pcall(events.RegisterEvent,events,e) end
events:SetScript("OnEvent",function() if FT.Coalesce then FT:Coalesce("trackSwitch",function() T:Apply() end,1) else T:Apply() end end)
