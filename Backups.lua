local _,FT=...
-- Action bar layouts and backups.
--   * Action bars: which spell, item or macro sits in each action slot. Used by
--     profile export/import ("Action bars") and by backups.
--   * Backups: a copy of your keybinds, action bars and spell binds, taken
--     automatically before an import changes them and whenever you ask. Any
--     backup can be put back later (Keybinds > Backups). The last 10 are kept
--     on this computer; they're also part of an export with keybinds.
-- Nothing here runs in combat: action bars and keys only change outside it.
local Backups={}
local MAX=10
local SLOTS=180
local function readable(v) return (not issecretvalue or not issecretvalue(v)) and v~=nil end
local function playerClass() local _,class=UnitClass("player"); return type(class)=="string" and class or nil end
local function copy(v) if type(v)~="table" then return v end local t={} for k,x in pairs(v) do t[k]=copy(x) end return t end

-- Capture: slot -> {k="spell",id=} / {k="item",id=} / {k="macro",name=,icon=,body=}.
function Backups:CaptureBars()
    if type(GetActionInfo)~="function" then return end
    local slots,count={},0
    for slot=1,SLOTS do
        local ok,kind,id,subType=pcall(GetActionInfo,slot)
        if ok and readable(kind) and readable(id) then
            if kind=="spell" and type(id)=="number" then slots[slot]={k="spell",id=id}
            elseif kind=="item" and type(id)=="number" then slots[slot]={k="item",id=id}
            elseif kind=="macro" and GetMacroInfo then
                -- The button's own label names the macro; its index can point elsewhere.
                local label=GetActionText and GetActionText(slot)
                local index=(type(label)=="string" and GetMacroIndexByName and GetMacroIndexByName(label)) or (subType~="spell" and id) or nil
                local name,icon,body=nil,nil,nil
                if type(index)=="number" and index>0 then name,icon,body=GetMacroInfo(index) end
                if type(name)=="string" and type(body)=="string" then slots[slot]={k="macro",name=name,icon=(type(icon)=="number" or type(icon)=="string") and icon or 134400,body=body} end
            elseif kind then
                -- Mounts, pets, flyouts, equipment sets…: left as they are on import.
                slots[slot]={k="keep"}
            end
            if slots[slot] then count=count+1 end
        end
    end
    return {class=playerClass(),slots=slots,count=count}
end
-- Only well-formed entries survive (import safety).
function Backups:ValidBars(bars)
    if type(bars)~="table" or type(bars.slots)~="table" then return nil end
    local clean={class=type(bars.class)=="string" and bars.class or nil,slots={}}
    local n=0
    for slot,e in pairs(bars.slots) do
        if type(slot)=="number" and slot>=1 and slot<=SLOTS and slot%1==0 and type(e)=="table" then
            if e.k=="keep" then clean.slots[slot]={k="keep"}
            elseif (e.k=="spell" or e.k=="item") and type(e.id)=="number" and e.id>0 and e.id<10000000 then clean.slots[slot]={k=e.k,id=e.id}; n=n+1
            elseif e.k=="macro" and type(e.name)=="string" and #e.name<=64 and type(e.body)=="string" and #e.body<=1024 then
                clean.slots[slot]={k="macro",name=e.name,body=e.body,icon=(type(e.icon)=="number" or type(e.icon)=="string") and e.icon or 134400}; n=n+1
            end
        end
    end
    return n>0 and clean or nil
end
local function knowsSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0) end
    if IsPlayerSpell then return IsPlayerSpell(id) end
    return IsSpellKnown and IsSpellKnown(id) or false
end
local function spellName(id) local n=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id); return readable(n) and n or ("spell "..id) end
-- Put a layout on the bars: the same slots as saved, empty slots cleared.
-- Anything this character can't place (a spell not learned yet, an item not
-- in the bags) is skipped and listed.
function Backups:ApplyBars(bars)
    if InCombatLockdown() then FT:Toast("Action bars can only change outside combat."); return end
    if type(bars)~="table" or type(bars.slots)~="table" or type(PlaceAction)~="function" then return end
    local placed,skipped=0,{}
    local profiles=FT.modules.Profiles
    for slot=1,SLOTS do
        local e=bars.slots[slot]
        ClearCursor()
        if e and e.k=="keep" then
            -- Something we don't carry (a mount, a flyout…): untouched.
        elseif not e then
            if GetActionInfo(slot) and PickupAction then PickupAction(slot); ClearCursor() end
        else
            local ok=false
            if e.k=="spell" then
                if knowsSpell(e.id) and C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(e.id); ok=GetCursorInfo()~=nil end
                if not ok then skipped[#skipped+1]=spellName(e.id) end
            elseif e.k=="item" then
                if C_Item and C_Item.PickupItem then C_Item.PickupItem(e.id); ok=GetCursorInfo()~=nil end
                if not ok then skipped[#skipped+1]=(C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.id)) or ("item "..e.id) end
            elseif e.k=="macro" and profiles and PickupMacro then
                local index=profiles:FindMacro(e)
                if not index and CreateMacro then pcall(CreateMacro,e.name,e.icon or 134400,e.body,true); index=profiles:FindMacro(e) end
                if index then PickupMacro(index); ok=GetCursorInfo()~=nil end
                if not ok then skipped[#skipped+1]=e.name end
            end
            if ok then PlaceAction(slot); placed=placed+1 end
            ClearCursor()
        end
    end
    return placed,skipped
end

-- Spell binds for this character, cleaned for storing or importing.
function Backups:CaptureSpellBinds()
    local binds=FT.modules.SpellBinds; if not binds then return end
    local s=binds:Settings()
    return {enabled=s.enabled,bar=s.bar,roles=copy(s.roles),slots=copy(s.slots)}
end
local function validEntry(e)
    if type(e)~="table" then return nil end
    local key=type(e.key)=="string" and #e.key<=40 and e.key or nil
    local off=e.off==true or nil
    if (e.kind=="spell" or e.kind=="item") and type(e.id)=="number" and e.id>0 then return {kind=e.kind,id=e.id,key=key,off=off} end
    if e.kind=="macro" and type(e.name)=="string" and #e.name<=64 then return {kind="macro",name=e.name,key=key,off=off} end
end
function Backups:ValidSpellBinds(data)
    if type(data)~="table" then return nil end
    local binds=FT.modules.SpellBinds; if not binds then return nil end
    local clean={enabled=data.enabled==true,bar=data.bar==true,roles={},slots={}}
    for _,role in ipairs(binds.roles) do
        local r=type(data.roles)=="table" and data.roles[role.key]
        clean.roles[role.key]={}
        if type(r)=="table" then
            clean.roles[role.key].key=type(r.key)=="string" and #r.key<=40 and r.key or nil
            clean.roles[role.key].off=r.off==true or nil
            local sp=validEntry(r.spell); if sp and sp.kind=="spell" then sp.key=nil; clean.roles[role.key].spell=sp end
        end
    end
    for i=1,20 do clean.slots[i]=validEntry(type(data.slots)=="table" and data.slots[i]) end
    return clean
end
function Backups:ApplySpellBinds(data)
    local binds=FT.modules.SpellBinds; if not binds or type(data)~="table" then return end
    local s=binds:Settings()
    s.enabled=data.enabled==true; s.bar=data.bar==true; s.roles=copy(data.roles); s.slots=copy(data.slots)
    binds:Apply()
end

-- Backups
function Backups:List()
    if type(FT.db.setupBackups)~="table" then FT.db.setupBackups={} end
    return FT.db.setupBackups
end
function Backups:Take(label,quiet)
    if InCombatLockdown() then return end
    local profiles=FT.modules.Profiles
    local entry={time=time(),label=label or "Backup",character=profiles and profiles:CharacterName() or nil,class=playerClass(),
        bindings=profiles and profiles:CaptureBindings() or nil,bars=self:CaptureBars(),spellBinds=self:CaptureSpellBinds()}
    local list=self:List()
    table.insert(list,1,entry)
    while #list>MAX do table.remove(list) end
    if not quiet then FT:Toast("Backup saved: keybinds, action bars and spell binds.",3) end
    return entry
end
-- Put a backup back. Action bars only on the same class (spells differ).
function Backups:Restore(index)
    local entry=self:List()[index]
    if not entry or InCombatLockdown() then if InCombatLockdown() then FT:Toast("Restore outside combat.") end; return end
    local sameClass=entry.class==playerClass()
    FT:Confirm("Put back the backup from "..date("%d %b %H:%M",entry.time).." ("..(entry.label or "Backup")..")?\n\nKeybinds"..(sameClass and ", action bars" or "").." and spell binds are replaced. Your current setup is backed up first, so this can be undone."..(sameClass and "" or "\n\nThis backup is from another class, so action bars are left as they are."),function()
        self:Take("Before restore",true)
        local profiles=FT.modules.Profiles
        if entry.bindings and profiles then profiles:ApplyBindings(entry.bindings,false,true) end
        local placed,skipped
        if sameClass and entry.bars then placed,skipped=self:ApplyBars(entry.bars) end
        if sameClass and entry.spellBinds then self:ApplySpellBinds(entry.spellBinds) end
        FT:Toast("Backup restored."..(skipped and #skipped>0 and (" "..#skipped.." action bar slot(s) skipped: not learned or not in your bags.") or ""),5)
    end)
end
-- One list for putting things back: your backups (keybinds, action bars and
-- spell binds) and your last keybind sessions (keybinds only), newest first.
function Backups:Count()
    local quick=FT.modules.QuickBind
    return #self:List()+(quick and #quick:History() or 0)
end
function Backups:Choices()
    local list={{value="new",label="Save a backup now",icon="Interface\\Icons\\INV_Misc_Book_09",tooltipTitle="Save a backup now",
        tooltip="A copy of your keybinds, action bars and spell binds that you can put back later."}}
    local entries={}
    for i,entry in ipairs(self:List()) do
        local bars=entry.bars and entry.bars.count or 0
        entries[#entries+1]={time=entry.time or 0,value="b"..i,label=date("%d %b %H:%M",entry.time).." · "..(entry.label or "Backup")..(entry.character and (" · "..entry.character:match("^[^%-]+")) or ""),
            icon="Interface\\Icons\\INV_Misc_Book_09",tooltipTitle=(entry.label or "Backup").." (full backup)",
            tooltip=(entry.character or "").."\n"..bars.." action bar slots, "..(entry.bindings and "keybinds" or "no keybinds")..(entry.spellBinds and ", spell binds" or "").."\n\nChoose to put it back (your current setup is backed up first)."}
    end
    local quick=FT.modules.QuickBind
    if quick then
        for i,entry in ipairs(quick:History()) do
            local n=#quick:ChangeLines(entry.changes)
            entries[#entries+1]={time=entry.time or 0,value="k"..i,label=date("%d %b %H:%M",entry.time).." · Before "..(entry.label or "keybind session"):lower().." · "..n.." change"..(n==1 and "" or "s"),
                icon="Interface\\Icons\\"..FT.icons.keybind,tooltipTitle="Before "..(entry.label or "keybind session"):lower().." (keybinds only)",
                tooltip=function() return "This session changed:\n"..quick:ChangeText(entry.changes).."\n\nChoose to put back the keybinds you had before it. Action bars and spell binds stay as they are." end}
        end
    end
    table.sort(entries,function(a,b) return a.time>b.time end)
    for _,e in ipairs(entries) do e.time=nil; list[#list+1]=e end
    return list
end
function Backups:Show(owner)
    owner.options=function() return self:Choices() end
    owner.onSelect=function(value)
        if value=="new" then self:Take("Saved by you")
        elseif type(value)=="string" and value:sub(1,1)=="b" then self:Restore(tonumber(value:sub(2)))
        elseif type(value)=="string" and value:sub(1,1)=="k" and FT.modules.QuickBind then FT.modules.QuickBind:Restore(tonumber(value:sub(2))) end
        if FT.modules.System then FT.modules.System:Refresh() end
    end
    owner.menuWidth=400
    FT:ShowChoices(owner)
end
FT:RegisterModule("Backups",Backups)
