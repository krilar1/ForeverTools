local _,FT=...
local Icons={records={},elapsed=0}
local excluded={Minimap=true,MinimapBackdrop=true,MinimapCluster=true,MiniMapTracking=true,
    MiniMapTrackingButton=true,MinimapZoomIn=true,MinimapZoomOut=true,MiniMapWorldMapButton=true,
    GameTimeFrame=true,TimeManagerClockButton=true,QueueStatusMinimapButton=true,
    ExpansionLandingPageMinimapButton=true,MiniMapMailFrame=true,MiniMapBattlefieldFrame=true}
local function protected(button)
    return button.IsProtected and button:IsProtected()
end
function Icons:Enabled()
    return FT.modules.System:Settings().minimapIcons==true
end
function Icons:PositionLauncher()
    if not self.launcher or not Minimap or InCombatLockdown() then return end
    local angle=tonumber(FT.db.minimapCollectorAngle) or 45
    if angle~=angle then angle=45 end
    local x,y=math.cos(math.rad(angle)),math.sin(math.rad(angle))
    if GetMinimapShape and GetMinimapShape()=="SQUARE" then
        local scale=math.max(math.abs(x),math.abs(y));x,y=x/scale,y/scale
    end
    self.launcher:ClearAllPoints()
    self.launcher:SetPoint("CENTER",Minimap,"CENTER",x*(Minimap:GetWidth()/2+4),y*(Minimap:GetHeight()/2+4))
end
function Icons:DragLauncher()
    if not self.dragging or InCombatLockdown() then return end
    local x,y=GetCursorPosition();local cx,cy=Minimap:GetCenter()
    if not cx or not cy then return end
    local scale=Minimap:GetEffectiveScale()
    FT.db.minimapCollectorAngle=math.deg(math.atan2((y/scale-cy)/Minimap:GetHeight(),(x/scale-cx)/Minimap:GetWidth()))
    self:PositionLauncher()
end
function Icons:BrightIcon(button,record)
    if not record.active then return end
    local icon=button.icon or button.Icon
    if icon and icon.GetVertexColor and icon.SetVertexColor then
        if not record.iconStyle or record.iconStyle.texture~=icon then
            record.iconStyle={texture=icon,color={icon:GetVertexColor()},alpha=icon:GetAlpha(),
                desaturated=icon.IsDesaturated and icon:IsDesaturated()}
        end
        icon:SetVertexColor(1,1,1,1);icon:SetAlpha(1)
        if icon.SetDesaturated then icon:SetDesaturated(false) end
    end
    if record.alpha==nil then record.alpha=button:GetAlpha() end
    button:SetAlpha(1)
end
-- The menu fades in, stays while the mouse is on it (or on its icon), and
-- closes by itself a few seconds after the mouse has left.
local IDLE,FADE_IN,FADE_OUT=3,.18,.25
function Icons:OpenMenu()
    local panel=self.panel
    if not panel then return end
    self:Scan();self:Layout()
    panel.idle=0;panel.closing=false;panel.opening=true
    panel:SetAlpha(0);panel:Show()
end
function Icons:CloseMenu(now)
    local panel=self.panel
    if not panel or not panel:IsShown() then return end
    if now then panel.closing=false;panel.opening=false;panel:Hide();panel:SetAlpha(1);return end
    panel.closing=true;panel.opening=false
end
function Icons:MenuUpdate(dt)
    local panel=self.panel
    local over=panel:IsMouseOver() or (self.launcher and self.launcher:IsMouseOver())
    if over then
        panel.idle=0
        -- Coming back while it fades away keeps it open.
        if panel.closing then panel.closing=false;panel.opening=true end
    else
        panel.idle=(panel.idle or 0)+dt
        if panel.idle>=IDLE and not panel.closing then self:CloseMenu() end
    end
    if panel.closing then
        local alpha=panel:GetAlpha()-dt/FADE_OUT
        if alpha<=0 then self:CloseMenu(true) else panel:SetAlpha(alpha) end
    elseif panel.opening then
        local alpha=panel:GetAlpha()+dt/FADE_IN
        if alpha>=1 then alpha=1;panel.opening=false end
        panel:SetAlpha(alpha)
    end
end
function Icons:Vertical()
    return FT.modules.System:Settings().minimapIconsVertical==true
end
function Icons:Create()
    if self.launcher or not Minimap then return end
    local button=CreateFrame("Button","ForeverToolsMinimapIcons",Minimap);self.launcher=button
    button:SetSize(32,32);self:PositionLauncher()
    button:RegisterForDrag("LeftButton")
    if button.SetDontSavePosition then button:SetDontSavePosition(true) end
    button:SetFrameLevel(Minimap:GetFrameLevel()+12);button:RegisterForClicks("LeftButtonUp")
    local icon=button:CreateTexture(nil,"ARTWORK");icon:SetSize(21,21);icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
    local ring=button:CreateTexture(nil,"OVERLAY");ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetTexCoord(0,.625,0,.625);ring:SetSize(34,34);ring:SetPoint("CENTER",button,"CENTER",0,0);ring:SetVertexColor(.08,.08,.08)
    local panel=CreateFrame("Frame","ForeverToolsMinimapIconMenu",UIParent);self.panel=panel
    panel:SetFrameStrata("DIALOG");panel:SetClampedToScreen(true);panel:EnableMouse(true)
    panel:SetPoint("TOPRIGHT",button,"BOTTOMRIGHT",0,-8);panel:Hide()
    FT:RoundedFill(panel,.025,.025,.03,.96)
    self.empty=FT:Label(panel,"No addon icons available",12);self.empty:SetPoint("CENTER")
    panel:SetScript("OnUpdate",function(_,dt) self:MenuUpdate(dt) end)
    button:SetScript("OnDragStart",function()
        if InCombatLockdown() then return end
        self.dragging=true;panel:Hide();if GameTooltip then GameTooltip:Hide() end
        self:DragLauncher()
    end)
    button:SetScript("OnDragStop",function()
        self:DragLauncher();self.dragging=false;self.skipClick=true
        C_Timer.After(0,function() self.skipClick=false end)
    end)
    button:SetScript("OnUpdate",function() if self.dragging then self:DragLauncher() end end)
    button:SetScript("OnHide",function() self.dragging=false end)
    Minimap:HookScript("OnSizeChanged",function() self:PositionLauncher() end)
    button:SetScript("OnClick",function()
        if self.skipClick then self.skipClick=false;return end
        if InCombatLockdown() then FT:CombatOpenRequest();return end
        if panel:IsShown() and not panel.closing then self:CloseMenu(true) else self:OpenMenu() end
    end)
    FT:Tooltip(button,"Grouped minimap buttons","Click to open or close. The menu closes by itself a few seconds after your mouse leaves it. Drag this icon to move it around the minimap. The buttons inside keep their normal clicks and tooltips.")
end
function Icons:Eligible(button,known)
    if not button or button==self.launcher or (self.records[button] and self.records[button].active) or protected(button) then return false end
    if not button.GetScript or not button.SetParent or not button.GetNumPoints then return false end
    local name=button.GetName and button:GetName() or ""
    if excluded[name] or (not known and (name:match("^MiniMap") or name:match("^Minimap"))) then return false end
    if not button:GetScript("OnClick") then return false end
    if known then return true end
    -- Only addon launchers, never world pins, tracking controls, or arbitrary
    -- Blizzard children. LibDBIcon provides the reliable identification path.
    local lower=name:lower()
    return button==FT.minimapButton or lower:find("minimap",1,true)~=nil
        or lower:find("libdbicon",1,true)~=nil
end
function Icons:Collect(button,known)
    if not self:Eligible(button,known) then return end
    local points={}
    for i=1,button:GetNumPoints() do points[i]={button:GetPoint(i)} end
    local record=self.records[button] or {}
    record.parent=button:GetParent();record.points=points;record.scale=button:GetScale()
    record.strata=button:GetFrameStrata();record.level=button:GetFrameLevel()
    -- LibDBIcon locks its buttons to MEDIUM strata / level 8. Left locked, they
    -- sit underneath the DIALOG menu: dimmed by its background and unclickable.
    record.fixedStrata=button.HasFixedFrameStrata and button:HasFixedFrameStrata() or false
    record.fixedLevel=button.HasFixedFrameLevel and button:HasFixedFrameLevel() or false
    record.dragStart=button:GetScript("OnDragStart");record.dragStop=button:GetScript("OnDragStop")
    record.active=true
    self.records[button]=record
    self.positioning=true
    if button.SetFixedFrameStrata then button:SetFixedFrameStrata(false) end
    if button.SetFixedFrameLevel then button:SetFixedFrameLevel(false) end
    button:SetParent(self.panel);button:SetScale(1);button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(self.panel:GetFrameLevel()+2)
    if record.fixedStrata then button:SetFixedFrameStrata(true) end
    if record.fixedLevel then button:SetFixedFrameLevel(true) end
    button:SetScript("OnDragStart",nil);button:SetScript("OnDragStop",nil)
    self.positioning=false
    self:BrightIcon(button,record)
    if hooksecurefunc and not record.hooked then
        record.hooked=true
        local function position()
            if record.active and not self.positioning and not InCombatLockdown() then self:Place(button,record) end
        end
        hooksecurefunc(button,"SetPoint",position)
        hooksecurefunc(button,"ClearAllPoints",position)
    end
    if not record.visibilityHooked then
        record.visibilityHooked=true
        button:HookScript("OnShow",function() self.dirty=true end)
        button:HookScript("OnHide",function() self.dirty=true end)
        button:HookScript("OnEnter",function() self:BrightIcon(button,record) end)
        button:HookScript("OnLeave",function() self:BrightIcon(button,record) end)
    end
end
function Icons:Place(button,record)
    if not record.x or protected(button) then return end
    self.positioning=true
    button:ClearAllPoints();button:SetPoint("CENTER",self.panel,"TOPLEFT",record.x,record.y)
    self.positioning=false
end
function Icons:Scan()
    if not self.active or InCombatLockdown() then return end
    if LibStub then
        local lib=LibStub("LibDBIcon-1.0",true)
        if lib and lib.GetButtonList and lib.GetMinimapButton then
            for _,name in ipairs(lib:GetButtonList()) do self:Collect(lib:GetMinimapButton(name),true) end
        end
    end
    if Minimap and Minimap.GetChildren then
        for _,button in ipairs({Minimap:GetChildren()}) do self:Collect(button,false) end
    end
    self:Collect(FT.minimapButton,true)
end
function Icons:Layout()
    if not self.panel or InCombatLockdown() then return end
    local list={};local cell=40
    for button,record in pairs(self.records) do
        if record.active and button:IsShown() and not (button.db and button.db.hide) then
            self:BrightIcon(button,record)
            list[#list+1]=button
            cell=math.max(cell,button:GetWidth()+8,button:GetHeight()+8)
        end
    end
    table.sort(list,function(a,b) return (a:GetName() or "")<(b:GetName() or "") end)
    -- Horizontal: side by side, a new row after 6. Vertical: one below the
    -- other, a new column after 6.
    local vertical=self:Vertical()
    local across=math.min(6,math.max(1,#list));local lines=math.max(1,math.ceil(#list/across))
    local columns,rows=across,lines
    if vertical then columns,rows=lines,across end
    -- Wide enough for the "no icons" line when there is nothing to show.
    self.panel:SetSize(math.max(#list==0 and 180 or 0,columns*cell+16),rows*cell+16)
    for i,button in ipairs(list) do
        local record=self.records[button]
        local along,line=(i-1)%across,math.floor((i-1)/across)
        local column,row=along,line
        if vertical then column,row=line,along end
        record.x=8+(column+.5)*cell;record.y=-8-(row+.5)*cell
        self:Place(button,record)
    end
    self.empty:SetShown(#list==0);self.dirty=false
end
function Icons:Restore()
    if InCombatLockdown() then return end
    for button,record in pairs(self.records) do
        if record.active and not protected(button) then
            record.active=false -- disable our positioning hooks before restoration
            if record.alpha~=nil then button:SetAlpha(record.alpha);record.alpha=nil end
            if record.iconStyle then
                local style=record.iconStyle;style.texture:SetVertexColor(unpack(style.color));style.texture:SetAlpha(style.alpha)
                if style.texture.SetDesaturated then style.texture:SetDesaturated(style.desaturated or false) end
                record.iconStyle=nil
            end
            if button.SetFixedFrameStrata then button:SetFixedFrameStrata(false) end
            if button.SetFixedFrameLevel then button:SetFixedFrameLevel(false) end
            button:SetParent(record.parent);button:SetScale(record.scale)
            button:SetFrameStrata(record.strata);button:SetFrameLevel(record.level)
            if record.fixedStrata then button:SetFixedFrameStrata(true) end
            if record.fixedLevel then button:SetFixedFrameLevel(true) end
            button:ClearAllPoints()
            for _,point in ipairs(record.points) do button:SetPoint(unpack(point)) end
            button:SetScript("OnDragStart",record.dragStart);button:SetScript("OnDragStop",record.dragStop)
        end
    end
    self:CloseMenu(true)
    if self.launcher then self.launcher:Hide() end
end
function Icons:Apply()
    if not FT.dbReady or not FT.profilesReady or InCombatLockdown() then return end
    self.active=self:Enabled()
    if not self.active then self:Restore();return end
    self:Create();if not self.launcher then return end
    -- Reuse hooks, but capture current positions again on each new enable.
    for button,record in pairs(self.records) do
        if not record.active then self:Collect(button,true) end
    end
    self:PositionLauncher();self.launcher:Show();self:Scan();self:Layout()
end
function Icons:ToggleVertical()
    if InCombatLockdown() then FT:Toast("Change minimap icons after combat.");return end
    local s=FT.modules.System:Settings()
    s.minimapIconsVertical=not (s.minimapIconsVertical==true)
    if self.active then self:Scan();self:Layout() end
    if FT.modules.Profiles then FT.modules.Profiles:SaveDraft() end
    FT.modules.System:Refresh()
end
function Icons:Toggle()
    if InCombatLockdown() then FT:Toast("Change minimap icons after combat.");return end
    FT.modules.System:Settings().minimapIcons=not self:Enabled()
    self:Apply()
    if FT.modules.Profiles then FT.modules.Profiles:SaveDraft() end
    ForeverToolsDB=FT.db;KrilarToolsDB=FT.db
    FT.modules.System:Refresh()
end
FT:RegisterModule("MinimapIcons",Icons)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then Icons.dragging=false;Icons:CloseMenu(true);return end
    if FT.dbReady then FT:Coalesce("minimapIcons",function() Icons:Apply() end) end
end)
events:SetScript("OnUpdate",function(_,dt)
    if not Icons.active or InCombatLockdown() then return end
    Icons.elapsed=Icons.elapsed+dt
    if Icons.elapsed>=3 then Icons.elapsed=0;Icons:Scan();Icons:Layout()
    elseif Icons.dirty then Icons:Layout() end
end)
