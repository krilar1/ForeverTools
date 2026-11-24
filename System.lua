local _,FT=...
local System={}
-- Quiet login (System > General): other addons' print() lines are left out
-- of chat from load until 10 s after you enter the world. The chat windows
-- are never touched (standing in for AddMessage once got whispers blocked,
-- 1.6.0): only the game's print handler is swapped for that time, then put
-- back. Which addon printed is read from the call stack; addons you pick
-- still show. Lines an addon writes straight into a chat window still show.
local quiet={held={},hidden={}}
local function quietOn()
    if not FT.dbReady or type(FT.db)~="table" then return nil end
    local s=type(FT.db.system)=="table" and FT.db.system or {}
    return s.quietLogin~=false, type(s.quietShow)=="table" and s.quietShow or {}
end
local function printer()
    if not debugstack then return end
    local ok,stack=pcall(debugstack,3,20,0)
    if not ok or type(stack)~="string" then return end
    for name in stack:gmatch("[Aa]dd[Oo]ns[/\\]([^/\\]+)[/\\]") do
        if name~=(FT.name or "ForeverTools") and not name:find("^Blizzard_") then return name end
    end
end
local function quietHandler(...)
    local original=quiet.original
    if quiet.done or not original then if original then return original(...) end return end
    local name=printer()
    if not name then return original(...) end
    local on,show=quietOn()
    if on==nil then
        -- Settings not loaded yet: keep the line until they are.
        quiet.held[#quiet.held+1]={name=name,n=select("#",...),...}; return
    end
    if not on or show[name] then return original(...) end
    quiet.hidden[name]=(quiet.hidden[name] or 0)+1
end
function System:QuietStart()
    if quiet.original or not setprinthandler or not getprinthandler then return end
    local ok,current=pcall(getprinthandler)
    if not ok or type(current)~="function" then return end
    quiet.original=current
    pcall(setprinthandler,quietHandler)
end
-- Settings loaded: lines kept until now go out, unless hidden.
function System:QuietReady()
    local held=quiet.held; quiet.held={}
    local on,show=quietOn()
    for _,line in ipairs(held) do
        if (not on or show[line.name]) and quiet.original then pcall(quiet.original,unpack(line,1,line.n))
        else quiet.hidden[line.name]=(quiet.hidden[line.name] or 0)+1 end
    end
    if on==false then self:QuietStop() end
end
function System:QuietStop()
    if quiet.done then return end
    quiet.done=true
    if #quiet.held>0 then self:QuietReady() end
    -- Only put the game's own back if nothing replaced ours since; else ours passes lines on.
    if quiet.original and getprinthandler and getprinthandler()==quietHandler then pcall(setprinthandler,quiet.original) end
    if FT.db then FT.db.quietHidden=quiet.hidden end
end
-- Addons for the "still show" list: every loaded one, the hidden first.
function System:QuietChoices()
    local show=self:Settings().quietShow or {}
    local last=FT.db.quietHidden or {}
    local list={}
    local count=C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i=1,count do
        local name,title=C_AddOns.GetAddOnInfo(i)
        if name and name~=(FT.name or "ForeverTools") and C_AddOns.IsAddOnLoaded(i) then
            local nice=(type(title)=="string" and title~="" and title:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")) or name
            local n=last[name]
            list[#list+1]={value=name,sortHidden=n and 0 or 1,label=nice..(show[name] and "  |cff7fd98a(shown)|r" or (n and ("  |cffb4aa96(hid "..n..(n==1 and " line" or " lines")..")|r") or "")),
                tooltipTitle=nice,tooltip=show[name] and "Its login lines show. Click to hide them." or "Its login lines are hidden. Click to show them."}
        end
    end
    table.sort(list,function(a,b) if a.sortHidden~=b.sortHidden then return a.sortHidden<b.sortHidden end return a.label<b.label end)
    if #list==0 then list[1]={value="",label="No other addons loaded",disabled=true} end
    return list
end
System:QuietStart()
do
    local f=CreateFrame("Frame"); f:RegisterEvent("ADDON_LOADED"); f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent",function(owner,event,name)
        if event=="ADDON_LOADED" then
            if name==(FT.name or "ForeverTools") then C_Timer.After(0,function() System:QuietReady() end) end
            return
        end
        owner:UnregisterAllEvents()
        C_Timer.After(10,function() System:QuietStop() end)
    end)
end
-- /ft chatdebug: is the game's chat still its own? Run it when whispers
-- stop going out, before /reload: "tainted by" names who touched it.
function System:ChatDebug()
    local sys=self:Settings()
    local chat=FT.modules.Chat and FT.modules.Chat:Settings() or {}
    print("Keep chat: "..tostring(chat.history==true).."  links: "..tostring(sys.chatLinks==true))
    local function check(label,owner,key)
        if not issecurevariable then return end
        local ok,secure,by
        if owner then ok,secure,by=pcall(issecurevariable,owner,key) else ok,secure,by=pcall(issecurevariable,key) end
        if not ok then return end
        if secure then print("  "..label..": game's own") else print("  "..label..": |cffff8080tainted by "..tostring(by).."|r") end
    end
    for i=1,(NUM_CHAT_WINDOWS or 10) do local f=_G["ChatFrame"..i]; if f then check("ChatFrame"..i..".AddMessage",f,"AddMessage") end end
    for _,g in ipairs({"ACTIVE_CHAT_EDIT_BOX","LAST_ACTIVE_CHAT_EDIT_BOX","ChatEdit_SetLastTellTarget","ChatEdit_GetLastTellTarget","ChatEdit_SendText","ChatEdit_ParseText","ChatFrame_SendTell","SendChatMessage"}) do
        if _G[g]~=nil then check(g,nil,g) end
    end
    if C_ChatInfo then check("C_ChatInfo.SendChatMessage",C_ChatInfo,"SendChatMessage") end
    local box=ChatFrame1EditBox or (ChatFrame1 and ChatFrame1.editBox)
    if box then for _,k in ipairs({"chatType","tellTarget","channelTarget","lastTell","setText","text"}) do if rawget(box,k)~=nil then check("ChatFrame1EditBox."..k,box,k) end end end
    if ChatFrameUtil then for _,k in ipairs({"SetLastTellTarget","GetLastTellTarget","SendTell"}) do if ChatFrameUtil[k]~=nil then check("ChatFrameUtil."..k,ChatFrameUtil,k) end end end
    if FT.db and type(FT.db.blockedActions)=="table" and FT.db.blockedActions[1] then
        local b=FT.db.blockedActions[1]; print("Last block: "..tostring(b.day or "").." "..tostring(b.when).." "..tostring(b.func))
    end
end
local function usable(value)
    return (not issecretvalue or not issecretvalue(value)) and value~=nil
end
local function tooltipUnit(tip)
    if not tip.GetUnit then return end
    local ok,_,unit=pcall(tip.GetUnit,tip)
    if ok and usable(unit) and type(unit)=="string" then return unit end
end
local function displayedUnit(tip)
    local unit=tooltipUnit(tip)
    if unit then return unit end
    if not tip.IsTooltipType or not Enum or not Enum.TooltipDataType then return end
    local ok,isUnit=pcall(tip.IsTooltipType,tip,Enum.TooltipDataType.Unit)
    if not ok or isUnit~=true then return end
    local owner=tip.GetOwner and tip:GetOwner()
    for _=1,4 do
        if not owner then break end
        if usable(owner.unit) and type(owner.unit)=="string" then return owner.unit end
        owner=owner.GetParent and owner:GetParent()
    end
    return "mouseover"
end
local function safeCall(fn,unit)
    if not fn or not usable(unit) then return end
    local ok,a,b=pcall(fn,unit)
    if ok and usable(a) and (b==nil or usable(b)) then return a,b end
end
function System:Settings()
    if type(FT.db.system)~="table" then FT.db.system={} end
    local s=FT.db.system
    if s.spellID==nil then s.spellID=false end
    -- 1.11.0: seconds on target and focus auras, on unless turned off.
    if s.auraCountdown==nil then s.auraCountdown=true end
    if s.minimapIcons==nil then s.minimapIcons=false end
    -- Forever shows coordinates under the minimap by default; match that.
    if s.coordinates==nil then s.coordinates=true end
    if type(s.quietNoControl)~="boolean" then s.quietNoControl=true end
    if type(s.quietLogin)~="boolean" then s.quietLogin=true end
    -- New version notice: on at first (Lars, 2026-11-09).
    if type(s.versionCheck)~="boolean" then s.versionCheck=true end
    if type(s.gameMenuButton)~="boolean" then s.gameMenuButton=true end
    return s
end
function System:Apply()
    local s=self:Settings()
    if FT.modules.ChatLinks and FT.modules.ChatLinks.Apply then FT.modules.ChatLinks:Apply() end
    if FT.PowerGlow then FT.PowerGlow:Apply() end
    if FT.StealthShade then FT.StealthShade:Apply() end
    if FT.BuffTimes then FT.BuffTimes:Apply() end
    if FT.modules.TrackSwitch then FT.modules.TrackSwitch:Apply() end
    -- Forever's own option, rather than hiding an unrelated minimap region.
    if s.coordinates~=nil and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar then
        if C_CVar.GetCVar("minimapShowPlayerCoords")~=nil then C_CVar.SetCVar("minimapShowPlayerCoords",s.coordinates and "1" or "0") end
    elseif s.coordinates~=nil and GetCVar and SetCVar and GetCVar("minimapShowPlayerCoords")~=nil then
        SetCVar("minimapShowPlayerCoords",s.coordinates and "1" or "0")
    end
    FT:UpdateMinimap(); if FT.modules.MinimapIcons then FT.modules.MinimapIcons:Apply() end
    self:ApplyErrors()
    self:ApplyCombatLog()
    if FT.modules.KeyText then FT.modules.KeyText:Apply() end
    if FT.modules.SoftRes then FT.modules.SoftRes:Apply() end
    if FT.modules.MailAlts then FT.modules.MailAlts:Apply() end
    if FT.modules.ItemLock then FT.modules.ItemLock:Apply() end
    self:Refresh()
end
-- Combat logging (System > Combat logging). The game's own combat log
-- (LoggingCombat, the same as /combatlog) with advanced logging on, which
-- Warcraft Logs needs. Automatic: on when you enter a raid (or a dungeon),
-- off when you leave, but only a log we started ourselves is stopped; one you
-- started by hand keeps running. Checked on zone changes only: no cost in a fight.
function System:CanLog() return type(LoggingCombat)=="function" end
function System:Logging()
    if not self:CanLog() then return false end
    local ok,on=pcall(LoggingCombat)
    return ok and usable(on) and on==true
end
local function say(msg) print("|cffffd100ForeverTools:|r "..msg) end
function System:SetLogging(on,why)
    if not self:CanLog() then return end
    if on then
        -- Warcraft Logs needs advanced combat logging.
        -- (Read here: the gameOption helper is defined further down the file.)
        local get=(C_CVar and C_CVar.GetCVar) or GetCVar
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        local ok,value=false,nil
        if get then ok,value=pcall(get,"advancedCombatLogging") end
        if set and ok and type(value)=="string" and value~="1" then pcall(set,"advancedCombatLogging","1") end
    end
    if self:Logging()==on then
        if not on then FT.db.combatLogAuto=nil end
        return
    end
    pcall(LoggingCombat,on)
    FT.db.combatLogAuto=(on and why=="auto") or nil
    if on then say("Logging on. Saves to _forever_\\Logs\\WoWCombatLog.")
    else say("Logging off.") end
end
function System:ApplyCombatLog()
    local s=self:Settings()
    if not self:CanLog() then return end
    if (s.combatLog or FT.db.combatLogAuto) and not self.logEvents then
        self.logEvents=CreateFrame("Frame")
        for _,e in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA"}) do self.logEvents:RegisterEvent(e) end
        self.logEvents:SetScript("OnEvent",function()
            -- The instance type settles a moment after loading.
            FT:Coalesce("combatLogZone",function() System:CheckCombatLog() end,1)
        end)
    end
    self:CheckCombatLog()
end
function System:CheckCombatLog()
    local s=self:Settings()
    local _,kind=IsInInstance()
    local want=s.combatLog==true and (kind=="raid" or (kind=="party" and s.combatLogDungeons==true))
    if want then
        if not self:Logging() then self:SetLogging(true,"auto") end
    elseif FT.db.combatLogAuto then
        -- Only stop a log we started. "Left the instance" only when you did.
        if self:Logging() then self:SetLogging(false,(kind==nil or kind=="none") and "auto" or "setting") else FT.db.combatLogAuto=nil end
    end
    self:Refresh()
end
-- LayerSwap (another addon) turns its hosting on at every login. On a real
-- login (not a /reload) we switch it off through its own command, /ls off,
-- a few seconds after it has done that. Nothing else of it is touched.
function System:HasLayerSwap()
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LayerSwap")
    return loaded==true and type(SlashCmdList)=="table" and type(SlashCmdList.LAYERSWAP)=="function"
end
function System:LayerSwapLogin()
    if not self:Settings().layerSwapOff or not self:HasLayerSwap() then return end
    local db=rawget(_G,"LayerSwapDB")
    if type(db)~="table" or db.hosting~=true then return end
    -- Its own Host switch (Options > AddOns > LayerSwap) turns it off without
    -- a status report in chat; /ls off is the fallback (it prints a few lines).
    local box=rawget(_G,"LayerSwapOptionHost")
    local click=box and box.GetScript and box:GetScript("OnClick")
    if click and box.SetChecked then box:SetChecked(false); pcall(click,box) end
    if db.hosting==true then pcall(SlashCmdList.LAYERSWAP,"off") end
end
do
    local f=CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent",function(owner,_,isLogin)
        owner:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if isLogin~=true then return end
        C_Timer.After(5,function() if FT.dbReady then System:LayerSwapLogin() end end)
    end)
end
-- Error messages (On-screen info > Error messages). With the switch on, the
-- game's error text frame stops listening for errors and we listen instead:
-- an error we let through is handed to the frame's own handler, so it looks
-- and sounds exactly like the game's. Off: the frame listens again. Only an
-- unprotected frame's events change, so this is safe in combat too.
local KEEP={"ERR_INV_FULL","ERR_BAG_FULL","ERR_QUEST_LOG_FULL","ERR_NOT_ENOUGH_MONEY","ERR_ITEM_MAX_COUNT","ERR_TOO_MANY_ITEMS"}
function System:KeepError(message)
    if type(message)~="string" or not usable(message) then return false end
    for _,name in ipairs(KEEP) do local text=_G[name]; if type(text)=="string" and text==message then return true end end
    return false
end
function System:ApplyErrors()
    local frame=UIErrorsFrame
    if not frame or not frame.RegisterEvent then return end
    local s=self:Settings()
    local on=s.hideErrors==true
    if not self.errorEvents then
        if not on then return end
        self.errorEvents=CreateFrame("Frame")
        self.errorEvents:SetScript("OnEvent",function(_,event,...)
            local settings=self:Settings()
            local _,message=...
            local hide=settings.hideErrors==true and (not settings.errorsInCombat or InCombatLockdown()) and not self:KeepError(message)
            if hide then return end
            local handler=frame:GetScript("OnEvent")
            if handler then pcall(handler,frame,event,...) end
        end)
    end
    if self.hidingErrors==on then return end
    self.hidingErrors=on
    if on then
        frame:UnregisterEvent("UI_ERROR_MESSAGE"); self.errorEvents:RegisterEvent("UI_ERROR_MESSAGE")
    else
        self.errorEvents:UnregisterEvent("UI_ERROR_MESSAGE"); frame:RegisterEvent("UI_ERROR_MESSAGE")
    end
end
-- The switch lists. Each is a page of its group (see Hubs.lua): General and
-- Loot and merchant under System, Minimap and Quests and loot rolls under
-- On-screen info, Group role and Death glow under Combat, Keybind tools under
-- Keybinds. Each page is its own module for FT:OpenModule and search.
local pages={
    {key="SystemGeneral",sections={{"Messages","welcome"},{"Setup","setup"},{"Help","scriptErrors"}},title="General",hint="Messages, setup, reset and help.",items={
        {"welcome","Welcome message","welcome","A short \"ForeverTools loaded\" line at login."},
        {"quietLogin","Quiet login","Spell_Holy_Silence","Other addons' \"loaded\" and version lines are left out of chat when you log in or reload. Player and game chat always shows."},
        {"quietShow","Still show","INV_Misc_Note_01","Pick addons whose login lines you still want in chat. The list shows how many lines each one had hidden last time."},
        {"quietNoControl","Hide notices while you can't play","Ability_Mount_Wyvern_01","Notices wait on flight paths, in vehicles and cutscenes."},
        {"hiddenUIHint","Show key when interface is hidden","INV_Misc_Eye_01","Show which key brings the interface back after hiding it (Alt+Z)."},
        {"whatsNew","What's new after updates","INV_Misc_Note_05","Show what changed after an update."},
        {"gameMenuButton","Move elements in the game menu","Ability_Rogue_Sprint","A Move elements button (with the ForeverTools logo) in the game's own menu (Esc), under Macros."},
        {"versionCheck","Tell me when a new version is out","INV_Misc_Note_06","ForeverTools copies in your guild and group tell each other their version (a hidden addon message with only the version number). When someone has a newer one, you get a line in chat."},
        {"setup","First-time tour","INV_Misc_Book_09","Take the tour again, or continue where you paused."},
        {"reset","Reset all settings","reset","Everything back to off and reload. Profiles, macros and flight times are kept."},
        {"scriptErrors","Show Lua errors","errors","Show the game's Lua error pop-ups."},
        {"bugReport","Copy bug report","INV_Misc_Note_04","Version, game build, features and recent errors, ready to copy. Nothing is sent."},
    }},
    {key="SystemMinimap",sections={{"Buttons","minimap"},{"Herbs and minerals","trackSwitch"},{"Grouping","minimapIcons"},{"World map","mapTransport"}},title="Minimap",hint="ForeverTools button, coordinates, herbs and minerals, button grouping, world map points.",items={
        {"minimap","ForeverTools minimap button","map","Show the ForeverTools button. /ft always works."},
        {"coordinates","Minimap coordinates","INV_Misc_Spyglass_02","Show coordinates below the minimap."},
        {"minimapTarget","Show your target on the minimap","Ability_Hunter_SniperShot","Turns on the game's own \"Target\" minimap tracking: what you target shows on the minimap. The game saves it."},
        {"trackSwitch","Herbs and minerals","INV_Misc_Flower_02","Switch between both: the minimap swaps between Find Herbs and Find Minerals while you travel, so you see both. Keep one on: Find Herbs or Find Minerals is turned back on whenever it's off, for example after you die. Only the minimap tracking changes. Waits in fights, while casting or fishing, and on flights; switching also waits while looting, in dungeons and towns, and with your mouse over the minimap."},
        {"trackSwitchEvery","Switch every","INV_Misc_PocketWatch_01","How often it switches between them."},
        {"trackSwitchStill","Also while standing still","INV_Ore_Copper_01","Off: it waits while you stand still, so the minimap keeps showing what you stopped for."},
        {"minimapIcons","Group minimap buttons","INV_Misc_Bag_08","Put other addons' minimap buttons into one menu."},
        {"minimapIconsVertical","Grouped buttons","INV_Misc_Bag_08","Layout of the grouped buttons."},
        {"minimapRings","Rings on the minimap","map","Addon buttons that sit on the minimap (also the ones you keep there): gold like the game, or dark in your Skins border color. Needs Skins > Minimap on. The same choice as Skins > Minimap > Addon rings."},
        {"groupRings","Rings in the group","INV_Misc_Bag_08","Addon buttons inside the grouped buttons menu: gold or dark. Needs Skins > Minimap on."},
        {"minimapKeep","Keep on the minimap","INV_Misc_Map_01","Pick buttons that stay on the minimap, outside the group (for example one you use a lot)."},
        {"mapTransport","Boats, zeppelins and tram","INV_Misc_Map_01","Show docks, zeppelin and airship towers and the tram on the world map, and where each goes. Also in the map's filter menu (the funnel, top right)."},
        {"mapDungeons","Dungeon and raid entrances","INV_Misc_Key_10","Show dungeon and raid entrances on the world map, with their levels. Also in the map's filter menu (the funnel, top right)."},
        {"mapFlights","Flight masters","Ability_Mount_Wyvern_01","Show flight masters on maps where the game doesn't. Also in the map's filter menu (the funnel, top right)."},
        {"mapGatherMate","GatherMate in the map menu","INV_Misc_Herb_10","On when GatherMate is loaded on this character. Adds herbs, minerals, fishing and treasure to the world map's filter menu (the funnel, top right): turn each kind on or off, or hover one to pick single nodes (Copper Vein, Peacebloom...). Changes GatherMate's own settings, so the minimap follows too."},
    }},
    {key="SystemGameplay",title="Group role",hint="Your group role, set from your talents.",items={
        {"autoRole","Set role when joining a group","Ability_Warrior_DefensiveStance","Set your role from your talents when you join a group."},
    }},
    {key="SystemEffects",title="Screen effects",hint="Glows and shadows on your screen.",
        bigSections={{"Poised","poisedPreview","Your energy bar lights up when Poised is ready.","Spell_Nature_LightningShield"},
            {"Stealth shadows","stealthPreview","The edges of your screen darken while you are stealthed.","Spell_Shadow_Twilight"},
            {"Death glow","deathGlow","How the screen looks while you are dead or a ghost.","Spell_Holy_Resurrection"}},items={
        {"poisedPreview","Preview","Spell_Lightning_LightningBolt01","Shows the glow now, without Poised, until you turn it off.",only={ROGUE=true,DRUID=true}},
        {only={ROGUE=true,DRUID=true},"poisedGlow","Poised glow on energy bar","Spell_Nature_LightningShield","While Poised is up (your next Energy ability costs less), sparks and twinkling stars run over your energy bar. No need to look at your buffs. Only while you target an enemy, unless you turn on the option below."},
        {"poisedAlways","Also without an enemy target","Ability_Stealth","Shows the glow whenever Poised is up, not only while you target an enemy.",only={ROGUE=true,DRUID=true}},
        {"stealthPreview","Preview","Ability_Stealth","Shows the shadows now, without stealth, until you turn it off.",only={ROGUE=true,DRUID=true}},
        {only={ROGUE=true,DRUID=true},"stealthShade","Shadows while stealthed","Ability_Stealth","While you are in Stealth, Prowl or Shadowmeld, the edges of your screen sink into a dark shadow, so you always know you are hidden. Behind your whole interface; works in combat."},
        {"stealthStrength","Strength","Spell_Shadow_Twilight","How dark the shadow gets.",only={ROGUE=true,DRUID=true}},
        {"stealthDrift","Drifting shadows","Spell_Shadow_ShadowWard","The shadow slowly creeps in and out at the edges. Off: it stays still.",only={ROGUE=true,DRUID=true}},
        {"deathGlow","Death glow","Spell_Holy_Resurrection","The washed-out screen while dead. The game's own setting, for all characters."},
    }},
    {key="SystemQuests",sections={{"Quest tracker","objectives"},{"Loot rolls","lootMove"}},title="Quests and loot rolls",hint="Quest tracker at login, loot-roll position.",items={
        {"objectives","Quest tracker at login","INV_Misc_Note_01","How the quest tracker starts at login."},
        {"lootMove","Move loot rolls","move","Drag a sample loot roll. Stays movable with this window closed; click again or right-click the sample to lock."},
        {"lootDefault","Revert to default position","reset","Let the game place loot rolls again."},
    }},
    {key="SystemMerchant",sections={{"Looting","fastLoot"},{"Raid loot","softRes"},{"Selling","autoSell"},{"Repairing","autoRepair"},{"Mailbox","mailAlts"}},title="Loot, merchant and mail",hint="Faster looting, raid soft reserves, selling, repairing and mail.",items={
        {"fastLoot","Faster looting","INV_Misc_Bag_10","Take everything at once (with auto loot on)."},
        {"softRes","Soft reserves (custom)","INV_Misc_Note_06","A custom function for our guild website's lists, not for softres.it or other soft reserve sites. Who reserved which raid items: paste the list from the guild website, then see it on loot, in raid chat and on tooltips. Also /ft sr."},
        {"autoSell","Auto-sell grey items","INV_Misc_Coin_05","Sell grey items at merchants, 12 per visit so all can be bought back."},
        {"sellWhite","Also sell white gear","INV_Misc_Coin_03","Also sell white weapons and armor you don't need. Can be bought back."},
        {"autoRepair","Auto-repair","Trade_BlackSmithing","Repair your gear at merchants."},
        {"guildRepair","Use guild funds for repairs first","INV_Shirt_GuildTabard_01","Use guild repair money when allowed."},
        {"mailAlts","Mailbox: only suggest my alts","INV_Letter_15","When you type a name to send mail to, only your own characters on this realm are suggested, not guildies first. A switch next to the To: box suggests everyone again when you need to, and an arrow beside it lists your alts to pick from."},
        {"mailGold","Mailbox: gold amount as subject","INV_Misc_Coin_01","Sending only money to one of your alts fills in the subject with the amount (12g 50s). Only an empty subject is filled; type your own any time."},
    }},
    {key="SystemCombatLog",title="Combat logging",hint="Log your fights for Warcraft Logs.",items={
        {"combatLog","Log raids automatically","INV_Misc_Book_11","Starts the game's combat log when you enter a raid and stops it when you leave. Advanced combat logging (needed by Warcraft Logs) is turned on with it. The log is saved in your game folder: _forever_\\Logs\\WoWCombatLog. Upload it with the Warcraft Logs uploader."},
        {"combatLogDungeons","Also in dungeons","INV_Misc_Key_10","Also log in dungeons, not only raids."},
        {"combatLogNow","Log now","INV_Misc_Note_02","Start or stop the combat log right now, anywhere. The same as typing /combatlog."},
    }},
    {key="SystemAddons",title="Other addons",hint="Small fixes for other addons you use.",items={
        {"layerSwapOff","Stop LayerSwap hosting when I log in","INV_Misc_GroupLooking","LayerSwap turns its hosting on every time you log in. With this on, ForeverTools turns it off right after you log in (the same as typing /ls off). Turn hosting on again in LayerSwap whenever you like: it stays on until you log out. A /reload changes nothing."},
    }},
    {key="SystemBuffTimes",title="Buff times",hint="How the time left on your buffs is shown.",items={
        {"buffMinutes","Show minutes on my buffs","INV_Misc_PocketWatch_01","Past an hour the game rounds your buffs to hours (2 h). With this on they show hours and minutes (2h 23m), like the Well Rested buff from a sleeping bag. Under an hour the game's own time stays."},
        {"auraCountdown","Time left on target and focus auras","Ability_Gouge","Your target's and focus's buffs and debuffs show the seconds left on their icons (your stuns, for example), the way nameplates do. The game counts them itself, also in fights."},
        {"buffTipTime","Exact time left in the buff's tooltip","INV_Misc_Note_02","Hover one of your buffs or debuffs to see exactly how long it has left (2 h 23 min, or 14 min 30 s in the last hour). Keeps counting while you hover. Works with or without minutes on the buffs."},
    }},
    {key="SystemErrors",title="Error messages",hint="Red text when an action fails.",items={
        {"hideErrors","Hide error messages","Ability_Rogue_Disguise","Hide the red error text (Out of range, Not enough rage...). Bag full and similar still show."},
        {"errorsInCombat","Only hide them in a fight","Ability_DualWield","Hide them only in combat."},
    }},
    {key="SystemKeybinds",sections={{"Keybinds","quickKeybind"},{"Action bars","actionFade"}},title="Keybind tools and action bars",hint="Bind by hovering, short key text, earlier keybinds back, and action bars on mouseover.",items={
        {"quickKeybind","Quick keybind mode (/kb)","keybind","Hover an action button and press a key to bind it. Esc unbinds. Also /kb."},
        {"shortKeys","Short key text","keybind","The key on your action buttons, short: S1 for Shift-1, C6 for Ctrl-6, M5 for mouse button 5, SM5 for Shift + mouse button 5, WU for mouse wheel up."},
        {"keyX","Key text left / right","keybind","Slide the key text on your action buttons left or right, a point at a time."},
        {"keyY","Key text up / down","keybind","Slide the key text on your action buttons up or down, a point at a time."},
        {"backups","Backups and restore","profiles","Put back earlier keybinds, action bars and spell binds, or save a copy now. Hover one to see what it restores."},
        {"actionFade","Action bars on mouseover","mouseover","Hide chosen action bars until your mouse is over them. They show while you drag a spell onto them too. Turn off bars here, or turn them on if they are off in the game's options."},
    }},
}
System.pages=pages
local toggles={trackSwitchStill=true,auraCountdown=true,buffMinutes=true,buffTipTime=true,poisedGlow=true,poisedAlways=true,poisedPreview=true,gameMenuButton=true,versionCheck=true,minimapTarget=true,hiddenUIHint=true,fastLoot=true,welcome=true,whatsNew=true,minimap=true,coordinates=true,minimapIcons=true,autoRole=true,shortKeys=true,lootMove=true,autoSell=true,autoRepair=true,guildRepair=true,mailAlts=true,mailGold=true,sellWhite=true,scriptErrors=true,deathGlow=true,hideErrors=true,errorsInCombat=true,quietNoControl=true,mapTransport=true,mapDungeons=true,mapFlights=true,mapGatherMate=true,stealthShade=true,stealthDrift=true,stealthPreview=true,combatLog=true,combatLogDungeons=true,combatLogNow=true,layerSwapOff=true,quietLogin=true}
-- Switches that are the game's own settings: read and written directly,
-- never stored by ForeverTools. "Unavailable" when the game has no such setting.
local gameOptions={scriptErrors="scriptErrors",deathGlow="ffxDeath"}
local function gameOption(name)
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    if not getter then return nil end
    local ok,value=pcall(getter,name)
    if ok and type(value)=="string" then return value end
end
System.gameOptions=gameOptions
-- The game's minimap tracking for your target (Enum.MinimapTrackingFilter.Target):
-- its index in the tracking list, or nil when this game version has none.
local TARGET_FILTER=Enum and Enum.MinimapTrackingFilter and Enum.MinimapTrackingFilter.Target
if type(TARGET_FILTER)~="number" or TARGET_FILTER==0 then TARGET_FILTER=16384 end
function System:TargetTracking()
    local M=C_Minimap
    if not (M and M.GetNumTrackingTypes and M.GetTrackingFilter and M.GetTrackingInfo) then return nil end
    local ok,n=pcall(M.GetNumTrackingTypes); if not ok or type(n)~="number" then return nil end
    for i=1,n do
        local okF,f=pcall(M.GetTrackingFilter,i)
        local okI,info=pcall(M.GetTrackingInfo,i)
        info=okI and type(info)=="table" and info or nil
        if (okF and type(f)=="table" and f.filterID==TARGET_FILTER) or (info and info.name==(MINIMAP_TRACKING_TARGET or "Target")) then
            return i,info and info.active==true
        end
    end
end
-- /ft trackdebug: every minimap tracking type the game lists.
function System:TrackingDebug()
    local M=C_Minimap
    print("ForeverTools "..tostring(FT.version).." minimap tracking")
    if not M or not M.GetNumTrackingTypes then print("C_Minimap.GetNumTrackingTypes: missing"); return end
    local ok,n=pcall(M.GetNumTrackingTypes); print("types: "..tostring(n))
    local cv=(C_CVar and C_CVar.GetCVar) or GetCVar
    if cv then print("minimapTrackingShowAll="..tostring(cv("minimapTrackingShowAll"))) end
    if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.IngameTrackingDisabled then
        local okR,r=pcall(C_GameRules.IsGameRuleActive,Enum.GameRule.IngameTrackingDisabled); print("tracking disabled rule: "..tostring(okR and r))
    end
    for i=1,(ok and type(n)=="number" and n or 0) do
        local okF,f=pcall(M.GetTrackingFilter,i); local okI,info=pcall(M.GetTrackingInfo,i)
        f=okF and type(f)=="table" and f or {}; info=okI and type(info)=="table" and info or {}
        print(("%d %s filter=%s spell=%s active=%s"):format(i,tostring(info.name),tostring(f.filterID),tostring(f.spellID),tostring(info.active)))
    end
    print("target tracking index: "..tostring((self:TargetTracking())))
end
function System:Values()
    local s=self:Settings()
    local getter=(C_CVar and C_CVar.GetCVar) or GetCVar
    local coords=s.coordinates
    if coords==nil then coords=not getter or getter("minimapShowPlayerCoords")=="1" end
    return {welcome=FT.db.welcome==true,whatsNew=s.hideWhatsNew~=true,minimap=FT.db.minimapEnabled~=false,coordinates=coords,
        minimapTarget=select(2,self:TargetTracking())==true,minimapIcons=s.minimapIcons==true,lootMove=FT.modules.LootRoll.moving==true,scriptErrors=gameOption("scriptErrors")=="1",deathGlow=gameOption("ffxDeath")~="0",
        hiddenUIHint=s.hiddenUIHint==true,poisedGlow=s.poisedGlow==true,poisedAlways=s.poisedAlways==true,poisedPreview=FT.PowerGlow and FT.PowerGlow.preview==true,autoRole=s.autoRole==true,shortKeys=s.shortKeys==true,fastLoot=s.fastLoot==true,autoSell=s.autoSell==true,sellWhite=s.sellWhite==true,autoRepair=s.autoRepair==true,guildRepair=s.guildRepair==true,mailAlts=s.mailAlts==true,mailGold=s.mailGold==true,
        hideErrors=s.hideErrors==true,errorsInCombat=s.errorsInCombat==true,quietNoControl=s.quietNoControl~=false,versionCheck=s.versionCheck~=false,gameMenuButton=s.gameMenuButton~=false,mapTransport=s.mapTransport==true,mapDungeons=s.mapDungeons==true,mapFlights=s.mapFlights==true,mapGatherMate=s.mapGatherMate~=false,stealthShade=s.stealthShade==true,stealthDrift=s.stealthDrift~=false,stealthPreview=FT.StealthShade and FT.StealthShade.preview==true,
        combatLog=s.combatLog==true,combatLogDungeons=s.combatLogDungeons==true,combatLogNow=self:Logging(),
        layerSwapOff=s.layerSwapOff==true,quietLogin=s.quietLogin~=false,
        buffMinutes=s.buffMinutes==true,buffTipTime=s.buffTipTime==true,auraCountdown=s.auraCountdown==true,
        trackSwitch=FT.modules.TrackSwitch and FT.modules.TrackSwitch:Mode() or "off",trackSwitchStill=s.trackSwitchStill==true}
end
function System:Refresh()
    if not self.buttons then return end
    local values=self:Values()
    for key,button in pairs(self.buttons) do
        if toggles[key] then
            local missing=(gameOptions[key] and gameOption(gameOptions[key])==nil) or (key=="minimapTarget" and self:TargetTracking()==nil)
            button.label:SetText(button.title..": "..(missing and "Unavailable" or (values[key] and "On" or "Off")))
            FT:SetSelected(button,values[key])
            if gameOptions[key] or key=="minimapTarget" then button:SetEnabled(not missing); button:SetAlpha(missing and .45 or 1) end
        end
        if key=="minimapRings" or key=="groupRings" then
            local a=FT.modules.IconStyles:Area("minimap")
            local v=key=="minimapRings" and a.addonRings or (a.groupRings==nil and a.addonRings or a.groupRings)
            button.label:SetText((key=="minimapRings" and "Rings on the minimap: " or "Rings in the group: ")..(v=="dark" and "Dark" or "Gold"))
            if key=="groupRings" then button:SetAlpha(values.minimapIcons and 1 or .45) end
        end
        if key=="quietShow" then
            local n=0; for _ in pairs(self:Settings().quietShow or {}) do n=n+1 end
            button.label:SetText("Still show: "..(n==0 and "None" or (n==1 and "1 addon" or (n.." addons"))))
            button:SetAlpha(values.quietLogin and 1 or .45)
        end
        if key=="minimapKeep" then
            local n=0; for _ in pairs(FT.modules.MinimapIcons:Kept()) do n=n+1 end
            button.label:SetText("Keep on the minimap: "..(n==0 and "None" or (n==1 and "1 button" or (n.." buttons"))))
            button:SetAlpha(values.minimapIcons and 1 or .45)
        end
        if key=="minimapIconsVertical" then
            local vertical=self:Settings().minimapIconsVertical==true
            button.label:SetText("Grouped buttons: "..(vertical and "Vertical" or "Horizontal"))
            button:SetAlpha(values.minimapIcons and 1 or .45)
        end
        -- Greyed while the setting it needs is off; clicking turns both on.
        if key=="guildRepair" then button:SetAlpha(values.autoRepair and 1 or .45) end
        if key=="sellWhite" then button:SetAlpha(values.autoSell and 1 or .45) end
        if key=="mapGatherMate" and not rawget(_G,"GatherMate2") then button:SetAlpha(.45); button.label:SetText(button.title..": GatherMate not loaded") end
        if key=="mapGatherMate" then s.mapGatherMate=s.mapGatherMate==false; self:Apply(); return end
    if key=="trackSwitchStill" then button:SetAlpha(values.trackSwitch=="swap" and 1 or .45) end
        if key=="trackSwitchEvery" then
            local T=FT.modules.TrackSwitch
            button.label:SetText("Switch every: "..(T and T:EveryText() or "3 seconds"))
            button:SetAlpha(values.trackSwitch=="swap" and 1 or .45)
        end
        if key=="trackSwitch" then
            local T=FT.modules.TrackSwitch
            local mode=values.trackSwitch
            local text=({off="Off",swap="Switch between both",herbs="Keep Find Herbs on",minerals="Keep Find Minerals on"})[mode] or "Off"
            if mode~="off" and T and not T:Known(mode) then text=text.." (spell not known)" end
            button.label:SetText(button.title..": "..text)
        end
        if key=="errorsInCombat" then button:SetAlpha(values.hideErrors and 1 or .45) end
        if key=="combatLogDungeons" then button:SetAlpha(values.combatLog and 1 or .45) end
        if key=="layerSwapOff" and not self:HasLayerSwap() then button:SetAlpha(.45); button.label:SetText(button.title..": LayerSwap not installed") end
        if key=="combatLogNow" then local ok=self:CanLog(); button:SetEnabled(ok); button:SetAlpha(ok and 1 or .45); if not ok then button.label:SetText(button.title..": Unavailable") end end
        if key=="backups" then
            button.label:SetText("Backups and restore ("..FT.modules.Backups:Count()..")")
        end
        if key=="lootDefault" then
            local custom=FT.modules.LootRoll:Settings().custom==true
            button:SetEnabled(custom); button:SetAlpha(custom and 1 or .45)
        end
        if key=="leveling" then
            local leveling=FT.modules.Leveling
            button.label:SetText("Leveling stats: "..(leveling and leveling:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="fps" then
            local fps=FT.modules.QualityOfLife
            button.label:SetText("FPS counter: "..(fps and fps.Settings and fps:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="keyX" or key=="keyY" then
            local v=tonumber(self:Settings()[key]) or 0
            local words=key=="keyX" and (v<0 and " left" or v>0 and " right" or "") or (v<0 and " down" or v>0 and " up" or "")
            button.label:SetText((key=="keyX" and "Key text left / right: " or "Key text up / down: ")..(v==0 and "Game's spot" or (math.abs(v)..words)))
        end
        if key=="stealthStrength" then
            local v=FT.StealthShade and FT.StealthShade:Settings().stealthStrength or "medium"
            button.label:SetText("Strength: "..({light="Light",medium="Medium",strong="Strong"})[v])
        end
        if key=="objectives" then
            local mode=FT.modules.QuestTracker and FT.modules.QuestTracker:Mode() or "default"
            button.label:SetText("Quest tracker at login: "..({default="Game's default",collapsed="Collapsed",open="Open",hidden="Always hidden"})[mode])
        end
        if key=="rareAlert" then
            local rare=FT.modules.RareAlert
            button.label:SetText("Rare alerts: "..(rare and rare:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="threat" then
            local threat=FT.modules.Threat; local t=threat and threat:Settings()
            button.label:SetText("Threat meter: "..(t and (t.enabled or t.text) and "On" or "Off").." — settings")
        end
        if key=="actionFade" then
            local fade=FT.modules.ActionFade; local n=fade and fade:Count() or 0
            button.label:SetText("Action bars on mouseover: "..(n>0 and (n.." bar"..(n>1 and "s" or "")) or "Off").." — settings")
        end
        if key=="sellMarks" then
            local marks=FT.modules.SellMarks
            button.label:SetText("Always-sell marks: "..(marks and marks:On() and ("On ("..marks:Count()..")") or "Off").." — settings")
        end
        if key=="smartKey" then
            local smart=FT.modules.SmartKey
            button.label:SetText("Smart interact key: "..(smart and smart:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="spellBinds" then
            local binds=FT.modules.SpellBinds
            button.label:SetText("Spell binds: "..(binds and binds:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="totems" then
            local totems=FT.modules.Totems
            local ts=totems and totems:Settings()
            button.label:SetText("Totems: "..(ts and (ts.range or ts.leftBehind) and "On" or "Off").." — settings")
        end
        if key=="wheelCasting" then
            local wheel=FT.modules.CustomKeybinds
            button.label:SetText("Mouse-wheel casting: "..(wheel and wheel:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="flightTimer" then
            local flight=FT.modules.FlightTimer
            button.label:SetText("Flight timer: "..(flight and flight:Settings().enabled and "On" or "Off").." — settings")
        end
        if key=="autoRole" then
            local reminder=FT.modules.BuffReminder
            if reminder then
                local current=reminder:CurrentSpec()
                for _,spec in ipairs(reminder:TalentSpecs()) do
                    if spec.name==current then button.icon:SetTexture(spec.icon);break end
                end
            end
        end
    end
    -- The sidebar of an open switch page shows the new state too.
    if FT.RefreshDock then
        for _,page in ipairs(pages) do
            local module=FT.modules[page.key]
            if module and module.frame and module.frame:IsShown() then FT:RefreshDock(module.frame) end
        end
    end
end
-- Settings that only work with another one on.
local SYSTEM_NEEDS={sellWhite="autoSell",guildRepair="autoRepair",errorsInCombat="hideErrors",combatLogDungeons="combatLog"}
function System:Click(key)
    if key=="minimapIcons" then FT.modules.MinimapIcons:Toggle();return end
    if key=="minimapIconsVertical" then FT.modules.MinimapIcons:ToggleVertical();return end
    if (key=="mapDungeons" or key=="mapTransport" or key=="mapFlights") and FT.MapPins then FT.MapPins:Toggle(key); self:Apply(); return end
    if key=="quietShow" then
        local button=self.buttons.quietShow; local s=self:Settings()
        button.options=function() return self:QuietChoices() end
        button.value=nil; button.menuWidth=math.max(button:GetWidth(),280)
        button.onSelect=function(value)
            if value=="" then return end
            s.quietShow=s.quietShow or {}; s.quietShow[value]=not s.quietShow[value] or nil; self:Refresh()
        end
        FT:ShowChoices(button); return
    end
    if key=="minimapKeep" then
        local button=self.buttons.minimapKeep; local I=FT.modules.MinimapIcons
        if I.active then I:Scan() end
        button.options=function() return I:KeepChoices() end
        button.value=nil; button.menuWidth=math.max(button:GetWidth(),260)
        button.onSelect=function(value) I:ToggleKeep(value); self:Refresh() end
        FT:ShowChoices(button); return
    end
    if key=="flightTimer" then FT:OpenModule("FlightTimer");return end
    if key=="fps" then FT:OpenModule("QualityOfLife");return end
    if key=="rareAlert" then FT:OpenModule("RareAlert");return end
    if key=="threat" then FT:OpenModule("Threat");return end
    if key=="totems" then FT:OpenModule("Totems");return end
    if key=="spellBinds" then FT:OpenModule("SpellBinds");return end
    if key=="smartKey" then FT:OpenModule("SmartKey");return end
    if key=="sellMarks" then FT:OpenModule("SellMarks");return end
    if key=="actionFade" then FT:OpenModule("ActionFade");return end
    if key=="softRes" then FT:OpenModule("SoftRes");return end
    if key=="wheelCasting" then FT:OpenModule("CustomKeybinds");return end
    if key=="leveling" then FT:OpenModule("Leveling");return end
    if key=="movers" then FT:OpenModule("Movers");return end
    if key=="bugReport" then FT.modules.BugReport:Open();return end
    if key=="quickKeybind" then FT.modules.QuickBind:Open();return end
    if key=="backups" then
        if not self.buttons.backups then FT:OpenModule("SystemKeybinds") end
        if self.buttons.backups then FT.modules.Backups:Show(self.buttons.backups) end
        return
    end
    if key=="setup" then FT.modules.Onboarding:ShowSetup(true);return end
    if key=="reset" then FT.modules.Profiles:ResetSettings();return end
    if key=="lootMove" then FT.modules.LootRoll:ToggleMove(); return end
    if key=="objectives" then
        local button=self.buttons.objectives
        button.options=function()
            local icon="Interface\\Icons\\INV_Misc_Note_01"
            return {
                {value="default",label="Default",icon=icon,tooltip="The game's own behavior."},
                {value="collapsed",label="Collapsed on login",icon=icon,tooltip="Collapsed after every login."},
                {value="open",label="Open on login",icon=icon,tooltip="Open after every login."},
                {value="hidden",label="Hidden",icon=icon,tooltip="Keep the tracker off the screen."},
            }
        end
        button.value=FT.modules.QuestTracker:Mode()
        button.menuWidth=button:GetWidth()
        button.onSelect=function(value)
            self:Settings().objectives=value~="default" and value or nil
            FT.modules.QuestTracker:Apply(); self:Refresh()
        end
        FT:ShowChoices(button); return
    end
    if key=="lootDefault" then FT.modules.LootRoll:UseDefault(); self:Refresh(); return end
    if key=="keyX" or key=="keyY" then self:Settings()[key]=nil; self:Apply(); return end
    if key=="minimapTarget" then
        local index,on=self:TargetTracking()
        if index and C_Minimap.SetTracking then pcall(C_Minimap.SetTracking,index,not on) end
        self:Refresh()
        -- The game updates its tracking a moment later: look again, and say
        -- so when it did not take the change.
        C_Timer.After(.5,function()
            local _,now=self:TargetTracking(); self:Refresh()
            if index and now==on then FT:Toast("The game did not change its Target tracking. Try the game's own tracking menu on the minimap.",5)
            elseif now then FT:Toast("Target tracking on: your target shows on the minimap when it is close.",4) end
        end)
        return
    end
    if gameOptions[key] then
        local name=gameOptions[key]
        local set=(C_CVar and C_CVar.SetCVar) or SetCVar
        local now=gameOption(name)
        -- Anything but "0" counts as on, the way the game reads it.
        if set and now~=nil then pcall(set,name,now~="0" and "0" or "1") end
        self:Refresh();return
    end
    local s=self:Settings()
    if key=="combatLogNow" then self:SetLogging(not self:Logging(),"manual"); self:Refresh(); return end
    if key=="layerSwapOff" then
        s.layerSwapOff=not (s.layerSwapOff==true); self:Refresh()
        -- Turned on while LayerSwap is hosting: offer to switch it off now,
        -- no login needed.
        local db=rawget(_G,"LayerSwapDB")
        if s.layerSwapOff and self:HasLayerSwap() and type(db)=="table" and db.hosting==true then
            FT:Confirm("LayerSwap is hosting right now.\nTurn its hosting off now?\n(No reload needed.)",function() System:LayerSwapLogin() end)
        end
        return
    end
    if key=="stealthPreview" then
        if FT.StealthShade then FT.StealthShade:TogglePreview() end
        self:Refresh(); return
    end
    if key=="poisedPreview" then
        local G=FT.PowerGlow; if G then G.preview=not G.preview; G:Check() end
        self:Refresh(); return
    end
    if key=="trackSwitchStill" then
        s.trackSwitchStill=not (s.trackSwitchStill==true)
        if s.trackSwitchStill and FT.modules.TrackSwitch and FT.modules.TrackSwitch:Mode()~="swap" then s.trackMode="swap"; s.trackSwitch=nil end
        self:Apply(); return
    end
    if key=="welcome" then FT.db.welcome=FT.db.welcome~=true
    elseif key=="minimap" then FT.db.minimapEnabled=FT.db.minimapEnabled==false
    elseif key=="whatsNew" then s.hideWhatsNew=not (s.hideWhatsNew==true)
    elseif key=="coordinates" then
        if s.coordinates==nil then local get=(C_CVar and C_CVar.GetCVar) or GetCVar; s.coordinates=not get or get("minimapShowPlayerCoords")=="1" end
        s.coordinates=not s.coordinates
    else
        s[key]=not (s[key]==true)
        -- A setting that only works with another one turns that one on too.
        local parent=SYSTEM_NEEDS[key]
        if s[key] and parent then s[parent]=true end
    end
    self:Apply()
end
-- Settings for some classes only (only={ROGUE=true}) are left out for others.
local function forMe(entry)
    if not entry.only then return true end
    local _,class=UnitClass("player")
    return class==nil or entry.only[class]==true
end
local function buildPage(page)
    local module={}
    function module:Open()
        if not self.frame then
            local items={}
            for _,entry in ipairs(page.items) do if forMe(entry) then items[#items+1]=entry end end
            local height=62+34+#items*40+22
            -- As wide as the other pages of its group.
            local hub=FT.HubOf and FT:HubOf(page.key)
            local width=hub and hub.width or 520
            self.frame=FT:Window("ForeverTools"..page.key,page.title,width,height)
            local hint=FT:Label(self.frame,page.hint or "",12); hint:SetPoint("TOPLEFT",24,-66); hint:SetWidth(width-48); hint:SetTextColor(.66,.59,.48)
            if hint.SetWordWrap then hint:SetWordWrap(true) end
            for i,entry in ipairs(items) do
                local key=entry[1]
                local b=FT:QuietButton(self.frame,entry[2],width-48,32,entry[3]); b.title=entry[2]
                b:SetPoint("TOPLEFT",24,-62-34-(i-1)*40); System.buttons[key]=b
                b:SetScript("OnClick",function() System:Click(key) end)
                FT:Tooltip(b,entry[2],entry[4])
                -- Settings with a few choices open their list (no click-to-cycle).
                if key=="stealthStrength" then
                    FT:MakeChoice(b,FT.StealthShade.strengths,
                        function() return FT.StealthShade:Settings().stealthStrength end,
                        function(value) local st=System:Settings(); st.stealthStrength=value; st.stealthShade=true; System:Apply(); System:Refresh() end)
                elseif key=="trackSwitch" then
                    FT:MakeChoice(b,{{"off","Off","Leave the minimap tracking alone."},{"swap","Switch between both","Find Herbs and Find Minerals take turns while you travel."},{"herbs","Keep Find Herbs on","Turned back on whenever it's off, for example after you die."},{"minerals","Keep Find Minerals on","Turned back on whenever it's off, for example after you die."}},
                        function() return FT.modules.TrackSwitch and FT.modules.TrackSwitch:Mode() or "off" end,
                        function(value) local st=System:Settings(); st.trackMode=value; st.trackSwitch=nil; System:Apply() end)
                elseif key=="trackSwitchEvery" then
                    FT:MakeChoice(b,FT.modules.TrackSwitch and FT.modules.TrackSwitch.EVERY or {{3,"3 seconds"}},
                        function() return FT.modules.TrackSwitch and FT.modules.TrackSwitch:Every() or 3 end,
                        function(value) local st=System:Settings(); st.trackSwitchEvery=value~=3 and value or nil; st.trackMode="swap"; st.trackSwitch=nil; System:Apply() end)
                elseif key=="objectives" then
                    FT:MakeChoice(b,{{"default","Game's default","The game decides, as without ForeverTools."},{"collapsed","Collapsed","Collapsed after every login."},{"open","Open","Open after every login."},{"hidden","Always hidden","Keep the tracker off the screen."}},
                        function() return FT.modules.QuestTracker:Mode() end,
                        function(value) System:Settings().objectives=value~="default" and value or nil; FT.modules.QuestTracker:Apply(); System:Refresh() end)
                elseif key=="keyX" or key=="keyY" then
                    -- A number with - and + beside it; click the number for 0.
                    b:SetWidth(width-48-76)
                    for i,delta in ipairs({-1,1}) do
                        local step=FT:QuietButton(self.frame,delta<0 and "-" or "+",34,32)
                        step:SetPoint("LEFT",b,"RIGHT",6+(i-1)*38,0)
                        step:SetScript("OnClick",function()
                            local s=System:Settings(); s[key]=math.max(-12,math.min(12,(tonumber(s[key]) or 0)+delta))
                            if s[key]==0 then s[key]=nil end; System:Apply()
                        end)
                        local words=key=="keyX" and (delta<0 and "left" or "right") or (delta<0 and "down" or "up")
                        FT:Tooltip(step,entry[2],"One point "..words..".")
                    end
                elseif key=="minimapRings" or key=="groupRings" then
                    local skins=FT.modules.IconStyles
                    local field=key=="minimapRings" and "addonRings" or "groupRings"
                    local function now() local a=skins:Area("minimap"); local v=a[field]; if field=="groupRings" and v==nil then v=a.addonRings end; return v=="dark" and "dark" or "game" end
                    FT:MakeChoice(b,{{"game","Gold","The game's gold ring."},{"dark","Dark","Your Skins border color."}},
                        now,
                        function(value)
                            local a=skins:Area("minimap")
                            -- The group follows the minimap until it has a choice of its own.
                            if field=="addonRings" and a.groupRings==nil then a.groupRings=a.addonRings or "game" end
                            a[field]=value; pcall(skins.Apply,skins); pcall(skins.AddonRings,skins)
                            if value=="dark" and skins:Settings().minimap~=true then FT:Toast("Turn on Skins > Minimap for dark rings.",4) end
                            System:Refresh()
                        end)
                end
                -- Grouping choices: picking one turns grouping on.
                if key=="groupRings" or key=="minimapKeep" or key=="minimapIconsVertical" then
                    b.ftNeeds={any=true,get=function() return System:Settings().minimapIcons==true end,on=function() System:Click("minimapIcons") end}
                end
                if key=="minimapKeep" then
                    b.options=function() return FT.modules.MinimapIcons:KeepChoices() end
                elseif key=="minimapIconsVertical" then
                    FT:MakeChoice(b,{{false,"Horizontal","Side by side, a new row after 6."},{true,"Vertical","One below the other."}},
                        function() return System:Settings().minimapIconsVertical==true end,
                        function(value) if (System:Settings().minimapIconsVertical==true)~=value then FT.modules.MinimapIcons:ToggleVertical() end end)
                end
            end
            -- One header per feature on pages that hold several, when more
            -- than one of them is for your class (else the page is just that one).
            if page.bigSections then
                local list={}
                for _,sec in ipairs(page.bigSections) do if System.buttons[sec[2]] and System.buttons[sec[2]]:GetParent()==self.frame then list[#list+1]={sec[1],System.buttons[sec[2]],sec[3],sec[4]} end end
                if #list>1 then FT:BigSections(self.frame,list,width-48) end
            end
            -- Headings between groups of settings.
            if page.sections then
                local list={}
                for _,sec in ipairs(page.sections) do if System.buttons[sec[2]] then list[#list+1]={sec[1],System.buttons[sec[2]]} end end
                FT:Sections(self.frame,list)
            end
            -- Headings push the rows down: the window grows to hold them all.
            local need=FT:ContentHeight(self.frame)
            if need>self.frame:GetHeight() then self.frame:SetHeight(math.ceil(need)) end
            if page.key=="SystemMinimap" then FT.minimapToggle=System.buttons.minimap end
            if page.key=="SystemGeneral" then FT.welcomeToggle=System.buttons.welcome end
        end
        System:Refresh(); self.frame:Show()
    end
    -- The switches are System's: refreshing the page refreshes them all.
    function module:Refresh() System:Refresh() end
    FT:RegisterModule(page.key,module)
end
-- "System" on the main menu is a group of pages (Hubs.lua).
System.redirect=true
function System:Open() FT:OpenHub("SystemHub") end
System.buttons={}
for _,page in ipairs(pages) do buildPage(page) end
function System:WatchSpellTooltip(tip)
    if not tip.ftSpellIDHooked and tip.HookScript then
        tip.ftSpellIDHooked=true
        tip:HookScript("OnTooltipCleared",function(owner) owner.ftSpellID=nil;owner.ftOtherIDs=nil;owner.ftSpellGeneration=(owner.ftSpellGeneration or 0)+1 end)
    end
end
function System:QueueSpellID(tip,id,kind)
    if not self:Settings().spellID or not tip or not usable(id) or type(id)~="number" then return end
    self:WatchSpellTooltip(tip)
    local generation=tip.ftSpellGeneration or 0
    C_Timer.After(0,function()
        if (tip.ftSpellGeneration or 0)==generation and tip:IsShown() then self:SpellID(tip,id,kind) end
    end)
end
-- An item tooltip's ID when the game hides it (fights): the bag slot,
-- action button or equipment slot the mouse is on, or the item link.
-- Item IDs seen out of a fight, so a fight's hidden tooltip can still show
-- one: by bag slot and by item name. Filled when bags change (out of a fight)
-- and from every item tooltip with a visible ID.
System.itemSlots,System.itemNames={},{}
local function tipName(tip)
    local name=tip.GetName and tip:GetName()
    local line=name and _G[name.."TextLeft1"]
    if not line or not line.GetText then return end
    local okT,text=pcall(line.GetText,line)
    if okT and usable(text) and type(text)=="string" and text~="" then return text end
end
function System:RememberItem(tip,id)
    if not (usable(id) and type(id)=="number" and id>0) then return end
    local name=tipName(tip)
    if name then self.itemNames[name]=id end
end
function System:ScanBagItems()
    if InCombatLockdown() or not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return end
    local slots={}
    for bag=-3,(NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5)+(NUM_BANKBAGSLOTS or 7) do
        local okN,count=pcall(C_Container.GetContainerNumSlots,bag)
        if okN and usable(count) and type(count)=="number" then
            for slot=1,count do
                local okI,id=pcall(C_Container.GetContainerItemID,bag,slot)
                if okI and usable(id) and type(id)=="number" then slots[bag..":"..slot]=id end
            end
        end
    end
    self.itemSlots=slots
end
do
    local f=CreateFrame("Frame")
    for _,e in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","BANKFRAME_OPENED","PLAYERBANKSLOTS_CHANGED","PLAYER_REGEN_ENABLED"}) do pcall(f.RegisterEvent,f,e) end
    f:SetScript("OnEvent",function() if FT.dbReady and System:Settings().spellID then FT:Coalesce("itemScan",function() System:ScanBagItems() end,.5) end end)
end
function System:ItemIDFromOwner(tip)
    local function ok(v) return usable(v) and type(v)=="number" and v>0 and v or nil end
    local debug=self.itemDebugUntil and GetTime()<self.itemDebugUntil
    local function say(...) if debug then print("|cffffd100FT item ID|r",...) end end
    local owner=tip.GetOwner and tip:GetOwner()
    say("owner",owner and owner.GetName and owner:GetName() or tostring(owner))
    if owner then
        -- Bag and bank slots.
        if owner.GetBagID and owner.GetID and C_Container and C_Container.GetContainerItemID then
            local okB,bag=pcall(owner.GetBagID,owner); local okS,slot=pcall(owner.GetID,owner)
            if okB and okS and ok(slot) and usable(bag) and type(bag)=="number" then
                local okI,id=pcall(C_Container.GetContainerItemID,bag,slot); id=okI and ok(id)
                say("bag",bag,slot,"game:",tostring(id),"saved:",tostring(self.itemSlots[bag..":"..slot]))
                if id then return id end
                id=self.itemSlots[bag..":"..slot]
                if id then return id end
            end
        end
        -- Action buttons with an item (or an item macro).
        local action=owner.action or (owner.GetAttribute and owner:GetAttribute("action"))
        if ok(action) and GetActionInfo then
            local okA,kind,id=pcall(GetActionInfo,action)
            if okA and kind=="item" and ok(id) then return id end
        end
        -- Character window slots.
        if owner.GetID and GetInventoryItemID and owner.GetName then
            local name=owner:GetName()
            if type(name)=="string" and name:find("^Character.+Slot$") then
                local okI,id=pcall(GetInventoryItemID,"player",owner:GetID()); id=okI and ok(id)
                if id then return id end
            end
        end
    end
    if tip.GetItem then
        local okL,_,link=pcall(tip.GetItem,tip)
        say("link",okL and usable(link) and tostring(link) or "hidden")
        if okL and usable(link) and type(link)=="string" then return tonumber(link:match("item:(%d+)")) end
    end
    local name=tipName(tip)
    say("name",tostring(name),"saved:",tostring(name and self.itemNames[name]))
    return name and self.itemNames[name]
end
-- A spell tooltip's ID when the game hides it (fights): the action button
-- the mouse is on, the tooltip's spell, or the IDs seen before the fight
-- (by name and rank), or your spellbook.
System.spellNames={}
local function tipRank(tip)
    local name=tip.GetName and tip:GetName()
    local line=name and _G[name.."TextRight1"]
    if not line or not line.GetText or (line.IsShown and not line:IsShown()) then return "" end
    local okT,text=pcall(line.GetText,line)
    return okT and usable(text) and type(text)=="string" and text or ""
end
function System:RememberSpell(tip,id)
    if not (usable(id) and type(id)=="number" and id>0) then return end
    local name=tipName(tip)
    if name then self.spellNames[name.."|"..tipRank(tip)]=id; self.spellNames[name]=self.spellNames[name] or id end
end
function System:SpellIDFromTip(tip)
    local function ok(v) return usable(v) and type(v)=="number" and v>0 and v or nil end
    local debug=self.itemDebugUntil and GetTime()<self.itemDebugUntil
    local function say(...) if debug then print("|cffffd100FT spell ID|r",...) end end
    local owner=tip.GetOwner and tip:GetOwner()
    if owner then
        local action=owner.action or (owner.GetAttribute and owner:GetAttribute("action"))
        if ok(action) and GetActionInfo then
            local okA,kind,id=pcall(GetActionInfo,action)
            say("action",action,tostring(okA and usable(kind) and kind),tostring(okA and usable(id) and id or "hidden"))
            if okA and usable(kind) and kind=="spell" and ok(id) then return id end
            local saved=self.actionSpells and self.actionSpells[action]
            say("saved action",tostring(saved and saved.id))
            if saved and not saved.name then return saved.id end
        end
    end
    if tip.GetSpell then
        local okS,_,id=pcall(tip.GetSpell,tip)
        say("tooltip spell",okS and usable(id) and tostring(id) or "hidden")
        if okS and ok(id) then return id end
    end
    local name=tipName(tip)
    if not name then say("name hidden"); return end
    local id=self.spellNames[name.."|"..tipRank(tip)]
    if not id then
        local reminder=FT.modules.BuffReminder
        local okL,learned=pcall(function() return reminder and reminder:Learned() end)
        local info=okL and type(learned)=="table" and learned[name]
        id=info and ok(info.value)
    end
    id=id or self.spellNames[name]
    say("name",name,tipRank(tip),"saved:",tostring(id))
    return id
end
-- Spells on your action bars and in your spellbook, read out of a fight,
-- so a fight's hidden tooltip can still show the ID. A slot that changes in
-- a fight is forgotten until the fight ends.
System.actionSpells,System.bookSpells={},{}
local function plainNumber(v) return usable(v) and type(v)=="number" and v>0 and v or nil end
local function spellName(id)
    local okN,name=pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or (GetSpellInfo and GetSpellInfo(id)) end)
    return okN and usable(name) and type(name)=="string" and name or nil
end
function System:ScanSpells()
    if InCombatLockdown() or not GetActionInfo then return end
    local actions={}
    for slot=1,180 do
        local okA,kind,id=pcall(GetActionInfo,slot)
        if okA and usable(kind) then
            if kind=="spell" and plainNumber(id) then actions[slot]={id=id}
            elseif kind=="macro" and GetMacroSpell and usable(id) then
                local okM,spell=pcall(GetMacroSpell,id)
                spell=okM and plainNumber(spell)
                -- A macro's spell can change with its conditions: kept with
                -- its name, used only when the tooltip shows that name.
                if spell then actions[slot]={id=spell,name=spellName(spell)} end
            end
        end
    end
    self.actionSpells=actions
    local book={}
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local okL,lines=pcall(C_SpellBook.GetNumSpellBookSkillLines)
        local total=0
        for i=1,(okL and plainNumber(lines) or 0) do
            local okI,info=pcall(C_SpellBook.GetSpellBookSkillLineInfo,i)
            if okI and type(info)=="table" and plainNumber(info.numSpellBookItems) then total=math.max(total,(info.itemIndexOffset or 0)+info.numSpellBookItems) end
        end
        for slot=1,total do
            local okS,info=pcall(C_SpellBook.GetSpellBookItemInfo,slot,0)
            if okS and type(info)=="table" and plainNumber(info.spellID) then book["0:"..slot]=info.spellID end
        end
    end
    self.bookSpells=book
end
do
    local f=CreateFrame("Frame")
    for _,e in ipairs({"PLAYER_ENTERING_WORLD","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","UPDATE_MACROS","SPELLS_CHANGED","PLAYER_REGEN_ENABLED"}) do pcall(f.RegisterEvent,f,e) end
    f:SetScript("OnEvent",function(_,event,slot)
        if not (FT.dbReady and System:Settings().spellID) then return end
        if InCombatLockdown() then
            if event=="ACTIONBAR_SLOT_CHANGED" then if plainNumber(slot) then System.actionSpells[slot]=nil else System.actionSpells={} end end
            return
        end
        FT:Coalesce("spellScan",function() System:ScanSpells() end,.5)
    end)
    -- After the game fills the tooltip: if it hid the ID, add the saved one.
    local function late(tip,id)
        if tip.ftSpellID or not FT.dbReady or not System:Settings().spellID then return end
        if plainNumber(id) then System:SpellID(tip,id) end
    end
    if GameTooltip and hooksecurefunc then
        if GameTooltip.SetAction then hooksecurefunc(GameTooltip,"SetAction",function(tip,slot)
            local saved=plainNumber(slot) and System.actionSpells[slot]
            if not saved or tip.ftSpellID then return end
            if saved.name then
                local name=tipName(tip)
                if name~=saved.name then return end
            end
            late(tip,saved.id)
        end) end
        if GameTooltip.SetSpellBookItem then hooksecurefunc(GameTooltip,"SetSpellBookItem",function(tip,slot,bank)
            if not plainNumber(slot) then return end
            local key=(bank==1 or bank=="pet") and nil or "0:"..slot
            late(tip,key and System.bookSpells[key])
        end) end
        if GameTooltip.SetSpellByID then hooksecurefunc(GameTooltip,"SetSpellByID",function(tip,id) late(tip,id) end) end
    end
end
function System:AuraSpellID(tip,id)
    if usable(id) then self:RememberSpell(tip,id) else id=self:SpellIDFromTip(tip) end
    if usable(id) then self:SpellID(tip,id) end
end
function System:ItemDebug()
    self.itemDebugUntil=GetTime()+60
    print("|cffffd100FT item ID|r for 60 s: hover items and spells in a fight; each hidden ID prints how it was looked for.")
end
function System:SpellID(tip,id,kind,building)
    if not self:Settings().spellID or not tip or tip.ftAddonHelp or not usable(id) or type(id)~="number" or id<=0 then return end
    kind=kind or "Spell"
    if kind=="Spell" and tip.ftSpellID==id then return end
    if kind~="Spell" and tip.ftOtherIDs and tip.ftOtherIDs[kind]==id then return end
    self:WatchSpellTooltip(tip)
    tip:AddLine(kind.." ID: "..id,.65,.65,.65)
    if kind=="Spell" then tip.ftSpellID=id else tip.ftOtherIDs=tip.ftOtherIDs or {};tip.ftOtherIDs[kind]=id end
    if not building and tip.Show then tip:Show() end
end
function System:TooltipClass(tip)
    -- Once our layout has rebuilt the tooltip, the class is already its own
    -- part. Blizzard refreshes tooltips while they are shown; adding the class
    -- again after the race would show it twice.
    if tip.ftPlayerLayout then return end
    if not tip.GetUnit or not UnitRace or not UnitIsPlayer then return end
    local unit=tooltipUnit(tip); if not unit or not safeCall(UnitIsPlayer,unit) then return end
    local race=safeCall(UnitRace,unit); local label,class=safeCall(UnitClass,unit)
    local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if not race or not label or not c then return end
    local color=string.format("|cff%02x%02x%02x",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5))
    local raceLine
    for i=2,(tip.NumLines and tip:NumLines() or 15) do
        local line=_G[(tip:GetName() or "GameTooltip").."TextLeft"..i]
        local text=line and line:GetText()
        if usable(text) and type(text)=="string" then
            local plain=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
            local first,last=plain:find(race,1,true)
            if first then
                local suffix=plain:sub(last+1)
                local trimmed=suffix:match("^%s*(.*)$")
                if trimmed:sub(1,#label)==label then suffix=trimmed:sub(#label+1) end
                line:SetText(plain:sub(1,last).." "..color..label.."|r"..suffix)
                raceLine=i
                break
            end
        end
    end
    if not raceLine then return end
    -- Some clients also supply a standalone class row. Remove only an exact
    -- class-name duplicate below the race; keep guilds, titles and other data.
    for i=raceLine+1,(tip.NumLines and tip:NumLines() or 15) do
        local prefix=tip:GetName() or "GameTooltip"
        local line=_G[prefix.."TextLeft"..i]
        local right=_G[prefix.."TextRight"..i]
        local text=line and line:GetText()
        local other=right and right:GetText()
        if usable(text) and (not other or usable(other)) and type(text)=="string" and (not other or other=="") then
            local plain=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
            if plain==label then line:SetText("") end
        end
    end
end
function System:TooltipLayout(tip)
    if tip.ftPlayerLayout or not tip.ClearLines or not tip.GetUnit or not GetGuildInfo then return end
    local unit=tooltipUnit(tip)
    if not unit or not safeCall(UnitIsPlayer,unit) then return end
    local prefix=tip:GetName() or "GameTooltip"
    local function plain(text) return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$") end
    local guild,guildRank=safeCall(GetGuildInfo,unit)
    local race=safeCall(UnitRace,unit)
    local class=safeCall(UnitClass,unit)
    -- Which line is Blizzard's level line? The one with the level number
    -- (any language, any word order); else the one naming the race. A class
    -- or race on a line of its own (some players' tooltips) is dropped too:
    -- both are parts of their own.
    local level=safeCall(UnitLevel,unit)
    local levelNumber=(type(level)=="number" and level>0) and tostring(level) or nil
    local function hasNumber(clean) return levelNumber and clean:find("%f[%d]"..levelNumber.."%f[%D]")~=nil end
    local rows={}; local details
    for i=1,tip:NumLines() do
        local left=_G[prefix.."TextLeft"..i]; local right=_G[prefix.."TextRight"..i]
        local text=left and left:GetText()
        local rightText=right and right:GetText()
        if text and not usable(text) then return end
        if rightText and not usable(rightText) then return end
        local clean=plain(text)
        local isGuild=guild and (clean==guild or clean=="<"..guild..">")
        if i==1 then rows[1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1}}
        elseif not details and not isGuild and (hasNumber(clean) or clean:find("??",1,true) or (race and clean:find(race,1,true))) then details=text
        elseif clean~="" and clean~=class and clean~=race and not isGuild and not clean:match("^Target:") then
            rows[#rows+1]={text=text,color=left.GetTextColor and {left:GetTextColor()} or {1,1,1},right=rightText,rightColor=right and right.GetTextColor and {right:GetTextColor()} or {1,1,1}}
        end
    end
    if not rows[1] then return end
    local tipModule=FT.modules.Tooltip
    local tipSettings=tipModule:Settings()
    local heading=rows[1].text
    local nameColor=rows[1].color
    local friendly=unit=="player"
    if UnitIsFriend then
        local ok,value=pcall(UnitIsFriend,"player",unit)
        if ok and usable(value) and value then friendly=true end
    end
    if UnitIsUnit then
        local ok,value=pcall(UnitIsUnit,"player",unit)
        if ok and usable(value) and value then friendly=true end
    end
    if friendly then
        heading=heading:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        nameColor={1,1,1}
    end
    local faction,factionName=safeCall(UnitFactionGroup,unit)
    -- The faction row ("Horde") becomes its own part; drop it from the extra rows.
    local factionText
    for i=#rows,2,-1 do
        local clean=plain(rows[i].text)
        if (factionName and clean==factionName) or (faction and clean==faction) then
            factionText=rows[i].text; table.remove(rows,i)
        end
    end
    -- Level, race and class are built from the unit itself, not cut out of
    -- Blizzard's line, so they show in every language and layout. Only extra
    -- words in brackets, such as "(Player)", are kept from the line.
    local parts={name=tipModule.hex(nameColor[1],nameColor[2],nameColor[3])..heading.."|r",faction=tipModule:FactionText(factionText and plain(factionText) or factionName,faction)}
    local detailText=details and plain(details) or ""
    local token=levelNumber
    if not token then
        -- Level hidden (??) or unreadable: take the number from the line, if any.
        token=detailText:find("??",1,true) and "??" or detailText:match("%f[%d]%d+%f[%D]") or "??"
    end
    local template=type(TOOLTIP_UNIT_LEVEL)=="string" and TOOLTIP_UNIT_LEVEL:find("%%[sd]") and TOOLTIP_UNIT_LEVEL or "Level %s"
    parts.level="|cffffffff"..template:gsub("%%d","%%s"):format(token).."|r"
    if race and race~="" then parts.race="|cffffffff"..race.."|r" end
    local label,classToken=safeCall(UnitClass,unit)
    if label then
        local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[classToken]
        parts.class=(c and tipModule.hex(c.r,c.g,c.b) or "|cffffffff")..label.."|r"
    end
    local suffix=detailText:match("%b()")
    parts.suffix=suffix and ("|cffffffff"..suffix.."|r") or nil
    if guild and guild~="" then
        local color=faction=="Horde" and PLAYER_FACTION_COLOR_HORDE or faction=="Alliance" and PLAYER_FACTION_COLOR_ALLIANCE
        local index=(PLAYER_FACTION_GROUP and PLAYER_FACTION_GROUP[faction]) or (faction=="Horde" and 0 or faction=="Alliance" and 1)
        color=color or (PLAYER_FACTION_COLORS and index and PLAYER_FACTION_COLORS[index])
        local tag="<"..guild..">"
        -- Faction coloring is optional (off by default); otherwise plain white like Blizzard's guild line.
        if not tipSettings.guildFactionColor then tag="|cffffffff"..tag.."|r"
        elseif color and color.WrapTextInColorCode then tag=color:WrapTextInColorCode(tag)
        elseif color and color.r then tag=tipModule.hex(color.r,color.g,color.b)..tag.."|r"
        else tag="|cffffffff"..tag.."|r" end
        -- Their guild rank right behind the name (Tooltip > Guild rank), a
        -- little smaller: a marker here, room for it in the line, and the
        -- rank drawn over that room (Tooltip.lua, ApplyTooltip).
        if tipSettings.guildRank and type(guildRank)=="string" and guildRank~="" then tag=tag.."{ftrank}" end
        parts.guild=tag
    end
    parts.target="|cffffd100Target: None|r"
    -- The native PvP badge occupies the upper-left of a 64px canvas; crop its padding.
    local headingLine=_G[prefix.."TextLeft1"]
    local _,nativeSize=headingLine:GetFont()
    local size=math.max(22,math.floor((tipSettings.name>0 and tipSettings.name or nativeSize or 14)*1.4+.5))
    local icon=tipModule:FactionIcon(faction,size)
    local lines=tipModule:Compose(parts,icon)
    if #lines==0 then return end
    tip:ClearLines()
    tip.ftNameLine,tip.ftDetailsLine,tip.ftTargetLine=nil,nil,nil
    tip.ftGuildOnName=false
    tip.ftRank=nil
    for _,line in ipairs(lines) do
        local text=line.text
        local at,stop=text:find("{ftrank}",1,true)
        if at then
            local before,after=text:sub(1,at-1),text:sub(stop+1)
            local lineSize=line.name and ((tipSettings.name>0 and tipSettings.name) or nativeSize or 14)
                or ((tipSettings.details>0 and tipSettings.details) or select(2,(_G[prefix.."TextLeft2"] or headingLine):GetFont()) or 12)
            local room=tipModule:RankRoom(guildRank,headingLine,lineSize)
            if room then text=before..room..after; tip.ftRank={before=before,rank=guildRank}
            else text=before.." |cffb4aa96"..guildRank.."|r"..after end
        end
        tip:AddLine(text,1,1,1)
        local index=tip:NumLines()
        if at and tip.ftRank then tip.ftRank.index=index end
        if line.name and not tip.ftNameLine then tip.ftNameLine=index end
        if line.details and not line.name and not tip.ftDetailsLine then tip.ftDetailsLine=index end
        if line.target then tip.ftTargetLine=index end
        if line.guildOnName then tip.ftGuildOnName=true end
    end
    tip.ftDetailsLine=tip.ftDetailsLine or -1
    for i=2,#rows do
        local row=rows[i]
        if row.right and row.right~="" and tip.AddDoubleLine then
            tip:AddDoubleLine(row.text,row.right,row.color[1],row.color[2],row.color[3],row.rightColor[1],row.rightColor[2],row.rightColor[3])
        else tip:AddLine(row.text,unpack(row.color)) end
    end
    tip.ftPlayerLayout=true
end
function System:ClearTargetPlayerDisplay(tip)
    if tip.ftTargetAlphaLine then tip.ftTargetAlphaLine:SetAlpha(1);tip.ftTargetAlphaLine=nil end
    if tip.ftTargetYou then tip.ftTargetYou:Hide() end
end
function System:TargetPlayerDisplay(tip,comparison)
    if not issecretvalue or not issecretvalue(comparison) then return end
    local evaluate=C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    local line=tip.ftTargetLine and _G[(tip:GetName() or "GameTooltip").."TextLeft"..tip.ftTargetLine]
    if not evaluate or not line then return end
    local ok,youAlpha,nameAlpha=pcall(function()
        return evaluate(comparison,1,0),evaluate(comparison,0,1)
    end)
    if not ok then return end
    if not tip.ftTargetYou then tip.ftTargetYou=tip:CreateFontString(nil,"OVERLAY") end
    local label=tip.ftTargetYou
    local file,size,flags=line:GetFont()
    label:SetFont(file,size,flags or "")
    label:SetTextColor(1,.82,0)
    label:SetText("Target: |cffff0000You|r")
    label:ClearAllPoints();label:SetPoint("TOPLEFT",line,"TOPLEFT",0,0)
    label:SetAlpha(youAlpha);label:Show()
    line:SetAlpha(nameAlpha);tip.ftTargetAlphaLine=line
end
-- The beta's "Press F6 to submit an issue" line (and the gap above it) is
-- added at the bottom of unit tooltips. Our Target line belongs with the
-- unit's own lines, so move it above that footer.
function System:RaiseTargetLine(tip)
    local index=tip.ftTargetLine; if not index or index<3 then return end
    local prefix=tip:GetName() or "GameTooltip"
    local function left(i) return _G[prefix.."TextLeft"..i] end
    local footer
    for i=index-1,2,-1 do
        local line=left(i); local text=line and line:GetText()
        if text~=nil and not usable(text) then return end
        if type(text)=="string" and text:lower():find("to submit an issue",1,true) then footer=i; break end
    end
    if not footer then return end
    -- Take the empty spacer line above the footer with it.
    local above=left(footer-1); local aboveText=above and above:GetText()
    if footer>2 and usable(aboveText) and (aboveText==nil or aboveText=="" or aboveText==" ") then footer=footer-1 end
    -- Shift the lines from the footer down by one and put Target in its place.
    local target=left(index); if not target then return end
    local text=target:GetText(); if not usable(text) then return end
    local r,g,b=target:GetTextColor()
    for i=index,footer+1,-1 do
        local to,from=left(i),left(i-1)
        local t=from:GetText(); if t~=nil and not usable(t) then return end
        local fr,fg,fb=from:GetTextColor()
        to:SetText(t or " "); to:SetTextColor(fr,fg,fb)
    end
    local line=left(footer); line:SetText(text); line:SetTextColor(r,g,b)
    tip.ftTargetLine=footer
end
function System:TooltipTarget(tip)
    self:TooltipTargetLine(tip)
    self:TargetedBy(tip)
end
-- "Targeted by": who in your group (and which enemies with a nameplate)
-- has the unit under the mouse targeted. Only what the game tells us: in a
-- fight it can hide who targets what, and those are left out.
local TARGETED_MAX=6
function System:TargetedByNames(unit)
    if not UnitIsUnit or not UnitExists then return {},0 end
    local names,hidden,seen={},0,{}
    local function check(source,you)
        if seen[source] then return end
        local ok,exists=pcall(UnitExists,source)
        if not ok or not usable(exists) or not exists then return end
        -- The same person can be both raid3 and a nameplate: count them once.
        local okName,name=pcall(UnitName,source)
        if not okName or not usable(name) or type(name)~="string" then hidden=hidden+1; return end
        if seen[name] then return end
        local okT,result=pcall(UnitIsUnit,source.."target",unit)
        if not okT or not usable(result) then hidden=hidden+1; return end
        if result~=true then return end
        seen[name]=true; seen[source]=true
        if you then table.insert(names,1,"|cffff5a5aYou|r"); return end
        -- Only players get a class color: NPCs report a class too (most are
        -- "warriors"), which painted mobs brown. The GUID tells players apart
        -- when UnitIsPlayer is hidden.
        local okP,isPlayer=pcall(UnitIsPlayer,source)
        if not okP or not usable(isPlayer) then
            local okG,guid=pcall(UnitGUID,source)
            isPlayer=okG and usable(guid) and type(guid)=="string" and guid:find("^Player%-")~=nil
        end
        local okC,_,token=pcall(UnitClass,source); if not okC or isPlayer~=true then token=nil end
        local c=token and usable(token) and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[token]
        local hostile=UnitCanAttack and UnitCanAttack("player",source)
        local color=c and FT.modules.Tooltip.hex(c.r,c.g,c.b) or (usable(hostile) and hostile and "|cffff4040" or "|cffffffff")
        names[#names+1]=color..name.."|r"
    end
    check("player",true)
    local raid=IsInRaid and IsInRaid()
    if raid then
        for i=1,40 do check("raid"..i) end
    else
        for i=1,4 do check("party"..i) end
    end
    for i=1,4 do check("party"..i.."pet") end
    check("pet")
    -- Enemies (and anyone else) with a nameplate on screen.
    for i=1,40 do check("nameplate"..i) end
    return names,hidden
end
function System:TargetedBy(tip)
    if tip.ftAddonHelp or not FT.modules.Tooltip:Settings().targetedBy then return end
    local unit=displayedUnit(tip); if not unit then return end
    local names,hidden=self:TargetedByNames(unit)
    local text
    if #names>0 then
        local shown={}
        for i=1,math.min(TARGETED_MAX,#names) do shown[i]=names[i] end
        text="Targeted by: "..table.concat(shown,"|cffffd100,|r ")
        if #names>TARGETED_MAX then text=text.." |cffffd100+"..(#names-TARGETED_MAX).."|r" end
    elseif hidden>0 and InCombatLockdown and InCombatLockdown() then
        text=nil -- the game hides it in this fight: say nothing rather than "nobody"
    end
    local prefix=tip:GetName() or "GameTooltip"
    local line=tip.ftTargetedLine and _G[prefix.."TextLeft"..tip.ftTargetedLine]
    if line then
        -- Updated in place while the tooltip stays up.
        line:SetText(text or "")
        return
    end
    if not text then return end
    tip:AddLine(text,1,.82,0)
    -- Above the beta's "submit an issue" footer, like the Target line.
    local saved=tip.ftTargetLine
    tip.ftTargetLine=tip:NumLines(); self:RaiseTargetLine(tip)
    tip.ftTargetedLine=tip.ftTargetLine; tip.ftTargetLine=saved
    if tip.Show then tip:Show() end
end
-- /ft tipdebug: the next player tooltip you see, as the game made it and as
-- ForeverTools changed it, in a window to copy into a bug report.
function System:TipDebugStart()
    self.tipCapture={stop=(GetTime and GetTime() or 0)+60}
    print("|cffffd100ForeverTools:|r Now hover the player whose tooltip looks wrong. A window opens with text to copy (60 seconds).")
end
local function tipLines(tip)
    local prefix=tip:GetName() or "GameTooltip"; local out={}
    for i=1,(tip.NumLines and tip:NumLines() or 0) do
        local function read(side)
            local line=_G[prefix..side..i]; if not line or (line.IsShown and not line:IsShown()) then return end
            local text=line:GetText(); if text==nil or text=="" then return end
            if not usable(text) then return "(hidden by the game)" end
            local r,g,b=line:GetTextColor()
            local color=(type(r)=="number" and usable(r)) and string.format(" [%02x%02x%02x]",r*255,g*255,b*255) or ""
            return (text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("|T.-|t","[icon]"):gsub("|A.-|a","[icon]"))..color
        end
        local l,r=read("TextLeft"),read("TextRight")
        if l or r then out[#out+1]=string.format("%d: %s%s",i,l or "",r and ("   >> "..r) or "") end
    end
    return out
end
function System:TipDebugCapture(tip,stage)
    local cap=self.tipCapture; if not cap then return end
    if (GetTime and GetTime() or 0)>cap.stop then self.tipCapture=nil; print("|cffffd100ForeverTools:|r Tooltip check timed out. Type /ft tipdebug to try again."); return end
    if stage=="before" then
        local unit=tooltipUnit(tip)
        if not unit or tip.ftPlayerLayout or not safeCall(UnitIsPlayer,unit) then cap.raw=nil; return end
        cap.unit=unit; cap.raw=tipLines(tip); return
    end
    if not cap.raw then return end
    self.tipCapture=nil
    local unit=cap.unit
    local function v(fn,...) if not fn then return "n/a" end local ok,a,b=pcall(fn,...); if not ok then return "error" end
        local function one(x) if x==nil then return "nil" end if not usable(x) then return "hidden" end return tostring(x) end
        return b~=nil and (one(a)..", "..one(b)) or one(a) end
    local version,build,_,interface=GetBuildInfo()
    local lines={"ForeverTools tooltip check","Addon: "..tostring(FT.version).."   Game: "..tostring(version).." ("..tostring(build)..", "..tostring(interface)..")   Locale: "..tostring(GetLocale and GetLocale()),
        "","Unit: "..tostring(unit).."   Level: "..v(UnitLevel,unit).."   Effective: "..v(UnitEffectiveLevel,unit),
        "Race: "..v(UnitRace,unit).."   Class: "..v(UnitClass,unit).."   Faction: "..v(UnitFactionGroup,unit),
        "Friend: "..v(UnitIsFriend,"player",unit).."   Enemy: "..v(UnitIsEnemy,"player",unit).."   Same faction: "..tostring(v(UnitFactionGroup,unit)==v(UnitFactionGroup,"player")).."   In group: "..v(UnitInParty,unit),
        "Guild: "..v(GetGuildInfo,unit).."   Level text: "..tostring(TOOLTIP_UNIT_LEVEL),
        "FT layout used: "..tostring(tip.ftPlayerLayout==true),"","Game's tooltip:"}
    for _,l in ipairs(cap.raw) do lines[#lines+1]="  "..l end
    lines[#lines+1]=""; lines[#lines+1]="After ForeverTools:"
    for _,l in ipairs(tipLines(tip)) do lines[#lines+1]="  "..l end
    local set={}
    for k,val in pairs(FT.modules.Tooltip:Settings()) do if type(val)~="table" and type(val)~="function" then set[#set+1]=k.."="..tostring(val) end end
    table.sort(set); lines[#lines+1]=""; lines[#lines+1]="Tooltip settings: "..table.concat(set,", ")
    local addons={}
    if C_AddOns and C_AddOns.GetNumAddOns then
        for i=1,C_AddOns.GetNumAddOns() do local name=C_AddOns.GetAddOnInfo(i); if name and C_AddOns.IsAddOnLoaded(i) and name~="ForeverTools" then addons[#addons+1]=name end end
    end
    lines[#lines+1]="Other addons: "..(#addons>0 and table.concat(addons,", ") or "none")
    C_Timer.After(0,function()
        FT:CopyBox("Tooltip check",table.concat(lines,"\n"),"Press Ctrl+C to copy, then paste it in your comment on CurseForge. Nothing is sent automatically.",true)
    end)
end
-- A player's full name ("Rick Hasselhoof": in WoW: Forever the second
-- part of UnitFullName is the last name) in class color, or nil.
local function fullColored(u)
    local ok,first,last=pcall(UnitFullName,u)
    if not ok or not usable(first) or type(first)~="string" or first=="" then return nil end
    local name=first
    if usable(last) and type(last)=="string" and last~="" then name=first.." "..last end
    local okC,_,class=pcall(UnitClass,u)
    local c=okC and usable(class) and class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[class]
    if c and c.r then return string.format("|cff%02x%02x%02x%s|r",c.r*255,c.g*255,c.b*255,name) end
    return "|cffffffff"..name.."|r"
end
-- In a fight the game hides who a monster targets. The group member it is
-- attacking (tanking) is almost always its target, and that the game does
-- tell: found among you and your group.
local function tankedBy(unit)
    if not UnitDetailedThreatSituation then return nil end
    local list={"player"}
    if IsInRaid and IsInRaid() then for i=1,40 do list[#list+1]="raid"..i end
    else for i=1,4 do list[#list+1]="party"..i end end
    for _,member in ipairs(list) do
        if UnitExists(member) then
            local ok,tanking=pcall(UnitDetailedThreatSituation,member,unit)
            if ok and usable(tanking) and tanking==true then return member end
        end
    end
end
function System:TooltipTargetLine(tip)
    self:ClearTargetPlayerDisplay(tip)
    if self.tipCapture then self:TipDebugCapture(tip,"before") end
    self:TooltipClass(tip)
    self:TooltipLayout(tip)
    FT.modules.Tooltip:ApplyTooltip(tip)
    if self.tipCapture and self.tipCapture.raw then self:TipDebugCapture(tip,"after") end
    if not FT.modules.Tooltip:Settings().target or not tip.GetUnit or not UnitExists or tip.ftAddonHelp then return end
    local unit=displayedUnit(tip); if not unit then return end
    local target=unit=="player" and "target" or unit.."target"
    local exists=safeCall(UnitExists,target)
    local targetsPlayer=false
    local comparison
    if UnitIsUnit then
        local ok,result=pcall(UnitIsUnit,target,"player")
        if ok then comparison=result end
        targetsPlayer=ok and usable(result) and result==true
    end
    local ok,name=pcall(UnitName,target)
    local secretName=ok and issecretvalue and issecretvalue(name)
    local shown
    if secretName and not targetsPlayer then
        local member=tankedBy(unit)
        if member=="player" then targetsPlayer=true
        elseif member then shown=fullColored(member) end
    elseif not targetsPlayer and exists then
        local okP,isPlayer=pcall(UnitIsPlayer,target)
        if okP and usable(isPlayer) and isPlayer then shown=fullColored(target) end
    end
    if secretName and not targetsPlayer and not shown then
        local index=tip.ftTargetLine
        local prefix=tip:GetName() or "GameTooltip"
        local left=index and _G[prefix.."TextLeft"..index]
        if not left then
            tip:AddLine("Target: Unavailable",1,.82,0)
            tip.ftTargetLine=tip:NumLines()
            self:RaiseTargetLine(tip)
            left=_G[prefix.."TextLeft"..tip.ftTargetLine]
        end
        local right=_G[prefix.."TextRight"..tip.ftTargetLine]
        if right then right:SetText("") end
        if left then
            local displayed=left.SetFormattedText and pcall(left.SetFormattedText,left,"Target: |cffffffff%s|r",name)
            if not displayed then left:SetText("Target: Unavailable") end
        end
        FT.modules.Tooltip:ApplyTooltip(tip)
        self:TargetPlayerDisplay(tip,comparison)
        return
    end
    local text="None"
    if targetsPlayer then text="You"
    elseif shown then text=""
    elseif ok and type(name)=="string" and not secretName and name~="" then text=name
    elseif exists then text="Unavailable" end
    local colored=(not targetsPlayer and shown) or ((targetsPlayer and "|cffff0000" or "|cffffffff")..text.."|r")
    local line=tip.ftTargetLine and _G[(tip:GetName() or "GameTooltip").."TextLeft"..tip.ftTargetLine]
    if line then
        local right=_G[(tip:GetName() or "GameTooltip").."TextRight"..tip.ftTargetLine]
        if right then right:SetText("") end
        line:SetText("Target: "..colored)
    else tip:AddLine("Target: "..colored,1,.82,0); tip.ftTargetLine=tip.NumLines and tip:NumLines(); self:RaiseTargetLine(tip) end
    FT.modules.Tooltip:ApplyTooltip(tip)
    self:TargetPlayerDisplay(tip,comparison)
end
FT:RegisterModule("System",System)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function()
    System:Apply()
    if not GameTooltip or System.hooked then return end
    System.hooked=true
    GameTooltip:HookScript("OnTooltipCleared",function(tip) System:ClearTargetPlayerDisplay(tip);tip.ftTargetLine=nil;tip.ftTargetedLine=nil;tip.ftNameLine=nil;tip.ftDetailsLine=nil;tip.ftPlayerLayout=nil;tip.ftRank=nil;if tip.ftRankText then tip.ftRankText:Hide() end;tip.ftGuildOnName=nil;tip.ftBuffSource=nil;tip.ftAddonHelp=nil;tip.ftSpellID=nil end)
    local function showBuffSource(tip,unit,aura)
        if tip~=GameTooltip or tip.ftBuffSource or not aura then return end
        local caster=aura.sourceUnit
        if not (usable(caster) and type(caster)=="string") then return end
        -- You: "You". Anyone else: their name in their class color. With no
        -- caster the game names (someone out of range, an item), nothing is
        -- shown: "from a player" doesn't say which one.
        local mine=caster=="player"
        if not mine and UnitIsUnit then local okU,same=pcall(UnitIsUnit,caster,"player"); mine=okU and usable(same) and same==true end
        local text
        if mine then text="You"
        else
            local source=safeCall(UnitName,caster)
            if not source or source=="" then return end
            local _,token=safeCall(UnitClass,caster)
            local c=type(token)=="string" and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[token]
            text=c and string.format("|cff%02x%02x%02x%s|r",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5),source) or source
        end
        tip.ftBuffSource=true
        tip:AddLine("Cast by: "..text,1,.82,0)
        tip:Show()
    end
    local function buffSourceByIndex(tip,unit,index,filter)
        if not usable(unit) or not usable(index) or not usable(filter) or type(unit)~="string" or type(index)~="number" then return end
        local harmful=filter and type(filter)=="string" and filter:find("HARMFUL",1,true)
        if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return end
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByIndex,unit,index,filter or "HELPFUL")
        if ok and aura then if not harmful then showBuffSource(tip,unit,aura) end;System:AuraSpellID(tip,aura.spellId) end
    end
    local function buffSourceByID(tip,unit,id)
        if not usable(unit) or not usable(id) or type(unit)~="string" or not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID then return end
        local ok,aura=pcall(C_UnitAuras.GetAuraDataByAuraInstanceID,unit,id)
        if ok and aura then
            if usable(aura.isHelpful) and aura.isHelpful then showBuffSource(tip,unit,aura) end
            System:AuraSpellID(tip,aura.spellId)
        end
    end
    if hooksecurefunc then
        if GameTooltip.SetUnitAura then hooksecurefunc(GameTooltip,"SetUnitAura",buffSourceByIndex) end
        if GameTooltip.SetUnitBuff then hooksecurefunc(GameTooltip,"SetUnitBuff",buffSourceByIndex) end
        if GameTooltip.SetUnitDebuff then hooksecurefunc(GameTooltip,"SetUnitDebuff",function(tip,unit,index) buffSourceByIndex(tip,unit,index,"HARMFUL") end) end
        if GameTooltip.SetUnitAuraByAuraInstanceID then hooksecurefunc(GameTooltip,"SetUnitAuraByAuraInstanceID",buffSourceByID) end
        if GameTooltip.SetUnitBuffByAuraInstanceID then hooksecurefunc(GameTooltip,"SetUnitBuffByAuraInstanceID",buffSourceByID) end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        -- Add IDs during the native build, before its final sizing/anchor pass.
        -- Deferring a frame makes refreshed tooltips alternate between heights.
        for _,kind in ipairs({"Item","Quest","Achievement"}) do
            local dataType=Enum.TooltipDataType[kind]
            local label=kind
            if dataType then TooltipDataProcessor.AddTooltipPostCall(dataType,function(tip,data)
                if not System:Settings().spellID then return end
                local id
                if usable(data) then local okD,v=pcall(function() return data.id end); if okD then id=v end end
                -- In a fight the game can hide the ID in the tooltip's data:
                -- then it is read from what the tooltip belongs to.
                if label=="Item" then
                    if usable(id) then System:RememberItem(tip,id)
                    else
                        if System.itemDebugUntil and GetTime()<System.itemDebugUntil then print("|cffffd100FT item ID|r","tooltip data: "..(usable(data) and "ID hidden" or "all hidden")) end
                        id=System:ItemIDFromOwner(tip)
                    end
                end
                if not usable(id) then return end
                System:SpellID(tip,id,label,true)
            end) end
        end
        if Enum.TooltipDataType.Spell then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell,function(tip,data)
                if not System:Settings().spellID then return end
                local id
                if usable(data) then local okD,v=pcall(function() return data.id end); if okD then id=v end end
                if usable(id) then System:RememberSpell(tip,id) else id=System:SpellIDFromTip(tip) end
                if usable(id) then System:SpellID(tip,id,"Spell",true) end
            end)
        end
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit,function(tip) if tip==GameTooltip then System:TooltipTarget(tip) end end)
    elseif not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetUnit") then
        GameTooltip:HookScript("OnTooltipSetUnit",function(tip) System:TooltipTarget(tip) end)
    end
    if (not TooltipDataProcessor) and GameTooltip.GetSpell and (not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetSpell")) then
        GameTooltip:HookScript("OnTooltipSetSpell",function(tip) local ok,_,id=pcall(tip.GetSpell,tip);if ok then System:QueueSpellID(tip,id) end end)
    end
    if not TooltipDataProcessor and GameTooltip.GetItem and (not GameTooltip.HasScript or GameTooltip:HasScript("OnTooltipSetItem")) then
        GameTooltip:HookScript("OnTooltipSetItem",function(tip)
            local ok,_,link=pcall(tip.GetItem,tip)
            if ok and usable(link) and type(link)=="string" then
                System:QueueSpellID(tip,tonumber(link:match("item:(%d+)")),"Item")
            end
        end)
    end
    local elapsed=0
    GameTooltip:HookScript("OnUpdate",function(tip,dt)
        elapsed=elapsed+dt
        if elapsed>.2 then
            elapsed=0
            if not tip.ftAddonHelp and tip.IsShown and tip:IsShown() and displayedUnit(tip) then System:TooltipTarget(tip) end
        end
    end)
end)

-- Login establishes membership without changing an existing role.
function System:SuggestedRole()
    local reminder=FT.modules.BuffReminder
    if not reminder then return end
    local best,chosen,tied=0,nil,false
    for _,spec in ipairs(reminder:TalentSpecs()) do
        if spec.points>best then best,chosen,tied=spec.points,spec.name,false
        elseif spec.points==best then tied=true end
    end
    -- A tree you picked yourself (Buff reminders > Your buffs) decides.
    local manual=reminder.ManualSpec and reminder:ManualSpec()
    local class=reminder:Class()
    local token=UnitClass and select(2,UnitClass("player"))
    if type(token)~="string" or (issecretvalue and issecretvalue(token)) then token=class and class:upper() end
    -- Rogues, mages, warlocks and hunters only deal damage: no talents needed.
    if token=="ROGUE" or token=="MAGE" or token=="WARLOCK" or token=="HUNTER" then return "DAMAGER",nil,"class" end
    if manual then chosen=manual
    elseif best==0 or tied then
        -- No tree stands out yet (low level, or even points): the usual role
        -- for the class. Priests heal; the others deal damage.
        if token=="PRIEST" then return "HEALER",nil,"class" end
        return "DAMAGER",nil,"class"
    end
    if class=="Druid" and chosen=="Feral Combat" then return nil,"FERAL" end
    if (class=="Paladin" or class=="Warrior") and chosen=="Protection" then return "TANK" end
    if (class=="Paladin" and chosen=="Holy") or (class=="Priest" and (chosen=="Holy" or chosen=="Discipline")) or
        ((class=="Druid" or class=="Shaman") and chosen=="Restoration") then return "HEALER" end
    return "DAMAGER"
end
function System:ObserveGroupRole(event)
    local grouped=IsInGroup and IsInGroup() or (GetNumGroupMembers and GetNumGroupMembers()>0) or false
    if event=="PLAYER_LOGIN" or self.wasGrouped==nil then
        self.wasGrouped=grouped
        -- Logged in or reloaded while in a group with no role yet: set it too.
        if grouped and C_Timer then C_Timer.After(3,function() System:FillEmptyRole() end) end
        return
    end
    if not grouped then
        self.feralPending=nil
        if self.rolePrompt then self.rolePrompt:Hide() end
    end
    local joined=grouped and not self.wasGrouped
    self.wasGrouped=grouped -- consume before invoking any role API
    if not joined or not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() or not UnitSetRole then return end
    local role,reason,from=self:SuggestedRole()
    -- A line in chat says what happened, so it is easy to see it worked.
    local names={TANK="Tank",HEALER="Healer",DAMAGER="Damage"}
    if reason=="FERAL" then
        self.feralPending=true
        print("|cff4fc3f7ForeverTools|r: Feral can tank or deal damage. You'll be asked in the dungeon.")
        self:CheckFeralPrompt()
    elseif role then
        if self:SetOwnRole(role) then print("|cff4fc3f7ForeverTools|r: role set to "..names[role]..(from=="class" and " (from your class)." or " (from your talents)."))
        else print("|cff4fc3f7ForeverTools|r: role not set (the game didn't allow it). Set it from your portrait's menu.") end
    else
        print("|cff4fc3f7ForeverTools|r: role not set. Set it from your portrait's menu.")
    end
end
-- In a group with no role picked: set the one your class or talents suggest
-- (Feral is asked in the dungeon, as on joining).
function System:FillEmptyRole()
    if not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() or not UnitSetRole then return end
    if not (IsInGroup and IsInGroup()) then return end
    local current=UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if not usable(current) or (current~=nil and current~="NONE") then return end
    local role,reason,from=self:SuggestedRole()
    if reason=="FERAL" then self.feralPending=true; self:CheckFeralPrompt(); return end
    if role and self:SetOwnRole(role) then
        print("|cff4fc3f7ForeverTools|r: role set to "..(({TANK="Tank",HEALER="Healer",DAMAGER="Damage"})[role])..(from=="class" and " (from your class)." or " (from your talents)."))
    end
end
-- Never attempt a protected role setter: pcall alone cannot prevent a
-- Blizzard blocked-action warning for a protected function.
function System:SetOwnRole(role)
    if InCombatLockdown() or not UnitSetRole then return false end
    if isprotectedfunction and isprotectedfunction("UnitSetRole") then return false end
    local ok,result=pcall(UnitSetRole,"player",role)
    return ok and result~=false
end
function System:CheckFeralPrompt()
    if not self.feralPending or not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() then return end
    local kind
    if IsInInstance then local inside;inside,kind=IsInInstance() end
    if kind~="party" and kind~="raid" then return end
    local _,reason=self:SuggestedRole()
    if reason~="FERAL" then self.feralPending=nil;return end
    self.feralPending=nil -- one prompt per group, including dismissal
    if not self.rolePrompt then
        local frame=CreateFrame("Frame","ForeverToolsRoleChoice",UIParent)
        self.rolePrompt=frame
        frame:SetSize(330,132);frame:SetPoint("CENTER",UIParent,"CENTER",0,170)
        frame:SetFrameStrata("FULLSCREEN");FT:Panel(frame);FT:MakeDraggable(frame)
        local title=FT:Label(frame,"Your role for this group?",15)
        title:SetPoint("TOP",0,-18)
        FT:AddClose(frame)
        local note=FT:Label(frame,"Feral can tank or deal damage.",12)
        note:SetPoint("TOP",0,-44)
        for i,entry in ipairs({{"Tank","TANK"},{"Damage","DAMAGER"},{"Skip"}}) do
            local role=entry[2]
            local button=FT:QuietButton(frame,entry[1],94,32)
            button:SetPoint("BOTTOMLEFT",16+(i-1)*102,16)
            button:SetScript("OnClick",function()
                frame:Hide()
                if role and self.wasGrouped and self:Settings().autoRole then
                    if not self:SetOwnRole(role) then
                        print("ForeverTools: Role unchanged. Set it from your player portrait menu.")
                    end
                end
            end)
        end
        UISpecialFrames[#UISpecialFrames+1]="ForeverToolsRoleChoice"
    end
    self.rolePrompt:Show()
end
local roleEvents=CreateFrame("Frame")
roleEvents:RegisterEvent("PLAYER_LOGIN")
roleEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PLAYER_REGEN_DISABLED","ROLE_CHANGED_INFORM"}) do
    pcall(roleEvents.RegisterEvent,roleEvents,event)
end
roleEvents:SetScript("OnEvent",function(_,event,changedName)
    if event=="PLAYER_LOGIN" or event=="GROUP_ROSTER_UPDATE" then System:ObserveGroupRole(event)
    elseif event=="PLAYER_REGEN_DISABLED" then
        if System.rolePrompt then System.rolePrompt:Hide() end
    elseif event=="ROLE_CHANGED_INFORM" then
        local name=UnitName and UnitName("player")
        local full=GetUnitName and GetUnitName("player",true)
        if usable(changedName) and ((usable(name) and changedName==name) or (usable(full) and changedName==full)) then
            System.feralPending=nil
            if System.rolePrompt then System.rolePrompt:Hide() end
        end
    else
        if event=="PLAYER_ENTERING_WORLD" then System:RoleOnEntering() end
        System:CheckFeralPrompt()
    end
end)
-- Entering a dungeon already grouped, with no role picked yet: set it (or
-- ask, for Feral) once per visit, not only right after joining a group.
function System:RoleOnEntering()
    if not FT.dbReady or not self:Settings().autoRole or InCombatLockdown() then return end
    if not (IsInGroup and IsInGroup()) then return end
    local kind; if IsInInstance then local ok,inside,k=pcall(IsInInstance); if ok and usable(k) then kind=k end end
    if kind~="party" and kind~="raid" then self.roleVisit=nil; return end
    if self.roleVisit then return end
    self.roleVisit=true
    local current=UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if usable(current) and current~=nil and current~="NONE" then return end
    local role,reason,from=self:SuggestedRole()
    if reason=="FERAL" then self.feralPending=true
    elseif role and self:SetOwnRole(role) then
        print("|cff4fc3f7ForeverTools|r: role set to "..(({TANK="Tank",HEALER="Healer",DAMAGER="Damage"})[role])..(from=="class" and " (from your class)." or " (from your talents)."))
    end
end

