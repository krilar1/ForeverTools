local _,FT=...
local Reminder={missing={},elapsed=0,cycle=1}
-- Each class's long buffs: {name, watched by default, kind}. Only spells you
-- have learned are listed, so a spell this game does not have costs nothing.
-- Buffs of one kind replace each other (one armor, one aspect, one shield):
-- you pick one, and any of them being up counts. A fourth value of true
-- keeps a buff off the list while it still counts for its kind.
local choices={
    Druid={{"Mark of the Wild",true,"wild"},{"Gift of the Wild",false,"wild"},{"Thorns",false},{"Omen of Clarity",false}},
    Hunter={{"Aspect of the Hawk",true,"aspect"},{"Aspect of the Dragonhawk",false,"aspect"},{"Aspect of the Monkey",false,"aspect"},{"Aspect of the Viper",false,"aspect"},{"Aspect of the Wild",false,"aspect"},{"Aspect of the Beast",false,"aspect"},{"Trueshot Aura",false}},
    Mage={{"Arcane Intellect",true,"intellect"},{"Arcane Brilliance",false,"intellect"},{"Frost Armor",false,"armor"},{"Ice Armor",false,"armor"},{"Mage Armor",false,"armor"},{"Molten Armor",false,"armor"},{"Dampen Magic",false,"magic"},{"Amplify Magic",false,"magic"}},
    Paladin={{"Blessing of Might",true,"blessing"},{"Blessing of Wisdom",false,"blessing"},{"Blessing of Kings",false,"blessing"},{"Salvation",false,"salvation"},{"Mass Salvation",false,"salvation",true},{"Blessing of Light",false,"blessing"},{"Blessing of Sanctuary",false,"blessing"},{"Righteous Fury",true,"protection"}},
    Priest={{"Power Word: Fortitude",true,"fortitude"},{"Prayer of Fortitude",false,"fortitude"},{"Divine Spirit",false,"spirit"},{"Prayer of Spirit",false,"spirit"},{"Inner Fire",false},{"Shadow Protection",false,"shadow"},{"Prayer of Shadow Protection",false,"shadow",true},{"Shadowform",false},{"Touch of Weakness",false},{"Shadowguard",false}},
    Shaman={{"Lightning Shield",true,"shield"},{"Water Shield",false,"shield"}},
    Warlock={{"Demon Armor",true,"armor"},{"Demon Skin",false,"armor"},{"Fel Armor",false,"armor"},{"Soul Link",false}},
    Warrior={{"Battle Shout",true,"shout"},{"Commanding Shout",false,"shout"}},
}
local enchants={"Windfury Weapon","Flametongue Weapon","Rockbiter Weapon","Frostbrand Weapon"}
local fallbackTrees={
    Druid={"Balance","Feral Combat","Restoration"},Hunter={"Beast Mastery","Marksmanship","Survival"},
    Mage={"Arcane","Fire","Frost"},Paladin={"Holy","Protection","Retribution"},
    Priest={"Discipline","Holy","Shadow"},Rogue={"Assassination","Combat","Subtlety"},
    Shaman={"Elemental","Enhancement","Restoration"},Warlock={"Affliction","Demonology","Destruction"},
    Warrior={"Arms","Fury","Protection"},
}
local treeIcons={
    Druid={"Spell_Nature_StarFall","Ability_Racial_BearForm","Spell_Nature_HealingTouch"},
    Hunter={"Ability_Hunter_BeastTaming","Ability_Marksmanship","Ability_Hunter_SwiftStrike"},
    Mage={"Spell_Holy_MagicalSentry","Spell_Fire_FireBolt02","Spell_Frost_FrostBolt02"},
    Paladin={"Spell_Holy_HolyBolt","Spell_Holy_DevotionAura","Spell_Holy_AuraOfLight"},
    Priest={"Spell_Holy_WordFortitude","Spell_Holy_HolyBolt","Spell_Shadow_ShadowWordPain"},
    Rogue={"Ability_Rogue_Eviscerate","Ability_BackStab","Ability_Stealth"},
    Shaman={"Spell_Nature_Lightning","Spell_Nature_LightningShield","Spell_Nature_MagicImmunity"},
    Warlock={"Spell_Shadow_DeathCoil","Spell_Shadow_Metamorphosis","Spell_Shadow_RainOfFire"},
    Warrior={"Ability_Warrior_SavageBlow","Ability_Warrior_InnerRage","Ability_Warrior_DefensiveStance"},
}
local function safe(value) return (not issecretvalue or not issecretvalue(value)) and value~=nil end
-- Settings are checked once per table: a profile switch, import or reset
-- always puts a new table in place, which is checked again on first use.
-- (This runs many times a second, so the check must not repeat.)
local checkedSettings=setmetatable({},{__mode="k"})
local WHERE_DEFAULTS={selfWhere={world=true,city=true,dungeon=true,raid=true,pvp=true},groupWhere={world=false,city=false,dungeon=true,raid=true,pvp=true}}
function Reminder:Settings()
    local s=FT.db.buffReminder
    if checkedSettings[s] then return s end
    if type(s)~="table" then s={}; FT.db.buffReminder=s end
    if s.enabled==nil then s.enabled=false end
    if s.groupEnabled==nil then s.groupEnabled=false end
    if s.lowRank==nil then s.lowRank=false end
    if s.ignoreRankOne==nil then s.ignoreRankOne=false end
    if s.rankMarker==nil then s.rankMarker=false end
    s.size=math.max(.7,math.min(1.5,tonumber(s.size) or 1))
    -- Seconds a notice stays before hiding by itself; 0 = until the buff is back.
    s.hideAfter=tonumber(s.hideAfter) or 30
    if s.hideAfter~=0 and s.hideAfter~=10 and s.hideAfter~=30 and s.hideAfter~=60 and s.hideAfter~=120 then s.hideAfter=30 end
    if type(s.textColor)~="table" then s.textColor={1,1,1} end
    for i=1,3 do s.textColor[i]=math.max(0,math.min(1,tonumber(s.textColor[i]) or 1)) end
    if type(s.groupTextColor)~="table" then s.groupTextColor={.82,.68,1} end
    for i=1,3 do s.groupTextColor[i]=math.max(0,math.min(1,tonumber(s.groupTextColor[i]) or 1)) end
    -- Where each kind of notice may appear. Self notices default to everywhere;
    -- group notices keep their original dungeon / raid / PvP behavior.
    for field,defaults in pairs(WHERE_DEFAULTS) do
        if type(s[field])~="table" then s[field]={} end
        for key,on in pairs(defaults) do if type(s[field][key])~="boolean" then s[field][key]=on end end
    end
    if type(s.selected)~="table" then s.selected={} end
    if type(s.specSelected)~="table" then s.specSelected={} end
    -- Forever renamed Blessing of Salvation to Salvation (not a blessing any
    -- more): choices, looks and combat picks saved under the old name follow.
    local function rename(t) if type(t)=="table" and t["Blessing of Salvation"]~=nil then if t["Salvation"]==nil then t["Salvation"]=t["Blessing of Salvation"] end; t["Blessing of Salvation"]=nil end end
    rename(s.selected); rename(s.styles); rename(s.combat)
    for _,specs in pairs(s.specSelected) do if type(specs)=="table" then for _,picked in pairs(specs) do rename(picked) end end end
    -- Buffs with a look of their own: [buff name or "weapon:main"/"weapon:off"]={mode=,size=,...}
    if type(s.styles)~="table" then s.styles={} end
    -- Buffs that also remind during a fight: [buff name or "weapon:main"/"weapon:off"]=true
    if type(s.combat)~="table" then s.combat={} end
    -- Remind in combat for every self buff at once (Your buffs page).
    if type(s.combatAll)~="boolean" then s.combatAll=false end
    -- Food buff reminder: off by default; "leveling" stops at max level.
    if type(s.food)~="boolean" then s.food=false end
    if s.foodWhen~="always" then s.foodWhen="leveling" end
    -- Stat food (Well Fed without the experience bonus): its own switch.
    if type(s.foodStat)~="boolean" then s.foodStat=false end
    -- Only remind about a self buff once you have the rage, mana or energy
    -- to cast it (Battle Shout with no rage stays quiet until you have 10).
    if type(s.powerReady)~="boolean" then s.powerReady=true end
    checkedSettings[s]=true
    return s
end
-- Food buff ("Well Fed"). In Forever it also gives 5% more experience from
-- kills. Different foods give different Well Fed buffs, so the buff is found
-- by its name. One known Well Fed spell supplies that name in the game's
-- language, and the icon.
local FOOD_SPELL=1249519
function Reminder:FoodInfo()
    if not self.foodName and C_Spell and C_Spell.GetSpellName then
        local ok,name=pcall(C_Spell.GetSpellName,FOOD_SPELL)
        if ok and safe(name) and type(name)=="string" and name~="" then self.foodName=name end
    end
    if not self.foodIcon and C_Spell and C_Spell.GetSpellTexture then
        local ok,icon=pcall(C_Spell.GetSpellTexture,FOOD_SPELL)
        if ok and safe(icon) and (type(icon)=="number" or type(icon)=="string") then self.foodIcon=icon end
    end
    return self.foodName or "Well Fed",self.foodIcon or "Interface\\Icons\\Spell_Misc_Food"
end
function Reminder:Leveling()
    local leveling=FT.modules.Leveling
    return not (leveling and leveling.MaxLevel and leveling:MaxLevel())
end
-- Two kinds of food buff: experience food (Well Fed with more experience
-- from kills) and stat food (Well Fed with stats). A reminder only shows
-- for a kind you carry food for; which kind is read from the item's own
-- tooltip ("experience", or "well fed" without it).
local function tooltipText(data)
    if type(data)~="table" or type(data.lines)~="table" then return nil end
    local parts={}
    for _,line in ipairs(data.lines) do
        local left=line.leftText
        if safe(left) and type(left)=="string" then parts[#parts+1]=left end
    end
    return table.concat(parts," "):lower()
end
function Reminder:FoodKinds()
    if self.foodKinds then return self.foodKinds end
    local kinds={xp=false,stat=false}
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem and C_Container and C_Container.GetContainerNumSlots) then
        -- Can't read item text: remind as before (any food counts).
        kinds.xp,kinds.stat,kinds.unknown=true,true,true
        return kinds
    end
    local seen={}
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local okCount,count=pcall(C_Container.GetContainerNumSlots,bag)
        if okCount and safe(count) and type(count)=="number" then
            for slot=1,count do
                local okID,id=pcall(C_Container.GetContainerItemID,bag,slot)
                if okID and safe(id) and type(id)=="number" and not seen[id] then
                    seen[id]=true
                    local okTip,data=pcall(C_TooltipInfo.GetBagItem,bag,slot)
                    local text=okTip and tooltipText(data)
                    if text then
                        if text:find("experience",1,true) and (text:find("well fed",1,true) or text:find("eat",1,true)) then kinds.xp=true
                        elseif text:find("well fed",1,true) then kinds.stat=true end
                    end
                end
            end
        end
    end
    self.foodKinds=kinds
    return kinds
end
-- Which food buffs you have now: xp, stat (nil when the game hides it).
function Reminder:FoodBuffs()
    local name=self:FoodInfo()
    local has=self:HasAura(name)
    if has~=true then return has,has end
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return true,true end
    local xp,stat,found=false,false,false
    for index=1,80 do
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,"player",index,"HELPFUL")
        if not ok then return nil,nil end
        if not aura then break end
        if not safe(aura.name) then return nil,nil end
        if aura.name==name or (safe(aura.spellId) and aura.spellId==FOOD_SPELL) then
            local text
            if C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID and safe(aura.auraInstanceID) then
                local okTip,data=pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID,"player",aura.auraInstanceID,"HELPFUL")
                text=okTip and tooltipText(data)
            end
            found=true
            if not text then xp,stat=true,true
            elseif text:find("experience",1,true) then xp=true else stat=true end
        end
    end
    -- Well Fed is there but could not be looked at closer: it counts for both.
    if not found then return true,true end
    return xp,stat
end
-- Is the food reminder wanted right now? (Whether the buff is there is checked by the caller.)
function Reminder:FoodWanted()
    local s=self:Settings()
    return s.food==true and (s.foodWhen=="always" or self:Leveling())
end
function Reminder:Class()
    local _,class=UnitClass("player")
    return safe(class) and type(class)=="string" and class:sub(1,1)..class:sub(2):lower() or ""
end
-- The tree most players of a class level in. Used while talents say little:
-- no points yet, or only a few early ones in another tree (a rogue's first
-- two in Assassination before going Combat).
local levelingTree={Druid="Feral Combat",Hunter="Beast Mastery",Mage="Frost",Paladin="Retribution",Priest="Shadow",
    Rogue="Combat",Shaman="Enhancement",Warlock="Affliction",Warrior="Arms"}
local EARLY_POINTS=5
-- Points spent in one tree, counted talent by talent. Some game versions do
-- not give the total per tree, or give it in another place; this always works
-- where talents can be read at all.
local function talentSum(tab)
    if type(GetNumTalents)~="function" or type(GetTalentInfo)~="function" then return nil end
    local ok,count=pcall(GetNumTalents,tab)
    if not ok or not safe(count) or type(count)~="number" or count<1 then return nil end
    local total,read=0,false
    for index=1,math.min(count,60) do
        local found,_,_,_,_,rank,maxRank=pcall(GetTalentInfo,tab,index)
        if found and safe(rank) and safe(maxRank) and type(rank)=="number" and type(maxRank)=="number" and rank>=0 and rank<=maxRank and maxRank<=10 then
            total=total+rank; read=true
        end
    end
    return read and total or nil
end
-- Your class's talent trees with the points in each: {name=, icon=, points=}.
-- Kept until talents change (and for a few seconds at most), because it is
-- asked for on every check.
function Reminder:TalentSpecs()
    local class=self:Class()
    local now=GetTime and GetTime() or 0
    local cache=self.specCache
    if cache and cache.class==class and now-cache.time<10 then return cache.list end
    local list,sources=self:ReadTalentSpecs()
    self.specCache={class=class,time=now,list=list,sources=sources}
    return list
end
function Reminder:ReadTalentSpecs()
    local result={}
    local sources={}
    local names=fallbackTrees[self:Class()] or {}
    if type(GetTalentTabInfo)=="function" then
        local count=GetNumTalentTabs and GetNumTalentTabs() or 3
        if safe(count) and type(count)=="number" then
            for i=1,math.min(count,4) do
                local ok,first,second,third,fourth,fifth=pcall(GetTalentTabInfo,i)
                local name=type(first)=="string" and first or second
                local points=type(first)=="string" and third or fifth
                local icon=type(first)=="string" and second or fourth
                -- Trees come in the same order as our list; Forever may word a
                -- tree name differently, so match by position when names differ.
                if ok and safe(name) and type(name)=="string" and names[i] then
                    result[#result+1]={name=names[i],icon=safe(icon) and icon or nil,points=safe(points) and type(points)=="number" and points or 0}
                    sources.tabs=true
                end
            end
        end
    end
    -- Current Classic clients expose spent points as the seventh return.
    local api=C_SpecializationInfo
    if api and type(api.GetSpecializationInfo)=="function" then
        local byName={};for _,spec in ipairs(result) do byName[spec.name]=spec end
        for i,name in ipairs(names) do
            local ok,_,liveName,_,icon,_,_,points=pcall(api.GetSpecializationInfo,i)
            -- By position, like above: the tree may be worded differently.
            if ok and safe(liveName) and type(liveName)=="string" and safe(points) and type(points)=="number" then
                local old=byName[name]
                byName[name]={name=name,icon=safe(icon) and icon or (old and old.icon) or nil,points=math.max(points,old and old.points or 0)}
                sources.spec=true
            end
        end
        result={};for _,name in ipairs(names) do if byName[name] then result[#result+1]=byName[name] end end
    end
    if #result~=#names then
        local byName={}
        for _,spec in ipairs(result) do byName[spec.name]=spec end
        result={}
        for _,name in ipairs(names) do result[#result+1]=byName[name] or {name=name,points=0} end
    end
    for i,spec in ipairs(result) do
        -- Counted talent by talent: the larger number wins.
        local sum=talentSum(i)
        if sum then sources.talents=true; if sum>spec.points then spec.points=sum end end
        spec.icon=spec.icon or ("Interface\\Icons\\"..((treeIcons[self:Class()] or {})[i] or "INV_Misc_Book_09"))
    end
    return result,sources
end
local function validTree(class,value)
    for _,tree in ipairs(fallbackTrees[class] or {}) do if value==tree then return tree end end
end
-- The tree you picked yourself, or nil when the addon follows your talents.
function Reminder:ManualSpec()
    local s=self:Settings(); local class=self:Class()
    local manual=type(s.manualSpec)=="table" and validTree(class,s.manualSpec[class])
    if manual then return manual end
    -- Older versions: a tree picked before any talent point was spent, used
    -- only while no points are spent.
    local old=type(s.chosenSpec)=="table" and validTree(class,s.chosenSpec[class])
    if old then
        local spent=0
        for _,spec in ipairs(self:TalentSpecs()) do spent=spent+spec.points end
        if spent==0 then return old end
    end
end
-- The tree your talents point to. Most points wins; with only a few points
-- spent, the tree most players of your class level in.
function Reminder:AutoSpec()
    local class=self:Class()
    local default=validTree(class,levelingTree[class])
    local best,bestPoints=nil,0
    for _,spec in ipairs(self:TalentSpecs()) do
        if spec.points>bestPoints then best,bestPoints=spec.name,spec.points end
    end
    if best then
        if default and best~=default and bestPoints<=EARLY_POINTS then return default end
        return best
    end
    local active=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local info=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    if type(active)=="function" and type(info)=="function" then
        local ok,index=pcall(active)
        if ok and safe(index) and type(index)=="number" and index>0 then
            local found,_,name=pcall(info,index)
            if found and safe(name) and type(name)=="string" and validTree(class,name) then return name end
        end
    end
    -- A class this list does not know has no trees to offer.
    return default or "Unassigned"
end
function Reminder:CurrentSpec()
    return self:ManualSpec() or self:AutoSpec()
end
-- One line for the bug report: what the game says about your talents.
function Reminder:TalentReport()
    self.specCache=nil
    local parts={}
    for _,spec in ipairs(self:TalentSpecs()) do parts[#parts+1]=spec.name.." "..spec.points end
    local sources=self.specCache and self.specCache.sources or {}
    local read={}
    for _,key in ipairs({"tabs","spec","talents"}) do if sources[key] then read[#read+1]=key end end
    local manual=self:ManualSpec()
    return "Talent trees: "..(#parts>0 and table.concat(parts,", ") or "none").." · using "..self:CurrentSpec()..(manual and " (picked)" or " (automatic)")
        .." · read from: "..(#read>0 and table.concat(read,"+") or "nothing")
end
-- The choices of the tree dropdown: Automatic first, then each tree.
function Reminder:SpecChoices()
    local result={}
    local auto=self:AutoSpec()
    local autoIcon
    local specs=self:TalentSpecs()
    for _,spec in ipairs(specs) do if spec.name==auto then autoIcon=spec.icon end end
    if #specs>0 then
        result[1]={value="auto",label="Automatic: "..auto,icon=autoIcon,tooltipTitle="Automatic",
            tooltip="Follows your talents (the tree with the most points). With few points: "..(levelingTree[self:Class()] or auto)..", the tree most "..self:Class():lower().."s level in."}
    end
    for _,spec in ipairs(specs) do
        result[#result+1]={value=spec.name,label=spec.name..(spec.points>0 and (" · "..spec.points..(spec.points==1 and " point" or " points")) or ""),icon=spec.icon,tooltipTitle=spec.name,
            tooltip="Always use "..spec.name..", whatever your talents. Pick Automatic to follow talents."}
    end
    if #result==0 then result[1]={value="auto",label="Automatic"} end
    return result
end
-- Pick a tree yourself ("auto" follows your talents again).
function Reminder:PickSpec(value)
    local s=self:Settings(); local class=self:Class()
    if type(s.manualSpec)~="table" then s.manualSpec={} end
    if value=="auto" or not validTree(class,value) then
        s.manualSpec[class]=nil
        if type(s.chosenSpec)=="table" then s.chosenSpec[class]=nil end
    else
        s.manualSpec[class]=value
    end
    self:Apply()
end
function Reminder:Selection(spec)
    local s=self:Settings();local class=self:Class()
    if type(s.specSelected[class])~="table" then s.specSelected[class]={} end
    spec=spec or self:CurrentSpec()
    if type(s.specSelected[class][spec])~="table" then s.specSelected[class][spec]={} end
    return s.specSelected[class][spec]
end
function Reminder:Enabled(entry,spec,learned)
    spec=spec or self:CurrentSpec()
    local chosen=self:Selection(spec)[entry.name]
    if chosen~=nil then return chosen end
    chosen=self:Settings().selected[entry.name]
    if chosen~=nil then return chosen end
    if self:Class()=="Paladin" and entry.group=="blessing" then
        learned=learned or self:Learned()
        return entry.name==(spec=="Holy" and learned["Blessing of Wisdom"] and "Blessing of Wisdom" or "Blessing of Might")
    end
    return entry.default
end
function Reminder:Learned()
    local found={}
    local book=FT.modules.CustomKeybinds
    if book and book.LearnedSpells then
        local ok,spells=pcall(book.LearnedSpells,book)
        -- Same spellbook scan as last time: reuse the map built from it.
        if ok and spells==self.learnedFrom and self.learnedMap then return self.learnedMap end
        if ok and type(spells)=="table" then
            self.learnedFrom,self.learnedMap=spells,found
            for _,spell in ipairs(spells) do
                if safe(spell.name) and type(spell.name)=="string" then
                    local _,rank=FT.BuffRanks:NameRank(spell.name,spell.rank or spell.label)
                    rank=rank or FT.BuffRanks:SpellRank(spell.value) or 0
                    local old=found[spell.name]
                    if not old or rank>(old.numericRank or 0) then
                        found[spell.name]={name=spell.name,value=spell.value,icon=spell.icon,rank=spell.rank,label=spell.label,numericRank=rank}
                    end
                end
            end
        end
    end
    return found
end
function Reminder:IsProtection()
    return self:CurrentSpec()=="Protection"
end
function Reminder:StanceStatus()
    local class=self:Class()
    if class~="Paladin" and class~="Warrior" then return end
    if not GetNumShapeshiftForms or not GetShapeshiftFormInfo then return end
    local ok,count=pcall(GetNumShapeshiftForms)
    if not ok or not safe(count) or type(count)~="number" or count<1 then return end
    local icon,unknown
    for i=1,math.min(count,20) do
        local found,texture,second,third=pcall(GetShapeshiftFormInfo,i)
        if found then
            local active=second
            if safe(second) and type(second)=="string" then active=third end
            if safe(texture) then icon=icon or texture end
            if not safe(active) then unknown=true
            elseif active then return true,icon end
        else unknown=true end
    end
    if unknown then return nil,icon end
    return false,icon
end
function Reminder:Available(learned,spec)
    local available={}
    spec=spec or self:CurrentSpec()
    for _,entry in ipairs(choices[self:Class()] or {}) do
        local spell=learned[entry[1]]
        if spell and not entry[4] and (entry[3]~="protection" or spec=="Protection") then
            available[#available+1]={name=entry[1],spell=spell,default=entry[2],group=entry[3]}
        end
    end
    local present,icon=self:StanceStatus()
    if present~=nil then
        local aura=self:Class()=="Paladin"
        available[#available+1]={name=aura and "Paladin aura" or "Warrior stance",message=aura and "Aura missing" or "Stance missing",spell={icon=icon or 134400},default=true,group="stance"}
    end
    return available
end
function Reminder:HasAura(name,unit)
    unit=unit or "player"
    if not C_UnitAuras then return nil end
    if C_UnitAuras.GetAuraDataBySpellName then
        local ok,aura=pcall(C_UnitAuras.GetAuraDataBySpellName,unit,name,"HELPFUL")
        if ok and aura then return true end
        if ok and not C_UnitAuras.GetAuraDataByIndex then return false end
    end
    if C_UnitAuras.GetAuraDataByIndex then
        local unknown=false
        for index=1,80 do
            local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,"HELPFUL")
            if not ok then unknown=true;break end
            if not aura then break end
            if not safe(aura.name) then unknown=true end
            if safe(aura.name) and aura.name==name then return true end
        end
        if unknown then return nil end
        return false
    end
end
function Reminder:FamilyPresent(group,unit)
    if not group or group=="protection" then return false end
    local unknown=false
    for _,entry in ipairs(choices[self:Class()] or {}) do
        if entry[3]==group then
            local present=self:HasAura(entry[1],unit)
            if present==true then return true elseif present==nil then unknown=true end
            if group=="blessing" then
                local greater=self:HasAura("Greater "..entry[1],unit)
                if greater==true then return true elseif greater==nil then unknown=true end
            end
        end
    end
    if unknown then return nil end
    return false
end
-- The player's surroundings, as the "Show in" choices name them.
Reminder.places={{"world","Open world","Away from dungeons, raids, battlegrounds and cities."},{"city","Cities","In cities and inns (while resting)."},{"dungeon","Dungeons","Inside five-player dungeons."},{"raid","Raids","Inside raids."},{"pvp","PvP","In battlegrounds and arenas."}}
function Reminder:Place()
    local kind
    if type(GetInstanceInfo)=="function" then local ok,_,value=pcall(GetInstanceInfo); if ok and safe(value) then kind=value end end
    if kind=="party" or kind=="scenario" then return "dungeon" end
    if kind=="raid" then return "raid" end
    if kind=="pvp" or kind=="arena" then return "pvp" end
    if IsResting then local ok,resting=pcall(IsResting); if ok and safe(resting) and resting then return "city" end end
    return "world"
end
function Reminder:ShowsHere(field)
    local where=self:Settings()[field]
    return where[self:Place()]==true
end
function Reminder:GroupUnits()
    if type(GetNumGroupMembers)~="function" then return {} end
    local okCount,count=pcall(GetNumGroupMembers)
    if not okCount or not safe(count) or type(count)~="number" or count<2 then return {} end
    local units={}
    local raid=false
    if IsInRaid then local ok,value=pcall(IsInRaid); raid=ok and safe(value) and value or false end
    local prefix=raid and "raid" or "party"
    for i=1,math.min(count,prefix=="raid" and 40 or 4) do
        local unit=prefix..i
        local okExists,exists=true,true
        if UnitExists then okExists,exists=pcall(UnitExists,unit) end
        exists=okExists and safe(exists) and exists
        if exists then units[#units+1]=unit end
    end
    return units
end
function Reminder:ApplyPosition()
    if not self.badge then return end
    local s=self:Settings();local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local x=s.x and s.x*(s.screenWidth and w/s.screenWidth or 1) or w*.5
    local y=s.y and s.y*(s.screenHeight and h/s.screenHeight or 1) or h-115
    local halfWidth=285*s.size/2
    local bottom=(self.badge:IsShown() and self.groupBadge:IsShown() and 59 or 17)*s.size
    x=math.max(halfWidth+10,math.min(w-halfWidth-10,x))
    y=math.max(bottom+10,math.min(h-17*s.size-10,y))
    if s.x or s.y then s.x=x;s.y=y;s.screenWidth=w;s.screenHeight=h end
    for _,badge in ipairs({self.badge,self.groupBadge}) do
        if badge.SetScale then badge:SetScale(s.size) end
        badge:ClearAllPoints()
        -- Offsets count in the notice's own (scaled) units, so divide by its size;
        -- otherwise a bigger size pushes the notices up and off the screen.
        badge:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/s.size,(y-(badge==self.groupBadge and (self.badge:IsShown() and 42*s.size or 0) or 0))/s.size)
        badge.text:SetTextColor(unpack(badge==self.groupBadge and s.groupTextColor or s.textColor))
    end
end
function Reminder:DragStart(badge)
    if not self.moving then return end
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    local cx,cy=badge:GetCenter();if not cx then return end
    local size=badge:GetScale() or 1; cx,cy=cx*size,cy*size
    self.dragX,self.dragY=cx-x/scale,cy-y/scale;self.dragging=true
end
function Reminder:DragUpdate()
    if not self.dragging then return end
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight();local s=self:Settings()
    s.x=math.max(150,math.min(w-150,x/scale+self.dragX))
    s.y=math.max(30,math.min(h-30,y/scale+self.dragY))
    s.screenWidth=w;s.screenHeight=h;self:ApplyPosition()
end
function Reminder:SetMoving(value)
    if self.dragging then self:DragUpdate() end
    self.dragging=false;self.moving=value==true
    self:Refresh()
end
-- The Preview switches (Your buffs, Look and position): sample notices that
-- can be dragged; off locks them again.
function Reminder:PreviewOn() return (self.previewSelf and not self.peekingSelf) and true or false end
function Reminder:SetPreview(on)
    self.previewSelf=on and true or nil; self.peekingSelf=nil; self.peekToken=nil
    self:SetMoving(on and true or false); self:Apply()
end
-- Classes with a weapon reminder. Shamans pick a weapon buff per hand (the
-- main hand is watched from the start). Rogues switch a poison reminder on
-- per hand (off from the start: poisons come at a later level). Whatever is
-- on the weapon counts; only a bare weapon reminds.
local POISON_ICON="Interface\\Icons\\Ability_Poisons"
-- Can this rogue use poisons yet? The reminder can be switched on before
-- that; it stays quiet until one of these is true:
--   * the spellbook has Poisons, or a poison spell (later versions of the game);
--   * the game says the Poisons spell is known, or lists a Poisons skill;
--   * there is a poison in the bags;
--   * a weapon has something on it, now or earlier on this character.
-- Once true it stays true. While false it is looked at again every few seconds.
local POISONS_SPELL=2842
local POISON_RECHECK=5
local function poisonName(name)
    if not safe(name) or type(name)~="string" then return false end
    return name=="Poisons" or name:match(" Poison$")~=nil or name:match(" Poison [IVX]+$")~=nil
end
function Reminder:PoisonsKnown(learned)
    if self.poisonsKnown then return true end
    local guid
    if UnitGUID then local ok,value=pcall(UnitGUID,"player"); if ok and safe(value) and type(value)=="string" then guid=value end end
    local function known(remember)
        self.poisonsKnown=true
        if remember and guid then
            if type(FT.db.poisonsSeen)~="table" then FT.db.poisonsSeen={} end
            FT.db.poisonsSeen[guid]=true
        end
        return true
    end
    if guid and type(FT.db.poisonsSeen)=="table" and FT.db.poisonsSeen[guid]==true then return known() end
    local now=GetTime and GetTime() or 0
    if self.poisonChecked and now-self.poisonChecked<POISON_RECHECK then return false end
    self.poisonChecked=now
    for name in pairs(learned or {}) do if poisonName(name) then return known(true) end end
    for _,check in ipairs({IsPlayerSpell or false,IsSpellKnown or false}) do
        if check then local ok,value=pcall(check,POISONS_SPELL); if ok and safe(value) and value then return known(true) end end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local ok,count=pcall(GetNumSkillLines)
        if ok and safe(count) and type(count)=="number" then
            for index=1,math.min(count,80) do
                local found,name=pcall(GetSkillLineInfo,index)
                if found and safe(name) and name=="Poisons" then return known(true) end
            end
        end
    end
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
        for bag=0,(NUM_BAG_SLOTS or 4) do
            local ok,count=pcall(C_Container.GetContainerNumSlots,bag)
            if ok and safe(count) and type(count)=="number" then
                for slot=1,count do
                    local found,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
                    if found and type(info)=="table" and poisonName(info.itemName) then return known(true) end
                end
            end
        end
    end
    for _,slot in ipairs({"main","off"}) do
        local state=FT.BuffRanks:WeaponState(slot)
        if state and state.present then return known(true) end
    end
    return false
end
function Reminder:WeaponKind()
    local class=self:Class()
    return class=="Shaman" and "enchant" or class=="Rogue" and "poison" or nil
end
-- What is watched for a hand: a name for the label and an icon. nil = off.
function Reminder:WeaponWatch(slot,learned)
    local s=self:Settings(); local kind=self:WeaponKind()
    if kind=="enchant" then
        local name=s[slot.."Enchant"]
        if slot=="main" and name==nil then
            for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end
        end
        if name and learned[name] then return name,learned[name].icon end
    elseif kind=="poison" then
        if s[slot.."Poison"]==true and self:PoisonsKnown(learned) then return "Poison",POISON_ICON end
    end
end
function Reminder:WeaponMissing(slot)
    local state=FT.BuffRanks:WeaponState(slot)
    if not state then return nil end
    return not state.present
end
-- The timer (and a dismissed notice) restarts only when a buff goes missing
-- that was not missing before. A buff coming back, or checking again, keeps
-- the current countdown.
function Reminder:NoticeVisible(key,entries)
    self.notices=self.notices or {}
    local notice=self.notices[key]
    local now=GetTime and GetTime() or 0
    local names,fresh={},not notice
    for _,entry in ipairs(entries) do
        local name=entry.message or entry.name
        names[name]=true
        if notice and not notice.names[name] then fresh=true end
    end
    if fresh then notice={names=names,started=now};self.notices[key]=notice
    else notice.names=names end
    if #entries==0 then self.notices[key]=nil; return false end
    local limit=self:Settings().hideAfter
    return not notice.dismissed and (limit==0 or now<notice.started+limit)
end
local hideChoices={{0,"Never (until the buff is back)"},{10,"10 seconds"},{30,"30 seconds"},{60,"1 minute"},{120,"2 minutes"}}
function Reminder:HideAfterText()
    local v=self:Settings().hideAfter
    for _,c in ipairs(hideChoices) do if c[1]==v then return "Hide notice after: "..(v==0 and "Never" or c[2]) end end
    return "Hide notice after: 30 seconds"
end
function Reminder:HideHint()
    local v=self:Settings().hideAfter
    return (v==0 and "Stays until the buff is back." or ("Hides after "..(v>=60 and (v/60).." minute"..(v>60 and "s" or "") or v.." seconds")..".")).." Left-click to dismiss, right-click for settings."
end
function Reminder:ClickNotice(key,button)
    if button=="RightButton" then
        if not InCombatLockdown() then FT:OpenModule("BuffReminder") end
    elseif not self.moving then
        if key=="self" then self.previewSelf=nil elseif key=="group" then self.previewGroup=nil end
        if self.notices and self.notices[key] then self.notices[key].dismissed=true end
        self:Refresh(self.learnedCache)
    end
end
-- Reminders in a fight. Notices normally pause in combat; a buff with
-- "Also remind in combat" on keeps its notice (Battle Shout needs rage, so a
-- fight is the only time it can be cast). The game can hide your buffs
-- during a fight, so each of these buffs also gets our own record of when it
-- runs out: read from the buff whenever the game shows it, and set from your
-- own casts when it does not.
local DEFAULT_DURATION={["Battle Shout"]=120,["Commanding Shout"]=120}
Reminder.seen={}
Reminder.instances={}
-- /ft buffdebug: for one minute, what the reminder sees when your buffs
-- change (also in a fight): whether the game hides the aura event's details,
-- and the state of each buff set to remind in combat.
function Reminder:BuffDebug()
    self.debugUntil=(GetTime and GetTime() or 0)+60
    print("|cffd8b25aForeverTools|r buff debug on for 60 seconds. Click a buff off in a fight, then use the chat copy button.")
    self:DebugState("start")
end
local function show(v) if issecretvalue and issecretvalue(v) then return "secret" end; return tostring(v) end
function Reminder:DebugState(why)
    local out=function(text) print("|cffd8b25aFT buffs|r "..text) end
    out(why.."  in combat: "..tostring(InCombatLockdown()))
    for name in pairs(self:Settings().combat) do
        local entry
        for _,e in ipairs(self:Available(self.learnedCache or self:Learned())) do if e.name==name then entry=e end end
        local has=self:HasAura(name)
        local ok,aura=false,nil
        if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then ok,aura=pcall(C_UnitAuras.GetAuraDataBySpellName,"player",name,"HELPFUL") end
        local id=self.instances[name]; local probe="-"
        if id and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then local okp,data=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,"player",id); probe=okp and (data==nil and "gone" or (safe(data) and "there" or "secret")) or "error" end
        out(string.format("  %s: has %s  lookup %s  family %s  seen %s  instance %s (%s)  missing %s",name,show(has),ok and (aura==nil and "nil" or show(type(aura))) or "error",entry and show(self:FamilyPresent(entry.group)) or "-",show(self.seen[name]),show(id),probe,entry and show(self:EntryMissing(entry,self:Fighting())) or "-"))
    end
end
function Reminder:DebugAura(info)
    if not self.debugUntil or (GetTime and GetTime() or 0)>self.debugUntil then return end
    local parts={}
    if info==nil then parts[#parts+1]="no details"
    elseif not safe(info) then parts[#parts+1]="details secret"
    elseif type(info)=="table" then
        parts[#parts+1]="full "..show(info.isFullUpdate)
        local removed=info.removedAuraInstanceIDs
        if removed~=nil then
            if not safe(removed) then parts[#parts+1]="removed: secret"
            else local ids={}; for _,id in ipairs(removed) do ids[#ids+1]=show(id) end; parts[#parts+1]="removed: "..table.concat(ids,",") end
        end
        local added=info.addedAuras
        if added~=nil then
            if not safe(added) then parts[#parts+1]="added: secret"
            else local names={}; for _,aura in ipairs(added) do names[#names+1]=(safe(aura) and type(aura)=="table") and (show(aura.name).."#"..show(aura.auraInstanceID)) or "secret" end; parts[#parts+1]="added: "..table.concat(names,",") end
        end
    end
    print("|cffd8b25aFT buffs|r aura event: "..table.concat(parts,"  "))
    self:DebugState("after event")
end
-- Your aura event's list of removed instances: a watched buff among them is
-- gone now (also in a fight, where the buff list itself is hidden).
function Reminder:NoteRemoved(info)
    if not safe(info) or type(info)~="table" then return false end
    -- New auras: remember the instance of a watched buff (a recast in a fight).
    if safe(info.addedAuras) and type(info.addedAuras)=="table" then
        for _,aura in ipairs(info.addedAuras) do
            if safe(aura) and type(aura)=="table" and safe(aura.name) and type(aura.name)=="string" and safe(aura.auraInstanceID) and aura.auraInstanceID
                and (self.seen[aura.name]~=nil or self:CombatFor(aura.name)) then
                self.instances[aura.name]=aura.auraInstanceID
            end
        end
    end
    if not safe(info.removedAuraInstanceIDs) or type(info.removedAuraInstanceIDs)~="table" then return false end
    local gone=false
    for _,id in ipairs(info.removedAuraInstanceIDs) do
        if safe(id) then
            for name,known in pairs(self.instances) do
                if known==id then self.seen[name]=0; self.instances[name]=nil; gone=true end
            end
        end
    end
    return gone
end
function Reminder:Fighting() return self.fighting==true or InCombatLockdown() end
function Reminder:CombatAny()
    local s=self:Settings()
    return s.enabled and (s.combatAll or next(s.combat)~=nil)
end
-- Does this buff (or "weapon:main"/"weapon:off") also remind in a fight?
-- You can't eat in a fight, so food never does.
function Reminder:CombatFor(key)
    if key=="food" then return false end
    local s=self:Settings()
    return s.combatAll==true or s.combat[key]==true
end
function Reminder:Duration(name)
    local known=type(FT.db.buffDurations)=="table" and FT.db.buffDurations[name]
    return type(known)=="number" and known>0 and known or DEFAULT_DURATION[name] or 600
end
-- The buff is up: remember when it runs out (exactly, if the game says).
function Reminder:Remember(name,own)
    local now=GetTime and GetTime() or 0
    if own and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok,aura=pcall(C_UnitAuras.GetAuraDataBySpellName,"player",name,"HELPFUL")
        if ok and safe(aura) and type(aura)=="table" then
            local expires,duration=aura.expirationTime,aura.duration
            -- Its instance: when it is clicked off or used up in a fight (the
            -- game then hides your buffs), the aura event still says which
            -- instance went away.
            if safe(aura.auraInstanceID) and aura.auraInstanceID then self.instances[name]=aura.auraInstanceID end
            if safe(expires) and type(expires)=="number" then
                self.seen[name]=expires>0 and expires or math.huge
                -- How long this buff lasts, learned once and kept for the account.
                if safe(duration) and type(duration)=="number" and duration>0 then
                    if type(FT.db.buffDurations)~="table" then FT.db.buffDurations={} end
                    if FT.db.buffDurations[name]~=duration then FT.db.buffDurations[name]=duration end
                end
                return
            end
        end
    end
    local old=self.seen[name]
    if not old or old<=now then self.seen[name]=now+self:Duration(name) end
end
-- Is this buff missing? For buffs that also remind in a fight. What the game
-- shows always wins; only when it hides the answer in a fight does our own
-- record decide. Never seen either way: say nothing.
function Reminder:EntryMissing(entry,fighting)
    local has=self:HasAura(entry.name); local family=self:FamilyPresent(entry.group)
    if has==false and family==false then self.seen[entry.name]=0; return true end
    if has==true or family==true then self:Remember(entry.name,has==true); return false end
    if not fighting then return false end
    -- The buff list is hidden in a fight, but asking for the one buff we saw
    -- (by its instance) still answers "gone" once it is clicked off or used up.
    if self:InstanceGone(entry.name) then self.seen[entry.name]=0; self.instances[entry.name]=nil; return true end
    local expires=self.seen[entry.name]
    return expires~=nil and (GetTime and GetTime() or 0)>=expires
end
-- true: the buff instance we saw is no longer on you. nil: unknown.
function Reminder:InstanceGone(name)
    local id=self.instances[name]
    if not id or not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then return nil end
    local ok,data=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,"player",id)
    if not ok then return nil end
    if data==nil then return true end
    return false
end
-- You cast something: if it is one of those buffs (or another of its kind,
-- like a different blessing), it is up again from now.
function Reminder:NoteCast(spellID)
    if not self:CombatAny() or not C_Spell or not C_Spell.GetSpellName then return end
    local ok,name=pcall(C_Spell.GetSpellName,spellID)
    if not ok or not safe(name) or type(name)~="string" then return end
    local s=self:Settings(); local group; local list=choices[self:Class()] or {}
    for _,entry in ipairs(list) do if entry[1]==name then group=entry[3] end end
    local now=GetTime and GetTime() or 0; local changed=false
    local keys={}
    for key in pairs(s.combat) do keys[key]=true end
    -- Everything reminds in a fight: every buff of yours counts.
    if s.combatAll then for _,entry in ipairs(list) do keys[entry[1]]=true end end
    for key in pairs(keys) do
        local same=key==name
        if not same and group and group~="protection" then
            for _,entry in ipairs(list) do if entry[1]==key and entry[3]==group then same=true end end
        end
        if same then self.seen[key]=now+self:Duration(name); changed=true end
    end
    if changed and self:Fighting() then FT:Coalesce("reminderCombat",function() self:Refresh(self.learnedCache) end,.1) end
end
-- Do you have the rage, mana or energy to cast this spell right now?
-- false only when the game says it costs more than you have; anything
-- unknown (no cost, hidden values) counts as enough, so nothing is hidden
-- by mistake.
-- "rage", "energy", "mana" or a mix, for the class you are playing.
function Reminder:PowerWord()
    local class=self:Class()
    if class=="Warrior" then return "rage" elseif class=="Rogue" then return "energy" end
    return "mana"
end
local function costsOf(spell)
    local get=(C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
    if not get then return end
    local id=tonumber(spell.value)
    local ok,costs=false,nil
    if id and id>0 then ok,costs=pcall(get,id) end
    if (not ok or type(costs)~="table" or #costs==0) and type(spell.name)=="string" then ok,costs=pcall(get,spell.name) end
    if ok and safe(costs) and type(costs)=="table" then return costs end
end
-- The game's own "can't cast: not enough rage/mana/energy" answer.
local function lacksPower(spell)
    local usable=(C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
    if not usable then return nil end
    local id=tonumber(spell.value)
    local ok,can,noPower=false,nil,nil
    if id and id>0 then ok,can,noPower=pcall(usable,id) end
    if (not ok or can==nil) and type(spell.name)=="string" then ok,can,noPower=pcall(usable,spell.name) end
    if ok and safe(noPower) then return noPower==true end
end
function Reminder:EnoughPower(spell)
    if type(spell)~="table" then return true end
    if lacksPower(spell)==true then return false end
    if not UnitPower then return true end
    for _,c in ipairs(costsOf(spell) or {}) do
        local need
        if type(c)=="table" then
            if safe(c.cost) and type(c.cost)=="number" and c.cost>0 then need=c.cost
            elseif safe(c.minCost) and type(c.minCost)=="number" then need=c.minCost end
        end
        if need and need>0 and safe(c.type)
            and not (safe(c.hasRequiredAura) and c.requiredAuraID and c.requiredAuraID~=0 and c.hasRequiredAura==false) then
            local okPower,have=pcall(UnitPower,"player",c.type)
            if okPower and safe(have) and type(have)=="number" and have<need then return false end
        end
    end
    return true
end
-- /ft powerdebug: what the reminder sees for each of your self buffs.
function Reminder:PowerDebug()
    local learned=self:Learned()
    local out=function(text) print("|cffd8b25aForeverTools|r "..text) end
    out("Wait for power: "..tostring(self:Settings().powerReady))
    for _,entry in ipairs(self:Available(learned)) do
        local spell=entry.spell or {}
        local costs=costsOf(spell)
        local parts={}
        for _,c in ipairs(costs or {}) do parts[#parts+1]=tostring(c.name or c.type)..":"..tostring(c.cost).."/"..tostring(c.minCost) end
        local usable=(C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
        local u1,u2; if usable then local _; _,u1,u2=pcall(usable,tonumber(spell.value) or spell.name or entry.name) end
        local p0,p1,p3=UnitPower and UnitPower("player",0),UnitPower and UnitPower("player",1),UnitPower and UnitPower("player",3)
        out(entry.name.." id="..tostring(spell.value).." cost="..(costs and (#parts>0 and table.concat(parts,",") or "none") or "unknown").." usable="..tostring(u1).."/"..tostring(u2).." power m/r/e="..tostring(p0).."/"..tostring(p1).."/"..tostring(p3).." enough="..tostring(self:EnoughPower(spell)))
    end
end
-- While a reminder waits for power, look again soon after it changes.
function Reminder:WatchPower(on)
    if not self.powerEvents then
        if not on then return end
        self.powerEvents=CreateFrame("Frame")
        self.powerEvents:SetScript("OnEvent",function()
            if FT.dbReady and self.badge then FT:Coalesce("reminderPower",function() self:Refresh(self.learnedCache) end,.2) end
        end)
    end
    if self.watchingPower==on then return end
    self.watchingPower=on
    if on then pcall(self.powerEvents.RegisterUnitEvent,self.powerEvents,"UNIT_POWER_UPDATE","player")
    else self.powerEvents:UnregisterAllEvents() end
end
function Reminder:Suppressed(fightOK)
    -- A flight path, a vehicle or a cutscene (System > General).
    if FT:NoControl() then return true end
    if not fightOK and (self.fighting==true or InCombatLockdown()) then return true end
    -- Dead or a ghost: no buffs to cast. (Flights and vehicles: FT:NoControl above.)
    for _,fn in ipairs({UnitIsDeadOrGhost or false}) do
        if fn then local ok,value=pcall(fn,"player");if ok and safe(value) and value then return true end end
    end
    if IsPlayerInWorld then local ok,value=pcall(IsPlayerInWorld);if ok and safe(value) and not value then return true end end
    return false
end
function Reminder:Refresh(cachedSpells)
    local s=self:Settings()
    -- In a fight only buffs with "Also remind in combat" are looked at.
    local fighting=self:Fighting()
    if self:Suppressed(fighting and self:CombatAny()) then
        self.wasSuppressed=true
        self.missing={}
        if self.badge then self.badge:Hide();self.groupBadge:Hide() end
        self:HideCustom()
        -- Notices pause on flights, while dead or in combat, but the settings
        -- page must still lay itself out, or it opens empty and jumbled.
        if self.frame then self:RefreshMenu(cachedSpells or self.learnedCache) end
        return
    end
    -- Back from combat, a flight or death: show missing buffs again with a
    -- fresh timer. The countdown kept running while notices were paused, so
    -- without this a buff that dropped earlier stayed hidden after combat.
    if self.wasSuppressed then self.wasSuppressed=nil; self.notices=nil end
    local learned=cachedSpells or self:Learned()
    self.learnedCache=learned
    local currentSpec=self:CurrentSpec()
    self.missing={}
    self.groupMissing={}
    local styleKeys={}
    local selfHere=self:ShowsHere("selfWhere")
    local waiting=false
    if s.enabled then
        for _,entry in ipairs(selfHere and self:Available(learned) or {}) do
            local also=self:CombatFor(entry.name)
            if (also or not fighting) and self:Enabled(entry,currentSpec,learned) then
                local missing
                if entry.group=="stance" then missing=self:StanceStatus()==false
                elseif also then missing=self:EntryMissing(entry,fighting)
                else missing=self:HasAura(entry.name)==false and self:FamilyPresent(entry.group)==false end
                if missing and s.powerReady and entry.group~="stance" and not self:EnoughPower(entry.spell) then missing=false; waiting=true end
                if missing then self.missing[#self.missing+1]=entry; styleKeys[entry]=entry.name end
            end
        end
        if not fighting and s.groupEnabled and self:ShowsHere("groupWhere") then
            local units=self:GroupUnits()
            if #units>0 then
                for _,entry in ipairs(self:Available(learned)) do
                    local group=entry.group
                    if self:Enabled(entry,currentSpec,learned) and (group=="wild" or group=="blessing" or group=="salvation" or group=="intellect" or group=="fortitude" or group=="spirit") then
                        local missing,names=0,{}
                        for _,unit in ipairs(units) do
                            if self:HasAura(entry.name,unit)==false and self:FamilyPresent(group,unit)==false then
                                missing=missing+1
                                local okN,n=pcall(UnitName,unit)
                                if okN and safe(n) and type(n)=="string" then names[#names+1]=n end
                            end
                        end
                        if missing>0 then
                            local family=({wild="Wild buff",blessing="Blessing",salvation="Salvation",intellect="Intellect",fortitude="Fortitude",spirit="Spirit"})[group] or "Group buff"
                            -- Who: up to two names on the bar, everyone in the tooltip.
                            local who
                            if #names==missing and missing<=2 then who=table.concat(names,", ")
                            elseif #names>0 then who=names[1]..", "..(names[2] and (names[2].." ") or "").."+"..(missing-math.min(2,#names))
                            else who=missing.." member"..(missing==1 and "" or "s") end
                            self.groupMissing[#self.groupMissing+1]={name=family.." missing — "..who,family=family,names=names,count=missing,spell=entry.spell}
                        end
                    end
                end
            end
        end
        if selfHere and not fighting and (self:FoodWanted() or s.foodStat) then
            local _,icon=self:FoodInfo()
            local kinds=self:FoodKinds()
            local xp,stat=self:FoodBuffs()
            if self:FoodWanted() and kinds.xp and xp==false then
                local food={name="Food buff",message=(kinds.unknown and "Food buff missing" or "XP food buff missing")..(self:Leveling() and " (+5% XP)" or ""),spell={icon=icon}}
                self.missing[#self.missing+1]=food; styleKeys[food]="food"
            end
            if s.foodStat and kinds.stat and stat==false and not (kinds.unknown and self:FoodWanted()) then
                local food={name="Stat food buff",message="Stat food buff missing",spell={icon=icon}}
                self.missing[#self.missing+1]=food; styleKeys[food]="food"
            end
        end
        local weaponKind=self:WeaponKind()
        if weaponKind and selfHere then
            local word=weaponKind=="poison" and "Poison" or "Weapon buff"
            for _,slot in ipairs({"main","off"}) do
                local name,icon=self:WeaponWatch(slot,learned)
                local ready=weaponKind=="poison" or not s.powerReady or self:EnoughPower(learned[name])
                if name and not ready and self:WeaponMissing(slot) then waiting=true end
                if name and ready and (not fighting or self:CombatFor("weapon:"..slot)) and self:WeaponMissing(slot) then
                    local hand=slot=="main" and "main hand" or "off hand"
                    local weapon={name=word.." ("..hand..")",message=word.." missing ("..hand..")",spell=weaponKind=="poison" and {icon=icon} or learned[name]}
                    self.missing[#self.missing+1]=weapon; styleKeys[weapon]="weapon:"..slot
                end
            end
        end
        if selfHere and not fighting then for _,warning in ipairs(FT.BuffRanks:Warnings(learned,s)) do self.missing[#self.missing+1]=warning end end
        if not fighting then FT.BuffRanks:ObserveWeapons() end
    end
    self:WatchPower(waiting)
    -- Buffs with their own look leave the shared notice and get their own.
    local custom={}
    if next(s.styles) then
        local shared={}
        for _,entry in ipairs(self.missing) do
            local key=styleKeys[entry]
            if key and self:Style(key) then custom[key]=entry else shared[#shared+1]=entry end
        end
        self.missing=shared
    end
    if self.badge then
        -- The look panel is open on a buff that uses the shared notice: show
        -- that notice as its sample (a buff with its own look shows its own).
        local sampleName,sampleIcon
        if not fighting and self.styleKey and not self:Style(self.styleKey) then sampleName,sampleIcon=self:StyleInfo(self.styleKey) end
        -- Samples and previews are for the settings page, never for a fight.
        local showing=not fighting and (self.moving or self.previewSelf or sampleName~=nil)
        self.badge:SetShown(self:NoticeVisible("self",self.missing) or showing)
        if #self.missing>0 then
            self.cycle=math.max(1,math.min(self.cycle,#self.missing))
            local entry=self.missing[self.cycle]
            self.badge.icon:SetTexture(entry.spell.icon or 134400)
            self.badge.text:SetText((entry.message or entry.name.." missing")..(#self.missing>1 and "  +"..(#self.missing-1) or ""))
        elseif sampleName then
            self.badge.icon:SetTexture(sampleIcon or 134400);self.badge.text:SetText(sampleName.." missing — preview")
        elseif self.moving or self.previewSelf then self.badge.icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude");self.badge.text:SetText(next(s.styles) and "Shared notice (buffs without their own look) — preview" or "Self buff missing — preview")
        end
        self.groupBadge:SetShown(self:NoticeVisible("group",self.groupMissing) or (not fighting and (self.previewGroup or self.moving)))
        if #self.groupMissing>0 then
            self.groupCycle=math.max(1,math.min(self.groupCycle or 1,#self.groupMissing))
            local entry=self.groupMissing[self.groupCycle]
            self.groupBadge.icon:SetTexture(entry.spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.groupBadge.text:SetText(entry.name)
        elseif self.previewGroup or self.moving then
            self.groupBadge.icon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfFortitude")
            self.groupBadge.text:SetText("Group buff missing — preview")
        end
        self:ApplyPosition()
        -- After the shared notices: own notices without a place of their own line up under them.
        self:ShowCustom(custom,fighting)
    end
    if self.frame then self:RefreshMenu(learned) end
end
-- While moving, the same outline box the other elements get, drawn just
-- behind each notice (self buffs and group buffs).
function Reminder:MoverBoxes()
    if not self.moving and not self.boxesShown then return end
    self.boxesShown=self.moving
    local badges={self.badge,self.groupBadge}
    for _,notice in pairs(self.custom or {}) do badges[#badges+1]=notice end
    for _,badge in ipairs(badges) do
        local box=badge.moverBox
        if not box and self.moving then
            box=CreateFrame("Frame",nil,UIParent); box:SetPoint("TOPLEFT",badge,"TOPLEFT"); box:SetPoint("BOTTOMRIGHT",badge,"BOTTOMRIGHT")
            FT:MoverBox(box,6); badge.moverBox=box
        end
        if box then
            box:SetFrameStrata(badge:GetFrameStrata()); box:SetFrameLevel(math.max(0,badge:GetFrameLevel()-1))
            box:SetShown(self.moving and badge:IsShown())
        end
    end
end
local refresh=Reminder.Refresh
function Reminder:Refresh(...)
    refresh(self,...)
    if self.badge then self:MoverBoxes() end
end
function Reminder:Apply()
    if FT.modules.RankMarker and self.markerApplied~=self:Settings().rankMarker then
        self.markerApplied=self:Settings().rankMarker; FT.modules.RankMarker:Apply()
    end
    if not self.badge then
        local badge=CreateFrame("Button","ForeverToolsBuffReminder",UIParent)
        self.badge=badge;badge:SetSize(285,34);badge:SetPoint("TOP",UIParent,"TOP",0,-115)
        badge:SetFrameStrata("LOW");FT:Panel(badge);FT:MeterSkin(badge)
        local skins=FT.modules.IconStyles; if skins and skins.SkinPanel then skins:SkinPanel(badge,"notices",{0.075,0.058,0.04,1},{.61,.51,.31,1}) end
        badge.icon=badge:CreateTexture(nil,"ARTWORK");badge.icon:SetSize(20,20);badge.icon:SetPoint("LEFT",8,0);badge.icon:SetTexCoord(.08,.92,.08,.92);FT:RoundIcon(badge.icon)
        badge.text=FT:Label(badge,"",13);badge.text:SetPoint("LEFT",badge.icon,"RIGHT",8,0);badge.text:SetWidth(242)
        badge:RegisterForClicks("LeftButtonUp","RightButtonUp")
        badge:SetScript("OnClick",function(_,button) self:ClickNotice("self",button) end)
        FT:Tooltip(badge,"Missing self buffs",function()
            local lines={};for _,entry in ipairs(self.missing) do lines[#lines+1]=entry.detail or entry.message or entry.name.." missing" end
            return table.concat(lines,"\n").."\n"..self:HideHint()
        end)
        badge:RegisterForDrag("LeftButton")
        badge:SetScript("OnDragStart",function(owner) self:DragStart(owner) end)
        badge:SetScript("OnDragStop",function() self:DragUpdate();self.dragging=false end)
        badge:SetScript("OnUpdate",function(_,dt)
            if self.dragging then self:DragUpdate() end
            self.elapsed=self.elapsed+dt
            if self.elapsed>=5 then self.elapsed=0;self.cycle=self.cycle%math.max(1,#self.missing)+1;self.groupCycle=(self.groupCycle or 1)%math.max(1,#(self.groupMissing or {}))+1;self:Refresh() end
        end)
        local group=CreateFrame("Button","ForeverToolsGroupBuffReminder",UIParent);self.groupBadge=group
        group:SetSize(285,34);group:SetFrameStrata("LOW");FT:Panel(group);FT:MeterSkin(group)
        local skins=FT.modules.IconStyles; if skins and skins.SkinPanel then skins:SkinPanel(group,"notices",{0.075,0.058,0.04,1},{.61,.51,.31,1}) end
        group.icon=group:CreateTexture(nil,"ARTWORK");group.icon:SetSize(20,20);group.icon:SetPoint("LEFT",8,0);group.icon:SetTexCoord(.08,.92,.08,.92);FT:RoundIcon(group.icon)
        group.text=FT:Label(group,"",13);group.text:SetPoint("LEFT",group.icon,"RIGHT",8,0);group.text:SetWidth(242)
        if group.text.SetWordWrap then group.text:SetWordWrap(false) end
        group:RegisterForClicks("LeftButtonUp","RightButtonUp")
        group:SetScript("OnClick",function(_,button) self:ClickNotice("group",button) end)
        group:RegisterForDrag("LeftButton");group:SetScript("OnDragStart",function(owner) self:DragStart(owner) end)
        group:SetScript("OnDragStop",function() self:DragUpdate();self.dragging=false end)
        FT:Tooltip(group,"Group buffs",function()
            -- Everyone missing each buff, then the usual click hints.
            local lines={}
            for _,e in ipairs(self.groupMissing or {}) do
                if e.family then lines[#lines+1]=e.family.." ("..e.count.."): "..(#e.names>0 and table.concat(e.names,", ") or "names hidden") end
            end
            local hint=self:HideHint()
            if #lines==0 then return hint end
            return table.concat(lines,"\n")..(hint and hint~="" and ("\n\n"..hint) or "")
        end)
    end
    self:Refresh()
end
-- Per-buff notice styles ---------------------------------------------------
-- A buff can leave the shared notice and get one of its own: a bar (the
-- usual look), an icon with text, or just an icon, with its own size, color,
-- outline, transparency and place on screen. Like every notice, these show
-- out of combat unless the buff has "Also remind in combat" on.
local styleModes={bar=true,both=true,icon=true,text=true}
local outlineNames={[""]="None",OUTLINE="Thin",THICKOUTLINE="Thick"}
local checkedStyles=setmetatable({},{__mode="k"})
local function unit(v,fallback) v=tonumber(v); if not v or v~=v then return fallback end; return math.max(0,math.min(1,v)) end
-- The buff's own look, or nil when it uses the shared notice. Every value is
-- checked when first read, so an imported or hand-edited style can't break a notice.
function Reminder:Style(key)
    local st=self:Settings().styles[key]
    if type(st)~="table" or not styleModes[st.mode] then return nil end
    if checkedStyles[st] then return st end
    local size=tonumber(st.size); st.size=(size and size==size) and math.max(.5,math.min(3,size)) or 1
    st.alpha=math.max(.2,unit(st.alpha,1))
    if type(st.color)~="table" then st.color={1,1,1} end
    for i=1,3 do st.color[i]=unit(st.color[i],1) end
    if type(st.borderColor)~="table" then st.borderColor={0,0,0} end
    for i=1,3 do st.borderColor[i]=unit(st.borderColor[i],0) end
    if not outlineNames[st.outline] then st.outline="" end
    if type(st.border)~="boolean" then st.border=st.mode~="bar" end
    if type(st.pulse)~="boolean" then st.pulse=false end
    for _,field in ipairs({"x","y","screenWidth","screenHeight"}) do if type(st[field])~="number" or st[field]~=st[field] then st[field]=nil end end
    checkedStyles[st]=true
    return st
end
-- Name and icon for a style's sample notice; nil when this character can't have that buff.
function Reminder:StyleInfo(key)
    local learned=self.learnedCache or {}
    local slot=type(key)=="string" and key:match("^weapon:(%a+)$")
    if slot then
        local kind=self:WeaponKind()
        if not kind then return nil end
        local hand=slot=="main" and "main hand" or "off hand"
        if kind=="poison" then return "Poison ("..hand..")",POISON_ICON end
        local name=self:Settings()[slot.."Enchant"]
        if not name or name=="" then for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate; break end end end
        return "Weapon buff ("..hand..")",name and learned[name] and learned[name].icon or "Interface\\Icons\\Spell_Nature_RockBiter"
    end
    if key=="food" then local _,icon=self:FoodInfo(); return "Food buff",icon end
    if learned[key] then return key,learned[key].icon end
end
function Reminder:StyleChanged()
    self.styleStamp=(self.styleStamp or 0)+1
    self:Refresh(self.learnedCache)
    self:RefreshStyle()
end
function Reminder:HideCustom()
    for _,notice in pairs(self.custom or {}) do notice:Hide() end
end
function Reminder:CustomNotice(key)
    self.custom=self.custom or {}
    local notice=self.custom[key]
    if notice then return notice end
    notice=CreateFrame("Button",nil,UIParent); notice:SetFrameStrata("LOW"); notice:SetSize(285,34)
    notice.key=key
    -- The bar look lives on its own layer so the icon looks can drop it.
    notice.bar=CreateFrame("Frame",nil,notice); notice.bar:SetAllPoints(notice)
    if notice.bar.SetFrameLevel then notice.bar:SetFrameLevel(math.max(0,(notice:GetFrameLevel() or 1)-1)) end
    FT:Panel(notice.bar); FT:MeterSkin(notice.bar)
    local skins=FT.modules.IconStyles; if skins and skins.SkinPanel then skins:SkinPanel(notice.bar,"notices",{0.075,0.058,0.04,1},{.61,.51,.31,1}) end
    notice.border=notice:CreateTexture(nil,"BORDER"); notice.border:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
    notice.icon=notice:CreateTexture(nil,"ARTWORK"); notice.icon:SetTexCoord(.08,.92,.08,.92); FT:RoundIcon(notice.icon)
    notice.border:SetPoint("TOPLEFT",notice.icon,"TOPLEFT",-2,2); notice.border:SetPoint("BOTTOMRIGHT",notice.icon,"BOTTOMRIGHT",2,-2)
    notice.text=FT:Label(notice,"",13); notice.text:SetJustifyH("LEFT")
    if notice.text.SetWordWrap then notice.text:SetWordWrap(false) end
    notice.pulse=notice:CreateAnimationGroup(); notice.pulse:SetLooping("BOUNCE")
    notice.fade=notice.pulse:CreateAnimation("Alpha"); notice.fade:SetDuration(.7); notice.fade:SetSmoothing("IN_OUT")
    notice:RegisterForClicks("LeftButtonUp","RightButtonUp")
    notice:SetScript("OnClick",function(_,button)
        -- While you are styling or moving it, a click must not dismiss it.
        if button~="RightButton" and (self.moving or self.styleKey==key) then return end
        self:ClickNotice("style:"..key,button)
    end)
    notice:SetMovable(true); notice:SetClampedToScreen(true); notice:RegisterForDrag("LeftButton")
    notice:SetScript("OnDragStart",function(owner)
        if not (self.moving or self.styleKey==key) or InCombatLockdown() then return end
        owner.dragging=true; owner:StartMoving()
    end)
    notice:SetScript("OnDragStop",function(owner)
        if not owner.dragging then return end
        owner:StopMovingOrSizing(); owner.dragging=false
        if owner.SetUserPlaced then owner:SetUserPlaced(false) end
        local st=self:Style(key); local cx,cy=owner:GetCenter()
        if st and cx and cy then
            local scale=owner:GetScale() or 1
            st.x,st.y=cx*scale,cy*scale; st.screenWidth,st.screenHeight=UIParent:GetWidth(),UIParent:GetHeight()
        end
        owner.placedAt=nil; self:Refresh(self.learnedCache)
    end)
    FT:Tooltip(notice,"Missing buff",function() return (notice.message or "Buff missing").."\n"..self:HideHint() end)
    notice:Hide()
    self.custom[key]=notice
    return notice
end
-- Size, pieces and colors for a look. Runs only when the look changed.
function Reminder:LayoutCustom(notice,st)
    local icon,text=notice.icon,notice.text
    icon:ClearAllPoints(); text:ClearAllPoints()
    icon:SetShown(st.mode~="text")
    text:SetJustifyH(st.mode=="text" and "CENTER" or "LEFT")
    if st.mode=="icon" then
        notice:SetSize(40,40); icon:SetSize(40,40); icon:SetPoint("CENTER")
        text:Hide()
    elseif st.mode=="text" then
        -- Just the words, centred where the notice sits.
        notice:SetSize(264,26); icon:SetSize(20,20); icon:SetPoint("CENTER")
        text:SetPoint("CENTER"); text:SetWidth(264); text:Show()
    elseif st.mode=="both" then
        notice:SetSize(264,36); icon:SetSize(36,36); icon:SetPoint("LEFT",0,0)
        text:SetPoint("LEFT",icon,"RIGHT",8,0); text:SetWidth(220); text:Show()
    else
        notice:SetSize(285,34); icon:SetSize(20,20); icon:SetPoint("LEFT",8,0)
        text:SetPoint("LEFT",icon,"RIGHT",8,0); text:SetWidth(242); text:Show()
    end
    notice.bar:SetShown(st.mode=="bar")
    local font=text:GetFont()
    local size=(st.mode=="both" or st.mode=="text") and 15 or 13
    local okFont=text:SetFont(font or FT.bodyFont,size,st.outline)
    if okFont==false or not text:GetFont() then text:SetFont("Fonts\\FRIZQT__.TTF",size,st.outline) end
    text:SetTextColor(st.color[1],st.color[2],st.color[3])
    notice.border:SetVertexColor(st.borderColor[1],st.borderColor[2],st.borderColor[3],1); notice.border:SetShown(st.border and st.mode~="text")
    notice:SetScale(st.size); notice:SetAlpha(st.alpha)
    -- A gentle fade down and back, from the look's own transparency.
    notice.fade:SetFromAlpha(st.alpha); notice.fade:SetToAlpha(st.alpha*.35)
    if st.pulse then if not notice.pulse:IsPlaying() then notice.pulse:Play() end
    elseif notice.pulse:IsPlaying() then notice.pulse:Stop() end
    notice.placedAt=nil
end
-- Where it sits: where you dragged it, or (flowX, flowY) in the column
-- that starts at the shared notice's own spot.
function Reminder:PlaceCustom(notice,st,flowX,flowY)
    if notice.dragging==true then return end
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local x=st.x and st.x*(st.screenWidth and w/st.screenWidth or 1)
    local y=st.y and st.y*(st.screenHeight and h/st.screenHeight or 1)
    if not x or not y then x,y=flowX,flowY end
    x=math.max(20,math.min(w-20,x)); y=math.max(20,math.min(h-20,y))
    local stamp=x..":"..y..":"..st.size
    if notice.placedAt==stamp then return end
    notice.placedAt=stamp
    notice:ClearAllPoints(); notice:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/st.size,y/st.size)
end
function Reminder:ShowCustom(custom,fighting)
    local s=self:Settings()
    if not next(s.styles) and not self.custom then return end
    local want={}
    for key in pairs(s.styles) do
        local entry=custom[key]
        -- The same hide-after timer and dismissal as the shared notice, per buff.
        if self:NoticeVisible("style:"..key,entry and {entry} or {}) then want[key]=entry end
    end
    -- Samples: every buff with its own look while moving or previewing, and
    -- the one being edited while its look panel is open.
    if not fighting and (self.moving or self.previewSelf) then for key in pairs(s.styles) do if want[key]==nil and self:Style(key) and self:StyleInfo(key) then want[key]=false end end end
    local editing=not fighting and self.styleKey
    if editing and want[editing]==nil and self:Style(editing) then want[editing]=false end
    for key,notice in pairs(self.custom or {}) do if want[key]==nil then notice:Hide() end end
    if not next(want) then return end
    -- Notices you have not dragged anywhere take the shared notice's spot,
    -- or line up under the shared notices when those are showing, so giving
    -- a buff its own look never makes it jump somewhere else.
    local keys={}
    for key in pairs(want) do keys[#keys+1]=key end
    table.sort(keys)
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local baseX=s.x and s.x*(s.screenWidth and w/s.screenWidth or 1) or w*.5
    local top=(s.y and s.y*(s.screenHeight and h/s.screenHeight or 1) or h-115)+17*s.size
    local used=0
    if self.badge:IsShown() then used=used+42*s.size end
    if self.groupBadge:IsShown() then used=used+42*s.size end
    for _,key in ipairs(keys) do
        local entry=want[key]
        local st=self:Style(key)
        if st then
            local notice=self:CustomNotice(key)
            local message,icon
            if entry then message=entry.message or (entry.name.." missing"); icon=entry.spell and entry.spell.icon
            else local name,sample=self:StyleInfo(key); message=(name or key).." missing — preview"; icon=sample end
            notice.message=message
            notice.icon:SetTexture(icon or 134400)
            if notice.shownText~=message then notice.shownText=message; notice.text:SetText(message) end
            if notice.styleRef~=st or notice.styleStamp~=self.styleStamp then
                notice.styleRef=st; notice.styleStamp=self.styleStamp; self:LayoutCustom(notice,st)
            end
            local height=(st.mode=="icon" and 40 or st.mode=="both" and 36 or st.mode=="text" and 26 or 34)*st.size
            if st.x and st.y then self:PlaceCustom(notice,st)
            else self:PlaceCustom(notice,st,baseX,top-used-height/2); used=used+height+8 end
            notice:Show()
        end
    end
    self:UnstackCustom(keys)
end
-- Notices never sit on top of each other: one placed (or dragged) where
-- another already shows moves just below it. Your saved spot is kept; only
-- what is on screen now is nudged.
local function rect(f)
    local l,b,w,h=f:GetRect()
    if type(l)~="number" or type(w)~="number" then return end
    local s=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
    return l*s,b*s,w*s,h*s
end
local function overlaps(a,b) return a[1]<b[1]+b[3] and b[1]<a[1]+a[3] and a[2]<b[2]+b[4] and b[2]<a[2]+a[4] end
function Reminder:UnstackCustom(keys)
    if self.moving then return end
    local taken={}
    for _,badge in ipairs({self.badge,self.groupBadge}) do
        if badge and badge:IsShown() then local l,b,w,h=rect(badge); if l then taken[#taken+1]={l,b,w,h} end end
    end
    for _,key in ipairs(keys) do
        local notice=self.custom and self.custom[key]
        if notice and notice:IsShown() and not notice.dragging then
            local l,b,w,h=rect(notice)
            if l then
                local mine={l,b,w,h}
                for _=1,8 do
                    local hit
                    for _,r in ipairs(taken) do if overlaps(mine,r) then hit=r; break end end
                    if not hit then break end
                    mine[2]=hit[2]-h-8
                end
                if mine[2]~=b then
                    local st=self:Style(key); local size=st and st.size or 1
                    notice:ClearAllPoints(); notice:SetPoint("CENTER",UIParent,"BOTTOMLEFT",(l+w/2)/size,(mine[2]+h/2)/size)
                    notice.placedAt=nil
                end
                taken[#taken+1]=mine
            end
        end
    end
end
-- The small panel beside the page where one buff's look is set.
local modeChoices={{"default","Default (shared notice)","Default"},{"bar","Bar"},{"both","Icon and text"},{"icon","Icon only"},{"text","Text only"}}
function Reminder:OpenStyle(key,title)
    if not self.frame then return end
    if not self.stylePanel then
        local frame=self.frame
        local panel=CreateFrame("Frame",nil,frame); self.stylePanel=panel
        panel:SetSize(300,474); panel:SetFrameStrata("FULLSCREEN"); panel:SetFrameLevel(frame:GetFrameLevel()+20); panel:SetClampedToScreen(true)
        FT:MakeDraggable(panel,frame); FT:Panel(panel); panel:Hide()
        FT:AddClose(panel,nil,8)
        panel.title=FT:Label(panel,"",16,true); panel.title:SetPoint("TOPLEFT",16,-14); panel.title:SetWidth(236); panel.title:SetJustifyH("LEFT"); panel.title:SetTextColor(1,.82,0)
        if panel.title.SetWordWrap then panel.title:SetWordWrap(false) end
        panel.hint=FT:Label(panel,"",11); panel.hint:SetPoint("TOPLEFT",16,-40); panel.hint:SetWidth(268); panel.hint:SetJustifyH("LEFT"); panel.hint:SetTextColor(.66,.59,.48)
        local icon="Interface\\Icons\\"..FT.icons.skins
        local function current() return self.styleKey and self:Style(self.styleKey) end
        local function change(fn) local st=current(); if st then fn(st); self:StyleChanged() end end
        panel.mode=FT:Dropdown(panel,268,function()
            local list={}; for _,c in ipairs(modeChoices) do list[#list+1]={value=c[1],label=c[2],icon=icon} end; return list
        end,function(value)
            local key=self.styleKey; if not key then return end
            local styles=self:Settings().styles
            if value=="default" then styles[key]=nil
            else
                -- A new look starts as a copy of the shared notice: same size and text color.
                if type(styles[key])~="table" then
                    local shared=self:Settings()
                    styles[key]={size=shared.size,color={shared.textColor[1],shared.textColor[2],shared.textColor[3]}}
                end
                styles[key].mode=value; checkedStyles[styles[key]]=nil
                -- Icon looks start with a border, the bar without.
                if styles[key].border==nil then styles[key].border=value~="bar" end
                -- Text with nothing behind it needs an outline to stay readable.
                if value=="text" and not styles[key].outline then styles[key].outline="OUTLINE" end
            end
            self:StyleChanged()
        end,"skins")
        panel.mode:SetPoint("TOPLEFT",16,-78); panel.mode.menuWidth=268
        if panel.mode.label.SetWordWrap then panel.mode.label:SetWordWrap(false) end
        FT:Tooltip(panel.mode,"Look","Default keeps it in the shared notice. The others give it a notice of its own.")
        local function slider(label,top,low,high,step,lowText,highText,tip,apply)
            local text=FT:Label(panel,"",13); text:SetPoint("TOPLEFT",16,-top)
            local control=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate"); control:SetSize(268,18); control:SetPoint("TOPLEFT",16,-top-20)
            control:SetMinMaxValues(low,high); control:SetValueStep(step); control:SetObeyStepOnDrag(true)
            local l=control.Low or (control.GetName and control:GetName() and _G[control:GetName().."Low"])
            local h=control.High or (control.GetName and control:GetName() and _G[control:GetName().."High"])
            if l and l.SetText then l:SetText(lowText) end
            if h and h.SetText then h:SetText(highText) end
            control:SetScript("OnValueChanged",function(_,value)
                if self.settingStyle then return end
                local st=current(); if not st then return end
                apply(st,value); self:RefreshStyle()
                -- The notice itself follows at most 20 times a second while dragging.
                FT:Coalesce("reminderStyle",function() self.styleStamp=(self.styleStamp or 0)+1; self:Refresh(self.learnedCache) end,.05)
            end)
            FT:Tooltip(control,label,tip)
            return text,control
        end
        panel.sizeText,panel.size=slider("Size",120,.5,3,.05,"50%","300%","Make this buff's notice smaller or bigger.",function(st,v) st.size=math.floor(v*20+.5)/20 end)
        panel.alphaText,panel.alpha=slider("Transparency",182,0,.8,.05,"Solid","See-through","How see-through this notice is.",function(st,v) st.alpha=1-math.floor(v*20+.5)/20 end)
        local function colorButton(label,top,x,width,field,tip)
            local b=FT:QuietButton(panel,label,width,30,"fonts"); b:SetPoint("TOPLEFT",x,-top)
            if b.label.SetWordWrap then b.label:SetWordWrap(false) end
            b.swatch=b:CreateTexture(nil,"ARTWORK"); b.swatch:SetTexture("Interface\\Buttons\\WHITE8X8"); b.swatch:SetSize(16,16); b.swatch:SetPoint("RIGHT",-10,0)
            b:SetScript("OnClick",function()
                local st=current(); if not st or not ColorPickerFrame then return end
                local old={unpack(st[field])}
                local function set(r,g,bl) st[field]={r,g,bl}; self:RefreshStyle(); FT:Coalesce("reminderStyle",function() self.styleStamp=(self.styleStamp or 0)+1; self:Refresh(self.learnedCache) end,.05) end
                local function pick() set(ColorPickerFrame:GetColorRGB()) end
                local function cancel() set(old[1],old[2],old[3]) end
                if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker(); ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=pick,cancelFunc=cancel})
                else ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=pick; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
            end)
            FT:Tooltip(b,label,tip)
            return b
        end
        panel.color=colorButton("Text color",246,16,268,"color","The color of this notice's text.")
        panel.outline=FT:Dropdown(panel,268,function()
            return {{value="",label="Text outline: None",icon=icon},{value="OUTLINE",label="Text outline: Thin",icon=icon},{value="THICKOUTLINE",label="Text outline: Thick",icon=icon}}
        end,function(value) change(function(st) st.outline=value end) end,"fonts")
        panel.outline:SetPoint("TOPLEFT",16,-284); panel.outline.menuWidth=268
        if panel.outline.label.SetWordWrap then panel.outline.label:SetWordWrap(false) end
        FT:Tooltip(panel.outline,"Text outline","A dark edge so the text stays readable.")
        panel.border=FT:QuietButton(panel,"",130,30); panel.border:SetPoint("TOPLEFT",16,-320)
        panel.border:SetScript("OnClick",function() change(function(st) st.border=not st.border end) end)
        FT:Tooltip(panel.border,"Icon border","A thin rounded border around the icon.")
        panel.borderColor=colorButton("Border",320,154,130,"borderColor","The color of the icon's border.")
        panel.pulse=FT:QuietButton(panel,"",130,30); panel.pulse:SetPoint("TOPLEFT",16,-356)
        panel.pulse:SetScript("OnClick",function() change(function(st) st.pulse=not st.pulse end) end)
        FT:Tooltip(panel.pulse,"Gentle pulse","Slowly fade the notice in and out.")
        panel.reset=FT:QuietButton(panel,"Reset position",130,30); panel.reset:SetPoint("TOPLEFT",154,-356)
        panel.reset:SetScript("OnClick",function() change(function(st) st.x,st.y,st.screenWidth,st.screenHeight=nil,nil,nil,nil end) end)
        FT:Tooltip(panel.reset,"Reset position","Back to the shared notice's spot.")
        for _,b in ipairs({panel.border,panel.pulse,panel.reset}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        -- Not part of the look: works with the shared notice too.
        panel.combat=FT:QuietButton(panel,"",268,30,"Ability_Warrior_BattleShout"); panel.combat:SetPoint("TOPLEFT",16,-394)
        if panel.combat.label.SetWordWrap then panel.combat.label:SetWordWrap(false) end
        panel.combat:SetScript("OnClick",function()
            local key=self.styleKey; if not key then return end
            if self:Settings().combatAll then FT:Toast("Remind in combat is on for all buffs.",3); return end
            local combat=self:Settings().combat
            combat[key]=not combat[key] and true or nil
            self:RefreshStyle(); self:Refresh(self.learnedCache)
        end)
        FT:Tooltip(panel.combat,"Also remind in combat","Also show this buff's notice in a fight, for buffs you cast in combat like Battle Shout.")
        panel.note=FT:Label(panel,"",11); panel.note:SetPoint("TOPLEFT",16,-434); panel.note:SetWidth(268); panel.note:SetJustifyH("LEFT"); panel.note:SetTextColor(.66,.59,.48)
        panel.styled={panel.sizeText,panel.size,panel.alphaText,panel.alpha,panel.color,panel.outline,panel.border,panel.borderColor,panel.pulse,panel.reset}
        panel:HookScript("OnHide",function() if self.styleKey then self.styleKey=nil; self:Refresh(self.learnedCache) end end)
        frame:HookScript("OnHide",function() panel:Hide() end)
    end
    local panel=self.stylePanel
    -- Clicking the same gear again closes the panel.
    if panel:IsShown() and self.styleKey==key then panel:Hide(); return end
    self.styleKey=key; panel.name=title or key
    panel:ClearAllPoints()
    local right=self.frame.GetRight and self.frame:GetRight(); local screen=UIParent.GetWidth and UIParent:GetWidth()
    if type(right)=="number" and type(screen)=="number" and screen-right<310 then panel:SetPoint("TOPRIGHT",self.frame,"TOPLEFT",-8,-132)
    else panel:SetPoint("TOPLEFT",self.frame,"TOPRIGHT",8,-132) end
    panel:Show()
    self:Refresh(self.learnedCache)
    self:RefreshStyle()
end
function Reminder:RefreshStyle()
    local panel=self.stylePanel
    if not panel or not self.styleKey then return end
    local st=self:Style(self.styleKey)
    panel.title:SetText(panel.name or self.styleKey)
    local mode=st and st.mode or "default"
    panel.mode.value=mode
    for _,c in ipairs(modeChoices) do if c[1]==mode then panel.mode.label:SetText("Look: "..(c[3] or c[2])) end end
    panel.hint:SetText(st and "Drag the sample on screen to place it." or "Uses the shared notice (shown as a sample).")
    local all=self:Settings().combatAll==true
    local also=all or self:Settings().combat[self.styleKey]==true
    panel.combat.label:SetText(all and "Remind in combat: On (all buffs)" or ("Also remind in combat: "..(also and "On" or "Off"))); FT:SetSelected(panel.combat,also)
    panel.combat:SetAlpha(all and .5 or 1)
    -- You can't eat in a fight.
    panel.combat:SetShown(self.styleKey~="food")
    -- Everything below belongs to a look of its own.
    for _,control in ipairs(panel.styled) do
        control:SetAlpha(st and 1 or .4)
        if control.SetEnabled then control:SetEnabled(st~=nil) elseif control.EnableMouse and control.SetValue then control:EnableMouse(st~=nil) end
    end
    local size,alpha=st and st.size or 1,st and st.alpha or 1
    self.settingStyle=true; panel.size:SetValue(size); panel.alpha:SetValue(1-alpha); self.settingStyle=false
    panel.sizeText:SetText("Size: "..math.floor(size*100+.5).."%")
    panel.alphaText:SetText("Transparency: "..math.floor((1-alpha)*100+.5).."%")
    local color,border=st and st.color or {1,1,1},st and st.borderColor or {0,0,0}
    panel.color.swatch:SetVertexColor(color[1],color[2],color[3]); panel.borderColor.swatch:SetVertexColor(border[1],border[2],border[3])
    panel.outline.value=st and st.outline or ""; panel.outline.label:SetText("Text outline: "..outlineNames[st and st.outline or ""])
    panel.border.label:SetText("Icon border: "..(st and st.border and "On" or "Off")); FT:SetSelected(panel.border,st~=nil and st.border)
    panel.pulse.label:SetText("Pulse: "..(st and st.pulse and "On" or "Off")); FT:SetSelected(panel.pulse,st~=nil and st.pulse)
    -- Text only has no icon, so no icon border.
    if st and st.mode=="text" then panel.border:SetAlpha(.4); panel.border:SetEnabled(false); panel.borderColor:SetAlpha(.4); panel.borderColor:SetEnabled(false) end
    panel.note:SetText(st and (st.mode=="icon" and "Hover the icon to see which buff." or st.mode=="text" and "Just the words, with an outline." or "") or "Pick a look to give this buff its own notice.")
end
local kindOrder={"group","blessing","aura","armor","self"}
local kindLabels={group="Group buffs",blessing="Blessings",aura="Auras, aspects and stances",armor="Armor",self="Self buffs"}
local kindIcons={group="Spell_Holy_PrayerOfFortitude",blessing="Spell_Holy_FistOfJustice",aura="Spell_Holy_DevotionAura",armor="Spell_Frost_FrostArmor02",self="Spell_Holy_WordFortitude"}
local function kindOf(entry)
    local g=entry.group
    if g=="wild" or g=="fortitude" or g=="intellect" or g=="spirit" or g=="salvation" then return "group" end
    if g=="blessing" then return "blessing" end
    if g=="stance" or g=="protection" or g=="aspect" then return "aura" end
    if g=="armor" then return "armor" end
    return "self"
end
-- Stable sort into the heading order above, keeping each class's own order inside a group.
function Reminder:SortByKind(list)
    local rank={}; for i,kind in ipairs(kindOrder) do rank[kind]=i end
    for i,entry in ipairs(list) do entry.listIndex=i end
    table.sort(list,function(a,b)
        local ka,kb=rank[kindOf(a)],rank[kindOf(b)]
        if ka~=kb then return ka<kb end
        return a.listIndex<b.listIndex
    end)
    return list
end
function Reminder:RefreshMenu(learned)
    local s=self:Settings();learned=learned or self:Learned()
    self.toggle.label:SetText("Self reminders: "..(s.enabled and "On" or "Off"));FT:SetSelected(self.toggle,s.enabled)
    self.groupToggle.label:SetText("Group reminders: "..(s.groupEnabled and "On" or "Off"));FT:SetSelected(self.groupToggle,s.groupEnabled)
    for field,row in pairs(self.whereRows) do
        local active=field=="selfWhere" and s.enabled or field=="groupWhere" and s.groupEnabled
        for key,button in pairs(row.buttons) do FT:SetSelected(button,s[field][key]); button:SetAlpha(active and 1 or .5) end
    end
    self.rankToggle.label:SetText("Low-rank alerts: "..(s.lowRank and "On" or "Off"));FT:SetSelected(self.rankToggle,s.lowRank)
    self.rankOneToggle.label:SetText("Ignore rank 1: "..(s.ignoreRankOne and "On" or "Off"));FT:SetSelected(self.rankOneToggle,s.ignoreRankOne)
    self.markerToggle.label:SetText("Marker on bars: "..(s.rankMarker and "On" or "Off"));FT:SetSelected(self.markerToggle,s.rankMarker)
    local ignoredCount=0;for _ in pairs(type(s.ignoredRanks)=="table" and s.ignoredRanks or {}) do ignoredCount=ignoredCount+1 end
    self.exceptions.label:SetText("Exceptions"..(ignoredCount>0 and (" ("..ignoredCount..")") or ""))
    -- Peeks (a setting changed) don't count as the switch being on.
    for _,b in ipairs({self.moveButton,self.selfPreview}) do b.label:SetText("Preview: "..(self:PreviewOn() and "On" or "Off")); FT:SetSelected(b,self:PreviewOn()) end
    self.groupPreview.label:SetText("Preview: "..(self.previewGroup and "On" or "Off")); FT:SetSelected(self.groupPreview,self.previewGroup and true or false)
    self.sizeValue:SetText("Size: "..math.floor(s.size*100+.5).."%")
    self.settingSize=true;self.sizeSlider:SetValue(s.size);self.settingSize=false
    self.hideChoice.value=s.hideAfter;self.hideChoice.label:SetText(self:HideAfterText())
    self.colorSwatch:SetVertexColor(unpack(s.textColor))
    self.groupColorSwatch:SetVertexColor(unpack(s.groupTextColor))
    -- The buffs shown are always those of the tree in use.
    local editSpec=self:CurrentSpec()
    local manual=self:ManualSpec()
    self.specChoice.value=manual or "auto"
    self.specChoice.label:SetText("Talent tree: "..editSpec..(manual and " (your choice)" or " (automatic)"))
    local icon="Interface\\Icons\\INV_Misc_Book_09"
    for _,spec in ipairs(self:TalentSpecs()) do if spec.name==editSpec then icon=spec.icon or icon;break end end
    self.specChoice.icon:SetTexture(icon)
    local available=self:SortByKind(self:Available(learned,editSpec))
    local watched=0
    for i,button in ipairs(self.rows) do
        local entry=available[i];button.entry=entry
        if entry then
            local enabled=self:Enabled(entry,editSpec,learned)
            if enabled then watched=watched+1 end
            button.label:SetText(entry.name..": "..(enabled and "On" or "Off"));FT:SetSelected(button,enabled)
            button.icon:SetTexture(entry.spell.icon or 134400)
            FT:SetSelected(button.gear,self:Style(entry.name)~=nil)
        end
    end
    local weaponKind=self:WeaponKind()
    local weapon=weaponKind~=nil
    for _,slot in ipairs({"main","off"}) do
        local dropdown=self[slot.."Dropdown"]
        if weapon then
            local hand=slot=="main" and "Main hand: " or "Off hand: "
            if weaponKind=="poison" then
                local on=s[slot.."Poison"]==true
                -- Switched on before poisons are learned: it waits, and says so.
                local ready=on and self:PoisonsKnown(learned)
                dropdown.value=on and "on" or ""; dropdown.label:SetText(hand..(not on and "Off" or ready and "Remind when no poison" or "On, once you can use poisons"))
                dropdown.icon:SetTexture(POISON_ICON)
                if on then watched=watched+1 end
            else
                local name=s[slot.."Enchant"]
                if slot=="main" and name==nil then for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end end
                dropdown.value=name or "";dropdown.label:SetText(hand..(name~="" and name or "Off"))
                if name and name~="" then watched=watched+1 end
            end
            FT:SetSelected(dropdown.gear,self:Style("weapon:"..slot)~=nil)
        end
    end
    local _,foodIcon=self:FoodInfo()
    self.powerToggle.label:SetText("Wait for "..self:PowerWord()..": "..(s.powerReady and "On" or "Off")); FT:SetSelected(self.powerToggle,s.powerReady)
    self.combatAllToggle.label:SetText("Also in combat: "..(s.combatAll and "All buffs" or "Chosen buffs")); FT:SetSelected(self.combatAllToggle,s.combatAll)
    self.foodToggle.label:SetText("XP food: "..(s.food and "On" or "Off")); FT:SetSelected(self.foodToggle,s.food)
    self.foodStatToggle.label:SetText("Stat food: "..(s.foodStat and "On" or "Off")); FT:SetSelected(self.foodStatToggle,s.foodStat)
    self.foodStatToggle.icon:SetTexture(foodIcon)
    self.foodToggle.icon:SetTexture(foodIcon)
    FT:SetSelected(self.foodToggle.gear,self:Style("food")~=nil)
    self.foodWhen.label:SetText(s.foodWhen=="always" and "Remind: Always" or "Remind: While leveling")
    self.foodWhen:SetAlpha(s.food and 1 or .5)
    if s.food then watched=watched+1 end
    self.watchedCount=watched
    local pane=self.pane or "self"
    -- Controls that stay are only moved, never hidden and shown again: a
    -- button hidden for a moment while you press it would lose the click.
    local placed={}
    self.placedNow=placed
    local info=self.paneInfo[pane]
    self.frame.titleText:SetText(info.title)
    -- One page per section (the group's sidebar on the left), full width.
    local X,COL=24,240
    -- Only moved when its spot changes (a slider re-anchored while you drag it can drop the drag).
    local function place(control,x,top)
        placed[control]=true
        if control.placedX~=x or control.placedY~=top or not control:IsShown() then control:ClearAllPoints();control:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top); control.placedX,control.placedY=x,top end
        control:Show()
    end
    -- A short line on what the page is for, at the top like other pages.
    self.paneHint:SetText(info.hint)
    place(self.paneHint,X,62)
    local hintHeight=self.paneHint:GetStringHeight()
    local y=62+math.max(14,type(hintHeight)=="number" and hintHeight or 14)+10
    if pane=="self" then
        place(self.toggle,X,y); place(self.selfPreview,X+COL,y); y=y+46
        place(self.specChoice,X,y);y=y+40
        -- Buffs grouped under small headings (Blessings, Auras & stances, ...),
        -- two per row inside each group.
        local index,headUsed=1,0
        for _,kind in ipairs(kindOrder) do
            local first=index
            while available[index] and kindOf(available[index])==kind do index=index+1 end
            local count=index-first
            if count>0 then
                headUsed=headUsed+1
                local h=self.kindHeads[headUsed]; h.ftHeading.icon=kindIcons[kind]; h:SetText(kindLabels[kind]); place(h,X,y); y=y+18
                -- Two per row; a name too long to sit beside its switch
                -- (Aspect of the Dragonhawk) gets a whole row.
                -- One long name makes the whole group full rows, so rows in a
                -- group are always the same width.
                local wide=false
                for n=0,count-1 do
                    local b=self.rows[first+n]
                    local w=b.label.GetUnboundedStringWidth and b.label:GetUnboundedStringWidth() or b.label:GetStringWidth()
                    if type(w)=="number" and w>114 then wide=true end
                end
                local col,rowY=0,y
                for n=0,count-1 do
                    local b=self.rows[first+n]; b:SetWidth(232)
                    if wide then
                        if col==1 then rowY=rowY+38; col=0 end
                        b:SetWidth(472); place(b,X,rowY); rowY=rowY+38
                    else
                        place(b,X+col*COL,rowY)
                        if col==1 then col=0; rowY=rowY+38 else col=1 end
                    end
                end
                if col==1 then rowY=rowY+38 end
                y=rowY+6
            end
        end
        if #available==0 and not weapon then place(self.empty,X,y+4); y=y+30 end
        if weapon then
            headUsed=headUsed+1
            local h=self.kindHeads[headUsed]; h.ftHeading.icon="INV_Sword_04"; h:SetText(weaponKind=="poison" and "Weapon poisons" or "Weapon buffs"); place(h,X,y); y=y+18
            place(self.mainDropdown,X,y);place(self.offDropdown,X,y+38)
            place(self.mainDropdown.gear,X+444,y);place(self.offDropdown.gear,X+444,y+38);y=y+80
        end
        headUsed=headUsed+1
        local fh=self.kindHeads[headUsed]; fh.ftHeading.icon=nil; fh:SetText("Food"); place(fh,X,y); y=y+18
        place(self.foodToggle,X,y); place(self.foodWhen,X+COL,y); y=y+40
        place(self.foodStatToggle,X,y); y=y+44
        headUsed=headUsed+1
        local h=self.kindHeads[headUsed]; h.ftHeading.icon=nil; h:SetText("Show in"); place(h,X,y); y=y+18
        self:PlaceWhere("selfWhere",X,y);y=y+40
        place(self.powerToggle,X,y);place(self.combatAllToggle,X+COL,y);y=y+34
        self.combatAllToggle:SetWidth(232)
    elseif pane=="group" then
        place(self.groupToggle,X,y); place(self.groupPreview,X+COL,y); y=y+46
        local h=self.kindHeads[1]; h.ftHeading.icon=nil; h:SetText("Show in"); place(h,X,y); y=y+18
        self:PlaceWhere("groupWhere",X,y);y=y+40
        place(self.groupColorButton,X,y);y=y+40
    elseif pane=="rank" then
        local function head(n,text) local h=self.kindHeads[n]; h.ftHeading.icon=nil; h:SetText(text); place(h,X,y); y=y+18 end
        head(1,"Alerts")
        place(self.rankToggle,X,y);place(self.rankOneToggle,X+COL,y);y=y+46
        head(2,"Action bar marker")
        place(self.markerToggle,X,y);place(self.exceptions,X+COL,y);y=y+32
    elseif pane=="look" then
        local function head(n,text) local h=self.kindHeads[n]; h.ftHeading.icon=nil; h:SetText(text); place(h,X,y); y=y+18 end
        place(self.moveButton,X+COL,y);y=y+46
        head(1,"Look")
        place(self.sizeValue,X,y+3);place(self.sizeSlider,X+124,y);y=y+36
        place(self.selfColorButton,X,y);y=y+46
        head(2,"Timing")
        place(self.hideChoice,X,y);y=y+46
        head(3,"Position")
        place(self.resetPosition,X,y);y=y+40
    end
    for _,control in ipairs(self.paneControls) do if not placed[control] then control:Hide() end end
    for _,h in ipairs(self.kindHeads) do if not placed[h] then h:Hide() end end
    self.placedNow=nil
    self.contentBottom=y
    FT:RefreshDock(self.frame)
end
-- The state of each section, for the sidebar.
function Reminder:PaneStatus(key)
    local s=self:Settings()
    if key=="self" then
        local watched=self.watchedCount
        if not watched then
            watched=0; local learned=self:Learned(); local spec=self:CurrentSpec()
            for _,entry in ipairs(self:Available(learned,spec)) do if self:Enabled(entry,spec,learned) then watched=watched+1 end end
            if s.food then watched=watched+1 end
        end
        return (s.enabled and "On" or "Off").." · "..watched.." watched"
    elseif key=="group" then return s.groupEnabled and "On" or "Off"
    elseif key=="rank" then return "Alerts "..(s.lowRank and "on" or "off").." · bar marker "..(s.rankMarker and "on" or "off")
    elseif key=="look" then
        local hide=s.hideAfter
        return math.floor(s.size*100+.5).."% · "..(hide==0 and "never hides" or "hides after "..(hide>=60 and (hide/60).." min" or hide.." s"))
    end
    return ""
end
function Reminder:PlaceWhere(field,x0,top)
    local x=x0
    for _,place in ipairs(self.places) do
        local b=self.whereRows[field].buttons[place[1]]
        if self.placedNow then self.placedNow[b]=true end
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top); b:Show(); x=x+96
    end
end
-- Buff reminders is a group like the rest of ForeverTools: Your buffs,
-- Group buffs, Low ranks, Look and position, and Cooldown reminders in the
-- sidebar. The first four are pages of one window.
local pages={self="BuffReminder",group="BuffGroup",rank="BuffRanks",look="BuffLook"}
Reminder.pages=pages
Reminder.ownDockRefresh=true -- Refresh here redraws the notices, not the page
function Reminder:Build()
    if not self.frame then
        local frame=FT:Window("ForeverToolsBuffReminders","Your buffs",520,720);self.frame=frame
        for _,name in pairs(pages) do if FT.modules[name] then FT.modules[name].frame=frame end end
        local W=472
        -- Every control sits straight on the page; RefreshMenu places them.
        local detail=CreateFrame("Frame",nil,frame); detail:SetAllPoints(); self.detail=detail
        local top=detail
        self.paneControls={}
        local function pane(control) self.paneControls[#self.paneControls+1]=control; return control end
        self.paneInfo={
            self={title="Your buffs",icon="Spell_Holy_WordFortitude",hint="Pick the buffs to watch. The gear on a buff gives it its own look."},
            group={title="Group buffs",icon="Spell_Holy_PrayerOfFortitude",hint="A notice when your group is missing your buff."},
            rank={title="Low ranks",icon="INV_Misc_Book_07",hint="Spells cast below your best rank. Visit a trainer once."},
            look={title="Look and position",icon="Ability_Rogue_Sprint",hint="Size, timing and place of the notices."},
        }
        self.paneHint=pane(FT:Label(detail,"",12)); self.paneHint:SetTextColor(.66,.59,.48); self.paneHint:SetWidth(W); self.paneHint:SetJustifyH("LEFT")
        if self.paneHint.SetWordWrap then self.paneHint:SetWordWrap(true) end
        self.toggle=pane(FT:AccentButton(top,"",232,34,"buffs"))
        self.toggle:SetScript("OnClick",function() local s=self:Settings();s.enabled=not s.enabled;self:Apply() end)
        FT:Tooltip(self.toggle,"Self-buff reminders","A notice when one of your buffs is missing. Hidden in combat, on flights and while dead.")
        self.groupToggle=pane(FT:AccentButton(top,"",232,34,"party"))
        self.groupToggle:SetScript("OnClick",function() local s=self:Settings();s.groupEnabled=not s.groupEnabled;self:Apply() end)
        FT:Tooltip(self.groupToggle,"Group reminders","A notice when someone in your group is missing your buff. Hidden in combat.")
        local tip="Shows sample notices, so you can drag them into place. Click again to lock them."
        self.moveButton=pane(FT:QuietButton(top,"Preview: Off",232,34,"Spell_Holy_MindVision"))
        self.moveButton:SetScript("OnClick",function() self:SetPreview(not self:PreviewOn()) end)
        FT:Tooltip(self.moveButton,"Preview",tip)
        self.selfPreview=pane(FT:QuietButton(top,"Preview: Off",232,34,"Spell_Holy_MindVision"))
        self.selfPreview:SetScript("OnClick",function() self:SetPreview(not self:PreviewOn()) end)
        FT:Tooltip(self.selfPreview,"Preview",tip)
        for _,b in ipairs({self.toggle,self.groupToggle,self.moveButton,self.selfPreview}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        self.specChoice=pane(FT:Dropdown(detail,W,function() return self:SpecChoices() end,function(value) self:PickSpec(value) end,"classes"))
        self.powerToggle=pane(FT:QuietButton(detail,"",232,32,"Spell_Nature_ManaRegenTotem"))
        self.powerToggle:SetScript("OnClick",function() local s=self:Settings(); s.powerReady=not s.powerReady; self:Apply() end)
        FT:Tooltip(self.powerToggle,"Wait for rage, mana or energy","Wait until you have the rage, mana or energy to cast the buff.")
        self.combatAllToggle=pane(FT:QuietButton(detail,"",232,32,"Ability_Warrior_BattleShout"))
        FT:MakeChoice(self.combatAllToggle,{{false,"Chosen buffs","Only buffs you turned on with their gear."},{true,"All buffs","Every self buff and weapon buff you watch."}},function() return self:Settings().combatAll==true end,function(v) self:Settings().combatAll=v; self:Apply() end)
        FT:Tooltip(self.combatAllToggle,"Remind in combat","All buffs: every watched buff also reminds in a fight. Chosen buffs: only those set with their gear. Food never does.")
        self.specChoice.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        FT:Tooltip(self.specChoice,"Your talent tree","Each tree keeps its own buff list. Automatic follows your talents.")
        self.rows={}
        self.kindHeads={}
        for i=1,8 do
            local h=FT:Label(detail,"",12,true); h:SetTextColor(.66,.59,.48); FT:SectionHeading(h,nil,320,14); h:Hide(); self.kindHeads[i]=h
        end
        for i=1,12 do
            local b=pane(FT:QuietButton(detail,"",232,32,"welcome"))
            b.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end
            b.label:ClearAllPoints(); b.label:SetPoint("LEFT",b.icon,"RIGHT",8,0); b.label:SetPoint("RIGHT",b,"RIGHT",-32,0)
            -- The gear gives this buff a notice look of its own.
            b.gear=FT:QuietButton(b,"",24,24); b.gear:SetPoint("RIGHT",-4,0); FT:GearIcon(b.gear)
            b.gear:SetScript("OnClick",function() if b.entry then self:OpenStyle(b.entry.name,b.entry.name) end end)
            FT:Tooltip(b.gear,"Notice look","Its own look, and reminders in combat. Lit when set.")
            b:SetScript("OnClick",function()
                local entry=b.entry;if not entry then return end
                local spec=self:CurrentSpec();local selection=self:Selection(spec)
                local on=self:Enabled(entry,spec,self:Learned())
                selection[entry.name]=not on
                if not on and entry.group and entry.group~="protection" then
                    for _,other in ipairs(choices[self:Class()] or {}) do if other[3]==entry.group and other[1]~=entry.name then selection[other[1]]=false end end
                end
                self:Apply()
            end)
            FT:Tooltip(b,"Choose a self buff","Click to watch this buff. Only learned spells are listed.")
            self.rows[i]=b
        end
        self.empty=pane(FT:Label(detail,"No supported self buffs learned yet.",13))
        -- Food buff: the same for every class and talent tree.
        local food=pane(FT:QuietButton(detail,"",232,32,"welcome")); self.foodToggle=food
        food.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if food.label.SetWordWrap then food.label:SetWordWrap(false) end
        food.label:ClearAllPoints(); food.label:SetPoint("LEFT",food.icon,"RIGHT",8,0); food.label:SetPoint("RIGHT",food,"RIGHT",-32,0)
        food:SetScript("OnClick",function() local s=self:Settings(); s.food=not s.food; self:Apply() end)
        FT:Tooltip(food,"XP food reminder","A notice when you lack the XP food buff (5% more kill XP). Only while you carry such food.")
        local stat=pane(FT:QuietButton(detail,"",232,32,"welcome")); self.foodStatToggle=stat
        stat.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if stat.label.SetWordWrap then stat.label:SetWordWrap(false) end
        stat:SetScript("OnClick",function() local s=self:Settings(); s.foodStat=not s.foodStat; self:Apply() end)
        FT:Tooltip(stat,"Stat food reminder","A notice when you lack a stat food buff. Only while you carry such food.")
        food.gear=FT:QuietButton(food,"",24,24); food.gear:SetPoint("RIGHT",-4,0); FT:GearIcon(food.gear)
        food.gear:SetScript("OnClick",function() self:OpenStyle("food","Food buff") end)
        FT:Tooltip(food.gear,"Notice look","Its own look. Lit when set.")
        self.foodWhen=pane(FT:QuietButton(detail,"",232,32,"reset"))
        self.foodWhen.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if self.foodWhen.label.SetWordWrap then self.foodWhen.label:SetWordWrap(false) end
        FT:MakeChoice(self.foodWhen,{{"leveling","While leveling","Stops by itself at max level."},{"always","Always","Keeps reminding at max level too."}},function() return self:Settings().foodWhen end,function(v) self:Settings().foodWhen=v; self:Apply() end)
        FT:Tooltip(self.foodWhen,"When to remind","While leveling: stops at max level. Always: keeps reminding.")
        for _,slot in ipairs({"main","off"}) do
            local dropdown=pane(FT:Dropdown(detail,W-32,function()
                local list={{value="",label="Off"}};local learned=self:Learned()
                if self:WeaponKind()=="poison" then
                    list[2]={value="on",label="Remind when no poison",icon=POISON_ICON,tooltip="A notice when this weapon has no poison. Quiet until you can use poisons."}
                    return list
                end
                for _,name in ipairs(enchants) do if learned[name] then list[#list+1]={value=name,label=name,icon=learned[name].icon} end end
                return list
            end,function(value)
                if self:WeaponKind()=="poison" then self:Settings()[slot.."Poison"]=value=="on" else self:Settings()[slot.."Enchant"]=value end
                self:Apply()
            end,"welcome"))
            self[slot.."Dropdown"]=dropdown
            dropdown.gear=pane(FT:QuietButton(detail,"",28,28)); FT:GearIcon(dropdown.gear)
            dropdown.gear:SetScript("OnClick",function()
                local what=self:WeaponKind()=="poison" and "poison" or "weapon buff"
                self:OpenStyle("weapon:"..slot,(slot=="main" and "Main-hand " or "Off-hand ")..what)
            end)
            FT:Tooltip(dropdown.gear,"Notice look","Its own look, and reminders in combat. Lit when set.")
            FT:Tooltip(dropdown,"Weapon reminder",function()
                if self:WeaponKind()=="poison" then return "A notice when this weapon has no poison. Quiet until you can use poisons. Empty hands and shields are ignored." end
                return "The weapon buff to watch for this hand."
            end)
        end
        -- "Show in" rows: pick every place a notice may appear (multiple choice).
        self.whereRows={}
        for _,field in ipairs({"selfWhere","groupWhere"}) do
            local row={buttons={}}
            for _,place in ipairs(self.places) do
                local key=place[1]
                local b=pane(FT:QuietButton(detail,place[2],88,30))
                b.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end
                b:SetScript("OnClick",function() local s=self:Settings(); s[field][key]=not s[field][key]; self:Apply() end)
                FT:Tooltip(b,place[2],(field=="selfWhere" and "Show self-buff notices here. " or "Show group notices here (in a group). ")..place[3].." Pick as many places as you like.")
                row.buttons[key]=b
            end
            self.whereRows[field]=row
        end
        self.sizeValue=pane(FT:Label(detail,"",14));self.sizeValue:SetWidth(120);self.sizeValue:SetJustifyH("LEFT")
        self.sizeSlider=pane(CreateFrame("Slider",nil,detail,"OptionsSliderTemplate"));self.sizeSlider:SetSize(W-130,18)
        self.sizeSlider:SetMinMaxValues(.7,1.5);self.sizeSlider:SetValueStep(.05);self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,value)
            if self.settingSize then return end
            self:Settings().size=math.floor(value*20+.5)/20;FT:Coalesce("reminderSlider",function() self:Apply() end,.05)
        end)
        FT:Tooltip(self.sizeSlider,"Reminder size","Notice size (70% to 150%).")
        self.hideChoice=pane(FT:Dropdown(detail,W,function()
            local list={};for _,c in ipairs(hideChoices) do list[#list+1]={value=c[1],label=c[2],icon="Interface\\Icons\\INV_Misc_PocketWatch_01"} end;return list
        end,function(value) self:Settings().hideAfter=value;self.notices=nil;self:Apply() end,"fps"))
        self.hideChoice:SetHeight(32); self.hideChoice.menuWidth=W
        FT:Tooltip(self.hideChoice,"Hide notice after","How long a notice stays. Never: until the buff is back or you click it.")
        for _,entry in ipairs({{"textColor","Self text color"},{"groupTextColor","Group text color"}}) do
            local field,label=entry[1],entry[2]
            local color=pane(FT:QuietButton(detail,label,W,32,"fonts"))
            if field=="textColor" then self.selfColorButton=color; color:SetWidth(232) else self.groupColorButton=color end
            local swatch=color:CreateTexture(nil,"ARTWORK");swatch:SetTexture("Interface\\Buttons\\WHITE8X8");swatch:SetSize(18,18);swatch:SetPoint("RIGHT",-12,0)
            if field=="textColor" then self.colorSwatch=swatch else self.groupColorSwatch=swatch end
            color:SetScript("OnClick",function()
                if not ColorPickerFrame then return end
                local s=self:Settings();local old={unpack(s[field])}
                local function change() s[field]={ColorPickerFrame:GetColorRGB()};FT:Coalesce("reminderColor",function() self:Apply() end,.05) end
                local function cancel() s[field]=old;self:Apply() end
                if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
                else ColorPickerFrame:SetColorRGB(unpack(old));ColorPickerFrame.func=change;ColorPickerFrame.cancelFunc=cancel;ColorPickerFrame:Show() end
            end)
            FT:Tooltip(color,label,"Text color of the notice.")
        end
        self.rankToggle=pane(FT:QuietButton(detail,"",232,32,"INV_Misc_Book_07"))
        self.rankToggle:SetScript("OnClick",function() local s=self:Settings();s.lowRank=not s.lowRank;self:Apply() end)
        FT:Tooltip(self.rankToggle,"Low-rank alerts","Warn when you cast a buff below your best rank. Visit a trainer once.")
        self.rankOneToggle=pane(FT:QuietButton(detail,"",232,32,"INV_Misc_Book_11"))
        self.rankOneToggle:SetScript("OnClick",function() local s=self:Settings();s.ignoreRankOne=not s.ignoreRankOne;self:Apply() end)
        FT:Tooltip(self.rankOneToggle,"Ignore rank 1","Never warn about rank 1 spells.")
        self.markerToggle=pane(FT:QuietButton(detail,"",232,32,"INV_Misc_Note_02"))
        self.markerToggle:SetScript("OnClick",function() local s=self:Settings();s.rankMarker=not s.rankMarker;self:Apply() end)
        FT:Tooltip(self.markerToggle,"Low-rank marker on action bars","An amber corner on action buttons below your best rank. Macros are not checked.")
        self.exceptions=pane(FT:Dropdown(detail,232,function() return FT.modules.RankMarker:ExceptionChoices() end,function(value) FT.modules.RankMarker:ToggleIgnore(value) end,"INV_Misc_Note_03"))
        self.exceptions:SetHeight(32); self.exceptions.menuWidth=340
        FT:Tooltip(self.exceptions,"Low-rank exceptions","Spells you downrank on purpose: no marker, no alert.")
        for _,b in ipairs({self.rankToggle,self.rankOneToggle,self.markerToggle,self.exceptions}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        local resetPosition=pane(FT:QuietButton(detail,"Reset position",232,32,"reset"));self.resetPosition=resetPosition
        resetPosition:SetScript("OnClick",function()
            local s=self:Settings();s.x=nil;s.y=nil;s.screenWidth=nil;s.screenHeight=nil;self:Apply()
        end)
        FT:Tooltip(resetPosition,"Reset position","Back to the top center of the screen.")
        self.groupPreview=pane(FT:QuietButton(detail,"Preview: Off",232,34,"Spell_Holy_MindVision"))
        self.groupPreview:SetScript("OnClick",function() local on=not self.previewGroup; self.previewGroup=on or nil; self:SetMoving(on) end)
        FT:Tooltip(self.groupPreview,"Preview","Shows a sample group notice, so you can drag it into place. Click again to lock it.")
        frame:HookScript("OnHide",function()
            self.previewSelf=nil;self.previewGroup=nil;self.peekingSelf=nil
            self:SetMoving(false)
        end)
        FT:PageInfo(frame,"Buff reminders","A small notice when one of your buffs is missing. Pick a section on the left.\n\nNotices hide in combat, on flights and while dead. Left-click a notice to dismiss it, right-click for settings.")
    end
end
function Reminder:ShowPage(pane)
    self:Build()
    self.pane=pane
    self:Apply();self.frame:Show()
    -- Apply only redraws the page when it is open.
    self:RefreshMenu()
end
function Reminder:Open() self:ShowPage("self") end
function Reminder:PeekSelf()
    if self.previewSelf or self.moving then return end
    self.previewSelf=true; self.peekingSelf=true; self:Apply()
    local token={}; self.peekToken=token
    C_Timer.After(4,function() if self.peekToken==token and self.previewSelf and self.peekingSelf then self.previewSelf=nil; self.peekingSelf=nil; self:Apply() end end)
end
FT:RegisterModule("BuffReminder",Reminder)
for key,name in pairs(pages) do
    if key~="self" then
        local page={Open=function(page) Reminder:ShowPage(key); page.frame=Reminder.frame end,Refresh=function() if Reminder.frame and Reminder.frame:IsShown() then Reminder:RefreshMenu() end end}
        -- Look and position: a change shows the sample notices a few seconds.
        if key=="look" then page.Peek=function() Reminder:PeekSelf() end end
        FT:RegisterModule(name,page)
    end
end
-- Talents changed: read the trees again on the next look.
local talentEvents=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_LEVEL_UP","PLAYER_SPECIALIZATION_CHANGED","TRAIT_CONFIG_UPDATED"}) do pcall(talentEvents.RegisterEvent,talentEvents,event) end
talentEvents:SetScript("OnEvent",function() Reminder.specCache=nil end)
-- Food in the bags is read again after the bags change (only when the food
-- reminders are on, and a moment after the last change).
local bagEvents=CreateFrame("Frame"); bagEvents:RegisterEvent("BAG_UPDATE_DELAYED")
bagEvents:SetScript("OnEvent",function()
    Reminder.foodKinds=nil
    if FT.dbReady then local s=Reminder:Settings(); if s.enabled and (s.food or s.foodStat) then FT:Coalesce("ftFoodBags",function() if Reminder.Refresh then Reminder:Refresh() end end,.5) end end
end)
-- Many events in the same moment lead to one check.
function Reminder:QueueApply(delay)
    if self.applyQueued then return end
    self.applyQueued=true
    C_Timer.After(delay or 0,function() self.applyQueued=false; if FT.dbReady then self:Apply() end end)
end
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED","UNIT_ENTERED_VEHICLE","UNIT_EXITED_VEHICLE","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","UNIT_AURA","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","UPDATE_SHAPESHIFT_FORM","UPDATE_SHAPESHIFT_FORMS","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_EQUIPMENT_CHANGED","UNIT_INVENTORY_CHANGED","WEAPON_ENCHANT_CHANGED","WEAPON_SLOT_CHANGED","UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED","PLAYER_LEVEL_UP","TRAINER_SHOW","TRAINER_UPDATE","PLAYER_UPDATE_RESTING"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,unit,castGUID,spellID)
    if not FT.dbReady then return end
    if event=="TRAINER_SHOW" or event=="TRAINER_UPDATE" then FT.BuffRanks:CaptureTrainer() end
    if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_SUCCEEDED" then
        if not safe(unit) or unit~="player" or not safe(spellID) then return end
        if event=="UNIT_SPELLCAST_START" then FT.BuffRanks:BeginCast(spellID);return end
        FT.BuffRanks:FinishCast(spellID)
        Reminder:NoteCast(spellID)
        if InCombatLockdown() then Reminder.pendingCombat=true; return end
        C_Timer.After(.6,function() if FT.dbReady then Reminder:Apply() end end)
        return
    end
    if event=="UNIT_AURA" and (not safe(unit) or type(unit)~="string" or (unit~="player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$"))) then return end
    -- Group members' auras only matter for the group notice.
    if event=="UNIT_AURA" and unit~="player" and not Reminder:Settings().groupEnabled then return end
    if event=="UNIT_AURA" and unit=="player" then
        local gone=Reminder:NoteRemoved(castGUID)
        if Reminder.debugUntil then Reminder:DebugAura(castGUID) end
        if gone and Reminder.badge and InCombatLockdown() then Reminder.notices=nil end
    end
    if event=="PLAYER_REGEN_DISABLED" then
        if Reminder.badge and Reminder:CombatAny() then
            -- Buffs that also remind in a fight start a fresh timer at the pull.
            -- The game only counts the fight as started after this event, so
            -- say so for this one look.
            Reminder.fighting=true
            Reminder.notices=nil; Reminder:Refresh(Reminder.learnedCache)
            Reminder.fighting=nil
        else
            if Reminder.badge then Reminder.badge:Hide();Reminder.groupBadge:Hide() end;Reminder:HideCustom()
        end
        return
    end
    -- Notices are paused in combat, so skip the work and check once afterwards.
    -- Only buffs that also remind in a fight are looked at, on your own changes.
    if InCombatLockdown() and event~="PLAYER_REGEN_ENABLED" then
        Reminder.pendingCombat=true
        if Reminder.badge and (event=="UNIT_AURA" or event=="UPDATE_SHAPESHIFT_FORM" or event=="WEAPON_ENCHANT_CHANGED") and Reminder:CombatAny() then
            FT:Coalesce("reminderCombat",function() Reminder:Refresh(Reminder.learnedCache) end,.25)
        end
        return
    end
    -- Aura changes come in bursts (many per second in a raid): check at most
    -- four times a second. Other events are handled on the next frame.
    Reminder:QueueApply(event=="UNIT_AURA" and .25 or 0)
    if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(1.5,function() if FT.dbReady then Reminder:Apply() end end)
    end
end)
local refreshElapsed=0
events:SetScript("OnUpdate",function(_,dt)
    refreshElapsed=refreshElapsed+dt
    if refreshElapsed<1 then return end
    refreshElapsed=0
    if FT.dbReady and Reminder.badge and Reminder:Settings().enabled and (not InCombatLockdown() or Reminder:CombatAny()) then
        Reminder:Refresh(Reminder.learnedCache)
    end
end)
