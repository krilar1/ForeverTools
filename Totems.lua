local _,FT=...
-- Totems (shamans; off by default). For now one feature: a soft circle on
-- the minimap for each totem you place, showing its 30-yard reach, so you
-- can see when you're about to leave it or need a new one. More totem
-- tools will live on this page later.
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
function Totems:MatchCast(name,slot)
    local now=GetTime(); local lower=type(name)=="string" and name:lower() or ""
    local fallback
    for i,c in ipairs(self.casts) do
        -- Hidden details: only a cast known to be for this element counts.
        if slot then
            if not c.used and now-c.time<3 and slotOf(c.name)==slot then c.used=true; return c end
        elseif not c.used and now-c.time<3 then
            if lower~="" and (lower:find(c.name,1,true) or c.name:find(lower,1,true)) then c.used=true; return c end
            fallback=fallback or c
        end
    end
    if slot then return end
    if fallback then fallback.used=true end
    return fallback
end
function Totems:Update(slot,noDraw,changed)
    if type(slot)~="number" or slot<1 or slot>4 then return end
    local have,name,start,duration=safe(GetTotemInfo,slot)
    if secret(have) or secret(start) or secret(duration) or secret(name) then
        -- In combat the game can hide totem details. Keep what we drew, and
        -- place a totem you just cast by its element (known from its name).
        local cast=self:MatchCast(nil,slot)
        if cast and cast.continent then self.placed[slot]={continent=cast.continent,x=cast.x,y=cast.y,name=cast.name,hidden=true}
        elseif changed then
            -- The game says this slot changed and you didn't just cast a totem
            -- for it: it was clicked away, destroyed or ran out.
            self.placed[slot]=nil
        end
    elseif have and type(start)=="number" and type(duration)=="number" and duration>0 and type(name)=="string" and name~="" then
        local old=self.placed[slot]
        -- Placed while the game hid the details: now we can read them, keep
        -- the spot if it's the same totem.
        if old and old.hidden and type(old.name)=="string" and name:lower():find(old.name,1,true) then old.start,old.name,old.hidden=start,name,nil; old=self.placed[slot] end
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
    else self.placed[slot]=nil end
    if noDraw then return end
    local layer=self:Layer(); if layer then self:Paint(); layer:Show(); self:Draw() end
end
-- All four slots at once: the event's slot number isn't always the one that
-- changed (replacing a totem can report only the old one).
function Totems:Scan(changed)
    if secret(changed) then changed=nil end
    for slot=1,4 do self:Update(slot,true,slot==changed) end
    local layer=self:Layer(); if layer then self:Paint(); layer:Show(); self:Draw() end
end
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event,a,_,spellID)
    if event=="PLAYER_TOTEM_UPDATE" then Totems:Scan(a)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        if secret(spellID) or type(spellID)~="number" then return end
        local name=C_Spell and C_Spell.GetSpellName and safe(C_Spell.GetSpellName,spellID) or (GetSpellInfo and safe(GetSpellInfo,spellID))
        if type(name)~="string" or secret(name) then return end
        -- Totemic Projection moves your totems to a spot we can't see.
        if name:lower()=="totemic projection" then
            Totems.placed={}; if Totems.layer then Totems:Draw() end
        elseif isTotemSpell(name) then Totems:NoteCast(name) end
    elseif event=="PLAYER_ENTERING_WORLD" then
        -- A new zone or loading screen: earlier spots may be on another map.
        Totems:Scan()
    end
end)
function Totems:Apply()
    if not FT.dbReady then return end
    if self:Settings().range and isShaman() then
        events:RegisterEvent("PLAYER_TOTEM_UPDATE"); events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
        self:Paint()
    else
        events:UnregisterAllEvents(); self.placed={}
        if self.layer then self.layer:Hide() end
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
        local frame=FT:Window("ForeverToolsTotems","Totems",520,284); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        FT:PageInfo(frame,"Totems","Tools for shamans' totems. More are on the way.")
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
        self.note=FT:Label(frame,"",12); self.note:SetPoint("TOPLEFT",24,-236); self.note:SetWidth(472); self.note:SetTextColor(.66,.59,.48)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Totems",Totems)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Totems:Apply() end end)
