--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v4.0.5 - IN-CAR FLOW
-- Never exit car. Drive through buy → sell → laundry
--═══════════════════════════════════════════════════════════════

local LOGO_ASSET_ID = 132469099334813

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
local VIM               = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local INSTANCE_KEY = "__X0DEC04T_BRP_v405"
if _G[INSTANCE_KEY] then
    pcall(function() _G[INSTANCE_KEY].destroy() end)
    _G[INSTANCE_KEY] = nil
    task.wait(0.2)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("Starting v4.0.5 IN-CAR FLOW...")

local function safeCB(fn)
    if not fn then return function() end end
    return function(...)
        local args = table.pack(...)
        task.defer(function()
            local ok, err = pcall(function() fn(table.unpack(args, 1, args.n)) end)
            if not ok then Log("CB err: " .. tostring(err)) end
        end)
    end
end

local WindUI
local ok, err = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not ok or not WindUI then warn("[X0DEC04T] WindUI failed"); return end

local HUB = { Name="X0DEC04T Hub", Version="4.0.5" }

local CM = { _list = {} }
function CM:Add(sig, cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list, c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

local RemotesFolder = ReplicatedStorage:WaitForChild("__remotes", 5)
local function GetRemote(path)
    if not RemotesFolder then return nil end
    local c = RemotesFolder
    for seg in string.gmatch(path, "[^%.]+") do c = c:FindFirstChild(seg); if not c then return nil end end
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
    UnstuckVehicle          = GetRemote("VehicleService.UnstuckVehicle"),
}

BRP.ApplyRollbackCFrame = nil
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
        local n = obj.Name:lower()
        if n:find("rollback") or n:find("antitp") then
            BRP.ApplyRollbackCFrame = obj
            break
        end
    end
end

local BRP_PATHS = {
    NPC = Workspace:FindFirstChild("NPC"),
    Vehicles = Workspace:FindFirstChild("Vehicles"),
    LaunderTrigger = nil,
    WorldBuyableItems = Workspace:FindFirstChild("WorldBuyableItems"),
    VehicleSpawners = Workspace:FindFirstChild("VehicleSpawners"),
}
pcall(function()
    local lp = Workspace:FindFirstChild("LaunderPrompts")
    if lp then BRP_PATHS.LaunderTrigger = lp:FindFirstChild("LaunderTrigger") end
end)

local State = {
    Smuggler_AutoLoop=false, Smuggler_JobsDone=0,
    Smuggler_UseRemotes=true, Smuggler_AutoLaunder=true,
    Smuggler_ItemName="Fake Diamond Ring", Smuggler_SellerName="Seller4",
    Smuggler_VehicleName="Tayora Cambria", 
    Smuggler_BuyRetries=5, Smuggler_SellRetries=10, Smuggler_LaunderRetries=6,
    Smuggler_Delay=1, Smuggler_DebugMode=true,
    Smuggler_AutoEquip=true, Smuggler_EquipAll=true,
    Smuggler_RemoveTires=true, Smuggler_SpawnCar=true, Smuggler_CurrentCar=nil,
    Smuggler_ChunkSize=20, Smuggler_StepDelay=0.05,
    TPStrategy="Instant", TweenSpeed=200, TweenNoclip=true,
    AntiTpBypass=true, AntiClipBypass=true, SafeLanding=true, NoFallDamage=true,
    POS_Shop=Vector3.new(6823.57,17.40,-20.00),
    POS_Laundry=Vector3.new(6804.78,17.43,-34.70),
    POS_CarSpawner=Vector3.new(6840,17,-30),
    CarSpeed=0, SpeedHack=false, SpeedHackConn=nil, SpeedHackValue=500,
    FlyActive=false, FlyConn=nil, GodMode=false,
    NoclipConn=nil, NoClip=false,
    WalkSpeed=16, JumpPower=50, InfiniteJump=false,
    Police_AutoAim=false, Police_AutoFire=false, Police_AutoArrest=false,
    Police_AimPart="Head", Police_AimFOV=150, Police_AimSmooth=1,
    Police_TargetWanted=true, Police_MinWantedLevel=1, Police_TargetAll=false,
    Police_ShowFOV=true, Police_FOVCircle=nil,
    Police_AimConn=nil, Police_FireConn=nil, Police_ArrestConn=nil, Police_CurrentTarget=nil,
    ESP_Players=false, ESP_Wanted=false, ESP_Police=false,
    ESP_ShowName=true, ESP_ShowDist=true, ESP_MaxDist=800, ESPCache={},
    Color_Player=Color3.fromRGB(60,220,255), Color_Wanted=Color3.fromRGB(255,50,50), Color_Police=Color3.fromRGB(60,120,255),
    FullBright=false, NoFog=false, FOV=70, AntiAFK=true,
    MutedSounds={}, LightBackup={}, TP_Target="",
    ACFlyEnabled=true,
}

local function GetChar() return LocalPlayer.Character end
local function GetHRP() local ch=GetChar(); return ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")) end
local function GetHuman() local ch=GetChar(); return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end
local function GetPlayerCar()
    local ch=GetChar(); if not ch then return nil end
    for _,seat in ipairs(Workspace:GetDescendants()) do
        if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) and seat.Occupant and seat.Occupant.Parent==ch then
            return seat:FindFirstAncestorOfClass("Model"), seat
        end
    end
    return nil
end
local function GetVehicleSeat() local c=GetPlayerCar(); return c and (c:FindFirstChildOfClass("VehicleSeat") or c:FindFirstChildWhichIsA("VehicleSeat",true)) end
local function GetCarRoot() local c=GetPlayerCar(); return c and (c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")) end
local function GetWantedLevel(p) return tonumber(p and p:GetAttribute("WantedLevel")) or 0 end
local function IsWanted(p) return GetWantedLevel(p)>=(State.Police_MinWantedLevel or 1) end
local function GetRank(p) return tostring(p and p:GetAttribute("CurrentRankName") or "Unknown") end
local function IsSeatedIn(car)
    if not car then return false end
    local hum = GetHuman(); if not hum then return false end
    for _,o in ipairs(car:GetDescendants()) do
        if (o:IsA("VehicleSeat") or o:IsA("Seat")) and o.Occupant == hum then return true end
    end
    return false
end

--━ ANTITP
local AntiTp = { enabled=false, hidden={}, holds=0, remotes={} }
local function ScanAC()
    local list = {}
    if BRP.ApplyRollbackCFrame then table.insert(list, BRP.ApplyRollbackCFrame) end
    for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            if n:find("rollback") or n:find("antitp") or n:find("anticheat") or n:find("teleportdet") or n:find("kickplayer") then
                if not table.find(list, obj) then table.insert(list, obj) end
            end
        end
    end
    return list
end
function AntiTp.Enable() AntiTp.enabled=true; AntiTp.remotes=ScanAC(); Log("[AntiTp] "..#AntiTp.remotes.." AC remotes") end
function AntiTp.Disable() AntiTp.enabled=false; AntiTp.Release(true) end
function AntiTp.Hold()
    if not AntiTp.enabled then return end
    AntiTp.holds = AntiTp.holds + 1
    for _,r in ipairs(AntiTp.remotes) do
        if r and r.Parent and not AntiTp.hidden[r] then
            AntiTp.hidden[r] = r.Parent
            pcall(function() r.Parent = nil end)
        end
    end
end
function AntiTp.Release(force)
    if not force then AntiTp.holds=math.max(0,AntiTp.holds-1); if AntiTp.holds>0 then return end
    else AntiTp.holds=0 end
    for r,p in pairs(AntiTp.hidden) do if r and p then pcall(function() r.Parent=p end) end end
    AntiTp.hidden = {}
end
task.spawn(function() while true do task.wait(6); if next(AntiTp.hidden) and AntiTp.holds==0 then AntiTp.Release(true) end end end)

--━ AC FLY
local ACFly = { enabled=false, conn=nil, fakeGroundConn=nil, groundSpoof=nil, lastGroundTime=tick() }
function ACFly.Enable()
    if ACFly.enabled then return end
    ACFly.enabled = true; ACFly.lastGroundTime = tick()
    ACFly.conn = RunService.Heartbeat:Connect(function()
        if not ACFly.enabled then return end
        local hrp = GetHRP(); if not hrp then return end
        local ch = GetChar()
        local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
        if ch then rp.FilterDescendantsInstances = {ch} end
        local ray = Workspace:Raycast(hrp.Position, Vector3.new(0,-6,0), rp)
        if ray then
            ACFly.lastGroundTime = tick()
            if ACFly.groundSpoof and ACFly.groundSpoof.Parent then pcall(function() ACFly.groundSpoof:Destroy() end); ACFly.groundSpoof = nil end
        else
            if tick() - ACFly.lastGroundTime > 2.2 and State.FlyActive and not ACFly.groundSpoof then
                pcall(function()
                    local fake = Instance.new("Part")
                    fake.Name = "__ACFakeGround"; fake.Size = Vector3.new(12,1,12)
                    fake.Transparency = 1; fake.Anchored = true; fake.CanCollide = true; fake.CanQuery = false
                    fake.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3.6, 0)); fake.Parent = Workspace
                    ACFly.groundSpoof = fake
                    game:GetService("Debris"):AddItem(fake, 0.25)
                    task.delay(0.2, function() ACFly.lastGroundTime = tick(); ACFly.groundSpoof = nil end)
                end)
            end
        end
    end)
end
function ACFly.Disable()
    if not ACFly.enabled then return end
    ACFly.enabled = false
    if ACFly.conn then pcall(function() ACFly.conn:Disconnect() end); ACFly.conn=nil end
    if ACFly.groundSpoof and ACFly.groundSpoof.Parent then pcall(function() ACFly.groundSpoof:Destroy() end); ACFly.groundSpoof=nil end
end

--━ FALL GUARD
local FallGuard = { conns={} }
local function ClearFG() for _,c in ipairs(FallGuard.conns) do pcall(function() c:Disconnect() end) end; FallGuard.conns={} end
function FallGuard.Enable()
    ClearFG()
    local h = GetHuman(); if not h then return end
    local c1 = h.StateChanged:Connect(function(_, new)
        if not State.NoFallDamage then return end
        if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.FallingDown then
            pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)
    table.insert(FallGuard.conns, c1)
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
end
function FallGuard.Disable() ClearFG() end

local function FindGroundBelow(pos)
    local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
    local ch = GetChar(); if ch then rp.FilterDescendantsInstances = {ch} end
    local r = Workspace:Raycast(pos + Vector3.new(0,5,0), Vector3.new(0,-500,0), rp)
    if r then return r.Position + Vector3.new(0, 3, 0) end
end

local function FindSafeCarGround(pos, car)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ch = GetChar()
    local excl = {}
    if car then table.insert(excl, car) end
    if ch then table.insert(excl, ch) end
    rp.FilterDescendantsInstances = excl
    local from = pos + Vector3.new(0, 80, 0)
    local r = Workspace:Raycast(from, Vector3.new(0, -400, 0), rp)
    if r then return r.Position + Vector3.new(0, 4.5, 0), true end
    return pos + Vector3.new(0, 5, 0), false
end

--━ TP (foot)
local SmartTP = {}
local _nc = nil
local function EnableNC() if _nc then return end; _nc = RunService.Stepped:Connect(function() local ch=GetChar(); if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end end end end) end
local function DisableNC() if _nc then pcall(function() _nc:Disconnect() end); _nc=nil end end
local function ZeroVel()
    local ch=GetChar(); if not ch then return end
    for _,p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end) end
    end
end
local function PrepTP(h) if h then pcall(function() h.PlatformStand=true; h:ChangeState(Enum.HumanoidStateType.Physics) end) end; ZeroVel() end
local function RecoverTP(h)
    ZeroVel()
    local hrp = GetHRP()
    if hrp then local wa=hrp.Anchored; pcall(function() hrp.Anchored=true end); task.wait(0.15); ZeroVel(); pcall(function() hrp.Anchored=wa end) end
    if h then pcall(function() h.PlatformStand=false; h:ChangeState(Enum.HumanoidStateType.GettingUp) end); task.wait(0.05); pcall(function() h:ChangeState(Enum.HumanoidStateType.Landed) end) end
    ZeroVel()
end
function SmartTP.Instant(pos, yOff)
    if not pos then return end
    local hrp=GetHRP(); if not hrp then return end
    local hum=GetHuman()
    local tp = pos + Vector3.new(0, yOff or 3, 0)
    if State.SafeLanding then local g=FindGroundBelow(pos); if g then tp=g end end
    PrepTP(hum)
    pcall(function() hrp.CFrame = CFrame.new(tp) end)
    task.wait(0.2); RecoverTP(hum); task.wait(0.1)
    return true
end
function SmartTP.Go(pos, yOff)
    if State.AntiTpBypass then AntiTp.Hold() end
    local r = SmartTP.Instant(pos, yOff)
    if State.AntiTpBypass then task.delay(3,function() pcall(AntiTp.Release) end) end
    return r
end
function SmartTP.WalkTo(targetPos, timeout)
    local hum = GetHuman(); local hrp = GetHRP()
    if not hum or not hrp then return false end
    local origWS = hum.WalkSpeed
    pcall(function() hum.WalkSpeed = 32 end)
    local reached = false
    local conn = hum.MoveToFinished:Connect(function(r) reached = r end)
    pcall(function() hum:MoveTo(targetPos) end)
    local t0 = tick()
    while not reached and tick()-t0 < (timeout or 5) do
        task.wait(0.1)
        if tick()-t0 > 1 and (hrp.Position - targetPos).Magnitude > 3 then
            pcall(function() hum:MoveTo(targetPos) end)
        end
    end
    if conn then pcall(function() conn:Disconnect() end) end
    pcall(function() hum.WalkSpeed = origWS end)
    return reached or (hrp.Position - targetPos).Magnitude < 5
end

--━ CAR DRIVE (seated, no anchor) - can penetrate to exact target
function SmartTP.CarDrive(car, targetPos, targetLookAt, penetrate)
    if not car or not car.Parent then Log("[CarDrive] no car"); return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then Log("[CarDrive] no root"); return false end
    if not IsSeatedIn(car) then
        Log("[CarDrive] NOT SEATED - refusing (would despawn)")
        return false
    end

    local finalPos
    if penetrate then
        -- Penetrate mode: teleport EXACTLY to target (into object), no ground raycast
        finalPos = targetPos
    else
        finalPos = FindSafeCarGround(targetPos, car)
    end

    local yaw = 0
    if targetLookAt then
        local dir = Vector3.new(targetLookAt.X, finalPos.Y, targetLookAt.Z) - finalPos
        if dir.Magnitude > 0.1 then
            local flat = dir.Unit
            yaw = math.atan2(-flat.X, -flat.Z)
        end
    end
    local targetCF = CFrame.new(finalPos) * CFrame.Angles(0, yaw, 0)

    AntiTp.Hold()

    local startCF = root.CFrame
    local totalDist = (targetCF.Position - startCF.Position).Magnitude
    local chunkSize = State.Smuggler_ChunkSize or 20
    local chunks = math.max(2, math.ceil(totalDist / chunkSize))

    Log(string.format("[CarDrive] %.0f studs in %d chunks (penetrate=%s)", totalDist, chunks, tostring(penetrate)))

    for i = 1, chunks do
        if not car.Parent or not root.Parent then
            Log("[CarDrive] car despawned mid-move!")
            task.delay(2, function() pcall(AntiTp.Release) end)
            return false
        end
        local alpha = i / chunks
        local stepPos = startCF.Position:Lerp(targetCF.Position, alpha)
        local stepCF
        if penetrate and i == chunks then
            -- Last chunk goes exactly to penetrate point
            stepCF = CFrame.new(stepPos) * CFrame.Angles(0, yaw, 0)
        elseif penetrate then
            -- Intermediate chunks stay above ground
            local safe = FindSafeCarGround(stepPos, car)
            stepCF = CFrame.new(safe) * CFrame.Angles(0, yaw, 0)
        else
            local safe = FindSafeCarGround(stepPos, car)
            stepCF = CFrame.new(safe) * CFrame.Angles(0, yaw, 0)
        end
        pcall(function()
            if car:IsA("Model") then car:PivotTo(stepCF) else root.CFrame = stepCF end
        end)
        for _,p in ipairs(car:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        task.wait(State.Smuggler_StepDelay or 0.05)
    end

    pcall(function()
        if car:IsA("Model") then car:PivotTo(targetCF) else root.CFrame = targetCF end
    end)
    for _,p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
    task.wait(0.2)
    task.delay(3, function() pcall(AntiTp.Release) end)
    return true
end

--━ ESP
local ESP = {}
function ESP.Clear(o) local c=State.ESPCache[o]; if not c then return end; for _,i in pairs(c) do if typeof(i)=="Instance" and i.Parent then pcall(function() i:Destroy() end) end end; State.ESPCache[o]=nil end
function ESP.ClearAll() for o in pairs(State.ESPCache) do ESP.Clear(o) end; State.ESPCache={} end
function ESP.AddTarget(a,model,label,color)
    if State.ESPCache[a] then ESP.Clear(a) end
    local hl=Instance.new("Highlight"); hl.Adornee=model or a; hl.FillColor=color; hl.OutlineColor=Color3.new(1,1,1); hl.FillTransparency=0.5; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=GuiParent()
    local bb=Instance.new("BillboardGui"); bb.Adornee=a; bb.Size=UDim2.new(0,260,0,55); bb.StudsOffset=Vector3.new(0,4,0); bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.MaxDistance=State.ESP_MaxDist; bb.Parent=GuiParent()
    local nl=Instance.new("TextLabel",bb); nl.Size=UDim2.new(1,0,0.6,0); nl.BackgroundTransparency=1; nl.Text=label; nl.TextColor3=color; nl.TextStrokeTransparency=0; nl.Font=Enum.Font.GothamBold; nl.TextSize=14
    local dl=Instance.new("TextLabel",bb); dl.Size=UDim2.new(1,0,0.4,0); dl.Position=UDim2.new(0,0,0.6,0); dl.BackgroundTransparency=1; dl.Text="0m"; dl.TextColor3=Color3.fromRGB(220,220,220); dl.TextStrokeTransparency=0; dl.Font=Enum.Font.Gotham; dl.TextSize=12
    State.ESPCache[a]={hl=hl,bb=bb,nl=nl,dl=dl,hrp=a}
end
function ESP.UpdateDist() local hrp=GetHRP(); if not hrp then return end; for _,c in pairs(State.ESPCache) do if c.dl and c.hrp and c.hrp.Parent then c.dl.Text=math.floor((c.hrp.Position-hrp.Position).Magnitude).."m" end end end
function ESP.ScanPlayers()
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character then
            local hrp=p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local wanted=IsWanted(p); local wl=GetWantedLevel(p); local rank=GetRank(p)
                local isPolice=rank:lower():find("police") or rank:lower():find("cop")
                local show,color,label=false,State.Color_Player,p.Name.." ["..rank.."]"
                if State.ESP_Wanted and wanted then show=true;color=State.Color_Wanted;label=p.Name.." [W"..wl.."]"
                elseif State.ESP_Police and isPolice then show=true;color=State.Color_Police;label="[P] "..p.Name
                elseif State.ESP_Players then show=true end
                if show and not State.ESPCache[hrp] then ESP.AddTarget(hrp,p.Character,label,color) elseif not show then ESP.Clear(hrp) end
            end
        end
    end
end
task.spawn(function() while task.wait(2) do pcall(function() for o in pairs(State.ESPCache) do if not o or not o.Parent then ESP.Clear(o) end end; ESP.ScanPlayers() end) end end)
CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDist) end)

--━ CAR
local Car = {}
function Car.ApplySpeed() local s=GetVehicleSeat(); if s then pcall(function() s.MaxSpeed=100+(State.CarSpeed or 0) end) end end
function Car.SetSpeedHack(e) if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn=nil end; if e then State.SpeedHackConn=RunService.Heartbeat:Connect(function() local s=GetVehicleSeat(); if s then pcall(function() s.MaxSpeed=State.SpeedHackValue end) end end) end end
function Car.Flip() local c=GetPlayerCar(); if c then local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then pcall(function() r.CFrame=CFrame.new(r.Position) end) end end end
function Car.Boost() local r=GetCarRoot(); if not r then return end; local bv=Instance.new("BodyVelocity"); bv.Velocity=r.CFrame.LookVector*400; bv.MaxForce=Vector3.new(math.huge,0,math.huge); bv.Parent=r; game:GetService("Debris"):AddItem(bv,0.3) end
function Car.SetNoClip(e) if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn=nil end; if e then State.NoclipConn=RunService.Stepped:Connect(function() local car=GetPlayerCar(); if car then for _,p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end end end; local ch=GetChar(); if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end end end end) end end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local h=GetHuman()
    if e then
        if h then pcall(function() h.PlatformStand=true end) end
        local hrp=GetHRP()
        if hrp then
            local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=9e4; bg.CFrame=hrp.CFrame; bg.Parent=hrp; bg.Name="__FG"
            local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=9e4; bv.Parent=hrp; bv.Name="__FV"
            State.FlyConn=RunService.RenderStepped:Connect(function()
                local h2=GetHRP(); if not h2 then return end
                local bg2=h2:FindFirstChild("__FG"); local bv2=h2:FindFirstChild("__FV"); if not bg2 or not bv2 then return end
                local spd=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 150 or 70
                local cf=Camera.CFrame; local mv=Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.yAxis end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.yAxis end
                bv2.Velocity=mv*spd; bg2.CFrame=cf
            end)
        end
        if State.ACFlyEnabled then ACFly.Enable() end
    else
        if h then pcall(function() h.PlatformStand=false end) end
        local hrp=GetHRP()
        if hrp then local a=hrp:FindFirstChild("__FG"); local b=hrp:FindFirstChild("__FV"); if a then a:Destroy() end; if b then b:Destroy() end end
        ACFly.Disable()
    end
end
function Car.SetGod(e) local h=GetHuman(); if h then pcall(function() if e then h.MaxHealth=math.huge; h.Health=math.huge else h.MaxHealth=100; h.Health=100 end end) end end

-- SPAWNER
local function FindAllSpawners()
    local spawners = {}
    if not BRP_PATHS.VehicleSpawners then return spawners end
    for _, obj in ipairs(BRP_PATHS.VehicleSpawners:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Name:lower() == "proximityprompt" then
            local part = obj.Parent
            while part and not part:IsA("BasePart") do part = part.Parent end
            if part then
                local container = part.Parent
                while container and container.Parent ~= BRP_PATHS.VehicleSpawners do
                    container = container.Parent
                    if not container then break end
                end
                table.insert(spawners, { prompt=obj, part=part, container=container or part.Parent, position=part.Position })
            end
        end
    end
    return spawners
end
local function FindNearestSpawner()
    local hrp = GetHRP(); if not hrp then return nil end
    local best, bd = nil, math.huge
    for _, s in ipairs(FindAllSpawners()) do
        local d = (s.position - hrp.Position).Magnitude
        if d < bd then best = s; bd = d end
    end
    return best
end

local SpawnUI = {}
function SpawnUI.WaitForGui(timeout)
    local t0 = tick()
    while tick() - t0 < (timeout or 4) do
        local gui = PlayerGui:FindFirstChild("VehicleSpawnerGui")
        if gui and gui.Enabled then
            local frame = gui:FindFirstChild("Frame")
            if frame and frame.Visible then return gui end
        end
        task.wait(0.1)
    end
    return nil
end
function SpawnUI.FindVehicleCard(gui, displayName)
    if not gui or not displayName then return nil end
    local target = displayName:lower():gsub("%s+", "")
    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            local txt = tostring(obj.Text or ""):lower():gsub("%s+", "")
            if txt == target then return obj.Parent, obj end
        end
    end
    return nil
end
function SpawnUI.ClickCard(card)
    if not card then return false end
    local clickTarget = card
    if not (card:IsA("TextButton") or card:IsA("ImageButton")) then
        for _, c in ipairs(card:GetDescendants()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then clickTarget = c; break end
        end
    end
    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(clickTarget.MouseButton1Click)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(clickTarget.MouseButton1Down)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(clickTarget.Activated)) do pcall(function() conn:Fire() end) end
        end
    end)
    if clickTarget.AbsolutePosition and clickTarget.AbsoluteSize then
        pcall(function()
            local c = clickTarget.AbsolutePosition + clickTarget.AbsoluteSize/2
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0); task.wait(0.05)
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        end)
    end
    return true
end
function SpawnUI.ClickBuyButton(gui)
    if not gui then return false end
    local frame = gui:FindFirstChild("Frame"); if not frame then return false end
    local detail = frame:FindFirstChild("Detail"); if not detail then return false end
    local buyBtn = detail:FindFirstChild("BuyButton"); if not buyBtn then return false end
    pcall(function()
        if getconnections then
            for _, conn in ipairs(getconnections(buyBtn.MouseButton1Click)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(buyBtn.MouseButton1Down)) do pcall(function() conn:Fire() end) end
            for _, conn in ipairs(getconnections(buyBtn.Activated)) do pcall(function() conn:Fire() end) end
        end
    end)
    if buyBtn.AbsolutePosition and buyBtn.AbsoluteSize then
        pcall(function()
            local c = buyBtn.AbsolutePosition + buyBtn.AbsoluteSize/2
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, true, game, 0); task.wait(0.05)
            VIM:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        end)
    end
    return true
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

--━ SMUGGLER (IN-CAR FLOW)
local Smuggler = {}
function Smuggler.FirePrompt(prompt)
    if not prompt then return end
    pcall(function() if fireproximityprompt then fireproximityprompt(prompt, 0.25) end end)
end
function Smuggler.EquipAll(tn)
    local bp=LocalPlayer:FindFirstChild("Backpack"); if not bp then return end
    local h=GetHuman(); if not h then return end
    for _,t in ipairs(bp:GetChildren()) do if t:IsA("Tool") and t.Name==tn then pcall(function() h:EquipTool(t) end); task.wait(0.15) end end
end
function Smuggler.EquipTool(tn)
    local ch=GetChar(); local bp=LocalPlayer:FindFirstChild("Backpack"); if not ch or not bp then return end
    if ch:FindFirstChild(tn) then return end
    local t=bp:FindFirstChild(tn); if t then local h=GetHuman(); if h then pcall(function() h:EquipTool(t) end); task.wait(0.3) end end
end
function Smuggler.GetBuyPrompt()
    if not BRP_PATHS.WorldBuyableItems then return end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(State.Smuggler_ItemName); if not item then return end
    for _,obj in ipairs(item:GetDescendants()) do if obj:IsA("ProximityPrompt") then return obj, item end end
end
function Smuggler.GetItemPos()
    if not BRP_PATHS.WorldBuyableItems then return end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(State.Smuggler_ItemName); if not item then return end
    local h=item:FindFirstChild("Handle"); if h and h:IsA("BasePart") then return h.Position end
    local p=item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart",true); return p and p.Position
end
function Smuggler.GetSellPrompt()
    if not BRP_PATHS.NPC then return end
    local seller = BRP_PATHS.NPC:FindFirstChild(State.Smuggler_SellerName)
    if not seller then return end
    local hrp = seller:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    return hrp:FindFirstChild("SellSmuggledGoodsPrompt"), seller
end
function Smuggler.GetSellerPos()
    local _, seller = Smuggler.GetSellPrompt()
    if not seller then return nil end
    local h = seller:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end
function Smuggler.GetLaunderPrompt()
    if BRP_PATHS.LaunderTrigger then 
        local pp = BRP_PATHS.LaunderTrigger:FindFirstChild("PromptPart")
        if pp then return pp:FindFirstChild("LaunderBriefcasePrompt") end 
    end
end
function Smuggler.GetLaunderPos()
    if BRP_PATHS.LaunderTrigger then
        local pp = BRP_PATHS.LaunderTrigger:FindFirstChild("PromptPart")
        if pp then return pp.Position end
    end
    return State.POS_Laundry
end

--━━━ STEP 1: SPAWN CAR ━━━
function Smuggler.SpawnCar()
    local vname = State.Smuggler_VehicleName
    if vname == "" then vname = "Tayora Cambria" end
    Log("[1] Spawn " .. vname)
    local spawner = FindNearestSpawner()
    if not spawner then Log("[1] No spawner"); return nil end
    SmartTP.Go(spawner.position + Vector3.new(0, 0, 3), 3)
    task.wait(0.4)
    SmartTP.WalkTo(spawner.position, 3)
    task.wait(0.5)
    local existing = {}
    if BRP_PATHS.Vehicles then 
        for _,v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do existing[v] = true end 
    end
    local newCar = nil
    local conn
    if BRP_PATHS.Vehicles then
        conn = BRP_PATHS.Vehicles.ChildAdded:Connect(function(c)
            if not existing[c] then newCar = c; Log("[1] NEW: " .. c.Name) end
        end)
    end
    Smuggler.FirePrompt(spawner.prompt)
    task.wait(0.5)
    local gui = SpawnUI.WaitForGui(3)
    if gui then
        task.wait(0.3)
        local card = SpawnUI.FindVehicleCard(gui, vname)
        if card then
            SpawnUI.ClickCard(card); task.wait(0.4)
            SpawnUI.ClickBuyButton(gui); task.wait(0.8)
            SpawnUI.ClickBuyButton(gui)
        end
    end
    if not newCar and BRP.SpawnVehicleFromSpawner then
        for _, args in ipairs({{vname}, {spawner.container, vname}, {vname, spawner.container}}) do
            if newCar then break end
            pcall(function()
                if BRP.SpawnVehicleFromSpawner:IsA("RemoteEvent") then BRP.SpawnVehicleFromSpawner:FireServer(unpack(args))
                else BRP.SpawnVehicleFromSpawner:InvokeServer(unpack(args)) end
            end)
            task.wait(0.4)
        end
    end
    local t0 = tick()
    while tick() - t0 < 5 do if newCar then break end; task.wait(0.1) end
    if conn then pcall(function() conn:Disconnect() end) end
    if not newCar and BRP_PATHS.Vehicles then
        for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do
            if not existing[v] then newCar = v; break end
        end
    end
    if not newCar then
        local hrp = GetHRP()
        if hrp and BRP_PATHS.Vehicles then
            local bd = math.huge
            for _, v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do
                local r = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
                if r then 
                    local d = (r.Position - hrp.Position).Magnitude
                    if d < bd and d < 40 then bd = d; newCar = v end
                end
            end
        end
    end
    if newCar then
        local t1 = tick()
        while tick() - t1 < 3 do if newCar.PrimaryPart or newCar:FindFirstChildWhichIsA("BasePart") then break end; task.wait(0.1) end
        State.Smuggler_CurrentCar = newCar
        Log("[1] READY: " .. newCar.Name)
        return newCar
    end
    Log("[1] FAILED")
    return nil
end

--━━━ STEP 2: SIT IN CAR ━━━
function Smuggler.SitInCar(car)
    if not car or not car.Parent then return false end
    if IsSeatedIn(car) then return true end
    local seat = nil
    local sT = tick()
    while tick() - sT < 1.5 do
        for _,obj in ipairs(car:GetDescendants()) do
            if (obj:IsA("VehicleSeat") or obj:IsA("Seat")) and not obj.Occupant then seat = obj; break end
        end
        if seat then break end
        task.wait(0.15)
    end
    if not seat then Log("[SIT] No seat"); return false end
    local hum, hrp = GetHuman(), GetHRP()
    if not hum or not hrp then return false end
    for a=1,3 do
        pcall(function() ZeroVel(); hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0) end)
        task.wait(0.15)
        pcall(function() seat:Sit(hum) end)
        local t0 = tick()
        while tick()-t0 < 0.8 do
            if IsSeatedIn(car) then Log("[SIT] OK #"..a); return true end
            task.wait(0.1)
        end
    end
    return false
end

--━━━ STEP 3: DRIVE CAR TO BUY LOCATION (PENETRATE) & BUY ━━━
function Smuggler.DriveAndBuy(car)
    Log("[3] Drive to buy " .. State.Smuggler_ItemName)
    local prompt, item = Smuggler.GetBuyPrompt()
    if not item then Log("[3] item not found"); return false end
    local pos = Smuggler.GetItemPos()
    if not pos then Log("[3] no pos"); return false end
    if not car or not car.Parent then Log("[3] no car"); return false end
    if not IsSeatedIn(car) then
        if not Smuggler.SitInCar(car) then Log("[3] can't sit"); return false end
    end
    -- Penetrate car right onto the item
    SmartTP.CarDrive(car, pos, pos + Vector3.new(0,0,5), true)
    task.wait(0.3)
    -- Fire buy prompt+remote from inside car
    for i=1, State.Smuggler_BuyRetries do
        if prompt then Smuggler.FirePrompt(prompt) end
        if BRP.PurchaseWorldItem then
            pcall(function()
                if BRP.PurchaseWorldItem:IsA("RemoteEvent") then BRP.PurchaseWorldItem:FireServer(State.Smuggler_ItemName)
                else BRP.PurchaseWorldItem:InvokeServer(State.Smuggler_ItemName) end
            end)
        end
        task.wait(0.35)
    end
    Log("[3] Buy done")
    return true
end

--━━━ STEP 4: DRIVE CAR TO SELLER (PENETRATE) & SELL ━━━
function Smuggler.DriveAndSell(car)
    Log("[4] Drive to seller " .. State.Smuggler_SellerName)
    local prompt, seller = Smuggler.GetSellPrompt()
    if not seller then Log("[4] no seller"); return false end
    local sellerPos = Smuggler.GetSellerPos()
    if not sellerPos then Log("[4] no pos"); return false end
    if not car or not car.Parent then Log("[4] no car"); return false end
    if not IsSeatedIn(car) then
        if not Smuggler.SitInCar(car) then Log("[4] can't sit"); return false end
    end
    -- Penetrate car into seller (within 5 studs)
    SmartTP.CarDrive(car, sellerPos, sellerPos + Vector3.new(0,0,5), true)
    task.wait(0.3)
    -- Equip items (works while seated)
    if State.Smuggler_AutoEquip then
        if State.Smuggler_EquipAll then Smuggler.EquipAll(State.Smuggler_ItemName)
        else Smuggler.EquipTool(State.Smuggler_ItemName) end
        task.wait(0.3)
    end
    -- Fire sell repeatedly from inside car
    for i=1, State.Smuggler_SellRetries do
        if prompt then Smuggler.FirePrompt(prompt) end
        if State.Smuggler_UseRemotes and BRP.SellSmuggledGoods then
            pcall(function() BRP.SellSmuggledGoods:FireServer() end)
        end
        task.wait(0.4)
    end
    Log("[4] Sell done")
    return true
end

--━━━ STEP 5: DRIVE CAR TO LAUNDRY (PENETRATE) & LAUNDER ━━━
function Smuggler.DriveAndLaunder(car)
    if not State.Smuggler_AutoLaunder then return true end
    Log("[5] Drive to laundry")
    local pos = Smuggler.GetLaunderPos()
    if not car or not car.Parent then Log("[5] no car"); return false end
    if not IsSeatedIn(car) then
        if not Smuggler.SitInCar(car) then Log("[5] can't sit"); return false end
    end
    -- Penetrate into laundry prompt part
    SmartTP.CarDrive(car, pos, pos + Vector3.new(0,0,5), true)
    task.wait(0.3)
    local prompt = Smuggler.GetLaunderPrompt()
    for i=1, State.Smuggler_LaunderRetries do
        if prompt then Smuggler.FirePrompt(prompt) end
        if State.Smuggler_UseRemotes and BRP.LaunderBriefcase then
            pcall(function() BRP.LaunderBriefcase:FireServer() end)
        end
        task.wait(0.4)
    end
    Log("[5] Launder done")
    return true
end

function Smuggler.RemoveTires(car)
    if not car then return end
    local removed = 0
    for _, obj in ipairs(car:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") and (n:find("wheel") or n:find("tire") or n:find("tyre")) then
            pcall(function() obj:Destroy() end)
            removed = removed + 1
        end
    end
    Log("[Tires] Removed " .. removed)
end

--━━━ FULL IN-CAR CYCLE ━━━
function Smuggler.RunCycle()
    Log("═══ CYCLE START ═══")
    local car = State.Smuggler_CurrentCar
    if State.Smuggler_SpawnCar and (not car or not car.Parent) then
        car = Smuggler.SpawnCar()
        if not State.Smuggler_AutoLoop then return end
        task.wait(0.5)
    end
    if not car then car = GetPlayerCar() end
    if not car then Log("Cycle: no car available"); return end

    Smuggler.SitInCar(car)
    if not State.Smuggler_AutoLoop then return end
    task.wait(0.3)

    if State.Smuggler_RemoveTires and not car:GetAttribute("__TR") then
        Smuggler.RemoveTires(car)
        pcall(function() car:SetAttribute("__TR", true) end)
    end
    task.wait(0.2)

    -- STEP: BUY (car penetrates buy point)
    Smuggler.DriveAndBuy(car)
    if not State.Smuggler_AutoLoop then return end
    task.wait(0.4)

    -- STEP: SELL (car penetrates seller)
    Smuggler.DriveAndSell(car)
    if not State.Smuggler_AutoLoop then return end
    task.wait(0.4)

    -- STEP: LAUNDER (car penetrates laundry)
    Smuggler.DriveAndLaunder(car)
    if not State.Smuggler_AutoLoop then return end

    State.Smuggler_JobsDone = State.Smuggler_JobsDone + 1
    Log("═══ JOB #"..State.Smuggler_JobsDone.." DONE ═══")
end

function Smuggler.SetAutoLoop(e)
    State.Smuggler_AutoLoop = e
    if not e then Log("Loop OFF"); return end
    Log("Loop ON")
    task.spawn(function()
        while State.Smuggler_AutoLoop do
            local ok, err = pcall(Smuggler.RunCycle)
            if not ok then Log("Cycle err: " .. tostring(err)) end
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
    local myHRP=GetHRP(); if not myHRP then return end
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
function Police.AimAt(part) if not part or not part.Parent then return end; if State.Police_AimSmooth<=1 then Camera.CFrame=CFrame.lookAt(Camera.CFrame.Position,part.Position) else Camera.CFrame=Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position,part.Position),math.clamp(1/State.Police_AimSmooth,0.05,1)) end end
function Police.SetAutoAim(e)
    State.Police_AutoAim=e; if State.Police_AimConn then pcall(function() State.Police_AimConn:Disconnect() end); State.Police_AimConn=nil end
    if e then Police.CreateFOV(); State.Police_AimConn=RunService.RenderStepped:Connect(function()
        Police.UpdateFOV(); local p,part=Police.GetTarget(); State.Police_CurrentTarget=p
        if part and (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or State.Police_AutoFire) then Police.AimAt(part) end
    end) else if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle.Visible=false end) end end
end
function Police.SetAutoFire(e)
    State.Police_AutoFire=e; if State.Police_FireConn then pcall(function() State.Police_FireConn:Disconnect() end); State.Police_FireConn=nil end
    if e then local last=0; State.Police_FireConn=RunService.Heartbeat:Connect(function() if State.Police_CurrentTarget and tick()-last>=0.15 then last=tick(); pcall(function() mouse1click() end) end end) end
end
function Police.SetAutoArrest(e)
    State.Police_AutoArrest=e; if State.Police_ArrestConn then pcall(function() State.Police_ArrestConn:Disconnect() end); State.Police_ArrestConn=nil end
    if e then local last=0; State.Police_ArrestConn=RunService.Heartbeat:Connect(function()
        if State.Police_CurrentTarget and tick()-last>=2.5 then last=tick()
            local t=State.Police_CurrentTarget; if not t.Character then return end
            local th=t.Character:FindFirstChild("HumanoidRootPart"); if not th then return end
            local myHRP=GetHRP(); if myHRP and (myHRP.Position-th.Position).Magnitude>8 then SmartTP.Go(th.Position+th.CFrame.LookVector*-3,0); task.wait(0.3) end
            if BRP.Detain then pcall(function() BRP.Detain:InvokeServer(t) end) end
            if BRP.Jail then task.wait(0.4); pcall(function() BRP.Jail:InvokeServer(t) end) end
        end
    end) end
end

--━ VIS
local Vis = {}
function Vis.BackupLight() if next(State.LightBackup) then return end; State.LightBackup={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,GlobalShadows=Lighting.GlobalShadows} end
function Vis.RestoreLight() for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e) Vis.BackupLight(); if e then Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255); Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false else Vis.RestoreLight() end end
function Vis.NoFog(e) Vis.BackupLight(); if e then Lighting.FogEnd=999999 else Lighting.FogEnd=State.LightBackup.FogEnd or 100000 end end
function Vis.SetFOV(f) if Camera then Camera.FieldOfView=f or 70 end end
function Vis.SetClock(t) Lighting.ClockTime=t or 14 end

CM:Add(LocalPlayer.Idled, function() if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end end)
task.spawn(function() while task.wait(1) do if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end end end)
CM:Add(UserInputService.JumpRequest, function() if State.InfiniteJump then local h=GetHuman(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end end end)

if State.AntiTpBypass then AntiTp.Enable() end
if State.NoFallDamage then FallGuard.Enable() end
if State.ACFlyEnabled then ACFly.Enable() end

--━ UI
local Window = WindUI:CreateWindow({
    Title=HUB.Name, Icon="gamepad-2", Author="v"..HUB.Version, Folder="X0DEC04T",
    Size=UDim2.fromOffset(560,460), Transparent=true, Theme="Dark", SideBarWidth=160, HasOutline=true,
})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." IN-CAR", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t, Content=c, Duration=d or 4, Icon="info"}) end) end

-- LOGO
local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui")
    logoGui.Name="X0DEC04T_Logo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.Position = UDim2.new(0, 20, 0.5, -30)
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Image = "rbxassetid://"..tostring(LOGO_ASSET_ID)
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Active = true
    btn.Draggable = true
    btn.Parent = logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled = false end
        logoActive = false
        pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

task.spawn(function()
    local last = true
    while task.wait(0.3) do
        if not Window then break end
        local isOpen = true
        pcall(function()
            if Window.UIElements and Window.UIElements.Main then isOpen = Window.UIElements.Main.Visible
            elseif Window.Root then isOpen = Window.Root.Visible end
        end)
        if isOpen ~= last then
            last = isOpen
            if isOpen then if logoGui then logoGui.Enabled=false end; logoActive=false
            else if logoGui then logoGui.Enabled=true end; logoActive=true end
        end
    end
end)

CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.wait(0.1)
        if logoActive then if logoGui then logoGui.Enabled=false end; logoActive=false; pcall(function() Window:Open() end)
        else if logoGui then logoGui.Enabled=true end; logoActive=true; pcall(function() Window:Close() end) end
    end
end)

local Tabs = {
    Main=Window:Tab({Title="Main",Icon="home"}),
    Vehicle=Window:Tab({Title="Vehicle",Icon="car"}),
    Smuggler=Window:Tab({Title="Smuggler",Icon="package"}),
    Police=Window:Tab({Title="Police",Icon="shield"}),
    Teleport=Window:Tab({Title="Teleport",Icon="map-pin"}),
    ESP=Window:Tab({Title="ESP",Icon="eye"}),
    Visuals=Window:Tab({Title="Visuals",Icon="sun"}),
    Settings=Window:Tab({Title="Settings",Icon="settings"}),
}
Window:SelectTab(1)

Tabs.Main:Section({Title="X0DEC04T Hub v"..HUB.Version})
Tabs.Main:Paragraph({Title="IN-CAR FLOW", Desc="Full cycle done from inside the car:\n1. Spawn car → sit\n2. Drive INTO item (penetrate) → buy\n3. Drive INTO seller → sell\n4. Drive INTO laundry → launder\nNo exits = no despawn = no rollback"})
Tabs.Main:Button({Title="Minimize UI", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})

Tabs.Vehicle:Section({Title="Speed"})
Tabs.Vehicle:Slider({Title="Extra Speed", Value={Min=0,Max=500,Default=0}, Step=10, Callback=safeCB(function(v) State.CarSpeed=v; Car.ApplySpeed() end)})
Tabs.Vehicle:Toggle({Title="Speed Hack", Default=false, Callback=safeCB(function(v) State.SpeedHack=v; Car.SetSpeedHack(v) end)})
Tabs.Vehicle:Section({Title="Actions"})
Tabs.Vehicle:Button({Title="Flip Car", Callback=safeCB(Car.Flip)})
Tabs.Vehicle:Button({Title="Boost", Callback=safeCB(Car.Boost)})
Tabs.Vehicle:Button({Title="Unstuck", Callback=safeCB(function() if BRP.UnstuckVehicle then pcall(function() BRP.UnstuckVehicle:FireServer() end) end end)})
Tabs.Vehicle:Section({Title="Abilities"})
Tabs.Vehicle:Toggle({Title="NoClip", Default=false, Callback=safeCB(function(v) State.NoClip=v; Car.SetNoClip(v) end)})
Tabs.Vehicle:Toggle({Title="Fly", Default=false, Callback=safeCB(function(v) State.FlyActive=v; Car.SetFly(v) end)})
Tabs.Vehicle:Toggle({Title="AC Fly Bypass", Default=true, Callback=safeCB(function(v) State.ACFlyEnabled=v; if v then ACFly.Enable() else ACFly.Disable() end end)})
Tabs.Vehicle:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v; Car.SetGod(v) end)})
Tabs.Vehicle:Section({Title="Character"})
Tabs.Vehicle:Slider({Title="WalkSpeed", Value={Min=16,Max=200,Default=16}, Step=4, Callback=safeCB(function(v) local h=GetHuman(); if h then pcall(function() h.WalkSpeed=v end) end end)})
Tabs.Vehicle:Toggle({Title="Infinite Jump", Default=false, Callback=safeCB(function(v) State.InfiniteJump=v end)})

Tabs.Smuggler:Section({Title="Item"})
Tabs.Smuggler:Dropdown({Title="Item to Buy", Values=GetBuyableItemNames(), Value="Fake Diamond Ring", Callback=safeCB(function(v) State.Smuggler_ItemName=v end)})
Tabs.Smuggler:Slider({Title="Buy Retries", Value={Min=1,Max=10,Default=5}, Step=1, Callback=safeCB(function(v) State.Smuggler_BuyRetries=v end)})
Tabs.Smuggler:Section({Title="Vehicle"})
Tabs.Smuggler:Toggle({Title="Auto Spawn Car", Default=true, Callback=safeCB(function(v) State.Smuggler_SpawnCar=v end)})
Tabs.Smuggler:Toggle({Title="Remove Tires (once)", Default=true, Callback=safeCB(function(v) State.Smuggler_RemoveTires=v end)})
Tabs.Smuggler:Dropdown({Title="Vehicle", Values={"Tayora Cambria","Citrion Buddy","Tayora Prion","Tayora Royal Touring","Dager Durance R/T","Mammoth Patriot","Chevran Silverline","Chevran Courier","Fjord F-450","Beamer M135X","Mammoth Trailrunner","Auvio R3S"}, Value="Tayora Cambria", Callback=safeCB(function(v) State.Smuggler_VehicleName=v end)})
Tabs.Smuggler:Input({Title="Custom Vehicle", Placeholder="overrides", Callback=safeCB(function(v) if v~="" then State.Smuggler_VehicleName=v end end)})
Tabs.Smuggler:Section({Title="Car TP"})
Tabs.Smuggler:Slider({Title="Chunk Size", Value={Min=5,Max=100,Default=20}, Step=5, Callback=safeCB(function(v) State.Smuggler_ChunkSize=v end)})
Tabs.Smuggler:Slider({Title="Step Delay x100", Value={Min=2,Max=30,Default=5}, Step=1, Callback=safeCB(function(v) State.Smuggler_StepDelay=v/100 end)})
Tabs.Smuggler:Section({Title="Seller"})
Tabs.Smuggler:Dropdown({Title="Seller", Values=GetSellerNames(), Value=State.Smuggler_SellerName, Callback=safeCB(function(v) State.Smuggler_SellerName=v end)})
Tabs.Smuggler:Slider({Title="Sell Retries", Value={Min=1,Max=20,Default=10}, Step=1, Callback=safeCB(function(v) State.Smuggler_SellRetries=v end)})
Tabs.Smuggler:Toggle({Title="Auto Equip", Default=true, Callback=safeCB(function(v) State.Smuggler_AutoEquip=v end)})
Tabs.Smuggler:Toggle({Title="Equip All", Default=true, Callback=safeCB(function(v) State.Smuggler_EquipAll=v end)})
Tabs.Smuggler:Section({Title="Laundry"})
Tabs.Smuggler:Toggle({Title="Auto Launder", Default=true, Callback=safeCB(function(v) State.Smuggler_AutoLaunder=v end)})
Tabs.Smuggler:Slider({Title="Launder Retries", Value={Min=1,Max=15,Default=6}, Step=1, Callback=safeCB(function(v) State.Smuggler_LaunderRetries=v end)})
Tabs.Smuggler:Section({Title="Anti-Cheat"})
Tabs.Smuggler:Toggle({Title="AntiTp Bypass", Default=true, Callback=safeCB(function(v) State.AntiTpBypass=v; if v then AntiTp.Enable() else AntiTp.Disable() end end)})
Tabs.Smuggler:Toggle({Title="No Fall Damage", Default=true, Callback=safeCB(function(v) State.NoFallDamage=v; if v then FallGuard.Enable() else FallGuard.Disable() end end)})
Tabs.Smuggler:Section({Title="Timing"})
Tabs.Smuggler:Slider({Title="Cycle Delay", Value={Min=0,Max=10,Default=1}, Step=1, Callback=safeCB(function(v) State.Smuggler_Delay=v end)})
Tabs.Smuggler:Section({Title="AUTO"})
Tabs.Smuggler:Toggle({Title="Auto Loop (Full In-Car Cycle)", Default=false, Callback=safeCB(function(v) Smuggler.SetAutoLoop(v) end)})
Tabs.Smuggler:Section({Title="Manual"})
Tabs.Smuggler:Button({Title="1. Spawn Car", Callback=safeCB(Smuggler.SpawnCar)})
Tabs.Smuggler:Button({Title="2. Sit In Car", Callback=safeCB(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.SitInCar(c) end end)})
Tabs.Smuggler:Button({Title="   Remove Tires", Callback=safeCB(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.RemoveTires(c) end end)})
Tabs.Smuggler:Button({Title="3. Drive Car → BUY (penetrate)", Callback=safeCB(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.DriveAndBuy(c) end end)})
Tabs.Smuggler:Button({Title="4. Drive Car → SELL (penetrate)", Callback=safeCB(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.DriveAndSell(c) end end)})
Tabs.Smuggler:Button({Title="5. Drive Car → LAUNDER (penetrate)", Callback=safeCB(function() local c=State.Smuggler_CurrentCar or GetPlayerCar(); if c then Smuggler.DriveAndLaunder(c) end end)})

Tabs.Police:Toggle({Title="Wanted Only", Default=true, Callback=safeCB(function(v) State.Police_TargetWanted=v end)})
Tabs.Police:Toggle({Title="Target All", Default=false, Callback=safeCB(function(v) State.Police_TargetAll=v end)})
Tabs.Police:Slider({Title="FOV", Value={Min=30,Max=500,Default=150}, Step=10, Callback=safeCB(function(v) State.Police_AimFOV=v end)})
Tabs.Police:Toggle({Title="Auto-Aim (RMB)", Default=false, Callback=safeCB(function(v) Police.SetAutoAim(v) end)})
Tabs.Police:Toggle({Title="Auto-Fire", Default=false, Callback=safeCB(function(v) Police.SetAutoFire(v) end)})
Tabs.Police:Toggle({Title="Auto-Arrest", Default=false, Callback=safeCB(function(v) Police.SetAutoArrest(v) end)})

Tabs.Teleport:Input({Title="Player Name", Placeholder="case-sensitive", Callback=safeCB(function(v) State.TP_Target=v end)})
Tabs.Teleport:Button({Title="TP to Player", Callback=safeCB(function() local n=State.TP_Target; if not n or n=="" then return end; local t=Players:FindFirstChild(n); if not t or not t.Character then return end; local th=t.Character:FindFirstChild("HumanoidRootPart"); if th then SmartTP.Go(th.Position+Vector3.new(0,0,4),0) end end)})
Tabs.Teleport:Section({Title="Locations"})
Tabs.Teleport:Button({Title="Shop", Callback=safeCB(function() SmartTP.Go(State.POS_Shop,3) end)})
Tabs.Teleport:Button({Title="Laundry", Callback=safeCB(function() SmartTP.Go(State.POS_Laundry,3) end)})
Tabs.Teleport:Button({Title="Car Spawner", Callback=safeCB(function() local sp=FindNearestSpawner(); if sp then SmartTP.Go(sp.position,3) end end)})
Tabs.Teleport:Section({Title="Sellers"})
for _,name in ipairs(GetSellerNames()) do
    Tabs.Teleport:Button({Title="TP to "..name, Callback=safeCB(function()
        local npc=BRP_PATHS.NPC and BRP_PATHS.NPC:FindFirstChild(name)
        if npc then local h=npc:FindFirstChild("HumanoidRootPart"); if h then SmartTP.Go(h.Position+Vector3.new(2,0,2),0); task.wait(0.3); SmartTP.WalkTo(h.Position, 3) end end
    end)})
end

Tabs.ESP:Toggle({Title="All Players", Default=false, Callback=safeCB(function(v) State.ESP_Players=v end)})
Tabs.ESP:Toggle({Title="Wanted", Default=false, Callback=safeCB(function(v) State.ESP_Wanted=v end)})
Tabs.ESP:Toggle({Title="Police", Default=false, Callback=safeCB(function(v) State.ESP_Police=v end)})
Tabs.ESP:Button({Title="Clear", Callback=safeCB(ESP.ClearAll)})

Tabs.Visuals:Toggle({Title="FullBright", Default=false, Callback=safeCB(function(v) Vis.FullBright(v) end)})
Tabs.Visuals:Toggle({Title="No Fog", Default=false, Callback=safeCB(function(v) Vis.NoFog(v) end)})
Tabs.Visuals:Slider({Title="Time", Value={Min=0,Max=24,Default=14}, Step=1, Callback=safeCB(function(v) Vis.SetClock(v) end)})
Tabs.Visuals:Slider({Title="FOV", Value={Min=30,Max=120,Default=70}, Step=5, Callback=safeCB(function(v) Vis.SetFOV(v) end)})

Tabs.Settings:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})
Tabs.Settings:Button({Title="Minimize UI", Callback=safeCB(function() pcall(function() Window:Close() end); task.wait(0.2); if logoGui then logoGui.Enabled=true end; logoActive=true end)})
Tabs.Settings:Button({Title="PANIC", Callback=safeCB(function() Smuggler.SetAutoLoop(false); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false); ACFly.Disable(); Notify("PANIC","Off",3) end)})
Tabs.Settings:Button({Title="Unload", Callback=safeCB(function()
    Smuggler.SetAutoLoop(false); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
    AntiTp.Disable(); FallGuard.Disable(); ACFly.Disable(); DisableNC()
    if logoGui then pcall(function() logoGui:Destroy() end) end
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
    CM:Cleanup(); Vis.RestoreLight(); ESP.ClearAll()
    _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGod,true) end
    if State.NoClip then pcall(Car.SetNoClip,true) end
    if State.FlyActive then pcall(Car.SetFly,true) end
    if State.FullBright then pcall(Vis.FullBright,true) end
    if State.AntiTpBypass then AntiTp.Enable() end
    if State.NoFallDamage then FallGuard.Enable() end
    if State.ACFlyEnabled and State.FlyActive then ACFly.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        Smuggler.SetAutoLoop(false); Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTp.Disable(); FallGuard.Disable(); ACFly.Disable(); DisableNC()
        if logoGui then pcall(function() logoGui:Destroy() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Log("v4.0.5 IN-CAR ready | Logo: "..tostring(LOGO_ASSET_ID))
