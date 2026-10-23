local _,FT=...
-- Threat (off by default): a small threat meter in the style of the game's
-- own damage meter, placed next to it, and your threat % above the target's
-- portrait. Uses only the game's threat functions. Where the game keeps threat
-- numbers private (some group content), values still show but cannot be
-- sorted or colored, because addons may display them but not compare them.
-- Event driven, updates at most five times a second, and does nothing while
-- both parts are off.
local Threat={rows={}}
local ICON="Ability_Warrior_DefensiveStance"
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function yes(v) return not secret(v) and v and true or false end
local function number(v,default,low,high)
    if type(v)~="number" or v~=v then return default end
    return math.max(low,math.min(high,v))
end
-- Asked once per art name (the answer never changes in a session).
local atlasKnown={}
local function hasAtlas(name)
    local known=atlasKnown[name]
    if known==nil then known=(C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)~=nil) or false; atlasKnown[name]=known end
    return known
end
local shows={{"combat","In combat"},{"group","In a group"},{"always","Always"}}
local MIN_W,MIN_H,MAX_W,MAX_H=180,80,600,500

-- Checked once per settings table (a profile switch, import or reset puts a
-- new table in place); the meter reads its settings many times a second.
local checkedSettings=setmetatable({},{__mode="k"})
function Threat:Settings()
    local s=FT.db.threat
    if checkedSettings[s] then return s end
    if type(s)~="table" then s={}; FT.db.threat=s end
    if type(s.enabled)~="boolean" then s.enabled=false end
    local known=false; for _,e in ipairs(shows) do if e[1]==s.show then known=true end end
    if not known then s.show="combat" end
    s.rows=number(s.rows,5,3,20) -- older setting, kept for profiles; the size now comes from resizing
    if s.width~=nil then s.width=number(s.width,260,MIN_W,MAX_W) end
    if s.height~=nil then s.height=number(s.height,150,MIN_H,MAX_H) end
    if type(s.collapsed)~="boolean" then s.collapsed=false end
    if type(s.locked)~="boolean" then s.locked=false end
    if s.grip~="always" and s.grip~="hover" then s.grip="always" end
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    -- Threat % above the target portrait.
    if type(s.text)~="boolean" then s.text=false end
    if type(s.font)~="string" then s.font="friz" end
    s.size=number(s.size,14,8,32)
    if s.outline~="" and s.outline~="OUTLINE" and s.outline~="THICKOUTLINE" then s.outline="OUTLINE" end
    if type(s.background)~="boolean" then s.background=false end
    local c=s.backgroundColor
    if type(c)~="table" or type(c[1])~="number" or type(c[2])~="number" or type(c[3])~="number" then s.backgroundColor={0,0,0} end
    s.backgroundAlpha=number(s.backgroundAlpha,.6,0,1)
    s.textX=number(s.textX,0,-400,400); s.textY=number(s.textY,2,-400,400)
    checkedSettings[s]=true
    return s
end

-- The mob whose threat we show: your target, if you can attack it.
local function mob()
    if not yes(UnitExists("target")) then return nil end
    if not yes(UnitCanAttack("player","target")) then return nil end
    local dead=UnitIsDead("target"); if secret(dead) or dead then return nil end
    return "target"
end
function Threat:Units()
    local list={"player"}
    if yes(UnitExists("pet")) then list[#list+1]="pet" end
    if IsInRaid() then
        for i=1,(GetNumGroupMembers() or 0) do
            local unit="raid"..i
            local me=UnitIsUnit(unit,"player")
            if yes(UnitExists(unit)) and not (not secret(me) and me) then list[#list+1]=unit end
        end
    elseif IsInGroup() then
        for i=1,4 do if yes(UnitExists("party"..i)) then list[#list+1]="party"..i end end
    end
    return list
end
-- One entry per unit on the mob's threat list. value is the "scaled" threat:
-- 100 means that unit has (or is about to take) aggro.
function Threat:Entries(target)
    local list,private={},false
    if not target or not UnitDetailedThreatSituation then return list,private end
    for _,unit in ipairs(self:Units()) do
        local tanking,_,scaled=UnitDetailedThreatSituation(unit,target)
        if secret(scaled) then
            private=true; list[#list+1]={unit=unit,value=scaled}
        elseif type(scaled)=="number" then
            local tank=yes(tanking)
            list[#list+1]={unit=unit,value=tank and 100 or scaled,tank=tank}
        end
    end
    if not private then
        table.sort(list,function(a,b)
            if a.value~=b.value then return a.value>b.value end
            return a.unit=="player"
        end)
    end
    return list,private
end

-- Look: the damage meter's own header, background and bar art, and its bar
-- height, spacing and background transparency when it is there.
function Threat:DamageMeter()
    local meter=_G.DamageMeter
    if type(meter)~="table" or not meter.GetWidth then return nil end
    return meter
end
-- One table, filled again on each look (read several times a second).
local style={}
local function readStyle(meter,method,key,low,high)
    if type(meter[method])~="function" then return end
    local ok,v=pcall(meter[method],meter)
    if ok and type(v)=="number" and not secret(v) then style[key]=math.max(low,math.min(high,v)) end
end
function Threat:Style()
    style.barHeight,style.spacing,style.background=22,3,.8
    local meter=self:DamageMeter()
    if meter then
        readStyle(meter,"GetBarHeight","barHeight",14,40); readStyle(meter,"GetBarSpacing","spacing",0,10); readStyle(meter,"GetBackgroundAlpha","background",0,1)
    end
    -- The damage meter's own bars, read from one on screen (at most every
    -- two seconds): row height, bar height and the fill picture.
    local now=GetTime()
    if not self.mirrorAt or now-self.mirrorAt>2 then
        self.mirrorAt=now; self.mirror=self:MirrorBar() or self.mirror
        self.mirrorAlpha=self:MirrorBackground() or self.mirrorAlpha
    end
    -- The damage meter's background as see-through as it really is (its
    -- transparency setting fades the frame that holds the picture).
    if self.mirrorAlpha then style.background=self.mirrorAlpha end
    local m=self.mirror
    style.fillHeight,style.fill=nil,nil
    if m then style.barHeight=m.row; style.fillHeight=m.bar; style.fill=m.fill end
    return style
end
function Threat:MirrorBackground()
    local w=self.MeterWindow and self:MeterWindow(); if not w then return end
    local found
    local function visit(f,depth)
        if found or depth<0 then return end
        local ok,list=pcall(function() return {f:GetRegions()} end)
        if ok then for _,region in ipairs(list) do
            if not found and region.GetObjectType and region:GetObjectType()=="Texture" then
                local a=region.GetAtlas and region:GetAtlas()
                if not secret(a) and a=="damagemeters-background" then found=region end
            end
        end end
        local okC,kids=pcall(function() return {f:GetChildren()} end)
        if okC then for _,child in ipairs(kids) do visit(child,depth-1) end end
    end
    visit(w,2)
    if not found then return end
    local alpha=found:GetAlpha(); local p=found:GetParent()
    while p and p~=w and p~=UIParent do alpha=alpha*p:GetAlpha(); p=p:GetParent() end
    if secret(alpha) or type(alpha)~="number" then return end
    return math.max(0,math.min(1,alpha))
end
function Threat:MirrorBar()
    local w=self.MeterWindow and self:MeterWindow(); if not w then return end
    local found
    local function visit(f,depth)
        if found or depth<0 then return end
        local ok,kids=pcall(function() return {f:GetChildren()} end)
        if not ok then return end
        for _,child in ipairs(kids) do
            if found then return end
            if child:IsShown() and child.GetObjectType and child:GetObjectType()=="StatusBar" then
                local h=child:GetHeight(); local parent=child:GetParent(); local ph=parent and parent:GetHeight()
                local t=child.GetStatusBarTexture and child:GetStatusBarTexture()
                if not secret(h) and not secret(ph) and type(h)=="number" and type(ph)=="number" and h>=8 and ph>=h and ph<=48 and t then
                    local atlas=t.GetAtlas and t:GetAtlas()
                    local file=t.GetTexture and t:GetTexture()
                    if secret(atlas) then atlas=nil end; if secret(file) then file=nil end
                    if (file==nil or file=="") and t.GetTextureFilePath then file=t:GetTextureFilePath(); if secret(file) then file=nil end end
                    if atlas=="" then atlas=nil end
                    found={row=math.floor(ph+.5),bar=math.floor(h+.5),fill=atlas and {atlas=atlas} or (file and {file=file}) or nil}
                end
            end
            if not found and child:IsShown() then visit(child,depth-1) end
        end
    end
    visit(w,6)
    return found
end
local function button(parent,size,normal,pushed,highlight)
    local b=CreateFrame("Button",nil,parent); b:SetSize(size[1],size[2])
    if hasAtlas(normal) then
        b:SetNormalAtlas(normal); if pushed and hasAtlas(pushed) then b:SetPushedAtlas(pushed) end
        if highlight and hasAtlas(highlight) then b:SetHighlightAtlas(highlight,"ADD") end
        b.art=true
    end
    return b
end
function Threat:Meter()
    if self.meter then return self.meter end
    local f=CreateFrame("Frame","ForeverToolsThreatMeter",UIParent)
    -- Low, like the damage meter: game windows (friends, map...) open above it.
    f:SetSize(260,120); f:SetFrameStrata("LOW"); f:SetClampedToScreen(true); f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.header=f:CreateTexture(nil,"BACKGROUND",nil,1); f.header:SetPoint("TOPLEFT"); f.header:SetPoint("TOPRIGHT"); f.header:SetHeight(32)
    if hasAtlas("ui-damagemeters-header-bar") then f.header:SetAtlas("ui-damagemeters-header-bar")
    else f.header:SetColorTexture(.05,.04,.08,.9) end
    f.body=f:CreateTexture(nil,"BACKGROUND")
    -- The background picture fades out at its top: like the damage meter,
    -- it starts at the very top, so the faded part sits under the header.
    f.body:SetPoint("TOPLEFT",0,0); f.body:SetPoint("BOTTOMRIGHT")
    if hasAtlas("damagemeters-background") then f.body:SetAtlas("damagemeters-background") else f.body:SetColorTexture(0,0,0,.6) end
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalMed1"); f.title:SetPoint("TOPLEFT",8,-9); f.title:SetText("Threat")
    f.target=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.target:SetPoint("LEFT",f.title,"RIGHT",8,0)
    f.target:SetJustifyH("LEFT"); if f.target.SetWordWrap then f.target:SetWordWrap(false) end
    -- Hide (collapse) and settings, where the damage meter has them.
    f.hide=button(f,{18,19},"ui-questtrackerbutton-collapse-all","ui-questtrackerbutton-collapse-all-pressed","ui-questtrackerbutton-red-highlight")
    f.hide:SetPoint("TOPRIGHT",-3,-5)
    if not f.hide.art then f.hide.text=FT:Label(f.hide,"–",14); f.hide.text:SetPoint("CENTER") end
    f.hide:SetScript("OnClick",function() local s=self:Settings(); s.collapsed=not s.collapsed; self:Update() end)
    f.gear=button(f,{27,27},"common-dropdown-a-button-settings-shadowless","common-dropdown-a-button-settings-pressed-shadowless","common-dropdown-a-button-settings-hover-shadowless")
    f.gear:SetPoint("RIGHT",f.hide,"LEFT",-2,-2)
    if not f.gear.art then f.gear:SetNormalTexture("Interface\\Icons\\Trade_Engineering") end
    f.gear:SetScript("OnClick",function() if not InCombatLockdown() then FT:OpenModule("Threat") end end)
    f.target:SetPoint("RIGHT",f.gear,"LEFT",-4,0)
    for _,b in ipairs({f.hide,f.gear}) do
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    f.hide:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText(self:Settings().collapsed and "Show bars" or "Hide bars",1,1,1)
        GameTooltip:AddLine("Only the title bar stays.",.8,.8,.8,true); GameTooltip:Show()
    end)
    f.gear:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText("Threat meter settings",1,1,1)
        GameTooltip:AddLine("Drag the title bar to move the meter.",.8,.8,.8,true); GameTooltip:Show()
    end)
    f.empty=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.empty:SetPoint("TOP",0,-44)
    -- Drag the title bar to move it (out of combat).
    f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(owner) if not InCombatLockdown() and (self.moverUnlock or not self:Settings().locked) then owner:StartMoving(); self.dragging=true end end)
    f:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        self.dragging=false; self:ShowSnapGlow(false)
        local s=self:Settings()
        s.x,s.y=owner:GetLeft(),owner:GetTop()
        self:Snap(owner)
        self:Place()
    end)
    -- Resize from the bottom-right corner, with the damage meter's own handle.
    -- It shows while the mouse is over the meter, like on the damage meter.
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W,MIN_H,MAX_W,MAX_H) elseif f.SetMinResize then f:SetMinResize(MIN_W,MIN_H); f:SetMaxResize(MAX_W,MAX_H) end
    f.grip=CreateFrame("Button",nil,f); f.grip:SetFrameLevel(f:GetFrameLevel()+5)
    if hasAtlas("damagemeters-scalehandle") then
        f.grip:SetSize(60,60); f.grip:SetPoint("BOTTOMRIGHT",9,-8)
        f.grip:SetNormalAtlas("damagemeters-scalehandle")
        if hasAtlas("damagemeters-scalehandle-hover") then f.grip:SetHighlightAtlas("damagemeters-scalehandle-hover") end
        if hasAtlas("damagemeters-scalehandle-pressed") then f.grip:SetPushedAtlas("damagemeters-scalehandle-pressed") end
        f.grip:SetHitRectInsets(30,0,30,0)
    else
        f.grip:SetSize(16,16); f.grip:SetPoint("BOTTOMRIGHT",-2,2)
        f.grip:SetNormalTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up")
        f.grip:SetHighlightTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight")
        f.grip:SetPushedTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down")
    end
    -- Shown always, or while the mouse is over the meter (checked ten times a
    -- second, only in that mode and only while the meter is on screen).
    local function hover() self:UpdateGrip() end
    f.gripElapsed=0
    f.snapElapsed=0
    f:SetScript("OnUpdate",function(owner,dt)
        if self.dragging or self.sizing then
            owner.snapElapsed=owner.snapElapsed+dt
            if owner.snapElapsed>=.05 then
                owner.snapElapsed=0
                if self.dragging then local x,_,_,rect=self:SnapSpot(owner); self:ShowSnapGlow(x~=nil,rect)
                else
                    self.sizeShift=IsShiftKeyDown and IsShiftKeyDown() or false
                    local h,rect=self:HeightSnap(owner); self:ShowSnapGlow(h~=nil,rect)
                end
            end
        end
        if not owner.gripWatch then return end
        owner.gripElapsed=owner.gripElapsed+dt
        if owner.gripElapsed<.1 then return end
        owner.gripElapsed=0; self:UpdateGrip()
    end)
    f.grip:SetScript("OnMouseDown",function(_,button)
        local s=self:Settings()
        if button~="LeftButton" or InCombatLockdown() or s.collapsed or (s.locked and not self.moverUnlock) then return end
        self.sizing=true; self.sizeShift=false; f:StartSizing("BOTTOMRIGHT")
    end)
    f.grip:SetScript("OnMouseUp",function()
        if not self.sizing then return end
        local snapped=not self.sizeShift and self:HeightSnap(f) or nil
        self.sizeShift=false
        self.sizing=false; f:StopMovingOrSizing(); self:ShowSnapGlow(false)
        local s=self:Settings()
        s.width=number(math.floor(f:GetWidth()+.5),260,MIN_W,MAX_W); s.height=number(snapped or math.floor(f:GetHeight()+.5),150,MIN_H,MAX_H)
        -- Sizing can move the anchor; keep a moved meter where it now is.
        if s.x and s.y then s.x,s.y=f:GetLeft(),f:GetTop() end
        self:Place(); self:Update(); hover()
    end)
    f.grip:SetScript("OnEnter",function(b) hover(); GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText("Resize",1,1,1); GameTooltip:AddLine("Drag to change the width and height. Beside the damage meter it snaps to its height; hold Shift for any height.",.8,.8,.8,true); GameTooltip:Show() end)
    f.grip:SetScript("OnLeave",function() hover(); GameTooltip:Hide() end)
    f:SetScript("OnSizeChanged",function() if self.sizing then self:UpdateMeter() end end)
    f:Hide()
    self.meter=f
    local skins=FT.modules.IconStyles; if skins and skins.SkinThreat then skins:SkinThreat(f) end
    return f
end
-- Dropped near the game's damage meter: it snaps against it (side by side
-- with the tops lined up, or stacked with the left edges lined up). Side by
-- side with almost the same height, it takes the damage meter's height.
-- The damage meter's art has a soft see-through edge: a small overlap makes
-- the two look flush.
local SNAP,GAP=16,-3
function Threat:MeterWindow()
    for i=1,3 do local w=_G["DamageMeterSessionWindow"..i]; if w and w.IsShown and w:IsShown() then return w end end
    local m=self:DamageMeter(); if m and m:IsShown() then return m end
end
-- The damage meter's visible art (header and background), in screen units:
-- its window is a little bigger than what you see, so snapping to the window
-- left a gap.
function Threat:MeterRect()
    local w=self:MeterWindow(); if not w then return end
    local k=w:GetEffectiveScale()/UIParent:GetEffectiveScale()
    local L,R,T,B,HT
    local function add(region)
        if not region.IsShown or not region:IsShown() then return end
        local atlas=region.GetAtlas and region:GetAtlas()
        if type(atlas)~="string" or secret(atlas) or not atlas:lower():find("damagemeter",1,true) then return end
        local atl=atlas:lower(); if atl:find("scalehandle",1,true) or atl:find("bar%-fill") then return end
        local rl,rr,rt,rb=region:GetLeft(),region:GetRight(),region:GetTop(),region:GetBottom()
        if not (rl and rr and rt and rb) or secret(rl) or secret(rr) or secret(rt) or secret(rb) then return end
        local rk=region.GetEffectiveScale and region:GetEffectiveScale()/UIParent:GetEffectiveScale() or k
        rl,rr,rt,rb=rl*rk,rr*rk,rt*rk,rb*rk
        L=L and math.min(L,rl) or rl; R=R and math.max(R,rr) or rr; T=T and math.max(T,rt) or rt; B=B and math.min(B,rb) or rb
        -- The header bar is the same art as ours: line our top up with it.
        if atl:find("header%-bar") then HT=HT and math.max(HT,rt) or rt end
    end
    local function visit(f,depth)
        if depth<0 then return end
        local ok,list=pcall(function() return {f:GetRegions()} end)
        if ok then for _,region in ipairs(list) do if region.GetObjectType and region:GetObjectType()=="Texture" then add(region) end end end
        local okC,kids=pcall(function() return {f:GetChildren()} end)
        if okC then for _,child in ipairs(kids) do if child.IsShown and child:IsShown() then visit(child,depth-1) end end end
    end
    visit(w,4)
    local l,r,t,b=w:GetLeft(),w:GetRight(),w:GetTop(),w:GetBottom()
    if not (l and r and t and b) or secret(l) or secret(r) or secret(t) or secret(b) then return end
    l,r,t,b=l*k,r*k,t*k,b*k
    -- Only trust the art when it sits on the window (its header may stick out a little).
    self.rectInfo={window={l,r,t,b},art=L and {L,R,HT or T,B} or nil}
    if L and R and T and B and L>=l-24 and R<=r+24 and T<=t+24 and B>=b-24 and R-L>40 and T-B>30 then return L,R,HT or T,B end
    return l,r,t,b
end
-- Where the meter would land if dropped now (nil: not close enough).
function Threat:SnapSpot(f)
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    local l,r,t,b=self:MeterRect(); if not l then return end
    local fl,ft,fw,fh=f:GetLeft(),f:GetTop(),f:GetWidth(),f:GetHeight()
    if not (fl and ft and fw and fh) then return end
    local fr,fb=fl+fw,ft-fh
    local function near(a,c) return math.abs(a-c)<=SNAP end
    local overlapY=fb<t+SNAP and ft>b-SNAP
    local overlapX=fr>l-SNAP and fl<r+SNAP
    local x,y=fl,ft
    if overlapY and near(fl,r) then x=r+GAP
    elseif overlapY and near(fr,l) then x=l-fw-GAP
    elseif overlapX and near(fb,t) then y=t+fh+GAP
    elseif overlapX and near(ft,b) then y=b-GAP
    else return end
    local height
    if x~=fl then y=t; height=math.floor((t-b)+.5)   -- side by side: same top, same height
    elseif math.abs(fl-l)<=40 then x=l end
    return x,y,height,{l,r,t,b}
end
function Threat:Snap(f)
    local x,y,height=self:SnapSpot(f); if not x then return end
    local s=self:Settings()
    if height and not s.collapsed then s.height=height end
    s.x,s.y=x,y
end
-- A gold flash around both meters while a drop (or a resize) would snap.
local function glowBox(parent)
    local g=CreateFrame("Frame",nil,parent or UIParent); g:SetFrameStrata("HIGH")
    g.edges={}
    for i=1,4 do local t=g:CreateTexture(nil,"OVERLAY"); t:SetColorTexture(1,.82,.2,1); t:SetBlendMode("ADD"); g.edges[i]=t end
    local e=g.edges
    e[1]:SetPoint("TOPLEFT",-2,2); e[1]:SetPoint("TOPRIGHT",2,2); e[1]:SetHeight(2)
    e[2]:SetPoint("BOTTOMLEFT",-2,-2); e[2]:SetPoint("BOTTOMRIGHT",2,-2); e[2]:SetHeight(2)
    e[3]:SetPoint("TOPLEFT",-2,2); e[3]:SetPoint("BOTTOMLEFT",-2,-2); e[3]:SetWidth(2)
    e[4]:SetPoint("TOPRIGHT",2,2); e[4]:SetPoint("BOTTOMRIGHT",2,-2); e[4]:SetWidth(2)
    g.elapsed=0
    g:SetScript("OnUpdate",function(owner,dt) owner.elapsed=owner.elapsed+dt; owner:SetAlpha(.55+.45*math.abs(math.sin(owner.elapsed*6))) end)
    g:Hide()
    return g
end
function Threat:ShowSnapGlow(on,rect)
    local f=self.meter; if not f then return end
    self.glowOwn=self.glowOwn or glowBox(f); self.glowOther=self.glowOther or glowBox(UIParent)
    if not on or not rect then self.glowOwn:Hide(); self.glowOther:Hide(); return end
    self.glowOwn:SetAllPoints(f); self.glowOwn:Show()
    local o=self.glowOther; o:ClearAllPoints()
    o:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",rect[1],rect[3]); o:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMLEFT",rect[2],rect[4]); o:Show()
end
-- Resizing beside the damage meter: close to its height, it snaps to it.
function Threat:HeightSnap(f)
    -- Hold Shift for any height.
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    local l,r,t,b=self:MeterRect(); if not l then return end
    local fl,fr,ft,fb=f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()
    if not (fl and fr and ft and fb) then return end
    local beside=(math.abs(fl-r)<=6 or math.abs(fr-l)<=6) and math.abs(ft-t)<=3
    if not beside then return end
    local h=t-b
    if math.abs((ft-fb)-h)<=SNAP then return math.floor(h+.5),{l,r,t,b} end
end
-- Beside the damage meter: above it, or below when there is no room above.
-- Once you drag the meter, your spot is used instead.
function Threat:Place()
    local f=self:Meter(); local s=self:Settings()
    f:ClearAllPoints()
    f:SetHeight(self:MeterHeight())
    if s.x and s.y then f:SetWidth(s.width or 260); f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",s.x,s.y); return end
    local meter=self:DamageMeter()
    local top=meter and meter:GetTop()
    if not top then f:SetWidth(s.width or 260); f:SetPoint("RIGHT",UIParent,"RIGHT",-24,80); return end
    local scale=meter:GetEffectiveScale()/UIParent:GetEffectiveScale()
    f:SetWidth(s.width or math.max(MIN_W,math.min(420,meter:GetWidth()*scale)))
    if top*scale+f:GetHeight()+8<=UIParent:GetHeight() then f:SetPoint("BOTTOMLEFT",meter,"TOPLEFT",0,6)
    else f:SetPoint("TOPLEFT",meter,"BOTTOMLEFT",0,-6) end
end
function Threat:UpdateGrip()
    local f=self.meter; if not f then return end
    local s=self:Settings()
    local usable=not s.collapsed and (self.moverUnlock or not s.locked)
    local visible=usable and (self.sizing or self.previewing or s.grip=="always" or f:IsMouseOver())
    f.grip:SetShown(usable); f.grip:SetAlpha(visible and 1 or 0)
    f.gripWatch=usable and s.grip=="hover" and not self.previewing
end
-- Your chosen height, or room for five bars until you resize it.
function Threat:MeterHeight()
    local s=self:Settings()
    if s.collapsed then return 32 end
    if s.height then return s.height end
    local style=self:Style()
    return 38+5*(style.barHeight+style.spacing)
end
function Threat:Row(index)
    local row=self.rows[index]
    if row then return row end
    local f=self.meter
    row=CreateFrame("Frame",nil,f)
    -- Like the damage meter: a square class icon the row's height, then a
    -- thinner bar (three quarters high, centered) starting just under the
    -- icon's right edge, with the meter's shadow behind and edge on top.
    -- Measured on the game's damage meter: the icon is 8 taller than the
    -- row (centered), the bar 2 shorter, and the bar's shadow and edge
    -- reach 2 above and below the bar.
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("LEFT")
    row.bar=CreateFrame("StatusBar",nil,row); row.bar:SetPoint("LEFT",row.icon,"RIGHT",-2,0); row.bar:SetPoint("RIGHT")
    row.bar:SetStatusBarTexture(hasAtlas("UI-HUD-CoolDownManager-Bar") and "UI-HUD-CoolDownManager-Bar" or "Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0,100)
    row.bg=row.bar:CreateTexture(nil,"BACKGROUND"); row.bg:SetPoint("TOPLEFT",0,2); row.bg:SetPoint("BOTTOMRIGHT",0,-2)
    if hasAtlas("ui-damagemeters-bar-shadowbg") then row.bg:SetAtlas("ui-damagemeters-bar-shadowbg") else row.bg:SetColorTexture(0,0,0,.4) end
    if hasAtlas("ui-damagemeters-bar-shadowedge") then row.edge=row.bar:CreateTexture(nil,"OVERLAY",nil,-1); row.edge:SetPoint("TOPLEFT",0,2); row.edge:SetPoint("BOTTOMRIGHT",0,-2); row.edge:SetAtlas("ui-damagemeters-bar-shadowedge") end
    row.value=row.bar:CreateFontString(nil,"OVERLAY","NumberFontNormal"); row.value:SetPoint("RIGHT",-4,0); row.value:SetJustifyH("RIGHT")
    row.name=row.bar:CreateFontString(nil,"OVERLAY","NumberFontNormal"); row.name:SetPoint("LEFT",4,0); row.name:SetPoint("RIGHT",row.value,"LEFT",-8,0)
    row.name:SetJustifyH("LEFT"); if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    self.rows[index]=row
    local fonts=FT.modules.FontManager
    if fonts and fonts:Settings("threatMeter").enabled then FT:Coalesce("threatFonts",function() fonts:ApplyArea("threatMeter") end) end
    return row
end
local sample={{"Tank","WARRIOR",100},{"You","",82},{"Healer","PRIEST",47},{"Damage","MAGE",31},{"Damage","ROGUE",12}}
local function classColor(unit)
    local _,class=UnitClass(unit)
    if not secret(class) and type(class)=="string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then return RAID_CLASS_COLORS[class] end
end
-- PvP has no threat: the meter stays away in battlegrounds and arenas, and
-- while your target is a player (a duel or world PvP).
function Threat:PvP()
    if IsInInstance then
        local ok,inside,kind=pcall(IsInInstance)
        if ok and not secret(inside) and inside and not secret(kind) and (kind=="pvp" or kind=="arena") then return true end
    end
    if UnitIsPlayer then
        local ok,p=pcall(UnitIsPlayer,"target")
        if ok and not secret(p) and p then
            local okA,attack=pcall(UnitCanAttack,"player","target")
            if okA and not secret(attack) and attack then return true end
        end
    end
    return false
end
function Threat:ShouldShowMeter()
    local s=self:Settings()
    if self.previewing then return true end
    if not s.enabled then return false end
    if self:PvP() then return false end
    if s.show=="always" then return true end
    if s.show=="group" then return IsInGroup() end
    return InCombatLockdown() or yes(UnitAffectingCombat("player"))
end
-- The class icon at the start of a bar (the game's class icon art).
function Threat:ClassIcon(texture,class)
    if texture.ftClass==class then return end
    texture.ftClass=class
    if not class or class=="" then texture:SetTexture(nil); texture:SetColorTexture(0,0,0,.4); return end
    -- The damage meter's own square class icons (Interface\Icons\ClassIcon_*).
    local name=class:sub(1,1)..class:sub(2):lower()
    if class=="DEATHKNIGHT" then name="DeathKnight" elseif class=="DEMONHUNTER" then name="DemonHunter" end
    texture:SetTexCoord(0,1,0,1); texture:SetTexture("Interface\\Icons\\ClassIcon_"..name)
    if texture:GetTexture() then return end
    local atlas="classicon-"..class:lower()
    if hasAtlas(atlas) then texture:SetAtlas(atlas); return end
    local c=CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    if c then texture:SetTexCoord(c[1],c[2],c[3],c[4]) end
end
function Threat:UpdateMeter()
    if not self:ShouldShowMeter() then if self.meter then self.meter:Hide() end return end
    local f=self:Meter(); local s=self:Settings(); local style=self:Style()
    local skins=FT.modules.IconStyles
    if skins and skins.SkinThreat and f.ftSkin~=(skins.skinVersion or 0) then skins:SkinThreat(f) end
    local target=mob()
    local entries,private
    if self.previewing then
        entries={}
        local _,myClass=UnitClass("player")
        for _,e in ipairs(sample) do entries[#entries+1]={name=e[1],class=e[2]=="" and myClass or e[2],value=e[3],tank=e[3]==100} end
        f.target:SetText("(preview)")
    else
        entries,private=self:Entries(target)
        if target then f.target:SetText(UnitName(target)) else f.target:SetText("") end
    end
    -- With the Meters skin, the background is as solid as the damage meter's.
    local skinned=skins and skins.Settings and skins:Settings().meters
    f.body:SetAlpha(style.background)
    -- As many bars as fit in the meter's height.
    local height=self.sizing and f:GetHeight() or self:MeterHeight()
    local fit=math.max(1,math.floor((height-38+style.spacing)/(style.barHeight+style.spacing)))
    local shown=s.collapsed and 0 or math.min(#entries,fit)
    for i=1,shown do
        local e=entries[i]; local row=self:Row(i)
        local y=-34-(i-1)*(style.barHeight+style.spacing)
        if row.placedY~=y or row.placedH~=style.barHeight or row.placedF~=style.fillHeight then
            row.placedY,row.placedH,row.placedF=y,style.barHeight,style.fillHeight
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT",f,"TOPLEFT",5,y)
            row:SetPoint("RIGHT",f,"RIGHT",-3,0); row:SetHeight(style.barHeight)
            row.icon:SetSize(style.barHeight+8,style.barHeight+8); row.bar:SetHeight(style.fillHeight or math.max(6,style.barHeight-2))
        end
        local color,class
        if e.unit then
            local n=UnitName(e.unit)
            if not pcall(row.name.SetFormattedText,row.name,"%d. %s",i,n) then row.name:SetText(n) end
            color=classColor(e.unit)
            local _,c=UnitClass(e.unit); if not secret(c) and type(c)=="string" then class=c end
        else
            row.name:SetFormattedText("%d. %s",i,e.name); color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]; class=e.class
        end
        self:ClassIcon(row.icon,class)
        -- The damage meter's own fill picture, when it shows a bar.
        local fill=style.fill
        local key=fill and (fill.atlas or fill.file) or "default"
        if row.fillKey~=key then
            row.fillKey=key
            if fill and fill.atlas then row.bar:SetStatusBarTexture(fill.atlas)
            elseif fill and fill.file then row.bar:SetStatusBarTexture(fill.file)
            else row.bar:SetStatusBarTexture(hasAtlas("UI-HUD-CoolDownManager-Bar") and "UI-HUD-CoolDownManager-Bar" or "Interface\\TargetingFrame\\UI-StatusBar") end
        end
        if color then row.bar:SetStatusBarColor(color.r,color.g,color.b) else row.bar:SetStatusBarColor(.55,.55,.6) end
        row.bar:SetValue(e.value)
        row.value:SetFormattedText("%.0f%%",e.value)
        row:Show()
    end
    for i=shown+1,#self.rows do self.rows[i]:Hide() end
    local message=""
    if not s.collapsed and shown==0 then message=target and "No threat on this target yet" or "No enemy targeted" end
    f.empty:SetText(message); f.empty:SetShown(message~="")
    if not self.sizing then f:SetHeight(height) end
    self:UpdateGrip()
    if f.hide.art then
        local expand=s.collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all"
        if f.hide.shownAtlas~=expand and hasAtlas(expand) then
            f.hide.shownAtlas=expand
            f.hide:SetNormalAtlas(expand); if hasAtlas(expand.."-pressed") then f.hide:SetPushedAtlas(expand.."-pressed") end
        end
    end
    f.body:SetShown(not s.collapsed); if f.ftSolid then f.ftSolid:Hide() end
    f:Show()
    self.private=private
end

-- Threat % above the target portrait. It sits on the target frame, so it
-- hides with it; it is placed only out of combat.
function Threat:Portrait()
    local frame=_G.TargetFrame
    if not frame then return nil end
    local container=frame.TargetFrameContainer
    return frame,(container and container.Portrait) or frame
end
function Threat:TextFrame()
    if self.text then return self.text end
    local target=self:Portrait(); if not target then return nil end
    local f=CreateFrame("Frame","ForeverToolsThreatText",target)
    f:SetSize(60,22); f:SetFrameLevel(target:GetFrameLevel()+20); f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.background=FT:RoundedFill(f,0,0,0,.6)
    f.label=f:CreateFontString(nil,"OVERLAY"); f.label:SetPoint("CENTER",0,0)
    f.label:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(owner) if self.movingText and not InCombatLockdown() then owner:StartMoving() end end)
    f:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local _,portrait=self:Portrait()
        local x,bottom=owner:GetCenter(),owner:GetBottom()
        local px,top=portrait:GetCenter(),portrait:GetTop()
        if x and bottom and px and top then
            local s=self:Settings()
            local ratio=owner:GetEffectiveScale()/portrait:GetEffectiveScale()
            s.textX=number(math.floor(x*ratio-px+.5),0,-400,400); s.textY=number(math.floor(bottom*ratio-top+.5),2,-400,400)
        end
        self:PlaceText()
    end)
    f:Hide()
    self.text=f
    return f
end
function Threat:PlaceText()
    local f=self:TextFrame(); if not f or InCombatLockdown() then self.placeAfterCombat=true; return end
    local s=self:Settings(); local _,portrait=self:Portrait()
    f:ClearAllPoints(); f:SetPoint("BOTTOM",portrait,"TOP",s.textX,s.textY)
end
function Threat:StyleText()
    local f=self:TextFrame(); if not f then return end
    local s=self:Settings()
    local path=FT.modules.FontManager and FT.modules.FontManager:Resolve(s)
    if not path or not FT.modules.FontManager:ValidFont(path) then path="Fonts\\FRIZQT__.TTF" end
    f.label:SetFont(path,s.size,s.outline)
    local c=s.backgroundColor
    for _,t in ipairs(f.background) do t:SetVertexColor(c[1],c[2],c[3],s.backgroundAlpha); t:SetShown(s.background or self.movingText) end
    f:EnableMouse(self.movingText==true)
end
function Threat:UpdateText()
    local s=self:Settings()
    local f=self.text
    if not s.text and not self.movingText then if f then f:Hide() end return end
    f=self:TextFrame(); if not f then return end
    local value,status
    if self.movingText then value,status=72,1
    else
        local target=mob()
        if target and UnitDetailedThreatSituation then
            local tanking; tanking,status,value=UnitDetailedThreatSituation("player",target)
            if not secret(value) and yes(tanking) then value=100 end
        end
    end
    if not secret(value) and (type(value)~="number" or value<=0) then f:Hide(); return end
    f.label:SetFormattedText("%.0f%%",value)
    -- Color by threat level when the game lets us read it; white otherwise.
    if not secret(status) and type(status)=="number" and status>0 and GetThreatStatusColor then f.label:SetTextColor(GetThreatStatusColor(status))
    else f.label:SetTextColor(1,1,1) end
    local w=f.label:GetStringWidth(); if secret(w) or type(w)~="number" then w=s.size*3 end
    f:SetSize(math.max(34,w+14),s.size+10)
    f:Show()
end

function Threat:Update()
    if not FT.dbReady then return end
    self:UpdateMeter(); self:UpdateText()
end
function Threat:Changed() FT:Coalesce("threat",function() self:Update() end,.2) end
local events=CreateFrame("Frame")
local watched={"PLAYER_TARGET_CHANGED","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","GROUP_ROSTER_UPDATE","UNIT_PET","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED","UI_SCALE_CHANGED"}
function Threat:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if s.enabled or s.text or self.previewing then
        for _,event in ipairs(watched) do pcall(events.RegisterEvent,events,event) end
    else events:UnregisterAllEvents() end
    if s.enabled or self.previewing then self:Place() end
    if s.text or self.movingText then self:PlaceText(); self:StyleText() end
    self:Update(); self:Refresh()
end
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_DISABLED" then
        if Threat.movingText then Threat.movingText=false; Threat:StyleText(); Threat:Refresh() end
        Threat:Update(); return
    end
    if event=="PLAYER_REGEN_ENABLED" and Threat.placeAfterCombat then Threat.placeAfterCombat=false; Threat:PlaceText() end
    if event=="EDIT_MODE_LAYOUTS_UPDATED" or event=="UI_SCALE_CHANGED" then C_Timer.After(0,function() if Threat.meter then Threat:Place() end end) end
    Threat:Changed()
end)

-- Settings page
local function showText(v) for _,e in ipairs(shows) do if e[1]==v then return e[2] end end return "In combat" end
function Threat:SetMovingText(on)
    if on and InCombatLockdown() then return end
    if on and not yes(UnitExists("target")) then FT:Toast("Target something first.",3); on=false end
    self.movingText=on==true
    self:Apply()
end
function Threat:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Threat meter: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.showChoice.value=s.show; self.showChoice.label:SetText("Show: "..showText(s.show))
    self.lock.label:SetText("Lock meter: "..(s.locked and "On" or "Off")); FT:SetSelected(self.lock,s.locked)
    self.gripChoice.value=s.grip; self.gripChoice.label:SetText(s.grip=="always" and "Resize corner: always" or "Resize corner: on mouseover")
    self.gripChoice:SetAlpha(s.locked and .5 or 1)
    self.placeNote:SetText((s.x and "Moved by you." or (self:DamageMeter() and "Placed next to the damage meter." or "Placed on the right side."))
        ..(s.locked and " Locked." or ""))
    self.textToggle.label:SetText("Threat % above target: "..(s.text and "On" or "Off")); FT:SetSelected(self.textToggle,s.text)
    local _,label=FT.modules.FontManager:Resolve(s)
    self.fontChoice.value=s.font; self.fontChoice.label:SetText("Font: "..(label or "Friz Quadrata"))
    self.outlineChoice.value=s.outline; self.outlineChoice.label:SetText(s.outline=="" and "No outline" or s.outline=="OUTLINE" and "Outline" or "Thick outline")
    self.sizeLabel:SetText("Font size: "..s.size)
    self.bgToggle.label:SetText("Background: "..(s.background and "On" or "Off")); FT:SetSelected(self.bgToggle,s.background)
    self.bgColor.swatch:SetColorTexture(s.backgroundColor[1],s.backgroundColor[2],s.backgroundColor[3],1)
    self.alphaLabel:SetText(string.format("Transparency: %d%%",math.floor((1-s.backgroundAlpha)*100+.5)))
    self.settingSliders=true
    self.sizeSlider:SetValue(s.size); self.alphaSlider:SetValue(math.floor((1-s.backgroundAlpha)*100+.5))
    self.settingSliders=false
    for _,c in ipairs({self.bgColor,self.alphaSlider,self.alphaLabel}) do c:SetAlpha(s.background and 1 or .5) end
    local p=self.textPreview
    local path=FT.modules.FontManager:Resolve(s)
    if not path or not FT.modules.FontManager:ValidFont(path) then path="Fonts\\FRIZQT__.TTF" end
    p.label:SetFont(path,math.min(s.size,24),s.outline); p.label:SetText("72%")
    if GetThreatStatusColor then p.label:SetTextColor(GetThreatStatusColor(2)) else p.label:SetTextColor(1,.6,0) end
    local w=p.label:GetStringWidth(); if type(w)~="number" then w=40 end
    p.box:SetSize(math.max(34,w+14),math.min(s.size,24)+10)
    local c=s.backgroundColor
    for _,t in ipairs(p.box.background) do t:SetVertexColor(c[1],c[2],c[3],s.backgroundAlpha); t:SetShown(s.background) end
    FT:RefreshPreview(self.frame)
end
function Threat:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsThreat","Threat",540,578); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        FT:PageInfo(frame,"Threat","A threat meter like the game's damage meter, and your threat % above your target. 100% means you have aggro.\n\nIn some dungeons the numbers can't be sorted or colored.")
        self.toggle=FT:AccentButton(frame,"",492,34,ICON); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Threat meter","Your group's threat on your target, next to the damage meter.")
        self.previewButton=FT:TopPreview(frame,self.toggle,{get=function() return self.previewing==true end,
            set=function(on)
                on=on and not InCombatLockdown()
                self.previewing=on; self.moverUnlock=on or nil; self.skinPeek=nil
                -- The threat % can only be dragged with a target.
                self.movingText=on and yes(UnitExists("target")) or false
                self:Apply()
            end,tip="Also the threat % above your target, when you have one."})
        self.showChoice=FT:Dropdown(frame,240,function()
            local list={}; for _,e in ipairs(shows) do list[#list+1]={value=e[1],label=e[2],icon="Interface\\Icons\\"..ICON} end; return list
        end,function(value) self:Settings().show=value; self:Apply() end,ICON)
        self.showChoice:SetPoint("TOPLEFT",24,-108)
        FT:Tooltip(self.showChoice,"Show","When the meter shows. Always shown on this page.")
        local reset=FT:QuietButton(frame,"Reset position and size",240,32,"reset"); reset:SetPoint("TOPLEFT",276,-108)
        reset:SetScript("OnClick",function() local s=self:Settings(); s.x,s.y,s.width,s.height=nil,nil,nil,nil; self:Apply() end)
        FT:Tooltip(reset,"Reset position and size","Back next to the damage meter, at its starting size.")
        self.lock=FT:QuietButton(frame,"",240,32,"move"); self.lock:SetPoint("TOPLEFT",24,-148)
        self.lock:SetScript("OnClick",function() local s=self:Settings(); s.locked=not s.locked; self:Apply() end)
        FT:Tooltip(self.lock,"Lock meter","Can't be moved or resized while locked.")
        self.gripChoice=FT:Dropdown(frame,240,function()
            local icon="Interface\\Icons\\"..ICON
            return {{value="always",label="Resize corner: always",icon=icon,tooltip="Always show the resize corner when unlocked."},
                {value="hover",label="Resize corner: on mouseover",icon=icon,tooltip="Show the resize corner on mouseover."}}
        end,function(value) self:Settings().grip=value; self:Apply() end,"move")
        self.gripChoice:SetPoint("TOPLEFT",276,-148)
        FT:Tooltip(self.gripChoice,"Resize corner","When the resize corner shows.")
        local function fontButton(label,area,x,tip)
            local b=FT:QuietButton(frame,label,240,32,"fonts"); b:SetPoint("TOPLEFT",x,-188)
            b:SetScript("OnClick",function() local fonts=FT.modules.FontManager; fonts.selected=area; FT:OpenModule("FontManager") end)
            FT:Tooltip(b,label,tip)
        end
        fontButton("Threat meter font","threatMeter",24,"Font of the threat meter (opens Fonts).")
        fontButton("Damage meter font","damageMeter",276,"Font of the game's damage meter (opens Fonts).")
        self.placeNote=FT:Label(frame,"",12); self.placeNote:SetPoint("TOPLEFT",24,-228); self.placeNote:SetWidth(492); self.placeNote:SetTextColor(.66,.59,.48)

        local heading=FT:Label(frame,"Threat % above target",15,true); heading:SetPoint("TOPLEFT",24,-278)
        FT:SectionHeading(heading,ICON,300)
        self.textToggle=FT:AccentButton(frame,"",380,34,ICON); self.textToggle:SetPoint("TOPLEFT",24,-308)
        -- A live example with your font, size, outline and background.
        self.textPreview=CreateFrame("Frame",nil,frame); self.textPreview:SetSize(100,34); self.textPreview:SetPoint("TOPLEFT",416,-308)
        FT:Panel(self.textPreview); FT:Paint(self.textPreview,{.03,.03,.04,1},{.61,.51,.31,1})
        self.textPreview.box=CreateFrame("Frame",nil,self.textPreview); self.textPreview.box:SetPoint("CENTER")
        self.textPreview.box.background=FT:RoundedFill(self.textPreview.box,0,0,0,.6)
        self.textPreview.label=self.textPreview.box:CreateFontString(nil,"OVERLAY"); self.textPreview.label:SetPoint("CENTER")
        self.textPreview.label:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
        self.textPreview:EnableMouse(true)
        FT:Tooltip(self.textPreview,"Preview","Your threat % with these settings.")
        self.textToggle:SetScript("OnClick",function() local s=self:Settings(); s.text=not s.text; self:Apply() end)
        FT:Tooltip(self.textToggle,"Threat % above target","Your threat % above your target. Turns yellow, orange and red near aggro.")
        self.fontChoice=FT:Dropdown(frame,240,function() return FT.modules.FontManager:Catalogue() end,function(value) self:Settings().font=value; self:Apply() end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",24,-354)
        FT:Tooltip(self.fontChoice,"Font","The font of the threat %.")
        self.outlineChoice=FT:Dropdown(frame,240,function() return {{value="",label="No outline"},{value="OUTLINE",label="Outline"},{value="THICKOUTLINE",label="Thick outline"}} end,function(value) self:Settings().outline=value; self:Apply() end,"fonts")
        self.outlineChoice:SetPoint("TOPLEFT",276,-354)
        FT:Tooltip(self.outlineChoice,"Outline","A dark edge so the text stays readable.")
        local function slider(top,min,max,step,title,tip,onChange)
            local text=FT:Label(frame,"",14); text:SetPoint("TOPLEFT",24,top-2); text:SetWidth(160)
            local bar=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); bar:SetSize(300,18); bar:SetPoint("TOPLEFT",196,top)
            bar:SetMinMaxValues(min,max); bar:SetValueStep(step); bar:SetObeyStepOnDrag(true)
            for _,key in ipairs({"Low","High","Text"}) do local r=bar[key] or (bar.GetName and bar:GetName() and _G[bar:GetName()..key]); if r and r.Hide then r:Hide() end end
            bar:SetScript("OnValueChanged",function(_,v) if not self.settingSliders then onChange(v) end end)
            FT:Tooltip(bar,title,tip)
            return text,bar
        end
        self.sizeLabel,self.sizeSlider=slider(-398,8,32,1,"Font size","Text size of the threat % (8 to 32).",function(v) self:Settings().size=math.floor(v+.5); FT:Coalesce("threatSlider",function() self:Apply() end,.05) end)
        self.bgToggle=FT:QuietButton(frame,"",240,32,"skins"); self.bgToggle:SetPoint("TOPLEFT",24,-432)
        self.bgToggle:SetScript("OnClick",function() local s=self:Settings(); s.background=not s.background; self:Apply() end)
        FT:Tooltip(self.bgToggle,"Background","A rounded background behind the threat %.")
        self.bgColor=FT:QuietButton(frame,"Background color",240,32); self.bgColor:SetPoint("TOPLEFT",276,-432)
        self.bgColor.swatch=self.bgColor:CreateTexture(nil,"ARTWORK"); self.bgColor.swatch:SetSize(18,18); self.bgColor.swatch:SetPoint("LEFT",10,0)
        self.bgColor.label:ClearAllPoints(); self.bgColor.label:SetPoint("LEFT",self.bgColor.swatch,"RIGHT",8,0)
        self.bgColor:SetScript("OnClick",function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local s=self:Settings(); local old={unpack(s.backgroundColor)}
            s.background=true
            FT:TrackColorPicker()
            ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,
                swatchFunc=function() s.backgroundColor={ColorPickerFrame:GetColorRGB()}; FT:Coalesce("threatColor",function() self:Apply() end,.05) end,
                cancelFunc=function() s.backgroundColor=old; self:Apply() end})
            self:Apply()
        end)
        FT:Tooltip(self.bgColor,"Background color","Background color.")
        self.alphaLabel,self.alphaSlider=slider(-478,0,100,5,"Transparency","0% solid, 100% invisible.",function(v) self:Settings().backgroundAlpha=1-math.floor(v+.5)/100; FT:Coalesce("threatSlider",function() self:Apply() end,.05) end)
        local resetText=FT:QuietButton(frame,"Reset position",240,32,"reset"); resetText:SetPoint("TOPLEFT",24,-512)
        resetText:SetScript("OnClick",function() local s=self:Settings(); s.textX,s.textY=0,2; self:Apply() end)
        FT:Tooltip(resetText,"Reset position","Back just above the target portrait.")
        frame:SetHeight(578)
    end
    self.frame:Show(); self:Apply()
end
FT:RegisterModule("Threat",Threat)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Threat:Apply() end end)

-- /ft threatdebug: where the damage meter's art is and where the threat
-- meter sits (to find a gap).
function Threat:Debug()
    local function r4(t) if not t then return "none" end; return string.format("left %.1f right %.1f top %.1f bottom %.1f",t[1],t[2],t[3],t[4]) end
    local w=self:MeterWindow()
    print("ForeverTools threat: damage meter window "..tostring(w and w.GetName and w:GetName() or "not found"))
    self:MeterRect()
    local info=self.rectInfo or {}
    print("  window "..r4(info.window)); print("  art    "..r4(info.art))
    local f=self.meter
    if f then print("  threat "..r4({f:GetLeft() or 0,f:GetRight() or 0,f:GetTop() or 0,f:GetBottom() or 0})..string.format("  scale %.2f",f:GetEffectiveScale()/UIParent:GetEffectiveScale())) end
    local m=self:MirrorBar()
    print("  damage meter bar: "..(m and string.format("row %d bar %d fill %s",m.row,m.bar,tostring(m.fill and (m.fill.atlas or m.fill.file))) or "none found"))
    local row=self.rows and self.rows[1]
    if row and row.bar then
        local t=row.bar:GetStatusBarTexture()
        print("  threat bar fill: "..tostring(t and (t:GetAtlas() or t:GetTexture()))..string.format("  bar %.0fx%.0f",row.bar:GetWidth(),row.bar:GetHeight()))
    end
    if w then
        local k=UIParent:GetEffectiveScale()
        local wl,wt=w:GetLeft(),w:GetTop()
        local lines=0
        local function visit(fr,depth,path)
            if depth<0 or lines>=90 then return end
            local ok,list=pcall(function() return {fr:GetRegions()} end)
            if ok then for _,region in ipairs(list) do
                if lines<90 and region.GetObjectType and region:GetObjectType()=="Texture" and region:IsShown() then
                    local a=region.GetAtlas and region:GetAtlas()
                    if secret(a) or a=="" then a=nil end
                    local raw=region.GetTexture and region:GetTexture()
                    if secret(raw) then raw="?" end
                    local l,t,w2,h=region:GetLeft(),region:GetTop(),region:GetWidth(),region:GetHeight()
                    if not secret(l) and l and wl then
                        lines=lines+1
                        local cr,cg,cb,ca=region:GetVertexColor()
                        local function n(v) if secret(v) or type(v)~="number" then return "?" end; return string.format("%.2f",v) end
                        print(string.format("    %s  %s  %s  %s  at %.0f,%.0f  %.0fx%.0f  color %s %s %s %s  alpha %s",path,tostring(a or raw),tostring(region:GetDrawLayer()),region:GetObjectType(),l-wl,t-wt,w2,h,n(cr),n(cg),n(cb),n(ca),n(region:GetAlpha())))
                    end
                end
            end end
            local okC,kids=pcall(function() return {fr:GetChildren()} end)
            if okC then for i,child in ipairs(kids) do if child:IsShown() then local nm=child.GetName and child:GetName(); if type(nm)~="string" or secret(nm) then nm=(child.GetObjectType and child:GetObjectType() or "")..i end; visit(child,depth-1,path.."."..nm) end end end
        end
        visit(w,6,"w")
    end
end
