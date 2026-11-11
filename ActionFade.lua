local _,FT=...
-- Action bars on mouseover (off by default). Chosen bars stay hidden until
-- the mouse is over them; they fade in, and fade out again a moment after the
-- mouse leaves. They show too while you hold a spell, item or macro on the
-- cursor (to drop it on a button), in Edit Mode and quick keybind mode, while
-- a flyout is open and, if chosen, in a fight.
-- Only the bars' see-through level changes (allowed in a fight too); nothing
-- is moved, so the buttons work as always, even while hidden. A bar that is
-- off in the game's own settings can be turned on from the window.
-- Settings: Keybind tools and action bars > Action bars on mouseover.
local Fade={}
-- Near instant: shown at once, hidden a short moment after the mouse leaves.
local IN,OUT,WAIT=.01,.08,.15
-- The game's bars, with their number in the game's "show bar" list.
local BARS={
    {key="main",label="Action bar 1",frames={"MainActionBar","MainMenuBar"}},
    {key="bl",label="Action bar 2",frames={"MultiBarBottomLeft"},toggle=1},
    {key="br",label="Action bar 3",frames={"MultiBarBottomRight"},toggle=2},
    {key="r",label="Action bar 4",frames={"MultiBarRight"},toggle=3},
    {key="l",label="Action bar 5",frames={"MultiBarLeft"},toggle=4},
    {key="b5",label="Action bar 6",frames={"MultiBar5"},toggle=5},
    {key="b6",label="Action bar 7",frames={"MultiBar6"},toggle=6},
    {key="b7",label="Action bar 8",frames={"MultiBar7"},toggle=7},
    {key="stance",label="Stance bar",frames={"StanceBar","StanceBarFrame"}},
    {key="pet",label="Pet bar",frames={"PetActionBar","PetActionBarFrame"}},
}
Fade.BARS=BARS
function Fade:Settings()
    FT.db.actionFade=type(FT.db.actionFade)=="table" and FT.db.actionFade or {}
    local s=FT.db.actionFade
    s.bars=type(s.bars)=="table" and s.bars or {}
    return s
end
function Fade:Count() local n=0; for _,on in pairs(self:Settings().bars) do if on then n=n+1 end end; return n end
function Fade:On() return FT.dbReady and self:Count()>0 end
function Fade:Frame(bar)
    for _,name in ipairs(bar.frames) do local f=_G[name]; if f and f.SetAlpha then return f end end
end
-- Is the bar on in the game's settings? (Bars 2-8; the others always count.)
function Fade:Shown(bar)
    if not bar.toggle then return self:Frame(bar)~=nil end
    if not GetActionBarToggles then local f=self:Frame(bar); return f and f:IsShown() or false end
    local t={GetActionBarToggles()}
    return t[bar.toggle] and true or false
end
-- Turn a bar on or off in the game's settings (out of combat).
function Fade:SetShown(bar,on)
    if not bar.toggle or InCombatLockdown() then if InCombatLockdown() then FT:Toast("Not in a fight.",3) end; return end
    local done=false
    if Settings and Settings.SetValue then
        done=pcall(Settings.SetValue,"PROXY_SHOW_ACTIONBAR_"..(bar.toggle+1),on)
    end
    if (not done) and GetActionBarToggles and SetActionBarToggles then
        local t={GetActionBarToggles()}; t[bar.toggle]=on and true or false
        done=pcall(SetActionBarToggles,unpack(t,1,7))
        if done and MultiActionBar_Update then pcall(MultiActionBar_Update) end
    end
    if not done then FT:Toast("Turn it on in the game's options: Esc > Options > Action Bars.",5) end
    C_Timer.After(.2,function() self:Refresh() end)
end
-- Showing --------------------------------------------------------------------
local function cursorHolds()
    if not GetCursorInfo then return false end
    local kind=GetCursorInfo()
    return kind=="spell" or kind=="item" or kind=="macro" or kind=="petaction" or kind=="mount" or kind=="flyout" or kind=="companion"
end
local function forced(s)
    if cursorHolds() then return true end
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive() then return true end
    if QuickKeybindFrame and QuickKeybindFrame:IsShown() then return true end
    if s.combat and InCombatLockdown() then return true end
    return false
end
local function over(frame)
    if frame:IsMouseOver(4,-4,-4,4) then return true end
    local flyout=SpellFlyout
    if flyout and flyout:IsShown() and flyout.GetParent and flyout:GetParent() and flyout:GetParent():GetParent()==frame then return true end
    return false
end
Fade.state={}
function Fade:Step(dt)
    local s=self:Settings()
    local always=forced(s)
    for _,bar in ipairs(BARS) do
        local f=self:Frame(bar)
        local st=self.state[bar.key]
        if f and s.bars[bar.key] then
            if not st then st={alpha=f:GetAlpha() or 1,seen=0}; self.state[bar.key]=st end
            local want
            if always or (f:IsShown() and over(f)) then want=1; st.seen=GetTime() else want=(GetTime()-st.seen>WAIT) and 0 or 1 end
            local a=st.alpha
            if a<want then a=math.min(want,a+dt/IN) elseif a>want then a=math.max(want,a-dt/OUT) end
            if a~=st.alpha or f:GetAlpha()~=a then st.alpha=a; f:SetAlpha(a) end
        elseif st then
            -- Turned off: back to fully shown.
            if f then f:SetAlpha(1) end
            self.state[bar.key]=nil
        end
    end
end
local ticker=CreateFrame("Frame"); ticker:Hide()
local acc=0
ticker:SetScript("OnUpdate",function(_,dt)
    acc=acc+dt; if acc<.02 then return end
    local step=acc; acc=0
    Fade:Step(step)
end)
function Fade:Apply()
    if not FT.dbReady then return end
    self:Step(0)
    ticker:SetShown(self:On())
    self:Refresh()
    local system=FT.modules.System
    if system and system.Refresh then system:Refresh() end
end
-- Window ---------------------------------------------------------------------
function Fade:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local s=self:Settings()
    self.combat.label:SetText("Show them in a fight: "..(s.combat and "On" or "Off")); FT:SetSelected(self.combat,s.combat==true)
    -- Only the bars this game version has.
    local y=-106
    for _,row in ipairs(self.rows) do
        local bar=row.bar
        local exists=self:Frame(bar)~=nil
        row:SetShown(exists); row:ClearAllPoints(); row:SetPoint("TOPLEFT",24,y); if exists then y=y-38 end
        local shown=self:Shown(bar)
        local on=s.bars[bar.key]==true
        row:SetEnabled(exists); row:SetAlpha(exists and 1 or .45)
        row.label:SetText(bar.label..": "..(on and "Mouseover" or "Always shown")..((not shown and exists) and "  |cffff9e59(off in game)|r" or ""))
        FT:SetSelected(row,on)
        row.game:SetShown(bar.toggle~=nil and exists)
        if not exists then row.game:Hide() end
        row.game.label:SetText(shown and "Shown in game" or "Off in game")
        FT:SetSelected(row.game,shown)
    end
end
function Fade:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsActionFade","Action bars on mouseover",520,572); self.frame=frame
        FT:BackTo(frame,"SystemKeybinds")
        FT:PageInfo(frame,"Action bars on mouseover","Choose bars that stay hidden until your mouse is over them. They also show while you drag a spell or item onto them, in Edit Mode and in quick keybind mode.\n\nHidden bars still work with their keys.\n\nA bar marked \"off in game\" is turned off in the game's own options: click \"Off in game\" to turn it on.")
        self.combat=FT:QuietButton(frame,"",472,32,"Ability_DualWield"); self.combat:SetPoint("TOPLEFT",24,-62)
        self.combat:SetScript("OnClick",function() local s=self:Settings(); s.combat=not s.combat; self:Apply() end)
        FT:Tooltip(self.combat,"Show them in a fight","Mouseover bars are shown the whole fight.")
        self.rows={}
        for i,bar in ipairs(BARS) do
            local row=FT:QuietButton(frame,"",326,32,"mouseover"); row:SetPoint("TOPLEFT",24,-106-(i-1)*38); row.bar=bar
            row.label:ClearAllPoints(); row.label:SetPoint("LEFT",row.icon,"RIGHT",8,0); row.label:SetPoint("RIGHT",-8,0); row.label:SetJustifyH("LEFT")
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row:SetScript("OnClick",function() local s=self:Settings(); s.bars[bar.key]=not s.bars[bar.key] or nil; self:Apply() end)
            FT:Tooltip(row,bar.label,"Click: hidden until your mouse is over it, or always shown.")
            row.game=FT:QuietButton(frame,"",140,32); row.game:SetPoint("LEFT",row,"RIGHT",6,0)
            row.game:SetScript("OnClick",function() self:SetShown(bar,not self:Shown(bar)) end)
            FT:Tooltip(row.game,"In the game's options",function() return self:Shown(bar) and "The bar is on in Esc > Options > Action Bars. Click to turn it off." or "The bar is off in Esc > Options > Action Bars, so it never shows. Click to turn it on." end)
            self.rows[i]=row
        end
        frame:HookScript("OnShow",function() self:Refresh() end)
    end
    self.frame:Show(); self:Refresh()
end
FT:RegisterModule("ActionFade",Fade)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Fade:Apply() end end)
