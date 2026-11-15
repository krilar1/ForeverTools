local _,FT=...
-- Cure macros (Macros > Generic): one key per kind of cure instead of one
-- per item.
--   * Cure poison: your best anti-venom (or any item that cures poison).
--   * Cure all: an item that removes curses, diseases or magic (Purification
--     Potion, Restorative Potion...).
--   * Break free: an item that frees you from stuns and slows (Living
--     Action Potion, Free Action Potion).
-- Each macro uses the best such item in your bags: on the friend under your
-- mouse, a friendly target, or yourself (items that only work on you just
-- ignore the target). When your bags change the macros you added are
-- rewritten (out of combat), like the Bandage macro. A macro whose text you
-- changed yourself is never touched. No item in your bags: the standard
-- items are listed by ID, so it works the moment you get one.
-- Known items have a strength; an item the game describes as curing the same
-- thing (Forever adds its own) is found by its "Use:" text.
local Cures={}
local LIMIT=255
local TARGET="[@mouseover,help,nodead][help,nodead][@player]"
-- Higher is better. Anti-venoms cure poisons up to a level, so the strongest first.
local KINDS={
    {key="poison",name="Cure poison",icon="inv_drink_14",note="Uses your best item that cures poison (Anti-Venom, Strong and Powerful Anti-Venom...) on the friend under your mouse, your friendly target, or you. Kept up to date as your bags change.",
        known={[19440]=60,[6453]=35,[6452]=25}, words={"poison"}},
    {key="all",name="Cure all",icon="inv_potion_26",note="Uses your best item that removes curses, diseases or magic (Purification Potion, Restorative Potion...). Kept up to date as your bags change.",
        known={[13462]=50,[9030]=40}, words={"curse","disease","magic"}},
    {key="free",name="Break free",icon="inv_potion_04",note="Uses your best item that frees you from stuns and slows (Living Action Potion, Free Action Potion). Kept up to date as your bags change.",
        known={[20008]=60,[5634]=40}, words={"stun","movement"}},
}
Cures.kinds=KINDS
local byName={}
for _,kind in ipairs(KINDS) do byName[kind.name]=kind end
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
-- The item's "Use:" text, lower case (cached: items don't change).
local useText={}
local function useLine(id)
    local cached=useText[id]
    if cached~=nil then return cached or nil end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
    local ok,data=pcall(C_TooltipInfo.GetItemByID,id)
    if not ok or not plain(data) or type(data)~="table" or type(data.lines)~="table" then return nil end
    local found=false
    for _,line in ipairs(data.lines) do
        local text=type(line)=="table" and line.leftText
        if plain(text) and type(text)=="string" and text:find("^Use:") then found=text:lower(); break end
    end
    -- Item data not loaded yet: ask again later.
    if found or #data.lines>1 then useText[id]=found end
    return found or nil
end
Cures.UseLine=useLine
-- Which kind of cure an item is, and how good: kindKey, score (or nil).
function Cures:Classify(id)
    for _,kind in ipairs(KINDS) do if kind.known[id] then return kind.key,kind.known[id] end end
    local text=useLine(id); if not text then return nil end
    local _,level=itemInfo(id); level=level or 1
    local removes=text:find("cure") or text:find("remov")
    if text:find("stun") and (text:find("movement") or text:find("immun") or removes) then return "free",level end
    if not removes then return nil end
    local poison=text:find("poison")
    local other=text:find("curse") or text:find("disease") or text:find("magic")
    if other then return "all",level end
    if poison then return "poison",level end
end
-- What you carry, per kind, best first: {poison={{id,name,score}},...}.
function Cures:Carried()
    local out={poison={},all={},free={}}
    if not C_Container or not C_Container.GetContainerNumSlots then return out end
    local seen={}
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local okCount,count=pcall(C_Container.GetContainerNumSlots,bag)
        if okCount and plain(count) and type(count)=="number" then
            for slot=1,count do
                local okId,id=pcall(C_Container.GetContainerItemID,bag,slot)
                if okId and plain(id) and type(id)=="number" and not seen[id] then
                    seen[id]=true
                    local key,score=self:Classify(id)
                    if key then local list=out[key]; list[#list+1]={id=id,name=(itemInfo(id)),score=score} end
                end
            end
        end
    end
    for _,list in pairs(out) do table.sort(list,function(a,b) if a.score~=b.score then return a.score>b.score end return a.id>b.id end) end
    return out
end
-- The macro text for one kind: the best item you carry (one /use line, so
-- two cures never go off at once). None carried: the standard items by ID.
function Cures:Body(kindKey)
    local kind; for _,k in ipairs(KINDS) do if k.key==kindKey then kind=k end end
    if not kind then return "#showtooltip" end
    local best=self:Carried()[kindKey][1]
    local lines
    if best then
        local ref=best.name or ("item:"..best.id)
        lines={"#showtooltip "..ref,"/use "..TARGET.." "..ref}
    else
        local ids={}; for id in pairs(kind.known) do ids[#ids+1]=id end
        table.sort(ids,function(a,b) return kind.known[a]>kind.known[b] end)
        lines={"#showtooltip"}
        for _,id in ipairs(ids) do lines[#lines+1]="/use "..TARGET.." item:"..id end
    end
    local body=table.concat(lines,"\n")
    while #body>LIMIT and #lines>2 do lines[#lines]=nil; body=table.concat(lines,"\n") end
    return body
end
-- Still the text ForeverTools writes? Anything you added makes it yours.
function Cures:Ours(body)
    local text=normalized(body)
    local count=0
    local prefix="/use "..TARGET.." "
    for line in (text.."\n"):gmatch("(.-)\n") do
        count=count+1
        if count==1 then if line:sub(1,12)~="#showtooltip" then return false end
        elseif line:sub(1,#prefix)~=prefix then return false end
    end
    return count>=2
end
-- Rewrite the cure macros you added to match your bags.
function Cures:Update()
    if not GetMacroInfo or not EditMacro or not GetNumMacros then return 0 end
    if InCombatLockdown() then self.pending=true; return 0 end
    self.pending=nil
    local changed=0
    local ours=function(body) return self:Ours(body) end
    for _,kind in ipairs(KINDS) do
        if #FT:FollowedMacros(kind.name,ours)>0 then changed=changed+FT:UpdateFollowed(kind.name,ours,self:Body(kind.key)) end
    end
    return changed
end
function Cures:Kind(name) return byName[name] end
-- Is that cure macro in your macros (under any name)?
function Cures:Installed(name)
    if not byName[name] then return false end
    return #FT:FollowedMacros(name,function(body) return self:Ours(body) end)>0
end
FT:RegisterModule("Cures",Cures)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_REGEN_ENABLED","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_ENABLED" and not Cures.pending then return end
    FT:Coalesce("cureMacros",function() Cures:Update() end,.5)
end)
