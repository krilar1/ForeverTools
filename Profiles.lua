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
    if self.active then return "Using profile: "..self.active..". Changes are saved to it automatically. Click to switch profiles." end
    return "No profile yet. Your first change makes one named after this character. Click to choose a profile."
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
        FT.home.profileStatus:SetText(name and shortName("Profile: "..name,27) or "No profile")
        FT.home.profileStatus:SetTextColor(name and .85 or .66,name and .72 or .59,name and .42 or .48)
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
        self:Load(value,true)
    end
    FT:ShowChoices(owner)
end
-- Only preferences are copied. Macro history and installed WoW macros belong to
-- the character and are never rewritten by loading an appearance profile.
local keys={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","macroScope","macroUnlearnedIcons","macroBulkMouseover","chat","system","customKeybinds","customFonts","lootRoll","tooltip","buffReminder","customMacros","flightTimer","leveling","dispelGlow","actionMacros","rareAlert","threat","fireAlert","smartKey","totems","movers"}
-- Every module that must redraw after settings change (load, login, reset).
local applyModules={"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll","BuffReminder","FlightTimer","Leveling","DispelGlow","QuestTracker","MinimapIcons","RareAlert","Threat","CooldownReminder","SmartKey","FireAlert","Totems"}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
-- Values the addon keeps up to date by itself (a font's resolved file path)
-- are not user changes, and positions re-clamped to the screen move by a
-- fraction of a pixel; neither should count as "unsaved changes".
local derived={path=true,pathFor=true}
-- A missing table and an empty one mean the same (pages create their empty
-- lists when first opened; that alone is not a change).
local function blank(v) return v==nil or (type(v)=="table" and next(v)==nil) end
local function same(a,b)
    if a==b then return true end
    if blank(a) and blank(b) then return true end
    if type(a)=="number" and type(b)=="number" then return math.abs(a-b)<0.5 end
    if type(a)~="table" or type(b)~="table" then return false end
    for k,v in pairs(a) do if not derived[k] and not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil and not derived[k] then return false end end
    return true
end
-- Setting-by-setting differences: {set=value}, {del=true} or {sub={key=diff}}.
local function diff(now,base)
    if same(now,base) then return nil end
    if type(now)=="table" and type(base)=="table" then
        local subs={}
        for k,v in pairs(now) do if not derived[k] then subs[k]=diff(v,base[k]) end end
        for k in pairs(base) do if now[k]==nil and not derived[k] and not blank(base[k]) then subs[k]={del=true} end end
        return next(subs) and {sub=subs} or nil
    end
    if now==nil then return {del=true} end
    return {set=copy(now)}
end
local function merge(base,change)
    if type(change)~="table" then return base end
    if change.del then return nil end
    if change.set~=nil then return copy(change.set) end
    if type(change.sub)=="table" then
        base=type(base)=="table" and base or {}
        for k,c in pairs(change.sub) do base[k]=merge(base[k],c) end
    end
    return base
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
    -- The profile you leave keeps everything you changed.
    if self.active~=name then self:AutoSave(true) end
    saved=copy(self:Store()[name]) -- detached before any settings callbacks run
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
-- Characters using a profile, by the names they had when they last logged in.
function Profiles:UsedBy(name)
    local names,others={},0
    local known=type(FT.db.characterNames)=="table" and FT.db.characterNames or {}
    for guid,profile in pairs(FT.db.profileCharacters or {}) do
        if profile==name then
            local full=known[guid]
            if type(full)=="string" then names[#names+1]=full:match("^[^%-]+") or full else others=others+1 end
        end
    end
    table.sort(names)
    return names,others
end
function Profiles:Refresh()
    self:RefreshIndicators()
    if not self.choice then return end
    local store=self:Store()
    local active=self.active and type(store[self.active])=="table" and self.active or nil
    self.choice.value=active
    local hasProfiles=self:AnyProfile()~=nil
    self.choice.label:SetText(active or (hasProfiles and "No profile: choose one" or "No profile yet"))
    self.choice:SetEnabled(hasProfiles)
    if active then
        local names,others=self:UsedBy(active)
        local text=table.concat(names,", ")
        if others>0 then text=text..(text~="" and " and " or "")..others.." more" end
        self.usedBy:SetText("Used by: "..(text~="" and text or "this character").."  ·  saves automatically")
    else
        self.usedBy:SetText("Your first change makes a profile named after this character.")
    end
    for _,button in ipairs({self.copyButton,self.rename,self.delete,self.export}) do button:SetEnabled(active~=nil); button:SetAlpha(active and 1 or .45) end
    local history=active and FT.db.profileBackups and FT.db.profileBackups[active]
    local backups=type(history)=="table" and #history or 0
    self.undo.label:SetText(backups>0 and ("Restore an earlier version ("..backups..")") or "No earlier versions yet")
    self.undo:SetEnabled(backups>0); self.undo:SetAlpha(backups>0 and 1 or .45)
    if self.newCharacter then
        local chosen=FT.db.newCharacterProfile
        if type(chosen)~="string" or type(store[chosen])~="table" then chosen=nil end
        self.newCharacter.value=chosen or "\001last"
        local last=self:NewCharacterProfile()
        self.newCharacter.label:SetText(chosen or ("Last used"..(last and (" ("..last..")") or "")))
        self.newCharacter:SetEnabled(hasProfiles); self.newCharacter:SetAlpha(hasProfiles and 1 or .45)
    end
end
function Profiles:RestoreChoices()
    local list={}
    local history=self.active and FT.db.profileBackups and FT.db.profileBackups[self.active] or {}
    for i=#history,1,-1 do
        local entry=history[i]
        if type(entry)=="table" and type(entry.settings)=="table" then
            list[#list+1]={value=i,label=date("%d %b %H:%M",entry.time or 0).." · "..(entry.label or "Earlier version"),
                icon="Interface\\Icons\\"..FT.icons.reset,tooltipTitle=entry.label or "Earlier version",
                tooltip="Put the profile back the way it was then. Your current version is kept in this list too, so this can be undone."}
        end
    end
    return list
end
function Profiles:RestoreVersion(index)
    local name=self.active; local history=name and FT.db.profileBackups and FT.db.profileBackups[name]
    local entry=type(history)=="table" and history[index]
    if type(entry)~="table" or type(entry.settings)~="table" then return end
    if InCombatLockdown() then FT:Toast("Change profiles outside combat."); return end
    FT:Confirm('Put profile "'..name..'" back to '..date("%d %b %H:%M",entry.time or 0)..'?\n\nYour current version is kept, so you can go back to it.',function()
        local settings=copy(entry.settings)
        self:AutoSave(); self:Archive(name,"Before restore")
        self:Store()[name]=settings; FT.db.profileVault[name]=copy(settings)
        self:Load(name,true,true); self:Refresh()
        FT:Toast('Profile "'..name..'" restored.',3)
    end)
end
function Profiles:CopyProfile()
    local from=self.active; if not from or not self:Store()[from] then return end
    FT:AskText('Copy "'..from..'" as a new profile named:',from.." copy",function(new)
        new=new:match("^%s*(.-)%s*$")
        if new=="" or #new>120 then FT:Toast("Use 1–120 characters."); return end
        if self:Store()[new] then FT:Toast("A profile with that name already exists."); return end
        self:AutoSave(true)
        self:Store()[new]=copy(self:Store()[from]); FT.db.profileVault[new]=copy(self:Store()[new])
        if self:Load(new,true,true) then FT:Toast('Copied to "'..new..'" and switched to it.',3) end
        self:Refresh()
    end)
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
        local window=FT:Window("ForeverToolsProfiles","Profiles",520,514)
        window.noSavePrompt=true -- this page saves by itself
        self.panel=window; self.frame=window
        FT:PageInfo(window,"Profiles","A profile is your ForeverTools setup. Characters on the same profile share it, and every change is saved to it automatically.\n\nKeybinds, action bars and spell binds stay with each character; they travel only in an export.")
        self.choice=FT:Dropdown(window,472,function() return self:ProfileList() end,function(name) self:Load(name,true) ; self:Refresh() end,"profiles")
        self.choice:SetPoint("TOPLEFT",24,-62); self.choice:SetHeight(34)
        FT:Tooltip(self.choice,"Profile","The profile this character uses. Pick another to switch; the one you leave keeps everything you changed.")
        self.usedBy=FT:Label(window,"",12); self.usedBy:SetPoint("TOPLEFT",26,-104); self.usedBy:SetWidth(468); self.usedBy:SetJustifyH("LEFT")
        self.usedBy:SetTextColor(.66,.59,.48); self.usedBy:SetWordWrap(false)
        local function heading(text,icon,y) local h=FT:Label(window,text,15,true); h:SetPoint("TOPLEFT",24,y); FT:SectionHeading(h,icon,380) end
        local function button(text,icon,x,y,width) local b=FT:QuietButton(window,text,width or 232,32,icon); b:SetPoint("TOPLEFT",x,y); return b end
        heading("Manage","INV_Misc_Book_09",-130)
        local new=button("New profile","add",24,-154)
        new:SetScript("OnClick",function()
            FT:AskText("Name for the new profile:","",function(name) self:Create(name) end)
        end)
        FT:Tooltip(new,"New profile","Start a profile with default settings (everything off) and switch to it. Your custom macros and fonts come along.")
        self.copyButton=button("Copy","INV_Misc_Note_02",264,-154)
        self.copyButton:SetScript("OnClick",function() self:CopyProfile() end)
        FT:Tooltip(self.copyButton,"Copy profile","Make a new profile with the same settings as this one and switch to it. Good for trying things without changing the original.")
        self.rename=button("Rename","fonts",24,-194)
        self.rename:SetScript("OnClick",function()
            local old=self.active; if not old or not self:Store()[old] then return end
            FT:AskText('Rename profile "'..old..'" to:',old,function(new)
                if new=="" or new==old then return end
                if #new>120 then FT:Toast("Use at most 120 characters."); return end
                if self:Store()[new] then FT:Toast("A profile with that name already exists."); return end
                self:Rename(old,new)
            end)
        end)
        FT:Tooltip(self.rename,"Rename profile","Give this profile a new name. Its settings and the characters using it stay the same.")
        self.delete=button("Delete","delete",264,-194)
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE={text="",button1="Delete",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingDelete then self:Delete(self.pendingDelete); self.pendingDelete=nil end end}
        self.delete:SetScript("OnClick",function()
            self.pendingDelete=self.active; if not self.pendingDelete then return end
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE.text='Delete profile "'..self.pendingDelete..'"?\n\nThis character keeps its current settings. Other characters using it go back to default settings.'
            FT:ShowPopup("FOREVERTOOLS_PROFILE_DELETE")
        end)
        FT:Tooltip(self.delete,"Delete profile","Delete this profile. Asks first.")
        heading("Share","INV_Misc_Note_01",-242)
        self.export=button("Export","INV_Misc_Note_01",24,-266)
        self.export:SetScript("OnClick",function() self:AutoSave(true); self:Transfer(false) end)
        FT:Tooltip(self.export,"Export","Text you can copy to keep a backup or move your setup to another computer or account. You choose whether keybinds, action bars and spell binds come along.")
        local import=button("Import","INV_Misc_Note_03",264,-266)
        import:SetScript("OnClick",function() self:Transfer(true) end)
        FT:Tooltip(import,"Import","Paste an export text. It becomes a new profile and this character switches to it; your keybinds, action bars and spell binds are backed up first if the text includes them.")
        heading("Undo","Spell_Nature_TimeStop",-314)
        self.undo=FT:Dropdown(window,472,function() return self:RestoreChoices() end,function(index) self:RestoreVersion(index) end,"reset")
        self.undo:SetPoint("TOPLEFT",24,-338); self.undo:SetHeight(32); self.undo.menuWidth=472
        FT:Tooltip(self.undo,"Restore an earlier version","Copies of this profile saved automatically: before your first change each session, before a restore, and before default settings. The last 3 are kept.")
        heading("New characters","INV_Misc_Head_Human_01",-386)
        self.newCharacter=FT:Dropdown(window,472,function()
            local list={{value="\001last",label="Last used profile",icon="Interface\\Icons\\INV_Misc_Book_09"}}
            for _,entry in ipairs(self:ProfileList()) do list[#list+1]=entry end
            return list
        end,function(value) FT.db.newCharacterProfile=value~="\001last" and value or nil; self:Refresh() end,"character")
        self.newCharacter:SetPoint("TOPLEFT",24,-410); self.newCharacter:SetHeight(32)
        FT:Tooltip(self.newCharacter,"Profile for new characters","A new character asks once which profile to use; this one is picked for it. \"Last used\" is the profile you used most recently.")
        self.defaults=FT:QuietButton(window,"Default settings",472,32,"reset"); self.defaults:SetPoint("TOPLEFT",24,-458)
        self.defaults.outline=true; FT:UpdateButton(self.defaults); self.defaults.label:SetTextColor(1,.86,.55)
        self.defaults:SetScript("OnClick",function() self:DefaultSettings() end)
        FT:Tooltip(self.defaults,"Default settings","Put everything ForeverTools changes back to Blizzard's defaults, as if the addon was just installed. This profile is reset too (a copy is kept under Undo). Custom macros, other profiles and learned flight times stay. Asks first, then reloads.")
    end
    self:Refresh()
end
FT:RegisterModule("Profiles",Profiles)
function Profiles:WelcomeCharacter()
    local guid=self:Character(); if not guid then return end
    FT.db.profileCharacters=FT.db.profileCharacters or {}
    -- Names for "Used by" on the Profiles page.
    FT.db.characterNames=type(FT.db.characterNames)=="table" and FT.db.characterNames or {}
    FT.db.characterNames[guid]=self:CharacterName()
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
        local profile=previous and self:Store()[previous]
        if type(draft)=="table" and draft.changesOnly==2 and type(profile)=="table" then
            -- The profile as saved, plus only what this character changed.
            local changes=type(draft.changes)=="table" and draft.changes or {}
            for _,key in ipairs(keys) do FT.db[key]=merge(copy(profile[key]),changes[key]) end
        else
            local source=type(draft)=="table" and draft or profile
            for _,key in ipairs(keys) do FT.db[key]=copy(source[key]) end
        end
        local assigned=previous and self:Store()[previous] and previous or nil
        self.active,self.selected=assigned,assigned
        if type(draft)=="table" then
            -- One-time move from 0.15: changes that were never saved ("Not
            -- now") go into the profile now, since profiles save by themselves.
            FT.db.profileDrafts[guid]=nil
            local store=self:Store()
            local name=assigned
            if not name then
                local base=self:CharacterName(); name=base; local n=2
                while store[name] do name=base.." "..n; n=n+1 end
                self.selected=name; self:Remember(name)
            else self:Archive(name,"Before update") end
            store[name]=self:Snapshot(); FT.db.profileVault[name]=copy(store[name])
        end
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
        note:SetPoint("TOPLEFT",24,-150); note:SetWidth(432); note:SetTextColor(.66,.59,.48)
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
        Profiles:AutoSave(true)
    end
end)

-- Settings only: saved profiles, custom macros/fonts, learned flight routes,
-- rank knowledge and macro history are kept. A reload re-applies native UI.
local resettable={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","minimapCollectorAngle","chat","system","customKeybinds","lootRoll","tooltip","buffReminder","flightTimer","leveling","vendor","dispelGlow","rareAlert","threat","fireAlert","smartKey","totems","movers"}
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
        self:Archive(profileName,"Before default settings")
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
function Profiles:Archive(name,label)
    if type(self:Store()[name])~="table" then return end
    FT.db.profileBackups=FT.db.profileBackups or {}
    local history=FT.db.profileBackups[name] or {}; FT.db.profileBackups[name]=history
    -- Nothing changed since the last backup: no need for another copy.
    local last=history[#history]
    if type(last)=="table" and same(last.settings,self:Store()[name]) then return end
    history[#history+1]={time=time(),label=label,settings=copy(self:Store()[name])}
    while #history>backupLimit do table.remove(history,1) end
end
-- Fill every module's defaults up front. Defaults are written lazily when a
-- module first reads its settings, which must never look like a user change.
function Profiles:Normalize()
    -- Every module fills in its defaults first, so opening a page for the
    -- first time never counts as a change.
    for _,name in ipairs({"LootRoll","System","Tooltip","QualityOfLife","FlightTimer","BuffReminder","CooldownReminder","Leveling","UnitColors","Chat","CustomKeybinds","IconStyles","DispelGlow","RareAlert","Threat","FireAlert","SmartKey","Totems","Movers"}) do
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
-- Changes go straight into the profile this character uses: written when a
-- ForeverTools window closes, before switching profiles, and on logout or
-- reload (never on every click). Before the first change of a session the
-- profile is backed up once, so Profiles > Undo can put it back.
-- A character without a profile gets one named after it on its first change.
function Profiles:AutoSave(full)
    if not FT.dbReady or not self.baseline or self.resetting then return end
    if full then self:CaptureActionMacros() end
    self:Normalize()
    if not self:HasChanges() then return end
    local store=self:Store()
    local name=self.active and type(store[self.active])=="table" and self.active or nil
    if not name then
        local base=self:CharacterName(); name=base; local n=2
        while store[name] do name=base.." "..n; n=n+1 end
        self.selected=name; self:Remember(name)
    end
    self.sessionBackups=self.sessionBackups or {}
    if not self.sessionBackups[name] then self.sessionBackups[name]=true; self:Archive(name,"Before this session") end
    store[name]=self:Snapshot(); FT.db.profileVault[name]=copy(store[name])
    self:Checkpoint(); self:Refresh()
end
-- Older name, still called by a few places.
function Profiles:SaveDraft() self:AutoSave() end
function Profiles:Checkpoint()
    self:Normalize()
    FT.db.profileSchema=2
    local baseline={}
    for _,key in ipairs(keys) do baseline[key]=copy(FT.db[key]) end
    self.baseline=baseline
    local guid=self:Character()
    if guid and FT.db.profileDrafts then FT.db.profileDrafts[guid]=nil end
end
function Profiles:CharacterName()
    local name,realm
    if UnitFullName then name,realm=UnitFullName("player") elseif UnitName then name=UnitName("player") end
    realm=realm and realm~="" and realm or (GetRealmName and GetRealmName()) or "Realm"
    return (name or "Character").."-"..realm
end
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
-- The extra parts an export string can carry besides settings.
Profiles.transferParts={
    {key="keys",data="bindings",export="exportBindings",label="Keybinds",icon="keybind",
        exportTip="Put all your current keybinds in the string.",
        importTip="Use the keybinds in this string. They replace your current keybinds; a backup of yours is saved first (Keybinds > Backups and restore)."},
    {key="bars",data="actionBars",export="exportBars",label="Action bars",icon="macros",
        exportTip="Put what sits in each action bar slot in the string: spells, items and macros.",
        importTip="Put the spells, items and macros back in the same action bar slots. Things this character doesn't know yet are skipped and listed. Same class only. A backup of your bars is saved first."},
    {key="spellBinds",data="spellBinds",export="exportSpellBinds",label="Spell binds",icon="keybind",
        exportTip="Put your spell binds and role keys in the string.",
        importTip="Use the spell binds and role keys in this string on this character. A backup of yours is saved first."},
}
function Profiles:Transfer(importing,onImported)
    if not self.transfer then
        local frame=FT:Window("ForeverToolsProfileTransfer","Profile transfer",600,430); self.transfer=frame
        frame.noSavePrompt=true
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        if frame.homeButton then frame.homeButton:Hide() end
        -- Plain answers to "will my string still work later?"
        local about=FT:Info(frame,"Will my string keep working?","Yes. Export strings keep working after ForeverTools and game updates.\n\n• Settings added after you exported start at their defaults.\n• Keybinds carry over. A key for an action that no longer exists is skipped.\n• Action bars go back in the same slots on a character of the same class; spells not learned yet and items not in your bags are skipped.\n• Mouse-wheel spells need that spell learned on the character.\n• Custom fonts need the same font file on the other computer.\n\nTip: export again after big changes, so your backup matches your setup.")
        about:SetPoint("RIGHT",frame.closeButton,"LEFT",-8,0)
        local info=FT:Label(frame,"",13); info:SetPoint("TOPLEFT",24,-66); info:SetSize(550,45); frame.info=info
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-150); scroll:SetSize(528,160); FT:Panel(scroll)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(520,160); box:SetAutoFocus(false); scroll:SetScrollChild(box); frame.box=box
        local pasteHint=FT:Label(box,"Paste string here",13);pasteHint:SetPoint("TOPLEFT",box,10,-10);frame.pasteHint=pasteHint
        box:SetScript("OnTextChanged",function(_,user)
            local n=#box:GetText(); box:SetHeight(math.max(160,math.ceil(n/65)*16));pasteHint:SetShown(n==0)
            if frame.importing and user then
                local data=n>0 and FT:DecodeProfile(box:GetText())
                for _,part in ipairs(self.transferParts) do
                    frame.has[part.key]=type(data)=="table" and data[part.data]~=nil
                    frame.apply[part.key]=frame.has[part.key]
                end
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
            local backups=FT.modules.Backups
            local bars=frame.apply.bars and backups and backups:ValidBars(data.actionBars)
            local spellBinds=frame.apply.spellBinds and backups and backups:ValidSpellBinds(data.spellBinds)
            local useKeys=bindings and frame.apply.keys
            if (useKeys or bars or spellBinds) and InCombatLockdown() then FT:Toast("Import keybinds and action bars outside combat."); return end
            self:Store()[profileName]=clean; FT.db.profileVault[profileName]=copy(clean); self.selected=profileName; self:Refresh(); frame:Hide()
            -- A copy of what you have now comes first, so it can be put back
            -- (Keybinds > Backups).
            if (useKeys or bars or spellBinds) and backups then backups:Take("Before import",true) end
            if useKeys then self:ApplyBindings(bindings,false,true) end
            local skipped,otherClass
            if bars then
                local _,class=UnitClass("player")
                if bars.class and bars.class~=class then otherClass=true else local _,missing=backups:ApplyBars(bars); skipped=missing end
            end
            if spellBinds then backups:ApplySpellBinds(spellBinds) end
            self:ImportSkinTemplates(data.skinTemplates)
            local parts={}
            if useKeys then parts[#parts+1]="keybinds" end
            if bars and not otherClass then parts[#parts+1]="action bars" end
            if spellBinds then parts[#parts+1]="spell binds" end
            if #parts>0 then
                FT:Toast("Applied "..table.concat(parts,", ")..". Your previous setup is saved in Keybinds > Backups and restore."..
                    (skipped and #skipped>0 and ("\nSkipped (not learned or not in bags): "..table.concat(skipped,", ",1,math.min(#skipped,6))..(#skipped>6 and "…" or "")) or "")..
                    (otherClass and "\nAction bars are from another class and were left as they are." or ""),8)
            end
            local callback=self.onImported; self.onImported=nil
            if callback then callback(profileName)
            elseif self:Load(profileName,true,true) and #parts==0 then FT:Toast('Profile "'..profileName..'" imported and in use.',3) end
            self:Refresh()
        end)
        -- Three toggles, two meanings: what goes into an export, or which parts
        -- of a pasted string to apply. On import, only parts in the string show.
        frame.toggles={}
        for i,part in ipairs(self.transferParts) do
            local b=FT:QuietButton(frame,"",176,32,part.icon); b:SetPoint("BOTTOMLEFT",24+(i-1)*188,68); frame.toggles[part.key]=b
            b:SetScript("OnClick",function()
                if frame.importing then frame.apply[part.key]=not frame.apply[part.key]
                else FT.db[part.export]=not FT.db[part.export]; self:FillExport() end
                self:RefreshTransfer()
            end)
            FT:Tooltip(b,part.label,function() return frame.importing and part.importTip or part.exportTip end)
        end
    end
    local frame=self.transfer
    self.onImported=importing and onImported or nil
    -- Keybinds start off on every export: they are rarely wanted on another
    -- computer, and turning them on is one click.
    if not importing then FT.db.exportBindings=nil end
    frame.importing=importing; frame.has={}; frame.apply={}
    frame.titleText:SetText(importing and "Import profile" or "Export profile")
    frame.import:SetShown(importing); frame.name:SetShown(importing);frame.nameHint:SetShown(importing)
    frame.info:SetText(importing and "Paste an export string, give it a name, then click Import profile. This character switches to the new profile." or "Press Ctrl+C to copy the string, then paste it somewhere safe. It keeps working after addon and game updates.")
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
    local backups=FT.modules.Backups
    if FT.db.exportBars and backups then data.actionBars=backups:CaptureBars() end
    if FT.db.exportSpellBinds and backups then data.spellBinds=backups:CaptureSpellBinds() end
    if type(FT.db.skinTemplates)=="table" and next(FT.db.skinTemplates) then data.skinTemplates=copy(FT.db.skinTemplates) end
    frame.box:SetText(FT:EncodeProfile(data))
    if frame.box.HighlightText then frame.box:HighlightText() end
end
function Profiles:RefreshTransfer()
    local frame=self.transfer; if not frame then return end
    for _,part in ipairs(self.transferParts) do
        local b=frame.toggles[part.key]
        if frame.importing then
            b:SetShown(frame.has[part.key]==true)
            b.label:SetText(part.label..": "..(frame.apply[part.key] and "On" or "Off")); FT:SetSelected(b,frame.apply[part.key])
        else
            b:Show()
            b.label:SetText(part.label..": "..(FT.db[part.export] and "On" or "Off")); FT:SetSelected(b,FT.db[part.export]==true)
        end
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
        if type(cooldowns)~="table" or not check(cooldowns,{enabled="boolean",sound="boolean",tough="boolean",pulls="boolean",defensive="boolean",leveling="boolean",chosen="table",roles="table"}) then return nil,"Invalid cooldown reminders." end
        for k,v in pairs(cooldowns.chosen or {}) do if type(k)~="string" or type(v)~="boolean" then return nil,"Invalid cooldown reminders." end end
        for k,v in pairs(cooldowns.roles or {}) do if type(k)~="string" or (v~="offensive" and v~="defensive" and v~="off") then return nil,"Invalid cooldown reminders." end end
    end
    if not check(result.totems,{range="boolean",opacity="number",colors="table",defaults="number"}) then return nil,"Invalid totem settings." end
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
        if not skin(root) or not check(root,{actions="boolean",buffs="boolean",stances="boolean",areas="table",minimap="boolean",micro="boolean",bags="boolean",player="boolean",target="boolean",tot="boolean",focus="boolean",focustarget="boolean",xp="boolean",pet="boolean",party="boolean",personal="boolean",castbar="boolean"}) then return nil,"Invalid skin settings." end
        for key,pref in pairs(root.areas or {}) do if type(key)~="string" or not skin(pref) then return nil,"Invalid skin area." end end
    end
    for _,file in pairs(result.customFonts or {}) do if type(file)~="string" or #file>150 or file:find("[/\\]") then return nil,"Invalid font filename." end end
    if result.macroScope and result.macroScope~="account" and result.macroScope~="character" then return nil,"Invalid macro destination." end
    return result
end
