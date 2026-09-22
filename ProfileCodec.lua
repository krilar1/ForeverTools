local _,FT=...
-- Length-prefixed data, not Lua source. Import never evaluates executable text.
function FT:EncodeProfile(value)
    local function encode(v,depth)
        assert(depth<20,"Profile too deeply nested")
        local kind=type(v)
        if kind=="nil" then return "z" end
        if kind=="boolean" then return v and "t" or "f" end
        if kind=="number" then assert(v==v and math.abs(v)<1e12); local s=tostring(v); return "n"..#s..":"..s end
        if kind=="string" then return "s"..#v..":"..v end
        assert(kind=="table","Unsupported profile value")
        local keys={}; for k in pairs(v) do assert(type(k)=="string" or type(k)=="number"); keys[#keys+1]=k end
        table.sort(keys,function(a,b) return type(a)==type(b) and a<b or type(a)<type(b) end)
        local out={"m",tostring(#keys),":"}
        for _,k in ipairs(keys) do out[#out+1]=encode(k,depth+1); out[#out+1]=encode(v[k],depth+1) end
        return table.concat(out)
    end
    local raw=encode(value,0)
    return "FT1:"..raw:gsub(".",function(c) return string.format("%02x",c:byte()) end)
end
function FT:DecodeProfile(text)
    if type(text)~="string" or #text>200000 then return nil,"Profile is too large." end
    local encoded=text:gsub("%s",""):match("^FT1:(.*)$")
    if not encoded or #encoded%2~=0 or encoded:find("[^%x]") then return nil,"Invalid ForeverTools profile string." end
    local raw=encoded:gsub("..",function(pair) return string.char(tonumber(pair,16)) end)
    local pos,nodes=1,0
    local function read(depth)
        nodes=nodes+1; assert(nodes<10000 and depth<20,"Profile exceeds limits")
        local tag=raw:sub(pos,pos); pos=pos+1
        if tag=="z" then return nil elseif tag=="t" then return true elseif tag=="f" then return false end
        assert(tag=="n" or tag=="s" or tag=="m","Invalid value")
        local ending=assert(raw:find(":",pos,true)); local digits=raw:sub(pos,ending-1)
        assert(digits:match("^%d+$") and #digits<7,"Invalid length")
        local count=tonumber(digits); pos=ending+1
        if tag=="m" then
            assert(count<5000); local result={}
            for i=1,count do local key=read(depth+1); assert(type(key)=="string" or type(key)=="number"); assert(result[key]==nil,"Duplicate key"); result[key]=read(depth+1) end
            return result
        end
        assert(pos+count-1<=#raw,"Truncated value")
        local value=raw:sub(pos,pos+count-1); pos=pos+count
        if tag=="s" then return value end
        value=tonumber(value); assert(value and value==value and math.abs(value)<1e12,"Invalid number"); return value
    end
    local ok,result=pcall(read,0)
    if not ok or pos~=#raw+1 or type(result)~="table" or result.format~=1 or type(result.settings)~="table" then return nil,"Invalid or unsupported profile." end
    return result
end
