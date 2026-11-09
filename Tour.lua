local _,FT=...
-- First-time setup as a short guided tour.
--   Start: pick a look (shown live on your screen while you click) and a
--   Quick tour (the most useful features) or a Full tour (every feature).
--   One card per menu (Appearance, Combat, PvP...) lists its features as
--   switches: click one to turn it on and see it on your screen (it pulses);
--   click again to turn it off. Next goes to the next menu.
--   Pause any time (or close the card, or enter combat): the tour remembers
--   the menu. /ft setup continues it, and the next login asks once.
-- Nothing changes unless you switch it on; the result is saved to this
-- character's profile at the end.
local Tour={}
local function mod(name) return FT.modules[name] end
local function apply(name) local m=mod(name); if m and m.Apply then pcall(m.Apply,m) end end
local function playerClass() local _,class=UnitClass("player"); return class end
local function sys(key) return {get=function() return mod("System"):Settings()[key]==true end,
    set=function(on) mod("System"):Settings()[key]=on and true or false; apply("System") end} end
local function field(module,key,applyName)
    return {get=function() return mod(module):Settings()[key]==true end,
        set=function(on) mod(module):Settings()[key]=on and true or false; apply(applyName or module) end}
end
local function bags(key) return {get=function() return FT.Bags:Settings()[key]==true end,
    set=function(on) FT.Bags:Settings()[key]=on and true or false; FT.Bags:Apply() end} end
-- Every stop: chapter, settings page, title, one or two plain lines, how to
-- read and set it, the switch to point at (start of its label), what on the
-- screen it changes, an optional preview, and whether the Quick tour has it.
local function stops()
    local list={
        {key="unitColors",chapter="Appearance",page="UnitColors",title="Class-colored health bars",text="Your health bar takes your class color, and so do your target's and focus's.",
            find="Player class colors",target=function() return PlayerFrame end,quick=true,
            get=function() return mod("UnitColors"):Settings().player==true end,
            set=function(on) local s=mod("UnitColors"):Settings(); for _,u in ipairs({"player","target","focus"}) do s[u]=on and true or false end; apply("UnitColors") end},
        {key="dispelGlow",chapter="Appearance",page="DispelGlow",title="Dispel glow",text="A colored glow around a frame with a debuff you can remove.",
            find="Dispel glow",target=function() return PlayerFrame end,preview=function() local g=mod("DispelGlow"); if g and g.Preview then pcall(g.Preview,g,"Magic",4) end end,
            get=field("DispelGlow","enabled").get,set=field("DispelGlow","enabled").set},
        {key="druidMana",chapter="Appearance",page="DruidMana",title="Druid mana bar",text="Your mana as a third bar while in a form.",
            find="Mana bar while shapeshifted",target=function() return PlayerFrame end,when=function() return playerClass()=="DRUID" end,
            get=function() return mod("UnitColors"):Settings().druidMana==true end,
            set=function(on) mod("UnitColors"):Settings().druidMana=on and true or false; apply("UnitColors"); apply("DruidMana") end},
        {key="tooltipTarget",chapter="Appearance",page="Tooltip",title="Who a player is targeting",text="Player tooltips show who they target.",
            find="Target",quick=true,
            get=function() return mod("Tooltip"):Settings().target==true end,
            set=function(on) mod("Tooltip"):Settings().target=on and true or false end},
        {key="itemCounts",chapter="Appearance",page="ItemCounts",title="Item counts",text="Item tooltips show how many you have on every character.",
            find="Item counts",get=bags("counts").get,set=bags("counts").set},
        {key="chatHistory",chapter="Appearance",page="Chat",title="Keep chat after reload",text="Today's chat comes back after a /reload or logging in again.",
            find="Keep chat after reload",get=function() return type(FT.db.chat)=="table" and FT.db.chat.history==true end,
            set=function(on) if type(FT.db.chat)~="table" then FT.db.chat={} end; FT.db.chat.history=on and true or nil; local c=FT.modules.Chat; if c then if on then c.restored=true end; c:ApplyHistory() end end},
        {key="thanks",chapter="Appearance",page="Chat",title="Thank for buffs",text="A /thank to strangers who buff you.",
            find="Thank for buffs",get=function() return type(FT.db.thanks)=="table" and FT.db.thanks.enabled==true end,
            set=function(on) if type(FT.db.thanks)~="table" then FT.db.thanks={} end; FT.db.thanks.enabled=on and true or false end},
        {key="reminders",chapter="Buff reminders",page="BuffReminder",title="Buff reminders",text="A notice when one of your buffs is missing.",
            find="Self reminders",quick=true,get=field("BuffReminder","enabled").get,set=field("BuffReminder","enabled").set},
        {key="rankMarker",chapter="Buff reminders",page="BuffRanks",title="Low-rank marker",text="A corner on buttons below your best rank.",
            find="Marker on bars",get=field("BuffReminder","rankMarker").get,set=field("BuffReminder","rankMarker").set},
        {key="cooldowns",chapter="Buff reminders",page="CooldownReminder",title="Cooldown reminders",text="A nudge to use a big cooldown when it matters.",
            find="Cooldown reminders",get=field("CooldownReminder","enabled").get,set=field("CooldownReminder","enabled").set},
        {key="threat",chapter="Combat",page="Threat",title="Threat meter",text="Your threat on your target, next to the damage meter.",
            find="Threat meter",quick=true,target=function() local t=mod("Threat"); return t and t.meter end,get=field("Threat","enabled").get,set=field("Threat","enabled").set},
        {key="rare",chapter="Combat",page="RareAlert",title="Rare alerts",text="A notice when a rare is nearby.",
            find="Rare alerts",quick=true,target=function() local r=mod("RareAlert"); return r and r.notice end,
            preview=function() local r=mod("RareAlert"); if r and r.Show then pcall(r.Show,r,"Rare example",true) end end,
            get=field("RareAlert","enabled").get,set=field("RareAlert","enabled").set},
        {key="interrupts",chapter="Combat",page="Interrupts",title="Interrupt bar",text="Your group's interrupts and when each is ready.",
            find="Interrupt bar",target=function() local i=mod("Interrupts"); return i and i.bar end,
            preview=function() local i=mod("Interrupts"); if i and i.Peek then pcall(i.Peek,i) end end,
            get=field("Interrupts","enabled").get,set=field("Interrupts","enabled").set},
        {key="totems",chapter="Combat",page="Totems",title="Totem range",text="Your totems' reach on the minimap.",
            find="Totem range on minimap",target=function() return Minimap end,when=function() return playerClass()=="SHAMAN" end,
            get=field("Totems","range").get,set=field("Totems","range").set},
        {key="autoRole",chapter="Combat",page="SystemGameplay",title="Group role",text="Your role is set from your talents when you join a group.",
            find="Set role when joining",get=sys("autoRole").get,set=sys("autoRole").set},
        {key="stealth",chapter="PvP",page="EnemyAlerts",title="Stealth alerts",text="A warning when an enemy near you goes into stealth.",
            find="Stealth alerts",quick=true,target=function() return FT.Enemies and FT.Enemies.notice end,
            preview=function() if FT.Enemies then FT.Enemies:Preview("stealth") end end,
            get=field("Enemies","stealth").get,set=field("Enemies","stealth").set},
        {key="nearby",chapter="PvP",page="EnemyNearby",title="Nearby enemies",text="Enemy players you saw recently.",
            find="Nearby enemies",target=function() return FT.Enemies and FT.Enemies.strip end,
            preview=function() if FT.Enemies then FT.Enemies:PreviewStrip() end end,
            get=field("Enemies","nearby").get,set=field("Enemies","nearby").set},
        {key="trinkets",chapter="PvP",page="Trinkets",title="Trinket menu",text="Two trinket buttons with cooldowns. Point at one to swap.",
            find="Trinket menu",target=function() local t=mod("Trinkets"); return t and t.bar end,
            get=field("Trinkets","enabled").get,set=field("Trinkets","enabled").set},
        {key="enemyCooldowns",chapter="PvP",page="EnemyCooldowns",title="Enemy cooldowns",text="Big cooldowns enemy players used (trinket, Blind, Ice Block...), with the time left.",
            find="Enemy cooldowns",target=function() local c=mod("EnemyCooldowns"); return c and c.bar end,
            preview=function() local c=mod("EnemyCooldowns"); if c and c.Peek then c:Peek() end end,
            get=field("EnemyCooldowns","enabled").get,set=field("EnemyCooldowns","enabled").set},
        {key="diminish",chapter="PvP",page="Diminish",title="Diminishing returns",text="Icons by your target when crowd control will be shorter. Red: immune.",
            find="Diminishing returns",preview=function() local d=mod("Diminish"); if d and d.Peek then d:Peek() end end,
            get=field("Diminish","enabled").get,set=field("Diminish","enabled").set},
        {key="autoRelease",chapter="PvP",page="AutoRelease",title="Auto release",text="In battlegrounds your spirit is released by itself.",
            find="Auto release",get=field("AutoRelease","enabled").get,set=field("AutoRelease","enabled").set},
        {key="bgTimer",chapter="PvP",page="QueueTimer",title="Battleground timer",text="The time left to enter when a battleground queue pops.",
            find="Battleground timer",target=function() local t=mod("QueueTimer"); return t and t.bar end,
            preview=function() local t=mod("QueueTimer"); if t and t.Peek then t:Peek() end end,
            get=field("QueueTimer","enabled").get,set=field("QueueTimer","enabled").set},
        {key="fps",chapter="On-screen info",page="QualityOfLife",title="FPS counter",text="A small FPS counter. Drag it anywhere later.",
            find="FPS counter",quick=true,target=function() local q=mod("QualityOfLife"); return q and q.counter end,
            get=field("QualityOfLife","enabled").get,set=field("QualityOfLife","enabled").set},
        {key="leveling",chapter="On-screen info",page="Leveling",title="Leveling stats",text="XP per hour and time to level.",
            find="Leveling stats",quick=true,target=function() local l=mod("Leveling"); return l and l.line end,
            get=field("Leveling","enabled").get,set=field("Leveling","enabled").set},
        {key="errors",chapter="On-screen info",page="SystemErrors",title="Fewer error messages",text="The red error text (Out of range...) is hidden.",
            find="Hide error messages",get=sys("hideErrors").get,set=sys("hideErrors").set},
        {key="moveWindows",chapter="On-screen info",page="MoveWindows",title="Move game windows",text="Drag game windows by their title bar. Click Done at the top when finished.",
            find="Move game windows",get=field("MoveWindows","enabled").get,set=field("MoveWindows","enabled").set},
        {key="flight",chapter="On-screen info",page="FlightTimer",title="Flight timer",text="How long until you land.",
            find="Flight timer",get=field("FlightTimer","enabled").get,set=field("FlightTimer","enabled").set},
        {key="shortKeys",chapter="System",page="SystemKeybinds",title="Short key text",text="The keys on your action buttons, short: S1 for Shift-1, M5 for mouse button 5.",
            find="Short key text",get=sys("shortKeys").get,set=sys("shortKeys").set},
        {key="fastLoot",chapter="System",page="SystemMerchant",title="Faster looting",text="Everything is looted at once (with auto loot on).",
            find="Faster looting",quick=true,get=sys("fastLoot").get,set=sys("fastLoot").set},
        {key="softRes",chapter="System",page="SystemMerchant",title="Soft reserves",text="Paste your raid's soft reserves from the guild website (/ft sr): who reserved what shows on loot, in raid chat and on tooltips.",
            find="Soft reserves",get=sys("softRes").get,set=sys("softRes").set},
        {key="autoSell",chapter="System",page="SystemMerchant",title="Sell grey items",text="Grey items are sold at merchants.",
            find="Auto-sell grey items",quick=true,get=sys("autoSell").get,set=sys("autoSell").set},
        {key="autoRepair",chapter="System",page="SystemMerchant",title="Auto-repair",text="Your gear is repaired at merchants.",
            find="Auto-repair",quick=true,get=sys("autoRepair").get,set=sys("autoRepair").set},
        {key="versionCheck",chapter="System",page="SystemGeneral",title="New version notice",text="One chat line when someone in your guild or group has a newer ForeverTools.",
            find="New version notice",get=sys("versionCheck").get,set=sys("versionCheck").set},
        {key="hiddenUI",chapter="System",page="SystemGeneral",title="Key to show the interface",text="A line says which key brings the interface back.",
            find="Show key when interface is hidden",get=sys("hiddenUIHint").get,set=sys("hiddenUIHint").set},
        {key="gold",chapter="Bags",page="BagsGeneral",title="Gold of all your characters",text="Hover your bag's gold to see every character's gold.",
            find="Gold tooltip",quick=true,get=bags("gold").get,set=bags("gold").set},
        {key="bankView",chapter="Bags",page="BagsGeneral",title="Bank and other characters",text="Right-click your bag's portrait: your bank and your other characters' bags.",
            find="Bank and other characters",quick=true,get=bags("view").get,set=bags("view").set},
    }
    return list
end
Tour.Stops=stops
function Tour:State()
    if type(FT.db.tour)~="table" then FT.db.tour={} end
    local t=FT.db.tour
    if t.mode~="quick" and t.mode~="full" then t.mode="quick" end
    if type(t.kept)~="table" then t.kept={} end
    t.index=tonumber(t.index) or 1
    return t
end
-- The stops of the chosen tour that fit this character.
function Tour:List(mode)
    local out={}
    for _,stop in ipairs(stops()) do
        local fits=(mode=="full" or stop.quick) and (not stop.when or stop.when()) and FT.modules[stop.page]~=nil
        if fits then out[#out+1]=stop end
    end
    return out
end
-- Pulsing highlights ------------------------------------------------------------
local function glowFrame()
    local g=CreateFrame("Frame",nil,UIParent)
    g:SetFrameStrata("TOOLTIP"); g:EnableMouse(false)
    g.edges={}
    for i=1,4 do local t=g:CreateTexture(nil,"OVERLAY"); t:SetColorTexture(1,.82,0,1); g.edges[i]=t end
    g.edges[1]:SetPoint("TOPLEFT"); g.edges[1]:SetPoint("TOPRIGHT"); g.edges[1]:SetHeight(3)
    g.edges[2]:SetPoint("BOTTOMLEFT"); g.edges[2]:SetPoint("BOTTOMRIGHT"); g.edges[2]:SetHeight(3)
    g.edges[3]:SetPoint("TOPLEFT"); g.edges[3]:SetPoint("BOTTOMLEFT"); g.edges[3]:SetWidth(3)
    g.edges[4]:SetPoint("TOPRIGHT"); g.edges[4]:SetPoint("BOTTOMRIGHT"); g.edges[4]:SetWidth(3)
    g.fill=g:CreateTexture(nil,"BACKGROUND"); g.fill:SetAllPoints(); g.fill:SetColorTexture(1,.82,0,.10); g.fill:SetBlendMode("ADD")
    g:SetScript("OnUpdate",function(owner)
        local t=GetTime and GetTime() or 0
        owner:SetAlpha(.45+.55*math.abs(math.sin(t*2.6)))
        if owner.target and owner.target.IsVisible and not owner.target:IsVisible() then owner:Hide() end
    end)
    g:Hide()
    return g
end
function Tour:Pulse(index,target,pad)
    self.glows=self.glows or {}
    local g=self.glows[index] or glowFrame(); self.glows[index]=g
    if not target or not target.GetRect or not target:IsVisible() then g:Hide(); return end
    pad=pad or 5
    -- A switch on a page glows above the page; something on the screen glows
    -- at its own height, so a window in front of it still covers it.
    if index==1 then g:SetFrameStrata("TOOLTIP")
    else
        local strata=target.GetFrameStrata and target:GetFrameStrata() or "MEDIUM"
        g:SetFrameStrata(strata); g:SetFrameLevel(math.min(9000,(target:GetFrameLevel() or 1)+20))
    end
    g.target=target; g:ClearAllPoints()
    g:SetPoint("TOPLEFT",target,"TOPLEFT",-pad,pad); g:SetPoint("BOTTOMRIGHT",target,"BOTTOMRIGHT",pad,-pad)
    g:Show()
    return g
end
function Tour:ClearPulses() for _,g in pairs(self.glows or {}) do g.target=nil; g:Hide() end end
-- The switch on the page whose label starts with the stop's text.
function Tour:FindControl(frame,prefix,depth)
    if not frame or not prefix or (depth or 0)>6 then return end
    for _,child in ipairs({frame:GetChildren()}) do
        local label=rawget(child,"label")
        local text=label and label.GetText and label:GetText()
        if type(text)=="string" and text:sub(1,#prefix)==prefix and child:IsShown() then return child end
        local found=self:FindControl(child,prefix,(depth or 0)+1)
        if found then return found end
    end
end
-- The guide card --------------------------------------------------------------------
-- One card per menu: the menu's features as switches.
local CARD_W,ROWS=340,10
function Tour:Chapters(mode)
    local out,byName={},{}
    for _,stop in ipairs(self:List(mode)) do
        local c=byName[stop.chapter]
        if not c then c={name=stop.chapter,stops={}}; byName[stop.chapter]=c; out[#out+1]=c end
        c.stops[#c.stops+1]=stop
    end
    return out
end
function Tour:Card()
    if self.card then return self.card end
    local card=FT:Window("ForeverToolsTour","Tour",CARD_W,330); self.card=card
    card.noSavePrompt=true; card.ignorePlacement=true; card:SetFrameStrata("FULLSCREEN_DIALOG")
    if card.homeButton then card.homeButton:Hide() end
    card.titleText:SetText("")
    card.overall=FT:Label(card,"",11); card.overall:SetPoint("TOPLEFT",20,-18); card.overall:SetTextColor(.66,.59,.48)
    card.bar=card:CreateTexture(nil,"ARTWORK"); card.bar:SetColorTexture(.79,.63,.29,1); card.bar:SetHeight(4); card.bar:SetPoint("TOPLEFT",20,-40)
    card.barBack=card:CreateTexture(nil,"BORDER"); card.barBack:SetColorTexture(.16,.13,.08,1); card.barBack:SetHeight(4)
    card.barBack:SetPoint("TOPLEFT",20,-40); card.barBack:SetPoint("TOPRIGHT",-20,-40)
    card.title=FT:Label(card,"",17,true); card.title:SetPoint("TOPLEFT",20,-56); card.title:SetWidth(CARD_W-40); card.title:SetTextColor(1,.91,.66)
    card.text=FT:Label(card,"Click to turn on: it shows on your screen. Point at one to see what it does.",12); card.text:SetPoint("TOPLEFT",20,-80); card.text:SetWidth(CARD_W-40)
    if card.text.SetWordWrap then card.text:SetWordWrap(true) end
    card.text:SetTextColor(.85,.80,.70)
    card.rows={}
    for i=1,ROWS do
        local b=FT:QuietButton(card,"",CARD_W-40,30)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(owner,button)
            if not owner.stop then return end
            if button=="RightButton" then self:OpenPage(owner.stop) else self:Toggle(owner.stop) end
        end)
        FT:Tooltip(b,function() return b.stop and b.stop.title or "" end,function()
            local st=b.stop; if not st then return "" end
            return st.text.."\n\nRight-click: open its settings ("..st.chapter..")."
        end)
        card.rows[i]=b
    end
    card.next=FT:AccentButton(card,"Next",CARD_W-40,32,"confirm")
    card.next.action=true; card.next.primary=true
    card.next:SetScript("OnClick",function() self:Next(1) end)
    FT:Tooltip(card.next,"Next","Go to the next menu. What you switched on stays on.")
    card.back=FT:QuietButton(card,"Back",(CARD_W-48)/2,26); card.back.action=true
    card.back:SetScript("OnClick",function() self:Next(-1) end)
    FT:Tooltip(card.back,"Back","The menu before.")
    card.pause=FT:QuietButton(card,"Pause",(CARD_W-48)/2,26); card.pause.action=true
    card.pause:SetScript("OnClick",function() self:Pause() end)
    FT:Tooltip(card.pause,"Pause","Continue later with /ft setup. What you switched on stays on.")
    -- Closing the card is the same as Pause.
    card:HookScript("OnHide",function()
        if not self.running then return end
        -- Hidden because a fight started: pause quietly and come back after it.
        if FT.hidingForCombat or InCombatLockdown() then self:Pause(true,true); self.afterCombat=true; return end
        self:Pause(true)
    end)
    card:Hide()
    return card
end
local function isOn(stop) local ok,on=pcall(stop.get); return ok and on==true end
function Tour:Layout(chapter,index,count)
    local card=self:Card()
    card.overall:SetText("Menu "..index.." of "..count)
    card.bar:SetWidth(math.max(2,(CARD_W-40)*index/math.max(1,count)))
    card.title:SetText(chapter.name)
    local y=80+(card.text:GetStringHeight() or 28)+10
    for i,row in ipairs(card.rows) do
        local stop=chapter.stops[i]
        row.stop=stop; row:SetShown(stop~=nil)
        if stop then
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",20,-y); y=y+34
            row.label:SetText(stop.title..": "..(isOn(stop) and "On" or "Off"))
            FT:SetSelected(row,isOn(stop))
        end
    end
    y=y+8
    card.next.label:SetText(index<count and ("Next: "..(self.chapters[index+1].name)) or "Finish")
    card.next:ClearAllPoints(); card.next:SetPoint("TOPLEFT",20,-y)
    card.back:ClearAllPoints(); card.back:SetPoint("TOPLEFT",card.next,"BOTTOMLEFT",0,-10)
    card.pause:ClearAllPoints(); card.pause:SetPoint("TOPRIGHT",card.next,"BOTTOMRIGHT",0,-10)
    card.back:SetEnabled(index>1); card.back:SetAlpha(index>1 and 1 or .45)
    card:SetHeight(y+32+10+26+22)
end
function Tour:RefreshRows()
    local card=self.card; if not card then return end
    for _,row in ipairs(card.rows) do
        if row.stop and row:IsShown() then
            local on=isOn(row.stop)
            row.label:SetText(row.stop.title..": "..(on and "On" or "Off")); FT:SetSelected(row,on)
        end
    end
end
-- Running the tour ----------------------------------------------------------------------
function Tour:Begin(mode)
    local t=self:State()
    t.mode=mode or t.mode; t.index=1; t.kept={}; t.done=nil; t.paused=nil; t.reminded=nil; t.cards=true
    FT.db.setupDone=true
    self:Show()
end
function Tour:Resume()
    local t=self:State()
    if t.done then return false end
    -- A tour paused before 1.3.0 counted single features: start at the
    -- first menu of the new, shorter tour.
    if not t.cards then t.cards=true; t.index=1 end
    t.paused=nil
    self:Show()
    return true
end
-- A ForeverTools element shown on the tour (rare alert, stealth alert,
-- nearby enemies, …) is moved next to the tour card while it shows, so the
-- card never hides it; it goes back to its own place afterwards.
-- The game's own frames (player frame, minimap) stay where they are.
local function own(target)
    local name=target and target.GetName and target:GetName()
    return name==nil or (type(name)=="string" and name:find("^ForeverTools")~=nil)
end
function Tour:Bring(target)
    if not (target and own(target) and target.GetNumPoints and self.card and self.card:IsShown()) then return end
    if self.moved and self.moved.frame==target then return end
    self:PutBack()
    local points={}
    for i=1,(target:GetNumPoints() or 0) do points[i]={target:GetPoint(i)} end
    self.moved={frame=target,points=points}
    target:ClearAllPoints()
    local bottom=self.card:GetBottom() or 0
    local height=target:GetHeight() or 0
    if bottom-height-30>20 then target:SetPoint("TOP",self.card,"BOTTOM",0,-30)
    else target:SetPoint("TOPRIGHT",self.card,"TOPLEFT",-24,-40) end
end
function Tour:PutBack()
    local moved=self.moved; self.moved=nil
    if not moved then return end
    local f=moved.frame
    f:ClearAllPoints()
    for _,point in ipairs(moved.points) do pcall(f.SetPoint,f,unpack(point)) end
end
function Tour:Show()
    if InCombatLockdown() then self.afterCombat=true; return end
    self:PutBack(); self:ClearPulses()
    local t=self:State()
    self.chapters=self:Chapters(t.mode)
    if t.index<1 then t.index=1 end
    if t.index>#self.chapters then self:Finish(); return end
    self.running=true
    self:Layout(self.chapters[t.index],t.index,#self.chapters)
    local card=self:Card()
    if not card:IsShown() then card:ClearAllPoints(); card:SetPoint("RIGHT",UIParent,"RIGHT",-60,40) end
    card:Show()
end
-- Click a feature: on (and shown on screen, pulsing) or off again.
function Tour:Toggle(stop)
    if InCombatLockdown() then return end
    local t=self:State()
    local on=not isOn(stop)
    pcall(stop.set,on)
    t.kept[stop.key]=on or nil
    self:ClearPulses(); self:PutBack()
    if on then
        if stop.preview then pcall(stop.preview) end
        C_Timer.After(.2,function()
            if not self.running then return end
            local ok,target=pcall(stop.target or function() end)
            if ok and target then
                if target.IsVisible and target:IsVisible() then self:Bring(target) end
                self:Pulse(2,target,6)
            end
        end)
    end
    local page=mod(stop.page); if page and page.frame and page.frame:IsShown() and page.Refresh then pcall(page.Refresh,page) end
    self:RefreshRows()
end
-- Right-click: the feature's own settings page, its switch pulsing.
function Tour:OpenPage(stop)
    FT:OpenModule(stop.page)
    local page=mod(stop.page); local frame=page and page.frame
    if frame and frame:IsShown() and self.card then
        self.card:ClearAllPoints(); self.card:SetPoint("TOPLEFT",frame,"TOPRIGHT",12,0)
        self:Pulse(1,self:FindControl(frame,stop.find),4)
    end
end
function Tour:Next(step)
    local t=self:State()
    t.index=math.max(1,t.index+(step or 1))
    self:Show()
end
-- Kept for older callers: nothing is ever on without a click now.
function Tour:Undo() end
function Tour:Answer(keep) self:Next(1) end
function Tour:SkipChapter() self:Next(1) end
function Tour:Pause(fromClose,quiet)
    if not self.running then return end
    local t=self:State()
    self:PutBack()
    self.running=false; t.paused=true
    self:ClearPulses()
    if not fromClose and self.card then self.card:Hide() end
    if self:InTrial() and not quiet then self:EndTrial(); return end
    local chapter=self.chapters and self.chapters[t.index]
    if not quiet then FT:Toast("Tour paused at "..(chapter and chapter.name or "?").." (menu "..t.index.." of "..#(self.chapters or {})..").\nWhat you switched on stays on. Continue with /ft setup.",6) end
end
function Tour:Finish()
    local t=self:State()
    self:PutBack()
    self.running=false; t.done=true; t.paused=nil
    self:ClearPulses()
    if self.card then self.card:Hide() end
    local trial=self:InTrial()
    if not trial then local onboarding=mod("Onboarding"); if onboarding then onboarding:Finish() end end
    self:Summary(trial)
    if trial then self:EndTrial(true) end
end
function Tour:Summary(trial)
    if not self.summary then
        local frame=FT:Window("ForeverToolsTourDone","You're set up",440,330); self.summary=frame
        frame.noSavePrompt=true; if frame.homeButton then frame.homeButton:Hide() end
        frame.lines=FT:Label(frame,"",13); frame.lines:SetPoint("TOPLEFT",24,-66); frame.lines:SetWidth(392)
        if frame.lines.SetWordWrap then frame.lines:SetWordWrap(true) end
        frame.note=FT:Label(frame,"",12); frame.note:SetTextColor(.66,.59,.48); frame.note:SetWidth(392)
        local export=FT:QuietButton(frame,"Export my setup",190,32,"INV_Misc_Note_03"); export:SetPoint("BOTTOMLEFT",24,20)
        export:SetScript("OnClick",function() frame:Hide(); mod("Profiles"):Transfer(false) end)
        FT:Tooltip(export,"Export my setup","Copy your setup as a string.")
        local done=FT:AccentButton(frame,"Done",190,32,"confirm"); done:SetPoint("BOTTOMRIGHT",-24,20)
        done:SetScript("OnClick",function() frame:Hide() end)
        FT:Tooltip(done,"Done","Close. Open /ft any time to change things.")
    end
    local frame=self.summary; local t=self:State()
    local names={}
    for _,stop in ipairs(stops()) do if t.kept[stop.key] then names[#names+1]=stop.title end end
    local shown={}
    for i=1,math.min(8,#names) do shown[i]="· "..names[i] end
    if #names>8 then shown[#shown+1]="· …and "..(#names-8).." more" end
    local kept=trial and "You would have switched on " or "You switched on "
    frame.lines:SetText(#names==0 and (trial and "You switched nothing on." or "You kept everything as it was.") or (kept..#names.." feature"..(#names==1 and "" or "s")..":\n"..table.concat(shown,"\n")))
    if frame.titleText then frame.titleText:SetText(trial and "Practice run done" or "You're set up") end
    local profiles=mod("Profiles")
    local profile=profiles and profiles.active
    frame.note:ClearAllPoints(); frame.note:SetPoint("TOPLEFT",frame.lines,"BOTTOMLEFT",0,-12)
    frame.note:SetText(trial and "Practice run: every setting is now back the way it was." or "Change anything later in /ft."..(profile and (' Saved in profile "'..profile..'".') or ""))
    frame:SetHeight(66+(frame.lines:GetStringHeight() or 40)+12+30+80)
    FT:PlaceBeside(frame); frame:Show()
end
-- Start screen: a look and the length of the tour ------------------------------------
local looks={
    {key="dark",label="Darkmode",swatch={.08,.08,.08},border={0,0,0}},
    {key="class",label="Class Colors",swatch={.12,.12,.16},border="class"},
    {key="soft",label="Soft Shadow",swatch={.2,.2,.2},border={.33,.33,.33}},
    {key="none",label="Default look",swatch={.33,.27,.27},border={.72,.59,.24}},
}
local function deepCopy(v) if type(v)~="table" then return v end local o={}; for k,x in pairs(v) do o[k]=deepCopy(x) end; return o end
function Tour:PreviewLook(key)
    -- Remember the look from before the first click, to put it back on cancel.
    if not self.savedLook then self.savedLook={iconStyles=deepCopy(FT.db.iconStyles),unitColors=deepCopy(FT.db.unitColors)} end
    self.look=key
    FT.db.iconStyles=deepCopy(self.savedLook.iconStyles); FT.db.unitColors=deepCopy(self.savedLook.unitColors)
    local skins=mod("IconStyles")
    if key=="none" then
        local s=skins:Settings(); for k,v in pairs(s) do if type(v)=="boolean" then s[k]=false end end
        skins:Apply()
    else
        local template
        for _,t in ipairs(mod("Profiles").templates or {}) do if t.key==key then template=t end end
        skins:ApplyPresetToAll(template and template.preset or key)
        if template and template.colors then local c=mod("UnitColors"):Settings(); for _,u in ipairs({"player","target","focus"}) do c[u]=true end end
    end
    apply("UnitColors")
    self:RefreshStart()
end
function Tour:RestoreLook()
    if not self.savedLook then return end
    FT.db.iconStyles=self.savedLook.iconStyles; FT.db.unitColors=self.savedLook.unitColors
    self.savedLook=nil; self.look=nil
    apply("IconStyles"); apply("UnitColors")
end
function Tour:RefreshStart()
    local f=self.start; if not f then return end
    for key,b in pairs(f.looks) do FT:SetSelected(b,self.look==key) end
    for key,b in pairs(f.modes) do FT:SetSelected(b,self.mode==key) end
    local t=FT.db.tour
    local paused=type(t)=="table" and t.paused and not t.done
    f.resume:SetShown(paused and not self.demo)
    -- Set up before (the beta, another computer)? One line points to Import.
    f.importHint:SetShown(not (paused and not self.demo))
end
function Tour:ShowStart(again,demo)
    if InCombatLockdown() then FT:CombatOpenRequest(); return end
    self.demo=demo and true or nil
    if not self.start then
        local f=FT:Window("ForeverToolsSetup","Welcome to ForeverTools",600,450); self.start=f
        f.noSavePrompt=true; f:SetFrameStrata("FULLSCREEN_DIALOG"); if f.homeButton then f.homeButton:Hide() end
        f.intro=FT:Label(f,"",13); f.intro:SetPoint("TOPLEFT",24,-62); f.intro:SetWidth(552); f.intro:SetTextColor(.85,.80,.70)
        if f.intro.SetWordWrap then f.intro:SetWordWrap(true) end
        local h1=FT:Label(f,"Pick a look",15,true); h1:SetPoint("TOPLEFT",24,-108); FT:SectionHeading(h1,"skins",420)
        f.looks={}
        for i,look in ipairs(looks) do
            local b=FT:QuietButton(f,"",129,74); b:SetPoint("TOPLEFT",24+(i-1)*138,-134)
            b.label:ClearAllPoints(); b.label:SetPoint("BOTTOM",0,8); b.label:SetText(look.label)
            for n=1,3 do
                local sq=b:CreateTexture(nil,"ARTWORK"); sq:SetSize(22,22); sq:SetPoint("TOP",(n-2)*28,-10)
                sq:SetColorTexture(look.swatch[1],look.swatch[2],look.swatch[3],1)
                local edge=b:CreateTexture(nil,"BORDER"); edge:SetPoint("TOPLEFT",sq,"TOPLEFT",-2,2); edge:SetPoint("BOTTOMRIGHT",sq,"BOTTOMRIGHT",2,-2)
                local c=look.border
                if c=="class" then local _,class=UnitClass("player"); local cc=(RAID_CLASS_COLORS or {})[class or ""]; c=cc and {cc.r,cc.g,cc.b} or {0,.44,.87} end
                edge:SetColorTexture(c[1],c[2],c[3],1)
            end
            b:SetScript("OnClick",function() self:PreviewLook(look.key) end)
            FT:Tooltip(b,look.label,look.key=="none" and "The default look: no skins or colors." or "Shown as you click. Kept when you start.")
            f.looks[look.key]=b
        end
        f.lookNote=FT:Label(f,"Your screen changes as you click a look.",12)
        f.lookNote:SetPoint("TOPLEFT",24,-214); f.lookNote:SetTextColor(.66,.59,.48)
        local h2=FT:Label(f,"How long?",15,true); h2:SetPoint("TOPLEFT",24,-244); FT:SectionHeading(h2,"INV_Misc_PocketWatch_01",420)
        f.modes={}
        for i,m in ipairs({{"quick","Quick tour","The most useful features · about 1 min"},{"full","Full tour","Every feature, menu by menu · about 3 min"}}) do
            local b=FT:QuietButton(f,"",270,52); b:SetPoint("TOPLEFT",24+(i-1)*282,-270)
            b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT",14,-9); b.label:SetText(m[2])
            b.sub=FT:Label(b,m[3],11); b.sub:SetPoint("TOPLEFT",14,-29); b.sub:SetWidth(246); b.sub:SetTextColor(.66,.59,.48)
            b:SetScript("OnClick",function() self.mode=m[1]; self:RefreshStart() end)
            FT:Tooltip(b,m[2],m[3]..". You can pause any time and continue later.")
            f.modes[m[1]]=b
        end
        f.resume=FT:QuietButton(f,"Continue where you left off",552,30,"INV_Misc_Book_09"); f.resume:SetPoint("TOPLEFT",24,-334)
        f.resume:SetScript("OnClick",function() self.leaving=true; f:Hide(); self.leaving=nil; self:Resume() end)
        FT:Tooltip(f.resume,"Continue","Go back to where you paused.")
        f.importHint=FT:Label(f,"Set up before (the beta, another computer)? Import profile brings it all back.",12)
        f.importHint:SetPoint("TOPLEFT",24,-338); f.importHint:SetWidth(552); f.importHint:SetTextColor(.66,.59,.48)
        local import=FT:QuietButton(f,"Import profile",176,34,"INV_Misc_Note_03"); import:SetPoint("BOTTOMLEFT",24,22)
        import:SetScript("OnClick",function()
            if self.demo then FT:Toast("Not in the practice run.",2); return end
            self:RestoreLook(); self.leaving=true; f:Hide(); self.leaving=nil
            mod("Profiles"):Transfer(true,function(name)
                mod("Profiles"):Load(name,false,true)
                local onboarding=mod("Onboarding"); if onboarding then onboarding:Finish(true) end
                FT:Toast('Profile "'..name..'" imported and loaded.',4)
            end)
        end)
        FT:Tooltip(import,"Import profile","Paste a ForeverTools export string. Loaded right away.")
        local later=FT:QuietButton(f,"Not now",176,34); later:SetPoint("BOTTOM",0,22)
        later:SetScript("OnClick",function() f:Hide() end)
        FT:Tooltip(later,"Not now","Keep everything as it is. /ft setup starts the tour later.")
        local start=FT:AccentButton(f,"Start tour",176,34,"confirm"); start:SetPoint("BOTTOMRIGHT",-24,22)
        -- The one to click: filled gold.
        start.primary=true; FT:UpdateButton(start)
        start:SetScript("OnClick",function()
            if InCombatLockdown() then return end
            if self.demo then
                -- Practice run: everything is put back when it ends.
                FT.db.tourTrial=self.trialSnap; self.trialSnap=nil; self.demo=nil
            end
            self.savedLook=nil -- the look is kept
            self.leaving=true; f:Hide(); self.leaving=nil
            self:Begin(self.mode)
        end)
        FT:Tooltip(start,"Start tour","Keep the look and start the tour.")
        -- Closing without starting: the look goes back, and you are asked once more next time.
        f:HookScript("OnHide",function()
            if self.leaving then return end
            self:RestoreLook()
            if self.demo then self.demo=nil; self.trialSnap=nil; FT:Toast("Practice run: nothing was changed.",3); return end
            if FT.db.setupDone~=true then
                -- Asked once more at the next login, then never again.
                if FT.db.setupAsked then FT.db.setupDone=true else FT.db.setupAsked=true; FT.db.setupDone=false end
            end
        end)
    end
    local f=self.start
    f.titleText:SetText(self.demo and "Welcome to ForeverTools (practice run)" or "Welcome to ForeverTools")
    if self.demo then
        -- What everything is now, to put back when the practice run ends.
        local profiles=mod("Profiles")
        self.trialSnap={settings=profiles and profiles:Snapshot() or {},tour=deepCopy(FT.db.tour),setupDone=FT.db.setupDone,setupAsked=FT.db.setupAsked}
    end
    f.intro:SetText(self.demo and "Practice run: when it ends, every setting goes back to how it is now."
        or again and "Pick a new look if you like, then take the tour again."
        or "Everything starts off. The tour lists the features menu by menu: click one to turn it on and see it.")
    self.look=nil; self.mode=self.mode or "quick"; self.savedLook=nil
    self:RefreshStart()
    f.keepAfterCombat=not again
    FT:PlaceBeside(f); f:Show()
end
-- The practice run (/ft start) ends: every setting goes back to how it was.
function Tour:InTrial() return type(FT.db.tourTrial)=="table" end
function Tour:EndTrial(quiet)
    local trial=FT.db.tourTrial
    if type(trial)~="table" then return false end
    FT.db.tourTrial=nil
    local profiles=mod("Profiles"); if profiles then profiles:RestoreSnapshot(trial.settings) end
    FT.db.tour=trial.tour; FT.db.setupDone=trial.setupDone; FT.db.setupAsked=trial.setupAsked
    if not quiet then FT:Toast("Practice run over: every setting is back the way it was.",4) end
    return true
end
-- Combat pauses the tour; it comes back after the fight.
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then
        if Tour.running then Tour:Pause(false,true); Tour.afterCombat=true end
    elseif Tour.afterCombat then
        Tour.afterCombat=nil
        C_Timer.After(1,function() if not InCombatLockdown() then Tour:Resume() end end)
    end
end)
FT:RegisterModule("Tour",Tour)
