local _,FT=...
local Flight={}
local function number(value,default,low,high)
    if type(value)~="number" or value~=value then return default end
    return math.max(low,math.min(high,value))
end
function Flight:Settings()
    if type(FT.db.flightTimer)~="table" then FT.db.flightTimer={} end
    local s=FT.db.flightTimer
    if not s.compactDefaults then
        if s.font=="friz" and s.size==20 and s.outline=="OUTLINE" and type(s.color)=="table" and s.color[1]==1 and s.color[2]==1 and s.color[3]==1 then
            s.font="arial";s.size=18;s.color={211/255,1,126/255}
        end
        s.compactDefaults=true
    end
    if s.enabled==nil then s.enabled=false end
    s.size=number(s.size,18,10,48)
    s.x=number(s.x,.5,0,1);s.y=number(s.y,.5,0,1)
    if type(s.font)~="string" then s.font="arial" end
    if s.outline~="" and s.outline~="OUTLINE" and s.outline~="THICKOUTLINE" then s.outline="OUTLINE" end
    if type(s.color)~="table" then s.color={211/255,1,126/255} end
    -- A thin bar under the text that fills as the flight goes on.
    if type(s.bar)~="boolean" then s.bar=true end
    for i=1,3 do s.color[i]=number(s.color[i],1,0,1) end
    -- 1.8.0: class color by default. Players who kept the old default color
    -- move to class color; a color someone picked stays.
    if type(s.classColor)~="boolean" then
        local c=s.color
        s.classColor=math.abs(c[1]-211/255)<.01 and math.abs(c[2]-1)<.01 and math.abs(c[3]-126/255)<.01
    end
    return s
end
-- The timer's color: your class color, or the color you picked.
function Flight:Color()
    local s=self:Settings()
    if s.classColor then
        local _,class=UnitClass("player")
        local c=class and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class) or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if c and c.r then return c.r,c.g,c.b end
    end
    return unpack(s.color)
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
    -- One line: the countdown on the left at a fixed width (so it never
    -- jumps as digits change), a dim dash, then the destination as its own
    -- unit. Long names are cut short instead of wrapping.
    display.timer=FT:Label(display,"",20);display.timer:SetPoint("LEFT",display,"LEFT",10,0);display.timer:SetJustifyH("RIGHT");display.timer:SetWordWrap(false)
    display.dash=FT:Label(display,"-",20);display.dash:SetPoint("LEFT",display.timer,"RIGHT",10,0);display.dash:SetWordWrap(false)
    display.text=FT:Label(display,"",16);display.text:SetPoint("LEFT",display.dash,"RIGHT",10,0);display.text:SetJustifyH("LEFT");display.text:SetWordWrap(false)
    -- The progress bar: a dark track, a fill in the timer's color (darker
    -- where it started), and a soft spark at its edge. It moves smoothly on
    -- its own while shown; the rest of the display updates five times a second.
    local bar=FT:ProgressBar(display,4);display.bar=bar
    bar:SetScript("OnUpdate",function(b) local f=self:Progress(); if f then b:SetFraction(f) end end)
    bar:Hide()
    -- The same outline and hint as the FPS counter and leveling stats while moving.
    FT:MoverBox(display,0)
    display.hint=FT:Label(display,"Drag to move",12);FT:Caption(display.hint,display,"below",0)
    display:RegisterForDrag("LeftButton")
    display:SetScript("OnDragStart",function()
        if not self.preview or InCombatLockdown() then return end
        local x,y=GetCursorPosition();local scale=UIParent:GetEffectiveScale()
        local cx,cy=display:GetCenter();self.dragX=cx-x/scale;self.dragY=cy-y/scale;self.dragging=true
    end)
    display:SetScript("OnDragStop",function() self:Drag();self.dragging=false end)
    display:SetScript("OnUpdate",function() self:Drag() end)
end
-- Sizes the one-line display around its parts. The timer keeps the width of
-- its widest possible text so the dash and name stay put while counting.
function Flight:Layout(timer,place,known)
    local d=self.display;local s=self:Settings()
    d.timer:SetText(timer);d.text:SetText(place)
    d.timer:SetAlpha(known and 1 or .55)
    local wide=#timer>5 and "0:00:00" or "00:00"
    if d.measuredFor~=wide..s.size then
        d.timer:SetText(wide);d.measuredFor=wide..s.size;d.timerWidth=math.ceil(d.timer:GetStringWidth()+2);d.timer:SetText(timer)
    end
    d.timer:SetWidth(d.timerWidth or s.size*3)
    local maxName=math.max(120,math.min(360,UIParent:GetWidth()-(d.timerWidth or 0)-80))
    d.text:SetWidth(0);local nameWidth=math.min(maxName,math.ceil(d.text:GetStringWidth()+2));d.text:SetWidth(nameWidth)
    d:SetWidth(10+(d.timerWidth or 0)+10+d.dash:GetStringWidth()+10+nameWidth+10)
    local withBar=s.bar and known
    d:SetHeight(s.size+16+(withBar and 6 or 0))
    -- The text sits a little higher over the bar.
    d.timer:ClearAllPoints();d.timer:SetPoint("LEFT",d,"LEFT",10,withBar and 3 or 0)
    -- Under the text itself: from the first digit (the timer is right-aligned
    -- in its fixed box) to the end of the place name, whatever the font,
    -- size and timer length. Measured once per flight with every digit as a
    -- 0 (the widest), so the bar never moves while the time counts down.
    if withBar then
        local key=tostring(self.preview and "preview" or self.started)..s.size..tostring(d.timer:GetFont())..place
        if d.barFor~=key then
            d.timer:SetText((timer:gsub("%d","0")))
            d.barDigits=math.ceil(d.timer:GetStringWidth() or 0); d.barFor=key
            d.timer:SetText(timer)
        end
        local digits=d.barDigits
        local width=digits+10+(d.dash:GetStringWidth() or 0)+10+math.max(0,nameWidth-2)
        d.bar:ClearAllPoints()
        d.bar:SetPoint("TOPLEFT",d.timer,"BOTTOMRIGHT",-digits,-2)
        d.bar:SetWidth(math.max(20,width))
    end
    d.bar:SetShown(withBar and true or false)
end
-- How far along the flight is (0 to 1), or nil when the time isn't known.
function Flight:Progress()
    if self.preview then
        local t=(GetTime() or 0)%30
        return t/30
    end
    if not (self.duration and self.duration>0 and self.started) then return end
    return math.max(0,math.min(1,((GetTime() or 0)-self.started)/self.duration))
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
-- Frequent Flier (WoW: Forever Legacy perk, chosen per character): the flight
-- mount flies 20% faster, so the flight takes 1/1.2 of the time. Every time
-- we keep is at normal speed; a Frequent Flier sees it shortened.
local FAST=1/1.2
local FF_NAME="Frequent Flier"
-- What we know about this character: true (has it), false (doesn't) or nil.
-- Three things tell, best first:
--  1. the perk itself, when the game lists it among your spells (checked
--     before every flight);
--  2. flights: landing about 17% sooner than a known time (twice), or on time;
--  3. prices: Frequent Flier halves the fare. Another of your characters
--     whose speed is known saw the same route's normal price (faction
--     discounts are at most 20%, so half price can't be mistaken).
function Flight:SpeedInfo()
    local history=self:History()
    if type(history.speed)~="table" then history.speed={} end
    local me=self:Character()
    if type(history.speed[me])~="table" then history.speed[me]={} end
    return history.speed[me]
end
function Flight:PerkKnown()
    local id=self.perkSpell
    if not id and C_Spell and C_Spell.GetSpellInfo then
        local info=read(C_Spell.GetSpellInfo,FF_NAME)
        if type(info)=="table" and type(info.spellID)=="number" then id=info.spellID;self.perkSpell=id end
    end
    if id and IsPlayerSpell and read(IsPlayerSpell,id)==true then return true end
end
function Flight:FrequentFlier()
    local info=self:SpeedInfo()
    if self:PerkKnown() then info.ff=true;info.from="perk";return true end
    local votes=type(info.votes)=="number" and info.votes or 0
    if votes>=1.5 then return true end
    if votes<=-1.5 then return false end
    if info.price~=nil then return info.price end
    return info.ff
end
function Flight:Speed()
    return self:FrequentFlier() and FAST or 1
end
-- A landing with a known normal-speed time: votes for or against.
function Flight:Vote(actual,expected,weight)
    if type(expected)~="number" or expected<30 or actual<20 then return end
    local ratio=actual/expected;local info=self:SpeedInfo()
    local votes=type(info.votes)=="number" and info.votes or 0
    if ratio>=.76 and ratio<=.9 then votes=math.min(3,votes+weight)
    elseif ratio>=.93 and ratio<=1.08 then votes=math.max(-3,votes-weight) end
    info.votes=votes
end
local function nodeName(name)
    if type(name)~="string" then return end
    return name:match("^[^,]+"):lower():gsub("^the%s+",""):match("^%s*(.-)%s*$")
end
-- Seconds for a route: known hop times (your own recorded hops, then the
-- defaults). A hop nobody has a time for (new WoW: Forever flight points such
-- as Rog'mar) is estimated from its length on the flight map, at the speed
-- the known hops on this map fly. Returns seconds and whether any part of it
-- is such an estimate.
function Flight:HopTime(fromName,toName,faction)
    local hops=self:History().hops
    local own=hops and hops[faction..":"..tostring(fromName)..">"..tostring(toName)]
    if type(own)=="number" and own>0 then return own end
    local data=FT.flightDefaults and FT.flightDefaults[faction]
    if not data then return end
    local byName=self.byName and self.byName[faction]
    if not byName then
        byName={}
        for id,node in pairs(data) do if type(node)=="table" and node.name then byName[nodeName(node.name)]=id end end
        self.byName=self.byName or {}; self.byName[faction]=byName
    end
    local source,destination=byName[nodeName(fromName)],byName[nodeName(toName)]
    local seconds=source and destination and data[source][destination]
    if type(seconds)~="number" or seconds<=0 then
        -- Same hop the other way round: close enough.
        seconds=source and destination and data[destination][source]
    end
    if type(seconds)=="number" and seconds>0 then return seconds end
end
-- A recorded time for this route: this game version's, else the last one
-- from before a game update (until the route is flown again).
function Flight:Learned(key,anyKey)
    local history=self:History()
    local seconds=key and history.routes[key]
    if type(seconds)=="number" and seconds>0 then return seconds end
    seconds=anyKey and type(history.latest)=="table" and history.latest[anyKey]
    if type(seconds)=="number" and seconds>0 then return seconds end
end
function Flight:EstimateRoute(route,faction,points)
    if #route<2 then return end
    -- The hops the game says this flight takes, added up. Checked against
    -- 19 recorded multi-hop flights: within 1-2 seconds every time, while a
    -- start-to-end time is for the way Classic flew it, which WoW: Forever
    -- sometimes changed (1.11.0). So the hops win; the start-to-end time is
    -- used only when a hop has no time.
    local total,guessed=0,false
    local unknown={}
    for i=1,#route-1 do
        local seconds=self:HopTime(route[i],route[i+1],faction)
        if seconds then total=total+seconds else unknown[#unknown+1]=i end
    end
    if not unknown[1] and total>0 and total<7200 then return math.floor(total+.5),false end
    local whole=self:HopTime(route[1],route[#route],faction)
    if whole and whole<7200 then return math.floor(whole+.5),false end
    if unknown[1] then
        local rate=self.mapRate
        if not rate or not points then return end
        for _,i in ipairs(unknown) do
            local a,b=points[i],points[i+1]
            if not a or not b then return end
            total=total+math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2)*rate
        end
        guessed=true
    end
    if total>0 and total<7200 then return math.floor(total+.5),guessed end
end
function Flight:CacheRoutes()
    self.cachedRoutes={};self.cachedDestinations={};self.cachedEstimates={};self.cachedGuess={};self.cachedHops={};self.cachedAny={};self.pending=nil
    local count=read(NumTaxiNodes)
    if type(count)~="number" then return end
    local names,spots,origin={},{},nil
    for i=1,math.min(count,500) do
        local name=read(TaxiNodeName,i)
        if type(name)=="string" then names[i]=name end
        if TaxiNodePosition then
            local ok,x,y=pcall(TaxiNodePosition,i)
            if ok and type(x)=="number" and type(y)=="number" and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then spots[i]={x,y} end
        end
        if read(TaxiNodeGetType,i)=="CURRENT" then origin=i end
    end
    if not origin or not names[origin] then return end
    local faction=read(UnitFactionGroup,"player") or ""
    local prefix=tostring(read(GetBuildInfo) or "Forever")..":"..tostring(faction)..":"
    local routes={}
    for index,name in pairs(names) do
        if index~=origin and read(TaxiNodeGetType,index)=="REACHABLE" then
            local route,points={names[origin]},{spots[origin]}
            local hops=read(GetNumRoutes,index)
            if type(hops)=="number" and hops>0 and hops<=100 and TaxiGetNodeSlot then
                for step=1,hops do
                    local slot=read(TaxiGetNodeSlot,index,step,false)
                    -- A flight point you haven't found can still be flown
                    -- through: its name comes from the game all the same.
                    local hop=names[slot] or (type(slot)=="number" and read(TaxiNodeName,slot))
                    if type(hop)~="string" then route=nil;break end
                    route[#route+1]=hop;points[#points+1]=spots[slot]
                end
            elseif read(TaxiIsDirectFlight,index) then route[#route+1]=name;points[#points+1]=spots[index]
            else route=nil end
            if route and route[#route]==name then routes[index]={route,points} end
        end
    end
    -- The speed on this flight map: seconds per map length, the middle
    -- value over every hop with a known time (so a few wrong times can't
    -- pull it off).
    local rates,seen={},{}
    for _,r in pairs(routes) do
        local route,points=r[1],r[2]
        for i=1,#route-1 do
            local key=route[i]..">"..route[i+1]
            local a,b=points[i],points[i+1]
            if not seen[key] and a and b then
                seen[key]=true
                local t=self:HopTime(route[i],route[i+1],faction)
                local d=math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2)
                if t and d>0.01 then rates[#rates+1]=t/d end
            end
        end
    end
    table.sort(rates)
    self.mapRate=#rates>0 and rates[math.floor((#rates+1)/2)] or nil
    local history=self:History()
    if type(history.costs)~="table" then history.costs={} end
    local ff=self:FrequentFlier();local info=self:SpeedInfo()
    local cheap,normal=0,0
    for index,r in pairs(routes) do
        local route,points=r[1],r[2]
        self.cachedRoutes[index]=prefix..table.concat(route," > ")
        self.cachedAny[index]=tostring(faction)..":"..table.concat(route," > ")
        self.cachedDestinations[index]=names[index]
        self.cachedHops[index]=route
        local estimate,guessed=self:EstimateRoute(route,faction,points)
        -- WoW: Forever flies some routes another way than Classic did (the
        -- times we start from). When the known time is far off from the
        -- route's length on the map, the map is closer: shown as ~.
        if estimate and not guessed and #rates>=4 then
            local length=0
            for i=1,#route-1 do
                local a,b=points[i],points[i+1]
                if not a or not b then length=nil;break end
                length=length+math.sqrt((a[1]-b[1])^2+(a[2]-b[2])^2)
            end
            local byMap=length and length*self.mapRate
            if byMap and byMap>30 and math.abs(estimate-byMap)>math.max(45,byMap*.35) then estimate=math.floor(byMap+.5);guessed=true end
        end
        self.cachedEstimates[index],self.cachedGuess[index]=estimate,guessed
        -- Fares: a normal price kept from your characters whose speed is
        -- known tells this one's.
        local cost=read(TaxiNodeCost,index)
        if type(cost)=="number" and cost>0 then
            local key=self.cachedAny[index]
            if ff~=nil then
                history.costs[key]=ff and cost*2 or cost
            elseif type(history.costs[key])=="number" and history.costs[key]>0 then
                local ratio=cost/history.costs[key]
                if ratio<.7 then cheap=cheap+1 elseif ratio>.75 then normal=normal+1 end
            end
        end
    end
    if ff==nil and cheap+normal>0 then info.price=cheap>normal end
end
function Flight:SelectRoute(index)
    local key=self.cachedRoutes and self.cachedRoutes[index]
    self.pending=key and {key=key,at=GetTime(),destination=self.cachedDestinations and self.cachedDestinations[index],estimate=self.cachedEstimates and self.cachedEstimates[index],
        guess=self.cachedGuess and self.cachedGuess[index],hops=self.cachedHops and self.cachedHops[index],any=self.cachedAny and self.cachedAny[index]} or nil
end
-- why: "stop" (you asked to land early) shows "Stop requested" on the timer.
function Flight:CancelLearning(why)
    self.cancelled=true;self.duration=nil
    if why then self.stopWhy=why end
    local saved=self:History().active[self:Character()]
    if saved then saved.cancelled=true;saved.duration=nil;saved.why=why or saved.why end
end
function Flight:Tick()
    if not FT.dbReady or not self.display or self.suspended then return end
    local flying=read(UnitOnTaxi,"player")==true
    local now=GetTime and GetTime() or 0
    -- On the ground with nothing to show: nothing to do (this runs five
    -- times a second).
    if not flying and not self.flying and not self.preview then
        if self.display:IsShown() then self.display:Hide() end
        if self.groundCleared then return end
        self.groundCleared=true
    else
        self.groundCleared=nil
    end
    local history=self:History();local character=self:Character()
    if flying and not self.flying then
        local saved=history.active[character]
        self.started=now;self.route=nil;self.destination=nil;self.duration=nil;self.cancelled=false;self.stopWhy=nil
        if self.pending and now-self.pending.at<20 then
            self.route=self.pending.key;self.destination=self.pending.destination;self.any=self.pending.any
            local learned=self:Learned(self.route,self.any)
            local duration=learned or self.pending.estimate
            -- Normal-speed time, and how sure we are of it (for the
            -- Frequent Flier check after landing).
            self.expected=duration;self.expectedWeight=learned and 1 or (not self.pending.guess and .5) or nil
            self.speed=self:Speed()
            if type(duration)=="number" and duration>0 then duration=duration*self.speed end
            if type(duration)=="number" and duration>0 and duration<7200 then self.duration=duration end
            self.guess=not learned and self.pending.guess or nil
            self.hops=self.pending.hops
            history.active[character]={key=self.route,at=time(),duration=self.duration,destination=self.destination}
        elseif type(saved)=="table" and type(saved.at)=="number" and time()-saved.at>=0 and time()-saved.at<7200 then
            self.started=now-(time()-saved.at);self.route=saved.key;self.destination=saved.destination
            self.duration=type(saved.duration)=="number" and saved.duration or nil
            self.cancelled=true -- resume display, but don't record time spent offline
            self.stopWhy=saved.why
        end
        self.pending=nil
    elseif not flying and self.flying then
        local duration=now-(self.started or now)
        if self.route and not self.cancelled and not read(UnitIsDeadOrGhost,"player") and duration>=5 and duration<7200 then
            if self.expectedWeight then self:Vote(duration,self.expected,self.expectedWeight) end
            local ff=self:FrequentFlier()
            -- Kept at normal speed. While we don't know yet whether this
            -- character is a Frequent Flier, a flight that looks like one
            -- isn't kept (it would make the time too short for others).
            local ratio=type(self.expected)=="number" and self.expected>0 and duration/self.expected
            if ff~=nil or not (ratio and ratio>=.76 and ratio<=.9) then
                local normal=ff and duration/FAST or duration
                history.routes[self.route]=normal
                if self.any then
                    if type(history.latest)~="table" then history.latest={} end
                    history.latest[self.any]=math.floor(normal+.5)
                end
                -- A direct flight is also a hop time: longer routes through it
                -- use it (and new flight points get real times this way).
                local hops=self.hops
                if type(hops)=="table" and #hops==2 then
                    if type(history.hops)~="table" then history.hops={} end
                    history.hops[(read(UnitFactionGroup,"player") or "")..":"..hops[1]..">"..hops[2]]=math.floor(normal+.5)
                end
            end
        end
        self.guess=nil;self.hops=nil;self.any=nil;self.expected=nil;self.expectedWeight=nil
        history.active[character]=nil
        self.started=nil;self.route=nil;self.duration=nil
    elseif not flying and not self.flying then
        history.active[character]=nil
    end
    if flying and read(UnitIsDeadOrGhost,"player") then self:CancelLearning() end
    self.flying=flying
    local remaining=self.preview and 24 or self.duration and math.max(0,math.ceil(self.duration-(now-(self.started or now))))
    -- Longer than expected: count the extra time ("+0:12") instead of
    -- standing at 0:00. The real time is kept when you land.
    local over=not self.preview and self.duration and flying and math.floor((now-(self.started or now))-self.duration) or 0
    local destination=self.preview and "Crossroads, The Barrens" or self.destination
    local timer,place
    if remaining then
        timer=remaining>=3600 and string.format("%d:%02d:%02d",math.floor(remaining/3600),math.floor(remaining%3600/60),remaining%60) or string.format("%d:%02d",math.floor(remaining/60),remaining%60)
        if self.guess and not self.preview then timer="~"..timer end
        if over>0 then timer=string.format("+%d:%02d",math.floor(over/60),over%60) end
        place=type(destination)=="string" and destination or "Landing soon"
    else
        -- No time for this route yet: count up instead, and say the flight
        -- is being recorded (next time this route has its own time).
        local recording=self.route and not self.cancelled and not self.preview
        local elapsed=math.max(0,math.floor(now-(self.started or now)))
        timer=elapsed>=3600 and string.format("%d:%02d:%02d",math.floor(elapsed/3600),math.floor(elapsed%3600/60),elapsed%60) or string.format("%d:%02d",math.floor(elapsed/60),elapsed%60)
        local where=type(destination)=="string" and destination:match("^[^,]+") or nil
        if self.stopWhy=="stop" and not self.preview then place="Stop requested, landing soon"
        elseif recording then place=where and ("Recording time to "..where) or "Recording this flight's time"
        else place=where and (where.." (arrival time unknown)") or "Arrival time unknown" end
    end
    self:Layout(timer,place,remaining~=nil)
    self:Position()
    self.display:SetShown(self.preview or (flying and self:Settings().enabled))
end
-- /ft flighttimes: every flight time you recorded, at normal speed, to copy
-- and send in (they go into the addon's times for everyone).
function Flight:Export()
    local history=self:History();local lines={}
    local ff=self:FrequentFlier()
    lines[#lines+1]="ForeverTools "..tostring(FT.version).." flight times (normal speed, seconds). This character: "..(ff==true and "Frequent Flier" or ff==false and "no Frequent Flier" or "Frequent Flier not known yet")
    local list={}
    for key,seconds in pairs(type(history.hops)=="table" and history.hops or {}) do if type(seconds)=="number" then list[#list+1]="hop "..key.." = "..seconds end end
    for key,seconds in pairs(type(history.latest)=="table" and history.latest or {}) do if type(seconds)=="number" then list[#list+1]="route "..key.." = "..seconds end end
    table.sort(list)
    for _,line in ipairs(list) do lines[#lines+1]=line end
    if #list==0 then lines[#lines+1]="No flights recorded yet." end
    FT:CopyBox("Flight times",table.concat(lines,"\n"),"Ctrl+A to select all, Ctrl+C to copy, then paste it in a message or on CurseForge.",true)
end
function Flight:InstallHooks()
    if not hooksecurefunc then return end
    if TakeTaxiNode and not self.takeHook then
        self.takeHook=true;hooksecurefunc("TakeTaxiNode",function(index) if FT.dbReady then self:SelectRoute(index) end end)
    end
    if TaxiRequestEarlyLanding and not self.stopHook then
        self.stopHook=true;hooksecurefunc("TaxiRequestEarlyLanding",function() if FT.dbReady then self:CancelLearning("stop"); self:Tick() end end)
    end
end
function Flight:Apply()
    if not FT.dbReady then return end
    self:CreateDisplay();self:InstallHooks()
    local s=self:Settings();local fonts=FT.modules.FontManager
    local path,label=fonts:Resolve(s)
    if not path or not fonts:ValidFont(path) then path="Fonts\\FRIZQT__.TTF";label="Friz Quadrata (fallback)" end
    local d=self.display;local small=math.max(10,math.floor(s.size*.78+.5))
    d.timer:SetFont(path,s.size,s.outline);d.timer:SetTextColor(self:Color())
    d.dash:SetFont(path,small,s.outline);d.dash:SetTextColor(.62,.62,.62)
    d.text:SetFont(path,small,s.outline);d.text:SetTextColor(.92,.92,.92)
    d.bar:SetColor(self:Color())
    d.measuredFor=nil
    -- Behind game windows; on top only while you preview and move it.
    self.display:SetFrameStrata(self.preview and "HIGH" or "LOW")
    FT:LockedMouse(self.display,self.preview~=true,"FlightTimer");self.display.hint:SetShown(self.preview==true)
    for _,texture in ipairs(self.display.fillTextures) do texture:SetShown(self.preview==true) end
    for _,texture in ipairs(self.display.borderTextures) do texture:SetShown(self.preview==true) end
    self:Position();self:Tick()
    if self.frame then
        self.toggle.label:SetText("Flight timer: "..(s.enabled and "On" or "Off"));FT:SetSelected(self.toggle,s.enabled)
        FT:RefreshPreview(self.frame)
        self.fontChoice.label:SetText("Font: "..label)
        self.outlineChoice.label:SetText("Outline: "..(s.outline=="" and "None" or s.outline=="OUTLINE" and "Outline" or "Thick outline"))
        self.sizeLabel:SetText("Font size: "..s.size.." px")
        self.settingSize=true;self.slider:SetValue(s.size);self.settingSize=false
        self.colorChoice.label:SetText("Text color: "..(s.classColor and "Class color" or "Your color"))
        self.barToggle.label:SetText("Progress bar: "..(s.bar and "On" or "Off"));FT:SetSelected(self.barToggle,s.bar)
    end
end
function Flight:Open()
    if not self.frame then
        local frame=FT:Window("ForeverToolsFlightSettings","Flight timer",540,420);self.frame=frame
        -- Opens centered like every other page; Back returns to System > On-screen info.
        FT:BackTo(frame,"SystemDisplay")
        self.toggle=FT:AccentButton(frame,"",492,34,FT:FlightIcon());self.toggle:SetPoint("TOPLEFT",24,-62)
        self.toggle:SetScript("OnClick",function() local s=self:Settings();s.enabled=not s.enabled;self:Apply() end)
        self.previewButton=FT:TopPreview(frame,self.toggle,{get=function() return self.preview==true end,
            set=function(on) self:Drag();self.dragging=false;self.preview=on and true or false;self:Apply() end})
        self.fontChoice=FT:Dropdown(frame,492,function() return FT.modules.FontManager:Catalogue() end,function(value) self:Settings().font=value;self:Apply() end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",24,-104)
        FT:Tooltip(self.fontChoice,"Font","The font of the flight timer.")
        FT:Tooltip(self.toggle,"Flight timer","Show how long until you land.")
        self.outlineChoice=FT:Dropdown(frame,492,function() return {{value="",label="No outline"},{value="OUTLINE",label="Outline"},{value="THICKOUTLINE",label="Thick outline"}} end,function(value) self:Settings().outline=value;self:Apply() end,"fonts")
        self.outlineChoice:SetPoint("TOPLEFT",24,-144)
        FT:Tooltip(self.outlineChoice,"Outline","A dark edge so the text stays readable.")
        self.sizeLabel=FT:Label(frame,"",13);self.sizeLabel:SetPoint("TOPLEFT",24,-192)
        self.slider=CreateFrame("Slider",nil,frame,"OptionsSliderTemplate");self.slider:SetSize(300,18);self.slider:SetPoint("TOPLEFT",216,-192)
        self.slider:SetMinMaxValues(10,48);self.slider:SetValueStep(1);self.slider:SetObeyStepOnDrag(true)
        self.slider:SetScript("OnValueChanged",function(_,value) if not self.settingSize then self:Settings().size=math.floor(value+.5);FT:Coalesce("flightSlider",function() self:Apply() end,.05) end end)
        local color=FT:QuietButton(frame,"Text color: Class color",492,34,"fonts");color:SetPoint("TOPLEFT",24,-228);self.colorChoice=color
        local function pick()
            if not ColorPickerFrame then return end
            local s=self:Settings();local old={unpack(s.color)};local wasClass=s.classColor
            local function change() s.color={ColorPickerFrame:GetColorRGB()};s.classColor=false;FT:Coalesce("flightColor",function() self:Apply() end,.05) end
            local function cancel() s.color=old;s.classColor=wasClass;self:Apply() end
            if ColorPickerFrame.SetupColorPickerAndShow then FT:TrackColorPicker();ColorPickerFrame:SetupColorPickerAndShow({r=old[1],g=old[2],b=old[3],hasOpacity=false,swatchFunc=change,cancelFunc=cancel})
            else ColorPickerFrame:SetColorRGB(unpack(old));ColorPickerFrame.func=change;ColorPickerFrame.cancelFunc=cancel;ColorPickerFrame:Show() end
        end
        FT:MakeChoice(color,{{"class","Class color","Your class color."},{"own","Your color","Pick a color yourself."}},
            function() return self:Settings().classColor and "class" or "own" end,
            function(v) local s=self:Settings(); if v=="class" then s.classColor=true; self:Apply() else s.classColor=false; self:Apply(); pick() end end)
        FT:Tooltip(color,"Text color","The color of the flight timer's text and bar: your class color, or a color you pick.")
        FT:Tooltip(self.slider,"Font size","Text size of the flight timer (10 to 48).")
        self.barToggle=FT:QuietButton(frame,"",492,34,FT:FlightIcon());self.barToggle:SetPoint("TOPLEFT",24,-268)
        self.barToggle:SetScript("OnClick",function() local s=self:Settings();s.bar=not s.bar;self:Apply() end)
        FT:Tooltip(self.barToggle,"Progress bar","A thin bar under the timer that fills as the flight goes on, in the text color. Shows when the flight time is known.")
        local reset=FT:QuietButton(frame,"Reset position to center",492,34,"reset");reset:SetPoint("TOPLEFT",24,-316)
        FT:Tooltip(reset,"Reset position","Back to the middle of the screen. Asks first.")
        reset:SetScript("OnClick",function() FT:Confirm("Return the flight timer to the screen center?",function() local s=self:Settings();s.x=.5;s.y=.5;self:Apply() end) end)
        FT:Sections(frame,{{"Look",self.fontChoice},{"Position",reset}})
        FT:PageInfo(frame,"Flight timer","How long until you land. Times get more exact with every flight, and Frequent Flier is noticed by itself. /ft flighttimes lists your recorded times to send in.")
    end
    self:Apply();self.frame:Show()
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
