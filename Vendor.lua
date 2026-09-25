local _,FT=...
-- Merchant helpers (each opt-in, off by default): sell grey items and repair
-- when a merchant opens. They do what the merchant's own Sell All Junk and
-- Repair buttons do, never run in combat, and print one summary line.
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
-- Poor-quality items in the bags, with their total vendor value.
function Vendor:Junk()
    local items,value={},0
    if not C_Container or not C_Container.GetContainerNumSlots then return items,value end
    local poor=Enum and Enum.ItemQuality and Enum.ItemQuality.Poor or 0
    for bag=0,(NUM_BAG_SLOTS or 4) do
        for slot=1,(call(C_Container.GetContainerNumSlots,bag) or 0) do
            local info=call(C_Container.GetContainerItemInfo,bag,slot)
            if type(info)=="table" and readable(info.quality) and info.quality==poor and not info.hasNoValue and not info.isLocked then
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
    local native=C_MerchantFrame and C_MerchantFrame.SellAllJunkItems
    local enabled=C_MerchantFrame and call(C_MerchantFrame.IsSellAllJunkEnabled)
    if native and enabled then
        local ok=pcall(native)
        if ok then return #items,value end
    end
    -- Fallback when the client has no Sell All Junk: sell one item at a time
    -- while the merchant stays open.
    if not C_Container or not C_Container.UseContainerItem then return end
    local index=0
    local function step()
        index=index+1
        local item=items[index]
        if not item or not self.merchantOpen or InCombatLockdown() then return end
        pcall(C_Container.UseContainerItem,item.bag,item.slot)
        C_Timer.After(.2,step)
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
        if count then parts[#parts+1]="Sold "..count.." grey item"..(count==1 and "" or "s")..(value>0 and (" for "..money(value)) or "") end
    end
    if s.autoRepair then
        local cost,source,short=self:Repair()
        if cost then parts[#parts+1]="Repaired for "..money(cost)..(source=="guild" and " (guild funds)" or "")
        elseif short then parts[#parts+1]="Not enough gold to repair ("..money(short)..")" end
    end
    if #parts>0 then
        local frame=DEFAULT_CHAT_FRAME or ChatFrame1
        if frame then frame:AddMessage("|cffc9a0ffForeverTools:|r "..table.concat(parts," · ")) end
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
