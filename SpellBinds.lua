local _,FT=...
-- Spell binds (Keybinds, off by default): bind spells, items and macros
-- straight to keys, without putting them on an action bar.
--   * Role keys: Interrupt, Taunt, Dispel, Defensive, Heal and Movement. Each
--     picks your class's spell for that job (the first one you know from a
--     short list), or one you drag onto it. Set the key once; on another
--     character the same key does the same job.
--   * Your binds: free slots for any spell, item or macro.
-- Everything uses the game's own "override" bindings: they sit on top of your
-- normal key bindings while this is on and never change them. Keys you don't
-- use here keep working exactly as before; a key used here does the spell
-- bind, and gets its old action back when you clear it or turn this off.
-- Bindings can only change out of combat, so changes made in combat wait.
local Binds={}
local SLOTS=20
local ROLES={
    {key="interrupt",label="Interrupt",icon="Ability_Kick",spells={"Kick","Pummel","Shield Bash","Earth Shock","Wind Shear","Counterspell","Silence","Rebuke","Mind Freeze","Skull Bash","Spell Lock"}},
    {key="taunt",label="Taunt",icon="Spell_Nature_Reincarnation",spells={"Taunt","Growl","Hand of Reckoning","Righteous Defense","Dark Command","Mocking Blow"}},
    {key="dispel",label="Dispel",icon="Spell_Holy_DispelMagic",spells={"Cleanse","Purify","Dispel Magic","Remove Curse","Remove Lesser Curse","Abolish Poison","Cure Poison","Abolish Disease","Cure Disease","Cleanse Spirit","Remove Corruption","Devour Magic"}},
    {key="defensive",label="Defensive",icon="Ability_Warrior_ShieldWall",spells={"Evasion","Shield Wall","Last Stand","Divine Shield","Divine Protection","Ice Block","Barkskin","Power Word: Shield","Deterrence","Shamanistic Rage","Unending Resolve"}},
    {key="heal",label="Heal",icon="Spell_Holy_FlashHeal",spells={"Flash of Light","Holy Light","Lesser Healing Wave","Healing Wave","Flash Heal","Lesser Heal","Heal","Regrowth","Healing Touch","Mend Pet","Health Funnel"}},
    {key="movement",label="Movement",icon="Ability_Rogue_Sprint",spells={"Sprint","Blink","Dash","Aspect of the Cheetah","Ghost Wolf","Travel Form","Charge","Intercept","Divine Steed"}},
    {key="cc",label="Crowd control",icon="Spell_Nature_Polymorph",spells={"Polymorph","Sap","Hibernate","Freezing Trap","Shackle Undead","Banish","Fear","Hex","Repentance","Seduction","Hammer of Justice","Blind","Gouge","Entangling Roots","Scare Beast","Turn Undead","Turn Evil","Wyvern Sting","Scatter Shot","Psychic Scream","Intimidating Shout","Howl of Terror","Death Coil","Frost Nova","Bash","Concussion Blow","Kidney Shot","Cheap Shot","Mind Control","Cyclone"}},
    {key="burst",label="Burst",icon="Spell_Nature_Bloodlust",spells={"Recklessness","Death Wish","Arcane Power","Combustion","Icy Veins","Presence of Mind","Avenging Wrath","Adrenaline Rush","Cold Blood","Blade Flurry","Bestial Wrath","Rapid Fire","Power Infusion","Inner Focus","Elemental Mastery","Nature's Swiftness","Bloodlust","Heroism","Berserk","Tiger's Fury","Amplify Curse"}},
    {key="slow",label="Slow",icon="Spell_Frost_FrostShock",spells={"Hamstring","Piercing Howl","Wing Clip","Concussive Shot","Frost Shock","Earthbind Totem","Cone of Cold","Curse of Exhaustion"}},
}
Binds.roles=ROLES
local function readable(v) return (not issecretvalue or not issecretvalue(v)) and v~=nil end
local function keyText(key) return key and (GetBindingText and GetBindingText(key) or key) or nil end
-- The short form the game's own action bars use (c-R, s-4, a-F, M4…),
-- worked out once per key.
local shortKeys={}
local function shortKey(key)
    if not key then return nil end
    local text=shortKeys[key]
    if not text then
        local ok,t=pcall(GetBindingText,key,true)
        text=(ok and type(t)=="string" and t~="") and t or key
        text=text:gsub("Ctrl%-","c-"):gsub("Shift%-","s-"):gsub("Alt%-","a-")
        shortKeys[key]=text
    end
    return text
end
Binds.shortKey=shortKey
local function guid() local g=UnitGUID and UnitGUID("player"); return readable(g) and g or nil end

-- Saved per character (spells differ per class); the role keys you use last
-- are also kept as a template for new characters.
function Binds:Root()
    if type(FT.db.spellBinds)~="table" then FT.db.spellBinds={} end
    local r=FT.db.spellBinds
    if type(r.chars)~="table" then r.chars={} end
    if type(r.template)~="table" then r.template={} end
    if type(r.ask)~="boolean" then r.ask=true end
    return r
end
function Binds:Settings()
    local r=self:Root(); local id=guid() or "unknown"
    local s=r.chars[id]
    if type(s)~="table" then s={}; r.chars[id]=s end
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.bar)~="boolean" then s.bar=false end
    if type(s.roles)~="table" then s.roles={} end
    if type(s.slots)~="table" then s.slots={} end
    for _,role in ipairs(ROLES) do if type(s.roles[role.key])~="table" then s.roles[role.key]={} end end
    return s
end

-- What a slot or role holds: a spell (by ID), an item (by ID) or a macro (by name).
local function describe(entry)
    if type(entry)~="table" then return end
    if entry.kind=="spell" and type(entry.id)=="number" then
        local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(entry.id)
        local icon=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(entry.id)
        if readable(name) then return name,icon end
    elseif entry.kind=="item" and type(entry.id)=="number" then
        local name=C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
        local icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
        return name or ("item:"..entry.id),icon
    elseif entry.kind=="macro" and type(entry.name)=="string" then
        local name,icon=GetMacroInfo and GetMacroInfo(entry.name)
        if name then return name,icon end
    end
end
-- Every spell from a role's list that you know, in list order (one per name).
function Binds:RoleOptions(role)
    local known={}
    local book=FT.modules.CustomKeybinds
    local ok,spells=pcall(book.LearnedSpells,book)
    if ok and type(spells)=="table" then for _,sp in ipairs(spells) do if type(sp.name)=="string" then known[sp.name:lower()]=sp end end end
    local list={}
    for _,name in ipairs(role.spells) do
        local sp=known[name:lower()]
        if sp then list[#list+1]=sp end
    end
    return list
end
-- A role's spell: the one you picked (or dragged onto it), or the first known spell from its list.
function Binds:RoleSpell(role)
    local s=self:Settings(); local chosen=s.roles[role.key].spell
    if type(chosen)=="table" then local name,icon=describe(chosen); if name then return chosen,name,icon end end
    local sp=self:RoleOptions(role)[1]
    if sp then return {kind="spell",id=sp.value},sp.name,sp.icon end
end
-- Click a role's icon: pick which of your spells it uses.
function Binds:PickRoleSpell(role,owner)
    local s=self:Settings(); local chosen=s.roles[role.key].spell
    owner.options=function()
        local options=self:RoleOptions(role)
        local auto=options[1]
        local list={{value=0,label="Automatic"..(auto and (" ("..auto.name..")") or ""),icon=auto and auto.icon or ("Interface\\Icons\\"..role.icon),
            tooltipTitle="Automatic",tooltip="The first spell you know from this role's list. It changes by itself when you learn a better fit."}}
        for _,sp in ipairs(options) do list[#list+1]={value=sp.value,label=sp.name,icon=sp.icon,tooltipTitle=sp.name,tooltip="Use "..sp.name.." for "..role.label:lower().."."} end
        if type(chosen)=="table" then
            local listed=false; for _,sp in ipairs(options) do if sp.value==chosen.id then listed=true end end
            local name,icon=describe(chosen)
            if name and not listed then list[#list+1]={value=chosen.id,label=name,icon=icon,tooltipTitle=name,tooltip="Dragged here by you."} end
        end
        if #options==0 then list[1].tooltip="You don't know a "..role.label:lower().." spell yet. Drag any spell onto the icon to use it here." end
        return list
    end
    owner.value=type(chosen)=="table" and chosen.id or 0
    owner.menuWidth=260
    owner.onSelect=function(value)
        if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
        s.roles[role.key].spell=value~=0 and {kind="spell",id=value} or nil; self:Apply()
    end
    FT:ShowChoices(owner)
end

-- Override bindings on our own owner frame: cleared and set again as a whole.
local owner=CreateFrame("Frame","ForeverToolsSpellBinds",UIParent)
local function bind(key,entry)
    if not key or type(entry)~="table" then return end
    if entry.kind=="spell" then
        local name=describe(entry); if name then SetOverrideBindingSpell(owner,false,key,name) end
    elseif entry.kind=="item" then SetOverrideBindingItem(owner,false,key,"item:"..entry.id)
    elseif entry.kind=="macro" then SetOverrideBindingMacro(owner,false,key,entry.name) end
end
function Binds:Apply()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.pending=true; return end
    self.pending=nil
    ClearOverrideBindings(owner)
    local s=self:Settings()
    if s.enabled then
        for _,role in ipairs(ROLES) do
            local r=s.roles[role.key]
            if r.key and not r.off then local entry=self:RoleSpell(role); bind(r.key,entry) end
        end
        for i=1,SLOTS do local slot=s.slots[i]; if type(slot)=="table" and slot.key and not slot.off then bind(slot.key,slot) end end
    end
    self:UpdateBar()
    self:Refresh()
end
-- One key does one thing here: giving it to a slot takes it from any other.
function Binds:SetKey(target,key)
    local s=self:Settings()
    if key then
        for _,role in ipairs(ROLES) do if s.roles[role.key].key==key then s.roles[role.key].key=nil end end
        for i=1,SLOTS do local slot=s.slots[i]; if type(slot)=="table" and slot.key==key then slot.key=nil end end
    end
    target.key=key
    if key then target.off=nil end -- a new key is meant to work
    -- Remember role keys for new characters.
    local r=self:Root(); r.template={}
    for _,role in ipairs(ROLES) do r.template[role.key]=s.roles[role.key].key end
    self:Apply()
end
function Binds:Propose(target,key,what)
    local current=GetBindingAction and GetBindingAction(key)
    if current and current~="" then
        local name=GetBindingName and GetBindingName(current) or current
        FT:Confirm('Put "'..what..'" on '..keyText(key)..'?\n\n'..keyText(key)..' does '..name..' now. It does '..what..' instead while spell binds are on; clearing it here gives it back.',function() self:SetKey(target,key) end)
    else self:SetKey(target,key) end
end

-- Take whatever is on the cursor: a spell, an item or a macro.
local function fromCursor()
    if not GetCursorInfo then return end
    local kind,a,b,c=GetCursorInfo()
    if kind=="spell" then
        local id=type(c)=="number" and c or (type(b)=="number" and b) or nil
        if not id and type(a)=="number" and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
            local info=C_SpellBook.GetSpellBookItemInfo(a,Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0)
            id=info and (info.spellID or info.actionID)
        end
        if type(id)=="number" then return {kind="spell",id=id} end
    elseif kind=="item" and type(a)=="number" then return {kind="item",id=a}
    elseif kind=="macro" and type(a)=="number" and GetMacroInfo then
        local name=GetMacroInfo(a); if name then return {kind="macro",name=name} end
    end
end

-- On-screen role bar: real (secure) spell buttons you can also click,
-- with the key and the cooldown shown. Movable with Move elements.
function Binds:Bar()
    if self.bar then return self.bar end
    local bar=CreateFrame("Frame","ForeverToolsRoleBar",UIParent)
    bar:SetSize(6*44,40); bar:SetClampedToScreen(true); bar:SetFrameStrata("LOW")
    FT:MoverBox(bar,6)
    for _,t in ipairs(bar.fillTextures) do t:Hide() end; for _,t in ipairs(bar.borderTextures) do t:Hide() end
    bar.hint=FT:Label(bar,"Drag to move",12); FT:Caption(bar.hint,bar,"below",6); bar.hint:Hide()
    bar.buttons={}
    for i=1,#ROLES do
        local b=CreateFrame("Button","ForeverToolsRoleButton"..i,bar,"SecureActionButtonTemplate")
        b:SetSize(38,38); b:RegisterForClicks("AnyUp","AnyDown"); b:SetAttribute("type","spell")
        b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(b.icon)
        b.key=b:CreateFontString(nil,"OVERLAY","NumberFontNormalSmallGray"); b.key:SetPoint("TOPRIGHT",-2,-3)
        -- Border in the action bar skin's color (shown when that skin is on).
        b.rim=b:CreateTexture(nil,"BACKGROUND",nil,-5); b.rim:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga"); b.rim:Hide()
        -- The cooldown sits on the bar, not on the secure button, so it can update in combat.
        b.cd=CreateFrame("Cooldown",nil,bar,"CooldownFrameTemplate"); b.cd:SetAllPoints(b)
        b:SetScript("OnEnter",function(owner) if owner.spellID then GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetSpellByID(owner.spellID); GameTooltip:Show() end end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        bar.buttons[i]=b
    end
    bar:SetMovable(true); bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function(f) if self.moving and not InCombatLockdown() then f:StartMoving() end end)
    bar:SetScript("OnDragStop",function(f)
        f:StopMovingOrSizing()
        local x,y=f:GetCenter(); local s=self:Settings(); s.x,s.y=x,y
    end)
    bar:SetScript("OnEvent",function() self:Cooldowns() end)
    self.bar=bar
    -- Same look as your action bars: skin and key font.
    if FT.modules.IconStyles then FT.modules.IconStyles:Queue() end
    if FT.modules.FontManager then FT.modules.FontManager:Queue({actions=true}) end
    return bar
end
function Binds:Place()
    local bar=self.bar; if not bar or InCombatLockdown() then return end
    local s=self:Settings(); bar:ClearAllPoints()
    if type(s.x)=="number" and type(s.y)=="number" then bar:SetPoint("CENTER",UIParent,"BOTTOMLEFT",s.x,s.y)
    else bar:SetPoint("BOTTOM",UIParent,"BOTTOM",0,220) end
end
function Binds:UpdateBar()
    local s=self:Settings()
    local show=(s.enabled and s.bar) or self.moving
    if not show then
        if self.bar and not InCombatLockdown() then self.bar:Hide(); self.bar:UnregisterAllEvents() end
        return
    end
    if InCombatLockdown() then self.pending=true; return end
    local bar=self:Bar(); local n=0
    -- Only roles with a key; while moving with none keyed yet, all of them,
    -- so there is something to place.
    local anyKey=false
    for _,role in ipairs(ROLES) do if s.roles[role.key].key then anyKey=true end end
    for i,role in ipairs(ROLES) do
        local b=bar.buttons[i]
        local entry,name,icon=self:RoleSpell(role)
        if entry and entry.kind=="spell" and (s.roles[role.key].key or (self.moving and not anyKey)) then
            n=n+1
            b:ClearAllPoints(); b:SetPoint("LEFT",bar,"LEFT",(n-1)*44+2,0)
            b:SetAttribute("spell",name); b.spellID=entry.id; b.spellName=name
            b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            local r=s.roles[role.key]
            b.key:SetText(not r.off and shortKey(r.key) or "")
            b:Show()
        else b:SetAttribute("spell",nil); b.spellName=nil; b.spellID=nil; b:Hide(); b.cd:Clear() end
    end
    bar:SetWidth(math.max(1,n)*44)
    self:Place()
    bar:Show()
    bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:Cooldowns()
end
-- Called by the icon skin whenever it repaints the action bars.
function Binds:PaintRim()
    local bar=self.bar; local skins=FT.modules.IconStyles; if not bar or not skins then return end
    local on=skins:Settings().actions==true
    local a=on and skins:Area("actions")
    for _,b in ipairs(bar.buttons) do
        if on then
            local t=a.thickness
            b.rim:ClearAllPoints(); b.rim:SetPoint("TOPLEFT",b.icon,"TOPLEFT",-t,t); b.rim:SetPoint("BOTTOMRIGHT",b.icon,"BOTTOMRIGHT",t,-t)
            b.rim:SetVertexColor(a.borderColor[1],a.borderColor[2],a.borderColor[3],a.borderOpacity)
        end
        b.rim:SetShown(on)
    end
end
function Binds:Cooldowns()
    local bar=self.bar; if not bar then return end
    for _,b in ipairs(bar.buttons) do
        if b.spellName and C_Spell and C_Spell.GetSpellCooldown then
            local info=C_Spell.GetSpellCooldown(b.spellName)
            local start,duration=info and info.startTime,info and info.duration
            -- The game can hide cooldowns in some places; then the old one stays.
            if readable(start) and readable(duration) and type(start)=="number" and type(duration)=="number" then
                if duration>1.5 then pcall(b.cd.SetCooldown,b.cd,start,duration) else b.cd:Clear() end
            end
        end
    end
end
-- Move elements
function Binds:SetMoving(on)
    if InCombatLockdown() then on=false end
    self.moving=on==true
    local bar=self:Bar()
    for _,t in ipairs(bar.fillTextures) do t:SetShown(self.moving) end
    for _,t in ipairs(bar.borderTextures) do t:SetShown(self.moving) end
    bar.hint:SetShown(self.moving); bar:EnableMouse(self.moving)
    -- While moving, a click drags the bar; it never casts.
    for _,b in ipairs(bar.buttons) do b:EnableMouse(not self.moving) end
    bar:SetFrameStrata(self.moving and "HIGH" or "LOW")
    self:UpdateBar()
end

-- A new character: ask once whether to use your usual role keys.
function Binds:AskNewCharacter()
    local r=self:Root(); local id=guid()
    if not id or not r.ask or InCombatLockdown() then return end
    -- Only a character that hasn't been asked and has no role keys of its own.
    local mine=self:Settings()
    if mine.asked or mine.enabled then return end
    for _,role in ipairs(ROLES) do if mine.roles[role.key].key then return end end
    local lines={}
    for _,role in ipairs(ROLES) do
        local key=r.template[role.key]
        if key then local _,name=self:RoleSpell(role); lines[#lines+1]=keyText(key).." "..role.label..(name and " ("..name..")" or "") end
    end
    if #lines==0 then return end
    local s=mine; s.asked=true -- asked once; closing the question means no
    FT:Confirm("Use your role keys on this character?\n\n"..table.concat(lines,", "),function()
        for _,role in ipairs(ROLES) do s.roles[role.key].key=r.template[role.key] end
        s.enabled=true; self:Apply()
    end)
end

-- Settings page
function Binds:Refresh()
    if not self.frame then return end
    local s=self:Settings(); local r=self:Root()
    self.toggle.label:SetText("Spell binds: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.barToggle.label:SetText("Show on screen: "..(s.bar and "On" or "Off")); FT:SetSelected(self.barToggle,s.bar)
    self.askToggle.label:SetText("Ask on new characters: "..(r.ask and "On" or "Off")); FT:SetSelected(self.askToggle,r.ask)
    for i,role in ipairs(ROLES) do
        local row=self.roleRows[i]
        local entry,name,icon=self:RoleSpell(role)
        row.icon:SetTexture(icon or ("Interface\\Icons\\"..role.icon)); row.icon:SetDesaturated(not entry); row.icon:SetAlpha(entry and 1 or .4)
        row.spell:SetText(name or "No "..role.label:lower().." spell known")
        local r=s.roles[role.key]; local label=row.keyButton.label
        -- The full name when it fits, else the short one.
        label:SetText(r.key and keyText(r.key) or "Set key")
        if r.key and label:GetStringWidth()>54 then label:SetText(shortKey(r.key)) end
        local on=r.key and not r.off
        label:SetTextColor(on and 1 or .55,on and .82 or .49,on and 0 or .40)
    end
    for i=1,SLOTS do
        local cell=self.cells[i]; local slot=s.slots[i]
        local name,icon=describe(slot)
        cell.icon:SetShown(name~=nil); cell.plus:SetShown(name==nil)
        if name then cell.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
        cell.key:SetText(type(slot)=="table" and shortKey(slot.key) or "")
        cell.key:SetAlpha(type(slot)=="table" and slot.off and .4 or 1)
    end
    self:RefreshPopup()
end
-- One bind's own small window: set its key, turn it on or off, clear it.
-- Nothing changes until you press one of its buttons.
function Binds:Store(t)
    if not t then return end
    local s=self:Settings()
    if t.role then return s.roles[t.role.key] end
    local slot=s.slots[t.slot]; return type(slot)=="table" and slot or nil
end
function Binds:Popup()
    if self.popup then return self.popup end
    local p=CreateFrame("Frame",nil,self.frame); p:SetSize(248,208)
    p:SetFrameStrata("FULLSCREEN"); p:SetToplevel(true); p:EnableMouse(true); p:SetClampedToScreen(true)
    FT:Panel(p)
    p.icon=p:CreateTexture(nil,"ARTWORK"); p.icon:SetSize(28,28); p.icon:SetPoint("TOPLEFT",24,-18); p.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(p.icon)
    p.title=FT:Label(p,"",14,true); p.title:SetPoint("LEFT",p.icon,"RIGHT",8,0); p.title:SetPoint("RIGHT",p,"RIGHT",-44,0)
    p.title:SetJustifyH("LEFT"); p.title:SetWordWrap(false); p.title:SetTextColor(1,.82,0)
    FT:AddClose(p,function() self:ClosePopup() end,12)
    p.keyButton=FT:QuietButton(p,"",200,32,"keybind"); p.keyButton:SetPoint("TOPLEFT",24,-60)
    p.keyButton:SetScript("OnClick",function()
        if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
        if self.capturing then self:Capture(nil) else self:Capture(p.target) end
    end)
    FT:Tooltip(p.keyButton,"Set key","Click, then press the key (with Shift, Ctrl or Alt if you like). You're told first if the key already does something.\n\nWhile this bind is on, the key does this instead of its action bar button. Turn the bind off or clear it to give the key back.")
    p.onButton=FT:QuietButton(p,"",200,32,"confirm"); p.onButton:SetPoint("TOPLEFT",24,-100)
    p.onButton:SetScript("OnClick",function()
        if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
        local store=self:Store(p.target); if not store then return end
        store.off=not store.off or nil; self:Apply()
    end)
    FT:Tooltip(p.onButton,"Bind on or off","Off keeps the key saved here but gives it back to what it did before, until you turn it on again.")
    p.clear=FT:QuietButton(p,"Clear key",200,32,"reset"); p.clear:SetPoint("TOPLEFT",24,-140)
    p.clear:SetScript("OnClick",function()
        if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
        local store=self:Store(p.target); if store then self:SetKey(store,nil) end
    end)
    FT:Tooltip(p.clear,"Clear key","Remove the key. It gets its old action back.")
    p.remove=FT:QuietButton(p,"Remove from slot",200,32,"delete"); p.remove:SetPoint("TOPLEFT",24,-180)
    p.remove:SetScript("OnClick",function()
        if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
        local t=p.target; if not t or not t.slot then return end
        self:ClosePopup(); self:Settings().slots[t.slot]=nil; self:Apply()
    end)
    FT:Tooltip(p.remove,"Remove from slot","Empty this slot. Its key gets its old action back.")
    p.hint=FT:Label(p,"Press a key now. Esc cancels.",12); p.hint:SetPoint("BOTTOM",0,12); p.hint:SetTextColor(1,.27,.22); p.hint:Hide()
    p:Hide()
    self.popup=p
    return p
end
function Binds:OpenPopup(t,anchor)
    local p=self:Popup()
    if p:IsShown() and p.target and p.target.role==t.role and p.target.slot==t.slot then self:ClosePopup(); return end
    if self.capturing then self:Capture(nil) end
    p.target=t
    p:ClearAllPoints()
    if t.role then p:SetPoint("TOPRIGHT",anchor,"TOPLEFT",-8,0) else p:SetPoint("BOTTOMLEFT",anchor,"TOPRIGHT",8,0) end
    p:SetHeight(t.slot and 248 or 208); p.remove:SetShown(t.slot~=nil)
    p:Show(); self:RefreshPopup()
end
function Binds:ClosePopup()
    if self.capturing then self:Capture(nil) end
    if self.popup then self.popup:Hide(); self.popup.target=nil end
end
function Binds:RefreshPopup()
    local p=self.popup; if not p or not p:IsShown() then return end
    local t=p.target; local store=self:Store(t)
    if not store then self:ClosePopup(); return end
    local name,icon
    if t.role then local _,n,i=self:RoleSpell(t.role); name=t.role.label..(n and (": "..n) or ""); icon=i or ("Interface\\Icons\\"..t.role.icon)
    else name,icon=describe(store) end
    p.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark"); p.title:SetText(name or "")
    local capturing=self.capturing~=nil
    p.keyButton.label:SetText(capturing and "Press a key…" or (store.key and ("Key: "..keyText(store.key)) or "Set key"))
    p.onButton.label:SetText("Bind: "..(store.off and "Off" or "On")); FT:SetSelected(p.onButton,not store.off)
    p.clear:SetEnabled(store.key~=nil); p.clear:SetAlpha(store.key and 1 or .45)
    p.hint:SetShown(capturing)
end
function Binds:Capture(target)
    self.capturing=target
    self.capture:EnableKeyboard(target~=nil); self.capture:SetPropagateKeyboardInput(target==nil); self.capture:SetShown(target~=nil)
    self:Refresh()
end
function Binds:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsSpellBinds","Spell binds",520,608); self.frame=frame
        FT:BackTo(frame,"SystemKeybinds")
        FT:PageInfo(frame,"Spell binds","Bind spells, items and macros straight to keys, without an action bar.\n\nRole keys pick your class's spell for each job (interrupt, taunt, dispel and so on), so the same key does the same job on every character. Click a role's icon to choose another of your spells, or drag any spell onto it.\n\nA key used here does the spell bind instead of its normal action. Your normal key bindings are never changed: clear a key here and it gets its old action back. Keys can only change out of combat.")
        self.toggle=FT:AccentButton(frame,"",472,34,"INV_Misc_Key_13"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function()
            if InCombatLockdown() then FT:Toast("Leave combat to change this.") return end
            local s=self:Settings(); s.enabled=not s.enabled; self:Apply()
            if FT.modules.System then FT.modules.System:Refresh() end
        end)
        FT:Tooltip(self.toggle,"Spell binds","Turn all spell binds and role keys on or off. Off gives every key back to what it did before.")
        local head=FT:Label(frame,"Role keys",15,true); head:SetPoint("TOPLEFT",24,-112); FT:SectionHeading(head,"Ability_Kick",330)
        self.roleRows={}
        for i,role in ipairs(ROLES) do
            -- Two columns: left 24, right 264 (each 232 wide).
            local y=-140-math.floor((i-1)/2)*44
            local x=(i%2==1) and 24 or 264
            local row={}
            local cell=CreateFrame("Button",nil,frame); cell:SetSize(40,40); cell:SetPoint("TOPLEFT",x,y)
            FT:Panel(cell); FT:Paint(cell,{0.05,0.04,0.03,1},{0.29,0.24,0.15,1})
            row.icon=cell:CreateTexture(nil,"ARTWORK"); row.icon:SetPoint("TOPLEFT",3,-3); row.icon:SetPoint("BOTTOMRIGHT",-3,3); row.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(row.icon)
            cell:RegisterForClicks("LeftButtonUp","RightButtonUp")
            local function take()
                local entry=fromCursor(); if not entry or entry.kind~="spell" then return end
                ClearCursor(); self:Settings().roles[role.key].spell=entry; self:Apply()
            end
            cell:SetScript("OnReceiveDrag",take)
            cell:SetScript("OnClick",function(_,mouse)
                if GetCursorInfo and GetCursorInfo() then take(); return end
                if mouse=="RightButton" then self:Settings().roles[role.key].spell=nil; self:Apply()
                elseif not InCombatLockdown() then self:PickRoleSpell(role,cell) end
            end)
            FT:Tooltip(cell,role.label,"Click to choose which of your spells to use (automatic picks the first one you know). You can also drag any spell here. Right-click goes back to automatic.")
            row.name=FT:Label(frame,role.label,14); row.name:SetPoint("TOPLEFT",x+48,y-4)
            row.spell=FT:Label(frame,"",12); row.spell:SetPoint("TOPLEFT",x+48,y-21); row.spell:SetTextColor(.66,.59,.48)
            row.spell:SetWidth(112); row.spell:SetJustifyH("LEFT"); row.spell:SetWordWrap(false)
            local keyButton=FT:QuietButton(frame,"",64,28); keyButton:SetPoint("TOPLEFT",x+168,y-6)
            keyButton:SetScript("OnClick",function()
                if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
                self:OpenPopup({role=role},keyButton)
            end)
            FT:Tooltip(keyButton,role.label.." key","Click to set the key, or turn it off or clear it.\n\nA key used here does this instead of what your action bars say; the key text on the action button stays, but that button no longer answers the key.")
            row.keyButton=keyButton; row.role=role
            self.roleRows[i]=row
        end
        self.barToggle=FT:QuietButton(frame,"",230,32,"INV_Misc_Key_13"); self.barToggle:SetPoint("TOPLEFT",24,-372)
        self.barToggle:SetScript("OnClick",function()
            if InCombatLockdown() then return end
            local s=self:Settings(); s.bar=not s.bar; self:Apply()
            -- The bar belongs to spell binds: offer to turn them on with it.
            if s.bar and not s.enabled then
                FT:Confirm("Spell binds are off, so the bar stays hidden.\n\nTurn spell binds on too?",function()
                    s.enabled=true; self:Apply()
                    if FT.modules.System then FT.modules.System:Refresh() end
                end)
            end
        end)
        FT:Tooltip(self.barToggle,"Show on screen","A small bar with the role spells you gave a key: icon, key and cooldown. You can click them too. Move it with Move elements.")
        self.askToggle=FT:QuietButton(frame,"",230,32,"character"); self.askToggle:SetPoint("TOPLEFT",266,-372)
        self.askToggle:SetScript("OnClick",function() local r=self:Root(); r.ask=not r.ask; self:Refresh() end)
        FT:Tooltip(self.askToggle,"Ask on new characters","On a character that hasn't used spell binds yet, ask once whether to use your usual role keys.")
        local grid=FT:Label(frame,"Your binds",15,true); grid:SetPoint("TOPLEFT",24,-420); FT:SectionHeading(grid,"INV_Misc_Key_03",330)
        local hint=FT:Label(frame,"Drag a spell, item or macro onto a slot, then click it to set its key.",12); hint:SetPoint("TOPLEFT",24,-444); hint:SetTextColor(.66,.59,.48)
        self.cells={}
        for i=1,SLOTS do
            local cell=CreateFrame("Button",nil,frame); cell:SetSize(40,40)
            cell:SetPoint("TOPLEFT",24+((i-1)%10)*48,-468-math.floor((i-1)/10)*48)
            FT:Panel(cell); FT:Paint(cell,{0.05,0.04,0.03,1},{0.29,0.24,0.15,1})
            cell.icon=cell:CreateTexture(nil,"ARTWORK"); cell.icon:SetPoint("TOPLEFT",3,-3); cell.icon:SetPoint("BOTTOMRIGHT",-3,3); cell.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(cell.icon)
            cell.plus=FT:Label(cell,"+",20); cell.plus:SetPoint("CENTER"); cell.plus:SetTextColor(.49,.44,.36)
            cell.key=cell:CreateFontString(nil,"OVERLAY","NumberFontNormalSmallGray"); cell.key:SetPoint("TOPRIGHT",-2,-3)
            cell:RegisterForClicks("LeftButtonUp","RightButtonUp"); cell:RegisterForDrag("LeftButton")
            local function take()
                local entry=fromCursor(); if not entry then return end
                ClearCursor()
                local s=self:Settings(); local old=s.slots[i]
                entry.key=type(old)=="table" and old.key or nil
                entry.off=type(old)=="table" and old.off or nil
                s.slots[i]=entry; self:Apply()
            end
            cell:SetScript("OnReceiveDrag",take)
            cell:SetScript("OnDragStart",function()
                -- Drag it off the slot to remove it.
                if InCombatLockdown() then return end
                local s=self:Settings(); local slot=s.slots[i]; if type(slot)~="table" then return end
                if slot.kind=="spell" and C_Spell and C_Spell.PickupSpell then C_Spell.PickupSpell(slot.id)
                elseif slot.kind=="item" and C_Item and C_Item.PickupItem then C_Item.PickupItem(slot.id)
                elseif slot.kind=="macro" and PickupMacro then PickupMacro(slot.name) end
                s.slots[i]=nil; self:ClosePopup(); self:Apply()
            end)
            cell:SetScript("OnClick",function(_,mouse)
                if GetCursorInfo and GetCursorInfo() then take(); return end
                if InCombatLockdown() then FT:Toast("Leave combat to change keys.") return end
                local slot=self:Settings().slots[i]
                if type(slot)~="table" or mouse=="RightButton" then return end
                self:OpenPopup({slot=i},cell)
            end)
            cell:SetScript("OnEnter",function(owner)
                local slot=self:Settings().slots[i]
                GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
                if type(slot)~="table" then GameTooltip:SetText("Empty slot",1,.82,0); GameTooltip:AddLine("Drag a spell, item or macro here.",.96,.93,.86,true)
                else
                    if slot.kind=="spell" then GameTooltip:SetSpellByID(slot.id) elseif slot.kind=="item" then GameTooltip:SetItemByID(slot.id) else GameTooltip:SetText(slot.name,1,.82,0) end
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine((slot.key and ("Key: "..keyText(slot.key)..(slot.off and " (off)" or "")) or "No key yet").."\nClick to set its key or turn it off. Drag it off to remove it.",1,.82,0,true)
                end
                GameTooltip:Show()
            end)
            cell:SetScript("OnLeave",function() GameTooltip:Hide() end)
            self.cells[i]=cell
        end
        -- Key capture: the next key pressed becomes the key.
        local capture=CreateFrame("Frame",nil,frame); capture:SetAllPoints(frame); capture:EnableKeyboard(false); capture:Hide()
        capture:SetScript("OnKeyDown",function(_,key)
            local target=self.capturing; if not target then return end
            if key=="ESCAPE" then self:Capture(nil); return end
            if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
            local combo=(IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
            self:Capture(nil)
            local store=self:Store(target)
            local what=target.role and target.role.label or (describe(store)) or "this"
            if type(store)=="table" then self:Propose(store,combo,what) end
        end)
        self.capture=capture
        frame:HookScript("OnHide",function() self:ClosePopup() end)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("SpellBinds",Binds)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","SPELLS_CHANGED","UPDATE_MACROS"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then
        Binds:Apply(); C_Timer.After(8,function() Binds:AskNewCharacter() end)
    elseif event=="PLAYER_REGEN_ENABLED" then
        if Binds.pending then Binds:Apply() end
    else
        -- New spells (a role may pick a better one) or renamed macros.
        local s=Binds:Settings()
        if s.enabled then FT:Coalesce("spellBinds",function() Binds:Apply() end,.5) end
    end
end)
