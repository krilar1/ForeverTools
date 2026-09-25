local _, FT = ...
local Editor = { drafts = {}, target = "standard", modifier = "", stopcasting = false, startattack = false }
local Macros = FT.modules.MacroForge
local function normal(body) return (body or ""):gsub("\r\n", "\n"):gsub("\n+$", "") end
local function copy(source) local result = {}; for k, v in pairs(source) do result[k] = v end; return result end
function Editor:Key(entry) return FT:MacroKey(entry) end
function Editor:Record() return FT:MacroRecord(self.entry) end
function Editor:CharacterKey() return UnitGUID("player") or "player" end
function Editor:SaveVersion(kind, body)
    local record = self:Record()
    record.versions[#record.versions + 1] = {body = body or self.code:GetText(), time = time(), kind = kind}
    self.historyPage = 1
    self:RenderHistory()
end
function Editor:Message(text, failure)
    if Macros.status and (not self.frame or not self.frame:IsShown()) then Macros:Status(text, failure) end
    self.message:SetText(text)
    self.message:SetTextColor(failure and 1 or 0.78, failure and 0.45 or 0.68, failure and 0.45 or 1)
end
function Editor:Validate()
    local body = self.code:GetText()
    if not body:find("%S") then self:Message("The macro is empty.", true); return end
    if #body > 255 then self:Message("Over 255 bytes: shorten the macro before saving to WoW.", true); return end
    return body
end
function Editor:FindInstalled()
    local record = self:Record()
    local tracked = record.installed[self:CharacterKey()]
    local account, character = GetNumMacros()
    local scope = (self.entry.class or self.entry.characterOnly) and "character" or self.scope
    local first = scope == "character" and (MAX_ACCOUNT_MACROS or 120) + 1 or 1
    local count = scope == "character" and character or account
    local variants = {}
    local rank, mouseover = Macros.selectedRank, Macros.mouseover
    for i = 1, (self.entry.ranks or 1) + 1 do
        Macros.selectedRank = i > (self.entry.ranks or 1) and "max" or tostring(i)
        for _, enabled in ipairs({false, true}) do
            Macros.mouseover = enabled; variants[normal(Macros:BuildMacro(self.entry))] = true
        end
    end
    Macros.selectedRank, Macros.mouseover = rank, mouseover
    local trackedMatches, exactMatches, alternatives = {}, {}, {}
    for index = first, first + count - 1 do
        local name, _, body = GetMacroInfo(index)
        if body then
            local candidate = {index = index, name = name, body = body}
            if tracked and normal(body) == normal(tracked.body) then trackedMatches[#trackedMatches + 1] = candidate end
            if normal(body) == normal(self.sourceBody) then exactMatches[#exactMatches + 1] = candidate end
            if variants[normal(body)] or (not self.entry.class and not self.entry.characterOnly and name == Macros:MacroName(self.entry)) then alternatives[#alternatives + 1] = candidate end
        end
    end
    local matches = #trackedMatches > 0 and trackedMatches or (#exactMatches > 0 and exactMatches or alternatives)
    if #matches == 1 then return matches[1] end
    if #matches > 1 then return nil, "Several matching macros exist. Remove duplicates in Blizzard's Macro window before replacing." end
end
function Editor:SaveToWoW()
    if InCombatLockdown() then self:Message("Leave combat before saving to WoW.", true); return end
    local body = self:Validate(); if not body then return end
    local target, problem = self:FindInstalled()
    if problem then self:Message(problem, true); return end
    local request = {entry = copy(self.entry), body = body, scope = self.scope, target = target, key = self:Key(self.entry)}
    self.pendingSave = request
    if target then
        StaticPopupDialogs.FOREVERTOOLS_REPLACE.text = "Replace the existing " .. self.entry.name .. " macro with this edited version?\n\nThe current version will be recorded in your save log."
        FT:ShowPopup("FOREVERTOOLS_REPLACE")
    elseif self.entry.class and self.entry.class ~= Macros:PlayerClass() then
        StaticPopupDialogs.FOREVERTOOLS_EDITOR_FOREIGN.text = "This is a " .. self.entry.class .. " macro, but you are a " .. Macros:PlayerClass() .. ". Add it to Character macros anyway?"
        FT:ShowPopup("FOREVERTOOLS_EDITOR_FOREIGN")
    else self:CommitSave() end
end
function Editor:CommitSave()
    local request = self.pendingSave; self.pendingSave = nil
    if not request or self:Key(self.entry) ~= request.key then return end
    if InCombatLockdown() then self:Message("Save cancelled: you entered combat.", true); return end
    if request.target then
        local target = request.target
        local name, _, oldBody = GetMacroInfo(target.index)
        if name ~= target.name or normal(oldBody) ~= normal(target.body) then
            self:Message("The existing macro changed. Nothing was replaced; open it again and retry.", true); return
        end
        self:SaveVersion("Before replacement", oldBody)
        local index = EditMacro(target.index, Macros:MacroName(request.entry), 134400, request.body)
        if not index then self:Message("WoW could not replace the macro.", true); return end
    else
        local entry = copy(request.entry); entry.code = request.body
        local previousScope = Macros.scope; Macros.scope = request.scope
        local created = Macros:CreateEntry(entry, true); Macros.scope = previousScope
        if not created then self:Message(Macros.status and Macros.status:GetText() or "WoW could not add this macro.", true); return end
    end
    self:Record().installed[self:CharacterKey()] = {body = request.body}
    self.sourceBody = request.body
    self:SaveVersion(request.target and "Replaced in WoW" or "Added to WoW", request.body)
    self:Message(request.target and "Macro replaced. Both versions are in the save log." or "Macro added to WoW and saved in the log.")
    FT:Toast(request.target and "Updated macro" or ("Added to " .. (request.scope == "character" and "character" or "general") .. " macros"))
    Macros:UpdateBulkInfo()
end
function Editor:ConditionBlock(target)
    local friendly = self.entry.kind == "friendly"
    local kind = friendly and "help" or "harm"
    local branches
    if target == "self" then branches = {"@player"}
    elseif target == "mouseover" or target == "focus" then
        branches = {"@" .. target .. "," .. kind .. ",nodead", "@target," .. kind .. ",nodead"}
        if friendly then branches[#branches + 1] = "@player" end
    elseif friendly then branches = {"@target,help,nodead", "@player"}
    else branches = {""} end
    local result = ""
    for _, branch in ipairs(branches) do
        if self.modifier ~= "" then branch = "mod:" .. self.modifier .. (branch ~= "" and "," .. branch or "") end
        if branch ~= "" then result = result .. "[" .. branch .. "]" end
    end
    return result ~= "" and result .. " " or ""
end
function Editor:SyncBuilderFromBody()
    local body = "\n" .. self.code:GetText() .. "\n"
    self.stopcasting = body:find("\n/stopcasting\n", 1, true) ~= nil
    self.startattack = body:find("\n/startattack\n", 1, true) ~= nil
    local cast = body:match("\n/cast ([^\n]+)")
    if cast and not self.entry.code then
        self.target = cast:find("@mouseover",1,true) and "mouseover" or (cast:find("@focus",1,true) and "focus" or (cast:find("@player",1,true) and not cast:find("@target",1,true) and "self" or "standard"))
        self.modifier = cast:match("mod:(%a+)") or ""
        self.rank = cast:match("%(Rank (%d+)%)") or "max"
        local spell = cast:gsub("%b[]", ""):match("^%s*([^;]+)")
        if spell then self.spellName = spell:gsub("%(Rank %d+%)", ""):gsub("%s+$", "") end
    end
    self:RefreshControls()
end
function Editor:ApplyBuilder()
    local old = self.code:GetText()
    local spell = self.spellName or self.entry.name
    if not self.entry.code and spell == "" then self:Message("Enter a spell name first.", true); return end
    if self.rank ~= "max" and self.entry.ranks and self.entry.ranks > 1 then spell = spell .. "(Rank " .. self.rank .. ")" end
    local cast = "/cast " .. self:ConditionBlock(self.target) .. spell
    local lines, replaced, inserted = {}, false, false
    local function extras()
        if inserted then return end; inserted = true
        if self.stopcasting then lines[#lines + 1] = "/stopcasting" end
        if self.startattack then lines[#lines + 1] = "/startattack" end
    end
    for line in (old .. "\n"):gmatch("(.-)\n") do
        if line:match("^/cast%s") and not self.entry.code and not replaced then
            extras(); lines[#lines + 1] = cast; replaced = true
        elseif line == "/stopcasting" or line == "/startattack" then
            -- These two exact lines are controlled by their toggles.
        elseif line:match("^#showtooltip") and not self.entry.code then lines[#lines + 1] = "#showtooltip " .. spell
        else lines[#lines + 1] = line end
    end
    if not replaced and not self.entry.code then extras(); lines[#lines + 1] = cast end
    if self.entry.code then extras() end
    self.code:SetText(table.concat(lines, "\n"))
    self:RefreshControls()
    self:Message("Saved locally. Use Back to return to your macros.")
end
function Editor:EntryGroup() return self.entry.class or (self.entry.category == "racial" and "Racials" or "Generic") end
function Editor:EntriesForGroup(group)
    if group == "Generic" then return Macros:GenericEntries() end
    if group == "Racials" then return Macros:RaceEntries() end
    return Macros:BulkEntries(group)
end
function Editor:RefreshControls()
    local canTarget = Macros:CanMouseover(self.entry)
    for key, button in pairs(self.targetButtons) do
        button:SetEnabled(key == "standard" or (canTarget and (key ~= "self" or self.entry.kind == "friendly")))
        FT:SetSelected(button, self.target == key)
    end
    for key, button in pairs(self.modButtons) do
        button:SetEnabled(not self.entry.code); FT:SetSelected(button, self.modifier == key)
    end
    FT:SetSelected(self.stopButton, self.stopcasting); FT:SetSelected(self.attackButton, self.startattack)
    local hasRanks = not self.entry.code and self.entry.ranks and self.entry.ranks > 1
    self.rankDropdown:SetShown(hasRanks)
    self.rankDropdown:SetEnabled(hasRanks)
    self.spellDropdown:SetWidth(hasRanks and 238 or 392)
    self.rankDropdown.value = self.rank
    self.rankDropdown.label:SetText(self.entry.ranks and self.entry.ranks > 1 and (self.rank == "max" and "Max rank" or "Rank " .. self.rank) or "No ranks")
    self.classDropdown.value = self:EntryGroup()
    self.classDropdown.label:SetText(self:EntryGroup())
    self.spellDropdown.value = self.entry.name
    self.spellDropdown.label:SetText(self.spellName or self.entry.name)
    local group = self:EntryGroup()
    if group ~= "Generic" and group ~= "Racials" then self.classDropdown.icon:SetTexture(Macros:ClassIcon(group))
    else self.classDropdown.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01") end
    self.spellDropdown.icon:SetTexture(Macros:IconForEntry(self.entry))
end
function Editor:RenderHistory()
    local versions = self:Record().versions
    local pages = math.max(1, math.ceil(#versions / 6))
    self.historyPage = math.max(1, math.min(pages, self.historyPage or 1))
    self.historyTitle:SetText("Save log • " .. #versions .. " versions")
    self.pageLabel:SetText(self.historyPage .. " / " .. pages)
    for row, button in ipairs(self.historyButtons) do
        local index = #versions - (self.historyPage - 1) * 6 - row + 1
        local version = versions[index]
        button:SetShown(version ~= nil); button.version = version; button.historyIndex = index
        if version then
            button.label:SetText("v" .. index .. "  " .. date("%d %b %H:%M", version.time) .. "\n" .. version.kind)
            button.remove:SetShown(true)
        else
            button.remove:Hide()
        end
    end
end
function Editor:DeleteVersion(index)
    local versions = self:Record().versions
    if not index or not versions[index] then return end
    table.remove(versions, index)
    self:RenderHistory()
    self:Message("Revision removed from the save log.")
end
function Editor:CreateUI()
    if self.frame then return end
    local frame = FT:Window("ForeverToolsMacroEditor", "Advanced macro editor", 900, 580)
    self.frame = frame; frame:SetFrameStrata("FULLSCREEN_DIALOG")
    self.entryLabel = FT:Label(frame, "", 15, true); self.entryLabel:SetPoint("TOPLEFT", 24, -60)
    self.classDropdown = FT:Dropdown(frame, 150, function()
        local options = {}; for _, name in ipairs(Macros:ClassNames()) do options[#options + 1] = {value = name, label = name} end
        options[#options + 1] = {value = "Racials", label = "Racials"}; options[#options + 1] = {value = "Generic", label = "Generic"}; return options
    end, function(value)
        local entries = self:EntriesForGroup(value)
        self:ChooseEntry(entries[1])
    end, "classes")
    self.classDropdown:SetPoint("TOPLEFT", 24, -83)
    self.spellDropdown = FT:Dropdown(frame, 238, function()
        local entries = self:EntriesForGroup(self:EntryGroup())
        local options = {}; for _, entry in ipairs(entries) do options[#options + 1] = {value = entry.name, label = entry.name, icon = Macros:IconForEntry(entry)} end
        return options
    end, function(value)
        local entries = self:EntriesForGroup(self:EntryGroup())
        for _, entry in ipairs(entries) do if entry.name == value then self:ChooseEntry(entry); break end end
    end, "macros")
    self.spellDropdown:SetPoint("TOPLEFT", 184, -83)
    self.rankDropdown = FT:Dropdown(frame, 144, function()
        local options = {{value = "max", label = "Max rank"}}
        for rank = 1, (self.entry.ranks or 1) - 1 do options[#options + 1] = {value = tostring(rank), label = "Rank " .. rank} end
        return options
    end, function(value) self.rank = value; self:ApplyBuilder() end, "macros")
    self.rankDropdown:SetPoint("TOPLEFT", 432, -83)
    frame.homeButton.label:SetText("Back")
    frame.homeButton:SetScript("OnClick", function() self:GoBack() end)
    frame:HookScript("OnHide", function() FT:FlushMacroRevision(self.entry) end)
    self.targetButtons = {}
    for index, item in ipairs({{"standard","Target"}, {"mouseover","Mouseover"}, {"focus","Focus"}, {"self","Self"}}) do
        local key = item[1]; local button = FT:QuietButton(frame, item[2], 128, 28, "mouseover")
        button:SetPoint("TOPLEFT", 24 + (index - 1) * 138, -124)
        button:SetScript("OnClick", function() self.target = key; self:ApplyBuilder() end); self.targetButtons[key] = button
    end
    self.modButtons = {}
    for index, item in ipairs({{"","No modifier"}, {"shift","Shift"}, {"ctrl","Ctrl"}, {"alt","Alt"}}) do
        local key = item[1]; local button = FT:QuietButton(frame, item[2], 128, 28, "generic")
        button:SetPoint("TOPLEFT", 24 + (index - 1) * 138, -162)
        button:SetScript("OnClick", function() self.modifier = key; self:ApplyBuilder() end); self.modButtons[key] = button
    end
    self.stopButton = FT:QuietButton(frame, "Stop casting first", 264, 28, "delete"); self.stopButton:SetPoint("TOPLEFT", 24, -200)
    self.stopButton:SetScript("OnClick", function() self.stopcasting = not self.stopcasting; self:ApplyBuilder() end)
    self.attackButton = FT:QuietButton(frame, "Start attack", 278, 28, "add"); self.attackButton:SetPoint("TOPLEFT", 298, -200)
    self.attackButton:SetScript("OnClick", function() self.startattack = not self.startattack; self:ApplyBuilder() end)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -244); scroll:SetSize(528, 224)
    self.code = CreateFrame("EditBox", nil, scroll); self.code:SetMultiLine(true); self.code:SetAutoFocus(false)
    self.code:SetFont(FT.bodyFont, 15, ""); self.code:SetSize(520, 224); self.code:SetTextInsets(8,8,8,8); FT:Panel(self.code)
    scroll:SetScrollChild(self.code)
    self.caret = self.code:CreateTexture(nil, "OVERLAY"); self.caret:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.caret:SetSize(2, 18); self.caret:SetVertexColor(0.82, 0.62, 1, 1); self.caret:Hide()
    self.code:SetScript("OnCursorChanged", function(_, x, y, width, height)
        local top = -y; local offset = scroll:GetVerticalScroll()
        if top < offset then scroll:SetVerticalScroll(math.max(0, top))
        elseif top + height > offset + scroll:GetHeight() then scroll:SetVerticalScroll(top + height - scroll:GetHeight()) end
        self.caret:ClearAllPoints(); self.caret:SetPoint("TOPLEFT", self.code, "TOPLEFT", x + 8, y - 8)
        self.caret:SetHeight(math.max(16, height or 18))
    end)
    self.code:SetScript("OnTextChanged", function(box)
        self.count:SetText(#box:GetText() .. " / 255 bytes")
        local _, lines = box:GetText():gsub("\n", "")
        box:SetHeight(math.max(224, (lines + math.ceil(#box:GetText() / 60) + 1) * 18 + 16))
        if self.entry then
            if not self.loading then FT:StoreMacroBody(self.entry, box:GetText()) end
            self:SyncBuilderFromBody()
        end
    end)
    self.code:SetScript("OnEditFocusLost", function() FT:FlushMacroRevision(self.entry) end)
    self.code:HookScript("OnEditFocusGained", function()
        self.caret:Show(); self.caret.elapsed = 0
        self.code:SetScript("OnUpdate", function(_, elapsed)
            local caret=self.caret
            caret.elapsed = (caret.elapsed or 0) + elapsed
            caret:SetAlpha(0.35 + 0.65 * math.abs(math.sin(caret.elapsed * 4)))
        end)
    end)
    self.code:HookScript("OnEditFocusLost", function() self.caret:Hide(); self.code:SetScript("OnUpdate", nil) end)
    self.code:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.count = FT:Label(frame, "", 12); self.count:SetPoint("TOPLEFT", 24, -480)
    self.message = FT:Label(frame, "", 13); self.message:SetPoint("BOTTOMLEFT", 24, 24); self.message:SetWidth(850)
    self.historyTitle = FT:Label(frame, "", 16, true); self.historyTitle:SetPoint("TOPLEFT", 606, -60)
    self.historyButtons = {}
    for index = 1, 6 do
        local button = FT:QuietButton(frame, "", 270, 60)
        button:SetSize(270, 60)
        button:SetPoint("TOPLEFT", 606, -90 - (index - 1) * 66)
        FT:ButtonIcon(button, "macros", 20)
        button:SetScript("OnClick", function(owner) self.code:SetText(owner.version.body); self:Message("Version restored locally. Your installed macro was not changed.") end)
        button.remove = FT:QuietButton(button, "×", 20, 20)
        button.remove:SetPoint("TOPRIGHT", -3, -3)
        button.remove.label:SetTextColor(1, 0.35, 0.42)
        button.remove:SetScript("OnClick", function(owner) self:DeleteVersion(owner:GetParent().historyIndex) end)
        FT:Tooltip(button.remove, "Remove revision", "Delete this saved version from the history. Your macro in WoW does not change.")
        self.historyButtons[index] = button
    end
    local prev = FT:QuietButton(frame, "<", 32, 28); prev:SetPoint("TOPLEFT", 606, -500)
    prev:SetScript("OnClick", function() self.historyPage = self.historyPage - 1; self:RenderHistory() end)
    self.pageLabel = FT:Label(frame, "", 13); self.pageLabel:SetPoint("LEFT", prev, "RIGHT", 20, 0)
    local next = FT:QuietButton(frame, ">", 32, 28); next:SetPoint("TOPRIGHT", -24, -500)
    next:SetScript("OnClick", function() self.historyPage = self.historyPage + 1; self:RenderHistory() end)
    StaticPopupDialogs.FOREVERTOOLS_REPLACE = {text = "", button1 = "Replace macro", button2 = "Cancel", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() self:CommitSave() end, OnCancel = function() self.pendingSave = nil end}
    StaticPopupDialogs.FOREVERTOOLS_EDITOR_FOREIGN = {text = "", button1 = "Add anyway", button2 = "Cancel", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() self:CommitSave() end, OnCancel = function() self.pendingSave = nil end}
end
function Editor:ChooseEntry(entry)
    if not entry then return end
    FT:FlushMacroRevision(self.entry)
    local rank, mouseover = Macros.selectedRank, Macros.mouseover
    Macros.selectedRank, Macros.mouseover = "max", false
    local body = Macros:BuildMacro(entry)
    Macros.selectedRank, Macros.mouseover = rank, mouseover
    self:OpenEntry(entry, body)
end
function Editor:GoBack()
    FT:FlushMacroRevision(self.entry)
    local entry = self.entry
    self.frame:Hide()
    Macros:CreateUI()
    if entry.class then Macros.filter = "class"; Macros.browsedClass = entry.class
    else Macros.filter = entry.category == "generic" and "generic" or "mine" end
    Macros:Select(entry)
    FT:OpenModule("MacroForge")
end
function Editor:PrepareEntry(entry, body)
    FT:FlushMacroRevision(self.entry)
    self:CreateUI(); self.pendingSave = nil
    self.entry = copy(entry); self.sourceBody = body; self.templateBody = body
    self.scope = (entry.class or entry.characterOnly) and "character" or Macros.scope
    self.entryLabel:SetText(entry.name .. " • local draft; save a profile to keep this setup")
    self.rank = "max"; self.target = "standard"; self.modifier = ""; self.spellName = entry.name
    local installed, problem = self:FindInstalled()
    if installed then self.sourceBody = installed.body end
    self.loading = true
    self.code:SetText(FT:MacroBody(entry, self.sourceBody))
    self.loading = false
    self.historyPage = 1; self:RefreshControls(); self:RenderHistory()
    self:Message(problem or "Changes save locally as you type. Back returns to the normal macro view.", problem ~= nil)
end
function Editor:OpenEntry(entry, body)
    if not entry then return end
    self:PrepareEntry(entry, body)
    Macros.frame:Hide()
    self.frame:Show()
end
function Editor:InstallEntry(entry, body)
    if not entry then return end
    FT:FlushMacroRevision(entry)
    self:PrepareEntry(entry, body)
    self:SaveToWoW()
end
FT:RegisterModule("MacroEditor", Editor)
