local _,FT=...
local Fonts=FT.modules.FontManager
local icons,texts={},{}
local bars={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton","MultiBar5Button","MultiBar6Button","MultiBar7Button"}
local function cooling(cd)
    if not cd or not cd.GetCooldownTimes then return false end
    local ok,result=pcall(function()
        local start,duration=cd:GetCooldownTimes()
        -- Ignore the global cooldown. Restricted beta values cannot be compared.
        return type(start)=="number" and type(duration)=="number" and duration>1500 and start>0 and start+duration>GetTime()*1000
    end)
    return ok and result
end
local function update()
    if not FT.dbReady then return end
    local s=Fonts:Settings("cooldowns")
    for _,prefix in ipairs(bars) do for i=1,12 do
        local name=prefix..i; local button=_G[name]
        local cd=button and (button.cooldown or button.Cooldown) or _G[name.."Cooldown"]
        local icon=button and (button.icon or button.Icon) or _G[name.."Icon"]
        if icon and icon.SetDesaturated and icon.IsDesaturated then
            local grey=s.greyCooldowns==true and cooling(cd)
            if grey then
                if icons[icon]==nil then icons[icon]=icon:IsDesaturated() end
                icon:SetDesaturated(true)
            elseif icons[icon]~=nil then icon:SetDesaturated(icons[icon]); icons[icon]=nil end
        end
        if cd and cd.GetRegions then for _,text in ipairs({cd:GetRegions()}) do
            if text.GetFont and text.GetTextColor and text.SetTextColor then
                if s.enabled and type(s.numberColor)=="table" then
                    if not texts[text] then texts[text]={text:GetTextColor()} end
                    text:SetTextColor(s.numberColor[1],s.numberColor[2],s.numberColor[3],1)
                elseif texts[text] then text:SetTextColor(unpack(texts[text])); texts[text]=nil end
            end
        end end
    end end
end
function Fonts:CooldownColorPicker()
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then FT:Toast("Color picker unavailable on this client."); return end
    local s=self:Settings("cooldowns"); local old=s.numberColor; local wasEnabled=s.enabled
    local color=old or {1,1,1}
    FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=color[1],g=color[2],b=color[3],hasOpacity=false,
        swatchFunc=function() local r,g,b=ColorPickerFrame:GetColorRGB(); s.numberColor={r,g,b}; s.enabled=true; update(); self:Refresh() end,
        cancelFunc=function() s.numberColor=old; s.enabled=wasEnabled; update(); self:Refresh() end})
end
local refresh=Fonts.Refresh
function Fonts:Refresh()
    refresh(self)
    if not self.frame then return end
    if not self.cooldownColor then
        self.cooldownColor=FT:QuietButton(self.frame,"Number color",238,32,"fonts")
        self.cooldownColor:SetPoint("TOPLEFT",240,-406)
        self.cooldownColor:SetScript("OnClick",function() self:CooldownColorPicker() end)
        self.cooldownGrey=FT:QuietButton(self.frame,"",244,32,"skins")
        self.cooldownGrey:SetPoint("LEFT",self.cooldownColor,"RIGHT",12,0)
        self.cooldownGrey:SetScript("OnClick",function() local s=self:Settings("cooldowns"); s.greyCooldowns=not s.greyCooldowns; update(); self:Refresh() end)
        FT:Tooltip(self.cooldownColor,"Cooldown number color","Choose a color for Blizzard action-bar countdown text. Reset this area restores native colors. Changes save with your profile.")
        FT:Tooltip(self.cooldownGrey,"Grey out spells on cooldown","Desaturate Blizzard action icons during cooldowns longer than the global cooldown. Off restores their previous saturation. Restricted beta cooldown data may prevent this effect.")
    end
    local selected=self.selected=="cooldowns"; local s=self:Settings("cooldowns")
    self.cooldownColor:SetShown(selected); self.cooldownGrey:SetShown(selected)
    self.cooldownGrey.label:SetText("Grey on cooldown: "..(s.greyCooldowns and "On" or "Off"))
    FT:SetSelected(self.cooldownGrey,s.greyCooldowns==true)
    self.cooldownColor.label:SetTextColor(unpack(s.numberColor or {1,1,1}))
    if selected and self.scene then
        self.scene.text:SetTextColor(unpack(s.numberColor or {1,.85,.2}))
    end
    update()
end
local events=CreateFrame("Frame"); local elapsed=0
events:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt; if elapsed<.2 then return end; elapsed=0; update() end)
