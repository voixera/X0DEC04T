--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v3.1.0 - Border RP
-- Pure ScreenGui - No UI library, defers all callbacks
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

local INSTANCE_KEY = "__X0DEC04T_BRP_v310"
if _G[INSTANCE_KEY] then
    pcall(function() _G[INSTANCE_KEY].destroy() end)
    _G[INSTANCE_KEY] = nil
    task.wait(0.2)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("Starting v3.1.0 pure GUI...")

--━ SAFE CALLBACK WRAPPER (defers to prevent SEH crash)
local function safeCall(fn)
    return function(...)
        local args = {...}
        task.defer(function()
            local ok, err = pcall(function() fn(unpack(args)) end)
            if not ok then Log("Callback err: " .. tostring(err)) end
        end)
    end
end

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
    Detain                  = GetRemote("Handcuffs.Detain"),
    Jail                    = GetRemote("Handcuffs.Jail"),
    UnstuckVehicle          = GetRemote("VehicleService.UnstuckVehicle"),
    ApplyRollbackCFrame     = GetRemote("AntiTp.ApplyRollbackCFrame"),
}

local BRP_PATHS = {
    NPC = Workspace:FindFirstChild("NPC"),
    Vehicles = Workspace:FindFirstChild("Vehicles"),
    LaunderTrigger = nil,
    WorldBuyableItems = Workspace:FindFirstChild("WorldBuyableItems"),
}

pcall(function()
    local lp = Workspace:FindFirstChild("LaunderPrompts")
    if lp then BRP_PATHS.LaunderTrigger = lp:FindFirstChild("LaunderTrigger") end
end)

--━ STATE
local State = {
    Smuggler_AutoLoop = false,
    Smuggler_JobsDone = 0,
    Smuggler_ItemName = "Fake Diamond Ring",
    Smuggler_SellerName = "Seller4",
    Smuggler_VehicleName = "Camry6",
    Smuggler_Delay = 1,
    Smuggler_AutoEquip = true,
    Smuggler_EquipAll = true,
    Smuggler_RemoveTires = true,
    Smuggler_SpawnCar = true,
    Smuggler_CurrentCar = nil,
    Smuggler_CarTPMethod = "WeldTP",
    Smuggler_UseRemotes = true,
    Smuggler_AutoLaunder = true,
    Smuggler_DebugMode = false,

    TPStrategy = "Tween",
    TweenSpeed = 200,
    AntiTpBypass = true,

    POS_Shop = Vector3.new(6823.57, 17.40, -20.00),
    POS_Laundry = Vector3.new(6804.78, 17.43, -34.70),
    POS_CarSpawner = Vector3.new(6840, 17, -30),

    GodMode = false,
    NoClip = false,
    NoclipConn = nil,
    FlyActive = false,
    FlyConn = nil,
    WalkSpeed = 16,
    InfiniteJump = false,
    AntiAFK = true,
}

--━ HELPERS
local function GetChar() return LocalPlayer.Character end
local function GetHRP() local ch=GetChar(); return ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChildWhichIsA("BasePart")) end
local function GetHuman() local ch=GetChar(); return ch and ch:FindFirstChildOfClass("Humanoid") end

local function GetPlayerCar()
    local ch = GetChar(); if not ch then return nil end
    for _, seat in ipairs(Workspace:GetDescendants()) do
        if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) and seat.Occupant and seat.Occupant.Parent == ch then
            return seat:FindFirstAncestorOfClass("Model"), seat
        end
    end
    return nil
end

--━ ANTITP
local AntiTp = { enabled=false, hidden=false, origParent=nil, holds=0 }

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
            if ok then AntiTp.hidden = true end
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
        if r and AntiTp.origParent then pcall(function() r.Parent = AntiTp.origParent end) end
        AntiTp.hidden = false
    end
end

task.spawn(function()
    while true do
        task.wait(6)
        if AntiTp.hidden and AntiTp.holds == 0 then AntiTp.Release(true) end
    end
end)

--━ TELEPORT
local SmartTP = {}
local _noclip = nil

local function EnableNoclip()
    if _noclip then return end
    _noclip = RunService.Stepped:Connect(function()
        local ch = GetChar()
        if ch then for _,p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.CanCollide=false end) end
        end end
    end)
end

local function DisableNoclip()
    if _noclip then pcall(function() _noclip:Disconnect() end); _noclip = nil end
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
    if totalDist < 5 then pcall(function() hrp.CFrame = CFrame.new(targetPos) end); task.wait(0.1); return true end

    local wasPS = false
    if hum then wasPS = hum.PlatformStand; pcall(function() hum.PlatformStand = true end) end
    EnableNoclip()

    local speed = math.max(State.TweenSpeed, 50)
    local duration = math.clamp(totalDist / speed, 0.2, 15)

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
    if hum and hum.Parent then pcall(function() hum.PlatformStand = wasPS end) end
    DisableNoclip()
    task.wait(0.2)
    return true
end

function SmartTP.Go(pos, yOff)
    if State.AntiTpBypass then AntiTp.Hold() end
    local result
    if State.TPStrategy == "Instant" then result = SmartTP.Instant(pos, yOff)
    else result = SmartTP.Tween(pos, yOff) end
    if State.AntiTpBypass then task.delay(2, function() pcall(AntiTp.Release) end) end
    return result
end

function SmartTP.DirectVehicle(car, targetPos, faceCFrame)
    if not car then return false end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not root then return false end
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function() p.AssemblyLinearVelocity = Vector3.zero; p.AssemblyAngularVelocity = Vector3.zero end)
        end
    end
    local cf = faceCFrame or CFrame.new(targetPos)
    pcall(function() if car:IsA("Model") then car:PivotTo(cf) else root.CFrame = cf end end)
    task.wait(0.3); return true
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
        AntiTp.Hold()
        local r = SmartTP.DirectVehicle(car, targetPos, faceCFrame)
        task.delay(3, function() pcall(AntiTp.Release) end)
        return r
    end
    AntiTp.Hold()
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end) end
    end
    local targetCF = faceCFrame or CFrame.new(targetPos)
    local startCF = root.CFrame
    local totalDist = (targetCF.Position - startCF.Position).Magnitude
    local chunks = math.max(3, math.ceil(totalDist / 80))
    for i = 1, chunks do
        local alpha = i / chunks
        local stepCF = startCF:Lerp(targetCF, alpha)
        pcall(function() if car:IsA("Model") then car:PivotTo(stepCF) else root.CFrame = stepCF end end)
        for _, p in ipairs(car:GetDescendants()) do
            if p:IsA("BasePart") then pcall(function() p.AssemblyLinearVelocity=Vector3.zero; p.AssemblyAngularVelocity=Vector3.zero end) end
        end
        task.wait(0.08)
    end
    pcall(function() if car:IsA("Model") then car:PivotTo(targetCF) else root.CFrame = targetCF end end)
    task.wait(0.3)
    task.delay(3, function() pcall(AntiTp.Release) end)
    return true
end

function SmartTP.CarTP(car, targetPos, faceCFrame)
    if State.Smuggler_CarTPMethod == "WeldTP" then return SmartTP.WeldVehicle(car, targetPos, faceCFrame) end
    AntiTp.Hold()
    local r = SmartTP.DirectVehicle(car, targetPos, faceCFrame)
    task.delay(3, function() pcall(AntiTp.Release) end)
    return r
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
                    prompt=obj, part=part,
                    container=container or obj.Parent,
                    position=part and part.Position or Vector3.zero,
                })
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

--━ SMUGGLER
local Smuggler = {}

function Smuggler.FirePrompt(prompt)
    if not prompt then return end
    pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
end

function Smuggler.EquipAll(toolName)
    local bp = LocalPlayer:FindFirstChild("Backpack"); if not bp then return end
    local h = GetHuman(); if not h then return end
    for _,t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and t.Name==toolName then
            pcall(function() h:EquipTool(t) end); task.wait(0.15)
        end
    end
end

function Smuggler.GetBuyPrompt()
    if not BRP_PATHS.WorldBuyableItems then return nil end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(State.Smuggler_ItemName)
    if not item then return nil end
    for _,obj in ipairs(item:GetDescendants()) do if obj:IsA("ProximityPrompt") then return obj, item end end
    return nil, item
end

function Smuggler.GetItemPos()
    if not BRP_PATHS.WorldBuyableItems then return nil end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(State.Smuggler_ItemName)
    if not item then return nil end
    local h = item:FindFirstChild("Handle"); if h and h:IsA("BasePart") then return h.Position end
    local p = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

function Smuggler.GetSellPrompt()
    if not BRP_PATHS.NPC then return nil end
    local seller = BRP_PATHS.NPC:FindFirstChild(State.Smuggler_SellerName)
    if not seller then
        for _,npc in ipairs(BRP_PATHS.NPC:GetChildren()) do
            if npc.Name:lower():find("seller") then
                local hrp = npc:FindFirstChild("HumanoidRootPart")
                if hrp then local p = hrp:FindFirstChild("SellSmuggledGoodsPrompt"); if p then return p, npc end end
            end
        end
        return nil
    end
    local hrp = seller:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    return hrp:FindFirstChild("SellSmuggledGoodsPrompt"), seller
end

function Smuggler.GetLaunderPrompt()
    if BRP_PATHS.LaunderTrigger then
        local pp = BRP_PATHS.LaunderTrigger:FindFirstChild("PromptPart")
        if pp then return pp:FindFirstChild("LaunderBriefcasePrompt") end
    end
end

function Smuggler.BuyItem()
    Log("[1] Buy " .. State.Smuggler_ItemName)
    local prompt, item = Smuggler.GetBuyPrompt()
    if not item then return end
    local pos = Smuggler.GetItemPos()
    if pos then SmartTP.Go(pos, 3) end
    if not prompt then return end
    for i=1,2 do Smuggler.FirePrompt(prompt); task.wait(0.4) end
end

function Smuggler.SpawnCar()
    local vname = State.Smuggler_VehicleName
    if vname == "" then vname = "Camry6" end
    Log("[2] Spawn " .. vname)

    local spawner = FindNearestSpawner()
    if spawner then SmartTP.Go(spawner.position, 3); task.wait(0.6); spawner = FindNearestSpawner()
    else SmartTP.Go(State.POS_CarSpawner, 3); task.wait(0.8); spawner = FindNearestSpawner() end

    local existing = {}
    if BRP_PATHS.Vehicles then for _,v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do existing[v] = true end end

    local newCar = nil
    local conn
    if BRP_PATHS.Vehicles then
        conn = BRP_PATHS.Vehicles.ChildAdded:Connect(function(c)
            if not existing[c] then newCar = c; Log("[2] NEW: " .. c.Name) end
        end)
    end

    if spawner and spawner.prompt then Smuggler.FirePrompt(spawner.prompt); task.wait(0.5) end

    if BRP.SpawnVehicleFromSpawner then
        local cont = spawner and spawner.container
        local part = spawner and spawner.part
        local argSets = { {vname}, {cont, vname}, {vname, cont}, {part, vname}, {vname, part}, {cont} }
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
    if conn then pcall(function() conn:Disconnect() end) end

    if not newCar and BRP_PATHS.Vehicles then
        for _,v in ipairs(BRP_PATHS.Vehicles:GetChildren()) do
            if not existing[v] then newCar = v; break end
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
    if not car or not car.Parent then return end
    if GetPlayerCar() == car then return end
    local seat = nil
    for a=1,10 do
        for _,obj in ipairs(car:GetDescendants()) do
            if obj:IsA("VehicleSeat") and not obj.Occupant then seat = obj; break end
        end
        if seat then break end; task.wait(0.2)
    end
    if not seat then return end
    local hum, hrp = GetHuman(), GetHRP()
    if not hum or not hrp then return end
    for a=1,3 do
        pcall(function() hrp.CFrame = seat.CFrame * CFrame.new(0, 2, 0); task.wait(0.2); seat:Sit(hum) end)
        task.wait(0.6)
        if GetPlayerCar() == car then Log("[3] Sat #" .. a); return end
    end
end

function Smuggler.RemoveTires(car)
    if not car then return end
    for _,obj in ipairs(car:GetDescendants()) do
        local n = obj.Name:lower()
        if obj:IsA("BasePart") and (n:find("wheel") or n:find("tire") or n:find("tyre")) then
            pcall(function() obj:Destroy() end)
        end
    end
    Log("[4] Tires removed")
end

function Smuggler.TeleportCarToSeller(car)
    if not car then return end
    local _, seller = Smuggler.GetSellPrompt()
    if not seller then return end
    local sHRP = seller:FindFirstChild("HumanoidRootPart"); if not sHRP then return end
    local sellerPos = sHRP.Position
    local carRoot = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart"); if not carRoot then return end
    local dir = (sellerPos - carRoot.Position)
    if dir.Magnitude > 0 then dir = dir.Unit else dir = Vector3.new(1,0,0) end
    local targetPos = sellerPos - dir * 6
    targetPos = Vector3.new(targetPos.X, sellerPos.Y + 3, targetPos.Z)
    SmartTP.CarTP(car, targetPos, CFrame.lookAt(targetPos, sellerPos))
    task.wait(0.5)
end

function Smuggler.FireSell()
    if State.Smuggler_AutoEquip then
        Smuggler.EquipAll(State.Smuggler_ItemName)
        task.wait(0.4)
    end
    local prompt = Smuggler.GetSellPrompt()
    for i=1,8 do
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
    for i=1,3 do
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
        if State.Smuggler_RemoveTires and not car:GetAttribute("__TR") then
            Smuggler.RemoveTires(car); pcall(function() car:SetAttribute("__TR", true) end)
        end
        if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
        Smuggler.TeleportCarToSeller(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.FireSell(); if not State.Smuggler_AutoLoop then return end; task.wait(0.5)
        Smuggler.TeleportCarToLaundry(car); if not State.Smuggler_AutoLoop then return end; task.wait(0.4)
    else
        local _, seller = Smuggler.GetSellPrompt()
        if seller then local sh = seller:FindFirstChild("HumanoidRootPart"); if sh then SmartTP.Go(sh.Position, 3); task.wait(0.5) end end
        Smuggler.FireSell(); task.wait(0.5)
        SmartTP.Go(State.POS_Laundry, 3); task.wait(0.5)
    end
    Smuggler.FireLaunder()
    State.Smuggler_JobsDone = State.Smuggler_JobsDone + 1
    Log("Job #" .. State.Smuggler_JobsDone)
end

function Smuggler.SetAutoLoop(e)
    State.Smuggler_AutoLoop = e
    if not e then Log("Loop OFF"); return end
    Log("Loop ON")
    task.spawn(function()
        while State.Smuggler_AutoLoop do
            local ok, err = pcall(Smuggler.RunCycle)
            if not ok then Log("Err: " .. tostring(err)) end
            if not State.Smuggler_AutoLoop then break end
            task.wait(State.Smuggler_Delay)
        end
    end)
end

--━ CAR
local Car = {}
function Car.Flip() local c=GetPlayerCar(); if c then local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then pcall(function() r.CFrame=CFrame.new(r.Position) end) end end end
function Car.SetGod(e) local h=GetHuman(); if h then pcall(function() if e then h.MaxHealth=math.huge; h.Health=math.huge else h.MaxHealth=100; h.Health=100 end end) end end
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
        if h then pcall(function() h.PlatformStand=true end) end
        local hrp=GetHRP()
        if hrp then
            local bg=Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=9e4; bg.CFrame=hrp.CFrame; bg.Parent=hrp; bg.Name="__FG"
            local bv=Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=9e4; bv.Parent=hrp; bv.Name="__FV"
            State.FlyConn=RunService.RenderStepped:Connect(function()
                local h2=GetHRP(); if not h2 then return end
                local bg2=h2:FindFirstChild("__FG"); local bv2=h2:FindFirstChild("__FV")
                if not bg2 or not bv2 then return end
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
    else
        if h then pcall(function() h.PlatformStand=false end) end
        local hrp=GetHRP()
        if hrp then local a=hrp:FindFirstChild("__FG"); local b=hrp:FindFirstChild("__FV"); if a then a:Destroy() end; if b then b:Destroy() end end
    end
end

-- Anti-AFK
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end
end)

-- God loop
task.spawn(function()
    while task.wait(1) do
        if State.GodMode then local h=GetHuman(); if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end end
    end
end)

-- Infinite jump
CM:Add(UserInputService.JumpRequest, function()
    if State.InfiniteJump then local h=GetHuman(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end) end end
end)

if State.AntiTpBypass then AntiTp.Enable() end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- PURE SCREENGUI
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

-- Root GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "X0DEC04T_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = GuiParent() end)

-- Main frame
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 480, 0, 420)
Main.Position = UDim2.new(0.5, -240, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 8); corner.Parent = Main
local stroke = Instance.new("UIStroke"); stroke.Color = Color3.fromRGB(60, 60, 80); stroke.Thickness = 1; stroke.Parent = Main

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 8); tbc.Parent = TitleBar

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0)
TitleText.Position = UDim2.new(0, 12, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "X0DEC04T Hub  v3.1.0"
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 14
TitleText.TextColor3 = Color3.fromRGB(230, 230, 240)
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -32, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 4); cbc.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    pcall(function() Main.Visible = false end)
end)

-- Tab bar (left side)
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(0, 110, 1, -34)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local tblist = Instance.new("UIListLayout")
tblist.Padding = UDim.new(0, 2)
tblist.SortOrder = Enum.SortOrder.LayoutOrder
tblist.Parent = TabBar

local tbpad = Instance.new("UIPadding"); tbpad.PaddingTop = UDim.new(0, 6); tbpad.PaddingLeft = UDim.new(0, 4); tbpad.PaddingRight = UDim.new(0, 4); tbpad.Parent = TabBar

-- Content area
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -110, 1, -34)
Content.Position = UDim2.new(0, 110, 0, 34)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local clist = Instance.new("UIListLayout")
clist.Padding = UDim.new(0, 4)
clist.SortOrder = Enum.SortOrder.LayoutOrder
clist.Parent = Content

local cpad = Instance.new("UIPadding")
cpad.PaddingTop = UDim.new(0, 6); cpad.PaddingLeft = UDim.new(0, 8); cpad.PaddingRight = UDim.new(0, 8); cpad.PaddingBottom = UDim.new(0, 6)
cpad.Parent = Content

-- Tab system
local tabs = {}
local currentTab = nil
local tabOrder = 0

local function ShowTab(name)
    for tn, tf in pairs(tabs) do tf.Visible = (tn == name) end
    currentTab = name
    -- Reset scroll
    pcall(function() Content.CanvasPosition = Vector2.new(0, 0) end)
end

local function CreateTab(name)
    tabOrder = tabOrder + 1
    -- Tab button
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(200, 200, 210)
    btn.BorderSizePixel = 0
    btn.LayoutOrder = tabOrder
    btn.Parent = TabBar
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = btn

    -- Tab content frame
    local tf = Instance.new("Frame")
    tf.Size = UDim2.new(1, 0, 0, 0)
    tf.AutomaticSize = Enum.AutomaticSize.Y
    tf.BackgroundTransparency = 1
    tf.Visible = false
    tf.LayoutOrder = tabOrder
    tf.Parent = Content

    local tl = Instance.new("UIListLayout")
    tl.Padding = UDim.new(0, 4)
    tl.SortOrder = Enum.SortOrder.LayoutOrder
    tl.Parent = tf

    tabs[name] = tf

    btn.MouseButton1Click:Connect(function() ShowTab(name) end)

    return tf
end

-- Widget factory
local function AddLabel(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(180, 180, 190)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
    return lbl
end

local function AddSection(parent, text)
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 0, 22)
    frm.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    frm.BorderSizePixel = 0
    frm.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frm
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(140, 200, 255)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frm
    return frm
end

local function AddButton(parent, text, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    btn.MouseEnter:Connect(function() pcall(function() btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80) end) end)
    btn.MouseLeave:Connect(function() pcall(function() btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60) end) end)
    -- CRITICAL: defer callback to prevent SEH crash
    btn.MouseButton1Click:Connect(safeCall(cb))
    return btn
end

local function AddToggle(parent, text, default, cb)
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 0, 26)
    frm.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frm.BorderSizePixel = 0
    frm.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frm

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frm

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 36, 0, 18)
    toggle.Position = UDim2.new(1, -42, 0.5, -9)
    toggle.BackgroundColor3 = default and Color3.fromRGB(70, 180, 90) or Color3.fromRGB(80, 80, 90)
    toggle.Text = ""
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = false
    toggle.Parent = frm
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 9); tc.Parent = toggle

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    dot.BackgroundColor3 = Color3.fromRGB(255,255,255)
    dot.BorderSizePixel = 0
    dot.Parent = toggle
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = dot

    local state = default
    toggle.MouseButton1Click:Connect(function()
        state = not state
        pcall(function()
            toggle.BackgroundColor3 = state and Color3.fromRGB(70, 180, 90) or Color3.fromRGB(80, 80, 90)
            dot.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end)
        safeCall(cb)(state)
    end)

    return frm
end

local function AddSlider(parent, text, min, max, default, cb)
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 0, 40)
    frm.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frm.BorderSizePixel = 0
    frm.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frm

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -12, 0, 18)
    lbl.Position = UDim2.new(0, 8, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. tostring(default)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frm

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 8)
    bar.Position = UDim2.new(0, 8, 1, -14)
    bar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    bar.BorderSizePixel = 0
    bar.Parent = frm
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = bar

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(70, 130, 220)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 4); fc.Parent = fill

    local dragging = false
    local function update(x)
        local absPos = bar.AbsolutePosition.X
        local absSize = bar.AbsoluteSize.X
        local rel = math.clamp((x - absPos) / absSize, 0, 1)
        local val = math.floor(min + (max - min) * rel + 0.5)
        pcall(function()
            fill.Size = UDim2.new(rel, 0, 1, 0)
            lbl.Text = text .. ": " .. tostring(val)
        end)
        safeCall(cb)(val)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return frm
end

local function AddDropdown(parent, text, options, default, cb)
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 0, 26)
    frm.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frm.BorderSizePixel = 0
    frm.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frm

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, -8, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frm

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.5, -12, 0, 20)
    btn.Position = UDim2.new(0.5, 4, 0.5, -10)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    btn.Text = default .. " ▾"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(220, 220, 230)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = frm
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 4); dc.Parent = btn

    local currentValue = default
    local idx = 1
    for i, v in ipairs(options) do if v == default then idx = i; break end end

    btn.MouseButton1Click:Connect(function()
        idx = idx + 1
        if idx > #options then idx = 1 end
        currentValue = options[idx]
        pcall(function() btn.Text = currentValue .. " ▾" end)
        safeCall(cb)(currentValue)
    end)

    return frm
end

local function AddInput(parent, text, placeholder, cb)
    local frm = Instance.new("Frame")
    frm.Size = UDim2.new(1, 0, 0, 26)
    frm.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    frm.BorderSizePixel = 0
    frm.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frm

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.4, -8, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(220, 220, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frm

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0.6, -12, 0, 20)
    input.Position = UDim2.new(0.4, 4, 0.5, -10)
    input.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    input.Text = ""
    input.PlaceholderText = placeholder or ""
    input.Font = Enum.Font.Gotham
    input.TextSize = 11
    input.TextColor3 = Color3.fromRGB(220, 220, 230)
    input.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Parent = frm
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 4); ic.Parent = input

    input.FocusLost:Connect(function()
        safeCall(cb)(input.Text)
    end)

    return frm
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BUILD TABS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- MAIN
local T_Main = CreateTab("Main")
AddSection(T_Main, "X0DEC04T Hub v3.1.0")
AddLabel(T_Main, "Border RP - Stable Build")
AddLabel(T_Main, "Pure ScreenGui | Defer callbacks")
AddSection(T_Main, "Status")
AddLabel(T_Main, "Remotes: " .. (BRP.SpawnVehicleFromSpawner and "OK" or "MISSING"))
AddLabel(T_Main, "Sellers: " .. (BRP_PATHS.NPC and "OK" or "MISSING"))
AddLabel(T_Main, "Vehicles: " .. (BRP_PATHS.Vehicles and "OK" or "MISSING"))

-- SMUGGLER
local T_Smug = CreateTab("Smuggler")
AddSection(T_Smug, "Item")
AddInput(T_Smug, "Item Name", "Fake Diamond Ring", function(v) if v ~= "" then State.Smuggler_ItemName = v end end)

AddSection(T_Smug, "Vehicle")
AddToggle(T_Smug, "Auto Spawn Car", true, function(v) State.Smuggler_SpawnCar = v end)
AddToggle(T_Smug, "Remove Tires", true, function(v) State.Smuggler_RemoveTires = v end)
AddDropdown(T_Smug, "Vehicle", {"Camry6", "BorderPatrolCrownVic", "2020Rs3Done", "jzs171 touring", "TAPVSWAT"}, "Camry6", function(v) State.Smuggler_VehicleName = v end)
AddInput(T_Smug, "Custom Vehicle", "overrides", function(v) if v ~= "" then State.Smuggler_VehicleName = v end end)
AddButton(T_Smug, "Save Spawner Pos", function()
    local h = GetHRP(); if h then State.POS_CarSpawner = h.Position; Log("Saved spawner pos") end
end)
AddButton(T_Smug, "List Spawners (Console)", function()
    local s = FindAllSpawners()
    Log("=== SPAWNERS: " .. #s)
    for i, sp in ipairs(s) do
        Log(string.format("[%d] %s prompt=%s pos=%s", i, sp.container and sp.container.Name or "?", sp.prompt.Name, tostring(sp.position)))
    end
end)

AddSection(T_Smug, "Car TP Method")
AddDropdown(T_Smug, "Method", {"WeldTP", "DirectTP"}, "WeldTP", function(v) State.Smuggler_CarTPMethod = v end)

AddSection(T_Smug, "Equip")
AddToggle(T_Smug, "Auto Equip", true, function(v) State.Smuggler_AutoEquip = v end)
AddToggle(T_Smug, "Equip All", true, function(v) State.Smuggler_EquipAll = v end)

AddSection(T_Smug, "Seller")
AddInput(T_Smug, "Seller Name", "Seller4", function(v) if v ~= "" then State.Smuggler_SellerName = v end end)

AddSection(T_Smug, "TP")
AddToggle(T_Smug, "AntiTp Bypass", true, function(v) State.AntiTpBypass = v; if v then AntiTp.Enable() else AntiTp.Disable() end end)
AddDropdown(T_Smug, "Player TP", {"Tween", "Instant"}, "Tween", function(v) State.TPStrategy = v end)
AddSlider(T_Smug, "Tween Speed", 50, 1000, 200, function(v) State.TweenSpeed = v end)

AddSection(T_Smug, "Timing")
AddSlider(T_Smug, "Cycle Delay", 0, 10, 1, function(v) State.Smuggler_Delay = v end)
AddToggle(T_Smug, "Auto Launder", true, function(v) State.Smuggler_AutoLaunder = v end)
AddToggle(T_Smug, "Debug", false, function(v) State.Smuggler_DebugMode = v end)

AddSection(T_Smug, "MAIN TOGGLE")
AddToggle(T_Smug, "Auto Smuggler Loop", false, function(v) Smuggler.SetAutoLoop(v) end)

AddSection(T_Smug, "Manual Steps")
AddButton(T_Smug, "TP to Spawner", function()
    local sp = FindNearestSpawner()
    if sp then SmartTP.Go(sp.position, 3) else SmartTP.Go(State.POS_CarSpawner, 3) end
end)
AddButton(T_Smug, "1. Buy", function() Smuggler.BuyItem() end)
AddButton(T_Smug, "2. Spawn Car", function() Smuggler.SpawnCar() end)
AddButton(T_Smug, "3. Sit", function()
    local c = State.Smuggler_CurrentCar or GetPlayerCar()
    if c then Smuggler.SitInCar(c) end
end)
AddButton(T_Smug, "4. Remove Tires", function()
    local c = State.Smuggler_CurrentCar or GetPlayerCar()
    if c then Smuggler.RemoveTires(c) end
end)
AddButton(T_Smug, "5. TP Car -> Seller", function()
    local c = State.Smuggler_CurrentCar or GetPlayerCar()
    if c then Smuggler.TeleportCarToSeller(c) end
end)
AddButton(T_Smug, "6. Sell", function() Smuggler.FireSell() end)
AddButton(T_Smug, "7. TP Car -> Laundry", function()
    local c = State.Smuggler_CurrentCar or GetPlayerCar()
    Smuggler.TeleportCarToLaundry(c)
end)
AddButton(T_Smug, "8. Launder", function() Smuggler.FireLaunder() end)

-- VEHICLE
local T_Veh = CreateTab("Vehicle")
AddSection(T_Veh, "Actions")
AddButton(T_Veh, "Flip Car", Car.Flip)
AddButton(T_Veh, "Unstuck", function()
    if BRP.UnstuckVehicle then pcall(function() BRP.UnstuckVehicle:FireServer() end) end
end)

AddSection(T_Veh, "Abilities")
AddToggle(T_Veh, "NoClip", false, function(v) State.NoClip = v; Car.SetNoClip(v) end)
AddToggle(T_Veh, "Fly", false, function(v) State.FlyActive = v; Car.SetFly(v) end)
AddToggle(T_Veh, "God Mode", false, function(v) State.GodMode = v; Car.SetGod(v) end)

AddSection(T_Veh, "Character")
AddSlider(T_Veh, "WalkSpeed", 16, 200, 16, function(v) State.WalkSpeed = v; local h = GetHuman(); if h then pcall(function() h.WalkSpeed = v end) end end)
AddToggle(T_Veh, "Infinite Jump", false, function(v) State.InfiniteJump = v end)

-- TELEPORT
local T_TP = CreateTab("Teleport")
AddSection(T_TP, "Locations")
AddButton(T_TP, "Shop", function() SmartTP.Go(State.POS_Shop, 3) end)
AddButton(T_TP, "Laundry", function() SmartTP.Go(State.POS_Laundry, 3) end)
AddButton(T_TP, "Car Spawner", function()
    local sp = FindNearestSpawner()
    if sp then SmartTP.Go(sp.position, 3) else SmartTP.Go(State.POS_CarSpawner, 3) end
end)

AddSection(T_TP, "Sellers")
if BRP_PATHS.NPC then
    for _, npc in ipairs(BRP_PATHS.NPC:GetChildren()) do
        if npc.Name:lower():find("seller") then
            local nm = npc.Name
            AddButton(T_TP, "TP " .. nm, function()
                local n = BRP_PATHS.NPC:FindFirstChild(nm)
                if n then local h = n:FindFirstChild("HumanoidRootPart"); if h then SmartTP.Go(h.Position, 3) end end
            end)
        end
    end
end

AddInput(T_TP, "Player Name", "case-sensitive", function(v)
    if v == "" then return end
    local t = Players:FindFirstChild(v); if not t or not t.Character then return end
    local th = t.Character:FindFirstChild("HumanoidRootPart")
    if th then SmartTP.Go(th.Position + Vector3.new(0,0,4), 0) end
end)

-- SETTINGS
local T_Set = CreateTab("Settings")
AddSection(T_Set, "General")
AddToggle(T_Set, "Anti-AFK", true, function(v) State.AntiAFK = v end)

AddSection(T_Set, "Danger")
AddButton(T_Set, "PANIC (Off All)", function()
    Smuggler.SetAutoLoop(false)
    State.GodMode = false; State.NoClip = false; State.FlyActive = false
    Car.SetNoClip(false); Car.SetFly(false); Car.SetGod(false)
end)
AddButton(T_Set, "Unload Hub", function()
    Smuggler.SetAutoLoop(false)
    AntiTp.Disable(); DisableNoclip()
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
    CM:Cleanup()
    _G[INSTANCE_KEY] = nil
    pcall(function() ScreenGui:Destroy() end)
end)

-- Show first tab
ShowTab("Main")

-- Toggle key (RightShift)
CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        pcall(function() Main.Visible = not Main.Visible end)
    end
end)

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGod, true) end
    if State.NoClip then pcall(Car.SetNoClip, true) end
    if State.FlyActive then pcall(Car.SetFly, true) end
    if State.AntiTpBypass then AntiTp.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = "3.1.0",
    destroy = function()
        Smuggler.SetAutoLoop(false)
        AntiTp.Disable(); DisableNoclip()
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
        CM:Cleanup()
        pcall(function() ScreenGui:Destroy() end)
    end,
}

Log("v3.1.0 ready - Pure GUI, no external libs")
