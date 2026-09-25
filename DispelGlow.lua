local _,FT=...
-- Dispel glow: a soft colored outline around a unit frame's bars while that
-- unit has a debuff the player can remove. Which debuffs qualify comes from
-- the game's own "RAID" aura filter (harmful auras the player can dispel), so
-- unlearned dispels or the wrong level never light up. Original drawing:
-- plain white textures in stepped rings, tinted by debuff type.
local Glow={holders={}}
local frameKeys={"player","target","focus","party","raid"}
Glow.frameKeys=frameKeys
Glow.labels={player="Player",target="Target",focus="Focus",party="Party",raid="Raid-style"}
local strengths={soft=.6,medium=.85,strong=1}
Glow.strengths=strengths
-- Rings from the bar edge outwards: {thickness, alpha}.
local rings={{1,1},{2,.55},{2,.28},{2,.12}}
local fallback={.8,.55,1}
-- Game dispel-type ids used by colour curves (Magic, Curse, Disease, Poison).
local typeIDs={Magic=1,Curse=2,Disease=3,Poison=4}
function Glow:Settings()
    if type(FT.db.dispelGlow)~="table" then FT.db.dispelGlow={} end
    local s=FT.db.dispelGlow
    if type(s.enabled)~="boolean" then s.enabled=false end
    for _,key in ipairs(frameKeys) do if type(s[key])~="boolean" then s[key]=key~="raid" end end
    if not strengths[s.strength] then s.strength="medium" end
    if type(s.pulse)~="boolean" then s.pulse=false end
    return s
end
local function typeColor(name)
    local c=DebuffTypeColor and DebuffTypeColor[name]
    if c then return c.r,c.g,c.b end
    local own={Magic={.2,.6,1},Curse={.6,0,1},Disease={.6,.4,0},Poison={0,.6,0}}
    local v=own[name]; if v then return v[1],v[2],v[3] end
end
-- Colour for secret aura data (in combat): evaluated by the game itself.
function Glow:Curve()
    if self.curve~=nil then return self.curve or nil end
    self.curve=false
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor then
        local ok,curve=pcall(C_CurveUtil.CreateColorCurve)
        if ok and curve and curve.AddPoint then
            pcall(curve.AddPoint,curve,0,CreateColor(fallback[1],fallback[2],fallback[3],1))
            for name,id in pairs(typeIDs) do
                local r,g,b=typeColor(name)
                pcall(curve.AddPoint,curve,id,CreateColor(r,g,b,1))
            end
            self.curve=curve
        end
    end
    return self.curve or nil
end
local function secret(value) return issecretvalue and issecretvalue(value) end
local function bars(frame,kind)
    if kind=="raid" then return frame,frame end
    if kind=="party" then return frame.HealthBarContainer or frame.HealthBar or frame.healthbar,frame.ManaBar or frame.manabar end
    local content=frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
    if not main then return frame.healthbar or frame.HealthBar,frame.manabar end
    local mana=main.ManaBar or (main.ManaBarArea and main.ManaBarArea.ManaBar)
    return main.HealthBarsContainer or main.HealthBar,mana
end
function Glow:Holder(frame,kind,unitFn)
    local holder=self.holders[frame]
    if holder then return holder end
    if InCombatLockdown() then return end
    local top,bottom=bars(frame,kind)
    if not top then return end
    bottom=bottom or top
    holder=CreateFrame("Frame",nil,frame)
    holder:SetFrameLevel((frame:GetFrameLevel() or 1)+8)
    local out=kind=="raid" and 0 or 3
    holder:SetPoint("TOPLEFT",top,"TOPLEFT",-out,out)
    holder:SetPoint("BOTTOMRIGHT",bottom,"BOTTOMRIGHT",out,-out)
    holder.kind,holder.unitFn,holder.textures=kind,unitFn,{}
    local offset=0
    for _,ring in ipairs(rings) do
        local size,alpha=ring[1],ring[2]
        local o=offset
        for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local t=holder:CreateTexture(nil,"OVERLAY",nil,7)
            t:SetTexture("Interface\\Buttons\\WHITE8x8")
            if edge=="TOP" or edge=="BOTTOM" then
                t:SetHeight(size)
                local y=edge=="TOP" and o+size or -o-size
                t:SetPoint(edge.."LEFT",holder,edge.."LEFT",-o-size,edge=="TOP" and o+size or -o-size)
                t:SetPoint(edge.."RIGHT",holder,edge.."RIGHT",o+size,y)
            else
                t:SetWidth(size)
                local x=edge=="LEFT" and -o-size or o+size
                t:SetPoint("TOP"..edge,holder,"TOP"..edge,x,o)
                t:SetPoint("BOTTOM"..edge,holder,"BOTTOM"..edge,x,-o)
            end
            t.baseAlpha=alpha
            holder.textures[#holder.textures+1]=t
        end
        offset=offset+size
    end
    local pulse=holder:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(.35); fade:SetDuration(.8); fade:SetSmoothing("IN_OUT")
    holder.pulse=pulse
    holder:Hide()
    self.holders[frame]=holder
    return holder
end
function Glow:Paint(holder,unit,aura)
    local s=self:Settings()
    local scale=strengths[s.strength] or .85
    local r,g,b
    local name=aura.dispelName
    if not secret(name) and name~=nil then r,g,b=typeColor(name) end
    local color
    if not r and aura.auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor then
        local curve=self:Curve()
        if curve then
            local ok,value=pcall(C_UnitAuras.GetAuraDispelTypeColor,unit,aura.auraInstanceID,curve)
            if ok and value and value.GetRGB then color=value end
        end
    end
    for _,t in ipairs(holder.textures) do
        if r then t:SetVertexColor(r,g,b)
        elseif color then t:SetVertexColor(color:GetRGB())
        else t:SetVertexColor(fallback[1],fallback[2],fallback[3]) end
        t:SetAlpha(t.baseAlpha*scale)
    end
end
function Glow:PaintFallback(holder)
    local scale=strengths[self:Settings().strength] or .85
    for _,t in ipairs(holder.textures) do t:SetVertexColor(fallback[1],fallback[2],fallback[3]); t:SetAlpha(t.baseAlpha*scale) end
end
local function canAssist(unit)
    local ok,value=pcall(UnitCanAssist,"player",unit)
    return ok and not secret(value) and value
end
function Glow:Update(holder)
    local s=self:Settings()
    local unit=holder.unitFn and holder.unitFn()
    local show=false
    if s.enabled and s[holder.kind] and type(unit)=="string" and not secret(unit) and UnitExists(unit) and canAssist(unit)
        and C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,"HARMFUL|RAID",1)
        if ok and type(auras)=="table" and #auras>0 then
            show=true
            if not pcall(self.Paint,self,holder,unit,auras[1]) then self:PaintFallback(holder) end
        end
    end
    holder:SetShown(show)
    if show and s.pulse then if not holder.pulse:IsPlaying() then holder.pulse:Play() end
    elseif holder.pulse:IsPlaying() then holder.pulse:Stop() end
end
local function unitOf(frame) return function() return frame.displayedUnit or frame.unit end end
-- Finds the frames each option covers. New holders are only made out of combat.
function Glow:Collect()
    if PlayerFrame then self:Holder(PlayerFrame,"player",function() return "player" end) end
    if TargetFrame then self:Holder(TargetFrame,"target",function() return "target" end) end
    if FocusFrame then self:Holder(FocusFrame,"focus",function() return "focus" end) end
    for i=1,4 do
        local frame=(PartyFrame and PartyFrame["MemberFrame"..i]) or _G["PartyMemberFrame"..i]
        if frame then self:Holder(frame,"party",function() return frame.unit or ("party"..i) end) end
    end
    for i=1,5 do local frame=_G["CompactPartyFrameMember"..i]; if frame then self:Holder(frame,"raid",unitOf(frame)) end end
    for i=1,40 do local frame=_G["CompactRaidFrame"..i]; if frame then self:Holder(frame,"raid",unitOf(frame)) end end
    for g=1,8 do for m=1,5 do local frame=_G["CompactRaidGroup"..g.."Member"..m]; if frame then self:Holder(frame,"raid",unitOf(frame)) end end end
end
function Glow:UpdateAll()
    for _,holder in pairs(self.holders) do self:Update(holder) end
end
function Glow:UpdateUnit(unit)
    for _,holder in pairs(self.holders) do
        local current=holder.unitFn and holder.unitFn()
        if current==unit then self:Update(holder) end
    end
end
function Glow:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if s.enabled and not InCombatLockdown() then self:Collect() end
    self:UpdateAll()
    self:SetEvents(s.enabled)
end
function Glow:SetEvents(on)
    if self.listening==on then return end
    self.listening=on
    for _,event in ipairs({"UNIT_AURA","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","GROUP_ROSTER_UPDATE","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","PLAYER_ENTERING_WORLD"}) do
        if on then self.events:RegisterEvent(event) else self.events:UnregisterEvent(event) end
    end
end
FT:RegisterModule("DispelGlow",Glow)
Glow.events=CreateFrame("Frame")
Glow.events:RegisterEvent("PLAYER_LOGIN")
Glow.events:SetScript("OnEvent",function(_,event,unit)
    if not FT.dbReady then return end
    if event=="UNIT_AURA" then Glow:UpdateUnit(unit)
    elseif event=="PLAYER_TARGET_CHANGED" then Glow:UpdateUnit("target")
    elseif event=="PLAYER_FOCUS_CHANGED" then Glow:UpdateUnit("focus")
    elseif event=="PLAYER_LOGIN" then Glow:Apply()
    elseif event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" then
        -- Raid-style frames can appear with the group; collect them when allowed.
        C_Timer.After(.2,function() Glow:Apply() end)
    else Glow:UpdateAll() end
end)
