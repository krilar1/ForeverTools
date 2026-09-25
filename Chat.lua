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
    if self.links then
        local on=FT.modules.System:Settings().chatLinks==true
        self.links.label:SetText("Clickable links: "..(on and "On" or "Off"));FT:SetSelected(self.links,on)
    end
    if self.fontChoice then
        local fonts=FT.modules.FontManager;local pref=fonts:Settings("chat")
        local label=pref.font
        for _,choice in ipairs(fonts:Catalogue()) do if choice.value==pref.font then label=choice.label;break end end
        self.fontChoice.label:SetText("Chat font: "..label)
        self.fontSize.label:SetText("Size: "..(pref.size==0 and "Blizzard default" or pref.size.." px"))
        local outlineNames={original="Blizzard default",[""]="None",THIN="Thin",OUTLINE="Outline",THICKOUTLINE="Thick outline"}
        self.outline.label:SetText("Outline: "..(outlineNames[pref.outline] or pref.outline))
    end
end
function Chat:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsChat","ForeverTools | Chat",500,560); self.buttons={}
        for i,entry in ipairs(options) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",452,46,"chat")
            b:SetPoint("TOPLEFT",24,-65-(i-1)*58)
            b:SetScript("OnClick",function()
                self:Settings()[key]=({show="hide",hide="hover",hover="show"})[self:Settings()[key] or "show"]
                self:Apply()
            end)
            FT:Tooltip(b,entry[2],"Click to switch between Shown, Hidden and Mouseover (shows up when you hover it).")
            self.buttons[key]=b
        end
        local heading=FT:Label(self.frame,"Chat text",15,true);heading:SetPoint("TOPLEFT",24,-305)
        local fonts=FT.modules.FontManager
        self.fontChoice=FT:Dropdown(self.frame,452,function() return fonts:Catalogue() end,function(value)
            local pref=fonts:Settings("chat");local path=fonts:Resolve({font=value})
            if not fonts:ValidFont(path) then FT:Toast("That font is unavailable.");return end
            pref.font=value;pref.enabled=true;fonts:ApplyArea("chat");self:Refresh()
        end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",24,-332)
        self.fontSize=FT:QuietButton(self.frame,"",208,32,"fonts");self.fontSize:SetPoint("TOPLEFT",24,-380)
        self.fontSize:SetScript("OnClick",function()
            local p=fonts:Settings("chat");if p.size==0 then return end
            FT:Confirm("Restore the original chat font size?",function() p.size=0;fonts:ApplyArea("chat");self:Refresh() end)
        end)
        for i,delta in ipairs({-1,1}) do
            local button=FT:QuietButton(self.frame,delta<0 and "−" or "+",48,32,delta<0 and "reset" or "add")
            button:SetPoint("TOPLEFT",240+(i-1)*56,-380)
            button:SetScript("OnClick",function()local p=fonts:Settings("chat");p.size=math.max(8,math.min(40,(p.size==0 and 14 or p.size)+delta));p.enabled=true;fonts:ApplyArea("chat");self:Refresh() end)
        end
        self.outline=FT:QuietButton(self.frame,"",452,32,"fonts");self.outline:SetPoint("TOPLEFT",24,-426)
        local choices={"original","","THIN","OUTLINE","THICKOUTLINE"}
        self.outline:SetScript("OnClick",function()
            local p=fonts:Settings("chat")
            for i,value in ipairs(choices) do if value==p.outline then p.outline=choices[i%#choices+1];break end end
            p.enabled=true;fonts:ApplyArea("chat");self:Refresh()
        end)
        FT:Tooltip(self.fontChoice,"Chat font","The font for chat text. This is the same setting as Chat in Font manager.")
        FT:Tooltip(self.fontSize,"Chat font size","Use + and − to change the size. Click the number to go back to Blizzard's size.")
        FT:Tooltip(self.outline,"Chat outline","Click to switch the text outline: default, none, thin, normal or thick.")
        self.links=FT:QuietButton(self.frame,"",452,32,"chat");self.links:SetPoint("TOPLEFT",24,-472)
        self.links:SetScript("OnClick",function() local s=FT.modules.System:Settings();s.chatLinks=not s.chatLinks;self:Refresh() end)
        FT:Tooltip(self.links,"Clickable links","Web addresses in chat become clickable. Click one to get a box you can copy it from. Works on new messages.")
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
