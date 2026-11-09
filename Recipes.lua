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
function R:Open()
    local line,summary=self:Export()
    if not line then
        FT:CopyBox("Recipes for the guild website","","Open your profession window once so ForeverTools can read your recipes.")
        return
    end
    -- An edit box reads | as the start of a code (|T, |K... would turn the
    -- name into a picture); written as || it shows, and copies, as one |.
    FT:CopyBox("Recipes for the guild website",(line:gsub("|","||")),summary.."\nPress Ctrl+C to copy, then paste it on the guild website (Professions > Mine recipes > Importer fra ForeverTools).",true)
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
