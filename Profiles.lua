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
        if value=="\001manage" then FT:OpenModule("Profiles");return end
        if value==self.active then return end
        local function switch() self:Load(value,true) end
        if self:HasChanges() then
            FT:Confirm("Switch to profile \""..value.."\"? Unsaved changes to the current setup will be replaced.",switch)
        else switch() end
    end
    FT:ShowChoices(owner)
end
-- Only preferences are copied. Macro history and installed WoW macros belong to
-- the character and are never rewritten by loading an appearance profile.
local keys={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","macroScope","macroUnlearnedIcons","macroBulkMouseover","chat","system","customKeybinds","customFonts","lootRoll","tooltip","buffReminder","customMacros","flightTimer","leveling","dispelGlow","actionMacros","rareAlert","threat","fireAlert","smartKey"}
-- Every module that must redraw after settings change (load, login, reset).
local applyModules={"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll","BuffReminder","FlightTimer","Leveling","DispelGlow","QuestTracker","MinimapIcons","RareAlert","Threat","CooldownReminder","SmartKey"}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
-- Values the addon keeps up to date by itself (a font's resolved file path)
-- are not user changes, and positions re-clamped to the screen move by a
-- fraction of a pixel; neither should count as "unsaved changes".
local derived={path=true,pathFor=true}
local function same(a,b)
    if a==b then return true end
    if type(a)=="number" and type(b)=="number" then return math.abs(a-b)<0.5 end
    if type(a)~="table" or type(b)~="table" then return false end
    for k,v in pairs(a) do if not derived[k] and not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil and not derived[k] then return false end end
    return true
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
    -- Remember where this class's macros sit on the action bars.
    self:CaptureActionMacros()
    self:Store()[name]=self:Snapshot(); FT.db.profileVault[name]=copy(self:Store()[name]); self.selected=name
    self:Remember(name)
    self:Checkpoint(); self:Refresh(); if not quiet then FT:Toast("Profile saved: "..name) end; return true
end
-- Content the player made (custom macros, font files, macro destination) is
-- carried into a new profile; every setting starts from its default.
local content={customMacros=true,customFonts=true,macroScope=true,macroUnlearnedIcons=true,macroBulkMouseover=true}
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
    for _,module in ipairs(applyModules) do
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
    self:OfferActionMacros(name)
    if silent then return true end
    if page then FT:OpenModule(page) else FT:OpenHome() end
    FT:Toast("Profile loaded: "..name); return true
end
-- Macro placements on the action bars, saved per class inside a profile:
-- actionMacros[CLASS][slot] = {name=, icon=, body=}. Saving on a Druid
-- updates only the Druid layout; other classes' layouts stay in the profile.
local function macroText(body) return type(body)=="string" and body:gsub("\r\n","\n"):gsub("\n+$","") or "" end
local function playerClass() local _,class=UnitClass("player"); return type(class)=="string" and class or nil end
function Profiles:CaptureActionMacros()
    if InCombatLockdown() or type(GetActionInfo)~="function" or type(GetMacroInfo)~="function" then return end
    local class=playerClass(); if not class then return end
    local layout,count={},0
    for slot=1,180 do
        local ok,kind,id=pcall(GetActionInfo,slot)
        if ok and kind=="macro" and type(id)=="number" then
            local name,icon,body=GetMacroInfo(id)
            -- Check against the button's own label; fall back to a unique name match.
            local label=GetActionText and GetActionText(slot)
            if label and name~=label and GetMacroIndexByName then
                local other=GetMacroIndexByName(label)
                if other and other>0 then name,icon,body=GetMacroInfo(other) end
            end
            if type(name)=="string" and type(body)=="string" then
                layout[slot]={name=name,icon=(type(icon)=="number" or type(icon)=="string") and icon or 134400,body=body}
                count=count+1
            end
        end
    end
    if type(FT.db.actionMacros)~="table" then FT.db.actionMacros={} end
    FT.db.actionMacros[class]=count>0 and layout or nil
end
function Profiles:FindMacro(entry)
    local global,character=GetNumMacros()
    local accountMax=MAX_ACCOUNT_MACROS or 120
    local wanted=macroText(entry.body)
    local best
    for index=1,accountMax+(character or 0) do
        if index<=(global or 0) or index>accountMax then
            local name,_,body=GetMacroInfo(index)
            if name and macroText(body)==wanted then
                if name==entry.name then return index end
                best=best or index
            end
        end
    end
    return best
end
function Profiles:PlaceActionMacros(layout)
    if InCombatLockdown() then FT:Toast("Action bars can only change outside combat."); return end
    if type(PickupMacro)~="function" or type(PlaceAction)~="function" then return end
    local placed,missing=0,{}
    local slots={}; for slot in pairs(layout) do slots[#slots+1]=slot end
    table.sort(slots)
    for _,slot in ipairs(slots) do
        local entry=layout[slot]
        local index=self:FindMacro(entry)
        if not index then
            -- Not on this character yet: add it to Character macros.
            local ok,created=pcall(CreateMacro,entry.name,entry.icon or 134400,entry.body,true)
            if ok and type(created)=="number" and created>0 then index=self:FindMacro(entry) end
        end
        if index then
            local kind,id=GetActionInfo(slot)
            if not (kind=="macro" and id==index) then
                ClearCursor(); PickupMacro(index); PlaceAction(slot); ClearCursor()
            end
            placed=placed+1
        else missing[#missing+1]=(entry.name~="" and entry.name~=" ") and entry.name or ("slot "..slot) end
    end
    FT:Toast(placed.." macros placed on your action bars."..(#missing>0 and (" "..#missing.." did not fit in your Character macros.") or ""),4)
end
function Profiles:OfferActionMacros(name)
    local profile=self:Store()[name]; local class=playerClass()
    local layout=type(profile)=="table" and type(profile.actionMacros)=="table" and class and profile.actionMacros[class]
    if type(layout)~="table" or not next(layout) then return end
    local count=0; for _ in pairs(layout) do count=count+1 end
    local label=(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
    C_Timer.After(.3,function()
        FT:Confirm(string.format('Profile "%s" has %d %s macros saved on the action bars.\n\nPut them in the same slots now? Macros you are missing are added to your Character macros. Other slots are not changed.',name,count,label),function()
            self:PlaceActionMacros(layout)
        end)
    end)
end
function Profiles:Rename(old,new)
    new=type(new)=="string" and new:match("^%s*(.-)%s*$") or ""
    local store=self:Store()
    if type(old)~="string" or type(store[old])~="table" then FT:Toast("Choose a profile to rename first."); return false end
    if new=="" or #new>120 then FT:Toast("Type the new name in the box (1–120 characters)."); return false end
    if new==old then return false end
    if store[new] then FT:Toast("A profile with that name already exists."); return false end
    store[new]=store[old]; store[old]=nil
    FT.db.profileVault=FT.db.profileVault or {}
    FT.db.profileVault[new]=copy(store[new]); FT.db.profileVault[old]=nil
    if FT.db.profileBackups and FT.db.profileBackups[old] then FT.db.profileBackups[new]=FT.db.profileBackups[old]; FT.db.profileBackups[old]=nil end
    -- Keep every reference pointing at the renamed profile.
    if FT.db.newCharacterProfile==old then FT.db.newCharacterProfile=new end
    if FT.db.lastProfile==old then FT.db.lastProfile=new end
    for guid,profile in pairs(FT.db.profileCharacters or {}) do if profile==old then FT.db.profileCharacters[guid]=new end end
    if self.active==old then self.active=new end
    if self.selected==old then self.selected=new end
    self:Refresh()
    FT:Toast('Profile renamed to "'..new..'".',3)
    return true
end
function Profiles:Delete(name)
    self:Archive(name)
    -- Other characters using this profile go back to default settings the
    -- next time they log in. This character keeps its current settings.
    local me=self:Character()
    FT.db.profileResets=FT.db.profileResets or {}
    for guid,profile in pairs(FT.db.profileCharacters or {}) do
        if profile==name and guid~=me then
            FT.db.profileResets[guid]=true
            if FT.db.profileDrafts then FT.db.profileDrafts[guid]=nil end
        end
    end
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
    if self.panel then self.panel:SetHeight((hasProfiles and 326 or 348)+self.panelTop+10) end
    local exists=self.selected and self:Store()[self.selected]~=nil
    for _,button in ipairs({self.load,self.save,self.delete,self.rename}) do button:SetEnabled(not not exists); button:SetAlpha(exists and 1 or .4) end
    if self.newCharacter then
        local chosen=FT.db.newCharacterProfile
        if type(chosen)~="string" or type(self:Store()[chosen])~="table" then chosen=nil end
        self.newCharacter.value=chosen or "\001last"
        local last=self:NewCharacterProfile()
        self.newCharacter.label:SetText(chosen and ("New characters: "..chosen) or ("New characters: last used"..(last and (" ("..last..")") or "")))
        self.newCharacter:SetEnabled(hasProfiles); self.newCharacter:SetAlpha(hasProfiles and 1 or .4)
    end
end
-- Profiles is its own window like every other page: movable, with Back (to
-- the main menu) and the close X. The controls sit in a content frame.
function Profiles:TogglePanel() FT:OpenModule("Profiles") end
function Profiles:Open()
    self:Attach(FT.home)
    self:Refresh()
    self.panel:Show()
end
function Profiles:Attach(home)
    if not self.choice then
        local window=FT:Window("ForeverToolsProfiles","Profiles",424,390)
        window.noSavePrompt=true
        self.panel=window; self.frame=window; self.panelTop=16
        local panel=CreateFrame("Frame",nil,window); panel:SetPoint("TOPLEFT",16,-self.panelTop); panel:SetSize(392,326)
        FT:PageInfo(window,"Profiles","A profile is a saved copy of your ForeverTools settings. Load it on any character, or export it as text to keep a backup or move it to another computer.")
        self.choice=FT:Dropdown(panel,372,function()
            local list={}; for name,value in pairs(self:Store()) do if type(name)=="string" and type(value)=="table" then list[#list+1]={value=name,label=name,icon="Interface\\Icons\\INV_Misc_Book_09"} end end
            table.sort(list,function(a,b) return a.label<b.label end); return list
        end,function(name) self:Load(name) end,"profiles")
        self.choice:SetPoint("TOPLEFT",10,-46); self.choice:SetHeight(32)
        self.name=CreateFrame("EditBox",nil,panel); self.name:SetSize(266,30); self.name:SetPoint("TOPLEFT",10,-90)
        self.name:SetFont(FT.bodyFont,14,""); self.name:SetAutoFocus(false); self.name:SetTextInsets(8,8,0,0); FT:Panel(self.name)
        FT:Tooltip(self.name,"New profile name","Type a name, then click Create to make a new profile.")
        local create=FT:QuietButton(panel,"Create",98,30,"INV_Misc_Note_02"); create:SetPoint("LEFT",self.name,"RIGHT",8,0)
        create:SetScript("OnClick",function() if self:Create(self.name:GetText()) then self.name:SetText(""); self.name:ClearFocus() end end)
        FT:Tooltip(create,"Create profile","Make a new profile with default settings (everything off) and switch to it. Your custom macros and fonts stay. To keep your current look, use Save instead.")
        -- Actions on the profile chosen above: Load, Save, Rename, Delete.
        self.load=FT:QuietButton(panel,"Load",87,30,"INV_Misc_Book_11"); self.load:SetPoint("TOPLEFT",10,-130)
        self.load:SetScript("OnClick",function() self:Load(self.selected) end)
        self.save=FT:QuietButton(panel,"Save",87,30,"confirm"); self.save:SetPoint("LEFT",self.load,"RIGHT",8,0)
        self.rename=FT:QuietButton(panel,"Rename",87,30,"fonts"); self.rename:SetPoint("LEFT",self.save,"RIGHT",8,0)
        self.rename:SetScript("OnClick",function()
            local old=self.selected
            if not old or not self:Store()[old] then FT:Toast("Choose a profile first."); return end
            FT:AskText('Rename profile "'..old..'" to:',old,function(new)
                if new=="" or new==old then return end
                if #new>120 then FT:Toast("Use at most 120 characters."); return end
                if self:Store()[new] then FT:Toast("A profile with that name already exists."); return end
                self:Rename(old,new)
            end)
        end)
        FT:Tooltip(self.rename,"Rename profile",function() return self.selected and ('Give "'..self.selected..'" a new name. Its settings do not change.') or "Choose a profile above first." end)
        self.delete=FT:QuietButton(panel,"Delete",87,30,"delete"); self.delete:SetPoint("LEFT",self.rename,"RIGHT",8,0)
        for _,b in ipairs({self.load,self.save,self.rename,self.delete}) do b.label:SetFont(FT.bodyFont,13,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end end
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE={text="Replace this saved profile with your current settings?",button1="Save",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingSave then self:Save(self.pendingSave,true); self.pendingSave=nil end end}
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE={text="Delete this saved profile? Current settings will remain in use.",button1="Delete",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingDelete then self:Delete(self.pendingDelete); self.pendingDelete=nil end end}
        self.save:SetScript("OnClick",function()
            self.pendingSave=self.active or self.selected
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE.text='Save current settings to profile "'..(self.pendingSave or '')..'"?'
            FT:ShowPopup("FOREVERTOOLS_PROFILE_SAVE")
        end)
        self.delete:SetScript("OnClick",function()
            self.pendingDelete=self.selected
            if not self.pendingDelete then return end
            -- Name the profile so it is clear which one goes.
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE.text='Delete profile "'..self.pendingDelete..'"?'..(self.pendingDelete==self.active and "\n\nThis is the profile you are using. Your current settings stay as they are." or "\n\nYour current settings stay as they are.")
            FT:ShowPopup("FOREVERTOOLS_PROFILE_DELETE")
        end)
        local export=FT:QuietButton(panel,"Export",180,30,"INV_Misc_Note_01"); export:SetPoint("TOPLEFT",10,-182)
        export:SetScript("OnClick",function() self:Transfer(false) end)
        local import=FT:QuietButton(panel,"Import",180,30,"INV_Misc_Note_03"); import:SetPoint("LEFT",export,"RIGHT",12,0)
        import:SetScript("OnClick",function() self:Transfer(true) end)
        self.newCharacter=FT:Dropdown(panel,372,function()
            local list={{value="\001last",label="New characters: last used profile",icon="Interface\\Icons\\INV_Misc_Book_09"}}
            local names={}; for name,value in pairs(self:Store()) do if type(name)=="string" and type(value)=="table" then names[#names+1]=name end end
            table.sort(names)
            for _,name in ipairs(names) do list[#list+1]={value=name,label="New characters: "..name,icon="Interface\\Icons\\INV_Misc_Book_09"} end
            return list
        end,function(value) FT.db.newCharacterProfile=value~="\001last" and value or nil; self:Refresh() end,"character")
        self.newCharacter:SetPoint("TOPLEFT",10,-234); self.newCharacter:SetHeight(40)
        -- Long profile names wrap onto a second line instead of being cut off.
        self.newCharacter.label:SetWordWrap(true); if self.newCharacter.label.SetMaxLines then self.newCharacter.label:SetMaxLines(2) end
        FT:Tooltip(self.newCharacter,"Profile for new characters","New characters ask once which profile to use. This one is picked by default. \"Last used\" is the profile you loaded or saved most recently.")
        self.defaults=FT:QuietButton(panel,"Default settings",372,30,"reset"); self.defaults:SetPoint("TOPLEFT",10,-284)
        self.defaults:SetScript("OnClick",function() self:DefaultSettings() end)
        FT:Tooltip(self.defaults,"Default settings","Put everything ForeverTools changes back to Blizzard's defaults, as if the addon was just installed: skins, colors, fonts, chat, tooltips, counters, reminders and game options such as the Lua error display. The selected profile is reset too. Custom macros, other profiles and learned flight times are kept. Asks first, then reloads your interface.")
        self.emptyHint=FT:Label(panel,"Make your changes, then save a profile here.",12)
        self.emptyHint:SetPoint("TOPLEFT",10,-324)
        -- Thin dividers between the groups: pick/create, manage, transfer, new characters.
        for _,y in ipairs({-171,-223}) do
            local line=panel:CreateTexture(nil,"ARTWORK"); line:SetColorTexture(.30,.23,.46,.6)
            line:SetHeight(1); line:SetPoint("TOPLEFT",14,y); line:SetPoint("TOPRIGHT",-14,y)
        end
        FT:Tooltip(self.load,"Load profile","Switch to the selected profile.")
        FT:Tooltip(self.save,"Save profile","Save your current settings into the selected profile.")
        FT:Tooltip(self.delete,"Delete profile","Delete the selected profile. Your current settings do not change.")
    end
    self:Refresh()
end
FT:RegisterModule("Profiles",Profiles)
function Profiles:WelcomeCharacter()
    local guid=self:Character(); if not guid then return end
    FT.db.profileCharacters=FT.db.profileCharacters or {}
    local previous=FT.db.profileCharacters[guid]
    if FT.db.profileResets and FT.db.profileResets[guid] then
        -- The profile this character used was deleted on another character.
        FT.db.profileResets[guid]=nil
        self:DefaultsForCharacter()
        FT:Toast("Your profile was deleted on another character. Default settings are used.",5)
        return
    end
    local draft=FT.db.profileDrafts and FT.db.profileDrafts[guid]
    if type(draft)=="table" or (previous and self:Store()[previous]) then
        -- Restore the character's working copy without replacing a named snapshot.
        local source=type(draft)=="table" and draft or self:Store()[previous]
        for _,key in ipairs(keys) do FT.db[key]=copy(source[key]) end
        local assigned=previous and self:Store()[previous] and previous or nil
        self.active,self.selected=assigned,assigned
        for _,name in ipairs(applyModules) do
            local module=FT.modules[name]; if module then module:Apply() end
        end
        FT:UpdateMinimap()
    elseif previous==nil then
        -- A new character: ask once whether to use a saved profile or start a
        -- new one. Closing the question keeps Blizzard's defaults.
        FT.db.profileCharacters[guid]=false
        if self:NewCharacterProfile() or self:AnyProfile() then C_Timer.After(3,function() self:AskNewCharacter() end) end
    end
end
function Profiles:AnyProfile()
    for name,profile in pairs(self:Store()) do if type(name)=="string" and type(profile)=="table" then return name end end
end
function Profiles:ProfileList()
    local list={}
    for name,profile in pairs(self:Store()) do
        if type(name)=="string" and type(profile)=="table" then list[#list+1]={value=name,label=name,icon="Interface\\Icons\\INV_Misc_Book_09"} end
    end
    table.sort(list,function(a,b) return a.label<b.label end)
    return list
end
function Profiles:AskNewCharacter()
    if InCombatLockdown() then self.askAfterCombat=true; return end
    self.askAfterCombat=nil
    if not self.newCharacterFrame then
        local frame=FT:Window("ForeverToolsNewCharacter","New character",480,262); self.newCharacterFrame=frame
        frame.noSavePrompt=true
        frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame.homeButton:Hide()
        local text=FT:Label(frame,"",14); text:SetPoint("TOPLEFT",24,-60); text:SetWidth(432); frame.text=text
        local pick=FT:Dropdown(frame,432,function() return self:ProfileList() end,function(name) frame.choice=name; frame.pick.value=name; frame.pick.label:SetText(name) end,"profiles")
        pick:SetPoint("TOPLEFT",24,-104); pick:SetHeight(34); pick.menuWidth=300; frame.pick=pick
        FT:Tooltip(pick,"Profile","Choose one of your saved profiles for this character.")
        local note=FT:Label(frame,"Closing keeps Blizzard's default look. You can change this any time in /ft > Profiles.",12)
        note:SetPoint("TOPLEFT",24,-150); note:SetWidth(432); note:SetTextColor(.66,.57,.77)
        local new=FT:QuietButton(frame,"New profile",200,34,"add"); new:SetPoint("BOTTOMLEFT",24,22)
        new:SetScript("OnClick",function()
            local base=self:CharacterName(); local name,n=base,2
            while self:Store()[name] do name=base.." "..n; n=n+1 end
            frame:Hide()
            if self:Create(name) and FT.modules.Onboarding then FT.modules.Onboarding:ShowSetup(false) end
        end)
        FT:Tooltip(new,"New profile","Start a profile for this character with default settings, then pick a look in the short setup.")
        local use=FT:AccentButton(frame,"Use profile",200,34,"confirm"); use:SetPoint("BOTTOMRIGHT",-24,22)
        use:SetScript("OnClick",function()
            local name=frame.choice; if not name or not self:Store()[name] then return end
            frame:Hide()
            if self:Load(name,false,true) then FT:Toast('Using profile "'..name..'".',3) end
        end)
        FT:Tooltip(use,"Use profile","Load the selected profile on this character.")
    end
    local frame=self.newCharacterFrame
    local name=self:NewCharacterProfile() or self:AnyProfile()
    frame.choice=name; frame.pick.value=name; frame.pick.label:SetText(name or "")
    local who=UnitName and UnitName("player") or "this character"
    frame.text:SetText("Which settings should "..who.." use? Pick a saved profile, or start a new one.")
    frame:ClearAllPoints(); frame:SetPoint("CENTER"); frame:Show()
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
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_LOGOUT"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_ENABLED" then
        if Profiles.askAfterCombat then C_Timer.After(1,function() Profiles:AskNewCharacter() end) end
    elseif event=="PLAYER_LOGIN" then C_Timer.After(0,function() Profiles:TrimBackups(); Profiles:WelcomeCharacter(); Profiles:Checkpoint(); FT.profilesReady=true; if FT.modules.MinimapIcons then FT.modules.MinimapIcons:Apply() end end)
    elseif event=="PLAYER_LOGOUT" then
        if Profiles.resetting then return end
        Profiles:SaveDraft()
    end
end)

-- Settings only: saved profiles, custom macros/fonts, learned flight routes,
-- rank knowledge and macro history are kept. A reload re-applies native UI.
local resettable={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","chat","system","customKeybinds","lootRoll","tooltip","buffReminder","flightTimer","leveling","vendor","dispelGlow","rareAlert","threat","fireAlert","smartKey"}
function Profiles:DefaultsForCharacter()
    for _,key in ipairs(resettable) do FT.db[key]=nil end
    self.active,self.selected=nil,nil
    local guid=self:Character()
    if guid then FT.db.profileCharacters=FT.db.profileCharacters or {}; FT.db.profileCharacters[guid]=false end
    for _,name in ipairs(applyModules) do local module=FT.modules[name]; if module and module.Apply then pcall(module.Apply,module) end end
    FT:UpdateMinimap()
    self:Checkpoint()
end
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
-- Safety copies of a profile from before it was overwritten or deleted.
-- Three per profile is plenty; older saved data kept ten.
local backupLimit=3
function Profiles:TrimBackups()
    for _,history in pairs(type(FT.db.profileBackups)=="table" and FT.db.profileBackups or {}) do
        if type(history)=="table" then while #history>backupLimit do table.remove(history,1) end end
    end
end
function Profiles:Archive(name)
    if type(self:Store()[name])~="table" then return end
    FT.db.profileBackups=FT.db.profileBackups or {}
    local history=FT.db.profileBackups[name] or {}; FT.db.profileBackups[name]=history
    -- Nothing changed since the last backup: no need for another copy.
    local last=history[#history]
    if type(last)=="table" and same(last.settings,self:Store()[name]) then return end
    history[#history+1]={time=time(),settings=copy(self:Store()[name])}
    while #history>backupLimit do table.remove(history,1) end
end
-- Fill every module's defaults up front. Defaults are written lazily when a
-- module first reads its settings, which must never look like a user change.
function Profiles:Normalize()
    for _,name in ipairs({"LootRoll","System","Tooltip","QualityOfLife","FlightTimer","BuffReminder","Leveling","UnitColors","Chat","CustomKeybinds","IconStyles","DispelGlow"}) do
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
-- Compare the settings with the last saved or loaded state directly. (This
-- used to build a whole export string each time a window closed.)
function Profiles:HasChanges()
    local baseline=self.baseline
    if type(baseline)~="table" then return false end
    for _,key in ipairs(keys) do if not same(FT.db[key],baseline[key]) then return true end end
    return false
end
-- Each character keeps a working copy of its settings. When that copy is
-- identical to the profile the character uses, the profile is enough, so no
-- second copy is stored (smaller saved data, faster loading).
-- Profiles are shared: characters on the same profile follow it. A character
-- only keeps a copy of its own while it has unsaved changes.
function Profiles:SaveDraft()
    local guid=self:Character(); if not guid then return end
    FT.db.profileDrafts=FT.db.profileDrafts or {}
    local snapshot=self:Snapshot()
    local assigned=FT.db.profileCharacters and FT.db.profileCharacters[guid]
    local profile=type(assigned)=="string" and self:Store()[assigned]
    if type(profile)=="table" then
        local equal=true
        for _,key in ipairs(keys) do if not same(snapshot[key],profile[key]) then equal=false; break end end
        if equal then FT.db.profileDrafts[guid]=nil; return end
    end
    FT.db.profileDrafts[guid]=snapshot
end
function Profiles:Checkpoint()
    self:Normalize()
    FT.db.profileSchema=2
    local baseline={}
    for _,key in ipairs(keys) do baseline[key]=copy(FT.db[key]) end
    self.baseline=baseline
    self:SaveDraft()
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
    if not self:HasChanges() then return end
    self.prompting=true
    -- Save into the profile in use; without one, offer a profile named after the character.
    local name=(self.active and self:Store()[self.active]) and self.active or self:CharacterName()
    if not self.saveDialog then
        local dialog=CreateFrame("Frame","ForeverToolsSaveChanges",UIParent)
        self.saveDialog=dialog;dialog:SetSize(440,172);dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG");dialog:EnableMouse(true);FT:Panel(dialog)
        -- Same look as the other ForeverTools questions (the damage meter's).
        local skinned=FT:MeterSkin(dialog,32)
        local title=skinned and dialog:CreateFontString(nil,"OVERLAY","GameFontNormalMed1") or FT:Label(dialog,"Save changes?",18,true)
        title:SetText("Save changes?")
        if skinned then title:SetPoint("TOPLEFT",12,-9) else title:SetPoint("TOPLEFT",22,-22);title:SetTextColor(.82,.68,1);FT:TitleBand(dialog,50) end
        FT:FadeIn(dialog);FT:MakeDraggable(dialog)
        FT:AddClose(dialog,function() self:DismissSave(false) end,skinned and 2 or nil)
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
-- Key bindings travel only inside an export string, never inside saved
-- settings: WoW keeps bindings itself. Import applies them on request, out of
-- combat, through the game's own binding API into the current binding set.
function Profiles:CaptureBindings()
    if type(GetNumBindings)~="function" or type(GetBinding)~="function" then return nil end
    local map,count={},0
    for i=1,GetNumBindings() do
        local info={GetBinding(i)}
        local action=info[1]
        if type(action)=="string" and action~="" then
            for k=3,#info do
                local key=info[k]
                if type(key)=="string" and key~="" and not map[key] then map[key]=action; count=count+1 end
            end
        end
    end
    return count>0 and map or nil
end
function Profiles:ValidBindings(map)
    if type(map)~="table" then return nil end
    local count=0
    for key,action in pairs(map) do
        if type(key)~="string" or type(action)~="string" or #key>64 or #action>256 or key=="" or action=="" then return nil end
        count=count+1; if count>1500 then return nil end
    end
    return count>0 and map or nil
end
function Profiles:ApplyBindings(map,noSave,quiet)
    if InCombatLockdown() then FT:Toast("Keybinds can only change outside combat."); return false end
    if type(SetBinding)~="function" or type(SaveBindings)~="function" then FT:Toast("Keybinds cannot be changed in this game version."); return false end
    -- Clear the current keys first so the result matches the exported layout
    -- exactly, then bind every imported key. Unknown actions are skipped.
    local current=self:CaptureBindings() or {}
    for key in pairs(current) do SetBinding(key) end
    local applied,skipped=0,0
    for key,action in pairs(map) do
        local ok,result=pcall(SetBinding,key,action)
        if ok and result~=false then applied=applied+1 else skipped=skipped+1 end
    end
    if applied==0 then
        -- Nothing matched this client: put the previous bindings back untouched.
        for key,action in pairs(current) do SetBinding(key,action) end
        if not quiet then FT:Toast("None of these keybinds work in this game version. Your keybinds are unchanged.",4) end
        return false
    end
    if not noSave then
        local set=GetCurrentBindingSet and GetCurrentBindingSet() or 1
        SaveBindings(set)
    end
    if not quiet then FT:Toast(applied.." keybinds applied"..(skipped>0 and (" ("..skipped.." not available here)") or "")..".",4) end
    return true
end
function Profiles:Transfer(importing,onImported)
    if not self.transfer then
        local frame=FT:Window("ForeverToolsProfileTransfer","Profile transfer",600,390); self.transfer=frame
        frame.noSavePrompt=true
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        if frame.homeButton then frame.homeButton:Hide() end
        -- Plain answers to "will my string still work later?"
        local about=FT:Info(frame,"Will my string keep working?","Yes. Export strings keep working after ForeverTools and game updates.\n\n• Settings added after you exported start at their defaults.\n• Keybinds carry over. A key for an action that no longer exists is skipped.\n• Mouse-wheel spells need that spell learned on the character.\n• Custom fonts need the same font file on the other computer.\n\nTip: export again after big changes, so your backup matches your setup.")
        about:SetPoint("RIGHT",frame.closeButton,"LEFT",-8,0)
        local info=FT:Label(frame,"",13); info:SetPoint("TOPLEFT",24,-66); info:SetSize(550,45); frame.info=info
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-150); scroll:SetSize(528,160); FT:Panel(scroll)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(520,160); box:SetAutoFocus(false); scroll:SetScrollChild(box); frame.box=box
        local pasteHint=FT:Label(box,"Paste string here",13);pasteHint:SetPoint("TOPLEFT",box,10,-10);frame.pasteHint=pasteHint
        box:SetScript("OnTextChanged",function(_,user)
            local n=#box:GetText(); box:SetHeight(math.max(160,math.ceil(n/65)*16));pasteHint:SetShown(n==0)
            if frame.importing and user then
                local data=n>0 and FT:DecodeProfile(box:GetText())
                frame.hasBindings=type(data)=="table" and data.bindings~=nil
                frame.applyBindings=frame.hasBindings
                self:RefreshTransfer()
            end
        end)
        local name=CreateFrame("EditBox",nil,frame,"InputBoxTemplate"); name:SetSize(540,28); name:SetPoint("TOPLEFT",30,-114); name:SetFont(FT.bodyFont,14,""); name:SetAutoFocus(false); frame.name=name
        local nameHint=FT:Label(name,"Add profile name here",13);nameHint:SetPoint("LEFT",8,0);frame.nameHint=nameHint
        name:SetScript("OnTextChanged",function() nameHint:SetShown(name:GetText()=="") end)
        FT:Tooltip(name,"Imported profile name","Give the imported profile a new name. Importing never replaces an existing profile.")
        local button=FT:QuietButton(frame,"Import profile",220,32,"profiles"); button:SetPoint("BOTTOMLEFT",24,25); frame.import=button
        button:SetScript("OnClick",function()
            local data,err=FT:DecodeProfile(box:GetText())
            if not data then FT:Toast(err); return end
            local profileName=name:GetText():match("^%s*(.-)%s*$")
            if profileName=="" or #profileName>120 or self:Store()[profileName] then FT:Toast("Choose a new profile name (1–120 characters)."); return end
            local clean,reason=self:ValidateImport(data.settings)
            if not clean then FT:Toast(reason); return end
            local bindings=data.bindings~=nil and self:ValidBindings(data.bindings)
            if data.bindings~=nil and not bindings then FT:Toast("Invalid keybinds in this profile."); return end
            if bindings and frame.applyBindings and InCombatLockdown() then FT:Toast("Import keybinds outside combat."); return end
            self:Store()[profileName]=clean; FT.db.profileVault[profileName]=copy(clean); self.selected=profileName; self:Refresh(); frame:Hide()
            if bindings and frame.applyBindings then self:ApplyBindings(bindings) end
            self:ImportSkinTemplates(data.skinTemplates)
            local callback=self.onImported; self.onImported=nil
            if callback then callback(profileName) elseif not (bindings and frame.applyBindings) then FT:Toast("Profile imported. Select it to load.") end
        end)
        -- One toggle, two meanings: include keybinds in an export, or apply the
        -- keybinds found in a pasted string. Hidden when there is nothing to apply.
        local keys=FT:QuietButton(frame,"",250,32,"keybind"); keys:SetPoint("BOTTOMRIGHT",-24,25); frame.keys=keys
        keys:SetScript("OnClick",function()
            if frame.importing then frame.applyBindings=not frame.applyBindings
            else FT.db.exportBindings=not FT.db.exportBindings; self:FillExport() end
            self:RefreshTransfer()
        end)
        FT:Tooltip(keys,"Keybinds",function()
            return frame.importing and "Also use the keybinds saved in this string. This replaces all your current keybinds."
                or "Put all your current keybinds in the export string, so you can use them on another computer or account."
        end)
    end
    local frame=self.transfer
    self.onImported=importing and onImported or nil
    frame.importing=importing; frame.hasBindings=false; frame.applyBindings=false
    frame.titleText:SetText(importing and "Import profile" or "Export profile")
    frame.import:SetShown(importing); frame.name:SetShown(importing);frame.nameHint:SetShown(importing)
    frame.info:SetText(importing and "Paste an export string, give it a name, then click Import profile. Your settings only change when you load the profile (or apply its keybinds)." or "Press Ctrl+C to copy the string, then paste it somewhere safe. It keeps working after addon and game updates.")
    if importing then frame.box:SetText("") else self:FillExport() end
    frame.name:SetText(""); self:RefreshTransfer(); FT:PlaceBeside(frame); frame:Show()
    if frame.box.SetFocus then frame.box:SetFocus() end
end
-- Skin templates travel with an export. On import they are added; a name
-- already in use gets " (imported)". Each one is checked like a profile's skins.
function Profiles:ImportSkinTemplates(list)
    if type(list)~="table" then return end
    if type(FT.db.skinTemplates)~="table" then FT.db.skinTemplates={} end
    for name,template in pairs(list) do
        if type(name)=="string" and #name>0 and #name<=40 and type(template)=="table" then
            local clean=self:ValidateImport({iconStyles=template})
            if clean and type(clean.iconStyles)=="table" then
                local target=name
                if FT.db.skinTemplates[target] then target=(name:sub(1,29)).." (imported)" end
                if not FT.db.skinTemplates[target] then FT.db.skinTemplates[target]=clean.iconStyles end
            end
        end
    end
end
function Profiles:FillExport()
    local frame=self.transfer
    local data={format=1,addonVersion=FT.version,settings=self:Snapshot()}
    if FT.db.exportBindings then data.bindings=self:CaptureBindings() end
    if type(FT.db.skinTemplates)=="table" and next(FT.db.skinTemplates) then data.skinTemplates=copy(FT.db.skinTemplates) end
    frame.box:SetText(FT:EncodeProfile(data))
    if frame.box.HighlightText then frame.box:HighlightText() end
end
function Profiles:RefreshTransfer()
    local frame=self.transfer; if not frame then return end
    local keys=frame.keys
    if frame.importing then
        keys:SetShown(frame.hasBindings)
        keys.label:SetText("Apply keybinds: "..(frame.applyBindings and "On" or "Off")); FT:SetSelected(keys,frame.applyBindings)
    else
        keys:Show()
        keys.label:SetText("Include keybinds: "..(FT.db.exportBindings and "On" or "Off")); FT:SetSelected(keys,FT.db.exportBindings)
    end
end
-- Import only supported preference keys. Reject mismatched types before any
-- consumer sees data; never merge executable data or addon-owned frame state.
function Profiles:ValidateImport(data)
    local result={}; local scalar={welcome="boolean",minimapEnabled="boolean",minimapAngle="number",minimapCollectorAngle="number",macroScope="string",macroUnlearnedIcons="boolean",macroBulkMouseover="boolean"}
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
    if not check(result.fps,{enabled="boolean",fontSize="number",x="number",y="number",screenWidth="number",screenHeight="number",align="string",anchorX="number",anchorY="number",anchorWidth="number",anchorHeight="number"}) then return nil,"Invalid FPS settings." end
    if not check(result.flightTimer,{enabled="boolean",font="string",size="number",outline="string",color="table",x="number",y="number"}) then return nil,"Invalid flight timer settings." end
    if not check(result.lootRoll,{x="number",y="number",custom="boolean"}) then return nil,"Invalid loot-roll position." end
    if not check(result.leveling,{enabled="boolean",progress="boolean",rested="boolean",perHour="boolean",timeToLevel="boolean",kills="boolean",tooltip="boolean",fontSize="number",x="number",y="number",screenWidth="number",screenHeight="number",layout="string",order="table",background="boolean",backgroundColor="table",backgroundAlpha="number",align="string"}) then return nil,"Invalid leveling settings." end
    if result.leveling and result.leveling.backgroundColor then
        for i=1,3 do local v=result.leveling.backgroundColor[i]; if type(v)~="number" or v<0 or v>1 then return nil,"Invalid leveling background color." end end
    end
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
    if not check(result.dispelGlow,{enabled="boolean",player="boolean",target="boolean",focus="boolean",party="boolean",raid="boolean",strength="string",pulse="boolean"}) then return nil,"Invalid dispel glow settings." end
    if result.dispelGlow and result.dispelGlow.strength and not FT.modules.DispelGlow.strengths[result.dispelGlow.strength] then return nil,"Invalid glow strength." end
    for class,layout in pairs(result.actionMacros or {}) do
        if type(class)~="string" or type(layout)~="table" then return nil,"Invalid macro placements." end
        for slot,entry in pairs(layout) do
            if type(slot)~="number" or slot<1 or slot>180 or slot%1~=0 or type(entry)~="table" or type(entry.name)~="string" or #entry.name>16
                or type(entry.body)~="string" or #entry.body>255 or (entry.icon~=nil and type(entry.icon)~="number" and type(entry.icon)~="string") then
                return nil,"Invalid macro placement."
            end
        end
    end
    for _,v in pairs(result.chat or {}) do if v~="show" and v~="hide" and v~="hover" then return nil,"Invalid chat mode." end end
    for _,key in ipairs({"unitColors","system"}) do for _,v in pairs(result[key] or {}) do if type(v)~="boolean" then return nil,"Invalid toggle." end end end
    if not check(result.tooltip,{guildFactionColor="boolean",guildFactionIcon="boolean",target="boolean",guild="boolean",healthBar="boolean",position="string",order="string",offsetX="number",offsetY="number",x="number",y="number",screenWidth="number",screenHeight="number",name="number",details="number",targetSize="number",layout="table",factionIcon="string",guildIconPosition="string"}) then return nil,"Invalid tooltip settings." end
    if result.tooltip and result.tooltip.factionIcon and not FT.modules.Tooltip.iconPlaces[result.tooltip.factionIcon] then return nil,"Invalid faction icon place." end
    for _,entry in ipairs(result.tooltip and result.tooltip.layout or {}) do
        if type(entry)~="table" or type(entry.key)~="string" or not FT.modules.Tooltip.partLabels[entry.key] or (entry.show~=nil and type(entry.show)~="boolean") or (entry.join~=nil and type(entry.join)~="boolean") then return nil,"Invalid tooltip layout." end
    end
    if type(result.system)=="table" and result.system.objectives~=nil and result.system.objectives~="collapsed" and result.system.objectives~="open" and result.system.objectives~="hidden" then result.system.objectives=nil end
    if not check(result.threat,{enabled="boolean",show="string",rows="number",collapsed="boolean",x="number",y="number",text="boolean",font="string",size="number",outline="string",background="boolean",backgroundColor="table",backgroundAlpha="number",textX="number",textY="number",width="number",height="number",locked="boolean",grip="string"}) then return nil,"Invalid threat settings." end
    local cooldowns=nil; if type(result.buffReminder)=="table" then cooldowns=result.buffReminder.cooldowns end
    if cooldowns~=nil then
        if type(cooldowns)~="table" or not check(cooldowns,{enabled="boolean",sound="boolean",tough="boolean",pulls="boolean",defensive="boolean",chosen="table",roles="table"}) then return nil,"Invalid cooldown reminders." end
        for k,v in pairs(cooldowns.chosen or {}) do if type(k)~="string" or type(v)~="boolean" then return nil,"Invalid cooldown reminders." end end
        for k,v in pairs(cooldowns.roles or {}) do if type(k)~="string" or (v~="offensive" and v~="defensive" and v~="off") then return nil,"Invalid cooldown reminders." end end
    end
    if not check(result.smartKey,{enabled="boolean",key="string",confirmed="boolean"}) then return nil,"Invalid smart key settings." end
    if not check(result.fireAlert,{sound="string",channel="string"}) then return nil,"Invalid standing-in-fire settings." end
    if not check(result.rareAlert,{enabled="boolean",sound="boolean",soundKey="string",duration="number",size="number",glow="table",x="number",y="number"}) then return nil,"Invalid rare alert settings." end
    if not check(result.buffReminder,{enabled="boolean",selected="table",mainEnchant="string",offEnchant="string",rankMarker="boolean",ignoredRanks="table",selfWhere="table",groupWhere="table",chosenSpec="table",hideAfter="number"}) then return nil,"Invalid buff reminders." end
    for class,tree in pairs(result.buffReminder and result.buffReminder.chosenSpec or {}) do
        if type(class)~="string" or type(tree)~="string" then return nil,"Invalid talent tree choice." end
    end
    for _,field in ipairs({"selfWhere","groupWhere"}) do
        for key,on in pairs(result.buffReminder and result.buffReminder[field] or {}) do
            if type(key)~="string" or type(on)~="boolean" then return nil,"Invalid reminder places." end
        end
    end
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
            if type(pref)~="table" or not check(pref,{preset="string",opacity="number",shadow="boolean",thickness="number",borderOpacity="number",slotOpacity="number",slotColor="table",hideSlotArt="boolean",rares="boolean",elites="boolean",color="table",borderColor="table"}) then return false end
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
