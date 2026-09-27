local _,FT=...
-- /ft probe: a short, opt-in test of what the game lets addons read during
-- combat (threat values and damage taken). It only runs while turned on,
-- reports in chat and changes nothing. Used to plan the threat meter and the
-- "standing in fire" warning honestly.
local Probe={}
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function say(text) local f=DEFAULT_CHAT_FRAME or ChatFrame1; if f then f:AddMessage("|cffc9a0ffForeverTools probe:|r "..text) end end
local frame=CreateFrame("Frame")
local function describe(value)
    if value==nil then return "nothing" end
    if secret(value) then return "hidden (secret)" end
    return "readable"
end
function Probe:Sample(label)
    local lines={}
    local restricted=C_CombatLog and C_CombatLog.IsCombatLogRestricted and select(2,pcall(C_CombatLog.IsCombatLogRestricted))
    lines[#lines+1]="combat log restricted: "..tostring(restricted)
    if UnitExists and UnitExists("target") and UnitDetailedThreatSituation then
        local ok,tanking,status,scaled=pcall(UnitDetailedThreatSituation,"player","target")
        lines[#lines+1]="threat on target: "..(ok and describe(scaled) or "error")
    else lines[#lines+1]="threat on target: no target" end
    lines[#lines+1]="damage-taken events seen: "..(self.unitCombat or 0)..(self.unitCombat and self.unitCombat>0 and (", amounts "..(self.unitCombatSecret and "hidden" or "readable")) or "")
    local inInstance,kind=IsInInstance and IsInInstance()
    lines[#lines+1]="where: "..(inInstance and tostring(kind) or "open world")..((IsInGroup and IsInGroup()) and ", in a group" or ", solo")
    say(label..": "..table.concat(lines," · "))
end
function Probe:Toggle()
    self.on=not self.on
    if self.on then
        -- The combat log is not touched: the game reserves it for its own UI
        -- here, and listening to it shows a "blocked" message.
        self.unitCombat,self.unitCombatSecret=0,false
        frame:RegisterUnitEvent("UNIT_COMBAT","player")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED"); frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        say("on. Target a mob and fight it for 10+ seconds. Best: once in a dungeon group too. Results print when combat starts, midway and ends. Type /ft probe again to stop.")
    else
        frame:UnregisterAllEvents()
        say("off.")
    end
end
frame:SetScript("OnEvent",function(_,event,unit,action,flag,amount)
    if event=="UNIT_COMBAT" then
        Probe.unitCombat=(Probe.unitCombat or 0)+1
        if secret(amount) or secret(action) then Probe.unitCombatSecret=true end
    elseif event=="PLAYER_REGEN_DISABLED" then
        Probe:Sample("combat start")
        C_Timer.After(6,function() if Probe.on and InCombatLockdown() then Probe:Sample("in combat") end end)
    elseif event=="PLAYER_REGEN_ENABLED" then
        Probe:Sample("combat end")
    end
end)
FT:RegisterModule("Probe",Probe)
