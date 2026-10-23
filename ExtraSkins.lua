local _,FT=...
local S=FT.modules.IconStyles
S.artwork={};S.bagFills={};S.targetRims={};S.bagSlots={}
S.extraOptions={{"minimap","Minimap"},{"stances","Stance / totem bars"},{"micro","Micro menu"},{"bags","Bag bar"},{"bagWindows","Bag menu"},{"bank","Bank"},{"gryphons","Gryphon frame"},{"player","Player frame"},{"pet","Pet frame"},{"target","Target frame"},{"tot","Target of target"},{"focus","Focus frame"},{"focustarget","Focus target"},{"party","Party frames"},{"personal","Personal resources"},{"castbar","Cast bars"},{"swing","Swing timers"},{"xp","XP / reputation"},{"tooltip","Tooltips"},{"dialogs","Dialog windows"},{"gameWindows","Game windows"},{"calendar","Calendar"},{"trinkets","Trinket menu"},{"nearby","Nearby enemies"},{"enemyAlert","Enemy alert"},{"bgTimer","Battleground timer"},{"notices","Notices"},{"meters","Meters"},{"ftBars","Interrupt / enemy bars"}}
-- A frame's children / regions, safely: some game frames hold parts that
-- addons may not touch (the trade window's money boxes, for one). Asking
-- for those raises an error, so such frames count as empty here.
local function forbidden(f) return f.IsForbidden and f:IsForbidden() end
local function kids(f)
    if not f or not f.GetChildren or forbidden(f) then return {} end
    local ok,list=pcall(function() return {f:GetChildren()} end)
    return ok and list or {}
end
local function regs(f)
    if not f or not f.GetRegions or forbidden(f) then return {} end
    local ok,list=pcall(function() return {f:GetRegions()} end)
    return ok and list or {}
end
function S:TintArtwork(texture,key,secondary)
    if not texture or type(texture.GetVertexColor)~="function" or type(texture.SetVertexColor)~="function" then return end
    -- Our own textures (the bag slots' action-button frame) are never game art.
    if texture.ftOwn then return end
    local record=self.artwork[texture]
    if not record then
        record={key=key,original={texture:GetVertexColor()},desaturated=texture.IsDesaturated and texture:IsDesaturated(),bank=self.markingBank}; self.artwork[texture]=record
        if hooksecurefunc then hooksecurefunc(texture,"SetVertexColor",function(_,r,g,b,a)
            if self.paintingArtwork then return end
            local o=record.original; o[1],o[2],o[3],o[4]=r,g,b,a or 1; self:PaintArtwork(texture,record)
        end) end
    end
    if not record.atlasHooked and hooksecurefunc and texture.SetAtlas then
        record.atlasHooked=true
        hooksecurefunc(texture,"SetAtlas",function() if not self.paintingArtwork then self:PaintArtwork(texture,record) end end)
    end
    if secondary then record.secondary=true end
    -- The bank's bag slot buttons: their dark fill stays the game's (black
    -- on black they could not be seen as buttons); their outline goes a dark
    -- grey instead of black.
    if record.bankBagArt==nil then
        local atlas=texture.GetAtlas and texture:GetAtlas()
        if type(atlas)=="string" and not (issecretvalue and issecretvalue(atlas)) then
            atlas=atlas:lower()
            if atlas=="bank-frame-bag-slot-bg" then record.bankBagArt="fill"
            elseif atlas=="bank-frame-bag-slotframe" then record.bankBagArt="outline"; record.lift=record.lift or .35; record.desaturate=true
            else record.bankBagArt=false end
        else record.bankBagArt=false end
    end
    self:PaintArtwork(texture,record)
end
function S:BagBackdrop(texture)
    self:TintArtwork(texture,"bags")
    if self.artwork[texture] then self.artwork[texture].bagBackdrop=true end
end
function S:BagFill(button)
    -- Retired (2026-10-16 beta art): the bag bar keeps the game's own slot
    -- frames and is only recolored, so no fill of ours behind the icons.
    local fill=self.bagFills[button]
    if fill then fill:Hide() end
    do return end
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
        -- Rounded corners like the player frame's bar. The rounded texture is
        -- drawn as a nine-slice (corners kept at their own size, edges
        -- stretched): stretched whole, it turned into a long taper wherever
        -- missing health exposed it. Builds without nine-slice textures keep
        -- the plain rectangle.
        if rim.SetTextureSliceMargins then
            rim:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
            rim:SetTextureSliceMargins(8,8,8,8)
            if rim.SetTextureSliceMode then rim:SetTextureSliceMode(0) end
            rim.rounded=true
            -- Square right end: the backing meets the portrait ring there, and
            -- rounded corners made the outline go thin before the ring.
            local cap=bar:CreateTexture(nil,"BACKGROUND",nil,-8)
            cap:SetTexture("Interface\\Buttons\\WHITE8x8")
            cap:SetPoint("TOPRIGHT",rim,"TOPRIGHT");cap:SetPoint("BOTTOMRIGHT",rim,"BOTTOMRIGHT");cap:SetWidth(8)
            rim.cap=cap
        else
            rim:SetTexture("Interface\\Buttons\\WHITE8x8")
        end
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
        -- 1 px short of the ring: close enough that the top and bottom edges
        -- of the backing reach the portrait like on the left side.
        right=math.max(-12,math.min(2,math.floor(portraitLeft-barRight-1)))
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
    if rim.cap then
        rim.cap:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s[key] and s.borderOpacity or 0)
        rim.cap:SetShown(s[key])
    end
    if filler then
        filler:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s[key] and s.borderOpacity or 0)
        filler:SetShown(s[key] and right<0)
    end
end
-- Player frame: the health fill fades in over its first pixels (the game's
-- own shading), the power fill starts at full color, so the power bar looked
-- to start further left. A strip in the frame's color over the power bar's
-- first 2 screen pixels lines them up. Nothing is moved or resized: the
-- bar, its mask and the outlines stay the game's own.
function S:PlayerPowerEdge(frame)
    -- Player frame: the bars' own backing shows as a thin light line at their
    -- left end, next to the frame (most visible with class colors). A strip
    -- of one screen pixel in the frame's color covers it on the health and the
    -- power bar. Nothing is moved or resized.
    local content=frame and frame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    if not main then return end
    local health=(main.HealthBarsContainer and main.HealthBarsContainer.HealthBar) or main.HealthBar
    local power=(main.ManaBarArea and main.ManaBarArea.ManaBar) or main.ManaBar
    local s=self:Area("player")
    self.playerEdges=self.playerEdges or {}
    for i=1,2 do
        local bar=i==1 and health or power
        if bar and bar.CreateTexture then
            local edge=self.playerEdges[bar]
            if not edge and s.player then
                -- On a frame of its own above the bar: the bar's heal and
                -- absorb bars are frames on top of it and drew over the strip.
                local holder=CreateFrame("Frame",nil,bar); holder:SetAllPoints(bar); holder:SetFrameLevel(bar:GetFrameLevel()+20)
                edge=holder:CreateTexture(nil,"OVERLAY",nil,7)
                edge:SetTexture("Interface\\Buttons\\WHITE8x8")
                self.playerEdges[bar]=edge
            end
            if edge then
                -- Two screen pixels across the bar's left end (one outside, one
                -- inside): the light line can be the bar's backing just left of it.
                local px=self.OnePixel and self.OnePixel(bar) or 1
                if edge.width~=px then
                    edge.width=px
                    edge:ClearAllPoints(); edge:SetPoint("TOPLEFT",bar,"TOPLEFT",-px,0); edge:SetPoint("BOTTOMLEFT",bar,"BOTTOMLEFT",-px,0); edge:SetWidth(2*px)
                end
                -- The same tone as the frame art (never darker than its lift).
                -- The frame art is a shaded picture times the color, so a plain
                -- strip must be darker still to look the same.
                local c,l=s.borderColor,.025
                edge:SetVertexColor(math.max(c[1],l),math.max(c[2],l),math.max(c[3],l),s.player and s.borderOpacity or 0)
                edge:SetShown(s.player and true or false)
            end
        end
    end
end
function S:RetireUnitExtras()
    for _,rim in pairs(self.targetRims) do
        rim:Hide(); if rim.cap then rim.cap:Hide() end; if rim.filler then rim.filler:Hide() end
    end
    -- (The older 2 px strip on the power bar.)
    if self.powerEdge then self.powerEdge:Hide() end
end
-- Unit frame art in dark colors: never pure black, so the frame keeps its
-- bevel and inner lines and looks as thick as the game's own.
local UNIT_LIFT={player=.06,target=.06,tot=.06,focus=.06,focustarget=.06,pet=.06,party=.06}
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
    -- Bank pieces follow their own switch (Skins > Bank).
    local active=self:SkinOn(record,s) and allowed
    -- Addon minimap button rings follow their own choice.
    if record.ringChoice and s[record.ringChoice]~="dark" then active=false end
    if record.bankBagArt=="fill" then active=false end
    -- Calendar day tiles: the parchment kept (desaturated, never black),
    -- only darkened in the background color.
    if record.tile then
        if texture.SetDesaturated then texture:SetDesaturated(active or record.desaturated or false) end
        if active then local c,l=s.color,.2; texture:SetVertexColor(math.max(c[1],l),math.max(c[2],l),math.max(c[3],l),record.original[4] or 1)
        else texture:SetVertexColor(unpack(record.original)) end
        self.paintingArtwork=false
        return
    end
    -- Quest and gossip parchment: dark only with "Dark parchment" on.
    if record.parchment then
        local dark=active and s.darkParchment==true
        if texture.SetDesaturated then texture:SetDesaturated(dark or record.desaturated or false) end
        if dark then texture:SetVertexColor(s.color[1],s.color[2],s.color[3],1) else texture:SetVertexColor(unpack(record.original)) end
        self.paintingArtwork=false
        return
    end
    if texture.SetDesaturated and (record.desaturate or record.key=="micro" or record.key=="bags" or record.key=="bagWindows" or record.key=="gryphons" or record.key=="dialogs" or record.key=="calendar" or record.key=="gameWindows") then texture:SetDesaturated(active or record.desaturated or false) end
    -- Tooltip borders: a colored border (an item's quality, for example)
    -- means something; only the plain grey or white one takes the skin.
    if active and record.keepColored then
        local o=record.original; local r,g,b=o[1],o[2],o[3]
        if type(r)=="number" and type(g)=="number" and type(b)=="number" and not (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)))
            and math.max(r,g,b)-math.min(r,g,b)>.08 then active=false end
    end
    if active and record.bankBagArt~="outline" and (record.bagSlotBorder or (record.hideDecoration and (record.key=="bagWindows" and s.hideSlotArt or record.key~="bagWindows" and s.hideArt))) then
        texture:SetVertexColor(1,1,1,0)
    elseif record.background then
        if active then
            texture:SetVertexColor(s.color[1],s.color[2],s.color[3],s.hideArt and 0 or s.opacity)
        else texture:SetVertexColor(unpack(record.original)) end
        if record.replacement then
            record.replacement:SetVertexColor(s.color[1],s.color[2],s.color[3],s.opacity)
            record.replacement:SetShown(active and s.hideArt)
        end
    elseif active and record.lift then
        -- Never fully black (class points): a dark tone keeps their shape.
        local c,l=s.borderColor,record.lift
        texture:SetVertexColor(math.max(c[1],l),math.max(c[2],l),math.max(c[3],l),(record.original[4] or 1)*math.max(s.borderOpacity,.5))
    elseif active and special and s.preset=="dark" then
        -- Keep the native dragon/star silhouette legible: warm dark bronze for
        -- elites and cool dark silver for rares, rather than a black silhouette.
        local r,g,b=.23,.18,.10
        if rare or classification=="rare" or classification=="rareelite" then r,g,b=.23,.26,.30 end
        texture:SetVertexColor(r,g,b,(record.original[4] or 1)*s.borderOpacity)
    elseif active and record.key=="bags" and s.barStyle=="action" and not record.highlight then
        -- Bag bar, action bar style: the bar's frame, slot frames and
        -- dividers are hidden; plain square icons (empty slots keep their art).
        texture:SetVertexColor(1,1,1,0)
    elseif active and UNIT_LIFT[record.key] then
        local c,l=s.borderColor,UNIT_LIFT[record.key]
        texture:SetVertexColor(math.max(c[1],l),math.max(c[2],l),math.max(c[3],l),(record.original[4] or 1)*s.borderOpacity)
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
-- A window's own frame art: border, portrait ring, inset and background.
-- Shared by the bag windows and the dialog windows (NPC, trade, mail ...).
-- Only plain background art may be colored in a dialog window: a window's
-- "background" can also be a picture (the flight master's map is one), and
-- coloring that blacks it out. A texture counts as plain background only
-- when its art name says so; unknown or unnamed art is left alone.
local function plainBackground(texture)
    local name=texture.GetAtlas and texture:GetAtlas()
    if type(name)~="string" or name=="" or (issecretvalue and issecretvalue(name)) then name=texture.GetTexture and texture:GetTexture() end
    if type(name)~="string" or (issecretvalue and issecretvalue(name)) then return false end
    name=name:lower()
    -- Pictures and paper are never plain background.
    for _,word in ipairs({"parchment","questbg","questbackground","stationery","letter","paper","map","scroll","book","portrait"}) do if name:find(word,1,true) then return false end end
    for _,word in ipairs({"background","bg","marble","rock","flatpanel","dialogbox"}) do if name:find(word,1,true) then return true end end
    return false
end
S.PlainBackground=plainBackground
-- A window background: tinted in the area's background color, or hidden
-- behind a plain fill with "Hide window art".
--   template: a piece of the game's flat panel background (loot, bank),
--   plain by definition whatever its art is called.
function S:WindowBackground(texture,key,opts,template)
    if not texture or not texture.GetVertexColor or not texture.GetParent then return end
    -- Quest and gossip parchment has its own switch (dialog windows).
    if self.parchments and self.parchments[texture] then return end
    if opts and (opts.noBackground or (opts.plainOnly and not template and not plainBackground(texture))) then return end
    self:TintArtwork(texture,key)
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
-- opts.plainOnly: color only plain background art (dialog windows).
-- opts.noBackground: leave every background alone (map windows).
function S:WindowArt(frame,key,opts)
    if not frame then return end
    self:ArtworkFrame(frame,key)
    for _,field in ipairs({"PortraitContainer","Inset","InsetFrame","MoneyFrame"}) do
        local part=frame[field]
        self:ArtworkFrame(part,key)
        if part then
            self:TintArtwork(part.PortraitFrame,key)
            self:TintArtwork(part.Border,key)
            if part.Border then for _,edge in ipairs({"Left","Middle","Right"}) do self:TintArtwork(part.Border[edge],key) end end
        end
    end
    local function background(texture,template) self:WindowBackground(texture,key,opts,template) end
    for _,part in pairs({frame=frame,inset=frame.Inset,insetFrame=frame.InsetFrame}) do
        for _,field in ipairs({"Bg","Background","TitleBg","InsetBg","TopTileStreaks"}) do
            local art=part[field]
            if art and art.GetObjectType and art:GetObjectType()=="Texture" then background(art)
            elseif art then
                -- Forever's FlatPanelBackgroundTemplate is a frame with four
                -- background textures rather than a single Bg texture.
                for _,piece in ipairs({"BottomLeft","BottomRight","BottomEdge","TopSection"}) do background(art[piece],true) end
            end
        end
    end
end
function S:BagWindow(frame,opts)
    if not frame then return end
    self:WindowArt(frame,"bagWindows",opts)
    if frame.EnumerateValidItems then
        for _,button in frame:EnumerateValidItems() do self:BagSlot(button,"bagWindows") end
    elseif frame.GetChildren then
        for _,button in ipairs(kids(frame)) do if button.GetBagID then self:BagSlot(button,"bagWindows") end end
    end
    if not self.bagWindowHooks then self.bagWindowHooks={} end
    if frame.HookScript and not self.bagWindowHooks[frame] then
        self.bagWindowHooks[frame]=true
        -- Only this bag window needs redoing, once per burst, and only while
        -- the Bag menu skin is on (turning it off repaints everything once).
        local key="bagArt"..tostring(frame)
        local function bags()
            if not FT.dbReady or not self:Settings().bagWindows then return end
            FT:Coalesce(key,function() if not FT:LooksWait() then self:BagWindow(frame) end end,.1)
        end
        frame:HookScript("OnShow",bags)
        if hooksecurefunc and frame.UpdateItems then hooksecurefunc(frame,"UpdateItems",bags) end
    end
end
function S:BagSlot(button,key)
    if not button then return end
    local record=self.bagSlots[button]
    if not record then
        record={key=key,edges={},bank=self.markingBank};self.bagSlots[button]=record
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
    -- Bag bar style: the game's slot frames recolored ("game"), or the
    -- slot frames hidden for plain square icons like action buttons ("action").
    local actionStyle=key=="bags" and self:Area("bags").barStyle=="action"
    for _,method in ipairs({"GetNormalTexture","GetPushedTexture"}) do
        local texture=button[method] and button[method](button)
        decoration(texture)
        if key=="bags" and texture and self.artwork[texture] then
            local record=self.artwork[texture]
            if (record.bagSlotBorder==true)~=actionStyle then record.bagSlotBorder=actionStyle or nil; self:PaintArtwork(texture,record) end
        end
    end
    -- Bank slots keep the game's empty-slot art, like the bag slots show it.
    if not self.markingBank then
        for _,field in ipairs({"ItemSlotBackground","EmptyBackground","Background","BackgroundTexture","SlotBackground","SlotBackgroundTexture"}) do decoration(button[field]) end
    end
    local anchor=button.icon or button.Icon or button
    if not anchor.GetTexture then anchor=button end
    local edges=record.edges
    -- Re-anchoring 400 lines on every bag update makes the game lay them
    -- out again: only when the slot's picture changed.
    if record.edgeAnchor~=anchor then
        record.edgeAnchor=anchor
        for _,edge in ipairs(edges) do edge:ClearAllPoints() end
        edges[1]:SetPoint("TOPLEFT",anchor,"TOPLEFT");edges[1]:SetPoint("TOPRIGHT",anchor,"TOPRIGHT")
        edges[2]:SetPoint("BOTTOMLEFT",anchor,"BOTTOMLEFT");edges[2]:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT")
        edges[3]:SetPoint("TOPLEFT",anchor,"TOPLEFT");edges[3]:SetPoint("BOTTOMLEFT",anchor,"BOTTOMLEFT")
        edges[4]:SetPoint("TOPRIGHT",anchor,"TOPRIGHT");edges[4]:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT")
    end
    -- Bag bar: the same soft frame and rounded icon corners as the action bars
    -- instead of four straight lines (kept as the fallback without the frame art).
    -- Bag bar: the game's own slot frames, recolored (same shape and size
    -- as without the skin). Our older rounded frame and icon mask are put away.
    if key=="bags" then
        -- Action bar style: the game's slot frames are hidden (see
        -- PaintArtwork); each icon gets the action buttons' own frame, in
        -- the border color, like your action bars. Game frames: none.
        local pref=self:Area("bags")
        local action=pref.barStyle=="action" and pref.bags
        -- Small slots (the keyring) have their own, narrower frame picture.
        local normal=button.GetNormalTexture and button:GetNormalTexture()
        local normalAtlas=normal and normal.GetAtlas and normal:GetAtlas()
        local small=type(normalAtlas)=="string" and not (issecretvalue and issecretvalue(normalAtlas)) and normalAtlas:lower():find("small",1,true)~=nil
        local frameAtlas=(small and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame-Small")) and "UI-HUD-ActionBar-IconFrame-Small" or "UI-HUD-ActionBar-IconFrame"
        if action and not record.frameArt and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
            record.frameArt=button:CreateTexture(nil,"ARTWORK",nil,7)
            record.frameArt:SetAtlas(frameAtlas)
            record.frameArt.ftOwn=true
        end
        if record.frameArt and small and not record.smallFrame then
            -- Exactly where the game's own (hidden) frame is, so nothing of
            -- the slot's art sticks out at the side.
            record.smallFrame=true; record.frameArt:SetAtlas(frameAtlas)
        end
        if record.frameArt then
            -- An earlier build took it for the game's bag art and hid it.
            record.frameArt.ftOwn=true; self.artwork[record.frameArt]=nil
            -- Placed like on an action button: the frame picture starts at
            -- the icon's top left and is 46/45 as wide (its ring sits on the
            -- icon's edge evenly all round).
            local w=anchor.GetWidth and anchor:GetWidth()
            local extra=(type(w)=="number" and not (issecretvalue and issecretvalue(w)) and w>0) and w/45 or 1
            if record.smallFrame and normal then
                if record.frameAnchor~=normal then record.frameAnchor=normal; record.frameArt:ClearAllPoints(); record.frameArt:SetAllPoints(normal) end
            elseif record.frameExtra~=extra or record.frameAnchor~=anchor then
                record.frameExtra,record.frameAnchor=extra,anchor
                record.frameArt:ClearAllPoints(); record.frameArt:SetPoint("TOPLEFT",anchor,"TOPLEFT",0,0); record.frameArt:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT",extra,0)
            end
            record.frameArt:SetShown(action and true or false)
            if action then record.frameArt:SetDesaturated(true); record.frameArt:SetVertexColor(pref.borderColor[1],pref.borderColor[2],pref.borderColor[3],1); record.frameArt:SetAlpha(pref.borderOpacity) end
        end
        if record.mask and record.maskOn and anchor.RemoveMaskTexture then anchor:RemoveMaskTexture(record.mask); record.maskOn=false end
        -- Action style: the icon is cropped like action buttons, so the dark
        -- edge painted into bag pictures doesn't show on one side of the frame.
        local icon=anchor~=button and anchor or nil
        if icon and icon.SetTexCoord then
            if record.smallFrame then
                -- Small slots (the keyring) show the game's own slot art: never
                -- cropped, or it looks bigger than its frame.
                if not record.smallUncropped then record.smallUncropped=true; icon:SetTexCoord(0,1,0,1) end
            elseif action and record.frameArt and not record.iconCropped then
                local a,b,c,d,e,f,g,h=icon:GetTexCoord()
                record.iconCoord=(type(a)=="number" and not (issecretvalue and issecretvalue(a))) and {a,b,c,d,e,f,g,h} or nil
                record.iconCropped=true; icon:SetTexCoord(.07,.93,.07,.93)
            elseif not action and record.iconCropped then
                record.iconCropped=false
                local c=record.iconCoord
                if c and #c==8 then icon:SetTexCoord(c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8]) else icon:SetTexCoord(0,1,0,1) end
            end
        end
    end
    if key=="bagWindows" then
        if not record.slotFill then
            record.slotFill=button:CreateTexture(nil,"BACKGROUND",nil,-5)
            record.slotFill:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
            record.slotFill:SetAllPoints(anchor)
        end
        local pref=self:Area(key)
        record.slotFill:SetVertexColor(pref.slotColor[1],pref.slotColor[2],pref.slotColor[3],pref.slotOpacity)
        record.slotFill:SetShown(self:SkinOn(record,pref) or false)
        -- With the slot art hidden, frame each slot with the game's own soft
        -- action-button frame (like buffs), tinted in the border color,
        -- instead of thin square lines.
        if not record.frameArt and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-HUD-ActionBar-IconFrame") then
            record.frameArt=button:CreateTexture(nil,"ARTWORK",nil,7)
            record.frameArt:SetAtlas("UI-HUD-ActionBar-IconFrame")
            record.frameArt:SetPoint("TOPLEFT",anchor,"TOPLEFT",-2,2); record.frameArt:SetPoint("BOTTOMRIGHT",anchor,"BOTTOMRIGHT",2,-2)
            record.frameArt.ftOwn=true
        end
        if record.frameArt then
            local on=self:SkinOn(record,pref) and pref.hideSlotArt
            record.frameArt:SetShown(on and true or false)
            if on then record.frameArt:SetVertexColor(pref.borderColor[1],pref.borderColor[2],pref.borderColor[3],1); record.frameArt:SetAlpha(pref.borderOpacity) end
        end
    end
    -- An equipped bag is a white (common) item, and the game draws a faint
    -- white quality border around it. With the bag bar skin on, that border
    -- is hidden for common and poor items (better bags keep their color).
    if false and key=="bags" and button.IconBorder then
        local function quiet(quality)
            if not FT.dbReady or not self:Settings().bags then return end
            if quality~=nil and (issecretvalue and issecretvalue(quality)) then return end
            if quality==nil or (type(quality)=="number" and quality<=1) then button.IconBorder:Hide() end
        end
        if not record.qualityHooked and hooksecurefunc and button.SetItemButtonQuality then
            record.qualityHooked=true
            hooksecurefunc(button,"SetItemButtonQuality",function(_,quality) quiet(quality) end)
        end
        local border=button.IconBorder
        -- A white or grey border is the common-quality one: hide it. Checked
        -- again whenever the game shows or recolors it (closing the bags
        -- redraws the buttons without going through the quality call).
        local function neutral()
            if not FT.dbReady or not self:Settings().bags or not border:IsShown() or not border.GetVertexColor then return end
            local r,g,b=border:GetVertexColor()
            if (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b))) or type(r)~="number" or type(g)~="number" or type(b)~="number" then return end
            if math.max(r,g,b)-math.min(r,g,b)<.08 then border:Hide() end
        end
        if not record.borderHooked and hooksecurefunc then
            record.borderHooked=true
            for _,method in ipairs({"Show","SetShown","SetVertexColor"}) do if border[method] then hooksecurefunc(border,method,neutral) end end
        end
        neutral()
    end
    -- The game redraws a bag button's frame art when the bags open or close
    -- (its open highlight, its normal frame): put our look back after it.
    if key=="bags" and not record.redrawHooked and hooksecurefunc then
        record.redrawHooked=true
        local function again()
            if not FT.dbReady or not self:Settings().bags then return end
            FT:Coalesce("bagButton"..tostring(button),function() if not FT:LooksWait() then self:BagFill(button); self:BagSlot(button,"bags") end end,.05)
        end
        for _,method in ipairs({"SetNormalAtlas","SetNormalTexture","SetPushedAtlas","SetPushedTexture","SetChecked"}) do if type(button[method])=="function" then hooksecurefunc(button,method,again) end end
        local glow=button.SlotHighlightTexture
        if glow then for _,method in ipairs({"Show","Hide","SetShown"}) do if glow[method] then hooksecurefunc(glow,method,again) end end end
    end
    if key=="bags" and not record.updateHooked and hooksecurefunc and button.UpdateTextures then
        record.updateHooked=true
        -- Looting updates the bag bar buttons: redo just that button.
        hooksecurefunc(button,"UpdateTextures",function()
            if not FT.dbReady or not self:Settings().bags or FT:LooksWait() then return end
            FT:Coalesce("bagButton"..tostring(button),function() if not FT:LooksWait() then self:BagFill(button); self:BagSlot(button,"bags") end end,.1)
        end)
    end
    local s=self:Area(key)
    local areaOn=self:SkinOn(record,s)
    for _,edge in ipairs(record.edges) do edge:SetVertexColor(s.borderColor[1],s.borderColor[2],s.borderColor[3],s.borderOpacity);edge:SetShown(areaOn and key~="bags" and s.hideSlotArt and not record.frameArt and true or false) end
    if key=="bagWindows" then
        if C_Container and C_Container.GetContainerItemInfo and button.GetBagID and button.GetID then
            local ok,info=pcall(C_Container.GetContainerItemInfo,button:GetBagID(),button:GetID())
            if ok and (not issecretvalue or not issecretvalue(info)) then record.empty=info==nil end
        end
        self:PaintEmptyBagSlot(button,record)
    end
end
-- /ft bagdebug: what the first bag bar button shows right now, to find
-- a piece of game art that still draws over the skin.
function S:BagDebug()
    -- Every button on the bag bar, and whether the skin knows it.
    if BagsBar then
        print("ForeverTools bag bar buttons:")
        for _,child in ipairs(kids(BagsBar)) do
            local normal=child.GetNormalTexture and child:GetNormalTexture()
            local atlas=normal and normal.GetAtlas and normal:GetAtlas()
            print(string.format("  %s  %s  icon %s  frame %s  skinned %s",tostring(child.GetName and child:GetName()),tostring(child.GetObjectType and child:GetObjectType()),tostring((child.icon or child.Icon or child.IconTexture) and true or false),tostring(atlas),tostring(self.bagSlots[child] and true or false)))
        end
    end
    for _,name in ipairs({"KeyRingButton","MainMenuBarKeyRingButton","CharacterReagentBag0Slot","ReagentBagSlot"}) do
        local b=_G[name]; if b then print("  named "..name..": skinned "..tostring(self.bagSlots[b] and true or false)) end
    end
    -- The first bag button, then the keyring (its art sits a little off).
    local first=_G.CharacterBag0Slot or _G.MainMenuBarBackpackButton
    if not first or not first.GetRegions then print("ForeverTools: no bag button found."); return end
    for _,button in ipairs({first,_G.KeyRingButton or _G.MainMenuBarKeyRingButton or false}) do if button then
    local names={}
    for k,v in pairs(button) do if type(k)=="string" and type(v)=="table" then names[v]=k end end
    for _,m in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetCheckedTexture"}) do
        local t=button[m] and button[m](button); if t and not names[t] then names[t]=m:sub(4) end
    end
    print("ForeverTools bag button "..tostring(button:GetName())..": size "..tostring(button:GetWidth()).."x"..tostring(button:GetHeight()))
    for _,region in ipairs(regs(button)) do
        if region.IsShown and region:IsShown() and region.GetObjectType and region:GetObjectType()=="Texture" then
            local atlas=region.GetAtlas and region:GetAtlas(); local file=region.GetTexture and region:GetTexture()
            local r,g,b,a=region:GetVertexColor(); local layer,sub=region:GetDrawLayer()
            local function n(v) if issecretvalue and issecretvalue(v) then return "?" end; return type(v)=="number" and string.format("%.2f",v) or tostring(v) end
            print(string.format("  %s  %s  color %s %s %s %s  alpha %s  %s %s",names[region] or "(unnamed)",tostring((type(atlas)=="string" and atlas~="" and atlas) or file),n(r),n(g),n(b),n(a),n(region:GetAlpha()),tostring(layer),tostring(sub)))
            -- Where it sits on the button (left, top, size) and its crop.
            local bl,bt=button:GetLeft(),button:GetTop()
            local l,tp,w,h=region:GetLeft(),region:GetTop(),region:GetWidth(),region:GetHeight()
            local c1,c2,_,_,_,_,c7,c8=region:GetTexCoord()
            if type(l)=="number" and type(bl)=="number" and not (issecretvalue and (issecretvalue(l) or issecretvalue(bl))) then
                print(string.format("      at %s,%s  size %sx%s  crop %s-%s,%s-%s",n(l-bl),n((tp or 0)-(bt or 0)),n(w),n(h),n(c1),n(c7),n(c2),n(c8)))
            end
        end
    end
    end end
end
function S:PaintEmptyBagSlot(button,record)
    local icon=button.icon or button.Icon
    if not icon or not icon.GetAlpha or not icon.SetAlpha then return end
    local s=self:Area(record.key)
    local hide=self:SkinOn(record,s) and s.hideSlotArt and record.empty==true
    if hide and not record.iconHidden then record.iconAlpha=icon:GetAlpha();record.iconHidden=true;icon:SetAlpha(0)
    elseif not hide and record.iconHidden then icon:SetAlpha(record.iconAlpha or 1);record.iconHidden=false end
end
-- Bank pieces (records marked bank) follow Skins > Bank, with the Bag
-- menu's look; everything else follows its own area's switch.
function S:SkinOn(record,area)
    if record.bank then return self:Settings().bank==true end
    return area[record.key] and true or false
end
-- Forever's bank: its frame like a bag window, and its item slots like bag
-- slots. The slots are made again whenever the bank shows another tab, so
-- they are redone after that (once per burst, out of combat).
function S:BankWindow()
    local bank=_G.BankFrame
    if not bank then return end
    -- The game's bank is left alone until its own switch is turned on.
    local on=self:Settings().bank==true
    if not on and not self.bankTouched then return end
    self.bankTouched=true
    self.markingBank=true
    -- Same look as the bag windows: their background and empty-slot art are
    -- the game's own (only frame lines and slot colors change). Coloring the
    -- bank's background and slot art made it all one black, and its buttons
    -- and empty slots could not be seen.
    self:BagWindow(bank,{noBackground=true})
    local panel=bank.BankPanel
    local pool=panel and panel.itemButtonPool
    if pool and pool.EnumerateActive then
        for button in pool:EnumerateActive() do self:BagSlot(button,"bagWindows") end
    end
    self.markingBank=nil
    if panel and not self.bankHooked and hooksecurefunc then
        self.bankHooked=true
        local function again()
            if not FT.dbReady or self:Settings().bank~=true then return end
            FT:Coalesce("bankArt",function() if not FT:LooksWait() then self:BankWindow() end end,.1)
        end
        if panel.GenerateItemSlotsForSelectedTab then hooksecurefunc(panel,"GenerateItemSlotsForSelectedTab",again) end
        if panel.RefreshBankPanel then hooksecurefunc(panel,"RefreshBankPanel",again) end
        bank:HookScript("OnShow",again)
    end
end
function S:ApplyBagWindows()
    self:BagWindow(ContainerFrameCombinedBags)
    for i=1,13 do self:BagWindow(_G["ContainerFrame"..i]) end
    self:BagWindow(KeyRingFrame)
    self:BagWindow(ReagentBagFrame)
    -- The game's bank window gets the same look as the bags.
    self:BankWindow()
    -- ForeverTools' own view-only bag and bank windows.
    local bags=FT.Bags
    if bags and bags.views then for _,view in pairs(bags.views) do if view:IsShown() then pcall(bags.ApplySkin,bags,view) end end end
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
-- The main action bar's own frame art: the border around the bar and the
-- dividers between its buttons. The game shows it only while the bar sits in
-- its default spot (moved away, it hides), so it follows the Action bars skin
-- and looks the same dark wherever the bar is. Left alone until that skin
-- has been on once. Gryphons keep their own switch.
local function barFrameArt(region)
    local atlas=region and region.GetAtlas and region:GetAtlas()
    if type(atlas)~="string" or (issecretvalue and issecretvalue(atlas)) then return false end
    atlas=atlas:lower()
    return atlas:find("actionbar-frame",1,true) and true or false
end
function S:ApplyActionBarArt()
    if not self:Settings().actions and not self.actionArtTouched then return end
    self.actionArtTouched=true
    for _,name in ipairs({"MainActionBar","MainMenuBar"}) do
        local bar=_G[name]
        if bar then
            self:TintArtwork(bar.BorderArt,"actions")
            if bar.GetRegions then for _,region in ipairs(regs(bar)) do if barFrameArt(region) then self:TintArtwork(region,"actions") end end end
            -- Dividers are pooled frames, handed out again on every layout change.
            for _,field in ipairs({"HorizontalDividersPool","VerticalDividersPool"}) do
                local pool=bar[field]
                if pool and pool.EnumerateActive then
                    for divider in pool:EnumerateActive() do
                        if divider.GetRegions then for _,texture in ipairs(regs(divider)) do self:TintArtwork(texture,"actions") end end
                    end
                end
            end
            if hooksecurefunc and not (self.actionBarHooked and self.actionBarHooked[bar]) then
                self.actionBarHooked=self.actionBarHooked or {}; self.actionBarHooked[bar]=true
                local function again() if FT.dbReady then FT:Coalesce("actionBarArt",function() if not FT:LooksWait() then self:ApplyActionBarArt() end end,.1) end end
                for _,method in ipairs({"UpdateDividers","UpdateEndCaps"}) do if type(bar[method])=="function" then hooksecurefunc(bar,method,again) end end
            end
        end
    end
    -- Builds that keep the dividers on the buttons themselves.
    for i=1,12 do
        local button=_G["ActionButton"..i]
        if button then
            for _,field in ipairs({"RightDivider","BottomDivider","LeftDivider","TopDivider"}) do self:TintArtwork(button[field],"actions") end
        end
    end
end
-- Player, target and focus frame art only: what changes when you pick a
-- new target. Much lighter than redoing every skinned area.
-- Tooltip borders (the game's tooltips, item comparison and link windows).
-- Their edges are a nine-slice; the game recolors it for some tooltips,
-- which the SetVertexColor hook picks up. Left alone until switched on once.
function S:ApplyTooltipArtwork()
    if not self:Settings().tooltip and not self.tooltipTouched then return end
    self.tooltipTouched=true
    for _,name in ipairs({"GameTooltip","ItemRefTooltip","ShoppingTooltip1","ShoppingTooltip2","ItemRefShoppingTooltip1","ItemRefShoppingTooltip2","EmbeddedItemTooltip","FriendsTooltip"}) do
        local tip=_G[name]
        local nine=tip and tip.NineSlice
        if nine then
            for _,field in ipairs({"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}) do
                local piece=nine[field]
                self:TintArtwork(piece,"tooltip")
                local record=piece and self.artwork[piece]
                if record and not record.keepColored then record.keepColored=true; self:PaintArtwork(piece,record) end
            end
        end
    end
end
-- Dialog windows: NPC talk and quests, merchant, trade, mail, trainers,
-- flight master, loot and pop-up dialogs. Their frame art takes the Dialog
-- windows look (like the bag windows); quest and gossip parchment has its own
-- switch, and with it on the dark text on it turns light. Left alone until
-- the area has been on once. Load-on-demand windows are done when they load.
local DIALOG_FRAMES={"GossipFrame","QuestFrame","MerchantFrame","TradeFrame","MailFrame","OpenMailFrame","ClassTrainerFrame","TaxiFrame","FlightMapFrame","LootFrame","StaticPopup1","StaticPopup2","StaticPopup3","StaticPopup4"}
local PARCHMENT_FRAMES={GossipFrame=true,QuestFrame=true,OpenMailFrame=true,MailFrame=true}
-- Windows whose background is a picture: only their border is skinned.
local MAP_FRAMES={TaxiFrame=true,FlightMapFrame=true}
local BORDER_PIECES={"TopLeftCorner","TopRightCorner","BottomLeftCorner","BottomRightCorner","TopEdge","BottomEdge","LeftEdge","RightEdge"}
local function artName(texture)
    local name=texture.GetAtlas and texture:GetAtlas()
    if type(name)~="string" or name=="" or (issecretvalue and issecretvalue(name)) then name=texture.GetTexture and texture:GetTexture() end
    if type(name)~="string" or (issecretvalue and issecretvalue(name)) then return "" end
    return name:lower()
end
-- Every parchment texture in a quest or gossip window (any depth up to depth).
function S:FindParchment(frame,depth,out)
    if not frame or depth<0 then return out end
    if frame.GetRegions then for _,region in ipairs(regs(frame)) do
        if region.GetObjectType and region:GetObjectType()=="Texture" then
            local name=artName(region)
            if name:find("parchment",1,true) or name:find("questbg",1,true) or name:find("questbackground",1,true) or name:find("stationery",1,true) or name:find("letter",1,true) then out[#out+1]=region end
        end
    end end
    if frame.GetChildren then for _,child in ipairs(kids(frame)) do self:FindParchment(child,depth-1,out) end end
    return out
end
local function isTexture(t)
    if type(t)~="table" or not t.GetObjectType or forbidden(t) then return false end
    local ok,kind=pcall(t.GetObjectType,t)
    return ok and kind=="Texture"
end
-- The test client's issue reporter (Issue Report: ..., the bug button on
-- windows) is never skinned: it must stay easy to see and use.
local function reporter(f)
    for _,method in ipairs({"GetName","GetDebugName"}) do
        local ok,n=pcall(f[method] or function() end,f)
        if ok and type(n)=="string" and not (issecretvalue and issecretvalue(n)) then
            local l=n:lower()
            if l:find("ptr",1,true) or l:find("issuereport",1,true) or l:find("feedback",1,true) then return true end
        end
    end
end
S.Reporter=reporter
function S:DialogBorders(frame,depth,key)
    key=key or "dialogs"
    if not frame or depth<=0 or not frame.GetChildren then return end
    for _,child in ipairs(kids(frame)) do
        if not forbidden(child) and not reporter(child) then
            local nine
            if isTexture(child.TopEdge) and isTexture(child.LeftEdge) then nine=child else nine=child.NineSlice end
            if nine and not forbidden(nine) and isTexture(nine.TopEdge) then
                for _,field in ipairs(BORDER_PIECES) do if isTexture(nine[field]) then self:TintArtwork(nine[field],key) end end
            end
            self:DialogBorders(child,depth-1,key)
        end
    end
end
-- The other player's half of the trade window has art of its own (portrait
-- ring, a strip of title bar, the line down the middle, its background),
-- found by the game's names for it: TradeRecipient... / TradeFrameRecipient...
-- The portrait itself, item slots and highlights are left alone.
function S:TradeRecipient(frame)
    local seen={}
    local function visit(f,depth)
        if not f or depth<0 or forbidden(f) then return end
        for _,region in ipairs(regs(f)) do
            if not seen[region] and isTexture(region) then
                seen[region]=true
                local ok,n=pcall(region.GetName,region)
                if ok and type(n)=="string" and (n:find("^TradeRecipient") or n:find("^TradeFrameRecipient"))
                    and not n:find("Item",1,true) and not n:find("Highlight",1,true) then
                    if n:find("Portrait$") then
                        -- the other player's face
                    elseif n:find("BG",1,true) or n:find("Bg",1,true) or n:find("Background",1,true) then
                        self:WindowBackground(region,"dialogs",nil,true)
                    else
                        self:TintArtwork(region,"dialogs")
                    end
                end
            end
        end
        for _,child in ipairs(kids(f)) do visit(child,depth-1) end
    end
    visit(frame,3)
end
-- Your own game windows (Skins > Windows > Game windows): character,
-- spellbook, talents, quest log, social and the like. Only their frame and
-- borders go dark: their pictures (talent trees, the character's backdrop)
-- are kept, like the map windows.
local GAME_FRAMES={"CharacterFrame","PaperDollFrame","PlayerTalentFrame","TalentFrame","ClassTalentFrame","PlayerSpellsFrame","SpellBookFrame","ProfessionsBookFrame","QuestLogFrame","QuestLogPopupDetailFrame","FriendsFrame","GuildFrame","CommunitiesFrame","PVEFrame","LFGParentFrame","PVPFrame","PVPUIFrame","AchievementFrame","CollectionsJournal","EncounterJournal","InspectFrame","DressUpFrame","MacroFrame","TradeSkillFrame","ProfessionsFrame","CraftFrame","AuctionFrame","AuctionHouseFrame","BankFrame","GuildBankFrame","TabardFrame","ItemTextFrame","WorldMapFrame"}
S.GAME_FRAMES=GAME_FRAMES
function S:GameWindow(frame,name)
    if not frame or forbidden(frame) then return end
    self:WindowArt(frame,"gameWindows",{plainOnly=true,noBackground=true})
    local border=frame.Border
    if border and border.GetObjectType and border:GetObjectType()~="Texture" then
        for _,field in ipairs(BORDER_PIECES) do self:TintArtwork(border[field],"gameWindows") end
    end
    self:DialogBorders(frame,3,"gameWindows")
    self:SideTabs(frame,"gameWindows")
    self.gameHooked=self.gameHooked or {}
    if frame.HookScript and not self.gameHooked[frame] then
        self.gameHooked[frame]=true
        frame:HookScript("OnShow",function()
            if not FT.dbReady or not self:Settings().gameWindows then return end
            FT:Coalesce("gameWindow"..name,function() self:GameWindow(frame,name) end,0)
        end)
    end
end
-- The tabs that stick out of a window's side (social, group finder,
-- spellbook): their outer frame art is a plain file texture behind the icon.
-- Only the art around the icon goes dark; the icon, highlight and checked
-- glow are kept.
local function num(v) return type(v)=="number" and not (issecretvalue and issecretvalue(v)) and v or nil end
function S:SideTabs(frame,key)
    local left,right=num(frame.GetLeft and frame:GetLeft()),num(frame.GetRight and frame:GetRight())
    if not left or not right then return end
    local function tab(button)
        local keep={}
        for _,getter in ipairs({"GetNormalTexture","GetPushedTexture","GetHighlightTexture","GetCheckedTexture","GetDisabledTexture"}) do
            if button[getter] then local ok,t=pcall(button[getter],button); if ok and t then keep[t]=true end end
        end
        if button.icon then keep[button.icon]=true end; if button.Icon then keep[button.Icon]=true end
        for _,region in ipairs(regs(button)) do
            if not keep[region] and region.GetObjectType and region:GetObjectType()=="Texture" then
                local layer=region.GetDrawLayer and region:GetDrawLayer()
                if layer=="BACKGROUND" or layer=="BORDER" or layer=="ARTWORK" or layer=="OVERLAY" then
                    local name=artName(region)
                    if not name:find("highlight",1,true) and not name:find("glow",1,true) and not name:find("icon",1,true) then
                        -- One picture holds the tab's fill and its outline: grey
                        -- (not black), so only the outline turns dark.
                        self:TintArtwork(region,key)
                        local record=self.artwork[region]
                        if record and not record.lift then record.desaturate=true; record.lift=.38; self:PaintArtwork(region,record) end
                    end
                end
            end
        end
    end
    -- The game's own side tab art (common-sidetab): found by name, wherever
    -- the tab sits. The selected frame stays a little lighter.
    local function sidetabArt(f)
        for _,region in ipairs(regs(f)) do
            if region.GetObjectType and region:GetObjectType()=="Texture" then
                local name=artName(region)
                if name=="common-sidetab" or name=="common-sidetab-selected" then
                    self:TintArtwork(region,key)
                    local record=self.artwork[region]
                    if record and not record.lift then record.desaturate=true; record.lift=name=="common-sidetab" and .38 or .6; self:PaintArtwork(region,record) end
                end
            end
        end
    end
    local function visit(f,depth)
        if depth<0 then return end
        for _,child in ipairs(kids(f)) do
            sidetabArt(child)
            if child.GetObjectType and (child:GetObjectType()=="Button" or child:GetObjectType()=="CheckButton") then
                local l,r=num(child:GetLeft()),num(child:GetRight())
                local w,h=num(child:GetWidth()),num(child:GetHeight())
                local text=child.GetText and child:GetText()
                local hasText=type(text)=="string" and not (issecretvalue and issecretvalue(text)) and text~=""
                -- A side tab: small and about square, no words, sticking out
                -- of the window's side (never the buttons of a window docked
                -- beside it, like the macro icon picker's Okay and Cancel).
                local sideTab=l and r and w and h and w<=72 and h<=72 and math.abs(w-h)<=24 and not hasText and not child.Left and not child.Middle
                    and ((r>right+6 and l>=right-24 and l<=right+12) or (l<left-6 and r<=left+24 and r>=left-12))
                if sideTab then tab(child) end
            end
            visit(child,depth-1)
        end
    end
    visit(frame,5)
end
-- Every window the game opens as a panel (friends/social, group finder,
-- Forever's own windows...), besides the named list. Dialog windows (NPC,
-- vendor, mail...) have their own skin and are left out here.
function S:IsDialogWindow(name) for _,n in ipairs(DIALOG_FRAMES) do if n==name then return true end end return false end
function S:PanelNames()
    local out={}
    local dialog={}; for _,n in ipairs(DIALOG_FRAMES) do dialog[n]=true end
    if type(UIPanelWindows)=="table" then
        for name in pairs(UIPanelWindows) do if type(name)=="string" and not dialog[name] then out[name]=true end end
    end
    for _,name in ipairs({"SocialUIFrame","LFGUIFrame","GroupFinderFrame"}) do out[name]=true end
    return out
end
function S:ApplyGameWindows()
    if not self:Settings().gameWindows and not self.gameTouched then return end
    self.gameTouched=true
    for _,name in ipairs(GAME_FRAMES) do local frame=_G[name]; if frame then self:GameWindow(frame,name) end end
    for name in pairs(self:PanelNames()) do local frame=_G[name]; if type(frame)=="table" and frame.GetObjectType then self:GameWindow(frame,name) end end
    -- Windows made later (opened for the first time) are skinned as they open.
    if not self.panelHooked and hooksecurefunc and ShowUIPanel then
        self.panelHooked=true
        hooksecurefunc("ShowUIPanel",function(frame)
            if not FT.dbReady or not self:Settings().gameWindows or type(frame)~="table" or not frame.GetName then return end
            local name=frame:GetName(); if not name or self:IsDialogWindow(name) then return end
            FT:Coalesce("panel"..name,function() self:GameWindow(frame,name) end,0)
        end)
    end
end
function S:DialogWindow(frame,name)
    if not frame then return end
    if PARCHMENT_FRAMES[name] then
        self.parchments=self.parchments or {}
        for _,texture in ipairs(self:FindParchment(frame,4,{})) do
            self.parchments[texture]=true
            self:TintArtwork(texture,"dialogs")
            local record=self.artwork[texture]
            if record and not record.parchment then record.parchment=true; self:PaintArtwork(texture,record) end
        end
    end
    self:WindowArt(frame,"dialogs",{plainOnly=true,noBackground=MAP_FRAMES[name]})
    if name=="TradeFrame" then self:TradeRecipient(frame) end
    -- Pop-ups and some panels draw their border as a nine-slice frame of
    -- their own (frame.Border).
    local border=frame.Border
    if border and border.GetObjectType and border:GetObjectType()~="Texture" then
        for _,field in ipairs(BORDER_PIECES) do self:TintArtwork(border[field],"dialogs") end
    end
    -- A backdrop border (older pop-ups) keeps its edge and corner pieces on
    -- the frame itself.
    if isTexture(frame.TopEdge) and isTexture(frame.LeftEdge) then
        for _,field in ipairs(BORDER_PIECES) do if isTexture(frame[field]) then self:TintArtwork(frame[field],"dialogs") end end
    end
    -- Some windows keep their border in a child frame (the flight map's
    -- BorderFrame, for one): find nine-slice borders two levels down. Only
    -- their edge and corner pieces are touched, never the middle.
    self:DialogBorders(frame,2)
    self.dialogHooked=self.dialogHooked or {}
    if frame.HookScript and not self.dialogHooked[frame] then
        self.dialogHooked[frame]=true
        frame:HookScript("OnShow",function()
            if not FT.dbReady or not self:Settings().dialogs then return end
            FT:Coalesce("dialog"..name,function() self:DialogWindow(frame,name); self:DialogText() end,0)
        end)
    end
end
-- /ft skindebug: every texture the skin changed in the dialog windows that
-- are open now (field name, art, color), to find a piece that looks wrong.
function S:SkinDebug()
    local any=false
    -- The window under the mouse, by name (to find windows the skin misses).
    local focus=(GetMouseFoci and (GetMouseFoci() or {})[1]) or (GetMouseFocus and GetMouseFocus())
    if focus and focus.GetName then
        local chain={}
        local f=focus
        for _=1,8 do if not f or f==UIParent then break end; chain[#chain+1]=tostring(f:GetName() or "(unnamed)"); f=f.GetParent and f:GetParent() end
        print("ForeverTools skin, under the mouse: "..table.concat(chain," < "))
        if focus.GetRegions then
            for _,region in ipairs(regs(focus)) do
                if region.GetObjectType and region:GetObjectType()=="Texture" then
                    local raw=region.GetTexture and region:GetTexture()
                    if issecretvalue and issecretvalue(raw) then raw="?" end
                    local w,h=region:GetSize()
                    local function n(v) if type(v)~="number" or (issecretvalue and issecretvalue(v)) then return "?" end; return tostring(math.floor(v+.5)) end
                    print(string.format("    piece  %s  %s  %s  %sx%s  %s",artName(region),tostring(raw),tostring(region.GetDrawLayer and region:GetDrawLayer()),n(w),n(h),self.artwork[region] and "skinned" or "left alone"))
                end
            end
        end
    end
    -- The top window under the mouse: only that one is reported.
    local topName
    do local f=focus; for _=1,12 do if not f or not f.GetParent then break end; local p=f:GetParent(); if not p or p==UIParent then break end; f=p end
        topName=f and f.GetName and f:GetName() end
    local function inside(region,frame)
        local p=region.GetParent and region:GetParent()
        for _=1,8 do if not p then return false end; if p==frame then return true end; p=p.GetParent and p:GetParent() end
        return false
    end
    local list={}
    for _,name in ipairs(DIALOG_FRAMES) do list[#list+1]=name end
    for _,name in ipairs({"BankFrame","ContainerFrameCombinedBags","ContainerFrame1","MinimapCluster","CalendarFrame","CalendarViewHolidayFrame","CalendarViewEventFrame","CalendarCreateEventFrame","CalendarViewRaidFrame"}) do list[#list+1]=name end
    -- Every game window the Game windows skin knows (friends, group finder...).
    for _,name in ipairs(GAME_FRAMES) do list[#list+1]=name end
    for name in pairs(self:PanelNames()) do list[#list+1]=name end
    if topName then list={topName} end
    for _,name in ipairs(list) do
        local frame=_G[name]
        if frame and frame.IsShown and frame:IsShown() then
            any=true; print("ForeverTools skin, "..name..":")
            local names={}
            local function collect(t,prefix,depth) if depth<0 or type(t)~="table" then return end
                for k,v in pairs(t) do if type(k)=="string" and type(v)=="table" and v~=t and not names[v] then names[v]=prefix..k; if v.GetObjectType and v:GetObjectType()~="Texture" then collect(v,prefix..k..".",depth-1) end end end end
            collect(frame,"",2)
            local count=0
            for texture,record in pairs(self.artwork) do
                if (record.key=="dialogs" or record.key=="bagWindows" or record.key=="minimap" or record.key=="calendar" or record.key=="gameWindows") and inside(texture,frame) and count<40 then
                    count=count+1
                    local r,g,b,a=texture:GetVertexColor()
                    local function n(v) if issecretvalue and issecretvalue(v) then return "?" end; return type(v)=="number" and string.format("%.2f",v) or tostring(v) end
                    print(string.format("  %s  %s  %s  color %s %s %s %s",names[texture] or "(unnamed)",artName(texture),record.parchment and "parchment" or record.tile and "tile" or record.background and "background" or "border",n(r),n(g),n(b),n(a)))
                end
            end
            if count==0 then print("  nothing changed") end
            -- And what it left alone, to find a piece that should match.
            local left=0
            local function scan(f,depth)
                if not f or f==Minimap or depth<0 or left>=25 then return end
                if f.GetRegions then for _,region in ipairs(regs(f)) do
                    if left<25 and region.GetObjectType and region:GetObjectType()=="Texture" and region:IsShown() and not self.artwork[region] then
                        left=left+1
                        if left==1 then print("  left alone:") end
                        local w,h=region:GetSize()
                        local function n(v) if type(v)~="number" or (issecretvalue and issecretvalue(v)) then return "?" end; return tostring(math.floor(v+.5)) end
                        print(string.format("    %s  %s  %sx%s",names[region] or "(unnamed)",artName(region),n(w),n(h)))
                    end
                end end
                if f.GetChildren then for _,child in ipairs(kids(f)) do scan(child,depth-1) end end
            end
            scan(frame,3)
        end
    end
    -- The player frame: its bars and the art around them.
    local content=PlayerFrame and PlayerFrame.PlayerFrameContent
    local main=content and content.PlayerFrameContentMain
    if main then
        any=true; print("ForeverTools skin, PlayerFrame bars:")
        local health=(main.HealthBarsContainer and main.HealthBarsContainer.HealthBar) or main.HealthBar
        local power=(main.ManaBarArea and main.ManaBarArea.ManaBar) or main.ManaBar
        local function n(v) if type(v)~="number" or (issecretvalue and issecretvalue(v)) then return "?" end; return string.format("%.1f",v) end
        for label,bar in pairs({health=health,power=power}) do
            if bar then
                local edge=self.playerEdges and self.playerEdges[bar]
                print(string.format("  %s bar  left %s  width %s  edge %s",label,n(bar:GetLeft()),n(bar:GetWidth()),edge and (edge:IsShown() and "shown" or "hidden") or "none"))
            else print("  "..label.." bar not found") end
        end
        local count=0
        local function scan(f,depth,path)
            if not f or depth<0 or count>=40 then return end
            for _,region in ipairs(regs(f)) do
                if count<40 and region.GetObjectType and region:GetObjectType()=="Texture" and region:IsShown() then
                    count=count+1
                    local w,h=region:GetSize()
                    print(string.format("    %s  %s  %sx%s  left %s  %s",path,artName(region),n(w),n(h),n(region:GetLeft()),self.artwork[region] and "skinned" or "left alone"))
                end
            end
            for key,child in pairs(f) do
                if type(key)=="string" and type(child)=="table" and child~=f and child.GetObjectType and child:GetObjectType()~="Texture" and child.GetRegions and child.GetParent and child:GetParent()==f then scan(child,depth-1,path.."."..key) end
            end
        end
        scan(main,3,"Main")
    end
    if not any then print("ForeverTools: open a dialog window, the bank or your bags first.") end
end
function S:ApplyDialogArtwork()
    if not self:Settings().dialogs and not self.dialogsTouched then return end
    self.dialogsTouched=true
    for _,name in ipairs(DIALOG_FRAMES) do local frame=_G[name]; if frame then self:DialogWindow(frame,name) end end
    self:DialogText()
    -- Pop-ups (destroy an item, sell, confirm ...) are found when they show,
    -- whatever the game names them.
    if not self.popupHooked and hooksecurefunc and StaticPopup_Show then
        self.popupHooked=true
        hooksecurefunc("StaticPopup_Show",function(which)
            if not FT.dbReady or not self:Settings().dialogs then return end
            local dialog=StaticPopup_FindVisible and StaticPopup_FindVisible(which)
            if dialog and dialog.GetObjectType then
                local okN,n=pcall(dialog.GetName,dialog)
                self:DialogWindow(dialog,okN and type(n)=="string" and n or "StaticPopup")
            end
        end)
    end
end
-- With dark parchment, quest and gossip text the game writes in dark brown
-- turns light (titles gold). The game's own colors come back when it is off.
local LIGHT,GOLD={.93,.89,.80},{1,.82,0}
local function recolor(self,frame,depth)
    if not frame or depth<0 then return end
    if frame.GetRegions then for _,region in ipairs(regs(frame)) do
        if region.GetObjectType and region:GetObjectType()=="FontString" and region.GetTextColor then
            local r,g,b,a=region:GetTextColor()
            if type(r)=="number" and type(g)=="number" and type(b)=="number" and not (issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)))
                and math.max(r,g,b)<.4 then
                self.dialogTexts[region]=self.dialogTexts[region] or {r,g,b,a or 1}
                local _,size=region:GetFont()
                local c=(type(size)=="number" and size>=15) and GOLD or LIGHT
                region:SetTextColor(c[1],c[2],c[3],a or 1)
            end
        end
    end end
    if frame.GetChildren then for _,child in ipairs(kids(frame)) do recolor(self,child,depth-1) end end
end
function S:DialogText()
    self.dialogTexts=self.dialogTexts or {}
    local on=self:Settings().dialogs and self:Area("dialogs").darkParchment==true
    if not on then
        for fs,c in pairs(self.dialogTexts) do fs:SetTextColor(c[1],c[2],c[3],c[4]) end
        self.dialogTexts={}
        return
    end
    for name in pairs(PARCHMENT_FRAMES) do local frame=_G[name]; if frame and frame:IsShown() then recolor(self,frame,7) end end
end
-- Calendar (Skins > Windows > Calendar): only its outline goes dark (the
-- frame's border and corner pieces, dark grey, never black). The day tiles,
-- weekday headers, month box, holiday pictures and buttons keep the game's
-- look (Lars: "only outlines and such").
local function regionName(region)
    for _,method in ipairs({"GetName","GetDebugName"}) do
        if region[method] then
            local ok,n=pcall(region[method],region)
            if ok and type(n)=="string" and n~="" and not (issecretvalue and issecretvalue(n)) then return n end
        end
    end
    local p=region.GetParent and region:GetParent()
    if p then for k,v in pairs(p) do if v==region and type(k)=="string" then return k end end end
    return ""
end
local CALENDAR_KEEP={"background","bg","event","holiday","highlight","icon","today","pushed","selected","portrait","flash","glow","day","weekday","month","year","modal","overlay","dark","fill","inset","parchment"}
local CALENDAR_EDGE={"border","edge","corner","top","bottom","left","right"}
-- prefix: the window's own name, taken off first (CalendarViewHolidayFrame
-- has "day" in it). Pop-ups also darken their title box (header).
local function calendarEdge(name,prefix,popup)
    local n=name:lower()
    if prefix and n:sub(1,#prefix)==prefix then n=n:sub(#prefix+1) end
    n=n:gsub("^calendarframe",""):gsub("^calendar","")
    if popup and n:find("header",1,true) and not n:find("text",1,true) then return true end
    for _,word in ipairs(CALENDAR_KEEP) do if n:find(word,1,true) then return false end end
    for _,word in ipairs(CALENDAR_EDGE) do if n:find(word,1,true) then return true end end
    return false
end
-- The calendar's pop-up windows (an event or holiday, a new event, and so on).
local CALENDAR_POPUPS={"CalendarViewHolidayFrame","CalendarViewEventFrame","CalendarCreateEventFrame","CalendarViewRaidFrame","CalendarTexturePickerFrame","CalendarMassInviteFrame","CalendarEventPickerFrame"}
S.CalendarEdge=calendarEdge
function S:CalendarArt()
    local frame=_G.CalendarFrame
    if not frame or forbidden(frame) then return end
    if not self:Settings().calendar and not self.calendarTouched then return end
    self.calendarTouched=true
    local function paint(texture)
        self:TintArtwork(texture,"calendar")
        local record=self.artwork[texture]
        if record and not record.lift then record.lift=.16; self:PaintArtwork(texture,record) end
    end
    local function nineOf(f)
        local nine=isTexture(f.TopEdge) and f or f.NineSlice or f.Border
        if nine and not forbidden(nine) and isTexture(nine.TopEdge) then
            for _,field in ipairs(BORDER_PIECES) do if isTexture(nine[field]) then paint(nine[field]) end end
        end
    end
    local prefix,popup
    local function visit(f,depth)
        if not f or depth<0 or forbidden(f) then return end
        for _,region in ipairs(regs(f)) do
            if isTexture(region) and calendarEdge(regionName(region),prefix,popup) then paint(region) end
        end
        for _,child in ipairs(kids(f)) do
            local kind=child.GetObjectType and child:GetObjectType()
            local name=regionName(child):lower()
            -- Nine-slice borders and plain border frames; never buttons or day tiles.
            if kind~="Button" and kind~="CheckButton" and kind~="EditBox" and kind~="ScrollFrame"
                and not (prefix and name:sub(1,#prefix)~=prefix and name:find("^calendar")) -- pop-ups are done on their own
                and not name:gsub("^"..(prefix or "calendarframe"),""):find("day",1,true) and not name:find("event",1,true) then
                nineOf(child)
                visit(child,depth-1)
            end
        end
    end
    prefix,popup="calendarframe",false
    visit(frame,2); nineOf(frame)
    -- Pop-ups: their border and title box.
    self.calendarHooked=self.calendarHooked or {}
    for _,name in ipairs(CALENDAR_POPUPS) do
        local f=_G[name]
        if f and not forbidden(f) then
            prefix,popup=name:lower(),true
            nineOf(f); visit(f,2)
            if f.HookScript and not self.calendarHooked[f] then
                self.calendarHooked[f]=true
                f:HookScript("OnShow",function() if FT.dbReady and self:Settings().calendar then FT:Coalesce("calendarArt",function() self:CalendarArt() end,0) end end)
            end
        end
    end
    if frame.HookScript and not self.calendarHooked[frame] then
        self.calendarHooked[frame]=true
        frame:HookScript("OnShow",function() if FT.dbReady and self:Settings().calendar then FT:Coalesce("calendarArt",function() self:CalendarArt() end,0) end end)
    end
end
local dialogEvents=CreateFrame("Frame")
for _,event in ipairs({"ADDON_LOADED","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_GREETING","QUEST_ITEM_UPDATE","GOSSIP_SHOW"}) do dialogEvents:RegisterEvent(event) end
dialogEvents:SetScript("OnEvent",function(_,event,addon)
    if not FT.dbReady then return end
    -- The calendar loads on demand too.
    if event=="ADDON_LOADED" and addon=="Blizzard_Calendar" and S:Settings().calendar then FT:Coalesce("calendarArt",function() S:CalendarArt() end,0) end
    -- Talents, the spellbook and other game windows load on demand.
    if event=="ADDON_LOADED" and type(addon)=="string" and addon:find("^Blizzard_") and S:Settings().gameWindows then FT:Coalesce("gameWindows",function() S:ApplyGameWindows() end,0) end
    if not S:Settings().dialogs then return end
    if event=="ADDON_LOADED" then
        -- Trainer and flight map windows load on demand.
        if addon=="Blizzard_TrainerUI" or addon=="Blizzard_FlightMap" then FT:Coalesce("dialogArt",function() S:ApplyDialogArtwork() end,0) end
        return
    end
    -- The game fills the window first; recolor its text right after.
    if S:Area("dialogs").darkParchment then FT:Coalesce("dialogText",function() S:DialogText() end,0) end
end)
function S:ApplyUnitArtwork()
    for _,entry in ipairs({{"PlayerFrame","player"},{"TargetFrame","target"},{"TargetFrameToT","tot"},{"FocusFrame","focus"},{"FocusFrameToT","focustarget"}}) do
        local frame=_G[entry[1]]; local key=entry[2]
        self:TintArtwork(_G[entry[1].."Texture"],key); self:TintArtwork(_G[entry[1].."TextureFrameTexture"],key)
        if frame then
            self:ArtworkFrame(frame,key); self:ArtworkFrame(frame.PlayerFrameContainer,key); self:ArtworkFrame(frame.TargetFrameContainer,key); self:ArtworkFrame(frame.TextureFrame,key)
            -- The game's unit frames (since the 2026-10-16 beta patch) frame
            -- each bar themselves, so our own backing behind the target's
            -- health and the strip on the player's power bar are retired:
            -- the skin only recolors the game's art, same shape and size.
            self:RetireUnitExtras()
            if key=="player" then self:PlayerPowerEdge(frame) end
            local content=frame.PlayerFrameContent or frame.TargetFrameContent
            local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
            if main then self:TintArtwork(main.LevelBackgroundCircle,key); self:TintArtwork(main.PvpBackgroundCircle,key) end
            local contextual=content and (content.TargetFrameContentContextual or content.PlayerFrameContentContextual)
            if contextual then self:TintArtwork(contextual.PvpBackgroundCircle,key);self:TintArtwork(contextual.BossIcon,key) end
        end
    end
    -- Pet frame (hunter and warlock pets, a mage's water elemental, ...)
    -- and the default party frames (not raid-style frames), with their pets.
    self:TintArtwork(PetFrameTexture,"pet")
    local pet=_G.PetFrame
    if pet then
        for _,field in ipairs({"PetFrameTexture","FrameTexture","Texture","TextureFrame"}) do
            local t=pet[field]
            if t and t.GetObjectType and t:GetObjectType()=="Texture" then self:TintArtwork(t,"pet") end
        end
    end
    local party=PartyFrame
    if party then for i=1,4 do local member=party["MemberFrame"..i]; if member then
        self:TintArtwork(member.Texture,"party"); self:TintArtwork(member.VehicleTexture,"party")
        local mp=member.PetFrame; if mp then self:TintArtwork(mp.Texture,"party") end
    end end end
    for i=1,4 do self:TintArtwork(_G["PartyMemberFrame"..i.."PetFrameTexture"],"party") end
    -- Class bars on the player frame (combo points, soul shards, holy power,
    -- runes, ...): their rings and backing take the player frame's look; lit
    -- points keep their colors.
    for _,name in ipairs({"RogueComboPointBarFrame","DruidComboPointBarFrame","ComboPointPlayerFrame","PaladinPowerBarFrame","WarlockPowerFrame","RuneFrame","MageArcaneChargesFrame","MonkHarmonyBarFrame","EssencePlayerFrame"}) do
        local f=_G[name]
        if f and not forbidden(f) then self:ClassPoints(f,"player") end
    end
end
-- Personal resource display: the dark frame behind each bar. Its pieces
-- have no names, so find them once by their artwork.
function S:ApplyPersonalArtwork()
    local frame=PersonalResourceDisplayFrame
    if not frame then return end
    self.personalBars=self.personalBars or {}
    local container=frame.HealthBarsContainer
    for _,bar in ipairs({container and container.healthBar,frame.PowerBar,frame.AlternatePowerBar}) do
        if bar and bar.GetRegions and not self.personalBars[bar] then
            self.personalBars[bar]=true
            for _,region in ipairs(regs(bar)) do
                local atlas=region.GetAtlas and region:GetAtlas()
                if type(atlas)=="string" and not (issecretvalue and issecretvalue(atlas)) and atlas:lower()=="ui-hud-cooldownmanager-bar-bg" then self:TintArtwork(region,"personal") end
            end
        end
    end
    -- Class points (combo points and the like): the gold ring and backing of
    -- each point take the skin; the lit point, its glow and effects keep
    -- their colors.
    if frame.classFrame then self:ClassPoints(frame.classFrame,"personal") end
end
function S:ClassPoints(classFrame,key)
    do
        local function walk(f,depth)
            for _,region in ipairs(regs(f)) do
                if region.GetObjectType and region:GetObjectType()=="Texture" and not self.artwork[region] then
                    local atlas=region.GetAtlas and region:GetAtlas()
                    if type(atlas)=="string" and not (issecretvalue and issecretvalue(atlas)) then
                        local a=atlas:lower()
                        local art=a:find("bg",1,true) or a:find("frame",1,true) or a:find("border",1,true) or a:find("ring",1,true)
                        local lit=a:find("glow",1,true) or a:find("shadow",1,true) or a:find("icon",1,true) or a:find("fx",1,true) or a:find("slash",1,true) or a:find("anima",1,true) and not a:find("dis",1,true)
                        if art and not lit then
                            self:TintArtwork(region,key)
                            local record=self.artwork[region]
                            if record and not record.desaturate then record.desaturate=true; record.lift=.3; self:PaintArtwork(region,record) end
                        end
                    end
                end
            end
            if depth>0 then for _,child in ipairs(kids(f)) do walk(child,depth-1) end end
        end
        walk(classFrame,2)
    end
end
-- Cast bars: yours, your target's and your focus's frame, text box and background.
function S:ApplyCastbarArtwork()
    for _,bar in ipairs({PlayerCastingBarFrame,TargetFrameSpellBar,FocusFrameSpellBar,TargetFrame and TargetFrame.spellbar,FocusFrame and FocusFrame.spellbar,_G.PetCastingBarFrame}) do
        -- Only the outline: the bar's backing and the plate behind the
        -- spell name keep the game's colors, and the outline is a dark tone,
        -- never black, so it keeps its bevel.
        if bar and bar.Border then
            self:TintArtwork(bar.Border,"castbar")
            local record=self.artwork[bar.Border]
            if record and not record.lift then record.lift=.12; self:PaintArtwork(bar.Border,record) end
        end
    end
end
-- Forever's weapon swing timers (main hand, off hand, ranged): the frame
-- around each bar and the backing behind it. The moving fill, the marker
-- and the text keep their own colors.
function S:ApplySwingArtwork()
    for _,name in ipairs({"SwingTimerMainHandFrame","SwingTimerOffHandFrame","SwingTimerRangedFrame"}) do
        local bar=_G[name]
        if bar then self:TintArtwork(bar.Border,"swing"); self:TintArtwork(bar.Background,"swing") end
    end
end
-- Totem bar: the element-colored square frames (earth/fire/water/air) on
-- the multi-cast bar and the round borders on the player totem timers
-- follow the Stance / totem area color, like other stance-bar borders.
-- The action-button frame picture on a button (the gold square outline).
local function iconFrames(button)
    -- The action-button outline (any "...actionbar-iconframe..." art) on the
    -- button or a child of it; never highlights, flashes or masks.
    local out={}
    local function scan(f,depth)
        for _,region in ipairs(regs(f)) do
            if isTexture(region) then
                local a=region.GetAtlas and region:GetAtlas()
                if type(a)=="string" and not (issecretvalue and issecretvalue(a)) then
                    a=a:lower()
                    if a:find("actionbar%-iconframe") and not a:find("highlight",1,true) and not a:find("mouseover",1,true) and not a:find("flash",1,true)
                        and not a:find("mask",1,true) and not a:find("down",1,true) and not a:find("glow",1,true) then out[#out+1]=region end
                end
            end
        end
        if depth>0 then for _,child in ipairs(kids(f)) do scan(child,depth-1) end end
    end
    scan(button,1)
    return out
end
function S:ApplyTotemArtwork()
    for i=1,4 do local slot=_G["MultiCastSlotButton"..i]; if slot then self:TintArtwork(slot.overlayTex,"stances") end end
    for i=1,12 do local button=_G["MultiCastActionButton"..i]; if button then self:TintArtwork(button.overlayTex,"stances") end end
    -- Call of the elements, Totemic recall and the totem buttons: their
    -- action-button outline takes the Stance / totem look.
    local list={_G.MultiCastSummonSpellButton,_G.MultiCastRecallSpellButton}
    for i=1,12 do list[#list+1]=_G["MultiCastActionButton"..i] end
    for i=1,4 do list[#list+1]=_G["MultiCastSlotButton"..i] end
    for _,button in pairs(list) do
        if button then for _,t in ipairs(iconFrames(button)) do self:TintArtwork(t,"stances") end end
    end
    -- Call of the elements and Totemic recall draw their bronze ring with the
    -- old totem bar picture (a file, not an atlas): the ring over the icon.
    for _,button in ipairs({_G.MultiCastSummonSpellButton,_G.MultiCastRecallSpellButton}) do
        if button then
            local bw=button:GetWidth() or 30
            for _,region in ipairs(regs(button)) do
                if isTexture(region) and region.GetDrawLayer and region:GetDrawLayer()=="OVERLAY" then
                    local raw=region.GetTexture and region:GetTexture()
                    local a=region.GetAtlas and region:GetAtlas()
                    local noAtlas=not (type(a)=="string" and a~="") 
                    local w=region:GetWidth()
                    if noAtlas and type(raw)=="number" and not (issecretvalue and issecretvalue(raw)) and raw>0 and (raw==310727 or (type(w)=="number" and w>bw+1)) then self:TintArtwork(region,"stances") end
                end
            end
        end
    end
    if TotemFrame and TotemFrame.GetChildren then
        for _,button in ipairs(kids(TotemFrame)) do self:TintArtwork(button.Border,"stances") end
    end
    -- The totem bar is filled in after login (and when totems are learned):
    -- run again then.
    if not self.totemWatch then
        self.totemWatch=CreateFrame("Frame")
        for _,event in ipairs({"PLAYER_ENTERING_WORLD","UPDATE_MULTI_CAST_ACTIONBAR","LEARNED_SPELL_IN_TAB","SPELLS_CHANGED"}) do pcall(self.totemWatch.RegisterEvent,self.totemWatch,event) end
        self.totemWatch:SetScript("OnEvent",function()
            if not FT.dbReady then return end
            FT:Coalesce("totemArtwork",function() if not InCombatLockdown() then self:ApplyTotemArtwork() end end,1)
        end)
        local bar=_G.MultiCastActionBarFrame
        if bar and bar.HookScript then bar:HookScript("OnShow",function() FT:Coalesce("totemArtwork",function() self:ApplyTotemArtwork() end,0) end) end
    end
end
-- XP / reputation bar dividers only: what changes when the watched
-- reputation or XP bar switches.
function S:ApplyXPArtwork()
    local function xpDecorations(frame,depth)
        if not frame then return end
        for _,field in ipairs({"BarFrameTexture","Tick","TickTexture","Divider","DividerTexture","Separator","SeparatorTexture"}) do self:TintArtwork(frame[field],"xp") end
        for i=1,40 do self:TintArtwork(frame["XpDiv"..i],"xp");self:TintArtwork(frame["Divider"..i],"xp") end
        if frame.GetRegions then
            for _,region in ipairs(regs(frame)) do
                if region.GetObjectType and region:GetObjectType()=="Texture" then
                    local name=region.GetName and region:GetName() or ""
                    local art=region.GetAtlas and region:GetAtlas() or region.GetTexture and region:GetTexture() or ""
                    local id=(type(name)=="string" and name or "").." "..(type(art)=="string" and art or "")
                    id=id:lower()
                    if id:find("divider",1,true) or id:find("separator",1,true) or id:find("xpdiv",1,true) or id:find("tick",1,true) then self:TintArtwork(region,"xp") end
                end
            end
        end
        if depth>0 and frame.GetChildren then for _,child in ipairs(kids(frame)) do xpDecorations(child,depth-1) end end
    end
    for _,name in ipairs({"MainStatusTrackingBarContainer","SecondaryStatusTrackingBarContainer","StatusTrackingBarManager","MainMenuExpBar"}) do
        xpDecorations(_G[name],2)
    end
end
-- The day/night icon on the minimap: its ring follows the Minimap area, the
-- sun or moon inside keeps its colors. Blizzard gives the ring no name, so it
-- is found by its art, or else as the frame's texture that isn't the Background.
local DIEL_RING="UI-HUD-Minimap-Frame-Cycle"
function S:DielRing()
    if self.dielRing then return self.dielRing end
    local frame=MinimapCluster and MinimapCluster.DielFrame
    if not frame or not frame.GetRegions then return end
    local other
    for _,region in ipairs(regs(frame)) do
        if region~=frame.Background and type(region.GetVertexColor)=="function" then
            local atlas=region.GetAtlas and region:GetAtlas()
            if issecretvalue and issecretvalue(atlas) then atlas=nil end
            if type(atlas)=="string" and atlas:lower()==DIEL_RING:lower() then self.dielRing=region; return region end
            other=other or region
        end
    end
    self.dielRing=other
    return other
end
-- Minimap buttons drawn as one picture (gold frame and icon together). The
-- picture itself goes dark like every other border; a second copy of the
-- same picture, cut to the part inside the gold frame, lies exactly over it
-- at the same size and place. So the icon is the original art, untouched
-- and not zoomed, and only the outer frame is dark.
S.minimapRims=S.minimapRims or {}
local FRAME=.13
function S:MinimapButtonRim(texture)
    local rec=self.minimapRims[texture]
    local parent=texture.GetParent and texture:GetParent()
    if not rec then
        if not parent or not parent.CreateTexture or not texture.GetTexCoord then return end
        rec={}
        -- Above the picture (and the button's other art), below its text.
        rec.inner=parent:CreateTexture(nil,"OVERLAY",nil,-8)
        -- Rounded corners: the copy's square corners held a little of the
        -- bronze rim (the rim is round).
        if parent.CreateMaskTexture and rec.inner.AddMaskTexture then
            rec.mask=parent:CreateMaskTexture()
            rec.mask:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
            rec.mask:SetAllPoints(rec.inner); rec.inner:AddMaskTexture(rec.mask)
        end
        self.minimapRims[texture]=rec
        if hooksecurefunc then
            for _,method in ipairs({"SetAtlas","SetTexture","SetTexCoord"}) do
                if texture[method] then hooksecurefunc(texture,method,function() if not rec.setting then rec.key=nil; if FT.dbReady then self:MinimapButtonRim(texture) end end end) end
            end
            for _,method in ipairs({"Show","Hide","SetShown"}) do if texture[method] then hooksecurefunc(texture,method,function() if rec.inner then rec.inner:SetShown(rec.on and texture:IsShown()) end end) end end
        end
    end
    local s=self:Area("minimap")
    rec.on=s.minimap and true or false
    -- The addon list button shows a number (text), not a picture: its whole
    -- art takes the dark frame look, no copy needed.
    if parent==_G.AddonCompartmentFrame then
        self:TintArtwork(texture,"minimap")
        local record=self.artwork[texture]
        if record and not record.lift then record.desaturate=true; record.lift=.12; self:PaintArtwork(texture,record) end
        rec.inner:Hide(); return
    end
    -- The picture: its atlas, looked up in the game's atlas list (file and
    -- the exact part of it), so the copy is the same art at the same scale.
    local atlas=texture.GetAtlas and texture:GetAtlas()
    local info=type(atlas)=="string" and not (issecretvalue and issecretvalue(atlas)) and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if type(info)~="table" or not info.file or type(info.leftTexCoord)~="number" then
        -- Can't copy the picture: leave the button as the game draws it.
        local record=self.artwork[texture]
        if record then self.artwork[texture]=nil; texture:SetDesaturated(false); texture:SetVertexColor(unpack(record.original)) end
        rec.on=false; rec.inner:Hide(); return
    end
    if rec.key~=atlas then
        rec.key=atlas
        rec.inner:SetTexture(info.file)
        local l,rt,tp,bt=info.leftTexCoord,info.rightTexCoord,info.topTexCoord,info.bottomTexCoord
        local dx,dy=(rt-l)*FRAME,(bt-tp)*FRAME
        rec.inner:SetTexCoord(l+dx,rt-dx,tp+dy,bt-dy)
    end
    local w,hh=texture:GetSize()
    if type(w)=="number" and type(hh)=="number" and not (issecretvalue and (issecretvalue(w) or issecretvalue(hh))) and (rec.w~=w or rec.h~=hh) then
        rec.w,rec.h=w,hh
        rec.inner:ClearAllPoints()
        rec.inner:SetPoint("TOPLEFT",texture,"TOPLEFT",w*FRAME,-hh*FRAME); rec.inner:SetPoint("BOTTOMRIGHT",texture,"BOTTOMRIGHT",-w*FRAME,hh*FRAME)
    end
    -- The picture underneath goes dark (frame); the copy keeps the colors.
    self:TintArtwork(texture,"minimap")
    local record=self.artwork[texture]
    if record and not record.desaturate then record.desaturate=true; self:PaintArtwork(texture,record) end
    rec.inner:SetShown(rec.on and texture:IsShown())
end
-- The bag bar's background and divider art (the dividers are pooled and
-- handed out again on each redraw).
function S:BagBarArt()
    if not BagsBar then return end
    if BagsBar.GetRegions then
        local width=BagsBar.GetWidth and BagsBar:GetWidth() or 0
        for _,region in ipairs(regs(BagsBar)) do
            if region.GetObjectType and region:GetObjectType()=="Texture" and region.GetWidth
                and width>0 and region:GetWidth()>=width*.6 then self:TintArtwork(region,"bags",true) end
        end
    end
    for _,field in ipairs({"HorizontalDividersPool","VerticalDividersPool"}) do
        local pool=BagsBar[field]
        if pool and pool.EnumerateActive then
            for divider in pool:EnumerateActive() do
                if divider.GetRegions then
                    for _,texture in ipairs(regs(divider)) do self:TintArtwork(texture,"bags",true) end
                end
            end
        end
    end
end
function S:ApplyArtwork()
    self:ApplyBagWindows();self:ApplyGryphons();self:ApplyActionBarArt()
    self:ApplyTotemArtwork()
    self:TintArtwork(MinimapCompassTexture,"minimap"); self:TintArtwork(MinimapCompassTextureUnderlay,"minimap"); self:TintArtwork(MinimapBorder,"minimap")
    if MinimapCluster then self:ArtworkFrame(MinimapCluster.BorderTop,"minimap") end
    -- The zone name box above the minimap: a nine-slice in the game's newer
    -- art (gold edges and corners). Its pieces are greyed, then take the
    -- border color; the dark middle stays as it is.
    -- Other header art around the zone box (the game's newer minimap uses
    -- nine-slice pieces named after its texture kit): any texture in the
    -- minimap cluster whose art is a nine-slice, border or header piece.
    -- The map itself, its pins and the buttons' icons are left alone.
    if MinimapCluster then
        local map=Minimap
        local function header(f,depth)
            if not f or f==map or depth<0 then return end
            for _,region in ipairs(regs(f)) do
                if isTexture(region) and (not self.artwork[region] or self.minimapRims[region]) then
                    local atlas=region.GetAtlas and region:GetAtlas()
                    if type(atlas)=="string" and not (issecretvalue and issecretvalue(atlas)) then
                        local a=atlas:lower()
                        local piece=a:find("nineslice",1,true) or a:find("minimap-button",1,true) or (a:find("minimap",1,true) and (a:find("border",1,true) or a:find("header",1,true) or a:find("zone",1,true) or a:find("edge",1,true) or a:find("corner",1,true) or a:find("frame",1,true)))
                        local skip=a:find("icon",1,true) or a:find("glow",1,true) or a:find("highlight",1,true) or a:find("mouseover",1,true) or a:find("center",1,true) or a:find("background",1,true)
                        -- Whole-button art (frame and icon in one picture): the icon
                        -- keeps its colors; a thin frame in the border color is
                        -- drawn over the picture's gold edge instead.
                        local button=a:find("minimap",1,true) and (a:find("tracking-button",1,true) or a:find("calendar-button",1,true) or a:find("addon-indicator",1,true))
                        if button then self:MinimapButtonRim(region)
                        elseif piece and not skip then
                            self:TintArtwork(region,"minimap")
                            local record=self.artwork[region]
                            if record and not record.desaturate then record.desaturate=true; self:PaintArtwork(region,record) end
                        end
                    end
                end
            end
            for _,child in ipairs(kids(f)) do header(child,depth-1) end
        end
        header(MinimapCluster,3)
        -- The buttons beside the zone box (tracking, addons) can sit outside
        -- the cluster.
        header(AddonCompartmentFrame,2); header(GameTimeFrame,1)
        -- The addon list button's own art, whatever its picture is called.
        local comp=_G.AddonCompartmentFrame
        if comp and not forbidden(comp) then
            local hl=comp.GetHighlightTexture and comp:GetHighlightTexture()
            for _,region in ipairs(regs(comp)) do
                if isTexture(region) and region~=hl and region:GetDrawLayer()~="HIGHLIGHT" then self:MinimapButtonRim(region) end
            end
        end
        if MinimapCluster.Tracking then header(MinimapCluster.Tracking,2) end
    end
    local top=MinimapCluster and MinimapCluster.BorderTop
    if top then
        local pieces={}
        for _,field in ipairs(BORDER_PIECES) do if isTexture(top[field]) then pieces[top[field]]=true end end
        if top.NineSlice then for _,field in ipairs(BORDER_PIECES) do if isTexture(top.NineSlice[field]) then pieces[top.NineSlice[field]]=true end end end
        for _,region in ipairs(regs(top)) do if isTexture(region) and region~=top.Center and region~=top.Background then pieces[region]=true end end
        for texture in pairs(pieces) do
            self:TintArtwork(texture,"minimap")
            local record=self.artwork[texture]
            if record and not record.desaturate then record.desaturate=true; self:PaintArtwork(texture,record) end
        end
    end
    -- Addon minimap buttons (ForeverTools' own and other addons'): their
    -- gold ring goes dark only with "Addon button rings: Dark".
    self:AddonRings()
    -- Addons make their minimap buttons a little after login.
    if not self.ringsLater then self.ringsLater=true; C_Timer.After(5,function() if FT.dbReady then self:AddonRings() end end) end
    -- The ring is gold: grey it first so it takes the area's color cleanly.
    local ring=self:DielRing()
    if ring then
        self:TintArtwork(ring,"minimap")
        local record=self.artwork[ring]
        if record and not record.desaturate then record.desaturate=true; self:PaintArtwork(ring,record) end
    end
    self:ArtworkFrame(MicroMenu,"micro",true); self:ArtworkFrame(BagsBar,"bags",true); self:ArtworkFrame(MainMenuBarBackpackButton,"bags")
    -- The long bar behind the micro buttons is a region on MicroMenu in some
    -- client builds, rather than one of its named border fields.
    if MicroMenu then
        for _,field in ipairs({"Background","BackgroundTexture","Border","BorderTexture","Texture"}) do self:TintArtwork(MicroMenu[field],"micro",true) end
        if MicroMenu.GetRegions then
            local width=MicroMenu.GetWidth and MicroMenu:GetWidth() or 0
            for _,region in ipairs(regs(MicroMenu)) do
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
    if MicroMenu and MicroMenu.GetChildren then for _,button in ipairs(kids(MicroMenu)) do microButtons[button]=true end end
    for button in pairs(microButtons) do
        if button then self:ArtworkFrame(button,"micro"); self:TintArtwork(button.Background,"micro"); self:TintArtwork(button.PushedBackground,"micro")
            if button.GetRegions then for _,region in ipairs(regs(button)) do
                local atlas=region.GetAtlas and region:GetAtlas()
                if type(atlas)=="string" and (atlas:lower():find("buttonbg",1,true) or atlas:lower():find("iconframe",1,true)) then self:TintArtwork(region,"micro") end
            end end
        end
    end
    self:BagBarArt()
    if BagsBar and not self.bagLayoutHooked and hooksecurefunc and BagsBar.UpdateDividers then
        -- The game redraws the bag bar's dividers whenever an item is picked
        -- up or put down: redo only the bag bar's own art then (redoing all
        -- art took ~200 ms and made dragging items stutter).
        self.bagLayoutHooked=true;hooksecurefunc(BagsBar,"UpdateDividers",function() if FT.dbReady then FT:Coalesce("bagBarArt",function() if not FT:LooksWait() then self:BagBarArt() end end,.1) end end)
    end
    local bagButtons={}
    -- Every bag bar button: backpack, bags, the reagent bag and the key ring
    -- (always both of those too), by name and as children of the bag bar.
    for _,name in ipairs({"MainMenuBarBackpackButton","KeyRingButton","MainMenuBarKeyRingButton","KeyRingFrame","CharacterReagentBag0Slot","ReagentBagSlot","CharacterReagentBag1Slot"}) do
        if _G[name] then bagButtons[_G[name]]=true end
    end
    for i=0,5 do local button=_G["CharacterBag"..i.."Slot"]; if button then bagButtons[button]=true end end
    if BagsBar then
        for _,child in ipairs(kids(BagsBar)) do
            -- Bag slots are item buttons or check buttons, not only plain buttons.
            if child.GetNormalTexture and (child.icon or child.Icon or child.IconTexture) then bagButtons[child]=true end
        end
    end
    for button in pairs(bagButtons) do
        if button then
            self:ArtworkFrame(button,"bags")
            if button.GetNormalTexture then self:TintArtwork(button:GetNormalTexture(),"bags") end
            for _,field in ipairs({"Background","BackgroundTexture","SlotBackground","SlotBackgroundTexture"}) do self:BagBackdrop(button[field]) end
            for _,field in ipairs({"BorderTexture","SlotBorder","IconBorder"}) do self:TintArtwork(button[field],"bags") end
            if button.GetRegions then for _,region in ipairs(regs(button)) do
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
            if button.GetHighlightTexture then self:TintArtwork(button:GetHighlightTexture(),"bags"); local h=self.artwork[button:GetHighlightTexture()]; if h then h.highlight=true end end
            self:TintArtwork(button.SlotHighlightTexture,"bags"); if button.SlotHighlightTexture and self.artwork[button.SlotHighlightTexture] then self.artwork[button.SlotHighlightTexture].highlight=true end
        end
    end
    self:ApplyUnitArtwork()
    self:ApplyPersonalArtwork()
    self:ApplyCastbarArtwork()
    self:ApplySwingArtwork()
    self:ApplyXPArtwork()
    self:ApplyTooltipArtwork()
    self:ApplyDialogArtwork()
    self:ApplyGameWindows()
    self:CalendarArt()
    for texture,record in pairs(self.artwork) do self:PaintArtwork(texture,record) end
end
-- PvP windows (Skins > PvP): the Nearby enemies list, the enemy alert, the
-- battleground timer and the trinket menu. Each module hands its panel and
-- its own colors here every time it paints; with the part's skin on, the
-- panel takes the skin's background and border instead. Plain textures and
-- backdrops only, so this is safe in combat.
-- opts.semantic: the border means something (a marked player's red alert)
-- and keeps its color.
S.pvpPanels=S.pvpPanels or {}
local function backdropColors(frame)
    local fill,border={0,0,0,.8},{1,1,1,1}
    if frame.GetBackdropColor then local ok,r,g,b,a=pcall(frame.GetBackdropColor,frame); if ok and type(r)=="number" then fill={r,g,b,a or 1} end end
    if frame.GetBackdropBorderColor then local ok,r,g,b,a=pcall(frame.GetBackdropBorderColor,frame); if ok and type(r)=="number" then border={r,g,b,a or 1} end end
    return fill,border
end
function S:SkinPanel(frame,key,fill,border,opts)
    if not frame then return end
    local look=self.pvpPanels[frame]
    if not look then
        look={key=key}; self.pvpPanels[frame]=look
        if not frame.fillTextures and not fill then look.fill,look.border=backdropColors(frame) end
    end
    if key then look.key=key end
    if fill then look.fill=fill end
    if border then look.border=border end
    if opts then look.semantic=opts.semantic end
    local on=FT.dbReady and self:Settings()[look.key]==true
    local s=on and self:Area(look.key)
    local newFill,newBorder=look.fill,look.border
    if on then
        -- Never a hole: the background keeps at least a little body.
        local c,bc=s.color,s.borderColor
        newFill={math.max(c[1],.025),math.max(c[2],.025),math.max(c[3],.03),math.max(.35,s.opacity)}
        newBorder=look.semantic and look.border or {bc[1],bc[2],bc[3],s.borderOpacity}
    end
    if frame.fillTextures then
        FT:Paint(frame,newFill,newBorder)
        -- Notices normally wear the game's damage meter header; a skinned
        -- one shows our rounded panel in your colors instead.
        local meter=frame.meterSkinned and not on
        for _,t in ipairs(frame.fillTextures) do t:SetAlpha(meter and 0 or 1) end
        for _,t in ipairs(frame.borderTextures or {}) do t:SetAlpha(meter and 0 or 1) end
        for _,field in ipairs({"meterHeader","meterBody","meterShade"}) do if frame[field] then frame[field]:SetShown(not on) end end
    elseif newFill then
        if frame.SetBackdropColor then pcall(frame.SetBackdropColor,frame,unpack(newFill)) end
        if frame.SetBackdropBorderColor then pcall(frame.SetBackdropBorderColor,frame,unpack(newBorder)) end
    end
end
function S:ApplyPvp()
    for frame in pairs(self.pvpPanels) do self:SkinPanel(frame) end
    local trinkets=FT.modules.Trinkets
    if trinkets and trinkets.PaintSkin then trinkets:PaintSkin() end
    -- Our bars repaint their rows with the new look on their next paint.
    self.skinVersion=(self.skinVersion or 0)+1
    for _,name in ipairs({"Interrupts","EnemyCooldowns"}) do
        local m=FT.modules[name]
        if m and m.bar and m.bar:IsShown() and m.Paint then pcall(m.Paint,m) end
    end
    self:ApplyMeters()
    -- Meters again a moment later: the game's damage meter and our threat
    -- meter can redo their art right after a change (first switch-on).
    if self.metersTouched then
        FT:Coalesce("meterSkinsAgain",function() self.skinVersion=(self.skinVersion or 0)+1; self:ApplyMeters() end,.3)
        FT:Coalesce("meterSkinsLate",function() self:ApplyMeters() end,1.2)
    end
end
-- Meters (Skins > Notices & meters > Meters): the game's damage meter and
-- our threat meter. Only header and background art, found by its art name,
-- takes the look; bars, names, numbers and buttons are left alone. A
-- texture's color is kept and put back (TintArtwork), so this is safe in
-- fights and when the part is turned off.
local function meterArtKind(texture)
    local name=texture.GetAtlas and texture:GetAtlas()
    if type(name)~="string" or (issecretvalue and issecretvalue(name)) then return end
    name=name:lower()
    if not name:find("damagemeter",1,true) or name:find("scalehandle",1,true) then return end
    if name:find("header",1,true) or name:find("border",1,true) or name:find("frame",1,true) or name:find("edge",1,true) then return "edge" end
    if name:find("bar",1,true) then return end -- the bars themselves
    if name:find("background",1,true) then return "background" end
end
function S:MeterTexture(texture)
    if not texture or not texture.GetAtlas then return end
    local kind=meterArtKind(texture); if not kind then return end
    self:TintArtwork(texture,"meters")
    local record=self.artwork[texture]; if not record then return end
    -- Never pure black: the header keeps its shape.
    if kind=="background" then record.background=true else record.lift=.12 end
    self:PaintArtwork(texture,record)
end
-- Rings of addon minimap buttons: on the minimap and in the grouped menu.
-- Three choices (Skins > Minimap & menus): the ForeverTools button, the
-- grouped buttons' gear, and other addons' buttons (on the minimap and in
-- the group). Each keeps the game's gold ring unless set to Dark.
-- The gold ring of an addon button: its ring or border field, or the
-- texture showing the game's tracking border (by file id or name).
local RING_FILE=136430
local function ringOf(button)
    local r=button.ring or button.border or button.Border
    if isTexture(r) then return r end
    for _,region in ipairs(regs(button)) do
        if isTexture(region) then
            local t=region.GetTexture and region:GetTexture()
            if not (issecretvalue and issecretvalue(t)) and (t==RING_FILE or (type(t)=="string" and t:lower():find("trackingborder",1,true))) then return region end
        end
    end
end
function S:AddonRing(button,choice)
    if not button or forbidden(button) then return end
    local r=ringOf(button)
    if not r then return end
    self:TintArtwork(r,"minimap")
    local record=self.artwork[r]
    if record and record.ringChoice~=choice then record.ringChoice=choice; record.desaturate=true; self:PaintArtwork(r,record) end
end
function S:AddonRings()
    local ft,gear=_G.ForeverToolsMinimapButton,_G.ForeverToolsMinimapIcons
    self:AddonRing(ft,"addonRings"); self:AddonRing(gear,"gearRing")
    if Minimap then for _,c in ipairs(kids(Minimap)) do if c~=ft and c~=gear and c.GetObjectType and c:GetObjectType()=="Button" then self:AddonRing(c,"addonRings") end end end
    local icons=FT.modules.MinimapIcons
    if icons and icons.records then for button in pairs(icons.records) do if button~=ft and button~=gear then self:AddonRing(button,"addonRings") end end end
end
-- A header button's art (collapse, settings): a dark tone, never black.
function S:MeterButton(button)
    if not button or not button.GetNormalTexture or forbidden(button) then return end
    for _,get in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture"}) do
        local ok,t=pcall(button[get],button)
        if ok and t and t.GetVertexColor then
            self:TintArtwork(t,"meters")
            local record=self.artwork[t]
            if record and not record.lift then record.lift=.38; self:PaintArtwork(t,record) end
        end
    end
end
-- Our threat meter: its header, background and buttons, like the game's
-- damage meter. Redone when the look changes (checked as it updates).
function S:SkinThreat(meter)
    if not meter then return end
    meter.ftSkin=self.skinVersion or 0
    if not self:Settings().meters and not self.metersTouched then return end
    self.metersTouched=true
    self:MeterTexture(meter.header); self:MeterTexture(meter.body)
    -- Like the damage meter: the collapse button goes dark, the gear keeps
    -- its colors.
    self:MeterButton(meter.hide)
    -- The background picture fades out towards the top: with the skin on,
    -- an even fill in your background color sits under it (like the damage
    -- meter's body).
    -- Retired: the background now starts under the header like the damage
    -- meter's, so no extra fill (it made the header look patchy).
    local on=false
    if on and not meter.ftSolid and meter.body then
        meter.ftSolid=meter:CreateTexture(nil,"BACKGROUND",nil,-8); meter.ftSolid:SetTexture("Interface\\Buttons\\WHITE8x8")
        meter.ftSolid:SetAllPoints(meter.body)
    end
    if meter.ftSolid then
        local s=self:Area("meters"); local c=s.color
        meter.ftSolid:SetVertexColor(c[1],c[2],c[3],math.max(.35,s.opacity or 1)*.85)
        meter.ftSolid:SetShown(on and meter.body and meter.body:IsShown() and true or false)
    end
end
function S:ApplyMeters()
    if not FT.dbReady then return end
    -- Nothing to do until the part has been turned on once.
    if not self:Settings().meters and not self.metersTouched then return end
    self.metersTouched=true
    local threat=FT.modules.Threat
    self:SkinThreat(threat and threat.meter)
    for i=1,3 do
        local w=_G["DamageMeterSessionWindow"..i]
        if w and not forbidden(w) then
            for _,r in ipairs(regs(w)) do self:MeterTexture(r) end
            local box=w.MinimizeContainer and w.MinimizeContainer.ScrollBox
            for _,c in ipairs(kids(w)) do
                if c~=box and not (c.GetObjectType and c:GetObjectType()=="StatusBar") then
                    for _,r in ipairs(regs(c)) do self:MeterTexture(r) end
                    if c.GetObjectType and c:GetObjectType()=="Button" then self:MeterButton(c) end
                    -- Buttons in the header (collapse, settings, session).
                    for _,b in ipairs(kids(c)) do if b.GetObjectType and b:GetObjectType()=="Button" then self:MeterButton(b) end end
                end
            end
        end
    end
    -- Extra damage meter windows are made when you open them.
    if not self.meterHooked and DamageMeter and DamageMeter.SetupSessionWindow and hooksecurefunc then
        self.meterHooked=true
        hooksecurefunc(DamageMeter,"SetupSessionWindow",function() FT:Coalesce("meterSkins",function() S:ApplyMeters() end,.1) end)
    end
end
-- Bars (Skins > Notices & meters > Bars): rows of the interrupt bar and the
-- enemy cooldown bar. Each row gets the look's background and a thin border;
-- off, the row's own color comes back. Repainted only when the look changes.
function S:BarRow(row,back)
    local version=self.skinVersion or 0
    local on=FT.dbReady and self:Settings().ftBars==true
    if row.ftSkin==version and row.ftSkinOn==on then return end
    row.ftSkin=version; row.ftSkinOn=on
    local s=on and self:Area("ftBars")
    if not row.ftEdges then
        row.ftEdges={}
        for i=1,4 do local t=row:CreateTexture(nil,"BORDER"); t:SetTexture("Interface\\Buttons\\WHITE8x8"); t:Hide(); row.ftEdges[i]=t end
    end
    if on then
        local c,bc=s.color,s.borderColor
        row.back:SetColorTexture(math.max(c[1],.025),math.max(c[2],.025),math.max(c[3],.03),math.max(.35,s.opacity))
        local w=math.max(1,math.min(3,tonumber(s.thickness) or 1))
        local e=row.ftEdges
        e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(w)
        e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(w)
        e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(w)
        e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(w)
        for _,t in ipairs(e) do t:SetVertexColor(bc[1],bc[2],bc[3],s.borderOpacity or 1); t:Show() end
    else
        row.back:SetColorTexture(back[1],back[2],back[3],back[4])
        for _,t in ipairs(row.ftEdges) do t:Hide() end
    end
end
-- An icon's border on those bars: the look's border color, or plain black.
function S:BarIcon(b)
    local version=self.skinVersion or 0
    local on=FT.dbReady and self:Settings().ftBars==true
    if b.ftSkin==version and b.ftSkinOn==on then return end
    b.ftSkin=version; b.ftSkinOn=on
    if on then local s=self:Area("ftBars"); local bc=s.borderColor; b.border:SetVertexColor(bc[1],bc[2],bc[3],s.borderOpacity or 1)
    else b.border:SetVertexColor(0,0,0,.85) end
end
local apply=S.Apply
function S:Apply()
    apply(self)
    if FT.dbReady and not FT:LooksWait() then self:ApplyArtwork() end
    if FT.dbReady then self:ApplyPvp() end
end

local artworkEvents=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_TARGET_CHANGED","PLAYER_FOCUS_CHANGED","UNIT_TARGET","UNIT_CLASSIFICATION_CHANGED","UPDATE_EXPANSION_LEVEL","UPDATE_FACTION","BAG_UPDATE_DELAYED","GROUP_ROSTER_UPDATE","UNIT_PET"}) do artworkEvents:RegisterEvent(event) end
-- Unit events for other units (party, nameplates) do not change our artwork.
local artworkUnits={player=true,target=true,focus=true,targettarget=true,focustarget=true}
-- Each event only redoes the art it can change, once, out of combat (the
-- end of combat redoes everything anyway).
artworkEvents:SetScript("OnEvent",function(_,event,unit)
    if (event=="UNIT_TARGET" or event=="UNIT_CLASSIFICATION_CHANGED" or event=="UNIT_PET") and not artworkUnits[unit] then return end
    if not FT.dbReady or FT:LooksWait() then return end
    -- Open bag windows redo themselves when their items update (hooked above).
    if event=="BAG_UPDATE_DELAYED" then return
    elseif event=="UPDATE_FACTION" or event=="UPDATE_EXPANSION_LEVEL" then
        -- Reputation changes often (every kill for some factions). Repaint the
        -- XP bar art we know; look for new dividers at most every 30 seconds.
        if S:Settings().xp then FT:Coalesce("xpArt",function()
            if FT:LooksWait() then return end
            local now=GetTime()
            if not S.xpScanned or now-S.xpScanned>=30 then S.xpScanned=now; S:ApplyXPArtwork()
            else for texture,record in pairs(S.artwork) do if record.key=="xp" then S:PaintArtwork(texture,record) end end end
        end,.5) end
    else
        local s=S:Settings()
        if s.player or s.target or s.tot or s.focus or s.focustarget or s.pet or s.party then FT:Coalesce("unitArt",function() if not FT:LooksWait() then S:ApplyUnitArtwork() end end) end
    end
end)
