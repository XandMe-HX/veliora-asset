--!strict
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
    killerAlert=true, offscreenESP=true, hidden=false, scanProgress="Starting",
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

-- Glass appearance values live in this typed table.
type ModeStyle = {
    Subtitle: string, BlurSize: number, Tint: Color3,
    Alpha: number, Border: Color3, BorderAlpha: number,
    Radius: number, SheenAlpha: number,
    Gradient: ColorSequence, Edge: ColorSequence
}
local Modes: {[string]: ModeStyle} = {
    Frosted = {
        Subtitle="Concept", BlurSize=24,
        Tint=Color3.fromRGB(55,57,55),Alpha=.28,
        Border=Color3.fromRGB(229,229,218),BorderAlpha=.5,
        Radius=29,SheenAlpha=.8,
        Gradient=ColorSequence.new(
            Color3.fromRGB(125,128,123),Color3.fromRGB(65,60,54)),
        Edge=ColorSequence.new(
            Color3.fromRGB(252,250,239),Color3.fromRGB(139,145,137))
    },
    Clear = {
        Subtitle="iOS", BlurSize=4,
        Tint=Color3.fromRGB(168,205,204),Alpha=.87,
        Border=Color3.fromRGB(255,255,255),BorderAlpha=.15,
        Radius=24,SheenAlpha=.71,
        Gradient=ColorSequence.new(
            Color3.fromRGB(226,253,247),Color3.fromRGB(160,139,113)),
        Edge=ColorSequence.new(
            Color3.fromRGB(255,255,255),Color3.fromRGB(135,158,159))
    },
    Blur = {
        Subtitle="One UI", BlurSize=14,
        Tint=Color3.fromRGB(151,123,99),Alpha=.51,
        Border=Color3.fromRGB(232,215,192),BorderAlpha=.61,
        Radius=34,SheenAlpha=.9,
        Gradient=ColorSequence.new(
            Color3.fromRGB(189,162,127),Color3.fromRGB(104,99,86)),
        Edge=ColorSequence.new(
            Color3.fromRGB(239,220,193),Color3.fromRGB(145,132,120))
    }
}
local names={"Frosted","Clear","Blur"}
local stored=player:GetAttribute("GlassMode")
local selectedMode=(typeof(stored)=="string" and Modes[stored])
    and stored or "Frosted"
local blur: BlurEffect?=nil
local blurCreated=false
for _,effect in ipairs(Lighting:GetChildren()) do
    if effect.Name=="GlassBlur" and effect:IsA("BlurEffect") then
        if not blur then blur=effect else effect:Destroy() end
    end
end
if not blur then
    blur=Instance.new("BlurEffect")
    blur.Name="GlassBlur"
    blur.Size=0
    blur.Parent=Lighting
    blurCreated=true
end
local priorBlurSize=blur.Size
local priorBlurEnabled=blur.Enabled
local blurTween: Tween?=nil
local sceneBlurEnabled=true
local function fadeBlur()
    if blurTween then blurTween:Cancel() end
    if not blur then return end
    blur.Enabled=true
    local goal=(state.expanded and sceneBlurEnabled and not state.hidden)
        and Modes[selectedMode].BlurSize or 0
    blurTween=TweenService:Create(blur,
        TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {Size=goal})
    blurTween:Play()
end
local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictHubV2",ResetOnSpawn=false,
    IgnoreGuiInset=false,DisplayOrder=800,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
pcall(function() gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
local function screenWidth(open: boolean): number
    local cam=Workspace.CurrentCamera
    local x=cam and cam.ViewportSize.X or 1280
    return math.min(open and 520 or 365, math.max(296,x-22))
end
local panel=create("Frame",gui,{
    Name="MiniHUD",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-16,0,16),
    Size=UDim2.fromOffset(screenWidth(false),334),
    BackgroundTransparency=1,BorderSizePixel=0,
    Active=true,ClipsDescendants=false
})
create("UISizeConstraint",panel,{
    MinSize=Vector2.new(296,320),MaxSize=Vector2.new(540,690)
})
local hudScale=create("UIScale",panel,{Scale=1})
local cardArea=create("Frame",panel,{
    Name="GlassModeSelector",Size=UDim2.new(1,0,0,236),
    BackgroundTransparency=1
})
local cards={}
local function makeCard(large: boolean)
    local frame=create("Frame",cardArea,{
        BackgroundColor3=Modes.Frosted.Tint,
        BackgroundTransparency=Modes.Frosted.Alpha,
        BorderSizePixel=0,ClipsDescendants=false
    })
    local corner=create("UICorner",frame,{CornerRadius=UDim.new(0,28)})
    local gradient=create("UIGradient",frame,{
        Color=Modes.Frosted.Gradient,Rotation=22,
        Offset=Vector2.new(-.15,0)
    })
    local stroke=create("UIStroke",frame,{
        Color=Modes.Frosted.Border,Transparency=Modes.Frosted.BorderAlpha,
        Thickness=1.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    })
    local edge=create("UIGradient",stroke,{
        Color=Modes.Frosted.Edge,Rotation=136,
        Offset=Vector2.new(-.15,-.15)
    })
    local inner=create("Frame",frame,{
        Position=UDim2.fromOffset(5,5),
        Size=UDim2.new(1,-10,1,-10),BackgroundTransparency=1
    })
    local innerCorner=create("UICorner",inner,{
        CornerRadius=UDim.new(0,24)
    })
    local innerStroke=create("UIStroke",inner,{
        Thickness=.75,Color=Color3.new(1,1,1),
        Transparency=.82,ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    })
    local sheen=create("Frame",frame,{
        Position=UDim2.fromOffset(9,9),Size=UDim2.new(1,-18,.46,0),
        BackgroundColor3=Color3.fromRGB(251,249,245),
        BackgroundTransparency=.8,BorderSizePixel=0
    })
    local sheenCorner=create("UICorner",sheen,{
        CornerRadius=UDim.new(0,22)
    })
    local sheenGradient=create("UIGradient",sheen,{
        Color=ColorSequence.new(
            Color3.fromRGB(255,255,255),Color3.fromRGB(111,118,119)),
        Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.1),
            NumberSequenceKeypoint.new(1,.98)
        }),
        Rotation=91,Offset=Vector2.new(-.16,-.2)
    })
    local title=label(frame,"Frosted",0,0,100,50,large and 37 or 24,
        Color3.new(1,1,1))
    title.Font=Enum.Font.GothamMedium
    title.TextScaled=true
    title.TextXAlignment=Enum.TextXAlignment.Center
    title.Size=UDim2.new(1,-36,0,large and 63 or 39)
    title.Position=UDim2.new(0,18,0,large and 24 or 8)
    create("UITextSizeConstraint",title,{
        MinTextSize=large and 20 or 15,
        MaxTextSize=large and 45 or 27
    })
    create("UIStroke",title,{
        Color=Color3.fromRGB(20,20,20),Thickness=.6,Transparency=.87
    })
    local subtitle=label(frame,"Concept",0,0,100,22,large and 14 or 12,
        Color3.new(1,1,1))
    subtitle.Font=Enum.Font.GothamMedium
    subtitle.TextXAlignment=Enum.TextXAlignment.Center
    subtitle.TextScaled=true
    subtitle.Position=UDim2.new(0,18,0,large and 91 or 52)
    subtitle.Size=UDim2.new(1,-36,0,large and 22 or 19)
    create("UITextSizeConstraint",subtitle,{
        MinTextSize=10,MaxTextSize=large and 15 or 13
    })
    local hit=button(frame,"",0,0,100,100)
    hit.BackgroundTransparency=1
    hit.Size=UDim2.fromScale(1,1)
    hit.ZIndex=15
    local scale=create("UIScale",frame,{Scale=1})
    local card={frame=frame,corner=corner,gradient=gradient,
        stroke=stroke,edge=edge,innerCorner=innerCorner,
        innerStroke=innerStroke,sheen=sheen,sheenCorner=sheenCorner,
        sheenGradient=sheenGradient,title=title,subtitle=subtitle,
        hit=hit,scale=scale,mode="Frosted"}
    cards[#cards+1]=card
    return card
end
local hero=makeCard(true)
local second=makeCard(false)
local third=makeCard(false)
hero.frame.Position=UDim2.new(.025,0,0,9)
hero.frame.Size=UDim2.new(.95,0,0,122)
second.frame.Position=UDim2.new(.025,0,0,145)
second.frame.Size=UDim2.new(.463,0,0,83)
third.frame.Position=UDim2.new(.512,0,0,145)
third.frame.Size=UDim2.new(.463,0,0,83)
-- Use a size/aspect constraint on a small decorative high-gloss dot.
local dot=create("Frame",panel,{
    Position=UDim2.new(1,-155,0,22),
    Size=UDim2.fromOffset(12,12),BackgroundColor3=Color3.new(1,1,1),
    BackgroundTransparency=.6,ZIndex=25
})
round(dot,99)
create("UIAspectRatioConstraint",dot,{AspectRatio=1})
local expand=button(panel,"+",0,0,44,44)
expand.Name="Expand"
expand.Position=UDim2.new(1,-105,0,13)
expand.ZIndex=32
expand.BackgroundTransparency=.42
local close=button(panel,"X",0,0,44,44)
close.Position=UDim2.new(1,-55,0,13)
close.ZIndex=32
close.BackgroundColor3=Color3.fromRGB(72,48,48)
close.BackgroundTransparency=.3
local hudStatus=label(panel,"PLAYERS --  |  OBJECTIVES --  |  KILLER --",
    10,236,325,27,11,palette.white)
hudStatus.Position=UDim2.new(.025,0,0,236)
hudStatus.Size=UDim2.new(.95,0,0,28)
hudStatus.Font=Enum.Font.GothamMedium
local quickESP=button(panel,"PLAYER ESP: OFF",0,0,100,48)
quickESP.Position=UDim2.new(.025,0,0,276)
quickESP.Size=UDim2.new(.463,0,0,48)
local quickAlert=button(panel,"KILLER ALERT: ON",0,0,100,48)
quickAlert.Position=UDim2.new(.512,0,0,276)
quickAlert.Size=UDim2.new(.463,0,0,48)
quickESP.TextSize=11
quickAlert.TextSize=11

local expandedBody=create("ScrollingFrame",panel,{
    Name="FeatureDashboard",Position=UDim2.fromOffset(0,338),
    Size=UDim2.new(1,0,1,-338),
    BackgroundTransparency=1,Visible=false,
    BorderSizePixel=0,ScrollBarThickness=3,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.fromOffset(0,327)
})
local tabScroll=create("ScrollingFrame",expandedBody,{
    Position=UDim2.new(.025,0,0,0),Size=UDim2.new(.95,0,0,53),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=2,ScrollingDirection=Enum.ScrollingDirection.X,
    CanvasSize=UDim2.fromOffset(560,0)
})
local contents=create("Frame",expandedBody,{
    Position=UDim2.new(.025,0,0,61),
    Size=UDim2.new(.95,0,0,240),
    BackgroundColor3=Color3.fromRGB(38,40,39),
    BackgroundTransparency=.17,BorderSizePixel=0
})
round(contents,18)
create("UIStroke",contents,{
    Color=Color3.fromRGB(221,218,208),
    Transparency=.72,Thickness=.8
})
local footer=label(expandedBody,"RIGHT CTRL  show/hide  |  X  unload",
    12,307,400,18,10,palette.muted)
footer.Position=UDim2.new(.025,0,0,307)
footer.Size=UDim2.new(.95,0,0,18)
local pages,nav={},{}
local function makePage(name: string)
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
local tabs={"Dashboard","ESP","Movement","Objectives","Settings"}
local function choosePage(name: string)
    state.activeTab=name
    for n,p in pairs(pages) do p.Visible=n==name end
    for n,btn in pairs(nav) do
        btn.BackgroundColor3=(n==name) and Color3.fromRGB(84,87,83)
            or Color3.fromRGB(47,50,48)
    end
end
for i,name in ipairs(tabs) do
    local tab=button(tabScroll,name,(i-1)*110,2,104,47)
    nav[name]=tab
    tab.TextSize=11
    connect(tab.MouseButton1Click,function() choosePage(name) end)
end
local function sectionTitle(page: any,title: string)
    local t=label(page,title,13,2,310,26,14,palette.white)
    t.Font=Enum.Font.GothamMedium
end
sectionTitle(dashboard,"DASHBOARD")
sectionTitle(visual,"VISUAL & ESP")
sectionTitle(playerPage,"MOVEMENT")
sectionTitle(objectivesPage,"MAP OBJECTIVES")
sectionTitle(settingsPage,"GLASS SETTINGS")

local redrawQuick: () -> () = function() end
local redrawers: {() -> ()}={}
local function toggle(parent: any,name: string,y: number,get: () -> boolean,set: (boolean) -> ())
    local control=button(parent,name,0,y,100,42)
    control.Position=UDim2.new(.03,0,0,y)
    control.Size=UDim2.new(.94,0,0,44)
    control.TextXAlignment=Enum.TextXAlignment.Left
    control.TextSize=11
    create("UIPadding",control,{PaddingLeft=UDim.new(0,12)})
    local result=label(control,"OFF",0,0,45,43,11,palette.muted)
    result.Position=UDim2.new(1,-50,0,0)
    result.TextXAlignment=Enum.TextXAlignment.Center
    local function redraw()
        local on=get()
        control.BackgroundColor3=on and Color3.fromRGB(57,83,73)
            or Color3.fromRGB(48,51,49)
        result.Text=on and "ON" or "OFF"
        result.TextColor3=on and palette.green or palette.muted
    end
    redrawers[#redrawers+1]=redraw
    connect(control.MouseButton1Click,function()
        set(not get())
        redrawQuick()
    end)
    redraw()
    return redraw
end
redrawQuick=function()
    quickESP.Text="PLAYER ESP: "..(state.playerESP and "ON" or "OFF")
    quickAlert.Text="KILLER ALERT: "..(state.killerAlert and "ON" or "OFF")
    quickESP.BackgroundColor3=state.playerESP
        and Color3.fromRGB(54,87,71) or Color3.fromRGB(45,50,46)
    quickAlert.BackgroundColor3=state.killerAlert
        and Color3.fromRGB(54,87,71) or Color3.fromRGB(45,50,46)
    for _,redraw in ipairs(redrawers) do redraw() end
end

local animations: {Tween}={}
local function animate(instance: Instance, props: {[string]: any})
    local tween=TweenService:Create(instance,
        TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        props)
    animations[#animations+1]=tween
    tween:Play()
end
local function renderCard(card: any,name: string,active: boolean)
    local cfg=Modes[name]
    card.mode=name
    card.title.Text=name
    card.subtitle.Text=cfg.Subtitle
    card.corner.CornerRadius=UDim.new(0,cfg.Radius)
    card.innerCorner.CornerRadius=UDim.new(0,cfg.Radius-5)
    card.sheenCorner.CornerRadius=UDim.new(0,cfg.Radius-4)
    card.gradient.Color=cfg.Gradient
    card.edge.Color=cfg.Edge
    animate(card.frame,{BackgroundColor3=cfg.Tint,
        BackgroundTransparency=cfg.Alpha})
    animate(card.stroke,{Color=active and Color3.fromRGB(255,255,249)
        or cfg.Border,Transparency=active
        and math.max(0,cfg.BorderAlpha-.22) or cfg.BorderAlpha,
        Thickness=active and 1.65 or 1.15})
    animate(card.innerStroke,{Transparency=active and .58 or .86})
    animate(card.sheen,{BackgroundTransparency=cfg.SheenAlpha})
    animate(card.gradient,{Offset=active and Vector2.new(0,.08)
        or Vector2.new(-.14,-.06)})
    animate(card.edge,{Offset=active and Vector2.new(.14,0)
        or Vector2.new(-.14,0)})
    animate(card.scale,{Scale=active and 1.03 or 1})
    animate(card.title,{TextColor3=Color3.fromRGB(255,255,255)})
    animate(card.subtitle,{TextColor3=Color3.fromRGB(255,255,255)})
end
local function setMode(name: string)
    if not Modes[name] then return end
    selectedMode=name
    player:SetAttribute("GlassMode",name)
    for _,animation in ipairs(animations) do animation:Cancel() end
    table.clear(animations)
    local others={}
    for _,n in ipairs(names) do
        if n~=name then others[#others+1]=n end
    end
    renderCard(hero,name,true)
    renderCard(second,others[1],false)
    renderCard(third,others[2],false)
    panel:SetAttribute("ActiveGlassMode",name)
    fadeBlur()
end
for _,card in ipairs(cards) do
    connect(card.hit.MouseButton1Click,function() setMode(card.mode) end)
end
local widthTween: Tween?=nil
local function keepOnScreen()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local viewport=cam.ViewportSize
    local right=panel.AbsolutePosition.X+panel.AbsoluteSize.X
    local target=math.clamp(right,
        math.min(viewport.X-4,panel.AbsoluteSize.X+4),viewport.X-4)
    local top=math.clamp(panel.AbsolutePosition.Y,4,
        math.max(4,viewport.Y-55))
    panel.Position=UDim2.fromOffset(target,top)
end
local function setExpanded(open: boolean)
    state.expanded=open
    expandedBody.Visible=open
    expand.Text=open and "-" or "+"
    if widthTween then widthTween:Cancel() end
    local camera=Workspace.CurrentCamera
    local screenHeight=camera and camera.ViewportSize.Y or 800
    local availableHeight=math.max(455,screenHeight-70)
    local expandedHeight=math.min(670,availableHeight)
    widthTween=TweenService:Create(panel,
        TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {Size=UDim2.fromOffset(screenWidth(open),open and expandedHeight or 334)})
    widthTween:Play()
    fadeBlur()
    task.delay(.37,function()
        if state.alive then keepOnScreen() end
    end)
end
connect(expand.MouseButton1Click,function()
    setExpanded(not state.expanded)
end)
local restore=button(gui,"GLASS",0,0,73,47)
restore.Name="RestoreGlass"
restore.Position=UDim2.new(1,-88,0,18)
restore.Visible=false
restore.TextSize=11
connect(restore.MouseButton1Click,function()
    panel.Visible=true
    state.hidden=false
    restore.Visible=false
    fadeBlur()
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

-- Original game callbacks are retained below; every button is functional.
toggle(visual,"PLAYER ESP",30,
    function() return state.playerESP end,
    function(v)
        state.playerESP=v
        if not v then
            for p in pairs(playerVisuals) do removePlayerVisual(p) end
        end
    end)
toggle(visual,"OBJECTIVE ESP",74,
    function() return state.objectiveESP end,
    function(v) state.objectiveESP=v;refreshObjectiveVisibility() end)
toggle(visual,"FULLBRIGHT",118,
    function() return state.fullbright end,
    function(v) state.fullbright=v;updateLighting() end)
toggle(visual,"NO FOG",162,
    function() return state.noFog end,
    function(v) state.noFog=v;updateLighting() end)
local fov=button(visual,"CAMERA FOV: 70",0,206,100,44)
fov.Position=UDim2.new(.03,0,0,206)
fov.Size=UDim2.new(.94,0,0,44)
connect(fov.MouseButton1Click,function()
    local options={[70]=85,[85]=100,[100]=70}
    state.fov=options[state.fov] or 70
    fov.Text="CAMERA FOV: "..state.fov
    cameraFov()
end)

toggle(playerPage,"NOCLIP",30,
    function() return state.noClip end,setNoClip)
toggle(playerPage,"SPEED ASSIST",74,
    function() return state.speed end,setSpeed)
local speedButton=button(playerPage,"SPEED VALUE: 24",0,118,100,44)
speedButton.Position=UDim2.new(.03,0,0,118)
speedButton.Size=UDim2.new(.94,0,0,44)
connect(speedButton.MouseButton1Click,function()
    local options={[24]=28,[28]=32,[32]=20,[20]=24}
    state.speedValue=options[state.speedValue] or 24
    speedButton.Text="SPEED VALUE: "..state.speedValue
end)
toggle(playerPage,"KILLER PROXIMITY ALERT",162,
    function() return state.killerAlert end,
    function(v) state.killerAlert=v end)
toggle(playerPage,"OFFSCREEN INDICATORS",206,
    function() return state.offscreenESP end,
    function(v) state.offscreenESP=v end)

local homeCounts=label(dashboard,"Players: --  /  Objectives: --",
    13,29,300,34,15,palette.white)
homeCounts.Size=UDim2.new(.94,0,0,34)
local homeKiller=label(dashboard,"Killer: checking",
    13,67,300,28,12,palette.muted)
homeKiller.Size=UDim2.new(.94,0,0,28)
local homeSkill=label(dashboard,"Skill Check: waiting",
    13,98,300,46,11,palette.muted)
homeSkill.Size=UDim2.new(.94,0,0,46)
toggle(dashboard,"PLAYER ESP",154,
    function() return state.playerESP end,
    function(v)
        state.playerESP=v
        if not v then
            for p in pairs(playerVisuals) do removePlayerVisual(p) end
        end
    end)
toggle(dashboard,"OBJECTIVE ESP",198,
    function() return state.objectiveESP end,
    function(v) state.objectiveESP=v;refreshObjectiveVisibility() end)

local refreshButton=button(objectivesPage,"REFRESH OBJECTIVES",0,32,100,46)
refreshButton.Position=UDim2.new(.03,0,0,32)
refreshButton.Size=UDim2.new(.94,0,0,46)
connect(refreshButton.MouseButton1Click,startObjectiveScan)
local objectiveInfo=label(objectivesPage,"Scanning Workspace.Map",
    13,80,300,85,11,palette.muted)
objectiveInfo.Size=UDim2.new(.94,0,0,89)
local skillInfo=label(objectivesPage,"Skill Check: Waiting for GUI",
    13,167,300,70,11,palette.muted)
skillInfo.Size=UDim2.new(.94,0,0,65)

toggle(settingsPage,"SCENE BLUR (FULL SCREEN)",30,
    function() return sceneBlurEnabled end,
    function(v) sceneBlurEnabled=v;fadeBlur() end)
local scaleButton=button(settingsPage,"HUD SCALE: 100%",0,77,100,44)
scaleButton.Position=UDim2.new(.03,0,0,77)
scaleButton.Size=UDim2.new(.94,0,0,44)
local scales={1,.9,.8}
local scaleIndex=1
connect(scaleButton.MouseButton1Click,function()
    scaleIndex=scaleIndex%#scales+1
    hudScale.Scale=scales[scaleIndex]
    scaleButton.Text="HUD SCALE: "..math.floor(scales[scaleIndex]*100).."%"
    task.defer(keepOnScreen)
end)
local reset=button(settingsPage,"RESET HUD POSITION",0,122,100,44)
reset.Position=UDim2.new(.03,0,0,122)
reset.Size=UDim2.new(.94,0,0,44)
connect(reset.MouseButton1Click,function()
    panel.Position=UDim2.new(1,-16,0,16)
    task.defer(keepOnScreen)
end)
local collapse=button(settingsPage,"RETURN TO MINI HUD",0,169,100,44)
collapse.Position=UDim2.new(.03,0,0,169)
collapse.Size=UDim2.new(.94,0,0,44)
connect(collapse.MouseButton1Click,function() setExpanded(false) end)
label(settingsPage,
    "Global blur, not per-panel  |  Player.GlassMode",
    13,216,310,22,10,palette.muted)
connect(quickESP.MouseButton1Click,function()
    state.playerESP=not state.playerESP
    if not state.playerESP then
        for p in pairs(playerVisuals) do removePlayerVisual(p) end
    end
    redrawQuick()
end)
connect(quickAlert.MouseButton1Click,function()
    state.killerAlert=not state.killerAlert
    redrawQuick()
end)
choosePage("Dashboard")
redrawQuick()
setMode(selectedMode)


local alert=create("TextLabel",gui,{
    Name="KillerWarning",AnchorPoint=Vector2.new(.5,0),
    Position=UDim2.new(.5,0,0,10),
    Size=UDim2.new(.65,0,0,44),
    Text="",Visible=false,Font=Enum.Font.GothamMedium,TextSize=15,
    TextScaled=false,TextColor3=palette.red,
    BackgroundColor3=Color3.fromRGB(35,30,31),
    BackgroundTransparency=.35,BorderSizePixel=0,
    TextStrokeTransparency=.8
})
create("UISizeConstraint",alert,{
    MinSize=Vector2.new(220,44),MaxSize=Vector2.new(460,44)
})
round(alert,20)
create("UIStroke",alert,{
    Color=Color3.fromRGB(229,199,186),Transparency=.62,Thickness=1
})
create("UIGradient",alert,{
    Color=Modes.Blur.Gradient,Rotation=10
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
    alert.Visible=(alert.Text~="")
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
    local dangerous=(state.killerAlert and closestKiller<99)
    local killerText=dangerous
        and ("KILLER NEARBY: "..math.floor(closestKiller).." studs")
        or "KILLER: CLEAR / UNKNOWN"
    footer.Text="Players: "..totalPlayers.."  |  Objectives: "
        ..state.identifiedObjectives..speedState.." | RIGHT CTRL: HIDE"
    hudStatus.Text=string.format("PLAYERS %d | OBJECTIVES %d | %s",
        totalPlayers,state.identifiedObjectives,
        dangerous and "KILLER NEARBY" or "CLEAR / UNKNOWN")
    hudStatus.TextColor3=dangerous and palette.red or palette.white
    homeCounts.Text=string.format("%d PLAYERS / %d OBJECTIVES",
        totalPlayers,state.identifiedObjectives)
    homeKiller.Text=killerText
    homeKiller.TextColor3=dangerous and palette.red or palette.muted
    homeSkill.Text=checkSkillUi()
    local wanted=screenWidth(state.expanded)
    if (not widthTween or widthTween.PlaybackState~=Enum.PlaybackState.Playing)
        and math.abs(panel.Size.X.Offset-wanted)>2 then
        panel.Size=UDim2.fromOffset(wanted,panel.Size.Y.Offset)
        keepOnScreen()
    end
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
-- Replaces old drag, minimize and hotkey listeners.
local dragging=false
local dragInput: InputObject?=nil
local dragStart=Vector3.zero
local dragOrigin=UDim2.new()
connect(hero.hit.InputBegan,function(input: InputObject)
    if input.UserInputType==Enum.UserInputType.MouseButton1
        or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        dragInput=input
        dragStart=input.Position
        dragOrigin=panel.Position
    end
end)
connect(UserInputService.InputChanged,function(input: InputObject)
    if dragging and (input==dragInput
        or input.UserInputType==Enum.UserInputType.MouseMovement) then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+d.X,
            dragOrigin.Y.Scale,dragOrigin.Y.Offset+d.Y)
    end
end)
connect(UserInputService.InputEnded,function(input: InputObject)
    if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
        dragInput=nil
        keepOnScreen()
    end
end)
connect(UserInputService.InputBegan,function(input: InputObject,processed: boolean)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
        state.hidden=not panel.Visible
        restore.Visible=state.hidden
        fadeBlur()
    end
end)


local function cleanup()
    if not state.alive then return end
    state.alive=false
    scanGeneration+=1
    if widthTween then widthTween:Cancel() end
    if blurTween then blurTween:Cancel() end
    for _,t in ipairs(animations) do pcall(function() t:Cancel() end) end
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
    if blur and blur.Parent then
        if blurCreated then blur:Destroy()
        else
            blur.Size=priorBlurSize
            blur.Enabled=priorBlurEnabled
        end
    end
    if environment.VelionVDCleanup==cleanup then
        environment.VelionVDCleanup=nil
    end
end
environment.VelionVDCleanup=cleanup
connect(close.MouseButton1Click,cleanup)
choosePage("Visual")
startObjectiveScan()
print("[Velion Glass V2.2] Frosted/Clear/Blur installed. Roblox Studio runtime not tested.")
