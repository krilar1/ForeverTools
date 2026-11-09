local _,FT=...
-- Extra game options (System > Extra game options): game settings that
-- Forever has but its settings menu does not show, the ones players set by
-- hand with /console (sharpening at full render scale, grass, weather,
-- scenery detail, screen glow, spell queue). Each is the game's own
-- setting: ForeverTools only sets it when you move it here, the game saves
-- it (not your profile) and "Game default" puts it back. A setting this
-- game version doesn't have is not listed. Nothing runs in the background.
local G={}
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function get(name)
    local fn=(C_CVar and C_CVar.GetCVar) or GetCVar
    if not fn then return nil end
    local ok,v=pcall(fn,name); if ok and plain(v) then return v end
end
local function default(name)
    local fn=(C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
    if not fn then return nil end
    local ok,v=pcall(fn,name); if ok and plain(v) then return v end
end
local function set(name,value)
    if InCombatLockdown() then FT:Toast("Leave combat to change game options.",3); return false end
    local fn=(C_CVar and C_CVar.SetCVar) or SetCVar
    if not fn then return false end
    return pcall(fn,name,tostring(value))
end
G.Get,G.Set,G.Default=get,set,default
-- kind "switch": 0/1. kind "slider": min, max, step; reverse shows max-value
-- (the game's own sharpness slider works that way: 0 is the sharpest).
G.sections={{"graphics","Graphics","INV_Misc_Spyglass_03"},{"distance","Distance","INV_Misc_Map_01"},{"camera","Camera","INV_Misc_Spyglass_02"},{"combat","Combat","Ability_Hunter_SniperShot"}}
G.options={
    {cvar="ResampleAlwaysSharpen",kind="switch",section="graphics",title="Sharpen at full render scale",icon="INV_Misc_Spyglass_03",
        tip="The game only sharpens the picture when render scale is under 100%. On: sharpens at 100% too (uses Sharpness below)."},
    {cvar="ResampleSharpness",kind="slider",section="graphics",min=0,max=2,step=.1,reverse=true,title="Sharpness",
        tip="How strong the sharpening is. The game's own setting, also under Graphics > Advanced; it only shows below 100% render scale there."},
    {cvar="groundEffectDensity",kind="slider",section="distance",min=16,max=256,step=16,title="Grass density",
        tip="How thick grass and flowers grow. The game's highest graphics preset stops below the top of this range. More costs frames in grassy zones."},
    {cvar="groundEffectDist",kind="slider",section="distance",min=40,max=500,step=10,title="Grass distance",
        tip="How far away grass is still drawn, in yards."},
    {cvar="weatherDensity",kind="slider",section="distance",min=0,max=3,step=1,title="Weather",labels={[0]="Off","Light","Medium","Full"},
        tip="How much rain and snow falls. Off also clears the dim light of storms."},
    {cvar="terrainLodDist",kind="slider",section="distance",min=200,max=1000,step=50,title="Far terrain detail",
        tip="How far the ground keeps its full shape before turning coarse. Higher costs frames."},
    {cvar="lodObjectFadeScale",kind="slider",section="distance",min=50,max=300,step=10,title="Scenery fade distance",
        tip="How far trees, rocks and buildings keep their full detail. 100 is the game's normal."},
    {cvar="ffxGlow",kind="switch",section="graphics",title="Full-screen glow",icon="Spell_Holy_HolyBolt",
        tip="The soft glow (bloom) over bright parts of the screen. Off gives a crisper, darker picture."},
    {cvar="shadowSoft",kind="switch",section="graphics",title="Soft shadows",icon="Spell_Shadow_Twilight",
        tip="Shadows with soft edges instead of hard ones. Costs a little performance."},
    {cvar="projectedTextures",kind="switch",section="graphics",title="Spell effects on the ground",icon="Spell_Frost_FrostNova",
        tip="Spell circles and markings drawn on the ground (area spells, some boss effects). Off hides them."},
    {cvar="violenceLevel",kind="slider",section="graphics",min=0,max=5,step=1,title="Blood and gore",labels={[0]="None","Very low","Low","Some","More","Full"},
        tip="How much blood is shown when something is hit or dies."},
    {cvar="horizonStart",kind="slider",section="distance",min=400,max=5000,step=100,title="Far horizon starts at",
        tip="Where the far, flat backdrop of the world begins, in yards. Higher draws more of the real landscape first."},
    {cvar="skyCloudLOD",kind="slider",section="distance",min=0,max=3,step=1,title="Cloud detail",labels={[0]="Low","Medium","High","Highest"},
        tip="How detailed the clouds in the sky are."},
    {cvar="lodObjectCullSize",kind="slider",section="distance",min=0,max=40,step=1,title="Small things hidden below",
        tip="Objects smaller than this are not drawn in the distance. Lower draws more small things (rocks, plants)."},
    {cvar="entityLodDist",kind="slider",section="distance",min=0,max=100,step=5,title="Character detail distance",
        tip="How far characters and creatures keep their full detail."},
    {cvar="cameraIndirectVisibility",kind="switch",section="camera",title="Camera ignores small objects",icon="INV_Misc_Spyglass_02",
        tip="On: trees, lamp posts and other small things no longer push the camera in close; it looks past them. Size of what still counts: Camera ignores up to."},
    {cvar="cameraIndirectOffset",kind="slider",section="camera",min=1,max=10,step=1,title="Camera ignores up to",
        tip="With Camera ignores small objects on: how big an object may be before it still pushes the camera in. Higher ignores bigger things."},
    {cvar="cameraReduceUnexpectedMovement",kind="switch",section="camera",title="Steady camera",icon="Ability_Hunter_Pathfinding",
        tip="Less camera bounce and sway (for example when landing or on uneven ground)."},
    {cvar="screenshotQuality",kind="slider",section="camera",min=1,max=10,step=1,title="Screenshot quality",
        tip="Quality of screenshots saved as JPG (10 is best, larger files). Has no effect on PNG or TGA."},
    {cvar="screenshotFormat",kind="choice",section="camera",title="Screenshot format",icon="INV_Misc_Note_05",
        choices={{"jpeg","JPG","Small files, quality set above."},{"png","PNG","Lossless, larger files. Best for editing."},{"tga","TGA","Uncompressed, largest files."}},
        tip="The file type the game saves screenshots as (Screenshots folder in your WoW folder)."},
    {cvar="SpellQueueWindow",kind="slider",section="combat",min=0,max=400,step=10,title="Spell queue window (ms)",
        tip="How early you can press the next spell before the current one ends and still have it go off right after. Lower helps with high ping only if you time presses well."},
    {cvar="WorldTextScale",kind="slider",section="combat",min=.5,max=2.5,step=.1,title="Damage numbers size",
        tip="Size of the numbers that float over your target (damage, heals). 1 is the game's normal."},
    {cvar="nameplateMaxDistance",kind="slider",section="combat",min=20,max=41,step=1,title="Nameplate distance",
        tip="How far away nameplates still show, in yards. The game caps it; a higher number may be cut to its limit."},
    {cvar="nameplateOverlapV",kind="slider",section="combat",min=.5,max=2,step=.1,title="Nameplate stacking gap",
        tip="Space between stacked nameplates (when nameplates stack instead of overlap). Higher spreads them out."},
    {cvar="nameplateOccludedAlphaMult",kind="slider",section="combat",min=0,max=1,step=.1,title="Nameplates behind walls",
        tip="How visible nameplates of units you can't see (behind a wall or pillar) are. 0 hides them, 1 shows them fully."},
}
-- The options this game version has.
function G:Available()
    if self.available then return self.available end
    local list={}
    for _,o in ipairs(self.options) do if get(o.cvar)~=nil then list[#list+1]=o end end
    self.available=list
    return list
end
local function shown(o,v)
    if o.kind=="choice" then
        for _,c in ipairs(o.choices) do if c[1]==v or (v=="jpg" and c[1]=="jpeg") then return c[2] end end
        return tostring(v or "?")
    end
    v=tonumber(v)
    if not v then return "?" end
    if o.reverse then v=o.max-v end
    if o.labels then return o.labels[math.floor(v+.5)] or tostring(v) end
    if o.step<1 then return string.format("%.1f",v) end
    return tostring(math.floor(v+.5))
end
G.Shown=shown
function G:Refresh()
    if not self.frame then return end
    for _,row in ipairs(self.rows) do
        local o,v=row.option,get(row.option.cvar)
        if o.kind=="switch" then
            local on=v~=nil and v~="0"
            row.control.label:SetText(o.title..": "..(on and "On" or "Off")); FT:SetSelected(row.control,on)
        elseif o.kind=="choice" then
            row.control.label:SetText(o.title..": "..shown(o,v))
        elseif row.dragging or row.pending~=nil then
            -- Leave a slider alone while it is dragged or its value waits
            -- to be set: moving it under the mouse made it jumpy.
        else
            row.label:SetText(o.title..": "..shown(o,v))
            local n=tonumber(v)
            if n then
                if o.reverse then n=o.max-n end
                self.setting=true; row.control:SetValue(math.max(o.min,math.min(o.max,n))); self.setting=false
            end
        end
        local d=default(o.cvar)
        row.reset:SetAlpha((d~=nil and v~=nil and tonumber(d)~=tonumber(v)) and 1 or .45)
    end
end
function G:Reset(o)
    local d=default(o.cvar); if d==nil then return end
    if set(o.cvar,d) then self:Refresh() end
end
-- A slider sets the game's option once you let go (or stop moving for a
-- moment), never on every step of a drag: setting grass or terrain options
-- makes the game rebuild the scene, which made dragging choppy.
function G:Commit(row)
    local v=row.pending; row.pending=nil
    if v~=nil and set(row.option.cvar,v) then self:Refresh() end
end
function G:Later(row)
    row.changedAt=GetTime()
    C_Timer.After(.35,function()
        if row.pending~=nil and not row.dragging and GetTime()-(row.changedAt or 0)>=.3 then self:Commit(row) end
    end)
end
function G:ShowSection(key)
    self.section=key
    FT.db.gameTweaksTab=key
    for _,tab in ipairs(self.tabs or {}) do FT:SetSelected(tab,tab.key==key) end
    local y={}
    for _,row in ipairs(self.rows) do
        local on=row.option.section==key
        row.control:SetShown(on); row.reset:SetShown(on); if row.label then row.label:SetShown(on) end
        if on then
            local top=y[1] or -128; y[1]=top-42
            row.control:ClearAllPoints(); row.reset:ClearAllPoints()
            if row.label then
                row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT",24,top-8)
                row.control:SetPoint("TOPLEFT",240,top-7)
            else row.control:SetPoint("TOPLEFT",24,top) end
            row.reset:SetPoint("TOPLEFT",self.W-24-36,top)
        end
    end
    if self.all then self.all:ClearAllPoints(); self.all:SetPoint("TOPLEFT",24,(y[1] or -128)-6) end
    self:Refresh()
end
function G:Open()
    if not self.frame then
        local W,H=520,572; self.W=W
        local frame=FT:Window("ForeverToolsGameTweaks","Extra game options",W,H); self.frame=frame
        FT:BackTo(frame,"SystemGeneral")
        FT:PageInfo(frame,"Extra game options","Game settings Forever has but its settings menu doesn't show, the ones usually typed with /console.\n\nThey are the game's own settings: the game saves them for this computer (not your ForeverTools profile). Game default puts one back.")
        local hint=FT:Label(frame,"Game settings the menu doesn't show. Saved by the game.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(W-48); hint:SetTextColor(.66,.59,.48)
        self.rows={}; self.tabs={}
        local available=self:Available()
        -- One tab per section that has at least one option in this game.
        local used={}; for _,o in ipairs(available) do used[o.section]=true end
        local list={}; for _,sec in ipairs(self.sections) do if used[sec[1]] then list[#list+1]=sec end end
        local tw=#list>0 and math.floor((W-48-(#list-1)*8)/#list) or 0
        for i,sec in ipairs(list) do
            local tab=FT:QuietButton(frame,sec[2],tw,32,"generic"); tab.key=sec[1]; tab.rowStyle=false; tab.action=false
            tab.icon:SetTexture("Interface\\Icons\\"..sec[3])
            tab:SetPoint("TOPLEFT",24+(i-1)*(tw+8),-86)
            tab:SetScript("OnClick",function() self:ShowSection(sec[1]) end)
            FT:Tooltip(tab,sec[2],sec[1]=="camera" and "Camera and screenshot options." or ("Show the "..sec[2]:lower().." options."))
            self.tabs[#self.tabs+1]=tab
        end
        for _,o in ipairs(available) do
            local row={option=o}
            if o.kind=="slider" then
                -- The game's own default (or your current value) always fits on the slider.
                for _,v in ipairs({tonumber(default(o.cvar)),tonumber(get(o.cvar))}) do
                    if v and not o.reverse then o.min=math.min(o.min,v); o.max=math.max(o.max,v) end
                end
            end
            if o.kind=="switch" then
                local b=FT:QuietButton(frame,"",W-48-44,32,o.icon or "generic")
                b:SetScript("OnClick",function() local on=get(o.cvar)~="0"; if set(o.cvar,on and 0 or 1) then self:Refresh() end end)
                FT:Tooltip(b,o.title,o.tip)
                row.control=b
            elseif o.kind=="choice" then
                local b=FT:QuietButton(frame,o.title..": "..shown(o,get(o.cvar)),W-48-44,32,o.icon or "generic")
                FT:MakeChoice(b,o.choices,function() local v=get(o.cvar); return v=="jpg" and "jpeg" or v end,function(v) if set(o.cvar,v) then self:Refresh() end end)
                FT:Tooltip(b,o.title,o.tip)
                row.control=b
            else
                local l=FT:Label(frame,"",13); l:SetWidth(210); l:SetJustifyH("LEFT")
                if l.SetWordWrap then l:SetWordWrap(false) end
                local sl=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); sl:SetSize(W-48-44-216,18)
                sl:SetMinMaxValues(o.min,o.max); sl:SetValueStep(o.step); sl:SetObeyStepOnDrag(true)
                for _,k in ipairs({"Low","High","Text"}) do local t=sl[k] or (sl.GetName and sl:GetName() and _G[sl:GetName()..k]); if t and t.SetText then t:SetText("") end end
                sl:HookScript("OnMouseDown",function() row.dragging=true end)
                sl:HookScript("OnMouseUp",function() row.dragging=false; if row.pending~=nil then self:Commit(row) end end)
                sl:SetScript("OnValueChanged",function(_,v)
                    if self.setting then return end
                    v=math.floor(v/o.step+.5)*o.step
                    if o.reverse then v=o.max-v end
                    if o.step<1 then v=tonumber(string.format("%.2f",v)) end
                    l:SetText(o.title..": "..shown(o,v))
                    row.pending=v
                    -- Mouse wheel or arrow keys: set it once the moving stops.
                    if not row.dragging then self:Later(row) end
                end)
                FT:Tooltip(sl,o.title,o.tip)
                row.label,row.control=l,sl
            end
            local r=FT:QuietButton(frame,"",36,32,"reset")
            r.icon:ClearAllPoints(); r.icon:SetPoint("CENTER")
            r:SetScript("OnClick",function() row.pending=nil; self:Reset(o) end)
            FT:Tooltip(r,"Game default",function() local d=default(o.cvar); return "Back to the game's default"..(d and (" ("..shown(o,d)..")") or "").."." end)
            row.reset=r
            self.rows[#self.rows+1]=row
        end
        if #self.rows==0 then
            local none=FT:Label(frame,"This game version has none of these settings.",13); none:SetPoint("TOPLEFT",24,-92)
        else
            local all=FT:QuietButton(frame,"All back to game defaults",W-48,32,"reset"); self.all=all
            all:SetScript("OnClick",function() FT:Confirm("Put every option on this page (all tabs) back to the game's default?",function() for _,row in ipairs(self.rows) do row.pending=nil; self:Reset(row.option) end end) end)
            FT:Tooltip(all,"All back to game defaults","Every option on this page, in every tab, goes back to the game's own default. Asks first.")
        end
        local first=list[1] and list[1][1]
        local saved=FT.db.gameTweaksTab
        if saved and used[saved] then first=saved end
        if first then self:ShowSection(first) end
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("GameTweaks",G)
local events=CreateFrame("Frame"); events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent",function() if G.frame and G.frame:IsShown() then FT:Coalesce("gameTweaksRefresh",function() G:Refresh() end,.1) end end)
