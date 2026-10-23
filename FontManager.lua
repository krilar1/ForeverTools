local addonName, FT = ...
local Fonts = { areas = {}, order = {}, originals = {}, counts = {}, errors = {} }
local media = "Interface\\AddOns\\" .. addonName .. "\\Media\\Fonts\\"
local stock = {
    { value = "friz", label = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { value = "arial", label = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { value = "morpheus", label = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { value = "skurri", label = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { value = "inter", label = "Inter", path = media .. "Inter-Regular.ttf" },
    { value = "expressway", label = "Expressway", path = media .. "expressway.otf" },
    -- Bundled (SIL Open Font License, see Media/Fonts/README.txt).
    { value = "robotocondensed", label = "Roboto Condensed", path = media .. "RobotoCondensed-Medium.ttf" },
    { value = "barlowcondensed", label = "Barlow Condensed", path = media .. "BarlowCondensed-SemiBold.ttf" },
    { value = "oswald", label = "Oswald", path = media .. "Oswald-Medium.ttf" },
    { value = "rajdhani", label = "Rajdhani", path = media .. "Rajdhani-SemiBold.ttf" },
    { value = "teko", label = "Teko", path = media .. "Teko-Medium.ttf" },
    { value = "firasanscondensed", label = "Fira Sans Condensed", path = media .. "FiraSansCondensed-Medium.ttf" },
    { value = "notosans", label = "Noto Sans", path = media .. "NotoSans-Medium.ttf" },
    { value = "ptsansnarrow", label = "PT Sans Narrow", path = media .. "PTSansNarrow-Bold.ttf" },
}
-- More fonts the game itself ships with (for other languages; all have
-- Latin letters). Listed only when this client has the file.
local gameExtra = {
    { value = "game:2002", label = "2002", path = "Fonts\\2002.TTF" },
    { value = "game:2002b", label = "2002 Bold", path = "Fonts\\2002B.TTF" },
    { value = "game:arhei", label = "AR Hei", path = "Fonts\\ARHei.ttf" },
    { value = "game:arkai", label = "AR Kai", path = "Fonts\\ARKai_T.ttf" },
    { value = "game:kdamage", label = "K Damage", path = "Fonts\\K_Damage.TTF" },
    { value = "game:kpage", label = "K Pagetext", path = "Fonts\\K_Pagetext.TTF" },
    { value = "game:nimrod", label = "Nimrod", path = "Fonts\\NIM_____.ttf" },
    { value = "game:bold", label = "The Bold Font", path = "Fonts\\theboldfont.ttf" },
}
-- WoW draws two outline widths (Outline, Thick). Thin outline (saved as THIN)
-- is the outline without the text's drop shadow, so it reads much lighter.
local outlines = { {value="original", label="Default"}, {value="", label="No outline"},
    {value="THIN", label="Thin outline"}, {value="OUTLINE", label="Outline"}, {value="THICKOUTLINE", label="Thick outline"} }
-- Chat has no outline by default, so "No outline" would be the same as Default.
local function outlineChoices(area)
    if area ~= "chat" then return outlines end
    local list = {}
    for _, entry in ipairs(outlines) do if entry.value ~= "" then list[#list + 1] = entry end end
    return list
end

function Fonts:RegisterArea(id, label, description, collect, engine)
    self.order[#self.order + 1] = id
    self.areas[id] = { label=label, description=description, collect=collect, engine=engine }
end
function Fonts:Settings(id)
    if type(FT.db.fonts) ~= "table" then FT.db.fonts = {} end
    if type(FT.db.fonts[id]) ~= "table" then FT.db.fonts[id] = {} end
    local s = FT.db.fonts[id]
    if s.enabled == nil then s.enabled = false end -- Blizzard fonts until the player enables an area
    if type(s.font) ~= "string" then s.font = id=="chat" and "arial" or (id=="tooltip" or id=="units") and "friz" or "inter" end
    if type(s.size) ~= "number" or s.size ~= s.size then s.size = 0 end
    s.size = s.size == 0 and 0 or math.floor(math.max(8, math.min(40, s.size)))
    if s.outline ~= "" and s.outline ~= "OUTLINE" and s.outline ~= "THICKOUTLINE" and s.outline ~= "THIN" then s.outline = "original" end
    return s
end
function Fonts:Catalogue()
    local list = {}
    for _, entry in ipairs(stock) do list[#list+1] = entry end
    for _, entry in ipairs(gameExtra) do if self:ValidFont(entry.path) then list[#list+1] = entry end end
    local shared = LibStub and LibStub("LibSharedMedia-3.0", true)
    if shared then
        local extra = {}
        for name, path in pairs(shared:HashTable("font") or {}) do
            extra[#extra+1] = {value="shared:" .. name, label=name .. " (SharedMedia)", path=path}
        end
        table.sort(extra, function(a,b) return a.label < b.label end)
        for _, entry in ipairs(extra) do list[#list+1] = entry end
    end
    for _,entry in ipairs(FT.db.customFonts or {}) do
        if type(entry)=="string" then list[#list+1]={value="file:"..entry,label=entry,path=media..entry} end
    end
    return list
end
function Fonts:Resolve(s)
    if type(s.font)=="string" and s.font:sub(1,5)=="file:" then
        local file=s.font:sub(6)
        if file:match("^[%w _%-%.]+%.[tT][tT][fF]$") or file:match("^[%w _%-%.]+%.[oO][tT][fF]$") then
            -- A font file can be removed while it is still chosen. Never hand a
            -- missing file to the game: remember it and fall back instead.
            if self:ValidFont(media..file) then return media..file,file end
            self.missingFiles=self.missingFiles or {}; self.missingFiles[file]=true
            return nil,file.." (missing)"
        end
    end
    if s.font == "expressway" then
        for _, name in ipairs({"expressway.ttf", "expressway.otf", "Expressway.ttf", "Expressway.otf"}) do
            if self:ValidFont(media .. name) then return media .. name, "Expressway" end
        end
        return nil, "Expressway"
    end
    for _, entry in ipairs(self:Catalogue()) do
        if entry.value == s.font then return entry.path, entry.label end
    end
    -- A provider may load after us; remember its selected path for early engine setup.
    if s.pathFor == s.font and self:ValidFont(s.path) then return s.path, (s.font:gsub("^shared:", "")) end
end
function Fonts:ValidFont(path)
    if type(path) ~= "string" or path == "" then return false end
    -- A file added or removed shows up after a /reload (which starts this cache over), so one check per session is enough.
    self.validCache = self.validCache or {}
    if self.validCache[path] ~= nil then return self.validCache[path] end
    local result = self:ProbeFont(path)
    self.validCache[path] = result
    return result
end
function Fonts:ProbeFont(path)
    if not self.probe then self.probe = CreateFont("ForeverToolsFontProbe") end
    -- A FontString can return false even after loading a valid font. Use a Font
    -- object and confirm GetFont; reset first so a failed probe cannot reuse a result.
    self.probe:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    local ok = pcall(self.probe.SetFont, self.probe, path, 14, "")
    if not ok then return false end
    local actual = self.probe:GetFont()
    local function normalize(value) return type(value) == "string" and value:gsub("/", "\\"):lower() end
    return normalize(actual) == normalize(path)
end
local function add(list, object)
    if object and type(object.GetFont) == "function" and type(object.SetFont) == "function" then list[object] = true end
end
local function named(list, names)
    for name in names:gmatch("%S+") do add(list, _G[name]) end
end
Fonts:RegisterArea("general","General","One font for every area; each keeps its own size and outline. Own font: put a .ttf or .otf in ForeverTools/Media/Fonts, /reload, then type its name below.",function() end)
local bars = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton", "PossessButton"}
Fonts:RegisterArea("actions", "Action bars", "Key bindings, stack counts and macro names on action bars.", function(list)
    for _, prefix in ipairs(bars) do for i=1,12 do
        local name = prefix .. i; local button = _G[name]
        for _, field in ipairs({"HotKey", "Count", "Name"}) do
            add(list, _G[name .. field]); if button then add(list, button[field]) end
        end
    end end
    local roleBar = _G.ForeverToolsRoleBar
    if roleBar and roleBar.buttons then for _, b in ipairs(roleBar.buttons) do add(list, b.key) end end
end)
Fonts:RegisterArea("cooldowns", "Cooldown numbers", "Cooldown numbers on action buttons (turn them on in game settings).", function(list)
    for _, prefix in ipairs(bars) do for i=1,12 do
        local button = _G[prefix .. i]
        local cooldown = button and (button.cooldown or button.Cooldown) or _G[prefix .. i .. "Cooldown"]
        if cooldown and cooldown.GetRegions then for _, region in ipairs({cooldown:GetRegions()}) do add(list, region) end end
    end end
end)
Fonts:RegisterArea("units", "Unit frame text", "Names and numbers on unit frames.", function(list)
    for _, prefix in ipairs({"PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "TargetFrameToT", "FocusFrameToT",
        "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4"}) do
        for _, suffix in ipairs({"Name", "HealthBarText", "HealthBarTextLeft", "HealthBarTextRight", "ManaBarText", "ManaBarTextLeft", "ManaBarTextRight"}) do add(list, _G[prefix .. suffix]) end
        local frame = _G[prefix]
        if frame then
            add(list, frame.name)
            local content = frame.PlayerFrameContent or frame.TargetFrameContent
            local main = content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
            if main then
                add(list, main.Name); local health = main.HealthBarsContainer
                if health then add(list, health.HealthBarText); add(list, health.LeftText); add(list, health.RightText) end
            end
            for _, owner in ipairs({frame, main or frame}) do
                for _, key in ipairs({"healthbar", "manabar", "HealthBar", "ManaBar"}) do
                    local bar = owner[key]
                    if bar then for _, field in ipairs({"TextString", "LeftText", "RightText"}) do add(list, bar[field]) end end
                end
            end
        end
    end
end)
Fonts:RegisterArea("hits", "Unit frame hits", "Damage numbers on your player and pet portraits.", function(list)
    named(list, "PlayerHitIndicator PetHitIndicator TargetHitIndicator")
    for _, frame in ipairs({PlayerFrame or false, PetFrame or false, TargetFrame or false}) do
        if frame then add(list, frame.hitIndicator); add(list, frame.HitIndicator) end
    end
end)
Fonts:RegisterArea("incoming", "Scrolling combat text", "Scrolling combat text around you (turn it on in game settings).", function(list)
    named(list, "CombatTextFont")
    for i=1,30 do add(list, _G["CombatText" .. i]) end
end)
Fonts:RegisterArea("world", "World damage/healing", "Damage numbers above characters. Relog after changing.", nil, "DAMAGE_TEXT_FONT")
Fonts:RegisterArea("chat", "Chat", "Text in chat windows.", function(list)
    for i=1,(NUM_CHAT_WINDOWS or 10) do add(list, _G["ChatFrame" .. i]) end
end)
Fonts:RegisterArea("tooltip", "Tooltips", "Tooltip text.", function(list)
    named(list, "GameTooltipHeaderText GameTooltipText GameTooltipTextSmall")
    for _, prefix in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2"}) do
        for i=1,30 do add(list, _G[prefix .. "TextLeft" .. i]); add(list, _G[prefix .. "TextRight" .. i]) end
    end
end)
Fonts:RegisterArea("quests", "Quest text", "Quest titles and text.", function(list)
    named(list, "QuestFont QuestFontNormal QuestFontHighlight QuestFont_Shadow_Small QuestFont_Large QuestFont_Huge QuestTitleFont QuestTitleFontBlack QuestFontNormalSmall QuestFontHighlightSmall")
end)

-- Collect only the documented third-party/built-in frame trees.
local function collectTree(list,frame,depth)
    if not frame then return end
    add(list,frame)
    if frame.GetRegions then for _,region in ipairs({frame:GetRegions()}) do add(list,region) end end
    if depth>0 and frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do collectTree(list,child,depth-1) end end
end
Fonts:RegisterArea("restedxp","RestedXP","The RestedXP guide, when installed.",function(list)
    for _,name in ipairs({"RXPFrame","RXPV2GuideWindow","RXPG_ARROW","RXPItemFrame","RXPTargetFrame"}) do collectTree(list,_G[name],7) end
end)
for _,entry in ipairs({{"swingMain","Main-hand swing","SwingTimerMainHandFrame"},{"swingOff","Off-hand swing","SwingTimerOffHandFrame"},{"swingRanged","Ranged swing","SwingTimerRangedFrame"}}) do
    local frameName=entry[3]
    Fonts:RegisterArea(entry[1],entry[2],"The swing timer's text.",function(list)
        local frame=_G[frameName]; local bar=frame and frame.StatusBar
        if bar then add(list,bar.TypeLabel); add(list,bar.TimeLabel) end
    end)
end

Fonts:RegisterArea("objectives","Quest objectives","Quest tracker titles and objectives.",function(list)
    collectTree(list,ObjectiveTrackerFrame,8)
    collectTree(list,QuestObjectiveTracker,8)
    collectTree(list,QuestWatchFrame,5)
end)
-- The ForeverTools threat meter: title, target and each bar's name and number.
Fonts:RegisterArea("threatMeter","Threat meter","Text on the threat meter.",function(list)
    local threat=FT.modules.Threat; local meter=threat and threat.meter
    if not meter then return end
    add(list,meter.title); add(list,meter.target); add(list,meter.empty)
    for _,row in ipairs(threat.rows or {}) do add(list,row.name); add(list,row.value) end
end)
-- The ForeverTools interrupt bar: each row's name and time.
Fonts:RegisterArea("interrupts","Interrupt bar","Names and times on the interrupt bar.",function(list)
    local bar=FT.modules.Interrupts
    for _,row in ipairs(bar and bar.rows or {}) do add(list,row.name); add(list,row.time) end
end)
-- The game's own damage meter: the name and number on every bar, in each of
-- its windows. Bars are reused as the list scrolls, so new ones are picked up
-- as the game sets them up.
local function damageMeterWindows()
    local list={}
    for i=1,3 do local window=_G["DamageMeterSessionWindow"..i]; if window then list[#list+1]=window end end
    return list
end
local function damageMeterEntry(list,frame)
    local bar=frame and frame.StatusBar
    if bar then add(list,bar.Name); add(list,bar.Value) end
end
Fonts:RegisterArea("damageMeter","Damage meter","Text on the game's damage meter.",function(list)
    for _,window in ipairs(damageMeterWindows()) do
        local container=window.MinimizeContainer
        local box=container and container.ScrollBox
        if box and box.ForEachFrame then pcall(box.ForEachFrame,box,function(frame) damageMeterEntry(list,frame) end) end
        damageMeterEntry(list,container and container.LocalPlayerEntry)
    end
end)
function Fonts:WatchDamageMeter()
    self.meterHooks=self.meterHooks or {}
    local function refresh()
        if not self:Settings("damageMeter").enabled then return end
        FT:Coalesce("damageMeterFonts",function() self:ApplyArea("damageMeter") end,.05)
    end
    for _,window in ipairs(damageMeterWindows()) do
        if not self.meterHooks[window] and window.InitEntry and hooksecurefunc then
            self.meterHooks[window]=true
            hooksecurefunc(window,"InitEntry",refresh)
        end
    end
    -- Extra damage meter windows are made when you open them.
    if not self.meterHooks.owner and DamageMeter and DamageMeter.SetupSessionWindow and hooksecurefunc then
        self.meterHooks.owner=true
        hooksecurefunc(DamageMeter,"SetupSessionWindow",function() self:WatchDamageMeter(); refresh() end)
    end
end
function Fonts:Flags(value,original)
    return value=="THIN" and "OUTLINE" or value=="original" and (original or "") or value
end
function Fonts:ThinShadow(object,outline)
    if not object.SetShadowOffset or not object.SetShadowColor then return end
    self.shadows=self.shadows or {}
    if not self.shadows[object] then
        local x,y=0,0; local r,g,b,a=0,0,0,0
        if object.GetShadowOffset then x,y=object:GetShadowOffset() end
        if object.GetShadowColor then r,g,b,a=object:GetShadowColor() end
        self.shadows[object]={x,y,r,g,b,a}
    end
    local old=self.shadows[object]
    -- Already set this way: nothing to do (this runs for every text on each pass).
    local state=outline=="THIN" and "thin" or "original"
    if old.state==state then return end
    old.state=state
    -- Thin outline: WoW's outline without the drop shadow underneath, which
    -- is what makes the normal outline look heavy.
    if outline=="THIN" then object:SetShadowOffset(0,0); object:SetShadowColor(0,0,0,0)
    else object:SetShadowOffset(old[1],old[2]); object:SetShadowColor(old[3],old[4],old[5],old[6]) end
end
function Fonts:ApplyArea(id)
    if id=="general" then return end
    local area, s = self.areas[id], self:Settings(id)
    local cache = self.originals[id] or {}; self.originals[id] = cache
    self.errors[id] = nil
    if not s.enabled then
        for object, original in pairs(cache) do pcall(object.SetFont, object, unpack(original)); self:ThinShadow(object,"original") end
        self.originals[id] = {}
        if area.engine and self.engineOwned then _G[area.engine] = self.engineOriginal; self.engineOwned = false end
        self.counts[id] = 0
        return
    end
    local path = self:Resolve(s)
    if not self:ValidFont(path) then self.errors[id] = "Font unavailable. Install its file/provider, or choose another font."; return end
    s.path, s.pathFor = path, s.font
    if area.engine then
        if not self.engineOwned then self.engineOriginal = _G[area.engine]; self.engineOwned = true end
        _G[area.engine] = path; self.counts[id] = 1; return
    end
    local objects = {}; area.collect(objects)
    local count = 0
    -- Snapshot all originals before modifying shared Font objects inherited by other strings.
    for object in pairs(objects) do
        local ok, file, size, flags = pcall(object.GetFont, object)
        if ok and file and size then
            if not cache[object] then cache[object] = {file, size, flags or ""} end
        end
    end
    local lowerPath = path:lower()
    for object in pairs(objects) do
        local original = cache[object]
        if original then
            local size, flags = s.size == 0 and original[2] or s.size, self:Flags(s.outline,original[3])
            -- Already showing this font, size and outline: nothing to do.
            local ok, file, currentSize, currentFlags = pcall(object.GetFont, object)
            if ok and type(file) == "string" and file:lower() == lowerPath and currentSize and math.abs(currentSize - size) < 0.01 and (currentFlags or "") == flags then
                self:ThinShadow(object,s.outline)
                count = count + 1
            else
                local applied = pcall(object.SetFont, object, path, size, flags)
                self:ThinShadow(object,s.outline)
                local actual = applied and object:GetFont()
                if applied and actual and actual:lower() == lowerPath then count = count + 1 else self.errors[id] = "The client rejected this font for one or more text areas." end
            end
        end
    end
    if id=="restedxp" or id=="swingMain" or id=="swingOff" or id=="swingRanged" or id=="objectives" then
        self.integrationHooks=self.integrationHooks or {}
        for object in pairs(objects) do
            if not self.integrationHooks[object] and hooksecurefunc then
                self.integrationHooks[object]=true
                hooksecurefunc(object,"SetFont",function(target)
                    if self.reapplying then return end
                    local pref=self:Settings(id); local original=self.originals[id] and self.originals[id][target]
                    if not pref.enabled or not original or FT:LooksWait() then return end
                    local resolved=self:Resolve(pref); if not resolved then return end
                    self.reapplying=true
                    target:SetFont(resolved,pref.size==0 and original[2] or pref.size,self:Flags(pref.outline,original[3]))
                    self.reapplying=false
                end)
            end
        end
    end
    self.counts[id] = count
end
function Fonts:Apply(only)
    if FT:LooksWait() then self.deferred = true; self:RefreshShown(); return end
    if not only then self.deferred = false end
    for _, id in ipairs(self.order) do
        if not only or only[id] then self:ApplyArea(id) end
    end
    self:WarnMissing()
    self:RefreshShown()
end
-- The settings page only needs redrawing while it is open.
function Fonts:RefreshShown()
    if self.frame and self.frame:IsShown() then self:Refresh() end
end
-- Queue(): everything. Queue({actions=true}): only those areas. Requests in
-- the same moment are merged into one pass on the next frame.
function Fonts:Queue(areas)
    if areas and self.queuedAreas ~= "all" then
        self.queuedAreas = self.queuedAreas or {}
        for id in pairs(areas) do self.queuedAreas[id] = true end
    else self.queuedAreas = "all" end
    if self.queued then return end
    self.queued = true
    C_Timer.After(0, function()
        local only = self.queuedAreas; self.queued = false; self.queuedAreas = nil
        self:Apply(only ~= "all" and only or nil)
    end)
end
-- Tell the player once per session which chosen font files are gone and
-- where to put them back. Those areas keep the game's own font meanwhile.
function Fonts:WarnMissing()
    local files = {}
    for file in pairs(self.missingFiles or {}) do if not (self.warned and self.warned[file]) then files[#files + 1] = file end end
    if #files == 0 then return end
    table.sort(files)
    self.warned = self.warned or {}
    for _, file in ipairs(files) do self.warned[file] = true end
    local text = "Font file missing: " .. table.concat(files, ", ") .. ". Put it back in Interface\\AddOns\\ForeverTools\\Media\\Fonts and /reload, or pick another font. The game's font is used until then."
    print("|cffffd100ForeverTools:|r " .. text)
    FT:Toast("A chosen font file is missing. Details are in chat.", 5)
end
function Fonts:ChooseFont(value)
    local s = self:Settings(self.selected)
    local candidate = {font=value}
    local path = self:Resolve(candidate)
    if not self:ValidFont(path) then
        self.notice = value == "expressway" and "Expressway could not load. Put expressway.ttf or .otf in ForeverTools/Media/Fonts, then /reload." or "This font doesn't work here. Pick another."
        self:Refresh(); return
    end
    s.font, s.path, s.pathFor = value, path, value
    s.enabled = true
    self.notice = nil; self:Apply()
end
function Fonts:CurrentFont(id)
    local area = self.areas[id]
    local paths = {}
    if area.engine then
        if type(_G[area.engine]) == "string" then paths[_G[area.engine]] = true end
    else
        local objects = {}; area.collect(objects)
        for object in pairs(objects) do
            local ok, path = pcall(object.GetFont, object)
            if ok and type(path) == "string" then paths[path] = true end
        end
    end
    local count, current = 0, nil
    local unique = {}
    for path in pairs(paths) do
        local key = path:gsub("/", "\\"):lower()
        if not unique[key] then unique[key]=true; count=count+1; current=path end
    end
    if count == 0 then return nil, "Not loaded yet" end
    if count > 1 then return nil, "Mixed fonts" end
    for _, entry in ipairs(self:Catalogue()) do
        if entry.path:lower() == current:lower() then return current, entry.label, entry.value end
    end
    if current:lower():find("expressway",1,true) then return current, "Expressway", "expressway" end
    return current, current:match("([^\\/]+)$") or current
end
function Fonts:Refresh()
    if not self.frame then return end
    local id = self.selected; local area, s = self.areas[id], self:Settings(id)
    for key, button in pairs(self.areaButtons) do FT:SetSelected(button, id == key) end
    self.title:SetText(area.label)
    self.description:SetText(area.description); self.description:Hide()
    self.toggle.label:SetText(s.enabled and "Manage this area: On" or "Manage this area: Off")
    FT:SetSelected(self.toggle, s.enabled)
    local path, label, value = self:CurrentFont(id)
    if id=="general" then path,label=self:Resolve(s); value=s.font end
    if not s.enabled then path,label=self:Resolve(s); value=s.font end
    self.fontChoice.value = value; self.fontChoice.label:SetText(label)
    self.sizeChoice.value = s.size; self.sizeChoice.label:SetText(s.size == 0 and "Original size" or (s.size .. " px"))
    self.outlineChoice.value = s.outline
    for _, entry in ipairs(outlines) do if entry.value == s.outline then self.outlineChoice.label:SetText(entry.label) end end
    self.sizeChoice:SetEnabled(not area.engine); self.outlineChoice:SetEnabled(not area.engine)
    self.sizeChoice:SetAlpha(area.engine and 0.35 or 1); self.outlineChoice:SetAlpha(area.engine and 0.35 or 1)
    self.preview:SetShown(path ~= nil)
    if path then self.preview:SetFont(path, s.size == 0 and 22 or s.size, self:Flags(s.outline,"")) end
    -- A simulation is useful even before the corresponding native UI is loaded.
    self:ThinShadow(self.preview,s.outline)
    self:UpdateScene(path or self:Resolve(s))
    local general=id=="general"
    for _,control in ipairs({self.toggle,self.sizeChoice,self.outlineChoice,self.resetButton,self.reapplyButton}) do control:SetShown(not general) end
    self.allButton:SetShown(general); self.customFont:SetShown(general); self.customFontAdd:SetShown(general)
    local status = not s.enabled and "Off — this area keeps its original font." or
        (area.engine and "Saved. Relog to see it on damage numbers." or
        (Fonts.showsElement and Fonts.showsElement[id] and "Shown on screen while you edit this area." or
        ((self.counts[id] or 0) == 0 and "Not on screen yet. Applies when it appears." or "Changes apply right away.")))
    self.status:Hide()
    self.status:SetText(self.notice or (self.deferred and "Saved. Applies after you leave combat.") or self.errors[id] or status)
    self:ShowElement()
end
-- Areas for ForeverTools' own elements that are often hidden: while you edit
-- the area's font, the element itself is on screen as a preview (with
-- made-up rows), so you see the font where it is used.
local SHOW = {
    threatMeter = {
        on = function() local T = FT.modules.Threat; if T then T.previewing = true; T:Apply() end end,
        off = function() local T = FT.modules.Threat; if T and not (T.frame and T.frame:IsShown()) then T.previewing = false; T:Apply() end end,
    },
    interrupts = {
        on = function() local I = FT.modules.Interrupts; if I and not I.preview then I.fontPreview = true; I:SetPreview(true) end end,
        off = function() local I = FT.modules.Interrupts; if I and I.fontPreview then I.fontPreview = nil; I:SetPreview(false) end end,
    },
}
Fonts.showsElement = SHOW
function Fonts:ShowElement()
    local want = self.frame and self.frame:IsShown() and not InCombatLockdown() and SHOW[self.selected] and self.selected or nil
    if want == self.shownElement then return end
    if self.shownElement then pcall(SHOW[self.shownElement].off) end
    self.shownElement = want
    if want then pcall(SHOW[want].on) end
end
function Fonts:Open()
    self.selected = self.selected or "general"
    if not self.frame then
        self.frame = FT:Window("ForeverToolsFontManager", "Fonts", 620, 530)
        self.frame:HookScript("OnHide", function() self:ShowElement() end)
        FT:AppearanceBack(self.frame)
        self.areaButtons = {}
        local areaScroll=CreateFrame("ScrollFrame",nil,self.frame,"UIPanelScrollFrameTemplate")
        -- Scroll area as wide as its buttons: the scrollbar then sits in the gap
        -- before the settings instead of touching them.
        areaScroll:SetPoint("TOPLEFT",20,-64); areaScroll:SetSize(162,402)
        local areaList=CreateFrame("Frame",nil,areaScroll); areaList:SetSize(158,#self.order*40); areaScroll:SetScrollChild(areaList)
        for index, id in ipairs(self.order) do
            local key = id
            local button = FT:QuietButton(areaList, self.areas[key].label, 158, 34, "fonts")
            button:SetPoint("TOPLEFT", 0, -(index-1)*40)
            button.label:SetFont(FT.bodyFont,12,"")
            button:SetScript("OnClick", function() self.selected = key; self.notice = nil; self:Refresh() end)
            FT:Tooltip(button, self.areas[key].label, self.areas[key].description)
            self.areaButtons[key] = button
        end
        self.title = FT:Label(self.frame, "", 20, true); self.title:SetPoint("TOPLEFT", 204, -66)
        self.description = FT:Label(self.frame, "", 14); self.description:SetPoint("TOPLEFT", 204, -100); self.description:SetSize(392, 82); self.description:SetJustifyV("TOP")
        self.toggle = FT:AccentButton(self.frame, "", 392, 34, "fonts"); self.toggle:SetPoint("TOPLEFT", 204, -120)
        self.toggle:SetScript("OnClick", function() local s=self:Settings(self.selected); s.enabled=not s.enabled; self.notice=nil; self:Apply() end)
        self.fontChoice = FT:Dropdown(self.frame, 392, function() return self:Catalogue() end, function(value) self:ChooseFont(value) end, "fonts")
        self.fontChoice:SetPoint("TOPLEFT", 204, -170)
        self.fontChoice.menuBeside = self.frame
        self.sizeChoice = self:Stepper(self.frame, 190, function()
            local list = {{value=0,label="Original size"}}; for i=8,40 do list[#list+1]={value=i,label=i .. " px"} end; return list
        end, function(value) self:Settings(self.selected).size=value; self:Apply() end, "fonts")
        self.sizeChoice:SetPoint("TOPLEFT", 204, -212)
        self.outlineChoice = self:Stepper(self.frame, 190, function() return outlineChoices(self.selected) end, function(value) self:Settings(self.selected).outline=value; self:Apply() end, "fonts")
        self.outlineChoice:SetPoint("TOPLEFT", 402, -212)
        self.previewTitle = FT:Label(self.frame, "Preview", 14, true); self.previewTitle:SetPoint("TOPLEFT",204,-262); FT:SectionHeading(self.previewTitle, "INV_Inscription_Tradeskill01", 260)
        self.preview = FT:Label(self.frame, "The quick brown fox jumps over the lazy dog.", 22); self.preview:SetPoint("TOPLEFT", 204, -286); self.preview:SetSize(392, 80)
        local all=FT:QuietButton(self.frame,"Apply selected font to all",392,32,"fonts")
        all:SetPoint("TOPLEFT",204,-406)
        self.allButton=all
        all:SetScript("OnClick",function() local font=self:Settings(self.selected).font; FT:Confirm("Use this font in every area? Sizes and outlines stay.",function() self:ApplyAllFonts(font) end) end)
        FT:Tooltip(all,"Apply font to all areas","Use this font everywhere. Sizes and outlines stay.")
        self.customFont=CreateFrame("EditBox",nil,self.frame,"InputBoxTemplate"); self.customFont:SetSize(262,28); self.customFont:SetPoint("TOPLEFT",210,-212); self.customFont:SetFont(FT.bodyFont,14,""); self.customFont:SetAutoFocus(false)
        self.customFontAdd=FT:QuietButton(self.frame,"Add font",112,28,"add"); self.customFontAdd:SetPoint("LEFT",self.customFont,"RIGHT",12,0)
        FT:Tooltip(self.customFontAdd,"Add font","Add the font file named in the box.")
        self.customFontAdd:SetScript("OnClick",function() local file=self.customFont:GetText(); local path=self:Resolve({font="file:"..file}); if not path then FT:Toast("Font not found. Put the file in Interface\\AddOns\\ForeverTools\\Media\\Fonts, then /reload."); return end; FT.db.customFonts=FT.db.customFonts or {}; local found=false; for _,v in ipairs(FT.db.customFonts) do if v==file then found=true end end; if not found then table.insert(FT.db.customFonts,file) end; self:ChooseFont("file:"..file) end)
        FT:Tooltip(self.customFont,"Font filename","File name, like MyFont.ttf, placed in ForeverTools/Media/Fonts. Only fonts you may use.")
        self.status = FT:Label(self.frame, "", 13); self.status:SetPoint("TOPLEFT", 204, -392); self.status:SetSize(392, 62); self.status:SetJustifyV("TOP")
        local reset = FT:QuietButton(self.frame, "Reset this area", 190, 32, "reset"); reset:SetPoint("BOTTOMLEFT", 204, 30)
        self.resetButton=reset
        reset:SetScript("OnClick", function() local id=self.selected; FT:Confirm("Reset "..self.areas[id].label.." font settings?",function() FT.db.fonts[id]={}; self.notice=nil; self:Apply() end) end)
        local apply = FT:QuietButton(self.frame, "Reapply fonts", 190, 32, "confirm"); apply:SetPoint("LEFT", reset, "RIGHT", 8, 0)
        self.reapplyButton=apply
        apply:SetScript("OnClick", function() self.notice=nil; self:Apply() end)
        FT:PageInfo(self.frame, "Fonts", function()
            return "Pick an area on the left, turn it on, then choose its font, size and outline.\n\nThis area: " .. self.areas[self.selected].description .. ((self.status:GetText() or "") ~= "" and ("\n\n" .. self.status:GetText()) or "")
        end)
        FT:Tooltip(self.toggle, "Enable font changes", "Use your font in this area.")
        FT:Tooltip(self.fontChoice, "Current font", "Picking a font also turns the area on.")
        local function controlHelp()
            return self.areas[self.selected].engine
                and "The game sets the size of damage numbers. Only the font can change."
                or "Text size and outline. Original keeps the game's."
        end
        for _,control in ipairs({self.sizeChoice,self.outlineChoice}) do
            FT:Tooltip(control,"Font appearance",controlHelp)
            control:EnableMouse(true)
            for _,button in ipairs({control.minus,control.plus}) do
                if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
                FT:Tooltip(button,"Font appearance",controlHelp)
            end
        end
        FT:Tooltip(reset, "Reset area", "Back to the original font for this area.")
        FT:Tooltip(apply, "Reapply fonts", "Apply your fonts again, if something didn't update.")
    end
    self:Apply(); self.frame:Show(); self:Refresh()
end
FT:RegisterModule("FontManager", Fonts)
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "UPDATE_CHAT_WINDOWS", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED"}) do events:RegisterEvent(event) end
local ready = false
-- Which font areas each event can affect. Events not listed redo everything.
local eventAreas = {
    UPDATE_BINDINGS = {actions = true}, ACTIONBAR_SLOT_CHANGED = {actions = true, cooldowns = true},
    UPDATE_CHAT_WINDOWS = {chat = true},
    GROUP_ROSTER_UPDATE = {units = true}, PLAYER_TARGET_CHANGED = {units = true},
}
events:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" then
        if loaded == addonName then FT:InitializeDB(); ready = true; Fonts:Apply() end
    elseif ready then
        if event == "PLAYER_REGEN_ENABLED" and not Fonts.deferred then return end
        Fonts:Queue(eventAreas[event])
    end
end)

-- RestedXP creates rows as guide steps change. A bounded scan discovers these
-- without touching other addons or scanning the entire UI every frame.
-- The quest tracker is redone when quests change or the tracker resizes (new
-- lines), with a slow check every 10 seconds as a safety net.
local scanElapsed,objectiveElapsed=0,0
local function objectives()
    if not FT.dbReady or FT:LooksWait() then return end
    if (ObjectiveTrackerFrame or QuestObjectiveTracker or QuestWatchFrame) and Fonts:Settings("objectives").enabled then
        objectiveElapsed=0
        FT:Coalesce("objectiveFonts",function() if not FT:LooksWait() then Fonts:ApplyArea("objectives") end end,1)
    end
end
local questEvents=CreateFrame("Frame")
for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_WATCH_LIST_CHANGED","QUEST_ACCEPTED","QUEST_REMOVED","SUPER_TRACKING_CHANGED","PLAYER_ENTERING_WORLD"}) do pcall(questEvents.RegisterEvent,questEvents,event) end
questEvents:SetScript("OnEvent",function()
    for _,frame in ipairs({ObjectiveTrackerFrame or false,QuestObjectiveTracker or false,QuestWatchFrame or false}) do
        if frame and frame.HookScript and not frame.ftFontSizeHook then frame.ftFontSizeHook=true; frame:HookScript("OnSizeChanged",objectives) end
    end
    objectives()
end)
events:SetScript("OnUpdate",function(_,dt)
    scanElapsed=scanElapsed+dt; objectiveElapsed=objectiveElapsed+dt
    if scanElapsed<2 or not FT.dbReady or FT:LooksWait() then return end
    scanElapsed=0
    if (RXPFrame or RXPV2GuideWindow) and Fonts:Settings("restedxp").enabled then Fonts:ApplyArea("restedxp") end
    if objectiveElapsed>=10 then objectives() end
end)

-- Chat's own Font Size menu is an explicit user change. Adopt it instead of
-- fighting it on the next global font refresh.
local chatHook=CreateFrame("Frame"); chatHook:RegisterEvent("PLAYER_LOGIN")
chatHook:SetScript("OnEvent",function()
    Fonts:WatchDamageMeter()
    if Fonts.chatHooked or not FCF_SetChatWindowFontSize or not hooksecurefunc then return end
    Fonts.chatHooked=true
    hooksecurefunc("FCF_SetChatWindowFontSize",function(_,frame,size)
        if not FT.dbReady or type(size)~="number" then return end
        local pref=Fonts:Settings("chat"); pref.size=size
        if frame and frame.GetFont then
            local original=Fonts.originals.chat and Fonts.originals.chat[frame]; if original then original[2]=size end
        end
        if pref.enabled then Fonts:Queue() else Fonts:Refresh() end
    end)
end)
