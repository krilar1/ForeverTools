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
G.options={
    {cvar="ResampleAlwaysSharpen",kind="switch",title="Sharpen at full render scale",icon="INV_Misc_Spyglass_03",
        tip="The game only sharpens the picture when render scale is under 100%. On: sharpens at 100% too (uses Sharpness below)."},
    {cvar="ResampleSharpness",kind="slider",min=0,max=2,step=.1,reverse=true,title="Sharpness",
        tip="How strong the sharpening is. The game's own setting, also under Graphics > Advanced; it only shows below 100% render scale there."},
    {cvar="groundEffectDensity",kind="slider",min=16,max=256,step=16,title="Grass density",
        tip="How thick grass and flowers grow. The game's highest graphics preset stops below the top of this range. More costs frames in grassy zones."},
    {cvar="groundEffectDist",kind="slider",min=40,max=500,step=10,title="Grass distance",
        tip="How far away grass is still drawn, in yards."},
    {cvar="weatherDensity",kind="slider",min=0,max=3,step=1,title="Weather",labels={[0]="Off","Light","Medium","Full"},
        tip="How much rain and snow falls. Off also clears the dim light of storms."},
    {cvar="terrainLodDist",kind="slider",min=200,max=1000,step=50,title="Far terrain detail",
        tip="How far the ground keeps its full shape before turning coarse. Higher costs frames."},
    {cvar="lodObjectFadeScale",kind="slider",min=50,max=300,step=10,title="Scenery fade distance",
        tip="How far trees, rocks and buildings keep their full detail. 100 is the game's normal."},
    {cvar="ffxGlow",kind="switch",title="Full-screen glow",icon="Spell_Holy_HolyBolt",
        tip="The soft glow (bloom) over bright parts of the screen. Off gives a crisper, darker picture."},
    {cvar="SpellQueueWindow",kind="slider",min=0,max=400,step=10,title="Spell queue window (ms)",
        tip="How early you can press the next spell before the current one ends and still have it go off right after. Lower helps with high ping only if you time presses well."},
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
function G:Open()
    if not self.frame then
        local W,H=520,572
        local frame=FT:Window("ForeverToolsGameTweaks","Extra game options",W,H); self.frame=frame
        FT:BackTo(frame,"SystemGeneral")
        FT:PageInfo(frame,"Extra game options","Game settings Forever has but its settings menu doesn't show, the ones usually typed with /console.\n\nThey are the game's own settings: the game saves them for this computer (not your ForeverTools profile). Game default puts one back.")
        local hint=FT:Label(frame,"Game settings the menu doesn't show. Saved by the game.",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(W-48); hint:SetTextColor(.66,.59,.48)
        self.rows={}
        local y=-92
        for _,o in ipairs(self:Available()) do
            local row={option=o}
            if o.kind=="switch" then
                local b=FT:QuietButton(frame,"",W-48-44,32,o.icon or "generic"); b:SetPoint("TOPLEFT",24,y)
                b:SetScript("OnClick",function() local on=get(o.cvar)~="0"; if set(o.cvar,on and 0 or 1) then self:Refresh() end end)
                FT:Tooltip(b,o.title,o.tip)
                row.control=b
            else
                local l=FT:Label(frame,"",13); l:SetPoint("TOPLEFT",24,y-8); l:SetWidth(200); l:SetJustifyH("LEFT")
                if l.SetWordWrap then l:SetWordWrap(false) end
                local sl=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate"); sl:SetSize(W-48-44-216,18); sl:SetPoint("TOPLEFT",240,y-7)
                sl:SetMinMaxValues(o.min,o.max); sl:SetValueStep(o.step); sl:SetObeyStepOnDrag(true)
                for _,k in ipairs({"Low","High","Text"}) do local t=sl[k] or (sl.GetName and sl:GetName() and _G[sl:GetName()..k]); if t and t.SetText then t:SetText("") end end
                sl:SetScript("OnValueChanged",function(_,v)
                    if self.setting then return end
                    v=math.floor(v/o.step+.5)*o.step
                    if o.reverse then v=o.max-v end
                    -- One change per drag stop would lag behind the label: set it as
                    -- you drag, at most ten times a second.
                    FT:Coalesce("gameTweak"..o.cvar,function() if set(o.cvar,v) then self:Refresh() end end,.1)
                    l:SetText(o.title..": "..shown(o,v))
                end)
                FT:Tooltip(sl,o.title,o.tip)
                row.label,row.control=l,sl
            end
            local r=FT:QuietButton(frame,"",36,32,"reset"); r:SetPoint("TOPLEFT",W-24-36,y)
            r.icon:ClearAllPoints(); r.icon:SetPoint("CENTER")
            r:SetScript("OnClick",function() self:Reset(o) end)
            FT:Tooltip(r,"Game default",function() local d=default(o.cvar); return "Back to the game's default"..(d and (" ("..shown(o,d)..")") or "").."." end)
            row.reset=r
            self.rows[#self.rows+1]=row
            y=y-42
        end
        if #self.rows==0 then
            local none=FT:Label(frame,"This game version has none of these settings.",13); none:SetPoint("TOPLEFT",24,y)
        else
            local all=FT:QuietButton(frame,"All back to game defaults",W-48,32,"reset"); all:SetPoint("TOPLEFT",24,y-6)
            all:SetScript("OnClick",function() FT:Confirm("Put every option on this page back to the game's default?",function() for _,row in ipairs(self.rows) do self:Reset(row.option) end end) end)
            FT:Tooltip(all,"All back to game defaults","Every option on this page goes back to the game's own default. Asks first.")
        end
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("GameTweaks",G)
local events=CreateFrame("Frame"); events:RegisterEvent("CVAR_UPDATE")
events:SetScript("OnEvent",function() if G.frame and G.frame:IsShown() then FT:Coalesce("gameTweaksRefresh",function() G:Refresh() end,.1) end end)
