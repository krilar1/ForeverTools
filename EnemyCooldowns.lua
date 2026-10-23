local _,FT=...
-- Enemy cooldowns (PvP, off by default). Like OmniCD for enemies: when an
-- enemy player uses a big cooldown (trinket, racial, Blind, Ice Block,
-- Divine Shield, Psychic Scream ...), it shows with a countdown.
--   * A movable bar: one row per enemy (class colour), their used cooldowns
--     as icons with the time left. Most recent enemies first.
--   * Icons by your target's frame: the cooldowns your target has used.
--   * Seen from the casts the game shows us: target, focus, mouseover, enemy
--     nameplates and arena enemies. A cast we never see is never shown.
--   * The times are the usual ones; talents or gear can make them shorter.
--   * Hidden ("secret") values are skipped, never compared.
--   * Plain frames only (no clicks), so it all works in fights. The timer
--     runs only while something is cooling down; events are only listened to
--     while the feature is on.
local C={enemies={},rows={},targetIcons={}}
local NAME_W=74
local GAP=2
local ROW_BACK={0,0,0,.45}
-- English spell name -> usual cooldown in seconds. Your own client's names
-- are added from the spell IDs where the game knows them.
local SPELLS={
    -- PvP trinkets and racials
    ["Immune Charm/Fear/Stun"]=300,["Immune Charm/Fear/Polymorph"]=300,["Immune Fear/Polymorph/Snare"]=300,
    ["Immune Fear/Polymorph/Stun"]=300,["Immune Root/Snare/Stun"]=300,["PvP Trinket"]=300,
    ["Will of the Forsaken"]=120,["Escape Artist"]=105,["Stoneform"]=180,["War Stomp"]=120,["Perception"]=180,
    ["Berserking"]=180,["Blood Fury"]=120,["Shadowmeld"]=10,["Cannibalize"]=120,
    -- Potions and items many players carry (potions share one cooldown)
    ["Free Action"]=120,["Living Free Action"]=120,["Restore Mana"]=120,["Healing Potion"]=120,["Net-o-Matic"]=10,
    -- Rogue
    ["Kick"]=10,["Blind"]=300,["Vanish"]=300,["Evasion"]=300,["Sprint"]=300,["Kidney Shot"]=20,["Gouge"]=10,
    ["Preparation"]=600,["Cold Blood"]=180,["Adrenaline Rush"]=300,["Blade Flurry"]=120,["Premeditation"]=60,
    ["Ghostly Strike"]=20,
    -- Mage
    ["Counterspell"]=24,["Ice Block"]=300,["Blink"]=15,["Frost Nova"]=25,["Cold Snap"]=600,["Presence of Mind"]=180,
    ["Arcane Power"]=180,["Combustion"]=180,["Ice Barrier"]=30,["Evocation"]=480,["Blast Wave"]=45,["Fire Ward"]=30,["Frost Ward"]=30,
    -- Warrior
    ["Pummel"]=10,["Shield Bash"]=12,["Intimidating Shout"]=180,["Intercept"]=30,["Recklessness"]=1800,["Shield Wall"]=1800,
    ["Retaliation"]=1800,["Berserker Rage"]=30,["Death Wish"]=180,["Disarm"]=60,["Concussion Blow"]=45,["Charge"]=15,
    ["Last Stand"]=600,["Sweeping Strikes"]=30,["Bloodrage"]=60,["Challenging Shout"]=600,
    -- Priest
    ["Psychic Scream"]=30,["Silence"]=45,["Power Infusion"]=180,["Inner Focus"]=180,["Desperate Prayer"]=600,["Fear Ward"]=30,
    ["Devouring Plague"]=180,["Elune's Grace"]=300,["Feedback"]=180,
    -- Paladin
    ["Hammer of Justice"]=60,["Divine Shield"]=300,["Blessing of Protection"]=300,["Lay on Hands"]=3600,["Repentance"]=60,
    ["Divine Favor"]=120,["Divine Protection"]=300,["Blessing of Freedom"]=20,["Holy Shock"]=30,["Divine Intervention"]=3600,["Blessing of Sacrifice"]=30,
    -- Warlock
    ["Death Coil"]=120,["Howl of Terror"]=40,["Spell Lock"]=24,["Shadowburn"]=15,["Amplify Curse"]=180,["Fel Domination"]=900,["Shadow Ward"]=30,
    ["Inferno"]=3600,
    -- Hunter
    ["Scatter Shot"]=30,["Freezing Trap"]=15,["Intimidation"]=60,["Deterrence"]=300,["Feign Death"]=30,["Bestial Wrath"]=120,
    ["Rapid Fire"]=300,["Wyvern Sting"]=120,["Concussive Shot"]=12,
    -- Druid
    ["Bash"]=60,["Barkskin"]=60,["Nature's Swiftness"]=180,["Innervate"]=360,["Feral Charge"]=15,["Dash"]=300,
    ["Frenzied Regeneration"]=180,["Tranquility"]=300,["Nature's Grasp"]=60,["Rebirth"]=1800,["Enrage"]=60,["Challenging Roar"]=600,
    -- Shaman
    ["Earth Shock"]=6,["Grounding Totem"]=15,["Mana Tide Totem"]=300,["Elemental Mastery"]=180,["Reincarnation"]=3600,
    ["Stormstrike"]=20,["Earthbind Totem"]=15,["Fire Nova Totem"]=15,
}
C.SPELLS=SPELLS
-- One cooldown for several spells (any shock puts Earth Shock on cooldown).
local SHARED={["Flame Shock"]="Earth Shock",["Frost Shock"]="Earth Shock",
    -- Hunter traps share one cooldown.
    ["Frost Trap"]="Freezing Trap",["Explosive Trap"]="Freezing Trap",["Immolation Trap"]="Freezing Trap",
    -- Potions share one cooldown.
    ["Greater Healing Potion"]="Healing Potion",["Superior Healing Potion"]="Healing Potion",["Major Healing Potion"]="Healing Potion"}
-- Spells that end other cooldowns.
local RESETS={
    ["Preparation"]={"Vanish","Sprint","Evasion","Cold Blood","Premeditation"},
    ["Cold Snap"]={"Ice Block","Frost Nova","Ice Barrier"},
}
-- Icons for the preview, and when the game gives none.
local ICONS={["Blind"]="Spell_Shadow_MindSteal",["Vanish"]="Ability_Vanish",["Kick"]="Ability_Kick",["Ice Block"]="Spell_Frost_Frost",
    ["Counterspell"]="Spell_Frost_IceShock",["Divine Shield"]="Spell_Holy_DivineIntervention",["Hammer of Justice"]="Spell_Holy_SealOfMight",
    ["Psychic Scream"]="Spell_Shadow_PsychicScream",["Will of the Forsaken"]="Spell_Shadow_RaiseDead",["PvP Trinket"]="INV_Jewelry_TrinketPVP_01",
    ["Death Coil"]="Spell_Shadow_DeathCoil",["Intimidating Shout"]="Ability_GolemThunderClap",["Scatter Shot"]="Ability_GolemStormBolt"}
local SIDES={above=true,below=true,left=true,right=true,free=true}
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function now() return GetTime and GetTime() or 0 end
local GROWS={down=true,up=true,right=true,left=true,lineright=true,lineleft=true}
-- Columns: a column per enemy. One line: every enemy side by side in one row.
local function columns(grow) return grow=="right" or grow=="left" end
local function oneLine(grow) return grow=="lineright" or grow=="lineleft" end
local function sideways(grow) return columns(grow) or oneLine(grow) end
local NAMES={beside=true,above=true,below=true,inside=true,none=true}
function C:Settings()
    if type(FT.db.enemyCooldowns)~="table" then FT.db.enemyCooldowns={} end
    local s=FT.db.enemyCooldowns
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.bar)~="boolean" then s.bar=true end
    -- Icons on the target frame: their own switch, off until you turn it on.
    if type(s.targetIcons)~="boolean" then s.targetIcons=false end
    s.target=nil
    if s.where~="all" and s.where~="pvp" then s.where="all" end
    if not GROWS[s.grow] then s.grow="down" end
    if not NAMES[s.name] then s.name="beside" end
    if not SIDES[s.side] then s.side="above" end
    -- Dragged by you: kept as an offset from the target frame (it follows it).
    if s.side=="free" and (type(s.tx)~="number" or type(s.ty)~="number") then s.side="above" end
    if s.side~="free" then s.tx,s.ty=nil,nil end
    -- Countdown text on the icons, as a share of its automatic size.
    s.timeScale=math.max(.5,math.min(2,tonumber(s.timeScale) or 1))
    -- Enemy names, as a share of their automatic size (which follows the icons).
    s.nameScale=math.max(.5,math.min(2,tonumber(s.nameScale) or 1))
    s.size=nil
    s.icon=math.floor(math.max(16,math.min(48,tonumber(s.icon) or 24)))
    s.rows=math.floor(math.max(1,math.min(15,tonumber(s.rows) or 5)))
    s.targetSize=math.max(.7,math.min(1.6,tonumber(s.targetSize) or 1))
    if type(s.x)~="number" or type(s.y)~="number" then s.x,s.y=nil,nil end
    return s
end
-- Spell lookups ------------------------------------------------------------------
local function spellName(id)
    if not plain(id) or type(id)~="number" then return end
    if C_Spell and C_Spell.GetSpellName then local ok,n=pcall(C_Spell.GetSpellName,id); if ok and plain(n) and type(n)=="string" then return n end end
    if GetSpellInfo then local ok,n=pcall(GetSpellInfo,id); if ok and plain(n) and type(n)=="string" then return n end end
end
local function spellIcon(id)
    if not plain(id) or type(id)~="number" then return end
    if C_Spell and C_Spell.GetSpellTexture then local ok,t=pcall(C_Spell.GetSpellTexture,id); if ok and plain(t) and t then return t end end
    if GetSpellTexture then local ok,t=pcall(GetSpellTexture,id); if ok and plain(t) and t then return t end end
end
-- Spell ID -> tracked name (or false), remembered so a busy battleground
-- costs one table lookup per cast.
C.known={}
function C:Tracked(id)
    local k=self.known[id]
    if k~=nil then return k end
    local name=spellName(id)
    local key=name and ((SPELLS[name] and name) or SHARED[name]) or false
    self.known[id]=key
    return key
end
-- Which casts we read, and from whom.
local function watched(unit)
    if unit=="target" or unit=="focus" or unit=="mouseover" then return true end
    return unit:find("^nameplate%d")~=nil or unit:find("^arena%d")~=nil
end
local function enemyPlayer(unit)
    if not UnitIsPlayer or not UnitCanAttack then return false end
    local ok,p=pcall(UnitIsPlayer,unit); if not ok or not plain(p) or not p then return false end
    local ok2,e=pcall(UnitCanAttack,"player",unit); if not ok2 or not plain(e) or not e then return false end
    return true
end
-- Someone of your own faction you can attack: a duel.
local function dueling(unit)
    if not unit or not UnitFactionGroup then return false end
    local okA,mine=pcall(UnitFactionGroup,"player"); local okB,theirs=pcall(UnitFactionGroup,unit)
    return okA and okB and plain(mine) and plain(theirs) and type(mine)=="string" and mine==theirs or false
end
function C:WhereOk(unit)
    if self:Settings().where=="all" then return true end
    -- "PvP only" also counts duels.
    if dueling(unit) then return true end
    if not IsInInstance then return false end
    local ok,inside,kind=pcall(IsInInstance)
    return ok and plain(inside) and inside and plain(kind) and (kind=="pvp" or kind=="arena") or false
end
-- The last casts looked at, with what became of each (/ft enemycd): small,
-- written only for casts of tracked spells or ones the game hides.
C.log={}
local function note(unit,what)
    local log=C.log
    log[#log+1]=date("%H:%M:%S").."  "..tostring(unit).."  "..what
    if #log>15 then table.remove(log,1) end
end
-- An enemy player cast something.
function C:Cast(unit,castID,spellID)
    if not plain(spellID) then note(unit,"spell hidden by the game (secret)"); return end
    if type(spellID)~="number" then return end
    local key=self:Tracked(spellID); if not key then return end
    if not enemyPlayer(unit) then note(unit,key..": not an enemy player"); return end
    if not self:WhereOk(unit) then note(unit,key..": not tracked here (Track: PvP only)"); return end
    note(unit,key..": shown")
    local okG,guid=pcall(UnitGUID,unit); if not okG or not plain(guid) or type(guid)~="string" then return end
    local t=now()
    -- The same cast seen on several units (target and its nameplate): once.
    if plain(castID) and castID and self.lastCast==castID then return end
    if plain(castID) then self.lastCast=castID end
    local e=self.enemies[guid]
    if not e then
        local okN,name=pcall(UnitName,unit); if not okN or not plain(name) or type(name)~="string" then return end
        local _,class=UnitClass(unit)
        e={name=name,class=plain(class) and class or nil,cds={}}
        self.enemies[guid]=e
    end
    local cd=e.cds[key]
    if cd and t-cd.start<.5 then return end
    if RESETS[key] then for _,other in ipairs(RESETS[key]) do e.cds[other]=nil end end
    e.cds[key]={start=t,dur=SPELLS[key],icon=spellIcon(spellID) or ("Interface\\Icons\\"..(ICONS[key] or "INV_Misc_QuestionMark"))}
    e.last=t
    self.lastSeen=key.." by "..e.name
    self:Changed()
end
-- Forget what is ready again, and enemies with nothing left.
function C:Prune()
    local t=now(); local changed=false
    for guid,e in pairs(self.enemies) do
        local left=false
        for k,cd in pairs(e.cds) do if t>=cd.start+cd.dur then e.cds[k]=nil; changed=true else left=true end end
        if not left then self.enemies[guid]=nil end
    end
    return changed
end
-- Lists -------------------------------------------------------------------------
local function cooldownList(e,t)
    local list={}
    for k,cd in pairs(e.cds) do if t<cd.start+cd.dur then list[#list+1]={spell=k,start=cd.start,dur=cd.dur,icon=cd.icon} end end
    table.sort(list,function(a,b) local ra,rb=a.start+a.dur,b.start+b.dur; if ra~=rb then return ra<rb end; return a.spell<b.spell end)
    return list
end
local SAMPLES={{"Stabbington","ROGUE",{"Blind","Vanish","Kick"}},{"Frostina","MAGE",{"Ice Block","Counterspell"}},
    {"Lightbane","PALADIN",{"Divine Shield","Hammer of Justice"}},{"Mindy","PRIEST",{"Psychic Scream","Will of the Forsaken"}},
    {"Felgrin","WARLOCK",{"Death Coil"}},{"Gorrun","WARRIOR",{"Intimidating Shout","PvP Trinket"}}}
function C:Samples()
    if self.samples then return self.samples end
    local t=now(); local out={}
    for i,smp in ipairs(SAMPLES) do
        local e={name=smp[1],class=smp[2],cds={},last=t-i,sample=true}
        for j,spell in ipairs(smp[3]) do
            local dur=SPELLS[spell] or 60
            e.cds[spell]={start=t-dur*(.15*j+.1*i)%dur,dur=dur,icon="Interface\\Icons\\"..(ICONS[spell] or "INV_Misc_QuestionMark")}
        end
        out[#out+1]=e
    end
    self.samples=out
    return out
end
function C:Showing() return self.preview or self.moving or self.peeking end
function C:Rows()
    local t=now(); local list={}
    local source=self:Showing() and self:Samples() or self.enemies
    for _,e in pairs(source) do
        local cds=cooldownList(e,t)
        if #cds>0 then list[#list+1]={e=e,cds=cds} end
    end
    table.sort(list,function(a,b) if (a.e.last or 0)~=(b.e.last or 0) then return (a.e.last or 0)>(b.e.last or 0) end; return a.e.name<b.e.name end)
    for i=#list,self:Settings().rows+1,-1 do list[i]=nil end
    return list
end
-- Icons ---------------------------------------------------------------------------
local function short(left)
    if left>=60 then return math.ceil(left/60).."m" end
    return tostring(math.ceil(left))
end
local function makeIcon(parent)
    local b=CreateFrame("Frame",nil,parent); b:EnableMouse(false)
    b.border=b:CreateTexture(nil,"BACKGROUND"); b.border:SetTexture("Interface\\Buttons\\WHITE8x8"); b.border:SetAllPoints(); b.border:SetVertexColor(0,0,0,.85)
    b.tex=b:CreateTexture(nil,"ARTWORK"); b.tex:SetPoint("TOPLEFT",1,-1); b.tex:SetPoint("BOTTOMRIGHT",-1,1); b.tex:SetTexCoord(.08,.92,.08,.92)
    b.cd=CreateFrame("Cooldown",nil,b,"CooldownFrameTemplate"); b.cd:SetPoint("TOPLEFT",1,-1); b.cd:SetPoint("BOTTOMRIGHT",-1,1)
    if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
    b.time=FT:Label(b,"",11); b.time:SetPoint("CENTER",0,0); b.time:SetShadowColor(0,0,0,1); b.time:SetShadowOffset(1,-1); b.time:SetTextColor(1,1,1)
    return b
end
local function paintIcon(b,cd,size,t)
    b:SetSize(size,size)
    b.tex:SetTexture(cd.icon)
    if b.cdStart~=cd.start then b.cdStart=cd.start; b.cd:SetCooldown(cd.start,cd.dur) end
    b.cd.done=cd.start+cd.dur
    local fs=math.max(6,math.floor(size*.45*C:Settings().timeScale+.5))
    if b.fontSize~=fs then b.fontSize=fs; local path,_,flags=b.time:GetFont(); if path then b.time:SetFont(path,fs,"OUTLINE") end end
    b.time:SetText(short(cd.start+cd.dur-t))
    local skins=FT.modules.IconStyles; if skins and skins.BarIcon then skins:BarIcon(b) end
    b:Show()
end
-- The bar ---------------------------------------------------------------------------
-- One group per enemy: the name and that enemy's icons. Grow down or up:
-- each enemy is a row (icons side by side). Grow right or left: each enemy
-- is a column (icons on top of each other). The name sits beside, above,
-- below or on the icons, or is hidden; its size follows the icon size.
function C:Bar()
    if self.bar then return self.bar end
    local f=CreateFrame("Frame","ForeverToolsEnemyCooldowns",UIParent)
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(false); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if self.moving or self.preview then f:StartMoving() end end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SavePlace() end)
    FT:MoverBox(f,6)
    for _,t in ipairs(f.fillTextures) do t:Hide() end; for _,t in ipairs(f.borderTextures) do t:Hide() end
    f.title=FT:Label(f,"Enemy cooldowns",12); FT:Caption(f.title,f,"above",6); f.title:Hide()
    f.hint=FT:Label(f,"Drag to move",12); FT:Caption(f.hint,f,"below",6); f.hint:Hide()
    f:SetSize(160,24); f:Hide()
    self.bar=f
    self:Place()
    return f
end
local function makeRow(self,i)
    local r=CreateFrame("Frame",nil,self.bar)
    r.back=r:CreateTexture(nil,"BACKGROUND"); r.back:SetAllPoints(); r.back:SetColorTexture(0,0,0,.45)
    -- The name sits on its own layer, above the icons (for "on the icons").
    r.top=CreateFrame("Frame",nil,r); r.top:SetAllPoints(); r.top:SetFrameLevel(r:GetFrameLevel()+6)
    r.name=r.top:CreateFontString(nil,"OVERLAY"); r.name:SetJustifyH("LEFT")
    r.name:SetShadowColor(0,0,0,1); r.name:SetShadowOffset(1,-1); if r.name.SetWordWrap then r.name:SetWordWrap(false) end
    r.icons={}
    self.rows[i]=r
    return r
end
local function classColor(class)
    local c=class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r,c.g,c.b end
    return .8,.8,.8
end
-- Name text size for an icon size: readable at 16 px icons, never huge.
local function nameSize(icon) return math.max(9,math.min(16,math.floor(icon*.42+.5))) end
local function scaledName(icon,share) return math.max(6,math.floor(nameSize(icon)*(share or 1)+.5)) end
C.NameSize=nameSize
local function setFont(fs,size,outline)
    if fs.ftSize==size then return end
    fs.ftSize=size
    fs:SetFont(FT.bodyFont or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size,outline and "OUTLINE" or "")
end
-- One enemy's group, laid out; returns its width and height.
function C:LayoutGroup(r,row,t)
    local s=self:Settings(); local S=s.icon
    local across=columns(s.grow)   -- a column per enemy
    local name=s.name
    if across and name=="beside" then name="above" end
    local fsz=scaledName(S,s.nameScale); local lineH=fsz+4
    local n=#row.cds
    local nameW=(name=="beside") and math.floor(S*3.4+.5) or 0
    local colW=across and ((name=="above" or name=="below") and math.max(S,math.floor(S*2.6+.5)) or S) or nil
    local iconsW=across and S or (n*S+(n-1)*GAP)
    local iconsH=across and (n*S+(n-1)*GAP) or S
    local top=(name=="above") and lineH or 0
    local w=across and colW or (nameW+iconsW)
    local h=top+iconsH+((name=="below") and lineH or 0)
    if not across and (name=="above" or name=="below") then w=math.max(w,math.floor(S*2.6+.5)) end
    -- Name.
    setFont(r.name,name=="inside" and math.max(6,math.floor(S*.32*s.nameScale+.5)) or fsz,name=="inside")
    r.name:SetText(row.e.name); r.name:SetTextColor(classColor(row.e.class))
    r.name:ClearAllPoints()
    if name=="none" then r.name:Hide()
    else
        r.name:Show()
        if name=="beside" then r.name:SetPoint("LEFT",r,"LEFT",4,0); r.name:SetWidth(nameW-6); r.name:SetJustifyH("LEFT")
        elseif name=="above" then r.name:SetPoint("TOPLEFT",r,"TOPLEFT",2,-1); r.name:SetWidth(w-4); r.name:SetJustifyH(across and "CENTER" or "LEFT")
        elseif name=="below" then r.name:SetPoint("BOTTOMLEFT",r,"BOTTOMLEFT",2,1); r.name:SetWidth(w-4); r.name:SetJustifyH(across and "CENTER" or "LEFT")
        else r.name:SetPoint("BOTTOM",r,"TOPLEFT",(across and w or S)/2,-(top+S)+1); r.name:SetWidth(S); r.name:SetJustifyH("CENTER") end
    end
    -- Icons.
    local x0=across and math.floor((w-S)/2) or nameW
    for j,cd in ipairs(row.cds) do
        local b=r.icons[j] or makeIcon(r); r.icons[j]=b
        b:ClearAllPoints()
        if across then b:SetPoint("TOPLEFT",r,"TOPLEFT",x0,-(top+(j-1)*(S+GAP)))
        else b:SetPoint("TOPLEFT",r,"TOPLEFT",x0+(j-1)*(S+GAP),-top) end
        paintIcon(b,cd,S,t)
        if name=="inside" and j==1 then b.time:ClearAllPoints(); b.time:SetPoint("TOP",b,"TOP",0,-2) else b.time:ClearAllPoints(); b.time:SetPoint("CENTER") end
    end
    for j=n+1,#r.icons do r.icons[j]:Hide(); r.icons[j].cdStart=nil end
    r:SetSize(w,h)
    return w,h
end
function C:PaintBar(list,t)
    local s=self:Settings()
    local show=(s.enabled and s.bar and #list>0) or (self:Showing() and s.bar) or self.moving
    if not show then if self.bar then self.bar:Hide() end; return false end
    local f=self:Bar()
    local across=sideways(s.grow)
    local pos,most=0,0
    for i,row in ipairs(list) do
        local r=self.rows[i] or makeRow(self,i)
        local w,h=self:LayoutGroup(r,row,t)
        r:ClearAllPoints()
        if s.grow=="down" then r:SetPoint("TOPLEFT",f,"TOPLEFT",0,-pos)
        elseif s.grow=="up" then r:SetPoint("BOTTOMLEFT",f,"BOTTOMLEFT",0,pos)
        elseif s.grow=="right" or s.grow=="lineright" then r:SetPoint("TOPLEFT",f,"TOPLEFT",pos,0)
        else r:SetPoint("TOPRIGHT",f,"TOPRIGHT",-pos,0) end
        pos=pos+(across and w or h)+GAP+2
        most=math.max(most,across and h or w)
        local skins=FT.modules.IconStyles; if skins and skins.BarRow then skins:BarRow(r,ROW_BACK) end
        r:Show()
    end
    for i=#list+1,#self.rows do self.rows[i]:Hide() end
    local length=math.max(s.icon,pos-GAP-2)
    if #list==0 then most=s.icon end
    f:SetScale(1)
    if across then f:SetSize(length,most) else f:SetSize(most,length) end
    f:Show()
    return #list>0
end
-- Icons by the target frame ------------------------------------------------------------
function C:TargetRow()
    if self.targetRow then return self.targetRow end
    local row=CreateFrame("Frame",nil,UIParent); row:SetSize(24,24); row:SetFrameStrata("MEDIUM"); row:EnableMouse(false)
    FT:LockedMouse(row,true,"EnemyCooldowns")
    -- While previewing: says these icons belong to the target frame.
    row.caption=FT:Label(row,"On your target's frame · drag to move",11); row.caption:SetPoint("BOTTOMLEFT",row,"TOPLEFT",0,3); row.caption:SetTextColor(1,.82,0); row.caption:Hide()
    row.box=row:CreateTexture(nil,"BACKGROUND"); row.box:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.box:SetPoint("TOPLEFT",-3,3); row.box:SetPoint("BOTTOMRIGHT",3,-3); row.box:SetVertexColor(.85,.66,.25,.35); row.box:Hide()
    row:SetMovable(true); row:SetClampedToScreen(true); row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart",function() if self.preview or self.moving then row:StartMoving() end end)
    row:SetScript("OnDragStop",function() row:StopMovingOrSizing(); self:TargetDropped(row) end)
    row:Hide()
    self.targetRow=row
    return row
end
-- A dragged target row keeps its spot next to the target frame.
function C:TargetDropped(row)
    local frame=TargetFrame
    local s=self:Settings()
    local l,b=row:GetLeft(),row:GetBottom()
    if frame and plain(l) and plain(b) and l and b and frame:GetLeft() and frame:GetBottom() then
        -- Kept in screen units, so changing the icon size never moves it.
        local rs,fs,us=row:GetEffectiveScale(),frame:GetEffectiveScale(),UIParent:GetEffectiveScale()
        s.side="free"; s.tx=math.floor((l*rs-frame:GetLeft()*fs)/us+.5); s.ty=math.floor((b*rs-frame:GetBottom()*fs)/us+.5)
    end
    row.place=nil; self:Paint(); self:Refresh()
end
function C:AnchorTarget(row)
    local s=self:Settings(); local frame=TargetFrame
    row:SetScale(s.targetSize); row:ClearAllPoints()
    if not frame then row:SetPoint("CENTER",UIParent,"CENTER",0,-100); return end
    -- Offsets are in the row's own (scaled) units: divide so the spot by the
    -- frame stays the same whatever the size.
    local k=1/s.targetSize
    if s.side=="free" then row:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",s.tx*k,s.ty*k)
    elseif s.side=="below" then row:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",8*k,-2*k)
    elseif s.side=="left" then row:SetPoint("RIGHT",frame,"LEFT",-4*k,0)
    elseif s.side=="right" then row:SetPoint("LEFT",frame,"RIGHT",4*k,0)
    else row:SetPoint("BOTTOMLEFT",frame,"TOPLEFT",8*k,2*k) end
end
function C:PaintTarget(t)
    local s=self:Settings()
    local cds
    if self:Showing() and s.targetIcons then
        cds=cooldownList(self:Samples()[1],t)
    elseif s.enabled and s.targetIcons and UnitGUID then
        local ok,guid=pcall(UnitGUID,"target")
        local e=ok and plain(guid) and guid and self.enemies[guid]
        cds=e and cooldownList(e,t) or {}
    else cds={} end
    if #cds==0 and not self.targetRow then return false end
    local row=self:TargetRow()
    local place=s.side..(s.tx or "")..(s.ty or "")..s.targetSize
    if row.place~=place then row.place=place; self:AnchorTarget(row) end
    local size=s.icon
    for i,cd in ipairs(cds) do
        local b=self.targetIcons[i] or makeIcon(row); self.targetIcons[i]=b
        b:ClearAllPoints(); b:SetPoint("LEFT",row,"LEFT",(i-1)*(size+GAP),0)
        paintIcon(b,cd,size,t)
    end
    for i=#cds+1,#self.targetIcons do self.targetIcons[i]:Hide(); self.targetIcons[i].cdStart=nil end
    row:SetSize(math.max(size,#cds*(size+GAP)-GAP),size)
    local open=(self.preview or self.moving) and true or false
    row.caption:SetShown(self:Showing() and true or false); row.box:SetShown(open)
    if row.open~=open then row.open=open; FT:LockedMouse(row,not open,"EnemyCooldowns") end
    local frameUp=not TargetFrame or TargetFrame:IsVisible() or self:Showing()
    row:SetShown(#cds>0 and frameUp and true or false)
    return row:IsShown()
end
function C:Paint()
    local t=now()
    self:Prune()
    local a=self:PaintBar(self:Rows(),t)
    local b=self:PaintTarget(t)
    self:Tick(a or b)
end
-- Five updates a second, only while something is counting down.
function C:Tick(on)
    if not self.ticker then
        self.ticker=CreateFrame("Frame"); self.ticker.wait=0
        self.ticker:SetScript("OnUpdate",function(tk,dt) tk.wait=tk.wait+dt; if tk.wait<.2 then return end; tk.wait=0; self:Paint() end)
    end
    self.ticker:SetShown(on and true or false)
end
function C:Changed() FT:Coalesce("enemyCooldowns",function() self:Paint() end,0) end
-- Place ---------------------------------------------------------------------------------
-- The bar keeps the corner new enemies grow away from, so changing Grow
-- never moves it.
local CORNERS={down="TOPLEFT",up="BOTTOMLEFT",right="TOPLEFT",left="TOPRIGHT",lineright="TOPLEFT",lineleft="TOPRIGHT"}
function C:Corner() return CORNERS[self:Settings().grow] end
local function cornerXY(f,corner)
    local l,r,t,b=f:GetLeft(),f:GetRight(),f:GetTop(),f:GetBottom()
    if not (plain(l) and plain(r) and plain(t) and plain(b) and l and r and t and b) then return end
    return corner:find("RIGHT") and r or l, corner:find("BOTTOM") and b or t
end
function C:Place()
    local f=self.bar; if not f then return end
    local s=self:Settings(); local corner=self:Corner()
    f:SetScale(1); f:ClearAllPoints()
    if s.x and s.y then f:SetPoint(corner,UIParent,"BOTTOMLEFT",s.x,s.y)
    else f:SetPoint(corner,UIParent,"CENTER",corner:find("RIGHT") and 420 or 200,s.grow=="up" and -60 or 160) end
end
function C:SavePlace()
    local f=self.bar; if not f then return end
    local x,y=cornerXY(f,self:Corner()); if not x then return end
    local s=self:Settings(); s.x,s.y=x,y
    self:Place()
end
function C:SetGrow(grow)
    local s=self:Settings(); local f=self.bar
    local x,y
    if f and f:IsShown() then x,y=cornerXY(f,CORNERS[grow]) end
    s.grow=grow
    if x then s.x,s.y=x,y end
    self:Place(); self:Peek(); self:Refresh()
end
function C:ResetPosition() local s=self:Settings(); s.x,s.y=nil,nil; self:Place() end
function C:Unlock()
    local f=self:Bar(); local open=(self.moving or self.preview) and true or false
    FT:LockedMouse(f,not open,"EnemyCooldowns")
    for _,t in ipairs(f.fillTextures) do t:SetShown(open) end
    for _,t in ipairs(f.borderTextures) do t:SetShown(open) end
    f.title:SetShown(open); f.hint:SetShown(open)
    f:SetFrameStrata(open and "HIGH" or "MEDIUM")
end
function C:SetMoving(on) self.moving=on and true or nil; self.samples=nil; self:Unlock(); self:Paint(); self:Refresh() end
function C:SetPreview(on) self.preview=on and true or nil; self.samples=nil; self:Unlock(); self:Paint(); self:Refresh() end
-- A setting changed while nothing shows: example rows for a few seconds.
function C:Peek()
    if self.preview or self.moving then self:Paint(); return end
    self.peeking=(self.peeking or 0)+1; self.samples=nil
    local mine=self.peeking
    self:Paint()
    C_Timer.After(4,function() if self.peeking==mine then self.peeking=nil; self:Paint() end end)
end
-- On / off ------------------------------------------------------------------------------
local events=CreateFrame("Frame")
C.events=events
function C:Listen(on)
    if self.listening==on then return end
    self.listening=on
    for _,event in ipairs({"UNIT_SPELLCAST_SUCCEEDED","PLAYER_TARGET_CHANGED"}) do
        if on then pcall(events.RegisterEvent,events,event) else pcall(events.UnregisterEvent,events,event) end
    end
end
function C:Apply()
    if not FT.dbReady then return end
    local s=self:Settings()
    self:Listen(s.enabled)
    if not s.enabled then self.enemies={} end
    if self.bar then self:Place() end
    if self.targetRow then self.targetRow.place=nil end
    self:Paint(); self:Refresh()
end
-- /ft enemycd: what was seen, for bug reports.
function C:Diagnose()
    local n=0; for _ in pairs(self.enemies) do n=n+1 end
    local s=self:Settings()
    print("ForeverTools enemy cooldowns: "..(s.enabled and "on" or "off")..", bar "..(s.bar and "on" or "off")..", tracking "..(self.listening and "on" or "off")..", where "..tostring(s.where)..", enemies now "..n..", last shown: "..(self.lastSeen or "nothing yet"))
    print("Casts looked at (newest last):")
    if #self.log==0 then print("  none: no tracked spell was seen from your target, focus, mouseover or nameplates") end
    for _,line in ipairs(self.log) do print("  "..line) end
end
-- Settings page (PvP > Enemy cooldowns) --------------------------------------------------
local GROW_NAMES={down="Down",up="Up",right="Right (columns)",left="Left (columns)",lineright="Right, one line",lineleft="Left, one line"}
local NAME_NAMES={beside="Beside the icons",above="Above the icons",below="Below the icons",inside="On the icons",none="Hidden"}
local SIDE_NAMES={above="Above the frame",below="Below the frame",left="Left of the frame",right="Right of the frame",free="Custom"}
function C:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    self.toggle.label:SetText("Enemy cooldowns: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.barRow.label:SetText("Bar: "..(s.bar and "On" or "Off")); FT:SetSelected(self.barRow,s.bar)
    self.targetToggle.label:SetText("Icons on target frame: "..(s.targetIcons and "On" or "Off")); FT:SetSelected(self.targetToggle,s.targetIcons)
    self.where.label:SetText("Track: "..(s.where=="pvp" and "PvP only" or "Everywhere"))
    self.grow.label:SetText("Grow: "..GROW_NAMES[s.grow])
    local across=columns(s.grow)
    self.name.label:SetText("Name: "..NAME_NAMES[(across and s.name=="beside") and "above" or s.name])
    self.side.label:SetText("Place: "..SIDE_NAMES[s.side])
    self.iconLabel:SetText(string.format("Icon size: %d",s.icon))
    self.timeLabel:SetText(string.format("Timer text: %d%%",math.floor(s.timeScale*100+.5)))
    self.nameLabel:SetText(string.format("Name text: %d%%",math.floor(s.nameScale*100+.5)))
    self.rowsLabel:SetText(string.format("Most enemies: %d",s.rows))
    self.targetSizeLabel:SetText(string.format("Size: %d%%",math.floor(s.targetSize*100+.5)))
    self.settingSlider=true
    self.iconSlider:SetValue(s.icon); self.timeSlider:SetValue(s.timeScale); self.nameSlider:SetValue(s.nameScale); self.rowsSlider:SetValue(s.rows); self.targetSizeSlider:SetValue(s.targetSize)
    self.settingSlider=false
    -- Target icon settings only matter with those icons on.
    for _,c in ipairs({self.side,self.targetSizeLabel,self.targetSizeSlider}) do c:SetAlpha(s.targetIcons and 1 or .45) end
    for _,c in ipairs({self.grow,self.name,self.rowsLabel,self.rowsSlider,self.reset}) do c:SetAlpha(s.bar and 1 or .45) end
    FT:RefreshPreview(self.frame)
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
function C:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsEnemyCooldownsPage","Enemy cooldowns",540,560); self.frame=frame
        FT:PageInfo(frame,"Enemy cooldowns","When an enemy player uses a big cooldown (trinket, racial, Blind, Ice Block, Divine Shield, fears and stuns), it shows with the time left.\n\nBar: a group per enemy, newest first. Icons on target frame: only your target's.\n\nOnly casts the game shows you count: target, focus, mouseover, nameplates and arena enemies. Times are the usual ones; talents can make them shorter.")
        local hint=FT:Label(frame,"Big cooldowns your enemies used, and when they have them again.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(492); hint:SetTextColor(.66,.59,.48)
        self.toggle=FT:AccentButton(frame,"",492,34,"Spell_Holy_BorrowedTime"); self.toggle:SetPoint("TOPLEFT",24,-90)
        self.toggle:SetScript("OnClick",function()
            local s=self:Settings(); s.enabled=not s.enabled; self:Apply()
            if s.enabled then self:Peek() end
        end)
        FT:Tooltip(self.toggle,"Enemy cooldowns","Track the big cooldowns enemy players use. Shows the bar; icons on your target frame are a separate switch.")
        self.previewButton=FT:TopPreview(frame,self.toggle,{get=function() return (self.preview or self.moving) and true or false end,
            set=function(on) self.moving=nil; self:SetPreview(on) end,tip="Made-up enemies on the bar (and on your target frame when that is on)."})
        -- Show
        self.barRow=FT:QuietButton(frame,"",240,32,"Spell_Holy_BorrowedTime"); self.barRow:SetPoint("TOPLEFT",24,-140)
        self.barRow:SetScript("OnClick",function() local s=self:Settings(); s.bar=not s.bar; self:Peek(); self:Refresh() end)
        FT:Tooltip(self.barRow,"Bar","A movable bar with every enemy's used cooldowns.")
        self.targetToggle=FT:QuietButton(frame,"",240,32,"Ability_Hunter_SniperShot"); self.targetToggle:SetPoint("TOPLEFT",276,-140)
        self.targetToggle:SetScript("OnClick",function() local s=self:Settings(); s.targetIcons=not s.targetIcons; self:Peek(); self:Refresh() end)
        FT:Tooltip(self.targetToggle,"Icons on target frame","Also show your target's used cooldowns as icons by the target frame.")
        self.where=FT:QuietButton(frame,"",492,32,"INV_BannerPVP_02"); self.where:SetPoint("TOPLEFT",24,-178)
        FT:MakeChoice(self.where,{{"all","Everywhere","Also in the open world."},{"pvp","PvP only","Battlegrounds, arenas and duels."}},function() return self:Settings().where end,function(v) self:Settings().where=v; self:Refresh() end)
        FT:Tooltip(self.where,"Track","Where enemy cooldowns are tracked.")
        -- Bar
        self.grow=FT:QuietButton(frame,"",240,32,"Ability_Hunter_Pet_Bear"); self.grow:SetPoint("TOPLEFT",24,-232)
        FT:MakeChoice(self.grow,{{"down","Down","Each enemy is a row; new ones below."},{"up","Up","Each enemy is a row; new ones above."},{"right","Right (columns)","Each enemy is a column; new ones to the right."},{"left","Left (columns)","Each enemy is a column; new ones to the left."},{"lineright","Right, one line","Everyone side by side in a single row; new ones to the right. Takes the least height."},{"lineleft","Left, one line","Everyone side by side in a single row; new ones to the left."}},function() return self:Settings().grow end,function(v) self:SetGrow(v) end)
        FT:Tooltip(self.grow,"Grow","Where new enemies are added. The bar itself never moves.")
        self.name=FT:QuietButton(frame,"",240,32,"INV_Misc_Note_04"); self.name:SetPoint("TOPLEFT",276,-232)
        FT:MakeChoice(self.name,{{"beside","Beside the icons","Left of each row (rows only)."},{"above","Above the icons"},{"below","Below the icons"},{"inside","On the icons","Small, on the first icon."},{"none","Hidden","Icons only."}},function() return self:Settings().name end,function(v) self:Settings().name=v; self:Peek(); self:Refresh() end)
        FT:Tooltip(self.name,"Name","Where the enemy's name shows. Its size follows the icon size.")
        local function slider(y,lo,hi,step,label,tip,set)
            local text=FT:Label(frame,"",14); text:SetPoint("TOPLEFT",24,-y-2)
            local sl=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); sl:SetSize(300,18); sl:SetPoint("TOPLEFT",216,-y)
            sl:SetMinMaxValues(lo,hi); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
            sl:SetScript("OnValueChanged",function(_,v) if self.settingSlider then return end; set(v); FT:Coalesce("enemyCdSize",function() if self.targetRow then self.targetRow.place=nil end; self:Peek(); self:Refresh() end,.05) end)
            FT:Tooltip(sl,label,tip)
            return text,sl
        end
        self.iconLabel,self.iconSlider=slider(276,16,48,1,"Icon size","Size of the icons, on the bar and on the target frame; names grow with them.",function(v) self:Settings().icon=math.floor(v+.5) end)
        self.timeLabel,self.timeSlider=slider(310,.5,2,.05,"Timer text","Size of the countdown on the icons (50% to 200%), on the bar and on the target frame.",function(v) self:Settings().timeScale=math.floor(v*20+.5)/20; for _,r in ipairs(self.rows) do for _,b in ipairs(r.icons) do b.fontSize=nil end end; for _,b in ipairs(self.targetIcons) do b.fontSize=nil end end)
        self.nameLabel,self.nameSlider=slider(344,.5,2,.05,"Name text","Size of the enemy names (50% to 200%). They still follow the icon size.",function(v) self:Settings().nameScale=math.floor(v*20+.5)/20 end)
        self.rowsLabel,self.rowsSlider=slider(378,1,15,1,"Most enemies","The most enemies shown, newest first, so a battleground never fills your screen.",function(v) self:Settings().rows=math.floor(v+.5) end)
        self.reset=FT:QuietButton(frame,"Reset position",240,32,"reset"); self.reset:SetPoint("TOPLEFT",24,-410)
        self.reset:SetScript("OnClick",function() self:ResetPosition() end)
        FT:Tooltip(self.reset,"Reset position","Put the bar back in its starting place.")
        -- Target frame icons
        self.side=FT:QuietButton(frame,"",240,32,"Ability_Hunter_SniperShot"); self.side:SetPoint("TOPLEFT",24,-480)
        FT:MakeChoice(self.side,{{"above","Above the frame"},{"below","Below the frame"},{"left","Left of the frame"},{"right","Right of the frame"}},function() return self:Settings().side end,function(v) self:Settings().side=v; if self.targetRow then self.targetRow.place=nil end; self:Peek(); self:Refresh() end)
        FT:Tooltip(self.side,"Place","Where the icons sit by your target's frame. Or turn on Preview and drag them. They follow the frame.")
        self.targetSizeLabel,self.targetSizeSlider=slider(522,.7,1.6,.05,"Size","Size of the icons by your target (70% to 160%).",function(v) self:Settings().targetSize=math.floor(v*20+.5)/20 end)
        frame:HookScript("OnHide",function() if self.moving then self:SetMoving(false) end end)
        FT:Sections(frame,{{"Show",self.barRow},{"Bar",self.grow},{"Icons on target frame",self.side}})
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("EnemyCooldowns",C)
FT.EnemyCooldowns=C
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent",function(_,event,unit,castID,spellID)
    if not FT.dbReady then return end
    if event=="UNIT_SPELLCAST_SUCCEEDED" then
        if plain(unit) and type(unit)=="string" and watched(unit) then C:Cast(unit,castID,spellID) end
    elseif event=="PLAYER_TARGET_CHANGED" then
        C:Changed()
    elseif event=="PLAYER_ENTERING_WORLD" then
        C.enemies={}; C.lastCast=nil; if C.bar or C.targetRow then C:Paint() end
    elseif event=="PLAYER_LOGIN" then
        C:Apply()
    end
end)
