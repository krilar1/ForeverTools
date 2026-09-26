local _, FT = ...
local Macros = FT.modules.MacroForge
local function normalized(body)
    return type(body) == "string" and body:gsub("\r\n", "\n"):gsub("\n+$", "") or ""
end
local function signature(name, body) return (name or "") .. "\001" .. normalized(body) end

-- Every macro text ForeverTools can create for this character: class
-- templates (excluded ones too), spellbook extras including the General line
-- (Attack, racials), racial and generic macros, at every rank, with and
-- without mouseover. A Character macro whose text still matches one of these
-- has not been changed by the player, whatever its name.
function Macros:TemplateBodies()
    local bodies = {}
    local entries = self:BulkEntries(self:PlayerClass())
    self:AddLearnedEntries(entries, self:PlayerClass(), true)
    for _, entry in ipairs(self:RaceEntries()) do entries[#entries + 1] = entry end
    for _, entry in ipairs(self:GenericEntries()) do entries[#entries + 1] = entry end
    local previousRank, previousMouseover = self.selectedRank, self.mouseover
    for _, entry in ipairs(entries) do
        for rank = 1, (entry.ranks or 1) + 1 do
            self.selectedRank = rank > (entry.ranks or 1) and "max" or tostring(rank)
            for _, mouseover in ipairs({false, true}) do
                self.mouseover = mouseover
                local ok, body = pcall(self.BuildMacro, self, entry)
                if ok and body then
                    bodies[normalized(body)] = true
                    for _, old in ipairs(self:LegacyBodies(entry, body)) do bodies[normalized(old)] = true end
                end
            end
        end
    end
    self.selectedRank, self.mouseover = previousRank, previousMouseover
    return bodies
end
-- mode "unchanged": only macros that still match a ForeverTools template.
-- mode "all": every Character macro.
function Macros:DeletionCandidates(mode)
    local bodies = mode == "unchanged" and self:TemplateBodies() or nil
    local candidates = {}
    local _, count = GetNumMacros()
    local offset = MAX_ACCOUNT_MACROS or 120
    for index = offset + 1, offset + count do
        local name, _, body = GetMacroInfo(index)
        if name and (mode == "all" or bodies[normalized(body)]) then
            candidates[#candidates + 1] = {index = index, name = name, body = body}
        end
    end
    return candidates
end
function Macros:CancelDelete()
    self.deleteRequest = nil
end
function Macros:RequestDeleteClass(mode)
    self:CancelDelete()
    StaticPopup_Hide("FOREVERTOOLS_DELETE_FIRST")
    StaticPopup_Hide("FOREVERTOOLS_DELETE_FINAL")
    mode = mode == "all" and "all" or "unchanged"
    if InCombatLockdown() then self:Status("Leave combat before deleting macros.", true); return end
    local candidates = self:DeletionCandidates(mode)
    if #candidates == 0 then
        self:Status(mode == "all" and "You have no Character macros." or "No unchanged ForeverTools macros found in Character macros.", true)
        return
    end
    self.deleteRequest = {stage = 1, candidates = candidates, mode = mode}
    StaticPopupDialogs.FOREVERTOOLS_DELETE_FIRST.text = mode == "all"
        and string.format("Delete ALL %d Character macros, including ones you made or changed yourself?\n\nGeneral macros are not touched.", #candidates)
        or string.format("Delete %d Character macros that ForeverTools made and you have not changed?\n\nMacros you changed and General macros are kept.", #candidates)
    FT:ShowPopup("FOREVERTOOLS_DELETE_FIRST")
end
function Macros:ShowFinalDelete()
    local request = self.deleteRequest
    if not request or request.stage ~= 1 then return end
    if InCombatLockdown() then self:CancelDelete(); self:Status("Deletion cancelled: you entered combat.", true); return end
    request.stage = 2
    -- Wait until Blizzard has dismissed the first popup before opening the second.
    C_Timer.After(0, function()
        if self.deleteRequest ~= request or request.stage ~= 2 then return end
        if InCombatLockdown() then self:CancelDelete(); self:Status("Deletion cancelled: you entered combat.", true); return end
        StaticPopupDialogs.FOREVERTOOLS_DELETE_FINAL.text = string.format(
            "FINAL CONFIRMATION\n\nPermanently delete %d Character macros%s?\nTheir action-bar buttons will stop working.\n\nClick Delete macros to proceed, or Cancel to keep them.", #request.candidates, request.mode == "all" and " (all of them)" or "")
        request.stage = 3
        FT:ShowPopup("FOREVERTOOLS_DELETE_FINAL")
    end)
end
-- WoW re-sorts the macro tab after every deletion, so saved slot numbers
-- go stale. Look the macros up again before each delete instead, matching
-- on name and text; each listed macro is deleted once. Returns the count.
function Macros:DeleteMatching(candidates)
    local wanted = {}
    for _, target in ipairs(candidates) do
        local key = signature(target.name, target.body)
        wanted[key] = (wanted[key] or 0) + 1
    end
    local offset = MAX_ACCOUNT_MACROS or 120
    local deleted = 0
    for _ = 1, #candidates do
        local _, count = GetNumMacros()
        local found
        for index = offset + count, offset + 1, -1 do
            local name, _, body = GetMacroInfo(index)
            local key = name and signature(name, body)
            if key and (wanted[key] or 0) > 0 then found = index; wanted[key] = wanted[key] - 1; break end
        end
        if not found then break end
        DeleteMacro(found)
        deleted = deleted + 1
    end
    return deleted
end
function Macros:DeleteConfirmedClass()
    local request = self.deleteRequest
    if not request or request.stage ~= 3 then return end
    self:CancelDelete()
    if InCombatLockdown() then self:Status("Deletion cancelled: you entered combat.", true); return end
    local deleted = self:DeleteMatching(request.candidates)
    local skipped = #request.candidates - deleted
    self:UpdateBulkInfo()
    self:Status(skipped > 0 and string.format("Deleted %d Character macros; kept %d that changed after you confirmed.", deleted, skipped) or string.format("Deleted %d Character macros.", deleted), skipped > 0)
end
function Macros:SetupDeleteDialogs()
    StaticPopupDialogs.FOREVERTOOLS_DELETE_FIRST = {
        text = "", button1 = "Delete macros", button2 = "Cancel", timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function() self:ShowFinalDelete() end,
        OnCancel = function() self:CancelDelete() end,
    }
    StaticPopupDialogs.FOREVERTOOLS_DELETE_FINAL = {
        text = "", button1 = "Delete macros", button2 = "Cancel", timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3,
        OnAccept = function() self:DeleteConfirmedClass() end,
        OnCancel = function() self:CancelDelete() end,
    }
end

