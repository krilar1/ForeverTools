local _,FT=...
-- Mailbox: "Only my alts". While typing a name in the To: box, the game
-- suggests everyone it knows (guild, friends, recent players) and often puts
-- a guildie before your own character. With this on, it suggests only your
-- own characters on this realm and faction: the ones the game lists as yours,
-- plus the ones ForeverTools has seen you log in with. A small switch next to
-- the To: box turns it off for a moment when you do want guildies and friends.
-- Setting: System > Loot, merchant and mail > "Mailbox: only suggest my alts".
-- Only the mailbox's own name box is changed, and only while the setting is on.
local Mail={}
local ACCOUNT=Enum and Enum.AutoCompleteEntryFlag and Enum.AutoCompleteEntryFlag.AccountCharacter or 128
local BNET=Enum and Enum.AutoCompleteEntryFlag and Enum.AutoCompleteEntryFlag.Bnet or 1
local SAME_REALM=Enum and Enum.AutoCompletePriority and Enum.AutoCompletePriority.AccountCharacterSameRealm or 6
local function plain(v) return type(v)=="string" and not (issecretvalue and issecretvalue(v)) and v or nil end
function Mail:Settings() return FT.modules.System:Settings() end
function Mail:On() return FT.dbReady and self:Settings().mailAlts==true end
-- The switch in the mailbox (on at first; remembered).
function Mail:AltsOnly() return self:On() and self:Settings().mailAltsOnly~=false end
-- Your characters ForeverTools has seen on this realm and faction (not this one).
-- withData: {name=, c=} entries (class for the alt list) instead of names.
function Mail:KnownAlts(withData)
    local list={}
    local bags=FT.Bags; if not bags or not bags.Store then return list end
    local me=plain(UnitGUID and UnitGUID("player"))
    local realm=bags.Ruleset and select(1,bags:Ruleset())
    local faction=plain(UnitFactionGroup and UnitFactionGroup("player"))
    for guid,c in pairs(bags:Store().chars) do
        if guid~=me and type(c)=="table" and type(c.name)=="string" and c.name~="?" and c.name~=""
            and (not realm or c.realm==realm) and (not faction or not c.faction or c.faction==faction) then
            list[#list+1]=withData and {name=c.name,c=c} or c.name
        end
    end
    if withData then table.sort(list,function(a,b) return a.name<b.name end) else table.sort(list) end
    return list
end
-- The name box's suggestions: alts only, or the game's usual list.
function Mail:Results(original,text,count,cursor,allowFull,include,exclude)
    if not self:AltsOnly() then return original(text,count,cursor,allowFull,include,exclude) end
    local out,seen={},{}
    local ok,game=pcall(original,text,count,cursor,allowFull,ACCOUNT,BNET)
    if ok and type(game)=="table" then
        for _,r in ipairs(game) do
            local name=type(r)=="table" and plain(r.name)
            if name and not seen[name:lower()] then seen[name:lower()]=true; out[#out+1]=r end
        end
    end
    local typed=plain(text); typed=typed and typed:lower() or ""
    for _,name in ipairs(self:KnownAlts()) do
        local key=name:lower()
        if not seen[key] and key:sub(1,#typed)==typed and (allowFull or key~=typed) then
            seen[key]=true; out[#out+1]={name=name,priority=SAME_REALM,bnetID=0}
        end
    end
    while count and #out>count do out[#out]=nil end
    return out
end
function Mail:Hook()
    local box=_G.SendMailNameEditBox
    if not box or box.ftMailAlts then return end
    local original=box.autoCompleteSource
    if type(original)~="function" then return end
    box.ftMailAlts=true; self.box=box
    box.autoCompleteSource=function(...) return Mail:Results(original,...) end
    -- The switch and the alt list sit just right of the To: box. The box is
    -- made as wide as the Subject box (minus the two buttons) so full names
    -- fit, and the postage moves up beside the window's close button.
    local button=CreateFrame("Button",nil,box); button:SetSize(18,18); self.button=button
    button:SetFrameLevel((box:GetFrameLevel() or 1)+3)
    button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints(); button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    if FT.RoundIcon then FT:RoundIcon(button.icon) end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    -- The alt list: a small arrow left of the switch. Picks one of your
    -- characters on this realm and faction, with class icon and colour.
    local pick=CreateFrame("Button",nil,box); pick:SetSize(16,18); self.pick=pick
    pick:SetPoint("LEFT",box,"RIGHT",4,0); pick:SetFrameLevel((box:GetFrameLevel() or 1)+3)
    button:SetPoint("LEFT",pick,"RIGHT",2,0)
    pick.arrow=pick:CreateTexture(nil,"ARTWORK"); pick.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    pick.arrow:SetSize(14,14); pick.arrow:SetPoint("CENTER",0,-3); pick.arrow:SetVertexColor(1,.82,0)
    pick:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    pick.menuWidth=250; pick.alwaysIcons=true; pick.ftCombatOK=true; pick.noPeek=true; pick.accent=true
    pick.options=function() return self:AltChoices() end
    pick.onSelect=function(name)
        if type(name)~="string" or name=="" then return end
        box:SetText(name); if box.SetCursorPosition then box:SetCursorPosition(#name) end
        local subject=_G.SendMailSubjectEditBox
        if subject and subject.SetFocus then subject:SetFocus() end
        self:GoldSubject()
    end
    pick:SetScript("OnClick",function() pick.value=box:GetText(); FT:ShowChoices(pick) end)
    FT:Tooltip(pick,"Send to an alt","Pick one of your characters on this realm and faction.")
    button:SetScript("OnClick",function()
        local s=self:Settings(); s.mailAltsOnly=not self:AltsOnly(); self:Refresh()
        if GameTooltip:IsOwned(button) and button:GetScript("OnEnter") then button:GetScript("OnEnter")(button) end
        -- Show the new suggestions for what is typed now.
        if box:HasFocus() and AutoComplete_Update then pcall(AutoComplete_Update,box,box:GetText(),box:GetCursorPosition()) end
    end)
    FT:Tooltip(button,function() return self:AltsOnly() and "Only my alts: On" or "Only my alts: Off" end,
        function() return self:AltsOnly() and "Names you type suggest only your own characters on this realm. Click to suggest guildies and friends too."
            or "Names you type suggest everyone, as the game does. Click to suggest only your alts." end)
    self:Refresh()
end
-- The alt list's choices: class icon on the left, name in class colour.
function Mail:AltChoices()
    local out={}
    local bags=FT.Bags
    for _,alt in ipairs(self:KnownAlts(true)) do
        local full=type(alt.c.fullName)=="string" and alt.c.fullName~="" and alt.c.fullName or alt.name
        out[#out+1]={value=full,label=bags and bags.ClassName and bags:ClassName(alt.c,nil,true) or alt.name,
            icon=bags and bags.ClassIcon and bags:ClassIcon(alt.c) or nil}
    end
    if #out==0 then
        out[1]={value="",label="No alts seen yet",disabled=true,
            tooltip="Log in once on each of your characters on this realm and faction, and they show up here."}
    end
    return out
end
-- The To: row's layout while the setting is on; the game's own when off.
local SUBJECT_WIDTH=220
function Mail:Layout(on)
    local box=self.box; if not box then return end
    local cost=_G.SendMailCostMoneyFrame
    local middle=_G.SendMailNameEditBoxMiddle
    if not self.original then
        local points={}
        if cost then for i=1,cost:GetNumPoints() do points[i]={cost:GetPoint(i)} end end
        if cost then
            for _,r in ipairs({cost:GetRegions()}) do
                if r.GetObjectType and r:GetObjectType()=="FontString" and r.GetText and r:GetText()==(_G.SEND_MAIL_COST or "Postage:") then self.costLabel=r end
            end
        end
        self.original={width=box:GetWidth(),middle=middle and middle:GetWidth(),cost=points,level=cost and cost:GetFrameLevel()}
    end
    local o=self.original
    if InCombatLockdown() and box.IsProtected and box:IsProtected() then return end
    if on then
        local width=math.max(o.width or 109,SUBJECT_WIDTH-40)
        box:SetWidth(width); if middle then middle:SetWidth(width-9) end
        local close=(_G.MailFrame and (_G.MailFrame.CloseButton or _G.MailFrameCloseButton)) or _G.MailFrameCloseButton
        if cost and close then
            cost:ClearAllPoints(); cost:SetPoint("RIGHT",close,"LEFT",-6,0)
            -- Above the window's title bar, which is drawn over the send page.
            cost:SetFrameLevel((close:GetFrameLevel() or 1)+2)
            -- Only the coins: the "Postage:" word would run into the title.
            -- Pointing at them says what they are.
            if self.costLabel then self.costLabel:Hide() end
            if not cost.ftPostageTip then
                cost.ftPostageTip=true
                if cost.EnableMouse then cost:EnableMouse(true) end
                cost:HookScript("OnEnter",function(owner)
                    if not Mail:On() then return end
                    GameTooltip:SetOwner(owner,"ANCHOR_BOTTOM"); GameTooltip:SetText(_G.SEND_MAIL_COST or "Postage:",1,.82,0); GameTooltip:Show()
                end)
                cost:HookScript("OnLeave",function() GameTooltip:Hide() end)
            end
        end
    else
        if o.width then box:SetWidth(o.width) end
        if middle and o.middle then middle:SetWidth(o.middle) end
        if cost and #o.cost>0 then
            cost:ClearAllPoints()
            for _,pt in ipairs(o.cost) do cost:SetPoint(unpack(pt)) end
            if o.level then cost:SetFrameLevel(o.level) end
            if self.costLabel then self.costLabel:Show() end
        end
    end
end
function Mail:Refresh()
    if not self.button then return end
    self.button:SetShown(self:On())
    if self.pick then self.pick:SetShown(self:On()) end
    self:Layout(self:On())
    local only=self:AltsOnly()
    self.button.icon:SetDesaturated(not only); self.button.icon:SetAlpha(only and 1 or .55)
end
-- Gold to an alt: when the mail only carries money (no items, not C.O.D.)
-- and goes to one of your characters, the amount becomes the subject
-- ("12g 50s"). Only an empty subject, or one this filled in, is changed.
-- Setting: System > Loot, merchant and mail > "Mailbox: gold amount as subject".
function Mail:GoldOn() return FT.dbReady and self:Settings().mailGold==true end
function Mail:IsAlt(name)
    name=plain(name); if not name then return false end
    name=name:match("^%s*(.-)%s*$"):lower(); if name=="" then return false end
    name=name:match("^([^%-]+)") or name
    for _,alt in ipairs(self:KnownAlts(true)) do
        if alt.name:lower()==name or (type(alt.c.fullName)=="string" and alt.c.fullName:lower()==name) then return true end
    end
    return false
end
local function amountText(copper)
    local g,sv,c=math.floor(copper/10000),math.floor(copper/100)%100,copper%100
    local parts={}
    if g>0 then parts[#parts+1]=g.."g" end
    if sv>0 then parts[#parts+1]=sv.."s" end
    if c>0 then parts[#parts+1]=c.."c" end
    return table.concat(parts," ")
end
local function hasItems()
    for i=1,(ATTACHMENTS_MAX_SEND or 12) do
        local ok,name=pcall(GetSendMailItem or function() end,i)
        if ok and name then return true end
    end
    return false
end
function Mail:GoldSubject()
    if not self:GoldOn() then return end
    local subject,box,money=_G.SendMailSubjectEditBox,_G.SendMailNameEditBox,_G.SendMailMoney
    if not (subject and box and money and MoneyInputFrame_GetCopper) then return end
    local current=subject:GetText() or ""
    if current~="" and current~=self.autoSubject then return end
    local ok,copper=pcall(MoneyInputFrame_GetCopper,money)
    copper=ok and tonumber(copper) or 0
    local cod=_G.SendMailCODButton and _G.SendMailCODButton.GetChecked and _G.SendMailCODButton:GetChecked()
    local want=""
    if copper>0 and not cod and not hasItems() and self:IsAlt(box:GetText()) then want=amountText(copper) end
    if want==current then return end
    if want=="" and current~=self.autoSubject then return end
    self.filling=true; subject:SetText(want); self.filling=nil
    self.autoSubject=want~="" and want or nil
end
function Mail:HookGold()
    if self.goldHooked then return end
    local subject=_G.SendMailSubjectEditBox
    if not (subject and _G.SendMailMoney and _G.SendMailNameEditBox) then return end
    self.goldHooked=true
    local function later() C_Timer.After(0,function() Mail:GoldSubject() end) end
    for _,name in ipairs({"SendMailMoneyGold","SendMailMoneySilver","SendMailMoneyCopper","SendMailNameEditBox"}) do
        local edit=_G[name]; if edit and edit.HookScript then edit:HookScript("OnTextChanged",later) end
    end
    for _,name in ipairs({"SendMailSendMoneyButton","SendMailCODButton"}) do
        local b=_G[name]; if b and b.HookScript then b:HookScript("OnClick",later) end
    end
    if type(SendMailFrame_Update)=="function" then hooksecurefunc("SendMailFrame_Update",later) end
    -- Typed over by you: yours from then on.
    subject:HookScript("OnTextChanged",function(_,user) if user and not Mail.filling then Mail.autoSubject=nil end end)
end
function Mail:Apply()
    if self:On() then
        self:Hook()
        -- Remember this character for the list (unless remembering characters is off).
        local st=FT.db and FT.db.bagStore
        if FT.Bags and FT.Bags.Record and not (type(st)=="table" and st.off==true) then pcall(FT.Bags.Record,FT.Bags,true) end
    end
    if self:GoldOn() then self:HookGold() end
    self:Refresh()
end
FT:RegisterModule("MailAlts",Mail)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("MAIL_SHOW")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then C_Timer.After(2,function() if FT.dbReady then Mail:Apply() end end)
    else
        if Mail:On() then Mail:Hook(); Mail:Refresh() end
        if Mail:GoldOn() then Mail:HookGold() end
    end
end)
