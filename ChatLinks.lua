local _,FT=...
-- Clickable web links in chat (off by default). A link opens a copy box;
-- nothing is opened or sent automatically. The game has no URL detection itself.
local Links={urls={},count=0}
local events={"CHAT_MSG_SAY","CHAT_MSG_YELL","CHAT_MSG_WHISPER","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_BN_WHISPER","CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_PARTY","CHAT_MSG_PARTY_LEADER","CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER","CHAT_MSG_RAID_WARNING","CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER","CHAT_MSG_GUILD","CHAT_MSG_OFFICER","CHAT_MSG_CHANNEL","CHAT_MSG_COMMUNITIES_CHANNEL","CHAT_MSG_SYSTEM"}
local patterns={
    "https?://[%w%-%._~:/%?#%[%]@!%$&'%*%+,;=%%]+",
    "www%.[%w%-]+%.[%w%-%._~:/%?#%[%]@!%$&'%*%+,;=%%]+",
}
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
function Links:Enabled() return FT.dbReady and FT.modules.System:Settings().chatLinks==true end
function Links:Store(url)
    -- Keep a bounded list; old lines simply open nothing once rotated out.
    self.count=self.count%200+1
    self.urls[self.count]=url
    return self.count
end
function Links:Decorate(message)
    if not readable(message) or type(message)~="string" or not message:find("[wh][wt][wt]") then return end
    local changed=false
    local function wrap(url)
        -- Keep closing punctuation that belongs to the sentence outside the link.
        local trail=url:match("[%.,;:!%?%)]+$") or ""
        if #trail>0 then url=url:sub(1,#url-#trail) end
        changed=true
        return "|cff7fc8ff|Haddon:ForeverToolsURL:"..self:Store(url).."|h["..url.."]|h|r"..trail
    end
    -- Leave existing hyperlinks (items, players, etc.) untouched.
    local out=" "..message:gsub("(|H.-|h.-|h)",function(link) return "\001"..link:gsub("[%w]","\002%0").."\001" end)
    for _,pattern in ipairs(patterns) do
        out=out:gsub("([%s%(%[])("..pattern..")",function(space,url) return space..wrap(url) end)
    end
    out=out:sub(2):gsub("\001(.-)\001",function(link) return (link:gsub("\002","")) end)
    if changed then return out end
end
local function filter(_,_,message,...)
    if not Links:Enabled() then return false end
    local ok,decorated=pcall(Links.Decorate,Links,message)
    if ok and decorated then return false,decorated,... end
    return false
end
function Links:Open(index)
    local url=self.urls[tonumber(index) or 0]
    if not url then FT:Toast("That link is no longer available."); return end
    FT:CopyBox("Copy link",url,"Press Ctrl+C to copy the link, then paste it into your browser. Escape closes this box.")
end
FT:RegisterModule("ChatLinks",Links)
local register=(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if register then for _,event in ipairs(events) do pcall(register,event,filter) end end
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("SetItemRef",function(_,link)
        if type(link)~="string" then return end
        local index=link:match("^addon:ForeverToolsURL:(%d+)")
        if index then Links:Open(index) end
    end,Links)
end
