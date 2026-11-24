local _,FT=...
-- Grenade macro (Macros > Generic > Grenade): throws your grenade where your
-- mouse points (/use [@cursor]). Which grenade:
--   * one kind in your bags: that one;
--   * several kinds: you pick;
--   * none: you pick from the grenades used in PvP, and the macro works as
--     soon as you carry it.
-- The pick is kept per character; /ft grenade changes it and updates the
-- macro. Grenades are found by the game's own item type (Explosives with a
-- Use effect), so WoW: Forever's new ones count too.
local G={}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local NAME="Grenade"
-- The usual PvP grenades and bombs (Classic items, also in WoW: Forever).
local PVP={
    {4390,"Iron Grenade","Stuns for 3 sec in 3 yards."},
    {4394,"Big Iron Bomb","Stuns for 3 sec in 5 yards."},
    {15993,"Thorium Grenade","Stuns for 3 sec in 3 yards. Can be thrown while moving."},
    {16005,"Dark Iron Bomb","Stuns for 4 sec in 5 yards."},
    {10562,"Hi-Explosive Bomb","Stuns for 3 sec in 3 yards."},
    {10586,"The Big One","Stuns for 5 sec in a large area."},
    {16040,"Arcane Bomb","Silences for 5 sec and drains mana."},
    {4380,"Big Bronze Bomb","Stuns for 2 sec in 5 yards."},
}
local KNOWN={}; for _,g in ipairs(PVP) do KNOWN[g[1]]=g end
local function guid() local g=UnitGUID and UnitGUID("player"); return plain(g) and type(g)=="string" and g or "?" end
function G:Choice()
    local t=type(FT.db.grenadeChoice)=="table" and FT.db.grenadeChoice
    local id=t and t[guid()]
    return type(id)=="number" and id or nil
end
function G:SetChoice(id)
    if type(FT.db.grenadeChoice)~="table" then FT.db.grenadeChoice={} end
    FT.db.grenadeChoice[guid()]=id
end
-- Is this item a grenade? Explosives (trade goods, subclass 2) that do
-- something when used, or one of the known ones.
local function isGrenade(id)
    if KNOWN[id] then return true end
    local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not instant then return false end
    local ok,_,_,_,_,_,classID,subclassID=pcall(instant,id)
    if not ok or not plain(classID) or classID~=7 or subclassID~=2 then return false end
    local spell=(C_Item and C_Item.GetItemSpell) or GetItemSpell
    local okS,name=pcall(spell,id)
    return okS and plain(name) and name~=nil
end
-- Grenade kinds in your bags: {id=,name=,link=,count=} in bag order.
function G:Carried()
    local out,seen={},{}
    if not (C_Container and C_Container.GetContainerNumSlots) then return out end
    for bag=0,(tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or tonumber(NUM_BAG_SLOTS) or 4) do
        local okN,slots=pcall(C_Container.GetContainerNumSlots,bag)
        for slot=1,(okN and plain(slots) and type(slots)=="number" and slots or 0) do
            local ok,info=pcall(C_Container.GetContainerItemInfo,bag,slot)
            local id=ok and type(info)=="table" and plain(info.itemID) and info.itemID
            if id and not seen[id] and isGrenade(id) then
                seen[id]=true
                out[#out+1]={id=id,name=plain(info.itemName) and info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]")) or ("Item "..id),link=info.hyperlink}
            end
        end
    end
    return out
end
-- The item the macro throws.
function G:Pick()
    local choice=self:Choice()
    if choice then return choice end
    local carried=self:Carried()
    if carried[1] then return carried[1].id end
    return PVP[1][1]
end
-- How it's thrown: the game's targeting circle (default; you click where it
-- lands) or straight at your mouse ([@cursor]).
G.AIMS={{"circle","Targeting circle","Click where it lands, as when you use it from your bags."},{"cursor","Where your mouse points","Lands at your mouse right away, no circle."}}
function G:Aim() return FT.db.grenadeAim=="cursor" and "cursor" or "circle" end
function G:Body()
    local id=self:Pick()
    return "#showtooltip item:"..id.."\n/use "..(self:Aim()=="cursor" and "[@cursor] " or "").."item:"..id
end
function G:Ours(body)
    return type(body)=="string" and body:find("^#showtooltip item:%d+%s*\n/use [^\n]*item:%d+%s*$")~=nil
end
function G:Installed()
    return FT.FollowedMacros and #FT:FollowedMacros(NAME,function(body) return self:Ours(body) end)>0 or false
end
function G:Update()
    if InCombatLockdown() or not FT.FollowedMacros then return end
    local ours=function(body) return self:Ours(body) end
    if #FT:FollowedMacros(NAME,ours)>0 then FT:UpdateFollowed(NAME,ours,self:Body()) end
end
-- Before the macro is added (MacroForge entry.prepare): true = go ahead,
-- false = we asked; go() adds it after the answer.
function G:Prepare(go)
    if self:Choice() then return true end
    local carried=self:Carried()
    if #carried==1 then self:SetChoice(carried[1].id); return true end
    self:Open(go)
    return false
end
-- The question: a small window with a list (hover: the game's tooltip).
local function choices(carried)
    local list={}
    if #carried>0 then
        for _,c in ipairs(carried) do
            local k=KNOWN[c.id]
            list[#list+1]={value=c.id,label=c.name,icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(c.id) or nil,hyperlink=c.link or ("item:"..c.id),tooltip=k and k[3] or "In your bags."}
        end
    else
        for _,g in ipairs(PVP) do
            list[#list+1]={value=g[1],label=g[2],icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(g[1]) or nil,hyperlink="item:"..g[1],tooltip=g[3]}
        end
    end
    return list
end
function G:Open(go)
    if InCombatLockdown() then FT:Toast("Grenades can be picked after the fight.",3); return end
    local carried=self:Carried()
    if not self.frame then
        local f=CreateFrame("Frame","ForeverToolsGrenadePick",UIParent); self.frame=f
        f:SetSize(420,206); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
        FT:Panel(f); FT:AddClose(f,function() f:Hide() end,10)
        if FT.TitleBand then FT:TitleBand(f) end
        f.title=FT:Label(f,"Grenade macro",18,true); f.title:SetPoint("TOPLEFT",22,-18); f.title:SetTextColor(1,.82,0)
        f.text=FT:Label(f,"",13); f.text:SetPoint("TOPLEFT",22,-60); f.text:SetWidth(376); f.text:SetJustifyH("LEFT")
        if f.text.SetWordWrap then f.text:SetWordWrap(true) end
        f.drop=FT:Dropdown(f,376,function() return choices(G.frameCarried or {}) end,function(value)
            G.picked=value
            for _,c in ipairs(choices(G.frameCarried or {})) do if c.value==value then f.drop.label:SetText(c.label); if f.drop.icon and c.icon then f.drop.icon:SetTexture(c.icon) end end end
        end,"generic")
        f.drop.menuWidth=376
        f.drop:HookScript("OnEnter",function(owner)
            if not G.picked then return end
            GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
            if pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..G.picked) then GameTooltip:Show() end
        end)
        f.drop:HookScript("OnLeave",function() GameTooltip:Hide() end)
        f.aimLabel=FT:Label(f,"Throw with",13); f.aimLabel:SetTextColor(.66,.59,.48)
        f.aim=FT:Dropdown(f,376,function() local out={} for _,a in ipairs(G.AIMS) do out[#out+1]={value=a[1],label=a[2],tooltip=a[3]} end return out end,function(value)
            G.aimPicked=value
            for _,a in ipairs(G.AIMS) do if a[1]==value then f.aim.label:SetText(a[2]) end end
        end,"generic")
        f.aim.menuWidth=376
        f.add=FT:AccentButton(f,"Use this grenade",200,32,"confirm")
        f.add:SetScript("OnClick",function()
            if not G.picked then return end
            G:SetChoice(G.picked); FT.db.grenadeAim=G.aimPicked=="cursor" and "cursor" or nil; f:Hide()
            local after=G.after; G.after=nil
            if after then after() else G:Update(); FT:Toast("Grenade macro updated.",3) end
        end)
        f.cancel=FT:QuietButton(f,"Cancel",160,32,"reset")
        f.cancel:SetScript("OnClick",function() G.after=nil; f:Hide() end)
        f:SetPoint("TOP",UIParent,"TOP",0,-180)
        tinsert(UISpecialFrames,"ForeverToolsGrenadePick")
        f:Hide()
    end
    local f=self.frame
    self.after=go; self.frameCarried=carried
    if #carried>1 then f.text:SetText("You have several grenades. Which one should the macro throw?")
    elseif #carried==1 then f.text:SetText("Which grenade should the macro throw?")
    else f.text:SetText("No grenades in your bags. Pick one; the macro works as soon as you carry it.") end
    local list=choices(carried)
    local current=self:Choice()
    local first=list[1]
    for _,c in ipairs(list) do if c.value==current then first=c end end
    self.picked=first and first.value
    f.drop.label:SetText(first and first.label or ""); if f.drop.icon and first and first.icon then f.drop.icon:SetTexture(first.icon) end
    self.aimPicked=self:Aim()
    for _,a in ipairs(self.AIMS) do if a[1]==self.aimPicked then f.aim.label:SetText(a[2]) end end
    local y=60+(f.text:GetStringHeight() or 16)+14
    f.drop:ClearAllPoints(); f.drop:SetPoint("TOPLEFT",22,-y)
    f.aimLabel:ClearAllPoints(); f.aimLabel:SetPoint("TOPLEFT",22,-y-44)
    f.aim:ClearAllPoints(); f.aim:SetPoint("TOPLEFT",22,-y-64)
    f.add:ClearAllPoints(); f.add:SetPoint("TOPLEFT",22,-y-112)
    f.cancel:ClearAllPoints(); f.cancel:SetPoint("LEFT",f.add,"RIGHT",16,0)
    f:SetHeight(y+112+52)
    f:Show()
end
FT:RegisterModule("Grenades",G)
local events=CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent",function()
    if not FT.dbReady or not FT.Coalesce then return end
    FT:Coalesce("grenadeMacro",function() G:Update() end,1)
end)
