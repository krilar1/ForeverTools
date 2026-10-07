local _,FT=...
-- Edit Mode layouts (where bars and frames sit) are saved by the game, never
-- by a ForeverTools profile. This window keeps a copy of the player's own
-- layout string on the account, and can add a pasted string to the game's
-- layouts and switch to it (only on a click, outside combat, with Edit Mode
-- closed, through the game's own layout calls, checked afterwards). Reading
-- the active layout only reads. A reminder shown on the last days of the
-- beta asks players to export their layout.
local Layout={}
local LIMIT=60000
local HOWTO="Save: press Esc > Edit Mode, open the layout list, choose Share (copy to clipboard), and paste it here and click Import layout, or into its own text file.\n\nPut it back: Esc > Edit Mode > the layout list > Import Layout, paste the string, name it and import it.\n\nThis is not a ForeverTools string. Never paste one into the other, and keep each in its own text file. Menu names can differ a little between game versions."
function Layout:Saved()
    local text=FT.db and FT.db.editModeLayout
    return type(text)=="string" and text or ""
end
local function looksLikeProfile(text) return type(text)=="string" and text:match("^%s*FT1:")~=nil end
local function builtInCount()
    local count=0
    if Enum and type(Enum.EditModePresetLayouts)=="table" then for _ in pairs(Enum.EditModePresetLayouts) do count=count+1 end else count=2 end
    return count
end
-- The active layout as the game's share string, or nil and a short reason.
-- Built-in layouts (Modern, Classic) have no string of their own.
function Layout:Read()
    local api=C_EditMode
    if type(api)~="table" or not api.GetLayouts or not api.ConvertLayoutInfoToString then return nil,"This game version can't give the string. Copy it from Edit Mode instead." end
    local ok,info=pcall(api.GetLayouts)
    if not ok or type(info)~="table" or type(info.layouts)~="table" or type(info.activeLayout)~="number" then return nil,"Couldn't read your layouts. Copy it from Edit Mode instead." end
    -- The game lists its built-in layouts before yours.
    local active=info.layouts[info.activeLayout-builtInCount()]
    if type(active)~="table" then return nil,"You are using one of the game's own layouts. Make a copy of it in Edit Mode, switch to the copy, then try again." end
    local made,text=pcall(api.ConvertLayoutInfoToString,active)
    if not made or type(text)~="string" or text=="" then return nil,"Couldn't read your layout. Copy it from Edit Mode instead." end
    return text
end
-- Add the pasted string to the game's layouts and switch to it. Returns true
-- and the layout's name, or false and a short reason. Never errors.
function Layout:Apply(text)
    if InCombatLockdown() then return false,"Apply it outside combat." end
    local api=C_EditMode
    if type(api)~="table" or not (api.ConvertStringToLayoutInfo and api.GetLayouts and api.SaveLayouts and api.SetActiveLayout) then
        return false,"This game version can't do that. Import it in Edit Mode instead."
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown() then return false,"Close Edit Mode first, then try again." end
    local ok,info=pcall(api.ConvertStringToLayoutInfo,text)
    if not ok or type(info)~="table" then return false,"The game could not read this string. Check that all of it was pasted." end
    local okLayouts,current=pcall(api.GetLayouts)
    if not okLayouts or type(current)~="table" or type(current.layouts)~="table" then return false,"Couldn't read your current layouts." end
    local taken={}
    for _,layout in ipairs(current.layouts) do if type(layout)=="table" and type(layout.layoutName)=="string" then taken[layout.layoutName]=true end end
    local base=type(info.layoutName)=="string" and info.layoutName~="" and info.layoutName or "Imported layout"
    local name,n=base,2
    while taken[name] do name=base.." "..n; n=n+1 end
    info.layoutName=name
    info.layoutType=(Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account) or 1
    current.layouts[#current.layouts+1]=info
    local index=builtInCount()+#current.layouts
    current.activeLayout=index
    local saved,err=pcall(api.SaveLayouts,current)
    if not saved then return false,"The game blocked it ("..tostring(err).."). Import it in Edit Mode instead." end
    pcall(api.SetActiveLayout,index)
    -- Look again: was it really added, and is it the active one?
    local okAfter,after=pcall(api.GetLayouts)
    local found=false
    if okAfter and type(after)=="table" and type(after.layouts)=="table" then
        for _,layout in ipairs(after.layouts) do if type(layout)=="table" and layout.layoutName==name then found=true end end
    end
    if not found then return false,"The game did not accept it. Import it in Edit Mode instead." end
    return true,name
end
-- Whether the active layout can be read (a layout of the player's own).
function Layout:CanRead() return (self:Read())~=nil end
function Layout:Refresh()
    local frame=self.window; if not frame then return end
    local text=self:Saved()
    frame.loading=true; frame.box:SetText(text); frame.loading=false
    frame.hint:SetShown(text=="")
    frame.intro:SetText(text=="" and "Paste an Edit Mode string below. Import layout keeps it on your account and offers to use it in the game."
        or "Your saved Edit Mode layout. Press Ctrl+C to copy it, or apply it on this character.")
    frame.status:SetText(text=="" and "Nothing saved yet." or "Saved on this account.")
    frame.status:SetTextColor(.66,.59,.48)
    frame.read:SetShown(self:CanRead())
    frame.clear:SetShown(text~="")
end
-- Keep what is in the box on the account (empty clears it).
function Layout:Save()
    local frame=self.window; if not frame then return end
    local text=frame.box:GetText() or ""
    text=text:match("^%s*(.-)%s*$")
    if looksLikeProfile(text) then FT:Toast("That is a ForeverTools profile string. It goes in Profiles > Import, not here.",5); return end
    if #text>LIMIT then FT:Toast("That is too long for an Edit Mode string.",4); return end
    FT.db.editModeLayout=text~="" and text or nil
    self:Refresh()
    FT:Toast(text~="" and "Edit Mode layout saved." or "Edit Mode layout cleared.",3)
end
-- copy=true: opened to put the saved string back on a new character.
function Layout:Show(copy)
    if FT:CombatOpenRequest() then return end
    if not self.window then
        local frame=FT:Window("ForeverToolsEditMode","Edit Mode layout",560,350); self.window=frame
        frame.noSavePrompt=true; frame.loading=false
        frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame.homeButton:Hide()
        FT:PageInfo(frame,"Edit Mode layout",HOWTO)
        frame.intro=FT:Label(frame,"",13)
        frame.intro:SetPoint("TOPLEFT",24,-58); frame.intro:SetWidth(512); frame.intro:SetTextColor(.85,.80,.70)
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",24,-110); scroll:SetSize(498,150); FT:Panel(scroll)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetFont(FT.bodyFont,12,""); box:SetSize(490,150); box:SetAutoFocus(false)
        box:SetTextInsets(6,6,6,6); scroll:SetScrollChild(box); frame.box=box
        box:SetScript("OnEscapePressed",function() box:ClearFocus() end)
        local hint=FT:Label(box,"Paste your Edit Mode string here",13); hint:SetPoint("TOPLEFT",box,10,-10); hint:SetWidth(470); hint:SetTextColor(.66,.59,.48); frame.hint=hint
        box:SetScript("OnTextChanged",function(_,user)
            local n=#box:GetText()
            box:SetHeight(math.max(150,math.ceil(n/62)*16)); hint:SetShown(n==0)
            if frame.loading or not user then return end
            local wrong=looksLikeProfile(box:GetText())
            frame.status:SetText(wrong and "That is a ForeverTools string. It goes in Profiles > Import." or "Not saved yet. Click Import layout.")
            if wrong then frame.status:SetTextColor(1,.6,.45) else frame.status:SetTextColor(.85,.80,.70) end
        end)
        box:SetScript("OnEditFocusGained",function(owner) if owner:GetText()~="" then owner:HighlightText() end end)
        -- Long strings: the typing line follows the game's cursor and never lays the text out.
        FT:TextCaret(box,6,{light=true})
        local apply=FT:AccentButton(frame,"Import layout",190,30,"INV_Scroll_03"); apply:SetPoint("TOPLEFT",24,-276); frame.apply=apply
        apply:SetScript("OnClick",function()
            local text=(box:GetText() or ""):match("^%s*(.-)%s*$")
            if text=="" then FT:Toast("Paste an Edit Mode string first.",4); return end
            if looksLikeProfile(text) then FT:Toast("That is a ForeverTools profile string. It goes in Profiles > Import, not here.",5); return end
            if #text>LIMIT then FT:Toast("That is too long for an Edit Mode string.",4); return end
            self:Save()
            -- Kept on the account; whether to switch to it now is the player's call.
            FT:Confirm("Your Edit Mode layout is saved on this account.\n\nUse it in the game now? It is added to your Edit Mode layouts and switched to. Choose Cancel to only keep it.",function()
                local ok,result=self:Apply(text)
                if ok then FT:Toast('Edit Mode layout "'..result..'" is now active.',5); frame.status:SetText('Applied as "'..result..'".'); frame.status:SetTextColor(.55,.85,.45); frame:Hide()
                else FT:Toast(result,7); frame.status:SetText(result); frame.status:SetTextColor(1,.6,.45) end
            end)
        end)
        FT:Tooltip(apply,"Import layout","Keeps the string on your account, then asks if you want to use it in the game now. If the game does not allow an addon to switch layouts, you are told and can import it in Edit Mode instead. Not during combat.")
        local read=FT:QuietButton(frame,"Read from game",190,30,"reset"); read:SetPoint("LEFT",apply,"RIGHT",8,0); frame.read=read
        read:SetScript("OnClick",function()
            local text,reason=self:Read()
            if not text then FT:Toast(reason,6); return end
            if #text>LIMIT then FT:Toast("That layout is too long to keep here. Copy it from Edit Mode instead.",5); return end
            frame.loading=true; box:SetText(text); frame.loading=false; hint:SetShown(false)
            frame.status:SetText("Not saved yet. Click Import layout."); frame.status:SetTextColor(.85,.80,.70)
        end)
        FT:Tooltip(read,"Read from game","Fills the box with your active Edit Mode layout, then click Import layout. It only reads; nothing in the game changes. Shown only when your active layout is one of your own.")
        local clear=FT:QuietButton(frame,"Clear",100,30,"delete"); clear:SetPoint("LEFT",read,"RIGHT",8,0); frame.clear=clear
        clear:SetScript("OnClick",function() frame.loading=true; box:SetText(""); frame.loading=false; self:Save() end)
        FT:Tooltip(clear,"Clear","Remove the saved string from your account.")
        frame.status=FT:Label(frame,"",12); frame.status:SetPoint("TOPLEFT",24,-316); frame.status:SetWidth(512)
    end
    self:Refresh()
    self.window:Show()
    FT:PlaceBeside(self.window)
    if copy and self:Saved()~="" then
        self.window.box:SetFocus(); self.window.box:HighlightText()
        self.window.status:SetText("Press Ctrl+C, then import it in Edit Mode.")
    end
end
-- Last days of the beta: ask players to export their layout, once per day.
local REMIND_FROM,REMIND_TO=20261018,20261021
function Layout:ReminderDue()
    if not FT.db or FT.db.editModeReminderOff then return false end
    local day=tonumber(date("%Y%m%d")); if not day then return false end
    return day>=REMIND_FROM and day<=REMIND_TO and FT.db.editModeReminderDay~=day
end
-- force: show it now whatever the date (/ft editmode remind).
function Layout:Remind(force)
    if not force and not self:ReminderDue() then return end
    if InCombatLockdown() then self.remindWaiting=true; return end
    if not UIParent:IsShown() then C_Timer.After(5,function() self:Remind(force) end); return end
    local frame=self.reminder
    if not frame then
        frame=FT:Window("ForeverToolsEditModeReminder","Export your Edit Mode layout",446,230); self.reminder=frame
        frame.ignorePlacement=true; frame.noSavePrompt=true; frame.homeButton:Hide()
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:ClearAllPoints(); frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-40,-160)
        local text=FT:Label(frame,"The beta ends on October 21. Your Edit Mode layout (where your bars and frames sit) is saved by the game for the beta only and does not carry over to the live game.\n\nExport it now: Esc > Edit Mode > layout list > Share, and keep the text in a file. Then import it the same way when the game is out.",13)
        text:SetPoint("TOPLEFT",24,-58); text:SetWidth(398); text:SetTextColor(.85,.80,.70)
        local open=FT:AccentButton(frame,"Open layout window",182,30,"INV_Scroll_03"); open:SetPoint("BOTTOMLEFT",24,20)
        open:SetScript("OnClick",function() frame:Hide(); self:Show() end)
        local close=FT:QuietButton(frame,"Close",66,30); close:SetPoint("LEFT",open,"RIGHT",8,0)
        close:SetScript("OnClick",function() frame:Hide() end)
        local never=FT:QuietButton(frame,"Don't remind me",134,30); never:SetPoint("LEFT",close,"RIGHT",8,0)
        never:SetScript("OnClick",function() FT.db.editModeReminderOff=true; frame:Hide(); FT:Toast("Reminder turned off.",3) end)
    end
    if not force then FT.db.editModeReminderDay=tonumber(date("%Y%m%d")) end
    frame:Show(); frame:ClearAllPoints(); frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-40,-160)
end
FT:RegisterModule("EditModeLayout",Layout)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then C_Timer.After(12,function() Layout:Remind() end)
    elseif Layout.remindWaiting then Layout.remindWaiting=false; C_Timer.After(2,function() Layout:Remind() end) end
end)
