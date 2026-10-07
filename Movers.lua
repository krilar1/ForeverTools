local _,FT=...
-- Move elements: one click unlocks every on-screen element ForeverTools
-- draws, so they can all be dragged at once. Each element keeps its own
-- saved position and its own settings page; this only switches their
-- existing "move" modes on and off together. Blizzard's own frames stay in
-- the game's Edit Mode. Entering combat locks everything again.
local Movers={labels={}}
local function mod(name) return FT.modules[name] end
local function hasTarget() return UnitExists and UnitExists("target") and true or false end
-- Magnetic elements: one dropped on top of another slides off it, so two
-- never sit on the same spot. Each element says how to move itself by a few
-- pixels (nudge), the way its own drag does, so the new place is saved.
--   byOffset: elements that follow the mouse plus an offset. Right after a
--     drop the mouse has not moved, so changing the offset moves the element.
--   byFrame: elements that save where their frame is when a drag ends.
local function byOffset(m,xKey,yKey,dx,dy,update)
    if type(m[xKey])~="number" or type(m[yKey])~="number" or not update then return end
    m[xKey],m[yKey]=m[xKey]+dx,m[yKey]+dy
    m.dragging=true; update(m); m.dragging=false
end
local function byFrame(frame,dx,dy)
    if not frame then return end
    local cx,cy=frame:GetCenter(); if not cx then return end
    -- dx,dy are in the screen's units; the frame may have a scale of its own.
    local ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",cx+dx/ratio,cy+dy/ratio)
    local stop=frame:GetScript("OnDragStop"); if stop then stop(frame) end
end
-- Every element: whether it is in use, how to start and stop moving it,
-- the frame to label, how to reset it and which page holds its settings.
local elements={
    {key="fps",name="FPS counter",module="QualityOfLife",open="QualityOfLife",pad=8,
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.counter end, reset=function(m) m:ResetPosition() end,
        nudge=function(m,dx,dy) byOffset(m,"dragOffsetX","dragOffsetY",dx,dy,m.UpdateDrag); m:RestorePosition() end},
    {key="leveling",name="Leveling stats",module="Leveling",open="Leveling",pad=6,
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.line end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil; m:Apply() end,
        nudge=function(m,dx,dy) byOffset(m,"dragOffsetX","dragOffsetY",dx,dy,m.UpdateDrag); m:Position() end},
    {key="flight",name="Flight timer",module="FlightTimer",open="FlightTimer",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m.preview=true; m:Apply() end,
        stop=function(m) if m.preview then m:Drag(); m.dragging=false; m.preview=false; m:Apply() end end,
        frame=function(m) return m.display end,
        reset=function(m) local s=m:Settings(); s.x=.5; s.y=.5; m:Apply() end,
        nudge=function(m,dx,dy) byOffset(m,"dragX","dragY",dx,dy,m.Drag) end},
    {key="threat",name="Threat meter",module="Threat",open="Threat",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m.moverUnlock=true; m.previewing=true; m:Apply() end,
        stop=function(m)
            m.moverUnlock=false
            -- Its settings page shows the preview too; keep it while that is open.
            m.previewing=(m.frame and m.frame:IsShown() and not InCombatLockdown()) and true or false
            m:Apply()
        end,
        frame=function(m) return m.meter end, nudge=function(m,dx,dy) byFrame(m.meter,dx,dy) end,
        reset=function(m) local s=m:Settings(); s.x,s.y,s.width,s.height=nil,nil,nil,nil; m:Apply() end,
        resetTip="Put the meter back next to the damage meter, at its starting size."},
    {key="threatText",name="Threat % above target",module="Threat",open="Threat",
        used=function(m) return m:Settings().text==true end,
        -- It sits on the target portrait, so it can only move with a target.
        start=function(m) if hasTarget() then m:SetMovingText(true) end end,
        stop=function(m) if m.movingText then m:SetMovingText(false) end end,
        frame=function(m) return m.text end, nudge=function(m,dx,dy) byFrame(m.text,dx,dy) end,
        reset=function(m) local s=m:Settings(); s.textX,s.textY=0,2; m:Apply() end,
        note="Needs a target, since it sits on the target portrait."},
    {key="rare",name="Rare alert",module="RareAlert",open="RareAlert",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true,"Drag to move") end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.notice end, nudge=function(m,dx,dy) byFrame(m.notice,dx,dy) end,
        reset=function(m) local s=m:Settings(); s.x,s.y=nil,nil; m:Position() end},
    {key="queue",name="Battleground timer",module="QueueTimer",open="QueueTimer",
        used=function(m) return m:Settings().enabled==true end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.bar end, nudge=function(m,dx,dy) byFrame(m.bar,dx,dy) end,
        reset=function(m) m:ResetPosition() end,
        resetTip="Put the timer back in the middle of the screen."},
    {key="reminders",name="Buff and cooldown reminders",module="BuffReminder",open="BuffReminder",
        used=function(m) local s=m:Settings(); local cd=mod("CooldownReminder"); return s.enabled==true or s.groupEnabled==true or (cd and cd:Settings().enabled==true) or false end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.badge end, nudge=function(m,dx,dy) byOffset(m,"dragX","dragY",dx,dy,m.DragUpdate) end,
        reset=function(m)
            local s=m:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil
            -- Buffs with their own notice go back to their default spots too.
            for _,st in pairs(type(s.styles)=="table" and s.styles or {}) do if type(st)=="table" then st.x,st.y,st.screenWidth,st.screenHeight=nil,nil,nil,nil end end
            m.styleStamp=(m.styleStamp or 0)+1; m:Apply()
        end},
    {key="loot",name="Loot rolls",module="LootRoll",open="SystemGameplay",
        used=function() return true end,
        start=function(m) if not m.moving then m:ToggleMove() end end, stop=function(m) if m.moving then m:FinishMove() end end,
        frame=function(m) return m.box end, nudge=function(m,dx,dy) byOffset(m,"offsetX","offsetY",dx,dy,m.UpdateDrag) end,
        reset=function(m) m:UseDefault() end, resetTip="Loot rolls go back to where the game puts them."},
    {key="roleBar",name="Role key bar",module="SpellBinds",open="SpellBinds",
        used=function(m) local s=m:Settings(); return s.enabled and s.bar end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.bar end, nudge=function(m,dx,dy) byFrame(m.bar,dx,dy) end,
        reset=function(m) local s=m:Settings(); s.x,s.y=nil,nil; m:Place() end,
        resetTip="Put the role key bar back above the middle of your action bars."},
    {key="tooltip",name="Tooltip position",module="Tooltip",open="Tooltip",
        used=function(m) local s=m:Settings(); return (s.x~=nil and s.y~=nil) or (s.position~=nil and s.position~="Default") end,
        start=function(m) m:SetMoving(true) end, stop=function(m) if m.moving then m:SetMoving(false) end end,
        frame=function(m) return m.previewFrame end, nudge=function(m,dx,dy) byOffset(m,"dragX","dragY",dx,dy,m.UpdateMove) end,
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
-- A frame's place in the screen's units: left, bottom, right, top.
local function rectOf(frame)
    if not frame or not frame.GetRect then return nil end
    local l,b,w,h=frame:GetRect()
    if not l or not w then return nil end
    for _,v in ipairs({l,b,w,h}) do if (issecretvalue and issecretvalue(v)) or type(v)~="number" then return nil end end
    local ratio=frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return {l=l*ratio,b=b*ratio,r=(l+w)*ratio,t=(b+h)*ratio}
end
-- Room between two elements. While everything is unlocked each one wears a
-- name tag, so they stand a little further apart.
local function gap() return Movers.active and 20 or 8 end
local function touching(a,b) local g=gap()-.5; return a.l<b.r+g and b.l<a.r+g and a.b<b.t+g and b.b<a.t+g end
-- The frames of the other elements that are on screen now (for elements that
-- keep clear of them by themselves, like the battleground timer).
function Movers:Others(own)
    local list={}
    for _,e in ipairs(elements) do
        local m=mod(e.module); local frame=m and e.frame(m)
        if frame and frame~=own and frame.IsShown and frame:IsShown() then list[#list+1]=frame end
    end
    return list
end
-- An element was dropped: if it lies on another one, slide it off by the
-- shortest way that keeps it on the screen.
function Movers:Settle(e)
    if InCombatLockdown() or not e.nudge then return end
    local m=mod(e.module); local frame=m and e.frame(m)
    if not frame or not frame:IsShown() then return end
    local W,H=UIParent:GetWidth(),UIParent:GetHeight()
    for _=1,4 do
        local a=rectOf(frame); if not a then return end
        local hit
        for _,other in ipairs(self:Others(frame)) do
            local b=rectOf(other)
            if b and touching(a,b) then hit=b; break end
        end
        if not hit then return end
        local g=gap()
        local moves={{0,hit.t+g-a.b},{0,hit.b-g-a.t},{hit.r+g-a.l,0},{hit.l-g-a.r,0}}
        table.sort(moves,function(x,y) return math.abs(x[1])+math.abs(x[2])<math.abs(y[1])+math.abs(y[2]) end)
        local chosen
        for _,move in ipairs(moves) do
            local l,r,b,t=a.l+move[1],a.r+move[1],a.b+move[2],a.t+move[2]
            if l>=0 and r<=W and b>=0 and t<=H then chosen=move; break end
        end
        if not chosen then return end
        local before=a
        pcall(e.nudge,m,chosen[1],chosen[2])
        local after=rectOf(frame)
        -- It did not move (its own limits held it): leave it.
        if not after or (math.abs(after.l-before.l)<.5 and math.abs(after.b-before.b)<.5) then return end
    end
end
-- Listen for drops on every element that exists by now.
function Movers:Hook()
    self.hooked=self.hooked or {}
    for _,e in ipairs(elements) do
        local m=mod(e.module); local frame=m and e.frame(m)
        if frame and e.nudge and not self.hooked[frame] and frame.HookScript then
            self.hooked[frame]=true
            frame:HookScript("OnDragStop",function() if not self.settling then self.settling=true; pcall(self.Settle,self,e); self.settling=false end end)
        end
    end
end
-- An element's own page can unlock it too, and its frame may only be made
-- then: look for new frames once a second while a ForeverTools window is open.
function Movers:WatchPages()
    self:Hook()
    if self.pageWatch or not C_Timer or not C_Timer.NewTicker then return end
    self.pageWatch=C_Timer.NewTicker(1,function()
        self:Hook()
        if self.active then return end
        for frame in pairs(FT.controlWindows or {}) do if frame:IsShown() then return end end
        if FT.home and FT.home:IsShown() then return end
        self.pageWatch:Cancel(); self.pageWatch=nil
    end)
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
    -- Open ForeverTools windows shrink to their title bar while moving and
    -- open again on Done.
    self.shrunk={}
    for frame in pairs(FT.controlWindows or {}) do
        if frame:IsShown() and frame.minButton and frame.minButton:IsShown() and not frame.minimized then
            FT:SetMinimized(frame,true); self.shrunk[frame]=true
        end
    end
    self.active=true
    local showUnused=self:Settings().showUnused
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and (showUnused or self:Used(e)) then
            if pcall(e.start,m) then self.running=self.running or {}; self.running[e.key]=true end
        end
    end
    -- Some elements build their frame a moment later (the threat meter).
    self:LabelAll(); C_Timer.After(.2,function() if self.active then self:LabelAll(); self:Hook() end end)
    self:Hook()
    self:Bar():Show(); self.pulse:Play()
    -- Something turned on or off while moving (its own page is open): keep
    -- the list of movable elements in step. Only runs while moving.
    if self.watch then self.watch:Cancel() end
    self.watch=C_Timer.NewTicker(.5,function() self:Sync() end)
    FT:RefreshMoveButtons(true)
    self:Refresh()
end
function Movers:LabelAll()
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and self.running and self.running[e.key] then local frame=e.frame(m); if frame then self:Label(e,frame) end end
    end
end
function Movers:Sync()
    if not self.active or InCombatLockdown() then return end
    self:Hook()
    local showUnused=self:Settings().showUnused
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m then
            local want=showUnused or self:Used(e)
            local running=self.running and self.running[e.key]
            if want and not running then
                if pcall(e.start,m) then self.running=self.running or {}; self.running[e.key]=true; local frame=e.frame(m); if frame then self:Label(e,frame) end end
            elseif running and not want then
                pcall(e.stop,m); self.running[e.key]=nil
                if self.labels[e.key] then self.labels[e.key]:Hide() end
            end
        end
    end
end
function Movers:Stop()
    self.active=false
    if self.watch then self.watch:Cancel(); self.watch=nil end
    for _,e in ipairs(elements) do
        local m=mod(e.module)
        if m and self.running and self.running[e.key] then pcall(e.stop,m) end
        if self.labels[e.key] then self.labels[e.key]:Hide() end
    end
    self.running=nil
    if self.bar then self.bar:Hide(); self.pulse:Stop() end
    FT:RefreshMoveButtons(false)
    -- New positions go into the profile right away.
    if FT.modules.Profiles then FT.modules.Profiles:AutoSave() end
    for frame in pairs(self.shrunk or {}) do if frame:IsShown() and frame.minimized then FT:SetMinimized(frame,false) end end
    self.shrunk=nil
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
    -- A slow gold pulse on the border while you're moving things.
    local glow=CreateFrame("Frame",nil,bar); glow:SetAllPoints(); FT:Panel(glow)
    for _,t in ipairs(glow.fillTextures) do t:Hide() end
    FT:Paint(glow,{0,0,0,0},{.95,.78,.42,1}); glow:SetAlpha(0)
    local pulse=glow:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(0); fade:SetToAlpha(.5); fade:SetDuration(1.6); fade:SetSmoothing("IN_OUT")
    self.pulse=pulse
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
        -- Rows 36 apart: the list has to fit the group's window (Hubs.lua).
        local rowsTop,STEP=184,36
        local height=rowsTop+#elements*STEP+32+24
        local frame=FT:Window("ForeverToolsMovers","Move elements",540,height); self.frame=frame
        FT:BackTo(frame,"SystemDisplay")
        FT:PageInfo(frame,"Move elements","Unlock everything ForeverTools draws on screen and drag it where you like, all at once. Click Done on the bar at the top, or enter combat, to lock it again.\n\nAction bars, unit frames and other game frames are moved in the game's Edit Mode.")
        self.toggle=FT:AccentButton(frame,"",492,34,"move"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() self:Toggle() end)
        FT:Tooltip(self.toggle,"Move elements","Unlock all elements so you can drag them. The same as the move button in every window's title bar.")
        self.unused=FT:QuietButton(frame,"",492,32,"move"); self.unused:SetPoint("TOPLEFT",24,-106)
        self.unused:SetScript("OnClick",function() local s=self:Settings(); s.showUnused=not s.showUnused; self:Restart(); self:Refresh() end)
        FT:Tooltip(self.unused,"Show unused elements","Also show elements you have turned off, so you can place them before using them. Off shows only what you use.")
        local head=FT:Label(frame,"Elements",15,true); head:SetPoint("TOPLEFT",24,-154); FT:SectionHeading(head,"Ability_Rogue_Sprint",380)
        self.rows={}
        for i,e in ipairs(elements) do
            local y=-rowsTop-(i-1)*STEP
            local b=FT:QuietButton(frame,e.name,350,32,"move"); b:SetPoint("TOPLEFT",24,y)
            -- Its own page has its own move and preview, so lock everything first.
            b:SetScript("OnClick",function() if self.active then self:Stop() end; FT:OpenModule(e.open) end)
            FT:Tooltip(b,e.name,"Click to open its settings page. This locks all elements first."..(e.note and ("\n\n"..e.note) or ""))
            local r=FT:QuietButton(frame,"Reset",130,32,"reset"); r:SetPoint("TOPLEFT",386,y)
            r:SetScript("OnClick",function() self:Reset(e) end)
            FT:Tooltip(r,"Reset "..e.name:lower(),e.resetTip or "Put it back where it starts.")
            self.rows[i]={e=e,button=b}
        end
        local all=FT:QuietButton(frame,"Reset all positions",492,32,"reset"); all:SetPoint("TOPLEFT",24,-rowsTop-#elements*STEP-4)
        all:SetScript("OnClick",function() FT:Confirm("Put every element back where it starts?",function() for _,e in ipairs(elements) do self:Reset(e) end end) end)
        FT:Tooltip(all,"Reset all positions","Put every element on this list back where it starts.")
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("Movers",Movers)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent",function() if Movers.active then Movers:Stop(); FT:Toast("Elements locked for combat.",2.5) end end)
