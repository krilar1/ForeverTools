local _,FT=...
local System={}
function System:Settings()
    if type(FT.db.system)~="table" then FT.db.system={} end
    local s=FT.db.system
    if s.tooltipTarget==nil then s.tooltipTarget=true end
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
    local values={welcome=FT.db.welcome~=false,minimap=FT.db.minimapEnabled~=false,coordinates=coords,tooltipTarget=s.tooltipTarget,lootMove=FT.modules.LootRoll.moving}
    for key,button in pairs(self.buttons) do button.label:SetText(button.title..": "..(values[key] and "On" or "Off")); FT:SetSelected(button,values[key]) end
end
function System:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsSystem","ForeverTools | System",500,408); self.buttons={}
        self.frame:HookScript("OnHide",function() FT.modules.LootRoll:FinishMove() end)
        for i,entry in ipairs({{"welcome","Welcome message","welcome"},{"minimap","Minimap icon","map"},{"coordinates","Minimap coordinates","map"},{"tooltipTarget","Tooltip target","mouseover"},{"lootMove","Move loot rolls","move"}}) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",452,46,entry[3]); b.title=entry[2]
            b:SetPoint("TOPLEFT",24,-66-(i-1)*58); self.buttons[key]=b
            b:SetScript("OnClick",function()
                if key=="lootMove" then FT.modules.LootRoll:ToggleMove(); return end
                if key=="welcome" then FT.db.welcome=FT.db.welcome==false
                elseif key=="minimap" then FT.db.minimapEnabled=FT.db.minimapEnabled==false
                else local s=self:Settings(); if key=="coordinates" and s[key]==nil then local get=(C_CVar and C_CVar.GetCVar) or GetCVar; s[key]=not get or get("minimapShowPlayerCoords")=="1" end; s[key]=not s[key] end
                self:Apply()
            end)
            FT:Tooltip(b,entry[2],key=="lootMove" and "Show a draggable loot-roll placeholder, even without active loot. Turn this off to lock its position. Starts just right of screen center; the position saves with your profile. Movement locks in combat." or key=="tooltipTarget" and "Show who a unit is targeting in its tooltip. Your character is displayed as You." or key=="coordinates" and "Show or hide Forever's built-in coordinates below the minimap." or "Show or hide this feature. Your choice is saved in your profile.")
        end
        FT.welcomeToggle=self.buttons.welcome; FT.minimapToggle=self.buttons.minimap
    end
    self:Refresh(); self.frame:Show()
end
function System:TooltipClass(tip)
    if not tip.GetUnit or not UnitRace or not UnitIsPlayer then return end
    local _,unit=tip:GetUnit(); if not unit or not UnitIsPlayer(unit) then return end
    local race=UnitRace(unit); local label,class=UnitClass(unit)
    local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if not race or not label or not c then return end
    local color=string.format("|cff%02x%02x%02x",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5))
    local raceLine
    for i=2,(tip.NumLines and tip:NumLines() or 15) do
        local line=_G[(tip:GetName() or "GameTooltip").."TextLeft"..i]
        local text=line and line:GetText()
        if type(text)=="string" then
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
        if type(text)=="string" and (not other or other=="") then
            local plain=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
            if plain==label then line:SetText("") end
        end
    end
end
function System:TooltipLayout(tip)
    if tip.ftPlayerLayout or not tip.ClearLines or not tip.GetUnit or not GetGuildInfo then return end
    local _,unit=tip:GetUnit()
    if not unit or not UnitIsPlayer(unit) then return end
    local prefix=tip:GetName() or "GameTooltip"
    local function plain(text) return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$") end
    local guild=GetGuildInfo(unit)
    local race=UnitRace(unit)
    local class=UnitClass(unit)
    local rows={}; local details
    for i=1,tip:NumLines() do
        local left=_G[prefix.."TextLeft"..i]; local right=_G[prefix.."TextRight"..i]
        local text=left and left:GetText(); local clean=plain(text)
        if i==1 then rows[1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1}}
        elseif race and clean:find(race,1,true) and not details then details=text
        elseif clean~="" and clean~=class and not (guild and (clean==guild or clean=="<"..guild..">")) and not clean:match("^Target:") then
            rows[#rows+1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1},right=right and right:GetText(),rightColor=right and right.GetTextColor and {right:GetTextColor()} or {1,1,1}}
        end
    end
    if not rows[1] or not details then return end
    local heading=rows[1].text
    if guild and guild~="" then
        local faction=UnitFactionGroup and UnitFactionGroup(unit)
        local color=faction=="Horde" and PLAYER_FACTION_COLOR_HORDE or faction=="Alliance" and PLAYER_FACTION_COLOR_ALLIANCE
        local index=(PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[faction]) or (faction=="Horde" and 0 or faction=="Alliance" and 1)
        color=color or (PLAYER_FACTION_COLORS and index and PLAYER_FACTION_COLORS[index])
        local tag="<"..guild..">"
        if color and color.WrapTextInColorCode then tag=color:WrapTextInColorCode(tag)
        elseif color and color.r then tag=string.format("|cff%02x%02x%02x%s|r",math.floor(color.r*255+.5),math.floor(color.g*255+.5),math.floor(color.b*255+.5),tag) end
        heading=heading.." "..tag
    end
    tip:ClearLines()
    tip:AddLine(heading,unpack(rows[1].color))
    tip:AddLine(details,1,1,1)
    if self:Settings().tooltipTarget then tip:AddLine("Target: None",.79,.63,1); tip.ftTargetLine=3 end
    for i=2,#rows do
        local row=rows[i]
        if row.right and row.right~="" and tip.AddDoubleLine then
            tip:AddDoubleLine(row.text,row.right,row.color[1],row.color[2],row.color[3],row.rightColor[1],row.rightColor[2],row.rightColor[3])
        else tip:AddLine(row.text,unpack(row.color)) end
    end
    tip.ftPlayerLayout=true
end
function System:TooltipTarget(tip)
    self:TooltipClass(tip)
    self:TooltipLayout(tip)
    if not self:Settings().tooltipTarget or not tip.GetUnit or not UnitExists then return end
    local _,unit=tip:GetUnit(); if not unit or not UnitExists(unit) then return end
    local target=unit.."target"
    local text="None"
    local targetsPlayer=UnitExists(target) and UnitIsUnit(target,"player")
    if UnitExists(target) then text=targetsPlayer and "You" or (UnitName(target) or "Unknown") end
    local colored=(targetsPlayer and "|cffff0000" or "|cffffffff")..text.."|r"
    local line=tip.ftTargetLine and _G[(tip:GetName() or "GameTooltip").."TextLeft"..tip.ftTargetLine]
    if line then line:SetText("Target: "..colored)
    else tip:AddLine("Target: "..colored,.79,.63,1); tip.ftTargetLine=tip.NumLines and tip:NumLines() end
end
FT:RegisterModule("System",System)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    System:Apply()
    if not GameTooltip or System.hooked then return end
    System.hooked=true
    GameTooltip:HookScript("OnTooltipCleared",function(tip) tip.ftTargetLine=nil; tip.ftPlayerLayout=nil end)
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tip) if tip==GameTooltip then System:TooltipTarget(tip) end end)
    elseif not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit",function(tip) System:TooltipTarget(tip) end)
    end
    local elapsed=0
    GameTooltip:HookScript("OnUpdate",function(tip,dt) elapsed=elapsed+dt; if elapsed>.2 then elapsed=0; if tip.ftTargetLine then System:TooltipTarget(tip) end end end)
end)
