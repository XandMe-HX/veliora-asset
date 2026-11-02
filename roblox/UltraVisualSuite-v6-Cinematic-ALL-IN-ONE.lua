--!strict
-- ULTRA VISUAL SUITE v6.0.0 | Standalone client-side visual controller
-- Standalone Luau build: no ModuleScript or RemoteEvent dependency.
-- Intended for authorized client-side use only. No real DLSS/AI upscaling.
-- No account data, HTTP requests, external services, or server persistence.
-- Client lighting and material changes are best-effort and may be blocked by the engine.
-- UI: F3 / glass launcher. Reflectance is skybox-based, NOT SSR.
-- Texture safe by design: original materials, SurfaceAppearance, textures, faces,
-- clothing, decals, mesh IDs and physics are not replaced or overwritten.
-- Files 01..14 are sequential code fragments; use the combined file to execute.

local Config = (function()
--!strict
-- Ultra Visual Suite 6.0 | Shared, data-only graphics configuration.
local C = {}

C.Order = {"Off", "Balanced", "Ultra", "High Ultra", "Cinematic", "Max"}
C.Presets = {
    Off = {specular=0,diffuse=0,shadow=0,bloom=0,bloomSize=0,saturation=0,contrast=0,density=0,rays=0,dof=0,gloss=0},
    Balanced = {specular=.72,diffuse=.52,shadow=.32,bloom=.11,bloomSize=16,saturation=.05,contrast=.045,density=.075,rays=.015,dof=0,gloss=.55},
    Ultra = {specular=.87,diffuse=.65,shadow=.26,bloom=.16,bloomSize=19,saturation=.065,contrast=.065,density=.09,rays=.027,dof=0,gloss=.76},
    ["High Ultra"] = {specular=.96,diffuse=.72,shadow=.23,bloom=.20,bloomSize=21,saturation=.08,contrast=.08,density=.10,rays=.038,dof=0,gloss=.89},
    Cinematic = {specular=1,diffuse=.85,shadow=.24,bloom=.22,bloomSize=25,saturation=.11,contrast=.115,density=.1,rays=.04,dof=0,gloss=.97},
    Max = {specular=1,diffuse=.95,shadow=.12,bloom=.31,bloomSize=29,saturation=.15,contrast=.15,density=.11,rays=.07,dof=0,gloss=1},
}
C.FinishOrder = {"Original", "Polished", "Wet Look", "Chrome Highlights"}
-- These modes modify reflectance only. None swaps Metal, Glass or SmoothPlastic.

C.TimeOrder = {"Auto", "Day", "Golden Hour", "Sunset", "Dusk", "Night", "Neon Night", "Cinematic", "Realistic"}
C.WeatherOrder = {"Clear", "Overcast", "Foggy", "Rainy"}
C.Weather = {
    Clear = {density=1, haze=1, exposure=0},
    Overcast = {density=1.28, haze=1.4, exposure=.025},
    Foggy = {density=1.65, haze=1.6, exposure=.06},
    Rainy = {density=1.28, haze=1.28, exposure=.04},
}
-- Hour, ambient, outdoor, tint, exposure, bloom multiplier, haze.
local function profile(hour: number, ambient: Color3, outdoor: Color3, tint: Color3, exposure: number, bloom: number, haze: number)
    return {hour=hour, ambient=ambient, outdoor=outdoor, tint=tint, exposure=exposure, bloom=bloom, haze=haze}
end
C.Modes = {
    Day = profile(12.5, Color3.fromRGB(60,63,70), Color3.fromRGB(145,150,160), Color3.fromRGB(255,252,249), -.12, .9, .5),
    ["Golden Hour"] = profile(17, Color3.fromRGB(82,65,56), Color3.fromRGB(160,132,108), Color3.fromRGB(255,234,204), -.09, .85, 1.1),
    Sunset = profile(18.1, Color3.fromRGB(76,57,72), Color3.fromRGB(142,106,129), Color3.fromRGB(255,219,211), .03, .8, 1.15),
    Dusk = profile(19, Color3.fromRGB(54,58,80), Color3.fromRGB(100,113,144), Color3.fromRGB(225,231,255), .17, .72, .8),
    Night = profile(0, Color3.fromRGB(51,57,79), Color3.fromRGB(85,101,139), Color3.fromRGB(220,232,255), .27, .6, .38),
    ["Neon Night"] = profile(.5, Color3.fromRGB(54,46,78), Color3.fromRGB(89,84,142), Color3.fromRGB(230,222,255), .21, .95, .6),
    Cinematic = profile(16.4, Color3.fromRGB(63,57,66), Color3.fromRGB(139,130,147), Color3.fromRGB(255,241,225), -.06, .85, .8),
}
C.AutoKeys = {
    {hour=0, mode="Night"}, {hour=5, mode="Night"}, {hour=7, mode="Day"},
    {hour=12, mode="Day"}, {hour=17, mode="Golden Hour"},
    {hour=18.1, mode="Sunset"}, {hour=19, mode="Dusk"},
    {hour=20.5, mode="Night"}, {hour=24, mode="Night"},
}
C.FeatureOrder = {"Lighting", "MapAdaptive", "Glossy", "AllObjects", "PBRVariants",
    "Bloom", "Colors", "Atmosphere", "Sharpness", "DOF", "Sky", "Water", "WetGround", "Lamps",
    "CharacterAccents", "Characters", "Transparent", "Neon", "SoftSunRays"}
C.SliderOrder = {"Glossy","Reflectance","SurfaceStrength","Specular","ShadowStrength","ShadowSoftness","ShadowLift","Ambient",
    "Bloom","GlowThreshold","Saturation","Contrast","Clarity","HighlightProtection","Exposure",
    "WaterReflection","WaterClarity","WaterDepth","WaterWaves","Density","Haze","FogDistance","SunRays","BatchPace"}

C.Defaults = {
    preset="Cinematic",mode="Auto",weather="Clear",finish="Chrome Highlights",adaptive=false,
    features={Lighting=true,MapAdaptive=true,Glossy=true,AllObjects=true,PBRVariants=false,
        Bloom=true,Colors=true,Atmosphere=true,Sharpness=true,DOF=false,Sky=false,
        Water=true,WetGround=false,Lamps=false,CharacterAccents=true,
        Characters=false,Transparent=false,Neon=false,SoftSunRays=true},
    sliders={Glossy=.94,Reflectance=.75,SurfaceStrength=.80,Specular=.94,
        ShadowStrength=.55,ShadowSoftness=.22,ShadowLift=.55,Ambient=.45,
        Bloom=.64,GlowThreshold=.68,Saturation=.57,Contrast=.66,Clarity=.70,
        HighlightProtection=.75,Exposure=.5,WaterReflection=.58,WaterClarity=.70,WaterDepth=.50,WaterWaves=.40,
        Density=.30,Haze=.48,FogDistance=.65,SunRays=.65,BatchPace=.54}
}

function C.Copy(source: any): any
    if type(source) ~= "table" then return source end
    local out = {}
    for key, value in pairs(source) do out[key] = C.Copy(value) end
    return out
end
local function option(options: {string}, value: any): boolean
    return type(value) == "string" and table.find(options, value) ~= nil
end
function C.Sanitize(source: any): any
    local out = C.Copy(C.Defaults)
    if type(source) ~= "table" then return out end
    if option(C.Order, source.preset) then out.preset = source.preset end
    if option(C.TimeOrder, source.mode) then out.mode = source.mode end
    if option(C.WeatherOrder, source.weather) then out.weather = source.weather end
    if option(C.FinishOrder, source.finish) then out.finish = source.finish end
    if type(source.adaptive) == "boolean" then out.adaptive = source.adaptive end
    if type(source.features) == "table" then
        for key in pairs(out.features) do
            if type(source.features[key]) == "boolean" then out.features[key] = source.features[key] end
        end
    end
    if type(source.sliders) == "table" then
        for key in pairs(out.sliders) do
            local v = source.sliders[key]
            if type(v) == "number" and v == v and v > -math.huge and v < math.huge then
                out.sliders[key] = math.clamp(v, 0, 1)
            end
        end
    end
    return out
end
function C.Profile(mode: string, clock: number): any
    if mode ~= "Auto" and mode ~= "Realistic" then
        return C.Modes[mode] or C.Modes.Day
    end
    local hour = clock % 24
    local points = C.AutoKeys
    for i=1, #points - 1 do
        local first, last = points[i], points[i+1]
        if hour >= first.hour and hour <= last.hour then
            local a, b = C.Modes[first.mode], C.Modes[last.mode]
            local t = math.clamp((hour-first.hour)/(last.hour-first.hour), 0, 1)
            local result = {
                hour=hour, ambient=a.ambient:Lerp(b.ambient, t),
                outdoor=a.outdoor:Lerp(b.outdoor, t), tint=a.tint:Lerp(b.tint, t),
                exposure=a.exposure+(b.exposure-a.exposure)*t,
                bloom=a.bloom+(b.bloom-a.bloom)*t,
                haze=a.haze+(b.haze-a.haze)*t,
            }
            if mode == "Realistic" then
                result.exposure *= .75
                result.bloom *= .75
                result.haze *= .7
            end
            return result
        end
    end
    return C.Modes.Day
end
return C

end)()


-- UltraVisualSuite v6: Part 02/14
-- This is a continuation, not independently executable.

local Controller = (function(Config)
--!strict
-- Ultra Visual Suite 6.0 | One texture-safe controller, staged scans and adaptive lighting.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local RS = game:GetService("ReplicatedStorage")
-- Config passed from the inline module

local Controller = {}
Controller.__index = Controller
local LP = {"Brightness","ClockTime","GeographicLatitude","Ambient","OutdoorAmbient",
    "ColorShift_Top","ColorShift_Bottom","EnvironmentDiffuseScale","EnvironmentSpecularScale",
    "ExposureCompensation","GlobalShadows","ShadowSoftness","LightingStyle",
    "PrioritizeLightingQuality","Technology"}
local AP = {"Density","Offset","Haze","Glare","Color","Decay"}
local SP = {"CelestialBodiesShown","StarCount","MoonAngularSize","SunAngularSize"}
local WP = {"WaterReflectance","WaterTransparency","WaterColor","WaterWaveSize","WaterWaveSpeed"}
local EFFECTS = {Bloom="BloomEffect",Color="ColorCorrectionEffect",Rays="SunRaysEffect",DOF="DepthOfFieldEffect",MenuBlur="BlurEffect"}
local BASE_REFLECT = {
    [Enum.Material.Metal]=.16, [Enum.Material.DiamondPlate]=.14,
    [Enum.Material.Glass]=.065, [Enum.Material.Marble]=.105,
    [Enum.Material.Granite]=.075, [Enum.Material.Ice]=.085,
    [Enum.Material.SmoothPlastic]=.15,
    [Enum.Material.Plastic]=.10,
    [Enum.Material.WoodPlanks]=.07,
    [Enum.Material.Wood]=.035,
    [Enum.Material.Concrete]=.055,
    [Enum.Material.Asphalt]=.07,
    [Enum.Material.Slate]=.08,
    [Enum.Material.Rock]=.025,
}
local VARIANTS = {
    [Enum.Material.Metal]="UVS_Metal", [Enum.Material.DiamondPlate]="UVS_DiamondPlate",
    [Enum.Material.Marble]="UVS_Marble", [Enum.Material.Granite]="UVS_Granite",
}
local WET = {[Enum.Material.Asphalt]=true,[Enum.Material.Concrete]=true,[Enum.Material.Slate]=true,
    [Enum.Material.WoodPlanks]=true,[Enum.Material.Wood]=true,[Enum.Material.Rock]=true}
-- All-objects mode does not stop at a fixed count; scanning yields between batches.
-- Very large experiences may require Balanced for acceptable performance.

local function get(object: Instance, property: string): any
    local ok, v = pcall(function() return (object :: any)[property] end)
    if ok then return v end
    return nil
end
local function put(object: Instance, property: string, value: any): boolean
    if value == nil then return false end
    local ok = pcall(function()
        if (object :: any)[property] ~= value then (object :: any)[property] = value end
    end)
    return ok
end
local function snap(object: Instance, keys: {string}): {[string]:any}
    local result = {}
    for _, k in ipairs(keys) do
        local v = get(object, k)
        if v ~= nil then result[k] = v end
    end
    return result
end
local function restore(object: Instance, values: {[string]:any})
    for k, v in pairs(values) do put(object, k, v) end
end
local function isCharacter(part: BasePart): boolean
    local ancestor = part.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then return true end
        ancestor = ancestor.Parent
    end
    return false
end
local function idx(name: string): number
    return table.find(Config.Order, name) or 1
end
local function effective(self: any): string
    return Config.Order[math.max(1, idx(self.state.preset)-self.downgrade)]
end

function Controller.new(settings: any): any
    local self: any = setmetatable({}, Controller)
    self.alive, self.active, self.comparing, self.photo = true, false, false, false
    self.testing = false
    self.failedWrites = {}
    self.lastApply = 0
    self.menuOpen = false
    self.state = Config.Sanitize(settings)
    self.changed = Instance.new("BindableEvent")
    self.connections = {}
    self.tweens = {}
    self.effects = {}
    self.pending = {}
    self.pendingSet = setmetatable({}, {__mode="k"})
    self.parts = setmetatable({}, {__mode="k"})
    self.lamps = setmetatable({}, {__mode="k"})
    self.trackedCount = 0
    self.replacedCount = 0
    self.materialFailures = 0
    self.scanBusy=false;self.scanCount=0;self.scanQueued=0;self.scanBatchCount=0
    self.skippedTextures=0
    self.mapLighting={}
    self.pumping, self.scheduled, self.applying = false, false, false
    self.scanVersion = 0
    self.surfaceKey, self.lampKey = "", ""
    self.ownUntil = 0
    self.sourceClock = Lighting.ClockTime
    self.lastFixed = false
    self.night = false
    self.downgrade, self.lowSamples, self.highSamples = 0, 0, 0
    self.frames, self.seconds, self.fps = 0, 0, 60
    self.originalLighting = snap(Lighting, LP)
    self.mapLighting = snap(Lighting, LP)
    self.originalWater = snap(Workspace.Terrain, WP)
    self.atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    self.sky = Lighting:FindFirstChildOfClass("Sky")
    self.originalAtmosphere = if self.atmosphere then snap(self.atmosphere, AP) else nil
    self.originalSky = if self.sky then snap(self.sky, SP) else nil
    self.createdAtmosphere, self.createdSky = false, false
    self.originalEffects = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("PostEffect") then
            self.originalEffects[child] = child.Enabled
        end
    end

    -- A new client session is clean; hot reload first invokes the old controller's Cleanup.
    for _, child in ipairs(Lighting:GetChildren()) do
        if child.Name == "UVS_Runtime" or
            (string.sub(child.Name,1,4)=="UVS_" and child:IsA("PostEffect")) then
            child:Destroy()
        end
    end
    self.folder = Instance.new("Folder")
    self.folder.Name = "UVS_Runtime"
    self.folder:SetAttribute("Build", "6.0.0")
    self.folder.Parent = Lighting

    table.insert(self.connections, Lighting.Changed:Connect(function(property)
        if not self.alive or self.applying or os.clock() < self.ownUntil then return end
        if property == "ClockTime" then
            if self.state.mode == "Auto" or self.state.mode == "Realistic" then
                self.sourceClock = Lighting.ClockTime
            end
            -- Fixed modes are periodically reconciled instead of fighting a
            -- game time script on every frame.
            return
        end
        if self.active and table.find(LP,property) then
            self.mapLighting[property]=get(Lighting,property)
            self:Schedule()
        end
    end))
    table.insert(self.connections, Workspace.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") and self.active then self:Queue(inst) end
    end))
    table.insert(self.connections, Workspace.DescendantRemoving:Connect(function(inst)
        if inst:IsA("BasePart") and self.parts[inst] then self:RestorePart(inst) end
    end))
    table.insert(self.connections, CollectionService:GetInstanceAddedSignal("UVS_Lamp"):Connect(function()
        self.lampKey = ""
        self:Schedule()
    end))
    table.insert(self.connections, CollectionService:GetInstanceAddedSignal("UVS_Glossy"):Connect(function(inst)
        if inst:IsA("BasePart") then self:Queue(inst) end
    end))
    table.insert(self.connections, CollectionService:GetInstanceAddedSignal("UVS_Exclude"):Connect(function(inst)
        if inst:IsA("BasePart") then self:RestorePart(inst) end
    end))
    table.insert(self.connections, CollectionService:GetInstanceRemovedSignal("UVS_Exclude"):Connect(function(inst)
        if inst:IsA("BasePart") then self:Queue(inst) end
    end))
    -- Camera can be recreated during respawn or cutscenes. Keep local effects on current camera.
    table.insert(self.connections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if not self.alive then return end
        for _, fx in pairs(self.effects) do
            if fx and fx.Parent then
                local parent = Workspace.CurrentCamera or Lighting
                fx.Parent = parent
            end
        end
        self:Schedule()
    end))
    table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
        self:Sample(dt)
    end))
    task.spawn(function()
        while self.alive do
            task.wait(2.5)
            if self.alive and self.active then
                if (self.state.mode=="Auto" or self.state.mode=="Realistic")
                    and not self.lastFixed then self.sourceClock = Lighting.ClockTime end
                self:Schedule()
            end
        end
    end)
    self:Schedule()
    return self
end

function Controller:GetState(): any return Config.Copy(self.state) end
function Controller:Metrics(): any
    local n = 0
    for _, effect in pairs(self.effects) do
        if effect.Parent == (Workspace.CurrentCamera or Lighting) then n += 1 end
    end
    return {fps=self.fps, preset=self.state.preset, effective=effective(self),
        finish=self.state.finish, replaced=self.replacedCount, failures=self.materialFailures,
        scanBusy=self.scanBusy or self.pumping,scanCount=self.scanCount,scanQueued=self.scanQueued,
        skippedTextures=self.skippedTextures,effects=n, parts=self.trackedCount, comparing=self.comparing, photo=self.photo, testing=self.testing,
        clock=Lighting.ClockTime, exposure=Lighting.ExposureCompensation,
        colorActive=(self.effects.Color~=nil and self.effects.Color.Enabled==true),
        cameraEffect=(self.effects.Color~=nil and self.effects.Color.Parent==(Workspace.CurrentCamera or Lighting))}
end
function Controller:Notify()
    if self.alive then self.changed:Fire(self:GetState(), self:Metrics()) end
end
function Controller:Update(group: string, key: any, value: any?)
    if group=="preset" then self.state.preset=key; self.downgrade=0
    elseif group=="mode" then self.state.mode=key
    elseif group=="weather" then self.state.weather=key
    elseif group=="finish" then self.state.finish=key
    elseif group=="adaptive" then self.state.adaptive=key; self.downgrade=0
    elseif group=="features" and self.state.features[key]~=nil then self.state.features[key]=value
    elseif group=="sliders" and self.state.sliders[key]~=nil then self.state.sliders[key]=value
    else return end
    self.state=Config.Sanitize(self.state)
    self:Schedule(); self:Notify()
end
function Controller:Load(values: any)
    self.state=Config.Sanitize(values)
    self.downgrade=0
    self:Schedule(); self:Notify()
end
function Controller:Reset()
    self.state=Config.Copy(Config.Defaults)
    self.downgrade=0; self.comparing=false; self.photo=false
    self:Schedule(); self:Notify()
end
function Controller:Compare(on: boolean)
    self.comparing=on
    self:Schedule(); self:Notify()
end
function Controller:Photo(on: boolean)
    self.photo=on
    self:Schedule(); self:Notify()
end
function Controller:MenuBlur(show: boolean)
    self.menuOpen=show
    -- No full-world blur: sharp clothing and faces remain legible in settings.
    self:DropEffect("MenuBlur")
end
function Controller:VisualTest()
    if not self.alive or self.state.preset=="Off" then return end
    self.comparing=false
    self.testing=true
    self:Apply()
    self:Notify()
    task.delay(3.2,function()
        if not self.alive then return end
        self.testing=false
        self:Schedule()
        self:Notify()
    end)
end
function Controller:Schedule()
    if self.scheduled or not self.alive then return end
    self.scheduled=true
    task.delay(.25, function()
        self.scheduled=false
        if self.alive then self:Apply() end
    end)
end
function Controller:StopTweens()
    for _, t in ipairs(self.tweens) do t:Cancel(); t:Destroy() end
    table.clear(self.tweens)
end
function Controller:Tween(inst: Instance, props: {[string]:any}, duration: number)
    for k, v in pairs(props) do
        if v == nil or get(inst,k) == v then continue end
        local ok, tween = pcall(function()
            return TweenService:Create(inst,TweenInfo.new(duration,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{[k]=v})
        end)
        if ok and tween then
            table.insert(self.tweens,tween)
            tween:Play()
        else
            put(inst,k,v)
        end
    end
end
function Controller:Effect(kind: string): any
    local found=self.effects[kind]
    local parent=Workspace.CurrentCamera or Lighting
    if found and found.Parent==parent then return found end
    if found and found.Parent then
        found.Parent=parent
        return found
    end
    local cls=EFFECTS[kind]
    if not cls then return nil end
    found=Instance.new(cls)
    found.Name="UVS_"..kind
    found.Parent=parent -- Camera-local post-processing; validated against Roblox docs.
    self.effects[kind]=found
    return found
end
function Controller:DropEffect(kind: string)
    local found=self.effects[kind]
    if found then found:Destroy(); self.effects[kind]=nil end
end
function Controller:Atmosphere(): Atmosphere
    if self.atmosphere and self.atmosphere.Parent==Lighting then return self.atmosphere end
    local new=Instance.new("Atmosphere"); new.Name="UVS_Atmosphere"; new.Parent=Lighting
    self.atmosphere=new; self.createdAtmosphere=true
    return new
end
function Controller:Sky(): Sky
    if self.sky and self.sky.Parent==Lighting then return self.sky end
    local new=Instance.new("Sky"); new.Name="UVS_Sky"; new.Parent=Lighting
    self.sky=new; self.createdSky=true
    return new
end

-- UltraVisualSuite v6: Part 03/14
-- This is a continuation, not independently executable.

function Controller:RestorePart(part: BasePart)
    local old=self.parts[part]
    if old then
        if part.Parent then
            put(part,"Reflectance",old.reflectance)
            if old.variantApplied then put(part,"MaterialVariant",old.variant) end
        end
        self.parts[part]=nil
        self.trackedCount=math.max(0,self.trackedCount-1)
    end
end
function Controller:RestoreParts()
    self.scanVersion+=1
    self.pending={};self.pendingSet=setmetatable({}, {__mode="k"})
    self.scanBusy=false
    for part in pairs(self.parts) do self:RestorePart(part) end
    self.surfaceKey="";self.replacedCount=0
end
function Controller:RestoreLamps()
    for light, original in pairs(self.lamps) do
        if light.Parent then put(light,"Brightness",original) end
    end
    table.clear(self.lamps)
    self.lampKey=""
end
function Controller:Restore()
    self:StopTweens()
    self.applying=true
    self.ownUntil=os.clock()+1.2
    restore(Lighting,self.originalLighting)
    restore(Workspace.Terrain,self.originalWater)
    for key in pairs(self.effects) do self:DropEffect(key) end
    if self.atmosphere then
        if self.createdAtmosphere then self.atmosphere:Destroy(); self.atmosphere=nil; self.createdAtmosphere=false
        elseif self.originalAtmosphere then restore(self.atmosphere,self.originalAtmosphere) end
    end
    if self.sky then
        if self.createdSky then self.sky:Destroy(); self.sky=nil; self.createdSky=false
        elseif self.originalSky then restore(self.sky,self.originalSky) end
    end
    -- Existing game post-effects were never modified by UVS v2.
    self:RestoreParts()
    self:RestoreLamps()
    self.active=false; self.lastFixed=false
    self.sourceClock=self.originalLighting.ClockTime or self.sourceClock
    self.applying=false
    self:Notify()
end

function Controller:Queue(part: BasePart)
    if not self.active or not part:IsDescendantOf(Workspace) or self.pendingSet[part] then return end
    self.pendingSet[part]=true
    table.insert(self.pending,part)
    self.scanQueued+=1
    if self.pumping then return end
    self.pumping=true
    task.spawn(function()
        while self.alive and #self.pending>0 do
            local batch=self.pending
            self.pending={}
            self.pendingSet=setmetatable({}, {__mode="k"})
            for i,entry in ipairs(batch) do
                if not self.alive then break end
                self:UpdatePart(entry)
                self.scanBatchCount+=1
                if i%65==0 then task.wait(.008+self.state.sliders.BatchPace*.022) end
            end
            task.wait()
        end
        self.pumping=false
    end)
end
function Controller:ScanParts()
    self.scanVersion+=1
    local version=self.scanVersion
    self.scanCount=0;self.scanQueued=0;self.scanBatchCount=0
    self.skippedTextures=0;self.scanBusy=true
    task.spawn(function()
        -- Progressive breadth-first walk: no single giant GetDescendants allocation.
        local list: {[number]: Instance}={[1]=Workspace}
        local head,tail=1,1
        while head<=tail and self.alive and version==self.scanVersion do
            local node=list[head]
            list[head]=nil
            head+=1
            if not node then continue end
            for _,child in ipairs(node:GetChildren()) do
                if not self.alive or version~=self.scanVersion then return end
                self.scanCount+=1
                if child:IsA("BasePart") then self:Queue(child) end
                if #child:GetChildren()>0 then
                    tail+=1;list[tail]=child
                end
                if self.scanCount%100==0 then
                    self:Notify()
                    task.wait(.008+self.state.sliders.BatchPace*.022)
                end
            end
        end
        if self.alive and version==self.scanVersion then
            self.scanBusy=false
            self:Notify()
        end
    end)
end
function Controller:UpdatePart(part: BasePart)
    if not self.active or not part:IsDescendantOf(Workspace) then return end
    local f=self.state.features
    if (not f.Glossy and not f.WetGround) or CollectionService:HasTag(part,"UVS_Exclude") then
        self:RestorePart(part);return
    end
    if part.Transparency>=1 or (part.Transparency>.4 and not f.Transparent) then
        self:RestorePart(part);return
    end
    if part.Material==Enum.Material.Neon and not f.Neon then
        self:RestorePart(part);return
    end
    local character=isCharacter(part)
    if character then
        if not f.Characters and not f.CharacterAccents then self:RestorePart(part);return end
        if not f.Characters and not part:FindFirstAncestorOfClass("Accessory") then
            self:RestorePart(part);return
        end
    end
    local style=self.state.finish
    if style=="Original" then self:RestorePart(part);return end
    local material=part.Material
    local textured=(part:IsA("MeshPart") and part.TextureID~="")
        or part:FindFirstChildOfClass("SurfaceAppearance")~=nil
        or part:FindFirstChildOfClass("Texture")~=nil
        or part:FindFirstChildOfClass("Decal")~=nil
    local base=BASE_REFLECT[material] or (if f.AllObjects then .065 else 0)
    local wet=f.WetGround and (self.state.weather=="Rainy" or style=="Wet Look")
        and WET[material]==true and part.CFrame.UpVector.Y>.65
    if wet then base=math.max(base,.10) end
    if base<=0 then self:RestorePart(part);return end
    local p=Config.Presets[effective(self)]
    local s=self.state.sliders
    local scale=p.gloss*s.Glossy*(.35+s.SurfaceStrength*.85)
    local amount=if style=="Polished" then .95 elseif style=="Wet Look" then 1.04 else 1.32
    local target=base*scale*amount*(.45+s.Reflectance*1.05)
    if material==Enum.Material.Metal or material==Enum.Material.DiamondPlate then
        target=math.max(target,.14*scale*amount)
    end
    if wet then target=math.max(target,.19*scale) end
    local cap=if style=="Chrome Highlights" then .56 else .33
    if character then
        cap=if textured then .125 else .19
    elseif textured then
        cap=math.min(cap,.23)
    end
    target=math.clamp(target,0,cap)
    local old=self.parts[part]
    if not old then
        old={reflectance=part.Reflectance,variant=part.MaterialVariant,variantApplied=false}
        self.parts[part]=old
        self.trackedCount+=1
    end
    -- Never write Material, Color, Transparency, TextureID, SurfaceAppearance or physics.
    put(part,"Reflectance",math.max(old.reflectance,target))
    -- Opt-in only: Studio-authored material variants on explicitly tagged parts.
    if f.PBRVariants and CollectionService:HasTag(part,"UVS_PBR")
        and not textured and old.variant=="" then
        local name=VARIANTS[material]
        if name then
            local ok,v=pcall(function()
                return MaterialService:GetMaterialVariant(material,name)
            end)
            if ok and v then old.variantApplied=put(part,"MaterialVariant",name) end
        end
    elseif old.variantApplied then
        put(part,"MaterialVariant",old.variant)
        old.variantApplied=false
    end
end
function Controller:SurfaceRefresh()
    local f=self.state.features
    local key=table.concat({effective(self),self.state.finish,self.state.weather,
        tostring(f.Glossy),tostring(f.WetGround),tostring(f.CharacterAccents),
        tostring(f.Characters),tostring(f.AllObjects),tostring(f.Neon),
        tostring(f.Transparent),tostring(f.PBRVariants),
        tostring(self.state.sliders.SurfaceStrength),
        tostring(self.state.sliders.Glossy),tostring(self.state.sliders.Reflectance)},"|")
    if key~=self.surfaceKey then self.surfaceKey=key;self:ScanParts() end
end
function Controller:UpdateLamps()
    if not self.active or not self.state.features.Lamps then self:RestoreLamps(); return end
    local key=tostring(self.night)
    if key==self.lampKey then return end
    self.lampKey=key
    for _, inst in ipairs(CollectionService:GetTagged("UVS_Lamp")) do
        if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
            if self.lamps[inst]==nil then self.lamps[inst]=inst.Brightness end
            put(inst,"Brightness",math.min(self.lamps[inst]*(if self.night then 1.12 else 1),4))
        end
    end
end


-- UltraVisualSuite v6: Part 04/14
-- This is a continuation, not independently executable.

function Controller:Apply()
    if not self.alive or self.applying then return end
    self.lastApply=os.clock()
    local state=self.state
    local name=effective(self)
    if name=="Off" or self.comparing then
        if self.active then self:Restore() end
        return
    end
    local preset=Config.Presets[name]
    local f,s=state.features,state.sliders
    local fixed=state.mode~="Auto" and state.mode~="Realistic"
    if not fixed and self.lastFixed then put(Lighting,"ClockTime",self.sourceClock) end
    if not fixed then self.sourceClock=Lighting.ClockTime end
    local profile=Config.Profile(state.mode,self.sourceClock)
    local weather=Config.Weather[state.weather]
    self.night=profile.hour<6.5 or profile.hour>=18.5
    self.lastFixed=fixed;self.active=true;self.applying=true
    self.ownUntil=os.clock()+1.15
    self:StopTweens()
    local originals=self.originalLighting
    local map=if f.MapAdaptive then self.mapLighting else originals
    local values={
        Brightness=map.Brightness,Ambient=map.Ambient,
        OutdoorAmbient=map.OutdoorAmbient,ColorShift_Top=map.ColorShift_Top,
        ColorShift_Bottom=map.ColorShift_Bottom,
        EnvironmentSpecularScale=map.EnvironmentSpecularScale,
        EnvironmentDiffuseScale=map.EnvironmentDiffuseScale,
        ExposureCompensation=map.ExposureCompensation,
        ShadowSoftness=map.ShadowSoftness,
    }
    if f.Lighting then
        values.Brightness=math.clamp(map.Brightness or 2,.15,5)
        local a=map.Ambient or Color3.fromRGB(80,80,80)
        local o=map.OutdoorAmbient or Color3.fromRGB(127,127,127)
        local lift=math.clamp(.34+s.ShadowLift*.47+s.Ambient*.14-s.ShadowStrength*.46,0,.82)
        local neutral=if self.night then Color3.fromRGB(125,135,155) else Color3.fromRGB(160,159,158)
        values.Ambient=a:Lerp(neutral,lift)
        values.OutdoorAmbient=o:Lerp(neutral,math.clamp(lift*.62,0,.54))
        if fixed then
            values.Ambient=values.Ambient:Lerp(profile.ambient,.18)
            values.OutdoorAmbient=values.OutdoorAmbient:Lerp(profile.outdoor,.18)
            put(Lighting,"ClockTime",profile.hour)
        end
        values.EnvironmentSpecularScale=math.clamp(
            math.max(map.EnvironmentSpecularScale or 0,preset.specular*(.45+s.Specular*.5)),0,1)
        values.EnvironmentDiffuseScale=math.clamp(
            math.max(map.EnvironmentDiffuseScale or 0,preset.diffuse*(.45+s.Ambient*.55)),0,1)
        values.ShadowSoftness=math.clamp(s.ShadowSoftness,0,1)
        values.ExposureCompensation=math.clamp((map.ExposureCompensation or 0)
            +(s.Exposure-.5)*.9+(if self.night then .05 else 0)
            -s.HighlightProtection*(if self.night then .04 else .14)+weather.exposure,-.75,.65)
        put(Lighting,"GlobalShadows",true)
        -- May be client-restricted; put() uses protected write.
        put(Lighting,"LightingStyle",Enum.LightingStyle.Realistic)
        put(Lighting,"PrioritizeLightingQuality",true)
    else
        put(Lighting,"GlobalShadows",originals.GlobalShadows)
        if f.Glossy then
            values.EnvironmentSpecularScale=math.max(map.EnvironmentSpecularScale or 0,
                preset.specular*s.Specular*.75)
        end
        if fixed then put(Lighting,"ClockTime",self.sourceClock) end
    end
    -- LightingStyle is restricted on ordinary client scripts. No fake Future API.
    self:Tween(Lighting,values,.65)

-- UltraVisualSuite v6: Part 05/14
-- This is a continuation, not independently executable.

    if f.Water then
        local w=self.originalWater
        put(Workspace.Terrain,"WaterReflectance",math.clamp(.07+s.WaterReflection*.66,0,.73))
        put(Workspace.Terrain,"WaterTransparency",math.clamp((w.WaterTransparency or .3)*.45
            +s.WaterClarity*.58,.08,.91))
        -- This is a global tint: depth-dependent attenuation is engine-controlled.
        local baseColor=w.WaterColor or Color3.fromRGB(17,70,80)
        put(Workspace.Terrain,"WaterColor",baseColor:Lerp(
            Color3.fromRGB(13,52,72),s.WaterDepth*.34))
        local rain=state.weather=="Rainy"
        put(Workspace.Terrain,"WaterWaveSize",math.clamp(
            (w.WaterWaveSize or 0)+s.WaterWaves*.12+(if rain then .05 else 0),0,.58))
        put(Workspace.Terrain,"WaterWaveSpeed",math.clamp(
            (w.WaterWaveSpeed or 0)+(if rain then 5 else s.WaterWaves*5),0,55))
    else restore(Workspace.Terrain,self.originalWater) end


-- UltraVisualSuite v6: Part 06/14
-- This is a continuation, not independently executable.

    if f.Bloom then
        local fx=self:Effect("Bloom")
        local strength=math.clamp(preset.bloom*(.22+s.Bloom*.9)*profile.bloom
            *(1-s.HighlightProtection*.42),0,if self.night then .21 else .27)
        if state.mode=="Neon Night" then strength=math.min(strength*1.2,.3) end
        self:Tween(fx,{Intensity=strength,Size=preset.bloomSize,
            Threshold=math.clamp(1.30-s.GlowThreshold*.28,.96,1.30)},.55)
        fx.Enabled=true
    else self:DropEffect("Bloom") end


-- UltraVisualSuite v6: Part 07/14
-- This is a continuation, not independently executable.

    if f.Colors or f.Sharpness then
        local fx=self:Effect("Color")
        local sat=if f.Colors then preset.saturation*(.3+s.Saturation*1.35) else 0
        local contrast=if f.Colors then preset.contrast*(.3+s.Contrast*1.4) else 0
        if f.Sharpness then contrast+=.024*s.Clarity end -- cosmetic pseudo-clarity only
        local tint=if f.Colors and fixed
            then Color3.new(1,1,1):Lerp(profile.tint,.20)
            else Color3.new(1,1,1)
        local bright=if self.night then .009 else 0
        if self.testing then
            sat=.35;contrast=.17;bright=.06
            tint=Color3.fromRGB(255,185,225)
        end
        self:Tween(fx,{Saturation=math.clamp(sat,0,.23),
            Contrast=math.clamp(contrast,0,.23),Brightness=bright,TintColor=tint},.4)
        fx.Enabled=true
    else self:DropEffect("Color") end


-- UltraVisualSuite v6: Part 08/14
-- This is a continuation, not independently executable.

    if f.Atmosphere then
        local at=self:Atmosphere()
        local source=self.originalAtmosphere
        local rain=state.weather=="Rainy"
        local density=math.clamp((source and source.Density or preset.density)
            *(.25+s.Density*1.3)*(1.75-s.FogDistance*1.4)
            *(if state.weather=="Clear" then 1 else weather.density),.005,.42)
        local haze=math.clamp((source and source.Haze or .65)
            *(.22+s.Haze*1.9)*(if rain then 1.3 else weather.haze),0,3)
        self:Tween(at,{Density=density,Offset=(source and source.Offset or .12),
            Haze=haze,Glare=if self.night then .015 else .07,
            Color=(source and source.Color or Color3.fromRGB(204,215,235)),
            Decay=(source and source.Decay or Color3.fromRGB(137,152,180))},.7)
        if f.SoftSunRays then
            local rays=self:Effect("Rays")
            self:Tween(rays,{Intensity=if self.night then 0 else math.clamp(preset.rays*(.15+s.SunRays*2),0,.14),Spread=.7},.55)
            rays.Enabled=true
        else self:DropEffect("Rays") end
    else
        self:DropEffect("Rays")
        if self.atmosphere then
            if self.createdAtmosphere then
                self.atmosphere:Destroy();self.atmosphere=nil;self.createdAtmosphere=false
            elseif self.originalAtmosphere then
                restore(self.atmosphere,self.originalAtmosphere)
            end
        end
    end


-- UltraVisualSuite v6: Part 09/14
-- This is a continuation, not independently executable.

    if f.DOF or self.photo then
        local fx=self:Effect("DOF")
        self:Tween(fx,{FarIntensity=if self.photo then .045 else .01,
            NearIntensity=0,FocusDistance=85,
            InFocusRadius=if self.photo then 120 else 220},.6)
        fx.Enabled=true
    else self:DropEffect("DOF") end


-- UltraVisualSuite v6: Part 10/14
-- This is a continuation, not independently executable.

    if f.Sky then
        local sky=self:Sky()
        put(sky,"CelestialBodiesShown",true)
        put(sky,"StarCount",if self.night then 1600 else 400)
        put(sky,"MoonAngularSize",11)
        put(sky,"SunAngularSize",14)
    elseif self.sky then
        if self.createdSky then self.sky:Destroy(); self.sky=nil; self.createdSky=false
        elseif self.originalSky then restore(self.sky,self.originalSky) end
    end

    self.applying=false
    self:SurfaceRefresh()
    self:UpdateLamps()
    self:MenuBlur(self.menuOpen)
    self:Notify()
end


-- UltraVisualSuite v6: Part 11/14
-- This is a continuation, not independently executable.

function Controller:Sample(dt: number)
    if not self.alive then return end
    self.frames+=1
    self.seconds+=math.min(dt,.5)
    if self.seconds<4 then return end
    self.fps=math.floor(self.frames/math.max(.01,self.seconds))
    self.frames=0;self.seconds=0
    if self.state.adaptive and self.state.preset~="Off" then
        if self.fps<27 then self.lowSamples+=1;self.highSamples=0
        elseif self.fps>52 then self.highSamples+=1;self.lowSamples=0
        else self.lowSamples=0;self.highSamples=0 end
        local maxLoss=math.max(0,idx(self.state.preset)-2)
        if self.lowSamples>=3 and self.downgrade<maxLoss then
            self.downgrade+=1;self.lowSamples=0;self:Schedule()
        elseif self.highSamples>=5 and self.downgrade>0 then
            self.downgrade-=1;self.highSamples=0;self:Schedule()
        end
    end
    self:Notify()
end
function Controller:Destroy()
    if not self.alive then return end
    self:Restore()
    self.alive=false
    for _, conn in ipairs(self.connections) do conn:Disconnect() end
    table.clear(self.connections)
    self:StopTweens()
    if self.folder then self.folder:Destroy() end
    self.changed:Destroy()
end
return Controller

end)(Config)


-- UltraVisualSuite v6: Part 12/14
-- This is a continuation, not independently executable.

do
--!strict
-- Ultra Visual Suite | Runtime UI, input, adaptive performance, DataStore bridge.
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
-- Config is inlined above
-- Controller is inlined above
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
-- No DataStore RemoteEvent in standalone build.
local oldShutdown=playerGui:FindFirstChild("UVS_Shutdown")
if oldShutdown and oldShutdown:IsA("BindableFunction") then
    pcall(function() oldShutdown:Invoke() end)
end
local oldGui=playerGui:FindFirstChild("UltraVisualSuiteUI")
if oldGui then oldGui:Destroy() end

local initial=Config.Copy(Config.Defaults)
if UIS.TouchEnabled and not UIS.KeyboardEnabled then initial.preset="Balanced" end
local graphics=Controller.new(initial)
local connections: {RBXScriptConnection}={}
local disposed=false
local userEdited=false
local saveSequence=0
local open=false
local photo=false
local activeDrag: any = nil
-- No remote event in standalone build.
local qualityHint="Graphics Quality: unknown"
local ok, quality=pcall(function()
    return UserSettings():GetService("UserGameSettings").SavedQualityLevel
end)
if ok and quality then
    qualityHint="Graphics Quality: " .. (if quality==Enum.SavedQualitySetting.Automatic then "Auto" else quality.Name)
end

local ui=Instance.new("ScreenGui")
ui.Name="UltraVisualSuiteUI"
ui.ResetOnSpawn=false
ui.IgnoreGuiInset=false
ui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ui.Parent=playerGui
local function round(inst: Instance, amount: number)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,amount)
    c.Parent=inst
end
local function border(inst: Instance)
    local s=Instance.new("UIStroke")
    s.Color=Color3.fromRGB(128,112,215)
    s.Transparency=.65
    s.Thickness=1
    s.Parent=inst
end
local function text(parent: Instance, content: string, size: number): TextLabel
    local t=Instance.new("TextLabel")
    t.Size=UDim2.new(1,0,0,26)
    t.BackgroundTransparency=1
    t.Text=content
    t.TextColor3=Color3.fromRGB(226,230,241)
    t.Font=Enum.Font.Gotham
    t.TextSize=size
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextWrapped=true
    t.Parent=parent
    return t
end
local function button(parent: Instance, content: string): TextButton
    local b=Instance.new("TextButton")
    b.Name=content
    b.Size=UDim2.new(1,0,0,34)
    b.BackgroundColor3=Color3.fromRGB(38,41,58)
    b.TextColor3=Color3.fromRGB(231,233,244)
    b.Font=Enum.Font.GothamMedium
    b.TextSize=11
    b.Text=content
    b.AutoButtonColor=true
    b.Selectable=true
    b.Parent=parent
    round(b,8)
    return b
end

local launcher=button(ui,"VISUALS  |  F3")
launcher.AnchorPoint=Vector2.new(1,0)
launcher.Position=UDim2.new(1,-12,0,12)
launcher.Size=UDim2.fromOffset(142,39)
launcher.BackgroundColor3=Color3.fromRGB(29,31,53)
launcher.BackgroundTransparency=.16
border(launcher)
local launcherGradient=Instance.new("UIGradient")
launcherGradient.Color=ColorSequence.new(Color3.fromRGB(45,49,80),Color3.fromRGB(51,34,79))
launcherGradient.Rotation=35
launcherGradient.Parent=launcher

local panel=Instance.new("Frame")
panel.Name="SettingsPanel"
panel.AnchorPoint=Vector2.new(.5,.5)
panel.Position=UDim2.fromScale(.5,.5)
panel.Size=UDim2.fromOffset(388,570)
panel.BackgroundColor3=Color3.fromRGB(21,24,43)
panel.BackgroundTransparency=.12
panel.BorderSizePixel=0
panel.Visible=false
panel.ClipsDescendants=true
panel.Parent=ui
round(panel,18)
border(panel)
-- Glass aesthetic: translucent surface, cool-to-violet gradient, soft outline.
-- This is a UI simulation, NOT a CSS-style region-limited backdrop blur.
local panelGradient=Instance.new("UIGradient")
panelGradient.Rotation=110
panelGradient.Color=ColorSequence.new({
    ColorSequenceKeypoint.new(0,Color3.fromRGB(27,34,57)),
    ColorSequenceKeypoint.new(.55,Color3.fromRGB(23,24,40)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(41,31,67))
})
panelGradient.Parent=panel
local glassAccent=Instance.new("Frame")
glassAccent.Name="GlassAccent"
glassAccent.BackgroundColor3=Color3.fromRGB(164,146,255)
glassAccent.BackgroundTransparency=.22
glassAccent.BorderSizePixel=0
glassAccent.Position=UDim2.fromOffset(18,60)
glassAccent.Size=UDim2.new(1,-36,0,1)
glassAccent.Parent=panel
local accentGradient=Instance.new("UIGradient")
accentGradient.Transparency=NumberSequence.new({
    NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.12),
    NumberSequenceKeypoint.new(.7,.12),NumberSequenceKeypoint.new(1,1)
})
accentGradient.Parent=glassAccent
local scale=Instance.new("UIScale")
scale.Parent=panel

local title=text(panel,"ULTRA VISUAL SUITE",17)
title.Position=UDim2.fromOffset(16,11)
title.Size=UDim2.new(1,-73,0,26)
title.Font=Enum.Font.GothamBold
local subtitle=text(panel,"Cinematic | texture-safe | no fake SSR / DLSS",11)
subtitle.Position=UDim2.fromOffset(16,36)
subtitle.Size=UDim2.new(1,-80,0,22)
subtitle.TextColor3=Color3.fromRGB(149,158,181)
local close=button(panel,"X")
close.Size=UDim2.fromOffset(33,31)
close.Position=UDim2.new(1,-44,0,14)

local tabs={"LOOKS","SHADOW","WATER","FOG","SYSTEM"}
local tabButtons={}
local tabMembers={}
local currentTab="LOOKS"
local tabBar=Instance.new("Frame")
tabBar.Name="Tabs"
tabBar.Position=UDim2.fromOffset(11,66)
tabBar.Size=UDim2.new(1,-22,0,37)
tabBar.BackgroundTransparency=1
tabBar.Parent=panel
local barLayout=Instance.new("UIListLayout")
barLayout.FillDirection=Enum.FillDirection.Horizontal
barLayout.Padding=UDim.new(0,4)
barLayout.Parent=tabBar
for _,tab in ipairs(tabs) do
    tabMembers[tab]={}
    local b=button(tabBar,tab)
    b.Size=UDim2.new(1/#tabs,-4,0,32)
    b.TextSize=9
    b.LayoutOrder=#tabButtons+1
    table.insert(tabButtons,{name=tab,button=b})
end
local scroll=Instance.new("ScrollingFrame")
scroll.Position=UDim2.fromOffset(13,108)
scroll.Size=UDim2.new(1,-26,1,-188)
scroll.BackgroundTransparency=1
scroll.ScrollBarThickness=4
scroll.ScrollBarImageColor3=Color3.fromRGB(145,124,232)
scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new()
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.Parent=panel
local list=Instance.new("UIListLayout")
list.SortOrder=Enum.SortOrder.LayoutOrder
list.Padding=UDim.new(0,7)
list.Parent=scroll
local pad=Instance.new("UIPadding")
pad.PaddingBottom=UDim.new(0,8)
pad.PaddingRight=UDim.new(0,6)
pad.Parent=scroll

local status=text(panel,"Loading visuals",11)
status.Position=UDim2.new(0,14,1,-74)
status.Size=UDim2.new(1,-28,0,40)
status.TextColor3=Color3.fromRGB(181,190,218)
status.Font=Enum.Font.Code
status.BackgroundColor3=Color3.fromRGB(31,34,51)
status.BackgroundTransparency=0
round(status,7)
local hint=text(panel,qualityHint.." | Set Manual Graphics Quality 10 for renderer detail",10)
hint.Position=UDim2.new(0,14,1,-31)
hint.Size=UDim2.new(1,-28,0,25)
hint.TextColor3=Color3.fromRGB(153,166,193)

local photoExit=button(ui,"EXIT PHOTO MODE  |  F3")
photoExit.AnchorPoint=Vector2.new(.5,1)
photoExit.Position=UDim2.new(.5,0,1,-16)
photoExit.Size=UDim2.fromOffset(195,40)
photoExit.Visible=false
photoExit.BackgroundColor3=Color3.fromRGB(23,26,43)

local order=0
local controls={}
local function tagTab(item: GuiObject, tab: string?)
    local group=tab or currentTab
    table.insert(tabMembers[group],item)
    item.Visible=(group==currentTab)
end
local function nextOrder(): number order+=1;return order end
local function heading(name: string)
    if name=="GRAPHICS PRESET" or name=="TIME / LIGHTING" or name=="TEXTURE-SAFE SURFACE LOOK" then currentTab="LOOKS"
    elseif name=="WEATHER" then currentTab="FOG"
    elseif name=="FEATURES" or name=="TOOLS" then currentTab="SYSTEM"
    elseif name=="FINE TUNING" then currentTab="SHADOW" end
    local item=text(scroll,name,12)
    item.Size=UDim2.new(1,-3,0,26)
    item.Font=Enum.Font.GothamBold
    item.TextColor3=Color3.fromRGB(185,172,255)
    item.LayoutOrder=nextOrder()
    tagTab(item)
end
local function row(height: number): Frame
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,-3,0,height)
    f.BackgroundTransparency=1
    f.LayoutOrder=nextOrder()
    f.Parent=scroll
    tagTab(f)
    local l=Instance.new("UIListLayout")
    l.FillDirection=Enum.FillDirection.Horizontal
    l.Padding=UDim.new(0,5)
    l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Parent=f
    return f
end
local function requestSave()
    -- This remote-load build intentionally does not persist settings.
    userEdited = true
end
local function change(group: string, key: any, value: any?)
    graphics:Update(group,key,value)
    requestSave()
end
local function options(titleText: string, names: {string}, group: string, count: number)
    heading(titleText)
    local i=1
    while i<=#names do
        local r=row(34)
        local size=math.min(count,#names-i+1)
        for j=1,size do
            local name=names[i]
            i+=1
            local b=button(r,name)
            b.Size=UDim2.new(1/size,-5,1,0)
            b.LayoutOrder=j
            table.insert(controls,{type="option",button=b,group=group,key=name})
            b.Activated:Connect(function() change(group,name) end)
        end
    end
end
options("GRAPHICS PRESET",{"Cinematic","Max","High Ultra","Ultra","Balanced","Off"},"preset",3)
options("TIME / LIGHTING",Config.TimeOrder,"mode",3)
options("WEATHER",Config.WeatherOrder,"weather",3)
options("TEXTURE-SAFE SURFACE LOOK",Config.FinishOrder,"finish",2)
heading("FEATURES")
for i=1,#Config.FeatureOrder,2 do
    local r=row(35)
    for j=0,1 do
        local name=Config.FeatureOrder[i+j]
        if name then
            local b=button(r,name)
            b.Size=UDim2.new(.5,-5,1,0)
            b.LayoutOrder=j+1
            table.insert(controls,{type="feature",button=b,key=name})
            b.Activated:Connect(function()
                local state=graphics:GetState()
                change("features",name,not state.features[name])
            end)
        end
    end
end


-- UltraVisualSuite v6: Part 13/14
-- This is a continuation, not independently executable.

heading("FINE TUNING")
for _,name in ipairs(Config.SliderOrder) do
    local box=Instance.new("Frame")
    box.Size=UDim2.new(1,-3,0,49)
    box.BackgroundTransparency=1
    box.LayoutOrder=nextOrder()
    box.Parent=scroll
    local target="LOOKS"
    if name=="ShadowStrength" or name=="ShadowSoftness" or name=="ShadowLift" or name=="Ambient" then target="SHADOW"
    elseif name=="WaterReflection" or name=="WaterClarity" or name=="WaterDepth" or name=="WaterWaves" then target="WATER"
    elseif name=="Density" or name=="Haze" or name=="FogDistance" or name=="SunRays" then target="FOG"
    elseif name=="BatchPace" then target="SYSTEM" end
    tagTab(box,target)
    local label=text(box,name,11)
    label.Size=UDim2.new(1,0,0,20)
    local bar=Instance.new("Frame")
    bar.Size=UDim2.new(1,-12,0,9)
    bar.Position=UDim2.fromOffset(6,30)
    bar.BackgroundColor3=Color3.fromRGB(51,55,75)
    bar.Active=true
    bar.Parent=box
    round(bar,5)
    local fill=Instance.new("Frame")
    fill.Size=UDim2.fromScale(.5,1)
    fill.BackgroundColor3=Color3.fromRGB(150,118,249)
    fill.BorderSizePixel=0
    fill.Parent=bar
    round(fill,5)
    local hit=Instance.new("TextButton")
    hit.Size=UDim2.new(1,0,0,27)
    hit.Position=UDim2.fromOffset(0,-9)
    hit.BackgroundTransparency=1
    hit.Text=""
    hit.Parent=bar
    local function update(x: number)
        local width=math.max(1,bar.AbsoluteSize.X)
        local value=math.clamp((x-bar.AbsolutePosition.X)/width,0,1)
        change("sliders",name,math.floor(value*100+.5)/100)
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            activeDrag={name=name,input=input,update=update}
            update(input.Position.X)
        end
    end)
    table.insert(controls,{type="slider",key=name,fill=fill,label=label})
end

heading("TOOLS")
local adaptive=button(scroll,"Adaptive: ON")
adaptive.LayoutOrder=nextOrder()
tagTab(adaptive)
table.insert(controls,{type="adaptive",button=adaptive})
adaptive.Activated:Connect(function()
    change("adaptive",not graphics:GetState().adaptive)
end)
local testButton=button(scroll,"VISUAL TEST  |  3 SECOND PINK FILTER")
testButton.LayoutOrder=nextOrder()
tagTab(testButton)
testButton.BackgroundColor3=Color3.fromRGB(85,55,113)
testButton.Activated:Connect(function() graphics:VisualTest() end)
local compare=button(scroll,"BEFORE / AFTER  (hold via toggle)")
compare.LayoutOrder=nextOrder()
tagTab(compare)
compare.Activated:Connect(function()
    graphics:Compare(not graphics:Metrics().comparing)
end)
local picture=button(scroll,"PHOTO MODE")
picture.LayoutOrder=nextOrder()
tagTab(picture)
local reset=button(scroll,"RESET TO DEFAULTS")
reset.LayoutOrder=nextOrder()
tagTab(reset)
reset.BackgroundColor3=Color3.fromRGB(72,42,63)
reset.Activated:Connect(function()
    graphics:Reset()
    requestSave()
end)


-- UltraVisualSuite v6: Part 14/14
-- This is a continuation, not independently executable.

local function setPhoto(value: boolean)
    photo=value
    graphics:Photo(value)
    if photo then
        open=false
        graphics:MenuBlur(false)
        panel.Visible=false
        launcher.Visible=false
        photoExit.Visible=true
    else
        launcher.Visible=true
        photoExit.Visible=false
    end
end
picture.Activated:Connect(function() setPhoto(true) end)
photoExit.Activated:Connect(function() setPhoto(false) end)

local animation: Tween?=nil
local function setOpen(value: boolean)
    if photo then setPhoto(false) end
    open=value
    graphics:MenuBlur(value)
    if animation then animation:Cancel();animation:Destroy();animation=nil end
    if value then panel.Visible=true end
    local target=if value then 1 else .92
    animation=TweenService:Create(scale,TweenInfo.new(.17,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=target})
    animation:Play()
    if not value then
        local current=animation
        task.delay(.19,function()
            if animation==current and not open then panel.Visible=false end
        end)
    end
end
launcher.Activated:Connect(function() setOpen(not open) end)
close.Activated:Connect(function() setOpen(false) end)

local function showTab(group: string)
    currentTab=group
    for tab,items in pairs(tabMembers) do
        for _,item in ipairs(items) do item.Visible=(tab==group) end
    end
    for _,entry in ipairs(tabButtons) do
        entry.button.BackgroundColor3=if entry.name==group then Color3.fromRGB(103,80,191)
            else Color3.fromRGB(38,41,58)
    end
    scroll.CanvasPosition=Vector2.new(0,0)
end
for _,entry in ipairs(tabButtons) do
    entry.button.Activated:Connect(function() showTab(entry.name) end)
end
showTab("LOOKS")
local function render()
    if disposed then return end
    local state=graphics:GetState()
    local metric=graphics:Metrics()
    for _, entry in ipairs(controls) do
        if entry.type=="option" or entry.type=="feature" then
            local selected=if entry.type=="option" then state[entry.group]==entry.key else state.features[entry.key]
            entry.button.BackgroundColor3=if selected then Color3.fromRGB(103,79,192) else Color3.fromRGB(38,41,58)
            entry.button.TextColor3=if selected then Color3.new(1,1,1) else Color3.fromRGB(220,225,239)
        elseif entry.type=="slider" then
            local value=state.sliders[entry.key]
            entry.fill.Size=UDim2.fromScale(value,1)
            entry.label.Text=string.format("%s   %d%%",entry.key,math.floor(value*100+.5))
        elseif entry.type=="adaptive" then
            entry.button.Text="Adaptive performance: "..(if state.adaptive then "ON" else "OFF")
            entry.button.BackgroundColor3=if state.adaptive then Color3.fromRGB(93,75,168) else Color3.fromRGB(38,41,58)
        end
    end
    compare.Text=if metric.comparing then "AFTER  |  Restore enhanced visuals" else "BEFORE  |  Compare original visuals"
    status.Text=string.format("FPS %d | %s > %s | FX %d | Parts %d | Stage %s %d\nCamera %s | Time %.1f | Exposure %.2f",metric.fps,metric.preset,
        metric.effective,metric.effects,metric.parts,(if metric.scanBusy then "SCANNING" else "READY"),metric.scanCount,
        (if metric.cameraEffect then "OK" else "OFF"),metric.clock,metric.exposure)
end

table.insert(connections,graphics.changed.Event:Connect(render))
table.insert(connections,UIS.InputChanged:Connect(function(input)
    if not activeDrag then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement or
        (input.UserInputType==Enum.UserInputType.Touch and input==activeDrag.input) then
        activeDrag.update(input.Position.X)
    end
end))
table.insert(connections,UIS.InputEnded:Connect(function(input)
    if activeDrag and (input==activeDrag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then
        activeDrag=nil
    end
end))
table.insert(connections,UIS.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.F3 or input.KeyCode==Enum.KeyCode.ButtonStart then
        if photo then setPhoto(false) else setOpen(not open) end
    elseif input.KeyCode==Enum.KeyCode.ButtonB and open then
        setOpen(false)
    end
end))

local viewportConn: RBXScriptConnection?=nil
local function viewport()
    local camera=Workspace.CurrentCamera
    if not camera then return end
    local size=camera.ViewportSize
    scale.Scale=math.clamp(math.min(size.X/425,size.Y/630),.64,1)
end
local function cameraChanged()
    if viewportConn then viewportConn:Disconnect(); viewportConn=nil end
    if Workspace.CurrentCamera then
        viewportConn=Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(viewport)
        viewport()
    end
end
table.insert(connections,Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged))
cameraChanged()

local shutdown=Instance.new("BindableFunction")
shutdown.Name="UVS_Shutdown"
shutdown.Parent=playerGui
local function cleanup()
    if disposed then return end
    disposed=true
    if viewportConn then viewportConn:Disconnect() end
    for _,connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    graphics:Destroy()
    ui:Destroy()
    shutdown:Destroy()
end
shutdown.OnInvoke=cleanup
render()
-- The UVS_Shutdown BindableFunction handles re-execution cleanup.
print("[UVS v6] Loaded | preset:",graphics:GetState().preset,"mode:",graphics:GetState().mode,"finish:",graphics:GetState().finish)
print("[UVS v6] F3 / VISUALS. All finishes preserve texture maps; real SSR is unavailable.")

end
