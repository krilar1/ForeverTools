local _,FT=...
-- A copyable bug report. It only reads Blizzard's own error list (no custom
-- error handler, so BugSack and similar addons are unaffected) and never sends
-- anything: the player copies the text and pastes it where they choose.
local Report={}
local function readable(v) return v~=nil and (not issecretvalue or not issecretvalue(v)) end
local function yes(value) return value and "on" or "off" end
function Report:Features()
    local db,out=FT.db,{}
    local function add(label,on) if on then out[#out+1]=label end end
    local skins=db.iconStyles or {}
    local areas={}
    for _,key in ipairs({"actions","buffs","stances","minimap","bags","bagWindows","micro","xp","player","target","tot","focus","focustarget","gryphons"}) do if skins[key] then areas[#areas+1]=key end end
    if #areas>0 then out[#out+1]="skins("..table.concat(areas,",")..")" end
    local fonts={}
    for id,pref in pairs(db.fonts or {}) do if type(pref)=="table" and pref.enabled then fonts[#fonts+1]=id end end
    table.sort(fonts)
    if #fonts>0 then out[#out+1]="fonts("..table.concat(fonts,",")..")" end
    local colors={}
    for key,on in pairs(db.unitColors or {}) do if on==true then colors[#colors+1]=key end end
    table.sort(colors)
    if #colors>0 then out[#out+1]="unitColors("..table.concat(colors,",")..")" end
    local s=db.system or {}
    add("fps",db.fps and db.fps.enabled); add("flightTimer",db.flightTimer and db.flightTimer.enabled)
    add("leveling",db.leveling and db.leveling.enabled)
    add("buffReminders",db.buffReminder and db.buffReminder.enabled); add("groupReminders",db.buffReminder and db.buffReminder.groupEnabled)
    add("lowRankAlerts",db.buffReminder and db.buffReminder.lowRank); add("rankMarker",db.buffReminder and db.buffReminder.rankMarker)
    add("groupMinimapButtons",s.minimapIcons); add("tooltipIDs",s.spellID); add("autoRole",s.autoRole)
    add("autoSell",s.autoSell); add("autoRepair",s.autoRepair); add("chatLinks",s.chatLinks)
    local tip=db.tooltip or {}
    add("tooltipTarget",tip.target); add("tooltipGuild",tip.guild)
    local keybinds=false
    for _,class in pairs(db.customKeybinds or {}) do if type(class)=="table" and class.enabled then keybinds=true end end
    add("wheelCasting",keybinds)
    return #out>0 and table.concat(out,", ") or "none (all defaults)"
end
function Report:Errors(limit)
    local frame=_G.ScriptErrorsFrame
    local out={}
    if not frame or not frame.GetCount or not frame.GetErrorData then return out end
    local ok,count=pcall(frame.GetCount,frame)
    if not ok or type(count)~="number" then return out end
    for index=count,1,-1 do
        local okData,data=pcall(frame.GetErrorData,frame,index)
        if okData and type(data)=="table" and readable(data.message) and type(data.message)=="string" then
            local stack=readable(data.stack) and type(data.stack)=="string" and data.stack or ""
            if (data.message..stack):find(FT.name,1,true) then
                out[#out+1]={message=data.message,stack=stack,count=data.count,time=readable(data.time) and data.time or nil}
                if #out>=(limit or 5) then break end
            end
        end
    end
    return out
end
function Report:Text()
    local version,build,_,interface=GetBuildInfo()
    local _,class=UnitClass("player")
    local lines={
        "ForeverTools bug report",
        "Addon version: "..FT.version,
        "Game build: "..tostring(version).." ("..tostring(build)..", interface "..tostring(interface)..")",
        "Locale: "..tostring(GetLocale and GetLocale() or "?").." · Class: "..tostring(class).." · Level: "..tostring(UnitLevel("player")),
        "Enabled features: "..self:Features(),
        "Lua error display: "..yes(((C_CVar and C_CVar.GetCVar) or GetCVar)("scriptErrors")=="1"),
        "",
        "What happened: (describe it here after pasting)",
        "",
    }
    local errors=self:Errors(5)
    if #errors==0 then
        lines[#lines+1]="Recent ForeverTools errors: none recorded this session."
    else
        lines[#lines+1]="Recent ForeverTools errors (newest first):"
        for i,err in ipairs(errors) do
            lines[#lines+1]=""
            lines[#lines+1]=i..". "..err.message..((err.count and err.count>1) and ("  (x"..err.count..")") or "")..(err.time and ("  ["..err.time.."]") or "")
            local stack={}
            for line in err.stack:gmatch("[^\n]+") do
                stack[#stack+1]="   "..line
                if #stack>=6 then break end
            end
            for _,line in ipairs(stack) do lines[#lines+1]=line end
        end
    end
    return table.concat(lines,"\n")
end
function Report:Open()
    FT:CopyBox("Bug report",self:Text(),"Press Ctrl+C to copy, then paste it in a comment on CurseForge or an issue on GitHub (github.com/krilar1/ForeverTools). Add what you were doing. Nothing is sent automatically.",true)
end
FT:RegisterModule("BugReport",Report)
