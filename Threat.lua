local _,FT=...
-- Threat (off by default): a small threat meter in the style of the game's
-- own damage meter, placed next to it, and your threat % above the target's
-- portrait. Uses only the game's threat functions. Where the game keeps threat
-- numbers private (some group content), values still show but cannot be
-- sorted or colored, because addons may display them but not compare them.
-- Event driven, updates at most five times a second, and does nothing while
-- both parts are off.
local Threat={rows={}}
local ICON="Ability_Warrior_DefensiveStance"
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function yes(v) return not secret(v) and v and true or false end
local function number(v,default,low,high)
    if type(v)~="number" or v~=v then return default end
    return math.max(low,math.min(high,v))
end
local function hasAtlas(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)~=nil end
local shows={{"combat","In combat"},{"group","In a group"},{"always","Always"}}
local MIN_W,MIN_H,MAX_W,MAX_H=180,80,600,500

function Threat:Settings()
    if type(FT.db.threat)~="table" then FT.db.threat={} end
    local s=FT.db.threat
    if type(s.enabled)~="boolean" then s.enabled=false end
    local known=false; for _,e in ipairs(shows) do if e[1]==s.show then known=true end end
    if not known then s.show="combat" end
    s.rows=number(s.rows,5,3,20) -- older setting, kept for profiles; the size now comes from resizing
    if s.width~=nil then s.width=number(s.width,260,MIN_W,MAX_W) end
    if s.height~=nil then s.height=number(s.height,150,MIN_H,MAX_H) end
    if type(s.collapsed)~="boolean" then s.collapsed=false end
    if type(s.locked)~="boolean" then s.locked=false end
    if s.grip~="always" and s.grip~="hover" then s.grip="always" end
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    -- Threat % above the target portrait.
    if type(s.text)~="boolean" then s.text=false end
    if type(s.font)~="string" then s.font="friz" end
    s.size=number(s.size,14,8,32)
    if s.outline~="" and s.outline~="OUTLINE" and s.outline~="THICKOUTLINE" then s.outline="OUTLINE" end
    if type(s.background)~="boolean" then s.background=false end
    local c=s.backgroundColor
    if type(c)~="table" or type(c[1])~="number" or type(c[2])~="number" or type(c[3])~="number" then s.backgroundColor={0,0,0} end
    s.backgroundAlpha=number(s.backgroundAlpha,.6,0,1)
    s.textX=number(s.textX,0,-400,400); s.textY=number(s.textY,2,-400,400)
    return s
end

-- The mob whose threat we show: your target, if you can attack it.
local function mob()
    if not yes(UnitExists("target")) then return nil end
    if not yes(UnitCanAttack("player","target")) then return nil end
    local dead=UnitIsDead("target"); if secret(dead) or dead then return nil end
    return "target"
end
function Threat:Units()
    local list={"player"}
    if yes(UnitExists("pet")) then list[#list+1]="pet" end
    if IsInRaid() then
        for i=1,(GetNumGroupMembers() or 0) do
            local unit="raid"..i
            local me=UnitIsUnit(unit,"player")
            if yes(UnitExists(unit)) and not (not secret(me) and me) then list[#list+1]=unit end
        end
    elseif IsInGroup() then
        for i=1,4 do if yes(UnitExists("party"..i)) then list[#list+1]="party"..i end end
    end
    return list
end
-- One entry per unit on the mob's threat list. value is the "scaled" threat:
-- 100 means that unit has (or is about to take) aggro.
function Threat:Entries(target)
    local list,private={},false
    if not target or not UnitDetailedThreatSituation then return list,private end
    for _,unit in ipairs(self:Units()) do
        local tanking,_,scaled=UnitDetailedThreatSituation(unit,target)
        if secret(scaled) then
            private=true; list[#list+1]={unit=unit,value=scaled}
        elseif type(scaled)=="number" then
            local tank=yes(tanking)
            list[#list+1]={unit=unit,value=tank and 100 or scaled,tank=tank}
        end
    end
    if not private then
        table.sort(list,function(a,b)
            if a.value~=b.value then return a.value>b.value end
            return a.unit=="player"
        end)
    end
    return list,private
end

-- Look: the damage meter's own header, background and bar art, and its bar
-- height, spacing and background transparency when it is there.
function Threat:DamageMeter()
    local meter=_G.DamageMeter
    if type(meter)~="table" or not meter.GetWidth then return nil end
    return meter
end
function Threat:Style()
    local style={barHeight=22,spacing=3,background=.8}
    local meter=self:DamageMeter()
    if meter then
        local function read(method,key,low,high)
            if type(meter[method])~="function" then return end
            local ok,v=pcall(meter[method],meter)
            if ok and type(v)=="number" and not secret(v) then style[key]=math.max(low,math.min(high,v)) end
        end
        read("GetBarHeight","barHeight",14,40); read("GetBarSpacing","spacing",0,10); read("GetBackgroundAlpha","background",0,1)
    end
    return style
end
local function button(parent,size,normal,pushed,highlight)
    local b=CreateFrame("Button",nil,parent); b:SetSize(size[1],size[2])
    if hasAtlas(normal) then
        b:SetNormalAtlas(normal); if pushed and hasAtlas(pushed) then b:SetPushedAtlas(pushed) end
        if highlight and hasAtlas(highlight) then b:SetHighlightAtlas(highlight,"ADD") end
        b.art=true
    end
    return b
end
function Threat:Meter()
    if self.meter then return self.meter end
    local f=CreateFrame("Frame","ForeverToolsThreatMeter",UIParent)
    f:SetSize(260,120); f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.header=f:CreateTexture(nil,"BACKGROUND",nil,1); f.header:SetPoint("TOPLEFT"); f.header:SetPoint("TOPRIGHT"); f.header:SetHeight(32)
    if hasAtlas("ui-damagemeters-header-bar") then f.header:SetAtlas("ui-damagemeters-header-bar")
    else f.header:SetColorTexture(.05,.04,.08,.9) end
    f.body=f:CreateTexture(nil,"BACKGROUND")
    f.body:SetPoint("TOPLEFT",0,-30); f.body:SetPoint("BOTTOMRIGHT")
    if hasAtlas("damagemeters-background") then f.body:SetAtlas("damagemeters-background") else f.body:SetColorTexture(0,0,0,.6) end
    f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalMed1"); f.title:SetPoint("TOPLEFT",8,-9); f.title:SetText("Threat")
    f.target=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.target:SetPoint("LEFT",f.title,"RIGHT",8,0)
    f.target:SetJustifyH("LEFT"); if f.target.SetWordWrap then f.target:SetWordWrap(false) end
    -- Hide (collapse) and settings, where the damage meter has them.
    f.hide=button(f,{18,19},"ui-questtrackerbutton-collapse-all","ui-questtrackerbutton-collapse-all-pressed","ui-questtrackerbutton-red-highlight")
    f.hide:SetPoint("TOPRIGHT",-3,-5)
    if not f.hide.art then f.hide.text=FT:Label(f.hide,"–",14); f.hide.text:SetPoint("CENTER") end
    f.hide:SetScript("OnClick",function() local s=self:Settings(); s.collapsed=not s.collapsed; self:Update() end)
    f.gear=button(f,{27,27},"common-dropdown-a-button-settings-shadowless","common-dropdown-a-button-settings-pressed-shadowless","common-dropdown-a-button-settings-hover-shadowless")
    f.gear:SetPoint("RIGHT",f.hide,"LEFT",-2,-2)
    if not f.gear.art then f.gear:SetNormalTexture("Interface\\Icons\\Trade_Engineering") end
    f.gear:SetScript("OnClick",function() if not InCombatLockdown() then FT:OpenModule("Threat") end end)
    f.target:SetPoint("RIGHT",f.gear,"LEFT",-4,0)
    for _,b in ipairs({f.hide,f.gear}) do
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    f.hide:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText(self:Settings().collapsed and "Show bars" or "Hide bars",1,1,1)
        GameTooltip:AddLine("Only the title bar stays. Turn the meter off in its settings.",.8,.8,.8,true); GameTooltip:Show()
    end)
    f.gear:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText("Threat meter settings",1,1,1)
        GameTooltip:AddLine("Drag the title bar to move the meter.",.8,.8,.8,true); GameTooltip:Show()
    end)
    f.empty=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.empty:SetPoint("TOP",0,-44)
    -- Drag the title bar to move it (out of combat).
    f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(owner) if not InCombatLockdown() and (self.moverUnlock or not self:Settings().locked) then owner:StartMoving() end end)
    f:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local s=self:Settings()
        s.x,s.y=owner:GetLeft(),owner:GetTop()
        self:Place()
    end)
    -- Resize from the bottom-right corner, with the damage meter's own handle.
    -- It shows while the mouse is over the meter, like on the damage meter.
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W,MIN_H,MAX_W,MAX_H) elseif f.SetMinResize then f:SetMinResize(MIN_W,MIN_H); f:SetMaxResize(MAX_W,MAX_H) end
    f.grip=CreateFrame("Button",nil,f); f.grip:SetFrameLevel(f:GetFrameLevel()+5)
    if hasAtlas("damagemeters-scalehandle") then
        f.grip:SetSize(60,60); f.grip:SetPoint("BOTTOMRIGHT",9,-8)
        f.grip:SetNormalAtlas("damagemeters-scalehandle")
        if hasAtlas("damagemeters-scalehandle-hover") then f.grip:SetHighlightAtlas("damagemeters-scalehandle-hover") end
        if hasAtlas("damagemeters-scalehandle-pressed") then f.grip:SetPushedAtlas("damagemeters-scalehandle-pressed") end
        f.grip:SetHitRectInsets(30,0,30,0)
    else
        f.grip:SetSize(16,16); f.grip:SetPoint("BOTTOMRIGHT",-2,2)
        f.grip:SetNormalTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Up")
        f.grip:SetHighlightTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Highlight")
        f.grip:SetPushedTexture("Interface\ChatFrame\UI-ChatIM-SizeGrabber-Down")
    end
    -- Shown always, or while the mouse is over the meter (checked ten times a
    -- second, only in that mode and only while the meter is on screen).
    local function hover() self:UpdateGrip() end
    f.gripElapsed=0
    f:SetScript("OnUpdate",function(owner,dt)
        if not owner.gripWatch then return end
        owner.gripElapsed=owner.gripElapsed+dt
        if owner.gripElapsed<.1 then return end
        owner.gripElapsed=0; self:UpdateGrip()
    end)
    f.grip:SetScript("OnMouseDown",function(_,button)
        local s=self:Settings()
        if button~="LeftButton" or InCombatLockdown() or s.collapsed or (s.locked and not self.moverUnlock) then return end
        self.sizing=true; f:StartSizing("BOTTOMRIGHT")
    end)
    f.grip:SetScript("OnMouseUp",function()
        if not self.sizing then return end
        self.sizing=false; f:StopMovingOrSizing()
        local s=self:Settings()
        s.width=math.floor(f:GetWidth()+.5); s.height=math.floor(f:GetHeight()+.5)
        -- Sizing can move the anchor; keep a moved meter where it now is.
        if s.x and s.y then s.x,s.y=f:GetLeft(),f:GetTop() end
        self:Place(); self:Update(); hover()
    end)
    f.grip:SetScript("OnEnter",function(b) hover(); GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetText("Resize",1,1,1); GameTooltip:AddLine("Drag to change the width and height.",.8,.8,.8,true); GameTooltip:Show() end)
    f.grip:SetScript("OnLeave",function() hover(); GameTooltip:Hide() end)
    f:SetScript("OnSizeChanged",function() if self.sizing then self:UpdateMeter() end end)
    f:Hide()
    self.meter=f
    return f
end
-- Beside the damage meter: above it, or below when there is no room above.
-- Once you drag the meter, your spot is used instead.
function Threat:Place()
    local f=self:Meter(); local s=self:Settings()
    f:ClearAllPoints()
    f:SetHeight(self:MeterHeight())
    if s.x and s.y then f:SetWidth(s.width or 260); f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",s.x,s.y); return end
    local meter=self:DamageMeter()
    local top=meter and meter:GetTop()
    if not top then f:SetWidth(s.width or 260); f:SetPoint("RIGHT",UIParent,"RIGHT",-24,80); return end
    local scale=meter:GetEffectiveScale()/UIParent:GetEffectiveScale()
    f:SetWidth(s.width or math.max(MIN_W,math.min(420,meter:GetWidth()*scale)))
    if top*scale+f:GetHeight()+8<=UIParent:GetHeight() then f:SetPoint("BOTTOMLEFT",meter,"TOPLEFT",0,6)
    else f:SetPoint("TOPLEFT",meter,"BOTTOMLEFT",0,-6) end
end
function Threat:UpdateGrip()
    local f=self.meter; if not f then return end
    local s=self:Settings()
    local usable=not s.collapsed and (self.moverUnlock or not s.locked)
    local visible=usable and (self.sizing or self.previewing or s.grip=="always" or f:IsMouseOver())
    f.grip:SetShown(usable); f.grip:SetAlpha(visible and 1 or 0)
    f.gripWatch=usable and s.grip=="hover" and not self.previewing
end
-- Your chosen height, or room for five bars until you resize it.
function Threat:MeterHeight()
    local s=self:Settings()
    if s.collapsed then return 32 end
    if s.height then return s.height end
    local style=self:Style()
    return 38+5*(style.barHeight+style.spacing)
end
function Threat:Row(index)
    local row=self.rows[index]
    if row then return row end
    local f=self.meter
    row=CreateFrame("Frame",nil,f)
    row.bar=CreateFrame("StatusBar",nil,row); row.bar:SetAllPoints()
    if hasAtlas("UI-HUD-CoolDownManager-Bar") then row.bar:SetStatusBarTexture("UI-HUD-CoolDownManager-Bar") else row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar") end
    row.bar:SetMinMaxValues(0,100)
    row.bg=row.bar:CreateTexture(nil,"BACKGROUND"); row.bg:SetPoint("TOPLEFT",-2,2); row.bg:SetPoint("BOTTOMRIGHT",2,-2)
    if hasAtlas("ui-damagemeters-bar-shadowbg") then row.bg:SetAtlas("ui-damagemeters-bar-shadowbg") else row.bg:SetColorTexture(0,0,0,.4) end
    row.value=row.bar:CreateFontString(nil,"OVERLAY","NumberFontNormal"); row.value:SetPoint("RIGHT",-4,0); row.value:SetJustifyH("RIGHT")
    row.name=row.bar:CreateFontString(nil,"OVERLAY","NumberFontNormal"); row.name:SetPoint("LEFT",4,0); row.name:SetPoint("RIGHT",row.value,"LEFT",-8,0)
    row.name:SetJustifyH("LEFT"); if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    self.rows[index]=row
    local fonts=FT.modules.FontManager
    if fonts and fonts:Settings("threatMeter").enabled then FT:Coalesce("threatFonts",function() fonts:ApplyArea("threatMeter") end) end
    return row
end
local sample={{"Tank","WARRIOR",100},{"You","",82},{"Healer","PRIEST",47},{"Damage","MAGE",31},{"Damage","ROGUE",12}}
local function classColor(unit)
    local _,class=UnitClass(unit)
    if not secret(class) and type(class)=="string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then return RAID_CLASS_COLORS[class] end
end
function Threat:ShouldShowMeter()
    local s=self:Settings()
    if self.previewing then return true end
    if not s.enabled then return false end
    if s.show=="always" then return true end
    if s.show=="group" then return IsInGroup() end
    return InCombatLockdown() or yes(UnitAffectingCombat("player"))
end
function Threat:UpdateMeter()
    if not self:ShouldShowMeter() then if self.meter then self.meter:Hide() end return end
    local f=self:Meter(); local s=self:Settings(); local style=self:Style()
    local target=mob()
    local entries,private
    if self.previewing then
        entries={}
        local _,myClass=UnitClass("player")
        for _,e in ipairs(sample) do entries[#entries+1]={name=e[1],class=e[2]=="" and myClass or e[2],value=e[3],tank=e[3]==100} end
        f.target:SetText("(preview)")
    else
        entries,private=self:Entries(target)
        if target then f.target:SetText(UnitName(target)) else f.target:SetText("") end
    end
    f.body:SetAlpha(style.background)
    -- As many bars as fit in the meter's height.
    local height=self.sizing and f:GetHeight() or self:MeterHeight()
    local fit=math.max(1,math.floor((height-38+style.spacing)/(style.barHeight+style.spacing)))
    local shown=s.collapsed and 0 or math.min(#entries,fit)
    for i=1,shown do
        local e=entries[i]; local row=self:Row(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",f,"TOPLEFT",4,-34-(i-1)*(style.barHeight+style.spacing))
        row:SetPoint("RIGHT",f,"RIGHT",-4,0); row:SetHeight(style.barHeight)
        local color
        if e.unit then
            row.name:SetText(UnitName(e.unit)); color=classColor(e.unit)
        else
            row.name:SetText(e.name); color=RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
        end
        if color then row.bar:SetStatusBarColor(color.r,color.g,color.b) else row.bar:SetStatusBarColor(.55,.55,.6) end
        row.bar:SetValue(e.value)
        row.value:SetFormattedText("%.0f%%",e.value)
        row:Show()
    end
    for i=shown+1,#self.rows do self.rows[i]:Hide() end
    local message=""
    if not s.collapsed and shown==0 then message=target and "No threat on this target yet" or "No enemy targeted" end
    f.empty:SetText(message); f.empty:SetShown(message~="")
    if not self.sizing then f:SetHeight(height) end
    self:UpdateGrip()
    if f.hide.art then
        local expand=s.collapsed and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all"
        if hasAtlas(expand) then f.hide:SetNormalAtlas(expand); if hasAtlas(expand.."-pressed") then f.hide:SetPushedAtlas(expand.."-pressed") end end
    end
    f.body:SetShown(not s.collapsed)
    f:Show()
    self.private=private
end

-- Threat % above the target portrait. It sits on the target frame, so it
-- hides with it; it is placed only out of combat.
function Threat:Portrait()
    local frame=_G.TargetFrame
    if not frame then return nil end
    local container=frame.TargetFrameContainer
    return frame,(container and container.Portrait) or frame
end
function Threat:TextFrame()
    if self.text then return self.text end
    local target=self:Portrait(); if not target then return nil end
    local f=CreateFrame("Frame","ForeverToolsThreatText",target)
    f:SetSize(60,22); f:SetFrameLevel(target:GetFrameLevel()+20); f:SetMovable(true)
    if f.SetDontSavePosition then f:SetDontSavePosition(true) end
    f.background=FT:RoundedFill(f,0,0,0,.6)
    f.label=f:CreateFontString(nil,"OVERLAY"); f.label:SetPoint("CENTER",0,0)
    f.label:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(owner) if self.movingText and not InCombatLockdown() then owner:StartMoving() end end)
    f:SetScript("OnDragStop",function(owner)
        owner:StopMovingOrSizing()
        local _,portrait=self:Portrait()
        local x,bottom=owner:GetCenter(),owner:GetBottom()
        local px,top=portrait:GetCenter(),portrait:GetTop()
        if x and bottom and px and top then
            local s=self:Settings()
            local ratio=owner:GetEffectiveScale()/portrait:GetEffectiveScale()
            s.textX=math.floor(x*ratio-px+.5); s.textY=math.floor(bottom*ratio-top+.5)
        end
        self:PlaceText()
    end)
    f:Hide()
    self.text=f
    return f
end
function Threat:PlaceText()
    local f=self:TextFrame(); if not f or InCombatLockdown() then self.placeAfterCombat=true; return end
    local s=self:Settings(); local _,portrait=self:Portrait()
    f:ClearAllPoints(); f:SetPoint("BOTTOM",portrait,"TOP",s.textX,s.textY)
end
function Threat:StyleText()
    local f=self:TextFrame(); if not f then return end
    local s=self:Settings()
    local path=FT.modules.FontManager and FT.modules.FontManager:Resolve(s)
    if not path or not FT.modules.FontManager:ValidFont(path) then path="Fonts\\FRIZQT__.TTF" end
    f.label:SetFont(path,s.size,s.outline)
    local c=s.backgroundColor
    for _,t in ipairs(f.background) do t:SetVertexColor(c[1],c[2],c[3],s.backgroundAlpha); t:SetShown(s.background or self.movingText) end
    f:EnableMouse(self.movingText==true)
end
function Threat:UpdateText()
    local s=self:Settings()
    local f=self.text
    if not s.text and not self.movingText then if f then f:Hide() end return end
    f=self:TextFrame(); if not f then return end
    local value,status
    if self.movingText then value,status=72,1
    else
        local target=mob()
        if target and UnitDetailedThreatSituation then
            local tanking; tanking,status,value=UnitDetailedThreatSituation("player",target)
            if not secret(value) and yes(tanking) then value=100 end
        end
    end
    if not secret(value) and (type(value)~="number" or value<=0) then f:Hide(); return end
    f.label:SetFormattedText("%.0f%%",value)
    -- Color by threat level when the game lets us read it; white otherwise.
    if not secret(status) and type(status)=="number" and status>0 and GetThreatStatusColor then f.label:SetTextColor(GetThreatStatusColor(status))
    else f.label:SetTextColor(1,1,1) end
    local w=f.label:GetStringWidth(); if secret(w) or type(w)~="number" then w=s.size*3 end
    f:SetSize(math.max(34,w+14),s.size+10)
    f:Show()
end

function Threat:Update()
    if not FT.dbReady then return end
    self:UpdateMeter(); self:UpdateText()
end
function Threat:Changed() FT:Coalesce("threat",function() self:Update() end,.2) end
local events=CreateFrame("Frame")
local watched={"PLAYER_TARGET_CHANGED","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE","GROUP_ROSTER_UPDATE","UNIT_PET","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","EDIT_MODE_LAYOUTS_UPDATED","UI_SCALE_CHANGED"}
function Threat:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if s.enabled or s.text or self.previewing then
        for _,event in ipairs(watched) do pcall(events.RegisterEvent,events,event) end
    else events:UnregisterAllEvents() end
    if s.enabled or self.previewing then self:Place() end
    if s.text or self.movingText then self:PlaceText(); self:StyleText() end
    self:Update(); self:Refresh()
end
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_DISABLED" then
        if Threat.movingText then Threat.movingText=false; Threat:StyleText(); Threat:Refresh() end
        Threat:Update(); return
    end
    if event=="PLAYER_REGEN_ENABLED" and Threat.placeAfterCombat then Threat.placeAfterCombat=false; Threat:PlaceText() end
    if event=="EDIT_MODE_LAYOUTS_UPDATED" or event=="UI_SCALE_CHANGED" then C_Timer.After(0,function() if Threat.meter then Threat:Place() end end) end
    Threat:Changed()
end)

-- Settings page
local function showText(v) for _,e in ipairs(shows) do if e[1]==v then return e[2] end end return "In combat" end
function Threat:SetMovingText(on)
    if on and InCombatLockdown() then return end
    if on and not yes(UnitExists("target")) then FT:Toast("Target something first, so the target frame is on screen.",3); on=false end
    self.movingText=on==true
    self:Apply()
end
function Threat:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Threat meter: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.showChoice.value=s.show; self.showChoice.label:SetText("Show: "..showText(s.show))
    self.lock.label:SetText("Lock meter: "..(s.locked and "On" or "Off")); FT:SetSelected(self.lock,s.locked)
    self.gripChoice.value=s.grip; self.gripChoice.label:SetText(s.grip=="always" and "Resize corner: always" or "Resize corner: on mouseover")
    self.gripChoice:SetAlpha(s.locked and .5 or 1)
    self.placeNote:SetText((s.x and "Moved by you." or (self:DamageMeter() and "Placed next to the damage meter." or "Placed on the right side."))
        ..(s.locked and " Locked." or ""))
    self.textToggle.label:SetText("Threat % above target: "..(s.text and "On" or "Off")); FT:SetSelected(self.textToggle,s.text)
    local _,label=FT.modules.FontManager:Resolve(s)
    self.fontChoice.value=s.font; self.fontChoice.label:SetText("Font: "..(label or "Friz Quadrata"))
    self.outlineChoice.value=s.outline; self.outlineChoice.label:SetText(s.outline=="" and "No outline" or s.outline=="OUTLINE" and "Outline" or "Thick outline")
    self.sizeLabel:SetText("Font size: "..s.size)
    self.bgToggle.label:SetText("Background: "..(s.background and "On" or "Off")); FT:SetSelected(self.bgToggle,s.background)
    self.bgColor.swatch:SetColorTexture(s.backgroundColor[1],s.backgroundColor[2],s.backgroundColor[3],1)
    self.alphaLabel:SetText(string.format("Transparency: %d%%",math.floor((1-s.backgroundAlpha)*100+.5)))
    self.settingSliders=true
    self.sizeSlider:SetValue(s.size); self.alphaSlider:SetValue(math.floor((1-s.backgroundAlpha)*100+.5))
    self.settingSliders=false
    for _,c in ipairs({self.bgColor,self.alphaSlider,self.alphaLabel}) do c:SetAlpha(s.background and 1 or .5) end
    local p=self.textPreview
    local path=FT.modules.FontManager:Resolve(s)
    if not path or not FT.modules.FontManager:ValidFont(path) then path="Fonts\\FRIZQT__.TTF" end
    p.label:SetFont(path,math.min(s.size,24),s.outline); p.label:SetText("72%")
    if GetThreatStatusColor then p.label:SetTextColor(GetThreatStatusColor(2)) else p.label:SetTextColor(1,.6,0) end
    local w=p.label:GetStringWidth(); if type(w)~="number" then w=40 end
    p.box:SetSize(math.max(34,w+14),math.min(s.size,24)+10)
    local c=s.backgroundColor
    for _,t in ipairs(p.box.background) do t:SetVertexColor(c[1],c[2],c[3],s.backgroundAlpha); t:SetShown(s.background) end
    self.moveText.label:SetText(self.movingText and "Lock position" or "Move threat %"); FT:SetSelected(self.moveText,self.movingText)
end
function Threat:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsThreat","Threat",540,578); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        FT:PageInfo(frame,"Threat","A threat meter that looks like the game's damage meter, and your threat % above your target. 100% means you have aggro, or are about to.\n\nIn some dungeons and raids the game keeps threat numbers private. The meter still shows them there, but can't sort or color them.")
        self.toggle=FT:AccentButton(frame,"",492,34,ICON); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Threat meter","Show a list of your group's threat on your target, next to the damage meter.")
        self.showChoice=FT:Dropdown(frame,240,function()
            local list={}; for _,e in ipairs(shows) do list[#list+1]={value=e[1],label=e[2],icon="Interface\\Icons\\"..ICON} end; return list
        end,function(value) self:Settings().show=value; self:Apply() end,ICON)
        self.showChoice:SetPoint("TOPLEFT",24,-108)
        FT:Tooltip(self.showChoice,"Show","When the meter is on screen. It always shows while this page is open, as a preview.")
        local reset=FT:QuietButton(frame,"Reset position and size",240,32,"reset"); reset:SetPoint("TOPLEFT",276,-108)
        reset:SetScript("OnClick",function() local s=self:Settings(); s.x,s.y,s.width,s.height=nil,nil,nil,nil; self:Apply() end)
        FT:Tooltip(reset,"Reset position and size","Put the meter back next to the damage meter (above it, or below when there is no room), at its starting size.")
        self.lock=FT:QuietButton(frame,"",240,32,"move"); self.lock:SetPoint("TOPLEFT",24,-148)
        self.lock:SetScript("OnClick",function() local s=self:Settings(); s.locked=not s.locked; self:Apply() end)
        FT:Tooltip(self.lock,"Lock meter","Locked: the meter can't be moved or resized and the resize corner is hidden. Unlock to change it.")
        self.gripChoice=FT:Dropdown(frame,240,function()
            local icon="Interface\\Icons\\"..ICON
            return {{value="always",label="Resize corner: always",icon=icon,tooltip="Always show the resize corner while the meter is unlocked."},
                {value="hover",label="Resize corner: on mouseover",icon=icon,tooltip="Show the resize corner only while the mouse is over the meter."}}
        end,function(value) self:Settings().grip=value; self:Apply() end,"move")
        self.gripChoice:SetPoint("TOPLEFT",276,-148)
        FT:Tooltip(self.gripChoice,"Resize corner","When the resize corner shows on the meter. On this page it always shows, so you can size the preview.")
        local function fontButton(label,area,x,tip)
            local b=FT:QuietButton(frame,label,240,32,"fonts"); b:SetPoint("TOPLEFT",x,-188)
            b:SetScript("OnClick",function() local fonts=FT.modules.FontManager; fonts.selected=area; FT:OpenModule("FontManager") end)
            FT:Tooltip(b,label,tip)
        end
        fontButton("Threat meter font","threatMeter",24,"Choose the font, size and outline of the threat meter's text (opens Fonts).")
        fontButton("Damage meter font","damageMeter",276,"Choose the font, size and outline of the game's own damage meter bars (opens Fonts).")
        self.placeNote=FT:Label(frame,"",12); self.placeNote:SetPoint("TOPLEFT",24,-228); self.placeNote:SetWidth(492); self.placeNote:SetTextColor(.66,.59,.48)

        local heading=FT:Label(frame,"Threat % above target",15,true); heading:SetPoint("TOPLEFT",24,-278)
        FT:SectionHeading(heading,ICON,300)
        self.textToggle=FT:AccentButton(frame,"",380,34,ICON); self.textToggle:SetPoint("TOPLEFT",24,-308)
        -- A live example with your font, size, outline and background.
        self.textPreview=CreateFrame("Frame",nil,frame); self.textPreview:SetSize(100,34); self.textPreview:SetPoint("TOPLEFT",416,-308)
        FT:Panel(self.textPreview); FT:Paint(self.textPreview,{.03,.03,.04,1},{.61,.51,.31,1})
        self.textPreview.box=CreateFrame("Frame",nil,self.textPreview); self.textPreview.box:SetPoint("CENTER")
        self.textPreview.box.background=FT:RoundedFill(self.textPreview.box,0,0,0,.6)
        self.textPreview.label=self.textPreview.box:CreateFontString(nil,"OVERLAY"); self.textPreview.label:SetPoint("CENTER")
        self.textPreview.label:SetFont("Fonts\\FRIZQT__.TTF",14,"OUTLINE")
        self.textPreview:EnableMouse(true)
        FT:Tooltip(self.textPreview,"Preview","How the threat % looks with your settings (here at 72%, close to pulling aggro).")
        self.textToggle:SetScript("OnClick",function() local s=self:Settings(); s.text=not s.text; self:Apply() end)
        FT:Tooltip(self.textToggle,"Threat % above target","Your threat on your target, above its portrait. The color turns yellow, orange and red as you get close to pulling aggro.")
        self.fontChoice=FT:Dropdown(frame,240,function() return FT.modules.FontManager:Catalogue() end,function(value) self:Settings().font=value; self:Apply() end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",24,-354)
        FT:Tooltip(self.fontChoice,"Font","The font of the threat %.")
        self.outlineChoice=FT:Dropdown(frame,240,function() return {{value="",label="No outline"},{value="OUTLINE",label="Outline"},{value="THICKOUTLINE",label="Thick outline"}} end,function(value) self:Settings().outline=value; self:Apply() end,"fonts")
        self.outlineChoice:SetPoint("TOPLEFT",276,-354)
        FT:Tooltip(self.outlineChoice,"Outline","A dark edge around the threat %, so it stays readable over bright ground.")
        local function slider(top,min,max,step,title,tip,onChange)
            local text=FT:Label(frame,"",14); text:SetPoint("TOPLEFT",24,top-2); text:SetWidth(160)
            local bar=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); bar:SetSize(300,18); bar:SetPoint("TOPLEFT",196,top)
            bar:SetMinMaxValues(min,max); bar:SetValueStep(step); bar:SetObeyStepOnDrag(true)
            for _,key in ipairs({"Low","High","Text"}) do local r=bar[key] or (bar.GetName and bar:GetName() and _G[bar:GetName()..key]); if r and r.Hide then r:Hide() end end
            bar:SetScript("OnValueChanged",function(_,v) if not self.settingSliders then onChange(v) end end)
            FT:Tooltip(bar,title,tip)
            return text,bar
        end
        self.sizeLabel,self.sizeSlider=slider(-398,8,32,1,"Font size","Text size of the threat % (8 to 32).",function(v) self:Settings().size=math.floor(v+.5); FT:Coalesce("threatSlider",function() self:Apply() end,.05) end)
        self.bgToggle=FT:QuietButton(frame,"",240,32,"skins"); self.bgToggle:SetPoint("TOPLEFT",24,-432)
        self.bgToggle:SetScript("OnClick",function() local s=self:Settings(); s.background=not s.background; self:Apply() end)
        FT:Tooltip(self.bgToggle,"Background","A rounded background behind the threat %.")
        self.bgColor=FT:QuietButton(frame,"Background color",240,32); self.bgColor:SetPoint("TOPLEFT",276,-432)
        self.bgColor.swatch=self.bgColor:CreateTexture(nil,"ARTWORK"); self.bgColor.swatch:SetSize(18,18); self.bgColor.swatch:SetPoint("LEFT",10,0)
        self.bgColor.label:ClearAllPoints(); self.bgColor.label:SetPoint("LEFT",self.bgColor.swatch,"RIGHT",8,0)
        self.bgColor:SetScript("OnClick",function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local s=self:Settings(); local old={unpack(s.backgroundColor)}
            s.background=true
            FT:TrackColorPicker()
            ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,
                swatchFunc=function() s.backgroundColor={ColorPickerFrame:GetColorRGB()}; FT:Coalesce("threatColor",function() self:Apply() end,.05) end,
                cancelFunc=function() s.backgroundColor=old; self:Apply() end})
            self:Apply()
        end)
        FT:Tooltip(self.bgColor,"Background color","Choose the background color. Choosing a color turns the background on.")
        self.alphaLabel,self.alphaSlider=slider(-478,0,100,5,"Transparency","How see-through the background is (0% solid, 100% invisible).",function(v) self:Settings().backgroundAlpha=1-math.floor(v+.5)/100; FT:Coalesce("threatSlider",function() self:Apply() end,.05) end)
        self.moveText=FT:QuietButton(frame,"",240,32,"move"); self.moveText:SetPoint("TOPLEFT",24,-512)
        self.moveText:SetScript("OnClick",function() self:SetMovingText(not self.movingText) end)
        FT:Tooltip(self.moveText,"Move threat %","Target something, click to unlock, drag the number, then click again to lock it. It stays attached to the target frame.")
        local resetText=FT:QuietButton(frame,"Reset position",240,32,"reset"); resetText:SetPoint("TOPLEFT",276,-512)
        resetText:SetScript("OnClick",function() local s=self:Settings(); s.textX,s.textY=0,2; self:Apply() end)
        FT:Tooltip(resetText,"Reset position","Put the threat % back just above the target portrait.")
        frame:SetHeight(578)
        frame:HookScript("OnShow",function() self.previewing=not InCombatLockdown(); self:Apply() end)
        frame:HookScript("OnHide",function() self.previewing=false; if self.movingText then self.movingText=false end; self:Apply() end)
    end
    self.previewing=not InCombatLockdown()
    self.frame:Show(); self:Apply()
end
FT:RegisterModule("Threat",Threat)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Threat:Apply() end end)
