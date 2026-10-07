local _,FT=...
local S=FT.modules.IconStyles
local options={{"everything","Everything"},{"actions","Action bars"},{"buffs","Buffs / debuffs"}}
for _,entry in ipairs(S.extraOptions) do options[#options+1]=entry end
function S:SetOpacity(value)
    local s=self:Area(self.selected or "actions"); s.opacity=math.max(0,math.min(1,value)); s.preset="custom"; self:LiveApply()
end
-- Sliders fire many times a second while you drag. Repainting the whole UI
-- (and looking for new buttons) each time made the game stutter, so while
-- dragging only the chosen area's existing pieces are recolored, at most 20
-- times a second; one full pass follows when the slider rests.
function S:LiveApply()
    local key=self.selected or "actions"
    FT:Coalesce("skinLive",function()
        if InCombatLockdown() then return end
        for _,rec in pairs(self.records or {}) do if rec.kind==key then self:Paint(rec) end end
        for texture,record in pairs(self.artwork or {}) do if record.key==key then self:PaintArtwork(texture,record) end end
        for button,record in pairs(self.bagSlots or {}) do if record.key==key and self.PaintEmptyBagSlot then self:PaintEmptyBagSlot(button,record) end end
        if key=="actions" and FT.modules.SpellBinds then FT.modules.SpellBinds:PaintRim() end
        self:Refresh()
    end,.05)
    self.liveToken=(self.liveToken or 0)+1; local token=self.liveToken
    C_Timer.After(.35,function() if self.liveToken==token and FT.dbReady then self:Apply() end end)
end
function S:UsePreset(value)
    local s=self:Area(self.selected or "actions")
    for _,p in ipairs(self.presets) do if p.value==value then
        s.preset=value
        if p.color then s.color={unpack(p.color)}; s.borderColor={unpack(p.border)}; s.opacity=1-p.transparency/100; s.shadow=p.shadow end
        if value=="class" then s.opacity=0; s.shadow=false end
        if value=="dark" and self.selected=="micro" then s.hideSecondary=true end
        if value=="dark" and (self.selected=="bags" or self.selected=="bagWindows") then s.opacity=1 end
        if value=="dark" and self.selected=="buffs" then s.thickness=1 end
    end end
    self:Apply()
end
-- Turn on every skin area and give each the preset (also used by the
-- built-in profile templates).
function S:ApplyPresetToAll(value)
    local root=self:Settings()
    for _,entry in ipairs(options) do
        local key=entry[1]
        if key~="everything" then
            root[key]=true
            local area=self:Area(key)
            for _,p in ipairs(self.presets) do if p.value==value then
                area.preset=p.value;area.borderOpacity=1
                if p.color then area.color={unpack(p.color)};area.borderColor={unpack(p.border)};area.opacity=1-p.transparency/100;area.shadow=p.shadow end
                if p.value=="class" then area.opacity=0;area.shadow=false end
                if key=="buffs" then area.thickness=1 end
                if p.value=="dark" and (key=="bags" or key=="bagWindows") then area.opacity=1 end
                if key=="micro" and p.value=="dark" then area.hideSecondary=true end
                -- Keep each unit area's rare/elite artwork preference.
            end end
        end
    end
    self:Apply()
end
function S:OpenColorPicker(setting)
    local s=self:Area(self.selected or "actions"); local old={unpack(s[setting])}; local oldPreset=s.preset
    local function change() local r,g,b=ColorPickerFrame:GetColorRGB(); s[setting]={r,g,b}; s.preset="custom"; self:LiveApply() end
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
    for _,control in ipairs({self.toggle,self.presetChoice,self.borderButton,self.colorButton,self.borderSlider,self.borderLabel,self.opacitySlider,self.opacityLabel,self.shadow,self.thickness,self.rares,self.elites,self.microOutline,self.hideArt,self.hideSlotArt,self.slotLabel,self.slotSlider,self.slotColorButton,self.reset,self.shadowSizeSlider,self.shadowSizeLabel,self.shadowStrengthSlider,self.shadowStrengthLabel}) do control:SetShown(not everything) end
    if everything then return end
    local s=self:Area(key)
    self.slotLabel:SetShown(key=="bagWindows");self.slotSlider:SetShown(key=="bagWindows");self.slotColorButton:SetShown(key=="bagWindows")
    self.slotColorSwatch:SetVertexColor(unpack(s.slotColor))
    self.settingSlider=true;self.slotSlider:SetValue(1-s.slotOpacity);self.settingSlider=false
    self.slotLabel:SetText("Slot color transparency: "..math.floor(100-s.slotOpacity*100+.5).."%")
    -- Bag menu rows: art switches, then Slot color with its transparency.
    local bag=key=="bagWindows"
    self.hideArt:ClearAllPoints(); self.hideArt:SetPoint("TOPLEFT",222,bag and -361 or -401)
    self.hideSlotArt:ClearAllPoints(); self.hideSlotArt:SetPoint("TOPLEFT",483,-361)
    self.slotColorButton:ClearAllPoints(); self.slotColorButton:SetPoint("TOPLEFT",222,-401)
    self.slotLabel:ClearAllPoints(); self.slotLabel:SetPoint("TOPLEFT",222,-441)
    self.slotSlider:ClearAllPoints(); self.slotSlider:SetPoint("TOPLEFT",432,-438)
    self.toggle.label:SetText("Skin this area: "..(root[key] and "On" or "Off")); FT:SetSelected(self.toggle,root[key])
    self.microOutline:SetShown(key=="micro")
    self.microOutline.label:SetText("Extra micro menu outline: "..(s.hideSecondary and "Off" or "On"))
    FT:SetSelected(self.microOutline,not s.hideSecondary)
    self.presetChoice.value=s.preset
    for _,p in ipairs(self.presets) do if p.value==s.preset then self.presetChoice.label:SetText(p.label) end end
    self.hideArt:SetShown(key=="bagWindows" or key=="gryphons")
    self.hideArt:SetWidth(key=="bagWindows" and 249 or 510)
    self.hideArt.label:SetText((key=="bagWindows" and "Hide window art: " or "Hide Blizzard art: ")..(s.hideArt and "On" or "Off")); FT:SetSelected(self.hideArt,s.hideArt)
    self.hideSlotArt:SetShown(key=="bagWindows")
    if key=="bagWindows" then self.hideSlotArt.label:SetText("Hide empty slot art: "..(s.hideSlotArt and "On" or "Off")); FT:SetSelected(self.hideSlotArt,s.hideSlotArt) end
    local icons=key=="actions" or key=="buffs" or key=="stances"
    for _,control in ipairs({self.shadow,self.thickness}) do control:SetShown(icons) end
    for _,control in ipairs({self.shadowSizeSlider,self.shadowSizeLabel,self.shadowStrengthSlider,self.shadowStrengthLabel}) do control:SetShown(icons and s.shadow) end
    -- Buff icons fill their whole square, so a fill color behind them never shows.
    for _,control in ipairs({self.opacitySlider,self.opacityLabel,self.colorButton}) do control:SetShown((icons and key~="buffs") or key=="bagWindows" or key=="bags") end
    self.colorButton.label:SetText(key=="bagWindows" and "Background color" or "Shading color")
    self.thickness.value=s.thickness; self.thickness.label:SetText("Border: "..s.thickness.." px")
    self.shadow.label:SetText("Shadow: "..(s.shadow and "On" or "Off")); FT:SetSelected(self.shadow,s.shadow)
    self.settingSlider=true; self.shadowSizeSlider:SetValue(s.shadowSize); self.shadowStrengthSlider:SetValue(s.shadowStrength); self.settingSlider=false
    self.shadowSizeLabel:SetText("Shadow size: "..s.shadowSize.." px")
    self.shadowStrengthLabel:SetText("Shadow darkness: "..math.floor(s.shadowStrength*100+.5).."%")
    -- Both sliders show transparency the same way: right = more see-through.
    self.settingSlider=true; self.opacitySlider:SetValue(1-s.opacity); self.borderSlider:SetValue(1-s.borderOpacity); self.settingSlider=false
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
        self.frame=FT:Window("ForeverToolsIconStyles","Skins",760,550); FT:AppearanceBack(self.frame); self.areaButtons={}
        FT:PageInfo(self.frame,"Skins","Pick an area on the left and turn it on. Then choose its look: a template, colors, transparency and border.\n\nEverything gives all areas one template at once, and holds the templates you saved yourself. Changes apply right away and are saved to your profile.")
        local scroll=CreateFrame("ScrollFrame",nil,self.frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",20,-66); scroll:SetSize(160,420) -- scrollbar sits in the gap, clear of the settings
        local list=CreateFrame("Frame",nil,scroll); list:SetSize(156,#options*38); scroll:SetScrollChild(list)
        for i,entry in ipairs(options) do
            local key=entry[1]; local button=FT:QuietButton(list,entry[2],156,32,"skins"); button.label:SetFont(FT.bodyFont,12,""); button:SetPoint("TOPLEFT",0,-(i-1)*38)
            button:SetScript("OnClick",function() self.selected=key; self:Refresh() end); self.areaButtons[key]=button
            FT:Tooltip(button,entry[2],key=="everything" and "Templates for every area at once, and your own saved templates." or function() return (self:Settings()[key] and "On. " or "Off. ").."Click to show the look for "..entry[2]:lower().."." end)
        end
        self.allPreset="dark"
        self.allPresetChoice=FT:Dropdown(self.frame,510,function() local choices={}; for _,p in ipairs(self.presets) do if p.value~="custom" then choices[#choices+1]=p end end; return choices end,function(value) self.allPreset=value; self:Refresh() end,"skins"); self.allPresetChoice:SetPoint("TOPLEFT",222,-148)
        local all=FT:AccentButton(self.frame,"Apply template to all areas",510,34,"skins");all:SetPoint("TOPLEFT",222,-194); self.applyAll=all
        all:SetScript("OnClick",function() FT:Confirm("Apply the selected template to all supported skin areas? This replaces their current skin colors and transparency.",function() self:ApplyPresetToAll(self.allPreset) end) end)
        FT:Tooltip(all,"Apply to all areas","Turn on every area and give them all the chosen template. You can still change each area afterwards.")
        self.heading=FT:Label(self.frame,"",20,true); self.heading:SetPoint("TOPLEFT",222,-105)
        self.toggle=FT:AccentButton(self.frame,"",510,34,"skins"); self.toggle:SetPoint("TOPLEFT",222,-140)
        self.toggle:SetScript("OnClick",function() local root=self:Settings(); root[self.selected]=not root[self.selected]; self:Apply() end)
        FT:Tooltip(self.toggle,"Skin this area","Turn the skin for this area on or off. Off gives the area back its normal look.")
        self.presetChoice=FT:Dropdown(self.frame,510,function() return self.presets end,function(value) self:UsePreset(value) end,"skins"); self.presetChoice:SetPoint("TOPLEFT",222,-183)
        local function colorButton(label,x,field)
            local b=FT:QuietButton(self.frame,label,249,32,"fonts"); b:SetPoint("TOPLEFT",x,-225); b:SetScript("OnClick",function() self:OpenColorPicker(field) end)
            local swatch=b:CreateTexture(nil,"ARTWORK"); swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch:SetSize(16,16); swatch:SetPoint("RIGHT",-10,0); return b,swatch
        end
        self.borderButton,self.borderSwatch=colorButton("Border color",222,"borderColor")
        self.colorButton,self.colorSwatch=colorButton("Shading color",483,"color")
        FT:Tooltip(self.borderButton,"Border color","The color of the frame line around each button, icon or frame. Picking a color makes this area's look your own (Custom).")
        FT:Tooltip(self.colorButton,function() return self.selected=="bagWindows" and "Background color" or "Shading color" end,function() return self.selected=="bagWindows" and "The color behind the bag window." or "The color of the shading behind each button or icon. Set how much of it shows with Fill transparency." end)
        local function slider(y,callback)
            local label=FT:Label(self.frame,"",13); label:SetPoint("TOPLEFT",222,y)
            local slider=CreateFrame("Slider",nil,self.frame,"OptionsSliderTemplate"); slider:SetSize(290,18); slider:SetPoint("TOPLEFT",432,y+3); slider:SetMinMaxValues(0,1); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
            slider:SetScript("OnValueChanged",function(_,value) if not self.settingSlider then callback(value) end end)
            -- Plain end labels instead of Low / High.
            local low=slider.Low or (slider.GetName and slider:GetName() and _G[slider:GetName().."Low"])
            local high=slider.High or (slider.GetName and slider:GetName() and _G[slider:GetName().."High"])
            if low and low.SetText then low:SetText("Solid") end
            if high and high.SetText then high:SetText("See-through") end
            return label,slider
        end
        self.borderLabel,self.borderSlider=slider(-281,function(v) self:Area(self.selected).borderOpacity=1-v; self:LiveApply() end)
        FT:Tooltip(self.borderSlider,"Border transparency","The thin frame line around each button or icon. 0% is solid, 100% hides it. Slide right for more see-through.")
        self.opacityLabel,self.opacitySlider=slider(-321,function(v) self:SetOpacity(1-v) end)
        FT:Tooltip(self.opacitySlider,"Fill transparency",function() return (self.selected=="bagWindows" and "The background behind the bag window." or "The shading color behind each button or icon.").." 0% is solid, 100% hides it. Slide right for more see-through." end)
        self.slotLabel,self.slotSlider=slider(-361,function(v) self:Area("bagWindows").slotOpacity=1-v;self:LiveApply() end)
        FT:Tooltip(self.slotSlider,"Slot color transparency","How much of the Slot color shows in each bag slot. 0% is solid, 100% shows no color, so the bag window shows through.")
        self.slotColorButton,self.slotColorSwatch=colorButton("Slot color",222,"slotColor")
        self.slotColorButton:ClearAllPoints(); self.slotColorButton:SetPoint("TOPLEFT",222,-441)
        FT:Tooltip(self.slotColorButton,"Bag slot color","The color of the square behind each bag slot.")
        self.thickness=FT.modules.FontManager:Stepper(self.frame,249,function() local choices={}; for i=1,4 do choices[i]={value=i} end; return choices end,function(v) self:Area(self.selected).thickness=v; self:Apply() end)
        self.thickness:SetPoint("TOPLEFT",222,-361)
        FT:Tooltip(self.thickness,"Border thickness","How thick the border is. On buffs and debuffs it's in real screen pixels, so 1 px is the thinnest line your screen can show.")
        for _,step in ipairs({self.thickness.minus,self.thickness.plus}) do if step then FT:Tooltip(step,"Border thickness","Make the border one step thinner or thicker (1 to 4).") end end
        self.shadow=FT:QuietButton(self.frame,"",249,32,"skins"); self.shadow:SetPoint("TOPLEFT",483,-361)
        self.shadow:SetScript("OnClick",function() local s=self:Area(self.selected); s.shadow=not s.shadow; self:Apply() end)
        FT:Tooltip(self.shadow,"Shadow","A soft dark shadow around each icon that fades out. Set how far it reaches and how dark it is below.")
        local function ends(slider,low,high)
            local l=slider.Low or (slider.GetName and slider:GetName() and _G[slider:GetName().."Low"])
            local h=slider.High or (slider.GetName and slider:GetName() and _G[slider:GetName().."High"])
            if l and l.SetText then l:SetText(low) end; if h and h.SetText then h:SetText(high) end
        end
        self.shadowSizeLabel,self.shadowSizeSlider=slider(-401,function(v) self:Area(self.selected).shadowSize=math.floor(v+.5); self:LiveApply() end)
        self.shadowSizeSlider:SetMinMaxValues(1,8); self.shadowSizeSlider:SetValueStep(1); ends(self.shadowSizeSlider,"Tight","Wide")
        FT:Tooltip(self.shadowSizeSlider,"Shadow size","How far the shadow reaches past the icon, in screen pixels (1 to 8).")
        self.shadowStrengthLabel,self.shadowStrengthSlider=slider(-441,function(v) self:Area(self.selected).shadowStrength=v; self:LiveApply() end)
        self.shadowStrengthSlider:SetMinMaxValues(.1,1); ends(self.shadowStrengthSlider,"Light","Dark")
        FT:Tooltip(self.shadowStrengthSlider,"Shadow darkness","How dark the shadow is next to the icon. It always fades out toward its edge.")
        for i,key in ipairs({"rares","elites"}) do
            local option=key; local b=FT:QuietButton(self.frame,"",249,32,"skins"); b:SetPoint("TOPLEFT",222+(i-1)*261,-321)
            b:SetScript("OnClick",function() local s=self:Area(self.selected); s[option]=not s[option]; self:Apply() end); self[key]=b
            FT:Tooltip(b,"Rare / elite artwork","Also color the rare or elite dragon on unit frames. Rare elites need both switches on.")
        end
        self.microOutline=FT:QuietButton(self.frame,"",510,32,"skins");self.microOutline:SetPoint("TOPLEFT",222,-321)
        self.microOutline:SetScript("OnClick",function() local s=self:Area("micro");s.hideSecondary=not s.hideSecondary;self:Apply() end)
        FT:Tooltip(self.microOutline,"Extra micro menu outline","Hide the outer border around the micro menu. Each button keeps its own border.")
        self.hideArt=FT:QuietButton(self.frame,"",510,32,"skins");self.hideArt:SetPoint("TOPLEFT",222,-401)
        self.hideArt:SetScript("OnClick",function() local s=self:Area(self.selected);s.hideArt=not s.hideArt;self:Apply() end)
        FT:Tooltip(self.hideArt,"Blizzard art",function() return self.selected=="bagWindows" and "Hide the bag window's textured background; your fill color is used instead." or "Hide the gryphons at both ends of the action bar." end)
        self.hideSlotArt=FT:QuietButton(self.frame,"",249,32,"skins");self.hideSlotArt:SetPoint("TOPLEFT",483,-401)
        self.hideSlotArt:SetScript("OnClick",function() local s=self:Area("bagWindows");s.hideSlotArt=not s.hideSlotArt;self:Apply() end)
        FT:Tooltip(self.hideSlotArt,"Empty slot art","Hide Blizzard's picture in empty bag slots. The slot outline stays; use Slot color and Slot backgrounds to tint the square or make it see-through.")
        local reset=FT:QuietButton(self.frame,"Reset this area",249,32,"reset"); reset:SetPoint("BOTTOMLEFT",222,30); self.reset=reset
        FT:Tooltip(reset,"Reset this area","Put this area's colors, transparency and border back to how they start. Asks first.")
        reset:SetScript("OnClick",function() local key=self.selected; FT:Confirm("Reset this skin area to its defaults?",function() local root=self:Settings(); root.areas[key]=nil; self:Area(key); self:Apply() end) end)

        FT:Tooltip(self.presetChoice,"Preset for this area","Pick a look for this area only. Dark mode gives black borders.")
        FT:Tooltip(self.allPresetChoice,"Template for all areas","Choose a template, then use the button below to apply it everywhere.")
    end
    self:Apply(); self.frame:Show()
end
