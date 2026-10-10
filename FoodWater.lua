local _,FT=...
-- The "Eat & Drink" macro (Macros > Mage): one button that eats mage-made
-- food when you are hurt and drinks mage-made water when your mana is low.
-- Buff food is never used: that is yours to eat when the buff runs out.
--   * Health missing and mana missing: it eats and drinks at once.
--   * Health full: it only drinks. Mana full (or no mana): it only eats.
--   * Both full: it does nothing (the icon stays, so the button is not blank).
--   * It uses the best conjured food and water you can use at your level,
--     so it follows you as you learn better ranks. Out of water or food: it
--     conjures more (water first).
-- A macro cannot see your health or mana, so ForeverTools rewrites the one
-- you added whenever that changes (only out of combat, where you can eat).
-- A macro whose text you changed yourself is never touched.
local Meal={}
local NAME="Eat & Drink"
Meal.NAME=NAME
local CONSUMABLE,FOOD_DRINK=0,5
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function normalized(body) return type(body)=="string" and body:gsub("\r\n","\n"):gsub("\n+$","") or "" end
local function number(v) return plain(v) and type(v)=="number" and v or nil end
local function itemInfo(id)
    local get=(C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return end
    local ok,name,_,_,level,minLevel=pcall(get,id)
    if not ok or not plain(name) or type(name)~="string" or name=="" then return end
    return name,number(level) or 1,number(minLevel) or 0
end
-- What an item does when used: "food", "drink", "both" or nil.
function Meal:Kind(id)
    local getSpell=(C_Item and C_Item.GetItemSpell) or GetItemSpell
    local spell
    if getSpell then local ok,name=pcall(getSpell,id); if ok and plain(name) and type(name)=="string" then spell=name end end
    if spell=="Food" then return "food" elseif spell=="Drink" then return "drink" elseif spell=="Refreshment" then return "both" end
    -- The item's spell is only known once the game has loaded the item. A
    -- consumable whose spell is not known yet is asked for, and checked
    -- again when it arrives (it may be food or drink).
    local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant then return nil end
    local ok,_,_,_,_,_,class,subclass=pcall(instant,id)
    if not ok or class~=CONSUMABLE or (subclass~=FOOD_DRINK and subclass~=0) then return nil end
    if not spell then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID,id) end
        return "pending"
    end
    if subclass~=FOOD_DRINK then return nil end
    local lower=spell:lower()
    if lower:find("drink",1,true) then return "drink" end
    if lower:find("food",1,true) then return "food" end
end
-- The best food and the best drink in your bags.
function Meal:Carried()
    -- Bags are read again only after they change (health ticks do not).
    if self.best then return self.best end
    local best={}
    local complete=true
    if not C_Container or not C_Container.GetContainerNumSlots then return best end
    local level=UnitLevel and number(UnitLevel("player")) or 1
    local seen={}
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local okCount,count=pcall(C_Container.GetContainerNumSlots,bag)
        if okCount and number(count) then
            for slot=1,count do
                local okID,id=pcall(C_Container.GetContainerItemID,bag,slot)
                if okID and number(id) and not seen[id] then
                    seen[id]=true
                    local kind=self:Kind(id)
                    if kind=="pending" then complete=false; kind=nil; self.waiting=true end
                    local name,itemLevel,minLevel=itemInfo(id)
                    if kind and not name then complete=false end
                    -- Only mage-made food and water: your own buff food is left
                    -- for you to eat when you choose.
                    if kind and name and minLevel<=level and self:Conjured(name,bag,slot) then
                        local score=itemLevel
                        for _,want in ipairs({"food","drink"}) do
                            if kind==want or kind=="both" then
                                if not best[want] or score>best[want].score then best[want]={id=id,name=name,score=score} end
                            end
                        end
                    end
                end
            end
        end
    end
    if complete then self.best=best end
    return best
end
-- Made by a mage? (The name, or the item's "Conjured Item" line.)
function Meal:Conjured(name,bag,slot)
    if name:find("^Conjured") then return true end
    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok,data=pcall(C_TooltipInfo.GetBagItem,bag,slot)
        if ok and type(data)=="table" and type(data.lines)=="table" then
            for _,line in ipairs(data.lines) do
                local text=line.leftText
                if plain(text) and type(text)=="string" and text:lower():find("conjured item",1,true) then return true end
            end
        end
    end
    return false
end
-- Do you know this spell (Conjure Water, Conjure Food)?
function Meal:Knows(spell)
    local get=(C_Spell and C_Spell.GetSpellInfo) or GetSpellInfo
    if not get then return false end
    local ok,info=pcall(get,spell)
    return ok and info~=nil and plain(info)
end
local function full(current,max) current,max=number(current),number(max); return not max or max<=0 or (current and current>=max) end
-- Missing health? Missing mana (classes without mana never are)?
function Meal:Needs()
    local hurt=not full(UnitHealth and UnitHealth("player"),UnitHealthMax and UnitHealthMax("player"))
    local power=Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    local thirsty=not full(UnitPower and UnitPower("player",power),UnitPowerMax and UnitPowerMax("player",power))
    return hurt,thirsty
end
-- The macro text for right now. Out of water (or food) and you can make
-- it: the macro conjures it first (water before food).
function Meal:Body()
    local best=self:Carried()
    local hurt,thirsty=self:Needs()
    local food,drink=best.food,best.drink
    local conjure
    if not drink and self:Knows("Conjure Water") and (thirsty or not hurt) then conjure="Conjure Water"
    elseif not food and self:Knows("Conjure Food") and (hurt or not thirsty) then conjure="Conjure Food"
    elseif not drink and self:Knows("Conjure Water") and not (hurt and food) then conjure="Conjure Water" end
    if conjure then return "#showtooltip "..conjure.."\n/cast "..conjure end
    local lines={}
    if hurt and food then lines[#lines+1]="/use "..food.name end
    -- Food that also restores mana (Refreshment) already covers both.
    if thirsty and drink and not (hurt and food and food.id==drink.id) then lines[#lines+1]="/use "..drink.name end
    local shown=(thirsty and not hurt and drink) or food or drink
    table.insert(lines,1,"#showtooltip"..(shown and (" "..shown.name) or ""))
    return table.concat(lines,"\n")
end
-- Still the text ForeverTools writes? Then it may be rewritten.
function Meal:Ours(body)
    local count=0
    for line in (normalized(body).."\n"):gmatch("(.-)\n") do
        count=count+1
        if count==1 then if line:sub(1,12)~="#showtooltip" then return false end
        elseif line=="/cast Conjure Water" or line=="/cast Conjure Food" then -- ours too
        elseif line:sub(1,5)~="/use " or line:find("[%[;]") then return false
        elseif count>3 then return false end
    end
    return count>=1
end
function Meal:Update()
    if not GetMacroInfo or not EditMacro or not GetNumMacros then return 0 end
    local function ours(body) return self:Ours(body) end
    local list=FT:FollowedMacros(NAME,ours)
    if #list==0 then return 0 end
    if InCombatLockdown() or (MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown()) then self.pending=true; return 0 end
    self.pending=nil
    return FT:UpdateFollowed(NAME,ours,self:Body())
end
-- Is it in your macros (under any name)?
function Meal:Installed() return #FT:FollowedMacros(NAME,function(body) return self:Ours(body) end)>0 end
-- For the bug report: what the macro would use right now.
function Meal:Report()
    self.best=nil
    local best=self:Carried(); local hurt,thirsty=self:Needs()
    return "Eat & Drink: food "..(best.food and best.food.name or "none")..", drink "..(best.drink and best.drink.name or "none")..
        ", hurt "..tostring(hurt)..", mana missing "..tostring(thirsty)..(self.waiting and ", items still loading" or "")
end
FT:RegisterModule("FoodWater",Meal)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_REGEN_ENABLED","PLAYER_LEVEL_UP","GET_ITEM_INFO_RECEIVED","ITEM_DATA_LOAD_RESULT"}) do pcall(events.RegisterEvent,events,event) end
pcall(events.RegisterUnitEvent,events,"UNIT_HEALTH","player")
pcall(events.RegisterUnitEvent,events,"UNIT_MAXHEALTH","player")
pcall(events.RegisterUnitEvent,events,"UNIT_POWER_UPDATE","player")
pcall(events.RegisterUnitEvent,events,"UNIT_MAXPOWER","player")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        -- Only matters while an item in the bags was still loading.
        if not Meal.waiting then return end
        Meal.waiting=nil; Meal.best=nil
    end
    if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_LEVEL_UP" or event=="PLAYER_ENTERING_WORLD" then Meal.best=nil end
    if InCombatLockdown() then Meal.pending=true; return end
    if event=="PLAYER_REGEN_ENABLED" and not Meal.pending then
        -- A fight changed your health: the macro follows right after it.
        Meal.pending=true
    end
    -- Health and mana tick often: one check a moment after the last change,
    -- and the macro is only rewritten when its text really changes.
    FT:Coalesce("foodWaterMacro",function() Meal:Update() end,.3)
end)
