-- VELION INFINITY LITE V1.1 | independent native Auto Dash and Auto Run
-- Client-side ball avoidance for Dodge or Die-like Roblox arenas.
-- Based on provided reference's predicted-position/pushout concept.
-- No remote code, UI libraries, auto-parry, or server invulnerability claims.
-- CFrame movement may be corrected or rejected by the server.

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Workspace=game:GetService("Workspace")
local me=Players.LocalPlayer
local playerGui=me:FindFirstChildOfClass("PlayerGui")
if not playerGui then
    warn("[Velion Infinity] PlayerGui not available")
    return
end

-- Stop earlier Velion auto-dodge when present. Two controllers would fight.
local old=playerGui:FindFirstChild("VelionBallDodgeV1")
if old then
    local stop=old:FindFirstChild("Shutdown")
    if stop and stop:IsA("BindableEvent") then
        pcall(function() stop:Fire() end)
    end
end
local duplicate=playerGui:FindFirstChild("VelionInfinityLite")
if duplicate then
    local stop=duplicate:FindFirstChild("Shutdown")
    if stop and stop:IsA("BindableEvent") then
        pcall(function() stop:Fire() end)
    end
    duplicate:Destroy()
end

local C={
    running=true,enabled=false,autoDash=false,autoRun=false,
    groundGuard=true,level="Normal",
    minimized=false,scan=0,repulsions=0,threats=0,count=0,
    state="Ready (OFF)",types="",side=1,sideUntil=0,
    lastDash=-1e6,dashAttempts=0,inputStatus="Not tested",runHeld=false,
}
local settings={
    Safe={horizon=.32,margin=2.4,step=1.4,close=8},
    Normal={horizon=.44,margin=3.2,step=2.0,close=10},
    Aggressive={horizon=.58,margin=4.2,step=2.8,close=12}
}
local colors={
    bg=Color3.fromRGB(12,15,28),surf=Color3.fromRGB(31,36,60),
    accent=Color3.fromRGB(157,119,255),white=Color3.fromRGB(242,243,255),
    green=Color3.fromRGB(51,186,141),muted=Color3.fromRGB(177,183,202)
}
local function make(class,parent,props)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    obj.Parent=parent
    return obj
end
local function corner(obj,px)
    make("UICorner",obj,{CornerRadius=UDim.new(0,px)})
end
local gui=make("ScreenGui",playerGui,{
    Name="VelionInfinityLite",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=980
})
local shutdown=make("BindableEvent",gui,{Name="Shutdown"})
local main=make("Frame",gui,{
    Position=UDim2.new(.5,-186,0,60),Size=UDim2.fromOffset(372,403),
    BackgroundColor3=colors.bg,BorderSizePixel=0,Active=true
})
corner(main,12)
make("UIStroke",main,{Color=colors.accent,Thickness=1.3})
local header=make("Frame",main,{
    Size=UDim2.fromOffset(372,43),BackgroundTransparency=1,Active=true
})
local function text(parent,content,x,y,w,h,size)
    return make("TextLabel",parent,{
        Text=content,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),TextSize=size or 12,
        TextColor3=colors.white,TextXAlignment=Enum.TextXAlignment.Left,
        BackgroundTransparency=1,TextWrapped=true,Font=Enum.Font.Gotham
    })
end
local title=text(header,"VELION | INFINITY LITE V1.1",12,8,275,28,14)
title.Font=Enum.Font.GothamBold
local function makeButton(label,x,y,w,h)
    local b=make("TextButton",main,{
        Text=label,Position=UDim2.fromOffset(x,y),
        Size=UDim2.fromOffset(w,h),BackgroundColor3=colors.surf,
        BorderSizePixel=0,TextSize=12,TextColor3=colors.white,
        Font=Enum.Font.GothamBold,AutoButtonColor=true
    })
    corner(b,7)
    return b
end
local mini=makeButton("-",304,8,25,25)
local exit=makeButton("X",337,8,25,25)
local power=makeButton("INFINITY: OFF",12,52,348,40)
local sensitivity=makeButton("SENSITIVITY: NORMAL",12,100,348,34)
local guard=makeButton("EDGE GUARD: ON",12,141,348,34)
local dash=makeButton("AUTO DASH (Q/E/R): OFF",12,183,348,36)
local run=makeButton("AUTO RUN (SHIFT): OFF",12,227,348,36)
local status=text(main,"Ready.",13,274,345,103,11)
status.TextColor3=colors.muted
local note=text(main,"Client only | Right Ctrl: toggle GUI",13,381,350,15,10)
note.TextColor3=colors.muted

local connections={}
local function connect(signal,cb)
    local conn=signal:Connect(cb)
    connections[#connections+1]=conn
    return conn
end
local function repaint()
    power.Text="INFINITY: "..(C.enabled and "ON" or "OFF")
    power.BackgroundColor3=C.enabled and colors.green or colors.surf
    sensitivity.Text="SENSITIVITY: "..string.upper(C.level)
    guard.Text="EDGE GUARD: "..(C.groundGuard and "ON" or "OFF")
    guard.BackgroundColor3=C.groundGuard and colors.green or colors.surf
    dash.Text="AUTO DASH (Q/E/R): "..(C.autoDash and "ON" or "OFF")
    dash.BackgroundColor3=C.autoDash and colors.green or colors.surf
    run.Text="AUTO RUN (SHIFT): "..(C.autoRun and "ON" or "OFF")
    run.BackgroundColor3=C.autoRun and colors.green or colors.surf
end
connect(power.MouseButton1Click,function()
    C.enabled=not C.enabled
    C.state=C.enabled and "Monitoring live balls" or "Disabled"
    repaint()
end)
connect(sensitivity.MouseButton1Click,function()
    local modes={"Safe","Normal","Aggressive"}
    for i,n in ipairs(modes) do
        if C.level==n then
            C.level=modes[i%#modes+1]
            break
        end
    end
    repaint()
end)
connect(guard.MouseButton1Click,function()
    C.groundGuard=not C.groundGuard
    repaint()
end)

-- Native dodge uses the game's Q/E/R keybinds. Executor input support
-- varies; a successful API call is NOT proof the game accepted the action.
local VIM
pcall(function()
    VIM=game:GetService("VirtualInputManager")
end)

local keyData={
    Q={code=0x51,key=Enum.KeyCode.Q},
    E={code=0x45,key=Enum.KeyCode.E},
    R={code=0x52,key=Enum.KeyCode.R},
    Shift={code=0x10,key=Enum.KeyCode.LeftShift}
}
local function emitKey(name,down)
    local binding=keyData[name]
    if not binding then return false,"invalid key" end
    local sender=down and keypress or keyrelease
    if type(sender)=="function" then
        local ok=pcall(sender,binding.code)
        if ok then return true,"executor keyboard" end
    end
    if VIM then
        local ok=pcall(function()
            VIM:SendKeyEvent(down,binding.key,false,game)
        end)
        if ok then return true,"virtual keyboard" end
    end
    return false,"input API unavailable"
end

local function releaseSprint()
    if C.runHeld then
        emitKey("Shift",false)
        C.runHeld=false
    end
end

local function pressDash(name)
    local ok,method=emitKey(name,true)
    C.inputStatus=ok and (name.." sent via "..method.." (unverified)")
        or ("Dash failed: "..method)
    if not ok then return false end
    task.delay(.075,function()
        -- Release even if the GUI is closed to avoid stuck dodge inputs.
        emitKey(name,false)
    end)
    return true
end

local function updateAutoRun()
    if not C.running then return end
    local char=me.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local moving=hum and hum.Health>0 and not hum.Sit
        and hum.MoveDirection.Magnitude>.07
    local textbox=UIS:GetFocusedTextBox()
    local desired=C.autoRun and moving and not textbox
    if desired and not C.runHeld then
        local ok,method=emitKey("Shift",true)
        if ok then
            C.runHeld=true
            C.inputStatus="Sprint held via "..method
        else
            C.inputStatus="Sprint failed: "..method
        end
    elseif not desired and C.runHeld then
        releaseSprint()
        C.inputStatus="Sprint released"
    end
end

connect(dash.MouseButton1Click,function()
    C.autoDash=not C.autoDash
    C.state=C.autoDash and "Auto Dash watching threats" or "Auto Dash OFF"
    repaint()
end)
connect(run.MouseButton1Click,function()
    C.autoRun=not C.autoRun
    if not C.autoRun then releaseSprint() end
    repaint()
end)

local samples={}
local accumulator=0
local uiAccumulator=0
local currentBalls={}
local lastScan=-math.huge
local ballFolder=nil
local maxBalls=64

local function readVelocity(part,now)
    local raw=part.AssemblyLinearVelocity
    local old=samples[part]
    local vel=raw
    if old then
        local dt=now-old.t
        if dt>.012 and dt<.3 then
            local measured=(part.Position-old.p)/dt
            if measured.Magnitude>2 then
                vel=raw.Magnitude>2 and measured*.75+raw*.25 or measured
            end
        end
    end
    if vel.Magnitude>550 then vel=vel.Unit*550 end
    samples[part]={p=part.Position,t=now,v=vel}
    return vel
end

local function scanBalls(now)
    if now-lastScan<.12 then return end
    lastScan=now
    ballFolder=Workspace:FindFirstChild("Balls")
    table.clear(currentBalls)
    local types={}
    if ballFolder then
        -- Only direct BasePart children; never scan Workspace descendants.
        for _,part in ipairs(ballFolder:GetChildren()) do
            if part:IsA("BasePart") then
                currentBalls[#currentBalls+1]=part
                types[part.Name]=(types[part.Name] or 0)+1
                if #currentBalls>=maxBalls then break end
            end
        end
    end
    local list={}
    for name,n in pairs(types) do
        list[#list+1]=name..(n>1 and (" x"..n) or "")
    end
    table.sort(list)
    C.types=table.concat(list,", ")
    if #C.types>90 then C.types=C.types:sub(1,88).."..." end
    C.count=#currentBalls
    for part in pairs(samples) do
        if not part.Parent or part.Parent~=ballFolder then
            samples[part]=nil
        end
    end
end

local params=RaycastParams.new()
params.FilterType=Enum.RaycastFilterType.Exclude
params.IgnoreWater=true
params.RespectCanCollide=true

local function safePosition(root,character,to)
    params.FilterDescendantsInstances={character,ballFolder}
    local delta=to-root.Position
    if delta.Magnitude<.1 then return false end
    local wall=Workspace:Raycast(root.Position+Vector3.new(0,1.5,0),delta,params)
    if wall then return false end
    if not C.groundGuard then return true end
    local foot=Workspace:Raycast(to+Vector3.new(0,4,0),
        Vector3.new(0,-14,0),params)
    return foot~=nil and foot.Normal.Y>.45
end

local function chooseMove(root,character,ball,velocity,profile,now)
    local xz=Vector3.new(velocity.X,0,velocity.Z)
    local relative=ball.Position-root.Position
    local dir
    if xz.Magnitude>2 then
        dir=Vector3.new(-xz.Z,0,xz.X).Unit
    else
        local away=Vector3.new(-relative.X,0,-relative.Z)
        if away.Magnitude<.1 then return nil end
        dir=away.Unit
    end
    local locked=now<C.sideUntil
    local options=locked and {C.side} or {1,-1}
    local choice=nil
    local best=-math.huge
    for _,sign in ipairs(options) do
        local offset=dir*profile.step*sign
        local destination=root.Position+offset
        if safePosition(root,character,destination) then
            local closest=math.huge
            for _,p in ipairs(currentBalls) do
                if p.Parent then
                    local v=samples[p] and samples[p].v or p.AssemblyLinearVelocity
                    local future=p.Position+v*.17
                    local dist=(future-destination).Magnitude
                        -math.max(p.Size.X,p.Size.Y,p.Size.Z)*.5
                    closest=math.min(closest,dist)
                end
            end
            -- Favor the previous sidestep slightly to prevent flip-flop.
            local score=closest+(sign==C.side and .7 or 0)
            if score>best then best=score;choice=sign end
        end
    end
    if choice then
        C.side=choice
        C.sideUntil=now+.19
        return dir*choice*profile.step
    end
    return nil
end


-- Select a native dodge key based on safe nearby destinations.
-- Relative to character orientation: Q left, E right, R forward.
-- Uses short probes rather than pathfinding or Workspace-wide scans.
local function chooseDashKey(root,character,now)
    local look=root.CFrame.LookVector
    local right=root.CFrame.RightVector
    local directions={
        {key="Q",v=-right},{key="E",v=right},{key="R",v=look}
    }
    local bestKey,bestScore=nil,-math.huge
    for _,option in ipairs(directions) do
        local v=Vector3.new(option.v.X,0,option.v.Z)
        if v.Magnitude>.1 then
            local endpoint=root.Position+v.Unit*8
            if safePosition(root,character,endpoint) then
                local nearest=math.huge
                for _,ball in ipairs(currentBalls) do
                    if ball.Parent then
                        local velocity=samples[ball] and samples[ball].v
                            or ball.AssemblyLinearVelocity
                        local predicted=ball.Position+velocity*.19
                        local gap=(predicted-endpoint).Magnitude
                            -math.max(ball.Size.X,ball.Size.Y,ball.Size.Z)*.5
                        if gap<nearest then nearest=gap end
                    end
                end
                -- Front dashes are a fallback if side moves are equally safe.
                local score=nearest-(option.key=="R" and 1.4 or 0)
                if score>bestScore then
                    bestScore,bestKey=score,option.key
                end
            end
        end
    end
    return bestKey
end

local function tick(now)
    scanBalls(now)
    C.threats=0
    if not C.enabled and not C.autoDash then
        C.state=C.autoRun and "Auto Run ready" or "All assists disabled"
        return
    end
    local character=me.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health<=0 or not root then
        C.state="Waiting for living character";return
    end
    if humanoid.Sit then C.state="Paused while seated";return end
    if not ballFolder then C.state="Workspace.Balls not found";return end
    if C.count==0 then C.state="No active ball objects";return end

    local profile=settings[C.level]
    local rootPos=root.Position
    local ownVel=root.AssemblyLinearVelocity
    local target=nil
    local worst=-math.huge
    for _,p in ipairs(currentBalls) do
        if p.Parent then
            local v=readVelocity(p,now)
            local delta=p.Position-rootPos
            if delta.Magnitude<125 then
                local relative=v-ownVel*.3
                local planar=Vector3.new(relative.X,0,relative.Z)
                local horizontal=Vector3.new(delta.X,0,delta.Z)
                local t=0
                if planar:Dot(planar)>16 then
                    t=math.clamp(-horizontal:Dot(planar)/planar:Dot(planar),
                        0,profile.horizon)
                end
                local predicted=delta+relative*t
                local h=Vector3.new(predicted.X,0,predicted.Z).Magnitude
                local ballRadius=math.max(p.Size.X,p.Size.Y,p.Size.Z)*.5
                local collision=ballRadius+2.6+profile.margin
                local close=delta.Magnitude<profile.close+ballRadius
                local toward=horizontal:Dot(planar)<0
                if (close or (toward and h<collision
                    and math.abs(predicted.Y)<4.5+ballRadius)) then
                    C.threats+=1
                    local score=collision-h+(profile.horizon-t)*6
                        +(close and 3 or 0)
                    if score>worst then
                        worst=score
                        target={ball=p,velocity=v,time=t}
                    end
                end
            end
        end
    end
    if not target then
        C.state="Clear | no collision risk"
        return
    end
    local dashSent=false
    if C.autoDash and now-C.lastDash>=.85
        and not UIS:GetFocusedTextBox() then
        local key=chooseDashKey(root,character,now)
        if key then
            C.lastDash=now
            C.dashAttempts+=1
            dashSent=pressDash(key)
        else
            C.inputStatus="Dash blocked: no safe Q/E/R direction"
        end
    end
    -- Avoid fighting a native dash with CFrame nudges during its short
    -- animation. If Auto Dash is OFF, Infinity works exactly as before.
    if not C.enabled then
        C.state=dashSent and "Dash input sent (not server-confirmed)"
            or "Threat detected; Auto Dash monitoring"
        return
    end
    if C.autoDash and now-C.lastDash<.24 and dashSent then
        C.state="Native dash attempted; Infinity paused briefly"
        return
    end

    local offset=chooseMove(root,character,target.ball,
        target.velocity,profile,now)
    if not offset then
        C.state="Threat detected; no safe nearby step"
        return
    end
    local ok=pcall(function()
        local currentVelocity=root.AssemblyLinearVelocity
        root.CFrame=root.CFrame+offset
        root.AssemblyLinearVelocity=currentVelocity
    end)
    if ok then
        C.repulsions+=1
        C.state=string.format("Client sidestep %.1f studs | TTC %.2fs",
            offset.Magnitude,target.time)
    else
        C.state="Client movement rejected"
    end
end

connect(RunService.Heartbeat,function(dt)
    if not C.running then return end
    accumulator+=math.min(dt,.10)
    uiAccumulator+=dt
    if accumulator>=.045 then
        accumulator=0
        local ok,err=pcall(tick,os.clock())
        local runOK,runErr=pcall(updateAutoRun)
        if not runOK then
            C.inputStatus="Sprint error: "..tostring(runErr):sub(1,35)
        end
        if not ok then
            C.state="Error: "..tostring(err):sub(1,52)
            C.enabled=false
            repaint()
        end
    end
    if uiAccumulator>=.24 then
        uiAccumulator=0
        status.Text=string.format(
            "Balls: %d | Threats: %d | Shifts: %d | Dashes: %d\n"
            .."Types: %s\n%s\nInput: %s\n"
            .."Dash/sprint require accepted game inputs",
            C.count,C.threats,C.repulsions,C.dashAttempts,
            C.types~="" and C.types or "none",C.state,C.inputStatus
        )
    end
end)

local drag=false
local originInput,originPanel
connect(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true
        originInput=input.Position
        originPanel=main.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if drag and input.UserInputType==Enum.UserInputType.MouseMovement then
        local diff=input.Position-originInput
        main.Position=UDim2.new(originPanel.X.Scale,originPanel.X.Offset+diff.X,
            originPanel.Y.Scale,originPanel.Y.Offset+diff.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
connect(UIS.InputBegan,function(input,processed)
    if not processed and input.KeyCode==Enum.KeyCode.RightControl then
        main.Visible=not main.Visible
    end
end)
connect(mini.MouseButton1Click,function()
    C.minimized=not C.minimized
    for _,v in ipairs({power,sensitivity,guard,dash,run,status,note}) do
        v.Visible=not C.minimized
    end
    main.Size=C.minimized and UDim2.fromOffset(372,43)
        or UDim2.fromOffset(372,403)
    mini.Text=C.minimized and "+" or "-"
end)
local function unload()
    if not C.running then return end
    C.running=false
    C.enabled=false
    C.autoDash=false
    C.autoRun=false
    releaseSprint()
    for _,v in ipairs(connections) do v:Disconnect() end
    table.clear(samples)
    table.clear(currentBalls)
    gui:Destroy()
end
connect(shutdown.Event,unload)
connect(exit.MouseButton1Click,unload)
repaint()
print("[Velion Infinity Lite V1.1] Auto Dash Q/E/R + Auto Run Shift; no external libraries")
