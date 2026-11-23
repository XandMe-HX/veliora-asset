--!strict
--[[
    VELION DISTRICT HUB V4.2 - FLUENT GAME TRACKING
    For Roblox Violence District - client-side utility module.
    Game UI uses upstream Fluent; the World ESP engine is local code.
    IMPORTANT: Does not spoof server state or grant server-side immunity.
    UI uses dawid-scripts Fluent, with individual ESP toggles and color controls.
    Game internals can change. Auto input attempts are not confirmed success.
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
    alive=true, playerESP=true, objectiveESP=true,
    fullbright=false, noFog=false, noClip=false,
    speed=false, speedValue=24, fov=70,
    killerAlert=true, offscreenESP=true, hidden=false, scanProgress="Starting",
    expanded=true, activeTab="Home", sceneBlur=false,
    killerESP=true, survivorESP=true, unknownESP=false,
    survivorItemsESP=true, worldItemsESP=true,
    abilityNotify=true, roleTracking=true,
    playerNames=true, playerDistance=true,
    playerMask=true, chaseStatus=true, knockedStatus=true, hookedStatus=true,
    playerHighlight=true, objectHighlight=true, highlightMode="Outline", nextKiller=true, skillMonitor=true,
    autoSkillCheck=false, inputStatus="No action attempted",
    generatorESP=true, palletESP=true, windowESP=true, hookESP=true,
    gateESP=true, generatorProgressESP=true, espDistance=650,
    identifiedObjectives=0, unknownRoles=0,
    progressScale="Auto", progressUnknown=0,
    worldItemsFound=0, scanMapCount=0, scanInteractableCount=0,
    abilityStatus="Waiting for replicated ability signals",
    roleTransitions=0, trackedPlayers=0,
    maxWorldLabels=22, maxWorldHighlights=20, objectLabels=true,
    scanCandidates=0, scanScanned=0, scanDurationMs=0,
    visibleLabels=0, visibleHighlights=0, fps=60,
}
local palette = {
    bg=Color3.fromRGB(26,28,27),
    side=Color3.fromRGB(43,45,42),
    surface=Color3.fromRGB(67,69,66),
    accent=Color3.fromRGB(220,230,220),
    green=Color3.fromRGB(126,222,167),
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

-- Glass appearance values live in this typed table.

-- Main panel: same feature dashboard in all three glass styles.
-- Roblox has NO per-UI backdrop blur or real refraction. Tint, rim and sheen
-- emulate the surface. The optional Lighting blur affects the whole scene.

local espColors={
    Killer=Color3.fromRGB(255,80,91),
    Survivor=Color3.fromRGB(78,173,252),
    Generator=Color3.fromRGB(194,108,255),
    Pallet=Color3.fromRGB(255,196,86),
    Window=Color3.fromRGB(95,233,223),
    Hook=Color3.fromRGB(248,122,170),
    Gate=Color3.fromRGB(122,244,165),
    Chased=Color3.fromRGB(255,155,80),
    Knocked=Color3.fromRGB(244,199,78),
    Hooked=Color3.fromRGB(255,134,195),
    Unknown=Color3.fromRGB(184,180,205),
    Item=Color3.fromRGB(246,213,104),
}
local function highlightStyle(h: Highlight,color: Color3)
    h.FillColor=color
    h.OutlineColor=color
    h.FillTransparency=(state.highlightMode=="Outline") and 1 or .79
    h.OutlineTransparency=(state.highlightMode=="Fill") and 1 or 0
end
local function categoryName(key: string): string
    if key=="palletwrong" or key=="pallet" then return "Pallet" end
    if key=="generator" then return "Generator" end
    if key=="window" then return "Window" end
    if key=="hook" then return "Hook" end
    if key=="gate" then return "Gate" end
    if key=="item" then return "Item" end
    return "Unknown"
end
local function categoryColor(key: string): Color3
    return espColors[categoryName(key)] or espColors.Unknown
end

-- The Fluent window is the only menu. This ScreenGui contains ESP overlays
-- only, so no hidden large Frame can block mouse/touch interactions.
local existingOverlay=playerGui:FindFirstChild("VelionDistrictOverlayV4")
if existingOverlay then existingOverlay:Destroy() end
local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictOverlayV4",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=950,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
local alert=create("TextLabel",gui,{
    Name="KillerWarning",Text="",Visible=false,
    AnchorPoint=Vector2.new(.5,0),
    Position=UDim2.new(.5,0,0,12),
    Size=UDim2.new(.92,0,0,43),
    TextColor3=espColors.Killer,TextSize=14,
    Font=Enum.Font.GothamBold,
    BackgroundColor3=Color3.fromRGB(26,28,33),
    BackgroundTransparency=.15,BorderSizePixel=0,
    TextStrokeTransparency=.6
})
round(alert,12)
create("UISizeConstraint",alert,{
    MinSize=Vector2.new(220,43),MaxSize=Vector2.new(410,43)
})
create("UIStroke",alert,{
    Color=espColors.Killer,Thickness=1,Transparency=.35
})

local okFluent,Fluent=pcall(function()
    local url="https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"
    return loadstring(game:HttpGet(url))()
end)
if not okFluent or type(Fluent)~="table" then
    gui:Destroy()
    warn("[Velion Fluent V4] Fluent download/load failed: "..tostring(Fluent))
    return
end
local cameraSize=Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
    or Vector2.new(1280,720)
local uiWidth=math.min(600,math.max(310,cameraSize.X-24))
local uiHeight=math.min(490,math.max(320,cameraSize.Y-80))
local createdWindow,Window=pcall(function()
    return Fluent:CreateWindow({
        Title="VELION | VIOLENCE DISTRICT",
        SubTitle="V4.2 / Game Tracking",
        TabWidth=cameraSize.X<500 and 116 or 150,
        Size=UDim2.fromOffset(uiWidth,uiHeight),
        Acrylic=true,Theme="Dark",
        MinimizeKey=Enum.KeyCode.RightControl
    })
end)
if not createdWindow or not Window then
    gui:Destroy()
    pcall(function() Fluent:Destroy() end)
    warn("[Velion Fluent V4] CreateWindow failed: "..tostring(Window))
    return
end
local Tabs={
    Main=Window:AddTab({Title="Dashboard",Icon="layout-dashboard"}),
    Players=Window:AddTab({Title="Player ESP",Icon="users"}),
    Objects=Window:AddTab({Title="Object ESP",Icon="scan"}),
    Survivor=Window:AddTab({Title="Survivor",Icon="shield"}),
    Movement=Window:AddTab({Title="Movement",Icon="footprints"}),
    Visual=Window:AddTab({Title="Visual",Icon="eye"}),
    Settings=Window:AddTab({Title="Settings",Icon="settings"})
}
local Options=Fluent.Options
local controls={}
local toggles={}
local function registerToggle(tab:any,id:string,title:string,description:string,
    stateKey:string,onValue:((boolean)->())?)
    local obj=tab:AddToggle(id,{
        Title=title,Description=description,
        Default=state[stateKey]==true,
        Callback=function(value)
            state[stateKey]=value
            if onValue then onValue(value) end
        end
    })
    toggles[id]=obj
    return obj
end
local function registerColor(tab:any,id:string,label:string,colorKey:string)
    local colorPicker=tab:AddColorpicker(id,{
        Title=label,
        Description="Outline / Fill color for this ESP category",
        Default=espColors[colorKey],
        Callback=function(color)
            if typeof(color)=="Color3" then
                espColors[colorKey]=color
            end
        end
    })
    controls[id]=colorPicker
    return colorPicker
end
local function registerSlider(tab:any,id:string,label:string,description:string,
    init:number,minimum:number,maximum:number,rounding:number,onValue:(number)->())
    local item=tab:AddSlider(id,{
        Title=label,Description=description,
        Default=init,Min=minimum,Max=maximum,Rounding=rounding,
        Callback=onValue
    })
    controls[id]=item
    return item
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
            return "Killer",espColors.Killer
        elseif s:find("surviv",1,true) or s:find("innocent",1,true) then
            return "Survivor",espColors.Survivor
        end
    end
    return "Unknown",espColors.Unknown
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
    local role,color=roleOf(other)
    if (role=="Killer" and not state.killerESP) or
        (role=="Survivor" and not state.survivorESP) or
        (role=="Unknown" and not state.unknownESP) then
        removePlayerVisual(other)
        return
    end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=character:FindFirstChild("HumanoidRootPart")
    local distance=(root and targetRoot)
        and math.floor((root.Position-targetRoot.Position).Magnitude) or nil
    if distance and distance>state.espDistance then
        removePlayerVisual(other)
        return
    end
    local existing=playerVisuals[other]
    if existing and existing.character~=character then
        removePlayerVisual(other)
        existing=nil
    end
    if not existing then
        local highlight=create("Highlight",Workspace,{
            Name="VelionVDPlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=.82,OutlineTransparency=0
        })
        local billboard=create("BillboardGui",playerGui,{
            Name="VelionVDPlayerTag",Adornee=head,
            AlwaysOnTop=true,Size=UDim2.fromOffset(205,62),
            StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
            MaxDistance=650
        })
        local textLabel=label(billboard,"",0,0,205,62,11)
        textLabel.TextXAlignment=Enum.TextXAlignment.Center
        textLabel.TextStrokeTransparency=.25
        local pointer=label(gui,"",0,0,185,43,11,espColors.Killer)
        pointer.TextXAlignment=Enum.TextXAlignment.Center
        pointer.TextStrokeTransparency=.2
        pointer.Visible=false
        existing={character=character,highlight=highlight,
            billboard=billboard,text=textLabel,pointer=pointer}
        playerVisuals[other]=existing
    end
    local isHooked=gameValue(character,"IsHooked")==true
        or gameValue(other,"IsHooked")==true
    local isKnocked=gameValue(character,"Knocked")==true
        or gameValue(other,"Knocked")==true
    local isChased=gameValue(character,"IsChased")==true
        or gameValue(other,"IsChased")==true
    if isHooked and state.hookedStatus then color=espColors.Hooked
    elseif isKnocked and state.knockedStatus then color=espColors.Knocked
    elseif isChased and state.chaseStatus then color=espColors.Chased end
    local selectedKiller=gameValue(other,"SelectedKiller")
    local nick=(role=="Killer" and selectedKiller)
        and tostring(selectedKiller) or other.DisplayName
    local mask=(state.playerMask and role=="Killer") and maskLabel(other) or nil
    local status=(isHooked and state.hookedStatus and "HOOKED")
        or (isKnocked and state.knockedStatus and "KNOCKED")
        or (isChased and state.chaseStatus and "CHASED") or nil
    local heldItem=nil
    if state.survivorItemsESP and role=="Survivor" then
        local item=character:FindFirstChildWhichIsA("Tool")
        if item then heldItem=item.Name end
    end
    highlightStyle(existing.highlight,color)
    existing.highlight.Enabled=state.playerHighlight and
        (not distance or distance<=state.espDistance)
    existing.billboard.MaxDistance=state.espDistance
    existing.billboard.Enabled=state.playerNames or status~=nil
    existing.text.TextColor3=color
    existing.text.Text=(state.playerNames and (nick.." ["..role.."]") or "")
        ..(state.playerDistance and distance and
            ("\n"..distance.." studs") or "")
        ..(mask and ("\nMask: "..mask) or "")
        ..(status and ("\n"..status) or "")
        ..(heldItem and ("\nHeld item: "..heldItem) or "")
    local cam=Workspace.CurrentCamera
    if not cam or not state.offscreenESP or
        (not (isChased and state.chaseStatus) and role~="Killer")
        or not targetRoot then
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

-- WORLD ESP V2: map-only discovery, lazy rendering and strict visibility caps.
-- High-instance-count lobby objects, cosmetic preview models and fake
-- characters are deliberately excluded by the Workspace.Map scope.
-- V4.2 World ESP: two verified Workspace scopes (Map + Interactables).
-- No full Workspace scans, preview-model targeting or arbitrary 90-object cap.
local objectiveKinds={
    {name="Generator",key="generator",priority=145},
    {name="ExitGate",key="gate",priority=115},
    {name="Gate",key="gate",priority=115},
    {name="Hook",key="hook",priority=80},
    {name="Palletwrong",key="pallet",priority=55},
    {name="Pallet",key="pallet",priority=55},
    {name="Window",key="window",priority=18},
    {name="Medkit",key="item",priority=65},
    {name="Bandage",key="item",priority=65},
    {name="Flashlight",key="item",priority=65},
    {name="Battery",key="item",priority=65},
    {name="Item",key="item",priority=65},
    {name="Pickup",key="item",priority=65},
}
local currentMap: Instance?=nil
local activeInteractables: Instance?=nil
local sourceConnections: {RBXScriptConnection}={}
local scanGeneration=0
local lastObjectiveRefresh=0
local cachedNameKinds={}
for _,kind in ipairs(objectiveKinds) do
    cachedNameKinds[kind.name:lower()]=kind
end
local itemKind={name="ITEM",key="item",priority=65}
local repairKind=cachedNameKinds.generator
local windowKind=cachedNameKinds.window

local function objectiveEnabled(key: string): boolean
    if key=="generator" then return state.generatorESP end
    if key=="pallet" then return state.palletESP end
    if key=="window" then return state.windowESP end
    if key=="hook" then return state.hookESP end
    if key=="gate" then return state.gateESP end
    if key=="item" then return state.worldItemsESP end
    return false
end
local function inScope(item: Instance): boolean
    local root: Instance?=nil
    if currentMap and item:IsDescendantOf(currentMap) then
        root=currentMap
    elseif activeInteractables and item:IsDescendantOf(activeInteractables) then
        root=activeInteractables
    end
    if not root then return false end
    local node=item
    while node and node~=root do
        local lower=node.Name:lower()
        if lower:find("lobby",1,true)
            or lower:find("preview",1,true)
            or lower:find("fakecharacter",1,true) then
            return false
        end
        node=node.Parent
    end
    return true
end
local function classifyNamed(item: Instance)
    if not item:IsA("Model") and not item:IsA("BasePart")
        and not item:IsA("Tool") then return nil end
    if item:IsA("Tool") then return itemKind end
    local canonical=item.Name:lower():gsub("[%s_%-]","")
    for _,kind in ipairs(objectiveKinds) do
        local target=kind.name:lower()
        if canonical==target or canonical:match("^"..target.."%d+$") then
            return kind
        end
    end
    return nil
end
local function promptKind(item: Instance)
    if not item:IsA("ProximityPrompt") then return nil end
    local action=item.ActionText:lower()
    if action:find("repair",1,true) then return repairKind end
    if action:find("vault",1,true) then return windowKind end
    if action:find("pick up",1,true) or action:find("pickup",1,true)
        or action:find("collect",1,true) or action=="take" then
        return itemKind
    end
    return nil
end
local function getObjective(item: Instance)
    if not inScope(item) then return nil,nil,nil end
    local kind=classifyNamed(item)
    local original=item
    if item:IsA("ProximityPrompt") then
        kind=promptKind(item)
        if not kind then return nil,nil,nil end
        -- Resolve to a useful nearby model/part, not Map or Interactables.
        local parent=item.Parent
        if not parent then return nil,nil,nil end
        local model=parent:IsA("Model") and parent
            or parent:FindFirstAncestorOfClass("Model")
        if model and model~=currentMap and model~=activeInteractables
            and inScope(model) then
            item=model
        elseif parent:IsA("BasePart") then
            item=parent
        else
            return nil,nil,nil
        end
    end
    if not kind then return nil,nil,nil end
    -- Model gets one marker even when its nested part shares the same name.
    if original:IsA("BasePart") then
        local parent=original.Parent
        if parent and parent:IsA("Model") and classifyNamed(parent)
            and inScope(parent) then
            return nil,nil,nil
        end
    end
    local part: BasePart?=nil
    if item:IsA("BasePart") then
        part=item
    elseif item:IsA("Model") then
        part=item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart",true)
    elseif item:IsA("Tool") then
        part=item:FindFirstChild("Handle")
        if not part or not part:IsA("BasePart") then
            part=item:FindFirstChildWhichIsA("BasePart")
        end
    end
    if not part then return nil,nil,nil end
    return item,part,kind
end

local function destroyObjectiveNodes(record)
    if record.gui then record.gui:Destroy();record.gui=nil end
    if record.highlight then record.highlight:Destroy();record.highlight=nil end
    record.text=nil
end
local function removeObjectiveRecord(obj: Instance)
    local rec=objectiveVisuals[obj]
    if not rec then return end
    destroyObjectiveNodes(rec)
    objectiveVisuals[obj]=nil
    state.identifiedObjectives=math.max(0,state.identifiedObjectives-1)
end
local function clearObjectives()
    for obj in pairs(objectiveVisuals) do removeObjectiveRecord(obj) end
    state.identifiedObjectives=0
    state.visibleLabels=0
    state.visibleHighlights=0
    state.worldItemsFound=0
end
local function considerObjective(candidate: Instance)
    if not state.alive or not candidate.Parent then return end
    local obj,part,kind=getObjective(candidate)
    if not obj or not part or not kind then return end
    if objectiveVisuals[obj] then return end
    objectiveVisuals[obj]={
        obj=obj,part=part,kind=kind,gui=nil,
        highlight=nil,text=nil,lastVisible=0,
        progressRef=nil,progressMaxRef=nil
    }
    state.identifiedObjectives+=1
    if kind.key=="item" then state.worldItemsFound+=1 end
end
local function makeObjectiveNodes(rec)
    if not rec.gui then
        local board=create("BillboardGui",playerGui,{
            Name="VelionVDObjective",Adornee=rec.part,
            Size=UDim2.fromOffset(160,30),AlwaysOnTop=true,
            Enabled=false,MaxDistance=state.espDistance,
            StudsOffsetWorldSpace=Vector3.new(0,3,0)
        })
        local tag=label(board,rec.kind.name:upper(),
            0,0,160,30,12,categoryColor(rec.kind.key))
        tag.TextXAlignment=Enum.TextXAlignment.Center
        tag.TextStrokeTransparency=.25
        rec.gui=board
        rec.text=tag
    end
    if state.objectHighlight and not rec.highlight then
        rec.highlight=create("Highlight",Workspace,{
            Name="VelionVDObjectiveOutline",Adornee=rec.obj,
            Enabled=false,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=1,OutlineTransparency=0,
            FillColor=categoryColor(rec.kind.key),
            OutlineColor=categoryColor(rec.kind.key)
        })
    end
end

local function asNumber(target: Instance?,field: string): number?
    if not target then return nil end
    local raw=gameValue(target,field)
    if type(raw)=="number" then return raw end
    return nil
end
-- Only sample plausible progress fields, not arbitrary "Progress" GUI text.
-- A missing maximum for 0 < x < 1 is intentionally not guessed as percent.
local function generatorProgress(rec): string
    local obj=rec.obj
    local part=rec.part
    local progress=asNumber(obj,"RepairProgress")
        or asNumber(obj,"Progress")
        or asNumber(part,"RepairProgress")
        or asNumber(part,"Progress")
    local maxValue=asNumber(obj,"MaxRepairProgress")
        or asNumber(obj,"MaxProgress")
        or asNumber(part,"MaxRepairProgress")
        or asNumber(part,"MaxProgress")
    if progress==nil and obj:IsA("Model") then
        if not rec.progressRef or not rec.progressRef.Parent then
            rec.progressRef=obj:FindFirstChild("RepairProgress",true)
                or obj:FindFirstChild("Progress",true)
        end
        local node=rec.progressRef
        if node and node:IsA("ValueBase") and type(node.Value)=="number" then
            progress=node.Value
        end
    end
    if not maxValue and obj:IsA("Model") then
        if not rec.progressMaxRef or not rec.progressMaxRef.Parent then
            rec.progressMaxRef=obj:FindFirstChild("MaxRepairProgress",true)
                or obj:FindFirstChild("MaxProgress",true)
        end
        local node=rec.progressMaxRef
        if node and node:IsA("ValueBase") and type(node.Value)=="number" then
            maxValue=node.Value
        end
    end
    if type(progress)~="number" then
        state.progressUnknown+=1
        return "GEN • progress unavailable"
    end
    local value: number?=nil
    if maxValue and maxValue>0 then
        value=progress/maxValue*100
    elseif state.progressScale=="Fraction" then
        value=progress*100
    elseif state.progressScale=="Percent" then
        value=progress
    elseif state.progressScale=="Auto" then
        if progress==0 or (progress>=1 and progress<=100) then
            value=progress
        end
    end
    if value then
        return string.format("GEN %.0f%%",math.clamp(value,0,100))
    end
    state.progressUnknown+=1
    return string.format("GEN %.2f (raw)",progress)
end

local function refreshObjectiveVisibility()
    local now=os.clock()
    if now-lastObjectiveRefresh<.3 then return end
    lastObjectiveRefresh=now
    local cam=Workspace.CurrentCamera
    local root=player.Character and
        player.Character:FindFirstChild("HumanoidRootPart")
    local candidates={}
    local cacheCount=0
    for obj,rec in pairs(objectiveVisuals) do
        if not obj.Parent or not rec.part.Parent or not inScope(obj) then
            removeObjectiveRecord(obj)
        else
            cacheCount+=1
            if rec.gui then rec.gui.Enabled=false end
            if rec.highlight then rec.highlight.Enabled=false end
            if state.objectiveESP and objectiveEnabled(rec.kind.key)
                and root and cam then
                local d=(root.Position-rec.part.Position).Magnitude
                if d<=state.espDistance then
                    local pos,onScreen=cam:WorldToViewportPoint(
                        rec.part.Position)
                    if onScreen and pos.Z>0 then
                        candidates[#candidates+1]={
                            rec=rec,dist=d,pos=pos,
                            priority=d-rec.kind.priority
                        }
                    end
                end
            end
        end
    end
    table.sort(candidates,function(a,b)
        return a.priority<b.priority
    end)
    local occupied={}
    local labels,highlights=0,0
    state.progressUnknown=0
    for _,entry in ipairs(candidates) do
        local rec=entry.rec
        local cell=math.floor(entry.pos.X/125)..":"..
            math.floor(entry.pos.Y/64)
        local showLabel=state.objectLabels
            and labels<state.maxWorldLabels and not occupied[cell]
        local showOutline=state.objectHighlight
            and highlights<state.maxWorldHighlights
        if showLabel or showOutline then
            makeObjectiveNodes(rec)
            local color=categoryColor(rec.kind.key)
            if rec.text then
                rec.text.TextColor3=color
                if rec.kind.key=="generator" and state.generatorProgressESP then
                    rec.text.Text=generatorProgress(rec)
                elseif rec.kind.key=="item" then
                    rec.text.Text="ITEM • "..rec.obj.Name
                else
                    rec.text.Text=rec.kind.name:upper()
                end
            end
            if rec.gui then
                rec.gui.MaxDistance=state.espDistance
                rec.gui.Enabled=showLabel
            end
            if rec.highlight then
                highlightStyle(rec.highlight,color)
                rec.highlight.Enabled=showOutline
            end
            if showLabel then
                occupied[cell]=true;labels+=1
            end
            if showOutline then highlights+=1 end
            rec.lastVisible=now
        end
    end
    -- Prune only inactive visuals; retain metadata so spawning hundreds of
    -- objects won't spawn hundreds of GUI instances.
    for _,rec in pairs(objectiveVisuals) do
        if rec.gui and now-rec.lastVisible>5 then
            destroyObjectiveNodes(rec)
        end
    end
    state.scanCandidates=cacheCount
    state.visibleLabels=labels
    state.visibleHighlights=highlights
end

local function stopSourceWatchers()
    for _,c in ipairs(sourceConnections) do c:Disconnect() end
    table.clear(sourceConnections)
end
local function startObjectiveScan()
    scanGeneration+=1
    local token=scanGeneration
    stopSourceWatchers()
    clearObjectives()
    currentMap=Workspace:FindFirstChild("Map")
    activeInteractables=Workspace:FindFirstChild("Interactables")
    state.scanScanned=0
    state.scanMapCount=0
    state.scanInteractableCount=0
    state.scanDurationMs=0
    lastObjectiveRefresh=0
    local sources={}
    if currentMap then sources[#sources+1]=currentMap end
    if activeInteractables and activeInteractables~=currentMap then
        sources[#sources+1]=activeInteractables
    end
    -- No round map means no active objective ESP; don't tag the lobby.
    if not currentMap then
        state.scanProgress="Waiting for Workspace.Map"
        activeInteractables=nil
        return
    end
    for _,source in ipairs(sources) do
        sourceConnections[#sourceConnections+1]=source.DescendantAdded:Connect(
            function(item) considerObjective(item) end)
        sourceConnections[#sourceConnections+1]=source.DescendantRemoving:Connect(
            function(item)
                if objectiveVisuals[item] then removeObjectiveRecord(item) end
            end)
    end
    state.scanProgress="Scanning Map + Interactables"
    task.spawn(function()
        local start=os.clock()
        for _,source in ipairs(sources) do
            local descendants=source:GetDescendants()
            state.scanScanned+=#descendants
            if source==currentMap then state.scanMapCount=#descendants
            else state.scanInteractableCount=#descendants end
            for i,node in ipairs(descendants) do
                if not state.alive or scanGeneration~=token then return end
                considerObjective(node)
                if i%120==0 then task.wait() end
            end
        end
        if not state.alive or scanGeneration~=token then return end
        state.scanDurationMs=math.floor((os.clock()-start)*1000)
        state.scanProgress="Map + Interactables ready"
    end)
end
connect(Workspace.ChildAdded,function(item)
    if item.Name=="Map" or item.Name=="Interactables" then
        task.defer(function()
            if state.alive then startObjectiveScan() end
        end)
    end
end)
connect(Workspace.ChildRemoved,function(item)
    if item==currentMap or item==activeInteractables then
        task.defer(function()
            if state.alive then startObjectiveScan() end
        end)
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






-- =========================================
-- Fluent menu - actual controls, not decorative rectangles.
-- =========================================
local statusMain=Tabs.Main:AddParagraph({
    Title="CURRENT SESSION",Content="Reading players and map..."
})
local statusKiller=Tabs.Main:AddParagraph({
    Title="KILLER DISTANCE",Content="Waiting for known killer..."
})
local statusSkill=Tabs.Main:AddParagraph({
    Title="SKILL CHECK",Content="UI not active"
})
local statusNext=Tabs.Main:AddParagraph({
    Title="NEXT KILLER (ESTIMATE)",Content="Waiting for lobby"
})
registerToggle(Tabs.Main,"PlayerESPMaster","Player ESP Master",
    "Overall player outlines / nametags switch","playerESP",
    function(value)
        if not value then
            for other in pairs(playerVisuals) do
                removePlayerVisual(other)
            end
        end
    end)
registerToggle(Tabs.Main,"ObjectESPMaster","Object ESP Master",
    "Show map object highlights and labels","objectiveESP",
    function() refreshObjectiveVisibility() end)

-- Player ESP: each category has a separate ON/OFF.
registerToggle(Tabs.Players,"KillerESP","Killer ESP",
    "Killer character outline + labels","killerESP")
registerColor(Tabs.Players,"KillerColor","Killer Outline Color","Killer")
registerToggle(Tabs.Players,"SurvivorESP","Survivor ESP",
    "Survivor character outline + labels","survivorESP")
registerColor(Tabs.Players,"SurvivorColor","Survivor Outline Color","Survivor")
registerToggle(Tabs.Players,"UnknownESP","Unknown Role Markers",
    "Disabled by default; prevents lobby role false positives","unknownESP")
registerToggle(Tabs.Players,"SurvivorItems","Survivor Held Item",
    "Show replicated Tool equipped by survivor (not world item ESP)",
    "survivorItemsESP")
registerToggle(Tabs.Players,"PlayerOutline","Outlines Enabled",
    "Use through-wall Highlight for players","playerHighlight")
registerToggle(Tabs.Players,"NameESP","Player Name Tags",
    "Show names and roles","playerNames")
registerToggle(Tabs.Players,"DistanceESP","Distance ESP",
    "Show stud distance on name tags","playerDistance")
registerToggle(Tabs.Players,"MaskESP","Killer Mask ESP",
    "Display replicated mask name","playerMask")
registerToggle(Tabs.Players,"ChasedESP","Chased Indicator",
    "Special marker for chased player","chaseStatus")
registerColor(Tabs.Players,"ChasedColor","Chased Indicator Color","Chased")
registerToggle(Tabs.Players,"KnockedESP","Knocked Indicator",
    "Show knocked status","knockedStatus")
registerColor(Tabs.Players,"KnockedColor","Knocked Indicator Color","Knocked")
registerToggle(Tabs.Players,"HookedESP","Hooked Indicator",
    "Show hooked status","hookedStatus")
registerColor(Tabs.Players,"HookedColor","Hooked Indicator Color","Hooked")
registerToggle(Tabs.Players,"OffscreenESP","Off-Screen Pointers",
    "Display directions near screen edges","offscreenESP")
registerToggle(Tabs.Players,"KillerWarn","Killer Proximity Alert",
    "Notify when known killer is less than 99 studs","killerAlert")

-- Object ESP: separate toggle and color selector per kind.
registerToggle(Tabs.Objects,"ObjectOutline","Object Outlines",
    "Enable object Highlight outlines / fill","objectHighlight",
    function() refreshObjectiveVisibility() end)
registerToggle(Tabs.Objects,"GeneratorESP","Generator ESP",
    "Generator highlight + location","generatorESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"GeneratorColor","Generator Outline Color","Generator")
registerToggle(Tabs.Objects,"GenProgress","Generator Repair %",
    "Show replicated repair percent","generatorProgressESP",
    function() refreshObjectiveVisibility() end)
registerToggle(Tabs.Objects,"PalletESP","Pallet ESP",
    "Both Pallet / Palletwrong","palletESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"PalletColor","Pallet Outline Color","Pallet")
registerToggle(Tabs.Objects,"WindowESP","Window ESP",
    "Window map objects","windowESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"WindowColor","Window Outline Color","Window")
registerToggle(Tabs.Objects,"HookESP","Hook ESP",
    "Map Hook models","hookESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"HookColor","Hook Outline Color","Hook")
registerToggle(Tabs.Objects,"GateESP","Gate ESP",
    "Exit gates","gateESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"GateColor","Gate Outline Color","Gate")
Tabs.Objects:AddButton({
    Title="Rescan Map",Description="Refresh Workspace map references",
    Callback=function() startObjectiveScan() end
})
local objectStatus=Tabs.Objects:AddParagraph({
    Title="WORLD ESP V2",Content="Waiting for active map..."
})
local perfStatus=Tabs.Objects:AddParagraph({
    Title="WORLD ESP DIAGNOSTICS",
    Content="Map status, cache, visible labels, highlights and FPS"
})
registerToggle(Tabs.Objects,"ObjectLabels","Objective Nametags",
    "Display labels without crowding the screen","objectLabels",
    function() lastObjectiveRefresh=0;refreshObjectiveVisibility() end)
registerSlider(Tabs.Objects,"MaxLabels","Maximum Object Labels",
    "Render nearest prioritized labels; 0 hides labels",
    state.maxWorldLabels,0,40,0,
    function(v)
        state.maxWorldLabels=v
        lastObjectiveRefresh=0
        refreshObjectiveVisibility()
    end)
registerSlider(Tabs.Objects,"MaxHighlights","Maximum Object Highlights",
    "Caps simultaneous highlights to protect FPS (max 26)",
    state.maxWorldHighlights,0,26,0,
    function(v)
        state.maxWorldHighlights=v
        lastObjectiveRefresh=0
        refreshObjectiveVisibility()
    end)
registerSlider(Tabs.Objects,"ESPRange","ESP Distance",
    "Max object and player visibility range (studs)",
    state.espDistance,100,2000,0,
    function(v) state.espDistance=v;refreshObjectiveVisibility() end)
local hMode=Tabs.Objects:AddDropdown("HighlightMode",{
    Title="Highlight Mode",
    Description="Choose between outline, fill or both",
    Values={"Outline","Fill","Both"},Default=1,
    Callback=function(v)
        if v=="Outline" or v=="Fill" or v=="Both" then
            state.highlightMode=v
        end
    end
})
controls.HighlightMode=hMode

-- Survivor mechanics only where source references are available.
registerToggle(Tabs.Survivor,"MonitorSkill","Skill Check Monitor",
    "Read Line / Goal rotation from the game UI","skillMonitor")
registerToggle(Tabs.Survivor,"AutoSkillCheck","Auto Skill Check (experimental)",
    "Attempts mobile input; game acceptance cannot be confirmed","autoSkillCheck",
    function(v)
        state.inputStatus=v and "Enabled, awaiting a Skill Check"
            or "Disabled"
    end)
registerToggle(Tabs.Survivor,"NextKiller","Next Killer Estimate",
    "Based on AllowKiller and KillerChance","nextKiller")
local inputStatus=Tabs.Survivor:AddParagraph({
    Title="AUTO INPUT STATUS",Content="Auto input disabled"
})
local skillStatus=Tabs.Survivor:AddParagraph({
    Title="SKILL CHECK STATUS",Content="Reading..."
})

registerToggle(Tabs.Movement,"NoClip","NoClip",
    "Local collision override","noClip",
    function(v) setNoClip(v) end)
registerToggle(Tabs.Movement,"SpeedAssist","Speed Assist",
    "Maintain the requested WalkSpeed","speed",
    function(v) setSpeed(v) end)
registerSlider(Tabs.Movement,"SpeedValue","WalkSpeed",
    "Local Humanoid WalkSpeed (game may override)",
    state.speedValue,16,60,0,
    function(v) state.speedValue=v end)

registerToggle(Tabs.Visual,"Fullbright","Fullbright",
    "Lighten environment locally","fullbright",
    function() updateLighting() end)
registerToggle(Tabs.Visual,"NoFog","Remove Fog",
    "Reduce atmosphere density and fog","noFog",
    function() updateLighting() end)
registerSlider(Tabs.Visual,"CameraFov","Field of View",
    "Camera FOV in degrees",
    state.fov,60,110,0,
    function(v) state.fov=v;cameraFov() end)

-- Fluent owns the menu layout, theme picker and acrylic rendering.
local defMode=player:GetAttribute("GlassMode")
local glassMode=(typeof(defMode)=="string" and
    (defMode=="Frosted" or defMode=="Clear" or defMode=="Blur"))
    and defMode or "Frosted"
local function applyGlassMode(value:string)
    glassMode=value
    player:SetAttribute("GlassMode",glassMode)
    if value=="Frosted" then
        Fluent:ToggleAcrylic(true)
        Fluent:ToggleTransparency(false)
    elseif value=="Clear" then
        Fluent:ToggleAcrylic(false)
        Fluent:ToggleTransparency(true)
    else -- Blur / One UI
        Fluent:ToggleAcrylic(true)
        Fluent:ToggleTransparency(true)
    end
end
local modeDropdown=Tabs.Settings:AddDropdown("GlassMode",{
    Title="Glass Style",
    Description="Frosted / Clear / Blur (applied to Fluent Acrylic)",
    Values={"Frosted","Clear","Blur"},
    Default=glassMode,
    Callback=applyGlassMode
})
controls.GlassMode=modeDropdown
Tabs.Settings:AddParagraph({
    Title="RENDER LIMITS",
    Content="Acrylic depends on executor/graphics settings. True per-element blur is not a Roblox property."
})
Tabs.Settings:AddButton({
    Title="Unload Velion Hub",
    Description="Disconnect features and close the Fluent window",
    Callback=function()
        local f=environment.VelionVDCleanup
        if type(f)=="function" then f() end
    end
})
-- Optional config support only when the executor exposes filesystem APIs.
if type(isfolder)=="function" and type(makefolder)=="function" and
    type(readfile)=="function" and type(writefile)=="function" then
    local okModules,SaveManager,InterfaceManager=pcall(function()
        local base="https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/"
        return loadstring(game:HttpGet(base.."SaveManager.lua"))(),
            loadstring(game:HttpGet(base.."InterfaceManager.lua"))()
    end)
    if okModules and SaveManager and InterfaceManager then
        pcall(function()
            SaveManager:SetLibrary(Fluent)
            InterfaceManager:SetLibrary(Fluent)
            SaveManager:IgnoreThemeSettings()
            InterfaceManager:SetFolder("VelionDistrict")
            SaveManager:SetFolder("VelionDistrict/profiles")
            InterfaceManager:BuildInterfaceSection(Tabs.Settings)
            SaveManager:BuildConfigSection(Tabs.Settings)
            SaveManager:LoadAutoloadConfig()
        end)
    end
end
Window:SelectTab(1)
Fluent:Notify({
    Title="Velion District V4",
    Content="Fluent UI loaded: ESP toggles, outlines and color pickers.",
    Duration=5
})

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





-- Polling gameplay data at 4 Hz; UI paragraphs at 2 Hz.
-- FPS sample uses the existing Heartbeat connection (no extra render loop).
local lastTick=0
local lastUI=-1e9
local frameCounter=0
local fpsFrom=os.clock()
connect(RunService.Heartbeat,function()
    if not state.alive then return end
    frameCounter+=1
    local now=os.clock()
    if now-fpsFrom>=1 then
        state.fps=math.floor(frameCounter/math.max(.001,now-fpsFrom)+.5)
        fpsFrom=now
        frameCounter=0
    end
    if now-lastTick<.25 then return end
    lastTick=now
    updateNoClip()
    updateSpeed()
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local closest=math.huge
    local killerName=""
    local list=Players:GetPlayers()
    for _,other in ipairs(list) do
        if other~=player then
            if state.playerESP then ensurePlayerVisual(other) end
            if state.killerAlert and root then
                local role=roleOf(other)
                if role=="Killer" then
                    local target=other.Character and
                        other.Character:FindFirstChild("HumanoidRootPart")
                    if target then
                        local d=(root.Position-target.Position).Magnitude
                        if d<closest then closest=d;killerName=other.DisplayName end
                    end
                end
            end
        end
    end
    refreshObjectiveVisibility()
    local danger=state.killerAlert and closest<99
    alert.Visible=danger
    alert.Text=danger and ("KILLER NEARBY: "..killerName
        .." ("..math.floor(closest).." studs)") or ""
    alert.TextColor3=espColors.Killer
    if now-lastUI<.50 then return end
    lastUI=now
    local total=#list
    local near=danger and (killerName.." - "..math.floor(closest).." studs")
        or "Not detected / beyond 99 studs"
    local msg=total.." players  |  "..state.identifiedObjectives.." map objects"
    statusMain:SetDesc(msg)
    statusKiller:SetDesc(near)
    local team=player.Team and player.Team.Name:lower() or ""
    local lobby=(team:find("lobby",1,true)
        or team:find("spectator",1,true))~=nil
    statusNext:SetDesc(state.nextKiller
        and (lobby and estimateNextKiller() or "Available while in lobby")
        or "Disabled")
    local skill=state.skillMonitor and checkSkillUi() or "Monitor disabled"
    statusSkill:SetDesc(skill)
    objectStatus:SetDesc(state.scanProgress..
        " | "..state.identifiedObjectives.." cached objectives")
    perfStatus:SetDesc(string.format(
        "Map: %s | scanned: %d instances | scan: %d ms\n"
        .."Candidates: %d | active labels: %d/%d | highlights: %d/%d | FPS: %d",
        currentMap and currentMap:GetFullName() or "not loaded",
        state.scanScanned,state.scanDurationMs,state.scanCandidates,
        state.visibleLabels,state.maxWorldLabels,
        state.visibleHighlights,state.maxWorldHighlights,state.fps))
    skillStatus:SetDesc(skill)
    inputStatus:SetDesc(state.inputStatus)
end)

-- Keep experimental auto input isolated from ESP and do not infer success
-- from a pcall that merely attempted to send an event.
local tried=false
local touchId=10421
connect(RunService.Heartbeat,function()
    if not state.alive or not state.autoSkillCheck then
        tried=false;return
    end
    if not player.Team or player.Team.Name~="Survivors" then return end
    local prompt=playerGui:FindFirstChild("SkillCheckPromptGui")
    local check=prompt and prompt:FindFirstChild("Check")
    if not check or not check:IsA("GuiObject") or not check.Visible then
        tried=false;return
    end
    if tried then return end
    local line=check:FindFirstChild("Line")
    local goal=check:FindFirstChild("Goal")
    if not line or not goal or not line:IsA("GuiObject")
        or not goal:IsA("GuiObject") then
        state.inputStatus="Line or Goal GUI not found";return
    end
    local current=line.Rotation%360
    local ss=(goal.Rotation+101)%360
    local se=(goal.Rotation+115)%360
    if not ((ss>se and (current>=ss or current<=se))
        or (current>=ss and current<=se)) then return end
    tried=true
    local action:Instance?=playerGui
    for segment in string.gmatch("Survivor-mob.Controls.action.check","[^%.]+") do
        action=action and action:FindFirstChild(segment) or nil
    end
    if not action or not action:IsA("GuiObject") then
        state.inputStatus="Mobile action button missing";return
    end
    local ok,err=pcall(function()
        local input=game:GetService("VirtualInputManager")
        local inset=game:GetService("GuiService"):GetGuiInset()
        local p=action.AbsolutePosition
        local sz=action.AbsoluteSize
        local x=p.X+sz.X/2+inset.X
        local y=p.Y+sz.Y/2+inset.Y
        input:SendTouchEvent(touchId,0,x,y)
        task.delay(.04,function()
            if state.alive then
                pcall(function() input:SendTouchEvent(touchId,2,x,y) end)
            end
        end)
    end)
    state.inputStatus=ok and "Touch sent (not confirmed by game)" or
        ("Input unavailable: "..tostring(err):sub(1,95))
end)
connect(Players.PlayerRemoving,removePlayerVisual)
connect(Lighting.ChildAdded,function()
    if state.alive and (state.fullbright or state.noFog) then
        task.defer(updateLighting)
    end
end)
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
    if state.alive then cameraFov() end
end)

local function cleanup()
    if not state.alive then return end
    state.alive=false
    scanGeneration+=1
    stopSourceWatchers()
    for _,conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    for other in pairs(playerVisuals) do removePlayerVisual(other) end
    for obj,item in pairs(objectiveVisuals) do
        if item.gui then item.gui:Destroy() end
        if item.highlight then item.highlight:Destroy() end
        objectiveVisuals[obj]=nil
    end
    setNoClip(false)
    state.fullbright=false
    state.noFog=false
    updateLighting()
    if state.speed then setSpeed(false) end
    local camera=Workspace.CurrentCamera
    if camera then camera.FieldOfView=originalFOV end
    gui:Destroy()
    pcall(function() Fluent:Destroy() end)
    if environment.VelionVDCleanup==cleanup then
        environment.VelionVDCleanup=nil
    end
end
environment.VelionVDCleanup=cleanup
startObjectiveScan()
print("[Velion District V4.1] Map-scoped World ESP V2 enabled. Live game not tested.")
