local _,FT=...
-- Interrupt bar (Combat > Interrupt bar, off by default). One slim bar per
-- group member's interrupt, showing when it is ready again, so you can plan
-- who kicks next.
--   * Your own interrupts are read from your casts (always exact).
--   * Group members with ForeverTools send theirs over the addon channel the
--     moment they use one, with their real cooldown; they also say which
--     interrupts they know, so their row shows "Ready" before the first kick.
--   * Group members without ForeverTools show up when the game lets us see
--     their cast (it hides other players' spells at times, mostly in fights);
--     their cooldown is then the usual one for that spell.
--   * Earth Shock shares its cooldown with Flame Shock and Frost Shock: any
--     shock puts the interrupt on cooldown.
--   * A plain frame of ours: shown, hidden and updated in fights too. The
--     timer only runs while something is cooling down.
local I={rows={},entries={}}
-- Interrupts (and a few stuns or silences that stop a cast), by spell name.
-- Cooldowns are the usual ones; your own come from the game.
local SPELLS={
    ["Kick"]={cd=10,icon="Ability_Kick"},
    ["Pummel"]={cd=10,icon="INV_Gauntlets_04"},
    ["Shield Bash"]={cd=12,icon="Ability_Warrior_ShieldBash"},
    ["Earth Shock"]={cd=6,icon="Spell_Nature_EarthShock"},
    ["Counterspell"]={cd=24,icon="Spell_Frost_IceShock"},
    ["Hammer of Justice"]={cd=60,icon="Spell_Holy_SealOfMight"},
    ["Silence"]={cd=45,icon="Spell_Shadow_ImpPhaseShift"},
    ["Spell Lock"]={cd=24,icon="Spell_Shadow_MindRot"},
    ["Bash"]={cd=60,icon="Ability_Druid_Bash"},
    ["Feral Charge"]={cd=15,icon="Ability_Hunter_Pet_Bear"},
}
I.SPELLS=SPELLS
local SHARED={["Flame Shock"]="Earth Shock",["Frost Shock"]="Earth Shock"}
local PREFIX="FTINT"
local ROW_GAP=2
local function safe(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function now() return GetTime and GetTime() or 0 end
local function busy() return InCombatLockdown and InCombatLockdown() end
function I:Settings()
    if type(FT.db.interrupts)~="table" then FT.db.interrupts={} end
    local s=FT.db.interrupts
    if type(s.enabled)~="boolean" then s.enabled=false end
    if s.when~="group" and s.when~="combat" and s.when~="always" then s.when="group" end
    if s.grow~="up" and s.grow~="down" then s.grow=s.dock=="bottom" and "up" or "down" end
    if type(s.self)~="boolean" then s.self=true end
    if type(s.solo)~="boolean" then s.solo=false end
    s.width=math.max(120,math.min(320,tonumber(s.width) or 190))
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    -- Most rows at once (a 40-player battleground never floods the screen).
    s.rows=math.floor(math.max(1,math.min(20,tonumber(s.rows) or 8)))
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    -- "Anchor to" is gone (Grow does the job). A bar kept by its right edge
    -- is now kept by its left edge, at the same spot on screen.
    if s.dock~=nil then
        if s.dock=="right" and s.x then s.x=s.x-s.width*s.size end
        s.dock=nil
    end
    return s
end
-- Spell name for a spell ID, when the game lets us read it.
local function spellName(id)
    if not safe(id) then return end
    local name
    if C_Spell and C_Spell.GetSpellName then local ok,n=pcall(C_Spell.GetSpellName,id); if ok then name=n end end
    if not name and GetSpellInfo then local ok,n=pcall(GetSpellInfo,id); if ok then name=n end end
    if safe(name) and type(name)=="string" then return name end
end
-- Your group: name -> unit, class.
function I:Roster()
    local out={}
    local function add(unit)
        if not UnitExists or not UnitExists(unit) then return end
        local name=UnitName(unit); local _,class=UnitClass(unit)
        if safe(name) and name then out[name]={unit=unit,class=safe(class) and class or nil} end
    end
    add("player")
    if IsInRaid and IsInRaid() then for i=1,40 do add("raid"..i) end
    elseif IsInGroup and IsInGroup() then for i=1,4 do add("party"..i) end end
    return out
end
function I:InGroup() return (IsInGroup and IsInGroup()) and true or false end
-- An interrupt was used (or is known): start or keep its row.
function I:Note(name,spell,cd,used,source)
    if not name or not SPELLS[spell] then return end
    local key=name.."|"..spell
    local e=self.entries[key]
    if not e then e={name=name,spell=spell}; self.entries[key]=e end
    e.cd=tonumber(cd) and tonumber(cd)>0 and tonumber(cd) or e.cd or SPELLS[spell].cd
    e.source=source or e.source
    if used then e.readyAt=now()+e.cd end
    self:Changed()
end
-- Your own interrupts: the ones you know, with the game's cooldown.
function I:Own()
    local learned=FT.modules.BuffReminder and FT.modules.BuffReminder:Learned() or {}
    local me=UnitName and UnitName("player")
    local out={}
    for spell in pairs(SPELLS) do
        local info=learned[spell]
        if info then
            local cd
            if GetSpellBaseCooldown and info.value then local ok,ms=pcall(GetSpellBaseCooldown,info.value); if ok and safe(ms) and type(ms)=="number" and ms>0 then cd=ms/1000 end end
            out[spell]=cd or SPELLS[spell].cd
        end
    end
    self.own=out
    if safe(me) and me then
        for spell,cd in pairs(out) do self:Note(me,spell,cd,false,"self") end
    end
    return out
end
-- Tell your group which interrupts you know (once in a while, not in fights).
function I:Announce()
    if not self:InGroup() or busy() or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    if self.announced and now()-self.announced<20 then return end
    self.announced=now()
    for spell,cd in pairs(self.own or self:Own()) do self:Send("K|"..spell.."|"..cd) end
end
function I:Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end
function I:Send(text)
    local channel=self:Channel()
    if channel and C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage,PREFIX,text,channel) end
end
-- Casts: yours (and your pet's), and the group's when the game shows them.
function I:Cast(unit,spellID)
    local name=spellName(spellID); if not name then return end
    local spell=SPELLS[name] and name or SHARED[name]; if not spell then return end
    local owner=unit
    if unit=="pet" then owner="player"
    elseif type(unit)=="string" and unit:find("pet",1,true) then owner=unit:gsub("pet","") end
    local who=UnitName and UnitName(owner)
    if not safe(who) or not who then return end
    if owner=="player" then
        local cd=(self.own and self.own[spell]) or SPELLS[spell].cd
        self:Note(who,spell,cd,true,"self")
        self:Send("U|"..spell.."|"..cd)
    else
        local e=self.entries[who.."|"..spell]
        -- A synced member reports it themselves (with the exact cooldown).
        if e and e.source=="sync" and e.readyAt and e.readyAt>now()-.5 then return end
        self:Note(who,spell,nil,true,e and e.source or "seen")
    end
end
function I:Message(text,sender)
    if not safe(text) or not safe(sender) or type(text)~="string" then return end
    local who=Ambiguate and Ambiguate(sender,"short") or sender
    if who==(UnitName and UnitName("player")) then return end
    local kind,spell,cd=text:match("^(%a)|([^|]+)|([%d%.]+)$")
    if not kind or not SPELLS[spell] then return end
    self:Note(who,spell,cd,kind=="U","sync")
end
-- Rows -------------------------------------------------------------------------
function I:Bar()
    if self.bar then return self.bar end
    local f=CreateFrame("Frame","ForeverToolsInterrupts",UIParent)
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(false); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if self.moving or self.preview then f:StartMoving() end end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SavePlace() end)
    FT:MoverBox(f,6)
    for _,t in ipairs(f.fillTextures) do t:Hide() end; for _,t in ipairs(f.borderTextures) do t:Hide() end
    f.name=FT:Label(f,"Interrupt bar",12); FT:Caption(f.name,f,"above",6); f.name:Hide()
    f.hint=FT:Label(f,"Drag to move",12); FT:Caption(f.hint,f,"below",6); f.hint:Hide()
    f:Hide()
    self.bar=f
    self:Place()
    return f
end
local function makeRow(self,f,i)
    local r=CreateFrame("Frame",nil,f)
    r.back=r:CreateTexture(nil,"BACKGROUND"); r.back:SetAllPoints(); r.back:SetColorTexture(0,0,0,.6)
    r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetPoint("LEFT"); FT:RoundIcon(r.icon)
    r.bar=CreateFrame("StatusBar",nil,r); r.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8"); r.bar:SetMinMaxValues(0,1)
    r.bar:SetPoint("TOPLEFT",r.icon,"TOPRIGHT",2,0); r.bar:SetPoint("BOTTOMRIGHT")
    r.name=FT:Label(r.bar,"",11); r.name:SetPoint("LEFT",4,0); r.name:SetJustifyH("LEFT")
    r.name:SetShadowColor(0,0,0,1); r.name:SetShadowOffset(1,-1); if r.name.SetWordWrap then r.name:SetWordWrap(false) end
    r.time=FT:Label(r.bar,"",11); r.time:SetPoint("RIGHT",-4,0); r.time:SetShadowColor(0,0,0,1); r.time:SetShadowOffset(1,-1)
    self.rows[i]=r
    local fonts=FT.modules.FontManager
    if fonts and fonts:Settings("interrupts").enabled then FT:Coalesce("interruptFonts",function() fonts:ApplyArea("interrupts") end) end
    return r
end
local function classColor(class)
    local c=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r,c.g,c.b end
    return .7,.7,.7
end
-- Who is shown: group members (and you), each interrupt once.
function I:List()
    local roster=self:Roster(); local s=self:Settings(); local out={}
    for key,e in pairs(self.entries) do
        local member=roster[e.name]
        if not member then self.entries[key]=nil
        elseif e.name~=(UnitName and UnitName("player")) or s.self then
            e.class=member.class; out[#out+1]=e
        end
    end
    local t=now()
    table.sort(out,function(a,b)
        local ra,rb=math.max(0,(a.readyAt or 0)-t),math.max(0,(b.readyAt or 0)-t)
        if ra~=rb then return ra<rb end
        if a.name~=b.name then return a.name<b.name end
        return a.spell<b.spell
    end)
    return out
end
-- Preview: made-up players of different classes, some cooling down, so the
-- bar can be sized and placed before a real group shows up.
local SAMPLE_NAMES={"Kickington","Shockwell","Frostina","Bashrock","Lightbane","Mindy","Felgrin","Barkley","Shieldra","Clawdia","Stabbs","Zapwick","Emberly","Gorrun","Thistle","Varn","Oakhide","Sparkle","Murk","Brannoc"}
local SAMPLE_KITS={{"ROGUE","Kick"},{"SHAMAN","Earth Shock"},{"MAGE","Counterspell"},{"WARRIOR","Pummel"},{"PALADIN","Hammer of Justice"},{"PRIEST","Silence"},{"WARLOCK","Spell Lock"},{"DRUID","Bash"},{"WARRIOR","Shield Bash"},{"DRUID","Feral Charge"}}
function I:Samples()
    local want=math.min(self:Settings().rows,#SAMPLE_NAMES)
    if self.samples and #self.samples==want then return self.samples end
    local names={}; for i,n in ipairs(SAMPLE_NAMES) do names[i]=n end
    local rnd=math.random
    for i=#names,2,-1 do local j=rnd(i); names[i],names[j]=names[j],names[i] end
    local out={}
    for i=1,want do
        local kit=SAMPLE_KITS[rnd(#SAMPLE_KITS)]; local cd=SPELLS[kit[2]].cd
        out[i]={name=names[i],class=kit[1],spell=kit[2],cd=cd,readyAt=rnd(2)==1 and now()+rnd()*cd or nil,sample=true}
    end
    self.samples=out
    return out
end
-- A setting changed while the bar is hidden: sample rows for a few seconds.
function I:Peek()
    if self.bar and self.bar:IsShown() and not self.peeking then return end
    self:Bar(); self.peeking=true
    local token={}; self.peekToken=token
    self:Paint()
    C_Timer.After(4,function() if self.peekToken==token then self.peeking=nil; self:Paint() end end)
end
function I:SetPreview(on)
    self.preview=on and true or false
    self.samples=nil
    self:Unlock(); self:Paint(); self:Refresh()
end
function I:Wanted()
    local s=self:Settings()
    if self.moving or self.preview or self.peeking then return true end
    if not s.enabled then return false end
    if s.when=="always" then return true end
    if not self:InGroup() and not s.solo then return false end
    if s.when=="combat" and not busy() and not self.fighting then return false end
    return true
end
local function short(left)
    if left>=10 then return tostring(math.floor(left+.5)) end
    return string.format("%.1f",left)
end
function I:Paint()
    local f=self.bar
    if not f then return end
    local show=self:Wanted()
    local list=show and self:List() or {}
    local sample=self.preview or ((self.moving or self.peeking) and #list==0)
    if sample then
        list={}; local t=now()
        for i,e in ipairs(self:Samples()) do
            -- Ready a little while, then used again: the preview keeps moving.
            if e.readyAt and e.readyAt<t-3 then e.readyAt=nil elseif not e.readyAt and math.random(40)==1 then e.readyAt=t+e.cd end
            list[i]=e
        end
        table.sort(list,function(a,b) local ra,rb=math.max(0,(a.readyAt or 0)-t),math.max(0,(b.readyAt or 0)-t); if ra~=rb then return ra<rb end; return a.name<b.name end)
    end
    local s=self:Settings()
    -- The ones ready soonest are kept when there are more than fit.
    for i=#list,s.rows+1,-1 do list[i]=nil end
    f:SetShown(show and #list>0)
    if not f:IsShown() then self:Tick(false); return end
    local h=18; local t=now(); local cooling=sample and true or false
    f:SetScale(s.size); f:SetSize(s.width,math.max(h,#list*(h+ROW_GAP)-ROW_GAP))
    for i,e in ipairs(list) do
        local r=self.rows[i] or makeRow(self,f,i)
        r:ClearAllPoints()
        if s.grow=="up" then r:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,(i-1)*(h+ROW_GAP)) else r:SetPoint("TOPLEFT",f,"TOPLEFT",0,-(i-1)*(h+ROW_GAP)) end
        r:SetSize(s.width,h)
        r.icon:SetSize(h,h); r.icon:SetTexture("Interface\\Icons\\"..SPELLS[e.spell].icon)
        local cr,cg,cb=classColor(e.class)
        local left=math.max(0,(e.readyAt or 0)-t)
        r.name:SetText(e.name); r.name:SetWidth(s.width-h-44)
        if left>0 then
            cooling=true
            r.bar:SetValue(1-left/(e.cd or 1)); r.bar:SetStatusBarColor(cr*.45,cg*.45,cb*.45,1)
            r.time:SetText(short(left)); r.time:SetTextColor(1,1,1); r.icon:SetDesaturated(true)
        else
            r.bar:SetValue(1); r.bar:SetStatusBarColor(cr,cg,cb,.85)
            r.time:SetText("Ready"); r.time:SetTextColor(.6,1,.6); r.icon:SetDesaturated(false)
        end
        r:Show()
    end
    for i=#list+1,#self.rows do self.rows[i]:Hide() end
    self:Tick(cooling)
end
-- Ten updates a second, only while a row is cooling down.
function I:Tick(on)
    if not self.ticker then
        self.ticker=CreateFrame("Frame"); self.ticker.wait=0
        self.ticker:SetScript("OnUpdate",function(tk,dt) tk.wait=tk.wait+dt; if tk.wait<.1 then return end; tk.wait=0; self:Paint() end)
    end
    self.ticker:SetShown(on and true or false)
end
function I:Changed() FT:Coalesce("interrupts",function() self:Paint() end,0) end
-- Place -------------------------------------------------------------------------
-- The bar keeps one corner in place: the top left (grows down) or the
-- bottom left (grows up). Switching Grow never moves the bar.
function I:Corner()
    return (self:Settings().grow=="up" and "BOTTOM" or "TOP").."LEFT"
end
function I:Place()
    local f=self.bar; if not f then return end
    local s=self:Settings(); local scale=s.size
    f:SetScale(scale); f:ClearAllPoints()
    local corner=self:Corner()
    if s.x and s.y then f:SetPoint(corner,UIParent,"BOTTOMLEFT",s.x/scale,s.y/scale)
    else
        local x=corner:find("RIGHT") and -170 or -360
        local y=corner:find("BOTTOM") and 40 or 140
        f:SetPoint(corner,UIParent,"CENTER",x/scale,y/scale)
    end
end
function I:SavePlace()
    local f=self.bar; if not f then return end
    local left,top,right,bottom=f:GetLeft(),f:GetTop(),f:GetRight(),f:GetBottom()
    if not (safe(left) and safe(top) and safe(right) and safe(bottom)) then return end
    local s=self:Settings(); local scale=f:GetScale() or 1
    local corner=self:Corner()
    s.x=(corner:find("RIGHT") and right or left)*scale
    s.y=(corner:find("BOTTOM") and bottom or top)*scale
    self:Place()
end
-- A new growth: the bar stays where it is on screen.
function I:SetGrow(grow)
    local s=self:Settings()
    if self.bar and self.bar:GetLeft() then self:SavePlace() end
    local left,top,right,bottom
    if self.bar then left,top,right,bottom=self.bar:GetLeft(),self.bar:GetTop(),self.bar:GetRight(),self.bar:GetBottom() end
    if grow then s.grow=grow end
    if left and top and safe(left) and safe(top) then
        local scale=self.bar:GetScale() or 1; local corner=self:Corner()
        s.x=(corner:find("RIGHT") and right or left)*scale; s.y=(corner:find("BOTTOM") and bottom or top)*scale
    end
    self:Place(); self:Paint(); self:Refresh()
end
function I:ResetPosition() local s=self:Settings(); s.x,s.y=nil,nil; self:Place() end
function I:SetMoving(on)
    self.moving=on and true or false
    self:Unlock(); self:Paint(); self:Refresh()
end
-- Moving or previewing: the bar can be dragged, with its outline shown.
function I:Unlock()
    local f=self:Bar(); local open=self.moving or self.preview or false
    FT:LockedMouse(f,not open,"Interrupts")
    for _,t in ipairs(f.fillTextures) do t:SetShown(open) end
    for _,t in ipairs(f.borderTextures) do t:SetShown(open) end
    f.name:SetShown(open); f.hint:SetShown(open)
    f:SetFrameStrata(open and "HIGH" or "MEDIUM")
end
-- On / off ----------------------------------------------------------------------
function I:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    self:SetEvents(s.enabled)
    if s.enabled then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and not self.prefixed then self.prefixed=true; pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
        self:Bar(); self:Own(); self:Announce()
    end
    if self.bar then self:Place(); self:Paint() end
    self:Refresh()
end
function I:SetEvents(on)
    if self.listening==on then return end
    self.listening=on
    local events={"UNIT_SPELLCAST_SUCCEEDED","CHAT_MSG_ADDON","GROUP_ROSTER_UPDATE","SPELLS_CHANGED","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}
    for _,event in ipairs(events) do
        if on then pcall(self.events.RegisterEvent,self.events,event) else pcall(self.events.UnregisterEvent,self.events,event) end
    end
end
-- Settings page (Combat > Interrupt bar) -------------------------------------------
function I:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Interrupt bar: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.when.label:SetText("Show: "..({group="In a group",combat="In fights",always="Always"})[s.when])
    self.grow.label:SetText("Grow: "..(s.grow=="up" and "Up" or "Down"))
    self.selfRow.label:SetText("Your own row: "..(s.self and "On" or "Off")); FT:SetSelected(self.selfRow,s.self)
    self.solo.label:SetText("Also when alone: "..(s.solo and "On" or "Off")); FT:SetSelected(self.solo,s.solo)
    self.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
    self.widthLabel:SetText(string.format("Width: %d",s.width))
    self.rowsLabel:SetText(string.format("Most rows: %d",s.rows))
    self.settingSlider=true; self.sizeSlider:SetValue(s.size); self.widthSlider:SetValue(s.width); self.rowsSlider:SetValue(s.rows); self.settingSlider=false
    self.previewButton.label:SetText("Preview: "..(self.preview and "On" or "Off")); FT:SetSelected(self.previewButton,self.preview)
    self.move.label:SetText(self.moving and "Lock position" or "Move bar"); FT:SetSelected(self.move,self.moving)
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
function I:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsInterruptPage","Interrupt bar",540,480); self.frame=frame
        FT:PageInfo(frame,"Interrupt bar","A bar for each interrupt in your group, showing when it is ready again.\n\nGroup members with ForeverTools share theirs exactly. Others show once the game lets us see their cast. Earth Shock counts any shock.")
        local hint=FT:Label(frame,"Who can interrupt, and when.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,"Ability_Kick"); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function()
            local s=self:Settings(); s.enabled=not s.enabled; self:Apply()
            -- Turned on: sample rows to drag into place.
            if s.enabled then self:SetMoving(true); FT:Toast("Drag the bar into place, then click Lock position.",4)
            elseif self.moving then self:SetMoving(false) end
        end)
        FT:Tooltip(self.toggle,"Interrupt bar","Show your group's interrupts and cooldowns.")
        self.when=FT:QuietButton(frame,"",240,32,"Ability_DualWield"); self.when:SetPoint("TOPLEFT",24,-136)
        FT:MakeChoice(self.when,{{"group","In a group","Whenever you are in a group."},{"combat","In fights","Only during a fight."},{"always","Always","All the time."}},function() return self:Settings().when end,function(v) self:Settings().when=v; self:Paint(); self:Refresh() end)
        FT:Tooltip(self.when,"When to show","When the bar shows.")
        self.selfRow=FT:QuietButton(frame,"",240,32,"Ability_Kick"); self.selfRow:SetPoint("TOPLEFT",24,-176)
        self.selfRow:SetScript("OnClick",function() local s=self:Settings(); s.self=not s.self; self:Paint(); self:Refresh() end)
        FT:Tooltip(self.selfRow,"Your own row","Also show your own interrupt in the bar.")
        self.grow=FT:QuietButton(frame,"",240,32,"Ability_Hunter_Pet_Bear"); self.grow:SetPoint("TOPLEFT",24,-216)
        FT:MakeChoice(self.grow,{{"down","Down","New rows are added below."},{"up","Up","New rows are added above."}},function() return self:Settings().grow end,function(v) self:SetGrow(v) end)
        FT:Tooltip(self.grow,"Grow","Which way new rows are added. The bar itself never moves.")
        self.font=FT:QuietButton(frame,"Interrupt bar font",240,32,"fonts"); self.font:SetPoint("TOPLEFT",276,-216)
        self.font:SetScript("OnClick",function() local fonts=FT.modules.FontManager; fonts.selected="interrupts"; FT:OpenModule("FontManager") end)
        FT:Tooltip(self.font,"Interrupt bar font","Font, size and outline of the bar (opens Fonts).")
        self.solo=FT:QuietButton(frame,"",240,32,"Spell_Holy_PrayerOfHealing"); self.solo:SetPoint("TOPLEFT",276,-136)
        self.solo:SetScript("OnClick",function() local s=self:Settings(); s.solo=not s.solo; self:Paint(); self:Refresh() end)
        FT:Tooltip(self.solo,"Also when alone","Show the bar when you are not in a group.")
        local function slider(y,lo,hi,step,label,tip,set)
            local text=FT:Label(frame,"",14); text:SetPoint("TOPLEFT",24,-y-2)
            local sl=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); sl:SetSize(320,18); sl:SetPoint("TOPLEFT",196,-y)
            sl:SetMinMaxValues(lo,hi); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
            sl:SetScript("OnValueChanged",function(_,v) if self.settingSlider then return end; set(v); FT:Coalesce("interruptSize",function() self:Place(); self:Paint(); self:Refresh() end,.05) end)
            FT:Tooltip(sl,label,tip)
            return text,sl
        end
        self.sizeLabel,self.sizeSlider=slider(266,.7,1.5,.05,"Size","Bar size (70% to 150%).",function(v) self:Settings().size=math.floor(v*20+.5)/20 end)
        self.widthLabel,self.widthSlider=slider(306,120,320,10,"Width","How wide the bars are.",function(v) self:Settings().width=math.floor(v/10+.5)*10 end)
        self.rowsLabel,self.rowsSlider=slider(346,1,20,1,"Most rows","The most rows shown, so a 40-player battleground never fills your screen. Ready soonest first.",function(v) self:Settings().rows=math.floor(v+.5); self.samples=nil end)
        self.previewButton=FT:QuietButton(frame,"",156,32,"Spell_Holy_MindVision"); self.previewButton:SetPoint("TOPLEFT",24,-386)
        self.previewButton:SetScript("OnClick",function() self:SetPreview(not self.preview) end)
        FT:Tooltip(self.previewButton,"Preview","Fill the bar with made-up players to set its size and place.")
        self.move=FT:QuietButton(frame,"",156,32,"move"); self.move:SetPoint("TOPLEFT",192,-386)
        self.move:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.move,"Move bar","Unlock, drag the bar, then click again to lock.")
        local reset=FT:QuietButton(frame,"Reset position",156,32,"reset"); reset:SetPoint("TOPLEFT",360,-386)
        reset:SetScript("OnClick",function() self:ResetPosition() end)
        FT:Tooltip(reset,"Reset position","Put the bar back in its starting place.")
        frame:HookScript("OnHide",function() if self.moving then self:SetMoving(false) end; if self.preview then self:SetPreview(false) end end)
        FT:Sections(frame,{{"When it shows",self.when},{"Look",self.grow},{"Place",self.previewButton}})
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Interrupts",I)
I.events=CreateFrame("Frame")
I.events:RegisterEvent("PLAYER_LOGIN")
I.events:SetScript("OnEvent",function(_,event,a,b,c,d)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then I:Apply(); return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if not safe(a) or type(a)~="string" then return end
        if a=="player" or a=="pet" or a:match("^party%d") or a:match("^raid%d") or a:match("^partypet%d") or a:match("^raidpet%d") then I:Cast(a,c) end
    elseif event=="CHAT_MSG_ADDON" then
        if safe(a) and a==PREFIX then I:Message(b,d) end
    elseif event=="GROUP_ROSTER_UPDATE" then
        -- Someone joined: tell them, once the group settles (a battleground
        -- fires this many times a second), and at most every few seconds.
        FT:Coalesce("interruptsRoster",function() if not I.announced or now()-I.announced>=5 then I.announced=nil; I:Announce() end end,2)
        I:Changed()
    elseif event=="SPELLS_CHANGED" then
        FT:Coalesce("interruptsOwn",function() I:Own(); I.announced=nil; I:Announce() end,1)
    elseif event=="PLAYER_REGEN_DISABLED" then
        I.fighting=true; I:Changed()
    elseif event=="PLAYER_REGEN_ENABLED" then
        I.fighting=false; I:Changed(); I:Announce()
    end
end)
