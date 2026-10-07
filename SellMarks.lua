local _,FT=...
-- Always-sell marks (off by default). Hover an item in your bags and press
-- the mark key you chose: every item of that kind is then sold when you open
-- a merchant, together with the grey items auto-sell takes. A small coin on
-- the item and a line in its tooltip show the mark.
--
-- The marks themselves are item data, not settings: they stay on the account
-- (for all characters, or one list per character) and are never part of a
-- profile or an export. Nothing is bound for you: without a mark key the
-- feature can't mark anything.
local Marks={}
local function readable(v) return (not issecretvalue or not issecretvalue(v)) and v~=nil end
local function keyText(key) return key and (GetBindingText and GetBindingText(key) or key) or "none" end
local PAGE=6

function Marks:Settings()
    -- Unset means off, like the other merchant switches (nothing is written
    -- until you change it, so opening the page never counts as a change).
    return FT.modules.System:Settings()
end
function Marks:On() return self:Settings().sellMarked==true end
function Marks:Key()
    local key=FT.db.sellMarkKey
    return type(key)=="string" and key~="" and key or nil
end
-- The list in use: one for the whole account, or this character's own.
function Marks:List()
    if self:Settings().sellMarksPerCharacter==true then
        local guid=UnitGUID and UnitGUID("player")
        if not readable(guid) or type(guid)~="string" then return {} end
        if type(FT.db.sellMarksChar)~="table" then FT.db.sellMarksChar={} end
        if type(FT.db.sellMarksChar[guid])~="table" then FT.db.sellMarksChar[guid]={} end
        return FT.db.sellMarksChar[guid]
    end
    if type(FT.db.sellMarks)~="table" then FT.db.sellMarks={} end
    return FT.db.sellMarks
end
function Marks:Has(itemID)
    if type(itemID)~="number" then return false end
    return self:List()[itemID]~=nil
end
function Marks:Count()
    local n=0; for _ in pairs(self:List()) do n=n+1 end
    return n
end
local function linkName(link)
    if not readable(link) or type(link)~="string" then return end
    return link:match("%[(.-)%]")
end
function Marks:Name(itemID)
    local stored=self:List()[itemID]
    if type(stored)=="string" then return stored end
    local name=C_Item and C_Item.GetItemNameByID and select(2,pcall(C_Item.GetItemNameByID,itemID))
    return readable(name) and type(name)=="string" and name or ("Item "..itemID)
end
function Marks:Set(itemID,name,on)
    if type(itemID)~="number" then return end
    self:List()[itemID]=on and (type(name)=="string" and name~="" and name or true) or nil
    self:Changed()
end
function Marks:Changed()
    self.sorted=nil
    self:QueuePaint()
    if self.frame and self.frame:IsShown() then self:Refresh() end
end

-- The bag item under the mouse: its item, name and whether a merchant buys it.
function Marks:Hovered()
    local focus
    if GetMouseFoci then
        local ok,foci=pcall(GetMouseFoci); focus=ok and type(foci)=="table" and foci[1] or nil
    elseif GetMouseFocus then focus=GetMouseFocus() end
    if type(focus)~="table" or type(focus.GetBagID)~="function" or type(focus.GetID)~="function" then return end
    local okBag,bag=pcall(focus.GetBagID,focus); local okSlot,slot=pcall(focus.GetID,focus)
    if not okBag or not okSlot or type(bag)~="number" or type(slot)~="number" then return end
    if not C_Container or not C_Container.GetContainerItemInfo then return end
    local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
    if not ok or type(info)~="table" or not readable(info.itemID) or type(info.itemID)~="number" then return end
    local name=(readable(info.itemName) and type(info.itemName)=="string" and info.itemName) or linkName(info.hyperlink)
    return info.itemID,name,readable(info.hasNoValue) and info.hasNoValue==true
end
-- The mark key was pressed.
function Marks:Press()
    if not self:On() then return end
    local itemID,name,worthless=self:Hovered()
    if not itemID then return end
    -- Silent: the coin on the item is the feedback. Only a refusal is said
    -- out loud, since nothing on the item would show why the key did nothing.
    if self:Has(itemID) then self:Set(itemID,name,false)
    elseif worthless then FT:Toast((name or "This item").." has no sell price, so a merchant won't buy it.",3)
    else self:Set(itemID,name,true) end
end

-- The key: a listener that hears keys without taking them, so nothing the
-- key normally does is lost and no key can ever get stuck. It only exists
-- while the feature is on and a key is chosen.
local listener=CreateFrame("Frame",nil,UIParent); listener:SetSize(1,1); listener:SetPoint("TOPLEFT"); listener:Hide()
listener:SetScript("OnKeyDown",function(_,key)
    local wanted=Marks.key
    if not wanted or not readable(key) or type(key)~="string" then return end
    if key:find("SHIFT",1,true) or key:find("CTRL",1,true) or key:find("ALT",1,true) then return end
    local combo=(IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
    if combo==wanted then Marks:Press() end
end)
function Marks:Listen()
    local want=self:On() and self:Key() or nil
    self.key=want
    if not want then
        if self.listening then self.listening=false; listener:Hide() end
        return
    end
    if self.listening then return end
    -- Passing keys on can only be set outside combat, and it must be set
    -- before the frame hears any key: otherwise wait until the fight is over.
    if InCombatLockdown() or not listener.SetPropagateKeyboardInput then self.listenAfterCombat=true; return end
    listener:SetPropagateKeyboardInput(true)
    listener:EnableKeyboard(true)
    listener:Show()
    self.listening=true
end

-- The coin on marked items in the bags.
local coins=setmetatable({},{__mode="k"})
local function coinFor(button)
    local coin=coins[button]
    if coin then return coin end
    coin=button:CreateTexture(nil,"OVERLAY",nil,6)
    local atlas=C_Texture and C_Texture.GetAtlasInfo and select(2,pcall(C_Texture.GetAtlasInfo,"bags-junkcoin"))
    if atlas then coin:SetAtlas("bags-junkcoin",true)
    else coin:SetTexture("Interface\\Icons\\INV_Misc_Coin_02"); coin:SetSize(14,14) end
    coin:SetPoint("TOPLEFT",1,0)
    coins[button]=coin
    return coin
end
function Marks:PaintFrame(frame,on)
    if not frame or type(frame.EnumerateValidItems)~="function" then return end
    if frame.IsShown and not frame:IsShown() then return end
    local list=on and self:List() or nil
    for _,button in frame:EnumerateValidItems() do
        local show=false
        if list and next(list) and button.GetBagID and button.GetID then
            local okBag,bag=pcall(button.GetBagID,button); local okSlot,slot=pcall(button.GetID,button)
            if okBag and okSlot and type(bag)=="number" and type(slot)=="number" then
                local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
                if ok and type(info)=="table" and readable(info.itemID) and list[info.itemID]~=nil then show=true end
            end
        end
        local coin=coins[button]
        if show and not coin then coin=coinFor(button) end
        if coin then coin:SetShown(show) end
    end
end
function Marks:Paint()
    if not C_Container or not C_Container.GetContainerItemInfo then return end
    local on=self:On()
    -- Off and never drawn: nothing to do.
    if not on and not self.painted then return end
    self.painted=on
    self:PaintFrame(ContainerFrameCombinedBags,on)
    for i=1,13 do self:PaintFrame(_G["ContainerFrame"..i],on) end
end
function Marks:QueuePaint() FT:Coalesce("sellMarks",function() self:Paint() end,0) end
function Marks:HookBags()
    if self.hooked then return end
    self.hooked=true
    local function watch(frame)
        if not frame or not frame.HookScript then return end
        frame:HookScript("OnShow",function() if Marks.painted or Marks:On() then Marks:QueuePaint() end end)
        if hooksecurefunc and type(frame.UpdateItems)=="function" then
            hooksecurefunc(frame,"UpdateItems",function() if Marks.painted or Marks:On() then Marks:QueuePaint() end end)
        end
    end
    watch(ContainerFrameCombinedBags)
    for i=1,13 do watch(_G["ContainerFrame"..i]) end
end
-- The tooltip line on marked items.
function Marks:HookTooltip()
    if self.tooltipHooked or not TooltipDataProcessor or not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Item then return end
    self.tooltipHooked=true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip,data)
        if tip~=GameTooltip or not Marks.active or type(data)~="table" then return end
        local id=data.id
        if readable(id) and type(id)=="number" and Marks:Has(id) then
            tip:AddLine("ForeverTools: sold at merchants",1,.82,0)
        end
    end)
end

local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_ENABLED" then
        if Marks.listenAfterCombat then Marks.listenAfterCombat=nil; Marks:Listen() end
    elseif event=="BAG_UPDATE_DELAYED" then Marks:QueuePaint() end
end)
function Marks:Apply()
    if not FT.dbReady then return end
    local on=self:On()
    self.active=on
    if on then
        self:HookBags(); self:HookTooltip()
        events:RegisterEvent("BAG_UPDATE_DELAYED"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else events:UnregisterAllEvents() end
    self:Listen()
    self:QueuePaint()
    self:Refresh()
    local system=FT.modules.System
    if system and system.Refresh then system:Refresh() end
end

-- Settings page (System > Merchant > Always-sell marks)
function Marks:Sorted()
    if self.sorted then return self.sorted end
    local list={}
    for id in pairs(self:List()) do if type(id)=="number" then list[#list+1]={id=id,name=self:Name(id)} end end
    table.sort(list,function(a,b) if a.name==b.name then return a.id<b.id end return a.name<b.name end)
    self.sorted=list
    return list
end
function Marks:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Sell marked items: "..(s.sellMarked==true and "On" or "Off")); FT:SetSelected(self.toggle,s.sellMarked==true)
    local key=self:Key()
    self.keyLabel:SetText("Mark key: "..(self.capturing and "press a key… (Escape cancels)" or (key and keyText(key) or "not chosen yet")))
    self.clearKey:SetEnabled(key~=nil); self.clearKey:SetAlpha(key and 1 or .45)
    self.scope.label:SetText("Marks are for: "..(s.sellMarksPerCharacter and "This character" or "All characters"))
    local list=self:Sorted()
    local pages=math.max(1,math.ceil(#list/PAGE))
    self.page=math.max(1,math.min(pages,self.page or 1))
    self.listTitle:SetText("Marked items ("..#list..")")
    for i,row in ipairs(self.rows) do
        local entry=list[(self.page-1)*PAGE+i]
        -- The X is a button of its own beside the row: shown with it, by hand.
        -- (A show/hide hook on the row misses rows hidden while the window is closed.)
        row.entry=entry; row:SetShown(entry~=nil); row.remove:SetShown(entry~=nil)
        if entry then
            row.label:SetText(entry.name)
            local icon=C_Item and C_Item.GetItemIconByID and select(2,pcall(C_Item.GetItemIconByID,entry.id))
            row.icon:SetTexture(readable(icon) and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    self.empty:SetShown(#list==0)
    self.pageLabel:SetText(#list>PAGE and (self.page.." / "..pages) or "")
    self.prev:SetShown(#list>PAGE); self.next:SetShown(#list>PAGE)
    local note
    if s.sellMarked~=true then note="Off: nothing is marked or sold."
    elseif not key then note="|cffff9e59Choose a mark key to start marking items.|r"
    else note='Hover an item in your bags and press "'..keyText(key)..'" to mark or unmark it.' end
    self.status:SetText(note)
end
function Marks:Capture(on)
    self.capturing=on
    self.capture:EnableKeyboard(on)
    self.capture:SetPropagateKeyboardInput(not on)
    self.capture:SetShown(on)
    self:Refresh()
end
-- A new key is confirmed, and you're told what it does now: the mark key
-- never takes a key over, so its usual action still happens too.
function Marks:Propose(key)
    if not key or InCombatLockdown() then return end
    local action=GetBindingAction and GetBindingAction(key)
    local name=action and action~="" and ((GetBindingName and GetBindingName(action)) or action) or nil
    local text='Use "'..keyText(key)..'" as the mark key?'
    if name then text=text.."\n\nIt is bound to "..name.." now. That still happens when you press it, so a free key or combination works best." end
    FT:Confirm(text,function() FT.db.sellMarkKey=key; self:Apply() end)
end
function Marks:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsSellMarks","Always-sell marks",520,572); self.frame=frame
        FT:BackTo(frame,"SystemMerchant")
        FT:PageInfo(frame,"Always-sell marks","Mark the items you always want to sell. Hover an item in your bags and press your mark key: it gets a small coin, and every item of that kind is sold when you open a merchant. Press the key on it again to unmark.\n\nAt most 12 items are sold per merchant visit (greys, white gear and marked items together), so every one can be bought back. The rest is sold next time.\n\nThe marks stay on your account. They are never part of a profile or an export.")
        self.toggle=FT:AccentButton(frame,"",472,34,"INV_Misc_Coin_01"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.sellMarked=not (s.sellMarked==true); self:Apply() end)
        FT:Tooltip(self.toggle,"Sell marked items","When you open a merchant, sell the items you have marked. Works with or without Auto-sell grey items. Items with no sell price are skipped.")
        self.keyLabel=FT:Label(frame,"",15); self.keyLabel:SetPoint("TOPLEFT",24,-114); self.keyLabel:SetWidth(472)
        local change=FT:QuietButton(frame,"Choose a key",230,32,"keybind"); change:SetPoint("TOPLEFT",24,-142)
        change:SetScript("OnClick",function() if not InCombatLockdown() then self:Capture(true) end end)
        FT:Tooltip(change,"Choose a key","Click, then press the key (with Shift, Ctrl or Alt if you like). You're asked to confirm. The key only marks while your mouse is on an item in your bags; everywhere else it does what it always did. Escape cancels.")
        self.clearKey=FT:QuietButton(frame,"Clear key",230,32,"reset"); self.clearKey:SetPoint("TOPLEFT",266,-142)
        self.clearKey:SetScript("OnClick",function() FT.db.sellMarkKey=nil; self:Apply() end)
        FT:Tooltip(self.clearKey,"Clear key","Remove the mark key. Marked items are still sold; you just can't mark new ones until you choose a key again.")
        self.scope=FT:QuietButton(frame,"",472,32,"character"); self.scope:SetPoint("TOPLEFT",24,-182)
        self.scope:SetScript("OnClick",function() local s=self:Settings(); s.sellMarksPerCharacter=not (s.sellMarksPerCharacter==true); self.page=1; self:Changed(); self:Apply() end)
        FT:Tooltip(self.scope,"Who the marks are for","All characters: one list for your whole account. This character: each character has its own list. Switching deletes nothing. Click to switch.")
        self.listTitle=FT:Label(frame,"",16,true); self.listTitle:SetPoint("TOPLEFT",24,-232); FT:SectionHeading(self.listTitle,"INV_Misc_Coin_02",300)
        self.rows={}
        for i=1,PAGE do
            local row=FT:QuietButton(frame,"",436,32,"generic"); row:SetPoint("TOPLEFT",24,-262-(i-1)*36)
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row.icon,"RIGHT",8,0); row.label:SetPoint("RIGHT",-8,0); row.label:SetJustifyH("LEFT")
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row.remove=FT:QuietButton(frame,"",32,32); row.remove:SetPoint("LEFT",row,"RIGHT",4,0)
            row.remove.glyph=row.remove:CreateTexture(nil,"ARTWORK"); row.remove.glyph:SetSize(14,14); row.remove.glyph:SetPoint("CENTER")
            row.remove.glyph:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            row.remove:SetScript("OnClick",function() if row.entry then self:Set(row.entry.id,nil,false) end end)
            FT:Tooltip(row.remove,"Remove mark","Stop selling this item automatically.")
            row.remove:Hide()
            row:HookScript("OnEnter",function()
                if not row.entry or not GameTooltip.SetItemByID then return end
                GameTooltip:SetOwner(row,"ANCHOR_RIGHT"); pcall(GameTooltip.SetItemByID,GameTooltip,row.entry.id); GameTooltip:Show()
            end)
            row:HookScript("OnLeave",function() GameTooltip:Hide() end)
            self.rows[i]=row
        end
        self.empty=FT:Label(frame,"Nothing marked yet.",13); self.empty:SetPoint("TOPLEFT",24,-266); self.empty:SetTextColor(.66,.59,.48)
        self.prev=FT:QuietButton(frame,"Previous",110,26,"reset"); self.prev:SetPoint("TOPLEFT",24,-482)
        self.next=FT:QuietButton(frame,"Next",110,26,"add"); self.next:SetPoint("TOPLEFT",386,-482)
        self.prev:SetScript("OnClick",function() self.page=(self.page or 1)-1; self:Refresh() end)
        self.next:SetScript("OnClick",function() self.page=(self.page or 1)+1; self:Refresh() end)
        self.pageLabel=FT:Label(frame,"",12); self.pageLabel:SetPoint("TOP",0,-488)
        self.status=FT:Label(frame,"",13); self.status:SetPoint("TOPLEFT",24,-522); self.status:SetWidth(472)
        -- Key capture: the next key pressed is proposed as the mark key.
        local capture=CreateFrame("Frame",nil,frame); capture:SetAllPoints(frame); capture:EnableKeyboard(false); capture:Hide()
        capture:SetScript("OnKeyDown",function(_,key)
            if not self.capturing then return end
            if key=="ESCAPE" then self:Capture(false); return end
            if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
            local combo=(IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
            self:Capture(false); self:Propose(combo)
        end)
        self.capture=capture
        frame:HookScript("OnHide",function() if self.capturing then self:Capture(false) end end)
    end
    self.sorted=nil
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("SellMarks",Marks)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Marks:Apply() end end)
