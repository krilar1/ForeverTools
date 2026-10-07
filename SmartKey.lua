local _,FT=...
-- Smart interact key (off by default): one key that does the right thing.
--   * A dialog is open (quest, gossip, merchant…): Interact with target, so
--     nothing gets closed.
--   * Your target is friendly or dead, or the game's interact key has
--     something in reach: Interact with target (talk, loot).
--   * RestedXP shows a quest item button: use the item.
--   * RestedXP shows a target button and you have no target: target it.
--   * Otherwise: Interact with target.
-- When the key you chose is already your own Interact with target key, that
-- binding is left alone and only the RestedXP cases are put on top of it.
-- It uses the game's own secure key switching (a key that clicks another
-- button), so it also works in combat and never acts on its own: you still
-- press the key. RestedXP's buttons are only clicked, never changed. Without
-- RestedXP the key is just Interact with target.
local Key={}
local ITEMS={"RXPItemFrameButton1","RXPItemFrameButton2","RXPItemFrameButton3","RXPItemFrameButton4"}
local TARGETS={"RXPTargetFrame_EnemyButton1","RXPTargetFrame_EnemyButton2","RXPTargetFrame_EnemyButton3","RXPTargetFrame_EnemyButton4",
    "RXPTargetFrame_FriendlyButton1","RXPTargetFrame_FriendlyButton2","RXPTargetFrame_FriendlyButton3","RXPTargetFrame_FriendlyButton4"}
local DIALOGS={"GossipFrame","QuestFrame","MerchantFrame","ClassTrainerFrame","TaxiFrame","BankFrame","MailFrame","ItemTextFrame"}

function Key:Settings()
    if type(FT.db.smartKey)~="table" then FT.db.smartKey={} end
    local s=FT.db.smartKey
    if type(s.enabled)~="boolean" then s.enabled=false end
    if s.key~=nil and (type(s.key)~="string" or s.key=="") then s.key=nil end
    -- A test build could take a key without asking; drop any key that was
    -- never confirmed, and switch off until one is chosen.
    if s.key and s.confirmed~=true then s.key=nil; s.enabled=false end
    if not s.key then s.enabled=false end
    return s
end
-- Only a key you chose yourself; nothing is ever bound on its own.
function Key:CurrentKey() return self:Settings().key end
local function keyText(key) return key and (GetBindingText and GetBindingText(key) or key) or "none" end
local function actionText(key)
    local action=key and GetBindingAction and GetBindingAction(key)
    if not action or action=="" then return nil end
    return GetBindingName and GetBindingName(action) or action
end
-- Every new key is confirmed, showing what it does now, so a stray key
-- press (for example a movement key) can't take over a key by accident.
function Key:Propose(key)
    if not key or InCombatLockdown() then return end
    local current=actionText(key)
    local text='Use "'..keyText(key)..'" as the smart interact key?'
    if current and current~=(GetBindingName and GetBindingName("INTERACTTARGET") or "INTERACTTARGET") then
        text=text.."\n\nIt is bound to "..current..' now. While the smart key is on, "'..keyText(key)..'" does Interact with target and the RestedXP buttons instead. Turning the smart key off gives it back.'
    end
    FT:Confirm(text,function() local s=self:Settings(); s.key=key; s.confirmed=true; self:Update() end)
end

-- The secure part: a small handler that owns the key's override binding and
-- re-decides when your target changes (also in combat) or when we tell it
-- (out of combat) that RestedXP's buttons or a dialog changed.
function Key:Header()
    if self.header then return self.header end
    local h=CreateFrame("Frame","ForeverToolsSmartKey",UIParent,"SecureHandlerAttributeTemplate")
    h:SetAttribute("_onattributechanged",[[
        if name~="state-target" and name~="refresh" then return end
        self:ClearBindings()
        local key=self:GetAttribute("smartkey")
        if not key or self:GetAttribute("on")~=1 then return end
        -- Your own Interact key already interacts: nothing to put on it.
        if self:GetAttribute("native")~=1 then self:SetBinding(false,key,"INTERACTTARGET") end
        if self:GetAttribute("dialog")==1 then return end
        local state=self:GetAttribute("state-target")
        if state=="interact" then return end
        local item=self:GetAttribute("item")
        if item then self:SetBindingClick(true,key,item,"LeftButton") return end
        local target=self:GetAttribute("targetbutton")
        if target and state=="none" then self:SetBindingClick(true,key,target,"LeftButton") end
    ]])
    -- interact: someone to talk to or loot (a friendly or dead target, or
    -- something in reach of the game's own interact key). enemy: a living
    -- enemy target. none: no target.
    RegisterStateDriver(h,"target","[@target,help,nodead][@target,dead][@softinteract,exists] interact; [@target,exists] enemy; none")
    self.header=h
    return h
end
local function visible(name) local f=_G[name]; return f and f.IsVisible and f:IsVisible() and name or nil end
function Key:Scan()
    local item,target
    for _,name in ipairs(ITEMS) do item=item or visible(name) end
    for _,name in ipairs(TARGETS) do target=target or visible(name) end
    local dialog=0
    for _,name in ipairs(DIALOGS) do local f=_G[name]; if f and f.IsShown and f:IsShown() then dialog=1 end end
    return item,target,dialog
end
-- Out of combat only (the game allows changing the key then); anything that
-- changes in combat is picked up when it ends.
function Key:Update()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.pending=true; return end
    self.pending=false
    local s=self:Settings()
    if not s.enabled and not self.header then return end
    local h=self:Header()
    self:WatchButtons()
    local item,target,dialog=self:Scan()
    local key=s.enabled and self:CurrentKey() or nil
    -- Is the chosen key the game's own Interact with target key?
    local native=0
    if key and GetBindingKey then for _,bound in ipairs({GetBindingKey("INTERACTTARGET")}) do if bound==key then native=1 end end end
    self.state={item=item,target=target,dialog=dialog==1,native=native==1}
    -- Only touch the binding when something changed. (Changing it makes the
    -- game announce new bindings, which would otherwise start this again.)
    local signature=tostring(s.enabled)..":"..tostring(key)..":"..tostring(item)..":"..tostring(target)..":"..dialog..":"..native
    if signature==self.signature then self:Refresh(); return end
    self.signature=signature
    h:SetAttribute("on",s.enabled and 1 or 0)
    h:SetAttribute("smartkey",key); h:SetAttribute("native",native)
    h:SetAttribute("item",item); h:SetAttribute("targetbutton",target); h:SetAttribute("dialog",dialog)
    h:SetAttribute("refresh",(h:GetAttribute("refresh") or 0)+1)
    self:Refresh()
end
function Key:Queue() FT:Coalesce("smartKey",function() self:Update() end) end
-- RestedXP makes its buttons when a guide step needs them: watch them (and
-- their parent frames) showing and hiding.
function Key:WatchButtons()
    self.watched=self.watched or {}
    local function watch(frame)
        if not frame or self.watched[frame] or not frame.HookScript then return end
        self.watched[frame]=true
        frame:HookScript("OnShow",function() self:Queue() end)
        frame:HookScript("OnHide",function() self:Queue() end)
    end
    for _,list in ipairs({ITEMS,TARGETS}) do
        for _,name in ipairs(list) do
            local f=_G[name]; watch(f)
            if f and f.GetParent then watch(f:GetParent()) end
        end
    end
end

local events=CreateFrame("Frame")
local dialogEvents={"GOSSIP_SHOW","GOSSIP_CLOSED","QUEST_GREETING","QUEST_DETAIL","QUEST_PROGRESS","QUEST_COMPLETE","QUEST_FINISHED","MERCHANT_SHOW","MERCHANT_CLOSED","TRAINER_SHOW","TRAINER_CLOSED","TAXIMAP_OPENED","TAXIMAP_CLOSED","BANKFRAME_OPENED","BANKFRAME_CLOSED","MAIL_SHOW","MAIL_CLOSED","ITEM_TEXT_BEGIN","ITEM_TEXT_CLOSED"}
events:SetScript("OnEvent",function(_,event,name)
    if not FT.dbReady then return end
    if event=="ADDON_LOADED" and name~="RXPGuides" then return end
    if event=="PLAYER_REGEN_ENABLED" and not Key.pending then return end
    -- Dialog frames finish showing or hiding after their event.
    C_Timer.After(0,function() Key:Update() end)
end)
function Key:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    if s.enabled then
        for _,event in ipairs(dialogEvents) do pcall(events.RegisterEvent,events,event) end
        for _,event in ipairs({"PLAYER_REGEN_ENABLED","UPDATE_BINDINGS","ADDON_LOADED","PLAYER_ENTERING_WORLD"}) do events:RegisterEvent(event) end
    else events:UnregisterAllEvents() end
    self:Update()
end

-- Settings page (Keybinds)
function Key:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Smart interact key: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    local key=self:CurrentKey()
    self.keyLabel:SetText("Key: "..(self.capturing and "press a key… (Escape cancels)" or (key and keyText(key) or "not chosen yet")))
    local rxp=_G.RXPItemFrameButton1 or _G.RXPTargetFrame_EnemyButton1 or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides"))
    local st=self.state or {}
    local now
    if not s.enabled then now="Off."
    elseif not key then now="|cffff9e59Choose a key first.|r"
    elseif st.dialog then now="A dialog is open: the key interacts."
    elseif st.item then now="RestedXP shows a quest item: the key uses it. With a friendly or dead target it interacts instead."
    elseif st.target then now="RestedXP shows a target: with no target, the key targets it; otherwise it interacts."
    else now="The key interacts with your target." end
    local lines={"Right now: "..now}
    if s.enabled and key then lines[#lines+1]=self:Doing(key) end
    if not rxp then lines[#lines+1]="RestedXP is not loaded, so the key is just Interact with target." end
    self.status:SetText(table.concat(lines,"\n"))
end
-- What the game has on the key at this moment, in plain words, so a key
-- that another addon or binding took over shows up here.
function Key:Doing(key)
    local action=GetBindingAction and GetBindingAction(key,true)
    if type(action)~="string" or action=="" then return "|cffff9e59The key has nothing on it. Turn the smart key off and on again, out of combat.|r" end
    if action=="INTERACTTARGET" then return "The key is set to: Interact with target"..((self.state and self.state.native) and " (your own key binding)." or ".") end
    local button=action:match("^CLICK ([^:]+)")
    if button then
        for _,name in ipairs(ITEMS) do if name==button then return "The key is set to: RestedXP's quest item." end end
        for _,name in ipairs(TARGETS) do if name==button then return "The key is set to: RestedXP's target button." end end
    end
    return "|cffff9e59Something else has the key: "..((GetBindingName and GetBindingName(action)) or action)..".|r"
end
-- One line for the bug report.
function Key:Report()
    local s=self:Settings(); if not s.key then return nil end
    local st=self.state or {}
    local action=GetBindingAction and GetBindingAction(s.key,true)
    local base=GetBindingAction and GetBindingAction(s.key)
    return "Smart key: "..tostring(s.key).." ("..(s.enabled and "on" or "off")..") · set to "..tostring(action).." · game binding "..tostring(base)
        .." · own interact key "..tostring(st.native==true).." · item "..tostring(st.item).." · target button "..tostring(st.target).." · dialog "..tostring(st.dialog==true)
end
function Key:Capture(on)
    self.capturing=on
    -- The listener only exists while you are choosing: hidden, it can't
    -- catch a key (for example a movement key) by accident.
    self.capture:EnableKeyboard(on)
    self.capture:SetPropagateKeyboardInput(not on)
    self.capture:SetShown(on)
    self:Refresh()
end
function Key:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsSmartKey","Smart interact key",520,262); self.frame=frame
        FT:BackTo(frame,"SystemKeybinds")
        FT:PageInfo(frame,"Smart interact key","One key for questing. It picks the first that fits:\n1. A dialog is open, or your target is friendly or dead: Interact with target (talk, loot).\n2. RestedXP shows a quest item: use it.\n3. RestedXP shows a target and you have none: target it.\n4. Otherwise: Interact with target.\n\nWorks in combat; RestedXP buttons that appear in combat count once it ends. You choose the key yourself and confirm it. The page shows what the key is set to right now.")
        self.toggle=FT:AccentButton(frame,"",472,34,"INV_Misc_Key_10"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function()
            if InCombatLockdown() then FT:Toast("Leave combat to change this."); return end
            local s=self:Settings()
            if not s.enabled and not s.key then FT:Toast("Choose a key first.",3); return end
            s.enabled=not s.enabled; self:Apply()
            if FT.modules.System then FT.modules.System:Refresh() end
        end)
        FT:Tooltip(self.toggle,"Smart interact key","One key for questing: it talks and loots, uses RestedXP's quest item, or targets what RestedXP wants. Choose a key first. Off, your key works exactly as before. The (i) has the full order.")
        self.keyLabel=FT:Label(frame,"",15); self.keyLabel:SetPoint("TOPLEFT",24,-114); self.keyLabel:SetWidth(472)
        local change=FT:QuietButton(frame,"Choose a key",230,32,"keybind"); change:SetPoint("TOPLEFT",24,-140)
        change:SetScript("OnClick",function() if not InCombatLockdown() then self:Capture(true) end end)
        FT:Tooltip(change,"Choose a key","Click, then press the key (with Shift, Ctrl or Alt if you like). You're asked to confirm, and told what the key does now. Escape cancels.")
        self.useInteract=FT:QuietButton(frame,"Use my Interact key",230,32,"reset"); self.useInteract:SetPoint("TOPLEFT",266,-140)
        self.useInteract:SetScript("OnClick",function()
            local key=GetBindingKey and GetBindingKey("INTERACTTARGET")
            if not key then FT:Toast("Interact with target has no key in the game's key bindings.",3); return end
            self:Propose(key)
        end)
        FT:Tooltip(self.useInteract,"Use my Interact key","Use the key you already have on Interact with target in the game's key bindings (asks first).")
        -- Key capture: the next key pressed becomes the smart key.
        local capture=CreateFrame("Frame",nil,frame); capture:SetAllPoints(frame); capture:EnableKeyboard(false); capture:Hide()
        capture:SetScript("OnKeyDown",function(_,key)
            if not self.capturing then return end
            if key=="ESCAPE" then self:Capture(false); return end
            if key:find("SHIFT") or key:find("CTRL") or key:find("ALT") then return end
            local combo=(IsAltKeyDown() and "ALT-" or "")..(IsControlKeyDown() and "CTRL-" or "")..(IsShiftKeyDown() and "SHIFT-" or "")..key
            self:Capture(false); self:Propose(combo)
        end)
        self.capture=capture
        self.status=FT:Label(frame,"",13); self.status:SetPoint("TOPLEFT",24,-190); self.status:SetWidth(472); self.status:SetJustifyV("TOP")
        frame:HookScript("OnHide",function() if self.capturing then self:Capture(false) end end)
    end
    self:Update(); self:Refresh(); self.frame:Show()
end
FT:RegisterModule("SmartKey",Key)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Key:Apply() end end)
