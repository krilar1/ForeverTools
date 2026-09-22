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
        {"Holy Light", 11, "friendly", "spell_holy_holybolt"}, {"Flash of Light", 7, "friendly", "spell_holy_flashheal"}, {"Blessing of Might", 7, "friendly", "spell_holy_fistofjustice"}, {"Blessing of Wisdom", 6, "friendly", "spell_holy_sealofwisdom"}, {"Blessing of Protection", 3, "friendly", "spell_holy_sealofprotection"}, {"Cleanse", 1, "friendly", "spell_holy_renew"}, {"Lay on Hands", 3, "friendly", "spell_holy_layonhands"}, {"Redemption", 5, "friendly", "spell_holy_resurrection"}, {"Judgement", 6, "startattack", "spell_holy_righteousfury"}, {"Hammer of Justice", 4, "startattack", "spell_holy_sealofmight"}, {"Holy Strike", 1, "startattack", "inv_sword_2h_ashbringercorrupt"}, {"Seal of Righteousness", 8, "self", "ability_thunderbolt"}, {"Seal of Command", 5, "self", "ability_warrior_innerrage"}, {"Seal of Wisdom", 5, "self", "spell_holy_sealofwisdom"}, {"Seal of Light", 4, "self", "spell_holy_healingaura"}, {"Consecration", 5, nil, "spell_holy_innerfire"}, {"Divine Shield", 2, "self", "spell_holy_divineshield"}, {"Divine Intervention", 1, "friendly", "spell_holy_divineintervention"},
    },
    Priest = {
        {"Heal", 4, "friendly", "spell_holy_heal"}, {"Flash Heal", 7, "friendly", "spell_holy_flashheal"}, {"Renew", 10, "friendly", "spell_holy_renew"}, {"Power Word: Shield", 10, "friendly", "spell_holy_powerwordshield"}, {"Dispel Magic", 2, "friendly", "spell_holy_dispelmagic"}, {"Cure Disease", 1, "friendly", "spell_holy_nullifydisease"}, {"Levitate", 1, "friendly", "spell_holy_layonhands"}, {"Resurrection", 5, "friendly", "spell_holy_resurrection"}, {"Mind Blast", 9, nil, "spell_shadow_unholyfrenzy"}, {"Shadow Word: Pain", 8, nil, "spell_shadow_shadowwordpain"}, {"Mind Flay", 6, nil, "spell_shadow_siphonmana"}, {"Psychic Scream", 4, nil, "spell_shadow_psychicscream"}, {"Silence", 1, nil, "spell_shadow_impphaseshift"},
    },
    Rogue = {
        {"Sinister Strike", 9, "startattack", "spell_shadow_ritualofsacrifice"}, {"Backstab", 9, "startattack", "ability_backstab"}, {"Eviscerate", 9, "startattack", "ability_rogue_eviscerate"}, {"Kick", 1, "startattack", "ability_kick"}, {"Gouge", 5, "startattack", "ability_gouge"}, {"Sap", 3, nil, "ability_sap"}, {"Blind", 1, nil, "spell_shadow_mindsteal"}, {"Vanish", 3, "self", "ability_vanish"}, {"Garrote", 6, "startattack", "ability_rogue_garrote"}, {"Rupture", 6, "startattack", "ability_rogue_rupture"}, {"Ambush", 6, "startattack", "ability_rogue_ambush"}, {"Cheap Shot", 1, "startattack", "ability_cheapshot"}, {"Kidney Shot", 2, "startattack", "ability_rogue_kidneyshot"}, {"Stealth", 4, "self", "ability_stealth"}, {"Sprint", 3, "self", "ability_rogue_sprint"}, {"Evasion", 1, "self", "spell_shadow_shadowward"},
    },
    Shaman = {
        {"Lightning Bolt", 10, nil, "spell_nature_lightning"}, {"Chain Lightning", 6, nil, "spell_nature_chainlightning"}, {"Earth Shock", 7, nil, "spell_nature_earthshock"}, {"Flame Shock", 6, nil, "spell_fire_flameshock"}, {"Frost Shock", 7, nil, "spell_frost_frostshock"}, {"Healing Wave", 10, "friendly", "spell_nature_magicimmunity"}, {"Lesser Healing Wave", 6, "friendly", "spell_nature_healingwavelesser"}, {"Purge", 2, nil, "spell_nature_purge"}, {"Chain Heal", 3, "friendly", "spell_nature_healingwavegreater"}, {"Ghost Wolf", 1, "self", "spell_nature_spiritwolf"}, {"Lightning Shield", 7, "self", "spell_nature_lightningshield"}, {"Windfury Weapon", 3, "self", "spell_nature_cyclone"},
    },
    Warlock = {
        {"Shadow Bolt", 11, nil, "spell_shadow_shadowbolt"}, {"Corruption", 7, nil, "spell_shadow_abominationexplosion"}, {"Curse of Agony", 6, nil, "spell_shadow_curseofsargeras"}, {"Fear", 3, nil, "spell_shadow_possession"}, {"Drain Life", 6, nil, "spell_shadow_lifedrain02"}, {"Immolate", 8, nil, "spell_fire_immolation"}, {"Life Tap", 6, "self", "spell_shadow_burningspirit"}, {"Howl of Terror", 2, nil, "spell_shadow_deathscream"}, {"Death Coil", 4, nil, "spell_shadow_deathcoil"}, {"Banish", 2, nil, "spell_shadow_cripple"}, {"Shadow Ward", 4, "self", "spell_shadow_antishadow"},
    },
    Warrior = {
        {"Heroic Strike", 9, "startattack", "ability_rogue_ambush"}, {"Sunder Armor", 5, "startattack", "ability_warrior_sunder"}, {"Overpower", 4, "startattack", "ability_meleedamage"}, {"Charge", 3, "startattack", "ability_warrior_charge"}, {"Pummel", 1, "startattack", "inv_gauntlets_04"}, {"Thunder Clap", 7, "startattack", "ability_thunderclap"}, {"Cleave", 6, "startattack", "ability_warrior_cleave"}, {"Rend", 8, "startattack", "ability_gouge"}, {"Mocking Blow", 5, "startattack", "ability_warrior_punishingblow"}, {"Disarm", 1, "startattack", "ability_warrior_disarm"}, {"Revenge", 6, "startattack", "ability_warrior_revenge"}, {"Slam", 6, "startattack", "ability_warrior_decisivestrike"}, {"Intercept", 3, "startattack", "ability_rogue_sprint"}, {"Mortal Strike", 4, "startattack", "ability_warrior_savageblow"}, {"Bloodthirst", 6, "startattack", "spell_nature_bloodlust"}, {"Execute", 6, "startattack", "inv_sword_48"}, {"Hamstring", 4, "startattack", "ability_shockwave"}, {"Shield Bash", 1, "startattack", "ability_warrior_shieldbash"},
    },
}

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
    elseif entry.name=="Redemption" or entry.name=="Resurrection" then
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
    Druid = "Ability_Druid_Maul", Hunter = "INV_Weapon_Bow_07", Mage = "INV_Staff_13",
    Paladin = "INV_Hammer_01", Priest = "INV_Staff_30", Rogue = "INV_ThrowingKnife_04",
    Shaman = "Spell_Nature_BloodLust", Warlock = "Spell_Nature_Drowsy", Warrior = "INV_Sword_27",
}
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
    return entries
end

function MacroForge:IconForEntry(entry)
    if entry.category == "classPicker" or entry.category == "generic" then return "Interface\\Icons\\" .. (entry.icon or "INV_MISC_QUESTIONMARK") end
    local texture
    if C_Spell and C_Spell.GetSpellTexture then texture = C_Spell.GetSpellTexture(entry.name)
    elseif GetSpellTexture then texture = GetSpellTexture(entry.name) end
    return texture or (entry.icon and "Interface\\Icons\\" .. entry.icon) or 134400
end
function MacroForge:ClassIcon(className)
    return "Interface\\Icons\\" .. (classIcons[className] or "INV_Misc_QuestionMark")
end
function MacroForge:MacroName(entry)
    return entry.class and " " or string.sub(entry.name, 1, 16)
end

local function normalizeBody(body) return (body or ""):gsub("\r\n", "\n"):gsub("\n+$", "") end
function MacroForge:EntryExists(entry, body)
    if not entry.class then return (GetMacroIndexByName(self:MacroName(entry)) or 0) > 0 end
    local _, count = GetNumMacros()
    for index = (MAX_ACCOUNT_MACROS or 120) + 1, (MAX_ACCOUNT_MACROS or 120) + count do
        local _, _, existing = GetMacroInfo(index)
        if existing and normalizeBody(existing) == normalizeBody(body) then return true, index end
    end
    return false
end

function MacroForge:Status(message, isError)
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
        StaticPopup_Show("FOREVERTOOLS_FOREIGN_SINGLE")
        return false
    end
    local body = self:BuildMacro(entry)
    if #body > 255 then self:Status("This macro is too long for WoW's 255-character limit.", true); return false end
    local name = self:MacroName(entry)
    local exists, existingIndex = self:EntryExists(entry, body)
    if exists then
        if entry.class and existingIndex then
            EditMacro(existingIndex, " ", 134400, body)
            self:Status(entry.name .. " already exists; blank name and automatic icon applied.")
        else self:Status(entry.name .. " already exists — skipped to protect it.", true) end
        return false
    end
    local scope = entry.class and "character" or self.scope
    local accountCount, characterCount = GetNumMacros()
    local limit = scope == "character" and (MAX_CHARACTER_MACROS or 18) or (MAX_ACCOUNT_MACROS or 120)
    local count = scope == "character" and characterCount or accountCount
    if count >= limit then self:Status((scope == "character" and "Character" or "General") .. " macro tab is full.", true); return false end
    local macroIndex = CreateMacro(name, 134400, body, scope == "character")
    if macroIndex then
        local destination = scope == "character" and "Character" or "General"
        self:Status("Added " .. entry.name .. " to " .. destination .. " macros.")
        if not self.bulkAdding then KT:Toast("Added to " .. string.lower(destination) .. " macros") end
        return true
    end
    self:Status("WoW could not create that macro.", true)
    return false
end

function MacroForge:BulkEntries(className)
    className = className or self:BulkClass()
    local entries = {}
    addEntries(entries, classMacros[className], className, nil, "class")
    return entries
end

function MacroForge:CreateBulk(className)
    if InCombatLockdown() then self:Status("Leave combat before adding macros.", true); return end
    local rank, mouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    local created, skipped = 0, 0; self.bulkAdding = true
    for _, entry in ipairs(self:BulkEntries(className)) do
        if self:CreateEntry(entry, true) then created = created + 1 else skipped = skipped + 1 end
    end
    self.bulkAdding = nil; self.selectedRank, self.mouseover = rank, mouseover
    self:Status(string.format("%d class macros added to Character; %d skipped (existing or no room).", created, skipped), skipped > 0)
    if created > 0 then KT:Toast(string.format("Added %d character macros", created)) end
    self:UpdateBulkInfo()
end

local function sameEntry(a, b)
    return a and b and a.name == b.name and a.class == b.class and a.race == b.race
end

function MacroForge:UpdateFilters()
    for key, button in pairs(self.filterButtons) do KT:SetSelected(button, self.filter == key) end
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
                self.rows[shown] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 0, -(shown - 1) * 48)
            button.entry = entry
            button.icon:SetTexture(self:IconForEntry(entry))
            button.title:SetText(entry.name)
            button.meta:SetText(entry.category == "classPicker" and "View class macros" or entry.class or entry.race or "Generic")
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
    local forced = entry.class ~= nil
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
    if self.selectedMacro and self.selectedMacro.class then self:UpdatePreview(); return end
    self.scope = scope
    KT.db.macroScope = scope
    self:UpdatePreview()
end
function MacroForge:UpdateBulkInfo()
    local _, count = GetNumMacros()
    local free = math.max(0, (MAX_CHARACTER_MACROS or 18) - count)
    local needed = 0
    local oldRank, oldMouseover = self.selectedRank, self.mouseover
    self.selectedRank, self.mouseover = "max", self.bulkMouseover == true
    for _, entry in ipairs(self:BulkEntries()) do
        if not self:EntryExists(entry, self:BuildMacro(entry)) then needed = needed + 1 end
    end
    self.selectedRank, self.mouseover = oldRank, oldMouseover
    local className = self:BulkClass()
    local icon = classIcons[className] or "INV_Misc_QuestionMark"
    self.bulkStatus:SetText("Browsing |TInterface\\Icons\\" .. icon .. ":18:18|t " .. className .. " macros")
    self.bulkButton.label:SetText("Add all |TInterface\\Icons\\" .. icon .. ":18:18|t " .. className .. " macros")
    self.bulkMouseoverButton.label:SetText(self.bulkMouseover and "Bulk Mouseover: On" or "Bulk Mouseover: Off")
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
    StaticPopupDialogs.FOREVERTOOLS_BULK.text = needed > free
        and string.format("Not enough Character macro space for all %s macros.\n\nOnly available slots will be filled.", className)
        or string.format("Add all %s macros to Character macros?", className)
    if foreign then
        StaticPopupDialogs.FOREVERTOOLS_BULK.text = "WARNING: You are a " .. classKey() .. ", not a " .. className .. ".\n\n" .. StaticPopupDialogs.FOREVERTOOLS_BULK.text
    end
    StaticPopup_Show("FOREVERTOOLS_BULK")
end
function MacroForge:CreateUI()
    if self.uiReady then return end
    if self.frame then self.frame:Hide() end
    self.rows = {}
    local frame = KT:Window("ForeverToolsMacros", "ForeverTools | Macros", 800, 650)
    self.frame = frame
    local hint = KT:Label(frame, "", 14)
    hint:SetPoint("TOPLEFT", 24, -57)
    local bulkPanel = CreateFrame("Frame", nil, frame)
    bulkPanel:SetSize(752, 58); bulkPanel:SetPoint("TOPLEFT", 24, -82); KT:Panel(bulkPanel)
    self.bulkStatus = KT:Label(bulkPanel, "", 15, true); self.bulkStatus:SetPoint("LEFT", 14, 0); self.bulkStatus:SetWidth(250)
    self.bulkMouseoverButton = KT:QuietButton(bulkPanel, "", 190, 34, "mouseover")
    self.bulkMouseoverButton:SetPoint("LEFT", self.bulkStatus, "RIGHT", 8, 0)
    self.bulkMouseoverButton:SetScript("OnClick", function() self.bulkMouseover = not self.bulkMouseover; self:UpdateBulkInfo() end)
    KT:Tooltip(self.bulkMouseoverButton, "Bulk Mouseover", "When enabled, friendly and hostile target spells use mouseover where the spell supports it. Area, self-only and queued attacks stay unchanged. Tip: Enable Mouseover Cast in the game Combat settings.")
    self.deleteButton = KT:QuietButton(bulkPanel, "Delete my class macros", 222, 34, "delete")
    self.deleteButton:SetPoint("TOPRIGHT", -12, -12)
    self.deleteButton:SetScript("OnClick", function() self:RequestDeleteClass() end)
    KT:Tooltip(self.deleteButton, "Delete character macros", "Deletes only unchanged templates for your current class. General, racial and edited macros stay safe.")
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
    self.search = CreateFrame("EditBox", nil, frame)
    self.search:SetSize(414, 28); self.search:SetPoint("TOPRIGHT", -24, -156)
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
    scroll:SetPoint("TOPLEFT", 24, -198); scroll:SetSize(308, 388)
    self.list = CreateFrame("Frame", nil, scroll); self.list:SetWidth(300); scroll:SetScrollChild(self.list)
    self.empty = KT:Label(self.list, "No matching macros.", 14); self.empty:SetPoint("TOPLEFT", 6, -8)
    local detail = CreateFrame("Frame", nil, frame)
    self.detail = detail
    detail:SetSize(414, 388); detail:SetPoint("TOPRIGHT", -24, -198); KT:Panel(detail)
    self.title = KT:Label(detail, "", 18, true); self.title:SetPoint("TOPLEFT", 16, -16); self.title:SetWidth(380)
    self.prevRank = KT:QuietButton(detail, "<", 28, 26); self.prevRank:SetPoint("TOPLEFT", 16, -52)
    self.prevRank:SetScript("OnClick", function() self:StepRank(-1) end)
    KT:Tooltip(self.prevRank, "Spell rank", "Choose a lower rank when it is useful for mana or spell behavior.")
    self.rankLabel = KT:Label(detail, "", 14); self.rankLabel:SetPoint("LEFT", self.prevRank, "RIGHT", 8, 0); self.rankLabel:SetWidth(84); self.rankLabel:SetJustifyH("CENTER")
    self.nextRank = KT:QuietButton(detail, ">", 28, 26); self.nextRank:SetPoint("LEFT", self.rankLabel, "RIGHT", 8, 0)
    self.nextRank:SetScript("OnClick", function() self:StepRank(1) end)
    KT:Tooltip(self.nextRank, "Spell rank", "Max rank is used by default.")
    self.mouseoverButton = KT:QuietButton(detail, "", 168, 26, "mouseover"); self.mouseoverButton:SetPoint("LEFT", self.nextRank, "RIGHT", 20, 0)
    self.mouseoverButton:SetScript("OnClick", function() self.mouseover = not self.mouseover; KT:StoreMacroBody(self.selectedMacro, self:BuildMacro(self.selectedMacro)); self:UpdatePreview() end)
    KT:Tooltip(self.mouseoverButton, "Mouseover", "Adds mouseover targeting where that spell supports it. The preview updates immediately.")
    self.previewArea = CreateFrame("ScrollFrame", nil, detail, "UIPanelScrollFrameTemplate")
    self.previewArea:SetSize(360, 100); self.previewArea:SetPoint("TOPLEFT", 16, -96)
    self.preview = CreateFrame("EditBox", nil, self.previewArea)
    self.preview:SetMultiLine(true); self.preview:SetAutoFocus(false)
    self.preview:SetFont(KT.bodyFont, 14, ""); self.preview:SetSize(352, 100)
    self.preview:SetTextInsets(6,6,6,6); KT:Panel(self.preview)
    self.previewArea:SetScrollChild(self.preview)
    self.preview:SetScript("OnTextChanged", function(box)
        local _, lines = box:GetText():gsub("\n", "")
        box:SetHeight(math.max(100, (lines + math.ceil(#box:GetText() / 48) + 1) * 17 + 12))
        if self.selectedMacro and not self.loadingPreview then
            KT:StoreMacroBody(self.selectedMacro, box:GetText())
            self:UpdateDefaultButton()
        end
    end)
    self.preview:SetScript("OnEditFocusLost", function() KT:FlushMacroRevision(self.selectedMacro) end)
    self.preview:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    self.preview:SetScript("OnCursorChanged", function(_, x, y, width, height)
        local top = -y; local offset = self.previewArea:GetVerticalScroll()
        if top < offset then self.previewArea:SetVerticalScroll(math.max(0, top))
        elseif top + height > offset + self.previewArea:GetHeight() then self.previewArea:SetVerticalScroll(top + height - self.previewArea:GetHeight()) end
    end)
    local advanced = KT:QuietButton(detail, "Advanced...", 280, 28, "generic")
    advanced:SetPoint("BOTTOMLEFT", 16, 156)
    advanced:SetScript("OnClick", function()
        KT:FlushMacroRevision(self.selectedMacro)
        KT.modules.MacroEditor:OpenEntry(self.selectedMacro, self:BuildMacro(self.selectedMacro))
    end)
    KT:Tooltip(advanced, "Advanced editor", "Build targeting and modifier conditions while keeping a local revision history. It does not change an installed macro until you use Add selected macro.")
    self.advancedButton = advanced
    self.defaultButton = KT:QuietButton(detail, "Default", 92, 28, "reset")
    self.defaultButton:SetPoint("LEFT", advanced, "RIGHT", 10, 0)
    self.defaultButton:SetScript("OnClick", function() self:RestoreDefault() end)
    KT:Tooltip(self.defaultButton, "Restore default", "Restores this macro's original template text. Your current local edit is kept in the save log.")
    self.scopeNote = KT:Label(detail, "", 13); self.scopeNote:SetPoint("BOTTOMLEFT", 16, 134); self.scopeNote:SetWidth(380)
    self.accountScope = KT:QuietButton(detail, "General macros", 183, 28, "general"); self.accountScope:SetPoint("BOTTOMLEFT", 16, 96)
    self.accountScope:SetScript("OnClick", function() self:ChooseScope("account") end)
    if self.accountScope.SetMotionScriptsWhileDisabled then self.accountScope:SetMotionScriptsWhileDisabled(true) end
    KT:Tooltip(self.accountScope, "General macros", function()
        return self.selectedMacro and self.selectedMacro.class
            and "Class-specific macros must be saved in the Character tab. Select a Generic macro to use the General tab."
            or "Add macro to general macro tab."
    end)
    self.characterScope = KT:QuietButton(detail, "Character macros", 189, 28, "character"); self.characterScope:SetPoint("LEFT", self.accountScope, "RIGHT", 10, 0)
    self.characterScope:SetScript("OnClick", function() self:ChooseScope("character") end)
    KT:Tooltip(self.characterScope, "Character macros", "Add macro to character tab.")
    local add = KT:AccentButton(detail, "Add selected macro", 382, 32, "add"); add:SetPoint("BOTTOM", 0, 52)
    add:SetScript("OnClick", function() if self.selectedMacro then KT.modules.MacroEditor:InstallEntry(self.selectedMacro, self:BuildMacro(self.selectedMacro)) end end)
    KT:Tooltip(add, "Add selected macro", "Adds macro to selected tab. If macro exist, you can choose to overwrite it.")
    self.bulkButton = KT:QuietButton(detail, "", 382, 28, "add"); self.bulkButton:SetPoint("BOTTOM", 0, 16)
    self.bulkButton:SetScript("OnClick", function() self:ConfirmBulk() end)
    KT:Tooltip(self.bulkButton, "Add all class macros", "Adds every macro for the class currently being browsed to Character macros.")
    self.status = KT:Label(frame, "", 14); self.status:SetPoint("BOTTOMLEFT", 24, 20); self.status:SetWidth(750)
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

