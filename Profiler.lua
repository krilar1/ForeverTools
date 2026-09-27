local _,FT=...
-- /ft cpu: an opt-in timing check. While on, every ForeverTools module
-- function is timed; typing /ft cpu again prints the ten that used the most
-- time and puts everything back as it was. Nothing is timed while it is off.
local Profiler={}
local stack,depth={},0
local function say(text) local f=DEFAULT_CHAT_FRAME or ChatFrame1; if f then f:AddMessage("|cffc9a0ffForeverTools cpu:|r "..text) end end
function Profiler:Start()
    if not debugprofilestop then say("timing is not available in this game version."); return end
    self.stats,self.originals,self.started={}, {}, debugprofilestop()
    depth=0
    for moduleName,module in pairs(FT.modules) do
        if module~=self and type(module)=="table" then
            for key,fn in pairs(module) do
                if type(fn)=="function" then
                    local label=moduleName..":"..key
                    local stat={ms=0,self=0,calls=0}; self.stats[label]=stat
                    -- Time inside nested ForeverTools calls is counted for the
                    -- outer function too, but "own" time only once.
                    local function finish(start,...)
                        local elapsed=debugprofilestop()-start
                        local inner=stack[depth] or 0; stack[depth]=0; depth=math.max(0,depth-1)
                        stat.ms=stat.ms+elapsed; stat.self=stat.self+(elapsed-inner); stat.calls=stat.calls+1
                        if depth>0 then stack[depth]=(stack[depth] or 0)+elapsed end
                        return ...
                    end
                    local wrapper=function(...) depth=depth+1; stack[depth]=0; return finish(debugprofilestop(),fn(...)) end
                    self.originals[#self.originals+1]={module,key,fn,wrapper}
                    module[key]=wrapper
                end
            end
        end
    end
    self.on=true
    say("on. Play normally (fight a few mobs), then type /ft cpu again for the results.")
end
function Profiler:Stop()
    for _,entry in ipairs(self.originals or {}) do
        local module,key,fn,wrapper=entry[1],entry[2],entry[3],entry[4]
        if module[key]==wrapper then module[key]=fn end
    end
    self.on=false
    local list,total={},0
    for label,stat in pairs(self.stats or {}) do if stat.calls>0 then list[#list+1]={label,stat}; total=total+stat.self end end
    table.sort(list,function(a,b) return a[2].self>b[2].self end)
    local seconds=(debugprofilestop()-(self.started or 0))/1000
    say(string.format("%.0f s measured, ForeverTools used %.1f ms (%.2f ms per second).",seconds,total,seconds>0 and total/seconds or 0))
    for i=1,math.min(10,#list) do
        local label,stat=list[i][1],list[i][2]
        say(string.format("%2d. %s  %.1f ms own (%.1f with inner calls)  %d calls",i,label,stat.self,stat.ms,stat.calls))
    end
    if #list==0 then say("nothing ran.") end
end
function Profiler:Toggle() if self.on then self:Stop() else self:Start() end end
FT:RegisterModule("Profiler",Profiler)
