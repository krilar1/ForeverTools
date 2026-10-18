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

-- Eat & Drink (FoodWater.lua): eats when hurt, drinks when mana is low. Its
-- text follows your health, mana and bags, so it keeps its own name.
table.insert(classMacros.Mage,1,{"Eat & Drink",1,"generic","inv_misc_food_73",
    function() return KT.modules.FoodWater and KT.modules.FoodWater:Body() or "#showtooltip" end,nil,
    "One button for conjured food and water: eats when hurt, drinks when low on mana, conjures more when you run out. Kept up to date, also if renamed. Edit it yourself and it is left alone.",named=true})
-- Teleports and portals are spells you click from the spellbook once in a
-- while; they never need a macro, so the list leaves them out.
local function isTravelSpell(name) return type(name)=="string" and (name:find("^Teleport") or name:find("^Portal")) ~= nil end
for _,entries in pairs(classMacros) do
    for i=#entries,1,-1 do if isTravelSpell(entries[i][1]) then table.remove(entries,i) end end
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
    -- Text and note from Bandage.lua: it follows the bandages in your bags.
    {"Bandage", 1, "generic", "inv_misc_bandage_12", function() return KT.modules.Bandage and KT.modules.Bandage:Body() or "#showtooltip\n/stopattack" end, nil,
        "Stops your attack and uses your best bandage. Kept up to date as your bags change. Edit it yourself and it is left alone."},
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
        local code = data[5]
        -- A text that follows the game (the Bandage macro) is built when listed.
        if type(code) == "function" then code = code() end
        destination[#destination + 1] = { name = data[1], ranks = data[2], kind = data[3], icon = data[4], code = code, old = data[6], note = data[7], class = className, race = raceName, category = category, named = data.named }
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
    Mage = {},
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
        if type(spell.name)=="string" and (includeGeneral or spell.line~=1) and not isTravelSpell(spell.name) then
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
    self:Status("Macro created at the top. Add spells or edit it, then Add.")
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
    if entry.named then return string.sub(entry.name, 1, 16) end
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
-- The spells (and items) a macro casts, whatever its conditions, ranks,
-- tooltip line or extra lines like /startattack: "/cast [@mouseover,harm]
-- [] Lightning Bolt(Rank 3)" and "/cast Lightning Bolt" both cast
-- {lightning bolt}. Slot numbers (/use 13) don't count.
local CAST = {cast = true, use = true, castsequence = true, castrandom = true}
local function castSpells(body)
    local set, count = {}, 0
    for line in ((body or "") .. "\n"):gmatch("([^\n]*)\n") do
        local command, rest = line:match("^%s*/(%a+)%s*(.*)$")
        if command and CAST[command:lower()] then
            command = command:lower()
            if command == "castsequence" then rest = rest:gsub("reset=%S+%s*", "") end
            for option in rest:gmatch("[^;]+") do
                option = option:gsub("%b[]", "")
                -- Only sequences and random casts list several spells with commas
                -- (an item name may have a comma of its own).
                local pattern = (command == "castsequence" or command == "castrandom") and "[^,]+" or ".+"
                for spell in option:gmatch(pattern) do
                    spell = spell:gsub("^%s*!?%s*", ""):gsub("%s*%([^%)]*%)%s*$", ""):gsub("%s+$", "")
                    if spell ~= "" and not spell:match("^%d+%s*%d*$") and not set[spell:lower()] then set[spell:lower()] = true; count = count + 1 end
                end
            end
        end
    end
    return set, count
end
MacroForge.CastSpells = castSpells
-- A macro of yours (General or Character, any name) that casts exactly what
-- this template casts: it counts as this macro, even with your own text.
-- Returns its index. Never used to change a macro, only to know it is there.
function MacroForge:SameAction(entry, body)
    if not GetNumMacros or not GetMacroInfo or entry.name == "1-shot combo" then return nil end
    local wanted, count = castSpells(body)
    if count == 0 then return nil end
    local account, character = GetNumMacros()
    local first = (MAX_ACCOUNT_MACROS or 120) + 1
    local ranges = {{1, account or 0}, {first, first + (character or 0) - 1}}
    for _, range in ipairs(ranges) do
        for index = range[1], range[2] do
            local _, _, existing = GetMacroInfo(index)
            if type(existing) == "string" and not (issecretvalue and issecretvalue(existing)) then
                local have, n = castSpells(existing)
                if n == count then
                    local same = true
                    for spell in pairs(wanted) do if not have[spell] then same = false; break end end
                    if same then return index end
                end
            end
        end
    end
    return nil
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
    if entry.named or (not entry.class and not entry.characterOnly) then return (GetMacroIndexByName(self:MacroName(entry)) or 0) > 0 end
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
    if #body > 255 then self.skipReason = "long"; self:Status("Too long for WoW's 255-character limit.", true); return false end
    local name = self:MacroName(entry)
    local exists, existingIndex = self:EntryExists(entry, body)
    -- You already have your own macro for it (another text or name): keep
    -- yours, never add a second one.
    -- (Adding one macro yourself still adds it: you asked for that one.)
    if not exists and self.bulkAdding and self:SameAction(entry, body) then
        self.skipReason = "exists"
        self:Status(entry.name .. " is already in your macros (your own version).")
        return false
    end
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
        -- Macros that follow the game (Bandage, Eat & Drink) catch up at once.
        for _,key in ipairs({"Bandage","FoodWater"}) do
            local follow=KT.modules[key]; if follow and follow.Update then C_Timer.After(0,function() follow.best=nil; pcall(follow.Update,follow) end) end
        end
        return true
    end
    self.skipReason = "full"
    self:Status("WoW couldn't create the macro. Is the tab full?", true)
    return false
end

-- Macro icon. Normally the question mark, so WoW shows the spell's own icon
-- (#showtooltip). With "Icons for unlearned spells" on, a spell you have not
-- learned yet gets its real icon right away (from your spellbook's upcoming
-- spells, or the template), so bars can be set up from level 1.
function MacroForge:MacroIcon(entry)
    if KT.db.macroUnlearnedIcons ~= true or not entry.class then return 134400 end
    -- Your own macros are named by you, not after a spell: the spell is the
    -- one the macro text shows or casts first.
    local spellName = entry.name
    local custom = entry.kind == "custom" or entry.category == "custom"
    if custom then
        local text = "\n" .. (self:BuildMacro(entry) or "")
        spellName = text:match("\n#showtooltip[ \t]+([^\n]+)") or text:match("\n/cast[ \t]+([^\n]+)") or text:match("\n/use[ \t]+([^\n]+)")
        if spellName then spellName = spellName:gsub("^%b[]%s*", ""):gsub("%s*%(.-%)%s*$", ""):gsub("%s+$", "") end
        if not spellName or spellName == "" then return 134400 end
    end
    local book = KT.modules.CustomKeybinds
    local ok, spells = pcall(book.LearnedSpells, book)
    if ok and type(spells) == "table" then
        local wanted = spellName:lower()
        for _, spell in ipairs(spells) do if type(spell.name) == "string" and spell.name:lower() == wanted then return 134400 end end
    end
    -- One spellbook scan per spellbook change, not one per macro.
    if self.futureFor ~= spells or not self.futureIcons then self:LearnLevels(); self.futureFor = spells end
    local future = self.futureIcons and self.futureIcons[spellName]
    if type(future) == "number" then return future end
    -- A placeholder (the note icon of your own macros) is never used as the
    -- macro's icon: the question mark lets the game show the spell's icon.
    if custom then return 134400 end
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
    self.counts = nil
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
        self:Status(string.format("%d class macros added; %d skipped. Hover to see which.", created, total), #skipped.full + #skipped.long > 0)
    end
    self.statusHover:SetShown(total > 0)
    if created > 0 then KT:Toast(string.format("Added %d character macros", created)) end
    self:UpdateBulkInfo()
end

local function sameEntry(a, b)
    return a and b and a.name == b.name and a.class == b.class and a.race == b.race
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
    self:RefreshEquip()
end
-- Equip lines: "/equipslot <slot> <item name>" puts a chosen item in a gear
-- slot, for example a weapon swap that goes with the macro's spell.
-- Which slots an item fits, by the game's own equip-location names.
local EQUIP_FITS={
    INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_BODY={4},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
    INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},
    INVTYPE_WEAPON={16,17},INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16},
    INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},INVTYPE_HOLDABLE={17},
    -- Ranged weapons sit in the ranged slot where the game has one, else in the main hand.
    INVTYPE_RANGED={18,16},INVTYPE_RANGEDRIGHT={18,16},INVTYPE_THROWN={18},INVTYPE_RELIC={18},
    INVTYPE_TABARD={19},
}
-- Weapons first: those are the swaps the game also allows in a fight.
MacroForge.equipSlots={{16,"Main hand"},{17,"Off hand"},{18,"Ranged"},{13,"Trinket 1"},{14,"Trinket 2"},{11,"Ring 1"},{12,"Ring 2"},
    {1,"Head"},{2,"Neck"},{3,"Shoulders"},{15,"Back"},{5,"Chest"},{4,"Shirt"},{19,"Tabard"},{9,"Wrist"},{10,"Hands"},{6,"Waist"},{7,"Legs"},{8,"Feet"}}
local function plain(v) return (not issecretvalue or not issecretvalue(v)) and v~=nil end
local function linkName(link)
    if not plain(link) or type(link)~="string" then return end
    return link:match("%[(.-)%]")
end
local function fits(item,slot)
    local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant or item==nil then return false end
    local ok,_,_,_,equipLoc=pcall(instant,item)
    if not ok or not plain(equipLoc) then return false end
    for _,candidate in ipairs(EQUIP_FITS[equipLoc] or {}) do if candidate==slot then return true end end
    return false
end
-- The item this macro equips in a slot, read from its text (nil if none).
function MacroForge:EquipLine(slot,text)
    text=text or (self.preview and self.preview:GetText()) or ""
    for row in (text.."\n"):gmatch("(.-)\n") do
        local number,name=row:match("^/equipslot%s+(%d+)%s+(.-)%s*$")
        if tonumber(number)==slot and name~="" then return (name:gsub('^"(.*)"$',"%1")) end
    end
end
-- The game's own color for an item quality (grey, white, green, blue,
-- purple, orange), as a color code; nil when it is not known.
local function qualityCode(quality)
    if not plain(quality) or type(quality)~="number" then return nil end
    local r,g,b
    local entry=type(ITEM_QUALITY_COLORS)=="table" and ITEM_QUALITY_COLORS[quality]
    if type(entry)=="table" and type(entry.r)=="number" then r,g,b=entry.r,entry.g,entry.b
    else
        local get=(C_Item and C_Item.GetItemQualityColor) or GetItemQualityColor
        if get then local ok,cr,cg,cb=pcall(get,quality); if ok and type(cr)=="number" and type(cg)=="number" and type(cb)=="number" then r,g,b=cr,cg,cb end end
    end
    if not r then return nil end
    return string.format("|cff%02x%02x%02x",math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5))
end
-- The quality of an item by name: what you wear in that slot, else what the
-- game knows about the name (items in your bags).
function MacroForge:EquipQuality(slot,name)
    if type(name)~="string" or name=="" then return nil end
    if GetInventoryItemLink and GetInventoryItemQuality then
        local ok,link=pcall(GetInventoryItemLink,"player",slot)
        if ok and linkName(link)==name then
            local okQuality,quality=pcall(GetInventoryItemQuality,"player",slot)
            if okQuality and plain(quality) and type(quality)=="number" then return quality end
        end
    end
    local get=(C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get then
        local ok,_,_,quality=pcall(get,name)
        if ok and plain(quality) and type(quality)=="number" then return quality end
    end
end
-- An item name in its quality color, like the game shows it.
function MacroForge:ColoredItem(name,quality)
    local code=qualityCode(quality)
    return code and (code..name.."|r") or name
end
-- What can go in this slot: what you wear there now, then soulbound items in
-- your bags that fit it. Read when the menu opens, never while playing.
function MacroForge:EquipChoices(slot)
    local list={{value="",label="None (remove from macro)",icon="Interface\\Icons\\INV_Misc_QuestionMark"}}
    local seen={}
    local function add(name,icon,suffix,quality)
        if type(name)~="string" or name=="" or seen[name] then return end
        seen[name]=true
        if quality==nil then quality=self:EquipQuality(slot,name) end
        list[#list+1]={value=name,label=self:ColoredItem(name,quality)..(suffix or ""),icon=plain(icon) and icon or nil,tooltipTitle=name}
    end
    if GetInventoryItemLink then
        local ok,link=pcall(GetInventoryItemLink,"player",slot)
        if ok then
            local icon; if GetInventoryItemTexture then local okIcon,texture=pcall(GetInventoryItemTexture,"player",slot); if okIcon then icon=texture end end
            add(linkName(link),icon," (equipped)")
        end
    end
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
        for bag=0,(NUM_BAG_SLOTS or 4) do
            local okCount,count=pcall(C_Container.GetContainerNumSlots,bag)
            for index=1,(okCount and plain(count) and type(count)=="number" and count or 0) do
                local ok,info=pcall(C_Container.GetContainerItemInfo,bag,index)
                if ok and type(info)=="table" and plain(info.isBound) and info.isBound and plain(info.itemID) and fits(info.itemID,slot) then
                    add((plain(info.itemName) and type(info.itemName)=="string" and info.itemName) or linkName(info.hyperlink),info.iconFileID,nil,
                        plain(info.quality) and type(info.quality)=="number" and info.quality or nil)
                end
            end
        end
    end
    -- An item the macro names that you no longer carry stays in the list.
    local current=self:EquipLine(slot)
    if current and not seen[current] then add(current,nil," (not in your bags)") end
    return list
end
-- Set, replace or remove (name "" or nil) the equip line for a slot. Equip
-- lines sit right under the # lines, so the swap comes before the cast.
function MacroForge:SetEquipLine(slot,name)
    if not self.selectedMacro or not self.preview then return end
    local old=self.preview:GetText() or ""
    local head,equips,rest={},{},{}
    for row in (old.."\n"):gmatch("(.-)\n") do
        local number=row:match("^/equipslot%s+(%d+)%s")
        if number then
            if tonumber(number)~=slot then equips[#equips+1]=row end
        elseif row:sub(1,1)=="#" and #rest==0 and #equips==0 then head[#head+1]=row
        else rest[#rest+1]=row end
    end
    if type(name)=="string" and name~="" then equips[#equips+1]="/equipslot "..slot.." "..name end
    local rows={}
    for _,group in ipairs({head,equips,rest}) do for _,row in ipairs(group) do rows[#rows+1]=row end end
    while #rows>0 and rows[#rows]=="" do table.remove(rows) end
    local body=table.concat(rows,"\n")
    if #body>255 then self:Status("Too long for a WoW macro (255 bytes).",true); return end
    if body==old then return end
    self.preview:SetText(body)
    KT:StoreMacroBody(self.selectedMacro, body)
    self:RefreshQuickButtons(); self:UpdateDefaultButton()
    if type(name)=="string" and name~="" then self:Status("This macro now equips "..name..".") end
end
function MacroForge:RefreshEquip()
    if not self.equipSlot or not self.equipItem then return end
    local slot=self.equipSlotValue or 16
    local label="Slot"
    for _,entry in ipairs(self.equipSlots) do if entry[1]==slot then label=entry[2] end end
    -- Slots this macro already equips are marked in the slot list.
    self.equipSlot.value=slot; self.equipSlot.label:SetText(label)
    local current=self:EquipLine(slot)
    self.equipItem.value=current or ""
    self.equipItem.label:SetText(current and self:ColoredItem(current,self:EquipQuality(slot,current)) or "Choose an item")
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
-- The window and its pages are built in MacroHub.lua from these.
MacroForge.data = {classMacros = classMacros, racials = racials, genericMacros = genericMacros, addEntries = addEntries,
    classKey = classKey, raceKey = raceKey, classIcons = classIcons, nameList = nameList, sameEntry = sameEntry, normalizeBody = normalizeBody}
KT:RegisterModule("MacroForge", MacroForge)


local spellsChanged=CreateFrame("Frame")
spellsChanged:RegisterEvent("SPELLS_CHANGED")
spellsChanged:SetScript("OnEvent",function()
    if KT.dbReady and MacroForge.frame and MacroForge.frame:IsShown() and not InCombatLockdown() then
        MacroForge:RenderList();MacroForge:UpdateBulkInfo()
    end
end)
