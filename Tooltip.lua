local _,FT=...
local Tip={originals={}}
local positions={"Default","Top left","Top right","Bottom left","Bottom right"}
local orders={"NLT","NTL","LNT","LTN","TNL","TLN"}
-- Player tooltip layout: ordered parts, each shown or hidden and either on
-- its own line or joined to the line above. Guild and Target keep their
-- older on/off switches (s.guild, s.target) so presets and old profiles work.
local partKeys={"name","guild","level","race","class","faction","target"}
Tip.partKeys=partKeys
Tip.partLabels={name="Name",guild="Guild",level="Level",race="Race",class="Class",faction="Faction",target="Target"}
local iconPlaces={off=true,beforeName=true,afterName=true,beforeGuild=true,afterGuild=true}
Tip.iconPlaces=iconPlaces
-- Today's layout: name + guild, then level race class, then the target and
-- the faction line; old "row order" choices are converted once.
local function defaultLayout(order)
    local blocks={N={{"name",false},{"guild",true}},L={{"level",false},{"race",true},{"class",true}},T={{"target",false}}}
    local layout={}
    for kind in (order or "NLT"):gmatch(".") do
        for _,part in ipairs(blocks[kind] or {}) do layout[#layout+1]={key=part[1],show=true,join=part[2]} end
    end
    layout[#layout+1]={key="faction",show=true,join=false}
    return layout
end
function Tip:Settings()
    if type(FT.db.tooltip)~="table" then FT.db.tooltip={} end
    local s=FT.db.tooltip
    if s.target==nil then
        -- Legacy builds stored this switch under System.
        s.target=FT.db.system~=nil and FT.db.system.tooltipTarget==true
    end
    if s.guild==nil then s.guild=false end
    if s.guildFactionIcon==nil then s.guildFactionIcon=false end
    if s.guildFactionColor==nil then s.guildFactionColor=false end
    if s.guildIconPosition~="after" then s.guildIconPosition="before" end
    if s.healthBar==nil then s.healthBar=true end
    if not s.position then s.position="Default" end
    if not s.order then s.order="NLT" end
    local valid=false
    for _,order in ipairs(orders) do if s.order==order then valid=true;break end end
    if not valid then s.order="NLT" end
    -- Faction icon placement (replaces "icon by guild").
    if not iconPlaces[s.factionIcon] then
        s.factionIcon=s.guildFactionIcon and (s.guildIconPosition=="after" and "afterGuild" or "beforeGuild") or "off"
    end
    s.guildFactionIcon=s.factionIcon~="off"
    -- Layout: keep known parts once each, add any missing part at the end.
    local layout,seen={},{}
    for _,entry in ipairs(type(s.layout)=="table" and s.layout or {}) do
        if type(entry)=="table" and self.partLabels[entry.key] and not seen[entry.key] then
            seen[entry.key]=true
            layout[#layout+1]={key=entry.key,show=entry.show~=false,join=entry.join==true and entry.key~="target"}
        end
    end
    if #layout==0 then layout=defaultLayout(s.order); seen={} ; for _,e in ipairs(layout) do seen[e.key]=true end end
    for _,key in ipairs(partKeys) do if not seen[key] then layout[#layout+1]={key=key,show=true,join=false} end end
    s.layout=layout
    if type(s.offsetX)~="number" then s.offsetX=0 end
    if type(s.offsetY)~="number" then s.offsetY=0 end
    if type(s.x)~="number" or type(s.y)~="number" then s.x=nil;s.y=nil end
    for _,part in ipairs({"name","details","targetSize"}) do
        if type(s[part])~="number" then s[part]=0 end
        s[part]=math.max(0,math.min(32,math.floor(s[part])))
    end
    return s
end
-- Whether a part is switched on (guild and target use their own switches).
function Tip:PartShown(entry)
    local s=self:Settings()
    if entry.key=="guild" then return s.guild end
    if entry.key=="target" then return s.target end
    return entry.show
end
local function hex(r,g,b) return string.format("|cff%02x%02x%02x",math.floor((r or 1)*255+.5),math.floor((g or 1)*255+.5),math.floor((b or 1)*255+.5)) end
Tip.hex=hex
-- The faction badge as inline texture text, sized from the name font.
function Tip:FactionIcon(faction,size)
    if faction~="Horde" and faction~="Alliance" then return nil end
    return "|TInterface\\TargetingFrame\\UI-PVP-"..faction..":"..size..":"..size..":0:0:64:64:0:40:0:40|t"
end
-- parts: key -> colored text (nil when unknown). icon: faction badge text.
-- Returns lines: { text=, name=bool, details=bool, target=bool, guildOnName=bool }.
function Tip:Compose(parts,icon)
    local s=self:Settings()
    parts=setmetatable({},{__index=parts})
    local hasGuild=s.guild and parts.guild and parts.guild~=""
    if icon and s.factionIcon~="off" then
        local place=s.factionIcon
        -- Without a (shown) guild, guild placements fall back to after the name.
        if (place=="beforeGuild" or place=="afterGuild") and not hasGuild then place="afterName" end
        if place=="beforeName" then parts.name=icon.." "..(parts.name or "")
        elseif place=="afterName" then parts.name=(parts.name or "").." "..icon
        elseif place=="beforeGuild" then parts.guild=icon.." "..parts.guild
        elseif place=="afterGuild" then parts.guild=parts.guild.." "..icon end
    end
    local lines={}
    for _,entry in ipairs(s.layout) do
        local text=parts[entry.key]
        if self:PartShown(entry) and text and text~="" then
            local line=lines[#lines]
            if entry.join and line and not line.target then
                line.text=line.text.." "..text
            else
                line={text=text}; lines[#lines+1]=line
            end
            if entry.key=="name" then line.name=true end
            if entry.key=="level" or entry.key=="race" or entry.key=="class" then line.details=true end
            if entry.key=="level" then line.level=true end
            if entry.key=="target" then line.target=true end
            if entry.key=="guild" then line.guild=true end
        end
    end
    if parts.suffix then
        local host
        for _,line in ipairs(lines) do if line.level then host=line; break end end
        if not host then for _,line in ipairs(lines) do if line.details then host=line; break end end end
        if host then host.text=host.text.." "..parts.suffix end
    end
    for _,line in ipairs(lines) do line.guildOnName=line.name and line.guild end
    return lines
end
function Tip:ApplyTooltip(tip)
    if not tip or not tip.GetName then return end
    if tip.ftAddonHelp then return end
    local s=self:Settings(); local prefix=tip:GetName()
    if not prefix then return end
    for index=1,(tip.NumLines and tip:NumLines() or 0) do
        for _,side in ipairs({"Left","Right"}) do
            local region=_G[prefix.."Text"..side..index]
            if region and region.GetFont and region.SetFont then
                local original=self.originals[region]
                if not original then
                    local file,size,flags=region:GetFont()
                    if file and size then original={file,size,flags or ""}; self.originals[region]=original end
                end
                if original then
                    local size=index==(tip.ftNameLine or 1) and s.name or
                        index==(tip.ftDetailsLine or 2) and s.details or
                        index==tip.ftTargetLine and s.targetSize or s.details
                    region:SetFont(original[1],size>0 and size or original[2],original[3])
                end
            end
        end
    end
    -- Keep long guild names beside the player name instead of letting the
    -- first row grow across the screen. Each update starts from the saved
    -- name size above, so a later short name is never left shrunken.
    if tip.ftGuildOnName and tip.ftNameLine then
        local region=_G[prefix.."TextLeft"..tip.ftNameLine]
        if region and region.GetStringWidth and region.GetFont and region.SetFont then
            local file,size,flags=region:GetFont()
            if file and size then
                local maxWidth=math.min(420,(UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1000)*.45)
                while size>8 and region:GetStringWidth()>maxWidth do
                    size=size-1
                    region:SetFont(file,size,flags or "")
                end
            end
        end
    end
    local bar=tip.StatusBar or GameTooltipStatusBar
    if bar and bar.SetAlpha then bar:SetAlpha(s.healthBar and 1 or 0) end
end
function Tip:RestoreTooltipFont(tip)
    local prefix=tip and tip.GetName and tip:GetName()
    if not prefix then return end
    for index=1,(tip.NumLines and tip:NumLines() or 0) do
        for _,side in ipairs({"Left","Right"}) do
            local region=_G[prefix.."Text"..side..index]
            local original=region and self.originals[region]
            if original then region:SetFont(original[1],original[2],original[3]) end
        end
    end
end
function Tip:Anchor(tip)
    if not tip or InCombatLockdown() then return end
    local s=self:Settings()
    if s.x and s.y then
        local width,height=UIParent:GetWidth(),UIParent:GetHeight()
        local x=s.x*(s.screenWidth and width/s.screenWidth or 1)
        local y=s.y*(s.screenHeight and height/s.screenHeight or 1)
        tip:ClearAllPoints();tip:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
        return
    end
    if s.position=="Default" then return end
    local point=({["Top left"]="TOPLEFT",["Top right"]="TOPRIGHT",["Bottom left"]="BOTTOMLEFT",["Bottom right"]="BOTTOMRIGHT"})[s.position]
    if not point then return end
    tip:ClearAllPoints()
    local x=point:find("LEFT",1,true) and 24+s.offsetX or -24+s.offsetX
    local y=point:find("TOP",1,true) and -24+s.offsetY or 24+s.offsetY
    tip:SetPoint(point,UIParent,point,x,y)
end
function Tip:MovePreview()
    if not self.previewFrame then
        local p=CreateFrame("Frame","ForeverToolsTooltipMover",UIParent)
        self.previewFrame=p;p:SetSize(230,68);p:SetFrameStrata("FULLSCREEN_DIALOG");p:SetClampedToScreen(true);p:EnableMouse(true)
        if p.SetDontSavePosition then p:SetDontSavePosition(true) end
        FT:Panel(p)
        local title=FT:Label(p,"Tooltip preview",15,true);title:SetPoint("TOPLEFT",12,-10)
        local hint=FT:Label(p,"Drag to move",12);hint:SetPoint("BOTTOMLEFT",12,10)
        p:RegisterForDrag("LeftButton")
        p:SetScript("OnDragStart",function()
            local cx,cy=p:GetCenter(); if not cx then return end
            local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
            self.dragX,self.dragY=cx-x/scale,cy-y/scale;self.dragging=true
        end)
        p:SetScript("OnDragStop",function() self:UpdateMove();self.dragging=false end)
        p:SetScript("OnUpdate",function() self:UpdateMove() end)
    end
    local p=self.previewFrame;local s=self:Settings()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local x=s.x and s.x*(s.screenWidth and w/s.screenWidth or 1) or w-145
    local y=s.y and s.y*(s.screenHeight and h/s.screenHeight or 1) or 95
    p:ClearAllPoints();p:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
    p:Show()
end
function Tip:UpdateMove()
    if not self.dragging then return end
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    x=math.max(115,math.min(w-115,x/scale+self.dragX))
    y=math.max(34,math.min(h-34,y/scale+self.dragY))
    local s=self:Settings();s.x=x;s.y=y;s.screenWidth=w;s.screenHeight=h
    self.previewFrame:ClearAllPoints();self.previewFrame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
end
function Tip:SetMoving(value)
    if self.dragging then self:UpdateMove() end
    self.dragging=false;self.moving=value==true
    if self.moving then self:MovePreview() elseif self.previewFrame then self.previewFrame:Hide() end
    self:Refresh()
end
local iconChoices={{"off","Off"},{"beforeName","Before name"},{"afterName","After name"},{"beforeGuild","Before guild"},{"afterGuild","After guild"}}
function Tip:MoveLayout(key,delta)
    local layout=self:Settings().layout
    for i,entry in ipairs(layout) do
        if entry.key==key then
            local j=i+delta
            if j>=1 and j<=#layout then layout[i],layout[j]=layout[j],layout[i] end
            break
        end
    end
    self:Refresh()
end
function Tip:TogglePart(key)
    local s=self:Settings()
    if key=="guild" then s.guild=not s.guild
    elseif key=="target" then s.target=not s.target
    else for _,entry in ipairs(s.layout) do if entry.key==key then entry.show=not entry.show end end end
    self:Refresh()
end
function Tip:ToggleJoin(key)
    for _,entry in ipairs(self:Settings().layout) do if entry.key==key and key~="target" then entry.join=not entry.join end end
    self:Refresh()
end
-- Sample parts from your own character for the live preview.
function Tip:SampleParts()
    local name=UnitName and UnitName("player") or "Player"
    local level=UnitLevel and UnitLevel("player") or 1
    local race=UnitRace and UnitRace("player") or "Human"
    local label,class=UnitClass("player")
    local faction,factionName=UnitFactionGroup and UnitFactionGroup("player")
    local guild=GetGuildInfo and GetGuildInfo("player")
    local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
    if not readable(name) then name="Player" end
    if not readable(guild) or guild==nil or guild=="" then guild="Guild Name" end
    local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    local s=self:Settings()
    return {
        name="|cffffffff"..name.."|r",
        guild=(s.guildFactionColor and (faction=="Horde" and "|cffff5a5a" or "|cff4a9eff") or "|cffffffff").."<"..guild..">|r",
        level="|cffffffffLevel "..tostring(readable(level) and level or 1).."|r",
        race="|cffffffff"..tostring(readable(race) and race or "Human").."|r",
        class=(c and hex(c.r,c.g,c.b) or "|cffffffff")..tostring(readable(label) and label or "Class").."|r",
        suffix="|cffffffff(Player)|r",
        faction="|cffffffff"..tostring(readable(factionName) and factionName or "Horde").."|r",
        target="|cffc9a0ffTarget: |cffffffffNone|r",
    },readable(faction) and faction or "Horde"
end
function Tip:RenderPreview()
    local box=self.preview; if not box then return end
    local s=self:Settings()
    local parts,faction=self:SampleParts()
    local nameSize=s.name>0 and s.name or 14
    local lines=self:Compose(parts,self:FactionIcon(faction,math.max(18,math.floor(nameSize*1.3+.5))))
    local headerFont,_,headerFlags=(GameTooltipHeaderText or GameFontNormal):GetFont()
    local bodyFont,_,bodyFlags=(GameTooltipText or GameFontNormal):GetFont()
    local y=-10
    for i=1,8 do
        local fs=box.lines[i]
        local line=lines[i]
        if line then
            local size=line.name and nameSize or line.target and (s.targetSize>0 and s.targetSize or 12) or (s.details>0 and s.details or 12)
            fs:SetFont(line.name and headerFont or bodyFont,size,(line.name and headerFlags or bodyFlags) or "")
            fs:SetText(line.text); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT",box,"TOPLEFT",10,y); fs:Show()
            y=y-(fs:GetStringHeight() or size)-3
        else fs:Hide() end
    end
    box:SetHeight(math.max(40,-y+8))
end
function Tip:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    -- Layout rows follow the saved order, top to bottom.
    for i,entry in ipairs(s.layout) do
        local row=self.rows[entry.key]
        local top=-self.layoutTop-(i-1)*40
        row.toggle:ClearAllPoints(); row.toggle:SetPoint("TOPLEFT",self.frame,"TOPLEFT",24,top)
        local shown=self:PartShown(entry)
        row.toggle.label:SetText(self.partLabels[entry.key]..": "..(shown and "On" or "Off")); FT:SetSelected(row.toggle,shown)
        row.up:SetEnabled(i>1); row.up:SetAlpha(i>1 and 1 or .35)
        row.down:SetEnabled(i<#s.layout); row.down:SetAlpha(i<#s.layout and 1 or .35)
        local canJoin=entry.key~="target" and i>1
        row.join:SetEnabled(canJoin); row.join:SetAlpha(canJoin and (shown and 1 or .6) or .35)
        row.join.label:SetText(entry.join and canJoin and "Same line" or "New line"); FT:SetSelected(row.join,entry.join and canJoin)
    end
    local iconLabel="Off"; for _,c in ipairs(iconChoices) do if c[1]==s.factionIcon then iconLabel=c[2] end end
    self.factionIcon.value=s.factionIcon; self.factionIcon.label:SetText("Faction icon: "..iconLabel)
    self.health.label:SetText("Tooltip health bar: "..(s.healthBar and "On" or "Off")); FT:SetSelected(self.health,s.healthBar)
    self.guildColor.label:SetText("Faction-colored guild name: "..(s.guildFactionColor and "On" or "Off")); FT:SetSelected(self.guildColor,s.guildFactionColor)
    self.guildColor:SetAlpha(s.guild and 1 or .5)
    for _,part in ipairs({"name","details","targetSize"}) do
        self.sizes[part].label:SetText((s[part]==0 and "Default" or s[part].." px"))
    end
    self.moveButton.label:SetText(self.moving and "Moving tooltip — click to lock" or "Move tooltip freely")
    FT:SetSelected(self.moveButton,self.moving)
    local ids=FT.modules.System:Settings().spellID==true
    self.ids.label:SetText("Show tooltip IDs: "..(ids and "On" or "Off")); FT:SetSelected(self.ids,ids)
    self:RenderPreview()
end
function Tip:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTooltip","ForeverTools | Tooltip",1116,600)
        self.frame=frame
        local intro=FT:Label(frame,"Build your player tooltip on the left and watch the preview. Everything else is on the right.",14)
        intro:SetPoint("TOPLEFT",24,-62); intro:SetTextColor(.78,.74,.86)
        local function section(x,y,title,hint)
            local h=FT:Label(frame,title,16,true); h:SetPoint("TOPLEFT",x,y); h:SetTextColor(.82,.68,1)
            local t=FT:Label(frame,hint,12); t:SetPoint("TOPLEFT",x,y-22); t:SetWidth(512); t:SetTextColor(.66,.57,.77)
        end
        section(24,-98,"Layout","Turn parts on or off, order them with the arrows, and choose Same line to join a part to the one above.")
        self.layoutTop=148
        self.rows={}
        for _,key in ipairs(partKeys) do
            local row={}
            local label=self.partLabels[key]
            row.toggle=FT:QuietButton(frame,"",290,34,key=="target" and "mouseover" or key=="guild" and "party" or key=="class" and "classes" or key=="faction" and "map" or "tooltip")
            row.toggle:SetScript("OnClick",function() self:TogglePart(key) end)
            FT:Tooltip(row.toggle,label,({name="The player's name.",guild="The player's guild, if they have one.",level="The player's level.",race="The player's race.",class="The player's class, in class color.",faction="The Horde or Alliance line.",target="Who the player is targeting. Always on its own line."})[key])
            -- Blizzard's own friends-list arrow, referenced from the game, not bundled.
            row.up=FT:QuietButton(frame,"",40,34)
            row.up.arrow=row.up:CreateTexture(nil,"ARTWORK"); row.up.arrow:SetPoint("CENTER")
            row.up.arrow:SetAtlas("friendslist-categorybutton-arrow-down",true); row.up.arrow:SetRotation(math.pi)
            row.up:SetPoint("LEFT",row.toggle,"RIGHT",6,0)
            row.up:SetScript("OnClick",function() self:MoveLayout(key,-1) end)
            FT:Tooltip(row.up,"Move up","Show "..label:lower().." earlier.")
            row.down=FT:QuietButton(frame,"",40,34)
            row.down.arrow=row.down:CreateTexture(nil,"ARTWORK"); row.down.arrow:SetPoint("CENTER")
            row.down.arrow:SetAtlas("friendslist-categorybutton-arrow-down",true)
            row.down:SetPoint("LEFT",row.up,"RIGHT",6,0)
            row.down:SetScript("OnClick",function() self:MoveLayout(key,1) end)
            FT:Tooltip(row.down,"Move down","Show "..label:lower().." later.")
            row.join=FT:QuietButton(frame,"",124,34,"move")
            row.join:SetPoint("LEFT",row.down,"RIGHT",6,0)
            if row.join.SetMotionScriptsWhileDisabled then row.join:SetMotionScriptsWhileDisabled(true) end
            row.join:SetScript("OnClick",function() self:ToggleJoin(key) end)
            FT:Tooltip(row.join,"Same line or new line",key=="target" and "The target always gets its own line." or "Same line puts "..label:lower().." on the line above, after what is already there. New line starts a new line.")
            self.rows[key]=row
        end
        local previewTop=self.layoutTop+#partKeys*40+10
        local ph=FT:Label(frame,"Preview",16,true); ph:SetPoint("TOPLEFT",24,-previewTop); ph:SetTextColor(.82,.68,1)
        local pnote=FT:Label(frame,"Uses your own character. Other players' tooltips follow the same layout.",12); pnote:SetPoint("TOPLEFT",24,-previewTop-22); pnote:SetTextColor(.66,.57,.77)
        local box=CreateFrame("Frame",nil,frame); box:SetPoint("TOPLEFT",24,-previewTop-44); box:SetWidth(512)
        FT:RoundedFill(box,0,0,0,.85)
        box.lines={}
        for i=1,8 do local fs=box:CreateFontString(nil,"OVERLAY"); fs:SetFont(FT.bodyFont,12,""); fs:SetJustifyH("LEFT"); fs:SetWidth(492); box.lines[i]=fs end
        self.preview=box
        local divider=frame:CreateTexture(nil,"ARTWORK"); divider:SetColorTexture(.30,.23,.46,.6); divider:SetWidth(1)
        divider:SetPoint("TOPLEFT",552,-96); divider:SetPoint("BOTTOMLEFT",552,24)
        -- Right column.
        local R=580
        section(R,-98,"Extras","Faction icon, guild color, health bar and IDs.")
        self.factionIcon=FT:Dropdown(frame,512,function()
            local s=self:Settings(); local list={}
            for _,c in ipairs(iconChoices) do
                local guildPlace=c[1]=="beforeGuild" or c[1]=="afterGuild"
                list[#list+1]={value=c[1],label="Faction icon: "..c[2],icon="Interface\\Icons\\INV_Misc_Map_01",disabled=guildPlace and not s.guild,
                    tooltip=guildPlace and (s.guild and "Players without a guild get the icon after their name." or "Turn on Guild in the layout to use this. Players without a guild get the icon after their name.") or nil}
            end
            return list
        end,function(value) self:Settings().factionIcon=value; self:Refresh() end,"map")
        self.factionIcon:SetPoint("TOPLEFT",R,-148); self.factionIcon:SetHeight(34)
        FT:Tooltip(self.factionIcon,"Faction icon","Show a small Horde or Alliance badge next to the player's name or guild.")
        self.guildColor=FT:QuietButton(frame,"",512,34,"party"); self.guildColor:SetPoint("TOPLEFT",R,-188)
        self.guildColor:SetScript("OnClick",function() local s=self:Settings();s.guildFactionColor=not s.guildFactionColor;self:Refresh() end)
        FT:Tooltip(self.guildColor,"Faction-colored guild name","Color the guild name red for Horde and blue for Alliance. Off keeps it white.")
        self.health=FT:QuietButton(frame,"",512,34,"generic"); self.health:SetPoint("TOPLEFT",R,-228)
        self.health:SetScript("OnClick",function() local s=self:Settings();s.healthBar=not s.healthBar;self:Refresh();if GameTooltip then self:ApplyTooltip(GameTooltip) end end)
        FT:Tooltip(self.health,"Tooltip health bar","Show or hide the small health bar under unit tooltips.")
        -- Stored under System for profile compatibility; it belongs with tooltips.
        self.ids=FT:QuietButton(frame,"",512,34,"spellID"); self.ids:SetPoint("TOPLEFT",R,-268)
        self.ids:SetScript("OnClick",function() local s=FT.modules.System:Settings();s.spellID=not s.spellID;self:Refresh() end)
        FT:Tooltip(self.ids,"Show tooltip IDs","Show spell, item, quest and achievement IDs at the bottom of tooltips.")
        local line=frame:CreateTexture(nil,"ARTWORK"); line:SetColorTexture(.30,.23,.46,.6); line:SetSize(512,1); line:SetPoint("TOPLEFT",R,-318)
        section(R,-330,"Text size","0 keeps Blizzard's size. The preview shows your sizes.")
        self.sizes={}
        for i,entry in ipairs({{"name","Name line"},{"details","Other lines"},{"targetSize","Target line"}}) do
            local part=entry[1]; local y=-384-(i-1)*42
            local label=FT:Label(frame,entry[2],14);label:SetPoint("TOPLEFT",R,y-6)
            local minus=FT:QuietButton(frame,"−",34,30,"reset");minus:SetPoint("TOPLEFT",R+300,y)
            local value=FT:QuietButton(frame,"",120,30,"fonts");value:SetPoint("LEFT",minus,"RIGHT",4,0)
            local plus=FT:QuietButton(frame,"+",34,30,"add");plus:SetPoint("LEFT",value,"RIGHT",4,0)
            self.sizes[part]=value
            for _,step in ipairs({{minus,-1},{plus,1}}) do
                step[1]:SetScript("OnClick",function()
                    local s=self:Settings(); local current=s[part]==0 and (part=="name" and 16 or 12) or s[part]
                    s[part]=math.max(8,math.min(32,current+step[2]));self:Refresh();if GameTooltip then self:ApplyTooltip(GameTooltip) end
                end)
            end
            value:SetScript("OnClick",function()
                local s=self:Settings();if s[part]==0 then return end
                FT:Confirm("Restore Blizzard's font size for "..entry[2]:lower().."?",function()
                    s[part]=0;self:Refresh();if GameTooltip then self:ApplyTooltip(GameTooltip) end
                end)
            end)
            FT:Tooltip(value,entry[2].." size","Use + and − to change the size. Click the number to go back to Blizzard's size (asks first).")
        end
        local line2=frame:CreateTexture(nil,"ARTWORK"); line2:SetColorTexture(.30,.23,.46,.6); line2:SetSize(512,1); line2:SetPoint("TOPLEFT",R,-516)
        section(R,-528,"Position","Where tooltips appear on screen.")
        self.moveButton=FT:QuietButton(frame,"",512,34,"move");self.moveButton:SetPoint("TOPLEFT",R,-578)
        self.moveButton:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.moveButton,"Move tooltip","Click to unlock, drag the preview where tooltips should appear, then click again to lock it.")
        frame:SetHeight(math.max(previewTop+44+150,578+34)+30)
        frame:HookScript("OnHide",function() self:SetMoving(false) end)
    end
    self:Refresh();self.frame:Show()
end
FT:RegisterModule("Tooltip",Tip)
local hook=CreateFrame("Frame");hook:RegisterEvent("PLAYER_LOGIN")
hook:SetScript("OnEvent",function()
    if GameTooltip_SetDefaultAnchor and hooksecurefunc then
        hooksecurefunc("GameTooltip_SetDefaultAnchor",function(tip) Tip:Anchor(tip) end)
    end
end)
