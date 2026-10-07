local _,FT=...
local System={}
local function usable(value)
    return (not issecretvalue or not issecretvalue(value)) and value~=nil
end
local function tooltipUnit(tip)
    if not tip.GetUnit then return end
    local ok,_,unit=pcall(tip.GetUnit,tip)
    if ok and usable(unit) and type(unit)=="string" then return unit end
end
local function displayedUnit(tip)
    local unit=tooltipUnit(tip)
    if unit then return unit end
    if not tip.IsTooltipType or not Enum or not Enum.TooltipDataType then return end
    local ok,isUnit=pcall(tip.IsTooltipType,tip,Enum.TooltipDataType.Unit)
    if not ok or isUnit~=true then return end
    local owner=tip.GetOwner and tip:GetOwner()
    for _=1,4 do
        if not owner then break end
        if usable(owner.unit) and type(owner.unit)=="string" then return owner.unit end
        owner=owner.GetParent and owner:GetParent()
    end
    return "mouseover"
end
local function safeCall(fn,unit)
    if not fn or not usable(unit) then return end
    local ok,a,b=pcall(fn,unit)
    if ok and usable(a) and (b==nil or usable(b)) then return a,b end
end
function System:Settings()
    if type(FT.db.system)~="table" then FT.db.system={} end
    local s=FT.db.system
    if s.spellID==nil then s.spellID=false end
    if s.minimapIcons==nil then s.minimapIcons=false end
    -- Forever shows coordinates under the minimap by default; match that.
    if s.coordinates==nil then s.coordinates=true end
    return s
end
function System:Apply()
    local s=self:Settings()
    -- Forever's own option, rather than hiding an unrelated minimap region.
    if s.coordinates~=nil and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
        if C_CVar.GetCVar("minimapShowPlayerCoords")~=nil then C_CVar.SetCVar("minimapShowPlayerCoords",s.coordinates and "1" or "0") end
    elseif s.coordinates~=nil and GetCVar and SetCVar and GetCVar("minimapShowPlayerCoords")~=nil then
        SetCVar("minimapShowPlayerCoords",s.coordinates and "1" or "0")
    end
    FT:UpdateMinimap(); if FT.modules.MinimapIcons then FT.modules.MinimapIcons:Apply() end
    self:Refresh()
end
-- The switch lists. Each is a page of its group (see Hubs.lua): General and
-- Loot and merchant under System, Minimap and Quests and loot rolls under
-- On-screen info, Group role and Death glow under Combat, Keybind tools under
-- Keybinds. Each page is its own module for FT:OpenModule and search.
local pages={
    {key="SystemGeneral",title="General",hint="Messages at login, first-time setup, resetting, and help when something breaks.",items={
        {"welcome","Welcome message","welcome","Print a short \"ForeverTools loaded\" line in chat when you log in."},
        {"hiddenUIHint","Show key when interface is hidden","INV_Misc_Eye_01","When you hide the interface (ALT-Z by default), show for a few seconds which key brings it back. The line fades by itself, steps aside for a screenshot and returns a couple of seconds later, and does not show during cutscenes."},
        {"whatsNew","What's new after updates","INV_Misc_Note_05","After an update, show a short summary of what changed, once. Turn off to never show it."},
        {"setup","Run first-time setup again","INV_Misc_Book_09","Open the welcome setup to pick a starting look. Your current settings stay until you apply one."},
        {"reset","Reset all settings","reset","Return every ForeverTools setting to its default (all off) and reload. Saved profiles, custom macros and learned flight times are kept. Asks first."},
        {"scriptErrors","Show Lua errors","errors","Show or hide the game's Lua error pop-ups. Hiding them does not fix the errors. This is the game's own setting."},
        {"bugReport","Copy bug report","INV_Misc_Note_04","Opens a box with your addon version, game build, enabled features and recent ForeverTools errors, ready to copy. Nothing is sent anywhere."},
    }},
    {key="SystemMinimap",title="Minimap",hint="The ForeverTools button, coordinates, and tidying other addons' buttons.",items={
        {"minimap","ForeverTools minimap button","map","Show or hide the ForeverTools button on the minimap. You can always open the settings with /ft."},
        {"coordinates","Minimap coordinates","INV_Misc_Spyglass_02","Show or hide the game's own coordinates below the minimap."},
        {"minimapIcons","Group minimap buttons","INV_Misc_Bag_08","Put other addons' minimap buttons into one small menu. Click its icon to open it. A few buttons may stay on the minimap. Do not use it together with another addon that collects minimap buttons."},
        {"minimapIconsVertical","Grouped buttons","INV_Misc_Bag_08","How the grouped buttons are laid out in their menu. Horizontal: side by side, a new row after 6. Vertical: one below the other, a new column after 6. Click to switch. Needs Group minimap buttons on."},
    }},
    {key="SystemGameplay",title="Group role",hint="Your role when you join a group.",items={
        {"autoRole","Set role when joining a group","Ability_Warrior_DefensiveStance","When you join a group, set your role (tank, healer or damage) from your talents. Changing it yourself always wins. Feral druids are asked once."},
    }},
    {key="SystemDeath",title="Death glow",hint="How the screen looks while you are dead or a ghost.",items={
        {"deathGlow","Death glow","Spell_Holy_Resurrection","The glowing, washed-out screen while you are dead or a ghost. On is the game's default; Off keeps the world looking normal. This is the game's own setting (the same as /console ffxDeath 0 or 1), so it applies to all your characters."},
    }},
    {key="SystemQuests",title="Quests and loot rolls",hint="The quest tracker at login, and where loot-roll windows appear.",items={
        {"objectives","Quest objectives","INV_Misc_Note_01","How the quest tracker starts when you log in or reload: Default (the game decides), Collapsed, Open, or Hidden. Opening or closing it yourself is kept until the next login. Hidden keeps it off the screen."},
        {"lootMove","Move loot rolls","move","Show a sample loot-roll window you can drag. Click again to lock it. Until you move it, loot rolls appear where the game puts them."},
        {"lootDefault","Use the game's loot-roll position","reset","Forget your moved position and let the game place loot rolls again."},
    }},
    {key="SystemMerchant",title="Loot and merchant",hint="Looting faster, and selling and repairing when you visit a merchant.",items={
        {"fastLoot","Faster looting","INV_Misc_Bag_10","Loot everything the moment a corpse is opened, instead of waiting for each slot. Works when auto loot is on (the game's Auto Loot option, or holding the auto-loot key). Items that ask before binding still ask."},
        {"autoSell","Auto-sell grey items","INV_Misc_Coin_05","Sell grey (junk) items when you open a merchant, at most 12 per visit so every one can be bought back. If you carry more, the rest is sold next time."},
        {"sellWhite","Also sell white gear","INV_Misc_Coin_03","When auto-sell runs, also sell white weapons and armor you have no use for. Kept: gear for an empty slot, gear in an equipment set and, up to level 20, anything better than what you wear. Never sold: potions, food, reagents, ammo, trade goods, quest items, tools, shirts, tabards, bags, rings, necklaces and trinkets. Sold gear can be bought back."},
        {"autoRepair","Auto-repair","Trade_BlackSmithing","Repair all your gear when you visit a merchant who can repair."},
        {"guildRepair","Use guild funds for repairs first","INV_Shirt_GuildTabard_01","When auto-repair runs, use guild bank repair money if your guild allows it, otherwise your own gold."},
    }},
    {key="SystemKeybinds",title="Keybind tools",hint="Bind action buttons by hovering them, and put earlier keybinds back.",items={
        {"quickKeybind","Quick keybind mode (/kb)","keybind","Hover any action button and press a key to bind it. Escape on a bound button unbinds it. Your keybinds are copied first, so you can save, go back or discard. You can also type /kb."},
        {"backups","Backups and restore","profiles","Put back earlier keybinds, action bars and spell binds, or save a copy now. The list holds your full backups (saved by you, or automatically before an import) and your last keybind sessions. Hover one to see what it puts back. The last 10 of each are kept on this computer."},
    }},
}
System.pages=pages
local toggles={hiddenUIHint=true,fastLoot=true,welcome=true,whatsNew=true,minimap=true,coordinates=true,minimapIcons=true,autoRole=true,lootMove=true,autoSell=true,autoRepair=true,guildRepair=true,sellWhite=true,scriptErrors=true,deathGlow=true}
-- Switches that are the game's own settings: read and written directly,
-- never stored by ForeverTools. "Unavailable" when the game has no such setting.
local gameOptions={scriptErrors="scriptErrors",deathGlow="ffxDeath"}
local function gameOption(name)
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    if not getter then return nil end
    local ok,value=pcall(getter,name)
    if ok and type(value)=="string" then return value end
end
System.gameOptions=gameOptions
function System:Values()
    local s=self:Settings()
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    local coords=s.coordinates
    if coords==nil then coords=not getter or getter("minimapShowPlayerCoords")=="1" end
    return {welcome=FT.db.welcome==true,whatsNew=s.hideWhatsNew~=true,minimap=FT.db.minimapEnabled~=false,coordinates=coords,
        minimapIcons=s.minimapIcons==true,lootMove=FT.modules.LootRoll.moving==true,scriptErrors=gameOption("scriptErrors")=="1",deathGlow=gameOption("ffxDeath")~="0",
        hiddenUIHint=s.hiddenUIHint==true,autoRole=s.autoRole==true,fastLoot=s.fastLoot==true,autoSell=s.autoSell==true,sellWhite=s.sellWhite==true,autoRepair=s.autoRepair==true,guildRepair=s.guildRepair==true}
end
function System:Refresh()
    if not self.buttons then return end
    local values=self:Values()
    for key,button in pairs(self.buttons) do
        if toggles[key] then
            local missing=gameOptions[key] and gameOption(gameOptions[key])==nil
            button.label:SetText(button.title..": "..(missing and "Unavailable" or (values[key] and "On" or "Off")))
            FT:SetSelected(button,values[key])
            if gameOptions[key] then button:SetEnabled(not missing); button:SetAlpha(missing and .45 or 1) end
        end
        if key=="minimapIconsVertical" then
            local vertical=self:Settings().minimapIconsVertical==true
            button.label:SetText("Grouped buttons: "..(vertical and "Vertical" or "Horizontal"))
            button:SetEnabled(values.minimapIcons); button:SetAlpha(values.minimapIcons and 1 or .45)
        end
        if key=="guildRepair" then button:SetEnabled(values.autoRepair); button:SetAlpha(values.autoRepair and 1 or .45) end
        if key=="sellWhite" then button:SetEnabled(values.autoSell); button:SetAlpha(values.autoSell and 1 or .45) end
        if key=="backups" then
            button.label:SetText("Backups and restore ("..FT.modules.Backups:Count()..")")
        end
        if key=="lootDefault" then
            local custom=FT.modules.LootRoll:Settings().custom==true
            button:SetEnabled(custom); button:SetAlpha(custom and 1 or .45)
        end
        if key=="leveling" then
            local leveling=FT.modules.Leveling
            button.label:SetText("Leveling stats: "..(leveling and leveling:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="fps" then
            local fps=FT.modules.QualityOfLife
            button.label:SetText("FPS counter: "..(fps and fps.Settings and fps:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="objectives" then
            local mode=FT.modules.QuestTracker and FT.modules.QuestTracker:Mode() or "default"
            button.label:SetText("Quest objectives: "..({default="Default",collapsed="Collapsed on login",open="Open on login",hidden="Hidden"})[mode])
            if not button.arrow then button.arrow=FT:Label(button,"v",12); button.arrow:SetPoint("RIGHT",-12,0) end
            FT:SetSelected(button,mode~="default")
        end
        if key=="rareAlert" then
            local rare=FT.modules.RareAlert
            button.label:SetText("Rare alerts: "..(rare and rare:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="threat" then
            local threat=FT.modules.Threat; local t=threat and threat:Settings()
            button.label:SetText("Threat meter: "..(t and (t.enabled or t.text) and "On" or "Off").." — settings")
        end
        if key=="sellMarks" then
            local marks=FT.modules.SellMarks
            button.label:SetText("Always-sell marks: "..(marks and marks:On() and ("On ("..marks:Count()..")") or "Off").." — settings")
        end
        if key=="smartKey" then
            local smart=FT.modules.SmartKey
            button.label:SetText("Smart interact key: "..(smart and smart:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="spellBinds" then
            local binds=FT.modules.SpellBinds
            button.label:SetText("Spell binds: "..(binds and binds:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="totems" then
            local totems=FT.modules.Totems
            local ts=totems and totems:Settings()
            button.label:SetText("Totems: "..(ts and (ts.range or ts.leftBehind) and "On" or "Off").." — settings")
        end
        if key=="wheelCasting" then
            local wheel=FT.modules.CustomKeybinds
            button.label:SetText("Mouse-wheel casting: "..(wheel and wheel:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="flightTimer" then
            local flight=FT.modules.FlightTimer
            button.label:SetText("Flight timer: "..(flight and flight:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="autoRole" then
            local reminder=FT.modules.BuffReminder
            if reminder then
                local current=reminder:CurrentSpec()
                for _,spec in ipairs(reminder:TalentSpecs()) do
                    if spec.name==current then button.icon:SetTexture(spec.icon);break end
                end
            end
        end
    end
    -- The sidebar of an open switch page shows the new state too.
    if FT.RefreshDock then
        for _,page in ipairs(pages) do
            local module=FT.modules[page.key]
            if module and module.frame and module.frame:IsShown() then FT:RefreshDock(module.frame) end
        end
    end
end
function System:Click(key)
    if key=="minimapIcons" then FT.modules.MinimapIcons:Toggle();return end
    if key=="minimapIconsVertical" then FT.modules.MinimapIcons:ToggleVertical();return end
    if key=="flightTimer" then FT:OpenModule("FlightTimer");return end
    if key=="fps" then FT:OpenModule("QualityOfLife");return end
    if key=="rareAlert" then FT:OpenModule("RareAlert");return end
    if key=="threat" then FT:OpenModule("Threat");return end
    if key=="totems" then FT:OpenModule("Totems");return end
    if key=="spellBinds" then FT:OpenModule("SpellBinds");return end
    if key=="smartKey" then FT:OpenModule("SmartKey");return end
    if key=="sellMarks" then FT:OpenModule("SellMarks");return end
    if key=="wheelCasting" then FT:OpenModule("CustomKeybinds");return end
    if key=="leveling" then FT:OpenModule("Leveling");return end
    if key=="movers" then FT:OpenModule("Movers");return end
    if key=="bugReport" then FT.modules.BugReport:Open();return end
    if key=="quickKeybind" then FT.modules.QuickBind:Open();return end
    if key=="backups" then
        if not self.buttons.backups then FT:OpenModule("SystemKeybinds") end
        if self.buttons.backups then FT.modules.Backups:Show(self.buttons.backups) end
        return
    end
    if key=="setup" then FT.modules.Onboarding:ShowSetup(true);return end
    if key=="reset" then FT.modules.Profiles:ResetSettings();return end
    if key=="lootMove" then FT.modules.LootRoll:ToggleMove(); return end
    if key=="objectives" then
        local button=self.buttons.objectives
        button.options=function()
            local icon="Interface\\Icons\\INV_Misc_Note_01"
            return {
                {value="default",label="Default",icon=icon,tooltip="The game's own behavior."},
                {value="collapsed",label="Collapsed on login",icon=icon,tooltip="Collapsed after every login and reload. Opening it yourself is kept until then."},
                {value="open",label="Open on login",icon=icon,tooltip="Open after every login and reload. Closing it yourself is kept until then."},
                {value="hidden",label="Hidden",icon=icon,tooltip="Keep the tracker off the screen."},
            }
        end
        button.value=FT.modules.QuestTracker:Mode()
        button.menuWidth=button:GetWidth()
        button.onSelect=function(value)
            self:Settings().objectives=value~="default" and value or nil
            FT.modules.QuestTracker:Apply(); self:Refresh()
        end
        FT:ShowChoices(button); return
    end
    if key=="lootDefault" then FT.modules.LootRoll:UseDefault(); self:Refresh(); return end
    if gameOptions[key] then
        local name=gameOptions[key]
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        local now=gameOption(name)
        -- Anything but "0" counts as on, the way the game reads it.
        if set and now~=nil then pcall(set,name,now~="0" and "0" or "1") end
        self:Refresh();return
    end
    local s=self:Settings()
    if key=="welcome" then FT.db.welcome=FT.db.welcome~=true
    elseif key=="minimap" then FT.db.minimapEnabled=FT.db.minimapEnabled==false
    elseif key=="whatsNew" then s.hideWhatsNew=not (s.hideWhatsNew==true)
    elseif key=="coordinates" then
        if s.coordinates==nil then local get=(C_CVar and C_CVar.GetCVar) or GetCVar; s.coordinates=not get or get("minimapShowPlayerCoords")=="1" end
        s.coordinates=not s.coordinates
    else s[key]=not (s[key]==true) end
    self:Apply()
end
local function buildPage(page)
    local module={}
    function module:Open()
        if not self.frame then
            local height=62+34+#page.items*40+22
            -- As wide as the other pages of its group.
            local hub=FT.HubOf and FT:HubOf(page.key)
            local width=hub and hub.width or 520
            self.frame=FT:Window("ForeverTools"..page.key,page.title,width,height)
            local hint=FT:Label(self.frame,page.hint or "",12); hint:SetPoint("TOPLEFT",24,-66); hint:SetWidth(width-48); hint:SetTextColor(.66,.59,.48)
            if hint.SetWordWrap then hint:SetWordWrap(true) end
            if page.key=="SystemQuests" then self.frame:HookScript("OnHide",function() FT.modules.LootRoll:FinishMove() end) end
            for i,entry in ipairs(page.items) do
                local key=entry[1]
                local b=FT:QuietButton(self.frame,entry[2],width-48,32,entry[3]); b.title=entry[2]
                b:SetPoint("TOPLEFT",24,-62-34-(i-1)*40); System.buttons[key]=b
                b:SetScript("OnClick",function() System:Click(key) end)
                FT:Tooltip(b,entry[2],entry[4])
            end
            if page.key=="SystemMinimap" then FT.minimapToggle=System.buttons.minimap end
            if page.key=="SystemGeneral" then FT.welcomeToggle=System.buttons.welcome end
        end
        System:Refresh(); self.frame:Show()
    end
    -- The switches are System's: refreshing the page refreshes them all.
    function module:Refresh() System:Refresh() end
    FT:RegisterModule(page.key,module)
end
-- "System" on the main menu is a group of pages (Hubs.lua).
System.redirect=true
function System:Open() FT:OpenHub("SystemHub") end
System.buttons={}
for _,page in ipairs(pages) do buildPage(page) end
function System:WatchSpellTooltip(tip)
    if not tip.ftSpellIDHooked and tip.HookScript then
        tip.ftSpellIDHooked=true
        tip:HookScript("OnTooltipCleared",function(owner) owner.ftSpellID=nil;owner.ftOtherIDs=nil;owner.ftSpellGeneration=(owner.ftSpellGeneration or 0)+1 end)
    end
end
function System:QueueSpellID(tip,id,kind)
    if not self:Settings().spellID or not tip or not usable(id) or type(id)~="number" then return end
    self:WatchSpellTooltip(tip)
    local generation=tip.ftSpellGeneration or 0
    C_Timer.After(0,function()
        if (tip.ftSpellGeneration or 0)==generation and tip:IsShown() then self:SpellID(tip,id,kind) end
    end)
end
function System:SpellID(tip,id,kind,building)
    if not self:Settings().spellID or not tip or tip.ftAddonHelp or not usable(id) or type(id)~="number" or id<=0 then return end
    kind=kind or "Spell"
    if kind=="Spell" and tip.ftSpellID==id then return end
    if kind~="Spell" and tip.ftOtherIDs and tip.ftOtherIDs[kind]==id then return end
    self:WatchSpellTooltip(tip)
    tip:AddLine(kind.." ID: "..id,.65,.65,.65)
    if kind=="Spell" then tip.ftSpellID=id else tip.ftOtherIDs=tip.ftOtherIDs or {};tip.ftOtherIDs[kind]=id end
    if not building and tip.Show then tip:Show() end
end
function System:TooltipClass(tip)
    -- Once our layout has rebuilt the tooltip, the class is already its own
    -- part. Blizzard refreshes tooltips while they are shown; adding the class
    -- again after the race would show it twice.
    if tip.ftPlayerLayout then return end
    if not tip.GetUnit or not UnitRace or not UnitIsPlayer then return end
    local unit=tooltipUnit(tip); if not unit or not safeCall(UnitIsPlayer,unit) then return end
    local race=safeCall(UnitRace,unit); local label,class=safeCall(UnitClass,unit)
    local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if not race or not label or not c then return end
    local color=string.format("|cff%02x%02x%02x",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5))
    local raceLine
    for i=2,(tip.NumLines and tip:NumLines() or 15) do
        local line=_G[(tip:GetName() or "GameTooltip").."TextLeft"..i]
        local text=line and line:GetText()
        if usable(text) and type(text)=="string" then
            local plain=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            local first,last=plain:find(race,1,true)
            if first then
                local suffix=plain:sub(last+1)
                local trimmed=suffix:match("^%s*(.*)$")
                if trimmed:sub(1,#label)==label then suffix=trimmed:sub(#label+1) end
                line:SetText(plain:sub(1,last).." "..color..label.."|r"..suffix)
                raceLine=i
                break
            end
        end
    end
    if not raceLine then return end
    -- Some clients also supply a standalone class row. Remove only an exact
    -- class-name duplicate below the race; keep guilds, titles and other data.
    for i=raceLine+1,(tip.NumLines and tip:NumLines() or 15) do
        local prefix=tip:GetName() or "GameTooltip"
        local line=_G[prefix.."TextLeft"..i]
        local right=_G[prefix.."TextRight"..i]
        local text=line and line:GetText()
        local other=right and right:GetText()
        if usable(text) and (not other or usable(other)) and type(text)=="string" and (not other or other=="") then
            local plain=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
            if plain==label then line:SetText("") end
        end
    end
end
function System:TooltipLayout(tip)
    if tip.ftPlayerLayout or not tip.ClearLines or not tip.GetUnit or not GetGuildInfo then return end
    local unit=tooltipUnit(tip)
    if not unit or not safeCall(UnitIsPlayer,unit) then return end
    local prefix=tip:GetName() or "GameTooltip"
    local function plain(text) return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$") end
    local guild=safeCall(GetGuildInfo,unit)
    local race=safeCall(UnitRace,unit)
    local class=safeCall(UnitClass,unit)
    local rows={}; local details
    for i=1,tip:NumLines() do
        local left=_G[prefix.."TextLeft"..i]; local right=_G[prefix.."TextRight"..i]
        local text=left and left:GetText()
        local rightText=right and right:GetText()
        if text and not usable(text) then return end
        if rightText and not usable(rightText) then return end
        local clean=plain(text)
        if i==1 then rows[1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1}}
        elseif race and clean:find(race,1,true) and not details then details=text
        elseif clean~="" and clean~=class and not (guild and (clean==guild or clean=="<"..guild..">")) and not clean:match("^Target:") then
            rows[#rows+1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1},right=rightText,rightColor=right and right.GetTextColor and {right:GetTextColor()} or {1,1,1}}
        end
    end
    if not rows[1] or not details then return end
    local tipModule=FT.modules.Tooltip
    local tipSettings=tipModule:Settings()
    local heading=rows[1].text
    local nameColor=rows[1].color
    local friendly=unit=="player"
    if UnitIsFriend then
        local ok,value=pcall(UnitIsFriend,"player",unit)
        if ok and usable(value) and value then friendly=true end
    end
    if UnitIsUnit then
        local ok,value=pcall(UnitIsUnit,"player",unit)
        if ok and usable(value) and value then friendly=true end
    end
    if friendly then
        heading=heading:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        nameColor={1,1,1}
    end
    local faction,factionName=safeCall(UnitFactionGroup,unit)
    -- The faction row ("Horde") becomes its own part; drop it from the extra rows.
    local factionText
    for i=#rows,2,-1 do
        local clean=plain(rows[i].text)
        if (factionName and clean==factionName) or (faction and clean==faction) then
            factionText=rows[i].text; table.remove(rows,i)
        end
    end
    -- Split Blizzard's "Level 3 <race> <class> (Player)" line into parts.
    local parts={name=tipModule.hex(nameColor[1],nameColor[2],nameColor[3])..heading.."|r",faction=tipModule:FactionText(factionText and plain(factionText) or factionName,faction)}
    local detailText=plain(details)
    local level=safeCall(UnitLevel,unit)
    local levelToken=(type(level)=="number" and level>0) and tostring(level) or "??"
    local _,levelEnd=detailText:find(levelToken,1,true)
    local label,classToken=safeCall(UnitClass,unit)
    local rest=levelEnd and detailText:sub(levelEnd+1) or nil
    local classStart,classEnd
    if rest and label then classStart,classEnd=rest:find(label,1,true) end
    if levelEnd and classStart then
        parts.level="|cffffffff"..detailText:sub(1,levelEnd).."|r"
        local raceText=rest:sub(1,classStart-1):match("^%s*(.-)%s*$")
        if raceText=="" then raceText=race or "" end
        parts.race=raceText~="" and ("|cffffffff"..raceText.."|r") or nil
        local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[classToken]
        local suffix=rest:sub(classEnd+1):match("^%s*(.-)%s*$")
        parts.class=(c and tipModule.hex(c.r,c.g,c.b) or "|cffffffff")..label.."|r"
        -- Extra words such as "(Player)" stay at the end of the level line.
        parts.suffix=suffix~="" and ("|cffffffff"..suffix.."|r") or nil
    else
        -- Unknown wording: keep Blizzard's whole line as the Level part.
        parts.level="|cffffffff"..detailText.."|r"
    end
    if guild and guild~="" then
        local color=faction=="Horde" and PLAYER_FACTION_COLOR_HORDE or faction=="Alliance" and PLAYER_FACTION_COLOR_ALLIANCE
        local index=(PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[faction]) or (faction=="Horde" and 0 or faction=="Alliance" and 1)
        color=color or (PLAYER_FACTION_COLORS and index and PLAYER_FACTION_COLORS[index])
        local tag="<"..guild..">"
        -- Faction coloring is optional (off by default); otherwise plain white like Blizzard's guild line.
        if not tipSettings.guildFactionColor then tag="|cffffffff"..tag.."|r"
        elseif color and color.WrapTextInColorCode then tag=color:WrapTextInColorCode(tag)
        elseif color and color.r then tag=tipModule.hex(color.r,color.g,color.b)..tag.."|r"
        else tag="|cffffffff"..tag.."|r" end
        parts.guild=tag
    end
    parts.target="|cffffd100Target: None|r"
    -- The native PvP badge occupies the upper-left of a 64px canvas; crop its padding.
    local headingLine=_G[prefix.."TextLeft1"]
    local _,nativeSize=headingLine:GetFont()
    local size=math.max(22,math.floor((tipSettings.name>0 and tipSettings.name or nativeSize or 14)*1.4+.5))
    local icon=tipModule:FactionIcon(faction,size)
    local lines=tipModule:Compose(parts,icon)
    if #lines==0 then return end
    tip:ClearLines()
    tip.ftNameLine,tip.ftDetailsLine,tip.ftTargetLine=nil,nil,nil
    tip.ftGuildOnName=false
    for _,line in ipairs(lines) do
        tip:AddLine(line.text,1,1,1)
        local index=tip:NumLines()
        if line.name and not tip.ftNameLine then tip.ftNameLine=index end
        if line.details and not line.name and not tip.ftDetailsLine then tip.ftDetailsLine=index end
        if line.target then tip.ftTargetLine=index end
        if line.guildOnName then tip.ftGuildOnName=true end
    end
    tip.ftDetailsLine=tip.ftDetailsLine or -1
    for i=2,#rows do
        local row=rows[i]
        if row.right and row.right~="" and tip.AddDoubleLine then
            tip:AddDoubleLine(row.text,row.right,row.color[1],row.color[2],row.color[3],row.rightColor[1],row.rightColor[2],row.rightColor[3])
        else tip:AddLine(row.text,unpack(row.color)) end
    end
    tip.ftPlayerLayout=true
end
function System:ClearTargetPlayerDisplay(tip)
    if tip.ftTargetAlphaLine then tip.ftTargetAlphaLine:SetAlpha(1);tip.ftTargetAlphaLine=nil end
    if tip.ftTargetYou then tip.ftTargetYou:Hide() end
end
function System:TargetPlayerDisplay(tip,comparison)
    if not issecretvalue or not issecretvalue(comparison) then return end
    local evaluate=C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    local line=tip.ftTargetLine and _G[(tip:GetName() or "GameTooltip").."TextLeft"..tip.ftTargetLine]
    if not evaluate or not line then return end
    local ok,youAlpha,nameAlpha=pcall(function()
        return evaluate(comparison,1,0),evaluate(comparison,0,1)
    end)
    if not ok then return end
    if not tip.ftTargetYou then tip.ftTargetYou=tip:CreateFontString(nil,"OVERLAY") end
    local label=tip.ftTargetYou
    local file,size,flags=line:GetFont()
    label:SetFont(file,size,flags or "")
    label:SetTextColor(1,.82,0)
    label:SetText("Target: |cffff0000You|r")
    label:ClearAllPoints();label:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
    label:SetAlpha(youAlpha);label:Show()
    line:SetAlpha(nameAlpha);tip.ftTargetAlphaLine=line
end
-- The beta's "Press F6 to submit an issue" line (and the gap above it) is
-- added at the bottom of unit tooltips. Our Target line belongs with the
-- unit's own lines, so move it above that footer.
function System:RaiseTargetLine(tip)
    local index=tip.ftTargetLine; if not index or index<3 then return end
    local prefix=tip:GetName() or "GameTooltip"
    local function left(i) return _G[prefix.."TextLeft"..i] end
    local footer
    for i=index-1,2,-1 do
        local line=left(i); local text=line and line:GetText()
        if text~=nil and not usable(text) then return end
        if type(text)=="string" and text:lower():find("to submit an issue",1,true) then footer=i; break end
    end
    if not footer then return end
    -- Take the empty spacer line above the footer with it.
    local above=left(footer-1); local aboveText=above and above:GetText()
    if footer>2 and usable(aboveText) and (aboveText==nil or aboveText=="" or aboveText==" ") then footer=footer-1 end
    -- Shift the lines from the footer down by one and put Target in its place.
    local target=left(index); if not target then return end
    local text=target:GetText(); if not usable(text) then return end
    local r,g,b=target:GetTextColor()
    for i=index,footer+1,-1 do
        local to,from=left(i),left(i-1)
        local t=from:GetText(); if t~=nil and not usable(t) then return end
        local fr,fg,fb=from:GetTextColor()
        to:SetText(t or " "); to:SetTextColor(fr,fg,fb)
    end
    local line=left(footer); line:SetText(text); line:SetTextColor(r,g,b)
    tip.ftTargetLine=footer
end
function System:TooltipTarget(tip)
    self:ClearTargetPlayerDisplay(tip)
    self:TooltipClass(tip)
    self:TooltipLayout(tip)
    FT.modules.Tooltip:ApplyTooltip(tip)
    if not FT.modules.Tooltip:Settings().target or not tip.GetUnit or not UnitExists or tip.ftAddonHelp then return end
    local unit=displayedUnit(tip); if not unit then return end
    local target=unit=="player" and "target" or unit.."target"
    local exists=safeCall(UnitExists,target)
    local targetsPlayer=false
    local comparison
    if UnitIsUnit then
        local ok,result=pcall(UnitIsUnit,target,"player")
        if ok then comparison=result end
        targetsPlayer=ok and usable(result) and result==true
    end
    local ok,name=pcall(UnitName,target)
    local secretName=ok and issecretvalue and issecretvalue(name)
    if secretName and not targetsPlayer then
        local index=tip.ftTargetLine
        local prefix=tip:GetName() or "GameTooltip"
        local left=index and _G[prefix.."TextLeft"..index]
        if not left then
            tip:AddLine("Target: Unavailable",1,.82,0)
            tip.ftTargetLine=tip:NumLines()
            self:RaiseTargetLine(tip)
            left=_G[prefix.."TextLeft"..tip.ftTargetLine]
        end
        local right=_G[prefix.."TextRight"..tip.ftTargetLine]
        if right then right:SetText("") end
        if left then
            local displayed=left.SetFormattedText and pcall(left.SetFormattedText,left,"Target: |cffffffff%s|r",name)
            if not displayed then left:SetText("Target: Unavailable") end
        end
        FT.modules.Tooltip:ApplyTooltip(tip)
        self:TargetPlayerDisplay(tip,comparison)
        return
    end
    local text=targetsPlayer and "You" or (ok and name and name~="" and name or (exists and "Unavailable" or "None"))
    local colored=(targetsPlayer and "|cffff0000" or "|cffffffff")..text.."|r"
    local line=tip.ftTargetLine and _G[(tip:GetName() or "GameTooltip").."TextLeft"..tip.ftTargetLine]
    if line then
        local right=_G[(tip:GetName() or "GameTooltip").."TextRight"..tip.ftTargetLine]
        if right then right:SetText("") end
        line:SetText("Target: "..colored)
    else tip:AddLine("Target: "..colored,1,.82,0); tip.ftTargetLine=tip.NumLines and tip:NumLines(); self:RaiseTargetLine(tip) end
    FT.modules.Tooltip:ApplyTooltip(tip)
    self:TargetPlayerDisplay(tip,comparison)
end
FT:RegisterModule("System",System)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    System:Apply()
    if not GameTooltip or System.hooked then return end
    System.hooked=true
    GameTooltip:HookScript("OnTooltipCleared",function(tip) System:ClearTargetPlayerDisplay(tip);tip.ftTargetLine=nil;tip.ftNameLine=nil;tip.ftDetailsLine=nil;tip.ftPlayerLayout=nil;tip.ftGuildOnName=nil;tip.ftBuffSource=nil;tip.ftAddonHelp=nil;tip.ftSpellID=nil end)
    local function showBuffSource(tip,unit,aura)
        if tip~=GameTooltip or tip.ftBuffSource or not aura then return end
        local caster=aura.sourceUnit
        local source=usable(caster) and type(caster)=="string" and safeCall(UnitName,caster) or nil
        if (not source or source=="") and usable(aura.isFromPlayerOrPlayerPet) and aura.isFromPlayerOrPlayerPet then source="You" end
        if not source or source=="" then return end
        tip.ftBuffSource=true
        tip:AddLine("Cast by: "..source,1,.82,0)
        tip:Show()
    end
    local function buffSourceByIndex(tip,unit,index,filter)
        if not usable(unit) or not usable(index) or not usable(filter) or type(unit)~="string" or type(index)~="number" then return end
        local harmful=filter and type(filter)=="string" and filter:find("HARMFUL",1,true)
        if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,filter or "HELPFUL")
        if ok and aura then if not harmful then showBuffSource(tip,unit,aura) end;System:SpellID(tip,aura.spellId) end
    end
    local function buffSourceByID(tip,unit,id)
        if not usable(unit) or not usable(id) or type(unit)~="string" or not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then return end
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,unit,id)
        if ok and aura then
            if usable(aura.isHelpful) and aura.isHelpful then showBuffSource(tip,unit,aura) end
            System:SpellID(tip,aura.spellId)
        end
    end
    if hooksecurefunc then
        if GameTooltip.SetUnitAura then hooksecurefunc(GameTooltip,"SetUnitAura",buffSourceByIndex) end
        if GameTooltip.SetUnitBuff then hooksecurefunc(GameTooltip,"SetUnitBuff",buffSourceByIndex) end
        if GameTooltip.SetUnitDebuff then hooksecurefunc(GameTooltip,"SetUnitDebuff",function(tip,unit,index) buffSourceByIndex(tip,unit,index,"HARMFUL") end) end
        if GameTooltip.SetUnitAuraByAuraInstanceID then hooksecurefunc(GameTooltip,"SetUnitAuraByAuraInstanceID",buffSourceByID) end
        if GameTooltip.SetUnitBuffByAuraInstanceID then hooksecurefunc(GameTooltip,"SetUnitBuffByAuraInstanceID",buffSourceByID) end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        -- Add IDs during the native build, before its final sizing/anchor pass.
        -- Deferring a frame makes refreshed tooltips alternate between heights.
        for _,kind in ipairs({"Item","Quest","Achievement"}) do
            local dataType=Enum.TooltipDataType[kind]
            local label=kind
            if dataType then TooltipDataProcessor.AddTooltipPostCall(dataType,function(tip,data)
                if data then System:SpellID(tip,data.id,label,true) end
            end) end
        end
        if Enum.TooltipDataType.Spell then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell,function(tip,data) if data then System:SpellID(tip,data.id,"Spell",true) end end)
        end
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tip) if tip==GameTooltip then System:TooltipTarget(tip) end end)
    elseif not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit",function(tip) System:TooltipTarget(tip) end)
    end
    if (not TooltipDataProcessor) and GameTooltip.GetSpell and (not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetSpell")) then
        GameTooltip:HookScript("OnTooltipSetSpell",function(tip) local ok,_,id=pcall(tip.GetSpell,tip);if ok then System:QueueSpellID(tip,id) end end)
    end
    if not TooltipDataProcessor and GameTooltip.GetItem and (not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetItem")) then
        GameTooltip:HookScript("OnTooltipSetItem",function(tip)
            local ok,_,link=pcall(tip.GetItem,tip)
            if ok and usable(link) and type(link)=="string" then
                System:QueueSpellID(tip,tonumber(link:match("item:(%d+)")),"Item")
            end
        end)
    end
    local elapsed=0
    GameTooltip:HookScript("OnUpdate",function(tip,dt)
        elapsed=elapsed+dt
        if elapsed>.2 then
            elapsed=0
            if not tip.ftAddonHelp and tip.IsShown and tip:IsShown() and displayedUnit(tip) then System:TooltipTarget(tip) end
        end
    end)
end)

-- Login establishes membership without changing an existing role.
function System:SuggestedRole()
    local reminder=FT.modules.BuffReminder
    if not reminder then return end
    local best,chosen,tied=0,nil,false
    for _,spec in ipairs(reminder:TalentSpecs()) do
        if spec.points>best then best,chosen,tied=spec.points,spec.name,false
        elseif spec.points==best then tied=true end
    end
    -- A tree you picked yourself (Buff reminders > Your buffs) decides.
    local manual=reminder.ManualSpec and reminder:ManualSpec()
    if manual then chosen=manual
    elseif best==0 or tied then return end
    local class=reminder:Class()
    if class=="Druid" and chosen=="Feral Combat" then return nil,"FERAL" end
    if (class=="Paladin" or class=="Warrior") and chosen=="Protection" then return "TANK" end
    if (class=="Paladin" and chosen=="Holy") or (class=="Priest" and (chosen=="Holy" or chosen=="Discipline")) or
        ((class=="Druid" or class=="Shaman") and chosen=="Restoration") then return "HEALER" end
    return "DAMAGER"
end
function System:ObserveGroupRole(event)
    local grouped=IsInGroup and IsInGroup() or (GetNumGroupMembers and GetNumGroupMembers()>0) or false
    if event=="PLAYER_LOGIN" or self.wasGrouped==nil then self.wasGrouped=grouped;return end
    if not grouped then
        self.feralPending=nil
        if self.rolePrompt then self.rolePrompt:Hide() end
    end
    local joined=grouped and not self.wasGrouped
    self.wasGrouped=grouped -- consume before invoking any role API
    if not joined or not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() or not UnitSetRole then return end
    local role,reason=self:SuggestedRole()
    if reason=="FERAL" then self.feralPending=true;self:CheckFeralPrompt()
    elseif role then self:SetOwnRole(role) end
end
-- Never attempt a protected role setter: pcall alone cannot prevent a
-- Blizzard blocked-action warning for a protected function.
function System:SetOwnRole(role)
    if InCombatLockdown() or not UnitSetRole then return false end
    if isprotectedfunction and isprotectedfunction("UnitSetRole") then return false end
    local ok,result=pcall(UnitSetRole,"player",role)
    return ok and result~=false
end
function System:CheckFeralPrompt()
    if not self.feralPending or not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() then return end
    local kind
    if IsInInstance then local inside;inside,kind=IsInInstance() end
    if kind~="party" and kind~="raid" then return end
    local _,reason=self:SuggestedRole()
    if reason~="FERAL" then self.feralPending=nil;return end
    self.feralPending=nil -- one prompt per group, including dismissal
    if not self.rolePrompt then
        local frame=CreateFrame("Frame","ForeverToolsRoleChoice",UIParent)
        self.rolePrompt=frame
        frame:SetSize(330,132);frame:SetPoint("CENTER",UIParent,"CENTER",0,170)
        frame:SetFrameStrata("DIALOG");FT:Panel(frame);FT:MakeDraggable(frame)
        local title=FT:Label(frame,"Your role for this group?",15)
        title:SetPoint("TOP",0,-18)
        FT:AddClose(frame)
        local note=FT:Label(frame,"Feral can tank or deal damage.",12)
        note:SetPoint("TOP",0,-44)
        for i,entry in ipairs({{"Tank","TANK"},{"Damage","DAMAGER"},{"Skip"}}) do
            local role=entry[2]
            local button=FT:QuietButton(frame,entry[1],94,32)
            button:SetPoint("BOTTOMLEFT",16+(i-1)*102,16)
            button:SetScript("OnClick",function()
                frame:Hide()
                if role and self.wasGrouped and self:Settings().autoRole then
                    if not self:SetOwnRole(role) then
                        print("ForeverTools: Role unchanged. Set it from your player portrait menu.")
                    end
                end
            end)
        end
        UISpecialFrames[#UISpecialFrames+1]="ForeverToolsRoleChoice"
    end
    self.rolePrompt:Show()
end
local roleEvents=CreateFrame("Frame")
roleEvents:RegisterEvent("PLAYER_LOGIN")
roleEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_REGEN_DISABLED","ROLE_CHANGED_INFORM"}) do
    pcall(roleEvents.RegisterEvent,roleEvents,event)
end
roleEvents:SetScript("OnEvent",function(_,event,changedName)
    if event=="PLAYER_LOGIN" or event=="GROUP_ROSTER_UPDATE" then System:ObserveGroupRole(event)
    elseif event=="PLAYER_REGEN_DISABLED" then
        if System.rolePrompt then System.rolePrompt:Hide() end
    elseif event=="ROLE_CHANGED_INFORM" then
        local name=UnitName and UnitName("player")
        local full=GetUnitName and GetUnitName("player",true)
        if usable(changedName) and ((usable(name) and changedName==name) or (usable(full) and changedName==full)) then
            System.feralPending=nil
            if System.rolePrompt then System.rolePrompt:Hide() end
        end
    else System:CheckFeralPrompt() end
end)
