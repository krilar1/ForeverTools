local _, FT = ...
local Colors = { tracked={}, hooks={}, active={} }
local groups = {{"player","Player"}, {"target","Target"}, {"party","Party"}, {"raid","Raid"}, {"focus","Focus"}}
function Colors:Settings()
    if type(FT.db.unitColors) ~= "table" then FT.db.unitColors = {} end
    return FT.db.unitColors
end
local function groupFor(unit)
    if type(unit) ~= "string" then return end
    if unit:match("^party%d+$") then return "party" end
    if unit:match("^raid%d+$") then return "raid" end
    if unit=="targettarget" then return "target" end
    if unit=="focustarget" then return "focus" end
    if unit == "player" or unit == "target" or unit == "focus" then return unit end
end
function Colors:Paint(bar)
    local info = self.tracked[bar]
    if not info or self.painting then return end
    local unit = info.owner and (info.owner.displayedUnit or info.owner.unit) or info.unit
    local enabled = self.active[info.group] == true
    local color
    if enabled and unit and UnitIsPlayer(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
        local _, class = UnitClass(unit)
        color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS or {})[class]
    end
    self.painting = true
    -- Forever health atlases contain a green fill. Multiplying a class color
    -- into that artwork makes it dark green. Use a neutral fill while managed,
    -- retaining the client's geometry and masks, then restore the native atlas.
    local texture=bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if color and texture and texture.SetTexture then
        if not info.art then info.art={texture=texture,file=texture:GetTexture(),atlas=texture.GetAtlas and texture:GetAtlas(),coords=texture.GetTexCoord and {texture:GetTexCoord()},layer=texture.GetDrawLayer and {texture:GetDrawLayer()}} end
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        local parent=bar.GetParent and bar:GetParent()
        local mask=parent and parent.HealthBarMask or bar.HealthBarMask
        if mask and texture.AddMaskTexture and not info.addedMask then texture:AddMaskTexture(mask); info.addedMask=mask end
        -- The prediction mask alone does not preserve the portrait cutout in
        -- Forever's health artwork. Reuse the original fill's alpha as a mask,
        -- fixed to the whole bar so its cutout never moves as health decreases.
        if info.art.atlas and bar.CreateMaskTexture and texture.AddMaskTexture and not info.shapeAttached then
            if not info.shapeMask then
                info.shapeMask=bar:CreateMaskTexture(nil,"BACKGROUND",nil,0)
            end
            info.shapeMask:SetAtlas(info.art.atlas)
            info.shapeMask:SetAllPoints(bar)
            texture:AddMaskTexture(info.shapeMask)
            info.shapeAttached=true
        end
        -- Native health artwork contains a shaded rim. A neutral replacement
        -- must stay beneath frame decorations, not in their overlay layer.
        if texture.SetDrawLayer then texture:SetDrawLayer("BACKGROUND",0) end
        if texture.SetTexCoord then texture:SetTexCoord(0,1,0,1) end
    elseif info.art then
        local art=info.art
        if info.shapeAttached and art.texture.RemoveMaskTexture then art.texture:RemoveMaskTexture(info.shapeMask); info.shapeAttached=nil end
        if info.addedMask and art.texture.RemoveMaskTexture then art.texture:RemoveMaskTexture(info.addedMask); info.addedMask=nil end
        if art.atlas and art.texture.SetAtlas then art.texture:SetAtlas(art.atlas)
        else art.texture:SetTexture(art.file); if art.coords and art.texture.SetTexCoord then art.texture:SetTexCoord(unpack(art.coords)) end end
        if art.layer and art.texture.SetDrawLayer then art.texture:SetDrawLayer(unpack(art.layer)) end
        info.art=nil
    end
    -- The player artwork supplies a dark finish above its fill. Other unit
    -- frames lack that finish, so reduce brightness without shifting the hue.
    local muted=enabled and (info.group=="target" or info.group=="focus")
    local finish=muted and .58 or 1
    if color then bar:SetStatusBarColor(color.r*finish, color.g*finish, color.b*finish)
    elseif muted and info.original then
        local native=info.original
        bar:SetStatusBarColor(native[1]*finish,native[2]*finish,native[3]*finish,native[4] or 1)
    elseif info.colored and info.original then bar:SetStatusBarColor(unpack(info.original)) end
    info.colored = color ~= nil or muted
    self.painting = false
end
function Colors:Track(bar, unit, group, owner)
    if not bar or type(bar.SetStatusBarColor) ~= "function" or not group then return end
    local info = self.tracked[bar]
    if not info then
        info = {original={bar:GetStatusBarColor()}}
        self.tracked[bar] = info
        -- Blizzard recolors health bars frequently. Preserve its latest native color
        -- and apply our optional tint afterwards without replacing its updater.
        if hooksecurefunc then
            hooksecurefunc(bar, "SetStatusBarColor", function(_, r,g,b,a)
                if self.painting then return end
                info.original = {r,g,b,a}
                self:Paint(bar)
            end)
        end
    end
    info.unit, info.group, info.owner = unit, group, owner
    self:Paint(bar)
    local parent=bar.GetParent and bar:GetParent()
    local loss=parent and (parent.PlayerFrameHealthBarAnimatedLoss or parent.TargetFrameHealthBarAnimatedLoss or parent.HealthBarAnimatedLoss)
    if loss and loss~=bar then
        self.losses=self.losses or {}
        if not self.losses[loss] then
            self.losses[loss]={alpha=loss:GetAlpha(),group=group}
            if hooksecurefunc then hooksecurefunc(loss,"SetAlpha",function(_,a)
                if self.paintingLoss then return end
                self.losses[loss].alpha=a; self:PaintLoss(loss)
            end) end
        end
        self:PaintLoss(loss)
    end
end
function Colors:PaintLoss(loss)
    if self.paintingLoss then return end
    local data=self.losses[loss]; self.paintingLoss=true
    loss:SetAlpha(self.active[data.group] and 0 or data.alpha)
    self.paintingLoss=false
end
local function healthBar(frame)
    if not frame then return end
    if frame.healthBar or frame.healthbar then return frame.healthBar or frame.healthbar end
    local container = frame.PlayerFrameContainer or frame.TargetFrameContainer or frame.FocusFrameContainer
    local content = frame.PlayerFrameContent or frame.TargetFrameContent or frame.FocusFrameContent
        or (container and (container.PlayerFrameContent or container.TargetFrameContent or container.FocusFrameContent))
    local main = content and (content.PlayerFrameContentMain or content.TargetFrameContentMain or content.FocusFrameContentMain or content.MainFrame)
    return (main and ((main.HealthBarsContainer and main.HealthBarsContainer.HealthBar) or main.HealthBar))
        or (content and ((content.HealthBarsContainer and content.HealthBarsContainer.HealthBar) or content.HealthBar))
end
function Colors:Compact(frame)
    if not frame then return end
    local unit = frame.displayedUnit or frame.unit
    local group = groupFor(unit)
    local name = frame.GetName and frame:GetName() or ""
    -- Never recolor nameplates, even though they use the compact-frame updater.
    if not name or not name:match("^Compact") then return end
    if name:find("Party",1,true) then group="party" end
    if group == "raid" or group == "party" then self:Track(healthBar(frame), unit, group, frame) end
end
function Colors:LayerPlayerLevel(decorations)
    local content=PlayerFrame and PlayerFrame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    if not main then return end
    if self.active.player then
        if not self.levelOverlay then
            self.levelOverlay=CreateFrame("Frame",nil,main)
            self.levelOverlay:SetAllPoints(main)
            self.levelRegions={}
        end
        self.levelOverlay:SetFrameLevel(decorations:GetFrameLevel()+1)
        for _,region in pairs({circle=main.LevelBackgroundCircle,text=PlayerLevelText}) do
            if region and region.SetParent and not self.levelRegions[region] then
                local old={parent=region:GetParent(),points={}}
                for i=1,region:GetNumPoints() do
                    local point={region:GetPoint(i)}
                    point[2]=point[2] or old.parent
                    old.points[#old.points+1]=point
                end
                self.levelRegions[region]=old
                region:SetParent(self.levelOverlay)
                region:ClearAllPoints()
                for _,point in ipairs(old.points) do region:SetPoint(unpack(point)) end
            end
        end
    elseif self.levelRegions then
        for region,old in pairs(self.levelRegions) do
            region:SetParent(old.parent)
            region:ClearAllPoints()
            for _,point in ipairs(old.points) do region:SetPoint(unpack(point)) end
        end
        self.levelRegions={}
    end
end
function Colors:Apply()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.deferred=true; self:Refresh(); return end
    self.deferred=false
    for _,entry in ipairs(groups) do self.active[entry[1]]=self:Settings()[entry[1]] == true end
    for _, entry in ipairs({{"PlayerFrame","player"}, {"TargetFrame","target"}, {"FocusFrame","focus"}}) do
        local frame = _G[entry[1]]
        self:Track(healthBar(frame) or _G[entry[1] .. "HealthBar"], entry[2], entry[2])
        -- Retail/Classic UI revisions use different frame nesting. These aliases
        -- cover the visible native health bars without touching nameplates.
        self:Track(_G[entry[1] .. "HealthBar"], entry[2], entry[2], frame)
        self:Track(_G[entry[1] .. "HealthBarLeft"], entry[2], entry[2], frame)
        self:Track(_G[entry[1] .. "HealthBarRight"], entry[2], entry[2], frame)
    end
    for _,entry in ipairs({{"TargetFrameToT","targettarget","target"},{"FocusFrameToT","focustarget","focus"}}) do
        local frame=_G[entry[1]]
        self:Track(healthBar(frame) or _G[entry[1].."HealthBar"],entry[2],entry[3],frame)
    end
    for i=1,5 do
        self:Track(healthBar(_G["PartyMemberFrame" .. i]) or _G["PartyMemberFrame" .. i .. "HealthBar"], "party" .. i, "party")
        local modern = PartyFrame and PartyFrame["MemberFrame" .. i]
        if modern then self:Track(healthBar(modern), "party" .. i, "party", modern) end
        self:Compact(_G["CompactPartyFrameMember" .. i])
        for g=1,8 do self:Compact(_G["CompactRaidGroup" .. g .. "Member" .. i]) end
    end
    for i=1,40 do self:Compact(_G["CompactRaidFrame" .. i]) end
    if not self.hooks.compact and type(CompactUnitFrame_UpdateHealthColor) == "function" and hooksecurefunc then
        self.hooks.compact=true
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
            if InCombatLockdown() then
                local bar=healthBar(frame); if self.tracked[bar] then self:Paint(bar) end
            else self:Compact(frame) end
        end)
    end
    -- The player, target and focus bars are recolored by Blizzard after several
    -- unit events. Queue one pass after their native updater has finished.
    if not self.hooks.unitFrame and type(UnitFrameHealthBar_Update) == "function" and hooksecurefunc then
        self.hooks.unitFrame = true
        hooksecurefunc("UnitFrameHealthBar_Update", function(frame, unit)
            local bar = healthBar(frame) or (frame and frame.SetStatusBarColor and frame)
            local resolved = unit or (frame and (frame.displayedUnit or frame.unit))
            if bar and groupFor(resolved) then self:Track(bar, resolved, groupFor(resolved), frame) end
            self:Queue()
        end)
    end
    for bar in pairs(self.tracked) do self:Paint(bar) end
    -- Draw layers only order textures within one frame level. The portrait
    -- container is a sibling below the health-bar content on this client;
    -- move its native decorations above the fill instead of adding new art.
    local decorations=PlayerFrame and PlayerFrame.PlayerFrameContainer
    local bar=healthBar(PlayerFrame) or PlayerFrameHealthBar
    if decorations and bar and decorations.GetFrameLevel and bar.GetFrameLevel then
        if self.active.player then
            if not self.playerArtLevel then self.playerArtLevel=decorations:GetFrameLevel() end
            decorations:SetFrameLevel(math.max(self.playerArtLevel,bar:GetFrameLevel()+1))
        elseif self.playerArtLevel then
            decorations:SetFrameLevel(self.playerArtLevel); self.playerArtLevel=nil
        end
        self:LayerPlayerLevel(decorations)
    end
    for loss in pairs(self.losses or {}) do self:PaintLoss(loss) end
    self:Refresh()
end
function Colors:Queue()
    if self.queued then return end
    self.queued=true; C_Timer.After(0, function() self.queued=false; self:Apply() end)
end
function Colors:Refresh()
    if not self.frame then return end
    local settings=self:Settings(); local all=true
    for _, entry in ipairs(groups) do
        local enabled=settings[entry[1]] == true
        self.buttons[entry[1]].label:SetText(entry[2] .. " class colors: " .. (enabled and "On" or "Off"))
        FT:SetSelected(self.buttons[entry[1]], enabled)
        all=all and enabled
    end
    self.all.label:SetText(all and "All unit frames: On" or "Enable all unit frames")
    FT:SetSelected(self.all, all)
    self.note:SetText(self.deferred and "Saved. Changes apply when you leave combat." or "Colors health bars by class. NPC, dead and offline colors stay native.\nBlizzard frames only; power-bar colors stay unchanged.")
end
function Colors:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsUnitColors", "Unitframe colors", 590, 450)
        FT:AppearanceBack(self.frame)
        local badge = FT:Label(self.frame, "WORK IN PROGRESS", 12, true)
        badge:SetPoint("BOTTOMLEFT",24,18); badge:SetTextColor(1,.72,.25)
        self.all=FT:AccentButton(self.frame, "", 542, 34, "classes"); self.all:SetPoint("TOPLEFT",24,-65)
        self.all:SetScript("OnClick",function()
            local s=self:Settings(); local all=true
            for _, entry in ipairs(groups) do all=all and s[entry[1]] == true end
            for _, entry in ipairs(groups) do s[entry[1]]=not all end
            self:Apply()
        end)
        self.buttons={}
        for i,entry in ipairs(groups) do
            local key=entry[1]
            local button=FT:QuietButton(self.frame,"",542,34,"character")
            button:SetPoint("TOPLEFT",24,-113-(i-1)*44)
            button:SetScript("OnClick",function() local s=self:Settings(); s[key]=not s[key]; self:Apply() end)
            self.buttons[key]=button
        end
        self.note=FT:Label(self.frame,"",13); self.note:SetPoint("BOTTOMLEFT",24,28); self.note:SetSize(542,60)
    end
    self:Apply(); self.frame:Show()
    if not self.warned then
        self.warned = true
        StaticPopupDialogs.FOREVERTOOLS_COLORS_WIP = {text="Unitframe colors is under development. Results may be unreliable on the beta client as its unit-frame APIs change. You can still adjust these settings.", button1="Continue", timeout=0, whileDead=true, hideOnEscape=true}
        StaticPopup_Show("FOREVERTOOLS_COLORS_WIP")
    end
end
FT:RegisterModule("UnitColors", Colors)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","GROUP_ROSTER_UPDATE","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_TARGET","UNIT_CONNECTION","UNIT_NAME_UPDATE","UNIT_HEALTH","UNIT_MAXHEALTH","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() if FT.dbReady then Colors:Queue() end end)
