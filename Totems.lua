local _,FT=...
-- Totems (shamans; off by default). Two tools:
--  * a soft circle on the minimap for each totem you place, showing its
--    30-yard reach, so you can see when you're about to leave it;
--  * a left-behind warning: the totem's own icon under the player frame
--    pulses red once you are farther from it than a distance you choose.
--
-- The game doesn't say where a totem stands, so the spot is your own map
-- position at the moment you place it. After Totemic Projection moves your
-- totems the new spot is unknown, so the circles hide until you place again.
-- Where the game hides your position (dungeons, raids) nothing is drawn.
local Totems={}
local RANGE=30 -- WoW Forever buff totems reach party members within 30 yards
-- Totem slots: 1 fire, 2 earth, 3 water, 4 air. Default colors, changeable.
local elements={{key="fire",label="Fire",color={1,.5,.08}},{key="earth",label="Earth",color={158/255,136/255,101/255}},
    {key="water",label="Water",color={.1,.3,.95}},{key="air",label="Air",color={.2,.9,1}}}
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function safe(fn,...) if not fn then return end local ok,a,b,c,d,e,f,g=pcall(fn,...) if ok then return a,b,c,d,e,f,g end end
local function isShaman() local _,class=UnitClass("player"); return class=="SHAMAN" end
function Totems:Settings()
    if type(FT.db.totems)~="table" then FT.db.totems={} end
    local s=FT.db.totems
    if type(s.range)~="boolean" then s.range=false end
    if type(s.leftBehind)~="boolean" then s.leftBehind=false end
    s.leftRange=math.max(20,math.min(60,tonumber(s.leftRange) or 30))
    if type(s.opacity)~="number" or s.opacity~=s.opacity then s.opacity=.85 end
    -- Earlier test defaults (softer, older earth color) move to the new ones
    -- unless they were changed.
    if s.defaults~=2 then
        s.defaults=2
        if math.abs(s.opacity-.45)<.001 then s.opacity=.85 end
        local e=type(s.colors)=="table" and s.colors.earth
        if type(e)=="table" and math.abs((e[1] or 0)-.62)<.001 and math.abs((e[2] or 0)-.4)<.001 and math.abs((e[3] or 0)-.16)<.001 then s.colors.earth=nil end
    end
    s.opacity=math.max(.1,math.min(1,s.opacity))
    if type(s.colors)~="table" then s.colors={} end
    for _,e in ipairs(elements) do
        local c=s.colors[e.key]
        if type(c)~="table" then c={unpack(e.color)}; s.colors[e.key]=c end
        for i=1,3 do if type(c[i])~="number" then c[i]=e.color[i] end; c[i]=math.max(0,math.min(1,c[i])) end
    end
    return s
end
-- Where you are, in world yards on the continent (the same numbers on every
-- zone, city or sub-zone map, so a totem stays put when the map changes),
-- plus which way east and north point in those numbers.
local function world(map,x,y)
    if not CreateVector2D then return end
    local continent,pos=safe(C_Map.GetWorldPosFromMapPos,map,CreateVector2D(x,y))
    if type(continent)~="number" or not pos or not pos.GetXY then return end
    local wx,wy=pos:GetXY()
    if secret(wx) or secret(wy) or type(wx)~="number" or type(wy)~="number" then return end
    return continent,wx,wy
end
local axes={}
local function here()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetWorldPosFromMapPos then return end
    local map=safe(C_Map.GetBestMapForUnit,"player")
    if type(map)~="number" or secret(map) then return end
    local pos=safe(C_Map.GetPlayerMapPosition,map,"player")
    if not pos or not pos.GetXY then return end
    local x,y=pos:GetXY()
    if secret(x) or secret(y) or type(x)~="number" or type(y)~="number" or (x==0 and y==0) then return end
    local continent,wx,wy=world(map,x,y)
    if not continent then return end
    -- Directions never change for a map, so they're worked out once per map.
    local d=axes[map]
    if not d then
        local _,ex,ey=world(map,x+.001,y); local _,nx,ny=world(map,x,y-.001)
        if not ex or not nx then return end
        ex,ey=ex-wx,ey-wy; nx,ny=nx-wx,ny-wy
        local el,nl=math.sqrt(ex*ex+ey*ey),math.sqrt(nx*nx+ny*ny)
        if el<=0 or nl<=0 then return end
        d={ex/el,ey/el,nx/nl,ny/nl}; axes[map]=d
    end
    return continent,wx,wy,d[1],d[2],d[3],d[4]
end
Totems.placed={}
-- Every totem standing right now, with or without a known spot:
-- [slot]={start=,name=,moved=}. "moved" is how many yards you have run since
-- it went down where the game gives no position (nil when we can't tell).
Totems.up={}
Totems.warned={}
-- In a fight the game can hide a slot's details. veiled[slot] marks those
-- slots; maybe[slot] is a slot that changed right after a cast the game
-- would not name (decided once Blizzard has redrawn its totem icons).
Totems.veiled={}
Totems.maybe={}
local active={}
-- Counters for the bug report: which of these paths this client really takes.
local seen={hidden=0,casts=0,hiddenCasts=0,guessed=0,dropped=0}
-- The circles: one per totem slot, clipped to a round minimap.
function Totems:Layer()
    if self.layer or not Minimap then return self.layer end
    local layer=CreateFrame("Frame",nil,Minimap); layer:SetAllPoints(Minimap)
    layer:SetFrameLevel(Minimap:GetFrameLevel()+2)
    local mask=layer:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(Minimap)
    layer.circles={}
    for slot=1,4 do
        local t=layer:CreateTexture(nil,"ARTWORK")
        t:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        -- Square minimaps (from other addons) aren't clipped to a circle.
        local square=GetMinimapShape and GetMinimapShape()=="SQUARE"
        if not square then t:AddMaskTexture(mask) end
        t:Hide(); layer.circles[slot]=t
    end
    -- The circles cover the game's own player arrow, so draw the same arrow
    -- again on top of them while any circle shows.
    layer.arrow=layer:CreateTexture(nil,"OVERLAY")
    layer.arrow:SetTexture("Interface\\Minimap\\MinimapArrow"); layer.arrow:SetSize(32,32); layer.arrow:SetPoint("CENTER",Minimap,"CENTER",0,0)
    layer.arrow:Hide()
    -- Every frame while a circle is up, so it moves as smoothly as the map
    -- (four textures; drawing less often made the circles shiver when moving).
    layer:SetScript("OnUpdate",function()
        self:Draw()
    end)
    self.layer=layer
    return layer
end
function Totems:Paint()
    if not self.layer then return end
    local s=self:Settings()
    for slot,e in ipairs(elements) do local c=s.colors[e.key]; self.layer.circles[slot]:SetVertexColor(c[1],c[2],c[3],s.opacity) end
end
function Totems:Draw()
    local layer=self.layer; if not layer then return end
    local continent,wx,wy,ex,ey,nx,ny=here()
    local radius=C_Minimap and C_Minimap.GetViewRadius and safe(C_Minimap.GetViewRadius)
    local any=false
    local rotate=GetCVar and GetCVar("rotateMinimap")=="1"
    local facing=safe(GetPlayerFacing)
    if secret(facing) or type(facing)~="number" then facing=nil end
    local half=Minimap:GetWidth()/2
    for slot=1,4 do
        local t,p=layer.circles[slot],self.placed[slot]
        local shown=false
        if p and continent and p.continent==continent and type(radius)=="number" and radius>0 and (facing or not rotate) then
            any=true
            local dx,dy=p.x-wx,p.y-wy
            local east=dx*ex+dy*ey; local north=dx*nx+dy*ny
            if rotate then
                local c,s=math.cos(facing),math.sin(facing)
                east,north=east*c+north*s,-east*s+north*c
            end
            local scale=half/radius
            t:ClearAllPoints(); t:SetPoint("CENTER",Minimap,"CENTER",east*scale,north*scale)
            t:SetSize(RANGE*2*scale,RANGE*2*scale)
            shown=true
        end
        t:SetShown(shown)
    end
    -- The arrow copy turns with you (on a rotating minimap it always points up).
    layer.arrow:SetShown(any and facing~=nil)
    if any and facing then layer.arrow:SetRotation(rotate and 0 or facing) end
    -- Nothing left to follow: stop updating until the next totem.
    local keep=false; for slot=1,4 do if self.placed[slot] then keep=true end end
    layer:SetShown(keep)
    return any
end
-- Totems you just cast, with where you stood: {name=, time=, continent=, x=, y=}.
-- The game reports a new totem a moment after the cast, sometimes before its
-- slot shows the new totem; the cast tells us where it went down.
Totems.casts={}
local function isTotemSpell(name) return type(name)=="string" and name:find("Totem",1,true) and not name:find("Totemic",1,true) end
function Totems:NoteCast(name)
    local continent,wx,wy=here()
    table.insert(self.casts,1,{name=name:lower(),time=GetTime(),continent=continent,x=wx,y=wy})
    while #self.casts>6 do table.remove(self.casts) end
    -- Look again shortly: the slot can update a moment after the cast.
    for _,delay in ipairs({.1,.5,1.5}) do C_Timer.After(delay,function() if next(self.casts) then self:Scan() end end) end
end
-- The cast that put this totem down: same name if possible, else the newest
-- unused one from the last few seconds.
-- Which element (slot) a totem spell belongs to, by name.
local elementOf={}
for slot,list in ipairs({
    {"searing","fire nova","magma","flametongue","frost resistance","totem of wrath"},
    {"stoneskin","earthbind","stoneclaw","strength of earth","tremor","earth elemental"},
    {"healing stream","mana spring","poison cleansing","disease cleansing","fire resistance","mana tide"},
    {"grounding","nature resistance","windfury","grace of air","windwall","tranquil air","wrath of air","sentry"}}) do
    for _,n in ipairs(list) do elementOf[n]=slot end
end
local function slotOf(spell) for n,slot in pairs(elementOf) do if spell:find(n,1,true) then return slot end end end
function Totems:MatchCast(name,slot,changed)
    local now=GetTime(); local lower=type(name)=="string" and name:lower() or ""
    local fallback
    for i,c in ipairs(self.casts) do
        -- Hidden details: a cast known to be for this element counts. A totem
        -- whose element we don't know counts only for the slot the game says
        -- just changed.
        if slot then
            if not c.used and now-c.time<3 then
                local element=slotOf(c.name)
                if element==slot then c.used=true; return c end
                if changed and not element then fallback=fallback or c end
            end
        elseif not c.used and now-c.time<3 then
            if lower~="" and (lower:find(c.name,1,true) or c.name:find(lower,1,true)) then c.used=true; return c end
            fallback=fallback or c
        end
    end
    if fallback then fallback.used=true end
    return fallback
end
-- Is this record, made while the game hid the details, the totem the game
-- now describes? Same name, and it went down when the record was made (so a
-- record that went stale during a fight is never taken for a newer totem).
local function sameTotem(rec,name,start)
    if not rec or not rec.hidden then return false end
    if rec.castAt and math.abs(start-rec.castAt)>3 then return false end
    return type(rec.name)~="string" or name:lower():find(rec.name,1,true)~=nil
end
function Totems:Update(slot,noDraw,changed)
    if type(slot)~="number" or slot<1 or slot>4 then return end
    local have,name,start,duration=safe(GetTotemInfo,slot)
    if secret(have) or secret(start) or secret(duration) or secret(name) then
        -- In combat the game can hide totem details. Keep what we drew, and
        -- place a totem you just cast by its element (known from its name).
        self.veiled[slot]=true; seen.hidden=seen.hidden+1
        local cast=self:MatchCast(nil,slot,changed)
        if cast then
            -- A new totem always replaces what we knew about the slot, also
            -- when we could not tell where you stood.
            self.placed[slot]=cast.continent and {continent=cast.continent,x=cast.x,y=cast.y,name=cast.name,hidden=true,castAt=cast.time} or nil
            self.up[slot]={moved=0,name=cast.name,hidden=true,castAt=cast.time}
        elseif changed then
            -- The game says this slot changed and we saw no totem cast for
            -- it: it was clicked away, destroyed or ran out...
            self.placed[slot]=nil; self.up[slot]=nil
            -- ...unless you just cast something the game would not name.
            local at=self.hiddenCast
            if at and GetTime()-at<1.5 then self.maybe[slot]=at end
        end
    elseif have and type(start)=="number" and type(duration)=="number" and duration>0 and type(name)=="string" and name~="" then
        self.veiled[slot]=nil
        local up=self.up[slot]
        if sameTotem(up,name,start) then up.start,up.name,up.hidden=start,name,nil end
        -- A new totem in this slot: the yards-run count starts over. One that
        -- was up before we were watching has no count.
        if not up or up.start~=start or up.name~=name then self.up[slot]={start=start,name=name,moved=(GetTime()-start<3) and 0 or nil} end
        local old=self.placed[slot]
        -- Placed while the game hid the details: now we can read them, keep
        -- the spot if it's the same totem.
        if sameTotem(old,name,start) then old.start,old.name,old.hidden=start,name,nil end
        -- A different totem than the one we drew (or none drawn yet).
        if not old or old.start~=start or old.name~=name then
            local cast=self:MatchCast(name)
            if cast and cast.continent then
                self.placed[slot]={continent=cast.continent,x=cast.x,y=cast.y,start=start,name=name}
            elseif GetTime()-start<2 then
                local continent,wx,wy=here()
                self.placed[slot]=continent and {continent=continent,x=wx,y=wy,start=start,name=name} or nil
            else
                -- Up since before we were watching: we don't know where it is.
                self.placed[slot]=nil
            end
        end
    else self.veiled[slot]=nil; self.placed[slot]=nil; self.up[slot]=nil end
    if noDraw then return end
    self:Show()
end
-- Draw the circles (if that tool is on) and bring the warning up to date.
function Totems:Show()
    if self:Settings().range then
        local layer=self:Layer(); if layer then self:Paint(); layer:Show(); self:Draw() end
    end
    self:Watch()
end
-- All four slots at once: the event's slot number isn't always the one that
-- changed (replacing a totem can report only the old one).
function Totems:Scan(changed)
    -- A look-again timer can fire after both tools were turned off.
    if not self.tracking then return end
    if secret(changed) then changed=nil end
    for slot=1,4 do self:Update(slot,true,slot==changed) end
    self:Show()
    -- Blizzard redraws its totem icons on the same event; compare on the
    -- next frame, when they are up to date whichever of us ran first.
    FT:Coalesce("totemSync",function() self:Sync() end,0)
end
-- Blizzard's own totem icons say which slots hold a totem, also in a fight.
-- Called right after Blizzard redraws them. For slots whose details are
-- hidden: no icon means the totem is gone (forget it), and an icon in a slot
-- that changed right after an unnamed cast is a totem you just placed, here.
-- Blizzard also hands its icons out again on every redraw, so the pulse is
-- repainted each time or it would stay on an icon that now shows another totem.
function Totems:Sync()
    if not self.tracking then return end
    local frame=TotemFrame
    local changed=false
    if frame and frame.GetChildren and frame.IsEventRegistered and frame:IsEventRegistered("PLAYER_TOTEM_UPDATE")==true then
        for slot=1,4 do active[slot]=nil end
        for _,button in ipairs({frame:GetChildren()}) do
            local slot=button.slot
            if not secret(slot) and type(slot)=="number" and button:IsShown()==true then active[slot]=true end
        end
        local now=GetTime()
        for slot=1,4 do
            if self.veiled[slot] then
                local rec=self.up[slot] or self.placed[slot]
                if not active[slot] then
                    -- A totem cast a moment ago may not have its icon yet.
                    if rec and not (rec.castAt and now-rec.castAt<1.2) then
                        self.up[slot]=nil; self.placed[slot]=nil; changed=true; seen.dropped=seen.dropped+1
                    end
                elseif self.maybe[slot] and not rec then
                    local at=self.maybe[slot]
                    local continent,wx,wy=here()
                    self.up[slot]={moved=0,hidden=true,castAt=at}
                    self.placed[slot]=continent and {continent=continent,x=wx,y=wy,hidden=true,castAt=at} or nil
                    changed=true; seen.guessed=seen.guessed+1
                end
            end
            self.maybe[slot]=nil
        end
    end
    if changed then self:Show() end
    self:PaintWarnings()
end
-- One line for the bug report (our own numbers only, nothing hidden).
function Totems:Report()
    local parts={}
    for slot=1,4 do
        local up,p=self.up[slot],self.placed[slot]
        if up or p then
            parts[#parts+1]=slot..":"..((up and up.hidden or p and p.hidden) and "hidden" or "known")..(p and "+spot" or "")..(self.warned[slot] and "+warn" or "")
        end
    end
    return "Totems: "..(#parts>0 and table.concat(parts," ") or "none up").." · hidden reads "..seen.hidden..", totem casts "..seen.casts..", unnamed casts "..seen.hiddenCasts..", guessed "..seen.guessed..", dropped "..seen.dropped
end

-- Left-behind warning. Checked five times a second, and only while a totem
-- is standing; nothing runs otherwise.
local watcher=CreateFrame("Frame"); watcher:Hide()
local waited=0
watcher:SetScript("OnUpdate",function(_,dt)
    waited=waited+dt
    if waited<.2 then return end
    local elapsed=waited; waited=0
    Totems:Check(elapsed)
end)
function Totems:Watch()
    local on=self:Settings().leftBehind==true and next(self.up)~=nil
    watcher:SetShown(on)
    if on then self:Check(0)
    elseif next(self.warned) then self.warned={}; self:PaintWarnings() end
    -- Blizzard moves its totem icons around on the same event: look again
    -- on the next frame so the pulse sits on the right icon.
    if on or self.ringsUsed then FT:Coalesce("totemWarning",function() self:PaintWarnings() end,0) end
end
function Totems:Check(elapsed)
    local limit=self:Settings().leftRange
    local continent,wx,wy=here()
    -- Where the game gives no position (dungeons, raids) the distance is a
    -- guess: the yards you have run since the totem went down, counted out
    -- of combat only (in a fight you mostly move around your totems).
    local run=0
    if not continent and elapsed>0 and not InCombatLockdown() then
        local speed=safe(GetUnitSpeed,"player")
        if not secret(speed) and type(speed)=="number" then run=speed*math.min(elapsed,1) end
    end
    local changed=false
    for slot=1,4 do
        local up,warn=self.up[slot],false
        if up then
            local p=self.placed[slot]
            -- The spot must be this totem's own, never an earlier totem's.
            if p and (p.start~=up.start or (up.start==nil and p.castAt~=up.castAt)) then p=nil end
            if continent and p and p.continent==continent then
                local dx,dy=p.x-wx,p.y-wy
                warn=dx*dx+dy*dy>limit*limit
            elseif not continent and up.moved then
                up.moved=up.moved+run; warn=up.moved>limit
            end
        end
        if (self.warned[slot]==true)~=warn then self.warned[slot]=warn or nil; changed=true end
    end
    if changed then self:PaintWarnings() end
end
-- The pulse: a red copy of the icon's ring, on top of Blizzard's own, fading
-- in and out. The ring underneath (and its skin color) is never changed.
local rings=setmetatable({},{__mode="k"})
local RING="UI-HUD-UnitFrame-TotemFrame"
local function ringFor(button)
    local holder=rings[button]
    if holder then return holder end
    holder=CreateFrame("Frame",nil,button)
    holder:SetAllPoints(button.Border or button)
    if holder.SetFrameLevel and button.GetFrameLevel then holder:SetFrameLevel((button:GetFrameLevel() or 0)+3) end
    local art=C_Texture and C_Texture.GetAtlasInfo and safe(C_Texture.GetAtlasInfo,RING)
    for i=1,2 do
        local t=holder:CreateTexture(nil,"OVERLAY",nil,5+i)
        if art then t:SetAtlas(RING) else t:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") end
        t:SetAllPoints(holder); if t.SetDesaturated then t:SetDesaturated(true) end
        t:SetVertexColor(1,.1,.06,i==1 and 1 or .7)
        -- The second layer adds light, so the red stays bright on a dark ring.
        if i==2 then t:SetBlendMode("ADD") end
    end
    local pulse=holder:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(0); fade:SetToAlpha(1); fade:SetDuration(.55); fade:SetSmoothing("IN_OUT")
    holder.pulse=pulse; holder:Hide()
    rings[button]=holder
    return holder
end
function Totems:PaintWarnings()
    local frame=TotemFrame
    if not frame or not frame.GetChildren then return end
    local any=false
    for _,button in ipairs({frame:GetChildren()}) do
        local slot=button.slot
        local on=not secret(slot) and type(slot)=="number" and self.warned[slot]==true and button:IsShown()==true
        local holder=rings[button]
        if on and not holder then holder=ringFor(button) end
        if holder then
            holder:SetShown(on)
            if on then any=true; if not holder.pulse:IsPlaying() then holder.pulse:Play() end
            elseif holder.pulse:IsPlaying() then holder.pulse:Stop() end
        end
    end
    self.ringsUsed=any
end
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event,a,_,spellID)
    if event=="PLAYER_TOTEM_UPDATE" then Totems:Scan(a)
    elseif event=="PLAYER_REGEN_ENABLED" then
        -- The fight is over: details are readable again, so check every slot
        -- against the game (now, and once more in case they lag a moment).
        Totems:Scan(); C_Timer.After(1,function() Totems:Scan() end)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        if secret(spellID) or type(spellID)~="number" then
            -- The game won't say what you cast; remember only that you did.
            if secret(spellID) then Totems.hiddenCast=GetTime(); seen.hiddenCasts=seen.hiddenCasts+1 end
            return
        end
        local name=C_Spell and C_Spell.GetSpellName and safe(C_Spell.GetSpellName,spellID) or (GetSpellInfo and safe(GetSpellInfo,spellID))
        if type(name)~="string" or secret(name) then return end
        -- Totemic Projection moves your totems to a spot we can't see.
        if name:lower()=="totemic projection" then
            Totems.placed={}; if Totems.layer then Totems:Draw() end
            for _,up in pairs(Totems.up) do up.moved=nil end
        elseif isTotemSpell(name) then seen.casts=seen.casts+1; Totems:NoteCast(name) end
    elseif event=="PLAYER_ENTERING_WORLD" then
        -- A new zone or loading screen: earlier spots may be on another map.
        Totems:Scan()
    end
end)
function Totems:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    self.tracking=(s.range or s.leftBehind) and isShaman() or false
    if self.tracking then
        events:RegisterEvent("PLAYER_TOTEM_UPDATE"); events:RegisterEvent("PLAYER_ENTERING_WORLD"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
        -- Follow Blizzard's totem icons: every redraw can move them around.
        if not self.hooked and hooksecurefunc and TotemFrame and type(TotemFrame.Update)=="function" then
            self.hooked=true
            hooksecurefunc(TotemFrame,"Update",function() Totems:Sync() end)
        end
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
        if s.range then self:Paint() elseif self.layer then self.layer:Hide() end
        self:Scan()
    else
        events:UnregisterAllEvents(); self.placed={}; self.up={}; self.veiled={}; self.maybe={}
        if self.layer then self.layer:Hide() end
        self:Watch()
    end
    self:Refresh()
end

-- Settings page (Combat > Totems)
function Totems:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Totem range on minimap: "..(s.range and "On" or "Off")); FT:SetSelected(self.toggle,s.range)
    self.note:SetText(isShaman() and "" or "Only shamans place totems, so this does nothing on this character.")
    for _,e in ipairs(elements) do local b=self.colorButtons[e.key]; b.swatch:SetVertexColor(unpack(s.colors[e.key])); b:SetAlpha(s.range and 1 or .5) end
    self.settingSlider=true; self.slider:SetValue(1-s.opacity); self.settingSlider=false
    self.opacityLabel:SetText("Circle transparency: "..math.floor(100-s.opacity*100+.5).."%")
    self.leftToggle.label:SetText("Left-behind warning: "..(s.leftBehind and "On" or "Off")); FT:SetSelected(self.leftToggle,s.leftBehind)
    self.settingSlider=true; self.leftSlider:SetValue(s.leftRange); self.settingSlider=false
    self.leftLabel:SetText("Warn beyond: "..s.leftRange.." yards")
    self.leftLabel:SetAlpha(s.leftBehind and 1 or .5); self.leftSlider:SetAlpha(s.leftBehind and 1 or .5)
end
function Totems:PickColor(key)
    local c=self:Settings().colors[key]; local old={c[1],c[2],c[3]}
    local function set(r,g,b) c[1],c[2],c[3]=r,g,b; self:Paint(); self:Refresh() end
    local function change() set(ColorPickerFrame:GetColorRGB()) end
    local function cancel() set(old[1],old[2],old[3]) end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        FT:TrackColorPicker(); ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
    elseif ColorPickerFrame then ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=change; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
end
function Totems:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTotems","Totems",520,372); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        FT:PageInfo(frame,"Totems","Tools for shamans' totems.\n\nTotem range on minimap: a circle for each totem's 30-yard reach.\n\nLeft-behind warning: the totem's own icon under your player frame pulses red once you are farther from it than the distance you set, so a forgotten totem doesn't pull for you. Right-click the icon to remove the totem. Outdoors the distance is measured from where you placed it. In dungeons and raids the game hides your position, so it is a guess: the yards you have run out of combat since you placed it. That can warn a little early if you run back and forth.")
        self.toggle=FT:AccentButton(frame,"",472,34,"Spell_Nature_StoneSkinTotem"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.range=not s.range; self:Apply() end)
        FT:Tooltip(self.toggle,"Totem range on minimap","A circle on the minimap in each totem's element color, showing its 30-yard reach, so you can see when you're leaving it or need a new one. The spot is where you stood when you placed it. After Totemic Projection the circles hide until you place again, and in dungeons and raids the game hides your position, so nothing is drawn there.")
        self.colorButtons={}
        for i,e in ipairs(elements) do
            local key=e.key
            local b=FT:QuietButton(frame,e.label.." totem color",230,32,"fonts")
            b:SetPoint("TOPLEFT",24+((i-1)%2)*242,-106-math.floor((i-1)/2)*40)
            b.swatch=b:CreateTexture(nil,"ARTWORK"); b.swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); b.swatch:SetSize(16,16); b.swatch:SetPoint("RIGHT",-10,0)
            b:SetScript("OnClick",function() self:PickColor(key) end)
            FT:Tooltip(b,e.label.." totem color","The circle color for your "..e.label:lower().." totems.")
            self.colorButtons[key]=b
        end
        self.opacityLabel=FT:Label(frame,"",13); self.opacityLabel:SetPoint("TOPLEFT",24,-195)
        local slider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); slider:SetSize(240,18); slider:SetPoint("TOPLEFT",256,-192)
        slider:SetMinMaxValues(0,.9); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
        local low=slider.Low or (slider.GetName and slider:GetName() and _G[slider:GetName().."Low"])
        local high=slider.High or (slider.GetName and slider:GetName() and _G[slider:GetName().."High"])
        if low and low.SetText then low:SetText("Solid") end
        if high and high.SetText then high:SetText("See-through") end
        slider:SetScript("OnValueChanged",function(_,v) if self.settingSlider then return end; self:Settings().opacity=1-v; self:Paint(); self:Refresh() end)
        FT:Tooltip(slider,"Circle transparency","How see-through the circles are. Slide right for more see-through.")
        self.slider=slider
        self.leftToggle=FT:AccentButton(frame,"",472,34,"Spell_Fire_SearingTotem"); self.leftToggle:SetPoint("TOPLEFT",24,-236)
        self.leftToggle:SetScript("OnClick",function() local s=self:Settings(); s.leftBehind=not s.leftBehind; self:Apply() end)
        FT:Tooltip(self.leftToggle,"Left-behind warning","The totem's icon under your player frame pulses red when you are farther from the totem than the distance below, so you don't leave one behind to pull by accident. Right-click the icon to remove the totem. In dungeons and raids the distance is a guess (yards run out of combat since you placed it).")
        self.leftLabel=FT:Label(frame,"",13); self.leftLabel:SetPoint("TOPLEFT",24,-289)
        local range=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); range:SetSize(240,18); range:SetPoint("TOPLEFT",256,-286)
        range:SetMinMaxValues(20,60); range:SetValueStep(5); range:SetObeyStepOnDrag(true)
        local rlow=range.Low or (range.GetName and range:GetName() and _G[range:GetName().."Low"])
        local rhigh=range.High or (range.GetName and range:GetName() and _G[range:GetName().."High"])
        if rlow and rlow.SetText then rlow:SetText("20") end
        if rhigh and rhigh.SetText then rhigh:SetText("60") end
        range:SetScript("OnValueChanged",function(_,v)
            if self.settingSlider then return end
            self:Settings().leftRange=math.floor(v/5+.5)*5; self:Refresh()
        end)
        FT:Tooltip(range,"Warning distance","How far you can go from a totem before its icon starts to pulse. Buff totems reach 30 yards.")
        self.leftSlider=range
        self.note=FT:Label(frame,"",12); self.note:SetPoint("TOPLEFT",24,-326); self.note:SetWidth(472); self.note:SetTextColor(.66,.59,.48)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Totems",Totems)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Totems:Apply() end end)
