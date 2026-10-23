local _,FT=...
-- Macro guide (Macros > Macro guide): every kind of macro the game
-- understands, each with a short explanation and an example. "Make a macro"
-- turns the example into one of your own macros (My own macros), where you
-- swap the <placeholders> for your spells; "Copy" shows the text to copy.
-- Words in <angle brackets> are placeholders.
local G={}
G.SECTIONS={
    {title="Basics",items={
        {"Show the spell icon and tooltip","#showtooltip as the first line gives the macro the icon, tooltip and cooldown of the spell it casts.","#showtooltip\n/cast <spell>"},
        {"Cast a spell","/cast casts a spell by name. Add (Rank 3) after the name for a lower rank.","/cast <spell>\n/cast <spell>(Rank 1)"},
        {"Use an item","/use uses an item from your bags or gear by name.","/use <item>"},
        {"Use a trinket or gear slot","A number uses what is in that slot: 13 is the top trinket, 14 the bottom one, 10 gloves.","#showtooltip 13\n/use 13"},
        {"Several commands at once","Each line runs in order on one press. Only one spell that triggers the global cooldown can be cast per press; commands that don't (attacking, trinkets, talking) can be added freely.","#showtooltip\n/use 13\n/cast <spell>\n/startattack"},
        {"How conditions work","Conditions go in [brackets] before a spell. They are checked left to right and the first one that is true wins. A comma means \"and\", a semicolon starts the next choice, and \"no\" in front turns a condition around (nocombat).","/cast [mod:shift] <spell A>; [combat] <spell B>; <spell C>"},
    }},
    {title="Who it is cast on",items={
        {"Mouseover heal","Heals whoever is under your mouse (unit frames or in the world), else your friendly target, else yourself.","#showtooltip\n/cast [@mouseover,help,nodead][help,nodead][@player] <spell>"},
        {"Mouseover attack","Casts on the enemy under your mouse, else on your target.","#showtooltip\n/cast [@mouseover,harm,nodead][] <spell>"},
        {"Cast on yourself","Always casts on you, whatever you have targeted.","#showtooltip\n/cast [@player] <spell>"},
        {"Focus","Casts on your focus if there is one, else on your target. /focus sets your target as focus, /clearfocus removes it.","#showtooltip\n/cast [@focus,harm,nodead][] <spell>"},
        {"Set focus","Makes the unit under your mouse (or your target) your focus.","/focus [@mouseover,exists][]"},
        {"Your target's target","Casts on whoever your target is targeting (handy for healing the tank from the enemy).","#showtooltip\n/cast [@targettarget,help,nodead] <spell>"},
        {"A party member","party1 to party4 are your group members in party frame order; raid1 to raid40 in a raid.","/cast [@party1] <spell>"},
        {"Where your cursor points","For spells you place on the ground: cast straight at the cursor, no targeting circle.","#showtooltip\n/cast [@cursor] <spell>"},
        {"Nearest enemy","Targets the nearest enemy when you have no living hostile target, then attacks.","/targetenemy [noharm][dead]\n/startattack"},
        {"Target someone by name","/target picks the nearest match; /targetexact only that exact name.","/targetexact <name>"},
        {"Assist","Targets what your focus (or the named player) is targeting.","/assist [@focus]"},
        {"Clear or swap target","/cleartarget drops your target, /targetlasttarget goes back to the one before.","/cleartarget\n/targetlasttarget"},
    }},
    {title="Conditions",items={
        {"Modifier keys","Hold Shift, Ctrl or Alt for another spell on the same button.","#showtooltip\n/cast [mod:shift] <spell A>; [mod:ctrl] <spell B>; <spell C>"},
        {"In or out of combat","One spell in a fight, another outside it.","#showtooltip\n/cast [combat] <spell A>; <spell B>"},
        {"Stances and forms","stance:1 is your first stance or form (a druid's bear, a warrior's battle stance), stance:0 none.","#showtooltip\n/cast [stance:1] <spell A>; [stance:2] <spell B>; <spell C>"},
        {"Stealth","An opener while stealthed, a normal attack otherwise.","#showtooltip\n/cast [stealth] <opener>; <spell>"},
        {"Where you are","swimming, outdoors, indoors, mounted, flying.","#showtooltip\n/cast [swimming] <spell A>; [outdoors] <spell B>; <spell C>"},
        {"What you wear","equipped: checks a weapon or armor type, like Shields or Two-Handed Maces.","#showtooltip\n/cast [equipped:Shields] <spell A>; <spell B>"},
        {"Mouse button","btn:2 is a right click on the button, btn:3 the middle button.","#showtooltip\n/cast [btn:2] <spell A>; <spell B>"},
        {"Group","group checks a party, group:raid a raid.","/cast [group:raid] <spell A>; [group] <spell B>; <spell C>"},
        {"Pet","pet is true while you have a pet out, nopet when not.","#showtooltip\n/cast [nopet] <summon spell>; <spell>"},
        {"Target state","exists, dead, help (friendly), harm (enemy), and the same with no in front.","/cast [harm,nodead] <spell A>; [help] <spell B>"},
        {"Not while channeling","Don't break a channeled spell (like Arcane Missiles) by pressing the button.","/cast [nochanneling] <spell>"},
        {"Stop the macro","/stopmacro ends the macro here when its condition is true; the lines below don't run.","/stopmacro [nocombat]\n/cast <spell>"},
    }},
    {title="Casting and attacking",items={
        {"Stop casting first","Cancels what you are casting so the next spell goes off right away (good for interrupts).","#showtooltip\n/stopcasting\n/cast <interrupt>"},
        {"Start or stop attacking","/startattack turns auto attack on, /stopattack off (useful before crowd control).","#showtooltip\n/stopattack\n/cast <spell>"},
        {"A sequence","Each press casts the next spell in the list. reset= starts over after a fight (combat), a new target (target), or seconds.","#showtooltip\n/castsequence reset=combat/target <spell A>, <spell B>, <spell C>"},
        {"A random spell","Casts one of the spells at random.","/castrandom <spell A>, <spell B>"},
        {"Cancel a buff","Removes a buff from you (cancelaura), your form (cancelform), or dismounts.","/cancelaura <buff>\n/cancelform\n/dismount"},
        {"Raid marker","Puts a mark on your target: 1 star, 2 circle, 3 diamond, 4 triangle, 5 moon, 6 square, 7 cross, 8 skull.","/tm 8"},
    }},
    {title="Pets",items={
        {"Pet attack","Sends your pet at your target (or the enemy under your mouse).","/petattack [@mouseover,harm][]"},
        {"Pet stance and moving","Follow, stay, and how your pet fights.","/petfollow\n/petstay\n/petpassive\n/petdefensive"},
        {"Pet spell on a target","Casts your pet's spell on your target.","#showtooltip\n/cast [@target] <pet spell>"},
        {"Pet spell on or off","Turns a pet spell's automatic use on or off.","/petautocasttoggle <pet spell>"},
    }},
    {title="Items and gear",items={
        {"Equip an item","/equip puts an item on; /equipslot puts it in one slot (16 main hand, 17 off hand, 13/14 trinkets).","/equipslot 16 <weapon>\n/equipslot 17 <off hand>"},
        {"Bandage yourself","Uses a bandage on you even with an enemy targeted. (Macros > Generic > Bandage keeps the best one up to date.)","/use [@player] <bandage>"},
        {"Eat and drink","Food and drink on one button.","/use <food>\n/use <drink>"},
        {"Hearthstone outside fights","Only when you are not in a fight.","/use [nocombat] Hearthstone"},
    }},
    {title="Talking and other",items={
        {"Say something","/say, /yell, /p (party), /raid, /g (guild). %t is your target's name.","/p Sheeping %t, don't break it!\n/cast <spell>"},
        {"Emote","Any emote works: /wave, /dance, /thank, /cheer.","/thank"},
        {"Click a button","/click presses any named button, for example an action button or a ForeverTools trinket button.","/click ForeverToolsTrinket1"},
        {"A line of Lua","/run (or /script) runs a short piece of Lua.","/run print(\"Hello\")"},
        {"Silence error messages","Hides the red error text for the lines between (ForeverTools can also hide errors: On-screen info > Error messages).","/run UIErrorsFrame:Hide()\n/cast <spell>\n/run UIErrorsFrame:Clear(); UIErrorsFrame:Show()"},
        {"Group tools","/readycheck, /roll, and /reload to reload your interface.","/readycheck"},
    }},
}
-- Make one of your own macros from an example (My own macros).
function G:Make(title,code)
    local macro=FT.modules.MacroForge
    FT.db.customMacros=type(FT.db.customMacros)=="table" and FT.db.customMacros or {}
    local base=title:gsub("[^%w ]",""):sub(1,14):gsub("%s+$","")
    if base=="" then base="Macro" end
    local name,n=base,1
    local function taken(x) for _,e in ipairs(FT.db.customMacros) do if e.name==x and e.class==nil then return true end end return false end
    while taken(name) do n=n+1; name=base:sub(1,13)..n end
    local entry={name=name,code=code,category="custom",icon="INV_Misc_Note_01",kind="custom"}
    table.insert(FT.db.customMacros,1,entry)
    FT:OpenModule("MacroOwn")
    if macro then macro.counts=nil; macro.expanded=true; if macro.Select then pcall(macro.Select,macro,entry) end; if macro.Status then macro:Status("Made from the guide. Swap the <words> for your spells, then Add.") end end
end
function G:Open()
    if not self.frame then
        local W,H=600,660
        local frame=FT:Window("ForeverToolsMacroGuide","Macro guide",W,H); self.frame=frame
        FT:PageInfo(frame,"Macro guide","Every kind of macro the game understands, with a short explanation and an example. Make a macro turns an example into one of your own macros (My own macros); swap the words in <angle brackets> for your own spells, items or names. Copy shows the text so you can copy it.")
        local hint=FT:Label(frame,"Every kind of macro, explained. Words in <angle brackets> are yours to fill in.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(W-48); hint:SetTextColor(.66,.59,.48)
        local scroll=CreateFrame("ScrollFrame","ForeverToolsMacroGuideScroll",frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",24,-88); scroll:SetPoint("BOTTOMRIGHT",-40,20)
        local content=CreateFrame("Frame",nil,scroll); content:SetSize(W-72,1); scroll:SetScrollChild(content)
        if FT.AutoHideScrollBar then FT:AutoHideScrollBar(scroll) end
        local inner=W-72
        local y=0
        for _,section in ipairs(self.SECTIONS) do
            local head=FT:Label(content,section.title,15,true); head:SetPoint("TOPLEFT",0,-y); head:SetTextColor(1,.82,0)
            FT:SectionHeading(head,nil,inner-200); y=y+26
            for _,item in ipairs(section.items) do
                local title,text,code=item[1],item[2],item[3]
                local t=FT:Label(content,title,14); t:SetPoint("TOPLEFT",0,-y); t:SetWidth(inner)
                y=y+20
                local d=FT:Label(content,text,12); d:SetPoint("TOPLEFT",0,-y); d:SetWidth(inner); d:SetTextColor(.78,.72,.62)
                if d.SetWordWrap then d:SetWordWrap(true) end
                local dh=d:GetStringHeight(); y=y+math.max(15,type(dh)=="number" and dh or 15)+6
                -- The example in a dark box, one line per command.
                local lines=1; for _ in code:gmatch("\n") do lines=lines+1 end
                -- A read-only text box: click selects it all (or drag to mark
                -- part of it), Ctrl+C copies. Addons cannot copy for you.
                local box=CreateFrame("Frame",nil,content); box:SetPoint("TOPLEFT",0,-y); box:SetSize(inner-150,lines*16+12); FT:Panel(box); FT:Paint(box,{.04,.035,.03,1},{.35,.29,.18,1})
                local edit=CreateFrame("EditBox",nil,box); edit:SetMultiLine(true); edit:SetAutoFocus(false)
                edit:SetFont("Fonts\\ARIALN.TTF",13,""); edit:SetTextColor(.62,.87,.62)
                edit:SetPoint("TOPLEFT",8,-6); edit:SetPoint("BOTTOMRIGHT",-8,4); edit:SetText(code)
                local hint=FT:Label(content,"Click, then Ctrl+C",12); hint:SetPoint("TOPLEFT",box,"TOPRIGHT",12,-4); hint:SetWidth(130); hint:SetTextColor(.66,.59,.48)
                local check=content:CreateTexture(nil,"OVERLAY"); check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); check:SetSize(16,16); check:SetPoint("RIGHT",hint,"LEFT",-2,0); check:Hide()
                local function reset() hint:SetText("Click, then Ctrl+C"); hint:SetTextColor(.66,.59,.48); check:Hide() end
                edit:SetScript("OnTextChanged",function(owner,user) if user then owner:SetText(code); owner:HighlightText() end end)
                edit:SetScript("OnEditFocusGained",function(owner) owner:HighlightText(); hint:SetText("Ctrl+C to copy"); hint:SetTextColor(1,.82,0) end)
                edit:SetScript("OnEditFocusLost",function(owner) owner:HighlightText(0,0); reset() end)
                edit:SetScript("OnEscapePressed",function(owner) owner:ClearFocus() end)
                edit:HookScript("OnKeyDown",function(_,key)
                    if key=="C" and IsControlKeyDown and IsControlKeyDown() then
                        hint:SetText("Copied"); hint:SetTextColor(.45,.9,.45); check:Show()
                        local mine={}; edit.copyToken=mine
                        C_Timer.After(2,function() if edit.copyToken==mine then if edit:HasFocus() then hint:SetText("Ctrl+C to copy"); hint:SetTextColor(1,.82,0); check:Hide() else reset() end end end)
                    end
                end)
                FT:Tooltip(edit,title,"Click to select it all, or drag to mark part of it. Then Ctrl+C to copy and paste it into a macro.")
                y=y+math.max(lines*16+12,58)+14
            end
            y=y+8
        end
        content:SetHeight(y)
    end
    self.frame:Show()
end
FT:RegisterModule("MacroGuide",G)
