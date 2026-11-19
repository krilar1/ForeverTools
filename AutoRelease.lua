local _,FT=...
-- Auto release (PvP, off by default). When you die in a battleground, your
-- spirit is released for you, so you go to the graveyard and the next
-- spirit wave without clicking.
--   * Battlegrounds only: never in arenas, dungeons or the open world.
--   * By default it waits if you can bring yourself back (a soulstone, a
--     shaman's Reincarnation and the like): then you choose yourself.
--   * Half a second after death, and only if you are still dead and not yet
--     a ghost, so the game's own death window has opened first.
local A={}
local DELAY=.5
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
function A:Settings()
    if type(FT.db.autoRelease)~="table" then FT.db.autoRelease={} end
    local s=FT.db.autoRelease
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.keepSelfRes)~="boolean" then s.keepSelfRes=true end
    return s
end
-- In a battleground right now (not an arena).
function A:InBattleground()
    if not IsInInstance then return false end
    local ok,inside,kind=pcall(IsInInstance)
    return ok and plain(kind) and inside and kind=="pvp" or false
end
-- Can you bring yourself back (soulstone, Reincarnation, ...)?
function A:CanSelfRes()
    if C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions then
        local ok,options=pcall(C_DeathInfo.GetSelfResurrectOptions)
        if ok and plain(options) and type(options)=="table" and #options>0 then return true end
    end
    if HasSoulstone then
        local ok,text=pcall(HasSoulstone)
        if ok and plain(text) and text then return true end
    end
    return false
end
function A:Release()
    if not RepopMe then return false end
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    local ghost=UnitIsGhost and UnitIsGhost("player")
    if not plain(dead) or not plain(ghost) or not dead or ghost then return false end
    local ok=pcall(RepopMe)
    return ok
end
function A:OnDeath()
    local s=self:Settings()
    if not s.enabled or not self:InBattleground() then return end
    if s.keepSelfRes and self:CanSelfRes() then
        FT:Toast("Not released: you can resurrect yourself.",3)
        return
    end
    local token={}; self.token=token
    C_Timer.After(DELAY,function()
        if self.token~=token or not self:Settings().enabled or not self:InBattleground() then return end
        if s.keepSelfRes and self:CanSelfRes() then return end
        self:Release()
    end)
end
function A:Apply()
    local s=self:Settings()
    if s.enabled then self.events:RegisterEvent("PLAYER_DEAD") else self.events:UnregisterEvent("PLAYER_DEAD") end
    self:Refresh()
end
-- Settings page (PvP > Auto release).
function A:Refresh()
    if not self.frame or not self.toggle then return end
    local s=self:Settings()
    self.toggle.label:SetText("Auto release: "..(s.enabled and "On" or "Off")); FT:SetSelected(self.toggle,s.enabled)
    self.selfRes.label:SetText("Wait if I can resurrect myself: "..(s.keepSelfRes and "On" or "Off")); FT:SetSelected(self.selfRes,s.keepSelfRes)
    self.selfRes:SetAlpha(s.enabled and 1 or .5)
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
-- Its settings sit on the Battlegrounds page (QueueTimer), under their own
-- header: Build puts them there, starting at y.
A.redirect=true
function A:Open() FT:OpenModule("QueueTimer"); self.frame=FT.modules.QueueTimer and FT.modules.QueueTimer.frame end
function A:Build(frame,y)
    if self.toggle then return end
    self.frame=frame
    do
        self.toggle=FT:AccentButton(frame,"",492,34,"Spell_Holy_Resurrection"); self.toggle:SetPoint("TOPLEFT",24,y)
        self.toggle:SetScript("OnClick",function() local s=self:Settings(); s.enabled=not s.enabled; self:Apply() end)
        FT:Tooltip(self.toggle,"Auto release","Release your spirit when you die in a battleground.")
        self.selfRes=FT:QuietButton(frame,"",492,32,"Spell_Holy_Resurrection"); self.selfRes:SetPoint("TOPLEFT",24,y-46)
        self.selfRes:SetScript("OnClick",function() local s=self:Settings(); s.keepSelfRes=not s.keepSelfRes; self:Refresh() end)
        FT:Tooltip(self.selfRes,"Wait if I can resurrect myself","Don't release when you can come back yourself (soulstone, Reincarnation).")
    end
end
FT:RegisterModule("AutoRelease",A)
A.events=CreateFrame("Frame")
A.events:RegisterEvent("PLAYER_LOGIN")
A.events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" then A:Apply()
    elseif event=="PLAYER_DEAD" then A:OnDeath() end
end)
