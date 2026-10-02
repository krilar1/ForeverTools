local _,FT=...
local B={buttons={}}
local directions={{"up","Scroll up","MOUSEWHEELUP"},{"down","Scroll down","MOUSEWHEELDOWN"}}
-- Dispels by spellbook name, with the debuff type each one removes. true means
-- "whatever the game says this character can remove" (spells that cover
-- several types). A dispel on the wheel is only cast when there is something
-- for it to remove; see B:DispelBlocked.
local DISPELS={
    ["Cure Poison"]="Poison",["Abolish Poison"]="Poison",
    ["Cure Disease"]="Disease",["Abolish Disease"]="Disease",
    ["Remove Curse"]="Curse",["Remove Lesser Curse"]="Curse",
    ["Dispel Magic"]="Magic",
    ["Cleanse"]=true,["Purify"]=true,["Cleanse Spirit"]=true,["Remove Corruption"]=true,
}
function B:Settings()
    if type(FT.db.customKeybinds)~="table" then FT.db.customKeybinds={} end
    local _,class=UnitClass("player")
    local all=FT.db.customKeybinds
    if type(all[class])~="table" then all[class]={enabled=false,up={},down={}} end
    return all[class]
end
-- The spellbook only changes on a few events, so the scan is kept until one
-- of them fires. Callers only read the list; nobody may change it.
function B:LearnedSpells()
    if self.spellCache then return self.spellCache end
    local list=self:ScanSpells()
    -- An empty book usually means it is not loaded yet: do not keep that.
    if #list>0 then self.spellCache=list end
    return list
end
local spellbookEvents=CreateFrame("Frame")
for _,event in ipairs({"SPELLS_CHANGED","LEARNED_SPELL_IN_SKILL_LINE","PLAYER_LEVEL_UP","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","ACTIVE_TALENT_GROUP_CHANGED","PLAYER_ENTERING_WORLD","TRAINER_UPDATE"}) do pcall(spellbookEvents.RegisterEvent,spellbookEvents,event) end
spellbookEvents:SetScript("OnEvent",function() B.spellCache=nil end)
-- Enumerate the player's actual spellbook, never the macro template catalogue.
function B:ScanSpells()
    local list,seen={},{}
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local function add(id,name,icon,rank,passive,line)
        if not id or not name or passive or seen[id] then return end
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            if not C_SpellBook.IsSpellKnown(id,bank) then return end
        elseif IsPlayerSpell then if not IsPlayerSpell(id) then return end
        elseif IsSpellKnown and not IsSpellKnown(id,false) then return end
        seen[id]=true
        list[#list+1]={value=id,name=name,rank=rank,label=name..(rank and rank~="" and (" ("..rank..")") or ""),icon=icon,line=line}
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        for line=1,C_SpellBook.GetNumSpellBookSkillLines() do
            local info=C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and (not info.offSpecID or info.offSpecID==0) then
                for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                    local spell=C_SpellBook.GetSpellBookItemInfo(slot,bank)
                    if spell and not spell.isOffSpec and spell.itemType==(Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1) then
                        add(spell.spellID or spell.actionID,spell.name,spell.iconID,spell.subName,spell.isPassive,line)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for tab=1,GetNumSpellTabs() do
            local _,_,offset,count=GetSpellTabInfo(tab)
            for slot=offset+1,offset+count do
                local kind,id=GetSpellBookItemInfo(slot,BOOKTYPE_SPELL or "spell")
                if kind=="SPELL" then
                    local name,rank=GetSpellBookItemName(slot,BOOKTYPE_SPELL or "spell")
                    local icon=GetSpellBookItemTexture and GetSpellBookItemTexture(slot,BOOKTYPE_SPELL or "spell")
                    add(id,name,icon,rank,IsPassiveSpell and IsPassiveSpell(slot,BOOKTYPE_SPELL or "spell"),tab)
                end
            end
        end
    end
    table.sort(list,function(a,b) return a.label==b.label and a.value<b.value or a.label<b.label end)
    return list
end
function B:SelectedSpell(key,list)
    local pref=self:Settings()[key] or {}
    -- Keep old fields for recovery, but migrate only names found in this
    -- character's learned spellbook. One direction now selects one spell.
    for _,spell in ipairs(list or self:LearnedSpells()) do
        if spell.value==pref.spellID then return spell end
        if not pref.spellID and (spell.name==pref.friendly or spell.name==pref.hostile) then
            pref.spellID=spell.value; return spell
        end
    end
end
function B:SelectSpell(key,id)
    local s=self:Settings(); s[key]=s[key] or {}
    if id==0 then s[key]={}; self:Apply(); return end
    for _,spell in ipairs(self:LearnedSpells()) do
        if spell.value==id then
            s[key]={spellID=id}
            -- Binding a spell is a clear sign the player wants wheel casting.
            if not s.enabled and not self.unavailable then
                s.enabled=true
                FT:Toast("Mouse-wheel casting turned on.",3)
            end
            self:Apply(); return
        end
    end
    FT:Toast("That spell is no longer learned."); self:Refresh()
end
function B:SpellOptions()
    local list={{value=0,label="None — normal scrolling",icon="Interface\\Icons\\INV_Misc_QuestionMark"}}
    local query=self.search and self.search:GetText():lower() or ""
    for _,spell in ipairs(self:LearnedSpells()) do if spell.label:lower():find(query,1,true) then list[#list+1]=spell end end
    return list
end
function B:Apply()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.pending=true; self:Refresh(); return end
    self.pending=false
    -- Blizzard's secure snippet compiler is captured privately by the restricted
    -- environment and its global name is then cleared (EnvironmentCleanup), so a
    -- global check always failed. Only the public driver API is required here.
    self.unavailable = type(RegisterStateDriver)~="function" or type(UnregisterStateDriver)~="function"
        or type(ClearOverrideBindings)~="function"
    local s=self:Settings()
    if self.unavailable or not s.enabled then
        for _,button in pairs(self.buttons) do
            button:SetAttribute("_onattributechanged",nil)
            if UnregisterStateDriver then UnregisterStateDriver(button,"hover") end
            if ClearOverrideBindings then ClearOverrideBindings(button) end
            button:SetAttribute("type",nil)
            button:SetAttribute("state-hover",nil)
            button.dispel=false
        end
        self:WatchNpcs()
        self:Refresh(); return
    end
    for _,d in ipairs(directions) do
        local key=d[1]; local button=self.buttons[key]
        if not button then
            button=CreateFrame("Button","ForeverToolsWheel"..key,UIParent,"SecureActionButtonTemplate,SecureHandlerAttributeTemplate")
            button:RegisterForClicks("AnyDown","AnyUp")
            button:SetAttribute("unit","mouseover")
            -- A wheel "press" is instant: act on the down event whatever the
            -- player's cast-on-key-down setting is, so each wheel tick casts once.
            button:SetAttribute("useOnKeyDown",true)
            button:SetAttribute("wheel",d[3])
            self.buttons[key]=button
        end
        button:SetAttribute("_onattributechanged",nil)
        UnregisterStateDriver(button,"hover")
        ClearOverrideBindings(button)
        button:SetAttribute("type",nil)
        button:SetAttribute("state-hover",nil)
        button.npcBlock=false; button:SetAttribute("npcblock",false)
        -- Runs when the unit under the mouse changes kind ("state-hover":
        -- friendly, hostile or none) and when the friendly cast is held back
        -- ("npcblock": a friendly NPC or totem, or a dispel with nothing to
        -- remove). The wheel is bound only while there is something to cast
        -- on; otherwise it zooms the camera.
        button:SetAttribute("_onattributechanged",[[
                if name~="state-hover" and name~="npcblock" then return end
                self:ClearBindings()
                local state=self:GetAttribute("state-hover")
                local spell=state and self:GetAttribute(state)
                if state=="friendly" and self:GetAttribute("npcblock") then spell=nil end
                self:SetAttribute("type",nil)
                if spell and spell~="" then
                    self:SetAttribute("type","spell")
                    self:SetAttribute("spell",spell)
                    self:SetBindingClick(true,self:GetAttribute("wheel"),self:GetName(),"LeftButton")
                end
            ]])

        local pref=s[key] or {}; s[key]=pref
        local spell=self:SelectedSpell(key)
        local helpful=(C_Spell and C_Spell.IsSpellHelpful) or IsHelpfulSpell
        local harmful=(C_Spell and C_Spell.IsSpellHarmful) or IsHarmfulSpell
        local function relation(fn)
            if not spell or not fn then return end
            local ok,value=pcall(fn,spell.value)
            if ok and (not issecretvalue or not issecretvalue(value)) then return value end
        end
        local help=relation(helpful)
        local harm=relation(harmful)
        -- A dual-purpose spell works on either relation; WoW validates targets.
        button:SetAttribute("friendly",spell and (help or not harm) and spell.value or nil)
        button.dispel=spell and (help or not harm) and DISPELS[spell.name] or false
        button:SetAttribute("hostile",spell and (harm or not help) and spell.value or nil)
        if s.enabled then RegisterStateDriver(button,"hover","[@mouseover,help,nodead] friendly; [@mouseover,harm,nodead] hostile; none") end
    end
    self:WatchNpcs()
    self:Refresh()
end
-- What the wheel never casts on, so scrolling over it zooms the camera:
--  * totems and other summoned helpers (always; a player's pet is not one);
--  * friendly NPCs such as vendors and quest givers, unless "Cast on
--    friendly NPCs" is on.
-- Players and pets are never skipped. The game only lets this change out of
-- combat, so it is lifted for a fight: in combat the wheel casts as before.
local function hidden(v) return issecretvalue and issecretvalue(v) or false end
-- A real pet: yours, a group member's or another player's. When the game
-- hides the answer, treat it as a pet (never block by mistake).
function B:IsPet(unit)
    local kind=UnitCreatureType and UnitCreatureType(unit)
    if not hidden(kind) and kind=="Totem" then return false end
    local mine=UnitIsUnit and UnitIsUnit(unit,"pet")
    if hidden(mine) or mine then return true end
    local other=UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit)
    if hidden(other) or other then return true end
    for _,check in ipairs({UnitPlayerOrPetInParty or false,UnitPlayerOrPetInRaid or false}) do
        if check then local grouped=check(unit); if hidden(grouped) or grouped then return true end end
    end
    return false
end
function B:NpcUnderMouse()
    if not UnitExists or not UnitIsPlayer then return false end
    local exists=UnitExists("mouseover")
    if hidden(exists) or not exists then return false end
    local player=UnitIsPlayer("mouseover")
    if hidden(player) or player then return false end
    local friend=UnitCanAssist and UnitCanAssist("player","mouseover")
    if hidden(friend) or not friend then return false end
    local controlled=UnitPlayerControlled and UnitPlayerControlled("mouseover")
    if hidden(controlled) then return false end
    -- Summoned by a player: pets stay, totems and the like are skipped.
    if controlled then return not self:IsPet("mouseover") end
    return self:Settings().npcs~=true
end
-- Is the mouse on a character in the world, rather than on a unit frame?
local function overWorld()
    if not WorldFrame then return false end
    if GetMouseFoci then
        local ok,foci=pcall(GetMouseFoci)
        return ok and type(foci)=="table" and foci[1]==WorldFrame
    end
    return GetMouseFocus~=nil and GetMouseFocus()==WorldFrame
end
-- Does the unit have a debuff this dispel removes? nil when the game does
-- not say. "HARMFUL|RAID" is the game's own "debuffs you can remove" filter,
-- the same one the dispel glow uses.
function B:Removable(unit,kind)
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuras then return nil end
    local ok,auras=pcall(C_UnitAuras.GetUnitAuras,unit,"HARMFUL|RAID",kind==true and 1 or nil)
    if not ok or hidden(auras) or type(auras)~="table" then return nil end
    if kind==true then return #auras>0 end
    for _,aura in ipairs(auras) do
        if hidden(aura) or type(aura)~="table" then return true end
        local name=aura.dispelName
        if hidden(name) or name==kind then return true end
    end
    return false
end
-- A dispel on the wheel is held back when the friendly unit under the mouse
-- has nothing it removes, and on a player's character in the world, where a
-- scroll is nearly always meant for the camera. Unit frames always work.
-- Anything the game hides counts as "cast as usual".
function B:DispelBlocked(kind)
    local exists=UnitExists and UnitExists("mouseover")
    if hidden(exists) or not exists then return false end
    local friend=UnitCanAssist and UnitCanAssist("player","mouseover")
    if hidden(friend) or not friend then return false end
    local player=UnitIsPlayer and UnitIsPlayer("mouseover")
    if not hidden(player) and player and overWorld() then return true end
    return self:Removable("mouseover",kind)==false
end
local auraEvents=CreateFrame("Frame")
-- Debuffs come and go while the mouse rests on a unit; listen only then.
function B:WatchAuras(on)
    on=on==true
    if on==(self.auraWatch==true) then return end
    self.auraWatch=on
    if on then auraEvents:RegisterEvent("UNIT_AURA") else auraEvents:UnregisterEvent("UNIT_AURA") end
end
auraEvents:SetScript("OnEvent",function(_,_,unit)
    if not FT.dbReady or InCombatLockdown() then return end
    local exists=UnitExists("mouseover")
    if hidden(exists) or not exists then B:WatchAuras(false); return end
    if hidden(unit) or type(unit)~="string" then return end
    local same=UnitIsUnit and UnitIsUnit(unit,"mouseover")
    if hidden(same) or same then FT:Coalesce("wheel:auras",function() B:UpdateBlocks() end,0) end
end)
-- Works out, per wheel direction, whether the friendly cast is held back.
-- lift: entering combat, clear every block while it can still be changed.
function B:UpdateBlocks(lift)
    if InCombatLockdown() and not lift then return end
    local npc=not lift and self:NpcUnderMouse() or false
    local dispels
    for _,button in pairs(self.buttons) do
        local blocked=npc
        if button.dispel and not lift then
            dispels=true
            if not blocked then blocked=self:DispelBlocked(button.dispel) end
        end
        if button.npcBlock~=blocked then button.npcBlock=blocked; button:SetAttribute("npcblock",blocked) end
    end
    local exists=dispels and UnitExists and UnitExists("mouseover")
    self:WatchAuras(not hidden(exists) and exists and true or false)
end
local npcEvents=CreateFrame("Frame")
npcEvents:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    B:UpdateBlocks(event=="PLAYER_REGEN_DISABLED")
end)
function B:WatchNpcs()
    local s=self:Settings()
    if s.enabled and not self.unavailable then
        for _,event in ipairs({"UPDATE_MOUSEOVER_UNIT","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do npcEvents:RegisterEvent(event) end
        self:UpdateBlocks()
    else
        npcEvents:UnregisterAllEvents(); self:UpdateBlocks(true)
    end
end
function B:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.npcToggle.label:SetText("Cast on friendly NPCs: "..(s.npcs==true and "On" or "Off")); FT:SetSelected(self.npcToggle,s.npcs==true)
    self.npcToggle:SetAlpha(s.enabled and not self.unavailable and 1 or .5)
    self.toggle.label:SetText(self.unavailable and "Mouse-wheel casting: Unavailable" or ("Mouse-wheel casting: "..(s.enabled and "On" or "Off")))
    self.toggle:SetEnabled(not self.unavailable); FT:SetSelected(self.toggle,s.enabled and not self.unavailable)
    local list=self:LearnedSpells()
    for key,picker in pairs(self.pickers) do
        local spell=self:SelectedSpell(key,list)
        picker.value=spell and spell.value or 0
        picker.label:SetText(spell and spell.label or (s[key] and s[key].spellID and "Spell no longer learned — select another" or "Select a learned spell"))
        picker.icon:SetTexture(spell and spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if self.spellRows then self:RenderSpellRows() end
    self.status:SetText(self.unavailable and "Wheel casting isn't available on this game version. Your wheel works as usual, and your spell choices are kept." or self.pending and "Saved. Bindings update after combat." or "")
end
function B:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsCustomKeybinds","ForeverTools | Mouse-wheel casting",640,680); self.pickers={}
        FT:BackTo(self.frame,"SystemKeybinds")
        self.toggle=FT:AccentButton(self.frame,"",292,34,"mouseover"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        self.npcToggle=FT:QuietButton(self.frame,"",292,34,"character"); self.npcToggle:SetPoint("TOPLEFT",324,-62)
        self.npcToggle.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
        self.npcToggle:SetScript("OnClick",function() local s=self:Settings(); s.npcs=not (s.npcs==true); self:Apply() end)
        FT:Tooltip(self.npcToggle,"Cast on friendly NPCs","Off (the default): scrolling over a vendor, quest giver or other friendly NPC zooms the camera as usual, so you don't cast on them by accident. Players, their pets and enemies are not affected. Totems and other summoned helpers are always skipped, whatever this is set to. In combat the wheel casts on all of them, because the game does not allow this to change during a fight. On: friendly NPCs are cast on like players.")
        for _,b in ipairs({self.toggle,self.npcToggle}) do if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        self.search=CreateFrame("EditBox",nil,self.frame,"InputBoxTemplate")
        self.search:SetSize(580,28); self.search:SetPoint("TOPLEFT",30,-306)
        self.search:SetFont(FT.bodyFont,14,""); self.search:SetAutoFocus(false)
        local searchLabel=FT:Label(self.frame,"Search learned spells",12); searchLabel:SetPoint("BOTTOMLEFT",self.search,"TOPLEFT",0,4)
        self.search:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
        self.search:SetScript("OnTextChanged",function()
            self.spellPage=1; if self.spellRows then self:RenderSpellRows() end
            local menu=FT.choiceMenu
            if menu and menu:IsShown() and (menu.owner==self.pickers.up or menu.owner==self.pickers.down) then
                local owner=menu.owner; menu:Hide(); FT:ShowChoices(owner)
            end
        end)
        for i,d in ipairs(directions) do
            local key=d[1]
            local label=FT:Label(self.frame,d[2],16,true); label:SetPoint("TOPLEFT",24,-112-(i-1)*80); FT:SectionHeading(label,"INV_Misc_Key_03",300)
            local picker=FT:Dropdown(self.frame,592,function() return self:SpellOptions() end,function(id) self:SelectSpell(key,id) end,"mouseover")
            picker:SetPoint("TOPLEFT",24,-142-(i-1)*80); picker:SetHeight(34)
            self.pickers[key]=picker
            FT:Tooltip(picker,d[2],"Pick a spell you have learned. It is cast on the unit under your mouse, friend or enemy as the spell allows. A dispel is only cast when there is something to remove. Choose None to scroll normally again.")
        end
        self.status=FT:Label(self.frame,"",13); self.status:SetPoint("TOPLEFT",24,-594); self.status:SetSize(592,42)
        self.spellRows={}
        for i=1,5 do
            local row=FT:QuietButton(self.frame,"",592,36,"mouseover"); row:SetPoint("TOPLEFT",24,-360-(i-1)*40)
            -- Scrolling over the list only pages it; binding needs an explicit click first.
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel",function(_,delta) self:TurnPage(delta>0 and -1 or 1) end)
            row:SetScript("OnClick",function(owner) if owner.spell then self:StartBinding(owner.spell) end end)
            FT:Tooltip(row,"Bind this spell","Click, then scroll up or down to choose the wheel direction. Click again or press Esc to cancel. Your choice saves immediately.")
            self.spellRows[i]=row
        end
        self:CreateBindOverlay()
        local prev=FT:QuietButton(self.frame,"Previous",110,26,"reset"); prev:SetPoint("TOPLEFT",24,-564)
        local next=FT:QuietButton(self.frame,"Next",110,26,"add"); next:SetPoint("TOPLEFT",506,-564)
        prev:SetScript("OnClick",function() self:TurnPage(-1) end)
        next:SetScript("OnClick",function() self:TurnPage(1) end)
        self.pageLabel=FT:Label(self.frame,"",12); self.pageLabel:SetPoint("TOP",0,-570)
        FT:PageInfo(self.frame,"Mouse-wheel casting","Bind a spell to scrolling up or down. Scroll over a unit frame or a character in the world to cast it on them. Anywhere else, the wheel zooms the camera as usual. Friendly NPCs such as vendors and quest givers are skipped unless you turn on Cast on friendly NPCs; totems are always skipped, pets never.\n\nDispels (Cure Poison, Remove Curse, Cleanse and the like) are only cast when the unit has something they remove, and never on a player's character in the world: scroll over their unit frame instead. With nothing to remove, the wheel zooms the camera.\n\nThese checks work out of combat. In a fight the game does not allow the wheel to change, so it casts on whatever is under the mouse.\n\nPick a spell in the Scroll up / Scroll down menus, or click a spell in the list, then scroll up or down to bind it.")
        FT:Tooltip(self.toggle,"Enable mouse-wheel casting","Turn mouse-wheel casting on or off. Off gives the wheel back to the camera. Each scroll casts once.")
    end
    self:Refresh(); self.frame:Show()
end
function B:TurnPage(step)
    self.spellPage=math.max(1,math.min(self.spellPages or 1,(self.spellPage or 1)+step))
    self:RenderSpellRows()
end
-- Bind mode: a click on a spell arms the wheel once. The overlay covers the
-- window so the next wheel tick is caught anywhere on it, never by accident.
function B:CreateBindOverlay()
    local frame=self.frame
    local overlay=CreateFrame("Button",nil,frame); self.overlay=overlay
    overlay:SetPoint("TOPLEFT",8,-58); overlay:SetPoint("BOTTOMRIGHT",-8,8)
    overlay:SetFrameLevel(frame:GetFrameLevel()+30)
    overlay:EnableMouse(true); overlay:EnableMouseWheel(true); overlay:RegisterForClicks("AnyUp")
    FT:RoundedFill(overlay,.02,.015,.04,.9)
    local box=CreateFrame("Frame",nil,overlay); box:SetSize(420,150); box:SetPoint("CENTER"); FT:Panel(box)
    box.icon=box:CreateTexture(nil,"ARTWORK"); box.icon:SetSize(40,40); box.icon:SetPoint("TOP",0,-20)
    box.icon:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(box.icon)
    box.title=FT:Label(box,"",16,true); box.title:SetPoint("TOP",box.icon,"BOTTOM",0,-10); box.title:SetWidth(390); box.title:SetJustifyH("CENTER")
    box.hint=FT:Label(box,"Scroll up or down to bind. Click or press Esc to cancel.",13); box.hint:SetPoint("TOP",box.title,"BOTTOM",0,-8)
    box.hint:SetWidth(390); box.hint:SetJustifyH("CENTER"); box.hint:SetTextColor(.85,.80,.70)
    overlay.box=box
    overlay:SetScript("OnMouseWheel",function(_,delta)
        local spell=self.binding; self:StopBinding(); if not spell then return end
        local key=delta>0 and "up" or "down"
        self:SelectSpell(key,spell.value)
        FT:Toast(spell.name.." bound to scroll "..key,3)
    end)
    overlay:SetScript("OnClick",function() self:StopBinding() end)
    overlay:SetScript("OnKeyDown",function(owner,key)
        if key=="ESCAPE" then
            if owner.SetPropagateKeyboardInput and not InCombatLockdown() then owner:SetPropagateKeyboardInput(false) end
            self:StopBinding()
        elseif owner.SetPropagateKeyboardInput and not InCombatLockdown() then owner:SetPropagateKeyboardInput(true) end
    end)
    overlay:Hide()
    frame:HookScript("OnHide",function() self:StopBinding() end)
end
function B:StartBinding(spell)
    if InCombatLockdown() then return end
    self.binding=spell
    local box=self.overlay.box
    box.icon:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    box.title:SetText("Bind "..spell.label)
    self.overlay:EnableKeyboard(true); self.overlay:Show()
end
function B:StopBinding()
    self.binding=nil
    if self.overlay then self.overlay:EnableKeyboard(false); self.overlay:Hide() end
end
function B:RenderSpellRows()
    local spells=self:SpellOptions(); table.remove(spells,1)
    self.spellPages=math.max(1,math.ceil(#spells/5)); self.spellPage=math.min(self.spellPages,self.spellPage or 1)
    for i,row in ipairs(self.spellRows) do
        local spell=spells[(self.spellPage-1)*5+i]; row.spell=spell; row:SetShown(spell~=nil)
        if spell then row.label:SetText(spell.label); row.icon:SetTexture(spell.icon) end
    end
    self.pageLabel:SetText(#spells==0 and "No matching learned spells" or (self.spellPage.." / "..self.spellPages))
end
FT:RegisterModule("CustomKeybinds",B)
local events=CreateFrame("Frame")
-- SPELLS_CHANGED also covers newly learned spells; the beta has no LEARNED_SPELL_IN_TAB event.
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","SPELLS_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() B:Apply() end)
