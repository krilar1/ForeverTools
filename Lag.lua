local _,FT=...
-- /ft lag: a 20 second recording for bug reports about stutter. While it
-- runs, every ForeverTools function called through its module is timed
-- (debugprofilestop), so a slow frame can be traced to the part that ran in
-- it. The game's own add-on profiler, when present, shows whether another
-- add-on is the one taking the time. Nothing is changed for good: the timers
-- are taken off again when the recording ends.
local Lag={}
local SECONDS=20
local SLOW=40 -- a frame this many ms long counts as a hitch
local function clock() if debugprofilestop then return debugprofilestop() end return GetTime()*1000 end
local function pack(...) return {n=select("#",...),...} end
local unpack=unpack or table.unpack

local function addonNames()
    local list={}
    local count=C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or (GetNumAddOns and GetNumAddOns()) or 0
    for i=1,count do
        local ok,name=pcall(C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo,i)
        if ok and type(name)=="string" then list[#list+1]=name end
    end
    return list
end
local function metric(name,kind)
    local P=C_AddOnProfiler; local E=Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and E and E[kind]) then return nil end
    local ok,v=pcall(P.GetAddOnMetric,name,E[kind])
    if ok and type(v)=="number" and not (issecretvalue and issecretvalue(v)) then return v end
end

-- Timing wrappers --------------------------------------------------------
function Lag:Wrap()
    self.saved={}; self.stats={}; self.frameFT=0; self.depth=0
    local stats=self.stats
    local function timed(label,fn)
        return function(...)
            if Lag.depth>0 then
                -- Inside another timed call: count it, time it as part of the caller too.
                Lag.depth=Lag.depth+1
                local t=clock()
                local r=pack(pcall(fn,...))
                Lag.depth=Lag.depth-1
                local ms=clock()-t
                local s=stats[label] or {n=0,ms=0,max=0}; stats[label]=s
                s.n=s.n+1; s.ms=s.ms+ms; if ms>s.max then s.max=ms end
                if not r[1] then error(r[2],0) end
                return unpack(r,2,r.n)
            end
            Lag.depth=1
            local t=clock()
            local r=pack(pcall(fn,...))
            Lag.depth=0
            local ms=clock()-t
            Lag.frameFT=Lag.frameFT+ms
            local s=stats[label] or {n=0,ms=0,max=0}; stats[label]=s
            s.n=s.n+1; s.ms=s.ms+ms; if ms>s.max then s.max=ms end
            if ms>(Lag.frameTop and Lag.frameTop.ms or 0) then Lag.frameTop={label=label,ms=ms} end
            if not r[1] then error(r[2],0) end
            return unpack(r,2,r.n)
        end
    end
    local seen={}
    local function wrapTable(owner,prefix)
        if type(owner)~="table" or seen[owner] or owner==Lag then return end
        seen[owner]=true
        for key,fn in pairs(owner) do
            if type(fn)=="function" and type(key)=="string" and key~="Settings" then
                self.saved[#self.saved+1]={owner,key,fn}
                owner[key]=timed(prefix..key,fn)
            end
        end
    end
    for name,module in pairs(FT.modules or {}) do wrapTable(module,name..":") end
    for _,name in ipairs({"Bags","Enemies","BuffRanks","Skins"}) do wrapTable(FT[name],name..":") end
    -- Delayed jobs ("one pass a moment after the last bag change") by name.
    local coalesce=FT.Coalesce
    self.saved[#self.saved+1]={FT,"Coalesce",coalesce}
    FT.Coalesce=function(owner,key,fn,delay)
        local label="job "..tostring(key):gsub("table: %x+",""):gsub("%d%d%d+","#")
        return coalesce(owner,key,timed(label,fn),delay)
    end
end
function Lag:Unwrap()
    for i=#(self.saved or {}),1,-1 do local s=self.saved[i]; s[1][s[2]]=s[3] end
    self.saved=nil
end

-- Recording --------------------------------------------------------------
function Lag:Start()
    if self.running then print("|cffffd100ForeverTools:|r already recording, "..math.ceil(self.left or 0).." s left."); return end
    self.running=true; self.left=SECONDS; self.hitches={}; self.frames=0; self.worst=0
    self.addonsBefore={}
    for _,name in ipairs(addonNames()) do self.addonsBefore[name]=metric(name,"CountTimeOver10Ms") end
    self:Wrap()
    local frame=self.frame or CreateFrame("Frame"); self.frame=frame
    local last=clock()
    frame:SetScript("OnUpdate",function(_,elapsed)
        local now=clock(); local ms=now-last; last=now
        self.frames=self.frames+1
        if self.frames>2 and ms>SLOW then
            self.hitches[#self.hitches+1]={ms=ms,ft=self.frameFT,top=self.frameTop,at=SECONDS-self.left}
        end
        if self.frames>2 and ms>self.worst then self.worst=ms end
        self.frameFT=0; self.frameTop=nil
        self.left=self.left-elapsed
        if self.left<=0 then frame:SetScript("OnUpdate",nil); self:Stop() end
    end)
    print("|cffffd100ForeverTools:|r recording for "..SECONDS.." seconds. Do what causes the stutter now (for example drag items in your bags). A report opens when it ends.")
end
function Lag:Stop()
    self.running=false
    self:Unwrap()
    FT:DebugBox("Lag report",function() self:Report() end)
end
function Lag:Report()
    print(("ForeverTools lag report (%s) – %d s, %d frames, slowest frame %.0f ms"):format(FT.version or "?",SECONDS,self.frames or 0,self.worst or 0))
    local hitches=self.hitches or {}
    print(("Hitches (frames over %d ms): %d"):format(SLOW,#hitches))
    table.sort(hitches,function(a,b) return a.ms>b.ms end)
    for i=1,math.min(12,#hitches) do
        local h=hitches[i]
        print(("  %5.0f ms at %4.1f s – ForeverTools %4.1f ms%s"):format(h.ms,h.at,h.ft,h.top and (" (most: "..h.top.label..(" %.1f ms)"):format(h.top.ms)) or ""))
    end
    local list={}
    for label,s in pairs(self.stats or {}) do list[#list+1]={label,s} end
    table.sort(list,function(a,b) return a[2].max>b[2].max end)
    print("ForeverTools parts, slowest single call first (calls, total ms, slowest ms):")
    for i=1,math.min(25,#list) do local l=list[i]; print(("  %-44s %5d %8.1f %7.1f"):format(l[1],l[2].n,l[2].ms,l[2].max)) end
    if C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric then
        local rows={}
        for name,before in pairs(self.addonsBefore or {}) do
            local after=metric(name,"CountTimeOver10Ms")
            local peak=metric(name,"PeakTime")
            if after and before and after>before then rows[#rows+1]={name,after-before,peak or 0} end
        end
        table.sort(rows,function(a,b) return a[2]>b[2] end)
        print("Add-ons with frames over 10 ms while recording (game profiler):")
        if #rows==0 then print("  none") end
        for i=1,math.min(10,#rows) do print(("  %-30s %4d times, peak %.0f ms"):format(rows[i][1],rows[i][2],rows[i][3])) end
    else
        print("The game's add-on profiler isn't available here.")
    end
    local on={}
    for name,module in pairs(FT.modules or {}) do
        if type(module.Settings)=="function" then
            local ok,s=pcall(module.Settings,module)
            if ok and type(s)=="table" and s.enabled==true then on[#on+1]=name end
        end
    end
    table.sort(on); print("On: "..table.concat(on,", "))
end
FT:RegisterModule("Lag",Lag)
