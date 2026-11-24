-- XandMe | Auto Generator Repair - Studio-only test fixture
-- Install as a Script in ServerScriptService in your own place.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local RATE = 5 -- percentage points per second
local FIXTURE_NAME = "XandMe_RepairTestGenerator"

local function advance(progress, enabled, dt)
    if not enabled or dt <= 0 then return progress end
    return math.clamp(progress + RATE * dt, 0, 100)
end

-- Run deterministic checks in Studio before creating the test fixture.
assert(advance(0, false, 1) == 0, "OFF must not repair")
assert(advance(0, true, 1) == 5, "Repair rate mismatch")
assert(advance(25, false, 2) == 25, "Pause must preserve progress")
assert(advance(99, true, 1) == 100, "Progress must cap at 100")
assert(advance(100, true, 1) == 100, "Completed generator must stay complete")
assert(advance(20, true, -1) == 20, "Negative elapsed time rejected")
print("[XandMe Repair Test] 6 self-tests passed")

if workspace:FindFirstChild(FIXTURE_NAME) then
    warn("[XandMe Repair Test] Fixture already exists; remove the duplicate before testing.")
    return
end

local generator = Instance.new("Part")
generator.Name = FIXTURE_NAME
generator.Anchored = true
generator.Size = Vector3.new(5, 4, 3)
generator.Material = Enum.Material.Metal
generator.Color = Color3.fromRGB(35, 35, 35)
local spawnPoint = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
generator.CFrame = spawnPoint and (spawnPoint.CFrame * CFrame.new(8, 2, 0)) or CFrame.new(0, 3, -12)

local enabled, progress = false, 0
generator:SetAttribute("RepairEnabled", enabled)
generator:SetAttribute("RepairProgress", progress)

local prompt = Instance.new("ProximityPrompt")
prompt.ObjectText = "Studio Repair Generator"
prompt.ActionText = "Start Auto Repair"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 12
prompt.RequiresLineOfSight = true
prompt.Parent = generator

local gui = Instance.new("BillboardGui")
gui.Name = "RepairStatus"
gui.Size = UDim2.fromOffset(230, 90)
gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
gui.MaxDistance = 35
gui.AlwaysOnTop = false
gui.Parent = generator

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(1, 1)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner", panel)
corner.CornerRadius = UDim.new(0, 8)

local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Position = UDim2.fromOffset(8, 5)
label.Size = UDim2.new(1, -16, 0, 52)
label.Font = Enum.Font.GothamMedium
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 15
label.TextWrapped = true
label.Parent = panel

local track = Instance.new("Frame")
track.Position = UDim2.new(0, 12, 1, -23)
track.Size = UDim2.new(1, -24, 0, 10)
track.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
track.BorderSizePixel = 0
track.Parent = panel
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = track

local function refresh()
    generator:SetAttribute("RepairEnabled", enabled)
    generator:SetAttribute("RepairProgress", progress)
    local status = progress >= 100 and "COMPLETE" or (enabled and "ON" or "OFF")
    label.Text = string.format("AUTO GENERATOR REPAIR\n%s  |  %d%%", status, math.floor(progress))
    fill.Size = UDim2.fromScale(progress / 100, 1)
    prompt.ActionText = progress >= 100 and "Reset Generator" or (enabled and "Pause Auto Repair" or "Start Auto Repair")
end

local function canInteract(player)
    if player.Parent ~= Players then return false end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    return root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
        and (root.Position - generator.Position).Magnitude <= prompt.MaxActivationDistance + 2
end

local trigger = prompt.Triggered:Connect(function(player)
    if not canInteract(player) then return end
    if progress >= 100 then
        progress, enabled = 0, false
    else
        enabled = not enabled
    end
    refresh()
end)

local elapsed = 0
local heartbeat = RunService.Heartbeat:Connect(function(dt)
    if not enabled then return end
    progress = advance(progress, enabled, dt)
    if progress >= 100 then
        enabled = false
        elapsed = 0
        refresh()
        print("[XandMe Repair Test] Generator completed")
    else
        elapsed += dt
        if elapsed >= 0.1 then
            elapsed = 0
            refresh()
        end
    end
end)

local function cleanup()
    trigger:Disconnect()
    heartbeat:Disconnect()
end
generator.Destroying:Connect(cleanup)
script.Destroying:Connect(function()
    cleanup()
    if generator.Parent then generator:Destroy() end
end)

refresh()
generator.Parent = workspace
print("[XandMe Repair Test] Ready. Walk to the test generator and press E.")
