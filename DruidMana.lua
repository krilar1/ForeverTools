local _,FT=...
-- Druid mana while shapeshifted: a third bar under the player frame's power
-- bar. It uses the game's own three-bar player frame art (the look Blizzard
-- gives classes with a second resource), so it reads as part of the frame.
-- The bar is ours; Blizzard's own alternate power bar is never touched.
-- Only textures and our own bar change, so everything here is safe in combat.
local Mana={}
local MANA=0
local secret=issecretvalue or function() return false end
local BAR_ATLAS="UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana"
local MASK_ATLAS="UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Mask"
local SQUARE_MASK="Unit_BarMask"
local FLASH="UI-HUD-UnitFrame-Player-PortraitOn-InCombat"
local FLASH_THREE="UI-HUD-UnitFrame-Player-PortraitOn-ClassResource-InCombat"
local known={}
local function atlas(name)
    if known[name]==nil then
        local ok,info=pcall(function() return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) end)
        known[name]=ok and info~=nil
    end
    return known[name]
end

function Mana:On()
    local colors=FT.modules.UnitColors
    return colors~=nil and colors:Settings().druidMana==true
end
-- The pieces of Blizzard's player frame we need; nil if the frame is built differently.
function Mana:Parts()
    local frame=PlayerFrame
    local container=frame and frame.PlayerFrameContainer
    local content=frame and frame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    if not container or not main or not container.FrameTexture or not container.AlternatePowerFrameTexture then return end
    return frame,container,main
end
function Mana:Build()
    if self.bar then return self.bar end
    local _,_,main=self:Parts()
    -- The player frame is protected; only attach to it out of combat.
    if not main or InCombatLockdown() then return end
    local bar=CreateFrame("StatusBar",nil,main)
    bar:SetSize(124,9); bar:SetPoint("TOPLEFT",main,"TOPLEFT",85,-73)
    if atlas(BAR_ATLAS) then bar:SetStatusBarTexture(BAR_ATLAS)
    else bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar"); bar:SetStatusBarColor(0,.35,1) end
    local fill=bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill then
        if fill.SetTexelSnappingBias then fill:SetTexelSnappingBias(0) end
        if fill.SetSnapToPixelGrid then fill:SetSnapToPixelGrid(false) end
        -- Rounded bottom corners, like the last bar of Blizzard's frame.
        if bar.CreateMaskTexture and fill.AddMaskTexture and atlas(MASK_ATLAS) then
            local mask=bar:CreateMaskTexture()
            mask:SetAtlas(MASK_ATLAS,true); mask:SetPoint("TOPLEFT",bar,"TOPLEFT",-2,3)
            fill:AddMaskTexture(mask); bar.mask=mask
        end
    end
    bar.text=bar:CreateFontString(nil,"OVERLAY","TextStatusBarText"); bar.text:SetPoint("CENTER"); bar.text:Hide()
    -- Hover shows the numbers; clicks still reach the player frame.
    if bar.SetMouseClickEnabled then
        bar:EnableMouse(true); bar:SetMouseClickEnabled(false)
        bar:SetScript("OnEnter",function() self.hover=true; self:UpdateText() end)
        bar:SetScript("OnLeave",function() self.hover=false; self:UpdateText() end)
    end
    bar:Hide()
    self.bar=bar
    for _,name in ipairs({"PlayerFrame_ToPlayerArt","PlayerFrame_ToVehicleArt"}) do
        if hooksecurefunc and type(_G[name])=="function" then
            -- Blizzard just redrew the frame its own way; put our look back if needed.
            hooksecurefunc(name,function() self.artOn=false; self:Update() end)
        end
    end
    return bar
end
-- Should the bar show now? nil means the game hides the answer: keep what is shown.
function Mana:Wanted()
    if not self.druid or not self:On() or not UnitPowerType then return false end
    local frame,container=self:Parts()
    if not frame then return false end
    if frame.activeAlternatePowerBar then return false end
    local vehicle=container.VehicleFrameTexture
    if vehicle and vehicle:IsShown() then return false end
    local power=UnitPowerType("player")
    if secret(power) then return nil end
    return type(power)=="number" and power~=MANA
end
-- Swap between the two-bar and three-bar frame art (textures only).
function Mana:Art(on)
    local frame,container,main=self:Parts()
    if not frame then return end
    local manaBar=main.ManaBarArea and main.ManaBarArea.ManaBar
    local barMask=manaBar and manaBar.ManaBarMask
    local flash=container.FrameFlash
    if on then
        container.FrameTexture:Hide(); container.AlternatePowerFrameTexture:Show()
        if barMask and barMask.SetAtlas and atlas(SQUARE_MASK) then barMask:SetAtlas(SQUARE_MASK,true) end
        if flash and flash.SetAtlas and atlas(FLASH_THREE) then flash:SetAtlas(FLASH_THREE,true); flash:SetPoint("CENTER",container,"CENTER",-2,.5) end
    elseif self.artOn then
        -- Undo only what we changed, and only when Blizzard is not showing its own art there.
        local vehicle=container.VehicleFrameTexture
        if not frame.activeAlternatePowerBar and not (vehicle and vehicle:IsShown()) then
            container.AlternatePowerFrameTexture:Hide(); container.FrameTexture:Show()
            if barMask and barMask.SetAtlas and atlas(MASK_ATLAS) then barMask:SetAtlas(MASK_ATLAS,true) end
            if flash and flash.SetAtlas and atlas(FLASH) then flash:SetAtlas(FLASH,true); flash:SetPoint("CENTER",container,"CENTER",-1.5,1) end
        end
    end
    self.artOn=on==true
end
function Mana:UpdateText()
    local bar=self.bar
    if not bar then return end
    local show=bar:IsShown() and (self.always==true or self.hover==true)
    bar.text:SetShown(show)
    if not show then return end
    -- The game formats the numbers itself, so hidden values are fine here.
    if not pcall(bar.text.SetFormattedText,bar.text,"%d / %d",UnitPower("player",MANA),UnitPowerMax("player",MANA)) then bar.text:SetText("") end
end
function Mana:Values()
    local bar=self.bar
    if not bar or not bar:IsShown() then return end
    bar:SetMinMaxValues(0,UnitPowerMax("player",MANA))
    bar:SetValue(UnitPower("player",MANA))
    self:UpdateText()
end
function Mana:Update()
    local wanted=self:Wanted()
    if wanted==nil then self:Values(); return end
    if wanted and not self.bar then self:Build() end
    local bar=self.bar
    if not bar then return end
    if wanted then
        self:Art(true); bar:Show(); self:Values()
    else
        bar:Hide(); bar.text:Hide(); self:Art(false)
    end
end
local events=CreateFrame("Frame")
function Mana:Apply()
    if not FT.dbReady then return end
    if self.druid==nil then local _,class=UnitClass("player"); self.druid=class=="DRUID" end
    if not self.druid then return end
    local on=self:On()
    if on and not self.listening then
        self.listening=true
        for _,event in ipairs({"PLAYER_ENTERING_WORLD","UPDATE_SHAPESHIFT_FORM","PLAYER_REGEN_ENABLED","CVAR_UPDATE"}) do events:RegisterEvent(event) end
        for _,event in ipairs({"UNIT_DISPLAYPOWER","UNIT_MAXPOWER","UNIT_POWER_UPDATE"}) do
            if events.RegisterUnitEvent then events:RegisterUnitEvent(event,"player") else events:RegisterEvent(event) end
        end
    elseif not on and self.listening then
        self.listening=false
        for _,event in ipairs({"PLAYER_ENTERING_WORLD","UPDATE_SHAPESHIFT_FORM","PLAYER_REGEN_ENABLED","CVAR_UPDATE","UNIT_DISPLAYPOWER","UNIT_MAXPOWER","UNIT_POWER_UPDATE"}) do events:UnregisterEvent(event) end
    end
    self:ReadStatusText()
    self:Update()
end
-- Blizzard's "status text" option: numbers always on the bars, or only on hover.
function Mana:ReadStatusText()
    local get=(C_CVar and C_CVar.GetCVar) or GetCVar
    local ok,value=pcall(function() return get and get("statusText") end)
    self.always=ok and value=="1"
end
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event,unit,token)
    if event=="PLAYER_LOGIN" then Mana:Apply(); return end
    if not FT.dbReady or not Mana.listening then return end
    local mine=not secret(unit) and unit=="player"
    if event=="UNIT_POWER_UPDATE" then
        -- Rage and energy change constantly; only mana matters here.
        if mine and (secret(token) or token=="MANA") then Mana:Values() end
    elseif event=="UNIT_MAXPOWER" then
        if mine then Mana:Values() end
    elseif event=="CVAR_UPDATE" then
        Mana:ReadStatusText(); Mana:UpdateText()
    elseif event=="UNIT_DISPLAYPOWER" then
        if mine then Mana:Update() end
    else Mana:Update() end
end)
FT:RegisterModule("DruidMana",Mana)
