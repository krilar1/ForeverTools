local _,FT=...
-- Personal resource display (Appearance > Personal resources). The game's
-- display above your character stacks health, power (energy, rage, mana),
-- an extra power bar (a druid's mana in a form) and class points (combo
-- points) in a fixed order. Here you pick the order and the text on each bar.
--   * Order: after the game places the parts (it does whenever one is shown,
--     hidden or resized), they are stacked again in your order, with the same
--     gap. Untouched until you change the order; Reset gives the game's back.
--   * Text: the game writes both a percent and a number on each bar. Each bar
--     can keep that, or show only one of them, or no text. Only text is hidden
--     after the game writes it; its numbers are never read, so nothing here
--     touches values the game hides in a fight.
--   * Which parts show at all is the game's Edit Mode setting (Personal
--     Resource Display). The eye on each row only changes the preview.
--   * Plain frames only (not protected), so it works in combat too.
local P={}
local PARTS={"health","power","alt","class"}
local TEXT_PARTS={"health","power","alt"}
local MODES={game=true,value=true,percent=true,none=true}
local MODE_LABEL={game="Number and percent",value="Number only",percent="Percent only",none="No text"}
local function busy() return InCombatLockdown and InCombatLockdown() end
local function validOrder(order)
    if type(order)~="table" or #order~=#PARTS then return false end
    local seen={}
    for _,part in ipairs(order) do
        if type(part)~="string" or seen[part] then return false end
        seen[part]=true
    end
    for _,part in ipairs(PARTS) do if not seen[part] then return false end end
    return true
end
function P:Settings()
    if type(FT.db.personal)~="table" then FT.db.personal={} end
    local s=FT.db.personal
    if s.order~=nil and not validOrder(s.order) then s.order=nil end
    if type(s.text)~="table" then s.text={} end
    for _,part in ipairs(TEXT_PARTS) do if not MODES[s.text[part]] then s.text[part]="game" end end
    if type(s.preview)~="table" then s.preview={} end
    return s
end
-- The order in use: yours, or the game's own.
function P:Order() return self:Settings().order or {unpack(PARTS)} end
local function display() return PersonalResourceDisplayFrame end
local function partFrame(f,part)
    if part=="health" then return f.HealthBarsContainer
    elseif part=="power" then return f.PowerBar
    elseif part=="alt" then return f.AlternatePowerBar
    elseif part=="class" then return f.ClassFrameContainer end
end
local function textBar(f,part)
    if part=="health" then return f.healthbar or (f.HealthBarsContainer and f.HealthBarsContainer.healthBar)
    elseif part=="power" then return f.PowerBar
    elseif part=="alt" then return f.AlternatePowerBar end
end
-- The class points draw past their small container: the next part goes
-- under the points themselves.
local function bottomOf(f,part)
    if part=="class" and f.classFrame and f.classFrame:IsShown() then return f.classFrame end
    return partFrame(f,part)
end
local function shownPart(f,part)
    local bar=partFrame(f,part)
    if not bar or not bar:IsShown() then return false end
    if part=="class" and f.HasClassInfo then local ok,has=pcall(f.HasClassInfo,f); if ok and not has then return false end end
    return true
end
-- Stack the shown parts in your order.
function P:Layout()
    local f=display()
    if not f or self.laying then return end
    local s=self:Settings()
    if not s.order then return end
    self.laying=true
    local pad=4
    if f.GetBarPadding then local ok,value=pcall(f.GetBarPadding,f); if ok and type(value)=="number" then pad=value end end
    local prev
    for _,part in ipairs(s.order) do
        if shownPart(f,part) then
            local bar=partFrame(f,part)
            local y=part=="class" and (tonumber(bar.yOffset) or 0) or 0
            bar:ClearAllPoints()
            if prev then bar:SetPoint("TOP",bottomOf(f,prev),"BOTTOM",0,y-pad)
            else bar:SetPoint("TOP",f,"TOP",0,y) end
            prev=part
        end
    end
    self.laying=false
end
-- After the game writes a bar's text: hide the parts you don't want.
function P:Text(bar)
    local part=self.textParts and self.textParts[bar]
    if not part then return end
    local mode=self:Settings().text[part]
    if mode=="game" then return end
    -- Only text the game shows is hidden, and remembered, so a later
    -- change can give exactly that back.
    self.hiddenText=self.hiddenText or {}
    local function hide(text) if text and text:IsShown() then text:Hide(); self.hiddenText[text]=true end end
    if mode=="none" then
        for _,field in ipairs({"TextString","LeftText","RightText"}) do hide(bar[field]) end
    elseif mode=="value" then
        hide(bar.LeftText)
    elseif mode=="percent" then
        -- Both shown: the number is the right one. One line alone stays.
        if bar.RightText and bar.LeftText and bar.LeftText:IsShown() then hide(bar.RightText) end
    end
end
-- Hook the display once it exists (it can load after us).
function P:Hook()
    local f=display()
    if not f or self.hooked then return f~=nil end
    self.hooked=true
    for _,method in ipairs({"UpdateAdditionalBarAnchors","UpdatePowerBarAnchor"}) do
        if type(f[method])=="function" then hooksecurefunc(f,method,function() P:Layout() end) end
    end
    self.textParts={}
    for _,part in ipairs(TEXT_PARTS) do
        local bar=textBar(f,part)
        if bar then
            self.textParts[bar]=part
            if type(bar.UpdateTextStringWithValues)=="function" then hooksecurefunc(bar,"UpdateTextStringWithValues",function(owner) P:Text(owner) end) end
        end
    end
    -- New class points (first login on a class): their frame art follows the skin.
    if type(f.SetupClassBar)=="function" then
        hooksecurefunc(f,"SetupClassBar",function()
            local skins=FT.modules.IconStyles
            if skins and skins.ApplyPersonalArtwork then FT:Coalesce("personalArt",function() skins:ApplyPersonalArtwork() end,.1) end
            P:Layout()
        end)
    end
    return true
end
-- Redo text after a change: give back what we hid, then hide again by the
-- current settings. The game's own text update is never called: it would
-- hide the text until you point at the bar (the game's mouseover rule).
function P:RefreshText(textChanged)
    local f=display(); if not f then return end
    if textChanged then
        for text in pairs(self.hiddenText or {}) do text:Show() end
        self.hiddenText={}
    end
    for bar in pairs(self.textParts or {}) do self:Text(bar) end
end
function P:Apply(textChanged)
    if not FT.dbReady then return end
    self:Settings()
    if self:Hook() then
        local f=display()
        if self:Settings().order then self:Layout()
        elseif self.wasOrdered and not busy() then
            -- Back to the game's order: health goes back to the top (the game
            -- never moves it), then the game places the rest again.
            if f.HealthBarsContainer then f.HealthBarsContainer:ClearAllPoints(); f.HealthBarsContainer:SetPoint("TOP",f,"TOP") end
            if f.UpdatePowerBarAnchor then pcall(f.UpdatePowerBarAnchor,f) end
            if f.UpdateAdditionalBarAnchors then pcall(f.UpdateAdditionalBarAnchors,f) end
        end
        self.wasOrdered=self:Settings().order~=nil
        self:RefreshText(textChanged)
    end
    self:Refresh()
end
function P:Move(part,step)
    local order=self:Order()
    local at; for i,p in ipairs(order) do if p==part then at=i end end
    local to=at and at+step
    if not to or to<1 or to>#order then return end
    order[at],order[to]=order[to],order[at]
    self:Settings().order=order
    self:Apply()
end
function P:ResetOrder() self:Settings().order=nil; self:Apply() end
-- Names for your class.
local function powerName()
    local token=UnitPowerType and select(2,UnitPowerType("player"))
    if type(token)~="string" or (issecretvalue and issecretvalue(token)) then return "Power" end
    return ({ENERGY="Energy",RAGE="Rage",MANA="Mana",FOCUS="Focus",RUNIC_POWER="Runic power"})[token] or "Power"
end
local function classPointsName()
    local _,class=UnitClass("player")
    return ({ROGUE="Combo points",DRUID="Combo points",PALADIN="Holy power",WARLOCK="Soul shards",MAGE="Arcane charges",MONK="Chi",DEATHKNIGHT="Runes",EVOKER="Essence"})[class] or "Class points"
end
function P:Label(part)
    if part=="health" then return "Health"
    elseif part=="power" then return powerName().." bar"
    elseif part=="alt" then return "Extra power bar"
    else return classPointsName() end
end
-- What the game shows now (Edit Mode), for the preview's starting eyes.
function P:GameShows(part)
    local f=display()
    if not f then return part~="alt" end
    if part=="health" then return not f.hideHealth
    elseif part=="power" then return not f.hidePower
    elseif part=="alt" then local ok,has=pcall(f.HasAlternatePowerBar or function() return false end,f); return not f.hideAltPower and ok and has==true
    else local ok,has=pcall(f.HasClassInfo or function() return false end,f); return not f.hideClassInfo and ok and has==true end
end
function P:Previewed(part)
    local v=self:Settings().preview[part]
    if v==nil then return self:GameShows(part) end
    return v
end
-- Settings page ---------------------------------------------------------------
local BAR={health={.1,.75,.2},alt={.15,.35,.95}}
local function powerColor()
    local token=UnitPowerType and select(2,UnitPowerType("player"))
    local c=type(token)=="string" and not (issecretvalue and issecretvalue(token)) and PowerBarColor and PowerBarColor[token]
    if c and c.r then return {c.r,c.g,c.b} end
    return {.95,.85,.1}
end
-- The color and texture the game's own bar uses now, so the preview looks
-- like your bar in the world (green, class colored, mana blue, ...).
local function liveLook(part)
    local f=display(); local bar=f and textBar(f,part)
    if not (bar and bar.GetStatusBarColor) then return end
    local r,g,b=bar:GetStatusBarColor()
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then return end
    if type(r)~="number" or type(g)~="number" or type(b)~="number" then return end
    local tex=bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    local file=tex and tex.GetTexture and tex:GetTexture()
    local atlas=tex and tex.GetAtlas and tex:GetAtlas()
    if issecretvalue and (issecretvalue(file) or issecretvalue(atlas)) then file,atlas=nil,nil end
    return {r,g,b},(type(atlas)=="string" and atlas~="" and atlas) or nil,(type(file)=="string" or type(file)=="number") and file or nil
end
local function paintFill(row,part,fallback)
    local color,atlas,file=liveLook(part)
    color=color or fallback
    if atlas then row.fill:SetAtlas(atlas) elseif file then row.fill:SetTexture(file) else row.fill:SetColorTexture(1,1,1) end
    row.fill:SetVertexColor(unpack(color))
end
function P:PaintPreview()
    local box=self.preview; if not box then return end
    local s=self:Settings()
    local y=-14; local any=false
    for _,row in pairs(box.rows) do row:Hide() end
    for _,part in ipairs(self:Order()) do
        if self:Previewed(part) then
            local row=box.rows[part]; any=true
            row:ClearAllPoints(); row:SetPoint("TOP",box,"TOP",0,y); row:Show()
            if part=="class" then
                y=y-row:GetHeight()-8
            else
                local mode=s.text[part]
                local value=part=="health" and "1,250" or "100"
                row.left:SetText((mode=="game" or mode=="percent") and "100%" or "")
                row.right:SetText((mode=="game" or mode=="value") and value or "")
                paintFill(row,part,part=="power" and powerColor() or BAR[part])
                y=y-row:GetHeight()-6
            end
        end
    end
    box.empty:SetShown(not any)
end
function P:Refresh()
    if not self.frame then return end
    local s=self:Settings()
    for i,part in ipairs(self:Order()) do
        local row=self.rows[part]
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",24,-124-(i-1)*40)
        local game=self:GameShows(part)
        row.name.label:SetText(self:Label(part)..(game and "" or " · off"))
        local eye=self:Previewed(part)
        FT:SetSelected(row.eye,eye); row.eye.icon:SetDesaturated(not eye); row.eye.icon:SetAlpha(eye and 1 or .45)
        row.up:SetEnabled(i>1); row.up:SetAlpha(i>1 and 1 or .4)
        row.down:SetEnabled(i<#PARTS); row.down:SetAlpha(i<#PARTS and 1 or .4)
    end
    for _,part in ipairs(TEXT_PARTS) do
        local d=self.textChoices[part]
        d.value=s.text[part]; d.label:SetText(self:Label(part)..": "..MODE_LABEL[s.text[part]])
    end
    self.reset:SetEnabled(s.order~=nil); self.reset:SetAlpha(s.order and 1 or .45)
    self:PaintPreview()
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
function P:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsPersonal","Game resource bars",620,560); self.frame=frame
        FT:PageInfo(frame,"Personal resources","The game's health and power display above your character. Pick the order of its parts and the text on each bar.\n\nWhich parts show is set in Edit Mode.")
        local hint=FT:Label(frame,"Changes the game's Personal Resource Display (turn it on in Edit Mode).",12); hint:SetPoint("TOPLEFT",24,-64); hint:SetWidth(572); hint:SetTextColor(.66,.59,.48)
        local head=FT:Label(frame,"Order (top to bottom)",14,true); head:SetPoint("TOPLEFT",24,-96); FT:SectionHeading(head,nil,170)
        self.rows={}
        for _,part in ipairs(PARTS) do
            local row=CreateFrame("Frame",nil,frame); row:SetSize(300,32)
            row.eye=FT:QuietButton(row,"",32,32,"INV_Misc_Spyglass_02"); row.eye:SetPoint("LEFT")
            row.eye:SetScript("OnClick",function() local s=self:Settings(); s.preview[part]=not self:Previewed(part); self:Refresh() end)
            FT:Tooltip(row.eye,"Show in preview","Show it in the preview only. \"off\": hidden in Edit Mode.")
            row.name=FT:QuietButton(row,"",156,32); row.name:SetPoint("LEFT",row.eye,"RIGHT",6,0); row.name:EnableMouse(false)
            row.name.label:ClearAllPoints(); row.name.label:SetPoint("LEFT",12,0); row.name.label:SetFont(FT.bodyFont,13,"")
            row.up=FT:QuietButton(row,"Up",44,32); row.up:SetPoint("LEFT",row.name,"RIGHT",6,0)
            row.up:SetScript("OnClick",function() self:Move(part,-1) end)
            FT:Tooltip(row.up,"Move up","Move this part one step up.")
            row.down=FT:QuietButton(row,"Down",52,32); row.down:SetPoint("LEFT",row.up,"RIGHT",4,0)
            row.down:SetScript("OnClick",function() self:Move(part,1) end)
            FT:Tooltip(row.down,"Move down","Move this part one step down.")
            self.rows[part]=row
        end
        self.reset=FT:QuietButton(frame,"Use the game's order",300,32,"reset"); self.reset:SetPoint("TOPLEFT",24,-290)
        self.reset:SetScript("OnClick",function() self:ResetOrder() end)
        FT:Tooltip(self.reset,"Game's order","The game's own order.")
        -- Preview: the parts in your order, as eyes allow.
        local phead=FT:Label(frame,"Preview",14,true); phead:SetPoint("TOPLEFT",340,-96); FT:SectionHeading(phead,nil,180)
        local box=CreateFrame("Frame",nil,frame); box:SetSize(256,130); box:SetPoint("TOPLEFT",340,-124); FT:Panel(box); FT:Paint(box,{.03,.025,.02,1},{.3,.25,.18,1})
        box.rows={}
        for _,part in ipairs({"health","power","alt"}) do
            local row=CreateFrame("Frame",nil,box); row:SetSize(216,part=="alt" and 12 or 16)
            row.back=row:CreateTexture(nil,"BACKGROUND"); row.back:SetAllPoints(); row.back:SetColorTexture(0,0,0,.85)
            row.fill=row:CreateTexture(nil,"ARTWORK"); row.fill:SetPoint("TOPLEFT",1,-1); row.fill:SetPoint("BOTTOMRIGHT",-1,1)
            row.fill:SetColorTexture(unpack(BAR[part] or {.95,.85,.1}))
            row.left=FT:Label(row,"",11); row.left:SetPoint("LEFT",5,0); row.left:SetTextColor(1,1,1)
            row.right=FT:Label(row,"",11); row.right:SetPoint("RIGHT",-5,0); row.right:SetTextColor(1,1,1)
            box.rows[part]=row
        end
        local points=CreateFrame("Frame",nil,box); points:SetSize(5*22,20)
        for i=1,5 do
            local dot=points:CreateTexture(nil,"ARTWORK"); dot:SetSize(18,18); dot:SetPoint("LEFT",(i-1)*22,0)
            dot:SetTexture("Interface\\AddOns\\"..FT.name.."\\Media\\Rounded.tga"); dot:SetVertexColor(i<=3 and .85 or .2,i<=3 and .15 or .18,i<=3 and .1 or .16)
        end
        box.rows.class=points
        box.empty=FT:Label(box,"Nothing to show: every bar is hidden here.",12); box.empty:SetPoint("CENTER"); box.empty:SetTextColor(.66,.59,.48)
        self.preview=box
        local note=FT:Label(frame,"The spyglass on a row shows or hides that bar here only. Your bars in the game don't change.",12)
        note:SetPoint("TOPLEFT",340,-264); note:SetWidth(256); note:SetTextColor(.66,.59,.48)
        -- Text on each bar.
        local thead=FT:Label(frame,"Text on the bars",14,true); thead:SetPoint("TOPLEFT",24,-372); FT:SectionHeading(thead,nil,440)
        self.textChoices={}
        for i,part in ipairs(TEXT_PARTS) do
            local d=FT:Dropdown(frame,280,function()
                local out={}
                for _,mode in ipairs({"game","value","percent","none"}) do
                    out[#out+1]={value=mode,label=MODE_LABEL[mode],icon="Interface\\Icons\\INV_Misc_Note_01",
                        tooltip=({game="Percent left, number right.",value="Only the number.",percent="Only the percent.",none="No text on this bar."})[mode]}
                end
                return out
            end,function(value) self:Settings().text[part]=value; self:Apply(true) end,"fonts")
            d:SetHeight(32)
            d:SetPoint("TOPLEFT",i==2 and 316 or 24,i==3 and -440 or -400)
            FT:Tooltip(d,"Text","Which text this bar shows.")
            self.textChoices[part]=d
        end
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("PersonalResource",P)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if not FT.dbReady then return end
    if event=="ADDON_LOADED" and name~="Blizzard_PersonalResourceDisplay" then return end
    P:Apply(true)
end)
