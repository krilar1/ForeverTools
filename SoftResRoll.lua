local _,FT=...
-- Soft reserve loot rolls, for the whole raid.
--   * The loot master (or the raid leader / an assistant) imports the list
--     once (/ft sr). ForeverTools sends it to everyone in the raid who has
--     the addon, so raiders see who reserved what on tooltips, the loot
--     window and in chat without importing anything.
--   * Boss dead: the loot master opens the loot and clicks the dice on an
--     item. Raid warning: "[Item] SR: A, B - roll now" (or "No SR - 100 main
--     spec, 99 off spec"). Everyone with the addon gets a roll window: the
--     item, who reserved it, a timer and the buttons to roll (or pass).
--     Players without the addon just /roll as usual.
--   * Rolls from chat are listed live, best first (reserved rolls, then main
--     spec, then off spec). When the time is up the loot master clicks
--     "Give to <name>": the item goes to them (master loot) and the raid is told.
-- Raiders' windows are on at first (System > Loot, merchant and mail > Soft
-- reserves > "Roll windows from the loot master"), and only open for rolls
-- started by the group's loot master, leader or an assistant.
local SR=FT.SoftRes
local Roll={}
local PREFIX="FTSR"
local SECONDS=20
local CHUNK=200
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local function lower(s) return type(s)=="string" and s:lower() or "" end
local function now() return GetTime and GetTime() or 0 end
local function short(name)
    name=text(name); if not name then return nil end
    if Ambiguate then local ok,s=pcall(Ambiguate,name,"short"); if ok and text(s) then name=s end end
    return (name:gsub("%-.*",""))
end
local function me() return short(UnitName and UnitName("player")) end
function Roll:Settings() return FT.modules.System:Settings() end
-- Windows and shared lists from the loot master: on unless switched off.
function Roll:On() return FT.dbReady and self:Settings().softResRolls~=false end
function Roll:InGroup() return (IsInGroup and IsInGroup()) and true or false end
function Roll:Channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
end
-- The group's master looter, by short name (nil when another loot method).
function Roll:MasterLooter()
    local get=(C_PartyInfo and C_PartyInfo.GetLootMethod) or GetLootMethod
    if not get then return nil end
    local ok,method,partyID,raidID=pcall(get)
    if not ok or not plain(method) then return nil end
    local ml=(Enum and Enum.LootMethod and Enum.LootMethod.Masterlooter) or 2
    if method~=ml and method~="master" then return nil end
    local unit
    if plain(raidID) and type(raidID)=="number" then unit="raid"..raidID
    elseif plain(partyID) and type(partyID)=="number" then unit=partyID==0 and "player" or ("party"..partyID) end
    return unit and short(UnitName(unit))
end
-- May this player start rolls and share lists? Loot master, leader or assistant.
function Roll:Trusted(name)
    name=short(name); if not name then return false end
    if not self:InGroup() then return name==me() end
    local function check(fn) if not fn then return false end; local ok,v=pcall(fn,name); return ok and plain(v) and v==true end
    if check(UnitIsGroupLeader) or check(UnitIsGroupAssistant) then return true end
    return lower(self:MasterLooter())==lower(name)
end
-- Sending, a little apart so the game never drops a message.
function Roll:Send(msg)
    if self.demo then return end
    local channel=self:Channel()
    if not channel or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    self.queue=self.queue or {}
    self.queue[#self.queue+1]={msg,channel}
    if self.sending then return end
    self.sending=true
    local function step()
        local item=table.remove(self.queue,1)
        if not item then self.sending=false; return end
        pcall(C_ChatInfo.SendAddonMessage,PREFIX,item[1],item[2])
        C_Timer.After(.25,step)
    end
    step()
end
function Roll:Say(msg)
    if self.demo then print("|cffffd100[Demo raid warning]|r "..msg); return end
    local channel
    if IsInRaid and IsInRaid() then
        channel=self:Trusted(me()) and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) and "RAID_WARNING" or "RAID"
    elseif IsInGroup and IsInGroup() then channel="PARTY" end
    if not channel then print("|cffffd100ForeverTools:|r "..msg.." (not in a group, only you see this)"); return end
    local send=(C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then pcall(send,msg,channel) end
end
-- Sharing the list --------------------------------------------------------------
-- A list from the guild website back as its string.
function SR:Serialize(ev)
    local players={}
    for i,p in ipairs(ev.players) do
        local items={}; for j,id in ipairs(p.items) do items[j]=tostring(id) end
        players[i]=p.first..":"..(p.last or "")..":"..p.class..":"..table.concat(items,",")
    end
    return table.concat({"FTSR1",ev.id,ev.raid,tostring(ev.start or 0),tostring(ev.limit or 1),(ev.title or ""):gsub("|",""),table.concat(players,";")},"|")
end
function Roll:Share(force)
    local ev=SR:Active()
    if not ev or ev.shared or not self:InGroup() or not self:Trusted(me()) then return false end
    if not force and self.sharedAt and now()-self.sharedAt<20 then return false end
    self.sharedAt=now()
    local raw=SR:Serialize(ev)
    local tag=ev.id..math.floor(now()*10)%100000
    local n=math.ceil(#raw/CHUNK)
    for i=1,n do self:Send("L|"..tag.."|"..i.."|"..n.."|"..raw:sub((i-1)*CHUNK+1,i*CHUNK)) end
    return true
end
function Roll:Received(raw,from)
    local ev=SR:Parse(raw); if not ev then return end
    local st=SR:Store(); local old=st.events[ev.id]
    -- Your own import of the same raid is kept.
    if type(old)=="table" and not old.shared then return end
    ev.shared=true; ev.from=from; ev.imported=time and time() or 0
    st.events[ev.id]=ev; st.active=ev.id
    SR:Prune(); SR:Rebuild(); SR:Apply()
    -- Tell you what you reserved, so you can check it is right.
    local mine
    for _,p in ipairs(ev.players) do if lower(p.first)==lower(me()) then mine=p end end
    local what
    if not mine then what="you are not on it."
    elseif #mine.items==0 then what="you have not reserved anything."
    else
        local names={}
        for i,id in ipairs(mine.items) do local _,link=SR.ItemInfo(id); names[i]=link:find("|H",1,true) and link or ("item "..id) end
        what="you reserved "..table.concat(names,", ").."."
    end
    if not old or self.lastToast~=ev.id then
        self.lastToast=ev.id
        print("|cffffd100ForeverTools:|r soft reserves for "..ev.title.." from "..tostring(from)..": "..what)
    end
end
-- Rolls ------------------------------------------------------------------------
-- "Name rolls 87 (1-100)" in any language: built from the game's own text.
local rollPattern
local function parseRoll(msg)
    if not rollPattern then
        local f=RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"
        f=f:gsub("%%%d%$","%%"):gsub("([%(%)%.%[%]%+%-%*%?%^%$])","%%%1"):gsub("%%s","(.+)"):gsub("%%d","(%%d+)")
        rollPattern="^"..f.."$"
    end
    local name,value,low,high=msg:match(rollPattern)
    if not name then return end
    return short(name),tonumber(value),tonumber(low),tonumber(high)
end
Roll.ParseRoll=parseRoll
local function itemID(link) local id=type(link)=="string" and link:match("item:(%d+)"); return id and tonumber(id) end
-- Who reserved an item: the demo's list while a demo runs.
function Roll:Holders(id)
    if self.demo then return self.demo.holders[id] end
    return SR:Holders(id)
end
-- In your group (demo players always are).
function Roll:Present(p) return self.demo~=nil or SR:Here(p) end
function Roll:NameList(list)
    if not self.demo then return SR:NameList(list) end
    local out={}; for i,p in ipairs(list) do out[i]="|cff"..SR.ClassHex(p.class)..p.first.."|r" end
    return table.concat(out,", ")
end
-- Start a roll on an item (loot master). slot: the loot window slot, when known.
function Roll:Start(link,id,slot,copies)
    if not link or not id then return end
    if not self.demo and self:InGroup() and not self:Trusted(me()) then FT:Toast("Only the loot master, the raid leader or an assistant can start a roll.",4); return end
    local holders=self:Holders(id)
    local mode=holders and "sr" or "open"
    local rollId=tostring(math.floor((time and time() or 0)%100000))..tostring(id%1000)
    copies=self.demo and (copies or 1) or 0
    for s2=1,(not self.demo and GetNumLootItems and LootFrame and LootFrame:IsShown() and GetNumLootItems() or 0) do
        local l=GetLootSlotLink and GetLootSlotLink(s2); if plain(l) and itemID(l)==id then copies=copies+1 end
    end
    copies=math.max(1,copies)
    self:Begin({id=rollId,itemID=id,link=link,mode=mode,seconds=SECONDS,leader=me(),slot=slot,mine=true,copies=copies})
    local names={}; for i,p in ipairs(holders or {}) do names[i]=p.first end
    local two=copies>1 and (" ("..copies.." drop)") or ""
    if mode=="sr" then self:Say(link..two.." SR"..(#names>1 and (" x"..#names) or "")..": "..table.concat(names,", ").." - roll now ("..SECONDS.." sec)")
    else self:Say(link..two.." No SR - /roll 100 main spec, /roll 99 off spec ("..SECONDS.." sec)") end
    self:Send("R|"..rollId.."|"..SECONDS.."|"..mode..copies.."|"..link)
end
function Roll:Begin(r)
    r.started=now(); r.ends=now()+(r.seconds or SECONDS); r.rolls={}; r.passed={}; r.given={}
    r.copies=r.copies or 1
    r.holders={}
    for _,p in ipairs(self:Holders(r.itemID) or {}) do r.holders[lower(p.first)]=p end
    -- A list the raider doesn't have says "sr" anyway: trust the loot master.
    self.roll=r
    self:Show()
    if self.demo and self.demo.OnStart then self.demo:OnStart(r) end
end
function Roll:Eligible(r,entry)
    if entry.removed then return false,"removed" end
    if r.tieOnly and not r.tieOnly[lower(entry.name)] then return false,"not in the tie" end
    if r.given[lower(entry.name)] then return false,"got one" end
    local kind=r.mode=="sr" and "SR" or (entry.high==99 and "OS" or "MS")
    if entry.accepted then return true,kind end
    if entry.late then return false,"late" end
    if entry.low~=1 then return false,"not 1-100" end
    if r.mode=="sr" then
        if entry.high~=100 then return false,"not /roll 100" end
        if next(r.holders) and not r.holders[lower(entry.name)] then return false,"not reserved" end
        return true,"SR"
    end
    if entry.high==100 then return true,"MS" end
    if entry.high==99 then return true,"OS" end
    return false,"not 100 or 99"
end
-- Valid rolls first (main spec before off spec), highest first.
function Roll:Ranked()
    local r=self.roll; if not r then return {} end
    local list={}
    for _,e in pairs(r.rolls) do local ok,kind=self:Eligible(r,e); e.ok=ok; e.kind=kind; list[#list+1]=e end
    table.sort(list,function(a,b)
        if a.ok~=b.ok then return a.ok end
        if (a.kind=="MS")~=(b.kind=="MS") and a.ok then return a.kind=="MS" end
        if a.value~=b.value then return a.value>b.value end
        return a.at<b.at
    end)
    return list
end
-- The winner, or nil and the tied names.
function Roll:Winner()
    local list=self:Ranked()
    local best=list[1]
    if not best or not best.ok then return nil end
    local tied={}
    for _,e in ipairs(list) do if e.ok and e.kind==best.kind and e.value==best.value then tied[#tied+1]=e.name end end
    if #tied>1 then return nil,tied end
    return best
end
function Roll:Heard(msg)
    local r=self.roll
    if not r or r.over or not plain(msg) or type(msg)~="string" then return end
    local name,value,low,high=parseRoll(msg)
    if not name or not value then return end
    -- The first roll counts. Rolling again is shown (the loot master decides);
    -- a roll after the time is up is listed as late.
    local old=r.rolls[lower(name)]
    if old and not old.reroll then old.extra=old.extra or {}; old.extra[#old.extra+1]=value; self:Refresh(); return end
    r.rolls[lower(name)]={name=name,value=value,low=low,high=high,at=now(),late=now()>r.ends+1}
    if lower(name)==lower(me()) then r.rolled=value end
    self:Refresh()
end
function Roll:DoRoll(high)
    local r=self.roll; if not r or r.over or r.rolled or r.passedMe then return end
    if self.demo then
        -- No real /roll in a demo: your roll shows up as from chat.
        local v=math.random(1,high)
        C_Timer.After(.4,function() if self.roll==r then self:Heard((RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)"):format(me(),v,1,high)) end end)
    elseif RandomRoll then pcall(RandomRoll,1,high) end
    r.rolledMax=high; self:Refresh()
end
function Roll:Pass()
    local r=self.roll; if not r then return end
    r.passedMe=true
    if not r.mine then self:Send("P|"..r.id) end
    self:Refresh()
end
-- Loot master: give the item (master loot) and tell the raid.
function Roll:GiveTo(name)
    local r=self.roll; if not r or not name or r.over then return end
    local given=false
    if not self.demo and GiveMasterLoot and GetMasterLootCandidate and GetNumLootItems and LootFrame and LootFrame:IsShown() then
        for slot=1,GetNumLootItems() do
            local link=GetLootSlotLink and GetLootSlotLink(slot)
            if plain(link) and itemID(link)==r.itemID then
                for i=1,40 do
                    local ok,candidate=pcall(GetMasterLootCandidate,slot,i)
                    if ok and plain(candidate) and lower(short(candidate))==lower(name) then
                        given=pcall(GiveMasterLoot,slot,i); break
                    end
                end
                if given then break end
            end
        end
    end
    local e=r.rolls[lower(name)]
    self:Say(r.link.." goes to "..name..(e and (" ("..e.value..(r.mode=="sr" and " SR" or e.kind=="OS" and " off spec" or "")..")") or ""))
    self:Send("E|"..r.id.."|"..name.."|"..(e and e.value or 0))
    self:Log(r,name,e)
    r.given[lower(name)]=true; r.winners=r.winners or {}; r.winners[#r.winners+1]=name
    if self.demo then print("|cffffd100[Demo]|r the item would go to "..name.." now (master loot).")
    elseif not given and GiveMasterLoot then FT:Toast("Give "..name.." the item from the loot window (it could not be handed out from here).",5) end
    -- Two of the same item: the roll stays open for the next best.
    r.copies=(r.copies or 1)-1
    if r.copies>0 then self:Refresh(); if self.demo and self.demo.OnGiven then self.demo:OnGiven(r,name) end; return end
    r.over=true; r.winner=table.concat(r.winners,", ")
    self:Refresh()
    if self.demo and self.demo.OnGiven then self.demo:OnGiven(r,name) end
    C_Timer.After(4,function() if self.roll==r and self.frame then self.frame:Hide() end end)
end
-- Who got what, kept with the raid's list (/ft sr shows it).
function Roll:Log(r,name,e)
    if self.demo then return end
    local ev=SR:Active(); if not ev then return end
    ev.awards=type(ev.awards)=="table" and ev.awards or {}
    ev.awards[#ev.awards+1]={item=r.itemID,to=name,roll=e and e.value or nil,sr=r.mode=="sr",at=time and time() or 0}
    if SR.Refresh then SR:Refresh() end
end
-- Loot master's fixes: take a roll out, let someone roll again, count a roll
-- the rules would not count, more time. Raiders' windows follow.
function Roll:Remove(name,back)
    local r=self.roll; local e=r and r.rolls[lower(name)]; if not e then return end
    e.removed=not back or nil
    if r.mine then self:Send((back and "B|" or "X|")..r.id.."|"..e.name) end
    self:Refresh()
end
function Roll:Reroll(name)
    local r=self.roll; if not r then return end
    local e=r.rolls[lower(name)]
    if e then e.reroll=true; r.rolls[lower(name)]=nil end
    r.passed[lower(name)]=nil
    if lower(name)==lower(me()) then r.rolled=nil; r.rolledMax=nil; r.passedMe=nil end
    -- More time if it was nearly up.
    if r.ends-now()<10 then r.ends=now()+10; r.closed=nil end
    if r.mine then self:Send("A|"..r.id.."|"..name); self:Say(name.." may roll again for "..r.link) end
    if r.tieOnly then r.tieOnly[lower(name)]=true end
    self:Refresh()
    if self.demo and self.demo.OnReroll then self.demo:OnReroll(r,{name}) end
end
function Roll:Accept(name)
    local r=self.roll; local e=r and r.rolls[lower(name)]; if not e then return end
    e.accepted=true; e.removed=nil
    if r.mine then self:Send("K|"..r.id.."|"..e.name) end
    self:Refresh()
end
function Roll:Extend(seconds)
    local r=self.roll; if not r or r.over then return end
    r.ends=math.max(r.ends,now())+seconds; r.closed=nil; r.seconds=math.max(r.seconds or SECONDS,r.ends-r.started)
    if r.mine then self:Send("T|"..r.id.."|"..math.floor(r.ends-now())) end
    self:Refresh()
end
-- Holders in the group who have not rolled (or passed) yet.
function Roll:Waiting()
    local r=self.roll; if not r or r.mode~="sr" then return {} end
    local out={}
    for key,p in pairs(r.holders) do
        if self:Present(p) and not r.rolls[key] and not r.passed[key] and not r.given[key] then out[#out+1]=p.first end
    end
    table.sort(out)
    return out
end
function Roll:Cancel()
    local r=self.roll; if not r then return end
    if r.mine then self:Send("C|"..r.id); self:Say(r.link.." roll cancelled") end
    r.over=true; r.cancelled=true
    if self.frame then self.frame:Hide() end
    if self.demo and self.demo.OnCancel then self.demo:OnCancel(r) end
end
-- An award from the loot master (raiders' windows).
function Roll:Awarded(id,name)
    local r=self.roll
    if not r or r.id~=id then return end
    r.given[lower(name)]=true; r.winners=r.winners or {}; r.winners[#r.winners+1]=name
    r.copies=(r.copies or 1)-1
    if r.copies>0 then self:Refresh(); return end
    r.over=true; r.winner=table.concat(r.winners,", "); self:Refresh()
    C_Timer.After(5,function() if self.roll==r and self.frame then self.frame:Hide() end end)
end
-- Messages from other players' ForeverTools -------------------------------------
function Roll:Message(msg,channel,sender)
    if self.demo or not plain(msg) or type(msg)~="string" or not plain(sender) then return end
    local from=short(sender); if not from or lower(from)==lower(me()) then return end
    local kind=msg:sub(1,1)
    if kind=="Q" then
        -- Someone joined: the loot master's list goes out again (once in a while).
        C_Timer.After(1+math.random()*2,function() self:Share() end)
        return
    end
    if kind=="P" then
        local id=msg:match("^P|(%w+)$"); local r=self.roll
        if r and r.id==id then r.passed[lower(from)]=from; self:Refresh() end
        return
    end
    if not self:On() or not self:Trusted(from) then return end
    if kind=="L" then
        local tag,i,n,chunk=msg:match("^L|(%w+)|(%d+)|(%d+)|(.*)$")
        i,n=tonumber(i),tonumber(n); if not tag or not i or not n or n>60 then return end
        self.parts=self.parts or {}
        local key=from..tag
        local p=self.parts[key] or {n=n,got=0,at=now()}; self.parts[key]=p
        if not p[i] then p[i]=chunk; p.got=p.got+1 end
        if p.got==p.n then self.parts[key]=nil; self:Received(table.concat(p,"",1,p.n),from) end
    elseif kind=="R" then
        local id,secs,mode,copies,link=msg:match("^R|(%w+)|(%d+)|(%a+)(%d*)|(.+)$")
        if not id then return end
        self:Begin({id=id,itemID=itemID(link),link=link,mode=mode,seconds=math.min(120,tonumber(secs) or SECONDS),leader=from,copies=math.max(1,math.min(5,tonumber(copies) or 1))})
    elseif kind=="E" then
        local id,name=msg:match("^E|(%w+)|([^|]+)|(%d+)$")
        if id then self:Awarded(id,name) end
    elseif kind=="X" or kind=="B" or kind=="A" or kind=="K" or kind=="T" or kind=="Z" then
        local id,arg=msg:match("^%a|(%w+)|([^|]+)$"); local r=self.roll
        if not r or r.id~=id then return end
        if kind=="X" then self:Remove(arg) elseif kind=="B" then self:Remove(arg,true)
        elseif kind=="A" then self:Reroll(arg) elseif kind=="K" then self:Accept(arg)
        elseif kind=="Z" then local names={}; for n in arg:gmatch("[^,]+") do names[#names+1]=n end; self:Tie(names)
        else local secs=tonumber(arg); if secs then r.ends=now()+secs; r.closed=nil; r.seconds=math.max(r.seconds or SECONDS,r.ends-r.started); self:Refresh() end end
    elseif kind=="C" then
        local id=msg:match("^C|(%w+)$"); local r=self.roll
        if r and r.id==id then r.over=true; r.cancelled=true; if self.frame then self.frame:Hide() end end
    end
end
-- The window -------------------------------------------------------------------
local W=340
local function button(parent,label,width,accent)
    local b=accent and FT:AccentButton(parent,label,width,28) or FT:QuietButton(parent,label,width,28)
    return b
end
function Roll:Build()
    local f=CreateFrame("Frame","ForeverToolsLootRoll",UIParent); self.frame=f
    f:SetSize(W,260); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving)
    f:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local x,y=owner:GetCenter(); if x and y then self:Settings().softResRollAt={x,y} end
    end)
    -- Closing the roll window during a demo ends the demo.
    FT:Panel(f); FT:AddClose(f,function() f:Hide(); if self.demo and FT.SoftResDemo then FT.SoftResDemo:Stop() end end,8)
    f.title=FT:Label(f,"Loot roll",16,true); f.title:SetPoint("TOPLEFT",16,-14); f.title:SetTextColor(1,.82,0)
    f.from=FT:Label(f,"",11); f.from:SetPoint("TOPLEFT",16,-34); f.from:SetTextColor(.66,.59,.48)
    if FT.SetTitleLine then FT:SetTitleLine(f,50) end
    local item=CreateFrame("Button",nil,f); item:SetSize(W-32,40); item:SetPoint("TOPLEFT",16,-58); f.item=item
    item.icon=item:CreateTexture(nil,"ARTWORK"); item.icon:SetSize(36,36); item.icon:SetPoint("LEFT"); FT:RoundIcon(item.icon)
    item.name=FT:Label(item,"",14,true); item.name:SetPoint("LEFT",item.icon,"RIGHT",10,0); item.name:SetWidth(W-90); item.name:SetJustifyH("LEFT")
    if item.name.SetWordWrap then item.name:SetWordWrap(false) end
    item:SetScript("OnEnter",function(owner)
        local r=self.roll; if not r or not r.link then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); pcall(GameTooltip.SetHyperlink,GameTooltip,r.link:match("|H(item:[^|]+)|h") or r.link); GameTooltip:Show()
    end)
    item:SetScript("OnLeave",function() GameTooltip:Hide() end)
    item:SetScript("OnClick",function() local r=self.roll; if r and IsShiftKeyDown and IsShiftKeyDown() and HandleModifiedItemClick then HandleModifiedItemClick(r.link) end end)
    local bar=CreateFrame("StatusBar",nil,f); bar:SetSize(W-32,6); bar:SetPoint("TOPLEFT",16,-104); f.bar=bar
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(1,.75,.2); bar:SetMinMaxValues(0,1)
    bar.bg=bar:CreateTexture(nil,"BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0,0,0,.5)
    f.time=FT:Label(f,"",11); f.time:SetPoint("TOPRIGHT",bar,"BOTTOMRIGHT",0,-3); f.time:SetTextColor(.85,.80,.70)
    f.sr=FT:Label(f,"",13); f.sr:SetPoint("TOPLEFT",16,-120); f.sr:SetWidth(W-32-60); f.sr:SetJustifyH("LEFT")
    if f.sr.SetWordWrap then f.sr:SetWordWrap(true) end
    f.you=FT:Label(f,"",12); f.you:SetPoint("TOPLEFT",f.sr,"BOTTOMLEFT",0,-4); f.you:SetWidth(W-32); f.you:SetJustifyH("LEFT")
    -- Your buttons.
    f.ms=button(f,"Main spec",96,true); f.ms:SetScript("OnClick",function() self:DoRoll(100) end)
    FT:Tooltip(f.ms,"Main spec","/roll 100")
    f.os=button(f,"Off spec",96); f.os:SetScript("OnClick",function() self:DoRoll(99) end)
    FT:Tooltip(f.os,"Off spec","/roll 99. Main spec rolls win over off spec rolls.")
    f.pass=button(f,"Pass",96); f.pass:SetScript("OnClick",function() self:Pass() end)
    FT:Tooltip(f.pass,"Pass","Don't roll on this item.")
    -- Rolls so far.
    f.head=FT:Label(f,"Rolls",12,true); f.head:SetTextColor(1,.82,0)
    f.lines={}
    for i=1,8 do
        -- A row is a button: the loot master clicks it for that player's options.
        local row=CreateFrame("Button",nil,f); row:SetSize(W-32,16); f.lines[i]=row; row.ftCombatOK=true
        local l=FT:Label(row,"",12); l:SetPoint("LEFT"); l:SetWidth(W-32); l:SetJustifyH("LEFT"); row.text=l
        if l.SetWordWrap then l:SetWordWrap(false) end
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        row:SetScript("OnClick",function(owner) self:RowMenu(owner) end)
        row.SetText=function(owner,t) owner.text:SetText(t) end
        FT:Tooltip(row,function() return row.name or "" end,function() return self:RowHint(row) end)
    end
    f.waiting=FT:Label(f,"",11); f.waiting:SetWidth(W-32); f.waiting:SetJustifyH("LEFT"); f.waiting:SetTextColor(1,.45,.38)
    if f.waiting.SetWordWrap then f.waiting:SetWordWrap(true) end
    -- Loot master's buttons.
    f.give=button(f,"",196,true); f.give:SetScript("OnClick",function() self:LeaderClick() end)
    FT:Tooltip(f.give,function() return f.give.label:GetText() end,function() return self:LeaderHint() end)
    f.cancel=button(f,"Cancel",104); f.cancel:SetScript("OnClick",function() self:Cancel() end)
    FT:Tooltip(f.cancel,"Cancel","Stop this roll. The raid is told.")
    f.more=button(f,"+10 sec",96); f.more:SetScript("OnClick",function() self:Extend(10) end)
    FT:Tooltip(f.more,"+10 seconds","More time to roll. Raiders' timers follow.")
    f.other=button(f,"Give to…",204); f.other.ftCombatOK=true; f.other:SetScript("OnClick",function(owner) self:GiveMenu(owner) end)
    FT:Tooltip(f.other,"Give to someone else","Pick anyone in the raid: a misroll, the winner already has it, disenchant or the bank.")
    f:SetScript("OnUpdate",function(_,dt)
        f.tick=(f.tick or 0)+dt; if f.tick<.1 then return end; f.tick=0
        self:Tick()
    end)
    f:Hide()
end
function Roll:Show()
    if not self.frame then self:Build() end
    local f=self.frame
    local at=self:Settings().softResRollAt
    f:ClearAllPoints()
    if type(at)=="table" and type(at[1])=="number" and type(at[2])=="number" then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",at[1],at[2])
    else f:SetPoint("TOP",UIParent,"TOP",0,-180) end
    if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound,SOUNDKIT.READY_CHECK) end
    self:Refresh(); f:Show()
end
function Roll:Tick()
    local r=self.roll; local f=self.frame; if not r or not f then return end
    local left=math.max(0,r.ends-now())
    f.bar:SetValue(r.over and 0 or left/(r.seconds or SECONDS))
    if not r.over and left<=0 and not r.closed then r.closed=true; self:Refresh() end
    f.time:SetText(r.over and "" or left>0 and (math.ceil(left).." sec") or "Time is up")
end
function Roll:LeaderHint()
    local r=self.roll; if not r then return "" end
    if not r.closed and not r.over then return "Stop the rolls now instead of waiting for the timer." end
    local best,tied=self:Winner()
    if tied then return "A tie: only "..table.concat(tied,", ").." roll again." end
    if not best then return "Nobody has a roll that counts. Roll again, or use Give to…" end
    return "Give the item to "..best.name.." (master loot) and tell the raid."
end
function Roll:LeaderClick()
    local r=self.roll; if not r or r.over then return end
    if not r.closed then r.ends=now(); r.closed=true; self:Refresh(); return end
    local best,tied=self:Winner()
    if best then self:GiveTo(best.name); return end
    if tied then
        -- Only the tied players roll again.
        self:Tie(tied)
        self:Say("Tie for "..r.link..": "..table.concat(tied,", ").." roll again ("..(SECONDS/2).." sec)")
        self:Send("Z|"..r.id.."|"..table.concat(tied,","))
        return
    end
    self:Start(r.link,r.itemID,r.slot)
end
-- A tie: only those players roll again, the others no longer count.
function Roll:Tie(names)
    local r=self.roll; if not r then return end
    r.tieOnly={}
    for _,name in ipairs(names) do
        local key=lower(name); r.tieOnly[key]=true
        local e=r.rolls[key]; if e then e.reroll=true; r.rolls[key]=nil end
        if key==lower(me()) then r.rolled=nil; r.rolledMax=nil; r.passedMe=nil end
    end
    r.ends=now()+(SECONDS/2); r.closed=nil; r.seconds=math.max(r.seconds or SECONDS,r.ends-r.started)
    self:Refresh()    if self.demo and self.demo.OnReroll then self.demo:OnReroll(r,names) end
end
-- The loot master clicks a roll: give it, take it out, let them roll again, or count it.
function Roll:RowHint(row)
    local r=self.roll; local e=row.entry
    if not r or not e then return "" end
    local lines={}
    if e.extra then lines[#lines+1]="Rolled "..(#e.extra+1).." times: "..e.value..", "..table.concat(e.extra,", ")..". The first counts." end
    if not e.ok then lines[#lines+1]="Not counted: "..tostring(e.kind).."." end
    if r.mine and not r.over then lines[#lines+1]="Click: give to them, take the roll out, let them roll again, or count it." end
    return table.concat(lines,"\n")
end
function Roll:RowMenu(row)
    local r=self.roll; local e=row.entry
    if not r or not e or not r.mine or r.over then return end
    local icon="Interface\\Icons\\INV_Misc_Dice_01"
    row.options=function()
        local list={{value="give",label="Give to "..e.name,icon="Interface\\Icons\\INV_Misc_Bag_10",tooltip="The item goes to them now, whatever the rolls."}}
        if e.removed then list[#list+1]={value="back",label="Put the roll back",icon=icon,tooltip="Count it again."}
        else list[#list+1]={value="remove",label="Take the roll out",icon=icon,tooltip="A misroll: it no longer counts."} end
        list[#list+1]={value="reroll",label="Let "..e.name.." roll again",icon=icon,tooltip="Clears their roll; the next one counts. The raid is told."}
        if not e.ok and not e.removed then list[#list+1]={value="accept",label="Count this roll",icon=icon,tooltip="Count it anyway (late, wrong range or not reserved)."} end
        return list
    end
    row.menuWidth=220
    row.onSelect=function(v)
        if v=="give" then self:GiveTo(e.name) elseif v=="remove" then self:Remove(e.name) elseif v=="back" then self:Remove(e.name,true)
        elseif v=="reroll" then self:Reroll(e.name) elseif v=="accept" then self:Accept(e.name) end
    end
    FT:ShowChoices(row)
end
-- Anyone in the group (raid order), for Give to…
function Roll:GiveMenu(owner)
    local r=self.roll; if not r or r.over then return end
    owner.options=function()
        local list,seen={},{}
        local function add(unit)
            local name=short(UnitName(unit)); if not name or seen[lower(name)] then return end
            seen[lower(name)]=true
            local _,class=UnitClass(unit)
            local p=r.holders[lower(name)]
            list[#list+1]={value=name,label="|cff"..SR.ClassHex(class)..name.."|r"..(p and "  |cffffd100SR|r" or ""),tooltip=p and "Reserved this item." or nil}
        end
        if self.demo then
            for _,p in ipairs(self.demo.raid) do
                seen[lower(p.first)]=true
                list[#list+1]={value=p.first,label="|cff"..SR.ClassHex(p.class)..p.first.."|r"..(r.holders[lower(p.first)] and "  |cffffd100SR|r" or "")}
            end
        elseif IsInRaid and IsInRaid() then for i=1,40 do add("raid"..i) end
        else add("player"); for i=1,4 do add("party"..i) end end
        table.sort(list,function(a,b) return lower(a.value)<lower(b.value) end)
        return list
    end
    owner.menuWidth=204
    owner.onSelect=function(name) FT:Confirm("Give "..r.link.." to "..name.."?",function() self:GiveTo(name) end,true) end
    FT:ShowChoices(owner)
end
function Roll:Refresh()
    local r=self.roll; local f=self.frame; if not r or not f then return end
    f.title:SetText(r.mode=="sr" and "Soft reserve roll" or "Loot roll")
    local copies=(r.copies or 1)>1 and ("  ·  "..r.copies.." left") or ""
    f.from:SetText((self.demo and "|cff66c0ffDemo|r  ·  " or "")..(r.mine and (self.demo and "You are the loot master" or self:InGroup() and "You started this roll" or "Only you see this (not in a group)") or ("From "..tostring(r.leader)))..copies)
    local _,_,quality,icon=SR.ItemInfo(r.itemID or 0)
    f.item.icon:SetTexture(icon); f.item.name:SetText(r.link or "?")
    -- Who reserved it, and whether it's you.
    local holders=self:Holders(r.itemID)
    local you=lower(me())
    local reservedByYou=r.holders[you]~=nil
    if r.mode=="sr" then
        f.sr:SetText("|cffffd100Soft reserved by:|r "..(holders and self:NameList(holders) or "(you don't have the list)"))
        if reservedByYou then f.you:SetText("|cff8fd18fYou reserved this: roll!|r")
        elseif next(r.holders) then f.you:SetText("|cffa8967aOnly players who reserved it roll.|r")
        else f.you:SetText("|cffa8967aRoll if you reserved it.|r") end
    else
        f.sr:SetText("|cff8fd18fNo soft reserves:|r main spec rolls 100, off spec 99.")
        f.you:SetText("")
    end
    local mineEntry=r.rolls[you]
    if mineEntry and mineEntry.removed then f.you:SetText("|cffff7060The loot master took your roll out.|r")
    elseif r.rolled then f.you:SetText((f.you:GetText() or "").."  You rolled |cffffffff"..r.rolled.."|r.")
    elseif r.passedMe then f.you:SetText("You passed.") end
    -- Your buttons: reserved roll = one Roll button; open roll = main/off spec.
    local canRoll=not r.over and not r.closed and not r.rolled and not r.passedMe and not r.rolledMax
    local srRoll=r.mode=="sr"
    local mayRoll=not srRoll or reservedByYou or not next(r.holders)
    f.ms.label:SetText(srRoll and "Roll (SR)" or "Main spec")
    f.ms:SetShown(mayRoll); f.os:SetShown(not srRoll); f.pass:SetShown(true)
    for _,b in ipairs({f.ms,f.os,f.pass}) do b:SetEnabled(canRoll); b:SetAlpha(canRoll and 1 or .45) end
    local y=-120-(f.sr:GetStringHeight() or 14)-4-((f.you:GetText() or "")~="" and 18 or 0)-8
    local x=16
    for _,b in ipairs({f.ms,f.os,f.pass}) do if b:IsShown() then b:ClearAllPoints(); b:SetPoint("TOPLEFT",x,y); x=x+104 end end
    y=y-36
    -- The rolls, best first; the one in front is marked.
    f.head:ClearAllPoints(); f.head:SetPoint("TOPLEFT",16,y)
    local list=self:Ranked()
    local passed=0; for _ in pairs(r.passed) do passed=passed+1 end
    f.head:SetText("Rolls"..(#list>0 and (" ("..#list..")") or "")..(passed>0 and ("  ·  "..passed.." passed") or ""))
    y=y-18
    local best=self:Winner()
    for i,row in ipairs(f.lines) do
        local e=list[i]
        row.entry=e; row.name=e and e.name
        if e then
            local p=r.holders[lower(e.name)]
            local hex=p and SR.ClassHex(p.class) or "ffffff"
            local tag
            if r.given[lower(e.name)] then tag=" |cff8fd18fgot it|r"
            elseif e.ok then tag=(e.kind=="SR" and " |cffffd100SR|r" or e.kind=="OS" and " |cffa8967aoff spec|r" or "")..(e.accepted and " |cffa8967a(counted)|r" or "")
            else tag=" |cff8a8a8a("..e.kind..")|r" end
            local again=e.extra and (" |cffff9a3drolled again: "..table.concat(e.extra,", ").."|r") or ""
            local lead=(best and best==e) and "|cffffd100»|r " or "   "
            row:SetText(lead.."|cff"..(e.ok and hex or "8a8a8a")..e.name.."|r  "..(e.ok and "|cffffffff" or "|cff8a8a8a")..e.value.."|r"..tag..again)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT",16,y); row:Show(); row:EnableMouse(true); y=y-16
        else row:Hide() end
    end
    if #list==0 then local row=f.lines[1]; row.entry=nil; row:SetText("|cff8a8a8aNo rolls yet.|r"); row:ClearAllPoints(); row:SetPoint("TOPLEFT",16,y); row:Show(); row:EnableMouse(false); y=y-16 end
    -- Reservers who still have to roll.
    local waiting=not r.over and self:Waiting() or {}
    if #waiting>0 then
        f.waiting:SetText("Not rolled yet: "..table.concat(waiting,", ")); f.waiting:ClearAllPoints(); f.waiting:SetPoint("TOPLEFT",16,y-2); f.waiting:Show()
        y=y-4-(f.waiting:GetStringHeight() or 12)
    else f.waiting:Hide() end
    -- Result, or the loot master's buttons.
    y=y-8
    if r.over then
        f.give:Hide(); f.cancel:Hide(); f.more:Hide(); f.other:Hide()
        if r.winner then f.time:SetText(""); f.you:SetText("|cff8fd18fWon by "..r.winner..".|r") end
    elseif r.mine then
        local b,tied=self:Winner()
        local next_=r.winners and #r.winners>0 and "Give next to " or "Give to "
        local label=not r.closed and "End rolls now" or b and (next_..b.name) or tied and "Tie: roll again" or "Roll again"
        f.give.label:SetText(label)
        f.give:ClearAllPoints(); f.give:SetPoint("TOPLEFT",16,y); f.give:Show()
        f.cancel:ClearAllPoints(); f.cancel:SetPoint("LEFT",f.give,"RIGHT",8,0); f.cancel:Show()
        y=y-34
        f.more:ClearAllPoints(); f.more:SetPoint("TOPLEFT",16,y); f.more:Show()
        f.other:ClearAllPoints(); f.other:SetPoint("LEFT",f.more,"RIGHT",8,0); f.other:Show()
        y=y-36
    else f.give:Hide(); f.cancel:Hide(); f.more:Hide(); f.other:Hide() end
    f:SetHeight(-y+12)
    self:Tick()
end
-- /ft srtest (and /ft srdemo): the demo (SoftResDemo.lua).
function Roll:Test() if FT.SoftResDemo then FT.SoftResDemo:Ask() end end
-- Rolls happen in fights too: the window stays open and works.
Roll.combatOK=true
FT:RegisterModule("SoftResRoll",Roll)
FT.SoftResRoll=Roll
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("CHAT_MSG_ADDON"); events:RegisterEvent("GROUP_ROSTER_UPDATE"); events:RegisterEvent("CHAT_MSG_SYSTEM")
local wasInGroup=false
events:SetScript("OnEvent",function(_,event,a,b,c,d)
    if event=="CHAT_MSG_ADDON" then
        if plain(a) and a==PREFIX then Roll:Message(b,c,d) end
    elseif event=="CHAT_MSG_SYSTEM" then
        -- Real rolls don't count in a demo.
        if Roll.roll and not Roll.roll.over and not Roll.demo then Roll:Heard(a) end
    elseif event=="PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
        wasInGroup=Roll:InGroup()
        -- Back in a raid after a reload: ask for the list.
        if wasInGroup and FT.dbReady and Roll:On() then C_Timer.After(5,function() Roll:Send("Q") end) end
    elseif event=="GROUP_ROSTER_UPDATE" then
        local inGroup=Roll:InGroup()
        if inGroup and not wasInGroup and FT.dbReady and Roll:On() then C_Timer.After(3,function() Roll:Send("Q") end) end
        wasInGroup=inGroup
    end
end)
