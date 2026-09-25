local _,FT=...
-- Leveling stats: a small movable line and extra XP-bar tooltip lines.
-- Session-based: resets on reload and on level-up. Off by default.
local Leveling={kills={}}
local parts={
    {"perHour","XP per hour","8.2k XP/h"},
    {"timeToLevel","Time to level","Level in: 42m"},
    {"kills","Kills to level","Kills to level: 27"},
    {"progress","XP progress","XP: 12,340 / 45,000 (27%)"},
    {"rested","Rested XP","Rested: 5,000"},
}
local partByKey={}; for _,entry in ipairs(parts) do partByKey[entry[1]]=entry end
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
local function number(v,default,low,high)
    if type(v)~="number" or v~=v then return default end
    return math.max(low,math.min(high,v))
end
function Leveling:Settings()
    if type(FT.db.leveling)~="table" then FT.db.leveling={} end
    local s=FT.db.leveling
    if type(s.enabled)~="boolean" then s.enabled=false end
    for _,entry in ipairs(parts) do
        if type(s[entry[1]])~="boolean" then s[entry[1]]=entry[1]=="perHour" or entry[1]=="timeToLevel" or entry[1]=="kills" end
    end
    if type(s.tooltip)~="boolean" then s.tooltip=true end
    s.fontSize=number(s.fontSize,13,10,32)
    -- Player-built layout: the order of the stats, and one per line or all on one line.
    if s.layout~="single" then s.layout="lines" end
    local order,seen={},{}
    for _,key in ipairs(type(s.order)=="table" and s.order or {}) do
        if partByKey[key] and not seen[key] then order[#order+1]=key; seen[key]=true end
    end
    for _,entry in ipairs(parts) do if not seen[entry[1]] then order[#order+1]=entry[1] end end
    s.order=order
    return s
end
local function short(value)
    value=math.floor(value+.5)
    if value>=100000 then return string.format("%dk",math.floor(value/1000+.5)) end
    if value>=10000 then return string.format("%.1fk",value/1000) end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(value) or tostring(value)
end
local function duration(seconds)
    if not seconds or seconds~=seconds or seconds==math.huge then return nil end
    seconds=math.floor(seconds+.5)
    if seconds<60 then return "<1m" end
    local hours=math.floor(seconds/3600); local minutes=math.floor((seconds%3600)/60)
    if hours>=100 then return "100h+" end
    return hours>0 and string.format("%dh %dm",hours,minutes) or string.format("%dm",minutes)
end
function Leveling:MaxLevel()
    local ok,value=pcall(function()
        if GameRulesUtil and GameRulesUtil.IsPlayerAtEffectiveMaxLevel then return GameRulesUtil.IsPlayerAtEffectiveMaxLevel() end
        return UnitLevel("player")>=(GetMaxPlayerLevel and GetMaxPlayerLevel() or 60)
    end)
    if ok and value then return true end
    if IsXPUserDisabled then local okDisabled,disabled=pcall(IsXPUserDisabled); if okDisabled and disabled then return true end end
    return false
end
function Leveling:Reset()
    self.start=GetTime(); self.gained=0; self.kills={}
    self.lastXP=UnitXP("player"); self.lastLevel=UnitLevel("player")
end
function Leveling:ObserveXP()
    local current,level=UnitXP("player"),UnitLevel("player")
    if not readable(current) or not readable(level) then return end
    if not self.start then self:Reset() return end
    if level~=self.lastLevel then self:Reset() return end
    local delta=current-(self.lastXP or current)
    if delta>0 then self.gained=self.gained+delta end
    self.lastXP=current
end
-- "X dies, you gain N experience." Built from the client's own global string so
-- it follows the game language; English wording is only a fallback.
local killPattern
local function pattern()
    if killPattern then return killPattern end
    local template=type(COMBATLOG_XPGAIN_FIRSTPERSON)=="string" and COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience."
    template=template:gsub("%.$","")
    local escaped=template:gsub("([%(%)%.%+%-%*%?%[%]%^%$])","%%%1")
    killPattern=escaped:gsub("%%s","(.-)"):gsub("%%d","(%%d+)")
    return killPattern
end
function Leveling:ObserveKill(text)
    if not readable(text) or type(text)~="string" then return end
    local ok,_,amount=pcall(string.match,text,pattern())
    amount=ok and tonumber(amount)
    if not amount or amount<=0 then return end
    local kills=self.kills; kills[#kills+1]=amount
    if #kills>10 then table.remove(kills,1) end
end
function Leveling:Stats()
    if not self.start then self:Reset() end
    local current,maximum=UnitXP("player"),UnitXPMax("player")
    if not readable(current) or not readable(maximum) or maximum<=0 then return end
    local elapsed=GetTime()-self.start
    local perSecond=(elapsed>=60 and self.gained>0) and self.gained/elapsed or nil
    local rested=GetXPExhaustion and GetXPExhaustion() or 0
    if not readable(rested) then rested=0 end
    local remaining=maximum-current
    local average
    if #self.kills>0 then local total=0; for _,v in ipairs(self.kills) do total=total+v end; average=total/#self.kills end
    return {current=current,maximum=maximum,percent=math.floor(current/maximum*100),rested=rested or 0,
        perHour=perSecond and perSecond*3600,timeToLevel=perSecond and remaining/perSecond,
        kills=average and math.ceil(remaining/average),gained=self.gained,elapsed=elapsed}
end
function Leveling:Text(stats)
    local s=self:Settings(); local out={}
    local lines=s.layout=="lines"
    for _,key in ipairs(s.order) do
        if s[key] then
            local text
            if key=="progress" then text=string.format(lines and "XP: %s / %s (%d%%)" or "XP %s / %s (%d%%)",short(stats.current),short(stats.maximum),stats.percent)
            elseif key=="rested" then text=(lines and "Rested: " or "Rested ")..short(stats.rested)
            elseif key=="perHour" then text=stats.perHour and (short(stats.perHour).." XP/h") or "– XP/h"
            elseif key=="timeToLevel" then text=(lines and "Level in: " or "Level in ")..(duration(stats.timeToLevel) or "–")
            elseif key=="kills" then text=lines and ("Kills to level: "..(stats.kills or "–")) or (stats.kills and ("~"..stats.kills.." kills") or "– kills") end
            out[#out+1]=text
        end
    end
    return table.concat(out,lines and "\n" or "  ·  ")
end
function Leveling:DefaultPosition()
    return 16,UIParent:GetHeight()-54
end
function Leveling:Position()
    if not self.line then return end
    local s=self:Settings()
    local x,y=s.x,s.y
    if type(x)~="number" or type(y)~="number" then x,y=self:DefaultPosition()
    else
        if type(s.screenWidth)=="number" and s.screenWidth>0 then x=x*UIParent:GetWidth()/s.screenWidth end
        if type(s.screenHeight)=="number" and s.screenHeight>0 then y=y*UIParent:GetHeight()/s.screenHeight end
    end
    self.line:ClearAllPoints()
    self.line:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x,y)
end
function Leveling:Create()
    if self.line then return end
    local line=CreateFrame("Frame","ForeverToolsLeveling",UIParent)
    self.line=line
    line:SetFrameStrata("HIGH"); line:SetClampedToScreen(true); line:SetMovable(true)
    if line.SetDontSavePosition then line:SetDontSavePosition(true) end
    line:RegisterForDrag("LeftButton")
    line.text=line:CreateFontString(nil,"OVERLAY","GameFontNormal")
    line.text:SetPoint("TOPLEFT",8,-6); line.text:SetJustifyH("LEFT"); line.text:SetJustifyV("TOP")
    if line.text.SetSpacing then line.text:SetSpacing(3) end
    FT:Panel(line)
    line.hint=FT:Label(line,"Drag to move",12); line.hint:SetPoint("TOPLEFT",line,"BOTTOMLEFT",4,-4)
    line:SetScript("OnDragStart",function(owner) if self.moving and not InCombatLockdown() then owner:StartMoving() end end)
    line:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local s=self:Settings()
        s.x,s.y=owner:GetLeft(),owner:GetTop(); s.screenWidth,s.screenHeight=UIParent:GetWidth(),UIParent:GetHeight()
        self:Position()
    end)
    line.elapsed=0
    line:SetScript("OnUpdate",function(owner,dt)
        owner.elapsed=owner.elapsed+dt
        if owner.elapsed>=1 then owner.elapsed=0; self:Update() end
    end)
end
function Leveling:Update()
    if not self.line or not self.line:IsShown() then return end
    local stats=self:Stats()
    local text=stats and self:Text(stats) or ""
    if text=="" then text=self.moving and "Leveling stats — choose what to show" or "" end
    self.line.text:SetText(text)
    local height=self.line.text:GetStringHeight() or 0
    if height<=0 then height=self:Settings().fontSize end
    self.line:SetSize(math.max(120,(self.line.text:GetStringWidth() or 0)+16),height+12)
end
function Leveling:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    self:Create()
    local font,_,flags=GameFontNormal:GetFont()
    self.line.text:SetFont(font,s.fontSize,flags or "")
    self.line.text:SetTextColor(GameFontNormal:GetTextColor())
    self:Position()
    local moving=self.moving==true
    self.line:EnableMouse(moving)
    for _,texture in ipairs(self.line.fillTextures) do texture:SetShown(moving) end
    for _,texture in ipairs(self.line.borderTextures) do texture:SetShown(moving) end
    self.line.hint:SetShown(moving)
    self.line:SetShown(moving or (s.enabled and not self:MaxLevel()))
    self:Update()
    self:HookBars()
    self:Refresh()
end
function Leveling:SetMoving(value)
    if InCombatLockdown() then value=false end
    self.moving=value==true
    if self.moving then self:Settings().enabled=true end
    self:Apply()
end
-- Append to Blizzard's own XP bar tooltip (which already shows XP and rested).
function Leveling:TooltipLines(owner)
    local s=self:Settings()
    if not s.enabled or not s.tooltip or self:MaxLevel() then return end
    local stats=self:Stats(); if not stats then return end
    local tip=GameTooltip
    if not tip:IsShown() then tip:SetOwner(owner,"ANCHOR_TOP") end
    tip:AddLine(" ")
    local function row(label,value) tip:AddDoubleLine(label,value,.79,.63,1,1,1,1) end
    for _,key in ipairs(s.order) do
        if s[key] then
            if key=="perHour" then row("XP per hour",stats.perHour and short(stats.perHour) or "gathering…")
            elseif key=="timeToLevel" then row("Time to level",duration(stats.timeToLevel) or "gathering…")
            elseif key=="kills" then row("Kills to level",stats.kills and ("~"..stats.kills) or "after your next kill") end
        end
    end
    row("This session","+"..short(stats.gained).." XP in "..(duration(stats.elapsed) or "<1m"))
    tip:Show()
end
function Leveling:HookBars()
    self.hooked=self.hooked or {}
    local function hook(bar)
        if not bar or self.hooked[bar] or not bar.HookScript then return end
        self.hooked[bar]=true
        bar:HookScript("OnEnter",function(owner) self:TooltipLines(owner) end)
    end
    for _,name in ipairs({"MainStatusTrackingBarContainer","SecondaryStatusTrackingBarContainer"}) do
        local container=_G[name]
        for _,bar in pairs(container and container.bars or {}) do
            if type(bar)=="table" and bar.isExpBar then hook(bar) end
        end
    end
    hook(_G.MainMenuExpBar)
end
function Leveling:Move(key,delta)
    local order=self:Settings().order
    for i,value in ipairs(order) do
        if value==key then
            local j=i+delta
            if j>=1 and j<=#order then order[i],order[j]=order[j],order[i] end
            break
        end
    end
    self:Apply()
end
function Leveling:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Leveling stats: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    -- Rows follow the chosen order, top to bottom, like the stats on screen.
    for i,key in ipairs(s.order) do
        local row=self.rows[key]
        row.toggle:ClearAllPoints(); row.toggle:SetPoint("TOPLEFT",self.frame,"TOPLEFT",24,-178-(i-1)*40)
        row.toggle.label:SetText(partByKey[key][2]..": "..(s[key] and "On" or "Off")); FT:SetSelected(row.toggle,s[key])
        row.up:SetEnabled(i>1); row.up:SetAlpha(i>1 and 1 or .35)
        row.down:SetEnabled(i<#s.order); row.down:SetAlpha(i<#s.order and 1 or .35)
    end
    self.layout.label:SetText("Layout: "..(s.layout=="lines" and "One stat per line" or "All on one line"))
    self.tooltipButton.label:SetText("XP bar tooltip: "..(s.tooltip and "On" or "Off")); FT:SetSelected(self.tooltipButton,s.tooltip)
    self.moveButton.label:SetText(self.moving and "Moving unlocked — click to lock" or "Move stats"); FT:SetSelected(self.moveButton,self.moving)
    self.sizeLabel:SetText(string.format("Font size: %d",s.fontSize))
    self.smaller:SetEnabled(s.fontSize>10); self.larger:SetEnabled(s.fontSize<32)
end
function Leveling:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsLeveling","ForeverTools | Leveling stats",540,560); self.frame=frame
        FT:BackTo(frame,"SystemGameplay")
        local hint=FT:Label(frame,"Session stats reset when you reload or level up. Hidden at max level.",13)
        hint:SetPoint("TOPLEFT",24,-60); hint:SetWidth(492)
        self.toggle=FT:QuietButton(frame,"",492,36,"fps"); self.toggle:SetPoint("TOPLEFT",24,-86)
        self.toggle:SetScript("OnClick",function() if self.moving then self.moving=false end; local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Leveling stats","Show your chosen stats on screen and extra lines in the XP bar tooltip.")
        local build=FT:Label(frame,"Build your layout: turn stats on or off and use the arrows to order them.",13)
        build:SetPoint("TOPLEFT",24,-150); build:SetWidth(492); build:SetTextColor(.78,.74,.86)
        self.rows={}
        for _,entry in ipairs(parts) do
            local key=entry[1]
            local row={}
            row.toggle=FT:QuietButton(frame,"",400,34,"fps")
            row.toggle:SetScript("OnClick",function() local s=self:Settings(); s[key]=not s[key]; self:Apply() end)
            FT:Tooltip(row.toggle,entry[2],"Show "..entry[2]:lower()..". Example: "..entry[3])
            -- Blizzard's own friends-list arrow (used by Forever's UI), referenced from the game, not bundled.
            row.up=FT:QuietButton(frame,"",40,34)
            row.up.arrow=row.up:CreateTexture(nil,"ARTWORK"); row.up.arrow:SetPoint("CENTER")
            row.up.arrow:SetAtlas("friendslist-categorybutton-arrow-down",true); row.up.arrow:SetRotation(math.pi)
            row.up:SetPoint("LEFT",row.toggle,"RIGHT",6,0)
            row.up:SetScript("OnClick",function() self:Move(key,-1) end)
            FT:Tooltip(row.up,"Move up","Show this stat earlier.")
            row.down=FT:QuietButton(frame,"",40,34)
            row.down.arrow=row.down:CreateTexture(nil,"ARTWORK"); row.down.arrow:SetPoint("CENTER")
            row.down.arrow:SetAtlas("friendslist-categorybutton-arrow-down",true)
            row.down:SetPoint("LEFT",row.up,"RIGHT",6,0)
            row.down:SetScript("OnClick",function() self:Move(key,1) end)
            FT:Tooltip(row.down,"Move down","Show this stat later.")
            self.rows[key]=row
        end
        local y=-178-#parts*40-6
        self.layout=FT:QuietButton(frame,"",240,34,"move"); self.layout:SetPoint("TOPLEFT",24,y)
        self.layout:SetScript("OnClick",function() local s=self:Settings(); s.layout=s.layout=="lines" and "single" or "lines"; self:Apply() end)
        FT:Tooltip(self.layout,"Layout","Show each stat on its own line, or all stats on one compact line.")
        self.tooltipButton=FT:QuietButton(frame,"",240,34,"tooltip"); self.tooltipButton:SetPoint("TOPLEFT",276,y)
        self.tooltipButton:SetScript("OnClick",function() local s=self:Settings(); s.tooltip=not s.tooltip; self:Apply() end)
        FT:Tooltip(self.tooltipButton,"XP bar tooltip","Add your chosen stats to the XP bar tooltip, in the same order.")
        y=y-44
        self.moveButton=FT:QuietButton(frame,"",240,34,"move"); self.moveButton:SetPoint("TOPLEFT",24,y)
        self.moveButton:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.moveButton,"Move stats","Unlock, drag the stats anywhere, then lock them. Moving turns the stats on.")
        local reset=FT:QuietButton(frame,"Reset position",240,34,"reset"); reset:SetPoint("TOPLEFT",276,y)
        reset:SetScript("OnClick",function() local s=self:Settings(); s.x,s.y,s.screenWidth,s.screenHeight=nil,nil,nil,nil; self:Apply() end)
        FT:Tooltip(reset,"Reset position","Return the stats to the top left of the screen.")
        y=y-48
        self.smaller=FT:QuietButton(frame,"−",40,32); self.smaller:SetPoint("TOPLEFT",24,y)
        self.smaller:SetScript("OnClick",function() local s=self:Settings(); s.fontSize=math.max(10,s.fontSize-1); self:Apply() end)
        self.sizeLabel=FT:Label(frame,"",16); self.sizeLabel:SetPoint("LEFT",self.smaller,"RIGHT",18,0); self.sizeLabel:SetWidth(135)
        self.larger=FT:QuietButton(frame,"+",40,32); self.larger:SetPoint("LEFT",self.sizeLabel,"RIGHT",10,0)
        self.larger:SetScript("OnClick",function() local s=self:Settings(); s.fontSize=math.min(32,s.fontSize+1); self:Apply() end)
        local note=FT:Label(frame,"Kills to level uses your recent kill experience. XP per hour starts after a minute of play.",12)
        note:SetPoint("BOTTOMLEFT",24,20); note:SetWidth(492); note:SetTextColor(.66,.57,.77)
        frame:SetHeight(-y+32+50)
        frame:HookScript("OnHide",function() if self.moving then self:SetMoving(false) end end)
    end
    self:Apply(); self.frame:Show()
end
FT:RegisterModule("Leveling",Leveling)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","CHAT_MSG_COMBAT_XP_GAIN","PLAYER_REGEN_DISABLED","UI_SCALE_CHANGED","DISPLAY_SIZE_CHANGED"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,arg)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then Leveling:Reset(); Leveling:Apply()
    elseif event=="PLAYER_XP_UPDATE" then if arg==nil or arg=="player" then Leveling:ObserveXP() end
    elseif event=="PLAYER_LEVEL_UP" then C_Timer.After(0,function() Leveling:Reset(); Leveling:Apply() end)
    elseif event=="CHAT_MSG_COMBAT_XP_GAIN" then Leveling:ObserveKill(arg)
    elseif event=="PLAYER_REGEN_DISABLED" then if Leveling.moving then Leveling:SetMoving(false) end
    else C_Timer.After(1,function() if FT.dbReady then Leveling:Apply() end end) end
end)
