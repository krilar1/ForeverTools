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
-- "9 of 22 added" for a macro list (the name of your class or race first).
local function macroCount(view, named)
    local m = mod("MacroForge"); if not m or not m.ViewCount or not FT.dbReady then return "" end
    local ok, added, total = pcall(m.ViewCount, m, view)
    if not ok then return "" end
    local who = ""
    if named then
        if view == "class" then local name = UnitClass("player"); who = (name or "") .. " · "
        else local name = UnitRace("player"); who = (name or "") .. " · " end
    end
    return who .. added .. " of " .. total .. " added"
end
-- The state of a Buff reminders section.
local function buffStatus(key)
    local m = mod("BuffReminder"); if not m or not m.PaneStatus or not FT.dbReady then return "" end
    local ok, text = pcall(m.PaneStatus, m, key)
    return ok and text or ""
end
local hubs = {
    {key = "Appearance", width = 620, height = 610, title = "Appearance", pages = {
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
        {"PersonalResource", "Game resource bars", "Ability_Rogue_SliceDice", function()
            local m = mod("PersonalResource"); if not m or not FT.dbReady then return "" end
            local s = m:Settings(); local text = 0
            for _, v in pairs(s.text) do if v ~= "game" then text = text + 1 end end
            return (s.order and "Own order" or "Game's order") .. (text > 0 and " · text changed" or "")
        end},
        {"IconStyles", "Skins", "skins", function()
            local s = settings("IconStyles"); local n, total = 0, 0
            for _, entry in ipairs(mod("IconStyles").extraOptions or {}) do total = total + 1; if s[entry[1]] then n = n + 1 end end
            for _, key in ipairs({"actions", "buffs"}) do total = total + 1; if s[key] then n = n + 1 end end
            return n == 0 and "Off" or (n .. " of " .. total .. " areas on")
        end},
        {"Chat", "Chat", "Interface\\GossipFrame\\GossipGossipIcon", function() return "Buttons, font and links" end},
        {"Tooltip", "Tooltip", "INV_Misc_Note_01", function() return "Layout, extras and position" end},
        {"ItemCounts", "Item counts", "INV_Misc_Gem_01", function()
            local B = FT.Bags; if not B then return "" end
            local s = B:Settings(); return s.counts and ({each = "Each character", total = "Total only", both = "Each and total"})[s.countStyle] or "Off"
        end},
    }},
    {key = "SystemCombat", width = 540, height = 578, title = "Combat", pages = {
        {"Threat", "Threat meter", "Spell_Nature_Reincarnation", function() local t = settings("Threat"); return (t.enabled and "Meter on" or "Meter off") .. " · threat % " .. onOff(t.text):lower() end},
        {"RareAlert", "Rare alerts", "INV_Misc_Head_Dragon_01", function() return onOff(settings("RareAlert").enabled) end},
        {"Totems", "Totems", "Spell_Nature_StoneSkinTotem", function() local t = settings("Totems"); return onOff(t.range or t.leftBehind) end},
        {"Interrupts", "Interrupt bar", "Ability_Kick", function() return onOff(settings("Interrupts").enabled) end},
        {"SystemGameplay", "Group role", "Ability_Warrior_DefensiveStance", function() local s = settings("System"); return "Role " .. onOff(s.autoRole):lower() end},
        {"SystemDeath", "Death glow", "Spell_Holy_Resurrection", function()
            local get = (C_CVar and C_CVar.GetCVar) or GetCVar
            local ok, value = pcall(function() return get and get("ffxDeath") end)
            if not ok or value == nil then return "The game's setting" end
            return onOff(value ~= "0")
        end},
    }},
    {key = "PvP", width = 540, height = 640, title = "PvP", pages = {
        {"EnemyAlerts", "Enemy alerts", "Ability_Stealth", function()
            local s = settings("Enemies")
            return (s.stealth and "Stealth on" or "Stealth off") .. " · marked " .. onOff(s.marks):lower()
        end},
        {"EnemyMarks", "Marked players", "Ability_Hunter_SniperShot", function()
            local n = 0; for _ in pairs(type(FT.db.enemyMarks) == "table" and FT.db.enemyMarks or {}) do n = n + 1 end
            return n == 0 and "None yet" or (n .. " marked")
        end},
        {"EnemyNearby", "Nearby enemies", "INV_Misc_Spyglass_02", function() return onOff(settings("Enemies").nearby) end},
        {"QueueTimer", "Battleground timer", "INV_Misc_PocketWatch_01", function() return onOff(settings("QueueTimer").enabled) end},
        {"Trinkets", "Trinket menu", function() return FT:FactionIcon() end, function() local on = settings("Trinkets").enabled; local T = FT.modules.Trinkets; if on and T and T.Worn and not T:Worn() then return "On · no trinket yet" end; return onOff(on) end},
        {"EnemyCooldowns", "Enemy cooldowns", "Spell_Holy_BorrowedTime", function() return onOff(settings("EnemyCooldowns").enabled) end},
        {"Diminish", "Diminishing returns", "Spell_Frost_FrostNova", function() return onOff(settings("Diminish").enabled) end},
        {"AutoRelease", "Auto release", "Spell_Holy_GuardianSpirit", function() return onOff(settings("AutoRelease").enabled) end},
    }},
    {key = "Keybinds", width = 520, height = 608, title = "Keybinds", pages = {
        {"SystemKeybinds", "Keybind tools", "INV_Misc_Key_03", function() return "Short keys " .. onOff(settings("System").shortKeys):lower() end},
        {"SpellBinds", "Spell binds", "INV_Misc_Key_13", function() return onOff(settings("SpellBinds").enabled) end},
        {"CustomKeybinds", "Mouse-wheel casting", "mouseover", function() return onOff(settings("CustomKeybinds").enabled) end},
        {"SmartKey", "Smart interact key", "INV_Misc_Key_10", function() return onOff(settings("SmartKey").enabled) end},
    }},
    {key = "SystemDisplay", width = 540, height = 660, title = "On-screen info", pages = {
        {"QualityOfLife", "FPS counter", "INV_Gizmo_01", function() return onOff(settings("QualityOfLife").enabled) end},
        {"Leveling", "Leveling stats", "Spell_ChargePositive", function() return onOff(settings("Leveling").enabled) end},
        {"FlightTimer", "Flight timer", function() return FT:FlightIcon() end, function() return onOff(settings("FlightTimer").enabled) end},
        {"SystemMinimap", "Minimap", "map", function() return "Button, coordinates, grouping" end},
        {"SystemQuests", "Quests and loot rolls", "INV_Misc_Book_08", function() return "Tracker and roll position" end},
        {"SystemErrors", "Error messages", "Ability_Rogue_Disguise", function() local s = settings("System"); return s.hideErrors and (s.errorsInCombat and "Hidden in a fight" or "Hidden") or "Shown" end},
        {"Movers", "Move elements", "move", function() local m = mod("Movers"); return m and m.active and "Moving now" or "Drag things on screen" end},
        {"MoveWindows", "Move game windows", "Ability_Hunter_Pathfinding", function() local s = settings("MoveWindows"); local n = 0; for _ in pairs(s.frames or {}) do n = n + 1 end; return s.enabled and (n > 0 and n .. " moved" or "On") or "Off" end},
    }},
    -- Starts to the right, clear of the game's own macro window (left side).
    {key = "MacrosHub", width = 600, height = 660, shiftX = 220, title = "Macros", pages = {
        {"MacroForge", "My class", function()
            local _, class = UnitClass("player")
            return "ClassIcon_" .. (class and (class:sub(1, 1) .. class:sub(2):lower()) or "Warrior")
        end, function() return macroCount("class", true) end},
        {"MacroRace", "My race", "INV_Misc_Head_Human_01", function() return macroCount("race", true) end},
        {"MacroGeneric", "Generic", "INV_Misc_Gear_01", function() return macroCount("generic") end},
        {"MacroOwn", "My own macros", "INV_Feather_05", function()
            local m = mod("MacroForge"); if not m or not m.ViewEntries then return "" end
            -- Removed (hidden) macros don't count.
            local n = 0
            for _, e in ipairs(m:ViewEntries("own")) do if not (m.IsHidden and m:IsHidden(e)) then n = n + 1 end end
            return n == 0 and "None yet" or (n .. " made by you")
        end},
        {"MacroOther", "Other classes", "classes", function() return "Look at an alt's macros" end},
        {"MacroHidden", "Hidden", "Spell_Magic_LesserInvisibilty", function()
            local m = mod("MacroForge"); local n = m and m.HiddenCount and m:HiddenCount() or 0
            return n == 0 and "None" or (n .. " hidden")
        end},
        {"MacroGuide", "Macro guide", "INV_Misc_Book_03", function() return "Examples, explained" end},
        {"MacroSettings", "Settings", "INV_Misc_Wrench_01", function()
            local db = FT.db or {}
            return (db.macroScope == "account" and "General" or "Character") .. " · mouseover " .. (db.macroBulkMouseover and "on" or "off")
        end},
    }},
    {key = "BuffsHub", width = 520, height = 720, title = "Buff reminders", pages = {
        {"BuffReminder", "Your buffs", "Spell_Holy_WordFortitude", function() return buffStatus("self") end},
        {"BuffGroup", "Group buffs", "Spell_Holy_PrayerOfFortitude", function() return buffStatus("group") end},
        {"BuffRanks", "Low ranks", "INV_Misc_Book_07", function() return buffStatus("rank") end},
        {"BuffLook", "Look and position", "Spell_Holy_MagicalSentry", function() return buffStatus("look") end},
        {"CooldownReminder", "Cooldown reminders", "Spell_Nature_TimeStop", function() return onOff(settings("CooldownReminder").enabled) end},
    }},
    {key = "ProfilesHub", width = 520, height = 560, title = "Profiles", pages = {
        {"Profiles", "Profiles", "INV_Misc_Book_04", function() local m = mod("Profiles"); return m and m.SidebarStatus and m:SidebarStatus("list") or "" end},
        {"ProfilesShare", "Export and import", "INV_Misc_Note_06", function() return "Backups and other computers" end},
        {"ProfilesUndo", "Earlier versions", "INV_Misc_PocketWatch_02", function() local m = mod("Profiles"); return m and m.SidebarStatus and m:SidebarStatus("undo") or "" end},
        {"ProfilesNew", "New characters", "INV_Misc_Toy_07", function() local m = mod("Profiles"); return m and m.SidebarStatus and m:SidebarStatus("new") or "" end},
        {"ProfilesReset", "Default settings", "Spell_Holy_Purify", function() return "Start over" end},
    }},
    {key = "BagsHub", width = 540, height = 440, title = "Bags", pages = {
        {"BagsGeneral", "Bags", "INV_Misc_Bag_09", function()
            local B = FT.Bags; if not B then return "" end
            local s = B:Settings(); local n = count({s.gold, s.view, s.counts})
            return n == 0 and "Off" or (n .. " of 3 on")
        end},
        {"BagsCharacters", "Characters", "Spell_Holy_PrayerofSpirit", function()
            local B = FT.Bags; if not B then return "" end
            local n = 0; local st = FT.db and FT.db.bagStore
            if type(st) == "table" and type(st.chars) == "table" then for _ in pairs(st.chars) do n = n + 1 end end
            return B:Recording() and (n .. " remembered") or "Not remembering"
        end},
        {"BagsOrder", "Bag order", "INV_Misc_Bag_10", function()
            local O = FT.BagOrder; if not O or not FT.Bags then return "" end
            return O:Summary()
        end},
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
    FontManager = "Fonts, sizes and outlines.",
    UnitColors = "Class colors on player, target and focus.",
    DispelGlow = "A glow on frames with a debuff you can remove.",
    PersonalResource = "The order and text of the game's resource bars.",
    DruidMana = "Druids: mana as a third bar in forms.",
    IconStyles = "Dark mode and other looks.",
    Chat = "Chat buttons, font, links and copy.",
    Tooltip = "What player tooltips show, and where.",
    ItemCounts = "Item counts per character on tooltips.",
    BagsGeneral = "Everyone's gold, bank anywhere, alts' bags.",
    BagsCharacters = "The characters ForeverTools remembers.",
    Threat = "Threat meter and threat % above your target.",
    RareAlert = "A notice when a rare is nearby.",
    Totems = "Shamans: totem range and left-behind warning.",
    SystemGameplay = "Your group role, set from your talents.",
    SystemDeath = "The washed-out screen while dead.",
    EnemyAlerts = "Alerts for stealth and marked players.",
    EnemyMarks = "Players you marked.",
    EnemyNearby = "Enemy players you saw recently.",
    QueueTimer = "Time left to enter a battleground.",
    Diminish = "When crowd control will be shorter, or won't land.",
    SystemKeybinds = "Bind keys by hovering (/kb), short key text on buttons, and backups.",
    SpellBinds = "Bind spells, items and macros to keys.",
    CustomKeybinds = "Cast by scrolling over a unit.",
    SmartKey = "One key to interact while questing.",
    QualityOfLife = "A small frames-per-second counter.",
    Leveling = "XP per hour, time to level and more.",
    FlightTimer = "Time until you land.",
    SystemMinimap = "Minimap button, coordinates, button grouping.",
    SystemQuests = "Quest tracker at login, loot-roll position.",
    Interrupts = "Your group's interrupts and cooldowns.",
    EnemyCooldowns = "Big cooldowns enemy players have used.",
    SystemErrors = "Hide the red error text.",
    Movers = "Drag ForeverTools' things on screen.",
    MoveWindows = "Drag the game's own windows.",
    SystemGeneral = "Messages, setup, reset and bug report.",
    SystemMerchant = "Faster looting, selling and repairing.",
    SellMarks = "Mark bag items to sell at merchants.",
    MacroForge = "Ready-made macros for your class.",
    MacroRace = "Macros for your race's own abilities.",
    MacroGeneric = "Macros for any class.",
    MacroOwn = "Macros you made yourself.",
    MacroOther = "Look at another class's macros, for an alt.",
    MacroHidden = "Macros you hid or removed.",
    BuffReminder = "A notice when one of your buffs is missing.",
    BuffGroup = "A notice when your group is missing your buff.",
    BuffRanks = "Warnings for spells below your best rank.",
    BuffLook = "Size, timing and place of notices.",
    CooldownReminder = "A reminder to use a ready cooldown.",
    Profiles = "Switch, make, copy or delete profiles.",
    ProfilesShare = "Export your setup as text, or import one.",
    ProfilesUndo = "Put an earlier version back.",
    ProfilesNew = "Which profile a new character starts with.",
    ProfilesReset = "Back to the game's defaults.",
    MacroGuide = "Every kind of macro, with examples.",
    MacroSettings = "Where macros go, mouseover, icons, clean-up.",
}
FT.hubs = hubs
local byPage
-- Built on first use (after login, when your class is known): pages for
-- another class are left out of their group.
local function index()
    if byPage then return byPage end
    byPage = {}
    for _, hub in ipairs(hubs) do
        local shown = {}
        for _, page in ipairs(hub.pages) do if FT:ForMyClass(page[1]) then shown[#shown + 1] = page end end
        hub.pages = shown
        for i, page in ipairs(hub.pages) do byPage[page[1]] = {hub = hub, index = i} end
    end
    return byPage
end
function FT:HubOf(name) local entry = index()[name]; return entry and entry.hub, entry and entry.index end
-- Open a group: the page of it you used last this session, or its first.
function FT:OpenHub(key)
    index()
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
-- Pages for one class only: other classes never see them (menu or search).
FT.classOnly = {Totems = "SHAMAN", DruidMana = "DRUID"}
function FT:ForMyClass(name)
    local class = self.classOnly[name]
    if not class then return true end
    local _, mine = UnitClass("player")
    return mine == nil or mine == class
end
function FT:IconPath(icon)
    icon = FT.icons[icon] or icon
    -- A full path (a picture that is not a spell icon) is used as it is.
    if type(icon) == "string" and icon:find("\\", 1, true) then return icon end
    return "Interface\\Icons\\" .. icon
end
local function buildSidebar(frame, hub)
    index()
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
        b.icon:SetTexture(FT:IconPath(icon)); b.icon:SetTexCoord(.07, .93, .07, .93); FT:RoundIcon(b.icon)
        b.title = FT:Label(b, title, 14); b.title:SetPoint("TOPLEFT", 46, -7)
        b.meta = FT:Label(b, "", 11); b.meta:SetPoint("TOPLEFT", 46, -26); b.meta:SetWidth(SIDE - 24 - 52); b.meta:SetJustifyH("LEFT"); b.meta:SetTextColor(.72, .66, .55)
        if b.meta.SetWordWrap then b.meta:SetWordWrap(false) end
        if b.title.SetWordWrap then b.title:SetWordWrap(false) end
        -- Pages can share one window (Macros): what counts is which page is showing.
        b:SetScript("OnClick", function() if FT.modules[name] and (FT.modules[name].frame ~= frame or side.index ~= i or not frame:IsShown()) then FT:OpenModule(name) end end)
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
function FT:Dock(name, stays)
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
        if frame.homeButton then frame.homeButton:SetScript("OnClick", function() FT:Back() end) end
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
        if type(module.Refresh) == "function" and not module.ownDockRefresh then
            local refresh = module.Refresh
            module.Refresh = function(owner, ...) local a, b = refresh(owner, ...); FT:RefreshDock(frame); return a, b end
        end
    end
    -- Pages that share one window (Macros) light their own button.
    frame.ftSidebar.index = index
    -- Every page of a group has the group's size, so nothing jumps when you
    -- switch between them.
    -- (A page with few settings may be narrower: module.pageWidth. The
    -- window's left edge and the sidebar stay where they are.)
    if not frame.minimized then frame:SetSize(module.pageWidth or hub.width, hub.height) end
    -- Already open (another page of the same window): it stays put.
    if not stays then
        frame:ClearAllPoints()
        if hub.left and hub.top then frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", hub.left, hub.top)
        else frame:SetPoint("CENTER", UIParent, "CENTER", SIDE / 2 + (hub.shiftX or 0), 0) end
    end
    self:RefreshDock(frame)
end
