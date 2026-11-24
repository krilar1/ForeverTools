local _,FT=...
-- Buff times (Buff reminders > Buff times, both off by default):
--   * Minutes on buffs: past an hour the game rounds to hours ("2 h") until
--     the last hour. With this on your buffs show hours and minutes
--     ("2h 23m"). Under an hour the game's own text is kept.
--   * Exact time in the tooltip: hovering one of your buffs or debuffs adds
--     a "Time left" line with minutes (and seconds in the last hour). The
--     game refreshes the tooltip every second, so the line keeps counting.
-- Only follows what the game does: a post-hook on each buff button's own
-- duration update and on the tooltip; nothing is replaced, nothing runs
-- while both are off besides a settings check.
local B={}
FT.BuffTimes=B
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function on(key)
    local S=FT.dbReady and FT.modules.System
    return S and S:Settings()[key]==true or false
end
function B.Short(t)
    local h=math.floor(t/3600); local m=math.floor((t%3600)/60)
    return string.format("%dh %02dm",h,m)
end
function B.Long(t)
    t=math.floor(t+.5)
    local h=math.floor(t/3600); local m=math.floor((t%3600)/60); local s=t%60
    if h>0 then return string.format("%d h %d min",h,m) end
    if m>0 then return string.format("%d min %d s",m,s) end
    return string.format("%d s",s)
end
local function seconds(v) return plain(v) and type(v)=="number" and v==v and v>0 and v<864000 and v or nil end
-- One buff button: after the game writes its time, ours goes over it.
function B:HookButton(button)
    if not button or button.ftBuffTimes or not button.UpdateDuration or not button.Duration or not hooksecurefunc then return end
    button.ftBuffTimes=true
    hooksecurefunc(button,"UpdateDuration",function(owner,timeLeft)
        if not on("buffMinutes") then return end
        local t=seconds(timeLeft)
        if not t or t<3600 then return end
        local text=owner.Duration
        if text and text.IsShown and text:IsShown() then text:SetText(B.Short(t)) end
    end)
end
function B:HookButtons()
    for _,frame in ipairs({BuffFrame or false,DebuffFrame or false}) do
        if frame and type(frame.auraFrames)=="table" then
            for _,button in ipairs(frame.auraFrames) do self:HookButton(button) end
        end
    end
end
-- The tooltip line. The owner is the buff button, which knows its time left.
function B:Tooltip(tip)
    if not on("buffTipTime") or tip~=GameTooltip then return end
    local owner=tip.GetOwner and tip:GetOwner()
    if not owner or not owner.Duration then return end
    local t=seconds(owner.timeLeft)
    if not t then return end
    tip:AddLine("Time left: "..B.Long(t),.85,.85,.85)
    tip:Show()
end
-- Time left on your target's and focus's buffs and debuffs (your stuns,
-- for example). The game draws the sweep on them but hides its numbers
-- there; nameplates show them. Turning the numbers on is enough: the game
-- counts them itself, also in fights where addons can't read the time.
-- Found through the game's own CooldownFrame_Set: a cooldown inside the
-- target or focus frame's aura buttons, checked once per cooldown.
local OWNERS={}
local marked={}
local function underUnitFrame(frame)
    for _=1,8 do
        if not frame then return false end
        if OWNERS[frame] then return true end
        frame=frame.GetParent and frame:GetParent()
    end
    return false
end
function B:AuraCooldown(cooldown)
    if not cooldown or cooldown.ftAuraChecked then
        if cooldown and cooldown.ftAuraNumbers~=nil and cooldown.ftAuraNumbers~=on("auraCountdown") then self:SetNumbers(cooldown) end
        return
    end
    cooldown.ftAuraChecked=true
    local button=cooldown.GetParent and cooldown:GetParent()
    if not button or not button.GetAuraInstance or not underUnitFrame(button) then return end
    marked[#marked+1]=cooldown
    self:SetNumbers(cooldown)
end
function B:SetNumbers(cooldown)
    if not cooldown.SetHideCountdownNumbers then return end
    local show=on("auraCountdown")
    cooldown.ftAuraNumbers=show
    pcall(cooldown.SetHideCountdownNumbers,cooldown,not show)
    -- Small icons: a smaller, outlined number.
    if show and not cooldown.ftAuraFont and cooldown.GetCountdownFontString then
        local ok,text=pcall(cooldown.GetCountdownFontString,cooldown)
        if ok and text and text.GetFont then
            local font,_,flags=text:GetFont()
            if font then pcall(text.SetFont,text,font,10,"OUTLINE"); cooldown.ftAuraFont=true end
        end
    end
end
function B:Apply()
    self:HookButtons()
    for _,cooldown in ipairs(marked) do self:SetNumbers(cooldown) end
    -- The game sets the buttons' text again within a moment; a buff that
    -- just changed setting is redrawn on its next update.
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    B:HookButtons()
    for _,frame in ipairs({TargetFrame or false,FocusFrame or false}) do if frame then OWNERS[frame]=true end end
    if hooksecurefunc and CooldownFrame_Set then hooksecurefunc("CooldownFrame_Set",function(cooldown) B:AuraCooldown(cooldown) end) end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura,function(tip) pcall(B.Tooltip,B,tip) end)
    end
    -- Buttons the game makes later (more buffs than at login).
    C_Timer.After(5,function() B:HookButtons() end)
end)
