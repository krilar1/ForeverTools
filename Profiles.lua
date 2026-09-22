local _, FT = ...
local Profiles = {}
function Profiles:Character()
    return UnitGUID("player")
end
function Profiles:Remember(name)
    FT.db.profileCharacters=FT.db.profileCharacters or {}
    local guid=self:Character()
    if guid then FT.db.profileCharacters[guid]=name or false end
    self.active=name
end
-- Only preferences are copied. Macro history and installed WoW macros belong to
-- the character and are never rewritten by loading an appearance profile.
local keys={"fps","fonts","unitColors","iconStyles","welcome","minimapEnabled","minimapAngle","macroScope","chat","system","customKeybinds","customFonts","lootRoll"}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
function Profiles:Store()
    if type(FT.db.profiles) ~= "table" then FT.db.profiles={} end
    return FT.db.profiles
end
function Profiles:Snapshot()
    local result={}
    for _,key in ipairs(keys) do result[key]=copy(FT.db[key]) end
    return result
end
function Profiles:Save(name, overwrite)
    name=type(name)=="string" and name:match("^%s*(.-)%s*$") or ""
    if name=="" or #name>120 then FT:Toast("Enter a profile name (1–120 characters)."); return false end
    if self:Store()[name] and not overwrite then FT:Toast("That profile name already exists."); return false end

    self:Archive(name)
    self:Store()[name]=self:Snapshot(); self.selected=name
    self:Remember(name)
    self:Checkpoint(); self:Refresh(); FT:Toast("Profile saved: "..name); return true
end
function Profiles:Load(name)
    if InCombatLockdown() then FT:Toast("Load profiles outside combat."); return false end
    local saved=self:Store()[name]; if type(saved)~="table" then FT:Toast("That profile is unavailable."); return false end
    saved=copy(saved) -- detached before any settings callbacks run
    local qol=FT.modules.QualityOfLife
    if qol and qol.moving then qol:SetMoving(false) end

    for _,key in ipairs(keys) do FT.db[key]=copy(saved[key]) end
    FT.minimapDragAngle=nil
    self.selected=name
    self:Remember(name)
    for _,module in ipairs({"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll"}) do
        local object=FT.modules[module]; if object then object:Apply() end
    end
    FT:UpdateMinimap()
    local macros=FT.modules.MacroForge
    if macros then macros.scope=FT.db.macroScope=="account" and "account" or "character" end
    self:Checkpoint(); FT:OpenHome(); FT:Toast("Profile loaded: "..name); return true
end
function Profiles:Delete(name)
    self:Archive(name)
    self:Store()[name]=nil
    if self.selected==name then self.selected=nil end
    if self.active==name then self:Remember(nil) end
    for guid,profile in pairs(FT.db.profileCharacters or {}) do if profile==name then FT.db.profileCharacters[guid]=false end end
    self:Refresh(); FT:Toast("Profile deleted")
end
function Profiles:Refresh()
    if not self.choice then return end
    self.choice.value=self.selected
    self.choice.label:SetText(self.active and ("Active: "..self.active) or "Choose a profile")
    local exists=self.selected and self:Store()[self.selected]~=nil
    for _,button in ipairs({self.load,self.save,self.delete}) do button:SetEnabled(not not exists); button:SetAlpha(exists and 1 or .4) end
end
function Profiles:Attach(home)
    if not self.choice then
        local panel=CreateFrame("Frame",nil,home); panel:SetSize(392,182); panel:EnableMouse(true); panel:SetPoint("TOPRIGHT",home,"TOPRIGHT",-16,-50); FT:Panel(panel)
        self.panel=panel; panel:SetFrameLevel(home:GetFrameLevel()+20); panel:Hide()
        local toggle=FT:QuietButton(home,"Profiles",105,28,"profiles")
        toggle:SetPoint("RIGHT",home.closeButton,"LEFT",-6,0)
        toggle:SetScript("OnClick",function() panel:SetShown(not panel:IsShown()) end)
        FT:Tooltip(toggle,"Profiles","Create, load, save or delete your local profiles.")
        home:HookScript("OnHide",function() panel:Hide() end)
        local label=FT:Label(panel,"Profiles",14,true); label:SetPoint("TOPLEFT",10,-8)
        local info=FT:Info(panel,"Local profiles","Selecting a profile loads its saved snapshot. Save updates that snapshot explicitly. Closing the addon offers to save changed settings under Character-Realm. Working settings survive reload without silently overwriting named profiles. The name field is only for creating a new profile. Profiles are shared across characters; macro history and installed macros are separate.")
        info:SetPoint("TOPRIGHT",-6,-4)
        self.choice=FT:Dropdown(panel,372,function()
            local list={}; for name,value in pairs(self:Store()) do if type(name)=="string" and type(value)=="table" then list[#list+1]={value=name,label=name,icon="Interface\\Icons\\INV_Misc_Book_09"} end end
            table.sort(list,function(a,b) return a.label<b.label end); return list
        end,function(name) self:Load(name) end,"profiles")
        self.choice:SetPoint("TOPLEFT",10,-38)
        self.name=CreateFrame("EditBox",nil,panel); self.name:SetSize(270,28); self.name:SetPoint("TOPLEFT",10,-72)
        self.name:SetFont(FT.bodyFont,14,""); self.name:SetAutoFocus(false); self.name:SetTextInsets(8,8,0,0); FT:Panel(self.name)
        FT:Tooltip(self.name,"New profile name","Type a name, then click Create to save the current settings.")
        local create=FT:QuietButton(panel,"Create",92,28,"add"); create:SetPoint("LEFT",self.name,"RIGHT",10,0)
        create:SetScript("OnClick",function() if self:Save(self.name:GetText()) then self.name:SetText("") end end)
        self.load=FT:QuietButton(panel,"Load",116,28,"profiles"); self.load:SetPoint("TOPLEFT",10,-106)
        self.load:SetScript("OnClick",function() self:Load(self.selected) end)
        self.save=FT:QuietButton(panel,"Save",116,28,"profiles"); self.save:SetPoint("LEFT",self.load,"RIGHT",12,0)
        self.delete=FT:QuietButton(panel,"Delete",116,28,"delete"); self.delete:SetPoint("LEFT",self.save,"RIGHT",12,0)
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE={text="Replace this saved profile with your current settings?",button1="Save",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingSave then self:Save(self.pendingSave,true); self.pendingSave=nil end end}
        StaticPopupDialogs.FOREVERTOOLS_PROFILE_DELETE={text="Delete this saved profile? Current settings will remain in use.",button1="Delete",button2="Cancel",timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() if self.pendingDelete then self:Delete(self.pendingDelete); self.pendingDelete=nil end end}
        self.save:SetScript("OnClick",function()
            self.pendingSave=self.active or self.selected
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_SAVE.text='Save current settings to profile "'..(self.pendingSave or '')..'"?'
            StaticPopup_Show("FOREVERTOOLS_PROFILE_SAVE")
        end)
        self.delete:SetScript("OnClick",function() self.pendingDelete=self.selected; StaticPopup_Show("FOREVERTOOLS_PROFILE_DELETE") end)
        local export=FT:QuietButton(panel,"Export",180,28,"profiles"); export:SetPoint("TOPLEFT",10,-144)
        export:SetScript("OnClick",function() self:Transfer(false) end)
        local import=FT:QuietButton(panel,"Import",180,28,"profiles"); import:SetPoint("LEFT",export,"RIGHT",12,0)
        import:SetScript("OnClick",function() self:Transfer(true) end)
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
        for _,name in ipairs({"QualityOfLife","FontManager","UnitColors","IconStyles","Chat","System","CustomKeybinds","LootRoll"}) do
            local module=FT.modules[name]; if module then module:Apply() end
        end
        FT:UpdateMinimap()
    elseif previous==nil then
        FT.db.profileCharacters[guid]=false
        if next(self:Store()) then
            StaticPopupDialogs.FOREVERTOOLS_PROFILE_WELCOME={text="Welcome to ForeverTools on this character. Use an existing profile to copy your setup?",button1="Choose profile",button2="Keep current",timeout=0,whileDead=true,hideOnEscape=true,
                OnAccept=function() FT:OpenHome(); Profiles.panel:Show(); FT:ShowChoices(Profiles.choice) end}
            StaticPopup_Show("FOREVERTOOLS_PROFILE_WELCOME")
        end
    end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then C_Timer.After(0,function() Profiles:WelcomeCharacter(); Profiles:Checkpoint() end)
    elseif event=="PLAYER_LOGOUT" then
        FT.db.profileDrafts=FT.db.profileDrafts or {}
        local guid=Profiles:Character(); if guid then FT.db.profileDrafts[guid]=Profiles:Snapshot() end
    end
end)

function Profiles:Archive(name)
    if type(self:Store()[name])~="table" then return end
    FT.db.profileBackups=FT.db.profileBackups or {}
    local history=FT.db.profileBackups[name] or {}; FT.db.profileBackups[name]=history
    history[#history+1]={time=time(),settings=copy(self:Store()[name])}
    if #history>10 then table.remove(history,1) end
end
function Profiles:Checkpoint()
    if FT.modules.LootRoll then FT.modules.LootRoll:Settings() end
    local skins=FT.modules.IconStyles
    if skins then
        skins:Area("actions"); skins:Area("buffs")
        for _,entry in ipairs(skins.extraOptions) do skins:Area(entry[1]) end
    end
    if FT.modules.FontManager then FT.modules.FontManager:Settings("general") end
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
    if FT:EncodeProfile(self:Snapshot())==self.baseline then return end
    self.prompting=true
    local name=self:CharacterName()
    StaticPopupDialogs.FOREVERTOOLS_CHANGES={text='Save changes? Save this setup locally as "'..name..'"'..(self:Store()[name] and " (replace its saved snapshot)?" or "?"),button1="Yes",button2="Not now",timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function() self.prompting=nil; self:Save(name,true) end,
        OnCancel=function() self.prompting=nil; self:Checkpoint() end}
    StaticPopup_Show("FOREVERTOOLS_CHANGES")
end
function Profiles:Transfer(importing)
    if not self.transfer then
        local frame=FT:Window("ForeverToolsProfileTransfer","ForeverTools | Profile transfer",600,390); self.transfer=frame
        local info=FT:Label(frame,"",13); info:SetPoint("TOPLEFT",24,-66); info:SetSize(550,45); frame.info=info
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-150); scroll:SetSize(528,160)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(520,160); box:SetAutoFocus(false); scroll:SetScrollChild(box); frame.box=box
        box:SetScript("OnTextChanged",function() local n=#box:GetText(); box:SetHeight(math.max(160,math.ceil(n/65)*16)) end)
        local name=CreateFrame("EditBox",nil,frame,"InputBoxTemplate"); name:SetSize(540,28); name:SetPoint("TOPLEFT",30,-114); name:SetFont(FT.bodyFont,14,""); name:SetAutoFocus(false); frame.name=name
        FT:Tooltip(name,"Imported profile name","A new name is required. Existing profiles will never be overwritten by import.")
        local button=FT:QuietButton(frame,"Import profile",220,32,"profiles"); button:SetPoint("BOTTOMLEFT",24,25); frame.import=button
        button:SetScript("OnClick",function()
            local data,err=FT:DecodeProfile(box:GetText())
            if not data then FT:Toast(err); return end
            local profileName=name:GetText():match("^%s*(.-)%s*$")
            if profileName=="" or #profileName>120 or self:Store()[profileName] then FT:Toast("Choose a new profile name (1–120 characters)."); return end
            local clean,reason=self:ValidateImport(data.settings)
            if not clean then FT:Toast(reason); return end
            self:Store()[profileName]=clean; self.selected=profileName; self:Refresh(); frame:Hide()
            FT:Toast("Profile imported. Select it to load.")
        end)
    end
    local frame=self.transfer
    frame.import:SetShown(importing); frame.name:SetShown(importing)
    frame.info:SetText(importing and "Paste a ForeverTools export string, enter a new profile name, then import. Import does not change your current setup." or "Copy this string to a text file to back up or share your current setup. It contains settings, not executable code.")
    frame.box:SetText(importing and "" or FT:EncodeProfile({format=1,addonVersion=FT.version,settings=self:Snapshot()}))
    frame.name:SetText(""); frame:Show()
    if frame.box.HighlightText then frame.box:HighlightText() end
    if frame.box.SetFocus then frame.box:SetFocus() end
end
-- Import only supported preference keys. Reject mismatched types before any
-- consumer sees data; never merge executable data or addon-owned frame state.
function Profiles:ValidateImport(data)
    local result={}; local scalar={welcome="boolean",minimapEnabled="boolean",minimapAngle="number",macroScope="string"}
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
    if not check(result.lootRoll,{x="number",y="number"}) then return nil,"Invalid loot-roll position." end
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
    if result.iconStyles then
        local function skin(pref)
            if type(pref)~="table" or not check(pref,{preset="string",opacity="number",shadow="boolean",thickness="number",borderOpacity="number",rares="boolean",elites="boolean",color="table",borderColor="table"}) then return false end
            for _,field in ipairs({"color","borderColor"}) do
                if pref[field] then for i=1,3 do if type(pref[field][i])~="number" or pref[field][i]<0 or pref[field][i]>1 then return false end end end
            end
            return true
        end
        local root=result.iconStyles
        if not skin(root) or not check(root,{actions="boolean",buffs="boolean",areas="table",minimap="boolean",micro="boolean",bags="boolean",player="boolean",target="boolean",tot="boolean",focus="boolean",focustarget="boolean",xp="boolean"}) then return nil,"Invalid skin settings." end
        for key,pref in pairs(root.areas or {}) do if type(key)~="string" or not skin(pref) then return nil,"Invalid skin area." end end
    end
    for _,file in pairs(result.customFonts or {}) do if type(file)~="string" or #file>150 or file:find("[/\\]") then return nil,"Invalid font filename." end end
    if result.macroScope and result.macroScope~="account" and result.macroScope~="character" then return nil,"Invalid macro destination." end
    return result
end
