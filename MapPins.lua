local _,FT=...
-- Travel points on the world map (1.8.0, off by default): zeppelins, boats,
-- the tram and portals, plus dungeon and raid entrances.
--   * Switched on in the map's own filter menu (the funnel, top right).
--   * Flight masters: the game's own taxi nodes (C_TaxiMap), drawn by us only
--     on maps where the game doesn't draw them itself.
--   * Our pins are plain frames on the map canvas: drawn only while the map
--     is open, nothing runs while it is closed.
--   * /ft mappoint <kind> <name>: saves where you stand as a point (to fill
--     in Forever's new docks and towers). /ft mappoint list prints them.
local P={}
FT.MapPins=P
local function plain(v) return v~=nil and not (issecretvalue and issecretvalue(v)) end

-- Known points, from the game's own tables (via OpenMap's data, MIT, see
-- THIRD_PARTY_NOTICES.md): {kind, continent, x, y, name, faction}, with x, y in
-- world yards on that continent (0 Eastern Kingdoms, 1 Kalimdor, 2991 Zephras
-- Isle); or with map=uiMapID, x, y on that zone's map (0-1). Dungeons and raids
-- add levels; one entrance can hold several (lines in its tooltip).
P.points={
    {"boat",1,-1005.6,-3841.6,"Boat to Booty Bay"},
    {"boat",0,-14277.7,582.9,"Boat to Ratchet"},
    {"boat",1,-6932.6,-4950.8,"Boat to Powderfuse Port"},
    {"boat",0,-8232.3,-5800.8,"Boat to Steamwheedle Port"},
    {"zeppelin",0,-12464.0,231.6,"Zeppelin to Orgrimmar","Horde"},
    {"zeppelin",1,1360.9,-4631.3,"Zeppelin to Grom'gol","Horde"},
    {"zeppelin",0,-12406.9,211.8,"Zeppelin to Undercity","Horde"},
    {"zeppelin",0,2062.6,235.3,"Zeppelin to Grom'gol","Horde"},
    {"zeppelin",1,1318.1,-4658.0,"Zeppelin to Undercity","Horde"},
    {"zeppelin",0,2062.4,293.0,"Zeppelin to Orgrimmar","Horde"},
    {"boat",0,-3905.2,-585.8,"Boat to Theramore","Alliance"},
    {"boat",1,-4016.4,-4740.6,"Boat to Menethil Harbor","Alliance"},
    {"boat",1,8532.0,1023.7,"Boat to Auberdine","Alliance"},
    {"boat",1,6594.4,759.8,"Boat to Rut'theran Village","Alliance"},
    {"boat",1,-4197.3,3286.6,"Boat to the Feralas coast","Alliance"},
    {"boat",1,-4347.8,2444.4,"Boat to Feathermoon Stronghold","Alliance"},
    {"boat",0,-3709.5,-575.1,"Boat to Southshore, then Auberdine","Alliance"},
    {"boat",0,-1102.6,-554.7,"Boat to Auberdine, then Menethil Harbor","Alliance"},
    {"boat",1,6406.2,823.1,"Boat to Menethil Harbor, then Southshore","Alliance"},
    {"boat",1,6548.3,942.2,"Boat to Stormwind Harbor","Alliance"},
    {"boat",0,-8654.5,1344.4,"Boat to Auberdine","Alliance"},
    {"airship",0,544.8,424.2,"Airship to Zephras Isle","Alliance"},
    {"airship",2991,1848.3,569.1,"Airship to Alterac Mountains","Alliance"},
    {"airship",1,-802.0,366.5,"Airship to Zephras Isle","Horde"},
    {"airship",2991,1952.5,1019.1,"Airship to Mulgore","Horde"},
    {"tram",nil,.764,.512,"Deeprun Tram to Stormwind","Alliance",map=1455},
    {"dungeon",0,-231.0,1571.6,{{"Shadowfang Keep","20-30"}}},
    {"dungeon",0,-8762.4,848.0,{{"Stormwind Stockade","24-32"}}},
    {"dungeon",0,-11207.8,1681.2,{{"Deadmines","17-26"}}},
    {"dungeon",1,-751.1,-2209.2,{{"Wailing Caverns","15-24"}}},
    {"dungeon",1,-4459.4,-1660.2,{{"Razorfen Kraul","29-38"}}},
    {"dungeon",1,4249.1,748.4,{{"Blackfathom Deeps","24-32"}}},
    {"dungeon",0,-6060.2,-2955.0,{{"Uldaman","41-51"}}},
    {"dungeon",0,-5162.7,931.6,{{"Gnomeregan","29-38"}}},
    {"dungeon",0,-10170.1,-3996.0,{{"Sunken Temple","50-60"}}},
    {"dungeon",1,-4662.9,-2535.9,{{"Razorfen Downs","37-46"}}},
    {"dungeon",0,2892.2,-811.3,{{"Scarlet Monastery - Graveyard","30-38"},{"Scarlet Monastery - Library","33-41"},{"Scarlet Monastery - Armory","36-44"},{"Scarlet Monastery - Cathedral","38-46"}}},
    {"dungeon",1,-6790.6,-2891.3,{{"Zul'Farrak","44-54"}}},
    {"raid",0,-7522.5,-1233.0,{{"Lower Blackrock Spire","55-60"},{"Upper Blackrock Spire","59-60"},{"Molten Core","60, raid"},{"Blackwing Lair","60, raid"}}},
    {"dungeon",0,-7178.1,-928.6,{{"Blackrock Depths","52-60"}}},
    {"raid",1,-4753.3,-3752.4,{{"Onyxia's Lair","60, raid"}}},
    {"dungeon",0,1274.8,-2552.6,{{"Scholomance","58-60"}}},
    {"raid",0,-11916.1,-1224.6,{{"Zul'Gurub","60, raid"}}},
    {"dungeon",0,3392.3,-3378.5,{{"Stratholme","58-60"}}},
    {"dungeon",1,-1432.7,2925.0,{{"Maraudon","46-55"}}},
    {"dungeon",1,1816.8,-4423.4,{{"Ragefire Chasm","13-18"}}},
    {"dungeon",1,-3908.0,1130.0,{{"Dire Maul - East","54-60"},{"Dire Maul - West","56-60"},{"Dire Maul - North","56-60"}}},
    {"raid",1,-8114.5,1526.4,{{"Ruins of Ahn'Qiraj","60, raid"},{"Ahn'Qiraj Temple","60, raid"}}},
    {"dungeon",nil,.085,.593,{{"City of Dalaran","28-35"}},map=1416},
    {"dungeon",nil,.213,.278,{{"The Drowned City","35-42"}},map=1434},
    {"dungeon",nil,.386,.332,{{"Blackmaw Hold","55-60"}},map=1447},
    {"dungeon",nil,.753,.141,{{"Alcaz Prison","48-55"}},map=1445},
    {"dungeon",nil,.478,.562,{{"Excavation Site: Wetlands","26-33"}},map=1437},
    {"dungeon",nil,.725,.114,{{"Ruins of Lordaeron","15-22"}},map=1458},
    {"dungeon",nil,.481,.061,{{"Shaper's Terrace","58-60"}},map=1449},
    {"dungeon",nil,.375,.373,{{"Krol'dok Stronghold","40-47"}},map=2548},
    {"dungeon",nil,.277,.479,{{"The Hall of Thanes","13-20"}},map=1455},
}
P.kinds={
    zeppelin={label="Zeppelin",atlas={"Zeppelin","poi-zeppelin","TaxiNode_Horde"},icon="Interface\\TaxiFrame\\UI-Taxi-Icon-Red"},
    airship={label="Airship",atlas={"Zeppelin","poi-zeppelin","TaxiNode_Neutral"},icon="Interface\\TaxiFrame\\UI-Taxi-Icon-Yellow"},
    boat={label="Boat",atlas={"Boat","poi-boat","Vehicle-Boat","TaxiNode_Neutral"},icon="Interface\\TaxiFrame\\UI-Taxi-Icon-Yellow"},
    tram={label="Tram",atlas={"Tram","poi-tram","TaxiNode_Alliance"},icon="Interface\\TaxiFrame\\UI-Taxi-Icon-Green"},
    portal={label="Portal",atlas={"MagePortalHorde","MagePortalAlliance","poi-portal"},icon="Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar"},
    dungeon={label="Dungeon",atlas={"Dungeon","poi-dungeon"},icon="Interface\\Icons\\INV_Misc_Key_10"},
    raid={label="Raid",atlas={"Raid","poi-raid"},icon="Interface\\Icons\\INV_Misc_Key_13"},
    flight={label="Flight master",atlas={"TaxiNode_Neutral","Taxi_Frame_Yellow"},icon="Interface\\TaxiFrame\\UI-Taxi-Icon-Green"},
}
local transport={zeppelin=true,airship=true,boat=true,tram=true,portal=true}

function P:Settings()
    local s=FT.modules.System and FT.modules.System:Settings()
    if not s then return {} end
    for _,key in ipairs({"mapTransport","mapDungeons","mapFlights"}) do
        if type(s[key])~="boolean" then s[key]=false end
    end
    return s
end
-- Points you saved yourself (account data, never in profiles).
function P:Own()
    if type(FT.db.mapPointsOwn)~="table" then FT.db.mapPointsOwn={} end
    return FT.db.mapPointsOwn
end
local function atlasExists(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok,info=pcall(C_Texture.GetAtlasInfo,name)
    return ok and info~=nil
end
function P:SetIcon(texture,kind)
    local k=self.kinds[kind] or self.kinds.dungeon
    if k.found==nil then
        k.found=false
        for _,name in ipairs(k.atlas) do if atlasExists(name) then k.found=name; break end end
    end
    if k.found then texture:SetAtlas(k.found); texture:SetTexCoord(0,1,0,1)
    else texture:SetTexture(k.icon); texture:SetTexCoord(.08,.92,.08,.92) end
end
local function faction()
    local ok,f=pcall(UnitFactionGroup,"player")
    return ok and plain(f) and f or nil
end
local function inside(x,y) return x and y and x>=0 and x<=1 and y>=0 and y<=1 end
-- World yards to a map's 0-1 spot. Which of the two numbers comes first is
-- checked once against a known spot (Ragefire Chasm, inside Orgrimmar).
local function toMap(continent,x,y,mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local function try(a,b)
        local ok,_,pos=pcall(C_Map.GetMapPosFromWorldPos,continent,CreateVector2D(a,b),mapID)
        if ok and pos then local u,v=pos:GetXY(); if inside(u,v) then return u,v end end
    end
    if P.swap==nil then
        local function at(a,b)
            local ok,_,pos=pcall(C_Map.GetMapPosFromWorldPos,1,CreateVector2D(a,b),1454)
            if ok and pos then local u,v=pos:GetXY(); return inside(u,v) end
        end
        if at(1816.8,-4423.4) then P.swap=false elseif at(-4423.4,1816.8) then P.swap=true end
        if P.swap==nil then return end
    end
    if P.swap then return try(y,x) end
    return try(x,y)
end
-- A zone-map point on a bigger map above it (continent, world).
local function fromZone(zone,x,y,mapID)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return end
    local info=C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not info or not (Enum and Enum.UIMapType) or info.mapType==nil or info.mapType>(Enum.UIMapType.Continent or 2) then return end
    local ok,continent,world=pcall(C_Map.GetWorldPosFromMapPos,zone,CreateVector2D(x,y))
    if not ok or not continent or not world then return end
    local ok2,_,pos=pcall(C_Map.GetMapPosFromWorldPos,continent,world,mapID)
    if not ok2 or not pos then return end
    local u,v=pos:GetXY()
    if inside(u,v) then return u,v end
end
local function place(point,mapID)
    if point.map or point[2]==nil then
        local zone=point.map or point[2]
        if zone==mapID then return point[3],point[4] end
        return fromZone(zone,point[3],point[4],mapID)
    end
    return toMap(point[2],point[3],point[4],mapID)
end
function P:Wanted(kind)
    local s=self:Settings()
    if transport[kind] then return s.mapTransport end
    if kind=="flight" then return s.mapFlights end
    return s.mapDungeons
end
function P:Pin(i)
    self.pins=self.pins or {}
    local pin=self.pins[i]
    if pin then return pin end
    local canvas=WorldMapFrame:GetCanvas()
    pin=CreateFrame("Frame",nil,canvas)
    pin:SetSize(20,20); pin:EnableMouse(true)
    -- Right-click still zooms the map out under a pin, the way the map does
    -- it (zoomed in: zoom out; else the map above). Done here, because
    -- letting the click through (SetPassThroughButtons) is protected on the
    -- world map and the game blocked it (1.11.0).
    pin:SetScript("OnMouseUp",function(_,button)
        if button~="RightButton" or not WorldMapFrame then return end
        local scroll=WorldMapFrame.ScrollContainer
        if scroll and scroll.IsAtMinZoom and not scroll:IsAtMinZoom() and scroll.ZoomOut then scroll:ZoomOut()
        elseif WorldMapFrame.NavigateToParentMap then WorldMapFrame:NavigateToParentMap() end
    end)
    pin:SetFrameLevel(canvas:GetFrameLevel()+2100)
    pin.icon=pin:CreateTexture(nil,"OVERLAY"); pin.icon:SetAllPoints()
    pin:SetScript("OnEnter",function(owner)
        GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
        local name=owner.name
        if type(name)=="table" then
            GameTooltip:SetText(P.kinds[owner.kind].label=="Raid" and "Dungeon and raid entrance" or "Dungeon entrance",1,.82,0)
            for _,e in ipairs(name) do GameTooltip:AddDoubleLine(e[1],e[2],1,1,1,.8,.8,.8) end
        else
            GameTooltip:SetText(name or "",1,.82,0)
            if owner.note then GameTooltip:AddLine(owner.note,.8,.8,.8) end
        end
        if owner.own then GameTooltip:AddLine("Saved by you (/ft mappoint)",.6,.6,.6) end
        GameTooltip:Show()
    end)
    pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.pins[i]=pin
    return pin
end
function P:Refresh()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
    local mapID=WorldMapFrame:GetMapID()
    local canvas=WorldMapFrame:GetCanvas()
    local w,h=canvas:GetWidth(),canvas:GetHeight()
    local scale=1/((WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()) or 1)
    local mine,n=faction(),0
    local function show(kind,x,y,name,own,note,size)
        n=n+1
        local pin=self:Pin(n)
        pin.kind,pin.name,pin.own,pin.note=kind,name,own,note
        self:SetIcon(pin.icon,kind)
        pin:SetSize(size or 20,size or 20)
        pin:SetScale(scale)
        pin:ClearAllPoints(); pin:SetPoint("CENTER",canvas,"TOPLEFT",x*w/scale,-y*h/scale)
        pin:Show()
    end
    local function add(point,own)
        if not self:Wanted(point[1]) then return end
        if point[6] and mine and point[6]~=mine then return end
        local x,y=place(point,mapID)
        if x then show(point[1],x,y,point[5],own) end
    end
    if mapID then
        for _,point in ipairs(self.points) do add(point,false) end
        for _,point in ipairs(self:Own()) do add(point,true) end
        -- Flight masters: only where the game doesn't draw them itself.
        if self:Settings().mapFlights and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
            local ok,gameShows=pcall(function() return C_TaxiMap.ShouldMapShowTaxiNodes and C_TaxiMap.ShouldMapShowTaxiNodes(mapID) end)
            if not (ok and gameShows) then
                local okN,nodes=pcall(C_TaxiMap.GetTaxiNodesForMap,mapID)
                local F=Enum and Enum.FlightPathFaction or {}
                for _,node in ipairs(okN and type(nodes)=="table" and nodes or {}) do
                    local mineOK=not mine or not node.faction or (node.faction==F.Horde and mine=="Horde") or (node.faction==F.Alliance and mine=="Alliance") or (node.faction~=F.Horde and node.faction~=F.Alliance)
                    local x,y
                    if node.position then x,y=node.position:GetXY() end
                    if mineOK and inside(x,y) then show("flight",x,y,node.name,false,node.isUndiscovered and "Not discovered yet" or nil,16) end
                end
            end
        end
    end
    for i=n+1,#(self.pins or {}) do self.pins[i]:Hide() end
end
function P:Apply()
    self:Settings()
    self:Hook()
    if WorldMapFrame and WorldMapFrame:IsShown() then self:Refresh() end
end
function P:Toggle(key)
    local s=self:Settings(); s[key]=not s[key]; self:Apply()
    if FT.modules.System and FT.modules.System.Refresh then FT.modules.System:Refresh() end
end
function P:Hook()
    if self.hooked or not WorldMapFrame or not hooksecurefunc then return end
    self.hooked=true
    local function later() if FT.dbReady then P:Refresh() end end
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame,"OnMapChanged",later) end
    if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame,"OnCanvasScaleChanged",later) end
    if WorldMapFrame.OnCanvasSizeChanged then hooksecurefunc(WorldMapFrame,"OnCanvasSizeChanged",later) end
    WorldMapFrame:HookScript("OnShow",later)
    -- The map's filter menu (funnel icon): our switches at the bottom.
    if Menu and Menu.ModifyMenu then
        Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING",function(_,root)
            if not FT.dbReady then return end
            root:CreateDivider()
            root:CreateTitle("ForeverTools")
            for _,e in ipairs({{"mapTransport","Boats, zeppelins and tram"},{"mapDungeons","Dungeon and raid entrances"},{"mapFlights","Flight masters"}}) do
                root:CreateCheckbox(e[2],function() return P:Settings()[e[1]] end,function() P:Toggle(e[1]) end)
            end
            P:GatherMateMenu(root)
        end)
    end
end
-- GatherMate in the map's filter menu (System > Minimap > GatherMate in the
-- map menu, off): each kind (herbs, minerals, fishing, treasure) on or off,
-- and hover one for each node of it (Copper Vein, Peacebloom...). Uses
-- GatherMate's own settings ("Show" per kind and its node filter), so its
-- options window shows the same and the minimap follows too.
local GM_TYPES={{"Herb Gathering","Herbs"},{"Mining","Minerals"},{"Fishing","Fishing"},{"Treasure","Treasure"}}
local gmNodes,gmNodesAt={},{}
local function gatherMate()
    local gm=rawget(_G,"GatherMate2")
    if type(gm)~="table" or type(gm.db)~="table" or type(gm.db.profile)~="table" then return nil end
    return gm
end
-- The nodes of a kind: every one in GatherMate's data, plus the Classic
-- ones it knows. Sorted by name. Built at most once a minute.
local function nodesOf(gm,kind)
    local t=GetTime and GetTime() or 0
    if gmNodes[kind] and t-(gmNodesAt[kind] or 0)<60 then return gmNodes[kind] end
    local names=gm.reverseNodeIDs and gm.reverseNodeIDs[kind] or {}
    local ids={}
    local data=gm.gmdbs and gm.gmdbs[kind]
    if type(data)=="table" then
        for _,zone in pairs(data) do
            if type(zone)=="table" then for _,id in pairs(zone) do if type(id)=="number" then ids[id]=true end end end
        end
    end
    local exp=gm.nodeExpansion and gm.nodeExpansion[kind]
    if type(exp)=="table" then for id,e in pairs(exp) do if e==1 then ids[id]=true end end end
    local list={}
    for id in pairs(ids) do if type(names[id])=="string" then list[#list+1]={id=id,name=names[id]} end end
    table.sort(list,function(a,b) return a.name<b.name end)
    gmNodes[kind],gmNodesAt[kind]=list,t
    return list
end
local function gmChanged(gm)
    if gm.SendMessage then pcall(gm.SendMessage,gm,"GatherMate2ConfigChanged") end
end
function P:GatherMateMenu(root)
    -- On unless turned off; only when GatherMate is loaded on this character.
    if P:Settings().mapGatherMate==false then return end
    local gm=gatherMate(); if not gm then return end
    local db=gm.db.profile
    if type(db.show)~="table" or type(db.filter)~="table" then return end
    root:CreateDivider()
    root:CreateTitle("GatherMate")
    for _,k in ipairs(GM_TYPES) do
        local kind,label=k[1],k[2]
        -- Ticked = shown on your map now (GatherMate's "Only with profession"
        -- hides herbs on a miner: that counts as off). On = "Always".
        local function shown()
            if type(gm.Visible)=="table" and gm.Visible[kind]~=nil then return gm.Visible[kind]==true end
            return db.show[kind]=="always"
        end
        local item=root:CreateCheckbox(label,shown,function()
            db.show[kind]=shown() and "never" or "always"
            gmChanged(gm)
        end)
        local nodes=nodesOf(gm,kind)
        if #nodes>0 and item.CreateButton then
            local filter=db.filter[kind]
            item:CreateButton("Show all",function() for _,n in ipairs(nodes) do filter[n.id]=true end; gmChanged(gm); return MenuResponse and MenuResponse.Refresh end)
            item:CreateButton("Hide all",function() for _,n in ipairs(nodes) do filter[n.id]=false end; gmChanged(gm); return MenuResponse and MenuResponse.Refresh end)
            item:CreateDivider()
            for _,n in ipairs(nodes) do
                item:CreateCheckbox(n.name,function() return filter[n.id]~=false end,function() filter[n.id]=not (filter[n.id]~=false); gmChanged(gm) end)
            end
            if item.SetScrollMode then pcall(item.SetScrollMode,item,400) end
        end
    end
end
-- /ft mappoint <kind> <name> | list | undo
function P:Command(text)
    text=text or ""
    local word,rest=text:match("^(%S*)%s*(.-)$")
    word=(word or ""):lower()
    local own=self:Own()
    if word=="list" then
        if #own==0 then print("|cffffd100FT map points|r none saved yet. Stand at a dock or entrance: /ft mappoint boat Boat to Auberdine") return end
        for _,p in ipairs(own) do print(('{"%s",%d,%.3f,%.3f,"%s"},'):format(p[1],p[2],p[3],p[4],p[5])) end
        return
    elseif word=="undo" then
        local p=table.remove(own); print("|cffffd100FT map points|r "..(p and ("removed: "..p[5]) or "nothing to remove")); self:Refresh(); return
    end
    if not self.kinds[word] or rest=="" then
        print("|cffffd100FT map points|r /ft mappoint <zeppelin|airship|boat|tram|portal|dungeon|raid> <name>  ·  /ft mappoint list  ·  /ft mappoint undo")
        return
    end
    local mapID=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos=mapID and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID,"player")
    local x,y=nil,nil
    if pos then x,y=pos:GetXY() end
    if not (plain(mapID) and plain(x) and plain(y) and x and y) then print("|cffffd100FT map points|r your position can't be read here.") return end
    own[#own+1]={word,mapID,math.floor(x*1000+.5)/1000,math.floor(y*1000+.5)/1000,rest}
    print(("|cffffd100FT map points|r saved %s \"%s\" at %.1f, %.1f (map %d)."):format(word,rest,x*100,y*100,mapID))
    self:Refresh()
end
FT:RegisterModule("MapPins",P)
local events=CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if not FT.dbReady then return end
    if event=="PLAYER_LOGIN" or name=="Blizzard_WorldMap" then P:Apply() end
end)
