local _,FT=...
local S=FT.modules.IconStyles
S.artwork={};S.bagFills={};S.targetRims={};S.bagSlots={}
S.extraOptions={{"minimap","Minimap"},{"stances","Stance / totem bars"},{"micro","Micro menu"},{"bags","Bag bar"},{"bagWindows","Bag menu"},{"gryphons","Gryphon frame"},{"player","Player frame"},{"target","Target frame"},{"tot","Target of target"},{"focus","Focus frame"},{"focustarget","Focus target"},{"xp","XP / reputation"}}
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
    if not record.atlasHooked and hooksecurefunc and texture.SetAtlas then
        record.atlasHooked=true
        hooksecurefunc(texture,"SetAtlas",function() if not self.paintingArtwork then self:PaintArtwork(texture,record) end end)
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
        local anchor=button.icon or button.Icon or button
        if not anchor.GetTexture then anchor=button end
        fill:SetPoint("TOPLEFT",anchor,"TOPLEFT");fill:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT")
        self.bagFills[button]=fill
    end
    local s=self:Area("bags")
    fill:SetVertexColor(s.color[1],s.color[2],s.color[3],s.bags and s.opacity or 0)
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
        -- A plain rectangle: the rounded panel texture stretched to bar size
        -- turned into a long taper wherever missing health exposed it.
        rim:SetTexture("Interface\\Buttons\\WHITE8x8")
        rim:SetPoint("TOPLEFT",bar,"TOPLEFT",-2,2)
        self.targetRims[bar]=rim
    end
    -- The bar runs underneath the portrait ring, but only its fill is masked to
    -- that cutout. Stop the dark backing just before the ring so it never covers
    -- the red threat ring (TargetFrameContainer.Flash) or the portrait edge.
    local container=frame.TargetFrameContainer
    local portrait=container and container.Portrait
    local right=2
    local portraitLeft=portrait and portrait:IsShown() and portrait:GetLeft()
    local barRight=bar:GetRight()
    if portraitLeft and barRight and (not issecretvalue or not (issecretvalue(portraitLeft) or issecretvalue(barRight))) then
        right=math.max(-12,math.min(2,math.floor(portraitLeft-barRight-4)))
    end
    if rim.rightOffset~=right then
        rim.rightOffset=right
        rim:ClearAllPoints()
        rim:SetPoint("TOPLEFT",bar,"TOPLEFT",-2,2);rim:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",right,-2)
    end
    -- Where the backing stops short of the ring, an empty bar (a dead or hurt
    -- unit) would show the world through a thin gap. Fill that strip with the
    -- same color, clipped by Blizzard's own health-bar mask so it follows the
    -- portrait curve exactly like the health fill and never covers the ring.
    local mask=main.HealthBarsContainer and main.HealthBarsContainer.HealthBarMask or main.HealthBarMask
    if not rim.filler and mask and rim.AddMaskTexture then
        local filler=bar:CreateTexture(nil,"BACKGROUND",nil,-8)
        filler:SetTexture("Interface\\Buttons\\WHITE8x8")
        filler:AddMaskTexture(mask)
        rim.filler=filler
    end
    local filler=rim.filler
    if filler and filler.fillerOffset~=right then
        filler.fillerOffset=right
        filler:ClearAllPoints()
        -- Tuck 2 px under the backing so pixel rounding can never leave a seam.
        filler:SetPoint("TOPLEFT",bar,"TOPRIGHT",math.min(right,0)-2,0)
        filler:SetPoint("BOTTOMRIGHT",bar,"BOTTOMRIGHT",0,0)
    end
    local s=self:Area(key)
    rim:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s[key] and s.borderOpacity or 0)
    rim:SetShown(s[key])
    if filler then
        filler:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s[key] and s.borderOpacity or 0)
        filler:SetShown(s[key] and right<0)
    end
end
function S:PaintArtwork(texture,record)
    if self.paintingArtwork then return end
    self.paintingArtwork=true
    local s=self:Area(record.key)
    local unit=({target="target",tot="targettarget",focus="focus",focustarget="focustarget"})[record.key]
    local classification
    if unit and UnitClassification then
        local ok,value=pcall(UnitClassification,unit)
        if ok and (not issecretvalue or not issecretvalue(value)) and type(value)=="string" then classification=value end
    end
    -- Preserve the special dragon/portrait artwork when its switch is off,
    -- while still darkening the ordinary frame pieces around an elite target.
    local artwork=texture.GetAtlas and texture:GetAtlas() or nil
    if issecretvalue and issecretvalue(artwork) then artwork=nil end
    if type(artwork)~="string" then artwork=texture.GetTexture and texture:GetTexture() end
    if issecretvalue and issecretvalue(artwork) then artwork=nil end
    local artName=type(artwork)=="string" and artwork:lower() or ""
    local rare=artName:find("rare",1,true)
    local elite=artName:find("elite",1,true) or artName:find("boss",1,true)
    local special=rare or elite
    local allowed=not special or (not ((rare or classification=="rare" or classification=="rareelite") and not s.rares)
        and not ((elite or classification=="elite" or classification=="worldboss" or classification=="rareelite") and not s.elites))
    local active=s[record.key] and allowed
    if texture.SetDesaturated and (record.key=="micro" or record.key=="bags" or record.key=="bagWindows" or record.key=="gryphons") then texture:SetDesaturated(active or record.desaturated or false) end
    if active and (record.bagSlotBorder or (record.hideDecoration and s.hideArt)) then
        texture:SetVertexColor(1,1,1,0)
    elseif record.background then
        if active then
            texture:SetVertexColor(s.color[1],s.color[2],s.color[3],s.hideArt and 0 or s.opacity)
        else texture:SetVertexColor(unpack(record.original)) end
        if record.replacement then
            record.replacement:SetVertexColor(s.color[1],s.color[2],s.color[3],s.opacity)
            record.replacement:SetShown(active and s.hideArt)
        end
    elseif active and special and s.preset=="dark" then
        -- Keep the native dragon/star silhouette legible: warm dark bronze for
        -- elites and cool dark silver for rares, rather than a black silhouette.
        local r,g,b=.23,.18,.10
        if rare or classification=="rare" or classification=="rareelite" then r,g,b=.23,.26,.30 end
        texture:SetVertexColor(r,g,b,(record.original[4] or 1)*s.borderOpacity)
    elseif active then texture:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],((record.bagBackdrop and s.hideArt) or (record.secondary and ((record.key=="bags" and s.hideArt) or (record.key=="micro" and s.hideSecondary) or (record.key=="gryphons" and s.hideArt)))) and 0 or (record.original[4] or 1)*s.borderOpacity)
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
        for _,field in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do self:TintArtwork(frame.NineSlice[field],key,secondary) end
    end
end
-- Explicit bag window decorations; item icons, quality borders, locks, counts,
-- search controls and buttons retain their native behavior and colors.
function S:BagWindow(frame)
    if not frame then return end
    self:ArtworkFrame(frame,"bagWindows")
    for _,field in ipairs({"PortraitContainer","Inset","InsetFrame","MoneyFrame"}) do
        local part=frame[field]
        self:ArtworkFrame(part,"bagWindows")
        if part then
            self:TintArtwork(part.PortraitFrame,"bagWindows")
            self:TintArtwork(part.Border,"bagWindows")
            if part.Border then for _,edge in ipairs({"Left","Middle","Right"}) do self:TintArtwork(part.Border[edge],"bagWindows") end end
        end
    end
    local function background(texture)
        if not texture or not texture.GetVertexColor or not texture.GetParent then return end
        self:TintArtwork(texture,"bagWindows")
        local record=self.artwork[texture]
        record.background=true
        if not record.replacement then
            local parent=texture:GetParent()
            if parent and parent.CreateTexture then
                local fill=parent:CreateTexture(nil,"BACKGROUND",nil,-6)
                fill:SetTexture("Interface\\Buttons\\WHITE8x8");fill:SetAllPoints(texture)
                record.replacement=fill
            end
        end
        self:PaintArtwork(texture,record)
    end
    for _,part in pairs({frame=frame,inset=frame.Inset,insetFrame=frame.InsetFrame}) do
        for _,field in ipairs({"Bg","Background","TitleBg","InsetBg","TopTileStreaks"}) do
            local art=part[field]
            if art and art.GetVertexColor then background(art)
            elseif art then
                -- Forever's FlatPanelBackgroundTemplate is a frame with four
                -- background textures rather than a single Bg texture.
                for _,piece in ipairs({"BottomLeft","BottomRight","BottomEdge","TopSection"}) do background(art[piece]) end
            end
        end
    end
    if frame.EnumerateValidItems then
        for _,button in frame:EnumerateValidItems() do self:BagSlot(button,"bagWindows") end
    elseif frame.GetChildren then
        for _,button in ipairs({frame:GetChildren()}) do if button.GetBagID then self:BagSlot(button,"bagWindows") end end
    end
    if not self.bagWindowHooks then self.bagWindowHooks={} end
    if frame.HookScript and not self.bagWindowHooks[frame] then
        self.bagWindowHooks[frame]=true
        frame:HookScript("OnShow",function() if FT.dbReady then self:Queue() end end)
        if hooksecurefunc and frame.UpdateItems then hooksecurefunc(frame,"UpdateItems",function() if FT.dbReady then self:Queue() end end) end
    end
end
function S:BagSlot(button,key)
    if not button then return end
    local record=self.bagSlots[button]
    if not record then
        record={key=key,edges={}};self.bagSlots[button]=record
        for i=1,4 do
            local edge=button:CreateTexture(nil,"BORDER",nil,1);edge:SetTexture("Interface\\Buttons\\WHITE8x8")
            record.edges[i]=edge
        end
        record.edges[1]:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1);record.edges[1]:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-1);record.edges[1]:SetHeight(1)
        record.edges[2]:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1);record.edges[2]:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1);record.edges[2]:SetHeight(1)
        record.edges[3]:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1);record.edges[3]:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1);record.edges[3]:SetWidth(1)
        record.edges[4]:SetPoint("TOPRIGHT",button,"TOPRIGHT",-1,-1);record.edges[4]:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1);record.edges[4]:SetWidth(1)
        if key=="bagWindows" and hooksecurefunc and button.SetItemButtonTexture then
            hooksecurefunc(button,"SetItemButtonTexture",function(_,itemTexture)
                if issecretvalue and issecretvalue(itemTexture) then return end
                record.empty=itemTexture==nil
                if FT.dbReady then self:PaintEmptyBagSlot(button,record) end
            end)
        end
    end
    local function decoration(texture)
        self:TintArtwork(texture,key)
        if texture and self.artwork[texture] then self.artwork[texture].hideDecoration=true;self:PaintArtwork(texture,self.artwork[texture]) end
    end
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture"}) do
        local texture=button[method] and button[method](button)
        decoration(texture)
        if key=="bags" and texture and self.artwork[texture] then self.artwork[texture].bagSlotBorder=true end
    end
    for _,field in ipairs({"ItemSlotBackground","EmptyBackground","Background","BackgroundTexture","SlotBackground","SlotBackgroundTexture"}) do decoration(button[field]) end
    local anchor=button.icon or button.Icon or button
    if not anchor.GetTexture then anchor=button end
    local edges=record.edges
    for _,edge in ipairs(edges) do edge:ClearAllPoints() end
    edges[1]:SetPoint("TOPLEFT",anchor,"TOPLEFT");edges[1]:SetPoint("TOPRIGHT",anchor,"TOPRIGHT")
    edges[2]:SetPoint("BOTTOMLEFT",anchor,"BOTTOMLEFT");edges[2]:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT")
    edges[3]:SetPoint("TOPLEFT",anchor,"TOPLEFT");edges[3]:SetPoint("BOTTOMLEFT",anchor,"BOTTOMLEFT")
    edges[4]:SetPoint("TOPRIGHT",anchor,"TOPRIGHT");edges[4]:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT")
    if key=="bagWindows" then
        if not record.slotFill then
            record.slotFill=button:CreateTexture(nil,"BACKGROUND",nil,-5)
            record.slotFill:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
            record.slotFill:SetAllPoints(anchor)
        end
        local pref=self:Area(key)
        record.slotFill:SetVertexColor(.6,.63,.68,pref.slotOpacity)
        record.slotFill:SetShown(pref[key])
    end
    if key=="bags" and not record.updateHooked and hooksecurefunc and button.UpdateTextures then
        record.updateHooked=true
        hooksecurefunc(button,"UpdateTextures",function() if FT.dbReady then self:Queue() end end)
    end
    local s=self:Area(key)
    for _,edge in ipairs(record.edges) do edge:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s.borderOpacity);edge:SetShown(s[key] and (key=="bags" or s.hideArt)) end
    if key=="bagWindows" then
        if C_Container and C_Container.GetContainerItemInfo and button.GetBagID and button.GetID then
            local ok,info=pcall(C_Container.GetContainerItemInfo,button:GetBagID(),button:GetID())
            if ok and (not issecretvalue or not issecretvalue(info)) then record.empty=info==nil end
        end
        self:PaintEmptyBagSlot(button,record)
    end
end
function S:PaintEmptyBagSlot(button,record)
    local icon=button.icon or button.Icon
    if not icon or not icon.GetAlpha or not icon.SetAlpha then return end
    local s=self:Area(record.key)
    local hide=s[record.key] and s.hideArt and record.empty==true
    if hide and not record.iconHidden then record.iconAlpha=icon:GetAlpha();record.iconHidden=true;icon:SetAlpha(0)
    elseif not hide and record.iconHidden then icon:SetAlpha(record.iconAlpha or 1);record.iconHidden=false end
end
function S:ApplyBagWindows()
    self:BagWindow(ContainerFrameCombinedBags)
    for i=1,13 do self:BagWindow(_G["ContainerFrame"..i]) end
    self:BagWindow(KeyRingFrame)
    self:BagWindow(ReagentBagFrame)
end
function S:ApplyGryphons()
    for _,name in ipairs({"MainActionBar","MainMenuBar","MainMenuBarArtFrame"}) do
        local frame=_G[name];local caps=frame and frame.EndCaps
        if caps then
            self:TintArtwork(caps.LeftEndCap and caps.LeftEndCap.Texture,"gryphons",true)
            self:TintArtwork(caps.RightEndCap and caps.RightEndCap.Texture,"gryphons",true)
        end
    end
    self:TintArtwork(MainMenuBarLeftEndCap,"gryphons",true)
    self:TintArtwork(MainMenuBarRightEndCap,"gryphons",true)
end
function S:ApplyArtwork()
    self:ApplyBagWindows();self:ApplyGryphons()
    -- Totem bar: the element-colored square frames (earth/fire/water/air) on
    -- the multi-cast bar and the round borders on the player totem timers
    -- follow the Stance / totem area color, like other stance-bar borders.
    for i=1,4 do local slot=_G["MultiCastSlotButton"..i]; if slot then self:TintArtwork(slot.overlayTex,"stances") end end
    for i=1,12 do local button=_G["MultiCastActionButton"..i]; if button then self:TintArtwork(button.overlayTex,"stances") end end
    if TotemFrame and TotemFrame.GetChildren then
        for _,button in ipairs({TotemFrame:GetChildren()}) do self:TintArtwork(button.Border,"stances") end
    end
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
    -- Forever creates narrow decorative separator frames, not bar-wide textures.
    if BagsBar then
        for _,field in ipairs({"HorizontalDividersPool","VerticalDividersPool"}) do
            local pool=BagsBar[field]
            if pool and pool.EnumerateActive then
                for divider in pool:EnumerateActive() do
                    if divider.GetRegions then
                        for _,texture in ipairs({divider:GetRegions()}) do self:TintArtwork(texture,"bags",true) end
                    end
                end
            end
        end
        if not self.bagLayoutHooked and hooksecurefunc and BagsBar.UpdateDividers then
            self.bagLayoutHooked=true;hooksecurefunc(BagsBar,"UpdateDividers",function() self:Queue() end)
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
                    if (lower:find("bag",1,true) or lower:find("keyring",1,true) or lower:find("actionbar",1,true))
                        and (lower:find("border",1,true) or lower:find("frame",1,true) or lower:find("background",1,true)) then
                        if region~=button.icon and region~=button.Icon and region~=button.SlotHighlightTexture
                            and region~=(button.GetHighlightTexture and button:GetHighlightTexture()) then
                            self:TintArtwork(region,"bags")
                            if self.artwork[region] then self.artwork[region].hideDecoration=true end
                        end
                    end
                end
            end end
            self:BagFill(button);self:BagSlot(button,"bags")
            local icon=button.icon or button.Icon
            -- Native mouseover/slot highlights use bright additive frame art.
            -- Tint their edges too; keep their visibility and click behavior native.
            if button.GetHighlightTexture then self:TintArtwork(button:GetHighlightTexture(),"bags") end
            self:TintArtwork(button.SlotHighlightTexture,"bags")
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
            if main then self:TintArtwork(main.LevelBackgroundCircle,key); self:TintArtwork(main.PvpBackgroundCircle,key) end
            local contextual=content and (content.TargetFrameContentContextual or content.PlayerFrameContentContextual)
            if contextual then self:TintArtwork(contextual.PvpBackgroundCircle,key);self:TintArtwork(contextual.BossIcon,key) end
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
for _,event in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_TARGET","UNIT_CLASSIFICATION_CHANGED","UPDATE_EXPANSION_LEVEL","UPDATE_FACTION","BAG_UPDATE_DELAYED"}) do artworkEvents:RegisterEvent(event) end
artworkEvents:SetScript("OnEvent",function() if FT.dbReady then S:Queue() end end)
