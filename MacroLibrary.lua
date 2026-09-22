local _, FT = ...
function FT:MacroKey(entry) return (entry.class or entry.race or "Generic") .. ":" .. entry.name end
function FT:MacroRecord(entry)
    if type(self.db.macroHistory) ~= "table" then self.db.macroHistory = {} end
    local key = self:MacroKey(entry)
    if type(self.db.macroHistory[key]) ~= "table" then self.db.macroHistory[key] = {} end
    local record = self.db.macroHistory[key]
    if type(record.versions) ~= "table" then record.versions = {} end
    if type(record.installed) ~= "table" then record.installed = {} end
    if record.body == nil and #record.versions > 0 then record.body = record.versions[#record.versions].body end
    return record
end
function FT:MacroBody(entry, fallback)
    local record = self:MacroRecord(entry)
    return type(record.body) == "string" and record.body or fallback
end
function FT:FlushMacroRevision(entry)
    if not entry then return end
    local record = self:MacroRecord(entry)
    if not record.dirty then return end
    record.dirty = nil
    local last = record.versions[#record.versions]
    if not last or last.body ~= record.body then
        record.versions[#record.versions + 1] = {body = record.body, time = time(), kind = "Edited locally"}
    end
    local editor = self.modules.MacroEditor
    if editor and editor.frame and editor.entry and self:MacroKey(editor.entry) == self:MacroKey(entry) then editor:RenderHistory() end
end
function FT:StoreMacroBody(entry, body)
    local record = self:MacroRecord(entry)
    if record.body == body then return end
    record.body = body; record.dirty = true
    -- Coalesce typing into one history entry; the latest text is saved immediately.
    self.macroSaveTokens = self.macroSaveTokens or {}
    local key = self:MacroKey(entry)
    local token = {}; self.macroSaveTokens[key] = token
    C_Timer.After(1, function()
        if FT.macroSaveTokens[key] == token then FT:FlushMacroRevision(entry); FT.macroSaveTokens[key] = nil end
    end)
end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function()
    for _, record in pairs(FT.db.macroHistory or {}) do
        if record.dirty and type(record.body) == "string" then
            record.versions = record.versions or {}
            local last = record.versions[#record.versions]
            if not last or last.body ~= record.body then record.versions[#record.versions + 1] = {body = record.body, time = time(), kind = "Edited locally"} end
            record.dirty = nil
        end
    end
end)
