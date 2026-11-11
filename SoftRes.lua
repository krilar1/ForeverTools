local _,FT=...
-- Soft reserves (System > Loot and merchant > Soft reserves, /ft sr).
-- A raid's soft reserves are made on the guild website and pasted in here as
-- one line of text (addons can't fetch anything from the web):
--   FTSR1|eventId|raidKey|startUnix|limit|title|player;player;...
--   player = first:last:Class:itemId,itemId,...   (no items = signed up, nothing reserved)
-- Who reserved what then shows on the loot window, under item links in raid
-- and party chat, and on item tooltips. Players are matched to characters
-- by first name (no realm, any case); the last name is only shown.
-- The lists are kept on the account (never in profiles or exports).
local SR={}
local RAIDS={mc="Molten Core",ony="Onyxia's Lair",bwl="Blackwing Lair",zg="Zul'Gurub",aq20="Ruins of Ahn'Qiraj",aq40="Temple of Ahn'Qiraj",naxx="Naxxramas"}
local CLASSES={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
SR.RAIDS,SR.CLASSES=RAIDS,CLASSES
local KEEP_EVENTS=10          -- lists kept on the account
local KEEP_DAYS=30            -- older raids are forgotten
local NO_SR_QUALITY=3         -- "No SR" is pointed out for rare items and better
local CHAT_EVENTS={"CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER"}
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local function lower(s) return type(s)=="string" and s:lower() or "" end
local function now() return GetTime and GetTime() or 0 end
local function settings() return FT.modules.System:Settings() end
-- On when switched on, or when the loot master shared a list with you (raiders
-- see it without importing; "Roll windows from the loot master" off stops that).
function SR:Enabled()
    local s=settings()
    if s.softRes==true then return true end
    if s.softResRolls==false then return false end
    local st=FT.db and FT.db.softRes
    local ev=type(st)=="table" and type(st.events)=="table" and st.active and st.events[st.active]
    return type(ev)=="table" and ev.shared==true
end
-- Stored lists ------------------------------------------------------------------
function SR:Store()
    if type(FT.db.softRes)~="table" then FT.db.softRes={} end
    local st=FT.db.softRes
    if type(st.events)~="table" then st.events={} end
    return st
end
function SR:Active()
    local st=self:Store()
    local e=st.active and st.events[st.active]
    if type(e)=="table" then return e end
    -- The newest import when the chosen one is gone.
    local best
    for _,ev in pairs(st.events) do if type(ev)=="table" and (not best or (ev.imported or 0)>(best.imported or 0)) then best=ev end end
    st.active=best and best.id or nil
    return best
end
function SR:EventList()
    local list={}
    for _,ev in pairs(self:Store().events) do if type(ev)=="table" then list[#list+1]=ev end end
    table.sort(list,function(a,b) return (a.start or 0)>(b.start or 0) end)
    return list
end
-- Old raids go, and at most KEEP_EVENTS are kept (the newest).
function SR:Prune()
    local st=self:Store(); local t=time and time() or 0
    for id,ev in pairs(st.events) do
        if type(ev)~="table" or ((ev.start or 0)>0 and t-(ev.start or 0)>KEEP_DAYS*86400) then st.events[id]=nil end
    end
    local list=self:EventList()
    for i=KEEP_EVENTS+1,#list do st.events[list[i].id]=nil end
    if st.active and not st.events[st.active] then st.active=nil end
end
-- Reading a string --------------------------------------------------------------
local function split(s,sep)
    local out={}
    for piece in (s..sep):gmatch("(.-)"..sep:gsub("%p","%%%0")) do out[#out+1]=piece end
    return out
end
local function className(token) return token:sub(1,1)..token:sub(2):lower() end
-- Returns the list, or nil and a message for the player.
function SR:Parse(raw)
    if type(raw)~="string" then return nil,"Paste a soft reserve string first." end
    -- Edit boxes show a typed | as ||; line breaks from copying are dropped.
    local s=raw:gsub("||","|"):gsub("[\r\n]",""):match("^%s*(.-)%s*$")
    if s=="" then return nil,"Paste a soft reserve string first." end
    if s:sub(1,4)=="FT1:" then return nil,"That is a ForeverTools profile string. It goes in Profiles > Import." end
    local version=s:match("^FTSR(%d+)|")
    if version and version~="1" then return nil,"This string is for a newer ForeverTools (FTSR"..version.."). Update the addon and try again." end
    if not version then return nil,"This is not a ForeverTools soft reserve string. It should start with FTSR1|| and comes from the guild website (softres.it lists don't work here)." end
    local f=split(s,"|")
    if #f~=7 then return nil,"The string is cut short or has extra parts ("..#f.." of 7). Copy it again from the guild website." end
    local id,raid,start,limit,title,players=f[2],f[3]:lower(),f[4],f[5],f[6],f[7]
    if not id:match("^%w+$") then return nil,"The raid id is missing or wrong." end
    if not RAIDS[raid] then return nil,'Unknown raid "'..f[3]..'". Known: mc, ony, bwl, zg, aq20, aq40, naxx.' end
    if not start:match("^%d+$") then return nil,"The raid's start time is not a number." end
    if not limit:match("^%d+$") or tonumber(limit)<1 then return nil,"The reserve limit is not a number." end
    title=title:match("^%s*(.-)%s*$")
    if title=="" then title=RAIDS[raid] end
    local ev={id=id,raid=raid,start=tonumber(start),limit=tonumber(limit),title=title:sub(1,60),players={}}
    local seen={}
    for i,entry in ipairs(players~="" and split(players,";") or {}) do
        if entry~="" then
            local parts=split(entry,":")
            local first=(parts[1] or ""):match("^%s*(.-)%s*$")
            local who=first~="" and ("Player "..i.." ("..first..")") or ("Player "..i)
            if #parts~=4 then return nil,who.." has "..(#parts-1).." colons (3 expected)." end
            if first=="" then return nil,who.." has no first name." end
            local class=parts[3]:upper():match("^%s*(.-)%s*$")
            if not CLASSES[class] then return nil,who..' has an unknown class "'..parts[3]..'".' end
            local items,have={},{}
            for _,item in ipairs(parts[4]~="" and split(parts[4],",") or {}) do
                item=item:match("^%s*(.-)%s*$")
                if item~="" then
                    if not item:match("^%d+$") or tonumber(item)<1 then return nil,who..' has a wrong item number "'..item..'".' end
                    local n=tonumber(item)
                    if not have[n] then have[n]=true; items[#items+1]=n end
                end
            end
            local key=lower(first)
            ev.players[#ev.players+1]={first=first,last=parts[2]:match("^%s*(.-)%s*$"),class=class,items=items,twin=seen[key] or nil}
            if seen[key] then ev.players[seen[key]].twin=true end
            seen[key]=#ev.players
        end
    end
    return ev
end
-- Import: the same raid (event id) is replaced; the new list is the one shown.
function SR:Import(raw)
    local ev,err=self:Parse(raw)
    if not ev then return nil,err end
    local st=self:Store()
    local replaced=st.events[ev.id]~=nil
    ev.imported=time and time() or 0
    st.events[ev.id]=ev; st.active=ev.id
    self:Prune()
    if settings().softRes~=true then settings().softRes=true end
    self:Rebuild(); self:Apply()
    -- In a group as loot master, leader or assistant: everyone with the addon gets it.
    if FT.SoftResRoll then FT.SoftResRoll:Share(true) end
    local over=0
    for _,p in ipairs(ev.players) do if #p.items>ev.limit then over=over+1 end end
    return ev,replaced,over
end
function SR:Delete(id)
    local st=self:Store(); st.events[id]=nil
    if st.active==id then st.active=nil end
    self:Rebuild(); self:Refresh()
end
function SR:Choose(id) self:Store().active=id; self:Rebuild(); self:Refresh() end
-- Item id -> players who reserved it, for the shown list.
function SR:Rebuild()
    self.byItem={}
    local ev=self:Active(); if not ev then return end
    for _,p in ipairs(ev.players) do
        for _,id in ipairs(p.items) do local l=self.byItem[id] or {}; l[#l+1]=p; self.byItem[id]=l end
    end
    for _,list in pairs(self.byItem) do table.sort(list,function(a,b) return lower(a.first)<lower(b.first) end) end
end
function SR:Holders(id)
    if not self:Enabled() or not id then return nil end
    if not self.byItem then self:Rebuild() end
    return self.byItem[id]
end
-- Who is in your group, by first name (no realm, any case).
function SR:Roster()
    if self.roster then return self.roster end
    local r={}
    local function add(unit)
        local ok,name=pcall(UnitName,unit)
        name=ok and text(name)
        if name then r[lower(name:gsub("%-.*",""))]=true end
    end
    add("player")
    if IsInRaid and IsInRaid() then for i=1,40 do add("raid"..i) end
    elseif IsInGroup and IsInGroup() then for i=1,4 do add("party"..i) end end
    self.roster=r
    return r
end
function SR:InGroup() return (IsInGroup and IsInGroup()) and true or false end
function SR:Here(p) return not self:InGroup() or self:Roster()[lower(p.first)]==true end
-- Text --------------------------------------------------------------------------
local function classHex(class)
    local c=class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if c and c.r then return ("%02x%02x%02x"):format(math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5)) end
    return "ffffff"
end
SR.ClassHex=classHex
-- A player's name in their class color; grey when not in your group.
function SR:Name(p,full)
    local name=p.first..((full and p.last~="") and (" "..p.last) or "")
    if not self:Here(p) then return "|cff8a8a8a"..name.."|r" end
    return "|cff"..classHex(p.class)..name.."|r"
end
function SR:NameList(list,full)
    local out={}
    for i,p in ipairs(list) do out[i]=self:Name(p,full) end
    return table.concat(out,", ")
end
-- "SR: A, B" or "SR ×2: A, B" (several reserved it), or nil.
function SR:Line(list)
    if not list or #list==0 then return nil end
    local count=#list>1 and (" |cffff9a3d×"..#list.."|r") or ""
    return "|cffffd100SR"..count..":|r "..self:NameList(list)
end
local NO_SR="|cff8fd18fNo SR|r"
-- What the loot window and chat say for an item (nil: nothing to say).
function SR:Describe(id,quality)
    if not self:Enabled() or not self:Active() then return nil end
    local list=self:Holders(id)
    if list then return self:Line(list) end
    if type(quality)=="number" and quality>=NO_SR_QUALITY then return NO_SR end
end
-- Plain text for raid chat (no colors): "[Item] SR: A, B" / "SR x2" / "No SR".
function SR:Announcement(link,id)
    local list=self:Holders(id)
    if not list then return link.." No SR - free roll" end
    local names={}
    for i,p in ipairs(list) do names[i]=p.first end
    return link.." SR"..(#list>1 and (" x"..#list) or "")..": "..table.concat(names,", ")
end
function SR:Announce(link,id)
    if type(link)~="string" or not id then return end
    local t=now()
    if self.lastAnnounce and self.lastAnnounce.id==id and t-self.lastAnnounce.t<3 then return end
    self.lastAnnounce={id=id,t=t}
    local msg=self:Announcement(link,id)
    local channel
    if IsInRaid and IsInRaid() then
        local lead=(UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        channel=(plain(lead) and lead) and "RAID_WARNING" or "RAID"
    elseif IsInGroup and IsInGroup() then channel="PARTY" end
    if not channel then print("|cffffd100ForeverTools:|r "..msg.." (not in a group, only you see this)"); return end
    local send=(C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if send then pcall(send,msg,channel) end
end
-- Item details (names load a moment after first use) -----------------------------
local function itemInfo(id)
    local name,link,quality,_,_,_,_,_,_,icon
    local get=(C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get then name,link,quality,_,_,_,_,_,_,icon=get(id) end
    if not icon then
        local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if instant then local _,_,_,_,i=instant(id); icon=i end
    end
    if not name and not SR.asked then SR.asked={} end
    if not name and not SR.asked[id] then
        SR.asked[id]=true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id) end
    end
    return name,link or ("item:"..id),quality,icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
SR.ItemInfo=itemInfo
local function itemID(link) local id=type(link)=="string" and link:match("item:(%d+)"); return id and tonumber(id) end
SR.ItemID=itemID
-- The loot window --------------------------------------------------------------
-- The game's loot window is a scrolling list of pooled rows in newer clients
-- (LootFrame.ScrollBox) and LootButton1-4 in older ones; both are read. Our
-- line and button live on the row and are redrawn on every change, so a row
-- reused for another item never shows the wrong names. If neither is found,
-- a small list sits beside the loot window instead.
local function slotOf(row)
    if row.GetSlotIndex then local ok,s=pcall(row.GetSlotIndex,row); if ok and type(s)=="number" then return s end end
    if row.GetElementData then local ok,d=pcall(row.GetElementData,row); if ok and type(d)=="table" and type(d.slotIndex)=="number" then return d.slotIndex end end
    if type(row.slotIndex)=="number" then return row.slotIndex end
    if type(row.slot)=="number" then return row.slot end
end
function SR:LootRows()
    local rows={}
    local box=LootFrame and LootFrame.ScrollBox
    if box and box.ForEachFrame then
        pcall(box.ForEachFrame,box,function(row) if row and row.IsShown and row:IsShown() then rows[#rows+1]=row end end)
        if #rows>0 then self.lootKind="list"; return rows end
    end
    for i=1,(LOOTFRAME_NUMBUTTONS or 4) do
        local b=_G["LootButton"..i]
        if b and b:IsShown() then rows[#rows+1]=b end
    end
    self.lootKind=#rows>0 and "buttons" or "none"
    return rows
end
local function announceButton(parent)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(18,18); b:SetFrameLevel((parent:GetFrameLevel() or 1)+5)
    b.tex=b:CreateTexture(nil,"ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexture("Interface\\Icons\\Ability_Warrior_BattleShout"); FT:RoundIcon(b.tex)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    b:SetScript("OnClick",function(owner) SR:Announce(owner.link,owner.itemID) end)
    b:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText("Announce soft reserves",1,.82,0)
        GameTooltip:AddLine("Say who reserved this item: raid warning if you lead or assist, else raid chat.",.96,.93,.86,true); GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return b
end
-- The dice: start a roll for the raid (roll window for everyone with the addon).
local function rollButton(parent)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(18,18); b:SetFrameLevel((parent:GetFrameLevel() or 1)+5)
    b.tex=b:CreateTexture(nil,"ARTWORK"); b.tex:SetAllPoints(); b.tex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
    b:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight","ADD")
    b:SetScript("OnClick",function(owner) if FT.SoftResRoll then FT.SoftResRoll:Start(owner.link,owner.itemID,owner.slot) end end)
    b:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText("Start a roll",1,.82,0)
        GameTooltip:AddLine("Raid warning with who reserved it, and a roll window for everyone with ForeverTools. Rolls are listed for you; then give the item to the winner.",.96,.93,.86,true); GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return b
end
function SR:PaintRow(row,slot)
    local line=row.ftSRLine
    local link=slot and GetLootSlotLink and GetLootSlotLink(slot)
    local id=plain(link) and itemID(link)
    local quality
    if id and GetLootSlotInfo then local ok,_,_,_,_,q=pcall(GetLootSlotInfo,slot); if ok and plain(q) then quality=q end end
    local say=id and self:Describe(id,quality)
    if not say then
        if line then line:Hide(); row.ftSRButton:Hide(); row.ftSRRoll:Hide() end
        return false
    end
    if not line then
        line=row:CreateFontString(nil,"OVERLAY"); row.ftSRLine=line
        line:SetFont(FT.bodyFont,10,"OUTLINE"); line:SetJustifyH("LEFT"); if line.SetWordWrap then line:SetWordWrap(false) end
        row.ftSRButton=announceButton(row)
        row.ftSRRoll=rollButton(row)
    end
    local name=row.Text or (row.GetName and row:GetName() and _G[row:GetName().."Text"])
    line:ClearAllPoints()
    if name and name.GetObjectType then line:SetPoint("TOPLEFT",name,"BOTTOMLEFT",0,-1) else line:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",44,2) end
    line:SetWidth(math.max(80,(row:GetWidth() or 160)-70))
    line:SetText(say); line:Show()
    local b=row.ftSRButton
    b.link,b.itemID=link,id
    b:ClearAllPoints(); b:SetPoint("RIGHT",row,"RIGHT",-4,0); b:Show()
    local d=row.ftSRRoll
    d.link,d.itemID,d.slot=link,id,slot
    d:ClearAllPoints(); d:SetPoint("RIGHT",b,"LEFT",-4,0); d:Show()
    return true
end
function SR:PaintLoot()
    if not LootFrame or not LootFrame:IsShown() then if self.lootPanel then self.lootPanel:Hide() end; return end
    local rows=self:LootRows()
    for _,row in ipairs(rows) do self:PaintRow(row,slotOf(row)) end
    -- No rows we can read: a small list beside the loot window.
    if #rows==0 then self:PaintPanel() elseif self.lootPanel then self.lootPanel:Hide() end
end
function SR:PaintPanel()
    local items={}
    if self:Enabled() and self:Active() then
        for slot=1,(GetNumLootItems and GetNumLootItems() or 0) do
            local link=GetLootSlotLink and GetLootSlotLink(slot)
            local id=plain(link) and itemID(link)
            local quality; if id and GetLootSlotInfo then local ok,_,_,_,_,q=pcall(GetLootSlotInfo,slot); if ok and plain(q) then quality=q end end
            local say=id and self:Describe(id,quality)
            if say then items[#items+1]={link=link,id=id,say=say,slot=slot} end
        end
    end
    local p=self.lootPanel
    if #items==0 then if p then p:Hide() end; return end
    if not p then
        p=CreateFrame("Frame",nil,LootFrame); self.lootPanel=p; FT:Panel(p); p.rows={}
        p:SetPoint("TOPLEFT",LootFrame,"TOPRIGHT",4,0)
    end
    for i,it in ipairs(items) do
        local r=p.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,p); r:SetSize(260,34); p.rows[i]=r
            r:SetPoint("TOPLEFT",8,-8-(i-1)*36)
            r.item=r:CreateFontString(nil,"OVERLAY"); r.item:SetFont(FT.bodyFont,11,""); r.item:SetPoint("TOPLEFT",0,-2); r.item:SetWidth(230); r.item:SetJustifyH("LEFT")
            r.Text=r.item
            r.say=r:CreateFontString(nil,"OVERLAY"); r.say:SetFont(FT.bodyFont,10,"OUTLINE"); r.say:SetPoint("TOPLEFT",r.item,"BOTTOMLEFT",0,-2); r.say:SetWidth(230); r.say:SetJustifyH("LEFT")
            r.button=announceButton(r); r.button:SetPoint("RIGHT",0,0)
            r.roll=rollButton(r); r.roll:SetPoint("RIGHT",r.button,"LEFT",-4,0)
        end
        r.item:SetText(it.link); r.say:SetText(it.say); r.button.link,r.button.itemID=it.link,it.id; r.roll.link,r.roll.itemID,r.roll.slot=it.link,it.id,it.slot; r:Show()
    end
    for i=#items+1,#p.rows do p.rows[i]:Hide() end
    p:SetSize(276,16+#items*36); p:Show()
end
function SR:HookLoot()
    if self.lootHooked or not LootFrame then return end
    self.lootHooked=true
    LootFrame:HookScript("OnShow",function() SR:QueueLoot() end)
    LootFrame:HookScript("OnHide",function() if SR.lootPanel then SR.lootPanel:Hide() end end)
    local box=LootFrame.ScrollBox
    if box and box.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
        for _,event in ipairs({"OnDataRangeChanged","OnScroll"}) do
            local name=ScrollBoxListMixin.Event[event]
            if name then pcall(box.RegisterCallback,box,name,function() SR:QueueLoot() end,SR) end
        end
    end
    if type(LootFrame.Update)=="function" then hooksecurefunc(LootFrame,"Update",function() SR:QueueLoot() end) end
    if type(_G.LootFrame_Update)=="function" then hooksecurefunc("LootFrame_Update",function() SR:QueueLoot() end) end
end
local function paintLoot() SR:PaintLoot() end
function SR:QueueLoot() FT:Coalesce("softResLoot",paintLoot,0) end
-- Chat: a line under raid and party messages that link reserved items ----------
function SR:ChatLink(msg,author)
    if not self:Enabled() or not self:Active() or not plain(msg) or type(msg)~="string" then return end
    if not msg:find("|Hitem:",1,true) then return end
    -- Our own announcement already says it.
    local me=UnitName and UnitName("player")
    if plain(author) and type(author)=="string" and me and lower(author:gsub("%-.*",""))==lower(me) and msg:find(" SR",1,true) then return end
    local lines,t={},now()
    self.chatSeen=self.chatSeen or {}
    -- Any link style: the item's own link is shown again (with its color).
    for itemString,label in msg:gmatch("|H(item:[^|]+)|h(.-)|h") do
        local id=itemID(itemString)
        if id and not (self.chatSeen[id] and t-self.chatSeen[id]<8) then
            local _,link,quality=itemInfo(id)
            if not link:find("|H",1,true) then link="|cffffffff|H"..itemString.."|h"..label.."|h|r" end
            local say=self:Describe(id,quality)
            if say then self.chatSeen[id]=t; lines[#lines+1]="   "..link.." "..say end
        end
        if #lines>=3 then break end
    end
    if #lines==0 then return end
    -- After the message itself is shown.
    C_Timer.After(0,function()
        local frame=DEFAULT_CHAT_FRAME or ChatFrame1
        for _,line in ipairs(lines) do if frame then frame:AddMessage(line,1,1,1) end end
    end)
end
-- Tooltips ---------------------------------------------------------------------
function SR:TooltipLine(tip,data)
    if not self:Enabled() or (tip~=GameTooltip and tip~=ItemRefTooltip) then return end
    local id=type(data)=="table" and plain(data.id) and type(data.id)=="number" and data.id
    if not id and tip.GetItem then local ok,_,link=pcall(tip.GetItem,tip); if ok and plain(link) then id=itemID(link) end end
    local list=id and self:Holders(id)
    if not list then return end
    tip:AddLine(self:Line(list),1,1,1,true)
    tip:Show()
end
-- On / off ---------------------------------------------------------------------
local events=CreateFrame("Frame")
local itemWait=CreateFrame("Frame")
function SR:Apply()
    if not FT.dbReady then return end
    local on=self:Enabled() and self:Active()~=nil
    for _,event in ipairs({"LOOT_OPENED","LOOT_SLOT_CLEARED","LOOT_SLOT_CHANGED","LOOT_CLOSED","GROUP_ROSTER_UPDATE",unpack(CHAT_EVENTS)}) do
        if on then pcall(events.RegisterEvent,events,event) else pcall(events.UnregisterEvent,events,event) end
    end
    if on then self:HookLoot() end
    self.roster=nil
    self:QueueLoot()
    self:Refresh()
end
events:SetScript("OnEvent",function(_,event,a,b)
    if event=="GROUP_ROSTER_UPDATE" then SR.roster=nil; if SR.frame and SR.frame:IsShown() then FT:Coalesce("softResList",function() SR:Refresh() end,.5) end; return end
    if event:find("^CHAT_MSG_") then SR:ChatLink(a,b); return end
    if event=="LOOT_CLOSED" then if SR.lootPanel then SR.lootPanel:Hide() end; return end
    SR:QueueLoot()
end)
-- Item names that arrive later redraw the open list.
itemWait:SetScript("OnEvent",function(_,_,id)
    if SR.frame and SR.frame:IsShown() and SR.asked and SR.asked[id] then FT:Coalesce("softResNames",function() SR:Refresh() end,.3) end
end)
pcall(itemWait.RegisterEvent,itemWait,"GET_ITEM_INFO_RECEIVED")
local boot=CreateFrame("Frame"); boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent",function()
    if not FT.dbReady then return end
    SR:Prune(); SR:Rebuild(); SR:Apply()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item~=nil then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip,data) pcall(SR.TooltipLine,SR,tip,data) end)
    else
        for _,tip in ipairs({GameTooltip or false,ItemRefTooltip or false}) do
            if tip and tip.HookScript then pcall(tip.HookScript,tip,"OnTooltipSetItem",function(owner) pcall(SR.TooltipLine,SR,owner) end) end
        end
    end
end)
-- The window (/ft sr) --------------------------------------------------------------
local W,ROW,MAXROWS,NAMEW=600,24,40,180
local function when(ev)
    if not ev.start or ev.start<=0 or not date then return "" end
    return date("%a %d %b, %H:%M",ev.start)
end
function SR:Counts(ev)
    local reserved,missing=0,{}
    for _,p in ipairs(ev.players) do if #p.items>0 then reserved=reserved+1 else missing[#missing+1]=p end end
    return reserved,missing
end
-- Group members who are not on the list.
function SR:NotSignedUp(ev)
    if not self:InGroup() then return {} end
    local on={}
    for _,p in ipairs(ev.players) do on[lower(p.first)]=true end
    local out={}
    for name in pairs(self:Roster()) do if not on[name] then out[#out+1]=name:sub(1,1):upper()..name:sub(2) end end
    table.sort(out)
    return out
end
local function itemCell(parent)
    local c=CreateFrame("Button",nil,parent); c:SetSize(150,ROW-2)
    c.icon=c:CreateTexture(nil,"ARTWORK"); c.icon:SetSize(18,18); c.icon:SetPoint("LEFT",0,0); FT:RoundIcon(c.icon)
    c.name=c:CreateFontString(nil,"OVERLAY"); c.name:SetFont(FT.bodyFont,12,""); c.name:SetPoint("LEFT",c.icon,"RIGHT",5,0); c.name:SetPoint("RIGHT",c,"RIGHT",-2,0); c.name:SetJustifyH("LEFT")
    if c.name.SetWordWrap then c.name:SetWordWrap(false) end
    c:RegisterForClicks("LeftButtonUp"); c.ftTipTitle="Reserved item"
    c:SetScript("OnEnter",function(owner)
        if not owner.itemID then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(owner.itemID) else GameTooltip:SetHyperlink("item:"..owner.itemID) end
        GameTooltip:AddLine("Click: announce who reserved it. Shift-click: link it in chat.",.72,.66,.55,true)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave",function() GameTooltip:Hide() end)
    c:SetScript("OnClick",function(owner)
        if not owner.itemID then return end
        local _,link=itemInfo(owner.itemID)
        if IsShiftKeyDown and IsShiftKeyDown() and HandleModifiedItemClick then HandleModifiedItemClick(link); return end
        SR:Announce(link,owner.itemID)
    end)
    return c
end
function SR:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsSoftRes","Soft reserves",W,636); self.frame=frame
        -- Works in a fight: a boss can die mid-pull and loot comes during trash.
        frame.ftCombatOK=true
        FT:PageInfo(frame,"Soft reserves","Who reserved which items in your raid. A custom function for our guild website: make the list there, copy the ForeverTools string and paste it here. Lists from softres.it and other soft reserve sites do not work here.\n\nThe names then show on the loot window, under item links in raid chat and on item tooltips. Click an item here, or the shout button on the loot window, to announce who reserved it.\n\nLoot master: import the list and it is shared with everyone in the raid who has ForeverTools. Click the dice on the loot window to start a roll: everyone gets a roll window, the rolls are listed for you, then give the item to the winner.")
        frame.toggle=FT:AccentButton(frame,"",268,32,"INV_Misc_Note_06"); frame.toggle:SetPoint("TOPLEFT",24,-62)
        frame.toggle:SetScript("OnClick",function() local s=settings(); s.softRes=not s.softRes; SR:Apply() end)
        FT:Tooltip(frame.toggle,"Soft reserves (custom)","Custom function for the guild website's lists (not softres.it). Shows who reserved items on loot, in raid chat and on tooltips. Importing a list turns it on.")
        frame.raidChoice=FT:QuietButton(frame,"",268,32,"INV_Misc_Note_06"); frame.raidChoice:SetPoint("TOPLEFT",308,-62); frame.raidChoice.ftCombatOK=true
        FT:Tooltip(frame.raidChoice,"Raid","Which imported raid is shown. The newest import is chosen by itself.")
        FT:MakeChoice(frame.raidChoice,function()
            local list={}
            for _,ev in ipairs(SR:EventList()) do list[#list+1]={ev.id,ev.title.." – "..when(ev),RAIDS[ev.raid]} end
            return list
        end,function() local ev=SR:Active(); return ev and ev.id end,function(id) SR:Choose(id) end)
        frame.rolls=FT:QuietButton(frame,"",404,30,"INV_Misc_Dice_01"); frame.rolls:SetPoint("TOPLEFT",24,-100)
        frame.demo=FT:QuietButton(frame,"Try it (demo)",140,30,"INV_Misc_Dice_02"); frame.demo:SetPoint("TOPLEFT",436,-100)
        frame.demo:SetScript("OnClick",function() if FT.SoftResDemo then FT.SoftResDemo:Ask() end end)
        FT:Tooltip(frame.demo,"Try it (demo)","Practise a raid's loot rolls on your own, as the loot master or as a raider. Fake raiders roll; nothing is sent to anyone and no /roll is made.")
        frame.rolls:SetScript("OnClick",function() local s=settings(); s.softResRolls=s.softResRolls==false; SR:Apply() end)
        FT:Tooltip(frame.rolls,"Roll windows from the loot master","When the loot master, leader or an assistant starts a roll with ForeverTools, a window shows the item, who reserved it and buttons to roll. Their list is shared with you too, so you see reserves without importing. On at first.")
        -- List view.
        local list=CreateFrame("Frame",nil,frame); list:SetPoint("TOPLEFT",0,-138); list:SetPoint("BOTTOMRIGHT",0,0); frame.list=list
        list.head=FT:Label(list,"",15,true); list.head:SetPoint("TOPLEFT",24,-4); list.head:SetWidth(W-48)
        list.count=FT:Label(list,"",13); list.count:SetPoint("TOPLEFT",24,-26); list.count:SetWidth(W-48); list.count:SetTextColor(.85,.80,.70)
        list.missing=FT:Label(list,"",13); list.missing:SetPoint("TOPLEFT",24,-46); list.missing:SetWidth(W-48); list.missing:SetTextColor(1,.32,.28)
        if list.missing.SetWordWrap then list.missing:SetWordWrap(true) end
        local scroll=CreateFrame("ScrollFrame",nil,list,"UIPanelScrollFrameTemplate"); list.scroll=scroll
        scroll:SetPoint("TOPLEFT",24,-84); scroll:SetPoint("BOTTOMRIGHT",-40,96)
        local child=CreateFrame("Frame",nil,scroll); child:SetSize(W-64,ROW); scroll:SetScrollChild(child); list.child=child
        if FT.AutoHideScrollBar then FT:AutoHideScrollBar(scroll) end
        list.rows={}
        list.extra=FT:Label(list,"",12); list.extra:SetPoint("BOTTOMLEFT",24,70); list.extra:SetWidth(W-48); list.extra:SetTextColor(.66,.59,.48)
        list.import=FT:QuietButton(list,"Import new list",180,30,"INV_Scroll_03"); list.import:SetPoint("BOTTOMLEFT",24,22)
        list.import:SetScript("OnClick",function() SR.view="import"; SR:Refresh() end)
        FT:Tooltip(list.import,"Import new list","Paste a new string. The same raid is replaced, other raids are kept.")
        list.delete=FT:QuietButton(list,"Delete this raid",180,30,"delete"); list.delete:SetPoint("LEFT",list.import,"RIGHT",8,0)
        list.delete:SetScript("OnClick",function() local ev=SR:Active(); if ev then FT:Confirm('Delete the soft reserves for "'..ev.title..'"?',function() SR:Delete(ev.id) end,true) end end)
        FT:Tooltip(list.delete,"Delete this raid","Remove this raid's list from your account.")
        -- Import view.
        local imp=CreateFrame("Frame",nil,frame); imp:SetPoint("TOPLEFT",0,-138); imp:SetPoint("BOTTOMRIGHT",0,0); frame.imp=imp
        imp.intro=FT:Label(imp,"Paste the ForeverTools string from the guild website (it starts with FTSR1||), then click Import. Not for softres.it lists.",13)
        imp.intro:SetPoint("TOPLEFT",24,-4); imp.intro:SetWidth(W-48); imp.intro:SetTextColor(.85,.80,.70)
        local s2=CreateFrame("ScrollFrame",nil,imp,"UIPanelScrollFrameTemplate"); s2:SetPoint("TOPLEFT",24,-44); s2:SetSize(W-76,260); FT:Panel(s2)
        local box=CreateFrame("EditBox",nil,s2); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(W-84,260); box:SetAutoFocus(false)
        box:SetTextInsets(6,6,6,6); s2:SetScrollChild(box); imp.box=box
        if box.SetMaxLetters then box:SetMaxLetters(0) end
        box:SetScript("OnEscapePressed",function() box:ClearFocus() end)
        local hint=FT:Label(box,"Paste here (Ctrl+V)",13); hint:SetPoint("TOPLEFT",box,10,-10); hint:SetTextColor(.66,.59,.48); imp.hint=hint
        box:SetScript("OnTextChanged",function(_,user)
            local n=#box:GetText(); box:SetHeight(math.max(260,math.ceil(n/70)*16)); hint:SetShown(n==0)
            if user then imp.status:SetText(""); end
        end)
        FT:TextCaret(box,6,{light=true})
        imp.go=FT:AccentButton(imp,"Import",180,32,"INV_Scroll_03"); imp.go:SetPoint("TOPLEFT",24,-318)
        imp.go:SetScript("OnClick",function()
            local ev,replaced,over=SR:Import(box:GetText())
            if not ev then imp.status:SetText(replaced); imp.status:SetTextColor(1,.45,.38); return end
            box:SetText(""); box:ClearFocus(); SR.view="list"
            local note=(replaced and "Updated: " or "Imported: ")..ev.title..", "..#ev.players.." players."
            if over>0 then note=note.." "..over.." reserved more than the limit of "..ev.limit.."." end
            FT:Toast(note,5); SR:Refresh()
        end)
        FT:Tooltip(imp.go,"Import","Read the string and show the list. A list for the same raid is replaced.")
        imp.cancel=FT:QuietButton(imp,"Cancel",120,32,"delete"); imp.cancel:SetPoint("LEFT",imp.go,"RIGHT",8,0)
        imp.cancel:SetScript("OnClick",function() box:SetText(""); box:ClearFocus(); SR.view="list"; SR:Refresh() end)
        FT:Tooltip(imp.cancel,"Cancel","Back to the list without importing.")
        imp.status=FT:Label(imp,"",13); imp.status:SetPoint("TOPLEFT",24,-362); imp.status:SetWidth(W-48)
        if imp.status.SetWordWrap then imp.status:SetWordWrap(true) end
    end
    if not self:Active() then self.view="import" end
    self:Refresh(); self.frame:Show(); FT:PlaceBeside(self.frame)
end
function SR:RenderRow(i,p,ev)
    local list=self.frame.list
    local row=list.rows[i]
    if not row then
        row=CreateFrame("Frame",nil,list.child); row:SetSize(W-64,ROW); row:SetPoint("TOPLEFT",0,-(i-1)*ROW); list.rows[i]=row
        row.name=row:CreateFontString(nil,"OVERLAY"); row.name:SetFont(FT.bodyFont,12,""); row.name:SetPoint("LEFT",4,0); row.name:SetWidth(NAMEW-10); row.name:SetJustifyH("LEFT")
        if row.name.SetWordWrap then row.name:SetWordWrap(false) end
        row.none=row:CreateFontString(nil,"OVERLAY"); row.none:SetFont(FT.bodyFont,12,""); row.none:SetPoint("LEFT",NAMEW,0); row.none:SetTextColor(1,.32,.28)
        row.cells={}
        if i%2==0 then local bg=row:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1,.9,.6,.04) end
    end
    local name=self:Name(p,true)
    if p.twin then name=name.." |cffff9a3d(same first name)|r" end
    row.name:SetText(name)
    local n=math.max(1,#p.items)
    local width=math.floor((W-64-NAMEW)/math.max(n,ev.limit,1))
    for j=1,math.max(#p.items,#row.cells) do
        local c=row.cells[j]
        if j<=#p.items then
            if not c then c=itemCell(row); row.cells[j]=c end
            local id=p.items[j]
            local itemName,_,quality,icon=itemInfo(id)
            c.itemID=id; c.icon:SetTexture(icon)
            local hex=quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] and ITEM_QUALITY_COLORS[quality].hex or "|cffa335ee"
            local others=self:Holders(id)
            local count=(others and #others>1) and (" |cffff9a3d×"..#others.."|r") or ""
            c.name:SetText(hex..(itemName or ("Item "..id)).."|r"..count)
            c:SetWidth(width-6); c:ClearAllPoints(); c:SetPoint("LEFT",row,"LEFT",NAMEW+(j-1)*width,0); c:Show()
        elseif c then c:Hide(); c.itemID=nil end
    end
    row.none:SetText(#p.items==0 and "Nothing reserved" or "")
    row:Show()
end
function SR:Refresh()
    local frame=self.frame; if not frame then return end
    local on=self:Enabled()
    frame.toggle.label:SetText("Soft reserves: "..(on and "On" or "Off")); FT:SetSelected(frame.toggle,on)
    local ev=self:Active()
    frame.raidChoice:SetShown(ev~=nil)
    if ev then frame.raidChoice.label:SetText("Raid: "..ev.title) end
    local rolls=settings().softResRolls~=false
    frame.rolls.label:SetText("Roll windows from the loot master: "..(rolls and "On" or "Off")); FT:SetSelected(frame.rolls,rolls)
    local importing=self.view=="import" or not ev
    frame.imp:SetShown(importing); frame.list:SetShown(not importing)
    frame.imp.cancel:SetShown(ev~=nil)
    if importing then return end
    local list=frame.list
    list.head:SetText(ev.title.."  |cffa8967a"..when(ev).." · "..ev.limit.." per player"..(ev.shared and (" · from "..tostring(ev.from)) or "").."|r")
    local reserved,missing=self:Counts(ev)
    list.count:SetText(reserved.."/"..#ev.players.." have reserved")
    if #missing>0 then
        local names={}; for i,p in ipairs(missing) do names[i]=p.first end
        list.missing:SetText("Not reserved yet: "..table.concat(names,", "))
    else list.missing:SetText("|cff8fd18fEveryone has reserved.|r") end
    -- Not reserved first, then by name.
    local players={}
    for _,p in ipairs(ev.players) do players[#players+1]=p end
    table.sort(players,function(a,b) if (#a.items==0)~=(#b.items==0) then return #a.items==0 end; return lower(a.first)<lower(b.first) end)
    for i=1,math.min(#players,MAXROWS) do self:RenderRow(i,players[i],ev) end
    for i=math.min(#players,MAXROWS)+1,#list.rows do list.rows[i]:Hide() end
    list.child:SetHeight(math.max(ROW,math.min(#players,MAXROWS)*ROW))
    local absent=self:NotSignedUp(ev)
    local lines={}
    if #absent>0 then lines[#lines+1]="In your group without a sign-up: "..table.concat(absent,", ") end
    -- Who got what in this raid (rolls given out with ForeverTools).
    if type(ev.awards)=="table" and #ev.awards>0 then
        local given={}
        for i=math.max(1,#ev.awards-5),#ev.awards do
            local a=ev.awards[i]; local _,link=itemInfo(a.item)
            given[#given+1]=(link:find("|H",1,true) and link or ("item "..a.item)).." → "..a.to..(a.roll and (" ("..a.roll..(a.sr and " SR" or "")..")") or "")
        end
        lines[#lines+1]="Given out ("..#ev.awards.."): "..table.concat(given,", ")
    end
    list.extra:SetText(table.concat(lines,"\n"))
end
-- /ft srdebug: what the loot window looks like to us, for bug reports.
function SR:Debug()
    local ev=self:Active()
    print("Soft reserves: "..(self:Enabled() and "on" or "off")..", raids kept: "..#self:EventList()..(ev and (", shown: "..ev.title.." ("..ev.raid..", "..#ev.players.." players)") or ""))
    print("Loot window: "..(LootFrame and "found" or "missing")..", ScrollBox: "..tostring(LootFrame and LootFrame.ScrollBox~=nil)..", LootButton1: "..tostring(_G.LootButton1~=nil))
    if LootFrame and LootFrame:IsShown() then
        local rows=self:LootRows()
        print("Open now: "..#rows.." rows read ("..tostring(self.lootKind)..")")
        for i,row in ipairs(rows) do local slot=slotOf(row); print("  row "..i..": slot "..tostring(slot)..", link "..tostring(slot and GetLootSlotLink and GetLootSlotLink(slot))) end
    else print("Open a loot window and run /ft srdebug again to see its rows.") end
    print("Group: "..(self:InGroup() and "yes" or "no")..", tooltip hook: "..tostring(TooltipDataProcessor~=nil))
end
SR.combatOK=true
FT:RegisterModule("SoftRes",SR)
FT.SoftRes=SR
