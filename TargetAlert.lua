local _,FT=...
-- Targeted alert (PvP, off by default; PvP > Targeted alert). A small box
-- when an enemy player near you has you as their target: how many, and
-- who (class colored). Gone the moment nobody targets you any more.
--   * Near = their nameplate is on screen (the game shows nameplates up to
--     its nameplate distance), or they are your target, focus or mouseover.
--     Enemy nameplates must be on (V) to see players you don't target.
--   * Enemy = a player of the other faction you can attack. Duels and
--     your own faction are left out.
--   * Works in combat: a plain frame of ours, nothing protected.
--   * Costs nothing until it is on; then it follows the game's "target
--     changed" events for the units it watches, with a light check four
--     times a second only while enemy players are near.
local A={plates={},found={},names={},order={}}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local COLORS={red={1,.22,.18},orange={1,.55,.1},yellow={1,.85,.15},white={1,1,1}}
local COLOR_LIST={{"red","Red"},{"orange","Orange"},{"yellow","Yellow"},{"white","White"}}
local WHERE_LIST={{"world","Open world","Not in battlegrounds or arenas, where everyone targets you."},{"all","Everywhere","Battlegrounds and arenas too."}}
local AGAIN_LIST={{0,"Every time","Sound and flash each time they target you again."},{10,"10 seconds"},{30,"30 seconds"},{60,"1 minute"},{120,"2 minutes"},{300,"5 minutes"}}
-- The box stays this long after the last one stops (hovering someone and
-- moving the mouse away no longer makes it blink).
local HOLD=3
local NAMES=3
function A:Settings()
    if type(FT.db.targetAlert)~="table" then FT.db.targetAlert={} end
    local s=FT.db.targetAlert
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.sound)~="boolean" then s.sound=true end
    if type(s.names)~="boolean" then s.names=true end
    if type(s.background)~="boolean" then s.background=true end
    if type(s.flash)~="boolean" then s.flash=true end
    if not COLORS[s.color] then s.color="red" end
    if s.where~="world" and s.where~="all" then s.where="world" end
    s.again=tonumber(s.again) or 30
    s.size=math.max(.6,math.min(2,tonumber(s.size) or 1))
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    return s
end
-- Where we are counts: the open world, unless "Everywhere".
function A:Here()
    if self:Settings().where=="all" or not IsInInstance then return true end
    local ok,inside,kind=pcall(IsInInstance)
    if ok and plain(inside) and inside and plain(kind) and (kind=="pvp" or kind=="arena") then return false end
    return true
end
local function myFaction()
    local f=UnitFactionGroup and UnitFactionGroup("player")
    return text(f)
end
-- An enemy player of the other faction (nil when unknown or hidden).
function A:Enemy(unit)
    if not UnitExists or not UnitExists(unit) then return false end
    local ok,isPlayer=pcall(UnitIsPlayer,unit)
    if not ok or not plain(isPlayer) or not isPlayer then return false end
    local okA,attack=pcall(UnitCanAttack,"player",unit)
    if not okA or not plain(attack) or not attack then return false end
    local theirs=text(UnitFactionGroup and UnitFactionGroup(unit))
    local mine=myFaction()
    if theirs and mine and theirs==mine then return false end
    if theirs and theirs~="Alliance" and theirs~="Horde" then return false end
    return true
end
-- Does this unit have you as its target?
function A:TargetsMe(unit)
    local target=unit.."target"
    if not UnitExists or not UnitExists(target) then return false end
    local ok,same=pcall(UnitIsUnit,target,"player")
    if ok and plain(same) then return same and true or false end
    -- Hidden in a fight: compare who it is instead.
    local okG,g=pcall(UnitGUID,target); local me=UnitGUID and UnitGUID("player")
    if okG and plain(g) and type(g)=="string" then return g==me end
    return false
end
-- Who targets you right now: fills self.found (name -> class) and
-- self.order (names in the order seen). No new tables per check.
local WATCH={"target","focus","mouseover"}
function A:Collect()
    local found,order=self.found,self.order
    for k in pairs(found) do found[k]=nil end
    for i=#order,1,-1 do order[i]=nil end
    local function look(unit)
        if not self:Enemy(unit) or not self:TargetsMe(unit) then return end
        local okN,name=pcall(UnitName,unit); name=okN and text(name)
        if not name or found[name] then return end
        local _,class=UnitClass(unit)
        found[name]=text(class) or "?"; order[#order+1]=name
    end
    for unit in pairs(self.plates) do look(unit) end
    for _,unit in ipairs(WATCH) do look(unit) end
    return #order
end
function A:Check()
    local s=self:Settings()
    if not s.enabled or self.preview then return end
    local count=0
    if self:Here() then count=self:Collect() end
    self.count=count
    local t=GetTime and GetTime() or 0
    -- Sound and flash only for a player who hasn't targeted you in the last
    -- "Warn again after" (the time counts from when they last did).
    self.alerted=self.alerted or {}
    local alerted,new=self.alerted,false
    for _,name in ipairs(self.order) do
        local last=alerted[name]
        if not last or t-last>s.again then new=true end
        alerted[name]=t
    end
    if count>0 then
        self.holdUntil=t+HOLD
        self:Show(self.order,self.found)
        if new then
            if s.sound and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound,SOUNDKIT.RAID_WARNING,"Master") end
            if s.flash then self.flashUntil=t+.6 end
        end
    elseif self.box and self.box:IsShown() and not self.moving then
        local left=(self.holdUntil or 0)-t
        if left>0 then
            if C_Timer and not self.holdTimer then
                self.holdTimer=true
                C_Timer.After(left+.05,function() self.holdTimer=nil; self:Check() end)
            end
        else
            self.box:Hide()
        end
    end
    -- Forget old names now and then (a city full of players).
    if t-(self.swept or 0)>60 then
        self.swept=t
        for name,last in pairs(alerted) do if t-last>math.max(300,s.again) then alerted[name]=nil end end
    end
end
-- The box ----------------------------------------------------------------
local ICON="Interface\\Icons\\Ability_Hunter_SniperShot"
function A:Box()
    if self.box then return self.box end
    local f=CreateFrame("Frame","ForeverToolsTargetedAlert",UIParent)
    self.box=f
    f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true); f:SetSize(150,30)
    FT:Panel(f)
    f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetSize(20,20); f.icon:SetPoint("LEFT",6,0)
    f.icon:SetTexture(ICON); f.icon:SetTexCoord(.07,.93,.07,.93)
    if FT.RoundIcon then FT:RoundIcon(f.icon) end
    f.title=FT:Label(f,"",13,true); f.title:SetPoint("TOPLEFT",f.icon,"TOPRIGHT",7,1); f.title:SetJustifyH("LEFT")
    f.title:SetShadowColor(0,0,0,1); f.title:SetShadowOffset(1,-1)
    f.who=FT:Label(f,"",11); f.who:SetPoint("TOPLEFT",f.title,"BOTTOMLEFT",0,-1); f.who:SetJustifyH("LEFT")
    f.who:SetShadowColor(0,0,0,1); f.who:SetShadowOffset(1,-1)
    if f.who.SetWordWrap then f.who:SetWordWrap(false) end
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); FT:LockedMouse(f,true,"TargetAlert")
    f:SetScript("OnDragStart",function() if self.moving and not InCombatLockdown() then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local s=self:Settings()
        if x and y then local scale=f:GetScale(); s.x,s.y=x*scale,y*scale end
        self:Position()
    end)
    -- A short flash of the border when someone new targets you.
    f:SetScript("OnUpdate",function()
        local untilT=self.flashUntil
        if not untilT then return end
        local t=GetTime and GetTime() or 0
        local r,g,b=self:Color()
        if t>=untilT then self.flashUntil=nil; self:Paint(); return end
        local glow=.35+.65*math.abs(math.sin((untilT-t)*12))
        for _,texture in ipairs(f.borderTextures) do texture:SetVertexColor(r,g,b,glow) end
    end)
    f:Hide()
    return f
end
function A:Color() local c=COLORS[self:Settings().color] or COLORS.red; return c[1],c[2],c[3] end
function A:Paint()
    local f=self:Box(); local s=self:Settings()
    local r,g,b=self:Color()
    FT:Paint(f,s.background and {.05,.035,.02,.88} or {0,0,0,0},{r,g,b,s.background and .9 or 0})
    f.title:SetTextColor(r,g,b)
end
function A:Position()
    local f=self:Box(); local s=self:Settings()
    f:SetScale(s.size); f:ClearAllPoints()
    if s.x and s.y then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x/s.size,s.y/s.size)
    else f:SetPoint("CENTER",UIParent,"CENTER",0,150) end
end
function A:ResetPosition() local s=self:Settings(); s.x,s.y=nil,nil; self:Position() end
local function classColored(name,class)
    local c=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if c and c.r then return string.format("|cff%02x%02x%02x%s|r",c.r*255,c.g*255,c.b*255,name) end
    return name
end
function A:Show(order,classes)
    local f=self:Box(); local s=self:Settings()
    local n=#order
    f.title:SetText(n==1 and "Targeted!" or ("Targeted by "..n.."!"))
    local width=f.title:GetStringWidth() or 0
    if s.names then
        local parts={}
        for i=1,math.min(n,NAMES) do parts[i]=classColored(order[i],classes[order[i]]) end
        f.who:SetText(table.concat(parts,", ")..(n>NAMES and (" +"..(n-NAMES)) or ""))
        f.who:Show(); width=math.max(width,f.who:GetStringWidth() or 0)
    else
        f.who:SetText(""); f.who:Hide()
    end
    f.title:ClearAllPoints()
    if s.names then f.title:SetPoint("TOPLEFT",f.icon,"TOPRIGHT",7,2) else f.title:SetPoint("LEFT",f.icon,"RIGHT",7,0) end
    f:SetSize(math.ceil(width)+42,s.names and 38 or 30)
    f.icon:SetSize(s.names and 26 or 20,s.names and 26 or 20)
    self:Paint()
    if not f:IsShown() then self:Position(); f:Show() end
end
-- Preview: an example (and the box can be dragged while it shows).
local SAMPLE_ORDER={"Valeria","Thorgrim"}
local SAMPLE_CLASS={Valeria="PALADIN",Thorgrim="WARRIOR"}
function A:SetPreview(on)
    self.preview=on and true or nil
    self.moving=self.preview
    local f=self:Box()
    FT:LockedMouse(f,not self.moving,"TargetAlert")
    if on then self:Position(); self:Show(SAMPLE_ORDER,SAMPLE_CLASS); self.flashUntil=(GetTime and GetTime() or 0)+.6
    else f:Hide(); self.count=0; self:Check() end
    self:Refresh()
end
function A:SetMoving(on) self:SetPreview(on) end
-- Watching ---------------------------------------------------------------
function A:PlateAdded(unit) if self:Enemy(unit) then self.plates[unit]=true; self:Wake() end end
function A:PlateRemoved(unit) if self.plates[unit] then self.plates[unit]=nil; self:Check() end end
function A:ScanPlates()
    for k in pairs(self.plates) do self.plates[k]=nil end
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok,list=pcall(C_NamePlate.GetNamePlates)
        if ok and type(list)=="table" then
            for _,plate in ipairs(list) do
                local unit=plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if type(unit)=="string" and self:Enemy(unit) then self.plates[unit]=true end
            end
        end
    end
end
-- The light check runs only while enemy players are near or the box shows.
function A:Wake()
    local driver=self.driver
    if next(self.plates) or (self.box and self.box:IsShown()) then driver:Show() else driver:Hide() end
end
function A:Apply()
    local s=self:Settings()
    local ev=self.events
    local list={"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_TARGET","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UPDATE_MOUSEOVER_UNIT","PLAYER_ENTERING_WORLD"}
    for _,event in ipairs(list) do
        if s.enabled then pcall(ev.RegisterEvent,ev,event) else pcall(ev.UnregisterEvent,ev,event) end
    end
    if s.enabled then self:ScanPlates() else for k in pairs(self.plates) do self.plates[k]=nil end end
    if self.box then self:Position(); if not self.preview then self.count=0; self.box:Hide() end end
    if s.enabled then self:Check() end
    self:Wake()
    self:Refresh()
end
-- Settings page (PvP > Targeted alert) -----------------------------------
function A:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Targeted alert: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    local where=s.where=="all" and "Everywhere" or "Open world"
    self.whereButton.label:SetText("Where: "..where)
    local again="30 seconds"; for _,c in ipairs(AGAIN_LIST) do if c[1]==s.again then again=c[2] end end
    self.againButton.label:SetText("Warn again about the same player: "..again)
    self.soundButton.label:SetText("Sound: "..(s.sound and "On" or "Off")); FT:SetSelected(self.soundButton,s.sound)
    self.flashButton.label:SetText("Flash when someone new targets you: "..(s.flash and "On" or "Off")); FT:SetSelected(self.flashButton,s.flash)
    self.namesButton.label:SetText("Show their names: "..(s.names and "On" or "Off")); FT:SetSelected(self.namesButton,s.names)
    local colorName="Red"; for _,c in ipairs(COLOR_LIST) do if c[1]==s.color then colorName=c[2] end end
    self.colorButton.label:SetText("Color: "..colorName)
    self.backButton.label:SetText("Background: "..(s.background and "On" or "Off")); FT:SetSelected(self.backButton,s.background)
    self.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
    self.settingSize=true; self.sizeSlider:SetValue(s.size); self.settingSize=false
    for _,b in ipairs(self.subs) do b:SetAlpha(s.enabled and 1 or .5) end
    FT:RefreshPreview(self.frame)
    if self.preview then self:Show(SAMPLE_ORDER,SAMPLE_CLASS) end
end
-- Any setting on the page also turns the alert on.
function A:Change(fn)
    local s=self:Settings(); fn(s)
    if not s.enabled then s.enabled=true end
    self:Apply()
end
function A:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTargetAlert","Targeted alert",540,510); self.frame=frame
        FT:PageInfo(frame,"Targeted alert","A small box when an enemy player near you has you as their target, with how many and who. Enemy nameplates must be on (V) to see players you haven't targeted yourself.")
        self.toggle=FT:AccentButton(frame,"",492,34,"Ability_Hunter_SniperShot"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Targeted alert","Warn me when an enemy player near me targets me.")
        self.previewButton=FT:TopPreview(frame,self.toggle,{get=function() return self.preview==true end,set=function(on) self:SetPreview(on) end})
        local y=-118
        local function row(label,icon,tipTitle,tip,h)
            local b=FT:QuietButton(frame,label,492,h or 32,icon); b:SetPoint("TOPLEFT",24,y); y=y-(h or 32)-8
            FT:Tooltip(b,tipTitle,tip)
            return b
        end
        self.whereButton=row("Where","INV_Misc_Map_01","Where","Open world: not in battlegrounds or arenas, where everyone targets you. Everywhere: there too.")
        FT:MakeChoice(self.whereButton,WHERE_LIST,function() return self:Settings().where end,function(v) self:Change(function(s) s.where=v end) end)
        self.soundButton=row("","Spell_Holy_Silence","Sound","A warning sound when someone new targets you.")
        self.soundButton:SetScript("OnClick",function() self:Change(function(s) s.sound=not s.sound end) end)
        self.flashButton=row("","Spell_Holy_SearingLight","Flash","The box's border flashes when someone new targets you.")
        self.flashButton:SetScript("OnClick",function() self:Change(function(s) s.flash=not s.flash end) end)
        self.againButton=row("Warn again","INV_Misc_PocketWatch_01","Warn again about the same player","Sound and flash only once per player: again when they target you after this long without doing it. The box always shows who targets you now.")
        FT:MakeChoice(self.againButton,AGAIN_LIST,function() return self:Settings().again end,function(v) self:Change(function(s) s.again=v end) end)
        self.namesButton=row("","INV_Misc_Note_02","Show their names","Up to three names in class colors, under the count. Off: only the count, in a smaller box.")
        self.namesButton:SetScript("OnClick",function() self:Change(function(s) s.names=not s.names end) end)
        self.colorButton=row("Color","fonts","Color","The color of the text and border.")
        FT:MakeChoice(self.colorButton,COLOR_LIST,function() return self:Settings().color end,function(v) self:Change(function(s) s.color=v end) end)
        self.backButton=row("","Spell_Shadow_Twilight","Background","A dark box behind the text. Off: only the text and icon.")
        self.backButton:SetScript("OnClick",function() self:Change(function(s) s.background=not s.background end) end)
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,y-6)
        self.sizeSlider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); self.sizeSlider:SetSize(320,18); self.sizeSlider:SetPoint("TOPLEFT",196,y-4)
        self.sizeSlider:SetMinMaxValues(.6,2); self.sizeSlider:SetValueStep(.05); self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,v) if self.settingSize then return end local s=self:Settings(); s.size=math.floor(v*20+.5)/20; if not s.enabled then s.enabled=true; self:Apply() end; self:Position(); self:Refresh() end)
        FT:Tooltip(self.sizeSlider,"Size","Box size (60% to 200%).")
        y=y-40
        local reset=FT:QuietButton(frame,"Reset position",240,32,"reset"); reset:SetPoint("TOPLEFT",24,y)
        reset:SetScript("OnClick",function() self:ResetPosition(); self:Refresh() end)
        FT:Tooltip(reset,"Reset position","Back above the middle of the screen.")
        self.subs={self.whereButton,self.againButton,self.soundButton,self.flashButton,self.namesButton,self.colorButton,self.backButton}
        FT:Sections(frame,{{"When",self.whereButton},{"Look",self.namesButton},{"Position",reset}})
        local need=FT.ContentHeight and FT:ContentHeight(frame)
        if need and need>frame:GetHeight() then frame:SetHeight(math.ceil(need)) end
        frame:HookScript("OnHide",function() if self.preview then self:SetPreview(false) end end)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("TargetAlert",A)
A.events=CreateFrame("Frame")
A.events:RegisterEvent("PLAYER_LOGIN")
A.events:SetScript("OnEvent",function(_,event,unit)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then A:Apply(); return end
    if event=="NAME_PLATE_UNIT_ADDED" then A:PlateAdded(unit)
    elseif event=="NAME_PLATE_UNIT_REMOVED" then A:PlateRemoved(unit); return
    elseif event=="PLAYER_ENTERING_WORLD" then A:ScanPlates()
    elseif event=="UNIT_TARGET" then
        -- Only the units we watch.
        if not (A.plates[unit] or unit=="target" or unit=="focus" or unit=="mouseover") then return end
    end
    A:Check(); A:Wake()
end)
-- The light check (four times a second, only while enemies are near).
A.driver=CreateFrame("Frame"); A.driver:Hide()
local elapsed=0
A.driver:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt; if elapsed<.25 then return end; elapsed=0
    if not FT.dbReady then return end
    A:Check(); A:Wake()
end)
