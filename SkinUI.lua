local _,FT=...
local S=FT.modules.IconStyles
-- Every skin area (used by "Apply template to all areas" and the tour).
local options={{"everything","Everything"},{"actions","Action bars"},{"buffs","Buffs / debuffs"}}
for _,entry in ipairs(S.extraOptions) do options[#options+1]=entry end
-- The Skins page shows groups. Each part keeps its own switch and its own
-- saved look. "Editing" picks what the look controls change: all parts of
-- the group at once (the default), or one part only. Nothing is copied or
-- turned off when you switch between them.
local groups={
    {key="everything",label="Everything"},
    {key="g_actions",label="Action bars",parts={"actions","stances","gryphons"}},
    {key="g_buffs",label="Buffs / debuffs",parts={"buffs"}},
    {key="g_units",label="Unit frames",parts={"player","pet","target","tot","focus","focustarget","party","personal"}},
    {key="g_cast",label="Cast bars & timers",parts={"castbar","swing"}},
    {key="g_bags",label="Bags",parts={"bags","bagWindows","bank"}},
    {key="g_menus",label="Minimap & menus",parts={"minimap","micro","xp"}},
    {key="g_windows",label="Windows",parts={"tooltip","dialogs","gameWindows","calendar"}},
    {key="g_pvp",label="PvP",parts={"trinkets","nearby","enemyAlert","bgTimer"}},
    {key="g_ft",label="Notices & meters",parts={"notices","meters","ftBars"}},
}
S.skinGroups=groups
local partLabels={actions="Action bars",stances="Stance / totem",gryphons="Gryphons",buffs="Buffs / debuffs",
    player="Player",pet="Pet",target="Target",tot="Target's target",focus="Focus",focustarget="Focus target",party="Party",personal="Personal bars",
    castbar="Cast bars",swing="Swing timers",bags="Bag bar",bagWindows="Bag menu",bank="Bank",minimap="Minimap",micro="Micro menu",xp="XP / reputation",
    tooltip="Tooltips",dialogs="Dialog windows",gameWindows="Game windows",calendar="Calendar",trinkets="Trinket menu",nearby="Nearby enemies",enemyAlert="Enemy alert",bgTimer="BG timer",notices="Notices",meters="Meters",ftBars="Bars"}
local partTips={gameWindows="Character, spellbook, talents, quest log and more. Only frames and borders go dark.",calendar="The calendar: only the outline goes dark.",bank="The bank takes the Bag menu's look.",
    notices="Buff and cooldown reminders, and the rare alert.",meters="The game's damage meter and the threat meter: only the header and background.",ftBars="The interrupt bar and the enemy cooldown bar."}
local groupOf={}
for _,g in ipairs(groups) do for _,p in ipairs(g.parts or {}) do groupOf[p]=g end end
local byKey={}; for _,g in ipairs(groups) do byKey[g.key]=g end
-- The look shared by a group's parts (copied when it becomes one look again).
local LOOK={"preset","opacity","color","borderColor","borderOpacity","thickness","shadow","shadowSize","shadowStrength"}
local ICONS={actions=true,buffs=true,stances=true,trinkets=true}
local PANELS={bagWindows=true,dialogs=true,nearby=true,enemyAlert=true,bgTimer=true,notices=true,ftBars=true}
local SOLID={bags=true,bagWindows=true,dialogs=true,calendar=true,nearby=true,enemyAlert=true,bgTimer=true,notices=true,meters=true,ftBars=true}
local UNITART={target=true,tot=true,focus=true,focustarget=true}
-- Turning a part on or off (or changing its look) shows what it skins for a
-- few seconds, for parts that are not always on screen. Each change starts
-- the few seconds again.
local function peekPart(part)
    local m=FT.modules
    local function call(name,fn) local x=m[name]; if x and x[fn] then pcall(x[fn],x) end end
    if part=="notices" then call("BuffReminder","PeekSelf"); call("RareAlert","Peek")
    elseif part=="meters" then
        local T=m.Threat
        -- Not while you preview it yourself (its page's Preview switch).
        if T and (not T.previewing or T.skinPeek) and not InCombatLockdown() then
            T.skinPeek=(T.skinPeek or 0)+1; local token=T.skinPeek
            T.previewing=true; T:Apply()
            C_Timer.After(.1,function() if S.SkinThreat then S:SkinThreat(T.meter) end; T:Update() end)
            C_Timer.After(4,function() if T.skinPeek==token then T.skinPeek=nil; T.previewing=false; T:Apply() end end)
        end
    elseif part=="ftBars" then call("Interrupts","Peek"); call("EnemyCooldowns","Peek")
    elseif part=="nearby" then call("EnemyNearby","Peek")
    elseif part=="enemyAlert" then call("EnemyAlerts","Peek")
    elseif part=="bgTimer" then call("QueueTimer","Peek") end
end
S.PeekPart=peekPart
local function copy(v) if type(v)=="table" then local t={}; for k,x in pairs(v) do t[k]=x end; return t end; return v end
function S:CurrentGroup()
    local key=self.selected or "everything"
    -- An area key (older code and tests) opens its group, editing that part.
    if not byKey[key] and groupOf[key] then
        local g=groupOf[key]; self.editPart=self.editPart or {}; self.editPart[g.key]=key; self.selected=g.key; key=g.key
    end
    return byKey[key] or groups[1]
end
local function lookParts(g) local out={}; for _,p in ipairs(g.parts or {}) do if p~="bank" then out[#out+1]=p end end; return out end
-- The part being edited in a group ("all" or a part key).
function S:EditTarget(g)
    local e=self.editPart and self.editPart[g.key]
    for _,p in ipairs(lookParts(g)) do if p==e then return e end end
    return "all"
end
-- The parts the look controls change right now.
function S:EditedParts()
    local g=self:CurrentGroup(); local looks=lookParts(g)
    local e=self:EditTarget(g)
    if #looks<=1 or e=="all" then return looks end
    return {e}
end
local function has(list,set) for _,p in ipairs(list) do if set[p] then return true end end return false end
local function contains(list,key) for _,p in ipairs(list) do if p==key then return true end end return false end
function S:EachEdited(fn) for _,key in ipairs(self:EditedParts()) do fn(self:Area(key),key) end end
function S:Lead() return self:Area(self:EditedParts()[1] or "actions") end
function S:SetOpacity(value)
    self:EachEdited(function(s) s.opacity=math.max(0,math.min(1,value)); s.preset="custom" end); self:LiveApply()
end
-- Sliders fire many times a second while you drag. Repainting the whole UI
-- (and looking for new buttons) each time made the game stutter, so while
-- dragging only the edited parts are recolored, at most 20 times a second;
-- one full pass follows when the slider rests.
function S:LiveApply()
    local edited={}; for _,k in ipairs(self:EditedParts()) do edited[k]=true end
    FT:Coalesce("skinPeek",function() local root=self:Settings(); for k in pairs(edited) do peekPart(k) end end,.3)
    FT:Coalesce("skinLive",function()
        if FT:LooksWait() then return end
        for _,rec in pairs(self.records or {}) do if edited[rec.kind] then self:Paint(rec) end end
        for texture,record in pairs(self.artwork or {}) do if edited[record.key] then self:PaintArtwork(texture,record) end end
        for button,record in pairs(self.bagSlots or {}) do if edited[record.key] and self.PaintEmptyBagSlot then self:PaintEmptyBagSlot(button,record) end end
        if edited.actions and FT.modules.SpellBinds then FT.modules.SpellBinds:PaintRim() end
        if self.ApplyPvp then self:ApplyPvp() end
        self:Refresh()
    end,.05)
    self.liveToken=(self.liveToken or 0)+1; local token=self.liveToken
    C_Timer.After(.35,function() if self.liveToken==token and FT.dbReady then self:Apply() end end)
end
local function presetInto(self,s,key,value)
    for _,p in ipairs(self.presets) do if p.value==value then
        s.preset=value
        if p.color then s.color={unpack(p.color)}; s.borderColor={unpack(p.border)}; s.opacity=1-p.transparency/100; s.shadow=p.shadow end
        if value=="class" then s.opacity=0; s.shadow=false end
        if value=="dark" and key=="micro" then s.hideSecondary=true end
        if value=="dark" and SOLID[key] then s.opacity=1 end
        if value=="dark" and key=="buffs" then s.thickness=1 end
    end end
end
function S:UsePreset(value)
    self:EachEdited(function(s,key) presetInto(self,s,key,value) end)
    self:Apply()
end
-- Turn on every skin area and give each the preset (also used by the
-- built-in profile templates).
function S:ApplyPresetToAll(value)
    local root=self:Settings()
    for _,entry in ipairs(options) do
        local key=entry[1]
        -- The bank keeps its own switch: "all areas" never turns it on.
        if key~="everything" and key~="bank" then
            root[key]=true
            local area=self:Area(key)
            for _,p in ipairs(self.presets) do if p.value==value then
                area.preset=p.value;area.borderOpacity=1
                if p.color then area.color={unpack(p.color)};area.borderColor={unpack(p.border)};area.opacity=1-p.transparency/100;area.shadow=p.shadow end
                if p.value=="class" then area.opacity=0;area.shadow=false end
                if key=="buffs" then area.thickness=1 end
                if p.value=="dark" and SOLID[key] then area.opacity=1 end
                if key=="micro" and p.value=="dark" then area.hideSecondary=true end
                -- Keep each unit area's rare/elite artwork preference.
            end end
        end
    end
    self:Apply()
end
function S:OpenColorPicker(setting)
    local lead=self:Lead(); local old={unpack(lead[setting])}
    local olds={}; self:EachEdited(function(s,key) olds[key]={value={unpack(s[setting])},preset=s.preset} end)
    local function change() local r,g,b=ColorPickerFrame:GetColorRGB(); self:EachEdited(function(s) s[setting]={r,g,b}; s.preset="custom" end); self:LiveApply() end
    local function cancel() self:EachEdited(function(s,key) local o=olds[key]; if o then s[setting]=o.value; s.preset=o.preset end end); self:Apply() end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
    elseif ColorPickerFrame then ColorPickerFrame:SetColorRGB(unpack(old)); ColorPickerFrame.func=change; ColorPickerFrame.cancelFunc=cancel; ColorPickerFrame:Show() end
end
-- Places the visible controls from the top down, so each group shows only
-- what applies to its parts, without gaps.
-- A control is only moved when its spot changes, and only the controls not
-- placed this time are hidden afterwards: hiding or re-anchoring a slider
-- while you drag it drops the drag (the page refreshes while you slide).
local visible
local function place(control,x,y)
    visible[control]=true
    if control.placedX~=x or control.placedY~=y or not control:IsShown() then
        control:ClearAllPoints(); control:SetPoint("TOPLEFT",x,y); control.placedX,control.placedY=x,y
    end
    control:Show()
end
-- Sets a slider's value unless you are dragging it right now.
local function setSlider(slider,value)
    if slider.IsDraggingThumb and slider:IsDraggingThumb() then return end
    slider:SetValue(value)
end
function S:Refresh()
    if not self.frame then return end
    visible={}
    self:RefreshLook()
    for _,control in ipairs(self.lookControls) do if not visible[control] then control:Hide() end end
    for _,chip in ipairs(self.chips) do if not visible[chip] then chip:Hide() end end
end
function S:RefreshLook()
    local g=self:CurrentGroup(); local root=self:Settings()
    for _,entry in ipairs(groups) do FT:SetSelected(self.groupButtons[entry.key],g.key==entry.key) end
    self.heading:SetText(g.label)
    local everything=g.key=="everything"
    self.allPresetChoice:SetShown(everything); self.applyAll:SetShown(everything)
    self.allPresetChoice.value=self.allPreset or "dark"
    for _,p in ipairs(self.presets) do if p.value==self.allPresetChoice.value then self.allPresetChoice.label:SetText(p.label) end end
    if everything then return end
    -- Which parts are skinned: one switch each, two per row. Kept apart
    -- from the look below, so changing the look never turns a part off.
    local y=-138
    self.partsHead:SetText("Skin these parts"); place(self.partsHead,176,y); y=y-22
    for i,part in ipairs(g.parts) do
        local chip=self.chips[i]
        chip.part=part
        local on=root[part]==true
        chip.label:SetText((partLabels[part] or part)..": "..(on and "On" or "Off"))
        place(chip,(i%2==1) and 176 or 391,y-math.floor((i-1)/2)*38)
    end
    y=y-math.ceil(#g.parts/2)*38-8
    self.lookHead:SetText("Look"); place(self.lookHead,176,y); y=y-22
    local looks=lookParts(g)
    local edited=self:EditedParts()
    local s=self:Lead()
    if #looks>1 then
        local target=self:EditTarget(g)
        self.partChoice.value=target
        self.partChoice.label:SetText("Change the look of: "..(target=="all" and "All parts" or partLabels[target] or target))
        place(self.partChoice,176,y)
        y=y-40
    end
    self.presetChoice.value=s.preset
    for _,p in ipairs(self.presets) do if p.value==s.preset then self.presetChoice.label:SetText("Style: "..p.label) end end
    place(self.presetChoice,176,y); y=y-40
    local icons=has(edited,ICONS); local panels=has(edited,PANELS)
    -- (The bag bar has no fill of its own: only its frame is recolored.)
    local fill=(icons and not (#edited==1 and edited[1]=="buffs")) or panels
    place(self.borderButton,176,y)
    if fill then
        self.colorButton.label:SetText(panels and "Background color" or "Shading color")
        place(self.colorButton,391,y)
    end
    y=y-40
    self.settingSlider=true; setSlider(self.opacitySlider,1-s.opacity); setSlider(self.borderSlider,1-s.borderOpacity); self.settingSlider=false
    self.borderLabel:SetText("Border transparency: "..math.floor(100-s.borderOpacity*100+.5).."%")
    place(self.borderLabel,176,y); place(self.borderSlider,406,y+3); y=y-36
    if fill then
        self.opacityLabel:SetText((panels and "Background transparency: " or "Fill transparency: ")..math.floor(100-s.opacity*100+.5).."%")
        place(self.opacityLabel,176,y); place(self.opacitySlider,406,y+3); y=y-36
    end
    -- Switches that belong to one kind of part, two per row.
    local buttons={}
    if icons then
        self.thickness.value=s.thickness; self.thickness.label:SetText("Border: "..s.thickness.." px")
        self.shadow.label:SetText("Shadow: "..(s.shadow and "On" or "Off")); FT:SetSelected(self.shadow,s.shadow)
        buttons[#buttons+1]=self.thickness; buttons[#buttons+1]=self.shadow
    end
    local unitArt=false; for _,p in ipairs(edited) do if UNITART[p] then unitArt=true end end
    if unitArt then
        for _,entry in ipairs({{"rares",self.rares},{"elites",self.elites}}) do
            local value=false; for _,p in ipairs(edited) do if UNITART[p] and self:Area(p)[entry[1]] then value=true end end
            entry[2].label:SetText((entry[1]=="rares" and "Darken rares: " or "Darken elites: ")..(value and "On" or "Off")); FT:SetSelected(entry[2],value)
            buttons[#buttons+1]=entry[2]
        end
    end
    if contains(edited,"bags") then
        local b=self:Area("bags")
        self.bagStyle.label:SetText("Bar slots: "..(b.barStyle=="action" and "Action bars" or "Game frames")); FT:SetSelected(self.bagStyle,b.barStyle=="action")
        buttons[#buttons+1]=self.bagStyle
    end
    if contains(edited,"minimap") then
        local m=self:Area("minimap")
        for key,b in pairs(self.ringChoices) do b.label:SetText(b.ftTitle..": "..(m[key]=="dark" and "Dark" or "Game")) end
        buttons[#buttons+1]=self.ringChoices.addonRings; buttons[#buttons+1]=self.ringChoices.gearRing
    end
    if contains(edited,"micro") then
        local m=self:Area("micro")
        self.microOutline.label:SetText("Extra outline: "..(m.hideSecondary and "Off" or "On")); FT:SetSelected(self.microOutline,not m.hideSecondary)
        buttons[#buttons+1]=self.microOutline
    end
    local artKey=(contains(edited,"bagWindows") and "bagWindows") or (contains(edited,"dialogs") and "dialogs") or (contains(edited,"gryphons") and "gryphons")
    self.hideArtKey=artKey
    if artKey then
        local a=self:Area(artKey)
        self.hideArt.label:SetText((artKey=="gryphons" and "Hide gryphons: " or "Hide window art: ")..(a.hideArt and "On" or "Off")); FT:SetSelected(self.hideArt,a.hideArt)
        buttons[#buttons+1]=self.hideArt
    end
    if contains(edited,"bagWindows") then
        local b=self:Area("bagWindows")
        self.hideSlotArt.label:SetText("Hide empty slot art: "..(b.hideSlotArt and "On" or "Off")); FT:SetSelected(self.hideSlotArt,b.hideSlotArt)
        self.slotColorSwatch:SetVertexColor(unpack(b.slotColor))
        buttons[#buttons+1]=self.hideSlotArt; buttons[#buttons+1]=self.slotColorButton
    end
    if contains(edited,"dialogs") then
        local d=self:Area("dialogs")
        self.parchment.label:SetText("Dark parchment: "..(d.darkParchment and "On" or "Off")); FT:SetSelected(self.parchment,d.darkParchment)
        buttons[#buttons+1]=self.parchment
    end
    for i,b in ipairs(buttons) do
        b:SetWidth(205)
        place(b,(i%2==1) and 176 or 391,y)
        if i%2==0 or i==#buttons then y=y-38 end
    end
    if contains(edited,"bagWindows") then
        local b=self:Area("bagWindows")
        self.settingSlider=true;setSlider(self.slotSlider,1-b.slotOpacity);self.settingSlider=false
        self.slotLabel:SetText("Slot transparency: "..math.floor(100-b.slotOpacity*100+.5).."%")
        place(self.slotLabel,176,y); place(self.slotSlider,406,y+3); y=y-36
    end
    if icons and s.shadow then
        self.settingSlider=true; setSlider(self.shadowSizeSlider,s.shadowSize); setSlider(self.shadowStrengthSlider,s.shadowStrength); self.settingSlider=false
        self.shadowSizeLabel:SetText("Shadow size: "..s.shadowSize.." px")
        self.shadowStrengthLabel:SetText("Shadow darkness: "..math.floor(s.shadowStrength*100+.5).."%")
        place(self.shadowSizeLabel,176,y); place(self.shadowSizeSlider,406,y+3); y=y-36
        place(self.shadowStrengthLabel,176,y); place(self.shadowStrengthSlider,406,y+3); y=y-36
    end
    self.colorSwatch:SetVertexColor(unpack(s.color)); self.borderSwatch:SetVertexColor(unpack(s.borderColor))
    visible[self.reset]=true; self.reset:Show()
end
function S:Open()
    self.selected=self.selected or "everything"
    if not self.frame then
        self.frame=FT:Window("ForeverToolsIconStyles","Skins",620,550); FT:AppearanceBack(self.frame); self.groupButtons={}
        FT:PageInfo(self.frame,"Skins","Pick a group on the left. Switch parts on under Skin these parts, then choose their look.\n\nChange the look of: all parts, or one part.")
        for i,entry in ipairs(groups) do
            local key=entry.key; local button=FT:QuietButton(self.frame,entry.label,140,32,"skins"); button.label:SetFont(FT.bodyFont,12,""); button:SetPoint("TOPLEFT",20,-66-(i-1)*38)
            button:SetScript("OnClick",function() self.selected=key; self:Refresh() end); self.groupButtons[key]=button
            FT:Tooltip(button,entry.label,key=="everything" and "Templates for every area at once." or function()
                local on,total=0,#entry.parts; for _,p in ipairs(entry.parts) do if self:Settings()[p] then on=on+1 end end
                return on.." of "..total.." on. Click to see this group."
            end)
        end
        self.allPreset="dark"
        self.allPresetChoice=FT:Dropdown(self.frame,420,function() local choices={}; for _,p in ipairs(self.presets) do if p.value~="custom" then choices[#choices+1]=p end end; return choices end,function(value) self.allPreset=value; self:Refresh() end,"skins"); self.allPresetChoice:SetPoint("TOPLEFT",176,-148)
        local all=FT:AccentButton(self.frame,"Apply template to all areas",420,34,"skins");all:SetPoint("TOPLEFT",176,-194); self.applyAll=all
        all:SetScript("OnClick",function() FT:Confirm("Give every area this template? Current colors are replaced.",function() self:ApplyPresetToAll(self.allPreset) end) end)
        FT:Tooltip(all,"Apply to all areas","Turn on every area with the chosen template.")
        self.heading=FT:Label(self.frame,"",20,true); self.heading:SetPoint("TOPLEFT",176,-102)
        local reset=FT:QuietButton(self.frame,"Reset look",120,28,"reset"); reset:SetPoint("TOPLEFT",476,-100); self.reset=reset
        FT:Tooltip(reset,"Reset","Back to the starting look. Asks first.")
        reset:SetScript("OnClick",function() FT:Confirm("Reset the look of these parts to their defaults?",function() local root=self:Settings(); for _,key in ipairs(self:EditedParts()) do root.areas[key]=nil; self:Area(key) end; self:Apply() end) end)
        -- Part switches (up to 8 per group, four per row).
        self.partsHead=FT:Label(self.frame,"",13,true); self.partsHead:SetTextColor(.66,.59,.48); FT:SectionHeading(self.partsHead,nil,300)
        self.lookHead=FT:Label(self.frame,"",13,true); self.lookHead:SetTextColor(.66,.59,.48); FT:SectionHeading(self.lookHead,nil,300)
        self.chips={}
        for i=1,8 do
            local chip=FT:QuietButton(self.frame,"",205,32); chip:Hide()
            chip:SetScript("OnClick",function(owner) local root=self:Settings(); root[owner.part]=not root[owner.part]; self:Apply(); peekPart(owner.part) end)
            FT:Tooltip(chip,function() return partLabels[chip.part] or "" end,function()
                if partTips[chip.part] then return partTips[chip.part] end
                return ((self:Settings()[chip.part] and "On" or "Off")..". Click to turn the skin for "..(partLabels[chip.part] or ""):lower().." on or off.")
            end)
            self.chips[i]=chip
        end
        self.partChoice=FT:Dropdown(self.frame,420,function()
            local out={{value="all",label="All parts",tooltip="Changes go to every part of this group."}}
            for _,p in ipairs(lookParts(self:CurrentGroup())) do out[#out+1]={value=p,label=partLabels[p] or p,tooltip="Changes go to this part only."} end
            return out
        end,function(value) local g=self:CurrentGroup(); self.editPart=self.editPart or {}; self.editPart[g.key]=value; self:Refresh() end,"skins")
        FT:Tooltip(self.partChoice,"Editing","Change all parts of the group, or one part.")
        self.presetChoice=FT:Dropdown(self.frame,420,function() return self.presets end,function(value) self:UsePreset(value) end,"skins")
        local function colorButton(label,field)
            local b=FT:QuietButton(self.frame,label,205,32,"fonts"); b:SetScript("OnClick",function() self:OpenColorPicker(field) end)
            local swatch=b:CreateTexture(nil,"ARTWORK"); swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); swatch:SetSize(16,16); swatch:SetPoint("RIGHT",-10,0); return b,swatch
        end
        self.borderButton,self.borderSwatch=colorButton("Border color","borderColor")
        self.colorButton,self.colorSwatch=colorButton("Shading color","color")
        FT:Tooltip(self.borderButton,"Border color","Border color.")
        FT:Tooltip(self.colorButton,function() return self.colorButton.label:GetText() end,"Fill or background color.")
        local function slider(callback)
            -- The label has its own space left of the slider and never runs into it.
            local label=FT:Label(self.frame,"",13); label:SetWidth(214); label:SetJustifyH("LEFT")
            if label.SetWordWrap then label:SetWordWrap(false) end
            local slider=CreateFrame("Slider",nil,self.frame,"OptionsSliderTemplate"); slider:SetSize(190,18); slider:SetMinMaxValues(0,1); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
            slider:SetScript("OnValueChanged",function(_,value) if not self.settingSlider then callback(value) end end)
            local low=slider.Low or (slider.GetName and slider:GetName() and _G[slider:GetName().."Low"])
            local high=slider.High or (slider.GetName and slider:GetName() and _G[slider:GetName().."High"])
            if low and low.SetText then low:SetText("Solid") end
            if high and high.SetText then high:SetText("See-through") end
            return label,slider
        end
        self.borderLabel,self.borderSlider=slider(function(v) self:EachEdited(function(s) s.borderOpacity=1-v end); self:LiveApply() end)
        FT:Tooltip(self.borderSlider,"Border transparency","0% solid, 100% hidden.")
        self.opacityLabel,self.opacitySlider=slider(function(v) self:SetOpacity(1-v) end)
        FT:Tooltip(self.opacitySlider,"Fill transparency","0% solid, 100% hidden.")
        self.slotLabel,self.slotSlider=slider(function(v) self:Area("bagWindows").slotOpacity=1-v;self:LiveApply() end)
        FT:Tooltip(self.slotSlider,"Slot color transparency","0% solid, 100% hidden.")
        self.slotColorButton,self.slotColorSwatch=colorButton("Slot color","slotColor")
        self.slotColorButton:SetScript("OnClick",function()
            local b=self:Area("bagWindows"); local old={unpack(b.slotColor)}
            local function change() local r,g,bl=ColorPickerFrame:GetColorRGB(); b.slotColor={r,g,bl}; self:LiveApply() end
            local function cancel() b.slotColor=old; self:Apply() end
            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker(); ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel}) end
        end)
        FT:Tooltip(self.slotColorButton,"Bag slot color","The square behind each bag slot.")
        self.thickness=FT.modules.FontManager:Stepper(self.frame,205,function() local choices={}; for i=1,4 do choices[i]={value=i} end; return choices end,function(v) self:EachEdited(function(s) s.thickness=v end); self:Apply() end)
        FT:Tooltip(self.thickness,"Border thickness","Border thickness.")
        for _,step in ipairs({self.thickness.minus,self.thickness.plus}) do if step then FT:Tooltip(step,"Border thickness","Border thickness (1 to 4).") end end
        self.shadow=FT:QuietButton(self.frame,"",205,32,"skins")
        self.shadow:SetScript("OnClick",function() local on=not self:Lead().shadow; self:EachEdited(function(s) s.shadow=on end); self:Apply() end)
        FT:Tooltip(self.shadow,"Shadow","A soft shadow around each icon.")
        local function ends(slider,low,high)
            local l=slider.Low or (slider.GetName and slider:GetName() and _G[slider:GetName().."Low"])
            local h=slider.High or (slider.GetName and slider:GetName() and _G[slider:GetName().."High"])
            if l and l.SetText then l:SetText(low) end; if h and h.SetText then h:SetText(high) end
        end
        self.shadowSizeLabel,self.shadowSizeSlider=slider(function(v) self:EachEdited(function(s) s.shadowSize=math.floor(v+.5) end); self:LiveApply() end)
        self.shadowSizeSlider:SetMinMaxValues(1,8); self.shadowSizeSlider:SetValueStep(1); ends(self.shadowSizeSlider,"Tight","Wide")
        FT:Tooltip(self.shadowSizeSlider,"Shadow size","How far the shadow reaches (1 to 8).")
        self.shadowStrengthLabel,self.shadowStrengthSlider=slider(function(v) self:EachEdited(function(s) s.shadowStrength=v end); self:LiveApply() end)
        self.shadowStrengthSlider:SetMinMaxValues(.1,1); ends(self.shadowStrengthSlider,"Light","Dark")
        FT:Tooltip(self.shadowStrengthSlider,"Shadow darkness","How dark the shadow is.")
        for _,key in ipairs({"rares","elites"}) do
            local option=key; local b=FT:QuietButton(self.frame,"",205,32,"skins")
            b:SetScript("OnClick",function()
                local value=false; for _,p in ipairs(self:EditedParts()) do if UNITART[p] and self:Area(p)[option] then value=true end end
                for _,p in ipairs(self:EditedParts()) do if UNITART[p] then self:Area(p)[option]=not value end end
                self:Apply()
            end); self[key]=b
            FT:Tooltip(b,"Rare / elite artwork","Also color the rare or elite dragon.")
        end
        self.bagStyle=FT:QuietButton(self.frame,"",205,32,"INV_Misc_Bag_08")
        FT:MakeChoice(self.bagStyle,{{"game","Game frames","The game's frames in your border color."},{"action","Action bars","Plain square icons, like action buttons."}},function() return self:Area("bags").barStyle end,function(v) self:Area("bags").barStyle=v; self:Apply() end)
        FT:Tooltip(self.bagStyle,"Bag bar slots","Game frames, or plain square icons like action buttons.")
        -- Gold or dark rings: the ForeverTools button, the grouped buttons'
        -- gear, and the other addons' buttons, each on its own.
        self.ringChoices={}
        for _,e in ipairs({{"addonRings","Addon rings","The ForeverTools button and other addons' minimap buttons, on the minimap and in the group."},{"gearRing","Group ring","The gear that opens your grouped minimap buttons."}}) do
            local key=e[1]
            local b=FT:QuietButton(self.frame,"",205,32,"map"); b.ftTitle=e[2]
            FT:MakeChoice(b,{{"game","Game","The game's gold ring."},{"dark","Dark","The ring in your border color."}},function() return self:Area("minimap")[key]=="dark" and "dark" or "game" end,function(v) self:Area("minimap")[key]=v; self:Apply() end)
            FT:Tooltip(b,e[2],e[3].." Gold like the game, or dark in your border color.")
            self.ringChoices[key]=b
        end
        self.microOutline=FT:QuietButton(self.frame,"",205,32,"skins")
        self.microOutline:SetScript("OnClick",function() local s=self:Area("micro");s.hideSecondary=not s.hideSecondary;self:Apply() end)
        FT:Tooltip(self.microOutline,"Extra micro menu outline","The outer border of the micro menu.")
        self.hideArt=FT:QuietButton(self.frame,"",205,32,"skins")
        self.hideArt:SetScript("OnClick",function() local key=self.hideArtKey; if not key then return end; local s=self:Area(key);s.hideArt=not s.hideArt;self:Apply() end)
        FT:Tooltip(self.hideArt,"Blizzard art",function() return self.hideArtKey=="bagWindows" and "Use your background color instead of the texture." or self.hideArtKey=="dialogs" and "Use your background color instead of the texture." or "Hide the gryphons at the bar's ends." end)
        self.hideSlotArt=FT:QuietButton(self.frame,"",205,32,"skins")
        self.hideSlotArt:SetScript("OnClick",function() local s=self:Area("bagWindows");s.hideSlotArt=not s.hideSlotArt;self:Apply() end)
        FT:Tooltip(self.hideSlotArt,"Empty slot art","Hide the picture in empty bag slots.")
        self.parchment=FT:QuietButton(self.frame,"",205,32,"INV_Misc_Note_04")
        self.parchment:SetScript("OnClick",function() local s=self:Area("dialogs");s.darkParchment=not s.darkParchment;self:Apply() end)
        FT:Tooltip(self.parchment,"Dark parchment","Dark quest and NPC parchment with light text.")
        self.lookControls={self.partChoice,self.presetChoice,self.borderButton,self.colorButton,self.borderLabel,self.borderSlider,self.opacityLabel,self.opacitySlider,
            self.slotLabel,self.slotSlider,self.slotColorButton,self.thickness,self.shadow,self.shadowSizeLabel,self.shadowSizeSlider,self.shadowStrengthLabel,self.shadowStrengthSlider,
            self.rares,self.elites,self.bagStyle,self.ringChoices.addonRings,self.ringChoices.gearRing,self.microOutline,self.hideArt,self.hideSlotArt,self.parchment,self.reset,self.partsHead,self.lookHead}
        FT:Tooltip(self.presetChoice,"Template","The style of these parts.")
        FT:Tooltip(self.allPresetChoice,"Template for all areas","Pick a template, then apply it everywhere.")
    end
    self:Apply(); self.frame:Show()
end
