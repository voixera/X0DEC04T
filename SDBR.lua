--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.9.5 - Border RP (Scarface)
-- Fixed: SEH crashes, safe hooks, stable car spawn
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

local INSTANCE_KEY = "__X0DEC04T_BRP_v295"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(m))) end
local function Err(m,d) warn(string.format("[X0DEC04T] ERR: %s | %s", tostring(m), tostring(d or ""))) end
Log("BorderRP Hub v2.9.5 starting...")

local Rayfield
for _, url in ipairs({"https://sirius.menu/rayfield","https://raw.githubusercontent.com/shlexware/Rayfield/main/source"}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then Err("Rayfield failed"); return end

local HUB = { Name="X0DEC04T Hub", Game="Border RP", Version="2.9.5", Author="voixera" }

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

local function Notify(t, c, d)
    pcall(function() Rayfield:Notify({Title=tostring(t or ""), Content=tostring(c or ""), Duration=tonumber(d) or 4, Image=4483345998}) end)
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
    SaveVehicleColor        = GetRemote("VehicleSpawnerService.SaveVehicleColor"),
    PromptVehicle           = GetRemote("VehicleSpawnerService.PromptVehicleDevProductPurchase"),
    PurchaseWorldItem       = GetRemote("WorldBuyableItemService.PurchaseWorldBuyableItem"),
    Detain                  = GetRemote("Handcuffs.Detain"),
    Jail                    = GetRemote("Handcuffs.Jail"),
    BatonSwing              = GetRemote("Baton.Swing"),
    UnstuckVehicle          = GetRemote("VehicleService.UnstuckVehicle"),
    JoinTeam                = GetRemote("TeamService.JoinTeam"),
    ApplyRollbackCFrame     = GetRemote("AntiTp.ApplyRollbackCFrame"),
    VehicleStateChanged     = GetRemote("VehicleService.VehicleStateChanged"),
    SetVehicleState         = GetRemote("VehicleService.SetVehicleState"),
}
local remoteCount = 0
for _, v in pairs(BRP) do if v then remoteCount = remoteCount + 1 end end
Log("Loaded " .. remoteCount .. " BRP remotes")

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

local RemoteDB, RemoteDBAll = {}, {}
for _, o in ipairs(ReplicatedStorage:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        RemoteDB[o.Name:lower()] = o
        table.insert(RemoteDBAll, o)
    end
end
local function FindRemote(name)
    if not name or name == "" then return nil end
    local k = name:lower()
    if RemoteDB[k] then return RemoteDB[k] end
    for key, v in pairs(RemoteDB) do if key:find(k, 1, true) then return v end end
    return nil
end

local DEFAULT_POS = {
    Laundry = Vector3.new(6804.78, 17.43, -34.70),
    Shop    = Vector3.new(6823.57, 17.40, -20.00),
    CarSpawner = Vector3.new(6840, 17, -30),
}

local function GetBuyableItemNames()
    local names = {}
    if BRP_PATHS.WorldBuyableItems then
        for _, item in ipairs(BRP_PATHS.WorldBuyableItems:GetChildren()) do
            table.insert(names, item.Name)
        end
    end
    if #names == 0 then table.insert(names, "Fake Diamond Ring") end
    return names
end

--━ STATE
local State = {
    ESP_Players=false, ESP_Wanted=false, ESP_Police=false,
    ESP_ShowName=true, ESP_ShowDist=true, ESP_MaxDist=800,
    Color_Player=Color3.fromRGB(60,220,255),
    Color_Wanted=Color3.fromRGB(255,50,50),
    Color_Police=Color3.fromRGB(60,120,255),
    CarSpeed=0, SpeedHack=false, SpeedHackConn=nil, SpeedHackValue=500,
    FlyActive=false, FlyConn=nil, GodMode=false, NoclipConn=nil, NoClip=false,
    WalkSpeed=16, JumpPower=50, InfiniteJump=false,
    TP_Target="", RemoteName="", RemoteArg="",

    Smuggler_AutoLoop=false, Smuggler_JobsDone=0,
    Smuggler_UseRemotes=true, Smuggler_AutoLaunder=true,
    Smuggler_ItemName = "Fake Diamond Ring",
    Smuggler_SellerName = "Seller4",
    Smuggler_VehicleName = "Camry6",
    Smuggler_BuyRetries = 2, Smuggler_SellRetries = 8,
    Smuggler_Delay = 1, Smuggler_DebugMode = true,
    Smuggler_AutoEquip = true, Smuggler_EquipAll = true,
    Smuggler_RemoveTires = true, Smuggler_SpawnCar = true,
    Smuggler_CurrentCar = nil,
    Smuggler_CarTPMethod = "WeldTP",
    POS_Shop = DEFAULT_POS.Shop,
    POS_Laundry = DEFAULT_POS.Laundry,
    POS_CarSpawner = DEFAULT_POS.CarSpawner,

    AntiTpBypass = true,
    AntiTpMethod = "hide",
    TPStrategy = "Tween",
    TweenSpeed = 200, TweenNoclip = true,

    Police_AutoAim=false, Police_AutoFire=false, Police_AutoArrest=false,
    Police_AimPart="Head", Police_AimFOV=150, Police_AimSmooth=1,
    Police_TargetWanted=true, Police_MinWantedLevel=1, Police_TargetAll=false,
    Police_ShowFOV=true, Police_FOVCircle=nil,
    Police_AimConn=nil, Police_FireConn=nil, Police_ArrestConn=nil,
    Police_CurrentTarget=nil,

    FullBright=false, NoFog=false, FOV=70, AntiAFK=true, MutedSounds={},
    ESPCache={}, LightBackup={},
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
-- ANTITP BYPASS - HIDE METHOD ONLY (SAFEST, NO SEH CRASH)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AntiTpBypass = {
    enabled = false,
    blockedCount = 0,
    _remoteHidden = false,
    _origParent = nil,
    _activeHolds = 0,
}

function AntiTpBypass.Enable()
    State.AntiTpMethod = "hide"
    AntiTpBypass.enabled = true
    Log("[AntiTp] Enabled (hide method - safe)")
end

function AntiTpBypass.Disable()
    AntiTpBypass.enabled = false
    AntiTpBypass.EndTP(true) -- force restore
end

function AntiTpBypass.BeginTP()
    if not AntiTpBypass.enabled then return end
    AntiTpBypass._activeHolds = AntiTpBypass._activeHolds + 1
    if not AntiTpBypass._remoteHidden and BRP.ApplyRollbackCFrame then
        local r = BRP.ApplyRollbackCFrame
        if r and r.Parent then
            AntiTpBypass._origParent = r.Parent
            local ok = pcall(function() r.Parent = nil end)
            if ok then
                AntiTpBypass._remoteHidden = true
                AntiTpBypass.blockedCount = AntiTpBypass.blockedCount + 1
                if State.Smuggler_DebugMode then Log("[AntiTp] Hidden #" .. AntiTpBypass.blockedCount) end
            end
        end
    end
end

function AntiTpBypass.EndTP(force)
    if not force then
        AntiTpBypass._activeHolds = math.max(0, AntiTpBypass._activeHolds - 1)
        if AntiTpBypass._activeHolds > 0 then return end
    else
        AntiTpBypass._activeHolds = 0
    end
    if AntiTpBypass._remoteHidden then
        local r = BRP.ApplyRollbackCFrame
        if r and AntiTpBypass._origParent then
            pcall(function() r.Parent = AntiTpBypass._origParent end)
        end
        AntiTpBypass._remoteHidden = false
        if State.Smuggler_DebugMode then Log("[AntiTp] Restored") end
    end
end

-- Auto-restore safety: never leave remote hidden more than 10s
task.spawn(function()
    while true do
        task.wait(5)
        if AntiTpBypass._remoteHidden and AntiTpBypass._activeHolds == 0 then
            AntiTpBypass.EndTP(true)
        end
    end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SMART TELEPORT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local SmartTP = {}
local _tweenNoclipConn = nil

local function EnableTweenNoclip()
    if _tweenNoclipConn then return end
    _tweenNoclipConn = RunService.Stepped:Connect(function()
        local ch = GetChar()
        if ch then for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end end
    end)
end

local function DisableTweenNoclip()
    if _tweenNoclipConn then pcall(function() _tweenNoclipConn:Disconnect() end); _tweenNoclipConn = nil end
end

function SmartTP.Tween(pos, yOff)
    if not pos then return false end
    local hrp = GetHRP(); if not hrp then return false end
    local hum = GetHuman()
    local targetPos = pos + Vector3.new(0, yOff or 3, 0)
    local totalDist = (targetPos - hrp.Position).Magnitude

    if totalDist < 5 then hrp.CFrame = CFrame.new(targetPos); task.wait(0.1); return true end

    local wasPlatform = false
    if hum then wasPlatform = hum.PlatformStand; hum.PlatformStand = true end
    if State.TweenNoclip then EnableTweenNoclip() end

    local speed = math.max(State.TweenSpeed or 200, 50)
    local duration = math.clamp(totalDist / speed, 0.2, 15)

    if State.Smuggler_DebugMode then Log(string.format("[Tween] dist=%.0f dur=%.2fs", totalDist, duration)) end

    local ok, tween = pcall(function()
        return TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
    end)
    if not ok or not tween then
        if hum and hum.Parent then hum.PlatformStand = wasPlatform end
        DisableTweenNoclip()
        return false
    end

    tween:Play()
    local t0 = tick()
    while tick() - t0 < duration + 1 do
        task.wait(0.1)
        if not hrp or not hrp.Parent then break end
    end
    pcall(function() tween:Cancel() end)

    local fhrp = GetHRP()
    if fhrp then pcall(function() fhrp.CFrame = CFrame.new(targetPos) end) end
    if hum and hum.Parent then hum.PlatformStand = wasPlatform end
    DisableTweenNoclip()
    task.wait(0.2)
    return true
end

function SmartTP.Instant(pos, yOff)
    if not pos then return false end
    local hrp = GetHRP(); if not hrp then return false end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOff or 3, 0)) end)
    task.wait(0.3)
    return true
end

function SmartTP.Go(pos, yOff)
    if State.AntiTpBypass then AntiTpBypass.BeginTP() end
    local result
    if (State.TPStrategy or "Tween") == "Instant" then
        result = SmartTP.Instant(pos, yOff)
    else
        result = SmartTP.Tween(pos, yOff)
    end
    if State.AntiTpBypass then
        task.delay(2, function() pcall(AntiTpBypass.EndTP) end)
    end
    return result
end

function SmartTP.TeleportVehicle(car, targetPos, faceCFrame)
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

function SmartTP.WeldCarTP(car, targetPos, faceCFrame)
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
        Log("[WeldTP] Not in car, fallback to direct")
        AntiTpBypass.BeginTP()
        local r = SmartTP.TeleportVehicle(car, targetPos, faceCFrame)
        task.delay(3, function() pcall(AntiTpBypass.EndTP) end)
        return r
    end

    AntiTpBypass.BeginTP()

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

    if State.Smuggler_DebugMode then Log(string.format("[WeldTP] dist=%.0f", totalDist)) end

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

    task.delay(3, function() pcall(AntiTpBypass.EndTP) end)
    return true
end

function SmartTP.TweenVehicle(car, targetPos, faceCFrame)
    if not car then return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then return false end

    AntiTpBypass.BeginTP()

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

    if State.Smuggler_DebugMode then Log(string.format("[TweenVeh] dist=%.0f dur=%.2fs", totalDist, duration)) end

    local ok, tween = pcall(function()
        return TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
    end)
    if ok and tween then
        tween:Play()
        local t0 = tick()
        while tick() - t0 < duration + 1 do task.wait(0.1) end
        pcall(function() tween:Cancel() end)
    end

    pcall(function()
        if car:IsA("Model") then car:PivotTo(targetCF) else root.CFrame = targetCF end
    end)
    task.wait(0.2)

    task.delay(3, function() pcall(AntiTpBypass.EndTP) end)
    return true
end

function SmartTP.CarTP(car, targetPos, faceCFrame)
    local m = State.Smuggler_CarTPMethod or "WeldTP"
    if m == "WeldTP" then return SmartTP.WeldCarTP(car, targetPos, faceCFrame) end
    if m == "TweenVehicle" then return SmartTP.TweenVehicle(car, targetPos, faceCFrame) end
    AntiTpBypass.BeginTP()
    local r = SmartTP.TeleportVehicle(car, targetPos, faceCFrame)
    task.delay(3, function() pcall(AntiTpBypass.EndTP) end)
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
function Car.ApplySpeed() local s=GetVehicleSeat(); if s then s.MaxSpeed=100+(tonumber(State.CarSpeed)or 0) else Notify("Speed","Enter vehicle",3) end end
function Car.SetSpeedHack(e)
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn=nil end
    if e then State.SpeedHackConn=RunService.Heartbeat:Connect(function() local s=GetVehicleSeat(); if s then s.MaxSpeed=tonumber(State.SpeedHackValue)or 500 end end) end
end
function Car.Flip() local c=GetPlayerCar(); if c then local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then pcall(function() r.CFrame=CFrame.new(r.Position) end) end end end
function Car.Boost() local r=GetCarRoot(); if not r then return end; local bv=Instance.new("BodyVelocity"); bv.Velocity=r.CFrame.LookVector*400; bv.MaxForce=Vector3.new(math.huge,0,math.huge); bv.Parent=r; game:GetService("Debris"):AddItem(bv,0.3) end
function Car.SetNoClip(e)
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn=nil end
    if e then State.NoclipConn=RunService.Stepped:Connect(function()
        local car=GetPlayerCar(); if car then for _,p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        local ch=GetChar(); if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end) end
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local h=GetHuman()
    if e then
        if h then h.PlatformStand=true end; local hrp=GetHRP()
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
        if h then h.PlatformStand=false end; local hrp=GetHRP()
        if hrp then local a=hrp:FindFirstChild("__FG"); local b=hrp:FindFirstChild("__FV"); if a then a:Destroy() end; if b then b:Destroy() end end
    end
end
function Car.SetGod(e) local h=GetHuman(); if h then if e then h.MaxHealth=math.huge; h.Health=math.huge else h.MaxHealth=100; h.Health=100 end end end
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

--━ SMUGGLER
local Smuggler = {}

function Smuggler.FirePrompt(prompt)
    if not prompt then return false end
    local ok = pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
    if State.Smuggler_DebugMode then Log("FirePrompt [" .. tostring(ok) .. "] " .. prompt:GetFullName()) end
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
    Log("[Step 1] Buying " .. State.Smuggler_ItemName)
    local prompt, item = Smuggler.GetBuyPrompt(State.Smuggler_ItemName)
    if not item then Log("[Step 1] Item not found"); return false end
    local pos = Smuggler.GetItemPos(State.Smuggler_ItemName)
    if pos then SmartTP.Go(pos, 3) end
    if not prompt then Log("[Step 1] No prompt"); return false end
    for i = 1, State.Smuggler_BuyRetries or 2 do Smuggler.FirePrompt(prompt); task.wait(0.4) end
    Log("[Step 1] Done"); return true
end

function Smuggler.SpawnCar()
    local vehicleName = State.Smuggler_VehicleName
    if vehicleName == "" or not vehicleName then vehicleName = "Camry6" end
    Log("[Step 2] Spawn: " .. vehicleName)

    local spawner = FindNearestSpawner()
    if spawner then
        Log("[Step 2] Spawner: " .. spawner.container.Name .. " at " .. tostring(spawner.position))
        SmartTP.Go(spawner.position, 3)
        task.wait(0.6)
        spawner = FindNearestSpawner()
    else
        Log("[Step 2] No spawner detected, using saved pos")
        SmartTP.Go(State.POS_CarSpawner, 3)
        task.wait(0.8)
        spawner = FindNearestSpawner()
    end

    local existingCars = {}
    if BRP_PATHS.Vehicles then
        for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do existingCars[v] = true end
    end

    local newCar = nil
    local addedConn
    if BRP_PATHS.Vehicles then
        addedConn = BRP_PATHS.Vehicles.ChildAdded:Connect(function(child)
            if not existingCars[child] then
                newCar = child
                Log("[Step 2] [NEW VEHICLE SPAWNED] " .. child.Name)
            end
        end)
    end

    if spawner and spawner.prompt then
        Log("[Step 2] Fire prompt: " .. spawner.prompt:GetFullName())
        Smuggler.FirePrompt(spawner.prompt)
        task.wait(0.5)
    end

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
            if State.Smuggler_DebugMode then Log("[Step 2] Try #" .. i) end
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
            if not existingCars[v] then newCar = v; Log("[Step 2] Diff: " .. v.Name); break end
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
        Log("[Step 2] Ready: " .. newCar.Name)
        return newCar
    end

    Log("[Step 2] FAILED"); Notify("Spawn","Failed - press E manually",4)
    return nil
end

function Smuggler.SitInCar(car)
    Log("[Step 3] Sit")
    if not car or not car.Parent then return false end
    if GetPlayerCar() == car then Log("[Step 3] Already in"); return true end

    local seat = nil
    for a = 1, 10 do
        for _, obj in ipairs(car:GetDescendants()) do
            if obj:IsA("VehicleSeat") and not obj.Occupant then seat = obj; break end
        end
        if seat then break end; task.wait(0.2)
    end
    if not seat then Log("[Step 3] No seat"); return false end

    local hum, hrp = GetHuman(), GetHRP()
    if not hum or not hrp then return false end

    for a = 1, 3 do
        pcall(function() hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(0.2); seat:Sit(hum) end)
        task.wait(0.6)
        if GetPlayerCar() == car then Log("[Step 3] OK #" .. a); return true end
    end
    Log("[Step 3] Failed"); return false
end

function Smuggler.RemoveTires(car)
    if not car then return end; Log("[Step 4] Tires")
    local removed = 0
    for _, obj in ipairs(car:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") and (n:find("wheel") or n:find("tire") or n:find("tyre")) then
            pcall(function() obj:Destroy() end); removed = removed + 1
        end
    end
    Log("[Step 4] Removed " .. removed)
end

function Smuggler.TeleportCarToSeller(car)
    Log("[Step 5] TP car -> seller")
    if not car then return false end
    local _, seller = Smuggler.GetSellPrompt(State.Smuggler_SellerName)
    if not seller then Log("[Step 5] No seller"); return false end
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
    Log("[Step 6] Sell")
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
    Log("[Step 6] Done")
end

function Smuggler.TeleportCarToLaundry(car)
    Log("[Step 7] TP -> laundry")
    if not car then SmartTP.Go(State.POS_Laundry, 3); task.wait(0.6); return end
    local tp = State.POS_Laundry + Vector3.new(0, 3, 0)
    SmartTP.CarTP(car, tp, CFrame.new(tp))
    task.wait(0.5)
end

function Smuggler.FireLaunder()
    if not State.Smuggler_AutoLaunder then return end; Log("[Step 8] Launder")
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
        if State.Smuggler_RemoveTires and not car:GetAttribute("__TR") then Smuggler.RemoveTires(car); car:SetAttribute("__TR",true) end
        if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
        Smuggler.TeleportCarToSeller(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.FireSell(); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.TeleportCarToLaundry(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.4)
    else
        Log("[Cycle] No car - foot")
        local _,seller=Smuggler.GetSellPrompt(State.Smuggler_SellerName)
        if seller then local sh=seller:FindFirstChild("HumanoidRootPart"); if sh then SmartTP.Go(sh.Position,3); task.wait(0.5) end end
        Smuggler.FireSell(); task.wait(0.5)
        SmartTP.Go(State.POS_Laundry,3); task.wait(0.5)
    end

    Smuggler.FireLaunder()
    State.Smuggler_JobsDone = State.Smuggler_JobsDone + 1
    Log("[Cycle] Job #" .. State.Smuggler_JobsDone)
end

function Smuggler.SetAutoLoop(e)
    State.Smuggler_AutoLoop = e; if not e then Log("[Smuggler] Stop"); return end
    Log("[Smuggler] Start")
    task.spawn(function()
        while State.Smuggler_AutoLoop do
            local ok, err = pcall(Smuggler.RunCycle)
            if not ok then Log("Err: " .. tostring(err)) end
            if not State.Smuggler_AutoLoop then break end
            task.wait(State.Smuggler_Delay)
        end
    end)
end

--━ POLICE
local Police = {}
function Police.CreateFOV()
    if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
    if Drawing then State.Police_FOVCircle=Drawing.new("Circle"); State.Police_FOVCircle.Thickness=1; State.Police_FOVCircle.NumSides=60; State.Police_FOVCircle.Radius=State.Police_AimFOV; State.Police_FOVCircle.Filled=false; State.Police_FOVCircle.Visible=false; State.Police_FOVCircle.Transparency=0.7; State.Police_FOVCircle.Color=Color3.fromRGB(255,50,50) end
end
function Police.UpdateFOV() if State.Police_FOVCircle then local vp=Camera.ViewportSize; State.Police_FOVCircle.Position=Vector2.new(vp.X/2,vp.Y/2); State.Police_FOVCircle.Radius=State.Police_AimFOV; State.Police_FOVCircle.Visible=State.Police_ShowFOV and (State.Police_AutoAim or State.Police_AutoFire) end end
function Police.GetTarget()
    local myHRP=GetHRP(); if not myHRP then return nil,nil end; local vp=Camera.ViewportSize; local center=Vector2.new(vp.X/2,vp.Y/2)
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
function Vis.ServerHop() pcall(function() local TS=game:GetService("TeleportService"); local raw=game:HttpGet("https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100"); local data=HttpService:JSONDecode(raw); for _,s in ipairs(data.data or {}) do if s.playing<s.maxPlayers and s.id~=game.JobId then TS:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer); return end end end) end

CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end end)
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then h.MaxHealth=math.huge; h.Health=math.huge end end end end)
CM:Add(UserInputService.JumpRequest, function() if State.InfiniteJump then local h=GetHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end end)

local function GetSellerNames()
    local names={}; if BRP_PATHS.NPC then for _,npc in ipairs(BRP_PATHS.NPC:GetChildren()) do if npc.Name:lower():find("seller") then table.insert(names,npc.Name) end end end
    if #names==0 then table.insert(names,"Seller4") end; return names
end

if State.AntiTpBypass then AntiTpBypass.Enable() end

--━ WINDOW
local Window = Rayfield:CreateWindow({
    Name = HUB.Name .. "  v" .. HUB.Version,
    LoadingTitle = HUB.Name, LoadingSubtitle = HUB.Game .. " - by " .. HUB.Author,
    Theme = "Default", DisableRayfieldPrompts = true, DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",name="Main",icon="home"},{key="Car",name="Vehicle",icon="zap"},
    {key="Smuggler",name="Smuggler",icon="package"},{key="Police",name="Police",icon="shield"},
    {key="Teleport",name="Teleport",icon="map-pin"},{key="ESP",name="ESP",icon="eye"},
    {key="Remote",name="Remotes",icon="radio"},{key="Visuals",name="Visuals",icon="sun"},
    {key="Misc",name="Misc",icon="wrench"},{key="Settings",name="Settings",icon="settings"},
}) do local ok,tab=pcall(function() return Window:CreateTab(def.name,def.icon) end); if ok then Tabs[def.key]=tab end end

local function Sec(t,n) if t then pcall(function() t:CreateSection(n) end) end end
local function Tog(t,c) if t then pcall(function() t:CreateToggle(c) end) end end
local function Btn(t,c) if t then pcall(function() t:CreateButton(c) end) end end
local function Sld(t,c) if t then pcall(function() t:CreateSlider(c) end) end end
local function Inp(t,c) if t then pcall(function() t:CreateInput(c) end) end end
local function Lbl(t,x) if t then pcall(function() t:CreateLabel(x) end) end end
local function Kbnd(t,c) if t then pcall(function() t:CreateKeybind(c) end) end end
local function Drp(t,c) if t then pcall(function() t:CreateDropdown(c) end) end end

if Tabs.Main then
    local T=Tabs.Main
    Sec(T,"X0DEC04T Hub v"..HUB.Version)
    Lbl(T,"Stable version - no SEH crashes")
    Lbl(T,"AntiTp: "..State.AntiTpMethod.." (safe)")
    Lbl(T,"Spawner: "..(BRP_PATHS.VehicleSpawners and BRP_PATHS.VehicleSpawners.Name or "none"))
    Lbl(T,"Remotes: "..remoteCount)
    Lbl(T,"Sellers: "..#GetSellerNames())
end

if Tabs.Car then
    local T=Tabs.Car
    Sec(T,"Speed")
    Sld(T,{Name="Extra Speed",Range={0,500},Increment=10,CurrentValue=0,Flag="ES",Callback=function(v) State.CarSpeed=v; Car.ApplySpeed() end})
    Sld(T,{Name="SpeedHack Value",Range={100,2000},Increment=50,CurrentValue=500,Flag="SHV",Callback=function(v) State.SpeedHackValue=v end})
    Tog(T,{Name="Speed Hack",CurrentValue=false,Flag="SH",Callback=function(v) State.SpeedHack=v; Car.SetSpeedHack(v) end})
    Sec(T,"Actions")
    Btn(T,{Name="Flip Car",Callback=Car.Flip})
    Btn(T,{Name="Boost",Callback=Car.Boost})
    Btn(T,{Name="Unstuck",Callback=function() if BRP.UnstuckVehicle then pcall(function() BRP.UnstuckVehicle:FireServer() end) end end})
    Sec(T,"Abilities")
    Tog(T,{Name="NoClip",CurrentValue=false,Flag="NC",Callback=function(v) State.NoClip=v; Car.SetNoClip(v) end})
    Tog(T,{Name="Fly",CurrentValue=false,Flag="FL",Callback=function(v) State.FlyActive=v; Car.SetFly(v) end})
    Tog(T,{Name="God Mode",CurrentValue=false,Flag="GM",Callback=function(v) State.GodMode=v; Car.SetGod(v) end})
    Sec(T,"Character")
    Sld(T,{Name="WalkSpeed",Range={16,200},Increment=4,CurrentValue=16,Flag="WS",Callback=function(v) State.WalkSpeed=v; local h=GetHuman(); if h then h.WalkSpeed=v end end})
    Sld(T,{Name="JumpPower",Range={50,300},Increment=10,CurrentValue=50,Flag="JP",Callback=function(v) State.JumpPower=v; local h=GetHuman(); if h then h.JumpPower=v end end})
    Tog(T,{Name="Infinite Jump",CurrentValue=false,Flag="IJ",Callback=function(v) State.InfiniteJump=v end})
end

if Tabs.Smuggler then
    local T=Tabs.Smuggler
    Sec(T,"Auto Smuggler")

    Sec(T,"Item")
    Drp(T,{Name="Item to Buy",Options=GetBuyableItemNames(),CurrentOption={"Fake Diamond Ring"},MultiOption=false,Flag="ItemPick",Callback=function(v) State.Smuggler_ItemName=(type(v)=="table" and v[1]) or v end})
    Sld(T,{Name="Buy Retries",Range={1,5},Increment=1,CurrentValue=2,Flag="BR",Callback=function(v) State.Smuggler_BuyRetries=v end})

    Sec(T,"Vehicle Spawn")
    Tog(T,{Name="Auto Spawn Car",CurrentValue=true,Flag="SC",Callback=function(v) State.Smuggler_SpawnCar=v end})
    Tog(T,{Name="Remove Tires",CurrentValue=true,Flag="RT",Callback=function(v) State.Smuggler_RemoveTires=v end})
    Drp(T,{Name="Vehicle",Options={"Camry6","BorderPatrolCrownVic","2020Rs3Done","jzs171 touring","TAPVSWAT"},CurrentOption={"Camry6"},MultiOption=false,Flag="VNP",Callback=function(v) State.Smuggler_VehicleName=(type(v)=="table" and v[1]) or v end})
    Inp(T,{Name="Custom Vehicle Name",PlaceholderText="overrides dropdown",RemoveTextAfterFocusLost=false,Callback=function(v) if v~="" then State.Smuggler_VehicleName=v end end})
    Btn(T,{Name="Save Spawner Pos Here",Callback=function() local h=GetHRP(); if h then State.POS_CarSpawner=h.Position; Notify("OK","Saved",2) end end})
    Btn(T,{Name="List All Spawners",Callback=function()
        local s=FindAllSpawners(); Log("=== SPAWNERS: "..#s.." ===")
        for i,sp in ipairs(s) do Log(string.format("[%d] %s | prompt=%s | pos=%s",i,sp.container and sp.container.Name or "?",sp.prompt.Name,tostring(sp.position))) end
        Notify("Spawners","Found "..#s.." see console",4)
    end})

    Sec(T,"Car TP Method")
    Drp(T,{Name="Car TP Method",Options={"WeldTP","DirectTP","TweenVehicle"},CurrentOption={"WeldTP"},MultiOption=false,Flag="CTM",Callback=function(v) State.Smuggler_CarTPMethod=(type(v)=="table" and v[1]) or v end})
    Lbl(T,"WeldTP = safest (sit in car first)")

    Sec(T,"Equip")
    Tog(T,{Name="Auto Equip",CurrentValue=true,Flag="AE",Callback=function(v) State.Smuggler_AutoEquip=v end})
    Tog(T,{Name="Equip All Copies",CurrentValue=true,Flag="EA",Callback=function(v) State.Smuggler_EquipAll=v end})

    Sec(T,"Seller")
    Drp(T,{Name="Target Seller",Options=GetSellerNames(),CurrentOption={State.Smuggler_SellerName},MultiOption=false,Flag="SN",Callback=function(v) State.Smuggler_SellerName=(type(v)=="table" and v[1]) or v end})
    Sld(T,{Name="Sell Retries",Range={1,15},Increment=1,CurrentValue=8,Flag="SR",Callback=function(v) State.Smuggler_SellRetries=v end})

    Sec(T,"TP")
    Tog(T,{Name="AntiTp Bypass",CurrentValue=true,Flag="ATP",Callback=function(v) State.AntiTpBypass=v; if v then AntiTpBypass.Enable() else AntiTpBypass.Disable() end end})
    Drp(T,{Name="Player TP",Options={"Tween","Instant"},CurrentOption={"Tween"},MultiOption=false,Flag="TPS",Callback=function(v) State.TPStrategy=(type(v)=="table" and v[1]) or v end})
    Sld(T,{Name="Tween Speed",Range={50,1000},Increment=25,CurrentValue=200,Flag="TWS",Callback=function(v) State.TweenSpeed=v end})

    Sec(T,"Timing")
    Sld(T,{Name="Cycle Delay",Range={0,10},Increment=1,CurrentValue=1,Flag="SD",Callback=function(v) State.Smuggler_Delay=v end})
    Tog(T,{Name="Use Remote Backup",CurrentValue=true,Flag="UR",Callback=function(v) State.Smuggler_UseRemotes=v end})
    Tog(T,{Name="Auto Launder",CurrentValue=true,Flag="AL",Callback=function(v) State.Smuggler_AutoLaunder=v end})
    Tog(T,{Name="Debug Mode",CurrentValue=true,Flag="DBG",Callback=function(v) State.Smuggler_DebugMode=v end})

    Sec(T,"Main")
    Tog(T,{Name="Auto Smuggler Loop",CurrentValue=false,Flag="AS",Callback=function(v) Smuggler.SetAutoLoop(v) end})

    Sec(T,"Manual")
    Btn(T,{Name="TP to Spawner",Callback=function() local sp=FindNearestSpawner(); if sp then SmartTP.Go(sp.position,3) else SmartTP.Go(State.POS_CarSpawner,3) end end})
    Btn(T,{Name="1. Buy Item",Callback=function() task.spawn(Smuggler.BuyItem) end})
    Btn(T,{Name="2. Spawn Car",Callback=function() task.spawn(Smuggler.SpawnCar) end})
    Btn(T,{Name="3. Sit In Car",Callback=function() task.spawn(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.SitInCar(c) else Notify("Err","No car",3) end end) end})
    Btn(T,{Name="4. Remove Tires",Callback=function() task.spawn(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.RemoveTires(c) else Notify("Err","No car",3) end end) end})
    Btn(T,{Name="5. TP Car -> Seller",Callback=function() task.spawn(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.TeleportCarToSeller(c) else Notify("Err","No car",3) end end) end})
    Btn(T,{Name="6. Sell",Callback=function() task.spawn(Smuggler.FireSell) end})
    Btn(T,{Name="7. TP Car -> Laundry",Callback=function() task.spawn(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); Smuggler.TeleportCarToLaundry(c) end) end})
    Btn(T,{Name="8. Launder",Callback=function() task.spawn(Smuggler.FireLaunder) end})
end

if Tabs.Police then
    local T=Tabs.Police
    Tog(T,{Name="Wanted Only",CurrentValue=true,Flag="TW",Callback=function(v) State.Police_TargetWanted=v end})
    Tog(T,{Name="Target All",CurrentValue=false,Flag="TA",Callback=function(v) State.Police_TargetAll=v end})
    Sld(T,{Name="Min Wanted",Range={1,10},Increment=1,CurrentValue=1,Flag="MWL",Callback=function(v) State.Police_MinWantedLevel=v end})
    Drp(T,{Name="Aim Part",Options={"Head","HumanoidRootPart","UpperTorso"},CurrentOption={"Head"},MultiOption=false,Flag="AP",Callback=function(v) State.Police_AimPart=(type(v)=="table" and v[1]) or v end})
    Sld(T,{Name="FOV",Range={30,500},Increment=10,CurrentValue=150,Flag="AFOV",Callback=function(v) State.Police_AimFOV=v end})
    Sld(T,{Name="Smoothness",Range={1,20},Increment=1,CurrentValue=1,Flag="ASM",Callback=function(v) State.Police_AimSmooth=v end})
    Tog(T,{Name="Show FOV",CurrentValue=true,Flag="SFOV",Callback=function(v) State.Police_ShowFOV=v end})
    Tog(T,{Name="Auto-Aim (RMB)",CurrentValue=false,Flag="AAim",Callback=function(v) Police.SetAutoAim(v) end})
    Tog(T,{Name="Auto-Fire",CurrentValue=false,Flag="AFire",Callback=function(v) Police.SetAutoFire(v) end})
    Tog(T,{Name="Auto-Arrest",CurrentValue=false,Flag="AArr",Callback=function(v) Police.SetAutoArrest(v) end})
end

if Tabs.Teleport then
    local T=Tabs.Teleport
    Inp(T,{Name="Player Name",PlaceholderText="Case-sensitive",RemoveTextAfterFocusLost=false,Callback=function(v) State.TP_Target=v end})
    Btn(T,{Name="TP to Player",Callback=function() Car.TeleportToPlayer(State.TP_Target) end})
    Sec(T,"Quick")
    Btn(T,{Name="Shop",Callback=function() SmartTP.Go(State.POS_Shop,3) end})
    Btn(T,{Name="Laundry",Callback=function() SmartTP.Go(State.POS_Laundry,3) end})
    Btn(T,{Name="Car Spawner",Callback=function() local sp=FindNearestSpawner(); if sp then SmartTP.Go(sp.position,3) else SmartTP.Go(State.POS_CarSpawner,3) end end})
    Sec(T,"Sellers")
    for _,name in ipairs(GetSellerNames()) do
        Btn(T,{Name="TP "..name,Callback=function() local npc=BRP_PATHS.NPC and BRP_PATHS.NPC:FindFirstChild(name); if npc then local h=npc:FindFirstChild("HumanoidRootPart"); if h then SmartTP.Go(h.Position,3) end end end})
    end
end

if Tabs.ESP then
    local T=Tabs.ESP
    Tog(T,{Name="All Players",CurrentValue=false,Flag="PE",Callback=function(v) State.ESP_Players=v end})
    Tog(T,{Name="Wanted (Red)",CurrentValue=false,Flag="WE",Callback=function(v) State.ESP_Wanted=v end})
    Tog(T,{Name="Police (Blue)",CurrentValue=false,Flag="POE",Callback=function(v) State.ESP_Police=v end})
    Tog(T,{Name="Names",CurrentValue=true,Flag="EN",Callback=function(v) State.ESP_ShowName=v; for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end end})
    Tog(T,{Name="Distance",CurrentValue=true,Flag="ED",Callback=function(v) State.ESP_ShowDist=v; for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end end})
    Sld(T,{Name="Max Dist",Range={100,5000},Increment=100,CurrentValue=800,Flag="EMD",Callback=function(v) State.ESP_MaxDist=v end})
    Btn(T,{Name="Refresh",Callback=function() ESP.ClearAll(); ESP.RefreshAll() end})
end

if Tabs.Remote then
    local T=Tabs.Remote
    Lbl(T,"Total: "..#RemoteDBAll)
    Inp(T,{Name="Name",PlaceholderText="Remote name",RemoveTextAfterFocusLost=false,Callback=function(v) State.RemoteName=v end})
    Inp(T,{Name="Arg",PlaceholderText="Optional",RemoveTextAfterFocusLost=false,Callback=function(v) State.RemoteArg=v end})
    Btn(T,{Name="Fire",Callback=function()
        local r=FindRemote(State.RemoteName); if not r then Notify("Remote","Not found",3); return end
        local a=State.RemoteArg; local n=tonumber(a); if n then a=n end; if a=="true" then a=true elseif a=="false" then a=false end
        pcall(function() if r:IsA("RemoteEvent") then r:FireServer(a) else r:InvokeServer(a) end end); Notify("Remote","Fired "..r.Name,2)
    end})
end

if Tabs.Visuals then
    local T=Tabs.Visuals
    Tog(T,{Name="FullBright",CurrentValue=false,Flag="FB",Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    Tog(T,{Name="No Fog",CurrentValue=false,Flag="NF",Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    Sld(T,{Name="Time",Range={0,24},Increment=1,CurrentValue=14,Flag="TOD",Callback=function(v) Vis.SetClock(v) end})
    Sld(T,{Name="FOV",Range={30,120},Increment=5,CurrentValue=70,Flag="FOV2",Callback=function(v) State.FOV=v; Vis.SetFOV(v) end})
end

if Tabs.Misc then
    local T=Tabs.Misc
    Tog(T,{Name="Mute All",CurrentValue=false,Flag="MA",Callback=function(v) Vis.MuteAll(v) end})
    Btn(T,{Name="Server Hop",Callback=Vis.ServerHop})
    Btn(T,{Name="Rejoin",Callback=function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId,LocalPlayer) end) end})
    Btn(T,{Name="Copy Position",Callback=function() local h=GetHRP(); if h then local p=h.Position; local s=string.format("Vector3.new(%.2f,%.2f,%.2f)",p.X,p.Y,p.Z); if setclipboard then setclipboard(s) end; Notify("Copied",s,3) end end})
end

if Tabs.Settings then
    local T=Tabs.Settings
    Tog(T,{Name="Anti-AFK",CurrentValue=true,Flag="AA",Callback=function(v) State.AntiAFK=v end})
    Kbnd(T,{Name="Toggle UI",CurrentKeybind="RightShift",HoldToInteract=false,Flag="KUI",Callback=function() pcall(function() Window:Toggle() end) end})
    Kbnd(T,{Name="Panic",CurrentKeybind="End",HoldToInteract=false,Flag="KP",Callback=function() ESP.ClearAll(); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false); Smuggler.SetAutoLoop(false); Notify("PANIC","Off",3) end})
    Lbl(T,HUB.Name.." v"..HUB.Version)
    Btn(T,{Name="Unload",Callback=function()
        Smuggler.SetAutoLoop(false); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTpBypass.Disable(); DisableTweenNoclip()
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
        if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
        CM:Cleanup(); Vis.RestoreLight(); Vis.MuteAll(false); ESP.ClearAll(); _G[INSTANCE_KEY]=nil
        pcall(function() Window:Destroy() end)
    end})
end

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGod,true) end
    if State.NoClip then pcall(Car.SetNoClip,true) end
    if State.FlyActive then pcall(Car.SetFly,true) end
    if State.FullBright then pcall(Vis.FullBright,true) end
    if State.AntiTpBypass then AntiTpBypass.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        Smuggler.SetAutoLoop(false); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTpBypass.Disable(); DisableTweenNoclip()
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
        CM:Cleanup(); ESP.ClearAll(); pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." loaded (stable)", 4)
Log("v2.9.5 ready | AntiTp: hide | Spawner: "..(BRP_PATHS.VehicleSpawners and BRP_PATHS.VehicleSpawners.Name or "none"))
