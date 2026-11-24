-- XandMe | Standalone Studio generator test fixture.
-- Install as a Script in ServerScriptService in a private Studio test place.
-- No executor, external dependencies, remotes, or third-party game references.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local RATE = 8 -- percentage points per second
local CHECKPOINTS = {25, 50, 75}
local function newState()
    return {progress = 0, active = false, checks = 0, passed = 0, failed = 0}
end

local function advance(state, dt, rate, mockSuccess)
    if not state.active or state.progress >= 100 then return end
    local previous = state.progress
    state.progress = math.clamp(previous + math.max(0, dt) * math.max(0, rate), 0, 100)
    for _, checkpoint in ipairs(CHECKPOINTS) do
        if previous < checkpoint and state.progress >= checkpoint then
            state.checks += 1
            if mockSuccess then state.passed += 1 else state.failed += 1 end
        end
    end
    if state.progress >= 100 then state.active = false end
end

-- These behavioral checks run in Studio before spawning the fixture.
do
    local s = newState()
    advance(s, 10, 10, true)
    assert(s.progress == 0 and s.checks == 0, "Inactive repair must not progress")
    s.active = true
    advance(s, 3, 10, true)
    assert(s.progress == 30 and s.passed == 1, "First checkpoint must count once")
    advance(s, 1, 10, true)
    assert(s.checks == 1, "Checkpoint must not repeat")
    advance(s, 2, 10, false)
    assert(s.progress == 60 and s.failed == 1, "Mock failure must be counted")
    advance(s, 100, 10, true)
    assert(s.progress == 100 and not s.active and s.checks == 3, "Complete and clamp")
    print("[XandMe Studio] Generator model assertions passed")
end

local NAME = "XandMeStudioGeneratorFixture"
local existing = workspace:FindFirstChild(NAME)
if existing then
    warn("[XandMe Studio] Fixture already exists; no duplicate created")
    return
end
local model = Instance.new("Model")
model.Name = NAME
model.Parent = workspace
local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local origin = spawn and (spawn.Position + Vector3.new(8, 2, 0)) or Vector3.new(0, 4, 0)
local body = Instance.new("Part")
body.Name = "TestGenerator"
body.Size = Vector3.new(5, 4, 3)
body.Position = origin
body.Anchored = true
body.Color = Color3.fromRGB(35, 35, 35)
body.Material = Enum.Material.Metal
body.Parent = model

local panel = Instance.new("BillboardGui")
panel.Name = "RepairDisplay"
panel.Size = UDim2.fromOffset(250, 100)
panel.StudsOffset = Vector3.new(0, 4, 0)
panel.Adornee = body
panel.Parent = body
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
label.TextColor3 = Color3.fromRGB(240, 240, 240)
label.Font = Enum.Font.GothamMedium
label.TextSize = 16
label.TextWrapped = true
label.Parent = panel

local function prompt(name, action, key, offset)
    local attachment = Instance.new("Attachment")
    attachment.Position = offset
    attachment.Parent = body
    local p = Instance.new("ProximityPrompt")
    p.Name = name
    p.ObjectText = "Studio Test Generator"
    p.ActionText = action
    p.KeyboardKeyCode = key
    p.MaxActivationDistance = 10
    p.RequiresLineOfSight = true
    p.Parent = attachment
    return p
end

local toggle = prompt("ToggleRepair", "Start / Stop", Enum.KeyCode.E, Vector3.new(-2, 1, 0))
local reset = prompt("ResetRepair", "Reset", Enum.KeyCode.R, Vector3.new(2, 1, 0))
local outcome = prompt("MockOutcome", "Switch mock result", Enum.KeyCode.T, Vector3.new(0, -1, 0))
local state = newState()
local mockSuccess = true
local connections = {}

local function connect(signal, callback)
    connections[#connections + 1] = signal:Connect(callback)
end
local function nearby(player)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root:IsA("BasePart") and (root.Position - body.Position).Magnitude <= 12
end
local function refresh()
    local status = state.progress >= 100 and "COMPLETE" or (state.active and "REPAIRING" or "STOPPED")
    label.Text = string.format("STUDIO ONLY | %s\nRepair: %d%%\nMock checks: %d pass / %d fail\nOutcome: %s",
        status, math.floor(state.progress), state.passed, state.failed, mockSuccess and "PASS" or "FAIL")
    model:SetAttribute("RepairProgress", state.progress)
    model:SetAttribute("RepairActive", state.active)
    model:SetAttribute("MockChecksPassed", state.passed)
    model:SetAttribute("MockChecksFailed", state.failed)
end
connect(toggle.Triggered, function(player)
    if not nearby(player) or state.progress >= 100 then return end
    state.active = not state.active
    refresh()
end)
connect(reset.Triggered, function(player)
    if not nearby(player) then return end
    state = newState()
    refresh()
end)
connect(outcome.Triggered, function(player)
    if not nearby(player) then return end
    mockSuccess = not mockSuccess
    refresh()
end)
local elapsed = 0
connect(RunService.Heartbeat, function(dt)
    if not state.active then return end
    advance(state, math.min(dt, 0.25), RATE, mockSuccess)
    elapsed += dt
    if elapsed >= 0.15 or not state.active then
        elapsed = 0
        refresh()
    end
end)
connect(model.Destroying, function()
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
end)
refresh()
