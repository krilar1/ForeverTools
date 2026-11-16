local _,FT=...
-- First-time setup (once per account, fresh installs only) and "What's new"
-- (once per version, existing users only). New characters never see either.
local Onboarding={}
function Onboarding:Finish(keepProfile)
    FT.db.setupDone=true
    FT.db.lastSeenVersion=FT.version
    -- Store the result in this character's profile so other characters and
    -- future sessions can reuse it (the active profile, or one named after the character).
    local profiles=FT.modules.Profiles
    if profiles and not keepProfile then
        local name=(profiles.active and profiles:Store()[profiles.active]) and profiles.active or profiles:CharacterName()
        profiles:Save(name,true,true)
    end
end
-- The first-time setup is the guided tour (Tour.lua). /ft start is a practice
-- run of it: when it ends, every setting goes back to how it was.
function Onboarding:ShowDemo()
    if InCombatLockdown() then FT:CombatOpenRequest(); return end
    FT.modules.Tour:ShowStart(false,true)
end
function Onboarding:ShowSetup(again)
    FT.modules.Tour:ShowStart(again)
end
-- "What's new": a small card panel near the top right (below the minimap),
-- not in the middle of the screen. Each note is an icon, a short title and
-- one short line. Older plain-text notes still work.
local NEWS_WIDTH, CARD_HEIGHT, CARD_GAP = 340, 40, 5
local function newsCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(NEWS_WIDTH - 40, CARD_HEIGHT)
    FT:RoundedFill(card, 0.12,0.095,0.065, 1)
    card.icon = card:CreateTexture(nil, "ARTWORK"); card.icon:SetSize(26, 26); card.icon:SetPoint("LEFT", 8, 0)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); FT:RoundIcon(card.icon)
    card.title = FT:Label(card, "", 13, true); card.title:SetPoint("TOPLEFT", 42, -6); card.title:SetWidth(NEWS_WIDTH - 92)
    card.title:SetTextColor(1, 0.84, 0.45)
    card.text = FT:Label(card, "", 11); card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2); card.text:SetWidth(NEWS_WIDTH - 92)
    card.text:SetTextColor(.88,.83,.74)
    -- "Try it": turns the new setting on (and off again) or opens its page.
    card.try = FT:QuietButton(card, "Try it", 66, 22)
    card.try:SetPoint("RIGHT", -6, 0); card.try.rowStyle = false
    if card.try.icon then card.try.icon:Hide() end
    card.try.label:ClearAllPoints(); card.try.label:SetPoint("CENTER"); card.try.label:SetJustifyH("CENTER")
    FT:Tooltip(card.try,function() return card.note and card.note.title or "" end,function()
        local note=card.note; if not note then return "" end
        if not note.try then return "Opens its page." end
        if note.try.get and note.try.get() then return "On now. Click to turn it off again." end
        return "Turns it on now. Click again to turn it off."..(note.where and (" Settings: "..note.where..".") or "")
    end)
    return card
end
function Onboarding:ShowWhatsNew()
    local entry=FT.changelog and FT.changelog[1]
    if not entry or InCombatLockdown() then return end
    if not self.news then
        local frame=FT:Window("ForeverToolsWhatsNew","What's new",NEWS_WIDTH,300); self.news=frame; frame.ignorePlacement=true
        frame.noSavePrompt=true; frame.keepAfterCombat=true
        -- Above the addon's pages (they use FULLSCREEN), so a page opened
        -- with Show me never shows through it.
        frame:SetFrameStrata("DIALOG")
        frame.homeButton:Hide()
        frame.logo=frame:CreateTexture(nil,"ARTWORK"); frame.logo:SetSize(32,32); frame.logo:SetPoint("TOPLEFT",18,-13)
        frame.logo:SetTexture("Interface\\AddOns\\ForeverTools\\Media\\MinimapIcon.tga")
        frame.titleText:ClearAllPoints(); frame.titleText:SetPoint("TOPLEFT",58,-13)
        if frame.titleText.SetFont and frame.titleText.GetFont then local font,_,flags=frame.titleText:GetFont(); if font then frame.titleText:SetFont(font,17,flags) end end
        frame.sub=FT:Label(frame,"",11); frame.sub:SetPoint("TOPLEFT",58,-33); frame.sub:SetTextColor(.66,.59,.48)
        FT:SetTitleLine(frame,54)
        frame.cards={}
        -- No icon: the text needs the whole button to stay on one line.
        local off=FT:QuietButton(frame,"Don't show again",170,26); off:SetPoint("BOTTOMLEFT",20,14)
        off.label:SetWidth(162); off.label:SetJustifyH("CENTER"); if off.label.SetWordWrap then off.label:SetWordWrap(false) end
        off:SetScript("OnClick",function() FT.modules.System:Settings().hideWhatsNew=true; frame:Hide(); FT:Toast("Turn it back on in System > General.",3) end)
        FT:Tooltip(off,"Don't show again","Stop showing this after updates.")
        local close=FT:AccentButton(frame,"Got it",110,26,"confirm"); close:SetPoint("BOTTOMRIGHT",-20,14)
        close:SetScript("OnClick",function() frame:Hide() end)
    end
    local frame=self.news
    frame.titleText:SetText("What's new")
    frame.sub:SetText("ForeverTools v"..entry.version)
    for _,card in ipairs(frame.cards) do card:Hide() end
    local y=-62
    local _,myClass=UnitClass("player")
    local index=0
    for _,note in ipairs(entry.notes) do
      -- A note for some classes only (Poised: energy users).
      if not (type(note)=="table" and note.classes and myClass and not note.classes[myClass]) then
        index=index+1
        local card=frame.cards[index] or newsCard(frame); frame.cards[index]=card
        local icon,title,text
        if type(note)=="table" then icon,title,text=note.icon,note.title,note.text
        else text=tostring(note) end
        -- A card can use one of the game's own pictures (atlas), else an icon.
        local atlas=type(note)=="table" and note.atlas
        local okAtlas=false
        if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) and card.icon.SetAtlas then
            okAtlas=pcall(card.icon.SetAtlas,card.icon,atlas)
        end
        if not okAtlas then
            card.icon:SetTexture("Interface\\Icons\\"..(icon or "INV_Misc_Note_01"))
            card.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        end
        card.title:SetText(title or ""); card.title:SetShown(title~=nil)
        card.text:ClearAllPoints()
        if title then card.text:SetPoint("TOPLEFT",card.title,"BOTTOMLEFT",0,-2) else card.text:SetPoint("LEFT",42,0) end
        card.text:SetText(text or "")
        -- A note with try={get,set} switches its setting; open="Module" shows the page.
        local try=type(note)=="table" and (note.try or note.open) and note
        card.title:SetWidth(NEWS_WIDTH - (try and 164 or 92)); card.text:SetWidth(NEWS_WIDTH - (try and 164 or 92))
        card.try:SetShown(try~=nil and try~=false); card.note=try or nil
        if try then
            local function refresh()
                local on=try.try and try.try.get and try.try.get()
                card.try.label:SetText(try.try and (on and "On" or "Try it") or "Show me")
                FT:SetSelected(card.try,on==true)
            end
            card.try:SetScript("OnClick",function()
                if InCombatLockdown() then FT:Toast("Leave combat first.",3); return end
                if try.try then
                    local on=not (try.try.get and try.try.get())
                    try.try.set(on)
                    FT:Toast(on and (try.title.." is on. Click again to turn it off.") or (try.title.." is off."),3)
                    refresh()
                else
                    -- What's new stays where it is, open and on top. The page
                    -- opens beside it when it would sit under it, so you can
                    -- look at one card after another.
                    FT:OpenModule(try.open)
                    local page=FT.modules[try.open] and FT.modules[try.open].frame
                    -- Edges in screen units (windows can have their own scale).
                    local ui=UIParent:GetEffectiveScale()
                    local function edges(f)
                        local l,r,t=f:GetLeft(),f:GetRight(),f:GetTop(); if not (l and r and t) then return end
                        local k=f:GetEffectiveScale()/ui
                        return l*k,r*k,t*k
                    end
                    local nl,nr=edges(frame)
                    local pl,pr,pt
                    if page and page:IsShown() then pl,pr,pt=edges(page) end
                    -- The group sidebar beside the page moves with it.
                    local side=page and page.ftSidebar
                    if pl and side and side.IsShown and side:IsShown() then
                        local sl,sr=edges(side)
                        if sl then pl,pr=math.min(pl,sl),math.max(pr,sr) end
                    end
                    if nl and pl and pl<nr and pr>nl then
                        local w=pr-pl
                        local screen=UIParent:GetRight() or 0
                        local x
                        if nl-8-w>=0 then x=nl-8-w elseif nr+8+w<=screen then x=nr+8 end
                        if x then
                            local pageLeft=edges(page)
                            local k=page:GetEffectiveScale()/ui
                            local shift=x-pl
                            page:ClearAllPoints(); page:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",(pageLeft+shift)/k,pt/k)
                        end
                    end
                    frame:Show(); frame:Raise()
                end
            end)
            refresh()
        end
        local height=math.max(CARD_HEIGHT,(title and 25 or 14)+(card.text:GetStringHeight() or 12))
        card:SetHeight(height)
        card:ClearAllPoints(); card:SetPoint("TOPLEFT",20,y); card:Show()
        y=y-height-CARD_GAP
      end
    end
    frame:SetHeight(-y+50)
    -- Near the top right, below the minimap and clear of the screen corner.
    frame:ClearAllPoints(); frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-240,-190)
    frame:Show()
end
-- One check per login, after profiles and settings are in place.
function Onboarding:Check()
    if self.checked or not FT.dbReady then return end
    if InCombatLockdown() then self.waiting=true; return end
    self.checked=true; self.waiting=nil
    if FT.db.setupDone==nil then
        -- Existing installs skip setup; only a fresh install gets it.
        if FT.freshInstall then self:ShowSetup(false); return end
        FT.db.setupDone=true
    end
    if FT.db.setupDone~=true then self:ShowSetup(false); return end
    -- A paused tour is offered once, at the next login.
    local tour=FT.db.tour
    if type(tour)=="table" and tour.paused and not tour.done and not tour.reminded then
        tour.reminded=true
        FT:Confirm("Continue the ForeverTools tour where you left off?",function() FT.modules.Tour:Resume() end)
        return
    end
    if FT.db.lastSeenVersion~=FT.version then
        local updated=FT.db.lastSeenVersion~=nil or not FT.freshInstall
        FT.db.lastSeenVersion=FT.version
        -- Some versions come out quietly: their notes are in the menu's
        -- What's new, but the window doesn't open by itself (1.0.0 goes out
        -- around the game's launch, when players have enough on screen).
        local quiet=FT.quietReleases and FT.quietReleases[FT.version]
        if updated and not quiet and FT.modules.System:Settings().hideWhatsNew~=true then self:ShowWhatsNew() end
    end
end
FT:RegisterModule("Onboarding",Onboarding)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then C_Timer.After(3,function() Onboarding:Check() end)
    elseif Onboarding.waiting then C_Timer.After(1,function() Onboarding:Check() end) end
end)
