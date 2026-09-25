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
    return s
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
                if ok and safe(name) and type(name)=="string" and name==names[i] then
                    result[#result+1]={name=name,icon=safe(icon) and icon or nil,points=safe(points) and type(points)=="number" and points or 0}
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
    local best,name=0,"Unassigned"
    for _,spec in ipairs(self:TalentSpecs()) do
        if spec.points>best then best,name=spec.points,spec.name end
    end
    return name
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
        if ok and type(spells)=="table" then
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
        badge:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y-(badge==self.groupBadge and (self.badge:IsShown() and 42*s.size or 0) or 0))
        badge.text:SetTextColor(unpack(badge==self.groupBadge and s.groupTextColor or s.textColor))
    end
end
function Reminder:DragStart(badge)
    if not self.moving then return end
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    local cx,cy=badge:GetCenter();if not cx then return end
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
-- Polling the same missing buffs must not restart a dismissed notice.
function Reminder:NoticeVisible(key,entries)
    self.notices=self.notices or {}
    local names={}
    for _,entry in ipairs(entries) do names[#names+1]=entry.message or entry.name end
    table.sort(names)
    local signature=table.concat(names,"\n")
    local notice=self.notices[key]
    local now=GetTime and GetTime() or 0
    if not notice or notice.signature~=signature then
        notice={signature=signature,expires=now+30};self.notices[key]=notice
    end
    return #entries>0 and not notice.dismissed and now<notice.expires
end
function Reminder:ClickNotice(key,button)
    if button=="RightButton" then
        if not InCombatLockdown() then FT:OpenModule("BuffReminder") end
    elseif not self.moving then
        if key=="self" then self.previewSelf=nil else self.previewGroup=nil end
        if self.notices and self.notices[key] then self.notices[key].dismissed=true end
        self:Refresh(self.learnedCache)
    end
end
function Reminder:Suppressed()
    if InCombatLockdown() then return true end
    for _,fn in ipairs({UnitOnTaxi or false,UnitIsDeadOrGhost or false,UnitInVehicle or false}) do
        if fn then local ok,value=pcall(fn,"player");if ok and safe(value) and value then return true end end
    end
    if IsPlayerInWorld then local ok,value=pcall(IsPlayerInWorld);if ok and safe(value) and not value then return true end end
    return false
end
function Reminder:Refresh(cachedSpells)
    local s=self:Settings()
    if self:Suppressed() then
        self.missing={}
        if self.badge then self.badge:Hide();self.groupBadge:Hide() end
        return
    end
    local learned=cachedSpells or self:Learned()
    self.learnedCache=learned
    local currentSpec=self:CurrentSpec()
    self.missing={}
    self.groupMissing={}
    local selfHere=self:ShowsHere("selfWhere")
    if s.enabled and not InCombatLockdown() then
        for _,entry in ipairs(selfHere and self:Available(learned) or {}) do
            local missing
            if entry.group=="stance" then missing=self:StanceStatus()==false
            else missing=self:HasAura(entry.name)==false and self:FamilyPresent(entry.group)==false end
            if self:Enabled(entry,currentSpec,learned) and missing then
                self.missing[#self.missing+1]=entry
            end
        end
        if s.groupEnabled and self:ShowsHere("groupWhere") then
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
        if self:Class()=="Shaman" and selfHere then
            for _,slot in ipairs({"main","off"}) do
                local name=s[slot.."Enchant"]
                if slot=="main" and name==nil then
                    for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end
                end
                if name and learned[name] and self:WeaponMissing(slot) then
                    local hand=slot=="main" and "main hand" or "off hand"
                    self.missing[#self.missing+1]={name="Weapon buff ("..hand..")",message="Weapon buff missing ("..hand..")",spell=learned[name]}
                end
            end
        end
        if selfHere then for _,warning in ipairs(FT.BuffRanks:Warnings(learned,s)) do self.missing[#self.missing+1]=warning end end
        FT.BuffRanks:ObserveWeapons()
    end
    if self.badge then
        self.badge:SetShown(self:NoticeVisible("self",self.missing) or self.moving or self.previewSelf)
        if #self.missing>0 then
            self.cycle=math.max(1,math.min(self.cycle,#self.missing))
            local entry=self.missing[self.cycle]
            self.badge.icon:SetTexture(entry.spell.icon or 134400)
            self.badge.text:SetText((entry.message or entry.name.." missing")..(#self.missing>1 and "  +"..(#self.missing-1) or ""))
        elseif self.moving or self.previewSelf then self.badge.icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude");self.badge.text:SetText("Self buff missing — preview")
        end
        self.groupBadge:SetShown(self:NoticeVisible("group",self.groupMissing) or self.previewGroup)
        if #self.groupMissing>0 then
            self.groupCycle=math.max(1,math.min(self.groupCycle or 1,#self.groupMissing))
            local entry=self.groupMissing[self.groupCycle]
            self.groupBadge.icon:SetTexture(entry.spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.groupBadge.text:SetText(entry.name)
        elseif self.previewGroup then
            self.groupBadge.icon:SetTexture("Interface\\Icons\\Spell_Holy_PrayerOfFortitude")
            self.groupBadge.text:SetText("Group buff missing — preview")
        end
        self:ApplyPosition()
    end
    if self.frame then self:RefreshMenu(learned) end
end
function Reminder:Apply()
    if FT.modules.RankMarker and self.markerApplied~=self:Settings().rankMarker then
        self.markerApplied=self:Settings().rankMarker; FT.modules.RankMarker:Apply()
    elseif FT.modules.RankMarker and self:Settings().rankMarker then FT.modules.RankMarker:Queue() end
    if not self.badge then
        local badge=CreateFrame("Button","ForeverToolsBuffReminder",UIParent)
        self.badge=badge;badge:SetSize(285,34);badge:SetPoint("TOP",UIParent,"TOP",0,-115)
        badge:SetFrameStrata("LOW");FT:Panel(badge)
        badge.icon=badge:CreateTexture(nil,"ARTWORK");badge.icon:SetSize(22,22);badge.icon:SetPoint("LEFT",8,0)
        badge.text=FT:Label(badge,"",13);badge.text:SetPoint("LEFT",badge.icon,"RIGHT",8,0);badge.text:SetWidth(242)
        badge:RegisterForClicks("LeftButtonUp","RightButtonUp")
        badge:SetScript("OnClick",function(_,button) self:ClickNotice("self",button) end)
        FT:Tooltip(badge,"Missing self buffs",function()
            local lines={};for _,entry in ipairs(self.missing) do lines[#lines+1]=entry.detail or entry.message or entry.name.." missing" end
            return table.concat(lines,"\n").."\nHides after 30 sec. Left-click dismisses; right-click opens settings."
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
        group:SetSize(285,34);group:SetFrameStrata("LOW");FT:Panel(group)
        group.icon=group:CreateTexture(nil,"ARTWORK");group.icon:SetSize(22,22);group.icon:SetPoint("LEFT",8,0)
        group.text=FT:Label(group,"",13);group.text:SetPoint("LEFT",group.icon,"RIGHT",8,0);group.text:SetWidth(242)
        group:RegisterForClicks("LeftButtonUp","RightButtonUp")
        group:SetScript("OnClick",function(_,button) self:ClickNotice("group",button) end)
        group:RegisterForDrag("LeftButton");group:SetScript("OnDragStart",function(owner) self:DragStart(owner) end)
        group:SetScript("OnDragStop",function() self:DragUpdate();self.dragging=false end)
        FT:Tooltip(group,"Group buffs","Hides after 30 sec. Left-click dismisses; right-click opens settings.")
    end
    self:Refresh()
end
function Reminder:RefreshMenu(learned)
    local s=self:Settings();learned=learned or self:Learned()
    self.toggle.label:SetText("Self-buff reminders: "..(s.enabled and "On" or "Off"));FT:SetSelected(self.toggle,s.enabled)
    self.groupToggle.label:SetText("Group reminders: "..(s.groupEnabled and "On" or "Off"));FT:SetSelected(self.groupToggle,s.groupEnabled)
    for field,row in pairs(self.whereRows) do
        local active=field=="selfWhere" and s.enabled or field=="groupWhere" and s.groupEnabled
        for key,button in pairs(row.buttons) do FT:SetSelected(button,s[field][key]); button:SetAlpha(active and 1 or .5) end
        row.label:SetAlpha(active and 1 or .5)
    end
    self.rankToggle.label:SetText("Low-rank alerts: "..(s.lowRank and "On" or "Off"));FT:SetSelected(self.rankToggle,s.lowRank)
    self.rankOneToggle.label:SetText("Ignore rank 1: "..(s.ignoreRankOne and "On" or "Off"));FT:SetSelected(self.rankOneToggle,s.ignoreRankOne)
    self.markerToggle.label:SetText("Mark on action bars: "..(s.rankMarker and "On" or "Off"));FT:SetSelected(self.markerToggle,s.rankMarker)
    local ignoredCount=0;for _ in pairs(type(s.ignoredRanks)=="table" and s.ignoredRanks or {}) do ignoredCount=ignoredCount+1 end
    self.exceptions.label:SetText("Exceptions"..(ignoredCount>0 and (" ("..ignoredCount..")") or ""))
    self.moveButton.label:SetText(self.moving and "Moving reminders — click to lock" or "Move reminders")
    FT:SetSelected(self.moveButton,self.moving)
    FT:SetSelected(self.selfPreview,self.previewSelf)
    FT:SetSelected(self.groupPreview,self.previewGroup)
    self.sizeValue:SetText("Size: "..math.floor(s.size*100+.5).."%")
    self.settingSize=true;self.sizeSlider:SetValue(s.size);self.settingSize=false
    self.colorSwatch:SetVertexColor(unpack(s.textColor))
    self.groupColorSwatch:SetVertexColor(unpack(s.groupTextColor))
    local editSpec=self.editSpec
    if not editSpec or editSpec=="Unassigned" then editSpec=self:CurrentSpec() end
    self.specChoice.value=editSpec;self.specChoice.label:SetText("Assign buffs for: "..editSpec)
    local specs=self:SpecChoices()
    local icon=specs[1] and specs[1].icon or "Interface\\Icons\\INV_Misc_Book_09"
    for _,spec in ipairs(specs) do if spec.value==editSpec then icon=spec.icon;break end end
    self.specChoice.icon:SetTexture(icon)
    local available=self:Available(learned,editSpec)
    for i,button in ipairs(self.rows) do
        local entry=available[i];button.entry=entry;button:SetShown(entry~=nil)
        if entry then
            local enabled=self:Enabled(entry,editSpec,learned)
            button.label:SetText(entry.name..": "..(enabled and "On" or "Off"));FT:SetSelected(button,enabled)
            button.icon:SetTexture(entry.spell.icon or 134400)
        end
    end
    local weapon=self:Class()=="Shaman"
    for _,slot in ipairs({"main","off"}) do
        local dropdown=self[slot.."Dropdown"];dropdown:SetShown(weapon)
        if weapon then
            local name=s[slot.."Enchant"]
            if slot=="main" and name==nil then for _,candidate in ipairs(enchants) do if learned[candidate] then name=candidate;break end end end
            dropdown.value=name or "";dropdown.label:SetText((slot=="main" and "Main hand: " or "Off hand: ")..(name or "Off"))
        end
    end
    self.empty:SetShown(#available==0 and not weapon)
    local y=184+math.max(1,math.ceil(#available/2))*38
    local function place(control,x,top) control:ClearAllPoints();control:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top) end
    if weapon then place(self.mainDropdown,24,y);place(self.offDropdown,24,y+38);y=y+80 end
    place(self.rankToggle,24,y);place(self.rankOneToggle,286,y);y=y+38
    place(self.markerToggle,24,y);place(self.exceptions,286,y);y=y+38
    place(self.selfColorButton,24,y);y=y+40
    place(self.whereRows.selfWhere.label,24,y+9);self:PlaceWhere("selfWhere",y);y=y+46
    place(self.groupToggle,24,y);y=y+40
    place(self.whereRows.groupWhere.label,24,y+9);self:PlaceWhere("groupWhere",y);y=y+40
    place(self.selfPreview,24,y);place(self.groupPreview,286,y);y=y+40
    place(self.groupColorButton,24,y);y=y+46
    place(self.moveButton,24,y);y=y+44
    place(self.sizeValue,24,y);place(self.sizeSlider,186,y);y=y+35
    place(self.resetPosition,24,y)
    self.frame:SetHeight(y+54)
end
function Reminder:PlaceWhere(field,top)
    local x=92
    for _,place in ipairs(self.places) do
        local b=self.whereRows[field].buttons[place[1]]
        b:ClearAllPoints(); b:SetPoint("TOPLEFT",self.frame,"TOPLEFT",x,-top); x=x+89
    end
end
function Reminder:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsBuffReminders","Self-buff reminders",560,640);self.frame=frame
        local intro=FT:Label(frame,"A small notice appears when a chosen buff is missing.",14);intro:SetPoint("TOPLEFT",24,-64)
        self.toggle=FT:QuietButton(frame,"",512,36,"welcome");self.toggle:SetPoint("TOPLEFT",24,-96)
        self.toggle:SetScript("OnClick",function() local s=self:Settings();s.enabled=not s.enabled;self:Apply() end)
        FT:Tooltip(self.toggle,"Self-buff reminders","Shows a quiet notice near the top of the screen. Hidden in combat, on flights, while dead or in vehicles. Never casts for you.")
        self.specChoice=FT:Dropdown(frame,512,function() return self:SpecChoices() end,function(value) self.editSpec=value;self:RefreshMenu() end,"classes")
        self.specChoice.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.specChoice:SetPoint("TOPLEFT",24,-145)
        FT:Tooltip(self.specChoice,"Buffs for each talent tree","Choose a talent tree to assign its reminders. The addon follows your current talent tree automatically; these choices save with your profile.")
        self.rows={}
        for i=1,8 do
            local b=FT:QuietButton(frame,"",250,32,"welcome");b:SetPoint("TOPLEFT",24+((i-1)%2)*262,-185-math.floor((i-1)/2)*38)
            b.label:SetFont(FT.font or "Fonts\\FRIZQT__.TTF",12,"")
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
            FT:Tooltip(b,"Choose a self buff","Only learned spells appear here. Any active aura or stance clears its missing reminder. Choosing a buff in a shared family turns off the others.")
            self.rows[i]=b
        end
        self.empty=FT:Label(frame,"No supported self buffs learned yet.",13);self.empty:SetPoint("TOPLEFT",24,-195)
        for i,slot in ipairs({"main","off"}) do
            local dropdown=FT:Dropdown(frame,512,function()
                local list={{value="",label="Off"}};local learned=self:Learned()
                for _,name in ipairs(enchants) do if learned[name] then list[#list+1]={value=name,label=name,icon=learned[name].icon} end end
                return list
            end,function(value) self:Settings()[slot.."Enchant"]=value;self:Apply() end,"welcome")
            dropdown:SetPoint("TOPLEFT",24,-405-(i-1)*42);self[slot.."Dropdown"]=dropdown
            FT:Tooltip(dropdown,"Weapon enchant reminder","Choose an enchant for this weapon slot. Any active temporary weapon buff clears the missing notice. Empty slots and shields stay quiet; your choice is kept for later weapon swaps.")
        end
        -- "Show in" rows: pick every place a notice may appear (multiple choice).
        self.whereRows={}
        for _,field in ipairs({"selfWhere","groupWhere"}) do
            local row={buttons={}}
            row.label=FT:Label(frame,"Show in:",13); row.label:SetTextColor(.78,.74,.86)
            for _,place in ipairs(self.places) do
                local key=place[1]
                local b=FT:QuietButton(frame,place[2],86,30)
                b:SetScript("OnClick",function() local s=self:Settings(); s[field][key]=not s[field][key]; self:Apply() end)
                FT:Tooltip(b,place[2],(field=="selfWhere" and "Show self-buff notices here. " or "Show group-buff notices here (only while in a group). ")..place[3].." Pick as many places as you like.")
                row.buttons[key]=b
            end
            self.whereRows[field]=row
        end
        self.groupToggle=FT:QuietButton(frame,"",512,34,"party");self.groupToggle:SetPoint("TOPLEFT",24,-488)
        self.groupToggle:SetScript("OnClick",function() local s=self:Settings();s.groupEnabled=not s.groupEnabled;self:Apply() end)
        FT:Tooltip(self.groupToggle,"Group reminders","Shows a small notice while you are in a group and a chosen group buff is missing from a member. Choose where below; by default dungeons, raids and PvP. Hidden in combat and when solo.")
        self.moveButton=FT:QuietButton(frame,"",512,34,"move");self.moveButton:SetPoint("TOPLEFT",24,-528)
        self.moveButton:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.moveButton,"Move reminders","Unlock, drag the reminder on screen, then lock it. Its position saves with your profile.")
        self.sizeValue=FT:Label(frame,"",14);self.sizeValue:SetPoint("TOPLEFT",24,-574);self.sizeValue:SetWidth(120)
        self.sizeSlider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate");self.sizeSlider:SetSize(345,18);self.sizeSlider:SetPoint("TOPLEFT",186,-571)
        self.sizeSlider:SetMinMaxValues(.7,1.5);self.sizeSlider:SetValueStep(.05);self.sizeSlider:SetObeyStepOnDrag(true)
        self.sizeSlider:SetScript("OnValueChanged",function(_,value)
            if self.settingSize then return end
            self:Settings().size=math.floor(value*20+.5)/20;self:Apply()
        end)
        FT:Tooltip(self.sizeSlider,"Reminder size","Adjust self and group notices from 70% to 150%. The position stays on screen as the size changes.")
        for i,entry in ipairs({{"textColor","Self text color"},{"groupTextColor","Group text color"}}) do
            local field,label=entry[1],entry[2]
            local color=FT:QuietButton(frame,label,250,34,"fonts");color:SetPoint("TOPLEFT",24+(i-1)*262,-611)
            if field=="textColor" then self.selfColorButton=color else self.groupColorButton=color end
            local swatch=color:CreateTexture(nil,"ARTWORK");swatch:SetTexture("Interface\\Buttons\\WHITE8X8");swatch:SetSize(18,18);swatch:SetPoint("RIGHT",-12,0)
            if field=="textColor" then self.colorSwatch=swatch else self.groupColorSwatch=swatch end
            color:SetScript("OnClick",function()
                if not ColorPickerFrame then return end
                local s=self:Settings();local old={unpack(s[field])}
                local function change() s[field]={ColorPickerFrame:GetColorRGB()};self:Apply() end
                local function cancel() s[field]=old;self:Apply() end
                if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
                else ColorPickerFrame:SetColorRGB(unpack(old));ColorPickerFrame.func=change;ColorPickerFrame.cancelFunc=cancel;ColorPickerFrame:Show() end
            end)
            FT:Tooltip(color,label,"Choose the text color for this reminder notice.")
        end
        self.rankToggle=FT:QuietButton(frame,"",250,32,"buffs");self.rankToggle:SetPoint("TOPLEFT",24,-653)
        self.rankToggle:SetScript("OnClick",function() local s=self:Settings();s.lowRank=not s.lowRank;self:Apply() end)
        FT:Tooltip(self.rankToggle,"Low-rank alerts","Warn when your own buff uses a lower rank than you have learned. Trainer upgrades are checked after visiting a trainer. Unknown ranks stay quiet. Turn off for intentional downranking.")
        self.rankOneToggle=FT:QuietButton(frame,"",250,32,"buffs");self.rankOneToggle:SetPoint("LEFT",self.rankToggle,"RIGHT",12,0)
        self.rankOneToggle:SetScript("OnClick",function() local s=self:Settings();s.ignoreRankOne=not s.ignoreRankOne;self:Apply() end)
        FT:Tooltip(self.rankOneToggle,"Ignore rank 1","Keep low-rank checks, but allow rank 1 spells (for example dispel bait or cheap heals) without a warning or marker.")
        self.markerToggle=FT:QuietButton(frame,"",250,32,"buffs")
        self.markerToggle:SetScript("OnClick",function() local s=self:Settings();s.rankMarker=not s.rankMarker;self:Apply() end)
        FT:Tooltip(self.markerToggle,"Low-rank marker on action bars","Adds a small amber corner to your own action buttons that use a lower rank than one you have learned. Hover the button to see which rank you know. No popups, sounds or messages. Spells placed directly on bars only; macros are not checked.")
        self.exceptions=FT:Dropdown(frame,250,function() return FT.modules.RankMarker:ExceptionChoices() end,function(value) FT.modules.RankMarker:ToggleIgnore(value) end,"buffs")
        self.exceptions.menuWidth=340
        FT:Tooltip(self.exceptions,"Low-rank exceptions","Ignore specific spells you downrank on purpose. Ignored spells get no marker and no low-rank alert. Choose an ignored spell again to stop ignoring it.")
        local resetPosition=FT:QuietButton(frame,"Reset reminder position",512,30,"reset");resetPosition:SetPoint("TOPLEFT",24,-695);self.resetPosition=resetPosition
        resetPosition:SetScript("OnClick",function()
            local s=self:Settings();s.x=nil;s.y=nil;s.screenWidth=nil;s.screenHeight=nil;self:Apply()
        end)
        FT:Tooltip(resetPosition,"Reset position","Return the reminders to their original place near the top center of the screen.")
        for i,entry in ipairs({{"previewSelf","Preview self reminder","selfPreview"},{"previewGroup","Preview group reminder","groupPreview"}}) do
            local key=entry[1]
            local button=FT:QuietButton(frame,entry[2],250,32,"buffs");self[entry[3]]=button
            button:SetScript("OnClick",function() self[key]=not self[key];FT:SetSelected(button,self[key]);self:Apply() end)
            FT:Tooltip(button,entry[2],"Show or hide a sample notice. Both previews stack without overlapping.")
        end
        frame:HookScript("OnHide",function()
            self.previewSelf=nil;self.previewGroup=nil
            FT:SetSelected(self.selfPreview,false);FT:SetSelected(self.groupPreview,false)
            self:SetMoving(false)
        end)
        local info=FT:Info(frame,"How reminders work","Choose buffs from your learned spells. Notices hide in combat, on flights, while dead or in vehicles. Righteous Fury appears only when you have learned it and Protection is your main talent tree. Left-click dismisses; right-click opens settings.")
        info:SetPoint("TOPRIGHT",-22,-62)
    end
    self.editSpec=self:CurrentSpec()
    self:Apply();self.frame:Show()
end
FT:RegisterModule("BuffReminder",Reminder)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_CONTROL_LOST","PLAYER_CONTROL_GAINED","UNIT_ENTERED_VEHICLE","UNIT_EXITED_VEHICLE","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","UNIT_AURA","SPELLS_CHANGED","PLAYER_TALENT_UPDATE","UPDATE_SHAPESHIFT_FORM","UPDATE_SHAPESHIFT_FORMS","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_EQUIPMENT_CHANGED","UNIT_INVENTORY_CHANGED","WEAPON_ENCHANT_CHANGED","WEAPON_SLOT_CHANGED","UNIT_SPELLCAST_START","UNIT_SPELLCAST_SUCCEEDED","PLAYER_LEVEL_UP","TRAINER_SHOW","TRAINER_UPDATE","PLAYER_UPDATE_RESTING"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event,unit,castGUID,spellID)
    if not FT.dbReady then return end
    if event=="TRAINER_SHOW" or event=="TRAINER_UPDATE" then FT.BuffRanks:CaptureTrainer() end
    if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_SUCCEEDED" then
        if not safe(unit) or unit~="player" or not safe(spellID) then return end
        if event=="UNIT_SPELLCAST_START" then FT.BuffRanks:BeginCast(spellID);return end
        FT.BuffRanks:FinishCast(spellID)
        C_Timer.After(.6,function() if FT.dbReady then Reminder:Apply() end end)
        return
    end
    if event=="UNIT_AURA" and (not safe(unit) or type(unit)~="string" or (unit~="player" and not unit:match("^party%d+$") and not unit:match("^raid%d+$"))) then return end
    if event=="PLAYER_REGEN_DISABLED" then if Reminder.badge then Reminder.badge:Hide();Reminder.groupBadge:Hide() end;return end
    C_Timer.After(0,function() if FT.dbReady then Reminder:Apply() end end)
    if event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(1.5,function() if FT.dbReady then Reminder:Apply() end end)
    end
end)
local refreshElapsed=0
events:SetScript("OnUpdate",function(_,dt)
    refreshElapsed=refreshElapsed+dt
    if refreshElapsed<1 then return end
    refreshElapsed=0
    if FT.dbReady and Reminder.badge and not InCombatLockdown() and Reminder:Settings().enabled then
        Reminder:Refresh(Reminder.learnedCache)
    end
end)
