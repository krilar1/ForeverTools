local _,FT=...
local Tip={originals={}}
local positions={"Default","Top left","Top right","Bottom left","Bottom right"}
local orders={"NLT","NTL","LNT","LTN","TNL","TLN"}
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
    if type(s.offsetX)~="number" then s.offsetX=0 end
    if type(s.offsetY)~="number" then s.offsetY=0 end
    if type(s.x)~="number" or type(s.y)~="number" then s.x=nil;s.y=nil end
    for _,part in ipairs({"name","details","targetSize"}) do
        if type(s[part])~="number" then s[part]=0 end
        s[part]=math.max(0,math.min(32,math.floor(s[part])))
    end
    return s
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
function Tip:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.target.label:SetText("Show target: "..(s.target and "On" or "Off"))
    self.guild.label:SetText("Show guild beside name: "..(s.guild and "On" or "Off"))
    self.guildIcon.label:SetText("Faction icon by guild: "..(s.guildFactionIcon and "On" or "Off"))
    self.guildIconPosition.label:SetText("Faction icon: "..(s.guildIconPosition=="after" and "After guild" or "Before guild"))
    self.guildIconPosition:SetEnabled(s.guildFactionIcon)
    self.guildIconPosition:SetAlpha(s.guildFactionIcon and 1 or .45)
    self.health.label:SetText("Tooltip health bar: "..(s.healthBar and "On" or "Off"))
    for _,part in ipairs({"name","details","targetSize"}) do
        self.sizes[part].label:SetText((s[part]==0 and "Default" or s[part].." px"))
    end
    self.moveButton.label:SetText(self.moving and "Moving tooltip — click to lock" or "Move tooltip freely")
    FT:SetSelected(self.moveButton,self.moving)
    local names={N="Name",L="Level",T="Target"}
    self.order.label:SetText("Row order: "..names[s.order:sub(1,1)].." → "..names[s.order:sub(2,2)].." → "..names[s.order:sub(3,3)])
    self.guildColor.label:SetText("Faction-colored guild name: "..(s.guildFactionColor and "On" or "Off"))
    for _,button in ipairs({self.target,self.guild,self.guildIcon,self.guildColor,self.health}) do FT:SetSelected(button,s[button.setting]) end
    local ids=FT.modules.System:Settings().spellID==true
    self.ids.label:SetText("Show tooltip IDs: "..(ids and "On" or "Off")); FT:SetSelected(self.ids,ids)
end
function Tip:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsTooltip","ForeverTools | Tooltip",640,650)
        self.frame=frame
        local header=FT:Label(frame,"Unit tooltip",16,true); header:SetPoint("TOPLEFT",24,-62)
        for i,entry in ipairs({{"target","Show target"},{"guild","Show guild beside name"},{"healthBar","Tooltip health bar"}}) do
            local key=entry[1]
            local b=FT:QuietButton(frame,entry[2],592,34,key=="target" and "mouseover" or "generic")
            b:SetPoint("TOPLEFT",24,-89-(i-1)*40); b.setting=key; self[key=="healthBar" and "health" or key]=b
            b:SetScript("OnClick",function() local s=self:Settings();s[key]=not s[key];self:Refresh();if GameTooltip then self:ApplyTooltip(GameTooltip) end end)
            FT:Tooltip(b,entry[2],key=="healthBar" and "Hide the small health bar attached to unit tooltips." or "Changes this row in player tooltips. Enemy tooltips with protected data retain their native layout.")
        end
        self.guildIcon=FT:QuietButton(frame,"",592,32,"generic");self.guildIcon:SetPoint("TOPLEFT",24,-465);self.guildIcon.setting="guildFactionIcon"
        self.guildIcon:SetScript("OnClick",function() local s=self:Settings();s.guildFactionIcon=not s.guildFactionIcon;self:Refresh() end)
        FT:Tooltip(self.guildIcon,"Faction icon","Show a small Horde or Alliance icon next to the guild name in player tooltips.")
        self.guildIconPosition=FT:QuietButton(frame,"",592,32,"generic");self.guildIconPosition:SetPoint("TOPLEFT",24,-503)
        self.guildIconPosition:SetScript("OnClick",function() local s=self:Settings();s.guildIconPosition=s.guildIconPosition=="after" and "before" or "after";self:Refresh() end)
        FT:Tooltip(self.guildIconPosition,"Faction icon position","Place the faction icon before or after the guild name.")
        self.guildColor=FT:QuietButton(frame,"",592,32,"generic");self.guildColor:SetPoint("TOPLEFT",24,-579);self.guildColor.setting="guildFactionColor"
        self.guildColor:SetScript("OnClick",function() local s=self:Settings();s.guildFactionColor=not s.guildFactionColor;self:Refresh() end)
        FT:Tooltip(self.guildColor,"Faction-colored guild name","Color the guild name red for Horde and blue for Alliance. Off keeps it plain white.")
        -- Stored under System for profile compatibility; it belongs with tooltips.
        self.ids=FT:QuietButton(frame,"",592,32,"spellID");self.ids:SetPoint("TOPLEFT",24,-541)
        self.ids:SetScript("OnClick",function() local s=FT.modules.System:Settings();s.spellID=not s.spellID;self:Refresh() end)
        FT:Tooltip(self.ids,"Show tooltip IDs","Show spell, item, quest and achievement IDs at the bottom of supported tooltips.")
        local sizes=FT:Label(frame,"Font sizes (0 keeps Blizzard's size)",14,true); sizes:SetPoint("TOPLEFT",24,-222)
        self.sizes={}
        for i,entry in ipairs({{"name","Name"},{"details","Level, race and class"},{"targetSize","Target"}}) do
            local part=entry[1]; local y=-251-(i-1)*42
            local label=FT:Label(frame,entry[2],14);label:SetPoint("TOPLEFT",24,y)
            local minus=FT:QuietButton(frame,"−",34,30,"reset");minus:SetPoint("TOPLEFT",395,y+3)
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
                FT:Confirm("Restore Blizzard's font size for "..entry[2].."?",function()
                    s[part]=0;self:Refresh();if GameTooltip then self:ApplyTooltip(GameTooltip) end
                end)
            end)
            FT:Tooltip(value,entry[2].." font size","Click to restore Blizzard's size after confirmation. Use + or − for immediate adjustments.")
        end
        self.order=FT:QuietButton(frame,"",592,32,"move");self.order:SetPoint("TOPLEFT",24,-386)
        self.order:SetScript("OnClick",function()
            local s=self:Settings()
            for i,value in ipairs(orders) do if value==s.order then s.order=orders[i%#orders+1];break end end
            self:Refresh()
        end)
        FT:Tooltip(self.order,"Unit tooltip row order","Cycle the positions of Name, Level and Target. Your choice applies to the next player tooltip.")
        self.moveButton=FT:QuietButton(frame,"",592,34,"move");self.moveButton:SetPoint("TOPLEFT",24,-426)
        self.moveButton:SetScript("OnClick",function() self:SetMoving(not self.moving) end)
        FT:Tooltip(self.moveButton,"Move tooltip","Unlock the preview, drag it where you want tooltips to appear, then click again to lock it. Saves with your profile.")
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
