--!strict
--[[
    VELION DISTRICT HUB V5.3 - CAMERA STATUS DIAGNOSTICS
    For Roblox Violence District - client-side utility module.
    Native Roblox UI; no external interface library.
    IMPORTANT: Does not spoof server state or grant server-side immunity.
    Existing observational features remain unverified; no game security bypass.
    Manual skill-check and movement practice only.
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
    fullbright=false, lightIntensity=100, noFog=false, noClip=false,
    speed=false, speedValue=24, fov=70,
    customFov=false, fovMode="Preserve Dynamic", fovSmooth=0.18,
    smoothCamera=false, cameraTurnTime=0.08,
    smoothZoom=false, cameraZoomTime=0.18,
    moonwalk=false, moonwalkSteer=.28,
    moonwalkStatus="OFF | assign a shortcut in Settings",
    killerAlert=false, offscreenESP=false, hidden=false, scanProgress="Disabled",
    expanded=true, activeTab="Home", sceneBlur=false,
    killerESP=false, survivorESP=false, unknownESP=false,
    survivorItemsESP=false, worldItemsESP=false,
    abilityNotify=false, roleTracking=false,
    playerNames=false, playerDistance=false,
    playerMask=false, chaseStatus=false, knockedStatus=false, hookedStatus=false,
    playerHighlight=false, objectHighlight=false, highlightMode="Outline", nextKiller=false, skillMonitor=false,
    autoSkillCheck=false, inputStatus="No action attempted",
    generatorESP=false, palletESP=false, windowESP=false, hookESP=false,
    gateESP=false, generatorProgressESP=false, espDistance=650,
    identifiedObjectives=0, unknownRoles=0,
    progressScale="Auto", progressUnknown=0,
    worldItemsFound=0, scanMapCount=0, scanInteractableCount=0,
    abilityStatus="Waiting for replicated ability signals",
    abilityLast="No verified activation",
    abilitySignalsObserved=0, abilityNotificationCount=0,
    lastRoleTransition="None detected",
    roleTransitions=0, trackedPlayers=0,
    maxWorldLabels=22, maxWorldHighlights=20, objectLabels=false,
    scanCandidates=0, scanScanned=0, scanDurationMs=0,
    visibleLabels=0, visibleHighlights=0, fps=60,
    highlightBudgetAvailable=20,
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
-- Local UI diagnostics only: no game security interception or global hooks.
local runtimeLog=(function()
    local log={entries={},total=0,started=os.clock(),lastUpdate=0}
    function log.record(source,err)
        log.total+=1
        local message=tostring(err):sub(1,240)
        local last=log.entries[#log.entries]
        if last and last.source==source and last.message==message then
            last.count+=1
            last.time=os.clock()
        else
            log.entries[#log.entries+1]={source=source,message=message,count=1,time=os.clock()}
        end
        if #log.entries>32 then table.remove(log.entries,1) end
    end
    function log.clear()
        table.clear(log.entries)
        log.total=0
    end
    function log.snapshot()
        local lines={}
        for i=math.max(1,#log.entries-3),#log.entries do
            local item=log.entries[i]
            lines[#lines+1]=string.format("+%.1fs | %s x%d: %s",item.time-log.started,item.source,item.count,item.message)
        end
        return #lines==0 and "No local UI errors recorded." or table.concat(lines,"\n")
    end
    return log
end)()
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

local espColors={
    Killer=Color3.fromRGB(255,80,91),
    Survivor=Color3.fromRGB(78,173,252),
    Generator=Color3.fromRGB(194,108,255),
    Pallet=Color3.fromRGB(255,196,86),
    Window=Color3.fromRGB(95,233,223),
    Hook=Color3.fromRGB(248,122,170),
    Gate=Color3.fromRGB(122,244,165),
    Chased=Color3.fromRGB(255,155,80),
    Knocked=Color3.fromRGB(244,199,78),
    Hooked=Color3.fromRGB(255,134,195),
    Unknown=Color3.fromRGB(184,180,205),
    Item=Color3.fromRGB(246,213,104),
}
local function highlightStyle(h: Highlight,color: Color3)
    h.FillColor=color
    h.OutlineColor=color
    h.FillTransparency=(state.highlightMode=="Outline") and 1 or .79
    h.OutlineTransparency=(state.highlightMode=="Fill") and 1 or 0
end
local function categoryName(key: string): string
    if key=="palletwrong" or key=="pallet" then return "Pallet" end
    if key=="generator" then return "Generator" end
    if key=="window" then return "Window" end
    if key=="hook" then return "Hook" end
    if key=="gate" then return "Gate" end
    if key=="item" then return "Item" end
    return "Unknown"
end
local function categoryColor(key: string): Color3
    return espColors[categoryName(key)] or espColors.Unknown
end

-- Native window is the only menu. This ScreenGui contains ESP overlays
-- only, so no hidden large Frame can block mouse/touch interactions.
local existingOverlay=playerGui:FindFirstChild("VelionDistrictOverlayV4")
if existingOverlay then existingOverlay:Destroy() end
local gui=create("ScreenGui",playerGui,{
    Name="VelionDistrictOverlayV4",ResetOnSpawn=false,
    IgnoreGuiInset=true,DisplayOrder=950,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling
})
local alert=create("TextLabel",gui,{
    Name="KillerWarning",Text="",Visible=false,
    AnchorPoint=Vector2.new(.5,0),
    Position=UDim2.new(.5,0,0,12),
    Size=UDim2.new(.92,0,0,43),
    TextColor3=espColors.Killer,TextSize=14,
    Font=Enum.Font.GothamBold,
    BackgroundColor3=Color3.fromRGB(26,28,33),
    BackgroundTransparency=.15,BorderSizePixel=0,
    TextStrokeTransparency=.6
})
round(alert,12)
create("UISizeConstraint",alert,{
    MinSize=Vector2.new(220,43),MaxSize=Vector2.new(410,43)
})
create("UIStroke",alert,{
    Color=espColors.Killer,Thickness=1,Transparency=.35
})

-- XandMe Native UI: opaque grayscale surfaces, native Roblox widgets.
-- No external loader, library theme, or global input hooks.
local Native,Window=(function()
    local ui={Options={}}
    local animationDuration=.14
    local activeUITweens={}
    local rowOrder={}
    local function nextRowOrder(container)
        rowOrder[container]=(rowOrder[container] or 0)+1
        return rowOrder[container]
    end
    local C={
        black=Color3.fromRGB(7,7,7),sidebar=Color3.fromRGB(12,12,12),
        row=Color3.fromRGB(21,21,21),button=Color3.fromRGB(32,32,32),
        border=Color3.fromRGB(49,49,49),text=Color3.fromRGB(245,245,245),
        muted=Color3.fromRGB(165,165,165),white=Color3.fromRGB(255,255,255),
    }
    local screen=create("ScreenGui",playerGui,{
        Name="VelionDistrictHubV2",ResetOnSpawn=false,IgnoreGuiInset=false,
        DisplayOrder=949,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    })
    local function stroke(item)
        create("UIStroke",item,{Color=C.border,Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    end
    local function text(parent,caption,size,medium,color)
        return create("TextLabel",parent,{
            BackgroundTransparency=1,Text=caption,TextColor3=color or C.text,
            TextSize=size,Font=medium and Enum.Font.BuilderSansMedium or Enum.Font.BuilderSans,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
            TextWrapped=true,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y
        })
    end
    local function btn(parent,caption,width,height)
        local b=create("TextButton",parent,{
            Text=caption,TextSize=12,Font=Enum.Font.BuilderSansMedium,TextColor3=C.text,
            BackgroundColor3=C.button,BackgroundTransparency=0,AutoButtonColor=true,
            BorderSizePixel=0,Size=UDim2.fromOffset(width,height)
        })
        round(b,6);stroke(b)
        return b
    end
    local function list(parent,padding,direction)
        return create("UIListLayout",parent,{
            FillDirection=direction or Enum.FillDirection.Vertical,
            SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,padding)
        })
    end
    local function pad(parent,n)
        create("UIPadding",parent,{
            PaddingTop=UDim.new(0,n),PaddingBottom=UDim.new(0,n),
            PaddingLeft=UDim.new(0,n),PaddingRight=UDim.new(0,n)
        })
    end
    local function safe(name,fn,...)
        if not fn then return end
        local ok,err=pcall(fn,...)
        if not ok then
            runtimeLog.record("native UI / "..name,err)
            warn("[XandMe UI] "..name..": "..tostring(err))
        end
        return ok
    end
    local function bindClick(b,name,fn)
        connect(b.Activated,function()
            if state.alive then safe(name,fn) end
        end)
    end
    local root=create("Frame",screen,{
        Name="XandMeWindow",AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.94,.88),
        BackgroundColor3=C.black,BackgroundTransparency=0,BorderSizePixel=0,
        ClipsDescendants=true,Visible=true
    })
    round(root,12);stroke(root)
    create("UISizeConstraint",root,{MaxSize=Vector2.new(810,570)})
    local header=create("Frame",root,{Size=UDim2.new(1,0,0,62),BackgroundColor3=C.black,BorderSizePixel=0,Active=true})
    local brand=text(header,"XandMe.",26,true)
    brand.Position=UDim2.fromOffset(16,7);brand.Size=UDim2.new(1,-120,0,30);brand.AutomaticSize=Enum.AutomaticSize.None
    local subtitle=text(header,"VELION DISTRICT  /  NATIVE V5.3",10,false,C.muted)
    subtitle.Position=UDim2.fromOffset(17,38);subtitle.Size=UDim2.new(1,-120,0,15);subtitle.AutomaticSize=Enum.AutomaticSize.None
    local close=btn(header,"−",34,30)
    close.AnchorPoint=Vector2.new(1,.5);close.Position=UDim2.new(1,-12,.5,0)
    create("Frame",root,{Position=UDim2.fromOffset(0,62),Size=UDim2.new(1,0,0,1),BackgroundColor3=C.border,BorderSizePixel=0})
    local sidebar=create("ScrollingFrame",root,{
        Name="Navigation",Position=UDim2.fromOffset(0,63),Size=UDim2.new(.24,0,1,-63),
        BackgroundColor3=C.sidebar,BackgroundTransparency=0,BorderSizePixel=0,
        ScrollBarThickness=2,ScrollBarImageColor3=C.border,CanvasSize=UDim2.new(),
        AutomaticCanvasSize=Enum.AutomaticSize.Y
    })
    pad(sidebar,8);list(sidebar,5)
    local navTitle=text(sidebar,"WORKSPACE",10,true,C.muted);navTitle.LayoutOrder=0
    local content=create("Frame",root,{
        Position=UDim2.new(.24,0,0,63),Size=UDim2.new(.76,0,1,-63),
        BackgroundColor3=C.black,BackgroundTransparency=0,BorderSizePixel=0
    })
    local window={Root=root,Minimized=false,Tabs={}}
    function window:Minimize()
        self.Minimized=not self.Minimized
        root.Visible=not self.Minimized
    end
    bindClick(close,"close",function() window:Minimize() end)
    connect(UserInputService.InputBegan,function(input)
        if state.alive and input.KeyCode==Enum.KeyCode.RightControl and not UserInputService:GetFocusedTextBox() then
            window:Minimize()
        end
    end)
    local Methods={}
    local drag=nil
    local windowDrag=nil
    local searchRows={}
    local searchBox=nil
    local function clampWindowPosition(point)
        local vp=screen.AbsoluteSize
        local half=root.AbsoluteSize/2
        if vp.X<=0 or vp.Y<=0 then return end
        local x=math.clamp(point.X,math.min(half.X,vp.X/2),math.max(vp.X-half.X,vp.X/2))
        local y=math.clamp(point.Y,math.min(half.Y,vp.Y/2),math.max(vp.Y-half.Y,vp.Y/2))
        root.Position=UDim2.fromOffset(x,y)
    end
    function window:ResetPosition()
        windowDrag=nil;root.Position=UDim2.fromScale(.5,.5)
    end
    connect(screen:GetPropertyChangedSignal("AbsoluteSize"),function() window:ResetPosition() end)
    connect(root:GetPropertyChangedSignal("Visible"),function() if not root.Visible then windowDrag=nil;drag=nil end end)
    connect(header.InputBegan,function(input)
        if not state.alive or not root.Visible or windowDrag then return end
        if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
        local closePos,closeSize=close.AbsolutePosition,close.AbsoluteSize
        if input.Position.X>=closePos.X and input.Position.X<=closePos.X+closeSize.X and input.Position.Y>=closePos.Y and input.Position.Y<=closePos.Y+closeSize.Y then return end
        windowDrag={input=input,start=Vector2.new(input.Position.X,input.Position.Y),center=root.AbsolutePosition-screen.AbsolutePosition+root.AbsoluteSize/2}
    end)
    connect(UserInputService.InputChanged,function(input)
        if not state.alive then return end
        if windowDrag then
            local held=windowDrag.input
            if input==held or (held.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then
                local point=Vector2.new(input.Position.X,input.Position.Y)
                clampWindowPosition(windowDrag.center+point-windowDrag.start)
            end
        end
        if not drag then return end
        if input==drag.input or (drag.input.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement) then
            drag.update(input.Position.X)
        end
    end)
    connect(UserInputService.InputEnded,function(input)
        if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil end
        if windowDrag and (input==windowDrag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then windowDrag=nil end
    end)
    local function applySettingsSearch()
        if not searchBox then return end
        local query=searchBox.Text:lower():match("^%s*(.-)%s*$") or ""
        for _,entry in ipairs(searchRows) do
            entry.frame.Visible=query=="" or string.find(entry.title:lower(),query,1,true)~=nil
        end
    end
    local function newRow(container,title,desc,rightWidth)
        local frame=create("Frame",container,{
            LayoutOrder=nextRowOrder(container),BackgroundColor3=C.row,BackgroundTransparency=0,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y
        })
        round(frame,8);stroke(frame);pad(frame,10)
        create("UISizeConstraint",frame,{MinSize=Vector2.new(0,54)})
        list(frame,8)
        local top=create("Frame",frame,{LayoutOrder=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
        create("UISizeConstraint",top,{MinSize=Vector2.new(0,34)})
        local left=create("Frame",top,{
            BackgroundTransparency=1,Size=UDim2.new(1,-rightWidth,0,0),
            AutomaticSize=Enum.AutomaticSize.Y
        })
        list(left,4)
        local heading=text(left,title,13,true);heading.LayoutOrder=1
        local detail=text(left,desc or "",11,false,C.muted);detail.LayoutOrder=2;detail.Visible=detail.Text~=""
        local result={Frame=frame}
        if container.Name=="Settings" then
            searchRows[#searchRows+1]={frame=frame,title=title.." "..(desc or "")}
            applySettingsSearch()
        end
        function result:SetDesc(value)
            detail.Text=tostring(value or "")
            detail.Visible=detail.Text~=""
        end
        function result:SetTitle(value) heading.Text=tostring(value) end
        if rightWidth>0 then
            local actions=create("Frame",top,{
                AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,0,.5,0),
                Size=UDim2.fromOffset(rightWidth-6,34),BackgroundTransparency=1
            })
            local layout=list(actions,5,Enum.FillDirection.Horizontal)
            layout.HorizontalAlignment=Enum.HorizontalAlignment.Right
            layout.VerticalAlignment=Enum.VerticalAlignment.Center
            result.Actions=actions
        end
        return result
    end
    function Methods:AddParagraph(cfg)
        return newRow(self.Container,cfg.Title,cfg.Content,0)
    end
    function Methods:AddButton(cfg)
        local obj=newRow(self.Container,cfg.Title,cfg.Description,88)
        local b=btn(obj.Actions,cfg.ButtonText or "OPEN",74,30)
        bindClick(b,cfg.Title,cfg.Callback)
        return obj
    end
    function Methods:AddSection(title)
        local heading=text(self.Container,title,15,true)
        heading.LayoutOrder=nextRowOrder(self.Container)
        heading.Size=UDim2.new(1,0,0,26);heading.AutomaticSize=Enum.AutomaticSize.None
        return setmetatable({Container=self.Container},{__index=Methods})
    end
    function Methods:AddToggle(id,cfg)
        local obj=newRow(self.Container,cfg.Title,cfg.Description,150)
        obj.Value=cfg.Default==true;obj.Type="Toggle"
        local key=btn(obj.Actions,"Unbound",67,30);key.LayoutOrder=1
        local toggle=btn(obj.Actions,"OFF",43,30);toggle.LayoutOrder=3
        function obj:SetBindText(value) key.Text=value or "Unbound" end
        function obj:SetBindCallback(fn) self._bind=fn end
        bindClick(key,id.." shortcut",function() if obj._bind then obj._bind() end end)
        local toggleTween=nil
        local function paint(animate)
            toggle.Text=obj.Value and "ON" or "OFF"
            local goal={BackgroundColor3=obj.Value and C.white or C.button,TextColor3=obj.Value and C.black or C.muted}
            if toggleTween then activeUITweens[toggleTween]=nil;toggleTween:Cancel();toggleTween=nil end
            if animate then
                toggleTween=TweenService:Create(toggle,TweenInfo.new(animationDuration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal)
                activeUITweens[toggleTween]=true;toggleTween:Play()
            else
                toggle.BackgroundColor3=goal.BackgroundColor3;toggle.TextColor3=goal.TextColor3
            end
        end
        function obj:SetValue(value)
            self.Value=value==true;paint(true);safe(id,cfg.Callback,self.Value)
        end
        bindClick(toggle,id,function() obj:SetValue(not obj.Value) end)
        paint();ui.Options[id]=obj;self.lastToggle=obj
        return obj
    end
    function Methods:AddSlider(id,cfg)
        local row=newRow(self.Container,cfg.Title,cfg.Description,65)
        local valueText=text(row.Actions,"",12,true)
        valueText.AutomaticSize=Enum.AutomaticSize.None;valueText.Size=UDim2.fromOffset(54,26)
        valueText.TextXAlignment=Enum.TextXAlignment.Right
        local railFrame=create("Frame",row.Frame,{
            LayoutOrder=2,BackgroundColor3=C.row,BackgroundTransparency=0,BorderSizePixel=0,
            Size=UDim2.new(1,0,0,31)
        })
        round(railFrame,6)
        local rail=create("Frame",railFrame,{
            Position=UDim2.new(0,12,.5,-4),Size=UDim2.new(1,-24,0,8),
            BackgroundColor3=C.border,BorderSizePixel=0,Active=true
        })
        round(rail,4)
        local fill=create("Frame",rail,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.white,BorderSizePixel=0})
        round(fill,4)
        local knob=create("Frame",rail,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(15,15),BackgroundColor3=C.white,BorderSizePixel=0})
        round(knob,8)
        local obj={Type="Slider",Value=cfg.Default}
        local min,max,precision=cfg.Min,cfg.Max,math.clamp(cfg.Rounding or 0,0,3)
        local function normalize(v)
            local number=tonumber(v)
            if not number or number~=number or math.abs(number)==math.huge then return obj.Value end
            local factor=10^precision
            return math.clamp(math.floor(number*factor+.5)/factor,min,max)
        end
        local function paint()
            local t=(obj.Value-min)/math.max(.00001,max-min)
            fill.Size=UDim2.fromScale(t,1);knob.Position=UDim2.fromScale(t,.5)
            valueText.Text=string.format("%."..precision.."f",obj.Value)
        end
        function obj:SetValue(v)
            self.Value=normalize(v);paint();safe(id,cfg.Callback,self.Value)
        end
        local function move(x)
            if rail.AbsoluteSize.X<=0 then return end
            obj:SetValue(min+math.clamp((x-rail.AbsolutePosition.X)/rail.AbsoluteSize.X,0,1)*(max-min))
        end
        connect(rail.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
                drag={input=input,update=move};move(input.Position.X)
            end
        end)
        obj.Value=normalize(cfg.Default);paint();ui.Options[id]=obj
        return obj
    end
    function Methods:AddDropdown(id,cfg)
        local row=newRow(self.Container,cfg.Title,cfg.Description,116)
        local b=btn(row.Actions,"",104,30)
        local panel=create("Frame",row.Frame,{
            LayoutOrder=2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=C.button,BorderSizePixel=0,Visible=false
        })
        round(panel,7);pad(panel,8);list(panel,4)
        local obj={Type="Dropdown",Value=type(cfg.Default)=="number" and cfg.Values[cfg.Default] or cfg.Default}
        if not table.find(cfg.Values,obj.Value) then obj.Value=cfg.Values[1] end
        function obj:SetValue(v)
            if not table.find(cfg.Values,v) then return end
            self.Value=v;b.Text=tostring(v);panel.Visible=false;safe(id,cfg.Callback,v)
        end
        for _,value in ipairs(cfg.Values) do
            local v=value
            local option=btn(panel,tostring(v),100,30);option.Size=UDim2.new(1,0,0,30)
            bindClick(option,id,function() obj:SetValue(v) end)
        end
        b.Text=tostring(obj.Value)
        bindClick(b,id,function() panel.Visible=not panel.Visible end)
        ui.Options[id]=obj;return obj
    end
    function Methods:AddColorpicker(id,cfg)
        local parentRow=self.lastToggle
        local row=parentRow and parentRow.Actions and parentRow or newRow(self.Container,cfg.Title,cfg.Description,54)
        local swatch=btn(row.Actions,"",22,24);swatch.LayoutOrder=2;swatch.AutoButtonColor=false
        local panel=create("Frame",row.Frame,{
            LayoutOrder=2,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=C.button,BorderSizePixel=0,Visible=false
        })
        round(panel,7);pad(panel,9);list(panel,6)
        text(panel,cfg.Title.." / color",12,true)
        local chips=create("Frame",panel,{Size=UDim2.new(1,0,0,29),BackgroundTransparency=1})
        list(chips,5,Enum.FillDirection.Horizontal)
        local hex=create("TextBox",panel,{
            Size=UDim2.new(1,0,0,30),BackgroundColor3=C.button,TextColor3=C.text,
            Font=Enum.Font.BuilderSans,TextSize=12,ClearTextOnFocus=false,
            PlaceholderText="#RRGGBB",Text="",BorderSizePixel=0
        })
        round(hex,5)
        local feedback=text(panel,"Enter six hexadecimal digits, e.g. #FFFFFF.",11,false,C.muted)
        local reset=btn(panel,"Reset color",92,28);reset.Size=UDim2.new(1,0,0,28)
        local obj={Type="Colorpicker",Value=cfg.Default}
        local function hexString(c)
            return string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))
        end
        function obj:SetValue(v)
            if typeof(v)=="string" then
                local raw=v:match("^%s*(.-)%s*$"):gsub("^#","")
                if not raw:match("^%x%x%x%x%x%x$") then
                    hex.Text=hexString(self.Value);feedback.Text="Invalid HEX. Previous color retained.";return
                end
                v=Color3.fromRGB(tonumber(raw:sub(1,2),16),tonumber(raw:sub(3,4),16),tonumber(raw:sub(5,6),16))
            end
            if typeof(v)~="Color3" then return end
            self.Value=v;swatch.BackgroundColor3=v;hex.Text=hexString(v)
            local ok=safe(id,cfg.Callback,v)
            feedback.Text=ok==false and "Color callback error. See Diagnostics." or "Selected: "..hexString(v)
        end
        for _,v in ipairs({cfg.Default,Color3.fromRGB(255,80,91),Color3.fromRGB(78,173,252),Color3.fromRGB(112,222,154),Color3.fromRGB(244,203,85),Color3.fromRGB(190,128,255),C.white}) do
            local color=v;local chip=btn(chips,"",23,25);chip.BackgroundColor3=color
            bindClick(chip,id,function() obj:SetValue(color) end)
        end
        connect(hex.FocusLost,function() obj:SetValue(hex.Text) end)
        bindClick(reset,id.." reset color",function() obj:SetValue(cfg.Default) end)
        swatch.BackgroundColor3=cfg.Default;hex.Text=hexString(cfg.Default)
        bindClick(swatch,id,function() panel.Visible=not panel.Visible end)
        ui.Options[id]=obj;return obj
    end
    function window:AddTab(cfg)
        local index=#self.Tabs+1
        local nav=btn(sidebar,cfg.Title,100,35)
        nav.Size=UDim2.new(1,0,0,35);nav.LayoutOrder=index
        nav.TextSize=11;nav.TextWrapped=true
        local page=create("ScrollingFrame",content,{
            Name=cfg.Title,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
            BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
            ScrollBarThickness=3,ScrollBarImageColor3=C.muted,Visible=false
        })
        pad(page,11);list(page,8)
        local heading=text(page,cfg.Title,23,true);heading.LayoutOrder=nextRowOrder(page);heading.Size=UDim2.new(1,0,0,36);heading.AutomaticSize=Enum.AutomaticSize.None
        if cfg.Title=="Settings" then
            searchBox=create("TextBox",page,{
                Name="SettingsSearch",Size=UDim2.new(1,0,0,34),BackgroundColor3=C.row,BackgroundTransparency=0,
                Text="",PlaceholderText="Search settings...",PlaceholderColor3=C.muted,TextColor3=C.text,
                Font=Enum.Font.BuilderSans,TextSize=14,ClearTextOnFocus=false,BorderSizePixel=0
            })
            searchBox.LayoutOrder=nextRowOrder(page)
            round(searchBox,7);stroke(searchBox)
            connect(searchBox:GetPropertyChangedSignal("Text"),applySettingsSearch)
        end
        local tab=setmetatable({Container=page,Nav=nav},{__index=Methods})
        self.Tabs[index]=tab
        bindClick(nav,"navigation",function() window:SelectTab(index) end)
        return tab
    end
    function window:SelectTab(index)
        for i,tab in ipairs(self.Tabs) do
            local active=i==index
            tab.Container.Visible=active
            tab.Nav.BackgroundColor3=active and C.white or C.sidebar
            tab.Nav.TextColor3=active and C.black or C.muted
        end
    end
    local notice=nil
    local noticeTween=nil
    function ui:Notify(cfg)
        if not state.alive then return end
        if noticeTween then noticeTween:Cancel();noticeTween=nil end
        if notice then notice:Destroy() end
        local toast=create("CanvasGroup",screen,{
            Name="XandMeToast",GroupTransparency=1,
            AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-12,1,-12),
            Size=UDim2.new(.85,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,
            BackgroundColor3=C.black,BorderSizePixel=0
        })
        notice=toast;round(toast,8);stroke(toast);pad(toast,12);list(toast,5)
        create("UISizeConstraint",toast,{MaxSize=Vector2.new(340,1000)})
        text(toast,cfg.Title or "XandMe",13,true)
        text(toast,cfg.Content or "",11,false,C.muted)
        noticeTween=TweenService:Create(toast,TweenInfo.new(animationDuration),{GroupTransparency=0});noticeTween:Play()
        task.delay(cfg.Duration or 3,function()
            if not state.alive or notice~=toast or not toast.Parent then return end
            if noticeTween then noticeTween:Cancel() end
            noticeTween=TweenService:Create(toast,TweenInfo.new(animationDuration),{GroupTransparency=1});noticeTween:Play()
            task.delay(animationDuration,function()
                if notice==toast then notice=nil;noticeTween=nil end
                if toast.Parent then toast:Destroy() end
            end)
        end)
    end
    function ui:Destroy()
        drag=nil;windowDrag=nil
        if noticeTween then noticeTween:Cancel();noticeTween=nil end
        for tween in pairs(activeUITweens) do pcall(function() tween:Cancel() end) end
        table.clear(activeUITweens);table.clear(rowOrder);table.clear(searchRows);screen:Destroy()
    end
    return ui,window
end)()
local Tabs={
    Main=Window:AddTab({Title="Dashboard",Icon="layout-dashboard"}),
    Players=Window:AddTab({Title="Player ESP",Icon="users"}),
    Objects=Window:AddTab({Title="Object ESP",Icon="scan"}),
    Survivor=Window:AddTab({Title="Survivor",Icon="shield"}),
    Killer=Window:AddTab({Title="Killer",Icon="skull"}),
    Movement=Window:AddTab({Title="Movement",Icon="footprints"}),
    Visual=Window:AddTab({Title="Visual",Icon="eye"}),
    Settings=Window:AddTab({Title="Settings",Icon="settings"})
}
local Options=Native.Options
local controls={}
local toggles={}
local toggleTitles={}
local toggleOrder={}
local toggleStateKeys={}
local function registerToggle(tab:any,id:string,title:string,description:string,
    stateKey:string,onValue:((boolean)->())?)
    local obj=tab:AddToggle(id,{
        Title=title,Description=description,
        Default=state[stateKey]==true,
        Callback=function(value)
            state[stateKey]=value
            if onValue then onValue(value) end
        end
    })
    toggles[id]=obj
    toggleTitles[id]=title
    toggleStateKeys[id]=stateKey
    toggleOrder[#toggleOrder+1]=id
    return obj
end
local function registerColor(tab:any,id:string,label:string,colorKey:string)
    local colorPicker=tab:AddColorpicker(id,{
        Title=label,
        Description="Outline / Fill color for this ESP category",
        Default=espColors[colorKey],
        Callback=function(color)
            if typeof(color)=="Color3" then
                espColors[colorKey]=color
            end
        end
    })
    controls[id]=colorPicker
    return colorPicker
end
local function registerSlider(tab:any,id:string,label:string,description:string,
    init:number,minimum:number,maximum:number,rounding:number,onValue:(number)->())
    local item=tab:AddSlider(id,{
        Title=label,Description=description,
        Default=init,Min=minimum,Max=maximum,Rounding=rounding,
        Callback=onValue
    })
    controls[id]=item
    return item
end

local lightingOriginal={
    Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,
    Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,
    FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,
    GlobalShadows=Lighting.GlobalShadows
}
local atmosphereOriginal=setmetatable({}, {__mode="k"})
local function updateLighting()
    local intensity=state.fullbright and math.clamp(state.lightIntensity/100,0,1) or 0
    Lighting.Brightness=lightingOriginal.Brightness+(3-lightingOriginal.Brightness)*intensity
    Lighting.ClockTime=lightingOriginal.ClockTime+(14-lightingOriginal.ClockTime)*intensity
    Lighting.Ambient=lightingOriginal.Ambient:Lerp(Color3.fromRGB(235,235,235),intensity)
    Lighting.OutdoorAmbient=lightingOriginal.OutdoorAmbient:Lerp(Color3.fromRGB(235,235,235),intensity)
    if state.fullbright and intensity>0 then
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
    -- Prefer explicit replicated state over guesses from names or cosmetics.
    if gameValue(other,"IsKiller")==true
        or gameValue(character,"IsKiller")==true then
        return "Killer",espColors.Killer
    end
    if gameValue(other,"IsSurvivor")==true
        or gameValue(character,"IsSurvivor")==true then
        return "Survivor",espColors.Survivor
    end
    local fields={
        tostring(other.Team and other.Team.Name or ""),
        tostring(gameValue(other,"Role") or ""),
        tostring(gameValue(other,"role") or ""),
        tostring(gameValue(other,"TeamRole") or ""),
        tostring(gameValue(character,"Role") or ""),
        tostring(gameValue(character,"TeamRole") or "")
    }
    for _,value in ipairs(fields) do
        local field=value:lower()
        if field=="killer" or field=="killers"
            or field=="hunter" or field=="hunters" then
            return "Killer",espColors.Killer
        elseif field=="survivor" or field=="survivors"
            or field=="innocent" or field=="innocents" then
            return "Survivor",espColors.Survivor
        end
    end
    return "Unknown",espColors.Unknown
end

local roleCache={}
local abilityCache={}
local abilityNotifyCooldown=7
local function monitorPlayerRole(other,now)
    local role=roleOf(other)
    local previous=roleCache[other]
    if previous and previous.role~=role then
        state.roleTransitions+=1
        state.lastRoleTransition=other.DisplayName..": "
            ..previous.role.." → "..role
    end
    roleCache[other]={role=role,char=other.Character,updated=now}
    return role
end
local function booleanAbilitySignal(other)
    local char=other.Character
    for _,key in ipairs({
        "IsUsingAbility","UsingAbility","AbilityActive","AbilityInUse"
    }) do
        local raw=gameValue(char,key)
        if raw==nil then raw=gameValue(other,key) end
        if type(raw)=="boolean" then
            return raw,key
        end
    end
    local phase=gameValue(char,"AbilityState")
        or gameValue(other,"AbilityState")
    if type(phase)=="string" then
        local lower=phase:lower()
        local active=lower=="using" or lower=="active"
            or lower=="casting" or lower=="triggered"
        return active,"AbilityState: "..phase
    end
    return nil,nil
end
local function monitorKillerAbility(other,role,now)
    if role~="Killer" or not other.Character then
        abilityCache[other]=nil
        return
    end
    local value,signalName=booleanAbilitySignal(other)
    local prev=abilityCache[other]
    if value==nil then
        -- No replicated signal: do not invent ability activations.
        if not prev then abilityCache[other]={value=nil,lastAt=-1e9} end
        return
    end
    state.abilitySignalsObserved+=1
    if prev and prev.value==false and value==true
        and now-(prev.lastAt or -1e9)>=abilityNotifyCooldown then
        state.abilityLast=other.DisplayName.." activated ability ("
            ..tostring(signalName)..")"
        state.abilityNotificationCount+=1
        if state.abilityNotify then
            pcall(function()
                Native:Notify({
                    Title="Killer Ability",
                    Content=state.abilityLast,
                    Duration=4
                })
            end)
        end
        prev.lastAt=now
    end
    abilityCache[other]={
        value=value,signal=signalName,
        lastAt=prev and prev.lastAt or -1e9
    }
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
    local role,color=roleOf(other)
    if (role=="Killer" and not state.killerESP) or
        (role=="Survivor" and not state.survivorESP) or
        (role=="Unknown" and not state.unknownESP) then
        removePlayerVisual(other)
        return
    end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot=character:FindFirstChild("HumanoidRootPart")
    local distance=(root and targetRoot)
        and math.floor((root.Position-targetRoot.Position).Magnitude) or nil
    if distance and distance>state.espDistance then
        removePlayerVisual(other)
        return
    end
    local existing=playerVisuals[other]
    if existing and existing.character~=character then
        removePlayerVisual(other)
        existing=nil
    end
    if not existing then
        local highlight=create("Highlight",Workspace,{
            Name="VelionVDPlayerOutline",Adornee=character,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=.82,OutlineTransparency=0
        })
        local billboard=create("BillboardGui",playerGui,{
            Name="VelionVDPlayerTag",Adornee=head,
            AlwaysOnTop=true,Size=UDim2.fromOffset(205,62),
            StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
            MaxDistance=650
        })
        local textLabel=label(billboard,"",0,0,205,62,11)
        textLabel.TextXAlignment=Enum.TextXAlignment.Center
        textLabel.TextStrokeTransparency=.25
        local pointer=label(gui,"",0,0,185,43,11,espColors.Killer)
        pointer.TextXAlignment=Enum.TextXAlignment.Center
        pointer.TextStrokeTransparency=.2
        pointer.Visible=false
        existing={character=character,highlight=highlight,
            billboard=billboard,text=textLabel,pointer=pointer}
        playerVisuals[other]=existing
    end
    local isHooked=gameValue(character,"IsHooked")==true
        or gameValue(other,"IsHooked")==true
    local isKnocked=gameValue(character,"Knocked")==true
        or gameValue(other,"Knocked")==true
    local isChased=gameValue(character,"IsChased")==true
        or gameValue(other,"IsChased")==true
    if isHooked and state.hookedStatus then color=espColors.Hooked
    elseif isKnocked and state.knockedStatus then color=espColors.Knocked
    elseif isChased and state.chaseStatus then color=espColors.Chased end
    local selectedKiller=gameValue(other,"SelectedKiller")
    local nick=(role=="Killer" and selectedKiller)
        and tostring(selectedKiller) or other.DisplayName
    local mask=(state.playerMask and role=="Killer") and maskLabel(other) or nil
    local status=(isHooked and state.hookedStatus and "HOOKED")
        or (isKnocked and state.knockedStatus and "KNOCKED")
        or (isChased and state.chaseStatus and "CHASED") or nil
    local heldItem=nil
    if state.survivorItemsESP and role=="Survivor" then
        local item=character:FindFirstChildWhichIsA("Tool")
        if item then heldItem=item.Name end
    end
    highlightStyle(existing.highlight,color)
    existing.highlight.Enabled=state.playerHighlight and
        (not distance or distance<=state.espDistance)
    existing.billboard.MaxDistance=state.espDistance
    existing.billboard.Enabled=state.playerNames or status~=nil
        or heldItem~=nil or (state.playerMask and mask~=nil)
        or (state.playerDistance and distance~=nil)
    existing.text.TextColor3=color
    existing.text.Text=(state.playerNames and (nick.." ["..role.."]") or "")
        ..(state.playerDistance and distance and
            ("\n"..distance.." studs") or "")
        ..(mask and ("\nMask: "..mask) or "")
        ..(status and ("\n"..status) or "")
        ..(heldItem and ("\nHeld item: "..heldItem) or "")
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

-- WORLD ESP V2: map-only discovery, lazy rendering and strict visibility caps.
-- High-instance-count lobby objects, cosmetic preview models and fake
-- characters are deliberately excluded by the Workspace.Map scope.
-- V4.2 World ESP: two verified Workspace scopes (Map + Interactables).
-- No full Workspace scans, preview-model targeting or arbitrary 90-object cap.
local objectiveKinds={
    {name="Generator",key="generator",priority=145},
    {name="ExitGate",key="gate",priority=115},
    {name="Gate",key="gate",priority=115},
    {name="Hook",key="hook",priority=80},
    {name="Palletwrong",key="pallet",priority=55},
    {name="Pallet",key="pallet",priority=55},
    {name="Window",key="window",priority=18},
    {name="Medkit",key="item",priority=65},
    {name="Bandage",key="item",priority=65},
    {name="Flashlight",key="item",priority=65},
    {name="Battery",key="item",priority=65},
    {name="Item",key="item",priority=65},
    {name="Pickup",key="item",priority=65},
}
local currentMap: Instance?=nil
local activeInteractables: Instance?=nil
local sourceConnections: {RBXScriptConnection}={}
local scanGeneration=0
local lastObjectiveRefresh=0
local cachedNameKinds={}
for _,kind in ipairs(objectiveKinds) do
    cachedNameKinds[kind.name:lower()]=kind
end
local itemKind={name="ITEM",key="item",priority=65}
local repairKind=cachedNameKinds.generator
local windowKind=cachedNameKinds.window

local function objectiveEnabled(key: string): boolean
    if key=="generator" then return state.generatorESP end
    if key=="pallet" then return state.palletESP end
    if key=="window" then return state.windowESP end
    if key=="hook" then return state.hookESP end
    if key=="gate" then return state.gateESP end
    if key=="item" then return state.worldItemsESP end
    return false
end
local function inScope(item: Instance): boolean
    local root: Instance?=nil
    if currentMap and item:IsDescendantOf(currentMap) then
        root=currentMap
    elseif activeInteractables and item:IsDescendantOf(activeInteractables) then
        root=activeInteractables
    end
    if not root then return false end
    local node=item
    while node and node~=root do
        local lower=node.Name:lower()
        if lower:find("lobby",1,true)
            or lower:find("preview",1,true)
            or lower:find("fakecharacter",1,true) then
            return false
        end
        node=node.Parent
    end
    return true
end
local function classifyNamed(item: Instance)
    if not item:IsA("Model") and not item:IsA("BasePart")
        and not item:IsA("Tool") then return nil end
    if item:IsA("Tool") then return itemKind end
    local canonical=item.Name:lower():gsub("[%s_%-]","")
    for _,kind in ipairs(objectiveKinds) do
        local target=kind.name:lower()
        if canonical==target or canonical:match("^"..target.."%d+$") then
            return kind
        end
    end
    return nil
end
local function promptKind(item: Instance)
    if not item:IsA("ProximityPrompt") then return nil end
    local action=item.ActionText:lower()
    if action:find("repair",1,true) then return repairKind end
    if action:find("vault",1,true) then return windowKind end
    if action:find("pick up",1,true) or action:find("pickup",1,true)
        or action:find("collect",1,true) or action=="take" then
        return itemKind
    end
    return nil
end
local function getObjective(item: Instance)
    if not inScope(item) then return nil,nil,nil end
    local kind=classifyNamed(item)
    local original=item
    if item:IsA("ProximityPrompt") then
        kind=promptKind(item)
        if not kind then return nil,nil,nil end
        -- Follow the nearest physical owner. Generic House/Room models
        -- must not absorb multiple prompts into giant ESP markers.
        local cursor=item.Parent
        local nearestPart: BasePart?=nil
        local namedModel: Model?=nil
        local toolOwner: Tool?=nil
        while cursor and cursor~=currentMap
            and cursor~=activeInteractables do
            if cursor:IsA("BasePart") and not nearestPart then
                nearestPart=cursor
            elseif cursor:IsA("Tool") and not toolOwner then
                toolOwner=cursor
            elseif cursor:IsA("Model") and not namedModel then
                local match=classifyNamed(cursor)
                if match and match.key==kind.key then namedModel=cursor end
            end
            cursor=cursor.Parent
        end
        if namedModel then
            item=namedModel
        elseif toolOwner and kind.key=="item" then
            item=toolOwner
        elseif nearestPart then
            item=nearestPart
        else
            return nil,nil,nil
        end
    end
    if not kind then return nil,nil,nil end
    -- Model gets one marker even when its nested part shares the same name.
    if original:IsA("BasePart") then
        local parent=original.Parent
        if parent and parent:IsA("Model") and classifyNamed(parent)
            and inScope(parent) then
            return nil,nil,nil
        end
    end
    local part: BasePart?=nil
    if item:IsA("BasePart") then
        part=item
    elseif item:IsA("Model") then
        part=item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart",true)
    elseif item:IsA("Tool") then
        part=item:FindFirstChild("Handle")
        if not part or not part:IsA("BasePart") then
            part=item:FindFirstChildWhichIsA("BasePart")
        end
    end
    if not part then return nil,nil,nil end
    return item,part,kind
end

local function destroyObjectiveNodes(record)
    if record.gui then record.gui:Destroy();record.gui=nil end
    if record.highlight then record.highlight:Destroy();record.highlight=nil end
    record.text=nil
end
local function removeObjectiveRecord(obj: Instance)
    local rec=objectiveVisuals[obj]
    if not rec then return end
    destroyObjectiveNodes(rec)
    objectiveVisuals[obj]=nil
    state.identifiedObjectives=math.max(0,state.identifiedObjectives-1)
    if rec.kind.key=="item" then
        state.worldItemsFound=math.max(0,state.worldItemsFound-1)
    end
end
local function clearObjectives()
    for obj in pairs(objectiveVisuals) do removeObjectiveRecord(obj) end
    state.identifiedObjectives=0
    state.visibleLabels=0
    state.visibleHighlights=0
    state.worldItemsFound=0
end
local function considerObjective(candidate: Instance)
    if not state.alive or not candidate.Parent then return end
    local obj,part,kind=getObjective(candidate)
    if not obj or not part or not kind then return end
    if objectiveVisuals[obj] then return end
    objectiveVisuals[obj]={
        obj=obj,part=part,kind=kind,gui=nil,
        highlight=nil,text=nil,lastVisible=0,
        progressRef=nil,progressMaxRef=nil
    }
    state.identifiedObjectives+=1
    if kind.key=="item" then state.worldItemsFound+=1 end
end
local function makeObjectiveNodes(rec)
    if not rec.gui then
        local board=create("BillboardGui",playerGui,{
            Name="VelionVDObjective",Adornee=rec.part,
            Size=UDim2.fromOffset(160,30),AlwaysOnTop=true,
            Enabled=false,MaxDistance=state.espDistance,
            StudsOffsetWorldSpace=Vector3.new(0,3,0)
        })
        local tag=label(board,rec.kind.name:upper(),
            0,0,160,30,12,categoryColor(rec.kind.key))
        tag.TextXAlignment=Enum.TextXAlignment.Center
        tag.TextStrokeTransparency=.25
        rec.gui=board
        rec.text=tag
    end
    if state.objectHighlight and not rec.highlight then
        rec.highlight=create("Highlight",Workspace,{
            Name="VelionVDObjectiveOutline",Adornee=rec.obj,
            Enabled=false,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
            FillTransparency=1,OutlineTransparency=0,
            FillColor=categoryColor(rec.kind.key),
            OutlineColor=categoryColor(rec.kind.key)
        })
    end
end

local function asNumber(target: Instance?,field: string): number?
    if not target then return nil end
    local raw=gameValue(target,field)
    if type(raw)=="number" then return raw end
    return nil
end
-- Only sample plausible progress fields, not arbitrary "Progress" GUI text.
-- A missing maximum for 0 < x < 1 is intentionally not guessed as percent.
local function generatorProgress(rec): string
    local obj=rec.obj
    local part=rec.part
    local progress=asNumber(obj,"RepairProgress")
        or asNumber(obj,"Progress")
        or asNumber(part,"RepairProgress")
        or asNumber(part,"Progress")
    local maxValue=asNumber(obj,"MaxRepairProgress")
        or asNumber(obj,"MaxProgress")
        or asNumber(part,"MaxRepairProgress")
        or asNumber(part,"MaxProgress")
    if progress==nil and obj:IsA("Model") then
        if not rec.progressRef or not rec.progressRef.Parent then
            rec.progressRef=obj:FindFirstChild("RepairProgress",true)
                or obj:FindFirstChild("Progress",true)
        end
        local node=rec.progressRef
        if node and node:IsA("ValueBase") and type(node.Value)=="number" then
            progress=node.Value
        end
    end
    if not maxValue and obj:IsA("Model") then
        if not rec.progressMaxRef or not rec.progressMaxRef.Parent then
            rec.progressMaxRef=obj:FindFirstChild("MaxRepairProgress",true)
                or obj:FindFirstChild("MaxProgress",true)
        end
        local node=rec.progressMaxRef
        if node and node:IsA("ValueBase") and type(node.Value)=="number" then
            maxValue=node.Value
        end
    end
    if type(progress)~="number" then
        state.progressUnknown+=1
        return "GEN • progress unavailable"
    end
    local value: number?=nil
    if maxValue and maxValue>0 and state.progressScale~="Raw" then
        value=progress/maxValue*100
    elseif state.progressScale=="Fraction" then
        value=progress*100
    elseif state.progressScale=="Percent" then
        value=progress
    elseif state.progressScale=="Auto" then
        if progress==0 or (progress>=1 and progress<=100) then
            value=progress
        end
    end
    if value then
        return string.format("GEN %.0f%%",math.clamp(value,0,100))
    end
    state.progressUnknown+=1
    return string.format("GEN %.2f (raw)",progress)
end

local function refreshObjectiveVisibility()
    local now=os.clock()
    if now-lastObjectiveRefresh<.3 then return end
    lastObjectiveRefresh=now
    local cam=Workspace.CurrentCamera
    local root=player.Character and
        player.Character:FindFirstChild("HumanoidRootPart")
    local candidates={}
    local cacheCount=0
    for obj,rec in pairs(objectiveVisuals) do
        if not obj.Parent or not rec.part.Parent or not inScope(obj) then
            removeObjectiveRecord(obj)
        else
            cacheCount+=1
            if rec.gui then rec.gui.Enabled=false end
            if rec.highlight then rec.highlight.Enabled=false end
            if state.objectiveESP and objectiveEnabled(rec.kind.key)
                and root and cam then
                local d=(root.Position-rec.part.Position).Magnitude
                if d<=state.espDistance then
                    local pos,onScreen=cam:WorldToViewportPoint(
                        rec.part.Position)
                    if onScreen and pos.Z>0 then
                        candidates[#candidates+1]={
                            rec=rec,dist=d,pos=pos,
                            priority=d-rec.kind.priority
                        }
                    end
                end
            end
        end
    end
    table.sort(candidates,function(a,b)
        return a.priority<b.priority
    end)
    local occupied={}
    local labels,highlights=0,0
    -- Share a conservative Highlight limit with active Player ESP.
    local playerHighlights=0
    for _,data in pairs(playerVisuals) do
        if data.highlight and data.highlight.Enabled then
            playerHighlights+=1
        end
    end
    local safeHighlightLimit=math.min(state.maxWorldHighlights,
        math.max(0,28-playerHighlights))
    state.highlightBudgetAvailable=safeHighlightLimit
    state.progressUnknown=0
    for _,entry in ipairs(candidates) do
        local rec=entry.rec
        local cell=math.floor(entry.pos.X/125)..":"..
            math.floor(entry.pos.Y/64)
        local showLabel=state.objectLabels
            and labels<state.maxWorldLabels and not occupied[cell]
        local showOutline=state.objectHighlight
            and highlights<safeHighlightLimit
        if showLabel or showOutline then
            makeObjectiveNodes(rec)
            local color=categoryColor(rec.kind.key)
            if rec.text then
                rec.text.TextColor3=color
                if rec.kind.key=="generator" and state.generatorProgressESP then
                    rec.text.Text=generatorProgress(rec)
                elseif rec.kind.key=="item" then
                    rec.text.Text="ITEM • "..rec.obj.Name
                else
                    rec.text.Text=rec.kind.name:upper()
                end
            end
            if rec.gui then
                rec.gui.MaxDistance=state.espDistance
                rec.gui.Enabled=showLabel
            end
            if rec.highlight then
                highlightStyle(rec.highlight,color)
                rec.highlight.Enabled=showOutline
            end
            if showLabel then
                occupied[cell]=true;labels+=1
            end
            if showOutline then highlights+=1 end
            rec.lastVisible=now
        end
    end
    -- Prune only inactive visuals; retain metadata so spawning hundreds of
    -- objects won't spawn hundreds of GUI instances.
    for _,rec in pairs(objectiveVisuals) do
        if rec.gui and now-rec.lastVisible>5 then
            destroyObjectiveNodes(rec)
        end
    end
    state.scanCandidates=cacheCount
    state.visibleLabels=labels
    state.visibleHighlights=highlights
end

local function stopSourceWatchers()
    for _,c in ipairs(sourceConnections) do c:Disconnect() end
    table.clear(sourceConnections)
end
local function startObjectiveScan()
    if not state.objectiveESP then return end
    scanGeneration+=1
    local token=scanGeneration
    stopSourceWatchers()
    clearObjectives()
    currentMap=Workspace:FindFirstChild("Map")
    activeInteractables=Workspace:FindFirstChild("Interactables")
    state.scanScanned=0
    state.scanMapCount=0
    state.scanInteractableCount=0
    state.scanDurationMs=0
    lastObjectiveRefresh=0
    local sources={}
    if currentMap then sources[#sources+1]=currentMap end
    if activeInteractables and activeInteractables~=currentMap then
        sources[#sources+1]=activeInteractables
    end
    -- No round map means no active objective ESP; don't tag the lobby.
    if not currentMap then
        state.scanProgress="Waiting for Workspace.Map"
        activeInteractables=nil
        return
    end
    for _,source in ipairs(sources) do
        sourceConnections[#sourceConnections+1]=source.DescendantAdded:Connect(
            function(item) considerObjective(item) end)
        sourceConnections[#sourceConnections+1]=source.DescendantRemoving:Connect(
            function(item)
                if objectiveVisuals[item] then removeObjectiveRecord(item) end
            end)
    end
    state.scanProgress="Scanning Map + Interactables"
    task.spawn(function()
        local start=os.clock()
        for _,source in ipairs(sources) do
            local descendants=source:GetDescendants()
            state.scanScanned+=#descendants
            if source==currentMap then state.scanMapCount=#descendants
            else state.scanInteractableCount=#descendants end
            for i,node in ipairs(descendants) do
                if not state.alive or scanGeneration~=token then return end
                considerObjective(node)
                if i%120==0 then task.wait() end
            end
        end
        if not state.alive or scanGeneration~=token then return end
        state.scanDurationMs=math.floor((os.clock()-start)*1000)
        state.scanProgress="Map + Interactables ready"
    end)
end
connect(Workspace.ChildAdded,function(item)
    if item.Name=="Map" or item.Name=="Interactables" then
        task.defer(function()
            if state.alive then startObjectiveScan() end
        end)
    end
end)
connect(Workspace.ChildRemoved,function(item)
    if item==currentMap or item==activeInteractables then
        task.defer(function()
            if state.alive then startObjectiveScan() end
        end)
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
-- Camera comfort: native camera remains responsible for position, input and occlusion.
-- Only angular presentation and inward-clamped zoom recovery are filtered.
local cameraController=(function()
    local suffix=tostring(player.UserId)
    local lensBinding="VelionCameraLens_"..suffix
    local beforeBinding="VelionCameraBefore_"..suffix
    local afterBinding="VelionCameraComfort_"..suffix
    local lensCamera: Camera?=nil
    local reference=70
    local native=70
    local applied: number?=nil
    local filtered=70
    local lensBound=false
    local poseBound=false
    local poseCamera: Camera?=nil
    local rawPose: CFrame?=nil
    local shownPose: CFrame?=nil
    local smoothedRotation: CFrame?=nil
    local smoothedDistance: number?=nil
    local lastFocus: Vector3?=nil
    local function alpha(dt,seconds)
        return seconds<=0 and 1 or 1-math.exp(-math.clamp(dt,0,0.25)/seconds)
    end
    local function eligible(cam)
        if not cam or cam.CameraType~=Enum.CameraType.Custom then return false end
        local character=player.Character
        local subject=cam.CameraSubject
        if not character or not subject or not subject:IsDescendantOf(character) then return false end
        local hum=character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then return false end
        if game:GetService("VRService").VREnabled then return false end
        return true
    end
    local function restoreLens()
        if lensCamera and applied~=nil and math.abs(lensCamera.FieldOfView-applied)<0.02 then
            lensCamera.FieldOfView=native
        end
        lensCamera=nil
        applied=nil
    end
    local function lensStep(dt)
        if not state.alive or not state.customFov then return end
        local cam=Workspace.CurrentCamera
        if not eligible(cam) then restoreLens(); return end
        if lensCamera~=cam then
            restoreLens()
            lensCamera=cam
            reference=cam.FieldOfView
            native=reference
            filtered=reference
        end
        local observed=cam.FieldOfView
        if applied==nil or math.abs(observed-applied)>0.02 then native=observed end
        local offset=state.fovMode=="Preserve Dynamic" and (native-reference) or 0
        local target=math.clamp(state.fov+offset,1,120)
        filtered=math.clamp(filtered+(target-filtered)*alpha(dt,state.fovSmooth),1,120)
        if math.abs(target-filtered)<0.02 then filtered=target end
        if math.abs(observed-filtered)>0.02 then cam.FieldOfView=filtered end
        applied=cam.FieldOfView
    end
    local function restorePose()
        if poseCamera and rawPose and shownPose and poseCamera.CFrame==shownPose then
            poseCamera.CFrame=rawPose
        end
        rawPose=nil
        shownPose=nil
    end
    local function clearPose()
        restorePose()
        poseCamera=nil
        smoothedRotation=nil
        smoothedDistance=nil
        lastFocus=nil
    end
    local function beforePose()
        -- Do not feed our visual pose back into the native camera controller.
        restorePose()
    end
    local function afterPose(dt)
        local cam=Workspace.CurrentCamera
        if not state.alive or not eligible(cam) then clearPose(); return end
        if poseCamera~=cam then clearPose(); poseCamera=cam end
        local raw=cam.CFrame
        local focus=cam.Focus.Position
        local offset=raw.Position-focus
        local distance=offset.Magnitude
        local rawRotation=raw.Rotation
        if distance<2.5 or (lastFocus and (focus-lastFocus).Magnitude>12) then
            smoothedRotation=rawRotation
            smoothedDistance=distance
            lastFocus=focus
            return
        end
        lastFocus=focus
        local previousRotation=smoothedRotation or rawRotation
        local previousDistance=smoothedDistance or distance
        local rotation=rawRotation
        if state.smoothCamera then
            rotation=previousRotation:Lerp(rawRotation,alpha(dt,state.cameraTurnTime))
            local _,lag=(rotation:ToObjectSpace(rawRotation)):ToAxisAngle()
            -- Limit visual lag; rapid direction changes remain responsive.
            if math.abs(lag)>math.rad(12) then
                rotation=rawRotation:Lerp(rotation,math.rad(12)/math.abs(lag))
            end
        end
        local newDistance=distance
        if state.smoothZoom and distance>previousDistance then
            newDistance=math.min(distance,previousDistance+(distance-previousDistance)*alpha(dt,state.cameraZoomTime))
        end
        -- Occlusion or deliberate zoom-in always wins immediately.
        newDistance=math.clamp(newDistance,0,distance)
        smoothedRotation=rotation
        smoothedDistance=newDistance
        local position=focus+offset.Unit*newDistance
        rawPose=raw
        cam.CFrame=CFrame.new(position)*rotation
        shownPose=cam.CFrame
    end
    local function setEnabled(enabled: boolean)
        state.customFov=enabled
        if enabled and not lensBound then
            RunService:BindToRenderStep(lensBinding,Enum.RenderPriority.Last.Value+1,lensStep)
            lensBound=true
        elseif not enabled then
            if lensBound then RunService:UnbindFromRenderStep(lensBinding); lensBound=false end
            restoreLens()
        end
    end
    local function refreshPose()
        local enabled=state.smoothCamera or state.smoothZoom
        if enabled and not poseBound then
            RunService:BindToRenderStep(beforeBinding,Enum.RenderPriority.Camera.Value-1,beforePose)
            RunService:BindToRenderStep(afterBinding,Enum.RenderPriority.Camera.Value+1,afterPose)
            poseBound=true
        elseif not enabled then
            if poseBound then
                RunService:UnbindFromRenderStep(beforeBinding)
                RunService:UnbindFromRenderStep(afterBinding)
                poseBound=false
            end
            clearPose()
        end
    end
    local function nativeFreeLookInfo()
        local ok,mode=pcall(function() return UserSettings().GameSettings.ComputerCameraMovementMode end)
        if not ok then return "Read unavailable; use Roblox Settings > Camera Mode." end
        if player.DevComputerCameraMode~=Enum.DevComputerCameraMovementMode.UserChoice
            and player.DevComputerCameraMode~=Enum.DevComputerCameraMovementMode.CameraToggle then
            return "Camera mode is controlled by this experience. No override applied."
        end
        if mode==Enum.ComputerCameraMovementMode.CameraToggle
            or player.DevComputerCameraMode==Enum.DevComputerCameraMovementMode.CameraToggle then
            return "CameraToggle selected. Click RMB once to enter or exit free-look."
        end
        return "Open Roblox Settings > Camera Mode > CameraToggle if available; click RMB once. Current: "..tostring(mode.Name)
    end
    local function shutdown()
        state.smoothCamera=false
        state.smoothZoom=false
        refreshPose()
        setEnabled(false)
    end
    local function status()
        -- Read-only diagnostics. Do not change camera ownership or eligibility.
        local cam=Workspace.CurrentCamera
        if not cam then return "No active camera. Waiting for the experience." end
        local function onOff(value) return value and "ON" or "OFF" end
        local info=string.format("Actual FOV: %.1f° | configured: %.1f° | type: %s",cam.FieldOfView,state.fov,cam.CameraType.Name)
        info=info.."\nFOV: "..onOff(state.customFov).." | rotation: "..onOff(state.smoothCamera).." | zoom: "..onOff(state.smoothZoom)
        if not state.customFov and not state.smoothCamera and not state.smoothZoom then
            return info.."\nAll camera options OFF. Native camera is unchanged."
        end
        if not eligible(cam) then
            return info.."\nNative camera unavailable for these options. Experience camera is respected."
        end
        return info.."\nOptions requested. Runtime behavior has not been verified."
    end
    return {setEnabled=setEnabled,refreshPose=refreshPose,shutdown=shutdown,nativeFreeLookInfo=nativeFreeLookInfo,status=status}
end)()
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






-- Manual input practice: never writes Humanoid.Move, AutoRotate, or root CFrame.
local function setMoonwalk(enabled: boolean)
    state.moonwalk=enabled
    state.moonwalkStatus=enabled and "Manual input monitor only; does not animate the character." or "Practice OFF"
end

-- =========================================
-- Native controls.
-- =========================================
local statusMain=Tabs.Main:AddParagraph({
    Title="CURRENT SESSION",Content="Reading players and map..."
})
local statusKiller=Tabs.Main:AddParagraph({
    Title="KILLER DISTANCE",Content="Waiting for known killer..."
})
local statusSkill=Tabs.Main:AddParagraph({
    Title="SKILL CHECK",Content="UI not active"
})
local statusNext=Tabs.Main:AddParagraph({
    Title="NEXT KILLER (ESTIMATE)",Content="Waiting for lobby"
})
registerToggle(Tabs.Players,"PlayerESPMaster","Enable player markers",
    "Overall player outlines / nametags switch","playerESP",
    function(value)
        if not value then
            for other in pairs(playerVisuals) do
                removePlayerVisual(other)
            end
        end
    end)
registerToggle(Tabs.Objects,"ObjectESPMaster","Enable map markers",
    "Show map object highlights and labels","objectiveESP",
    function(value)
        if value then startObjectiveScan()
        else
            scanGeneration+=1
            stopSourceWatchers()
            clearObjectives()
            state.scanProgress="Disabled"
        end
        refreshObjectiveVisibility()
    end)

-- Player ESP: category and display toggles are independent.
Tabs.Players:AddParagraph({Title="How to use",Content="Enable player markers, choose a category, then enable names or body highlight. Detection remains unverified."})
registerToggle(Tabs.Players,"KillerESP","Killer ESP",
    "Killer character outline + labels","killerESP")
registerColor(Tabs.Players,"KillerColor","Killer Color","Killer")
registerToggle(Tabs.Players,"SurvivorESP","Survivor ESP",
    "Survivor character outline + labels","survivorESP")
registerColor(Tabs.Players,"SurvivorColor","Survivor Color","Survivor")
registerToggle(Tabs.Players,"UnknownESP","Unknown Role Markers",
    "Disabled by default; prevents lobby role false positives","unknownESP")
registerToggle(Tabs.Players,"SurvivorItems","Survivor Equipped Items",
    "Show Tool names equipped by visible Survivor characters",
    "survivorItemsESP")
registerToggle(Tabs.Players,"PlayerOutline","Body Highlight",
    "Color or outline the character model","playerHighlight")
registerToggle(Tabs.Players,"NameESP","Player Names",
    "Show names and roles","playerNames")
registerToggle(Tabs.Players,"DistanceESP","Show Distance",
    "Show stud distance on name tags","playerDistance")
registerToggle(Tabs.Players,"MaskESP","Killer Mask ESP",
    "Display replicated mask name","playerMask")
registerToggle(Tabs.Players,"ChasedESP","Chased Indicator",
    "Special marker for chased player","chaseStatus")
registerColor(Tabs.Players,"ChasedColor","Chased Indicator Color","Chased")
registerToggle(Tabs.Players,"KnockedESP","Knocked Indicator",
    "Show knocked status","knockedStatus")
registerColor(Tabs.Players,"KnockedColor","Knocked Indicator Color","Knocked")
registerToggle(Tabs.Players,"HookedESP","Hooked Indicator",
    "Show hooked status","hookedStatus")
registerColor(Tabs.Players,"HookedColor","Hooked Indicator Color","Hooked")
registerToggle(Tabs.Players,"OffscreenESP","Off-Screen Pointers",
    "Display directions near screen edges","offscreenESP")
registerToggle(Tabs.Players,"KillerWarn","Killer Proximity Alert",
    "Notify when known killer is less than 99 studs","killerAlert")

-- Object ESP: separate toggle and color selector per kind.
Tabs.Objects:AddParagraph({Title="How to use",Content="Enable map markers, select an object category and enable labels or outlines. Click the color square to edit its color."})
registerToggle(Tabs.Objects,"ObjectOutline","Object Highlight",
    "Enable object Highlight outlines / fill","objectHighlight",
    function() refreshObjectiveVisibility() end)
registerToggle(Tabs.Objects,"GeneratorESP","Generator ESP",
    "Generator highlight + location","generatorESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"GeneratorColor","Generator Color","Generator")
registerToggle(Tabs.Objects,"GenProgress","Generator Repair %",
    "Show replicated repair percent","generatorProgressESP",
    function() refreshObjectiveVisibility() end)
registerToggle(Tabs.Objects,"PalletESP","Pallet ESP",
    "Both Pallet / Palletwrong","palletESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"PalletColor","Pallet Color","Pallet")
registerToggle(Tabs.Objects,"WindowESP","Window ESP",
    "Window map objects","windowESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"WindowColor","Window Color","Window")
registerToggle(Tabs.Objects,"HookESP","Hook ESP",
    "Map Hook models","hookESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"HookColor","Hook Color","Hook")
registerToggle(Tabs.Objects,"GateESP","Gate ESP",
    "Exit gates","gateESP",
    function() refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"GateColor","Gate Color","Gate")
registerToggle(Tabs.Objects,"WorldItems","World Pickup Items",
    "Show Tool and recognized pickup objects within Map/Interactables",
    "worldItemsESP",
    function() lastObjectiveRefresh=0;refreshObjectiveVisibility() end)
registerColor(Tabs.Objects,"ItemColor","Item Color","Item")
local itemInfo=Tabs.Objects:AddParagraph({
    Title="SURVIVOR ITEMS ESP",
    Content="Replicated world Tools and pickup prompts only. Unreplicated inventories are unavailable."
})
Tabs.Objects:AddButton({
    Title="Rescan Map",Description="Refresh Workspace map references",
    Callback=function() startObjectiveScan() end
})
local objectStatus=Tabs.Objects:AddParagraph({
    Title="WORLD ESP V2",Content="Waiting for active map..."
})
local perfStatus=Tabs.Objects:AddParagraph({
    Title="WORLD ESP DIAGNOSTICS",
    Content="Map status, cache, visible labels, highlights and FPS"
})
local progressStatus=Tabs.Objects:AddParagraph({
    Title="GENERATOR PROGRESS",
    Content="Auto detects percentage where possible; ambiguous values show raw."
})
local progressDropdown=Tabs.Objects:AddDropdown("GeneratorProgressScale",{
    Title="Generator Progress Units",
    Description="Auto / percent 0-100 / fraction 0-1 / raw value",
    Values={"Auto","Percent","Fraction","Raw"},Default="Auto",
    Callback=function(v)
        if v=="Auto" or v=="Percent" or v=="Fraction" or v=="Raw" then
            state.progressScale=v
            lastObjectiveRefresh=0
        end
    end
})
controls.GeneratorProgressScale=progressDropdown
registerToggle(Tabs.Objects,"ObjectLabels","Object Labels",
    "Display labels without crowding the screen","objectLabels",
    function() lastObjectiveRefresh=0;refreshObjectiveVisibility() end)
registerSlider(Tabs.Objects,"MaxLabels","Maximum Object Labels",
    "Render nearest prioritized labels; 0 hides labels",
    state.maxWorldLabels,0,40,0,
    function(v)
        state.maxWorldLabels=v
        lastObjectiveRefresh=0
        refreshObjectiveVisibility()
    end)
registerSlider(Tabs.Objects,"MaxHighlights","Maximum Object Highlights",
    "Caps simultaneous highlights to protect FPS (max 26)",
    state.maxWorldHighlights,0,26,0,
    function(v)
        state.maxWorldHighlights=v
        lastObjectiveRefresh=0
        refreshObjectiveVisibility()
    end)
registerSlider(Tabs.Objects,"ESPRange","ESP Distance",
    "Max object and player visibility range (studs)",
    state.espDistance,100,2000,0,
    function(v) state.espDistance=v;refreshObjectiveVisibility() end)
local hMode=Tabs.Objects:AddDropdown("HighlightMode",{
    Title="Highlight Mode",
    Description="Choose between outline, fill or both",
    Values={"Outline","Fill","Both"},Default=1,
    Callback=function(v)
        if v=="Outline" or v=="Fill" or v=="Both" then
            state.highlightMode=v
        end
    end
})
controls.HighlightMode=hMode

-- Killer ability notifications are observational, not synthetic remote calls.
registerToggle(Tabs.Killer,"KillerAbilityNotify","Killer Ability Notifications",
    "Alerts on replicated false-to-true ability status changes only",
    "abilityNotify")
local abilityStatus=Tabs.Killer:AddParagraph({
    Title="ABILITY SIGNAL MONITOR",
    Content="Waiting for replicated ability state; no remote hooks are assumed."
})
local roleStatus=Tabs.Killer:AddParagraph({
    Title="KILLER / SURVIVOR ROLE TRACKING",
    Content="Updates roles from Team and explicit replicated flags."
})
Tabs.Killer:AddParagraph({
    Title="LIMITATIONS",
    Content="No server ability packets are captured. Unknown states produce no speculative alerts."
})

-- Survivor mechanics only where source references are available.
registerToggle(Tabs.Survivor,"MonitorSkill","Skill Check Monitor",
    "Read Line / Goal rotation from the game UI","skillMonitor")
Tabs.Survivor:AddParagraph({
    Title="Manual skill checks",
    Content="Automatic generator input is not included in this version. Practice manually; game detection is not verified."
})
registerToggle(Tabs.Survivor,"NextKiller","Next Killer Estimate",
    "Based on AllowKiller and KillerChance","nextKiller")
local inputStatus=Tabs.Survivor:AddParagraph({
    Title="INPUT STATUS",Content="Manual input only"
})
local skillStatus=Tabs.Survivor:AddParagraph({
    Title="SKILL CHECK STATUS",Content="Reading..."
})

local movementDiagnostics=Tabs.Movement:AddParagraph({
    Title="MOVEMENT DIAGNOSTICS",
    Content="Native movement retained. NoClip and forced WalkSpeed are disabled in this build."
})
Tabs.Movement:AddButton({
    Title="Reset Movement",
    Description="Disable local movement assists and restore their original settings.",
    Callback=function()
        setNoClip(false)
        setSpeed(false)
        if toggles.MoonwalkAD then toggles.MoonwalkAD:SetValue(false) end
    end
})
registerToggle(Tabs.Movement,
    "MoonwalkAD","Moonwalk Input Practice",
    "Shows manual A/D input without changing movement or rotation.",
    "moonwalk",setMoonwalk)
local moonwalkStatusBox=Tabs.Movement:AddParagraph({
    Title="INPUT STATUS",Content="Practice OFF"
})


registerToggle(Tabs.Visual,"Fullbright","Fullbright",
    "Lighten environment locally","fullbright",
    function() updateLighting() end)
registerSlider(Tabs.Visual,"LightIntensity","Lighting Intensity",
    "0 = native lighting, 100 = full brightness. Enable Fullbright first.",
    state.lightIntensity,0,100,0,function(v) state.lightIntensity=v;if state.fullbright then updateLighting() end end)
registerToggle(Tabs.Visual,"NoFog","Remove Fog",
    "Reduce atmosphere density and fog","noFog",
    function() updateLighting() end)
Tabs.Visual:AddParagraph({
    Title="CAMERA / LENS",
    Content="70-degree reference lens. Optional angular smoothing and conservative zoom recovery; native collision remains the limit."
})
registerToggle(Tabs.Visual,"CustomFov","Custom FOV",
    "Optional local lens override; OFF restores native FOV.",
    "customFov",cameraController.setEnabled)
local cameraStatusBox=Tabs.Visual:AddParagraph({Title="Camera status",Content="Waiting for camera..."})
local fovSlider=registerSlider(Tabs.Visual,"CameraFov","Field of View",
    "Vertical FOV in degrees (native maximum 120).",
    state.fov,60,120,0,function(v) state.fov=v end)
local lensPresets={["1.0x"]=1,["0.8x"]=0.8,["0.7x"]=0.7,["0.6x"]=0.6,["0.5x"]=0.5}
-- Buttons avoid persisting a second, conflicting FOV source in SaveManager.
for _,preset in ipairs({"1.0x","0.8x","0.7x","0.6x","0.5x"}) do
    local factor=lensPresets[preset]
    local degrees=math.floor(math.deg(2*math.atan(math.tan(math.rad(35))/factor))+0.5)
    Tabs.Visual:AddButton({
        Title="Lens "..preset.." / "..tostring(degrees).." deg",
        Description="Set target FOV; enable Custom FOV to apply.",
        Callback=function()
            state.fov=degrees
            fovSlider:SetValue(degrees)
        end
    })
end
controls.FovMode=Tabs.Visual:AddDropdown("FovMode",{
    Title="FOV Behavior",
    Values={"Preserve Dynamic","Fixed"},Default="Preserve Dynamic",
    Description="Preserve observed native FOV changes or keep a fixed target.",
    Callback=function(v)
        if v=="Preserve Dynamic" or v=="Fixed" then state.fovMode=v end
    end
})
registerSlider(Tabs.Visual,"FovSmooth","FOV Smoothing",
    "Exponential transition time constant in seconds; 0 = instant.",
    state.fovSmooth,0,0.6,2,function(v) state.fovSmooth=v end)
registerToggle(Tabs.Visual,"SmoothCamera","Smooth Camera Rotation",
    "Optional visual angular smoothing; native camera still handles movement.",
    "smoothCamera",function() cameraController.refreshPose() end)
registerSlider(Tabs.Visual,"CameraTurnTime","Rotation Smoothing",
    "Transition time in seconds; 0 = native response.",
    state.cameraTurnTime,0,0.3,2,function(v) state.cameraTurnTime=v end)
registerToggle(Tabs.Visual,"SmoothZoom","Smooth Zoom Recovery",
    "Smooth zoom-out only; zoom-in remains immediate for native occlusion.",
    "smoothZoom",function() cameraController.refreshPose() end)
registerSlider(Tabs.Visual,"CameraZoomTime","Zoom Recovery Time",
    "Transition time in seconds; 0 = instant.",
    state.cameraZoomTime,0,0.6,2,function(v) state.cameraZoomTime=v end)
Tabs.Visual:AddButton({
    Title="Native Free-Look Setup",
    Description="Check whether Roblox CameraToggle is available. No forced camera mode.",
    Callback=function()
        Native:Notify({Title="Native Free-Look",Content=cameraController.nativeFreeLookInfo(),Duration=8})
    end
})
Tabs.Visual:AddButton({
    Title="Reset Camera Lens",
    Description="Disable all camera comfort overrides and restore the native camera.",
    Callback=function()
        fovSlider:SetValue(70)
        toggles.SmoothCamera:SetValue(false)
        toggles.SmoothZoom:SetValue(false)
        toggles.CustomFov:SetValue(false)
        cameraController.shutdown()
    end
})

-- Fixed dark theme and native menu shortcut. Gameplay preferences never auto-enable.
local glassModeStatus="Native opaque monochrome"
Tabs.Settings:AddButton({Title="Reset Window Position",Description="Return the draggable interface to the center of the viewport.",ButtonText="RESET",Callback=function() Window:ResetPosition() end})
Tabs.Settings:AddParagraph({
    Title="XANDME / MONOCHROME",
    Content="Right Ctrl opens or closes the menu. Features start OFF and can be enabled individually. Click Unbound on a feature row to assign its key."
})
local manualCursor=false
local cursorModal=create("TextButton",Window.Root,{
    Name="XandMeCursorModal",Text="",Size=UDim2.fromOffset(1,1),
    Position=UDim2.fromOffset(0,0),BackgroundTransparency=1,
    TextTransparency=1,AutoButtonColor=false,Modal=true,Visible=true
})
local cursorRelease=create("TextButton",gui,{
    Name="XandMeManualCursor",Text="",Size=UDim2.fromOffset(1,1),
    BackgroundTransparency=1,TextTransparency=1,AutoButtonColor=false,
    Modal=true,Visible=false
})
local savedMouseBehavior=nil
local savedMouseIcon=nil
local function syncCursor()
    local open=Window.Root.Parent~=nil and Window.Root.Visible
    local release=state.alive and (open or manualCursor)
    cursorModal.Visible=state.alive and open
    cursorRelease.Visible=state.alive and manualCursor and not open
    if release then
        if savedMouseBehavior==nil then
            savedMouseBehavior=UserInputService.MouseBehavior
            savedMouseIcon=UserInputService.MouseIconEnabled
        end
        UserInputService.MouseBehavior=Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled=true
    elseif savedMouseBehavior~=nil then
        if UserInputService.MouseBehavior==Enum.MouseBehavior.Default then
            UserInputService.MouseBehavior=savedMouseBehavior
        end
        if UserInputService.MouseIconEnabled==true then UserInputService.MouseIconEnabled=savedMouseIcon end
        savedMouseBehavior=nil
        savedMouseIcon=nil
    end
end
registerToggle(Tabs.Settings,"ReleaseCursor","Release Cursor Outside Menu",
    "Uses Roblox modal UI; OFF returns control to the native camera.",
    "manualCursor",function(v) manualCursor=v;syncCursor() end)
local menuScale=create("UIScale",Window.Root,{Scale=1})
local openTween=nil
local captureId=nil
local bindings={}
local keyRows={}
local safetyActionId="EmergencyDisable"
local safetyBusy=false
local emergencyDisable
local HttpService=game:GetService("HttpService")
local keyPath="VelionDistrict/xandme-keybinds.json"
local canSave=type(isfolder)=="function" and type(makefolder)=="function" and type(writefile)=="function" and type(readfile)=="function" and type(isfile)=="function"
local function keyAllowed(name)
    if type(name)~="string" or name=="RightControl" or name=="Unknown" or name=="Escape" or name=="Backspace" or name=="Delete" then return false end
    local ok,key=pcall(function() return Enum.KeyCode[name] end)
    return ok and key~=nil and key~=Enum.KeyCode.Unknown
end
local function saveBindings()
    if not canSave then return end
    pcall(function()
        if not isfolder("VelionDistrict") then makefolder("VelionDistrict") end
        writefile(keyPath,HttpService:JSONEncode(bindings))
    end)
end
local function refreshKeyRows()
    for id,row in pairs(keyRows) do
        local value=bindings[id] or "Unbound"
        row:SetDesc(captureId==id and "Press a key... Esc cancels / Backspace clears" or value)
        local toggle=toggles[id]
        if toggle and toggle.SetBindText then toggle:SetBindText(captureId==id and "Press key" or value) end
    end
end
if canSave then
    pcall(function()
        if not isfile(keyPath) then return end
        local data=HttpService:JSONDecode(readfile(keyPath))
        if type(data)~="table" then return end
        local used={}
        local ids=table.clone(toggleOrder)
        ids[#ids+1]=safetyActionId
        for _,id in ipairs(ids) do
            local name=data[id]
            if keyAllowed(name) and not used[name] then bindings[id]=name;used[name]=true end
        end
    end)
end
local keySection=Tabs.Settings:AddSection("Feature shortcuts")
keySection:AddParagraph({Title="Press to bind",Content="Click any row and press a keyboard key (including Numpad). Esc cancels; Backspace/Delete clears. Right Ctrl is reserved."})
for _,id in ipairs(toggleOrder) do
    local featureId=id
    local function beginCapture() captureId=featureId;refreshKeyRows() end
    toggles[featureId]:SetBindCallback(beginCapture)
    keyRows[featureId]=keySection:AddButton({
        Title=toggleTitles[featureId],ButtonText="BIND",
        Description=bindings[featureId] or "Unbound",
        Callback=beginCapture
    })
end
refreshKeyRows()
toggleTitles[safetyActionId]="Emergency Disable"
keyRows[safetyActionId]=keySection:AddButton({
    Title="Emergency Disable",ButtonText="BIND",
    Description=bindings[safetyActionId] or "Unbound",
    Callback=function() captureId=safetyActionId;refreshKeyRows() end
})
keySection:AddButton({Title="Clear all shortcuts",Description="Keeps Right Ctrl reserved.",Callback=function()
    table.clear(bindings);captureId=nil;saveBindings();refreshKeyRows()
end})
connect(UserInputService.InputBegan,function(input,processed)
    if not state.alive or input.UserInputType~=Enum.UserInputType.Keyboard then return end
    local name=input.KeyCode.Name
    if captureId then
        if name=="RightControl" then captureId=nil;refreshKeyRows();return end
        if name=="Escape" then captureId=nil;refreshKeyRows();return end
        if name=="Backspace" or name=="Delete" then
            bindings[captureId]=nil;captureId=nil;saveBindings();refreshKeyRows();return
        end
        if not keyAllowed(name) then return end
        for id,existing in pairs(bindings) do
            if id~=captureId and existing==name then
                Native:Notify({Title="Shortcut conflict",Content="Already assigned to "..toggleTitles[id],Duration=3})
                return
            end
        end
        bindings[captureId]=name
        captureId=nil
        saveBindings();refreshKeyRows()
        return -- assigning a key does not activate its feature
    end
    if processed or UserInputService:GetFocusedTextBox() or name=="RightControl" then return end
    if bindings[safetyActionId]==name and emergencyDisable then emergencyDisable();return end
    if safetyBusy then return end
    for id,key in pairs(bindings) do
        if key==name and toggles[id] then toggles[id]:SetValue(not toggles[id].Value);break end
    end
end)
connect(Window.Root:GetPropertyChangedSignal("Visible"),function()
    local ok,err=pcall(function()
        if not Window.Root.Visible then captureId=nil;refreshKeyRows() end
        if openTween then openTween:Cancel() end
        if Window.Root.Visible then
            menuScale.Scale=.96
            openTween=TweenService:Create(menuScale,TweenInfo.new(.23,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Scale=1})
            openTween:Play()
        else menuScale.Scale=1 end
    end)
    if not ok then runtimeLog.record("menu animation",err);pcall(function() menuScale.Scale=1 end) end
    ok,err=pcall(syncCursor)
    if not ok then runtimeLog.record("cursor",err) end
end)
connect(player.CharacterAdded,function()
    task.defer(function()
        if not state.alive then return end
        local ok,err=pcall(syncCursor)
        if not ok then runtimeLog.record("cursor",err) end
    end)
end)
local function stopCursor()
    manualCursor=false
    state.manualCursor=false
    if openTween then openTween:Cancel() end
    syncCursor()
end
local safetySection=Tabs.Settings:AddSection("Session Safety")
local safetyStatus=safetySection:AddParagraph({Title="Session status",Content="Manual recovery controls only. No moderator detection."})
local function restoreNativeControls(closeMenu)
    local failures={}
    local function attempt(name,fn)
        local ok,err=pcall(fn)
        if not ok then failures[#failures+1]=name..": "..tostring(err):sub(1,100) end
    end
    for _,id in ipairs({"CustomFov","SmoothCamera","SmoothZoom","MoonwalkAD","ReleaseCursor"}) do
        local toggle=toggles[id]
        if toggle then
            state[toggleStateKeys[id]]=false
            attempt(id,function() toggle:SetValue(false) end)
        end
    end
    attempt("camera",cameraController.shutdown)
    attempt("moonwalk",function() setMoonwalk(false) end)
    attempt("collision",function() setNoClip(false) end)
    attempt("speed",function() setSpeed(false) end)
    manualCursor=false
    state.manualCursor=false
    if closeMenu then attempt("menu",function() if Window.Root.Visible then Window:Minimize() end end) end
    attempt("cursor",stopCursor)
    return failures
end
emergencyDisable=function()
    if not state.alive or safetyBusy then return end
    safetyBusy=true
    captureId=nil
    local failures={}
    local function attempt(name,fn)
        local ok,err=pcall(fn)
        if not ok then failures[#failures+1]=name..": "..tostring(err):sub(1,100) end
    end
    -- Reset registered feature state before callbacks; cleanup is independent of UI success.
    for _,id in ipairs(toggleOrder) do
        if toggleStateKeys[id] then state[toggleStateKeys[id]]=false end
    end
    state.roleTracking=false
    state.sceneBlur=false
    for _,id in ipairs(toggleOrder) do
        attempt(id,function() toggles[id]:SetValue(false) end)
    end
    scanGeneration+=1
    attempt("watchers",stopSourceWatchers)
    attempt("object visuals",clearObjectives)
    state.scanProgress="Disabled"
    attempt("player visuals",function()
        for other in pairs(playerVisuals) do removePlayerVisual(other) end
    end)
    alert.Visible=false
    state.inputStatus="Disabled manually"
    attempt("lighting",updateLighting)
    for _,err in ipairs(restoreNativeControls(true)) do failures[#failures+1]=err end
    local message=#failures==0 and "Feature reset requested; native controls restored where supported." or ("Recovery errors: "..table.concat(failures," | "))
    attempt("keybind display",refreshKeyRows)
    attempt("status",function() safetyStatus:SetDesc(message) end)
    safetyBusy=false
    if #failures>0 then warn("[XandMe Safety] "..table.concat(failures," | ")) end
end
safetySection:AddButton({Title="Emergency Disable",Description="Manually turn features off and return to native controls. Your key assignments are kept.",Callback=emergencyDisable})
safetySection:AddButton({Title="Restore Native Controls",Description="Disable camera and movement overrides and close the menu.",Callback=function()
    local failures=restoreNativeControls(true)
    safetyStatus:SetDesc(#failures==0 and "Native control restoration requested." or table.concat(failures," | "))
end})
-- Diagnostics use only this interface's counters and errors.
local diagnosticSection=Tabs.Settings:AddSection("Runtime Diagnostics")
local diagnosticStatus=diagnosticSection:AddParagraph({Title="Runtime Diagnostics",Content="Waiting for local sample..."})
local diagnosticErrors=diagnosticSection:AddParagraph({Title="Local UI Error Log",Content="No local UI errors recorded."})
local function refreshDiagnostics()
    if not state.alive or not Window.Root.Visible then return end
    local count=0
    for _,connection in ipairs(connections) do if connection.Connected then count+=1 end end
    local memory="Unavailable"
    local ok,kb=pcall(function() return collectgarbage("count") end)
    if ok and type(kb)=="number" then memory=string.format("%.1f MiB (Lua heap)",kb/1024) end
    local rows=0
    for _ in pairs(keyRows) do rows+=1 end
    local assigned=0
    for _ in pairs(bindings) do assigned+=1 end
    diagnosticStatus:SetDesc(string.format("Uptime: %.0fs | FPS: %d\nLua memory: %s\nTracked connections: %d | shortcut rows: %d | assigned: %d\nUI errors: %d | retained records: %d",os.clock()-runtimeLog.started,state.fps,memory,count,rows,assigned,runtimeLog.total,#runtimeLog.entries))
    diagnosticErrors:SetDesc(runtimeLog.snapshot())
end
diagnosticSection:AddButton({Title="Reset UI Presentation",Description="Cancel the menu animation, reset scale, cancel key capture and refresh cursor state. Does not change gameplay.",Callback=function()
    local ok,err=pcall(function()
        if openTween then openTween:Cancel();openTween=nil end
        menuScale.Scale=1
        captureId=nil
        refreshKeyRows()
        syncCursor()
    end)
    if not ok then runtimeLog.record("UI presentation",err) end
    pcall(refreshDiagnostics)
end})
diagnosticSection:AddButton({Title="Clear Diagnostic Log",Description="Clear only the local UI error history.",Callback=function()
    runtimeLog.clear()
    pcall(refreshDiagnostics)
end})
connect(RunService.Heartbeat,function()
    if not state.alive or not Window.Root.Visible then return end
    local now=os.clock()
    if now-runtimeLog.lastUpdate<1 then return end
    runtimeLog.lastUpdate=now
    local ok,err=pcall(refreshDiagnostics)
    if not ok then runtimeLog.record("diagnostic display",err) end
    local okCamera,cameraText=pcall(cameraController.status)
    if not okCamera then
        runtimeLog.record("camera status",cameraText)
        cameraText="Camera status unavailable. See Runtime Diagnostics."
    end
    local okDisplay,displayErr=pcall(function() cameraStatusBox:SetDesc(cameraText) end)
    if not okDisplay then runtimeLog.record("camera status display",displayErr) end
end)
-- Use the real logo when the owner supplies a published Roblox image asset ID.
-- A typographic fallback is intentional; no fabricated asset ID.
local function playIntro()
    local intro=create("CanvasGroup",gui,{
        Name="XandMeIntro",Size=UDim2.fromScale(1,1),
        BackgroundColor3=Color3.fromRGB(5,5,5),BackgroundTransparency=0,
        GroupTransparency=0,ZIndex=100
    })
    local asset=environment.XandMeLogoAssetId
    local rawId=type(asset)=="number" and tostring(asset) or type(asset)=="string" and asset or ""
    local id=rawId:match("^rbxassetid://(%d+)$") or rawId:match("^(%d+)$")
    local mark
    if id then
        mark=create("ImageLabel",intro,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.46),Size=UDim2.fromScale(.46,.32),BackgroundTransparency=1,Image="rbxassetid://"..id,ScaleType=Enum.ScaleType.Fit,ImageTransparency=1,ZIndex=101})
        TweenService:Create(mark,TweenInfo.new(.45),{ImageTransparency=0}):Play()
    else
        mark=create("TextLabel",intro,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.46),Size=UDim2.fromScale(.82,.23),BackgroundTransparency=1,Text="XandMe.",Font=Enum.Font.GothamMedium,TextScaled=true,TextColor3=Color3.fromRGB(245,245,245),TextTransparency=1,ZIndex=101})
        create("UITextSizeConstraint",mark,{MaxTextSize=72})
        TweenService:Create(mark,TweenInfo.new(.45),{TextTransparency=0}):Play()
    end
    create("TextLabel",intro,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.64),Size=UDim2.fromOffset(260,20),BackgroundTransparency=1,Text="M O N O C H R O M E",Font=Enum.Font.Gotham,TextSize=11,TextColor3=Color3.fromRGB(155,155,155),ZIndex=101})
    local line=create("Frame",intro,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.70),Size=UDim2.fromOffset(0,1),BackgroundColor3=Color3.fromRGB(245,245,245),BorderSizePixel=0,ZIndex=101})
    TweenService:Create(line,TweenInfo.new(1.05,Enum.EasingStyle.Quint),{Size=UDim2.fromOffset(125,1)}):Play()
    task.delay(1.2,function()
        if not state.alive or not intro.Parent then return end
        local fade=TweenService:Create(intro,TweenInfo.new(.48,Enum.EasingStyle.Quad),{GroupTransparency=1})
        fade:Play()
        fade.Completed:Connect(function()
            if intro.Parent then intro:Destroy() end
        end)
    end)
end
syncCursor()

Tabs.Settings:AddButton({
    Title="Unload Velion Hub",
    Description="Disconnect features and close the native window",
    Callback=function()
        local f=environment.VelionVDCleanup
        if type(f)=="function" then f() end
    end
})
-- Native preferences: persist only non-toggle values. Features always start OFF.
do
    local configStatusBox=Tabs.Settings:AddParagraph({
        Title="Preferences",Content=canSave and "Local keybind and preference storage available." or "Local storage unavailable; settings apply to this session only."
    })
    local prefPath="VelionDistrict/xandme-preferences.json"
    local function savePreferences()
        if not canSave then return end
        local ok,err=pcall(function()
            local data={}
            for id,obj in pairs(controls) do
                if obj.Type=="Slider" or obj.Type=="Dropdown" then data[id]=obj.Value
                elseif obj.Type=="Colorpicker" then
                    local c=obj.Value
                    data[id]=string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5))
                end
            end
            if not isfolder("VelionDistrict") then makefolder("VelionDistrict") end
            writefile(prefPath,HttpService:JSONEncode(data))
        end)
        configStatusBox:SetDesc(ok and "Preferences saved. Feature toggles were not saved." or "Save failed: "..tostring(err):sub(1,120))
    end
    local function loadPreferences()
        if not canSave then return end
        local ok,err=pcall(function()
            if not isfile(prefPath) then return end
            local data=HttpService:JSONDecode(readfile(prefPath))
            if type(data)~="table" then return end
            for id,obj in pairs(controls) do
                local v=data[id]
                if obj.Type=="Slider" and type(v)=="number" then obj:SetValue(v)
                elseif (obj.Type=="Dropdown" or obj.Type=="Colorpicker") and type(v)=="string" then obj:SetValue(v) end
            end
        end)
        if not ok then configStatusBox:SetDesc("Load failed: "..tostring(err):sub(1,120)) end
    end
    Tabs.Settings:AddButton({Title="Save Preferences",Description="Save color, slider and dropdown values, not feature ON/OFF state.",ButtonText="SAVE",Callback=savePreferences})
    Tabs.Settings:AddButton({Title="Load Preferences",Description="Reload saved visual preferences only.",ButtonText="LOAD",Callback=loadPreferences})
    loadPreferences()
    local status=Tabs.Settings:AddParagraph({Title="Native UI health",Content="Static interface setup complete; Roblox runtime is not verified."})
    Tabs.Settings:AddButton({
        Title="Check UI Registration",Description="Count native tabs and controls without enabling any feature.",ButtonText="CHECK",
        Callback=function()
            local count,optionCount=0,0
            for _ in pairs(toggles) do count+=1 end
            for _ in pairs(controls) do optionCount+=1 end
            status:SetDesc(string.format("%d tabs | %d toggles | %d settings | Native monochrome",#Window.Tabs,count,optionCount))
        end
    })
end
Window:SelectTab(1)
Native:Notify({Title="XandMe Native",Content="Right Ctrl: menu. All features start OFF.",Duration=4})

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





-- Polling gameplay data at 4 Hz; UI paragraphs at 2 Hz.
-- FPS sample uses the existing Heartbeat connection (no extra render loop).
local lastTick=0
local lastUI=-1e9
local frameCounter=0
local fpsFrom=os.clock()
connect(RunService.Heartbeat,function()
    if not state.alive then return end
    frameCounter+=1
    local now=os.clock()
    if now-fpsFrom>=1 then
        state.fps=math.floor(frameCounter/math.max(.001,now-fpsFrom)+.5)
        fpsFrom=now
        frameCounter=0
    end
    if now-lastTick<.25 then return end
    lastTick=now
    local char=player.Character
    local root=char and char:FindFirstChild("HumanoidRootPart")
    local closest=math.huge
    local killerName=""
    local list=Players:GetPlayers()
    local knownRoles=0
    state.abilitySignalsObserved=0
    for _,other in ipairs(list) do
        if other~=player then
            local role="Unknown"
            if state.playerESP or state.killerAlert or state.abilityNotify or state.roleTracking then
                role=monitorPlayerRole(other,now)
                if state.abilityNotify then monitorKillerAbility(other,role,now) end
            end
            if role~="Unknown" then knownRoles+=1 end
            if state.playerESP then ensurePlayerVisual(other)
            elseif playerVisuals[other] then removePlayerVisual(other) end
            if state.killerAlert and root then
                if role=="Killer" then
                    local target=other.Character and
                        other.Character:FindFirstChild("HumanoidRootPart")
                    if target then
                        local d=(root.Position-target.Position).Magnitude
                        if d<closest then closest=d;killerName=other.DisplayName end
                    end
                end
            end
        end
    end
    state.trackedPlayers=#list-1
    state.unknownRoles=math.max(0,state.trackedPlayers-knownRoles)
    refreshObjectiveVisibility()
    local danger=state.killerAlert and closest<99
    alert.Visible=danger
    alert.Text=danger and ("KILLER NEARBY: "..killerName
        .." ("..math.floor(closest).." studs)") or ""
    alert.TextColor3=espColors.Killer
    if now-lastUI<.50 then return end
    lastUI=now
    local total=#list
    local near=danger and (killerName.." - "..math.floor(closest).." studs")
        or "Not detected / beyond 99 studs"
    local msg=total.." players  |  "..state.identifiedObjectives.." map objects"
    statusMain:SetDesc(msg)
    statusKiller:SetDesc(near)
    local team=player.Team and player.Team.Name:lower() or ""
    local lobby=(team:find("lobby",1,true)
        or team:find("spectator",1,true))~=nil
    statusNext:SetDesc(state.nextKiller
        and (lobby and estimateNextKiller() or "Available while in lobby")
        or "Disabled")
    local skill=state.skillMonitor and checkSkillUi() or "Monitor disabled"
    statusSkill:SetDesc(skill)
    objectStatus:SetDesc(state.scanProgress..
        " | "..state.identifiedObjectives.." cached objectives")
    itemInfo:SetDesc("World item markers: "..state.worldItemsFound..
        " | Character equipped Tool names: "..
        (state.survivorItemsESP and "ON" or "OFF")..
        " | No access to unreplicated inventories")
    progressStatus:SetDesc("Units: "..state.progressScale..
        " | Unknown/ambiguous visible generators: "..state.progressUnknown..
        " | Percentages are shown only with recognized numeric scales")
    abilityStatus:SetDesc(state.abilityLast..
        " | Observed ability signals: "..state.abilitySignalsObserved..
        " | Notifications: "..state.abilityNotificationCount)
    roleStatus:SetDesc("Tracked: "..state.trackedPlayers..
        " | Unknown: "..state.unknownRoles..
        " | Role changes: "..state.roleTransitions..
        " | Latest: "..state.lastRoleTransition)
    perfStatus:SetDesc(string.format(
        "Map: %s | Interactables: %s | scan: %d ms\n"
        .."Scanned Map: %d / Interactables: %d | cache: %d\n"
        .."Labels: %d/%d | highlights: %d/%d | FPS: %d",
        currentMap and currentMap.Name or "not loaded",
        activeInteractables and activeInteractables.Name or "not loaded",
        state.scanDurationMs,state.scanMapCount,
        state.scanInteractableCount,state.scanCandidates,
        state.visibleLabels,state.maxWorldLabels,
        state.visibleHighlights,state.maxWorldHighlights,state.fps))
    skillStatus:SetDesc(skill)
    inputStatus:SetDesc(state.inputStatus)
    if state.moonwalk then
        local left=UserInputService:IsKeyDown(Enum.KeyCode.A)
        local right=UserInputService:IsKeyDown(Enum.KeyCode.D)
        state.moonwalkStatus="Manual input monitor only (no animation) | A: "..(left and "DOWN" or "up").." | D: "..(right and "DOWN" or "up")
    end
    moonwalkStatusBox:SetDesc(state.moonwalkStatus)
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    local velocity=root and root:IsA("BasePart") and root.AssemblyLinearVelocity or Vector3.zero
    local horizontal=Vector3.new(velocity.X,0,velocity.Z).Magnitude
    local pingText="unavailable"
    local pingOK,ping=pcall(function() return player:GetNetworkPing() end)
    if pingOK and type(ping)=="number" then pingText=string.format("%.0f ms (one-way estimate)",ping*1000) end
    movementDiagnostics:SetDesc(string.format("FPS: %d | Network: %s\nNative WalkSpeed: %.1f | Horizontal velocity: %.1f studs/s\nNo movement override is applied by NoClip or Speed Assist.",state.fps,pingText,hum and hum.WalkSpeed or 0,horizontal))
end)

-- No automated gameplay input in this version.
connect(Players.PlayerRemoving,function(leaving)
    removePlayerVisual(leaving)
    roleCache[leaving]=nil
    abilityCache[leaving]=nil
end)
connect(Lighting.ChildAdded,function()
    if state.alive and (state.fullbright or state.noFog) then
        task.defer(updateLighting)
    end
end)

local function cleanup()
    if not state.alive then return end
    state.alive=false
    local function attempt(name,fn)
        local ok,err=pcall(fn)
        if not ok then
            runtimeLog.record("cleanup / "..name,err)
            warn("[XandMe cleanup] "..name..": "..tostring(err))
        end
    end
    attempt("moonwalk",function() setMoonwalk(false) end)
    scanGeneration+=1
    attempt("source watchers",stopSourceWatchers)
    for _,conn in ipairs(connections) do
        attempt("disconnect",function() conn:Disconnect() end)
    end
    table.clear(connections)
    for other in pairs(playerVisuals) do
        attempt("player visual",function() removePlayerVisual(other) end)
    end
    for obj,item in pairs(objectiveVisuals) do
        if item.gui then attempt("object label",function() item.gui:Destroy() end) end
        if item.highlight then attempt("object highlight",function() item.highlight:Destroy() end) end
        objectiveVisuals[obj]=nil
    end
    attempt("collision",function() setNoClip(false) end)
    state.fullbright=false
    state.noFog=false
    attempt("lighting",updateLighting)
    if state.speed then attempt("speed",function() setSpeed(false) end) end
    attempt("camera",cameraController.shutdown)
    attempt("cursor",stopCursor)
    attempt("overlay",function() gui:Destroy() end)
    attempt("interface",function() Native:Destroy() end)
    if environment.VelionVDCleanup==cleanup then
        environment.VelionVDCleanup=nil
    end
end
environment.VelionVDCleanup=cleanup
playIntro()
print("[XandMe V5.3] Read-only camera diagnostics; Roblox runtime not tested.")
