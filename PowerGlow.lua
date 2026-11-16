local _,FT=...
-- Poised glow: while you have Poised (energy users: your next Energy ability
-- costs less), sparks and twinkling stars run over the energy bar on your
-- player frame, so you don't have to look at your buffs. Off by default
-- (Combat > Poised). Only drawn while the buff is up: two looping
-- animations, nothing runs in the background.
local Glow={}
FT.PowerGlow=Glow
local POISED=1328826
local function secret(v) return issecretvalue and issecretvalue(v) end
function Glow:On() return FT.dbReady and FT.modules.System:Settings().poisedGlow==true end
-- By default only while you target a living enemy (Combat > Poised can
-- show it always).
function Glow:Always() return FT.dbReady and FT.modules.System:Settings().poisedAlways==true end
function Glow:EnemyTarget()
    local ok,yes=pcall(function()
        return UnitExists("target") and UnitCanAttack("player","target") and not UnitIsDeadOrGhost("target")
    end)
    return ok and yes==true
end
-- Your energy bar on the player frame.
function Glow:Bar()
    local frame=PlayerFrame
    local content=frame and frame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    local bar=main and main.ManaBarArea and main.ManaBarArea.ManaBar
    return bar or (frame and (frame.manabar or frame.ManaBar))
end
-- Is Poised up? By its spell ID, else by name.
function Glow:Has()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok,aura=pcall(C_UnitAuras.GetPlayerAuraBySpellID,POISED)
        if ok and aura and not secret(aura) then return true end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok,aura=pcall(C_UnitAuras.GetAuraDataBySpellName,"player","Poised","HELPFUL")
        if ok and aura and not secret(aura) then return true end
    end
    return false
end
function Glow:Build(bar)
    if self.frame then return self.frame end
    local f=CreateFrame("Frame",nil,bar)
    f:SetFrameLevel((bar:GetFrameLevel() or 1)+5)
    f:SetAllPoints(bar)
    -- Nothing covers the bar itself: only sparkles on top of it.
    -- Two sparks gliding along the bar at different, calm speeds.
    local sparks={}
    for i,spec in ipairs({{2.4,.9},{1.7,.6}}) do
        local s=f:CreateTexture(nil,"OVERLAY",nil,7)
        s:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); s:SetBlendMode("ADD")
        s:SetVertexColor(.75,.9,1,spec[2])
        local run=f:CreateAnimationGroup(); run:SetLooping("REPEAT")
        local move=run:CreateAnimation("Translation"); move:SetTarget(s); move:SetDuration(spec[1])
        sparks[i]={tex=s,run=run,move=move}
    end
    -- Small stars that twinkle in and out at spots along the bar.
    local stars={}
    for i,spec in ipairs({{.12,0},{.34,.5},{.55,.2},{.76,.8},{.92,.35}}) do
        local t=f:CreateTexture(nil,"OVERLAY",nil,6)
        t:SetTexture("Interface\\Cooldown\\star4"); t:SetBlendMode("ADD")
        t:SetVertexColor(.8,.95,1,1); t:SetAlpha(0)
        local g=f:CreateAnimationGroup(); g:SetLooping("REPEAT")
        local wait=g:CreateAnimation("Alpha"); wait:SetTarget(t); wait:SetFromAlpha(0); wait:SetToAlpha(0); wait:SetDuration(.05); wait:SetStartDelay(spec[2]); wait:SetOrder(1)
        local on=g:CreateAnimation("Alpha"); on:SetTarget(t); on:SetFromAlpha(0); on:SetToAlpha(.9); on:SetDuration(.35); on:SetOrder(2)
        local off=g:CreateAnimation("Alpha"); off:SetTarget(t); off:SetFromAlpha(.9); off:SetToAlpha(0); off:SetDuration(.5); off:SetOrder(3)
        local rest=g:CreateAnimation("Alpha"); rest:SetTarget(t); rest:SetFromAlpha(0); rest:SetToAlpha(0); rest:SetDuration(.6+i*.15); rest:SetOrder(4)
        stars[i]={tex=t,run=g,x=spec[1]}
    end
    f.sparks,f.stars=sparks,stars
    f:Hide()
    self.frame=f
    return f
end
function Glow:Show(bar)
    local f=self:Build(bar)
    local w,h=bar:GetWidth() or 100,bar:GetHeight() or 10
    for _,s in ipairs(f.sparks) do
        s.tex:SetSize(12,h*2); s.tex:ClearAllPoints(); s.tex:SetPoint("CENTER",bar,"LEFT",0,0)
        s.move:SetOffset(w,0)
        if not s.run:IsPlaying() then s.run:Play() end
    end
    for i,s in ipairs(f.stars) do
        local size=math.max(10,h*1.6)
        s.tex:SetSize(size,size); s.tex:ClearAllPoints()
        s.tex:SetPoint("CENTER",bar,"LEFT",w*s.x,(i%2==0) and h*.25 or -h*.2)
        if not s.run:IsPlaying() then s.run:Play() end
    end
    f:Show()
end
function Glow:Hide()
    local f=self.frame; if not f then return end
    f:Hide()
    for _,s in ipairs(f.sparks) do s.run:Stop() end
    for _,s in ipairs(f.stars) do s.run:Stop(); s.tex:SetAlpha(0) end
end
-- Preview: shows the glow without the buff, until you turn it off.
function Glow:Check()
    local bar=self:Bar()
    if bar and (self.preview or (self:On() and self:Has() and (self:Always() or self:EnemyTarget()))) then self:Show(bar) else self:Hide() end
end
function Glow:Apply()
    if self:On() then
        self.events:RegisterUnitEvent("UNIT_AURA","player")
        self.events:RegisterEvent("PLAYER_TARGET_CHANGED")
    else
        self.events:UnregisterEvent("UNIT_AURA")
        self.events:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
    self:Check()
end
local events=CreateFrame("Frame"); Glow.events=events
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_ENTERING_WORLD" then Glow:Apply() else Glow:Check() end
end)
