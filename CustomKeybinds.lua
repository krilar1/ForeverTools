local _,FT=...
local B={buttons={}}
local directions={{"up","Scroll up","MOUSEWHEELUP"},{"down","Scroll down","MOUSEWHEELDOWN"}}
function B:Settings()
    if type(FT.db.customKeybinds)~="table" then FT.db.customKeybinds={} end
    local _,class=UnitClass("player")
    local all=FT.db.customKeybinds
    if type(all[class])~="table" then all[class]={enabled=false,up={},down={}} end
    return all[class]
end
-- Enumerate the player's actual spellbook, never the macro template catalogue.
function B:LearnedSpells()
    local list,seen={},{}
    local bank=Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local function add(id,name,icon,rank,passive)
        if not id or not name or passive or seen[id] then return end
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            if not C_SpellBook.IsSpellKnown(id,bank) then return end
        elseif IsPlayerSpell then if not IsPlayerSpell(id) then return end
        elseif IsSpellKnown and not IsSpellKnown(id,false) then return end
        seen[id]=true
        list[#list+1]={value=id,name=name,rank=rank,label=name..(rank and rank~="" and (" ("..rank..")") or ""),icon=icon}
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        for line=1,C_SpellBook.GetNumSpellBookSkillLines() do
            local info=C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info and (not info.offSpecID or info.offSpecID==0) then
                for slot=info.itemIndexOffset+1,info.itemIndexOffset+info.numSpellBookItems do
                    local spell=C_SpellBook.GetSpellBookItemInfo(slot,bank)
                    if spell and not spell.isOffSpec and spell.itemType==(Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1) then
                        add(spell.spellID or spell.actionID,spell.name,spell.iconID,spell.subName,spell.isPassive)
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
                    add(id,name,icon,rank,IsPassiveSpell and IsPassiveSpell(slot,BOOKTYPE_SPELL or "spell"))
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
            button:SetAttribute("_onstate-hover",nil)
            if UnregisterStateDriver then UnregisterStateDriver(button,"hover") end
            if ClearOverrideBindings then ClearOverrideBindings(button) end
            button:SetAttribute("type",nil)
            button:SetAttribute("state-hover",nil)
        end
        self:Refresh(); return
    end
    for _,d in ipairs(directions) do
        local key=d[1]; local button=self.buttons[key]
        if not button then
            button=CreateFrame("Button","ForeverToolsWheel"..key,UIParent,"SecureActionButtonTemplate,SecureHandlerStateTemplate")
            button:RegisterForClicks("AnyDown","AnyUp")
            button:SetAttribute("unit","mouseover")
            -- A wheel "press" is instant: act on the down event whatever the
            -- player's cast-on-key-down setting is, so each wheel tick casts once.
            button:SetAttribute("useOnKeyDown",true)
            button:SetAttribute("wheel",d[3])
            self.buttons[key]=button
        end
        button:SetAttribute("_onstate-hover",nil)
        UnregisterStateDriver(button,"hover")
        ClearOverrideBindings(button)
        button:SetAttribute("type",nil)
        button:SetAttribute("state-hover",nil)
        button:SetAttribute("_onstate-hover",[[
                self:ClearBindings()
                local spell=newstate and self:GetAttribute(newstate)
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
        button:SetAttribute("hostile",spell and (harm or not help) and spell.value or nil)
        if s.enabled then RegisterStateDriver(button,"hover","[@mouseover,help,nodead] friendly; [@mouseover,harm,nodead] hostile; none") end
    end
    self:Refresh()
end
function B:Refresh()
    if not self.frame then return end
    local s=self:Settings()
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
    self.status:SetText(self.unavailable and "This client does not provide the secure bindings needed for wheel casting. Normal wheel bindings are unchanged. Your spell settings are retained." or self.pending and "Saved. Bindings update after combat." or "Hover a unit frame or a character in the world to cast. Away from a valid mouseover unit, the wheel keeps its normal camera action.")
end
function B:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsCustomKeybinds","ForeverTools | Custom keybinds",640,680); self.pickers={}
        self.toggle=FT:QuietButton(self.frame,"",592,46,"mouseover"); self.toggle:SetPoint("TOPLEFT",24,-66)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        self.search=CreateFrame("EditBox",nil,self.frame,"InputBoxTemplate")
        self.search:SetSize(580,28); self.search:SetPoint("TOPLEFT",30,-298)
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
            local label=FT:Label(self.frame,d[2],16,true); label:SetPoint("TOPLEFT",24,-128-(i-1)*72)
            local picker=FT:Dropdown(self.frame,592,function() return self:SpellOptions() end,function(id) self:SelectSpell(key,id) end,"mouseover")
            picker:SetPoint("TOPLEFT",24,-152-(i-1)*72); picker:SetHeight(36)
            self.pickers[key]=picker
            FT:Tooltip(picker,d[2],"Select a learned active spell. The same spell is used on your hovered unit, friendly or enemy as the spell allows. Passive, unlearned and other-specialization spells are excluded. Search above filters both lists. None restores normal scrolling.")
        end
        self.status=FT:Label(self.frame,"",13); self.status:SetPoint("TOPLEFT",24,-594); self.status:SetSize(592,42)
        local hint=FT:Label(self.frame,"Hover a spell below, then scroll up or down to bind it.",13)
        hint:SetPoint("TOPLEFT",24,-336)
        self.spellRows={}
        for i=1,5 do
            local row=FT:QuietButton(self.frame,"",592,36,"mouseover"); row:SetPoint("TOPLEFT",24,-360-(i-1)*40)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel",function(owner,delta)
                if not owner.spell then return end
                self:SelectSpell(delta>0 and "up" or "down",owner.spell.value)
                FT:Toast(owner.spell.name.." bound to scroll "..(delta>0 and "up" or "down"))
            end)
            FT:Tooltip(row,"Bind this spell","Hover here and scroll up or down. Your selection saves immediately, even when casting is unavailable on this beta. Use the search or page buttons to browse.")
            self.spellRows[i]=row
        end
        local prev=FT:QuietButton(self.frame,"Previous",110,26,"reset"); prev:SetPoint("TOPLEFT",24,-564)
        local next=FT:QuietButton(self.frame,"Next",110,26,"add"); next:SetPoint("TOPLEFT",506,-564)
        prev:SetScript("OnClick",function() self.spellPage=math.max(1,(self.spellPage or 1)-1); self:RenderSpellRows() end)
        next:SetScript("OnClick",function() self.spellPage=math.min(self.spellPages or 1,(self.spellPage or 1)+1); self:RenderSpellRows() end)
        self.pageLabel=FT:Label(self.frame,"",12); self.pageLabel:SetPoint("TOP",0,-570)
        local info=FT:Info(self.frame,"Mouse-wheel casting","Choose a learned spell, then bind a wheel direction. Over a unit, the wheel uses that spell; elsewhere, it zooms the camera. Change bindings outside combat.")
        info:SetPoint("BOTTOMRIGHT",-24,20)
        FT:Tooltip(self.toggle,"Enable mouse-wheel casting","Select one learned spell for each direction below. Off restores the previous wheel bindings. Each scroll casts once.")
    end
    self:Refresh(); self.frame:Show()
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
-- Troubleshooting only (/ft wheeldebug): prints what the wheel-casting pieces see.
-- Hooks are added only while debugging, and nothing here casts or changes bindings.
function B:Debug()
    self.debug=not self.debug
    local function say(text) print("|cffc9a0ffForeverTools wheel:|r "..text) end
    if not self.debug then say("debug off"); return end
    local s=self:Settings()
    local get=(C_CVar and C_CVar.GetCVar) or GetCVar
    local _,class=UnitClass("player")
    say("debug on ("..tostring(class)..", saved enabled="..tostring(s.enabled).."). Casting "..(s.enabled and "ON" or "OFF")..(self.unavailable and " (unavailable on this client)" or "")..
        ", ActionButtonUseKeyDown="..tostring(get and get("ActionButtonUseKeyDown")))
    for _,d in ipairs(directions) do
        local spell=self:SelectedSpell(d[1]); local button=self.buttons[d[1]]
        say(d[2]..": "..(spell and spell.label or "no spell")..(button and "" or " (no button yet: turn casting on)"))
        if button and not button.ftDebugHooked then
            button.ftDebugHooked=true
            button:HookScript("OnAttributeChanged",function(owner,name,value)
                if B.debug and name=="state-hover" then
                    say(d[2].." state = "..tostring(value).." · "..d[3].." bound to: "..tostring(GetBindingAction and GetBindingAction(d[3],true)))
                end
            end)
            button:HookScript("PreClick",function(owner,mouse,down)
                if B.debug then say(d[2].." click received (down="..tostring(down)..", spell="..tostring(owner:GetAttribute("spell"))..", type="..tostring(owner:GetAttribute("type"))..")") end
            end)
        end
    end
    say("Now hover your player frame and a character in the world, and scroll.")
end
FT:RegisterModule("CustomKeybinds",B)
local events=CreateFrame("Frame")
-- SPELLS_CHANGED also covers newly learned spells; the beta has no LEARNED_SPELL_IN_TAB event.
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_REGEN_ENABLED","SPELLS_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() B:Apply() end)
