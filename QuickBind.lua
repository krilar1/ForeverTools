local _,FT=...
-- /kb: opens Blizzard's own Quick Keybind Mode (hover a slot, press a key;
-- Escape unbinds; the game shows those hints itself) and adds a small
-- ForeverTools panel with snapshots so changes can be saved or rolled back.
-- Keybinds are changed only through the game's binding API, outside combat.
local Q={snapshots={}}
local MAX_SNAPSHOTS=6 -- the "before" snapshot plus five mid-edit ones
local function native() return _G.QuickKeybindFrame end
function Q:Available()
    if not native() and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn,"Blizzard_QuickKeybind") end
    return native()~=nil
end
local function capture() return FT.modules.Profiles:CaptureBindings() or {} end
function Q:Open()
    if InCombatLockdown() then
        self.afterCombat=true
        FT:Toast("Quick keybind mode opens when combat ends.",3)
        return
    end
    if not self:Available() then FT:Toast("Quick keybind mode is not available in this game version.",3); return end
    local frame=native()
    if frame:IsShown() then self:ShowPanel(); return end
    -- Get the settings windows out of the way of the action bars.
    if FT.home then FT.home:Hide() end
    for _,module in pairs(FT.modules) do if module.frame and module.frame~=self.panel then module.frame:Hide() end end
    self:Hook()
    self.snapshots={{label="Before this session",time=date("%H:%M"),map=capture()}}
    self.startedHere=true
    frame:Show()
    self:ShowPanel()
    FT:Toast("Snapshot taken: your keybinds from before this session are saved.",4)
end
function Q:Hook()
    local frame=native()
    if not frame or self.hooked then return end
    self.hooked=true
    frame:HookScript("OnShow",function()
        -- Opened from Blizzard's options: still offer snapshots.
        if not self.startedHere and not InCombatLockdown() then
            self.snapshots={{label="Before this session",time=date("%H:%M"),map=capture()}}
        end
        self:ShowPanel()
    end)
    -- Saving with Blizzard's own Okay button also keeps the undo point.
    if frame.OkayButton then frame.OkayButton:HookScript("OnClick",function() self:RecordSession(); if FT.modules.System then FT.modules.System:Refresh() end end) end
    frame:HookScript("OnHide",function()
        if self.panel then self.panel:Hide() end
        local fromKB=self.startedHere
        self.startedHere=nil
        -- Blizzard reopens its options window when the mode ends. When the
        -- mode was started with /kb, close that again so play resumes.
        if fromKB and not self.keepSettings then
            C_Timer.After(0,function()
                local settings=_G.SettingsPanel
                if settings and settings:IsShown() and not InCombatLockdown() and settings.Close then pcall(settings.Close,settings,true) end
            end)
        end
        self.keepSettings=nil
    end)
end
-- Session history. Only the keys that changed are stored with the "before"
-- layout, so the list shows real edits, never the ~140 untouched bindings.
-- It lives in this account's saved settings only and is never exported.
local MAX_HISTORY=10
function Q:History()
    if type(FT.db.keybindHistory)~="table" then FT.db.keybindHistory={} end
    local history=FT.db.keybindHistory
    -- One-time move of the single undo point from 0.14.3 test builds.
    local old=FT.db.keybindUndo
    if type(old)=="table" and type(old.map)=="table" then
        table.insert(history,1,{time=old.time or time(),label="Keybind session",before=old.map,changes=self:Changes(old.map,capture())})
        FT.db.keybindUndo=nil
    end
    return history
end
-- key -> {old action or false, new action or false}, for keys that differ.
function Q:Changes(before,after)
    local changes={}
    for key,action in pairs(before) do if after[key]~=action then changes[key]={action,after[key] or false} end end
    for key,action in pairs(after) do if before[key]==nil then changes[key]={false,action} end end
    return changes
end
local function actionName(action)
    local ok,name=pcall(GetBindingName,action)
    return ok and type(name)=="string" and name~="" and name or action
end
local function keyName(key)
    local ok,text=pcall(GetBindingText,key)
    return ok and type(text)=="string" and text~="" and text or key
end
-- Readable lines, one per changed action: "Action Button 1: Q → E".
function Q:ChangeLines(changes)
    local byAction={}
    local function entry(action) byAction[action]=byAction[action] or {added={},removed={}}; return byAction[action] end
    for key,pair in pairs(changes) do
        if pair[1] then table.insert(entry(pair[1]).removed,keyName(key)) end
        if pair[2] then table.insert(entry(pair[2]).added,keyName(key)) end
    end
    local lines={}
    for action,e in pairs(byAction) do
        table.sort(e.added); table.sort(e.removed)
        local text
        if #e.added==1 and #e.removed==1 then text=e.removed[1].." → "..e.added[1]
        else
            local parts={}
            if #e.added>0 then parts[#parts+1]=table.concat(e.added,", ").." added" end
            if #e.removed>0 then parts[#parts+1]=table.concat(e.removed,", ").." removed" end
            text=table.concat(parts,"; ")
        end
        lines[#lines+1]=actionName(action)..": "..text
    end
    table.sort(lines)
    return lines
end
function Q:ChangeText(changes,limit)
    local lines=self:ChangeLines(changes); limit=limit or 16
    if #lines==0 then return "No keybind changes." end
    local shown={}
    for i=1,math.min(#lines,limit) do shown[i]=lines[i] end
    if #lines>limit then shown[#shown+1]="…and "..(#lines-limit).." more" end
    return table.concat(shown,"\n")
end
function Q:Record(before,label)
    local changes=self:Changes(before,capture())
    if next(changes)==nil then return end
    local history=self:History()
    table.insert(history,1,{time=time(),label=label or "Keybind session",before=before,changes=changes})
    while #history>MAX_HISTORY do table.remove(history) end
end
function Q:RecordSession()
    local before=self.snapshots[1]
    if before then self:Record(before.map,"Keybind session") end
end
function Q:TakeSnapshot()
    if InCombatLockdown() then return end
    local list=self.snapshots
    if #list>=MAX_SNAPSHOTS then table.remove(list,2) end -- keep "before" forever
    local number=(self.counter or 1)+1; self.counter=number
    list[#list+1]={label="Snapshot "..number,time=date("%H:%M"),map=capture()}
    self:RefreshPanel()
    FT:Toast("Snapshot "..number.." taken.",2)
end
function Q:Revert(index)
    local snap=self.snapshots[index]
    if not snap or InCombatLockdown() then return end
    -- Live and unsaved: keep editing, then Save or Discard as usual.
    FT.modules.Profiles:ApplyBindings(snap.map,true,true)
    local frame=native()
    if frame and frame.mouseOverButton and frame.mouseOverButton.QuickKeybindButtonSetTooltip then pcall(frame.mouseOverButton.QuickKeybindButtonSetTooltip,frame.mouseOverButton) end
    FT:Toast("Keybinds reverted to "..snap.label:lower().." ("..snap.time..").",3)
end
function Q:Finish(save)
    local frame=native(); if not frame or InCombatLockdown() then return end
    -- The same steps as Blizzard's Okay / Cancel buttons: save or reload the
    -- binding set, stop listening, close the popup.
    local listener=_G.KeybindListener
    if listener and listener.StopListening then pcall(listener.StopListening,listener) end
    if save then
        SaveBindings(GetCurrentBindingSet())
        self:RecordSession()
        FT:Toast("Keybinds saved. Restore earlier keybinds any time in System → Gameplay.",4)
    else
        LoadBindings(GetCurrentBindingSet())
        FT:Toast("Changes discarded.",2)
    end
    frame:Hide()
    if FT.modules.System then FT.modules.System:Refresh() end
end
-- Restore picker: every saved session, newest first. Hovering one lists
-- what that session changed; choosing it puts back the keybinds from before it.
function Q:RestoreChoices()
    local list={}
    for i,entry in ipairs(self:History()) do
        local n=#self:ChangeLines(entry.changes)
        list[#list+1]={value=i,label=date("%d %b %H:%M",entry.time).." · "..entry.label.." · "..n.." change"..(n==1 and "" or "s"),
            icon="Interface\\Icons\\"..FT.icons.keybind,
            tooltipTitle="Before "..entry.label:lower().." ("..date("%d %b %H:%M",entry.time)..")",
            tooltip=function() return "This session changed:\n"..self:ChangeText(entry.changes).."\n\nChoose to put back the keybinds you had before it." end}
    end
    return list
end
function Q:Restore(index)
    local entry=self:History()[index]
    if not entry or InCombatLockdown() then if InCombatLockdown() then FT:Toast("Change keybinds outside combat.") end; return end
    FT:Confirm("Restore the keybinds from before this session ("..date("%d %b %H:%M",entry.time)..")?\n\nYour current keybinds are replaced. The restore itself can be undone from the same list.",function()
        local current=capture()
        if FT.modules.Profiles:ApplyBindings(entry.before,false,true) then
            self:Record(current,"Restore")
            FT:Toast("Keybinds restored.",3)
            if FT.modules.System then FT.modules.System:Refresh() end
        end
    end)
end
function Q:ShowRestore(owner)
    owner.options=function() return self:RestoreChoices() end
    owner.onSelect=function(index) self:Restore(index) end
    owner.menuWidth=380
    FT:ShowChoices(owner)
end
function Q:HasUndo() return #self:History()>0 end
function Q:ShowPanel()
    if InCombatLockdown() then return end
    if not self.panel then
        local panel=CreateFrame("Frame","ForeverToolsQuickKeybind",UIParent); self.panel=panel
        panel:SetSize(300,286); panel:SetFrameStrata("DIALOG"); panel:EnableMouse(true); panel:SetClampedToScreen(true)
        FT:Panel(panel)
        local title=FT:Label(panel,"Keybind snapshots",17,true); title:SetPoint("TOPLEFT",20,-20); title:SetTextColor(.82,.68,1)
        FT:AddClose(panel,function() self:Finish(false) end)
        panel.closeButton:HookScript("OnEnter",function() GameTooltip:AddLine("Closing discards unsaved changes.",.91,.88,.96,true); GameTooltip:Show() end)
        local help=FT:Label(panel,"Hover any slot and press a key to bind it. Escape on a bound slot unbinds it.",12)
        help:SetPoint("TOPLEFT",20,-54); help:SetWidth(260); help:SetTextColor(.78,.74,.86)
        local take=FT:QuietButton(panel,"Take snapshot",260,32,"add"); take:SetPoint("TOPLEFT",20,-100)
        take:SetScript("OnClick",function() self:TakeSnapshot() end)
        FT:Tooltip(take,"Take snapshot","Remember your keybinds as they are right now, so you can come back to this point while you keep editing.")
        self.revert=FT:Dropdown(panel,260,function()
            local list={}
            for i=#self.snapshots,1,-1 do
                local snap=self.snapshots[i]
                list[#list+1]={value=i,label=snap.label.." · "..snap.time,icon="Interface\\Icons\\"..FT.icons.keybind,
                    tooltipTitle=snap.label.." ("..snap.time..")",
                    tooltip=function() return "Reverting changes:\n"..self:ChangeText(self:Changes(capture(),snap.map)) end}
            end
            return list
        end,function(index) self:Revert(index) end,"reset")
        self.revert:SetPoint("TOPLEFT",20,-140); self.revert:SetHeight(32); self.revert.menuWidth=260
        FT:Tooltip(self.revert,"Revert to snapshot","Put your keybinds back to a snapshot. Nothing is saved yet: keep editing, then Save or Discard.")
        self.status=FT:Label(panel,"",12); self.status:SetPoint("TOPLEFT",20,-182); self.status:SetWidth(260); self.status:SetTextColor(.66,.57,.77)
        local discard=FT:QuietButton(panel,"Discard",124,34,"reset"); discard:SetPoint("BOTTOMLEFT",20,20)
        discard:SetScript("OnClick",function() self:Finish(false) end)
        FT:Tooltip(discard,"Discard & exit","Leave quick keybind mode and go back to the keybinds you had before this session.")
        local save=FT:AccentButton(panel,"Save",124,34,"confirm"); save:SetPoint("BOTTOMRIGHT",-20,20)
        save:SetScript("OnClick",function() self:Finish(true) end)
        FT:Tooltip(save,"Save & exit","Keep your new keybinds and leave quick keybind mode. You can go back later with Restore keybinds in System → Gameplay.")
        panel:Hide()
    end
    self:Place()
    self:RefreshPanel()
    self.panel:Show()
end
-- Beside Blizzard's popup, on whichever side has room.
function Q:Place()
    local frame,panel=native(),self.panel
    panel:ClearAllPoints()
    local right=frame and frame.GetRight and frame:GetRight()
    if frame and right and UIParent:GetWidth()-right>panel:GetWidth()+16 then panel:SetPoint("TOPLEFT",frame,"TOPRIGHT",10,0)
    elseif frame and frame.GetLeft and (frame:GetLeft() or 0)>panel:GetWidth()+16 then panel:SetPoint("TOPRIGHT",frame,"TOPLEFT",-10,0)
    else panel:SetPoint("TOP",UIParent,"TOP",0,-120) end
end
function Q:RefreshPanel()
    if not self.panel then return end
    local count=#self.snapshots
    self.revert.label:SetText("Revert to snapshot")
    self.status:SetText(count<=1 and "Snapshot taken when you started. Take more while you edit." or (count.." snapshots this session, including the one from before you started."))
end
FT:RegisterModule("QuickBind",Q)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED"); events:RegisterEvent("PLAYER_REGEN_ENABLED"); events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then
        -- Also offer snapshots when the mode is opened from Blizzard's options.
        if native() then Q:Hook() end
    elseif event=="PLAYER_REGEN_DISABLED" then
        if Q.panel then Q.panel:Hide() end
    elseif Q.afterCombat then
        Q.afterCombat=nil; C_Timer.After(.5,function() Q:Open() end)
    elseif native() and native():IsShown() then Q:ShowPanel() end
end)
SLASH_FOREVERTOOLSKB1="/kb"
SlashCmdList.FOREVERTOOLSKB=function() Q:Open() end
