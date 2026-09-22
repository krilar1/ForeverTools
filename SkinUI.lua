local _,FT=...
local S=FT.modules.IconStyles
local options={{"actions","Action bars"},{"buffs","Buffs / debuffs"}}
for _,entry in ipairs(S.extraOptions) do options[#options+1]=entry end
function S:SetOpacity(value)
    local s=self:Area(self.selected or "actions"); s.opacity=math.max(0,math.min(1,value)); s.preset="custom"; self:Apply()
end
function S:UsePreset(value)
    local s=self:Area(self.selected or "actions")
    for _,p in ipairs(self.presets) do if p.value==value then
        s.preset=value
        if p.color then s.color={unpack(p.color)}; s.borderColor={unpack(p.border)}; s.opacity=1-p.transparency/100; s.shadow=p.shadow end
        if value=="class" then s.opacity=0; s.shadow=false end
    end end
    self:Apply()
end
function S:OpenColorPicker(setting)
    local s=self:Area(self.selected or "actions"); local old={unpack(s[setting])}; local oldPreset=s.preset
    local function change() local r,g,b=ColorPickerFrame:GetColorRGB(); s[setting]={r,g,b}; s.preset="custom"; self:Apply() end
    local function cancel() s[setting]=old; s.preset=oldPreset; self:Apply() end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
    elseif ColorPickerFrame then ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=change; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
end
function S:Refresh()
    if not self.frame then return end
    local key=self.selected or "actions"; local root=self:Settings(); local s=self:Area(key)
    for _,entry in ipairs(options) do
        FT:SetSelected(self.areaButtons[entry[1]],key==entry[1])
        if key==entry[1] then self.heading:SetText(entry[2]) end
    end
    self.toggle.label:SetText("Skin this area: "..(root[key] and "On" or "Off")); FT:SetSelected(self.toggle,root[key])
    self.presetChoice.value=s.preset
    for _,p in ipairs(self.presets) do if p.value==s.preset then self.presetChoice.label:SetText(p.label) end end
    local icons=key=="actions" or key=="buffs"
    for _,control in ipairs({self.opacitySlider,self.opacityLabel,self.colorButton,self.shadow,self.thickness}) do control:SetShown(icons) end
    self.thickness.value=s.thickness; self.thickness.label:SetText("Border: "..s.thickness.." px")
    self.shadow.label:SetText("Shadow outline: "..(s.shadow and "On" or "Off")); FT:SetSelected(self.shadow,s.shadow)
    self.settingSlider=true; self.opacitySlider:SetValue(s.opacity); self.borderSlider:SetValue(s.borderOpacity); self.settingSlider=false
    self.opacityLabel:SetText("Fill transparency: "..math.floor(100-s.opacity*100+.5).."%")
    self.borderLabel:SetText("Border transparency: "..math.floor(100-s.borderOpacity*100+.5).."%")
    for _,entry in ipairs({{"rares",self.rares},{"elites",self.elites}}) do
        entry[2]:SetShown(key=="target" or key=="tot" or key=="focus" or key=="focustarget")
        entry[2].label:SetText((entry[1]=="rares" and "Darken rares: " or "Darken elites: ")..(s[entry[1]] and "On" or "Off")); FT:SetSelected(entry[2],s[entry[1]])
    end
    self.colorSwatch:SetVertexColor(unpack(s.color)); self.borderSwatch:SetVertexColor(unpack(s.borderColor))
end
function S:Open()
    self.selected=self.selected or "actions"
    if not self.frame then
        self.frame=FT:Window("ForeverToolsIconStyles","ForeverTools | Skins",730,550); FT:AppearanceBack(self.frame); self.areaButtons={}
        local scroll=CreateFrame("ScrollFrame",nil,self.frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",20,-66); scroll:SetSize(174,420)
        local list=CreateFrame("Frame",nil,scroll); list:SetSize(156,#options*38); scroll:SetScrollChild(list)
        for i,entry in ipairs(options) do
            local key=entry[1]; local button=FT:QuietButton(list,entry[2],156,32,"skins"); button.label:SetFont(FT.bodyFont,12,""); button:SetPoint("TOPLEFT",0,-(i-1)*38)
            button:SetScript("OnClick",function() self.selected=key; self:Refresh() end); self.areaButtons[key]=button
        end
        self.heading=FT:Label(self.frame,"",20,true); self.heading:SetPoint("TOPLEFT",222,-68)
        self.toggle=FT:QuietButton(self.frame,"",480,36,"skins"); self.toggle:SetPoint("TOPLEFT",222,-104)
        self.toggle:SetScript("OnClick",function() local root=self:Settings(); root[self.selected]=not root[self.selected]; self:Apply() end)
        self.presetChoice=FT:Dropdown(self.frame,480,function() return self.presets end,function(value) self:UsePreset(value) end,"skins"); self.presetChoice:SetPoint("TOPLEFT",222,-152)
        local function colorButton(label,x,field)
            local b=FT:QuietButton(self.frame,label,234,32,"fonts"); b:SetPoint("TOPLEFT",x,-194); b:SetScript("OnClick",function() self:OpenColorPicker(field) end)
            local swatch=b:CreateTexture(nil,"ARTWORK"); swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch:SetSize(16,16); swatch:SetPoint("RIGHT",-10,0); return b,swatch
        end
        self.borderButton,self.borderSwatch=colorButton("Border color",222,"borderColor")
        self.colorButton,self.colorSwatch=colorButton("Shading color",468,"color")
        local function slider(y,callback)
            local label=FT:Label(self.frame,"",13); label:SetPoint("TOPLEFT",222,y)
            local slider=CreateFrame("Slider",nil,self.frame,"OptionsSliderTemplate"); slider:SetSize(260,18); slider:SetPoint("TOPLEFT",432,y+3); slider:SetMinMaxValues(0,1); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
            slider:SetScript("OnValueChanged",function(_,value) if not self.settingSlider then callback(value) end end); return label,slider
        end
        self.borderLabel,self.borderSlider=slider(-250,function(v) self:Area(self.selected).borderOpacity=v; self:Apply() end)
        self.opacityLabel,self.opacitySlider=slider(-290,function(v) self:SetOpacity(v) end)
        self.thickness=FT.modules.FontManager:Stepper(self.frame,234,function() local choices={}; for i=1,6 do choices[i]={value=i} end; return choices end,function(v) self:Area(self.selected).thickness=v; self:Apply() end)
        self.thickness:SetPoint("TOPLEFT",222,-330)
        self.shadow=FT:QuietButton(self.frame,"",234,32,"skins"); self.shadow:SetPoint("TOPLEFT",468,-330)
        self.shadow:SetScript("OnClick",function() local s=self:Area(self.selected); s.shadow=not s.shadow; self:Apply() end)
        for i,key in ipairs({"rares","elites"}) do
            local option=key; local b=FT:QuietButton(self.frame,"",234,32,"skins"); b:SetPoint("TOPLEFT",222+(i-1)*246,-290)
            b:SetScript("OnClick",function() local s=self:Area(self.selected); s[option]=not s[option]; self:Apply() end); self[key]=b
            FT:Tooltip(b,"Rare / elite artwork","Off preserves original rare/elite frame artwork. Rare elites require both switches on. Level numbers keep their original color.")
        end
        local reset=FT:QuietButton(self.frame,"Reset this area",234,32,"reset"); reset:SetPoint("BOTTOMLEFT",222,30)
        reset:SetScript("OnClick",function() local key=self.selected; FT:Confirm("Reset this skin area to Dark mode defaults?",function() local root=self:Settings(); root.areas[key]={preset="dark",opacity=0,shadow=true,color={0,0,0},borderColor={0,0,0},thickness=1}; self:Apply() end) end)
        local info=FT:Info(self.frame,"Independent skin settings","Every area saves its own preset, color and transparency. Buff and action-bar borders also have independent thickness. Native unitframe/minimap artwork keeps its original shape; its thickness is fixed. Shading never covers aura duration text. Changes save automatically to working settings."); info:SetPoint("BOTTOMRIGHT",-28,30)
        FT:Tooltip(self.thickness,"Border thickness","Changes only this area's border. Action buttons use a rounded replacement when a thicker border is chosen; aura borders stay inside the icon.")
        FT:Tooltip(self.presetChoice,"Preset for this area","Changing a preset affects this area only. Dark mode uses black borders and fully transparent fill.")
    end
    self:Apply(); self.frame:Show()
end
