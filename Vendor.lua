local _,FT=...
-- Merchant helpers (each opt-in, off by default): sell grey items and repair
-- when a merchant opens. Selling works like right-clicking each grey item (so
-- it can be bought back); repairing like the Repair button. Never in combat;
-- one summary line.
local Vendor={}
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
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
local function whiteGear(link,itemID)
    if itemID and TOOLS[itemID] then return false end
    local get=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return false end
    local ok,_,_,quality,_,_,_,_,_,equipLoc,_,sell,classID,subclassID=pcall(get,link)
    if not ok or not readable(quality) or quality~=1 then return false end
    if not readable(classID) or (classID~=2 and classID~=4) then return false end
    if classID==2 and subclassID==20 then return false end -- fishing poles
    if classID==4 and subclassID==0 then return false end -- miscellaneous armor
    if not readable(equipLoc) or KEEP_SLOTS[equipLoc or ""] then return false end
    return readable(sell) and type(sell)=="number" and sell>0
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
                items[#items+1]={bag=bag,slot=slot}
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
    return #items,value
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
        local count,value=self:Sell()
        if count then parts[#parts+1]="Sold "..count..(s.sellWhite and " item" or " grey item")..(count==1 and "" or "s")..(value>0 and (" for "..money(value)) or "") end
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
