local _,FT=...
-- Macro updates (Macro settings > Update macros: Ask, Automatically, Off).
-- While leveling you often get a better poison or mana gem, or a new weapon,
-- and your macros still name the old one. ForeverTools notices and asks.
--   * Poisons and mana gems: a better version in your bags (or spellbook)
--     than one a macro names. "Instant Poison III is in your bags. Update 2
--     macros?" Update / Not now / Always. Every macro counts, your own too:
--     the old name is swapped for the new one (whole names only: "Instant
--     Poison" never matches inside "Instant Poison II"). Asked once per new
--     version, never to go back to an older one.
--   * Weapons: macros with swap lines (/equipslot 16 <weapon>) are grouped
--     by what they equip (Sinister Strike: sword in the main hand, dagger in
--     the off hand; Backstab and Ambush: the other way round). When you equip
--     a weapon none of them uses in place of one they use, a window shows
--     each group with a main hand and an off hand choice, the new weapon put
--     in wherever the old one was. Update changes them all at once. Asked
--     once per new weapon; /ft weaponswap opens it any time.
--   * Never in a fight (macros can't change then): it waits until after.
local W={}
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function call(fn,...) if type(fn)~="function" then return nil end local ok,a,b,c,d,e,f,g=pcall(fn,...); if ok then return a,b,c,d,e,f,g end end
local function busy() return InCombatLockdown and InCombatLockdown() end
local function MF() return FT.modules.MacroForge end
function W:Mode()
    local m=FT.db and FT.db.macroUpdates
    if m~="auto" and m~="off" then m="ask" end
    return m
end
local function guid() local g=call(UnitGUID,"player"); return plain(g) and type(g)=="string" and g or "?" end
local function charStore(key)
    if type(FT.db[key])~="table" then FT.db[key]={} end
    local g=guid(); if type(FT.db[key][g])~="table" then FT.db[key][g]={} end
    return FT.db[key][g]
end
-- Every macro: {index=, body=}.
function W:Macros()
    local out={}
    if not (GetNumMacros and GetMacroInfo) then return out end
    local account,character=call(GetNumMacros)
    local first=(MAX_ACCOUNT_MACROS or 120)+1
    local function add(i)
        local name,_,body=call(GetMacroInfo,i)
        if plain(body) and type(body)=="string" then out[#out+1]={index=i,name=plain(name) and name or "",body=body} end
    end
    for i=1,(plain(account) and account or 0) do add(i) end
    for i=first,first+(plain(character) and character or 0)-1 do add(i) end
    return out
end
-- Whole-name matching: letters, digits and apostrophes are part of a name,
-- and so is a rank like " II" after it.
local function wordChar(c) return c~=nil and c~="" and c:match("[%w']")~=nil end
local function rankAfter(rest)
    local roman=rest:match("^ ([IVX]+)")
    return roman and not wordChar(rest:sub(#roman+2,#roman+2))
end
local function findWhole(text,name,from)
    local i=from or 1
    while true do
        local s,e=text:find(name,i,true)
        if not s then return nil end
        local rest=text:sub(e+1)
        if not wordChar(text:sub(s-1,s-1)) and not wordChar(rest:sub(1,1)) and not rankAfter(rest) then return s,e end
        i=e+1
    end
end
W.FindWhole=findWhole
local function replaceWhole(text,old,new)
    local out,i,n={},1,0
    while true do
        local s,e=findWhole(text,old,i)
        if not s then break end
        out[#out+1]=text:sub(i,s-1); out[#out+1]=new; i=e+1; n=n+1
    end
    out[#out+1]=text:sub(i)
    return table.concat(out),n
end
W.ReplaceWhole=replaceWhole
local function edit(index,expected,new)
    if busy() or not EditMacro then return false end
    local _,_,now=call(GetMacroInfo,index)
    if now~=expected then return false end -- changed meanwhile
    local ok=pcall(EditMacro,index,nil,nil,new)
    return ok
end
-- Poisons and mana gems --------------------------------------------------------
-- What could change now: {fam=, new=, rank=, olds={...}, macros={{index,body,new}}}
function W:FamilyChanges()
    local mf=MF(); if not (mf and mf.FAMILIES) then return {} end
    local list=self:Macros()
    local out={}
    for _,fam in ipairs(mf.FAMILIES) do
        local best,bestRank=mf:FamilyBest(fam)
        if best and bestRank and bestRank>1 then
            local change={fam=fam,new=best,rank=bestRank,olds={},macros={}}
            for _,m in ipairs(list) do
                local body,used=m.body,false
                for r=bestRank-1,1,-1 do
                    local old=fam.members[r]
                    if findWhole(body,old) then
                        body=replaceWhole(body,old,best); used=true
                        local seen=false; for _,o in ipairs(change.olds) do if o==old then seen=true end end
                        if not seen then change.olds[#change.olds+1]=old end
                    end
                end
                if used then change.macros[#change.macros+1]={index=m.index,body=m.body,new=body} end
            end
            if #change.macros>0 then out[#out+1]=change end
        end
    end
    return out
end
function W:ApplyFamily(change)
    local n=0
    for _,m in ipairs(change.macros) do if edit(m.index,m.body,m.new) then n=n+1 end end
    -- An earlier version picked in the macro editor gives way to the new one.
    if type(FT.db.macroFamilyPick)=="table" then FT.db.macroFamilyPick[change.fam.head]=nil end
    if n>0 then FT:Toast(n.." macro"..(n==1 and "" or "s").." now use "..change.new..".",4) end
    local mf=MF(); if mf and mf.frame and mf.frame:IsShown() and mf.UpdatePreview then pcall(mf.UpdatePreview,mf) end
    return n
end
function W:CheckFamilies()
    if not FT.dbReady or self:Mode()=="off" then return end
    if busy() then self.pending=true; return end
    local seen=charStore("macroFamilySeen")
    for _,change in ipairs(self:FamilyChanges()) do
        local head=change.fam.head
        -- Asked once per new version (any answer).
        if (tonumber(seen[head]) or 0)<change.rank then
            if self:Mode()=="auto" or FT.db.macroFamilyAuto==true then
                seen[head]=change.rank; self:ApplyFamily(change)
            elseif not self.asking then
                self:AskFamily(change,function() seen[head]=change.rank end)
                return
            end
        end
    end
end
function W:AskFamily(change,answered)
    self.asking=change
    StaticPopupDialogs.FOREVERTOOLS_MACRO_FAMILY=StaticPopupDialogs.FOREVERTOOLS_MACRO_FAMILY or {
        button1="Update",button2="Not now",button3="Always",timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnAccept=function() local c=W.asking; W.asking=nil; if W.answered then W.answered() end; if c then W:ApplyFamily(c) end; W:Next() end,
        OnCancel=function() W.asking=nil; if W.answered then W.answered() end; W:Next() end,
        OnAlt=function() local c=W.asking; W.asking=nil; FT.db.macroFamilyAuto=true; if W.answered then W.answered() end; if c then W:ApplyFamily(c) end; W:Next() end,
    }
    self.answered=answered
    local n=#change.macros
    StaticPopupDialogs.FOREVERTOOLS_MACRO_FAMILY.text="|cffffd100"..change.new.."|r is "..(change.fam.kind=="item" and "in your bags" or "learned")..".\n\nUpdate "..n.." macro"..(n==1 and "" or "s").." that use "..table.concat(change.olds,", ").."?\n\n|cffa8967aAlways: update by itself from now on.|r"
    if not FT:ShowPopup("FOREVERTOOLS_MACRO_FAMILY") then self.asking=nil; self.pending=true end
end
-- After one answer, the next family (or a pending weapon question).
function W:Next()
    if FT.Coalesce then FT:Coalesce("macroWatchNext",function() W:CheckFamilies(); W:CheckWeapons() end,.5) end
end
-- Weapons -----------------------------------------------------------------------
local HANDS={16,17,18}
local HAND_NAMES={[16]="Main hand",[17]="Off hand",[18]="Ranged"}
local function wornName(slot)
    local link=call(GetInventoryItemLink,"player",slot)
    return plain(link) and type(link)=="string" and link:match("%[(.-)%]") or nil
end
-- Kind of weapon, so a new dagger replaces a dagger and a new sword a sword
-- or mace: dagger, fishing pole, ranged, two-hand, one-hand. nil if unknown.
function W:Kind(item)
    local instant=(C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _,_,_,equipLoc,_,classID,subclassID=call(instant,item)
    if not plain(equipLoc) or type(equipLoc)~="string" or equipLoc=="" then return nil end
    if plain(subclassID) and subclassID==15 then return "dagger" end
    if plain(subclassID) and subclassID==20 then return "fishing" end
    if equipLoc=="INVTYPE_RANGED" or equipLoc=="INVTYPE_RANGEDRIGHT" or equipLoc=="INVTYPE_THROWN" then return "ranged" end
    if equipLoc=="INVTYPE_2HWEAPON" then return "twohand" end
    if equipLoc=="INVTYPE_SHIELD" or equipLoc=="INVTYPE_HOLDABLE" then return "offhand" end
    return "onehand"
end
-- Macros grouped by what they equip: {key=, slots={[16]=name,...}, order={16,17}, macros={...}, spells={...}}
function W:Sets()
    local sets,byKey={},{}
    for _,m in ipairs(self:Macros()) do
        local slots,order={}, {}
        for row in (m.body:gsub("\r\n","\n").."\n"):gmatch("(.-)\n") do
            local n,name=row:match("^/equipslot%s+(%d+)%s+(.-)%s*$")
            n=tonumber(n)
            if n and (n==16 or n==17 or n==18) and name~="" and not slots[n] then slots[n]=(name:gsub('^"(.*)"$',"%1")); order[#order+1]=n end
        end
        if #order>0 then
            local parts={}; for _,n in ipairs(HANDS) do if slots[n] then parts[#parts+1]=n.."="..slots[n] end end
            local key=table.concat(parts,"|")
            local set=byKey[key]
            if not set then set={key=key,slots=slots,order={},macros={},spells={}}; for _,n in ipairs(HANDS) do if slots[n] then set.order[#set.order+1]=n end end; byKey[key]=set; sets[#sets+1]=set end
            set.macros[#set.macros+1]=m
            local spell=m.body:match("#showtooltip ([^\n\r]+)")
            if not spell then local c=m.body:match("/cast ([^\n\r]+)"); spell=c and c:gsub("%b[]",""):match("^%s*([^;]-)%s*$") end
            if not spell or spell=="" then spell=m.name~="" and m.name or "Macro" end
            spell=spell:gsub("%s+$","")
            local dup=false; for _,sp in ipairs(set.spells) do if sp==spell then dup=true end end
            if not dup then set.spells[#set.spells+1]=spell end
        end
    end
    return sets
end
function W:Referenced(sets)
    local out={}
    for _,set in ipairs(sets or self:Sets()) do for _,name in pairs(set.slots) do out[name]=true end end
    return out
end
-- Remember what each hand wears (only out of fights: swap macros change it all the time).
function W:ReadWorn() self.worn={}; for _,s in ipairs(HANDS) do self.worn[s]=wornName(s) end end
function W:CheckWeapons()
    if not FT.dbReady or self:Mode()=="off" then return end
    if busy() then self.pending=true; return end
    if not self.worn then self:ReadWorn(); return end
    local before=self.worn; self:ReadWorn()
    if self.asking or (self.swapFrame and self.swapFrame:IsShown()) then return end
    local sets=self:Sets(); if #sets==0 then return end
    local used=self:Referenced(sets)
    local asked=charStore("macroWeaponAsked")
    for _,slot in ipairs(HANDS) do
        local new,old=self.worn[slot],before[slot]
        if new and new~=old and not used[new] and not asked[new] then
            -- Which weapon it takes the place of: the one it replaced, if the
            -- macros use it and it's the same kind; else the only one of its kind.
            local kind=self:Kind(new)
            local function same(name) local k=self:Kind(name); return not kind or not k or k==kind end
            local replaces
            if old and used[old] and same(old) then replaces=old
            else
                local found={}
                for name in pairs(used) do if same(name) and name~=new then found[#found+1]=name end end
                if #found==1 then replaces=found[1] end
            end
            if replaces and kind~="fishing" then
                asked[new]=true
                local touched={}
                for _,set in ipairs(sets) do for _,name in pairs(set.slots) do if name==replaces then touched[#touched+1]=set; break end end end
                if self:Mode()=="auto" then
                    local choice={}
                    for _,set in ipairs(touched) do choice[set.key]={}; for s,name in pairs(set.slots) do choice[set.key][s]=name==replaces and new or name end end
                    self:ApplySwaps(touched,choice)
                else self:OpenSwap(touched,replaces,new) end
                return
            end
        end
    end
end
-- Rewrite the /equipslot lines of every macro in these groups.
function W:ApplySwaps(sets,choice)
    if busy() then FT:Toast("Macros can't change in a fight. Try again after it.",4); return 0 end
    local n=0
    for _,set in ipairs(sets) do
        local want=choice[set.key] or {}
        for _,m in ipairs(set.macros) do
            local rows,changed={},false
            for row in (m.body:gsub("\r\n","\n").."\n"):gmatch("(.-)\n") do
                local num,name=row:match("^/equipslot%s+(%d+)%s+(.-)%s*$")
                num=tonumber(num)
                local pick=num and want[num]
                if pick~=nil and pick~=(name and name:gsub('^"(.*)"$',"%1")) then
                    changed=true
                    if pick~="" then rows[#rows+1]="/equipslot "..num.." "..pick end
                else rows[#rows+1]=row end
            end
            while rows[#rows]=="" do rows[#rows]=nil end
            if changed and edit(m.index,m.body,table.concat(rows,"\n")) then n=n+1 end
        end
    end
    if n>0 then FT:Toast(n.." weapon swap macro"..(n==1 and "" or "s").." updated.",4) end
    return n
end
-- The window: one block per group, a choice per hand.
local WIDTH=460
function W:BuildSwap()
    local f=CreateFrame("Frame","ForeverToolsWeaponSwap",UIParent); self.swapFrame=f
    f:SetSize(WIDTH,240); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
    FT:Panel(f); FT:AddClose(f,function() f:Hide() end,10)
    if FT.TitleBand then FT:TitleBand(f) end
    f.title=FT:Label(f,"Update weapon swaps",18,true); f.title:SetPoint("TOPLEFT",22,-18); f.title:SetTextColor(1,.82,0)
    f.text=FT:Label(f,"",13); f.text:SetPoint("TOPLEFT",22,-60); f.text:SetWidth(WIDTH-44); f.text:SetJustifyH("LEFT")
    if f.text.SetWordWrap then f.text:SetWordWrap(true) end
    f.blocks={}
    f.update=FT:AccentButton(f,"Update macros",200,32,"confirm")
    f.update:SetScript("OnClick",function() local n=self:ApplySwaps(self.swapSets or {},self.swapChoice or {}); if n>=0 then f:Hide() end end)
    FT:Tooltip(f.update,"Update macros","Change the swap lines of these macros to what is picked above.")
    f.later=FT:QuietButton(f,"Not now",200,32,"reset")
    f.later:SetScript("OnClick",function() f:Hide() end)
    FT:Tooltip(f.later,"Not now","Leave the macros as they are. /ft weaponswap opens this again.")
    f:SetPoint("TOP",UIParent,"TOP",0,-160)
    f:SetScript("OnHide",function() if FT.choiceMenu then FT.choiceMenu:Hide() end; W:Next() end)
    tinsert(UISpecialFrames,"ForeverToolsWeaponSwap")
    f:Hide()
end
local function itemLabel(name)
    if not name or name=="" then return "|cffa8967aNone (no swap)|r" end
    local mf=MF()
    return mf and mf.ColoredItem and mf:ColoredItem(name,mf:EquipQuality(16,name)) or name
end
function W:SetIcon(drop,slot,name)
    if not drop.icon then return end
    local mf=MF()
    local icon=mf and mf.EquipIcon and mf:EquipIcon(slot,name)
    drop.icon:SetTexture(icon or (slot==17 and "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" or "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand"))
end
function W:OpenSwap(sets,old,new)
    if busy() then FT:Toast("Weapon swaps can be changed after the fight.",3); return end
    sets=sets or self:Sets()
    if not self.swapFrame then self:BuildSwap() end
    local f=self.swapFrame
    self.swapSets=sets; self.swapChoice={}
    if #sets==0 then
        f.text:SetText("None of your macros swaps weapons yet. Add a swap in the macro editor (Weapon swap), then come back here.")
    elseif new then
        f.text:SetText("You equipped "..itemLabel(new).." in place of "..itemLabel(old)..". Pick what each of these macros puts in your hands.")
    else
        f.text:SetText("Pick what each of these macros puts in your hands.")
    end
    for _,b in ipairs(f.blocks) do b:Hide() end
    local y=60+(f.text:GetStringHeight() or 30)+14
    for i,set in ipairs(sets) do
        local b=f.blocks[i]
        if not b then
            b=CreateFrame("Frame",nil,f); b:SetSize(WIDTH-44,10); f.blocks[i]=b
            b.head=FT:Label(b,"",14,true); b.head:SetPoint("TOPLEFT"); b.head:SetWidth(WIDTH-44); b.head:SetJustifyH("LEFT"); b.head:SetTextColor(1,.82,0)
            if b.head.SetWordWrap then b.head:SetWordWrap(false) end
            b.rows={}
            for r,slot in ipairs(HANDS) do
                local row={}
                row.label=FT:Label(b,HAND_NAMES[slot],13)
                row.drop=FT:Dropdown(b,300,function() local mf=MF(); return mf and mf:WeaponChoices(b.slotOf[r]) or {} end,function(value)
                    local key=b.set.key; W.swapChoice[key]=W.swapChoice[key] or {}
                    W.swapChoice[key][b.slotOf[r]]=value; row.drop.label:SetText(itemLabel(value)); W:SetIcon(row.drop,b.slotOf[r],value)
                end,"generic")
                row.drop.menuWidth=340
                if row.drop.label.SetWordWrap then row.drop.label:SetWordWrap(false) end
                b.rows[r]=row
            end
            b.slotOf={}
        end
        b.set=set
        b.head:SetText(table.concat(set.spells,", ").."  |cffa8967a"..#set.macros.." macro"..(#set.macros==1 and "" or "s").."|r")
        self.swapChoice[set.key]={}
        local ry=22
        for r,row in ipairs(b.rows) do
            local slot=set.order[r]
            b.slotOf[r]=slot
            if slot then
                local now=set.slots[slot]
                local pick=(new and now==old) and new or now
                self.swapChoice[set.key][slot]=pick
                row.label:SetText(HAND_NAMES[slot]); row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT",0,-ry-7); row.label:Show()
                row.drop:ClearAllPoints(); row.drop:SetPoint("TOPLEFT",96,-ry); row.drop:Show()
                row.drop.label:SetText(itemLabel(pick)); self:SetIcon(row.drop,slot,pick)
                FT:Tooltip(row.drop,HAND_NAMES[slot],"What these macros put in your "..HAND_NAMES[slot]:lower()..". None removes the swap line.")
                ry=ry+34
            else row.label:Hide(); row.drop:Hide() end
        end
        b:SetHeight(ry); b:ClearAllPoints(); b:SetPoint("TOPLEFT",22,-y); b:Show()
        y=y+ry+12
    end
    f.update:SetShown(#sets>0)
    f.update:ClearAllPoints(); f.update:SetPoint("TOPLEFT",22,-y-4)
    f.later:ClearAllPoints(); f.later:SetPoint("LEFT",f.update,"RIGHT",16,0)
    if #sets==0 then f.later:ClearAllPoints(); f.later:SetPoint("TOPLEFT",22,-y-4); f.later.label:SetText("Close") else f.later.label:SetText("Not now") end
    f:SetHeight(y+52)
    f:Show()
end
-- /ft weaponswap
function W:Open() self:OpenSwap(self:Sets()) end
FT.MacroWatch=W
local events=CreateFrame("Frame")
for _,e in ipairs({"PLAYER_LOGIN","PLAYER_EQUIPMENT_CHANGED","PLAYER_REGEN_ENABLED"}) do pcall(events.RegisterEvent,events,e) end
events:SetScript("OnEvent",function(_,event,slot)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then C_Timer.After(3,function() W:ReadWorn() end); return end
    if event=="PLAYER_EQUIPMENT_CHANGED" then
        if not (plain(slot) and (slot==16 or slot==17 or slot==18)) then return end
        if busy() then W.pending=true; return end
        FT:Coalesce("macroWatchWeapons",function() W:CheckWeapons() end,1)
        return
    end
    if event=="PLAYER_REGEN_ENABLED" and W.pending then
        W.pending=nil
        FT:Coalesce("macroWatchAfterFight",function() W:CheckFamilies(); W:CheckWeapons() end,2)
    end
end)
