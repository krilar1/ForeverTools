local _,FT=...
local F=FT.modules.FontManager
function F:ApplyAllFonts(font)
    local s=font and {font=font} or self:Settings(self.selected)
    local path=self:Resolve(s)
    if not self:ValidFont(path) then self.notice="Choose an available font first."; self:Refresh(); return end
    for _,id in ipairs(self.order) do
        local target=self:Settings(id)
        target.font,target.path,target.pathFor,target.enabled=s.font,path,s.font,true
    end
    self:Apply()
    FT:Toast("Font applied to all areas")
end
function F:Stepper(parent,width,values,change)
    local box=CreateFrame("Frame",nil,parent); box:SetSize(width,28)
    FT:Panel(box)
    box.onSelect=change
    box.label=FT:Label(box,"",13); box.label:SetPoint("LEFT",10,0); box.label:SetWidth(width-82)
    box.minus=FT:QuietButton(box,"−",28,24); box.minus:SetPoint("RIGHT",-34,0)
    box.plus=FT:QuietButton(box,"+",28,24); box.plus:SetPoint("RIGHT",-3,0)
    local function step(delta)
        if box==self.sizeChoice and box.value==0 then
            local size=self:EffectiveSize(self.selected)
            change(math.max(8,math.min(40,math.floor(size+delta+.5)))); return
        end
        local list=values(); local index=1
        for i,item in ipairs(list) do if item.value==box.value then index=i; break end end
        index=math.max(1,math.min(#list,index+delta)); change(list[index].value)
    end
    box.minus:SetScript("OnClick",function() step(-1) end); box.plus:SetScript("OnClick",function() step(1) end)
    box.SetEnabled=function(_,enabled) box.enabled=enabled; box.minus:SetEnabled(enabled); box.plus:SetEnabled(enabled) end
    return box
end
function F:EffectiveSize(id)
    local s=self:Settings(id)
    if s.size~=0 then return s.size end
    local area=self.areas[id]; local sizes={}
    if area.collect then
        local objects={}; area.collect(objects)
        for object in pairs(objects) do
            local ok,_,size=pcall(object.GetFont,object)
            if ok and type(size)=="number" then sizes[#sizes+1]=size end
        end
    end
    table.sort(sizes)
    return sizes[math.ceil(#sizes/2)] or (self.preview and select(2,self.preview:GetFont())) or 22
end
function F:UpdateScene(path)
    if not self.scene then
        self.scene=CreateFrame("Frame",nil,self.frame); self.scene:SetSize(494,100); self.scene:SetPoint("TOPLEFT",240,-282)
        FT:Panel(self.scene)
        self.scene.icon=self.scene:CreateTexture(nil,"ARTWORK"); self.scene.icon:SetSize(64,64); self.scene.icon:SetPoint("LEFT",16,0)
        self.scene.icon:SetTexture("Interface\\Icons\\Spell_Frost_FrostBolt02")
        self.scene.text=FT:Label(self.scene,"",24); self.scene.text:SetPoint("LEFT",98,0); self.scene.text:SetWidth(380)
        FT:Tooltip(self.scene,"Simulated preview","Sample text uses the chosen font. Native combat-number placement and size are controlled by the client and can differ from this simulation.")
        self.frame:HookScript("OnHide",function() self.scene:SetScript("OnUpdate",nil) end)
    end
    local sameArea=self.scene.area==self.selected
    self.scene.area=self.selected
    if not sameArea then self.scene.elapsed=0 end
    self.scene:Hide(); self.scene:SetScript("OnUpdate",nil)
    for _,slot in ipairs(self.scene.slots or {}) do slot:Hide() end
    if not path then return end
    local id=self.selected
    if id=="general" or id=="chat" or id=="tooltip" or id=="quests" or id=="objectives" then
        self.preview:SetText(id=="chat" and "[Guild] Player: The quick brown fox jumps over the lazy dog." or id=="tooltip" and "Frostbolt\nDeals Frost damage and slows the target." or "The quick brown fox jumps over the lazy dog.")
        return
    end
    self.preview:Hide(); self.scene:Show()
    self.scene.icon:SetVertexColor(1,1,1)
    self.scene.text:ClearAllPoints(); self.scene.text:SetPoint("LEFT",98,0)
    self.scene.text:SetWidth(380); self.scene.text:SetJustifyH("LEFT")
    local s=self:Settings(id); self.scene.text:SetFont(path,math.min(32,self:EffectiveSize(id)),self:Flags(s.outline,""))
    self:ThinShadow(self.scene.text,s.outline)
    self.scene.icon:SetShown(id=="cooldowns")
    if id~="cooldowns" and self.scene.icon.SetDesaturated then self.scene.icon:SetDesaturated(false) end
    self.scene.text:Show()
    self.scene.text:SetAlpha(1); self.scene.text:SetTextColor(1,.85,.2)
    if id=="actions" then
        self.scene.text:Hide(); self.scene.slots=self.scene.slots or {}
        for i,key in ipairs({"1","F","s-2","s-X"}) do
            local slot=self.scene.slots[i]
            if not slot then
                slot=CreateFrame("Frame",nil,self.scene); slot:SetSize(64,64); slot:SetPoint("LEFT",16+(i-1)*86,0)
                FT:Panel(slot)
                slot.icon=slot:CreateTexture(nil,"ARTWORK"); slot.icon:SetPoint("TOPLEFT",2,-2); slot.icon:SetPoint("BOTTOMRIGHT",-2,2)
                slot.icon:SetTexture("Interface\\Icons\\"..({"Spell_Frost_FrostBolt02","Spell_Fire_FlameBolt","Spell_Holy_Heal","Ability_Warrior_Charge"})[i])
                slot.text=FT:Label(slot,key,14); slot.text:SetPoint("TOPRIGHT",-3,-3)
                self.scene.slots[i]=slot
            end
            slot.text:SetFont(path,self:EffectiveSize(id),self:Flags(s.outline,"OUTLINE"))
            self:ThinShadow(slot.text,s.outline)
            slot:Show()
        end
    elseif id=="restedxp" then self.scene.text:SetText("Step 16\nTravel to the Crossroads")
    elseif id=="swingMain" or id=="swingOff" then self.scene.text:SetText((id=="swingMain" and "Main hand" or "Off hand").."     2.4 s")
    elseif id=="units" then self.scene.text:SetText("Player\n2,450 / 3,000")
    else
        local elapsed=self.scene.elapsed or 0
        if id=="cooldowns" then
            self.scene.text:ClearAllPoints(); self.scene.text:SetPoint("CENTER",self.scene.icon,"CENTER")
            self.scene.text:SetWidth(64); self.scene.text:SetJustifyH("CENTER")
            self.scene.text:SetText(string.format("%.1f",6-elapsed))
        end
        local function animate(_,dt)
            elapsed=(elapsed+dt)%6
            self.scene.elapsed=elapsed
            if id=="cooldowns" then
                self.scene.text:SetText(string.format("%.1f",6-elapsed))
                local grey=self:Settings("cooldowns").greyCooldowns==true
                if self.scene.icon.SetDesaturated then self.scene.icon:SetDesaturated(grey) end
                self.scene.icon:SetVertexColor(1,1,1)
            else
                local heal=elapsed>=3
                self.scene.text:SetText(heal and "+2,450" or "−1,280")
                self.scene.text:SetTextColor(heal and .2 or 1,heal and 1 or .3,.2)
                self.scene.text:SetAlpha(1-(elapsed%3)/3)
                self.scene.text:ClearAllPoints(); self.scene.text:SetPoint("LEFT",98,(elapsed%3)*12-12)
            end
        end
        self.scene:SetScript("OnUpdate",animate)
        animate(self.scene,0)
    end
end
