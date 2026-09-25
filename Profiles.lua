local _, FT = ...
local Profiles = {}
function Profiles:Character()
    return UnitGUID("player")
end
function Profiles:Remember(name)
    FT.db.profileCharacters=FT.db.profileCharacters or {}
    local guid=self:Character()
    if guid then FT.db.profileCharacters[guid]=name or false end
    if name then FT.db.lastProfile=name end
    self.active=name
    self:RefreshIndicators()
end
local function shortName(name,limit)
    if #name<=limit then return name end
    return name:sub(1,limit-3).."..."
end
function Profiles:IndicatorHelp()
    if self.active then return "Editing profile: "..self.active..". Click to switch profiles. Changes apply immediately; save the profile to keep them." end
    return "No profile selected. Click to choose one, or make changes and save a new profile from Home."
end
function Profiles:RefreshIndicators()
    local name=self.active and self:Store()[self.active] and self.active or nil
    for _,module in pairs(FT.modules) do
        local badge=module.frame and module.frame.profileBadge
        if badge then
            badge.label:SetText(name and shortName(name,15) or "No profile")
            if badge.label.SetWordWrap then badge.label:SetWordWrap(false) end
            FT:SetSelected(badge,name~=nil)
        end
    end
    if FT.home and FT.home.profileStatus then
        FT.home.profileStatus:SetText(name and shortName("Editing: "..name,27) or "No profile")
        FT.home.profileStatus:SetTextColor(name and .82 or .66,name and .68 or .57,name and 1 or .77)
    end
end
function Profiles:ShowSwitcher(owner)
    local list={}
    for name,profile in pairs(self:Store()) do
        if type(name)=="string" and type(profile)=="table" then
            list[#list+1]={value=name,label=name,icon="Interface\\Icons\\INV_Misc_Book_09"}
        end
    end
    table.sort(list,function(a,b) return a.label<b.label end)
    list[#list+1]={value="\001manage",label="Manage profiles...",icon="Interface\\Icons\\INV_Misc_Book_09"}
    owner.options=function() return list end
    owner.menuWidth=300
    owner.value=self.active
    owner.onSelect=function(value)
        if value=="\001manage" then FT:OpenHome();self.panel:Show();return end
        if value==self.active then return end
        local function switch() self:Load(value,true) end
        if self.baseline and FT:EncodeProfile(self:Snapshot())~=self.baseline then
            FT:Confirm("Switch to profile \""..value.."\"? Unsaved changes to the current setup will be replaced.",switch)
        else switch() end
    end
    FT:ShowChoices(owner)
end
-- Only preferences are copied. Macro history and installed WoW macros belong to
-- the character and are never rewritten by loading an appearance profile.
local keys={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","macroScope","chat","system","customKeybinds","customFonts","lootRoll","tooltip","buffReminder","customMacros","flightTimer","leveling"}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
function Profiles:Store()
    if type(FT.db.profiles) ~= "table" then FT.db.profiles={} end
    if type(FT.db.profileVault)=="table" then
        for name,profile in pairs(FT.db.profileVault) do
            if FT.db.profiles[name]==nil and type(profile)=="table" then FT.db.profiles[name]=copy(profile) end
        end
    else FT.db.profileVault={} end
    for name,profile in pairs(FT.db.profiles) do
        if FT.db.profileVault[name]==nil and type(profile)=="table" then FT.db.profileVault[name]=copy(profile) end
    end
    return FT.db.profiles
end
function Profiles:Snapshot()
    local result={}
    for _,key in ipairs(keys) do result[key]=copy(FT.db[key]) end
    for _,entry in ipairs(type(result.customMacros)=="table" and result.customMacros or {}) do
        if type(entry)=="table" and type(entry.name)=="string" then entry.savedBody=FT:MacroBody(entry,entry.code) end
    end
    return result
end
function Profiles:Save(name, overwrite, quiet)
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    if name=="" or #name>120 then FT:Toast("Enter a profile name (1–120 characters)."); return false end
    if self:Store()[name] and not overwrite then FT:Toast("That profile name already exists."); return false end

    self:Archive(name)
    self:Store()[name]=self:Snapshot(); FT.db.profileVault[name]=copy(self:Store()[name]); self.selected=name
    self:Remember(name)
    self:Checkpoint(); self:Refresh(); if not quiet then FT:Toast("Profile saved: "..name) end; return true
end
-- Content the player made (custom macros, font files, macro destination) is
-- carried into a new profile; every setting starts from its default.
local content={customMacros=true,customFonts=true,macroScope=true}
function Profiles:Create(name)
    if InCombatLockdown() then FT:Toast("Create profiles outside combat."); return false end
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    if name=="" or #name>120 then FT:Toast("Enter a profile name (1–120 characters)."); return false end
    if self:Store()[name] then FT:Toast("That profile name already exists."); return false end
    local fresh={}
    for key in pairs(content) do fresh[key]=copy(FT.db[key]) end
    for _,entry in ipairs(type(fresh.customMacros)=="table" and fresh.customMacros or {}) do
        if type(entry)=="table" and type(entry.name)=="string" then entry.savedBody=FT:MacroBody(entry,entry.code) end
    end
    self:Store()[name]=fresh; FT.db.profileVault[name]=copy(fresh)
    if not self:Load(name,false,true) then return false end
    self:Refresh()
    if self.panel then self.panel:Hide() end
    FT:Toast('Profile "'..name..'" created with default settings.',3)
    return true
end
function Profiles:Load(name,stayPage,silent)
    if InCombatLockdown() then FT:Toast("Load profiles outside combat."); return false end
    local saved=self:Store()[name]; if type(saved)~="table" then FT:Toast("That profile is unavailable."); return false end
    saved=copy(saved) -- detached before any settings callbacks run
    local qol=FT.modules.QualityOfLife
    if qol and qol.moving then qol:SetMoving(false) end

    for _,key in ipairs(keys) do FT.db[key]=copy(saved[key]) end
    for _,entry in ipairs(type(FT.db.customMacros)=="table" and FT.db.customMacros or {}) do
        if type(entry)=="table" and type(entry.name)=="string" and type(entry.savedBody)=="string" then
            FT:MacroRecord(entry).body=entry.savedBody
        end
    end
    FT.minimapDragAngle=nil
    self.selected=name
    self:Remember(name)
    for _,module in ipairs({"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll","BuffReminder","FlightTimer","Leveling"}) do
        local object=FT.modules[module]; if object then object:Apply() end
    end
    FT:UpdateMinimap()
    local macros=FT.modules.MacroForge
    if macros then macros.scope=FT.db.macroScope=="account" and "account" or "character" end
    local page
    if stayPage then
        for moduleName,module in pairs(FT.modules) do
            if module.frame and module.frame:IsShown() then page=moduleName;break end
        end
    end
    self:Checkpoint()
    self:RefreshIndicators()
    if silent then return true end
    if page then FT:OpenModule(page) else FT:OpenHome() end
    if self.panel then self.panel:Hide() end -- the switch is done; save a click
    FT:Toast("Profile loaded: "..name); return true
end
function Profiles:Delete(name)
    self:Archive(name)
    self:Store()[name]=nil
    FT.db.profileVault[name]=nil
    if self.selected==name then self.selected=nil end
    if self.active==name then self:Remember(nil) end
    if FT.db.newCharacterProfile==name then FT.db.newCharacterProfile=nil end
    if FT.db.lastProfile==name then FT.db.lastProfile=nil end
    for guid,profile in pairs(FT.db.profileCharacters or {}) do if profile==name then FT.db.profileCharacters[guid]=false end end
    self:Refresh(); FT:Toast("Profile deleted")
end
function Profiles:Refresh()
    self:RefreshIndicators()
    if not self.choice then return end
    self.choice.value=self.selected
    local hasProfiles=false
    for name,profile in pairs(self:Store()) do
        if type(name)=="string" and type(profile)=="table" then hasProfiles=true;break end
    end
    self.choice.label:SetText(not hasProfiles and "No profiles yet" or (self.active and ("Active: "..self.active) or "Choose a profile"))
    self.choice:SetEnabled(hasProfiles)
    self.choice:SetAlpha(hasProfiles and 1 or .7)
    self.emptyHint:SetShown(not hasProfiles)
    local exists=self.selected and self:Store()[self.selected]~=nil
    for _,button in ipairs({self.load,self.save,self.delete}) do button:SetEnabled(not not exists); button:SetAlpha(exists and 1 or .4) end
    if self.newCharacter then
        local chosen=FT.db.newCharacterProfile
        if type(chosen)~="string" or type(self:Store()[chosen])~="table" then chosen=nil end
        self.newCharacter.value=chosen or "\001last"
        local last=self:NewCharacterProfile()
        self.newCharacter.label:SetText(chosen and ("New characters: "..chosen) or ("New characters: last used"..(last and (" ("..last..")") or "")))
        self.newCharacter:SetEnabled(hasProfiles); self.newCharacter:SetAlpha(hasProfiles and 1 or .4)
    end
end
function Profiles:Attach(home)
    if not self.choice then
        local panel=CreateFrame("Frame",nil,home); panel:SetSize(392,280); panel:EnableMouse(true); panel:SetPoint("TOPRIGHT",home,"TOPRIGHT",-16,-50); FT:Panel(panel)
        self.panel=panel; panel:SetFrameLevel(home:GetFrameLevel()+20); panel:Hide()
        local toggle=FT:QuietButton(home,"Profiles",105,28,"profiles")
        toggle:SetPoint("RIGHT",home.closeButton,"LEFT",-6,0)
        toggle:SetScript("OnClick",function() panel:SetShown(not panel:IsShown()) end)
        FT:Tooltip(toggle,"Profiles","Create, load, save or delete your local profiles.")
        home:HookScript("OnHide",function() panel:Hide() end)
        local label=FT:Label(panel,"Profiles",14,true); label:SetPoint("TOPLEFT",10,-8)
        local info=FT:Info(panel,"Profiles","Profiles save your setup for reuse on other characters. Choose one to load it, or type a name and select Create. Use Export to keep a backup copy.")
        info:SetPoint("TOPRIGHT",-6,-4)
        self.choice=FT:Dropdown(panel,372,function()
            local list={}; for name,value in pairs(self:Store()) do if type(name)=="string" and type(value)=="table" then list[#list+1]={value=name,label=name,icon="Interface\\Icons\\INV_Misc_Book_09"} end end
            table.sort(list,function(a,b) return a.label<b.label end); return list
        end,function(name) self:Load(name) end,"profiles")
        self.choice:SetPoint("TOPLEFT",10,-38)
        self.name=CreateFrame("EditBox",nil,panel); self.name:SetSize(245,28); self.name:SetPoint("TOPLEFT",10,-72)
        self.name:SetFont(FT.bodyFont,14,""); self.name:SetAutoFocus(false); self.name:SetTextInsets(8,8,0,0); FT:Panel(self.name)
        FT:Tooltip(self.name,"New profile name","Type a name, then click Create to save the current settings.")
        local create=FT:QuietButton(panel,"Create",122,28,"add"); create:SetPoint("LEFT",self.name,"RIGHT",10,0)
        create:SetScript("OnClick",function() if self:Create(self.name:GetText()) then self.name:SetText(""); self.name:ClearFocus() end end)
        FT:Tooltip(create,"Create profile","Start a new profile with default settings (everything off) and switch to it. Your custom macros and fonts stay available. To store your current look instead, use Save on an existing profile.")
        self.load=FT:QuietButton(panel,"Load",116,28,"profiles"); self.load:SetPoint("TOPLEFT",10,-106)
        self.load:SetScript("OnClick",function() self:Load(self.selected) end)
        self.save=FT:QuietButton(panel,"Save",116,28,"profiles"); self.save:SetPoint("LEFT",self.load,"RIGHT",12,0)
        self.delete=FT:QuietButton(panel,"Delete",116,28,"delete"); self.delete:SetPoint("LEFT",self.save,"RIGHT",12,0)
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE={text="Replace this saved profile with your current settings?",button1="Save",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingSave then self:Save(self.pendingSave,true); self.pendingSave=nil end end}
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE={text="Delete this saved profile? Current settings will remain in use.",button1="Delete",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingDelete then self:Delete(self.pendingDelete); self.pendingDelete=nil end end}
        self.save:SetScript("OnClick",function()
            self.pendingSave=self.active or self.selected
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE.text='Save current settings to profile "'..(self.pendingSave or '')..'"?'
            FT:ShowPopup("FOREVERTOOLS_PROFILE_SAVE")
        end)
        self.delete:SetScript("OnClick",function() self.pendingDelete=self.selected; FT:ShowPopup("FOREVERTOOLS_PROFILE_DELETE") end)
        local export=FT:QuietButton(panel,"Export",180,28,"profiles"); export:SetPoint("TOPLEFT",10,-144)
        export:SetScript("OnClick",function() self:Transfer(false) end)
        local import=FT:QuietButton(panel,"Import",180,28,"profiles"); import:SetPoint("LEFT",export,"RIGHT",12,0)
        import:SetScript("OnClick",function() self:Transfer(true) end)
        self.newCharacter=FT:Dropdown(panel,372,function()
            local list={{value="\001last",label="New characters: last used profile",icon="Interface\\Icons\\INV_Misc_Book_09"}}
            local names={}; for name,value in pairs(self:Store()) do if type(name)=="string" and type(value)=="table" then names[#names+1]=name end end
            table.sort(names)
            for _,name in ipairs(names) do list[#list+1]={value=name,label="New characters: "..name,icon="Interface\\Icons\\INV_Misc_Book_09"} end
            return list
        end,function(value) FT.db.newCharacterProfile=value~="\001last" and value or nil; self:Refresh() end,"character")
        self.newCharacter:SetPoint("TOPLEFT",10,-180)
        FT:Tooltip(self.newCharacter,"Profile for new characters","New characters load this profile automatically, with no setup. \"Last used\" follows whichever profile you loaded or saved most recently.")
        self.defaults=FT:QuietButton(panel,"Default settings",372,28,"reset"); self.defaults:SetPoint("TOPLEFT",10,-214)
        self.defaults:SetScript("OnClick",function() self:DefaultSettings() end)
        FT:Tooltip(self.defaults,"Default settings","Put everything ForeverTools changes back to Blizzard's defaults, as if the addon was just installed: skins, colors, fonts, chat, tooltips, counters, reminders and game options such as the Lua error display. The selected profile is reset too. Custom macros, other profiles and learned flight times are kept. Asks first, then reloads your interface.")
        self.emptyHint=FT:Label(panel,"Make your changes, then save a profile here.",12)
        self.emptyHint:SetPoint("TOPLEFT",10,-252)
        FT:Tooltip(self.load,"Load profile","Restore the selected saved settings.")
        FT:Tooltip(self.save,"Save profile","Update the selected profile with your current settings.")
        FT:Tooltip(self.delete,"Delete profile","Remove the selected snapshot. Your current settings stay active.")
    end
    self:Refresh()
end
FT:RegisterModule("Profiles",Profiles)
function Profiles:WelcomeCharacter()
    local guid=self:Character(); if not guid then return end
    FT.db.profileCharacters=FT.db.profileCharacters or {}
    local previous=FT.db.profileCharacters[guid]
    local draft=FT.db.profileDrafts and FT.db.profileDrafts[guid]
    if type(draft)=="table" or (previous and self:Store()[previous]) then
        -- Restore the character's working copy without replacing a named snapshot.
        local source=type(draft)=="table" and draft or self:Store()[previous]
        for _,key in ipairs(keys) do FT.db[key]=copy(source[key]) end
        local assigned=previous and self:Store()[previous] and previous or nil
        self.active,self.selected=assigned,assigned
        for _,name in ipairs({"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll","BuffReminder","FlightTimer","Leveling"}) do
            local module=FT.modules[name]; if module then module:Apply() end
        end
        FT:UpdateMinimap()
    elseif previous==nil then
        -- A new character: no wizard or popup. Quietly apply the profile chosen
        -- for new characters (or the last one used) and say so once.
        FT.db.profileCharacters[guid]=false
        local name=self:NewCharacterProfile()
        if name and not InCombatLockdown() and self:Load(name,false,true) then
            C_Timer.After(4,function() FT:Toast('Using profile "'..name..'". Change it in /ft → Profiles.',5) end)
        end
    end
end
-- The explicit choice, else the most recently used profile, if it still exists.
function Profiles:NewCharacterProfile()
    local store=self:Store()
    local chosen=FT.db.newCharacterProfile
    if type(chosen)=="string" and type(store[chosen])=="table" then return chosen end
    local last=FT.db.lastProfile
    if type(last)=="string" and type(store[last])=="table" then return last end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then C_Timer.After(0,function() Profiles:WelcomeCharacter(); Profiles:Checkpoint(); FT.profilesReady=true; if FT.modules.MinimapIcons then FT.modules.MinimapIcons:Apply() end end)
    elseif event=="PLAYER_LOGOUT" then
        if Profiles.resetting then return end
        FT.db.profileDrafts=FT.db.profileDrafts or {}
        local guid=Profiles:Character(); if guid then FT.db.profileDrafts[guid]=Profiles:Snapshot() end
    end
end)

-- Settings only: saved profiles, custom macros/fonts, learned flight routes,
-- rank knowledge and macro history are kept. A reload re-applies native UI.
local resettable={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","chat","system","customKeybinds","lootRoll","tooltip","buffReminder","flightTimer","leveling","vendor"}
-- Game options ForeverTools can change on the player's behalf, returned to the
-- client's own defaults so the game looks as if the addon was never installed.
local function restoreGameOptions()
    local get=(C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
    local set=(C_CVar and C_CVar.SetCVar) or SetCVar
    if not get or not set then return end
    for _,name in ipairs({"scriptErrors","minimapShowPlayerCoords"}) do
        local ok,value=pcall(get,name)
        if ok and type(value)=="string" then pcall(set,name,value) end
    end
end
-- Clears every setting (content such as custom macros and fonts, other
-- profiles, flight times and rank knowledge stay) and reloads, so every
-- Blizzard frame, font, binding and color is rebuilt untouched.
function Profiles:ApplyDefaults(profileName)
    for _,key in ipairs(resettable) do FT.db[key]=nil end
    restoreGameOptions()
    local guid=self:Character()
    if guid then
        if FT.db.profileDrafts then FT.db.profileDrafts[guid]=nil end
        FT.db.profileCharacters=FT.db.profileCharacters or {}
        FT.db.profileCharacters[guid]=profileName or false
    end
    if profileName and type(self:Store()[profileName])=="table" then
        local stored=self:Store()[profileName]
        for _,key in ipairs(resettable) do stored[key]=nil end
        if type(FT.db.profileVault)=="table" then FT.db.profileVault[profileName]=copy(stored) end
    end
    self.resetting=true
    ReloadUI()
end
function Profiles:ResetSettings()
    if InCombatLockdown() then FT:Toast("Reset settings outside combat."); return end
    FT:Confirm("Reset all ForeverTools settings to their defaults?\n\nSaved profiles, custom macros and learned flight times are kept. Your interface will reload.",function()
        self:ApplyDefaults(nil)
    end)
end
function Profiles:DefaultSettings()
    if InCombatLockdown() then FT:Toast("Reset settings outside combat."); return end
    local name=self.active and self:Store()[self.active] and self.active or nil
    local target=name and ('profile "'..name..'"') or "your current settings"
    FT:Confirm("Reset "..target.." to default settings?\n\nEverything ForeverTools changes goes back to Blizzard's defaults, as if the addon was just installed. Custom macros, other profiles and learned flight times are kept. Your interface will reload.",function()
        self:ApplyDefaults(name)
    end)
end
function Profiles:Archive(name)
    if type(self:Store()[name])~="table" then return end
    FT.db.profileBackups=FT.db.profileBackups or {}
    local history=FT.db.profileBackups[name] or {}; FT.db.profileBackups[name]=history
    history[#history+1]={time=time(),settings=copy(self:Store()[name])}
    if #history>10 then table.remove(history,1) end
end
-- Fill every module's defaults up front. Defaults are written lazily when a
-- module first reads its settings, which must never look like a user change.
function Profiles:Normalize()
    for _,name in ipairs({"LootRoll","System","Tooltip","QualityOfLife","FlightTimer","BuffReminder","Leveling","UnitColors","Chat","CustomKeybinds","IconStyles"}) do
        local module=FT.modules[name]
        if module and module.Settings then pcall(module.Settings,module) end
    end
    local skins=FT.modules.IconStyles
    if skins then
        pcall(skins.Area,skins,"actions"); pcall(skins.Area,skins,"buffs")
        for _,entry in ipairs(skins.extraOptions or {}) do pcall(skins.Area,skins,entry[1]) end
    end
    local fonts=FT.modules.FontManager
    if fonts then for _,id in ipairs(fonts.order or {"general"}) do pcall(fonts.Settings,fonts,id) end end
end
function Profiles:Checkpoint()
    self:Normalize()
    FT.db.profileSchema=2
    self.baseline=FT:EncodeProfile(self:Snapshot())
    FT.db.profileDrafts=FT.db.profileDrafts or {}
    local guid=self:Character(); if guid then FT.db.profileDrafts[guid]=self:Snapshot() end
end
function Profiles:CharacterName()
    local name,realm
    if UnitFullName then name,realm=UnitFullName("player") elseif UnitName then name=UnitName("player") end
    realm=realm and realm~="" and realm or (GetRealmName and GetRealmName()) or "Realm"
    return (name or "Character").."-"..realm
end
function Profiles:OfferSave()
    if not FT.dbReady or InCombatLockdown() or self.prompting or not self.baseline then return end
    if FT.home and FT.home:IsShown() then return end
    if self.transfer and self.transfer:IsShown() then return end
    for _,module in pairs(FT.modules) do if module.frame and module.frame:IsShown() then return end end
    self:Normalize()
    if FT:EncodeProfile(self:Snapshot())==self.baseline then return end
    self.prompting=true
    -- Save into the profile in use; without one, offer a profile named after the character.
    local name=(self.active and self:Store()[self.active]) and self.active or self:CharacterName()
    if not self.saveDialog then
        local dialog=CreateFrame("Frame","ForeverToolsSaveChanges",UIParent)
        self.saveDialog=dialog;dialog:SetSize(440,172);dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG");dialog:EnableMouse(true);FT:Panel(dialog)
        local title=FT:Label(dialog,"Save changes?",18,true);title:SetPoint("TOPLEFT",22,-22)
        local message=FT:Label(dialog,"",14);message:SetPoint("TOPLEFT",22,-62);message:SetWidth(396);dialog.message=message
        local yes=FT:AccentButton(dialog,"Save",190,34,"confirm");yes:SetPoint("BOTTOMLEFT",22,20)
        yes:SetScript("OnClick",function() self:DismissSave(true) end)
        local later=FT:QuietButton(dialog,"Not now",190,34,"reset");later:SetPoint("BOTTOMRIGHT",-22,20)
        later:SetScript("OnClick",function() self:DismissSave(false) end)
        dialog:Hide()
    end
    self.pendingCharacterSave=name
    self.saveDialog.message:SetText('Save this setup locally as "'..name..'"?'..(self:Store()[name] and " This replaces its saved snapshot." or ""))
    self.saveDialog:Show()
end
function Profiles:DismissSave(save,keepDraft)
    if not self.prompting then return end
    local name=self.pendingCharacterSave
    self.prompting=nil;self.pendingCharacterSave=nil
    if self.saveDialog then self.saveDialog:Hide() end
    if save and name then self:Save(name,true) elseif not keepDraft then self:Checkpoint() end
end
local savePromptEvents=CreateFrame("Frame")
savePromptEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
savePromptEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
savePromptEvents:SetScript("OnEvent",function()
    if Profiles.prompting then Profiles:DismissSave(false,true) end
end)
function Profiles:Transfer(importing,onImported)
    if not self.transfer then
        local frame=FT:Window("ForeverToolsProfileTransfer","Profile transfer",600,390); self.transfer=frame
        frame.noSavePrompt=true
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        if frame.homeButton then frame.homeButton:Hide() end
        local info=FT:Label(frame,"",13); info:SetPoint("TOPLEFT",24,-66); info:SetSize(550,45); frame.info=info
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-150); scroll:SetSize(528,160); FT:Panel(scroll)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(520,160); box:SetAutoFocus(false); scroll:SetScrollChild(box); frame.box=box
        local pasteHint=FT:Label(box,"Paste string here",13);pasteHint:SetPoint("TOPLEFT",box,10,-10);frame.pasteHint=pasteHint
        box:SetScript("OnTextChanged",function() local n=#box:GetText(); box:SetHeight(math.max(160,math.ceil(n/65)*16));pasteHint:SetShown(n==0) end)
        local name=CreateFrame("EditBox",nil,frame,"InputBoxTemplate"); name:SetSize(540,28); name:SetPoint("TOPLEFT",30,-114); name:SetFont(FT.bodyFont,14,""); name:SetAutoFocus(false); frame.name=name
        local nameHint=FT:Label(name,"Add profile name here",13);nameHint:SetPoint("LEFT",8,0);frame.nameHint=nameHint
        name:SetScript("OnTextChanged",function() nameHint:SetShown(name:GetText()=="") end)
        FT:Tooltip(name,"Imported profile name","A new name is required. Existing profiles will never be overwritten by import.")
        local button=FT:QuietButton(frame,"Import profile",220,32,"profiles"); button:SetPoint("BOTTOMLEFT",24,25); frame.import=button
        button:SetScript("OnClick",function()
            local data,err=FT:DecodeProfile(box:GetText())
            if not data then FT:Toast(err); return end
            local profileName=name:GetText():match("^%s*(.-)%s*$")
            if profileName=="" or #profileName>120 or self:Store()[profileName] then FT:Toast("Choose a new profile name (1–120 characters)."); return end
            local clean,reason=self:ValidateImport(data.settings)
            if not clean then FT:Toast(reason); return end
            self:Store()[profileName]=clean; FT.db.profileVault[profileName]=copy(clean); self.selected=profileName; self:Refresh(); frame:Hide()
            local callback=self.onImported; self.onImported=nil
            if callback then callback(profileName) else FT:Toast("Profile imported. Select it to load.") end
        end)
    end
    local frame=self.transfer
    self.onImported=importing and onImported or nil
    frame.import:SetShown(importing); frame.name:SetShown(importing);frame.nameHint:SetShown(importing)
    frame.info:SetText(importing and "Paste a ForeverTools export string, enter a new profile name, then import. Import does not change your current setup." or "Export string selected. Press Ctrl+C to copy it, then paste it somewhere safe.")
    frame.box:SetText(importing and "" or FT:EncodeProfile({format=1,addonVersion=FT.version,settings=self:Snapshot()}))
    frame.name:SetText(""); FT:PlaceBeside(frame); frame:Show()
    if frame.box.SetFocus then frame.box:SetFocus() end
    if not importing and frame.box.HighlightText then frame.box:HighlightText() end
end
-- Import only supported preference keys. Reject mismatched types before any
-- consumer sees data; never merge executable data or addon-owned frame state.
function Profiles:ValidateImport(data)
    local result={}; local scalar={welcome="boolean",minimapEnabled="boolean",minimapAngle="number",minimapCollectorAngle="number",macroScope="string"}
    for _,key in ipairs(keys) do
        local v=data[key]
        if v~=nil then
            if type(v)~=(scalar[key] or "table") then return nil,"Invalid setting: "..key end
            result[key]=copy(v)
        end
    end
    local function check(t,types)
        for k,v in pairs(t or {}) do if types[k] and type(v)~=types[k] then return false end end; return true
    end
    if not check(result.fps,{enabled="boolean",fontSize="number",x="number",y="number",screenWidth="number",screenHeight="number"}) then return nil,"Invalid FPS settings." end
    if not check(result.flightTimer,{enabled="boolean",font="string",size="number",outline="string",color="table",x="number",y="number"}) then return nil,"Invalid flight timer settings." end
    if not check(result.lootRoll,{x="number",y="number",custom="boolean"}) then return nil,"Invalid loot-roll position." end
    if not check(result.leveling,{enabled="boolean",progress="boolean",rested="boolean",perHour="boolean",timeToLevel="boolean",kills="boolean",tooltip="boolean",fontSize="number",x="number",y="number",screenWidth="number",screenHeight="number",layout="string",order="table"}) then return nil,"Invalid leveling settings." end
    for _,key in ipairs(result.leveling and type(result.leveling.order)=="table" and result.leveling.order or {}) do
        if type(key)~="string" then return nil,"Invalid leveling order." end
    end
    for _,pref in pairs(result.fonts or {}) do
        if type(pref)~="table" or not check(pref,{enabled="boolean",font="string",size="number",outline="string",greyCooldowns="boolean",numberColor="table",path="string",pathFor="string"}) then return nil,"Invalid font settings." end
    end
    for _,pref in pairs(result.fonts or {}) do
        if pref.numberColor then for i=1,3 do local v=pref.numberColor[i]; if type(v)~="number" or v<0 or v>1 then return nil,"Invalid font color." end end end
    end
    for _,pref in pairs(result.customKeybinds or {}) do
        if type(pref)~="table" or not check(pref,{enabled="boolean",up="table",down="table"}) then return nil,"Invalid bindings." end
        for _,dir in ipairs({"up","down"}) do if not check(pref[dir],{spellID="number",friendly="string",hostile="string"}) then return nil,"Invalid spell." end end
    end
    for _,v in pairs(result.chat or {}) do if v~="show" and v~="hide" and v~="hover" then return nil,"Invalid chat mode." end end
    for _,key in ipairs({"unitColors","system"}) do for _,v in pairs(result[key] or {}) do if type(v)~="boolean" then return nil,"Invalid toggle." end end end
    if not check(result.tooltip,{guildFactionColor="boolean",guildFactionIcon="boolean",target="boolean",guild="boolean",healthBar="boolean",position="string",order="string",offsetX="number",offsetY="number",x="number",y="number",screenWidth="number",screenHeight="number",name="number",details="number",targetSize="number"}) then return nil,"Invalid tooltip settings." end
    if not check(result.buffReminder,{enabled="boolean",selected="table",mainEnchant="string",offEnchant="string",rankMarker="boolean",ignoredRanks="table"}) then return nil,"Invalid buff reminders." end
    for name,on in pairs(result.buffReminder and type(result.buffReminder.ignoredRanks)=="table" and result.buffReminder.ignoredRanks or {}) do
        if type(name)~="string" or on~=true then return nil,"Invalid rank exception." end
    end
    for name,on in pairs(result.buffReminder and result.buffReminder.selected or {}) do
        if type(name)~="string" or type(on)~="boolean" then return nil,"Invalid buff choice." end
    end
    if result.tooltip then
        local p=result.tooltip.position
        if p and p~="Default" and p~="Top left" and p~="Top right" and p~="Bottom left" and p~="Bottom right" then return nil,"Invalid tooltip position." end
        local order=result.tooltip.order
        if order and order~="NLT" and order~="NTL" and order~="LNT" and order~="LTN" and order~="TNL" and order~="TLN" then return nil,"Invalid tooltip row order." end
    end
    if result.iconStyles then
        local function skin(pref)
            if type(pref)~="table" or not check(pref,{preset="string",opacity="number",shadow="boolean",thickness="number",borderOpacity="number",slotOpacity="number",rares="boolean",elites="boolean",color="table",borderColor="table"}) then return false end
            for _,field in ipairs({"color","borderColor"}) do
                if pref[field] then for i=1,3 do if type(pref[field][i])~="number" or pref[field][i]<0 or pref[field][i]>1 then return false end end end
            end
            return true
        end
        local root=result.iconStyles
        if not skin(root) or not check(root,{actions="boolean",buffs="boolean",stances="boolean",areas="table",minimap="boolean",micro="boolean",bags="boolean",player="boolean",target="boolean",tot="boolean",focus="boolean",focustarget="boolean",xp="boolean"}) then return nil,"Invalid skin settings." end
        for key,pref in pairs(root.areas or {}) do if type(key)~="string" or not skin(pref) then return nil,"Invalid skin area." end end
    end
    for _,file in pairs(result.customFonts or {}) do if type(file)~="string" or #file>150 or file:find("[/\\]") then return nil,"Invalid font filename." end end
    if result.macroScope and result.macroScope~="account" and result.macroScope~="character" then return nil,"Invalid macro destination." end
    return result
end
