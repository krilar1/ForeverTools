local _,FT=...
local S=FT.modules.IconStyles
-- Your own skin templates: a saved copy of every skin setting (which areas
-- are on, colors, transparency, borders), shared by all characters. Shown in
-- the Skins "Everything" page next to the built-in templates.
local PREFIX="\001tpl:"
local function copy(v) if type(v)~="table" then return v end local t={} for k,x in pairs(v) do t[k]=copy(x) end return t end
function S:Templates()
    if type(FT.db.skinTemplates)~="table" then FT.db.skinTemplates={} end
    return FT.db.skinTemplates
end
function S:TemplateNames()
    local names={}
    for name,t in pairs(self:Templates()) do if type(name)=="string" and type(t)=="table" then names[#names+1]=name end end
    table.sort(names,function(a,b) return a:lower()<b:lower() end)
    return names
end
local function userName(value) return type(value)=="string" and value:sub(1,#PREFIX)==PREFIX and value:sub(#PREFIX+1) or nil end
local function cleanName(text) return type(text)=="string" and text:match("^%s*(.-)%s*$") or "" end
function S:SaveTemplate(name)
    self:Templates()[name]=copy(self:Settings())
    self.allPreset=PREFIX..name
    self:Refresh(); FT:Toast('Template "'..name..'" saved.',3)
end
function S:ApplyTemplate(name)
    local t=self:Templates()[name]; if type(t)~="table" then return end
    FT.db.iconStyles=copy(t)
    self:Settings(); self:Apply()
    FT:Toast('Template "'..name..'" applied.',3)
end
-- A small name box (the game's own pop-up with a text field).
function S:AskTemplateName(title,start,onName)
    StaticPopupDialogs.FOREVERTOOLS_SKIN_NAME={
        text=title,button1="OK",button2="Cancel",hasEditBox=true,maxLetters=40,
        timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnShow=function(popup) local box=popup.editBox or (popup.GetEditBox and popup:GetEditBox()); if box then box:SetText(start or ""); box:HighlightText() end end,
        OnAccept=function(popup) local box=popup.editBox or (popup.GetEditBox and popup:GetEditBox()); onName(cleanName(box and box:GetText())) end,
        EditBoxOnEnterPressed=function(box) local popup=box:GetParent(); onName(cleanName(box:GetText())); popup:Hide() end,
        EditBoxOnEscapePressed=function(box) box:GetParent():Hide() end,
    }
    FT:ShowPopup("FOREVERTOOLS_SKIN_NAME")
end
local function validName(self,name,except)
    if name=="" or #name>40 then FT:Toast("Enter a name (1–40 characters)."); return false end
    if name~=except and self:Templates()[name] then FT:Toast("A template with that name already exists."); return false end
    return true
end
function S:UpdateTemplate()
    local current=userName(self.allPreset)
    if not current or not self:Templates()[current] then return end
    FT:Confirm('Update template "'..current..'" with your current skin settings?',function() self:SaveTemplate(current) end)
end
function S:SaveCurrentAsTemplate()
    self:AskTemplateName("Name for your new skin template:","",function(name) if validName(self,name) then self:SaveTemplate(name) end end)
end
function S:RenameTemplate()
    local old=userName(self.allPreset); if not old then return end
    self:AskTemplateName('Rename template "'..old..'" to:',old,function(name)
        if name==old or not validName(self,name,old) then return end
        local list=self:Templates(); list[name]=list[old]; list[old]=nil
        self.allPreset=PREFIX..name; self:Refresh(); FT:Toast('Template renamed to "'..name..'".',3)
    end)
end
function S:DeleteTemplate()
    local name=userName(self.allPreset); if not name then return end
    FT:Confirm('Delete skin template "'..name..'"? Your current skin settings do not change.',function()
        self:Templates()[name]=nil; self.allPreset="dark"; self:Refresh(); FT:Toast("Template deleted.",2)
    end)
end

local refresh=S.Refresh
function S:Refresh()
    refresh(self)
    if not self.frame then return end
    if not self.saveTemplate then
        local frame=self.frame
        -- The template list: built-in templates first, then your own.
        self.allPresetChoice.options=function()
            local list={}
            for _,p in ipairs(self.presets) do if p.value~="custom" then list[#list+1]={value=p.value,label=p.label,icon="Interface\\Icons\\"..FT.icons.skins,tooltip="Built-in template. Sets colors and transparency for every area."} end end
            for _,name in ipairs(self:TemplateNames()) do
                list[#list+1]={value=PREFIX..name,label=name.."  (your template)",icon="Interface\\Icons\\INV_Misc_Note_02",tooltip="Your template. Applying it restores every skin setting exactly as you saved it."}
            end
            return list
        end
        local w=111
        self.saveTemplate=FT:QuietButton(frame,"Save as new",w,32,"add"); self.saveTemplate:SetPoint("TOPLEFT",222,-244)
        self.saveTemplate:SetScript("OnClick",function() self:SaveCurrentAsTemplate() end)
        FT:Tooltip(self.saveTemplate,"Save as new template","Save your current skin settings (every area) as a new template with a name you choose.")
        self.updateTemplate=FT:QuietButton(frame,"Update",w,32,"reset"); self.updateTemplate:SetPoint("LEFT",self.saveTemplate,"RIGHT",12,0)
        self.updateTemplate:SetScript("OnClick",function() self:UpdateTemplate() end)
        FT:Tooltip(self.updateTemplate,"Update template","Replace the selected template with your current skin settings. Asks first. Only your own templates can be updated.")
        self.renameTemplate=FT:QuietButton(frame,"Rename",w,32,"INV_Misc_Note_01"); self.renameTemplate:SetPoint("LEFT",self.updateTemplate,"RIGHT",12,0)
        self.renameTemplate:SetScript("OnClick",function() self:RenameTemplate() end)
        FT:Tooltip(self.renameTemplate,"Rename template","Give the selected template a new name. Only your own templates can be renamed.")
        self.deleteTemplate=FT:QuietButton(frame,"Delete",w,32,"delete"); self.deleteTemplate:SetPoint("LEFT",self.renameTemplate,"RIGHT",12,0)
        self.deleteTemplate:SetScript("OnClick",function() self:DeleteTemplate() end)
        FT:Tooltip(self.deleteTemplate,"Delete template","Delete the selected template. Asks first. Only your own templates can be deleted.")
        for _,b in ipairs({self.saveTemplate,self.updateTemplate,self.renameTemplate,self.deleteTemplate}) do
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            b.label:SetFont(FT.bodyFont,13,""); if b.label.SetWordWrap then b.label:SetWordWrap(false) end
        end
        -- Applying a template: yours restore everything, built-ins work as before.
        local builtIn=self.applyAll:GetScript("OnClick")
        self.applyAll:SetScript("OnClick",function(...)
            local name=userName(self.allPreset)
            if not name then return builtIn(...) end
            FT:Confirm('Apply your template "'..name..'"? It replaces all current skin settings.',function() self:ApplyTemplate(name) end)
        end)
        FT:Tooltip(self.allPresetChoice,"Templates","Built-in templates and your own. Choose one, then use the button below to apply it to every area. Save your own look as a template to switch back to it any time; your templates are shared by all characters.")
    end
    local everything=(self.selected or "everything")=="everything"
    local mine=userName(self.allPreset)
    if mine and not self:Templates()[mine] then self.allPreset="dark"; mine=nil end
    for _,c in ipairs({self.saveTemplate,self.updateTemplate,self.renameTemplate,self.deleteTemplate}) do c:SetShown(everything) end
    if not everything then return end
    self.allPresetChoice.value=self.allPreset
    if mine then self.allPresetChoice.label:SetText(mine.."  (your template)") end
    for _,b in ipairs({self.updateTemplate,self.renameTemplate,self.deleteTemplate}) do b:SetEnabled(mine~=nil); b:SetAlpha(mine and 1 or .45) end
end
