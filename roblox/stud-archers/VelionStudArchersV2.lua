-- Velion Stud Archers V2.0
-- Visual assistance for Stud Archers (Roblox)
-- The game may use custom 2D actors, not regular Humanoid characters.
-- No remote firing, damage editing, or reward manipulation.
-- Version: 2026-11-08 | V2.3 dynamic body-part reticle and clean hold-to-aim UI

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

for _,name in ipairs({"VelionArchersV1", "VelionArchersV2"}) do
    local prev = pg:FindFirstChild(name)
    if prev then
        local stop = prev:FindFirstChild("Shutdown")
        if stop and stop:IsA("BindableEvent") then pcall(function() stop:Fire() end) end
        prev:Destroy()
    end
end

local s = {
    alive=true, esp=true, tracer=false, trajectory=false, prediction=false,
    marker=true, warning=true, performance=true, lock=false, pick=false,
    aimPart="Head", detection=2200, arrowSpeed=280, lineLength=1,
    minimized=false, target=nil, targetData=nil, count=0, message="Scanning..."
}
local theme = {
    bg=Color3.fromRGB(16,18,30), panel=Color3.fromRGB(32,36,55),
    purple=Color3.fromRGB(148,103,248), white=Color3.fromRGB(239,243,255),
    green=Color3.fromRGB(59,192,134), gray=Color3.fromRGB(162,171,192),
    red=Color3.fromRGB(244,83,101)
}
local links, candidate, visuals, templateNames = {}, {}, {}, {}
local scanned = false
local allData = {}
local projectileNames = {"arrow","projectile","bolt"}
local fullMap = workspace:FindFirstChild("StudArchersMap")
local ref = RS:FindFirstChild("StudArchers")
if ref then
    for _,dir in ipairs({"Enemies","EnemyAvatars"}) do
        local f=ref:FindFirstChild(dir)
        if f then
            for _,v in ipairs(f:GetChildren()) do
                templateNames[v.Name:lower()]=true
            end
        end
    end
end

local function conn(signal, fn)
    local c=signal:Connect(fn); table.insert(links,c); return c
end
local function inst(kind, par, props)
    local x=Instance.new(kind)
    for k,v in pairs(props or {}) do x[k]=v end
    x.Parent=par; return x
end
local function rounded(x,n)
    inst("UICorner",x,{CornerRadius=UDim.new(0,n or 8)})
end
local function label(par,str,x,y,w,h,size)
    return inst("TextLabel",par,{
        Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1, Text=str, TextColor3=theme.white,
        TextSize=size or 12, Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true
    })
end
local function button(par,str,x,y,w,h)
    local b=inst("TextButton",par,{
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BorderSizePixel=0,BackgroundColor3=theme.panel,TextColor3=theme.white,
        Text=str,Font=Enum.Font.GothamBold,TextSize=11
    }); rounded(b); return b
end

local gui=inst("ScreenGui",pg,{
    Name="VelionArchersV2",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=950
})
local stop=inst("BindableEvent",gui,{Name="Shutdown"})
local panel=inst("Frame",gui,{
    Position=UDim2.new(.5,-206,0,45),Size=UDim2.fromOffset(412,395),
    BackgroundColor3=theme.bg,BorderSizePixel=0,Active=true
})
rounded(panel,11)
inst("UIStroke",panel,{Color=theme.purple,Thickness=1.2})
local header=inst("Frame",panel,{
    Size=UDim2.new(1,0,0,42),BackgroundTransparency=1,Active=true
})
local heading=label(header,"VELION | STUD ARCHERS V2.3",11,8,325,26,14)
heading.Font=Enum.Font.GothamBold
local mini=button(header,"-",350,8,25,24)
local close=button(header,"X",381,8,25,24)
local side=inst("Frame",panel,{
    Position=UDim2.fromOffset(9,47),Size=UDim2.fromOffset(95,304),
    BackgroundColor3=theme.panel,BorderSizePixel=0
});rounded(side)
local content=inst("Frame",panel,{
    Position=UDim2.fromOffset(112,47),Size=UDim2.fromOffset(291,304),
    BackgroundColor3=theme.panel,BorderSizePixel=0
});rounded(content)
local status=label(panel,"Preparing target data...",12,354,390,35,10)
status.TextColor3=theme.gray
local tabs,nav={},{}
for i,name in ipairs({"Combat","Visual","Radar","Settings"}) do
    tabs[name]=inst("Frame",content,{
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        Visible=(i==1)
    })
    nav[name]=button(side,name,5,8+(i-1)*49,85,40)
end
local function showTab(name)
    for k,v in pairs(tabs) do
        v.Visible=(k==name)
        nav[k].BackgroundColor3=(k==name) and theme.purple or theme.bg
    end
end
for name,b in pairs(nav) do b.MouseButton1Click:Connect(function()showTab(name)end) end
showTab("Combat")

local refreshControls={}
local function toggle(page,name,key,y)
    local b=button(page,"",10,y,271,33)
    local function refresh()
        b.Text=name..(s[key] and ": ON" or ": OFF")
        b.BackgroundColor3=s[key] and theme.green or theme.bg
    end
    refreshControls[key]=refresh
    b.MouseButton1Click:Connect(function()
        s[key]=not s[key]
        if key=="lock" and not s.lock then s.target=nil end
        refresh()
    end)
    refresh()
    return b
end
local draggingSlider=nil
local function slider(page,name,key,y,minV,maxV,step,suffix)
    label(page,name,12,y,188,20,11)
    local readout=label(page,"",206,y,70,20,11)
    readout.TextXAlignment=Enum.TextXAlignment.Right
    local rail=button(page,"",17,y+28,258,10)
    rail.AutoButtonColor=false
    rail.BackgroundColor3=Color3.fromRGB(66,68,86)
    local fill=inst("Frame",rail,{
        Size=UDim2.fromScale(0,1),BackgroundColor3=theme.purple,
        BorderSizePixel=0
    });rounded(fill,6)
    local knob=inst("Frame",rail,{
        AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),
        Size=UDim2.fromOffset(19,19),BackgroundColor3=theme.white,Active=true
    });rounded(knob,10)
    local function set(v)
        v=math.clamp(math.floor((v-minV)/step+.5)*step+minV,minV,maxV)
        s[key]=v
        local a=(v-minV)/(maxV-minV)
        fill.Size=UDim2.fromScale(a,1)
        knob.Position=UDim2.fromScale(a,.5)
        readout.Text=tostring(v)..(suffix or "")
    end
    local function fromX(x)
        local w=rail.AbsoluteSize.X
        if w<=0 then return end
        local a=math.clamp((x-rail.AbsolutePosition.X)/w,0,1)
        set(minV+(maxV-minV)*a)
    end
    local function begin(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            draggingSlider=fromX; fromX(input.Position.X)
        end
    end
    rail.InputBegan:Connect(begin);knob.InputBegan:Connect(begin)
    set(s[key])
end

toggle(tabs.Combat,"TARGET LOCK (VISUAL)","lock",10)
toggle(tabs.Combat,"TARGET MOTION LEAD (EST.)","prediction",49)
local partBtns={}
label(tabs.Combat,"TARGET BODY PART",12,90,210,20,11)
for i,name in ipairs({"Head","Body","Legs"}) do
    partBtns[name]=button(tabs.Combat,name,10+(i-1)*92,114,87,35)
    partBtns[name].MouseButton1Click:Connect(function()
        s.aimPart=name
        for n,b in pairs(partBtns) do
            b.BackgroundColor3=(n==name) and theme.purple or theme.bg
        end
    end)
end
partBtns.Head.BackgroundColor3=theme.purple
local pick=button(tabs.Combat,"PICK NPC / CHARACTER (CLICK)",10,157,271,35)
pick.MouseButton1Click:Connect(function()
    s.message="Click the enemy model in the arena"
    task.delay(.2,function()if s.alive then s.pick=true end end)
end)
local nextTarget=button(tabs.Combat,"NEXT TARGET",10,198,271,32)
nextTarget.MouseButton1Click:Connect(function()
    if #allData==0 then
        s.message="No candidates: try PICK NPC in arena"
        return
    end
    local index=0
    for i,d in ipairs(allData) do if d.model==s.target then index=i;break end end
    s.target=allData[index % #allData+1].model
    s.lock=true
    refreshControls.lock()
end)
label(tabs.Combat,"Q = Lock  |  N = Next Target\n"
    .."Hold left-click to aim with GAME preview.\nUse the green marker for Head/Body/Legs.",12,242,268,49,10)

toggle(tabs.Visual,"ENEMY ESP","esp",8)
toggle(tabs.Visual,"STRAIGHT TARGET LINE","tracer",47)
toggle(tabs.Visual,"AIMARROW DEBUG (OPTIONAL)","trajectory",86)
toggle(tabs.Visual,"HEAD / BODY / LEG MARKER","marker",125)
toggle(tabs.Visual,"PROJECTILE ALERT","warning",164)
slider(tabs.Visual,"TARGET MARKER SIZE","lineLength",212,.5,2.5,.25,"x")

local radarLabel=label(tabs.Radar,"No match detected.",12,13,269,246,12)
radarLabel.TextColor3=theme.white
toggle(tabs.Settings,"PERFORMANCE MODE","performance",8)
slider(tabs.Settings,"DETECTION DISTANCE","detection",63,100,5000,100," studs")
slider(tabs.Settings,"ESTIMATED ARROW SPEED","arrowSpeed",133,50,1000,25,"")
label(tabs.Settings,"No stage/level cap is used.\n"
    .."ESP searches Workspace active models.\n"
    .."Precise body-part marker; no fake trajectory.\n"
    .."No server-side hit or damage changes.",12,201,268,88,11)

-- Runtime actors are not necessarily Humanoids.
local function mapObject(model)
    local map=workspace:FindFirstChild("StudArchersMap")
    return map and model:IsDescendantOf(map)
end
local function localActor(model)
    if model==player.Character then return true end
    if Players:GetPlayerFromCharacter(model)==player then return true end
    local n=model.Name:lower()
    return n=="player_"..player.UserId
        or n=="player"..player.UserId
        or n==player.Name:lower()
end
local function characteristic(model)
    if not model:IsA("Model") or mapObject(model) or localActor(model) then return false end
    local n=model.Name:lower()
    if templateNames[n] or n:find("enemy",1,true)
        or n:find("boss",1,true) or n:find("npc",1,true)
        or n:match("^player_%d+") then return true end
    if model:FindFirstChildOfClass("Humanoid") then return true end
    local head=model:FindFirstChild("Head",true)
    local torso=model:FindFirstChild("Torso",true)
        or model:FindFirstChild("UpperTorso",true)
    return head~=nil and torso~=nil
end
local function register(m)
    if characteristic(m) then candidate[m]=true end
end
for _,v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Model") then register(v) end
end
conn(workspace.DescendantAdded,function(v)
    if v:IsA("Model") then
        register(v)
    elseif v:IsA("Humanoid") and v.Parent and v.Parent:IsA("Model") then
        register(v.Parent)
    elseif v:IsA("BasePart") and v.Parent and v.Parent:IsA("Model") then
        if v.Name=="Head" or v.Name=="Torso" then register(v.Parent) end
    end
end)

local function referencePosition()
    local char=player.Character
    if char then
        local part=char:FindFirstChild("HumanoidRootPart",true)
            or char:FindFirstChild("Head",true)
        if part and part:IsA("BasePart") then return part.Position,part end
    end
    local actor=workspace:FindFirstChild("Player_"..player.UserId,true)
    if actor and actor:IsA("Model") then
        local part=actor.PrimaryPart or actor:FindFirstChildWhichIsA("BasePart",true)
        if part then return part.Position,part end
    end
    local cam=workspace.CurrentCamera
    return cam and cam.CFrame.Position or Vector3.zero,nil
end

local function aimPosition(model)
    -- Always prefer actual avatar body parts; bows, accessories and props
    -- must never define the selected head/torso/legs position.
    local function named(...)
        for _,n in ipairs({...}) do
            local v=model:FindFirstChild(n,true)
            if v and v:IsA("BasePart") then return v end
        end
    end
    local head=named("Head")
    local torso=named("UpperTorso","Torso","LowerTorso")
    local mid=named("HumanoidRootPart")
    local legs={
        named("LeftFoot","LeftLowerLeg","Left Leg"),
        named("RightFoot","RightLowerLeg","Right Leg")
    }
    local selected
    if s.aimPart=="Head" then
        selected=head
    elseif s.aimPart=="Body" then
        selected=torso or mid
    elseif s.aimPart=="Legs" then
        selected=legs[1] or legs[2]
    end
    if selected then return selected.Position,selected end
    if s.aimPart=="Legs" and legs[1] and legs[2] then
        return (legs[1].Position+legs[2].Position)*.5,legs[1]
    end
    local base=torso or mid or head or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart",true)
    if not base then return nil,nil end
    local height=math.clamp(base.Size.Y*2.5,2.5,6)
    local offset=s.aimPart=="Head" and (height*.35)
        or s.aimPart=="Legs" and (-height*.30)
        or 0
    return base.Position+Vector3.new(0,offset,0),base
end
local function getData(m,origin)
    if not m.Parent or not m:IsDescendantOf(workspace) or mapObject(m) then return nil end
    local hum=m:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health<=0 then return nil end
    local position,part=aimPosition(m)
    if not position then return nil end
    local dist=(position-origin).Magnitude
    if dist>s.detection then return nil end
    return {
        model=m,part=part,point=position,distance=dist,hum=hum,
        boss=(m.Name:lower():find("boss",1,true)~=nil),
        hp=hum and hum.Health or m:GetAttribute("Health"),
        maxhp=hum and hum.MaxHealth or m:GetAttribute("MaxHealth")
    }
end

local function removeVisual(m)
    local v=visuals[m]; if not v then return end
    if v.h then v.h:Destroy() end
    if v.bb then v.bb:Destroy() end
    visuals[m]=nil
end
local function updateESP(d)
    local m=d.model
    local v=visuals[m]
    if not v then
        local h=inst("Highlight",m,{
            Name="VelionESP",Adornee=m,FillTransparency=.84,
            OutlineTransparency=.05,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        })
        local bb=inst("BillboardGui",gui,{
            Adornee=d.part,AlwaysOnTop=true,
            Size=UDim2.fromOffset(200,52),
            StudsOffsetWorldSpace=Vector3.new(0,2.7,0)
        })
        local textLabel=inst("TextLabel",bb,{
            Size=UDim2.fromScale(1,1),
            BackgroundTransparency=1,TextColor3=theme.white,
            Font=Enum.Font.GothamBold,TextSize=11,
            TextStrokeTransparency=.2,TextWrapped=true
        })
        v={h=h,bb=bb,text=textLabel};visuals[m]=v
    end
    local color=(m==s.target and theme.green) or (d.boss and theme.purple) or theme.red
    v.h.OutlineColor=color;v.h.FillColor=color
    v.bb.Adornee=d.part;v.bb.MaxDistance=s.detection
    local hp=(type(d.hp)=="number") and ("HP "..math.floor(d.hp)
        ..(type(d.maxhp)=="number" and ("/"..math.floor(d.maxhp)) or "")) or "HP ?"
    v.text.Text=m.Name.."\n"..hp.."  |  "..math.floor(d.distance).." studs"
end

local function scan()
    local origin=referencePosition()
    local result={}
    for m in pairs(candidate) do
        if not m.Parent then candidate[m]=nil;removeVisual(m)
        else
            local d=getData(m,origin)
            if d then result[#result+1]=d end
        end
    end
    table.sort(result,function(a,b)return a.distance<b.distance end)
    allData=result;s.count=#result
    local chosen=nil
    if s.target then
        for _,d in ipairs(result) do
            if d.model==s.target then chosen=d;break end
        end
    end
    if not chosen then
        chosen=result[1]
        if s.lock then s.target=chosen and chosen.model or nil end
    end
    s.targetData=chosen
    local seen={}
    if s.esp then
        local limit=s.performance and 8 or 24
        for i=1,math.min(limit,#result) do
            local d=result[i];seen[d.model]=true;updateESP(d)
        end
    end
    for m in pairs(visuals) do if not seen[m] then removeVisual(m) end end
    local d=s.targetData
    if d then
        local hp=type(d.hp)=="number" and math.floor(d.hp) or "?"
        radarLabel.Text=("TARGET: "..d.model.Name
            .."\nPART: "..s.aimPart
            .."\nDISTANCE: "..math.floor(d.distance).." studs"
            .."\nHP: "..tostring(hp)
            .."\nACTIVE MODELS: "..s.count
            .."\nLOCK: "..(s.lock and "ON" or "OFF"))
        s.message=d.model.Name.." | "..math.floor(d.distance).." studs"
    else
        radarLabel.Text="No active target found.\n\n"
            .."During a duel, click PICK NPC, then the visible enemy.\n"
            .."Maps and reference models are ignored.\n\n"
            .."Candidates: 0\nNo HumanoidRootPart required."
        s.message="No match: use PICK NPC during battle"
    end
end

-- V2.2: Do NOT invent a parabola between player and enemy.
-- The game is hold-to-aim / release-to-fire.
-- AimArrow objects, if present, are shown only at their true world positions.
local lines={}
for i=1,24 do
    local dot=inst("Frame",gui,{
        AnchorPoint=Vector2.new(.5,.5),
        BackgroundColor3=Color3.fromRGB(255,207,86),
        BorderSizePixel=0,
        Visible=false,
        Size=UDim2.fromOffset(5,5)
    })
    rounded(dot,6)
    lines[i]=dot
end

local mark=inst("Frame",gui,{
    AnchorPoint=Vector2.new(.5,.5),
    Size=UDim2.fromOffset(20,20),
    BorderSizePixel=0,BackgroundTransparency=1,Visible=false
})
rounded(mark,10)
local markerStroke=inst("UIStroke",mark,{Color=theme.green,Thickness=2.5})
local markerLabel=label(gui,"HEAD",0,0,88,19,11)
markerLabel.AnchorPoint=Vector2.new(.5,.5)
markerLabel.TextXAlignment=Enum.TextXAlignment.Center
markerLabel.Font=Enum.Font.GothamBold
markerLabel.TextStrokeTransparency=.25
markerLabel.Visible=false
local trace=inst("Frame",gui,{
    AnchorPoint=Vector2.new(.5,.5),
    BackgroundColor3=theme.red,BorderSizePixel=0,Visible=false
})
local radar=label(gui,"NO TARGET",18,130,470,46,12)
radar.Font=Enum.Font.GothamBold
radar.TextStrokeTransparency=.3

local aimStatus=label(gui,"",18,171,550,40,11)
aimStatus.Font=Enum.Font.GothamBold
aimStatus.TextColor3=Color3.fromRGB(255,207,86)
aimStatus.TextStrokeTransparency=.3

local warn=label(gui,"",0,0,500,35,15)
warn.AnchorPoint=Vector2.new(.5,0)
warn.Position=UDim2.new(.5,0,0,115)
warn.TextXAlignment=Enum.TextXAlignment.Center
warn.TextColor3=theme.red
warn.TextStrokeTransparency=.2
warn.Font=Enum.Font.GothamBold
warn.Visible=false

local function lineBetween(frame,a,b)
    local delta=b-a
    frame.Position=UDim2.fromOffset((a.X+b.X)*.5,(a.Y+b.Y)*.5)
    frame.Size=UDim2.fromOffset(delta.Magnitude,2)
    frame.Rotation=math.deg(math.atan2(delta.Y,delta.X))
end

local function screenPoint(cam,v)
    local point,visible=cam:WorldToViewportPoint(v)
    return Vector2.new(point.X,point.Y),visible and point.Z>0
end

local activeAimParts={}
local function refreshNativeMarkers()
    table.clear(activeAimParts)
    local root=workspace:FindFirstChild("StudArchersLocal")
    if not root then return end
    local inspected=0
    for _,obj in ipairs(root:GetDescendants()) do
        inspected+=1
        if inspected>3500 or #activeAimParts>=96 then break end
        if obj:IsA("BasePart") and obj.Name=="AimArrow" then
            table.insert(activeAimParts,obj)
        end
    end
end

task.spawn(function()
    while s.alive and gui.Parent do
        pcall(refreshNativeMarkers)
        task.wait(s.performance and 1.2 or .55)
    end
end)

local smoothPoint=nil
local smoothTarget=nil

local function redraw()
    local cam=workspace.CurrentCamera
    if not cam then return end

    local aiming=UIS:IsMouseButtonPressed(
        Enum.UserInputType.MouseButton1
    )
    for _,dot in ipairs(lines) do dot.Visible=false end
    mark.Visible=false
    markerLabel.Visible=false
    trace.Visible=false

    local d=s.targetData
    if not d or not d.model.Parent then
        smoothPoint=nil
        smoothTarget=nil
        radar.Text="NO TARGET | PICK NPC"
        aimStatus.Text="No active opponent model"
        return
    end

    -- Re-evaluate part on EVERY overlay update.
    -- The old implementation reused the 0.85s scanner cache, so changing
    -- Head -> Body -> Legs or tracking a moving enemy was visibly delayed.
    local point,part=aimPosition(d.model)
    if not point or not part then
        aimStatus.Text="Selected enemy has no visible body parts"
        return
    end
    d.part=part
    d.point=point
    local origin,root=referencePosition()
    d.distance=(point-origin).Magnitude
    radar.Text="TARGET: "..d.model.Name.." | "..string.upper(s.aimPart)
        .." | "..math.floor(d.distance).." studs"

    -- Optional experimental motion lead is OFF by default.
    -- It is NOT a computed impact position or validated ballistic solution.
    if s.prediction then
        local travelTime=math.clamp(
            d.distance/math.max(s.arrowSpeed,1),0,1.2
        )
        point=point+part.AssemblyLinearVelocity*travelTime
    end

    local screenPoint2,visible=screenPoint(cam,point)
    if not visible then
        markerLabel.Visible=false
        smoothPoint=nil
        aimStatus.Text="Target outside camera"
        return
    end

    if smoothTarget~=d.model then
        smoothPoint=screenPoint2
        smoothTarget=d.model
    else
        -- High responsiveness while drawing a bow.
        smoothPoint=smoothPoint:Lerp(
            screenPoint2,aiming and .95 or .82
        )
    end

    local colors={
        Head=theme.green,
        Body=theme.purple,
        Legs=Color3.fromRGB(252,195,84)
    }
    local accent=colors[s.aimPart] or theme.green
    if s.marker then
        local size=(aiming and 17 or 20)*s.lineLength
        mark.Size=UDim2.fromOffset(size,size)
        mark.Position=UDim2.fromOffset(
            smoothPoint.X,smoothPoint.Y
        )
        markerStroke.Color=accent
        markerStroke.Thickness=aiming and 2.8 or 2.0
        mark.Visible=true

        markerLabel.Text=string.upper(s.aimPart)
        markerLabel.TextColor3=accent
        markerLabel.Position=UDim2.fromOffset(
            smoothPoint.X,smoothPoint.Y-24*s.lineLength
        )
        markerLabel.Visible=true
    end

    -- Straight line is optional, OFF by default. Do not present it
    -- as a firing trajectory, impact prediction, or hit confirmation.
    if s.tracer and root and root.Parent then
        local startPos,onScreen=screenPoint(
            cam,root.Position+Vector3.new(0,2.3,0)
        )
        if onScreen then
            trace.Visible=true
            lineBetween(trace,startPos,smoothPoint)
        end
    end

    -- Native AimArrow debug: show only a few real objects CLOSE TO
    -- the shooter's world position, never the 24 scattered markers.
    if aiming and s.trajectory and #activeAimParts>0 then
        local spots={}
        for _,p in ipairs(activeAimParts) do
            if p.Parent and (p.Position-origin).Magnitude<22 then
                local xy,inView=screenPoint(cam,p.Position)
                if inView then spots[#spots+1]=xy end
            end
        end
        table.sort(spots,function(a,b) return a.X<b.X end)
        for i=1,math.min(#spots,6,#lines) do
            local dot=lines[i]
            dot.Size=UDim2.fromOffset(4,4)
            dot.Position=UDim2.fromOffset(
                spots[i].X,spots[i].Y
            )
            dot.Visible=true
        end
    end

    if aiming then
        aimStatus.Text="AIMING: "..string.upper(s.aimPart)
            .." | follow the GAME'S own arrow guide"
    else
        aimStatus.Text="HOLD LEFT CLICK to aim | release to shoot"
    end
end

local warnedUntil=0
local function projectiles()
    if not s.warning then warn.Visible=false;return end
    local origin=referencePosition()
    local params=OverlapParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances=player.Character and {player.Character} or {}
    params.MaxParts=120
    local nearby=workspace:GetPartBoundsInRadius(origin,55,params)
    for _,part in ipairs(nearby) do
        local n=part.Name:lower()
        local isArrow=false
        for _,key in ipairs(projectileNames) do
            if n:find(key,1,true) then isArrow=true;break end
        end
        if isArrow then
            local dv=origin-part.Position
            local v=part.AssemblyLinearVelocity
            if dv.Magnitude>2 and v.Magnitude>30
                and v.Unit:Dot(dv.Unit)>.7 then
                warnedUntil=os.clock()+.55
                break
            end
        end
    end
    warn.Visible=os.clock()<warnedUntil
    warn.Text=warn.Visible and "ARROW APPROACHING" or ""
end

local renderAccum=0
conn(RunService.RenderStepped,function(dt)
    if not s.alive then return end
    renderAccum+=dt
    if renderAccum<(UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and .04 or (s.performance and .075 or .03)) then return end
    renderAccum=0
    local ok,err=pcall(redraw)
    if not ok then s.message="Render error: "..tostring(err):sub(1,50) end
end)
task.spawn(function()
    while s.alive and gui.Parent do
        local ok,err=pcall(scan)
        if not ok then s.message="Scan error: "..tostring(err):sub(1,65) end
        status.Text="NPCs: "..s.count.."  |  Lock: "..(s.lock and "ON" or "OFF")
            .."\n"..s.message
        task.wait(s.performance and .85 or .35)
    end
end)
task.spawn(function()
    while s.alive and gui.Parent do
        pcall(projectiles)
        task.wait(s.performance and .4 or .18)
    end
end)

-- Pick a world model without requiring Humanoid or named enemy templates.
conn(UIS.InputBegan,function(input,processed)
    if input.KeyCode==Enum.KeyCode.Q and not processed then
        s.lock=not s.lock
        if not s.lock then s.target=nil end
        refreshControls.lock()
    elseif input.KeyCode==Enum.KeyCode.N and not processed then
        if #allData>0 then
            local ix=0
            for i,d in ipairs(allData) do if d.model==s.target then ix=i;break end end
            s.target=allData[ix%#allData+1].model
            s.lock=true;refreshControls.lock()
        end
    elseif s.pick and input.UserInputType==Enum.UserInputType.MouseButton1
        and not processed then
        local part=mouse.Target
        if part then
            local m=part:FindFirstAncestorOfClass("Model")
            local map=workspace:FindFirstChild("StudArchersMap")
            if m and not (map and m:IsDescendantOf(map)) then
                -- Prefer a character-like ancestor.
                local cur=m
                for _=1,4 do
                    if not cur or not cur:IsA("Model") then break end
                    if characteristic(cur) then m=cur;break end
                    local p=cur.Parent
                    if not p or not p:IsA("Model") then break end
                    cur=p
                end
                candidate[m]=true
                s.target=m;s.lock=true;refreshControls.lock()
                s.message="Picked: "..m:GetFullName()
            else
                s.message="Picked map/background; click enemy instead"
            end
        else s.message="No 3D part under cursor" end
        s.pick=false
    end
end)

-- Drag UI, minimize, close.
local dragging,dragStart,panelStart=false,nil,nil
conn(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true;dragStart=input.Position;panelStart=panel.Position
    end
end)
conn(UIS.InputChanged,function(input)
    if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    if draggingSlider then draggingSlider(input.Position.X) end
    if dragging then
        local delta=input.Position-dragStart
        panel.Position=UDim2.new(
            panelStart.X.Scale,panelStart.X.Offset+delta.X,
            panelStart.Y.Scale,panelStart.Y.Offset+delta.Y
        )
    end
end)
conn(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false;draggingSlider=nil
    end
end)
mini.MouseButton1Click:Connect(function()
    s.minimized=not s.minimized
    side.Visible=not s.minimized;content.Visible=not s.minimized
    status.Visible=not s.minimized
    panel.Size=s.minimized and UDim2.fromOffset(412,42)
        or UDim2.fromOffset(412,395)
    mini.Text=s.minimized and "+" or "-"
end)
local function cleanup()
    if not s.alive then return end
    s.alive=false
    for _,c in ipairs(links) do c:Disconnect() end
    for m in pairs(visuals) do removeVisual(m) end
    gui:Destroy()
end
stop.Event:Connect(cleanup)
close.MouseButton1Click:Connect(cleanup)
print("[VELION STUD ARCHERS V2] Initialized")
print("[V2.3] Dynamic Head/Body/Legs markers. Native aim owns trajectory.")
