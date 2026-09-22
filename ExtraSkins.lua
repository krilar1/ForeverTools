local _,FT=...
local S=FT.modules.IconStyles
S.artwork={}
S.extraOptions={{"minimap","Minimap"},{"micro","Micro menu"},{"bags","Bag menu"},{"player","Player frame"},{"target","Target frame"},{"tot","Target of target"},{"focus","Focus frame"},{"focustarget","Focus target"},{"xp","XP / reputation"}}
function S:TintArtwork(texture,key)
    if not texture or type(texture.GetVertexColor)~="function" or type(texture.SetVertexColor)~="function" then return end
    local record=self.artwork[texture]
    if not record then
        record={key=key,original={texture:GetVertexColor()}}; self.artwork[texture]=record
        if hooksecurefunc then hooksecurefunc(texture,"SetVertexColor",function(_,r,g,b,a)
            if self.paintingArtwork then return end
            record.original={r,g,b,a or 1}; self:PaintArtwork(texture,record)
        end) end
    end
    self:PaintArtwork(texture,record)
end
function S:PaintArtwork(texture,record)
    if self.paintingArtwork then return end
    self.paintingArtwork=true
    local s=self:Area(record.key)
    local unit=({target="target",tot="targettarget",focus="focus",focustarget="focustarget"})[record.key]
    local classification=unit and UnitClassification and UnitClassification(unit)
    local allowed=not ((classification=="rare" or classification=="rareelite") and not s.rares)
        and not ((classification=="elite" or classification=="worldboss" or classification=="rareelite") and not s.elites)
    if s[record.key] and allowed then texture:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],(record.original[4] or 1)*s.borderOpacity)
    else texture:SetVertexColor(unpack(record.original)) end
    self.paintingArtwork=false
end
function S:ArtworkFrame(frame,key)
    if not frame then return end
    -- Explicit decorative fields only. Never tint portraits, status bars,
    -- spell artwork, labels, selection/aggro flashes or resource fills.
    for _,field in ipairs({"FrameTexture","BorderArt","Border","TextureFrame","AlternatePowerFrameTexture","VehicleFrameTexture","BossPortraitFrameTexture"}) do
        self:TintArtwork(frame[field],key)
    end
    if frame.NineSlice then
        for _,field in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do self:TintArtwork(frame.NineSlice[field],key) end
    end
end
function S:ApplyArtwork()
    self:TintArtwork(MinimapCompassTexture,"minimap"); self:TintArtwork(MinimapCompassTextureUnderlay,"minimap"); self:TintArtwork(MinimapBorder,"minimap")
    if MinimapCluster then self:ArtworkFrame(MinimapCluster.BorderTop,"minimap") end
    self:ArtworkFrame(MicroMenu,"micro"); self:ArtworkFrame(BagsBar,"bags"); self:ArtworkFrame(MainMenuBarBackpackButton,"bags")
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
    if MainMenuBarBackpackButton and MainMenuBarBackpackButton.GetNormalTexture then self:TintArtwork(MainMenuBarBackpackButton:GetNormalTexture(),"bags") end
    for i=0,5 do local button=_G["CharacterBag"..i.."Slot"]; if button then self:ArtworkFrame(button,"bags"); if button.GetNormalTexture then self:TintArtwork(button:GetNormalTexture(),"bags") end end end
    for _,entry in ipairs({{"PlayerFrame","player"},{"TargetFrame","target"},{"TargetFrameToT","tot"},{"FocusFrame","focus"},{"FocusFrameToT","focustarget"}}) do
        local frame=_G[entry[1]]; local key=entry[2]
        self:TintArtwork(_G[entry[1].."Texture"],key); self:TintArtwork(_G[entry[1].."TextureFrameTexture"],key)
        if frame then
            self:ArtworkFrame(frame,key); self:ArtworkFrame(frame.PlayerFrameContainer,key); self:ArtworkFrame(frame.TargetFrameContainer,key); self:ArtworkFrame(frame.TextureFrame,key)
            local content=frame.PlayerFrameContent or frame.TargetFrameContent
            local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
            if main then self:TintArtwork(main.LevelBackgroundCircle,key) end
        end
    end
    for _,name in ipairs({"MainStatusTrackingBarContainer","SecondaryStatusTrackingBarContainer"}) do
        local container=_G[name]; if container then self:TintArtwork(container.BarFrameTexture,"xp") end
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
