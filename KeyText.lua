local _,FT=...
-- Short key text (System > Keybind tools, off by default): the key shown on
-- action buttons in a compact form. Shift-1 is S1, Ctrl-6 is C6, mouse
-- button 5 is M5, Shift + mouse button 5 is SM5, mouse wheel up is WU.
-- Worked out from the binding itself (SHIFT-BUTTON5), so it reads the same in
-- every game language. Only the button's key text changes; nothing secure is
-- touched, so it also works in a fight.
local K={}
local MODS={SHIFT="S",CTRL="C",ALT="A",META="Cmd"}
local NAMED={MOUSEWHEELUP="WU",MOUSEWHEELDOWN="WD",SPACE="Sp",ESCAPE="Esc",BACKSPACE="Bs",CAPSLOCK="Cap",TAB="Tab",ENTER="Ent",
    PAGEUP="PU",PAGEDOWN="PD",INSERT="Ins",DELETE="Del",HOME="Hm",END="End",UP="Up",DOWN="Dn",LEFT="Lt",RIGHT="Rt",
    NUMPADPLUS="N+",NUMPADMINUS="N-",NUMPADMULTIPLY="N*",NUMPADDIVIDE="N/",NUMPADDECIMAL="N.",NUMLOCK="NL",PRINTSCREEN="PS",SCROLLLOCK="SL",PAUSE="Pa",
    BACKSLASH="\\",SEMICOLON=";",APOSTROPHE="'",COMMA=",",PERIOD=".",SLASH="/",MINUS="-",EQUALS="=",LEFTBRACKET="[",RIGHTBRACKET="]",TILDE="`"}
local cache={}
function K.Short(key)
    if type(key)~="string" or key=="" then return nil end
    local text=cache[key]
    if text then return text end
    local mods,rest="",key
    while true do
        local m,r=rest:match("^(%u+)%-(.+)$")
        if m and MODS[m] then mods=mods..MODS[m]; rest=r else break end
    end
    local k
    local button=rest:match("^BUTTON(%d+)$")
    local pad=rest:match("^NUMPAD(%d)$")
    if button then k="M"..button
    elseif pad then k="N"..pad
    elseif NAMED[rest] then k=NAMED[rest]
    elseif #rest<=3 then k=rest
    else
        local ok,t=pcall(GetBindingText,rest,true)
        k=(ok and type(t)=="string" and t~="") and t or rest
    end
    text=mods..k
    cache[key]=text
    return text
end
-- Which binding each bar's buttons use.
local BARS={
    {"ActionButton","ACTIONBUTTON",12},{"MultiBarBottomLeftButton","MULTIACTIONBAR1BUTTON",12},{"MultiBarBottomRightButton","MULTIACTIONBAR2BUTTON",12},
    {"MultiBarRightButton","MULTIACTIONBAR3BUTTON",12},{"MultiBarLeftButton","MULTIACTIONBAR4BUTTON",12},{"MultiBar5Button","MULTIACTIONBAR5BUTTON",12},
    {"MultiBar6Button","MULTIACTIONBAR6BUTTON",12},{"MultiBar7Button","MULTIACTIONBAR7BUTTON",12},
    {"StanceButton","SHAPESHIFTBUTTON",10},{"PetActionButton","BONUSACTIONBUTTON",10},
}
function K:On() local s=FT.modules.System and FT.modules.System:Settings(); return s and s.shortKeys==true end
-- Nudge (System > Keybind tools): the key text slid left/right and up/down,
-- in points, from where the game puts it.
function K:Offset()
    local s=FT.modules.System and FT.modules.System:Settings() or {}
    local x,y=tonumber(s.keyX) or 0,tonumber(s.keyY) or 0
    return math.max(-12,math.min(12,x)),math.max(-12,math.min(12,y))
end
function K:Place(button)
    local hotkey=button and button.HotKey
    if not hotkey or not hotkey.GetNumPoints then return end
    local x,y=self:Offset()
    if not hotkey.ftPoints then
        if x==0 and y==0 then return end
        hotkey.ftPoints={}
        for i=1,hotkey:GetNumPoints() do hotkey.ftPoints[i]={hotkey:GetPoint(i)} end
    end
    if hotkey.ftX==x and hotkey.ftY==y then return end
    hotkey.ftX,hotkey.ftY=x,y
    hotkey:ClearAllPoints()
    for _,p in ipairs(hotkey.ftPoints) do hotkey:SetPoint(p[1],p[2],p[3],(p[4] or 0)+x,(p[5] or 0)+y) end
end
function K:Paint(button,command)
    local hotkey=button and button.HotKey
    if not hotkey or not hotkey.SetText then return end
    command=button.commandName or command
    if not command or not GetBindingKey then return end
    local ok,key=pcall(GetBindingKey,command)
    if not ok or type(key)~="string" then return end
    local text
    if self:On() then text=K.Short(key)
    else local okT,t=pcall(GetBindingText,key,true); text=okT and t or nil end
    if text and hotkey:GetText()~=text then hotkey:SetText(text) end
end
function K:Each(fn)
    for _,bar in ipairs(BARS) do
        for i=1,bar[3] do local b=_G[bar[1]..i]; if b then fn(b,bar[2]..i) end end
    end
end
function K:Apply()
    if not FT.dbReady then return end
    local on=self:On()
    local x,y=self:Offset()
    if x~=0 or y~=0 or self.placed then self.placed=true; self:Each(function(b) self:Place(b) end) end
    if not on and not self.touched then return end
    self.touched=true
    if on and not self.hooked then
        self.hooked=true
        -- The game redraws the key text now and then (new binding, range
        -- check): put the short text back each time.
        self:Each(function(b,command)
            if b.UpdateHotkeys and hooksecurefunc then hooksecurefunc(b,"UpdateHotkeys",function(owner) if K:On() then K:Paint(owner,command) end end) end
        end)
        if hooksecurefunc and ActionButton_UpdateHotkeys then
            hooksecurefunc("ActionButton_UpdateHotkeys",function(owner) if K:On() then K:Paint(owner) end end)
        end
    end
    self:Each(function(b,command) self:Paint(b,command) end)
end
FT:RegisterModule("KeyText",K)
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","UPDATE_BINDINGS","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
    if event=="UPDATE_BINDINGS" then cache={} end
    FT:Coalesce("keyText",function() K:Apply() end,.2)
end)
