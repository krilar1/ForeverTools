local _,FT=...
-- Bags (all off by default). Built on the game's own bag window, which is
-- left as it is:
--   * Gold: hover the gold in your bag to see the gold of every character
--     on the same ruleset, and a total.
--   * Bank and other characters: two small buttons beside the bag's sort
--     button. Bank opens a view-only copy of your bank as it was at your
--     last visit. The character button switches both the bag view and the
--     bank view to another character on the same ruleset.
--   * Item counts in tooltips live in BagCounts.lua (Appearance > Item counts).
-- What each character carries is saved for the whole account (never in
-- profiles or exports), on login, when bags change (once per burst), at the
-- bank and at the guild bank. Nothing is read in combat; it catches up after.
local Bags={}
local SLOT,GAP=37,5
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function now() return time and time() or 0 end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local function number(v) if plain(v) and type(v)=="number" then return v end end
-- The icon of Forever's own bank tabs; a plain bag if this game version lacks it.
Bags.BANK_ICON="Interface\\Icons\\INV_SideTab_Bank_c60"
do
    local id=GetFileIDFromPath and GetFileIDFromPath(Bags.BANK_ICON)
    if GetFileIDFromPath and not (type(id)=="number" and id>0) then Bags.BANK_ICON="Interface\\Icons\\INV_Misc_Bag_10" end
end
-- Settings (profile key "bags"); the item-count keys are used by BagCounts.lua.
function Bags:Settings()
    if type(FT.db.bags)~="table" then FT.db.bags={} end
    local s=FT.db.bags
    for _,key in ipairs({"gold","view","counts","locked","buttons"}) do if type(s[key])~="boolean" then s[key]=false end end
    for key,default in pairs({countSplit=true,countSelf=true,countGuild=true,countShift=false,countSpacer=true,countFullNames=false}) do
        if type(s[key])~="boolean" then s[key]=default end
    end
    if s.countStyle~="each" and s.countStyle~="total" and s.countStyle~="both" then s.countStyle="each" end
    if s.countPlace~="inside" and s.countPlace~="above" and s.countPlace~="below" then s.countPlace="inside" end
    -- Bag order (BagOrder.lua): "game" leaves the layout alone; insert and
    -- cleanup stay nil (the game's own setting untouched) until picked.
    if s.order~="topleft" and s.order~="topright" and s.order~="bottomleft" and s.order~="bottomright" then s.order="game" end
    if s.insert~="backpack" and s.insert~="lastbag" then s.insert=nil end
    if s.cleanup~="backpack" and s.cleanup~="lastbag" then s.cleanup=nil end
    for _,pair in ipairs({{"bagX","bagY"},{"bankX","bankY"}}) do
        if type(s[pair[1]])~="number" or type(s[pair[2]])~="number" then s[pair[1]],s[pair[2]]=nil,nil end
    end
    return s
end
function Bags:AnyOn() local s=self:Settings(); return s.gold or s.view or s.counts end
-- Account data: what every character carries.
function Bags:Store()
    if type(FT.db.bagStore)~="table" then FT.db.bagStore={} end
    local st=FT.db.bagStore
    if type(st.chars)~="table" then st.chars={} end
    if type(st.guilds)~="table" then st.guilds={} end
    return st
end
-- Characters are remembered once any bag feature has been turned on (on any
-- character), until the player switches remembering off on the Characters page.
function Bags:Recording()
    local st=FT.db and FT.db.bagStore
    if type(st)=="table" and st.off==true then return false end
    if type(st)=="table" and st.started==true then return true end
    return self:AnyOn()
end
function Bags:Me()
    local guid=UnitGUID and UnitGUID("player")
    return text(guid)
end
-- WoW: Forever has rulesets (PvP, PvE, roleplay, hardcore) rather than
-- realms; characters are grouped by the realm name the game reports.
-- The game spells the realm two ways ("Classic Beta PvE" right after login,
-- "ClassicBetaPvE" later), so names are compared without spaces or dashes.
local function sameRealm(name) return type(name)=="string" and (name:gsub("[%s%-]","")) or "?" end
Bags.SameRealm=sameRealm
function Bags:Ruleset()
    for _,fn in ipairs({GetRealmName or false,GetNormalizedRealmName or false}) do
        if fn then local ok,v=pcall(fn); if ok and text(v) then return sameRealm(v),v end end
    end
    return "?","?"
end
-- The player's full name (first and last), or nil when the game shows no
-- more than the first name. Only accepted when it starts with that name.
function Bags:FullName(first)
    if type(first)~="string" or first=="" or first=="?" then return end
    local function check(v)
        v=text(v)
        if v and v~=first and v:sub(1,#first+1)==first.." " then return v end
    end
    local full=GetUnitName and check(GetUnitName("player",false))
    if not full then
        local label=_G.PlayerName or (PlayerFrame and PlayerFrame.name)
        if label and label.GetText then full=check(label:GetText()) end
    end
    return full
end
function Bags:Record(create)
    local guid=self:Me(); if not guid then return end
    local st=self:Store(); local c=st.chars[guid]
    if not c then if not create then return end; c={}; st.chars[guid]=c end
    local name=UnitName and UnitName("player"); c.name=text(name) or c.name or "?"
    -- Forever characters have a last name too. UnitName gives the first
    -- name only; the full one is what the game shows on its own frames.
    local full=self:FullName(c.name)
    if full then c.fullName=full end
    local _,class=UnitClass("player"); c.class=text(class) or c.class
    local faction=UnitFactionGroup and UnitFactionGroup("player"); c.faction=text(faction) or c.faction
    local realm,shown=self:Ruleset()
    c.realm=realm; if shown~="?" then c.realmName=shown end
    local level=UnitLevel and UnitLevel("player"); c.level=number(level) or c.level
    if GetGuildInfo then local guild=GetGuildInfo("player"); c.guild=text(guild) end
    return c,guid
end
-- Reading containers ------------------------------------------------------
local function readContainer(bag)
    local api=C_Container; if not api or not api.GetContainerNumSlots or not api.GetContainerItemInfo then return end
    local ok,size=pcall(api.GetContainerNumSlots,bag)
    if not ok or not number(size) or size<=0 then return end
    local items={size=size}
    for slot=1,size do
        local found,info=pcall(api.GetContainerItemInfo,bag,slot)
        if found and plain(info) and type(info)=="table" then
            local link=text(info.hyperlink)
            if link then items[slot]={link,number(info.stackCount) or 1,number(info.iconFileID),number(info.quality)} end
        end
    end
    return items
end
Bags.ReadContainer=readContainer
function Bags:BagIDs()
    local ids={0}
    local inv=Constants and Constants.InventoryConstants
    local count=(inv and number(inv.NumBagSlots)) or NUM_BAG_SLOTS or 4
    for i=1,count do ids[#ids+1]=i end
    local reagent=inv and number(inv.NumReagentBagSlots)
    if reagent then for i=1,reagent do ids[#ids+1]=count+i end end
    if C_ActionBar and C_ActionBar.ShouldShowKeyring then
        local ok,show=pcall(C_ActionBar.ShouldShowKeyring)
        if ok and plain(show) and show==true then ids[#ids+1]=KEYRING_CONTAINER or -2 end
    end
    return ids
end
-- Bank containers. Which numbers Forever uses for the bank is not known for
-- sure, so the known ways are tried in order and the first that finds
-- anything is used: the bank's tabs as the game lists them, the tab numbers
-- themselves, then the older main bank plus bank bags. (Forever also answers
-- for the old main bank, always empty, so it is only a last resort.)
function Bags:BankContainers()
    if not C_Container or not C_Container.GetContainerNumSlots then return {},"none" end
    local function size(id)
        local ok,n=pcall(C_Container.GetContainerNumSlots,id)
        return ok and number(n) or 0
    end
    local sources={}
    -- 1. The tabs the game lists.
    sources[1]=function()
        local list={}
        if C_Bank and C_Bank.FetchPurchasedBankTabData and Enum and Enum.BankType and Enum.BankType.Character~=nil then
            local ok,tabs=pcall(C_Bank.FetchPurchasedBankTabData,Enum.BankType.Character)
            if ok and plain(tabs) and type(tabs)=="table" then
                for _,tab in ipairs(tabs) do
                    local id=type(tab)=="table" and number(tab.ID)
                    if id and size(id)>0 then list[#list+1]={id=id,name=text(tab.name),icon=number(tab.icon) or text(tab.icon)} end
                end
            end
        end
        return list,"tabs"
    end
    -- 2. The tab numbers themselves.
    sources[2]=function()
        local list={}; local bagIndex=Enum and Enum.BagIndex
        for i=1,8 do local id=bagIndex and bagIndex["CharacterBankTab_"..i]; if id~=nil and size(id)>0 then list[#list+1]={id=id,name="Tab "..i} end end
        return list,"tabIDs"
    end
    -- 3. The older bank: main bank and bank bags.
    sources[3]=function()
        local list={}; local seen={}
        local function add(id,name) if type(id)=="number" and not seen[id] and size(id)>0 then seen[id]=true; list[#list+1]={id=id,name=name} end end
        local bagIndex=Enum and Enum.BagIndex
        add(bagIndex and bagIndex.Bank or BANK_CONTAINER or -1,"Bank")
        local first=(NUM_BAG_SLOTS or 4)
        for i=1,(NUM_BANKBAGSLOTS or 7) do add((bagIndex and bagIndex["BankBag_"..i]) or (first+i),"Bank bag "..i) end
        return list,"bankBags"
    end
    for _,source in ipairs(sources) do
        local list,how=source()
        if #list>0 then return list,how.." "..#list end
    end
    return {},"nothing found"
end
-- How many tabs the bank can have (bought or not), for the bag-slot row.
function Bags:BankTabMax()
    if C_Bank and C_Bank.FetchMaxNumBankTabs and Enum and Enum.BankType and Enum.BankType.Character~=nil then
        local ok,n=pcall(C_Bank.FetchMaxNumBankTabs,Enum.BankType.Character)
        if ok and number(n) and n>0 then return n end
    end
end
function Bags:Busy() return InCombatLockdown and InCombatLockdown() end
function Bags:ScanBags()
    if not FT.dbReady or not self:Recording() then return end
    if self:Busy() then self.pending=true; return end
    local c,guid=self:Record(true); if not c then return end
    local bags={}
    for _,id in ipairs(self:BagIDs()) do
        local items=readContainer(id)
        if items then items.id=id; bags[#bags+1]=items end
    end
    if #bags>0 then c.bags=bags end
    local worn={}
    if GetInventoryItemLink then
        for slot=1,19 do local link=GetInventoryItemLink("player",slot); if text(link) then worn[slot]=link end end
    end
    c.worn=worn
    local money=GetMoney and GetMoney(); c.money=number(money) or c.money
    c.seen=now()
    if self.bankOpen then self:ScanBank(true) end
    self:Changed(guid)
end
function Bags:ScanMoney()
    if not FT.dbReady or not self:Recording() then return end
    local c,guid=self:Record(true); if not c then return end
    local money=GetMoney and GetMoney(); c.money=number(money) or c.money
    self:Changed(guid,true)
end
function Bags:ScanBank(quiet)
    if not FT.dbReady or not self.bankOpen or not self:Recording() then return end
    if self:Busy() then self.pending=true; return end
    local c,guid=self:Record(true); if not c then return end
    local tabs,how=self:BankContainers()
    local out,items=0,{}
    for _,tab in ipairs(tabs) do
        local read=readContainer(tab.id)
        if read then read.id=tab.id; read.name=tab.name; read.icon=tab.icon; items[#items+1]=read; out=out+1 end
    end
    -- What was found, for the bug report.
    self.bankHow=how.." ("..out.." read)"
    -- An empty answer (the bank is not really open) never wipes what we had.
    if out>0 then c.bank=items; c.bankSeen=now(); c.bankMax=self:BankTabMax() or c.bankMax end
    if not quiet then self:Changed(guid) end
end
-- Guild bank: only the tabs the game has sent are read; an empty tab that is
-- not the one on screen keeps what was seen before.
function Bags:GuildKey()
    if not GetGuildInfo then return end
    local name=text((GetGuildInfo("player")))
    if name then return self:Ruleset().."|"..name,name end
end
function Bags:QueryGuild()
    if not GetNumGuildBankTabs or not QueryGuildBankTab then return end
    local ok,count=pcall(GetNumGuildBankTabs)
    if not ok or not number(count) then return end
    for tab=1,count do
        C_Timer.After(tab*.3,function() if self.guildOpen then pcall(QueryGuildBankTab,tab) end end)
    end
end
function Bags:ScanGuild()
    if not FT.dbReady or not self.guildOpen or not self:Recording() then return end
    if self:Busy() then self.pending=true; return end
    local key,name=self:GuildKey(); if not key or not GetNumGuildBankTabs or not GetGuildBankItemLink then return end
    local ok,count=pcall(GetNumGuildBankTabs); if not ok or not number(count) then return end
    local st=self:Store()
    local entry=st.guilds[key] or {}; st.guilds[key]=entry
    entry.name=name; entry.realm=self:Ruleset(); entry.tabs=entry.tabs or {}
    local current=GetCurrentGuildBankTab and GetCurrentGuildBankTab()
    local per=MAX_GUILDBANK_SLOTS_PER_TAB or 98
    for tab=1,count do
        local tabName,icon,viewable
        if GetGuildBankTabInfo then tabName,icon,viewable=GetGuildBankTabInfo(tab) end
        if plain(viewable) and viewable then
            local items={size=per,name=text(tabName),icon=number(icon) or text(icon)}
            local found=0
            for slot=1,per do
                local link=text(GetGuildBankItemLink(tab,slot))
                if link then
                    local _,stack=GetGuildBankItemInfo(tab,slot)
                    items[slot]={link,number(stack) or 1}; found=found+1
                end
            end
            if found>0 or (plain(current) and current==tab) then entry.tabs[tab]=items end
        end
    end
    entry.seen=now()
    self:Changed("guild:"..key,true)
end
-- Something changed: drop the cached counts and redraw what is open.
function Bags:Changed(who,quiet)
    self.indexes=self.indexes or {}
    if who then self.indexes[who]=nil end
    if quiet then return end
    for _,kind in ipairs({"bags","bank"}) do
        local view=self.views and self.views[kind]
        if view and view:IsShown() then self:FillView(kind) end
    end
end
-- Counting: itemID -> {bags=, bank=, worn=} per character.
local function itemID(link)
    if not link then return end
    local id=link:match("item:(%d+)")
    return id and tonumber(id)
end
Bags.ItemID=itemID
function Bags:Index(guid)
    self.indexes=self.indexes or {}
    if self.indexes[guid] then return self.indexes[guid] end
    local st=self:Store(); local index={}
    local function add(link,count,field)
        local id=itemID(link); if not id then return end
        local e=index[id]; if not e then e={bags=0,bank=0,worn=0,total=0}; index[id]=e end
        e[field]=e[field]+count; e.total=e.total+count
    end
    local function containers(list,field)
        for _,bag in ipairs(list or {}) do for slot=1,(bag.size or 0) do local it=bag[slot]; if it then add(it[1],it[2] or 1,field) end end end
    end
    if guid:sub(1,6)=="guild:" then
        local entry=st.guilds[guid:sub(7)]
        if entry then for _,tab in pairs(entry.tabs or {}) do for slot=1,(tab.size or 0) do local it=tab[slot]; if it then add(it[1],it[2] or 1,"bank") end end end end
    else
        local c=st.chars[guid]
        if c then
            containers(c.bags,"bags"); containers(c.bank,"bank")
            for _,link in pairs(c.worn or {}) do add(link,1,"worn") end
        end
    end
    self.indexes[guid]=index
    return index
end
-- Characters on a ruleset: you first, then by name (or by gold for the gold list).
function Bags:Characters(ruleset,byGold)
    local st=self:Store(); local me=self:Me(); local list={}
    ruleset=ruleset or self:Ruleset()
    for guid,c in pairs(st.chars) do
        if type(c)=="table" and sameRealm(c.realm)==ruleset then list[#list+1]={guid=guid,c=c,me=guid==me} end
    end
    table.sort(list,function(a,b)
        if byGold then
            local ma,mb=a.c.money or 0,b.c.money or 0
            if ma~=mb then return ma>mb end
        elseif a.me~=b.me then return a.me end
        return (a.c.name or "")<(b.c.name or "")
    end)
    return list
end
function Bags:Rulesets()
    local seen,list={},{}
    for _,c in pairs(self:Store().chars) do
        local key=type(c)=="table" and c.realm and sameRealm(c.realm)
        if key and not seen[key] then seen[key]=true; list[#list+1]=key; self.realmNames=self.realmNames or {}; self.realmNames[key]=c.realmName or c.realm end
    end
    table.sort(list,function(a,b) if a==self:Ruleset() then return true elseif b==self:Ruleset() then return false end return a<b end)
    return list
end
function Bags:ClassName(c,guid,full)
    local name=(full and c and c.fullName) or (c and c.name) or "?"
    local color=c and c.class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[c.class]
    if color and color.r then name=string.format("|cff%02x%02x%02x%s|r",color.r*255,color.g*255,color.b*255,name) end
    -- The other faction gets its banner, so it is never mistaken for a mail target.
    local mine=UnitFactionGroup and UnitFactionGroup("player")
    if c and c.faction and plain(mine) and mine and c.faction~=mine then
        name="|TInterface\\Icons\\"..(c.faction=="Alliance" and "INV_BannerPVP_02" or "INV_BannerPVP_01")..":12:12|t "..name
    end
    return name
end
function Bags:ClassIcon(c)
    local class=c and c.class
    if not class then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return "Interface\\Icons\\ClassIcon_"..class:sub(1,1)..class:sub(2):lower()
end
function Bags:Money(amount)
    amount=math.max(0,math.floor(tonumber(amount) or 0))
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok,s=pcall(C_CurrencyInfo.GetCoinTextureString,amount); if ok and type(s)=="string" then return s end
    end
    if GetCoinTextureString then local ok,s=pcall(GetCoinTextureString,amount); if ok and type(s)=="string" then return s end end
    local gold,silver,copper=math.floor(amount/10000),math.floor(amount/100)%100,amount%100
    return string.format("%dg %ds %dc",gold,silver,copper)
end
function Bags:Ago(stamp)
    if type(stamp)~="number" or stamp<=0 then return "never" end
    local seconds=math.max(0,now()-stamp)
    if seconds<90 then return "just now" end
    if seconds<3600 then return math.floor(seconds/60+.5).." min ago" end
    if seconds<86400*2 then return math.floor(seconds/3600+.5).." h ago" end
    return math.floor(seconds/86400+.5).." days ago"
end
-- Gold tooltip -----------------------------------------------------------
function Bags:GoldLines()
    local lines,total={},0
    local me=self:Me()
    for _,entry in ipairs(self:Characters(nil,true)) do
        local money=entry.c.money or 0
        if entry.guid==me then local live=GetMoney and GetMoney(); money=number(live) or money end
        total=total+money
        lines[#lines+1]={self:ClassName(entry.c,entry.guid),self:Money(money)}
    end
    return lines,total
end
function Bags:ShowGold(owner)
    if not self:Settings().gold or not GameTooltip then return end
    self:Record(true)
    GameTooltip:SetOwner(owner,"ANCHOR_TOPLEFT")
    GameTooltip:SetText("Gold on your characters",1,.82,0)
    local lines,total=self:GoldLines()
    for _,line in ipairs(lines) do GameTooltip:AddDoubleLine(line[1],line[2],1,1,1,1,1,1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Total",self:Money(total),1,.82,0,1,1,1)
    GameTooltip.ftBagGold=true
    GameTooltip:Show()
end
function Bags:HookMoney(frame)
    if not frame or frame.ftGoldHooked or not frame.HookScript then return end
    frame.ftGoldHooked=true
    local parts={frame}
    for _,key in ipairs({"GoldButton","SilverButton","CopperButton"}) do if frame[key] then parts[#parts+1]=frame[key] end end
    for _,part in ipairs(parts) do
        part:HookScript("OnEnter",function() self:ShowGold(frame) end)
        part:HookScript("OnLeave",function() if GameTooltip.ftBagGold then GameTooltip.ftBagGold=nil; GameTooltip:Hide() end end)
    end
end
-- The two buttons on the game's bag window --------------------------------
-- Same size and frame art as the game's own bank bag slots and sort button,
-- so they sit in the row without looking added on.
function Bags:SmallButton(parent,icon)
    local b=CreateFrame("Button",nil,parent)
    b:SetSize(28,26)
    b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetAtlas("bank-frame-bag-slot-bg"); b.bg:SetPoint("TOPLEFT",2,-2); b.bg:SetPoint("BOTTOMRIGHT",-2,2)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",3,-3); b.icon:SetPoint("BOTTOMRIGHT",-3,3)
    b.icon:SetTexture(icon); b.icon:SetTexCoord(.08,.92,.08,.92)
    b.border=b:CreateTexture(nil,"OVERLAY"); b.border:SetAtlas("bank-frame-bag-slotframe"); b.border:SetAllPoints()
    local glow=b:CreateTexture(nil,"HIGHLIGHT"); glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); glow:SetBlendMode("ADD"); glow:SetPoint("TOPLEFT",2,-2); glow:SetPoint("BOTTOMRIGHT",-2,2)
    b:SetScript("OnMouseDown",function() b.icon:SetPoint("TOPLEFT",4,-4); b.icon:SetPoint("BOTTOMRIGHT",-2,2) end)
    b:SetScript("OnMouseUp",function() b.icon:SetPoint("TOPLEFT",3,-3); b.icon:SetPoint("BOTTOMRIGHT",-3,3) end)
    return b
end
function Bags:AddBagButtons(frame)
    if not frame or frame.ftBagButtons then return frame and frame.ftBagButtons end
    local bank=self:SmallButton(frame,self.BANK_ICON)
    bank:SetScript("OnClick",function() self:ToggleBank() end)
    FT:Tooltip(bank,"Bank (view only)",function()
        local who=self:BankWho()
        local whose=who==self:Me() and "your bank" or (self:WhoName(who).."'s bank")
        return "Open "..whose.." from your last visit. View and link only."
    end)
    local chars=self:SmallButton(frame,self:ClassIcon(self:Record()))
    chars:SetScript("OnClick",function(owner) self:ChooseCharacter(owner) end)
    FT:Tooltip(chars,"Characters","Show another character's bags and bank. Characters on this ruleset only.")
    frame.ftBagButtons={bank=bank,chars=chars}
    if hooksecurefunc and frame.UpdateSearchBox then hooksecurefunc(frame,"UpdateSearchBox",function() self:PlaceBagButtons(frame,true) end) end
    frame:HookScript("OnShow",function() self:PlaceBagButtons(frame) end)
    return frame.ftBagButtons
end
-- The search box keeps the width the game gave it; with the buttons on it
-- is set to that width minus room for them. It is never shrunk from its
-- current width, so redrawing (or any other setting) cannot make it smaller.
local SEARCH_CUT=62
function Bags:PlaceBagButtons(frame,fromGame)
    local buttons=frame and frame.ftBagButtons; if not buttons then return end
    local s=self:Settings()
    local on=s.view and s.buttons
    local sort=BagItemAutoSortButton
    -- Only the all-in-one bag has room in its top row; a separate backpack
    -- is narrow, so there the buttons hang on its left edge like side tabs
    -- and its search box keeps its full width.
    local combined=frame==ContainerFrameCombinedBags
    local sortHere=combined and sort and sort.GetParent and sort:GetParent()==frame and sort:IsShown()
    local box=BagItemSearchBox
    local ours=box and box.anchorBag==frame
    -- The game has just laid the box out: this is its own width.
    if ours and (fromGame or not frame.ftSearchFull) then
        local width=box:GetWidth()
        if number(width) and width>0 and (fromGame or not frame.ftSearchCut) then frame.ftSearchFull=width end
    end
    buttons.bank:SetShown(on); buttons.chars:SetShown(on)
    local want=frame.ftSearchFull
    if on and sortHere and want and want-SEARCH_CUT>60 then want=want-SEARCH_CUT; frame.ftSearchCut=true else frame.ftSearchCut=nil end
    if ours and want then box:SetWidth(want) end
    if not on then return end
    buttons.chars.icon:SetTexture(self:ClassIcon(self:ViewedRecord()))
    buttons.bank:ClearAllPoints(); buttons.chars:ClearAllPoints()
    if sortHere then
        buttons.chars:SetPoint("RIGHT",sort,"LEFT",-3,0)
        buttons.bank:SetPoint("RIGHT",buttons.chars,"LEFT",-3,0)
    else
        buttons.chars:SetPoint("TOPRIGHT",frame,"TOPLEFT",1,-58)
        buttons.bank:SetPoint("TOP",buttons.chars,"BOTTOM",0,-2)
    end
end
-- Right-click the bag's own portrait (top left) to open the bank view. The
-- portrait is the game's settings menu button, which opens on any click. A
-- small invisible button of ours lies on top of it and takes right-clicks
-- only: left-clicks and the mouse-over pass through to the game's button, so
-- its menu and tooltip work as before. Without those two game functions the
-- right-click is caught after the fact instead (the game's menu closes again).
-- The game's line "<Click for Bag Settings>" becomes "<Left-click ...>" now
-- that right-click opens the bank; then our own line is added once.
local RIGHT_LINE="<Right-click to view your bank>"
local function fixTooltip(tip)
    -- The game's text has a color code around it; compare the plain words.
    local phrases={"Click for Bag Settings"}
    if type(CLICK_BAG_SETTINGS)=="string" then
        local plainText=CLICK_BAG_SETTINGS:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("[<>]","")
        if plainText:sub(1,6)=="Click " then phrases[#phrases+1]=plainText end
    end
    local has=false
    for i=1,(tip:NumLines() or 0) do
        local line=_G[(tip.GetName and tip:GetName() or "GameTooltip").."TextLeft"..i]
        local value=line and line:GetText()
        if type(value)=="string" and (not issecretvalue or not issecretvalue(value)) then
            if value:find(RIGHT_LINE,1,true) then has=true
            elseif not value:find("Left-click",1,true) then
                for _,phrase in ipairs(phrases) do
                    local at=value:find(phrase,1,true)
                    if at then line:SetText(value:sub(1,at-1).."Left-c"..value:sub(at+1)); break end
                end
            end
        end
    end
    if not has then tip:AddLine(RIGHT_LINE,.1,1,.1) end
    tip:Show()
end
function Bags:HookPortrait(frame)
    local portrait=frame and frame.PortraitButton
    if not portrait or frame.ftPortraitHooked or not portrait.HookScript then return end
    frame.ftPortraitHooked=true
    -- A child of the portrait, so mouse-over passes up to it.
    local cover=CreateFrame("Button",nil,portrait)
    cover:SetAllPoints(portrait); cover:SetFrameLevel(portrait:GetFrameLevel()+5)
    cover:RegisterForClicks("RightButtonUp")
    local passes=cover.SetPassThroughButtons and cover.SetPropagateMouseMotion
    if passes then
        pcall(cover.SetPassThroughButtons,cover,"LeftButton","MiddleButton","Button4","Button5")
        pcall(cover.SetPropagateMouseMotion,cover,true)
        cover:SetScript("OnClick",function(_,button) if button=="RightButton" and self:Settings().view then self:ToggleBank() end end)
        frame.ftPortraitCover=cover
    else cover:Hide() end
    cover:SetShown(passes and self:Settings().view and true or false)
    portrait:HookScript("OnMouseDown",function(owner,button)
        if passes or button~="RightButton" or not self:Settings().view then return end
        if owner.IsMenuOpen and owner.CloseMenu then
            local ok,open=pcall(owner.IsMenuOpen,owner)
            if ok and open then pcall(owner.CloseMenu,owner) end
        end
        self:ToggleBank()
    end)
    portrait.ftBagPortrait=true
    portrait:HookScript("OnEnter",function()
        if self:Settings().view and GameTooltip:IsOwned(portrait) then fixTooltip(GameTooltip) end
    end)
    -- The game may fill the tooltip after its own OnEnter; catch it when shown.
    if not self.tipHooked and GameTooltip.HookScript then
        self.tipHooked=true
        GameTooltip:HookScript("OnShow",function(tip)
            local owner=tip.GetOwner and tip:GetOwner()
            if owner and rawget(owner,"ftBagPortrait") and FT.dbReady and self:Settings().view and not self.fixing then
                self.fixing=true; pcall(fixTooltip,tip); self.fixing=nil
            end
        end)
    end
    -- Opening your own bag (B) while another character's bags are shown in
    -- its place switches back to yours.
    frame:HookScript("OnShow",function()
        local v=self.views and self.views.bags
        if v and v:IsShown() and v.replaced then v.replaced=nil; self.viewing=nil; v:Hide() end
    end)
end
-- "Characters" in the bag's own settings menu (left-click on the portrait).
function Bags:HookBagMenus()
    if self.menusHooked or not Menu or not Menu.ModifyMenu then return end
    self.menusHooked=true
    local function add(owner,root)
        if not FT.dbReady then return end
        local frame=owner and owner.GetParent and owner:GetParent()
        if frame and frame~=ContainerFrameCombinedBags and frame~=ContainerFrame1 then return end
        if not self:Settings().view then return end
        root:CreateDivider()
        local sub=root:CreateButton("Characters")
        for _,entry in ipairs(self:Characters()) do
            local guid=entry.guid
            sub:CreateButton(self:ClassName(entry.c,guid)..(entry.me and " (you)" or ""),function() self:Select(guid,true) end)
        end
    end
    for _,tag in ipairs({"MENU_CONTAINER_FRAME_COMBINED","MENU_CONTAINER_FRAME"}) do pcall(Menu.ModifyMenu,tag,add) end
end
function Bags:GameBags()
    local list={}
    for _,name in ipairs({"ContainerFrameCombinedBags","ContainerFrame1"}) do if _G[name] then list[#list+1]=_G[name] end end
    return list
end
function Bags:GameBagShown()
    for _,frame in ipairs(self:GameBags()) do if frame:IsShown() then return frame end end
end
-- Who is being looked at ---------------------------------------------------
function Bags:Viewed() return self.viewing or self:Me() end
function Bags:ViewedRecord() local st=self:Store(); return st.chars[self:Viewed() or ""] or self:Record() end
function Bags:BankWho() return self.bankWho or self:Viewed() end
function Bags:WhoName(who)
    local c=self:Store().chars[who or ""]
    if who==self:Me() then return "your" end
    return c and c.name or "this character"
end
function Bags:CharacterOptions()
    local options={}
    for _,entry in ipairs(self:Characters()) do
        local c=entry.c
        options[#options+1]={value=entry.guid,label=(c.name or "?")..(entry.me and " (you)" or ""),icon=self:ClassIcon(c),
            tooltipTitle=c.name,tooltip=function()
                return "Level "..(c.level or "?").." · "..self:Money(entry.me and (number(GetMoney and GetMoney()) or c.money) or c.money)..
                    "\nBags seen "..self:Ago(entry.me and now() or c.seen)..". Bank seen "..self:Ago(c.bankSeen).."."
            end}
    end
    return options
end
function Bags:ChooseCharacter(owner)
    owner.options=function() return self:CharacterOptions() end
    owner.value=owner.ftBankMenu and self:BankWho() or self:Viewed()
    owner.menuWidth=210
    owner.onSelect=function(value) self:Select(value) end
    FT:ShowChoices(owner)
end
-- Picking a character switches the bag view and the bank view together.
-- Picking another character puts their bags in place of your own bag
-- window (same spot); picking yourself brings your own bag back.
function Bags:Select(value)
    local me=self:Me()
    self.viewing=value~=me and value or nil
    self.bankWho=nil
    local bagView=self.views and self.views.bags
    if value==me then
        if bagView and bagView:IsShown() then
            local reopen=bagView.replaced
            bagView:Hide()
            if reopen and not self:GameBagShown() and OpenAllBags then pcall(OpenAllBags) end
        end
    elseif self:GameBagShown() or (bagView and bagView:IsShown()) or not (self.views and self.views.bank and self.views.bank:IsShown()) then
        self:ShowView("bags")
    end
    local bankView=self.views and self.views.bank
    if bankView and bankView:IsShown() then self:FillView("bank") end
    for _,frame in ipairs(self:GameBags()) do self:PlaceBagButtons(frame) end
end
function Bags:ToggleBank()
    local view=self.views and self.views.bank
    if view and view:IsShown() then view:Hide(); return end
    if self.bankOpen and self:BankWho()==self:Me() then FT:Toast("Your bank is open right now.",3); return end
    self:ShowView("bank")
end
-- The view-only windows ------------------------------------------------------
-- One slot: the game's own item button (same frame, empty-slot art and
-- quality border as the real bag), or a plain copy where that is missing.
local function slotButton(view)
    local ok,b=pcall(CreateFrame,"ItemButton",nil,view.grid)
    if ok and b and (b.icon or b.Icon) and SetItemButtonTexture then
        b.real=true; b.icon=b.icon or b.Icon
    else
        b=CreateFrame("Button",nil,view.grid)
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
        b.IconBorder=b:CreateTexture(nil,"OVERLAY"); b.IconBorder:SetAllPoints(); b.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame"); b.IconBorder:Hide()
        b.Count=b:CreateFontString(nil,"OVERLAY","NumberFontNormal"); b.Count:SetPoint("BOTTOMRIGHT",-3,3); b.Count:SetJustifyH("RIGHT")
        local glow=b:CreateTexture(nil,"HIGHLIGHT"); glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); glow:SetBlendMode("ADD"); glow:SetAllPoints()
    end
    b:SetSize(SLOT,SLOT)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    -- The item's own tooltip (with item counts, if those are on).
    b:SetScript("OnEnter",function(owner)
        if not owner.link then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        pcall(GameTooltip.SetHyperlink,GameTooltip,owner.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    -- View only: shift-click links the item, ctrl-click tries it on; nothing moves.
    b:SetScript("OnClick",function(owner)
        if owner.link and HandleModifiedItemClick then pcall(HandleModifiedItemClick,owner.link) end
    end)
    b.ftTipTitle="Item"
    return b
end
function Bags:MakeView(kind)
    self.views=self.views or {}
    if self.views[kind] then return self.views[kind] end
    local name=kind=="bags" and "ForeverToolsBagView" or "ForeverToolsBankView"
    -- The bank view uses the game's textured frame, like Forever's own bank.
    local ok,view=pcall(CreateFrame,"Frame",name,UIParent,kind=="bank" and "PortraitFrameTemplate" or "PortraitFrameFlatTemplate")
    if not ok or not view then view=CreateFrame("Frame",name,UIParent); FT:Panel(view) end
    self.views[kind]=view
    view.kind=kind
    view:SetFrameStrata("MEDIUM"); view:SetClampedToScreen(true); view:SetMovable(true); view:EnableMouse(true)
    if view.SetToplevel then view:SetToplevel(true) end
    view:RegisterForDrag("LeftButton")
    view:SetScript("OnDragStart",function(owner) if not self:Settings().locked then owner:StartMoving() end end)
    view:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local left,top=owner:GetLeft(),owner:GetTop()
        if number(left) and number(top) then
            local s=self:Settings(); local scale=owner:GetScale() or 1
            s[kind=="bags" and "bagX" or "bankX"],s[kind=="bags" and "bagY" or "bankY"]=left*scale,top*scale
        end
    end)
    if not view.CloseButton then FT:AddClose(view,nil,4) end
    if not view.SetTitle then
        view.ftTitle=view:CreateFontString(nil,"OVERLAY","GameFontNormal"); view.ftTitle:SetPoint("TOP",0,-5)
    end
    if UISpecialFrames then table.insert(UISpecialFrames,name) end
    -- Top row, like the game's bag: search on the left, the character button on the right.
    local okBox,search=pcall(CreateFrame,"EditBox",nil,view,"SearchBoxTemplate")
    if not okBox or not search then search=CreateFrame("EditBox",nil,view) end
    search:SetSize(kind=="bags" and 355 or 395,20); search:SetPoint("TOPLEFT",62,-37); search:SetAutoFocus(false)
    search:HookScript("OnTextChanged",function() self:Filter(view) end)
    view.search=search
    -- The window's own portrait (the character's class icon) picks the
    -- character: left-click for the list, right-click for the other window.
    local chars=CreateFrame("Button",nil,view)
    chars:SetSize(54,54); chars:SetPoint("TOPLEFT",-6,8); chars:SetFrameLevel(view:GetFrameLevel()+20)
    chars:RegisterForClicks("LeftButtonUp","RightButtonUp")
    chars.icon=chars:CreateTexture(nil,"ARTWORK"); chars.icon:SetPoint("TOPLEFT",8,-8); chars.icon:SetPoint("BOTTOMRIGHT",-8,8); FT:RoundIcon(chars.icon)
    -- With the game's portrait frame the portrait itself shows the icon.
    if view.SetPortraitToAsset then chars.icon:Hide() end
    local glow=chars:CreateTexture(nil,"HIGHLIGHT"); glow:SetAtlas("bags-roundhighlight"); glow:SetBlendMode("ADD"); glow:SetPoint("TOPLEFT",5,-5); glow:SetPoint("BOTTOMRIGHT",-5,5)
    chars:SetScript("OnClick",function(owner,button)
        if button=="RightButton" then
            if kind=="bags" then self:ToggleBank() else self:ShowView("bags") end
        else self:ChooseCharacter(owner) end
    end)
    FT:Tooltip(chars,"Characters",kind=="bank" and "Click: another character's bank. Right-click: bag view." or "Click: another character's bags. Right-click: bank view.")
    view.chars=chars
    if kind=="bank" then
        -- One button per bank tab, in the row under the search box.
        view.tabs={}
        view.tab=1
    end
    view.grid=CreateFrame("Frame",nil,view)
    view.grid:SetPoint("TOPLEFT",8,-66)
    view.slots={}
    view.note=view:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); view.note:SetPoint("BOTTOMLEFT",12,10); view.note:SetJustifyH("LEFT")
    view.note:SetTextColor(.82,.78,.68)
    view.money=view:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); view.money:SetPoint("BOTTOMRIGHT",-12,10); view.money:SetJustifyH("RIGHT")
    view.empty=view:CreateFontString(nil,"OVERLAY","GameFontHighlight"); view.empty:SetPoint("TOP",view.grid,"TOP",0,-20); view.empty:SetJustifyH("CENTER")
    if kind=="bank" then self:BuildBankParts(view) end
    view:SetScript("OnHide",function()
        if kind=="bank" then self.bankWho=nil; return end
        -- Closed with its X or Escape: your own bag comes back where it was.
        if view.replaced and not self.switching then
            view.replaced=nil; self.viewing=nil
            if not self:GameBagShown() and OpenAllBags and not InCombatLockdown() then pcall(OpenAllBags) end
        end
    end)
    view:Hide()
    return view
end
function Bags:PlaceView(view)
    local s=self:Settings(); local kind=view.kind
    -- In place of the game's bag: exactly where it is, which then closes.
    local bag=kind=="bags" and self:GameBagShown()
    if bag then
        local right,top=bag:GetRight(),bag:GetTop()
        if number(right) and number(top) then
            local ratio=bag:GetEffectiveScale()/view:GetEffectiveScale()
            view:ClearAllPoints(); view:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",right*ratio,top*ratio)
            view.replaced=true
            if CloseAllBags then pcall(CloseAllBags) end
            return
        end
    end
    if kind=="bags" then view.replaced=nil end
    local x,y=s[kind=="bags" and "bagX" or "bankX"],s[kind=="bags" and "bagY" or "bankY"]
    view:ClearAllPoints()
    if x and y then local scale=view:GetScale() or 1; view:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale); return end
    -- Not placed yet: bags at the bottom right like the game's, the bank on
    -- the left like the game's own bank.
    if kind=="bags" then view:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOMRIGHT",-480,120)
    else view:SetPoint("TOPLEFT",UIParent,"TOPLEFT",16,-116) end
end
function Bags:ShowView(kind)
    if not self:Settings().view then return end
    self:Record(true)
    local view=self:MakeView(kind)
    local wasShown=view:IsShown()
    self:FillView(kind)
    -- Each time: a bag window that is open is replaced in its spot.
    if not wasShown or (kind=="bags" and self:GameBagShown()) then self:PlaceView(view) end
    view:Show()
    if self.ApplySkin then self:ApplySkin(view) end
end
-- The containers to draw for a view: list of {size=, [slot]={link,count,icon,quality}}.
function Bags:ViewData(kind)
    local st=self:Store()
    if kind=="bank" then
        local who=self:BankWho()
        local c=st.chars[who or ""]
        return c and c.bank,c and c.bankSeen,c,(c and c.name or "?").."'s bank",c
    end
    local who=self:Viewed()
    local c=st.chars[who or ""]
    return c and c.bags,c and c.seen,c,(c and c.name or "?").."'s bags",c
end
local function iconFor(item)
    if item[3] then return item[3] end
    local id=itemID(item[1])
    if id and C_Item and C_Item.GetItemIconByID then local ok,icon=pcall(C_Item.GetItemIconByID,id); if ok and plain(icon) then return icon end end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
Bags.IconFor=function(item) return iconFor(item) end
local function qualityFor(item)
    if item[4] then return item[4] end
    local hex=item[1] and item[1]:match("|c(%x%x%x%x%x%x%x%x)")
    for quality,color in pairs(ITEM_QUALITY_COLORS or {}) do
        if hex and color.hex and color.hex:lower():find(hex:lower(),1,true) then return quality end
    end
end
Bags.QualityFor=qualityFor
-- Bank view parts, laid out like Forever's own bank window: stone
-- background, search at the top right, the slots in rows of eight, a divider,
-- "Bag Slots:" with the bank's bag tabs (a lock where one is not bought), and
-- the character's money at the bottom right.
local BANK_COLUMNS,BANK_GAP,BANK_PAGE=8,12,88
function Bags:BuildBankParts(view)
    view.Background=view:CreateTexture(nil,"BACKGROUND",nil,-5)
    view.Background:SetAtlas("bank-frame-background")
    if view.Background.SetHorizTile then view.Background:SetHorizTile(true); view.Background:SetVertTile(true) end
    view.Background:SetPoint("TOPLEFT",2,-21); view.Background:SetPoint("BOTTOMRIGHT",-2,28)
    view.search:ClearAllPoints(); view.search:SetSize(130,20); view.search:SetPoint("TOPRIGHT",-24,-33)
    view.grid:ClearAllPoints(); view.grid:SetPoint("TOP",0,-66)
    view.divider=view:CreateTexture(nil,"ARTWORK"); view.divider:SetAtlas("bank-divider",true)
    if view.divider.SetScale then view.divider:SetScale(.48) end
    view.bagText=view:CreateFontString(nil,"ARTWORK","GameFontNormalLarge"); view.bagText:SetText(BAGSLOTTEXT_COLON or "Bag Slots:")
    view.bagSlots={}
    view.bottom=view:CreateTexture(nil,"BORDER"); view.bottom:SetColorTexture(0,0,0,.45)
    view.bottom:SetPoint("BOTTOMLEFT",4,4); view.bottom:SetPoint("BOTTOMRIGHT",-4,4); view.bottom:SetHeight(22)
    view.note:ClearAllPoints(); view.note:SetPoint("BOTTOMLEFT",12,10)
    view.money:ClearAllPoints(); view.money:SetPoint("BOTTOMRIGHT",-14,10)
    view.pages={}; view.page=1
end
local function bankSlot(view,i)
    local b=view.bagSlots[i]
    if b then return b end
    b=CreateFrame("Button",nil,view); b:SetSize(28,28)
    b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetAtlas("bank-frame-bag-slot-bg"); b.bg:SetAllPoints()
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",2,-2); b.icon:SetPoint("BOTTOMRIGHT",-2,2)
    b.lock=b:CreateTexture(nil,"ARTWORK",nil,1); b.lock:SetAtlas("bankslot-icon-lock"); b.lock:SetAllPoints()
    b.frame=b:CreateTexture(nil,"OVERLAY"); b.frame:SetAtlas("bank-frame-bag-slotframe"); b.frame:SetPoint("TOPLEFT",-2,2); b.frame:SetPoint("BOTTOMRIGHT",2,-2)
    FT:Tooltip(b,function() return b.title or "Bank bag" end,function() return b.tip or "" end)
    view.bagSlots[i]=b
    return b
end
function Bags:FillBank(view,containers,seen,c)
    containers=containers or {}
    -- Forever also answers for the old main bank, which is always empty:
    -- leave out empty extra containers when there is a real tab.
    local list={}
    for _,bag in ipairs(containers) do
        local items=0; for slot=1,(bag.size or 0) do if bag[slot] then items=items+1 end end
        if items>0 or #containers==1 or bag.id~=-1 then list[#list+1]=bag end
    end
    -- All tabs make one list of slots, shown a page (88) at a time.
    local slots={}
    for _,bag in ipairs(list) do for slot=1,(bag.size or 0) do slots[#slots+1]=bag[slot] or false end end
    local pages=math.max(1,math.ceil(#slots/BANK_PAGE))
    if view.page>pages then view.page=1 end
    local first=(view.page-1)*BANK_PAGE
    local count=math.min(BANK_PAGE,#slots-first)
    local rows=math.max(1,math.ceil(count/BANK_COLUMNS))
    local width=BANK_COLUMNS*SLOT+(BANK_COLUMNS-1)*BANK_GAP
    local height=rows*SLOT+(rows-1)*BANK_GAP
    view.grid:SetSize(width,height)
    for i=1,count do
        local b=view.slots[i]
        if not b then b=slotButton(view); view.slots[i]=b end
        if not b.slotFrame then b.slotFrame=b:CreateTexture(nil,"OVERLAY",nil,-1); b.slotFrame:SetAtlas("bank-frame-item-slotframe"); b.slotFrame:SetPoint("TOPLEFT",-3,3); b.slotFrame:SetPoint("BOTTOMRIGHT",3,-3) end
        b.slotFrame:Show()
        local row,col=math.floor((i-1)/BANK_COLUMNS),(i-1)%BANK_COLUMNS
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",view.grid,"TOPLEFT",col*(SLOT+BANK_GAP),-row*(SLOT+BANK_GAP))
        b.emptyBackgroundAtlas="bags-item-bankslot64"
        local item=slots[first+i]
        self:PaintSlot(b,item or nil)
        b:Show()
    end
    for i=count+1,#view.slots do view.slots[i]:Hide() end
    view.grid:SetShown(count>0)
    if count==0 then
        view.empty:SetText("Visit a banker once on "..((c and c.name) or "this character").." to see the bank here.")
        view.empty:SetWidth(width-20); view.empty:Show()
    else view.empty:Hide() end
    -- Page tabs on the right edge, like the game's (only with more than one page).
    for p=1,pages do
        local tab=view.pages[p]
        if not tab then
            tab=self:SmallButton(view,self.BANK_ICON); tab:SetSize(36,36); view.pages[p]=tab
            tab:SetPoint("TOPLEFT",view,"TOPRIGHT",2,-60-(p-1)*42)
            tab:SetScript("OnClick",function() view.page=p; self:FillView("bank") end)
            FT:Tooltip(tab,"Page "..p,"Show this page of the bank.")
        end
        tab:SetShown(pages>1); tab:SetAlpha(p==view.page and 1 or .55)
    end
    for p=pages+1,#view.pages do view.pages[p]:Hide() end
    -- Divider and bag slots under the items.
    local gridBottom=66+(count>0 and height or 60)
    view.divider:ClearAllPoints(); view.divider:SetPoint("TOP",view,"TOP",0,-(gridBottom+14)/(view.divider.GetScale and view.divider:GetScale() or 1))
    view.bagText:ClearAllPoints(); view.bagText:SetPoint("TOPLEFT",view,"TOPLEFT",26,-(gridBottom+36))
    local max=(c and c.bankMax) or 9
    local shown=0
    for n=2,max do
        shown=shown+1
        local b=bankSlot(view,shown)
        b:ClearAllPoints(); b:SetPoint("LEFT",view.bagText,"RIGHT",10+(shown-1)*36,0)
        local tab=list[n]
        if tab then
            b.icon:SetTexture(tab.icon or ("Interface\\Icons\\INV_Misc_Bag_0"..math.min(9,n))); b.icon:Show(); b.lock:Hide()
            b.title=tab.name or ("Bank bag "..(n-1)); b.tip="Bought. Its slots are part of the list above."
        else
            b.icon:Hide(); b.lock:Show(); b.title="Bank bag "..(n-1); b.tip="Not bought yet."
        end
        b:Show()
    end
    for i=shown+1,#view.bagSlots do view.bagSlots[i]:Hide() end
    local me=self:BankWho()==self:Me()
    view.note:SetText("Seen "..self:Ago(seen))
    local money=c and (me and number(GetMoney and GetMoney()) or c.money)
    if money then view.money:SetText(self:Money(money)); view.money:Show() else view.money:Hide() end
    local frameWidth=math.max(width+60,(shown*36)+150)
    view:SetSize(frameWidth,gridBottom+36+28+30+12)
    self:Filter(view)
    if self.ApplySkin then self:ApplySkin(view) end
end
-- Draw one slot from what was saved.
function Bags:PaintSlot(b,item)
    b.link=item and item[1] or nil
    local count=item and (item[2] or 1) or 0
    local quality=item and self.QualityFor(item)
    if b.real then
        SetItemButtonTexture(b,item and self.IconFor(item) or nil)
        if SetItemButtonCount then SetItemButtonCount(b,count) end
        if SetItemButtonQuality then SetItemButtonQuality(b,quality,b.link) end
    else
        if item then b.icon:SetTexture(self.IconFor(item)) else b.icon:SetAtlas(b.emptyBackgroundAtlas or "bags-item-slot64") end
        b.icon:Show()
        b.Count:SetText(count>1 and count or ""); b.Count:SetShown(count>1)
        local color=quality and quality>=2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then b.IconBorder:SetVertexColor(color.r,color.g,color.b); b.IconBorder:Show() else b.IconBorder:Hide() end
    end
    b.ftEmpty=item==nil
end
function Bags:FillView(kind)
    local view=self:MakeView(kind)
    local containers,seen,c,title=self:ViewData(kind)
    local isBank=kind=="bank"
    view.ftTitleText=title
    if view.ftTitle then view.ftTitle:SetText(title) elseif view.SetTitle then view:SetTitle(title) end
    if view.SetPortraitToAsset then
        local who=isBank and self:BankWho() or self:Viewed()
        pcall(view.SetPortraitToAsset,view,self:ClassIcon(c))
    end
    view.chars.icon:SetTexture(self:ClassIcon(c or self:Record()))
    if isBank then return self:FillBank(view,containers,seen,c) end
    -- Like the game's combined bag: one line of slots (backpack first, then
    -- bag 1 to 4), drawn from the corner the game uses, or the one picked
    -- under Bag order; ten to a row. An empty keyring is left out, as the
    -- game does; a keyring with keys comes last.
    local slots={}
    local list={}
    for _,bag in ipairs(containers or {}) do
        local items=0; for slot=1,(bag.size or 0) do if bag[slot] then items=items+1 end end
        if (bag.id or 0)>=0 or items>0 then list[#list+1]=bag end
    end
    local function rank(bag) local id=bag.id or 0; return id<0 and 1000-id or id end
    table.sort(list,function(x,y) return rank(x)<rank(y) end)
    for _,bag in ipairs(list) do for slot=1,(bag.size or 0) do slots[#slots+1]=bag[slot] or false end end
    local order=FT.BagOrder
    local corner=order and order:Corner() or "bottomright"
    local columns=10
    local count=#slots
    local rows=math.max(1,math.ceil(count/columns))
    local width=columns*SLOT+(columns-1)*GAP
    view.grid:SetSize(width,rows*SLOT+(rows-1)*GAP)
    for i=1,count do
        local b=view.slots[i]
        if not b then b=slotButton(view); view.slots[i]=b end
        local k=order and order.Cell(i-1,count,columns,corner) or (i-1)
        local fromBottom,fromRight=math.floor(k/columns),k%columns
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",view.grid,"TOPLEFT",(columns-1-fromRight)*(SLOT+GAP),-(rows-1-fromBottom)*(SLOT+GAP))
        b.emptyBackgroundAtlas="bags-item-slot64"
        self:PaintSlot(b,slots[i] or nil)
        b:Show()
    end
    for i=count+1,#view.slots do view.slots[i]:Hide() end
    local index=count
    view.grid:SetShown(index>0)
    local who=self:Viewed()
    if index==0 then
        view.empty:SetText("Log in on "..((c and c.name) or "this character").." once to see its bags here.")
        view.empty:SetWidth(width-20); view.empty:Show()
    else view.empty:Hide() end
    local me=who==self:Me()
    view.note:SetText(me and "Your bags right now" or ("Seen "..self:Ago(seen)))
    if c then
        local money=me and number(GetMoney and GetMoney()) or c.money
        view.money:SetText(self:Money(money)); view.money:Show()
    else view.money:SetText(""); view.money:Hide() end
    local gridHeight=index>0 and (rows*SLOT+(rows-1)*GAP) or 60
    view:SetSize(width+16,66+gridHeight+34)
    self:Filter(view)
    if self.ApplySkin then self:ApplySkin(view) end
end
-- Search: everything that does not match fades.
function Bags:Filter(view)
    local query=view.search and view.search.GetText and view.search:GetText() or ""
    query=plain(query) and type(query)=="string" and query:lower():gsub("^%s+",""):gsub("%s+$","") or ""
    for _,b in ipairs(view.slots or {}) do
        if b:IsShown() then
            local match=query=="" or (b.link and (b.link:match("%[(.-)%]") or ""):lower():find(query,1,true))
            b:SetAlpha(match and 1 or .25)
        end
    end
end
-- Dark mode and the other bag looks reach these windows too.
function Bags:ApplySkin(view)
    local skins=FT.modules.IconStyles
    if not skins or not skins.BagWindow or not skins.Settings then return end
    local ok,s=pcall(skins.Settings,skins); if not ok or type(s)~="table" then return end
    -- The bank view follows the bank switch, the bag view the Bag menu skin.
    local isBank=view.kind=="bank"
    local on=isBank and s.bank==true or (not isBank and s.bagWindows)
    if not on and not view.ftSkinned then return end
    view.ftSkinned=true
    skins.markingBank=isBank or nil
    pcall(skins.BagWindow,skins,view)
    for _,b in ipairs(view.slots or {}) do
        if b:IsShown() then
            pcall(skins.BagSlot,skins,b,"bagWindows")
            local record=skins.bagSlots and skins.bagSlots[b]
            if record then record.empty=b.ftEmpty==true; pcall(skins.PaintEmptyBagSlot,skins,b,record) end
        end
    end
    skins.markingBank=nil
end
function Bags:Report()
    local st=FT.db.bagStore
    local chars,here,banks=0,0,0
    local ruleset=self:Ruleset()
    if type(st)=="table" and type(st.chars)=="table" then
        for _,c in pairs(st.chars) do chars=chars+1; if sameRealm(c.realm)==ruleset then here=here+1 end; if c.bank then banks=banks+1 end end
    end
    local guilds=0
    if type(st)=="table" and type(st.guilds)=="table" then for _ in pairs(st.guilds) do guilds=guilds+1 end end
    return "Bags: ruleset \""..ruleset.."\", "..here.." of "..chars.." characters here, "..banks.." banks read ("..(self.bankHow or "not this session").."), "..guilds.." guild banks, remembering "..(self:Recording() and "on" or "off")..", order "..tostring(self:Settings().order)..(self:Settings().insert and (", new loot "..self:Settings().insert) or "")..(self:Settings().cleanup and (", clean up "..self:Settings().cleanup) or "")
end
function Bags:Windows() local list={}; for _,view in pairs(self.views or {}) do list[#list+1]=view end; return list end
-- Characters ---------------------------------------------------------------
function Bags:Forget(guid)
    local st=self:Store()
    st.chars[guid]=nil
    if self.indexes then self.indexes[guid]=nil end
    if self.viewing==guid then self.viewing=nil end
    if self.bankWho==guid then self.bankWho=nil end
    for _,view in pairs(self.views or {}) do if view:IsShown() then self:FillView(view.kind) end end
end
function Bags:ForgetGuild(key)
    local st=self:Store(); st.guilds[key]=nil
    if self.indexes then self.indexes["guild:"..key]=nil end
end
-- Apply / events --------------------------------------------------------------
function Bags:HookBankFrame()
    local frame=_G.BankFrame
    if self.bankHooked or not frame or not frame.HookScript then return end
    self.bankHooked=true
    frame:HookScript("OnShow",function()
        if not FT.dbReady or not self:Recording() then return end
        self.bankOpen=true
        C_Timer.After(.5,function() self:ScanBank() end)
        C_Timer.After(2,function() self:ScanBank() end)
    end)
    frame:HookScript("OnHide",function() self.bankOpen=false end)
end
function Bags:Apply()
    self:HookBankFrame()
    self:HookBagMenus()
    local s=self:Settings()
    if self:AnyOn() then local st=self:Store(); if st.off~=true then st.started=true end end
    for _,frame in ipairs(self:GameBags()) do
        self:HookMoney(frame.MoneyFrame)
        if s.view then self:HookPortrait(frame) end
        if frame.ftPortraitCover then frame.ftPortraitCover:SetShown(s.view) end
        if s.view and s.buttons then self:AddBagButtons(frame) end
        self:PlaceBagButtons(frame)
    end
    if not s.view then for _,view in pairs(self.views or {}) do view:Hide() end end
    if self:Recording() then FT:Coalesce("ftBagsScan",function() self:ScanBags() end,1) end
    if FT.BagOrder then FT.BagOrder:Apply() end
    self:Refresh()
end
FT:RegisterModule("Bags",Bags)
local bankers
local function bankerTypes()
    if bankers then return bankers end
    bankers={}
    local types=Enum and Enum.PlayerInteractionType
    if types then
        for _,key in ipairs({"Banker","CharacterBanker","AccountBanker"}) do if types[key]~=nil then bankers[types[key]]="bank" end end
        if types.GuildBanker~=nil then bankers[types.GuildBanker]="guild" end
    end
    return bankers
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_MONEY","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","PLAYER_REGEN_ENABLED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW","PLAYER_INTERACTION_MANAGER_FRAME_HIDE","BANKFRAME_OPENED","BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED","PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED","BANK_TABS_CHANGED","GUILDBANKBAGSLOTS_CHANGED","PLAYER_GUILD_UPDATE","PLAYER_LOGOUT"}) do
    pcall(events.RegisterEvent,events,event)
end
events:SetScript("OnEvent",function(_,event,kind)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then
        Bags:Apply()
        if Bags:Recording() then C_Timer.After(3,function() Bags:Record(true); Bags:ScanBags() end) end
        return
    end
    if not Bags:Recording() then return end
    if event=="PLAYER_MONEY" then Bags:ScanMoney()
    elseif event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED" then FT:Coalesce("ftBagsScan",function() Bags:ScanBags() end,1)
    elseif event=="PLAYER_REGEN_ENABLED" then
        if Bags.pending then Bags.pending=nil; FT:Coalesce("ftBagsScan",function() Bags:ScanBags(); Bags:ScanGuild() end,1) end
    elseif event=="PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event=="BANKFRAME_OPENED" then
        local what=event=="BANKFRAME_OPENED" and "bank" or (plain(kind) and bankerTypes()[kind])
        if what=="bank" then
            Bags.bankOpen=true
            local view=Bags.views and Bags.views.bank
            if view and view:IsShown() and Bags:BankWho()==Bags:Me() then view:Hide() end
            -- The bank's contents arrive a moment after it opens: read twice.
            C_Timer.After(.5,function() Bags:ScanBank() end)
            C_Timer.After(2,function() Bags:ScanBank() end)
        elseif what=="guild" then
            Bags.guildOpen=true; Bags:QueryGuild()
            C_Timer.After(.5,function() Bags:ScanGuild() end)
        end
    elseif event=="PLAYER_INTERACTION_MANAGER_FRAME_HIDE" or event=="BANKFRAME_CLOSED" then
        local what=event=="BANKFRAME_CLOSED" and "bank" or (plain(kind) and bankerTypes()[kind])
        if what=="bank" then Bags.bankOpen=false elseif what=="guild" then Bags.guildOpen=false end
    elseif event=="PLAYERBANKSLOTS_CHANGED" or event=="PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" or event=="BANK_TABS_CHANGED" then
        if Bags.bankOpen then FT:Coalesce("ftBankScan",function() Bags:ScanBank() end,.5) end
    elseif event=="GUILDBANKBAGSLOTS_CHANGED" then
        if Bags.guildOpen then FT:Coalesce("ftGuildScan",function() Bags:ScanGuild() end,.5) end
    elseif event=="PLAYER_GUILD_UPDATE" then Bags:Record()
    elseif event=="PLAYER_LOGOUT" then pcall(Bags.Record,Bags,true)
    end
end)
FT.Bags=Bags
-- Settings pages: Bags (switches) and Characters (who is remembered) ---------
local switches={
    {"gold","Gold tooltip","INV_Misc_Coin_02","Hover your bag's gold to see every character's gold and the total."},
    {"view","Bank and other characters","INV_Misc_Bag_08","Right-click your bag's portrait to see your bank from anywhere (view only). Left-click it for other characters' bags."},
    {"buttons","Extra buttons on the bag","INV_Misc_Bag_10","Bank and character buttons next to the sort button."},
    {"locked","Lock bag and bank views","INV_Misc_Key_03","Keep the view windows in place."},
    {"counts","Item counts in tooltips","INV_Misc_Note_04","Item counts on tooltips. Look: Appearance > Item counts."},
}
function Bags:Refresh()
    local page=self.page
    if not page or not page.buttons then return end
    local s=self:Settings()
    for _,entry in ipairs(switches) do
        local b=page.buttons[entry[1]]
        b.label:SetText(entry[2]..": "..(s[entry[1]] and "On" or "Off")); FT:SetSelected(b,s[entry[1]])
    end
    for _,key in ipairs({"locked","buttons"}) do page.buttons[key]:SetEnabled(s.view); page.buttons[key]:SetAlpha(s.view and 1 or .45) end
    local st=FT.db.bagStore
    local count=0
    if type(st)=="table" and type(st.chars)=="table" then for _ in pairs(st.chars) do count=count+1 end end
    page.status:SetText(self:Recording() and (count==1 and "1 character remembered. Log in on others once to add them." or (count.." characters remembered.")) or "Not remembering characters.")
    if self.list and self.list.frame and self.list.frame:IsShown() then self.list:Refresh() end
    if FT.RefreshDock and page.frame and page.frame:IsShown() then FT:RefreshDock(page.frame) end
end
local page={}
Bags.page=page
function page:Open()
    if not self.frame then
        local hub=FT:HubOf("BagsGeneral"); local width=hub and hub.width or 540
        local frame=FT:Window("ForeverToolsBagsGeneral","Bags",width,420); self.frame=frame
        FT:PageInfo(frame,"Bags","Extras for the game's bag window. Characters are remembered at login, on this account only.")
        local hint=FT:Label(frame,"Gold, bank and alts' bags from your bag.",12); hint:SetPoint("TOPLEFT",24,-66); hint:SetWidth(width-48); hint:SetTextColor(.66,.59,.48)
        self.buttons={}
        for i,entry in ipairs(switches) do
            local key=entry[1]
            local b=FT:QuietButton(frame,entry[2],width-48,32,entry[3]); b:SetPoint("TOPLEFT",24,-96-(i-1)*40)
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            b:SetScript("OnClick",function()
                local s=Bags:Settings(); s[key]=not s[key]
                Bags:Apply()
            end)
            FT:Tooltip(b,entry[2],entry[4])
            self.buttons[key]=b
        end
        local more=FT:QuietButton(frame,"Item count settings",width-48,32,"tooltip"); more:SetPoint("TOPLEFT",24,-96-#switches*40)
        more:SetScript("OnClick",function() FT:OpenModule("ItemCounts") end)
        FT:Tooltip(more,"Item count settings","What counts show and where.")
        self.status=FT:Label(frame,"",12); self.status:SetPoint("TOPLEFT",24,-96-(#switches+1)*40-6); self.status:SetWidth(width-48); self.status:SetTextColor(.66,.59,.48)
        FT:Sections(frame,{{"In your bag",self.buttons.gold},{"Item counts",self.buttons.counts}})
    end
    Bags:Refresh(); self.frame:Show()
end
function page:Refresh() Bags:Refresh() end
FT:RegisterModule("BagsGeneral",page)
-- Characters: everyone remembered, by ruleset, with Forget.
local list={}
Bags.list=list
local ROW=40
function list:Refresh()
    if not self.frame then return end
    local st=Bags:Store()
    local on=Bags:Recording()
    self.remember.label:SetText("Remember my characters: "..(on and "On" or "Off")); FT:SetSelected(self.remember,on)
    local rows={}
    -- One section per ruleset you have characters on; click its title to
    -- open or close it. Your current ruleset starts open, the others closed.
    self.open=self.open or {}
    for _,ruleset in ipairs(Bags:Rulesets()) do
        local members={}
        for _,entry in ipairs(Bags:Characters(ruleset)) do members[#members+1]={guid=entry.guid,c=entry.c,me=entry.me} end
        for key,guild in pairs(st.guilds) do
            if type(guild)=="table" and sameRealm(guild.realm)==ruleset then members[#members+1]={guild=key,g=guild} end
        end
        if #members>0 then
            if self.open[ruleset]==nil then self.open[ruleset]=ruleset==Bags:Ruleset() end
            rows[#rows+1]={heading=ruleset,count=#members}
            if self.open[ruleset] then for _,m in ipairs(members) do rows[#rows+1]=m end end
        end
    end
    local width=self.content:GetWidth()
    for i,row in ipairs(rows) do
        local r=self.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,self.content); r:SetSize(width,ROW-4); self.rows[i]=r
            r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(26,26); r.icon:SetPoint("LEFT",6,0); FT:RoundIcon(r.icon)
            r.name=FT:Label(r,"",14); r.name:SetPoint("TOPLEFT",40,-3); r.name:SetWidth(width-80); r.name:SetJustifyH("LEFT")
            r.meta=FT:Label(r,"",11); r.meta:SetPoint("TOPLEFT",40,-20); r.meta:SetWidth(width-80); r.meta:SetJustifyH("LEFT"); r.meta:SetTextColor(.72,.66,.55)
            if r.meta.SetWordWrap then r.meta:SetWordWrap(false) end
            r.heading=FT:Label(r,"",15,true); r.heading:SetPoint("BOTTOMLEFT",28,6); r.heading:SetTextColor(1,.82,0)
            r.toggle=r:CreateTexture(nil,"ARTWORK"); r.toggle:SetSize(16,16); r.toggle:SetPoint("BOTTOMLEFT",4,7)
            -- Forget: a small red circle with a cross.
            r.forget=CreateFrame("Button",nil,r); r.forget:SetSize(24,24); r.forget:SetPoint("RIGHT",-6,0)
            r.forget:SetNormalTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            r.forget:SetHighlightTexture("Interface\\RaidFrame\\ReadyCheck-NotReady","ADD")
            FT:Tooltip(r.forget,"Forget",function() return r.forgetTip or "" end)
            -- The full line when it doesn't fit.
            r:EnableMouse(true)
            r:SetScript("OnEnter",function(owner)
                if owner.headingKey then return end
                GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText(owner.fullName or "",1,.82,0); GameTooltip:AddLine(owner.fullMeta or "",.96,.93,.86,true); GameTooltip:Show()
            end)
            r:SetScript("OnLeave",function() GameTooltip:Hide() end)
            r:SetScript("OnMouseUp",function(owner) if owner.headingKey then list.open[owner.headingKey]=not list.open[owner.headingKey]; list:Refresh() end end)
        end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,-(i-1)*ROW)
        local heading=row.heading~=nil
        r.heading:SetShown(heading); r.toggle:SetShown(heading); r.icon:SetShown(not heading); r.name:SetShown(not heading); r.meta:SetShown(not heading); r.forget:SetShown(not heading)
        r.headingKey=heading and row.heading or nil
        if heading then
            local shown=(Bags.realmNames and Bags.realmNames[row.heading]) or row.heading
            r.heading:SetText((row.heading==Bags:Ruleset() and (shown.." (this ruleset)") or shown).."  |cffb8ab8a("..row.count..")|r")
            r.toggle:SetTexture(list.open[row.heading] and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
        elseif row.guid then
            local c=row.c
            r.icon:SetTexture(Bags:ClassIcon(c))
            r.name:SetText(Bags:ClassName(c,row.guid)..(row.me and "  |cffb8ab8a(you)|r" or ""))
            r.meta:SetText("Level "..(c.level or "?").." · "..Bags:Money(c.money).." · bags "..Bags:Ago(row.me and now() or c.seen).." · bank "..Bags:Ago(c.bankSeen))
            r.fullName=c.name; r.fullMeta=r.meta:GetText()
            r.forgetTip="Remove "..(c.name or "this character").." from gold, item counts and character buttons."..(row.me and " You are on it now: it comes back when your bags change." or " It is added again the next time it logs in.")
            r.forget:SetScript("OnClick",function() FT:Confirm("Forget "..(c.name or "this character").."?",function() Bags:Forget(row.guid); list:Refresh(); Bags:Refresh() end) end)
        elseif row.guild then
            r.icon:SetTexture("Interface\\Icons\\INV_Shirt_GuildTabard_01")
            r.name:SetText("<"..(row.g.name or "?")..">  guild bank")
            local tabs=0; for _ in pairs(row.g.tabs or {}) do tabs=tabs+1 end
            r.meta:SetText(tabs.." tab"..(tabs==1 and "" or "s").." read · seen "..Bags:Ago(row.g.seen))
            r.fullName="<"..(row.g.name or "?")..">"; r.fullMeta=r.meta:GetText()
            r.forgetTip="Remove this guild bank. Read again when opened."
            r.forget:SetScript("OnClick",function() FT:Confirm("Forget the guild bank of <"..(row.g.name or "?")..">?",function() Bags:ForgetGuild(row.guild); list:Refresh() end) end)
        end
        r:Show()
    end
    for i=#rows+1,#self.rows do self.rows[i]:Hide() end
    self.content:SetHeight(math.max(1,#rows*ROW))
    self.none:SetShown(#rows==0)
end
function list:Open()
    if not self.frame then
        local hub=FT:HubOf("BagsCharacters"); local width=hub and hub.width or 540
        local frame=FT:Window("ForeverToolsBagsCharacters","Characters",width,420); self.frame=frame
        FT:PageInfo(frame,"Characters","Characters remembered, by ruleset. Forget removes one until it logs in again.")
        self.remember=FT:QuietButton(frame,"",width-48,32,"profiles"); self.remember:SetPoint("TOPLEFT",24,-66)
        self.remember:SetScript("OnClick",function()
            local st=Bags:Store()
            if Bags:Recording() then
                FT:Confirm("Stop remembering characters? Saved data stays.",function() st.off=true; list:Refresh(); Bags:Refresh() end)
            else st.off=nil; st.started=true; Bags:Record(true); Bags:ScanBags(); list:Refresh(); Bags:Refresh() end
        end)
        FT:Tooltip(self.remember,"Remember my characters","Remember gold, bags and banks of your characters.")
        local scroll=CreateFrame("ScrollFrame","ForeverToolsBagsCharactersScroll",frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",24,-110); scroll:SetPoint("BOTTOMRIGHT",-40,20)
        self.content=CreateFrame("Frame",nil,scroll); self.content:SetSize(width-72,1); scroll:SetScrollChild(self.content)
        FT:AutoHideScrollBar(scroll)
        self.rows={}
        self.none=FT:Label(frame,"No characters yet. Log in on each once.",12)
        self.none:SetPoint("TOPLEFT",24,-116); self.none:SetWidth(width-48); self.none:SetTextColor(.66,.59,.48)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("BagsCharacters",list)
