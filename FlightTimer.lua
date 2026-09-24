local _,FT=...
local Flight={}
local function number(value,default,low,high)
    if type(value)~="number" or value~=value then return default end
    return math.max(low,math.min(high,value))
end
function Flight:Settings()
    if type(FT.db.flightTimer)~="table" then FT.db.flightTimer={} end
    local s=FT.db.flightTimer
    if s.enabled==nil then s.enabled=true end
    s.size=number(s.size,20,10,48)
    s.x=number(s.x,.5,0,1);s.y=number(s.y,.5,0,1)
    if type(s.font)~="string" then s.font="friz" end
    if s.outline~="" and s.outline~="OUTLINE" and s.outline~="THICKOUTLINE" then s.outline="OUTLINE" end
    if type(s.color)~="table" then s.color={1,1,1} end
    for i=1,3 do s.color[i]=number(s.color[i],1,0,1) end
    return s
end
function Flight:Position()
    local s=self:Settings();local w,h=UIParent:GetWidth(),UIParent:GetHeight()
    local halfW,halfH=self.display:GetWidth()/2,self.display:GetHeight()/2
    local x=math.max(halfW+8,math.min(w-halfW-8,s.x*w))
    local y=math.max(halfH+8,math.min(h-halfH-8,s.y*h))
    self.display:ClearAllPoints();self.display:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
end
function Flight:Drag()
    if not self.dragging then return end
    local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
    local s=self:Settings()
    s.x=(x/scale+self.dragX)/UIParent:GetWidth();s.y=(y/scale+self.dragY)/UIParent:GetHeight()
    self:Position()
end
function Flight:CreateDisplay()
    if self.display then return end
    local display=CreateFrame("Frame","ForeverToolsFlightTimer",UIParent);self.display=display
    display:SetFrameStrata("HIGH");display:SetClampedToScreen(true)
    display.text=FT:Label(display,"",20);display.text:SetPoint("CENTER")
    display.hint=FT:Label(display,"Preview - drag to move",11);display.hint:SetPoint("TOP",display,"BOTTOM",0,-3)
    display:RegisterForDrag("LeftButton")
    display:SetScript("OnDragStart",function()
        if not self.preview or InCombatLockdown() then return end
        local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
        local cx,cy=display:GetCenter();self.dragX=cx-x/scale;self.dragY=cy-y/scale;self.dragging=true
    end)
    display:SetScript("OnDragStop",function() self:Drag();self.dragging=false end)
    display:SetScript("OnUpdate",function() self:Drag() end)
end
local function read(fn,...)
    if not fn then return end
    local ok,value=pcall(fn,...)
    if ok and (not issecretvalue or not issecretvalue(value)) then return value end
end
function Flight:History()
    if type(FT.db.flightHistory)~="table" then FT.db.flightHistory={} end
    local history=FT.db.flightHistory
    if type(history.routes)~="table" then history.routes={} end
    if type(history.active)~="table" then history.active={} end
    return history
end
function Flight:Character()
    return read(UnitGUID,"player") or "player"
end
local function nodeName(name)
    if type(name)~="string" then return end
    return name:match("^[^,]+"):lower():gsub("^the%s+",""):match("^%s*(.-)%s*$")
end
function Flight:EstimateRoute(route,faction)
    local data=FT.flightDefaults and FT.flightDefaults[faction]
    if not data or #route<2 then return end
    local byName={}
    for id,node in pairs(data) do if type(node)=="table" and node.name then byName[nodeName(node.name)]=id end end
    local total=0
    for i=1,#route-1 do
        local source,destination=byName[nodeName(route[i])],byName[nodeName(route[i+1])]
        local seconds=source and destination and data[source][destination]
        if type(seconds)~="number" or seconds<=0 then return end
        total=total+seconds
    end
    return total>0 and total<7200 and total or nil
end
function Flight:CacheRoutes()
    self.cachedRoutes={};self.cachedDestinations={};self.cachedEstimates={};self.pending=nil
    local count=read(NumTaxiNodes)
    if type(count)~="number" then return end
    local names,origin={},nil
    for i=1,math.min(count,500) do
        local name=read(TaxiNodeName,i)
        if type(name)=="string" then names[i]=name end
        if read(TaxiNodeGetType,i)=="CURRENT" then origin=i end
    end
    if not origin or not names[origin] then return end
    local prefix=tostring(read(GetBuildInfo) or "Forever")..":"..tostring(read(UnitFactionGroup,"player") or "")..":"
    for index,name in pairs(names) do
        if index~=origin and read(TaxiNodeGetType,index)=="REACHABLE" then
            local route={names[origin]}
            local hops=read(GetNumRoutes,index)
            if type(hops)=="number" and hops>0 and hops<=100 and TaxiGetNodeSlot then
                for step=1,hops do
                    local slot=read(TaxiGetNodeSlot,index,step,false)
                    if not names[slot] then route=nil;break end
                    route[#route+1]=names[slot]
                end
            elseif read(TaxiIsDirectFlight,index) then route[#route+1]=name
            else route=nil end
            if route and route[#route]==name then self.cachedRoutes[index]=prefix..table.concat(route," > ");self.cachedDestinations[index]=name;self.cachedEstimates[index]=self:EstimateRoute(route,read(UnitFactionGroup,"player")) end
        end
    end
end
function Flight:SelectRoute(index)
    local key=self.cachedRoutes and self.cachedRoutes[index]
    self.pending=key and {key=key,at=GetTime(),destination=self.cachedDestinations and self.cachedDestinations[index],estimate=self.cachedEstimates and self.cachedEstimates[index]} or nil
end
function Flight:CancelLearning()
    self.cancelled=true;self.duration=nil
    local saved=self:History().active[self:Character()]
    if saved then saved.cancelled=true;saved.duration=nil end
end
function Flight:Tick()
    if not FT.dbReady or not self.display or self.suspended then return end
    local flying=read(UnitOnTaxi,"player")==true
    local now=GetTime and GetTime() or 0
    local history=self:History();local character=self:Character()
    if flying and not self.flying then
        local saved=history.active[character]
        self.started=now;self.route=nil;self.destination=nil;self.duration=nil;self.cancelled=false
        if self.pending and now-self.pending.at<20 then
            self.route=self.pending.key;self.destination=self.pending.destination
            local duration=history.routes[self.route] or self.pending.estimate
            if type(duration)=="number" and duration>0 and duration<7200 then self.duration=duration end
            history.active[character]={key=self.route,at=time(),duration=self.duration,destination=self.destination}
        elseif type(saved)=="table" and type(saved.at)=="number" and time()-saved.at>=0 and time()-saved.at<7200 then
            self.started=now-(time()-saved.at);self.route=saved.key;self.destination=saved.destination
            self.duration=type(saved.duration)=="number" and saved.duration or nil
            self.cancelled=true -- resume display, but don't record time spent offline
        end
        self.pending=nil
    elseif not flying and self.flying then
        local duration=now-(self.started or now)
        if self.route and not self.cancelled and not read(UnitIsDeadOrGhost,"player") and duration>=5 and duration<7200 then
            history.routes[self.route]=duration
        end
        history.active[character]=nil
        self.started=nil;self.route=nil;self.duration=nil
    elseif not flying and not self.flying then
        history.active[character]=nil
    end
    if flying and read(UnitIsDeadOrGhost,"player") then self:CancelLearning() end
    self.flying=flying
    local remaining=self.preview and 165 or self.duration and math.max(0,math.ceil(self.duration-(now-(self.started or now))))
    local text
    if remaining then
        local destination=self.preview and "The Crossroads" or self.destination
        local landing=type(destination)=="string" and ("Landing at "..destination) or "Landing"
        text=remaining>0 and string.format("%s in %dmin%02dsec",landing,math.floor(remaining/60),remaining%60) or landing.." soon"
    elseif self.cancelled then text="Flight: arrival time unknown"
    else text=self.route and "Flight: learning route" or "Flight: arrival time unknown" end
    self.display.text:SetText(text)
    if self.display.text.GetStringWidth then
        local width=self.display.text:GetStringWidth()+24
        self.display:SetWidth(math.min(UIParent:GetWidth()-20,math.max(240,width)))
        self:Position()
    end
    self.display:SetShown(self.preview or (flying and self:Settings().enabled))
end
function Flight:InstallHooks()
    if not hooksecurefunc then return end
    if TakeTaxiNode and not self.takeHook then
        self.takeHook=true;hooksecurefunc("TakeTaxiNode",function(index) if FT.dbReady then self:SelectRoute(index) end end)
    end
    if TaxiRequestEarlyLanding and not self.stopHook then
        self.stopHook=true;hooksecurefunc("TaxiRequestEarlyLanding",function() if FT.dbReady then self:CancelLearning() end end)
    end
end
function Flight:Apply()
    if not FT.dbReady then return end
    self:CreateDisplay();self:InstallHooks()
    local s=self:Settings();local fonts=FT.modules.FontManager
    local path,label=fonts:Resolve(s)
    if not path or not fonts:ValidFont(path) then path="Fonts\\FRIZQT__.TTF";label="Friz Quadrata (fallback)" end
    self.display.text:SetFont(path,s.size,s.outline);self.display.text:SetTextColor(unpack(s.color))
    self.display:SetSize(math.max(240,s.size*15),s.size+16)
    self.display:EnableMouse(self.preview==true);self.display.hint:SetShown(self.preview==true)
    self:Position();self:Tick()
    if self.frame then
        self.toggle.label:SetText("Flight timer: "..(s.enabled and "On" or "Off"));FT:SetSelected(self.toggle,s.enabled)
        self.previewButton.label:SetText(self.preview and "Finish preview / lock" or "Preview / move timer")
        self.fontChoice.label:SetText("Font: "..label)
        self.outlineChoice.label:SetText("Outline: "..(s.outline=="" and "None" or s.outline=="OUTLINE" and "Outline" or "Thick outline"))
        self.sizeLabel:SetText("Font size: "..s.size.." px")
        self.settingSize=true;self.slider:SetValue(s.size);self.settingSize=false
        self.swatch:SetVertexColor(unpack(s.color))
    end
end
function Flight:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsFlightSettings","Flight timer",440,402);self.frame=frame
        -- Keep the initially centered preview clear of its settings window.
        frame:ClearAllPoints();frame:SetPoint("LEFT",UIParent,"LEFT",30,0)
        self.toggle=FT:QuietButton(frame,"",392,34,"fps");self.toggle:SetPoint("TOPLEFT",24,-66)
        self.toggle:SetScript("OnClick",function() local s=self:Settings();s.enabled=not s.enabled;self:Apply() end)
        self.previewButton=FT:QuietButton(frame,"",392,34,"move");self.previewButton:SetPoint("TOPLEFT",24,-106)
        self.previewButton:SetScript("OnClick",function() self:Drag();self.dragging=false;self.preview=not self.preview;self:Apply() end)
        self.fontChoice=FT:Dropdown(frame,392,function() return FT.modules.FontManager:Catalogue() end,function(value) self:Settings().font=value;self:Apply() end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",24,-146)
        self.outlineChoice=FT:Dropdown(frame,392,function() return {{value="",label="No outline"},{value="OUTLINE",label="Outline"},{value="THICKOUTLINE",label="Thick outline"}} end,function(value) self:Settings().outline=value;self:Apply() end,"fonts")
        self.outlineChoice:SetPoint("TOPLEFT",24,-186)
        self.sizeLabel=FT:Label(frame,"",13);self.sizeLabel:SetPoint("TOPLEFT",24,-234)
        self.slider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate");self.slider:SetSize(220,18);self.slider:SetPoint("TOPLEFT",190,-234)
        self.slider:SetMinMaxValues(10,48);self.slider:SetValueStep(1);self.slider:SetObeyStepOnDrag(true)
        self.slider:SetScript("OnValueChanged",function(_,value) if not self.settingSize then self:Settings().size=math.floor(value+.5);self:Apply() end end)
        local color=FT:QuietButton(frame,"Text color",392,34,"fonts");color:SetPoint("TOPLEFT",24,-270)
        self.swatch=color:CreateTexture(nil,"ARTWORK");self.swatch:SetTexture("Interface\\Buttons\\WHITE8X8");self.swatch:SetSize(18,18);self.swatch:SetPoint("RIGHT",-12,0)
        color:SetScript("OnClick",function()
            if not ColorPickerFrame then return end
            local s=self:Settings();local old={unpack(s.color)}
            local function change() s.color={ColorPickerFrame:GetColorRGB()};self:Apply() end
            local function cancel() s.color=old;self:Apply() end
            if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
            else ColorPickerFrame:SetColorRGB(unpack(old));ColorPickerFrame.func=change;ColorPickerFrame.cancelFunc=cancel;ColorPickerFrame:Show() end
        end)
        local reset=FT:QuietButton(frame,"Reset position to center",392,34,"reset");reset:SetPoint("TOPLEFT",24,-310)
        reset:SetScript("OnClick",function() FT:Confirm("Return the flight timer to the screen center?",function() local s=self:Settings();s.x=.5;s.y=.5;self:Apply() end) end)
        local note=FT:Label(frame,"Changes apply immediately. Save them to a profile.",11);note:SetPoint("TOPLEFT",24,-360)
        FT:Tooltip(self.previewButton,"Flight timer","Drag the preview to move it. Closing this window locks it. Shows estimated time until landing. Includes Classic route estimates. Your completed flights refine them. Unlisted routes are learned after one flight. Early landings are not recorded.")
        frame:HookScript("OnHide",function() self:Drag();self.dragging=false;self.preview=false;self:Apply() end)
    end
    self.preview=true;self:Apply();self.frame:Show()
end
FT:RegisterModule("FlightTimer",Flight)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
for _,event in ipairs({"TAXIMAP_OPENED","PLAYER_LEAVING_WORLD","PLAYER_ENTERING_WORLD","PLAYER_DEAD"}) do pcall(events.RegisterEvent,events,event) end
 events:SetScript("OnEvent",function(_,event)
    if not FT.dbReady then return end
    if event=="TAXIMAP_OPENED" then
        Flight:InstallHooks();Flight:CacheRoutes()
    elseif event=="PLAYER_LEAVING_WORLD" then
        Flight.suspended=true
        if Flight.flying then Flight:CancelLearning() end
    elseif event=="PLAYER_ENTERING_WORLD" then
        Flight.suspended=false;Flight:Apply()
    elseif event=="PLAYER_DEAD" then Flight:CancelLearning()
    else Flight:Apply() end
end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt;if elapsed<.2 then return end;elapsed=0
    if Flight.preview and InCombatLockdown() then Flight.preview=false;Flight.dragging=false;Flight:Apply() end
    Flight:Tick()
end)
