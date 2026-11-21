local _,FT=...
-- Trade log (on by default): every completed trade with another player, with
-- the time, who it was with, where, the items and gold each side gave, and
-- enchants put on the "Will not be traded" slot. Nothing shows by itself:
-- open the log from the small button under the trade window, the Trade log
-- page (System) or /ft trades. Cancelled trades are not kept.
-- Only listens to trade events while a trade window is open; reads the two
-- sides at most once per frame while something changes.
local Log={}
local ICON="INV_Misc_Note_02"
local KEEP=500
local PAGE=7
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function plain(v) if type(v)=="string" and not secret(v) and v~="" then return v end end
local function count(v) if type(v)=="number" and not secret(v) and v>0 then return v end end

function Log:Settings()
    local s=FT.db.tradeLog
    if type(s)~="table" then s={}; FT.db.tradeLog=s end
    if type(s.enabled)~="boolean" then s.enabled=true end
    if type(s.button)~="boolean" then s.button=true end
    return s
end
-- Account data, not part of profiles or exports.
function Log:Store()
    local st=FT.db.tradeStore
    if type(st)~="table" then st={}; FT.db.tradeStore=st end
    if type(st.entries)~="table" then st.entries={} end
    return st.entries
end
function Log:On() return FT.dbReady and self:Settings().enabled==true end

-- One side of the trade: up to six items, then slot 7 (enchants only).
local function side(info,link,enchantAt)
    local items={}
    for i=1,6 do
        local ok,name,texture,n=pcall(info,i)
        name=ok and plain(name)
        if name then
            local okL,l=pcall(link,i)
            items[#items+1]={name=name,count=count(n) or 1,link=okL and plain(l) or nil,icon=(type(texture)=="number" or plain(texture)) and texture or nil}
        end
    end
    local r={pcall(info,7)}
    local enchant=r[1] and plain(r[enchantAt+1])
    return items,enchant,r[1] and plain(r[2]) or nil
end
function Log:Read()
    local p=self.pending; if not p then return end
    if GetTradePlayerItemInfo and GetTradePlayerItemLink then
        p.gave,p.myEnchant,p.myKept=side(GetTradePlayerItemInfo,GetTradePlayerItemLink,5)
    end
    if GetTradeTargetItemInfo and GetTradeTargetItemLink then
        p.got,p.theirEnchant,p.theirKept=side(GetTradeTargetItemInfo,GetTradeTargetItemLink,6)
    end
    -- Slot 7 enchants: what the other player puts on your item (your side)
    -- and what you put on theirs (their side).
    local ok,m=pcall(GetPlayerTradeMoney or function() end); p.gaveMoney=ok and count(m) or 0
    ok,m=pcall(GetTargetTradeMoney or function() end); p.gotMoney=ok and count(m) or 0
end
function Log:Begin()
    local name,realm=UnitName("NPC")
    local _,class=UnitClass("NPC")
    name=plain(name) or plain(_G.TradeFrameRecipientNameText and _G.TradeFrameRecipientNameText:GetText()) or "?"
    realm=plain(realm)
    local zone=GetRealZoneText and plain(GetRealZoneText())
    local me=plain(UnitName("player"))
    self.pending={with=realm and (name.."-"..realm) or name,class=plain(class),zone=zone,me=me}
    self:Read()
end
-- What was on the table when someone pressed Trade: any change after that
-- takes both accepts back, so this is what was traded. The game can empty
-- the slots as the trade goes through, before the window closes.
local FIELDS={"gave","got","gaveMoney","gotMoney","myEnchant","theirEnchant","myKept","theirKept"}
function Log:Agreed()
    local p=self.pending; if not p then return end
    self:Read()
    p.agreed={}; for _,k in ipairs(FIELDS) do p.agreed[k]=p[k] end
end
function Log:Finish()
    local p=self.pending; self.pending=nil
    if not p then return end
    if p.agreed then for _,k in ipairs(FIELDS) do p[k]=p.agreed[k] end end
    p.agreed=nil
    local any=#(p.gave or {})>0 or #(p.got or {})>0 or (p.gaveMoney or 0)>0 or (p.gotMoney or 0)>0 or p.theirEnchant or p.myEnchant
    if not any then return end
    p.t=time()
    local list=self:Store()
    table.insert(list,1,p)
    for i=#list,KEEP+1,-1 do list[i]=nil end
    self.page=1
    if self.frame and self.frame:IsShown() then self:Refresh() end
end

-- Events: the trade window's own; the rest only while it is open.
local events=CreateFrame("Frame")
local during={"TRADE_PLAYER_ITEM_CHANGED","TRADE_TARGET_ITEM_CHANGED","TRADE_MONEY_CHANGED","TRADE_ACCEPT_UPDATE","PLAYER_TRADE_MONEY","UI_INFO_MESSAGE","TRADE_CLOSED"}
local function readNow() Log:Read() end
events:SetScript("OnEvent",function(_,event,a,b)
    if not FT.dbReady then return end
    if event=="TRADE_SHOW" then
        if not Log:On() then return end
        for _,e in ipairs(during) do pcall(events.RegisterEvent,events,e) end
        Log:Begin(); Log:Button()
    elseif event=="UI_INFO_MESSAGE" then
        -- The game says the trade went through (the message can come just
        -- after the window closes).
        local msg=plain(b) or plain(a)
        if msg and msg==_G.ERR_TRADE_COMPLETE then Log:Finish() end
    elseif event=="TRADE_CLOSED" then
        local p=Log.pending
        C_Timer.After(3,function()
            if Log.pending==p then Log.pending=nil end
            if not Log.pending then for _,e in ipairs(during) do pcall(events.UnregisterEvent,events,e) end end
        end)
    elseif event=="TRADE_ACCEPT_UPDATE" then
        local mine,theirs=count(a),count(b)
        if mine or theirs then Log:Agreed() elseif Log.pending then Log.pending.agreed=nil; Log:Read() end
    else
        -- Items and gold: read once, after this frame's changes.
        FT:Coalesce("tradeLogRead",readNow,0)
    end
end)
function Log:Apply()
    if not FT.dbReady then return end
    if self:On() then events:RegisterEvent("TRADE_SHOW") else events:UnregisterAllEvents(); self.pending=nil end
    self:Button()
    if self.frame and self.frame:IsShown() then self:Refresh() end
end
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Log:Apply() end end)

-- The small "Trade log" button just under the trade window.
function Log:Button()
    local trade=_G.TradeFrame
    if not trade then return end
    if not self.tradeButton then
        if not (self:On() and self:Settings().button) then return end
        local b=FT:QuietButton(trade,"Trade log",110,24,"generic")
        b:SetPoint("TOPLEFT",trade,"BOTTOMLEFT",0,-2)
        b:SetScript("OnClick",function() FT:OpenModule("TradeLog") end)
        FT:Tooltip(b,"Trade log","Your completed trades: items, gold and when.")
        self.tradeButton=b
    end
    self.tradeButton:SetShown(self:On() and self:Settings().button==true)
end

-- Text helpers.
local function money(c)
    c=c or 0
    local g,s,cp=math.floor(c/10000),math.floor(c/100)%100,c%100
    local out={}
    if g>0 then out[#out+1]=g.."g" end
    if s>0 then out[#out+1]=s.."s" end
    if cp>0 or #out==0 then out[#out+1]=cp.."c" end
    return table.concat(out," ")
end
local function moneyText(c) if GetCoinTextureString then local ok,t=pcall(GetCoinTextureString,c); if ok and type(t)=="string" then return t end end return money(c) end
local function part(items,copper)
    local bits={}
    local n=0; for _,it in ipairs(items or {}) do n=n+(it.count or 1) end
    if #(items or {})==1 then local it=items[1]; bits[1]=it.name..((it.count or 1)>1 and (" x"..it.count) or "")
    elseif #(items or {})>1 then bits[1]=n.." items" end
    if (copper or 0)>0 then bits[#bits+1]=money(copper) end
    return #bits>0 and table.concat(bits,", ") or nil
end
local function classColor(class)
    local c=class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    return c and string.format("|cff%02x%02x%02x",c.r*255,c.g*255,c.b*255) or "|cffffffff"
end
function Log:Summary(e)
    local gave,got=part(e.gave,e.gaveMoney),part(e.got,e.gotMoney)
    local bits={}
    if gave then bits[#bits+1]="|cffff9a7aGave|r "..gave end
    if got then bits[#bits+1]="|cff9ade7aGot|r "..got end
    if #bits==0 and (e.myEnchant or e.theirEnchant) then bits[1]="Enchant" end
    return table.concat(bits,"  ·  ")
end
function Log:Matches(e,q)
    if q=="" then return true end
    local function has(v) return type(v)=="string" and v:lower():find(q,1,true) end
    if has(e.with) or has(e.zone) or has(e.me) or has(e.myEnchant) or has(e.theirEnchant) then return true end
    for _,list in ipairs({e.gave or {},e.got or {}}) do for _,it in ipairs(list) do if has(it.name) then return true end end end
    return false
end
function Log:Filtered()
    local q=(self.search and self.search:GetText() or ""):lower():match("^%s*(.-)%s*$")
    local out={}
    for _,e in ipairs(self:Store()) do if type(e)=="table" and self:Matches(e,q) then out[#out+1]=e end end
    return out,q
end
function Log:EntryTooltip(row,e)
    GameTooltip:SetOwner(row,"ANCHOR_RIGHT")
    GameTooltip:SetText("Trade with "..classColor(e.class)..tostring(e.with).."|r",1,.82,0)
    GameTooltip:AddLine(date("%A %d %B %Y, %H:%M",e.t or 0)..(e.zone and (" · "..e.zone) or ""),.8,.8,.8)
    if e.me then GameTooltip:AddLine("Your character: "..e.me,.8,.8,.8) end
    local function list(title,items,copper)
        if #(items or {})==0 and (copper or 0)==0 then return end
        GameTooltip:AddLine(" "); GameTooltip:AddLine(title,1,.82,0)
        for _,it in ipairs(items or {}) do GameTooltip:AddLine((it.link or it.name)..((it.count or 1)>1 and (" |cffffffffx"..it.count.."|r") or ""),1,1,1) end
        if (copper or 0)>0 then GameTooltip:AddLine(moneyText(copper),1,1,1) end
    end
    list("You gave",e.gave,e.gaveMoney)
    list("You got",e.got,e.gotMoney)
    if e.myEnchant then GameTooltip:AddLine(" "); GameTooltip:AddLine("Enchant on your "..(e.myKept or "item")..": "..e.myEnchant,.6,.8,1,true) end
    if e.theirEnchant then GameTooltip:AddLine(" "); GameTooltip:AddLine("You enchanted their "..(e.theirKept or "item")..": "..e.theirEnchant,.6,.8,1,true) end
    GameTooltip:AddLine(" "); GameTooltip:AddLine("Shift-click: link the items in chat.",.5,.5,.5)
    GameTooltip:Show()
end
function Log:LinkInChat(e)
    local bits={}
    for _,it in ipairs(e.got or {}) do bits[#bits+1]=(it.link or it.name)..((it.count or 1)>1 and ("x"..it.count) or "") end
    for _,it in ipairs(e.gave or {}) do bits[#bits+1]=(it.link or it.name)..((it.count or 1)>1 and ("x"..it.count) or "") end
    if #bits==0 then return end
    local text=table.concat(bits," ")
    if ChatEdit_InsertLink and ChatEdit_InsertLink(text) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(text) end
end

-- The page (System > Trade log).
function Log:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTradeLog","Trade log",520,572); self.frame=frame
        FT:BackTo(frame,"SystemMerchant")
        FT:PageInfo(frame,"Trade log","Every trade you finish with another player: when, who, where, and the items and gold each of you gave. Cancelled trades are not kept.\n\nOpen it from the button under the trade window, here, or with /ft trades. The newest "..KEEP.." trades on this account are kept.")
        self.toggle=FT:AccentButton(frame,"",472,34,ICON); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Trade log","Keep a log of your completed trades. It never shows by itself.")
        self.buttonToggle=FT:QuietButton(frame,"",230,32,"generic"); self.buttonToggle:SetPoint("TOPLEFT",24,-104)
        self.buttonToggle:SetScript("OnClick",function() local s=self:Settings(); s.button=not s.button; if s.button then s.enabled=true end; self:Apply() end)
        FT:Tooltip(self.buttonToggle,"Button on trade window","A small Trade log button just under the trade window.")
        local clear=FT:QuietButton(frame,"Clear log",230,32,"reset"); clear:SetPoint("TOPLEFT",266,-104)
        clear:SetScript("OnClick",function()
            FT:Confirm("Delete every trade in the log?",function() wipe(self:Store()); self.page=1; self:Refresh() end)
        end)
        FT:Tooltip(clear,"Clear log","Delete every trade in the log. Asks first.")
        local search=CreateFrame("EditBox",nil,frame,"InputBoxTemplate"); search:SetSize(466,28); search:SetPoint("TOPLEFT",30,-146)
        search:SetFont(FT.bodyFont,14,""); search:SetAutoFocus(false); self.search=search
        search.hint=FT:Label(search,"Search names, items or places",13); search.hint:SetPoint("LEFT",4,0); search.hint:SetTextColor(.5,.47,.4)
        search:SetScript("OnTextChanged",function(box) box.hint:SetShown(box:GetText()=="" and not box:HasFocus()); self.page=1; self:Refresh() end)
        search:SetScript("OnEditFocusGained",function(box) box.hint:Hide() end)
        search:SetScript("OnEditFocusLost",function(box) box.hint:SetShown(box:GetText()=="") end)
        search:SetScript("OnEscapePressed",function(box) box:SetText(""); box:ClearFocus() end)
        search:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
        self.listTitle=FT:Label(frame,"",16,true); self.listTitle:SetPoint("TOPLEFT",24,-190); FT:SectionHeading(self.listTitle,ICON,300)
        self.rows={}
        for i=1,PAGE do
            local row=FT:QuietButton(frame,"",472,32,"generic"); row:SetPoint("TOPLEFT",24,-220-(i-1)*36)
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row.icon or row,row.icon and "RIGHT" or "LEFT",8,0); row.label:SetPoint("RIGHT",-8,0); row.label:SetJustifyH("LEFT")
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row:SetScript("OnClick",function() if row.entry and IsShiftKeyDown() then self:LinkInChat(row.entry) end end)
            row:HookScript("OnEnter",function() if row.entry then self:EntryTooltip(row,row.entry) end end)
            row:HookScript("OnLeave",function() GameTooltip:Hide() end)
            self.rows[i]=row
        end
        self.empty=FT:Label(frame,"",13); self.empty:SetPoint("TOPLEFT",24,-224); self.empty:SetWidth(472); self.empty:SetTextColor(.66,.59,.48)
        self.prev=FT:QuietButton(frame,"Previous",110,26,"reset"); self.prev:SetPoint("TOPLEFT",24,-478)
        self.next=FT:QuietButton(frame,"Next",110,26,"add"); self.next:SetPoint("TOPLEFT",386,-478)
        self.prev:SetScript("OnClick",function() self.page=(self.page or 1)-1; self:Refresh() end)
        self.next:SetScript("OnClick",function() self.page=(self.page or 1)+1; self:Refresh() end)
        self.pageLabel=FT:Label(frame,"",12); self.pageLabel:SetPoint("TOP",0,-484)
        local note=FT:Label(frame,"Hover a trade for every item. Shift-click it to link the items in chat.",12)
        note:SetPoint("TOPLEFT",24,-522); note:SetWidth(472); note:SetTextColor(.66,.59,.48)
    end
    self.frame:Show(); self:Refresh()
end
function Log:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Trade log: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.buttonToggle.label:SetText("Button on trade window: "..(s.button and "On" or "Off")); FT:SetSelected(self.buttonToggle,s.button and s.enabled)
    self.buttonToggle:SetAlpha(s.enabled and 1 or .5)
    local list,q=self:Filtered()
    local pages=math.max(1,math.ceil(#list/PAGE))
    self.page=math.max(1,math.min(self.page or 1,pages))
    self.listTitle:SetText(q~="" and ("Trades found ("..#list..")") or ("Trades ("..#list..")"))
    for i,row in ipairs(self.rows) do
        local e=list[(self.page-1)*PAGE+i]
        row.entry=e
        if e then
            row.label:SetText("|cffa89a80"..date("%b %d %H:%M",e.t or 0).."|r  "..classColor(e.class)..tostring(e.with):gsub("%-.*$","").."|r  "..self:Summary(e))
            local first=(e.got and e.got[1]) or (e.gave and e.gave[1])
            if row.icon then
                if first and first.icon then row.icon:SetTexture(first.icon) else row.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01") end
            end
            row:Show()
        else row:Hide() end
    end
    self.empty:SetText(#list>0 and "" or (q~="" and "No trades match." or (s.enabled and "No trades yet. Finished trades show up here." or "The trade log is off.")))
    self.prev:SetShown(self.page>1); self.next:SetShown(self.page<pages)
    self.pageLabel:SetText(pages>1 and ("Page "..self.page.." of "..pages) or "")
end
FT:RegisterModule("TradeLog",Log)
FT.TradeLog=Log
