local _,FT=...
-- Item counts in tooltips (Appearance > Item counts; off by default).
-- How many of the hovered item you have: in your bags, bank and worn gear,
-- on your other characters on this ruleset, in the guild bank and the
-- (no warband bank in Forever). Read from what Bags.lua has saved, so it costs nothing until
-- a tooltip opens, and each character's totals are counted once until its
-- bags change.
local Counts={}
local function plain(v) return not (issecretvalue and issecretvalue(v)) end
local function bags() return FT.Bags end
local function settings() return bags():Settings() end
-- The lines for one item: {left, right} pairs, and the grand total.
function Counts:Lines(id,s)
    s=s or settings()
    local B=bags()
    local rows,total={},0
    local function split(e)
        local parts={}
        if e.bags>0 then parts[#parts+1]="bags "..e.bags end
        if e.bank>0 then parts[#parts+1]="bank "..e.bank end
        if e.worn>0 then parts[#parts+1]="worn "..e.worn end
        if (e.mail or 0)>0 then parts[#parts+1]="mail "..e.mail end
        return parts
    end
    local function right(e)
        local parts=split(e)
        if s.countSplit and #parts>1 then return "|cffffffff"..e.total.."|r  |cffb8ab8a("..table.concat(parts,", ")..")|r" end
        if s.countSplit and #parts==1 then return "|cffffffff"..e.total.."|r  |cffb8ab8a("..parts[1]:gsub(" %d+$","")..")|r" end
        return "|cffffffff"..e.total.."|r"
    end
    local me=B:Me()
    for _,entry in ipairs(B:Characters()) do
        if not entry.me or s.countSelf then
            local e=(entry.me and B.LiveIndex and B:LiveIndex() or B:Index(entry.guid))[id]
            if e and e.total>0 then rows[#rows+1]={B:ClassName(entry.c,entry.guid,s.countFullNames),right(e)}; total=total+e.total end
        end
    end
    local st=B:Store()
    if s.countGuild then
        local realm=B:Ruleset(); local mine=B:GuildKey()
        local guilds={}
        for key,guild in pairs(st.guilds) do if type(guild)=="table" and B.SameRealm(guild.realm)==realm then guilds[#guilds+1]=key end end
        table.sort(guilds,function(a,b) if a==mine then return true elseif b==mine then return false end return a<b end)
        for _,key in ipairs(guilds) do
            local e=B:Index("guild:"..key)[id]
            if e and e.total>0 then
                local label=(#guilds==1 or key==mine) and "Guild bank" or ("<"..(st.guilds[key].name or "?")..">")
                rows[#rows+1]={"|cff40ff40"..label.."|r","|cffffffff"..e.total.."|r"}; total=total+e.total
            end
        end
    end
    return rows,total,me
end
-- What goes on the tooltip, following the style setting.
function Counts:Build(rows,total,s)
    s=s or settings()
    if #rows==0 then return {} end
    local out={}
    if s.countStyle~="total" then for _,row in ipairs(rows) do out[#out+1]=row end end
    if s.countStyle=="total" or (s.countStyle=="both" and #rows>1) then
        out[#out+1]={"|cffffd100Total|r","|cffffffff"..total.."|r"}
    end
    return out
end
function Counts:ItemFrom(data)
    if type(data)~="table" or not plain(data) then return end
    local id=data.id
    if plain(id) and type(id)=="number" then return id end
end
-- The box above or below the tooltip.
local boxes={}
function Counts:Box(tip)
    if boxes[tip] then return boxes[tip] end
    local ok,box=pcall(CreateFrame,"Frame",nil,UIParent,"TooltipBackdropTemplate")
    if not ok or not box then box=CreateFrame("Frame",nil,UIParent); FT:Panel(box) end
    box:SetFrameStrata("TOOLTIP"); box:SetClampedToScreen(true)
    box.left,box.right={},{}
    box:Hide()
    boxes[tip]=box
    tip:HookScript("OnHide",function() box:Hide() end)
    if tip.HookScript then pcall(tip.HookScript,tip,"OnTooltipCleared",function() box:Hide() end) end
    return box
end
function Counts:BoxOf(tip) return boxes[tip] end
function Counts:FillBox(tip,lines,place)
    local box=self:Box(tip)
    local width,height=0,10
    for i,line in ipairs(lines) do
        local l,r=box.left[i],box.right[i]
        if not l then
            l=box:CreateFontString(nil,"OVERLAY","GameTooltipText"); box.left[i]=l
            r=box:CreateFontString(nil,"OVERLAY","GameTooltipText"); box.right[i]=r; r:SetJustifyH("RIGHT")
        end
        l:SetText(line[1]); r:SetText(line[2])
        l:ClearAllPoints(); l:SetPoint("TOPLEFT",10,-8-(i-1)*16)
        r:ClearAllPoints(); r:SetPoint("TOPRIGHT",-10,-8-(i-1)*16)
        l:Show(); r:Show()
        local w=(l:GetStringWidth() or 0)+(r:GetStringWidth() or 0)+40
        if w>width then width=w end
        height=height+16
    end
    for i=#lines+1,#box.left do box.left[i]:Hide(); box.right[i]:Hide() end
    box:SetSize(math.max(width,(tip:GetWidth() or 0)),height+6)
    box:ClearAllPoints()
    if place=="above" then box:SetPoint("BOTTOMLEFT",tip,"TOPLEFT",0,2) else box:SetPoint("TOPLEFT",tip,"BOTTOMLEFT",0,-2) end
    box:Show()
end
function Counts:OnTooltip(tip,data)
    local B=bags()
    if boxes[tip] then boxes[tip]:Hide() end
    if not B or not FT.dbReady then return end
    local s=settings()
    if not s.counts then return end
    if tip~=GameTooltip and tip~=ItemRefTooltip then return end
    if s.countShift and not (IsShiftKeyDown and IsShiftKeyDown()) then return end
    local id=self:ItemFrom(data); if not id then return end
    local rows,total=self:Lines(id,s)
    local lines=self:Build(rows,total,s)
    if #lines==0 then return end
    if s.countPlace=="inside" then
        if s.countSpacer then tip:AddLine(" ") end
        for _,line in ipairs(lines) do tip:AddDoubleLine(line[1],line[2],1,1,1,1,1,1) end
        tip:Show()
    else
        self:FillBox(tip,lines,s.countPlace)
    end
end
function Counts:Hook()
    if self.hooked then return end
    self.hooked=true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item~=nil then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip,data) pcall(self.OnTooltip,self,tip,data) end)
    else
        -- Game versions without the tooltip data system: the item tooltip's
        -- own "item set" moment, with the id read from the item's link.
        for _,tip in ipairs({GameTooltip,ItemRefTooltip}) do
            if tip and tip.HookScript and (not tip.HasScript or tip:HasScript("OnTooltipSetItem")) then
                tip:HookScript("OnTooltipSetItem",function(owner)
                    local ok,_,link=pcall(owner.GetItem,owner)
                    local id=ok and plain(link) and type(link)=="string" and tonumber(link:match("item:(%d+)"))
                    if id then pcall(self.OnTooltip,self,owner,{id=id}) end
                end)
            end
        end
    end
end
-- Holding Shift (when counts wait for it) redraws the tooltip that is open.
local watcher=CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
pcall(watcher.RegisterEvent,watcher,"MODIFIER_STATE_CHANGED")
watcher:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then Counts:Hook(); return end
    if not FT.dbReady or not settings().counts or not settings().countShift then return end
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then pcall(GameTooltip.RefreshData,GameTooltip) end
end)
-- Settings page --------------------------------------------------------------
local SAMPLE={
    {name="Krilar",full="Krilar Stormcaller",class="SHAMAN",me=true,e={bags=12,bank=8,worn=0,total=20}},
    {name="Frostbolt",full="Frostbolt Emberwake",class="MAGE",e={bags=5,bank=0,worn=0,total=5}},
    {name="Shadowmeld",full="Shadowmeld Nightveil",class="ROGUE",e={bags=0,bank=3,worn=0,total=3}},
}
function Counts:SampleLines(s)
    local rows,total={},0
    local function colored(entry)
        local name=(s.countFullNames and entry.full) or entry.name
        local c=(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[entry.class]
        if c and c.r then return string.format("|cff%02x%02x%02x%s|r",c.r*255,c.g*255,c.b*255,name) end
        return name
    end
    for _,entry in ipairs(SAMPLE) do
        if not entry.me or s.countSelf then
            local e=entry.e; local parts={}
            if e.bags>0 then parts[#parts+1]="bags "..e.bags end
            if e.bank>0 then parts[#parts+1]="bank "..e.bank end
            local right="|cffffffff"..e.total.."|r"
            if s.countSplit and #parts>1 then right=right.."  |cffb8ab8a("..table.concat(parts,", ")..")|r"
            elseif s.countSplit and #parts==1 then right=right.."  |cffb8ab8a("..parts[1]:gsub(" %d+$","")..")|r" end
            rows[#rows+1]={colored(entry),right}; total=total+e.total
        end
    end
    if s.countGuild then rows[#rows+1]={"|cff40ff40Guild bank|r","|cffffffff40|r"}; total=total+40 end
    return self:Build(rows,total,s)
end
local styles={
    {value="each",label="Each character",tooltip="One line per character that has it."},
    {value="total",label="Total only",tooltip="One line with how many you have in all."},
    {value="both",label="Each character and total",tooltip="One line per character, then the total."},
}
local places={
    {value="inside",label="Inside, at the bottom",tooltip="At the bottom of the tooltip."},
    {value="above",label="Box above the tooltip",tooltip="A small box above the tooltip."},
    {value="below",label="Box below the tooltip",tooltip="A small box below the tooltip."},
}
local function labelOf(list,value) for _,item in ipairs(list) do if item.value==value then return item.label end end end
local toggles={
    {"countSplit","Bags and bank apart","INV_Misc_Bag_10","Show where: bags, bank or worn."},
    {"countSelf","This character too","character","Include the character you play."},
    {"countGuild","Guild bank","INV_Shirt_GuildTabard_01","Include the guild bank (read when you open it)."},
    {"countFullNames","Full character names","character","First and last names. Alts need one login."},
    {"countShift","Only while Shift is held","INV_Misc_Key_03","Show counts only while holding Shift."},
    {"countSpacer","Empty line before","INV_Misc_Note_01","An empty line before the counts."},
}
function Counts:Refresh()
    if not self.frame then return end
    local s=settings()
    self.toggle.label:SetText("Item counts: "..(s.counts and "On" or "Off")); FT:SetSelected(self.toggle,s.counts)
    self.style.label:SetText("Show: "..labelOf(styles,s.countStyle))
    self.place.label:SetText("Place: "..labelOf(places,s.countPlace))
    for _,entry in ipairs(toggles) do
        local b=self.buttons[entry[1]]
        b.label:SetText(entry[2]..": "..(s[entry[1]] and "On" or "Off")); FT:SetSelected(b,s[entry[1]])
    end
    local spacer=self.buttons.countSpacer
    spacer:SetEnabled(s.countPlace=="inside"); spacer:SetAlpha(s.countPlace=="inside" and 1 or .45)
    self:RenderPreview()
    if FT.RefreshDock then FT:RefreshDock(self.frame) end
end
-- A sample item tooltip with the counts where they would go.
function Counts:RenderPreview()
    local s=settings(); local p=self.preview
    local lines=self:SampleLines(s)
    local item={{"|cff1eff00Linen Cloth|r",""},{"|cffffffffCrafting reagent|r",""},{"|cffffffffMax stack: 20|r",""}}
    local function fill(box,rows)
        for i,row in ipairs(rows) do
            local l,r=box.left[i],box.right[i]
            l:SetText(row[1]); r:SetText(row[2]); l:Show(); r:Show()
        end
        for i=#rows+1,#box.left do box.left[i]:Hide(); box.right[i]:Hide() end
        box:SetHeight(#rows*17+14)
    end
    local inside=s.countPlace=="inside"
    local main={}
    for _,row in ipairs(item) do main[#main+1]=row end
    if inside then
        if s.countSpacer then main[#main+1]={" ",""} end
        for _,row in ipairs(lines) do main[#main+1]=row end
    end
    fill(p.tip,main)
    p.extra:SetShown(not inside)
    if not inside then fill(p.extra,lines) end
    p.tip:ClearAllPoints(); p.extra:ClearAllPoints()
    if s.countPlace=="above" then
        p.extra:SetPoint("TOPLEFT",p,"TOPLEFT",0,0)
        p.tip:SetPoint("TOPLEFT",p.extra,"BOTTOMLEFT",0,-4)
    else
        p.tip:SetPoint("TOPLEFT",p,"TOPLEFT",0,0)
        p.extra:SetPoint("TOPLEFT",p.tip,"BOTTOMLEFT",0,-4)
    end
    self.shiftNote:SetShown(s.countShift)
end
function Counts:Open()
    if not self.frame then
        local hub=FT:HubOf("ItemCounts"); local width=hub and hub.width or 760
        local frame=FT:Window("ForeverToolsItemCounts","Item counts",width,560); self.frame=frame
        FT:PageInfo(frame,"Item counts","How many you have of an item, on its tooltip: bags, bank, other characters on this ruleset and the guild bank.\n\nEach character needs one login; banks are read when opened.")
        local function section(x,y,title,icon)
            local h=FT:Label(frame,title,16,true); h:SetPoint("TOPLEFT",x,y); h:SetTextColor(1,.82,0)
            FT:SectionHeading(h,icon,x>100 and 120 or 200)
        end
        section(24,-66,"What to show","INV_Misc_Note_04")
        self.toggle=FT:AccentButton(frame,"",300,34,"INV_Misc_Note_04"); self.toggle:SetPoint("TOPLEFT",24,-96)
        self.toggle:SetScript("OnClick",function() local s=settings(); s.counts=not s.counts; bags():Apply(); self:Refresh() end)
        FT:Tooltip(self.toggle,"Item counts","Show how many of an item you have, and where.")
        self.style=FT:QuietButton(frame,"",300,32,"classes"); self.style:SetPoint("TOPLEFT",24,-138)
        self.style.options=function() local out={}; for _,o in ipairs(styles) do out[#out+1]={value=o.value,label=o.label,tooltip=o.tooltip,icon="Interface\\Icons\\INV_Misc_Note_04"} end; return out end
        self.style.onSelect=function(value) settings().countStyle=value; self:Refresh() end
        self.style:SetScript("OnClick",function(owner) owner.value=settings().countStyle; owner.menuWidth=364; FT:ShowChoices(owner) end)
        FT:Tooltip(self.style,"Show","Each character, a total, or both.")
        self.buttons={}
        for i,entry in ipairs(toggles) do
            local key=entry[1]
            local b=FT:QuietButton(frame,"",300,32,entry[3]); b:SetPoint("TOPLEFT",24,-178-(i-1)*38)
            if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
            b:SetScript("OnClick",function() local s=settings(); s[key]=not s[key]; self:Refresh() end)
            FT:Tooltip(b,entry[2],entry[4])
            self.buttons[key]=b
        end
        local divider=frame:CreateTexture(nil,"ARTWORK"); divider:SetColorTexture(.61,.51,.31,.6); divider:SetWidth(1)
        divider:SetPoint("TOPLEFT",338,-96); divider:SetPoint("BOTTOMLEFT",338,24)
        local R=352
        section(R,-66,"Where","Ability_Rogue_Sprint")
        self.place=FT:QuietButton(frame,"",244,32,"move"); self.place:SetPoint("TOPLEFT",R,-96)
        self.place.options=function() local out={}; for _,o in ipairs(places) do out[#out+1]={value=o.value,label=o.label,tooltip=o.tooltip,icon="Interface\\Icons\\Ability_Rogue_Sprint"} end; return out end
        self.place.onSelect=function(value) settings().countPlace=value; self:Refresh() end
        self.place:SetScript("OnClick",function(owner) owner.value=settings().countPlace; owner.menuWidth=316; FT:ShowChoices(owner) end)
        FT:Tooltip(self.place,"Place","Where the counts show.")
        local ph=FT:Label(frame,"Preview",16,true); ph:SetPoint("TOPLEFT",R,-146); ph:SetTextColor(1,.82,0); FT:SectionHeading(ph,"INV_Misc_Note_01",120)
        local p=CreateFrame("Frame",nil,frame); p:SetPoint("TOPLEFT",R,-178); p:SetSize(244,300)
        local function box()
            local b=CreateFrame("Frame",nil,p); b:SetWidth(244); FT:RoundedFill(b,0,0,0,.88)
            b.left,b.right={},{}
            for i=1,10 do
                local l=b:CreateFontString(nil,"OVERLAY"); l:SetFont(FT.bodyFont,12,""); l:SetPoint("TOPLEFT",10,-7-(i-1)*17); l:SetJustifyH("LEFT"); l:SetWidth(92)
                local r=b:CreateFontString(nil,"OVERLAY"); r:SetFont(FT.bodyFont,12,""); r:SetPoint("TOPRIGHT",-10,-7-(i-1)*17); r:SetJustifyH("RIGHT"); r:SetWidth(132)
                if l.SetWordWrap then l:SetWordWrap(false); r:SetWordWrap(false) end
                b.left[i],b.right[i]=l,r
            end
            return b
        end
        p.tip=box(); p.extra=box()
        self.preview=p
        self.shiftNote=FT:Label(frame,"Shown while you hold Shift.",12); self.shiftNote:SetPoint("BOTTOMLEFT",R,30); self.shiftNote:SetTextColor(.66,.59,.48)
    end
    self:Refresh(); self.frame:Show()
end
FT:RegisterModule("ItemCounts",Counts)
FT.BagCounts=Counts
