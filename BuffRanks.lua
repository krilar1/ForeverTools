local _,FT=...
local R={}
FT.BuffRanks=R
local function readable(v) return not issecretvalue or not issecretvalue(v) end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b,c=pcall(fn,...)
    if ok and readable(a) and readable(b) and readable(c) then return a,b,c end
end
local function number(text)
    if not readable(text) then return end
    if type(text)=="number" then return text>0 and text or nil end
    if type(text)=="string" then return tonumber(text:match("[Rr]ank%s+(%d+)")) end
end
local function roman(text)
    local values={I=1,V=5,X=10};local total,last=0,0
    for i=#text,1,-1 do local n=values[text:sub(i,i)];if not n then return end;total=total+(n<last and -n or n);last=n end
    return total>0 and total or nil
end
function R:NameRank(name,rank)
    if not readable(name) or type(name)~="string" then return end
    local base,suffix=name:match("^(.+ Poison) ([IVX]+)$")
    return base or name,number(rank) or (suffix and roman(suffix))
end
function R:SpellRank(id)
    if not readable(id) or type(id)~="number" then return end
    local text=call(C_Spell and C_Spell.GetSpellSubtext or GetSpellSubtext,id)
    if not text and GetSpellInfo then local _,legacy=call(GetSpellInfo,id);text=legacy end
    return number(text)
end
function R:Knowledge()
    local build=GetBuildInfo and select(2,GetBuildInfo()) or "unknown"
    local guid=call(UnitGUID,"player") or "player"
    FT.db.buffRankKnowledge=FT.db.buffRankKnowledge or {}
    local key=tostring(build)..":"..guid
    if type(FT.db.buffRankKnowledge[key])~="table" then FT.db.buffRankKnowledge[key]={trainer={},enchants={}} end
    return FT.db.buffRankKnowledge[key]
end
function R:Catalogue(spells)
    local result={}
    for _,spell in pairs(spells or {}) do
        local name,rank=self:NameRank(spell.name,spell.rank or spell.label)
        rank=rank or self:SpellRank(spell.value)
        if name and rank and (not result[name] or rank>result[name].rank) then result[name]={name=name,rank=rank,icon=spell.icon,value=spell.value} end
    end
    local level=call(UnitLevel,"player") or 0
    for name,ranks in pairs(self:Knowledge().trainer) do
        for _,entry in pairs(ranks) do
            if type(entry.level)=="number" and entry.level<=level and (not result[name] or entry.rank>result[name].rank) then
                result[name]={name=name,rank=entry.rank,icon=entry.icon,trainer=true}
            end
        end
    end
    return result
end
function R:CaptureTrainer()
    local count=call(GetNumTrainerServices)
    if type(count)~="number" or not GetTrainerServiceInfo then return end
    local known=self:Knowledge().trainer
    for i=1,count do
        local name,sub,kind=call(GetTrainerServiceInfo,i)
        local base,rank=self:NameRank(name,sub)
        local level=call(GetTrainerServiceLevelReq,i)
        local qualified=kind=="available" or kind=="used"
        if not qualified and kind=="unavailable" and type(level)=="number" and level>(call(UnitLevel,"player") or 0) then
            -- Only predict a later level when all non-level prerequisites are exposed and met.
            local skill,_,hasSkill=call(GetTrainerServiceSkillReq,i)
            local requirements=call(GetTrainerServiceNumAbilityReq,i)
            qualified=GetTrainerServiceSkillReq and (not skill or hasSkill==true) and type(requirements)=="number"
            if qualified then
                for n=1,requirements do local _,met=call(GetTrainerServiceAbilityReq,i,n);if not met then qualified=false;break end end
            end
        end
        if base and rank and qualified and type(level)=="number" then
            known[base]=known[base] or {}
            known[base][rank]={rank=rank,level=level,icon=call(GetTrainerServiceIcon,i)}
        end
    end
end
function R:WeaponEligible(slot)
    local inventory=slot=="main" and 16 or 17
    local get=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if slot=="off" and get and GetInventoryItemID then
        local main=call(GetInventoryItemID,"player",16)
        if main then
            local ok,_,_,_,equip=pcall(get,main)
            if ok and readable(equip) and equip=="INVTYPE_2HWEAPON" then return false end
        end
    end
    if GetInventoryItemID then
        local item=call(GetInventoryItemID,"player",inventory)
        if not item then return false end
        if get then
            local ok,_,_,_,equip=pcall(get,item)
            if ok and readable(equip) and equip then
                return equip=="INVTYPE_WEAPON" or equip=="INVTYPE_2HWEAPON" or equip=="INVTYPE_WEAPONMAINHAND" or equip=="INVTYPE_WEAPONOFFHAND"
            end
        end
    end
    if slot=="off" then
        local fn=C_PaperDollInfo and C_PaperDollInfo.OffhandHasWeapon or OffhandHasWeapon
        if fn then return call(fn)==true end
    end
    return true
end
function R:WeaponState(slot)
    if not self:WeaponEligible(slot) then return nil end
    local inventory=slot=="main" and 16 or 17
    local item=call(GetInventoryItemID,"player",inventory)
    -- Same source Blizzard's buff frame uses for weapon-enchant icons on this
    -- client, so the reminder agrees with what the player sees on screen.
    local weaponSlot=Enum and Enum.WeaponSlot and (slot=="main" and Enum.WeaponSlot.MainHand or Enum.WeaponSlot.OffHand)
    if weaponSlot and C_Item and C_Item.GetWeaponEnchantInfo then
        local ok,enchants=pcall(C_Item.GetWeaponEnchantInfo,weaponSlot)
        if ok and readable(enchants) and type(enchants)=="table" then
            local unknown=false
            for _,enchant in pairs(enchants) do
                if type(enchant)=="table" then
                    if not readable(enchant.hasEnchant) then unknown=true
                    elseif enchant.hasEnchant then
                        local id=readable(enchant.enchantID) and enchant.enchantID or nil
                        local remaining=readable(enchant.timeLeft) and enchant.timeLeft or nil
                        return {present=true,id=id,remaining=remaining,item=item}
                    end
                end
            end
            if not unknown then return {present=false,item=item} end
        end
    end
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local ok,info=pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo,inventory)
        if ok and readable(info) then return info and {present=true,id=info.enchantID,remaining=info.remainingTimeMs,item=item} or {present=false,item=item} end
    end
    if not GetWeaponEnchantInfo then return end
    local values={pcall(GetWeaponEnchantInfo)}
    if not values[1] then return end
    local index=slot=="main" and 2 or 6
    -- Old clients expose three fields per weapon, newer clients expose four.
    if slot=="off" and type(values[5])=="boolean" then index=5 end
    local value=values[index]
    if not readable(value) then return end
    local id=(index~=5) and values[index+3] or nil
    return {present=value==true or value==1,id=id,remaining=values[index+1],item=item}
end
function R:WeaponRank(slot,state,catalogue)
    if not state or not state.present then return end
    if readable(state.id) and state.id then
        local observed=self:Knowledge().enchants[state.id]
        if observed then return observed.name,observed.rank end
    end
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then return end
    local data=call(C_TooltipInfo.GetInventoryItem,"player",slot=="main" and 16 or 17)
    if not data or not readable(data.lines) or type(data.lines)~="table" then return end
    for _,line in ipairs(data.lines) do
        local text=line.leftText
        if readable(text) and type(text)=="string" then
            text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            for name in pairs(catalogue) do
                local stem=name:gsub(" Weapon$","")
                if text:sub(1,#stem)==stem then
                    local tail=text:sub(#stem+1)
                    local rank=tonumber(tail:match("^%s+(%d+)%f[%D]")) or number(tail)
                    local numeral=tail:match("^%s+([IVX]+)%f[%W]")
                    rank=rank or (numeral and roman(numeral))
                    if rank then return name,rank end
                end
            end
        end
    end
end
function R:BeginCast(id)
    local name=call(C_Spell and C_Spell.GetSpellName,id)
    if not name and GetSpellInfo then name=call(GetSpellInfo,id) end
    local base,rank=self:NameRank(name,self:SpellRank(id))
    if not base or not rank or not (base:match(" Weapon$") or base:match(" Poison$")) then self.cast=nil;return end
    self.cast={id=id,name=base,rank=rank,main=self:WeaponState("main"),off=self:WeaponState("off")}
end
function R:FinishCast(id)
    local cast=self.cast
    if not cast and self.weaponSnapshot then
        self:BeginCast(id);cast=self.cast
        if cast then cast.main=self.weaponSnapshot.main;cast.off=self.weaponSnapshot.off end
    end
    self.cast=nil
    if not cast or not readable(id) or id~=cast.id then return end
    C_Timer.After(.4,function()
        for _,slot in ipairs({"main","off"}) do
            local before=cast[slot];local after=self:WeaponState(slot)
            if before and after and before.item==after.item and after.present and readable(after.id) and after.id and readable(before.id) and readable(after.remaining) and readable(before.remaining) then
                local changed=not before.present or before.id~=after.id or
                    (type(after.remaining)=="number" and type(before.remaining)=="number" and after.remaining>before.remaining+500)
                if changed then self:Knowledge().enchants[after.id]={name=cast.name,rank=cast.rank} end
            end
        end
    end)
end
function R:ObserveWeapons()
    self.weaponSnapshot={main=self:WeaponState("main"),off=self:WeaponState("off")}
end
function R:Warnings(spells,settings)
    local result={}
    if not settings.lowRank then return result end
    local catalogue=self:Catalogue(spells);local seen={}
    if not next(catalogue) then return result end
    local function warn(name,rank,slot)
        local best=name and catalogue[name]
        if not best or not rank or rank>=best.rank or (rank==1 and settings.ignoreRankOne) then return end
        if type(settings.ignoredRanks)=="table" and settings.ignoredRanks[name] then return end
        local key=name..(slot or "")
        if seen[key] then return end;seen[key]=true
        result[#result+1]={name=name,spell={icon=best.icon or 134400},message=(slot and "Weapon buff" or name).." — low rank",detail=name..(slot and (" ("..slot.." hand)") or "")..": rank "..rank.."; rank "..best.rank..(best.trainer and " available at trainer." or " learned.")}
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i=1,80 do
            local aura=call(C_UnitAuras.GetAuraDataByIndex,"player",i,"HELPFUL")
            if not aura then break end
            -- Only audit the player's own casts, never tell them to overwrite another caster's buff.
            if readable(aura.sourceUnit) and aura.sourceUnit=="player" then
                local name,rank=self:NameRank(aura.name,aura.rank)
                warn(name,rank or self:SpellRank(aura.spellId))
            end
        end
    end
    for _,slot in ipairs({"main","off"}) do
        local state=self:WeaponState(slot)
        local name,rank=self:WeaponRank(slot,state,catalogue)
        warn(name,rank,slot)
    end
    return result
end
