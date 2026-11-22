--[[
    VELION DISTRICT HUB V1.0
    For Roblox Violence District - client-side utility module.
    Clean, readable Luau. No external UI libraries, telemetry or extra loaders.
    IMPORTANT: Does not spoof server state or grant server-side immunity.
    Objective detection uses names/prompts because map internals may change.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then return end
local playerGui = player:WaitForChild("PlayerGui",10)
if not playerGui then warn("[Velion VD] PlayerGui unavailable"); return end

local environment = (type(getgenv)=="function" and getgenv()) or _G
if type(environment.VelionVDCleanup)=="function" then
    pcall(environment.VelionVDCleanup)
end
local previousGui = playerGui:FindFirstChild("VelionDistrictHub")
if previousGui then previousGui:Destroy() end

local state = {
    alive=true, playerESP=false, objectiveESP=false,
    fullbright=false, noFog=false, noClip=false,
    speed=false, speedValue=24, fov=70,
    killerAlert=true, scanProgress="Starting",
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

local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictHub",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=800
})
local panel=create("Frame",gui,{
    Position=UDim2.new(.5,-230,0,75),Size=UDim2.fromOffset(460,370),
    BackgroundColor3=palette.bg,BorderSizePixel=0,
    Active=true
})
round(panel,12)
create("UIStroke",panel,{Color=palette.accent,Thickness=1.3})
local header=create("Frame",panel,{
    Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(460,42),
    BackgroundTransparency=1,Active=true
})
local title=label(header,"VELION  |  VIOLENCE DISTRICT",14,6,360,30,14)
title.Font=Enum.Font.GothamBold
local minimize=button(header,"-",398,8,24,25)
local close=button(header,"X",430,8,23,25)
local sidebar=create("Frame",panel,{
    Position=UDim2.fromOffset(8,45),Size=UDim2.fromOffset(119,278),
    BackgroundColor3=palette.side,BorderSizePixel=0
})
round(sidebar,8)
local contents=create("Frame",panel,{
    Position=UDim2.fromOffset(135,46),Size=UDim2.fromOffset(317,278),
    BackgroundColor3=palette.side,BorderSizePixel=0
})
round(contents,8)
local footer=label(panel,"Detection-based tools | local changes only",
    12,330,437,27,10,palette.muted)
local pages,nav={}
local function makePage(name)
    local page=create("Frame",contents,{
        Name=name,Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Visible=false
    })
    pages[name]=page
    return page
end
local visual=makePage("Visual")
local playerPage=makePage("Player")
local objectivesPage=makePage("Objectives")
local aboutPage=makePage("Info")
local navOrder={"Visual","Player","Objectives","Info"}
local function choosePage(name)
    for tab,page in pairs(pages) do page.Visible=(tab==name) end
    for tab,item in pairs(nav) do
        item.BackgroundColor3=tab==name and palette.accent or palette.surface
    end
end
for i,name in ipairs(navOrder) do
    local item=button(sidebar,name,8,9+(i-1)*54,103,43)
    nav[name]=item
    connect(item.MouseButton1Click,function() choosePage(name) end)
end
local function sectionTitle(page,name)
    local t=label(page,name,12,6,294,27,13,palette.white)
    t.Font=Enum.Font.GothamBold
end
sectionTitle(visual,"VISUAL / ESP")
sectionTitle(playerPage,"MOVEMENT / ALERT")
sectionTitle(objectivesPage,"MAP OBJECTIVES")
sectionTitle(aboutPage,"ABOUT THIS HUB")

local function toggle(parent,title,y,get,set)
    local control=button(parent,title..": OFF",12,y,293,35)
    local function redraw()
        local on=get()
        control.Text=title..": "..(on and "ON" or "OFF")
        control.BackgroundColor3=on and palette.green or palette.surface
    end
    connect(control.MouseButton1Click,function()
        set(not get())
        redraw()
    end)
    redraw()
    return redraw
end

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
    Lighting.GlobalShadows=state.fullbright and false
        or lightingOriginal.GlobalShadows
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
local originalFOV=Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70
local function roleOf(other)
    local character=other.Character
    local fields={
        other:GetAttribute("Role"),other:GetAttribute("role"),
        other:GetAttribute("Team"),other:GetAttribute("TeamRole"),
        character and character:GetAttribute("Role"),
        other.Team and other.Team.Name
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
            AlwaysOnTop=true,Size=UDim2.fromOffset(180,39),
            StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
            MaxDistance=650,ResetOnSpawn=false
        })
        local textLabel=label(billboard,"",0,0,180,39,12)
        textLabel.TextXAlignment=Enum.TextXAlignment.Center
        textLabel.TextStrokeTransparency=.25
        existing={character=character,highlight=highlight,
            billboard=billboard,text=textLabel}
        playerVisuals[other]=existing
    end
    local role,color=roleOf(other)
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=character:FindFirstChild("HumanoidRootPart")
    local distance=(root and targetRoot)
        and math.floor((root.Position-targetRoot.Position).Magnitude) or nil
    existing.highlight.FillColor=color
    existing.highlight.OutlineColor=color
    existing.text.TextColor3=color
    existing.text.Text=other.DisplayName.." ["..role.."]"
        ..(distance and ("\n"..distance.." studs") or "")
end

local objectiveKinds={
    {key="generator",title="GENERATOR",color=Color3.fromRGB(108,214,253)},
    {key="pallet",title="PALLET",color=Color3.fromRGB(251,198,104)},
    {key="hook",title="HOOK",color=Color3.fromRGB(245,115,146)},
    {key="exitgate",title="EXIT GATE",color=Color3.fromRGB(112,238,154)},
    {key="exit gate",title="EXIT GATE",color=Color3.fromRGB(112,238,154)},
    {key="gateexit",title="EXIT GATE",color=Color3.fromRGB(112,238,154)}
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
    local model=candidate:IsA("Model") and candidate
        or candidate:FindFirstAncestorOfClass("Model")
    if model and model==player.Character then return nil,nil end
    if model then
        local base=model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart",true)
        if base then return model,base end
    end
    if candidate:IsA("BasePart") then return candidate,candidate end
    local parent=candidate.Parent
    if parent and parent:IsA("BasePart") then return parent,parent end
    return nil,nil
end
local function considerObjective(candidate)
    if not state.alive or not candidate.Parent then return end
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
    objectiveVisuals[obj]={gui=billboard,kind=kind,part=part}
    state.identifiedObjectives+=1
end
local function refreshObjectiveVisibility()
    for object,v in pairs(objectiveVisuals) do
        if object.Parent and v.part.Parent then
            v.gui.Enabled=state.objectiveESP
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
        local objects=Workspace:GetDescendants()
        state.scanProgress="Analyzing "..#objects.." instances"
        for i,item in ipairs(objects) do
            if not state.alive or generation~=scanGeneration then return end
            considerObjective(item)
            if i%90==0 then task.wait() end
        end
        state.scanProgress="Complete"
    end)
end
connect(Workspace.DescendantAdded,considerObjective)
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
    if hum and hum.Health>0 and hum.WalkSpeed~=state.speedValue then
        hum.WalkSpeed=state.speedValue
    end
end
local function cameraFov()
    local camera=Workspace.CurrentCamera
    if camera then camera.FieldOfView=state.fov end
end
local function setSpeed(value)
    state.speed=value
    if not value then
        local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16 end
    end
end

-- Visual
toggle(visual,"PLAYER ESP",41,
    function() return state.playerESP end,
    function(v)
        state.playerESP=v
        if not v then
            for other in pairs(playerVisuals) do removePlayerVisual(other) end
        end
    end)
toggle(visual,"OBJECTIVE ESP",83,
    function() return state.objectiveESP end,
    function(v) state.objectiveESP=v;refreshObjectiveVisibility() end)
toggle(visual,"FULLBRIGHT",125,
    function() return state.fullbright end,
    function(v) state.fullbright=v;updateLighting() end)
toggle(visual,"NO FOG",167,
    function() return state.noFog end,
    function(v) state.noFog=v;updateLighting() end)
local fovButton=button(visual,"CAMERA FOV: 70",12,209,293,35)
connect(fovButton.MouseButton1Click,function()
    local nextValues={[70]=85,[85]=100,[100]=70}
    state.fov=nextValues[state.fov] or 70
    fovButton.Text="CAMERA FOV: "..state.fov
    cameraFov()
end)

-- Player
toggle(playerPage,"NOCLIP",41,
    function() return state.noClip end,setNoClip)
local speedToggle=toggle(playerPage,"SPEED ASSIST",83,
    function() return state.speed end,setSpeed)
local speedButton=button(playerPage,"SPEED VALUE: 24",12,125,293,35)
connect(speedButton.MouseButton1Click,function()
    local values={[24]=28,[28]=32,[32]=20,[20]=24}
    state.speedValue=values[state.speedValue] or 24
    speedButton.Text="SPEED VALUE: "..state.speedValue
end)
toggle(playerPage,"KILLER PROXIMITY ALERT",167,
    function() return state.killerAlert end,
    function(v) state.killerAlert=v end)
local roleHint=label(playerPage,
    "Role alert uses visible player attributes or team data.\n"
    .."Unknown roles are never automatically labeled Killer.",
    12,208,292,55,11,palette.muted)

-- Objectives
local refreshButton=button(objectivesPage,"REFRESH OBJECTIVES",12,43,293,38)
connect(refreshButton.MouseButton1Click,startObjectiveScan)
local objectiveInfo=label(objectivesPage,"Scanning map...",12,94,292,139,12,palette.muted)
label(objectivesPage,
    "Supported names: Generator, Pallet, Hook, ExitGate.\n"
    .."Markers depend on replicated object names.",
    12,230,295,43,10,palette.muted)

-- Info
label(aboutPage,
    "VELION DISTRICT HUB V1.0\n\n"
    .."Implemented: Player ESP, objective markers, Fullbright,\n"
    .."No Fog, camera FOV, NoClip, speed assist,\n"
    .."Killer proximity warning.\n\n"
    .."Not included: server immunity, auto generator,\n"
    .."auto parry or unverified game remotes.\n\n"
    .."RightControl: show/hide GUI\n"
    .."Close (X): restore settings and disconnect.",
    13,42,293,218,12,palette.muted)

local alert=label(gui,"",0,0,460,40,16,palette.red)
alert.Font=Enum.Font.GothamBold
alert.TextXAlignment=Enum.TextXAlignment.Center
alert.Position=UDim2.new(.5,-230,0,8)

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
    alert.Text=(state.killerAlert and closestKiller<85)
        and string.format("KILLER NEARBY: %s (%d studs)",
            closestName,math.floor(closestKiller))
        or ""
    objectiveInfo.Text="Detected objectives: "..state.identifiedObjectives
        .."\nScanner: "..state.scanProgress
        .."\nObjective ESP: "..(state.objectiveESP and "ON" or "OFF")
    refreshObjectiveVisibility()
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local speedState=hum and string.format(" | Speed %.0f",hum.WalkSpeed) or ""
    footer.Text="Players: "..#Players:GetPlayers()..
        " | Objectives: "..state.identifiedObjectives..speedState
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

local dragging=false
local dragStart,frameStart
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        dragStart=input.Position
        frameStart=panel.Position
    end
end)
connect(UserInputService.InputChanged,function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local diff=input.Position-dragStart
        panel.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+diff.X,
            frameStart.Y.Scale,frameStart.Y.Offset+diff.Y)
    end
end)
connect(UserInputService.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
connect(UserInputService.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
    end
end)
local minimized=false
connect(minimize.MouseButton1Click,function()
    minimized=not minimized
    sidebar.Visible=not minimized
    contents.Visible=not minimized
    footer.Visible=not minimized
    panel.Size=minimized and UDim2.fromOffset(460,42)
        or UDim2.fromOffset(460,370)
    minimize.Text=minimized and "+" or "-"
end)

local function cleanup()
    if not state.alive then return end
    state.alive=false
    scanGeneration+=1
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
print("[Velion VD V1.0] Loaded. Clear UI, no external downloads. RightControl toggles GUI.")
