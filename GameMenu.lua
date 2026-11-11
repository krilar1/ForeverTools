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
-- The game's macro window: the ForeverTools logo in its title bar opens
-- the ForeverTools macro editor (and closes the game's window).
function GM:MacroButton()
    local frame=_G.MacroFrame
    if self.macroButton or not frame then return end
    -- Not a child of the game's window: window skins restyle every texture
    -- inside it, and our logo came out invisible. It follows the window.
    local b=CreateFrame("Button","ForeverToolsMacroFrameButton",UIParent); self.macroButton=b
    b:SetSize(24,24)
    -- Above anything a skin or the window puts on top.
    local function place()
        -- In front of the dark window skin, whatever layer it uses.
        b:SetFrameStrata("FULLSCREEN_DIALOG")
        b:SetFrameLevel(50)
        b:ClearAllPoints()
        -- The close button you can see (the old name can be a hidden one).
        local close
        for _,c in ipairs({frame.CloseButton,_G.MacroFrameCloseButton}) do if c and c.IsVisible and c:IsVisible() then close=c; break end end
        if close then b:SetPoint("RIGHT",close,"LEFT",-4,0) else b:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-34,-6) end
        b.icon:SetTexture(LOGO); b.icon:SetAlpha(1); b.icon:Show()
        b:SetShown(frame:IsShown())
    end
    frame:HookScript("OnShow",function() place(); C_Timer.After(0,place) end)
    frame:HookScript("OnHide",function() b:Hide() end)
    b.icon=b:CreateTexture(nil,"OVERLAY"); b.icon:SetAllPoints(); b.icon:SetTexture(LOGO)
    local hi=b:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(); hi:SetTexture(LOGO); hi:SetBlendMode("ADD"); hi:SetAlpha(.5)
    b:SetScript("OnClick",function()
        if InCombatLockdown() then FT:Toast("Open the ForeverTools macros after the fight.",3) return end
        HideUIPanel(frame)
        FT:OpenModule("MacroForge")
    end)
    b:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT"); GameTooltip:SetText("ForeverTools macros",1,.82,0)
        GameTooltip:AddLine("Open the ForeverTools macro editor: ready-made class macros, spell ranks, mouseover and more.",.96,.93,.86,true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() GameTooltip:Hide() end)
    place()
end
FT:RegisterModule("GameMenu",GM)
local events=CreateFrame("Frame"); events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED" then if addon=="Blizzard_MacroUI" then pcall(GM.MacroButton,GM) end return end
    GM:Hook(); pcall(GM.MacroButton,GM)
end)
