local _,FT=...
-- Battleground timer (PvP, off by default). When a battleground queue pops,
-- the game gives you a limited time to enter but does not show how much is
-- left. This bar counts it down: the battleground's name, the time left, and
-- a bar that shrinks and turns from green to red.
--   * The time comes from the game itself (GetBattlefieldPortExpiration), so
--     it is exact, also when the pop-up was open before you looked.
--   * With several invitations waiting, the one that runs out first is shown.
--   * It starts in the middle of the screen and moves below the game's own
--     "enter battle" window if the two would overlap. Once you have dragged
--     it somewhere, it stays there.
--   * It never takes mouse clicks while you play: only while you move it.
local Timer={total={}}
local WIDTH,HEIGHT=280,30
local PREVIEW_SECONDS=80
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
function Timer:Settings()
    if type(FT.db.queueTimer)~="table" then FT.db.queueTimer={} end
    local s=FT.db.queueTimer
    if type(s.enabled)~="boolean" then s.enabled=false end
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    return s
end
-- The invitation that runs out first: name and seconds left. nil when no
-- queue has popped, false when the game hides the answer right now.
function Timer:Pending()
    if not GetBattlefieldStatus or not GetBattlefieldPortExpiration then return nil end
    local count=3
    if GetMaxBattlefieldID then
        local ok,value=pcall(GetMaxBattlefieldID)
        if ok and plain(value) and type(value)=="number" then count=math.max(1,math.min(10,value)) end
    end
    local best,bestLeft,hidden
    for index=1,count do
        local ok,status,name=pcall(GetBattlefieldStatus,index)
        if ok and not plain(status) then hidden=true
        elseif ok and status=="confirm" then
            local found,left=pcall(GetBattlefieldPortExpiration,index)
            if found and not plain(left) then hidden=true
            elseif found and type(left)=="number" and left>0 then
                -- Very old game versions count in milliseconds.
                if left>1000 then left=left/1000 end
                if not bestLeft or left<bestLeft then
                    best,bestLeft={index=index,name=plain(name) and type(name)=="string" and name~="" and name or "Battleground"},left
                end
            end
        elseif ok then
            self.total[index]=nil
        end
    end
    if best then
        -- How long the invitation lasts in all: the most we have seen for it.
        local total=self.total[best.index]
        if not total or bestLeft>total then total=bestLeft; self.total[best.index]=total end
        return best.name,bestLeft,total
    end
    if hidden then return false end
    return nil
end
local function timeText(seconds)
    seconds=math.max(0,math.ceil(seconds))
    return string.format("%d:%02d",math.floor(seconds/60),seconds%60)
end
function Timer:Bar()
    if self.bar then return self.bar end
    local f=CreateFrame("Frame","ForeverToolsQueueTimer",UIParent)
    self.bar=f
    f:SetSize(WIDTH,HEIGHT); f:SetFrameStrata("HIGH"); f:SetClampedToScreen(true)
    FT:Panel(f); FT:Paint(f,{.06,.045,.02,.92},{.85,.66,.25,1})
    f.fill=f:CreateTexture(nil,"ARTWORK"); f.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    f.fill:SetPoint("TOPLEFT",4,-4); f.fill:SetPoint("BOTTOMLEFT",4,4); f.fill:SetWidth(WIDTH-8)
    f.name=FT:Label(f,"",13,true); f.name:SetPoint("LEFT",10,0); f.name:SetWidth(WIDTH-78); f.name:SetJustifyH("LEFT")
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.name:SetTextColor(1,1,1); f.name:SetShadowColor(0,0,0,1); f.name:SetShadowOffset(1,-1)
    f.time=FT:Label(f,"",15,true); f.time:SetPoint("RIGHT",-10,0); f.time:SetJustifyH("RIGHT")
    f.time:SetTextColor(1,1,1); f.time:SetShadowColor(0,0,0,1); f.time:SetShadowOffset(1,-1)
    f:SetMovable(true); f:RegisterForDrag("LeftButton"); f:EnableMouse(false)
    f:SetScript("OnDragStart",function() if self.moving then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local s=self:Settings()
        if x and y then local scale=f:GetScale(); s.x,s.y=x*scale,y*scale end
        self:Position()
    end)
    f:SetScript("OnUpdate",function(_,dt) self:Tick(dt) end)
    f:Hide()
    return f
end
-- The game's own windows that ask you to enter: the bar keeps clear of them.
local POPUPS={"PVPReadyDialog","StaticPopup1","StaticPopup2","StaticPopup3","StaticPopup4","LFGDungeonReadyDialog"}
local function overlaps(a,b)
    local al,ab,aw,ah=a:GetRect(); local bl,bb,bw,bh=b:GetRect()
    if not al or not bl then return false end
    for _,v in ipairs({al,ab,aw,ah,bl,bb,bw,bh}) do if not plain(v) or type(v)~="number" then return false end end
    -- Both in screen units, whatever their own scale.
    local as,bs=a:GetEffectiveScale(),b:GetEffectiveScale()
    al,ab,aw,ah=al*as,ab*as,aw*as,ah*as; bl,bb,bw,bh=bl*bs,bb*bs,bw*bs,bh*bs
    return al<bl+bw and bl<al+aw and ab<bb+bh and bb<ab+ah
end
function Timer:Position()
    local f=self:Bar(); local s=self:Settings()
    f:SetScale(s.size); f:ClearAllPoints()
    if s.x and s.y then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x/s.size,s.y/s.size); return end
    -- The middle of the screen, unless one of the game's windows is there:
    -- then just below the lowest of them.
    f:SetPoint("CENTER",UIParent,"CENTER",0,0)
    -- Measured in screen units and placed against the screen, never
    -- anchored to the game's window.
    -- The same goes for other ForeverTools elements on that spot (the
    -- flight timer also starts in the middle).
    local inTheWay={}
    for _,name in ipairs(POPUPS) do inTheWay[#inTheWay+1]=_G[name] end
    local movers=FT.modules.Movers
    if movers and movers.Others then for _,frame in ipairs(movers:Others(f)) do inTheWay[#inTheWay+1]=frame end end
    local lowest
    for _,popup in ipairs(inTheWay) do
        if popup and popup.IsShown and popup:IsShown() and popup.GetRect and overlaps(f,popup) then
            local bottom=popup:GetBottom()
            if plain(bottom) and type(bottom)=="number" then
                bottom=bottom*popup:GetEffectiveScale()
                if not lowest or bottom<lowest then lowest=bottom end
            end
        end
    end
    if lowest then
        local scale=f:GetEffectiveScale()
        local middle=UIParent:GetWidth()*UIParent:GetEffectiveScale()/2
        f:ClearAllPoints(); f:SetPoint("TOP",UIParent,"BOTTOMLEFT",middle/scale,(lowest-14*scale)/scale)
    end
end
-- Green with plenty of time, yellow at half, red at the end.
local function barColor(share)
    if share>.5 then return 2*(1-share)*.9+.1,.75,.15 end
    return 1,.75*share*2,.12
end
function Timer:Paint(name,left,total)
    local f=self:Bar()
    local share=math.max(0,math.min(1,(total and total>0) and left/total or 1))
    f.fill:SetWidth(math.max(1,(WIDTH-8)*share))
    local r,g,b=barColor(share)
    f.fill:SetVertexColor(r,g,b,.85)
    f.name:SetText(name); f.time:SetText(timeText(left))
    -- The last ten seconds blink.
    f:SetAlpha((left<=10 and not self.moving) and (.55+.45*math.abs(math.sin((GetTime and GetTime() or 0)*4))) or 1)
end
-- Show (or keep showing) the countdown for an invitation.
function Timer:Start(name,left,total)
    local now=GetTime and GetTime() or 0
    -- The game counts in whole seconds: keep our own smooth clock unless it
    -- has drifted from the game's answer.
    if not self.expires or self.name~=name or math.abs((self.expires-now)-left)>1.5 then self.expires=now+left end
    self.name=name; self.totalNow=total
    local f=self:Bar()
    if not f:IsShown() then self:Position(); f:Show() end
    self:Paint(name,math.max(0,self.expires-now),total)
end
function Timer:Stop()
    self.expires=nil; self.name=nil
    if self.bar and not self.moving and not self.previewUntil then self.bar:Hide() end
end
-- Ask the game where the queues stand.
function Timer:Check()
    if not self:Settings().enabled then self:Stop(); return end
    local name,left,total=self:Pending()
    if name==false then return end -- hidden right now: keep counting on our own clock
    if name then self:Start(name,left,total) else self:Stop() end
end
function Timer:Tick(dt)
    local f=self.bar
    f.wait=(f.wait or 0)+dt
    if f.wait<.05 then return end
    local passed=f.wait; f.wait=0
    local now=GetTime and GetTime() or 0
    f.sync=(f.sync or 0)+passed
    if self.moving or self.previewUntil then
        -- A sample that counts down, then starts over while you move it.
        local start=self.sampleStart or now
        self.sampleStart=start
        local left=PREVIEW_SECONDS-((now-start)*(self.moving and 1 or 6))%PREVIEW_SECONDS
        self:Paint(self.moving and "Drag me" or "Warsong Gulch",left,PREVIEW_SECONDS)
        if self.previewUntil and not self.moving and now>=self.previewUntil then self.previewUntil=nil; self.sampleStart=nil; self:Check(); if not self.expires then f:Hide() end end
        return
    end
    if not self.expires then f:Hide(); return end
    local left=self.expires-now
    if left<=0 then self:Stop(); return end
    self:Paint(self.name or "Battleground",left,self.totalNow)
    -- Twice a second: has the game's window moved in, and is the invitation still there?
    if f.sync>=.5 then
        f.sync=0
        self:Check()
        if self.expires then local s=self:Settings(); if not s.x then self:Position() end end
    end
end
function Timer:Apply()
    if self.bar then self:Position() end
    self:Check()
    self:Refresh()
end
function Timer:SetMoving(on)
    self.moving=on and true or false
    local f=self:Bar()
    f:EnableMouse(self.moving)
    self.sampleStart=nil
    if self.moving then self:Position(); f:Show() else self:Position(); self:Check(); if not self.expires and not self.previewUntil then f:Hide() end end
    self:Refresh()
end
function Timer:Preview()
    self.previewUntil=(GetTime and GetTime() or 0)+8; self.sampleStart=nil
    self:Position(); self:Bar():Show()
end
function Timer:ResetPosition()
    local s=self:Settings(); s.x,s.y=nil,nil
    self:Position()
end
-- Settings page
function Timer:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Battleground timer: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
    self.settingSize=true; self.sizeSlider:SetValue(s.size); self.settingSize=false
    self.move.label:SetText(self.moving and "Lock position" or "Move timer"); FT:SetSelected(self.move,self.moving)
    self.place:SetText(s.x and "You placed the timer yourself." or "The timer is in the middle of the screen, and steps below the game's enter window if they would overlap.")
end
function Timer:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsQueueTimer","Battleground timer",540,300); self.frame=frame
        FT:PageInfo(frame,"Battleground timer","When a battleground queue pops, the game gives you a short time to enter but does not show how much is left. This bar counts it down: the battleground's name, the time left, and a bar that shrinks from green to red. The last ten seconds blink.\n\nThe time comes from the game, so it is exact. It never takes mouse clicks while you play.")
        local hint=FT:Label(frame,"Counts down the time you have to enter when a battleground queue pops.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,"INV_Misc_PocketWatch_01"); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Battleground timer","Show a countdown of the time you have left to enter when a battleground queue pops.")
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,-142)
        self.sizeSlider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); self.sizeSlider:SetSize(320,18); self.sizeSlider:SetPoint("TOPLEFT",196,-140)
        self.sizeSlider:SetMinMaxValues(.7,1.5); self.sizeSlider:SetValueStep(.05); self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,v) if self.settingSize then return end self:Settings().size=math.floor(v*20+.5)/20; self:Position(); self:Refresh() end)
        FT:Tooltip(self.sizeSlider,"Size","Make the timer smaller or bigger (70% to 150%).")
        local preview=FT:QuietButton(frame,"Preview",240,32,"INV_Misc_PocketWatch_01"); preview:SetPoint("TOPLEFT",24,-180)
        preview:SetScript("OnClick",function() self:Preview() end)
        FT:Tooltip(preview,"Preview","Show an example timer for a few seconds, running fast so you see the colors change.")
        self.move=FT:QuietButton(frame,"",240,32,"move"); self.move:SetPoint("TOPLEFT",276,-180)
        self.move:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.move,"Move timer","Click to unlock, drag the timer where you want it, then click again to lock it.")
        local reset=FT:QuietButton(frame,"Reset position",240,32,"reset"); reset:SetPoint("TOPLEFT",24,-220)
        reset:SetScript("OnClick",function() self:ResetPosition(); self:Refresh() end)
        FT:Tooltip(reset,"Reset position","Put the timer back in the middle of the screen, clear of the game's enter window.")
        self.place=FT:Label(frame,"",12); self.place:SetPoint("TOPLEFT",24,-262); self.place:SetWidth(492); self.place:SetTextColor(.66,.59,.48)
        if self.place.SetWordWrap then self.place:SetWordWrap(true) end
        -- Closing the page ends moving and the preview.
        frame:HookScript("OnHide",function()
            if self.moving then self:SetMoving(false) end
            if self.previewUntil then
                self.previewUntil=nil; self.sampleStart=nil
                self:Check(); if not self.expires and self.bar then self.bar:Hide() end
            end
        end)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("QueueTimer",Timer)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","UPDATE_BATTLEFIELD_STATUS","BATTLEFIELDS_SHOW","PVPQUEUE_ANYWHERE_SHOW"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function()
    if not FT.dbReady then return end
    Timer:Check()
    -- The game's enter window opens a moment after the status changes.
    if Timer.expires then C_Timer.After(.3,function() if Timer.expires and not Timer:Settings().x then Timer:Position() end end) end
end)
