local addonName, FT = ...
local QoL = {}
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < 100000 end
function QoL:Settings()
    if type(FT.db.fps) ~= "table" then FT.db.fps = {} end
    local settings = FT.db.fps
    -- Earlier builds exposed a separate Always on switch. The counter now has
    -- one clear on/off control and starts on for both new and migrated settings.
    if settings.alwaysOn == true and settings.enabled == false then settings.enabled = true end
    if type(settings.enabled) ~= "boolean" then settings.enabled = false end
    settings.alwaysOn = nil
    settings.fontSize = finite(settings.fontSize) and math.max(10, math.min(48, settings.fontSize)) or 16
    if not finite(settings.x) or not finite(settings.y) then
        -- Convert the old corner setting once into free-position coordinates.
        local width, height = UIParent:GetWidth(), UIParent:GetHeight()
        local right = settings.corner == "TOPRIGHT" or settings.corner == "BOTTOMRIGHT"
        local bottom = settings.corner == "BOTTOMLEFT" or settings.corner == "BOTTOMRIGHT"
        settings.x = right and width - 76 or 70
        settings.y = bottom and 32 or height - 28
        settings.screenWidth, settings.screenHeight = width, height
        settings.defaultPositionVersion = 2
    elseif settings.defaultPositionVersion ~= 2 and settings.x <= 100 and settings.y > UIParent:GetHeight() * 0.40 then
        -- The old default could be saved as a left-side coordinate far down the
        -- screen, with or without display dimensions. Migrate that known default
        -- once; positions moved elsewhere are retained unchanged.
        settings.x, settings.y = 70, UIParent:GetHeight() - 28
        settings.screenWidth, settings.screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
        settings.defaultPositionVersion = 2
    end
    return settings
end
function QoL:SavePosition()
    if not self.dragging then return end
    self:UpdateDrag()
    self.dragging = false
    self:RestorePosition()
end
function QoL:BeginDrag()
    if not self.moving then return end
    local x, y = GetCursorPosition()
    local centerX, centerY = self.counter:GetCenter()
    if not centerX or not centerY then return end
    local scale = UIParent:GetEffectiveScale()
    local frameScale = self.counter:GetEffectiveScale() / scale
    self.dragOffsetX, self.dragOffsetY = centerX * frameScale - x / scale, centerY * frameScale - y / scale
    self.dragging = true
end
function QoL:UpdateDrag()
    if not self.dragging then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local s = self:Settings()
    s.x = math.max(60, math.min(width - 60, x / scale + self.dragOffsetX))
    s.y = math.max(24, math.min(height - 24, y / scale + self.dragOffsetY))
    s.screenWidth, s.screenHeight = width, height
    -- Persist during dragging as well as on release; no engine layout cache involved.
    self.counter:ClearAllPoints()
    self.counter:SetPoint("CENTER", UIParent, "BOTTOMLEFT", s.x, s.y)
end
function QoL:RestorePosition()
    if not self.counter or self.dragging then return end
    local settings = self:Settings()
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local x, y = settings.x, settings.y
    if finite(settings.screenWidth) and settings.screenWidth > 0 then x = x * width / settings.screenWidth end
    if finite(settings.screenHeight) and settings.screenHeight > 0 then y = y * height / settings.screenHeight end
    -- Clamp only the displayed position; startup layout must never rewrite saved coordinates.
    x = math.max(60, math.min(width - 60, x))
    y = math.max(24, math.min(height - 24, y))
    self.counter:ClearAllPoints()
    self.counter:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end
function QoL:SetMoving(value)
    if self.moving then self:SavePosition() end
    self.moving = not not value
    if self.moving then self:Settings().enabled = true end
    self:Apply()
end
function QoL:Apply()
    local settings = self:Settings()
    if not self.counter then
        local counter = CreateFrame("Frame", "ForeverToolsFPS", UIParent)
        self.counter = counter
        counter:SetFrameStrata("HIGH")
        if counter.SetDontSavePosition then counter:SetDontSavePosition(true) end
        counter:SetClampedToScreen(true)
        counter:RegisterForDrag("LeftButton")
        counter.text = counter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        counter.text:SetPoint("CENTER")
        counter.text:SetJustifyH("CENTER")
        FT:Panel(counter)
        counter.hint = FT:Label(counter, "Drag to move", 12)
        counter.hint:SetPoint("TOP", counter, "BOTTOM", 0, -4)
        counter:SetScript("OnDragStart", function() self:BeginDrag() end)
        counter:SetScript("OnDragStop", function() self:SavePosition() end)
        counter:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then self:SavePosition() end end)
    end
    self.counter:SetSize(math.max(100, settings.fontSize * 5), settings.fontSize + 16)
    self:RestorePosition()
    -- Match the original counter's GameFontNormal face, flags, shadow and gold color.
    local font, _, flags = GameFontNormal:GetFont()
    self.counter.text:SetFont(font, settings.fontSize, flags or "")
    self.counter.text:SetTextColor(GameFontNormal:GetTextColor())
    self.counter:EnableMouse(self.moving or false)
    for _, texture in ipairs(self.counter.fillTextures) do texture:SetShown(self.moving or false) end
    for _, texture in ipairs(self.counter.borderTextures) do texture:SetShown(self.moving or false) end
    self.counter.hint:SetShown(self.moving or false)
    self.counter:SetScript("OnUpdate", nil)
    local visible = settings.enabled or self.moving
    self.counter:SetShown(visible)
    if visible then
        self.counter.text:SetText(string.format("%d FPS", math.floor(GetFramerate() + 0.5)))
        self.counter.elapsed = 0
        self.counter:SetScript("OnUpdate", function(owner, elapsed)
            self:UpdateDrag()
            owner.elapsed = owner.elapsed + elapsed
            if owner.elapsed >= 0.5 then
                owner.elapsed = 0
                owner.text:SetText(string.format("%d FPS", math.floor(GetFramerate() + 0.5)))
            end
        end)
    end
    if self.toggle then
        self.toggle.label:SetText(settings.enabled and "FPS counter: On" or "FPS counter: Off")
        FT:SetSelected(self.toggle, settings.enabled)
        self.moveButton.label:SetText(self.moving and "Moving unlocked — click to lock" or "Move counter freely")
        FT:SetSelected(self.moveButton, self.moving)
        self.sizeLabel:SetText(string.format("Font size: %d", settings.fontSize))
        self.smaller:SetEnabled(settings.fontSize > 10)
        self.larger:SetEnabled(settings.fontSize < 48)
    end
end
function QoL:ChangeSize(delta)
    local settings = self:Settings()
    settings.fontSize = math.max(10, math.min(48, settings.fontSize + delta))
    self:Apply()
end
function QoL:Open()
    if not self.frame then
        self.frame = FT:Window("ForeverToolsFPSSettings", "ForeverTools | FPS counter", 500, 320)
        local hint = FT:Label(self.frame, "Unlock, drag the counter anywhere, then lock it in place.", 14)
        hint:SetPoint("TOPLEFT", 24, -60)
        self.toggle = FT:QuietButton(self.frame, "", 452, 36, "fps")
        self.toggle:SetPoint("TOPLEFT", 24, -90)
        self.toggle:SetScript("OnClick", function()
            if self.moving then self:SetMoving(false) end
            local settings = self:Settings()
            settings.enabled = not settings.enabled
            self:Apply()
        end)
        self.moveButton = FT:QuietButton(self.frame, "", 452, 36, "move")
        self.moveButton:SetPoint("TOPLEFT", 24, -138)
        self.moveButton:SetScript("OnClick", function() self:SetMoving(not self.moving) end)
        self.smaller = FT:QuietButton(self.frame, "−", 40, 32)
        self.smaller:SetPoint("TOPLEFT", 24, -198)
        self.smaller:SetScript("OnClick", function() self:ChangeSize(-2) end)
        self.sizeLabel = FT:Label(self.frame, "", 16)
        self.sizeLabel:SetPoint("LEFT", self.smaller, "RIGHT", 18, 0); self.sizeLabel:SetWidth(135)
        self.larger = FT:QuietButton(self.frame, "+", 40, 32)
        self.larger:SetPoint("LEFT", self.sizeLabel, "RIGHT", 10, 0)
        self.larger:SetScript("OnClick", function() self:ChangeSize(2) end)
        local reset = FT:QuietButton(self.frame, "Reset position", 160, 32, "reset")
        reset:SetPoint("TOPRIGHT", -24, -198)
        reset:SetScript("OnClick", function()
            local settings = self:Settings()
            settings.x, settings.y = 100, UIParent:GetHeight() - 48
            settings.screenWidth, settings.screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
            self:Apply()
        end)
        local note = FT:Label(self.frame, "Moving turns the counter on. Changes apply now; save a profile to reuse them.", 13)
        note:SetPoint("BOTTOMLEFT", 24, 32); note:SetWidth(450)
        self.frame:HookScript("OnHide", function() if self.moving then self:SetMoving(false) end end)
    end
    self:Apply()
    self.frame:Show()
end
function QoL:AttachMacroButton()
    if not MacroFrame or InCombatLockdown() then return end
    if self.macroButton then
        self.macroButton:SetFrameLevel(MacroFrame:GetFrameLevel() + 10)
        self.macroButton:Show()
        return
    end
    local button = FT:QuietButton(MacroFrame, "FT", 48, 20)
    button:SetPoint("TOPRIGHT", MacroFrame, "TOPRIGHT", -30, -2)
    button:SetFrameLevel(MacroFrame:GetFrameLevel() + 10)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(14, 14); button.icon:SetPoint("LEFT", 4, 0)
    button.icon:SetTexture("Interface\\Icons\\Trade_Engineering")
    button.label:ClearAllPoints(); button.label:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
    button:SetScript("OnClick", function() FT:OpenModule("MacroForge") end)
    button:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText("ForeverTools")
        GameTooltip:AddLine("Open Macros", 1, 1, 1); GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self.macroButton = button
    MacroFrame:HookScript("OnShow", function() QoL:AttachMacroButton() end)
    button:Show()
end
FT:RegisterModule("QualityOfLife", QoL)
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
local welcomed = false
local function initialize()
    FT:InitializeDB()
    QoL:Apply()
    FT:UpdateMinimap()
end
events:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then initialize()
    elseif event == "PLAYER_LOGIN" then
        initialize()
        if not welcomed and FT.db.welcome == true then print("|cffc9a0ffForeverTools v"..FT.version.." loaded:|r |cffffffff/ft|r") end
        welcomed = true
    elseif event == "PLAYER_LOGOUT" and QoL.moving then QoL:SavePosition() end
    if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        QoL:RestorePosition()
        C_Timer.After(0, function() QoL:RestorePosition() end)
        C_Timer.After(1, function() QoL:RestorePosition() end)
    end
    QoL:AttachMacroButton()
    if event == "ADDON_LOADED" and C_Timer and C_Timer.After then C_Timer.After(0, function() QoL:AttachMacroButton() end) end
end)
if type(MacroFrame_LoadUI) == "function" and type(hooksecurefunc) == "function" then
    hooksecurefunc("MacroFrame_LoadUI", function() QoL:AttachMacroButton() end)
end
QoL:AttachMacroButton()

