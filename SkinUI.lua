local _,FT=...
local S=FT.modules.IconStyles
local options={{"everything","Everything"},{"actions","Action bars"},{"buffs","Buffs / debuffs"}}
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
        if value=="dark" and self.selected=="micro" then s.hideSecondary=true end
        if value=="dark" and (self.selected=="bags" or self.selected=="bagWindows") then s.opacity=1 end
        if value=="dark" and self.selected=="buffs" then s.thickness=3 end
    end end
    self:Apply()
end
function S:OpenColorPicker(setting)
    local s=self:Area(self.selected or "actions"); local old={unpack(s[setting])}; local oldPreset=s.preset
    local function change() local r,g,b=ColorPickerFrame:GetColorRGB(); s[setting]={r,g,b}; s.preset="custom"; self:Apply() end
    local function cancel() s[setting]=old; s.preset=oldPreset; self:Apply() end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
    elseif ColorPickerFrame then ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=change; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
end
function S:Refresh()
    if not self.frame then return end
    local key=self.selected or "everything"; local root=self:Settings()
    for _,entry in ipairs(options) do
        FT:SetSelected(self.areaButtons[entry[1]],key==entry[1])
        if key==entry[1] then self.heading:SetText(entry[2]) end
    end
    local everything=key=="everything"
    self.allPresetChoice:SetShown(everything); self.applyAll:SetShown(everything)
    self.allPresetChoice.value=self.allPreset or "dark"
    for _,p in ipairs(self.presets) do if p.value==self.allPresetChoice.value then self.allPresetChoice.label:SetText(p.label) end end
    for _,control in ipairs({self.toggle,self.presetChoice,self.borderButton,self.colorButton,self.borderSlider,self.borderLabel,self.opacitySlider,self.opacityLabel,self.shadow,self.thickness,self.rares,self.elites,self.microOutline,self.hideArt,self.slotLabel,self.slotSlider,self.reset}) do control:SetShown(not everything) end
    if everything then return end
    local s=self:Area(key)
    self.slotLabel:SetShown(key=="bagWindows");self.slotSlider:SetShown(key=="bagWindows")
    self.settingSlider=true;self.slotSlider:SetValue(1-s.slotOpacity);self.settingSlider=false
    self.slotLabel:SetText("Slot transparency: "..math.floor(100-s.slotOpacity*100+.5).."%")
    self.toggle.label:SetText("Skin this area: "..(root[key] and "On" or "Off")); FT:SetSelected(self.toggle,root[key])
    self.microOutline:SetShown(key=="micro")
    self.microOutline.label:SetText("Extra micro menu outline: "..(s.hideSecondary and "Off" or "On"))
    FT:SetSelected(self.microOutline,not s.hideSecondary)
    self.presetChoice.value=s.preset
    for _,p in ipairs(self.presets) do if p.value==s.preset then self.presetChoice.label:SetText(p.label) end end
    self.hideArt:SetShown(key=="bagWindows" or key=="gryphons")
    self.hideArt.label:SetText("Hide Blizzard art: "..(s.hideArt and "On" or "Off")); FT:SetSelected(self.hideArt,s.hideArt)
    local icons=key=="actions" or key=="buffs" or key=="stances"
    for _,control in ipairs({self.shadow,self.thickness}) do control:SetShown(icons) end
    for _,control in ipairs({self.opacitySlider,self.opacityLabel,self.colorButton}) do control:SetShown(icons or key=="bagWindows" or key=="bags") end
    self.colorButton.label:SetText(key=="bagWindows" and "Background color" or "Shading color")
    self.thickness.value=s.thickness; self.thickness.label:SetText("Border: "..s.thickness.." px")
    self.shadow.label:SetText("Shadow outline: "..(s.shadow and "On" or "Off")); FT:SetSelected(self.shadow,s.shadow)
    self.settingSlider=true; self.opacitySlider:SetValue(1-s.opacity); self.borderSlider:SetValue(s.borderOpacity); self.settingSlider=false
    self.opacityLabel:SetText((key=="bagWindows" and "Background transparency: " or "Fill transparency: ")..math.floor(100-s.opacity*100+.5).."%")
    self.borderLabel:SetText("Border transparency: "..math.floor(100-s.borderOpacity*100+.5).."%")
    for _,entry in ipairs({{"rares",self.rares},{"elites",self.elites}}) do
        entry[2]:SetShown(key=="target" or key=="tot" or key=="focus" or key=="focustarget")
        entry[2].label:SetText((entry[1]=="rares" and "Darken rares: " or "Darken elites: ")..(s[entry[1]] and "On" or "Off")); FT:SetSelected(entry[2],s[entry[1]])
    end
    self.colorSwatch:SetVertexColor(unpack(s.color)); self.borderSwatch:SetVertexColor(unpack(s.borderColor))
end
function S:Open()
    self.selected=self.selected or "everything"
    if not self.frame then
        self.frame=FT:Window("ForeverToolsIconStyles","ForeverTools | Skins",730,550); FT:AppearanceBack(self.frame); self.areaButtons={}
        local scroll=CreateFrame("ScrollFrame",nil,self.frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",20,-66); scroll:SetSize(160,420) -- scrollbar sits in the gap, clear of the settings
        local list=CreateFrame("Frame",nil,scroll); list:SetSize(156,#options*38); scroll:SetScrollChild(list)
        for i,entry in ipairs(options) do
            local key=entry[1]; local button=FT:QuietButton(list,entry[2],156,32,"skins"); button.label:SetFont(FT.bodyFont,12,""); button:SetPoint("TOPLEFT",0,-(i-1)*38)
            button:SetScript("OnClick",function() self.selected=key; self:Refresh() end); self.areaButtons[key]=button
        end
        self.allPreset="dark"
        self.allPresetChoice=FT:Dropdown(self.frame,480,function() local choices={}; for _,p in ipairs(self.presets) do if p.value~="custom" then choices[#choices+1]=p end end; return choices end,function(value) self.allPreset=value; self:Refresh() end,"skins"); self.allPresetChoice:SetPoint("TOPLEFT",222,-148)
        local all=FT:AccentButton(self.frame,"Apply template to all areas",480,36,"skins");all:SetPoint("TOPLEFT",222,-194); self.applyAll=all
        all:SetScript("OnClick",function() FT:Confirm("Apply the selected template to all supported skin areas? This replaces their current skin colors and transparency.",function()
            local root=self:Settings()
            for _,entry in ipairs(options) do
                local key=entry[1]
                if key~="everything" then
                    root[key]=true
                    local area=self:Area(key)
                    for _,p in ipairs(self.presets) do if p.value==self.allPreset then
                        area.preset=p.value;area.borderOpacity=1
                        if p.color then area.color={unpack(p.color)};area.borderColor={unpack(p.border)};area.opacity=1-p.transparency/100;area.shadow=p.shadow end
                        if p.value=="class" then area.opacity=0;area.shadow=false end
                        if key=="buffs" then area.thickness=3 end
                        if p.value=="dark" and (key=="bags" or key=="bagWindows") then area.opacity=1 end
                        if key=="micro" and p.value=="dark" then area.hideSecondary=true end
                        -- Keep each unit area's rare/elite artwork preference.
                    end end
                end
            end
            self:Apply()
        end) end)
        FT:Tooltip(all,"Apply to all areas","Turn on every area and give them all the chosen template. You can still change each area afterwards.")
        self.heading=FT:Label(self.frame,"",20,true); self.heading:SetPoint("TOPLEFT",222,-105)
        self.toggle=FT:QuietButton(self.frame,"",480,36,"skins"); self.toggle:SetPoint("TOPLEFT",222,-140)
        self.toggle:SetScript("OnClick",function() local root=self:Settings(); root[self.selected]=not root[self.selected]; self:Apply() end)
        self.presetChoice=FT:Dropdown(self.frame,480,function() return self.presets end,function(value) self:UsePreset(value) end,"skins"); self.presetChoice:SetPoint("TOPLEFT",222,-183)
        local function colorButton(label,x,field)
            local b=FT:QuietButton(self.frame,label,234,32,"fonts"); b:SetPoint("TOPLEFT",x,-225); b:SetScript("OnClick",function() self:OpenColorPicker(field) end)
            local swatch=b:CreateTexture(nil,"ARTWORK"); swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch:SetSize(16,16); swatch:SetPoint("RIGHT",-10,0); return b,swatch
        end
        self.borderButton,self.borderSwatch=colorButton("Border color",222,"borderColor")
        self.colorButton,self.colorSwatch=colorButton("Shading color",468,"color")
        local function slider(y,callback)
            local label=FT:Label(self.frame,"",13); label:SetPoint("TOPLEFT",222,y)
            local slider=CreateFrame("Slider",nil,self.frame,"OptionsSliderTemplate"); slider:SetSize(260,18); slider:SetPoint("TOPLEFT",432,y+3); slider:SetMinMaxValues(0,1); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
            slider:SetScript("OnValueChanged",function(_,value) if not self.settingSlider then callback(value) end end); return label,slider
        end
        self.borderLabel,self.borderSlider=slider(-281,function(v) self:Area(self.selected).borderOpacity=v; self:Apply() end)
        self.opacityLabel,self.opacitySlider=slider(-321,function(v) self:SetOpacity(1-v) end)
        self.slotLabel,self.slotSlider=slider(-361,function(v) self:Area("bagWindows").slotOpacity=1-v;self:Apply() end)
        FT:Tooltip(self.slotSlider,"Bag slot backgrounds","How see-through the background behind each bag slot is.")
        self.thickness=FT.modules.FontManager:Stepper(self.frame,234,function() local choices={}; for i=1,6 do choices[i]={value=i} end; return choices end,function(v) self:Area(self.selected).thickness=v; self:Apply() end)
        self.thickness:SetPoint("TOPLEFT",222,-361)
        self.shadow=FT:QuietButton(self.frame,"",234,32,"skins"); self.shadow:SetPoint("TOPLEFT",468,-361)
        self.shadow:SetScript("OnClick",function() local s=self:Area(self.selected); s.shadow=not s.shadow; self:Apply() end)
        for i,key in ipairs({"rares","elites"}) do
            local option=key; local b=FT:QuietButton(self.frame,"",234,32,"skins"); b:SetPoint("TOPLEFT",222+(i-1)*246,-321)
            b:SetScript("OnClick",function() local s=self:Area(self.selected); s[option]=not s[option]; self:Apply() end); self[key]=b
            FT:Tooltip(b,"Rare / elite artwork","Also color the rare or elite dragon on unit frames. Rare elites need both switches on.")
        end
        self.microOutline=FT:QuietButton(self.frame,"",480,32,"skins");self.microOutline:SetPoint("TOPLEFT",222,-321)
        self.microOutline:SetScript("OnClick",function() local s=self:Area("micro");s.hideSecondary=not s.hideSecondary;self:Apply() end)
        FT:Tooltip(self.microOutline,"Extra micro menu outline","Hide the outer border around the micro menu. Each button keeps its own border.")
        self.hideArt=FT:QuietButton(self.frame,"",480,32,"skins");self.hideArt:SetPoint("TOPLEFT",222,-401)
        self.hideArt:SetScript("OnClick",function() local s=self:Area(self.selected);s.hideArt=not s.hideArt;self:Apply() end)
        FT:Tooltip(self.hideArt,"Blizzard art","Bags: hide Blizzard's textured backgrounds and empty-slot art. Gryphons: hide the gryphons at both ends of the action bar.")
        local reset=FT:QuietButton(self.frame,"Reset this area",234,32,"reset"); reset:SetPoint("BOTTOMLEFT",222,30); self.reset=reset
        reset:SetScript("OnClick",function() local key=self.selected; FT:Confirm("Reset this skin area to its defaults?",function() local root=self:Settings(); root.areas[key]=nil; self:Area(key); self:Apply() end) end)
        local info=FT:Info(self.frame,"Skin settings","Changes apply right away. Save a profile to keep this look for other characters."); info:SetPoint("BOTTOMRIGHT",-28,30)
        FT:Tooltip(self.thickness,"Border thickness","How thick the border is in this area.")
        FT:Tooltip(self.presetChoice,"Preset for this area","Pick a look for this area only. Dark mode gives black borders.")
        FT:Tooltip(self.allPresetChoice,"Template for all areas","Choose a template, then use the button below to apply it everywhere.")
    end
    self:Apply(); self.frame:Show()
end
