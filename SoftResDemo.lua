local _,FT=...
-- Soft reserve demo: practise a raid's loot rolls on your own (/ft srdemo, or
-- "Try it (demo)" in /ft sr). Fake raiders roll, pass, misroll and tie, as in
-- a real raid. Nothing is sent to the raid, no /roll is made and nothing is
-- handed out; real rolls in chat are ignored while it runs.
--   Loot master: a demo loot window with four items. Click the dice to start
--     a roll, watch the rolls come in, fix misrolls, break a tie and give the
--     item (two copies of one item).
--   Raider: a fake loot master starts three rolls: an item you reserved, one
--     reserved by others, and an open roll (main spec / off spec / pass).
local SR=FT.SoftRes
local Roll=FT.SoftResRoll
local Demo={}
local LEADER="Kjell"
local function lower(s) return type(s)=="string" and s:lower() or "" end
local function me()
    local n=UnitName and UnitName("player")
    if type(n)~="string" or (issecretvalue and issecretvalue(n)) then return "You" end
    return (n:gsub("%-.*",""))
end
-- Invented raiders (not real players).
local RAID={
    {first="Bonk",class="SHAMAN"},{first="Aksje",class="DRUID"},{first="Frost",class="MAGE"},
    {first="Tamp",class="WARRIOR"},{first="Mira",class="PALADIN"},{first="Varg",class="WARLOCK"},
    {first=LEADER,class="PALADIN"},
}
local ITEMS={
    {id=16800,name="Arcanist Boots",sr={"@me","Bonk"}},
    {id=17063,name="Band of Accuria",sr={"Frost","Mira"}},
    {id=17109,name="Choker of Enlightenment"},
    {id=18823,name="Aged Core Leather Gloves",sr={"Tamp","Varg","Aksje"},copies=2},
}
local function itemLink(it)
    local _,link=SR.ItemInfo(it.id)
    if type(link)=="string" and link:find("|H",1,true) then return link end
    return "|cffa335ee|Hitem:"..it.id.."::::::::60:::::|h["..it.name.."]|h|r"
end
-- The demo raid and who reserved what.
function Demo:Data()
    local _,class=UnitClass and UnitClass("player")
    local raid={{first=me(),last="",class=class or "WARRIOR",items={}}}
    local by={}; by[lower(raid[1].first)]=raid[1]
    for _,p in ipairs(RAID) do local c={first=p.first,last="",class=p.class,items={}}; raid[#raid+1]=c; by[lower(p.first)]=c end
    local holders={}
    for _,it in ipairs(ITEMS) do
        if it.sr then
            local list={}
            for _,n in ipairs(it.sr) do local p=by[lower(n=="@me" and me() or n)]; list[#list+1]=p; p.items[#p.items+1]=it.id end
            holders[it.id]=list
        end
    end
    return raid,holders,by
end
-- Timers that stop when the demo or the roll is over.
function Demo:After(secs,r,fn)
    local token=self.token
    C_Timer.After(secs,function()
        if self.token~=token or not Roll.demo then return end
        if r and (Roll.roll~=r or r.over) then return end
        fn()
    end)
end
local function rollText(name,v,low,high) return (RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"):format(name,v,low or 1,high or 100) end
function Demo:FakeRoll(r,secs,name,v,high,low)
    self.lastHigh=self.lastHigh or {}; self.lastHigh[lower(name)]=high or 100
    self:After(secs,r,function() Roll:Heard(rollText(name,v or math.random(1,high or 100),low or 1,high or 100)) end)
end
-- A roll that comes 2 seconds after the time is up (however it ended).
function Demo:FakeLate(r,name,high)
    local function wait()
        self:After(1,r,function()
            if (GetTime and GetTime() or 0)>r.ends+1.5 then Roll:Heard(rollText(name,math.random(1,high),1,high)) else wait() end
        end)
    end
    wait()
end
function Demo:FakePass(r,secs,name)
    self:After(secs,r,function() r.passed[lower(name)]=name; Roll:Refresh() end)
end
-- Start / stop ---------------------------------------------------------------
function Demo:Begin(role)
    if Roll.roll and not Roll.roll.over and not Roll.demo then FT:Toast("A real roll is running. Try the demo after it.",4); return end
    self:Stop(true)
    self.token=(self.token or 0)+1
    local raid,holders=self:Data()
    self.role=role; self.given={}; self.step=0; self.done=false; self.lastHigh={}
    Roll.demo={raid=raid,holders=holders,role=role,
        OnStart=function(_,r) Demo:OnStart(r) end,
        OnReroll=function(_,r,names) Demo:OnReroll(r,names) end,
        OnGiven=function(_,r,name) Demo:OnGiven(r,name) end,
        OnCancel=function() Demo:Refresh() end}
    print("|cffffd100ForeverTools:|r soft reserve demo ("..(role=="lm" and "loot master" or "raider").."). Only you see it; nothing is sent to the raid.")
    if role=="raider" then self:Raider() end
    self:Show()
end
function Demo:Stop(quiet)
    if not Roll.demo then if self.frame and not quiet then self.frame:Hide() end; return end
    self.token=(self.token or 0)+1
    Roll.demo=nil
    if Roll.roll then Roll.roll.over=true; Roll.roll=nil end
    if Roll.frame then Roll.frame:Hide() end
    if not quiet then
        if self.frame then self.frame:Hide() end
        print("|cffffd100ForeverTools:|r soft reserve demo ended.")
    end
end
-- Loot master ----------------------------------------------------------------
-- Scripted raiders for each item: holders roll, a misroll, a second roll,
-- someone late, a tie, passes.
function Demo:OnStart(r)
    if self.role~="lm" then return end
    local id=r.itemID
    if id==16800 then
        self:FakeRoll(r,2,"Bonk",64)
        self:FakeRoll(r,3.5,"Varg",91)            -- didn't reserve it
        self:FakeRoll(r,6,"Bonk",88)              -- rolled again
    elseif id==17063 then
        self:FakeRoll(r,2.5,"Frost",77)
        self:FakeRoll(r,4,"Aksje",412,1000)       -- /roll 1000
        self:FakeRoll(r,5.5,"Mira",77)            -- a tie with Frost
    elseif id==17109 then
        self:FakeRoll(r,2,"Tamp",83)
        self:FakeRoll(r,3,"Frost",95,99)          -- off spec
        self:FakeRoll(r,4,"Varg",41)
        self:FakePass(r,5,"Mira")
        self:FakeLate(r,"Aksje",99)               -- after the time is up
    elseif id==18823 then
        self:FakeRoll(r,2,"Varg",90)
        self:FakeRoll(r,3.5,"Tamp",55)
        self:FakeRoll(r,12,"Aksje",72)            -- slow: "Not rolled yet" until then
    end
end
-- Let someone roll again / a tie: the fake raiders roll again (never the same).
function Demo:OnReroll(r,names)
    local used={}
    for i,name in ipairs(names) do
        if lower(name)~=lower(me()) then
            local high=r.mode=="open" and (self.lastHigh and self.lastHigh[lower(name)] or 100) or 100
            local v; repeat v=math.random(1,high) until not used[v]; used[v]=true
            self:FakeRoll(r,1.5+i*1.2,name,v,high)
        end
    end
end
function Demo:OnGiven(r,name)
    if self.role=="lm" then
        self.given[r.itemID]=self.given[r.itemID] or {}
        local g=self.given[r.itemID]; g[#g+1]=name
        self:Refresh()
    end
end
-- Raider ---------------------------------------------------------------------
-- A fake loot master starts three rolls, one after another.
local STEPS={
    {item=1,text="Kjell started a roll on an item |cff8fd18fyou reserved|r. Press Roll (SR) before the timer runs out.",
        fake=function(d,r) d:FakeRoll(r,2.5,"Bonk",math.random(30,95)) end},
    {item=2,text="An item reserved by others: only they roll. You can only pass.",
        fake=function(d,r) d:FakeRoll(r,2,"Frost",45); d:FakeRoll(r,3.5,"Mira",88); d:FakeRoll(r,5,"Tamp",97) end},
    {item=3,text="No soft reserves: Main spec rolls 100, Off spec rolls 99 (main spec wins). Or pass.",
        fake=function(d,r) d:FakeRoll(r,2,"Tamp",63); d:FakeRoll(r,3,"Frost",97,99); d:FakePass(r,4,"Varg"); d:FakeRoll(r,6,"Aksje",58) end},
}
local SECS=15
function Demo:Raider()
    self.step=self.step+1
    local step=STEPS[self.step]
    if not step then
        self.done=true; self:Refresh()
        print("|cffffd100ForeverTools:|r demo finished. Click Again for another go, or End demo.")
        return
    end
    self:After(self.step==1 and 1 or 2,nil,function()
        local it=ITEMS[step.item]; local link=itemLink(it)
        local holders=Roll.demo.holders[it.id]
        local names={}; for i,p in ipairs(holders or {}) do names[i]=p.first end
        print("|cffffd100[Demo raid warning]|r "..LEADER..": "..link..(holders and (" SR"..(#names>1 and (" x"..#names) or "")..": "..table.concat(names,", ").." - roll now") or " No SR - /roll 100 main spec, /roll 99 off spec").." ("..SECS.." sec)")
        local r={id="demo"..self.step,itemID=it.id,link=link,mode=holders and "sr" or "open",seconds=SECS,leader=LEADER,copies=1}
        Roll:Begin(r)
        step.fake(self,r)
        self:Refresh()
        -- Time up: the loot master gives it to the best roll.
        self:After(SECS+2.5,r,function()
            local best,tied=Roll:Winner()
            local name=best and best.name or (tied and tied[1]) or "Tamp"
            local e=r.rolls[lower(name)]
            print("|cffffd100[Demo raid warning]|r "..LEADER..": "..link.." goes to "..name..(e and (" ("..e.value..(r.mode=="sr" and " SR" or e.kind=="OS" and " off spec" or "")..")") or ""))
            Roll:Awarded(r.id,name)
            self:After(5,nil,function() self:Raider() end)
        end)
    end)
end
-- The window -----------------------------------------------------------------
local W=320
function Demo:Build()
    local f=CreateFrame("Frame","ForeverToolsSRDemo",UIParent); self.frame=f
    f:SetSize(W,200); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
    FT:Panel(f); FT:AddClose(f,function() self:Stop() end,8)
    -- However the window goes away (X, Escape, End demo), the demo stops.
    f:HookScript("OnHide",function() if Roll.demo then self:Stop() end end)
    if UISpecialFrames then table.insert(UISpecialFrames,"ForeverToolsSRDemo") end
    f.title=FT:Label(f,"Soft reserve demo",16,true); f.title:SetPoint("TOPLEFT",16,-14); f.title:SetTextColor(1,.82,0)
    if FT.SetTitleLine then FT:SetTitleLine(f,42) end
    f.text=FT:Label(f,"",12); f.text:SetPoint("TOPLEFT",16,-52); f.text:SetWidth(W-32); f.text:SetJustifyH("LEFT"); f.text:SetTextColor(.85,.80,.70)
    if f.text.SetWordWrap then f.text:SetWordWrap(true) end
    f.lm=FT:AccentButton(f,"Loot master",140,30,"INV_Misc_Bag_10"); f.lm:SetScript("OnClick",function() self:Begin("lm") end)
    FT:Tooltip(f.lm,"Loot master","Start rolls on demo loot, fix misrolls, break a tie and give the items.")
    f.raider=FT:QuietButton(f,"Raider",140,30,"INV_Misc_Dice_01"); f.raider:SetScript("OnClick",function() self:Begin("raider") end)
    FT:Tooltip(f.raider,"Raider","A fake loot master starts three rolls: one you reserved, one reserved by others and an open roll.")
    f.rows={}
    for i,it in ipairs(ITEMS) do
        local row=CreateFrame("Frame",nil,f); row:SetSize(W-32,40); f.rows[i]=row; row.it=it
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(30,30); row.icon:SetPoint("LEFT"); FT:RoundIcon(row.icon)
        row.name=FT:Label(row,"",12,true); row.name:SetPoint("TOPLEFT",row.icon,"TOPRIGHT",8,-1); row.name:SetWidth(W-32-38-34); row.name:SetJustifyH("LEFT")
        row.sr=FT:Label(row,"",11); row.sr:SetPoint("TOPLEFT",row.name,"BOTTOMLEFT",0,-2); row.sr:SetWidth(W-32-38-34); row.sr:SetJustifyH("LEFT")
        for _,l in ipairs({row.name,row.sr}) do if l.SetWordWrap then l:SetWordWrap(false) end end
        local dice=CreateFrame("Button",nil,row); dice:SetSize(26,26); dice:SetPoint("RIGHT"); row.dice=dice
        dice.tex=dice:CreateTexture(nil,"ARTWORK"); dice.tex:SetAllPoints(); dice.tex:SetTexture("Interface\\Icons\\INV_Misc_Dice_01"); FT:RoundIcon(dice.tex)
        dice:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        dice:SetScript("OnClick",function()
            if Roll.roll and not Roll.roll.over then FT:Toast("Finish or cancel the roll that is running first.",3); return end
            Roll:Start(itemLink(it),it.id,nil,it.copies)
        end)
        FT:Tooltip(dice,"Start a roll","As the dice on the loot window: a raid warning and roll windows for the raid (demo: only you).")
    end
    f.again=FT:QuietButton(f,"Again",140,28); f.again:SetScript("OnClick",function() self:Begin(self.role) end)
    f.stop=FT:QuietButton(f,"End demo",140,28); f.stop:SetScript("OnClick",function() self:Stop() end)
    f:SetPoint("TOPRIGHT",UIParent,"TOP",-182,-180)
    f:Hide()
end
function Demo:Show()
    if not self.frame then self:Build() end
    self:Refresh(); self.frame:Show()
end
function Demo:Refresh()
    local f=self.frame; if not f then return end
    local role=Roll.demo and self.role
    f.lm:SetShown(not role); f.raider:SetShown(not role)
    for _,row in ipairs(f.rows) do row:Hide() end
    f.again:Hide(); f.stop:Hide()
    local y
    if not role then
        f.title:SetText("Soft reserve demo")
        f.text:SetText("Practise a raid's loot rolls on your own. Fake raiders roll, pass, misroll and tie. Nothing is sent to the raid, no /roll is made and nothing is handed out.\n\nTry it as:")
        y=-52-(f.text:GetStringHeight() or 60)-10
        f.lm:ClearAllPoints(); f.lm:SetPoint("TOPLEFT",16,y); f.raider:ClearAllPoints(); f.raider:SetPoint("LEFT",f.lm,"RIGHT",8,0)
        y=y-40
    elseif role=="lm" then
        f.title:SetText("Demo loot  ·  loot master")
        f.text:SetText("Click the dice on an item to start a roll. Click a roll in the list to take it out, let them roll again or count it. Then give the item.")
        y=-52-(f.text:GetStringHeight() or 40)-8
        local _,holders=nil,Roll.demo.holders
        for _,row in ipairs(f.rows) do
            local it=row.it
            local _,_,_,icon=SR.ItemInfo(it.id)
            row.icon:SetTexture(icon); row.name:SetText(itemLink(it)..((it.copies or 1)>1 and (" |cffa8967ax"..it.copies.."|r") or ""))
            local g=self.given[it.id]
            local list=holders[it.id]
            if g and #g>=(it.copies or 1) then row.sr:SetText("|cff8fd18fGiven to "..table.concat(g,", ").."|r"); row.icon:SetDesaturated(true)
            else
                row.icon:SetDesaturated(false)
                row.sr:SetText(list and ("|cffffd100SR:|r "..Roll:NameList(list)) or "|cff8fd18fNo SR|r  |cffa8967aopen roll|r")
            end
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",16,y); row:Show(); y=y-44
        end
        y=y-6
    else
        f.title:SetText("Demo  ·  raider")
        local step=STEPS[self.step]
        f.text:SetText(self.done and "|cff8fd18fDemo finished.|r In a raid it works the same: the loot master's ForeverTools opens these windows for you. Players without the addon just /roll."
            or step and ("|cffffd100Roll "..self.step.." of "..#STEPS..":|r "..step.text) or "The loot master is about to start a roll…")
        y=-52-(f.text:GetStringHeight() or 40)-10
    end
    if role then
        f.again:ClearAllPoints(); f.again:SetPoint("TOPLEFT",16,y); f.again:Show()
        f.stop:ClearAllPoints(); f.stop:SetPoint("LEFT",f.again,"RIGHT",8,0); f.stop:Show()
        y=y-36
    end
    f:SetHeight(-y+8)
end
-- /ft srdemo [lm|raider|stop]
function Demo:Ask(arg)
    arg=lower(arg)
    if arg=="stop" or arg=="end" then self:Stop(); return end
    if arg=="lm" or arg=="loot" or arg=="master" or arg=="officer" then self:Begin("lm"); return end
    if arg=="raider" or arg=="raid" then self:Begin("raider"); return end
    if Roll.demo then self:Show(); return end
    self.role=nil; self:Show()
end
Demo.combatOK=true
FT:RegisterModule("SoftResDemo",Demo)
FT.SoftResDemo=Demo
