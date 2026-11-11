local _,FT=...
-- Item locks (off by default), next to always-sell marks and set up the same
-- way. Lock an item: hover it in your bags and press your lock key (if you
-- chose one), or Alt + right-click it. Again to unlock. A locked item:
--   * can't be mailed: it is taken off the letter at once,
--   * can't be traded: it is taken out of the trade window,
--   * can't be deleted: the delete question closes and the item goes back,
--   * is bought back at once if it is sold to a merchant (the game gives no
--     safe way to stop the sale itself), and ForeverTools' own selling
--     (auto-sell, always-sell marks) never sells it.
-- A padlock shows on the item in your bags and a line in its tooltip.
-- Locks are by item and kept for the whole account (not in profiles or exports).
-- Settings: System > Item locks (/ft lock).
local Lock={}
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
local function idFromLink(link)
    if not readable(link) or type(link)~="string" then return end
    local id=link:match("item:(%d+)"); return id and tonumber(id)
end
local PAGE=6
local function keyText(key) return key and (GetBindingText and GetBindingText(key) or key) or "none" end
local function tell(msg) print("|cffffd100ForeverTools:|r "..msg) end
function Lock:Settings() return FT.modules.System:Settings() end
function Lock:On() return FT.dbReady and self:Settings().itemLock==true end
function Lock:List()
    if type(FT.db.itemLocks)~="table" then FT.db.itemLocks={} end
    return FT.db.itemLocks
end
function Lock:Has(itemID) return type(itemID)=="number" and self:List()[itemID]~=nil end
function Lock:HasLink(link) local id=idFromLink(link); return id~=nil and self:Has(id) end
function Lock:Count() local n=0; for _ in pairs(self:List()) do n=n+1 end; return n end
local function nameOf(link,id)
    local n=readable(link) and type(link)=="string" and link:match("%[(.-)%]")
    return link or n or ("item "..tostring(id))
end
function Lock:Key()
    local key=FT.db.itemLockKey
    return type(key)=="string" and key~="" and key or nil
end
function Lock:Name(itemID)
    local name=C_Item and C_Item.GetItemNameByID and select(2,pcall(C_Item.GetItemNameByID,itemID))
    return readable(name) and type(name)=="string" and name or ("Item "..itemID)
end
function Lock:Set(itemID,on,link)
    if type(itemID)~="number" then return end
    self:List()[itemID]=on and true or nil
    -- A locked item is never sold: its always-sell mark goes.
    local marks=FT.modules.SellMarks
    if on and marks and marks.Has and marks:Has(itemID) then marks:Set(itemID,nil,false) end
    self.sorted=nil
    if self.frame and self.frame:IsShown() then self:Refresh() end
    tell(nameOf(link,itemID)..(on and " |cffffd100locked|r: it can't be sold, mailed, traded or deleted." or " unlocked."))
    if PlaySound and SOUNDKIT then pcall(PlaySound,on and (SOUNDKIT.UI_BAG_SORTING_01 or 856) or (SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 857)) end
    self:QueuePaint()
end
-- The bag slot's item.
local function slotItem(button)
    if not button or type(button.GetBagID)~="function" or type(button.GetID)~="function" then return end
    local okBag,bag=pcall(button.GetBagID,button); local okSlot,slot=pcall(button.GetID,button)
    if not okBag or not okSlot or type(bag)~="number" or type(slot)~="number" then return end
    if not C_Container or not C_Container.GetContainerItemInfo then return end
    local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
    if not ok or type(info)~="table" or not readable(info.itemID) or type(info.itemID)~="number" then return end
    return info.itemID,readable(info.hyperlink) and info.hyperlink or nil
end
-- The lock key: pressed while hovering a bag item.
function Lock:Press()
    if not self:On() then return end
    local focus
    if GetMouseFoci then local ok,foci=pcall(GetMouseFoci); focus=ok and type(foci)=="table" and foci[1] or nil
    elseif GetMouseFocus then focus=GetMouseFocus() end
    local id,link=slotItem(focus); if not id then return end
    self:Set(id,not self:Has(id),link)
end
-- A listener that hears keys without taking them (as the mark key does).
local listener=CreateFrame("Frame",nil,UIParent); listener:SetSize(1,1); listener:SetPoint("TOPLEFT"); listener:Hide()
local function combo(key) return (IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key end
listener:SetScript("OnKeyDown",function(_,key)
    local wanted=Lock.key
    if not wanted or not readable(key) or type(key)~="string" then return end
    if key:find("SHIFT",1,true) or key:find("CTRL",1,true) or key:find("ALT",1,true) then return end
    if combo(key)==wanted then Lock:Press() end
end)
function Lock:Listen()
    local want=self:On() and self:Key() or nil
    self.key=want
    if not want then
        if self.listening then self.listening=false; listener:Hide() end
        return
    end
    if self.listening then return end
    if InCombatLockdown() or not listener.SetPropagateKeyboardInput then self.listenAfterCombat=true; return end
    listener:SetPropagateKeyboardInput(true); listener:EnableKeyboard(true); listener:Show()
    self.listening=true
end
-- Alt + right-click on a bag item. A modified click never uses or sells the
-- item, so this only adds a lock and changes nothing the click did before.
function Lock:Clicked(button,mouse)
    if mouse~="RightButton" or not self:On() then return end
    if not (IsAltKeyDown and IsAltKeyDown()) or (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then return end
    local id,link=slotItem(button); if not id then return end
    self:Set(id,not self:Has(id),link)
    if GameTooltip:IsOwned(button) and button:GetScript("OnEnter") then pcall(button:GetScript("OnEnter"),button) end
end
-- The padlock on locked items in the bags.
local locks=setmetatable({},{__mode="k"})
local hooked=setmetatable({},{__mode="k"})
local function padlock(button)
    local t=locks[button]; if t then return t end
    t=button:CreateTexture(nil,"OVERLAY",nil,7)
    t:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon"); t:SetSize(15,15)
    t:SetPoint("BOTTOMLEFT",1,1)
    locks[button]=t
    return t
end
function Lock:PaintFrame(frame,on)
    if not frame or type(frame.EnumerateValidItems)~="function" then return end
    if frame.IsShown and not frame:IsShown() then return end
    local list=self:List()
    for _,button in frame:EnumerateValidItems() do
        if on and not hooked[button] and button.HookScript then
            hooked[button]=true
            button:HookScript("OnClick",function(b,mouse) Lock:Clicked(b,mouse) end)
        end
        local id=on and next(list) and slotItem(button)
        local show=id~=nil and id~=false and list[id]~=nil
        local t=locks[button]
        if show and not t then t=padlock(button) end
        if t then t:SetShown(show) end
    end
end
function Lock:Paint()
    local on=self:On()
    if not on and not self.painted then return end
    self.painted=on
    self:PaintFrame(ContainerFrameCombinedBags,on)
    for i=1,13 do self:PaintFrame(_G["ContainerFrame"..i],on) end
end
function Lock:QueuePaint() FT:Coalesce("itemLock",function() self:Paint() end,0) end
function Lock:HookBags()
    if self.bagsHooked then return end
    self.bagsHooked=true
    local function watch(frame)
        if not frame or not frame.HookScript then return end
        frame:HookScript("OnShow",function() if Lock.painted or Lock:On() then Lock:QueuePaint() end end)
        if hooksecurefunc and type(frame.UpdateItems)=="function" then
            hooksecurefunc(frame,"UpdateItems",function() if Lock.painted or Lock:On() then Lock:QueuePaint() end end)
        end
    end
    watch(ContainerFrameCombinedBags)
    for i=1,13 do watch(_G["ContainerFrame"..i]) end
end
function Lock:HookTooltip()
    if self.tooltipHooked or not TooltipDataProcessor or not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Item then return end
    self.tooltipHooked=true
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip,data)
        if tip~=GameTooltip or not Lock:On() or type(data)~="table" then return end
        if readable(data.id) and Lock:Has(data.id) then tip:AddLine("|TInterface\\PetBattles\\PetBattle-LockIcon:0|t Locked (Alt + right-click to unlock)",1,.82,0) end
    end)
end
-- Mail: a locked item is taken off the letter.
function Lock:CheckMail()
    if not GetSendMailItemLink or not ClickSendMailItemButton then return end
    for i=1,(ATTACHMENTS_MAX_SEND or 12) do
        local ok,link=pcall(GetSendMailItemLink,i)
        if ok and self:HasLink(link) then
            pcall(ClickSendMailItemButton,i,true)
            if ClearCursor then ClearCursor() end
            FT:Toast(nameOf(link).." is locked: it can't be mailed. Alt + right-click it in your bags to unlock.",4)
        end
    end
end
-- Trade: a locked item is taken out of the trade window.
function Lock:CheckTrade(slot)
    if not GetTradePlayerItemLink or not ClickTradeButton then return end
    for i=slot or 1,slot or (MAX_TRADABLE_ITEMS or 6) do
        local ok,link=pcall(GetTradePlayerItemLink,i)
        if ok and self:HasLink(link) then
            if not (GetCursorInfo and GetCursorInfo()) then pcall(ClickTradeButton,i); if ClearCursor then ClearCursor() end end
            FT:Toast(nameOf(link).." is locked: it can't be traded. Alt + right-click it in your bags to unlock.",4)
        end
    end
end
-- Delete: the question closes and the item goes back to the bag.
local DELETE={DELETE_ITEM=true,DELETE_GOOD_ITEM=true,DELETE_QUEST_ITEM=true,DELETE_GOOD_QUEST_ITEM=true}
function Lock:CursorLocked()
    if not GetCursorInfo then return end
    local kind,id,link=GetCursorInfo()
    if kind=="item" and readable(id) and self:Has(id) then return link or id end
end
function Lock:StopDelete()
    local item=self:CursorLocked(); if not item then return end
    if StaticPopup_Hide then for which in pairs(DELETE) do pcall(StaticPopup_Hide,which) end end
    if ClearCursor then ClearCursor() end
    FT:Toast(nameOf(type(item)=="string" and item or nil,item).." is locked: it can't be deleted. Alt + right-click it in your bags to unlock.",4)
end
-- Selling: a locked item sold to a merchant is bought back at once.
function Lock:BuybackList()
    local out={}
    for i=1,(GetNumBuybackItems and GetNumBuybackItems() or 0) do
        local ok,link=pcall(GetBuybackItemLink,i); out[i]=ok and readable(link) and link or ""
    end
    return out
end
function Lock:CheckBuyback()
    if not GetNumBuybackItems or not BuybackItem then return end
    local list=self:BuybackList()
    local before=self.buyback or {}
    -- The newest sale is last; it is new when the list grew or its last item changed.
    local n=#list
    if n>0 and (n>#before or list[n]~=before[#before]) and self:HasLink(list[n]) then
        pcall(BuybackItem,n)
        FT:Toast(nameOf(list[n]).." is locked: bought back. Alt + right-click it in your bags to unlock.",4)
        list=self:BuybackList()
    end
    self.buyback=list
end
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event,a)
    if not Lock:On() then return end
    if event=="BAG_UPDATE_DELAYED" then Lock:QueuePaint()
    elseif event=="MAIL_SEND_INFO_UPDATE" then Lock:CheckMail()
    elseif event=="TRADE_PLAYER_ITEM_CHANGED" then Lock:CheckTrade(type(a)=="number" and a or nil)
    elseif event=="DELETE_ITEM_CONFIRM" then C_Timer.After(0,function() Lock:StopDelete() end)
    elseif event=="MERCHANT_SHOW" then Lock.buyback=Lock:BuybackList()
    elseif event=="MERCHANT_UPDATE" then Lock:CheckBuyback()
    elseif event=="PLAYER_REGEN_ENABLED" then if Lock.listenAfterCombat then Lock.listenAfterCombat=nil; Lock:Listen() end end
end)
function Lock:Apply()
    if not FT.dbReady then return end
    if self:On() then
        self:HookBags(); self:HookTooltip()
        for _,e in ipairs({"BAG_UPDATE_DELAYED","MAIL_SEND_INFO_UPDATE","TRADE_PLAYER_ITEM_CHANGED","DELETE_ITEM_CONFIRM","MERCHANT_SHOW","MERCHANT_UPDATE","PLAYER_REGEN_ENABLED"}) do pcall(events.RegisterEvent,events,e) end
        if hooksecurefunc and StaticPopup_Show and not self.popupHooked then
            self.popupHooked=true
            hooksecurefunc("StaticPopup_Show",function(which) if Lock:On() and DELETE[which] then Lock:StopDelete() end end)
        end
    else events:UnregisterAllEvents() end
    self:Listen()
    self:QueuePaint()
    self:Refresh()
end
-- Settings page (System > Item locks), laid out as Always-sell marks.
function Lock:Sorted()
    if self.sorted then return self.sorted end
    local list={}
    for id in pairs(self:List()) do if type(id)=="number" then list[#list+1]={id=id,name=self:Name(id)} end end
    table.sort(list,function(a,b) if a.name==b.name then return a.id<b.id end return a.name<b.name end)
    self.sorted=list
    return list
end
function Lock:Refresh()
    if not self.frame then return end
    local on=self:On()
    self.toggle.label:SetText("Item locks: "..(on and "On" or "Off")); FT:SetSelected(self.toggle,on)
    local key=self:Key()
    self.keyLabel:SetText("Lock key: "..(self.capturing and "press a key… (Escape cancels)" or (key and keyText(key) or "not chosen (Alt + right-click works)")))
    self.clearKey:SetEnabled(key~=nil); self.clearKey:SetAlpha(key and 1 or .45)
    local list=self:Sorted()
    local pages=math.max(1,math.ceil(#list/PAGE))
    self.page=math.max(1,math.min(pages,self.page or 1))
    self.listTitle:SetText("Locked items ("..#list..")")
    for i,row in ipairs(self.rows) do
        local entry=list[(self.page-1)*PAGE+i]
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
    if not on then note="Off: locks are kept but nothing is protected."
    elseif key then note='Hover an item in your bags and press "'..keyText(key)..'" (or Alt + right-click it) to lock or unlock it.'
    else note="Alt + right-click an item in your bags to lock or unlock it, or choose a key." end
    self.status:SetText(note)
end
function Lock:Capture(on)
    self.capturing=on
    self.capture:EnableKeyboard(on); self.capture:SetPropagateKeyboardInput(not on); self.capture:SetShown(on)
    self:Refresh()
end
function Lock:Propose(key)
    if not key or InCombatLockdown() then return end
    if key==FT.db.sellMarkKey then FT:Toast('"'..keyText(key)..'" is your always-sell mark key. Choose another key.',4); return end
    local action=GetBindingAction and GetBindingAction(key)
    local name=action and action~="" and ((GetBindingName and GetBindingName(action)) or action) or nil
    local text='Use "'..keyText(key)..'" as the lock key?'
    if name then text=text.."\n\nIt is bound to "..name.." now. A free key works best." end
    FT:Confirm(text,function() FT.db.itemLockKey=key; self:Apply() end)
end
function Lock:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsItemLock","Item locks",520,572); self.frame=frame
        FT:BackTo(frame,"SystemMerchant")
        FT:PageInfo(frame,"Item locks","Lock items you never want to lose. A locked item can't be mailed, traded or deleted, and is bought back at once if you sell it. Auto-sell and always-sell marks never sell it.\n\nHover an item in your bags and press your lock key, or Alt + right-click it; again to unlock. Locks stay on your account.")
        self.toggle=FT:AccentButton(frame,"",472,34,"INV_Misc_Key_03"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.itemLock=not (s.itemLock==true); self:Apply() end)
        FT:Tooltip(self.toggle,"Item locks","Protect locked items from selling, mail, trade and delete.")
        self.keyLabel=FT:Label(frame,"",15); self.keyLabel:SetPoint("TOPLEFT",24,-114); self.keyLabel:SetWidth(472)
        local change=FT:QuietButton(frame,"Choose a key",230,32,"keybind"); change:SetPoint("TOPLEFT",24,-142)
        change:SetScript("OnClick",function() if not InCombatLockdown() then self:Capture(true) end end)
        FT:Tooltip(change,"Choose a key","Click, then press the key. It only locks while hovering a bag item. Esc cancels.")
        self.clearKey=FT:QuietButton(frame,"Clear key",230,32,"reset"); self.clearKey:SetPoint("TOPLEFT",266,-142)
        self.clearKey:SetScript("OnClick",function() FT.db.itemLockKey=nil; self:Apply() end)
        FT:Tooltip(self.clearKey,"Clear key","Remove the lock key. Alt + right-click still works, and locked items stay locked.")
        self.listTitle=FT:Label(frame,"",16,true); self.listTitle:SetPoint("TOPLEFT",24,-196); FT:SectionHeading(self.listTitle,"INV_Misc_Key_03",300)
        self.rows={}
        for i=1,PAGE do
            local row=FT:QuietButton(frame,"",436,32,"generic"); row:SetPoint("TOPLEFT",24,-226-(i-1)*36)
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row.icon,"RIGHT",8,0); row.label:SetPoint("RIGHT",-8,0); row.label:SetJustifyH("LEFT")
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row.remove=FT:QuietButton(frame,"",32,32); row.remove:SetPoint("LEFT",row,"RIGHT",4,0)
            row.remove.glyph=row.remove:CreateTexture(nil,"ARTWORK"); row.remove.glyph:SetSize(14,14); row.remove.glyph:SetPoint("CENTER")
            row.remove.glyph:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            row.remove:SetScript("OnClick",function() if row.entry then self:Set(row.entry.id,false) end end)
            FT:Tooltip(row.remove,"Unlock","Unlock this item.")
            row.remove:Hide()
            row:HookScript("OnEnter",function()
                if not row.entry or not GameTooltip.SetItemByID then return end
                GameTooltip:SetOwner(row,"ANCHOR_RIGHT"); pcall(GameTooltip.SetItemByID,GameTooltip,row.entry.id); GameTooltip:Show()
            end)
            row:HookScript("OnLeave",function() GameTooltip:Hide() end)
            self.rows[i]=row
        end
        self.empty=FT:Label(frame,"Nothing locked yet.",13); self.empty:SetPoint("TOPLEFT",24,-230); self.empty:SetTextColor(.66,.59,.48)
        self.prev=FT:QuietButton(frame,"Previous",110,26,"reset"); self.prev:SetPoint("TOPLEFT",24,-446)
        self.next=FT:QuietButton(frame,"Next",110,26,"add"); self.next:SetPoint("TOPLEFT",386,-446)
        self.prev:SetScript("OnClick",function() self.page=(self.page or 1)-1; self:Refresh() end)
        self.next:SetScript("OnClick",function() self.page=(self.page or 1)+1; self:Refresh() end)
        self.pageLabel=FT:Label(frame,"",12); self.pageLabel:SetPoint("TOP",0,-452)
        self.status=FT:Label(frame,"",13); self.status:SetPoint("TOPLEFT",24,-490); self.status:SetWidth(472)
        if self.status.SetWordWrap then self.status:SetWordWrap(true) end
        local capture=CreateFrame("Frame",nil,frame); capture:SetAllPoints(frame); capture:EnableKeyboard(false); capture:Hide()
        capture:SetScript("OnKeyDown",function(_,key)
            if not self.capturing then return end
            if key=="ESCAPE" then self:Capture(false); return end
            if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
            local c=combo(key); self:Capture(false); self:Propose(c)
        end)
        self.capture=capture
        frame:HookScript("OnHide",function() if self.capturing then self:Capture(false) end end)
    end
    self.sorted=nil
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("ItemLock",Lock)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Lock:Apply() end end)
