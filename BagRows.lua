local _,FT=...
-- Bags > "Special bags on their own row" (off at first). In the game's
-- all-in-one bag, a quiver, ammo pouch, soul bag or other bag that only takes
-- one kind of item gets its own row at the bottom, with a small toggle above it
-- (the bag's icon) that hides or shows the row, instead
-- of being mixed in with your other slots. Click that bag on your bag bar
-- (with the bag open) to hide its row; click again to show it. Hidden rows
-- are remembered per character. Only positions change: the slots stay the
-- game's own buttons. Off: the game's layout (or Bag order's) as before.
-- The reagent bag works the same: while the all-in-one bag is open, its own
-- window is tucked away (invisible, off screen) and its slots sit in the
-- bottom row of the all-in-one bag. Its row shows while the reagent bag is
-- open: its icon (or the bag on your bag bar, the game's own click) opens
-- and closes it. The toggles sit in the bag's bottom bar, left of the gold.
local Rows={}
FT.BagRows=Rows
local REAGENT=5 -- the reagent bag's bag number
local GAP=8 -- between your other slots and the special rows
local function settings() return FT.Bags:Settings() end
local function combined() return _G.ContainerFrameCombinedBags end
local function bagOf(b) local ok,v=pcall(b.GetBagID,b); return ok and type(v)=="number" and v or 0 end
local function slotOf(b) local ok,v=pcall(b.GetID,b); return ok and type(v)=="number" and v or 0 end
local function gamepad() return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() end
function Rows:On() return FT.dbReady and settings().rows==true end
function Rows:Active(frame)
    return self:On() and frame~=nil and frame==combined() and not gamepad()
        and frame.EnumerateValidItems and frame.GetColumns and frame.GetInitialItemAnchor and AnchorUtil and AnchorUtil.GridLayout and true or false
end
-- A bag that only takes one kind of item (quiver, ammo pouch, soul bag,
-- herb bag and so on): the game reports a bag family for it.
local function slots(bag)
    if not (C_Container and C_Container.GetContainerNumSlots) then return 0 end
    local ok,n=pcall(C_Container.GetContainerNumSlots,bag)
    return ok and type(n)=="number" and n or 0
end
function Rows:Special(bag)
    if bag==REAGENT then return slots(REAGENT)>0 end
    if type(bag)~="number" or bag<1 or not (C_Container and C_Container.GetContainerNumFreeSlots) then return false end
    local ok,_,family=pcall(C_Container.GetContainerNumFreeSlots,bag)
    return ok and type(family)=="number" and family~=0
end
-- The reagent bag's own window, while it is open.
function Rows:ReagentFrame()
    if slots(REAGENT)<=0 then return nil end
    for i=1,(NUM_CONTAINER_FRAMES or 13) do
        local f=_G["ContainerFrame"..i]
        if f and f~=combined() and f:IsShown() and f.GetBagID and f.EnumerateValidItems then
            local ok,id=pcall(f.GetBagID,f)
            if ok and id==REAGENT then return f end
        end
    end
end
-- Whether this window is the reagent bag tucked into the all-in-one bag.
function Rows:Absorbs(frame) return frame~=nil and frame.ftRowsParked==true end
-- Hidden rows, per character: {[bag]=true}.
function Rows:HiddenSet()
    local guid=UnitGUID and UnitGUID("player")
    if type(guid)~="string" or (issecretvalue and issecretvalue(guid)) then return {} end
    if type(FT.db.bagRowsHidden)~="table" then FT.db.bagRowsHidden={} end
    local all=FT.db.bagRowsHidden
    if type(all[guid])~="table" then all[guid]={} end
    return all[guid]
end
function Rows:Hidden(bag) return self:HiddenSet()[bag]==true end
-- What goes where: your other slots, and each special bag's slots (in
-- slot order), the hidden ones apart.
function Rows:Plan(frame)
    local plan={normal={},special={},hidden={},bags={},all={}}
    local byBag,special={},{}
    for _,b in frame:EnumerateValidItems() do
        local bag=bagOf(b)
        if special[bag]==nil then special[bag]=self:Special(bag); if special[bag] then plan.all[#plan.all+1]=bag end end
        if special[bag] then
            if self:Hidden(bag) then plan.hidden[#plan.hidden+1]=b
            else
                if not byBag[bag] then byBag[bag]={}; plan.bags[#plan.bags+1]=bag end
                local t=byBag[bag]; t[#t+1]=b
            end
        else plan.normal[#plan.normal+1]=b end
    end
    -- The reagent bag, from its own window.
    if self:Special(REAGENT) then
        plan.all[#plan.all+1]=REAGENT
        local rf=self:ReagentFrame()
        plan.reagent=rf
        if rf then
            local t={}
            for _,b in rf:EnumerateValidItems() do t[#t+1]=b end
            if #t>0 then byBag[REAGENT]=t; plan.bags[#plan.bags+1]=REAGENT end
        end
    end
    table.sort(plan.bags); table.sort(plan.all)
    for _,bag in ipairs(plan.bags) do
        local t=byBag[bag]; table.sort(t,function(x,y) return slotOf(x)<slotOf(y) end)
        plan.special[#plan.special+1]=t
    end
    return plan
end
local function size(frame)
    local w,h=37,37
    local pool=frame.itemButtonPool
    if pool and pool.GetTemplate and C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok,info=pcall(function() return C_XMLUtil.GetTemplateInfo(pool:GetTemplate()) end)
        if ok and type(info)=="table" then w=tonumber(info.width) or w; h=tonumber(info.height) or h end
    end
    return w,h
end
local SPACING=5 -- the game's ITEM_SPACING_X / _Y
local function rowsOf(n,columns) return n>0 and math.ceil(n/columns) or 0 end
-- How much taller (or shorter) the window gets than the game makes it.
function Rows:ExtraHeight(frame,plan)
    local columns=frame:GetColumns()
    local _,h=size(frame)
    local okS,total=pcall(frame.GetBagSize,frame)
    total=okS and type(total)=="number" and total or (#plan.normal+#plan.hidden)
    local before=rowsOf(total,columns)
    local special=0
    for _,t in ipairs(plan.special) do special=special+rowsOf(#t,columns) end
    local after=rowsOf(#plan.normal,columns)+special
    local extra=(after-before)*(h+SPACING)
    if special>0 and #plan.normal>0 then extra=extra+GAP end
    return extra
end
local function anchorParts(frame)
    local ok,anchor=pcall(frame.GetInitialItemAnchor,frame)
    if ok and anchor and anchor.Get then
        local p,rel,rp,x,y=anchor:Get()
        if p then return p,rel,rp,x or 0,y or 0 end
    end
    return "BOTTOMRIGHT",frame.MoneyFrame or frame,"TOPRIGHT",0,4
end
function Rows:Layout(frame)
    local plan=self:Plan(frame)
    local columns=frame:GetColumns()
    local w,h=size(frame)
    local p,rel,rp,x,y=anchorParts(frame)
    if plan.reagent then self:Park(plan.reagent,frame) end
    for _,b in ipairs(plan.hidden) do b:Hide() end
    -- Special rows from the bottom up: the first bag's first row on top, each
    -- row starting on the left.
    local total=0
    for _,t in ipairs(plan.special) do total=total+rowsOf(#t,columns) end
    local row=0
    for _,t in ipairs(plan.special) do
        for i,b in ipairs(t) do
            local r=row+math.floor((i-1)/columns)
            local c=(i-1)%columns
            if not b:IsShown() then b:Show() end
            b:ClearAllPoints()
            b:SetPoint(p,rel,rp,x-(columns-1-c)*(w+SPACING),y+(total-1-r)*(h+SPACING))
        end
        row=row+rowsOf(#t,columns)
    end
    local lift=total*(h+SPACING)+(total>0 and #plan.normal>0 and GAP or 0)
    -- Your other slots above, in the game's order or Bag order's corner.
    local Order=FT.BagOrder
    local corner=settings().order; if corner=="game" then corner=nil end
    if Order and Order.Arrange then
        Order:Arrange(frame,plan.normal,AnchorUtil.CreateAnchor(p,rel,rp,x,y+lift),corner)
    end
    -- In the bottom bar, from the left, level with the gold: each special
    -- bag's icon. Click: hide or show its row (also when hidden, so it can
    -- come back); the reagent bag's opens or closes it.
    frame.ftRowToggles=frame.ftRowToggles or {}
    for _,t in pairs(frame.ftRowToggles) do t:Hide() end
    local left=x-(columns-1)*(w+SPACING)-w
    local money=frame.MoneyFrame
    local middle=-((money and money.GetHeight and money:GetHeight() or 14)/2)
    for i,bag in ipairs(plan.all) do
        local t=self:Toggle(frame,bag)
        t:ClearAllPoints()
        if money then t:SetPoint("CENTER",money,"TOPRIGHT",left+8+(i-1)*20,middle)
        else t:SetPoint("CENTER",rel,rp,left+8+(i-1)*20,y-12) end
        t:Show()
    end
    if frame.LayoutAddSlots then pcall(frame.LayoutAddSlots,frame) end
    self:Size(frame,plan)
    self:Overlays()
end
-- The reagent bag's window while its slots sit in the all-in-one bag:
-- invisible and off screen; its slots ignore that and draw above the bag.
function Rows:Park(rf,host)
    if not rf.ftRowsParked then
        rf.ftRowsParked=true
        rf.ftRowsLevel=rf:GetFrameLevel()
        rf.ftRowsClamped=rf.IsClampedToScreen and rf:IsClampedToScreen() or false
    end
    if rf.SetClampedToScreen then rf:SetClampedToScreen(false) end
    if rf.ftMoveHandle then rf.ftMoveHandle:EnableMouse(false) end
    rf:SetAlpha(0)
    if rf.EnableMouse then rf:EnableMouse(false) end
    rf:ClearAllPoints(); rf:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",-4000,-4000)
    local level=(host:GetFrameLevel() or 1)+4
    for _,b in rf:EnumerateValidItems() do
        if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(true) end
        if b.SetFrameStrata and host.GetFrameStrata then b:SetFrameStrata(host:GetFrameStrata()) end
        b:SetFrameLevel(level)
    end
end
-- Back to its own window (switched off, or the window closed).
function Rows:Unpark(rf,relayout)
    if not (rf and rf.ftRowsParked) then return end
    rf.ftRowsParked=nil
    rf:SetAlpha(1)
    if rf.SetClampedToScreen then rf:SetClampedToScreen(rf.ftRowsClamped and true or false) end
    local mover=FT.modules.MoveWindows
    if rf.ftMoveHandle and mover and mover.Unlocked then rf.ftMoveHandle:EnableMouse(mover:Unlocked()) end
    if rf.EnableMouse then rf:EnableMouse(true) end
    for _,b in rf:EnumerateValidItems() do
        if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(false) end
        if b.SetFrameStrata and rf.GetFrameStrata then b:SetFrameStrata(rf:GetFrameStrata()) end
        b:SetFrameLevel((rf.ftRowsLevel or rf:GetFrameLevel() or 1)+1)
        if not b:IsShown() then b:Show() end
    end
    if relayout and rf:IsShown() then
        if UpdateContainerFrameAnchors then pcall(UpdateContainerFrameAnchors) end
        if rf.UpdateItemLayout then pcall(rf.UpdateItemLayout,rf) end
    end
end
-- The window's height: the game's, plus what the rows add.
function Rows:Size(frame,plan)
    local ok,base=pcall(frame.CalculateHeight,frame)
    if not ok or type(base)~="number" then return end
    local extra=self:ExtraHeight(frame,plan or self:Plan(frame))
    local height=base+extra
    frame:SetHeight(height)
    self:GrowUp(frame,extra)
    if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then pcall(NineSliceUtil.UpdateCornerCropping,frame,height) end
end
-- Grow up: the game places its bag by the bottom corner, so it already
-- grows up; a bag you moved (Move game windows) is placed by its top, so it
-- is told how much taller the rows make it and sits that much higher.
function Rows:GrowUp(frame,extra)
    if frame.ftGrowUp==extra then return end
    frame.ftGrowUp=extra~=0 and extra or nil
    local mover=FT.modules.MoveWindows
    if mover and mover.Place and mover.Settings then
        local ok,s=pcall(mover.Settings,mover)
        local name=frame.GetName and frame:GetName()
        if ok and type(s)=="table" and s.enabled and type(s.frames)=="table" and name and s.frames[name] then pcall(mover.Place,mover,frame,name) end
    end
end
-- Back to the game's own layout (switched off).
function Rows:Restore(frame)
    if not (frame and frame.EnumerateValidItems and frame.GetInitialItemAnchor) then return end
    for _,t in pairs(frame.ftRowToggles or {}) do t:Hide() end
    for _,b in frame:EnumerateValidItems() do if not b:IsShown() then b:Show() end end
    local ok,base=pcall(frame.CalculateHeight,frame)
    self:GrowUp(frame,0)
    if ok and type(base)=="number" then frame:SetHeight(base); if NineSliceUtil and NineSliceUtil.UpdateCornerCropping then pcall(NineSliceUtil.UpdateCornerCropping,frame,base) end end
    local Order=FT.BagOrder
    local corner=settings().order
    if Order and Order.Arrange then
        local list={}; for _,b in frame:EnumerateValidItems() do list[#list+1]=b end
        Order:Arrange(frame,list,frame:GetInitialItemAnchor(),corner~="game" and corner or nil)
    end
    if frame.LayoutAddSlots then pcall(frame.LayoutAddSlots,frame) end
    for i=1,(NUM_CONTAINER_FRAMES or 13) do local f=_G["ContainerFrame"..i]; if f and f.ftRowsParked then self:Unpark(f,true) end end
end
function Rows:Redraw()
    local frame=combined()
    if not frame or not frame:IsShown() then self:Overlays(); return end
    if self:Active(frame) then self:Layout(frame) else self:Restore(frame) end
    self:Overlays()
end
-- Hide or show a special bag's row. The reagent bag: open or close it.
function Rows:Flip(bag)
    if bag==REAGENT then
        if InCombatLockdown() then UIErrorsFrame:AddMessage("Leave combat to open the reagent bag.",1,.3,.3); return end
        if self:ReagentFrame() then if CloseBag then pcall(CloseBag,REAGENT) end
        elseif OpenBag then pcall(OpenBag,REAGENT) end
        C_Timer.After(0,function() Rows:Redraw() end)
        return
    end
    local set=self:HiddenSet()
    set[bag]=not set[bag] or nil
    self:Redraw()
end
local function bagIcon(bag)
    local inv=C_Container and C_Container.ContainerIDToInventoryID and select(2,pcall(C_Container.ContainerIDToInventoryID,bag))
    local tex=type(inv)=="number" and GetInventoryItemTexture and GetInventoryItemTexture("player",inv)
    return tex or "Interface\\Icons\\INV_Misc_Bag_08"
end
-- The small icon for one special bag above the rows.
function Rows:Toggle(frame,bag)
    local t=frame.ftRowToggles[bag]
    if not t then
        t=CreateFrame("Button",nil,frame); frame.ftRowToggles[bag]=t
        t:SetSize(16,16); t:SetFrameLevel((frame:GetFrameLevel() or 1)+20)
        t.icon=t:CreateTexture(nil,"ARTWORK"); t.icon:SetAllPoints()
        if FT.RoundIcon then FT:RoundIcon(t.icon) end
        t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        t:SetScript("OnClick",function() Rows:Flip(bag); if t:IsMouseOver() then t:GetScript("OnEnter")(t) end end)
        t:SetScript("OnEnter",function()
            GameTooltip:SetOwner(t,"ANCHOR_RIGHT")
            if bag==REAGENT then
                GameTooltip:SetText("Reagent bag",1,.82,0)
                GameTooltip:AddLine(Rows:ReagentFrame() and "Click to close it." or "Click to open it here.",.96,.93,.86,true)
            else
                local name=C_Container and C_Container.GetBagName and select(2,pcall(C_Container.GetBagName,bag))
                GameTooltip:SetText(type(name)=="string" and name or "Bag",1,.82,0)
                GameTooltip:AddLine(Rows:Hidden(bag) and "Hidden. Click to show its row." or "Click to hide its row.",.96,.93,.86,true)
            end
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    t.icon:SetTexture(bagIcon(bag))
    local hidden
    -- The reagent bag's icon: full colour while closed (click to open), grey while open.
    if bag==REAGENT then hidden=self:ReagentFrame()~=nil else hidden=self:Hidden(bag) end
    t.icon:SetDesaturated(hidden); t:SetAlpha(hidden and .5 or 1)
    return t
end
-- Bag bar: a click on a special bag (bag open, nothing on the cursor)
-- hides or shows its row. A cover on the button takes that click, so the
-- game's own click never runs from here; it goes away while you carry an
-- item, so you can still drop things on the bag.
local covers={}
local function bagButton(bag) return bag==REAGENT and _G.CharacterReagentBag0Slot or _G["CharacterBag"..(bag-1).."Slot"] end
function Rows:Cover(button,bag)
    local cover=covers[bag]
    if cover then return cover end
    cover=CreateFrame("Button",nil,button); covers[bag]=cover
    cover:SetAllPoints(button); cover:SetFrameLevel((button:GetFrameLevel() or 1)+5)
    cover:RegisterForClicks("LeftButtonUp")
    if cover.SetPassThroughButtons then pcall(cover.SetPassThroughButtons,cover,"RightButton","MiddleButton") end
    cover.shade=cover:CreateTexture(nil,"OVERLAY"); cover.shade:SetPoint("TOPLEFT",4,-4); cover.shade:SetPoint("BOTTOMRIGHT",-4,4)
    cover.shade:SetColorTexture(0,0,0,.6)
    cover:RegisterForDrag("LeftButton")
    cover:SetScript("OnDragStart",function() if PickupBagFromSlot then pcall(PickupBagFromSlot,button:GetID()) end end)
    cover:SetScript("OnClick",function()
        Rows:Flip(bag)
        if cover:IsMouseOver() and cover:GetScript("OnEnter") then cover:GetScript("OnEnter")(cover) end
    end)
    cover:SetScript("OnEnter",function()
        GameTooltip:SetOwner(cover,"ANCHOR_LEFT")
        local ok=pcall(GameTooltip.SetInventoryItem,GameTooltip,"player",button:GetID())
        if not ok then GameTooltip:SetText("Bag",1,.82,0) end
        GameTooltip:AddLine(Rows:Hidden(bag) and "Hidden in your bag. Click to show its row." or "Click to hide its row in your bag.",.4,.8,1,true)
        GameTooltip:Show()
    end)
    cover:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return cover
end
function Rows:Overlays()
    local frame=combined()
    local open=self:On() and frame and frame:IsShown() and not gamepad()
    local carrying=GetCursorInfo and GetCursorInfo()~=nil
    local list={}
    for bag=1,(Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots or 4) do list[#list+1]=bag end
    for _,bag in ipairs(list) do
        local button=bagButton(bag)
        local special=open and button and self:Special(bag)
        local cover=covers[bag]
        if special and not cover then cover=self:Cover(button,bag) end
        if cover then
            cover:SetShown(special and not carrying or false)
            cover.shade:SetShown(self:Hidden(bag))
        end
    end
end
local hooked
function Rows:Hook()
    local frame=combined()
    if hooked or not frame or not frame.UpdateItemLayout then return end
    hooked=true
    hooksecurefunc(frame,"UpdateItemLayout",function(owner) if Rows:Active(owner) then Rows:Layout(owner) end end)
    if frame.UpdateFrameSize then hooksecurefunc(frame,"UpdateFrameSize",function(owner) if Rows:Active(owner) then Rows:Size(owner) end end) end
    frame:HookScript("OnShow",function() Rows:Overlays() end)
    frame:HookScript("OnHide",function()
        -- The reagent bag closes with it (its window is tucked away).
        local rf=Rows:ReagentFrame()
        if rf and rf.ftRowsParked then
            if CloseBag then pcall(CloseBag,REAGENT) end
            if rf:IsShown() then rf:Hide() end
        end
        Rows:Overlays()
    end)
    -- The reagent bag's window: whenever the game opens, moves or redraws
    -- it, its slots go back into the all-in-one bag.
    for i=1,(NUM_CONTAINER_FRAMES or 13) do
        local f=_G["ContainerFrame"..i]
        if f and f.UpdateItemLayout then
            hooksecurefunc(f,"UpdateItemLayout",function(owner)
                local host=combined()
                if host and host:IsShown() and Rows:Active(host) and owner==Rows:ReagentFrame() then Rows:Layout(host) end
            end)
            f:HookScript("OnShow",function(owner)
                local host=combined()
                if host and host:IsShown() and Rows:Active(host) and owner==Rows:ReagentFrame() then Rows:Layout(host) end
            end)
            f:HookScript("OnHide",function(owner)
                if owner.ftRowsParked then
                    Rows:Unpark(owner,false)
                    local host=combined()
                    if host and host:IsShown() and Rows:Active(host) then Rows:Layout(host) end
                end
            end)
        end
    end
    if type(UpdateContainerFrameAnchors)=="function" then
        hooksecurefunc("UpdateContainerFrameAnchors",function()
            local rf=Rows:ReagentFrame()
            if rf and rf.ftRowsParked then rf:ClearAllPoints(); rf:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",-4000,-4000) end
        end)
    end
end
function Rows:Apply()
    if self:On() then self:Hook() end
    if hooked or self:On() then self.touched=true; self:Redraw() end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("CURSOR_CHANGED"); events:RegisterEvent("BAG_CONTAINER_UPDATE")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then C_Timer.After(1,function() Rows:Apply() end)
    elseif event=="CURSOR_CHANGED" then if Rows:On() then Rows:Overlays() end
    elseif Rows:On() then FT:Coalesce("ftBagRows",function() Rows:Redraw() end,.2) end
end)
