--!strict
--[[
    VELION DISTRICT HUB V4.0 - FLUENT UI
    For Roblox Violence District - client-side utility module.
    Clean, readable Luau. No external UI libraries, telemetry or extra loaders.
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
    killerESP=true, survivorESP=true, playerNames=true, playerDistance=true,
    playerMask=true, chaseStatus=true, knockedStatus=true, hookedStatus=true,
    playerHighlight=true, highlightMode="Outline", nextKiller=true, skillMonitor=true,
    autoSkillCheck=false, inputStatus="No action attempted",
    generatorESP=true, palletESP=true, windowESP=true, hookESP=true,
    gateESP=true, generatorProgressESP=true, espDistance=650,
    identifiedObjectives=0, unknownRoles=0,
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
    Size=UDim2.fromOffset(410,43),
    TextColor3=espColors.Killer,TextSize=14,
    Font=Enum.Font.GothamBold,
    BackgroundColor3=Color3.fromRGB(26,28,33),
    BackgroundTransparency=.15,BorderSizePixel=0,
    TextStrokeTransparency=.6
})
round(alert,12)
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
        SubTitle="V4.0 / Fluent Hub",
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
local function setState(key:string,value:boolean)
    state[key]=value
    for _,control in pairs(toggles) do
        if control._stateKey==key then
            pcall(function() control:SetValue(value) end)
        end
    end
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
            MaxDistance=650,ResetOnSpawn=false
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
    local role,color=roleOf(other)
    if (role=="Killer" and not state.killerESP) or
        (role=="Survivor" and not state.survivorESP) then
        removePlayerVisual(other)
        return
    end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=character:FindFirstChild("HumanoidRootPart")
    local distance=(root and targetRoot)
        and math.floor((root.Position-targetRoot.Position).Magnitude) or nil
    local isHooked=gameValue(character,"IsHooked")==true
    local isKnocked=gameValue(character,"Knocked")==true
    local isChased=gameValue(character,"IsChased")==true
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

local objectiveKinds={
    {key="generator",title="GENERATOR",color=Color3.fromRGB(150,0,200)},
    {key="palletwrong",title="PALLET",color=Color3.fromRGB(74,255,181)},
    {key="pallet",title="PALLET",color=Color3.fromRGB(74,255,181)},
    {key="window",title="WINDOW",color=Color3.fromRGB(74,255,181)},
    {key="hook",title="HOOK",color=Color3.fromRGB(132,255,169)},
    {key="gate",title="GATE",color=Color3.fromRGB(255,255,255)}
}
local function objectiveEnabled(kind: string): boolean
    if kind=="generator" then return state.generatorESP end
    if kind=="palletwrong" or kind=="pallet" then return state.palletESP end
    if kind=="window" then return state.windowESP end
    if kind=="hook" then return state.hookESP end
    if kind=="gate" then return state.gateESP end
    return true
end
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
    local kind=classify(candidate)
    if not kind then return end
    local map=Workspace:FindFirstChild("Map")
    if not map or (not candidate:IsDescendantOf(map) and
        kind.key~="window") then return end
    local obj,part=resolveObjective(candidate,kind)
    if not obj or not part or objectiveVisuals[obj] then return end
    if state.identifiedObjectives>=90 then return end
    local outline=create("Highlight",Workspace,{
        Name="VelionVDObjectiveOutline",Adornee=obj,
        Enabled=state.objectiveESP and objectiveEnabled(kind.key),
        FillColor=categoryColor(kind.key),OutlineColor=categoryColor(kind.key),
        FillTransparency=.86,OutlineTransparency=.15,
        DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    })
    local billboard=create("BillboardGui",playerGui,{
        Name="VelionVDObjective",Adornee=part,
        Size=UDim2.fromOffset(168,26),AlwaysOnTop=true,
        MaxDistance=state.espDistance,
        Enabled=state.objectiveESP and objectiveEnabled(kind.key),
        StudsOffsetWorldSpace=Vector3.new(0,3.2,0)
    })
    local tag=label(billboard,kind.title,0,0,168,26,12,categoryColor(kind.key))
    tag.TextStrokeTransparency=.2
    tag.TextXAlignment=Enum.TextXAlignment.Center
    objectiveVisuals[obj]={gui=billboard,highlight=outline,kind=kind,part=part,text=tag}
    state.identifiedObjectives+=1
end
local function refreshObjectiveVisibility()
    for object,v in pairs(objectiveVisuals) do
        if object.Parent and v.part.Parent then
            local show=state.objectiveESP and objectiveEnabled(v.kind.key)
            v.gui.Enabled=show
            if v.highlight then v.highlight.Enabled=show end
            v.gui.MaxDistance=state.espDistance
            local ownRoot=player.Character and
                player.Character:FindFirstChild("HumanoidRootPart")
            local within=(not ownRoot or
                (ownRoot.Position-v.part.Position).Magnitude<=state.espDistance)
            if v.highlight then
                v.highlight.Enabled=show and within and state.playerHighlight
                highlightStyle(v.highlight,categoryColor(v.kind.key))
            end
            v.text.Text=v.kind.title
            v.text.TextColor3=categoryColor(v.kind.key)
            if v.kind.key=="generator" and state.generatorProgressESP then
                local percent=tonumber(gameValue(object,"RepairProgress")
                    or gameValue(object,"Progress"))
                if percent then
                    local cp=math.clamp(percent,0,100)
                    v.text.Text=string.format("GENERATOR %.1f%%",cp)
                    v.text.TextColor3=categoryColor(v.kind.key)
                else
                    v.text.Text="GENERATOR (progress unknown)"
                end
            end
        else
            v.gui:Destroy()
            if v.highlight then v.highlight:Destroy() end
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
        local objects=Workspace:GetDescendants()
        state.scanProgress="Analyzing: "..#objects.." objects"
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
        if visual.highlight then visual.highlight:Destroy() end
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
    Title="OBJECT DETECTION",Content="Scanning Workspace..."
})
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
local lastTick=0
local lastUI=-1e9
connect(RunService.Heartbeat,function()
    if not state.alive then return end
    local now=os.clock()
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
    objectStatus:SetDesc(state.scanProgress.." | "..state.identifiedObjectives.." found")
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
print("[Velion District V4.0 Fluent] Loaded (runtime gameplay not verified).")
