local _,FT=...
-- Standing in fire (off by default): one warning sound when you keep taking
-- magic damage in a steady rhythm, the way ground effects and lava hit you.
-- Nothing to set up. It listens only to the game's "you took damage" event
-- (the combat log is reserved for the game here) and plays a game sound on
-- the effects channel, so your effects volume and Ctrl+S apply.
--
-- The rule: 3 or more non-physical hits within 4.5 seconds, spaced 0.6 to
-- 2.3 seconds apart and evenly (ground effects tick about every 1 or 2
-- seconds; most damage-over-time spells here tick every 3). It stays quiet
-- while your target channels a spell, and repeats at most every 4 seconds.
local Fire={hits={}}
local PHYSICAL=1
local WINDOW,MIN_GAP,MAX_GAP,EVEN,REPEAT=4.5,.6,2.3,.45,4
local function secret(v) return issecretvalue and issecretvalue(v) or false end
-- Game sounds only. Addons can't set a sound's own volume, so loudness
-- follows either your effects volume or your master volume.
local sounds={
    {value="whisper",label="Boss whisper",kit="UI_RAID_BOSS_WHISPER_WARNING"},
    {value="emote",label="Boss emote",kit="RAID_BOSS_EMOTE_WARNING"},
    {value="raid",label="Raid warning",kit="RAID_WARNING"},
    {value="alarm",label="Alarm clock",kit="ALARM_CLOCK_WARNING_3"},
    {value="chime",label="Soft chime",kit="MAP_PING"},
}
local channels={{value="SFX",label="Effects volume"},{value="Master",label="Master volume"}}
function Fire:Enabled() return type(FT.db.system)=="table" and FT.db.system.fireAlert==true end
function Fire:SetEnabled(on)
    if type(FT.db.system)~="table" then FT.db.system={} end
    FT.db.system.fireAlert=on==true
end
function Fire:Settings()
    if type(FT.db.fireAlert)~="table" then FT.db.fireAlert={} end
    local s=FT.db.fireAlert
    local known=false; for _,e in ipairs(sounds) do if e.value==s.sound then known=true end end
    if not known then s.sound="whisper" end
    if s.channel~="SFX" and s.channel~="Master" then s.channel="SFX" end
    return s
end
function Fire:PlaySound()
    if not PlaySound or not SOUNDKIT then return end
    local s=self:Settings()
    for _,e in ipairs(sounds) do
        if e.value==s.sound then
            local kit=SOUNDKIT[e.kit] or SOUNDKIT.RAID_WARNING
            if kit then pcall(PlaySound,kit,s.channel) end
        end
    end
end
local function cvar(name) return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name) or (GetCVar and GetCVar(name)) end
-- A short warning when the game would make the sound hard to hear.
function Fire:VolumeWarning()
    if cvar("Sound_EnableAllSound")=="0" then return "Game sound is turned off (the game's sound on/off key), so the warning is silent." end
    local master=tonumber(cvar("Sound_MasterVolume")) or 1
    local level=master
    if self:Settings().channel=="SFX" then
        if cvar("Sound_EnableSFX")=="0" then return "Sound effects are off in the game's sound settings, so the warning is silent. Choose Master volume or turn effects on." end
        level=master*(tonumber(cvar("Sound_SFXVolume")) or 1)
    end
    if level<.2 then return string.format("Your %s volume is about %d%%, so the warning may be hard to hear.",self:Settings().channel=="SFX" and "effects" or "master",math.floor(level*100+.5)) end
end
-- Your target is channeling (Drain Life, Mind Flay…): those ticks look like
-- fire, so wait until it stops.
local function targetChanneling()
    if not UnitChannelInfo then return false end
    local ok,name=pcall(UnitChannelInfo,"target")
    return ok and not secret(name) and name~=nil
end
-- Out of combat nobody can be casting on you, so repeated magic damage is
-- the world itself (campfires, lava, fire patches, which can tick slower):
-- two hits up to about 3 seconds apart are enough there.
local CALM_WINDOW,CALM_GAP=7,3.4
local function fighting()
    if InCombatLockdown() then return true end
    local ok,value=pcall(UnitAffectingCombat,"player")
    return ok and not secret(value) and value==true
end
function Fire:Hit(now)
    local hits=self.hits
    hits[#hits+1]=now
    local calm=not fighting()
    while hits[1] and now-hits[1]>(calm and CALM_WINDOW or WINDOW) do table.remove(hits,1) end
    local n=#hits
    if calm then
        if n<2 then return end
        local gap=hits[n]-hits[n-1]
        if gap<MIN_GAP or gap>CALM_GAP then return end
        if self.last and now-self.last<REPEAT then return end
        self.last=now
        self:PlaySound()
        return
    end
    if n<3 then return end
    local a,b=hits[n-1]-hits[n-2],hits[n]-hits[n-1]
    if a<MIN_GAP or b<MIN_GAP or a>MAX_GAP or b>MAX_GAP then return end
    if math.abs(a-b)>EVEN*math.max(a,b) then return end
    if self.last and now-self.last<REPEAT then return end
    if targetChanneling() then return end
    self.last=now
    self:PlaySound()
end
local events=CreateFrame("Frame")
events:SetScript("OnEvent",function(_,_,unit,action,_,amount,school)
    if unit~="player" or secret(action) or action~="WOUND" then return end
    -- Only the timing of hits matters. The game can hide the amount or the
    -- school (for example for fire from the world, like campfires); a hidden
    -- one still counts. Only a readable physical school (melee, arrows) or a
    -- readable zero is skipped.
    if not secret(amount) and type(amount)=="number" and amount<=0 then return end
    if not secret(school) and type(school)=="number" and school==PHYSICAL then return end
    Fire:Hit(GetTime())
end)
function Fire:Apply()
    if self:Enabled() then
        if not self.listening then self.listening=true; events:RegisterUnitEvent("UNIT_COMBAT","player") end
    elseif self.listening then
        self.listening=false; events:UnregisterAllEvents(); self.hits={}
    end
end
-- Settings page
local function label(list,v) for _,e in ipairs(list) do if e.value==v then return e.label end end end
function Fire:Refresh()
    if not self.frame then return end
    local s=self:Settings(); local on=self:Enabled()
    self.toggle.label:SetText("Standing in fire sound: "..(on and "On" or "Off")); FT:SetSelected(self.toggle,on)
    self.soundChoice.value=s.sound; self.soundChoice.label:SetText("Sound: "..label(sounds,s.sound))
    self.channelChoice.value=s.channel; self.channelChoice.label:SetText("Loudness: "..label(channels,s.channel))
    local warn=self:VolumeWarning()
    self.volumeNote:SetText(warn or "")
    if warn then self.volumeNote:SetTextColor(1,.62,.35) else self.volumeNote:SetTextColor(.66,.59,.48) end
end
function Fire:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsFireAlert","Standing in fire",520,200); self.frame=frame
        FT:BackTo(frame,"SystemCombat")
        self.toggle=FT:AccentButton(frame,"",472,34,"Spell_Fire_Fire"); self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function()
            local on=not self:Enabled(); self:SetEnabled(on); self:Apply(); self:Refresh()
            if on then self:PlaySound() end
            if FT.modules.System then FT.modules.System:Refresh() end
        end)
        FT:Tooltip(self.toggle,"Standing in fire sound","Turn the warning on or off. Turning it on plays the sound once.")
        self.soundChoice=FT:Dropdown(frame,230,function()
            local list={}; for _,e in ipairs(sounds) do list[#list+1]={value=e.value,label=e.label,icon="Interface\\Icons\\INV_Misc_Bell_01",tooltip="A sound from the game itself. Choosing it plays a short preview."} end; return list
        end,function(value) self:Settings().sound=value; self:PlaySound(); self:Refresh() end,"INV_Misc_Bell_01")
        self.soundChoice:SetPoint("TOPLEFT",24,-106)
        self.channelChoice=FT:Dropdown(frame,230,function()
            return {{value="SFX",label="Effects volume",icon="Interface\\Icons\\INV_Misc_Bell_01",tooltip="Follows the game's sound effects volume. Choosing it plays the sound."},
                {value="Master",label="Master volume",icon="Interface\\Icons\\INV_Misc_Bell_01",tooltip="Follows only the master volume, so it stays loud even with quiet effects. Choosing it plays the sound."}}
        end,function(value) self:Settings().channel=value; self:PlaySound(); self:Refresh() end,"INV_Misc_Bell_01")
        self.channelChoice:SetPoint("TOPLEFT",266,-106)
        FT:Tooltip(self.channelChoice,"Loudness","Addons can't set a sound's own volume, so choose which game volume it follows. Turning game sound off (the game's sound on/off key) mutes it either way.")
        self.volumeNote=FT:Label(frame,"",12); self.volumeNote:SetPoint("TOPLEFT",24,-148); self.volumeNote:SetWidth(472)
        FT:PageInfo(frame,"Standing in fire","A warning sound when you keep taking magic damage in a steady rhythm, like standing in fire, lava or another ground effect. It works without any setup; the choices are optional.\n\nIn combat it warns after 3 or more magic hits within a few seconds that land evenly 0.6 to 2.3 seconds apart. Out of combat (campfires, lava) two hits up to about 3 seconds apart are enough. It repeats at most every 4 seconds while you stay in it. It stays quiet while your target channels a spell. It can't tell ground effects from a fast spell cast on you, and it doesn't catch physical damage.")
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("FireAlert",Fire)
local login=CreateFrame("Frame"); login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent",function() if FT.dbReady then Fire:Apply() end end)
