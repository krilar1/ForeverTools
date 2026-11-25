local _,FT=...
-- Settings search on the /ft home window: finds pages and individual settings
-- by name or keyword, then opens the page that holds them.
local Search={}
local function profiles() FT:OpenModule("Profiles") end
local index={
    {"Macros","macro builder templates ranks mouseover combo","MacroForge","macros"},
    {"Buff reminders","self buff reminder missing buffs weapon enchant rage mana energy power shout enough","BuffReminder","buffs"},
    {"Group buff reminders","group party raid dungeon buffs missing","BuffGroup","party",find="Group reminders"},
    {"Where reminders show","reminder show in open world city cities inn dungeon raid pvp battleground arena condition","BuffReminder","buffs",find="Show in"},
    {"Low-rank alerts","rank downrank low rank buffs trainer","BuffRanks","buffs",find="Low-rank alerts"},
    {"Low-rank marker on action bars","rank downrank marker action bar outdated","BuffRanks","buffs",find="Marker on bars"},
    {"Ignore rank 1","rank one downrank","BuffRanks","buffs",find="Ignore rank 1"},
    {"FPS counter","fps frames framerate counter performance","QualityOfLife","fps"},
    {"Appearance","appearance look fonts colors colours theme","Appearance","skins"},
    {"Fonts","font fonts manager size outline text inter","FontManager","fonts"},
    {"Cooldown numbers","cooldown numbers color grey font","FontManager","fonts"},
    {"Unit frames","unit frames unitframe class colors health bar player target focus","UnitColors","character"},
    {"Dispel glow","dispel debuff cleanse purify decurse remove curse poison disease magic glow outline highlight color colour party","DispelGlow","Spell_Holy_DispelMagic"},
    {"Game resource bars","personal resources resource display bars health energy rage mana combo points order move swap text percent number duplicate","PersonalResource","Ability_Rogue_SliceDice"},
    {"Druid mana bar","druid mana bar bear cat form shapeshift energy rage third bar player frame","DruidMana","Ability_Racial_BearForm"},
    {"Skins","dark mode darkmode skin border outline action bars buttons buffs debuffs bags micro menu minimap gryphons totem stance xp reputation player target focus frame cast bar swing timer weapon tooltip tooltips dialog npc gossip quest merchant vendor trade mail trainer flight loot popup parchment pvp trinket nearby enemies enemy alert battleground timer unit frames groups","IconStyles","skins"},
    {"Chat","chat social tabs side buttons input box","Chat","chat"},
    {"Chat font","chat font size outline","Chat","chat"},
    {"Clickable chat links","url link links copy web address","Chat","chat",find="Clickable links"},
    {"Tooltip","tooltip target guild health bar position move font","Tooltip","tooltip"},
    {"Targeted by","targeted by who targets me targeting tooltip raid battleground enemies","Tooltip","tooltip"},
    {"Tooltip IDs","spell id item id quest achievement ids","Tooltip","spellID"},
    {"Tooltip layout","tooltip layout order name race class level guild faction target line preview builder","Tooltip","tooltip",find="Layout"},
    {"Faction icon or text","faction icon text horde alliance badge color tooltip","Tooltip","tooltip",find="Faction"},
    {"Faction-colored guild name","guild color horde alliance faction tooltip","Tooltip","tooltip",find="Guild in faction color"},
    {"Guild rank","guild rank officer member tooltip","Tooltip","tooltip"},
    {"Mouse-wheel casting","mouse wheel scroll casting mouseover bindings keybind custom keybinds","CustomKeybinds","keybind"},
    {"System","system settings general merchant","System","generic"},
    {"On-screen info","on-screen screen info hud fps leveling flight timer progress bar minimap quests loot rolls move","SystemDisplay","fps"},
    {"Keybinds","keybinds keys bind binding","Keybinds","keybind"},
    {"Welcome message","welcome login message chat","SystemGeneral","welcome"},
    {"What's new","whats new changelog updates popup","SystemGeneral","welcome"},
    {"Backups and restore","backup backups copy keybinds action bars spell binds restore save undo revert snapshot session history","SystemKeybinds","profiles"},
    {"Spell binds","spell binds bind key keys role interrupt taunt dispel bindpad hidden bar","SpellBinds","INV_Misc_Key_13"},
    {"Totems","totem totems shaman range minimap circle reach left behind forgotten out of range warning pull","Totems","Spell_Nature_StoneSkinTotem"},
    {"Move elements","move elements movers unlock drag frames position anchors","Movers","move"},
    {"Macro guide","macro guide help conditions mouseover focus castsequence modifier shift stance stopcasting startattack examples syntax how to write macros","MacroGuide","INV_Misc_Book_03"},
    {"Move game windows","moveall move anything windows drag character frame spellbook talents calendar quest log social bank vendor mailbox trainer professions reset position blizzard frames world refresh notice shard progress bar","MoveWindows","INV_Misc_Map_01"},
    {"First-time setup","setup wizard preset welcome start","SystemGeneral","INV_Misc_Book_09",find="First-time tour"},
    {"Reset all settings","reset defaults restore clear","SystemGeneral","reset"},
    {"ForeverTools minimap button","minimap icon button","SystemMinimap","map"},
    {"Minimap coordinates","coordinates coords position","SystemMinimap","map"},
    {"Reagent reminder (low on candles, Ankh, runes)","reagent reagents candle candles ankh rune runes teleport portal seed seeds powder poison poisons vendor buy low city inn","BuffReminder","buffs",find="Reagents"},
    {"Stealth shadows","stealth prowl shadowmeld vignette shadow dark screen edges hidden rogue druid","SystemStealth","Spell_Shadow_Twilight",find="Shadows while stealthed"},
    {"Poised glow on energy bar","poised energy bar glow ready rogue druid cat cost cheaper opener electric spark","SystemPoised","Spell_Nature_LightningShield"},
    {"Talent point reminder","talent talents points unspent spend level leveling","BuffReminder","buffs",find="Talent points"},
    {"Camp items reminder (tent, sleeping bag)","tent sleeping bag cozy camp camping campfire rested well-rested boosted rest bonus xp experience leveling","BuffReminder","buffs",find="Camp items"},
    {"Move elements in the game menu","game menu escape esc button move elements","SystemGeneral","general"},
    {"Rings of addon minimap buttons","minimap ring rings gold dark addon button border","SystemMinimap","map",find="Rings in the group"},
    {"Keep minimap buttons outside the group","minimap keep exclude outside group button journal single","SystemMinimap","map",find="Keep on the minimap"},
    {"Travel points on the world map","map world zeppelin zeppelins boat boats ship tram deeprun portal travel dock dungeon dungeons raid raids entrance entrances instance pins airship flight master flight path taxi","SystemMinimap","map",find="Boats, zeppelins and tram"},
    {"Group minimap buttons","minimap icons collect gather addon buttons menu horizontal vertical row column","SystemMinimap","map"},
    {"Set role when joining a group","role tank healer damage group auto","SystemGameplay","Ability_Warrior_DefensiveStance"},
    {"Interrupt bar","interrupt kick pummel shield bash earth shock counterspell hammer of justice silence spell lock bash cooldown party raid group tracker announce say chat message kicked","Interrupts","Ability_Kick"},
    {"Keep chat after reload","chat history keep reload relog log in scroll back earlier messages","Chat","chat"},
    {"Thank for buffs","thank thanks buff emote auto automatic stranger","Chat","Spell_Holy_PowerWordShield"},
    {"Combat logging","combat log logging warcraft logs wcl warcraftlogs raid dungeon advanced combatlog","SystemCombatLog","INV_Misc_Book_11"},
    {"Hide error messages","error errors red text spam out of range not enough rage energy mana moving interrupted ui errors frame","SystemErrors","Ability_Rogue_Disguise"},
    {"Move loot rolls","loot roll need greed position move","SystemQuests","move"},
    {"Flight timer","flight taxi flying countdown timer","FlightTimer","Ability_Mount_Wyvern_01"},
    {"Leveling stats","xp experience per hour time to level kills leveling rested background","Leveling","Spell_ChargePositive"},
    {"Faster looting","fast loot looting auto loot speed quick corpse","SystemMerchant","INV_Misc_Bag_10"},
    {"Soft reserves (custom)","soft reserve sr softres reserves raid loot import guild website /ft sr","SoftRes","INV_Misc_Note_06",find="Soft reserves"},
    {"Auto-sell grey items","vendor merchant sell junk grey gray","SystemMerchant","INV_Misc_Coin_05"},
    {"Poison reminder","rogue poison weapon main hand off hand missing reminder","BuffReminder","Ability_Poisons",find="Main hand",only={ROGUE=true,SHAMAN=true}},
    {"Show key when interface is hidden","hide show interface ui alt-z key hint message screenshot","SystemGeneral","INV_Misc_Eye_01"},
    {"Auto-repair","vendor merchant repair durability guild funds","SystemMerchant","Trade_BlackSmithing"},
    {"Show Lua errors","lua errors script errors troubleshooting","SystemGeneral","errors"},
    {"Bug report","bug report error copy issue troubleshooting","SystemGeneral","errors"},
    {"Profiles","profile save load switch copy export import undo restore used by","\001profiles","profiles"},
    {"Short key text","short key keybind text hotkey hotkeys action button shift ctrl mouse s-1 c-6 mouse5 compact","SystemKeybinds","keybind"},
    {"Quick keybind mode","kb /kb keybind keybinds bind hotkey hotkeys action bar keys quick","SystemKeybinds","keybind"},
    {"Export keybinds","keybind keybinds bindings keys export import profile action bar","\001profiles","keybind"},
    {"Rename profile","rename profile name change","\001profiles","profiles"},
    {"Icons for unlearned spells","icon unlearned spell level 1 bars question mark macro","MacroSettings","macros"},
    {"Quest tracker at login","quest objectives tracker collapsed closed open hide hidden login reload","SystemQuests","INV_Misc_Note_01"},
    {"Death glow","death glow ghost dead grey gray screen effect ffxdeath bloom","SystemDeath","Spell_Holy_Resurrection"},
    {"Buff notice look","buff reminder style look icon only icon text bar size color outline transparency pulse own position weakaura","BuffLook","buffs",find="Look"},
    {"Food buff reminder","food well fed eat buff missing xp experience kills leveling reminder","BuffReminder","buffs",find="XP food"},
    {"Always-sell marks","mark item always sell autosell auto sell merchant vendor hotkey key coin junk list","SellMarks","INV_Misc_Coin_01"},
    {"Action bars on mouseover","mouseover fade hide action bar bars show hover hidden","ActionFade","Spell_Holy_Heal"},
    {"Trade log","trade trades log history traded items gold player who when record","TradeLog","INV_Misc_Note_02"},
    {"Item locks","lock item protect padlock keep safe delete mail trade sell merchant vendor hotkey key list","ItemLock","INV_Misc_Key_03"},
    {"Show your target on the minimap","minimap target tracking track arrow dot where is my target","SystemMinimap","Ability_Hunter_SniperShot"},
    {"Extra game options","sharpness sharpen sharp grass foliage ground clutter density distance weather rain snow terrain detail lod scenery glow bloom spell queue window cvar console graphics","GameTweaks","INV_Misc_Spyglass_03"},
    {"Update macros (new poisons, mana gems, weapons)","update macros new poison rank mana gem weapon swap equipslot ask automatically sinister strike backstab ambush dagger sword","MacroSettings","macros",find="Update macros"},
    {"Equip an item in a macro","equipslot equip weapon swap switch macro gear item slot","MacroForge","macros"},
    {"Buff reminders in combat","combat fight battle shout remind in combat warrior rage buff notice during combat","BuffReminder","buffs",find="In combat"},
    {"Buff notice timer","hide notice after seconds timer fade reminder","BuffLook","buffs",find="Hide notice after"},
    {"Skin templates","skin template save look preset theme rename delete","IconStyles","skins",find="Apply template to all areas"},
    {"Rare alerts","rare elite spawn alert notice sound vignette","RareAlert","Ability_Hunter_SniperShot"},
    {"Threat meter","threat aggro tank meter percent target portrait damage meter where dungeons raids instance","Threat","Ability_Warrior_DefensiveStance"},
    {"Loot and merchant","merchant vendor sell repair loot","SystemMerchant","INV_Misc_Coin_02"},
    {"Damage meter font","damage meter font text size outline dps","FontManager","fonts",find="Damage meter"},
    {"Combat","combat alerts threat rare totems role","SystemCombat","Ability_Warrior_DefensiveStance"},
    {"PvP","pvp battleground bg arena queue","PvP","INV_BannerPVP_01"},
    {"Bags","bags bag bank banker dialog gossip skip gold money alts characters baganator bank view inventory","BagsHub","INV_Misc_Bag_08"},
    {"Gold tooltip","gold money silver copper alts characters total wealth","BagsGeneral","INV_Misc_Coin_02"},
    {"Quivers and soul bags on their own row","quiver ammo pouch soul bag shard herb reagent special bag row line combined hide","BagsGeneral","INV_Misc_Quiver_02"},
    {"Bank view","bank banker view remote alts other characters bags","BagsGeneral","INV_Misc_Bag_08"},
    {"Item counts","item count counts how many alts bank guild bank warband tooltip inventory","ItemCounts","INV_Misc_Note_04"},
    {"Characters (bags)","characters alts forget remember bags gold","BagsCharacters","character",find="Remember my characters"},
    {"Bag order","bag order sort sorting layout reverse flip direction corner clean up cleanup new items loot backpack last bag","BagsOrder","INV_Misc_Bag_10"},
    {"Enemy alerts","stealth rogue druid prowl vanish shadowmeld invisible enemy alert warning pvp spy gank kill death tracker kd wins losses score","EnemyAlerts","Ability_Stealth"},
    {"Marked players","mark marked kos kill on sight kill-list killlist guild enemy player grudge rival pvp alert by name","EnemyMarks","Ability_Hunter_SniperShot"},
    {"Nearby enemies","nearby enemies enemy players list icons pvp radar","EnemyNearby","INV_Misc_Spyglass_02"},
    {"GatherMate in the map menu","gathermate gather mate map filter herbs minerals mining ore fishing treasure nodes world map funnel","SystemMinimap","INV_Misc_Herb_10",find="GatherMate in the map menu"},
    {"Herbs and minerals","herbs minerals herb mining ore find herbs find minerals tracking switch switcher gathering herbalism minimap auto","SystemMinimap","INV_Misc_Flower_02",find="Herbs and minerals"},
    {"Buff times","buff buffs debuff debuffs minutes hours seconds time left duration timer countdown numbers target focus stun well rested sleeping bag tooltip exact","SystemBuffTimes","INV_Misc_PocketWatch_01"},
    {"Targeted alert","targeted target targeting me aggro enemy alliance horde player warning alert gank pvp","TargetAlert","Ability_Hunter_SniperShot"},
    {"Auto release","auto release spirit repop death dead battleground bg graveyard pvp","AutoRelease","Spell_Holy_Resurrection"},
    {"Trinket menu","trinket trinkets swap equip menu cooldown pvp medallion insignia use","Trinkets","INV_Misc_PocketWatch_01"},
    {"Enemy cooldowns","enemy cooldowns omnicd trinket racial blind vanish ice block divine shield psychic scream fear stun used tracker pvp arena battleground","EnemyCooldowns","Spell_Holy_BorrowedTime"},
    {"Diminishing returns","dr diminishing returns crowd control cc stun fear root silence immune pvp arena target of target tot grow direction","Diminish","Spell_Frost_FrostNova"},
    {"Battleground timer","battleground bg queue pop enter timer countdown time left invitation pvp","QueueTimer","INV_Misc_PocketWatch_01"},
    {"Smart interact key","interact target key restedxp rxp quest item keybind one key","SmartKey","INV_Misc_Key_10"},
    {"Cooldown reminders","cooldown racial trinket reminder use elite rare pull blood fury berserking","CooldownReminder","buffs"},
    {"Leveling stats line up","leveling xp align left right center edge move","Leveling","Spell_ChargePositive",find="Line up"},
    {"Eat & Drink macro","food water eat drink mage conjured macro","MacroForge","macros",find="Eat & Drink",only={MAGE=true}},
    {"Hidden macros","hide macro hidden filter blacklist show again restore","MacroHidden","macros"},
    {"PvP macros","pvp macros focus mouseover sap blind polymorph fear kick interrupt counterspell pummel opener cheap shot stance charge intercept ice block powershift arena battleground","MacroPvP","Ability_Warrior_Challange"},
    {"Make room for macros","make room full macro slots delete add all space","MacroSettings","macros",find="Delete Character macros"},
    {"Macro placements","macro action bar placement slots layout profile save","\001profiles","macros"},
    {"Profile for new characters","new character profile alt","\001profiles","profiles"},
    {"Default settings","default reset blizzard fresh start clean profile","\001profiles","reset"},
}
-- Every setting on the System pages too, by its own name: opens its page
-- and points at it. Added once, the first time you search.
-- Two names that only differ in case or punctuation are the same entry
-- ("LayerSwap hosting" and "LayerSwap: hosting").
local function norm(label) return (label:lower():gsub("[^%w]","")) end
local function known(label)
    label=norm(label)
    for _,e in ipairs(index) do if norm(e[1])==label then return true end end
end
function Search:AddPageSettings()
    if self.pagesAdded then return end
    self.pagesAdded=true
    -- Every page in the menu groups, by its own title.
    for _,hub in ipairs(FT.hubs or {}) do
        for _,page in ipairs(hub.pages or {}) do
            local module,title,icon=page[1],page[2],page[3]
            if type(title)=="string" and type(module)=="string" and not known(title) then
                index[#index+1]={title,(hub.title or ""):lower(),module,type(icon)=="string" and icon or "generic",sub=hub.title}
            end
        end
    end
    -- Each game option on Extra game options, by its name and help text.
    local G=FT.modules.GameTweaks
    for _,o in ipairs(G and G.options or {}) do
        if type(o.title)=="string" and not known(o.title) then
            index[#index+1]={o.title,((o.tip or "").." "..(o.cvar or "").." game option"):lower(),"GameTweaks",o.icon or "INV_Misc_Spyglass_03",find=o.title,tab=o.section,sub="Extra game options"}
        end
    end
    -- Ready-made macros (Generic), by name: opens Macros.
    local M=FT.modules.MacroForge
    local okG,generic=pcall(function() return M and M:GenericEntries() end)
    for _,e in ipairs(okG and type(generic)=="table" and generic or {}) do
        if type(e.name)=="string" and not known(e.name.." macro") then
            index[#index+1]={e.name.." macro",("macro generic "..(e.note or "")):lower(),"MacroGeneric","macros",find=e.name,sub="Macros"}
        end
    end
    local okP,pvpList=pcall(function() return M and M.PvPSharedEntries and M:PvPSharedEntries() end)
    for _,e in ipairs(okP and type(pvpList)=="table" and pvpList or {}) do
        if type(e.name)=="string" and not known(e.name.." macro") then
            index[#index+1]={e.name.." macro",("macro pvp "..(e.note or "")):lower(),"MacroPvP","macros",find=e.name,sub="Macros"}
        end
    end
    local sys=FT.modules.System
    for _,page in ipairs(sys and sys.pages or {}) do
        for _,item in ipairs(page.items or {}) do
            local label=type(item[2])=="string" and item[2]~="Preview" and item[2]
            -- Another class's setting (Poised on a warrior) is not offered.
            if label and item.only then local _,class=UnitClass("player"); if class and not item.only[class] then label=nil end end
            if label then
                if not known(label) then index[#index+1]={label,(type(item[4])=="string" and item[4]:lower() or "").." "..(page.title or ""):lower(),page.key,item[3] or "generic",find=label,sub=page.title} end
            end
        end
    end
end
function Search:Results(query)
    self:AddPageSettings()
    query=(query or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if query=="" then return {} end
    local starts,contains={},{}
    for i,entry in ipairs(index) do
      -- Another class's page never shows (Totems on a warrior), nor another
      -- class's single setting (Eat & Drink is a mage macro).
      if FT:ForMyClass(entry[3]) and (not entry.only or entry.only[select(2,UnitClass("player")) or ""]) then
        local label=entry[1]:lower()
        -- The same icon as the page has in its group's list.
        local hub,at=FT:HubOf(entry[3])
        local pageIcon=hub and hub.pages[at] and hub.pages[at][3]
        if type(pageIcon)=="function" then pageIcon=pageIcon() end
        local icon=FT:IconPath(pageIcon or entry[4])
        local item={value=i,label=entry[1],icon=icon,tooltip=entry.sub and ("In "..entry.sub) or nil}
        if label:sub(1,#query)==query then starts[#starts+1]=item
        elseif label:find(query,1,true) or entry[2]:find(query,1,true) then contains[#contains+1]=item end
      end
    end
    for _,item in ipairs(contains) do starts[#starts+1]=item end
    return starts
end
function Search:Open(i)
    local entry=index[i]; if not entry then return end
    self.box:SetText(""); self.box:ClearFocus()
    if entry[3]=="\001profiles" then profiles() else FT:OpenModule(entry[3]) end
    -- Point at the setting itself: scroll to it and flash a gold frame.
    local find=entry.find or entry[1]
    C_Timer.After(.15,function()
        local m=FT.modules[entry[3]]
        local root=(m and m.frame) or (entry[3]=="\001profiles" and FT.modules.Profiles and FT.modules.Profiles.frame)
        if entry.tab and m and m.ShowSection then m:ShowSection(entry.tab) end
        if root and root:IsShown() then FT:FocusSetting(root,find) end
    end)
end
function Search:Show()
    local menu=FT.choiceMenu
    if menu and menu:IsShown() and menu.owner==self.box then menu:Hide() end
    self.results=self:Results(self.box:GetText())
    if #self.results==0 then
        self.none:SetShown(self.box:GetText()~="")
        return
    end
    self.none:Hide()
    FT:ShowChoices(self.box)
end
function Search:Attach(home)
    if self.box then return end
    local box=CreateFrame("EditBox",nil,home)
    self.box=box; box.alwaysIcons=true -- every result shows its page icon, also when they share one
    box:SetSize(220,26); box:SetPoint("TOPLEFT",24,-54)
    box:SetFont(FT.bodyFont,13,""); box:SetAutoFocus(false); box:SetTextInsets(26,24,0,0)
    FT:Panel(box); FT:Paint(box,{0.05,0.04,0.03,1},{0.29,0.24,0.15,1})
    local icon=box:CreateTexture(nil,"ARTWORK"); icon:SetSize(14,14); icon:SetPoint("LEFT",8,0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local placeholder=FT:Label(box,"Search settings",13); placeholder:SetPoint("LEFT",26,0); placeholder:SetTextColor(.6,.55,.46)
    self.none=FT:Label(home,"No matches",12); self.none:SetPoint("LEFT",box,"RIGHT",10,0); self.none:SetTextColor(.66,.59,.48); self.none:Hide()
    box.options=function() return self.results or {} end
    box.onSelect=function(value) self:Open(value) end
    box.menuWidth=300
    -- Ways out: the X in the box, Escape, a right-click on the box, or a
    -- click anywhere else in the window.
    local clear=CreateFrame("Button",nil,box); clear:SetSize(18,18); clear:SetPoint("RIGHT",-4,0)
    clear.tex=clear:CreateTexture(nil,"ARTWORK"); clear.tex:SetAllPoints(); clear.tex:SetTexture("Interface\\Buttons\\UI-StopButton")
    clear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight","ADD")
    clear:Hide()
    function self:Clear()
        local menu=FT.choiceMenu
        if menu and menu:IsShown() and menu.owner==box then menu:Hide() end
        box:SetText(""); box:ClearFocus(); self.none:Hide()
    end
    clear:SetScript("OnClick",function() self:Clear() end)
    FT:Tooltip(clear,"Clear search","Or press Escape, right-click the box, or click anywhere else in the window.")
    box:SetScript("OnMouseUp",function(_,button) if button=="RightButton" then self:Clear() end end)
    home:HookScript("OnMouseDown",function() if box:GetText()~="" then self:Clear() end end)
    box:SetScript("OnTextChanged",function(owner)
        local empty=owner:GetText()==""
        placeholder:SetShown(empty); clear:SetShown(not empty)
        self:Show()
    end)
    box:SetScript("OnEnterPressed",function() if self.results and self.results[1] then if FT.choiceMenu then FT.choiceMenu:Hide() end; self:Open(self.results[1].value) end end)
    box:SetScript("OnEscapePressed",function() self:Clear() end)
    home:HookScript("OnHide",function() box:SetText(""); box:ClearFocus() end)
    FT:Tooltip(box,"Search settings","Type a feature or setting, for example \"dark mode\", \"repair\" or \"xp\". Press Enter to open the first result. Clear it with the X, Escape or a right-click.")
end
FT:RegisterModule("Search",Search)
