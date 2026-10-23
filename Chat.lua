local _,FT=...
local Chat={tracked={}}
local options={{"social","Social button"},{"tabs","Chat tabs"},{"icons","Side buttons"},{"input","Input box border"},{"copy","Copy button"}}
-- Values the game hides in a fight are treated as "not known".
local function hidden(...)
    if not issecretvalue then return false end
    for i=1,select("#",...) do if issecretvalue((select(i,...))) then return true end end
    return false
end
local function mouseOver(object)
    if not object or not object.IsMouseOver then return false end
    local over=object:IsMouseOver()
    if hidden(over) then return false end
    return over==true
end
local function overBox(object,padding)
    if not object then return false end
    if mouseOver(object) then return true end
    if not object.GetLeft or not object.GetRight or not object.GetTop or not object.GetBottom then return false end
    local left,right,top,bottom=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
    if hidden(left,right,top,bottom) then return false end
    if not left or not right or not top or not bottom then return false end
    local x,y=GetCursorPosition(); local scale=object:GetEffectiveScale()
    if hidden(x,y,scale) then return false end
    x,y=x/scale,y/scale
    return x>=left-padding and x<=right+padding and y>=bottom-padding and y<=top+padding
end
function Chat:Settings()
    if type(FT.db.chat)~="table" then FT.db.chat={} end
    local s=FT.db.chat
    -- The copy button shows while the mouse is over the chat.
    if s.copy~="show" and s.copy~="hide" and s.copy~="hover" then s.copy="hover" end
    return s
end
-- Copy chat: a window with the chat frame's text, to select and copy
-- (Ctrl+C). Links, icons and colors become plain text. Lines the game hides
-- in a fight are marked as hidden.
-- colors: keep the chat's colors (class-colored names and the like). The
-- box shows them; copied text then carries the game's color codes, so
-- "Colors: Off" gives clean text to paste elsewhere.
local function plainText(text,colors)
    text=text:gsub("|T.-|t",""):gsub("|A.-|a","")
    if not colors then text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|cn.-:",""):gsub("|r","") end
    text=text:gsub("|H.-|h(.-)|h","%1"):gsub("|K.-|k","?"):gsub("|n","\n")
    return text
end
function Chat:CopyText(frame,colors)
    frame=frame or SELECTED_CHAT_FRAME or ChatFrame1
    local lines={}
    local count=frame and frame.GetNumMessages and frame:GetNumMessages() or 0
    if hidden(count) or type(count)~="number" then count=0 end
    -- Each line's time: the chat keeps when a line arrived (game uptime);
    -- turned into the clock time. Time: Off, 21:17 or 21:17:05.
    local mode=self:CopyTime()
    local seconds=mode=="hms"
    local buffer=frame and frame.historyBuffer
    local nowClock,nowUp=time and time() or 0,GetTime and GetTime() or 0
    local function stamp(i)
        if mode=="off" or not buffer or not buffer.GetEntryAtIndex or not buffer.GetNumElements or not date then return "" end
        local ok,entry=pcall(function() return buffer:GetEntryAtIndex(buffer:GetNumElements()-i+1) end)
        local at=ok and type(entry)=="table" and entry.timestamp
        if type(at)~="number" or hidden(at) then return "" end
        return "|cff9d9d9d["..date(seconds and "%H:%M:%S" or "%H:%M",math.floor(nowClock-(nowUp-at)+.5)).."]|r "
    end
    for i=1,count do
        local ok,text=pcall(frame.GetMessageInfo,frame,i)
        if ok and type(text)=="string" and not hidden(text) then lines[#lines+1]=stamp(i)..plainText(text,colors)
        elseif ok and text~=nil then lines[#lines+1]=stamp(i).."(hidden by the game in this fight)" end
    end
    return table.concat(lines,"\n")
end
-- Time in front of each copied line: "off", "hm" (21:17) or "hms" (21:17:05).
function Chat:CopyTime()
    local s=self:Settings()
    if s.copyTime~="off" and s.copyTime~="hm" and s.copyTime~="hms" then s.copyTime=s.copySeconds==false and "hm" or "hms" end
    return s.copyTime
end
function Chat:OpenCopy(frame)
    local w=self.copyWindow
    if not w then
        w=CreateFrame("Frame","ForeverToolsChatCopy",UIParent); w:SetSize(620,420); w:SetPoint("CENTER")
        w:SetFrameStrata("FULLSCREEN"); w:SetClampedToScreen(true); w:EnableMouse(true); w:SetMovable(true); w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart",w.StartMoving); w:SetScript("OnDragStop",w.StopMovingOrSizing)
        FT:Panel(w)
        w.title=FT:Label(w,"Copy chat",15,true); w.title:SetPoint("TOPLEFT",16,-12)
        w.hint=FT:Label(w,"Select with the mouse, then Ctrl+C. Esc closes.",12); w.hint:SetPoint("TOPLEFT",16,-34); w.hint:SetTextColor(.66,.59,.48)
        local close=CreateFrame("Button",nil,w,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)
        w.seconds=FT:QuietButton(w,"",150,24,"INV_Misc_PocketWatch_01"); w.seconds:SetPoint("TOPRIGHT",-40,-8); w.seconds.label:SetFont(FT.bodyFont,12,"")
        w.seconds:SetScript("OnClick",function() local s=Chat:Settings(); s.copyTime=({off="hm",hm="hms",hms="off"})[Chat:CopyTime()]; Chat:OpenCopy(w.frame) end)
        FT:Tooltip(w.seconds,"Time","Show the time each line arrived.")
        local scroll=CreateFrame("ScrollFrame","ForeverToolsChatCopyScroll",w,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-58); scroll:SetPoint("BOTTOMRIGHT",-34,14)
        local box=CreateFrame("EditBox",nil,scroll); box:SetMultiLine(true); box:SetAutoFocus(false); box:SetWidth(560)
        box:SetFontObject(ChatFontNormal or GameFontHighlight)
        box:SetScript("OnEscapePressed",function() w:Hide() end)
        -- Read only: typing puts the chat text back.
        box:SetScript("OnTextChanged",function(owner,user) if user and w.text then owner:SetText(w.text) end end)
        scroll:SetScrollChild(box)
        w.scroll,w.box=scroll,box
        -- Hold the mouse to select and drag past the top or bottom: the text
        -- scrolls, faster the further out the mouse is.
        box:HookScript("OnMouseDown",function() w.selecting=true end)
        box:HookScript("OnMouseUp",function() w.selecting=false end)
        w:SetScript("OnUpdate",function(_,dt)
            if not w.selecting then return end
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then w.selecting=false; return end
            local _,y=GetCursorPosition(); local scale=scroll:GetEffectiveScale(); y=y/scale
            local top,bottom=scroll:GetTop(),scroll:GetBottom(); if not top or not bottom then return end
            local step=0
            if y>top then step=-(y-top) elseif y<bottom then step=bottom-y end
            if step~=0 then
                local range=scroll:GetVerticalScrollRange() or 0
                local speed=math.max(60,math.abs(step)*12)*dt*(step<0 and -1 or 1)
                scroll:SetVerticalScroll(math.max(0,math.min(range,scroll:GetVerticalScroll()+speed)))
            end
        end)
        if UISpecialFrames then table.insert(UISpecialFrames,"ForeverToolsChatCopy") end
        self.copyWindow=w
    end
    w.frame=frame
    local mode=self:CopyTime()
    w.seconds.label:SetText("Time: "..({off="Off",hm="21:17",hms="21:17:05"})[mode]); FT:SetSelected(w.seconds,mode~="off")
    -- The chat's own colors (class-colored names and the like).
    w.text=self:CopyText(frame,true)
    w.box:SetText(w.text); w.box:ClearFocus()
    w:Show()
    -- Start at the newest line, like the chat.
    C_Timer.After(0,function() if w.scroll.GetVerticalScrollRange then w.scroll:SetVerticalScroll(w.scroll:GetVerticalScrollRange()) end end)
end
-- The small copy button in each chat window's top right corner.
function Chat:CopyButton(frame,i)
    if not frame or frame.ftCopy then return frame and frame.ftCopy end
    local b=CreateFrame("Button",nil,frame); b:SetSize(20,20); b:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-2,-2); b:SetFrameLevel(frame:GetFrameLevel()+5)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_02"); FT:RoundIcon(b.icon)
    local hi=b:CreateTexture(nil,"HIGHLIGHT"); hi:SetAllPoints(); hi:SetColorTexture(1,1,1,.15)
    b:SetScript("OnClick",function() Chat:OpenCopy(frame) end)
    FT:Tooltip(b,"Copy chat","Copy this chat window's text. Also /ft copy.")
    frame.ftCopy=b
    return b
end
function Chat:Track(object,key,owner,cluster)
    if not object or not object.SetAlpha then return end
    local rec=self.tracked[object]
    if rec then rec.cluster=rec.cluster or cluster end
    if not rec then
        rec={alpha=object:GetAlpha(),key=key,owner=owner,cluster=cluster}; self.tracked[object]=rec
        if object.EnableMouse and object.IsMouseEnabled then rec.mouse=object:IsMouseEnabled() end
        if hooksecurefunc then
            hooksecurefunc(object,"SetAlpha",function(target)
                if not self.painting and FT.dbReady then self:Paint(target) end
            end)
        end
    end
end
local function tabsHovered(self)
    for object,rec in pairs(self.tracked) do
        if rec.key=="tabs" and (mouseOver(object) or mouseOver(rec.owner)) then return true end
    end
    return false
end
-- Side buttons (and the social button) show when the cursor is anywhere over
-- the box they sit in, not only exactly on one button. The box is the area
-- covering every button of that group on the same chat frame.
local function overGroup(self,cluster,padding)
    local left,right,top,bottom
    for object,rec in pairs(self.tracked) do
        if rec.cluster==cluster and object.IsShown and object:IsShown() and object.GetLeft then
            local l,r,t,b=object:GetLeft(),object:GetRight(),object:GetTop(),object:GetBottom()
            local scale=object:GetEffectiveScale()
            if not hidden(l,r,t,b,scale) and l and r and t and b then
                l,r,t,b=l*scale,r*scale,t*scale,b*scale
                left=left and math.min(left,l) or l; right=right and math.max(right,r) or r
                top=top and math.max(top,t) or t; bottom=bottom and math.min(bottom,b) or b
            end
        end
    end
    if not left then return false end
    local x,y=GetCursorPosition()
    if hidden(x,y) then return false end
    return x>=left-padding and x<=right+padding and y>=bottom-padding and y<=top+padding
end
local function paintOne(self,s,object,rec,tabsOver)
    local mode=s[rec.key] or "show"
    local hover=false
    if mode=="hover" then
        if rec.key=="tabs" then hover=tabsOver
        elseif rec.key=="copy" then hover=overBox(rec.owner,4) or mouseOver(object)
        elseif rec.key=="icons" or rec.key=="social" then
            local cache,cluster=self.groupHover,rec.cluster
            if not cluster then hover=overBox(object,8)
            elseif cache and cache[cluster]~=nil then hover=cache[cluster]
            else
                hover=overGroup(self,cluster,8)
                if cache then cache[cluster]=hover end
            end
        else
            -- The input box border also shows while you are typing (for
            -- example after clicking a name to whisper), not only on hover.
            local owner=rec.owner
            hover=(rec.key=="input" and owner and ((owner.HasFocus and owner:HasFocus()==true) or mouseOver(owner))) or mouseOver(object)
        end
    end
    local visible=mode=="show" or (mode=="hover" and hover)
    local alpha=visible and (mode=="hover" and 1 or rec.alpha) or 0
    -- Only touch the frame when something changes (this runs often).
    local current=object.GetAlpha and object:GetAlpha()
    if hidden(current) or type(current)~="number" or math.abs(current-alpha)>.001 then object:SetAlpha(alpha) end
    -- Showing and hiding is allowed in a fight; switching the mouse on a
    -- frame is not always, and it only changes with the setting anyway.
    if rec.mouse~=nil and not FT:LooksWait() then
        local mouse=mode~="hide" and rec.mouse
        local actual=object.IsMouseEnabled and object:IsMouseEnabled()
        if actual~=mouse then object:EnableMouse(mouse) end
    end
end
-- Paint(): every tracked object. Paint(object): just that one (used when
-- Blizzard changes its alpha, for example while fading chat tabs).
function Chat:Paint(only)
    if self.painting then return end
    self.painting=true
    local s=self:Settings()
    if only then
        local rec=self.tracked[only]
        if rec then paintOne(self,s,only,rec,rec.key=="tabs" and s.tabs=="hover" and tabsHovered(self)) end
    else
        local tabsOver=s.tabs=="hover" and tabsHovered(self)
        -- Work out each box once per paint, not once per button.
        self.groupHover={}
        for object,rec in pairs(self.tracked) do paintOne(self,s,object,rec,tabsOver) end
        self.groupHover=nil
    end
    self.painting=false
end
-- Mouseover modes need polling; shown and hidden ones do not.
function Chat:NeedsPolling()
    local s=self:Settings()
    for _,entry in ipairs(options) do if s[entry[1]]=="hover" then return true end end
    return false
end
function Chat:Apply()
    if not FT.dbReady or FT:LooksWait() then return end
    self:Track(QuickJoinToastButton,"social",ChatFrame1,"social")
    self:Track(FriendsMicroButton,"social",ChatFrame1,"social")
    for _,name in ipairs({"ChatFrameMenuButton","ChatFrameChannelButton","ChatFrameToggleVoiceDeafenButton","ChatFrameToggleVoiceMuteButton"}) do self:Track(_G[name],"icons",ChatFrame1,"side1") end
    for i=1,(NUM_CHAT_WINDOWS or 10) do
        local name="ChatFrame"..i; local frame=_G[name]
        self:Track(_G[name.."Tab"],"tabs",frame)
        self:Track(_G[name.."ButtonFrame"],"icons",frame,"side"..i)
        self:Track(_G[name.."ScrollBar"],"icons",frame)
        if frame then self:Track(frame.ScrollBar,"icons",frame); self:Track(frame.ScrollToBottomButton,"icons",frame) end
        if frame then self:Track(self:CopyButton(frame,i),"copy",frame) end
        local box=_G[name.."EditBox"]
        -- Only artwork is hidden. The edit box, focus, typed text and Enter work normally.
        for _,suffix in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(_G[name.."EditBox"..suffix],"input",box) end
        if box then for _,key in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do self:Track(box[key],"input",box) end end
        if box and not box.ftFocusHooked and box.HookScript then
            box.ftFocusHooked=true
            box:HookScript("OnEditFocusGained",function() if FT.dbReady then Chat:Paint() end end)
            box:HookScript("OnEditFocusLost",function() if FT.dbReady then Chat:Paint() end end)
        end
    end
    self:Paint(); self:ApplyThanks(); self:ApplyHistory(); self:Refresh()
end
function Chat:Refresh()
    if not self.buttons then return end
    for _,entry in ipairs(options) do
        local mode=self:Settings()[entry[1]] or "show"
        self.buttons[entry[1]].label:SetText(entry[2]..": "..({show="Shown",hide="Hidden",hover="Mouseover"})[mode])
    end
    if self.thanks then
        local th=self:Thanks()
        self.thanks.label:SetText("Thank for buffs: "..(th.enabled and "On" or "Off")); FT:SetSelected(self.thanks,th.enabled)
        self.thanksGroup.label:SetText("Also my group: "..(th.group and "On" or "Off")); FT:SetSelected(self.thanksGroup,th.group)
        self.thanksGroup:SetAlpha(th.enabled and 1 or .5)
    end
    if self.history then
        local on=self:Settings().history==true
        self.history.label:SetText("Keep chat after reload: "..(on and "On" or "Off")); FT:SetSelected(self.history,on)
    end
    if self.links then
        local on=FT.modules.System:Settings().chatLinks==true
        self.links.label:SetText("Clickable links: "..(on and "On" or "Off"));FT:SetSelected(self.links,on)
    end
    if self.fontChoice then
        local fonts=FT.modules.FontManager;local pref=fonts:Settings("chat")
        local label=pref.font
        for _,choice in ipairs(fonts:Catalogue()) do if choice.value==pref.font then label=choice.label;break end end
        self.fontChoice.label:SetText("Chat font: "..label)
        self.fontSize.label:SetText("Size: "..(pref.size==0 and "Blizzard default" or pref.size.." px"))
        local outlineNames={original="Default",[""]="Default",THIN="Thin outline",OUTLINE="Outline",THICKOUTLINE="Thick outline"}
        self.outline.label:SetText("Outline: "..(outlineNames[pref.outline] or pref.outline))
    end
end
function Chat:Open()
    if not self.frame then
        self.frame=FT:Window("ForeverToolsChat","Chat",620,560); self.buttons={}
        -- Two columns: what shows around the chat on the left, its text on the right.
        local buttonsHead=FT:Label(self.frame,"Buttons and tabs",15,true);buttonsHead:SetPoint("TOPLEFT",24,-66);FT:SectionHeading(buttonsHead,"INV_Misc_Note_03",200)
        FT:AppearanceBack(self.frame)
        FT:PageInfo(self.frame,"Chat","What shows around the chat, the chat font, and clickable links.")
        for i,entry in ipairs(options) do
            local key=entry[1]; local b=FT:QuietButton(self.frame,"",276,32,"chat")
            b:SetPoint("TOPLEFT",24,-94-(i-1)*40)
            FT:MakeChoice(b,{{"show","Shown"},{"hide","Hidden"},{"hover","Mouseover","Shows while the mouse is over the chat."}},function() return self:Settings()[key] or "show" end,function(v) self:Settings()[key]=v; self:Apply() end)
            FT:Tooltip(b,entry[2],key=="copy" and "A button to copy the chat's text." or "Shown, Hidden, or on mouseover.")
            self.buttons[key]=b
        end
        local heading=FT:Label(self.frame,"Chat text",15,true);heading:SetPoint("TOPLEFT",320,-66);FT:SectionHeading(heading,"INV_Inscription_Tradeskill01",200)
        local fonts=FT.modules.FontManager
        self.fontChoice=FT:Dropdown(self.frame,276,function() return fonts:Catalogue() end,function(value)
            local pref=fonts:Settings("chat");local path=fonts:Resolve({font=value})
            if not fonts:ValidFont(path) then FT:Toast("That font is unavailable.");return end
            pref.font=value;pref.enabled=true;fonts:ApplyArea("chat");self:Refresh()
        end,"fonts")
        self.fontChoice:SetPoint("TOPLEFT",320,-94)
        self.fontSize=FT:QuietButton(self.frame,"",184,32,"fonts");self.fontSize:SetPoint("TOPLEFT",320,-134)
        self.fontSize:SetScript("OnClick",function()
            local p=fonts:Settings("chat");if p.size==0 then return end
            FT:Confirm("Restore the original chat font size?",function() p.size=0;fonts:ApplyArea("chat");self:Refresh() end)
        end)
        for i,delta in ipairs({-1,1}) do
            local button=FT:QuietButton(self.frame,delta<0 and "-" or "+",40,32,delta<0 and "reset" or "add")
            button:SetPoint("TOPLEFT",510+(i-1)*46,-134)
            FT:Tooltip(button,delta<0 and "Smaller" or "Larger",delta<0 and "Make chat text one size smaller." or "Make chat text one size larger.")
            button:SetScript("OnClick",function()local p=fonts:Settings("chat");p.size=math.max(8,math.min(40,(p.size==0 and 14 or p.size)+delta));p.enabled=true;fonts:ApplyArea("chat");self:Refresh() end)
        end
        self.outline=FT:QuietButton(self.frame,"",276,32,"fonts");self.outline:SetPoint("TOPLEFT",320,-174)
        local choices={"original","THIN","OUTLINE","THICKOUTLINE"}
        local names={original="Default",THIN="Thin outline",OUTLINE="Outline",THICKOUTLINE="Thick outline"}
        FT:MakeChoice(self.outline,function() local out={}; for _,v in ipairs(choices) do out[#out+1]={v,names[v] or v} end; return out end,
            function() local p=fonts:Settings("chat"); return (p.outline=="" or p.outline==nil) and "original" or p.outline end,
            function(v) local p=fonts:Settings("chat"); p.outline=v; p.enabled=true; fonts:ApplyArea("chat"); self:Refresh() end)
        FT:Tooltip(self.fontChoice,"Chat font","Chat font (same as Fonts > Chat).")
        FT:Tooltip(self.fontSize,"Chat font size","+ and - change the size. Click the number for the game's size.")
        FT:Tooltip(self.outline,"Chat outline","Shadow or outline on chat text.")
        local linksHead=FT:Label(self.frame,"Links",15,true);linksHead:SetPoint("TOPLEFT",24,-310);FT:SectionHeading(linksHead,"INV_Misc_Note_02",200)
        self.links=FT:QuietButton(self.frame,"",276,32,"chat");self.links:SetPoint("TOPLEFT",24,-338)
        self.links:SetScript("OnClick",function() local s=FT.modules.System:Settings();s.chatLinks=not s.chatLinks;self:Refresh() end)
        local thanksHead=FT:Label(self.frame,"Thanks",15,true);thanksHead:SetPoint("TOPLEFT",24,-390);FT:SectionHeading(thanksHead,"Spell_Holy_PrayerOfHealing",200)
        self.thanks=FT:QuietButton(self.frame,"",276,32,"Spell_Holy_PowerWordShield");self.thanks:SetPoint("TOPLEFT",24,-418)
        self.thanks:SetScript("OnClick",function() local th=self:Thanks(); th.enabled=not th.enabled; self:ApplyThanks(); self:Refresh() end)
        FT:Tooltip(self.thanks,"Thank for buffs","A /thank to players who buff you in the open world, after a short pause. Once per player every few minutes. Never in fights, dungeons or PvP.")
        self.thanksGroup=FT:QuietButton(self.frame,"",276,32,"Spell_Holy_PrayerOfHealing");self.thanksGroup:SetPoint("TOPLEFT",24,-458)
        self.thanksGroup:SetScript("OnClick",function() local th=self:Thanks(); th.group=not th.group; self:Refresh() end)
        FT:Tooltip(self.thanksGroup,"Also my group","Also thank group members.")
        FT:Tooltip(self.links,"Clickable links","Web addresses in chat become clickable, to copy.")
        local historyHead=FT:Label(self.frame,"History",15,true);historyHead:SetPoint("TOPLEFT",320,-230);FT:SectionHeading(historyHead,"INV_Misc_Book_09",150)
        self.history=FT:QuietButton(self.frame,"",276,32,"chat");self.history:SetPoint("TOPLEFT",320,-258)
        self.history:SetScript("OnClick",function()
            local st=self:Settings(); st.history=not st.history
            -- Turned on now: keep from here (nothing to bring back this time).
            if st.history then self.restored=true end
            self:ApplyHistory(); self:Refresh()
        end)
        FT:Tooltip(self.history,"Keep chat after reload","Today's chat comes back after a /reload or logging in again: up to 250 lines per chat window, for this character. From the next day it starts fresh. The combat log is not kept.")
    end
    self:Apply(); self.frame:Show()
end
-- Thank for buffs (Chat > Thanks, off by default). When another player
-- buffs you in the open world, you /thank them after a short, slightly
-- random pause (1 to 2.5 seconds), like a person would. Once per player
-- every few minutes; never in a fight, in dungeons, raids, battlegrounds
-- or arenas, and never for buffs from yourself or your pet. Group members
-- only with "Also my group" on. It is the game's own /thank emote.
local THANK_AGAIN=300
function Chat:Thanks()
    if type(FT.db.thanks)~="table" then FT.db.thanks={} end
    local s=FT.db.thanks
    if type(s.enabled)~="boolean" then s.enabled=false end
    if type(s.group)~="boolean" then s.group=false end
    return s
end
local thanked={}
local function inWorld()
    if not IsInInstance then return true end
    local ok,inside=pcall(IsInInstance)
    return ok and not hidden(inside) and not inside
end
-- The game only names who cast a buff when that player has a unit you can
-- point at (your target, mouseover, a group member, a nameplate). A buff
-- from a player the game doesn't name gets a general /thank (no name) instead,
-- at most once a minute.
local lastGeneral=0
-- The game's emote call (DoEmote is only kept for old addons on some clients).
local function emote(token,name)
    if C_ChatInfo and C_ChatInfo.PerformEmote then return pcall(C_ChatInfo.PerformEmote,token,name) end
    if DoEmote then return pcall(DoEmote,token,name) end
end
function Chat:ThankFor(info)
    local s=self:Thanks()
    if not s.enabled or InCombatLockdown() or not inWorld() then return end
    if type(info)~="table" or hidden(info) or hidden(info.addedAuras) or type(info.addedAuras)~="table" then return end
    for _,aura in ipairs(info.addedAuras) do
        if type(aura)=="table" and not hidden(aura) and not hidden(aura.isHelpful) and aura.isHelpful then
            local source=aura.sourceUnit
            local fromPlayer=aura.isFromPlayerOrPlayerPet
            if not hidden(source) and type(source)=="string" then
                if UnitIsPlayer(source) and not UnitIsUnit(source,"player") and not UnitIsUnit(source,"pet") then
                    local friend=UnitIsFriend and UnitIsFriend("player",source)
                    local grouped=(UnitInParty and UnitInParty(source)) or (UnitInRaid and UnitInRaid(source))
                    local name=UnitName(source)
                    if not hidden(friend) and friend and not hidden(grouped) and (s.group or not grouped) and not hidden(name) and type(name)=="string" then
                        local now=GetTime()
                        if not thanked[name] or now-thanked[name]>THANK_AGAIN then
                            thanked[name]=now
                            C_Timer.After(1+math.random()*1.5,function()
                                if InCombatLockdown() or not self:Thanks().enabled then return end
                                emote("THANK",name)
                            end)
                        end
                    end
                end
            elseif source==nil and not hidden(fromPlayer) and fromPlayer==true and not hidden(aura.sourceUnit) then
                -- Cast by a player the game doesn't name (not your own: those carry "player").
                local now=GetTime()
                if now-lastGeneral>60 then
                    lastGeneral=now
                    C_Timer.After(1+math.random()*1.5,function()
                        if InCombatLockdown() or not self:Thanks().enabled then return end
                        -- No target name: aimed at your target if you have one, so only then.
                        if not (UnitExists and UnitExists("target")) then emote("THANK",nil) end
                    end)
                end
            end
        end
    end
end
local thankEvents=CreateFrame("Frame")
function Chat:ApplyThanks()
    if self:Thanks().enabled then thankEvents:RegisterUnitEvent("UNIT_AURA","player") else thankEvents:UnregisterEvent("UNIT_AURA") end
end
thankEvents:SetScript("OnEvent",function(_,_,unit,info) if FT.dbReady and unit=="player" then Chat:ThankFor(info) end end)
FT:RegisterModule("Chat",Chat)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","UPDATE_CHAT_WINDOWS","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ADDON_LOADED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function() if FT.dbReady then FT:Coalesce("chat",function() Chat:Apply() end) end end)
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<=.15 then return end
    elapsed=0
    -- Also in a fight: mouseover buttons must show there too.
    if not FT.dbReady or not Chat:NeedsPolling() then return end
    -- Mouseover only changes when the mouse moves (typing and fading are
    -- handled when they happen), so skip the check while it stands still.
    local x,y=GetCursorPosition()
    if hidden(x,y) then return end
    if x==Chat.lastX and y==Chat.lastY then return end
    Chat.lastX,Chat.lastY=x,y
    Chat:Paint()
end)

-- Keep chat (Chat > History, off by default). What your chat windows showed
-- today comes back after a /reload or logging in again: up to 250 lines per
-- window, for this character, and only from today (from the next day it
-- starts empty). The combat log and lines the game hides (secret) or that
-- name Battle.net friends (only valid in the session they were written)
-- are not kept. It lives outside your profile, so it never travels with an
-- export.
local KEEP_LINES=250
local function today() return date and date("%Y-%m-%d") or "" end
function Chat:HistoryStore()
    if type(FT.db.chatHistory)~="table" then FT.db.chatHistory={} end
    local name=UnitName and UnitName("player"); local realm=GetRealmName and GetRealmName()
    if hidden(name,realm) or type(name)~="string" then return nil end
    local key=name.."-"..tostring(realm)
    local store=FT.db.chatHistory[key]
    if type(store)~="table" or store.day~=today() then store={day=today(),frames={}}; FT.db.chatHistory[key]=store end
    return store
end
local function keptFrame(i) local frame=_G["ChatFrame"..i]; if frame and frame~=COMBATLOG and i~=2 then return frame end end
function Chat:Remember(i,text,r,g,b)
    if self.restoring or not self:Settings().history then return end
    if hidden(text) or type(text)~="string" or text=="" or text:find("|K",1,true) then return end
    if hidden(r,g,b) then r,g,b=nil,nil,nil end
    local store=self.historyStore; if not store or store.day~=today() then store=self:HistoryStore(); self.historyStore=store end
    if not store then return end
    local list=store.frames[i]; if not list then list={}; store.frames[i]=list end
    list[#list+1]={text,type(r)=="number" and r or nil,type(g)=="number" and g or nil,type(b)=="number" and b or nil}
    if #list>KEEP_LINES then table.remove(list,1) end
end
function Chat:ApplyHistory()
    local on=self:Settings().history==true
    if on and not self.historyHooked and hooksecurefunc then
        self.historyHooked=true
        for i=1,(NUM_CHAT_WINDOWS or 10) do
            local frame=keptFrame(i)
            if frame and frame.AddMessage then hooksecurefunc(frame,"AddMessage",function(_,text,r,g,b) Chat:Remember(i,text,r,g,b) end) end
        end
    end
    if not on then self.historyStore=nil end
end
-- Put today's lines back, once per login, before anything new is kept.
function Chat:RestoreHistory()
    if self.restored or not self:Settings().history then return end
    self.restored=true
    local store=self:HistoryStore(); if not store then return end
    self.historyStore=store
    self.restoring=true
    for i,list in pairs(store.frames) do
        local frame=type(i)=="number" and keptFrame(i)
        if frame and type(list)=="table" and #list>0 then
            frame:AddMessage("|cff8a7f6a— Chat from earlier today —|r")
            for _,line in ipairs(list) do if type(line)=="table" and type(line[1])=="string" then pcall(frame.AddMessage,frame,line[1],line[2],line[3],line[4]) end end
            frame:AddMessage("|cff8a7f6a— Now —|r")
        end
    end
    self.restoring=false
end
local historyEvents=CreateFrame("Frame")
historyEvents:RegisterEvent("PLAYER_LOGIN")
historyEvents:SetScript("OnEvent",function()
    if not FT.dbReady then return end
    -- Restore first, then start keeping new lines (the restored ones are not
    -- kept twice).
    Chat:RestoreHistory(); Chat:ApplyHistory()
end)
