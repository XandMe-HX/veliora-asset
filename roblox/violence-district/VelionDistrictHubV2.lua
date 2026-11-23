--!strict
--[[
    VELION DISTRICT HUB V3.0 - GLASS FEATURE HUB
    For Roblox Violence District - client-side utility module.
    Clean, readable Luau. No external UI libraries, telemetry or extra loaders.
    IMPORTANT: Does not spoof server state or grant server-side immunity.
    UI design uses Frosted/Clear/Blur as themes, not giant selector cards.
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
    alive=true, playerESP=false, objectiveESP=false,
    fullbright=false, noFog=false, noClip=false,
    speed=false, speedValue=24, fov=70,
    killerAlert=true, offscreenESP=true, hidden=false, scanProgress="Starting",
    expanded=true, activeTab="Home", sceneBlur=false,
    killerESP=true, survivorESP=true, playerNames=true, playerDistance=true,
    playerMask=true, chaseStatus=true, knockedStatus=true, hookedStatus=true,
    playerHighlight=true, nextKiller=true, skillMonitor=true,
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
type GlassMode = {
    Subtitle: string, Tint: Color3, TintDark: Color3,
    Transparency: number, Rim: Color3, RimTransparency: number,
    Radius: number, Blur: number, Sheen: number,
}
local Modes: {[string]: GlassMode} = {
    Frosted={
        Subtitle="Concept", Tint=Color3.fromRGB(64,66,62),
        TintDark=Color3.fromRGB(29,31,30),Transparency=.20,
        Rim=Color3.fromRGB(234,233,224),RimTransparency=.47,
        Radius=23,Blur=24,Sheen=.84,
    },
    Clear={
        Subtitle="iOS",Tint=Color3.fromRGB(178,211,206),
        TintDark=Color3.fromRGB(52,76,78),Transparency=.79,
        Rim=Color3.fromRGB(255,255,255),RimTransparency=.18,
        Radius=25,Blur=4,Sheen=.72,
    },
    Blur={
        Subtitle="One UI",Tint=Color3.fromRGB(139,116,98),
        TintDark=Color3.fromRGB(65,57,54),Transparency=.42,
        Rim=Color3.fromRGB(236,222,204),RimTransparency=.58,
        Radius=28,Blur=14,Sheen=.89,
    }
}
local savedMode=player:GetAttribute("GlassMode")
local glassMode: string=(typeof(savedMode)=="string" and Modes[savedMode])
    and savedMode or "Frosted"
local blur: BlurEffect?=nil
local blurCreated=false
for _,child in ipairs(Lighting:GetChildren()) do
    if child.Name=="GlassBlur" and child:IsA("BlurEffect") then
        if not blur then blur=child else child:Destroy() end
    end
end
if not blur then
    blur=Instance.new("BlurEffect")
    blur.Name="GlassBlur"
    blur.Size=0
    blur.Enabled=false
    blur.Parent=Lighting
    blurCreated=true
end
local originalBlurSize=blur.Size
local originalBlurEnabled=blur.Enabled
local blurTween: Tween?=nil
local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictHubV2",ResetOnSpawn=false,
    DisplayOrder=800,IgnoreGuiInset=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
pcall(function() gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets end)
local function windowSize(open: boolean): UDim2
    local camera=Workspace.CurrentCamera
    local vp=camera and camera.ViewportSize or Vector2.new(1280,720)
    local width=math.min(438,math.max(280,vp.X-26))
    local height=math.min(555,math.max(310,vp.Y-52))
    return UDim2.fromOffset(width,open and height or 112)
end
local panel=create("Frame",gui,{
    Name="GlassWindow",AnchorPoint=Vector2.new(1,0),
    Position=UDim2.new(1,-17,0,18),
    Size=windowSize(true),BackgroundColor3=Modes.Frosted.Tint,
    BackgroundTransparency=Modes.Frosted.Transparency,
    ClipsDescendants=true,Active=true,BorderSizePixel=0
})
local panelCorner=create("UICorner",panel,{CornerRadius=UDim.new(0,23)})
local panelRim=create("UIStroke",panel,{
    Color=Modes.Frosted.Rim,Transparency=Modes.Frosted.RimTransparency,
    Thickness=1.3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border
})
local panelRimGradient=create("UIGradient",panelRim,{
    Color=ColorSequence.new(
        Color3.fromRGB(255,255,255),Color3.fromRGB(134,135,129)),
    Rotation=125
})
local panelGradient=create("UIGradient",panel,{
    Color=ColorSequence.new(
        Modes.Frosted.Tint,Modes.Frosted.TintDark),
    Rotation=29
})
create("UISizeConstraint",panel,{
    MinSize=Vector2.new(274,112),MaxSize=Vector2.new(455,590)
})
local hudScale=create("UIScale",panel,{Scale=1})
-- Top sheen is decorative; the glass dashboard itself remains usable.
local sheen=create("Frame",panel,{
    Name="GlassSheen",Position=UDim2.fromOffset(6,5),
    Size=UDim2.new(1,-12,0,58),
    BackgroundColor3=Color3.fromRGB(247,249,238),
    BackgroundTransparency=.84,BorderSizePixel=0
})
local sheenCorner=create("UICorner",sheen,{CornerRadius=UDim.new(0,20)})
create("UIGradient",sheen,{
    Rotation=90,Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,.13),
        NumberSequenceKeypoint.new(1,.98)
    })
})
local header=create("Frame",panel,{
    Name="TopBar",Size=UDim2.new(1,0,0,67),
    BackgroundTransparency=1,Active=true
})
local dragHandle=create("Frame",header,{
    Name="DragArea",Size=UDim2.new(1,-111,1,0),
    BackgroundTransparency=1,Active=true
})
local title=label(dragHandle,"VELION  /  DISTRICT",16,8,235,29,15,palette.white)
title.Font=Enum.Font.GothamBold
local themeText=label(dragHandle,"FROSTED  /  CONCEPT",17,36,260,17,10,palette.muted)
local minimize=button(header,"-",0,10,45,45)
minimize.Name="Minimize"
minimize.Position=UDim2.new(1,-102,0,11)
local close=button(header,"X",0,10,45,45)
close.Name="Close"
close.Position=UDim2.new(1,-51,0,11)
close.BackgroundColor3=Color3.fromRGB(77,55,57)
local navStrip=create("ScrollingFrame",panel,{
    Name="FeatureTabs",Position=UDim2.fromOffset(0,68),
    Size=UDim2.new(1,0,0,53),BackgroundTransparency=1,
    BorderSizePixel=0,ScrollBarThickness=2,
    ScrollingDirection=Enum.ScrollingDirection.X,
    CanvasSize=UDim2.fromOffset(798,0),
})
create("UIPadding",navStrip,{PaddingLeft=UDim.new(0,10)})
local navGradient=create("UIGradient",navStrip,{
    Color=ColorSequence.new(Color3.fromRGB(254,255,248),
        Color3.fromRGB(233,235,224)),Rotation=90
})
local mainArea=create("Frame",panel,{
    Name="TabContent",Position=UDim2.fromOffset(8,125),
    Size=UDim2.new(1,-16,1,-178),
    BackgroundColor3=Color3.fromRGB(26,28,27),
    BackgroundTransparency=.54,BorderSizePixel=0,
    ClipsDescendants=true
})
round(mainArea,13)
create("UIStroke",mainArea,{
    Color=Color3.fromRGB(246,245,229),Transparency=.83,Thickness=.8
})
local footer=create("Frame",panel,{
    Position=UDim2.new(0,9,1,-48),
    Size=UDim2.new(1,-18,0,40),
    BackgroundTransparency=1
})
local footerText=label(footer,"VELION READY  •  RIGHT CTRL TO HIDE",10,3,360,31,10,palette.white)
footerText.Size=UDim2.new(1,-20,0,31)
local miniSummary=label(panel,"PLAYERS --  |  OBJECTIVES --  |  KILLER: --",
    17,70,320,31,11,palette.white)
miniSummary.Size=UDim2.new(1,-34,0,32)
miniSummary.Visible=false
local restore=button(gui,"VD",0,0,49,46)
restore.Name="RestoreGlassHub"
restore.Position=UDim2.new(1,-64,0,18)
restore.Visible=false
restore.BackgroundColor3=Color3.fromRGB(73,77,68)

local pages: {[string]: ScrollingFrame}={}
local nav: {[string]: TextButton}={}
local tabNames={"Home","Players","Objects","Survivor","Movement","Visual","Settings"}
local function makePage(name: string): ScrollingFrame
    local page=create("ScrollingFrame",mainArea,{
        Name="Tab_"..name,Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,Visible=false,
        BorderSizePixel=0,ScrollBarThickness=3,
        ScrollingDirection=Enum.ScrollingDirection.Y,
        CanvasSize=UDim2.fromOffset(0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y
    })
    create("UIListLayout",page,{
        Padding=UDim.new(0,8),
        SortOrder=Enum.SortOrder.LayoutOrder
    })
    create("UIPadding",page,{
        PaddingTop=UDim.new(0,9),PaddingBottom=UDim.new(0,12),
        PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)
    })
    pages[name]=page
    return page
end
local homePage=makePage("Home")
local playersPage=makePage("Players")
local objectsPage=makePage("Objects")
local survivorPage=makePage("Survivor")
local movementPage=makePage("Movement")
local visualPage=makePage("Visual")
local settingsPage=makePage("Settings")
local function switchTab(name: string)
    state.activeTab=name
    for n,p in pairs(pages) do p.Visible=(n==name) end
    for n,b in pairs(nav) do
        b.BackgroundColor3=(n==name) and Color3.fromRGB(118,134,116)
            or Color3.fromRGB(61,65,62)
        b.BackgroundTransparency=(n==name) and .32 or .57
        b.TextColor3=(n==name) and palette.white or palette.muted
    end
end
for i,name in ipairs(tabNames) do
    local tab=button(navStrip,name,(i-1)*111,3,105,44)
    tab.Name="Nav"..name
    tab.BackgroundColor3=Color3.fromRGB(61,65,62)
    tab.BackgroundTransparency=.57
    tab.Font=Enum.Font.GothamMedium
    tab.TextSize=11
    nav[name]=tab
    connect(tab.MouseButton1Click,function() switchTab(name) end)
end
local redraws: {() -> ()}={}
local function glassRow(page: ScrollingFrame,headerText: string,
    description: string): (TextButton,TextLabel)
    local row=button(page,"",0,0,100,54)
    row.Size=UDim2.new(1,-5,0,55)
    row.BackgroundColor3=Color3.fromRGB(70,75,70)
    row.BackgroundTransparency=.40
    row.Text=""
    local rowTitle=label(row,headerText,12,7,300,23,12,palette.white)
    rowTitle.Size=UDim2.new(1,-108,0,23)
    rowTitle.Font=Enum.Font.GothamMedium
    local note=label(row,description,12,30,305,16,10,palette.muted)
    note.Size=UDim2.new(1,-108,0,17)
    local indicator=label(row,"",0,0,69,55,11,palette.muted)
    indicator.Position=UDim2.new(1,-77,0,0)
    indicator.TextXAlignment=Enum.TextXAlignment.Right
    indicator.Font=Enum.Font.GothamBold
    return row,indicator
end
local function makeToggle(page: ScrollingFrame,heading: string,help: string,
    getter: () -> boolean,setter: (boolean) -> ())
    local row,status=glassRow(page,heading,help)
    local function redraw()
        local on=getter()
        status.Text=on and "ON" or "OFF"
        status.TextColor3=on and palette.green or palette.muted
        row.BackgroundColor3=on and Color3.fromRGB(78,99,81)
            or Color3.fromRGB(64,69,66)
    end
    redraws[#redraws+1]=redraw
    connect(row.MouseButton1Click,function()
        setter(not getter())
        for _,f in ipairs(redraws) do f() end
    end)
    redraw()
    return redraw
end
local function makeAction(page: ScrollingFrame,heading: string,
    help: string,callback: () -> ())
    local row,status=glassRow(page,heading,help)
    status.Text="›"
    connect(row.MouseButton1Click,callback)
    return row
end
local function makeStat(page: ScrollingFrame,name: string): TextLabel
    local f=create("Frame",page,{
        Size=UDim2.new(1,-5,0,64),
        BackgroundColor3=Color3.fromRGB(55,60,57),
        BackgroundTransparency=.52,BorderSizePixel=0
    })
    round(f,12)
    local nameLabel=label(f,name,12,6,310,18,10,palette.muted)
    nameLabel.Size=UDim2.new(1,-24,0,18)
    local value=label(f,"Checking...",12,28,315,29,12,palette.white)
    value.Size=UDim2.new(1,-24,0,28)
    return value
end
local modeActions: {() -> ()}={}
local windowTween: Tween?=nil
local themeTweens: {Tween}={}
local function animateTheme(obj: Instance,props: {[string]: any})
    local t=TweenService:Create(obj,
        TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        props)
    themeTweens[#themeTweens+1]=t
    t:Play()
end
local function syncBlur()
    if blurTween then blurTween:Cancel() end
    if not blur then return end
    local enabled=state.sceneBlur and state.expanded and not state.hidden
    blur.Enabled=enabled
    blurTween=TweenService:Create(blur,
        TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {Size=enabled and Modes[glassMode].Blur or 0})
    blurTween:Play()
end
local function applyMode(name: string)
    local style=Modes[name]
    if not style then return end
    glassMode=name
    player:SetAttribute("GlassMode",name)
    for _,tw in ipairs(themeTweens) do tw:Cancel() end
    table.clear(themeTweens)
    panelCorner.CornerRadius=UDim.new(0,style.Radius)
    sheenCorner.CornerRadius=UDim.new(0,math.max(10,style.Radius-3))
    panelGradient.Color=ColorSequence.new(style.Tint,style.TintDark)
    panelRimGradient.Color=ColorSequence.new(
        Color3.fromRGB(255,255,253),style.Rim)
    animateTheme(panel,{BackgroundColor3=style.Tint,
        BackgroundTransparency=style.Transparency})
    animateTheme(panelRim,{Color=style.Rim,
        Transparency=style.RimTransparency})
    animateTheme(sheen,{BackgroundTransparency=style.Sheen})
    themeText.Text=name:upper().."  /  "..style.Subtitle:upper()
    for _,redraw in ipairs(modeActions) do redraw() end
    syncBlur()
end
local function ensureVisible()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local view=camera.ViewportSize
    local right=panel.AbsolutePosition.X+panel.AbsoluteSize.X
    right=math.clamp(right,math.min(view.X-5,panel.AbsoluteSize.X+5),view.X-5)
    local top=math.clamp(panel.AbsolutePosition.Y,5,math.max(5,view.Y-50))
    panel.Position=UDim2.fromOffset(right,top)
end
local function expandWindow(open: boolean)
    state.expanded=open
    navStrip.Visible=open
    mainArea.Visible=open
    footer.Visible=open
    miniSummary.Visible=not open
    minimize.Text=open and "-" or "+"
    if windowTween then windowTween:Cancel() end
    windowTween=TweenService:Create(panel,
        TweenInfo.new(.22,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),
        {Size=windowSize(open)})
    windowTween:Play()
    syncBlur()
    task.delay(.24,function()
        if state.alive then ensureVisible() end
    end)
end
connect(minimize.MouseButton1Click,function()
    expandWindow(not state.expanded)
end)
connect(restore.MouseButton1Click,function()
    panel.Visible=true
    restore.Visible=false
    state.hidden=false
    syncBlur()
end)
-- Correctly drag the title bar, not a mode button over the entire screen.
local dragging=false
local dragInput: InputObject?=nil
local dragStart=Vector3.zero
local dragOrigin=UDim2.new()
connect(dragHandle.InputBegan,function(input: InputObject)
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
        local delta=input.Position-dragStart
        panel.Position=UDim2.new(dragOrigin.X.Scale,dragOrigin.X.Offset+delta.X,
            dragOrigin.Y.Scale,dragOrigin.Y.Offset+delta.Y)
    end
end)
connect(UserInputService.InputEnded,function(input: InputObject)
    if input==dragInput or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
        dragInput=nil
        ensureVisible()
    end
end)
connect(UserInputService.InputBegan,function(input: InputObject,processed: boolean)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
        state.hidden=not panel.Visible
        restore.Visible=state.hidden
        syncBlur()
    end
end)
-- Alert outside the window, with the same glass visual language.
local alert=create("TextLabel",gui,{
    Name="KillerWarning",AnchorPoint=Vector2.new(.5,0),
    Position=UDim2.new(.5,0,0,8),
    Size=UDim2.new(.65,0,0,44),
    Text="",Visible=false,Font=Enum.Font.GothamMedium,
    TextColor3=palette.red,TextSize=15,
    BackgroundColor3=Color3.fromRGB(51,50,46),
    BackgroundTransparency=.27,BorderSizePixel=0,
    TextStrokeTransparency=.8
})
create("UISizeConstraint",alert,{
    MinSize=Vector2.new(180,44),MaxSize=Vector2.new(430,44)
})
round(alert,19)
create("UIStroke",alert,{
    Color=Color3.fromRGB(246,231,209),
    Transparency=.58,Thickness=1
})


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
    if isHooked then color=Color3.fromRGB(255,170,196)
    elseif isKnocked then color=palette.yellow end
    local selectedKiller=gameValue(other,"SelectedKiller")
    local nick=(role=="Killer" and selectedKiller)
        and tostring(selectedKiller) or other.DisplayName
    local mask=(state.playerMask and role=="Killer") and maskLabel(other) or nil
    local status=(isHooked and state.hookedStatus and "HOOKED")
        or (isKnocked and state.knockedStatus and "KNOCKED")
        or (isChased and state.chaseStatus and "CHASED") or nil
    existing.highlight.FillColor=color
    existing.highlight.OutlineColor=color
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
            v.gui.Enabled=state.objectiveESP and objectiveEnabled(v.kind.key)
            v.gui.MaxDistance=state.espDistance
            v.text.Text=v.kind.title
            v.text.TextColor3=v.kind.color
            if v.kind.key=="generator" and state.generatorProgressESP then
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




-- Feature-first navigation. Each row calls an actual V2 game subsystem.
local homeCounts=makeStat(homePage,"PLAYERS  /  OBJECTIVES")
local homeKiller=makeStat(homePage,"KILLER PROXIMITY")
local homeSkill=makeStat(homePage,"SKILL CHECK")
local homeNext=makeStat(homePage,"NEXT KILLER (ESTIMATE)")
makeToggle(homePage,"PLAYER ESP","Show markers for nearby players",
    function() return state.playerESP end,
    function(v)
        state.playerESP=v
        if not v then
            for p in pairs(playerVisuals) do removePlayerVisual(p) end
        end
    end)
makeToggle(homePage,"OBJECTIVE ESP","Map generator and interactable markers",
    function() return state.objectiveESP end,
    function(v) state.objectiveESP=v;refreshObjectiveVisibility() end)

makeToggle(playersPage,"PLAYER ESP MASTER","Enable player outlines and nametags",
    function() return state.playerESP end,
    function(v)
        state.playerESP=v
        if not v then
            for p in pairs(playerVisuals) do removePlayerVisual(p) end
        end
    end)
makeToggle(playersPage,"KILLER ESP","Mark players identified as killers",
    function() return state.killerESP end,
    function(v) state.killerESP=v end)
makeToggle(playersPage,"SURVIVOR ESP","Mark players identified as survivors",
    function() return state.survivorESP end,
    function(v) state.survivorESP=v end)
makeToggle(playersPage,"PLAYER HIGHLIGHT","Outlines through map objects",
    function() return state.playerHighlight end,
    function(v) state.playerHighlight=v end)
makeToggle(playersPage,"PLAYER NAMETAGS","Display names and selected killers",
    function() return state.playerNames end,
    function(v) state.playerNames=v end)
makeToggle(playersPage,"DISTANCE ESP","Display distance in studs",
    function() return state.playerDistance end,
    function(v) state.playerDistance=v end)
makeToggle(playersPage,"KILLER MASK ESP","Show mask names when replicated",
    function() return state.playerMask end,
    function(v) state.playerMask=v end)
makeToggle(playersPage,"CHASED INDICATORS","Flag chased players with status",
    function() return state.chaseStatus end,
    function(v) state.chaseStatus=v end)
makeToggle(playersPage,"KNOCKED STATUS","Highlight players who are knocked",
    function() return state.knockedStatus end,
    function(v) state.knockedStatus=v end)
makeToggle(playersPage,"HOOKED STATUS","Highlight players on hooks",
    function() return state.hookedStatus end,
    function(v) state.hookedStatus=v end)
makeToggle(playersPage,"OFFSCREEN INDICATORS","Show killer/chased direction at screen edge",
    function() return state.offscreenESP end,
    function(v) state.offscreenESP=v end)
makeToggle(playersPage,"KILLER DISTANCE ALERT","Warn when known killer is under 99 studs",
    function() return state.killerAlert end,
    function(v) state.killerAlert=v end)

makeToggle(objectsPage,"OBJECTIVE ESP MASTER","Show map objective markers",
    function() return state.objectiveESP end,
    function(v) state.objectiveESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"GENERATOR ESP","Show generators found inside map",
    function() return state.generatorESP end,
    function(v) state.generatorESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"GENERATOR PROGRESS","RepairProgress / Progress attributes",
    function() return state.generatorProgressESP end,
    function(v) state.generatorProgressESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"PALLET ESP","Pallet and Palletwrong",
    function() return state.palletESP end,
    function(v) state.palletESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"WINDOW ESP","Highlight Window instances",
    function() return state.windowESP end,
    function(v) state.windowESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"HOOK ESP","Show hook locations",
    function() return state.hookESP end,
    function(v) state.hookESP=v;refreshObjectiveVisibility() end)
makeToggle(objectsPage,"GATE ESP","Show map exit gates",
    function() return state.gateESP end,
    function(v) state.gateESP=v;refreshObjectiveVisibility() end)
makeAction(objectsPage,"REFRESH MAP OBJECTS","Re-scan Workspace for replicated instances",
    function() startObjectiveScan() end)
local objectiveInfo=makeStat(objectsPage,"OBJECTIVE SCANNER")

makeToggle(survivorPage,"AUTO SKILL CHECK","Try the original mobile action when aligned",
    function() return state.autoSkillCheck end,
    function(v)
        state.autoSkillCheck=v
        state.inputStatus=v and "Enabled; waiting for Skill Check" or "Disabled"
    end)
makeToggle(survivorPage,"SKILL CHECK MONITOR","Show current angle and target window",
    function() return state.skillMonitor end,
    function(v) state.skillMonitor=v end)
makeToggle(survivorPage,"NEXT KILLER ESTIMATE","Use AllowKiller and KillerChance",
    function() return state.nextKiller end,
    function(v) state.nextKiller=v end)
local skillInfo=makeStat(survivorPage,"SKILL CHECK STATUS")
local autoInputInfo=makeStat(survivorPage,"AUTO INPUT DIAGNOSTIC")
makeAction(survivorPage,"REFRESH GAME UI STATUS","Re-read SkillCheckPromptGui",
    function()
        state.inputStatus="Checking UI path"
    end)

makeToggle(movementPage,"NOCLIP","Local character collision toggle",
    function() return state.noClip end,setNoClip)
makeToggle(movementPage,"SPEED ASSIST","Apply local Humanoid WalkSpeed",
    function() return state.speed end,setSpeed)
local speedButton=makeAction(movementPage,"SPEED VALUE: 24",
    "Tap to cycle 24 / 28 / 32 / 20",
    function()
        local choices={[24]=28,[28]=32,[32]=20,[20]=24}
        state.speedValue=choices[state.speedValue] or 24
    end)
local movementStat=makeStat(movementPage,"CURRENT WALK SPEED")

makeToggle(visualPage,"FULLBRIGHT","Local lighting and ambient boost",
    function() return state.fullbright end,
    function(v) state.fullbright=v;updateLighting() end)
makeToggle(visualPage,"NO FOG","Reduce fog and atmospheric haze",
    function() return state.noFog end,
    function(v) state.noFog=v;updateLighting() end)
makeAction(visualPage,"CAMERA FOV","Cycle 70 / 85 / 100 degrees",
    function()
        local cycle={[70]=85,[85]=100,[100]=70}
        state.fov=cycle[state.fov] or 70
        cameraFov()
    end)
makeAction(visualPage,"ESP RANGE","Cycle 350 / 650 / 1000 / 2000 studs",
    function()
        local cycle={[350]=650,[650]=1000,[1000]=2000,[2000]=350}
        state.espDistance=cycle[state.espDistance] or 650
        refreshObjectiveVisibility()
    end)
local visualInfo=makeStat(visualPage,"VISUAL SETTINGS")

for _,name in ipairs({"Frosted","Clear","Blur"}) do
    local modeName=name
    local action=makeAction(settingsPage,modeName:upper().."  /  "..Modes[modeName].Subtitle,
        "Use this glass theme for the dashboard",function()
            applyMode(modeName)
        end)
    local leftLabel=action:FindFirstChildOfClass("TextLabel")
    local function displayActive()
        action.BackgroundColor3=glassMode==modeName
            and Color3.fromRGB(103,116,104) or Color3.fromRGB(66,70,66)
    end
    modeActions[#modeActions+1]=displayActive
end
makeToggle(settingsPage,"SCENE BLUR (GLOBAL)","Off by default; affects all 3D scenery",
    function() return state.sceneBlur end,
    function(v) state.sceneBlur=v;syncBlur() end)
local scaleIndex=1
local scaleChoices={1,.9,.8}
makeAction(settingsPage,"HUD SCALE","Tap to cycle 100 / 90 / 80 percent",
    function()
        scaleIndex=scaleIndex%3+1
        hudScale.Scale=scaleChoices[scaleIndex]
        task.defer(ensureVisible)
    end)
makeAction(settingsPage,"RESET HUD POSITION","Return window to the top-right",
    function()
        panel.Position=UDim2.new(1,-17,0,18)
        task.defer(ensureVisible)
    end)
makeAction(settingsPage,"REFRESH OBJECTS","Scan map again",
    function() startObjectiveScan() end)
local settingsInfo=makeStat(settingsPage,"SELECTED GLASS STYLE")
switchTab("Home")
applyMode(glassMode)


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
connect(RunService.Heartbeat,function()
    if not state.alive then return end
    local now=os.clock()
    if now-lastUpdate<.25 then return end
    lastUpdate=now
    updateNoClip()
    updateSpeed()
    local character=player.Character
    local myRoot=character and character:FindFirstChild("HumanoidRootPart")
    local closest=math.huge
    local closestName=""
    local players=Players:GetPlayers()
    for _,other in ipairs(players) do
        if other~=player then
            if state.playerESP then ensurePlayerVisual(other) end
            if state.killerAlert and myRoot then
                local role=roleOf(other)
                if role=="Killer" then
                    local hisRoot=other.Character and
                        other.Character:FindFirstChild("HumanoidRootPart")
                    if hisRoot then
                        local dist=(myRoot.Position-hisRoot.Position).Magnitude
                        if dist<closest then
                            closest=dist;closestName=other.DisplayName
                        end
                    end
                end
            end
        end
    end
    local inDanger=state.killerAlert and closest<99
    local warning=inDanger and ("KILLER NEARBY: "..closestName
        .." ("..math.floor(closest).." studs)") or
        (state.killerAlert and "No known killer nearby" or "Alert disabled")
    alert.Text=inDanger and warning or ""
    alert.Visible=inDanger
    refreshObjectiveVisibility()
    local count=state.identifiedObjectives
    homeCounts.Text=#players.." players  •  "..count.." objects"
    homeKiller.Text=warning
    homeKiller.TextColor3=inDanger and palette.red or palette.white
    local skillStatus=state.skillMonitor and checkSkillUi()
        or "Monitor disabled"
    homeSkill.Text=skillStatus
    local team=player.Team and player.Team.Name:lower() or ""
    local lobby=(team:find("lobby",1,true) or
        team:find("spectator",1,true))~=nil
    local estimate=state.nextKiller and
        (lobby and estimateNextKiller() or "Visible in lobby") or "Disabled"
    homeNext.Text=estimate
    skillInfo.Text=skillStatus
    autoInputInfo.Text=state.inputStatus
    objectiveInfo.Text=state.scanProgress.."  |  "..count.." objects"
    visualInfo.Text="FOV "..state.fov.."  |  ESP Range "..state.espDistance.." studs"
    settingsInfo.Text=glassMode.." / "..Modes[glassMode].Subtitle
        .."  |  HUD "..math.floor(hudScale.Scale*100).."%"
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    movementStat.Text=hum and
        ("WalkSpeed: "..hum.WalkSpeed.."; Assist: "
            ..(state.speed and "ON" or "OFF")) or "No humanoid"
    local miniWarning=inDanger and "KILLER NEARBY" or "CLEAR / UNKNOWN"
    miniSummary.Text="# "..#players.." PLAYERS   |   "..count
        .." OBJECTIVES   |   "..miniWarning
    footerText.Text="PLAYERS "..#players.."  •  OBJECTIVES "..count
        .."  •  "..(inDanger and "KILLER NEARBY" or "READY")
    if windowTween==nil or windowTween.PlaybackState~=Enum.PlaybackState.Playing then
        local required=windowSize(state.expanded)
        if math.abs(panel.Size.X.Offset-required.X.Offset)>2 or
            math.abs(panel.Size.Y.Offset-required.Y.Offset)>2 then
            panel.Size=required
            ensureVisible()
        end
    end
end)
-- Reproduce the reference's optional skill-check input attempt. This does
-- not claim that a game/server accepts the simulated touch event.
local inputAttempted=false
local touchId=8822
connect(RunService.Heartbeat,function()
    if not state.alive or not state.autoSkillCheck then
        inputAttempted=false
        return
    end
    if not player.Team or player.Team.Name~="Survivors" then return end
    local prompt=playerGui:FindFirstChild("SkillCheckPromptGui")
    local check=prompt and prompt:FindFirstChild("Check")
    if not check or not check:IsA("GuiObject") or not check.Visible then
        inputAttempted=false
        return
    end
    if inputAttempted then return end
    local line=check:FindFirstChild("Line")
    local goal=check:FindFirstChild("Goal")
    if not line or not goal or not line:IsA("GuiObject")
        or not goal:IsA("GuiObject") then
        state.inputStatus="Line/Goal not found"
        return
    end
    local rotation=line.Rotation%360
    local ss=(goal.Rotation+101)%360
    local se=(goal.Rotation+115)%360
    local inside=(ss>se and (rotation>=ss or rotation<=se))
        or (rotation>=ss and rotation<=se)
    if not inside then return end
    inputAttempted=true
    local guiItem: Instance?=playerGui
    for seg in string.gmatch("Survivor-mob.Controls.action.check","[^%.]+") do
        guiItem=guiItem and guiItem:FindFirstChild(seg) or nil
    end
    if not guiItem or not guiItem:IsA("GuiObject") then
        state.inputStatus="Action GUI not found"
        return
    end
    local ok,reason=pcall(function()
        local vim=game:GetService("VirtualInputManager")
        local g=game:GetService("GuiService")
        local inset=g:GetGuiInset()
        local position=guiItem.AbsolutePosition
        local size=guiItem.AbsoluteSize
        local x=position.X+size.X/2+inset.X
        local y=position.Y+size.Y/2+inset.Y
        vim:SendTouchEvent(touchId,0,x,y)
        task.delay(.04,function()
            if state.alive then
                pcall(function()
                    vim:SendTouchEvent(touchId,2,x,y)
                end)
            end
        end)
    end)
    state.inputStatus=ok and "Touch sent (NOT confirmed by game)"
        or ("Touch unavailable: "..tostring(reason):sub(1,74))
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
    if windowTween then windowTween:Cancel() end
    if blurTween then blurTween:Cancel() end
    for _,tw in ipairs(themeTweens) do
        pcall(function() tw:Cancel() end)
    end
    for _,conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    for other in pairs(playerVisuals) do removePlayerVisual(other) end
    for obj,v in pairs(objectiveVisuals) do
        v.gui:Destroy();objectiveVisuals[obj]=nil
    end
    setNoClip(false)
    state.fullbright=false
    state.noFog=false
    updateLighting()
    if state.speed then setSpeed(false) end
    local camera=Workspace.CurrentCamera
    if camera then camera.FieldOfView=originalFOV end
    gui:Destroy()
    if blur and blur.Parent then
        if blurCreated then blur:Destroy()
        else
            blur.Size=originalBlurSize
            blur.Enabled=originalBlurEnabled
        end
    end
    if environment.VelionVDCleanup==cleanup then
        environment.VelionVDCleanup=nil
    end
end
environment.VelionVDCleanup=cleanup
connect(close.MouseButton1Click,cleanup)
startObjectiveScan()
print("[Velion District V3] Feature-first glass dashboard loaded. Studio runtime unverified.")
