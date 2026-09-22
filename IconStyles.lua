local _, FT = ...
local Skins = { records = {}, iconOwners = {} }
local presets = {
    {value="dark", label="Dark mode", color={0,0,0}, border={0,0,0}, transparency=100, shadow=true},
    {value="soft", label="Soft shadow", color={0.04,0.04,0.05}, border={0.26,0.21,0.17}, transparency=66, shadow=true},
    {value="charcoal", label="Charcoal", color={0.10,0.10,0.12}, border={0.32,0.30,0.28}, transparency=52, shadow=false},
    {value="purple", label="Purple dusk", color={0.13,0.07,0.20}, border={0.46,0.31,0.66}, transparency=60, shadow=true},
    {value="class", label="Class colors"},
    {value="silver", label="Silver", color={.12,.12,.12}, border={.8,.8,.8}, transparency=85, shadow=false},
    {value="warm", label="Warm bronze", color={.12,.06,.02}, border={.65,.4,.18}, transparency=85, shadow=false},
    {value="custom", label="Custom"},
}
Skins.presets=presets
local bars={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarLeftButton","MultiBarRightButton","MultiBar5Button","MultiBar6Button","MultiBar7Button","PetActionButton","StanceButton","PossessButton"}
function Skins:Settings()
    if type(FT.db.iconStyles)~="table" then FT.db.iconStyles={} end
    local s=FT.db.iconStyles
    if type(s.actions)~="boolean" then s.actions=true end
    if type(s.buffs)~="boolean" then s.buffs=false end
    if type(s.shadow)~="boolean" then s.shadow=true end
    s.opacity=type(s.opacity)=="number" and math.max(0,math.min(.9,s.opacity)) or 0
    if type(s.color)~="table" then s.color={0,0,0} end
    for i=1,3 do s.color[i]=type(s.color[i])=="number" and math.max(0,math.min(1,s.color[i])) or 0 end
    if type(s.borderColor)~="table" then s.borderColor={0,0,0} end
    for i=1,3 do s.borderColor[i]=type(s.borderColor[i])=="number" and math.max(0,math.min(1,s.borderColor[i])) or 0 end
    if not s.preset then s.preset="dark" end
    if s.preset == "class" then
        local _, class = UnitClass("player")
        local c = (RAID_CLASS_COLORS or {})[class]
        if c then s.borderColor={c.r,c.g,c.b}; s.color={c.r,c.g,c.b} end
    end
    return s
end
function Skins:Area(key)
    local root=self:Settings(); root.areas=type(root.areas)=="table" and root.areas or {}
    local s=root.areas[key]
    if type(s)~="table" then
        s={preset=root.preset,opacity=root.opacity,shadow=root.shadow,color={unpack(root.color)},borderColor={unpack(root.borderColor)},thickness=1,borderOpacity=1,rares=false,elites=false}
        root.areas[key]=s
    end
    s.color=type(s.color)=="table" and s.color or {0,0,0}; s.borderColor=type(s.borderColor)=="table" and s.borderColor or {0,0,0}
    s.opacity=tonumber(s.opacity) or 0; s.thickness=math.max(1,math.min(6,tonumber(s.thickness) or 1)); s.borderOpacity=math.max(0,math.min(1,tonumber(s.borderOpacity) or 1))
    if s.preset=="class" then local _,class=UnitClass("player"); local c=(RAID_CLASS_COLORS or {})[class]; if c then s.borderColor={c.r,c.g,c.b}; s.color={c.r,c.g,c.b} end end
    s[key]=root[key]==true; s.buffs=root.buffs==true
    return s
end
local function textureFrom(candidate, depth)
    if not candidate then return end
    if type(candidate.GetTexture) == "function" then return candidate end
    if (depth or 0) <= 0 then return end
    return textureFrom(candidate.icon, (depth or 0) - 1)
        or textureFrom(candidate.Icon, (depth or 0) - 1)
        or textureFrom(candidate.Texture, (depth or 0) - 1)
end
local function iconOf(button)
    if not button then return end
    local name=button.GetName and button:GetName()
    return textureFrom(button.icon, 2) or textureFrom(button.Icon, 2)
        or textureFrom(name and _G[name.."Icon"], 2)
        or textureFrom(name and _G[name.."IconTexture"], 2)
end
function Skins:Track(button,kind)
    local icon=iconOf(button); if not icon then return end
    if self.iconOwners[icon] and self.iconOwners[icon] ~= button then return end
    self.iconOwners[icon] = button
    local rec=self.records[button]
    if not rec then
        rec={button=button,kind=kind,icon=icon}
        -- This is behind Blizzard's artwork. It never hides, crops, or replaces
        -- normal borders, icons, cooldowns, checked states, labels or debuff borders.
        rec.fill=button:CreateTexture(nil,"BACKGROUND",nil,-7)
        -- Anchor aura overlays to the icon only: timer/count text beneath stays clear.
        rec.fill:SetPoint("TOPLEFT",icon,"TOPLEFT"); rec.fill:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT")
        rec.fill:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
        rec.shadow=button:CreateTexture(nil,"BACKGROUND",nil,-8)
        rec.shadow:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga")
        rec.shadow:SetPoint("TOPLEFT",icon,"TOPLEFT",-1,1); rec.shadow:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
        rec.border = kind == "actions" and (button:GetNormalTexture() or button.normalTexture or (button.GetName and _G[button:GetName() .. "NormalTexture"])) or nil
        if kind == "buffs" then
            rec.nativeBorders={}
            local name=button.GetName and button:GetName()
            local function border(texture,semantic)
                if not texture or not texture.GetVertexColor or rec.nativeBorders[texture] then return end
                rec.nativeBorders[texture]={alpha=texture:GetAlpha(),semantic=semantic}
                if hooksecurefunc then
                    hooksecurefunc(texture,"SetVertexColor",function() if not self.paintingAura then self:Paint(rec) end end)
                    hooksecurefunc(texture,"SetAlpha",function(_,alpha)
                        if self.paintingAura then return end
                        rec.nativeBorders[texture].alpha=alpha; self:Paint(rec)
                    end)
                end
            end
            border(button.DebuffBorder); border(button.Border); border(button.border); border(button.TempEnchantBorder,{.6,0,1})
            border(name and _G[name.."Border"])
            if button.Icon and button.Icon~=icon then border(button.Icon.Border); border(button.Icon.DebuffBorder); border(button.Icon.TempEnchantBorder,{.6,0,1}) end
            rec.auraEdges={}
            for i=1,4 do
                local edge=button:CreateTexture(nil,"OVERLAY",nil,1)
                edge:SetTexture("Interface\\Buttons\\WHITE8x8"); rec.auraEdges[i]=edge
            end
            local e=rec.auraEdges
            e[1]:SetPoint("TOPLEFT",icon,"TOPLEFT"); e[1]:SetPoint("TOPRIGHT",icon,"TOPRIGHT"); e[1]:SetHeight(1)
            e[2]:SetPoint("BOTTOMLEFT",icon,"BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT"); e[2]:SetHeight(1)
            e[3]:SetPoint("TOPLEFT",icon,"TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT",icon,"BOTTOMLEFT"); e[3]:SetWidth(1)
            e[4]:SetPoint("TOPRIGHT",icon,"TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT"); e[4]:SetWidth(1)
            button:HookScript("OnShow",function() self:Paint(rec) end)
        end
        self.records[button]=rec
    end
    self:Paint(rec)
end
function Skins:Paint(rec)
    local s=self:Area(rec.kind)
    local active = rec.kind ~= "buffs" or (rec.button:IsShown() and rec.icon:IsShown() and rec.icon:GetTexture())
    local r,g,b=unpack(s.borderColor)
    self.paintingAura=true
    for texture,original in pairs(rec.nativeBorders or {}) do
        if texture:IsShown() and original.alpha>0 then
            local cr,cg,cb=texture:GetVertexColor()
            if original.semantic then cr,cg,cb=unpack(original.semantic) end
            -- Preserve semantic colored borders (magic, poison, enchants etc.).
            if math.max(cr,cg,cb)-math.min(cr,cg,cb)>.08 then r,g,b=cr,cg,cb end
        end
        texture:SetAlpha(s.buffs and active and 0 or original.alpha)
    end
    self.paintingAura=false
    if not s[rec.kind] or not active then
        rec.fill:Hide(); rec.shadow:Hide()
        for _,edge in ipairs(rec.auraEdges or {}) do edge:Hide() end
        if rec.customBorder then rec.customBorder:Hide() end
        if rec.border and rec.border.SetVertexColor then rec.border:SetVertexColor(1,1,1,1); rec.border:SetAlpha(rec.borderAlpha or 1) end
        return
    end
    for i,edge in ipairs(rec.auraEdges or {}) do
        if i<=2 then edge:SetHeight(s.thickness) else edge:SetWidth(s.thickness) end
        edge:SetVertexColor(r,g,b,s.borderOpacity); edge:Show()
    end
    rec.fill:SetVertexColor(s.color[1],s.color[2],s.color[3],s.opacity); rec.fill:Show()
    rec.shadow:SetVertexColor(0,0,0,s.shadow and math.min(.55,s.opacity+.12) or 0); rec.shadow:SetShown(s.shadow)
    -- Tint Blizzard's existing action-button border itself. No second outline is
    -- layered over the button, so the original corner art and spacing remain.
    if rec.border and rec.border.SetVertexColor then
        rec.borderAlpha=rec.borderAlpha or rec.border:GetAlpha()
        if s.thickness>1 then
            if not rec.customBorder then
                rec.customBorder=CreateFrame("Frame",nil,rec.button,"BackdropTemplate")
                rec.customBorder:SetPoint("TOPLEFT",rec.icon,"TOPLEFT",-1,1); rec.customBorder:SetPoint("BOTTOMRIGHT",rec.icon,"BOTTOMRIGHT",1,-1)
                rec.customBorder:SetFrameLevel(rec.button:GetFrameLevel()+1)
            end
            if rec.customBorder.SetBackdrop then
                rec.customBorder:SetBackdrop({edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=s.thickness*3})
                rec.customBorder:SetBackdropBorderColor(r,g,b,s.borderOpacity)
                rec.border:SetAlpha(0); rec.customBorder:Show()
            end
        else
            if rec.customBorder then rec.customBorder:Hide() end
            rec.border:SetAlpha(rec.borderAlpha*s.borderOpacity)
            rec.border:SetVertexColor(r,g,b,1)
        end
    end
end
function Skins:ScanBuffs(container,depth)
    if not container then return end
    if iconOf(container) then self:Track(container,"buffs") end
    if depth>0 and container.GetChildren then for _,child in ipairs({container:GetChildren()}) do self:ScanBuffs(child,depth-1) end end
end
function Skins:Apply()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.deferred=true; self:Refresh(); return end
    self.deferred=false; local s=self:Settings()
    if s.actions then for _,prefix in ipairs(bars) do for i=1,12 do self:Track(_G[prefix..i],"actions") end end end
    if s.buffs then
        for i=1,40 do self:Track(_G["BuffButton"..i],"buffs"); self:Track(_G["DebuffButton"..i],"buffs") end
        for i=1,3 do self:Track(_G["TempEnchant"..i],"buffs") end
        self:ScanBuffs(BuffFrame,2); self:ScanBuffs(DebuffFrame,2)
    end
    for _,rec in pairs(self.records) do self:Paint(rec) end
    self:Refresh()
end
function Skins:Queue()
    if self.queued then return end
    self.queued=true; C_Timer.After(0,function() self.queued=false; self:Apply() end)
end
FT:RegisterModule("IconStyles",Skins)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ADDON_LOADED","PLAYER_REGEN_ENABLED","ACTIONBAR_SLOT_CHANGED","UPDATE_SHAPESHIFT_FORMS","UNIT_AURA"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit) if event~="UNIT_AURA" or unit=="player" then if FT.dbReady then Skins:Queue() end end end)
