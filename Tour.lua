local _,FT=...
-- First-time setup as a guided tour.
--   Start: pick a look (shown live on your screen while you click) and a
--   Quick tour (the most useful features) or a Full tour (every menu).
--   Each stop opens the real settings page, turns the feature on so you see
--   it, and makes both the switch and the thing it changes pulse. Keep it, or
--   No thanks (it goes back to how it was).
--   Pause any time (or close the card, or enter combat): the tour remembers
--   the stop. /ft setup continues it, and the next login asks once.
-- Nothing changes unless you keep it; the result is saved to this
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
        {key="fastLoot",chapter="System",page="SystemMerchant",title="Faster looting",text="Everything is looted at once (with auto loot on).",
            find="Faster looting",quick=true,get=sys("fastLoot").get,set=sys("fastLoot").set},
        {key="autoSell",chapter="System",page="SystemMerchant",title="Sell grey items",text="Grey items are sold at merchants.",
            find="Auto-sell grey items",quick=true,get=sys("autoSell").get,set=sys("autoSell").set},
        {key="autoRepair",chapter="System",page="SystemMerchant",title="Auto-repair",text="Your gear is repaired at merchants.",
            find="Auto-repair",quick=true,get=sys("autoRepair").get,set=sys("autoRepair").set},
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
local CARD_W=300
function Tour:Card()
    if self.card then return self.card end
    local card=FT:Window("ForeverToolsTour","Tour",CARD_W,330); self.card=card
    card.noSavePrompt=true; card.ignorePlacement=true; card:SetFrameStrata("FULLSCREEN_DIALOG")
    if card.homeButton then card.homeButton:Hide() end
    card.titleText:SetText("")
    card.chapter=FT:Label(card,"",13,true); card.chapter:SetPoint("TOPLEFT",20,-16); card.chapter:SetTextColor(1,.82,0)
    card.overall=FT:Label(card,"",11); card.overall:SetPoint("TOPRIGHT",-52,-18); card.overall:SetTextColor(.66,.59,.48)
    card.dots={}
    card.bar=card:CreateTexture(nil,"ARTWORK"); card.bar:SetColorTexture(.79,.63,.29,1); card.bar:SetHeight(4); card.bar:SetPoint("TOPLEFT",20,-52)
    card.barBack=card:CreateTexture(nil,"BORDER"); card.barBack:SetColorTexture(.16,.13,.08,1); card.barBack:SetHeight(4)
    card.barBack:SetPoint("TOPLEFT",20,-52); card.barBack:SetPoint("TOPRIGHT",-20,-52)
    card.title=FT:Label(card,"",17,true); card.title:SetPoint("TOPLEFT",20,-70); card.title:SetWidth(CARD_W-40); card.title:SetTextColor(1,.91,.66)
    card.text=FT:Label(card,"",13); card.text:SetPoint("TOPLEFT",card.title,"BOTTOMLEFT",0,-8); card.text:SetWidth(CARD_W-40)
    if card.text.SetWordWrap then card.text:SetWordWrap(true) end
    card.text:SetTextColor(.85,.80,.70)
    card.keep=FT:AccentButton(card,"Keep it",CARD_W-40,32,"confirm")
    card.keep.action=true; card.keep.primary=true; card.keep.label:SetText("Keep it")
    card.keep:SetScript("OnClick",function() self:Answer(true) end)
    FT:Tooltip(card.keep,"Keep it","Keep it on, next stop.")
    card.no=FT:QuietButton(card,"No thanks",CARD_W-40,32)
    card.no:SetScript("OnClick",function() self:Answer(false) end)
    FT:Tooltip(card.no,"No thanks","Put it back, next stop.")
    card.no.action=true; card.no.label:SetText("No thanks")
    card.pause=FT:QuietButton(card,"Pause",126,26)
    card.pause:SetScript("OnClick",function() self:Pause() end)
    FT:Tooltip(card.pause,"Pause","Continue later with /ft setup. What you kept stays on.")
    card.skip=FT:QuietButton(card,"Skip chapter",126,26)
    card.skip:SetScript("OnClick",function() self:SkipChapter() end)
    FT:Tooltip(card.skip,"Skip chapter","Next menu, nothing changed here.")
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
function Tour:Chapter(list,index)
    local name=list[index] and list[index].chapter
    local first,last
    for i,stop in ipairs(list) do if stop.chapter==name then first=first or i; last=i end end
    return name,first,last
end
function Tour:Layout(stop,list,index)
    local card=self:Card()
    local name,first,last=self:Chapter(list,index)
    -- One counter: where you are in the whole tour. The dots show this chapter.
    card.chapter:SetText(name)
    card.overall:SetText(index.." of "..#list)
    for _,dot in ipairs(card.dots) do dot:Hide() end
    for i=first,last do
        local d=card.dots[i-first+1]
        if not d then d=card:CreateTexture(nil,"ARTWORK"); d:SetSize(8,8); d:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga"); card.dots[i-first+1]=d end
        d:ClearAllPoints(); d:SetPoint("TOPLEFT",20+(i-first)*13,-36)
        if i<index then d:SetVertexColor(.79,.63,.29) elseif i==index then d:SetVertexColor(1,.82,0) else d:SetVertexColor(.29,.24,.15) end
        d:Show()
    end
    card.bar:SetWidth(math.max(2,(CARD_W-40)*(index-1)/math.max(1,#list)))
    card.title:SetText(stop.title)
    card.text:SetText(stop.text..(self.wasOn and "\n\nYou already have this on." or ""))
    local textBottom=70+22+8+(card.text:GetStringHeight() or 40)
    card.keep:ClearAllPoints(); card.keep:SetPoint("TOPLEFT",20,-(textBottom+16))
    card.no:ClearAllPoints(); card.no:SetPoint("TOPLEFT",card.keep,"BOTTOMLEFT",0,-8)
    card.no.label:SetText(self.wasOn and "Turn it off" or "No thanks")
    card.pause:ClearAllPoints(); card.pause:SetPoint("TOPLEFT",card.no,"BOTTOMLEFT",0,-14)
    card.skip:ClearAllPoints(); card.skip:SetPoint("TOPRIGHT",card.no,"BOTTOMRIGHT",0,-14)
    card:SetHeight(textBottom+16+32+8+32+14+26+20)
end
-- Running the tour ----------------------------------------------------------------------
function Tour:Begin(mode)
    local t=self:State()
    t.mode=mode or t.mode; t.index=1; t.kept={}; t.done=nil; t.paused=nil; t.reminded=nil
    FT.db.setupDone=true
    self:Show()
end
function Tour:Resume()
    local t=self:State()
    if t.done then return false end
    t.paused=nil
    self:Show()
    return true
end
-- A ForeverTools element shown at a stop (rare alert, stealth alert, nearby
-- enemies, …) is moved next to the tour card for that stop, so the menu
-- never hides it; it goes back to its own place when the stop ends.
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
    local page=self.stop and mod(self.stop.page); local frame=page and page.frame
    if bottom-height-30>20 or not (frame and frame:IsShown()) then
        target:SetPoint("TOP",self.card,"BOTTOM",0,-30)
    else
        target:SetPoint("TOPRIGHT",frame,"TOPLEFT",-24,-40)
    end
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
    self:PutBack()
    local t=self:State()
    self.list=self:List(t.mode)
    if t.index>#self.list then self:Finish(); return end
    local stop=self.list[t.index]
    self.running=true; self.stop=stop
    -- Open the real page, and turn the feature on so it can be seen.
    FT:OpenModule(stop.page)
    if stop.prepare then pcall(stop.prepare) end
    local page=mod(stop.page); local frame=page and page.frame
    local okGet,on=pcall(stop.get)
    self.wasOn=okGet and on==true
    if not self.wasOn then pcall(stop.set,true) end
    if stop.preview then pcall(stop.preview) end
    if page and page.Refresh then pcall(page.Refresh,page) end
    self:Layout(stop,self.list,t.index)
    local card=self:Card()
    card:ClearAllPoints()
    if frame and frame:IsShown() then card:SetPoint("TOPLEFT",frame,"TOPRIGHT",12,0) else card:SetPoint("CENTER") end
    card:Show()
    -- Pulse the switch on the page and the thing it changes on screen.
    self:ClearPulses()
    self:Pulse(1,self:FindControl(frame,stop.find),4)
    C_Timer.After(.2,function()
        if self.stop~=stop then return end
        local ok,target=pcall(stop.target or function() end)
        if ok and target then
            if target.IsVisible and target:IsVisible() then self:Bring(target) end
            self:Pulse(2,target,6)
        end
    end)
end
function Tour:Answer(keep)
    local t=self:State(); local stop=self.stop
    if not stop then return end
    if keep then t.kept[stop.key]=true else t.kept[stop.key]=nil; pcall(stop.set,false) end
    t.index=t.index+1
    self:Show()
end
-- Leaving a stop without an answer puts it back the way it was.
function Tour:Undo()
    local stop=self.stop
    if stop and not self.wasOn then pcall(stop.set,false) end
end
function Tour:SkipChapter()
    local t=self:State()
    self:Undo()
    local _,_,last=self:Chapter(self.list,t.index)
    t.index=(last or t.index)+1
    self:Show()
end
function Tour:Pause(fromClose,quiet)
    if not self.running then return end
    local t=self:State()
    self:Undo(); self:PutBack()
    self.running=false; t.paused=true
    self:ClearPulses()
    local stop=self.stop; self.stop=nil
    local page=stop and mod(stop.page)
    if page and page.frame then page.frame:Hide() end
    if not fromClose and self.card then self.card:Hide() end
    if self:InTrial() and not quiet then self:EndTrial(); return end
    if not quiet then FT:Toast("Tour paused at "..(stop and stop.chapter or "?").." (stop "..t.index.." of "..#(self.list or {})..").\nWhat you kept stays on. Continue with /ft setup.",6) end
end
function Tour:Finish()
    local t=self:State()
    self:PutBack()
    self.running=false; self.stop=nil; t.done=true; t.paused=nil
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
    local kept=trial and "You would have kept " or "You kept "
    frame.lines:SetText(#names==0 and (trial and "You kept nothing." or "You kept everything as it was.") or (kept..#names.." feature"..(#names==1 and "" or "s")..":\n"..table.concat(shown,"\n")))
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
        for i,m in ipairs({{"quick","Quick tour","The most useful features · about 3 min"},{"full","Full tour","Every menu, stop by stop · about 5–10 min"}}) do
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
        or "Everything starts off. The tour shows each feature on your screen; keep what you like.")
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
