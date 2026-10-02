local _, FT = ...
local Colors = { tracked={}, hooks={}, active={} }
local groups = {{"player","Player"}, {"target","Target"}, {"focus","Focus"}}
function Colors:Settings()
    if type(FT.db.unitColors) ~= "table" then FT.db.unitColors = {} end
    for _,entry in ipairs(groups) do
        if type(FT.db.unitColors[entry[1]])~="boolean" then FT.db.unitColors[entry[1]]=false end
    end
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
local nativeAtlas = {player = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health"}
function Colors:Paint(bar, force)
    local info = self.tracked[bar]
    if not info or self.painting then return end
    local unit = info.owner and (info.owner.displayedUnit or info.owner.unit) or info.unit
    local enabled = self.active[info.group] == true
    -- Nothing of ours on this bar and nothing to add: leave it alone.
    if not enabled and not info.colored and not info.art then return end
    local color
    if enabled and unit then
        -- The game can hide who a unit is (target of target in combat, for
        -- example): then leave the bar exactly as it is until it can tell.
        local secret = issecretvalue
        local isPlayer, connected, dead = UnitIsPlayer(unit), UnitIsConnected(unit), UnitIsDeadOrGhost(unit)
        if secret and (secret(isPlayer) or secret(connected) or secret(dead)) then return end
        if isPlayer and connected and not dead then
            local _, class = UnitClass(unit)
            if secret and secret(class) then return end
            if type(class) == "string" then
                color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS or {})[class]
            end
        end
    end
    -- Same color as last time and Blizzard hasn't changed the bar since
    -- (it calls back when it does): nothing to redo.
    if not force and not info.art and info.lastColor==color and info.colored==(color~=nil) then return end
    info.lastColor=color
    self.painting = true
    -- Keep Blizzard's own health artwork (its shading, edges and masks) and
    -- only recolor it: the green fill is turned grey, then tinted in the class
    -- color. Incoming heals, absorbs and the frame edge stay exactly as in
    -- the default look.
    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if info.art then self:RestoreArt(info) end
    -- Blizzard ships a white "-Status" copy of each health fill (same shape,
    -- used for heal prediction and colored power bars). Tinting that one
    -- gives the true class color, as bright as the party and raid frames.
    -- Greying the green art (the fallback) comes out darker.
    local status
    if color and texture and texture.GetAtlas and texture.SetAtlas then
        local atlas = texture:GetAtlas()
        if issecretvalue and issecretvalue(atlas) then atlas = nil end
        -- Art set in the frame's XML can report no atlas name (the player
        -- frame does); use the name Blizzard gives that bar.
        if type(atlas) ~= "string" or atlas == "" then atlas = info.native or nativeAtlas[info.group] end
        if type(atlas) == "string" then
            if atlas:find("%-Status$") then status = true
            elseif C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas .. "-Status") then
                info.native = atlas; texture:SetAtlas(atlas .. "-Status"); status = true
            end
        end
    elseif not color and info.native and texture and texture.SetAtlas then
        texture:SetAtlas(info.native); info.native = nil
    end
    if texture and texture.SetDesaturated then texture:SetDesaturated(color ~= nil and not status) end
    if color then bar:SetStatusBarColor(color.r, color.g, color.b)
    elseif info.colored and info.original then bar:SetStatusBarColor(unpack(info.original)) end
    for _,rim in ipairs(info.rim or {}) do rim:Hide() end
    info.colored = color ~= nil
    self.painting = false
end
-- Undo the plain fill used by older versions (only matters within a session
-- that started before an update; kept so nothing is left behind).
function Colors:RestoreArt(info)
    local art=info.art
    if info.shapeAttached and art.texture.RemoveMaskTexture then art.texture:RemoveMaskTexture(info.shapeMask); info.shapeAttached=nil end
    if info.addedMask and art.texture.RemoveMaskTexture then art.texture:RemoveMaskTexture(info.addedMask); info.addedMask=nil end
    if art.atlas and art.texture.SetAtlas then art.texture:SetAtlas(art.atlas)
    else art.texture:SetTexture(art.file); if art.coords and art.texture.SetTexCoord then art.texture:SetTexCoord(unpack(art.coords)) end end
    if art.layer and art.texture.SetDrawLayer then art.texture:SetDrawLayer(unpack(art.layer)) end
    info.art=nil
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
                self:Paint(bar,true)
            end)
            -- Blizzard can swap the bar's artwork back to its green fill (for
            -- example on a target in combat). Our color on that green art
            -- turns dark olive, so take the new art as the original and
            -- paint again right away.
            local function artChanged()
                if self.painting then return end
                info.art = nil
                self:Paint(bar,true)
            end
            if bar.SetStatusBarTexture then hooksecurefunc(bar, "SetStatusBarTexture", artChanged) end
            local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
            if fill and fill.SetAtlas then hooksecurefunc(fill, "SetAtlas", artChanged) end
        end
    end
    info.unit, info.group, info.owner = unit, group, owner
    self:Paint(bar,true)
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
    -- Compact party and raid frames use Blizzard's own class-color option.
end
function Colors:LayerPlayerLevel(decorations,restoreOnly)
    local content=PlayerFrame and PlayerFrame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    if not main then return end
    if self.active.player and not restoreOnly then
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
    -- Party colors belong to Blizzard Edit Mode. Restore any bars this addon
    -- colored on older profiles, then leave their colors to the client.
    self.active.party=false; self.active.raid=false
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
        -- Leave compact raid frames untouched.
    end
    -- Leave compact raid frames untouched.
    -- The player, target and focus bars are recolored by Blizzard after several
    -- unit events. Queue one pass after their native updater has finished.
    if not self.hooks.unitFrame and type(UnitFrameHealthBar_Update) == "function" and hooksecurefunc then
        self.hooks.unitFrame = true
        hooksecurefunc("UnitFrameHealthBar_Update", function(frame, unit)
            local bar = healthBar(frame) or (frame and frame.SetStatusBarColor and frame)
            local resolved = unit or (frame and (frame.displayedUnit or frame.unit))
            local group=groupFor(resolved)
            if not self:Busy() then return end
            if bar and group and group~="party" and group~="raid" then
                local info=self.tracked[bar]
                -- Health updates many times a second in combat: only set up
                -- bars we have not seen, or that now show another unit.
                if not info or info.unit~=resolved or info.group~=group then self:Track(bar, resolved, group, frame) end
            end
            self:QueuePaint(resolved)
        end)
    end
    for bar in pairs(self.tracked) do self:Paint(bar,true) end
    -- Draw layers only order textures within one frame level. The portrait
    -- container is a sibling below the health-bar content on this client;
    -- move its native decorations above the fill instead of adding new art.
    -- Older versions lifted the player frame's artwork above the health bar
    -- (needed for the old plain fill). That put the frame's own shading over
    -- the bar and made the player bar darker than the target's, so the
    -- native layering is restored and left alone now.
    local decorations=PlayerFrame and PlayerFrame.PlayerFrameContainer
    if decorations and self.playerArtLevel then decorations:SetFrameLevel(self.playerArtLevel); self.playerArtLevel=nil end
    if decorations then self:LayerPlayerLevel(decorations,true) end
    for loss in pairs(self.losses or {}) do self:PaintLoss(loss) end
    self:Refresh()
end
-- Health changes only need the known bars repainted, not a full pass.
-- True while any unit frame is class-colored, or still carries our color.
function Colors:Busy()
    for _,on in pairs(self.active) do if on then return true end end
    for _,info in pairs(self.tracked) do if info.colored or info.art then return true end end
    return false
end
-- Repaint once on the next frame. With a unit, only that unit's bars (health
-- ticks many times a second in combat); without one, every bar.
function Colors:QueuePaint(unit)
    if self.queued or not self:Busy() then return end
    if unit and self.paintUnits~="all" then
        self.paintUnits=self.paintUnits or {}; self.paintUnits[unit]=true
    else self.paintUnits="all" end
    if self.paintQueued then return end
    self.paintQueued=true
    C_Timer.After(0,function()
        self.paintQueued=false
        local units=self.paintUnits; self.paintUnits=nil
        -- Repainting known bars is allowed in combat (only colors and art of
        -- the bar itself change), so a target never shows the wrong color.
        if not FT.dbReady then return end
        for bar,info in pairs(self.tracked) do
            if units=="all" or (units and units[info.unit]) then self:Paint(bar) end
        end
        if units=="all" then for loss in pairs(self.losses or {}) do self:PaintLoss(loss) end end
    end)
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
    self.note:SetText(self.deferred and "Saved. Changes apply when you leave combat." or "")
    if self.druidMana then
        local on=settings.druidMana==true
        self.druidMana.label:SetText("Mana bar while shapeshifted: "..(on and "On" or "Off")); FT:SetSelected(self.druidMana,on)
    end
    self:RefreshDispel()
end
-- Dispel glow lives here with the other unit-frame visuals (DispelGlow.lua).
function Colors:BuildDispel()
    local glow=FT.modules.DispelGlow; if not glow then return end
    local frame=self.frame
    local head=FT:Label(frame,"Dispel glow",16,true); head:SetPoint("TOPLEFT",24,-296); FT:SectionHeading(head,"Spell_Holy_DispelMagic",300)
    self.dispelToggle=FT:AccentButton(frame,"",542,34,"buffs"); self.dispelToggle:SetPoint("TOPLEFT",24,-326)
    self.dispelToggle:SetScript("OnClick",function() local s=glow:Settings(); s.enabled=not s.enabled; glow:Apply(); self:RefreshDispel() end)
    FT:Tooltip(self.dispelToggle,"Dispel glow","A soft glow around a unit frame when it has a debuff you can dispel, in that debuff type's color. It uses the same glow art the game lights up for aggro. Choose the frames and colors below.")
    self.dispelFrames={}
    for i,key in ipairs(glow.frameKeys) do
        local b=FT:QuietButton(frame,glow.labels[key],102,32)
        b:SetPoint("TOPLEFT",24+(i-1)*110,-368)
        b:SetScript("OnClick",function() local s=glow:Settings(); s[key]=not s[key]; glow:Apply(); self:RefreshDispel() end)
        FT:Tooltip(b,glow.labels[key].." frames",key=="raid" and "Raid frames. Blizzard has its own dispel highlight for these in Edit Mode; use one or the other."
            or key=="party" and "Show the glow on your party's frames, both the normal ones and the raid-style ones."
            or "Show the glow on the "..glow.labels[key]:lower().." frame.")
        self.dispelFrames[key]=b
    end
    local names={soft="Soft",medium="Medium",strong="Strong"}
    self.dispelStrength=FT:Dropdown(frame,266,function()
        local icon="Interface\\Icons\\"..FT.icons.skins
        return {{value="soft",label="Glow: Soft",icon=icon},{value="medium",label="Glow: Medium",icon=icon},{value="strong",label="Glow: Strong",icon=icon}}
    end,function(value) glow:Settings().strength=value; glow:Apply(); self:RefreshDispel() end,"skins")
    self.dispelStrength:SetPoint("TOPLEFT",24,-408); self.dispelStrength:SetHeight(32)
    self.dispelStrength.names=names
    FT:Tooltip(self.dispelStrength,"Glow strength","How bright the outline is.")
    self.dispelPulse=FT:QuietButton(frame,"",266,32,"reset"); self.dispelPulse:SetPoint("TOPLEFT",300,-408)
    self.dispelPulse:SetScript("OnClick",function() local s=glow:Settings(); s.pulse=not s.pulse; glow:Apply(); self:RefreshDispel() end)
    FT:Tooltip(self.dispelPulse,"Gentle pulse","Let the glow slowly fade in and out so it catches the eye.")
    -- One color per debuff type. Picking a color shows it on your frames for a moment.
    self.dispelColors={}
    for i,name in ipairs(glow.typeNames) do
        local b=FT:QuietButton(frame,name,131,32); b:SetPoint("TOPLEFT",24+(i-1)*137,-448)
        b.label:ClearAllPoints(); b.label:SetPoint("LEFT",12,0)
        b.swatch=b:CreateTexture(nil,"ARTWORK"); b.swatch:SetTexture("Interface\\Buttons\\WHITE8X8"); b.swatch:SetSize(18,18); b.swatch:SetPoint("RIGHT",-10,0)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetScript("OnClick",function(_,mouse)
            local function set(r,g,bl) glow:SetColor(name,r,g,bl); glow:Preview(name); self:RefreshDispel() end
            if mouse=="RightButton" then local d=glow.defaultColors[name]; set(d[1],d[2],d[3]); return end
            if not ColorPickerFrame then return end
            local c=glow:Settings().colors[name]; local old={c[1],c[2],c[3]}
            glow:Preview(name,8)
            -- The frames follow at most 20 times a second while you drag the color wheel.
            local function pick() local r,g,bl=ColorPickerFrame:GetColorRGB(); glow:SetColor(name,r,g,bl); self:RefreshDispel(); FT:Coalesce("dispelColor",function() glow:Preview(name,6) end,.05) end
            local function cancel() set(old[1],old[2],old[3]) end
            if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker(); ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=pick,cancelFunc=cancel})
            else ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=pick; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
        end)
        FT:Tooltip(b,name.." glow color","The glow color for "..name:lower().." debuffs. Click to change it: the glow shows on your frames for a few seconds so you can judge it. Right-click puts the default color back.")
        self.dispelColors[name]=b
    end
end
function Colors:RefreshDispel()
    local glow=FT.modules.DispelGlow
    if not glow or not self.dispelToggle then return end
    local s=glow:Settings()
    self.dispelToggle.label:SetText("Dispel glow: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.dispelToggle,s.enabled)
    for key,b in pairs(self.dispelFrames) do
        FT:SetSelected(b,s[key]); b:SetAlpha(s.enabled and 1 or .5)
    end
    self.dispelStrength.value=s.strength
    self.dispelStrength.label:SetText("Glow: "..(self.dispelStrength.names[s.strength] or "Medium"))
    self.dispelPulse.label:SetText("Gentle pulse: "..(s.pulse and "On" or "Off")); FT:SetSelected(self.dispelPulse,s.pulse)
    for name,b in pairs(self.dispelColors or {}) do
        local c=s.colors[name]; b.swatch:SetVertexColor(c[1],c[2],c[3]); b:SetAlpha(s.enabled and 1 or .5)
    end
end
function Colors:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsUnitColors", "Unitframe colors", 590, 594)
        FT:AppearanceBack(self.frame)
        FT:PageInfo(self.frame,"Unitframe colors","Class-colored health bars for the player, target and focus frames. NPCs, dead and offline units keep Blizzard's colors. Party and raid class colors are a Blizzard setting (Edit Mode).\n\nDispel glow: A soft glow in the debuff's color (magic, curse, disease or poison; each color is yours to choose) appears around a frame while that unit has a debuff you can remove. Only dispels you have learned count, so nothing lights up before you train them. No icons are added.\n\nDruid mana bar: In bear, cat and other forms that hide your mana, a third bar under your rage or energy shows it, using the game's own three-bar player frame. Hover it for the numbers (or always, with the game's status text option). Only druids see it.")
        self.all=FT:AccentButton(self.frame, "", 542, 34, "classes"); self.all:SetPoint("TOPLEFT",24,-62)
        self.all:SetScript("OnClick",function()
            local s=self:Settings(); local all=true
            for _, entry in ipairs(groups) do all=all and s[entry[1]] == true end
            for _, entry in ipairs(groups) do s[entry[1]]=not all end
            self:Apply()
        end)
        self.buttons={}
        for i,entry in ipairs(groups) do
            local key=entry[1]
            local button=FT:QuietButton(self.frame,"",542,32,"character")
            button:SetPoint("TOPLEFT",24,-104-(i-1)*40)
            button:SetScript("OnClick",function() local s=self:Settings(); s[key]=not s[key]; self:Apply() end)
            self.buttons[key]=button
        end
        local partyInfo=FT:QuietButton(self.frame,"Party colors: use Blizzard Edit Mode",542,32,"party")
        partyInfo:SetPoint("TOPLEFT",24,-104-#groups*40)
        FT:Tooltip(partyInfo,"Party class colors","Party and raid class colors are a Blizzard setting. Click to open Edit Mode, select the party frame and turn on class colors.")
        partyInfo:SetScript("OnClick",function()
            if InCombatLockdown() then return end
            local manager=_G.EditModeManagerFrame
            if manager and manager.Show then
                if FT.home then FT.home:Hide() end
                for _,module in pairs(FT.modules) do if module.frame then module.frame:Hide() end end
                manager:Show()
            end
        end)
        self.note=FT:Label(self.frame,"",13); self.note:SetPoint("TOPLEFT",24,-270); self.note:SetSize(542,20)
        self.note:SetJustifyV("TOP")
        self:BuildDispel()
        local head=FT:Label(self.frame,"Druid mana bar",16,true); head:SetPoint("TOPLEFT",24,-496); FT:SectionHeading(head,"Ability_Racial_BearForm",300)
        self.druidMana=FT:QuietButton(self.frame,"",542,32,"Ability_Racial_BearForm"); self.druidMana:SetPoint("TOPLEFT",24,-526)
        self.druidMana:SetScript("OnClick",function()
            local s=self:Settings(); s.druidMana=not (s.druidMana==true)
            if FT.modules.DruidMana then FT.modules.DruidMana:Apply() end
            self:Refresh()
        end)
        FT:Tooltip(self.druidMana,"Druid mana bar","Show your mana as a third bar on the player frame while you are in bear, cat or another form that hides it. It uses the game's own three-bar frame art. Hover the bar for the numbers. Does nothing on other classes.")
    end
    self:Apply(); self.frame:Show()
end
FT:RegisterModule("UnitColors", Colors)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_TARGET","UNIT_CONNECTION","UNIT_NAME_UPDATE","UNIT_HEALTH","UNIT_MAXHEALTH","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
-- Only the frames this module colors matter; other units' events are ignored.
local ours={player=true,target=true,focus=true,targettarget=true,focustarget=true}
local unitEvents={UNIT_CONNECTION=true,UNIT_NAME_UPDATE=true,UNIT_HEALTH=true,UNIT_MAXHEALTH=true}
events:SetScript("OnEvent",function(_,event,unit)
    if not FT.dbReady then return end
    if event=="UNIT_TARGET" then
        if unit=="target" or unit=="focus" then Colors:Queue() end
    elseif unitEvents[event] then
        if ours[unit] then Colors:QueuePaint(unit) end
    elseif event=="PLAYER_REGEN_ENABLED" then
        if Colors.deferred then Colors:Queue() else Colors:QueuePaint() end
    else Colors:Queue() end
end)
