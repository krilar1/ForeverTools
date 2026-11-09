local _,FT=...
-- A "Move elements" button in the game's own menu (Esc), right above
-- Macros, with the ForeverTools logo in front of its text. It starts Move
-- elements, the same as the button on the ForeverTools menus. Setting:
-- System > General > "Move elements in the game menu" (on at first).
local GM={}
local LOGO="Interface\\AddOns\\"..FT.name.."\\Media\\MinimapIcon.tga"
function GM:On()
    local s=FT.dbReady and FT.modules.System and FT.modules.System:Settings()
    return not s or s.gameMenuButton~=false
end
-- The game rebuilds its menu every time it opens; the buttons come from a
-- pool, so the logo is put back on ours and taken off any other.
function GM:Add(menu)
    if not menu or not menu.AddButton or not menu.buttons then return end
    for _,b in ipairs(menu.buttons) do if b.ftLogo then b.ftLogo:Hide() end end
    if not self:On() then return end
    local after
    for _,b in ipairs(menu.buttons) do
        local text=b.GetText and b:GetText()
        if text==(MACROS or "Macros") then after=b end
    end
    local ok,button=pcall(menu.AddButton,menu,"Move elements",function()
        PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 0)
        HideUIPanel(menu)
        local movers=FT.modules.Movers
        if InCombatLockdown() then FT:Toast("Move elements after the fight.",3) return end
        if movers and movers.Start then movers:Start() end
    end)
    if not ok or not button then return end
    -- Right above Macros (away from Log Out), in the same group of buttons.
    if after and after.layoutIndex then
        button.layoutIndex=after.layoutIndex-.5; button.topPadding=nil
        if menu.MarkDirty then menu:MarkDirty() end
    end
    if not button.ftLogo then
        local logo=button:CreateTexture(nil,"OVERLAY"); logo:SetSize(18,18); logo:SetTexture(LOGO)
        button.ftLogo=logo
    end
    local fs=button.GetFontString and button:GetFontString()
    button.ftLogo:ClearAllPoints()
    if fs then button.ftLogo:SetPoint("RIGHT",fs,"LEFT",-4,0) else button.ftLogo:SetPoint("LEFT",10,0) end
    button.ftLogo:Show()
    self.button=button
end
function GM:Hook()
    if self.hooked or not GameMenuFrame or type(GameMenuFrame.InitButtons)~="function" or not hooksecurefunc then return end
    self.hooked=true
    hooksecurefunc(GameMenuFrame,"InitButtons",function(menu) pcall(GM.Add,GM,menu) end)
end
FT:RegisterModule("GameMenu",GM)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent",function() GM:Hook() end)
