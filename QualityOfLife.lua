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
-- Position works like the leveling stats: the point on the chosen side
-- (top-left, top or top-right) sits at anchorX/anchorY, the text lines up
-- on that side, and the counter can go right up to the screen edge.
local anchors = { left = "TOPLEFT", center = "TOP", right = "TOPRIGHT" }
local PAD = 2
function QoL:Anchor()
    local s = self:Settings()
    if s.align ~= "left" and s.align ~= "center" and s.align ~= "right" then s.align = "left" end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not finite(s.anchorX) or not finite(s.anchorY) then
        -- Older saves stored the counter's center; start from its left/top edge.
        local oldW, oldH = math.max(100, s.fontSize * 5), s.fontSize + 16
        local x, y = s.x, s.y
        if finite(s.screenWidth) and s.screenWidth > 0 then x = x * width / s.screenWidth end
        if finite(s.screenHeight) and s.screenHeight > 0 then y = y * height / s.screenHeight end
        s.anchorX, s.anchorY = x - oldW / 2 + 8, y + oldH / 2 - 8
        s.anchorWidth, s.anchorHeight = width, height
    end
    local x, y = s.anchorX, s.anchorY
    if finite(s.anchorWidth) and s.anchorWidth > 0 then x = x * width / s.anchorWidth end
    if finite(s.anchorHeight) and s.anchorHeight > 0 then y = y * height / s.anchorHeight end
    return x, y
end
function QoL:Clamp(x, y)
    local w, h = self.counter:GetWidth(), self.counter:GetHeight()
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local align = self:Settings().align
    local low = align == "right" and w or align == "center" and w / 2 or 0
    local high = align == "right" and W or align == "center" and W - w / 2 or W - w
    return math.max(low, math.min(high, x)), math.max(h, math.min(H, y))
end
function QoL:Place(x, y)
    self.counter:ClearAllPoints()
    self.counter:SetPoint(anchors[self:Settings().align], UIParent, "BOTTOMLEFT", x, y)
end
function QoL:RestorePosition()
    if not self.counter or self.dragging then return end
    -- Clamp only the displayed position; startup layout must never rewrite saved coordinates.
    self:Place(self:Clamp(self:Anchor()))
end
function QoL:BeginDrag()
    if not self.moving then return end
    local cx, cy = GetCursorPosition(); local scale = UIParent:GetEffectiveScale()
    local x, y = self:Anchor()
    self.dragOffsetX, self.dragOffsetY = x - cx / scale, y - cy / scale
    self.dragging = true
end
function QoL:UpdateDrag()
    if not self.dragging then return end
    local cx, cy = GetCursorPosition(); local scale = UIParent:GetEffectiveScale()
    local x, y = self:Clamp(cx / scale + self.dragOffsetX, cy / scale + self.dragOffsetY)
    local s = self:Settings()
    -- Persist during dragging as well as on release.
    s.anchorX, s.anchorY, s.anchorWidth, s.anchorHeight = x, y, UIParent:GetWidth(), UIParent:GetHeight()
    self:Place(x, y)
end
function QoL:SavePosition()
    if not self.dragging then return end
    self:UpdateDrag()
    self.dragging = false
    self:RestorePosition()
end
-- Changing the side keeps the counter where it is on screen.
function QoL:SetAlign(align)
    local s = self:Settings()
    if self.counter and self.counter:GetLeft() and s.align ~= align then
        local scale = self.counter:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, right, top = self.counter:GetLeft() * scale, self.counter:GetRight() * scale, self.counter:GetTop() * scale
        s.anchorX = align == "left" and left or align == "right" and right or (left + right) / 2
        s.anchorY = top; s.anchorWidth, s.anchorHeight = UIParent:GetWidth(), UIParent:GetHeight()
    end
    s.align = align
    self:Apply()
end
-- keepState: Move elements shows the counter while moving without turning it on.
function QoL:ResetPosition()
    local settings = self:Settings()
    settings.align = "left"
    settings.anchorX, settings.anchorY = 16, UIParent:GetHeight() - 16
    settings.anchorWidth, settings.anchorHeight = UIParent:GetWidth(), UIParent:GetHeight()
    self:Apply()
end
function QoL:SetMoving(value, keepState)
    if self.moving then self:SavePosition() end
    self.moving = not not value
    if self.moving and not keepState then self:Settings().enabled = true end
    self:Apply()
end
-- The text and a tight box around it (like the leveling stats), lined up
-- on the chosen side, so both sit exactly on the same edge.
function QoL:SetReading(text)
    local counter = self.counter
    counter.text:SetText(text)
    local w = counter.text:GetStringWidth()
    local size = self:Settings().fontSize
    if type(w) ~= "number" or w <= 0 then w = size * 3 end
    counter:SetSize(w + PAD * 2, size + 4)
end
function QoL:Apply()
    local settings = self:Settings()
    if not self.counter then
        local counter = CreateFrame("Frame", "ForeverToolsFPS", UIParent)
        self.counter = counter
        if counter.SetDontSavePosition then counter:SetDontSavePosition(true) end
        counter:SetClampedToScreen(true)
        counter:RegisterForDrag("LeftButton")
        counter.text = counter:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        FT:MoverBox(counter, 8)
        counter.hint = FT:Label(counter, "Drag to move", 12)
        FT:Caption(counter.hint, counter, "below", 8)
        counter:SetScript("OnDragStart", function() self:BeginDrag() end)
        counter:SetScript("OnDragStop", function() self:SavePosition() end)
        counter:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then self:SavePosition() end end)
    end
    local align = (settings.align == "center" or settings.align == "right") and settings.align or "left"
    local text = self.counter.text
    text:ClearAllPoints()
    if align == "left" then text:SetPoint("TOPLEFT", PAD, 0); text:SetJustifyH("LEFT")
    elseif align == "right" then text:SetPoint("TOPRIGHT", -PAD, 0); text:SetJustifyH("RIGHT")
    else text:SetPoint("TOP", 0, 0); text:SetJustifyH("CENTER") end
    -- Match the original counter's GameFontNormal face, flags, shadow and gold color.
    local font, _, flags = GameFontNormal:GetFont()
    text:SetFont(font, settings.fontSize, flags or "")
    text:SetTextColor(GameFontNormal:GetTextColor())
    self:SetReading(string.format("%d FPS", math.floor(GetFramerate() + 0.5)))
    -- Behind game windows (like buff reminders); on top only while you move it.
    self.counter:SetFrameStrata(self.moving and "HIGH" or "LOW")
    self.counter:EnableMouse(self.moving or false)
    for _, texture in ipairs(self.counter.fillTextures) do texture:SetShown(self.moving or false) end
    for _, texture in ipairs(self.counter.borderTextures) do texture:SetShown(self.moving or false) end
    self.counter.hint:SetShown(self.moving or false)
    self:RestorePosition()
    self.counter:SetScript("OnUpdate", nil)
    local visible = settings.enabled or self.moving
    self.counter:SetShown(visible)
    if visible then
        self.counter.elapsed = 0
        self.counter:SetScript("OnUpdate", function(owner, elapsed)
            self:UpdateDrag()
            owner.elapsed = owner.elapsed + elapsed
            if owner.elapsed >= 0.5 then
                owner.elapsed = 0
                self:SetReading(string.format("%d FPS", math.floor(GetFramerate() + 0.5)))
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
        local names = { left = "Line up: left", center = "Line up: center", right = "Line up: right" }
        self.alignChoice.value = align; self.alignChoice.label:SetText(names[align])
    end
end
function QoL:ChangeSize(delta)
    local settings = self:Settings()
    settings.fontSize = math.max(10, math.min(48, settings.fontSize + delta))
    self:Apply()
end
function QoL:Open()
    if not self.frame then
        self.frame = FT:Window("ForeverToolsFPSSettings", "FPS counter", 540, 240)
        FT:BackTo(self.frame,"SystemDisplay")
        FT:PageInfo(self.frame, "FPS counter", "A small frames-per-second counter. Unlock it, drag it anywhere (right up to the screen edge), then lock it. Moving it turns the counter on.")
        self.toggle = FT:AccentButton(self.frame, "", 492, 34, "fps")
        self.toggle:SetPoint("TOPLEFT", 24, -62)
        self.toggle:SetScript("OnClick", function()
            if self.moving then self:SetMoving(false) end
            local settings = self:Settings()
            settings.enabled = not settings.enabled
            self:Apply()
        end)
        self.moveButton = FT:QuietButton(self.frame, "", 492, 32, "move")
        self.moveButton:SetPoint("TOPLEFT", 24, -104)
        self.moveButton:SetScript("OnClick", function() self:SetMoving(not self.moving) end)
        self.smaller = FT:QuietButton(self.frame, "-", 40, 32)
        self.smaller:SetPoint("TOPLEFT", 24, -144)
        self.smaller:SetScript("OnClick", function() self:ChangeSize(-2) end)
        self.sizeLabel = FT:Label(self.frame, "", 16)
        self.sizeLabel:SetPoint("LEFT", self.smaller, "RIGHT", 18, 0); self.sizeLabel:SetWidth(135)
        self.larger = FT:QuietButton(self.frame, "+", 40, 32)
        self.larger:SetPoint("LEFT", self.sizeLabel, "RIGHT", 10, 0)
        self.larger:SetScript("OnClick", function() self:ChangeSize(2) end)
        local reset = FT:QuietButton(self.frame, "Reset position", 160, 32, "reset")
        reset:SetPoint("TOPRIGHT", -24, -144)
        reset:SetScript("OnClick", function() self:ResetPosition() end)
        FT:Tooltip(reset, "Reset position", "Put the counter back in the top-left corner.")
        FT:Tooltip(self.toggle, "FPS counter", "Show or hide the frames-per-second counter.")
        FT:Tooltip(self.moveButton, "Move counter", "Click to unlock, drag the counter where you want it, then click again to lock it. Moving turns the counter on.")
        FT:Tooltip(self.smaller, "Smaller", "Make the counter's text smaller.")
        FT:Tooltip(self.larger, "Larger", "Make the counter's text larger.")
        local icon = "Interface\\Icons\\INV_Misc_PocketWatch_01"
        self.alignChoice = FT:Dropdown(self.frame, 492, function()
            return {{value="left",label="Line up: left",icon=icon,tooltip="Text lines up on the left; the counter grows to the right."},
                {value="center",label="Line up: center",icon=icon,tooltip="Text is centered."},
                {value="right",label="Line up: right",icon=icon,tooltip="Text lines up on the right; good next to the right screen edge."}}
        end, function(value) self:SetAlign(value) end, "move")
        self.alignChoice:SetPoint("TOPLEFT", 24, -184); self.alignChoice.menuWidth = 492
        FT:Tooltip(self.alignChoice, "Line up", "Which side the counter lines up on, the same as the leveling stats. It stays anchored on that side, so it can sit flush against a screen edge.")
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
        if not welcomed and FT.db.welcome == true then print("|cffffd100ForeverTools v"..FT.version.." loaded:|r |cffffffff/ft|r") end
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

