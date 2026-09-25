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
    FT:UpdateMinimap(); if FT.modules.MinimapIcons then FT.modules.MinimapIcons:Apply() end; self:Refresh()
end
-- System is a small hub with four subpages, so no single page lists
-- every switch. Each subpage is its own module for FT:OpenModule and search.
local pages={
    {key="SystemGeneral",title="General",icon="general",description="Welcome message, what's new, first-time setup and resetting settings.",items={
        {"welcome","Welcome message","welcome","Print a short \"ForeverTools loaded\" line in chat when you log in."},
        {"whatsNew","What's new after updates","welcome","After an update, show a short summary of changes once. Turn off to never show it."},
        {"setup","Run first-time setup again","generic","Open the welcome setup to pick a starting preset. Your current settings stay until you apply one."},
        {"reset","Reset all settings","reset","Return every ForeverTools setting to its default (all off) and reload. Saved profiles, custom macros and learned flight times are kept."},
    }},
    {key="SystemMinimap",title="Minimap",icon="map",description="The ForeverTools button, coordinates and grouping other addons' buttons.",items={
        {"minimap","ForeverTools minimap button","map","Show or hide the ForeverTools button on the minimap. You can always open settings with /ft."},
        {"coordinates","Minimap coordinates","map","Show or hide Forever's built-in coordinates below the minimap."},
        {"minimapIcons","Group minimap buttons","map","Put other addons' minimap buttons into one small menu. Click its icon to open it. A few buttons may stay on the minimap. Do not use it together with another button-collector addon."},
    }},
    {key="SystemGameplay",title="Gameplay",icon="classes",description="Quick keybinds, group role, loot, flight timer, leveling stats and merchant helpers.",items={
        {"quickKeybind","Quick keybind mode (/kb)","keybind","Hover any action button and press a key to bind it; Escape on a bound slot unbinds it. A snapshot of your keybinds is taken first, so you can save, revert to a snapshot or discard. You can also type /kb in chat."},
        {"undoKeybinds","Restore keybinds","reset","Pick an earlier keybind session to go back to. Hover a session to see what it changed; choosing it puts back the keybinds you had before it. The last 10 sessions are kept on this computer."},
        {"autoRole","Set role when joining a group","classes","When you join a group, set your role (tank, healer or damage) from your talents. Changing it yourself always wins. Feral druids are asked once."},
        {"lootMove","Move loot rolls","move","Show a sample loot-roll window you can drag. Click again to lock it. Until you move it, loot rolls appear where Blizzard puts them."},
        {"lootDefault","Use Blizzard's loot-roll position","reset","Forget your moved position and let the game place loot rolls again."},
        {"flightTimer","Flight timer settings","fps","Turn the flight countdown on or off, preview and move it, and change its font, size, outline and color."},
        {"leveling","Leveling stats settings","fps","XP per hour, time to level, kills to level and more, on a small movable line and in the XP bar tooltip."},
        {"fastLoot","Faster looting","generic","Loot everything the moment a corpse is opened, instead of waiting for each slot. Works when auto loot is on (the Auto Loot game option, or holding the auto-loot key). Items that ask before binding still ask."},
        {"autoSell","Auto-sell grey items","generic","Sell all grey (junk) items when you open a merchant, like the Sell All Junk button."},
        {"autoRepair","Auto-repair","generic","Repair all your gear when you visit a merchant who can repair."},
        {"guildRepair","Use guild funds for repairs first","party","When auto-repair runs, use guild bank repair money if your guild allows it, otherwise your own gold."},
    }},
    {key="SystemTroubleshooting",title="Troubleshooting",icon="errors",description="Lua error display and a copyable bug report.",items={
        {"scriptErrors","Show Lua errors","errors","Show or hide Lua error popups. Hiding them does not fix the errors."},
        {"bugReport","Copy bug report","errors","Show your addon version, game build, enabled features and recent ForeverTools errors in a box you can copy. Nothing is sent automatically."},
    }},
}
System.pages=pages
local toggles={fastLoot=true,welcome=true,whatsNew=true,minimap=true,coordinates=true,minimapIcons=true,autoRole=true,lootMove=true,autoSell=true,autoRepair=true,guildRepair=true,scriptErrors=true}
function System:Values()
    local s=self:Settings()
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    local coords=s.coordinates
    if coords==nil then coords=not getter or getter("minimapShowPlayerCoords")=="1" end
    return {welcome=FT.db.welcome==true,whatsNew=s.hideWhatsNew~=true,minimap=FT.db.minimapEnabled~=false,coordinates=coords,
        minimapIcons=s.minimapIcons==true,lootMove=FT.modules.LootRoll.moving==true,scriptErrors=getter and getter("scriptErrors")=="1",
        autoRole=s.autoRole==true,fastLoot=s.fastLoot==true,autoSell=s.autoSell==true,autoRepair=s.autoRepair==true,guildRepair=s.guildRepair==true}
end
function System:Refresh()
    if not self.buttons then return end
    local values=self:Values()
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    for key,button in pairs(self.buttons) do
        if toggles[key] then
            button.label:SetText(button.title..": "..(key=="scriptErrors" and not getter and "Unavailable" or (values[key] and "On" or "Off")))
            FT:SetSelected(button,values[key])
        end
        if key=="scriptErrors" then button:SetEnabled(getter~=nil) end
        if key=="guildRepair" then button:SetEnabled(values.autoRepair); button:SetAlpha(values.autoRepair and 1 or .45) end
        if key=="undoKeybinds" then
            local quick=FT.modules.QuickBind; local has=quick and quick:HasUndo()
            button:SetEnabled(has); button:SetAlpha(has and 1 or .45)
            local n=has and #quick:History() or 0
            button.label:SetText(has and ("Restore keybinds ("..n.." session"..(n==1 and "" or "s")..")") or "Restore keybinds (no sessions yet)")
        end
        if key=="lootDefault" then
            local custom=FT.modules.LootRoll:Settings().custom==true
            button:SetEnabled(custom); button:SetAlpha(custom and 1 or .45)
        end
        if key=="leveling" then
            local leveling=FT.modules.Leveling
            button.label:SetText("Leveling stats: "..(leveling and leveling:Settings().enabled and "On" or "Off").." — settings")
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
end
function System:Click(key)
    if key=="minimapIcons" then FT.modules.MinimapIcons:Toggle();return end
    if key=="flightTimer" then FT:OpenModule("FlightTimer");return end
    if key=="leveling" then FT:OpenModule("Leveling");return end
    if key=="bugReport" then FT.modules.BugReport:Open();return end
    if key=="quickKeybind" then FT.modules.QuickBind:Open();return end
    if key=="undoKeybinds" then FT.modules.QuickBind:ShowRestore(self.buttons.undoKeybinds);return end
    if key=="setup" then FT.modules.Onboarding:ShowSetup(true);return end
    if key=="reset" then FT.modules.Profiles:ResetSettings();return end
    if key=="lootMove" then FT.modules.LootRoll:ToggleMove(); return end
    if key=="lootDefault" then FT.modules.LootRoll:UseDefault(); self:Refresh(); return end
    if key=="scriptErrors" then
        local get=(C_CVar and C_CVar.GetCVar) or GetCVar
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        if get and set then set("scriptErrors",get("scriptErrors")=="1" and "0" or "1") end
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
            local height=86+#page.items*52+24
            self.frame=FT:Window("ForeverTools"..page.key,"ForeverTools | System | "..page.title,500,height)
            FT:BackTo(self.frame,"System")
            if page.key=="SystemGameplay" then self.frame:HookScript("OnHide",function() FT.modules.LootRoll:FinishMove() end) end
            for i,entry in ipairs(page.items) do
                local key=entry[1]
                local b=FT:QuietButton(self.frame,entry[2],452,42,entry[3]); b.title=entry[2]
                b:SetPoint("TOPLEFT",24,-66-(i-1)*52); System.buttons[key]=b
                b:SetScript("OnClick",function() System:Click(key) end)
                FT:Tooltip(b,entry[2],entry[4])
            end
            if page.key=="SystemMinimap" then FT.minimapToggle=System.buttons.minimap end
            if page.key=="SystemGeneral" then FT.welcomeToggle=System.buttons.welcome end
        end
        System:Refresh(); self.frame:Show()
    end
    FT:RegisterModule(page.key,module)
end
function System:Open()
    self.buttons=self.buttons or {}
    if not self.frame then
        self.frame=FT:Window("ForeverToolsSystem","ForeverTools | System",500,86+#pages*58+20)
        for i,page in ipairs(pages) do
            local button=FT:QuietButton(self.frame,page.title,452,46,page.icon)
            FT:ButtonIcon(button,page.icon,30)
            button:SetPoint("TOPLEFT",24,-68-(i-1)*58)
            button:SetScript("OnClick",function() FT:OpenModule(page.key) end)
            FT:Tooltip(button,page.title,page.description)
        end
    end
    self.frame:Show()
end
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
    local parts={name=tipModule.hex(nameColor[1],nameColor[2],nameColor[3])..heading.."|r",faction=factionText and ("|cffffffff"..plain(factionText).."|r")}
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
    parts.target="|cffc9a0ffTarget: None|r"
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
    label:SetTextColor(.79,.63,1)
    label:SetText("Target: |cffff0000You|r")
    label:ClearAllPoints();label:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
    label:SetAlpha(youAlpha);label:Show()
    line:SetAlpha(nameAlpha);tip.ftTargetAlphaLine=line
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
            tip:AddLine("Target: Unavailable",.79,.63,1)
            tip.ftTargetLine=tip:NumLines()
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
    else tip:AddLine("Target: "..colored,.79,.63,1); tip.ftTargetLine=tip.NumLines and tip:NumLines() end
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
        tip:AddLine("Cast by: "..source,.79,.63,1)
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
    if best==0 or tied then return end
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
        frame:SetFrameStrata("DIALOG");FT:Panel(frame)
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
