--[[
    VELION DISTRICT HUB V2.1 - MINI HUD EDITION
    For Roblox Violence District - client-side utility module.
    Clean, readable Luau. No external UI libraries, telemetry or extra loaders.
    IMPORTANT: Does not spoof server state or grant server-side immunity.
    Objective detection uses names/prompts because map internals may change.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui",10)
if not playerGui then warn("[Velion VD] PlayerGui unavailable"); return end

local environment = (type(getgenv)=="function" and getgenv()) or _G
if type(environment.VelionVDCleanup)=="function" then
    pcall(environment.VelionVDCleanup)
end
for _,name in ipairs({"VelionDistrictHub","VelionDistrictHubV2"}) do
    local previousGui=playerGui:FindFirstChild(name)
    if previousGui then previousGui:Destroy() end
end

local state = {
    alive=true, playerESP=false, objectiveESP=false,
    fullbright=false, noFog=false, noClip=false,
    speed=false, speedValue=24, fov=70,
    killerAlert=true, offscreenESP=true, scanProgress="Starting",
    expanded=false, activeTab="Dashboard",
    identifiedObjectives=0, unknownRoles=0,
}
local palette = {
    bg=Color3.fromRGB(12,15,28),
    side=Color3.fromRGB(18,22,39),
    surface=Color3.fromRGB(31,36,59),
    accent=Color3.fromRGB(155,117,249),
    green=Color3.fromRGB(51,180,137),
    white=Color3.fromRGB(241,242,250),
    muted=Color3.fromRGB(164,170,191),
    yellow=Color3.fromRGB(248,186,68),
    red=Color3.fromRGB(249,90,113)
}
local connections = {}
local function connect(signal,callback)
    local connection=signal:Connect(callback)
    connections[#connections+1]=connection
    return connection
end
local function create(class,parent,props)
    local item=Instance.new(class)
    for name,value in pairs(props or {}) do item[name]=value end
    item.Parent=parent
    return item
end
local function round(item,radius)
    create("UICorner",item,{CornerRadius=UDim.new(0,radius or 8)})
end
local function label(parent,text,x,y,w,h,size,color)
    return create("TextLabel",parent,{
        BackgroundTransparency=1,
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        Text=text,TextColor3=color or palette.white,
        TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center,
        TextWrapped=true,Font=Enum.Font.Gotham,TextSize=size or 12
    })
end
local function button(parent,text,x,y,w,h)
    local item=create("TextButton",parent,{
        Text=text,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),
        BackgroundColor3=palette.surface,
        TextColor3=palette.white,Font=Enum.Font.GothamBold,
        TextSize=12,AutoButtonColor=true,BorderSizePixel=0
    })
    round(item,8)
    return item
end

-- ============================================================
-- MINI HUD UI: collapsible, responsive, game-first overlay.
-- No external UI library, no extra render loops for decoration.
-- ============================================================
local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictHubV2",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=800
})
local panel=create("Frame",gui,{
    Name="MiniHUD",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-18,0,76),Size=UDim2.fromOffset(310,135),
    BackgroundColor3=palette.bg,BorderSizePixel=0,
    Active=true,ClipsDescendants=true
})
round(panel,13)
local frameStroke=create("UIStroke",panel,{
    Color=palette.accent,Thickness=1.25,Transparency=.15
})
local viewport=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
    or Vector2.new(1280,720)
local uiScale=create("UIScale",panel,{
    Scale=math.clamp(viewport.X/580,.70,1)
})
if viewport.X>=580 then uiScale.Scale=1 end

local header=create("Frame",panel,{
    Name="DragHandle",Size=UDim2.new(1,0,0,43),
    BackgroundColor3=palette.side,BorderSizePixel=0,Active=true
})
round(header,12)
local headerBottom=create("Frame",header,{
    Position=UDim2.new(0,0,1,-9),Size=UDim2.new(1,0,0,9),
    BackgroundColor3=palette.side,BorderSizePixel=0
})
local dragHandle=create("Frame",header,{
    Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-91,1,0),
    BackgroundTransparency=1,Active=true
})
local title=label(dragHandle,"VELION  /  DISTRICT",14,2,206,36,13)
title.Font=Enum.Font.GothamBold
local version=label(header,"V2.1",0,0,45,43,10,palette.muted)
version.Position=UDim2.new(1,-127,0,0)
local minimize=button(header,"+",0,8,30,27)
minimize.Position=UDim2.new(1,-76,0,8)
local close=button(header,"X",0,8,29,27)
close.Position=UDim2.new(1,-38,0,8)
close.BackgroundColor3=Color3.fromRGB(64,35,53)

local hudBody=create("Frame",panel,{
    Position=UDim2.fromOffset(0,44),Size=UDim2.fromOffset(310,91),
    BackgroundTransparency=1
})
local hudOverview=label(hudBody,"PLAYERS  --   |   OBJECTIVES  --",
    13,3,289,20,11,palette.white)
hudOverview.Font=Enum.Font.GothamBold
local hudThreat=label(hudBody,"KILLER: checking teams...",
    13,25,289,21,10,palette.muted)
local quickESP=button(hudBody,"PLAYER ESP  OFF",13,56,137,29)
local quickAlert=button(hudBody,"ALERT  ON",160,56,137,29)
quickESP.TextSize=10
quickAlert.TextSize=10

local expandedBody=create("Frame",panel,{
    Name="DashboardBody",Position=UDim2.fromOffset(0,44),
    Size=UDim2.fromOffset(535,400),
    BackgroundTransparency=1,Visible=false
})
local sidebar=create("Frame",expandedBody,{
    Position=UDim2.fromOffset(11,9),Size=UDim2.fromOffset(132,320),
    BackgroundColor3=palette.side,BorderSizePixel=0
})
round(sidebar,10)
local contents=create("Frame",expandedBody,{
    Position=UDim2.fromOffset(154,9),Size=UDim2.fromOffset(369,320),
    BackgroundColor3=palette.side,BorderSizePixel=0
})
round(contents,10)
local footer=label(expandedBody,
    "Detecting players and map...  |  Right Ctrl: show/hide",
    14,338,500,31,11,palette.muted)

local pages,nav={},{}
local function makePage(name)
    local page=create("Frame",contents,{
        Name=name,Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Visible=false
    })
    pages[name]=page
    return page
end
local dashboard=makePage("Dashboard")
local visual=makePage("ESP")
local playerPage=makePage("Movement")
local objectivesPage=makePage("Objectives")
local settingsPage=makePage("Settings")
local navOrder={"Dashboard","ESP","Movement","Objectives","Settings"}
local function choosePage(name)
    state.activeTab=name
    for tab,page in pairs(pages) do page.Visible=(tab==name) end
    for tab,item in pairs(nav) do
        item.BackgroundColor3=tab==name and palette.accent
            or palette.surface
        item.TextColor3=tab==name and palette.white or palette.muted
    end
end
for i,name in ipairs(navOrder) do
    local item=button(sidebar,name,8,11+(i-1)*61,116,49)
    item.TextXAlignment=Enum.TextXAlignment.Left
    create("UIPadding",item,{PaddingLeft=UDim.new(0,12)})
    nav[name]=item
    connect(item.MouseButton1Click,function() choosePage(name) end)
end
local function sectionTitle(page,name)
    local t=label(page,name,14,9,340,27,14,palette.white)
    t.Font=Enum.Font.GothamBold
end
sectionTitle(dashboard,"DASHBOARD")
sectionTitle(visual,"VISUAL & ESP")
sectionTitle(playerPage,"MOVEMENT")
sectionTitle(objectivesPage,"MAP OBJECTIVES")
sectionTitle(settingsPage,"HUD SETTINGS")

local refreshQuick=function() end
local function toggle(parent,name,y,get,set)
    local control=button(parent,name,13,y,342,39)
    control.TextXAlignment=Enum.TextXAlignment.Left
    create("UIPadding",control,{PaddingLeft=UDim.new(0,12)})
    local indicator=label(control,"OFF",270,0,60,39,11,palette.muted)
    indicator.TextXAlignment=Enum.TextXAlignment.Right
    indicator.Font=Enum.Font.GothamBold
    local function redraw()
        local active=get()
        control.BackgroundColor3=active
            and Color3.fromRGB(38,66,66) or palette.surface
        indicator.Text=active and "ON" or "OFF"
        indicator.TextColor3=active and palette.green or palette.muted
    end
    connect(control.MouseButton1Click,function()
        set(not get())
        redraw()
        refreshQuick()
    end)
    redraw()
    return redraw
end

local function keepOnScreen()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local vw,vh=cam.ViewportSize.X,cam.ViewportSize.Y
    local width=(state.expanded and 535 or 310)*uiScale.Scale
    local right=panel.AbsolutePosition.X+panel.AbsoluteSize.X
    if right<=0 then right=vw-18 end
    right=math.clamp(right,math.min(width+6,vw-7),vw-7)
    local top=math.clamp(panel.AbsolutePosition.Y,6,math.max(6,vh-44))
    panel.Position=UDim2.fromOffset(right,top)
end
local activeTween=nil
local function setExpanded(open)
    if activeTween then activeTween:Cancel() end
    state.expanded=open
    hudBody.Visible=not open
    expandedBody.Visible=open
    minimize.Text=open and "-" or "+"
    title.Text=open and "VELION  /  VIOLENCE DISTRICT"
        or "VELION  /  DISTRICT"
    local newSize=open and UDim2.fromOffset(535,444)
        or UDim2.fromOffset(310,135)
    activeTween=TweenService:Create(panel,
        TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=newSize}
    )
    activeTween:Play()
    -- Keep the expanded window on-screen when switching sizes.
    task.defer(keepOnScreen)
end
connect(minimize.MouseButton1Click,function()
    setExpanded(not state.expanded)
end)

local restore=button(gui,"V",0,0,38,35)
restore.Position=UDim2.new(1,-52,0,77)
restore.Visible=false
restore.BackgroundColor3=palette.accent
connect(restore.MouseButton1Click,function()
    panel.Visible=true
    restore.Visible=false
end)


local lightingOriginal={
    Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,
    Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,
    FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,
    GlobalShadows=Lighting.GlobalShadows
}
local atmosphereOriginal=setmetatable({}, {__mode="k"})
local function updateLighting()
    Lighting.Brightness=state.fullbright and 3 or lightingOriginal.Brightness
    Lighting.ClockTime=state.fullbright and 14 or lightingOriginal.ClockTime
    Lighting.Ambient=state.fullbright and Color3.fromRGB(235,235,235)
        or lightingOriginal.Ambient
    Lighting.OutdoorAmbient=state.fullbright and Color3.fromRGB(235,235,235)
        or lightingOriginal.OutdoorAmbient
    if state.fullbright then
        Lighting.GlobalShadows=false
    else
        Lighting.GlobalShadows=lightingOriginal.GlobalShadows
    end
    Lighting.FogEnd=state.noFog and 100000 or lightingOriginal.FogEnd
    Lighting.FogStart=state.noFog and 0 or lightingOriginal.FogStart
    for _,child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            if not atmosphereOriginal[child] then
                atmosphereOriginal[child]={
                    Density=child.Density,Haze=child.Haze,Glare=child.Glare
                }
            end
            local original=atmosphereOriginal[child]
            child.Density=state.noFog and 0 or original.Density
            child.Haze=state.noFog and 0 or original.Haze
            child.Glare=state.noFog and 0 or original.Glare
        end
    end
end

local playerVisuals={}
local objectiveVisuals={}
local originalsCollision=setmetatable({}, {__mode="k"})
local originalWalkSpeed=setmetatable({}, {__mode="k"})
local originalFOV=Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70
local function gameValue(object,name)
    if not object then return nil end
    local value=object:GetAttribute(name)
    if value~=nil then return value end
    local child=object:FindFirstChild(name)
    if child and child:IsA("ValueBase") then return child.Value end
    return nil
end
local maskNames={
    Richard="Rooster",Tony="Tiger",Brandon="Panther",Cobra="Cobra",
    Richter="Rat",Rabbit="Rabbit",Alex="Chainsaw"
}
local function maskLabel(other)
    local raw=gameValue(other,"Mask") or gameValue(other.Character,"Mask")
    if raw==nil then return nil end
    for k,v in pairs(maskNames) do
        if tostring(raw):lower()==k:lower() then return v end
    end
    return tostring(raw)
end
local function roleOf(other)
    local character=other.Character
    -- Convert missing attributes to empty strings: ipairs would otherwise
    -- stop at the first nil and skip real Team/character attributes.
    local fields={
        tostring(other:GetAttribute("Role") or ""),
        tostring(other:GetAttribute("role") or ""),
        tostring(other:GetAttribute("Team") or ""),
        tostring(other:GetAttribute("TeamRole") or ""),
        tostring(character and character:GetAttribute("Role") or ""),
        tostring(other.Team and other.Team.Name or "")
    }
    for _,value in ipairs(fields) do
        local s=tostring(value or ""):lower()
        if s:find("killer",1,true) or s:find("hunter",1,true) then
            return "Killer",palette.red
        elseif s:find("surviv",1,true) or s:find("innocent",1,true) then
            return "Survivor",palette.green
        end
    end
    return "Unknown",palette.accent
end
local function removePlayerVisual(other)
    local v=playerVisuals[other]
    if not v then return end
    if v.highlight then v.highlight:Destroy() end
    if v.billboard then v.billboard:Destroy() end
    if v.pointer then v.pointer:Destroy() end
    playerVisuals[other]=nil
end
local function ensurePlayerVisual(other)
    if other==player or not state.playerESP then
        removePlayerVisual(other);return
    end
    local character=other.Character
    local head=character and character:FindFirstChild("Head")
    if not head then
        removePlayerVisual(other);return
    end
    local existing=playerVisuals[other]
    if existing and existing.character~=character then
        removePlayerVisual(other)
        existing=nil
    end
    if not existing then
        local highlight=create("Highlight",Workspace.CurrentCamera or Workspace,{
            Name="VelionVDPlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=.82,OutlineTransparency=0
        })
        local billboard=create("BillboardGui",playerGui,{
            Name="VelionVDPlayerTag",Adornee=head,
            AlwaysOnTop=true,Size=UDim2.fromOffset(205,62),
            StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
            MaxDistance=650,ResetOnSpawn=false
        })
        local textLabel=label(billboard,"",0,0,205,62,11)
        textLabel.TextXAlignment=Enum.TextXAlignment.Center
        textLabel.TextStrokeTransparency=.25
        local pointer=label(gui,"",0,0,185,43,11,palette.red)
        pointer.TextXAlignment=Enum.TextXAlignment.Center
        pointer.TextStrokeTransparency=.2
        pointer.Visible=false
        existing={character=character,highlight=highlight,
            billboard=billboard,text=textLabel,pointer=pointer}
        playerVisuals[other]=existing
    end
    local role,color=roleOf(other)
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=character:FindFirstChild("HumanoidRootPart")
    local distance=(root and targetRoot)
        and math.floor((root.Position-targetRoot.Position).Magnitude) or nil
    local isHooked=gameValue(character,"IsHooked")==true
    local isKnocked=gameValue(character,"Knocked")==true
    local isChased=gameValue(character,"IsChased")==true
    if isHooked then color=Color3.fromRGB(255,170,196)
    elseif isKnocked then color=palette.yellow end
    local selectedKiller=gameValue(other,"SelectedKiller")
    local nick=(role=="Killer" and selectedKiller)
        and tostring(selectedKiller) or other.DisplayName
    local mask=role=="Killer" and maskLabel(other) or nil
    local status=isHooked and "HOOKED"
        or (isKnocked and "KNOCKED" or (isChased and "CHASED" or nil))
    existing.highlight.FillColor=color
    existing.highlight.OutlineColor=color
    existing.text.TextColor3=color
    existing.text.Text=nick.." ["..role.."]"
        ..(distance and ("\n"..distance.." studs") or "")
        ..(mask and ("\nMask: "..mask) or "")
        ..(status and ("\n"..status) or "")
    local cam=Workspace.CurrentCamera
    if not cam or not state.offscreenESP or
        (not isChased and role~="Killer") or not targetRoot then
        existing.pointer.Visible=false
    else
        local pos,onScreen=cam:WorldToViewportPoint(targetRoot.Position)
        existing.pointer.Visible=not onScreen
        if not onScreen then
            local viewport=cam.ViewportSize
            local center=Vector2.new(viewport.X/2,viewport.Y/2)
            local direction=Vector2.new(pos.X,pos.Y)-center
            if pos.Z<0 then direction=-direction end
            if direction.Magnitude<.01 then direction=Vector2.new(1,0) end
            local maxScale=math.min((center.X-100)/math.max(math.abs(direction.X),1),
                (center.Y-60)/math.max(math.abs(direction.Y),1))
            local point=center+direction*math.clamp(maxScale,0,1)
            existing.pointer.Position=UDim2.fromOffset(point.X-92,point.Y-21)
            existing.pointer.Text=nick.." ("..role..")"
                ..(distance and ("\n"..distance.." studs") or "")
            existing.pointer.TextColor3=color
        end
    end
end

local objectiveKinds={
    {key="generator",title="GENERATOR",color=Color3.fromRGB(150,0,200)},
    {key="palletwrong",title="PALLET",color=Color3.fromRGB(74,255,181)},
    {key="pallet",title="PALLET",color=Color3.fromRGB(74,255,181)},
    {key="window",title="WINDOW",color=Color3.fromRGB(74,255,181)},
    {key="hook",title="HOOK",color=Color3.fromRGB(132,255,169)},
    {key="gate",title="GATE",color=Color3.fromRGB(255,255,255)}
}
local function classify(candidate)
    local name=candidate.Name:lower()
    if candidate:IsA("ProximityPrompt") then
        name=name.." "..candidate.ActionText:lower()
            .." "..candidate.ObjectText:lower()
    end
    for _,definition in ipairs(objectiveKinds) do
        if name:find(definition.key,1,true) then return definition end
    end
    return nil
end
local function resolveObjective(candidate,kind)
    -- Prefer the actual named object instead of its possibly huge Map model.
    if candidate:IsA("Model") then
        local base=candidate.PrimaryPart
            or candidate:FindFirstChildWhichIsA("BasePart",true)
        if base then return candidate,base end
    elseif candidate:IsA("BasePart") then
        local parent=candidate.Parent
        if parent and parent:IsA("Model") and classify(parent) then
            return parent,parent.PrimaryPart or candidate
        end
        return candidate,candidate
    elseif candidate:IsA("ProximityPrompt") then
        local parent=candidate.Parent
        if parent and parent:IsA("BasePart") then
            return parent,parent
        end
    end
    return nil,nil
end
local function considerObjective(candidate)
    if not state.alive or not candidate.Parent then return end
    local map=Workspace:FindFirstChild("Map")
    if not map or not candidate:IsDescendantOf(map) then return end
    local kind=classify(candidate)
    if not kind then return end
    local obj,part=resolveObjective(candidate,kind)
    if not obj or not part or objectiveVisuals[obj] then return end
    if state.identifiedObjectives>=90 then return end
    local billboard=create("BillboardGui",playerGui,{
        Name="VelionVDObjective",Adornee=part,
        Size=UDim2.fromOffset(168,26),AlwaysOnTop=true,
        MaxDistance=600,Enabled=state.objectiveESP,
        StudsOffsetWorldSpace=Vector3.new(0,3.2,0)
    })
    local tag=label(billboard,kind.title,0,0,168,26,12,kind.color)
    tag.TextStrokeTransparency=.2
    tag.TextXAlignment=Enum.TextXAlignment.Center
    objectiveVisuals[obj]={gui=billboard,kind=kind,part=part,text=tag}
    state.identifiedObjectives+=1
end
local function refreshObjectiveVisibility()
    for object,v in pairs(objectiveVisuals) do
        if object.Parent and v.part.Parent then
            v.gui.Enabled=state.objectiveESP
            if v.kind.key=="generator" then
                local percent=tonumber(gameValue(object,"RepairProgress")
                    or gameValue(object,"Progress"))
                if percent then
                    local cp=math.clamp(percent,0,100)
                    v.text.Text=string.format("GENERATOR %.1f%%",cp)
                    v.text.TextColor3=v.kind.color:Lerp(
                        Color3.fromRGB(60,220,100),cp/100)
                else
                    v.text.Text="GENERATOR (progress unknown)"
                end
            end
        else
            v.gui:Destroy()
            objectiveVisuals[object]=nil
            state.identifiedObjectives=math.max(0,state.identifiedObjectives-1)
        end
    end
end

-- Scan once in small batches, then follow newly spawned objects.
local scanGeneration=0
local function startObjectiveScan()
    scanGeneration+=1
    local generation=scanGeneration
    task.spawn(function()
        state.scanProgress="Enumerating map..."
        local map=Workspace:FindFirstChild("Map")
        if not map then
            state.scanProgress="Workspace.Map not found"
            return
        end
        local objects=map:GetDescendants()
        state.scanProgress="Analyzing Map: "..#objects.." objects"
        for i,item in ipairs(objects) do
            if not state.alive or generation~=scanGeneration then return end
            considerObjective(item)
            if i%90==0 then task.wait() end
        end
        state.scanProgress="Complete"
    end)
end
connect(Workspace.DescendantAdded,considerObjective)
connect(Workspace.ChildAdded,function(item)
    if state.alive and item.Name=="Map" then
        task.defer(startObjectiveScan)
    end
end)
connect(Workspace.DescendantRemoving,function(item)
    local visual=objectiveVisuals[item]
    if visual then
        visual.gui:Destroy()
        objectiveVisuals[item]=nil
        state.identifiedObjectives=math.max(0,state.identifiedObjectives-1)
    end
end)

local function setNoClip(active)
    state.noClip=active
    if not active then
        for part,wasCollidable in pairs(originalsCollision) do
            if part.Parent then
                pcall(function() part.CanCollide=wasCollidable end)
            end
            originalsCollision[part]=nil
        end
    end
end
local function updateNoClip()
    if not state.noClip then return end
    local character=player.Character
    if not character then return end
    for _,item in ipairs(character:GetDescendants()) do
        if item:IsA("BasePart") then
            if originalsCollision[item]==nil then
                originalsCollision[item]=item.CanCollide
            end
            if item.CanCollide then item.CanCollide=false end
        end
    end
end
local function updateSpeed()
    if not state.speed then return end
    local character=player.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health>0 then
        if originalWalkSpeed[hum]==nil then
            originalWalkSpeed[hum]=hum.WalkSpeed
        end
        if hum.WalkSpeed~=state.speedValue then
            hum.WalkSpeed=state.speedValue
        end
    end
end
local function cameraFov()
    local camera=Workspace.CurrentCamera
    if camera then camera.FieldOfView=state.fov end
end
local function setSpeed(value)
    state.speed=value
    if not value then
        for hum,original in pairs(originalWalkSpeed) do
            if hum.Parent then
                pcall(function() hum.WalkSpeed=original end)
            end
            originalWalkSpeed[hum]=nil
        end
    end
end

-- ============================================================
-- MENU CONTROLS (all wired to the existing V2 game systems)
-- ============================================================
local refreshPlayerESP=toggle(visual,"Player ESP",45,
    function() return state.playerESP end,
    function(value)
        state.playerESP=value
        if not value then
            for other in pairs(playerVisuals) do removePlayerVisual(other) end
        end
    end)
local refreshObjectiveESP=toggle(visual,"Objective ESP",90,
    function() return state.objectiveESP end,
    function(value)
        state.objectiveESP=value
        refreshObjectiveVisibility()
    end)
toggle(visual,"Fullbright",135,
    function() return state.fullbright end,
    function(value) state.fullbright=value;updateLighting() end)
toggle(visual,"No Fog",180,
    function() return state.noFog end,
    function(value) state.noFog=value;updateLighting() end)
local fovButton=button(visual,"Camera FOV: 70",13,225,342,39)
connect(fovButton.MouseButton1Click,function()
    local values={[70]=85,[85]=100,[100]=70}
    state.fov=values[state.fov] or 70
    fovButton.Text="Camera FOV: "..state.fov
    cameraFov()
end)

-- Movement and role alerts
toggle(playerPage,"NoClip",45,
    function() return state.noClip end,setNoClip)
toggle(playerPage,"Speed Assist",90,
    function() return state.speed end,setSpeed)
local speedButton=button(playerPage,"Speed Value: 24",13,135,342,39)
connect(speedButton.MouseButton1Click,function()
    local values={[24]=28,[28]=32,[32]=20,[20]=24}
    state.speedValue=values[state.speedValue] or 24
    speedButton.Text="Speed Value: "..state.speedValue
end)
local refreshAlert=toggle(playerPage,"Killer Proximity Alert",180,
    function() return state.killerAlert end,
    function(value) state.killerAlert=value end)
toggle(playerPage,"Off-screen ESP Indicators",225,
    function() return state.offscreenESP end,
    function(value) state.offscreenESP=value end)

-- Dashboard summary + actionable quick settings
local homeCounts=label(dashboard,"0 players   |   0 objectives",
    15,52,341,42,17,palette.white)
homeCounts.Font=Enum.Font.GothamBold
local homeKiller=label(dashboard,"Killer: not detected",
    15,98,341,29,12,palette.muted)
local homeSkill=label(dashboard,"Skill Check: inactive",
    15,128,341,45,11,palette.muted)
local dashboardESP=toggle(dashboard,"Player ESP",184,
    function() return state.playerESP end,
    function(value)
        state.playerESP=value
        if not value then
            for other in pairs(playerVisuals) do removePlayerVisual(other) end
        end
        refreshPlayerESP()
    end)
local dashboardObjectives=toggle(dashboard,"Objective ESP",230,
    function() return state.objectiveESP end,
    function(value)
        state.objectiveESP=value
        refreshObjectiveVisibility()
        refreshObjectiveESP()
    end)
local dashboardExtras=button(dashboard,"OPEN MAP OBJECTIVES",13,275,342,31)
connect(dashboardExtras.MouseButton1Click,function()
    choosePage("Objectives")
end)

-- Objectives: live scanner, generator progress ESP and skill-check monitor
local refreshButton=button(objectivesPage,"REFRESH MAP OBJECTIVES",13,45,342,39)
connect(refreshButton.MouseButton1Click,startObjectiveScan)
local objectiveInfo=label(objectivesPage,"Scanning Workspace.Map...",
    15,98,339,104,12,palette.muted)
local skillInfo=label(objectivesPage,
    "Skill Check: waiting for SkillCheckPromptGui",
    15,211,339,88,11,palette.muted)

-- Settings are real working actions; no decorative fake switches
local scaleButton=button(settingsPage,"HUD SCALE: 100%",13,45,342,40)
local scaleSteps={1,.90,.80}
local scaleIndex=1
connect(scaleButton.MouseButton1Click,function()
    scaleIndex=scaleIndex%#scaleSteps+1
    local cam=Workspace.CurrentCamera
    local responsive=cam and math.clamp(cam.ViewportSize.X/580,.70,1)
        or 1
    if cam and cam.ViewportSize.X>=580 then responsive=1 end
    uiScale.Scale=scaleSteps[scaleIndex]*responsive
    scaleButton.Text="HUD SCALE: "..math.floor(scaleSteps[scaleIndex]*100).."%"
    task.defer(keepOnScreen)
end)
local resetButton=button(settingsPage,"RESET HUD POSITION",13,93,342,40)
connect(resetButton.MouseButton1Click,function()
    panel.Position=UDim2.new(1,-18,0,76)
    task.defer(keepOnScreen)
end)
local scanButton=button(settingsPage,"RESCAN MAP",13,141,342,40)
connect(scanButton.MouseButton1Click,startObjectiveScan)
local collapseButton=button(settingsPage,"RETURN TO MINI HUD",13,189,342,40)
connect(collapseButton.MouseButton1Click,function()
    setExpanded(false)
end)
label(settingsPage,
    "Right Ctrl: hide / show  |  Close: restore settings\n"
    .."HUD defaults to compact mode. No external GUI assets.",
    15,240,337,64,11,palette.muted)

refreshQuick=function()
    quickESP.Text="PLAYER ESP  "..(state.playerESP and "ON" or "OFF")
    quickESP.BackgroundColor3=state.playerESP
        and Color3.fromRGB(38,66,66) or palette.surface
    quickAlert.Text="ALERT  "..(state.killerAlert and "ON" or "OFF")
    quickAlert.BackgroundColor3=state.killerAlert
        and Color3.fromRGB(38,66,66) or palette.surface
    refreshPlayerESP()
    refreshObjectiveESP()
    refreshAlert()
    dashboardESP()
    dashboardObjectives()
end
connect(quickESP.MouseButton1Click,function()
    state.playerESP=not state.playerESP
    if not state.playerESP then
        for other in pairs(playerVisuals) do removePlayerVisual(other) end
    end
    refreshQuick()
end)
connect(quickAlert.MouseButton1Click,function()
    state.killerAlert=not state.killerAlert
    refreshQuick()
end)
refreshQuick()
choosePage("Dashboard")


local alert=label(gui,"",0,0,460,40,16,palette.red)
alert.Font=Enum.Font.GothamBold
alert.TextXAlignment=Enum.TextXAlignment.Center
alert.Position=UDim2.new(.5,-230,0,8)

local function estimateNextKiller()
    local candidates=Players:GetPlayers()
    table.sort(candidates,function(a,b)
        local ax=gameValue(a,"AllowKiller")==true
        local bx=gameValue(b,"AllowKiller")==true
        if ax~=bx then return ax end
        return (tonumber(gameValue(a,"KillerChance")) or 0)>
            (tonumber(gameValue(b,"KillerChance")) or 0)
    end)
    return candidates[1] and candidates[1].DisplayName or "unknown"
end
local function checkSkillUi()
    local prompt=playerGui:FindFirstChild("SkillCheckPromptGui")
    local check=prompt and prompt:FindFirstChild("Check")
    if not check then return "Skill Check: UI not found" end
    if not check.Visible then return "Skill Check: inactive" end
    local line=check:FindFirstChild("Line")
    local goal=check:FindFirstChild("Goal")
    if not line or not goal or not line:IsA("GuiObject")
        or not goal:IsA("GuiObject") then
        return "Skill Check: Line/Goal missing"
    end
    local current=line.Rotation%360
    local startAngle=(goal.Rotation+101)%360
    local endAngle=(goal.Rotation+115)%360
    local hit=(startAngle>endAngle)
        and (current>=startAngle or current<=endAngle)
        or (current>=startAngle and current<=endAngle)
    return string.format("Skill Check: %s\nangle %.0f / goal %.0f",
        hit and "TARGET WINDOW" or "outside",current,goal.Rotation%360)
end
local lastUpdate=0
connect(RunService.Heartbeat,function(dt)
    if not state.alive then return end
    local now=os.clock()
    if now-lastUpdate<.25 then return end
    lastUpdate=now
    updateNoClip()
    updateSpeed()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local closestKiller=math.huge
    local closestName=""
    if state.playerESP or state.killerAlert then
        for _,other in ipairs(Players:GetPlayers()) do
            if other~=player then
                if state.playerESP then ensurePlayerVisual(other) end
                if state.killerAlert and root then
                    local role=roleOf(other)
                    if role=="Killer" then
                        local theirRoot=other.Character
                            and other.Character:FindFirstChild("HumanoidRootPart")
                        if theirRoot then
                            local distance=(root.Position-theirRoot.Position).Magnitude
                            if distance<closestKiller then
                                closestKiller=distance
                                closestName=other.DisplayName
                            end
                        end
                    end
                end
            end
        end
    end
    alert.Text=(state.killerAlert and closestKiller<99)
        and string.format("KILLER NEARBY: %s (%d studs)",
            closestName,math.floor(closestKiller))
        or ""
    local team=player.Team and player.Team.Name:lower() or ""
    local lobby=(team:find("lobby",1,true)
        or team:find("spectator",1,true))~=nil
    objectiveInfo.Text="Detected objectives: "..state.identifiedObjectives
        .."\nScanner: "..state.scanProgress
        .."\nObjective ESP: "..(state.objectiveESP and "ON" or "OFF")
        ..(lobby and ("\nNext Killer (estimate): "..estimateNextKiller()) or "")
    skillInfo.Text=checkSkillUi()
    refreshObjectiveVisibility()
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local speedState=hum and string.format(" | Speed %.0f",hum.WalkSpeed) or ""
    local totalPlayers=#Players:GetPlayers()
    footer.Text="PLAYERS  "..totalPlayers.."     OBJECTIVES  "
        ..state.identifiedObjectives..speedState
        .."     |     RIGHT CTRL: HIDE"
    hudOverview.Text=string.format("PLAYERS  %d   |   OBJECTIVES  %d",
        totalPlayers,state.identifiedObjectives)
    hudThreat.Text=closestKiller<99 and state.killerAlert
        and string.format("KILLER NEARBY  -  %d studs",
            math.floor(closestKiller))
        or (state.killerAlert and "KILLER STATUS  -  CLEAR / UNKNOWN"
            or "KILLER ALERT  -  OFF")
    hudThreat.TextColor=(closestKiller<99 and state.killerAlert)
        and palette.red or palette.muted
    homeCounts.Text=string.format("%d PLAYERS   /   %d OBJECTIVES",
        totalPlayers,state.identifiedObjectives)
    homeKiller.Text=hudThreat.Text
    homeKiller.TextColor=hudThreat.TextColor
    homeSkill.Text=checkSkillUi()
end)

connect(Players.PlayerRemoving,removePlayerVisual)
connect(Lighting.ChildAdded,function(child)
    if state.alive and (state.fullbright or state.noFog) then
        task.defer(updateLighting)
    end
end)
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
    if state.alive then cameraFov() end
end)

-- Drag only from the title area, keeping close/expand buttons reliable.
local dragging=false
local dragStart,frameStart,dragInput
connect(dragHandle.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragInput=input
        dragStart=input.Position
        frameStart=panel.Position
    end
end)
connect(UserInputService.InputChanged,function(input)
    if not dragging then return end
    if input==dragInput or input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-dragStart
        local x=frameStart.X.Scale
        local y=frameStart.Y.Scale
        panel.Position=UDim2.new(x,frameStart.X.Offset+delta.X,
            y,frameStart.Y.Offset+delta.Y)
    end
end)
connect(UserInputService.InputEnded,function(input)
    if input==dragInput or
        input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
        dragInput=nil
        task.defer(keepOnScreen)
    end
end)
connect(UserInputService.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
        restore.Visible=not panel.Visible
    end
end)


local function cleanup()
    if not state.alive then return end
    state.alive=false
    scanGeneration+=1
    if activeTween then activeTween:Cancel() end
    for _,connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(connections)
    for other in pairs(playerVisuals) do removePlayerVisual(other) end
    for object,visual in pairs(objectiveVisuals) do
        visual.gui:Destroy()
        objectiveVisuals[object]=nil
    end
    setNoClip(false)
    state.fullbright=false
    state.noFog=false
    updateLighting()
    local camera=Workspace.CurrentCamera
    if camera then camera.FieldOfView=originalFOV end
    if state.speed then setSpeed(false) end
    gui:Destroy()
    if environment.VelionVDCleanup==cleanup then
        environment.VelionVDCleanup=nil
    end
end
environment.VelionVDCleanup=cleanup
connect(close.MouseButton1Click,cleanup)
choosePage("Visual")
startObjectiveScan()
print("[Velion VD V2.1 Mini HUD] Source loaded. UI opens compact; toggle + for dashboard. Gameplay not yet verified.")
