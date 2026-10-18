local _,FT=...
-- Bag order (0.80.0): where the bag window starts drawing your slots, and
-- the game's own "where new loot goes" and "which way Clean Up packs"
-- settings. Off by default: the game's layout is left alone until a corner
-- is picked, and the two game settings are only set once you choose them.
local Order={}
local function bags() return FT.Bags end
local function settings() return bags():Settings() end
local CORNERS={"topleft","topright","bottomleft","bottomright"}
local GAME_DEFAULT="bottomright" -- what the game itself draws since its October 8, 2026 update
Order.CORNERS=CORNERS
Order.GAME_DEFAULT=GAME_DEFAULT
local function container() return C_Container or {} end
function Order:HasInsert() return type(container().SetInsertItemsLeftToRight)=="function" and type(container().GetInsertItemsLeftToRight)=="function" end
function Order:HasCleanup() return type(container().SetSortBagsRightToLeft)=="function" and type(container().GetSortBagsRightToLeft)=="function" end
-- The game's current values: "backpack" or "lastbag".
-- What you picked here wins: the game may report its new value a moment late.
function Order:Insert()
    local picked=settings().insert; if picked then return picked end
    if not self:HasInsert() then return "backpack" end
    local ok,v=pcall(container().GetInsertItemsLeftToRight)
    return ok and v==true and "lastbag" or "backpack"
end
function Order:Cleanup()
    local picked=settings().cleanup; if picked then return picked end
    if not self:HasCleanup() then return "lastbag" end
    local ok,v=pcall(container().GetSortBagsRightToLeft)
    return ok and v==true and "backpack" or "lastbag"
end
-- All-in-one bag (the game's "combined bags") or one window per bag.
function Order:Combined()
    local m=ContainerFrameSettingsManager
    if m and m.IsUsingCombinedBags then local ok,v=pcall(m.IsUsingCombinedBags,m); if ok then return v~=false end end
    return true
end
-- The corner the bag window starts in: the chosen one, or the game's own.
function Order:Corner()
    local s=settings()
    return s.order~="game" and s.order or GAME_DEFAULT
end
-- The slot line (backpack slot 1 = item 0) is drawn into the game's grid,
-- which fills from the bottom right: cell 0 bottom right, then to the left
-- and upwards; a part row sits at the top, on the right. Which cell holds
-- item i (both counted from 0) for each corner:
function Order.Cell(i,n,columns,corner)
    if corner=="topleft" then return n-1-i end
    if corner=="bottomleft" or corner=="topright" then
        if corner=="topright" then i=n-1-i end
        local rows=math.ceil(n/columns)
        local row=math.floor(i/columns)
        local width=row<rows-1 and columns or (n-(rows-1)*columns)
        return row*columns+(width-1-(i%columns))
    end
    return i
end
-- Lay out one of the game's bag windows in the chosen order. Only positions
-- change; the buttons stay the game's own.
local function bagOf(b) local ok,v=pcall(b.GetBagID,b); return ok and type(v)=="number" and v or 0 end
local function slotOf(b) local ok,v=pcall(b.GetID,b); return ok and type(v)=="number" and v or 0 end
local function byLine(x,y)
    local bx,by=bagOf(x),bagOf(y)
    if bx~=by then return bx<by end
    return slotOf(x)<slotOf(y)
end
function Order:Layout(frame,force)
    local corner=settings().order
    if corner=="game" and not force then return end
    if corner=="game" then corner=GAME_DEFAULT end
    if InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() then return end
    if not (frame and frame.EnumerateValidItems and frame.GetColumns and frame.GetInitialItemAnchor and frame.GetAnchorLayout and AnchorUtil and AnchorUtil.GridLayout) then return end
    local items,extra={},{}
    for _,b in frame:EnumerateValidItems() do
        if b.IsExtended and b:IsExtended() then extra[#extra+1]=b else items[#items+1]=b end
    end
    table.sort(items,byLine); table.sort(extra,byLine)
    local n=#items
    if n==0 then return end
    local columns=frame:GetColumns()
    local cells={}
    for i=1,n do cells[Order.Cell(i-1,n,columns,corner)+1]=items[i] end
    for i=1,#extra do cells[n+i]=extra[i] end
    pcall(AnchorUtil.GridLayout,cells,frame:GetInitialItemAnchor(),frame:GetAnchorLayout())
end
local hooked={}
function Order:GameFrames()
    -- The all-in-one bag and every separate bag window, whichever mode is on.
    local list,seen={},{}
    local function add(frame) if frame and not seen[frame] then seen[frame]=true; list[#list+1]=frame end end
    add(ContainerFrameCombinedBags)
    local holder=ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    if type(holder)=="table" then for _,frame in ipairs(holder) do add(frame) end end
    for i=1,(NUM_CONTAINER_FRAMES or 13) do add(_G["ContainerFrame"..i]) end
    if ContainerFrameUtil_EnumerateContainerFrames then
        pcall(function() for _,frame in ContainerFrameUtil_EnumerateContainerFrames() do add(frame) end end)
    end
    return list
end
function Order:Hook()
    for _,frame in ipairs(self:GameFrames()) do
        if not hooked[frame] and frame.UpdateItemLayout then
            hooked[frame]=true
            hooksecurefunc(frame,"UpdateItemLayout",function(owner) Order:Layout(owner) end)
        end
    end
end
-- Re-draw open bag windows now (after a change).
function Order:Redraw()
    for _,frame in ipairs(self:GameFrames()) do
        if frame:IsShown() then self:Layout(frame,true) end
    end
    local view=bags().views and bags().views.bags
    if view and view:IsShown() then bags():FillView("bags") end
end
-- The two game settings are set again at each login when chosen (the game
-- keeps them per character; the profile carries them to your others).
function Order:ApplyGame()
    local s=settings()
    if s.insert and self:HasInsert() then pcall(container().SetInsertItemsLeftToRight,s.insert=="lastbag") end
    if s.cleanup and self:HasCleanup() then pcall(container().SetSortBagsRightToLeft,s.cleanup=="backpack") end
end
function Order:Apply()
    if settings().order~="game" then self:Hook() end
    self:ApplyGame()
    if self.hookedOnce or settings().order~="game" then self.hookedOnce=true; self:Redraw() end
    self:Refresh()
end
function Order:Set(key,value)
    local s=settings()
    s[key]=value
    if key=="order" then self:Hook(); self.hookedOnce=true end
    self:Apply()
    if FT.RefreshHub then pcall(FT.RefreshHub,FT) end
end
-- Words ----------------------------------------------------------------------
local cornerText={
    topleft={label="Top left",runs="runs to the right, then down a row",ends="bottom right"},
    topright={label="Top right",runs="runs to the left, then down a row",ends="bottom left"},
    bottomleft={label="Bottom left",runs="runs to the right, then up a row",ends="top right"},
    bottomright={label="Bottom right",runs="runs to the left, then up a row",ends="top left"},
}
Order.cornerText=cornerText
function Order:CornerTooltip(corner)
    local t=cornerText[corner]
    if not self:Combined() then
        return "Each bag window puts its first slot in the "..t.label:lower().." corner. Its slots run "..t.runs:gsub("^runs ","")..", and its last slot ends in the "..t.ends.." corner."
    end
    return "Your backpack's first slot sits in the "..t.label:lower().." corner. The line "..t.runs..", so your last bag ends in the "..t.ends.." corner."
end
function Order:Summary()
    local s=settings()
    return s.order=="game" and "Game's own" or cornerText[s.order].label
end
-- The page ---------------------------------------------------------------------
-- Colors for the example: backpack, then bags 1-4.
local BAG_COLORS={{.86,.66,.26},{.36,.62,.88},{.66,.46,.86},{.32,.74,.68},{.88,.46,.52}}
local CELL,GAP=13,2
-- Your real bag sizes, or a typical set when they cannot be read.
function Order:Sizes()
    local sizes={}
    for bag=0,4 do
        local ok,n=pcall(container().GetContainerNumSlots or function() return 0 end,bag)
        n=ok and type(n)=="number" and n or 0
        sizes[#sizes+1]=n
    end
    local total=0; for _,n in ipairs(sizes) do total=total+n end
    if total<4 then sizes={16,10,10,10,10} end
    return sizes
end
-- Half-full bags after Clean Up, and the slot the next new item goes to.
function Order:Example(sizes,insert,cleanup)
    local line={}
    for bag,n in ipairs(sizes) do for slot=1,n do line[#line+1]={bag=bag,slot=slot} end end
    local n=#line; local full=math.floor(n/2)
    for i=1,n do
        if cleanup=="backpack" then line[i].item=i<=full else line[i].item=i>n-full end
    end
    local order={}
    if insert=="lastbag" then
        for bag=#sizes,1,-1 do for i=1,n do if line[i].bag==bag then order[#order+1]=i end end end
    else for i=1,n do order[i]=i end end
    for _,i in ipairs(order) do if not line[i].item then line[i].next=true; break end end
    return line
end
function Order:Refresh()
    local page=self.page
    if not page or not page.frame then return end
    local s=settings()
    FT:SetSelected(page.game,s.order=="game")
    for corner,b in pairs(page.corners) do FT:SetSelected(b,s.order==corner) end
    local insert,cleanup=self:Insert(),self:Cleanup()
    for value,b in pairs(page.insert) do FT:SetSelected(b,insert==value); b:SetEnabled(self:HasInsert()); b:SetAlpha(self:HasInsert() and 1 or .45) end
    for value,b in pairs(page.cleanup) do FT:SetSelected(b,cleanup==value); b:SetEnabled(self:HasCleanup()); b:SetAlpha(self:HasCleanup() and 1 or .45) end
    -- The example.
    local p=page.preview
    local sizes=self:Sizes()
    local line=self:Example(sizes,insert,cleanup)
    local n=#line
    local corner=self:Corner()
    -- One grid for the all-in-one bag (10 to a row, like the game), or one
    -- small grid per bag window (4 to a row), side by side.
    local groups={}
    if self:Combined() then groups[1]={from=1,count=n,columns=10,size=CELL}
    else
        local first=1
        for _,size in ipairs(sizes) do
            if size>0 then groups[#groups+1]={from=first,count=size,columns=4,size=11} end
            first=first+size
        end
    end
    local maxWidth=p:GetWidth() or 186
    local x,y,rowHeight=0,0,0
    for _,g in ipairs(groups) do
        g.rows=math.max(1,math.ceil(g.count/g.columns))
        local w=g.columns*g.size+(g.columns-1)*GAP; local h=g.rows*g.size+(g.rows-1)*GAP
        if x>0 and x+w>maxWidth then x=0; y=y-rowHeight-8; rowHeight=0 end
        g.x,g.y=x,y; x=x+w+8; rowHeight=math.max(rowHeight,h)
    end
    p.grid:SetSize(maxWidth,-y+rowHeight)
    for _,g in ipairs(groups) do
        for i=g.from,g.from+g.count-1 do
            local cell=p.cells[i]
            if not cell then
                cell=CreateFrame("Frame",nil,p.grid)
                cell.fill=cell:CreateTexture(nil,"ARTWORK"); cell.fill:SetAllPoints()
                cell.edge=cell:CreateTexture(nil,"BACKGROUND"); cell.edge:SetPoint("TOPLEFT",-1,1); cell.edge:SetPoint("BOTTOMRIGHT",1,-1); cell.edge:SetColorTexture(1,1,1,1)
                cell.mark=cell:CreateFontString(nil,"OVERLAY"); cell.mark:SetFont(FT.bodyFont,10,"OUTLINE"); cell.mark:SetPoint("CENTER",0,0)
                p.cells[i]=cell
            end
            cell:SetSize(g.size,g.size)
            local k=Order.Cell(i-g.from,g.count,g.columns,corner)
            local fromBottom,fromRight=math.floor(k/g.columns),k%g.columns
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT",p.grid,"TOPLEFT",g.x+(g.columns-1-fromRight)*(g.size+GAP),g.y-(g.rows-1-fromBottom)*(g.size+GAP))
            local slot=line[i]; local c=BAG_COLORS[slot.bag] or BAG_COLORS[1]
            if slot.item then cell.fill:SetColorTexture(c[1],c[2],c[3],1) else cell.fill:SetColorTexture(c[1]*.35,c[2]*.35,c[3]*.35,1) end
            cell.edge:SetShown(slot.next==true)
            cell.mark:SetText(i==1 and "1" or "")
            cell:Show()
        end
    end
    local combined=self:Combined()
    page.startHeading:SetText(combined and "Where your backpack starts" or "Where each bag starts")
    page.before:SetText(combined and "Before the October 8 update, bags started top left."
        or "Each bag starts in this corner.")
    for i=n+1,#p.cells do p.cells[i]:Hide() end
    p.caption:ClearAllPoints(); p.caption:SetPoint("TOPLEFT",p.grid,"BOTTOMLEFT",0,-8)
    if FT.RefreshDock and page.frame:IsShown() then FT:RefreshDock(page.frame) end
end
local page={}
Order.page=page
function page:Open()
    if not self.frame then
        local hub=FT:HubOf("BagsOrder"); local width=hub and hub.width or 540
        local frame=FT:Window("ForeverToolsBagsOrder","Bag order",width,440); self.frame=frame
        FT:PageInfo(frame,"Bag order","Your bag slots run in one line: backpack, then bags 1 to 4. Pick where it starts, where loot goes, and where Clean Up packs.")
        local hint=FT:Label(frame,"Pick where your bag slots start, where loot goes, and where Clean Up packs. The example shows each choice.",12)
        hint:SetPoint("TOPLEFT",24,-62); hint:SetWidth(width-48); hint:SetTextColor(.66,.59,.48)
        local L,COL=24,280
        local function heading(text,y,icon)
            local h=FT:Label(frame,text,15,true); h:SetPoint("TOPLEFT",L,y); h:SetTextColor(1,.82,0)
            FT:SectionHeading(h,icon,40)
            return h
        end
        self.startHeading=heading("Where your backpack starts",-104,"INV_Misc_Bag_08")
        self.game=FT:QuietButton(frame,"Game's own",COL,26); self.game:SetPoint("TOPLEFT",L,-130)
        self.game:SetScript("OnClick",function() Order:Set("order","game") end)
        FT:Tooltip(self.game,"Game's own","Let the game decide (bottom right since October 8).")
        self.corners={}
        for i,corner in ipairs(CORNERS) do
            local b=FT:QuietButton(frame,cornerText[corner].label,136,26)
            b:SetPoint("TOPLEFT",L+((i-1)%2)*144,-160-math.floor((i-1)/2)*30)
            b:SetScript("OnClick",function() Order:Set("order",corner) end)
            FT:Tooltip(b,"Start: "..cornerText[corner].label,function() return Order:CornerTooltip(corner) end)
            self.corners[corner]=b
        end
        local before=FT:Label(frame,"",12); self.before=before
        before:SetPoint("TOPLEFT",L,-224); before:SetWidth(COL); before:SetTextColor(.66,.59,.48)
        local function pair(key,y,title,options)
            heading(title,y,key=="insert" and "INV_Misc_Coin_02" or "INV_Misc_Note_04")
            self[key]={}
            for i,o in ipairs(options) do
                local b=FT:QuietButton(frame,o[2],136,26); b:SetPoint("TOPLEFT",L+(i-1)*144,y-26)
                if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
                b:SetScript("OnClick",function() Order:Set(key,o[1]) end)
                FT:Tooltip(b,o[2],o[3])
                self[key][o[1]]=b
            end
        end
        local remembered=" A game setting: every character on this profile gets it."
        pair("insert",-266,"New loot goes into",{
            {"backpack","Backpack first","Backpack first, then bag 1, 2... The game's normal way."..remembered},
            {"lastbag","Last bag first","Last bag first, backpack last."..remembered},
        })
        pair("cleanup",-326,"Clean Up packs into",{
            {"lastbag","Last bag first","Clean Up packs toward your last bag. Free slots end in the backpack."..remembered},
            {"backpack","Backpack first","Clean Up packs toward your backpack. Free slots end in the last bag."..remembered},
        })
        local note=FT:Label(frame,"Only the order changes. Items and the bag's look stay.",12)
        note:SetPoint("TOPLEFT",L,-388); note:SetWidth(width-48); note:SetTextColor(.66,.59,.48)
        -- The example, on the right.
        local R=L+COL+26
        local h=FT:Label(frame,"Example",15,true); h:SetPoint("TOPLEFT",R,-104); h:SetTextColor(1,.82,0)
        local p=CreateFrame("Frame",nil,frame); p:SetPoint("TOPLEFT",R,-130); p:SetSize(width-R-24,250)
        p.grid=CreateFrame("Frame",nil,p); p.grid:SetPoint("TOPLEFT")
        p.cells={}
        p.caption=CreateFrame("Frame",nil,p); p.caption:SetSize(width-R-24,110)
        local names={"Backpack","Bag 1","Bag 2","Bag 3","Bag 4"}
        for i,name in ipairs(names) do
            local x,y=((i-1)%2)*84,-math.floor((i-1)/2)*15
            local sq=p.caption:CreateTexture(nil,"ARTWORK"); sq:SetSize(10,10); sq:SetPoint("TOPLEFT",x,y-2)
            local c=BAG_COLORS[i]; sq:SetColorTexture(c[1],c[2],c[3],1)
            local l=FT:Label(p.caption,name,11); l:SetPoint("TOPLEFT",x+14,y); l:SetTextColor(.85,.80,.70)
        end
        local keyText=FT:Label(p.caption,"Bright: items after Clean Up.\n1: backpack's first slot.\nOutline: where loot goes next.",11)
        keyText:SetPoint("TOPLEFT",0,-50); keyText:SetWidth(width-R-24); keyText:SetTextColor(.66,.59,.48)
        self.preview=p
    end
    Order:Refresh(); self.frame:Show()
end
function page:Refresh() Order:Refresh() end
FT:RegisterModule("BagsOrder",page)
FT.BagOrder=Order
