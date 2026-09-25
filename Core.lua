local addonName, FT = ...
FT.name = addonName
FT.version = "0.13.6"
FT.modules = {}
FT.headingFont = "Fonts\\FRIZQT__.TTF"
FT.bodyFont = "Fonts\\ARIALN.TTF"
-- SavedVariables are ready at our ADDON_LOADED, not while these files execute.
-- Initialize once and keep every module on the same table throughout the session.
FT.db = {}
function FT:InitializeDB()
    if self.dbReady then return end
    -- A fresh install has no saved table (or an empty one) under either name.
    local function empty(t) return type(t) ~= "table" or next(t) == nil end
    self.freshInstall = empty(ForeverToolsDB) and empty(KrilarToolsDB)
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
    for _, filename in ipairs({"Inter-Regular.ttf", "expressway.ttf", "expressway.otf"}) do
        local path = "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\" .. filename
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
function FT:CombatOpenRequest()
    if not InCombatLockdown() then return false end
    if not self.openAfterCombat then
        print("ForeverTools will open after combat.")
    end
    self.openAfterCombat=true
    return true
end
function FT:TrackColorPicker()
    self.colorPickerOpen=true
    if ColorPickerFrame and not self.colorPickerWatched then
        self.colorPickerWatched=true
        ColorPickerFrame:HookScript("OnHide",function() FT.colorPickerOpen=nil end)
    end
end
function FT:ShowPopup(key,...)
    if InCombatLockdown() then return end
    return StaticPopup_Show(key,...)
end
function FT:OpenModule(name)
    if self:CombatOpenRequest() then return end
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
-- A single rounded fill without the purple addon border, for dark overlays.
function FT:RoundedFill(frame, r, g, b, a)
    local textures = layer(frame, 0, -8)
    for _, texture in ipairs(textures) do texture:SetVertexColor(r, g, b, a or 1) end
    return textures
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
    confirm = "Spell_Holy_SealOfSacrifice", tooltip = "INV_Misc_Note_01", keybind = "INV_Misc_Key_03", errors = "Spell_Shadow_UnholyFrenzy", spellID = "INV_Misc_Book_07",
    buffs = "Spell_Holy_WordFortitude",
    party = "Spell_Holy_PrayerOfFortitude",
}
function FT:ButtonIcon(button, icon, size)
    if not button.icon then button.icon = button:CreateTexture(nil, "ARTWORK") end
    local pixels = size or math.min(20, button:GetHeight() - 8)
    button.icon:SetSize(pixels, pixels)
    button.icon:SetPoint("LEFT", 9, 0)
    if icon=="classes" or icon=="character" then
        local _,class=UnitClass("player")
        class=class and (class:sub(1,1)..class:sub(2):lower()) or "Warrior"
        button.icon:SetTexture("Interface\\Icons\\ClassIcon_"..class)

    else button.icon:SetTexture("Interface\\Icons\\" .. (self.icons[icon] or icon)) end
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
        GameTooltip.ftAddonHelp = true
        local tooltipModule = FT.modules.Tooltip
        if tooltipModule and tooltipModule.RestoreTooltipFont then tooltipModule:RestoreTooltipFont(GameTooltip) end
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
function FT:Toast(message, seconds)
    if not self.toast then
        local frame = CreateFrame("Frame", "ForeverToolsToast", UIParent)
        frame:SetSize(270, 42); frame:SetPoint("TOP", UIParent, "TOP", 0, -135); frame:SetFrameStrata("DIALOG")
        self:Panel(frame)
        frame.text = self:Label(frame, "", 14, true); frame.text:SetPoint("CENTER"); frame.text:SetWidth(242); frame.text:SetJustifyH("CENTER")
        self.toast = frame
    end
    local toast = self.toast; toast.text:SetText(message)
    toast:SetHeight(math.max(42, (toast.text:GetStringHeight() or 16) + 24)); toast:Show()
    toast.token = (toast.token or 0) + 1
    local token = toast.token
    C_Timer.After(seconds or 2.2, function() if toast and toast.token == token then toast:Hide() end end)
end
function FT:QuietButton(parent, label, width, height, icon)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    self:Panel(button)
    button.label = self:Label(button, label, 14)
    button.label:SetPoint("CENTER")
    button:SetScript("OnEnter", function(owner) owner.hover = true; FT:UpdateButton(owner) end)
    button:SetScript("OnLeave", function(owner) owner.hover = false; FT:UpdateButton(owner) end)
    if icon and label~="+" and label~="−" and label~="-" then self:ButtonIcon(button, icon) end
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
    self.controlWindows=self.controlWindows or {}
    self.controlWindows[frame]=true
    frame:HookScript("OnShow",function(owner) if InCombatLockdown() then owner:Hide() end end)
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
    if name~="ForeverToolsHome" then
        title=title:gsub("^ForeverTools%s*|%s*", "")
    end
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
    -- The profile switcher lives only on the home window (Profiles button).
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    frame:HookScript("OnHide",function()
        -- Only settings pages can hold unsaved changes; info windows never ask.
        if frame.noSavePrompt then return end
        C_Timer.After(0,function() if FT.modules.Profiles then FT.modules.Profiles:OfferSave() end end)
    end)
    frame:Hide()
    return frame
end
function FT:OpenHome()
    if self:CombatOpenRequest() then return end
    for _, module in pairs(self.modules) do if module.frame then module.frame:Hide() end end
    if not self.home then
        self.home = self:Window("ForeverToolsHome", "ForeverTools", 440, 364)
        self.home.titleText:SetText("ForeverTools")
        local version = self:Label(self.home, "v" .. self.version, 11)
        version:SetPoint("BOTTOMLEFT", 18, 13); version:SetTextColor(0.66, 0.57, 0.77)
        local credit = self:Label(self.home, "Made by Krilar", 11)
        credit:SetPoint("BOTTOMRIGHT", -18, 13); credit:SetTextColor(0.66, 0.57, 0.77)
        if self.modules.Search then self.modules.Search:Attach(self.home) end
        self.home.profileStatus=self:Label(self.home, "", 12)
        self.home.profileStatus:SetPoint("TOPRIGHT", -24, -61)
        self.home.profileStatus:SetWidth(190)
        self.home.profileStatus:SetJustifyH("RIGHT")
        local tools={
            {"Macros","MacroForge","macros"},{"Buff reminders","BuffReminder","buffs"},
            {"FPS counter","QualityOfLife","fps"},{"Fonts & colors","Appearance","fonts"},
            {"Chat","Chat","chat"},{"Tooltip","Tooltip","tooltip"},
            {"Custom keybinds","CustomKeybinds","keybind"},{"System","System","generic"},
        }
        for i,entry in ipairs(tools) do
            local row=math.floor((i-1)/2);local column=(i-1)%2
            local button=self:QuietButton(self.home,entry[1],190,46,entry[3])
            self:ButtonIcon(button,entry[3],26)
            button:SetPoint("TOPLEFT",24+column*202,-86-row*58)
            button:SetScript("OnClick",function() FT:OpenModule(entry[2]) end)
            self:Tooltip(button,entry[1],"Open "..entry[1].." settings.")
        end
    end
    if self.modules.Profiles then self.modules.Profiles:Attach(self.home) end
    self.home:Show()
end

-- Addon controls should never remain over combat gameplay. Saved changes remain
-- available; closing only hides the interface until the player opens it again.
function FT:CloseCombatControls()
    for frame in pairs(self.controlWindows or {}) do frame:Hide() end
    if self.home then self.home:Hide() end
    for _,module in pairs(self.modules) do
        for _,key in ipairs({"frame","transfer","panel","saveDialog","advancedPanel","previewFrame","rolePrompt"}) do
            local frame=module[key];if frame and frame.Hide then frame:Hide() end
        end
    end
    for _,key in ipairs({"choiceMenu","minimapMenu","toast"}) do if self[key] then self[key]:Hide() end end
    local profiles=self.modules.Profiles
    if profiles and profiles.prompting then profiles:DismissSave(false,true) end
    if StaticPopup_Hide then
        for key in pairs(StaticPopupDialogs or {}) do
            if type(key)=="string" and key:match("^FOREVERTOOLS_") then StaticPopup_Hide(key) end
        end
    end
    if ColorPickerFrame and self.colorPickerOpen then ColorPickerFrame:Hide();self.colorPickerOpen=nil end
    if GameTooltip and GameTooltip.ftAddonHelp then GameTooltip:Hide() end
end
local combatClose = CreateFrame("Frame")
combatClose:RegisterEvent("PLAYER_REGEN_DISABLED")
combatClose:RegisterEvent("PLAYER_REGEN_ENABLED")
combatClose:SetScript("OnEvent", function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then FT:CloseCombatControls()
    elseif FT.openAfterCombat and not InCombatLockdown() then
        FT.openAfterCombat=nil;FT:OpenHome()
    end
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
    elseif command == "tooltip" or command == "tips" then FT:OpenModule("Tooltip")
    elseif command == "keybinds" then FT:OpenModule("CustomKeybinds")
    elseif command == "wheeldebug" then FT.modules.CustomKeybinds:Debug()
    elseif command == "buffs" or command == "reminders" then FT:OpenModule("BuffReminder")
    elseif command == "chat" then FT:OpenModule("Chat")
    elseif command == "appearance" then FT:OpenModule("Appearance")
    else FT:OpenHome() end
end
SLASH_FOREVERTOOLSRELOAD1 = "/rl"
SlashCmdList.FOREVERTOOLSRELOAD = function()
    -- Same as Blizzard's /reload, which works in combat; ReloadUI is not protected.
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
    if self:CombatOpenRequest() then return end
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
    local width = math.max(owner:GetWidth(), owner.menuWidth or 180)
    menu:SetSize(width, math.min(9, math.max(1, #options)) * 30 + 16)
    -- Only show the scroll bar when the list is longer than the menu.
    local scrolls = #options > 9
    local bar = menu.scroll.ScrollBar or (menu.scroll.GetName and menu.scroll:GetName() and _G[menu.scroll:GetName() .. "ScrollBar"])
    if bar then bar:SetShown(scrolls) end
    menu.scroll:ClearAllPoints(); menu.scroll:SetPoint("TOPLEFT", 8, -8); menu.scroll:SetPoint("BOTTOMRIGHT", scrolls and -26 or -8, 8)
    local inner = scrolls and 34 or 16
    menu:SetFrameLevel(owner:GetFrameLevel() + 30)
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3)
    menu.list:SetWidth(width - inner); menu.list:SetHeight(math.max(1, #options * 30))
    menu.scroll:SetVerticalScroll(0)
    for _, row in ipairs(menu.rows) do row:Hide() end
    for index, item in ipairs(options) do
        local row = menu.rows[index]
        if not row then
            row = self:QuietButton(menu.list, "", width - inner, 28, "macros")
            row:SetScript("OnClick", function(clicked)
                local current = menu.owner; local selected = clicked.item
                menu:Hide(); current.onSelect(selected.value)
            end)
            menu.rows[index] = row
        end
        row.item = item; row:SetWidth(width - inner); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
        row.label:SetText(item.label)
        row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_Note_01")
        self:SetSelected(row, owner.value == item.value)
        row:Show()
    end
    menu:Show()
end

-- Point a subpage's Home button back to its hub, like Fonts & colors.
function FT:BackTo(frame, moduleName)
    frame.homeButton.label:SetText("Back")
    frame.homeButton:SetScript("OnClick", function() FT:OpenModule(moduleName) end)
end
-- Secondary windows (setup, what's new, copy boxes, profile transfer) open in
-- the middle. If a ForeverTools window is already open, they sit beside it on
-- the side with the most room instead of covering it.
function FT:PlaceBeside(frame)
    local anchor
    local function consider(other)
        if other and other ~= frame and other.IsShown and other:IsShown() and other:GetLeft() then anchor = anchor or other end
    end
    consider(self.home)
    for _, module in pairs(self.modules) do consider(module.frame) end
    frame:ClearAllPoints()
    if not anchor then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0); return end
    local scale = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local left, right = anchor:GetLeft() * scale, anchor:GetRight() * scale
    local top, bottom = anchor:GetTop() * scale, anchor:GetBottom() * scale
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local w, h = frame:GetWidth(), frame:GetHeight()
    local room = { RIGHT = width - right, LEFT = left, TOP = height - top, BOTTOM = bottom }
    local fits = { RIGHT = room.RIGHT >= w + 16, LEFT = room.LEFT >= w + 16, TOP = room.TOP >= h + 16, BOTTOM = room.BOTTOM >= h + 16 }
    local best
    for _, side in ipairs({ "RIGHT", "LEFT", "TOP", "BOTTOM" }) do
        if fits[side] and (not best or room[side] > room[best]) then best = side end
    end
    if best == "RIGHT" then frame:SetPoint("LEFT", anchor, "RIGHT", 12, 0)
    elseif best == "LEFT" then frame:SetPoint("RIGHT", anchor, "LEFT", -12, 0)
    elseif best == "TOP" then frame:SetPoint("BOTTOM", anchor, "TOP", 0, 12)
    elseif best == "BOTTOM" then frame:SetPoint("TOP", anchor, "BOTTOM", 0, -12)
    else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
end
-- A read-only text box the player can select and copy with Ctrl+C.
-- Nothing is sent anywhere; the text only leaves the game if the player pastes it.
function FT:CopyBox(title, text, hint, tall)
    if self:CombatOpenRequest() then return end
    local frame = self.copyBox
    if not frame then
        frame = self:Window("ForeverToolsCopyBox", title, 560, 200)
        frame.noSavePrompt = true
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame.homeButton:Hide()
        frame.hint = self:Label(frame, "", 12); frame.hint:SetPoint("TOPLEFT", 24, -58); frame.hint:SetWidth(512)
        frame.hint:SetTextColor(0.78, 0.74, 0.86)
        frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        local box = CreateFrame("EditBox", nil, frame.scroll)
        box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFont(self.bodyFont, 13, "")
        box:SetWidth(488); box:SetTextInsets(4, 4, 4, 4)
        box:SetScript("OnEscapePressed", function() frame:Hide() end)
        -- Read-only: typing restores the original text.
        box:SetScript("OnTextChanged", function(owner, user) if user then owner:SetText(frame.original or ""); owner:HighlightText() end end)
        box:SetScript("OnEditFocusGained", function(owner) owner:HighlightText() end)
        frame.scroll:SetScrollChild(box); frame.box = box
        self.copyBox = frame
    end
    frame.titleText:SetText(title)
    frame.hint:SetText(hint or "Press Ctrl+C to copy, then Escape to close.")
    -- Place the text below the hint, however many lines the hint wraps to.
    local hintHeight = math.max(14, frame.hint:GetStringHeight() or 14)
    frame:SetHeight((tall and 440 or 180) + hintHeight)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", 24, -(58 + hintHeight + 14)); frame.scroll:SetPoint("BOTTOMRIGHT", -42, 22)
    self:PlaceBeside(frame)
    frame.original = text or ""
    frame.box:SetText(frame.original)
    frame:Show()
    frame.box:SetFocus(); frame.box:HighlightText()
end
function FT:Confirm(message,action)
    if InCombatLockdown() then return end
    StaticPopupDialogs.FOREVERTOOLS_CONFIRM={text=message,button1="Confirm",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=action}
    FT:ShowPopup("FOREVERTOOLS_CONFIRM")
end
