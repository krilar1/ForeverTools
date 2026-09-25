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
}
local outlines = { {value="original", label="Original outline"}, {value="", label="No outline"},
    {value="THIN", label="Thin outline"}, {value="OUTLINE", label="Outline"}, {value="THICKOUTLINE", label="Thick outline"} }

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
        if file:match("^[%w _%-%.]+%.[tT][tT][fF]$") or file:match("^[%w _%-%.]+%.[oO][tT][fF]$") then return media..file,file end
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
    if s.pathFor == s.font then return s.path, s.font:gsub("^shared:", "") end
end
function Fonts:ValidFont(path)
    if type(path) ~= "string" or path == "" then return false end
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
Fonts:RegisterArea("general","General","Choose a font to apply across all areas. Each area retains its own size and outline. To add a font, place a licensed .ttf or .otf file in ForeverTools/Media/Fonts, fully restart WoW, then enter its filename below. WoW cannot discover arbitrary files by itself. SharedMedia fonts are also listed when their provider is installed.",function() end)
local bars = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "PetActionButton", "StanceButton", "PossessButton"}
Fonts:RegisterArea("actions", "Action bars", "Key bindings, stack counts and macro labels on Blizzard action bars.", function(list)
    for _, prefix in ipairs(bars) do for i=1,12 do
        local name = prefix .. i; local button = _G[name]
        for _, field in ipairs({"HotKey", "Count", "Name"}) do
            add(list, _G[name .. field]); if button then add(list, button[field]) end
        end
    end end
end)
Fonts:RegisterArea("cooldowns", "Cooldown numbers", "Blizzard action-button cooldown numbers, when enabled in the game settings. Other cooldown addons manage their own fonts.", function(list)
    for _, prefix in ipairs(bars) do for i=1,12 do
        local button = _G[prefix .. i]
        local cooldown = button and (button.cooldown or button.Cooldown) or _G[prefix .. i .. "Cooldown"]
        if cooldown and cooldown.GetRegions then for _, region in ipairs({cooldown:GetRegions()}) do add(list, region) end end
    end end
end)
Fonts:RegisterArea("units", "Unitframe text", "Names and health/power values on Blizzard player, target, focus, pet and party frames. Custom unit-frame addons manage their own text.", function(list)
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
Fonts:RegisterArea("hits", "Unitframe hits", "Damage and healing flashes on player/pet portraits, where supported by this client. Separate from health/power values.", function(list)
    named(list, "PlayerHitIndicator PetHitIndicator TargetHitIndicator")
    for _, frame in ipairs({PlayerFrame or false, PetFrame or false, TargetFrame or false}) do
        if frame then add(list, frame.hitIndicator); add(list, frame.HitIndicator) end
    end
end)
Fonts:RegisterArea("incoming", "Scrolling combat text", "Blizzard scrolling text around your character. Damage and healing share a font. Enable the text itself in the game settings. Some clients control its size themselves.", function(list)
    named(list, "CombatTextFont")
    for i=1,30 do add(list, _G["CombatText" .. i]) end
end)
Fonts:RegisterArea("world", "World damage/healing", "Native numbers above characters. Changes the client's shared damage font; damage and healing cannot be styled separately here. Log out and back in after changing it. Some client builds ignore this setting.", nil, "DAMAGE_TEXT_FONT")
Fonts:RegisterArea("chat", "Chat", "Text inside Blizzard chat windows. Keeps their existing colors and spacing.", function(list)
    for i=1,(NUM_CHAT_WINDOWS or 10) do add(list, _G["ChatFrame" .. i]) end
end)
Fonts:RegisterArea("tooltip", "Tooltips", "Blizzard tooltip headings and body text, including item and spell tooltips.", function(list)
    named(list, "GameTooltipHeaderText GameTooltipText GameTooltipTextSmall")
    for _, prefix in ipairs({"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2"}) do
        for i=1,30 do add(list, _G[prefix .. "TextLeft" .. i]); add(list, _G[prefix .. "TextRight" .. i]) end
    end
end)
Fonts:RegisterArea("quests", "Quest text", "Blizzard quest headings and reading text. Original size preserves the difference between headings and paragraphs.", function(list)
    named(list, "QuestFont QuestFontNormal QuestFontHighlight QuestFont_Shadow_Small QuestFont_Large QuestFont_Huge QuestTitleFont QuestTitleFontBlack QuestFontNormalSmall QuestFontHighlightSmall")
end)

-- Collect only the documented third-party/built-in frame trees.
local function collectTree(list,frame,depth)
    if not frame then return end
    add(list,frame)
    if frame.GetRegions then for _,region in ipairs({frame:GetRegions()}) do add(list,region) end end
    if depth>0 and frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do collectTree(list,child,depth-1) end end
end
Fonts:RegisterArea("restedxp","RestedXP","Guide steps, headings, arrow and active-item/target text. Applies to RestedXP when installed, including newly created guide rows.",function(list)
    for _,name in ipairs({"RXPFrame","RXPV2GuideWindow","RXPG_ARROW","RXPItemFrame","RXPTargetFrame"}) do collectTree(list,_G[name],7) end
end)
for _,entry in ipairs({{"swingMain","Main-hand swing","SwingTimerMainHandFrame"},{"swingOff","Off-hand swing","SwingTimerOffHandFrame"},{"swingRanged","Ranged swing","SwingTimerRangedFrame"}}) do
    local frameName=entry[3]
    Fonts:RegisterArea(entry[1],entry[2],"Weapon name and countdown on Forever's built-in swing timer. Enable the timer in WoW settings to see it in game.",function(list)
        local frame=_G[frameName]; local bar=frame and frame.StatusBar
        if bar then add(list,bar.TypeLabel); add(list,bar.TimeLabel) end
    end)
end

Fonts:RegisterArea("objectives","Quest objectives","Quest tracker headings and objective text. Size and outline apply to loaded and newly created tracker rows.",function(list)
    collectTree(list,ObjectiveTrackerFrame,8)
    collectTree(list,QuestObjectiveTracker,8)
    collectTree(list,QuestWatchFrame,5)
end)
function Fonts:Flags(value,original)
    return value=="THIN" and "" or value=="original" and (original or "") or value
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
    if outline=="THIN" then object:SetShadowOffset(.5,-.5); object:SetShadowColor(0,0,0,.85)
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
    for object in pairs(objects) do
        local original = cache[object]
        if original then
            local applied, result = pcall(object.SetFont, object, path, s.size == 0 and original[2] or s.size, self:Flags(s.outline,original[3]))
            self:ThinShadow(object,s.outline)
            local actual = applied and object:GetFont()
            if applied and actual and actual:lower() == path:lower() then count = count + 1 else self.errors[id] = "The client rejected this font for one or more text areas." end
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
                    if not pref.enabled or not original or InCombatLockdown() then return end
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
function Fonts:Apply()
    if InCombatLockdown() then self.deferred = true; self:Refresh(); return end
    self.deferred = false
    for _, id in ipairs(self.order) do self:ApplyArea(id) end
    self:Refresh()
end
function Fonts:Queue()
    if self.queued then return end
    self.queued = true
    C_Timer.After(0, function() self.queued = false; self:Apply() end)
end
function Fonts:ChooseFont(value)
    local s = self:Settings(self.selected)
    local candidate = {font=value}
    local path = self:Resolve(candidate)
    if not self:ValidFont(path) then
        self.notice = value == "expressway" and "Expressway could not load. Use expressway.ttf or expressway.otf in ForeverTools/Media/Fonts, then fully restart WoW. Both formats are supported." or "This font is unavailable in your client. Choose another font."
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
    self.allButton:SetShown(general); self.allHint:SetShown(general); self.customFont:SetShown(general); self.customFontAdd:SetShown(general)
    local status = not s.enabled and "Off — this area keeps its original font." or
        (area.engine and "Font saved. Log out and back in to test native numbers." or
        ((self.counts[id] or 0) == 0 and "No matching text loaded yet. Applies when it becomes available. Save your setup to a profile." or "Changes apply immediately. Save your setup to a profile."))
    self.status:Hide()
    self.status:SetText(self.notice or (self.deferred and "Saved. Applies after you leave combat.") or self.errors[id] or status)
end
function Fonts:Open()
    self.selected = self.selected or "general"
    if not self.frame then
        self.frame = FT:Window("ForeverToolsFontManager", "ForeverTools | Font manager", 760, 530)
        FT:AppearanceBack(self.frame)
        self.areaButtons = {}
        local areaScroll=CreateFrame("ScrollFrame",nil,self.frame,"UIPanelScrollFrameTemplate")
        areaScroll:SetPoint("TOPLEFT",20,-64); areaScroll:SetSize(198,402)
        local areaList=CreateFrame("Frame",nil,areaScroll); areaList:SetSize(178,#self.order*40); areaScroll:SetScrollChild(areaList)
        for index, id in ipairs(self.order) do
            local key = id
            local button = FT:QuietButton(areaList, self.areas[key].label, 178, 34, "fonts")
            button:SetPoint("TOPLEFT", 0, -(index-1)*40)
            button.label:SetFont(FT.bodyFont,12,"")
            button:SetScript("OnClick", function() self.selected = key; self.notice = nil; self:Refresh() end)
            FT:Tooltip(button, self.areas[key].label, self.areas[key].description)
            self.areaButtons[key] = button
        end
        self.title = FT:Label(self.frame, "", 20, true); self.title:SetPoint("TOPLEFT", 240, -66)
        self.description = FT:Label(self.frame, "", 14); self.description:SetPoint("TOPLEFT", 240, -100); self.description:SetSize(494, 82); self.description:SetJustifyV("TOP")
        self.toggle = FT:QuietButton(self.frame, "", 494, 34, "fonts"); self.toggle:SetPoint("TOPLEFT", 240, -120)
        self.toggle:SetScript("OnClick", function() local s=self:Settings(self.selected); s.enabled=not s.enabled; self.notice=nil; self:Apply() end)
        self.fontChoice = FT:Dropdown(self.frame, 494, function() return self:Catalogue() end, function(value) self:ChooseFont(value) end, "fonts")
        self.fontChoice:SetPoint("TOPLEFT", 240, -170)
        self.sizeChoice = self:Stepper(self.frame, 238, function()
            local list = {{value=0,label="Original size"}}; for i=8,40 do list[#list+1]={value=i,label=i .. " px"} end; return list
        end, function(value) self:Settings(self.selected).size=value; self:Apply() end, "fonts")
        self.sizeChoice:SetPoint("TOPLEFT", 240, -212)
        self.outlineChoice = self:Stepper(self.frame, 244, function() return outlines end, function(value) self:Settings(self.selected).outline=value; self:Apply() end, "fonts")
        self.outlineChoice:SetPoint("TOPLEFT", 490, -212)
        self.previewTitle = FT:Label(self.frame, "Preview", 14, true); self.previewTitle:SetPoint("TOPLEFT",240,-262)
        self.preview = FT:Label(self.frame, "The quick brown fox jumps over the lazy dog.", 22); self.preview:SetPoint("TOPLEFT", 240, -286); self.preview:SetSize(494, 80)
        local all=FT:QuietButton(self.frame,"Apply selected font to all",494,32,"fonts")
        all:SetPoint("TOPLEFT",240,-406)
        self.allButton=all
        all:SetScript("OnClick",function() local font=self:Settings(self.selected).font; FT:Confirm("Apply the selected font to every area? This enables font management for all areas; sizes and outlines stay unchanged.",function() self:ApplyAllFonts(font) end) end)
        FT:Tooltip(all,"Apply font to all areas","Applies the selected font to every area. Adjust size and outline individually in each menu. Native world numbers may require logging out and back in.")
        local allHint=FT:Label(self.frame,"Adjust sizes and outlines separately in each area.",12)
        self.allHint=allHint
        allHint:SetPoint("TOPLEFT",240,-446)
        self.customFont=CreateFrame("EditBox",nil,self.frame,"InputBoxTemplate"); self.customFont:SetSize(350,28); self.customFont:SetPoint("TOPLEFT",246,-212); self.customFont:SetFont(FT.bodyFont,14,""); self.customFont:SetAutoFocus(false)
        self.customFontAdd=FT:QuietButton(self.frame,"Add font",128,28,"add"); self.customFontAdd:SetPoint("LEFT",self.customFont,"RIGHT",12,0)
        self.customFontAdd:SetScript("OnClick",function() local file=self.customFont:GetText(); local path=self:Resolve({font="file:"..file}); if not self:ValidFont(path) then FT:Toast("Font unavailable. Check filename and restart WoW."); return end; FT.db.customFonts=FT.db.customFonts or {}; local found=false; for _,v in ipairs(FT.db.customFonts) do if v==file then found=true end end; if not found then table.insert(FT.db.customFonts,file) end; self:ChooseFont("file:"..file) end)
        FT:Tooltip(self.customFont,"Font filename","For example MyFont.ttf or MyFont.otf. Place it in ForeverTools/Media/Fonts while WoW is closed, then restart. You must have permission to use the font.")
        self.status = FT:Label(self.frame, "", 13); self.status:SetPoint("TOPLEFT", 240, -392); self.status:SetSize(494, 62); self.status:SetJustifyV("TOP")
        local reset = FT:QuietButton(self.frame, "Reset this area", 238, 32, "reset"); reset:SetPoint("BOTTOMLEFT", 240, 30)
        self.resetButton=reset
        reset:SetScript("OnClick", function() local id=self.selected; FT:Confirm("Reset "..self.areas[id].label.." font settings?",function() FT.db.fonts[id]={}; self.notice=nil; self:Apply() end) end)
        local apply = FT:QuietButton(self.frame, "Reapply fonts", 244, 32, "confirm"); apply:SetPoint("LEFT", reset, "RIGHT", 12, 0)
        self.reapplyButton=apply
        apply:SetScript("OnClick", function() self.notice=nil; self:Apply() end)
        local info = FT:Info(self.frame, "Font manager", function()
            return self.areas[self.selected].description .. "\n\n" .. self.status:GetText()
        end)
        info:SetPoint("TOPRIGHT", -24, -66)
        FT:Tooltip(self.toggle, "Enable font changes", "Switch this area on to apply your chosen font. Each area is independent.")
        FT:Tooltip(self.fontChoice, "Current font", "Shows the font currently used by loaded text in this area. Choosing a font enables management for this area. Mixed fonts means the area uses several fonts.")
        local function controlHelp()
            return self.areas[self.selected].engine
                and "World damage/healing size and outline are controlled by WoW's renderer. This addon can change its font file only; size and outline controls are unavailable for this area."
                or "Adjust this area's size and outline. Thin outline uses a subtle half-pixel black shadow; WoW does not expose a thinner native outline. Original preserves native settings."
        end
        for _,control in ipairs({self.sizeChoice,self.outlineChoice}) do
            FT:Tooltip(control,"Font appearance",controlHelp)
            control:EnableMouse(true)
            for _,button in ipairs({control.minus,control.plus}) do
                if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
                FT:Tooltip(button,"Font appearance",controlHelp)
            end
        end
        FT:Tooltip(reset, "Reset area", "Restore the original font settings for this area.")
        FT:Tooltip(apply, "Reapply fonts", "Apply the saved settings to currently loaded text. Hover the info button for status.")
    end
    self:Apply(); self.frame:Show()
end
FT:RegisterModule("FontManager", Fonts)
local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "UPDATE_CHAT_WINDOWS", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED"}) do events:RegisterEvent(event) end
local ready = false
events:SetScript("OnEvent", function(_, event, loaded)
    if event == "ADDON_LOADED" and loaded == addonName then
        FT:InitializeDB(); ready = true; Fonts:Apply()
    elseif ready then Fonts:Queue() end
end)

-- RestedXP creates rows as guide steps change. A bounded scan discovers these
-- without touching other addons or scanning the entire UI every frame.
local scanElapsed=0
events:SetScript("OnUpdate",function(_,dt)
    scanElapsed=scanElapsed+dt
    if scanElapsed<2 or not FT.dbReady or InCombatLockdown() then return end
    scanElapsed=0
    if RXPFrame or RXPV2GuideWindow then Fonts:ApplyArea("restedxp") end
    if ObjectiveTrackerFrame or QuestObjectiveTracker or QuestWatchFrame then Fonts:ApplyArea("objectives") end
end)

-- Chat's own Font Size menu is an explicit user change. Adopt it instead of
-- fighting it on the next global font refresh.
local chatHook=CreateFrame("Frame"); chatHook:RegisterEvent("PLAYER_LOGIN")
chatHook:SetScript("OnEvent",function()
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
