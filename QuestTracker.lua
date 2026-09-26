local _,FT=...
-- Quest objectives: Default (the game's own behaviour), always collapsed or
-- always open after login or a reload (opening or closing it yourself is
-- respected for the rest of that session), or hidden altogether.
local Tracker={}
function Tracker:Mode()
    local mode=FT.modules.System:Settings().objectives
    return (mode=="collapsed" or mode=="open" or mode=="hidden") and mode or "default"
end
function Tracker:Hook(tracker)
    if self.hooked or not tracker.HookScript then return end
    self.hooked=true
    -- The game shows the tracker again on its own (new quests, zoning).
    tracker:HookScript("OnShow",function(frame)
        if Tracker:Mode()~="hidden" then return end
        if InCombatLockdown() then Tracker.pending=true else frame:Hide() end
    end)
end
function Tracker:Apply()
    local mode=self:Mode()
    local tracker=ObjectiveTrackerFrame
    if not tracker then return end
    if InCombatLockdown() then self.pending=true; return end
    self.pending=nil
    if mode=="hidden" then self:Hook(tracker); self.wasHidden=true; tracker:Hide(); return end
    if self.wasHidden then self.wasHidden=nil; tracker:Show() end
    if mode=="default" then return end
    local collapse=mode=="collapsed"
    if tracker.SetCollapsed and tracker.IsCollapsed then
        if tracker:IsCollapsed()~=collapse then pcall(tracker.SetCollapsed,tracker,collapse) end
    elseif collapse and ObjectiveTracker_Collapse then pcall(ObjectiveTracker_Collapse)
    elseif not collapse and ObjectiveTracker_Expand then pcall(ObjectiveTracker_Expand) end
end
FT:RegisterModule("QuestTracker",Tracker)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event,initialLogin,reloading)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_ENABLED" then if Tracker.pending then Tracker:Apply() end; return end
    -- Only a fresh login or reload, not every loading screen. The tracker
    -- finishes its own setup first, so wait a moment.
    if initialLogin or reloading then C_Timer.After(1,function() Tracker:Apply() end) end
end)
