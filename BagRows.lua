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
        if special[REAGENT]==nil then plan.all[#plan.all+1]=REAGENT end
        local rf=self:ReagentFrame()
        plan.reagent=rf
        if rf then
            local t={}
            for _,b in rf:EnumerateValidItems() do t[#t+1]=b end
            if #t>0 then
                -- The bag's own copies of the reagent slots (the game can add
                -- them after a click): hidden, the reagent window's are used.
                if byBag[REAGENT] then for _,b in ipairs(byBag[REAGENT]) do plan.hidden[#plan.hidden+1]=b end end
                local seen=false
                for _,bag in ipairs(plan.bags) do if bag==REAGENT then seen=true end end
                byBag[REAGENT]=t
                if not seen then plan.bags[#plan.bags+1]=REAGENT end
            end
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
    -- Hidden rows: see-through and not clickable, not hidden (hiding one of
    -- the game's slots runs the game's own code from here; see Rows:Unpark).
    Rows.faded=Rows.faded or setmetatable({},{__mode="k"})
    local fadeNow={}
    for _,b in ipairs(plan.hidden) do fadeNow[b]=true end
    for b in pairs(Rows.faded) do if not fadeNow[b] then Rows:Unfade(b) end end
    for b in pairs(fadeNow) do
        if not Rows.faded[b] then Rows.faded[b]=true; b:SetAlpha(0); b:EnableMouse(false) end
    end
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
        -- Where the window and its slots were, to put them back later
        -- ourselves: asking the game to lay its bag windows out again from
        -- here gets the game's own item use blocked (see Rows:Unpark).
        Rows.places=Rows.places or setmetatable({},{__mode="k"})
        local function points(f)
            local list={}
            for i=1,(f:GetNumPoints() or 0) do
                local pt,rel,rp,x,y=f:GetPoint(i)
                if pt then list[#list+1]={pt,rel,rp,x,y} end
            end
            return list
        end
        Rows.places[rf]=points(rf)
        for _,b in rf:EnumerateValidItems() do Rows.places[b]=points(b) end
    end
    if rf.SetClampedToScreen then rf:SetClampedToScreen(false) end
    if rf.ftMoveHandle then rf.ftMoveHandle:EnableMouse(false) end
    rf:SetAlpha(0)
    if rf.EnableMouse then rf:EnableMouse(false) end
    rf:ClearAllPoints(); rf:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",-4000,-4000)
    -- The slots move into the bag's own window: a slot whose window is
    -- hidden and see-through was drawn faded and let clicks through after
    -- a click in the bag. They go into a holder inside the bag that carries
    -- the reagent bag's number, which the game reads as the slot's bag.
    -- Nothing is written into the game's slots themselves: a value set by
    -- an addon there gets the game's own item use blocked.
    local holder=self:Holder(host)
    Rows.moved=Rows.moved or {}
    local now={}
    for _,b in rf:EnumerateValidItems() do now[b]=true end
    -- Slots the window no longer uses (it reuses them for other bags):
    -- theirs again, as the game made them.
    for b in pairs(Rows.moved) do if not now[b] then Rows:Release(b,rf) end end
    for _,b in rf:EnumerateValidItems() do
        Rows.moved[b]=true
        if b:GetParent()~=holder then b:SetParent(holder) end
        if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(false) end
    end
    self:Lift(rf,host)
    self:Watch(rf,host)
end
-- The tucked-away slots are not the bag's children, so they don't rise with
-- it: clicking in the bag (or the bank beside it) raises the bag's window
-- above them, and they turned grey and could not be clicked. Keep them just
-- above the bag.
function Rows:Lift(rf,host)
    -- In the bag's window, a few levels above it (so above its background
    -- and its own slots' level), in its strata: when the game raises the
    -- bag, its children rise with it.
    local level=(host:GetFrameLevel() or 1)+3
    local strata=host.GetFrameStrata and host:GetFrameStrata()
    local first
    for _,b in rf:EnumerateValidItems() do
        first=first or b
        if b.SetFixedFrameStrata then b:SetFixedFrameStrata(false) end
        if b.SetFixedFrameLevel then b:SetFixedFrameLevel(false) end
        if strata and b.SetFrameStrata and b:GetFrameStrata()~=strata then b:SetFrameStrata(strata) end
        if b:GetFrameLevel()~=level then b:SetFrameLevel(level) end
    end
    host.ftRowsFirst=first
end
-- The game can mark the tucked-away slots as "locked extra slots" (grey,
-- clicks go through) or leave them greyed after an item was picked up and
-- put back. Undo that for every slot the reagent bag really has.
function Rows:Heal(rf)
    if not (C_Container and C_Container.GetContainerNumSlots) then return 0 end
    local okN,count=pcall(C_Container.GetContainerNumSlots,REAGENT)
    count=okN and type(count)=="number" and count or 0
    local fixed=0
    for _,b in rf:EnumerateValidItems() do
        local slot=b:GetID()
        if slot and slot<=count then
            local extended=(b.IsExtended and b:IsExtended()) or (b.extendedFrame and b.extendedFrame:IsShown())
            if extended then
                if b.extendedFrame then b.extendedFrame:Hide() end
                fixed=fixed+1
            end
            local locked=InCombatLockdown() and b.IsProtected and b:IsProtected()
            if not locked and b.IsMouseEnabled and not b:IsMouseEnabled() then b:EnableMouse(true); fixed=fixed+1 end
            local icon=b.icon or b.Icon or (b.GetName and b:GetName() and _G[b:GetName().."IconTexture"])
            if icon and icon.IsDesaturated and icon:IsDesaturated() then
                local okI,info=pcall(C_Container.GetContainerItemInfo or function() end,REAGENT,slot)
                if okI and not (info and info.isLocked) then icon:SetDesaturated(false); fixed=fixed+1 end
            end
        end
    end
    self.healed=(self.healed or 0)+fixed
    return fixed
end
-- Is a slot inside the bag's window (on screen where the rows are)?
function Rows:Inside(b,host)
    local l,bt,r,t=b:GetLeft(),b:GetBottom(),b:GetRight(),b:GetTop()
    local hl,hb,hr,ht=host:GetLeft(),host:GetBottom(),host:GetRight(),host:GetTop()
    if not (l and bt and hl and hb and r and t and hr and ht) then return true end
    local bs,hs=b:GetEffectiveScale(),host:GetEffectiveScale()
    local cx,cy=(l+r)/2*bs/hs,(bt+t)/2*bs/hs
    return cx>=hl-2 and cx<=hr+2 and cy>=hb-2 and cy<=ht+2
end
-- Runs only while the bag is open with the reagent bag in it: one level
-- check per frame, work only when the bag's level really changed.
function Rows:Watch(rf,host)
    local w=host.ftRowsWatch
    if not w then
        w=CreateFrame("Frame",nil,host); host.ftRowsWatch=w
        w:SetScript("OnUpdate",function(self,elapsed)
            local owner,parked=self.host,self.parked
            if not (parked and parked.ftRowsParked and parked:IsShown()) then self:Hide(); return end
            -- One slot tells: not just above the bag any more (either moved).
            local b=owner.ftRowsFirst
            if b and (b:GetParent()~=owner.ftRowsHolder or b:GetFrameLevel()<owner:GetFrameLevel()+3 or (owner.GetFrameStrata and b:GetFrameStrata()~=owner:GetFrameStrata())) then
                if b:GetParent()~=owner.ftRowsHolder then Rows:Park(parked,owner) end
                Rows:Lift(parked,owner)
            end
            -- Five times a second: slots the game greyed out by mistake, or
            -- moved out of the bag (back into their hidden window).
            self.heal=(self.heal or 0)+elapsed
            if self.heal>=.2 then
                self.heal=0; Rows:Heal(parked)
                if b and not InCombatLockdown() and GetTime()-(Rows.relaidAt or 0)>1 and not Rows:Inside(b,owner) then Rows.relaid=(Rows.relaid or 0)+1; Rows.relaidAt=GetTime(); Rows:Layout(owner) end
            end
        end)
    end
    w.host=host; w.parked=rf; w:Show()
end
-- One slot back to the reagent window, as the game made it.
function Rows:Release(b,rf)
    if self.moved then self.moved[b]=nil end
    if rf and b:GetParent()~=rf then b:SetParent(rf) end
end
-- The holder: fills the bag's window and has the reagent bag's number.
function Rows:Holder(host)
    local h=host.ftRowsHolder
    if not h then
        h=CreateFrame("Frame",nil,host); host.ftRowsHolder=h
        h:SetAllPoints(host); h:EnableMouse(false)
    end
    if h:GetID()~=REAGENT then h:SetID(REAGENT) end
    h:SetFrameLevel((host:GetFrameLevel() or 1)+1)
    return h
end
-- Back to its own window (switched off, or the window closed).
function Rows:Unpark(rf,relayout)
    if not (rf and rf.ftRowsParked) then return end
    rf.ftRowsParked=nil
    for b in pairs(self.moved or {}) do self:Release(b,rf) end
    local host=combined(); if host and host.ftRowsWatch then host.ftRowsWatch:Hide() end
    rf:SetAlpha(1)
    if rf.SetClampedToScreen then rf:SetClampedToScreen(rf.ftRowsClamped and true or false) end
    local mover=FT.modules.MoveWindows
    if rf.ftMoveHandle and mover and mover.Unlocked then rf.ftMoveHandle:EnableMouse(mover:Unlocked()) end
    if rf.EnableMouse then rf:EnableMouse(true) end
    for _,b in rf:EnumerateValidItems() do
        if b.SetFixedFrameStrata then b:SetFixedFrameStrata(false) end
        if b.SetFixedFrameLevel then b:SetFixedFrameLevel(false) end
        if b.SetIgnoreParentAlpha then b:SetIgnoreParentAlpha(false) end
        self:Release(b,rf)
        if b.SetFrameStrata and rf.GetFrameStrata then b:SetFrameStrata(rf:GetFrameStrata()) end
        b:SetFrameLevel((rf.ftRowsLevel or rf:GetFrameLevel() or 1)+1)
        if not b:IsShown() then b:Show() end
    end
    -- Back where they were, set by us. Never by calling the game's own bag
    -- functions (UpdateContainerFrameAnchors, UpdateItemLayout, OpenBag,
    -- CloseBag, Hide on its windows): run from an addon, they leave the
    -- bags marked as touched by an addon, and the game then blocks using
    -- items from them ("ForeverTools has been blocked from an action").
    local function put(f)
        local list=Rows.places and Rows.places[f]
        if not list or #list==0 then return end
        f:ClearAllPoints()
        for _,pt in ipairs(list) do pcall(f.SetPoint,f,pt[1],pt[2],pt[3],pt[4],pt[5]) end
    end
    put(rf)
    for _,b in rf:EnumerateValidItems() do put(b) end
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
function Rows:Unfade(b)
    if self.faded then self.faded[b]=nil end
    b:SetAlpha(1); b:EnableMouse(true)
end
-- Back to the game's own layout (switched off).
function Rows:Restore(frame)
    if not (frame and frame.EnumerateValidItems and frame.GetInitialItemAnchor) then return end
    for _,t in pairs(frame.ftRowToggles or {}) do t:Hide() end
    for b in pairs(self.faded or {}) do self:Unfade(b) end
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
    -- The reagent bag opens and closes through its own icon (a click on the
    -- game's reagent bag button), never from here.
    if bag==REAGENT then return end
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
        -- The reagent bag's icon only shows whether it is open: an addon
        -- can't open or close a bag without getting the game's own item use
        -- blocked, and a protected button in the bag would lock the bag's
        -- window in fights. The game's reagent bag button does it.
        t=CreateFrame("Button",nil,frame)
        if bag~=REAGENT then t:SetScript("OnClick",function() Rows:Flip(bag); if t:IsMouseOver() then t:GetScript("OnEnter")(t) end end) end
        frame.ftRowToggles[bag]=t
        t:SetSize(16,16); t:SetFrameLevel((frame:GetFrameLevel() or 1)+20)
        t.icon=t:CreateTexture(nil,"ARTWORK"); t.icon:SetAllPoints()
        if FT.RoundIcon then FT:RoundIcon(t.icon) end
        t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
        t:SetScript("OnEnter",function()
            GameTooltip:SetOwner(t,"ANCHOR_RIGHT")
            if bag==REAGENT then
                GameTooltip:SetText("Reagent bag",1,.82,0)
                GameTooltip:AddLine(Rows:ReagentFrame() and "Open: its row is in your bag." or "Closed.",.96,.93,.86,true)
                GameTooltip:AddLine("Open or close it with the reagent bag on your bag bar.",.66,.59,.48,true)
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
-- /ft rowdebug: what the reagent row looks like to the game right now.
function Rows:Debug()
    local function say(...) print(...) end
    local function q(f,m,...) if f and f[m] then local ok,v=pcall(f[m],f,...); if ok then return tostring(v) end end return "?" end
    local host=combined()
    say("ForeverTools bag rows ("..tostring(FT.version)..") on: "..tostring(self:On()).." cursor: "..tostring(GetCursorInfo and GetCursorInfo() or "none").." fight: "..tostring(InCombatLockdown()))
    if host then say("Bag: shown "..q(host,"IsShown").." level "..q(host,"GetFrameLevel").." strata "..q(host,"GetFrameStrata").." toplevel "..q(host,"IsToplevel").." alpha "..q(host,"GetAlpha").." watch "..tostring(host.ftRowsWatch and host.ftRowsWatch:IsShown() or false)) end
    local rf=self:ReagentFrame()
    if not rf then say("Reagent bag: its window is not open"); return end
    say("Reagent window: "..q(rf,"GetName").." parked "..tostring(rf.ftRowsParked==true).." shown "..q(rf,"IsShown").." alpha "..q(rf,"GetAlpha").." level "..q(rf,"GetFrameLevel").." strata "..q(rf,"GetFrameStrata"))
    local n=0
    for _,b in rf:EnumerateValidItems() do
        n=n+1
        if n<=2 then
            local over=b.ItemContextOverlay
            say("Slot "..n.." bag "..q(b,"GetBagID").." id "..q(b,"GetID").." of "..tostring(C_Container and select(2,pcall(C_Container.GetContainerNumSlots,REAGENT))).." window id "..q(rf,"GetID").." extended "..q(b,"IsExtended").." grey "..q(b.icon or b.Icon,"IsDesaturated").." fixed so far "..tostring(self.healed or 0))
            say("Slot "..n..": shown "..q(b,"IsShown").." visible "..q(b,"IsVisible").." level "..q(b,"GetFrameLevel").." strata "..q(b,"GetFrameStrata").." alpha "..q(b,"GetAlpha").."/"..q(b,"GetEffectiveAlpha").." ignoreParentAlpha "..q(b,"IsIgnoringParentAlpha").." mouse "..q(b,"IsMouseEnabled").." enabled "..q(b,"IsEnabled").." over "..q(b,"IsMouseOver").." overlay "..q(over,"IsShown").." search "..tostring(b.matchesSearch).." context "..tostring(b.itemContextMatchResult).." extended "..tostring(b.extendedFrame and b.extendedFrame:IsShown() or false))
        end
    end
    say("Slots: "..n.."  inside the bag: "..tostring(host and (function() for _,b in rf:EnumerateValidItems() do return self:Inside(b,host) end end)()).."  put back: "..tostring(self.relaid or 0))
    -- Where the reagent slots are, and anything of the bag's own that sits on bag 5.
    for _,b in rf:EnumerateValidItems() do say("Reagent slot "..q(b,"GetID").." at "..q(b,"GetLeft").."/"..q(b,"GetBottom").." size "..q(b,"GetWidth")); break end
    if host and host.EnumerateValidItems then
        local mine,count=0,0
        for _,b in host:EnumerateValidItems() do count=count+1; local okB,bag=pcall(b.GetBagID,b); if okB and bag==REAGENT then mine=mine+1 end end
        say("Bag's own slots: "..count..", of them on the reagent bag: "..mine)
    end
    local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale()
    say("Mouse at "..string.format("%.0f/%.0f",x/scale,y/scale))
    -- The reagent slot drawn under the mouse, in full.
    local mx,my=x/scale,y/scale
    for _,b in rf:EnumerateValidItems() do
        local l,bt,r,t=b:GetLeft(),b:GetBottom(),b:GetRight(),b:GetTop()
        if l and r and bt and t then
            local k=b:GetEffectiveScale()/UIParent:GetEffectiveScale()
            if mx>=l*k and mx<=r*k and my>=bt*k and my<=t*k then
                local icon=b.icon or b.Icon
                local vr,vg,vb=icon and icon.GetVertexColor and icon:GetVertexColor()
                local hl,hr,ht,hb=0,0,0,0; if b.GetHitRectInsets then hl,hr,ht,hb=b:GetHitRectInsets() end
                say("Slot under the mouse: id "..q(b,"GetID").." level "..q(b,"GetFrameLevel").." strata "..q(b,"GetFrameStrata").." shown "..q(b,"IsShown").." visible "..q(b,"IsVisible").." alpha "..q(b,"GetEffectiveAlpha").." clicks "..q(b,"IsMouseClickEnabled").." motion "..q(b,"IsMouseMotionEnabled").." over "..q(b,"IsMouseOver").." insets "..tostring(hl)..","..tostring(hr)..","..tostring(ht)..","..tostring(hb).." protected "..q(b,"IsProtected").." forbidden "..q(b,"IsForbidden"))
                say("  icon alpha "..q(icon,"GetAlpha").." grey "..q(icon,"IsDesaturated").." colour "..string.format("%.2f %.2f %.2f",vr or -1,vg or -1,vb or -1).." parent "..tostring(b:GetParent() and b:GetParent():GetName()).." parent shown "..q(b:GetParent(),"IsShown").." parent alpha "..q(b:GetParent(),"GetAlpha"))
                local kids={}
                for _,c in ipairs({b:GetChildren()}) do if c:IsShown() then kids[#kids+1]=(c:GetDebugName() or "?"):gsub("^.*%.","").."("..c:GetFrameLevel()..","..tostring(c:IsMouseEnabled())..")" end end
                say("  shown children: "..(#kids>0 and table.concat(kids," ") or "none"))
            end
        end
    end
    local foci=GetMouseFoci and GetMouseFoci() or {}
    for i,f in ipairs(foci) do
        if i<=3 then
            local chain,x={},f
            for _=1,5 do if not x then break end chain[#chain+1]=(x.GetName and x:GetName()) or (x.GetDebugName and x:GetDebugName()) or "?"; x=x.GetParent and x:GetParent() end
            say("Under the mouse "..i..": "..table.concat(chain," < ").." level "..q(f,"GetFrameLevel").." strata "..q(f,"GetFrameStrata").." type "..q(f,"GetObjectType").." bag "..q(f,"GetBagID").." slot "..q(f,"GetID").." at "..q(f,"GetLeft").."/"..q(f,"GetBottom").." size "..q(f,"GetWidth").."x"..q(f,"GetHeight").." shown "..q(f,"IsShown").." alpha "..q(f,"GetEffectiveAlpha"))
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
    -- The reagent bag stays open while you close and open your bags: its
    -- slots sit in the bag's window and hide and show with it, and its own
    -- (tucked away) window is left open. Nothing is opened or closed here.
    frame:HookScript("OnShow",function() Rows:Overlays() end)
    frame:HookScript("OnHide",function() Rows:Overlays() end)
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
                    -- Closed (its icon, the bag bar, or all bags at once).
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
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("CURSOR_CHANGED"); events:RegisterEvent("BAG_CONTAINER_UPDATE"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then C_Timer.After(1,function() Rows:Apply() end)
    elseif event=="CURSOR_CHANGED" then if Rows:On() then Rows:Overlays() end
    elseif Rows:On() then FT:Coalesce("ftBagRows",function() Rows:Redraw() end,.2) end
end)
