local _, KT = ...
-- Macros, laid out like the rest of ForeverTools (0.80.0): a group with a
-- sidebar (My class, My race, Generic, My own macros, Other classes, Hidden,
-- Settings). Each list shows every macro with its state (added or not) and
-- an Add button; click a macro to open it right there in the list: its text,
-- rank, mouseover, more lines, and Add. The macro logic stays in
-- MacroForge.lua; this file is the window.
local M = KT.modules.MacroForge
local D = M.data
local classKey, raceKey = D.classKey, D.raceKey
local W, H = 600, 660
local LIST_W, ROW_H, EDIT_H = 520, 54, 362
local GREEN, MUTED = {.45, .86, .55}, {.72, .66, .55}

-- Views --------------------------------------------------------------------------
-- Which list a page shows. The older fields (filter, browsedClass,
-- showHidden) follow, so the rest of the macro code works as before.
M.views = {
    class = {page = "MacroForge"}, race = {page = "MacroRace"}, generic = {page = "MacroGeneric"},
    own = {page = "MacroOwn"}, other = {page = "MacroOther"}, hidden = {page = "MacroHidden"},
}
function M:OtherClasses()
    local list = {}
    for _, name in ipairs(self:ClassNames()) do if name ~= classKey() then list[#list + 1] = name end end
    return list
end
function M:SetView(view)
    if not self.views[view] then view = "class" end
    self.view = view
    self.showHidden = view == "hidden"
    if view == "generic" then self.filter, self.browsedClass = "generic", nil
    elseif view == "other" then
        self.otherClass = self.otherClass or self:OtherClasses()[1]
        self.filter, self.browsedClass = "class", self.otherClass
    else self.filter, self.browsedClass = "mine", nil end
    self.entriesCache, self.entriesKey = nil, nil
end
function M:ViewEntries(view)
    view = view or self.view or "class"
    local list = {}
    if view == "class" then
        D.addEntries(list, D.classMacros[classKey()], classKey(), nil, "class")
        self:AddLearnedEntries(list, classKey())
    elseif view == "race" then D.addEntries(list, D.racials[raceKey()], nil, raceKey(), "racial")
    elseif view == "generic" then D.addEntries(list, D.genericMacros, nil, nil, "generic")
    elseif view == "own" then
        local customs = type(KT.db.customMacros) == "table" and KT.db.customMacros or {}
        for i = #customs, 1, -1 do
            local e = customs[i]
            if type(e) == "table" and type(e.name) == "string" and type(e.code) == "string" and (e.class == nil or e.class == classKey()) then list[#list + 1] = e end
        end
    elseif view == "other" then
        local name = self.otherClass or self:OtherClasses()[1]
        D.addEntries(list, D.classMacros[name], name, nil, "class")
    end
    return list
end
-- The text a macro gets when added: highest rank, your mouseover choice.
function M:DefaultBody(entry)
    local rank, mouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self:EntryMouseover(entry)
    local ok, body = pcall(self.BuildMacro, self, entry)
    self.selectedRank, self.mouseover = rank, mouseover
    return ok and body or "#showtooltip"
end
-- Already in your WoW macros (its normal text, or the text you edited here)?
local followers = {["Eat & Drink"] = "FoodWater", Bandage = "Bandage"}
-- The text shown in the editor. Macros that follow your bags (Bandage, Eat &
-- Drink) show what is in your bags now, unless you wrote your own text.
function M:PreviewBody(entry)
    local live = self:BuildMacro(entry)
    local body = KT:MacroBody(entry, live)
    local follow = followers[entry.name] and KT.modules[followers[entry.name]]
    if follow and follow.Ours and body ~= live and follow:Ours(body) then return live end
    return body
end
M.followers = followers
function M:IsAdded(entry)
    if not GetNumMacros or not GetMacroInfo then return false end
    -- Macros kept up to date are found under any name (renamed to blank, say).
    local follow = followers[entry.name] and KT.modules[followers[entry.name]]
    if follow and follow.Installed then return follow:Installed() end
    local body = self:DefaultBody(entry)
    if self:EntryExists(entry, body) then return true end
    local own = KT:MacroBody(entry, body)
    if own ~= body and self:EntryExists(entry, own) then return true end
    -- Your own macro that casts the same spell, under any name or text.
    return self:SameAction(entry, body) ~= nil
end
-- "9 of 22 added" for the sidebar; kept until your macros change.
function M:ViewCount(view)
    self.counts = self.counts or {}
    local cached = self.counts[view]
    if cached then return cached[1], cached[2] end
    local added, total = 0, 0
    for _, entry in ipairs(self:ViewEntries(view)) do
        if not self:IsHidden(entry) then
            total = total + 1
            if self:IsAdded(entry) then added = added + 1 end
        end
    end
    self.counts[view] = {added, total}
    return added, total
end
function M:Changed()
    self.counts = nil
    -- A macro that follows the game gets its current text and is remembered.
    for _, key in pairs(followers) do
        local follow = KT.modules[key]; if follow and follow.Update then follow.best = nil; pcall(follow.Update, follow) end
    end
    if self.frame and self.frame:IsShown() then self:RenderList() end
    if self.frame and KT.RefreshDock then KT:RefreshDock(self.frame) end
end

-- The list ---------------------------------------------------------------------------
local titles = {class = function() return classKey() .. " macros" end, race = function() return raceKey() .. " macros" end,
    generic = function() return "Generic macros" end, own = function() return "My own macros" end,
    other = function() return (M.otherClass or "Other class") .. " macros" end, hidden = function() return "Hidden macros" end}
local function stateOf(self, entry)
    if self.view == "hidden" then
        return self:HiddenState(entry) == "deleted" and "Deleted" or "Hidden", MUTED
    end
    if self:IsAdded(entry) then return "\226\156\147 Added", GREEN end
    if entry.category == "custom" then return "Your macro · not added yet", MUTED end
    return "Not added", MUTED
end
-- The "..." menu on a row.
function M:RowMenu(owner, entry)
    local list = {}
    local hidden = self:IsHidden(entry)
    if not hidden then
        list[#list + 1] = {value = "hide", label = "Hide from the list", icon = "Interface\\Icons\\INV_Misc_Eye_01",
            tooltip = "Hidden macros are never added. Find them under Hidden."}
        list[#list + 1] = {value = "delete", label = "Remove from the list", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady",
            tooltip = "Moves it to Hidden. Your WoW macro stays."}
    elseif entry.category == "custom" then
        list[#list + 1] = {value = "delete", label = "Delete for good", icon = "Interface\\RaidFrame\\ReadyCheck-NotReady", tooltip = "Delete this macro for good. Asks first."}
    end
    -- Your own and generic macros: the other tab in one click.
    local free = not (entry.class or entry.characterOnly or entry.category == "racial")
    if not hidden and free and not self:IsAdded(entry) then
        local other = self:ScopeFor(entry) == "account" and "character" or "account"
        list[#list + 1] = {value = "to:" .. other, label = other == "account" and "Add to General macros" or "Add to Character macros",
            icon = other == "account" and "Interface\\Icons\\" .. KT.icons.general or self:ClassIcon(classKey()),
            tooltip = other == "account" and "Shared by all your characters." or "Only this character."}
    end
    local body = self:DefaultBody(entry)
    if KT:MacroBody(entry, body) ~= body then
        list[#list + 1] = {value = "default", label = "Restore its original text", icon = "Interface\\Icons\\" .. KT.icons.reset, tooltip = "Forget your edits. Asks first."}
    end
    owner.options = function() return list end
    owner.value = nil; owner.menuWidth = 240
    owner.onSelect = function(value)
        if type(value) == "string" and value:sub(1, 3) == "to:" then
            local scope = value:sub(4)
            -- Your own macro remembers where it goes; a built-in one goes there once.
            if entry.category == "custom" then entry.saveTo = scope; self:QuickAdd(entry)
            else
                local saved = entry.saveTo; entry.saveTo = scope
                self:QuickAdd(entry); entry.saveTo = saved
            end
            if self.selectedMacro == entry then self:UpdateAddButton() end
        elseif value == "hide" then self:SetHidden(entry, true)
        elseif value == "delete" then self:DeleteEntry(entry)
        elseif value == "default" then
            KT:Confirm("Restore the original text of " .. entry.name .. "? Your edits are forgotten.", function()
                local record = KT:MacroRecord(entry); record.body = false; record.dirty = nil
                if self.selectedMacro == entry then self:UpdatePreview() end
                self:RenderList()
            end)
        end
    end
    KT:ShowChoices(owner)
end
-- Add one macro from its row (the text you see in its editor, if open).
function M:QuickAdd(entry)
    if InCombatLockdown() then self:Status("Leave combat before adding macros.", true); return end
    if self.view == "hidden" then self:SetHidden(entry, false); return end
    local body
    if self.selectedMacro == entry and self.expanded and self.preview then body = self.preview:GetText()
    else body = KT:MacroBody(entry, self:DefaultBody(entry)) end
    KT.modules.MacroEditor:InstallEntry(entry, body)
    C_Timer.After(0, function() self:Changed() end)
end
local function makeRow(self)
    local row = KT:QuietButton(self.list, "", LIST_W, ROW_H)
    row.label:Hide()
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(34, 34); row.icon:SetPoint("LEFT", 10, 0); KT:RoundIcon(row.icon)
    row.title = KT:Label(row, "", 15); row.title:SetPoint("TOPLEFT", 56, -8); row.title:SetWidth(LIST_W - 56 - 170)
    row.meta = KT:Label(row, "", 12); row.meta:SetPoint("TOPLEFT", 56, -29); row.meta:SetWidth(LIST_W - 56 - 170)
    for _, label in ipairs({row.title, row.meta}) do if label.SetWordWrap then label:SetWordWrap(false) end end
    row.more = KT:QuietButton(row, "...", 38, 32); row.more:SetPoint("RIGHT", -10, 0)
    row.more.label:ClearAllPoints(); row.more.label:SetPoint("CENTER", 0, 3)
    if row.more.icon then row.more.icon:Hide() end
    row.more:SetScript("OnClick", function(owner) if row.entry then self:RowMenu(owner, row.entry) end end)
    KT:Tooltip(row.more, "More", "Add to the other tab, hide, remove, or restore its original text.")
    row.action = KT:QuietButton(row, "Add", 104, 32); row.action:SetPoint("RIGHT", row.more, "LEFT", -6, 0)
    if row.action.icon then row.action.icon:Hide() end
    row.action.label:ClearAllPoints(); row.action.label:SetPoint("CENTER", 0, 0)
    if row.action.SetMotionScriptsWhileDisabled then row.action:SetMotionScriptsWhileDisabled(true) end
    row.action:SetScript("OnClick", function() if row.entry then self:QuickAdd(row.entry) end end)
    KT:Tooltip(row.action, function() return self.view == "hidden" and "Show again" or "Add" end, function()
        if self.view == "hidden" then return "Put this macro back in its list." end
        return row.added and "Already in your macros. Click the row to change it." or "Add it to your WoW macros, ready for your bars."
    end)
    row:SetScript("OnClick", function()
        local entry = row.entry; if not entry then return end
        if D.sameEntry(entry, self.selectedMacro) and self.expanded then self.expanded = false; self:RenderList(); return end
        self.expanded = true; self:Select(entry)
    end)
    KT:Tooltip(row, function() return row.entry and row.entry.name or "Macro" end, function()
        local entry = row.entry; if not entry then return "" end
        return (entry.note and (entry.note .. "\n\n") or "") .. "Click to open it here."
    end)
    return row
end
function M:UpdateFilters() end
-- Icons follow the game: gear you equip, items the game has just loaded,
-- spells you learn. Only the rows on screen, a moment after the change.
function M:RefreshIcons()
    if not (self.uiReady and self.frame and self.frame:IsShown()) then return end
    for _, row in ipairs(self.rows or {}) do
        if row:IsShown() and row.entry then row.icon:SetTexture(self:IconForEntry(row.entry)) end
    end
end
function M:RenderList()
    if not self.uiReady then return end
    local view = self.view or "class"
    local query = string.lower(self.search:GetText() or "")
    local function matches(entry)
        if query == "" then return true end
        return string.lower(entry.name .. " " .. (entry.class or "") .. " " .. (entry.race or "")):find(query, 1, true) ~= nil
    end
    local items = {}
    if view == "hidden" then
        local hidden, deleted = self:HiddenEntries()
        for _, part in ipairs({{"Hidden", hidden}, {"Deleted", deleted}}) do
            local kept = {}
            for _, entry in ipairs(part[2]) do if matches(entry) then kept[#kept + 1] = entry end end
            if #kept > 0 then
                items[#items + 1] = {head = part[1] .. " (" .. #kept .. ")"}
                for _, entry in ipairs(kept) do items[#items + 1] = {entry = entry} end
            end
        end
    else
        for _, entry in ipairs(self:ViewEntries(view)) do
            if matches(entry) and not self:IsHidden(entry) then items[#items + 1] = {entry = entry} end
        end
    end
    for _, row in ipairs(self.rows) do row:Hide() end
    self.listHeads = self.listHeads or {}
    for _, head in ipairs(self.listHeads) do head:Hide(); if head.ftHeading and head.ftHeading.line then head.ftHeading.line:Hide() end end
    local y, shown, heads, openRow = 0, 0, 0, nil
    for _, item in ipairs(items) do
        if item.head then
            heads = heads + 1
            local head = self.listHeads[heads]
            if not head then
                head = KT:Label(self.list, "", 13, true); head:SetTextColor(1, .82, 0)
                KT:SectionHeading(head, nil, 200, 14)
                self.listHeads[heads] = head
            end
            head:ClearAllPoints(); head:SetPoint("TOPLEFT", 4, -(y + 8)); head:SetText(item.head); head:Show()
            if head.ftHeading and head.ftHeading.line then head.ftHeading.line:Show() end
            y = y + 30
        else
            local entry = item.entry
            shown = shown + 1
            local row = self.rows[shown]
            if not row then row = makeRow(self); self.rows[shown] = row end
            row.entry = entry
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); y = y + ROW_H + 6
            row.icon:SetTexture(self:IconForEntry(entry))
            row.title:SetText(entry.name)
            local text, color = stateOf(self, entry)
            row.added = text:find("Added", 1, true) ~= nil
            row.meta:SetText(text); row.meta:SetTextColor(color[1], color[2], color[3])
            if view == "hidden" then row.action.label:SetText("Show again")
            else row.action.label:SetText(row.added and "Added" or "Add") end
            row.action.label:SetTextColor(row.added and view ~= "hidden" and .6 or .95, row.added and view ~= "hidden" and .56 or .90, row.added and view ~= "hidden" and .48 or .81)
            row.action:SetEnabled(not row.added or view == "hidden")
            row.more:SetShown(view ~= "hidden" or entry.category == "custom")
            local open = self.expanded and D.sameEntry(entry, self.selectedMacro)
            KT:SetSelected(row, open)
            if open then row.title:SetTextColor(1, .86, .55) else row.title:SetTextColor(.95, .90, .81) end
            row:Show()
            -- The open macro's editor sits right under its row.
            if open then
                openRow = row
                self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", self.list, "TOPLEFT", 16, -(y - 2))
                y = y + EDIT_H + 8
            end
        end
    end
    self.detail:SetShown(openRow ~= nil)
    if not openRow and self.advancedPanel then self.advancedPanel:Hide() end
    self.list:SetHeight(math.max(1, y))
    self.empty:SetShown(shown == 0)
    self.empty:SetText(view == "hidden" and "Nothing hidden or deleted." or view == "own" and "No macros of your own yet. Use + New macro." or "No matching macros.")
    self.frame.titleText:SetText(titles[view]())
    self:UpdateBulkInfo()
end

-- The editor in the list --------------------------------------------------------------
function M:UpdatePreview()
    local entry = self.selectedMacro
    if not entry or not self.uiReady then return end
    self:ForgetDefaultBody(entry)
    self.title:SetText(entry.name)
    local hasRanks = entry.ranks and entry.ranks > 1
    self.rankLabel:SetText(hasRanks and (self.selectedRank == "max" and "Highest rank" or "Rank " .. self.selectedRank) or "One rank")
    self.prevRank:SetShown(hasRanks); self.nextRank:SetShown(hasRanks)
    self.prevRank:SetEnabled(hasRanks); self.nextRank:SetEnabled(hasRanks)
    local poison = self.IsPoison and self.IsPoison(entry)
    -- Rank families (poisons, mana gems): a list instead of the rank arrows.
    local fam = self.Family and self:Family(entry.name)
    if self.familyButton then
        self.familyButton:SetShown(fam ~= nil)
        if fam then
            self.prevRank:Hide(); self.nextRank:Hide(); self.rankLabel:SetText("")
            local pick = self:FamilyPick(fam)
            local now = self:FamilyChoice(fam)
            local short = now:sub(#fam.head + 2)
            if fam.kind == "spell" then short = now:match("(%S+)$") or now end
            if short == "" then short = "I" end
            self.familyButton.label:SetText((pick and "Kept: " or "Newest: ") .. short)
        else self.rankLabel:SetShown(true) end
    end
    self.mouseoverButton:SetShown(not poison); self.poisonRowButton:SetShown(poison and true or false)
    if poison then self:UpdatePoisonButton() end
    local showMouseover = self:CanMouseover(entry)
    self.mouseoverButton:SetEnabled(showMouseover); self.mouseoverButton:SetAlpha(showMouseover and 1 or .45)
    local own = self.mouseover ~= (self.bulkMouseover == true)
    self.mouseoverButton.label:SetText(showMouseover and ((self.mouseover and "Mouseover: On" or "Mouseover: Off") .. (own and " *" or "")) or "Mouseover: not for this one")
    KT:SetSelected(self.mouseoverButton, showMouseover and self.mouseover)
    self.loadingPreview = true
    self.preview:SetText(self:PreviewBody(entry))
    self.loadingPreview = false
    self:UpdateScopeButton()
    self:UpdateDefaultButton()
    self:UpdateAddButton()
end
function M:UpdateDefaultButton()
    if not self.defaultButton or not self.selectedMacro then return end
    local changed = (self.preview:GetText() or "") ~= self:BuildMacro(self.selectedMacro)
    self.defaultButton:SetShown(changed)
end
function M:UpdateAddButton()
    local entry = self.selectedMacro; if not entry or not self.addButton then return end
    local character = self:ScopeFor(entry) == "character"
    local added = self:IsAdded(entry)
    -- Already in your macros: saving writes your changes into it.
    self.addButton.label:SetText(added and "Save changes to your macro" or ("Save to " .. (character and "Character" or "General") .. " macros"))
end
-- Settings ---------------------------------------------------------------------------------
function M:UpdateScopeButton()
    local button = self.scopeButton; if not button then return end
    button.value = self.scope
    button.label:SetText("Save to: " .. (self.scope == "account" and "General" or "Character"))
    if self.scope == "account" then button.icon:SetTexture("Interface\\Icons\\" .. KT.icons.general) else button.icon:SetTexture(self:ClassIcon(classKey())) end
end
function M:ScopeChoices()
    return {
        {value = "character", label = "Character", icon = self:ClassIcon(classKey()), tooltip = "This character's own macro tab."},
        {value = "account", label = "General", icon = "Interface\\Icons\\" .. KT.icons.general,
            tooltip = "Shared by all characters. Class and race macros go to Character."},
    }
end
function M:ChooseScope(scope)
    self.scope = scope == "account" and "account" or "character"
    KT.db.macroScope = self.scope
    self:UpdateScopeButton(); self:UpdateAddButton()
    if self.settingsPage then self.settingsPage:Refresh() end
end
function M:LayoutTopBar() end
function M:UpdateIconsButton()
    if not self.iconsButton then return end
    local on = KT.db.macroUnlearnedIcons == true
    self.iconsButton.label:SetText("Icons for unlearned spells: " .. (on and "On" or "Off"))
    KT:SetSelected(self.iconsButton, on)
end
function M:UpdateUpdatesButton()
    if not self.updatesButton then return end
    local mode = KT.MacroWatch and KT.MacroWatch:Mode() or "ask"
    self.updatesButton.label:SetText("Update macros: " .. ({ask = "Ask", auto = "Automatically", off = "Off"})[mode])
end
function M:UpdatePoisonButton()
    local on = KT.db.macroPoisonConfirm == true
    if self.poisonRowButton then
        self.poisonRowButton.label:SetText("Auto-replace poison: " .. (on and "On" or "Off"))
        KT:SetSelected(self.poisonRowButton, on)
    end
    if not self.poisonButton then return end
    self.poisonButton.label:SetText("Replace poisons without asking: " .. (on and "On" or "Off"))
    KT:SetSelected(self.poisonButton, on)
end
-- How many of this list's macros are not added yet (and room left).
function M:UpdateBulkInfo()
    self.bulkMouseover = KT.db.macroBulkMouseover == true
    local _, count = GetNumMacros()
    local free = math.max(0, (MAX_CHARACTER_MACROS or 30) - (count or 0))
    local needed = 0
    local view = self.view or "class"
    if view == "class" or view == "other" then
        for _, entry in ipairs(self:AddableEntries()) do if not self:IsAdded(entry) then needed = needed + 1 end end
    end
    if self.bulkButton then
        local bulk = view == "class" or view == "other"
        self.bulkButton:SetShown(bulk)
        self.bulkButton.label:SetText(needed > 0 and ("+ Add the " .. needed .. " missing") or "All added")
        self.bulkButton:SetEnabled(needed > 0); self.bulkButton:SetAlpha(needed > 0 and 1 or .55)
        self.newButton:SetShown(view == "own")
        self.classPicker:SetShown(view == "other")
        if view == "other" then self.classPicker.label:SetText("Class: " .. (self.otherClass or "?")); self.classPicker.icon:SetTexture(self:ClassIcon(self.otherClass)) end
        -- Other classes: the class picker takes the search box's place.
        self.search:ClearAllPoints(); self.search:SetShown(view ~= "other")
        self.search:SetPoint("TOPLEFT", 24, -62); self.search:SetWidth((bulk or view == "own") and (W - 48 - 230) or (W - 48))
    end
    if self.bulkMouseoverButton then
        self.bulkMouseoverButton.label:SetText("Mouseover for all macros: " .. (self.bulkMouseover and "On" or "Off"))
        KT:SetSelected(self.bulkMouseoverButton, self.bulkMouseover)
    end
    self:UpdateIconsButton(); self:UpdatePoisonButton(); self:UpdateScopeButton()
    return needed, free
end
function M:CreateCustom(name, forClass)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" or #name > 16 then self:Status("Enter a macro name of 1–16 characters.", true); return end
    local class = forClass and classKey() or nil
    for _, entry in ipairs(type(KT.db.customMacros) == "table" and KT.db.customMacros or {}) do
        if entry.name == name and entry.class == class then self:Status("That custom macro name already exists here.", true); return end
    end
    local catalogue = class and D.classMacros[class] or D.genericMacros
    for _, entry in ipairs(catalogue or {}) do if entry[1] == name then self:Status("That name already belongs to a built-in macro.", true); return end end
    KT.db.customMacros = type(KT.db.customMacros) == "table" and KT.db.customMacros or {}
    local entry = {name = name, code = "#showtooltip", class = class, category = "custom", icon = "INV_Misc_Note_01", kind = "custom",
        saveTo = not class and (self.newScope == "account" and "account" or "character") or nil}
    KT.db.customMacros[#KT.db.customMacros + 1] = entry
    self.newPanel:Hide()
    self.counts = nil
    KT:OpenModule("MacroOwn")
    self.expanded = true; self:Select(entry)
    if self.listScroll and self.listScroll.SetVerticalScroll then self.listScroll:SetVerticalScroll(0) end
    self:Status("Your macro is at the top. Add spells or edit it, then Add.")
end

-- Building the window ---------------------------------------------------------------------
local function searchBox(parent)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(400, 30); KT:Panel(box)
    box:SetAutoFocus(false); box:SetFont(KT.bodyFont, 14, ""); box:SetTextInsets(10, 10, 0, 0)
    box.placeholder = KT:Label(box, "Search macros...", 14); box.placeholder:SetPoint("LEFT", 10, 0); box.placeholder:SetTextColor(.55, .49, .40)
    box:SetScript("OnEditFocusGained", function() box.placeholder:Hide() end)
    box:SetScript("OnEditFocusLost", function() box.placeholder:SetShown(box:GetText() == "") end)
    box:SetScript("OnEscapePressed", function() box:ClearFocus() end)
    return box
end
function M:CreateEditor(frame)
    local detail = CreateFrame("Frame", nil, self.list)
    self.detail = detail
    local IW = LIST_W - 16 -- editor width
    detail:SetSize(IW, EDIT_H); KT:Panel(detail); detail:Hide()
    self.title = KT:Label(detail, "", 14, true); self.title:Hide()
    local FULL = IW - 24
    -- The macro text, full width.
    self.previewArea = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    self.previewArea:SetSize(FULL, 110); self.previewArea:SetPoint("TOPLEFT", 12, -12)
    KT:AutoHideScrollBar(self.previewArea, function(needed)
        local width = needed and (FULL - 22) or FULL
        self.previewArea:SetWidth(width); if self.preview then self.preview:SetWidth(width) end
    end)
    self.preview = CreateFrame("EditBox", nil, self.previewArea)
    self.preview:SetMultiLine(true); self.preview:SetAutoFocus(false)
    self.preview:SetFont(KT.bodyFont, 14, ""); self.preview:SetSize(FULL, 110)
    self.preview:SetTextInsets(6, 6, 6, 6); KT:Panel(self.preview)
    self.previewArea:SetScrollChild(self.preview)
    self.preview:SetScript("OnTextChanged", function(box, userInput)
        local _, lines = box:GetText():gsub("\n", "")
        box:SetHeight(math.max(self.previewArea:GetHeight() or 110, (lines + math.ceil(#box:GetText() / 55) + 1) * 17 + 12))
        if self.selectedMacro and userInput and not self.loadingPreview then
            KT:StoreMacroBody(self.selectedMacro, box:GetText())
            self:UpdateDefaultButton(); self:RefreshQuickButtons()
            if self.selectedMacro.category == "custom" then self:RefreshIcons() end
        end
    end)
    self.preview:SetScript("OnEditFocusLost", function() KT:FlushMacroRevision(self.selectedMacro) end)
    self.preview:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.preview:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local top = -y; local offset = self.previewArea:GetVerticalScroll()
        if top < offset then self.previewArea:SetVerticalScroll(math.max(0, top))
        elseif top + height > offset + self.previewArea:GetHeight() then self.previewArea:SetVerticalScroll(top + height - self.previewArea:GetHeight()) end
    end)
    self.previewCaret = KT:TextCaret(self.preview, 6)
    -- Grouped in two small sections so each control says what it is for:
    -- "Options" (rank, mouseover or the poison choice) and "Add more"
    -- (a learned spell, extra lines); the actions sit at the bottom.
    local function heading(text, y, icon)
        local l = KT:Label(detail, text, 12, true); l:SetPoint("TOPLEFT", 12, y)
        KT:SectionHeading(l, icon, "full", 14); return l
    end
    -- Each band is 24 tall around its words: rows start 24 below the words.
    heading("Options", -132, "INV_Misc_Gear_01")
    heading("Add more", -198, "INV_Misc_Note_04")
    -- Row: rank, mouseover.
    self.prevRank = KT:QuietButton(detail, "<", 30, 30); self.prevRank:SetPoint("TOPLEFT", 12, -156)
    self.prevRank:SetScript("OnClick", function() self:StepRank(-1) end)
    KT:Tooltip(self.prevRank, "Spell rank", "Pick a lower rank, for example to save mana.")
    self.rankLabel = KT:Label(detail, "", 14); self.rankLabel:SetPoint("LEFT", self.prevRank, "RIGHT", 4, 0); self.rankLabel:SetWidth(96); self.rankLabel:SetJustifyH("CENTER")
    self.nextRank = KT:QuietButton(detail, ">", 30, 30); self.nextRank:SetPoint("LEFT", self.rankLabel, "RIGHT", 4, 0)
    self.nextRank:SetScript("OnClick", function() self:StepRank(1) end)
    KT:Tooltip(self.nextRank, "Spell rank", "Your highest rank is used by default.")
    -- Poisons and mana gems: newest by itself, or keep an earlier one.
    self.familyButton = KT:QuietButton(detail, "", 164, 30, "generic"); self.familyButton:SetPoint("TOPLEFT", 12, -156); self.familyButton:Hide()
    if self.familyButton.label.SetWordWrap then self.familyButton.label:SetWordWrap(false) end
    KT:MakeChoice(self.familyButton, function()
        local fam = self.selectedMacro and self:Family(self.selectedMacro.name)
        if not fam then return {} end
        local list = {{"auto", "Newest (updates by itself)", "Uses the best one you have and switches when you get a better one."}}
        local seen = {}
        local avail = self:FamilyAvailable(fam)
        for i = #avail, 1, -1 do local m = avail[i]; seen[m.name] = true; list[#list + 1] = {m.name, m.name, "Keep this one, even when you get a better one."} end
        local pick = self:FamilyPick(fam)
        if pick and not seen[pick] then list[#list + 1] = {pick, pick .. " (not in your bags)", "Your pick."} end
        return list
    end, function()
        local fam = self.selectedMacro and self:Family(self.selectedMacro.name)
        return fam and self:FamilyPick(fam) or "auto"
    end, function(value)
        local fam = self.selectedMacro and self:Family(self.selectedMacro.name); if not fam then return end
        self:SetFamilyPick(fam, value ~= "auto" and value or nil)
        local record = KT:MacroRecord(self.selectedMacro); record.body = false; record.dirty = nil
        self:UpdatePreview()
        if self.UpdateFamilyMacros then self:UpdateFamilyMacros() end
    end)
    KT:Tooltip(self.familyButton, "Version", "Newest: the macro uses the best one you have; when a better one comes, you are asked to update (Macro settings > Update macros). Or pick an earlier one to keep.")
    local HALF = math.floor((FULL - 8) / 2)
    self.mouseoverButton = KT:QuietButton(detail, "", FULL - 172, 30, "mouseover"); self.mouseoverButton:SetPoint("TOPLEFT", 184, -156)
    if self.mouseoverButton.SetMotionScriptsWhileDisabled then self.mouseoverButton:SetMotionScriptsWhileDisabled(true) end
    self.mouseoverButton:SetScript("OnClick", function()
        self.mouseover = not self.mouseover
        if type(KT.db.macroMouseover) ~= "table" then KT.db.macroMouseover = {} end
        local own = nil
        if self.mouseover ~= (self.bulkMouseover == true) then own = self.mouseover end
        KT.db.macroMouseover[KT:MacroKey(self.selectedMacro)] = own
        local record = KT:MacroRecord(self.selectedMacro); record.body = false; record.dirty = nil
        self:UpdatePreview()
    end)
    KT:Tooltip(self.mouseoverButton, "Mouseover", "Cast on the unit under your mouse and keep your target. Changing it here makes an exception (*).")
    -- Rogue poisons can't use mouseover: their spot holds the poison choice.
    self.poisonRowButton = KT:QuietButton(detail, "", FULL - 172, 30, "generic"); self.poisonRowButton:SetPoint("TOPLEFT", 184, -156); self.poisonRowButton:Hide()
    self.poisonRowButton.icon:SetTexture("Interface\\Icons\\Ability_Poisons")
    self.poisonRowButton:SetScript("OnClick", function()
        KT.db.macroPoisonConfirm = not (KT.db.macroPoisonConfirm == true)
        local record = KT:MacroRecord(self.selectedMacro); record.body = false; record.dirty = nil
        self:UpdatePoisonButton(); self:UpdatePreview()
    end)
    KT:Tooltip(self.poisonRowButton, "Auto-replace poison", "If the weapon already has a poison, the game asks whether to replace it. Turn this on and the macro answers Yes for you. It counts for all your poison macros (also in Macro settings). Save to put it in your macro.")
    -- Row: more lines, original text.
    self.advancedButton = KT:QuietButton(detail, "Extra lines…", HALF, 30, "generic"); self.advancedButton:SetPoint("TOPLEFT", 12, -260)
    KT:GearIcon(self.advancedButton)
    -- The cog takes the icon's place; the words stay.
    local cogSpot = self.advancedButton.icon
    self.advancedButton.gear:ClearAllPoints(); self.advancedButton.gear:SetPoint("CENTER", cogSpot, "CENTER")
    if cogSpot then cogSpot:SetTexture(nil); cogSpot:SetAlpha(0) end
    self.advancedButton.label:Show()
    KT:Tooltip(self.advancedButton, "Extra lines", "Stop casting first, start attacking, use a trinket, equip a weapon and more. Opens beside the window.")
    self.defaultButton = KT:QuietButton(detail, "Undo my edits", HALF, 30, "reset"); self.defaultButton:SetPoint("TOPLEFT", 20 + HALF, -260); self.defaultButton:Hide()
    self.defaultButton:SetScript("OnClick", function() KT:Confirm("Undo your edits and go back to the macro as it came?", function() self:RestoreDefault() end) end)
    KT:Tooltip(self.defaultButton, "Undo my edits", "Go back to the macro as it came. Asks first.")
    -- Row: add a learned spell to the text.
    -- Picking a spell puts its /cast line in the text right away.
    self.spellChoice = KT:Dropdown(detail, FULL, function() return self:LearnedSpellChoices() end, function(value)
        self.quickSpell = value
        self:AddQuickSpell()
        self.quickSpell = nil
        self.spellChoice.value = nil; self.spellChoice.label:SetText("Add another spell…")
    end, "add")
    self.spellChoice:SetPoint("TOPLEFT", 12, -222); self.spellChoice.label:SetText("Add another spell…")
    KT:Tooltip(self.spellChoice, "Add another spell", "Pick one of your spells to add it at the end of the macro.")
    -- Row: add the macro.
    local add = KT:AccentButton(detail, "Save to Character macros", FULL, 34, "macros"); add:SetPoint("TOPLEFT", 12, -300); self.addButton = add
    KT:SaveButton(add)
    add:SetScript("OnClick", function()
        if self.selectedMacro then
            KT.modules.MacroEditor:InstallEntry(self.selectedMacro, self.preview:GetText())
            C_Timer.After(0, function() self:Changed() end)
        end
    end)
    KT:Tooltip(add, "Save", "Saves this text into your WoW macros (a new macro, or your changes to the one you have). Then drag it from Esc > Macros to your bars.")
    local hint = KT:Label(detail, "You can type in the box above. Your changes are kept.", 12); hint:SetPoint("TOPLEFT", 12, -342); hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    -- "More lines": the floating panel next to the window.
    self:CreateAdvanced(frame)
end
function M:CreateUI()
    if self.uiReady then return end
    self.rows = {}
    local frame = KT:Window("ForeverToolsMacros", "Macros", W, H)
    self.frame = frame
    frame:HookScript("OnHide", function() self.entriesCache, self.entriesKey = nil, nil; KT:FlushMacroRevision(self.selectedMacro) end)
    KT:PageInfo(frame, "Macros", "Ready-made macros for your class, race and everyone, plus your own. Add puts one in your WoW macros; drag it from Esc > Macros to your bars.\n\nClick a macro to change its text, rank or mouseover.")
    self.search = searchBox(frame); self.search:SetPoint("TOPLEFT", 24, -62)
    self.search:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then self:RenderList(); return end
        KT:Coalesce("macroSearch", function() self:RenderList() end, 0.15)
    end)
    self.bulkButton = KT:AccentButton(frame, "", 220, 30, "add"); self.bulkButton:SetPoint("TOPRIGHT", -24, -62)
    if self.bulkButton.SetMotionScriptsWhileDisabled then self.bulkButton:SetMotionScriptsWhileDisabled(true) end
    self.bulkButton:SetScript("OnClick", function() self:ConfirmBulk(); C_Timer.After(0, function() self:Changed() end) end)
    KT:Tooltip(self.bulkButton, "Add the missing ones", function() return "Add every " .. self:BulkClass() .. " macro not in your Character macros yet. Ones you have are left alone." end)
    self.newButton = KT:AccentButton(frame, "+ New macro", 220, 30, "add"); self.newButton:SetPoint("TOPRIGHT", -24, -62)
    self.newButton:SetScript("OnClick", function() self.newName:SetText(""); self.newClass = false; self.newScope = self.scope == "account" and "account" or "character"; self:RefreshNewPanel(); self.newPanel:Show(); if self.newName.SetFocus then self.newName:SetFocus() end end)
    KT:Tooltip(self.newButton, "New macro", "Make your own macro.")
    self.classPicker = KT:Dropdown(frame, 200, function()
        local list = {}
        for _, name in ipairs(self:OtherClasses()) do list[#list + 1] = {value = name, label = name, icon = self:ClassIcon(name)} end
        return list
    end, function(name) self.otherClass = name; self:SetView("other"); self.expanded = false; self:RenderList(); KT:RefreshDock(frame) end, "classes")
    self.classPicker:SetHeight(30); self.classPicker:SetPoint("TOPLEFT", 24, -62); self.classPicker:SetWidth(W - 48 - 230); self.classPicker.menuWidth = 220
    KT:Tooltip(self.classPicker, "Class", "Another class's macros, for an alt.")
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -104); scroll:SetPoint("BOTTOMRIGHT", -46, 44); self.listScroll = scroll
    self.list = CreateFrame("Frame", nil, scroll); self.list:SetWidth(LIST_W); scroll:SetScrollChild(self.list)
    KT:AutoHideScrollBar(scroll)
    self.empty = KT:Label(self.list, "No matching macros.", 14); self.empty:SetPoint("TOPLEFT", 6, -8)
    self:CreateEditor(frame)
    -- New macro: a small panel over the window.
    local newPanel = CreateFrame("Frame", nil, frame); self.newPanel = newPanel
    newPanel:SetSize(420, 250); newPanel:SetPoint("CENTER", frame, "CENTER"); newPanel:SetFrameLevel(frame:GetFrameLevel() + 40); KT:MakeDraggable(newPanel, frame); KT:Panel(newPanel); newPanel:Hide()
    local newTitle = KT:Label(newPanel, "New macro", 18, true); newTitle:SetPoint("TOPLEFT", 16, -16)
    KT:AddClose(newPanel, nil, 8)
    local nameHint = KT:Label(newPanel, "Name (up to 16 characters)", 13); nameHint:SetPoint("TOPLEFT", 18, -56)
    self.newName = CreateFrame("EditBox", nil, newPanel, "InputBoxTemplate"); self.newName:SetSize(370, 28); self.newName:SetPoint("TOPLEFT", 25, -79)
    self.newName:SetFont(KT.bodyFont, 14, ""); self.newName:SetAutoFocus(false)
    self.newName:SetScript("OnEscapePressed", function() newPanel:Hide() end)
    -- Where it goes: General (all your characters), Character (this one) or
    -- My class (this class's list, Character tab).
    self.newGeneral = KT:QuietButton(newPanel, "General", 120, 32, "general"); self.newGeneral:SetPoint("TOPLEFT", 18, -122)
    self.newGeneral:SetScript("OnClick", function() self.newClass = false; self.newScope = "account"; self:RefreshNewPanel() end)
    self.newGeneric = KT:QuietButton(newPanel, "Character", 120, 32, "generic"); self.newGeneric:SetPoint("LEFT", self.newGeneral, "RIGHT", 12, 0)
    self.newGeneric:SetScript("OnClick", function() self.newClass = false; self.newScope = "character"; self:RefreshNewPanel() end)
    self.newClassButton = KT:QuietButton(newPanel, "My class", 120, 32, "classes"); self.newClassButton:SetPoint("LEFT", self.newGeneric, "RIGHT", 12, 0)
    self.newClassButton:SetScript("OnClick", function() self.newClass = true; self:RefreshNewPanel() end)
    KT:Tooltip(self.newGeneral, "General", "Any class. Goes to General macros: shared by all your characters.")
    KT:Tooltip(self.newGeneric, "Character", "Any class. Goes to this character's macros.")
    KT:Tooltip(self.newClassButton, "My class", "Listed with your class's macros. Goes to Character macros.")
    local createCustom = KT:AccentButton(newPanel, "Create macro", 384, 32, "add"); createCustom:SetPoint("BOTTOM", 0, 20); self.createCustomButton = createCustom
    createCustom:SetScript("OnClick", function() self:CreateCustom(self.newName:GetText(), self.newClass) end)
    -- Status line (and the list of skipped macros after adding many).
    self.status = KT:Label(frame, "", 13); self.status:SetPoint("BOTTOMLEFT", 24, 18); self.status:SetWidth(W - 48)
    self.statusHover = CreateFrame("Frame", nil, frame); self.statusHover:SetAllPoints(self.status); self.statusHover:EnableMouse(true); self.statusHover:Hide()
    self.statusHover:SetScript("OnEnter", function(owner)
        if not self.skippedText then return end
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText("Skipped macros", 1, .82, 0)
        GameTooltip:AddLine(self.skippedText, .96, .93, .86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Make room in your Character macros, then add the missing ones again.", .66, .59, .48, true)
        GameTooltip:Show()
    end)
    self.statusHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    StaticPopupDialogs.FOREVERTOOLS_BULK = {text = "", button1 = "Add class macros", button2 = "Cancel", OnAccept = function() local chosen = self.pendingBulkClass; self.pendingBulkClass = nil; if chosen then self:CreateBulk(chosen); self:Changed() end end, OnCancel = function() self.pendingBulkClass = nil end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3}
    StaticPopupDialogs.FOREVERTOOLS_FOREIGN_SINGLE = {text = "", button1 = "Add anyway", button2 = "Cancel", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() local entry = self.pendingEntry; self.pendingEntry = nil; if entry then self:CreateEntry(entry, true); self:Changed() end end,
        OnCancel = function() self.pendingEntry = nil end}
    self.scope = KT.db.macroScope == "account" and "account" or "character"
    self:SetupDeleteDialogs()
    self:CreateSettings()
    for _, info in pairs(self.views) do if info.module then info.module.frame = frame end end
    self.uiReady = true
end
-- "More lines": stop cast, start attack, use gear, equip an item. A panel
-- that opens beside the window.
function M:CreateAdvanced(frame)
    local panel = CreateFrame("Frame", nil, frame); self.advancedPanel = panel
    panel:SetSize(462, 232); panel:SetFrameLevel(frame:GetFrameLevel() + 20); panel:SetFrameStrata("FULLSCREEN"); panel:SetClampedToScreen(true)
    KT:MakeDraggable(panel, frame); KT:Panel(panel); panel:Hide()
    self.advancedButton:SetScript("OnClick", function()
        if not panel:IsShown() then
            panel:ClearAllPoints()
            local right = frame.GetRight and frame:GetRight(); local screen = UIParent.GetWidth and UIParent:GetWidth()
            if right and screen and screen - right < 470 then panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8 - (KT.dockWidth or 0), -104)
            else panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -104) end
        end
        panel:SetShown(not panel:IsShown())
    end)
    panel:HookScript("OnShow", function() KT:SetSelected(self.advancedButton, true) end)
    panel:HookScript("OnHide", function() KT:SetSelected(self.advancedButton, false) end)
    KT:AddClose(panel, nil, 8)
    local title = KT:Label(panel, "Extra lines", 15, true); title:SetPoint("TOPLEFT", 12, -14)
    local sub = KT:Label(panel, "Click to add a line, click again to take it out.", 12); sub:SetPoint("TOPLEFT", 12, -34); sub:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    local function heading(text, y, icon) local l = KT:Label(panel, text, 12, true); l:SetPoint("TOPLEFT", 12, y); KT:SectionHeading(l, icon, 140, 14); return l end
    heading("When you press it", -60, "Spell_Holy_Silence")
    self.quickButtons = {}
    -- Each button says what it does and whether the line is in the macro.
    local function lineButton(name, line, icon, x, y, width, tip)
        local button = KT:QuietButton(panel, name, width, 28, "generic")
        button.icon:SetTexture(icon); button:SetPoint("TOPLEFT", x, y); button.name = name
        button:SetScript("OnClick", function() self:EditQuickLine(line) end)
        KT:Tooltip(button, name, tip)
        self.quickButtons[#self.quickButtons + 1] = {button = button, line = line, name = name}
        return button
    end
    lineButton("Stop casting first", "/stopcasting", "Interface\\Icons\\Spell_Holy_Silence", 12, -82, 215, "Adds /stopcasting at the top: cancels what you are casting so this goes off at once.")
    lineButton("Start attacking", "/startattack", "Interface\\Icons\\Ability_MeleeDamage", 235, -82, 215, "Adds /startattack: also starts your auto attack on the target.")
    heading("Use a trinket or other gear", -122, "INV_Jewelry_Talisman_07")
    local trinkets = {{13, "Trinket 1", "Trinket0Slot", "Trinket"}, {14, "Trinket 2", "Trinket1Slot", "Trinket"}}
    local slots = {{1,"Head","HeadSlot","Head"},{2,"Neck","NeckSlot","Neck"},{3,"Shoulders","ShoulderSlot","Shoulder"},{5,"Chest","ChestSlot","Chest"},{6,"Waist","WaistSlot","Waist"},{7,"Legs","LegsSlot","Legs"},{8,"Feet","FeetSlot","Feet"},{9,"Wrist","WristSlot","Wrists"},{10,"Hands","HandsSlot","Hands"},{11,"Ring 1","Finger0Slot","Finger"},{12,"Ring 2","Finger1Slot","Finger"},{15,"Back","BackSlot","Chest"},{16,"Main hand","MainHandSlot","MainHand"},{17,"Off hand","SecondaryHandSlot","SecondaryHand"},{18,"Ranged","RangedSlot","Ranged"}}
    local function slotIcon(slot)
        local native = (C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo) or GetInventorySlotInfo
        local placeholder = "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slot[4]
        if native then
            local ok, _, texture = pcall(native, slot[3])
            if ok and texture and (not issecretvalue or not issecretvalue(texture)) then placeholder = texture end
        end
        if GetInventoryItemTexture then
            local ok, texture = pcall(GetInventoryItemTexture, "player", slot[1])
            if ok and texture and (not issecretvalue or not issecretvalue(texture)) then return texture end
        end
        return placeholder
    end
    self.slotButtons = {}
    for i, slot in ipairs(trinkets) do
        local button = lineButton(slot[2], "/use " .. slot[1], nil, 12 + (i - 1) * 148, -144, 142, "Adds /use " .. slot[1] .. ": uses the trinket you wear there (its Use effect) together with this macro.")
        self.slotButtons[i] = {button = button, slot = slot}
    end
    -- Every other slot in one list; slots already in the macro are marked.
    self.otherGear = KT:Dropdown(panel, 142, function()
        local body = "\n" .. (self.preview and self.preview:GetText() or "") .. "\n"
        local list = {}
        for _, slot in ipairs(slots) do
            local on = body:find("\n/use " .. slot[1] .. "\n", 1, true) ~= nil
            list[#list + 1] = {value = slot[1], label = slot[2] .. (on and "  (in macro)" or ""), icon = slotIcon(slot), tooltipTitle = slot[2], tooltip = on and "Click to take /use " .. slot[1] .. " out." or "Click to add /use " .. slot[1] .. "."}
        end
        return list
    end, function(value) self:EditQuickLine("/use " .. value); self:RefreshQuickButtons() end, "generic")
    self.otherGear:SetPoint("TOPLEFT", 308, -144); self.otherGear.menuWidth = 200
    self.otherGear.label:SetText("Other gear...")
    KT:Tooltip(self.otherGear, "Other gear", "Use the item in another slot (a Use effect on gloves, a belt, a weapon...). Slots already in the macro are marked.")
    local equipTop = 184
    heading("Weapon swap", -equipTop, "INV_Sword_04")
    -- One row per hand; each lists every weapon you carry.
    self.handDrops = {}
    for i, hand in ipairs({{16, "Main hand", "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand"}, {17, "Off hand", "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand"}}) do
        local y = -equipTop - 22 - (i - 1) * 34
        local name = KT:Label(panel, hand[2], 13); name:SetPoint("TOPLEFT", 14, y - 7)
        local drop = KT:Dropdown(panel, 340, function() return self:WeaponChoices(hand[1]) end, function(value) self:SetEquipLine(hand[1], value); self:RefreshEquip() end, "generic")
        drop:SetPoint("TOPLEFT", 110, y); drop.menuWidth = 340
        if drop.icon then drop.icon:SetTexture(hand[3]) end
        if drop.label.SetWordWrap then drop.label:SetWordWrap(false) end
        KT:Tooltip(drop, hand[2] .. " swap", "Pick any weapon you carry (worn or in your bags) to equip in your " .. hand[2]:lower() .. " before the spell. Greyed: it can't go in this hand. None: no swap.")
        self.handDrops[hand[1]] = drop
    end
    local otherTop = equipTop + 22 + 2 * 34 + 8
    local otherTitle = KT:Label(panel, "Other gear (ranged, trinkets, rings...)", 12); otherTitle:SetPoint("TOPLEFT", 14, -otherTop); otherTitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    self.equipSlot = KT:Dropdown(panel, 142, function()
        local list = {}
        for _, entry in ipairs(self.equipSlots) do
            local used = self:EquipLine(entry[1])
            list[#list + 1] = {value = entry[1], label = entry[2] .. (used and " *" or ""), tooltipTitle = entry[2], tooltip = used and ("This macro equips " .. used .. " here.") or nil}
        end
        return list
    end, function(value) self.equipSlotValue = value; self:RefreshEquip() end, "generic")
    self.equipSlot:SetPoint("TOPLEFT", 12, -otherTop - 18)
    KT:Tooltip(self.equipSlot, "Slot", "The gear slot. * means this macro already equips it. In a fight only weapons swap.")
    self.equipItem = KT:Dropdown(panel, 290, function() return self:EquipChoices(self.equipSlotValue or 18) end, function(value) self:SetEquipLine(self.equipSlotValue or 18, value) end, "generic")
    self.equipItem:SetPoint("TOPLEFT", 160, -otherTop - 18); self.equipItem.menuWidth = 290
    if self.equipItem.label.SetWordWrap then self.equipItem.label:SetWordWrap(false) end
    KT:Tooltip(self.equipItem, "Item to equip", "Add an equip line for this slot. None removes it.")
    self.equipSlotValue = 18
    panel:SetHeight(otherTop + 18 + 28 + 14)
    panel:HookScript("OnShow", function()
        for _, entry in ipairs(self.slotButtons) do entry.button.icon:SetTexture(slotIcon(entry.slot)) end
        self:RefreshQuickButtons()
    end)
end
-- The Settings page: where macros go, mouseover for all, icons, clean-up.
function M:CreateSettings()
    local page = self.settingsPage
    local frame = KT:Window("ForeverToolsMacroSettings", "Macro settings", W, H); page.frame = frame
    KT:PageInfo(frame, "Macro settings", "Where macros go, mouseover, icons for unlearned spells, and clean-up.")
    local function hint(anchor, text)
        local l = KT:Label(frame, text, 12); l:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 2, -6); l:SetWidth(W - 52); l:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
        if l.SetWordWrap then l:SetWordWrap(true) end
        return l
    end
    self.scopeButton = KT:Dropdown(frame, W - 48, function() return self:ScopeChoices() end, function(value) self:ChooseScope(value) end, "character")
    self.scopeButton:SetHeight(32); self.scopeButton.menuWidth = 240; self.scopeButton:SetPoint("TOPLEFT", 24, -66)
    KT:Tooltip(self.scopeButton, "Save to", "Character: this character's tab. General: shared by all. Class and race macros go to Character.")
    hint(self.scopeButton, "Where generic and your own macros go.")
    self.bulkMouseoverButton = KT:QuietButton(frame, "", W - 48, 32, "mouseover"); self.bulkMouseoverButton:SetPoint("TOPLEFT", 24, -136)
    self.bulkMouseoverButton:SetScript("OnClick", function()
        self.bulkMouseover = not self.bulkMouseover; KT.db.macroBulkMouseover = self.bulkMouseover
        KT.db.macroMouseover = nil
        if self.selectedMacro then self.mouseover = self:EntryMouseover(self.selectedMacro); self:UpdatePreview() end
        self:UpdateBulkInfo(); self.counts = nil; KT:RefreshDock(frame)
    end)
    KT:Tooltip(self.bulkMouseoverButton, "Mouseover for all macros", "Cast on the unit under your mouse and keep your target. Melee strikes stay on your target. Also turn on Mouseover Cast in the game's settings.")
    hint(self.bulkMouseoverButton, "Act on the unit under your mouse, keeping your target.")
    self.iconsButton = KT:QuietButton(frame, "", W - 48, 32, "classes"); self.iconsButton:SetPoint("TOPLEFT", 24, -206)
    self.iconsButton:SetScript("OnClick", function() KT.db.macroUnlearnedIcons = not (KT.db.macroUnlearnedIcons == true); self:UpdateIconsButton(); KT:RefreshDock(frame) end)
    KT:Tooltip(self.iconsButton, "Icons for unlearned spells", "Unlearned spells get their icon, so you can set up bars from level 1.")
    hint(self.iconsButton, "Unlearned spells show their icon on your bars.")
    -- Rogue poisons: the game asks "Replace the poison already on this weapon?"
    -- when a weapon has one. With this on, the macro clicks Yes for you.
    self.poisonButton = KT:QuietButton(frame, "", W - 48, 32, "generic"); self.poisonButton:SetPoint("TOPLEFT", 24, -346)
    self.poisonButton.icon:SetTexture("Interface\\Icons\\Ability_Poisons")
    self.poisonButton:SetScript("OnClick", function()
        KT.db.macroPoisonConfirm = not (KT.db.macroPoisonConfirm == true); self:UpdatePoisonButton()
        -- Macros already added keep their text until you add them again.
        if self.selectedMacro and KT.modules.MacroForge.IsPoison(self.selectedMacro) then
            local record = KT:MacroRecord(self.selectedMacro); record.body = false; record.dirty = nil; self:UpdatePreview()
        end
        KT:RefreshDock(frame)
    end)
    KT:Tooltip(self.poisonButton, "Confirm replacing poisons", "Rogues: when a weapon already has a poison, the game asks if you want to replace it. On: the poison macros click Yes for you (they get the line /click StaticPopup1Button1). Off: you click Yes yourself. Poison macros you already added change when you add them again.")
    hint(self.poisonButton, "Rogue poison macros: click Yes on \"replace poison?\" for you.")
    -- New poisons, mana gems and weapons (MacroWatch.lua).
    self.updatesButton = KT:QuietButton(frame, "", W - 48, 32, "macros"); self.updatesButton:SetPoint("TOPLEFT", 24, -416)
    KT:MakeChoice(self.updatesButton, {
        {"ask", "Ask", "A question when a better poison or mana gem, or a new weapon, means your macros should change."},
        {"auto", "Automatically", "Your macros change by themselves (a short message says so)."},
        {"off", "Off", "Your macros are never changed for you."},
    }, function() return KT.MacroWatch and KT.MacroWatch:Mode() or "ask" end, function(value) KT.db.macroUpdates = value; if value ~= "auto" then KT.db.macroFamilyAuto = nil end; self:UpdateUpdatesButton() end)
    KT:Tooltip(self.updatesButton, "Update macros", "When a better poison or mana gem is in your bags, or you equip a new weapon your weapon swap macros don't use. Every macro counts, your own too. /ft weaponswap shows your weapon swaps any time.")
    hint(self.updatesButton, "New poisons, mana gems and weapons: ask first, change by themselves, or never.")
    self:UpdateUpdatesButton()
    self.deleteButton = KT:QuietButton(frame, "Delete Character macros...", W - 48, 32, "delete"); self.deleteButton:SetPoint("TOPLEFT", 24, -276)
    self.deleteButton.options = function()
        return {
            {value = "unchanged", label = "Delete unchanged macros", icon = "Interface\\Icons\\INV_Misc_Note_01",
                tooltip = "Delete Character macros ForeverTools made that you haven't changed."},
            {value = "all", label = "Delete ALL Character macros", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
                tooltip = "Delete every Character macro. General macros stay. Asks twice."},
        }
    end
    self.deleteButton.onSelect = function(mode) self:RequestDeleteClass(mode); C_Timer.After(0, function() self:Changed() end) end
    self.deleteButton.menuWidth = 280
    self.deleteButton:SetScript("OnClick", function(owner) KT:ShowChoices(owner) end)
    KT:Tooltip(self.deleteButton, "Delete Character macros", "Delete the unchanged ForeverTools macros, or every Character macro. Asks first.")
    hint(self.deleteButton, "Remove unchanged ForeverTools macros, or clear the Character tab.")
    frame:Hide()
end

-- Pages -------------------------------------------------------------------------------------
local function listPage(view)
    local page = {}
    function page:Open()
        M:CreateUI()
        local fresh = M.view ~= view
        M:SetView(view)
        page.frame = M.frame
        if fresh then
            M.search:SetText(""); M.expanded = false
            if M.listScroll and M.listScroll.SetVerticalScroll then M.listScroll:SetVerticalScroll(0) end
        end
        M.bulkMouseover = KT.db.macroBulkMouseover == true
        if M.selectedMacro then M.mouseover = M:EntryMouseover(M.selectedMacro) end
        M:RenderList()
        M:Status(view == "class" and "Click a macro to open it." or "")
        M.frame:Show()
    end
    function page:Refresh() M:RenderList() end
    return page
end
M.Open = listPage("class").Open
function M:Refresh() self:RenderList() end
for view, info in pairs(M.views) do
    if view ~= "class" then
        local page = listPage(view)
        KT:RegisterModule(info.page, page)
        info.module = page
    end
end
local settingsPage = {}
M.settingsPage = settingsPage
function settingsPage:Open()
    M:CreateUI()
    M:UpdateBulkInfo()
    self.frame:Show()
end
function settingsPage:Refresh() M:UpdateBulkInfo() end
KT:RegisterModule("MacroSettings", settingsPage)
-- Your macros changed (added, deleted, edited in the game's window).
local events = CreateFrame("Frame")
events:RegisterEvent("UPDATE_MACROS")
for _, event in ipairs({"PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if event ~= "UPDATE_MACROS" then
        if M.frame and M.frame:IsShown() then KT:Coalesce("macroIcons", function()
            M:RefreshIcons()
            -- An open Bandage or Eat & Drink shows the bags' new text (not while you type in it).
            local entry = M.selectedMacro
            if entry and followers[entry.name] and M.expanded and M.preview and not (M.preview.HasFocus and M.preview:HasFocus()) then M:UpdatePreview() end
        end, .6) end
        return
    end
    M.counts = nil
    if M.frame and M.frame:IsShown() and not InCombatLockdown() then KT:Coalesce("macroListChanged", function() M:RenderList(); KT:RefreshDock(M.frame) end, .2) end
end)
