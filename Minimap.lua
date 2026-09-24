local addonName, FT = ...
function FT:PositionMinimap()
    if not self.minimapButton or not Minimap then return end
    local angle = tonumber(self.db.minimapAngle) or 135
    if angle ~= angle then angle = 135 end
    local radians = math.rad(angle)
    local x, y = math.cos(radians), math.sin(radians)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local scale = math.max(math.abs(x), math.abs(y)); x, y = x / scale, y / scale
    end
    self.minimapButton:ClearAllPoints()
    -- Slightly outside the rim, matching the visual centre of other minimap launchers.
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + 4), y * (Minimap:GetHeight() / 2 + 4))
end
function FT:MinimapDrag()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local centerX, centerY = Minimap:GetCenter()
    if not centerX or not centerY then return end
    -- Keep a runtime copy too: ADDON_LOADED may replace the initial saved-variable table.
    self.minimapDragAngle = math.deg(math.atan2((y / scale - centerY) / Minimap:GetHeight(), (x / scale - centerX) / Minimap:GetWidth()))
    self:SaveMinimapPosition()
    self:PositionMinimap()
end
function FT:SaveMinimapPosition()
    if self.minimapDragAngle then
        self.db.minimapAngle = self.minimapDragAngle
    end
end
function FT:ShowMinimapMenu()
    if self:CombatOpenRequest() then return end
    if not self.minimapMenu then
        local menu = CreateFrame("Frame", nil, UIParent)
        self.minimapMenu = menu
        menu:SetSize(246, 82); menu:SetFrameStrata("TOOLTIP"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
        self:Panel(menu)
        local hide = self:QuietButton(menu, "Hide minimap icon", 226, 28, "map")
        hide:SetPoint("TOPLEFT", 10, -10)
        hide:SetScript("OnClick", function()
            FT.db.minimapEnabled = false; FT:UpdateMinimap(); menu:Hide()
            if FT.minimapToggle then FT.minimapToggle.label:SetText("Minimap icon: Off"); FT:SetSelected(FT.minimapToggle, false) end
        end)
        self.minimapHideButton = hide
        local cancel = self:QuietButton(menu, "Close", 226, 26, "home")
        cancel:SetPoint("BOTTOMLEFT", 10, 10); cancel:SetScript("OnClick", function() menu:Hide() end)
        menu:Hide()
    end
    if self.minimapMenu:IsShown() then self.minimapMenu:Hide(); return end
    self.minimapMenu:ClearAllPoints(); self.minimapMenu:SetPoint("TOPRIGHT", self.minimapButton, "BOTTOMRIGHT", 0, -4)
    self.minimapMenu:Show()
end
function FT:UpdateMinimap()
    if type(self.db.minimapEnabled) ~= "boolean" then self.db.minimapEnabled = true end
    if not Minimap then return end
    if not self.minimapButton then
        local button = CreateFrame("Button", "ForeverToolsMinimapButton", Minimap)
        if button.SetDontSavePosition then button:SetDontSavePosition(true) end
        -- Custom dragging saves an angle; this frame never uses StartMoving/SetUserPlaced.
        button:SetSize(31, 31); button:SetFrameLevel(Minimap:GetFrameLevel() + 10)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); button:RegisterForDrag("LeftButton")
        -- The logo includes its own frame. An additional tracking ring has an
        -- asymmetric transparent canvas and makes the badge look off-centre.
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(31.625, 31.625)
        button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.icon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Logo.tga")
        button:SetScript("OnClick", function(owner, mouseButton)
            if owner.skipClick then owner.skipClick = false; return end
            if mouseButton == "RightButton" then FT:ShowMinimapMenu() else
                if FT.minimapMenu then FT.minimapMenu:Hide() end
                FT:OpenHome()
            end
        end)
        button:SetScript("OnDragStart", function(owner)
            GameTooltip:Hide(); if FT.minimapMenu then FT.minimapMenu:Hide() end
            FT:MinimapDrag()
            owner:SetScript("OnUpdate", function() FT:MinimapDrag() end)
        end)
        button:SetScript("OnDragStop", function(owner)
            owner:SetScript("OnUpdate", nil); FT:SaveMinimapPosition(); owner.skipClick = true
            C_Timer.After(0, function() owner.skipClick = false end)
        end)
        button:SetScript("OnEnter", function(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_LEFT"); GameTooltip:SetText("ForeverTools v" .. FT.version, 0.79, 0.63, 1)
            GameTooltip:AddLine("Left-click: open • Drag: move", 1, 1, 1)
            GameTooltip:AddLine("Right-click: icon options", 0.75, 0.70, 0.85); GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnHide", function(owner)
            owner:SetScript("OnUpdate", nil); GameTooltip:Hide()
            if FT.minimapMenu then FT.minimapMenu:Hide() end
        end)
        self.minimapButton = button
        Minimap:HookScript("OnSizeChanged", function() FT:PositionMinimap() end)
    end
    self:PositionMinimap(); self.minimapButton:SetShown(self.db.minimapEnabled)
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if not FT.dbReady then return end
    if event == "PLAYER_LOGOUT" then FT:SaveMinimapPosition(); return end
    FT:UpdateMinimap()
    C_Timer.After(0, function() FT:PositionMinimap() end)
    C_Timer.After(1, function() FT:PositionMinimap() end)
end)
