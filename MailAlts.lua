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
function Mail:KnownAlts()
    local list={}
    local bags=FT.Bags; if not bags or not bags.Store then return list end
    local me=plain(UnitGUID and UnitGUID("player"))
    local realm=bags.Ruleset and select(1,bags:Ruleset())
    local faction=plain(UnitFactionGroup and UnitFactionGroup("player"))
    for guid,c in pairs(bags:Store().chars) do
        if guid~=me and type(c)=="table" and type(c.name)=="string" and c.name~="?" and c.name~=""
            and (not realm or c.realm==realm) and (not faction or not c.faction or c.faction==faction) then
            list[#list+1]=c.name
        end
    end
    table.sort(list)
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
    -- The switch: a small icon inside the right end of the To: box, so it never
    -- covers the postage. Lit: only your alts; grey: everyone.
    local button=CreateFrame("Button",nil,box); button:SetSize(18,18); self.button=button
    button:SetPoint("RIGHT",box,"RIGHT",-2,0); button:SetFrameLevel((box:GetFrameLevel() or 1)+3)
    button.icon=button:CreateTexture(nil,"ARTWORK"); button.icon:SetAllPoints(); button.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    if FT.RoundIcon then FT:RoundIcon(button.icon) end
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    -- Typed names stop before the icon.
    if box.GetTextInsets and box.SetTextInsets then
        local l,r,t,b=box:GetTextInsets(); box:SetTextInsets(l or 0,(r or 0)+20,t or 0,b or 0)
    end
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
function Mail:Refresh()
    if not self.button then return end
    self.button:SetShown(self:On())
    local only=self:AltsOnly()
    self.button.icon:SetDesaturated(not only); self.button.icon:SetAlpha(only and 1 or .55)
end
function Mail:Apply()
    if self:On() then
        self:Hook()
        -- Remember this character for the list (unless remembering characters is off).
        local st=FT.db and FT.db.bagStore
        if FT.Bags and FT.Bags.Record and not (type(st)=="table" and st.off==true) then pcall(FT.Bags.Record,FT.Bags,true) end
    end
    self:Refresh()
end
FT:RegisterModule("MailAlts",Mail)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("MAIL_SHOW")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then C_Timer.After(2,function() if FT.dbReady then Mail:Apply() end end)
    elseif Mail:On() then Mail:Hook(); Mail:Refresh() end
end)
