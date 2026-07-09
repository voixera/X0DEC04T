--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v3.0.0 - Border RP (WindUI - Stable)
-- No metatable hooks, no newcclosure, pure Roblox API
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_BRP_v300"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.2)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("Starting v3.0.0 WindUI...")

-- Load WindUI
local WindUI
local ok, err = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok or not WindUI then
    warn("[X0DEC04T] WindUI failed: " .. tostring(err))
    return
end
Log("WindUI loaded")

local HUB = { Name="X0DEC04T Hub", Game="Border RP", Version="3.0.0" }

--━ CONNECTION MANAGER
local CM = { _list = {} }
function CM:Add(sig, cb)
    if not sig then return end
    local ok, c = pcall(function() return sig:Connect(cb) end)
    if ok and c then table.insert(self._list, c); return c end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

--━ REMOTES
local RemotesFolder
pcall(function() RemotesFolder = ReplicatedStorage:WaitForChild("__remotes", 5) end)

local function GetRemote(path)
    if not RemotesFolder then return nil end
    local c = RemotesFolder
    for seg in string.gmatch(path, "[^%.]+") do
        c = c:FindFirstChild(seg); if not c then return nil end
    end
    return c
end

local BRP = {
    SellSmuggledGoods       = GetRemote("SmuggleService.SellSmuggledGoods"),
    LaunderBriefcase        = GetRemote("SmuggleService.LaunderBriefcase"),
    SpawnVehicleFromSpawner = GetRemote("VehicleSpawnerService.SpawnVehicleFromSpawner"),
    PurchaseVehicle         = GetRemote("VehicleSpawnerService.PurchaseVehicle"),
    PurchaseWorldItem       = GetRemote("WorldBuyableItemService.PurchaseWorldBuyableItem"),
    Detain                  = GetRemote("Handcuffs.Detain"),
    Jail                    = GetRemote("Handcuffs.Jail"),
    BatonSwing              = GetRemote("Baton.Swing"),
    UnstuckVehicle          = GetRemote("VehicleService.UnstuckVehicle"),
    ApplyRollbackCFrame     = GetRemote("AntiTp.ApplyRollbackCFrame"),
}

local remoteCount = 0
for _, v in pairs(BRP) do if v then remoteCount = remoteCount + 1 end end
Log("Loaded " .. remoteCount .. " remotes")

local BRP_PATHS = {
    NPC = Workspace:FindFirstChild("NPC"),
    Vehicles = Workspace:FindFirstChild("Vehicles"),
    LaunderTrigger = nil,
    WorldBuyableItems = Workspace:FindFirstChild("WorldBuyableItems"),
    VehicleSpawners = nil,
}

pcall(function()
    local lp = Workspace:FindFirstChild("LaunderPrompts")
    if lp then BRP_PATHS.LaunderTrigger = lp:FindFirstChild("LaunderTrigger") end
end)

for _, obj in ipairs(Workspace:GetChildren()) do
    local n = obj.Name:lower()
    if n:find("spawner") or n:find("kendaraan") then
        BRP_PATHS.VehicleSpawners = obj
        Log("Spawner folder: " .. obj.Name)
        break
    end
end

--━ STATE
local State = {
    -- Smuggler
    Smuggler_AutoLoop = false,
    Smuggler_JobsDone = 0,
    Smuggler_UseRemotes = true,
    Smuggler_AutoLaunder = true,
    Smuggler_ItemName = "Fake Diamond Ring",
    Smuggler_SellerName = "Seller4",
    Smuggler_VehicleName = "Camry6",
    Smuggler_BuyRetries = 2,
    Smuggler_SellRetries = 8,
    Smuggler_Delay = 1,
    Smuggler_DebugMode = true,
    Smuggler_AutoEquip = true,
    Smuggler_EquipAll = true,
    Smuggler_RemoveTires = true,
    Smuggler_SpawnCar = true,
    Smuggler_CurrentCar = nil,
    Smuggler_CarTPMethod = "WeldTP",
    
    -- TP
    TPStrategy = "Tween",
    TweenSpeed = 200,
    TweenNoclip = true,
    AntiTpBypass = true,
    
    -- Positions
    POS_Shop = Vector3.new(6823.57, 17.40, -20.00),
    POS_Laundry = Vector3.new(6804.78, 17.43, -34.70),
    POS_CarSpawner = Vector3.new(6840, 17, -30),
    
    -- Car
    CarSpeed = 0,
    SpeedHack = false,
    SpeedHackConn = nil,
    SpeedHackValue = 500,
    FlyActive = false,
    FlyConn = nil,
    GodMode = false,
    NoclipConn = nil,
    NoClip = false,
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
    
    -- Police
    Police_AutoAim = false,
    Police_AutoFire = false,
    Police_AutoArrest = false,
    Police_AimPart = "Head",
    Police_AimFOV = 150,
    Police_AimSmooth = 1,
    Police_TargetWanted = true,
    Police_MinWantedLevel = 1,
    Police_TargetAll = false,
    Police_ShowFOV = true,
    Police_FOVCircle = nil,
    Police_AimConn = nil,
    Police_FireConn = nil,
    Police_ArrestConn = nil,
    Police_CurrentTarget = nil,
    
    -- ESP
    ESP_Players = false,
    ESP_Wanted = false,
    ESP_Police = false,
    ESP_ShowName = true,
    ESP_ShowDist = true,
    ESP_MaxDist = 800,
    ESPCache = {},
    Color_Player = Color3.fromRGB(60,220,255),
    Color_Wanted = Color3.fromRGB(255,50,50),
    Color_Police = Color3.fromRGB(60,120,255),
    
    -- Visuals
    FullBright = false,
    NoFog = false,
    FOV = 70,
    AntiAFK = true,
    MutedSounds = {},
    LightBackup = {},
    
    -- Misc
    TP_Target = "",
    RemoteName = "",
    RemoteArg = "",
}

--━ HELPERS
local function GetChar() return LocalPlayer.Character end
local function GetHRP() local ch = GetChar(); return ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")) end
local function GetHuman() local ch = GetChar(); return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p = CoreGui; pcall(function() if gethui then p = gethui() end end); return p end

local function GetPlayerCar()
    local ch = GetChar(); if not ch then return nil end
    for _, seat in ipairs(Workspace:GetDescendants()) do
        if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) and seat.Occupant and seat.Occupant.Parent == ch then
            return seat:FindFirstAncestorOfClass("Model"), seat
        end
    end
    return nil
end

local function GetVehicleSeat() local c = GetPlayerCar(); return c and (c:FindFirstChildOfClass("VehicleSeat") or c:FindFirstChildWhichIsA("VehicleSeat", true)) end
local function GetCarRoot() local c = GetPlayerCar(); return c and (c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")) end
local function GetWantedLevel(p) return tonumber(p and p:GetAttribute("WantedLevel")) or 0 end
local function IsWanted(p) return GetWantedLevel(p) >= (State.Police_MinWantedLevel or 1) end
local function GetRank(p) return tostring(p and p:GetAttribute("CurrentRankName") or "Unknown") end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTITP - HIDE METHOD (SAFEST)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AntiTp = {
    enabled = false,
    hidden = false,
    origParent = nil,
    holds = 0,
    blocked = 0,
}

function AntiTp.Enable() AntiTp.enabled = true end
function AntiTp.Disable() AntiTp.enabled = false; AntiTp.Release(true) end

function AntiTp.Hold()
    if not AntiTp.enabled then return end
    AntiTp.holds = AntiTp.holds + 1
    if not AntiTp.hidden and BRP.ApplyRollbackCFrame then
        local r = BRP.ApplyRollbackCFrame
        if r and r.Parent then
            AntiTp.origParent = r.Parent
            local ok = pcall(function() r.Parent = nil end)
            if ok then
                AntiTp.hidden = true
                AntiTp.blocked = AntiTp.blocked + 1
                if State.Smuggler_DebugMode then Log("[AntiTp] Blocked #" .. AntiTp.blocked) end
            end
        end
    end
end

function AntiTp.Release(force)
    if not force then
        AntiTp.holds = math.max(0, AntiTp.holds - 1)
        if AntiTp.holds > 0 then return end
    else
        AntiTp.holds = 0
    end
    if AntiTp.hidden then
        local r = BRP.ApplyRollbackCFrame
        if r and AntiTp.origParent then
            pcall(function() r.Parent = AntiTp.origParent end)
        end
        AntiTp.hidden = false
    end
end

-- Safety watchdog
task.spawn(function()
    while true do
        task.wait(6)
        if AntiTp.hidden and AntiTp.holds == 0 then AntiTp.Release(true) end
    end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TELEPORT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local SmartTP = {}
local _twNoclip = nil

local function EnableNoclip()
    if _twNoclip then return end
    _twNoclip = RunService.Stepped:Connect(function()
        local ch = GetChar()
        if ch then for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide = false end) end
        end end
    end)
end

local function DisableNoclip()
    if _twNoclip then pcall(function() _twNoclip:Disconnect() end); _twNoclip = nil end
end

function SmartTP.Instant(pos, yOff)
    if not pos then return false end
    local hrp = GetHRP(); if not hrp then return false end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOff or 3, 0)) end)
    task.wait(0.3)
    return true
end

function SmartTP.Tween(pos, yOff)
    if not pos then return false end
    local hrp = GetHRP(); if not hrp then return false end
    local hum = GetHuman()
    local targetPos = pos + Vector3.new(0, yOff or 3, 0)
    local totalDist = (targetPos - hrp.Position).Magnitude
    
    if totalDist < 5 then
        pcall(function() hrp.CFrame = CFrame.new(targetPos) end)
        task.wait(0.1)
        return true
    end
    
    local wasPlatform = false
    if hum then wasPlatform = hum.PlatformStand; pcall(function() hum.PlatformStand = true end) end
    if State.TweenNoclip then EnableNoclip() end
    
    local speed = math.max(State.TweenSpeed or 200, 50)
    local duration = math.clamp(totalDist / speed, 0.2, 15)
    
    if State.Smuggler_DebugMode then Log(string.format("[Tween] %.0f studs / %.2fs", totalDist, duration)) end
    
    local ok, tween = pcall(function()
        return TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    end)
    
    if ok and tween then
        pcall(function() tween:Play() end)
        local t0 = tick()
        while tick() - t0 < duration + 1 do
            task.wait(0.1)
            if not hrp or not hrp.Parent then break end
        end
        pcall(function() tween:Cancel() end)
    end
    
    local fhrp = GetHRP()
    if fhrp then pcall(function() fhrp.CFrame = CFrame.new(targetPos) end) end
    if hum and hum.Parent then pcall(function() hum.PlatformStand = wasPlatform end) end
    DisableNoclip()
    task.wait(0.2)
    return true
end

function SmartTP.Go(pos, yOff)
    if State.AntiTpBypass then AntiTp.Hold() end
    local result
    if (State.TPStrategy or "Tween") == "Instant" then
        result = SmartTP.Instant(pos, yOff)
    else
        result = SmartTP.Tween(pos, yOff)
    end
    if State.AntiTpBypass then
        task.delay(2, function() pcall(AntiTp.Release) end)
    end
    return result
end

function SmartTP.DirectVehicle(car, targetPos, faceCFrame)
    if not car then return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then return false end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
    local cf = faceCFrame or CFrame.new(targetPos)
    pcall(function()
        if car:IsA("Model") then car:PivotTo(cf) else root.CFrame = cf end
    end)
    task.wait(0.3)
    return true
end

function SmartTP.WeldVehicle(car, targetPos, faceCFrame)
    if not car then return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then return false end
    
    local hum = GetHuman()
    local seated = false
    if hum then
        for _, obj in ipairs(car:GetDescendants()) do
            if obj:IsA("VehicleSeat") and obj.Occupant == hum then seated = true; break end
        end
    end
    if not seated then
        Log("[WeldTP] Not seated, using direct")
        AntiTp.Hold()
        local r = SmartTP.DirectVehicle(car, targetPos, faceCFrame)
        task.delay(3, function() pcall(AntiTp.Release) end)
        return r
    end
    
    AntiTp.Hold()
    
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
    
    local targetCF = faceCFrame or CFrame.new(targetPos)
    local startCF = root.CFrame
    local totalDist = (targetCF.Position - startCF.Position).Magnitude
    
    if State.Smuggler_DebugMode then Log(string.format("[WeldTP] %.0f studs", totalDist)) end
    
    local chunks = math.max(3, math.ceil(totalDist / 80))
    for i = 1, chunks do
        local alpha = i / chunks
        local stepCF = startCF:Lerp(targetCF, alpha)
        pcall(function()
            if car:IsA("Model") then car:PivotTo(stepCF) else root.CFrame = stepCF end
        end)
        for _, p in ipairs(car:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        task.wait(0.08)
    end
    
    pcall(function()
        if car:IsA("Model") then car:PivotTo(targetCF) else root.CFrame = targetCF end
    end)
    task.wait(0.3)
    
    task.delay(3, function() pcall(AntiTp.Release) end)
    return true
end

function SmartTP.TweenVehicle(car, targetPos, faceCFrame)
    if not car then return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then return false end
    
    AntiTp.Hold()
    
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
    
    local targetCF = faceCFrame or CFrame.new(targetPos)
    local totalDist = (targetCF.Position - root.Position).Magnitude
    local speed = math.max(State.TweenSpeed or 200, 50)
    local duration = math.clamp(totalDist / speed, 0.2, 15)
    
    local ok, tween = pcall(function()
        return TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
    end)
    if ok and tween then
        pcall(function() tween:Play() end)
        local t0 = tick()
        while tick() - t0 < duration + 1 do task.wait(0.1) end
        pcall(function() tween:Cancel() end)
    end
    
    pcall(function()
        if car:IsA("Model") then car:PivotTo(targetCF) else root.CFrame = targetCF end
    end)
    task.wait(0.2)
    
    task.delay(3, function() pcall(AntiTp.Release) end)
    return true
end

function SmartTP.CarTP(car, targetPos, faceCFrame)
    local m = State.Smuggler_CarTPMethod or "WeldTP"
    if m == "WeldTP" then return SmartTP.WeldVehicle(car, targetPos, faceCFrame) end
    if m == "TweenVehicle" then return SmartTP.TweenVehicle(car, targetPos, faceCFrame) end
    AntiTp.Hold()
    local r = SmartTP.DirectVehicle(car, targetPos, faceCFrame)
    task.delay(3, function() pcall(AntiTp.Release) end)
    return r
end

--━ ESP
local ESP = {}
function ESP.Clear(o) local c = State.ESPCache[o]; if not c then return end; for _, i in pairs(c) do if typeof(i)=="Instance" and i.Parent then pcall(function() i:Destroy() end) end end; State.ESPCache[o]=nil end
function ESP.ClearAll() for o in pairs(State.ESPCache) do ESP.Clear(o) end; State.ESPCache={} end
function ESP.AddTarget(a, model, label, color)
    if State.ESPCache[a] then ESP.Clear(a) end
    local hl = Instance.new("Highlight"); hl.Adornee=model or a; hl.FillColor=color; hl.OutlineColor=Color3.new(1,1,1); hl.FillTransparency=0.5; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=GuiParent()
    local bb = Instance.new("BillboardGui"); bb.Adornee=a; bb.Size=UDim2.new(0,260,0,55); bb.StudsOffset=Vector3.new(0,4,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.MaxDistance=State.ESP_MaxDist; bb.Parent=GuiParent()
    local nl = Instance.new("TextLabel",bb); nl.Size=UDim2.new(1,0,0.6,0); nl.BackgroundTransparency=1; nl.Text=tostring(label); nl.TextColor3=color; nl.TextStrokeTransparency=0; nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Visible=State.ESP_ShowName
    local dl = Instance.new("TextLabel",bb); dl.Size=UDim2.new(1,0,0.4,0); dl.Position=UDim2.new(0,0,0.6,0); dl.BackgroundTransparency=1; dl.Text="0m"; dl.TextColor3=Color3.fromRGB(220,220,220); dl.TextStrokeTransparency=0; dl.Font=Enum.Font.Gotham; dl.TextSize=12; dl.Visible=State.ESP_ShowDist
    State.ESPCache[a]={hl=hl,bb=bb,nl=nl,dl=dl,hrp=a}
end
function ESP.UpdateDist() local hrp=GetHRP(); if not hrp then return end; for _,c in pairs(State.ESPCache) do if c.dl and c.hrp and c.hrp.Parent then c.dl.Text=math.floor((c.hrp.Position-hrp.Position).Magnitude).."m" end end end
function ESP.ScanPlayers()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local wanted=IsWanted(p); local wl=GetWantedLevel(p); local rank=GetRank(p)
                local isPolice=rank:lower():find("police") or rank:lower():find("cop") or rank:lower():find("agent")
                local show=false; local color=State.Color_Player; local label=p.Name.." ["..rank.."]"
                if State.ESP_Wanted and wanted then show=true;color=State.Color_Wanted;label=p.Name.." [W"..wl.."]"
                elseif State.ESP_Police and isPolice then show=true;color=State.Color_Police;label="[P] "..p.Name
                elseif State.ESP_Players then show=true; if wanted then color=State.Color_Wanted;label=p.Name.." [W"..wl.."]" end end
                if show and not State.ESPCache[hrp] then ESP.AddTarget(hrp,p.Character,label,color) elseif not show then ESP.Clear(hrp) end
            end
        end
    end
end
function ESP.RefreshAll() for o in pairs(State.ESPCache) do if not o or not o.Parent then ESP.Clear(o) end end; ESP.ScanPlayers() end
task.spawn(function() while task.wait(2) do pcall(ESP.RefreshAll) end end)
CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDist) end)

--━ CAR
local Car = {}
function Car.ApplySpeed() local s=GetVehicleSeat(); if s then pcall(function() s.MaxSpeed=100+(tonumber(State.CarSpeed)or 0) end) end end
function Car.SetSpeedHack(e)
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn=nil end
    if e then State.SpeedHackConn=RunService.Heartbeat:Connect(function() local s=GetVehicleSeat(); if s then pcall(function() s.MaxSpeed=tonumber(State.SpeedHackValue)or 500 end) end end) end
end
function Car.Flip() local c=GetPlayerCar(); if c then local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then pcall(function() r.CFrame=CFrame.new(r.Position) end) end end end
function Car.Boost() local r=GetCarRoot(); if not r then return end; local bv=Instance.new("BodyVelocity"); bv.Velocity=r.CFrame.LookVector*400; bv.MaxForce=Vector3.new(math.huge,0,math.huge); bv.Parent=r; game:GetService("Debris"):AddItem(bv,0.3) end
function Car.SetNoClip(e)
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn=nil end
    if e then State.NoclipConn=RunService.Stepped:Connect(function()
        local car=GetPlayerCar(); if car then for _,p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end end end
        local ch=GetChar(); if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end end end
    end) end
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local h=GetHuman()
    if e then
        if h then pcall(function() h.PlatformStand=true end) end; local hrp=GetHRP()
        if hrp then
            local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=9e4; bg.CFrame=hrp.CFrame; bg.Parent=hrp; bg.Name="__FG"
            local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=9e4; bv.Parent=hrp; bv.Name="__FV"
            State.FlyConn=RunService.RenderStepped:Connect(function()
                local h2=GetHRP(); if not h2 then return end; local bg2=h2:FindFirstChild("__FG"); local bv2=h2:FindFirstChild("__FV"); if not bg2 or not bv2 then return end
                local spd=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 150 or 70; local cf=Camera.CFrame; local mv=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end; if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end; if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.yAxis end; if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.yAxis end
                bv2.Velocity=mv*spd; bg2.CFrame=cf
            end)
        end
    else
        if h then pcall(function() h.PlatformStand=false end) end; local hrp=GetHRP()
        if hrp then local a=hrp:FindFirstChild("__FG"); local b=hrp:FindFirstChild("__FV"); if a then a:Destroy() end; if b then b:Destroy() end end
    end
end
function Car.SetGod(e) local h=GetHuman(); if h then if e then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) else pcall(function() h.MaxHealth=100; h.Health=100 end) end end end
function Car.TeleportToPlayer(name)
    if not name or name=="" then return end; local t=Players:FindFirstChild(name); if not t or not t.Character then return end
    local th=t.Character:FindFirstChild("HumanoidRootPart"); if not th then return end; SmartTP.Go(th.Position+Vector3.new(0,0,4),0)
end

--━ SPAWNER
local function FindAllSpawners()
    local spawners = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            local n = (obj.Name or ""):lower()
            local action = tostring(obj.ActionText or ""):lower()
            local object = tostring(obj.ObjectText or ""):lower()
            if n:find("spawn") or n:find("kendaraan") or n:find("munculkan")
               or action:find("spawn") or action:find("kendaraan") or action:find("munculkan")
               or object:find("spawner") or object:find("kendaraan") or object:find("vehicle") then
                local part = obj.Parent
                while part and not part:IsA("BasePart") do part = part.Parent end
                local container = obj.Parent
                while container and container.Parent ~= Workspace do
                    if container:IsA("Model") or container:IsA("Folder") then break end
                    container = container.Parent
                end
                table.insert(spawners, {
                    prompt = obj, part = part,
                    container = container or obj.Parent,
                    position = part and part.Position or Vector3.zero,
                })
            end
        end
    end
    return spawners
end

local function FindNearestSpawner()
    local hrp = GetHRP(); if not hrp then return nil end
    local spawners = FindAllSpawners()
    local best, bestDist = nil, math.huge
    for _, s in ipairs(spawners) do
        local d = (s.position - hrp.Position).Magnitude
        if d < bestDist then best = s; bestDist = d end
    end
    return best
end

local function GetSellerNames()
    local names={}
    if BRP_PATHS.NPC then for _,npc in ipairs(BRP_PATHS.NPC:GetChildren()) do if npc.Name:lower():find("seller") then table.insert(names,npc.Name) end end end
    if #names==0 then table.insert(names,"Seller4") end
    return names
end

local function GetBuyableItemNames()
    local names={}
    if BRP_PATHS.WorldBuyableItems then for _,item in ipairs(BRP_PATHS.WorldBuyableItems:GetChildren()) do table.insert(names,item.Name) end end
    if #names==0 then table.insert(names,"Fake Diamond Ring") end
    return names
end

--━ SMUGGLER
local Smuggler = {}

function Smuggler.FirePrompt(prompt)
    if not prompt then return false end
    local ok = pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
    if State.Smuggler_DebugMode then Log("Prompt [" .. tostring(ok) .. "] " .. prompt:GetFullName()) end
    return ok
end

function Smuggler.EquipTool(toolName)
    local ch=GetChar(); local bp=LocalPlayer:FindFirstChild("Backpack"); if not ch or not bp then return false end
    if ch:FindFirstChild(toolName) then return true end
    local tool=bp:FindFirstChild(toolName); if tool then local h=GetHuman(); if h then pcall(function() h:EquipTool(tool) end); task.wait(0.3); return true end end
    return false
end

function Smuggler.EquipAll(toolName)
    local bp=LocalPlayer:FindFirstChild("Backpack"); if not bp then return 0 end; local h=GetHuman(); if not h then return 0 end; local c=0
    for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name==toolName then pcall(function() h:EquipTool(t) end); c=c+1; task.wait(0.15) end end
    return c
end

function Smuggler.GetBuyPrompt(itemName)
    itemName=itemName or State.Smuggler_ItemName; if not BRP_PATHS.WorldBuyableItems then return nil end
    local item=BRP_PATHS.WorldBuyableItems:FindFirstChild(itemName); if not item then return nil end
    for _,obj in ipairs(item:GetDescendants()) do if obj:IsA("ProximityPrompt") then return obj, item end end
    return nil, item
end

function Smuggler.GetItemPos(itemName)
    itemName=itemName or State.Smuggler_ItemName; if not BRP_PATHS.WorldBuyableItems then return nil end
    local item=BRP_PATHS.WorldBuyableItems:FindFirstChild(itemName); if not item then return nil end
    local h=item:FindFirstChild("Handle"); if h and h:IsA("BasePart") then return h.Position end
    local p=item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart",true); return p and p.Position
end

function Smuggler.GetSellPrompt(sellerName)
    if not BRP_PATHS.NPC then return nil end
    local seller=BRP_PATHS.NPC:FindFirstChild(sellerName or "Seller4")
    if not seller then
        for _,npc in ipairs(BRP_PATHS.NPC:GetChildren()) do
            if npc.Name:lower():find("seller") then local hrp=npc:FindFirstChild("HumanoidRootPart"); if hrp then local p=hrp:FindFirstChild("SellSmuggledGoodsPrompt"); if p then return p,npc end end end
        end
        return nil
    end
    local hrp=seller:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    return hrp:FindFirstChild("SellSmuggledGoodsPrompt"), seller
end

function Smuggler.GetLaunderPrompt()
    if BRP_PATHS.LaunderTrigger then local pp=BRP_PATHS.LaunderTrigger:FindFirstChild("PromptPart"); if pp then return pp:FindFirstChild("LaunderBriefcasePrompt") end end
end

function Smuggler.BuyItem()
    Log("[1] Buy " .. State.Smuggler_ItemName)
    local prompt, item = Smuggler.GetBuyPrompt(State.Smuggler_ItemName)
    if not item then Log("[1] Not found"); return false end
    local pos = Smuggler.GetItemPos(State.Smuggler_ItemName)
    if pos then SmartTP.Go(pos, 3) end
    if not prompt then Log("[1] No prompt"); return false end
    for i = 1, State.Smuggler_BuyRetries or 2 do Smuggler.FirePrompt(prompt); task.wait(0.4) end
    Log("[1] Done"); return true
end

function Smuggler.SpawnCar()
    local vehicleName = State.Smuggler_VehicleName
    if vehicleName == "" or not vehicleName then vehicleName = "Camry6" end
    Log("[2] Spawn " .. vehicleName)

    local spawner = FindNearestSpawner()
    if spawner then
        Log("[2] Spawner at " .. tostring(spawner.position))
        SmartTP.Go(spawner.position, 3)
        task.wait(0.6)
        spawner = FindNearestSpawner()
    else
        SmartTP.Go(State.POS_CarSpawner, 3); task.wait(0.8)
        spawner = FindNearestSpawner()
    end

    local existingCars = {}
    if BRP_PATHS.Vehicles then for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do existingCars[v] = true end end

    local newCar = nil
    local addedConn
    if BRP_PATHS.Vehicles then
        addedConn = BRP_PATHS.Vehicles.ChildAdded:Connect(function(child)
            if not existingCars[child] then newCar = child; Log("[2] NEW: " .. child.Name) end
        end)
    end

    if spawner and spawner.prompt then Smuggler.FirePrompt(spawner.prompt); task.wait(0.5) end

    if BRP.SpawnVehicleFromSpawner then
        local cont = spawner and spawner.container or nil
        local part = spawner and spawner.part or nil
        local argSets = {
            {vehicleName},
            {cont, vehicleName},
            {vehicleName, cont},
            {part, vehicleName},
            {vehicleName, part},
            {cont},
        }
        for i, args in ipairs(argSets) do
            if newCar then break end
            pcall(function()
                if BRP.SpawnVehicleFromSpawner:IsA("RemoteEvent") then
                    BRP.SpawnVehicleFromSpawner:FireServer(unpack(args))
                else
                    BRP.SpawnVehicleFromSpawner:InvokeServer(unpack(args))
                end
            end)
            task.wait(0.5)
        end
    end

    local t0 = tick()
    while tick() - t0 < 5 do if newCar then break end; task.wait(0.1) end
    if addedConn then pcall(function() addedConn:Disconnect() end) end

    if not newCar and BRP_PATHS.Vehicles then
        for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do
            if not existingCars[v] then newCar = v; break end
        end
    end

    if not newCar then
        local myHRP = GetHRP()
        if myHRP and BRP_PATHS.Vehicles then
            local bd = math.huge
            for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do
                local r = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                if r then local d = (r.Position - myHRP.Position).Magnitude; if d < bd and d < 100 then bd = d; newCar = v end end
            end
        end
    end

    if newCar then
        local t1 = tick()
        while tick() - t1 < 3 do if newCar.PrimaryPart or newCar:FindFirstChildWhichIsA("BasePart") then break end; task.wait(0.1) end
        State.Smuggler_CurrentCar = newCar
        Log("[2] Ready: " .. newCar.Name)
        return newCar
    end

    Log("[2] FAILED")
    return nil
end

function Smuggler.SitInCar(car)
    if not car or not car.Parent then return false end
    if GetPlayerCar() == car then return true end
    local seat = nil
    for a = 1, 10 do
        for _, obj in ipairs(car:GetDescendants()) do
            if obj:IsA("VehicleSeat") and not obj.Occupant then seat = obj; break end
        end
        if seat then break end; task.wait(0.2)
    end
    if not seat then Log("[3] No seat"); return false end
    local hum, hrp = GetHuman(), GetHRP()
    if not hum or not hrp then return false end
    for a = 1, 3 do
        pcall(function() hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(0.2); seat:Sit(hum) end)
        task.wait(0.6)
        if GetPlayerCar() == car then Log("[3] Seated #" .. a); return true end
    end
    return false
end

function Smuggler.RemoveTires(car)
    if not car then return end
    local removed = 0
    for _, obj in ipairs(car:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") and (n:find("wheel") or n:find("tire") or n:find("tyre")) then
            pcall(function() obj:Destroy() end); removed = removed + 1
        end
    end
    Log("[4] Removed " .. removed .. " tires")
end

function Smuggler.TeleportCarToSeller(car)
    if not car then return false end
    local _, seller = Smuggler.GetSellPrompt(State.Smuggler_SellerName)
    if not seller then return false end
    local sHRP = seller:FindFirstChild("HumanoidRootPart"); if not sHRP then return false end
    local sellerPos = sHRP.Position
    local carRoot = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart"); if not carRoot then return false end
    local dir = (sellerPos - carRoot.Position); if dir.Magnitude > 0 then dir = dir.Unit else dir = Vector3.new(1,0,0) end
    local targetPos = sellerPos - dir * 6
    targetPos = Vector3.new(targetPos.X, sellerPos.Y + 3, targetPos.Z)
    local carCF = CFrame.lookAt(targetPos, sellerPos)
    SmartTP.CarTP(car, targetPos, carCF)
    task.wait(0.5)
    return true
end

function Smuggler.FireSell()
    if State.Smuggler_AutoEquip then
        if State.Smuggler_EquipAll then Smuggler.EquipAll(State.Smuggler_ItemName) else Smuggler.EquipTool(State.Smuggler_ItemName) end
        task.wait(0.4)
    end
    local prompt = Smuggler.GetSellPrompt(State.Smuggler_SellerName)
    for i = 1, State.Smuggler_SellRetries or 8 do
        if prompt then Smuggler.FirePrompt(prompt) end
        if State.Smuggler_UseRemotes and BRP.SellSmuggledGoods then pcall(function() BRP.SellSmuggledGoods:FireServer() end) end
        task.wait(0.4)
    end
end

function Smuggler.TeleportCarToLaundry(car)
    if not car then SmartTP.Go(State.POS_Laundry, 3); task.wait(0.6); return end
    local tp = State.POS_Laundry + Vector3.new(0, 3, 0)
    SmartTP.CarTP(car, tp, CFrame.new(tp))
    task.wait(0.5)
end

function Smuggler.FireLaunder()
    if not State.Smuggler_AutoLaunder then return end
    local prompt = Smuggler.GetLaunderPrompt()
    for i = 1, 3 do
        if prompt then Smuggler.FirePrompt(prompt) end
        if State.Smuggler_UseRemotes and BRP.LaunderBriefcase then pcall(function() BRP.LaunderBriefcase:FireServer() end) end
        task.wait(0.4)
    end
end

function Smuggler.RunCycle()
    Smuggler.BuyItem(); if not State.Smuggler_AutoLoop then return end; task.wait(0.4)

    local car = State.Smuggler_CurrentCar
    if State.Smuggler_SpawnCar and (not car or not car.Parent) then
        car = Smuggler.SpawnCar(); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
    end
    if not car then car = GetPlayerCar() end

    if car then
        Smuggler.SitInCar(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
        if State.Smuggler_RemoveTires and not car:GetAttribute("__TR") then Smuggler.RemoveTires(car); pcall(function() car:SetAttribute("__TR",true) end) end
        if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
        Smuggler.TeleportCarToSeller(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.FireSell(); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.TeleportCarToLaundry(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.4)
    else
        local _,seller=Smuggler.GetSellPrompt(State.Smuggler_SellerName)
        if seller then local sh=seller:FindFirstChild("HumanoidRootPart"); if sh then SmartTP.Go(sh.Position,3); task.wait(0.5) end end
        Smuggler.FireSell(); task.wait(0.5)
        SmartTP.Go(State.POS_Laundry,3); task.wait(0.5)
    end

    Smuggler.FireLaunder()
    State.Smuggler_JobsDone = State.Smuggler_JobsDone + 1
    Log("Job #" .. State.Smuggler_JobsDone)
end

function Smuggler.SetAutoLoop(e)
    State.Smuggler_AutoLoop = e
    if not e then Log("Smuggler stopped"); return end
    Log("Smuggler started")
    task.spawn(function()
        while State.Smuggler_AutoLoop do
            local ok, err = pcall(Smuggler.RunCycle)
            if not ok then Log("Cycle error: " .. tostring(err)) end
            if not State.Smuggler_AutoLoop then break end
            task.wait(State.Smuggler_Delay)
        end
    end)
end

--━ POLICE
local Police = {}
function Police.CreateFOV()
    if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
    if Drawing then
        State.Police_FOVCircle=Drawing.new("Circle")
        State.Police_FOVCircle.Thickness=1; State.Police_FOVCircle.NumSides=60
        State.Police_FOVCircle.Radius=State.Police_AimFOV; State.Police_FOVCircle.Filled=false
        State.Police_FOVCircle.Visible=false; State.Police_FOVCircle.Transparency=0.7
        State.Police_FOVCircle.Color=Color3.fromRGB(255,50,50)
    end
end
function Police.UpdateFOV() if State.Police_FOVCircle then local vp=Camera.ViewportSize; State.Police_FOVCircle.Position=Vector2.new(vp.X/2,vp.Y/2); State.Police_FOVCircle.Radius=State.Police_AimFOV; State.Police_FOVCircle.Visible=State.Police_ShowFOV and (State.Police_AutoAim or State.Police_AutoFire) end end
function Police.GetTarget()
    local myHRP=GetHRP(); if not myHRP then return nil,nil end
    local vp=Camera.ViewportSize; local center=Vector2.new(vp.X/2,vp.Y/2)
    local bestP,bestPart,bestDist=nil,nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then local hum=p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health>0 then
                local should=false; if State.Police_TargetAll then should=true elseif State.Police_TargetWanted then should=IsWanted(p) end
                if should then local aim=p.Character:FindFirstChild(State.Police_AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
                    if aim then local sp,on=Camera:WorldToScreenPoint(aim.Position); if on then local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude; if d<=State.Police_AimFOV and d<bestDist then bestP=p;bestPart=aim;bestDist=d end end end end
            end
        end
    end
    return bestP,bestPart
end
function Police.AimAt(part) if not part or not part.Parent then return end; local tp=part.Position; if State.Police_AimSmooth<=1 then Camera.CFrame=CFrame.lookAt(Camera.CFrame.Position,tp) else Camera.CFrame=Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position,tp),math.clamp(1/State.Police_AimSmooth,0.05,1)) end end
function Police.TryFire() pcall(function() mouse1click() end); if BRP.BatonSwing and State.Police_CurrentTarget then pcall(function() BRP.BatonSwing:FireServer(State.Police_CurrentTarget) end) end end
function Police.TryArrest()
    local t=State.Police_CurrentTarget; if not t or not t.Character then return end
    local tHRP=t.Character:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    local myHRP=GetHRP(); if myHRP and (myHRP.Position-tHRP.Position).Magnitude>8 then SmartTP.Go(tHRP.Position+tHRP.CFrame.LookVector*-3,0); task.wait(0.3) end
    if BRP.Detain then pcall(function() BRP.Detain:InvokeServer(t) end) end
    if BRP.Jail then task.wait(0.4); pcall(function() BRP.Jail:InvokeServer(t) end) end
end
function Police.SetAutoAim(e)
    State.Police_AutoAim=e; if State.Police_AimConn then pcall(function() State.Police_AimConn:Disconnect() end); State.Police_AimConn=nil end
    if e then Police.CreateFOV(); State.Police_AimConn=RunService.RenderStepped:Connect(function()
        Police.UpdateFOV(); local p,part=Police.GetTarget(); State.Police_CurrentTarget=p
        if part and (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or State.Police_AutoFire) then Police.AimAt(part) end
    end) else if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle.Visible=false end) end; State.Police_CurrentTarget=nil end
end
function Police.SetAutoFire(e)
    State.Police_AutoFire=e; if State.Police_FireConn then pcall(function() State.Police_FireConn:Disconnect() end); State.Police_FireConn=nil end
    if e then local last=0; State.Police_FireConn=RunService.Heartbeat:Connect(function() if State.Police_CurrentTarget and tick()-last>=0.15 then last=tick(); Police.TryFire() end end) end
end
function Police.SetAutoArrest(e)
    State.Police_AutoArrest=e; if State.Police_ArrestConn then pcall(function() State.Police_ArrestConn:Disconnect() end); State.Police_ArrestConn=nil end
    if e then local last=0; State.Police_ArrestConn=RunService.Heartbeat:Connect(function() if State.Police_CurrentTarget and tick()-last>=2.5 then last=tick(); Police.TryArrest() end end) end
end

--━ VISUALS
local Vis = {}
function Vis.BackupLight() if next(State.LightBackup) then return end; State.LightBackup={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,GlobalShadows=Lighting.GlobalShadows} end
function Vis.RestoreLight() for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e) Vis.BackupLight(); if e then Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255); Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false else Vis.RestoreLight() end end
function Vis.NoFog(e) Vis.BackupLight(); if e then Lighting.FogEnd=999999; Lighting.FogStart=999999 else Lighting.FogEnd=State.LightBackup.FogEnd or 100000 end end
function Vis.SetFOV(f) if Camera then Camera.FieldOfView=tonumber(f) or 70 end end
function Vis.SetClock(t) Lighting.ClockTime=tonumber(t) or 14 end
function Vis.MuteAll(e) if e then for _,s in ipairs(Workspace:GetDescendants()) do if s:IsA("Sound") then table.insert(State.MutedSounds,{s=s,v=s.Volume}); s.Volume=0 end end else for _,en in ipairs(State.MutedSounds) do if en.s and en.s.Parent then en.s.Volume=en.v end end; State.MutedSounds={} end end

CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end end)
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end end end)
CM:Add(UserInputService.JumpRequest, function() if State.InfiniteJump then local h=GetHuman(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end end end)

if State.AntiTpBypass then AntiTp.Enable() end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WINDUI SETUP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "gamepad-2",
    Author = "Border RP • v" .. HUB.Version,
    Folder = "X0DEC04T",
    Size = UDim2.fromOffset(560, 460),
    Transparent = true,
    Theme = "Dark",
    User = { Enabled = true, Anonymous = false, Callback = function() end },
    SideBarWidth = 160,
    HasOutline = true,
})

pcall(function()
    WindUI:Notify({
        Title = HUB.Name,
        Content = "v" .. HUB.Version .. " loaded",
        Duration = 4,
        Icon = "check",
    })
end)

local function Notify(t, c, d)
    pcall(function()
        WindUI:Notify({ Title=tostring(t), Content=tostring(c), Duration=d or 4, Icon="info" })
    end)
end

-- Tabs
local Tabs = {
    Main     = Window:Tab({ Title="Main", Icon="home" }),
    Vehicle  = Window:Tab({ Title="Vehicle", Icon="car" }),
    Smuggler = Window:Tab({ Title="Smuggler", Icon="package" }),
    Police   = Window:Tab({ Title="Police", Icon="shield" }),
    Teleport = Window:Tab({ Title="Teleport", Icon="map-pin" }),
    ESP      = Window:Tab({ Title="ESP", Icon="eye" }),
    Visuals  = Window:Tab({ Title="Visuals", Icon="sun" }),
    Misc     = Window:Tab({ Title="Misc", Icon="wrench" }),
    Settings = Window:Tab({ Title="Settings", Icon="settings" }),
}

Window:SelectTab(1)

-- ═════════════════════ MAIN TAB ═════════════════════
Tabs.Main:Section({ Title = "X0DEC04T Hub v" .. HUB.Version })
Tabs.Main:Paragraph({
    Title = "Border RP - Stable Build",
    Desc = "AntiTp: Hide method (no crashes)\nAll operations pcall-wrapped\nWindUI framework",
})

Tabs.Main:Section({ Title = "System Status" })
Tabs.Main:Paragraph({
    Title = "Info",
    Desc = "Remotes: " .. remoteCount .. "\nSellers: " .. #GetSellerNames() .. "\nSpawner: " .. (BRP_PATHS.VehicleSpawners and BRP_PATHS.VehicleSpawners.Name or "none"),
})

-- ═════════════════════ VEHICLE TAB ═════════════════════
Tabs.Vehicle:Section({ Title = "Speed" })
Tabs.Vehicle:Slider({
    Title = "Extra Speed", Value = { Min=0, Max=500, Default=0 }, Step=10,
    Callback = function(v) State.CarSpeed = v; Car.ApplySpeed() end
})
Tabs.Vehicle:Slider({
    Title = "SpeedHack Value", Value = { Min=100, Max=2000, Default=500 }, Step=50,
    Callback = function(v) State.SpeedHackValue = v end
})
Tabs.Vehicle:Toggle({
    Title = "Speed Hack", Default = false,
    Callback = function(v) State.SpeedHack = v; Car.SetSpeedHack(v) end
})

Tabs.Vehicle:Section({ Title = "Actions" })
Tabs.Vehicle:Button({ Title = "Flip Car", Callback = Car.Flip })
Tabs.Vehicle:Button({ Title = "Boost", Callback = Car.Boost })
Tabs.Vehicle:Button({ Title = "Unstuck", Callback = function()
    if BRP.UnstuckVehicle then pcall(function() BRP.UnstuckVehicle:FireServer() end) end
end })

Tabs.Vehicle:Section({ Title = "Abilities" })
Tabs.Vehicle:Toggle({ Title = "NoClip", Default = false, Callback = function(v) State.NoClip=v; Car.SetNoClip(v) end })
Tabs.Vehicle:Toggle({ Title = "Fly (WASD/Space)", Default = false, Callback = function(v) State.FlyActive=v; Car.SetFly(v) end })
Tabs.Vehicle:Toggle({ Title = "God Mode", Default = false, Callback = function(v) State.GodMode=v; Car.SetGod(v) end })

Tabs.Vehicle:Section({ Title = "Character" })
Tabs.Vehicle:Slider({
    Title = "WalkSpeed", Value = { Min=16, Max=200, Default=16 }, Step=4,
    Callback = function(v) State.WalkSpeed=v; local h=GetHuman(); if h then pcall(function() h.WalkSpeed=v end) end end
})
Tabs.Vehicle:Slider({
    Title = "JumpPower", Value = { Min=50, Max=300, Default=50 }, Step=10,
    Callback = function(v) State.JumpPower=v; local h=GetHuman(); if h then pcall(function() h.JumpPower=v end) end end
})
Tabs.Vehicle:Toggle({ Title = "Infinite Jump", Default = false, Callback = function(v) State.InfiniteJump=v end })

-- ═════════════════════ SMUGGLER TAB ═════════════════════
Tabs.Smuggler:Section({ Title = "Auto Smuggler" })
Tabs.Smuggler:Paragraph({
    Title = "Flow",
    Desc = "Buy → Spawn Car → Sit → Remove Tires → TP Car to Seller → Sell → TP to Laundry → Launder",
})

Tabs.Smuggler:Section({ Title = "Item Settings" })
Tabs.Smuggler:Dropdown({
    Title = "Item to Buy",
    Values = GetBuyableItemNames(),
    Value = "Fake Diamond Ring",
    Callback = function(v) State.Smuggler_ItemName = v end
})
Tabs.Smuggler:Slider({
    Title = "Buy Retries", Value = { Min=1, Max=5, Default=2 }, Step=1,
    Callback = function(v) State.Smuggler_BuyRetries = v end
})

Tabs.Smuggler:Section({ Title = "Vehicle Settings" })
Tabs.Smuggler:Toggle({ Title = "Auto Spawn Car", Default = true, Callback = function(v) State.Smuggler_SpawnCar = v end })
Tabs.Smuggler:Toggle({ Title = "Remove Tires", Default = true, Callback = function(v) State.Smuggler_RemoveTires = v end })
Tabs.Smuggler:Dropdown({
    Title = "Vehicle to Spawn",
    Values = {"Camry6", "BorderPatrolCrownVic", "2020Rs3Done", "jzs171 touring", "TAPVSWAT"},
    Value = "Camry6",
    Callback = function(v) State.Smuggler_VehicleName = v end
})
Tabs.Smuggler:Input({
    Title = "Custom Vehicle Name",
    Placeholder = "Overrides dropdown",
    Callback = function(v) if v ~= "" then State.Smuggler_VehicleName = v end end
})
Tabs.Smuggler:Button({ Title = "Save Spawner Pos (Here)", Callback = function()
    local h = GetHRP(); if h then State.POS_CarSpawner = h.Position; Notify("Saved", "Position saved", 2) end
end })
Tabs.Smuggler:Button({ Title = "List All Spawners (Console)", Callback = function()
    local s = FindAllSpawners()
    Log("=== SPAWNERS: " .. #s .. " ===")
    for i, sp in ipairs(s) do
        Log(string.format("[%d] %s | prompt=%s | pos=%s", i, sp.container and sp.container.Name or "?", sp.prompt.Name, tostring(sp.position)))
    end
    Notify("Spawners", "Found " .. #s .. " (check console)", 4)
end })

Tabs.Smuggler:Section({ Title = "Car TP Method (Anti-Rollback)" })
Tabs.Smuggler:Dropdown({
    Title = "Car TP Method",
    Values = {"WeldTP", "DirectTP", "TweenVehicle"},
    Value = "WeldTP",
    Callback = function(v) State.Smuggler_CarTPMethod = v end
})
Tabs.Smuggler:Paragraph({ Title = "Info", Desc = "WeldTP = safest (sit in car first)\nDirectTP = instant (may rollback)\nTweenVehicle = smooth" })

Tabs.Smuggler:Section({ Title = "Equip Settings" })
Tabs.Smuggler:Toggle({ Title = "Auto Equip Before Sell", Default = true, Callback = function(v) State.Smuggler_AutoEquip = v end })
Tabs.Smuggler:Toggle({ Title = "Equip All Copies", Default = true, Callback = function(v) State.Smuggler_EquipAll = v end })

Tabs.Smuggler:Section({ Title = "Seller Settings" })
Tabs.Smuggler:Dropdown({
    Title = "Target Seller",
    Values = GetSellerNames(),
    Value = State.Smuggler_SellerName,
    Callback = function(v) State.Smuggler_SellerName = v end
})
Tabs.Smuggler:Slider({
    Title = "Sell Retries", Value = { Min=1, Max=15, Default=8 }, Step=1,
    Callback = function(v) State.Smuggler_SellRetries = v end
})

Tabs.Smuggler:Section({ Title = "Player TP Settings" })
Tabs.Smuggler:Toggle({
    Title = "AntiTp Bypass (Hide)",
    Default = true,
    Callback = function(v) State.AntiTpBypass = v; if v then AntiTp.Enable() else AntiTp.Disable() end end
})
Tabs.Smuggler:Dropdown({
    Title = "Player TP Method",
    Values = {"Tween", "Instant"},
    Value = "Tween",
    Callback = function(v) State.TPStrategy = v end
})
Tabs.Smuggler:Slider({
    Title = "Tween Speed (studs/s)", Value = { Min=50, Max=1000, Default=200 }, Step=25,
    Callback = function(v) State.TweenSpeed = v end
})

Tabs.Smuggler:Section({ Title = "Timing" })
Tabs.Smuggler:Slider({
    Title = "Cycle Delay (s)", Value = { Min=0, Max=10, Default=1 }, Step=1,
    Callback = function(v) State.Smuggler_Delay = v end
})
Tabs.Smuggler:Toggle({ Title = "Use Remote Backup", Default = true, Callback = function(v) State.Smuggler_UseRemotes = v end })
Tabs.Smuggler:Toggle({ Title = "Auto Launder", Default = true, Callback = function(v) State.Smuggler_AutoLaunder = v end })
Tabs.Smuggler:Toggle({ Title = "Debug Mode", Default = true, Callback = function(v) State.Smuggler_DebugMode = v end })

Tabs.Smuggler:Section({ Title = "Main Toggle" })
Tabs.Smuggler:Toggle({
    Title = "Auto Smuggler Loop",
    Default = false,
    Callback = function(v) Smuggler.SetAutoLoop(v) end
})

Tabs.Smuggler:Section({ Title = "Manual Steps" })
Tabs.Smuggler:Button({ Title = "TP to Spawner", Callback = function()
    local sp = FindNearestSpawner()
    if sp then SmartTP.Go(sp.position, 3) else SmartTP.Go(State.POS_CarSpawner, 3) end
end })
Tabs.Smuggler:Button({ Title = "1. Buy Item", Callback = function() task.spawn(Smuggler.BuyItem) end })
Tabs.Smuggler:Button({ Title = "2. Spawn Car", Callback = function() task.spawn(Smuggler.SpawnCar) end })
Tabs.Smuggler:Button({ Title = "3. Sit In Car", Callback = function()
    task.spawn(function()
        local c = State.Smuggler_CurrentCar or GetPlayerCar()
        if c then Smuggler.SitInCar(c) else Notify("Err", "No car", 3) end
    end)
end })
Tabs.Smuggler:Button({ Title = "4. Remove Tires", Callback = function()
    task.spawn(function()
        local c = State.Smuggler_CurrentCar or GetPlayerCar()
        if c then Smuggler.RemoveTires(c) else Notify("Err", "No car", 3) end
    end)
end })
Tabs.Smuggler:Button({ Title = "5. TP Car → Seller", Callback = function()
    task.spawn(function()
        local c = State.Smuggler_CurrentCar or GetPlayerCar()
        if c then Smuggler.TeleportCarToSeller(c) else Notify("Err", "No car", 3) end
    end)
end })
Tabs.Smuggler:Button({ Title = "6. Sell", Callback = function() task.spawn(Smuggler.FireSell) end })
Tabs.Smuggler:Button({ Title = "7. TP Car → Laundry", Callback = function()
    task.spawn(function()
        local c = State.Smuggler_CurrentCar or GetPlayerCar()
        Smuggler.TeleportCarToLaundry(c)
    end)
end })
Tabs.Smuggler:Button({ Title = "8. Launder", Callback = function() task.spawn(Smuggler.FireLaunder) end })

-- ═════════════════════ POLICE TAB ═════════════════════
Tabs.Police:Section({ Title = "Targeting" })
Tabs.Police:Toggle({ Title = "Wanted Only", Default = true, Callback = function(v) State.Police_TargetWanted = v end })
Tabs.Police:Toggle({ Title = "Target All", Default = false, Callback = function(v) State.Police_TargetAll = v end })
Tabs.Police:Slider({ Title = "Min Wanted Level", Value = { Min=1, Max=10, Default=1 }, Step=1,
    Callback = function(v) State.Police_MinWantedLevel = v end })
Tabs.Police:Dropdown({
    Title = "Aim Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso"},
    Value = "Head",
    Callback = function(v) State.Police_AimPart = v end
})

Tabs.Police:Section({ Title = "Aim" })
Tabs.Police:Slider({ Title = "FOV", Value = { Min=30, Max=500, Default=150 }, Step=10, Callback = function(v) State.Police_AimFOV = v end })
Tabs.Police:Slider({ Title = "Smoothness", Value = { Min=1, Max=20, Default=1 }, Step=1, Callback = function(v) State.Police_AimSmooth = v end })
Tabs.Police:Toggle({ Title = "Show FOV Circle", Default = true, Callback = function(v) State.Police_ShowFOV = v end })

Tabs.Police:Section({ Title = "Controls" })
Tabs.Police:Toggle({ Title = "Auto-Aim (hold RMB)", Default = false, Callback = function(v) Police.SetAutoAim(v) end })
Tabs.Police:Toggle({ Title = "Auto-Fire", Default = false, Callback = function(v) Police.SetAutoFire(v) end })
Tabs.Police:Toggle({ Title = "Auto-Arrest", Default = false, Callback = function(v) Police.SetAutoArrest(v) end })

-- ═════════════════════ TELEPORT TAB ═════════════════════
Tabs.Teleport:Section({ Title = "Player TP" })
Tabs.Teleport:Input({
    Title = "Player Name",
    Placeholder = "Case-sensitive",
    Callback = function(v) State.TP_Target = v end
})
Tabs.Teleport:Button({ Title = "TP to Player", Callback = function() Car.TeleportToPlayer(State.TP_Target) end })

Tabs.Teleport:Section({ Title = "Quick Locations" })
Tabs.Teleport:Button({ Title = "Shop (El Capo)", Callback = function() SmartTP.Go(State.POS_Shop, 3) end })
Tabs.Teleport:Button({ Title = "Laundry", Callback = function() SmartTP.Go(State.POS_Laundry, 3) end })
Tabs.Teleport:Button({ Title = "Car Spawner", Callback = function()
    local sp = FindNearestSpawner()
    if sp then SmartTP.Go(sp.position, 3) else SmartTP.Go(State.POS_CarSpawner, 3) end
end })

Tabs.Teleport:Section({ Title = "All Sellers" })
for _, name in ipairs(GetSellerNames()) do
    Tabs.Teleport:Button({ Title = "TP to " .. name, Callback = function()
        local npc = BRP_PATHS.NPC and BRP_PATHS.NPC:FindFirstChild(name)
        if npc then local h = npc:FindFirstChild("HumanoidRootPart"); if h then SmartTP.Go(h.Position, 3) end end
    end })
end

-- ═════════════════════ ESP TAB ═════════════════════
Tabs.ESP:Section({ Title = "ESP Toggles" })
Tabs.ESP:Toggle({ Title = "All Players", Default = false, Callback = function(v) State.ESP_Players = v end })
Tabs.ESP:Toggle({ Title = "Wanted (Red)", Default = false, Callback = function(v) State.ESP_Wanted = v end })
Tabs.ESP:Toggle({ Title = "Police (Blue)", Default = false, Callback = function(v) State.ESP_Police = v end })

Tabs.ESP:Section({ Title = "Display" })
Tabs.ESP:Toggle({ Title = "Show Names", Default = true,
    Callback = function(v) State.ESP_ShowName = v; for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible = v end end end })
Tabs.ESP:Toggle({ Title = "Show Distance", Default = true,
    Callback = function(v) State.ESP_ShowDist = v; for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible = v end end end })
Tabs.ESP:Slider({ Title = "Max Distance", Value = { Min=100, Max=5000, Default=800 }, Step=100,
    Callback = function(v) State.ESP_MaxDist = v end })

Tabs.ESP:Button({ Title = "Refresh ESP", Callback = function() ESP.ClearAll(); ESP.RefreshAll() end })
Tabs.ESP:Button({ Title = "Clear ESP", Callback = ESP.ClearAll })

-- ═════════════════════ VISUALS TAB ═════════════════════
Tabs.Visuals:Section({ Title = "Lighting" })
Tabs.Visuals:Toggle({ Title = "FullBright", Default = false, Callback = function(v) State.FullBright = v; Vis.FullBright(v) end })
Tabs.Visuals:Toggle({ Title = "No Fog", Default = false, Callback = function(v) State.NoFog = v; Vis.NoFog(v) end })
Tabs.Visuals:Slider({ Title = "Time of Day", Value = { Min=0, Max=24, Default=14 }, Step=1, Callback = function(v) Vis.SetClock(v) end })

Tabs.Visuals:Section({ Title = "Camera" })
Tabs.Visuals:Slider({ Title = "FOV", Value = { Min=30, Max=120, Default=70 }, Step=5, Callback = function(v) State.FOV = v; Vis.SetFOV(v) end })

-- ═════════════════════ MISC TAB ═════════════════════
Tabs.Misc:Section({ Title = "Audio" })
Tabs.Misc:Toggle({ Title = "Mute All Sounds", Default = false, Callback = function(v) Vis.MuteAll(v) end })

Tabs.Misc:Section({ Title = "Server" })
Tabs.Misc:Button({ Title = "Server Hop", Callback = function()
    pcall(function()
        local TS = game:GetService("TeleportService")
        local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(raw)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); return
            end
        end
    end)
end })
Tabs.Misc:Button({ Title = "Rejoin", Callback = function()
    pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
end })

Tabs.Misc:Section({ Title = "Utility" })
Tabs.Misc:Button({ Title = "Copy Position", Callback = function()
    local h = GetHRP()
    if h then
        local p = h.Position
        local s = string.format("Vector3.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
        if setclipboard then setclipboard(s) end
        Notify("Copied", s, 3)
    end
end })

-- ═════════════════════ SETTINGS TAB ═════════════════════
Tabs.Settings:Section({ Title = "Anti-AFK" })
Tabs.Settings:Toggle({ Title = "Anti-AFK", Default = true, Callback = function(v) State.AntiAFK = v end })

Tabs.Settings:Section({ Title = "Panic" })
Tabs.Settings:Button({ Title = "PANIC (Disable Everything)", Callback = function()
    ESP.ClearAll()
    Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
    Smuggler.SetAutoLoop(false)
    Notify("PANIC", "All disabled", 3)
end })

Tabs.Settings:Section({ Title = "Info" })
Tabs.Settings:Paragraph({
    Title = HUB.Name .. " v" .. HUB.Version,
    Desc = "Border RP Automation\nWindUI Framework\nStable + Safe",
})

Tabs.Settings:Section({ Title = "Unload" })
Tabs.Settings:Button({ Title = "Unload Hub", Callback = function()
    Smuggler.SetAutoLoop(false)
    Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
    AntiTp.Disable(); DisableNoclip()
    if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
    CM:Cleanup(); Vis.RestoreLight(); Vis.MuteAll(false); ESP.ClearAll()
    _G[INSTANCE_KEY] = nil
    pcall(function() Window:Destroy() end)
end })

-- Character respawn handling
CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGod, true) end
    if State.NoClip then pcall(Car.SetNoClip, true) end
    if State.FlyActive then pcall(Car.SetFly, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.AntiTpBypass then AntiTp.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        Smuggler.SetAutoLoop(false)
        Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTp.Disable(); DisableNoclip()
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Log("v3.0.0 WindUI ready | AntiTp: hide | Spawner: " .. (BRP_PATHS.VehicleSpawners and BRP_PATHS.VehicleSpawners.Name or "none"))
