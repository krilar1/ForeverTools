local _,FT=...
-- Move game windows (On-screen info > Move game windows, off by default).
-- With it on, the game's own windows (character, spellbook, calendar, quest
-- log, vendor, and so on) can be dragged by any empty spot, usually the
-- title bar. Each window remembers where you put it until you reset it
-- (one at a time on the page, or all at once).
--   * Nothing is replaced: the window gets a drag hook and, when it opens,
--     is put back where you left it (the game places many windows itself
--     each time they open, so this runs right after it).
--   * Windows that hold action buttons are protected by the game during a
--     fight: they can't be dragged then, and a place they need is set as
--     soon as the fight ends.
--   * Windows that load later (calendar, talents, professions and so on)
--     are picked up the moment the game loads them.
--   * Off: the hooks do nothing and windows open where the game puts them.
local M={known={},originals={},pending={},editMode={}}
-- Windows that can be moved, by the game's name for them. Ones this client
-- doesn't have are skipped.
M.WINDOWS={
    {"CharacterFrame","Character"},{"SpellBookFrame","Spellbook"},{"PlayerTalentFrame","Talents"},{"TalentFrame","Talents"},
    {"QuestLogFrame","Quest log"},{"QuestFrame","Quest"},{"GossipFrame","NPC chat"},{"FriendsFrame","Social"},
    {"GuildFrame","Guild"},{"CommunitiesFrame","Guild and communities"},{"CalendarFrame","Calendar"},
    {"MerchantFrame","Vendor"},{"MailFrame","Mailbox"},{"OpenMailFrame","Letter"},{"BankFrame","Bank"},
    {"TradeFrame","Trade"},{"ClassTrainerFrame","Trainer"},{"TradeSkillFrame","Professions"},{"ProfessionsFrame","Professions"},
    {"CraftFrame","Crafting"},{"AuctionFrame","Auction house"},{"AuctionHouseFrame","Auction house"},
    {"TaxiFrame","Flight master"},{"DressUpFrame","Dressing room"},{"LootFrame","Loot"},
    {"PVPFrame","PvP"},{"PVPUIFrame","PvP"},{"HonorFrame","Honor"},{"LFGParentFrame","Looking for group"},{"LFDParentFrame","Dungeon finder"},
    {"PVEFrame","Group finder"},{"AchievementFrame","Achievements"},{"InspectFrame","Inspect"},{"MacroFrame","Macros"},
    {"ItemTextFrame","Book or note"},{"TabardFrame","Tabard designer"},{"GuildRegistrarFrame","Guild charter"},{"PetitionFrame","Petition"},
    {"PetStableFrame","Stable"},{"StableFrame","Stable"},{"AddonList","Addon list"},{"TimeManagerFrame","Clock"},
    {"EncounterJournal","Dungeon journal"},{"CollectionsJournal","Collections"},{"ItemSocketingFrame","Socketing"},
    {"GameMenuFrame","Game menu"},{"ChatConfigFrame","Chat settings"},{"BarberShopFrame","Barber"},{"ReadyCheckFrame","Ready check"},
    {"WorldMapFrame","World map"},{"PlayerSpellsFrame","Spellbook and talents"},{"ProfessionsBookFrame","Professions book"},
    {"SettingsPanel","Settings"},{"QuestLogPopupDetailFrame","Quest details"},{"ChannelFrame","Chat channels"},{"RaidParentFrame","Raid"},
    {"GuildBankFrame","Guild bank"},{"ProfessionsCustomerOrdersFrame","Crafting orders"},{"WardrobeFrame","Appearances"},
    {"ContainerFrameCombinedBags","Bags"},{"ContainerFrame1","Backpack"},{"ContainerFrame2","Bag 1"},{"ContainerFrame3","Bag 2"},
    {"ContainerFrame4","Bag 3"},{"ContainerFrame5","Bag 4"},{"ContainerFrame6","Reagent bag"},{"ContainerFrame7","Bank bag 1"},
    {"ContainerFrame8","Bank bag 2"},{"ContainerFrame9","Bank bag 3"},{"ContainerFrame10","Bank bag 4"},{"ContainerFrame11","Bank bag 5"},
    {"ContainerFrame12","Bank bag 6"},{"ContainerFrame13","Bank bag 7"},{"KeyRingFrame","Keyring"},
    -- "World refresh in N minutes": a notice above the chat, not in Edit Mode.
    {"ShardTransferImminentFrame","World refresh notice"},
}
local LABEL={}
local REFRESH="ShardTransferImminentFrame"
local BLUE={.51,.773,1}
for _,entry in ipairs(M.WINDOWS) do LABEL[entry[1]]=entry[2] end
local function safe(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function busy() return InCombatLockdown and InCombatLockdown() end
function M:Settings()
    if type(FT.db.moveWindows)~="table" then FT.db.moveWindows={} end
    local s=FT.db.moveWindows
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.frames)~="table" then s.frames={} end
    -- Drag the game's windows any time (not only after "Move windows now").
    if type(s.anytime)~="boolean" then s.anytime=false end
    -- A bar on the world refresh notice that fills as the refresh nears.
    if type(s.refreshBar)~="boolean" then s.refreshBar=false end
    for name,p in pairs(s.frames) do
        if type(name)~="string" or type(p)~="table" or type(p.x)~="number" or type(p.y)~="number" then s.frames[name]=nil end
    end
    return s
end
-- A protected window can't be moved during a fight (the game blocks it).
local function locked(frame) return busy() and frame.IsProtected and frame:IsProtected() end
-- The window's own place, where the game put it (for Reset). Taken again
-- each time the game places a window we haven't moved.
local function remember(self,frame,name,again)
    if (self.originals[name] and not again) or not frame.GetNumPoints then return end
    local points={}
    for i=1,frame:GetNumPoints() do
        local p,rel,rp,x,y=frame:GetPoint(i)
        if not (safe(p) and safe(x) and safe(y)) then return end
        points[#points+1]={p,rel,rp,x,y}
    end
    if #points>0 then self.originals[name]=points end
end
-- frame.ftGrowUp (Bags > special bag rows): how much taller than the game
-- makes it the window is now; it grows up, so its top sits that much higher.
local function growUp(frame) local v=frame and tonumber(frame.ftGrowUp); return v or 0 end
function M:Place(frame,name)
    local s=self:Settings(); local p=s.frames[name]
    if not s.enabled or not p or not frame then return end
    -- The reagent bag tucked into the all-in-one bag stays tucked away.
    if frame.ftRowsParked or self.dragging==frame then return end
    -- Already there: nothing to do (no needless redraw of the window).
    if frame:GetNumPoints()==1 then
        local point,rel,relPoint,x,y=frame:GetPoint(1)
        if point=="TOPLEFT" and rel==UIParent and relPoint=="BOTTOMLEFT" and safe(x) and safe(y) and math.abs(x-p.x)<.5 and math.abs(y-(p.y+growUp(frame)))<.5 then return end
    end
    if locked(frame) then self.pending[name]=true; self:WatchFight(); return end
    frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",p.x,p.y+growUp(frame))
end
-- Back where the game puts it, right away (not only the next time it opens).
function M:Restore(frame,name)
    if not frame or locked(frame) then return end
    local points=self.originals[name]
    if points and #points>0 then
        frame:ClearAllPoints()
        for _,pt in ipairs(points) do pcall(frame.SetPoint,frame,pt[1],pt[2],pt[3],pt[4],pt[5]) end
    end
    -- Never by hiding and showing it, or asking the game to place its bags
    -- again: run from an addon, that leaves the game's windows marked as
    -- touched by an addon and can get the game's own actions blocked. A
    -- window we never saw placed goes back the next time it opens.
end
-- A strip along the top of the window (its title bar) to drag it by, so
-- windows whose insides are covered by buttons and lists can be moved too.
-- It stops short of the close button in the top right corner.
function M:Handle(frame,name)
    if frame.ftMoveHandle then return end
    local h=CreateFrame("Frame",nil,frame)
    h:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0); h:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-34,0); h:SetHeight(26)
    h:SetFrameLevel((frame:GetFrameLevel() or 0)+20)
    h:EnableMouse(false); h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart",function() self:Start(frame,name) end)
    h:SetScript("OnDragStop",function() self:Stop(frame,name) end)
    frame.ftMoveHandle=h
end
function M:Start(f,name)
    local s=self:Settings()
    if not s.enabled or not (self.moving or s.anytime or self.withMovers) then return end
    if locked(f) then FT:Toast(LABEL[name].." can't be moved during a fight.",2); return end
    if not self:Settings().frames[name] then remember(self,f,name,true) end
    self.dragging=f; f:StartMoving()
end
function M:Stop(f,name)
    if self.dragging~=f then return end
    self.dragging=nil; f:StopMovingOrSizing(); self:Save(f,name)
end
-- The title strips take the mouse only while unlocked (Move windows / Done).
function M:Unlocked() local s=self:Settings(); return (s.enabled and (self.moving or s.anytime or self.withMovers)) and true or false end
-- Move elements is on: open game windows can be dragged too (no bar of our
-- own, nothing opened). Turns Move game windows on, since a moved window
-- needs it to stay where you put it.
function M:WithMovers(on)
    self.withMovers=on and true or nil
    if on then
        local s=self:Settings()
        if not s.enabled then s.enabled=true; self:Apply() end
        self:AttachAll(); self:HookPanels()
    end
    self:Handles(self:Unlocked())
    self:RefreshBar(); self:StandIn(self:Unlocked() and (self.moving or self.withMovers)); self:Cover()
    self:Refresh()
end
function M:Handles(on)
    for frame in pairs(self.known) do if frame.ftMoveHandle then frame.ftMoveHandle:EnableMouse(on and true or false) end end
end
function M:Save(frame,name)
    local left,top=frame:GetLeft(),frame:GetTop()
    if not (safe(left) and safe(top)) then return end
    self:Settings().frames[name]={x=left,y=top-growUp(frame)}
    -- Keep the game from saving its own copy of the place in its layout file.
    if frame.SetUserPlaced then pcall(frame.SetUserPlaced,frame,false) end
    self:Place(frame,name)
    self:Refresh()
end
-- Anything Edit Mode places (bars, unit frames, minimap, chat, and on some
-- game versions the bags or loot window) is left to Edit Mode.
function M:EditModeOwned(frame)
    if frame.system~=nil or frame.systemIndex~=nil or frame.isManagedFrame or type(frame.systemInfo)=="table" then return true end
    local manager=_G.EditModeManagerFrame
    local list=manager and manager.registeredSystemFrames
    if type(list)=="table" then for _,f in ipairs(list) do if f==frame then return true end end end
    return false
end
function M:Attach(frame,name)
    if not frame or self.known[frame] or (frame.IsForbidden and frame:IsForbidden()) then return end
    if self:EditModeOwned(frame) then self.editMode[name]=true; return end
    if not frame.HookScript or not frame.SetMovable or not frame.RegisterForDrag then return end
    -- Protected windows can only be set up out of a fight.
    if locked(frame) then self.pending["attach:"..name]=true; self:WatchFight(); return end
    self.known[frame]=name
    remember(self,frame,name)
    frame:SetMovable(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:RegisterForDrag("LeftButton")
    frame:HookScript("OnDragStart",function(f) self:Start(f,name) end)
    frame:HookScript("OnDragStop",function(f) self:Stop(f,name) end)
    self:Handle(frame,name); frame.ftMoveHandle:EnableMouse(self:Unlocked())
    -- The game places many windows each time they open: put it back after.
    frame:HookScript("OnShow",function(f)
        if not self:Settings().enabled then return end
        if not self:Settings().frames[name] then
            FT:Coalesce("moveWindowSeen"..name,function() if f:IsShown() and not self:Settings().frames[name] then remember(self,f,name,true) end end,0)
            return
        end
        self:Place(f,name)
        FT:Coalesce("moveWindow"..name,function() if f:IsShown() then self:Place(f,name) end end,0)
    end)
    if frame:IsShown() then self:Place(frame,name) end
end
function M:AttachAll()
    for _,entry in ipairs(self.WINDOWS) do
        local frame=_G[entry[1]]
        if type(frame)=="table" then self:Attach(frame,entry[1]) end
    end
end
-- The game's own panel layout runs whenever a side window opens or closes.
function M:HookPanels()
    if self.panelsHooked or not hooksecurefunc then return end
    self.panelsHooked=true
    -- Right away (same frame as the game's own placing), so a moved window
    -- never shows in the game's spot first.
    local function again()
        if not FT.dbReady or not self:Settings().enabled then return end
        self:PlaceShown()
    end
    if type(UpdateUIPanelPositions)=="function" then hooksecurefunc("UpdateUIPanelPositions",again) end
    if type(FramePositionDelegate)=="table" and type(FramePositionDelegate.UpdateUIPanelPositions)=="function" then hooksecurefunc(FramePositionDelegate,"UpdateUIPanelPositions",again) end
    -- Bags are stacked again by the game each time one opens or closes.
    if type(UpdateContainerFrameAnchors)=="function" then hooksecurefunc("UpdateContainerFrameAnchors",again) end
end
function M:PlaceShown()
    for frame,name in pairs(self.known) do
        if frame:IsShown() and self.dragging~=frame then
            if self:Settings().frames[name] then self:Place(frame,name) else remember(self,frame,name,true) end
        end
    end
end
function M:WatchFight() self.events:RegisterEvent("PLAYER_REGEN_ENABLED") end
function M:AfterFight()
    self.events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local list=self.pending; self.pending={}
    for key in pairs(list) do
        local name=key:match("^attach:(.+)$")
        if name then self:Attach(_G[name],name)
        else local frame=_G[key]; if frame and frame:IsShown() then self:Place(frame,key) end end
    end
end
-- Put one window back where the game puts it.
function M:Reset(name)
    local s=self:Settings(); s.frames[name]=nil
    local frame=_G[name]
    if frame and self.known[frame] then self:Restore(frame,name) end
    if name==REFRESH and self.standIn and self.standIn:IsShown() then self:StandIn(true) end
    self:Refresh()
end
function M:ResetAll()
    local names={}
    for name in pairs(self:Settings().frames) do names[#names+1]=name end
    for _,name in ipairs(names) do self:Reset(name) end
end
-- Unlocked: drag windows by their title bar; a bar at the top of the screen
-- says so and locks them again (Done). /ft moveall does the same.
function M:SetMoving(on)
    local s=self:Settings()
    if on and not s.enabled then s.enabled=true; self:Apply() end
    self.moving=on and true or false
    if self.moving then self:AttachAll(); self:HookPanels() end
    self:Handles(self:Unlocked())
    local bar=self:Bar(); bar:SetShown(self.moving)
    self:RefreshBar(); self:StandIn(self:Unlocked() and (self.moving or self.withMovers)); self:Cover()
    self:Refresh()
end
function M:ToggleMoving() self:SetMoving(not self.moving) end
function M:Bar()
    if self.bar then return self.bar end
    local bar=CreateFrame("Frame","ForeverToolsMoveWindowsBar",UIParent)
    bar:SetSize(520,48); bar:SetPoint("TOP",UIParent,"TOP",0,-80); bar:SetFrameStrata("DIALOG"); bar:SetClampedToScreen(true)
    FT:Panel(bar)
    local text=FT:Label(bar,"Moving game windows: drag them by the title bar",13,true); text:SetPoint("LEFT",16,0); text:SetWidth(390); text:SetJustifyH("LEFT")
    local done=FT:AccentButton(bar,"Done",88,30,"confirm"); done:SetPoint("RIGHT",-10,0)
    done:SetScript("OnClick",function() self:SetMoving(false) end)
    FT:Tooltip(done,"Done","Lock the windows where they are.")
    bar:Hide()
    self.bar=bar
    return bar
end
function M:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if not s.enabled and self.moving then self.moving=false; if self.bar then self.bar:Hide() end end
    self:Handles(self:Unlocked())
    self:RefreshBar()
    if s.enabled then
        self:AttachAll(); self:HookPanels(); self:PlaceShown()
    else
        -- Off: open windows go back to where the game had them.
        for frame,name in pairs(self.known) do if s.frames[name] and frame:IsShown() then self:Restore(frame,name) end end
    end
    self:Refresh()
end
-- Moved windows, by label (for the page).
function M:Moved()
    local out={}
    for name in pairs(self:Settings().frames) do out[#out+1]={name=name,label=LABEL[name] or name} end
    table.sort(out,function(a,b) if a.label~=b.label then return a.label<b.label end; return a.name<b.name end)
    return out
end
-- World refresh notice ------------------------------------------------------
-- "World refresh in N minutes" only shows before a refresh, so while you
-- move windows a look-alike stands in for it where it will show, to drag.
function M:RefreshBar()
    local f=_G[REFRESH]
    if type(f)~="table" or f.ftRefreshBar or not f.HookScript then return end
    local bar=FT:ProgressBar(f,4); f.ftRefreshBar=bar
    bar:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",10,8); bar:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",-10,8)
    bar:SetColor(unpack(BLUE)); bar:Hide()
    -- Runs after the game's own update, which sets the height each frame.
    f:HookScript("OnUpdate",function(frame)
        local t,start=frame.timer,frame.startingTimer
        local on=FT.dbReady and M:Settings().refreshBar and safe(t) and safe(start) and type(t)=="number" and type(start)=="number" and start>0 and t>0
        bar:SetShown(on and true or false)
        if on then bar:SetFraction(1-t/start); frame:SetHeight(frame:GetHeight()+8) end
    end)
    -- The chat's alert list places its notices again whenever one comes or
    -- goes: a moved notice goes back to your spot right after.
    local list=_G.ChatAlertFrame
    if type(list)=="table" and type(list.UpdateAnchors)=="function" and hooksecurefunc then
        hooksecurefunc(list,"UpdateAnchors",function()
            local s=M:Settings()
            if s.enabled and s.frames[REFRESH] and f:IsShown() and M.dragging~=f then M:Place(f,REFRESH) end
        end)
    end
    f:HookScript("OnShow",function() if M.standIn then M.standIn:Hide() end; M:Cover() end)
    f:HookScript("OnHide",function() M:Cover(); if M:Unlocked() and (M.moving or M.withMovers) then M:StandIn(true) end end)
end
-- The real notice while you move things: the same gold box as other
-- elements, with its name, to drag it by.
function M:Cover()
    local real=_G[REFRESH]
    local on=type(real)=="table" and real:IsShown() and self:Unlocked() and (self.moving or self.withMovers)
    local c=self.cover
    if not on then if c then c:Hide() end; return end
    if not c then
        c=CreateFrame("Frame",nil,UIParent); self.cover=c
        c:SetFrameStrata("DIALOG"); c:EnableMouse(true); c:RegisterForDrag("LeftButton")
        FT:MoverBox(c,0)
        c.label=FT:Label(c,"World refresh notice",12,true); c.label:SetPoint("BOTTOMLEFT",c,"TOPLEFT",0,3); c.label:SetTextColor(1,.82,0)
        c:SetScript("OnDragStart",function() local r=_G[REFRESH]; if r then M:Start(r,REFRESH) end end)
        c:SetScript("OnDragStop",function() local r=_G[REFRESH]; if r then M:Stop(r,REFRESH) end end)
        FT:Tooltip(c,"World refresh notice","Drag to move it. Reset on the Move game windows page puts it back.")
    end
    c:ClearAllPoints(); c:SetAllPoints(real); c:Show()
end
function M:StandIn(on)
    local real=_G[REFRESH]
    if not on or type(real)~="table" or real:IsShown() then if self.standIn then self.standIn:Hide() end; return end
    local f=self.standIn
    if not f then
        f=CreateFrame("Frame","ForeverToolsRefreshStandIn",UIParent); self.standIn=f
        f:SetWidth(250); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
        FT:Panel(f)
        f.box=CreateFrame("Frame",nil,f); f.box:SetAllPoints(); f.box:SetFrameLevel(f:GetFrameLevel()+5); FT:MoverBox(f.box,0)
        f.name=FT:Label(f,"World refresh notice",12,true); f.name:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,3); f.name:SetTextColor(1,.82,0)
        f.text=FT:Label(f,"World refresh in 9 Minutes.",13)
        f.text:SetPoint("TOPLEFT",10,-10); f.text:SetPoint("RIGHT",-10,0); f.text:SetJustifyH("LEFT"); f.text:SetTextColor(unpack(BLUE))
        if f.text.SetWordWrap then f.text:SetWordWrap(true) end
        f.hint=FT:Label(f,"An example: drag to move",11); f.hint:SetPoint("TOPLEFT",f,"BOTTOMLEFT",2,-4); f.hint:SetTextColor(.66,.59,.48)
        f.bar=FT:ProgressBar(f,4); f.bar:SetPoint("BOTTOMLEFT",10,8); f.bar:SetPoint("BOTTOMRIGHT",-10,8); f.bar:SetColor(unpack(BLUE))
        f:SetScript("OnUpdate",function(self_) self_.bar:SetFraction(((GetTime() or 0)%40)/40) end)
        f:SetScript("OnDragStart",function(self_) self_:StartMoving() end)
        f:SetScript("OnDragStop",function(self_)
            self_:StopMovingOrSizing()
            local left,top=self_:GetLeft(),self_:GetTop()
            if left and top then M:Settings().frames[REFRESH]={x=left,y=top}; M:Refresh() end
            M:StandIn(true)
        end)
        FT:Tooltip(f,"World refresh notice","Shows before a world refresh, with how long is left. Drag this example to where you want the notice.")
    end
    local bar=self:Settings().refreshBar
    f.bar:SetShown(bar)
    f:SetHeight((f.text:GetStringHeight() or 14)+20+(bar and 8 or 0))
    f:ClearAllPoints()
    local p=self:Settings().frames[REFRESH]
    if p then f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",p.x,p.y)
    else
        -- Where the game shows it: its own anchor (above the chat).
        local placed=false
        for i=1,(real.GetNumPoints and real:GetNumPoints() or 0) do
            local pt,rel,rp,x,y=real:GetPoint(i)
            if safe(pt) and safe(x) and safe(y) then f:SetPoint(pt,rel,rp,x,y); placed=true end
        end
        if not placed then f:SetPoint("BOTTOMLEFT",ChatFrame1 or UIParent,"TOPLEFT",30,90) end
    end
    f:Show()
end
-- Page -----------------------------------------------------------------------
local ROWS=8
function M:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Move game windows: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.unlock.label:SetText(self.moving and "Done moving" or "Move windows now"); FT:SetSelected(self.unlock,self.moving)
    self.anytime.label:SetText("Drag them any time: "..(s.anytime and "On" or "Off"))
    self.refreshToggle.label:SetText("World refresh progress bar: "..(s.refreshBar and "On" or "Off")); FT:SetSelected(self.refreshToggle,s.refreshBar)
    local list=self:Moved()
    for i=1,ROWS do
        local row=self.rows[i]; local e=list[i]
        if e then row.entry=e; row.label:SetText(e.label); row:Show() else row.entry=nil; row:Hide() end
    end
    self.empty:SetShown(#list==0)
    self.more:SetShown(#list>ROWS); self.more:SetText(#list>ROWS and string.format("And %d more (Reset all puts them back too).",#list-ROWS) or "")
    self.resetAll:SetEnabled(#list>0)
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
function M:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsMoveWindowsPage","Move game windows",540,680); self.frame=frame
        FT:PageInfo(frame,"Move game windows","Drag the game's own windows where you want them: character, spellbook, quest log, calendar, bank and more.\n\nClick Move windows now, drag by the title bar, then Done. Reset puts one back.\n\nWindows with action buttons can't move in a fight. Edit Mode frames stay with Edit Mode.")
        local hint=FT:Label(frame,"Drag game windows by their title bar.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,"move"); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function()
            local s=self:Settings(); s.enabled=not s.enabled; self:Apply()
            -- Turned on: straight into moving.
            if s.enabled then self:SetMoving(true) end
        end)
        FT:Tooltip(self.toggle,"Move game windows","Game windows open where you put them.")
        self.unlock=FT:QuietButton(frame,"",492,32,"move"); self.unlock:SetPoint("TOPLEFT",24,-130)
        self.unlock:SetScript("OnClick",function() self:ToggleMoving() end)
        FT:Tooltip(self.unlock,"Move windows now","Unlock game windows to drag them. Click Done to lock. Also /ft moveall.")
        self.anytime=FT:QuietButton(frame,"",492,32,"move"); self.anytime:SetPoint("TOPLEFT",24,-170)
        self.anytime:SetScript("OnClick",function() local s=self:Settings(); s.anytime=not s.anytime; if s.anytime then s.enabled=true end; self:Apply() end)
        FT:Tooltip(self.anytime,"Drag them any time","Drag title bars any time, without Move windows now.")
        self.refreshToggle=FT:QuietButton(frame,"",492,32,"Spell_Holy_BorrowedTime"); self.refreshToggle:SetPoint("TOPLEFT",24,-210)
        self.refreshToggle:SetScript("OnClick",function() local s=self:Settings(); s.refreshBar=not s.refreshBar; self:RefreshBar(); if self.standIn and self.standIn:IsShown() then self:StandIn(true) end; self:Refresh() end)
        FT:Tooltip(self.refreshToggle,"World refresh notice","A bar on the \"World refresh in N minutes\" notice that fills as the refresh nears. While you move windows, an example of the notice shows so you can drag it.")
        local title=FT:Label(frame,"Moved windows",14); title:SetPoint("TOPLEFT",24,-256); title:SetTextColor(1,.82,0)
        self.rows={}
        for i=1,ROWS do
            local row=CreateFrame("Frame",nil,frame); row:SetSize(492,34); row:SetPoint("TOPLEFT",24,-280-(i-1)*38)
            row.label=FT:Label(row,"",14); row.label:SetPoint("LEFT",8,0); row.label:SetWidth(330); row.label:SetJustifyH("LEFT")
            row.reset=FT:QuietButton(row,"Reset",140,30,"reset"); row.reset:SetPoint("RIGHT")
            row.reset:SetScript("OnClick",function() if row.entry then self:Reset(row.entry.name) end end)
            FT:Tooltip(row.reset,"Reset","Put this window back where the game puts it.")
            self.rows[i]=row
        end
        self.empty=FT:Label(frame,"None yet. Click Move windows now and drag a window.",13); self.empty:SetPoint("TOPLEFT",32,-288); self.empty:SetWidth(476); self.empty:SetTextColor(.66,.59,.48)
        self.more=FT:Label(frame,"",12); self.more:SetPoint("TOPLEFT",32,-284-ROWS*38); self.more:SetWidth(476); self.more:SetTextColor(.66,.59,.48)
        self.resetAll=FT:QuietButton(frame,"Reset all",240,32,"reset"); self.resetAll:SetPoint("TOPLEFT",24,-314-ROWS*38)
        self.resetAll:SetScript("OnClick",function() FT:Confirm("Put every moved window back?",function() self:ResetAll() end) end)
        FT:Tooltip(self.resetAll,"Reset all","Put every moved window back.")
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("MoveWindows",M)
M.events=CreateFrame("Frame")
M.events:RegisterEvent("PLAYER_LOGIN"); M.events:RegisterEvent("ADDON_LOADED")
M.events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_ENABLED" then M:AfterFight(); return end
    if not M:Settings().enabled then return end
    -- New windows (load-on-demand parts of the game) are picked up as they load.
    FT:Coalesce("moveWindowsAttach",function() M:AttachAll(); M:HookPanels() end,0)
end)
