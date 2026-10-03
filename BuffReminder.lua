local _,FT=...
local Reminder={missing={},elapsed=0,cycle=1}
local choices={
    Druid={{"Mark of the Wild",true,"wild"},{"Gift of the Wild",false,"wild"},{"Thorns",false}},
    Hunter={{"Aspect of the Hawk",true}},
    Mage={{"Arcane Intellect",true,"intellect"},{"Arcane Brilliance",false,"intellect"},{"Ice Armor",false,"armor"},{"Mage Armor",false,"armor"}},
    Paladin={{"Blessing of Might",true,"blessing"},{"Blessing of Wisdom",false,"blessing"},{"Blessing of Kings",false,"blessing"},{"Blessing of Salvation",false,"blessing"},{"Blessing of Light",false,"blessing"},{"Blessing of Sanctuary",false,"blessing"},{"Righteous Fury",true,"protection"}},
    Priest={{"Power Word: Fortitude",true,"fortitude"},{"Prayer of Fortitude",false,"fortitude"},{"Inner Fire",false},{"Shadow Protection",false}},
    Shaman={{"Lightning Shield",true},{"Water Shield",false}},
    Warlock={{"Demon Armor",true,"armor"},{"Demon Skin",false,"armor"}},
    Warrior={{"Battle Shout",true}},
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
function Reminder:Settings()
    if type(FT.db.buffReminder)~="table" then FT.db.buffReminder={} end
    local s=FT.db.buffReminder
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
    for field,defaults in pairs({selfWhere={world=true,city=true,dungeon=true,raid=true,pvp=true},groupWhere={world=false,city=false,dungeon=true,raid=true,pvp=true}}) do
        if type(s[field])~="table" then s[field]={} end
        for key,on in pairs(defaults) do if type(s[field][key])~="boolean" then s[field][key]=on end end
    end
    if type(s.selected)~="table" then s.selected={} end
    if type(s.specSelected)~="table" then s.specSelected={} end
    -- Buffs with a look of their own: [buff name or "weapon:main"/"weapon:off"]={mode=,size=,...}
    if type(s.styles)~="table" then s.styles={} end
    -- Buffs that also remind during a fight: [buff name or "weapon:main"/"weapon:off"]=true
    if type(s.combat)~="table" then s.combat={} end
    -- Food buff reminder: off by default; "leveling" stops at max level.
    if type(s.food)~="boolean" then s.food=false end
    if s.foodWhen~="always" then s.foodWhen="leveling" end
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
-- Is the food reminder wanted right now? (Whether the buff is there is checked by the caller.)
function Reminder:FoodWanted()
    local s=self:Settings()
    return s.food==true and (s.foodWhen=="always" or self:Leveling())
end
function Reminder:Class()
    local _,class=UnitClass("player")
    return safe(class) and type(class)=="string" and class:sub(1,1)..class:sub(2):lower() or ""
end
function Reminder:TalentSpecs()
    local result={}
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
            if ok and safe(liveName) and liveName==name and safe(points) and type(points)=="number" then
                byName[name]={name=name,icon=safe(icon) and icon or nil,points=points}
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
        spec.icon=spec.icon or ("Interface\\Icons\\"..((treeIcons[self:Class()] or {})[i] or "INV_Misc_Book_09"))
    end
    return result
end
function Reminder:CurrentSpec()
    local best,dominant=0,nil
    for _,spec in ipairs(self:TalentSpecs()) do
        if spec.points>best then best,dominant=spec.points,spec.name end
    end
    if dominant then return dominant end
    local active=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local info=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    if type(active)=="function" and type(info)=="function" then
        local ok,index=pcall(active)
        if ok and safe(index) and type(index)=="number" and index>0 then
            local found,_,name=pcall(info,index)
            if found and safe(name) and type(name)=="string" then
                for _,tree in ipairs(fallbackTrees[self:Class()] or {}) do if name==tree then return name end end
            end
        end
    end
    -- No talent points yet (low level): use the tree the player picked.
    local chosen=self:Settings().chosenSpec
    chosen=type(chosen)=="table" and chosen[self:Class()]
    for _,tree in ipairs(fallbackTrees[self:Class()] or {}) do if chosen==tree then return chosen end end
    return "Unassigned"
end
function Reminder:SpecChoices()
    local result={}
    for _,spec in ipairs(self:TalentSpecs()) do result[#result+1]={value=spec.name,label=spec.name,icon=spec.icon} end
    if #result==0 then result[1]={value="Unassigned",label="Unassigned"} end
    return result
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
        if spell and (entry[3]~="protection" or spec=="Protection") then
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
Reminder.places={{"world","Open world","Outside dungeons, raids and battlegrounds, away from cities and inns."},{"city","Cities","In cities and inns (while resting)."},{"dungeon","Dungeons","Inside five-player dungeons."},{"raid","Raids","Inside raids."},{"pvp","PvP","In battlegrounds and arenas."}}
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
local DEFAULT_DURATION={["Battle Shout"]=120}
Reminder.seen={}
function Reminder:Fighting() return self.fighting==true or InCombatLockdown() end
function Reminder:CombatAny()
    local s=self:Settings()
    return s.enabled and next(s.combat)~=nil
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
    local expires=self.seen[entry.name]
    return expires~=nil and (GetTime and GetTime() or 0)>=expires
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
    for key in pairs(s.combat) do
        local same=key==name
        if not same and group and group~="protection" then
            for _,entry in ipairs(list) do if entry[1]==key and entry[3]==group then same=true end end
        end
        if same then self.seen[key]=now+self:Duration(name); changed=true end
    end
    if changed and self:Fighting() then FT:Coalesce("reminderCombat",function() self:Refresh(self.learnedCache) end,.1) end
end
function Reminder:Suppressed(fightOK)
    if not fightOK and (self.fighting==true or InCombatLockdown()) then return true end
    for _,fn in ipairs({UnitOnTaxi or false,UnitIsDeadOrGhost or false,UnitInVehicle or false}) do
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
    if s.enabled then
        for _,entry in ipairs(selfHere and self:Available(learned) or {}) do
            local also=s.combat[entry.name]==true
            if (also or not fighting) and self:Enabled(entry,currentSpec,learned) then
                local missing
                if entry.group=="stance" then missing=self:StanceStatus()==false
                elseif also then missing=self:EntryMissing(entry,fighting)
                else missing=self:HasAura(entry.name)==false and self:FamilyPresent(entry.group)==false end
                if missing then self.missing[#self.missing+1]=entry; styleKeys[entry]=entry.name end
            end
        end
        if not fighting and s.groupEnabled and self:ShowsHere("groupWhere") then
            local units=self:GroupUnits()
            if #units>0 then
                for _,entry in ipairs(self:Available(learned)) do
                    local group=entry.group
                    if self:Enabled(entry,currentSpec,learned) and (group=="wild" or group=="blessing" or group=="intellect" or group=="fortitude") then
                        local missing=0
                        for _,unit in ipairs(units) do
                            if self:HasAura(entry.name,unit)==false and self:FamilyPresent(group,unit)==false then missing=missing+1 end
                        end
                        if missing>0 then
                            local family=({wild="Wild buff",blessing="Blessing",intellect="Intellect",fortitude="Fortitude"})[group] or "Group buff"
                            self.groupMissing[#self.groupMissing+1]={name=family.." missing — "..missing.." member"..(missing==1 and "" or "s"),spell=entry.spell}
                        end
                    end
                end
            end
        end
        if selfHere and not fighting and self:FoodWanted() then
            local name,icon=self:FoodInfo()
            if self:HasAura(name)==false then
                local food={name="Food buff",message="Food buff missing"..(self:Leveling() and " (+5% XP)" or ""),spell={icon=icon}}
                self.missing[#self.missing+1]=food; styleKeys[food]="food"
            end
        end
        if self:Class()=="Shaman" and selfHere then
            for _,slot in ipairs({"main","off"}) do
                local name=s[slot.."Enchant"]
                if slot=="main" and name==nil then
                    for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end
                end
                if name and learned[name] and (not fighting or s.combat["weapon:"..slot]==true) and self:WeaponMissing(slot) then
                    local hand=slot=="main" and "main hand" or "off hand"
                    local weapon={name="Weapon buff ("..hand..")",message="Weapon buff missing ("..hand..")",spell=learned[name]}
                    self.missing[#self.missing+1]=weapon; styleKeys[weapon]="weapon:"..slot
                end
            end
        end
        if selfHere and not fighting then for _,warning in ipairs(FT.BuffRanks:Warnings(learned,s)) do self.missing[#self.missing+1]=warning end end
        if not fighting then FT.BuffRanks:ObserveWeapons() end
    end
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
        group.icon=group:CreateTexture(nil,"ARTWORK");group.icon:SetSize(20,20);group.icon:SetPoint("LEFT",8,0);group.icon:SetTexCoord(.08,.92,.08,.92);FT:RoundIcon(group.icon)
        group.text=FT:Label(group,"",13);group.text:SetPoint("LEFT",group.icon,"RIGHT",8,0);group.text:SetWidth(242)
        group:RegisterForClicks("LeftButtonUp","RightButtonUp")
        group:SetScript("OnClick",function(_,button) self:ClickNotice("group",button) end)
        group:RegisterForDrag("LeftButton");group:SetScript("OnDragStart",function(owner) self:DragStart(owner) end)
        group:SetScript("OnDragStop",function() self:DragUpdate();self.dragging=false end)
        FT:Tooltip(group,"Group buffs",function() return self:HideHint() end)
    end
    self:Refresh()
end
-- Per-buff notice styles ---------------------------------------------------
-- A buff can leave the shared notice and get one of its own: a bar (the
-- usual look), an icon with text, or just an icon, with its own size, color,
-- outline, transparency and place on screen. Like every notice, these show
-- out of combat unless the buff has "Also remind in combat" on.
local styleModes={bar=true,both=true,icon=true}
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
        if self:Class()~="Shaman" then return nil end
        local name=self:Settings()[slot.."Enchant"]
        if not name or name=="" then for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate; break end end end
        return "Weapon buff ("..(slot=="main" and "main hand" or "off hand")..")",name and learned[name] and learned[name].icon or "Interface\\Icons\\Spell_Nature_RockBiter"
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
    if st.mode=="icon" then
        notice:SetSize(40,40); icon:SetSize(40,40); icon:SetPoint("CENTER")
        text:Hide()
    elseif st.mode=="both" then
        notice:SetSize(264,36); icon:SetSize(36,36); icon:SetPoint("LEFT",0,0)
        text:SetPoint("LEFT",icon,"RIGHT",8,0); text:SetWidth(220); text:Show()
    else
        notice:SetSize(285,34); icon:SetSize(20,20); icon:SetPoint("LEFT",8,0)
        text:SetPoint("LEFT",icon,"RIGHT",8,0); text:SetWidth(242); text:Show()
    end
    notice.bar:SetShown(st.mode=="bar")
    local font=text:GetFont()
    local size=st.mode=="both" and 15 or 13
    local okFont=text:SetFont(font or FT.bodyFont,size,st.outline)
    if okFont==false or not text:GetFont() then text:SetFont("Fonts\\FRIZQT__.TTF",size,st.outline) end
    text:SetTextColor(st.color[1],st.color[2],st.color[3])
    notice.border:SetVertexColor(st.borderColor[1],st.borderColor[2],st.borderColor[3],1); notice.border:SetShown(st.border)
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
            else local name,sample=self:StyleInfo(key); message=(name or key).." missing"; icon=sample end
            notice.message=message
            notice.icon:SetTexture(icon or 134400)
            if notice.shownText~=message then notice.shownText=message; notice.text:SetText(message) end
            if notice.styleRef~=st or notice.styleStamp~=self.styleStamp then
                notice.styleRef=st; notice.styleStamp=self.styleStamp; self:LayoutCustom(notice,st)
            end
            local height=(st.mode=="icon" and 40 or st.mode=="both" and 36 or 34)*st.size
            if st.x and st.y then self:PlaceCustom(notice,st)
            else self:PlaceCustom(notice,st,baseX,top-used-height/2); used=used+height+8 end
            notice:Show()
        end
    end
end
-- The small panel beside the page where one buff's look is set.
local modeChoices={{"default","Default (shared notice)","Default"},{"bar","Bar"},{"both","Icon and text"},{"icon","Icon only"}}
function Reminder:OpenStyle(key,title)
    if not self.frame then return end
    if not self.stylePanel then
        local frame=self.frame
        local panel=CreateFrame("Frame",nil,frame); self.stylePanel=panel
        panel:SetSize(300,474); panel:SetFrameStrata("DIALOG"); panel:SetFrameLevel(frame:GetFrameLevel()+20); panel:SetClampedToScreen(true)
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
            end
            self:StyleChanged()
        end,"skins")
        panel.mode:SetPoint("TOPLEFT",16,-78); panel.mode.menuWidth=268
        if panel.mode.label.SetWordWrap then panel.mode.label:SetWordWrap(false) end
        FT:Tooltip(panel.mode,"Look","Default keeps this buff in the shared notice. Bar is the same look as a notice of its own. Icon and text, or Icon only, show the buff's icon without the bar.")
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
        FT:Tooltip(panel.outline,"Text outline","A dark edge around the text, so it stays readable over bright ground.")
        panel.border=FT:QuietButton(panel,"",130,30); panel.border:SetPoint("TOPLEFT",16,-320)
        panel.border:SetScript("OnClick",function() change(function(st) st.border=not st.border end) end)
        FT:Tooltip(panel.border,"Icon border","A thin rounded border around the icon.")
        panel.borderColor=colorButton("Border",320,154,130,"borderColor","The color of the icon's border.")
        panel.pulse=FT:QuietButton(panel,"",130,30); panel.pulse:SetPoint("TOPLEFT",16,-356)
        panel.pulse:SetScript("OnClick",function() change(function(st) st.pulse=not st.pulse end) end)
        FT:Tooltip(panel.pulse,"Gentle pulse","Let the notice slowly fade down and back so it catches the eye.")
        panel.reset=FT:QuietButton(panel,"Reset position",130,30); panel.reset:SetPoint("TOPLEFT",154,-356)
        panel.reset:SetScript("OnClick",function() change(function(st) st.x,st.y,st.screenWidth,st.screenHeight=nil,nil,nil,nil end) end)
        FT:Tooltip(panel.reset,"Reset position","Forget where you dragged this notice: it goes back to the shared notice's spot (below the shared notices when they are showing).")
        for _,b in ipairs({panel.border,panel.pulse,panel.reset}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        -- Not part of the look: works with the shared notice too.
        panel.combat=FT:QuietButton(panel,"",268,30,"Ability_Warrior_BattleShout"); panel.combat:SetPoint("TOPLEFT",16,-394)
        if panel.combat.label.SetWordWrap then panel.combat.label:SetWordWrap(false) end
        panel.combat:SetScript("OnClick",function()
            local key=self.styleKey; if not key then return end
            local combat=self:Settings().combat
            combat[key]=not combat[key] and true or nil
            self:RefreshStyle(); self:Refresh(self.learnedCache)
        end)
        FT:Tooltip(panel.combat,"Also remind in combat","Notices normally hide while you fight. On: this buff's notice also shows during a fight, for buffs you can only or mostly cast in combat, like Battle Shout. In a fight the game can hide your buffs; then ForeverTools goes by when it saw you cast the buff and how long it lasts, so a buff that is removed early can be missed until the fight ends.")
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
    panel.hint:SetText(st and "This buff has a notice of its own. The sample is on screen now: drag it to place it." or "This buff uses the shared notice, shown now as a sample.")
    local also=self:Settings().combat[self.styleKey]==true
    panel.combat.label:SetText("Also remind in combat: "..(also and "On" or "Off")); FT:SetSelected(panel.combat,also)
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
    panel.note:SetText(st and (st.mode=="icon" and "Icon only: hover it to read which buff is missing." or "") or "Pick a look above to give this buff a notice of its own.")
end
local kindOrder={"group","blessing","aura","armor","self"}
local kindLabels={group="Group buffs",blessing="Blessings",aura="Auras & stances",armor="Armor",self="Self buffs"}
local kindIcons={group="Spell_Holy_PrayerOfFortitude",blessing="Spell_Holy_FistOfJustice",aura="Spell_Holy_DevotionAura",armor="Spell_Frost_FrostArmor02",self="Spell_Holy_WordFortitude"}
local function kindOf(entry)
    local g=entry.group
    if g=="wild" or g=="fortitude" or g=="intellect" then return "group" end
    if g=="blessing" then return "blessing" end
    if g=="stance" or g=="protection" then return "aura" end
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
    self.moveButton.label:SetText(self.moving and "Lock" or "Move")
    FT:SetSelected(self.moveButton,self.moving)
    FT:SetSelected(self.selfPreview,self.previewSelf)
    FT:SetSelected(self.groupPreview,self.previewGroup)
    self.sizeValue:SetText("Size: "..math.floor(s.size*100+.5).."%")
    self.settingSize=true;self.sizeSlider:SetValue(s.size);self.settingSize=false
    self.hideChoice.value=s.hideAfter;self.hideChoice.label:SetText(self:HideAfterText())
    self.colorSwatch:SetVertexColor(unpack(s.textColor))
    self.groupColorSwatch:SetVertexColor(unpack(s.groupTextColor))
    local editSpec=self.editSpec
    if not editSpec or editSpec=="Unassigned" then editSpec=self:CurrentSpec() end
    self.specChoice.value=editSpec;self.specChoice.label:SetText("Assign buffs for: "..editSpec)
    local specs=self:SpecChoices()
    local icon=specs[1] and specs[1].icon or "Interface\\Icons\\INV_Misc_Book_09"
    for _,spec in ipairs(specs) do if spec.value==editSpec then icon=spec.icon;break end end
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
    local weapon=self:Class()=="Shaman"
    for _,slot in ipairs({"main","off"}) do
        local dropdown=self[slot.."Dropdown"]
        if weapon then
            local name=s[slot.."Enchant"]
            if slot=="main" and name==nil then for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end end
            dropdown.value=name or "";dropdown.label:SetText((slot=="main" and "Main hand: " or "Off hand: ")..(name or "Off"))
            FT:SetSelected(dropdown.gear,self:Style("weapon:"..slot)~=nil)
            if name and name~="" then watched=watched+1 end
        end
    end
    local _,foodIcon=self:FoodInfo()
    self.foodToggle.label:SetText("Food buff: "..(s.food and "On" or "Off")); FT:SetSelected(self.foodToggle,s.food)
    self.foodToggle.icon:SetTexture(foodIcon)
    FT:SetSelected(self.foodToggle.gear,self:Style("food")~=nil)
    self.foodWhen.label:SetText(s.foodWhen=="always" and "Remind: Always" or "Remind: While leveling")
    self.foodWhen:SetAlpha(s.food and 1 or .5)
    if s.food then watched=watched+1 end
    -- Left: one row per section with its state. Right: only the chosen section.
    local cd=FT.modules.CooldownReminder
    local hide=s.hideAfter
    local status={
        self=(s.enabled and "On" or "Off").." · "..watched.." watched for "..editSpec,
        group=s.groupEnabled and "On" or "Off",
        rank="Alerts "..(s.lowRank and "on" or "off").." · bar marker "..(s.rankMarker and "on" or "off"),
        look=math.floor(s.size*100+.5).."% · "..(hide==0 and "never hides" or "hides after "..(hide>=60 and (hide/60).." min" or hide.." s")),
        cooldown=(cd and cd:Settings().enabled and "On" or "Off").." · opens its own page",
    }
    local pane=self.pane or "self"
    for key,button in pairs(self.paneButtons) do button.meta:SetText(status[key] or ""); FT:SetSelected(button,key==pane) end
    for _,control in ipairs(self.paneControls) do control:Hide() end
    for _,h in ipairs(self.kindHeads) do h:Hide() end
    local info=self.paneInfo[pane]
    self.paneTitle.ftHeading.icon=info.icon; self.paneTitle:SetText(info.title); self.paneTitle:Show()
    self.paneHint:SetText(info.hint); self.paneHint:Show()
    local X,TOP,W=290,132,442
    local function place(control,x,top) control:ClearAllPoints();control:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top);control:Show() end
    place(self.paneTitle,X,TOP+14); place(self.paneHint,X,TOP+40)
    local y=TOP+68
    if pane=="self" then
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
                for n=0,count-1 do place(self.rows[first+n],X+(n%2)*227,y+math.floor(n/2)*38) end
                y=y+math.ceil(count/2)*38+6
            end
        end
        if #available==0 and not weapon then place(self.empty,X,y+4); y=y+30 end
        if weapon then
            headUsed=headUsed+1
            local h=self.kindHeads[headUsed]; h.ftHeading.icon="INV_Sword_04"; h:SetText("Weapon buffs"); place(h,X,y); y=y+18
            place(self.mainDropdown,X,y);place(self.offDropdown,X,y+38)
            place(self.mainDropdown.gear,X+414,y);place(self.offDropdown.gear,X+414,y+38);y=y+80
        end
        headUsed=headUsed+1
        local fh=self.kindHeads[headUsed]; fh.ftHeading.icon=nil; fh:SetText("Food"); place(fh,X,y); y=y+18
        place(self.foodToggle,X,y); place(self.foodWhen,X+227,y); y=y+44
        headUsed=headUsed+1
        local h=self.kindHeads[headUsed]; h.ftHeading.icon=nil; h:SetText("Show in"); place(h,X,y); y=y+18
        self:PlaceWhere("selfWhere",X,y);y=y+40
        place(self.selfColorButton,X,y);y=y+34
    elseif pane=="group" then
        local h=self.kindHeads[1]; h.ftHeading.icon=nil; h:SetText("Show in"); place(h,X,y); y=y+18
        self:PlaceWhere("groupWhere",X,y);y=y+40
        place(self.groupColorButton,X,y);y=y+40
        place(self.groupPreview,X,y);y=y+32
    elseif pane=="rank" then
        place(self.rankToggle,X,y);place(self.rankOneToggle,X+227,y);y=y+38
        place(self.markerToggle,X,y);place(self.exceptions,X+227,y);y=y+32
    elseif pane=="look" then
        place(self.sizeValue,X,y+3);place(self.sizeSlider,X+124,y);y=y+36
        place(self.hideChoice,X,y);y=y+40
        place(self.resetPosition,X,y);y=y+30
    end
    -- One size for every section (room for the longest buff list), so the
    -- window never grows or shrinks as you click around.
    local bottom=math.max(TOP+478,y+14)
    if self.paneBottom~=bottom then
        self.paneBottom=bottom
        self.detail:SetHeight(bottom-TOP)
        self.frame:SetHeight(bottom+24)
    end
end
function Reminder:PlaceWhere(field,x0,top)
    local x=x0
    for _,place in ipairs(self.places) do
        local b=self.whereRows[field].buttons[place[1]]
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top); b:Show(); x=x+90
    end
end
function Reminder:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsBuffReminders","Buff reminders",772,634);self.frame=frame
        -- Top row: the switches and tools you reach for most.
        local top=CreateFrame("Frame",nil,frame); top:SetSize(724,58); top:SetPoint("TOPLEFT",24,-62); FT:Panel(top); self.topBar=top
        -- Right side: the chosen section's options.
        local detail=CreateFrame("Frame",nil,frame); detail:SetSize(474,478); detail:SetPoint("TOPLEFT",274,-132); FT:Panel(detail); self.detail=detail
        self.paneControls={}
        local function pane(control) self.paneControls[#self.paneControls+1]=control; return control end
        self.paneInfo={
            self={title="Your buffs",icon="Spell_Holy_WordFortitude",hint="Pick buffs for each talent tree. The gear: own look, and reminders in combat."},
            group={title="Group buffs",icon="Spell_Holy_PrayerOfFortitude",hint="A notice when group members are missing your group buffs."},
            rank={title="Low ranks",icon="INV_Misc_Book_07",hint="Catch spells cast at a lower rank than you know."},
            look={title="Look and position",icon="Ability_Rogue_Sprint",hint="Size and timing. Preview and Move are in the top row."},
        }
        self.paneTitle=FT:Label(detail,"",16,true); self.paneTitle:SetTextColor(1,.82,0); FT:SectionHeading(self.paneTitle,"Spell_Holy_WordFortitude",260)
        self.paneHint=FT:Label(detail,"",12); self.paneHint:SetTextColor(.66,.59,.48); self.paneHint:SetWidth(442); self.paneHint:SetJustifyH("LEFT")
        if self.paneHint.SetWordWrap then self.paneHint:SetWordWrap(false) end
        -- Left side: the sections, each with its current state.
        self.paneButtons={}
        for i,entry in ipairs({{"self","Your buffs","Spell_Holy_WordFortitude"},{"group","Group buffs","Spell_Holy_PrayerOfFortitude"},{"rank","Low ranks","INV_Misc_Book_07"},{"look","Look and position","Ability_Rogue_Sprint"},{"cooldown","Cooldown reminders","Spell_Nature_TimeStop"}}) do
            local key=entry[1]
            local b=FT:QuietButton(frame,"",236,48); b.label:Hide()
            b:SetPoint("TOPLEFT",24,-132-(i-1)*52)
            b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(28,28); b.icon:SetPoint("LEFT",10,0); b.icon:SetTexture("Interface\\Icons\\"..entry[3]); b.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(b.icon)
            b.title=FT:Label(b,entry[2],14); b.title:SetPoint("TOPLEFT",48,-8)
            b.meta=FT:Label(b,"",11); b.meta:SetPoint("TOPLEFT",48,-27); b.meta:SetWidth(180); b.meta:SetJustifyH("LEFT"); b.meta:SetTextColor(.72,.66,.55)
            if b.meta.SetWordWrap then b.meta:SetWordWrap(false) end
            b:SetScript("OnClick",function()
                if key=="cooldown" then FT:OpenModule("CooldownReminder"); return end
                self.pane=key; self:RefreshMenu()
            end)
            FT:Tooltip(b,entry[2],key=="cooldown" and "A short notice to use a ready racial, trinket or long cooldown on tough targets and big pulls. Off by default. Click to open its settings page."
                or self.paneInfo[key].hint.." Click to show these options on the right.")
            self.paneButtons[key]=b
        end
        self.toggle=FT:AccentButton(top,"",196,34,"buffs");self.toggle:SetPoint("LEFT",14,0)
        self.toggle:SetScript("OnClick",function() local s=self:Settings();s.enabled=not s.enabled;self:Apply() end)
        FT:Tooltip(self.toggle,"Self-buff reminders","Shows a small notice at the top of the screen when one of your buffs is missing. Hidden in combat, on flights and while dead. It never casts anything for you.")
        self.groupToggle=FT:QuietButton(top,"",196,34,"party");self.groupToggle:SetPoint("LEFT",self.toggle,"RIGHT",8,0)
        self.groupToggle:SetScript("OnClick",function() local s=self:Settings();s.groupEnabled=not s.groupEnabled;self:Apply() end)
        FT:Tooltip(self.groupToggle,"Group reminders","Shows a notice when someone in your group is missing one of your group buffs. Choose where it shows under Group buffs. Hidden in combat.")
        self.moveButton=FT:QuietButton(top,"",100,34,"move");self.moveButton:SetPoint("RIGHT",-14,0)
        self.moveButton:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.moveButton,"Move reminders","Click to unlock, drag the notice where you want it, then click again to lock it.")
        self.selfPreview=FT:QuietButton(top,"Preview",112,34,"buffs");self.selfPreview:SetPoint("RIGHT",self.moveButton,"LEFT",-8,0)
        self.selfPreview:SetScript("OnClick",function() self.previewSelf=not self.previewSelf;FT:SetSelected(self.selfPreview,self.previewSelf);self:Apply() end)
        FT:Tooltip(self.selfPreview,"Preview self reminders","Show sample notices so you can see how they look: the shared notice, and one for each buff you gave a look of its own. The group notice has its own preview under Group buffs.")
        for _,b in ipairs({self.toggle,self.groupToggle,self.moveButton,self.selfPreview}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        self.specChoice=pane(FT:Dropdown(detail,442,function() return self:SpecChoices() end,function(value)
            self.editSpec=value
            -- Before any talent points are spent, the picked tree becomes your tree.
            local spent=0; for _,spec in ipairs(self:TalentSpecs()) do spent=spent+spec.points end
            if spent==0 then local s=self:Settings(); s.chosenSpec=type(s.chosenSpec)=="table" and s.chosenSpec or {}; s.chosenSpec[self:Class()]=value; self:Apply() end
            self:RefreshMenu()
        end,"classes"))
        self.specChoice.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        FT:Tooltip(self.specChoice,"Buffs for each talent tree","Pick which buffs to watch for each talent tree. The addon follows the tree you have spent the most points in. Before you have talent points, the tree you pick here is used.")
        self.rows={}
        self.kindHeads={}
        for i=1,8 do
            local h=FT:Label(detail,"",12,true); h:SetTextColor(.66,.59,.48); FT:SectionHeading(h,nil,260,14); h:Hide(); self.kindHeads[i]=h
        end
        for i=1,12 do
            local b=pane(FT:QuietButton(detail,"",215,32,"welcome"))
            b.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end
            b.label:ClearAllPoints(); b.label:SetPoint("LEFT",b.icon,"RIGHT",8,0); b.label:SetPoint("RIGHT",b,"RIGHT",-32,0)
            -- The gear gives this buff a notice look of its own.
            b.gear=FT:QuietButton(b,"",24,24); b.gear:SetPoint("RIGHT",-4,0); FT:GearIcon(b.gear)
            b.gear:SetScript("OnClick",function() if b.entry then self:OpenStyle(b.entry.name,b.entry.name) end end)
            FT:Tooltip(b.gear,"Notice look","Give this buff a notice of its own: a bar, an icon with text or just an icon, with its own size, color and place on screen. Lit when it has one. Also where you make this buff remind you during a fight.")
            b:SetScript("OnClick",function()
                local entry=b.entry;if not entry then return end
                local spec=self.editSpec or self:CurrentSpec();local selection=self:Selection(spec)
                local on=self:Enabled(entry,spec,self:Learned())
                selection[entry.name]=not on
                if not on and entry.group and entry.group~="protection" then
                    for _,other in ipairs(choices[self:Class()] or {}) do if other[3]==entry.group and other[1]~=entry.name then selection[other[1]]=false end end
                end
                self:Apply()
            end)
            FT:Tooltip(b,"Choose a self buff","Click to watch this buff. Only spells you have learned are listed. Buffs that can't be active together, like two auras, turn each other off.")
            self.rows[i]=b
        end
        self.empty=pane(FT:Label(detail,"No supported self buffs learned yet.",13))
        -- Food buff: the same for every class and talent tree.
        local food=pane(FT:QuietButton(detail,"",215,32,"welcome")); self.foodToggle=food
        food.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if food.label.SetWordWrap then food.label:SetWordWrap(false) end
        food.label:ClearAllPoints(); food.label:SetPoint("LEFT",food.icon,"RIGHT",8,0); food.label:SetPoint("RIGHT",food,"RIGHT",-32,0)
        food:SetScript("OnClick",function() local s=self:Settings(); s.food=not s.food; self:Apply() end)
        FT:Tooltip(food,"Food buff reminder","A notice when you don't have a food buff (Well Fed). In WoW: Forever, Well Fed also gives 5% more experience from kills. It follows the same rules as your other buff notices.")
        food.gear=FT:QuietButton(food,"",24,24); food.gear:SetPoint("RIGHT",-4,0); FT:GearIcon(food.gear)
        food.gear:SetScript("OnClick",function() self:OpenStyle("food","Food buff") end)
        FT:Tooltip(food.gear,"Notice look","Give the food reminder a notice of its own: a bar, an icon with text or just an icon, with its own size, color and place on screen. Lit when it has one.")
        self.foodWhen=pane(FT:QuietButton(detail,"",215,32,"reset"))
        self.foodWhen.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if self.foodWhen.label.SetWordWrap then self.foodWhen.label:SetWordWrap(false) end
        self.foodWhen:SetScript("OnClick",function() local s=self:Settings(); s.foodWhen=s.foodWhen=="always" and "leveling" or "always"; self:Apply() end)
        FT:Tooltip(self.foodWhen,"When to remind","While leveling: the food reminder stops by itself at max level, where the extra kill experience no longer matters. Always: it keeps reminding at max level too. Click to switch.")
        for _,slot in ipairs({"main","off"}) do
            local dropdown=pane(FT:Dropdown(detail,410,function()
                local list={{value="",label="Off"}};local learned=self:Learned()
                for _,name in ipairs(enchants) do if learned[name] then list[#list+1]={value=name,label=name,icon=learned[name].icon} end end
                return list
            end,function(value) self:Settings()[slot.."Enchant"]=value;self:Apply() end,"welcome"))
            self[slot.."Dropdown"]=dropdown
            dropdown.gear=pane(FT:QuietButton(detail,"",28,28)); FT:GearIcon(dropdown.gear)
            dropdown.gear:SetScript("OnClick",function() self:OpenStyle("weapon:"..slot,slot=="main" and "Main-hand weapon buff" or "Off-hand weapon buff") end)
            FT:Tooltip(dropdown.gear,"Notice look","Give this weapon buff a notice of its own: a bar, an icon with text or just an icon, with its own size, color and place on screen. Lit when it has one.")
            FT:Tooltip(dropdown,"Weapon enchant reminder","Pick the weapon buff to watch for this hand. Any weapon buff counts. Empty hands and shields are ignored.")
        end
        -- "Show in" rows: pick every place a notice may appear (multiple choice).
        self.whereRows={}
        for _,field in ipairs({"selfWhere","groupWhere"}) do
            local row={buttons={}}
            for _,place in ipairs(self.places) do
                local key=place[1]
                local b=pane(FT:QuietButton(detail,place[2],82,30))
                b.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end
                b:SetScript("OnClick",function() local s=self:Settings(); s[field][key]=not s[field][key]; self:Apply() end)
                FT:Tooltip(b,place[2],(field=="selfWhere" and "Show self-buff notices here. " or "Show group-buff notices here (only while in a group). ")..place[3].." Pick as many places as you like.")
                row.buttons[key]=b
            end
            self.whereRows[field]=row
        end
        self.sizeValue=pane(FT:Label(detail,"",14));self.sizeValue:SetWidth(120);self.sizeValue:SetJustifyH("LEFT")
        self.sizeSlider=pane(CreateFrame("Slider",nil,detail,"OptionsSliderTemplate"));self.sizeSlider:SetSize(318,18)
        self.sizeSlider:SetMinMaxValues(.7,1.5);self.sizeSlider:SetValueStep(.05);self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,value)
            if self.settingSize then return end
            self:Settings().size=math.floor(value*20+.5)/20;FT:Coalesce("reminderSlider",function() self:Apply() end,.05)
        end)
        FT:Tooltip(self.sizeSlider,"Reminder size","Make the notices smaller or bigger (70% to 150%).")
        self.hideChoice=pane(FT:Dropdown(detail,442,function()
            local list={};for _,c in ipairs(hideChoices) do list[#list+1]={value=c[1],label=c[2],icon="Interface\\Icons\\INV_Misc_PocketWatch_01"} end;return list
        end,function(value) self:Settings().hideAfter=value;self.notices=nil;self:Apply() end,"fps"))
        self.hideChoice:SetHeight(32); self.hideChoice.menuWidth=442
        FT:Tooltip(self.hideChoice,"Hide notice after","How long a notice stays before it hides by itself. It shows again when another buff goes missing. Never: it stays until the buff is back or you click it.")
        for _,entry in ipairs({{"textColor","Self text color"},{"groupTextColor","Group text color"}}) do
            local field,label=entry[1],entry[2]
            local color=pane(FT:QuietButton(detail,label,442,32,"fonts"))
            if field=="textColor" then self.selfColorButton=color else self.groupColorButton=color end
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
            FT:Tooltip(color,label,"Choose the text color for this reminder notice.")
        end
        self.rankToggle=pane(FT:QuietButton(detail,"",215,32,"INV_Misc_Book_07"))
        self.rankToggle:SetScript("OnClick",function() local s=self:Settings();s.lowRank=not s.lowRank;self:Apply() end)
        FT:Tooltip(self.rankToggle,"Low-rank alerts","Warns when you cast a buff at a lower rank than you know. Visit a trainer once so the addon knows which ranks you can learn.")
        self.rankOneToggle=pane(FT:QuietButton(detail,"",215,32,"INV_Misc_Book_11"))
        self.rankOneToggle:SetScript("OnClick",function() local s=self:Settings();s.ignoreRankOne=not s.ignoreRankOne;self:Apply() end)
        FT:Tooltip(self.rankOneToggle,"Ignore rank 1","Never warn about rank 1 spells, for example cheap heals you use on purpose.")
        self.markerToggle=pane(FT:QuietButton(detail,"",215,32,"INV_Misc_Note_02"))
        self.markerToggle:SetScript("OnClick",function() local s=self:Settings();s.rankMarker=not s.rankMarker;self:Apply() end)
        FT:Tooltip(self.markerToggle,"Low-rank marker on action bars","Adds a small amber corner to action buttons that use a lower rank than you know. Hover the button to see your best rank. Macros are not checked.")
        self.exceptions=pane(FT:Dropdown(detail,215,function() return FT.modules.RankMarker:ExceptionChoices() end,function(value) FT.modules.RankMarker:ToggleIgnore(value) end,"INV_Misc_Note_03"))
        self.exceptions:SetHeight(32); self.exceptions.menuWidth=340
        FT:Tooltip(self.exceptions,"Low-rank exceptions","Pick spells you downrank on purpose. They get no marker and no alert. Pick one again to take it off the list.")
        for _,b in ipairs({self.rankToggle,self.rankOneToggle,self.markerToggle,self.exceptions}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        local resetPosition=pane(FT:QuietButton(detail,"Reset reminder position",442,30,"reset"));self.resetPosition=resetPosition
        resetPosition:SetScript("OnClick",function()
            local s=self:Settings();s.x=nil;s.y=nil;s.screenWidth=nil;s.screenHeight=nil;self:Apply()
        end)
        FT:Tooltip(resetPosition,"Reset position","Move the notices back to the top center of the screen.")
        self.groupPreview=pane(FT:QuietButton(detail,"Preview group reminder",442,32,"party"))
        self.groupPreview:SetScript("OnClick",function() self.previewGroup=not self.previewGroup;FT:SetSelected(self.groupPreview,self.previewGroup);self:Apply() end)
        FT:Tooltip(self.groupPreview,"Preview group reminder","Show a sample group notice so you can see how it looks.")
        frame:HookScript("OnHide",function()
            self.previewSelf=nil;self.previewGroup=nil
            FT:SetSelected(self.selfPreview,false);FT:SetSelected(self.groupPreview,false)
            self:SetMoving(false)
        end)
        FT:PageInfo(frame,"Buff reminders","The top row turns self and group reminders on, previews a notice and lets you move it. Pick a section on the left (each shows its current state) and its options appear on the right: your buffs for each talent tree, group buffs, low ranks, and the look of the notices. Cooldown reminders open their own page.\n\nA small notice appears when a buff is missing. Notices hide in combat, on flights and while dead. Left-click a notice to dismiss it, right-click it for settings.")
    end
    self.editSpec=self:CurrentSpec()
    self:Apply();self.frame:Show()
end
FT:RegisterModule("BuffReminder",Reminder)
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
