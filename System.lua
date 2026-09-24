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
    if s.tooltipTarget==nil then s.tooltipTarget=true end -- legacy profile migration
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
    FT:UpdateMinimap(); self:Refresh()
end
function System:Refresh()
    if not self.buttons then return end
    local s=self:Settings()
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    local coords=s.coordinates
    if coords==nil then coords=not getter or getter("minimapShowPlayerCoords")=="1" end
    local values={welcome=FT.db.welcome~=false,minimap=FT.db.minimapEnabled~=false,coordinates=coords,lootMove=FT.modules.LootRoll.moving,scriptErrors=getter and getter("scriptErrors")=="1",spellID=s.spellID==true,autoRole=s.autoRole==true}
    for key,button in pairs(self.buttons) do
        button.label:SetText(button.title..": "..(key=="scriptErrors" and not getter and "Unavailable" or (values[key] and "On" or "Off")))
        if key=="flightTimer" then button.label:SetText("Flight timer settings") end
        if key=="scriptErrors" then button:SetEnabled(getter~=nil) end
        FT:SetSelected(button,values[key])
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
function System:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsSystem","ForeverTools | System",500,584); self.buttons={}
        self.frame:HookScript("OnHide",function() FT.modules.LootRoll:FinishMove() end)
        for i,entry in ipairs({{"welcome","Welcome message","welcome"},{"minimap","Minimap icon","map"},{"coordinates","Minimap coordinates","map"},{"lootMove","Move loot rolls","move"},{"scriptErrors","Show Lua errors","errors"},{"spellID","Show spell ID","spellID"},{"autoRole","Set role when joining a group","classes"},{"flightTimer","Flight timer","fps"}}) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",452,46,entry[3]); b.title=entry[2]
            b:SetPoint("TOPLEFT",24,-66-(i-1)*58); self.buttons[key]=b
            b:SetScript("OnClick",function()
                if key=="flightTimer" then FT:OpenModule("FlightTimer");return end
                if key=="lootMove" then FT.modules.LootRoll:ToggleMove(); return end
                if key=="scriptErrors" then
                    local get=(C_CVar and C_CVar.GetCVar) or GetCVar
                    local set=(C_CVar and C_CVar.SetCVar) or SetCVar
                    if get and set then set("scriptErrors",get("scriptErrors")=="1" and "0" or "1") end
                    self:Refresh();return
                end
                if key=="welcome" then FT.db.welcome=FT.db.welcome==false
                elseif key=="minimap" then FT.db.minimapEnabled=FT.db.minimapEnabled==false
                else local s=self:Settings(); if key=="coordinates" and s[key]==nil then local get=(C_CVar and C_CVar.GetCVar) or GetCVar; s[key]=not get or get("minimapShowPlayerCoords")=="1" end; s[key]=not s[key] end
                self:Apply()
            end)
            FT:Tooltip(b,entry[2],key=="flightTimer" and "Preview and move the flight timer. Change its font, size, outline and color." or key=="autoRole" and "Set your role once when joining a group, using your strongest talent tree. Manual changes stay. Equal talent points leave your role unchanged. Feral asks Tank or Damage on your first dungeon entry. Takes effect next time you join." or key=="lootMove" and "Show a draggable loot-roll placeholder, even without active loot. Turn this off to lock its position. Starts just right of screen center; the position saves with your profile. Movement locks in combat." or key=="coordinates" and "Show or hide Forever's built-in coordinates below the minimap." or key=="scriptErrors" and "Controls WoW's scriptErrors setting, the same as /console scriptErrors 1 or 0. Hiding errors does not fix them or suppress Blizzard's blocked-action warning." or "Show or hide this feature. Your choice is saved in your profile.")
        end
        FT.welcomeToggle=self.buttons.welcome; FT.minimapToggle=self.buttons.minimap
    end
    self:Refresh(); self.frame:Show()
end
function System:WatchSpellTooltip(tip)
    if not tip.ftSpellIDHooked and tip.HookScript then
        tip.ftSpellIDHooked=true
        tip:HookScript("OnTooltipCleared",function(owner) owner.ftSpellID=nil;owner.ftSpellGeneration=(owner.ftSpellGeneration or 0)+1 end)
    end
end
function System:QueueSpellID(tip,id)
    if not self:Settings().spellID or not tip or not usable(id) or type(id)~="number" then return end
    self:WatchSpellTooltip(tip)
    local generation=tip.ftSpellGeneration or 0
    C_Timer.After(0,function()
        if (tip.ftSpellGeneration or 0)==generation and tip:IsShown() then self:SpellID(tip,id) end
    end)
end
function System:SpellID(tip,id)
    if not self:Settings().spellID or not tip or tip.ftAddonHelp or not usable(id) or type(id)~="number" or id<=0 then return end
    if tip.ftSpellID==id then return end
    self:WatchSpellTooltip(tip)
    tip:AddLine("Spell ID: "..id,.65,.65,.65)
    tip.ftSpellID=id
    if tip.Show then tip:Show() end
end
function System:TooltipClass(tip)
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
    local heading=rows[1].text
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
        rows[1].color={1,1,1}
    end
    tip.ftGuildOnName=false
    if FT.modules.Tooltip:Settings().guild and guild and guild~="" then
        local faction=safeCall(UnitFactionGroup,unit)
        local color=faction=="Horde" and PLAYER_FACTION_COLOR_HORDE or faction=="Alliance" and PLAYER_FACTION_COLOR_ALLIANCE
        local index=(PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[faction]) or (faction=="Horde" and 0 or faction=="Alliance" and 1)
        color=color or (PLAYER_FACTION_COLORS and index and PLAYER_FACTION_COLORS[index])
        local tag="<"..guild..">"
        local tipSettings=FT.modules.Tooltip:Settings()
        if tipSettings.guildFactionIcon and (faction=="Horde" or faction=="Alliance") then
            -- The native PvP badge occupies the upper-left portion of a
            -- 64px canvas. Crop its padding rather than shrinking the emblem.
            local headingLine=_G[prefix.."TextLeft1"]
            local _,nativeSize=headingLine:GetFont()
            local size=math.max(22,math.floor((tipSettings.name>0 and tipSettings.name or nativeSize or 14)*1.4+.5))
            local icon="|TInterface\\TargetingFrame\\UI-PVP-"..faction..":"..size..":"..size..":0:0:64:64:0:40:0:40|t"
            tag=tipSettings.guildIconPosition=="after" and (tag.." "..icon) or (icon.." "..tag)
        end
        if color and color.WrapTextInColorCode then tag=color:WrapTextInColorCode(tag)
        elseif color and color.r then tag=string.format("|cff%02x%02x%02x%s|r",math.floor(color.r*255+.5),math.floor(color.g*255+.5),math.floor(color.b*255+.5),tag) end
        heading=heading.." "..tag
        tip.ftGuildOnName=true
    end
    tip:ClearLines()
    tip.ftNameLine,tip.ftDetailsLine,tip.ftTargetLine=nil,nil,nil
    for kind in FT.modules.Tooltip:Settings().order:gmatch(".") do
        if kind=="N" then tip:AddLine(heading,unpack(rows[1].color));tip.ftNameLine=tip:NumLines()
        elseif kind=="L" then tip:AddLine(details,1,1,1);tip.ftDetailsLine=tip:NumLines()
        elseif kind=="T" and FT.modules.Tooltip:Settings().target then
            tip:AddLine("Target: None",.79,.63,1);tip.ftTargetLine=tip:NumLines()
        end
    end
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
        if Enum.TooltipDataType.Spell then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell,function(tip,data) if data then System:QueueSpellID(tip,data.id) end end)
        end
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tip) if tip==GameTooltip then System:TooltipTarget(tip) end end)
    elseif not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit",function(tip) System:TooltipTarget(tip) end)
    end
    if (not TooltipDataProcessor) and GameTooltip.GetSpell and (not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetSpell")) then
        GameTooltip:HookScript("OnTooltipSetSpell",function(tip) local ok,_,id=pcall(tip.GetSpell,tip);if ok then System:QueueSpellID(tip,id) end end)
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
        frame:SetSize(330,126);frame:SetPoint("CENTER",UIParent,"CENTER",0,170)
        frame:SetFrameStrata("DIALOG");FT:Panel(frame)
        local title=FT:Label(frame,"Your role for this group?",15)
        title:SetPoint("TOP",0,-16)
        local note=FT:Label(frame,"Feral can tank or deal damage.",12)
        note:SetPoint("TOP",0,-40)
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
