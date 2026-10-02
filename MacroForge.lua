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
        {"Sinister Strike", 9, "startattack", "spell_shadow_ritualofsacrifice"}, {"Backstab", 9, "startattack", "ability_backstab"}, {"Eviscerate", 9, "startattack", "ability_rogue_eviscerate"}, {"Kick", 1, "startattack", "ability_kick"}, {"Gouge", 5, nil, "ability_gouge"}, {"Sap", 3, nil, "ability_sap"}, {"Blind", 1, nil, "spell_shadow_mindsteal"}, {"Vanish", 3, "self", "ability_vanish"}, {"Garrote", 6, nil, "ability_rogue_garrote"}, {"Rupture", 6, "startattack", "ability_rogue_rupture"}, {"Ambush", 6, nil, "ability_rogue_ambush"}, {"Cheap Shot", 1, nil, "ability_cheapshot"}, {"Kidney Shot", 2, "startattack", "ability_rogue_kidneyshot"}, {"Stealth", 4, "self", "ability_stealth"}, {"Sprint", 3, "self", "ability_rogue_sprint"}, {"Evasion", 1, "self", "spell_shadow_shadowward"},
    },
    Shaman = {
        {"Lightning Bolt", 10, nil, "spell_nature_lightning"}, {"Chain Lightning", 6, nil, "spell_nature_chainlightning"}, {"Earth Shock", 7, nil, "spell_nature_earthshock"}, {"Flame Shock", 6, nil, "spell_fire_flameshock"}, {"Frost Shock", 7, nil, "spell_frost_frostshock"}, {"Healing Wave", 10, "friendly", "spell_nature_magicimmunity"}, {"Lesser Healing Wave", 6, "friendly", "spell_nature_healingwavelesser"}, {"Purge", 2, nil, "spell_nature_purge"}, {"Chain Heal", 3, "friendly", "spell_nature_healingwavegreater"}, {"Ghost Wolf", 1, "self", "spell_nature_spiritwolf"}, {"Lightning Shield", 7, "self", "spell_nature_lightningshield"}, {"Windfury Weapon", 3, "self", "spell_nature_cyclone"}, {"Stormstrike", 1, "startattack", "ability_shaman_stormstrike"},
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
    {"Party GZ", 1, "generic", "inv_misc_rabbit", "#showtooltip GZ\n/P GZ!!!\n/P (\\ /)\n/P (^_^)\n/p (*(\")(\")", "#showtooltip\n/P GZ!!!\n/P (\\ /)\n/P (^_^)\n/p (*(\")(\")"},
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
        destination[#destination + 1] = { name = data[1], ranks = data[2], kind = data[3], icon = data[4], code = data[5], old = data[6], class = className, race = raceName, category = category }
    end
end

local noUnitTarget = {
    ["Consecration"] = true, ["Freezing Trap"] = true, ["Frost Nova"] = true,
    ["Psychic Scream"] = true, ["Howl of Terror"] = true, ["Thunder Clap"] = true,
    ["War Stomp"] = true, ["Swipe"] = true, ["Whirlwind"] = true,
    -- Queued next-swing attacks use the current melee target, not a mouseover unit.
    ["Heroic Strike"] = true, ["Cleave"] = true, ["Maul"] = true, ["Raptor Strike"] = true,
}
-- Melee abilities that may appear later from the spellbook (talents, higher
-- levels). Like the class templates, they start auto attack by default.
-- Stealth openers and CC that damage would break never do.
local learnedMelee = {
    ["Stormstrike"] = true, ["Crusader Strike"] = true, ["Riposte"] = true, ["Ghostly Strike"] = true,
    ["Hemorrhage"] = true, ["Shield Slam"] = true, ["Whirlwind"] = true, ["Mangle"] = true,
    ["Lacerate"] = true, ["Counterattack"] = true, ["Devastate"] = true,
}
-- Pressing these again while stealthed would drop stealth; the macro only
-- enters stealth, it never leaves it by accident.
local stealthOnly = { ["Stealth"] = true, ["Prowl"] = true }
-- Mouseover audit (see SPELL_AUDIT.md). Every spell you cast at a unit can
-- use mouseover: hit an enemy beside you while keeping your target, heal or
-- dispel a party member, dot or crowd-control an add. Left out: melee strikes
-- that start auto attack (auto attack stays on your target and combo points
-- would land on the wrong enemy), apart from the ones meant for a second
-- enemy below; Auto Shot (a toggle); self buffs, ground effects, next-swing
-- attacks.
local mainTarget = { ["Auto Shot"] = true }
-- Melee abilities that are aimed at a second enemy: interrupts, taunts,
-- stuns, and debuffs you spread on adds.
local meleeMouseover = {
    ["Kick"] = true, ["Pummel"] = true, ["Shield Bash"] = true, ["Taunt"] = true, ["Growl"] = true,
    ["Mocking Blow"] = true, ["Hammer of Justice"] = true, ["Bash"] = true, ["Sunder Armor"] = true,
    ["Rend"] = true, ["Hamstring"] = true, ["Wing Clip"] = true, ["Disarm"] = true,
}
function MacroForge:CanMouseover(entry)
    if not entry or entry.category == "generic" or entry.code or entry.kind == "self" or noUnitTarget[entry.name] then return false end
    if mainTarget[entry.name] then return false end
    if entry.kind == "startattack" then return meleeMouseover[entry.name] == true end
    return true
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
    elseif stealthOnly[entry.name] then
        lines[#lines + 1] = "/cast [nostealth] " .. spell
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
-- Spells that "Add all class macros" never adds (utility, tracking and
-- teleports). They still appear in the list and can be added one by one.
local bulkExcluded = {
    Druid = {"Nature's Grasp", "Teleport: Moonglade"},
    Hunter = {"Track Beasts", "Track Undead"},
    Mage = {"Teleport: Ironforge", "Teleport: Orgrimmar", "Teleport: Stormwind", "Teleport: Undercity"},
    Paladin = {"Sense Undead"},
    Priest = {"Confounding Flash", "Hex of Weakness", "Fade", "Touch of Weakness", "Elune's Grace", "Shadowguard"},
}
local excludedSet = {}
for class, names in pairs(bulkExcluded) do
    excludedSet[class] = {}
    for _, name in ipairs(names) do excludedSet[class][name] = true end
end
function MacroForge:IsBulkExcluded(className, name)
    return excludedSet[className] and excludedSet[className][name] == true
end
function MacroForge:AddLearnedEntries(entries,className,includeGeneral)
    if className~=classKey() then return end
    local book=KT.modules.CustomKeybinds
    if not book then return end
    local ok,spells=pcall(book.LearnedSpells,book)
    if not ok or type(spells)~="table" then return end
    local known={};for _,entry in ipairs(entries) do known[entry.name]=entry end
    for _,spell in ipairs(spells) do
        -- The first spellbook line is General (Attack, racials, professions);
        -- those are not class spells and are only listed for clean-up.
        if type(spell.name)=="string" and (includeGeneral or spell.line~=1) then
            local rank=tonumber((spell.rank or ""):match("(%d+)")) or 1
            if not known[spell.name] then
                -- Unknown targeting stays a plain cast; never guess help/harm.
                local entry={name=spell.name,ranks=rank,class=className,category="class",liveIcon=spell.icon,kind=learnedMelee[spell.name] and "startattack" or "self",fromSpellbook=true}
                entries[#entries+1]=entry;known[spell.name]=entry
            else known[spell.name].ranks=math.max(known[spell.name].ranks or 1,rank);known[spell.name].liveIcon=spell.icon end
        end
    end
end
-- The list only changes with the filter, the browsed class, the spellbook or
-- your custom macros, so typing in the search box reuses it.
function MacroForge:AllEntries()
    local book = KT.modules.CustomKeybinds
    local custom = KT.db.customMacros
    local spells = book and book.LearnedSpells and select(2, pcall(book.LearnedSpells, book))
    local key = tostring(self.filter) .. "|" .. tostring(self.browsedClass) .. "|" .. tostring(spells) .. "|" .. tostring(custom) .. "|" .. (type(custom) == "table" and #custom or 0)
    if self.entriesKey == key and self.entriesCache then return self.entriesCache end
    local entries = self:BuildEntries()
    self.entriesKey, self.entriesCache = key, entries
    return entries
end
function MacroForge:BuildEntries()
    local entries, playerClass, playerRace = {}, classKey(), raceKey()
    -- Your own macros come first, newest on top, so a new one is easy to find.
    local customs=type(KT.db.customMacros)=="table" and KT.db.customMacros or {}
    for i=#customs,1,-1 do
        local entry=customs[i]
        if type(entry)=="table" and type(entry.name)=="string" and type(entry.code)=="string" and #entry.name>0 and #entry.name<=16 then
            if (self.filter=="mine" and entry.class==playerClass)
                or (self.filter=="class" and entry.class==self.browsedClass)
                or (self.filter=="generic" and not entry.class) then entries[#entries+1]=entry end
        end
    end
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
    self.browsedClass=nil; self.showHidden=false
    self.newPanel:Hide();self:Select(entry)
    if self.listScroll and self.listScroll.SetVerticalScroll then self.listScroll:SetVerticalScroll(0) end
    self:Status("Macro created at the top of the list. Add spells or edit its text, then click Add selected macro.")
end
function MacroForge:RefreshNewPanel()
    KT:SetSelected(self.newGeneric,not self.newClass)
    KT:SetSelected(self.newClassButton,self.newClass==true)
end

-- Icon name -> the game's file ID, or nil when the game has no such icon.
-- Macros need the file ID (a path makes an invisible icon), and checking
-- means a wrong name can never show as an empty square.
local iconIDs = {}
local function iconFile(name)
    if type(name) ~= "string" or name == "" or not GetFileIDFromPath then return nil end
    local key = name:lower()
    if iconIDs[key] == nil then
        local ok, id = pcall(GetFileIDFromPath, "Interface\\Icons\\" .. name)
        iconIDs[key] = ok and type(id) == "number" and id > 0 and id or false
    end
    return iconIDs[key] or nil
end
function MacroForge:IconForEntry(entry)
    if entry.category == "classPicker" or entry.category == "generic" then return "Interface\\Icons\\" .. (entry.icon or "INV_MISC_QUESTIONMARK") end
    local texture
    if C_Spell and C_Spell.GetSpellTexture then texture = C_Spell.GetSpellTexture(entry.name)
    elseif GetSpellTexture then texture = GetSpellTexture(entry.name) end
    return texture or entry.liveIcon or (self.futureIcons and self.futureIcons[entry.name]) or iconFile(entry.icon) or 134400
end
function MacroForge:ClassIcon(className)
    return "Interface\\Icons\\" .. (classIcons[className] or "INV_Misc_QuestionMark")
end
function MacroForge:MacroName(entry)
    return (entry.class or entry.characterOnly) and " " or string.sub(entry.name, 1, 16)
end

local function normalizeBody(body) return (body or ""):gsub("\r\n", "\n"):gsub("\n+$", "") end
-- Other default texts a Character macro may still have for this template:
-- the other mouseover setting, the pre-0.14.4 mouseover rule (every hostile
-- spell) and the pre-0.14.4 auto attack / stealth texts. Such a macro counts
-- as this macro, so Add all updates it in place instead of adding a copy.
-- Macros the player changed never match and are never touched.
local changedTemplates = {
    ["Cheap Shot"] = true, ["Ambush"] = true, ["Garrote"] = true, ["Gouge"] = true,
    ["Claw"] = true, ["Growl"] = true, ["Taunt"] = true, ["Victory Rush"] = true,
    ["Expose Armor"] = true, ["Stealth"] = true, ["Prowl"] = true,
}
local oldHostile = "[@mouseover,harm,nodead][harm,nodead] "
function MacroForge:LegacyBodies(entry, body)
    -- A built-in text macro whose text changed: its previous text still counts as ours.
    if entry and entry.code and entry.old then return {entry.old} end
    if type(body) ~= "string" or not entry or entry.code then return {} end
    local bases = {body}
    -- The same macro with mouseover switched the other way.
    local mouseover = self.mouseover
    self.mouseover = not mouseover
    local ok, other = pcall(self.BuildMacro, self, entry)
    self.mouseover = mouseover
    if ok and other and other ~= body then bases[#bases + 1] = other end
    -- Old rule: every hostile spell got mouseover.
    if entry.kind ~= "self" and entry.kind ~= "friendly" and not noUnitTarget[entry.name] and not body:find("@mouseover", 1, true) then
        local plain = body:gsub("\n/cast ", "\n/cast " .. oldHostile, 1)
        if plain ~= body then bases[#bases + 1] = plain end
    end
    local list = {}
    for i = 2, #bases do list[#list + 1] = bases[i] end
    if changedTemplates[entry.name] then
        for _, base in ipairs(bases) do
            if base:find("\n/startattack\n", 1, true) then list[#list + 1] = (base:gsub("\n/startattack\n", "\n", 1))
            else
                local head, rest = base:match("^(#showtooltip[^\n]*)\n(.*)$")
                if head then list[#list + 1] = head .. "\n/startattack\n" .. rest end
            end
            if base:find("[nostealth] ", 1, true) then list[#list + 1] = (base:gsub("%[nostealth%] ", "", 1)) end
        end
    end
    return list
end
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
    local wanted = normalizeBody(body)
    local legacy = {}
    for _, old in ipairs(self:LegacyBodies(entry, body)) do legacy[normalizeBody(old)] = true end
    local legacyIndex
    for index = (MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + count do
        local _, _, existing = GetMacroInfo(index)
        if existing then
            local text = normalizeBody(existing)
            if text == wanted then return true, index end
            if legacy[text] and not legacyIndex then legacyIndex = index end
        end
    end
    if legacyIndex then return true, legacyIndex end
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
    local icon = self:MacroIcon(entry)
    if #body > 255 then self.skipReason = "long"; self:Status("This macro is too long for WoW's 255-character limit.", true); return false end
    local name = self:MacroName(entry)
    local exists, existingIndex = self:EntryExists(entry, body)
    if exists then
        if entry.class and existingIndex then
            EditMacro(existingIndex, " ", icon, body)
            self:Status(entry.name .. " already exists; blank name and automatic icon applied.")
        else self:Status(entry.name .. " already exists — skipped to protect it.", true) end
        self.skipReason = "exists"
        return false
    end
    local scope = (entry.class or entry.characterOnly) and "character" or self.scope
    local accountCount, characterCount = GetNumMacros()
    -- The client is authoritative. Some beta builds expose stale slot constants;
    -- do not reject a valid creation merely because a guessed limit was reached.
    local ok,macroIndex = pcall(CreateMacro,name,icon,body,scope=="character")
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

-- Macro icon. Normally the question mark, so WoW shows the spell's own icon
-- (#showtooltip). With "Icons for unlearned spells" on, a spell you have not
-- learned yet gets its real icon right away (from your spellbook's upcoming
-- spells, or the template), so bars can be set up from level 1.
function MacroForge:MacroIcon(entry)
    if KT.db.macroUnlearnedIcons ~= true or not entry.class then return 134400 end
    local book = KT.modules.CustomKeybinds
    local ok, spells = pcall(book.LearnedSpells, book)
    if ok and type(spells) == "table" then
        for _, spell in ipairs(spells) do if spell.name == entry.name then return 134400 end end
    end
    -- One spellbook scan per spellbook change, not one per macro.
    if self.futureFor ~= spells or not self.futureIcons then self:LearnLevels(); self.futureFor = spells end
    local future = self.futureIcons and self.futureIcons[entry.name]
    if type(future) == "number" then return future end
    return iconFile(entry.icon) or 134400
end
-- Level each spell is learned at, from your own spellbook (it also lists
-- spells you have not learned yet). Spells you already know count as level 0.
function MacroForge:LearnLevels()
    local levels, icons = {}, {}
    self.futureIcons = icons
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
                            if item.iconID and not (issecretvalue and issecretvalue(item.iconID)) then icons[item.name] = item.iconID end
                            level = C_SpellBook.GetSpellBookItemLevelLearned and C_SpellBook.GetSpellBookItemLevelLearned(slot, bank) or 99
                            if type(level) ~= "number" or (issecretvalue and issecretvalue(level)) then level = 99 end
                        end
                        if levels[item.name] == nil or level < levels[item.name] then levels[item.name] = level end
                    end
                end
            end
        end
    end)
    -- Talent spells (Stormstrike and the like) are not in the spellbook until
    -- learned; the talent list has their icons.
    if type(GetNumTalentTabs) == "function" and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function" then
        pcall(function()
            for tab = 1, math.min(GetNumTalentTabs() or 0, 4) do
                for index = 1, math.min(GetNumTalents(tab) or 0, 60) do
                    local name, icon = GetTalentInfo(tab, index)
                    if type(name) == "string" and not (issecretvalue and (issecretvalue(name) or issecretvalue(icon))) and icons[name] == nil then
                        if type(icon) == "number" then icons[name] = icon
                        elseif type(icon) == "string" and GetFileIDFromPath then
                            local id = GetFileIDFromPath(icon); if type(id) == "number" and id > 0 then icons[name] = id end
                        end
                    end
                end
            end
        end)
    end
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
-- Macros the player hid from the list (per account). Hidden macros are
-- also never added by Add all; the Hidden filter shows them again.
function MacroForge:HiddenKey(entry) return (entry.class or entry.race or "Generic") .. "|" .. entry.name end
-- A stored value of true means hidden, "deleted" means deleted; both live
-- in the Hidden view and can be brought back from there.
function MacroForge:HiddenState(entry)
    local value = type(KT.db.hiddenMacros) == "table" and KT.db.hiddenMacros[self:HiddenKey(entry)]
    if value == "deleted" then return "deleted" end
    return value and "hidden" or nil
end
function MacroForge:IsHidden(entry) return self:HiddenState(entry) ~= nil end
function MacroForge:SetHidden(entry, hidden, deleted)
    if type(KT.db.hiddenMacros) ~= "table" then KT.db.hiddenMacros = {} end
    KT.db.hiddenMacros[self:HiddenKey(entry)] = hidden and (deleted and "deleted" or true) or nil
    local count = 0; for _ in pairs(KT.db.hiddenMacros) do count = count + 1 end
    if count == 0 then self.showHidden = false end
    self:RenderList()
    if hidden then KT:Toast(entry.name .. (deleted and " deleted." or " hidden.") .. " Open Hidden to bring it back.", 3)
    else KT:Toast(entry.name .. " is back in the list.", 2) end
end
-- The X on a row. In the list it moves the macro to Hidden as deleted (it
-- can come back). In the Hidden view, a macro you made yourself is removed
-- for good, after asking.
function MacroForge:DeleteEntry(entry)
    if not entry then return end
    if not (self.showHidden and entry.category == "custom") then self:SetHidden(entry, true, true); return end
    KT:Confirm("Delete your macro \"" .. entry.name .. "\" for good? This cannot be undone.", function()
        local list = type(KT.db.customMacros) == "table" and KT.db.customMacros or {}
        for index = #list, 1, -1 do if list[index] == entry then table.remove(list, index) end end
        if type(KT.db.hiddenMacros) == "table" then KT.db.hiddenMacros[self:HiddenKey(entry)] = nil end
        if type(KT.db.macroHistory) == "table" then KT.db.macroHistory[KT:MacroKey(entry)] = nil end
        if type(KT.db.macroMouseover) == "table" then KT.db.macroMouseover[KT:MacroKey(entry)] = nil end
        self.entriesCache, self.entriesKey = nil, nil
        if self:HiddenCount() == 0 then self.showHidden = false end
        if self.selectedMacro == entry then self.selectedMacro = nil; self:Select(self:AllEntries()[1])
        else self:RenderList() end
        KT:Toast(entry.name .. " deleted.", 2)
    end)
end
-- Everything hidden or deleted, wherever it came from: this character's
-- list, Generic and the other classes' lists. Hidden ones first.
function MacroForge:HiddenEntries()
    local filter, browsed = self.filter, self.browsedClass
    local seen, hidden, deleted = {}, {}, {}
    local function collect()
        for _, entry in ipairs(self:BuildEntries()) do
            if entry.category ~= "classPicker" then
                local key, state = self:HiddenKey(entry), self:HiddenState(entry)
                if state and not seen[key] then
                    seen[key] = true
                    local list = state == "deleted" and deleted or hidden
                    list[#list + 1] = entry
                end
            end
        end
    end
    self.filter, self.browsedClass = "mine", nil; collect()
    self.filter = "generic"; collect()
    for _, name in ipairs(self:ClassNames()) do
        if name ~= classKey() then self.filter, self.browsedClass = "class", name; collect() end
    end
    self.filter, self.browsedClass = filter, browsed
    return hidden, deleted
end
function MacroForge:HiddenCount()
    local count = 0; for _ in pairs(type(KT.db.hiddenMacros) == "table" and KT.db.hiddenMacros or {}) do count = count + 1 end
    return count
end
function MacroForge:AddableEntries(className)
    className = className or self:BulkClass()
    local list = {}
    for _, entry in ipairs(self:BulkEntries(className)) do
        if not self:IsBulkExcluded(className, entry.name) and not self:IsHidden(entry) then list[#list + 1] = entry end
    end
    return list
end
-- Mouseover for one macro: your own choice for it (the Mouseover button on
-- that macro), otherwise the Bulk Mouseover setting.
function MacroForge:EntryMouseover(entry)
    if type(KT.db.macroMouseover) == "table" then
        local key = KT:MacroKey(entry)
        local own = KT.db.macroMouseover[key]
        -- An exception equal to the row setting is no exception: forget it.
        if own == (self.bulkMouseover == true) then KT.db.macroMouseover[key] = nil
        elseif type(own) == "boolean" then return own end
    end
    return self.bulkMouseover == true
end
function MacroForge:CreateBulk(className, chosen)
    if InCombatLockdown() then self:Status("Leave combat before adding macros.", true); return end
    local entries = chosen or self:AddableEntries(className)
    local rank, mouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    local created = 0; self.bulkAdding = true
    local skipped = {exists = {}, full = {}, long = {}}
    for _, entry in ipairs(entries) do
        self.skipReason = nil
        self.mouseover = self:EntryMouseover(entry)
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
    local previewing = self.filter == "class" and self.browsedClass
    -- The Hidden view is its own list: neither Character nor Generic is lit.
    local listing = not self.showHidden
    KT:SetSelected(self.filterButtons.mine, listing and (self.filter == "mine" or previewing ~= nil and previewing ~= false))
    KT:SetSelected(self.filterButtons.generic, listing and self.filter == "generic")
    -- The Character button names the class you are looking at.
    self.filterButtons.mine.label:SetText(previewing and (previewing .. " (preview)") or "Character")
    self.filterButtons.mine.icon:SetTexture(self:ClassIcon(previewing or classKey()))
end
function MacroForge:RenderList()
    if not self.uiReady then return end
    if self.filter == "class" and not self.browsedClass then self.filter = "mine" end
    local query = string.lower(self.search:GetText() or "")
    for _, button in ipairs(self.rows) do button:Hide() end
    local shown = 0
    local function matches(entry)
        if query == "" then return true end
        local haystack = string.lower(entry.name .. " " .. (entry.class or "") .. " " .. (entry.race or "") .. " " .. entry.category)
        return haystack:find(query, 1, true) ~= nil
    end
    -- What to draw, top to bottom: macro rows, and in the Hidden view a
    -- heading above the hidden ones and another above the deleted ones.
    local items = {}
    if self.showHidden then
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
        for _, entry in ipairs(self:AllEntries()) do
            if matches(entry) and (entry.category == "classPicker" or not self:IsHidden(entry)) then items[#items + 1] = {entry = entry} end
        end
    end
    local y, heads = 0, 0
    self.listHeads = self.listHeads or {}
    for _, head in ipairs(self.listHeads) do head:Hide(); if head.ftHeading and head.ftHeading.line then head.ftHeading.line:Hide() end end
    for _, item in ipairs(items) do
        local entry = item.entry
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
            shown = shown + 1
            local button = self.rows[shown]
            if not button then
                button = KT:QuietButton(self.list, "", 300, 44)
                button.label:Hide()
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetSize(28, 28)
                button.icon:SetPoint("LEFT", 8, 0); KT:RoundIcon(button.icon)
                button.title = KT:Label(button, "", 14)
                button.title:SetPoint("TOPLEFT", 44, -6)
                button.title:SetWidth(246)
                button.meta = KT:Label(button, "", 11)
                button.meta:SetPoint("TOPLEFT", 44, -25)
                button.meta:SetTextColor(.72,.66,.55)
                button:SetScript("OnClick", function(owner)
                    if owner.entry.category == "classPicker" then
                        self.browsedClass = owner.entry.class
                        self:Select(self:AllEntries()[1])
                        self:Status("Previewing " .. self.browsedClass .. " macros. Click Character to go back to your own.")
                    else self:Select(owner.entry) end
                end)
                -- Two small buttons on the right of each row: hide (or show
                -- again), then X to delete.
                button.remove = KT:QuietButton(button, "", 24, 24)
                button.remove:SetPoint("RIGHT", -8, 0)
                button.remove.glyph = button.remove:CreateTexture(nil, "ARTWORK"); button.remove.glyph:SetSize(14, 14); button.remove.glyph:SetPoint("CENTER")
                button.remove.glyph:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
                button.remove:SetScript("OnClick", function() self:DeleteEntry(button.entry) end)
                KT:Tooltip(button.remove, "Delete", function()
                    return self.showHidden and "Delete this macro of yours for good. Asks first."
                        or "Remove this macro from the list. It moves to Hidden, where you can bring it back. A macro already added to WoW stays there; use Delete… in the top row for those."
                end)
                button.hide = KT:QuietButton(button, "", 24, 24)
                button.hide:SetPoint("RIGHT", button.remove, "LEFT", -4, 0)
                button.hide.glyph = button.hide:CreateTexture(nil, "ARTWORK"); button.hide.glyph:SetSize(16, 16); button.hide.glyph:SetPoint("CENTER")
                button.hide.glyph:SetTexCoord(.08, .92, .08, .92); KT:RoundIcon(button.hide.glyph)
                button.hide:SetScript("OnClick", function() local e = button.entry; if e then self:SetHidden(e, not self:IsHidden(e)) end end)
                KT:Tooltip(button.hide, "Hide or show", function()
                    return button.entry and self:IsHidden(button.entry) and "Show this macro in the list again." or "Hide this macro from the list. Hidden macros are never added by Add all. Open Hidden to bring it back."
                end)
                KT:Tooltip(button,"Macro template",function()
                    return button.entry and button.entry.name=="1-shot combo"
                        and "Build one macro that does several things. Pick learned spells above the macro name, and add trinkets or start attack from the gear button. Abilities off the global cooldown fire together; other spells may need another press."
                        or "Click to preview and edit this macro. Nothing changes in WoW until you add it."
                end)
                self.rows[shown] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 0, -y); y = y + 48
            button.entry = entry
            button.icon:SetTexture(self:IconForEntry(entry))
            button.title:SetText(entry.name)
            local state = entry.category ~= "classPicker" and self:HiddenState(entry) or nil
            local isHidden = state ~= nil
            button.hide:SetShown(entry.category ~= "classPicker")
            -- In the Hidden view only your own macros can be deleted for good.
            button.remove:SetShown(entry.category ~= "classPicker" and (not isHidden or entry.category == "custom"))
            -- An eye hides the macro; in the Hidden view the same button brings it back.
            button.hide.glyph:SetTexture(isHidden and "Interface\\Icons\\Spell_Nature_TimeStop" or "Interface\\Icons\\INV_Misc_Eye_01")
            button.title:SetWidth(186)
            button.meta:SetText(entry.category == "classPicker" and "View class macros" or entry.category=="custom" and (entry.class and "Custom • "..entry.class or "Custom • Generic") or entry.class or entry.race or "Generic")
            KT:SetSelected(button, sameEntry(entry, self.selectedMacro))
            button:Show()
        end
    end
    self.list:SetHeight(math.max(1, y))
    self.empty:SetShown(shown == 0)
    self.empty:SetText(self.showHidden and "Nothing hidden or deleted here." or "No matching macros.")
    local hiddenCount = self:HiddenCount()
    self.hiddenButton.label:SetText("Hidden (" .. hiddenCount .. ")")
    KT:SetSelected(self.hiddenButton, self.showHidden == true)
    self.hiddenButton:SetEnabled(hiddenCount > 0 or self.showHidden == true); self.hiddenButton:SetAlpha((hiddenCount > 0 or self.showHidden) and 1 or .45)
    self.detail:Show()
    self:UpdateFilters()
    self:UpdateBulkInfo()
end
function MacroForge:Select(entry)
    KT:FlushMacroRevision(self.selectedMacro)
    self.selectedMacro, self.selectedRank, self.mouseover = entry, "max", self:EntryMouseover(entry)
    self.quickSpell=nil
    if self.spellChoice then
        self.spellChoice.value=nil;self.spellChoice.label:SetText("Choose learned spell")
        self.spellChoice.icon:SetTexture("Interface\\Icons\\"..KT.icons.add)
    end
    if self.historyPanel then self.historyPanel:Hide() end
    if self.advancedPanel then self.advancedPanel:Hide() end
    self:UpdatePreview()
    self:RenderList()
end
-- A saved text that is only a default (the other mouseover setting, another
-- default version) is not an edit: drop it so the preview shows what Add
-- would actually create.
function MacroForge:ForgetDefaultBody(entry)
    local record = KT.db.macroHistory and KT.db.macroHistory[KT:MacroKey(entry)]
    if not record or type(record.body) ~= "string" or entry.code then return end
    local current = self:BuildMacro(entry)
    local saved = normalizeBody(record.body)
    -- false (not nil): nil would bring back the last saved version.
    if saved == normalizeBody(current) then record.body = false; record.dirty = nil; return end
    for _, old in ipairs(self:LegacyBodies(entry, current)) do
        if saved == normalizeBody(old) then record.body = false; record.dirty = nil; return end
    end
end
function MacroForge:UpdatePreview()
    local entry = self.selectedMacro
    if not entry then return end
    self:ForgetDefaultBody(entry)
    self.title:SetText(entry.name)
    self.rankLabel:SetText(entry.ranks and entry.ranks > 1 and (self.selectedRank == "max" and "Max rank" or "Rank " .. self.selectedRank) or "Single rank")
    local hasRanks = entry.ranks and entry.ranks > 1
    self.prevRank:SetShown(hasRanks); self.nextRank:SetShown(hasRanks); self.rankLabel:SetShown(hasRanks)
    local showMouseover = self:CanMouseover(entry)
    self.mouseoverButton:ClearAllPoints()
    if hasRanks then self.mouseoverButton:SetPoint("TOPRIGHT", self.detail, "TOPRIGHT", -16, -88)
    else self.mouseoverButton:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 16, -88) end
    local controls = hasRanks or showMouseover
    self.previewArea:ClearAllPoints(); self.previewArea:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 16, controls and -124 or -88)
    self.previewArea:SetHeight(controls and 300 or 336)
    self.prevRank:SetEnabled(hasRanks)
    self.nextRank:SetEnabled(entry.ranks and entry.ranks > 1)
    self.mouseoverButton:SetShown(showMouseover)
    local own = self.mouseover ~= (self.bulkMouseover == true)
    self.mouseoverButton.label:SetText((self.mouseover and "Mouseover: On" or "Mouseover: Off") .. (own and " *" or ""))
    KT:SetSelected(self.mouseoverButton, self.mouseover)
    self.loadingPreview = true
    self.preview:SetText(KT:MacroBody(entry, self:BuildMacro(entry)))
    self.loadingPreview = false
    self:UpdateScopeButton()
    self:UpdateDefaultButton()
end
-- "Save to" in the top row: Character or General. Class and racial macros
-- always go to Character, so the button rests there for them.
function MacroForge:UpdateScopeButton()
    local button = self.scopeButton; if not button then return end
    local entry = self.selectedMacro
    local forced = entry and (entry.class ~= nil or entry.characterOnly) or false
    local effective = forced and "character" or self.scope
    button.value = effective
    button.label:SetText("Save to: " .. (effective == "account" and "General" or "Character"))
    button.icon:SetTexture("Interface\\Icons\\" .. (effective == "account" and KT.icons.general or KT.icons.character))
    if effective ~= "account" then button.icon:SetTexture(self:ClassIcon(classKey())) end
end
function MacroForge:ScopeChoices()
    local entry = self.selectedMacro
    local forced = entry and (entry.class ~= nil or entry.characterOnly) or false
    return {
        {value = "character", label = "Character", icon = self:ClassIcon(classKey()), tooltip = "This character's own macro tab."},
        {value = "account", label = "General", icon = "Interface\\Icons\\" .. KT.icons.general, disabled = forced,
            tooltip = forced and "Class and racial macros always save to Character. To save a macro to General, pick one from the Generic list, or make your own with New macro and choose Generic." or "The tab shared by all your characters."},
    }
end
function MacroForge:UpdateDefaultButton()
    if not self.defaultButton or not self.selectedMacro then return end
    -- Only there when the text differs from the original.
    local changed = (self.preview:GetText() or "") ~= self:BuildMacro(self.selectedMacro)
    self.defaultButton:SetShown(changed)
    self.title:SetWidth(changed and 282 or 390)
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
    KT:StoreMacroBody(self.selectedMacro, body)
    self:RefreshQuickButtons(); self:UpdateDefaultButton()
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
    KT:StoreMacroBody(self.selectedMacro, body)
    self:UpdateDefaultButton()
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
    self:UpdateScopeButton()
    self:UpdatePreview()
end
-- Size each top-row button to its longest label in the font in use, so
-- nothing is cut off; the text shrinks a point only if the row would not fit.
function MacroForge:LayoutTopBar()
    if not self.bulkPanel then return end
    local items = {
        {self.scopeButton, {"Save to: Character", "Save to: General"}, 20},
        {self.bulkMouseoverButton, {"Mouseover: Off", "Mouseover: On"}, 0},
        {self.iconsButton, {"Icons: Off", "Icons: On"}, 0},
        {self.bulkButton, {"Add all"}, 0},
        {self.deleteButton, {"Delete character macros"}, 0},
    }
    local function measure(size)
        local total = 0
        for _, item in ipairs(items) do
            local label, widest = item[1].label, 0
            label:SetFont(KT.bodyFont, size, "")
            local keep = label:GetText()
            for _, text in ipairs(item[2]) do
                label:SetText(text)
                local width = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth()
                if type(width) ~= "number" then width = label:GetStringWidth() end
                if type(width) == "number" and width > widest then widest = width end
            end
            label:SetText(keep or "")
            -- icon (37) + text + right padding, plus the dropdown arrow where there is one
            item.width = math.ceil(37 + widest + 14 + item[3]); total = total + item.width
        end
        return total
    end
    -- 832 wide: 14 at each end, three 8 px gaps, and at least 12 between the two groups.
    local room, size = 832 - 28 - 24 - 12, 13
    while measure(size) > room and size > 10 do size = size - 1 end
    for _, item in ipairs(items) do item[1]:SetWidth(item.width) end
    self.scopeButton.menuWidth = math.max(180, self.scopeButton:GetWidth() or 180)
end
function MacroForge:UpdateIconsButton()
    if not self.iconsButton then return end
    local on = KT.db.macroUnlearnedIcons == true
    self.iconsButton.label:SetText("Icons: " .. (on and "On" or "Off"))
    KT:SetSelected(self.iconsButton, on)
end
function MacroForge:UpdateBulkInfo()
    self.bulkMouseover = KT.db.macroBulkMouseover == true
    local _, count = GetNumMacros()
    local free = math.max(0, (MAX_CHARACTER_MACROS or 30) - count)
    local needed = 0
    local oldRank, oldMouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    for _, entry in ipairs(self:AddableEntries()) do
        self.mouseover = self:EntryMouseover(entry)
        if not self:EntryExists(entry, self:BuildMacro(entry)) then needed = needed + 1 end
    end
    self.selectedRank, self.mouseover = oldRank, oldMouseover
    local className = self:BulkClass()
    local icon = classIcons[className] or "INV_Misc_QuestionMark"
    self.bulkButton.label:SetText("Add all")
    self.bulkButton.icon:SetTexture(self:ClassIcon(className))
    self.bulkMouseoverButton.label:SetText(self.bulkMouseover and "Mouseover: On" or "Mouseover: Off")
    KT:SetSelected(self.bulkMouseoverButton, self.bulkMouseover)
    self.bulkInfo:SetText(""); self.bulkInfo:Hide()
    self:UpdateIconsButton(); self:UpdateScopeButton()
    return needed, free
end
function MacroForge:ConfirmBulk()
    local needed, free = self:UpdateBulkInfo()
    local className = self:BulkClass()
    local foreign = className ~= classKey()
    if needed <= free and not foreign then self:CreateBulk(className); return end
    -- Not enough room: let the player pick what to delete and what to add.
    if needed > free then self:OpenMakeRoom(className); return end
    self.pendingBulkClass = className
    StaticPopupDialogs.FOREVERTOOLS_BULK.text = "WARNING: You are a " .. classKey() .. ", not a " .. className .. ".\n\n" .. string.format("Add all %s macros to Character macros?", className)
    KT:ShowPopup("FOREVERTOOLS_BULK")
end
function MacroForge:CreateUI()
    if self.uiReady then return end
    if self.frame then self.frame:Hide() end
    self.rows = {}
    local frame = KT:Window("ForeverToolsMacros", "ForeverTools | Macros", 880, 744)
    self.frame = frame
    frame:HookScript("OnHide", function() self.entriesCache, self.entriesKey = nil, nil end)
    local hint = KT:Label(frame, "", 14)
    hint:SetPoint("TOPLEFT", 24, -57)
    local bulkPanel = CreateFrame("Frame", nil, frame)
    bulkPanel:SetSize(832, 58); bulkPanel:SetPoint("TOPLEFT", 24, -82); KT:Panel(bulkPanel)
    -- One row. Left, how macros are made: Save to | Mouseover | Unlearned
    -- icons. Right, what to do: Add all | Delete.
    self.bulkStatus = KT:Label(bulkPanel, "", 15, true); self.bulkStatus:Hide()
    self.scopeButton = KT:Dropdown(bulkPanel, 204, function() return self:ScopeChoices() end, function(value) self:ChooseScope(value) end, "character")
    self.scopeButton:SetHeight(34); self.scopeButton.menuWidth = 204
    self.scopeButton:SetPoint("LEFT", 14, 0)
    KT:Tooltip(self.scopeButton, "Where macros are saved", "Character: this character's own macro tab. General: the tab shared by all your characters. Class and racial macros always go to Character.")
    self.bulkMouseover = KT.db.macroBulkMouseover == true
    self.bulkMouseoverButton = KT:QuietButton(bulkPanel, "", 150, 34, "mouseover")
    self.bulkMouseoverButton:SetPoint("LEFT", self.scopeButton, "RIGHT", 8, 0)
    self.bulkMouseoverButton:SetScript("OnClick", function()
        self.bulkMouseover = not self.bulkMouseover; KT.db.macroBulkMouseover = self.bulkMouseover
        -- The row sets every macro; single-macro exceptions start over.
        KT.db.macroMouseover = nil
        if self.selectedMacro then self:Select(self.selectedMacro) end
        self:UpdateBulkInfo()
    end)
    KT:Tooltip(self.bulkMouseoverButton, "Mouseover for all macros", "Macros cast on the unit under your mouse and keep your target: heal or dispel a party member, hit or crowd-control an enemy beside you. Melee strikes stay on your target. Add all updates macros you already added. A macro's own Mouseover button can make an exception (marked *); changing this clears them. Tip: also turn on Mouseover Cast in the game's Combat settings.")
    self.iconsButton = KT:QuietButton(bulkPanel, "", 180, 34, "classes")
    self.iconsButton:SetPoint("LEFT", self.bulkMouseoverButton, "RIGHT", 8, 0)
    self.iconsButton:SetScript("OnClick", function() KT.db.macroUnlearnedIcons = not (KT.db.macroUnlearnedIcons == true); self:UpdateIconsButton() end)
    KT:Tooltip(self.iconsButton, "Icons for unlearned spells", "When on, macros for spells you have not learned yet get the spell's icon, so you can set up your action bars from level 1. Add all also gives macros you already added their icon. Once learned, they work as usual.")
    self.bulkButton = KT:QuietButton(bulkPanel, "", 116, 34, "add")
    self.bulkButton:SetScript("OnClick", function() self:ConfirmBulk() end)
    KT:Tooltip(self.bulkButton, "Add all class macros", function() return "Add every " .. self:BulkClass() .. " macro to your Character macros. Macros you already added are updated, not copied." end)
    self.deleteButton = KT:QuietButton(bulkPanel, "Delete character macros", 200, 34, "delete")
    self.deleteButton:SetPoint("RIGHT", -14, 0)
    self.bulkButton:SetPoint("RIGHT", self.deleteButton, "LEFT", -8, 0)
    -- Two ways to clean up: only untouched ForeverTools macros, or everything.
    self.deleteButton.options = function()
        return {
            {value = "unchanged", label = "Delete unchanged macros", icon = "Interface\\Icons\\INV_Misc_Note_01",
                tooltip = "Delete Character macros that ForeverTools made and you have not changed: class, racial and generic ones. Macros you changed or made yourself are kept."},
            {value = "all", label = "Delete ALL Character macros", icon = "Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
                tooltip = "Delete every macro in your Character tab, including ones you made or changed. General macros are not touched. Asks twice."},
        }
    end
    self.deleteButton.onSelect = function(mode) self:RequestDeleteClass(mode) end
    self.deleteButton.menuWidth = 260
    self.deleteButton:SetScript("OnClick", function(owner) KT:ShowChoices(owner) end)
    for _,button in ipairs({self.scopeButton,self.bulkMouseoverButton,self.iconsButton,self.bulkButton,self.deleteButton}) do
        if button.label.SetWordWrap then button.label:SetWordWrap(false) end
        button.label:SetFont(KT.bodyFont, 13, "")
    end
    self.bulkPanel = bulkPanel
    KT:Tooltip(self.deleteButton, "Delete Character macros", "Choose: delete only the ForeverTools macros you have not changed, or every Character macro. Both ask before deleting.")
    self.bulkInfo = KT:Label(bulkPanel, "", 12)
    self.bulkInfo:SetPoint("TOPLEFT", 14, -53); self.bulkInfo:SetWidth(725); self.bulkInfo:Hide()
    self.filterButtons = {}
    local filters = {{"mine", "Character", "character"}, {"generic", "Generic", "generic"}}
    for index, item in ipairs(filters) do
        local key = item[1]
        local button = KT:QuietButton(frame, item[2], index == 1 and 164 or 108, 28, item[3])
        button:SetPoint("TOPLEFT", index == 1 and 24 or 196, -156)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if button.label.SetWordWrap then button.label:SetWordWrap(false) end
        button:SetScript("OnClick", function(owner, mouse)
            if key == "mine" and mouse == "RightButton" then
                -- Look at another class's macros (an alt's, for example).
                owner.options = function()
                    local list, names = {}, {}
                    for name in pairs(classMacros) do names[#names + 1] = name end
                    table.sort(names)
                    for _, name in ipairs(names) do list[#list + 1] = {value = name, label = name .. (name == classKey() and " (this character)" or ""), icon = self:ClassIcon(name)} end
                    return list
                end
                owner.value = self.filter == "class" and self.browsedClass or classKey(); owner.menuWidth = 220
                owner.onSelect = function(name)
                    self.showHidden = false
                    if name == classKey() then self.filter, self.browsedClass = "mine", nil
                    else self.filter, self.browsedClass = "class", name; self:Status("Previewing " .. name .. " macros. Click Character to go back to your own.") end
                    self:Select(self:AllEntries()[1])
                end
                KT:ShowChoices(owner); return
            end
            self.filter = key; self.browsedClass = nil; self.showHidden = false; self:RenderList()
        end)
        self.filterButtons[key] = button
        KT:Tooltip(button, item[2], key == "mine" and "Macros for this character's class and race. Right-click to preview another class's macros, for an alt." or "Useful macros that are not class-specific.")
    end
    self.newButton=KT:QuietButton(frame,"New macro",136,28,"add");self.newButton:SetPoint("TOPLEFT",312,-156)
    self.newButton:SetScript("OnClick",function() self.newName:SetText("");self.newClass=false;self:RefreshNewPanel();self.newPanel:Show();if self.newName.SetFocus then self.newName:SetFocus() end end)
    KT:Tooltip(self.newButton,"New macro","Create your own macro in My class or Generic, then edit its text and add it to WoW.")
    self.hiddenButton = KT:QuietButton(frame, "Hidden (0)", 130, 28, "reset"); self.hiddenButton:SetPoint("TOPLEFT", 456, -156)
    if self.hiddenButton.label.SetWordWrap then self.hiddenButton.label:SetWordWrap(false) end
    if self.hiddenButton.SetMotionScriptsWhileDisabled then self.hiddenButton:SetMotionScriptsWhileDisabled(true) end
    self.hiddenButton:SetScript("OnClick", function() self.showHidden = not self.showHidden; self:RenderList() end)
    KT:Tooltip(self.hiddenButton, "Hidden and deleted macros", "List the macros you hid or deleted (from every list), so you can bring them back. They are never added by Add all. Click Character or Generic to go back to the normal list.")
    self.search = CreateFrame("EditBox", nil, frame)
    self.search:SetSize(196, 28); self.search:SetPoint("TOPRIGHT", -24, -156)
    KT:Panel(self.search)
    self.search:SetAutoFocus(false); self.search:SetFont(KT.bodyFont, 14, "")
    self.search:SetTextInsets(10, 10, 0, 0)
    -- Wait for a short pause in typing before filtering the list.
    self.search:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then self:RenderList(); return end
        KT:Coalesce("macroSearch", function() self:RenderList() end, 0.15)
    end)
    self.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.search.placeholder = KT:Label(self.search, "Search macros...", 14)
    self.search.placeholder:SetPoint("LEFT", 10, 0)
    self.search.placeholder:SetTextColor(.55,.49,.40)
    self.search:SetScript("OnEditFocusGained", function() self.search.placeholder:Hide() end)
    self.search:SetScript("OnEditFocusLost", function() self.search.placeholder:SetShown(self.search:GetText() == "") end)
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -198); scroll:SetSize(308, 482); self.listScroll = scroll
    self.list = CreateFrame("Frame", nil, scroll); self.list:SetWidth(300); scroll:SetScrollChild(self.list)
    self.empty = KT:Label(self.list, "No matching macros.", 14); self.empty:SetPoint("TOPLEFT", 6, -8)
    local detail = CreateFrame("Frame", nil, frame)
    self.detail = detail
    detail:SetSize(494, 482); detail:SetPoint("TOPRIGHT", -24, -198); KT:Panel(detail)
    self.title = KT:Label(detail, "", 18, true); self.title:SetPoint("TOPLEFT", 52, -55); self.title:SetWidth(390)
    if self.title.SetWordWrap then self.title:SetWordWrap(false) end
    local newPanel=CreateFrame("Frame",nil,frame);self.newPanel=newPanel
    newPanel:SetSize(420,250);newPanel:SetPoint("CENTER",frame,"CENTER");newPanel:SetFrameLevel(frame:GetFrameLevel()+40);KT:MakeDraggable(newPanel,frame);KT:Panel(newPanel);newPanel:Hide()
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
    KT:Tooltip(self.newGeneric,"Generic","List the new macro under Generic. Save to in the top row sets whether it goes to General or Character macros.")
    local createCustom=KT:AccentButton(newPanel,"Create macro",384,32,"add");createCustom:SetPoint("BOTTOM",0,20);self.createCustomButton=createCustom
    createCustom:SetScript("OnClick",function() self:CreateCustom(self.newName:GetText(),self.newClass) end)
    self.prevRank = KT:QuietButton(detail, "<", 28, 26); self.prevRank:SetPoint("TOPLEFT", 16, -88)
    self.prevRank:SetScript("OnClick", function() self:StepRank(-1) end)
    KT:Tooltip(self.prevRank, "Spell rank", "Pick a lower rank, for example to save mana.")
    self.rankLabel = KT:Label(detail, "", 14); self.rankLabel:SetPoint("LEFT", self.prevRank, "RIGHT", 8, 0); self.rankLabel:SetWidth(84); self.rankLabel:SetJustifyH("CENTER")
    self.nextRank = KT:QuietButton(detail, ">", 28, 26); self.nextRank:SetPoint("LEFT", self.rankLabel, "RIGHT", 8, 0)
    self.nextRank:SetScript("OnClick", function() self:StepRank(1) end)
    KT:Tooltip(self.nextRank, "Spell rank", "Pick a higher rank. Your highest rank is used by default.")
    self.mouseoverButton = KT:QuietButton(detail, "", 168, 26, "mouseover"); self.mouseoverButton:SetPoint("LEFT", self.nextRank, "RIGHT", 20, 0)
    self.mouseoverButton:SetScript("OnClick", function()
        self.mouseover = not self.mouseover
        -- Remember this macro's own choice; Add all respects it too.
        -- Only a choice that differs from Mouseover in the Add all row is kept.
        if type(KT.db.macroMouseover) ~= "table" then KT.db.macroMouseover = {} end
        local own = nil
        if self.mouseover ~= (self.bulkMouseover == true) then own = self.mouseover end
        KT.db.macroMouseover[KT:MacroKey(self.selectedMacro)] = own
        -- The preview follows the setting; no text is saved for a default.
        local record = KT:MacroRecord(self.selectedMacro); record.body = false; record.dirty = nil
        self:UpdatePreview() end)
    KT:Tooltip(self.mouseoverButton, "Mouseover", "Cast on the unit under your mouse, keeping your target. Follows Mouseover in the Add all row; changing it here makes an exception for this macro only (marked *). Changing the row setting clears the exceptions.")
    self.previewArea = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    self.previewArea:SetSize(462, 300); self.previewArea:SetPoint("TOPLEFT", 16, -124)
    KT:AutoHideScrollBar(self.previewArea, function(needed)
        local width = needed and 440 or 462
        self.previewArea:SetWidth(width); if self.preview then self.preview:SetWidth(width) end
    end)
    self.preview = CreateFrame("EditBox", nil, self.previewArea)
    self.preview:SetMultiLine(true); self.preview:SetAutoFocus(false)
    self.preview:SetFont(KT.bodyFont, 14, ""); self.preview:SetSize(462, 172)
    self.preview:SetTextInsets(6,6,6,6); KT:Panel(self.preview)
    self.previewArea:SetScrollChild(self.preview)
    self.preview:SetScript("OnTextChanged", function(box, userInput)
        local _, lines = box:GetText():gsub("\n", "")
        box:SetHeight(math.max(self.previewArea:GetHeight() or 172, (lines + math.ceil(#box:GetText() / 60) + 1) * 17 + 12))
        -- Only typing counts as an edit. Showing a macro must never save its
        -- text, or the preview would stop following Mouseover and ranks.
        if self.selectedMacro and userInput and not self.loadingPreview then
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
    -- A gold typing line where the cursor is, and clicks that move it there.
    self.previewCaret = KT:TextCaret(self.preview, 6)
    -- Top row: pick a learned spell and add it to the macro text.
    self.spellChoice=KT:Dropdown(detail,330,function() return self:LearnedSpellChoices() end,function(value)
        self.quickSpell=value
        for _,spell in ipairs(self:LearnedSpellChoices()) do
            if spell.value==value then self.spellChoice.label:SetText(spell.label);self.spellChoice.icon:SetTexture(spell.icon or 134400);break end
        end
    end,"add")
    self.spellChoice:SetPoint("TOPLEFT",16,-12);self.spellChoice.label:SetText("Choose learned spell")
    KT:Tooltip(self.spellChoice,"Learned spells","Pick a spell you have learned, then add it to the macro.")
    local addSpell=KT:QuietButton(detail,"Add spell",122,28,"add");addSpell:SetPoint("LEFT",self.spellChoice,"RIGHT",10,0)
    KT:PlusIcon(addSpell);self.addSpellButton=addSpell
    addSpell:SetScript("OnClick",function() self:AddQuickSpell() end)
    KT:Tooltip(addSpell,"Add learned spell","Add a /cast line for this spell to the macro.")
    -- Gear in front of the macro name: extra lines (stop cast, start attack, gear).
    self.advancedButton=KT:QuietButton(detail,"",28,28);self.advancedButton:SetPoint("TOPLEFT",16,-50)
    KT:GearIcon(self.advancedButton)
    self.advancedPanel=CreateFrame("Frame",nil,frame);self.advancedPanel:SetSize(462,232)
    self.advancedPanel:SetPoint("TOPLEFT",frame,"TOPRIGHT",8,-198)
    self.advancedPanel:SetFrameLevel(frame:GetFrameLevel()+20)
    self.advancedPanel:SetFrameStrata("DIALOG");self.advancedPanel:SetClampedToScreen(true)
    KT:MakeDraggable(self.advancedPanel,frame)
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
    KT:Tooltip(self.advancedButton,"Advanced options","Extra lines for this macro: stop casting, start attacking, or use an equipped item such as a trinket.")
    self.advancedPanel:HookScript("OnShow",function() KT:SetSelected(self.advancedButton,true) end)
    self.advancedPanel:HookScript("OnHide",function() KT:SetSelected(self.advancedButton,false) end)
    KT:AddClose(self.advancedPanel,nil,8)
    local advancedTitle=KT:Label(self.advancedPanel,"Add or remove macro actions",15,true);advancedTitle:SetPoint("TOPLEFT",12,-14)
    self.quickButtons={}
    for i,entry in ipairs({{"Stop cast","/stopcasting","Interface\\Icons\\Spell_Holy_Silence"},{"Start attack","/startattack","Interface\\Icons\\Ability_MeleeDamage"}}) do
        local line=entry[2];local button=KT:QuietButton(self.advancedPanel,entry[1],215,28,"generic")
        button.icon:SetTexture(entry[3])
        button:SetPoint("TOPLEFT",12+(i-1)*223,-50)
        button:SetScript("OnClick",function() self:EditQuickLine(line) end)
        KT:Tooltip(button,entry[1],"Add or remove this line in the macro.")
        self.quickButtons[#self.quickButtons+1]={button=button,line=line}
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
    -- Every gear slot as its own button (three columns), each adding or
    -- removing a /use line for that slot.
    local gearTitle=KT:Label(self.advancedPanel,"Use equipped gear",13,true);gearTitle:SetPoint("TOPLEFT",12,-92);gearTitle:SetTextColor(1,.82,0)
    self.slotButtons={}
    for i,slot in ipairs(slots) do
        local line="/use "..slot[1]
        local button=KT:QuietButton(self.advancedPanel,slot[2],142,28,"generic")
        button:SetPoint("TOPLEFT",12+((i-1)%3)*148,-114-math.floor((i-1)/3)*34)
        button.label:SetFont(KT.bodyFont,13,""); if button.label.SetWordWrap then button.label:SetWordWrap(false) end
        button:SetScript("OnClick",function() self:EditQuickLine(line) end)
        KT:Tooltip(button,slot[2],"Add or remove /use "..slot[1].." in the macro: uses whatever you have equipped in this slot. Only items with a Use effect do anything.")
        self.quickButtons[#self.quickButtons+1]={button=button,line=line}
        self.slotButtons[i]={button=button,slot=slot}
    end
    self.advancedPanel:SetHeight(114+math.ceil(#slots/3)*34+8)
    -- Show what is equipped right now each time the panel opens.
    self.advancedPanel:HookScript("OnShow",function()
        for _,entry in ipairs(self.slotButtons) do entry.button.icon:SetTexture(slotIcon(entry.slot)) end
        self:RefreshQuickButtons()
    end)
    self.defaultButton = KT:QuietButton(detail, "Default", 100, 28, "reset")
    self.defaultButton:SetPoint("TOPRIGHT", -16, -50); self.defaultButton:Hide()
    self.defaultButton:SetScript("OnClick", function() KT:Confirm("Restore the original macro text? Your current edit will be replaced.",function() self:RestoreDefault() end) end)
    KT:Tooltip(self.defaultButton, "Restore default", "You changed this macro. Go back to its original text. Asks first.")
    local add = KT:AccentButton(detail, "Add selected macro", 462, 38, "macros"); add:SetPoint("BOTTOM", 0, 10); self.addButton = add
    do local font, _, flags = add.label:GetFont(); add.label:SetFont(font or KT.bodyFont, 16, flags or "") end
    add:SetScript("OnClick", function() if self.selectedMacro then KT.modules.MacroEditor:InstallEntry(self.selectedMacro, self:BuildMacro(self.selectedMacro)) end end)
    KT:Tooltip(add, "Add selected macro", "Add the macro to the chosen tab. If it is already there, you can choose to replace it.")
    self.status = KT:Label(frame, "", 14); self.status:SetPoint("BOTTOMLEFT", 24, 20); self.status:SetWidth(830)
    -- Hover area over the status line: lists skipped macros after "Add all".
    self.statusHover = CreateFrame("Frame", nil, frame); self.statusHover:SetAllPoints(self.status); self.statusHover:EnableMouse(true); self.statusHover:Hide()
    self.statusHover:SetScript("OnEnter", function(owner)
        if not self.skippedText then return end
        GameTooltip:SetOwner(owner, "ANCHOR_TOP")
        GameTooltip:SetText("Skipped macros", 1,.82,0)
        GameTooltip:AddLine(self.skippedText, .96,.93,.86, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Make room in your Character macros (Esc > Macros), then use Add all again. Macros you already have are never added twice.", .66,.59,.48, true)
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
    if not self.selectedMacro then self:Select(self:AllEntries()[1])
    else self.bulkMouseover = KT.db.macroBulkMouseover == true; self.mouseover = self:EntryMouseover(self.selectedMacro) end
    self:RenderList(); self:UpdatePreview(); self:UpdateBulkInfo(); self:LayoutTopBar()
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
