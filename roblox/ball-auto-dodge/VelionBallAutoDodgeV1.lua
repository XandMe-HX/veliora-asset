-- VELION BALL DODGE V1.0
-- Standalone Roblox Luau client helper.
-- Based on observed structure: Workspace.Balls -> Ball / Death Ball (BasePart).
-- Game keybinds in screenshot: Q=left dodge, E=right dodge, R=front dodge.
-- Caution: input simulation depends on the environment and game input handlers;
-- this code does not promise an invulnerability window, a saved win streak, or a server-confirmed dodge.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local previous = pg:FindFirstChild("VelionBallDodgeV1")
if previous then
    local shutdown = previous:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then
        pcall(function() shutdown:Fire() end)
    end
    previous:Destroy()
end

local config = {
    alive=true, enabled=false, edgeGuard=true, debug=false,
    sensitivity="Normal", cooldown=.85, minimized=false,
    lastDodge=-1e6, inspected=0, threats=0, actionCount=0,
    lastAction="Waiting", state="Idle", tracked=0
}
local scheme = {
    bg=Color3.fromRGB(14,17,30), surface=Color3.fromRGB(30,35,57),
    purple=Color3.fromRGB(147,109,248), green=Color3.fromRGB(61,191,143),
    white=Color3.fromRGB(239,242,255), muted=Color3.fromRGB(163,169,192),
    yellow=Color3.fromRGB(245,193,95)
}
local connections={}
local history={}
local speedCache={}
local accumulator=0
local gui

local function connect(sig,callback)
    local c=sig:Connect(callback)
    connections[#connections+1]=c
    return c
end
local function create(class,parent,props)
    local obj=Instance.new(class)
    for key,value in pairs(props or {}) do obj[key]=value end
    obj.Parent=parent
    return obj
end
local function round(obj,r)
    create("UICorner",obj,{CornerRadius=UDim.new(0,r or 8)})
end
local function label(parent,value,pos,size,fontSize)
    return create("TextLabel",parent,{
        Position=pos,Size=size,BackgroundTransparency=1,
        Text=value,TextColor3=scheme.white,
        Font=Enum.Font.Gotham,TextSize=fontSize or 12,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true
    })
end
local function button(parent,txt,y)
    local b=create("TextButton",parent,{
        Position=UDim2.fromOffset(12,y),Size=UDim2.fromOffset(346,35),
        Text=txt,BackgroundColor3=scheme.surface,TextColor3=scheme.white,
        BorderSizePixel=0,Font=Enum.Font.GothamBold,TextSize=12
    })
    round(b,7)
    return b
end

gui=create("ScreenGui",pg,{
    Name="VelionBallDodgeV1",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=950
})
local shutdown=create("BindableEvent",gui,{Name="Shutdown"})
local panel=create("Frame",gui,{
    Position=UDim2.new(.5,-185,0,55),
    Size=UDim2.fromOffset(370,316),BackgroundColor3=scheme.bg,
    BorderSizePixel=0,Active=true
})
round(panel,11)
create("UIStroke",panel,{Color=scheme.purple,Thickness=1.25})
local header=create("Frame",panel,{
    BackgroundTransparency=1,Size=UDim2.new(1,0,0,43),Active=true
})
local title=label(header,"VELION | BALL AUTO DODGE",
    UDim2.fromOffset(12,9),UDim2.fromOffset(295,26),14)
title.Font=Enum.Font.GothamBold
local mini=create("TextButton",header,{
    Position=UDim2.fromOffset(310,8),Size=UDim2.fromOffset(25,25),
    Text="-",BackgroundColor3=scheme.surface,TextColor3=scheme.white
})
round(mini,6)
local close=create("TextButton",header,{
    Position=UDim2.fromOffset(342,8),Size=UDim2.fromOffset(25,25),
    Text="X",BackgroundColor3=scheme.surface,TextColor3=scheme.white
})
round(close,6)
local onOff=button(panel,"AUTO DODGE: OFF",49)
local sense=button(panel,"SENSITIVITY: NORMAL",91)
local edge=button(panel,"EDGE GUARD: ON",133)
local debug=button(panel,"DEBUG MARKER: OFF",175)
local stat=label(panel,"Scanning Workspace.Balls...",
    UDim2.fromOffset(13,219),UDim2.fromOffset(344,83),11)
stat.TextColor3=scheme.muted
local tip=label(panel,"Q = Left   |   E = Right   |   R = Front",
    UDim2.fromOffset(15,298),UDim2.fromOffset(340,14),10)
tip.TextColor3=scheme.muted

local indicator=create("BillboardGui",gui,{
    Name="DangerMarker",Size=UDim2.fromOffset(135,34),
    StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
    AlwaysOnTop=true,Enabled=false,MaxDistance=125
})
local indicatorText=label(indicator,"INCOMING",UDim2.fromScale(0,0),
    UDim2.fromScale(1,1),12)
indicatorText.TextColor3=scheme.yellow
indicatorText.TextXAlignment=Enum.TextXAlignment.Center
indicatorText.TextStrokeTransparency=.2
indicatorText.Font=Enum.Font.GothamBold

local function refresh()
    onOff.Text=config.enabled and "AUTO DODGE: ON" or "AUTO DODGE: OFF"
    onOff.BackgroundColor3=config.enabled and scheme.green or scheme.surface
    sense.Text="SENSITIVITY: "..string.upper(config.sensitivity)
    edge.Text="EDGE GUARD: "..(config.edgeGuard and "ON" or "OFF")
    edge.BackgroundColor3=config.edgeGuard and scheme.green or scheme.surface
    debug.Text="DEBUG MARKER: "..(config.debug and "ON" or "OFF")
end
onOff.MouseButton1Click:Connect(function()
    config.enabled=not config.enabled
    config.state=config.enabled and "Monitoring ball movement" or "Disabled"
    refresh()
end)
sense.MouseButton1Click:Connect(function()
    local modes={"Safe","Normal","Aggressive"}
    for i,m in ipairs(modes) do
        if m==config.sensitivity then
            config.sensitivity=modes[i%#modes+1]
            break
        end
    end
    refresh()
end)
edge.MouseButton1Click:Connect(function()
    config.edgeGuard=not config.edgeGuard
    refresh()
end)
debug.MouseButton1Click:Connect(function()
    config.debug=not config.debug
    if not config.debug then indicator.Enabled=false end
    refresh()
end)

local function playerParts()
    local char=lp.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health<=0 or not root then return nil,nil end
    if hum.Sit then return nil,nil end
    return hum,root
end

local function isBall(p)
    return p:IsA("BasePart")
        and (p.Name=="Ball" or p.Name=="Death Ball")
end

-- Some AlignPosition-controlled balls expose unreliable instantaneous velocity.
-- Compare world-position samples, falling back to AssemblyLinearVelocity when
-- the networked position does not move between observations.
local function velocityOf(p,now)
    local data=history[p]
    local raw=p.AssemblyLinearVelocity
    local measured=Vector3.zero
    local valid=false
    if data then
        local dt=now-data.t
        if dt>.012 and dt<.3 then
            measured=(p.Position-data.pos)/dt
            valid=measured.Magnitude>3
        end
    end
    history[p]={pos=p.Position,t=now}
    if valid then
        if raw.Magnitude>3 then
            -- Measured displacement dominates because AlignPosition can drive
            -- the projectile without steady velocity replication.
            return measured*.75+raw*.25
        end
        return measured
    end
    return raw
end

local function checkGround(point,character,balls)
    -- Check for supporting floor after the proposed dodge.
    -- A missing floor is only treated as unsafe when the current player's
    -- feet DO have a floor, to avoid false negatives in custom maps.
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character,balls}
    params.RespectCanCollide=true
    local pos=point+Vector3.new(0,4,0)
    local ray=workspace:Raycast(pos,Vector3.new(0,-11,0),params)
    return ray and ray.Normal.Y>.5 or false
end

local function rayClear(startPos,endPos,character,balls)
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={character,balls}
    params.RespectCanCollide=true
    local delta=endPos-startPos
    if delta.Magnitude<.5 then return true end
    local hit=workspace:Raycast(startPos+Vector3.new(0,1,0),delta,params)
    -- Many maps have nonessential decoration; be conservative if blocked.
    return hit==nil
end

local function nearestCollision(ball,velocity,playerPosition,playerVelocity,maxTime)
    -- Relative-position closest approach (3D), future time within horizon.
    local relative=ball.Position-playerPosition
    local relVelocity=velocity-playerVelocity
    local norm=relVelocity:Dot(relVelocity)
    if norm<25 then return nil end
    local t=math.clamp(-relative:Dot(relVelocity)/norm,0,maxTime)
    if relative:Dot(relVelocity)>=0 then return nil end
    local separation=(relative+relVelocity*t).Magnitude
    return t,separation
end

local function trajectoryRisk(target,balls,now,delay)
    local minDist=math.huge
    for _,p in ipairs(balls) do
        if p.Parent and isBall(p) then
            local cache=speedCache[p]
            local v=cache and cache.v or p.AssemblyLinearVelocity
            local proj=p.Position+v*delay
            local dist=(proj-target).Magnitude-p.Size.Magnitude*.45
            if dist<minDist then minDist=dist end
        end
    end
    return minDist
end

local function sendDodge(key)
    -- Executors may provide keypress/keyrelease. Those are nonstandard.
    local code=({Q=0x51,E=0x45,R=0x52})[key]
    if type(keypress)=="function" and type(keyrelease)=="function" then
        local ok=pcall(function()
            keypress(code)
            task.delay(.075,function()pcall(function()keyrelease(code)end)end)
        end)
        if ok then return true,"executor key input" end
    end

    -- VirtualInputManager is protected in some environments.
    local ok,manager=pcall(game.GetService,game,"VirtualInputManager")
    if ok and manager then
        local keyCode=Enum.KeyCode[key]
        local pressed=pcall(function()
            manager:SendKeyEvent(true,keyCode,false,game)
        end)
        if pressed then
            task.delay(.075,function()
                pcall(function()
                    manager:SendKeyEvent(false,keyCode,false,game)
                end)
            end)
            return true,"virtual key input"
        end
    end
    return false,"input injection not supported"
end

local function detect()
    local hum,root=playerParts()
    local ballsFolder=workspace:FindFirstChild("Balls")
    if not hum or not ballsFolder then
        config.state=not hum and "Waiting for character" or "Workspace.Balls missing"
        indicator.Enabled=false
        return
    end

    local now=os.clock()
    local balls={}
    config.tracked=0
    for _,p in ipairs(ballsFolder:GetChildren()) do
        if isBall(p) then
            balls[#balls+1]=p
            config.tracked+=1
            speedCache[p]={v=velocityOf(p,now),seen=now}
        end
    end
    -- Only live Balls are tracked, no Workspace-wide scanning.
    for p in pairs(history) do
        if not p.Parent or p.Parent~=ballsFolder then
            history[p]=nil
            speedCache[p]=nil
        end
    end

    if #balls==0 then
        config.state="No active balls"
        indicator.Enabled=false
        return
    end
    if not config.enabled then
        config.state="Disabled"
        indicator.Enabled=false
        return
    end

    local profile=({
        Safe={horizon=.42,hitRadius=5.6,react=.30,range=80},
        Normal={horizon=.62,hitRadius=6.5,react=.38,range=105},
        Aggressive={horizon=.82,hitRadius=8.0,react=.50,range=125}
    })[config.sensitivity]
    local position=root.Position+Vector3.new(0,.8,0)
    local ownVel=root.AssemblyLinearVelocity
    local biggest=nil
    local dangerScore=-math.huge
    config.threats=0

    for _,p in ipairs(balls) do
        local velocity=speedCache[p].v
        if velocity.Magnitude>8
            and (p.Position-position).Magnitude<profile.range then
            local t,miss=nearestCollision(p,velocity,position,ownVel,profile.horizon)
            local hit=profile.hitRadius+math.max(p.Size.X,p.Size.Y,p.Size.Z)*.55
            if t and miss<=hit then
                config.threats+=1
                local score=(hit-miss)*3+(profile.horizon-t)*6
                if score>dangerScore then
                    dangerScore=score
                    biggest={part=p,velocity=velocity,t=t,miss=miss}
                end
            end
        end
    end

    indicator.Enabled=config.debug and biggest~=nil
    if biggest and config.debug then
        indicator.Adornee=biggest.part
        indicatorText.Text=string.format(
            "RISK: %.2fs | %.1f studs",biggest.t,biggest.miss
        )
    end

    if not biggest then
        config.state="No incoming collision predicted"
        return
    end

    config.state=string.format(
        "Incoming %s | TTC %.2fs | miss %.1f",
        biggest.part.Name,biggest.t,biggest.miss
    )
    if biggest.t>profile.react or now-config.lastDodge<config.cooldown then
        return
    end
    if UIS:GetFocusedTextBox() then return end

    -- Evaluate a sidestep on either side of the local character.
    local right=root.CFrame.RightVector
    right=Vector3.new(right.X,0,right.Z)
    if right.Magnitude<.2 then return end
    right=right.Unit
    local forward=root.CFrame.LookVector
    forward=Vector3.new(forward.X,0,forward.Z)
    forward=forward.Magnitude>.2 and forward.Unit or Vector3.new(0,0,-1)

    local checkDist=8
    local start=root.Position
    local char=lp.Character
    local baseOnGround=checkGround(start,char,ballsFolder)
    local plans={
        {key="Q",offset=-right*checkDist},
        {key="E",offset=right*checkDist},
        {key="R",offset=forward*checkDist}
    }
    local best=nil
    for _,plan in ipairs(plans) do
        local endpoint=start+plan.offset
        local grounded=checkGround(endpoint,char,ballsFolder)
        local floorOK=not config.edgeGuard or not baseOnGround or grounded
        local clear=rayClear(start,endpoint,char,ballsFolder)
        if floorOK and clear then
            local future=endpoint+Vector3.new(0,.8,0)
            local safe=trajectoryRisk(future,balls,now,.22)
            -- Penalize front dashes to prefer side dodges for streak safety.
            local value=safe-(plan.key=="R" and 2 or 0)
            if not best or value>best.value then
                best={key=plan.key,value=value}
            end
        end
    end
    if not best then
        config.state="Dodge blocked: edge / obstacles"
        return
    end

    local sent,method=sendDodge(best.key)
    if sent then
        config.lastDodge=now
        config.actionCount+=1
        config.lastAction=best.key.." sent ("..method..")"
        config.state=config.lastAction.." | unverified"
    else
        config.lastAction="INPUT ERROR: "..method
        config.state=config.lastAction
        -- Slow down retries if the environment cannot synthesize inputs.
        config.lastDodge=now
    end
end

local function getStreak()
    local stats=lp:FindFirstChild("leaderstats")
    if not stats then return "Unknown" end
    for _,name in ipairs({"WinStreak","Winstreak","Streak","CurrentStreak","WinningStreak"}) do
        local obj=stats:FindFirstChild(name)
        if obj and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
            return tostring(obj.Value)
        end
    end
    return "Unknown"
end

connect(RunService.Heartbeat,function(dt)
    if not config.alive then return end
    accumulator+=dt
    if accumulator<.035 then return end
    accumulator=0
    local ok,err=pcall(detect)
    if not ok then
        config.state="Detection error: "..tostring(err):sub(1,45)
    end
end)

task.spawn(function()
    while config.alive and gui.Parent do
        stat.Text=string.format(
            "Balls: %d | Incoming: %d | Dodges sent: %d\n"
            .."Win streak: %s (server data only)\n%s",
            config.tracked,config.threats,config.actionCount,
            getStreak(),config.state
        )
        task.wait(.25)
    end
end)

local drag=false
local dragInputPos,dragPanelPos
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true
        dragInputPos=input.Position
        dragPanelPos=panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if drag and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-dragInputPos
        panel.Position=UDim2.new(
            dragPanelPos.X.Scale,dragPanelPos.X.Offset+delta.X,
            dragPanelPos.Y.Scale,dragPanelPos.Y.Offset+delta.Y
        )
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=false
    end
end)
mini.MouseButton1Click:Connect(function()
    config.minimized=not config.minimized
    for _,item in ipairs({onOff,sense,edge,debug,stat,tip}) do
        item.Visible=not config.minimized
    end
    panel.Size=config.minimized and UDim2.fromOffset(370,43)
        or UDim2.fromOffset(370,316)
    mini.Text=config.minimized and "+" or "-"
end)

local function cleanup()
    if not config.alive then return end
    config.alive=false
    config.enabled=false
    for _,c in ipairs(connections) do c:Disconnect() end
    table.clear(history)
    table.clear(speedCache)
    gui:Destroy()
end
shutdown.Event:Connect(cleanup)
close.MouseButton1Click:Connect(cleanup)
refresh()
print("[Velion Ball Auto Dodge V1] Loaded. Q/E/R keybinds.")
print("[Auto Dodge] Toggle ON in UI. Requires supported input simulation.")
