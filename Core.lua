local addonName, FT = ...
FT.name = addonName
FT.version = "1.0.0"
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
    -- A practice tour (/ft start) cut short by a reload or logout: put every
    -- setting back the way it was before it started.
    local trial = self.db.tourTrial
    if type(trial) == "table" then
        local profiles = self.modules.Profiles
        local settings = type(trial.settings) == "table" and trial.settings or {}
        for _, key in ipairs(profiles and profiles.keys or {}) do self.db[key] = settings[key] end
        self.db.tour, self.db.setupDone, self.db.setupAsked = trial.tour, trial.setupDone, trial.setupAsked
        self.db.tourTrial = nil
    end
    self.dbReady = true
end
local databaseEvents = CreateFrame("Frame")
-- Looks wait for the end of a fight, except right after a /reload in one.
function FT:LooksWait() return InCombatLockdown() and not self.combatReload end
databaseEvents:RegisterEvent("ADDON_LOADED")
databaseEvents:RegisterEvent("PLAYER_LOGOUT")
databaseEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
databaseEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
-- A /reload during a fight: looks (skins, fonts, colours) are put on right
-- away instead of after the fight, or the game would look bare. The game may
-- only report the fight after loading, so this holds from loading until the
-- world is shown (no fight) or until the fight ends.
local function redoLooks()
    for _, name in ipairs({"IconStyles", "FontManager", "UnitColors"}) do
        local m = FT.modules[name]
        if m and m.Apply then pcall(m.Apply, m) end
    end
end
FT.redoLooks = redoLooks
databaseEvents:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        FT.combatReload = true
        FT:InitializeDB()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not FT.combatReload then return end
        local fighting = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player"))
        if fighting then
            -- Anything that waited during loading is put on now.
            C_Timer.After(0, function() if FT.dbReady and FT.combatReload then redoLooks() end end)
        else
            C_Timer.After(2, function() if not InCombatLockdown() then FT.combatReload = nil end end)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then FT.combatReload = nil
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
-- ForeverTools windows sit in the FULLSCREEN layer, above the elements they
-- preview; the game's color picker and pop-ups opened from them go above.
function FT:TrackColorPicker()
    self.colorPickerOpen=true
    if ColorPickerFrame then ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG"); ColorPickerFrame:Raise() end
    if ColorPickerFrame and not self.colorPickerWatched then
        self.colorPickerWatched=true
        ColorPickerFrame:HookScript("OnHide",function() FT.colorPickerOpen=nil end)
    end
end
function FT:ShowPopup(key,...)
    if InCombatLockdown() then return end
    local dialog=StaticPopup_Show(key,...)
    if dialog and dialog.SetFrameStrata then
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        if not dialog.ftStrataHooked then dialog.ftStrataHooked=true; dialog:HookScript("OnHide",function(d) d:SetFrameStrata("DIALOG") end) end
    end
    return dialog
end
function FT:OpenModule(name)
    if self:CombatOpenRequest() then return end
    local module = self.modules[name]
    if not module then return end
    self:CloseChoices()
    local homeShown = self.home and self.home:IsShown()
    if self.home then self.home:Hide() end
    -- Opened from another group's page (a link like "Interrupt bar font"):
    -- Back returns there. Opened from the main menu or its own group: Back
    -- goes to the main menu as before.
    self.backTo = self.backTo or {}
    local from = self.lastPage
    local fromModule = from and self.modules[from]
    if self.goingBack then
        -- Going back: keep where that page itself came from.
    elseif from and from ~= name and fromModule and fromModule.frame and fromModule.frame:IsShown() and self.HubOf and self:HubOf(from) ~= self:HubOf(name) then
        self.backTo[name] = from
    elseif not (module.frame and module.frame:IsShown()) then
        self.backTo[name] = nil
    end
    -- Pages that share one window (Macros) switch without closing it, so
    -- nothing flickers and the window stays where you put it.
    local stays = module.frame and module.frame:IsShown()
    -- The window this page replaces (the main menu or another page): the new
    -- one opens on its spot, so a menu you moved aside stays aside.
    local spot
    if not stays then
        local old = homeShown and self.home
        if not old then for _, other in pairs(self.modules) do if other ~= module and other.frame and other.frame ~= module.frame and other.frame:IsShown() and self.controlWindows and self.controlWindows[other.frame] then old = other.frame; break end end end
        spot = old and self:Spot(old)
    end
    -- A group opened from the main menu opens its first page through here
    -- again; that page takes the spot the menu had.
    spot = spot or (not stays and self.carrySpot) or nil
    -- Another page of the same group is open: the new page takes its place
    -- at once, without fading in (it would flash).
    local hub = self.HubOf and self:HubOf(name)
    local sameGroup = false
    for _, other in pairs(self.modules) do
        if other ~= module and other.frame and other.frame ~= module.frame then
            if hub and other.frame:IsShown() and other.frame.ftSidebar and other.frame.ftSidebar.hub == hub then sameGroup = true end
            other.frame:Hide()
        end
    end
    self.noFade = sameGroup or nil
    local carried = self.carrySpot
    self.carrySpot = spot or carried
    local ok, err = pcall(module.Open, module)
    self.carrySpot = carried
    self.noFade = nil
    if not ok then error(err, 0) end
    if self.modules.Movers and self.modules.Movers.WatchPages then self.modules.Movers:WatchPages() end
    -- A page (not a redirect to another page) is what /ft opens next time
    -- this session, and gets its group's sidebar.
    if module.frame and not module.redirect then
        self.lastPage = name
        if self.Dock then self:Dock(name, stays) end
        -- Within one group the sidebar stays put (Dock places the page);
        -- from the main menu or another group, the page takes that spot.
        if spot and not sameGroup then self:TakeSpot(module.frame, spot) end
        if module.Peek then self:PeekSliders(module.frame) end
    end
end
-- A setting changed on a page whose element is hidden right now (the
-- battleground timer, the interrupt bar, ...): show it for a few seconds,
-- so you see the change without pressing Preview. Pages say how with
-- module:Peek(). A page's main switch turned off shows nothing.
function FT:Peeked(control)
    if not control or control.noPeek then return end
    local module = self.lastPage and self.modules[self.lastPage]
    if not module or type(module.Peek) ~= "function" or not module.frame or not module.frame:IsShown() then return end
    if control.accent and control.switch and control.ftDimOn == false then return end
    -- Only controls on that page.
    local p, onPage = control, false
    for _ = 1, 8 do p = p and p.GetParent and p:GetParent(); if p == module.frame then onPage = true; break end end
    if not onPage then return end
    FT:Coalesce("peek", function() if not InCombatLockdown() then pcall(module.Peek, module) end end, .1)
end
-- Sliders on a page count as settings too (only when moved by you).
function FT:PeekSliders(frame, depth)
    if not frame or (depth or 0) > 3 or not frame.GetChildren then return end
    for _, child in ipairs({frame:GetChildren()}) do
        if child.GetObjectType and child:GetObjectType() == "Slider" and not child.ftPeek then
            child.ftPeek = true
            child:HookScript("OnValueChanged", function(s)
                if (s.IsDraggingThumb and s:IsDraggingThumb()) or (s.IsMouseOver and s:IsMouseOver()) then FT:Peeked(s) end
            end)
        end
        self:PeekSliders(child, (depth or 0) + 1)
    end
end
-- Open ForeverTools where you left it this session: the page you last had
-- open, or the main menu. A reload or login starts at the main menu again.
function FT:OpenLast()
    local last = self.lastPage
    if last and self.modules[last] and not InCombatLockdown() then
        local ok, err = pcall(self.OpenModule, self, last)
        if ok and self.modules[last].frame and self.modules[last].frame:IsShown() then return end
        -- A page that fails to open is reported, and the main menu opens instead.
        if not ok and geterrorhandler then geterrorhandler()(err) end
        self.lastPage = nil
    end
    self:OpenHome()
end

-- Nine sliced rounded textures keep the corner radius constant at any panel size.
local function layer(frame, inset, sublevel, flatRight)
    local result = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local texture = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
            texture:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\" .. (sublevel == -7 and "RoundedGradient.tga" or "Rounded.tga"))
            local cuts = {0, 0.25, 0.75, 1}
            -- flatRight: the right column repeats the middle one, so the panel
            -- ends in a straight edge there (a sidebar joined to a window).
            local tc = (flatRight and col == 2) and 1 or col
            texture:SetTexCoord(cuts[tc + 1], cuts[tc + 2], cuts[row + 1], cuts[row + 2])
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
function FT:Panel(frame, flatRight)
    frame.borderTextures = layer(frame, 0, -8, flatRight)
    frame.fillTextures = layer(frame, 1, -7, flatRight)
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
FT.GradientTexture = gradient
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
    frame:HookScript("OnShow", function() group:Stop(); if not FT.noFade then group:Play() end end)
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
    -- Icons live on the left side only (menu rework): headings are plain.
    icon = nil
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
        if text and text ~= "" and heading.icon and FT.headingIcons then
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
    self.labels[label] = true
    return label
end
-- On the first login of a session the game may still be loading the addon's
-- font file when the first notices are drawn; their text then stays blank
-- until a reload. A few seconds after login, every label that is on screen
-- sets its font and text again, which draws it once the font is there.
FT.labels = setmetatable({}, {__mode = "k"})
function FT:RedrawLabels()
    for label in pairs(self.labels) do
        if label.IsVisible and label:IsVisible() then
            local font, size, flags = label:GetFont()
            local text = label:GetText()
            if font then pcall(label.SetFont, label, font, size, flags or "") end
            if text and (not issecretvalue or not issecretvalue(text)) then label:SetText(""); label:SetText(text) end
        end
    end
end
do
    local warm = CreateFrame("Frame")
    warm:RegisterEvent("PLAYER_ENTERING_WORLD")
    warm:SetScript("OnEvent", function(owner)
        owner:UnregisterAllEvents()
        for _, delay in ipairs({2, 6}) do C_Timer.After(delay, function() FT:RedrawLabels() end) end
    end)
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
        -- The main action of a window (Start tour, Keep it): filled gold.
        if button.primary then
            if button.hover then self:Paint(button, {0.47, 0.35, 0.14, 1}, {1, 0.86, 0.52, 1})
            else self:Paint(button, {0.38, 0.28, 0.11, 1}, {0.90, 0.72, 0.38, 1}) end
        elseif button.hover then self:Paint(button, {0.16, 0.12, 0.07, 1}, {1, 0.84, 0.5, 1})
        else self:Paint(button, {0.085, 0.07, 0.05, 1}, {0.70, 0.56, 0.30, 1}) end
        return
    end
    -- Switch rows show their state on the switch itself, not as a fill.
    if button.selected and not button.switchMode then
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
-- Icons that follow your faction: the flight master's mount and the banner.
function FT:FlightIcon()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and "Ability_Mount_Gryphon_01" or "Ability_Mount_Wyvern_01"
end
function FT:FactionIcon()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and "INV_BannerPVP_02" or "INV_BannerPVP_01"
end
function FT:ButtonIcon(button, icon, size)
    if not button.icon then button.icon = button:CreateTexture(nil, "ARTWORK") end
    -- Called again on a made button (main menu tiles): its icon is wanted.
    if button.icon.ftPlain and not button.keepIcon then button.keepIcon = true; button.icon:SetAlpha(1) end
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
    if icon == "delete" or icon == "confirm" then
        -- The game's own red cross and green check: "remove" and "done".
        button.icon:SetTexture(icon == "delete" and "Interface\\Buttons\\UI-GroupLoot-Pass-Up" or "Interface\\RaidFrame\\ReadyCheck-Ready")
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
    local across = button:CreateTexture(nil, "ARTWORK"); across:SetColorTexture(1, .82, 0, 1); across:SetSize(12, 2)
    local up = button:CreateTexture(nil, "ARTWORK"); up:SetColorTexture(1, .82, 0, 1); up:SetSize(2, 12)
    -- Right before the text (an action button's text sits in the middle).
    local function placePlus()
        across:ClearAllPoints(); up:ClearAllPoints()
        if button.actionStyled then across:SetPoint("RIGHT", button.label, "LEFT", -8, 0) else across:SetPoint("CENTER", icon, "CENTER") end
        up:SetPoint("CENTER", across, "CENTER")
    end
    placePlus()
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
        GameTooltip:SetText(type(title) == "function" and title() or title, 1,.82,0)
        GameTooltip:AddLine(type(body) == "function" and body() or body, .96,.93,.86, true)
        -- A label cut off with "..." is shown in full here.
        local label = owner.label
        if label and label.IsTruncated and label:IsShown() then
            local ok, cut = pcall(label.IsTruncated, label)
            if ok and cut then GameTooltip:AddLine(" "); GameTooltip:AddLine(label:GetText() or "", 1, .82, 0, true) end
        end
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
    self:RowStyle(button)
    -- Changing a setting shows the thing it changes for a few seconds.
    button:HookScript("OnClick", function(owner) FT:CloseChoices(owner); FT:Peeked(owner) end)
    -- Wide rows lose their decorative icon; small square buttons keep theirs.
    if icon and width >= 100 then self:PlainRow(button) end
    self:UpdateButton(button)
    return button
end
-- One look for every setting (2026-10-17 menu rework):
--   * "Name: On" / "Name: Off" buttons are switches: the name on the left,
--     a switch on the right (gold and to the right when on).
--   * Buttons that open a list (button.options) show "Name" on the left and
--     the chosen value in gold on the right, with a down arrow.
--   * Rows have no decorative icon: only an icon the page sets itself
--     (a spell, a class, a macro) is kept. Icons live on the left side.
-- label:GetText() still returns the full text ("Name: On").
local function switchParts(button)
    if button.switch then return button.switch end
    local sw = {}
    -- Rows with a gear (buff reminders) keep the switch clear of it.
    local inset = button.gear and 40 or 12
    sw.inset = inset
    sw.track = button:CreateTexture(nil, "ARTWORK", nil, 2); sw.track:SetTexture(ROUNDED); sw.track:SetSize(36, 18); sw.track:SetPoint("RIGHT", -inset, 0)
    sw.knob = button:CreateTexture(nil, "ARTWORK", nil, 3); sw.knob:SetTexture(ROUNDED); sw.knob:SetSize(14, 14)
    sw.text = FT:Label(button, "", 12); sw.text:SetPoint("RIGHT", sw.track, "LEFT", -8, 0)
    button.switch = sw
    return sw
end
local function valueParts(button)
    if button.valueText then return button.valueText end
    local value = FT:Label(button, "", 13); value:SetJustifyH("RIGHT"); value:SetTextColor(1, .82, 0)
    if value.SetWordWrap then value:SetWordWrap(false) end
    local arrow = button:CreateTexture(nil, "ARTWORK", nil, 2)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up"); arrow:SetSize(14, 14); arrow:SetPoint("RIGHT", -10, -3)
    arrow:SetVertexColor(1, .82, 0)
    value:SetPoint("RIGHT", arrow, "LEFT", -6, 3)
    button.valueText, button.valueArrow = value, arrow
    return value
end
function FT:ShowSwitch(button, on)
    local sw = switchParts(button)
    button.switchMode = true
    sw.track:Show(); sw.knob:Show(); sw.text:Show()
    if on then sw.track:SetVertexColor(.80, .62, .23, 1); sw.knob:SetVertexColor(1, .96, .86, 1); sw.text:SetText("On"); sw.text:SetTextColor(1, .82, 0)
    else sw.track:SetVertexColor(.27, .25, .22, 1); sw.knob:SetVertexColor(.78, .74, .66, 1); sw.text:SetText("Off"); sw.text:SetTextColor(.62, .56, .46) end
    sw.knob:ClearAllPoints(); sw.knob:SetPoint(on and "RIGHT" or "LEFT", sw.track, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
    -- Narrow rows: the switch alone shows the state, so the name has room.
    local narrow = (button:GetWidth() or 300) < 260
    sw.text:SetShown(not narrow)
    FT:LeftLabel(button)
    button.label:SetPoint("RIGHT", button, "RIGHT", -((narrow and 40 or 72) + sw.inset), 0)
    self:UpdateButton(button)
    if button.accent then self:DimUnder(button, on) end
end
-- A page's main switch (the highlighted one) greys out the settings under
-- it while it is off, down to the next main switch. They still work, so
-- you can set things up first.
function FT:DimUnder(master, on)
    local page = master:GetParent()
    if not page or not page.GetChildren or not (self.controlWindows and self.controlWindows[page]) then return end
    master.ftDimOn = on
    if not page.ftDimHooked then
        page.ftDimHooked = true
        -- Each time the page shows, once it is laid out, grey again.
        page:HookScript("OnShow", function() C_Timer.After(.05, function() FT:RedoDim(page) end) end)
    end
    local top = master:GetBottom()
    if type(top) ~= "number" then
        -- Not laid out yet (the page was just made): look again a moment later.
        master.ftDimTries = (master.ftDimTries or 0) + 1
        if master.ftDimTries <= 10 and not master.ftDimRetry then master.ftDimRetry = true; C_Timer.After(.05, function() master.ftDimRetry = nil; FT:DimUnder(master, master.ftDimOn) end) end
        return
    end
    master.ftDimTries = nil
    local skip = {[master] = true, [page.closeButton or 0] = true, [page.homeButton or 0] = true, [page.pageInfo or 0] = true,
        [page.moveButton or 0] = true, [page.minButton or 0] = true, [page.ftSidebar or 0] = true, [page.titleText or 0] = true}
    -- Where the next main switch starts.
    local floor = -math.huge
    for _, child in ipairs({page:GetChildren()}) do
        if child ~= master and child.accent and child.switchMode and child:IsShown() then
            local t = child:GetTop(); if type(t) == "number" and t <= top and t > floor then floor = t end
        end
    end
    page.ftDimmed = page.ftDimmed or {}
    local function visit(object)
        if skip[object] then return end
        local t = object.GetTop and object:GetTop()
        local inside = type(t) == "number" and t <= top + 1 and t > floor + 1
        if inside and not on then FT:Dim(object, true); page.ftDimmed[object] = master
        elseif page.ftDimmed[object] == master then FT:Dim(object, false); page.ftDimmed[object] = nil end
    end
    for _, child in ipairs({page:GetChildren()}) do visit(child) end
    for _, region in ipairs({page:GetRegions()}) do if region.GetObjectType and region:GetObjectType() == "FontString" then visit(region) end end
end
-- Greying keeps the page's own transparency for a control (a page may fade
-- a setting itself): the two are multiplied.
function FT:Dim(object, dimmed)
    if not object.ftOwnAlpha then
        object.ftOwnAlpha = object:GetAlpha() or 1
        local setAlpha = object.SetAlpha
        object.ftSetAlpha = setAlpha
        object.SetAlpha = function(owner, a) owner.ftOwnAlpha = a; setAlpha(owner, a * (owner.ftDimmed and .45 or 1)) end
    end
    object.ftDimmed = dimmed or nil
    object.ftSetAlpha(object, object.ftOwnAlpha * (dimmed and .45 or 1))
end
function FT:RedoDim(page)
    for _, child in ipairs({page:GetChildren()}) do
        if child.accent and child.switchMode and child:IsShown() then self:DimUnder(child, child.ftDimOn) end
    end
end
-- Rows read left to right: the name starts at the left edge.
function FT:LeftLabel(button)
    local label = button.label
    if not button.icon or button.icon:GetAlpha() == 0 then
        if not label.ftLeft then label.ftLeft = true; label:ClearAllPoints(); label:SetPoint("LEFT", 14, 0) end
    end
    label:SetJustifyH("LEFT")
end
local function hideRowExtras(button)
    if button.switch then button.switch.track:Hide(); button.switch.knob:Hide(); button.switch.text:Hide() end
    if button.switchMode then button.switchMode = nil; FT:UpdateButton(button) end
    if button.valueText then button.valueText:Hide(); button.valueArrow:Hide() end
end
function FT:RowStyle(button)
    local label = button.label
    if not label or label.ftRow then return end
    label.ftRow = true
    local setText, getText = label.SetText, label.GetText
    label.GetText = function(owner) if owner.ftRaw ~= nil then return owner.ftRaw end; return getText(owner) end
    label.SetText = function(owner, text)
        owner.ftRaw = text
        -- One line, always: a name too long for its row is cut short ("…")
        -- instead of wrapping out of the box.
        if owner.SetWordWrap then owner:SetWordWrap(false) end
        if owner.SetMaxLines then owner:SetMaxLines(1) end
        if button.rowStyle == false or type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then hideRowExtras(button); return setText(owner, text) end
        local name, value = text:match("^(.-):%s+(.+)$")
        if name and name ~= "" and (value == "On" or value == "Off") then
            if button.valueText then button.valueText:Hide(); button.valueArrow:Hide() end
            setText(owner, name); FT:ShowSwitch(button, value == "On"); return
        end
        if name and name ~= "" and button.options then
            hideRowExtras(button)
            local v = valueParts(button); v:SetText(value); v:Show(); button.valueArrow:Show()
            if button.arrow then button.arrow:Hide() end
            setText(owner, name)
            FT:LeftLabel(button)
            label:SetPoint("RIGHT", v, "LEFT", -10, 0)
            return
        end
        hideRowExtras(button)
        if button.arrow then button.arrow:Show() end
        setText(owner, text)
        -- Buttons that do something (reset, move, copy, open a page) look like
        -- actions: outlined, text in the middle, no icon.
        if button.action == nil and not button.options and not button.keepIcon and (button:GetWidth() or 0) >= 100 and FT:ActionWord(text) then button.action = true end
        if button.action == true and not button.actionStyled then
            button.actionStyled = true; button.outline = true
            if button.icon and not button.keepIcon then button.icon:SetAlpha(0) end
            label:ClearAllPoints(); label:SetPoint("CENTER"); label:SetJustifyH("CENTER")
            FT:UpdateButton(button)
        end
    end
    -- Text given when the button was made goes through the same look.
    local first = getText(label)
    if type(first) == "string" and first ~= "" then label:SetText(first) end
end
local ACTIONS = {"^Reset", "^Revert", "^Move ", "^Copy", "^First%-time tour", "^Open ", "^Test", "^Clear", "^Import", "^Export", "^Delete", "^Add ", "^New ", "^Save", "^Lock", "^Unlock", "^Done", "^Restore", "^Undo", "^Show sample", "^Edit ", "^Rename", "^Choose ", " font$", "^Fonts$", "^Settings$", "^Back up", "^Make ", "^Use ", "^Enable ", "^Disable ", "^Apply ", "^Finish", "^Preview", "^Quick keybind", "^Backups", "^Item count settings", "^Set ", "^Start ", "^Stop "}
function FT:ActionWord(text)
    if type(text) ~= "string" or text == "" or text:find(":", 1, true) then return false end
    for _, pattern in ipairs(ACTIONS) do if text:find(pattern) then return true end end
    return false
end
-- A setting with a few fixed choices: click opens the list (never a
-- hidden click-to-cycle). list: {{value, label, tooltip}, ...} or a function
-- returning it; get() gives the current value, set(value) stores it.
function FT:MakeChoice(button, list, get, set)
    button.options = function()
        local out = {}
        for _, c in ipairs(type(list) == "function" and list() or list) do out[#out + 1] = {value = c[1], label = c[2], tooltip = c[3]} end
        return out
    end
    button.onSelect = function(value) set(value) end
    button:SetScript("OnClick", function() button.value = get(); button.menuWidth = math.max(button:GetWidth(), 200); FT:ShowChoices(button) end)
    -- Show its value on the right now that it has a list.
    local raw = button.label.ftRaw; if raw then button.label:SetText(raw) end
    return button
end
-- Decorative row icons go; one the page sets itself (a spell, a class) stays.
function FT:PlainRow(button)
    local icon = button.icon
    if not icon or button.keepIcon or icon.ftPlain then return end
    icon.ftPlain = true
    local w, h = icon:GetSize()
    local setTexture = icon.SetTexture
    icon:SetAlpha(0); icon:SetWidth(1)
    icon.SetTexture = function(owner, ...)
        if not button.keepIcon then
            button.keepIcon = true; owner:SetAlpha(1); owner:SetSize(w or 20, h or 20)
            -- The name moved to the left edge while the icon was hidden: back after it.
            local label = button.label
            if label and label.ftLeft then label.ftLeft = nil; label:ClearAllPoints(); label:SetPoint("LEFT", owner, "RIGHT", 8, 0); label:SetPoint("RIGHT", button, "RIGHT", button.switchMode and -84 or -8, 0) end
        end
        return setTexture(owner, ...)
    end
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
    -- Above every element on screen (previews, move tags), below menus,
    -- pop-ups and tooltips.
    frame:SetFrameStrata("FULLSCREEN")
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
        home.keepIcon = true
        frame.homeButton = home
        home:SetPoint("RIGHT", close, "LEFT", -8, 0)
        home:SetScript("OnClick", function() FT:Back() end)
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
-- Where a ForeverTools window sits on screen: the middle of it (with its
-- group's sidebar) and its top, in screen units.
function FT:Spot(frame)
    local l, r, t = frame:GetLeft(), frame:GetRight(), frame:GetTop()
    if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" then return end
    if frame.ftSidebar and frame.ftSidebar:IsShown() then l = l - (frame.ftDockWidth or 0) end
    local s = frame:GetEffectiveScale()
    return { x = (l + r) / 2 * s, top = t * s }
end
-- Open a window on that spot: same middle, same top.
function FT:TakeSpot(frame, spot)
    if not frame or not spot then return end
    local s = frame:GetEffectiveScale()
    if type(s) ~= "number" or s <= 0 then return end
    local dock = frame.ftSidebar and frame.ftSidebar:IsShown() and (frame.ftDockWidth or 0) or 0
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", spot.x / s + dock / 2, spot.top / s)
end
function FT:OpenHome()
    if self:CombatOpenRequest() then return end
    self:CloseChoices()
    local spot
    for _, module in pairs(self.modules) do if module.frame and module.frame:IsShown() and self.controlWindows and self.controlWindows[module.frame] then spot = self:Spot(module.frame); break end end
    if self.modules.Movers and self.modules.Movers.WatchPages then self.modules.Movers:WatchPages() end
    -- Going to the main menu yourself (Back) forgets the last page.
    self.lastPage = nil
    for _, module in pairs(self.modules) do if module.frame then module.frame:Hide() end end
    if not self.home then
        self.home = self:Window("ForeverToolsHome", "ForeverTools", 540, 432)
        self.home.titleText:SetText("ForeverTools")
        -- One quiet line: version and author.
        local version = self:Label(self.home, "v" .. self.version .. "  |cff7d705c·  By Krilar|r", 11)
        version:SetPoint("BOTTOMLEFT", 20, 13); version:SetTextColor(.66,.59,.48)
        if self.modules.Search then self.modules.Search:Attach(self.home) end
        self.home.profileStatus=self:Label(self.home, "", 12)
        self.home.profileStatus:SetPoint("TOPRIGHT", -24, -61)
        self.home.profileStatus:SetWidth(210)
        self.home.profileStatus:SetJustifyH("RIGHT")
        -- Buttons in two columns, each with a short line saying what's
        -- inside, so they need no tooltips. An odd one at the end takes the
        -- whole row.
        local tools={
            {"Macros","MacrosHub","macros","Ready-made class macros, your own macros and macro room"},
            {"Buff reminders","BuffsHub","Spell_Magic_GreaterBlessingofKings","Missing buffs, low ranks and cooldowns"},
            {"Appearance","Appearance","Spell_Holy_MindVision","Fonts, unit frames, skins, chat and tooltip"},
            {"Combat","SystemCombat","Ability_DualWield","Threat meter, rare alerts, interrupts and group role"},
            {"PvP","PvP",self:FactionIcon(),"Enemy cooldowns, stealth alerts, nearby enemies"},
            {"Keybinds","Keybinds","INV_Misc_Key_14","Quick keybind, spell binds, wheel casting and smart key"},
            {"On-screen info","SystemDisplay","INV_Misc_Spyglass_03","FPS, leveling stats, flight timer, minimap and quests"},
            {"System","System","generic","General settings, looting and merchant"},
            {"Bags","BagsHub","INV_Misc_Bag_08","Gold, bank view, other characters' bags, item counts"},
            {"Profiles","ProfilesHub","profiles","Save, load and share your setups"},
        }
        for i,entry in ipairs(tools) do
            local row=math.floor((i-1)/2);local column=(i-1)%2
            local wide=i==#tools and column==0
            local width=wide and 492 or 240
            local button=self:QuietButton(self.home,entry[1],width,52,entry[3])
            self:ButtonIcon(button,entry[3],32)
            -- Macros: the game's own macro window icon.
            -- It is round art: use the square inside the circle, so the rounded
            -- corners match the other buttons.
            if entry[3]=="macros" then button.icon:SetTexture("Interface\\MacroFrame\\MacroFrame-Icon"); button.icon:SetTexCoord(.16,.84,.16,.84) end
            button:SetPoint("TOPLEFT",24+column*252,-90-row*60)
            -- Name, then the description on up to two lines; the pair sits
            -- centered in the button whether the description takes one line or two.
            button.label:ClearAllPoints(); button.label:SetWidth(width-60)
            button.sub=self:Label(button,entry[4],11); button.sub:SetTextColor(.66,.59,.48)
            button.sub:SetWidth(width-60); button.sub:SetJustifyH("LEFT"); button.sub:SetWordWrap(true)
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
    if spot and not self.home:IsShown() then self:TakeSpot(self.home, spot) end
    self.home:Show()
end

-- Addon controls should never remain over combat gameplay. Saved changes remain
-- available; closing only hides the interface until the player opens it again.
function FT:CloseCombatControls()
    -- The page that was open stays remembered (FT.lastPage), so opening
    -- ForeverTools again after the fight brings you back to it.
    -- Windows that wait for an answer (setup, what's new) come back after
    -- combat; their own buttons still close them for good.
    -- hidingForCombat lets a window tell "closed by the fight" from "closed by you".
    self.hidingForCombat=true
    for frame in pairs(self.controlWindows or {}) do
        if frame.keepAfterCombat and frame:IsShown() then self.reopenAfterCombat=self.reopenAfterCombat or {}; self.reopenAfterCombat[frame]=true end
        frame:Hide()
    end
    self.hidingForCombat=nil
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
        FT.openAfterCombat=nil;FT:OpenLast()
    end
end)

-- Times you cannot play your character: on a flight path, in a vehicle or
-- in a cutscene. Notices (buff reminders, cooldown reminders, rare and
-- enemy alerts) wait until you are back, unless System > General > "Hide
-- notices while you can't play" is turned off.
local function yes(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and not (issecretvalue and issecretvalue(value)) and value == true
end
function FT:NoControl()
    if self.db and type(self.db.system) == "table" and self.db.system.quietNoControl == false then return false end
    if yes(UnitOnTaxi, "player") or yes(UnitInVehicle, "player") or yes(UnitHasVehicleUI, "player") then return true end
    if yes(InCinematic) or yes(IsInCinematicScene) then return true end
    if MovieFrame and MovieFrame.IsShown and MovieFrame:IsShown() then return true end
    if CinematicFrame and CinematicFrame.IsShown and CinematicFrame:IsShown() then return true end
    return false
end
-- The game's addon menu (the button under the minimap's calendar): ForeverTools
-- is listed there and opens its settings (named in ForeverTools.toc).
function ForeverTools_OnAddonCompartmentClick() if FT.OpenHome then FT:OpenHome() end end
function ForeverTools_OnAddonCompartmentEnter(_, button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_LEFT"); GameTooltip:SetText("ForeverTools"); GameTooltip:AddLine("Click to open the settings. Also /ft.", 1, 1, 1); GameTooltip:Show()
end
function ForeverTools_OnAddonCompartmentLeave() if GameTooltip then GameTooltip:Hide() end end
SLASH_FOREVERTOOLS1 = "/ft"
SlashCmdList.FOREVERTOOLS = function(message)
    local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if command == "macro" or command == "macros" then FT:OpenModule("MacrosHub")
    elseif command == "fps" then FT:OpenModule("QualityOfLife")
    elseif command == "move" then if FT.modules.Movers then FT.modules.Movers:Toggle() end
    elseif command == "moveall" or command == "windows" or command == "movewindows" then if FT.modules.MoveWindows then FT.modules.MoveWindows:ToggleMoving() end
    elseif command == "fonts" or command == "font" then FT:OpenModule("FontManager")
    elseif command == "colors" then FT:OpenModule("UnitColors")
    elseif command == "icons" or command == "skins" then FT:OpenModule("IconStyles")
    elseif command == "system" then FT:OpenModule("System")
    elseif command == "tooltip" or command == "tips" then FT:OpenModule("Tooltip")
    elseif command == "keybinds" then FT:OpenModule("Keybinds")
    elseif command == "wheel" then FT:OpenModule("CustomKeybinds")
    elseif command == "combat" then FT:OpenModule("SystemCombat")
    elseif command == "pvp" then FT:OpenModule("PvP")
    elseif command == "bags" or command == "bag" or command == "bank" then FT:OpenModule("BagsHub")
    elseif command == "counts" then FT:OpenModule("ItemCounts")
    elseif command == "mark" then if FT.Enemies then FT.Enemies:MarkUnit("target") end
    elseif command == "enemies" or command == "stealth" then FT:OpenModule("EnemyAlerts")
    elseif command == "screen" or command == "info" then FT:OpenModule("SystemDisplay")
    elseif command == "threat" then FT:OpenModule("Threat")
    elseif command == "dr" then if FT.modules.Diminish then FT:DebugBox("Diminishing returns", function() FT.modules.Diminish:Diagnose() end) end
    elseif command == "countdebug" then if FT.Bags and FT.Bags.Debug then FT:DebugBox("Item counts debug", function() FT.Bags:Debug() end) end
    elseif command == "nearbydebug" then if FT.Enemies and FT.Enemies.NearbyDebug then FT:DebugBox("Nearby enemies debug", function() FT.Enemies:NearbyDebug() end) end
    elseif command == "lag" then if FT.modules.Lag then FT.modules.Lag:Start() end
    elseif command == "enemycd" then if FT.modules.EnemyCooldowns then FT:DebugBox("Enemy cooldowns", function() FT.modules.EnemyCooldowns:Diagnose() end) end
    elseif command == "launch" then local layout=FT.modules.EditModeLayout; if layout then layout:Remind(true) end
    elseif command == "editmode" or command == "editmode remind" then local layout=FT.modules.EditModeLayout; if layout then if command == "editmode remind" then layout:Remind(true) else layout:Show() end end
    elseif command == "newchar" or command == "newcharacter" then if FT.modules.Profiles then FT.modules.Profiles:AskNewCharacter() end
    elseif command == "copy" then if FT.modules.Chat and FT.modules.Chat.OpenCopy then FT.modules.Chat:OpenCopy() end
    elseif command == "threatdebug" then if FT.modules.Threat and FT.modules.Threat.Debug then FT:DebugBox("Threat debug", function() FT.modules.Threat:Debug() end) end
    elseif command == "skindebug" then if FT.modules.IconStyles and FT.modules.IconStyles.SkinDebug then FT:DebugBox("Skin debug", function() FT.modules.IconStyles:SkinDebug() end) end
    elseif command == "buffdebug" then if FT.modules.BuffReminder and FT.modules.BuffReminder.BuffDebug then FT.modules.BuffReminder:BuffDebug() end
    elseif command == "powerdebug" then if FT.modules.BuffReminder and FT.modules.BuffReminder.PowerDebug then FT.modules.BuffReminder:PowerDebug() end
    elseif command == "bagdebug" then if FT.modules.IconStyles and FT.modules.IconStyles.BagDebug then FT:DebugBox("Bag debug", function() FT.modules.IconStyles:BagDebug() end) end
    elseif command == "start" then if FT.modules.Onboarding then FT.modules.Onboarding:ShowDemo() end
    elseif command == "setup" or command == "wizard" then if FT.modules.Onboarding then FT.modules.Onboarding:ShowSetup(true) end
    elseif command == "whatsnew" or command == "news" then if FT.modules.Onboarding then FT.modules.Onboarding:ShowWhatsNew() end
    elseif command == "buffs" or command == "reminders" then FT:OpenModule("BuffReminder")
    elseif command == "chat" then FT:OpenModule("Chat")
    elseif command == "appearance" then FT:OpenModule("Appearance")
    elseif command == "home" or command == "menu" then FT:OpenHome()
    else FT:OpenLast() end
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
    local arrow = button:CreateTexture(nil, "ARTWORK", nil, 2)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up"); arrow:SetSize(14, 14); arrow:SetPoint("RIGHT", -10, -3); arrow:SetVertexColor(1, .82, 0)
    button.arrow = arrow
    button:SetScript("OnClick", function() FT:ShowChoices(button) end)
    parent:HookScript("OnHide", function() if FT.choiceMenu then FT.choiceMenu:Hide() end end)
    return button
end
-- A box on a page that tells you something you need to know (why a
-- feature you switched on isn't showing, for example): amber edge, an icon
-- and a line or two of text. callout:Say(text) shows it, Say(nil) hides it.
function FT:Callout(parent, width, icon)
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(width, 48)
    self:Panel(box); self:Paint(box, {.16, .11, .04, .95}, {.95, .66, .22, 1})
    box.icon = box:CreateTexture(nil, "ARTWORK"); box.icon:SetSize(28, 28); box.icon:SetPoint("LEFT", 10, 0)
    box.icon:SetTexture("Interface\\Icons\\" .. (icon or "INV_Misc_QuestionMark")); self:RoundIcon(box.icon)
    box.text = self:Label(box, "", 13); box.text:SetPoint("LEFT", box.icon, "RIGHT", 10, 0); box.text:SetWidth(width - 62)
    box.text:SetJustifyH("LEFT"); box.text:SetTextColor(1, .9, .72)
    if box.text.SetWordWrap then box.text:SetWordWrap(true) end
    function box:Say(text)
        if not text or text == "" then self:Hide(); return end
        self.text:SetText(text)
        local h = self.text:GetStringHeight()
        self:SetHeight(math.max(48, (type(h) == "number" and h or 16) + 22))
        self:Show()
    end
    box:Hide()
    return box
end
-- Headings that split a page into groups ("When", "Look", "Position"), so
-- it is clear which settings belong together. sections: {{title, control},
-- ...} top to bottom; each heading goes where its control was and everything
-- from there down moves 28 px lower (controls placed TOPLEFT on the page).
-- An on-screen element that is locked still opens its page on a right-click,
-- while left clicks and the mouse-over go through to the world below.
-- Unlocked (moving): it takes the mouse fully for dragging.
function FT:MenuClick(frame, page)
    if not frame or frame.ftMenuHooked or not frame.HookScript then return end
    frame.ftMenuHooked = true
    frame:HookScript("OnMouseUp", function(_, button)
        if button ~= "RightButton" or InCombatLockdown() then return end
        local movers = FT.modules.Movers
        if movers and movers.active then movers:Stop() end
        FT:OpenModule(page)
    end)
end
function FT:LockedMouse(frame, locked, page)
    if page then self:MenuClick(frame, page) end
    if not frame or (InCombatLockdown and InCombatLockdown()) then return end
    frame:EnableMouse(true)
    if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, not locked) end
    if frame.SetPassThroughButtons then
        if locked then pcall(frame.SetPassThroughButtons, frame, "LeftButton", "MiddleButton", "Button4", "Button5")
        else pcall(frame.SetPassThroughButtons, frame) end
    end
end
function FT:Sections(frame, sections, width)
    local function topOf(region)
        if not region or not region.GetNumPoints or region:GetNumPoints() == 0 then return end
        local point, rel, _, x, y = region:GetPoint(1)
        if point == "TOPLEFT" and (rel == frame or rel == nil) then return x, y end
    end
    local all = {}
    for _, c in ipairs({frame:GetChildren()}) do all[#all + 1] = c end
    for _, r in ipairs({frame:GetRegions()}) do all[#all + 1] = r end
    frame.ftSectionHeads = frame.ftSectionHeads or {}
    for _, entry in ipairs(sections) do
        local title, control = entry[1], entry[2]
        local x0, y0 = topOf(control)
        if y0 then
            for _, r in ipairs(all) do
                local x, y = topOf(r)
                if y and y <= y0 + 8 then
                    local point, rel, relPoint = r:GetPoint(1)
                    local n = r:GetNumPoints()
                    if n == 1 then r:ClearAllPoints(); r:SetPoint(point, rel or frame, relPoint, x, y - 28)
                    else
                        local pts = {}
                        for i = 1, n do pts[i] = {r:GetPoint(i)} end
                        r:ClearAllPoints()
                        for i, p in ipairs(pts) do
                            if p[2] == frame or p[2] == nil then r:SetPoint(p[1], frame, p[3], p[4], (p[1]:find("TOP") and p[5] - 28) or p[5])
                            else r:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
                        end
                    end
                end
            end
            local head = self:Label(frame, title, 14, true); head:SetPoint("TOPLEFT", frame, "TOPLEFT", x0, y0 - 4)
            head:SetTextColor(.95, .90, .81); self:SectionHeading(head, nil, width or 300)
            frame.ftSectionHeads[#frame.ftSectionHeads + 1] = head
            all[#all + 1] = head
        end
    end
end
-- An open list closes when you click anything else in ForeverTools or
-- switch pages, so it never covers the next page.
function FT:CloseChoices(clicked)
    local menu = self.choiceMenu
    if not menu or not menu:IsShown() then return end
    if clicked and (clicked == menu.owner or (clicked.GetParent and clicked:GetParent() == menu.list)) then return end
    menu:Hide()
end
function FT:ShowChoices(owner)
    if self:CombatOpenRequest() then return end
    if not self.choiceMenu then
        local menu = CreateFrame("Frame", "ForeverToolsChoiceMenu", UIParent)
        self.choiceMenu = menu
        menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetClampedToScreen(true); menu:EnableMouse(true)
        -- Escape closes it, and it goes away with the window it belongs to.
        if UISpecialFrames then table.insert(UISpecialFrames, "ForeverToolsChoiceMenu") end
        menu:SetScript("OnUpdate", function(m) if m.owner and m.owner.IsVisible and not m.owner:IsVisible() then m:Hide() end end)
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
    -- Some lists open beside their window instead (the font list), so what
    -- they change stays in view while you pick.
    local beside = owner.menuBeside
    local right, left = beside and beside:IsVisible() and beside:GetRight(), owner:GetLeft()
    if right and left then
        menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", owner, "TOPLEFT", right - left + 8, 0)
    end
    menu.list:SetWidth(width - inner); menu.list:SetHeight(math.max(1, #options * 30))
    menu.scroll:SetVerticalScroll(0)
    for _, row in ipairs(menu.rows) do row:Hide() end
    local seen, kinds = {}, 0
    for _, item in ipairs(options) do if item.icon and not seen[item.icon] then seen[item.icon] = true; kinds = kinds + 1 end end
    menu.iconsDiffer = kinds > 1
    for index, item in ipairs(options) do
        local row = menu.rows[index]
        if not row then
            row = self:QuietButton(menu.list, "", width - inner, 28, "macros")
            -- List items are plain choices: never a switch or an action look.
            row.rowStyle = false; row.action = false
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
                menu:Hide(); current.onSelect(selected.value); FT:Peeked(current)
            end)
            menu.rows[index] = row
        end
        row.item = item; row:SetWidth(width - inner); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
        row.label:SetText(item.label)
        -- A list item shows an icon only when it has one of its own, and
        -- only when the icons tell items apart (spells, classes): a list
        -- where every item has the same icon shows none.
        if item.icon and menu.iconsDiffer then row.icon:SetTexture(item.icon); row.icon:SetAlpha(1); row.icon:SetSize(20, 20)
        else row.icon:SetAlpha(0); row.icon:SetWidth(1) end
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
    self:Tooltip(move, "Move elements", "Drag ForeverTools' things on screen. This window shrinks until you click Done.")
    local min = self:QuietButton(frame, "", 28, 28)
    -- A gold dash; minimized, a second bar turns it into a plus.
    min.dash = min:CreateTexture(nil, "ARTWORK"); min.dash:SetColorTexture(1, .82, 0, 1); min.dash:SetSize(12, 2); min.dash:SetPoint("CENTER", 0, -4)
    min.bar = min:CreateTexture(nil, "ARTWORK"); min.bar:SetColorTexture(1, .82, 0, 1); min.bar:SetSize(2, 12); min.bar:SetPoint("CENTER"); min.bar:Hide()
    min:SetScript("OnClick", function() FT:SetMinimized(frame, not frame.minimized) end)
    self:Tooltip(min, "Minimize", function() return frame.minimized and "Show the whole window again." or "Shrink this window to its title bar." end)
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
-- the text cursor is; a click in the text puts the cursor there, dragging
-- selects text and a double-click selects a row. The box
-- gets no cursor of its own from the game here, so both are done by hand:
-- the box's text is laid out again with a hidden measuring text to turn a
-- click into a place in the text and back. Call after the box's own scripts
-- are set (it only hooks). "inset" is the box's text inset. options.single
-- is for a one-line box (the cursor stays on that one line); options.insetY
-- is the text's top offset. options.light is for boxes that hold long
-- strings (profile and layout strings, tens of thousands of letters): the
-- line only follows where the game says the cursor is and never measures or
-- lays out the text, so pasting or clicking in a huge string stays instant.
function FT:TextCaret(box, inset, options)
    inset = inset or 6
    options = options or {}
    local insetY = options.insetY or inset
    local caret = box:CreateTexture(nil, "OVERLAY"); caret:SetTexture("Interface\\Buttons\\WHITE8x8")
    caret:SetSize(2, 17); caret:SetVertexColor(1, .82, 0, 1); caret:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -insetY); caret:Hide()
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
        -- Never lay out a huge text letter by letter (that froze the game):
        -- past this size each line of the text counts as one row.
        if #text > 4000 then
            local rows, from = {}, 0
            for logical in (text .. "\n"):gmatch("(.-)\n") do rows[#rows + 1] = {start = from, text = logical}; from = from + #logical + 1 end
            state.lines, state.text, state.limit = rows, text, limit
            return rows
        end
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
        caret:ClearAllPoints(); caret:SetPoint("TOPLEFT", box, "TOPLEFT", x + inset, -(y + insetY))
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
        place(x, options.single and 0 or -y, height)
    end)
    box:HookScript("OnTextChanged", function() state.lines = nil end)
    -- Up and down arrows: to the same column on the line above or below, when
    -- the game's own box does not move the cursor itself. Both the arrow
    -- event and the key press are watched (some boxes only get one of them).
    if not options.single then
        if box.SetAltArrowKeyMode then pcall(box.SetAltArrowKeyMode, box, false) end
        local function arrow(key)
            if key ~= "UP" and key ~= "DOWN" then return end
            if box.IsMultiLine and not box:IsMultiLine() then return end
            local stamp = GetTime()
            if state.arrowAt == stamp and state.arrowKey == key then return end
            state.arrowAt, state.arrowKey = stamp, key
            local before = box:GetCursorPosition()
            if type(before) ~= "number" then return end
            C_Timer.After(0, function()
                if box:GetCursorPosition() ~= before then return end
                local text = box:GetText() or ""
                local starts = {1}
                for i = 1, #text do if text:sub(i, i) == "\n" then starts[#starts + 1] = i + 1 end end
                local line = 1
                for i, st in ipairs(starts) do if before + 1 >= st then line = i end end
                local column = before + 1 - starts[line]
                local target = line + (key == "UP" and -1 or 1)
                if target < 1 then box:SetCursorPosition(0); return end
                if target > #starts then box:SetCursorPosition(#text); return end
                local lineEnd = (starts[target + 1] and starts[target + 1] - 2) or #text
                box:SetCursorPosition(math.min(starts[target] - 1 + column, lineEnd))
            end)
        end
        box:HookScript("OnArrowPressed", function(_, key) arrow(key) end)
        if box.HasScript and box:HasScript("OnKeyDown") then box:HookScript("OnKeyDown", function(_, key) arrow(key) end) end
    end
    -- Blink like a normal text cursor; solid for a moment after it moves.
    local driver = CreateFrame("Frame", nil, box); driver:Hide()
    driver:SetScript("OnUpdate", function()
        if not options.light then follow() end
        caret:SetAlpha(((GetTime() - state.moved) % 1.06) < .56 and 1 or 0)
    end)
    box:HookScript("OnEditFocusGained", function() state.moved = GetTime(); caret:SetAlpha(1); caret:Show(); driver:Show() end)
    box:HookScript("OnEditFocusLost", function() caret:Hide(); driver:Hide(); state.before = nil; state.index = nil end)
    box:HookScript("OnHide", function() caret:Hide(); driver:Hide() end)
    if options.light then
        box.ftCaret = {texture = caret, state = state, driver = driver}
        return caret
    end
    -- The mouse in the text. A click puts the cursor there (if the game did
    -- not), dragging selects from where you pressed to where you are, and a
    -- double-click selects the whole row with its line break, ready to delete.
    box:EnableMouse(true)
    local function pointIndex()
        local left, top, scale = box:GetLeft(), box:GetTop(), box:GetEffectiveScale()
        if type(left) ~= "number" or type(top) ~= "number" or type(scale) ~= "number" or scale <= 0 then return end
        local cx, cy = GetCursorPosition()
        if type(cx) ~= "number" or type(cy) ~= "number" then return end
        return indexAt(cx / scale - left - inset, top - cy / scale - insetY)
    end
    local function setCursor(index)
        box:SetCursorPosition(index)
        state.index = index
        local x, y = locate(index); place(x, y); state.moved = GetTime()
    end
    local function highlight(from, to)
        if from > to then from, to = to, from end
        state.selected = to > from
        if box.HighlightText then box:HighlightText(from, to) end
    end
    local function rowAt(index)
        local text = box:GetText() or ""
        local from = math.max(0, math.min(#text, index))
        while from > 0 and text:sub(from, from) ~= "\n" do from = from - 1 end
        local to = text:find("\n", index + 1, true)
        if to then return from, to end
        -- The last row has no break after it: take the one before it.
        return from > 0 and from - 1 or 0, #text
    end
    local drag = CreateFrame("Frame", nil, box); drag:Hide()
    drag:SetScript("OnUpdate", function()
        if not state.anchor or (IsMouseButtonDown and not IsMouseButtonDown("LeftButton")) then drag:Hide(); return end
        local index = pointIndex()
        if not index or index == state.dragIndex then return end
        state.dragIndex = index
        setCursor(index); highlight(state.anchor, index)
    end)
    box:HookScript("OnMouseDown", function(_, button)
        state.before = state.index
        if button and button ~= "LeftButton" then return end
        local index = pointIndex()
        if not index then return end
        local now = GetTime()
        if state.lastDown and now - state.lastDown < .4 and state.lastIndex and math.abs(state.lastIndex - index) <= 1 then
            local from, to = rowAt(index)
            if box.HasFocus and not box:HasFocus() then box:SetFocus() end
            setCursor(to); highlight(from, to)
            state.anchor, state.rowSelected, state.lastDown = nil, true, nil
            return
        end
        state.lastDown, state.lastIndex = now, index
        state.anchor, state.dragIndex, state.rowSelected = index, index, nil
        drag:Show()
    end)
    box:HookScript("OnMouseUp", function(_, button)
        drag:Hide()
        if button and button ~= "LeftButton" then return end
        local anchor = state.anchor; state.anchor = nil
        if state.rowSelected then state.rowSelected = nil; return end
        local index = pointIndex()
        if not index then return end
        if box.HasFocus and not box:HasFocus() then box:SetFocus() end
        if anchor and index ~= anchor then setCursor(index); highlight(anchor, index); return end
        -- A plain click: nothing stays selected.
        if state.selected then highlight(0, 0) end
        local now = box:GetCursorPosition()
        if state.before ~= nil and now ~= state.before then return end
        setCursor(index)
    end)
    box.ftCaret = {texture = caret, locate = locate, indexAt = indexAt, lines = lines, state = state, driver = driver, drag = drag, rowAt = rowAt}
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
-- Back: to the page this one was opened from (another group's page), else
-- the main menu.
function FT:Back()
    local here = self.lastPage
    local to = here and self.backTo and self.backTo[here]
    if to and self.modules[to] then
        self.backTo[here] = nil
        self.goingBack = true; local ok, err = pcall(self.OpenModule, self, to); self.goingBack = nil
        if not ok then error(err, 0) end
        return
    end
    self:OpenHome()
end
function FT:BackTo(frame, moduleName)
    frame.homeButton:SetScript("OnClick", function() FT:OpenModule(moduleName) end)
end
-- Secondary windows (setup, what's new, copy boxes, profile transfer) open in
-- the middle. If a ForeverTools window is already open, they sit beside it on
-- the side with the most room instead of covering it.
-- Put a window next to the ForeverTools windows that are open, never on top
-- of them: on the side of all of them with the most room (right, left, above,
-- below). When the screen has no room for it on any side, it sits a little
-- down and to the right of them, so every title bar and close button stays
-- reachable. Positions are worked out in screen units, so windows with a
-- different scale still line up.
function FT:PlaceBeside(frame)
    local parentScale = UIParent:GetEffectiveScale()
    local function bounds(other)
        local l, r, t, b = other:GetLeft(), other:GetRight(), other:GetTop(), other:GetBottom()
        if type(l) ~= "number" or type(r) ~= "number" or type(t) ~= "number" or type(b) ~= "number" then return end
        local s = other:GetEffectiveScale() / parentScale
        -- A page with its group's sidebar reaches further left.
        if other.ftSidebar and other.ftSidebar:IsShown() then l = l - (other.ftDockWidth or 0) end
        return l * s, r * s, t * s, b * s
    end
    local left, right, top, bottom
    for window in pairs(self.controlWindows or {}) do
        if window ~= frame and not window.ignorePlacement and window.IsShown and window:IsShown() then
            local l, r, t, b = bounds(window)
            if l then
                left = left and math.min(left, l) or l; right = right and math.max(right, r) or r
                top = top and math.max(top, t) or t; bottom = bottom and math.min(bottom, b) or b
            end
        end
    end
    frame:ClearAllPoints()
    if not left then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0); return end
    local own = frame:GetEffectiveScale() / parentScale
    if own <= 0 then own = 1 end
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local w, h = frame:GetWidth() * own, frame:GetHeight() * own
    local gap = 12
    local room = { RIGHT = width - right, LEFT = left, TOP = height - top, BOTTOM = bottom }
    local need = { RIGHT = w + gap, LEFT = w + gap, TOP = h + gap, BOTTOM = h + gap }
    local best
    for _, side in ipairs({ "RIGHT", "LEFT", "TOP", "BOTTOM" }) do
        if room[side] >= need[side] and (not best or room[side] > room[best]) then best = side end
    end
    local midX, midY = (left + right) / 2, (top + bottom) / 2
    local x, y -- top left corner, screen units from the bottom left
    if best == "RIGHT" then x, y = right + gap, midY + h / 2
    elseif best == "LEFT" then x, y = left - gap - w, midY + h / 2
    elseif best == "TOP" then x, y = midX - w / 2, top + gap + h
    elseif best == "BOTTOM" then x, y = midX - w / 2, bottom - gap
    else x, y = left + 40, top - 40 end
    x = math.max(0, math.min(x, width - w)); y = math.max(h, math.min(y, height))
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / own, y / own)
end
-- A read-only text box the player can select and copy with Ctrl+C.
-- Nothing is sent anywhere; the text only leaves the game if the player pastes it.
-- A debug report in a copy window instead of the chat (long reports scroll
-- out of the chat history): Ctrl+A, Ctrl+C, paste it in a message.
function FT:DebugBox(title, fn)
    local lines = {}
    local realPrint = print
    print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        lines[#lines + 1] = (table.concat(parts, " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    local ok, err = pcall(fn)
    print = realPrint
    if not ok then lines[#lines + 1] = "error: " .. tostring(err) end
    self:CopyBox(title, table.concat(lines, "\n"), "Ctrl+A to select all, Ctrl+C to copy, then paste it in a message.", true)
end
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

-- Preview, the same on every page that puts something on screen: one switch
-- at the top right, on the row of the page's main switch. On: the element
-- shows with example content and can be dragged. Off (or the page closes):
-- it is locked again and the examples go away.
--   opts.get() -> on?, opts.set(on), opts.tip (tooltip text)
function FT:TopPreview(frame, main, opts)
    local width = 150
    local b = self:QuietButton(frame, "Preview: Off", width, main and main:GetHeight() or 34, "Spell_Holy_MindVision")
    if main then
        main:SetWidth(main:GetWidth() - width - 12)
        b:SetPoint("LEFT", main, "RIGHT", 12, 0)
    else
        b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -62)
    end
    b.ftPreview = opts
    local function refresh() FT:RefreshPreview(frame) end
    b:SetScript("OnClick", function()
        local on = not opts.get()
        opts.set(on)
        if on then FT:Toast("Drag it into place. Click Preview again to lock it.", 4) end
        refresh()
    end)
    self:Tooltip(b, "Preview", (opts.tip and (opts.tip .. " ") or "") .. "Shows it on screen with examples, so you can drag it into place. Click again to lock it.")
    frame.ftPreviewButton = b
    frame:HookScript("OnShow", refresh)
    frame:HookScript("OnHide", function() if opts.get() then opts.set(false) end end)
    refresh()
    return b
end
function FT:RefreshPreview(frame)
    local b = frame and frame.ftPreviewButton
    if not b then return end
    local on = b.ftPreview.get() and true or false
    b.label:SetText("Preview: " .. (on and "On" or "Off"))
    self:SetSelected(b, on)
end
