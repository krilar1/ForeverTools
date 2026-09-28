local _,FT=...
-- Move elements: one click unlocks every on-screen element ForeverTools
-- draws, so they can all be dragged at once. Each element keeps its own
-- saved position and its own settings page; this only switches their
-- existing "move" modes on and off together. Blizzard's own frames stay in
-- the game's Edit Mode. Entering combat locks everything again.
local Movers={labels={}}
local function mod(name) return FT.modules[name] end
local function hasTarget() return UnitExists and UnitExists("target") and true or false end
-- Every element: whether it is in use, how to start and stop moving it,
-- the frame to label, how to reset it and which page holds its settings.
local elements={
    {key="fps",name="FPS counter",module="QualityOfLife",open="QualityOfLife",pad=8,
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.counter end, reset=function(m) m:ResetPosition() end},
    {key="leveling",name="Leveling stats",module="Leveling",open="Leveling",pad=6,
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.line end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil; m:Apply() end},
    {key="flight",name="Flight timer",module="FlightTimer",open="FlightTimer",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m.preview=true; m:Apply() end,
        stop=function(m) if m.preview then m:Drag(); m.dragging=false; m.preview=false; m:Apply() end end,
        frame=function(m) return m.display end,
        reset=function(m) local s=m:Settings(); s.x=.5; s.y=.5; m:Apply() end},
    {key="threat",name="Threat meter",module="Threat",open="Threat",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m.moverUnlock=true; m.previewing=true; m:Apply() end,
        stop=function(m)
            m.moverUnlock=false
            -- Its settings page shows the preview too; keep it while that is open.
            m.previewing=(m.frame and m.frame:IsShown() and not InCombatLockdown()) and true or false
            m:Apply()
        end,
        frame=function(m) return m.meter end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.width,s.height=nil,nil,nil,nil; m:Apply() end,
        resetTip="Put the meter back next to the damage meter, at its starting size."},
    {key="threatText",name="Threat % above target",module="Threat",open="Threat",
        used=function(m) return m:Settings().text==true end,
        -- It sits on the target portrait, so it can only move with a target.
        start=function(m) if hasTarget() then m:SetMovingText(true) end end,
        stop=function(m) if m.movingText then m:SetMovingText(false) end end,
        frame=function(m) return m.text end,
        reset=function(m) local s=m:Settings(); s.textX,s.textY=0,2; m:Apply() end,
        note="Needs a target, since it sits on the target portrait."},
    {key="rare",name="Rare alert",module="RareAlert",open="RareAlert",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,"Drag to move") end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.notice end,
        reset=function(m) local s=m:Settings(); s.x,s.y=nil,nil; m:Position() end},
    {key="reminders",name="Buff and cooldown reminders",module="BuffReminder",open="BuffReminder",
        used=function(m) local s=m:Settings(); local cd=mod("CooldownReminder"); return s.enabled==true or s.groupEnabled==true or (cd and cd:Settings().enabled==true) or false end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.badge end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil; m:Apply() end},
    {key="loot",name="Loot rolls",module="LootRoll",open="SystemGameplay",
        used=function() return true end,
        start=function(m) if not m.moving then m:ToggleMove() end end, stop=function(m) if m.moving then m:FinishMove() end end,
        frame=function(m) return m.box end,
        reset=function(m) m:UseDefault() end, resetTip="Loot rolls go back to where the game puts them."},
    {key="tooltip",name="Tooltip position",module="Tooltip",open="Tooltip",
        used=function(m) local s=m:Settings(); return (s.x~=nil and s.y~=nil) or (s.position~=nil and s.position~="Default") end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.previewFrame end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil; if m.moving then m:MovePreview() end; m:Refresh() end,
        resetTip="Tooltips go back to the spot chosen in Tooltip settings (or the game's default)."},
}
Movers.elements=elements
function Movers:Settings()
    if type(FT.db.movers)~="table" then FT.db.movers={} end
    local s=FT.db.movers
    if type(s.showUnused)~="boolean" then s.showUnused=false end
    return s
end
function Movers:Used(e)
    local m=mod(e.module); if not m then return false end
    local ok,value=pcall(e.used,m); return ok and value==true
end
-- A small name tag above each element while moving.
function Movers:Label(e,frame)
    local tag=self.labels[e.key]
    if not tag then
        tag=CreateFrame("Frame",nil,UIParent)
        tag.text=FT:Label(tag,e.name,12,true)
        tag.text:SetTextColor(1,.84,.45); tag.text:SetShadowOffset(1,-1); tag.text:SetShadowColor(0,0,0,1)
        tag.caption=FT:Caption(tag.text,frame,"above",e.pad or 0)
        self.labels[e.key]=tag
    end
    tag.caption.frame=frame
    tag:SetParent(frame); tag:SetFrameStrata("TOOLTIP")
    tag:ClearAllPoints(); tag:SetAllPoints(frame)
    tag:Show(); tag.text:Show(); tag.text:SetShown(true)
end
function Movers:Start()
    if InCombatLockdown() then FT:Toast("Leave combat to move elements.",3); return end
    if FT.home then FT.home:Hide() end
    self.active=true
    local showUnused=self:Settings().showUnused
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and (showUnused or self:Used(e)) then
            if pcall(e.start,m) then self.running=self.running or {}; self.running[e.key]=true end
        end
    end
    -- Some elements build their frame a moment later (the threat meter).
    self:LabelAll(); C_Timer.After(.2,function() if self.active then self:LabelAll() end end)
    self:Bar():Show()
    self:Refresh()
end
function Movers:LabelAll()
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and self.running and self.running[e.key] then local frame=e.frame(m); if frame then self:Label(e,frame) end end
    end
end
function Movers:Stop()
    self.active=false
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and self.running and self.running[e.key] then pcall(e.stop,m) end
        if self.labels[e.key] then self.labels[e.key]:Hide() end
    end
    self.running=nil
    if self.bar then self.bar:Hide() end
    self:Refresh()
    if FT.modules.System then FT.modules.System:Refresh() end
end
function Movers:Toggle() if self.active then self:Stop() else self:Start() end end
-- Switching "show unused" while moving adds or removes those elements now.
function Movers:Restart() if self.active then self:Stop(); self:Start() end end
function Movers:Reset(e)
    local m=mod(e.module); if not m then return end
    if InCombatLockdown() then FT:Toast("Leave combat to reset positions.",3); return end
    pcall(e.reset,m)
    -- Some resets lock their element (loot rolls); keep it movable.
    if self.active and self.running and self.running[e.key] then pcall(e.start,m); local frame=e.frame(m); if frame then self:Label(e,frame) end end
end
-- The bar at the top of the screen while moving.
function Movers:Bar()
    if self.bar then return self.bar end
    local bar=CreateFrame("Frame","ForeverToolsMoverBar",UIParent)
    bar:SetSize(460,48); bar:SetPoint("TOP",UIParent,"TOP",0,-24); bar:SetFrameStrata("DIALOG"); bar:SetClampedToScreen(true)
    FT:Panel(bar)
    local text=FT:Label(bar,"Move elements",14,true); text:SetPoint("LEFT",18,0)
    local done=FT:AccentButton(bar,"Done",88,30,"confirm"); done:SetPoint("RIGHT",-10,0)
    done:SetScript("OnClick",function() self:Stop() end)
    FT:Tooltip(done,"Done","Lock everything in place. Entering combat locks them too.")
    local settings=FT:QuietButton(bar,"Settings",104,30,"generic"); settings:SetPoint("RIGHT",done,"LEFT",-8,0)
    settings:SetScript("OnClick",function() FT:OpenModule("Movers") end)
    FT:Tooltip(settings,"Move elements settings","Show or hide unused elements while moving, and reset positions.")
    self.bar=bar
    return bar
end

-- Settings page
function Movers:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Move elements: "..(self.active and "On" or "Off")); FT:SetSelected(self.toggle,self.active)
    self.unused.label:SetText("Show unused elements: "..(s.showUnused and "On" or "Off")); FT:SetSelected(self.unused,s.showUnused)
    for _,row in ipairs(self.rows) do
        local used=self:Used(row.e)
        row.button.label:SetText(row.e.name.."  |cffa8977a- "..(used and "On" or "Off").."|r")
    end
end
function Movers:Open()
    if not self.frame then
        local rowsTop=184
        local height=rowsTop+#elements*40+32+24
        local frame=FT:Window("ForeverToolsMovers","Move elements",520,height); self.frame=frame
        FT:BackTo(frame,"SystemDisplay")
        FT:PageInfo(frame,"Move elements","Unlock every on-screen element ForeverTools draws and drag them where you like, all at once. Click Done on the bar at the top, or enter combat, to lock them. Action bars, unit frames and other game frames move in the game's Edit Mode.")
        self.toggle=FT:AccentButton(frame,"",472,34,"move"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() self:Toggle() end)
        FT:Tooltip(self.toggle,"Move elements","Unlock all elements so you can drag them. The same as the Move elements button on the main menu.")
        self.unused=FT:QuietButton(frame,"",472,32,"generic"); self.unused:SetPoint("TOPLEFT",24,-106)
        self.unused:SetScript("OnClick",function() local s=self:Settings(); s.showUnused=not s.showUnused; self:Restart(); self:Refresh() end)
        FT:Tooltip(self.unused,"Show unused elements","Also show elements you have turned off, so you can place them before using them. Off shows only what you use.")
        local head=FT:Label(frame,"Elements",15,true); head:SetPoint("TOPLEFT",24,-154); FT:SectionHeading(head,"INV_Misc_Map_01",380)
        self.rows={}
        for i,e in ipairs(elements) do
            local y=-rowsTop-(i-1)*40
            local b=FT:QuietButton(frame,e.name,330,32,"move"); b:SetPoint("TOPLEFT",24,y)
            -- Its own page has its own move and preview, so lock everything first.
            b:SetScript("OnClick",function() if self.active then self:Stop() end; FT:OpenModule(e.open) end)
            FT:Tooltip(b,e.name,"Click to open its settings page. This locks all elements first."..(e.note and ("\n\n"..e.note) or ""))
            local r=FT:QuietButton(frame,"Reset",130,32,"reset"); r:SetPoint("TOPLEFT",366,y)
            r:SetScript("OnClick",function() self:Reset(e) end)
            FT:Tooltip(r,"Reset "..e.name:lower(),e.resetTip or "Put it back where it starts.")
            self.rows[i]={e=e,button=b}
        end
        local all=FT:QuietButton(frame,"Reset all positions",472,32,"reset"); all:SetPoint("TOPLEFT",24,-rowsTop-#elements*40)
        all:SetScript("OnClick",function() FT:Confirm("Put every element back where it starts?",function() for _,e in ipairs(elements) do self:Reset(e) end end) end)
        FT:Tooltip(all,"Reset all positions","Put every element on this list back where it starts.")
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Movers",Movers)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent",function() if Movers.active then Movers:Stop(); FT:Toast("Elements locked for combat.",2.5) end end)
