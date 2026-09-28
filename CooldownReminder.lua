local _,FT=...
-- Cooldown reminders (off by default, part of Buff reminders). Each cooldown
-- has a role:
--   Offensive: racials like Blood Fury, trinkets, Recklessness… A short
--     notice on tough targets (elite, rare, boss or 3+ levels above you) and
--     big pulls (3+ enemies after a few seconds). Once per fight, once a
--     minute, and not if you already used one.
--   Defensive: Shield Wall, Evasion, Ice Block, Stoneform… Only when you are
--     in trouble: a burst of damage (a third of your health within 5
--     seconds), or an effect the spell removes (Stoneform: poison/disease;
--     Will of the Forsaken: fear/charm/sleep; Escape Artist: roots; curse
--     breakers: curses). Each at most once per 30 seconds.
--   Leveling fallback: after about 15 kills without using a ready offensive
--     cooldown, the next fight gets a quiet nudge (no sound), at most once
--     every 10 minutes. Kills are counted from the XP-gain message.
--   Off: never reminded.
-- Known spells get their role automatically; anything else starts Off and
-- you can set it. Work happens only in combat, on events, and only for roles
-- you use. (The game keeps your exact health private, so "in trouble" is
-- judged from the damage you take.)
local CD={}
local TOUGH_DELAY,PULL_DELAY,PULL_SIZE,GAP,SHOW,DEF_GAP=2,4,3,60,6,30
local BURST_WINDOW,BURST_SHARE=5,1/3
local NUDGE_KILLS,NUDGE_GAP,NUDGE_DELAY=15,600,3
local function secret(v) return issecretvalue and issecretvalue(v) or false end
local function safe(fn,...) if not fn then return end local ok,a,b,c,d=pcall(fn,...) if ok then return a,b,c,d end end

-- Known cooldowns (English names, any rank). "need" says what a defensive
-- one answers: burst (heavy damage), a debuff type, or a loss of control.
local known={
    ["blood fury"]={"offensive"},["berserking"]={"offensive"},["recklessness"]={"offensive"},["death wish"]={"offensive"},
    ["sweeping strikes"]={"offensive"},["adrenaline rush"]={"offensive"},["blade flurry"]={"offensive"},["cold blood"]={"offensive"},
    ["arcane power"]={"offensive"},["combustion"]={"offensive"},["presence of mind"]={"offensive"},["icy veins"]={"offensive"},
    ["power infusion"]={"offensive"},["inner focus"]={"offensive"},["elemental mastery"]={"offensive"},["rapid fire"]={"offensive"},
    ["bestial wrath"]={"offensive"},["amplify curse"]={"offensive"},["avenging wrath"]={"offensive"},["bloodlust"]={"offensive"},
    ["heroism"]={"offensive"},["nature's swiftness"]={"offensive"},["tiger's fury"]={"offensive"},
    ["shield wall"]={"defensive",need="burst"},["last stand"]={"defensive",need="burst"},["retaliation"]={"defensive",need="burst"},
    ["evasion"]={"defensive",need="burst"},["vanish"]={"defensive",need="burst"},["ice block"]={"defensive",need="burst"},
    ["divine shield"]={"defensive",need="burst"},["divine protection"]={"defensive",need="burst"},["blessing of protection"]={"defensive",need="burst"},
    ["lay on hands"]={"defensive",need="burst"},["barkskin"]={"defensive",need="burst"},["frenzied regeneration"]={"defensive",need="burst"},
    ["deterrence"]={"defensive",need="burst"},["desperate prayer"]={"defensive",need="burst"},["elune's grace"]={"defensive",need="burst"},
    ["war stomp"]={"defensive",need="burst"},["shamanistic rage"]={"defensive",need="burst"},["survival instincts"]={"defensive",need="burst"},
    ["stoneform"]={"defensive",need="Poison Disease"},
    ["will of the forsaken"]={"defensive",need="FEAR CHARM SLEEP"},
    ["escape artist"]={"defensive",need="ROOT"},
    ["shatter curse"]={"defensive",need="Curse"},
}
local function knownRole(name)
    if type(name)~="string" then return end
    local entry=known[name:lower()]
    if entry then return entry[1],entry.need end
    -- Other curse breakers (for example Forever's own racials).
    if name:lower():find("curse",1,true) and (name:lower():find("break",1,true) or name:lower():find("shatter",1,true) or name:lower():find("remove",1,true)) then return "defensive","Curse" end
end

function CD:Settings()
    local root=FT.modules.BuffReminder:Settings()
    if type(root.cooldowns)~="table" then root.cooldowns={} end
    local s=root.cooldowns
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.sound)~="boolean" then s.sound=false end
    if type(s.tough)~="boolean" then s.tough=true end
    if type(s.pulls)~="boolean" then s.pulls=true end
    if type(s.defensive)~="boolean" then s.defensive=true end
    if type(s.leveling)~="boolean" then s.leveling=true end
    -- Your role choices: key ("spell:ID" or "trinket:13/14") > offensive,
    -- defensive or off. Earlier test builds kept on/off in "chosen".
    if type(s.roles)~="table" then s.roles={} end
    if type(s.chosen)=="table" then
        for key,on in pairs(s.chosen) do if s.roles[key]==nil and on==false then s.roles[key]="off" end end
        s.chosen=nil
    end
    for key,role in pairs(s.roles) do if role~="offensive" and role~="defensive" and role~="off" then s.roles[key]=nil end end
    return s
end

-- Spells with a cooldown of a minute or more, read from the game (or the
-- spell's tooltip) once when your spells change.
local function minutes(text)
    if type(text)~="string" or secret(text) then return end
    local n=text:match("([%d%.]+)%s*[Mm]in") ; if n then return tonumber(n)*60 end
    n=text:match("([%d%.]+)%s*[Hh]our") ; if n then return tonumber(n)*3600 end
    n=text:match("([%d%.]+)%s*[Ss]ec") ; if n and text:lower():find("cooldown",1,true) then return tonumber(n) end
end
-- Cooldowns never change for a spell ID, so each is read only once.
local known={}
function CD:BaseCooldown(id)
    if known[id]~=nil then return known[id] or nil end
    known[id]=self:ReadCooldown(id) or false
    return known[id] or nil
end
function CD:ReadCooldown(id)
    if GetSpellBaseCooldown then
        local ms=safe(GetSpellBaseCooldown,id)
        if type(ms)=="number" and not secret(ms) and ms>0 then return ms/1000 end
    end
    local data=C_TooltipInfo and C_TooltipInfo.GetSpellByID and safe(C_TooltipInfo.GetSpellByID,id)
    for _,line in ipairs(type(data)=="table" and data.lines or {}) do
        for _,text in ipairs({line.rightText,line.leftText}) do
            if type(text)=="string" and not secret(text) and text:lower():find("cooldown",1,true) then
                local seconds=minutes(text); if seconds then return seconds end
            end
        end
    end
end
function CD:Candidates()
    if self.cache then return self.cache end
    local list={}
    local book=FT.modules.CustomKeybinds
    local ok,spells=pcall(book.LearnedSpells,book)
    for _,spell in ipairs(ok and type(spells)=="table" and spells or {}) do
        local cd=self:BaseCooldown(spell.value)
        if cd and cd>=60 then
            -- The first spellbook tab (General) holds racials.
            local role,need=knownRole(spell.name)
            list[#list+1]={key="spell:"..spell.value,id=spell.value,name=spell.name,icon=spell.icon,racial=spell.line==1,cooldown=cd,defaultRole=role or "off",need=need}
        end
    end
    -- Known cooldowns first (racials first among them), then the rest.
    local order={offensive=1,defensive=2,off=3}
    table.sort(list,function(a,b)
        if order[a.defaultRole]~=order[b.defaultRole] then return order[a.defaultRole]<order[b.defaultRole] end
        if a.racial~=b.racial then return a.racial end
        return a.name<b.name
    end)
    self.cache=list
    return list
end
function CD:Trinkets()
    local list={}
    for _,slot in ipairs({13,14}) do
        local item=safe(GetInventoryItemID,"player",slot)
        if item and not secret(item) then
            local getSpell=C_Item and C_Item.GetItemSpell or GetItemSpell
            local spellName,spellID=safe(getSpell,item)
            if spellName and not secret(spellName) then
                local name=C_Item and C_Item.GetItemNameByID and safe(C_Item.GetItemNameByID,item) or (GetItemInfo and safe(GetItemInfo,item)) or spellName
                list[#list+1]={key="trinket:"..slot,slot=slot,spellID=spellID,name=name,icon=safe(GetInventoryItemTexture,"player",slot),trinket=true,defaultRole="offensive",need="burst"}
            end
        end
    end
    return list
end
function CD:Role(entry) return self:Settings().roles[entry.key] or entry.defaultRole or "off" end
function CD:Chosen(entry) return self:Role(entry)=="offensive" end
local function ready(start,duration)
    if secret(start) or secret(duration) then return nil end
    if type(start)~="number" or type(duration)~="number" then return nil end
    return start==0 or duration<=1.5 or start+duration-GetTime()<=0
end
function CD:Ready(entry)
    if entry.trinket then
        local start,duration,enabled=safe(GetInventoryItemCooldown,"player",entry.slot)
        if secret(enabled) or enabled==0 then return false end
        return ready(start,duration)
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local info=safe(C_Spell.GetSpellCooldown,entry.id)
        if type(info)~="table" then return nil end
        return ready(info.startTime,info.duration)
    elseif GetSpellCooldown then
        local start,duration=safe(GetSpellCooldown,entry.id)
        return ready(start,duration)
    end
end

-- Is this fight worth a reminder?
local function tough()
    if not UnitExists("target") or not UnitCanAttack("player","target") then return false end
    local class=safe(UnitClassification,"target")
    if not secret(class) and (class=="elite" or class=="rare" or class=="rareelite" or class=="worldboss") then return true end
    local level,mine=safe(UnitLevel,"target"),UnitLevel("player")
    if secret(level) or type(level)~="number" then return false end
    return level==-1 or level>=mine+3
end
local function pullSize()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return 0 end
    local n=0
    for _,plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit=plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and UnitCanAttack("player",unit) and not UnitIsDead(unit) then
            local status=safe(UnitThreatSituation,"player",unit)
            local fighting
            if secret(status) or status==nil then fighting=safe(UnitAffectingCombat,unit) else fighting=true end
            if fighting and not secret(fighting) then n=n+1 end
        end
    end
    return n
end
function CD:ReadyList()
    local list={}
    local function consider(entry)
        if self:Chosen(entry) and self:Ready(entry)==true then list[#list+1]=entry end
    end
    for _,entry in ipairs(self:Trinkets()) do consider(entry) end
    for _,entry in ipairs(self:Candidates()) do consider(entry) end
    return list
end
function CD:Check(reason)
    local s=self:Settings()
    if not s.enabled or not self.fight or self.fight.reminded or self.fight.used then return end
    if not InCombatLockdown() then return end
    if reason=="tough" and not (s.tough and tough()) then return end
    if reason=="pull" and not (s.pulls and pullSize()>=PULL_SIZE) then return end
    local now=GetTime()
    if reason=="leveling" and not (s.leveling and (self.kills or 0)>=NUDGE_KILLS and (not self.nudged or now-self.nudged>=NUDGE_GAP)) then return end
    if self.last and now-self.last<GAP then return end
    local list=self:ReadyList()
    if #list==0 then return end
    self.fight.reminded=true; self.last=now
    if reason=="leveling" then self.nudged=now; self.kills=0 end
    self:Show(list,reason)
end

-- The notice: the same look as the buff reminders, just below them.
function CD:Notice()
    if self.notice then return self.notice end
    local f=CreateFrame("Frame","ForeverToolsCooldownReminder",UIParent)
    f:SetSize(285,34); f:SetFrameStrata("LOW"); FT:Panel(f); FT:MeterSkin(f)
    f.icons={}
    for i=1,3 do local t=f:CreateTexture(nil,"ARTWORK"); t:SetSize(22,22); t:SetPoint("LEFT",8+(i-1)*26,0); t:SetTexCoord(.07,.93,.07,.93); FT:RoundIcon(t); f.icons[i]=t end
    f.text=FT:Label(f,"",13); f.text:SetJustifyH("LEFT")
    if f.text.SetWordWrap then f.text:SetWordWrap(false) end
    f:EnableMouse(false); f:Hide()
    self.notice=f
    return f
end
function CD:Place()
    local f=self:Notice(); f:ClearAllPoints()
    local badge=FT.modules.BuffReminder.badge
    if badge then f:SetPoint("TOP",badge,"BOTTOM",0,-6) else f:SetPoint("TOP",UIParent,"TOP",0,-155) end
end
function CD:Show(list,reason,preview)
    local f=self:Notice(); self:Place()
    local names={}
    for i=1,3 do
        local entry=list[i]
        if entry then f.icons[i]:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"); f.icons[i]:Show(); names[#names+1]=entry.name
        else f.icons[i]:Hide() end
    end
    local shown=math.min(3,#list)
    f.text:ClearAllPoints(); f.text:SetPoint("LEFT",8+shown*26+4,0); f.text:SetWidth(285-(8+shown*26+4)-8)
    local quiet=reason=="leveling"
    f.text:SetText((quiet and "Ready: " or "Use ")..table.concat(names,", "))
    local c=FT.modules.BuffReminder:Settings().textColor
    if type(c)=="table" then f.text:SetTextColor(c[1] or 1,c[2] or 1,c[3] or 1) end
    -- The leveling nudge is quieter: a little see-through, shorter, no sound.
    f:SetAlpha(quiet and .8 or 1)
    f:Show()
    self.token=(self.token or 0)+1; local token=self.token
    C_Timer.After(preview and 8 or quiet and 4 or SHOW,function() if self.token==token then f:Hide() end end)
    if self:Settings().sound and not preview and not quiet and PlaySound and SOUNDKIT and SOUNDKIT.MAP_PING then pcall(PlaySound,SOUNDKIT.MAP_PING,"SFX") end
end

-- Defensive: are you in trouble that this cooldown answers?
function CD:Defensives()
    local list={}
    for _,e in ipairs(self:Trinkets()) do if self:Role(e)=="defensive" then list[#list+1]=e end end
    for _,e in ipairs(self:Candidates()) do if self:Role(e)=="defensive" then list[#list+1]=e end end
    return list
end
local function debuffTypes()
    local found={}
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return found end
    for i=1,40 do
        local aura=safe(C_UnitAuras.GetAuraDataByIndex,"player",i,"HARMFUL")
        if not aura then break end
        local kind=aura.dispelName
        if kind and not secret(kind) then found[kind]=true end
    end
    return found
end
local function controlTypes()
    local found={}
    if not C_LossOfControl or not C_LossOfControl.GetActiveLossOfControlDataCount then return found end
    local count=safe(C_LossOfControl.GetActiveLossOfControlDataCount) or 0
    if secret(count) then return found end
    for i=1,count do
        local data=safe(C_LossOfControl.GetActiveLossOfControlData,i)
        local kind=type(data)=="table" and data.locType
        if kind and not secret(kind) then found[kind]=true; if kind:find("FEAR",1,true) then found.FEAR=true end end
    end
    return found
end
function CD:Burst()
    local max=safe(UnitHealthMax,"player")
    if secret(max) or type(max)~="number" or max<=0 then return false end
    local now,total=GetTime(),0
    local hits=self.damage or {}
    while hits[1] and now-hits[1][1]>BURST_WINDOW do table.remove(hits,1) end
    for _,hit in ipairs(hits) do total=total+hit[2] end
    return total>=max*BURST_SHARE
end
function CD:CheckDefensive(reason)
    local s=self:Settings()
    if not s.enabled or not s.defensive or not InCombatLockdown() then return end
    local list=self:Defensives(); if #list==0 then return end
    local burst=reason=="burst" and self:Burst()
    local debuffs=reason=="aura" and debuffTypes() or {}
    local control=reason=="control" and controlTypes() or {}
    local now=GetTime(); self.defLast=self.defLast or {}
    local show={}
    for _,entry in ipairs(list) do
        local need=entry.need or "burst"
        local hit=false
        if need=="burst" then hit=burst
        else for word in need:gmatch("%S+") do if debuffs[word] or control[word] then hit=true end end end
        if hit and (not self.defLast[entry.key] or now-self.defLast[entry.key]>=DEF_GAP) and self:Ready(entry)==true then
            self.defLast[entry.key]=now; show[#show+1]=entry
        end
    end
    if #show>0 then self:Show(show,"defensive") end
end

-- Fight tracking: only while enabled; the in-combat listeners are added at
-- the start of a fight and removed at its end.
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,event,unit,a,b,c)
    if not FT.dbReady then return end
    if event=="PLAYER_REGEN_DISABLED" then
        CD.fight={}; CD.damage={}
        events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
        local s=CD:Settings()
        if s.defensive and #CD:Defensives()>0 then
            events:RegisterUnitEvent("UNIT_COMBAT","player"); events:RegisterUnitEvent("UNIT_AURA","player")
            pcall(events.RegisterEvent,events,"LOSS_OF_CONTROL_ADDED")
        end
        C_Timer.After(TOUGH_DELAY,function() CD:Check("tough") end)
        C_Timer.After(PULL_DELAY,function() CD:Check("pull") end)
        C_Timer.After(NUDGE_DELAY,function() CD:Check("leveling") end)
    elseif event=="PLAYER_REGEN_ENABLED" then
        CD.fight=nil; CD.damage=nil
        for _,e in ipairs({"UNIT_SPELLCAST_SUCCEEDED","UNIT_COMBAT","UNIT_AURA","LOSS_OF_CONTROL_ADDED"}) do events:UnregisterEvent(e) end
        if CD.notice then CD.notice:Hide() end
    elseif event=="UNIT_COMBAT" then
        -- a=action, c=amount (readable in the open world; skipped if hidden).
        if a~="WOUND" or secret(c) or type(c)~="number" or c<=0 or not CD.damage then return end
        local hits=CD.damage; hits[#hits+1]={GetTime(),c}
        if #hits>40 then table.remove(hits,1) end
        FT:Coalesce("cdBurst",function() CD:CheckDefensive("burst") end,.3)
    elseif event=="UNIT_AURA" then
        FT:Coalesce("cdAura",function() CD:CheckDefensive("aura") end,.3)
    elseif event=="LOSS_OF_CONTROL_ADDED" then
        FT:Coalesce("cdControl",function() CD:CheckDefensive("control") end,.1)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        -- You used one of your offensive cooldowns: no reminder this fight.
        local spellID=b
        if not CD.fight or secret(spellID) or type(spellID)~="number" then return end
        for _,entry in ipairs(CD:Candidates()) do if entry.id==spellID and CD:Chosen(entry) then CD.fight.used=true; CD.kills=0; if CD.notice then CD.notice:Hide() end return end end
        for _,entry in ipairs(CD:Trinkets()) do if entry.spellID==spellID and CD:Chosen(entry) then CD.fight.used=true; CD.kills=0; if CD.notice then CD.notice:Hide() end return end end
    elseif event=="CHAT_MSG_COMBAT_XP_GAIN" then
        -- One kill ("X dies, you gain N experience"); quest XP doesn't count.
        if secret(unit) or type(unit)~="string" then return end
        local template=type(COMBATLOG_XPGAIN_FIRSTPERSON)=="string" and COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience."
        local head=template:match("^(.-)%%s") or ""
        local tail=template:match("%%s(.-)%%d") or " dies"
        if unit:find(tail,1,true) or (head~="" and unit:find(head,1,true)) then CD.kills=(CD.kills or 0)+1 end
    elseif event=="LEARNED_SPELL_IN_SKILL_LINE" or event=="PLAYER_LEVEL_UP" or event=="PLAYER_TALENT_UPDATE" then
        CD.cache=nil
    end
end)
function CD:Apply()
    if not FT.dbReady then return end
    if self:Settings().enabled then
        for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","LEARNED_SPELL_IN_SKILL_LINE","PLAYER_LEVEL_UP","PLAYER_TALENT_UPDATE"}) do pcall(events.RegisterEvent,events,event) end
        if self:Settings().leveling then pcall(events.RegisterEvent,events,"CHAT_MSG_COMBAT_XP_GAIN") else events:UnregisterEvent("CHAT_MSG_COMBAT_XP_GAIN") end
    else events:UnregisterAllEvents(); self.fight=nil; if self.notice then self.notice:Hide() end end
    self:Refresh()
end

-- Settings page (opened from Buff reminders). Explanations live in tooltips.
local roleText={offensive="|cffffc766Offensive|r",defensive="|cff7dd3ff Defensive|r",off="|cff8a8098Off|r"}
local nextRole={offensive="defensive",defensive="off",off="offensive"}
local needText={burst="when you take heavy damage",Poison="poison",Disease="disease",Curse="a curse",Magic="magic",FEAR="fear",CHARM="charm",SLEEP="sleep",ROOT="a root"}
local function needLabel(need)
    if not need or need=="burst" then return needText.burst end
    local parts={}; for word in need:gmatch("%S+") do parts[#parts+1]=needText[word] or word:lower() end
    return "when you have "..table.concat(parts," or ")
end
function CD:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Cooldown reminders: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.toughToggle.label:SetText("Tough targets: "..(s.tough and "On" or "Off")); FT:SetSelected(self.toughToggle,s.tough)
    self.pullToggle.label:SetText("Big pulls: "..(s.pulls and "On" or "Off")); FT:SetSelected(self.pullToggle,s.pulls)
    self.defToggle.label:SetText("In trouble: "..(s.defensive and "On" or "Off")); FT:SetSelected(self.defToggle,s.defensive)
    self.soundToggle.label:SetText("Sound: "..(s.sound and "On" or "Off")); FT:SetSelected(self.soundToggle,s.sound)
    self.levelToggle.label:SetText("Remind while leveling: "..(s.leveling and "On" or "Off")); FT:SetSelected(self.levelToggle,s.leveling)
    local entries={}
    for _,e in ipairs(self:Trinkets()) do entries[#entries+1]=e end
    for _,e in ipairs(self:Candidates()) do entries[#entries+1]=e end
    for _,row in ipairs(self.rows) do row:Hide() end
    for i,entry in ipairs(entries) do
        local row=self.rows[i]
        if not row then
            row=FT:QuietButton(self.list,"",440,30,"generic")
            row.role=FT:Label(row,"",12); row.role:SetPoint("RIGHT",-10,0); row.role:SetJustifyH("RIGHT")
            row.label:SetPoint("RIGHT",row,"RIGHT",-92,0)
            if row.label.SetWordWrap then row.label:SetWordWrap(false) end
            row:SetScript("OnClick",function(owner) local r=self:Settings().roles; r[owner.entry.key]=nextRole[self:Role(owner.entry)]; self:Refresh() end)
            FT:Tooltip(row,"Cooldown",function()
                local e=row.entry; if not e then return "" end
                local role=self:Role(e)
                local when=role=="offensive" and "Reminded on tough targets and big pulls, once per fight." or role=="defensive" and ("Reminded "..needLabel(e.need)..", at most every 30 seconds.") or "Never reminded."
                return e.name..(e.trinket and " (trinket)" or e.racial and " (racial)" or "").."\n"..when.."\n\nClick to change it: Offensive, then Defensive, then Off."
            end)
            self.rows[i]=row
        end
        row.entry=entry
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-(i-1)*34)
        row.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.label:SetText(entry.name)
        local role=self:Role(entry)
        row.role:SetText(roleText[role]); FT:SetSelected(row,role~="off")
        row:Show()
    end
    self.list:SetHeight(math.max(1,#entries*34))
    self.empty:SetShown(#entries==0)
end
function CD:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsCooldownReminders","Cooldown reminders",520,600); self.frame=frame
        FT:BackTo(frame,"BuffReminder")
        self.rows={}
        self.toggle=FT:AccentButton(frame,"",472,34,"Spell_Nature_TimeStop"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Cooldown reminders","A short notice to use a ready cooldown when it matters. Offensive ones on tough targets and big pulls (once per fight, once a minute, not if you already used one). Defensive ones when you're in trouble. Nothing is used for you.")
        self.toughToggle=FT:QuietButton(frame,"",230,32,"Ability_Warrior_Sunder"); self.toughToggle:SetPoint("TOPLEFT",24,-106)
        self.toughToggle:SetScript("OnClick",function() local s=self:Settings(); s.tough=not s.tough; self:Refresh() end)
        FT:Tooltip(self.toughToggle,"Tough targets","Offensive reminder when your target is elite, rare, a boss, or 3 or more levels above you. Checked 2 seconds into the fight.")
        self.pullToggle=FT:QuietButton(frame,"",230,32,"Ability_Whirlwind"); self.pullToggle:SetPoint("TOPLEFT",266,-106)
        self.pullToggle:SetScript("OnClick",function() local s=self:Settings(); s.pulls=not s.pulls; self:Refresh() end)
        FT:Tooltip(self.pullToggle,"Big pulls","Offensive reminder when 3 or more enemies are in combat with you, 4 seconds into the fight (so a pull for AoE has time to gather). Needs enemy nameplates turned on.")
        self.defToggle=FT:QuietButton(frame,"",230,32,"Ability_Warrior_ShieldWall"); self.defToggle:SetPoint("TOPLEFT",24,-146)
        self.defToggle:SetScript("OnClick",function() local s=self:Settings(); s.defensive=not s.defensive; self:Refresh() end)
        FT:Tooltip(self.defToggle,"In trouble","Defensive reminders: when you take a third of your health in damage within 5 seconds, or have an effect the cooldown removes (for example Stoneform and poison, Will of the Forsaken and fear, curse breakers and curses). The game keeps your exact health private, so this goes by the damage you take.")
        self.soundToggle=FT:QuietButton(frame,"",230,32,"INV_Misc_Bell_01"); self.soundToggle:SetPoint("TOPLEFT",266,-146)
        self.soundToggle:SetScript("OnClick",function() local s=self:Settings(); s.sound=not s.sound; if s.sound and PlaySound and SOUNDKIT and SOUNDKIT.MAP_PING then PlaySound(SOUNDKIT.MAP_PING,"SFX") end; self:Refresh() end)
        FT:Tooltip(self.soundToggle,"Sound","Also play a soft chime with the notice (effects volume).")
        self.levelToggle=FT:QuietButton(frame,"",472,32,"fps"); self.levelToggle:SetPoint("TOPLEFT",24,-186)
        self.levelToggle:SetScript("OnClick",function() local s=self:Settings(); s.leveling=not s.leveling; self:Apply() end)
        FT:Tooltip(self.levelToggle,"Remind while leveling","Leveling fights are rarely tough enough for the other reminders. After about 15 kills without using a ready offensive cooldown, the next fight gets a quiet nudge: a slightly see-through notice, no sound, at most once every 10 minutes. Using one of your offensive cooldowns starts the count over.")
        local preview=FT:QuietButton(frame,"Preview",472,32,"buffs"); preview:SetPoint("TOPLEFT",24,-226)
        preview:SetScript("OnClick",function()
            local list={}
            for _,e in ipairs(self:Trinkets()) do if self:Role(e)~="off" then list[#list+1]=e end end
            for _,e in ipairs(self:Candidates()) do if self:Role(e)~="off" then list[#list+1]=e end end
            if #list==0 then list={{name="Blood Fury",icon="Interface\\Icons\\Racial_Orc_BerserkerStrength"}} end
            self:Show(list,"tough",true)
        end)
        FT:Tooltip(preview,"Preview","Show an example notice with your cooldowns.")
        local head=FT:Label(frame,"Your cooldowns",15,true); head:SetPoint("TOPLEFT",24,-276)
        FT:SectionHeading(head,"Spell_Nature_TimeStop",280)
        FT:PageInfo(frame,"Cooldown reminders","A short notice to use a ready cooldown when it matters; nothing is used for you. Offensive cooldowns on tough targets and big pulls, defensive ones when you're in trouble.\n\nThe list shows your on-use trinkets and every spell you know with a cooldown of a minute or more. Known cooldowns get their role automatically (for example Blood Fury is offensive, Stoneform defensive); others start Off. Click a row to change its role, hover it to see when it is reminded.")
        local box=CreateFrame("Frame",nil,frame); box:SetSize(472,280); box:SetPoint("TOPLEFT",24,-306); FT:Panel(box)
        local scroll=CreateFrame("ScrollFrame",nil,box,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",8,-8); scroll:SetPoint("BOTTOMRIGHT",-28,8)
        self.list=CreateFrame("Frame",nil,scroll); self.list:SetSize(440,1); scroll:SetScrollChild(self.list)
        self.empty=FT:Label(box,"No on-use trinkets or long cooldowns found yet.",13); self.empty:SetPoint("CENTER")
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("CooldownReminder",CD)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then CD:Apply() end end)
