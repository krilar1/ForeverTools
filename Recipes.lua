local _,FT=...
-- Recipe export for the guild website (/ft recipes). Each time you open a
-- profession window, the recipes you have learned there are kept for this
-- character (account data, never in profiles). /ft recipes then shows one
-- line to copy, also with the window closed:
--   FTRC1|Name|Profession:skill:id,id,...;Profession:skill:n=Recipe name,...
-- id = the item the recipe makes; recipes that make no item (enchants) are
-- n= and their name. Cooking and First Aid are left out. Forever's
-- profession window is C_TradeSkillUI (Enchanting included).
local R={}
local SKIP={["Cooking"]=true,["First Aid"]=true}
local SKIP_IDS={[185]=true,[129]=true} -- Cooking, First Aid skill lines
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end
local function text(v) if plain(v) and type(v)=="string" and v~="" then return v end end
local function number(v) if plain(v) and type(v)=="number" then return v end end
-- The export's separators never appear inside a name.
local function clean(s) return (tostring(s):gsub("[|;:,]",""):gsub("%s+"," "):match("^%s*(.-)%s*$")) end
R.Clean=clean
local function call(fn,...) if type(fn)~="function" then return nil end local ok,a=pcall(fn,...); if ok then return a end end
function R:Store()
    if type(FT.db.recipes)~="table" then FT.db.recipes={} end
    return FT.db.recipes
end
function R:Me()
    local guid=UnitGUID and text(call(UnitGUID,"player"))
    return guid
end
function R:Mine()
    local guid=self:Me(); if not guid then return nil end
    local c=self:Store()[guid]
    if type(c)~="table" or type(c.profs)~="table" then return nil end
    return c
end
-- The profession open right now: its English name, skill and id.
function R:OpenProfession()
    local T=C_TradeSkillUI; if not T then return end
    -- Someone else's list (a link, the guild list, an NPC crafter) is not yours.
    for _,check in ipairs({"IsTradeSkillLinked","IsTradeSkillGuild","IsNPCCrafting"}) do
        if call(T[check])==true then return end
    end
    local info=call(T.GetChildProfessionInfo)
    local base=call(T.GetBaseProfessionInfo)
    if not (plain(info) and type(info)=="table") then info=base end
    if not (plain(info) and type(info)=="table") then return end
    if not (plain(base) and type(base)=="table") then base=nil end
    local name=text(info.parentProfessionName) or text(info.professionName) or (base and text(base.professionName))
    if not name then return end
    local skill=number(info.skillLevel) or (base and number(base.skillLevel)) or 0
    local id=number(info.professionID)
    local parent=number(info.parentProfessionID) or (base and number(base.professionID))
    return clean(name),math.floor(skill),id,parent
end
-- What a recipe makes: an item id, or nil (enchants and the like).
local function outputItem(T,recipeID,info)
    local s=call(T.GetRecipeSchematic,recipeID,false)
    if plain(s) and type(s)=="table" then local id=number(s.outputItemID); if id and id>0 then return id end end
    local out=call(T.GetRecipeOutputItemData,recipeID)
    if plain(out) and type(out)=="table" then local id=number(out.itemID); if id and id>0 then return id end end
    local q=info and info.qualityItemIDs
    if plain(q) and type(q)=="table" then local id=number(q[1]); if id and id>0 then return id end end
    local link=info and text(info.hyperlink)
    local id=link and link:match("|Hitem:(%d+)")
    return id and tonumber(id) or nil
end
-- Read the learned recipes of the open profession window and keep them.
function R:Scan()
    local T=C_TradeSkillUI; if not T or not FT.dbReady then return end
    local name,skill,id,parent=self:OpenProfession(); if not name then return end
    if SKIP[name] or SKIP_IDS[id or 0] or SKIP_IDS[parent or 0] then return end
    local ids=call(T.GetAllRecipeIDs) or call(T.GetFilteredRecipeIDs)
    if not (plain(ids) and type(ids)=="table") then return end
    local items,names,seenItem,seenName={},{},{},{}
    for _,recipeID in ipairs(ids) do
        local info=plain(recipeID) and call(T.GetRecipeInfo,recipeID)
        if plain(info) and type(info)=="table" and info.learned==true and info.isRecraft~=true then
            local item=outputItem(T,recipeID,info)
            if item then if not seenItem[item] then seenItem[item]=true; items[#items+1]=item end
            else
                local n=text(info.name); n=n and clean(n)
                if n and n~="" and not seenName[n] then seenName[n]=true; names[#names+1]=n end
            end
        end
    end
    local guid=self:Me(); if not guid then return end
    local st=self:Store()
    local c=st[guid]; if type(c)~="table" then c={}; st[guid]=c end
    if type(c.profs)~="table" then c.profs={} end
    c.name=clean((text(call(UnitName,"player")) or c.name or "?"):gsub("%-.*",""))
    -- The list can be empty for a moment while the window loads: an empty
    -- read never replaces recipes read before.
    local old=c.profs[name]
    if #items+#names==0 and type(old)=="table" then old.skill=skill; return end
    table.sort(items); table.sort(names)
    c.profs[name]={skill=skill,items=items,names=names,at=time and time() or 0}
    self.lastScan=name
    self:AfterScan(name)
end
-- The line for the website, and the summary above it.
function R:Export()
    local c=self:Mine(); if not c then return nil end
    local list={}
    for prof,p in pairs(c.profs) do if type(p)=="table" and not SKIP[prof] then list[#list+1]=prof end end
    if #list==0 then return nil end
    table.sort(list)
    local parts,summary={},{}
    for _,prof in ipairs(list) do
        local p=c.profs[prof]
        local entries={}
        for _,id in ipairs(p.items or {}) do entries[#entries+1]=tostring(id) end
        for _,n in ipairs(p.names or {}) do entries[#entries+1]="n="..clean(n) end
        parts[#parts+1]=clean(prof)..":"..math.floor(tonumber(p.skill) or 0)..":"..table.concat(entries,",")
        summary[#summary+1]=prof.." "..math.floor(tonumber(p.skill) or 0).." – "..#entries.." recipe"..(#entries==1 and "" or "s")
    end
    local name=clean(text(call(UnitName,"player")) or c.name or "?"):gsub("%-.*","")
    return "FTRC1|"..name.."|"..table.concat(parts,";"),table.concat(summary," · ")
end
-- Your crafting professions: {name, spell to open it, icon, skill}.
-- Gathering (no recipe list), Cooking and First Aid are left out. Mining's
-- recipe list opens with Smelting.
local GATHER={Herbalism=true,Skinning=true,Fishing=true,Archaeology=true}
local OPEN_WITH={Mining="Smelting"}
function R:Professions()
    local list,seen={},{}
    local function add(name,icon,skill)
        name=text(name); if not name or seen[name] or SKIP[name] or GATHER[name] then return end
        seen[name]=true
        list[#list+1]={name=name,spell=OPEN_WITH[name] or name,icon=icon or 134400,skill=number(skill) or 0}
    end
    if type(GetProfessions)=="function" and type(GetProfessionInfo)=="function" then
        local ok,a,b,c,d,e=pcall(GetProfessions)
        if ok then for _,index in ipairs({a,b,c,d,e}) do
            if plain(index) and type(index)=="number" then
                local okI,name,icon,skill=pcall(GetProfessionInfo,index)
                if okI then add(name,icon,skill) end
            end
        end end
    end
    if #list==0 and type(GetNumSkillLines)=="function" and type(GetSkillLineInfo)=="function" then
        -- Older skill list: the lines under the "Professions" header.
        local ok,n=pcall(GetNumSkillLines); local inside=false
        for i=1,(ok and number(n) or 0) do
            local okL,name,header,_,skill=pcall(GetSkillLineInfo,i)
            if okL then
                if header then inside=(name=="Professions" or name==(TRADE_SKILLS or "Professions"))
                elseif inside then add(name,nil,skill) end
            end
        end
    end
    -- Professions read before still show (a list the game hides for a moment).
    local c=self:Mine()
    if c then for prof,p in pairs(c.profs) do if type(p)=="table" then add(prof,nil,p.skill) end end end
    table.sort(list,function(x,y) return x.name<y.name end)
    return list
end
local function ago(at)
    at=tonumber(at); if not at or at<=0 or not time then return "" end
    local d=time()-at
    if d<120 then return "just now" elseif d<7200 then return math.floor(d/60).." min ago" elseif d<172800 then return math.floor(d/3600).." h ago" end
    return math.floor(d/86400).." days ago"
end
function R:Refresh()
    local frame=self.frame; if not frame or not frame:IsShown() then return end
    local c=self:Mine()
    local profs=self:Professions()
    for i,row in ipairs(self.rows) do
        local prof=profs[i]
        row:SetShown(prof~=nil)
        if prof then
            local p=c and c.profs[prof.name]
            local n=p and (#(p.items or {})+#(p.names or {})) or 0
            row.prof=prof
            row.label:SetText(prof.name..(prof.skill>0 and (" "..prof.skill) or ""))
            row.state:SetText(p and (n.." recipes, read "..ago(p.at)) or "|cffff6b6bnot read yet|r")
            row.icon:SetTexture(prof.icon)
            if not InCombatLockdown() then
                row.read:SetAttribute("type","spell"); row.read:SetAttribute("spell",prof.spell)
            end
            row.read.label:SetText(p and "Read again" or "Read")
        end
    end
    self.none:SetShown(#profs==0)
    local line,summary=self:Export()
    self.original=line and line:gsub("|","||") or ""
    self.box:SetText(self.original)
    self.copyHint:SetText(line and "Click in the box, press Ctrl+A then Ctrl+C, and paste it on the guild website (Professions > Mine recipes > Importer fra ForeverTools)." or "Read at least one profession first.")
    self.box:SetEnabled(line~=nil)
end
function R:Open()
    if FT:CombatOpenRequest() then return end
    if not self.frame then
        local W,H=560,470
        local frame=FT:Window("ForeverToolsRecipes","Recipes for the guild website",W,H); self.frame=frame
        frame.noSavePrompt=true
        if frame.homeButton then frame.homeButton:Hide() end
        local hint=FT:Label(frame,"Click Read on each profession: its window opens, the recipes are read and it closes again.",12)
        hint:SetPoint("TOPLEFT",24,-60); hint:SetWidth(W-48); hint:SetTextColor(.85,.80,.70)
        self.rows={}
        for i=1,4 do
            local y=-92-(i-1)*42
            local row=CreateFrame("Frame",nil,frame); row:SetSize(W-48,36); row:SetPoint("TOPLEFT",24,y)
            row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",4,0)
            row.label=FT:Label(row,"",14,true); row.label:SetPoint("TOPLEFT",42,-2)
            row.state=FT:Label(row,"",12); row.state:SetPoint("TOPLEFT",42,-20); row.state:SetTextColor(.66,.59,.48)
            -- A secure button: opening a profession is casting its spell,
            -- which only a click may do.
            local read=CreateFrame("Button",nil,row,"SecureActionButtonTemplate")
            read:SetSize(130,30); read:SetPoint("RIGHT",0,0); read:RegisterForClicks("AnyUp","AnyDown")
            FT:Panel(read)
            read.label=FT:Label(read,"Read",13); read.label:SetPoint("CENTER")
            read:HookScript("PreClick",function()
                R.reading=row.prof and row.prof.name; local at=GetTime(); R.openedAt=at
                -- Nothing read after a while: say so instead of a silent window.
                C_Timer.After(8,function()
                    if R.reading and R.openedAt==at then
                        R.reading=nil
                        FT:Toast("Couldn't read the recipes. Type /ft recipesdebug and send the text.",5)
                    end
                end)
            end)
            FT:Tooltip(read,"Read recipes","Opens this profession's window, reads your recipes and closes it again.")
            row.read=read
            self.rows[i]=row
        end
        self.none=FT:Label(frame,"No crafting professions found on this character.",13); self.none:SetPoint("TOPLEFT",24,-100); self.none:Hide()
        self.copyHint=FT:Label(frame,"",12); self.copyHint:SetPoint("TOPLEFT",24,-264); self.copyHint:SetWidth(W-48); self.copyHint:SetTextColor(.85,.80,.70)
        local scroll=CreateFrame("ScrollFrame",nil,frame,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",24,-300); scroll:SetPoint("BOTTOMRIGHT",-42,22)
        local box=CreateFrame("EditBox",nil,scroll)
        box:SetMultiLine(true); box:SetAutoFocus(false); box:SetFont(FT.bodyFont,13,""); box:SetWidth(W-72); box:SetTextInsets(4,4,4,4)
        if box.SetMaxLetters then box:SetMaxLetters(0) end
        box:SetScript("OnEscapePressed",function() frame:Hide() end)
        box:SetScript("OnTextChanged",function(owner,user) if user then owner:SetText(R.original or ""); owner:HighlightText() end end)
        box:SetScript("OnEditFocusGained",function(owner) owner:HighlightText() end)
        FT:Panel(scroll)
        scroll:SetScrollChild(box); self.box=box
    end
    self.frame:Show(); self:Refresh()
end
-- A profession window we opened from Read closes again once it is read.
function R:AfterScan(name)
    if self.frame and self.frame:IsShown() then self:Refresh() end
    if self.reading and name and self.reading==name and GetTime()-(self.openedAt or 0)<20 then
        self.reading=nil
        local T=C_TradeSkillUI
        C_Timer.After(.3,function()
            if T and T.CloseTradeSkill then pcall(T.CloseTradeSkill) end
            local pf=_G.ProfessionsFrame or _G.TradeSkillFrame
            if pf and pf.IsShown and pf:IsShown() and not InCombatLockdown() then pcall(HideUIPanel,pf) end
            FT:Toast(name.." recipes read",2)
        end)
    end
end
local events=CreateFrame("Frame")
for _,event in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED"}) do pcall(events.RegisterEvent,events,event) end
local function scan() R:Scan() end
events:SetScript("OnEvent",function() if FT.dbReady then FT:Coalesce("ftRecipes",scan,.5) end end)
-- /ft recipesdebug: what was read, for bug reports (open a profession window first).
function R:Debug()
    local T=C_TradeSkillUI
    print("Profession window API: "..(T and "found" or "missing")..", all recipes: "..tostring(T and T.GetAllRecipeIDs~=nil)..", filtered: "..tostring(T and T.GetFilteredRecipeIDs~=nil))
    local name,skill,id,parent=self:OpenProfession()
    print("Open now: "..tostring(name).." "..tostring(skill).." (id "..tostring(id)..", parent "..tostring(parent)..")")
    local c=self:Mine()
    if not c then print("Nothing read yet for this character.") return end
    for prof,p in pairs(c.profs) do print("  "..prof.." "..tostring(p.skill)..": "..#(p.items or {}).." items, "..#(p.names or {}).." by name") end
end
FT.Recipes=R
