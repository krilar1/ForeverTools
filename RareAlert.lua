local _,FT=...
-- Rare alerts (off by default): a notice with a soft gold glow when a rare
-- shows up on the minimap or as a nameplate, plus an optional sound. Event
-- driven only (no scanning), and each rare alerts once per spawn.
local Rare={seen={},seenCount=0}
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local sounds={
    {value="chime",label="Soft chime",kit="MAP_PING"},
    {value="bell",label="Quest bell",kit="IG_QUEST_LIST_OPEN"},
    {value="horn",label="Adventure horn",kit="UI_WORLDQUEST_START"},
    {value="loot",label="Treasure",kit="UI_EPICLOOT_TOAST"},
    {value="warning",label="Raid warning",kit="RAID_WARNING"},
}
local durations={{0,"Until clicked"},{10,"10 seconds"},{20,"20 seconds"},{30,"30 seconds"},{60,"1 minute"}}
function Rare:Settings()
    if type(FT.db.rareAlert)~="table" then FT.db.rareAlert={} end
    local s=FT.db.rareAlert
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.sound)~="boolean" then s.sound=false end
    local known=false; for _,e in ipairs(sounds) do if e.value==s.soundKey then known=true end end
    if not known then s.soundKey="chime" end
    s.duration=tonumber(s.duration) or 20
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    if type(s.glow)~="table" then s.glow={1,.78,.25} end
    for i=1,3 do s.glow[i]=type(s.glow[i])=="number" and math.max(0,math.min(1,s.glow[i])) or 1 end
    return s
end
function Rare:PlaySound()
    local s=self:Settings()
    for _,e in ipairs(sounds) do
        if e.value==s.soundKey and SOUNDKIT and SOUNDKIT[e.kit] and PlaySound then
            -- The master channel, so it is not lost when the effects slider
            -- is low. Ctrl+S (sound on/off) still mutes it.
            pcall(PlaySound,SOUNDKIT[e.kit],"Master")
        end
    end
end
-- Soft glow: a few rounded rings around the notice, each a little wider and
-- fainter, added on top of each other so the light fades out smoothly with
-- round corners. Built from the addon's own rounded texture.
local ROUNDED="Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga"
local function cvar(name)
    local v=C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name) or (GetCVar and GetCVar(name))
    return v
end
-- A short warning when the game would make the alert sound hard to hear.
function Rare:VolumeWarning()
    if cvar("Sound_EnableAllSound")=="0" then return "Game sound is off (Ctrl+S), so the alert is silent." end
    local master=tonumber(cvar("Sound_MasterVolume"))
    if master and master<.25 then return string.format("Your master volume is %d%%, so the alert may be hard to hear.",math.floor(master*100+.5)) end
    return nil
end
local function glowRings(frame)
    local list={}
    local cuts={0,.25,.75,1}
    for ring=1,6 do
        local out=ring*2
        local corner=8+out
        for row=0,2 do for col=0,2 do
            local t=frame:CreateTexture(nil,"BACKGROUND",nil,-8)
            t:SetTexture(ROUNDED); t:SetBlendMode("ADD")
            t:SetTexCoord(cuts[col+1],cuts[col+2],cuts[row+1],cuts[row+2])
            local x1=col==0 and -out or (col==1 and corner-out or -corner+out)
            local x2=col==0 and corner-out or (col==1 and -corner+out or out)
            local y1=row==0 and out or (row==1 and -corner+out or corner-out)
            local y2=row==0 and -corner+out or (row==1 and corner-out or -out)
            t:SetPoint("TOPLEFT",frame,(row==2 and "BOTTOM" or "TOP")..(col==2 and "RIGHT" or "LEFT"),x1,y1)
            t:SetPoint("BOTTOMRIGHT",frame,(row==0 and "TOP" or "BOTTOM")..(col==0 and "LEFT" or "RIGHT"),x2,y2)
            t.strength=.075
            list[#list+1]=t
        end end
    end
    return list
end
function Rare:Notice()
    if self.notice then return self.notice end
    local f=CreateFrame("Button","ForeverToolsRareAlert",UIParent)
    f:SetSize(300,46); f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true)
    FT:Panel(f); FT:Paint(f,{.06,.045,.02,.95},{.85,.66,.25,1}); FT:MeterSkin(f)
    f.glow=glowRings(f)
    f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetSize(30,30); f.icon:SetPoint("LEFT",9,0)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("VignetteKill") then f.icon:SetAtlas("VignetteKill") else f.icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot") end
    f.title=FT:Label(f,"Rare nearby",11,true); f.title:SetPoint("TOPLEFT",f.icon,"TOPRIGHT",9,1); f.title:SetTextColor(1,.82,.4)
    f.name=FT:Label(f,"",15,true); f.name:SetPoint("TOPLEFT",f.title,"BOTTOMLEFT",0,-2); f.name:SetWidth(240)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    -- A gentle pulse of the glow when the notice appears.
    local pulse=f:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local fade=pulse:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(.35); fade:SetDuration(.9)
    f.pulse=pulse
    f:RegisterForClicks("LeftButtonUp","RightButtonUp"); f:RegisterForDrag("LeftButton"); f:SetMovable(true)
    f:SetScript("OnClick",function(_,button)
        if button=="RightButton" then if not InCombatLockdown() then FT:OpenModule("RareAlert") end
        elseif not self.moving then f:Hide() end
    end)
    f:SetScript("OnDragStart",function() if self.moving then f:StartMoving() end end)
    f:SetScript("OnDragStop",function()
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local s=self:Settings()
        if x and y then local scale=f:GetScale(); s.x,s.y=x*scale,y*scale end
        self:Position()
    end)
    FT:Tooltip(f,"Rare alert","Left-click to dismiss, right-click for settings.")
    -- Click to target: a game "secure" button over the notice that runs
    -- /targetexact with the rare's name. The game only lets addons set it up
    -- out of combat, so in combat the notice just dismisses on click.
    do
        local ok,t=pcall(CreateFrame,"Button","ForeverToolsRareTarget",UIParent,"SecureActionButtonTemplate")
        if ok and t then
            t:SetFrameStrata("MEDIUM"); t:SetFrameLevel(f:GetFrameLevel()+10)
            t:RegisterForClicks("LeftButtonUp","RightButtonUp")
            t:SetAttribute("useOnKeyDown",false); t:SetAttribute("type1","macro")
            t:SetScript("PostClick",function(_,button)
                if button=="RightButton" then if not InCombatLockdown() then FT:OpenModule("RareAlert") end end
                f:Hide()
            end)
            t:SetScript("OnEnter",function(btn)
                GameTooltip:SetOwner(btn,"ANCHOR_BOTTOM"); GameTooltip:SetText("Rare alert",1,.82,.4)
                GameTooltip:AddLine("Left-click to target "..(self.targetName or "it").." and dismiss. Right-click for settings.",1,1,1,true)
                GameTooltip:Show()
            end)
            t:SetScript("OnLeave",function() GameTooltip:Hide() end)
            t:Hide()
            self.target=t
        end
    end
    f:HookScript("OnHide",function() self:UpdateTarget() end)
    f:Hide()
    self.notice=f
    return f
end
-- Shows the target button over the notice (out of combat only). It sits on
-- its own at the same spot, so the notice itself never becomes protected.
function Rare:UpdateTarget()
    local t=self.target; if not t or InCombatLockdown() then return end
    local f=self.notice
    local name=self.targetName
    if f and f:IsShown() and name and not self.moving and not self.previewing then
        t:SetAttribute("macrotext1","/targetexact "..name)
        local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
        local l,b,w,h=f:GetRect()
        t:ClearAllPoints()
        if l then t:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",l*scale,b*scale); t:SetSize(w*scale,h*scale); t:Show()
        else t:Hide(); if not self.retry then self.retry=true; C_Timer.After(0,function() self.retry=false; self:UpdateTarget() end) end end
    else t:Hide() end
    if f and f:IsShown() and not self.previewing then f.title:SetText(t:IsShown() and "Rare nearby · click to target" or "Rare nearby") end
end
function Rare:Position()
    local f=self:Notice(); local s=self:Settings()
    f:SetScale(s.size); f:ClearAllPoints()
    if type(s.x)=="number" and type(s.y)=="number" then f:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x/s.size,s.y/s.size)
    else f:SetPoint("TOP",UIParent,"TOP",0,-190/s.size) end
    if f:IsShown() then self:UpdateTarget() end
end
function Rare:PaintGlow()
    local f=self.notice; if not f then return end
    local c=self:Settings().glow
    for _,t in ipairs(f.glow) do t:SetVertexColor(c[1],c[2],c[3],t.strength) end
end
function Rare:Show(name,preview)
    local f=self:Notice(); local s=self:Settings()
    self:Position()
    self:PaintGlow()
    f.name:SetText(name or "Unknown rare")
    f.title:SetText(preview and "Rare nearby (preview)" or "Rare nearby")
    self.targetName=(not preview) and name or nil; self.previewing=preview and true or false
    f:Show(); f.pulse:Stop(); f.pulse:Play()
    self:UpdateTarget()
    C_Timer.After(2.7,function() if f.pulse then f.pulse:Stop() end end)
    self.token=(self.token or 0)+1
    local token=self.token
    if s.duration>0 and not self.moving then C_Timer.After(s.duration,function() if self.token==token and not self.moving and not self.pickingGlow then f:Hide() end end) end
    if s.sound and not preview then self:PlaySound() end
end
function Rare:Found(key,name)
    if not self:Settings().enabled or not key or self.seen[key] then return end
    self.seen[key]=true; self.seenCount=self.seenCount+1
    -- Keep the memory small: forget old spawns after a while.
    if self.seenCount>200 then self.seen={}; self.seenCount=0; self.seen[key]=true end
    self:Show(name)
end
function Rare:Vignette(guid)
    if not guid or secret(guid) or not C_VignetteInfo or not C_VignetteInfo.GetVignetteInfo then return end
    local ok,info=pcall(C_VignetteInfo.GetVignetteInfo,guid)
    if not ok or type(info)~="table" then return end
    local atlas=info.atlasName
    if secret(atlas) or type(atlas)~="string" or not atlas:find("VignetteKill",1,true) then return end
    if info.isDead then return end
    local name=info.name; if secret(name) then name=nil end
    self:Found("v:"..guid,name)
end
function Rare:Nameplate(unit)
    local ok,class=pcall(UnitClassification,unit)
    if not ok or secret(class) or (class~="rare" and class~="rareelite") then return end
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit); if secret(dead) or dead then return end
    local guid=UnitGUID and UnitGUID(unit); if not guid or secret(guid) then return end
    local name=UnitName(unit); if secret(name) then name=nil end
    self:Found("u:"..guid,name)
end
local events=CreateFrame("Frame")
function Rare:Apply()
    local on=self:Settings().enabled
    if on then
        pcall(events.RegisterEvent,events,"VIGNETTE_MINIMAP_UPDATED"); events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
        events:RegisterEvent("PLAYER_REGEN_DISABLED"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
    else events:UnregisterAllEvents(); if self.notice and not self.moving then self.notice:Hide() end end
    self:Refresh()
end
events:SetScript("OnEvent",function(_,event,a,b)
    if not FT.dbReady then return end
    if event=="VIGNETTE_MINIMAP_UPDATED" then if b then Rare:Vignette(a) end
    elseif event=="NAME_PLATE_UNIT_ADDED" then Rare:Nameplate(a)
    elseif event=="PLAYER_REGEN_DISABLED" then if Rare.target then Rare.target:Hide() end
    elseif event=="PLAYER_REGEN_ENABLED" then Rare:UpdateTarget() end
end)
function Rare:SetMoving(on)
    self.moving=on
    if on then self:Show("Drag me, then click Lock",true) elseif self.notice then self.notice:Hide() end
    self:Refresh()
end

-- Settings page
local function durationText(v) for _,d in ipairs(durations) do if d[1]==v then return d[2] end end return "20 seconds" end
local function soundText(v) for _,e in ipairs(sounds) do if e.value==v then return e.label end end return "Soft chime" end
function Rare:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Rare alerts: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.soundToggle.label:SetText("Sound: "..(s.sound and "On" or "Off")); FT:SetSelected(self.soundToggle,s.sound)
    self.soundChoice.value=s.soundKey; self.soundChoice.label:SetText(soundText(s.soundKey))
    self.durationChoice.value=s.duration; self.durationChoice.label:SetText("Hide after: "..durationText(s.duration))
    self.sizeLabel:SetText(string.format("Size: %d%%",math.floor(s.size*100+.5)))
    self.settingSize=true; self.sizeSlider:SetValue(s.size); self.settingSize=false
    self.glowSwatch:SetVertexColor(unpack(s.glow)); self:PaintGlow()
    local warn=s.sound and self:VolumeWarning()
    if warn then self.volumeNote:SetText(warn); self.volumeNote:SetTextColor(1,.62,.35)
    else self.volumeNote:SetText("") end
    self.move.label:SetText(self.moving and "Lock position" or "Move alert"); FT:SetSelected(self.move,self.moving)
end
function Rare:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsRareAlerts","Rare alerts",520,366); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        FT:PageInfo(frame,"Rare alerts","A notice (and optional sound) when a rare appears on your minimap or nearby. Each rare alerts once. Click the notice to target the rare (out of combat), right-click it for these settings.")
        self.toggle=FT:AccentButton(frame,"",472,34,"Ability_Hunter_SniperShot"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Rare alerts","Turn rare alerts on or off.")
        self.soundToggle=FT:QuietButton(frame,"",230,32,"INV_Misc_Bell_01"); self.soundToggle:SetPoint("TOPLEFT",24,-108)
        self.soundToggle:SetScript("OnClick",function() local s=self:Settings(); s.sound=not s.sound; self:Refresh() end)
        FT:Tooltip(self.soundToggle,"Sound","Also play a sound. It plays at your master volume, and Ctrl+S (sound on/off) mutes it.")
        self.soundChoice=FT:Dropdown(frame,230,function()
            local list={}; for _,e in ipairs(sounds) do list[#list+1]={value=e.value,label=e.label,icon="Interface\\Icons\\INV_Misc_Bell_01",tooltip="A sound from the game itself. Choosing it plays a short preview."} end; return list
        end,function(value) self:Settings().soundKey=value; self:PlaySound(); self:Refresh() end,"INV_Misc_Bell_01")
        self.soundChoice:SetPoint("TOPLEFT",266,-110)
        self.durationChoice=FT:Dropdown(frame,472,function()
            local list={}; for _,d in ipairs(durations) do list[#list+1]={value=d[1],label=d[2],icon="Interface\\Icons\\INV_Misc_PocketWatch_01"} end; return list
        end,function(value) self:Settings().duration=value; self:Refresh() end,"fps")
        self.volumeNote=FT:Label(frame,"",12); self.volumeNote:SetPoint("TOPLEFT",24,-148); self.volumeNote:SetWidth(472)
        self.durationChoice:SetPoint("TOPLEFT",24,-174); self.durationChoice.menuWidth=472
        FT:Tooltip(self.durationChoice,"Hide after","How long the notice stays. Click it to dismiss it sooner.")
        self.sizeLabel=FT:Label(frame,"",14); self.sizeLabel:SetPoint("TOPLEFT",24,-222)
        self.sizeSlider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); self.sizeSlider:SetSize(300,18); self.sizeSlider:SetPoint("TOPLEFT",196,-220)
        self.sizeSlider:SetMinMaxValues(.7,1.5); self.sizeSlider:SetValueStep(.05); self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,v) if self.settingSize then return end self:Settings().size=math.floor(v*20+.5)/20; self:Position(); self:Refresh() end)
        FT:Tooltip(self.sizeSlider,"Size","Make the notice smaller or bigger (70% to 150%).")
        self.glowButton=FT:QuietButton(frame,"Glow color",230,32,"fonts"); self.glowButton:SetPoint("TOPLEFT",24,-260)
        self.glowSwatch=self.glowButton:CreateTexture(nil,"ARTWORK"); self.glowSwatch:SetTexture("Interface\\Buttons\\WHITE8x8"); self.glowSwatch:SetSize(16,16); self.glowSwatch:SetPoint("RIGHT",-10,0)
        self.glowButton:SetScript("OnClick",function()
            if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
            local s=self:Settings(); local old={unpack(s.glow)}
            FT:TrackColorPicker()
            -- Keep an example notice on screen while you pick, so you see the
            -- glow change live. It closes with the color picker.
            self.pickingGlow=true
            if not (self.notice and self.notice:IsShown()) then self:Show("Example rare",true) end
            if not self.glowPickerHooked then
                self.glowPickerHooked=true
                ColorPickerFrame:HookScript("OnHide",function()
                    if not self.pickingGlow then return end
                    self.pickingGlow=false
                    if self.notice and self.previewing and not self.moving then self.notice:Hide() end
                end)
            end
            ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,
                swatchFunc=function() s.glow={ColorPickerFrame:GetColorRGB()}; self:Refresh() end,
                cancelFunc=function() s.glow=old; self:Refresh() end})
        end)
        FT:Tooltip(self.glowButton,"Glow color","The color of the soft glow around the notice.")
        local preview=FT:QuietButton(frame,"Preview",230,32,"Ability_Hunter_SniperShot"); preview:SetPoint("TOPLEFT",266,-260)
        preview:SetScript("OnClick",function() self:Show("Example rare",true); if self:Settings().sound then self:PlaySound() end end)
        FT:Tooltip(preview,"Preview","Show an example notice (and play the sound if it is on).")
        self.move=FT:QuietButton(frame,"",230,32,"move"); self.move:SetPoint("TOPLEFT",24,-302)
        self.move:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.move,"Move alert","Click to unlock, drag the notice where you want it, then click again to lock it.")
        local reset=FT:QuietButton(frame,"Reset position",230,32,"reset"); reset:SetPoint("TOPLEFT",266,-302)
        reset:SetScript("OnClick",function() local s=self:Settings(); s.x,s.y=nil,nil; self:Position() end)
        FT:Tooltip(reset,"Reset position","Put the notice back at the top of the screen.")
        frame:HookScript("OnHide",function()
            if self.moving then self:SetMoving(false) end
            if self.pickingGlow and ColorPickerFrame and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        end)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("RareAlert",Rare)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Rare:Apply() end end)
