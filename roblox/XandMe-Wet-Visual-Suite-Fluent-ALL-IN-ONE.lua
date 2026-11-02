--!nocheck
-- XandMe Wet Visual Suite v1.0 | Fluent-inspired local graphics
-- Self-contained client Luau. Native Roblox effects, not SSR or neural upscaling.
-- Install as a LocalScript in StarterPlayerScripts in owned games, or run client-side.
-- Cleanup from old sessions is not possible if old scripts never exposed shutdown.

local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local Lighting=game:GetService("Lighting")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local LocalPlayer=Players.LocalPlayer
if not LocalPlayer then return end

local previous=rawget(_G,"XandMeWetVisualSuite")
if type(previous)=="table" and type(previous.Destroy)=="function" then
    pcall(function() previous:Destroy() end)
end

local Suite={}
_G.XandMeWetVisualSuite=Suite
Suite.Alive=true
local connections={}
local partOriginals=setmetatable({},{__mode="k"})
local trackedCharacters=setmetatable({},{__mode="k"})
local layers={}
local ownedEffects={}
local lightingOriginal={}
local terrainOriginal={}
local oldAtmosphere=nil
local atmosphereOriginal=nil
local wetRoot=Instance.new("Folder")
wetRoot.Name="XWM_WetLayers_"..tostring(LocalPlayer.UserId)
wetRoot.Parent=Workspace

local S={
    enabled=true,autoApply=true,
    charEnabled=true,charReflectance=.32,
    charMaterial=Enum.Material.SmoothPlastic,shinyAccessories=true,
    varnishEnabled=true,applyToFloors=true,applyToWalls=true,
    applyToNamedObjects=true,overlayReflectance=.08,
    overlayTransparency=.83,overlayDarkness=.12,overlayExpand=.045,
    maxLayers=800,
    lightingEnabled=true,brightness=2.25,envSpecular=1,envDiffuse=1,
    exposure=.08,shadowSoftness=.22,
    bloomIntensity=.18,bloomSize=30,bloomThreshold=1.02,
    contrast=.16,saturation=.12,ccBrightness=.015,
    atmosphereDensity=.27,atmosphereHaze=1.1,atmosphereGlare=.08,
    terrainWaterReflectance=.22,terrainWaterTransparency=.25,
    terrainWaterWaveSize=.16,terrainWaterWaveSpeed=14,
    menuOpen=false,selectedTab="characters",
}
Suite.Settings=S
local status="Siap"
local function track(conn) connections[#connections+1]=conn;return conn end
local function clamp(x,a,b)return math.clamp(x,a,b)end
local function safeGet(obj,key)
    local ok,value=pcall(function()return obj[key]end)
    return if ok then value else nil
end
local function safeSet(obj,key,value)
    return pcall(function() obj[key]=value end)
end
local function rememberPart(part)
    if not partOriginals[part] then
        partOriginals[part]={Material=part.Material,Reflectance=part.Reflectance}
    end
end
local function restoreParts()
    for part,original in pairs(partOriginals) do
        if part and part.Parent then
            safeSet(part,"Material",original.Material)
            safeSet(part,"Reflectance",original.Reflectance)
        end
        partOriginals[part]=nil
    end
end
local function clearLayers()
    for part,layer in pairs(layers) do
        if layer then pcall(function()layer:Destroy()end) end
        layers[part]=nil
    end
end
local function saveProps(obj,props,target)
    for _,key in ipairs(props) do
        if target[key]==nil then target[key]=safeGet(obj,key) end
    end
end

saveProps(Lighting,{"Brightness","EnvironmentDiffuseScale","EnvironmentSpecularScale",
    "ExposureCompensation","GlobalShadows","ShadowSoftness",
    "Ambient","OutdoorAmbient","ColorShift_Top","ColorShift_Bottom"},lightingOriginal)
local Terrain=Workspace.Terrain
saveProps(Terrain,{"WaterReflectance","WaterTransparency",
    "WaterWaveSize","WaterWaveSpeed"},terrainOriginal)

local function restoreProps(obj,record)
    for key,value in pairs(record)do safeSet(obj,key,value)end
end
local function getEffect(className,name)
    local found=Lighting:FindFirstChild(name)
    if found and found.ClassName==className then return found end
    if found then found:Destroy() end
    local obj=Instance.new(className)
    obj.Name=name
    obj.Parent=Lighting
    ownedEffects[#ownedEffects+1]=obj
    return obj
end

local function applyLighting()
    if not Suite.Alive or not S.enabled or not S.lightingEnabled then return end
    safeSet(Lighting,"Brightness",S.brightness)
    safeSet(Lighting,"EnvironmentDiffuseScale",S.envDiffuse)
    safeSet(Lighting,"EnvironmentSpecularScale",S.envSpecular)
    safeSet(Lighting,"ExposureCompensation",S.exposure)
    safeSet(Lighting,"GlobalShadows",true)
    safeSet(Lighting,"ShadowSoftness",S.shadowSoftness)
    safeSet(Lighting,"Ambient",Color3.fromRGB(90,96,108))
    safeSet(Lighting,"OutdoorAmbient",Color3.fromRGB(132,138,150))
    safeSet(Lighting,"ColorShift_Top",Color3.fromRGB(255,244,232))
    safeSet(Lighting,"ColorShift_Bottom",Color3.fromRGB(96,104,118))

    local bloom=getEffect("BloomEffect","XWM_Bloom")
    bloom.Enabled=true
    bloom.Intensity=S.bloomIntensity
    bloom.Size=S.bloomSize
    bloom.Threshold=S.bloomThreshold
    local color=getEffect("ColorCorrectionEffect","XWM_Color")
    color.Enabled=true
    color.Brightness=S.ccBrightness
    color.Contrast=S.contrast
    color.Saturation=S.saturation
    color.TintColor=Color3.fromRGB(255,249,243)

    local at=Lighting:FindFirstChildOfClass("Atmosphere")
    if not at then
        at=Instance.new("Atmosphere")
        at.Name="XWM_Atmosphere"
        at.Parent=Lighting
        ownedEffects[#ownedEffects+1]=at
    elseif not oldAtmosphere then
        oldAtmosphere=at
        atmosphereOriginal={}
        saveProps(at,{"Density","Offset","Color","Decay","Glare","Haze"},atmosphereOriginal)
    end
    at.Density=S.atmosphereDensity
    at.Offset=0
    at.Color=Color3.fromRGB(195,210,228)
    at.Decay=Color3.fromRGB(120,126,138)
    at.Glare=S.atmosphereGlare
    at.Haze=S.atmosphereHaze

    safeSet(Terrain,"WaterReflectance",S.terrainWaterReflectance)
    safeSet(Terrain,"WaterTransparency",S.terrainWaterTransparency)
    safeSet(Terrain,"WaterWaveSize",S.terrainWaterWaveSize)
    safeSet(Terrain,"WaterWaveSpeed",S.terrainWaterWaveSpeed)
end
local function restoreLighting()
    restoreProps(Lighting,lightingOriginal)
    restoreProps(Terrain,terrainOriginal)
    if oldAtmosphere and oldAtmosphere.Parent and atmosphereOriginal then
        restoreProps(oldAtmosphere,atmosphereOriginal)
    end
    for _,fx in ipairs(ownedEffects)do
        if fx and fx.Parent then fx:Destroy()end
    end
    table.clear(ownedEffects)
end

local function characterAncestor(part)
    local p=part.Parent
    while p and p~=Workspace do
        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return p end
        p=p.Parent
    end
    return nil
end
local function accessoryAncestor(part,model)
    local p=part.Parent
    while p and p~=model do
        if p:IsA("Accessory") then return true end
        p=p.Parent
    end
    return false
end
local function applyCharacterPart(part,model)
    if not Suite.Alive or not S.enabled or not S.charEnabled then return end
    if part.Name=="HumanoidRootPart" then return end
    if not S.shinyAccessories and accessoryAncestor(part,model) then return end
    rememberPart(part)
    safeSet(part,"Material",S.charMaterial)
    safeSet(part,"Reflectance",S.charReflectance)
end
local function applyCharacter(model)
    if not model or not model.Parent then return end
    trackedCharacters[model]=true
    for _,v in ipairs(model:GetDescendants())do
        if v:IsA("BasePart") then applyCharacterPart(v,model)end
    end
end
local function scanCharacters()
    local seen={}
    for _,player in ipairs(Players:GetPlayers())do
        local ch=player.Character
        if ch then seen[ch]=true;applyCharacter(ch)end
    end
    for _,obj in ipairs(Workspace:GetDescendants())do
        if obj:IsA("Model") and not seen[obj]
            and obj:FindFirstChildOfClass("Humanoid") then
            applyCharacter(obj)
        end
    end
end
local function refreshKnownCharacters()
    for model in pairs(trackedCharacters)do
        if model and model.Parent then applyCharacter(model)
        else trackedCharacters[model]=nil end
    end
end
local function restoreCharacterOnly()
    restoreParts()
    -- Only character entries are recorded in partOriginals.
end

local floorNames={"road","jalan","aspal","floor","trotoar","ground"}
local wallNames={"wall","tembok","building","pillar","tiang","fence"}
local function hasName(name,terms)
    name=string.lower(name)
    for _,word in ipairs(terms)do
        if string.find(name,word,1,true) then return true end
    end
    return false
end
local function wetCandidate(part)
    if not part:IsA("Part") or part.Shape~=Enum.PartType.Block then return false end
    if not part.Anchored or part.Transparency>=.95 then return false end
    if part:IsDescendantOf(wetRoot) or characterAncestor(part) then return false end
    local sz=part.Size
    local up=part.CFrame.UpVector:Dot(Vector3.yAxis)
    local floor=up>.85 and sz.X>4 and sz.Z>4
    local wall=math.abs(up)<.5 and sz.Y>4
    local namedFloor=hasName(part.Name,floorNames)
    local namedWall=hasName(part.Name,wallNames)
    return (S.applyToFloors and floor)
        or (S.applyToWalls and wall)
        or (S.applyToNamedObjects and (namedFloor or namedWall))
end
local function updateLayer(source,layer)
    if not layer or not layer.Parent then return end
    local extra=S.overlayExpand
    layer.Size=source.Size+Vector3.new(extra,extra,extra)
    layer.CFrame=source.CFrame
    layer.Transparency=S.overlayTransparency
    layer.Reflectance=S.overlayReflectance
    local v=select(3,source.Color:ToHSV())
    if v>.73 then layer.Transparency=math.max(layer.Transparency,.90)end
    local channel=math.floor(255*(1-S.overlayDarkness))
    layer.Color=Color3.fromRGB(channel,channel,channel)
end
local function applyWetPart(part)
    if not Suite.Alive or not S.enabled or not S.varnishEnabled then return end
    if not wetCandidate(part) then return end
    local layer=layers[part]
    if not layer then
        local count=0
        for _ in pairs(layers) do count+=1 end
        if count>=S.maxLayers then return end
        layer=Instance.new("Part")
        layer.Name="XWM_WetOverlay"
        layer.Anchored=true
        layer.CanCollide=false
        layer.CanTouch=false
        layer.CanQuery=false
        layer.CastShadow=false
        layer.Material=Enum.Material.Glass
        layer.Transparency=1
        layer.Locked=true
        layer.Parent=wetRoot
        layers[part]=layer
    end
    updateLayer(part,layer)
end
local function refreshLayers()
    for source,layer in pairs(layers)do
        if not S.enabled or not S.varnishEnabled or not source.Parent
            or not wetCandidate(source) then
            layer:Destroy()
            layers[source]=nil
        else
            updateLayer(source,layer)
        end
    end
end
local scanRunning=false
local function scanWet()
    if scanRunning or not Suite.Alive then return end
    scanRunning=true
    if S.enabled and S.varnishEnabled then
        local count=0
        for _,obj in ipairs(Workspace:GetDescendants())do
            if not Suite.Alive then break end
            if obj:IsA("Part") and not obj:IsDescendantOf(wetRoot) then
                applyWetPart(obj)
                count+=1
                if count%120==0 then task.wait()end
            end
        end
    end
    scanRunning=false
end
local function fullApply()
    S.enabled=true
    applyLighting()
    scanCharacters()
    task.spawn(scanWet)
    status="Efek diterapkan"
end
local function restoreAll()
    S.enabled=false
    clearLayers()
    restoreCharacterOnly()
    restoreLighting()
    status="Nilai awal dipulihkan"
end

local gui=Instance.new("ScreenGui")
gui.Name="XandMeWetVisualSuite"
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset=false
gui.Parent=LocalPlayer:WaitForChild("PlayerGui")

local function make(class,parent,props)
    local x=Instance.new(class)
    for k,v in pairs(props or {})do x[k]=v end
    x.Parent=parent
    return x
end
local function corner(obj,r)
    make("UICorner",obj,{CornerRadius=UDim.new(0,r)})
end
local dark=Color3.fromRGB(30,30,30)
local muted=Color3.fromRGB(45,45,45)
local blue=Color3.fromRGB(0,120,212)
local fg=Color3.fromRGB(241,242,247)
local sub=Color3.fromRGB(172,177,187)
local main=make("Frame",gui,{
    Name="Main",Size=UDim2.fromOffset(740,450),
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    BackgroundColor3=dark,BackgroundTransparency=.08,
    BorderSizePixel=0,Visible=false
})
corner(main,8)
make("UIStroke",main,{Color=Color3.fromRGB(100,105,113),Transparency=.55,Thickness=1})
local scale=make("UIScale",main,{Scale=1})
local sidebar=make("Frame",main,{
    Size=UDim2.fromOffset(178,450),BackgroundColor3=Color3.fromRGB(24,24,24),
    BackgroundTransparency=.08,BorderSizePixel=0
})
corner(sidebar,8)
make("TextLabel",sidebar,{
    Size=UDim2.fromOffset(160,30),Position=UDim2.fromOffset(14,14),
    BackgroundTransparency=1,Text="WET VISUAL SUITE",
    TextColor3=fg,Font=Enum.Font.GothamBold,TextSize=15,
    TextXAlignment=Enum.TextXAlignment.Left
})
make("TextLabel",sidebar,{
    Size=UDim2.fromOffset(158,20),Position=UDim2.fromOffset(14,45),
    BackgroundTransparency=1,Text="Fluent-inspired  ·  Local",
    TextColor3=sub,Font=Enum.Font.Gotham,TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left
})
local nav=make("Frame",sidebar,{
    Position=UDim2.fromOffset(12,85),Size=UDim2.new(1,-24,0,245),
    BackgroundTransparency=1
})
make("UIListLayout",nav,{Padding=UDim.new(0,7)})
local content=make("Frame",main,{
    Position=UDim2.fromOffset(178,0),Size=UDim2.new(1,-178,1,0),
    BackgroundTransparency=1
})
local topbar=make("TextButton",content,{
    Size=UDim2.new(1,0,0,55),BackgroundTransparency=1,Text="",
    AutoButtonColor=false
})
local title=make("TextLabel",topbar,{
    Position=UDim2.fromOffset(18,14),Size=UDim2.new(1,-34,0,27),
    BackgroundTransparency=1,Text="Characters",TextSize=19,
    Font=Enum.Font.GothamBold,TextColor3=fg,
    TextXAlignment=Enum.TextXAlignment.Left
})
local statusLabel=make("TextLabel",content,{
    Size=UDim2.new(1,-36,0,20),
    Position=UDim2.new(0,18,1,-26),
    BackgroundTransparency=1,Text=status,
    TextXAlignment=Enum.TextXAlignment.Left,
    Font=Enum.Font.Gotham,TextSize=11,TextColor3=sub
})
local pages={}
local navButtons={}
local names={
    {"characters","Characters"},
    {"varnish","Wet Overlay"},
    {"lighting","Lighting"},
    {"system","System"}
}
for _,item in ipairs(names)do
    local key,label=item[1],item[2]
    local btn=make("TextButton",nav,{
        Size=UDim2.new(1,0,0,39),BackgroundColor3=muted,
        BackgroundTransparency=.28,Text=label,
        Font=Enum.Font.GothamMedium,TextSize=13,
        TextColor3=fg,AutoButtonColor=false
    })
    corner(btn,6)
    navButtons[key]=btn
    local page=make("ScrollingFrame",content,{
        Name=key,Position=UDim2.fromOffset(18,61),
        Size=UDim2.new(1,-36,1,-102),
        CanvasSize=UDim2.fromOffset(0,0),
        AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollBarThickness=4,ScrollBarImageColor3=blue,
        BackgroundTransparency=1,BorderSizePixel=0,Visible=false
    })
    make("UIPadding",page,{PaddingTop=UDim.new(0,4),
        PaddingBottom=UDim.new(0,9),PaddingRight=UDim.new(0,7)})
    make("UIListLayout",page,{Padding=UDim.new(0,9)})
    pages[key]=page
end
local function showTab(name)
    S.selectedTab=name
    for key,page in pairs(pages) do
        local selected=key==name
        page.Visible=selected
        local button=navButtons[key]
        TweenService:Create(button,TweenInfo.new(.13),{
            BackgroundColor3=if selected then blue else muted,
            BackgroundTransparency=if selected then 0 else .28
        }):Play()
    end
    for _,item in ipairs(names)do
        if item[1]==name then title.Text=item[2]break end
    end
end
for key,btn in pairs(navButtons)do
    track(btn.Activated:Connect(function()showTab(key)end))
end
local function section(page,label)
    local box=make("Frame",page,{
        Size=UDim2.new(1,-5,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3=muted,BackgroundTransparency=.35,
        BorderSizePixel=0
    })
    corner(box,7)
    make("UIStroke",box,{Color=Color3.fromRGB(85,90,99),Transparency=.6,Thickness=1})
    local header=make("TextLabel",box,{
        Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,24),
        BackgroundTransparency=1,Text=label,
        Font=Enum.Font.GothamBold,TextSize=13,TextColor3=fg,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    local holder=make("Frame",box,{
        Position=UDim2.fromOffset(12,36),
        Size=UDim2.new(1,-24,0,0),AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundTransparency=1
    })
    make("UIListLayout",holder,{Padding=UDim.new(0,9)})
    make("UIPadding",holder,{PaddingBottom=UDim.new(0,12)})
    return holder
end
local redraw={}
local activeSlider=nil
local function syncControls()
    for _,func in ipairs(redraw)do func()end
    statusLabel.Text=status
end
local function changed(kind)
    if kind=="char" then
        if S.enabled and S.charEnabled then refreshKnownCharacters()
        else restoreCharacterOnly() end
    elseif kind=="wet" then
        if not S.varnishEnabled then clearLayers()
        else refreshLayers();task.spawn(scanWet)end
    elseif kind=="wetValues" then
        refreshLayers()
    elseif kind=="lighting" then
        if S.enabled and S.lightingEnabled then applyLighting()
        else restoreLighting() end
    end
end
local function rowButton(holder,label,callback,tint)
    local btn=make("TextButton",holder,{
        Size=UDim2.new(1,0,0,35),BackgroundColor3=tint or blue,
        Text=label,Font=Enum.Font.GothamMedium,TextSize=13,
        TextColor3=fg,BorderSizePixel=0,AutoButtonColor=false
    })
    corner(btn,6)
    track(btn.Activated:Connect(callback))
    track(btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(.12),{BackgroundTransparency=.15}):Play()
    end))
    track(btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(.12),{BackgroundTransparency=0}):Play()
    end))
    return btn
end
local function toggle(holder,label,key,kind)
    local row=make("Frame",holder,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1})
    make("TextLabel",row,{
        Size=UDim2.new(1,-70,1,0),Text=label,
        BackgroundTransparency=1,TextColor3=fg,
        Font=Enum.Font.Gotham,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    local btn=make("TextButton",row,{
        Size=UDim2.fromOffset(50,25),AnchorPoint=Vector2.new(1,.5),
        Position=UDim2.fromScale(1,.5),Text="",AutoButtonColor=false
    })
    corner(btn,13)
    local knob=make("Frame",btn,{
        Size=UDim2.fromOffset(19,19),
        BackgroundColor3=Color3.new(1,1,1),
        BorderSizePixel=0
    })
    corner(knob,10)
    local function draw()
        local on=S[key]
        btn.BackgroundColor3=if on then blue else Color3.fromRGB(85,85,85)
        knob.Position=if on then UDim2.fromOffset(28,3) else UDim2.fromOffset(3,3)
    end
    redraw[#redraw+1]=draw
    track(btn.Activated:Connect(function()
        S[key]=not S[key]
        if key=="enabled" then
            if S.enabled then fullApply()else restoreAll()end
        else changed(kind)end
        syncControls()
    end))
    draw()
end
local function slider(holder,label,key,minValue,maxValue,kind)
    local row=make("Frame",holder,{Size=UDim2.new(1,0,0,57),BackgroundTransparency=1})
    make("TextLabel",row,{
        Size=UDim2.new(1,-94,0,19),Text=label,
        BackgroundTransparency=1,TextColor3=fg,
        Font=Enum.Font.Gotham,TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left
    })
    local numeric=make("TextLabel",row,{
        Size=UDim2.fromOffset(90,19),AnchorPoint=Vector2.new(1,0),
        Position=UDim2.fromScale(1,0),Text="",
        BackgroundTransparency=1,TextColor3=sub,
        Font=Enum.Font.Gotham,TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Right
    })
    local trackFrame=make("Frame",row,{
        Position=UDim2.fromOffset(7,33),Size=UDim2.new(1,-14,0,7),
        BackgroundColor3=Color3.fromRGB(78,81,89),BorderSizePixel=0
    })
    corner(trackFrame,4)
    local fill=make("Frame",trackFrame,{
        BackgroundColor3=blue,BorderSizePixel=0,
        Size=UDim2.fromScale(0,1)
    })
    corner(fill,4)
    local knob=make("Frame",trackFrame,{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
        Size=UDim2.fromOffset(15,15),BackgroundColor3=fg,BorderSizePixel=0
    })
    corner(knob,8)
    local hit=make("TextButton",trackFrame,{
        Size=UDim2.new(1,22,0,30),Position=UDim2.fromOffset(-11,-12),
        BackgroundTransparency=1,Text="",Selectable=true
    })
    local function draw()
        local val=S[key]
        local alpha=clamp((val-minValue)/(maxValue-minValue),0,1)
        fill.Size=UDim2.fromScale(alpha,1)
        knob.Position=UDim2.fromScale(alpha,.5)
        numeric.Text=string.format("%.3f",val)
    end
    redraw[#redraw+1]=draw
    local function setX(x)
        local width=trackFrame.AbsoluteSize.X
        if width<=0 then return end
        local alpha=clamp((x-trackFrame.AbsolutePosition.X)/width,0,1)
        S[key]=minValue+(maxValue-minValue)*alpha
        draw()
        changed(kind)
    end
    track(hit.InputBegan:Connect(function(input)
        if activeSlider then return end
        local typ=input.UserInputType
        if typ==Enum.UserInputType.Touch or typ==Enum.UserInputType.MouseButton1 then
            activeSlider={input=input,touch=typ==Enum.UserInputType.Touch,
                callback=setX,page=pages[S.selectedTab]}
            if activeSlider.page then activeSlider.page.ScrollingEnabled=false end
            setX(input.Position.X)
        end
    end))
    draw()
end

local a=section(pages.characters,"CHARACTER GLOSS")
toggle(a,"Aktifkan player dan NPC","charEnabled","char")
toggle(a,"Aksesori ikut mengilap","shinyAccessories","char")
slider(a,"Reflectance karakter","charReflectance",0,.65,"char")
rowButton(a,"Material SmoothPlastic",function()
    S.charMaterial=Enum.Material.SmoothPlastic
    changed("char")
end)
rowButton(a,"Material Plastic",function()
    S.charMaterial=Enum.Material.Plastic
    changed("char")
end,Color3.fromRGB(60,88,124))
rowButton(a,"Terapkan ke seluruh karakter",function()
    scanCharacters();status="Karakter diperbarui";syncControls()
end,Color3.fromRGB(60,88,124))

local b=section(pages.varnish,"WET OVERLAY / NATIVE GLOSS")
toggle(b,"Aktifkan lapisan basah","varnishEnabled","wet")
toggle(b,"Lantai dan jalan","applyToFloors","wet")
toggle(b,"Dinding dan bangunan","applyToWalls","wet")
toggle(b,"Deteksi berdasarkan nama","applyToNamedObjects","wet")
slider(b,"Reflectance overlay","overlayReflectance",0,.4,"wetValues")
slider(b,"Transparansi overlay","overlayTransparency",.55,.98,"wetValues")
slider(b,"Darkness overlay","overlayDarkness",0,.35,"wetValues")
slider(b,"Ketebalan overlay","overlayExpand",.01,.12,"wetValues")
rowButton(b,"Terapkan Wet Map",function()
    refreshLayers();task.spawn(scanWet)
    status="Memproses lapisan basah";syncControls()
end)
rowButton(b,"Bersihkan lapisan basah",function()
    clearLayers();status="Lapisan dibersihkan";syncControls()
end,Color3.fromRGB(120,65,79))

local c=section(pages.lighting,"LIGHTING / POST-PROCESSING")
toggle(c,"Aktifkan pencahayaan","lightingEnabled","lighting")
slider(c,"Brightness","brightness",.5,4,"lighting")
slider(c,"Exposure","exposure",-.5,.5,"lighting")
slider(c,"Shadow Softness","shadowSoftness",0,1,"lighting")
slider(c,"Environment Specular","envSpecular",0,1,"lighting")
slider(c,"Environment Diffuse","envDiffuse",0,1,"lighting")
slider(c,"Bloom","bloomIntensity",0,.4,"lighting")
slider(c,"Contrast","contrast",0,.4,"lighting")
slider(c,"Saturation","saturation",0,.4,"lighting")
slider(c,"Terrain Water Reflection","terrainWaterReflectance",0,1,"lighting")
slider(c,"Terrain Water Clarity","terrainWaterTransparency",0,1,"lighting")
rowButton(c,"Terapkan pencahayaan",function()
    applyLighting();status="Pencahayaan diperbarui";syncControls()
end)

local d=section(pages.system,"SYSTEM")
toggle(d,"Aktifkan suite","enabled","system")
toggle(d,"Objek baru otomatis","autoApply","system")
rowButton(d,"Terapkan semuanya",function()
    fullApply();syncControls()
end)
rowButton(d,"Preset Glossy",function()
    S.charReflectance=.34;S.overlayReflectance=.1
    S.overlayTransparency=.82;S.overlayDarkness=.1
    S.brightness=2.3;S.exposure=.10;S.bloomIntensity=.18
    S.contrast=.17;S.saturation=.13
    fullApply();refreshLayers();status="Preset Glossy aktif";syncControls()
end,Color3.fromRGB(60,88,124))
rowButton(d,"Preset Wet Rain",function()
    S.charReflectance=.28;S.overlayReflectance=.13
    S.overlayTransparency=.80;S.overlayDarkness=.16
    S.brightness=2.1;S.exposure=.02;S.bloomIntensity=.12
    S.contrast=.14;S.saturation=.09
    fullApply();refreshLayers();status="Preset Wet Rain aktif";syncControls()
end,Color3.fromRGB(60,88,124))
rowButton(d,"Restore Original",function()
    restoreAll();syncControls()
end,Color3.fromRGB(125,65,80))

local launcher=make("TextButton",gui,{
    Name="Launcher",Size=UDim2.fromOffset(48,48),
    AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),
    BackgroundColor3=Color3.fromRGB(36,39,45),Text="V",
    TextColor3=fg,Font=Enum.Font.GothamBold,TextSize=19,
    AutoButtonColor=false
})
corner(launcher,24)
make("UIStroke",launcher,{Thickness=1,Color=Color3.fromRGB(88,97,111),Transparency=.35})
local launcherDrag=nil
local panelDrag=nil
local function positionClamped(obj,target)
    local camera=Workspace.CurrentCamera
    local vp=if camera then camera.ViewportSize else Vector2.new(1280,720)
    local size=obj.AbsoluteSize
    return Vector2.new(
        clamp(target.X,5,math.max(5,vp.X-size.X-5)),
        clamp(target.Y,5,math.max(5,vp.Y-size.Y-5)))
end
local function dragStart(input,obj)
    local kind=input.UserInputType
    if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return nil end
    return {input=input,touch=kind==Enum.UserInputType.Touch,
        origin=obj.AbsolutePosition,start=Vector2.new(input.Position.X,input.Position.Y),
        object=obj,moved=false}
end
track(launcher.InputBegan:Connect(function(input)
    if not launcherDrag then launcherDrag=dragStart(input,launcher)end
end))
track(topbar.InputBegan:Connect(function(input)
    if not panelDrag then panelDrag=dragStart(input,main)end
end))
track(UIS.InputChanged:Connect(function(input)
    if activeSlider then
        if (activeSlider.touch and input==activeSlider.input)
            or (not activeSlider.touch and input.UserInputType==Enum.UserInputType.MouseMovement)then
            activeSlider.callback(input.Position.X)
        end
    end
    for _,drag in ipairs({launcherDrag,panelDrag})do
        if drag and ((drag.touch and input==drag.input) or
            (not drag.touch and input.UserInputType==Enum.UserInputType.MouseMovement)) then
            local delta=Vector2.new(input.Position.X,input.Position.Y)-drag.start
            if delta.Magnitude>6 then drag.moved=true end
            local p=positionClamped(drag.object,drag.origin+delta)
            if drag.object==launcher then
                launcher.AnchorPoint=Vector2.new(0,0)
            elseif drag.object==main then
                main.AnchorPoint=Vector2.new(0,0)
            end
            drag.object.Position=UDim2.fromOffset(p.X,p.Y)
        end
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if activeSlider and ((activeSlider.touch and input==activeSlider.input)
        or (not activeSlider.touch and input.UserInputType==Enum.UserInputType.MouseButton1))then
        activeSlider.callback(input.Position.X)
        if activeSlider.page then activeSlider.page.ScrollingEnabled=true end
        activeSlider=nil
    end
    if launcherDrag and ((launcherDrag.touch and input==launcherDrag.input) or
        (not launcherDrag.touch and input.UserInputType==Enum.UserInputType.MouseButton1)) then
        local moved=launcherDrag.moved
        launcherDrag=nil
        if not moved then
            S.menuOpen=not S.menuOpen
            main.Visible=S.menuOpen
        end
    end
    if panelDrag and ((panelDrag.touch and input==panelDrag.input) or
        (not panelDrag.touch and input.UserInputType==Enum.UserInputType.MouseButton1))then
        panelDrag=nil
    end
end))
track(UIS.InputBegan:Connect(function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.F3 then
        S.menuOpen=not S.menuOpen
        main.Visible=S.menuOpen
    end
end))
track(launcher.Activated:Connect(function()
    local t=UIS:GetLastInputType()
    if t==Enum.UserInputType.Keyboard or t==Enum.UserInputType.Gamepad1 then
        S.menuOpen=not S.menuOpen
        main.Visible=S.menuOpen
    end
end))
local function resize()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local vp=camera.ViewportSize
    scale.Scale=clamp(math.min((vp.X-20)/740,(vp.Y-50)/450),.45,1)
end
local cameraConn=nil
local function watchCamera()
    if cameraConn then cameraConn:Disconnect()end
    local camera=Workspace.CurrentCamera
    if camera then cameraConn=track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize))end
    resize()
end
track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera))
watchCamera()

track(Workspace.DescendantAdded:Connect(function(obj)
    if not Suite.Alive or not S.enabled or not S.autoApply then return end
    if obj:IsDescendantOf(wetRoot) then return end
    if obj:IsA("BasePart") then
        task.defer(function()
            if not Suite.Alive or not obj.Parent then return end
            local model=characterAncestor(obj)
            if model then applyCharacterPart(obj,model)
            else applyWetPart(obj)end
        end)
    elseif obj:IsA("Model") then
        task.defer(function()
            if Suite.Alive and obj.Parent and obj:FindFirstChildOfClass("Humanoid")then
                applyCharacter(obj)
            end
        end)
    end
end))
track(Players.PlayerAdded:Connect(function(player)
    track(player.CharacterAdded:Connect(function(ch)
        task.delay(.35,function()
            if Suite.Alive and ch.Parent then applyCharacter(ch)end
        end)
    end))
end))
for _,player in ipairs(Players:GetPlayers())do
    track(player.CharacterAdded:Connect(function(ch)
        task.delay(.35,function()
            if Suite.Alive and ch.Parent then applyCharacter(ch)end
        end)
    end))
end

function Suite:Restore()
    restoreAll()
    syncControls()
end
function Suite:Destroy()
    if not self.Alive then return end
    self.Alive=false
    for _,conn in ipairs(connections)do pcall(function()conn:Disconnect()end)end
    table.clear(connections)
    if cameraConn then pcall(function()cameraConn:Disconnect()end)end
    clearLayers()
    restoreParts()
    restoreLighting()
    if gui then gui:Destroy()end
    if wetRoot then wetRoot:Destroy()end
    if rawget(_G,"XandMeWetVisualSuite")==self then _G.XandMeWetVisualSuite=nil end
end
showTab(S.selectedTab)
syncControls()
fullApply()
syncControls()
print("[XandMe Wet Visual Suite v1.0] Active. Press F3 or click the V button.")
