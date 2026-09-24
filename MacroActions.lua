local _, FT = ...
local Macros = FT.modules.MacroForge
local function normalized(body)
    return type(body) == "string" and body:gsub("\r\n", "\n"):gsub("\n+$", "") or ""
end
local function signature(name, body) return (name or "") .. "\001" .. normalized(body) end

function Macros:ClassDeletionCandidates()
    -- Match full template text, not just spell names, to leave custom macros intact.
    local signatures = {}
    local previousRank, previousMouseover = self.selectedRank, self.mouseover
    for _, entry in ipairs(self:BulkEntries(self:PlayerClass())) do
        local names = { self:MacroName(entry), string.sub(entry.name, 1, 16), string.sub("KT " .. entry.name, 1, 16) }
        for rank = 1, (entry.ranks or 1) + 1 do
            self.selectedRank = rank > (entry.ranks or 1) and "max" or tostring(rank)
            for _, mouseover in ipairs({false, true}) do
                self.mouseover = mouseover
                local body = self:BuildMacro(entry)
                for _, name in ipairs(names) do signatures[signature(name, body)] = true end
            end
        end
    end
    self.selectedRank, self.mouseover = previousRank, previousMouseover
    local candidates = {}
    local _, count = GetNumMacros()
    local offset = MAX_ACCOUNT_MACROS or 120
    for index = offset + 1, offset + count do
        local name, _, body = GetMacroInfo(index)
        if name and signatures[signature(name, body)] then
            candidates[#candidates + 1] = {index = index, name = name, body = body}
        end
    end
    return candidates
end
function Macros:CancelDelete()
    self.deleteRequest = nil
end
function Macros:RequestDeleteClass()
    self:CancelDelete()
    StaticPopup_Hide("FOREVERTOOLS_DELETE_FIRST")
    StaticPopup_Hide("FOREVERTOOLS_DELETE_FINAL")
    if InCombatLockdown() then self:Status("Leave combat before deleting macros.", true); return end
    local candidates = self:ClassDeletionCandidates()
    if #candidates == 0 then
        self:Status("No unchanged class templates found in Character macros.", true)
        return
    end
    local entries = self:BulkEntries(self:PlayerClass())
    local className = entries[1] and entries[1].class or "class"
    self.deleteRequest = {stage = 1, candidates = candidates, className = className}
    StaticPopupDialogs.FOREVERTOOLS_DELETE_FIRST.text = "Delete character macros. Will not delete any general macros."
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
            "FINAL CONFIRMATION\n\nPermanently delete %d %s class macros?\nTheir action-bar buttons may stop working.\n\nClick Delete macros to proceed, or Cancel to keep them.", #request.candidates, request.className)
        request.stage = 3
        FT:ShowPopup("FOREVERTOOLS_DELETE_FINAL")
    end)
end
function Macros:DeleteConfirmedClass()
    local request = self.deleteRequest
    if not request or request.stage ~= 3 then return end
    self:CancelDelete()
    if InCombatLockdown() then self:Status("Deletion cancelled: you entered combat.", true); return end
    local deleted, skipped = 0, 0
    -- Delete descending indices so earlier removals cannot renumber later targets.
    for i = #request.candidates, 1, -1 do
        local target = request.candidates[i]
        local name, _, body = GetMacroInfo(target.index)
        if name == target.name and normalized(body) == normalized(target.body) then
            DeleteMacro(target.index)
            deleted = deleted + 1
        else
            skipped = skipped + 1
        end
    end
    self:UpdateBulkInfo()
    self:Status(string.format("Deleted %d class macros; skipped %d that changed after confirmation.", deleted, skipped), skipped > 0)
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

