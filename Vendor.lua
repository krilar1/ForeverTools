local _,FT=...
-- Merchant helpers (each opt-in, off by default): sell grey items and repair
-- when a merchant opens. Selling works like right-clicking each grey item (so
-- it can be bought back); repairing like the Repair button. Never in combat;
-- one summary line.
local Vendor={}
local function readable(v) return (not issecretvalue or not issecretvalue(v)) and v~=nil end
local function call(fn,...)
    if type(fn)~="function" then return end
    local ok,a,b=pcall(fn,...)
    if ok and readable(a) then return a,b end
end
local function money(copper)
    if GetMoneyString then return GetMoneyString(copper,true) end
    return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
end
function Vendor:Settings() return FT.modules.System:Settings() end
-- White gear you can sell too (optional): only white weapons and armor you
-- would wear or wield. Never trade tools (mining pick, skinning knife,
-- blacksmith hammer, spanners, fishing poles), shirts, tabards, bags,
-- trinkets, rings and other miscellaneous pieces, or anything the merchant
-- won't pay for. Food, drink, reagents, ammo and trade goods are never
-- touched because they are not gear.
local TOOLS={[2901]=true,[7005]=true,[5956]=true,[6219]=true,[10498]=true,[6256]=true,[6365]=true,[6366]=true,[6367]=true,[12225]=true,[19022]=true,[19970]=true,[25978]=true,[9149]=true,[20815]=true}
local KEEP_SLOTS={INVTYPE_BODY=true,INVTYPE_TABARD=true,INVTYPE_BAG=true,INVTYPE_QUIVER=true,INVTYPE_AMMO=true,INVTYPE_TRINKET=true,INVTYPE_FINGER=true,INVTYPE_NECK=true,INVTYPE_RELIC=true,[""]=true}
-- Which inventory slots an equip type goes in (main slot first).
local SLOTS={INVTYPE_HEAD={1},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},
    INVTYPE_WRIST={9},INVTYPE_HAND={10},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},INVTYPE_2HWEAPON={16},INVTYPE_WEAPONMAINHAND={16},
    INVTYPE_WEAPONOFFHAND={17},INVTYPE_HOLDABLE={17},INVTYPE_SHIELD={17},INVTYPE_RANGED={18,16},INVTYPE_RANGEDRIGHT={18,16},INVTYPE_THROWN={18}}
-- White gear is only worth wearing early on: leveling guides and gear lists
-- have greens from quests and the first dungeons in almost every slot by the
-- late teens. So "better than what you wear" only protects white gear up to
-- this level; after it, white weapons and armor are sold (an empty slot is
-- still filled first, at any level).
local UPGRADE_LEVEL=20
-- Armor a class can wear right now (cloth 1, leather 2, mail 3, plate 4,
-- shields 6). Heavier armor learned at 40 is not kept for later: nobody
-- wears white gear by then.
local ARMOR={WARRIOR=3,PALADIN=3,HUNTER=2,SHAMAN=2,ROGUE=2,DRUID=2,MAGE=1,PRIEST=1,WARLOCK=1}
local ARMOR40={WARRIOR=4,PALADIN=4,HUNTER=3,SHAMAN=3}
local SHIELDS={WARRIOR=true,PALADIN=true,SHAMAN=true}
local function itemLevel(link)
    if not link then return end
    local get=C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
    local level=get and call(get,link)
    if type(level)=="number" then return level end
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    if info then local ok,_,_,_,lvl=pcall(info,link); if ok and readable(lvl) and type(lvl)=="number" then return lvl end end
end
-- Weapon types each class can use or learn (generous on purpose: when in
-- doubt an item is kept). 0/1 axes, 2 bow, 3 gun, 4/5 maces, 6 polearm,
-- 7/8 swords, 10 staff, 13 fist, 15 dagger, 16 thrown, 18 crossbow, 19 wand.
local function set(...) local t={} for _,v in ipairs({...}) do t[v]=true end return t end
local WEAPONS={WARRIOR=set(0,1,2,3,4,5,6,7,8,10,13,15,16,18),PALADIN=set(0,1,4,5,6,7,8),HUNTER=set(0,1,2,3,6,7,8,10,13,15,16,18),
    ROGUE=set(0,2,3,4,7,13,15,16,18),PRIEST=set(4,10,15,19),SHAMAN=set(0,1,4,5,10,13,15),MAGE=set(7,10,15,19),WARLOCK=set(7,10,15,19),DRUID=set(4,5,6,10,13,15)}
local function wearable(classID,subclassID)
    local _,class=UnitClass("player")
    if classID==2 then local known=WEAPONS[class]; return not known or known[subclassID]==true end
    if subclassID==6 then return SHIELDS[class]==true end
    if subclassID>=1 and subclassID<=4 then
        local level=UnitLevel and UnitLevel("player") or 1
        local best=(type(level)=="number" and level>=40 and ARMOR40[class]) or ARMOR[class] or 4
        return subclassID<=best
    end
    return true
end
-- Items saved in one of your equipment sets are never sold.
local function inEquipmentSet(itemID)
    if not itemID or not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs or not C_EquipmentSet.GetItemIDs then return false end
    local ok,sets=pcall(C_EquipmentSet.GetEquipmentSetIDs)
    if not ok or type(sets)~="table" then return false end
    for _,setID in ipairs(sets) do
        local ok2,ids=pcall(C_EquipmentSet.GetItemIDs,setID)
        if ok2 and type(ids)=="table" then for _,id in pairs(ids) do if id==itemID then return true end end end
    end
    return false
end
-- Could this still be an upgrade? Kept when you can wear it and it is better
-- (higher item level) than what you have in that slot, or that slot is empty.
-- If anything can't be read, it is kept.
local function possibleUpgrade(link,equipLoc,classID,subclassID)
    if not wearable(classID,subclassID) then return false end
    local slots=SLOTS[equipLoc]; if not slots then return true end
    local level=itemLevel(link); if not level then return true end
    local mine=UnitLevel and UnitLevel("player") or 1
    local early=type(mine)~="number" or mine<=UPGRADE_LEVEL
    for i,slot in ipairs(slots) do
        local worn=GetInventoryItemLink and call(GetInventoryItemLink,"player",slot)
        if worn then
            local wornLevel=itemLevel(worn); if not wornLevel then return true end
            if early and level>wornLevel then return true end
        elseif slot==17 then
            -- Empty off hand (for example with a two-hander): compare with the main hand.
            local main=GetInventoryItemLink and call(GetInventoryItemLink,"player",16)
            local mainLevel=main and itemLevel(main)
            if not main or not mainLevel or (early and level>mainLevel) then return true end
        elseif i==1 then
            return true -- nothing in that slot: anything is an upgrade
        end
    end
    return false
end
local function whiteGear(link,itemID)
    if itemID and TOOLS[itemID] then return false end
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return false end
    local ok,_,_,quality,_,_,_,_,_,equipLoc,_,sell,classID,subclassID=pcall(get,link)
    if not ok or not readable(quality) or quality~=1 then return false end
    if not readable(classID) or (classID~=2 and classID~=4) then return false end
    if not readable(subclassID) or type(subclassID)~="number" then return false end
    if classID==2 and subclassID==20 then return false end -- fishing poles
    if classID==4 and subclassID==0 then return false end -- miscellaneous armor
    if not readable(equipLoc) or KEEP_SLOTS[equipLoc or ""] then return false end
    if not (readable(sell) and type(sell)=="number" and sell>0) then return false end
    if inEquipmentSet(itemID) then return false end
    if possibleUpgrade(link,equipLoc,classID,subclassID) then return false end
    return true
end
function Vendor:Sellable(info)
    if type(info)~="table" or info.hasNoValue or info.isLocked or not readable(info.quality) then return false end
    local poor=Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
    if info.quality==poor then return true end
    if self:Settings().sellWhite and info.quality==1 and readable(info.hyperlink) then return whiteGear(info.hyperlink,readable(info.itemID) and info.itemID or nil) end
    return false
end
-- Poor-quality items (and white gear, if chosen) in the bags, with their total vendor value.
function Vendor:Junk()
    local items,value={},0
    if not C_Container or not C_Container.GetContainerNumSlots then return items,value end
    local poor=Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
    for bag=0,(NUM_BAG_SLOTS or 4) do
        for slot=1,(call(C_Container.GetContainerNumSlots,bag) or 0) do
            local info=call(C_Container.GetContainerItemInfo,bag,slot)
            if self:Sellable(info) then
                local price=0
                local get=C_Item and C_Item.GetItemInfo or GetItemInfo
                if get and readable(info.hyperlink) then
                    local ok,_,_,_,_,_,_,_,_,_,_,sell=pcall(get,info.hyperlink)
                    if ok and readable(sell) and type(sell)=="number" then price=sell end
                end
                items[#items+1]={bag=bag,slot=slot,link=readable(info.quality) and info.quality==1 and info.hyperlink or nil}
                value=value+price*(readable(info.stackCount) and info.stackCount or 1)
            end
        end
    end
    return items,value
end
function Vendor:Sell()
    local items,value=self:Junk()
    if #items==0 then return end
    -- Sold one at a time like a right-click, so every item lands in the
    -- merchant's Buyback tab. (The game's Sell All Junk skips buyback.)
    -- Buyback keeps the last 12 items, as usual.
    if not C_Container or not C_Container.UseContainerItem then return end
    local index=0
    local function step()
        index=index+1
        local item=items[index]
        if not item or not self.merchantOpen or InCombatLockdown() then return end
        -- Check again: the item in that slot may have been moved meanwhile.
        local info=call(C_Container.GetContainerItemInfo,item.bag,item.slot)
        if self:Sellable(info) then
            pcall(C_Container.UseContainerItem,item.bag,item.slot)
        end
        C_Timer.After(.15,step)
    end
    step()
    -- Name the white gear that went, so anything you wanted back is easy to
    -- spot and buy back.
    local white={}
    for _,item in ipairs(items) do if item.link then white[#white+1]=item.link end end
    return #items,value,white
end
function Vendor:Repair()
    if not call(CanMerchantRepair) then return end
    local cost,canRepair=call(GetRepairAllCost)
    if type(cost)~="number" or cost<=0 or not canRepair then return end
    local s=self:Settings()
    if s.guildRepair and IsInGuild and call(IsInGuild) and call(CanGuildBankRepair) then
        local allowed=call(GetGuildBankWithdrawMoney)
        if type(allowed)=="number" and (allowed==-1 or allowed>=cost) then
            if pcall(RepairAllItems,true) then return cost,"guild" end
        end
    end
    local gold=call(GetMoney) or 0
    if gold<cost then return nil,nil,cost end
    if pcall(RepairAllItems) then return cost,"own" end
end
function Vendor:OnMerchant()
    local s=self:Settings()
    if (not s.autoSell and not s.autoRepair) or InCombatLockdown() then return end
    local parts={}
    if s.autoSell then
        local count,value,white=self:Sell()
        if count then
            parts[#parts+1]="Sold "..count..(s.sellWhite and " item" or " grey item")..(count==1 and "" or "s")..(value>0 and (" for "..money(value)) or "")
            if white and #white>0 then
                local shown={}; for i=1,math.min(#white,6) do shown[i]=white[i] end
                parts[#parts+1]="White gear: "..table.concat(shown," ")..(#white>6 and (" +"..(#white-6)) or "")
            end
        end
    end
    if s.autoRepair then
        local cost,source,short=self:Repair()
        if cost then parts[#parts+1]="Repaired for "..money(cost)..(source=="guild" and " (guild funds)" or "")
        elseif short then parts[#parts+1]="Not enough gold to repair ("..money(short)..")" end
    end
    if #parts>0 then
        local frame=DEFAULT_CHAT_FRAME or ChatFrame1
        if frame then frame:AddMessage("|cffffd100ForeverTools:|r "..table.concat(parts," · ")) end
    end
end
FT:RegisterModule("Vendor",Vendor)
local events=CreateFrame("Frame")
events:RegisterEvent("MERCHANT_SHOW"); events:RegisterEvent("MERCHANT_CLOSED")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    Vendor.merchantOpen=event=="MERCHANT_SHOW"
    -- Let the merchant window finish opening before acting.
    if event=="MERCHANT_SHOW" then C_Timer.After(.3,function() if Vendor.merchantOpen then Vendor:OnMerchant() end end) end
end)
