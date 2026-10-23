local _,FT=...
-- Diminishing returns (PvP, off by default). Crowd control of one kind
-- (stuns, roots, fears…) lasts shorter each time it lands on the same player,
-- until that player is immune; the count resets after a while.
--   * Only the game's own DR data is used (C_SpellDiminish and the event
--     UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED, Forever 1.60.1+). No
--     guessing from casts, so what is shown is exact. When the game does not
--     send the data, nothing is shown and the page says so.
--   * Some clients only send it while the game's own DR option is on: any
--     game setting with "Diminish" in its name that is off is switched on
--     while this is on, and put back when it is switched off.
--   * One small icon per kind of crowd control next to the target, focus and
--     (optionally) your own frame. The swipe counts down to the reset; a red
--     border means immune.
--   * The game may hide the details in a fight: hidden values go straight to
--     the icon (texture, swipe), are never compared, and a hidden kind of
--     crowd control is skipped.
local DR={states={},seen=0,hidden=0}
local ICON=24
local PVP_RULES=2
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function now() return GetTime and GetTime() or 0 end
-- Icons when the game gives none (Enum.SpellDiminishCategory order).
local FALLBACK={[0]="Spell_Frost_FrostNova",[1]="Spell_Nature_Reincarnation",[2]="Ability_Rogue_KidneyShot",[3]="Spell_Nature_Thorns",
    [4]="Ability_Sap",[5]="Spell_Shadow_Possession",[6]="Spell_Holy_Silence",[7]="Ability_Warrior_Disarm"}
local NAMES={[0]="Roots",[1]="Taunts",[2]="Stuns",[3]="Knockbacks",[4]="Incapacitates",[5]="Fears and disorients",[6]="Silences",[7]="Disarms"}
local UNITS={target="TargetFrame",focus="FocusFrame",player="PlayerFrame"}
local SIDES={right=true,left=true,above=true,below=true,free=true}
local SIDE_NAMES={right="Right of the frame",left="Left of the frame",above="Above the frame",below="Below the frame",free="Custom"}
local UNIT_NAMES={target="Target",focus="Focus",player="Yourself"}
function DR:Settings()
    if type(FT.db.diminish)~="table" then FT.db.diminish={} end
    local s=FT.db.diminish
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.target)~="boolean" then s.target=true end
    if type(s.focus)~="boolean" then s.focus=true end
    if type(s.self)~="boolean" then s.self=false end
    s.side=nil
    -- Where each row sits: a side of its frame, or where you dragged it.
    if type(s.places)~="table" then s.places={} end
    for unit in pairs(UNITS) do
        local p=s.places[unit]
        if type(p)~="table" then p={}; s.places[unit]=p end
        if not SIDES[p.side] then p.side="right" end
        if p.side=="free" and (type(p.x)~="number" or type(p.y)~="number") then p.side="right" end
        if p.side~="free" then p.x,p.y=nil,nil end
    end
    s.size=math.max(.7,math.min(1.6,tonumber(s.size) or 1))
    s.fontSize=math.max(6,math.min(16,math.floor(tonumber(s.fontSize) or 9)))
    if s.text~="on" and s.text~="below" and s.text~="none" then s.text="on" end
    return s
end
-- Does the game send DR data right now?
function DR:Supported()
    local api=C_SpellDiminish
    if not api or not api.IsSystemSupported then return false end
    local ok,on=pcall(api.IsSystemSupported)
    return ok and plain(on) and on==true
end
-- The game's own settings about diminishing returns (names vary by client).
function DR:GameSettings()
    if self.cvarNames then return self.cvarNames end
    local names={}
    local list=C_Console and C_Console.GetAllCommands and select(2,pcall(C_Console.GetAllCommands))
    if type(list)=="table" then
        for _,c in ipairs(list) do
            local name=type(c)=="table" and c.command
            if type(name)=="string" and name:lower():find("diminish",1,true) and (c.commandType==nil or c.commandType==0) then names[#names+1]=name end
        end
    end
    table.sort(names)
    self.cvarNames=names
    return names
end
local function getCVar(name)
    local f=(C_CVar and C_CVar.GetCVar) or GetCVar
    if not f then return end
    local ok,v=pcall(f,name); if ok and plain(v) then return v end
end
local function setCVar(name,value)
    local f=(C_CVar and C_CVar.SetCVar) or SetCVar
    if f then pcall(f,name,value) end
end
-- Switch the game's DR settings on while this is on; give them back after.
-- Stored for the account (not in profiles): it is the game's setting.
function DR:SyncGameSettings()
    if InCombatLockdown and InCombatLockdown() then self.syncLater=true; return end
    self.syncLater=nil
    FT.db.diminishCVars=type(FT.db.diminishCVars)=="table" and FT.db.diminishCVars or {}
    local saved=FT.db.diminishCVars
    if self:Settings().enabled then
        for _,name in ipairs(self:GameSettings()) do
            local v=getCVar(name)
            if v=="0" then saved[name]=v; setCVar(name,"1") end
        end
    else
        for name,v in pairs(saved) do if type(v)=="string" then setCVar(name,v) end end
        FT.db.diminishCVars={}
    end
end
-- Which kinds count in PvP (taunts don't).
function DR:Tracked(category)
    local api=C_SpellDiminish
    -- Only ask the game while it sends DR data: otherwise it says no to everything.
    if api and api.ShouldTrackSpellDiminishCategory and self:Supported() then
        local ok,yes=pcall(api.ShouldTrackSpellDiminishCategory,category,PVP_RULES)
        if ok and plain(yes) and type(yes)=="boolean" then return yes end
    end
    return category~=1
end
function DR:Texture(category)
    self.icons=self.icons or {}
    if self.icons[category]~=nil then return self.icons[category] end
    local icon
    local api=C_SpellDiminish
    if api and api.GetSpellDiminishCategoryInfo then
        local ok,info=pcall(api.GetSpellDiminishCategoryInfo,category)
        if ok and plain(info) and type(info)=="table" and plain(info.icon) and info.icon then icon=info.icon end
    end
    icon=icon or ("Interface\\Icons\\"..(FALLBACK[category] or "INV_Misc_QuestionMark"))
    self.icons[category]=icon
    return icon
end
-- Rows of icons ----------------------------------------------------------------
function DR:Row(unit)
    self.rows=self.rows or {}
    local row=self.rows[unit]
    if row then return row end
    row=CreateFrame("Frame",nil,UIParent); row:SetSize(ICON,ICON); row:SetFrameStrata("MEDIUM"); row:EnableMouse(false); FT:LockedMouse(row,true,"Diminish")
    row.icons={}; row.unit=unit
    -- While moving: a gold box with the unit's name; drag it anywhere.
    row.box=row:CreateTexture(nil,"BACKGROUND"); row.box:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.box:SetPoint("TOPLEFT",-3,3); row.box:SetPoint("BOTTOMRIGHT",3,-3); row.box:SetVertexColor(.85,.66,.25,.35); row.box:Hide()
    row.name=FT:Label(row,UNIT_NAMES[unit] or unit,11,true); row.name:SetPoint("BOTTOMLEFT",row,"TOPLEFT",0,4); row.name:SetTextColor(1,.82,0); row.name:Hide()
    row:SetMovable(true); row:SetClampedToScreen(true); row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart",function() if DR.moving then row:StartMoving() end end)
    row:SetScript("OnDragStop",function() row:StopMovingOrSizing(); DR:Dropped(row) end)
    self.rows[unit]=row
    return row
end
-- A dragged row keeps its spot next to its frame (it follows the frame).
function DR:Dropped(row)
    local frame=_G[UNITS[row.unit] or ""]
    local p=self:Settings().places[row.unit]
    local l,b=row:GetLeft(),row:GetBottom()
    if frame and l and b and frame:GetLeft() and frame:GetBottom() then
        local rs,fs=row:GetEffectiveScale(),frame:GetEffectiveScale()
        p.side="free"
        p.x=math.floor((l*rs-frame:GetLeft()*fs)/rs+.5); p.y=math.floor((b*rs-frame:GetBottom()*fs)/rs+.5)
    end
    row.place=nil; self:Paint(row.unit); self:Refresh()
end
function DR:SetMoving(on)
    self.moving=on and true or nil
    self:PaintAll()
    for _,row in pairs(self.rows or {}) do
        FT:LockedMouse(row,not self.moving,"Diminish"); row.box:SetShown(self.moving and true or false); row.name:SetShown(self.moving and true or false)
    end
    self:Refresh()
end
function DR:ResetPlaces()
    for _,p in pairs(self:Settings().places) do p.side="right"; p.x,p.y=nil,nil end
    for _,row in pairs(self.rows or {}) do row.place=nil end
    self:PaintAll(); self:Refresh()
end
function DR:Icon(row,i)
    local b=row.icons[i]
    if b then return b end
    b=CreateFrame("Frame",nil,row); b:SetSize(ICON,ICON); b:EnableMouse(false)
    b.border=b:CreateTexture(nil,"BACKGROUND"); b.border:SetTexture("Interface\\Buttons\\WHITE8x8"); b.border:SetAllPoints()
    b.tex=b:CreateTexture(nil,"ARTWORK"); b.tex:SetPoint("TOPLEFT",2,-2); b.tex:SetPoint("BOTTOMRIGHT",-2,2); b.tex:SetTexCoord(.08,.92,.08,.92)
    b.cd=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate"); b.cd:SetPoint("TOPLEFT",2,-2); b.cd:SetPoint("BOTTOMRIGHT",-2,2)
    if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
    if b.cd.SetReverse then b.cd:SetReverse(true) end
    b.text=(b.cd.GetCountdownFontString and b.cd:GetCountdownFontString()) or nil
    if not b.text then for _,r in ipairs({b.cd:GetRegions()}) do if r.GetObjectType and r:GetObjectType()=="FontString" then b.text=r; break end end end
    -- The swipe ending is the reset, also when the times are hidden.
    b.cd:SetScript("OnCooldownDone",function()
        local st=b.state
        if st and not st.preview and st.timed then st.done=true; DR:Paint(row.unit) end
    end)
    row.icons[i]=b
    return b
end
function DR:Anchor(row)
    local s=self:Settings(); local p=s.places[row.unit]
    local frame=_G[UNITS[row.unit] or ""]
    row:SetScale(s.size); row:ClearAllPoints()
    if not frame then row:SetPoint("CENTER",UIParent,"CENTER",0,row.unit=="player" and -120 or -60); return end
    if p.side=="free" then row:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",p.x,p.y)
    elseif p.side=="above" then row:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",8,2+(s.text=="below" and 10 or 0))
    elseif p.side=="below" then row:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",8,-2)
    elseif p.side=="left" then row:SetPoint("RIGHT",frame,"LEFT",-4,0)
    else row:SetPoint("LEFT",frame,"RIGHT",4,0) end
end
-- The swipe's numbers: size and place (on the icon, under it, or none).
function DR:FontObject()
    local s=self:Settings()
    self.fonts=self.fonts or {}
    local f=self.fonts[s.fontSize]
    if not f and CreateFont then
        f=CreateFont("ForeverToolsDRFont"..s.fontSize)
        local path=(FT.bodyFont) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        if f and f.SetFont then f:SetFont(path,s.fontSize,"OUTLINE") end
        self.fonts[s.fontSize]=f
    end
    return f
end
function DR:StyleText(b)
    local s=self:Settings()
    local look=s.text..s.fontSize
    if b.look==look then return end
    b.look=look
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(s.text=="none") end
    local font=self:FontObject()
    if font and b.cd.SetCountdownFont then pcall(b.cd.SetCountdownFont,b.cd,"ForeverToolsDRFont"..s.fontSize) end
    local t=b.text
    if t then
        local path=FT.bodyFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
        if t.SetFont then t:SetFont(path,s.fontSize,"OUTLINE") end
        t:ClearAllPoints()
        if s.text=="below" then t:SetPoint("TOP",b,"BOTTOM",0,-1) else t:SetPoint("CENTER",b,"CENTER",0,0) end
    end
end
local function unitShown(unit)
    local s=DR:Settings()
    if unit=="target" then return s.target elseif unit=="focus" then return s.focus elseif unit=="player" then return s.self end
end
-- Which saved states belong to a unit: by player id when readable,
-- otherwise by the unit itself.
function DR:Key(unit)
    if UnitGUID then
        local ok,guid=pcall(UnitGUID,unit)
        if ok and plain(guid) and type(guid)=="string" then return guid end
    end
    return unit
end
local ORDER={2,4,5,6,0,7,3,1}
DR.sample={{category=2,immune=false,preview=true},{category=5,immune=true,preview=true},{category=0,immune=false,preview=true}}
function DR:Paint(unit)
    local row=self.rows and self.rows[unit]
    local s=self:Settings()
    local list={}
    if (self.previewOn or self.peeking or self.moving) and unitShown(unit) then
        list=self.sample
    elseif s.enabled and unitShown(unit) then
        local states=self.states[self:Key(unit)]
        if states then
            local t=now()
            for _,cat in ipairs(ORDER) do
                local st=states[cat]
                if st and (st.done or (st.expires and t>=st.expires)) then states[cat]=nil; st=nil end
                if st then list[#list+1]=st end
            end
        end
    end
    if #list==0 and not row then return end
    row=row or self:Row(unit)
    local p=s.places[unit]
    local place=p.side..(p.x or "")..(p.y or "")..s.size..s.text
    if row.place~=place then row.place=place; self:Anchor(row) end
    for i,st in ipairs(list) do
        local b=self:Icon(row,i); b.state=st
        b:ClearAllPoints(); b:SetPoint("LEFT",row,"LEFT",(i-1)*(ICON+3),0)
        b.tex:SetTexture(self:Texture(st.category)); self:StyleText(b)
        -- Red when immune, gold while the next one still lands (shorter).
        if st.own then
            -- After one: next lasts half (yellow); after two: a quarter (orange); then immune (red).
            local c=st.count or 1
            if c>=3 then b.border:SetVertexColor(.9,.12,.1,1) elseif c==2 then b.border:SetVertexColor(1,.5,.1,1) else b.border:SetVertexColor(.95,.85,.2,1) end
            b.tex:SetAlpha(st.guess and .7 or 1)
        elseif st.preview or plain(st.immune) then
            b.tex:SetAlpha(1)
            if st.immune then b.border:SetVertexColor(.9,.12,.1,1) else b.border:SetVertexColor(.95,.75,.2,1) end
        elseif b.border.SetVertexColorFromBoolean then
            pcall(b.border.SetVertexColorFromBoolean,b.border,st.immune,CreateColor and CreateColor(.9,.12,.1,1),CreateColor and CreateColor(.95,.75,.2,1))
        end
        local stamp=st.timed and st.start or false
        if b.cdFor~=st or b.cdStamp~=stamp then
            b.cdFor=st; b.cdStamp=stamp
            if st.preview then b.cd:SetCooldown(now(),18)
            elseif st.timed then b.cd:SetCooldown(st.start,st.duration)
            else b.cd:Clear() end
        end
        b:Show()
    end
    for i=#list+1,#row.icons do local b=row.icons[i]; b.state=nil; b.cdFor=nil; b:Hide() end
    row:SetWidth(math.max(ICON,#list*(ICON+3)-3))
    local frame=_G[UNITS[unit] or ""]
    row:SetShown(#list>0 and (self.previewOn or self.peeking or self.moving or not frame or frame:IsVisible()))
    self:Watch()
end
function DR:PaintAll()
    for unit in pairs(UNITS) do self:Paint(unit) end
end
-- One light timer while icons are up, to drop the ones that reset.
function DR:Watch()
    local any=false
    for _,row in pairs(self.rows or {}) do if row:IsShown() then any=true end end
    self.driver=self.driver or CreateFrame("Frame")
    if any and not self.driver.on then
        self.driver.on=true; self.driver.wait=0
        self.driver:SetScript("OnUpdate",function(f,dt)
            f.wait=f.wait+dt; if f.wait<.5 then return end; f.wait=0
            local a=DR:Tick(); local b=DR:Prune(); if a or b then DR:PaintAll() end
        end)
    elseif not any and self.driver.on then
        self.driver.on=nil; self.driver:SetScript("OnUpdate",nil)
    end
end
-- Forget players nobody has hit for a while.
function DR:Prune()
    local t=now(); local changed=false
    for key,states in pairs(self.states) do
        local left=false
        for cat,st in pairs(states) do
            if st.done or (st.expires and t>=st.expires) then states[cat]=nil; changed=true else left=true end
        end
        if not left then self.states[key]=nil end
    end
    return changed
end
-- The game's DR update for a unit.
function DR:Update(unit,info)
    self.seen=self.seen+1
    if not plain(unit) or type(unit)~="string" then return end
    if not plain(info) or type(info)~="table" then self.hidden=self.hidden+1; return end
    local cat=info.category
    if not plain(cat) or type(cat)~="number" then self.hidden=self.hidden+1; return end
    if not self:Tracked(cat) then return end
    local key=self:Key(unit)
    local states=self.states[key] or {}; self.states[key]=states
    local start,duration,countdown,immune=info.startTime,info.duration,info.showCountdown,info.isImmune
    local st={category=cat,immune=immune}
    local t=now()
    if plain(start) and plain(duration) and plain(countdown) then
        if type(duration)=="number" and duration<=0 and countdown then states[cat]=nil; self:Paint(unit); return end
        if countdown and type(start)=="number" and type(duration)=="number" then
            st.timed=true; st.start=start; st.duration=duration; st.expires=start+duration
        else
            -- Still under the crowd control: the reset clock starts when it ends.
            st.expires=t+60
        end
    else
        -- Hidden times go straight to the swipe; its end clears the icon.
        st.timed=true; st.start=start; st.duration=duration; st.expires=t+60
    end
    states[cat]=st
    for shown in pairs(UNITS) do
        if shown==unit or (key~=unit and self:Key(shown)==key) then self:Paint(shown) end
    end
end
-- Settings ---------------------------------------------------------------------
function DR:Apply()
    local s=self:Settings()
    self:SyncGameSettings()
    if not s.enabled then self.states={}; self.auraSeen={} end
    self:Listen()
    self:PaintAll()
    self:Refresh()
end
function DR:SetPreview(on)
    self.previewOn=on and true or nil
    self:PaintAll(); self:Refresh()
end
-- A setting changed while nothing shows: example icons for a few seconds.
function DR:Peek()
    if self.previewOn then return end
    self.peeking=(self.peeking or 0)+1
    local mine=self.peeking
    self:PaintAll()
    C_Timer.After(4,function() if self.peeking==mine then self.peeking=nil; self:PaintAll() end end)
end
-- Tracking by ourselves (when the game sends no DR data) -----------------------
-- Like other DR addons: crowd control seen as a debuff on an enemy (target,
-- focus, nameplates) or on you, plus your and your pet's own casts. Each kind
-- counts up (next one 50%, then 25%, then immune) and resets 18.5 seconds
-- after the last one ended. Casts nobody saw land are a guess.
local RESET=18.5
local GUESS={[2]=4,[4]=6,[5]=6,[0]=6,[6]=3,[7]=6}
-- {kind, English name, a spell id for the local name, cast=it can be a cast}
local CC={
    {2,"Cheap Shot",1833,true},{2,"Kidney Shot",408,true},{2,"Hammer of Justice",853,true},{2,"Bash",5211,true},{2,"Pounce",9005,true},
    {2,"Intercept Stun",20253},{2,"Concussion Blow",12809,true},{2,"War Stomp",20549,true},{2,"Intimidation",24394,true},{2,"Charge Stun",7922},
    {2,"Impact",12355},{2,"Mace Stun Effect",5530},{2,"Starfire Stun",16922},{2,"Revenge Stun",12798},{2,"Blackout",15269},
    {4,"Gouge",1776,true},{4,"Sap",6770,true},{4,"Polymorph",118,true},{4,"Repentance",20066,true},{4,"Freezing Trap Effect",3355},
    {4,"Hibernate",2637,true},{4,"Wyvern Sting",19386,true},
    {5,"Fear",5782,true},{5,"Psychic Scream",8122,true},{5,"Howl of Terror",5484,true},{5,"Intimidating Shout",5246,true},{5,"Seduction",6358,true},
    {5,"Scare Beast",1513,true},{5,"Death Coil",6789,true},{5,"Scatter Shot",19503,true},
    {0,"Frost Nova",122,true},{0,"Entangling Roots",339,true},{0,"Frostbite",12494},{0,"Improved Hamstring",23694},
    {6,"Silence",15487,true},{6,"Counterspell - Silenced",18469},{6,"Kick - Silenced",18425},{6,"Spell Lock",24259,true},{6,"Shield Bash - Silenced",18498},
    {7,"Disarm",676,true},{7,"Riposte",14251},
}
local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok,n=pcall(C_Spell.GetSpellName,id); if ok and plain(n) and type(n)=="string" then return n end end
    if GetSpellInfo then local ok,n=pcall(GetSpellInfo,id); if ok and plain(n) and type(n)=="string" then return n end end
end
function DR:Lists()
    if self.byName then return self.byName,self.byCast end
    local byName,byCast={},{}
    for _,e in ipairs(CC) do
        for _,name in ipairs({e[2],spellName(e[3])}) do
            byName[name]=e[1]; if e[4] then byCast[name]=e[1] end
        end
    end
    self.byName,self.byCast=byName,byCast
    return byName,byCast
end
local function kindOf(list,spellID,name)
    if plain(name) and type(name)=="string" and list[name] then return list[name] end
    if plain(spellID) and type(spellID)=="number" then local n=spellName(spellID); if n and list[n] then return list[n] end end
end
-- Which units we read: target, focus, you, and enemy nameplates.
local function watched(unit)
    return unit=="target" or unit=="focus" or unit=="player" or (type(unit)=="string" and unit:find("^nameplate%d") ~= nil) or (type(unit)=="string" and unit:find("^arena%d")~=nil)
end
local function enemyPlayer(unit)
    if unit=="player" then return true end
    if UnitIsPlayer then local ok,v=pcall(UnitIsPlayer,unit); if ok and plain(v) and v==false then return false end end
    if UnitCanAttack then local ok,v=pcall(UnitCanAttack,"player",unit); if ok and plain(v) and v==false then return false end end
    return true
end
-- A kind of crowd control landed on someone.
function DR:Applied(key,cat,ends,guess)
    if not self:Tracked(cat) then return end
    local states=self.states[key] or {}; self.states[key]=states
    local st=states[cat]; local t=now()
    if st and st.own and st.landed and t-st.landed<1 and (st.guess or guess) then
        -- The same one seen twice (cast and debuff): keep the better one.
        if not guess then st.guess=nil; st.ends=ends; st.active=true end
        return
    end
    local count=(st and st.own and (not st.expires or t<st.expires)) and (st.count or 0)+1 or 1
    st={category=cat,own=true,count=count,landed=t,active=true,guess=guess,ends=ends,immune=count>=3}
    -- Until it ends the reset clock waits; a safety end if we never see it go.
    st.expires=(ends or t+(GUESS[cat] or 6))+RESET
    st.timed=false
    states[cat]=st
end
-- The crowd control ended: the reset clock starts now.
function DR:Ended(key,cat)
    local st=self.states[key] and self.states[key][cat]
    if not st or not st.own or not st.active then return end
    local t=now()
    st.active=false; st.timed=true; st.start=t; st.duration=RESET; st.expires=t+RESET
end
function DR:Tick()
    -- Guessed or unseen endings: start the reset clock when the CC should be over.
    local t=now(); local changed=false
    for _,states in pairs(self.states) do
        for _,st in pairs(states) do
            if st.own and st.active then
                local ends=st.ends or (st.landed+(GUESS[st.category] or 6))
                if t>=ends then st.active=false; st.timed=true; st.start=ends; st.duration=RESET; st.expires=ends+RESET; changed=true end
            end
        end
    end
    return changed
end
-- Debuffs on a unit: what is new, what is gone.
function DR:ScanAuras(unit)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
    if not enemyPlayer(unit) then return end
    local key=self:Key(unit)
    if key==unit and unit~="target" and unit~="focus" then return end -- no id: only target/focus by token
    local byName=self:Lists()
    self.auraSeen=self.auraSeen or {}
    local seen=self.auraSeen[key] or {}; self.auraSeen[key]=seen
    local now_={}
    for i=1,40 do
        local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,unit,i,"HARMFUL")
        if not ok or not a then break end
        if plain(a) and type(a)=="table" then
            local cat=kindOf(byName,a.spellId,a.name)
            if cat then
                self.last=(NAMES[cat] or "CC").." debuff seen on "..unit
                local id=a.auraInstanceID
                local ends=a.expirationTime
                if not (plain(ends) and type(ends)=="number" and ends>0) then ends=nil end
                local tag=(plain(id) and id) or cat
                now_[tag]=cat
                if not seen[tag] then self:Applied(key,cat,ends) end
            end
        end
    end
    for tag,cat in pairs(seen) do if not now_[tag] then self:Ended(key,cat) end end
    self.auraSeen[key]=now_
    self:PaintKey(key,unit)
end
function DR:PaintKey(key,unit)
    for shown in pairs(UNITS) do
        if shown==unit or (key~=unit and self:Key(shown)==key) then self:Paint(shown) end
    end
end
-- Your or your pet's cast of a crowd control: counts on the target unless a
-- debuff shows up for it.
function DR:Cast(caster,spellID)
    local _,byCast=self:Lists()
    local cat=kindOf(byCast,spellID,nil)
    if not cat then return end
    local unit=caster=="pet" and "pettarget" or "target"
    local name=NAMES[cat] or "CC"
    if UnitExists then local ok,e=pcall(UnitExists,unit); if not ok or not plain(e) or not e then self.last=name.." cast: no target"; return end end
    if not enemyPlayer(unit) then self.last=name.." cast: target is not an enemy player"; return end
    self.last=name.." cast on an enemy player"
    local key=self:Key(unit)
    C_Timer.After(.4,function()
        local st=self.states[key] and self.states[key][cat]
        if st and st.own and now()-(st.landed or 0)<1 then return end -- the debuff was seen
        self:Applied(key,cat,nil,true); self:PaintKey(key,unit=="pettarget" and "target" or unit)
    end)
end
function DR:StatusText()
    if self:Supported() then return "Uses the game's own DR data." end
    return "Tracked from debuffs you can see and your own casts. Unseen casts are a guess."
end
-- /ft dr: what the game offers, for bug reports.
function DR:Diagnose()
    local api=C_SpellDiminish
    local parts={"DR: system "..(api and (self:Supported() and "on" or "off") or "missing")}
    local names=self:GameSettings()
    if #names==0 then parts[#parts+1]="no DR game settings" end
    for _,name in ipairs(names) do parts[#parts+1]=name.."="..tostring(getCVar(name)) end
    parts[#parts+1]="updates "..self.seen..", hidden "..self.hidden
    parts[#parts+1]="tracking "..(self.listening and "on" or "off")..", last: "..(self.last or "nothing yet")
    local st=self:Settings()
    parts[#parts+1]="shown on: target "..(st.target and "on" or "off")..", focus "..(st.focus and "on" or "off")..", yourself "..(st.self and "on" or "off")
    local mine=self.states[self:Key("player")]; local n=0; if mine then for _ in pairs(mine) do n=n+1 end end
    parts[#parts+1]="on you now: "..n.." kind(s)"
    print("ForeverTools "..table.concat(parts,"\n  "))
end
function DR:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Diminishing returns: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.targetRow.label:SetText("Target: "..(s.target and "On" or "Off")); FT:SetSelected(self.targetRow,s.target)
    self.focusRow.label:SetText("Focus: "..(s.focus and "On" or "Off")); FT:SetSelected(self.focusRow,s.focus)
    self.selfRow.label:SetText("Yourself: "..(s.self and "On" or "Off")); FT:SetSelected(self.selfRow,s.self)
    for unit,b in pairs(self.placeRows) do b.label:SetText(UNIT_NAMES[unit]..": "..SIDE_NAMES[s.places[unit].side]) end
    self.textRow.label:SetText("Timer: "..({on="On the icon",below="Below the icon",none="Hidden"})[s.text])
    self.sizeLabel:SetText(string.format("Icon size: %d%%",math.floor(s.size*100+.5)))
    self.fontLabel:SetText(string.format("Timer size: %d",s.fontSize))
    self.settingSize=true; self.sizeSlider:SetValue(s.size); self.fontSlider:SetValue(s.fontSize); self.settingSize=false
    FT:RefreshPreview(self.frame)
    self.status:SetText(self:StatusText())
    if self:Supported() then self.status:SetTextColor(.55,.8,.45) else self.status:SetTextColor(.66,.59,.48) end
end
function DR:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsDiminish","Diminishing returns",540,560); self.frame=frame
        FT:PageInfo(frame,"Diminishing returns","Crowd control of one kind lasts shorter each time it hits the same player, then they are immune for a while.\n\nAn icon per kind shows next to the frame. The timer counts down to the reset. Gold: the next one still lands, shorter. Red: immune.\n\nUses only the game's own DR data, so it is exact.")
        local hint=FT:Label(frame,"Shows when crowd control will be shorter or won't land.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,"Spell_Frost_FrostNova"); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Diminishing returns","Icons for crowd control that will be shorter, or won't land. Turns on the game's own DR data if needed.")
        self.previewButton=FT:TopPreview(frame,self.toggle,{get=function() return (self.previewOn or self.moving) and true or false end,
            set=function(on) self:SetPreview(on); self:SetMoving(on) end,tip="Each row follows its frame."})
        local function switch(key,x,y,title,tip)
            local b=FT:QuietButton(frame,"",240,32,"Spell_Frost_FrostNova"); b:SetPoint("TOPLEFT",x,y)
            b:SetScript("OnClick",function() local s=self:Settings(); s[key]=not s[key]; self:PaintAll(); self:Refresh() end)
            FT:Tooltip(b,title,tip)
            return b
        end
        self.targetRow=switch("target",24,-136,"Target","Icons by your target's frame.")
        self.focusRow=switch("focus",276,-136,"Focus","Icons by your focus's frame.")
        self.selfRow=switch("self",24,-176,"Yourself","Your own DR, by your frame.")
        -- Place: each row on its own side, or dragged anywhere.
        self.placeRows={}
        local sides={{"right","Right of the frame"},{"left","Left of the frame"},{"above","Above the frame"},{"below","Below the frame"}}
        for i,unit in ipairs({"target","focus","player"}) do
            local b=FT:QuietButton(frame,"",240,32,"move"); b:SetPoint("TOPLEFT",i==2 and 276 or 24,i==3 and -256 or -216)
            FT:MakeChoice(b,sides,function() return self:Settings().places[unit].side end,function(v) local p=self:Settings().places[unit]; p.side=v; p.x,p.y=nil,nil; self:Peek(); self:PaintAll(); self:Refresh() end)
            FT:Tooltip(b,UNIT_NAMES[unit],"Where these icons sit. Or turn on Preview and drag them anywhere.")
            self.placeRows[unit]=b
        end
        local reset=FT:QuietButton(frame,"Reset positions",240,32,"reset"); reset:SetPoint("TOPLEFT",276,-256)
        reset:SetScript("OnClick",function() self:ResetPlaces() end)
        FT:Tooltip(reset,"Reset positions","All rows back to the right of their frame.")
        local function slider(y,label,lo,hi,step,tip,set)
            local l=FT:Label(frame,"",14); l:SetPoint("TOPLEFT",24,y)
            local sl=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); sl:SetSize(320,18); sl:SetPoint("TOPLEFT",196,y+2)
            sl:SetMinMaxValues(lo,hi); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
            sl:SetScript("OnValueChanged",function(_,v) if self.settingSize then return end; set(v); self:Peek(); self:PaintAll(); self:Refresh() end)
            FT:Tooltip(sl,label,tip)
            return l,sl
        end
        self.sizeLabel,self.sizeSlider=slider(-302,"Icon size",.7,1.6,.05,"70% to 160%.",function(v) self:Settings().size=math.floor(v*20+.5)/20 end)
        self.fontLabel,self.fontSlider=slider(-336,"Timer size",6,16,1,"Size of the countdown numbers.",function(v) self:Settings().fontSize=math.floor(v+.5); for _,row in pairs(self.rows or {}) do for _,b in ipairs(row.icons) do b.look=nil end end end)
        self.textRow=FT:QuietButton(frame,"",240,32,"fonts"); self.textRow:SetPoint("TOPLEFT",24,-366)
        FT:MakeChoice(self.textRow,{{"on","On the icon"},{"below","Below the icon"},{"none","Hidden"}},function() return self:Settings().text end,function(v) self:Settings().text=v; for _,row in pairs(self.rows or {}) do row.place=nil; for _,b in ipairs(row.icons) do b.look=nil end end; self:Peek(); self:PaintAll(); self:Refresh() end)
        FT:Tooltip(self.textRow,"Timer","Where the countdown to the reset shows.")
        self.status=FT:Label(frame,"",12); self.status:SetPoint("TOPLEFT",24,-408); self.status:SetWidth(492)
        if self.status.SetWordWrap then self.status:SetWordWrap(true) end
        FT:Sections(frame,{{"Show on",self.targetRow},{"Place",self.placeRows.target},{"Look",self.sizeLabel}})
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Diminish",DR)
FT.Diminish=DR
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED"}) do pcall(events.RegisterEvent,events,event) end
-- Our own tracking listens only while the feature is on.
local tracking=CreateFrame("Frame")
function DR:Listen()
    local on=self:Settings().enabled and not self:Supported()
    if on==self.listening then return end
    self.listening=on
    for _,event in ipairs({"UNIT_AURA","UNIT_SPELLCAST_SUCCEEDED","NAME_PLATE_UNIT_ADDED"}) do
        if on then pcall(tracking.RegisterEvent,tracking,event) else pcall(tracking.UnregisterEvent,tracking,event) end
    end
end
-- Most aura updates are not crowd control: skip them without a scan.
function DR:Worth(unit,info)
    if not plain(info) or type(info)~="table" then return true end
    local full=info.isFullUpdate
    if not plain(full) or full then return true end
    local byName=self:Lists()
    local added=info.addedAuras
    if plain(added) and type(added)=="table" then
        for _,a in ipairs(added) do
            if not plain(a) or type(a)~="table" or not plain(a.name) then return true end
            local harmful=a.isHarmful
            if not plain(harmful) then return true end
            if harmful~=false and kindOf(byName,a.spellId,a.name) then return true end
        end
    end
    local removed=info.removedAuraInstanceIDs
    if plain(removed) and type(removed)=="table" and #removed>0 then
        local seen=self.auraSeen and self.auraSeen[self:Key(unit)]
        if seen then for _,id in ipairs(removed) do if not plain(id) or seen[id] then return true end end end
    end
    return false
end
tracking:SetScript("OnEvent",function(_,event,unit,info,spellID)
    if not plain(unit) or type(unit)~="string" then return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if unit=="player" or unit=="pet" then DR:Cast(unit,spellID) end
    elseif watched(unit) then
        if unit=="player" and not DR:Settings().self then return end
        if event=="UNIT_AURA" and not DR:Worth(unit,info) then return end
        DR:ScanAuras(unit)
    end
end)
events:SetScript("OnEvent",function(_,event,unit,info)
    if not FT.dbReady then return end
    if event=="UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED" then
        if DR:Settings().enabled then DR:Update(unit,info) end
    elseif event=="PLAYER_TARGET_CHANGED" then if DR.listening then DR:ScanAuras("target") end; DR:Paint("target")
    elseif event=="PLAYER_FOCUS_CHANGED" then if DR.listening then DR:ScanAuras("focus") end; DR:Paint("focus")
    elseif event=="PLAYER_REGEN_ENABLED" then if DR.syncLater then DR:SyncGameSettings() end
    elseif event=="PLAYER_LOGIN" then
        local saved=type(FT.db.diminishCVars)=="table" and next(FT.db.diminishCVars)
        if DR:Settings().enabled or saved then DR:SyncGameSettings() end
        DR:Listen()
    elseif event=="PLAYER_ENTERING_WORLD" then DR.states={}; DR:PaintAll()
    end
end)
