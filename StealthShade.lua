local _,FT=...
-- Stealth shadows (1.8.0, rogues and druids, off by default; Combat > Stealth):
-- while you are stealthed (Stealth, Prowl, Shadowmeld) the edges of the screen
-- sink into a dark violet shadow. With "Drifting shadows" the four edges
-- breathe slowly, each at its own pace, so the dark seems to creep in and
-- out. Made of thin strips (no extra art), behind the whole interface.
-- Nothing exists for other classes, and nothing runs while you aren't
-- stealthed: the animations only play while it shows. Works in combat.
local Shade={}
FT.StealthShade=Shade
local COLOR={.03,0,.07}
local STRENGTH={light=.45,medium=.65,strong=.85}
local EDGE=.22          -- how far in from each side the shadow reaches (of the screen)
Shade.strengths={{"light","Light","A faint shadow at the edges."},{"medium","Medium","A clear shadow at the edges."},{"strong","Strong","A deep shadow at the edges."}}

function Shade:Allowed()
    local ok,_,class=pcall(UnitClass,"player")
    return ok and (class=="ROGUE" or class=="DRUID")
end
function Shade:Settings()
    local s=FT.modules.System:Settings()
    if type(s.stealthShade)~="boolean" then s.stealthShade=false end
    if type(s.stealthDrift)~="boolean" then s.stealthDrift=true end
    if not STRENGTH[s.stealthStrength] then s.stealthStrength="medium" end
    return s
end
-- Each edge is a stack of thin strips, darkest at the screen's edge and
-- fading inwards (1.8.0: Forever draws gradient textures as solid boxes, so
-- no gradients are used). Each edge is its own frame so it can breathe.
local STRIPS=36
local function fade(k) local x=1-(k-1)/STRIPS; return x*x end
function Shade:Build()
    if self.frame then return self.frame end
    local f=CreateFrame("Frame","ForeverToolsStealthShade",UIParent)
    f:SetAllPoints(UIParent)
    f:SetFrameStrata("BACKGROUND"); f:SetFrameLevel(0)
    f:EnableMouse(false); f:Hide(); f:SetAlpha(0)
    f.edges={}
    for i,side in ipairs({"LEFT","RIGHT","BOTTOM","TOP"}) do
        local edge=CreateFrame("Frame",nil,f)
        edge.side=side; edge.strips={}
        for k=1,STRIPS do
            local t=edge:CreateTexture(nil,"BACKGROUND")
            t:SetColorTexture(COLOR[1],COLOR[2],COLOR[3],fade(k))
            edge.strips[k]=t
        end
        -- Slow breathing, each side at its own pace (out of step).
        local g=edge:CreateAnimationGroup(); g:SetLooping("BOUNCE")
        local a=g:CreateAnimation("Alpha"); a:SetFromAlpha(.65); a:SetToAlpha(1); a:SetDuration(4.2+i*.65); a:SetSmoothing("IN_OUT")
        edge.breathe=g
        f.edges[i]=edge
    end
    -- Fade in and out.
    f.fade=f:CreateAnimationGroup()
    f.fadeAlpha=f.fade:CreateAnimation("Alpha")
    f.fade:SetScript("OnFinished",function()
        f:SetAlpha(f.target or 0)
        if (f.target or 0)==0 then f:Hide(); for _,e in ipairs(f.edges) do e.breathe:Stop() end end
    end)
    self.frame=f
    self:Layout()
    return f
end
function Shade:Layout()
    local f=self.frame; if not f then return end
    local w,h=UIParent:GetWidth() or 1920,UIParent:GetHeight() or 1080
    local across=math.min(w,h)*EDGE
    local step=across/STRIPS
    for _,edge in ipairs(f.edges) do
        local side=edge.side
        edge:ClearAllPoints(); edge:SetAllPoints(f)
        for k,t in ipairs(edge.strips) do
            t:ClearAllPoints()
            local off=(k-1)*step
            if side=="LEFT" then t:SetPoint("TOPLEFT",off,0); t:SetPoint("BOTTOMLEFT",off,0); t:SetWidth(step)
            elseif side=="RIGHT" then t:SetPoint("TOPRIGHT",-off,0); t:SetPoint("BOTTOMRIGHT",-off,0); t:SetWidth(step)
            elseif side=="BOTTOM" then t:SetPoint("BOTTOMLEFT",0,off); t:SetPoint("BOTTOMRIGHT",0,off); t:SetHeight(step)
            else t:SetPoint("TOPLEFT",0,-off); t:SetPoint("TOPRIGHT",0,-off); t:SetHeight(step) end
        end
    end
end
function Shade:Stealthed()
    if not IsStealthed then return false end
    local ok,yes=pcall(IsStealthed)
    return ok and not (issecretvalue and issecretvalue(yes)) and yes==true
end
-- Show or hide to match: on, allowed class, and stealthed (or the preview).
function Shade:Check()
    if not FT.dbReady then return end
    local s=self:Settings()
    local want=self:Allowed() and (self.preview or (s.stealthShade and self:Stealthed()))
    local f=self.frame
    if not want and not f then return end
    f=self:Build()
    local alpha=want and STRENGTH[s.stealthStrength] or 0
    if f.target==alpha and (want==f:IsShown()) then return end
    f.target=alpha
    if want then
        f:Show()
        for _,e in ipairs(f.edges) do
            if s.stealthDrift then if not e.breathe:IsPlaying() then e.breathe:Play() end else e.breathe:Stop(); e:SetAlpha(1) end
        end
    end
    f.fade:Stop()
    f.fadeAlpha:SetFromAlpha(f:GetAlpha()); f.fadeAlpha:SetToAlpha(alpha); f.fadeAlpha:SetDuration(want and .6 or .4)
    f.fade:Play()
end
function Shade:Apply()
    if self.frame then self.frame.target=nil end
    if self.events then self:Check(); return end
    if not self:Allowed() then return end
    local e=CreateFrame("Frame"); self.events=e
    e:RegisterEvent("UPDATE_STEALTH"); e:RegisterEvent("PLAYER_ENTERING_WORLD"); e:RegisterEvent("UI_SCALE_CHANGED"); e:RegisterEvent("DISPLAY_SIZE_CHANGED")
    e:SetScript("OnEvent",function(_,event)
        if event=="UI_SCALE_CHANGED" or event=="DISPLAY_SIZE_CHANGED" then Shade:Layout() else Shade:Check() end
    end)
    self:Check()
end
function Shade:TogglePreview()
    self.preview=not self.preview
    if self.frame then self.frame.target=nil end
    self:Check()
end
-- A short look (the tour): shows for a few seconds, then back as it was.
function Shade:Peek(seconds)
    if self.preview then return end
    self.preview=true; self:Check()
    self.peek=(self.peek or 0)+1; local n=self.peek
    C_Timer.After(seconds or 4,function() if self.peek==n and self.preview then self.preview=false; if self.frame then self.frame.target=nil end; self:Check() end end)
end
