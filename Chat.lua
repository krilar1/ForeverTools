local _,FT=...
local Chat={tracked={}}
local options={{"social","Social button"},{"tabs","Chat tabs"},{"icons","Side buttons"},{"input","Input box border"}}
local function overBox(object,padding)
    if not object then return false end
    if object.IsMouseOver and object:IsMouseOver() then return true end
    if not object.GetLeft or not object.GetRight or not object.GetTop or not object.GetBottom then return false end
    local left,right,top,bottom=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
    if not left or not right or not top or not bottom then return false end
    local x,y=GetCursorPosition(); local scale=object:GetEffectiveScale()
    x,y=x/scale,y/scale
    return x>=left-padding and x<=right+padding and y>=bottom-padding and y<=top+padding
end
function Chat:Settings()
    if type(FT.db.chat)~="table" then FT.db.chat={} end
    if FT.db.chat.social==nil then FT.db.chat.social="hover" end
    return FT.db.chat
end
function Chat:Track(object,key,owner)
    if not object or not object.SetAlpha then return end
    local rec=self.tracked[object]
    if not rec then
        rec={alpha=object:GetAlpha(),key=key,owner=owner}; self.tracked[object]=rec
        if object.EnableMouse and object.IsMouseEnabled then rec.mouse=object:IsMouseEnabled() end
        if hooksecurefunc then
            hooksecurefunc(object,"SetAlpha",function()
                if not self.painting and FT.dbReady then self:Paint() end
            end)
        end
    end
end
function Chat:Paint()
    if self.painting then return end
    self.painting=true
    local s=self:Settings()
    local tabsHovered=false
    for object,rec in pairs(self.tracked) do
        if rec.key=="tabs" and ((object.IsMouseOver and object:IsMouseOver()) or (rec.owner and rec.owner.IsMouseOver and rec.owner:IsMouseOver())) then tabsHovered=true end
    end
    for object,rec in pairs(self.tracked) do
        local mode=s[rec.key] or "show"
        local hover=rec.key=="tabs" and tabsHovered or (rec.key=="input" and rec.owner and rec.owner.IsMouseOver and rec.owner:IsMouseOver())
        if object.IsMouseOver and object:IsMouseOver() then hover=true end
        if rec.key=="icons" or rec.key=="social" then hover=overBox(object,8) end
        local visible=mode=="show" or (mode=="hover" and hover)
        object:SetAlpha(visible and (mode=="hover" and 1 or rec.alpha) or 0)
        if rec.mouse~=nil then object:EnableMouse(mode~="hide" and rec.mouse) end
    end
    self.painting=false
end
function Chat:Apply()
    if not FT.dbReady or InCombatLockdown() then return end
    self:Track(QuickJoinToastButton,"social",ChatFrame1)
    self:Track(FriendsMicroButton,"social",ChatFrame1)
    for _,name in ipairs({"ChatFrameMenuButton","ChatFrameChannelButton","ChatFrameToggleVoiceDeafenButton","ChatFrameToggleVoiceMuteButton"}) do self:Track(_G[name],"icons",ChatFrame1) end
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local name="ChatFrame"..i; local frame=_G[name]
        self:Track(_G[name.."Tab"],"tabs",frame)
        self:Track(_G[name.."ButtonFrame"],"icons",frame)
        self:Track(_G[name.."ScrollBar"],"icons",frame)
        if frame then self:Track(frame.ScrollBar,"icons",frame); self:Track(frame.ScrollToBottomButton,"icons",frame) end
        local box=_G[name.."EditBox"]
        -- Only artwork is hidden. The edit box, focus, typed text and Enter work normally.
        for _,suffix in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(_G[name.."EditBox"..suffix],"input",box) end
        if box then for _,key in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(box[key],"input",box) end end
    end
    self:Paint(); self:Refresh()
end
function Chat:Refresh()
    if not self.buttons then return end
    for _,entry in ipairs(options) do
        local mode=self:Settings()[entry[1]] or "show"
        local icons={show="Spell_Holy_MagicalSentry",hide="Ability_Stealth",hover="Ability_Hunter_SniperShot"}
        self.buttons[entry[1]].label:SetText(entry[2]..": |TInterface\\Icons\\"..icons[mode]..":18:18|t "..({show="Shown",hide="Hidden",hover="Mouseover"})[mode])
    end
end
function Chat:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsChat","ForeverTools | Chat",500,350); self.buttons={}
        for i,entry in ipairs(options) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",452,46,"chat")
            b:SetPoint("TOPLEFT",24,-65-(i-1)*58)
            b:SetScript("OnClick",function()
                self:Settings()[key]=({show="hide",hide="hover",hover="show"})[self:Settings()[key] or "show"]
                self:Apply()
            end)
            FT:Tooltip(b,entry[2],"Click to cycle Shown, Hidden and Mouseover. Tabs reveal together over the chat area; social and side controls reveal only over their own region. Input styling never hides the text you type.")
            self.buttons[key]=b
        end
    end
    self:Apply(); self.frame:Show()
end
FT:RegisterModule("Chat",Chat)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","UPDATE_CHAT_WINDOWS","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ADDON_LOADED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() if FT.dbReady then Chat:Apply() end end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>.15 then elapsed=0; if FT.dbReady and not InCombatLockdown() then Chat:Paint() end end
end)
