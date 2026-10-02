local addonName, FT = ...
FT.name = addonName
FT.version = "0.50.0"
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
    -- Other addons named "ForeverTools" use the same folder and saved-settings
    -- name. Their leftovers (none of our keys) mean a fresh start for us, so
    -- first-time setup still shows; their old values are not carried over.
    local function foreign(t)
        if type(t) ~= "table" or next(t) == nil or t.schema ~= nil then return false end
        for _, key in ipairs({"profiles", "system", "iconStyles", "fonts", "fps", "setupDone", "lastSeenVersion",
            "minimapEnabled", "welcome", "buffReminder", "tooltip", "chat", "customMacros", "unitColors"}) do
            if t[key] ~= nil then return false end
        end
        return true
    end
    if foreign(ForeverToolsDB) then ForeverToolsDB = nil end
    if foreign(KrilarToolsDB) then KrilarToolsDB = nil end
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
-- Run fn once on the next frame (or after delay), however many times this is
-- called before then. Used so bursts of events lead to a single update.
function FT:Coalesce(key, fn, delay)
    self.coalesced = self.coalesced or {}
    if self.coalesced[key] then return end
    self.coalesced[key] = true
    C_Timer.After(delay or 0, function() self.coalesced[key] = nil; fn() end)
end
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
    self:Paint(frame, {0.075,0.058,0.04, 1}, {.61,.51,.31, 1})
end
-- A single rounded fill without the purple addon border, for dark overlays.
-- The outline shown around an element while you move it: the same rounded
-- panel, drawn "pad" pixels outside the frame so the text inside has room.
function FT:MoverBox(frame, pad)
    pad = pad or 0
    frame.borderTextures = layer(frame, -pad, -8)
    frame.fillTextures = layer(frame, -pad + 1, -7)
    self:Paint(frame, {0.075, 0.058, 0.04, 1}, {0.61, 0.51, 0.31, 1})
end
-- Captions next to a moving element ("Drag to move", its name): placed on
-- the preferred side, or the other side when that would leave the screen,
-- and lined up with the right edge when the left one would run off.
local captions, captionTicker = {}, CreateFrame("Frame")
local function rectOf(frame, pad)
    local top, bottom, left, right = frame:GetTop(), frame:GetBottom(), frame:GetLeft(), frame:GetRight()
    if not top or not left then return end
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    pad = pad or 0
    return {l = left * ratio - pad, r = right * ratio + pad, b = bottom * ratio - pad, t = top * ratio + pad}
end
local function overlaps(a, b) return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t end
-- All captions of one element move as a block (its name, then "Drag to
-- move"). The block tries above/below first, then right and left, and takes
-- the first spot that stays on screen and clear of the other elements being
-- moved and their captions.
local function placeAll()
    local groups, order, any = {}, {}, false
    for _, c in ipairs(captions) do
        if c.text:IsVisible() and c.frame:IsVisible() then
            any = true
            local g = groups[c.frame]
            if not g then g = {frame = c.frame, pad = c.pad or 0, list = {}}; groups[c.frame] = g; order[#order + 1] = g end
            g.pad = math.max(g.pad, c.pad or 0)
            -- Names (above) go first in the block, hints after.
            if c.side == "above" then table.insert(g.list, 1, c); g.preferAbove = true else g.list[#g.list + 1] = c end
        end
    end
    if not any then return false end
    local W, H, gap = UIParent:GetWidth(), UIParent:GetHeight(), 4
    local boxes, placed = {}, {}
    for _, g in ipairs(order) do g.rect = rectOf(g.frame, g.pad); if g.rect then boxes[#boxes + 1] = g end end
    for _, g in ipairs(boxes) do
        local r, bw, bh = g.rect, 0, 0
        for _, c in ipairs(g.list) do
            local scale = c.text:GetParent():GetEffectiveScale() / UIParent:GetEffectiveScale()
            c.w, c.h, c.scale = (c.text:GetStringWidth() or 60) * scale, (c.text:GetStringHeight() or 12) * scale, scale
            bw = math.max(bw, c.w); bh = bh + c.h + (bh > 0 and 2 or 0)
        end
        local leftX = (r.l + bw <= W) and r.l or (r.r - bw)
        local spots = {
            above = {l = leftX, r = leftX + bw, b = r.t + gap, t = r.t + gap + bh},
            below = {l = leftX, r = leftX + bw, t = r.b - gap, b = r.b - gap - bh},
            right = {l = r.r + gap, r = r.r + gap + bw, t = r.t, b = r.t - bh},
            left = {r = r.l - gap, l = r.l - gap - bw, t = r.t, b = r.t - bh},
        }
        local tries = g.preferAbove and {"above", "below", "right", "left"} or {"below", "above", "right", "left"}
        local chosen
        for _, name in ipairs(tries) do
            local spot, ok = spots[name], true
            if spot.l < 0 or spot.r > W or spot.b < 0 or spot.t > H then ok = false end
            if ok then for _, other in ipairs(boxes) do if other ~= g and overlaps(spot, other.rect) then ok = false; break end end end
            if ok then for _, other in ipairs(placed) do if overlaps(spot, other) then ok = false; break end end end
            if ok then chosen = spot; break end
        end
        chosen = chosen or spots[tries[1]]
        placed[#placed + 1] = chosen
        local y = chosen.t
        for _, c in ipairs(g.list) do
            c.text:ClearAllPoints()
            c.text:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", chosen.l / c.scale, y / c.scale)
            y = y - c.h - 2
        end
    end
    return true
end
captionTicker:Hide()
captionTicker:SetScript("OnUpdate", function(ticker, elapsed)
    ticker.elapsed = (ticker.elapsed or 0) + elapsed
    if ticker.elapsed < 0.02 then return end
    ticker.elapsed = 0
    if not placeAll() then ticker:Hide() end
end)
function FT:Caption(text, frame, side, pad)
    local c = {text = text, frame = frame, side = side, pad = pad}
    captions[#captions + 1] = c
    local function wake() if text:IsShown() then captionTicker:Show() end end
    hooksecurefunc(text, "Show", wake); hooksecurefunc(text, "SetShown", wake)
    if frame.HookScript then frame:HookScript("OnShow", wake) end
    return c
end
function FT:RoundedFill(frame, r, g, b, a)
    local textures = layer(frame, 0, -8)
    for _, texture in ipairs(textures) do texture:SetVertexColor(r, g, b, a or 1) end
    return textures
end
-- Window decoration: a soft purple band behind the title that fades out
-- downward, and a thin gold line under it that fades at both ends. Built from
-- the addon's own rounded texture and plain colored textures only.
local WHITE = "Interface\\Buttons\\WHITE8x8"
local function gradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    texture:SetTexture(WHITE)
    if CreateColor and texture.SetGradient then
        texture:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    else texture:SetVertexColor(r1, g1, b1, (a1 + a2) / 2) end
end
function FT:TitleBand(frame, lineY)
    if frame.titleBand then return end
    lineY = lineY or 48
    local r, g, b, a = 0.30, 0.23, 0.12, 0.55
    -- Rounded top edge (the same 8 px corners as the panel), then the fade.
    local cuts = {0, 0.25, 0.75, 1}
    frame.titleBand = {}
    for col = 0, 2 do
        local t = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        t:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Rounded.tga")
        t:SetTexCoord(cuts[col + 1], cuts[col + 2], 0, 0.25)
        t:SetVertexColor(r, g, b, a)
        local x1 = col == 0 and 1 or (col == 1 and 9 or -9)
        local x2 = col == 0 and 9 or (col == 1 and -9 or -1)
        t:SetPoint("TOPLEFT", frame, col == 2 and "TOPRIGHT" or "TOPLEFT", x1, -1)
        t:SetPoint("BOTTOMRIGHT", frame, col == 0 and "TOPLEFT" or "TOPRIGHT", x2, -9)
        frame.titleBand[#frame.titleBand + 1] = t
    end
    local fade = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    gradient(fade, "VERTICAL", r, g, b, 0, r, g, b, a)
    fade:SetPoint("TOPLEFT", 1, -9); fade:SetPoint("TOPRIGHT", -1, -9); fade:SetHeight(lineY + 6)
    frame.titleBand[#frame.titleBand + 1] = fade
    local gr, gg, gb = 0.79, 0.63, 0.29
    local left = frame:CreateTexture(nil, "ARTWORK")
    gradient(left, "HORIZONTAL", gr, gg, gb, 0, gr, gg, gb, 0.75)
    left:SetPoint("TOPLEFT", 1, -lineY); left:SetPoint("TOPRIGHT", frame, "TOP", 0, -lineY); left:SetHeight(1)
    local right = frame:CreateTexture(nil, "ARTWORK")
    gradient(right, "HORIZONTAL", gr, gg, gb, 0.75, gr, gg, gb, 0)
    right:SetPoint("TOPLEFT", frame, "TOP", 0, -lineY); right:SetPoint("TOPRIGHT", -1, -lineY); right:SetHeight(1)
    frame.titleLine = {left, right}
    frame.titleFade = fade
end
-- Move the gold line (and the fade) for windows with a taller header.
function FT:SetTitleLine(frame, lineY)
    if not frame.titleLine then return end
    local left, right = frame.titleLine[1], frame.titleLine[2]
    left:ClearAllPoints(); left:SetPoint("TOPLEFT", 1, -lineY); left:SetPoint("TOPRIGHT", frame, "TOP", 0, -lineY)
    right:ClearAllPoints(); right:SetPoint("TOPLEFT", frame, "TOP", 0, -lineY); right:SetPoint("TOPRIGHT", -1, -lineY)
    frame.titleFade:SetHeight(lineY + 6)
end
-- Section heading: a small icon before the text and a faint underline that
-- fades out to the right. Keeps the label's own position.
-- Pop-ups: drag anywhere on them to move them. Panels inside a window pass
-- the drag to their window (target), so the whole window moves together.
function FT:MakeDraggable(frame, target)
    target = target or frame
    target:SetMovable(true); target:SetClampedToScreen(true)
    frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() target:StartMoving() end)
    frame:SetScript("OnDragStop", function() target:StopMovingOrSizing() end)
end
-- Windows and panels fade in quickly (0.15 s) instead of popping up.
function FT:FadeIn(frame)
    if frame.fadeIn or not frame.CreateAnimationGroup then return end
    local group = frame:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0); alpha:SetToAlpha(1); alpha:SetDuration(0.15)
    frame.fadeIn = group
    frame:HookScript("OnShow", function() group:Stop(); group:Play() end)
end
-- Icons get softly rounded corners (the addon's own rounded shape as a
-- mask), the same everywhere. Safe to call more than once.
local ROUNDED = "Interface\\AddOns\\" .. addonName .. "\\Media\\Rounded.tga"
function FT:RoundIcon(texture)
    if not texture or texture.roundMask or not texture.AddMaskTexture then return texture end
    local parent = texture:GetParent()
    if not parent or not parent.CreateMaskTexture then return texture end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(ROUNDED, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask); texture.roundMask = mask
    return texture
end
function FT:SectionHeading(label, icon, lineWidth, iconSize)
    if not label or label.ftHeading then return label end
    local parent = label:GetParent()
    local _, size = label:GetFont()
    iconSize = iconSize or math.floor((size or 14) + 3)
    label.ftHeading = {icon = icon, size = iconSize}
    local line = parent:CreateTexture(nil, "ARTWORK")
    gradient(line, "HORIZONTAL", 0.61, 0.51, 0.31, 0.8, 0.61, 0.51, 0.31, 0)
    line:SetHeight(1); line:SetWidth(lineWidth or 180)
    label.ftHeading.line = line
    local function update()
        local text = label.ftHeading.raw or ""
        line:ClearAllPoints()
        line:SetPoint("LEFT", label, "LEFT", (label:GetStringWidth() or 0) + 8, 0)
        line:SetShown(label:IsShown() and text ~= "")
    end
    local setText = label.SetText
    label.SetText = function(owner, text)
        owner.ftHeading.raw = text
        local shown = text
        -- The icon is a real (rounded) texture over a see-through space
        -- in the text, so the text keeps its place.
        local heading = owner.ftHeading
        if text and text ~= "" and heading.icon then
            shown = "|T" .. ROUNDED .. ":" .. iconSize .. ":" .. iconSize .. ":0:0:32:32:0:1:0:1|t  " .. text
            if not heading.texture then
                heading.texture = FT:RoundIcon(parent:CreateTexture(nil, "ARTWORK"))
                heading.texture:SetSize(iconSize, iconSize); heading.texture:SetPoint("LEFT", owner, "LEFT", 0, 0)
                heading.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            end
            heading.texture:SetTexture("Interface\\Icons\\" .. heading.icon)
        end
        if heading.texture then heading.texture:SetShown(owner:IsShown() and text ~= nil and text ~= "" and heading.icon ~= nil) end
        setText(owner, shown); update()
    end
    function label:SetHeadingIcon(newIcon) self.ftHeading.icon = newIcon; self:SetText(self.ftHeading.raw) end
    local function icon() local t = label.ftHeading.texture; if t then t:SetShown(label:IsShown() and (label.ftHeading.raw or "") ~= "" and label.ftHeading.icon ~= nil) end end
    hooksecurefunc(label, "Show", function() update(); icon() end); hooksecurefunc(label, "Hide", function() line:Hide(); icon() end)
    if label.SetShown then hooksecurefunc(label, "SetShown", function() update(); icon() end) end
    label:SetText(label:GetText())
    return label
end
function FT:Label(parent, text, size, heading)
    local label = parent:CreateFontString(nil, "OVERLAY")
    -- If the addon's font file can't be read (for example the folder was
    -- replaced while the game runs), fall back to the game's own font: a
    -- label without a font errors on every text change.
    local okFont = label:SetFont(heading and self.headingFont or self.bodyFont, size or 14, "")
    if okFont == false or not label:GetFont() then label:SetFont("Fonts\\FRIZQT__.TTF", size or 14, "") end
    label:SetText(text)
    label:SetTextColor(0.95,0.90,0.81)
    label:SetJustifyH("LEFT")
    return label
end
-- Hover glow: a soft light inside the button's edges, shown only on hover.
local function hoverGlow(button)
    if button.glow then return button.glow end
    local glow = {}
    local r, g, b, a, depth = 0.79,0.64,0.35, 0.32, 7
    local sides = {
        {"TOPLEFT", "TOPRIGHT", "VERTICAL", false}, {"BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", true},
        {"TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", true}, {"TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", false},
    }
    for i, side in ipairs(sides) do
        local t = button:CreateTexture(nil, "BORDER")
        t:SetBlendMode("ADD")
        -- Bright at the edge, fading toward the middle.
        if side[4] then gradient(t, side[3], r, g, b, a, r, g, b, 0) else gradient(t, side[3], r, g, b, 0, r, g, b, a) end
        -- Kept clear of the rounded corners so the glow never pokes outside.
        if i <= 2 then
            local y = i == 1 and -2 or 2
            t:SetPoint(side[1], 6, y); t:SetPoint(side[2], -6, y); t:SetHeight(depth)
        else
            local x = i == 3 and 2 or -2
            t:SetPoint(side[1], x, -6); t:SetPoint(side[2], x, 6); t:SetWidth(depth)
        end
        t:Hide(); glow[i] = t
    end
    button.glow = glow
    return glow
end
function FT:UpdateButton(button)
    if button.hover or button.glow then
        local on = button.hover and (not button.IsEnabled or button:IsEnabled())
        for _, t in ipairs(hoverGlow(button)) do t:SetShown(on and true or false) end
    end
    if button.outline then
        -- A different kind of button: an action rather than a page.
        if button.hover then self:Paint(button, {0.16, 0.12, 0.07, 1}, {1, 0.84, 0.5, 1})
        else self:Paint(button, {0.07, 0.06, 0.08, 1}, {0.78, 0.62, 0.34, 1}) end
        return
    end
    if button.selected then
        self:Paint(button, {0.33,0.25,0.11, 1}, {0.85,0.68,0.36, 1})
    elseif button.hover then
        self:Paint(button, {0.17,0.13,0.09, 1}, {0.79,0.64,0.35, 1})
    elseif button.accent then
        self:Paint(button, {0.20,0.155,0.09, 1}, {0.55,0.44,0.24, 1})
    else
        self:Paint(button, {0.12,0.095,0.065, 1}, {0.29,0.24,0.15, 1})
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
    FT:RoundIcon(button.icon)
    if icon == "delete" then
        button.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        button.icon:SetTexCoord(0,1,0,1)
        if button.icon.roundMask then button.icon:RemoveMaskTexture(button.icon.roundMask); button.icon.roundMask = nil end
    end
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 8, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.label:SetJustifyH("LEFT")
end
-- A gold plus in place of a button's icon: "add this here".
function FT:PlusIcon(button)
    local icon = button.icon; if not icon then return end
    icon:SetTexture(nil); icon:SetAlpha(0)
    local across = button:CreateTexture(nil, "ARTWORK"); across:SetColorTexture(1, .82, 0, 1); across:SetSize(12, 2); across:SetPoint("CENTER", icon, "CENTER")
    local up = button:CreateTexture(nil, "ARTWORK"); up:SetColorTexture(1, .82, 0, 1); up:SetSize(2, 12); up:SetPoint("CENTER", icon, "CENTER")
    button.plus = {across, up}
end
-- A small cog centred on a square button: "more options".
local gearTexture
function FT:GearIcon(button)
    if gearTexture == nil then
        local id = GetFileIDFromPath and GetFileIDFromPath("Interface\\Buttons\\UI-OptionsButton")
        gearTexture = (type(id) == "number" and id > 0) and id or false
    end
    local icon = button:CreateTexture(nil, "ARTWORK"); icon:SetSize(16, 16); icon:SetPoint("CENTER")
    if gearTexture then icon:SetTexture(gearTexture)
    else icon:SetTexture("Interface\\Icons\\" .. self.icons.generic); icon:SetTexCoord(.07, .93, .07, .93); icon:SetSize(20, 20); self:RoundIcon(icon) end
    button.gear = icon
    if button.label then button.label:Hide() end
end
function FT:Tooltip(button, title, body)
    button:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1,.82,0)
        GameTooltip:AddLine(type(body) == "function" and body() or body, .96,.93,.86, true)
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
-- One place for a page's explanation: an (i) in the title bar, left of
-- Back. Single controls explain themselves in their own tooltips.
function FT:PageInfo(frame, title, text)
    if frame.pageInfo then self:Tooltip(frame.pageInfo, title, text); return frame.pageInfo end
    local info = self:Info(frame, title, text)
    info:SetPoint("RIGHT", frame.homeButton or frame.closeButton, "LEFT", -8, 0)
    frame.pageInfo = info
    self:LayoutTitle(frame)
    return info
end
-- The game's damage meter look for notices and dialogs: its dark header
-- bar (the whole notice, or the top of a dialog) over its background art,
-- referenced from the game, not bundled. Falls back to our panel.
local function atlasOK(name) return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil end
function FT:MeterSkin(frame, headerHeight)
    if not atlasOK("ui-damagemeters-header-bar") then return false end
    for _, t in ipairs(frame.fillTextures or {}) do t:SetAlpha(0) end
    for _, t in ipairs(frame.borderTextures or {}) do t:SetAlpha(0) end
    if not frame.meterBody and atlasOK("damagemeters-background") and headerHeight then
        frame.meterBody = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame.meterBody:SetAtlas("damagemeters-background"); frame.meterBody:SetAllPoints()
        -- A solid backing so text stays readable over bright ground.
        frame.meterShade = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        frame.meterShade:SetColorTexture(0, 0, 0, .75); frame.meterShade:SetAllPoints()
    end
    if not frame.meterHeader then
        frame.meterHeader = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        frame.meterHeader:SetAtlas("ui-damagemeters-header-bar")
        frame.meterHeader:SetPoint("TOPLEFT"); frame.meterHeader:SetPoint("TOPRIGHT")
    end
    if headerHeight then frame.meterHeader:SetHeight(headerHeight) else frame.meterHeader:SetPoint("BOTTOM") end
    frame.meterSkinned = true
    return true
end
function FT:Toast(message, seconds)
    if not self.toast then
        local frame = CreateFrame("Frame", "ForeverToolsToast", UIParent)
        frame:SetSize(270, 42); frame:SetPoint("TOP", UIParent, "TOP", 0, -135); frame:SetFrameStrata("DIALOG")
        self:Panel(frame); self:MeterSkin(frame)
        frame.text = self:Label(frame, "", 14, true); frame.text:SetPoint("CENTER"); frame.text:SetWidth(242); frame.text:SetJustifyH("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
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
    -- Hover: gold text, then back to whatever color the label had.
    button:SetScript("OnEnter", function(owner)
        owner.hover = true; FT:UpdateButton(owner)
        if owner.label and not owner.outline then owner.restColor = {owner.label:GetTextColor()}; owner.label:SetTextColor(1, 0.82, 0) end
    end)
    button:SetScript("OnLeave", function(owner)
        owner.hover = false; FT:UpdateButton(owner)
        if owner.restColor then owner.label:SetTextColor(unpack(owner.restColor)); owner.restColor = nil end
    end)
    if icon and label~="+" and label~="-" and label~="-" then self:ButtonIcon(button, icon) end
    self:UpdateButton(button)
    return button
end
function FT:AccentButton(parent, label, width, height, icon)
    local button = self:QuietButton(parent, label, width, height, icon)
    button.accent = true
    self:UpdateButton(button)
    return button
end
-- The one close button every ForeverTools window, dialog and panel uses:
-- Blizzard's standard X, 28 px, in the top-right corner. Windows and dialogs
-- use a 14 px corner inset; panels inside a window use 8 px.
function FT:AddClose(frame, onClick, inset)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton = close
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -(inset or 14), -(inset or 14))
    close:SetFrameLevel(frame:GetFrameLevel() + 5)
    close:SetScript("OnClick", onClick or function() frame:Hide() end)
    return close
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
    titleText:SetTextColor(1,.82,0)
    local close = self:AddClose(frame)
    self:TitleBand(frame)
    self:FadeIn(frame)
    -- One pattern everywhere: settings windows have "Back" (to the page they
    -- were opened from; the main menu for top-level pages) and the close X.
    -- Pop-ups and dialogs have only the X.
    if name ~= "ForeverToolsHome" then
        local home = self:QuietButton(frame, "Back", 88, 28, "home")
        frame.homeButton = home
        home:SetPoint("RIGHT", close, "LEFT", -8, 0)
        home:SetScript("OnClick", function() FT:OpenHome() end)
        local arrow = GetFileIDFromPath and GetFileIDFromPath("Interface\\Icons\\misc_arrowleft")
        if type(arrow) == "number" and arrow > 0 then home.icon:SetTexture(arrow) end
    end
    self:TitleTools(frame)
    -- The profile switcher lives only on the home window (Profiles button).
    if UISpecialFrames then table.insert(UISpecialFrames, name) end
    frame:HookScript("OnHide",function()
        -- Closing a settings page saves its changes into the profile.
        if frame.noSavePrompt then return end
        C_Timer.After(0,function() if FT.modules.Profiles then FT.modules.Profiles:AutoSave() end end)
    end)
    frame:Hide()
    return frame
end
function FT:OpenHome()
    if self:CombatOpenRequest() then return end
    local resume = self.resumeModule
    if resume then
        self.resumeModule = nil
        local now = GetTime and GetTime() or 0
        if self.modules[resume] and now - (self.resumeAt or 0) < 300 then self:OpenModule(resume); return end
    end
    for _, module in pairs(self.modules) do if module.frame then module.frame:Hide() end end
    if not self.home then
        self.home = self:Window("ForeverToolsHome", "ForeverTools", 540, 372)
        self.home.titleText:SetText("ForeverTools")
        -- One quiet line: version and author.
        local version = self:Label(self.home, "v" .. self.version .. "  |cff7d705c·  By Krilar|r", 11)
        version:SetPoint("BOTTOMLEFT", 20, 13); version:SetTextColor(.66,.59,.48)
        if self.modules.Search then self.modules.Search:Attach(self.home) end
        self.home.profileStatus=self:Label(self.home, "", 12)
        self.home.profileStatus:SetPoint("TOPRIGHT", -24, -61)
        self.home.profileStatus:SetWidth(210)
        self.home.profileStatus:SetJustifyH("RIGHT")
        -- Eight buttons in two columns, each with a short line saying what's
        -- inside, so they need no tooltips.
        local tools={
            {"Macros","MacroForge","macros","Ready-made class macros, editing and macro room"},
            {"Buff reminders","BuffReminder","buffs","Self and group buffs, low ranks and cooldowns"},
            {"Appearance","Appearance","fonts","Fonts, unit colors, skins and chat"},
            {"Tooltip","Tooltip","tooltip","Layout, extras, text sizes and position"},
            {"Combat","SystemCombat","Ability_Warrior_DefensiveStance","Threat meter, rare alerts and totems"},
            {"Keybinds","SystemKeybinds","keybind","Quick keybind, spell binds, wheel casting and smart key"},
            {"System","System","generic","General, minimap, gameplay, merchant and more"},
            {"Profiles",nil,"profiles","Save, load and share your setups"},
        }
        for i,entry in ipairs(tools) do
            local row=math.floor((i-1)/2);local column=(i-1)%2
            local button=self:QuietButton(self.home,entry[1],240,52,entry[3])
            self:ButtonIcon(button,entry[3],32)
            -- Macros: the game's own macro window icon.
            -- It is round art: use the square inside the circle, so the rounded
            -- corners match the other buttons.
            if entry[3]=="macros" then button.icon:SetTexture("Interface\\MacroFrame\\MacroFrame-Icon"); button.icon:SetTexCoord(.16,.84,.16,.84) end
            button:SetPoint("TOPLEFT",24+column*252,-90-row*60)
            -- Name, then the description on up to two lines; the pair sits
            -- centered in the button whether the description takes one line or two.
            button.label:ClearAllPoints(); button.label:SetWidth(240-60)
            button.sub=self:Label(button,entry[4],11); button.sub:SetTextColor(.66,.59,.48)
            button.sub:SetWidth(240-60); button.sub:SetJustifyH("LEFT"); button.sub:SetWordWrap(true)
            if button.sub.SetMaxLines then button.sub:SetMaxLines(2) end
            local subHeight=math.min(26,button.sub:GetStringHeight() or 13)
            local top=math.floor((52-(15+2+subHeight))/2)
            button.label:SetPoint("TOPLEFT",button,"TOPLEFT",52,-top)
            button.sub:SetPoint("TOPLEFT",button.label,"BOTTOMLEFT",0,-2)
            if entry[2] then
                button:SetScript("OnClick",function() FT:OpenModule(entry[2]) end)
            else
                button:SetScript("OnClick",function() if FT.modules.Profiles then FT.modules.Profiles:TogglePanel() end end)
            end
        end
    end
    if self.modules.Profiles then self.modules.Profiles:Attach(self.home) end
    self.home:Show()
end

-- Addon controls should never remain over combat gameplay. Saved changes remain
-- available; closing only hides the interface until the player opens it again.
function FT:CloseCombatControls()
    -- Remember the page that was open, so opening ForeverTools again right
    -- after combat brings you back to it instead of the main menu.
    for name, module in pairs(self.modules) do
        if module.frame and module.frame.IsShown and module.frame:IsShown() then
            self.resumeModule, self.resumeAt = name, GetTime and GetTime() or 0
        end
    end
    -- Windows that wait for an answer (setup, what's new) come back after
    -- combat; their own buttons still close them for good.
    for frame in pairs(self.controlWindows or {}) do
        if frame.keepAfterCombat and frame:IsShown() then self.reopenAfterCombat=self.reopenAfterCombat or {}; self.reopenAfterCombat[frame]=true end
        frame:Hide()
    end
    if self.home then self.home:Hide() end
    for _,module in pairs(self.modules) do
        for _,key in ipairs({"frame","transfer","panel","saveDialog","advancedPanel","previewFrame","rolePrompt"}) do
            local frame=module[key];if frame and frame.Hide then frame:Hide() end
        end
    end
    for _,key in ipairs({"choiceMenu","minimapMenu","toast"}) do if self[key] then self[key]:Hide() end end
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
    if event=="PLAYER_REGEN_DISABLED" then FT:CloseCombatControls(); return end
    if InCombatLockdown() then return end
    local reopen=FT.reopenAfterCombat; FT.reopenAfterCombat=nil
    for frame in pairs(reopen or {}) do frame:Show() end
    if FT.openAfterCombat then
        FT.openAfterCombat=nil;FT:OpenHome()
    end
end)

SLASH_FOREVERTOOLS1 = "/ft"
SlashCmdList.FOREVERTOOLS = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "macro" or command == "macros" then FT:OpenModule("MacroForge")
    elseif command == "fps" then FT:OpenModule("QualityOfLife")
    elseif command == "move" then if FT.modules.Movers then FT.modules.Movers:Toggle() end
    elseif command == "fonts" or command == "font" then FT:OpenModule("FontManager")
    elseif command == "colors" then FT:OpenModule("UnitColors")
    elseif command == "icons" or command == "skins" then FT:OpenModule("IconStyles")
    elseif command == "system" then FT:OpenModule("System")
    elseif command == "tooltip" or command == "tips" then FT:OpenModule("Tooltip")
    elseif command == "keybinds" then FT:OpenModule("CustomKeybinds")
    elseif command == "threat" then FT:OpenModule("Threat")
    elseif command == "start" then if FT.modules.Onboarding then FT.modules.Onboarding:ShowDemo() end
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
            -- Items may carry their own tooltip (for example a list of changes).
            row:HookScript("OnEnter", function(owner)
                local item = owner.item
                if not item or not item.tooltip then return end
                GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
                GameTooltip:SetText(item.tooltipTitle or item.label, 1,.82,0)
                GameTooltip:AddLine(type(item.tooltip) == "function" and item.tooltip() or item.tooltip, .96,.93,.86, true)
                GameTooltip:Show()
            end)
            row:HookScript("OnLeave", function() GameTooltip:Hide() end)
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
        -- Unavailable choices stay visible (greyed) and explain themselves on hover.
        if row.SetMotionScriptsWhileDisabled then row:SetMotionScriptsWhileDisabled(true) end
        row:SetEnabled(not item.disabled); row:SetAlpha(item.disabled and .45 or 1)
        row:Show()
    end
    menu:Show()
end

-- Point a subpage's Home button back to its hub, like Appearance.
-- Title bar tools on the main menu and settings pages: Move elements (the
-- menu stays open while you move) and minimize. Pop-ups (no Back button)
-- don't get them. Laid out right to left each time the window opens.
local moveTexture
local function moveIcon()
    if moveTexture == nil then
        local id = GetFileIDFromPath and GetFileIDFromPath("Interface\\CURSOR\\UI-Cursor-Move")
        moveTexture = (type(id) == "number" and id > 0) and id or false
    end
    return moveTexture
end
function FT:TitleTools(frame)
    local move = self:QuietButton(frame, "", 28, 28)
    move.icon = move:CreateTexture(nil, "ARTWORK"); move.icon:SetSize(20, 20); move.icon:SetPoint("CENTER")
    local texture = moveIcon()
    if texture then move.icon:SetTexture(texture)
    else move.icon:SetTexture("Interface\\Icons\\" .. self.icons.move); move.icon:SetTexCoord(.07, .93, .07, .93); self:RoundIcon(move.icon) end
    move:SetScript("OnClick", function() if FT.modules.Movers then FT.modules.Movers:Toggle() end end)
    self:Tooltip(move, "Move elements", "Unlock all ForeverTools elements on screen and drag them where you like. This window shrinks to its title bar meanwhile and opens again when you click Done (or this button again).")
    local min = self:QuietButton(frame, "", 28, 28)
    -- A gold dash; minimized, a second bar turns it into a plus.
    min.dash = min:CreateTexture(nil, "ARTWORK"); min.dash:SetColorTexture(1, .82, 0, 1); min.dash:SetSize(12, 2); min.dash:SetPoint("CENTER", 0, -4)
    min.bar = min:CreateTexture(nil, "ARTWORK"); min.bar:SetColorTexture(1, .82, 0, 1); min.bar:SetSize(2, 12); min.bar:SetPoint("CENTER"); min.bar:Hide()
    min:SetScript("OnClick", function() FT:SetMinimized(frame, not frame.minimized) end)
    self:Tooltip(min, "Minimize", function() return frame.minimized and "Show the whole window again." or "Shrink this window to its title bar. Drag it anywhere." end)
    frame.moveButton, frame.minButton = move, min
    frame:HookScript("OnShow", function() FT:LayoutTitle(frame); FT:SetSelected(move, FT.modules.Movers and FT.modules.Movers.active) end)
    frame:HookScript("OnHide", function() if frame.minimized then FT:SetMinimized(frame, false) end end)
end
function FT:LayoutTitle(frame)
    local tools = frame.homeButton == nil or frame.homeButton:IsShown()
    local chain = { frame.closeButton }
    if frame.homeButton and frame.homeButton:IsShown() then chain[#chain + 1] = frame.homeButton end
    if frame.minButton then frame.minButton:SetShown(tools); if tools then chain[#chain + 1] = frame.minButton end end
    if frame.moveButton then frame.moveButton:SetShown(tools); if tools then chain[#chain + 1] = frame.moveButton end end
    if frame.pageInfo then chain[#chain + 1] = frame.pageInfo end
    for i = 2, #chain do chain[i]:ClearAllPoints(); chain[i]:SetPoint("RIGHT", chain[i - 1], "LEFT", -8, 0) end
end
function FT:RefreshMoveButtons(active)
    for frame in pairs(self.controlWindows or {}) do
        if frame.moveButton then self:SetSelected(frame.moveButton, active) end
    end
end
-- Minimized: only the title bar is left (title, info, move, minimize, Back, close).
function FT:SetMinimized(frame, on)
    on = on == true
    if (frame.minimized == true) == on then return end
    if on then
        local keep = {}
        for _, key in ipairs({ "titleText", "closeButton", "homeButton", "moveButton", "minButton", "pageInfo" }) do
            if frame[key] then keep[frame[key]] = true end
        end
        for _, key in ipairs({ "fillTextures", "borderTextures", "titleBand" }) do for _, t in ipairs(frame[key] or {}) do keep[t] = true end end
        if frame.titleFade then frame.fadeHeight = frame.titleFade:GetHeight(); frame.titleFade:SetHeight(44) end
        frame.hiddenForMin = {}
        for _, list in ipairs({ { frame:GetRegions() }, { frame:GetChildren() } }) do
            for _, obj in ipairs(list) do
                if not keep[obj] and obj:IsShown() then obj:Hide(); frame.hiddenForMin[#frame.hiddenForMin + 1] = obj end
            end
        end
        frame.fullHeight = frame:GetHeight()
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top) end
        frame:SetHeight(56)
    else
        if frame.fullHeight then frame:SetHeight(frame.fullHeight) end
        if frame.titleFade and frame.fadeHeight then frame.titleFade:SetHeight(frame.fadeHeight) end
        for _, obj in ipairs(frame.hiddenForMin or {}) do obj:Show() end
        frame.hiddenForMin = nil
    end
    frame.minimized = on
    if frame.minButton then
        frame.minButton.dash:ClearAllPoints(); frame.minButton.dash:SetPoint("CENTER", 0, on and 0 or -4)
        frame.minButton.bar:SetShown(on)
    end
end
-- A scroll frame's bar only shows while there is something to scroll.
-- A typing line for a multi-line text box: a gold line that blinks where
-- the text cursor is, and a click in the text puts the cursor there. The box
-- gets no cursor of its own from the game here, so both are done by hand:
-- the box's text is laid out again with a hidden measuring text to turn a
-- click into a place in the text and back. Call after the box's own scripts
-- are set (it only hooks). "inset" is the box's text inset.
function FT:TextCaret(box, inset)
    inset = inset or 6
    local caret = box:CreateTexture(nil, "OVERLAY"); caret:SetTexture("Interface\\Buttons\\WHITE8x8")
    caret:SetSize(2, 17); caret:SetVertexColor(1, .82, 0, 1); caret:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset); caret:Hide()
    local measure = box:CreateFontString(nil, "OVERLAY"); measure:Hide()
    if measure.SetWordWrap then measure:SetWordWrap(false) end
    local state = {moved = 0}
    local function width(text)
        local font, size, flags = box:GetFont()
        if not font then return 0 end
        if state.font ~= font or state.size ~= size or state.flags ~= flags then
            state.font, state.size, state.flags = font, size, flags
            measure:SetFont(font, size, flags or ""); state.lines = nil; state.lineHeight = nil
        end
        measure:SetText(text)
        local w = measure.GetUnboundedStringWidth and measure:GetUnboundedStringWidth()
        if type(w) ~= "number" then w = measure:GetStringWidth() end
        return type(w) == "number" and w or 0
    end
    local function lineHeight()
        if state.cursorHeight then return state.cursorHeight end
        if not state.lineHeight then
            width("Ag"); local one = measure:GetStringHeight()
            if measure.SetWordWrap then measure:SetWordWrap(true) end
            measure:SetText("Ag\nAg"); local two = measure:GetStringHeight()
            if measure.SetWordWrap then measure:SetWordWrap(false) end
            local h = type(one) == "number" and type(two) == "number" and two - one or 0
            state.lineHeight = h > 4 and h or (tonumber(state.size) or 14) + 3
        end
        return state.lineHeight
    end
    -- Byte positions where a character ends (text can hold multi-byte letters).
    local function ends(text)
        local list = {}
        for i = 1, #text do
            local nextByte = text:byte(i + 1)
            if not nextByte or nextByte < 128 or nextByte >= 192 then list[#list + 1] = i end
        end
        return list
    end
    -- The text as the box shows it: one entry per line on screen, with the
    -- position in the whole text where that line starts.
    local function lines()
        local text = box:GetText() or ""
        local limit = (box:GetWidth() or 0) - inset * 2
        width("")
        if state.lines and state.text == text and state.limit == limit then return state.lines end
        local out, start = {}, 0
        for logical in (text .. "\n"):gmatch("(.-)\n") do
            local rest, offset = logical, start
            while limit > 20 and width(rest) > limit do
                -- The longest piece that fits, ending after a space when there is one.
                local stops = ends(rest); local low, high = 1, #stops
                while low < high do
                    local middle = math.floor((low + high + 1) / 2)
                    if width(rest:sub(1, stops[middle])) <= limit then low = middle else high = middle - 1 end
                end
                local cut = stops[low] or #rest
                local space = rest:sub(1, cut):match(".*() ")
                if space and space > 1 then cut = space end
                if cut >= #rest then break end
                out[#out + 1] = {start = offset, text = rest:sub(1, cut)}
                rest = rest:sub(cut + 1); offset = offset + cut
            end
            out[#out + 1] = {start = offset, text = rest}
            start = start + #logical + 1
        end
        state.lines, state.text, state.limit = out, text, limit
        return out
    end
    local function place(x, y, height)
        caret:ClearAllPoints(); caret:SetPoint("TOPLEFT", box, "TOPLEFT", x + inset, -(y + inset))
        caret:SetHeight(math.max(13, height or lineHeight()))
        if state.x ~= x or state.y ~= y then state.x, state.y = x, y; state.moved = GetTime() end
    end
    -- Where a position in the text is on screen (from the top left of the text).
    local function locate(index)
        local list = lines(); local row = 1
        for i = 1, #list do if list[i].start <= index then row = i else break end end
        local line = list[row]
        local within = math.max(0, math.min(#line.text, index - line.start))
        return width(line.text:sub(1, within)), (row - 1) * lineHeight()
    end
    -- The position in the text nearest to a point on screen.
    local function indexAt(x, y)
        local list = lines()
        local row = math.max(1, math.min(#list, math.floor(y / lineHeight()) + 1))
        local line = list[row]
        local best, distance = 0, math.abs(x)
        for _, stop in ipairs(ends(line.text)) do
            local d = math.abs(width(line.text:sub(1, stop)) - x)
            if d < distance then best, distance = stop, d end
        end
        -- The space a wrapped line ends with belongs before the break.
        if best == #line.text and list[row + 1] and list[row + 1].start == line.start + #line.text and best > 0 then best = best - 1 end
        return line.start + best
    end
    local function follow()
        local index = box:GetCursorPosition()
        if type(index) ~= "number" or index == state.index then return end
        state.index = index
        local x, y = locate(index); place(x, y)
    end
    -- The game tells us where the cursor is when it moves it itself.
    box:HookScript("OnCursorChanged", function(_, x, y, _, height)
        if type(x) ~= "number" or type(y) ~= "number" then return end
        if type(height) == "number" and height > 4 then state.cursorHeight = height end
        local index = box:GetCursorPosition(); if type(index) == "number" then state.index = index end
        place(x, -y, height)
    end)
    box:HookScript("OnTextChanged", function() state.lines = nil end)
    -- Blink like a normal text cursor; solid for a moment after it moves.
    local driver = CreateFrame("Frame", nil, box); driver:Hide()
    driver:SetScript("OnUpdate", function()
        follow()
        caret:SetAlpha(((GetTime() - state.moved) % 1.06) < .56 and 1 or 0)
    end)
    box:HookScript("OnEditFocusGained", function() state.moved = GetTime(); caret:SetAlpha(1); caret:Show(); driver:Show() end)
    box:HookScript("OnEditFocusLost", function() caret:Hide(); driver:Hide(); state.before = nil; state.index = nil end)
    box:HookScript("OnHide", function() caret:Hide(); driver:Hide() end)
    -- A click in the text: if the game did not move the cursor there, we do.
    box:EnableMouse(true)
    box:HookScript("OnMouseDown", function() state.before = state.index end)
    box:HookScript("OnMouseUp", function(_, button)
        if button and button ~= "LeftButton" then return end
        local now = box:GetCursorPosition()
        if state.before ~= nil and now ~= state.before then return end
        local left, top, scale = box:GetLeft(), box:GetTop(), box:GetEffectiveScale()
        if type(left) ~= "number" or type(top) ~= "number" or type(scale) ~= "number" or scale <= 0 then return end
        local cx, cy = GetCursorPosition()
        if type(cx) ~= "number" or type(cy) ~= "number" then return end
        local index = indexAt(cx / scale - left - inset, top - cy / scale - inset)
        if box.HasFocus and not box:HasFocus() then box:SetFocus() end
        box:SetCursorPosition(index)
        state.index = index
        local x, y = locate(index); place(x, y); state.moved = GetTime()
    end)
    box.ftCaret = {texture = caret, locate = locate, indexAt = indexAt, lines = lines, state = state, driver = driver}
    return caret
end
-- onChange(needed), if given, runs when the bar appears or goes, so the
-- content can use the full width while there is no bar.
function FT:AutoHideScrollBar(scroll, onChange)
    local bar = scroll and (scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"]))
    if not bar then return end
    local last
    local function update(_, _, yRange)
        if yRange == nil and scroll.GetVerticalScrollRange then yRange = scroll:GetVerticalScrollRange() end
        local needed = type(yRange) == "number" and yRange > 1
        bar:SetShown(needed)
        if not needed and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
        if onChange and last ~= needed then last = needed; onChange(needed) end
    end
    scroll:HookScript("OnScrollRangeChanged", update)
    scroll:HookScript("OnShow", function() update() end)
    update()
end
function FT:BackTo(frame, moduleName)
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
        frame.hint:SetTextColor(.85,.80,.70)
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
-- Ask for a short text (a name) in the game's own pop-up with a text field.
function FT:AskText(title,start,onText,maxLetters)
    if InCombatLockdown() then return end
    local function clean(text) return type(text)=="string" and text:match("^%s*(.-)%s*$") or "" end
    local function box(popup) return popup.editBox or (popup.GetEditBox and popup:GetEditBox()) end
    StaticPopupDialogs.FOREVERTOOLS_ASK_TEXT={
        text=title,button1="OK",button2="Cancel",hasEditBox=true,maxLetters=maxLetters or 120,
        timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnShow=function(popup) local b=box(popup); if b then b:SetText(start or ""); b:HighlightText() end end,
        OnAccept=function(popup) local b=box(popup); onText(clean(b and b:GetText())) end,
        EditBoxOnEnterPressed=function(b) local popup=b:GetParent(); onText(clean(b:GetText())); popup:Hide() end,
        EditBoxOnEscapePressed=function(b) b:GetParent():Hide() end,
    }
    FT:ShowPopup("FOREVERTOOLS_ASK_TEXT")
end
-- Yes/no questions: the damage meter's look with the game's own buttons.
-- Escape or Cancel closes it; nothing happens unless you confirm.
function FT:Confirm(message,action)
    if InCombatLockdown() then return end
    if not self.confirm then
        local f = CreateFrame("Frame", "ForeverToolsConfirm", UIParent)
        f:SetSize(400, 150); f:SetPoint("CENTER", 0, 120); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetToplevel(true)
        f:EnableMouse(true); f:SetClampedToScreen(true)
        self:Panel(f); self:MeterSkin(f, 32)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed1"); f.title:SetPoint("TOPLEFT", 12, -9); f.title:SetText("ForeverTools")
        f.text = self:Label(f, "", 14); f.text:SetPoint("TOP", 0, -46); f.text:SetWidth(360); f.text:SetJustifyH("CENTER")
        f.yes = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.yes:SetSize(150, 26); f.yes:SetText("Confirm")
        f.no = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); f.no:SetSize(150, 26); f.no:SetText(CANCEL or "Cancel")
        f.yes:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 16); f.no:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 16)
        f.yes:SetScript("OnClick", function() local fn = f.action; f.action = nil; f:Hide(); if fn then fn() end end)
        f.no:SetScript("OnClick", function() f.action = nil; f:Hide() end)
        f:HookScript("OnHide", function() f.action = nil end)
        self:AddClose(f, function() f.action = nil; f:Hide() end, 2)
        if UISpecialFrames then table.insert(UISpecialFrames, "ForeverToolsConfirm") end
        f:Hide()
        self.confirm = f
    end
    local f = self.confirm
    f.action = action
    f.text:SetText(message)
    local h = f.text:GetStringHeight(); if type(h) ~= "number" then h = 40 end
    f:SetHeight(math.max(130, h + 104))
    f:Show(); f:Raise()
end
