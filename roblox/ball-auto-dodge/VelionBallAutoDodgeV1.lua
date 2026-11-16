-- VELION BALL DODGE V1.2 | reliable workspace scan and diagnostics
-- Standalone Roblox Luau client helper.
-- Based on observed structure: Workspace.Balls -> Ball, Death Ball, Speed Ball,
-- Destruction Ball and additional named BaseParts with 'ball' in the name.
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
    lastAction="No dodge attempts", state="Starting scan", tracked=0, types="none", confirmedMove=0,
    rawChildren=0, characterStatus="Unknown", folderStatus="Unknown", scanCount=0
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
local title=label(header,"VELION | BALL DODGE V1.2",
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
    UDim2.fromOffset(13,217),UDim2.fromOffset(344,89),10)
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
    if not char then return nil,nil,"Character missing" end
    local hum=char:FindFirstChildOfClass("Humanoid")
    local root=char:FindFirstChild("HumanoidRootPart")
    if not hum then return nil,nil,"Humanoid missing" end
    if hum.Health<=0 then return nil,nil,"Character defeated / respawning" end
    if not root or not root:IsA("BasePart") then
        return nil,nil,"RootPart missing"
    end
    if hum.Sit then return nil,nil,"Seated" end
    return hum,root,"Ready"
end

-- Workspace.Balls contains real ball Parts (including future variants).
-- Count ALL direct BasePart children, regardless of their current name.
-- Ignore nested AlignPosition, trails and attachments automatically.
local function isBall(p)
    return p:IsA("BasePart")
end

local function velocityOf(p,now)
    local prev=history[p]
    local raw=p.AssemblyLinearVelocity
    local measured=nil
    if prev then
        local dt=now-prev.t
        if dt>.008 and dt<.25 then
            measured=(p.Position-prev.pos)/dt
        end
    end
    local velocity=raw
    if measured and measured.Magnitude>2 then
        if raw.Magnitude>2 then
            velocity=measured*.7+raw*.3
        else
            velocity=measured
        end
    end
    -- Network interpolation can yield unreasonable momentary spikes.
    local maxVelocity=400
    if velocity.Magnitude>maxVelocity then
        velocity=velocity.Unit*maxVelocity
    end
    local old=speedCache[p]
    local acceleration=Vector3.zero
    if old and old.seen and now>old.seen then
        acceleration=(velocity-old.v)/math.max(.025,now-old.seen)
        if acceleration.Magnitude>550 then
            acceleration=acceleration.Unit*550
        end
    end
    history[p]={pos=p.Position,t=now}
    speedCache[p]={v=velocity,a=acceleration,seen=now}
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

-- Simulate a few short future points with observed acceleration.
-- This is an estimate only. AlignPosition may retarget between samples.
local function predicted(p,t)
    local data=speedCache[p]
    local v=data and data.v or p.AssemblyLinearVelocity
    local a=data and data.a or Vector3.zero
    return p.Position + v*t + a*(.5*t*t)
end

local function possibleImpact(p,playerPos,playerVel,horizon,hitRadius)
    local data=speedCache[p]
    local velocity=data and data.v or p.AssemblyLinearVelocity
    local gap=(p.Position-playerPos).Magnitude
    if gap<=hitRadius then return 0,gap end
    if velocity.Magnitude<4 then return nil,nil end
    local bestT=0
    local closest=gap
    local step=math.min(.06,horizon/8)
    local t=step
    while t<=horizon+1e-4 do
        local at=predicted(p,t)
        local expectedPlayer=playerPos+playerVel*math.min(t,.22)
        local d=(at-expectedPlayer).Magnitude
        if d<closest then closest=d;bestT=t end
        t+=step
    end
    if closest<=hitRadius then return bestT,closest end

    -- Conservative near-field fallback for a fast homing ball that can
    -- change heading faster than simple constant-velocity prediction.
    local toward=playerPos-p.Position
    if gap<hitRadius+14 and gap>0 then
        local closing=velocity:Dot(toward.Unit)
        if closing>12 then
            local eta=(gap-hitRadius)/closing
            if eta>=0 and eta<=math.min(horizon,.30) then
                return eta,closest
            end
        end
    end
    return nil,closest
end

local function trajectoryRisk(target,balls,now,delay)
    local minimum=math.huge
    for _,p in ipairs(balls) do
        if p.Parent and isBall(p) then
            local ballRadius=math.max(p.Size.X,p.Size.Y,p.Size.Z)*.5
            -- Evaluate the destination at multiple points. Avoid steering
            -- the player toward another simultaneously incoming ball.
            for _,t in ipairs({.12,.22,.36}) do
                local future=predicted(p,math.max(t,delay))
                local dist=(future-target).Magnitude-ballRadius
                if dist<minimum then minimum=dist end
            end
        end
    end
    return minimum
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
    -- First update ball counts, regardless of character existence, respawn,
    -- whether Auto Dodge is enabled, or if currently in the lobby.
    local ballsFolder=workspace:FindFirstChild("Balls")
    config.scanCount+=1
    config.tracked=0
    config.rawChildren=0
    config.types="none"
    config.folderStatus=ballsFolder and "Found" or "Missing"
    local balls={}
    local typeCount={}
    local now=os.clock()
    if ballsFolder then
        local children=ballsFolder:GetChildren()
        config.rawChildren=#children
        for _,p in ipairs(children) do
            if isBall(p) then
                balls[#balls+1]=p
                config.tracked+=1
                typeCount[p.Name]=(typeCount[p.Name] or 0)+1
                velocityOf(p,now)
            end
        end
    end
    local typeList={}
    for name,count in pairs(typeCount) do
        typeList[#typeList+1]=name..(count>1 and (" x"..count) or "")
    end
    table.sort(typeList)
    config.types=table.concat(typeList,", ")
    if #config.types>72 then
        config.types=config.types:sub(1,69).."..."
    end
    -- Only live Balls are tracked, no Workspace-wide scanning.
    for p in pairs(history) do
        if not ballsFolder or p.Parent~=ballsFolder then
            history[p]=nil
            speedCache[p]=nil
        end
    end

    local hum,root,characterStatus=playerParts()
    config.characterStatus=characterStatus
    config.threats=0
    if not ballsFolder then
        config.state="Workspace.Balls is NOT present on client"
        indicator.Enabled=false
        return
    end
    if #balls==0 then
        config.state=config.rawChildren>0
            and "Folder populated but no BasePart children"
            or "Folder empty: no balls spawned in this phase"
        indicator.Enabled=false
        return
    end
    if not hum then
        config.state="Balls found; "..characterStatus.."; prediction paused"
        indicator.Enabled=false
        return
    end
    if not config.enabled then
        config.state="Balls found; Auto Dodge switched OFF"
        indicator.Enabled=false
        return
    end

    local profile=({
        Safe={horizon=.52,hitRadius=5.6,react=.36,range=100},
        Normal={horizon=.72,hitRadius=6.6,react=.46,range=135},
        Aggressive={horizon=.90,hitRadius=8.0,react=.55,range=170}
    })[config.sensitivity]
    local position=root.Position+Vector3.new(0,.8,0)
    local ownVel=root.AssemblyLinearVelocity
    local biggest=nil
    local dangerScore=-math.huge
    config.threats=0

    for _,p in ipairs(balls) do
        local velocity=speedCache[p].v
        if (p.Position-position).Magnitude<profile.range then
            local hit=profile.hitRadius+math.max(p.Size.X,p.Size.Y,p.Size.Z)*.5
            local t,miss=possibleImpact(
                p,position,ownVel,profile.horizon,hit
            )
            if t then
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
        config.lastAction=best.key.." input sent ("..method..")"
        config.state=config.lastAction.." | awaiting movement"
        local origin=root.Position
        local charAtSend=lp.Character
        task.delay(.22,function()
            if not config.alive then return end
            local currentRoot=charAtSend and charAtSend:FindFirstChild("HumanoidRootPart")
            if currentRoot and currentRoot.Parent then
                local delta=(currentRoot.Position-origin).Magnitude
                if delta>2.5 then
                    config.confirmedMove+=1
                    config.lastAction=best.key.." | movement observed ("..string.format("%.1f",delta).." studs)"
                else
                    config.lastAction=best.key.." | NO displacement detected; input may be ignored"
                end
            end
        end)
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
    if accumulator<.025 then return end
    accumulator=0
    local ok,err=pcall(detect)
    if not ok then
        config.state="Detection error: "..tostring(err):sub(1,45)
    end
end)

task.spawn(function()
    while config.alive and gui.Parent do
        stat.Text=string.format(
            "Balls: %d / %d | Risk: %d | Keys: %d | Motion: %d\n"
            .."Folder: %s | Char: %s | Scan: %d\n"
            .."Types: %s\n"
            .."State: %s",
            config.tracked,config.rawChildren,config.threats,
            config.actionCount,config.confirmedMove,
            config.folderStatus,config.characterStatus,
            config.scanCount,config.types,config.state
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
print("[Velion Ball Auto Dodge V1.2] Count all direct BaseParts before checking character.")
print("[Auto Dodge] Toggle ON in UI. Requires supported input simulation.")
