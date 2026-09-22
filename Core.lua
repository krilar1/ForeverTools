local addonName, FT = ...
FT.name = addonName
FT.version = "0.9.8"
FT.modules = {}
FT.headingFont = "Fonts\\FRIZQT__.TTF"
FT.bodyFont = "Fonts\\ARIALN.TTF"
-- SavedVariables are ready at our ADDON_LOADED, not while these files execute.
-- Initialize once and keep every module on the same table throughout the session.
FT.db = {}
function FT:InitializeDB()
    if self.dbReady then return end
    self.db = type(ForeverToolsDB) == "table" and ForeverToolsDB
        or (type(KrilarToolsDB) == "table" and KrilarToolsDB or {})
    -- Recover missing named profiles from the legacy table before aliasing it.
    -- Keep current profiles authoritative when both tables contain the same name.
    if type(KrilarToolsDB)=="table" and KrilarToolsDB~=self.db and type(KrilarToolsDB.profiles)=="table" then
        if type(self.db.profiles)~="table" then self.db.profiles={} end
        for name,profile in pairs(KrilarToolsDB.profiles) do
            if self.db.profiles[name]==nil and type(profile)=="table" then self.db.profiles[name]=profile end
        end
    end
    -- Keep the legacy key pointing at the same table. Older ForeverTools builds
    -- wrote KrilarToolsDB into ForeverTools.lua; clearing it at startup made the
    -- client serialize an empty table on reload for affected installations.
    ForeverToolsDB = self.db
    KrilarToolsDB = self.db
    self.db.schema = 3
    local probe = CreateFont("ForeverToolsInterfaceFontProbe")
    for _, extension in ipairs({"ttf", "otf"}) do
        local path = "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\expressway." .. extension
        probe:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
        local ok = pcall(probe.SetFont, probe, path, 14, "")
        local actual = probe:GetFont()
        if ok and actual and actual:lower() == path:lower() then
            self.headingFont, self.bodyFont = path, path; break
        end
    end
    self.dbReady = true
end
local databaseEvents = CreateFrame("Frame")
databaseEvents:RegisterEvent("ADDON_LOADED")
databaseEvents:RegisterEvent("PLAYER_LOGOUT")
databaseEvents:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then FT:InitializeDB()
    elseif event == "PLAYER_LOGOUT" and FT.dbReady then ForeverToolsDB = FT.db; KrilarToolsDB = FT.db end
end)

function FT:RegisterModule(name, module) self.modules[name] = module end
function FT:OpenModule(name)
    local module = self.modules[name]
    if not module then return end
    if self.home then self.home:Hide() end
    for _, other in pairs(self.modules) do
        if other ~= module and other.frame then other.frame:Hide() end
    end
    module:Open()
end

-- Nine sliced rounded textures keep the corner radius constant at any panel size.
local function layer(frame, inset, sublevel)
    local result = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local texture = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
            texture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\" .. (sublevel == -7 and "RoundedGradient.tga" or "Rounded.tga"))
            local cuts = {0, 0.25, 0.75, 1}
            texture:SetTexCoord(cuts[col + 1], cuts[col + 2], cuts[row + 1], cuts[row + 2])
            local startX = col == 2 and "RIGHT" or "LEFT"
            local endX = col == 0 and "LEFT" or "RIGHT"
            local startY = row == 2 and "BOTTOM" or "TOP"
            local endY = row == 0 and "TOP" or "BOTTOM"
            local x1 = col == 0 and inset or (col == 1 and inset + 8 or -inset - 8)
            local x2 = col == 0 and inset + 8 or (col == 1 and -inset - 8 or -inset)
            local y1 = row == 0 and -inset or (row == 1 and -inset - 8 or inset + 8)
            local y2 = row == 0 and -inset - 8 or (row == 1 and inset + 8 or inset)
            texture:SetPoint("TOPLEFT", frame, startY .. startX, x1, y1)
            texture:SetPoint("BOTTOMRIGHT", frame, endY .. endX, x2, y2)
            result[#result + 1] = texture
        end
    end
    return result
end
function FT:Paint(frame, fill, border)
    for _, texture in ipairs(frame.fillTextures) do texture:SetVertexColor(unpack(fill)) end
    for _, texture in ipairs(frame.borderTextures) do texture:SetVertexColor(unpack(border)) end
end
function FT:Panel(frame)
    frame.borderTextures = layer(frame, 0, -8)
    frame.fillTextures = layer(frame, 1, -7)
    self:Paint(frame, {0.045, 0.04, 0.07, 1}, {0.30, 0.23, 0.46, 1})
end
function FT:Label(parent, text, size, heading)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(heading and self.headingFont or self.bodyFont, size or 14, "")
    label:SetText(text)
    label:SetTextColor(0.94, 0.91, 1)
    label:SetJustifyH("LEFT")
    return label
end
function FT:UpdateButton(button)
    if button.selected then
        self:Paint(button, {0.30, 0.17, 0.51, 1}, {0.83, 0.62, 1, 1})
    elseif button.hover then
        self:Paint(button, {0.18, 0.12, 0.28, 1}, {0.63, 0.45, 0.85, 1})
    elseif button.accent then
        self:Paint(button, {0.28, 0.15, 0.48, 1}, {0.62, 0.43, 0.86, 1})
    else
        self:Paint(button, {0.09, 0.075, 0.13, 1}, {0.28, 0.23, 0.37, 1})
    end
end
function FT:SetSelected(button, selected)
    button.selected = not not selected
    self:UpdateButton(button)
end
FT.icons = {
    macros = "INV_Misc_Note_01", fps = "INV_Misc_PocketWatch_01", home = "INV_Misc_Rune_01",
    welcome = "INV_Misc_Note_02", character = "INV_Misc_Head_Human_01", classes = "Ability_Marksmanship",
    generic = "Trade_Engineering", add = "INV_Misc_Book_09", delete = "INV_Misc_EngGizmos_20",
    move = "Ability_Rogue_Sprint", reset = "Spell_Nature_TimeStop", mouseover = "Spell_Holy_Heal",
    chat = "INV_Misc_Note_03",
    skins = "INV_Misc_ArmorKit_17", profiles = "INV_Misc_Book_09",
    general = "INV_Misc_Book_11", map = "INV_Misc_Map_01", fonts = "INV_Inscription_Tradeskill01",
}
function FT:ButtonIcon(button, icon, size)
    if not button.icon then button.icon = button:CreateTexture(nil, "ARTWORK") end
    local pixels = size or math.min(20, button:GetHeight() - 8)
    button.icon:SetSize(pixels, pixels)
    button.icon:SetPoint("LEFT", 9, 0)
    button.icon:SetTexture(icon == "home" and ("Interface\\AddOns\\" .. self.name .. "\\Media\\Home.tga") or ("Interface\\Icons\\" .. (self.icons[icon] or icon)))
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if icon == "delete" then
        button.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.icon:SetTexCoord(0,1,0,1)
    end
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.label:SetJustifyH("LEFT")
end
function FT:Tooltip(button, title, body)
    button:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 0.79, 0.63, 1)
        GameTooltip:AddLine(type(body) == "function" and body() or body, 0.91, 0.88, 0.96, true)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
function FT:Info(parent, title, text)
    local button = self:QuietButton(parent, "", 28, 28)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture("Interface\\GossipFrame\\ActiveQuestIcon")
    button.icon:SetSize(20,20); button.icon:SetPoint("CENTER")
    self:Tooltip(button, title, text)
    return button
end
function FT:Toast(message)
    if not self.toast then
        local frame = CreateFrame("Frame", "ForeverToolsToast", UIParent)
        frame:SetSize(270, 42); frame:SetPoint("TOP", UIParent, "TOP", 0, -135); frame:SetFrameStrata("DIALOG")
        self:Panel(frame)
        frame.text = self:Label(frame, "", 14, true); frame.text:SetPoint("CENTER"); frame.text:SetWidth(242); frame.text:SetJustifyH("CENTER")
        self.toast = frame
    end
    local toast = self.toast; toast.text:SetText(message); toast:Show()
    C_Timer.After(2.2, function() if toast then toast:Hide() end end)
end
function FT:QuietButton(parent, label, width, height, icon)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    self:Panel(button)
    button.label = self:Label(button, label, 14)
    button.label:SetPoint("CENTER")
    button:SetScript("OnEnter", function(owner) owner.hover = true; FT:UpdateButton(owner) end)
    button:SetScript("OnLeave", function(owner) owner.hover = false; FT:UpdateButton(owner) end)
    if icon then self:ButtonIcon(button, icon) end
    self:UpdateButton(button)
    return button
end
function FT:AccentButton(parent, label, width, height, icon)
    local button = self:QuietButton(parent, label, width, height, icon)
    button.accent = true
    self:UpdateButton(button)
    return button
end
function FT:Window(name, title, width, height)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    self:Panel(frame)
    local titleText = self:Label(frame, title, 20, true)
    frame.titleText = titleText
    titleText:SetPoint("TOPLEFT", 22, -21)
    if name == "ForeverToolsHome" then
        local logo = frame:CreateTexture(nil, "ARTWORK")
        logo:SetSize(40, 40); logo:SetPoint("TOPLEFT", 16, -10)
        logo:SetTexture("Interface\\AddOns\\" .. self.name .. "\\Media\\Logo.tga")
        titleText:ClearAllPoints(); titleText:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    end
    titleText:SetTextColor(0.82, 0.68, 1)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton=close
    close:SetSize(28,28)
    self:Tooltip(close, "Close", "Close this window.")
    close:SetPoint("TOPRIGHT", -14, -14)
    close:SetScript("OnClick", function() frame:Hide() end)
    if name ~= "ForeverToolsHome" then
        local home = self:QuietButton(frame, "Home", 88, 28, "home")
        frame.homeButton = home
        home:SetPoint("RIGHT", close, "LEFT", -8, 0)
        home:SetScript("OnClick", function() FT:OpenHome() end)
    end
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    frame:HookScript("OnHide",function()
        C_Timer.After(0,function() if FT.modules.Profiles then FT.modules.Profiles:OfferSave() end end)
    end)
    frame:Hide()
    return frame
end
function FT:OpenHome()
    for _, module in pairs(self.modules) do if module.frame then module.frame:Hide() end end
    if not self.home then
        self.home = self:Window("ForeverToolsHome", "ForeverTools", 440, 470)
        self.home.titleText:SetText("ForeverTools")
        local version = self:Label(self.home, "v" .. self.version, 11)
        version:SetPoint("BOTTOMLEFT", 18, 13); version:SetTextColor(0.66, 0.57, 0.77)
        local credit = self:Label(self.home, "Made by Krilar", 11)
        credit:SetPoint("BOTTOMRIGHT", -18, 13); credit:SetTextColor(0.66, 0.57, 0.77)
        local intro = self:Label(self.home, "Choose a tool", 15)
        intro:SetPoint("TOPLEFT", 24, -58)
        local macros = self:AccentButton(self.home, "Macros", 392, 46, "macros")
        self:ButtonIcon(macros, "macros", 30)
        macros:SetPoint("TOPLEFT", 24, -87)
        macros:SetScript("OnClick", function() FT:OpenModule("MacroForge") end)
        local fps = self:QuietButton(self.home, "FPS counter", 392, 46, "fps")
        self:ButtonIcon(fps, "fps", 30)
        fps:SetPoint("TOPLEFT", 24, -145)
        fps:SetScript("OnClick", function() FT:OpenModule("QualityOfLife") end)
        local fonts = self:QuietButton(self.home, "Fonts & colors", 392, 46, "fonts")
        self:ButtonIcon(fonts, "fonts", 30)
        fonts:SetPoint("TOPLEFT", 24, -203)
        fonts:SetScript("OnClick", function() FT:OpenModule("Appearance") end)
        local chat=self:QuietButton(self.home,"Chat",392,46,"chat")
        chat:SetPoint("TOPLEFT",24,-261); self:ButtonIcon(chat,"chat",30)
        chat:SetScript("OnClick",function() FT:OpenModule("Chat") end)
        local binds=self:QuietButton(self.home,"Custom keybinds",392,46,"mouseover")
        binds:SetPoint("TOPLEFT",24,-319); self:ButtonIcon(binds,"mouseover",30)
        binds:SetScript("OnClick",function() FT:OpenModule("CustomKeybinds") end)
        local system=self:QuietButton(self.home,"System",392,46,"generic")
        system:SetPoint("TOPLEFT",24,-377); self:ButtonIcon(system,"generic",30)
        system:SetScript("OnClick",function() FT:OpenModule("System") end)
    end
    if self.modules.Profiles then self.modules.Profiles:Attach(self.home) end
    self.home:Show()
end

-- Addon controls should never remain over combat gameplay. Saved changes remain
-- available; closing only hides the interface until the player opens it again.
local combatClose = CreateFrame("Frame")
combatClose:RegisterEvent("PLAYER_REGEN_DISABLED")
combatClose:SetScript("OnEvent", function()
    if FT.home then FT.home:Hide() end
    for _, module in pairs(FT.modules) do if module.frame then module.frame:Hide() end end
    if FT.modules.Profiles and FT.modules.Profiles.transfer then FT.modules.Profiles.transfer:Hide() end
    if FT.choiceMenu then FT.choiceMenu:Hide() end
    if FT.toast then FT.toast:Hide() end
end)

SLASH_FOREVERTOOLS1 = "/ft"
SlashCmdList.FOREVERTOOLS = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "macro" or command == "macros" then FT:OpenModule("MacroForge")
    elseif command == "fps" then FT:OpenModule("QualityOfLife")
    elseif command == "fonts" or command == "font" then FT:OpenModule("FontManager")
    elseif command == "colors" then FT:OpenModule("UnitColors")
    elseif command == "icons" or command == "skins" then FT:OpenModule("IconStyles")
    elseif command == "system" then FT:OpenModule("System")
    elseif command == "keybinds" then FT:OpenModule("CustomKeybinds")
    elseif command == "chat" then FT:OpenModule("Chat")
    elseif command == "appearance" then FT:OpenModule("Appearance")
    else FT:OpenHome() end
end
SLASH_FOREVERTOOLSRELOAD1 = "/rl"
SlashCmdList.FOREVERTOOLSRELOAD = function()
    if InCombatLockdown() then print("|cffc9a0ffForeverTools:|r Leave combat before reloading."); return end
    ReloadUI()
end

-- A scrollable choice menu shared by the advanced editor's class/spell/rank controls.
function FT:Dropdown(parent, width, options, onSelect, icon)
    local button = self:QuietButton(parent, "", width, 28, icon)
    button.options, button.onSelect = options, onSelect
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.label:SetPoint("RIGHT", -26, 0)
    local arrow = self:Label(button, "v", 12); arrow:SetPoint("RIGHT", -9, 0)
    button:SetScript("OnClick", function() FT:ShowChoices(button) end)
    parent:HookScript("OnHide", function() if FT.choiceMenu then FT.choiceMenu:Hide() end end)
    return button
end
function FT:ShowChoices(owner)
    if not self.choiceMenu then
        local menu = CreateFrame("Frame", nil, UIParent)
        self.choiceMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
        self:Panel(menu)
        menu.scroll = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
        menu.scroll:SetPoint("TOPLEFT", 8, -8); menu.scroll:SetPoint("BOTTOMRIGHT", -26, 8)
        menu.list = CreateFrame("Frame", nil, menu.scroll); menu.scroll:SetScrollChild(menu.list)
        menu.rows = {}; menu:Hide()
    end
    local menu = self.choiceMenu
    if menu:IsShown() and menu.owner == owner then menu:Hide(); return end
    menu.owner = owner
    local options = owner.options()
    local width = math.max(owner:GetWidth(), 180)
    menu:SetSize(width, math.min(9, math.max(1, #options)) * 30 + 16)
    menu:SetFrameLevel(owner:GetFrameLevel() + 30)
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3)
    menu.list:SetWidth(width - 34); menu.list:SetHeight(math.max(1, #options * 30))
    menu.scroll:SetVerticalScroll(0)
    for _, row in ipairs(menu.rows) do row:Hide() end
    for index, item in ipairs(options) do
        local row = menu.rows[index]
        if not row then
            row = self:QuietButton(menu.list, "", width - 34, 28, "macros")
            row:SetScript("OnClick", function(clicked)
                local current = menu.owner; local selected = clicked.item
                menu:Hide(); current.onSelect(selected.value)
            end)
            menu.rows[index] = row
        end
        row.item = item; row:SetWidth(width - 34); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
        row.label:SetText(item.label)
        row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_Note_01")
        self:SetSelected(row, owner.value == item.value)
        row:Show()
    end
    menu:Show()
end

function FT:Confirm(message,action)
    StaticPopupDialogs.FOREVERTOOLS_CONFIRM={text=message,button1="Confirm",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=action}
    StaticPopup_Show("FOREVERTOOLS_CONFIRM")
end
