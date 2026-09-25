local _,FT=...
-- Low-rank marker: a small amber corner on your own action buttons whose spell
-- rank is lower than one you have learned. Self only: no chat, sound, popup or
-- combat log. Settings live with the other rank options on the Buff reminders page.
local Marker={marks={},flagged={}}
local bars={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarLeftButton","MultiBarRightButton","MultiBar5Button","MultiBar6Button","MultiBar7Button"}
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
function Marker:Settings() return FT.modules.BuffReminder:Settings() end
function Marker:Enabled() return self:Settings().rankMarker==true end
-- Highest learned rank per spell name, from the live spellbook.
function Marker:LearnedRanks()
    local best={}
    local book=FT.modules.CustomKeybinds
    local ok,spells=pcall(book.LearnedSpells,book)
    if not ok or type(spells)~="table" then return best end
    for _,spell in ipairs(spells) do
        if readable(spell.name) and type(spell.name)=="string" then
            local _,rank=FT.BuffRanks:NameRank(spell.name,spell.rank or spell.label)
            rank=rank or FT.BuffRanks:SpellRank(spell.value)
            if rank and rank>(best[spell.name] or 0) then best[spell.name]=rank end
        end
    end
    return best
end
function Marker:ActionSpell(button)
    local action=button and button.action
    if not readable(action) or type(action)~="number" or not GetActionInfo then return end
    local ok,kind,id=pcall(GetActionInfo,action)
    if not ok or not readable(kind) or kind~="spell" or not readable(id) or type(id)~="number" then return end
    local name=C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not readable(name) or type(name)~="string" then return end
    return name,FT.BuffRanks:SpellRank(id)
end
function Marker:Mark(button)
    local mark=self.marks[button]
    if not mark then
        -- Plain textures only (no new artwork): a thin dark outline and an amber fill.
        local icon=button.icon or button.Icon or button
        local outline=button:CreateTexture(nil,"OVERLAY",nil,6)
        outline:SetColorTexture(0,0,0,.9); outline:SetSize(8,8); outline:SetPoint("TOPLEFT",icon,"TOPLEFT",1,-1)
        local fill=button:CreateTexture(nil,"OVERLAY",nil,7)
        fill:SetColorTexture(1,.72,.2,.95); fill:SetSize(6,6); fill:SetPoint("CENTER",outline,"CENTER")
        mark={outline=outline,fill=fill}; self.marks[button]=mark
    end
    return mark
end
function Marker:Update()
    self.queued=false
    local enabled=FT.dbReady and self:Enabled()
    local s=enabled and self:Settings()
    local best=enabled and (self.best or self:LearnedRanks())
    if enabled then self.best=best end
    self.flagged={}
    for _,prefix in ipairs(bars) do
        for i=1,12 do
            local button=_G[prefix..i]
            if button then
                local low
                if enabled then
                    local name,rank=self:ActionSpell(button)
                    local top=name and best[name]
                    local ignored=name and type(s.ignoredRanks)=="table" and s.ignoredRanks[name]
                    if rank and top and rank<top and not ignored and not (rank==1 and s.ignoreRankOne) then
                        low={name=name,rank=rank,best=top}; self.flagged[name]=low
                    end
                end
                if low and InCombatLockdown() and not self.marks[button] then
                    self.pendingCombat=true -- add new marks once combat ends
                elseif low then
                    local mark=self:Mark(button); mark.outline:Show(); mark.fill:Show(); button.ftLowRank=low
                elseif self.marks[button] then
                    self.marks[button].outline:Hide(); self.marks[button].fill:Hide(); button.ftLowRank=nil
                end
            end
        end
    end
end
function Marker:Queue(learned)
    if learned then self.best=nil end
    if self.queued then return end
    self.queued=true
    C_Timer.After(.2,function() self:Update() end)
end
function Marker:Apply() self.best=nil; self:Update() end
-- Spells currently flagged on your bars plus ones you have chosen to ignore.
function Marker:ExceptionChoices()
    local s=self:Settings(); local list={}; local seen={}
    for name,info in pairs(self.flagged) do
        seen[name]=true
        list[#list+1]={value=name,label="Ignore "..name.." (rank "..info.rank.." of "..info.best..")",icon="Interface\\Icons\\INV_Misc_Book_09"}
    end
    for name in pairs(type(s.ignoredRanks)=="table" and s.ignoredRanks or {}) do
        if not seen[name] then list[#list+1]={value=name,label="Stop ignoring "..name,icon="Interface\\Icons\\INV_Misc_Book_11"} end
    end
    table.sort(list,function(a,b) return a.label<b.label end)
    if #list==0 then list[1]={value="",label="No low-rank spells on your bars",icon="Interface\\Icons\\INV_Misc_QuestionMark"} end
    return list
end
function Marker:ToggleIgnore(name)
    if type(name)~="string" or name=="" then return end
    local s=self:Settings()
    if type(s.ignoredRanks)~="table" then s.ignoredRanks={} end
    s.ignoredRanks[name]=not s.ignoredRanks[name] or nil
    FT.modules.BuffReminder:Apply()
end
FT:RegisterModule("RankMarker",Marker)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","UPDATE_BONUS_ACTIONBAR","UPDATE_SHAPESHIFT_FORM","SPELLS_CHANGED","LEARNED_SPELL_IN_SKILL_LINE"}) do pcall(events.RegisterEvent,events,event) end
events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    Marker:Queue(event=="SPELLS_CHANGED" or event=="LEARNED_SPELL_IN_SKILL_LINE" or event=="PLAYER_ENTERING_WORLD")
end)
if GameTooltip and GameTooltip.SetAction and hooksecurefunc then
    hooksecurefunc(GameTooltip,"SetAction",function(tip,slot)
        if not Marker:Enabled() then return end
        for button in pairs(Marker.marks) do
            local low=button.ftLowRank
            if low and button.action==slot then
                tip:AddLine("Rank "..low.best.." learned (this button uses rank "..low.rank..")",1,.72,.2)
                tip:Show(); return
            end
        end
    end)
end
