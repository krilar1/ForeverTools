local _,FT=...
-- New version notice (System > General, on at first). Addons can't go
-- online, so ForeverTools copies tell each other their version with a
-- hidden addon message: to your guild a little after login, and to your
-- party, raid or battleground group when you join one. When someone has a
-- newer version, you get one chat line and a short notice per session (and
-- once more at the next login, until you update). Only the version number
-- is sent; nothing else about you or your settings.
local V={}
local PREFIX="FTVER"
local GAP=120 -- seconds between two sends on the same channel
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
-- "1.2.0" -> 1, 2, 0 (missing parts are 0). Nil for anything else.
local function parse(text)
    if type(text)~="string" or not text:match("^%d+[%.%d]*$") or #text>15 then return nil end
    local parts={}
    for n in text:gmatch("%d+") do parts[#parts+1]=tonumber(n) end
    return parts
end
-- Is version a newer than version b?
local function newer(a,b)
    local x,y=parse(a),parse(b)
    if not x or not y then return false end
    for i=1,math.max(#x,#y) do
        local p,q=x[i] or 0,y[i] or 0
        if p~=q then return p>q end
    end
    return false
end
V.Newer=newer
function V:On()
    local s=FT.db and type(FT.db.system)=="table" and FT.db.system
    return not s or s.versionCheck~=false
end
function V:Send(channel)
    if not self:On() or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local t=GetTime()
    self.sent=self.sent or {}
    if self.sent[channel] and t-self.sent[channel]<GAP then return end
    self.sent[channel]=t
    if not self.prefixed and C_ChatInfo.RegisterAddonMessagePrefix then self.prefixed=true; pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
    pcall(C_ChatInfo.SendAddonMessage,PREFIX,"V|"..FT.version,channel)
end
-- Your group's channel right now, if any.
local function groupChannel()
    local function yes(fn,...) if not fn then return false end local ok,v=pcall(fn,...); return ok and plain(v) and v==true end
    if LE_PARTY_CATEGORY_INSTANCE and yes(IsInGroup,LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if yes(IsInRaid) then return "RAID" end
    if yes(IsInGroup) then return "PARTY" end
end
function V:Tell(version)
    if not self:On() or not newer(version,FT.version) then return end
    FT.db.newestSeen=version
    if self.told and not newer(version,self.told) then return end
    self.told=version
    local text="ForeverTools "..version.." is out (you have "..FT.version.."). Update it on CurseForge."
    print("|cffffd100ForeverTools:|r "..text)
    if FT.Toast then FT:Toast(text,6) end
end
function V:Heard(message,channel)
    if not plain(message) or type(message)~="string" then return end
    local version=message:match("^V|(.+)$")
    if not version or not parse(version) then return end
    self:Tell(version)
    -- They have an older one: answer on the same channel (at most every
    -- two minutes), so they hear about yours.
    if plain(channel) and (channel=="GUILD" or channel=="PARTY" or channel=="RAID" or channel=="INSTANCE_CHAT") and newer(FT.version,version) then self:Send(channel) end
end
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN"); events:RegisterEvent("CHAT_MSG_ADDON"); events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:SetScript("OnEvent",function(_,event,prefix,message,channel)
    if not FT.dbReady then return end
    if event=="CHAT_MSG_ADDON" then
        if plain(prefix) and prefix==PREFIX then V:Heard(message,channel) end
    elseif event=="PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then V.prefixed=true; pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX) end
        -- Updated since a newer version was seen: forget it.
        local seen=FT.db.newestSeen
        if type(seen)=="string" and not newer(seen,FT.version) then FT.db.newestSeen=nil end
        C_Timer.After(15,function()
            if type(FT.db.newestSeen)=="string" then V:Tell(FT.db.newestSeen) end
            if IsInGuild and IsInGuild() then V:Send("GUILD") end
            local ch=groupChannel(); if ch then V:Send(ch) end
        end)
    elseif event=="GROUP_ROSTER_UPDATE" then
        -- Joining fires this many times; one send once the group settles.
        FT:Coalesce("ftVersionGroup",function() local ch=groupChannel(); if ch then V:Send(ch) end end,5)
    end
end)
FT.VersionCheck=V
