local _,FT=...
local S=FT.modules.IconStyles
S.artwork={};S.bagFills={};S.targetRims={}
S.extraOptions={{"minimap","Minimap"},{"stances","Stance / totem bars"},{"micro","Micro menu"},{"bags","Bag menu"},{"player","Player frame"},{"target","Target frame"},{"tot","Target of target"},{"focus","Focus frame"},{"focustarget","Focus target"},{"xp","XP / reputation"}}
function S:TintArtwork(texture,key,secondary)
    if not texture or type(texture.GetVertexColor)~="function" or type(texture.SetVertexColor)~="function" then return end
    local record=self.artwork[texture]
    if not record then
        record={key=key,original={texture:GetVertexColor()},desaturated=texture.IsDesaturated and texture:IsDesaturated()}; self.artwork[texture]=record
        if hooksecurefunc then hooksecurefunc(texture,"SetVertexColor",function(_,r,g,b,a)
            if self.paintingArtwork then return end
            record.original={r,g,b,a or 1}; self:PaintArtwork(texture,record)
        end) end
    end
    if secondary then record.secondary=true end
    self:PaintArtwork(texture,record)
end
function S:BagBackdrop(texture)
    self:TintArtwork(texture,"bags")
    if self.artwork[texture] then self.artwork[texture].bagBackdrop=true end
end
function S:BagFill(button)
    local fill=self.bagFills[button]
    if not fill then
        fill=button:CreateTexture(nil,"BACKGROUND",nil,-7)
        fill:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
        fill:SetPoint("TOPLEFT",button,"TOPLEFT",2,-2);fill:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-2,2)
        self.bagFills[button]=fill
    end
    local s=self:Area("bags")
    fill:SetVertexColor(s.color[1],s.color[2],s.color[3],s.bags and .8 or 0)
    fill:SetShown(s.bags)
end
function S:TargetRim(frame,key)
    local content=frame and (frame.TargetFrameContent or (frame.TargetFrameContainer and frame.TargetFrameContainer.TargetFrameContent))
    local main=content and (content.TargetFrameContentMain or content.MainFrame)
    local bar=main and ((main.HealthBarsContainer and main.HealthBarsContainer.HealthBar) or main.HealthBar)
    if not bar then return end
    local rim=self.targetRims[bar]
    if not rim then
        rim=bar:CreateTexture(nil,"BACKGROUND",nil,-8)
        rim:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
        rim:SetPoint("TOPLEFT",bar,"TOPLEFT",-2,2);rim:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",2,-2)
        self.targetRims[bar]=rim
    end
    local s=self:Area(key)
    rim:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s[key] and s.borderOpacity or 0)
    rim:SetShown(s[key])
end
function S:PaintArtwork(texture,record)
    if self.paintingArtwork then return end
    self.paintingArtwork=true
    local s=self:Area(record.key)
    local unit=({target="target",tot="targettarget",focus="focus",focustarget="focustarget"})[record.key]
    local classification
    if unit and UnitClassification then
        local ok,value=pcall(UnitClassification,unit)
        if ok and type(value)=="string" then classification=value end
    end
    -- Preserve the special dragon/portrait artwork when its switch is off,
    -- while still darkening the ordinary frame pieces around an elite target.
    local artwork=texture.GetAtlas and texture:GetAtlas() or nil
    if type(artwork)~="string" then artwork=texture.GetTexture and texture:GetTexture() end
    local special=type(artwork)=="string" and (artwork:lower():find("elite",1,true) or artwork:lower():find("rare",1,true) or artwork:lower():find("boss",1,true))
    local allowed=not special or (not ((classification=="rare" or classification=="rareelite") and not s.rares)
        and not ((classification=="elite" or classification=="worldboss" or classification=="rareelite") and not s.elites))
    local active=s[record.key] and allowed
    if texture.SetDesaturated and (record.key=="micro" or record.key=="bags") then texture:SetDesaturated(active or record.desaturated or false) end
    if active then texture:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],(record.bagBackdrop or (record.secondary and (record.key=="bags" or s.hideSecondary))) and 0 or (record.original[4] or 1)*s.borderOpacity)
    else texture:SetVertexColor(unpack(record.original)) end
    self.paintingArtwork=false
end
function S:ArtworkFrame(frame,key,secondary)
    if not frame then return end
    -- Explicit decorative fields only. Never tint portraits, status bars,
    -- spell artwork, labels, selection/aggro flashes or resource fills.
    for _,field in ipairs({"FrameTexture","BorderArt","Border","TextureFrame","AlternatePowerFrameTexture","VehicleFrameTexture","BossPortraitFrameTexture"}) do
        self:TintArtwork(frame[field],key,secondary)
    end
    if frame.NineSlice then
        for _,field in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do self:TintArtwork(frame.NineSlice[field],key,secondary) end
    end
end
function S:ApplyArtwork()
    self:TintArtwork(MinimapCompassTexture,"minimap"); self:TintArtwork(MinimapCompassTextureUnderlay,"minimap"); self:TintArtwork(MinimapBorder,"minimap")
    if MinimapCluster then self:ArtworkFrame(MinimapCluster.BorderTop,"minimap") end
    self:ArtworkFrame(MicroMenu,"micro",true); self:ArtworkFrame(BagsBar,"bags",true); self:ArtworkFrame(MainMenuBarBackpackButton,"bags")
    -- The long bar behind the micro buttons is a region on MicroMenu in some
    -- client builds, rather than one of its named border fields.
    if MicroMenu then
        for _,field in ipairs({"Background","BackgroundTexture","Border","BorderTexture","Texture"}) do self:TintArtwork(MicroMenu[field],"micro",true) end
        if MicroMenu.GetRegions then
            local width=MicroMenu.GetWidth and MicroMenu:GetWidth() or 0
            for _,region in ipairs({MicroMenu:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType()=="Texture" and region.GetWidth
                    and width>0 and region:GetWidth()>=width*.6 then
                    self:TintArtwork(region,"micro",true)
                end
            end
        end
    end
    local microNames=MICRO_BUTTONS or {"CharacterMicroButton","PlayerSpellsMicroButton","ProfessionMicroButton","SpellbookMicroButton","TalentMicroButton","AchievementMicroButton","QuestLogMicroButton","GuildMicroButton","LFDMicroButton","CollectionsMicroButton","EJMicroButton","MainMenuMicroButton","HelpMicroButton"}
    local microButtons={}
    for _,name in ipairs(microNames) do local button=type(name)=="string" and _G[name] or name; if button then microButtons[button]=true end end
    if MicroMenu and MicroMenu.GetChildren then for _,button in ipairs({MicroMenu:GetChildren()}) do microButtons[button]=true end end
    for button in pairs(microButtons) do
        if button then self:ArtworkFrame(button,"micro"); self:TintArtwork(button.Background,"micro"); self:TintArtwork(button.PushedBackground,"micro")
            if button.GetRegions then for _,region in ipairs({button:GetRegions()}) do
                local atlas=region.GetAtlas and region:GetAtlas()
                if type(atlas)=="string" and (atlas:lower():find("buttonbg",1,true) or atlas:lower():find("iconframe",1,true)) then self:TintArtwork(region,"micro") end
            end end
        end
    end
    if BagsBar and BagsBar.GetRegions then
        local width=BagsBar.GetWidth and BagsBar:GetWidth() or 0
        for _,region in ipairs({BagsBar:GetRegions()}) do
            if region.GetObjectType and region:GetObjectType()=="Texture" and region.GetWidth
                and width>0 and region:GetWidth()>=width*.6 then self:TintArtwork(region,"bags",true) end
        end
    end
    local bagButtons={}
    for _,name in ipairs({"MainMenuBarBackpackButton","KeyRingButton","CharacterReagentBag0Slot","ReagentBagSlot"}) do
        if _G[name] then bagButtons[_G[name]]=true end
    end
    for i=0,5 do local button=_G["CharacterBag"..i.."Slot"]; if button then bagButtons[button]=true end end
    for button in pairs(bagButtons) do
        if button then
            self:ArtworkFrame(button,"bags")
            if button.GetNormalTexture then self:TintArtwork(button:GetNormalTexture(),"bags") end
            for _,field in ipairs({"Background","BackgroundTexture","SlotBackground","SlotBackgroundTexture"}) do self:BagBackdrop(button[field]) end
            for _,field in ipairs({"BorderTexture","SlotBorder","IconBorder"}) do self:TintArtwork(button[field],"bags") end
            if button.GetRegions then for _,region in ipairs({button:GetRegions()}) do
                local atlas=region.GetAtlas and region:GetAtlas()
                if type(atlas)=="string" then
                    local lower=atlas:lower()
                    if (lower:find("bag",1,true) or lower:find("keyring",1,true))
                        and (lower:find("border",1,true) or lower:find("frame",1,true) or lower:find("background",1,true)) then
                        if lower:find("background",1,true) then self:BagBackdrop(region) else self:TintArtwork(region,"bags") end
                    end
                end
            end end
            self:BagFill(button)
        end
    end
    for _,entry in ipairs({{"PlayerFrame","player"},{"TargetFrame","target"},{"TargetFrameToT","tot"},{"FocusFrame","focus"},{"FocusFrameToT","focustarget"}}) do
        local frame=_G[entry[1]]; local key=entry[2]
        self:TintArtwork(_G[entry[1].."Texture"],key); self:TintArtwork(_G[entry[1].."TextureFrameTexture"],key)
        if frame then
            self:ArtworkFrame(frame,key); self:ArtworkFrame(frame.PlayerFrameContainer,key); self:ArtworkFrame(frame.TargetFrameContainer,key); self:ArtworkFrame(frame.TextureFrame,key)
            if key=="target" or key=="focus" then self:TargetRim(frame,key) end
            local content=frame.PlayerFrameContent or frame.TargetFrameContent
            local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
            if main then self:TintArtwork(main.LevelBackgroundCircle,key) end
        end
    end
    local function xpDecorations(frame,depth)
        if not frame then return end
        for _,field in ipairs({"BarFrameTexture","Tick","TickTexture","Divider","DividerTexture","Separator","SeparatorTexture"}) do self:TintArtwork(frame[field],"xp") end
        for i=1,40 do self:TintArtwork(frame["XpDiv"..i],"xp");self:TintArtwork(frame["Divider"..i],"xp") end
        if frame.GetRegions then
            for _,region in ipairs({frame:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType()=="Texture" then
                    local name=region.GetName and region:GetName() or ""
                    local art=region.GetAtlas and region:GetAtlas() or region.GetTexture and region:GetTexture() or ""
                    local id=(type(name)=="string" and name or "").." "..(type(art)=="string" and art or "")
                    id=id:lower()
                    if id:find("divider",1,true) or id:find("separator",1,true) or id:find("xpdiv",1,true) or id:find("tick",1,true) then self:TintArtwork(region,"xp") end
                end
            end
        end
        if depth>0 and frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do xpDecorations(child,depth-1) end end
    end
    for _,name in ipairs({"MainStatusTrackingBarContainer","SecondaryStatusTrackingBarContainer","StatusTrackingBarManager","MainMenuExpBar"}) do
        xpDecorations(_G[name],2)
    end
    for texture,record in pairs(self.artwork) do self:PaintArtwork(texture,record) end
end
local apply=S.Apply
function S:Apply()
    apply(self)
    if FT.dbReady and not InCombatLockdown() then self:ApplyArtwork() end
end

local artworkEvents=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_TARGET","UNIT_CLASSIFICATION_CHANGED","UPDATE_EXPANSION_LEVEL","UPDATE_FACTION"}) do artworkEvents:RegisterEvent(event) end
artworkEvents:SetScript("OnEvent",function() if FT.dbReady then S:Queue() end end)
