local _, FT = ...
-- Groups of pages. Every page in a group shows the group's sections on its
-- left side (name and current state), like Macros and Buff reminders, so
-- you move between them with one click and never lose your place. A page
-- is still its own window: the sidebar is a panel joined to its left edge.
local SIDE, OVER = 232, 9 -- sidebar width; how far it covers the page's rounded left edge
local function onOff(v) return v and "On" or "Off" end
local function mod(name) return FT.modules[name] end
local function settings(name) local m = mod(name); return m and m.Settings and m:Settings() or {} end
local function count(list) local n = 0; for _, v in ipairs(list) do if v then n = n + 1 end end; return n end
local hubs = {
    {key = "Appearance", width = 760, height = 560, title = "Appearance", pages = {
        {"FontManager", "Fonts", "fonts", function() local m = mod("FontManager"); return m and m.Summary and m:Summary() or "Fonts, sizes and outlines" end},
        {"UnitColors", "Unit frames", function()
            -- Your own class's icon, like the switches on the page.
            local _, class = UnitClass("player")
            return "ClassIcon_" .. (class and (class:sub(1, 1) .. class:sub(2):lower()) or "Warrior")
        end, function()
            local s = settings("UnitColors"); local n = count({s.player, s.target, s.focus})
            return n == 0 and "Class colors off" or ("Class colors on " .. n .. " of 3")
        end},
        {"DispelGlow", "Dispel glow", "Spell_Holy_DispelMagic", function() return onOff(settings("DispelGlow").enabled) end},
        {"DruidMana", "Druid mana bar", "Ability_Racial_BearForm", function() return onOff(settings("UnitColors").druidMana) end},
        {"IconStyles", "Skins", "skins", function()
            local s = settings("IconStyles"); local n, total = 0, 0
            for _, entry in ipairs(mod("IconStyles").extraOptions or {}) do total = total + 1; if s[entry[1]] then n = n + 1 end end
            for _, key in ipairs({"actions", "buffs"}) do total = total + 1; if s[key] then n = n + 1 end end
            return n == 0 and "Off" or (n .. " of " .. total .. " areas on")
        end},
        {"Chat", "Chat", "chat", function() return "Buttons, font and links" end},
        {"Tooltip", "Tooltip", "tooltip", function() return "Layout, extras and position" end},
    }},
    {key = "SystemCombat", width = 540, height = 578, title = "Combat", pages = {
        {"Threat", "Threat meter", "Ability_Warrior_DefensiveStance", function() local t = settings("Threat"); return (t.enabled and "Meter on" or "Meter off") .. " · threat % " .. onOff(t.text):lower() end},
        {"RareAlert", "Rare alerts", "Ability_Hunter_SniperShot", function() return onOff(settings("RareAlert").enabled) end},
        {"Totems", "Totems", "Spell_Nature_StoneSkinTotem", function() local t = settings("Totems"); return onOff(t.range or t.leftBehind) end},
        {"SystemGameplay", "Group role", "Ability_Warrior_DefensiveStance", function() return onOff(settings("System").autoRole) end},
        {"SystemDeath", "Death glow", "Spell_Holy_Resurrection", function()
            local get = (C_CVar and C_CVar.GetCVar) or GetCVar
            local ok, value = pcall(function() return get and get("ffxDeath") end)
            if not ok or value == nil then return "The game's setting" end
            return onOff(value ~= "0")
        end},
    }},
    {key = "PvP", width = 540, height = 420, title = "PvP", pages = {
        {"QueueTimer", "Battleground timer", "INV_Misc_PocketWatch_01", function() return onOff(settings("QueueTimer").enabled) end},
    }},
    {key = "Keybinds", width = 520, height = 608, title = "Keybinds", pages = {
        {"SystemKeybinds", "Keybind tools", "keybind", function() return "Quick keybind and backups" end},
        {"SpellBinds", "Spell binds", "INV_Misc_Key_13", function() return onOff(settings("SpellBinds").enabled) end},
        {"CustomKeybinds", "Mouse-wheel casting", "mouseover", function() return onOff(settings("CustomKeybinds").enabled) end},
        {"SmartKey", "Smart interact key", "INV_Misc_Key_10", function() return onOff(settings("SmartKey").enabled) end},
    }},
    {key = "SystemDisplay", width = 540, height = 660, title = "On-screen info", pages = {
        {"QualityOfLife", "FPS counter", "fps", function() return onOff(settings("QualityOfLife").enabled) end},
        {"Leveling", "Leveling stats", "Spell_ChargePositive", function() return onOff(settings("Leveling").enabled) end},
        {"FlightTimer", "Flight timer", function() return FT:FlightIcon() end, function() return onOff(settings("FlightTimer").enabled) end},
        {"SystemMinimap", "Minimap", "map", function() return "Button, coordinates, grouping" end},
        {"SystemQuests", "Quests and loot rolls", "INV_Misc_Note_01", function() return "Tracker and roll position" end},
        {"Movers", "Move elements", "move", function() local m = mod("Movers"); return m and m.active and "Moving now" or "Drag things on screen" end},
    }},
    {key = "SystemHub", width = 520, height = 572, title = "System", pages = {
        {"SystemGeneral", "General", "general", function() return "Messages, setup, errors" end},
        {"SystemMerchant", "Loot and merchant", "INV_Misc_Coin_02", function()
            local s = settings("System")
            return "Sell " .. onOff(s.autoSell):lower() .. " · repair " .. onOff(s.autoRepair):lower()
        end},
        {"SellMarks", "Always-sell marks", "INV_Misc_Coin_01", function() local m = mod("SellMarks"); return m and m.On and m:On() and ("On (" .. m:Count() .. ")") or "Off" end},
    }},
}
-- What each section is, for its tooltip in the sidebar.
local tips = {
    FontManager = "Fonts, sizes and outlines for each kind of text on screen.",
    UnitColors = "Class-colored health bars on the player, target and focus frames.",
    DispelGlow = "A glow around unit frames that have a debuff you can remove.",
    DruidMana = "For druids: your mana as a third bar while you are in bear, cat or another form.",
    IconStyles = "Dark mode and other looks for action bars, buffs, bags, unit frames and more.",
    Chat = "Show or hide the buttons around the chat, and set the chat font and clickable links.",
    Tooltip = "What player tooltips show and in which order, text sizes, and where tooltips appear.",
    Threat = "A threat meter next to the damage meter, and your threat % above your target.",
    RareAlert = "A notice, and a sound if you like, when a rare is nearby.",
    Totems = "For shamans: totem range on the minimap, and a warning when you leave a totem behind.",
    SystemGameplay = "Set your role (tank, healer or damage) by itself when you join a group.",
    SystemDeath = "The glowing, washed-out screen while you are dead or a ghost.",
    QueueTimer = "A countdown of the time you have to enter when a battleground queue pops.",
    SystemKeybinds = "Bind action buttons by hovering them (/kb), and put earlier keybinds back.",
    SpellBinds = "Bind spells, items and macros straight to keys, without an action bar.",
    CustomKeybinds = "Cast a spell by scrolling the mouse wheel over a unit.",
    SmartKey = "One key for questing: it interacts, or uses RestedXP's quest item or target.",
    QualityOfLife = "A small frames-per-second counter.",
    Leveling = "XP per hour, time to level and more, on a small line and in the XP bar tooltip.",
    FlightTimer = "Where you are flying and how long until you land.",
    SystemMinimap = "The ForeverTools minimap button, coordinates, and grouping other addons' buttons.",
    SystemQuests = "How the quest tracker starts at login, and where loot-roll windows appear.",
    Movers = "Drag everything ForeverTools draws on screen, all at once.",
    SystemGeneral = "Login message, what's new, first-time setup, resetting, Lua errors and the bug report.",
    SystemMerchant = "Faster looting, and selling and repairing at merchants.",
    SellMarks = "Mark items in your bags with a key; marked items are sold at merchants.",
}
FT.hubs = hubs
local byPage = {}
for _, hub in ipairs(hubs) do
    for i, page in ipairs(hub.pages) do byPage[page[1]] = {hub = hub, index = i} end
end
function FT:HubOf(name) local entry = byPage[name]; return entry and entry.hub, entry and entry.index end
-- Open a group: the page of it you used last this session, or its first.
function FT:OpenHub(key)
    for _, hub in ipairs(hubs) do
        if hub.key == key then
            local target = hub.last and self.modules[hub.last] and hub.last or hub.pages[1][1]
            self:OpenModule(target)
            return
        end
    end
end
-- The modules behind the main-menu buttons only pass you on to a page.
for _, hub in ipairs(hubs) do
    local key = hub.key
    FT:RegisterModule(key, {redirect = true, Open = function() FT:OpenHub(key) end})
end
-- Older names of pages that moved.
FT:RegisterModule("SystemTroubleshooting", {redirect = true, Open = function() FT:OpenModule("SystemGeneral") end})
local function buildSidebar(frame, hub)
    local side = CreateFrame("Frame", nil, frame)
    side:SetPoint("TOPRIGHT", frame, "TOPLEFT", OVER, 0)
    side:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", OVER, 0)
    side:SetWidth(SIDE + OVER)
    FT:Panel(side, true)
    FT:TitleBand(side)
    -- The band ends straight where it meets the page's own band.
    if side.titleBand and side.titleBand[3] then side.titleBand[3]:SetTexCoord(0.25, 0.75, 0, 0.25) end
    if side.titleLine then
        local gr, gg, gb = 0.79, 0.63, 0.29
        FT.GradientTexture(side.titleLine[1], "HORIZONTAL", gr, gg, gb, 0, gr, gg, gb, 0.4)
        FT.GradientTexture(side.titleLine[2], "HORIZONTAL", gr, gg, gb, 0.4, gr, gg, gb, 0.75)
    end
    -- Dragging the sidebar moves the whole window.
    FT:MakeDraggable(side, frame)
    side.title = FT:Label(side, hub.title, 20, true)
    side.title:SetPoint("TOPLEFT", 22, -21); side.title:SetTextColor(1, .82, 0)
    side.buttons = {}
    for i, page in ipairs(hub.pages) do
        local name, title, icon = page[1], page[2], page[3]
        local b = FT:QuietButton(side, "", SIDE - 24, 46); b.label:Hide()
        b:SetPoint("TOPLEFT", 14, -62 - (i - 1) * 50)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(28, 28); b.icon:SetPoint("LEFT", 9, 0)
        if type(icon) == "function" then icon = icon() end
        b.icon:SetTexture("Interface\\Icons\\" .. (FT.icons[icon] or icon)); b.icon:SetTexCoord(.07, .93, .07, .93); FT:RoundIcon(b.icon)
        b.title = FT:Label(b, title, 14); b.title:SetPoint("TOPLEFT", 46, -7)
        b.meta = FT:Label(b, "", 11); b.meta:SetPoint("TOPLEFT", 46, -26); b.meta:SetWidth(SIDE - 24 - 52); b.meta:SetJustifyH("LEFT"); b.meta:SetTextColor(.72, .66, .55)
        if b.meta.SetWordWrap then b.meta:SetWordWrap(false) end
        if b.title.SetWordWrap then b.title:SetWordWrap(false) end
        b:SetScript("OnClick", function() if FT.modules[name] and FT.modules[name].frame ~= frame then FT:OpenModule(name) end end)
        FT:Tooltip(b, title, function()
            local ok, state = pcall(page[4])
            return (tips[name] or "") .. (ok and type(state) == "string" and state ~= "" and ("\n\nNow: " .. state) or "")
        end)
        side.buttons[i] = b
    end
    return side
end
FT.dockWidth = SIDE
function FT:RefreshDock(frame)
    local side = frame and frame.ftSidebar; if not side or not frame:IsShown() then return end
    local hub, index = side.hub, side.index
    for i, page in ipairs(hub.pages) do
        local b = side.buttons[i]
        local ok, text = pcall(page[4])
        b.meta:SetText(ok and type(text) == "string" and text or "")
        FT:SetSelected(b, i == index)
        if i == index then b.title:SetTextColor(1, .86, .55) else b.title:SetTextColor(0.95, 0.90, 0.81) end
    end
end
-- Join the group's sidebar to a page that has just been opened.
function FT:Dock(name)
    local hub, index = self:HubOf(name)
    local module = self.modules[name]
    local frame = module and module.frame
    if not hub or not frame then return end
    hub.last = name
    if not frame.ftSidebar then
        frame.ftSidebar = buildSidebar(frame, hub)
        frame.ftSidebar.hub, frame.ftSidebar.index = hub, index
        frame.ftDockWidth = SIDE
        if frame.SetClampRectInsets then frame:SetClampRectInsets(-SIDE, 0, 0, 0) end
        if frame.homeButton then frame.homeButton:SetScript("OnClick", function() FT:OpenHome() end) end
        if frame.titleLine then
            local gr, gg, gb = 0.79, 0.63, 0.29
            FT.GradientTexture(frame.titleLine[1], "HORIZONTAL", gr, gg, gb, 0.75, gr, gg, gb, 0.75)
        end
        -- Remember where the window is, so the next page of the group opens
        -- in the same place and the sidebar never jumps.
        frame:HookScript("OnHide", function()
            if frame.minimized then return end
            local left, top = frame:GetLeft(), frame:GetTop()
            if type(left) == "number" and type(top) == "number" then hub.left, hub.top = left, top end
        end)
        -- A page that refreshes itself (a switch was clicked) refreshes the sidebar too.
        if type(module.Refresh) == "function" then
            local refresh = module.Refresh
            module.Refresh = function(owner, ...) local a, b = refresh(owner, ...); FT:RefreshDock(frame); return a, b end
        end
    end
    -- Every page of a group has the group's size, so nothing jumps when you
    -- switch between them.
    if not frame.minimized then frame:SetSize(hub.width, hub.height) end
    frame:ClearAllPoints()
    if hub.left and hub.top then frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", hub.left, hub.top)
    else frame:SetPoint("CENTER", UIParent, "CENTER", SIDE / 2, 0) end
    self:RefreshDock(frame)
end
