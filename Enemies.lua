local _,FT=...
-- Enemy awareness (PvP group; everything off by default).
--   * Stealth alert: an enemy player near you goes into stealth (we see
--     them cast Stealth, Prowl, Vanish, Shadowmeld or Invisibility). As an
--     option also when a rogue or druid simply drops from view.
--   * Marked players: right-click an enemy player's portrait to mark them.
--     When a marked player shows up again (on any of your characters) you
--     get a stronger, red alert, and their tooltip says they are marked.
--   * Nearby enemies: a small row of class icons of the enemy players seen
--     in the last half minute.
-- The game keeps the combat log from addons, so all of this works from what
-- the game shows you: nameplates, your target and mouseover, and spells
-- enemies cast in front of you. Enemy nameplates must be on to see players
-- that are not targeted. Nothing is ever sent to anyone.
local E={plates={},seen={},alerted={}}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local function number(v) if plain(v) and type(v)=="number" then return v end end
local function now() return GetTime and GetTime() or 0 end
local function stamp() return time and time() or 0 end
local STEALTH_IDS={[1784]=1,[1785]=1,[1786]=1,[1787]=1,[1856]=1,[1857]=1,[11327]=1,[11329]=1,[5215]=1,[6783]=1,[9913]=1,[20580]=1,[58984]=1,[66]=1,[32612]=1}
local STEALTH_NAMES={Stealth=true,Prowl=true,Vanish=true,Shadowmeld=true,Invisibility=true}
local STEALTHY={ROGUE=true,DRUID=true}
-- The picture of the stealth spell (Stealth, Prowl, Shadowmeld ...), shown
-- on the alert and the list instead of the class icon.
local function spellIcon(id)
    if not id then return nil end
    local tex
    if C_Spell and C_Spell.GetSpellTexture then local ok,t=pcall(C_Spell.GetSpellTexture,id); if ok then tex=t end end
    if not tex and GetSpellTexture then local ok,t=pcall(GetSpellTexture,id); if ok then tex=t end end
    if tex and plain(tex) and (type(tex)=="number" or type(tex)=="string") then return tex end
end
function E:Settings()
    if type(FT.db.enemies)~="table" then FT.db.enemies={} end
    local s=FT.db.enemies
    for _,key in ipairs({"stealth","fade","marks","nearby","instances"}) do if type(s[key])~="boolean" then s[key]=false end end
    for _,key in ipairs({"sound","flash","markTooltip"}) do if type(s[key])~="boolean" then s[key]=true end end
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    s.nearSize=math.max(.7,math.min(1.5,tonumber(s.nearSize) or 1))
    s.nearTime=({[15]=15,[30]=30,[60]=60,[120]=120})[tonumber(s.nearTime) or 30] or 30
    if s.nearDock~="top" and s.nearDock~="bottom" and s.nearDock~="left" and s.nearDock~="right" then s.nearDock="free" end
    if type(s.nearCollapsed)~="boolean" then s.nearCollapsed=false end
    if type(s.nearShowEmpty)~="boolean" then s.nearShowEmpty=false end
    if type(s.nearAlong)~="number" then s.nearAlong=nil end
    if s.nearCorner~="TOPLEFT" and s.nearCorner~="BOTTOMLEFT" and s.nearCorner~="TOPRIGHT" then s.nearCorner=nil end
    s.nearRows=math.max(1,math.min(8,math.floor(tonumber(s.nearRows) or 8)))
    if type(s.nearFade)~="boolean" then s.nearFade=false end
    for _,pair in ipairs({{"x","y"},{"nearX","nearY"}}) do
        if type(s[pair[1]])~="number" or type(s[pair[2]])~="number" then s[pair[1]],s[pair[2]]=nil,nil end
    end
    return s
end
function E:AnyOn() local s=self:Settings(); return s.stealth or s.marks or s.nearby end
-- Marks are kept for the whole account (never in profiles or exports).
function E:Marks()
    if type(FT.db.enemyMarks)~="table" then FT.db.enemyMarks={} end
    return FT.db.enemyMarks
end
-- Where we are: the open world, unless battlegrounds and arenas are allowed.
function E:Active()
    if not FT.dbReady or not self:AnyOn() then return false end
    if self:Settings().instances then return true end
    if IsInInstance then
        local ok,inside,kind=pcall(IsInInstance)
        if ok and plain(inside) and inside and plain(kind) and (kind=="pvp" or kind=="arena") then return false end
    end
    return true
end
-- An enemy player, read from a unit. nil when it is not one, or hidden.
function E:Read(unit,duelToo)
    if not unit or not UnitIsPlayer then return end
    local ok,isPlayer=pcall(UnitIsPlayer,unit); if not ok or not plain(isPlayer) or not isPlayer then return end
    local okEnemy,enemy=pcall(UnitIsEnemy,"player",unit)
    if not okEnemy or not plain(enemy) then return end
    -- In a duel your own faction is not "enemy", only attackable.
    if not enemy and duelToo and UnitCanAttack then
        local okA,attack=pcall(UnitCanAttack,"player",unit)
        enemy=okA and plain(attack) and attack==true
    end
    if not enemy then return end
    -- A duel makes your own faction hostile for a while: only the other faction counts.
    if UnitFactionGroup then
        local okA,mine=pcall(UnitFactionGroup,"player"); local okB,theirs=pcall(UnitFactionGroup,unit)
        if okA and okB and plain(mine) and plain(theirs) and type(mine)=="string" and mine==theirs then
            -- Stealth alerts still count someone you duel (marked by duel).
            if not duelToo then return end
            duelToo="duel"
        end
    end
    local guid=text(UnitGUID and UnitGUID(unit)); if not guid then return end
    local okName,name,realm=pcall(UnitName,unit); name=okName and text(name); if not name then return end
    realm=okName and text(realm)
    local _,class=UnitClass(unit); class=text(class)
    local level=UnitLevel and number(UnitLevel(unit))
    local race
    if UnitRace then local _,file=UnitRace(unit); race=text(file) end
    local guild=GetGuildInfo and text((GetGuildInfo(unit)))
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit); dead=plain(dead) and dead==true
    return {guid=guid,name=name,realm=realm,class=class,level=level,race=race,guild=guild,dead=dead,duel=duelToo=="duel" or nil}
end
function E:Key(info)
    local realm=info.realm
    if not realm then local B=FT.Bags; realm=B and B:Ruleset() or (GetRealmName and text(GetRealmName())) or "?" end
    return info.name.."-"..realm
end
function E:IsMarked(info) return info and self:Marks()[self:Key(info)] or nil end
function E:ClassIcon(class)
    if not class then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return "Interface\\Icons\\ClassIcon_"..class:sub(1,1)..class:sub(2):lower()
end
function E:ClassColor(class)
    local c=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if c and c.r then return c.r,c.g,c.b end
    return 1,1,1
end
function E:Describe(info)
    local class=info.class and (info.class:sub(1,1)..info.class:sub(2):lower()) or ""
    return (info.level and info.level>0 and ("Level "..info.level.." ") or "")..class
end
-- Seeing an enemy player ------------------------------------------------------
function E:Saw(info,unit)
    if not info then return end
    local entry=self.seen[info.guid] or {}
    for k,v in pairs(info) do entry[k]=v end
    entry.last=now(); if not entry.first then entry.first=entry.last end
    -- A new sighting (they were out of view): the "in view for" clock restarts.
    if not entry.unit or not entry.since then entry.since=entry.last end
    entry.unit=unit
    self.seen[info.guid]=entry
    self:LogSaw(info)
    local mark=self:IsMarked(info)
    if mark then
        -- Keep what we know about a marked player up to date.
        mark.class=info.class or mark.class; mark.level=info.level or mark.level; mark.guild=info.guild or mark.guild; mark.seen=stamp()
        -- Not for someone you just marked yourself: the alert waits until
        -- they have been out of view and come back.
        if self:Settings().marks and not entry.markedHere then self:Alert(info,"marked") end
    end
    self:UpdateStrip()
end
-- A player you can see while they are in stealth (close enough to spot
-- them): their Stealth / Prowl buff is read when they come into view.
function E:InStealth(unit)
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return nil end
    for i=1,40 do
        local ok,a=pcall(C_UnitAuras.GetAuraDataByIndex,unit,i,"HELPFUL")
        if not ok or not a then return nil end
        if plain(a) and type(a)=="table" then
            local id,name=a.spellId,a.name
            if (plain(id) and STEALTH_IDS[id]) or (plain(name) and type(name)=="string" and STEALTH_NAMES[name]) then
                local icon=a.icon
                if not (plain(icon) and (type(icon)=="number" or type(icon)=="string")) then icon=plain(id) and spellIcon(id) or nil end
                return plain(name) and name or "Stealth",icon
            end
        end
    end
end
-- Going into stealth, seen from the Stealth / Prowl buff showing up on a
-- player in view (in a fight the game may hide the spell they cast, but
-- not always the buff). Only new buffs are looked at.
E.inStealth={}
function E:AuraChanged(unit,info)
    if not plain(unit) or type(unit)~="string" then return end
    if not (unit=="target" or unit=="focus" or unit=="mouseover" or unit:find("^nameplate")) then return end
    if not self:Settings().stealth or not self:Active() then return end
    local look=false
    if plain(info) and type(info)=="table" then
        local full=info.isFullUpdate
        if not plain(full) or full then look=true end
        local added=info.addedAuras
        if not look and plain(added) and type(added)=="table" then
            for _,a in ipairs(added) do
                if not plain(a) or type(a)~="table" then look=true; break end
                local id,name=a.spellId,a.name
                if (plain(id) and STEALTH_IDS[id]) or (plain(name) and type(name)=="string" and STEALTH_NAMES[name]) then look=true; break end
            end
        end
        -- A removed buff may be the stealth ending.
        local removed=info.removedAuraInstanceIDs
        if not look and plain(removed) and type(removed)=="table" and #removed>0 and next(self.inStealth) then
            local okG,g=pcall(UnitGUID,unit)
            if okG and plain(g) and self.inStealth[g] then look=true end
        end
    else look=true end
    if not look then return end
    local info2=self:Read(unit,true); if not info2 then return end
    local spell,icon=self:InStealth(unit)
    local was=self.inStealth[info2.guid]
    self.inStealth[info2.guid]=spell and true or nil
    if spell and not was then
        info2.spell=spell; info2.spellIcon=icon
        if not info2.duel then self:Saw(info2,unit) end
        self:Alert(info2,"stealth")
    end
end
function E:CheckSpotted(unit)
    if not self:Settings().stealth or not self:Active() then return end
    local info=self:Read(unit,true); if not info then return end
    local spell,icon=self:InStealth(unit); if not spell then return end
    info.spell=spell; info.spellIcon=icon
    self.inStealth[info.guid]=true
    self:Alert(info,"spotted")
end
function E:PlateAdded(unit)
    if not self:Active() then return end
    self:CheckSpotted(unit)
    local info=self:Read(unit); if not info then return end
    self.plates[unit]=info.guid
    self:Saw(info,unit)
end
-- A rogue or druid that drops from view without dying may have stealthed
-- (or simply walked out of sight); that guess is its own switch.
function E:PlateRemoved(unit)
    local guid=self.plates[unit]; self.plates[unit]=nil
    if not guid or not self:Active() then return end
    local entry=self.seen[guid]; if not entry then return end
    entry.unit=nil; entry.markedHere=nil
    local s=self:Settings()
    if not s.stealth or not s.fade then return end
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if plain(dead) and dead then return end
    if entry.dead then return end
    local stealthy=STEALTHY[entry.class or ""]
    if not stealthy or now()-(entry.first or now())<1 then return end
    self:Alert(entry,"faded")
end
function E:SpellName(id)
    if C_Spell and C_Spell.GetSpellName then local ok,name=pcall(C_Spell.GetSpellName,id); if ok then return text(name) end end
    if GetSpellInfo then local ok,name=pcall(GetSpellInfo,id); if ok then return text(name) end end
end
function E:IsStealthSpell(id)
    if not number(id) then return false end
    if STEALTH_IDS[id] then return true end
    if not self.stealthNames then
        self.stealthNames={}
        for name in pairs(STEALTH_NAMES) do self.stealthNames[name]=true end
        for known in pairs(STEALTH_IDS) do local name=self:SpellName(known); if name then self.stealthNames[name]=true end end
    end
    local name=self:SpellName(id)
    return name and self.stealthNames[name] or false
end
function E:Cast(unit,spellID)
    if not self:Settings().stealth or not self:Active() then return end
    if not plain(unit) or type(unit)~="string" then return end
    if not (unit:find("^nameplate") or unit=="target" or unit=="focus" or unit=="mouseover") then return end
    if not self:IsStealthSpell(spellID) then return end
    -- Someone you duel (your own faction) counts here too, but is not
    -- listed as an enemy.
    local info=self:Read(unit,true); if not info then return end
    info.spell=self:SpellName(spellID); info.spellIcon=spellIcon(spellID)
    if not info.duel then self:Saw(info,unit) end
    self:Alert(info,"stealth")
end
-- Skins > PvP: the panel takes the skin's colors when that part is on.
local function skinPanel(f,key,fill,border,opts)
    local skins=FT.modules.IconStyles
    if skins and skins.SkinPanel then skins:SkinPanel(f,key,fill,border,opts) elseif f.fillTextures then FT:Paint(f,fill,border) end
end
-- The alert --------------------------------------------------------------------
local GOLD,RED={1,.78,.25},{1,.22,.18}
function E:Notice()
    if self.notice then return self.notice end
    local f=CreateFrame("Button","ForeverToolsEnemyAlert",UIParent)
    f:SetSize(320,48); f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true)
    FT:Panel(f); FT:Paint(f,{.06,.045,.02,.95},{.85,.66,.25,1}); FT:MeterSkin(f)
    skinPanel(f,"enemyAlert",{.06,.045,.02,.95},{.85,.66,.25,1})
    f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetSize(32,32); f.icon:SetPoint("LEFT",9,0); FT:RoundIcon(f.icon)
    f.title=FT:Label(f,"",11,true); f.title:SetPoint("TOPLEFT",f,"TOPLEFT",50,-8)
    f.name=FT:Label(f,"",15,true); f.name:SetPoint("TOPLEFT",f.title,"BOTTOMLEFT",0,-2); f.name:SetWidth(258)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.reason=FT:Label(f,"",11); f.reason:SetPoint("TOPLEFT",f.name,"BOTTOMLEFT",0,-2); f.reason:SetWidth(258); f.reason:SetTextColor(1,.55,.45)
    if f.reason.SetWordWrap then f.reason:SetWordWrap(false) end
    local pulse=f:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(.45); fade:SetDuration(.45)
    f.pulse=pulse
    f:RegisterForClicks("LeftButtonUp","RightButtonUp"); f:RegisterForDrag("LeftButton"); f:SetMovable(true)
    f:SetScript("OnClick",function(_,button)
        if button=="RightButton" then if not InCombatLockdown() then FT:OpenModule("EnemyAlerts") end
        elseif not self.moving then f:Hide() end
    end)
    f:SetScript("OnDragStart",function() if self.moving then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local s=self:Settings()
        if x and y then local scale=f:GetScale(); s.x,s.y=x*scale,y*scale end
        self:Position()
    end)
    FT:Tooltip(f,"Enemy alert","Left-click to dismiss, right-click for settings.")
    f:Hide()
    self.notice=f
    return f
end
-- A short glow along the screen's edges, for alerts you might miss.
function E:Flash(color)
    if not self.edges then
        local frame=CreateFrame("Frame",nil,UIParent); frame:SetAllPoints(UIParent); frame:SetFrameStrata("BACKGROUND"); frame:EnableMouse(false)
        frame.parts={}
        for _,side in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
            local t=frame:CreateTexture(nil,"BACKGROUND"); t:SetTexture("Interface\\Buttons\\WHITE8x8"); t:SetBlendMode("ADD")
            if side=="TOP" or side=="BOTTOM" then t:SetPoint(side.."LEFT"); t:SetPoint(side.."RIGHT"); t:SetHeight(90)
            else t:SetPoint("TOP"..side); t:SetPoint("BOTTOM"..side); t:SetWidth(90) end
            t.side=side; frame.parts[#frame.parts+1]=t
        end
        frame:Hide(); self.edges=frame
    end
    local frame=self.edges
    for _,t in ipairs(frame.parts) do
        local r,g,b=color[1],color[2],color[3]
        if FT.GradientTexture then
            local orient=(t.side=="TOP" or t.side=="BOTTOM") and "VERTICAL" or "HORIZONTAL"
            local outerFirst=t.side=="BOTTOM" or t.side=="LEFT"
            if outerFirst then FT.GradientTexture(t,orient,r,g,b,.45,r,g,b,0) else FT.GradientTexture(t,orient,r,g,b,0,r,g,b,.45) end
        else t:SetVertexColor(r,g,b,.25) end
    end
    frame.started=now(); frame:SetAlpha(1); frame:Show()
    frame:SetScript("OnUpdate",function(owner)
        local passed=now()-owner.started
        -- Two soft beats, then gone.
        local a=passed<1.6 and math.abs(math.sin(passed*math.pi*1.25)) or 0
        owner:SetAlpha(a)
        if passed>=1.6 then owner:Hide(); owner:SetScript("OnUpdate",nil) end
    end)
end
function E:Position()
    local f=self:Notice(); local s=self:Settings()
    f:SetScale(s.size); f:ClearAllPoints()
    if s.x and s.y then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x/s.size,s.y/s.size)
    else f:SetPoint("TOP",UIParent,"TOP",0,-140/s.size) end
end
local titles={stealth="Enemy went into stealth",faded="Enemy dropped from view",spotted="Stealthed enemy spotted",marked="Marked player nearby"}
function E:Alert(info,kind,preview)
    local s=self:Settings()
    if not preview and FT:NoControl() then return end
    if not preview then
        if kind=="marked" and not s.marks then return end
        if kind~="marked" and not s.stealth then return end
        -- Once per player per minute (marked) or half minute (stealth).
        local key=kind..":"..(info.guid or info.name or "?")
        local last=self.alerted[key]
        -- Stealth warnings may come again quickly (a stealthed player in a
        -- fight keeps popping in and out of view); marked players once a minute.
        local gap=kind=="marked" and 60 or kind=="spotted" and 4 or 8
        if last and now()-last<gap then return end
        self.alerted[key]=now()
    end
    -- The list shows who went into stealth, and comes up if it was hidden.
    if not preview then
        local entry=info.guid and self.seen[info.guid]
        if entry and kind~="marked" then entry.stealthAt=now(); entry.stealthIcon=info.spellIcon end
        self:Wake(12)
    end
    -- A marked player is always the stronger, red alert.
    local danger=kind=="marked" or (self:IsMarked(info) and true or false)
    local f=self:Notice(); self:Position()
    local color=danger and RED or GOLD
    skinPanel(f,"enemyAlert",{.06,.045,.02,.95},{color[1]*.85,color[2]*.85,color[3]*.85,1},{semantic=danger})
    f.icon:SetTexture((kind~="marked" and info.spellIcon) or self:ClassIcon(info.class))
    f.title:SetText(((danger and kind~="marked") and ("Marked player · "..titles[kind]:lower()) or titles[kind] or "Enemy nearby")..(preview and not self.moving and " — preview" or ""))
    f.title:SetTextColor(color[1],color[2],color[3])
    local r,g,b=self:ClassColor(info.class)
    f.name:SetText(string.format("|cff%02x%02x%02x%s|r  |cffb8ab8a%s%s|r",r*255,g*255,b*255,info.name or "?",self:Describe(info),info.spell and (" · "..info.spell) or ""))
    local mark=self:IsMarked(info)
    local reason=mark and mark.note or (preview and kind=="marked" and "Camped me in Duskwood")
    f.reason:SetText(reason and ("Reason: "..reason) or ""); f.reason:SetShown(reason~=nil)
    f:SetHeight(reason and 62 or 48)
    f:Show(); f.pulse:Stop(); f.pulse:Play()
    self.token=(self.token or 0)+1
    local token=self.token
    C_Timer.After(danger and 3 or 1.8,function() if self.token==token and f.pulse then f.pulse:Stop() end end)
    C_Timer.After(danger and 12 or 7,function() if self.token==token and not self.moving and not self.previewKind then f:Hide() end end)
    if s.flash and not self.moving then self:Flash(color) end
    if s.sound and not preview and SOUNDKIT and SOUNDKIT.RAID_WARNING and PlaySound then pcall(PlaySound,SOUNDKIT.RAID_WARNING,"Master") end
end
function E:Preview(kind)
    self:Alert({guid="preview",name=kind=="marked" and "Gankalot" or "Sneakyboi",class="ROGUE",level=24,spell=kind=="stealth" and "Stealth" or nil},kind or "stealth",true)
end
-- Preview switch on the page: the alert stays on screen until switched off
-- (or the page closes). One kind at a time.
function E:SetPreviewKind(kind)
    if kind and InCombatLockdown() then kind=nil end
    self.previewKind=kind
    if kind then self:Preview(kind)
    elseif self.notice and not self.moving then self.notice:Hide() end
    self:Refresh()
end
function E:SetMoving(on)
    self.moving=on and true or false
    local f=self:Notice()
    if self.moving then self:Position(); self:Preview("stealth"); f.title:SetText("Drag me, then click Lock")
    elseif self.previewKind then self:Preview(self.previewKind) else f:Hide() end
    self:Refresh()
end
function E:ResetPosition() local s=self:Settings(); s.x,s.y=nil,nil; self:Position() end
-- Nearby enemies list ---------------------------------------------------------
-- A small list in the game's own tooltip style: a header (collapse button,
-- title with the count, move button) and one row per enemy player seen
-- lately: class icon, name in class colour, level, and how long ago. Click a
-- row to target that player. It can sit anywhere, or be attached to the top,
-- bottom, left or right edge of the screen; collapsed it is a small tab.
-- The rows are secure buttons (that is what lets a click target someone), so
-- in a fight the list keeps its rows: they still update and target, and
-- players first seen during the fight are listed under it (target them after
-- the fight). Everything is laid out again when the fight ends.
local WIDTH,HEADER,ROW,MAXROWS=196,24,18,20
-- Click the title: nearby → seen before (the log) → marked → nearby.
local VIEW_TITLE={near="Enemies nearby",log="Seen before",marked="Marked"}
local VIEW_NEXT={near="log",log="marked",marked="near"}
local DOCKS={free=true,top=true,bottom=true,left=true,right=true}
E.DOCKS={"free","top","bottom","left","right"}
local function busy() return InCombatLockdown and InCombatLockdown() end
local function backdrop(f)
    if f.SetBackdrop and BACKDROP_TOOLTIP_16_16_5555 then pcall(f.SetBackdrop,f,BACKDROP_TOOLTIP_16_16_5555) end
    if f.SetBackdropColor then pcall(f.SetBackdropColor,f,0,0,0,.82) end
    if f.SetBackdropBorderColor then pcall(f.SetBackdropBorderColor,f,.6,.6,.6,1) end
end
local function plainFrame(name,parent)
    local ok,f=pcall(CreateFrame,"Frame",name,parent,"TooltipBackdropTemplate")
    if not ok or not f then ok,f=pcall(CreateFrame,"Frame",name,parent,"BackdropTemplate") end
    if not ok or not f then f=CreateFrame("Frame",name,parent) end
    backdrop(f)
    return f
end
local function headerButton(parent,texture,size)
    local b=CreateFrame("Button",nil,parent); b:SetSize(size,size)
    b.tex=b:CreateTexture(nil,"ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexture(texture)
    local hi=b:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(); hi:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight"); hi:SetBlendMode("ADD")
    return b
end
local function short(sec)
    sec=math.max(0,math.floor(sec))
    if sec<60 then return sec.."s" elseif sec<3600 then return math.floor(sec/60).."m"
    elseif sec<86400 then return math.floor(sec/3600).."h" else return math.floor(sec/86400).."d" end
end
local STEALTH_TAG=30 -- seconds a row says "stealth" after they vanished
local function ago(e)
    if e.logged then return short(stamp()-(e.seen or stamp())) end
    if e.stealthAt and now()-e.stealthAt<STEALTH_TAG then return "|cffffd100stealth|r" end
    -- In view: how long you've seen them (1s, 2s ...); out of view: how long ago.
    if e.unit then local t=now()-(e.since or e.last or now()); return t<1 and "now" or short(t) end
    return short(now()-(e.last or now()))
end
local function fillRow(row,e)
    row.entry=e
    -- In stealth (or Shadowmeld) a moment ago: that spell's picture instead of the class.
    local stealthy=e.stealthIcon and e.stealthAt and now()-e.stealthAt<STEALTH_TAG
    row.icon:SetTexture(stealthy and e.stealthIcon or E:ClassIcon(e.class))
    local r,g,b=E:ClassColor(e.class)
    local marked=E:IsMarked(e)
    row.name:SetText((marked and "|cffff4433!|r " or "")..(e.name or "?")); row.name:SetTextColor(r,g,b)
    row.level:SetText(e.level and e.level>0 and e.level or "??")
    row.ago:SetText(ago(e))
    row.mark:SetShown(marked~=nil)
    row:SetAlpha((e.unit or e.logged) and 1 or .6)
end
local function rowTooltip(owner)
    local e=owner.entry; if not e then return end
    GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
    local r,g,bl=E:ClassColor(e.class)
    GameTooltip:SetText(e.name or "?",r,g,bl)
    GameTooltip:AddLine(E:Describe(e)..(e.guild and ("  <"..e.guild..">") or ""),.96,.93,.86)
    if e.logged then
        local B=FT.Bags
        GameTooltip:AddLine("Last seen "..(B and B:Ago(e.seen) or short(stamp()-(e.seen or 0)).." ago")..(e.zone and (" in "..e.zone) or ""),.72,.66,.55,true)
        if (e.times or 0)>1 then GameTooltip:AddLine("Met "..e.times.." times",.72,.66,.55) end
    else
        local s=math.floor(now()-(e.last or now()))
        GameTooltip:AddLine(e.unit and "In view now" or ("Seen "..s.." s ago"),.72,.66,.55)
        if e.stealthAt and now()-e.stealthAt<STEALTH_TAG then GameTooltip:AddLine("Went into stealth "..math.floor(now()-e.stealthAt).." s ago",1,.82,0) end
    end
    local mark=E:IsMarked(e)
    if mark then GameTooltip:AddLine("Marked"..(mark.note and (": "..mark.note) or " by you"),1,.3,.25,true) end
    if owner.secure then GameTooltip:AddLine(owner.combatNew and "Seen in this fight. Click to target after it." or "Click to target.",.1,1,.1) end
    GameTooltip:AddLine(mark and "Right-click: change reason or remove mark." or "Right-click: mark player.",.72,.66,.55)
    GameTooltip:Show()
end
-- Right-click a row: mark the player (with a reason), change the reason or
-- remove the mark.
local function rowMenu(row)
    local e=row.entry; if not e or not e.name then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(row,function(_,root)
        local key=E:Key(e); local m=E:Marks()[key]
        root:CreateTitle(e.name)
        if m then
            root:CreateButton("Change reason...",function() E:AskReason(key) end)
            root:CreateButton("Remove mark",function() E:Unmark(key) end)
        else
            root:CreateButton("Mark player...",function()
                local k=E:Mark(e); FT:Toast("Marked "..e.name..".",3); E:AskReason(k)
            end)
        end
    end)
end
local function makeRow(parent,secure)
    local row
    if secure then
        local ok,b=pcall(CreateFrame,"Button",nil,parent,"SecureActionButtonTemplate")
        row=ok and b or CreateFrame("Button",nil,parent)
        row:RegisterForClicks("AnyUp","AnyDown")
        row:SetAttribute("type","macro")
        -- Right-click opens our menu instead of targeting.
        row:SetAttribute("type2","ftmenu")
        row:HookScript("OnClick",function(owner,button,down) if button=="RightButton" and not down then rowMenu(owner) end end)
        row.secure=true
    else
        row=CreateFrame("Frame",nil,parent)
        row:SetScript("OnMouseUp",function(owner,button) if button=="RightButton" then rowMenu(owner) end end)
    end
    row:SetSize(WIDTH-12,ROW)
    row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(ROW-2,ROW-2); row.icon:SetPoint("LEFT",0,0); row.icon:SetTexCoord(.08,.92,.08,.92)
    row.ago=row:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); row.ago:SetPoint("RIGHT",-2,0); row.ago:SetWidth(28); row.ago:SetJustifyH("RIGHT")
    row.level=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); row.level:SetPoint("RIGHT",row.ago,"LEFT",-4,0); row.level:SetWidth(22); row.level:SetJustifyH("RIGHT")
    row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); row.name:SetPoint("LEFT",row.icon,"RIGHT",5,0); row.name:SetPoint("RIGHT",row.level,"LEFT",-4,0); row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.mark=row:CreateTexture(nil,"BACKGROUND"); row.mark:SetAllPoints(); row.mark:SetColorTexture(.8,.1,.05,.28); row.mark:Hide()
    if secure then
        local hi=row:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(); hi:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); hi:SetBlendMode("ADD")
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter",rowTooltip)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return row
end
function E:Strip()
    if self.strip then return self.strip end
    -- A secure frame: the collapse button (also secure) can fold it to the
    -- title in a fight, when the game won't let addon code resize it.
    local okF,secureF=pcall(CreateFrame,"Frame","ForeverToolsNearbyEnemies",UIParent,"SecureHandlerBaseTemplate")
    local f=okF and secureF or plainFrame("ForeverToolsNearbyEnemies",UIParent)
    f:SetSize(WIDTH,HEADER); f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Header: collapse, title and count, move.
    -- The rows sit in a holder of their own that the collapse button shows
    -- and hides, in a fight too.
    local okH,holder=pcall(CreateFrame,"Frame",nil,f,"SecureHandlerBaseTemplate")
    if not okH or not holder then holder=CreateFrame("Frame",nil,f) end
    holder:SetAllPoints(f); f.holder=holder
    local okT,toggle=pcall(CreateFrame,"Button",nil,f,"SecureHandlerClickTemplate")
    if not okT or not toggle then toggle=CreateFrame("Button",nil,f) end
    toggle:SetSize(14,14)
    toggle.tex=toggle:CreateTexture(nil,"ARTWORK"); toggle.tex:SetAllPoints(); toggle.tex:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
    local thi=toggle:CreateTexture(nil,"HIGHLIGHT"); thi:SetAllPoints(); thi:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight"); thi:SetBlendMode("ADD")
    f.toggle=toggle
    if toggle.SetFrameRef then
        toggle:SetFrameRef("holder",holder); toggle:SetFrameRef("strip",f)
        toggle:SetAttribute("_onclick",[[
            local holder=self:GetFrameRef("holder"); local strip=self:GetFrameRef("strip")
            if not holder or not strip then return end
            if holder:IsShown() then holder:Hide(); strip:SetHeight(self:GetAttribute("closedHeight") or 22)
            else holder:Show(); strip:SetHeight(self:GetAttribute("openHeight") or 22) end
        ]])
    end
    toggle:HookScript("PreClick",function() toggle.wasOpen=holder:IsShown() end)
    toggle:HookScript("OnClick",function() self:ToggleCollapsed(toggle.wasOpen) end)
    f.toggle:SetScript("OnEnter",function(owner) GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText(self:Settings().nearCollapsed and "Show the players" or "Hide the players (keep the title)"); GameTooltip:Show() end)
    f.toggle:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.swords=f:CreateTexture(nil,"ARTWORK"); f.swords:SetSize(16,16); f.swords:SetTexture("Interface\\Icons\\Ability_DualWield"); f.swords:SetTexCoord(.08,.92,.08,.92)
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); f.title:SetJustifyH("LEFT")
    -- Click the title to switch between who is near now and the log.
    f.titleButton=CreateFrame("Button",nil,f); f.titleButton:SetHeight(HEADER-4)
    f.titleButton:SetPoint("LEFT",f.swords,"LEFT",0,0); f.titleButton:SetPoint("RIGHT",f,"RIGHT",-28,0)
    f.titleButton:RegisterForDrag("LeftButton")
    f.titleButton:SetScript("OnDragStart",function() if self.movingStrip and not busy() then f:StartMoving() end end)
    f.titleButton:SetScript("OnDragStop",function() f:GetScript("OnDragStop")(f) end)
    f.titleButton:SetScript("OnClick",function() if not self.movingStrip then self:ToggleView() end end)
    f.titleButton:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_TOP")
        local v=self.view or "near"
        GameTooltip:SetText(VIEW_TITLE[v])
        GameTooltip:AddLine("Click to show: "..VIEW_TITLE[VIEW_NEXT[v]]:lower()..".",1,1,1,true)
        GameTooltip:AddLine("Order: nearby, seen before, marked.",.72,.66,.55)
        if v~="near" then GameTooltip:AddLine("Scroll with the mouse wheel.",.72,.66,.55) end
        GameTooltip:Show()
    end)
    f.titleButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel",function(_,delta) self:ScrollLog(delta) end)
    f.move=headerButton(f,"Interface\\Cursor\\UI-Cursor-Move",16)
    f.move:SetScript("OnClick",function() self:SetMovingStrip(not self.movingStrip) end)
    f.move:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        GameTooltip:SetText(self.movingStrip and "Lock the list" or "Move the list")
        GameTooltip:AddLine(self.movingStrip and "Click to lock it where it is." or "Click, then drag the list. Click again to lock.",1,1,1,true)
        GameTooltip:Show()
    end)
    f.move:SetScript("OnLeave",function() GameTooltip:Hide() end)
    f.rows={}
    for i=1,MAXROWS do local row=makeRow(holder,true); row:Hide(); f.rows[i]=row end
    -- One window, always: the background and border are a frame of their own
    -- behind the list, so in a fight it can grow over the rows added below
    -- (the list itself holds click-to-target buttons the game does not let
    -- us move or resize in combat). The list and the extra rows draw none.
    f:SetFrameLevel(10)
    -- The rows' holder (and so the rows) above the list itself, or the list
    -- would take the clicks meant for the names.
    holder:SetFrameLevel(f:GetFrameLevel()+2)
    for i=1,MAXROWS do f.rows[i]:SetFrameLevel(holder:GetFrameLevel()+1) end
    local panel=plainFrame(nil,f); panel:SetFrameLevel(9); panel:SetAllPoints(f); f.panel=panel
    skinPanel(panel,"nearby",{0,0,0,.82},{.6,.6,.6,1})
    local function clear(frame)
        if frame.SetBackdropColor then pcall(frame.SetBackdropColor,frame,0,0,0,0) end
        if frame.SetBackdropBorderColor then pcall(frame.SetBackdropBorderColor,frame,0,0,0,0) end
        if frame.NineSlice and frame.NineSlice.Hide then frame.NineSlice:Hide() end
    end
    clear(f)
    -- Players first seen during a fight: plain rows straight under (or above)
    -- the list, inside the same window.
    local extra=CreateFrame("Frame",nil,UIParent); extra:SetSize(WIDTH,HEADER); extra:SetFrameStrata("MEDIUM"); extra:SetFrameLevel(10); extra:Hide()
    extra:SetScript("OnShow",function() self:FitPanel() end); extra:SetScript("OnHide",function() self:FitPanel() end)
    extra.rows={}
    for i=1,5 do local row=makeRow(extra,false); row.secure=true; row.combatNew=true; row:Hide(); extra.rows[i]=row end
    f.extra=extra
    f:SetScript("OnDragStart",function() if self.movingStrip and not busy() then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        if busy() then return end
        self:SavePlace(); self:PlaceStrip()
    end)
    f:SetScript("OnUpdate",function(owner,dt)
        -- "Show the title bar on mouseover": it fades in under the mouse.
        local over=owner:IsMouseOver()
        if over~=owner.wasOver then owner.wasOver=over; self:FadeStrip() end
        owner.wait=(owner.wait or 0)+dt
        if owner.wait<1 then return end
        owner.wait=0; self:UpdateStrip()
    end)
    f:Hide()
    self.strip=f
    return f
end
-- Which corner of the list stays put. The anchor only says which way the
-- list grows: from the bottom it grows upwards, otherwise downwards. Picking
-- an anchor never moves the list.
local CORNER={free="TOPLEFT",top="TOPLEFT",left="TOPLEFT",bottom="BOTTOMLEFT",right="TOPRIGHT"}
E.CORNER=CORNER
-- Where the list is: its anchor corner, in screen units (x from the left,
-- y from the bottom).
function E:SavePlace()
    local f=self.strip; if not f then return end
    local s=self:Settings(); local scale=f:GetScale() or 1
    local left,top,right,bottom=f:GetLeft(),f:GetTop(),f:GetRight(),f:GetBottom()
    if not (number(left) and number(top) and number(right) and number(bottom)) then return end
    local corner=CORNER[s.nearDock] or "TOPLEFT"
    local x=corner=="TOPRIGHT" and right or left
    local y=corner=="BOTTOMLEFT" and bottom or top
    s.nearX,s.nearY,s.nearCorner,s.nearAlong=x*scale,y*scale,corner,nil
end
function E:PlaceStrip()
    if busy() then self.pendingLayout=true; return end
    local f=self:Strip(); local s=self:Settings()
    local scale=s.nearSize
    f:SetScale(scale); f:ClearAllPoints()
    local corner=s.nearCorner or "TOPLEFT"
    if s.nearAlong and not s.nearX then
        -- Saved by an older version, when an anchor glued the list to that
        -- screen edge: keep it where it was.
        local along=s.nearAlong/scale
        if s.nearDock=="top" then f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",along,0)
        elseif s.nearDock=="bottom" then f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",along,0)
        elseif s.nearDock=="left" then f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",0,-along)
        else f:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",0,-along) end
    elseif s.nearX and s.nearY then f:SetPoint(corner,UIParent,"BOTTOMLEFT",s.nearX/scale,s.nearY/scale)
    else
        -- First time: a little right of and above the middle of the screen,
        -- clear of the default action bars and of your character.
        corner=CORNER[s.nearDock] or "TOPLEFT"
        local x=corner=="TOPRIGHT" and 180+WIDTH or 180
        local y=corner=="BOTTOMLEFT" and 40 or 200
        f:SetPoint(corner,UIParent,"CENTER",x/scale,y/scale)
    end
    -- Players seen in a fight are listed on the side the list grows to.
    local extra=f.extra; extra:SetScale(scale); extra:ClearAllPoints()
    self:PlaceExtra()
end
-- New rows continue the list with the same spacing: over the list's end
-- padding when it shows rows, right after the title bar when it shows none.
function E:PlaceExtra()
    local f=self.strip; if not f or not f.extra then return end
    local pad=(f.shownRows or 0)>0 and 6 or 0
    f.extra:ClearAllPoints()
    if self:Settings().nearDock=="bottom" then f.extra:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,-pad) else f.extra:SetPoint("TOPLEFT",f,"BOTTOMLEFT",0,pad) end
    self:FitPanel()
end
-- The window's background covers the list and, in a fight, the rows under it.
function E:FitPanel()
    local f=self.strip; if not f or not f.panel then return end
    local panel,extra=f.panel,f.extra
    panel:ClearAllPoints()
    if extra and extra:IsShown() then
        if self:Settings().nearDock=="bottom" then
            panel:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT"); panel:SetPoint("TOPRIGHT",extra,"TOPRIGHT")
        else
            panel:SetPoint("TOPLEFT",f,"TOPLEFT"); panel:SetPoint("BOTTOMRIGHT",extra,"BOTTOMRIGHT")
        end
    else panel:SetAllPoints(f) end
end
-- wasOpen: whether the rows showed before the click. The secure click has
-- already folded or opened the list (in a fight too); this follows it.
-- /ft nearbydebug: why clicking a name doesn't target (hover a name, type it).
function E:NearbyDebug()
    local f=self.strip
    print("ForeverTools nearby list ("..(FT.version or "?")..") in fight: "..tostring(InCombatLockdown and InCombatLockdown()))
    if not f then print("No list yet."); return end
    local function lv(x) local ok,v=pcall(x.GetFrameLevel,x); return ok and v or "?" end
    print(("List: shown %s level %s strata %s mouse %s protected %s"):format(tostring(f:IsShown()),lv(f),tostring(f:GetFrameStrata()),tostring(f:IsMouseEnabled()),tostring(f.IsProtected and f:IsProtected())))
    local h=f.holder; if h then print(("Holder: shown %s level %s mouse %s"):format(tostring(h:IsShown()),lv(h),tostring(h:IsMouseEnabled()))) end
    for i,row in ipairs(f.rows) do
        if row:IsShown() then
            local okT,t=pcall(row.GetAttribute,row,"type"); local okM,m=pcall(row.GetAttribute,row,"macrotext")
            print(("Row %d: level %s mouse %s visible %s type %s text %s"):format(i,lv(row),tostring(row:IsMouseEnabled()),tostring(row:IsVisible()),tostring(okT and t),tostring(okM and m)))
        end
    end
    for i,row in ipairs(f.extra and f.extra.rows or {}) do if row:IsShown() then print("Row first seen in this fight (not clickable until it ends): "..tostring(row.entry and row.entry.name)) end end
    local foci=GetMouseFoci and GetMouseFoci() or {GetMouseFocus and GetMouseFocus()}
    for i,frame in ipairs(foci or {}) do
        local chain={}; local x=frame
        for _=1,6 do if not x then break end; local okN,n=pcall(x.GetName,x); chain[#chain+1]=(okN and n) or (x==f and "list") or (x==h and "holder") or "?"; x=x.GetParent and x:GetParent() end
        print("Under the mouse: "..table.concat(chain," < ").."  level "..lv(frame))
    end
    print("Mouse-down casting (ActionButtonUseKeyDown): "..tostring(GetCVar and GetCVar("ActionButtonUseKeyDown")))
end
function E:ToggleCollapsed(wasOpen)
    local s=self:Settings()
    local f=self.strip
    local holder=f and f.holder
    if wasOpen~=nil and holder and holder:IsShown()~=wasOpen then
        s.nearCollapsed=not holder:IsShown()
    elseif busy() then
        FT:Toast("Collapse or open the list after the fight.",3); return
    else
        s.nearCollapsed=not s.nearCollapsed
    end
    if busy() then
        -- In a fight only the look follows; the rest after it.
        f.toggle.tex:SetTexture(s.nearCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        if s.nearCollapsed then f.extra:Hide() end
        self.pendingLayout=true; self:FitPanel()
        return
    end
    self:UpdateStrip(); self:Refresh()
end
function E:StripEntries()
    local s=self:Settings(); local list={}; local t=now()
    for guid,e in pairs(self.seen) do
        if e.unit or t-(e.last or 0)<=s.nearTime then list[#list+1]=e
        elseif t-(e.last or 0)>600 then self.seen[guid]=nil end
    end
    table.sort(list,function(a,b)
        local ma,mb=self:IsMarked(a) and 1 or 0,self:IsMarked(b) and 1 or 0
        if ma~=mb then return ma>mb end
        return (a.last or 0)>(b.last or 0)
    end)
    return list
end
local function targetText(e)
    local name=e.name or ""
    if e.realm then name=name.."-"..e.realm end
    return "/targetexact "..name
end
-- The header: full (title and count) or, collapsed or empty, a small tab.
function E:LayoutHeader(f,count,compact)
    local s=self:Settings()
    local fromBottom=s.nearDock=="bottom"
    local y=fromBottom and 0 or 0
    f.toggle:ClearAllPoints(); f.swords:ClearAllPoints(); f.title:ClearAllPoints(); f.move:ClearAllPoints()
    local anchor=fromBottom and "BOTTOMLEFT" or "TOPLEFT"
    local dy=fromBottom and 5 or -5
    f.toggle:SetPoint(anchor,6,dy)
    -- Always there, empty or not: + when folded, - when open.
    f.toggle.tex:SetTexture(s.nearCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    f.toggle:Show()
    f.swords:SetPoint("LEFT",f.toggle,"RIGHT",4,0)
    f.title:SetPoint("LEFT",f.swords,"RIGHT",5,0)
    f.title:SetText(VIEW_TITLE[self.view or "near"].." ("..count..")")
    f.move:SetPoint(fromBottom and "BOTTOMRIGHT" or "TOPRIGHT",-6,fromBottom and 4 or -4)
    f.move.tex:SetVertexColor(self.movingStrip and 1 or .75,self.movingStrip and .82 or .75,self.movingStrip and 0 or .75)
    return y
end
function E:UpdateStrip()
    local s=self:Settings()
    if not s.nearby and not self.movingStrip and not self.previewStrip then
        if self.strip and not busy() then self.strip:Hide(); self.strip.extra:Hide() end
        return
    end
    -- Its rows are secure buttons: they can only be made out of a fight
    -- (after a /reload in a fight the list comes when it ends).
    if not self.strip and busy() then self.pendingLayout=true; return end
    local f=self:Strip()
    local log=(self.view=="log" or self.view=="marked") and not self.previewStrip
    local list=self.previewStrip or (log and (self.view=="marked" and self:MarkEntries() or self:LogEntries())) or self:StripEntries()
    local active=self:Active() or self.movingStrip or self.previewStrip or log
    if not active then list={} end
    if busy() then return self:UpdateInFight(f,list,log) end
    self.pendingLayout=nil
    local count=#list
    local compact=s.nearCollapsed or count==0
    self:LayoutHeader(f,count,compact)
    local offset=log and math.max(0,math.min(self.logOffset or 0,count-s.nearRows)) or 0
    if log then self.logOffset=offset end
    -- The rows are filled even while folded, so opening the list in a
    -- fight shows them right away.
    local filled=math.max(0,math.min(s.nearRows,count-offset))
    local shown=compact and 0 or filled
    local fromBottom=s.nearDock=="bottom"
    for i=1,MAXROWS do
        local row=f.rows[i]
        if i<=filled then
            local e=list[i+offset]
            fillRow(row,e)
            row.guid=e.guid or e.name
            row:SetAttribute("macrotext",targetText(e))
            row:ClearAllPoints()
            if fromBottom then row:SetPoint("BOTTOMLEFT",6,HEADER+(i-1)*ROW) else row:SetPoint("TOPLEFT",6,-HEADER-(i-1)*ROW) end
            row:Show()
        else row.guid=nil; row.entry=nil; row:SetAttribute("macrotext",nil); row:Hide() end
    end
    -- Collapsed (or empty) it is just the header, as wide as the list.
    f:SetSize(WIDTH,HEADER+(shown>0 and (shown*ROW+6) or 0)); f.shownRows=shown
    f.holder:SetShown(not s.nearCollapsed)
    if f.toggle.SetAttribute then
        f.toggle:SetAttribute("closedHeight",HEADER)
        f.toggle:SetAttribute("openHeight",HEADER+(filled>0 and (filled*ROW+6) or 0))
    end
    -- While moving, the rows let the mouse through: drag the box anywhere.
    for i=1,MAXROWS do f.rows[i]:EnableMouse(not self.movingStrip) end
    f.extra:Hide()
    -- With "on mouseover" the bar stays in place (see-through) so the mouse
    -- can find it; it shows when someone is near, after an alert, or hovered.
    -- The list stays in place (hidden from view while empty) so it can
    -- appear in a fight too, when frames like it may not be shown anew.
    local want=active and (s.nearby or self.movingStrip) and (count>0 or self.movingStrip or s.nearShowEmpty or s.nearFade or log)
    local present=(self:Active() or self.movingStrip or self.previewStrip) and (s.nearby or self.movingStrip or self.previewStrip) and true or false
    if present then if not f:IsShown() then self:PlaceStrip(); f:Show() end else f:Hide() end
    self.stripDormant=present and not want
    self.fightCount=nil
    -- Empty and out of sight: the mouse goes straight through it.
    local mouse=not self.stripDormant
    for _,part in ipairs({f,f.titleButton,f.toggle,f.move}) do part:EnableMouse(mouse) end
    f:EnableMouseWheel(mouse)
    self:FadeStrip(count)
end
function E:FadeStrip(count)
    local f=self.strip; if not f then return end
    local s=self:Settings()
    if count then self.stripCount=count end
    if self.stripDormant and not self.fightCount then f:SetAlpha(0); if f.extra then f.extra:SetAlpha(0) end; return end
    local visible=not s.nearFade or self.movingStrip or self.previewStrip or (self.view or "near")~="near" or f.wasOver
        or (self.stripCount or 0)>0 or now()<(self.wakeUntil or 0)
    f:SetAlpha(visible and 1 or 0)
    if f.extra then f.extra:SetAlpha(f:GetAlpha()) end
end
-- An alert (stealth, marked player) brings the bar up for a while.
function E:Wake(seconds) self.wakeUntil=now()+(seconds or 10); self:FadeStrip() end
-- The log: everyone you have met (this account), newest first.
-- The log keeps today's players only: from the next day they are forgotten
-- (marked players stay in Marked).
local function day(t) return date and date("%Y-%m-%d",t) or "" end
function E:Log()
    if type(FT.db.enemyLog)~="table" then FT.db.enemyLog={} end
    local log=FT.db.enemyLog
    local today=day(stamp())
    if self.logDay~=today then
        self.logDay=today
        for k,e in pairs(log) do if type(e)~="table" or day(e.seen or 0)~=today then log[k]=nil end end
    end
    return log
end
local LOG_MAX=300
function E:LogSaw(info)
    if not info or not info.name then return end
    local log=self:Log(); local key=self:Key(info)
    local e=log[key]
    local t=stamp()
    if not e then
        e={first=t,times=0}; log[key]=e
        local n=0; for _ in pairs(log) do n=n+1 end
        if n>LOG_MAX then
            local oldest,okey
            for k,v in pairs(log) do if not oldest or (v.seen or 0)<oldest then oldest,okey=v.seen or 0,k end end
            if okey then log[okey]=nil end
        end
    end
    -- A new meeting once five minutes have passed.
    if t-(e.seen or 0)>300 then e.times=(e.times or 0)+1 end
    e.name=info.name; e.realm=info.realm; e.class=info.class or e.class; e.level=info.level or e.level
    e.race=info.race or e.race; e.guild=info.guild or e.guild; e.seen=t
    local zone=GetRealZoneText and text(GetRealZoneText()); if zone then e.zone=zone end
end
function E:LogEntries()
    local list={}
    for _,e in pairs(self:Log()) do e.logged=true; list[#list+1]=e end
    table.sort(list,function(a,b) return (a.seen or 0)>(b.seen or 0) end)
    return list
end
-- Marked players as a list view: who, why (hover), when last seen.
function E:MarkEntries()
    local list={}
    for _,m in pairs(self:Marks()) do if type(m)=="table" and m.name then m.logged=true; list[#list+1]=m end end
    table.sort(list,function(a,b) return (a.seen or 0)>(b.seen or 0) end)
    return list
end
function E:ToggleView()
    if busy() then FT:Toast("Switch the list after the fight.",3); return end
    self.view=VIEW_NEXT[self.view or "near"]; self.logOffset=0
    self:UpdateStrip()
end
function E:ScrollLog(delta)
    if (self.view or "near")=="near" or busy() then return end
    self.logOffset=math.max(0,(self.logOffset or 0)-delta*3)
    self:UpdateStrip()
end
function E:ClearLog() FT.db.enemyLog={}; self.logOffset=0; self:UpdateStrip(); self:Refresh() end
-- In a fight: the rows keep who they are (a click still targets them); their
-- text and fading update. New players are listed below in plain rows.
function E:UpdateInFight(f,list,log)
    self.pendingLayout=true
    if #list>0 then self.fightCount=true end
    f.title:SetText(VIEW_TITLE[self.view or "near"].." ("..#list..")")
    self:FadeStrip(#list)
    local byKey={}
    for _,e in ipairs(list) do byKey[e.guid or e.name]=e end
    local listed={}
    for _,row in ipairs(f.rows) do
        if row.guid then
            local e=byKey[row.guid] or self.seen[row.guid]
            if e then fillRow(row,e); listed[row.guid]=true end
        end
    end
    local extra=f.extra; local n=0
    for _,e in ipairs(log and {} or list) do
        local key=e.guid or e.name
        if not listed[key] and n<#extra.rows then
            n=n+1; local row=extra.rows[n]
            fillRow(row,e)
            row:ClearAllPoints()
            if self:Settings().nearDock=="bottom" then row:SetPoint("BOTTOMLEFT",6,(n-1)*ROW) else row:SetPoint("TOPLEFT",6,-(n-1)*ROW) end
            row:Show()
        end
    end
    for i=n+1,#extra.rows do extra.rows[i]:Hide() end
    if n>0 and f:IsShown() and not self:Settings().nearCollapsed then extra:SetSize(WIDTH,n*ROW+6); self:PlaceExtra(); extra:Show() else extra:Hide() end
    self:FitPanel()
end
local SAMPLE={{name="Sneakyboi",class="ROGUE",level=24,unit="nameplate1"},{name="Gankalot",class="WARRIOR",level=30},{name="Moonfury",class="DRUID",level=22,unit="nameplate2"},{name="Pewpew",class="HUNTER",level=25}}
-- Enough sample players to fill the longest list.
for i,pair in ipairs({{"Frostnova","MAGE"},{"Holyshock","PALADIN"},{"Dotsalot","WARLOCK"},{"Bubbles","PRIEST"},{"Totemic","SHAMAN"},{"Backstabz","ROGUE"},{"Charger","WARRIOR"},{"Treehugs","DRUID"},{"Arrowz","HUNTER"},{"Blinky","MAGE"},{"Felguard","WARLOCK"}}) do
    SAMPLE[#SAMPLE+1]={name=pair[1],class=pair[2],level=18+i}
end
function E:SetMovingStrip(on)
    if busy() then return end
    self.movingStrip=on and true or false
    self:Strip()
    self.previewStrip=(self.movingStrip or self.stripPreviewOn) and SAMPLE or nil
    for _,e in ipairs(SAMPLE) do e.last=now() end
    self:PlaceStrip(); self:UpdateStrip(); self:Refresh()
end
function E:PreviewStrip()
    if busy() then return end
    for _,e in ipairs(SAMPLE) do e.last=now() end
    self.previewStrip=SAMPLE; self:PlaceStrip(); self:UpdateStrip()
    local token={}; self.previewToken=token
    -- A quick look (a setting changed) ends by itself; the Preview switch stays on.
    C_Timer.After(6,function() if self.previewToken==token and not self.movingStrip and not self.stripPreviewOn then self.previewStrip=nil; self:UpdateStrip() end end)
end
function E:SetStripPreview(on)
    if on and busy() then on=false end
    self.stripPreviewOn=on and true or nil
    if on then self:PreviewStrip()
    elseif not self.movingStrip then self.previewStrip=nil; self.previewToken=nil; if not busy() then self:UpdateStrip() end end
    self:Refresh()
end
function E:ResetStrip() local s=self:Settings(); s.nearX,s.nearY,s.nearAlong,s.nearCorner=nil,nil,nil,nil; self:PlaceStrip() end
function E:SetDock(dock)
    local s=self:Settings(); if not DOCKS[dock] then dock="free" end
    -- The list stays where it is: only the corner it grows from changes.
    if self.strip and self.strip:GetLeft() and not busy() then
        if not (s.nearX or s.nearAlong) then self:PlaceStrip() end
        s.nearDock=dock; self:SavePlace()
    else s.nearDock=dock end
    self:PlaceStrip(); self:UpdateStrip(); self:Refresh()
end
-- After a fight the list is laid out again (new players get their own row).
local fightEnd=CreateFrame("Frame"); fightEnd:RegisterEvent("PLAYER_REGEN_ENABLED")
fightEnd:SetScript("OnEvent",function()
    if E.pendingLayout and FT.dbReady then E:PlaceStrip(); E:UpdateStrip() end
end)
-- Marking players -----------------------------------------------------------------
function E:Mark(info,note)
    if not info or not info.name then return end
    local key=self:Key(info)
    local marks=self:Marks()
    marks[key]=marks[key] or {added=stamp()}
    local m=marks[key]
    m.name=info.name; m.realm=info.realm; m.class=info.class or m.class; m.level=info.level or m.level; m.guild=info.guild or m.guild; m.seen=stamp()
    if note then m.note=note end
    -- You are looking at them: no "Marked player nearby" for this sighting.
    local seen=info.guid and self.seen[info.guid]
    if seen then seen.markedHere=true end
    self:RefreshMarks(); self:UpdateStrip()
    return key
end
function E:Unmark(key) self:Marks()[key]=nil; self:RefreshMarks(); self:UpdateStrip() end
-- Why you marked someone: asked right after marking (you may leave it
-- empty), changed later on the Marked players page.
function E:AskReason(key)
    local m=key and self:Marks()[key]; if not m then return end
    FT:AskText("Why are you marking "..(m.name or "this player").."? (optional)",m.note or "",function(value)
        value=type(value)=="string" and value:gsub("^%s+",""):gsub("%s+$","") or ""
        m.note=value~="" and value:sub(1,60) or nil; self:RefreshMarks()
    end,60)
end
function E:MarkUnit(unit)
    local info=self:Read(unit)
    if not info then FT:Toast("Target an enemy player to mark them.",3); return end
    local key=self:Key(info)
    if self:Marks()[key] then FT:Toast(info.name.." is already marked.",3); return key end
    key=self:Mark(info); FT:Toast("Marked "..info.name..". You will be alerted when they are near.",4)
    if not self:Settings().marks then FT:Toast("Marked "..info.name..". Turn on Marked player alerts to be warned.",5) end
    self:AskReason(key)
    return key
end
-- "Mark player" in the right-click menu of an enemy player's portrait.
function E:HookMenus()
    if self.menusHooked or not Menu or not Menu.ModifyMenu then return end
    self.menusHooked=true
    for _,tag in ipairs({"MENU_UNIT_ENEMY_PLAYER","MENU_UNIT_TARGET","MENU_UNIT_FOCUS","MENU_UNIT_PLAYER"}) do
        pcall(Menu.ModifyMenu,tag,function(_,root,context)
            local unit=context and context.unit
            if not plain(unit) or type(unit)~="string" then return end
            local info=self:Read(unit); if not info then return end
            local key=self:Key(info); local marked=self:Marks()[key]~=nil
            root:CreateDivider()
            root:CreateButton(marked and "Remove mark (ForeverTools)" or "Mark player (ForeverTools)",function()
                if marked then self:Unmark(key) else self:Mark(info); FT:Toast("Marked "..info.name..".",3); self:AskReason(key) end
            end)
        end)
    end
end
-- "Marked by you" on their tooltip.
function E:TooltipLine(tip)
    local s=self:Settings()
    if not s.marks or not s.markTooltip or tip~=GameTooltip then return end
    local ok,_,unit=pcall(tip.GetUnit,tip)
    if not ok or not plain(unit) or type(unit)~="string" then return end
    local info=self:Read(unit); if not info then return end
    local mark=self:IsMarked(info); if not mark then return end
    tip:AddLine(mark.note and ("Marked: "..mark.note) or "Marked by you",1,.3,.25,true)
    tip:Show()
end
-- Events -----------------------------------------------------------------------------
local events=CreateFrame("Frame")
local listening={"NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_SPELLCAST_SUCCEEDED","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","PLAYER_ENTERING_WORLD","UNIT_AURA"}
function E:Apply()
    local on=self:AnyOn()
    for _,event in ipairs(listening) do
        if on then pcall(events.RegisterEvent,events,event) else pcall(events.UnregisterEvent,events,event) end
    end
    if not on then self.plates={}; self.seen={} end
    if not self:Settings().nearby and self.strip and not self.movingStrip and not InCombatLockdown() then self.strip:Hide(); self.strip.extra:Hide() end
    if self:Settings().nearby then self:UpdateStrip() end
    if not self:Settings().stealth and not self:Settings().marks and self.notice and not self.moving then self.notice:Hide() end
    self:Refresh()
end
events:SetScript("OnEvent",function(_,event,unit,arg2,spellID)
    if not FT.dbReady then return end
    if event=="NAME_PLATE_UNIT_ADDED" then E:PlateAdded(unit)
    elseif event=="NAME_PLATE_UNIT_REMOVED" then E:PlateRemoved(unit)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then E:Cast(unit,spellID)
    elseif event=="UNIT_AURA" then E:AuraChanged(unit,arg2)
    elseif event=="PLAYER_TARGET_CHANGED" then if E:Active() then E:CheckSpotted("target"); E:Saw(E:Read("target"),nil) end
    elseif event=="UPDATE_MOUSEOVER_UNIT" then if E:Active() then E:CheckSpotted("mouseover"); E:Saw(E:Read("mouseover"),nil) end
    elseif event=="PLAYER_ENTERING_WORLD" then E.plates={}; E.seen={}; E:UpdateStrip() end
end)
local boot=CreateFrame("Frame"); boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent",function()
    E:HookMenus()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit~=nil then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tip) pcall(E.TooltipLine,E,tip) end)
    end
    if FT.dbReady then E:Apply() end
end)
FT:RegisterModule("Enemies",E)
FT.Enemies=E
-- Settings pages ---------------------------------------------------------------------
local function width(name) local hub=FT:HubOf(name); return hub and hub.width or 540 end
local alertSwitches={
    {"stealth","Stealth alerts","Ability_Stealth","Alert when an enemy player near you goes into stealth."},
    {"fade","Also when a rogue or druid drops from view","Ability_Vanish","Also alert when an enemy rogue, druid or night elf vanishes without dying. Alerts more often."},
    {"marks","Marked player alerts","Ability_Hunter_SniperShot","Red alert when a player you marked shows up."},
    {"flash","Screen-edge flash","Spell_Holy_SearingLight","The screen edges glow briefly with every alert."},
    {"sound","Sound","INV_Misc_Bell_01","Play the raid warning sound with every alert."},
    {"instances","Also in battlegrounds and arenas","INV_BannerPVP_01","Keep alerts and the list on in battlegrounds and arenas."},
}
function E:Refresh()
    local page=self.alertPage
    if page and page.frame then
        local s=self:Settings()
        for _,entry in ipairs(alertSwitches) do
            local b=page.buttons[entry[1]]
            b.label:SetText(entry[2]..": "..(s[entry[1]] and "On" or "Off")); FT:SetSelected(b,s[entry[1]])
        end
        page.buttons.fade:SetEnabled(s.stealth); page.buttons.fade:SetAlpha(s.stealth and 1 or .45)
        page.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
        page.settingSize=true; page.sizeSlider:SetValue(s.size); page.settingSize=false
        FT:RefreshPreview(page.frame)
        page.plates:SetText(self:NameplateNote())
        if FT.RefreshDock and page.frame:IsShown() then FT:RefreshDock(page.frame) end
    end
    local near=self.nearPage
    if near and near.frame then
        local s=self:Settings()
        near.toggle.label:SetText("Nearby enemies: "..(s.nearby and "On" or "Off")); FT:SetSelected(near.toggle,s.nearby)
        near.keep.label:SetText("Keep for: "..s.nearTime.." seconds")
        near.dock.label:SetText("Anchor to: "..(E.dockLabels[s.nearDock] or "None"))
        near.fade.label:SetText("Title bar: "..(s.nearFade and "On mouseover" or "Always")); FT:SetSelected(near.fade,s.nearFade)
        near.rowsLabel:SetText("Players shown: "..s.nearRows)
        near.settingRows=true; near.rowsSlider:SetValue(s.nearRows); near.settingRows=false
        near.empty.label:SetText("Show when no one is near: "..(s.nearShowEmpty and "On" or "Off")); FT:SetSelected(near.empty,s.nearShowEmpty)
        near.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.nearSize*100+.5)))
        near.settingSize=true; near.sizeSlider:SetValue(s.nearSize); near.settingSize=false
        FT:RefreshPreview(near.frame)
        near.plates:SetText(self:NameplateNote())
        if FT.RefreshDock and near.frame:IsShown() then FT:RefreshDock(near.frame) end
    end
    self:RefreshMarks()
end
-- Enemy players further away than your target are only seen through their nameplates.
function E:NameplateNote()
    local get=(C_CVar and C_CVar.GetCVar) or GetCVar
    local ok,value=pcall(function() return get and get("nameplateShowEnemies") end)
    if ok and value=="0" then return "|cffff9f5aEnemy nameplates are off|r, so only players you target or hover are seen." end
    return "Players are seen through nameplates, target and mouseover."
end
local function slider(frame,y,onChange)
    local s=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); s:SetSize(300,18); s:SetPoint("TOPLEFT",216,y)
    s:SetMinMaxValues(.7,1.5); s:SetValueStep(.05); s:SetObeyStepOnDrag(true)
    s:SetScript("OnValueChanged",function(_,v) onChange(math.floor(v*20+.5)/20) end)
    return s
end
local alertPage={}
E.alertPage=alertPage
function alertPage:Open()
    if not self.frame then
        local w=width("EnemyAlerts")
        local frame=FT:Window("ForeverToolsEnemyAlerts","Enemy alerts",w,520); self.frame=frame
        FT:PageInfo(frame,"Enemy alerts","A warning when an enemy player near you goes into stealth, and a red one when a player you marked shows up.\n\nOnly players you can see count: nameplates, target, mouseover. Someone already in stealth is noticed when you get close enough to see them. Someone you duel counts too.")
        self.buttons={}
        for i,entry in ipairs(alertSwitches) do
            local key=entry[1]
            local b=(i==1 and FT.AccentButton or FT.QuietButton)(FT,frame,"",w-48,32,entry[3]); b:SetPoint("TOPLEFT",24,-66-(i-1)*38)
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            b:SetScript("OnClick",function() local s=E:Settings(); s[key]=not s[key]; E:Apply() end)
            FT:Tooltip(b,entry[2],entry[4])
            self.buttons[key]=b
        end
        local y=-66-#alertSwitches*38-8
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,y-2)
        self.sizeSlider=slider(frame,y,function(v) if self.settingSize then return end E:Settings().size=v; E:Position(); E:Refresh() end)
        FT:Tooltip(self.sizeSlider,"Size","Alert size (70% to 150%).")
        local reset=FT:QuietButton(frame,"Reset position",(w-60)/2,32,"reset"); reset:SetPoint("TOPLEFT",24,y-36)
        reset:SetScript("OnClick",function() E:ResetPosition() end)
        FT:Tooltip(reset,"Reset position","Put the alert back near the top of the screen.")
        self.plates=FT:Label(frame,"",12); self.plates:SetPoint("TOPLEFT",24,y-78); self.plates:SetWidth(w-48); self.plates:SetTextColor(.66,.59,.48)
        FT:Sections(frame,{{"Stealth",self.buttons.stealth},{"Marked players",self.buttons.marks},{"Alert",self.buttons.flash},{"Look and position",self.sizeLabel}})
        if self.plates.SetWordWrap then self.plates:SetWordWrap(true) end
        self.preview=FT:TopPreview(frame,self.buttons.stealth,{get=function() return (E.previewKind or E.moving) and true or false end,
            set=function(on) if on then E:SetPreviewKind("stealth"); E:SetMoving(true) else E:SetMoving(false); E:SetPreviewKind(nil) end end,
            tip="An example stealth alert."})
    end
    E:Refresh(); self.frame:Show()
end
function alertPage:Refresh() E:Refresh() end
function alertPage:Peek() local f=E.notice; if E.previewKind then E:Preview(E.previewKind) elseif not (f and f:IsShown()) then E:Preview("stealth") end end
FT:RegisterModule("EnemyAlerts",alertPage)
-- Marked players
local markPage={}
E.markPage=markPage
local ROW=44
function E:RefreshMarks()
    local page=self.markPage
    if not page or not page.frame then return end
    local s=self:Settings()
    page.alerts.label:SetText("Marked player alerts: "..(s.marks and "On" or "Off")); FT:SetSelected(page.alerts,s.marks)
    page.tip.label:SetText("Show the mark in tooltips: "..(s.markTooltip and "On" or "Off")); FT:SetSelected(page.tip,s.markTooltip)
    page.tip:SetEnabled(s.marks); page.tip:SetAlpha(s.marks and 1 or .45)
    local keys={}
    for key in pairs(self:Marks()) do keys[#keys+1]=key end
    table.sort(keys,function(a,b) return (self:Marks()[a].seen or 0)>(self:Marks()[b].seen or 0) end)
    local w=page.content:GetWidth()
    for i,key in ipairs(keys) do
        local m=self:Marks()[key]
        local r=page.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,page.content); r:SetSize(w,ROW-4); page.rows[i]=r
            r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(28,28); r.icon:SetPoint("LEFT",4,0); FT:RoundIcon(r.icon)
            r.name=FT:Label(r,"",14); r.name:SetPoint("TOPLEFT",40,-3); r.name:SetWidth(w-250); r.name:SetJustifyH("LEFT")
            r.meta=FT:Label(r,"",11); r.meta:SetPoint("TOPLEFT",40,-21); r.meta:SetWidth(w-250); r.meta:SetJustifyH("LEFT"); r.meta:SetTextColor(.72,.66,.55)
            if r.meta.SetWordWrap then r.meta:SetWordWrap(false); r.name:SetWordWrap(false) end
            r.remove=FT:QuietButton(r,"Remove",108,28,"delete"); r.remove:SetPoint("RIGHT",-2,0)
            FT:Tooltip(r.remove,"Remove mark","Stop alerting for this player.")
            r.note=FT:QuietButton(r,"Reason",96,28,"INV_Misc_Note_01"); r.note:SetPoint("RIGHT",r.remove,"LEFT",-6,0)
            FT:Tooltip(r.note,"Reason","A few words, shown on the alert and their tooltip.")
        end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,-(i-1)*ROW)
        r.icon:SetTexture(self:ClassIcon(m.class))
        local cr,cg,cb=self:ClassColor(m.class)
        r.name:SetText(string.format("|cff%02x%02x%02x%s|r",cr*255,cg*255,cb*255,m.name or "?")..(m.note and ("  |cffff8c73"..m.note.."|r") or "  |cff6f6656(no reason)|r"))
        local B=FT.Bags
        r.meta:SetText(self:Describe(m)..(m.guild and ("  <"..m.guild..">") or "").." · seen "..(B and B:Ago(m.seen) or "?"))
        r.remove:SetScript("OnClick",function() self:Unmark(key) end)
        r.note:SetScript("OnClick",function() self:AskReason(key) end)
        r:Show()
    end
    for i=#keys+1,#page.rows do page.rows[i]:Hide() end
    page.content:SetHeight(math.max(1,#keys*ROW))
    page.none:SetShown(#keys==0)
    if FT.RefreshDock and page.frame:IsShown() then FT:RefreshDock(page.frame) end
end
function markPage:Open()
    if not self.frame then
        local w=width("EnemyMarks")
        local frame=FT:Window("ForeverToolsEnemyMarks","Marked players",w,520); self.frame=frame
        FT:PageInfo(frame,"Marked players","Players you want to know about. When one shows up you get a red alert, on all your characters.\n\nMark: target them and click Mark my target, right-click their portrait or their row in the enemy list, or /ft mark.")
        self.alerts=FT:AccentButton(frame,"",w-48,32,"Ability_Hunter_SniperShot"); self.alerts:SetPoint("TOPLEFT",24,-66)
        self.alerts:SetScript("OnClick",function() local s=E:Settings(); s.marks=not s.marks; E:Apply() end)
        FT:Tooltip(self.alerts,"Marked player alerts","Red alert when a player you marked shows up.")
        self.tip=FT:QuietButton(frame,"",w-48,32,"tooltip"); self.tip:SetPoint("TOPLEFT",24,-104)
        if self.tip.SetMotionScriptsWhileDisabled then self.tip:SetMotionScriptsWhileDisabled(true) end
        self.tip:SetScript("OnClick",function() local s=E:Settings(); s.markTooltip=not s.markTooltip; E:Refresh() end)
        FT:Tooltip(self.tip,"Show the mark in tooltips","Show \"Marked\" and your reason on their tooltip.")
        local mark=FT:QuietButton(frame,"Mark my target",w-48,32,"add"); mark:SetPoint("TOPLEFT",24,-142)
        mark:SetScript("OnClick",function() E:MarkUnit("target") end)
        FT:Tooltip(mark,"Mark my target","Mark the enemy player you are targeting.")
        local scroll=CreateFrame("ScrollFrame","ForeverToolsEnemyMarksScroll",frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",24,-186); scroll:SetPoint("BOTTOMRIGHT",-40,20)
        self.content=CreateFrame("Frame",nil,scroll); self.content:SetSize(w-72,1); scroll:SetScrollChild(self.content)
        FT:AutoHideScrollBar(scroll)
        self.rows={}
        self.none=FT:Label(frame,"No marked players yet.",12); self.none:SetPoint("TOPLEFT",24,-192); self.none:SetTextColor(.66,.59,.48)
    end
    E:Refresh(); self.frame:Show()
end
function markPage:Refresh() E:Refresh() end
FT:RegisterModule("EnemyMarks",markPage)
-- Nearby enemies
local nearPage={}
E.nearPage=nearPage
local dockLabels={free="None",top="Top",bottom="Bottom",left="Left",right="Right"}
local dockTips={
    free="Grows downwards from where you put it.",
    top="Grows downwards.",
    bottom="Grows upwards. Good near the bottom of the screen.",
    left="Grows downwards.",
    right="Grows downwards.",
}
E.dockLabels=dockLabels
function nearPage:Open()
    if not self.frame then
        local w=width("EnemyNearby")
        local frame=FT:Window("ForeverToolsEnemyNearby","Nearby enemies",w,520); self.frame=frame
        FT:PageInfo(frame,"Nearby enemies","Enemy players you saw lately. Click a name to target them; right-click it to mark them. Marked players come first, in red.\n\nClick the title for everyone you met today (Seen before), then your marked players.")
        self.toggle=FT:AccentButton(frame,"",w-48,32,"Ability_Hunter_SniperShot"); self.toggle:SetPoint("TOPLEFT",24,-66)
        self.toggle:SetScript("OnClick",function() local s=E:Settings(); s.nearby=not s.nearby; E:Apply() end)
        FT:Tooltip(self.toggle,"Nearby enemies","Show enemy players you saw recently. Click a name to target.")
        self.keep=FT:QuietButton(frame,"",w-48,32,"INV_Misc_PocketWatch_01"); self.keep:SetPoint("TOPLEFT",24,-104)
        self.keep.options=function()
            local out={}
            for _,v in ipairs({15,30,60,120}) do out[#out+1]={value=v,label=v.." seconds",icon="Interface\\Icons\\INV_Misc_PocketWatch_01",tooltip="Keep a player in the list for "..v.." seconds after you last saw them."} end
            return out
        end
        self.keep.onSelect=function(v) E:Settings().nearTime=v; E:UpdateStrip(); E:Refresh() end
        self.keep:SetScript("OnClick",function(owner) owner.value=E:Settings().nearTime; owner.menuWidth=w-48; FT:ShowChoices(owner) end)
        FT:Tooltip(self.keep,"Keep for","How long a player stays in the list.")
        self.dock=FT:QuietButton(frame,"",w-48,32,"move"); self.dock:SetPoint("TOPLEFT",24,-142)
        self.dock.options=function()
            local out={}
            for _,v in ipairs(E.DOCKS) do out[#out+1]={value=v,label=dockLabels[v],tooltip=dockTips[v],icon="Interface\\Icons\\Ability_DualWield"} end
            return out
        end
        self.dock.onSelect=function(v) E:SetDock(v); E:PreviewStrip() end
        self.dock:SetScript("OnClick",function(owner) owner.value=E:Settings().nearDock; owner.menuWidth=w-48; FT:ShowChoices(owner) end)
        FT:Tooltip(self.dock,"Anchor to","Which way the list grows. It never moves when you pick one.")
        self.fade=FT:QuietButton(frame,"",w-48,32,"INV_Misc_Spyglass_02"); self.fade:SetPoint("TOPLEFT",24,-180)
        FT:MakeChoice(self.fade,{{false,"Always","The title bar is always shown."},{true,"On mouseover","Invisible until you point at it or someone is near."}},function() return E:Settings().nearFade==true end,function(v) E:Settings().nearFade=v; E:UpdateStrip(); E:Refresh() end)
        FT:Tooltip(self.fade,"Title bar","When the title bar shows.")
        self.empty=FT:QuietButton(frame,"",w-48,32,"INV_Misc_Note_04"); self.empty:SetPoint("TOPLEFT",24,-218)
        self.empty:SetScript("OnClick",function() local s=E:Settings(); s.nearShowEmpty=not s.nearShowEmpty; E:UpdateStrip(); E:Refresh() end)
        FT:Tooltip(self.empty,"Show when no one is near","Keep the empty list on screen.")
        self.rowsLabel=FT:Label(frame,"",14); self.rowsLabel:SetPoint("TOPLEFT",24,-264)
        self.rowsSlider=slider(frame,-262,function() end)
        self.rowsSlider:SetMinMaxValues(1,8); self.rowsSlider:SetValueStep(1)
        self.rowsSlider:SetScript("OnValueChanged",function(_,v)
            if self.settingRows then return end
            E:Settings().nearRows=math.floor(v+.5); E:PreviewStrip(); E:Refresh()
        end)
        FT:Tooltip(self.rowsSlider,"Players shown","Most players shown (1 to 8).")
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,-298)
        self.sizeSlider=slider(frame,-296,function(v) if self.settingSize then return end E:Settings().nearSize=v; E:PlaceStrip(); E:Refresh() end)
        FT:Tooltip(self.sizeSlider,"Size","List size (70% to 150%).")
        local reset=FT:QuietButton(frame,"Reset position",(w-60)/2,32,"reset"); reset:SetPoint("TOPLEFT",24,-332)
        local clear=FT:QuietButton(frame,"Clear the log",(w-60)/2,32,"delete"); clear:SetPoint("LEFT",reset,"RIGHT",12,0)
        clear:SetScript("OnClick",function() FT:Confirm("Forget every player in the log? Marks stay.",function() E:ClearLog() end) end)
        FT:Tooltip(clear,"Clear the log","Forget players you met before. Marks stay.")
        reset:SetScript("OnClick",function() E:ResetStrip() end)
        FT:Tooltip(reset,"Reset position","Put the list back in its starting place.")
        self.plates=FT:Label(frame,"",12); self.plates:SetPoint("TOPLEFT",24,-376); self.plates:SetWidth(w-48); self.plates:SetTextColor(.66,.59,.48)
        FT:Sections(frame,{{"List",self.keep},{"Look and position",self.dock}})
        if self.plates.SetWordWrap then self.plates:SetWordWrap(true) end
        self.preview=FT:TopPreview(frame,self.toggle,{get=function() return (E.stripPreviewOn or E.movingStrip) and true or false end,
            set=function(on) E:SetStripPreview(on); E:SetMovingStrip(on) end,tip="An example list; drag it by its title."})
    end
    E:Refresh(); self.frame:Show()
end
function nearPage:Refresh() E:Refresh() end
function nearPage:Peek() if not E.previewStrip then E:PreviewStrip() end end
FT:RegisterModule("EnemyNearby",nearPage)
