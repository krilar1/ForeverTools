local _,FT=...
-- The "Bandage" macro (Macros > Generic): stop attacking, then bandage
-- yourself with the best bandage you carry.
--   * The macro lists the bandages in your bags, best first, so when the best
--     one runs out in a fight the next line takes over.
--   * Its icon and tooltip are the bandage it uses first.
--   * When your bags change, the macro you added is rewritten (out of combat).
--     A macro whose text you changed yourself is never touched.
--   * With no bandage in your bags it lists the standard ones by item, best
--     first, so it works the moment you get one.
local Bandage={}
local NAME="Bandage"
local LIMIT=255
-- Standard bandages with how good they are (higher is better). A bandage the
-- game calls a bandage but that is not listed here is ranked by its item level.
local KNOWN={[1251]=5,[2581]=10,[3530]=15,[3531]=20,[6450]=25,[6451]=30,[8544]=35,[8545]=40,
    [14529]=50,[14530]=58,[21990]=60,[21991]=70}
local ORDER={21991,21990,14530,14529,8545,8544,6451,6450,3531,3530,2581,1251}
-- Bandages that only work inside one battleground: never put in the macro.
local BATTLEGROUND={[19066]=true,[19067]=true,[19068]=true,[19307]=true,[20065]=true,[20066]=true,[20067]=true,
    [20232]=true,[20234]=true,[20235]=true,[20237]=true,[20243]=true,[20244]=true}
local CONSUMABLE,BANDAGE=0,7
local function plain(value) return not (issecretvalue and issecretvalue(value)) end
local function normalized(body) return type(body)=="string" and body:gsub("\r\n","\n"):gsub("\n+$","") or "" end
local function itemInfo(id)
    local get=(C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get then return end
    local ok,name,_,_,level=pcall(get,id)
    if not ok then return end
    if not plain(name) or type(name)~="string" or name=="" then name=nil end
    if not plain(level) or type(level)~="number" then level=nil end
    return name,level
end
-- Is this item a bandage, and how good? nil when it is not one.
function Bandage:Score(id)
    if BATTLEGROUND[id] then return nil end
    if KNOWN[id] then return KNOWN[id] end
    local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant then return nil end
    local ok,_,_,_,_,_,class,subclass=pcall(instant,id)
    if not ok or not plain(class) or not plain(subclass) then return nil end
    if class~=CONSUMABLE or subclass~=BANDAGE then return nil end
    local _,level=itemInfo(id)
    return level or 1
end
-- The bandages in your bags, best first: {id=, name=, score=}.
function Bandage:Carried()
    local list,seen={},{}
    if not C_Container or not C_Container.GetContainerNumSlots then return list end
    local function itemID(bag,slot)
        if C_Container.GetContainerItemID then
            local ok,id=pcall(C_Container.GetContainerItemID,bag,slot)
            if ok then return id end
        elseif C_Container.GetContainerItemInfo then
            local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
            if ok and type(info)=="table" then return info.itemID end
        end
    end
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local okCount,count=pcall(C_Container.GetContainerNumSlots,bag)
        if okCount and plain(count) and type(count)=="number" then
            for slot=1,count do
                local id=itemID(bag,slot)
                if plain(id) and type(id)=="number" and not seen[id] then
                    seen[id]=true
                    local score=self:Score(id)
                    if score then list[#list+1]={id=id,name=(itemInfo(id)),score=score} end
                end
            end
        end
    end
    table.sort(list,function(a,b) if a.score~=b.score then return a.score>b.score end return a.id>b.id end)
    return list
end
-- The macro text for what you carry right now.
function Bandage:Body()
    local carried=self:Carried()
    local lines
    if #carried>0 then
        local function ref(item) return item.name or ("item:"..item.id) end
        lines={"#showtooltip "..ref(carried[1]),"/stopattack"}
        for _,item in ipairs(carried) do lines[#lines+1]="/use [@player] "..ref(item) end
    else
        lines={"#showtooltip","/stopattack"}
        for _,id in ipairs(ORDER) do lines[#lines+1]="/use [@player] item:"..id end
    end
    -- Keep within the game's 255 characters: the weakest lines go first.
    local body=table.concat(lines,"\n")
    while #body>LIMIT and #lines>3 do lines[#lines]=nil; body=table.concat(lines,"\n") end
    return body
end
-- Still the text ForeverTools writes? Then it may be rewritten. Anything you
-- added or changed in the macro makes it yours.
function Bandage:Ours(body)
    local text=normalized(body)
    local count=0
    for line in (text.."\n"):gmatch("(.-)\n") do
        count=count+1
        if count==1 then if line:sub(1,12)~="#showtooltip" then return false end
        elseif count==2 then if line~="/stopattack" then return false end
        elseif line:sub(1,15)~="/use [@player] " then return false end
    end
    return count>=3
end
-- Rewrite the Bandage macros you added (General and Character) to match
-- your bags. Returns how many were changed.
function Bandage:Update()
    if not GetMacroIndexByName or not GetMacroInfo or not EditMacro or not GetNumMacros then return 0 end
    if (GetMacroIndexByName(NAME) or 0)==0 then return 0 end
    -- Not in a fight, and not while you have the game's macro window open.
    if InCombatLockdown() or (MacroFrame and MacroFrame.IsShown and MacroFrame:IsShown()) then self.pending=true; return 0 end
    self.pending=nil
    local body=self:Body()
    local account,character=GetNumMacros()
    local first=(MAX_ACCOUNT_MACROS or 120)+1
    local changed=0
    local function check(index)
        local name,_,existing=GetMacroInfo(index)
        if name==NAME and type(existing)=="string" and self:Ours(existing) and normalized(existing)~=body then
            if pcall(EditMacro,index,nil,nil,body) then changed=changed+1 end
        end
    end
    for index=1,(account or 0) do check(index) end
    for index=first,first+(character or 0)-1 do check(index) end
    return changed
end
FT:RegisterModule("Bandage",Bandage)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_ENABLED" and not Bandage.pending then return end
    -- One pass after a burst of bag changes (looting, crafting a stack).
    FT:Coalesce("bandageMacro",function() Bandage:Update() end,.5)
end)
