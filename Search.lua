local _,FT=...
-- Settings search on the /ft home window: finds pages and individual settings
-- by name or keyword, then opens the page that holds them.
local Search={}
local function profiles() FT:OpenHome(); local p=FT.modules.Profiles; if p and p.panel then p.panel:Show() end end
local index={
    {"Macros","macro builder templates ranks mouseover combo","MacroForge","macros"},
    {"Buff reminders","self buff reminder missing buffs weapon enchant","BuffReminder","buffs"},
    {"Group buff reminders","group party raid dungeon buffs missing","BuffReminder","party"},
    {"Low-rank alerts","rank downrank low rank buffs trainer","BuffReminder","buffs"},
    {"Low-rank marker on action bars","rank downrank marker action bar outdated","BuffReminder","buffs"},
    {"Ignore rank 1","rank one downrank","BuffReminder","buffs"},
    {"FPS counter","fps frames framerate counter performance","QualityOfLife","fps"},
    {"Fonts & colors","appearance look","Appearance","fonts"},
    {"Font manager","font fonts size outline text inter","FontManager","fonts"},
    {"Cooldown numbers","cooldown numbers color grey font","FontManager","fonts"},
    {"Unitframe colors","class colors health bar unit frame player target focus","UnitColors","classes"},
    {"Skins","dark mode darkmode skin border outline action bars buttons buffs debuffs bags micro menu minimap gryphons totem stance xp reputation player target focus frame","IconStyles","skins"},
    {"Chat","chat social tabs side buttons input box","Chat","chat"},
    {"Chat font","chat font size outline","Chat","chat"},
    {"Clickable chat links","url link links copy web address","Chat","chat"},
    {"Tooltip","tooltip target guild health bar position move font","Tooltip","tooltip"},
    {"Tooltip IDs","spell id item id quest achievement ids","Tooltip","spellID"},
    {"Faction-colored guild name","guild color horde alliance faction tooltip","Tooltip","tooltip"},
    {"Custom keybinds","mouse wheel scroll casting mouseover bindings keybind","CustomKeybinds","keybind"},
    {"System","system settings","System","generic"},
    {"Welcome message","welcome login message chat","SystemGeneral","welcome"},
    {"What's new","whats new changelog updates popup","SystemGeneral","welcome"},
    {"First-time setup","setup wizard preset welcome start","SystemGeneral","generic"},
    {"Reset all settings","reset defaults restore clear","SystemGeneral","reset"},
    {"ForeverTools minimap button","minimap icon button","SystemMinimap","map"},
    {"Minimap coordinates","coordinates coords position","SystemMinimap","map"},
    {"Group minimap buttons","minimap icons collect gather addon buttons","SystemMinimap","map"},
    {"Set role when joining a group","role tank healer damage group auto","SystemGameplay","classes"},
    {"Move loot rolls","loot roll need greed position move","SystemGameplay","move"},
    {"Flight timer","flight taxi flying countdown timer","FlightTimer","fps"},
    {"Leveling stats","xp experience per hour time to level kills leveling rested","Leveling","fps"},
    {"Auto-sell grey items","vendor merchant sell junk grey gray","SystemGameplay","generic"},
    {"Auto-repair","vendor merchant repair durability guild funds","SystemGameplay","generic"},
    {"Show Lua errors","lua errors script errors","SystemTroubleshooting","errors"},
    {"Bug report","bug report error copy issue","SystemTroubleshooting","errors"},
    {"Profiles","profile save load export import","\001profiles","profiles"},
    {"Profile for new characters","new character profile alt","\001profiles","profiles"},
    {"Default settings","default reset blizzard fresh start clean profile","\001profiles","reset"},
}
function Search:Results(query)
    query=(query or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if query=="" then return {} end
    local starts,contains={},{}
    for i,entry in ipairs(index) do
        local label=entry[1]:lower()
        local icon="Interface\\Icons\\"..(FT.icons[entry[4]] or entry[4])
        local item={value=i,label=entry[1],icon=icon}
        if label:sub(1,#query)==query then starts[#starts+1]=item
        elseif label:find(query,1,true) or entry[2]:find(query,1,true) then contains[#contains+1]=item end
    end
    for _,item in ipairs(contains) do starts[#starts+1]=item end
    return starts
end
function Search:Open(i)
    local entry=index[i]; if not entry then return end
    self.box:SetText(""); self.box:ClearFocus()
    if entry[3]=="\001profiles" then profiles() else FT:OpenModule(entry[3]) end
end
function Search:Show()
    local menu=FT.choiceMenu
    if menu and menu:IsShown() and menu.owner==self.box then menu:Hide() end
    self.results=self:Results(self.box:GetText())
    if #self.results==0 then
        self.none:SetShown(self.box:GetText()~="")
        return
    end
    self.none:Hide()
    FT:ShowChoices(self.box)
end
function Search:Attach(home)
    if self.box then return end
    local box=CreateFrame("EditBox",nil,home)
    self.box=box
    box:SetSize(220,26); box:SetPoint("TOPLEFT",24,-54)
    box:SetFont(FT.bodyFont,13,""); box:SetAutoFocus(false); box:SetTextInsets(26,8,0,0)
    FT:Panel(box)
    local icon=box:CreateTexture(nil,"ARTWORK"); icon:SetSize(14,14); icon:SetPoint("LEFT",8,0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local placeholder=FT:Label(box,"Search settings",13); placeholder:SetPoint("LEFT",26,0); placeholder:SetTextColor(.6,.55,.7)
    self.none=FT:Label(home,"No matches",12); self.none:SetPoint("LEFT",box,"RIGHT",10,0); self.none:SetTextColor(.66,.57,.77); self.none:Hide()
    box.options=function() return self.results or {} end
    box.onSelect=function(value) self:Open(value) end
    box.menuWidth=300
    box:SetScript("OnTextChanged",function(owner)
        placeholder:SetShown(owner:GetText()=="")
        self:Show()
    end)
    box:SetScript("OnEnterPressed",function() if self.results and self.results[1] then if FT.choiceMenu then FT.choiceMenu:Hide() end; self:Open(self.results[1].value) end end)
    box:SetScript("OnEscapePressed",function(owner) owner:SetText(""); owner:ClearFocus() end)
    home:HookScript("OnHide",function() box:SetText(""); box:ClearFocus() end)
    FT:Tooltip(box,"Search settings","Type a feature or setting, for example \"dark mode\", \"repair\" or \"xp\". Press Enter to open the first result.")
end
FT:RegisterModule("Search",Search)
