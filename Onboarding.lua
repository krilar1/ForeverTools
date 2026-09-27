local _,FT=...
-- First-time setup (once per account, fresh installs only) and "What's new"
-- (once per version, existing users only). New characters never see either.
local Onboarding={}
local skinAreas={"actions","buffs","stances","minimap","bags","bagWindows","micro","xp","player","target","tot","focus","focustarget"}
local presets={
    {key="minimal",label="Minimal",icon="generic",text="Blizzard's own look. Nothing is skinned or recolored; turn on single features whenever you like."},
    {key="dark",label="Dark mode",icon="skins",text="Dark borders on action bars, buffs, bags, micro menu, minimap, XP bar and unit frames. Nothing else changes."},
    {key="full",label="Full",icon="classes",text="Dark mode plus class-colored health bars, the FPS counter, the flight timer and target and guild lines in player tooltips."},
}
local extras={
    {key="rankMarker",label="Low-rank marker",icon="buffs",text="A small amber corner on action buttons that use a lower rank than you know."},
    {key="leveling",label="Leveling stats",icon="fps",text="XP per hour, time to level and kills to level in a small line at the top left."},
    {key="reminders",label="Buff reminders",icon="buffs",text="A quiet notice when one of your own buffs is missing."},
    {key="autoSell",label="Auto-sell grey items",icon="generic",text="Sell junk automatically when you open a merchant."},
    {key="autoRepair",label="Auto-repair",icon="generic",text="Repair automatically at merchants who can repair."},
    {key="chatLinks",label="Clickable chat links",icon="chat",text="Web addresses in chat open a copy box when clicked."},
}
local function extraValue(key)
    local db=FT.db
    if key=="rankMarker" then return FT.modules.BuffReminder:Settings().rankMarker==true end
    if key=="leveling" then return FT.modules.Leveling:Settings().enabled==true end
    if key=="reminders" then return FT.modules.BuffReminder:Settings().enabled==true end
    return FT.modules.System:Settings()[key]==true
end
function Onboarding:ApplyChoices(preset,chosen)
    local skins=FT.modules.IconStyles:Settings()
    if preset then
        local dark=preset~="minimal"; local full=preset=="full"
        for _,key in ipairs(skinAreas) do skins[key]=dark end
        local colors=FT.modules.UnitColors:Settings()
        for _,key in ipairs({"player","target","focus"}) do colors[key]=full end
        FT.modules.QualityOfLife:Settings().enabled=full
        FT.modules.FlightTimer:Settings().enabled=full
        local tip=FT.modules.Tooltip:Settings(); tip.target=full; tip.guild=full
    end
    local reminders=FT.modules.BuffReminder:Settings()
    reminders.rankMarker=chosen.rankMarker==true
    reminders.enabled=chosen.reminders==true
    FT.modules.Leveling:Settings().enabled=chosen.leveling==true
    local system=FT.modules.System:Settings()
    system.autoSell=chosen.autoSell==true; system.autoRepair=chosen.autoRepair==true; system.chatLinks=chosen.chatLinks==true
    for _,name in ipairs({"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","LootRoll","BuffReminder","FlightTimer","Leveling"}) do
        local module=FT.modules[name]; if module and module.Apply then pcall(module.Apply,module) end
    end
    if FT.modules.Profiles then FT.modules.Profiles:Checkpoint() end
end
function Onboarding:Finish(keepProfile)
    FT.db.setupDone=true
    FT.db.lastSeenVersion=FT.version
    -- Store the result in this character's profile so other characters and
    -- future sessions can reuse it (the active profile, or one named after the character).
    local profiles=FT.modules.Profiles
    if profiles and not keepProfile then
        local name=(profiles.active and profiles:Store()[profiles.active]) and profiles.active or profiles:CharacterName()
        profiles:Save(name,true,true)
    end
    if self.frame then self.skipping=true; self.frame:Hide(); self.skipping=nil end
end
function Onboarding:Refresh()
    if not self.frame then return end
    for key,button in pairs(self.presetButtons) do FT:SetSelected(button,self.preset==key) end
    local text="Your current settings stay as they are unless you pick a preset."
    for _,preset in ipairs(presets) do if preset.key==self.preset then text=preset.text end end
    self.presetText:SetText(text)
    for key,button in pairs(self.extraButtons) do
        button.label:SetText(button.title..": "..(self.chosen[key] and "On" or "Off")); FT:SetSelected(button,self.chosen[key])
    end
end
function Onboarding:ShowSetup(again)
    if InCombatLockdown() then FT:CombatOpenRequest(); return end
    if not self.frame then
        local frame=FT:Window("ForeverToolsSetup","Welcome to ForeverTools",560,470); self.frame=frame
        frame.noSavePrompt=true -- setup saves its own result to the profile
        frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame.homeButton:Hide()
        local intro=FT:Label(frame,"",14); intro:SetPoint("TOPLEFT",24,-58); intro:SetWidth(512); self.intro=intro
        local head=FT:Label(frame,"Start with",15,true); head:SetPoint("TOPLEFT",24,-104); FT:SectionHeading(head,"INV_Misc_Book_11",380)
        self.presetButtons={}
        for i,preset in ipairs(presets) do
            local b=FT:QuietButton(frame,preset.label,164,40,preset.icon)
            b:SetPoint("TOPLEFT",24+(i-1)*174,-128)
            b:SetScript("OnClick",function() self.preset=preset.key; self:Refresh() end)
            FT:Tooltip(b,preset.label,preset.text)
            self.presetButtons[preset.key]=b
        end
        self.presetText=FT:Label(frame,"",13); self.presetText:SetPoint("TOPLEFT",24,-176); self.presetText:SetWidth(512)
        self.presetText:SetTextColor(.78,.74,.86)
        local extraHead=FT:Label(frame,"Also turn on",15,true); extraHead:SetPoint("TOPLEFT",24,-222); FT:SectionHeading(extraHead,"INV_Misc_Note_02",380)
        self.extraButtons={}
        for i,extra in ipairs(extras) do
            local b=FT:QuietButton(frame,"",250,32,extra.icon); b.title=extra.label
            b:SetPoint("TOPLEFT",24+((i-1)%2)*262,-246-math.floor((i-1)/2)*40)
            b:SetScript("OnClick",function() self.chosen[extra.key]=not self.chosen[extra.key]; self:Refresh() end)
            FT:Tooltip(b,extra.label,extra.text)
            self.extraButtons[extra.key]=b
        end
        local note=FT:Label(frame,"You can change everything later in /ft.",12)
        note:SetPoint("TOPLEFT",24,-374); note:SetWidth(512); note:SetTextColor(.66,.57,.77)
        local import=FT:QuietButton(frame,"Import profile",160,34,"profiles"); import:SetPoint("BOTTOMLEFT",24,22)
        import:SetScript("OnClick",function()
            FT.modules.Profiles:Transfer(true,function(name)
                FT.modules.Profiles:Load(name,false,true)
                self:Finish(true)
                FT:Toast('Profile "'..name..'" imported and loaded.',4)
            end)
        end)
        FT:Tooltip(import,"Import profile","Paste a ForeverTools export string from another computer or account. It is loaded right away.")
        local skip=FT:QuietButton(frame,"Skip",160,34,"reset"); skip:SetPoint("BOTTOM",0,22)
        skip:SetScript("OnClick",function() self:Finish(); FT:Toast("No changes made. Open /ft any time.",3) end)
        FT:Tooltip(skip,"Skip","Keep your current settings. You can run this setup again from System > General.")
        local apply=FT:AccentButton(frame,"Apply",160,34,"confirm"); apply:SetPoint("BOTTOMRIGHT",-24,22)
        apply:SetScript("OnClick",function()
            if InCombatLockdown() then return end
            self:ApplyChoices(self.preset,self.chosen); self:Finish()
            FT:Toast("Setup applied. Open /ft any time.",3)
        end)
        -- Closing with X or Escape counts as Skip, so it never returns uninvited.
        frame:HookScript("OnHide",function() if not self.skipping and FT.db.setupDone~=true then self:Finish() end end)
    end
    self.again=again
    self.preset=not again and "minimal" or nil
    self.intro:SetText(again and "Pick a preset to replace your current look, or only change the extras below." or "Everything starts off, so your interface looks like Blizzard's. Pick a starting point; you can change anything later.")
    self.chosen={}
    for _,extra in ipairs(extras) do self.chosen[extra.key]=extraValue(extra.key) end
    self:Refresh()
    FT:PlaceBeside(self.frame)
    self.frame:Show()
end
-- "What's new": a small card panel near the top right (below the minimap),
-- not in the middle of the screen. Each note is an icon, a short title and
-- one short line. Older plain-text notes still work.
local NEWS_WIDTH, CARD_HEIGHT, CARD_GAP = 400, 50, 6
local function newsCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(NEWS_WIDTH - 40, CARD_HEIGHT)
    FT:RoundedFill(card, 0.09, 0.075, 0.13, 1)
    card.icon = card:CreateTexture(nil, "ARTWORK"); card.icon:SetSize(34, 34); card.icon:SetPoint("LEFT", 8, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    card.title = FT:Label(card, "", 14, true); card.title:SetPoint("TOPLEFT", 52, -8); card.title:SetWidth(NEWS_WIDTH - 104)
    card.title:SetTextColor(1, 0.84, 0.45)
    card.text = FT:Label(card, "", 12); card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3); card.text:SetWidth(NEWS_WIDTH - 104)
    card.text:SetTextColor(0.86, 0.82, 0.93)
    return card
end
function Onboarding:ShowWhatsNew()
    local entry=FT.changelog and FT.changelog[1]
    if not entry or InCombatLockdown() then return end
    if not self.news then
        local frame=FT:Window("ForeverToolsWhatsNew","What's new",NEWS_WIDTH,300); self.news=frame
        frame.noSavePrompt=true
        frame.homeButton:Hide()
        frame.logo=frame:CreateTexture(nil,"ARTWORK"); frame.logo:SetSize(40,40); frame.logo:SetPoint("TOPLEFT",18,-16)
        frame.logo:SetTexture("Interface\\AddOns\\ForeverTools\\Media\\MinimapIcon.tga")
        frame.titleText:ClearAllPoints(); frame.titleText:SetPoint("TOPLEFT",66,-18)
        frame.sub=FT:Label(frame,"",12); frame.sub:SetPoint("TOPLEFT",66,-42); frame.sub:SetTextColor(.66,.57,.77)
        FT:SetTitleLine(frame,64)
        frame.cards={}
        local off=FT:QuietButton(frame,"Don't show again",170,30,"reset"); off:SetPoint("BOTTOMLEFT",20,18)
        off:SetScript("OnClick",function() FT.modules.System:Settings().hideWhatsNew=true; frame:Hide(); FT:Toast("Turn it back on in System > General.",3) end)
        FT:Tooltip(off,"Don't show again","Stop showing this after updates. You can still open it from System > General.")
        local close=FT:AccentButton(frame,"Got it",120,30,"confirm"); close:SetPoint("BOTTOMRIGHT",-20,18)
        close:SetScript("OnClick",function() frame:Hide() end)
    end
    local frame=self.news
    frame.titleText:SetText("What's new")
    frame.sub:SetText("ForeverTools v"..entry.version)
    for _,card in ipairs(frame.cards) do card:Hide() end
    local y=-74
    for index,note in ipairs(entry.notes) do
        local card=frame.cards[index] or newsCard(frame); frame.cards[index]=card
        local icon,title,text
        if type(note)=="table" then icon,title,text=note.icon,note.title,note.text
        else text=tostring(note) end
        card.icon:SetTexture("Interface\\Icons\\"..(icon or "INV_Misc_Note_01"))
        card.title:SetText(title or ""); card.title:SetShown(title~=nil)
        card.text:ClearAllPoints()
        if title then card.text:SetPoint("TOPLEFT",card.title,"BOTTOMLEFT",0,-3) else card.text:SetPoint("LEFT",52,0) end
        card.text:SetText(text or "")
        local height=math.max(CARD_HEIGHT,(title and 29 or 16)+(card.text:GetStringHeight() or 14))
        card:SetHeight(height)
        card:ClearAllPoints(); card:SetPoint("TOPLEFT",20,y); card:Show()
        y=y-height-CARD_GAP
    end
    frame:SetHeight(-y+62)
    -- Near the top right, below the minimap and clear of the screen corner.
    frame:ClearAllPoints(); frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-240,-190)
    frame:Show()
end
-- One check per login, after profiles and settings are in place.
function Onboarding:Check()
    if self.checked or not FT.dbReady then return end
    if InCombatLockdown() then self.waiting=true; return end
    self.checked=true; self.waiting=nil
    if FT.db.setupDone==nil then
        -- Existing installs skip setup; only a fresh install gets it.
        if FT.freshInstall then self:ShowSetup(false); return end
        FT.db.setupDone=true
    end
    if FT.db.setupDone~=true then self:ShowSetup(false); return end
    if FT.db.lastSeenVersion~=FT.version then
        local updated=FT.db.lastSeenVersion~=nil or not FT.freshInstall
        FT.db.lastSeenVersion=FT.version
        if updated and FT.modules.System:Settings().hideWhatsNew~=true then self:ShowWhatsNew() end
    end
end
FT:RegisterModule("Onboarding",Onboarding)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then C_Timer.After(3,function() Onboarding:Check() end)
    elseif Onboarding.waiting then C_Timer.After(1,function() Onboarding:Check() end) end
end)
