local _, FT = ...
local Macros = FT.modules.MacroForge
-- "Make room": opens when Add all needs more Character macro slots than are
-- free. Left: your Character macros, tick the ones to delete. Right: the new
-- macros, tick the ones to add. The counter turns green when it all fits,
-- and only then can you continue.
local ROW, ROW_GAP = 26, 30
local normalized = function(body) return type(body) == "string" and body:gsub("\r\n", "\n"):gsub("\n+$", "") or "" end

function Macros:NewBulkEntries(className)
    local list = {}
    local rank, mouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    for _, entry in ipairs(self:AddableEntries(className)) do
        self.mouseover = self:EntryMouseover(entry)
        if not self:EntryExists(entry, self:BuildMacro(entry)) then list[#list + 1] = entry end
    end
    self.selectedRank, self.mouseover = rank, mouseover
    return list
end
function Macros:CharacterMacros()
    local list = {}
    local _, count = GetNumMacros()
    local offset = MAX_ACCOUNT_MACROS or 120
    for index = offset + 1, offset + count do
        local name, icon, body = GetMacroInfo(index)
        if name then list[#list + 1] = {name = name, icon = icon, body = body} end
    end
    return list
end

local function levelText(entry)
    local level = entry.learnLevel or 0
    return level > 0 and level < 99 and ("level " .. level) or "known"
end
local function makeColumn(frame, x, title, hint)
    local column = {}
    column.title = FT:Label(frame, title, 15, true); column.title:SetPoint("TOPLEFT", x, -100)
    FT:SectionHeading(column.title, x < 100 and "INV_Misc_EngGizmos_20" or "INV_Misc_Book_09", 110)
    column.hint = FT:Label(frame, hint, 12); column.hint:SetPoint("TOPLEFT", x, -126); column.hint:SetWidth(310)
    column.hint:SetTextColor(.72,.66,.55)
    column.box = CreateFrame("Frame", nil, frame); column.box:SetSize(318, 272); column.box:SetPoint("TOPLEFT", x, -162)
    FT:Panel(column.box)
    column.scroll = CreateFrame("ScrollFrame", nil, column.box, "UIPanelScrollFrameTemplate")
    column.scroll:SetPoint("TOPLEFT", 8, -8); column.scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    column.list = CreateFrame("Frame", nil, column.scroll); column.list:SetSize(282, 1)
    column.scroll:SetScrollChild(column.list)
    column.rows = {}
    return column
end
local function fillColumn(column, items, onToggle)
    for _, row in ipairs(column.rows) do row:Hide() end
    for index, item in ipairs(items) do
        local row = column.rows[index]
        if not row then
            row = FT:QuietButton(column.list, "", 282, ROW, "macros")
            row.check = row:CreateTexture(nil, "OVERLAY"); row.check:SetSize(18, 18); row.check:SetPoint("RIGHT", -6, 0)
            row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.meta = FT:Label(row, "", 11); row.meta:SetPoint("RIGHT", -28, 0); row.meta:SetJustifyH("RIGHT")
            row.meta:SetTextColor(.72,.66,.55)
            row.label:SetPoint("RIGHT", row, "RIGHT", -92, 0)
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row:SetScript("OnClick", function(owner) owner.item.ticked = not owner.item.ticked; onToggle() end)
            column.rows[index] = row
        end
        row.item = item
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_GAP)
        row.label:SetText(item.label); row.meta:SetText(item.meta or "")
        row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row:Show()
    end
    column.list:SetHeight(math.max(1, #items * ROW_GAP))
    column.scroll:SetVerticalScroll(0)
end
local function paintColumn(column)
    for _, row in ipairs(column.rows) do
        if row:IsShown() and row.item then
            FT:SetSelected(row, row.item.ticked == true); row.check:SetShown(row.item.ticked == true)
        end
    end
end

function Macros:RoomCounts()
    local room = self.room
    local used, deleting, adding = #room.current, 0, 0
    for _, item in ipairs(room.current) do if item.ticked then deleting = deleting + 1 end end
    for _, item in ipairs(room.new) do if item.ticked then adding = adding + 1 end end
    return used, deleting, adding, MAX_CHARACTER_MACROS or 30
end
function Macros:RefreshRoom()
    local frame = self.roomFrame
    paintColumn(frame.left); paintColumn(frame.right)
    local used, deleting, adding, max = self:RoomCounts()
    local total = used - deleting + adding
    local fits = total <= max
    frame.counter:SetText(string.format("Slots: %d used  -  %d deleted  +  %d added  =  %s%d / %d|r",
        used, deleting, adding, fits and "|cff7dff8a" or "|cffff6b6b", total, max))
    local ready = fits and (deleting + adding) > 0
    frame.go.label:SetText(deleting > 0 and string.format("Delete %d & add %d", deleting, adding) or string.format("Add %d macros", adding))
    frame.go:SetEnabled(ready); frame.go:SetAlpha(ready and 1 or .45)
    frame.status:SetText(fits and (adding > 0 and "It fits." or "Tick the macros you want to add.")
        or string.format("Tick %d more to delete, or untick %d to add.", total - max, total - max))
    frame.status:SetTextColor(fits and 0.49 or 1, fits and 1 or 0.42, fits and 0.54 or 0.42)
end
function Macros:CreateRoomUI()
    local frame = FT:Window("ForeverToolsMakeRoom", "ForeverTools | Make room", 700, 596)
    frame.noSavePrompt = true
    frame.homeButton:Hide()
    self.roomFrame = frame
    frame.intro = FT:Label(frame, "", 14); frame.intro:SetPoint("TOPLEFT", 24, -56); frame.intro:SetWidth(650)
    frame.left = makeColumn(frame, 24, "Delete from Character macros", "Click a macro to tick it for deleting. General macros are never touched.")
    frame.right = makeColumn(frame, 358, "Add", "Spells you know come first, then by the level you learn them.")
    local toggle = function() self:RefreshRoom() end
    frame.tickUnchanged = FT:QuietButton(frame, "Tick unchanged", 154, 28, "macros"); frame.tickUnchanged:SetPoint("TOPLEFT", frame.left.box, "BOTTOMLEFT", 0, -8)
    frame.tickUnchanged:SetScript("OnClick", function()
        local bodies = self:TemplateBodies()
        for _, item in ipairs(self.room.current) do if bodies[normalized(item.body)] then item.ticked = true end end
        toggle()
    end)
    FT:Tooltip(frame.tickUnchanged, "Tick unchanged", "Tick every macro ForeverTools made that you have not changed. You can still untick any of them.")
    frame.clearLeft = FT:QuietButton(frame, "Clear", 154, 28, "reset"); frame.clearLeft:SetPoint("LEFT", frame.tickUnchanged, "RIGHT", 10, 0)
    frame.clearLeft:SetScript("OnClick", function() for _, item in ipairs(self.room.current) do item.ticked = false end; toggle() end)
    frame.allRight = FT:QuietButton(frame, "Tick all", 154, 28, "add"); frame.allRight:SetPoint("TOPLEFT", frame.right.box, "BOTTOMLEFT", 0, -8)
    frame.allRight:SetScript("OnClick", function() for _, item in ipairs(self.room.new) do item.ticked = true end; toggle() end)
    frame.clearRight = FT:QuietButton(frame, "Clear", 154, 28, "reset"); frame.clearRight:SetPoint("LEFT", frame.allRight, "RIGHT", 10, 0)
    frame.clearRight:SetScript("OnClick", function() for _, item in ipairs(self.room.new) do item.ticked = false end; toggle() end)
    frame.counter = FT:Label(frame, "", 15, true); frame.counter:SetPoint("BOTTOMLEFT", 24, 58)
    frame.status = FT:Label(frame, "", 13); frame.status:SetPoint("BOTTOMLEFT", 24, 32)
    frame.go = FT:AccentButton(frame, "", 210, 34, "confirm"); frame.go:SetPoint("BOTTOMRIGHT", -24, 24)
    if frame.go.SetMotionScriptsWhileDisabled then frame.go:SetMotionScriptsWhileDisabled(true) end
    frame.go:SetScript("OnClick", function() self:ConfirmRoom() end)
    FT:Tooltip(frame.go, "Make room and add", "Deletes the ticked Character macros, then adds the ticked new ones. Asks once first.")
    frame.cancel = FT:QuietButton(frame, "Cancel", 110, 34, "home"); frame.cancel:SetPoint("RIGHT", frame.go, "LEFT", -10, 0)
    frame.cancel:SetScript("OnClick", function() frame:Hide() end)
    frame:HookScript("OnHide", function() self.room = nil end)
end
function Macros:OpenMakeRoom(className)
    if InCombatLockdown() then self:Status("Leave combat before adding macros.", true); return end
    if not self.roomFrame then self:CreateRoomUI() end
    local frame = self.roomFrame
    local max = MAX_CHARACTER_MACROS or 30
    local current, new = {}, {}
    for _, macro in ipairs(self:CharacterMacros()) do
        current[#current + 1] = {label = macro.name, icon = macro.icon, name = macro.name, body = macro.body}
    end
    local free = math.max(0, max - #current)
    for index, entry in ipairs(self:NewBulkEntries(className)) do
        -- What fits already starts ticked; the highest-level ones start unticked.
        new[#new + 1] = {label = entry.name, meta = levelText(entry), icon = self:IconForEntry(entry), entry = entry, ticked = index <= free}
    end
    self.room = {className = className, current = current, new = new}
    local foreign = className ~= self:PlayerClass()
    frame.intro:SetText((foreign and ("|cffff6b6bYou are a " .. self:PlayerClass() .. ", not a " .. className .. ".|r ") or "")
        .. string.format("%d new %s macros, but only %d free slots. Delete some Character macros, or add fewer.", #new, className, free))
    -- An empty Character tab has nothing to delete: only the Add side matters.
    local hasCurrent = #current > 0
    for _, widget in ipairs({frame.left.title, frame.left.hint, frame.left.box, frame.tickUnchanged, frame.clearLeft}) do widget:SetShown(hasCurrent) end
    fillColumn(frame.left, current, function() self:RefreshRoom() end)
    fillColumn(frame.right, new, function() self:RefreshRoom() end)
    self:RefreshRoom()
    FT:PlaceBeside(frame)
    frame:Show()
end
function Macros:ConfirmRoom()
    local room = self.room
    if not room then return end
    local used, deleting, adding, max = self:RoomCounts()
    if used - deleting + adding > max then return end
    local message = deleting > 0
        and string.format("Delete %d Character macros and add %d new %s macros?\n\nDeleted macros cannot be restored, and their action-bar buttons stop working.", deleting, adding, room.className)
        or string.format("Add %d new %s macros?", adding, room.className)
    FT:Confirm(message, function() self:ApplyRoom(room) end)
end
function Macros:ApplyRoom(room)
    if room ~= self.room or InCombatLockdown() then return end
    local doomed, chosen = {}, {}
    for _, item in ipairs(room.current) do if item.ticked then doomed[#doomed + 1] = {name = item.name, body = item.body} end end
    for _, item in ipairs(room.new) do if item.ticked then chosen[#chosen + 1] = item.entry end end
    local deleted = #doomed > 0 and self:DeleteMatching(doomed) or 0
    self.roomFrame:Hide()
    if #chosen > 0 then self:CreateBulk(room.className, chosen)
    else self:UpdateBulkInfo(); self:Status(string.format("Deleted %d Character macros.", deleted)) end
end
