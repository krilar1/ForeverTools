local _,FT=...
local Loot={}
function Loot:Settings()
    if type(FT.db.lootRoll)~="table" then FT.db.lootRoll={} end
    local s=FT.db.lootRoll
    if type(s.x)~="number" then s.x=.68 end
    if type(s.y)~="number" then s.y=.5 end
    s.x=math.max(0,math.min(1,s.x)); s.y=math.max(0,math.min(1,s.y))
    return s
end
function Loot:Place()
    if self.placing or not self.anchor then return end
    local container=GroupLootContainer
    if not container then return end
    self.placing=true
    -- Blizzard can lay out alerts again during combat. Re-anchor immediately
    -- when permitted by the client, without changing roll buttons or timers.
    pcall(function()
        container:ClearAllPoints()
        container:SetPoint("BOTTOM",self.anchor,"CENTER",0,0)
    end)
    self.placing=false
end
function Loot:UpdateDrag()
    if not self.dragging or InCombatLockdown() then return end
    local x,y=GetCursorPosition(); local scale=UIParent:GetEffectiveScale()
    local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local s=self:Settings()
    s.x=math.max(140,math.min(w-140,x/scale+self.offsetX))/w
    s.y=math.max(40,math.min(h-100,y/scale+self.offsetY))/h
    self:Position()
end
function Loot:Position()
    local s=self:Settings()
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER",UIParent,"BOTTOMLEFT",UIParent:GetWidth()*s.x,UIParent:GetHeight()*s.y)
    self:Place()
end
function Loot:Apply()
    if not FT.dbReady then return end
    if InCombatLockdown() then self.deferred=true; return end
    self.deferred=nil
    if not self.anchor then
        local a=CreateFrame("Frame","ForeverToolsLootRollAnchor",UIParent,"BackdropTemplate")
        self.anchor=a; a:SetSize(280,54); a:SetFrameStrata("DIALOG")
        FT:Panel(a); FT:Paint(a,{.12,.05,.2,.9},{.7,.35,1,1})
        -- A non-interactive sample card, not a real roll or a usable item.
        local card=CreateFrame("Frame",nil,a); card:SetSize(280,64)
        card:SetPoint("BOTTOM",a,"TOP",0,4); FT:Panel(card)
        FT:Paint(card,{.025,.04,.045,.98},{.12,.42,.6,1})
        local item=card:CreateTexture(nil,"ARTWORK"); item:SetSize(40,40)
        item:SetPoint("LEFT",8,3); item:SetTexture("Interface\\Icons\\INV_Belt_03")
        local name=FT:Label(card,"Sample loot item",12); name:SetPoint("TOPLEFT",56,-13); name:SetTextColor(.25,.6,1)
        for i,icon in ipairs({"INV_Misc_Dice_01","INV_Misc_Coin_01"}) do
            local texture=card:CreateTexture(nil,"ARTWORK"); texture:SetSize(20,20)
            texture:SetPoint("TOPRIGHT",-12,-8-(i-1)*23); texture:SetTexture("Interface\\Icons\\"..icon)
        end
        local timer=card:CreateTexture(nil,"ARTWORK"); timer:SetSize(208,5)
        timer:SetPoint("BOTTOMLEFT",8,7); timer:SetColorTexture(.65,.8,.15,1)
        self.sample=card
        a:EnableMouse(true); a:RegisterForDrag("LeftButton")
        local label=FT:Label(a,"Loot rolls — drag to move",14,true); label:SetPoint("CENTER",0,6)
        local hint=FT:Label(a,"Close the addon to save and lock",11); hint:SetPoint("CENTER",0,-13)
        a:SetScript("OnDragStart",function()
            if not self.moving or InCombatLockdown() then return end
            local x,y=GetCursorPosition(); local cx,cy=a:GetCenter()
            if not cx or not cy then return end
            local scale=UIParent:GetEffectiveScale(); local ratio=a:GetEffectiveScale()/scale
            self.offsetX,self.offsetY=cx*ratio-x/scale,cy*ratio-y/scale; self.dragging=true
        end)
        a:SetScript("OnDragStop",function() self:UpdateDrag(); self.dragging=nil end)
        a:SetScript("OnUpdate",function() self:UpdateDrag() end)
        a:SetScript("OnHide",function() self.dragging=nil end)
    end
    if GroupLootContainer and not self.hooked then
        self.hooked=true
        -- Keep native roll stacking and button behavior; replace only its anchor.
        hooksecurefunc(GroupLootContainer,"SetPoint",function() self:Place() end)
        GroupLootContainer:HookScript("OnShow",function() self:Place() end)
    end
    self:Position(); self.anchor:SetShown(self.moving==true)
end
function Loot:FinishMove()
    self:UpdateDrag()
    self.dragging=nil; self.moving=false
    if self.anchor then self.anchor:Hide() end
    if FT.modules.System then FT.modules.System:Refresh() end
end
function Loot:ToggleMove()
    if InCombatLockdown() then FT:Toast("Leave combat to move loot rolls."); return end
    if self.moving then self:FinishMove(); return end
    self.moving=not self.moving; self.dragging=nil; self:Apply()
    if FT.modules.System then FT.modules.System:Refresh() end
end
FT:RegisterModule("LootRoll",Loot)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","ADDON_LOADED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_REGEN_DISABLED" then
        Loot.moving=false; Loot.dragging=nil
        if Loot.anchor then Loot.anchor:Hide() end
        if FT.modules.System then FT.modules.System:Refresh() end
    else Loot:Apply() end
end)
