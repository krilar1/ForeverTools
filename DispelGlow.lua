local _,FT=...
-- Dispel glow: a soft glow around a unit frame while that unit has a debuff
-- the player can remove, in a color per debuff type (yours to choose). Which
-- debuffs qualify comes from the game's own "RAID" aura filter (harmful auras
-- the player can dispel), so unlearned dispels never light up.
-- The glow is the frame's own glow art, the one the game lights up for aggro
-- and combat: we draw a copy of it (referenced, not bundled) in the debuff's
-- color and never touch Blizzard's. Frames without such art get plain rings.
local Glow={holders={}}
local frameKeys={"player","target","focus","party","raid"}
Glow.frameKeys=frameKeys
Glow.labels={player="Player",target="Target",focus="Focus",party="Party",raid="Raid"}
local strengths={soft=.6,medium=.85,strong=1}
Glow.strengths=strengths
-- Rings from the bar edge outwards: {thickness, alpha}.
local rings={{1,1},{2,.55},{2,.28},{2,.12}}
local fallback={.8,.55,1}
-- Brighter than the game's debuff border colors, so the glow reads at a glance.
local typeNames={"Magic","Curse","Disease","Poison"}
local defaults={Magic={.25,.65,1},Curse={.75,.25,1},Disease={.85,.6,.15},Poison={.15,1,.25}}
Glow.typeNames,Glow.defaultColors=typeNames,defaults
-- Game dispel-type ids used by colour curves (Magic, Curse, Disease, Poison).
local typeIDs={Magic=1,Curse=2,Disease=3,Poison=4}
function Glow:Settings()
    if type(FT.db.dispelGlow)~="table" then FT.db.dispelGlow={} end
    local s=FT.db.dispelGlow
    if type(s.enabled)~="boolean" then s.enabled=false end
    for _,key in ipairs(frameKeys) do if type(s[key])~="boolean" then s[key]=key~="raid" end end
    if not strengths[s.strength] then s.strength="medium" end
    if type(s.pulse)~="boolean" then s.pulse=false end
    -- One color per debuff type.
    if type(s.colors)~="table" then s.colors={} end
    for _,name in ipairs(typeNames) do
        local c=s.colors[name]
        if type(c)~="table" then c={unpack(defaults[name])}; s.colors[name]=c end
        for i=1,3 do local v=tonumber(c[i]); c[i]=(v and v==v) and math.max(0,math.min(1,v)) or defaults[name][i] end
    end
    return s
end
local function typeColor(name)
    local c=type(name)=="string" and Glow:Settings().colors[name]
    if c then return c[1],c[2],c[3] end
end
function Glow:SetColor(name,r,g,b)
    local c=self:Settings().colors[name]; if not c then return end
    c[1],c[2],c[3]=r,g,b
    self.curve=nil   -- the in-combat color lookup is built from these
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
local function atlasKnown(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)~=nil end
-- The frame's own glow region (hidden unless the game lights it).
local function flashOf(frame,kind)
    if kind=="player" then return frame.PlayerFrameContainer and frame.PlayerFrameContainer.FrameFlash end
    if kind=="target" or kind=="focus" then return frame.TargetFrameContainer and frame.TargetFrameContainer.Flash end
    if kind=="party" then return frame.Flash end
end
local RAID_GLOW="RaidFrame-AgroFrame"
local function bars(frame,kind)
    if kind=="raid" then return frame,frame end
    if kind=="party" then return frame.HealthBarContainer or frame.HealthBar or frame.healthbar,frame.ManaBar or frame.manabar end
    local content=frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
    if not main then return frame.healthbar or frame.HealthBar,frame.manabar end
    local mana=main.ManaBar or (main.ManaBarArea and main.ManaBarArea.ManaBar)
    return main.HealthBarsContainer or main.HealthBar,mana
end
-- kind: which switch it follows (player, target, focus, party, raid).
-- style: how the frame is built ("raid" for the raid-style frames, which a
-- party can use too); defaults to kind.
function Glow:Holder(frame,kind,unitFn,style)
    local holder=self.holders[frame]
    if holder then return holder end
    if InCombatLockdown() then return end
    style=style or kind
    local top,bottom=bars(frame,style)
    top=top or frame
    bottom=bottom or top
    holder=CreateFrame("Frame",nil,frame)
    holder:SetFrameLevel((frame:GetFrameLevel() or 1)+8)
    local out=style=="raid" and 0 or 3
    holder:SetPoint("TOPLEFT",top,"TOPLEFT",-out,out)
    holder:SetPoint("BOTTOMRIGHT",bottom,"BOTTOMRIGHT",out,-out)
    holder.kind,holder.unitFn,holder.textures,holder.frame=kind,unitFn,{},frame
    -- A copy of the frame's own glow art, where it has one.
    local source=flashOf(frame,style)
    local art
    if source and source.GetAtlas and source.GetParent then
        local atlas=source:GetAtlas()
        local owner=source:GetParent()
        if not secret(atlas) and type(atlas)=="string" and owner and owner.CreateTexture then
            -- Same place and layer as the game's glow, one step above it.
            local layer,sub=source:GetDrawLayer()
            art=owner:CreateTexture(nil,type(layer)=="string" and layer or "OVERLAY",nil,math.min(7,(tonumber(sub) or 0)+1))
            art:SetAtlas(atlas); art:SetAllPoints(source)
            holder.source,holder.atlas=source,atlas
        end
    elseif style=="raid" and atlasKnown(RAID_GLOW) then
        art=holder:CreateTexture(nil,"OVERLAY",nil,7)
        art:SetAtlas(RAID_GLOW); art:SetAllPoints(holder)
    end
    if art then
        art.baseAlpha=1; art:Hide()
        holder.art=art; holder.textures[1]=art
        local pulse=art:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
        local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(.3); fade:SetDuration(.8); fade:SetSmoothing("IN_OUT")
        holder.pulse=pulse
        holder:Hide()
        self.holders[frame]=holder
        return holder
    end
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
-- The game swaps the frame's glow art (elite targets, a third power bar, vehicles): follow it.
function Glow:SyncArt(holder)
    local source=holder.source
    if not source then return end
    local atlas=source:GetAtlas()
    if secret(atlas) or type(atlas)~="string" or atlas==holder.atlas then return end
    holder.atlas=atlas; holder.art:SetAtlas(atlas)
end
function Glow:PaintColor(holder,r,g,b)
    local scale=strengths[self:Settings().strength] or .85
    for _,t in ipairs(holder.textures) do t:SetVertexColor(r,g,b); t:SetAlpha(t.baseAlpha*scale) end
end
-- Show one type's glow on every frame that is on screen for a few seconds,
-- so a color can be judged without waiting for a debuff.
function Glow:Preview(name,seconds)
    if not self:Settings().enabled then return end
    if not InCombatLockdown() then self:Collect() end
    self.preview=name; self.previewToken=(self.previewToken or 0)+1
    local token=self.previewToken
    self:UpdateAll()
    C_Timer.After(seconds or 4,function() if self.previewToken==token then self.preview=nil; self:UpdateAll() end end)
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
    return ok and not secret(value) and value and true or false
end
function Glow:Update(holder)
    local s=self:Settings()
    local unit=holder.unitFn and holder.unitFn()
    local show=false
    local exists=type(unit)=="string" and not secret(unit) and UnitExists(unit)
    if s.enabled and s[holder.kind] and not secret(exists) and exists and canAssist(unit)
        and C_UnitAuras and C_UnitAuras.GetUnitAuras then
        local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,"HARMFUL|RAID",1)
        if ok and type(auras)=="table" and #auras>0 then
            show=true
            if not pcall(self.Paint,self,holder,unit,auras[1]) then self:PaintFallback(holder) end
        end
    end
    -- A preview shows the chosen type's color on every frame that is on screen.
    local preview=self.preview
    if preview and s.enabled and s[holder.kind] and holder.frame and holder.frame.IsShown and holder.frame:IsShown() then
        local r,g,b=typeColor(preview)
        if r then show=true; self:PaintColor(holder,r,g,b) end
    end
    if show and holder.art then self:SyncArt(holder) end
    holder:SetShown(show)
    if holder.art then holder.art:SetShown(show) end
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
    -- A party shown with raid-style frames still follows the Party switch.
    for i=1,5 do local frame=_G["CompactPartyFrameMember"..i]; if frame then self:Holder(frame,"party",unitOf(frame),"raid") end end
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
    if event=="UNIT_AURA" then
        -- Auras can change many times a second in a group: look once per unit per tenth of a second.
        if type(unit)=="string" and not secret(unit) then FT:Coalesce("glow:"..unit,function() Glow:UpdateUnit(unit) end,.1) end
    elseif event=="PLAYER_TARGET_CHANGED" then Glow:UpdateUnit("target")
    elseif event=="PLAYER_FOCUS_CHANGED" then Glow:UpdateUnit("focus")
    elseif event=="PLAYER_LOGIN" then Glow:Apply()
    elseif event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_REGEN_ENABLED" or event=="PLAYER_ENTERING_WORLD" then
        -- Raid-style frames can appear with the group; collect them when allowed.
        C_Timer.After(.2,function() Glow:Apply() end)
    else Glow:UpdateAll() end
end)
