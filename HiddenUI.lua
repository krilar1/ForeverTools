local _,FT=...
-- "Show key when interface is hidden" (System > General, off by default):
-- when you hide the interface (ALT-Z by default), a small line says which key
-- brings it back. It fades by itself after a few seconds, goes away the
-- moment a screenshot starts and comes back a couple of seconds after it,
-- and never shows during cutscenes.
local Hint={}
local STAY,FADE=5,1
local RETURN=2 -- seconds after a screenshot before the line is back
function Hint:Enabled()
    return FT.dbReady and FT.modules.System:Settings().hiddenUIHint==true
end
-- The key bound to the game's "Toggle user interface", in readable form.
function Hint:Key()
    if not GetBindingKey then return nil end
    local key=GetBindingKey("TOGGLEUI")
    if type(key)~="string" or key=="" then return nil end
    local text=GetBindingText and GetBindingText(key) or key
    return type(text)=="string" and text~="" and text or key
end
-- Cutscenes and movies hide the interface too: no message then.
local function cinematic()
    if CinematicFrame and CinematicFrame.IsShown and CinematicFrame:IsShown() then return true end
    if MovieFrame and MovieFrame.IsShown and MovieFrame:IsShown() then return true end
    if InCinematic and InCinematic() then return true end
    if IsInCinematicScene and IsInCinematicScene() then return true end
    return false
end
function Hint:Frame()
    if self.frame then return self.frame end
    -- No parent: a frame under UIParent would be hidden with the interface.
    local frame=CreateFrame("Frame","ForeverToolsHiddenUIHint")
    self.frame=frame
    frame:SetFrameStrata("TOOLTIP"); frame:SetSize(320,30); frame:Hide()
    FT:RoundedFill(frame,0,0,0,.55)
    frame.text=FT:Label(frame,"",14); frame.text:SetPoint("CENTER")
    frame:SetScript("OnUpdate",function(_,dt) self:Tick(dt) end)
    return frame
end
function Hint:Tick(dt)
    local frame=self.frame
    frame.age=(frame.age or 0)+dt
    if frame.age>=STAY+FADE then self:Hide()
    elseif frame.age>STAY then frame:SetAlpha(1-(frame.age-STAY)/FADE) end
end
function Hint:Hide()
    if self.frame then self.frame:Hide(); self.frame:SetAlpha(1) end
end
-- Show the line now (true when it was shown).
function Hint:Show()
    local key=self:Key()
    if not key then return false end
    local frame=self:Frame()
    frame.text:SetText("Press |cffffd100"..key.."|r to show the interface")
    -- Same size as the interface's own text, and above the action bar area.
    if UIParent and UIParent.GetScale then frame:SetScale(UIParent:GetScale()) end
    frame:SetWidth(math.max(120,(frame.text:GetStringWidth() or 260)+28))
    frame:ClearAllPoints(); frame:SetPoint("BOTTOM",WorldFrame or UIParent,"BOTTOM",0,150)
    frame.age=0; frame:SetAlpha(1); frame:Show()
    return true
end
function Hint:OnInterfaceHidden()
    if not self:Enabled() then return end
    -- A moment later: a cutscene needs a frame or two to say it has started.
    C_Timer.After(.3,function()
        if not self:Enabled() then return end
        -- A screenshot is being taken right now: show it after that.
        if self.capturing then self.interrupted=true; return end
        if UIParent and UIParent:IsShown() then return end
        if cinematic() then return end
        self:Show()
    end)
end
-- A screenshot starts: out of the picture at once. If that cut the line
-- short, it comes back a couple of seconds after the last screenshot.
function Hint:OnScreenshot()
    if self.frame and self.frame:IsShown() then self.interrupted=true end
    self.capturing=true; self:Hide()
    self.shot=(self.shot or 0)+1
    local shot=self.shot
    C_Timer.After(RETURN,function()
        if shot~=self.shot then return end -- another screenshot came after this one
        self.capturing=nil
        if not self.interrupted then return end
        self.interrupted=nil
        if not self:Enabled() or cinematic() then return end
        if UIParent and UIParent:IsShown() then return end
        self:Show()
    end)
end
FT:RegisterModule("HiddenUI",Hint)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
-- Screenshot events tell us just before the picture is taken.
for _,event in ipairs({"SCREENSHOT_STARTED","CINEMATIC_START","PLAY_MOVIE"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        if UIParent and UIParent.HookScript then
            UIParent:HookScript("OnHide",function() Hint:OnInterfaceHidden() end)
            UIParent:HookScript("OnShow",function() Hint.interrupted=nil; Hint:Hide() end)
        end
    elseif event=="SCREENSHOT_STARTED" then
        Hint:OnScreenshot()
    else
        Hint:Hide()
    end
end)
