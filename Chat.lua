local _,FT=...
local Chat={tracked={}}
local options={{"social","Social button"},{"tabs","Chat tabs"},{"icons","Side buttons"},{"input","Input box border"}}
-- Values the game hides in a fight are treated as "not known".
local function hidden(...)
    if not issecretvalue then return false end
    for i=1,select("#",...) do if issecretvalue((select(i,...))) then return true end end
    return false
end
local function mouseOver(object)
    if not object or not object.IsMouseOver then return false end
    local over=object:IsMouseOver()
    if hidden(over) then return false end
    return over==true
end
local function overBox(object,padding)
    if not object then return false end
    if mouseOver(object) then return true end
    if not object.GetLeft or not object.GetRight or not object.GetTop or not object.GetBottom then return false end
    local left,right,top,bottom=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
    if hidden(left,right,top,bottom) then return false end
    if not left or not right or not top or not bottom then return false end
    local x,y=GetCursorPosition(); local scale=object:GetEffectiveScale()
    if hidden(x,y,scale) then return false end
    x,y=x/scale,y/scale
    return x>=left-padding and x<=right+padding and y>=bottom-padding and y<=top+padding
end
function Chat:Settings()
    if type(FT.db.chat)~="table" then FT.db.chat={} end
    return FT.db.chat
end
function Chat:Track(object,key,owner,cluster)
    if not object or not object.SetAlpha then return end
    local rec=self.tracked[object]
    if rec then rec.cluster=rec.cluster or cluster end
    if not rec then
        rec={alpha=object:GetAlpha(),key=key,owner=owner,cluster=cluster}; self.tracked[object]=rec
        if object.EnableMouse and object.IsMouseEnabled then rec.mouse=object:IsMouseEnabled() end
        if hooksecurefunc then
            hooksecurefunc(object,"SetAlpha",function(target)
                if not self.painting and FT.dbReady then self:Paint(target) end
            end)
        end
    end
end
local function tabsHovered(self)
    for object,rec in pairs(self.tracked) do
        if rec.key=="tabs" and (mouseOver(object) or mouseOver(rec.owner)) then return true end
    end
    return false
end
-- Side buttons (and the social button) show when the cursor is anywhere over
-- the box they sit in, not only exactly on one button. The box is the area
-- covering every button of that group on the same chat frame.
local function overGroup(self,cluster,padding)
    local left,right,top,bottom
    for object,rec in pairs(self.tracked) do
        if rec.cluster==cluster and object.IsShown and object:IsShown() and object.GetLeft then
            local l,r,t,b=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
            local scale=object:GetEffectiveScale()
            if not hidden(l,r,t,b,scale) and l and r and t and b then
                l,r,t,b=l*scale,r*scale,t*scale,b*scale
                left=left and math.min(left,l) or l; right=right and math.max(right,r) or r
                top=top and math.max(top,t) or t; bottom=bottom and math.min(bottom,b) or b
            end
        end
    end
    if not left then return false end
    local x,y=GetCursorPosition()
    if hidden(x,y) then return false end
    return x>=left-padding and x<=right+padding and y>=bottom-padding and y<=top+padding
end
local function paintOne(self,s,object,rec,tabsOver)
    local mode=s[rec.key] or "show"
    local hover=false
    if mode=="hover" then
        if rec.key=="tabs" then hover=tabsOver
        elseif rec.key=="icons" or rec.key=="social" then
            local cache,cluster=self.groupHover,rec.cluster
            if not cluster then hover=overBox(object,8)
            elseif cache and cache[cluster]~=nil then hover=cache[cluster]
            else
                hover=overGroup(self,cluster,8)
                if cache then cache[cluster]=hover end
            end
        else
            -- The input box border also shows while you are typing (for
            -- example after clicking a name to whisper), not only on hover.
            local owner=rec.owner
            hover=(rec.key=="input" and owner and ((owner.HasFocus and owner:HasFocus()==true) or mouseOver(owner))) or mouseOver(object)
        end
    end
    local visible=mode=="show" or (mode=="hover" and hover)
    local alpha=visible and (mode=="hover" and 1 or rec.alpha) or 0
    -- Only touch the frame when something changes (this runs often).
    local current=object.GetAlpha and object:GetAlpha()
    if hidden(current) or type(current)~="number" or math.abs(current-alpha)>.001 then object:SetAlpha(alpha) end
    -- Showing and hiding is allowed in a fight; switching the mouse on a
    -- frame is not always, and it only changes with the setting anyway.
    if rec.mouse~=nil and not InCombatLockdown() then
        local mouse=mode~="hide" and rec.mouse
        local actual=object.IsMouseEnabled and object:IsMouseEnabled()
        if actual~=mouse then object:EnableMouse(mouse) end
    end
end
-- Paint(): every tracked object. Paint(object): just that one (used when
-- Blizzard changes its alpha, for example while fading chat tabs).
function Chat:Paint(only)
    if self.painting then return end
    self.painting=true
    local s=self:Settings()
    if only then
        local rec=self.tracked[only]
        if rec then paintOne(self,s,only,rec,rec.key=="tabs" and s.tabs=="hover" and tabsHovered(self)) end
    else
        local tabsOver=s.tabs=="hover" and tabsHovered(self)
        -- Work out each box once per paint, not once per button.
        self.groupHover={}
        for object,rec in pairs(self.tracked) do paintOne(self,s,object,rec,tabsOver) end
        self.groupHover=nil
    end
    self.painting=false
end
-- Mouseover modes need polling; shown and hidden ones do not.
function Chat:NeedsPolling()
    local s=self:Settings()
    for _,entry in ipairs(options) do if s[entry[1]]=="hover" then return true end end
    return false
end
function Chat:Apply()
    if not FT.dbReady or InCombatLockdown() then return end
    self:Track(QuickJoinToastButton,"social",ChatFrame1,"social")
    self:Track(FriendsMicroButton,"social",ChatFrame1,"social")
    for _,name in ipairs({"ChatFrameMenuButton","ChatFrameChannelButton","ChatFrameToggleVoiceDeafenButton","ChatFrameToggleVoiceMuteButton"}) do self:Track(_G[name],"icons",ChatFrame1,"side1") end
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local name="ChatFrame"..i; local frame=_G[name]
        self:Track(_G[name.."Tab"],"tabs",frame)
        self:Track(_G[name.."ButtonFrame"],"icons",frame,"side"..i)
        self:Track(_G[name.."ScrollBar"],"icons",frame)
        if frame then self:Track(frame.ScrollBar,"icons",frame); self:Track(frame.ScrollToBottomButton,"icons",frame) end
        local box=_G[name.."EditBox"]
        -- Only artwork is hidden. The edit box, focus, typed text and Enter work normally.
        for _,suffix in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(_G[name.."EditBox"..suffix],"input",box) end
        if box then for _,key in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(box[key],"input",box) end end
        if box and not box.ftFocusHooked and box.HookScript then
            box.ftFocusHooked=true
            box:HookScript("OnEditFocusGained",function() if FT.dbReady then Chat:Paint() end end)
            box:HookScript("OnEditFocusLost",function() if FT.dbReady then Chat:Paint() end end)
        end
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
        local outlineNames={original="Default",[""]="Default",THIN="Thin outline",OUTLINE="Outline",THICKOUTLINE="Thick outline"}
        self.outline.label:SetText("Outline: "..(outlineNames[pref.outline] or pref.outline))
    end
end
function Chat:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsChat","Chat",760,560); self.buttons={}
        -- Two columns: what shows around the chat on the left, its text on the right.
        local buttonsHead=FT:Label(self.frame,"Buttons and tabs",15,true);buttonsHead:SetPoint("TOPLEFT",24,-66);FT:SectionHeading(buttonsHead,"INV_Misc_Note_03",200)
        FT:AppearanceBack(self.frame)
        FT:PageInfo(self.frame,"Chat","Choose what shows around the chat: click a button to switch between Shown, Hidden and Mouseover (shows when you hover it). Also the chat font and clickable web links.")
        for i,entry in ipairs(options) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",350,32,"chat")
            b:SetPoint("TOPLEFT",24,-94-(i-1)*40)
            b:SetScript("OnClick",function()
                self:Settings()[key]=({show="hide",hide="hover",hover="show"})[self:Settings()[key] or "show"]
                self:Apply()
            end)
            FT:Tooltip(b,entry[2],"Click to switch between Shown, Hidden and Mouseover (shows up when you hover it).")
            self.buttons[key]=b
        end
        local heading=FT:Label(self.frame,"Chat text",15,true);heading:SetPoint("TOPLEFT",386,-66);FT:SectionHeading(heading,"INV_Inscription_Tradeskill01",200)
        local fonts=FT.modules.FontManager
        self.fontChoice=FT:Dropdown(self.frame,350,function() return fonts:Catalogue() end,function(value)
            local pref=fonts:Settings("chat");local path=fonts:Resolve({font=value})
            if not fonts:ValidFont(path) then FT:Toast("That font is unavailable.");return end
            pref.font=value;pref.enabled=true;fonts:ApplyArea("chat");self:Refresh()
        end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",386,-94)
        self.fontSize=FT:QuietButton(self.frame,"",236,32,"fonts");self.fontSize:SetPoint("TOPLEFT",386,-134)
        self.fontSize:SetScript("OnClick",function()
            local p=fonts:Settings("chat");if p.size==0 then return end
            FT:Confirm("Restore the original chat font size?",function() p.size=0;fonts:ApplyArea("chat");self:Refresh() end)
        end)
        for i,delta in ipairs({-1,1}) do
            local button=FT:QuietButton(self.frame,delta<0 and "-" or "+",50,32,delta<0 and "reset" or "add")
            button:SetPoint("TOPLEFT",630+(i-1)*56,-134)
            FT:Tooltip(button,delta<0 and "Smaller" or "Larger",delta<0 and "Make chat text one size smaller." or "Make chat text one size larger.")
            button:SetScript("OnClick",function()local p=fonts:Settings("chat");p.size=math.max(8,math.min(40,(p.size==0 and 14 or p.size)+delta));p.enabled=true;fonts:ApplyArea("chat");self:Refresh() end)
        end
        self.outline=FT:QuietButton(self.frame,"",350,32,"fonts");self.outline:SetPoint("TOPLEFT",386,-174)
        local choices={"original","THIN","OUTLINE","THICKOUTLINE"}
        self.outline:SetScript("OnClick",function()
            local p=fonts:Settings("chat")
            local current=(p.outline=="" or p.outline==nil) and "original" or p.outline
            for i,value in ipairs(choices) do if value==current then p.outline=choices[i%#choices+1];break end end
            p.enabled=true;fonts:ApplyArea("chat");self:Refresh()
        end)
        FT:Tooltip(self.fontChoice,"Chat font","The font for chat text. The same setting as the Chat area under Fonts.")
        FT:Tooltip(self.fontSize,"Chat font size","Use + and - to change the size. Click the number to go back to Blizzard's size.")
        FT:Tooltip(self.outline,"Chat outline","Click to switch: Default (the game's soft shadow), Thin outline (a light outline without the shadow), Outline or Thick outline.")
        local linksHead=FT:Label(self.frame,"Links",15,true);linksHead:SetPoint("TOPLEFT",24,-270);FT:SectionHeading(linksHead,"INV_Misc_Note_02",200)
        self.links=FT:QuietButton(self.frame,"",350,32,"chat");self.links:SetPoint("TOPLEFT",24,-298)
        self.links:SetScript("OnClick",function() local s=FT.modules.System:Settings();s.chatLinks=not s.chatLinks;self:Refresh() end)
        FT:Tooltip(self.links,"Clickable links","Web addresses in chat become clickable. Click one to get a box you can copy it from. Works on new messages.")
    end
    self:Apply(); self.frame:Show()
end
FT:RegisterModule("Chat",Chat)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","UPDATE_CHAT_WINDOWS","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ADDON_LOADED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() if FT.dbReady then FT:Coalesce("chat",function() Chat:Apply() end) end end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<=.15 then return end
    elapsed=0
    -- Also in a fight: mouseover buttons must show there too.
    if not FT.dbReady or not Chat:NeedsPolling() then return end
    -- Mouseover only changes when the mouse moves (typing and fading are
    -- handled when they happen), so skip the check while it stands still.
    local x,y=GetCursorPosition()
    if hidden(x,y) then return end
    if x==Chat.lastX and y==Chat.lastY then return end
    Chat.lastX,Chat.lastY=x,y
    Chat:Paint()
end)
