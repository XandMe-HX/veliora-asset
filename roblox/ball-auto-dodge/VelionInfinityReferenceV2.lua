-- VELION INFINITY V2.1 - reference Infinity core with explicit native input diagnostics
-- Original mechanics credited to Leewalky. All server-side outcomes remain unverified.
-- Local GUI, bounded scans and optional input features; no external downloads.
local Config = {
	GameName = "Dodge or Die",
	GuiName = "VelionInfinityReferenceV2",
	FooterText = "Mechanics from Leewalky | Velion UI V2",
	MenuKeybind = "RightControl",
	BallsFolderName = "Balls",
	PracticePath = { "Lobby", "PracticeArea", "PracticeBalls" },
	BallKeywords = { "ball", "practice" },
	ScanRadius = 200,
	BoxWidth = 10,
	BoxHeight = 10,
	BoxDepth = 10,
	BoxOffsetY = 0,
	MaxStep = 4,
	UrgentStep = 9,
	PredictTime = 0.12,
	LeadTime = 0.35,
	UrgentTime = 0.16,
	ExtraMargin = 0.35,
	ClearMargin = 0.6,
	MaxSubsteps = 20,
	SubstepStud = 2,
	ResolvePasses = 3,
	Predictive = true,
	Vertical = true,
	KeepVelocity = true,
	NoDrag = true,
	DragEpsilon = 0.02,
	CenterDeadzone = 0.6,
	SideCommitTime = 0.4,
	Smoothing = 0.55,
	UrgentSmoothing = 1,
	MinStep = 0.03,
	VerticalDamp = 0.35,
	SlowSpeed = 2,
	ClearanceProbe = 14,
	ClearanceMin = 5,
	WallPadding = 1.2,
	GroundDrop = 60,
	RefreshInterval = 0.14,
	SphereMinSpeed = 4,
	SphereMinSize = 3,
	MaxBalls = 24,
}

local cloneref = cloneref or function(instance)
	return instance
end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local Workspace = cloneref(game:GetService("Workspace"))
local LocalPlayer = Players.LocalPlayer

local vector3New = Vector3.new
local vector3Zero = Vector3.zero
local mathHuge = math.huge
local mathMin = math.min
local mathMax = math.max
local mathAbs = math.abs
local mathCeil = math.ceil
local mathClamp = math.clamp
local tableInsert = table.insert
local osClock = os.clock
local stringLower = string.lower
local stringFind = string.find

local guiParent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
if not guiParent then
    warn("[Velion Infinity V2] PlayerGui unavailable")
    return
end

-- Replace previous Velion versions to prevent physics controller conflicts.
for _,name in ipairs({"VelionInfinityLite","VelionInfinityReferenceV2","VelionBallDodgeV1"}) do
    local old=guiParent:FindFirstChild(name)
    if old then
        local stop=old:FindFirstChild("Shutdown")
        if stop and stop:IsA("BindableEvent") then
            pcall(function() stop:Fire() end)
        end
        old:Destroy()
    end
end

local State = {
	Infinity = false,
}

local Connections = {}
local BallCache = {}
local BallVelocity = {}
local BallSample = {}
local BlockedAxes = {}

local Character, Humanoid, Root
local BallsContainer, PracticeContainer
local lastRefresh = 0
local sideSign = 1
local sideChosenAt = 0
local lastEngaged = 0

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function track(connection)
	tableInsert(Connections, connection)
	return connection
end

local function updateFilter()
	local filter = {}
	if Character then
		tableInsert(filter, Character)
	end
	if BallsContainer then
		tableInsert(filter, BallsContainer)
	end
	if PracticeContainer then
		tableInsert(filter, PracticeContainer)
	end
	raycastParams.FilterDescendantsInstances = filter
end

local function bindCharacter(character)
	Character = character
	Humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	Root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	updateFilter()
end

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))

local function resolvePath(root, path)
	local node = root
	for _, name in ipairs(path) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	return node
end

local function matchesKeyword(name)
	local lowered = stringLower(name)
	for _, keyword in ipairs(Config.BallKeywords) do
		if stringFind(lowered, keyword, 1, true) then
			return true
		end
	end
	return false
end

local function isPlayerModel(instance)
	local model = instance:FindFirstAncestorOfClass("Model")
	while model do
		if Players:GetPlayerFromCharacter(model) then
			return true
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return false
end

local function isSphereBall(part)
	if not part:IsA("Part") then
		return false
	end
	if part.Shape ~= Enum.PartType.Ball then
		return false
	end
	if part.Size.X < Config.SphereMinSize then
		return false
	end
	if part.AssemblyLinearVelocity.Magnitude < Config.SphereMinSpeed then
		return false
	end
	return not isPlayerModel(part)
end

local function collectFrom(container, parts, seen)
	for _, descendant in ipairs(container:GetDescendants()) do
		if descendant:IsA("BasePart") and not seen[descendant] then
			seen[descendant] = true
			tableInsert(parts, descendant)
		end
	end
end

local function refreshBalls(now)
    if now-lastRefresh<Config.RefreshInterval then return end
    lastRefresh=now
    local oldBalls=BallsContainer
    local oldPractice=PracticeContainer
    BallsContainer=Workspace:FindFirstChild(Config.BallsFolderName)
    PracticeContainer=resolvePath(Workspace,Config.PracticePath)
    if oldBalls~=BallsContainer or oldPractice~=PracticeContainer then
        updateFilter()
    end
    table.clear(BallCache)
    local count=0

    -- Primary live projectiles are direct BaseParts under Workspace.Balls,
    -- including Ball, Death Ball, Speed Ball and Destruction Ball.
    if BallsContainer then
        for _,item in ipairs(BallsContainer:GetChildren()) do
            if item:IsA("BasePart") then
                count+=1
                BallCache[count]=item
                if count>=Config.MaxBalls then break end
            end
        end
    end

    -- Optional practice projectiles, without traversing the whole Workspace.
    if PracticeContainer and count<Config.MaxBalls then
        for _,item in ipairs(PracticeContainer:GetDescendants()) do
            if item:IsA("BasePart") and
                (matchesKeyword(item.Name) or isSphereBall(item)) then
                count+=1
                BallCache[count]=item
                if count>=Config.MaxBalls then break end
            end
        end
    end

    for part in pairs(BallSample) do
        if not part.Parent or (BallsContainer and part.Parent~=BallsContainer
            and (not PracticeContainer or not part:IsDescendantOf(PracticeContainer))) then
            BallSample[part]=nil
            BallVelocity[part]=nil
        end
    end
end

local function velocityOf(part, position, now)
	local velocity = part.AssemblyLinearVelocity
	if velocity.Magnitude > 1 then
		BallVelocity[part] = velocity
		BallSample[part] = { position, now }
		return velocity
	end
	local sample = BallSample[part]
	if sample then
		local delta = now - sample[2]
		if delta > 0.05 then
			local estimated = (position - sample[1]) / delta
			BallVelocity[part] = estimated
			BallSample[part] = { position, now }
			return estimated
		end
		return BallVelocity[part] or velocity
	end
	BallSample[part] = { position, now }
	return BallVelocity[part] or velocity
end

local function boxGap(localPoint, radius)
	local dx = mathAbs(localPoint.X) - (Config.BoxWidth * 0.5 + radius)
	local dy = mathAbs(localPoint.Y - Config.BoxOffsetY) - (Config.BoxHeight * 0.5 + radius)
	local dz = mathAbs(localPoint.Z) - (Config.BoxDepth * 0.5 + radius)
	return mathMax(dx, mathMax(dy, dz))
end

local function clearanceAlong(origin, direction)
	local probe = Workspace:Raycast(origin, direction * Config.ClearanceProbe, raycastParams)
	if not probe then
		return Config.ClearanceProbe
	end
	return probe.Distance
end

local function chooseSide(rootCFrame, lateralWorld, offsetAlongLateral, now)
	local preferred
	if mathAbs(offsetAlongLateral) > Config.CenterDeadzone then
		preferred = offsetAlongLateral >= 0 and -1 or 1
	else
		preferred = sideSign
	end
	if now - sideChosenAt < Config.SideCommitTime then
		return sideSign
	end
	local origin = rootCFrame.Position
	local room = clearanceAlong(origin, lateralWorld * preferred)
	if room < Config.ClearanceMin then
		local otherRoom = clearanceAlong(origin, lateralWorld * -preferred)
		if otherRoom > room then
			preferred = -preferred
		end
	end
	if preferred ~= sideSign then
		sideSign = preferred
		sideChosenAt = now
	end
	return sideSign
end

local function boxExtentAlong(axis)
	return Config.BoxWidth * 0.5 * mathAbs(axis.X)
		+ Config.BoxHeight * 0.5 * mathAbs(axis.Y)
		+ Config.BoxDepth * 0.5 * mathAbs(axis.Z)
end

local function staticPushout(localPoint, radius)
	local halfX = Config.BoxWidth * 0.5 + radius + Config.ExtraMargin
	local halfY = Config.BoxHeight * 0.5 + radius + Config.ExtraMargin
	local halfZ = Config.BoxDepth * 0.5 + radius + Config.ExtraMargin
	local offsetY = localPoint.Y - Config.BoxOffsetY
	local px = halfX - mathAbs(localPoint.X)
	local py = halfY - mathAbs(offsetY)
	local pz = halfZ - mathAbs(localPoint.Z)
	if px <= 0 or py <= 0 or pz <= 0 then
		return nil
	end
	local axis = "X"
	local depth = px
	if pz < depth then
		axis = "Z"
		depth = pz
	end
	if Config.Vertical and py * (1 / Config.VerticalDamp) < depth then
		axis = "Y"
		depth = py
	end
	if axis == "X" then
		return localPoint.X >= 0 and vector3New(-1, 0, 0) or vector3New(1, 0, 0), depth
	elseif axis == "Z" then
		return localPoint.Z >= 0 and vector3New(0, 0, -1) or vector3New(0, 0, 1), depth
	end
	return offsetY >= 0 and vector3New(0, -1, 0) or vector3New(0, 1, 0), depth
end

local function safeOffset(origin, direction, distance)
	local result = Workspace:Raycast(origin, direction * (distance + Config.WallPadding), raycastParams)
	if not result then
		return distance
	end
	local allowed = result.Distance - Config.WallPadding
	if allowed <= 0.05 then
		return 0
	end
	return mathMin(distance, allowed)
end

local function stripDrag(push)
	if not Config.NoDrag then
		return push
	end
	for index = 1, #BlockedAxes do
		local axis = BlockedAxes[index]
		local along = push:Dot(axis)
		if along > 0 then
			push = push - axis * along
		end
	end
	return push
end

local function applyPush(push, urgent, now)
	push = stripDrag(push)
	local length = push.Magnitude
	if length < Config.MinStep then
		return false
	end
	local direction = push.Unit
	if urgent then
		length = mathMin(length * Config.UrgentSmoothing, Config.UrgentStep)
	else
		length = mathMin(length * Config.Smoothing, Config.MaxStep)
	end
	if length < Config.MinStep then
		return false
	end
	local origin = Root.Position
	local allowed = safeOffset(origin, direction, length)
	if allowed <= 0.02 then
		local side = vector3New(-direction.Z, 0, direction.X)
		if side.Magnitude < 0.05 then
			return false
		end
		side = stripDrag(side.Unit)
		if side.Magnitude < 0.05 then
			return false
		end
		side = side.Unit
		local sideAllowed = safeOffset(origin, side, length)
		if sideAllowed <= 0.02 then
			local flipped = stripDrag(-side)
			if flipped.Magnitude < 0.05 then
				return false
			end
			side = flipped.Unit
			sideAllowed = safeOffset(origin, side, length)
		end
		if sideAllowed <= 0.02 then
			return false
		end
		sideSign = -sideSign
		sideChosenAt = now
		direction = side
		allowed = sideAllowed
	end
	local offset = direction * allowed
	local target = origin + offset
	if mathAbs(offset.Y) < 0.05 then
		local ground = Workspace:Raycast(target + vector3New(0, 5, 0), vector3New(0, -Config.GroundDrop, 0), raycastParams)
		if not ground then
			return false
		end
	end
	local velocity = Root.AssemblyLinearVelocity
	Root.CFrame = Root.CFrame + offset
	if Config.KeepVelocity then
		Root.AssemblyLinearVelocity = velocity
	end
	return true
end

local function resolveOnce(now, deltaTime)
	local rootCFrame = Root.CFrame
	local origin = rootCFrame.Position
	local ownVelocity = Root.AssemblyLinearVelocity
	local sweepHorizon = deltaTime + (Config.Predictive and Config.PredictTime or 0)
	local leadHorizon = sweepHorizon + Config.LeadTime
	local push = vector3Zero
	local urgent = false
	local count = 0
	table.clear(BlockedAxes)
	for _, part in ipairs(BallCache) do
		if part.Parent then
			local position = part.Position
			if (position - origin).Magnitude < Config.ScanRadius then
				local radius = part.Size.X * 0.5
				local velocity = velocityOf(part, position, now)
				local relative = velocity - ownVelocity
				local speed = relative.Magnitude
				local travel = relative * leadHorizon
				local steps = 1
				local span = travel.Magnitude
				if span > Config.SubstepStud then
					steps = mathClamp(mathCeil(span / Config.SubstepStud), 1, Config.MaxSubsteps)
				end
				local threatened = false
				local threatTime = mathHuge
				for stepIndex = 0, steps do
					local fraction = stepIndex / steps
					local samplePoint = position + travel * fraction
					local localPoint = rootCFrame:PointToObjectSpace(samplePoint)
					if boxGap(localPoint, radius) < Config.ExtraMargin then
						threatened = true
						threatTime = fraction * leadHorizon
						break
					end
				end
				if threatened then
					local escape = nil
					if speed > Config.SlowSpeed then
						local approach = relative.Unit
						tableInsert(BlockedAxes, approach)
						local lateral = vector3New(approach.Z, 0, -approach.X)
						if lateral.Magnitude > 0.05 then
							lateral = lateral.Unit
							local offsetVector = position - origin
							local separation = offsetVector:Dot(lateral)
							local sign = chooseSide(rootCFrame, lateral, separation, now)
							local localLateral = rootCFrame:VectorToObjectSpace(lateral)
							local corridor = boxExtentAlong(localLateral) + radius + Config.ExtraMargin + Config.ClearMargin
							local needed = corridor - separation * sign * -1
							needed = corridor - mathAbs(separation)
							if separation * sign > 0 then
								needed = corridor + mathAbs(separation)
							end
							if needed > 0 then
								escape = lateral * sign * needed
							end
						end
					end
					if not escape then
						local localPoint = rootCFrame:PointToObjectSpace(position)
						local direction, depth = staticPushout(localPoint, radius)
						if direction then
							escape = rootCFrame:VectorToWorldSpace(direction) * depth
						end
					end
					if escape then
						if threatTime <= Config.UrgentTime then
							urgent = true
						end
						push = push + escape
						count = count + 1
					end
				end
			end
		end
	end
	if count == 0 then
		return false
	end
	lastEngaged = now
	push = vector3New(push.X, push.Y * Config.VerticalDamp, push.Z)
	return applyPush(push, urgent, now)
end

local function step(deltaTime, passes)
	if not State.Infinity then
		return
	end
	local now = osClock()
	refreshBalls(now)
	if not Root or not Root.Parent or not Humanoid or Humanoid.Health <= 0 then
		return
	end
	if now - lastEngaged > 1 then
		sideChosenAt = 0
	end
	for _ = 1, passes do
		if not resolveOnce(now, deltaTime) then
			break
		end
	end
end

track(RunService.PreSimulation:Connect(function(deltaTime)
	step(deltaTime, 1)
end))

track(RunService.PostSimulation:Connect(function(deltaTime)
	step(deltaTime, Config.ResolvePasses)
end))

-- Compact, local UI, no external Obsidian or telemetry.
local UIS=game:GetService("UserInputService")
local gui=Instance.new("ScreenGui")
gui.Name=Config.GuiName
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=980
gui.Parent=guiParent
local unloadEvent=Instance.new("BindableEvent")
unloadEvent.Name="Shutdown"
unloadEvent.Parent=gui

local Palette={
    background=Color3.fromRGB(13,16,31),
    surface=Color3.fromRGB(32,37,61),
    accent=Color3.fromRGB(158,113,253),
    enabled=Color3.fromRGB(52,180,136),
    white=Color3.fromRGB(245,246,254),
    muted=Color3.fromRGB(175,178,198)
}
local function ui(class,parent,props)
    local v=Instance.new(class)
    for k,val in pairs(props or {}) do v[k]=val end
    v.Parent=parent
    return v
end
local function rounding(parent,size)
    ui("UICorner",parent,{CornerRadius=UDim.new(0,size or 8)})
end
local panel=ui("Frame",gui,{
    Position=UDim2.new(.5,-187,0,70),
    Size=UDim2.fromOffset(374,445),
    BackgroundColor3=Palette.background,
    BorderSizePixel=0,Active=true
})
rounding(panel,12)
ui("UIStroke",panel,{Color=Palette.accent,Thickness=1.3})
local header=ui("Frame",panel,{
    Size=UDim2.fromOffset(374,44),
    BackgroundTransparency=1,Active=true
})
local function caption(parent,t,x,y,w,h,size)
    return ui("TextLabel",parent,{
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundTransparency=1,Text=t,TextColor3=Palette.white,
        Font=Enum.Font.Gotham,TextSize=size or 12,
        TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true
    })
end
local title=caption(header,"VELION | GOJO INFINITY V2.1",13,9,285,25,14)
title.Font=Enum.Font.GothamBold
local function button(title,x,y,w,h)
    local obj=ui("TextButton",panel,{
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        Text=title,TextColor3=Palette.white,
        BackgroundColor3=Palette.surface,BorderSizePixel=0,
        Font=Enum.Font.GothamBold,TextSize=12
    })
    rounding(obj,8)
    return obj
end
local mini=button("-",304,8,27,27)
local exit=button("X",337,8,27,27)
local infinity=button("GOJO INFINITY: OFF",12,52,350,42)
local autoDash=button("AUTO DASH Q/E/R: OFF",12,104,350,37)
local autoRun=button("AUTO RUN SHIFT: OFF",12,150,350,37)
local sensitivity=button("DASH SENSITIVITY: NORMAL",12,196,350,34)
local testInput=button("TEST E KEY (CHECK INPUT)",12,239,350,32)
local status=caption(panel,"Initializing...",13,280,346,132,11)
status.TextColor3=Palette.muted
local note=caption(panel,
    "InputBegan = key observed, not dash confirmed.",
    13,418,348,17,10)
note.TextColor3=Palette.muted
note.TextColor3=Palette.muted

local alive=true
local dashOn=false
local runOn=false
local runHeld=false
local lastDash=-1e6
local dashAttempts=0
local lastKey="No dash attempted"
local lastObserved="none"
local observedAt={}
local injectedKey=""
local injectingAt=-1e6
local dashSensitivity=1
local lastUi=0
local lastCheck=0
local keyMap={
    Q={code=0x51,enum=Enum.KeyCode.Q},
    E={code=0x45,enum=Enum.KeyCode.E},
    R={code=0x52,enum=Enum.KeyCode.R},
    Shift={code=0x10,enum=Enum.KeyCode.LeftShift}
}
local VIM
pcall(function() VIM=game:GetService("VirtualInputManager") end)
local function keyEvent(name,down)
    local key=keyMap[name]
    if not key then return false,"Invalid key" end
    local sender=down and keypress or keyrelease
    if type(sender)=="function" then
        local ok,result=pcall(sender,key.code)
        if ok and result~=false then return true,"executor" end
    end
    if VIM then
        local ok,result=pcall(function()
            return VIM:SendKeyEvent(down,key.enum,false,game)
        end)
        if ok and result~=false then return true,"virtual input" end
    end
    return false,"No permitted input API"
end
-- This confirms an InputBegan event, NOT that the game's dash handler ran.
track(UIS.InputBegan:Connect(function(input,processed)
    local key=input.KeyCode.Name
    if key=="Q" or key=="E" or key=="R" then
        observedAt[key]=osClock()
        local origin=(key==injectedKey and
            osClock()-injectingAt<.30) and "during injection" or "physical/other"
        lastObserved=key.." ("..origin..
            ", processed="..tostring(processed)..")"
    end
end))
local function attemptKey(name)
    local started=osClock()
    injectedKey=name
    injectingAt=started
    local ok,method=keyEvent(name,true)
    if not ok then
        lastKey=name.." FAILED: "..method
        return false
    end
    lastKey=name.." sent via "..method.."; checking events..."
    task.delay(.145,function()
        keyEvent(name,false)
    end)
    task.delay(.28,function()
        if not alive then return end
        local seen=(observedAt[name] or -1e6)>=started
        lastKey=name.." via "..method..
            (seen and " | InputBegan observed" or " | NOT OBSERVED by InputBegan")..
            " (dash unverified)"
    end)
    return true
end
local function sprintRelease()
    if runHeld then
        keyEvent("Shift",false)
        runHeld=false
    end
end
local function updateKeys()
    if not alive then return end
    local moving=Humanoid and Humanoid.Health>0 and not Humanoid.Sit
        and Humanoid.MoveDirection.Magnitude>.075
    local shouldSprint=runOn and moving and not UIS:GetFocusedTextBox()
    if shouldSprint and not runHeld then
        local ok=keyEvent("Shift",true)
        if ok then
            runHeld=true
        else
            lastKey="Sprint input unavailable"
        end
    elseif not shouldSprint and runHeld then
        sprintRelease()
    end
end

-- Native dash is optional. Core Infinity uses position pushout, not keys.
local function estimateThreat(now)
    if not Root or not Root.Parent or not Humanoid or Humanoid.Health<=0 then
        return nil,nil
    end
    local cfg={
        {dist=9,lead=.18},{dist=13,lead=.26},{dist=17,lead=.36}
    }
    local sensitivityCfg=cfg[dashSensitivity]
    local best,smallest=nil,math.huge
    for _,part in ipairs(BallCache) do
        if part.Parent then
            local delta=Root.Position-part.Position
            local dist=delta.Magnitude
            if dist<100 then
                local v=BallVelocity[part] or part.AssemblyLinearVelocity
                local speed=v.Magnitude
                if speed>8 then
                    local closing=v:Dot(delta.Unit)
                    local future=part.Position+v*sensitivityCfg.lead
                    local sep=(future-Root.Position).Magnitude
                    local radius=math.max(part.Size.X,part.Size.Y,part.Size.Z)*.5
                    if closing>10 and
                        (sep<sensitivityCfg.dist+radius or
                        (dist<sensitivityCfg.dist+radius and closing>25)) then
                        if sep<smallest then
                            smallest=sep
                            best=part
                        end
                    end
                end
            end
        end
    end
    return best,smallest
end
local function dashDirection()
    if not Root or not Character then return nil end
    local orientation=Root.CFrame
    local options={
        {key="Q",axis=-orientation.RightVector},
        {key="E",axis=orientation.RightVector},
        {key="R",axis=orientation.LookVector},
    }
    local origin=Root.Position
    local chosen,score=nil,-mathHuge
    for _,opt in ipairs(options) do
        local dir=vector3New(opt.axis.X,0,opt.axis.Z)
        if dir.Magnitude>.1 then
            dir=dir.Unit
            local room=clearanceAlong(origin,dir)
            if room>7 then
                local endpoint=origin+dir*8
                local ground=Workspace:Raycast(
                    endpoint+vector3New(0,4,0),
                    vector3New(0,-14,0),raycastParams
                )
                if ground and ground.Normal.Y>.5 then
                    local distance=mathHuge
                    for _,ball in ipairs(BallCache) do
                        if ball.Parent then
                            local v=BallVelocity[ball]
                                or ball.AssemblyLinearVelocity
                            local predicted=ball.Position+v*.18
                            distance=mathMin(distance,
                                (predicted-endpoint).Magnitude)
                        end
                    end
                    local quality=distance-(opt.key=="R" and 2 or 0)
                    if quality>score then
                        score=quality
                        chosen=opt.key
                    end
                end
            end
        end
    end
    return chosen
end
local function nativeDash()
    if not dashOn or not alive or UIS:GetFocusedTextBox() then return end
    local now=osClock()
    if now-lastDash<.90 then return end
    refreshBalls(now)
    local target=estimateThreat(now)
    if not target then return end
    local choice=dashDirection()
    if not choice then
        lastKey="Dash blocked by environment"
        return
    end
    lastDash=now
    dashAttempts+=1
    attemptKey(choice)
end
local function paint()
    infinity.Text="GOJO INFINITY: "..(State.Infinity and "ON" or "OFF")
    infinity.BackgroundColor3=State.Infinity and Palette.enabled
        or Palette.surface
    autoDash.Text="AUTO DASH Q/E/R: "..(dashOn and "ON" or "OFF")
    autoDash.BackgroundColor3=dashOn and Palette.enabled
        or Palette.surface
    autoRun.Text="AUTO RUN SHIFT: "..(runOn and "ON" or "OFF")
    autoRun.BackgroundColor3=runOn and Palette.enabled
        or Palette.surface
    local modes={"SAFE","NORMAL","AGGRESSIVE"}
    sensitivity.Text="DASH SENSITIVITY: "..modes[dashSensitivity]
end
track(infinity.MouseButton1Click:Connect(function()
    State.Infinity=not State.Infinity
    if not State.Infinity then
        sideChosenAt=0
        lastEngaged=0
        table.clear(BlockedAxes)
    end
    paint()
end))
track(autoDash.MouseButton1Click:Connect(function()
    dashOn=not dashOn
    paint()
end))
track(autoRun.MouseButton1Click:Connect(function()
    runOn=not runOn
    if not runOn then sprintRelease() end
    paint()
end))
track(sensitivity.MouseButton1Click:Connect(function()
    dashSensitivity=dashSensitivity%3+1
    paint()
end))
track(testInput.MouseButton1Click:Connect(function()
    if not alive then return end
    -- A controlled attempt, independent of threat detection and cooldown.
    attemptKey("E")
end))

track(RunService.Heartbeat:Connect(function(dt)
    if not alive then return end
    local now=osClock()
    if now-lastCheck>=.06 then
        lastCheck=now
        pcall(updateKeys)
        if dashOn then
            local ok,err=pcall(nativeDash)
            if not ok then lastKey="Dash error: "..tostring(err):sub(1,42) end
        end
    end
    if now-lastUi>=.25 then
        lastUi=now
        status.Text=string.format(
            "Balls: %d | Infinity: %s | Attempts: %d\n"
            .."Root: %s | BallFolder: %s\n"
            .."Input: %s\n"
            .."Observed Q/E/R: %s\n"
            .."Press a real key, then press TEST E to compare.",
            #BallCache,State.Infinity and "ON" or "OFF",
            dashAttempts,Root and "Ready" or "Missing",
            BallsContainer and "Found" or "Missing",
            lastKey,lastObserved
        )
    end
end))

local dragging=false
local startPos,startGuiPos
track(header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        startPos=input.Position
        startGuiPos=panel.Position
    end
end))
track(UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=input.Position-startPos
        panel.Position=UDim2.new(
            startGuiPos.X.Scale,startGuiPos.X.Offset+delta.X,
            startGuiPos.Y.Scale,startGuiPos.Y.Offset+delta.Y
        )
    end
end))
track(UIS.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=false
    end
end))
track(UIS.InputBegan:Connect(function(input,used)
    if not used and input.KeyCode==Enum.KeyCode.RightControl then
        panel.Visible=not panel.Visible
    end
end))
track(mini.MouseButton1Click:Connect(function()
    local minimized=panel.Size.Y.Offset>50
    panel.Size=minimized and UDim2.fromOffset(374,43)
        or UDim2.fromOffset(374,445)
    for _,v in ipairs({infinity,autoDash,autoRun,sensitivity,testInput,status,note}) do
        v.Visible=not minimized
    end
    mini.Text=minimized and "+" or "-"
end))
local function cleanup()
    if not alive then return end
    alive=false
    State.Infinity=false
    dashOn=false
    runOn=false
    sprintRelease()
    for _,conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)
    table.clear(BallCache)
    table.clear(BallVelocity)
    table.clear(BallSample)
    table.clear(BlockedAxes)
    gui:Destroy()
end
track(unloadEvent.Event:Connect(cleanup))
track(exit.MouseButton1Click:Connect(cleanup))
paint()
print("[Velion Gojo Infinity V2.1] Native key input diagnostics. Key sent != dash accepted.")
