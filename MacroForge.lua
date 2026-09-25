local _, KT = ...

local MacroForge = {
    selectedRank = "max",
    selectedMacro = nil,
    scope = "character",
    filter = "mine",
    mouseover = false,
}

-- Add future utilities as their own module files; Macro Forge owns only macro data and UI.
local classMacros = {
    Druid = {
        {"Healing Touch", 11, "friendly", "spell_nature_healingtouch"}, {"Rejuvenation", 11, "friendly", "spell_nature_rejuvenation"}, {"Regrowth", 9, "friendly", "spell_nature_resistnature"}, {"Moonfire", 12, nil, "spell_nature_starfall"}, {"Entangling Roots", 6, nil, "spell_nature_stranglevines"}, {"Faerie Fire", 4, nil, "spell_nature_faeriefire"}, {"Bash", 3, "startattack", "ability_druid_bash"}, {"Maul", 9, "startattack", "ability_druid_maul"}, {"Swipe", 5, "startattack", "inv_misc_monsterclaw_03"}, {"Rake", 4, "startattack", "ability_druid_disembowel"}, {"Rip", 6, "startattack", "ability_ghoulfrenzy"}, {"Shred", 6, "startattack", "spell_shadow_vampiricaura"}, {"Ferocious Bite", 5, "startattack", "ability_druid_ferociousbite"}, {"Bear Form", 1, "self", "ability_racial_bearform"}, {"Cat Form", 1, "self", "ability_druid_catform"}, {"Travel Form", 1, "self", "ability_druid_travelform"}, {"Prowl", 3, "self", "ability_druid_disembowel"},
    },
    Hunter = {
        {"Arcane Shot", 8, nil, "ability_impalingbolt"}, {"Aimed Shot", 6, nil, "inv_spear_07"}, {"Serpent Sting", 9, nil, "ability_hunter_quickshot"}, {"Concussive Shot", 1, nil, "spell_frost_stun"}, {"Multi-Shot", 5, nil, "ability_upgrademoonglaive"}, {"Freezing Trap", 3, nil, "spell_frost_chainsofice"}, {"Wing Clip", 3, "startattack", "ability_rogue_trip"}, {"Raptor Strike", 8, "startattack", "ability_meleedamage"}, {"Mongoose Bite", 4, "startattack", "ability_hunter_swiftstrike"}, {"Aspect of the Hawk", 1, "self", "spell_nature_ravenform"}, {"Aspect of the Cheetah", 1, "self", "ability_mount_jungletiger"}, {"Aspect of the Pack", 1, "self", "ability_mount_jungletiger"}, {"Pet Attack", 1, "self", "ability_hunter_beastcall"},
    },
    Mage = {
        {"Fireball", 12, nil, "spell_fire_fireball02"}, {"Frostbolt", 11, nil, "spell_frost_frostbolt02"}, {"Arcane Missiles", 8, nil, "spell_nature_starfall"}, {"Polymorph", 4, nil, "spell_nature_polymorph"}, {"Counterspell", 1, nil, "spell_frost_iceshock"}, {"Fire Blast", 7, nil, "spell_fire_fireball"}, {"Scorch", 7, nil, "spell_fire_soulburn"}, {"Blink", 1, "self", "spell_arcane_blink"}, {"Frost Nova", 4, nil, "spell_frost_frostnova"}, {"Ice Block", 1, "self", "spell_frost_frost"}, {"Mana Shield", 6, "self", "spell_shadow_detectlesserinvisibility"},
    },
    Paladin = {
        {"Holy Light", 11, "friendly", "spell_holy_holybolt"}, {"Flash of Light", 7, "friendly", "spell_holy_flashheal"}, {"Blessing of Might", 7, "friendly", "spell_holy_fistofjustice"}, {"Blessing of Wisdom", 6, "friendly", "spell_holy_sealofwisdom"}, {"Blessing of Protection", 3, "friendly", "spell_holy_sealofprotection"}, {"Blessing of Freedom", 1, "friendly", "spell_holy_sealofvalor"}, {"Blessing of Kings", 1, "friendly", "spell_magic_magearmor"}, {"Blessing of Salvation", 1, "friendly", "spell_holy_sealofsalvation"}, {"Blessing of Sacrifice", 1, "friendly", "spell_holy_sealofsacrifice"}, {"Purify", 1, "friendly", "spell_holy_purify"}, {"Cleanse", 1, "friendly", "spell_holy_renew"}, {"Lay on Hands", 3, "friendly", "spell_holy_layonhands"}, {"Redemption", 5, "friendly", "spell_holy_resurrection"}, {"Judgement", 6, "startattack", "spell_holy_righteousfury"}, {"Hammer of Justice", 4, "startattack", "spell_holy_sealofmight"}, {"Holy Strike", 1, "startattack", "inv_sword_2h_ashbringercorrupt"}, {"Seal of Righteousness", 8, "self", "ability_thunderbolt"}, {"Seal of Command", 5, "self", "ability_warrior_innerrage"}, {"Seal of Wisdom", 5, "self", "spell_holy_sealofwisdom"}, {"Seal of Light", 4, "self", "spell_holy_healingaura"}, {"Consecration", 5, nil, "spell_holy_innerfire"}, {"Divine Shield", 2, "self", "spell_holy_divineshield"}, {"Divine Intervention", 1, "friendly", "spell_holy_divineintervention"},
    },
    Priest = {
        {"Lesser Heal", 3, "friendly", "spell_holy_lesserheal"}, {"Heal", 4, "friendly", "spell_holy_heal"}, {"Flash Heal", 7, "friendly", "spell_holy_flashheal"}, {"Renew", 10, "friendly", "spell_holy_renew"}, {"Power Word: Shield", 10, "friendly", "spell_holy_powerwordshield"}, {"Dispel Magic", 2, "friendly", "spell_holy_dispelmagic"}, {"Cure Disease", 1, "friendly", "spell_holy_nullifydisease"}, {"Levitate", 1, "friendly", "spell_holy_layonhands"}, {"Resurrection", 5, "friendly", "spell_holy_resurrection"}, {"Mind Blast", 9, nil, "spell_shadow_unholyfrenzy"}, {"Shadow Word: Pain", 8, nil, "spell_shadow_shadowwordpain"}, {"Mind Flay", 6, nil, "spell_shadow_siphonmana"}, {"Psychic Scream", 4, nil, "spell_shadow_psychicscream"}, {"Silence", 1, nil, "spell_shadow_impphaseshift"},
    },
    Rogue = {
        {"Sinister Strike", 9, "startattack", "spell_shadow_ritualofsacrifice"}, {"Backstab", 9, "startattack", "ability_backstab"}, {"Eviscerate", 9, "startattack", "ability_rogue_eviscerate"}, {"Kick", 1, "startattack", "ability_kick"}, {"Gouge", 5, "startattack", "ability_gouge"}, {"Sap", 3, nil, "ability_sap"}, {"Blind", 1, nil, "spell_shadow_mindsteal"}, {"Vanish", 3, "self", "ability_vanish"}, {"Garrote", 6, "startattack", "ability_rogue_garrote"}, {"Rupture", 6, "startattack", "ability_rogue_rupture"}, {"Ambush", 6, "startattack", "ability_rogue_ambush"}, {"Cheap Shot", 1, "startattack", "ability_cheapshot"}, {"Kidney Shot", 2, "startattack", "ability_rogue_kidneyshot"}, {"Stealth", 4, "self", "ability_stealth"}, {"Sprint", 3, "self", "ability_rogue_sprint"}, {"Evasion", 1, "self", "spell_shadow_shadowward"},
    },
    Shaman = {
        {"Lightning Bolt", 10, nil, "spell_nature_lightning"}, {"Chain Lightning", 6, nil, "spell_nature_chainlightning"}, {"Earth Shock", 7, nil, "spell_nature_earthshock"}, {"Flame Shock", 6, nil, "spell_fire_flameshock"}, {"Frost Shock", 7, nil, "spell_frost_frostshock"}, {"Healing Wave", 10, "friendly", "spell_nature_magicimmunity"}, {"Lesser Healing Wave", 6, "friendly", "spell_nature_healingwavelesser"}, {"Purge", 2, nil, "spell_nature_purge"}, {"Chain Heal", 3, "friendly", "spell_nature_healingwavegreater"}, {"Ghost Wolf", 1, "self", "spell_nature_spiritwolf"}, {"Lightning Shield", 7, "self", "spell_nature_lightningshield"}, {"Windfury Weapon", 3, "self", "spell_nature_cyclone"},
    },
    Warlock = {
        {"Shadow Bolt", 11, nil, "spell_shadow_shadowbolt"}, {"Corruption", 7, nil, "spell_shadow_abominationexplosion"}, {"Bane of Agony", 6, nil, "spell_shadow_curseofsargeras"}, {"Fear", 3, nil, "spell_shadow_possession"}, {"Drain Life", 6, nil, "spell_shadow_lifedrain02"}, {"Immolate", 8, nil, "spell_fire_immolation"}, {"Life Tap", 6, "self", "spell_shadow_burningspirit"}, {"Howl of Terror", 2, nil, "spell_shadow_deathscream"}, {"Death Coil", 4, nil, "spell_shadow_deathcoil"}, {"Banish", 2, nil, "spell_shadow_cripple"}, {"Shadow Ward", 4, "self", "spell_shadow_antishadow"},
    },
    Warrior = {
        {"Heroic Strike", 9, "startattack", "ability_rogue_ambush"}, {"Sunder Armor", 5, "startattack", "ability_warrior_sunder"}, {"Overpower", 4, "startattack", "ability_meleedamage"}, {"Charge", 3, "startattack", "ability_warrior_charge"}, {"Pummel", 1, "startattack", "inv_gauntlets_04"}, {"Thunder Clap", 7, "startattack", "ability_thunderclap"}, {"Cleave", 6, "startattack", "ability_warrior_cleave"}, {"Rend", 8, "startattack", "ability_gouge"}, {"Mocking Blow", 5, "startattack", "ability_warrior_punishingblow"}, {"Disarm", 1, "startattack", "ability_warrior_disarm"}, {"Revenge", 6, "startattack", "ability_warrior_revenge"}, {"Slam", 6, "startattack", "ability_warrior_decisivestrike"}, {"Intercept", 3, "startattack", "ability_rogue_sprint"}, {"Mortal Strike", 4, "startattack", "ability_warrior_savageblow"}, {"Bloodthirst", 6, "startattack", "spell_nature_bloodlust"}, {"Execute", 6, "startattack", "inv_sword_48"}, {"Hamstring", 4, "startattack", "ability_shockwave"}, {"Shield Bash", 1, "startattack", "ability_warrior_shieldbash"},
    },
}

-- Additional verified beta templates are maintained separately from the
-- original catalogue. Live spellbook discovery below fills future gaps.
for class,entries in pairs(KT.verifiedMacros or {}) do
    local names={};for _,entry in ipairs(classMacros[class] or {}) do names[entry[1]]=true end
    for _,entry in ipairs(entries) do
        if not names[entry[1]] then classMacros[class][#classMacros[class]+1]=entry end
    end
end

local racials = {
    Human = {{"Will to Survive", 1, "self", "spell_shadow_charm"}, {"Perception", 1, "self", "spell_nature_sleep"}},
    Dwarf = {{"Stoneform", 1, "self", "spell_shadow_unholystrength"}, {"Find Treasure", 1, "self", "inv_misc_bag_10"}},
    ["Night Elf"] = {{"Elune's Light", 1, "self", "spell_holy_elunesgrace"}, {"Shadowmeld", 1, "self", "ability_stealth"}},
    Gnome = {{"Escape Artist", 1, "self", "ability_rogue_trip"}, {"Eureka", 1, "self", "inv_misc_enggizmos_27"}},
    Orc = {{"Blood Fury", 1, "self", "racial_orc_berserkerstrength"}, {"Shatter Curse", 1, "self", "spell_shadow_unholyfrenzy"}},
    Undead = {{"Will of the Forsaken", 1, "self", "spell_shadow_raisedead"}, {"Cannibalize", 1, "self", "ability_racial_cannibalize"}},
    Tauren = {{"War Stomp", 1, nil, "ability_warstomp"}, {"Cultivation", 1, "self", "spell_nature_natureblessing"}},
    Troll = {{"Berserking", 1, "self", "racial_troll_berserk"}, {"Rapid Regeneration", 1, "self", "spell_nature_reincarnation"}},
    ["Skyborne (Alliance)"] = {{"Walk on Air", 1, "self", "spell_frost_windwalkon"}, {"Read Ley Line", 1, "self", "spell_arcane_arcane01"}},
    ["Skyborne (Horde)"] = {{"Walk on Air", 1, "self", "spell_frost_windwalkon"}, {"Skysight", 1, "self", "spell_nature_farsight"}},
}

local genericMacros = {
    {"1-shot combo", 1, "generic", "spell_nature_bloodlust", "#showtooltip"},
    {"Start attack", 1, "generic", "inv_sword_04", "#showtooltip\n/startattack"},
    {"Stop casting", 1, "generic", "spell_shadow_teleport", "#showtooltip\n/stopcasting"},
    {"Focus mouseover", 1, "generic", "ability_hunter_snipershot", "#showtooltip\n/focus [@mouseover,exists]"},
    {"Role Poll", 1, "generic", "spell_holy_powerwordshield", "#showtooltip\n/run InitiateRolePoll()"},
    {"Party GZ", 1, "generic", "inv_misc_rabbit", "#showtooltip\n/P GZ!!!\n/P (\\ /)\n/P (^_^)\n/p (*(\")(\")"},
    {"Target nearest enemy", 1, "generic", "ability_hunter_assassinate2", "#showtooltip\n/targetenemy [noharm][dead]\n/startattack"},
}

local function raceKey()
    local _, englishRace = UnitRace("player")
    if englishRace == "Skyborne" then
        local faction = UnitFactionGroup("player")
        return faction == "Horde" and "Skyborne (Horde)" or "Skyborne (Alliance)"
    end
    local aliases = { NightElf = "Night Elf", Scourge = "Undead" }
    return aliases[englishRace] or englishRace or "Human"
end

local function classKey()
    local _, englishClass = UnitClass("player")
    for name in pairs(classMacros) do
        if string.upper(name) == englishClass then return name end
    end
    return englishClass or "Warrior"
end

local function addEntries(destination, entries, className, raceName, category)
    for _, data in ipairs(entries or {}) do
        destination[#destination + 1] = { name = data[1], ranks = data[2], kind = data[3], icon = data[4], code = data[5], class = className, race = raceName, category = category }
    end
end

local noUnitTarget = {
    ["Consecration"] = true, ["Freezing Trap"] = true, ["Frost Nova"] = true,
    ["Psychic Scream"] = true, ["Howl of Terror"] = true, ["Thunder Clap"] = true,
    ["War Stomp"] = true, ["Swipe"] = true,
    -- Queued next-swing attacks use the current melee target, not a mouseover unit.
    ["Heroic Strike"] = true, ["Cleave"] = true, ["Maul"] = true, ["Raptor Strike"] = true,
}
function MacroForge:CanMouseover(entry)
    return entry and entry.category ~= "generic" and not entry.code and entry.kind ~= "self" and not noUnitTarget[entry.name]
end
function MacroForge:BuildMacro(entry)
    if entry.code then return entry.code end
    local spell = entry.name
    if self.selectedRank ~= "max" and entry.ranks and entry.ranks > 1 then spell = spell .. "(Rank " .. self.selectedRank .. ")" end
    local lines = {"#showtooltip " .. spell}
    if entry.kind == "startattack" then lines[#lines + 1] = "/startattack" end
    if entry.name=="Dispel Magic" then
        lines[#lines+1]="/cast "..(self.mouseover and "[@mouseover,exists,nodead][] " or "")..spell
    elseif entry.name=="Redemption" or entry.name=="Resurrection" or entry.name=="Revive" or entry.name=="Rebirth" or entry.name=="Ancestral Spirit" then
        lines[#lines+1]="/cast "..(self.mouseover and "[@mouseover,help,dead][@target,help,dead] " or "[@target,help,dead] ")..spell
    elseif entry.kind == "friendly" then
        local target = self.mouseover and "[@mouseover,help,nodead][@target,help,nodead][@player]" or "[@target,help,nodead][@player]"
        lines[#lines + 1] = "/cast " .. target .. " " .. spell
    else
        local target = self.mouseover and self:CanMouseover(entry) and "[@mouseover,harm,nodead][harm,nodead] " or ""
        lines[#lines + 1] = "/cast " .. target .. spell
    end
    return table.concat(lines, "\n")
end

local classIcons = {
    Druid = "ClassIcon_Druid", Hunter = "ClassIcon_Hunter", Mage = "ClassIcon_Mage",
    Paladin = "ClassIcon_Paladin", Priest = "ClassIcon_Priest", Rogue = "ClassIcon_Rogue",
    Shaman = "ClassIcon_Shaman", Warlock = "ClassIcon_Warlock", Warrior = "ClassIcon_Warrior",
}
function MacroForge:AddLearnedEntries(entries,className)
    if className~=classKey() then return end
    local book=KT.modules.CustomKeybinds
    if not book then return end
    local ok,spells=pcall(book.LearnedSpells,book)
    if not ok or type(spells)~="table" then return end
    local known={};for _,entry in ipairs(entries) do known[entry.name]=entry end
    for _,spell in ipairs(spells) do
        if type(spell.name)=="string" then
            local rank=tonumber((spell.rank or ""):match("(%d+)")) or 1
            if not known[spell.name] then
                -- Unknown targeting stays a plain cast; never guess help/harm.
                local entry={name=spell.name,ranks=rank,class=className,category="class",liveIcon=spell.icon,kind="self",fromSpellbook=true}
                entries[#entries+1]=entry;known[spell.name]=entry
            else known[spell.name].ranks=math.max(known[spell.name].ranks or 1,rank);known[spell.name].liveIcon=spell.icon end
        end
    end
end
function MacroForge:AllEntries()
    local entries, playerClass, playerRace = {}, classKey(), raceKey()
    if self.filter == "class" then
        if self.browsedClass and classMacros[self.browsedClass] then
            addEntries(entries, classMacros[self.browsedClass], self.browsedClass, nil, "class")
        else
            local names = {}
            for name in pairs(classMacros) do names[#names + 1] = name end
            table.sort(names)
            for _, name in ipairs(names) do
                entries[#entries + 1] = {name = name, class = name, category = "classPicker", icon = classIcons[name]}
            end
        end
    elseif self.filter == "mine" then
        addEntries(entries, classMacros[playerClass], playerClass, nil, "class")
        addEntries(entries, racials[playerRace], nil, playerRace, "racial")
    elseif self.filter == "generic" then
        addEntries(entries, genericMacros, nil, nil, "generic")
    end
    if self.filter=="mine" or (self.filter=="class" and self.browsedClass==playerClass) then self:AddLearnedEntries(entries,playerClass) end
    for _,entry in ipairs(type(KT.db.customMacros)=="table" and KT.db.customMacros or {}) do
        if type(entry)=="table" and type(entry.name)=="string" and type(entry.code)=="string" and #entry.name>0 and #entry.name<=16 then
            if (self.filter=="mine" and entry.class==playerClass)
                or (self.filter=="class" and entry.class==self.browsedClass)
                or (self.filter=="generic" and not entry.class) then entries[#entries+1]=entry end
        end
    end
    return entries
end
function MacroForge:CreateCustom(name,forClass)
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    if name=="" or #name>16 then self:Status("Enter a macro name of 1–16 characters.",true);return end
    local class=forClass and classKey() or nil
    for _,entry in ipairs(type(KT.db.customMacros)=="table" and KT.db.customMacros or {}) do
        if entry.name==name and entry.class==class then self:Status("That custom macro name already exists here.",true);return end
    end
    local catalogue=class and classMacros[class] or genericMacros
    for _,entry in ipairs(catalogue or {}) do if entry[1]==name then self:Status("That name already belongs to a built-in macro.",true);return end end
    KT.db.customMacros=type(KT.db.customMacros)=="table" and KT.db.customMacros or {}
    local entry={name=name,code="#showtooltip",class=class,category="custom",icon="INV_Misc_Note_01",kind="custom"}
    KT.db.customMacros[#KT.db.customMacros+1]=entry
    self.filter=class and "mine" or "generic"
    self.newPanel:Hide();self:Select(entry);self:Status("Custom macro created. Add spells or edit its text, then choose where to save it.")
end
function MacroForge:RefreshNewPanel()
    KT:SetSelected(self.newGeneric,not self.newClass)
    KT:SetSelected(self.newClassButton,self.newClass==true)
end

function MacroForge:IconForEntry(entry)
    if entry.category == "classPicker" or entry.category == "generic" then return "Interface\\Icons\\" .. (entry.icon or "INV_MISC_QUESTIONMARK") end
    local texture
    if C_Spell and C_Spell.GetSpellTexture then texture = C_Spell.GetSpellTexture(entry.name)
    elseif GetSpellTexture then texture = GetSpellTexture(entry.name) end
    return texture or entry.liveIcon or (entry.icon and "Interface\\Icons\\" .. entry.icon) or 134400
end
function MacroForge:ClassIcon(className)
    return "Interface\\Icons\\" .. (classIcons[className] or "INV_Misc_QuestionMark")
end
function MacroForge:MacroName(entry)
    return (entry.class or entry.characterOnly) and " " or string.sub(entry.name, 1, 16)
end

local function normalizeBody(body) return (body or ""):gsub("\r\n", "\n"):gsub("\n+$", "") end
function MacroForge:EntryExists(entry, body)
    if entry.name=="1-shot combo" then
        local account,character=GetNumMacros()
        local scope=self.scope=="account" and "account" or "character"
        local first=scope=="account" and 1 or (MAX_ACCOUNT_MACROS or 120)+1
        local count=scope=="account" and account or character
        for index=first,first+count-1 do
            local name,_,existing=GetMacroInfo(index)
            if name==self:MacroName(entry) and existing and normalizeBody(existing)==normalizeBody(body) then return true,index end
        end
        return false
    end
    if not entry.class and not entry.characterOnly then return (GetMacroIndexByName(self:MacroName(entry)) or 0) > 0 end
    local _, count = GetNumMacros()
    for index = (MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + count do
        local _, _, existing = GetMacroInfo(index)
        if existing and normalizeBody(existing) == normalizeBody(body) then return true, index end
    end
    return false
end

function MacroForge:Status(message, isError)
    if self.statusHover and not self.bulkAdding then self.statusHover:Hide() end
    self.status:SetText(message)
    self.status:SetTextColor(isError and 1 or 0.46, isError and 0.42 or 1, isError and 0.42 or 0.76)
end

function MacroForge:ClassNames()
    local names = {}; for name in pairs(classMacros) do names[#names + 1] = name end
    table.sort(names); return names
end
function MacroForge:RaceEntries()
    local entries = {}; addEntries(entries, racials[raceKey()], nil, raceKey(), "racial"); return entries
end
function MacroForge:GenericEntries()
    local entries = {}; addEntries(entries, genericMacros, nil, nil, "generic"); return entries
end
function MacroForge:PlayerClass() return classKey() end
function MacroForge:BulkClass() return self.filter == "class" and self.browsedClass or classKey() end
function MacroForge:CreateEntry(entry, confirmed)
    if InCombatLockdown() then self:Status("Leave combat before adding or changing macros.", true); return false end
    if entry.class and entry.class ~= classKey() and not confirmed then
        local snapshot = {}
        for key, value in pairs(entry) do snapshot[key] = value end
        snapshot.code = self:BuildMacro(entry)
        self.pendingEntry = snapshot
        StaticPopupDialogs.FOREVERTOOLS_FOREIGN_SINGLE.text = "This is a " .. entry.class .. " macro, but you are a " .. classKey() .. ". Add it to Character macros anyway?"
        KT:ShowPopup("FOREVERTOOLS_FOREIGN_SINGLE")
        return false
    end
    local body = self:BuildMacro(entry)
    if #body > 255 then self.skipReason = "long"; self:Status("This macro is too long for WoW's 255-character limit.", true); return false end
    local name = self:MacroName(entry)
    local exists, existingIndex = self:EntryExists(entry, body)
    if exists then
        if entry.class and existingIndex then
            EditMacro(existingIndex, " ", 134400, body)
            self:Status(entry.name .. " already exists; blank name and automatic icon applied.")
        else self:Status(entry.name .. " already exists — skipped to protect it.", true) end
        self.skipReason = "exists"
        return false
    end
    local scope = (entry.class or entry.characterOnly) and "character" or self.scope
    local accountCount, characterCount = GetNumMacros()
    -- The client is authoritative. Some beta builds expose stale slot constants;
    -- do not reject a valid creation merely because a guessed limit was reached.
    local ok,macroIndex = pcall(CreateMacro,name,134400,body,scope=="character")
    if ok and type(macroIndex)=="number" and macroIndex>0 then
        local destination = scope == "character" and "Character" or "General"
        self:Status("Added " .. entry.name .. " to " .. destination .. " macros.")
        if not self.bulkAdding then KT:Toast("Added to " .. string.lower(destination) .. " macros") end
        return true
    end
    self.skipReason = "full"
    self:Status("WoW could not create that macro. Check space in the selected macro tab.", true)
    return false
end

-- Level each spell is learned at, from your own spellbook (it also lists
-- spells you have not learned yet). Spells you already know count as level 0.
function MacroForge:LearnLevels()
    local levels = {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo) then return levels end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell or 2
    local ok = pcall(function()
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and not info.offSpecID or (info and info.offSpecID == 0) then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    if item and type(item.name) == "string" then
                        local level = 0
                        if item.itemType == future then
                            level = C_SpellBook.GetSpellBookItemLevelLearned and C_SpellBook.GetSpellBookItemLevelLearned(slot, bank) or 99
                            if type(level) ~= "number" or (issecretvalue and issecretvalue(level)) then level = 99 end
                        end
                        if levels[item.name] == nil or level < levels[item.name] then levels[item.name] = level end
                    end
                end
            end
        end
    end)
    return ok and levels or {}
end
function MacroForge:BulkEntries(className)
    className = className or self:BulkClass()
    local entries = {}
    addEntries(entries, classMacros[className], className, nil, "class")
    self:AddLearnedEntries(entries,className)
    -- Your own class: spells you know first, then by the level you learn them,
    -- so running out of macro slots only affects spells for later levels.
    if className == classKey() then
        local levels = self:LearnLevels()
        if next(levels) then
            for i, entry in ipairs(entries) do
                entry.sortIndex = i
                entry.learnLevel = levels[entry.name]
            end
            table.sort(entries, function(a, b)
                local la, lb = a.learnLevel or 100, b.learnLevel or 100
                if la ~= lb then return la < lb end
                return a.sortIndex < b.sortIndex
            end)
        end
    end
    return entries
end

-- Names in a readable list: "A, B, C and 3 more".
local function nameList(names, limit)
    limit = limit or 12
    local shown = {}
    for i = 1, math.min(#names, limit) do shown[i] = names[i] end
    local text = table.concat(shown, ", ")
    if #names > limit then text = text .. " and " .. (#names - limit) .. " more" end
    return text
end
function MacroForge:CreateBulk(className)
    if InCombatLockdown() then self:Status("Leave combat before adding macros.", true); return end
    local entries = self:BulkEntries(className)
    local rank, mouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    local created = 0; self.bulkAdding = true
    local skipped = {exists = {}, full = {}, long = {}}
    for _, entry in ipairs(entries) do
        self.skipReason = nil
        if self:CreateEntry(entry, true) then created = created + 1
        else
            local list = skipped[self.skipReason or "full"] or skipped.full
            list[#list + 1] = entry.name .. ((entry.learnLevel or 0) > 0 and entry.learnLevel < 99 and (" (level " .. entry.learnLevel .. ")") or "")
        end
    end
    self.bulkAdding = nil; self.selectedRank, self.mouseover = rank, mouseover
    local total = #skipped.exists + #skipped.full + #skipped.long
    -- Keep the list so the status line can show it on hover.
    local lines = {}
    if #skipped.full > 0 then lines[#lines + 1] = "|cffff6b6bNo room:|r " .. nameList(skipped.full, 40) end
    if #skipped.exists > 0 then lines[#lines + 1] = "|cffffd100Already in your macros:|r " .. nameList(skipped.exists, 40) end
    if #skipped.long > 0 then lines[#lines + 1] = "|cffff6b6bToo long for WoW:|r " .. nameList(skipped.long, 40) end
    self.skippedText = total > 0 and table.concat(lines, "\n\n") or nil
    if total == 0 then
        self:Status(string.format("%d class macros added to Character.", created))
    else
        self:Status(string.format("%d class macros added to Character; %d skipped. Hover here to see which.", created, total), #skipped.full + #skipped.long > 0)
    end
    self.statusHover:SetShown(total > 0)
    if created > 0 then KT:Toast(string.format("Added %d character macros", created)) end
    self:UpdateBulkInfo()
end

local function sameEntry(a, b)
    return a and b and a.name == b.name and a.class == b.class and a.race == b.race
end

function MacroForge:UpdateFilters()
    for key, button in pairs(self.filterButtons) do KT:SetSelected(button, self.filter == key) end
    if self.browsedClass then self.lastBrowsedClass=self.browsedClass end
    self.filterButtons.class.icon:SetTexture(self:ClassIcon(self.browsedClass or self.lastBrowsedClass or classKey()))
end
function MacroForge:RenderList()
    if not self.uiReady then return end
    local query = string.lower(self.search:GetText() or "")
    for _, button in ipairs(self.rows) do button:Hide() end
    local shown = 0
    for _, entry in ipairs(self:AllEntries()) do
        local haystack = string.lower(entry.name .. " " .. (entry.class or "") .. " " .. (entry.race or "") .. " " .. entry.category)
        if query == "" or haystack:find(query, 1, true) then
            shown = shown + 1
            local button = self.rows[shown]
            if not button then
                button = KT:QuietButton(self.list, "", 300, 44)
                button.label:Hide()
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetSize(28, 28)
                button.icon:SetPoint("LEFT", 8, 0)
                button.title = KT:Label(button, "", 14)
                button.title:SetPoint("TOPLEFT", 44, -6)
                button.title:SetWidth(246)
                button.meta = KT:Label(button, "", 11)
                button.meta:SetPoint("TOPLEFT", 44, -25)
                button.meta:SetTextColor(0.70, 0.64, 0.80)
                button:SetScript("OnClick", function(owner)
                    if owner.entry.category == "classPicker" then
                        self.browsedClass = owner.entry.class
                        self:Select(self:AllEntries()[1])
                        self:Status("Browsing " .. self.browsedClass .. " macros. Click Classes to choose another class.")
                    else self:Select(owner.entry) end
                end)
                KT:Tooltip(button,"Macro template",function()
                    return button.entry and button.entry.name=="1-shot combo"
                        and "Build one macro that does several things. Pick learned spells below the text, and add trinkets or start attack with one click. Abilities off the global cooldown fire together; other spells may need another press."
                        or "Click to preview and edit this macro. Nothing changes in WoW until you add it."
                end)
                self.rows[shown] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 0, -(shown - 1) * 48)
            button.entry = entry
            button.icon:SetTexture(self:IconForEntry(entry))
            button.title:SetText(entry.name)
            button.meta:SetText(entry.category == "classPicker" and "View class macros" or entry.category=="custom" and (entry.class and "Custom • "..entry.class or "Custom • Generic") or entry.class or entry.race or "Generic")
            KT:SetSelected(button, sameEntry(entry, self.selectedMacro))
            button:Show()
        end
    end
    self.list:SetHeight(math.max(1, shown * 48))
    self.empty:SetShown(shown == 0)
    self.detail:SetShown(not (self.filter == "class" and not self.browsedClass))
    self:UpdateFilters()
    self:UpdateBulkInfo()
end
function MacroForge:Select(entry)
    KT:FlushMacroRevision(self.selectedMacro)
    self.selectedMacro, self.selectedRank, self.mouseover = entry, "max", false
    self.quickSpell=nil
    if self.spellChoice then
        self.spellChoice.value=nil;self.spellChoice.label:SetText("Choose learned spell")
        self.spellChoice.icon:SetTexture("Interface\\Icons\\"..KT.icons.macros)
    end
    if self.historyPanel then self.historyPanel:Hide() end
    if self.advancedPanel then self.advancedPanel:Hide() end
    local saved=KT:MacroRecord(entry).body; if type(saved)=="string" then self.mouseover=saved:find("@mouseover",1,true)~=nil end
    self:UpdatePreview()
    self:RenderList()
end
function MacroForge:UpdatePreview()
    local entry = self.selectedMacro
    if not entry then return end
    self.title:SetText(entry.name)
    self.rankLabel:SetText(entry.ranks and entry.ranks > 1 and (self.selectedRank == "max" and "Max rank" or "Rank " .. self.selectedRank) or "Single rank")
    local hasRanks = entry.ranks and entry.ranks > 1
    self.prevRank:SetShown(hasRanks); self.nextRank:SetShown(hasRanks); self.rankLabel:SetShown(hasRanks)
    local showMouseover = self:CanMouseover(entry)
    self.mouseoverButton:ClearAllPoints()
    if hasRanks then self.mouseoverButton:SetPoint("TOPRIGHT", self.detail, "TOPRIGHT", -16, -52)
    else self.mouseoverButton:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 16, -52) end
    local controls = hasRanks or showMouseover
    self.previewArea:ClearAllPoints(); self.previewArea:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 16, controls and -96 or -52)
    self.previewArea:SetHeight(controls and 100 or 144)
    self.prevRank:SetEnabled(hasRanks)
    self.nextRank:SetEnabled(entry.ranks and entry.ranks > 1)
    self.mouseoverButton:SetShown(showMouseover)
    self.mouseoverButton.label:SetText(self.mouseover and "Mouseover: On" or "Mouseover: Off")
    KT:SetSelected(self.mouseoverButton, self.mouseover)
    self.loadingPreview = true
    self.preview:SetText(KT:MacroBody(entry, self:BuildMacro(entry)))
    self.loadingPreview = false
    local forced = entry.class ~= nil or entry.characterOnly
    local effective = forced and "character" or self.scope
    self.accountScope:SetEnabled(not forced)
    self.accountScope:SetAlpha(forced and 0.35 or 1)
    KT:SetSelected(self.accountScope, effective == "account")
    KT:SetSelected(self.characterScope, effective == "character")
    self.scopeNote:SetText("Choose where to save macro.")
    self:UpdateDefaultButton()
end
function MacroForge:UpdateDefaultButton()
    if not self.defaultButton or not self.selectedMacro then return end
    local changed = (self.preview:GetText() or "") ~= self:BuildMacro(self.selectedMacro)
    self.defaultButton:SetEnabled(changed); self.defaultButton:SetAlpha(changed and 1 or 0.42)
end
function MacroForge:LearnedSpellChoices()
    local book=KT.modules.CustomKeybinds
    if not book or not book.LearnedSpells then return {} end
    local ok,spells=pcall(book.LearnedSpells,book)
    if not ok or type(spells)~="table" then return {} end
    local choices={}
    for _,spell in ipairs(spells) do
        if type(spell.name)=="string" and (not issecretvalue or not issecretvalue(spell.name)) then
            choices[#choices+1]={value=spell.value,label=spell.label or spell.name,icon=spell.icon,name=spell.name}
        end
    end
    return choices
end
function MacroForge:EditQuickLine(line)
    if not self.selectedMacro then return end
    local old=self.preview:GetText() or ""
    local rows,found={},false
    for row in (old.."\n"):gmatch("(.-)\n") do
        if row==line then found=true else rows[#rows+1]=row end
    end
    if not found then rows[#rows+1]=line end
    local body=table.concat(rows,"\n")
    if #body>255 then self:Status("Too long for a WoW macro (255 bytes).",true);return end
    self.preview:SetText(body)
    self:RefreshQuickButtons()
end
function MacroForge:AddQuickSpell()
    if not self.selectedMacro or not self.quickSpell then self:Status("Choose a learned spell first.",true);return end
    local choice
    for _,spell in ipairs(self:LearnedSpellChoices()) do if spell.value==self.quickSpell then choice=spell;break end end
    if not choice then self:Status("That spell is no longer learned.",true);return end
    local old=self.preview:GetText() or ""
    local line="/cast "..choice.label
    if old:find(line,1,true) then self:Status("That spell is already in the macro.");return end
    local body=old:gsub("%s+$","")
    if body=="#showtooltip" then body=body.." "..choice.label end
    body=body..(body~="" and "\n" or "")..line
    if #body>255 then self:Status("Too long for a WoW macro (255 bytes).",true);return end
    self.preview:SetText(body)
    self:Status("Added "..choice.name.." to this macro.")
end
function MacroForge:RefreshQuickButtons()
    if not self.quickButtons or not self.preview then return end
    local body="\n"..(self.preview:GetText() or "").."\n"
    for _,entry in ipairs(self.quickButtons) do
        KT:SetSelected(entry.button,body:find("\n"..entry.line.."\n",1,true)~=nil)
    end
end
function MacroForge:RenderHistory()
    if not self.historyPanel or not self.selectedMacro then return end
    local versions=KT:MacroRecord(self.selectedMacro).versions
    local pages=math.max(1,math.ceil(#versions/4))
    self.historyPage=math.max(1,math.min(pages,self.historyPage or 1))
    self.historyTitle:SetText("Saved versions: "..#versions)
    self.historyPageLabel:SetText(self.historyPage.." / "..pages)
    for row,button in ipairs(self.historyRows) do
        local index=#versions-(self.historyPage-1)*4-row+1
        local version=versions[index]
        button:SetShown(version~=nil);button.historyIndex=index
        if version then button.label:SetText("v"..index.."  "..date("%d %b %H:%M",version.time).."  "..version.kind) end
    end
end
function MacroForge:RestoreDefault()
    if not self.selectedMacro then return end
    KT:FlushMacroRevision(self.selectedMacro)
    local body = self:BuildMacro(self.selectedMacro)
    self.loadingPreview = true; self.preview:SetText(body); self.loadingPreview = false
    KT:StoreMacroBody(self.selectedMacro, body); KT:FlushMacroRevision(self.selectedMacro)
    self:UpdateDefaultButton()
end
function MacroForge:StepRank(delta)
    local maximum = self.selectedMacro and self.selectedMacro.ranks or 1
    if maximum <= 1 then return end
    local value = (self.selectedRank == "max" and maximum or tonumber(self.selectedRank)) + delta
    if value > maximum then value = 1 elseif value < 1 then value = maximum end
    self.selectedRank = value == maximum and "max" or tostring(value)
    KT:StoreMacroBody(self.selectedMacro, self:BuildMacro(self.selectedMacro))
    self:UpdatePreview()
end
function MacroForge:ChooseScope(scope)
    if self.selectedMacro and (self.selectedMacro.class or self.selectedMacro.characterOnly) then self:UpdatePreview(); return end
    self.scope = scope
    KT.db.macroScope = scope
    self:UpdatePreview()
end
function MacroForge:UpdateBulkInfo()
    local _, count = GetNumMacros()
    local free = math.max(0, (MAX_CHARACTER_MACROS or 30) - count)
    local needed = 0
    local oldRank, oldMouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    for _, entry in ipairs(self:BulkEntries()) do
        if not self:EntryExists(entry, self:BuildMacro(entry)) then needed = needed + 1 end
    end
    self.selectedRank, self.mouseover = oldRank, oldMouseover
    local className = self:BulkClass()
    local icon = classIcons[className] or "INV_Misc_QuestionMark"
    self.bulkStatus:SetText("|TInterface\\Icons\\" .. icon .. ":18:18|t " .. className .. " macros")
    self.bulkButton.label:SetText("Add all " .. className .. " macros")
    self.bulkButton.icon:SetTexture(self:ClassIcon(className))
    self.bulkMouseoverButton.label:SetText(self.bulkMouseover and "Mouseover: On" or "Mouseover: Off")
    KT:SetSelected(self.bulkMouseoverButton, self.bulkMouseover)
    self.bulkInfo:SetText(""); self.bulkInfo:Hide()
    return needed, free
end
function MacroForge:ConfirmBulk()
    local needed, free = self:UpdateBulkInfo()
    local className = self:BulkClass()
    local foreign = className ~= classKey()
    if needed <= free and not foreign then self:CreateBulk(className); return end
    self.pendingBulkClass = className
    local left = {}
    if needed > free then
        -- Name the macros that will not fit (the last ones in the list).
        local oldRank, oldMouseover = self.selectedRank, self.mouseover
        self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
        local new = {}
        for _, entry in ipairs(self:BulkEntries(className)) do
            if not self:EntryExists(entry, self:BuildMacro(entry)) then
                new[#new + 1] = entry.name .. ((entry.learnLevel or 0) > 0 and entry.learnLevel < 99 and (" (level " .. entry.learnLevel .. ")") or "")
            end
        end
        self.selectedRank, self.mouseover = oldRank, oldMouseover
        for i = free + 1, #new do left[#left + 1] = new[i] end
    end
    StaticPopupDialogs.FOREVERTOOLS_BULK.text = needed > free
        and string.format("Only %d of %d new %s macros fit in your Character macros. Spells you know are added first, then by the level you learn them.\n\nThese will not be added:\n%s\n\nMake room in Esc → Macros first, or add the ones that fit.", free, needed, className, nameList(left, 20))
        or string.format("Add all %s macros to Character macros?", className)
    if foreign then
        StaticPopupDialogs.FOREVERTOOLS_BULK.text = "WARNING: You are a " .. classKey() .. ", not a " .. className .. ".\n\n" .. StaticPopupDialogs.FOREVERTOOLS_BULK.text
    end
    KT:ShowPopup("FOREVERTOOLS_BULK")
end
function MacroForge:CreateUI()
    if self.uiReady then return end
    if self.frame then self.frame:Hide() end
    self.rows = {}
    local frame = KT:Window("ForeverToolsMacros", "ForeverTools | Macros", 880, 744)
    self.frame = frame
    local hint = KT:Label(frame, "", 14)
    hint:SetPoint("TOPLEFT", 24, -57)
    local bulkPanel = CreateFrame("Frame", nil, frame)
    bulkPanel:SetSize(832, 58); bulkPanel:SetPoint("TOPLEFT", 24, -82); KT:Panel(bulkPanel)
    self.bulkStatus = KT:Label(bulkPanel, "", 15, true); self.bulkStatus:SetPoint("LEFT", 14, 0); self.bulkStatus:SetWidth(160)
    self.bulkMouseoverButton = KT:QuietButton(bulkPanel, "", 180, 34, "mouseover")
    self.bulkMouseoverButton:SetPoint("LEFT", self.bulkStatus, "RIGHT", 8, 0)
    self.bulkMouseoverButton:SetScript("OnClick", function() self.bulkMouseover = not self.bulkMouseover; self:UpdateBulkInfo() end)
    KT:Tooltip(self.bulkMouseoverButton, "Bulk Mouseover", "Adds mouseover to every macro whose spell can use it, so it casts on the unit under your mouse. Tip: also turn on Mouseover Cast in the game's Combat settings.")
    self.bulkButton = KT:QuietButton(bulkPanel, "", 230, 34, "add")
    self.bulkButton:SetPoint("LEFT", self.bulkMouseoverButton, "RIGHT", 8, 0)
    self.bulkButton:SetScript("OnClick", function() self:ConfirmBulk() end)
    KT:Tooltip(self.bulkButton, "Add all class macros", "Add every macro for this class to your Character macros.")
    self.deleteButton = KT:QuietButton(bulkPanel, "Delete class macros", 200, 34, "delete")
    self.deleteButton:SetPoint("LEFT", self.bulkButton, "RIGHT", 8, 0)
    self.deleteButton:SetScript("OnClick", function() self:RequestDeleteClass() end)
    for _,button in ipairs({self.bulkMouseoverButton,self.bulkButton,self.deleteButton}) do
        if button.label.SetWordWrap then button.label:SetWordWrap(false) end
    end
    KT:Tooltip(self.deleteButton, "Delete character macros", "Delete this class's macros that you have not changed. General, racial and edited macros are kept.")
    self.bulkInfo = KT:Label(bulkPanel, "", 12)
    self.bulkInfo:SetPoint("TOPLEFT", 14, -53); self.bulkInfo:SetWidth(725); self.bulkInfo:Hide()
    self.filterButtons = {}
    local filters = {{"mine", "Character", "character"}, {"class", "Classes", "classes"}, {"generic", "Generic", "generic"}}
    for index, item in ipairs(filters) do
        local key = item[1]
        local button = KT:QuietButton(frame, item[2], 104, 28, item[3])
        button:SetPoint("TOPLEFT", 24 + (index - 1) * 110, -156)
        button:SetScript("OnClick", function() self.filter = key; if key == "class" then self.browsedClass = nil; self:Status("Choose a class to browse its macros.") end; self:RenderList() end)
        self.filterButtons[key] = button
        KT:Tooltip(button, item[2], key == "mine" and "Macros installed for this character." or (key == "class" and "Browse every class before adding its macros." or "Useful macros that are not class-specific."))
    end
    self.newButton=KT:QuietButton(frame,"New macro",160,28,"add");self.newButton:SetPoint("TOPLEFT",354,-156)
    self.newButton:SetScript("OnClick",function() self.newName:SetText("");self.newClass=false;self:RefreshNewPanel();self.newPanel:Show();if self.newName.SetFocus then self.newName:SetFocus() end end)
    KT:Tooltip(self.newButton,"New macro","Create your own macro in My class or Generic, then edit its text and add it to WoW.")
    self.search = CreateFrame("EditBox", nil, frame)
    self.search:SetSize(330, 28); self.search:SetPoint("TOPRIGHT", -24, -156)
    KT:Panel(self.search)
    self.search:SetAutoFocus(false); self.search:SetFont(KT.bodyFont, 14, "")
    self.search:SetTextInsets(10, 10, 0, 0)
    self.search:SetScript("OnTextChanged", function() self:RenderList() end)
    self.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.search.placeholder = KT:Label(self.search, "Search macros...", 14)
    self.search.placeholder:SetPoint("LEFT", 10, 0)
    self.search.placeholder:SetTextColor(0.54, 0.48, 0.64)
    self.search:SetScript("OnEditFocusGained", function() self.search.placeholder:Hide() end)
    self.search:SetScript("OnEditFocusLost", function() self.search.placeholder:SetShown(self.search:GetText() == "") end)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -198); scroll:SetSize(308, 482)
    self.list = CreateFrame("Frame", nil, scroll); self.list:SetWidth(300); scroll:SetScrollChild(self.list)
    self.empty = KT:Label(self.list, "No matching macros.", 14); self.empty:SetPoint("TOPLEFT", 6, -8)
    local detail = CreateFrame("Frame", nil, frame)
    self.detail = detail
    detail:SetSize(494, 482); detail:SetPoint("TOPRIGHT", -24, -198); KT:Panel(detail)
    self.title = KT:Label(detail, "", 18, true); self.title:SetPoint("TOPLEFT", 16, -16); self.title:SetWidth(462)
    local newPanel=CreateFrame("Frame",nil,frame);self.newPanel=newPanel
    newPanel:SetSize(420,250);newPanel:SetPoint("CENTER",frame,"CENTER");newPanel:SetFrameLevel(frame:GetFrameLevel()+40);newPanel:EnableMouse(true);KT:Panel(newPanel);newPanel:Hide()
    local newTitle=KT:Label(newPanel,"New macro",18,true);newTitle:SetPoint("TOPLEFT",16,-16)
    KT:AddClose(newPanel,nil,8)
    local nameHint=KT:Label(newPanel,"Name (up to 16 characters)",13);nameHint:SetPoint("TOPLEFT",18,-56)
    self.newName=CreateFrame("EditBox",nil,newPanel,"InputBoxTemplate");self.newName:SetSize(370,28);self.newName:SetPoint("TOPLEFT",25,-79)
    self.newName:SetFont(KT.bodyFont,14,"");self.newName:SetAutoFocus(false)
    self.newName:SetScript("OnEscapePressed",function() newPanel:Hide() end)
    self.newGeneric=KT:QuietButton(newPanel,"Generic",180,32,"generic");self.newGeneric:SetPoint("TOPLEFT",18,-122)
    self.newGeneric:SetScript("OnClick",function() self.newClass=false;self:RefreshNewPanel() end)
    self.newClassButton=KT:QuietButton(newPanel,"My class",180,32,"classes");self.newClassButton:SetPoint("LEFT",self.newGeneric,"RIGHT",16,0)
    self.newClassButton:SetScript("OnClick",function() self.newClass=true;self:RefreshNewPanel() end)
    KT:Tooltip(self.newClassButton,"My class","List the new macro with this character's class macros. It saves to Character macros in WoW.")
    KT:Tooltip(self.newGeneric,"Generic","List the new macro under Generic. Choose General or Character before saving it to WoW.")
    local createCustom=KT:AccentButton(newPanel,"Create macro",384,32,"add");createCustom:SetPoint("BOTTOM",0,20);self.createCustomButton=createCustom
    createCustom:SetScript("OnClick",function() self:CreateCustom(self.newName:GetText(),self.newClass) end)
    self.prevRank = KT:QuietButton(detail, "<", 28, 26); self.prevRank:SetPoint("TOPLEFT", 16, -52)
    self.prevRank:SetScript("OnClick", function() self:StepRank(-1) end)
    KT:Tooltip(self.prevRank, "Spell rank", "Pick a lower rank, for example to save mana.")
    self.rankLabel = KT:Label(detail, "", 14); self.rankLabel:SetPoint("LEFT", self.prevRank, "RIGHT", 8, 0); self.rankLabel:SetWidth(84); self.rankLabel:SetJustifyH("CENTER")
    self.nextRank = KT:QuietButton(detail, ">", 28, 26); self.nextRank:SetPoint("LEFT", self.rankLabel, "RIGHT", 8, 0)
    self.nextRank:SetScript("OnClick", function() self:StepRank(1) end)
    KT:Tooltip(self.nextRank, "Spell rank", "Pick a higher rank. Your highest rank is used by default.")
    self.mouseoverButton = KT:QuietButton(detail, "", 168, 26, "mouseover"); self.mouseoverButton:SetPoint("LEFT", self.nextRank, "RIGHT", 20, 0)
    self.mouseoverButton:SetScript("OnClick", function() self.mouseover = not self.mouseover; KT:StoreMacroBody(self.selectedMacro, self:BuildMacro(self.selectedMacro)); self:UpdatePreview() end)
    KT:Tooltip(self.mouseoverButton, "Mouseover", "Cast on the unit under your mouse, when the spell allows it.")
    self.previewArea = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    self.previewArea:SetSize(446, 100); self.previewArea:SetPoint("TOPLEFT", 16, -96)
    self.preview = CreateFrame("EditBox", nil, self.previewArea)
    self.preview:SetMultiLine(true); self.preview:SetAutoFocus(false)
    self.preview:SetFont(KT.bodyFont, 14, ""); self.preview:SetSize(438, 100)
    self.preview:SetTextInsets(6,6,6,6); KT:Panel(self.preview)
    self.previewArea:SetScrollChild(self.preview)
    self.preview:SetScript("OnTextChanged", function(box)
        local _, lines = box:GetText():gsub("\n", "")
        box:SetHeight(math.max(100, (lines + math.ceil(#box:GetText() / 60) + 1) * 17 + 12))
        if self.selectedMacro and not self.loadingPreview then
            KT:StoreMacroBody(self.selectedMacro, box:GetText())
            self:UpdateDefaultButton()
            self:RefreshQuickButtons()
        end
    end)
    self.preview:SetScript("OnEditFocusLost", function() KT:FlushMacroRevision(self.selectedMacro) end)
    self.preview:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.preview:SetScript("OnCursorChanged", function(_, x, y, width, height)
        local top = -y; local offset = self.previewArea:GetVerticalScroll()
        if top < offset then self.previewArea:SetVerticalScroll(math.max(0, top))
        elseif top + height > offset + self.previewArea:GetHeight() then self.previewArea:SetVerticalScroll(top + height - self.previewArea:GetHeight()) end
    end)
    self.spellChoice=KT:Dropdown(detail,328,function() return self:LearnedSpellChoices() end,function(value)
        self.quickSpell=value
        for _,spell in ipairs(self:LearnedSpellChoices()) do
            if spell.value==value then self.spellChoice.label:SetText(spell.label);self.spellChoice.icon:SetTexture(spell.icon or 134400);break end
        end
    end,"macros")
    self.spellChoice:SetPoint("TOPLEFT",16,-234);self.spellChoice.label:SetText("Choose learned spell")
    KT:Tooltip(self.spellChoice,"Learned spells","Pick a spell you have learned, then add it to the macro.")
    local addSpell=KT:QuietButton(detail,"Add spell",122,28,"add");addSpell:SetPoint("LEFT",self.spellChoice,"RIGHT",10,0)
    addSpell:SetScript("OnClick",function() self:AddQuickSpell() end)
    KT:Tooltip(addSpell,"Add learned spell","Add a /cast line for this spell to the macro.")
    self.advancedButton=KT:QuietButton(detail,"Advanced options",462,28,"generic");self.advancedButton:SetPoint("TOPLEFT",16,-269)
    self.advancedPanel=CreateFrame("Frame",nil,frame);self.advancedPanel:SetSize(462,232)
    self.advancedPanel:SetPoint("TOPLEFT",frame,"TOPRIGHT",8,-198)
    self.advancedPanel:SetFrameLevel(frame:GetFrameLevel()+20)
    self.advancedPanel:SetFrameStrata("DIALOG");self.advancedPanel:SetClampedToScreen(true)
    self.advancedPanel:SetMovable(true);self.advancedPanel:EnableMouse(true)
    self.advancedPanel:RegisterForDrag("LeftButton")
    self.advancedPanel:SetScript("OnDragStart",self.advancedPanel.StartMoving)
    self.advancedPanel:SetScript("OnDragStop",self.advancedPanel.StopMovingOrSizing)
    KT:Panel(self.advancedPanel);self.advancedPanel:Hide()
    self.advancedButton:SetScript("OnClick",function()
        if not self.advancedPanel:IsShown() then
            self.advancedPanel:ClearAllPoints()
            local right=frame.GetRight and frame:GetRight()
            local screen=UIParent.GetWidth and UIParent:GetWidth()
            if right and screen and screen-right<470 then
                self.advancedPanel:SetPoint("TOPRIGHT",frame,"TOPLEFT",-8,-198)
            else
                self.advancedPanel:SetPoint("TOPLEFT",frame,"TOPRIGHT",8,-198)
            end
        end
        self.advancedPanel:SetShown(not self.advancedPanel:IsShown())
    end)
    KT:Tooltip(self.advancedButton,"Advanced macro lines","Extra lines: stop casting, start attacking or use a trinket.")
    KT:AddClose(self.advancedPanel,nil,8)
    local advancedTitle=KT:Label(self.advancedPanel,"Add or remove macro actions",15,true);advancedTitle:SetPoint("TOPLEFT",12,-14)
    self.quickButtons={}
    for i,entry in ipairs({{"Stop cast","/stopcasting","Interface\\Icons\\Spell_Holy_Silence"},{"Start attack","/startattack","Interface\\Icons\\Ability_MeleeDamage"},{"Trinket 1","/use 13","Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket"},{"Trinket 2","/use 14","Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket"}}) do
        local line=entry[2];local button=KT:QuietButton(self.advancedPanel,entry[1],208,28,"generic")
        button.icon:SetTexture(entry[3])
        button:SetPoint("TOPLEFT",12+((i-1)%2)*226,-50-math.floor((i-1)/2)*36)
        button:SetScript("OnClick",function() self:EditQuickLine(line) end)
        KT:Tooltip(button,entry[1],"Add or remove this line in the macro. Trinket 1 and 2 use whatever trinkets you have equipped.")
        self.quickButtons[i]={button=button,line=line}
    end
    local slots={{1,"Head","HeadSlot","Head"},{2,"Neck","NeckSlot","Neck"},{3,"Shoulders","ShoulderSlot","Shoulder"},{4,"Shirt","ShirtSlot","Shirt"},{5,"Chest","ChestSlot","Chest"},{6,"Waist","WaistSlot","Waist"},{7,"Legs","LegsSlot","Legs"},{8,"Feet","FeetSlot","Feet"},{9,"Wrist","WristSlot","Wrists"},{10,"Hands","HandsSlot","Hands"},{11,"Ring 1","Finger0Slot","Finger"},{12,"Ring 2","Finger1Slot","Finger"},{13,"Trinket 1","Trinket0Slot","Trinket"},{14,"Trinket 2","Trinket1Slot","Trinket"},{15,"Back","BackSlot","Chest"},{16,"Main hand","MainHandSlot","MainHand"},{17,"Off hand","SecondaryHandSlot","SecondaryHand"},{18,"Ranged","RangedSlot","Ranged"},{19,"Tabard","TabardSlot","Tabard"}}
    local function slotIcon(slot)
        local native=(C_PaperDollInfo and C_PaperDollInfo.GetInventorySlotInfo) or GetInventorySlotInfo
        local placeholder="Interface\\PaperDoll\\UI-PaperDoll-Slot-"..slot[4]
        if native then
            local ok,_,texture=pcall(native,slot[3])
            if ok and texture and (not issecretvalue or not issecretvalue(texture)) then placeholder=texture end
        end
        if GetInventoryItemTexture then
            local ok,texture=pcall(GetInventoryItemTexture,"player",slot[1])
            if ok and texture and (not issecretvalue or not issecretvalue(texture)) then return texture end
        end
        return placeholder
    end
    self.slotChoice=KT:Dropdown(self.advancedPanel,294,function() local list={};for _,slot in ipairs(slots) do list[#list+1]={value=slot[1],label=slot[2].." — slot "..slot[1],icon=slotIcon(slot)} end;return list end,function(value)
        self.quickSlot=value;for _,slot in ipairs(slots) do if slot[1]==value then self.slotChoice.label:SetText(slot[2].." — slot "..value);self.slotChoice.icon:SetTexture(slotIcon(slot));break end end
    end,"generic")
    self.slotChoice:SetPoint("TOPLEFT",12,-130);self.slotChoice.label:SetText("Choose equipment slot")
    local addSlot=KT:QuietButton(self.advancedPanel,"Toggle /use",140,28,"add");addSlot:SetPoint("LEFT",self.slotChoice,"RIGHT",8,0);self.addSlotButton=addSlot
    addSlot:SetScript("OnClick",function() if self.quickSlot then self:EditQuickLine("/use "..self.quickSlot) else self:Status("Choose an equipment slot first.",true) end end)
    KT:Tooltip(addSlot,"Use equipped item","Add or remove a /use line for this gear slot. Only items with a Use effect do anything.")
    local slotHint=KT:Label(self.advancedPanel,"Example: slot 13 is Trinket 1; slot 6 is Waist.",12);slotHint:SetPoint("TOPLEFT",14,-170)
    self.defaultButton = KT:QuietButton(detail, "Default", 462, 28, "reset")
    self.defaultButton:SetPoint("TOPLEFT",16,-305)
    self.defaultButton:SetScript("OnClick", function() KT:Confirm("Restore the original macro text? Your current edit will be replaced.",function() self:RestoreDefault() end) end)
    KT:Tooltip(self.defaultButton, "Restore default", "Go back to this macro's original text. Asks first.")
    self.scopeNote = KT:Label(detail, "", 13); self.scopeNote:SetPoint("BOTTOMLEFT", 16, 119); self.scopeNote:SetWidth(462)
    self.accountScope = KT:QuietButton(detail, "General macros", 226, 28, "general"); self.accountScope:SetPoint("BOTTOMLEFT", 16, 83)
    self.accountScope:SetScript("OnClick", function() self:ChooseScope("account") end)
    if self.accountScope.SetMotionScriptsWhileDisabled then self.accountScope:SetMotionScriptsWhileDisabled(true) end
    KT:Tooltip(self.accountScope, "General macros", function()
        return self.selectedMacro and (self.selectedMacro.class or self.selectedMacro.characterOnly)
            and "This macro uses class or racial spells, so it belongs in the Character tab."
            or "Save this macro to the General tab, shared by all your characters."
    end)
    self.characterScope = KT:QuietButton(detail, "Character macros", 226, 28, "character"); self.characterScope:SetPoint("LEFT", self.accountScope, "RIGHT", 10, 0)
    self.characterScope:SetScript("OnClick", function() self:ChooseScope("character") end)
    KT:Tooltip(self.characterScope, "Character macros", "Save this macro to this character's own tab.")
    local add = KT:AccentButton(detail, "Add selected macro", 462, 32, "add"); add:SetPoint("BOTTOM", 0, 7)
    add:SetScript("OnClick", function() if self.selectedMacro then KT.modules.MacroEditor:InstallEntry(self.selectedMacro, self:BuildMacro(self.selectedMacro)) end end)
    KT:Tooltip(add, "Add selected macro", "Add the macro to the chosen tab. If it is already there, you can choose to replace it.")
    self.status = KT:Label(frame, "", 14); self.status:SetPoint("BOTTOMLEFT", 24, 20); self.status:SetWidth(830)
    -- Hover area over the status line: lists skipped macros after "Add all".
    self.statusHover = CreateFrame("Frame", nil, frame); self.statusHover:SetAllPoints(self.status); self.statusHover:EnableMouse(true); self.statusHover:Hide()
    self.statusHover:SetScript("OnEnter", function(owner)
        if not self.skippedText then return end
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText("Skipped macros", 0.79, 0.63, 1)
        GameTooltip:AddLine(self.skippedText, 0.91, 0.88, 0.96, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Make room in your Character macros (Esc → Macros), then use Add all again. Macros you already have are never added twice.", 0.66, 0.57, 0.77, true)
        GameTooltip:Show()
    end)
    self.statusHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    StaticPopupDialogs.FOREVERTOOLS_BULK = { text = "", button1 = "Add class macros", button2 = "Cancel", OnAccept = function() local chosen = self.pendingBulkClass; self.pendingBulkClass = nil; if chosen then self:CreateBulk(chosen) end end, OnCancel = function() self.pendingBulkClass = nil end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
    frame:HookScript("OnHide", function() KT:FlushMacroRevision(self.selectedMacro) end)
    self.scope = KT.db.macroScope == "account" and "account" or "character"
    StaticPopupDialogs.FOREVERTOOLS_FOREIGN_SINGLE = {text = "", button1 = "Add anyway", button2 = "Cancel", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() local entry = self.pendingEntry; self.pendingEntry = nil; if entry then self:CreateEntry(entry, true); self:UpdateBulkInfo() end end,
        OnCancel = function() self.pendingEntry = nil end}
    self:SetupDeleteDialogs()
    self.uiReady = true
end
function MacroForge:Open()
    self:CreateUI()
    self.search:SetText("")
    if not self.selectedMacro then self:Select(self:AllEntries()[1]) end
    self:RenderList(); self:UpdatePreview(); self:UpdateBulkInfo()
    self:Status("Select a macro to preview it, or use Add all " .. classKey() .. " macros above.")
    self.frame:Show()
end
KT:RegisterModule("MacroForge", MacroForge)


local spellsChanged=CreateFrame("Frame")
spellsChanged:RegisterEvent("SPELLS_CHANGED")
spellsChanged:SetScript("OnEvent",function()
    if KT.dbReady and MacroForge.frame and MacroForge.frame:IsShown() and not InCombatLockdown() then
        MacroForge:RenderList();MacroForge:UpdateBulkInfo()
    end
end)
