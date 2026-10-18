local _,FT=...
-- Trinket menu (PvP, off by default). Two buttons that use your top and
-- bottom trinket (click, or bind a key to them with /click), each showing
-- the trinket's cooldown. Point at either one and a menu lists every trinket
-- you carry, worn or in your bags, with its cooldown. Click one to put it in
-- that slot: left-click for the slot you pointed at, right-click for the
-- other one. In a fight the game does not allow equipping, so the swap waits
-- (a clock shows on the button) and happens the moment the fight ends.
--   * The two buttons are the game's own secure buttons running "/use 13"
--     and "/use 14", so they work in combat. They are made, shown, hidden and moved
--     out of combat only, as the game requires.
--   * The menu is a plain frame of ours: it opens and shows cooldowns in
--     combat too.
--   * Nothing runs while the feature is off; with it on, cooldown text only
--     ticks while a cooldown is running.
local T={queue={}}
local SLOTS={13,14}
local SIZE,GAP,MENU_COLS=36,4,4
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function num(v) if plain(v) and type(v)=="number" then return v end end
local function busy() return InCombatLockdown and InCombatLockdown() end
function T:Settings()
    if type(FT.db.trinkets)~="table" then FT.db.trinkets={} end
    local s=FT.db.trinkets
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.vertical)~="boolean" then s.vertical=false end
    if type(s.numbers)~="boolean" then s.numbers=true end
    if type(s.mouseover)~="boolean" then s.mouseover=false end
    -- No trinket worn or in your bags: no buttons, until you get one.
    if type(s.hideEmpty)~="boolean" then s.hideEmpty=true end
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    return s
end
-- Cooldown of a worn slot or of an item ID: start, duration (or nil).
local function slotCooldown(slot)
    if not GetInventoryItemCooldown then return end
    local ok,start,duration,enable=pcall(GetInventoryItemCooldown,"player",slot)
    if ok then start,duration=num(start),num(duration) end
    if ok and start and duration and duration>1.5 and enable~=0 then return start,duration end
end
local function itemCooldown(id)
    local get=(C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not get or not id then return end
    local ok,start,duration,enable=pcall(get,id)
    if ok then start,duration=num(start),num(duration) end
    if ok and start and duration and duration>1.5 and enable~=0 and enable~=false then return start,duration end
end
local function short(left)
    if left>=3600 then return math.floor(left/3600+.5).."h" end
    if left>=60 then return math.floor(left/60+.5).."m" end
    return tostring(math.floor(left+.5))
end
local function isTrinket(id)
    if not id then return false end
    local get=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not get then return false end
    local ok,_,_,_,equipLoc=pcall(get,id)
    return ok and equipLoc=="INVTYPE_TRINKET"
end
-- Every trinket you carry: the two worn ones, then those in your bags.
function T:List()
    local out={}
    for _,slot in ipairs(SLOTS) do
        local id=GetInventoryItemID and num(GetInventoryItemID("player",slot))
        if id then
            local link=GetInventoryItemLink and GetInventoryItemLink("player",slot)
            out[#out+1]={id=id,slot=slot,link=plain(link) and link or nil,icon=GetInventoryItemTexture and GetInventoryItemTexture("player",slot)}
        end
    end
    local slots=(C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local info=C_Container and C_Container.GetContainerItemInfo
    if slots and info then
        for bag=0,4 do
            local ok,n=pcall(slots,bag); n=ok and num(n) or 0
            for i=1,n do
                local found,item=pcall(info,bag,i)
                if found and type(item)=="table" and plain(item) then
                    local id=num(item.itemID)
                    if id and isTrinket(id) then out[#out+1]={id=id,bag=bag,index=i,link=plain(item.hyperlink) and item.hyperlink or nil,icon=item.iconFileID} end
                end
            end
        end
    end
    return out
end
-- Do you carry a trinket at all (worn or in your bags)?
function T:HasAny() return #self:List()>0 end
-- A trinket in either slot right now.
function T:Worn()
    for _,slot in ipairs({13,14}) do
        local id=GetInventoryItemID and GetInventoryItemID("player",slot)
        if issecretvalue and issecretvalue(id) then return true end
        if id then return true end
    end
    return false
end
-- Should the buttons show right now?
function T:Wanted()
    local s=self:Settings()
    if self.moving then return true end
    if not s.enabled then return false end
    return not s.hideEmpty or self:HasAny()
end
-- Cooldown swipe and the time left on one button.
local function paintCooldown(button,start,duration,numbers)
    if start then
        if button.cooldown and button.cooldown.SetCooldown then button.cooldown:SetCooldown(start,duration) end
        button.until_=start+duration
    else
        if button.cooldown and button.cooldown.Clear then button.cooldown:Clear() elseif button.cooldown and button.cooldown.Hide then button.cooldown:Hide() end
        button.until_=nil
    end
    if button.time then
        local left=button.until_ and button.until_-GetTime()
        button.time:SetText((numbers and left and left>0) and short(left) or "")
    end
end
local function makeIcon(parent,name,secure)
    local b
    if secure then
        local ok,made=pcall(CreateFrame,"Button",name,parent,"SecureActionButtonTemplate")
        b=ok and made or CreateFrame("Button",name,parent)
    else b=CreateFrame("Button",name,parent) end
    b:SetSize(SIZE,SIZE)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(.07,.93,.07,.93)
    local ok,cd=pcall(CreateFrame,"Cooldown",nil,b,"CooldownFrameTemplate")
    if ok and cd then cd:SetAllPoints(b.icon); if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end; b.cooldown=cd end
    b.time=b:CreateFontString(nil,"OVERLAY","NumberFontNormal"); b.time:SetPoint("CENTER",0,0)
    local hi=b:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(b.icon); hi:SetColorTexture(1,1,1,.15)
    return b
end
-- The two buttons. Made out of combat only (secure buttons).
function T:Bar()
    if self.bar then return self.bar end
    if busy() then return end
    local f=CreateFrame("Frame","ForeverToolsTrinkets",UIParent)
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(false)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if self.moving and not busy() then f:StartMoving() end end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SavePlace() end)
    -- The same mover as every other element: rounded outline, its name
    -- above and "Drag to move" below, shown only while moving.
    FT:MoverBox(f,6)
    for _,t in ipairs(f.fillTextures) do t:Hide() end; for _,t in ipairs(f.borderTextures) do t:Hide() end
    f.name=FT:Label(f,"Trinket menu",12); FT:Caption(f.name,f,"above",6); f.name:Hide()
    f.hint=FT:Label(f,"Drag to move",12); FT:Caption(f.hint,f,"below",6); f.hint:Hide()
    f.buttons={}
    for i,slot in ipairs(SLOTS) do
        local b=makeIcon(f,"ForeverToolsTrinket"..i,true)
        b:RegisterForClicks("AnyUp","AnyDown")
        -- "/use 13" uses whatever trinket is in that slot. (The game's own
        -- "item" button type looked the item up by name and errored on a
        -- bare slot number in Forever.)
        b:SetAttribute("type","macro"); b:SetAttribute("macrotext","/use "..slot)
        b.slot=slot
        b.queued=b:CreateTexture(nil,"OVERLAY"); b.queued:SetSize(14,14); b.queued:SetPoint("TOPRIGHT",2,2)
        b.queued:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01"); b.queued:Hide()
        b:HookScript("OnEnter",function(owner)
            if GameTooltip then GameTooltip:SetOwner(owner,"ANCHOR_TOP"); if GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player",slot) end; GameTooltip:Show() end
            self:OpenMenu(owner)
        end)
        b:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end; self:MenuLeft() end)
        f.buttons[i]=b
    end
    f:Hide()
    self.bar=f
    self:Layout()
    return f
end
function T:Layout()
    local f=self.bar; if not f or busy() then return end
    local s=self:Settings()
    f:SetScale(s.size)
    for i,b in ipairs(f.buttons) do
        b:ClearAllPoints()
        if s.vertical then b:SetPoint("TOP",f,"TOP",0,-(i-1)*(SIZE+GAP)) else b:SetPoint("LEFT",f,"LEFT",(i-1)*(SIZE+GAP),0) end
    end
    if s.vertical then f:SetSize(SIZE,SIZE*2+GAP) else f:SetSize(SIZE*2+GAP,SIZE) end
    self:Place()
end
-- Where it is: saved as its center (screen units), or a spot near the
-- middle of the screen, a little below and to the right of your character.
function T:Place()
    local f=self.bar; if not f or busy() then return end
    local s=self:Settings(); local scale=f:GetScale() or 1
    f:ClearAllPoints()
    if s.x and s.y then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x/scale,s.y/scale)
    else f:SetPoint("CENTER",UIParent,"CENTER",140/scale,-120/scale) end
end
function T:SavePlace()
    local f=self.bar; if not f then return end
    local x,y=f:GetCenter()
    if not (num(x) and num(y)) then return end
    local s=self:Settings(); local scale=f:GetScale() or 1
    s.x,s.y=x*scale,y*scale
    if not busy() then self:Place() end
end
function T:ResetPosition() local s=self:Settings(); s.x,s.y=nil,nil; self:Place() end
-- Icons and cooldowns of the two buttons.
function T:Update()
    local f=self.bar; if not f then return end
    local s=self:Settings()
    local running=false
    for _,b in ipairs(f.buttons) do
        local icon=GetInventoryItemTexture and GetInventoryItemTexture("player",b.slot)
        b.icon:SetTexture(plain(icon) and icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        b.icon:SetDesaturated(not (plain(icon) and icon))
        local start,duration=slotCooldown(b.slot)
        paintCooldown(b,start,duration,s.numbers)
        if start then running=true end
        b.queued:SetShown(self.queue[b.slot]~=nil)
    end
    if self.menu and self.menu:IsShown() then running=self:FillMenu() or running end
    self:Tick(running)
end
-- The countdown text: updated twice a second, only while something cools down.
function T:Tick(on)
    if not self.ticker then
        self.ticker=CreateFrame("Frame"); self.ticker.wait=0
        self.ticker:SetScript("OnUpdate",function(t,dt)
            t.wait=t.wait+dt; if t.wait<.5 then return end; t.wait=0
            local s=self:Settings(); local any=false
            local function step(b)
                if b.until_ then
                    local left=b.until_-GetTime()
                    if left>0 then any=true; b.time:SetText(s.numbers and short(left) or "") else b.until_=nil; b.time:SetText("") end
                end
            end
            if self.bar then for _,b in ipairs(self.bar.buttons) do step(b) end end
            if self.menu and self.menu:IsShown() then for _,b in ipairs(self.menu.items) do if b:IsShown() then step(b) end end end
            if not any then t:Hide() end
        end)
    end
    self.ticker:SetShown(on and true or false)
end
-- The menu -----------------------------------------------------------------
function T:Menu()
    if self.menu then return self.menu end
    local ok,m=pcall(CreateFrame,"Frame","ForeverToolsTrinketMenu",UIParent,"TooltipBackdropTemplate")
    if not ok or not m then m=CreateFrame("Frame","ForeverToolsTrinketMenu",UIParent) end
    m:SetFrameStrata("DIALOG"); m:SetClampedToScreen(true); m:EnableMouse(true); m:Hide()
    m.items={}
    m:SetScript("OnEnter",function() self.menuOver=true end)
    m:SetScript("OnLeave",function() self.menuOver=false; self:MenuLeft() end)
    m.empty=m:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); m.empty:SetPoint("CENTER"); m.empty:SetText("No other trinkets in your bags")
    self.menu=m
    local skins=FT.modules.IconStyles
    if skins and skins.SkinPanel then skins:SkinPanel(m,"trinkets") end
    return m
end
local function menuItem(self,m,i)
    local b=m.items[i]
    if b then return b end
    b=makeIcon(m,nil,false)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    b.worn=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.worn:SetPoint("BOTTOMRIGHT",-1,1)
    b:SetScript("OnEnter",function(owner)
        self.menuOver=true
        if not GameTooltip then return end
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        local e=owner.entry
        if e and e.slot and GameTooltip.SetInventoryItem then GameTooltip:SetInventoryItem("player",e.slot)
        elseif e and e.bag and GameTooltip.SetBagItem then GameTooltip:SetBagItem(e.bag,e.index)
        elseif e and e.link and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink(e.link) end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: this slot. Right-click: the other slot."..(busy() and " In a fight it waits until the fight ends." or ""),.72,.66,.55,true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end; self.menuOver=false; self:MenuLeft() end)
    b:SetScript("OnClick",function(owner,mouse)
        local target=self.menuFor and self.menuFor.slot or 13
        if mouse=="RightButton" then target=target==13 and 14 or 13 end
        self:Equip(owner.entry,target)
    end)
    m.items[i]=b
    return b
end
-- Fill the menu; returns true when a listed trinket is cooling down.
function T:FillMenu()
    local m=self:Menu(); local s=self:Settings()
    local list=self:List(); local running=false
    local per=MENU_COLS
    for i,e in ipairs(list) do
        local b=menuItem(self,m,i)
        b.entry=e
        b.icon:SetTexture(plain(e.icon) and e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local start,duration
        if e.slot then start,duration=slotCooldown(e.slot) else start,duration=itemCooldown(e.id) end
        paintCooldown(b,start,duration,s.numbers)
        if start then running=true end
        b.worn:SetText(e.slot==13 and "1" or e.slot==14 and "2" or "")
        local row,col=math.floor((i-1)/per),(i-1)%per
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",m,"TOPLEFT",8+col*(SIZE+GAP),-8-row*(SIZE+GAP))
        b:Show()
        local skins=FT.modules.IconStyles
        if skins and skins.Track and not b.skinned then b.skinned=true; pcall(skins.Track,skins,b,"trinkets") end
    end
    for i=#list+1,#m.items do m.items[i]:Hide(); m.items[i].entry=nil end
    self:PaintSkin()
    local n=math.max(1,#list); local cols=math.min(per,n); local rows=math.ceil(n/per)
    m:SetSize(16+cols*SIZE+(cols-1)*GAP,16+rows*SIZE+(rows-1)*GAP)
    m.empty:SetShown(#list==0)
    if #list==0 then m:SetSize(200,40) end
    return running
end
function T:OpenMenu(owner)
    local m=self:Menu()
    self.menuFor=owner; self.menuOver=true
    m:SetScale(self:Settings().size)
    m:ClearAllPoints()
    local bar=self.bar
    local s=self:Settings()
    if s.vertical then m:SetPoint("LEFT",bar,"RIGHT",4,0) else m:SetPoint("BOTTOMLEFT",bar,"TOPLEFT",-8,4) end
    local running=self:FillMenu()
    m:Show()
    self:Tick(running or (self.ticker and self.ticker:IsShown()))
end
-- Close shortly after the mouse leaves the buttons and the menu.
function T:MenuLeft()
    self.menuOver=false
    local token={}; self.leaveToken=token
    C_Timer.After(.4,function()
        if self.leaveToken~=token or not self.menu then return end
        local over=self.menu:IsMouseOver()
        if self.bar then for _,b in ipairs(self.bar.buttons) do if b:IsMouseOver() then over=true end end end
        if not over then self.menu:Hide() end
    end)
end
-- Equip now, or after the fight.
function T:Equip(entry,slot)
    if not entry or not slot then return end
    if entry.slot==slot then return end
    if busy() then
        self.queue[slot]=entry
        FT:Toast("Swaps when the fight ends.",2)
        self:Update(); return
    end
    local item=entry.link or entry.id
    local equip=(C_Item and C_Item.EquipItemByName) or EquipItemByName
    if equip and item then pcall(equip,item,slot) end
    self.queue[slot]=nil
    C_Timer.After(.3,function() self:Update() end)
end
function T:RunQueue()
    if busy() then return end
    for _,slot in ipairs(SLOTS) do
        local e=self.queue[slot]
        if e then self.queue[slot]=nil; self:Equip(e,slot) end
    end
    self:Update()
end
-- "Show on mouseover": the buttons stay invisible until you point at them
-- (or the menu is open, or you are moving them). Only their alpha changes,
-- which the game allows in combat too, so they stay clickable.
function T:Fade()
    local f=self.bar; if not f then return end
    local s=self:Settings()
    local watch=s.enabled and s.mouseover and not self.moving
    if not watch then
        if self.fader then self.fader:Hide() end
        f:SetAlpha(1); return
    end
    if not self.fader then
        self.fader=CreateFrame("Frame"); self.fader.wait=0
        self.fader:SetScript("OnUpdate",function(t,dt)
            t.wait=t.wait+dt; if t.wait<.1 then return end; t.wait=0
            local bar=self.bar; if not bar then return end
            local over=bar:IsMouseOver() or (self.menu and self.menu:IsShown() and self.menu:IsMouseOver())
            local want=over and 1 or 0
            if bar:GetAlpha()~=want then bar:SetAlpha(want) end
        end)
    end
    f:SetAlpha(f:IsMouseOver() and 1 or 0)
    self.fader:Show()
end
-- On / off, out of combat (secure buttons cannot be shown or hidden in a fight).
function T:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if busy() then self.pending=true; return end
    self.pending=nil
    if not s.enabled and not self.bar then self:SetEvents(false); self:Refresh(); return end
    local f=self:Bar(); if not f then self.pending=true; return end
    self:Layout()
    f:SetShown(self:Wanted())
    if not f:IsShown() and self.menu then self.menu:Hide() end
    self:SetEvents(s.enabled)
    local skins=FT.modules.IconStyles
    if skins and skins.Track then for _,b in ipairs(f.buttons) do pcall(skins.Track,skins,b,"trinkets") end end
    self:PaintSkin()
    if s.enabled then self:Update() end
    self:Fade()
    self:Refresh()
end
-- Skins > PvP > Trinket menu: a rounded rim in the border color around
-- each button and menu icon (the icon itself rounds to match). Only plain
-- textures, so it is safe in combat. Off: the plain square icons.
local ROUNDED="Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga"
function T:PaintSkin()
    local skins=FT.modules.IconStyles
    if not skins or not skins.Area or not FT.dbReady then return end
    local on=skins:Settings().trinkets==true
    local s=on and skins:Area("trinkets")
    local function paint(b)
        if not b or not b.icon then return end
        if on and not b.rim then
            b.rim=b:CreateTexture(nil,"BACKGROUND",nil,-6); b.rim:SetTexture(ROUNDED)
            FT:RoundIcon(b.icon); b.rounded=b.icon.roundMask~=nil
        end
        if not b.rim then return end
        local mask=b.icon.roundMask
        if on then
            local out=(skins.OnePixel and skins.OnePixel(b) or 1)*(tonumber(s.thickness) or 2)
            b.rim:ClearAllPoints(); b.rim:SetPoint("TOPLEFT",b.icon,"TOPLEFT",-out,out); b.rim:SetPoint("BOTTOMRIGHT",b.icon,"BOTTOMRIGHT",out,-out)
            b.rim:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s.borderOpacity); b.rim:Show()
            if mask and not b.rounded then b.icon:AddMaskTexture(mask); b.rounded=true end
        else
            b.rim:Hide()
            if mask and b.rounded then b.icon:RemoveMaskTexture(mask); b.rounded=false end
        end
    end
    if self.bar then for _,b in ipairs(self.bar.buttons) do paint(b) end end
    if self.menu then for _,b in ipairs(self.menu.items) do paint(b) end end
end
function T:SetEvents(on)
    if self.listening==on then return end
    self.listening=on
    for _,event in ipairs({"PLAYER_EQUIPMENT_CHANGED","BAG_UPDATE_COOLDOWN","BAG_UPDATE_DELAYED","SPELL_UPDATE_COOLDOWN"}) do
        if on then pcall(self.events.RegisterEvent,self.events,event) else pcall(self.events.UnregisterEvent,self.events,event) end
    end
end
function T:SetMoving(on)
    if busy() then return end
    self.moving=on and true or false
    local f=self:Bar(); if not f then return end
    f:EnableMouse(self.moving)
    for _,b in ipairs(f.buttons) do b:EnableMouse(not self.moving) end
    for _,t in ipairs(f.fillTextures) do t:SetShown(self.moving) end
    for _,t in ipairs(f.borderTextures) do t:SetShown(self.moving) end
    f.name:SetShown(self.moving); f.hint:SetShown(self.moving)
    f:SetFrameStrata(self.moving and "HIGH" or "MEDIUM")
    f:SetShown(self:Wanted())
    if self.moving then self:Update() end
    self:Fade()
    self:Refresh()
end
-- Settings page (PvP > Trinket menu) ----------------------------------------
function T:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Trinket menu: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.layout.label:SetText("Layout: "..(s.vertical and "Vertical" or "Side by side"))
    self.numbers.label:SetText("Cooldown numbers: "..(s.numbers and "On" or "Off")); FT:SetSelected(self.numbers,s.numbers)
    self.mouseover.label:SetText("Show on mouseover: "..(s.mouseover and "On" or "Off")); FT:SetSelected(self.mouseover,s.mouseover)
    self.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
    self.settingSize=true; self.sizeSlider:SetValue(s.size); self.settingSize=false
    self.move.label:SetText(self.moving and "Lock position" or "Move buttons"); FT:SetSelected(self.move,self.moving)
    self.hideEmpty.label:SetText("Hide without trinkets: "..(s.hideEmpty and "On" or "Off")); FT:SetSelected(self.hideEmpty,s.hideEmpty)
    self.note:SetText(self.pending and "Saved. Changes after the fight." or "")
    -- On, but nothing to show yet: say so plainly.
    local worn=self:Worn()
    local say
    if s.enabled and not self.moving and not worn then
        if not self:HasAny() then
            say=s.hideEmpty and "The menu shows once you equip a trinket."
                or "The menu shows once you equip a trinket."
        else
            say="No trinket equipped. Point at a button to pick one from your bags."
        end
    end
    self.callout:Say(say)
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
function T:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTrinketPage","Trinket menu",540,420); self.frame=frame
        FT:PageInfo(frame,"Trinket menu","Two buttons for your trinkets, with cooldowns. Point at one to see every trinket you carry; left-click puts it in that slot, right-click in the other.\n\nIn a fight the swap waits until the fight ends. Key: a macro with /click ForeverToolsTrinket1 (or 2).")
        local hint=FT:Label(frame,"Use and swap trinkets from two buttons.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,FT:FactionIcon()); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Trinket menu","Show two trinket buttons.")
        self.layout=FT:QuietButton(frame,"",240,32,"move"); self.layout:SetPoint("TOPLEFT",24,-136)
        FT:MakeChoice(self.layout,{{false,"Side by side"},{true,"Vertical","One above the other."}},function() return self:Settings().vertical==true end,function(v) self:Settings().vertical=v; self:Apply() end)
        FT:Tooltip(self.layout,"Layout","Side by side, or one above the other.")
        self.numbers=FT:QuietButton(frame,"",240,32,"INV_Misc_PocketWatch_01"); self.numbers:SetPoint("TOPLEFT",276,-136)
        self.numbers:SetScript("OnClick",function() local s=self:Settings(); s.numbers=not s.numbers; self:Update(); self:Refresh() end)
        FT:Tooltip(self.numbers,"Cooldown numbers","Show the time left as a number.")
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,-186)
        self.sizeSlider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); self.sizeSlider:SetSize(320,18); self.sizeSlider:SetPoint("TOPLEFT",196,-184)
        self.sizeSlider:SetMinMaxValues(.7,1.5); self.sizeSlider:SetValueStep(.05); self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,v) if self.settingSize then return end; self:Settings().size=math.floor(v*20+.5)/20; FT:Coalesce("trinketSize",function() self:Apply() end,.1) end)
        FT:Tooltip(self.sizeSlider,"Size","Button size (70% to 150%).")
        self.move=FT:QuietButton(frame,"",240,32,"move"); self.move:SetPoint("TOPLEFT",24,-264)
        self.move:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.move,"Move buttons","Unlock, drag the buttons, then click again to lock. Not in a fight.")
        local reset=FT:QuietButton(frame,"Reset position",240,32,"reset"); reset:SetPoint("TOPLEFT",276,-264)
        reset:SetScript("OnClick",function() if not busy() then self:ResetPosition() end end)
        FT:Tooltip(reset,"Reset position","Put the buttons back near the middle of the screen.")
        self.mouseover=FT:QuietButton(frame,"",240,32,"INV_Misc_Spyglass_02"); self.mouseover:SetPoint("TOPLEFT",24,-224)
        self.mouseover:SetScript("OnClick",function() local s=self:Settings(); s.mouseover=not s.mouseover; self:Fade(); self:Refresh() end)
        FT:Tooltip(self.mouseover,"Show on mouseover","Invisible until you point at them. They still work.")
        self.hideEmpty=FT:QuietButton(frame,"",240,32,"INV_Misc_Bag_08"); self.hideEmpty:SetPoint("TOPLEFT",276,-224)
        self.hideEmpty:SetScript("OnClick",function() local s=self:Settings(); s.hideEmpty=not s.hideEmpty; self:Apply() end)
        FT:Tooltip(self.hideEmpty,"Hide without trinkets","No buttons while you have no trinket.")
        self.note=FT:Label(frame,"",12); self.note:SetPoint("TOPLEFT",24,-308); self.note:SetWidth(492); self.note:SetTextColor(.66,.59,.48)
        self.callout=FT:Callout(frame,492,"INV_Jewelry_Talisman_07"); self.callout:SetPoint("TOPLEFT",24,-330)
        -- Equipping or looting a trinket changes what the box says.
        FT:Sections(frame,{{"Buttons",self.layout},{"Position",self.move}})
        frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED"); frame:RegisterEvent("BAG_UPDATE_DELAYED")
        frame:SetScript("OnEvent",function() if frame:IsShown() then FT:Coalesce("trinketPage",function() self:Refresh() end,.2) end end)
        frame:HookScript("OnHide",function() if self.moving then self:SetMoving(false) end end)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Trinkets",T)
T.events=CreateFrame("Frame")
T.events:RegisterEvent("PLAYER_LOGIN"); T.events:RegisterEvent("PLAYER_REGEN_ENABLED")
T.events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then T:Apply()
    elseif event=="PLAYER_REGEN_ENABLED" then
        if T.pending then T:Apply() end
        if next(T.queue) then T:RunQueue() end
    else FT:Coalesce("trinkets",function()
        T:Update()
        -- A trinket came or went: show or hide the buttons (after the fight
        -- if in one; secure buttons can't be shown or hidden then).
        if T.bar and (event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED") and T.bar:IsShown()~=T:Wanted() then T:Apply() end
    end,.1) end
end)
