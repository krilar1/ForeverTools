local _,FT=...
-- Reagent reminder (Buff reminders > Your buffs > Reagents, off at first).
-- In a city or inn (while resting), a notice when you are low on a vendor
-- reagent one of your spells needs (Holy Candle, Ankh, Rune of Teleportation,
-- seeds, powders...), so you can buy more before you leave. Rogues are also
-- reminded about the poisons they use.
--   * Which reagents: read from the tooltip of each spell you know (the
--     "Reagents:" line), so it follows the game; spells whose tooltip can't
--     be read use the list below. Every reagent a spell lists counts (Forever
--     has its own, like Vanishing Powder), except Soul Shards.
--   * Reagent Economy (legacy talent: class abilities need no vendor
--     reagents): no reagent notices. Poisons still count (you still need them).
--   * "Low" is per reagent (Low amounts window), 0 = never remind.
--   * Cheap: the spells are read when they change, bags are counted after a
--     bag change, and only while you rest.
local R={}
local REAGENT_ECONOMY=1225503
local SOUL_SHARD=6265
-- Vendor reagents: item id = amount that counts as low.
local VENDOR={
    [17020]=10,  -- Arcane Powder (Arcane Brilliance)
    [17031]=5,   -- Rune of Teleportation
    [17032]=5,   -- Rune of Portals
    [17056]=10,  -- Light Feather (Slow Fall, Levitate)
    [17028]=10,  -- Holy Candle (Prayer of Fortitude)
    [17029]=10,  -- Sacred Candle (Prayer of Spirit / Shadow Protection)
    [17030]=3,   -- Ankh (Reincarnation)
    [17058]=5,   -- Fish Oil (Water Walking)
    [17057]=5,   -- Shiny Fish Scales (Water Breathing)
    [17033]=3,   -- Symbol of Divinity (Divine Intervention)
    [21177]=10,  -- Symbol of Kings (Greater Blessings)
    [17021]=10,  -- Wild Berries (Gift of the Wild)
    [17026]=10,  -- Wild Thornroot (Gift of the Wild)
    [17034]=3,[17035]=3,[17036]=3,[17037]=3,[17038]=3, -- Rebirth seeds
    [5140]=5,    -- Flash Powder (Vanish)
    [5530]=5,    -- Blinding Powder (Blind)
    [5565]=2,    -- Infernal Stone (Inferno)
    [16583]=2,   -- Demonic Figurine (Ritual of Doom)
}
R.VENDOR=VENDOR
-- Used only when a spell's tooltip can't be read. Spells whose reagent
-- changes with the rank (Rebirth, Gift of the Wild) are left out.
local BY_SPELL={
    ["Arcane Brilliance"]=17020,["Slow Fall"]=17056,["Levitate"]=17056,
    ["Prayer of Fortitude"]=17028,["Prayer of Spirit"]=17029,["Prayer of Shadow Protection"]=17029,
    ["Reincarnation"]=17030,["Water Walking"]=17058,["Water Breathing"]=17057,
    ["Divine Intervention"]=17033,["Vanish"]=5140,["Blind"]=5530,["Inferno"]=5565,["Ritual of Doom"]=16583,
}
local POISON_LOW=5
local POISON_FAMILIES={"Instant Poison","Deadly Poison","Crippling Poison","Mind-numbing Poison","Wound Poison"}
local function safe(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function call(fn,...) if type(fn)~="function" then return nil end local ok,a,b,c,d,e,f=pcall(fn,...); if ok then return a,b,c,d,e,f end end
local function text(v) if safe(v) and type(v)=="string" and v~="" then return v end end
local function itemName(id) return text(call(C_Item and C_Item.GetItemNameByID,id)) or text(call(GetItemInfo,id)) end
local function itemIcon(id)
    local icon=call(C_Item and C_Item.GetItemIconByID,id)
    if safe(icon) and icon then return icon end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end
-- Saved amounts: [item id or poison family]=n (0 = never).
function R:Low(key)
    local s=FT.modules.BuffReminder:Settings()
    local v=type(s.reagentLow)=="table" and tonumber(s.reagentLow[key])
    if v then return math.max(0,math.min(40,math.floor(v))) end
    return VENDOR[key] or 5
end
function R:SetLow(key,n)
    local s=FT.modules.BuffReminder:Settings()
    if type(s.reagentLow)~="table" then s.reagentLow={} end
    n=math.max(0,math.min(40,math.floor(tonumber(n) or 0)))
    local default=VENDOR[key] or 5
    s.reagentLow[key]=n~=default and n or nil
    self.counts=nil
end
-- Reagent Economy: no vendor reagents needed.
function R:Economy()
    for _,check in ipairs({IsPlayerSpell or false,IsSpellKnown or false,C_SpellBook and C_SpellBook.IsSpellKnown or false}) do
        if check then local ok,v=pcall(check,REAGENT_ECONOMY); if ok and safe(v) and v==true then return true end end
    end
    return false
end
-- The "Reagents:" label in the game's language.
local function reagentLabel()
    local label=text(SPELL_REAGENTS) or "Reagents: "
    label=label:gsub("|n",""):gsub("%%s",""):gsub(":%s*$","")
    return label
end
-- Reagent names in a spell's tooltip; nil when the tooltip can't be read.
function R:TooltipReagents(spellID)
    if not (C_TooltipInfo and C_TooltipInfo.GetSpellByID) or not safe(spellID) then return nil end
    local data=call(C_TooltipInfo.GetSpellByID,spellID)
    if not (safe(data) and type(data)=="table" and type(data.lines)=="table" and #data.lines>0) then return nil end
    local label=reagentLabel()
    local out={}
    for _,line in ipairs(data.lines) do
        local t=line and text(line.leftText)
        if t and t:sub(1,#label)==label then
            -- "Reagents:|nFlash Powder": the game's line break, colors, commas.
            t=t:sub(#label+1):gsub("|n",","):gsub("\n",","):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^:%s*","")
            for part in t:gmatch("[^,]+") do
                local name=part:gsub("%s*%(%d+%)%s*$",""):match("^%s*(.-)%s*$")
                if name~="" then out[#out+1]=name end
            end
        end
    end
    return out
end
-- Vendor reagent ids by name (names in the game's language).
function R:VendorNames()
    if self.vendorNames and self.vendorNamesFull then return self.vendorNames end
    local map,full={},true
    for id in pairs(VENDOR) do
        local n=itemName(id)
        if n then map[n]=id else full=false; call(C_Item and C_Item.RequestLoadItemDataByID,id) end
    end
    self.vendorNames,self.vendorNamesFull=map,full
    return map
end
-- Your bags: count and id by item name.
function R:Bags()
    local byName,byID={},{}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return byName,byID end
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local n=call(C_Container.GetContainerNumSlots,bag)
        for slot=1,(safe(n) and type(n)=="number" and n or 0) do
            local info=call(C_Container.GetContainerItemInfo,bag,slot)
            if safe(info) and type(info)=="table" and safe(info.itemID) and type(info.itemID)=="number" then
                local count=safe(info.stackCount) and tonumber(info.stackCount) or 1
                local name=text(info.itemName) or itemName(info.itemID)
                byID[info.itemID]=(byID[info.itemID] or 0)+count
                if name then local e=byName[name]; if not e then e={id=info.itemID,count=0}; byName[name]=e end; e.count=e.count+count end
            end
        end
    end
    return byName,byID
end
-- Soul Shards come from fighting, not from a vendor.
local function shardName() return itemName(SOUL_SHARD) or "Soul Shard" end
-- The vendor reagents your spells need: {[id]={id=,name=,spell=}}.
function R:Needed(learned,bagNames)
    if self.needed and self.neededFrom==learned then return self.needed end
    local vendorNames=self:VendorNames()
    local out={}
    for spellName,info in pairs(learned or {}) do
        local names=self:TooltipReagents(info.value)
        if names then
            for _,n in ipairs(names) do
                local id=vendorNames[n] or (bagNames[n] and bagNames[n].id)
                if not id then
                    local instant=call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant,n)
                    if safe(instant) and type(instant)=="number" then id=instant end
                end
                -- An item the game hasn't loaded and you don't carry: by name.
                local key=id or ("name:"..n)
                if id~=SOUL_SHARD and n~=shardName() and not out[key] then out[key]={id=id,key=key,name=n,spell=spellName} end
            end
        else
            local id=BY_SPELL[spellName]
            if id and not out[id] then out[id]={id=id,key=id,name=itemName(id) or "?",spell=spellName} end
        end
    end
    -- Kept until the spells change, or a reagent's name arrives late (an
    -- item the game hasn't loaded yet; one Forever doesn't have never does).
    self.needed,self.neededFrom=out,learned
    return out
end
-- Poison families this character has carried (remembered, so running out
-- completely still reminds).
function R:Poisons(bagNames)
    local guid=text(call(UnitGUID,"player")); if not guid then return {} end
    if type(FT.db.poisonsUsed)~="table" then FT.db.poisonsUsed={} end
    local used=FT.db.poisonsUsed[guid]; if type(used)~="table" then used={}; FT.db.poisonsUsed[guid]=used end
    local counts={}
    for name,e in pairs(bagNames) do
        for _,family in ipairs(POISON_FAMILIES) do
            if name==family or name:sub(1,#family+1)==family.." " then
                used[family]=true; counts[family]=(counts[family] or 0)+e.count
                counts[family.."#id"]=counts[family.."#id"] or e.id
            end
        end
    end
    local out={}
    for _,family in ipairs(POISON_FAMILIES) do
        if used[family] then out[#out+1]={key=family,name=family,count=counts[family] or 0,id=counts[family.."#id"]} end
    end
    return out
end
-- Everything to show in the Low amounts window, with counts.
function R:List(learned)
    local bagNames,bagIDs=self:Bags()
    local list={}
    local economy=self:Economy()
    if not economy then
        for key,e in pairs(self:Needed(learned,bagNames)) do
            local count=e.id and bagIDs[e.id] or (bagNames[e.name] and bagNames[e.name].count) or 0
            list[#list+1]={key=key,name=e.name,spell=e.spell,count=count,icon=e.id and itemIcon(e.id) or "Interface\\Icons\\INV_Misc_Dust_02"}
        end
    end
    local class=select(2,call(UnitClass,"player"))
    if class=="ROGUE" then
        for _,p in ipairs(self:Poisons(bagNames)) do
            list[#list+1]={key=p.key,name=p.name,spell="Poisons",count=p.count,icon=p.id and itemIcon(p.id) or "Interface\\Icons\\Ability_Poisons",poison=true}
        end
    end
    table.sort(list,function(a,b) if (a.poison and 1 or 0)~=(b.poison and 1 or 0) then return not a.poison end; return a.name<b.name end)
    return list,economy
end
-- Notices for the buff reminder: only while resting and not fighting.
function R:Notices(learned)
    local s=FT.modules.BuffReminder:Settings()
    if not s.reagents then return {} end
    local resting=call(IsResting); if not (safe(resting) and resting) then return {} end
    if not self.counts or self.countsFrom~=learned then
        local out={}
        for _,e in ipairs((self:List(learned))) do
            local low=self:Low(e.key)
            if low>0 and e.count<low then
                out[#out+1]={name=e.name,message="Low on "..e.name.." ("..e.count..")",spell={icon=e.icon},reagent=e.key}
            end
        end
        self.counts,self.countsFrom=out,learned
    end
    return self.counts
end
function R:Changed() self.counts=nil end
function R:SpellsChanged() self.needed=nil; self.counts=nil end
-- Low amounts window ----------------------------------------------------------
local ROW=36
function R:OpenAmounts()
    local Reminder=FT.modules.BuffReminder
    if not self.frame then
        local f=CreateFrame("Frame","ForeverToolsReagentAmounts",UIParent); self.frame=f
        f:SetSize(420,200); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
        FT:Panel(f); FT:AddClose(f,nil,10)
        if FT.TitleBand then FT:TitleBand(f) end
        f.title=FT:Label(f,"Low amounts",18,true); f.title:SetPoint("TOPLEFT",22,-18); f.title:SetTextColor(1,.82,0)
        f.none=FT:Label(f,"",13); f.none:SetPoint("TOPLEFT",22,-66); f.none:SetWidth(376); f.none:SetJustifyH("LEFT")
        if f.none.SetWordWrap then f.none:SetWordWrap(true) end
        f.rows={}
        tinsert(UISpecialFrames,"ForeverToolsReagentAmounts")
        f:SetPoint("LEFT",Reminder.frame or UIParent,Reminder.frame and "RIGHT" or "CENTER",8,0)
    end
    self:RefreshAmounts()
    self.frame:Show()
end
function R:RefreshAmounts()
    local f=self.frame; if not f then return end
    local Reminder=FT.modules.BuffReminder
    local list,economy=self:List(Reminder:Learned())
    for _,r in ipairs(f.rows) do r:Hide() end
    local y=62
    if economy then
        f.none:SetText("You have Reagent Economy: your spells need no vendor reagents, so there are no reagent reminders."..(#list>0 and " Poisons still count." or ""))
        f.none:Show(); y=y+(f.none:GetStringHeight() or 30)+12
    elseif #list==0 then
        f.none:SetText("None of the spells you know needs a vendor reagent yet."); f.none:Show(); y=y+40
    else f.none:Hide() end
    for i,e in ipairs(list) do
        local r=f.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,f); r:SetSize(376,ROW-4); f.rows[i]=r
            r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(26,26); r.icon:SetPoint("LEFT"); FT:RoundIcon(r.icon)
            r.name=FT:Label(r,"",12); r.name:SetPoint("TOPLEFT",r.icon,"TOPRIGHT",8,-1); r.name:SetWidth(170); r.name:SetJustifyH("LEFT")
            r.have=FT:Label(r,"",11); r.have:SetPoint("TOPLEFT",r.name,"BOTTOMLEFT",0,-2); r.have:SetWidth(170); r.have:SetJustifyH("LEFT"); r.have:SetTextColor(.66,.59,.48)
            for _,l in ipairs({r.name,r.have}) do if l.SetWordWrap then l:SetWordWrap(false) end end
            r.slider=CreateFrame("Slider",nil,r,"OptionsSliderTemplate"); r.slider:SetSize(110,16); r.slider:SetPoint("RIGHT",-60,0)
            r.slider:SetMinMaxValues(0,40); r.slider:SetValueStep(1); r.slider:SetObeyStepOnDrag(true)
            r.value=FT:Label(r,"",12); r.value:SetPoint("RIGHT",0,0); r.value:SetWidth(52); r.value:SetJustifyH("RIGHT")
            r.slider:SetScript("OnValueChanged",function(sl,v)
                if self.filling or not r.key then return end
                self:SetLow(r.key,v); r.value:SetText(math.floor(v+.5)==0 and "Off" or ("< "..math.floor(v+.5)))
                FT:Coalesce("reagentLow",function() if Reminder.Refresh then Reminder:Refresh() end end,.3)
            end)
            FT:Tooltip(r.slider,"Low amount","Remind when you have fewer than this. 0: never remind about this one.")
        end
        r.key=e.key
        r.icon:SetTexture(e.icon); r.name:SetText(e.name)
        r.have:SetText("You have "..e.count.."  ·  "..e.spell)
        self.filling=true; local low=self:Low(e.key); r.slider:SetValue(low); self.filling=false
        r.value:SetText(low==0 and "Off" or ("< "..low))
        r:ClearAllPoints(); r:SetPoint("TOPLEFT",22,-y); r:Show(); y=y+ROW
    end
    f:SetHeight(y+16)
end
-- /ft reagentdebug
function R:Debug()
    local Reminder=FT.modules.BuffReminder
    local learned=Reminder:Learned()
    print("|cffffd100ForeverTools reagents:|r Reagent Economy "..(self:Economy() and "yes" or "no").." (spell "..REAGENT_ECONOMY.."), resting "..tostring(call(IsResting)).." , switch "..tostring(Reminder:Settings().reagents))
    local n=0
    for name,info in pairs(learned) do
        local names=self:TooltipReagents(info.value)
        if names==nil and BY_SPELL[name] then print("  "..name..": tooltip unreadable, list says "..(itemName(BY_SPELL[name]) or BY_SPELL[name])); n=n+1
        elseif names and #names>0 then print("  "..name..": "..table.concat(names,", ")); n=n+1 end
    end
    if n==0 then print("  No known spell lists a reagent.") end
    for _,e in ipairs((self:List(learned))) do print("  "..e.name..": "..e.count.." (low under "..self:Low(e.key)..")") end
end
FT.Reagents=R
local events=CreateFrame("Frame")
events:RegisterEvent("SPELLS_CHANGED"); events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent",function(_,event,id)
    if event=="GET_ITEM_INFO_RECEIVED" then
        -- Only a vendor reagent's name coming in matters.
        if R.vendorNamesFull or not (safe(id) and VENDOR[id]) then return end
        R.vendorNames=nil
    end
    R:SpellsChanged()
end)
