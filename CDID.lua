--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.1.0 - Car Driving Indonesia
-- UI: Rayfield | Compatible: Xeno, Delta, Solara, Wave, Codex
--═══════════════════════════════════════════════════════════════

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SERVICES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
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

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DUPLICATE GUARD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local INSTANCE_KEY = "__X0DEC04T_CDI_v210"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOGGER
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local _logStart = os.clock()
local function Log(msg)
    print(string.format("[X0DEC04T][+%.2fs] %s", os.clock() - _logStart, tostring(msg)))
end
local function Err(msg, detail)
    warn(string.format("[X0DEC04T][+%.2fs] ERROR: %s | %s", os.clock() - _logStart, tostring(msg), tostring(detail or "")))
end

Log("CDI Hub v2.1.0 starting...")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOAD RAYFIELD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Rayfield = nil
local RAYFIELD_URLS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}

for _, url in ipairs(RAYFIELD_URLS) do
    Log("Trying: " .. url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        Rayfield = result
        Log("Rayfield loaded OK")
        break
    else
        Err("Mirror failed: " .. url, tostring(result))
    end
end

if not Rayfield then
    Err("FATAL: Rayfield could not be loaded.")
    return
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HUB CONFIG
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Car Driving Indonesia",
    Version = "2.1.0",
    Author  = "voixera",
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONNECTION MANAGER
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CM = { _list = {} }

function CM:Add(signal, callback, label)
    if not signal then
        Err("CM:Add nil signal", tostring(label))
        return nil
    end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then
        table.insert(self._list, conn)
        Log("Signal connected: " .. tostring(label))
        return conn
    end
    Err("CM:Add failed", tostring(label))
    return nil
end

function CM:Cleanup()
    for _, c in ipairs(self._list) do
        pcall(function() c:Disconnect() end)
    end
    self._list = {}
    Log("All connections cleaned up")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOTIFY
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({
            Title    = tostring(title   or ""),
            Content  = tostring(content or ""),
            Duration = tonumber(dur)    or 4,
            Image    = 4483345998,
        })
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE SCANNER + DATABASE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local RemoteDB    = {}
local RemoteDBAll = {}

local function ScanRemotes()
    RemoteDB    = {}
    RemoteDBAll = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local key = obj.Name:lower():gsub("%s+", "")
            RemoteDB[key] = obj
            table.insert(RemoteDBAll, obj)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local key = obj.Name:lower():gsub("%s+", "")
            RemoteDB[key] = obj
            table.insert(RemoteDBAll, obj)
        end
    end
    Log("Remote scan: " .. #RemoteDBAll .. " remotes found")
end

ScanRemotes()

local function FindRemote(name)
    local key = name:lower():gsub("%s+", "")
    if RemoteDB[key] then return RemoteDB[key] end
    for k, v in pairs(RemoteDB) do
        if k:find(key, 1, true) then return v end
    end
    return nil
end

local function DumpRemotes()
    Log("=== REMOTE DUMP (" .. #RemoteDBAll .. " total) ===")
    for _, r in ipairs(RemoteDBAll) do
        Log("  [" .. r.ClassName .. "] " .. r:GetFullName())
    end
    Log("=== END DUMP ===")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CDI EXACT REMOTES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local RRE = ReplicatedStorage:FindFirstChild("ReplicaRemoteEvents")

local R = {
    RequestData = RRE and RRE:FindFirstChild("Replica_ReplicaRequestData"),
    SetValue    = RRE and RRE:FindFirstChild("Replica_ReplicaSetValue"),
    SetValues   = RRE and RRE:FindFirstChild("Replica_ReplicaSetValues"),
    ArrayInsert = RRE and RRE:FindFirstChild("Replica_ReplicaArrayInsert"),
    ArraySet    = RRE and RRE:FindFirstChild("Replica_ReplicaArraySet"),
    ArrayRemove = RRE and RRE:FindFirstChild("Replica_ReplicaArrayRemove"),
    Write       = RRE and RRE:FindFirstChild("Replica_ReplicaWrite"),
    Signal      = RRE and RRE:FindFirstChild("Replica_ReplicaSignal"),
    SetParent   = RRE and RRE:FindFirstChild("Replica_ReplicaSetParent"),
    Create      = RRE and RRE:FindFirstChild("Replica_ReplicaCreate"),
    Destroy     = RRE and RRE:FindFirstChild("Replica_ReplicaDestroy"),
}

for k, v in pairs(R) do
    Log("R." .. k .. " = " .. (v and "OK" or "NOT FOUND"))
end

local function FireByName(name, ...)
    local rem = FindRemote(name)
    if not rem then
        Notify("Remote", "Not found: " .. tostring(name), 3)
        return false
    end
    local args = {...}
    local ok = pcall(function()
        if rem:IsA("RemoteEvent") then rem:FireServer(unpack(args))
        else rem:InvokeServer(unpack(args)) end
    end)
    return ok
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CDI GAME REFERENCES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CDI = {
    Cars        = Workspace:FindFirstChild("Cars"),
    Roads       = Workspace:FindFirstChild("Roads"),
    SpawnPoints = Workspace:FindFirstChild("SpawnPoints"),
    CarData     = ReplicatedStorage:FindFirstChild("CarData"),
    Rank        = ReplicatedStorage:FindFirstChild("Rank"),
    Sound       = ReplicatedStorage:FindFirstChild("Sound"),
}

if not CDI.Cars then
    CDI.Cars = Workspace:FindFirstChild("Vehicles")
            or Workspace:FindFirstChild("car")
            or Workspace:FindFirstChild("Car")
end
if not CDI.SpawnPoints then
    CDI.SpawnPoints = Workspace:FindFirstChild("Spawn")
                   or Workspace:FindFirstChild("SpawnPoint")
end

Log("CDI.Cars = "        .. tostring(CDI.Cars ~= nil))
Log("CDI.SpawnPoints = " .. tostring(CDI.SpawnPoints ~= nil))
Log("CDI.CarData = "     .. tostring(CDI.CarData ~= nil))

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {
    -- ESP
    ESP_Players     = false,
    ESP_Cars        = false,
    ESP_ShowName    = true,
    ESP_ShowDist    = true,
    ESP_MaxDist     = 500,
    Color_Player    = Color3.fromRGB(60,  220, 255),
    Color_Car       = Color3.fromRGB(255, 200,  60),

    -- Car
    CarSpeed        = 0,
    NitroActive     = false,
    FlyActive       = false,
    FlyConn         = nil,
    GodMode         = false,
    NoclipConn      = nil,
    NoClip          = false,
    RainbowCar      = false,
    RainbowConn     = nil,
    SpeedHack       = false,
    SpeedHackConn   = nil,
    SpeedHackValue  = 500,

    -- Freecam / Camera
    Freecam         = false,
    FreecamConn     = nil,

    -- Teleport
    TP_Target       = "",
    SavedPositions  = {},

    -- Remote spam
    RemoteName      = "",
    RemoteArg       = "",
    RemoteSpamConn  = nil,

    -- Folder
    FolderName      = "",

    -- Trucker
    Trucker_AutoAccept  = false,
    Trucker_AutoDeliver = false,
    Trucker_FullLoop    = false,
    Trucker_Delay       = 51,
    Trucker_JobsDone    = 0,
    Trucker_Status      = "Idle",
    Trucker_LoopThread  = nil,
    Trucker_StatusLbl   = nil,

    -- Visuals
    FullBright      = false,
    NoFog           = false,
    NoShadows       = false,
    FOV             = 70,
    ClockTime       = 14,
    RemoveBlur      = false,
    LowGraphics     = false,
    NoParticles     = false,

    -- Misc
    AntiAFK         = true,
    AutoRejoin      = false,
    NoSound         = false,
    MutedSounds     = {},

    -- Internal
    ESPCache        = {},
    LightBackup     = {},
    CurrentCarModel = nil,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function GetCharacter() return LocalPlayer.Character end

local function GetHRP()
    local ch = GetCharacter()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function GetHuman()
    local ch = GetCharacter()
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function GetPlayerCar()
    local ch = GetCharacter()
    if not ch then return nil end
    local carsFolder = CDI.Cars
    if not carsFolder then return nil end
    for _, car in ipairs(carsFolder:GetChildren()) do
        for _, seat in ipairs(car:GetDescendants()) do
            if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) then
                if seat.Occupant and seat.Occupant.Parent == ch then
                    State.CurrentCarModel = car
                    return car
                end
            end
        end
    end
    return nil
end

local function GetVehicleSeat()
    local car = GetPlayerCar()
    if not car then return nil end
    return car:FindFirstChildOfClass("VehicleSeat")
        or car:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function GetCarRoot()
    local car = GetPlayerCar()
    if not car then return nil end
    return car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP SYSTEM
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ESP = {}

function ESP.Clear(obj)
    local cache = State.ESPCache[obj]
    if not cache then return end
    for _, inst in pairs(cache) do
        if typeof(inst) == "Instance" and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
    end
    State.ESPCache[obj] = nil
end

function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Clear(obj) end
    State.ESPCache = {}
end

local function MakeBB(adornee, label, color, showName, showDist, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Adornee        = adornee
    bb.Size           = UDim2.new(0, 220, 0, 55)
    bb.StudsOffset    = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = maxDist or 500
    bb.Parent         = GuiParent()

    local nl = Instance.new("TextLabel", bb)
    nl.Size                   = UDim2.new(1, 0, 0.6, 0)
    nl.BackgroundTransparency = 1
    nl.Text                   = tostring(label or "")
    nl.TextColor3             = color
    nl.TextStrokeTransparency = 0
    nl.Font                   = Enum.Font.GothamBold
    nl.TextSize               = 14
    nl.Visible                = showName

    local dl = Instance.new("TextLabel", bb)
    dl.Size                   = UDim2.new(1, 0, 0.4, 0)
    dl.Position               = UDim2.new(0, 0, 0.6, 0)
    dl.BackgroundTransparency = 1
    dl.Text                   = "0m"
    dl.TextColor3             = Color3.fromRGB(220, 220, 220)
    dl.TextStrokeTransparency = 0
    dl.Font                   = Enum.Font.Gotham
    dl.TextSize               = 12
    dl.Visible                = showDist

    return bb, nl, dl
end

function ESP.AddTarget(adornee, model, label, color)
    if State.ESPCache[adornee] then ESP.Clear(adornee) end

    local hl = Instance.new("Highlight")
    hl.Adornee          = model or adornee
    hl.FillColor        = color
    hl.OutlineColor     = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.5
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = GuiParent()

    local bb, nl, dl = MakeBB(
        adornee, label, color,
        State.ESP_ShowName, State.ESP_ShowDist, State.ESP_MaxDist
    )

    State.ESPCache[adornee] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=adornee }
end

function ESP.UpdateDistances()
    local hrp = GetHRP()
    if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then
            local dist = math.floor((c.hrp.Position - hrp.Position).Magnitude)
            c.dl.Text = dist .. "m"
        end
    end
end

function ESP.Validate()
    for obj in pairs(State.ESPCache) do
        if not obj or not obj.Parent then ESP.Clear(obj) end
    end
end

function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local ch = p.Character
            if ch then
                local hrp = ch:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if State.ESP_Players and not State.ESPCache[hrp] then
                        ESP.AddTarget(hrp, ch, "👤 " .. p.Name, State.Color_Player)
                    elseif not State.ESP_Players then
                        ESP.Clear(hrp)
                    end
                end
            end
        end
    end
end

function ESP.ScanCars()
    if not CDI.Cars then return end
    for _, car in ipairs(CDI.Cars:GetChildren()) do
        local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
        if root then
            if State.ESP_Cars and not State.ESPCache[root] then
                local ownerTag = car:FindFirstChild("Owner")
                    or car:FindFirstChild("PlayerName")
                    or car:FindFirstChild("OwnerName")
                local ownerStr = ownerTag and tostring(ownerTag.Value) or car.Name
                ESP.AddTarget(root, car, "🚘 " .. ownerStr, State.Color_Car)
            elseif not State.ESP_Cars then
                ESP.Clear(root)
            end
        end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers()
    ESP.ScanCars()
end

task.spawn(function()
    while task.wait(2) do pcall(ESP.RefreshAll) end
end)

CM:Add(RunService.Heartbeat, function()
    pcall(ESP.UpdateDistances)
end, "ESP.Heartbeat")

CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then
        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
        if hrp then ESP.Clear(hrp) end
    end
end, "PlayerRemoving")

CM:Add(Players.PlayerAdded, function(p)
    CM:Add(p.CharacterRemoving, function(ch)
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp then ESP.Clear(hrp) end
    end, "CharRemove:" .. p.Name)
end, "PlayerAdded")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CAR FEATURES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Car = {}

function Car.ApplySpeed()
    local seat = GetVehicleSeat()
    if seat then
        local base = 100
        seat.MaxSpeed = base + (tonumber(State.CarSpeed) or 0)
        Notify("Speed", "MaxSpeed = " .. seat.MaxSpeed, 2)
    else
        Notify("Speed", "You must be in a car first.", 3)
    end
end

function Car.ResetSpeed()
    local seat = GetVehicleSeat()
    if seat then
        seat.MaxSpeed = 100
        Notify("Speed", "Reset to default.", 3)
    end
end

function Car.SetSpeedHack(e)
    if State.SpeedHackConn then
        pcall(function() State.SpeedHackConn:Disconnect() end)
        State.SpeedHackConn = nil
    end
    if e then
        State.SpeedHackConn = RunService.Heartbeat:Connect(function()
            local seat = GetVehicleSeat()
            if seat then
                seat.MaxSpeed = tonumber(State.SpeedHackValue) or 500
            end
        end)
        Notify("SpeedHack", "ON - MaxSpeed locked at " .. State.SpeedHackValue, 3)
    else
        Notify("SpeedHack", "OFF", 3)
    end
end

function Car.Flip()
    local car = GetPlayerCar()
    if not car then Notify("Flip", "Get in a car first.", 3); return end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if root then
        root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, root.CFrame.Y, 0)
        Notify("Flip", "Car flipped upright.", 3)
    end
end

function Car.Launch()
    local car = GetPlayerCar()
    if not car then Notify("Launch", "Get in a car first.", 3); return end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if root then
        local bv = Instance.new("BodyVelocity")
        bv.Velocity    = Vector3.new(0, 200, 0)
        bv.MaxForce    = Vector3.new(0, math.huge, 0)
        bv.Parent      = root
        game:GetService("Debris"):AddItem(bv, 0.2)
        Notify("Launch", "Car launched!", 2)
    end
end

function Car.Boost()
    local car = GetPlayerCar()
    if not car then Notify("Boost", "Get in a car first.", 3); return end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if root then
        local bv = Instance.new("BodyVelocity")
        bv.Velocity  = root.CFrame.LookVector * 400
        bv.MaxForce  = Vector3.new(math.huge, 0, math.huge)
        bv.Parent    = root
        game:GetService("Debris"):AddItem(bv, 0.3)
        Notify("Boost", "Forward boost applied!", 2)
    end
end

function Car.SetRainbow(e)
    if State.RainbowConn then
        pcall(function() State.RainbowConn:Disconnect() end)
        State.RainbowConn = nil
    end
    if e then
        State.RainbowConn = RunService.Heartbeat:Connect(function()
            local car = GetPlayerCar()
            if not car then return end
            local hue = (tick() * 0.3) % 1
            local color = Color3.fromHSV(hue, 1, 1)
            for _, p in ipairs(car:GetDescendants()) do
                if p:IsA("BasePart")
                and not p.Name:lower():find("wheel")
                and not p.Name:lower():find("tire") then
                    p.Color = color
                end
            end
        end)
        Notify("Rainbow", "Rainbow car ON!", 3)
    else
        Notify("Rainbow", "OFF", 3)
    end
end

function Car.TeleportToPlayer(name)
    if not name or name == "" then
        Notify("TP", "Enter a player name first.", 3); return
    end
    local target = Players:FindFirstChild(name)
    if not target or not target.Character then
        Notify("TP", "Player not found: " .. name, 3); return
    end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then Notify("TP", "Target has no HRP.", 3); return end

    local car = GetPlayerCar()
    if car then
        local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
        if root then
            root.CFrame = tHRP.CFrame + Vector3.new(0, 5, 6)
            Notify("TP", "Car teleported to " .. name, 3)
            return
        end
    end

    local hrp = GetHRP()
    if hrp then
        hrp.CFrame = tHRP.CFrame + Vector3.new(0, 0, 4)
        Notify("TP", "Teleported to " .. name, 3)
    end
end

function Car.TeleportToSpawn(index)
    if not CDI.SpawnPoints then
        Notify("TP", "No spawn points found.", 3); return
    end
    local spawns = CDI.SpawnPoints:GetChildren()
    local sp = spawns[tonumber(index) or 1]
    if not sp then
        Notify("TP", "Spawn #" .. tostring(index) .. " not found.", 3); return
    end

    local pos = sp:IsA("BasePart") and sp.CFrame
             or (sp.PrimaryPart and sp:GetPrimaryPartCFrame())
    if not pos then Notify("TP", "Invalid spawn.", 3); return end

    local car = GetPlayerCar()
    if car then
        local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
        if root then root.CFrame = pos + Vector3.new(0, 4, 0) end
    else
        local hrp = GetHRP()
        if hrp then hrp.CFrame = pos + Vector3.new(0, 4, 0) end
    end
    Notify("TP", "Teleported to spawn " .. tostring(index), 3)
end

function Car.SavePosition(label)
    local hrp = GetHRP()
    if not hrp then Notify("Save", "No character.", 3); return end
    label = label ~= "" and label or ("Pos" .. (#State.SavedPositions + 1))
    table.insert(State.SavedPositions, { name = label, cframe = hrp.CFrame })
    Notify("Save", "Position '" .. label .. "' saved.", 3)
end

function Car.LoadPosition(label)
    for _, entry in ipairs(State.SavedPositions) do
        if entry.name == label then
            local root = GetCarRoot()
            if root then
                root.CFrame = entry.cframe + Vector3.new(0, 3, 0)
            else
                local hrp = GetHRP()
                if hrp then hrp.CFrame = entry.cframe end
            end
            Notify("Load", "Teleported to '" .. label .. "'", 3)
            return
        end
    end
    Notify("Load", "'" .. label .. "' not found.", 3)
end

function Car.SetNoClip(e)
    if State.NoclipConn then
        pcall(function() State.NoclipConn:Disconnect() end)
        State.NoclipConn = nil
    end
    if e then
        State.NoclipConn = RunService.Stepped:Connect(function()
            local car = GetPlayerCar()
            if car then
                for _, p in ipairs(car:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
            local ch = GetCharacter()
            if ch then
                for _, p in ipairs(ch:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
        Notify("NoClip", "Car NoClip ON", 3)
    else
        Notify("NoClip", "OFF", 3)
    end
end

function Car.SetFly(e)
    if State.FlyConn then
        pcall(function() State.FlyConn:Disconnect() end)
        State.FlyConn = nil
    end

    local h = GetHuman()
    if e then
        if h then h.PlatformStand = true end
        local hrp = GetHRP()
        if hrp then
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            bg.P         = 9e4
            bg.CFrame    = hrp.CFrame
            bg.Parent    = hrp
            bg.Name      = "__FlyGyro"

            local bv = Instance.new("BodyVelocity")
            bv.Velocity  = Vector3.zero
            bv.MaxForce  = Vector3.new(9e9, 9e9, 9e9)
            bv.P         = 9e4
            bv.Parent    = hrp
            bv.Name      = "__FlyVel"

            State.FlyConn = RunService.RenderStepped:Connect(function()
                local hrp2 = GetHRP()
                if not hrp2 then return end
                local bg2 = hrp2:FindFirstChild("__FlyGyro")
                local bv2 = hrp2:FindFirstChild("__FlyVel")
                if not bg2 or not bv2 then return end

                local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 120 or 60
                local cf    = Camera.CFrame
                local mv    = Vector3.zero

                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector  end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space)
                then mv = mv + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                then mv = mv - Vector3.new(0,1,0) end

                bv2.Velocity  = mv * speed
                bg2.CFrame    = cf
            end)
        end
        Notify("Fly", "ON - WASD/Space/Ctrl/Shift=Fast", 4)
    else
        if h then h.PlatformStand = false end
        local hrp = GetHRP()
        if hrp then
            local bg = hrp:FindFirstChild("__FlyGyro")
            local bv = hrp:FindFirstChild("__FlyVel")
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
        end
        Notify("Fly", "OFF", 3)
    end
end

function Car.SetGodMode(e)
    local h = GetHuman()
    if not h then return end
    if e then
        h.MaxHealth = math.huge
        h.Health    = math.huge
        Notify("God Mode", "ON - Invincible!", 3)
    else
        h.MaxHealth = 100
        h.Health    = 100
        Notify("God Mode", "OFF", 3)
    end
end

function Car.DeleteAllCars()
    if not CDI.Cars then Notify("Cars", "Cars folder not found.", 3); return end
    local count = #CDI.Cars:GetChildren()
    for _, c in ipairs(CDI.Cars:GetChildren()) do
        pcall(function() c:Destroy() end)
    end
    Notify("Cars", "Deleted " .. count .. " cars.", 3)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TRUCKER AUTOMATION ENGINE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Trucker = {}

local JobRemote  = ReplicatedStorage:FindFirstChild("NetworkContainer")
    and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents")
    and ReplicatedStorage.NetworkContainer.RemoteEvents:FindFirstChild("Job")

local TruckAreaM = ReplicatedStorage:FindFirstChild("Shared")
    and ReplicatedStorage.Shared:FindFirstChild("TruckArea")

-- Load TruckArea data
local TruckLocations = {}
if TruckAreaM then
    local ok, data = pcall(require, TruckAreaM)
    if ok and typeof(data) == "table" then
        for i, entry in ipairs(data) do
            if entry.txt and entry.Location then
                table.insert(TruckLocations, {
                    name     = tostring(entry.txt),
                    location = entry.Location,
                })
                Log("TruckLoc[" .. i .. "]: " .. tostring(entry.txt))
            end
        end
    end
end
Log("Loaded " .. #TruckLocations .. " truck locations")

function Trucker.SetStatus(txt)
    State.Trucker_Status = txt
    if State.Trucker_StatusLbl then
        pcall(function()
            State.Trucker_StatusLbl:Set("Status: " .. txt
                .. " | Jobs: " .. State.Trucker_JobsDone)
        end)
    end
    Log("[Trucker] " .. txt)
end

function Trucker.GetStarter()
    local etc = Workspace:FindFirstChild("Etc")
    if not etc then return nil end
    local job = etc:FindFirstChild("Job")
    if not job then return nil end
    local truck = job:FindFirstChild("Truck")
    if not truck then return nil end
    local starter = truck:FindFirstChild("Starter")
    if not starter then return nil end
    local prompt = starter:FindFirstChildWhichIsA("ProximityPrompt", true)
    return starter, prompt
end

function Trucker.GetDestination()
    local etc = Workspace:FindFirstChild("Etc")
    if not etc then return nil end
    local job = etc:FindFirstChild("Job")
    if not job then return nil end
    local truck = job:FindFirstChild("Truck")
    if not truck then return nil end
    local destF = truck:FindFirstChild("Destination")
    if not destF then return nil end

    for _, v in ipairs(destF:GetChildren()) do
        if v:IsA("BasePart") then return v end
        if v:IsA("Model") then
            local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if p then return p end
        end
        if v:IsA("Folder") then
            for _, c in ipairs(v:GetDescendants()) do
                if c:IsA("BasePart") then return c end
            end
        end
    end
    return nil
end

function Trucker.GetTruck()
    if not CDI.Cars then return nil end
    local ch = GetCharacter()
    if not ch then return nil end
    for _, car in ipairs(CDI.Cars:GetChildren()) do
        for _, seat in ipairs(car:GetDescendants()) do
            if (seat:IsA("VehicleSeat") or seat:IsA("Seat"))
            and seat.Occupant and seat.Occupant.Parent == ch then
                return car
            end
        end
    end
    return nil
end

function Trucker.AcceptJob()
    Trucker.SetStatus("Accepting job...")
    local starter, prompt = Trucker.GetStarter()
    if not starter then
        Notify("Trucker", "Starter not found!", 3)
        Trucker.SetStatus("Error: no starter")
        return false
    end

    local hrp = GetHRP()
    if hrp and starter:IsA("BasePart") then
        hrp.CFrame = starter.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.5)

        if prompt then
            local ok = pcall(function()
                fireproximityprompt(prompt)
            end)
            if ok then
                Log("Fired ProximityPrompt on Starter")
            else
                Log("fireproximityprompt failed - trying remote")
                if JobRemote then
                    pcall(function() JobRemote:FireServer() end)
                end
            end
        else
            if JobRemote then
                pcall(function() JobRemote:FireServer() end)
                Log("Fired Job remote (no prompt)")
            end
        end
        task.wait(0.5)
    end

    Trucker.SetStatus("Job accepted")
    return true
end

function Trucker.TeleportToDelivery()
    Trucker.SetStatus("Delivering...")
    local dest = Trucker.GetDestination()
    if not dest then
        Notify("Trucker", "No active destination.", 3)
        Trucker.SetStatus("No destination")
        return false
    end

    local truck = Trucker.GetTruck()
    local target = dest.CFrame + Vector3.new(0, 8, 0)

    if truck then
        local root = truck.PrimaryPart or truck:FindFirstChildWhichIsA("BasePart")
        if root then
            for _, p in ipairs(truck:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Velocity = Vector3.zero
                    p.RotVelocity = Vector3.zero
                end
            end
            root.CFrame = target
            task.wait(0.3)
            Log("Truck teleported to delivery: " .. tostring(dest.Position))
            Trucker.SetStatus("Arrived at delivery")
            return true
        end
    else
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = target
            Trucker.SetStatus("Player TP to delivery")
            return true
        end
    end
    return false
end

function Trucker.WaitForComplete(timeout)
    timeout = timeout or 20
    local start = tick()
    while tick() - start < timeout do
        local dest = Trucker.GetDestination()
        if not dest then
            return true
        end
        task.wait(0.3)
    end
    return false
end

function Trucker.SetFullLoop(enable)
    if State.Trucker_LoopThread then
        State.Trucker_LoopThread = nil
    end

    if not enable then
        Trucker.SetStatus("Loop stopped")
        return
    end

    Trucker.SetStatus("Loop started")
    State.Trucker_LoopThread = task.spawn(function()
        while State.Trucker_FullLoop do
            -- Step 1: Accept job if no active destination
            local dest = Trucker.GetDestination()
            if not dest then
                Trucker.AcceptJob()
                task.wait(2)
            end

            -- Step 2: Wait for destination to appear
            local waitStart = tick()
            while not Trucker.GetDestination() and tick() - waitStart < 10 do
                if not State.Trucker_FullLoop then break end
                task.wait(0.3)
            end

            if not State.Trucker_FullLoop then break end

            -- Step 3: Teleport to delivery
            if Trucker.GetDestination() then
                Trucker.TeleportToDelivery()
                task.wait(1)

                -- Step 4: Wait for completion
                if Trucker.WaitForComplete(20) then
                    State.Trucker_JobsDone = State.Trucker_JobsDone + 1
                    Trucker.SetStatus("Job #" .. State.Trucker_JobsDone .. " done!")
                    Notify("Trucker", "Job #" .. State.Trucker_JobsDone .. " completed!", 3)
                else
                    Trucker.SetStatus("Timeout waiting completion")
                end
            end

            -- Step 5: Delay before next job
            local waited = 0
            while waited < State.Trucker_Delay and State.Trucker_FullLoop do
                task.wait(1)
                waited = waited + 1
                Trucker.SetStatus("Waiting " .. (State.Trucker_Delay - waited) .. "s")
            end
        end
        Trucker.SetStatus("Loop ended")
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOLDER ENGINE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local FolderEngine = {}

local function FindFolder(name)
    local key = name:lower():gsub("%s+", "_")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model"))
        and obj.Name:lower():gsub("%s+", "_") == key then
            return obj
        end
    end
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model"))
        and obj.Name:lower():gsub("%s+", "_") == key then
            return obj
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model"))
        and obj.Name:lower():find(name:lower(), 1, true) then
            return obj
        end
    end
    return nil
end

function FolderEngine.Delete(name)
    local f = FindFolder(name)
    if not f then Notify("Folder", "Not found: " .. name, 3); return end
    local fn = f:GetFullName()
    pcall(function() f:Destroy() end)
    Notify("Folder", "Deleted: " .. fn, 4)
end

function FolderEngine.Hide(name)
    local f = FindFolder(name)
    if not f then Notify("Folder", "Not found: " .. name, 3); return end
    local count = 0
    for _, v in ipairs(f:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("UnionOperation") or v:IsA("MeshPart") then
            v.Transparency = 1
            count = count + 1
        end
    end
    Notify("Folder", "Hidden " .. count .. " parts in " .. f.Name, 4)
end

function FolderEngine.Show(name)
    local f = FindFolder(name)
    if not f then Notify("Folder", "Not found: " .. name, 3); return end
    local count = 0
    for _, v in ipairs(f:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("UnionOperation") or v:IsA("MeshPart") then
            v.Transparency = 0
            count = count + 1
        end
    end
    Notify("Folder", "Restored " .. count .. " parts in " .. f.Name, 4)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE EXPLOIT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function ParseArg(str)
    if str == nil or str == "" then return nil end
    local n = tonumber(str)
    if n then return n end
    if str:lower() == "true"  then return true  end
    if str:lower() == "false" then return false end
    return str
end

local RemoteExploit = {}

function RemoteExploit.Fire(remoteName, argStr)
    local rem = FindRemote(remoteName)
    if not rem then
        Notify("Remote", "Not found: " .. tostring(remoteName), 3); return
    end
    local arg = ParseArg(argStr)
    local ok, result = pcall(function()
        if rem:IsA("RemoteEvent") then
            rem:FireServer(arg)
        elseif rem:IsA("RemoteFunction") then
            return rem:InvokeServer(arg)
        end
    end)
    if ok then
        Notify("Remote", "Fired: " .. rem.Name, 3)
        Log("Fired remote: " .. rem:GetFullName() .. " with " .. tostring(arg))
    else
        Notify("Remote", "Error: " .. tostring(result), 4)
    end
end

function RemoteExploit.SetSpam(e, remoteName, argStr, interval)
    if State.RemoteSpamConn then
        pcall(function() State.RemoteSpamConn:Disconnect() end)
        State.RemoteSpamConn = nil
    end
    if e then
        local rem = FindRemote(remoteName)
        if not rem then Notify("Spam", "Not found: " .. remoteName, 3); return end
        local arg = ParseArg(argStr)
        local iv = tonumber(interval) or 0.5
        local last = 0
        State.RemoteSpamConn = RunService.Heartbeat:Connect(function()
            if tick() - last >= iv then
                last = tick()
                pcall(function()
                    if rem:IsA("RemoteEvent") then rem:FireServer(arg)
                    else rem:InvokeServer(arg) end
                end)
            end
        end)
        Notify("Spam", "Spamming " .. rem.Name .. " every " .. iv .. "s", 4)
    else
        Notify("Spam", "OFF", 3)
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Vis = {}

function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient                  = Lighting.Ambient,
        OutdoorAmbient           = Lighting.OutdoorAmbient,
        Brightness               = Lighting.Brightness,
        ClockTime                = Lighting.ClockTime,
        FogEnd                   = Lighting.FogEnd,
        FogStart                 = Lighting.FogStart,
        GlobalShadows            = Lighting.GlobalShadows,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

function Vis.RestoreLight()
    for k, v in pairs(State.LightBackup) do
        pcall(function() Lighting[k] = v end)
    end
end

function Vis.FullBright(e)
    Vis.BackupLight()
    if e then
        Lighting.Ambient                  = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient           = Color3.fromRGB(255,255,255)
        Lighting.Brightness               = 2
        Lighting.ClockTime                = 14
        Lighting.GlobalShadows            = false
        Lighting.EnvironmentDiffuseScale  = 1
        Lighting.EnvironmentSpecularScale = 1
    else
        Vis.RestoreLight()
    end
end

function Vis.NoFog(e)
    Vis.BackupLight()
    if e then
        Lighting.FogEnd   = 999999
        Lighting.FogStart = 999999
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else
        Lighting.FogEnd   = State.LightBackup.FogEnd   or 100000
        Lighting.FogStart = State.LightBackup.FogStart or 0
    end
end

function Vis.NoShadows(e)
    Vis.BackupLight()
    Lighting.GlobalShadows = not e
end

function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel =
            e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

function Vis.SetFOV(f)
    if Camera then Camera.FieldOfView = tonumber(f) or 70 end
end

function Vis.SetClock(t)
    Lighting.ClockTime = tonumber(t) or 14
end

function Vis.RemoveBlur(e)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not e
        end
    end
end

function Vis.NoParticles(e)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire")
        or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Trail") then
            v.Enabled = not e
        end
    end
end

function Vis.MuteAll(e)
    if e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and not table.find(State.MutedSounds, s) then
                table.insert(State.MutedSounds, { s=s, v=s.Volume })
                s.Volume = 0
            end
        end
    else
        for _, entry in ipairs(State.MutedSounds) do
            if entry.s and entry.s.Parent then entry.s.Volume = entry.v end
        end
        State.MutedSounds = {}
    end
end

function Vis.Freecam(e)
    if State.FreecamConn then
        pcall(function() State.FreecamConn:Disconnect() end)
        State.FreecamConn = nil
    end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look  = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local mv    = Vector3.zero
            local spd   = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 6 or 2
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)
            then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            then mv=mv-Vector3.new(0,1,0) end
            pos = pos + mv * spd
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
        Notify("Freecam", "ON - WASD/Space/Ctrl/Shift=Fast", 4)
    else
        Camera.CameraType = Enum.CameraType.Custom
        Notify("Freecam", "OFF", 3)
    end
end

function Vis.ServerHop()
    local ok, e = pcall(function()
        local TS  = game:GetService("TeleportService")
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"
            .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"
        )
        local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if dok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
        Notify("Server Hop", "No server found.", 4)
    end)
    if not ok then Notify("Server Hop", "Error: " .. tostring(e), 4) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTI-AFK & LOOPS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end, "AntiAFK")

task.spawn(function()
    while task.wait(5) do
        if State.FullBright  then pcall(Vis.FullBright, true)  end
        if State.NoFog       then pcall(Vis.NoFog,      true)  end
        if State.NoShadows   then pcall(Vis.NoShadows,  true)  end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if State.GodMode then
            local h = GetHuman()
            if h then
                h.MaxHealth = math.huge
                h.Health    = math.huge
            end
        end
    end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BUILD WINDOW
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Log("Creating window...")

local Window = Rayfield:CreateWindow({
    Name                   = HUB.Name .. "  v" .. HUB.Version,
    LoadingTitle           = HUB.Name,
    LoadingSubtitle        = "Car Driving Indonesia  •  by " .. HUB.Author,
    Theme                  = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

assert(Window, "Window creation failed")
Log("Window created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Tabs = {}
local TAB_DEFS = {
    { key="Main",     name="Main",     icon="home"      },
    { key="Car",      name="Car",      icon="zap"       },
    { key="Trucker",  name="Trucker",  icon="truck"     },
    { key="Teleport", name="Teleport", icon="map-pin"   },
    { key="ESP",      name="ESP",      icon="eye"       },
    { key="Remote",   name="Remotes",  icon="radio"     },
    { key="Folder",   name="Folders",  icon="folder"    },
    { key="Visuals",  name="Visuals",  icon="sun"       },
    { key="Misc",     name="Misc",     icon="wrench"    },
    { key="Settings", name="Settings", icon="settings"  },
}

for _, def in ipairs(TAB_DEFS) do
    local ok, tab = pcall(function()
        return Window:CreateTab(def.name, def.icon)
    end)
    if ok and tab then
        Tabs[def.key] = tab
        Log("Tab: " .. def.name)
    else
        Err("Tab failed: " .. def.name, tostring(tab))
    end
end

assert(next(Tabs), "No tabs created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ELEMENT HELPERS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Sec(tab, name)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateSection(name) end)
    if not ok then Err("Section:" .. name, err) end
end
local function Tog(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateToggle(cfg) end)
    if not ok then Err("Toggle:" .. tostring(label), err) end
end
local function Btn(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateButton(cfg) end)
    if not ok then Err("Button:" .. tostring(label), err) end
end
local function Sld(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateSlider(cfg) end)
    if not ok then Err("Slider:" .. tostring(label), err) end
end
local function Inp(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateInput(cfg) end)
    if not ok then Err("Input:" .. tostring(label), err) end
end
local function Lbl(tab, text)
    if not tab then return end
    local ok, ret = pcall(function() return tab:CreateLabel(text) end)
    if not ok then Err("Label:" .. tostring(text), ret) end
    return ret
end
local function Kbnd(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateKeybind(cfg) end)
    if not ok then Err("Keybind:" .. tostring(label), err) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MAIN TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Main then
    local T = Tabs.Main

    Sec(T, "Welcome")
    Lbl(T, "X0DEC04T Hub v" .. HUB.Version)
    Lbl(T, "Game: Car Driving Indonesia")
    Lbl(T, "Author: " .. HUB.Author)
    Lbl(T, "Executors: Xeno, Delta, Solara, Wave, Codex")

    Sec(T, "Game Info")
    Lbl(T, "Remotes found: " .. #RemoteDBAll)
    Lbl(T, "Cars folder: " .. (CDI.Cars and "OK" or "MISSING"))
    Lbl(T, "Spawns folder: " .. (CDI.SpawnPoints and "OK" or "MISSING"))
    Lbl(T, "ReplicaRemoteEvents: " .. (RRE and "DETECTED" or "MISSING"))
    Lbl(T, "Truck locations: " .. #TruckLocations)

    Sec(T, "Quick Guide")
    Lbl(T, "Trucker tab - Auto job loop")
    Lbl(T, "Car tab - speed, fly, noclip, rainbow, launch")
    Lbl(T, "Teleport tab - players, spawns, saved positions")
    Lbl(T, "RightShift = Toggle UI | End = Panic ESP")

    Sec(T, "Debug Tools")
    Btn(T, {
        Name="Dump All Remotes to Console",
        Callback=DumpRemotes,
    }, "DumpRemotes")
    Btn(T, {
        Name="Rescan Remotes",
        Callback=function()
            ScanRemotes()
            Notify("Scan", "Found " .. #RemoteDBAll .. " remotes", 3)
        end,
    }, "Rescan")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CAR TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Car then
    local T = Tabs.Car

    Sec(T, "Speed Boost")
    Sld(T, {
        Name="Extra Speed",
        Range={0, 500},
        Increment=10,
        CurrentValue=0,
        Flag="CarExtraSpeed",
        Callback=function(v)
            State.CarSpeed = tonumber(v) or 0
            Car.ApplySpeed()
        end,
    }, "CarSpeed")
    Btn(T, {
        Name="Apply Speed Now",
        Callback=Car.ApplySpeed,
    }, "ApplySpeed")
    Btn(T, {
        Name="Reset Speed",
        Callback=function()
            State.CarSpeed = 0
            Car.ResetSpeed()
        end,
    }, "ResetSpeed")

    Sec(T, "Speed Hack (Continuous)")
    Sld(T, {
        Name="SpeedHack Value",
        Range={100, 2000},
        Increment=50,
        CurrentValue=500,
        Flag="SpeedHackVal",
        Callback=function(v)
            State.SpeedHackValue = tonumber(v) or 500
            if State.SpeedHack then Car.SetSpeedHack(true) end
        end,
    }, "SpeedHackVal")
    Tog(T, {
        Name="Speed Hack (locks MaxSpeed)",
        CurrentValue=false,
        Flag="SpeedHack",
        Callback=function(v)
            State.SpeedHack = v
            Car.SetSpeedHack(v)
        end,
    }, "SpeedHack")

    Sec(T, "Car Actions")
    Btn(T, {
        Name="Flip Car (Upright)",
        Callback=Car.Flip,
    }, "Flip")
    Btn(T, {
        Name="Launch Car Upward",
        Callback=Car.Launch,
    }, "Launch")
    Btn(T, {
        Name="Forward Boost",
        Callback=Car.Boost,
    }, "Boost")
    Btn(T, {
        Name="Delete All Cars in Workspace",
        Callback=Car.DeleteAllCars,
    }, "DeleteAllCars")

    Sec(T, "Abilities")
    Tog(T, {
        Name="Car NoClip",
        CurrentValue=false,
        Flag="CarNoClip",
        Callback=function(v)
            State.NoClip = v
            Car.SetNoClip(v)
        end,
    }, "CarNoClip")
    Tog(T, {
        Name="Fly Mode (on foot)",
        CurrentValue=false,
        Flag="FlyMode",
        Callback=function(v)
            State.FlyActive = v
            Car.SetFly(v)
        end,
    }, "FlyMode")
    Tog(T, {
        Name="God Mode",
        CurrentValue=false,
        Flag="GodMode",
        Callback=function(v)
            State.GodMode = v
            Car.SetGodMode(v)
        end,
    }, "GodMode")

    Sec(T, "Visual FX")
    Tog(T, {
        Name="Rainbow Car",
        CurrentValue=false,
        Flag="Rainbow",
        Callback=function(v)
            State.RainbowCar = v
            Car.SetRainbow(v)
        end,
    }, "Rainbow")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TRUCKER TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Trucker then
    local T = Tabs.Trucker

    Sec(T, "Trucker Info")
    Lbl(T, "Locations loaded: " .. #TruckLocations)
    Lbl(T, "Job remote: " .. (JobRemote and "OK" or "MISSING"))
    Lbl(T, "Starter: " .. (Trucker.GetStarter() and "OK" or "N/A - go to Ngawi"))

    Sec(T, "Status")
    State.Trucker_StatusLbl = Lbl(T, "Status: Idle | Jobs: 0")

    Sec(T, "Manual Actions")
    Btn(T, {
        Name = "🚚 Accept Job (TP + Prompt)",
        Callback = Trucker.AcceptJob,
    }, "TruckerAccept")
    Btn(T, {
        Name = "📦 Teleport to Delivery",
        Callback = Trucker.TeleportToDelivery,
    }, "TruckerDeliver")
    Btn(T, {
        Name = "🔍 Show Current Destination",
        Callback = function()
            local d = Trucker.GetDestination()
            if d then
                Notify("Destination", d.Name .. " @ " .. tostring(d.Position), 5)
                Log("Dest: " .. d:GetFullName() .. " pos=" .. tostring(d.Position))
            else
                Notify("Destination", "No active destination.", 3)
            end
        end,
    }, "ShowDest")

    Sec(T, "Full Automation")
    Sld(T, {
        Name = "Delay Between Jobs (seconds)",
        Range = {1, 120},
        Increment = 1,
        CurrentValue = 51,
        Flag = "TruckerDelay",
        Callback = function(v)
            State.Trucker_Delay = tonumber(v) or 51
        end,
    }, "TruckerDelay")
    Tog(T, {
        Name = "🔁 Auto Trucker (Full Loop)",
        CurrentValue = false,
        Flag = "TruckerAutoLoop",
        Callback = function(v)
            State.Trucker_FullLoop = v
            Trucker.SetFullLoop(v)
        end,
    }, "TruckerAutoLoop")

    Sec(T, "Quick TP to Cities")
    for i, loc in ipairs(TruckLocations) do
        Btn(T, {
            Name = "📍 " .. loc.name,
            Callback = function()
                local target = CFrame.new(loc.location) + Vector3.new(0, 8, 0)
                local truck = Trucker.GetTruck()
                if truck then
                    local r = truck.PrimaryPart or truck:FindFirstChildWhichIsA("BasePart")
                    if r then
                        for _, p in ipairs(truck:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.Velocity = Vector3.zero
                                p.RotVelocity = Vector3.zero
                            end
                        end
                        r.CFrame = target
                    end
                else
                    local hrp = GetHRP()
                    if hrp then hrp.CFrame = target end
                end
                Notify("TP", "Teleported to " .. loc.name, 3)
            end,
        }, "TP_"..i)
    end

    Sec(T, "Reset")
    Btn(T, {
        Name = "Reset Job Counter",
        Callback = function()
            State.Trucker_JobsDone = 0
            Trucker.SetStatus("Reset")
        end,
    }, "ResetCount")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TELEPORT TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Teleport then
    local T = Tabs.Teleport

    Sec(T, "Teleport to Player")
    Inp(T, {
        Name="Player Name",
        PlaceholderText="Enter player name (case-sensitive)",
        RemoveTextAfterFocusLost=false,
        Callback=function(v)
            State.TP_Target = tostring(v or "")
        end,
    }, "TPName")
    Btn(T, {
        Name="Teleport to Player",
        Callback=function()
            Car.TeleportToPlayer(State.TP_Target)
        end,
    }, "TPToPlayer")

    Sec(T, "Teleport to Spawn")
    Lbl(T, "Spawns available: " .. (function()
        if CDI.SpawnPoints then return tostring(#CDI.SpawnPoints:GetChildren()) end
        return "0 (folder not found)"
    end)())

    if CDI.SpawnPoints then
        local spawns = CDI.SpawnPoints:GetChildren()
        for i, sp in ipairs(spawns) do
            if i > 15 then break end
            Btn(T, {
                Name="Spawn " .. i .. " - " .. sp.Name,
                Callback=function()
                    Car.TeleportToSpawn(i)
                end,
            }, "Spawn"..i)
        end
    else
        Lbl(T, "SpawnPoints folder not detected.")
    end

    Sec(T, "Saved Positions")
    local savedPosName = ""
    Inp(T, {
        Name="Position Label",
        PlaceholderText="e.g. Garage, Racetrack",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) savedPosName = tostring(v or "") end,
    }, "SavedName")
    Btn(T, {
        Name="Save Current Position",
        Callback=function() Car.SavePosition(savedPosName) end,
    }, "SavePos")
    Btn(T, {
        Name="Load Saved Position",
        Callback=function() Car.LoadPosition(savedPosName) end,
    }, "LoadPos")
    Btn(T, {
        Name="List Saved Positions",
        Callback=function()
            if #State.SavedPositions == 0 then
                Notify("Positions", "No positions saved yet.", 3)
                return
            end
            local list = {}
            for _, e in ipairs(State.SavedPositions) do
                table.insert(list, e.name)
            end
            Notify("Positions", table.concat(list, ", "), 6)
        end,
    }, "ListPos")

    Sec(T, "Quick Tools")
    Btn(T, {
        Name="Print My Position",
        Callback=function()
            local hrp = GetHRP()
            if hrp then
                local p = hrp.Position
                local str = string.format("X:%.1f Y:%.1f Z:%.1f", p.X, p.Y, p.Z)
                Notify("Position", str, 5)
                if setclipboard then setclipboard(str) end
                Log("Position: " .. str)
            end
        end,
    }, "PrintPos")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.ESP then
    local T = Tabs.ESP

    Sec(T, "Player & Car ESP")
    Tog(T, {
        Name="Player ESP",
        CurrentValue=false,
        Flag="PlayerESP",
        Callback=function(v)
            State.ESP_Players = v
            if not v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then ESP.Clear(hrp) end
                    end
                end
            end
        end,
    }, "PlayerESP")
    Tog(T, {
        Name="Car ESP",
        CurrentValue=false,
        Flag="CarESP",
        Callback=function(v)
            State.ESP_Cars = v
            if not v and CDI.Cars then
                for _, car in ipairs(CDI.Cars:GetChildren()) do
                    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
                    if root then ESP.Clear(root) end
                end
            end
        end,
    }, "CarESP")

    Sec(T, "Display")
    Tog(T, {
        Name="Show Names",
        CurrentValue=true,
        Flag="ESPNames",
        Callback=function(v)
            State.ESP_ShowName = v
            for _, c in pairs(State.ESPCache) do
                if c.nl then c.nl.Visible = v end
            end
        end,
    }, "ESPNames")
    Tog(T, {
        Name="Show Distance",
        CurrentValue=true,
        Flag="ESPDist",
        Callback=function(v)
            State.ESP_ShowDist = v
            for _, c in pairs(State.ESPCache) do
                if c.dl then c.dl.Visible = v end
            end
        end,
    }, "ESPDist")
    Sld(T, {
        Name="Max Distance",
        Range={50, 3000},
        Increment=50,
        CurrentValue=500,
        Flag="ESPMaxDist",
        Callback=function(v)
            State.ESP_MaxDist = tonumber(v) or 500
            for _, c in pairs(State.ESPCache) do
                if c.bb then c.bb.MaxDistance = State.ESP_MaxDist end
            end
        end,
    }, "ESPMaxDist")

    Sec(T, "Actions")
    Btn(T, {
        Name="Refresh ESP",
        Callback=function()
            ESP.ClearAll()
            ESP.RefreshAll()
            Notify("ESP","Refreshed!",2)
        end,
    }, "RefreshESP")
    Btn(T, {
        Name="Clear All ESP",
        Callback=function()
            ESP.ClearAll()
            Notify("ESP","Cleared.",2)
        end,
    }, "ClearESP")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Remote then
    local T = Tabs.Remote

    Sec(T, "Remote Info")
    Lbl(T, "Total remotes found: " .. #RemoteDBAll)
    Lbl(T, "Type name (partial OK)")

    Sec(T, "Fire Any Remote")
    Inp(T, {
        Name="Remote Name",
        PlaceholderText="e.g. Job, GiveMoney",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.RemoteName = tostring(v or "") end,
    }, "RemoteName")
    Inp(T, {
        Name="Argument (number/string/true/false)",
        PlaceholderText="e.g. 999999",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.RemoteArg = tostring(v or "") end,
    }, "RemoteArg")
    Btn(T, {
        Name="Fire Remote",
        Callback=function()
            RemoteExploit.Fire(State.RemoteName, State.RemoteArg)
        end,
    }, "FireRemote")

    Sec(T, "Remote Spam")
    local spamInterval = 0.5
    Sld(T, {
        Name="Spam Interval (x0.1 seconds)",
        Range={1, 50},
        Increment=1,
        CurrentValue=5,
        Flag="SpamInterval",
        Callback=function(v) spamInterval = (tonumber(v) or 5) / 10 end,
    }, "SpamInterval")
    Tog(T, {
        Name="Spam Remote (uses fields above)",
        CurrentValue=false,
        Flag="RemoteSpam",
        Callback=function(v)
            RemoteExploit.SetSpam(v, State.RemoteName, State.RemoteArg, spamInterval)
        end,
    }, "RemoteSpam")

    Sec(T, "Debug")
    Btn(T, {
        Name="Dump All Remotes to Console",
        Callback=DumpRemotes,
    }, "DumpR")
    Btn(T, {
        Name="Rescan Remotes",
        Callback=function()
            ScanRemotes()
            Notify("Scan", "Found " .. #RemoteDBAll .. " remotes", 3)
        end,
    }, "RescanR")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOLDER TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Folder then
    local T = Tabs.Folder

    Sec(T, "Folder by Name")
    Lbl(T, "Supports partial match")
    Lbl(T, "Works on Workspace & ReplicatedStorage")
    Inp(T, {
        Name="Folder / Model Name",
        PlaceholderText="e.g. Roads, Cars, Map",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.FolderName = tostring(v or "") end,
    }, "FolderName")
    Btn(T, {
        Name="Delete Folder",
        Callback=function() FolderEngine.Delete(State.FolderName) end,
    }, "DelFolder")
    Btn(T, {
        Name="Hide Folder (transparent)",
        Callback=function() FolderEngine.Hide(State.FolderName) end,
    }, "HideFolder")
    Btn(T, {
        Name="Show Folder (restore)",
        Callback=function() FolderEngine.Show(State.FolderName) end,
    }, "ShowFolder")

    Sec(T, "Quick Deletes")
    Btn(T, {
        Name="Delete All Cars",
        Callback=Car.DeleteAllCars,
    }, "QuickDelCars")
    Btn(T, {
        Name="Delete Roads",
        Callback=function()
            local f = Workspace:FindFirstChild("Roads")
            if f then pcall(function() f:Destroy() end); Notify("Roads", "Deleted!", 3)
            else Notify("Roads", "Not found.", 3) end
        end,
    }, "DelRoads")
    Btn(T, {
        Name="Delete Map",
        Callback=function()
            local f = Workspace:FindFirstChild("Map")
            if f then pcall(function() f:Destroy() end); Notify("Map", "Deleted!", 3)
            else Notify("Map", "Not found.", 3) end
        end,
    }, "DelMap")
    Btn(T, {
        Name="Delete Lighting Effects",
        Callback=function()
            local count = 0
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") or v:IsA("BlurEffect")
                or v:IsA("ColorCorrectionEffect") or v:IsA("SunRaysEffect")
                or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                    pcall(function() v:Destroy() end)
                    count = count + 1
                end
            end
            Notify("Lighting", "Deleted " .. count .. " effects.", 4)
        end,
    }, "DelLightFX")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Visuals then
    local T = Tabs.Visuals

    Sec(T, "Lighting")
    Tog(T, {
        Name="FullBright", CurrentValue=false, Flag="FullBright",
        Callback=function(v) State.FullBright=v; Vis.FullBright(v) end,
    }, "FullBright")
    Tog(T, {
        Name="No Fog", CurrentValue=false, Flag="NoFog",
        Callback=function(v) State.NoFog=v; Vis.NoFog(v) end,
    }, "NoFog")
    Tog(T, {
        Name="No Shadows", CurrentValue=false, Flag="NoShadows",
        Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end,
    }, "NoShadows")
    Sld(T, {
        Name="Time of Day", Range={0,24}, Increment=1,
        CurrentValue=14, Flag="TimeOfDay",
        Callback=function(v) State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime) end,
    }, "TimeOfDay")

    Sec(T, "Camera")
    Sld(T, {
        Name="Field of View", Range={30,120}, Increment=5,
        CurrentValue=70, Flag="FOV",
        Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end,
    }, "FOV")
    Tog(T, {
        Name="Freecam", CurrentValue=false, Flag="Freecam",
        Callback=function(v) State.Freecam=v; Vis.Freecam(v) end,
    }, "Freecam")

    Sec(T, "Post-Processing")
    Tog(T, {
        Name="Remove Blur / Bloom", CurrentValue=false, Flag="RemoveBlur",
        Callback=function(v) State.RemoveBlur=v; Vis.RemoveBlur(v) end,
    }, "RemoveBlur")
    Tog(T, {
        Name="No Particles", CurrentValue=false, Flag="NoParticles",
        Callback=function(v) State.NoParticles=v; Vis.NoParticles(v) end,
    }, "NoParticles")

    Sec(T, "Performance")
    Tog(T, {
        Name="Low Graphics", CurrentValue=false, Flag="LowGfx",
        Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end,
    }, "LowGfx")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MISC TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Misc then
    local T = Tabs.Misc

    Sec(T, "Audio")
    Tog(T, {
        Name="Mute All Sounds", CurrentValue=false, Flag="MuteAll",
        Callback=function(v) State.NoSound=v; Vis.MuteAll(v) end,
    }, "MuteAll")

    Sec(T, "Utility")
    Tog(T, {
        Name="Auto Rejoin", CurrentValue=false, Flag="AutoRejoin",
        Callback=function(v) State.AutoRejoin=v end,
    }, "AutoRejoin")
    Btn(T, {
        Name="Server Hop",
        Callback=Vis.ServerHop,
    }, "ServerHop")
    Btn(T, {
        Name="Copy JobId",
        Callback=function()
            if setclipboard then
                setclipboard(tostring(game.JobId))
                Notify("Copied", "JobId copied!", 3)
            else
                Notify("Error", "Clipboard not supported.", 3)
            end
        end,
    }, "CopyJob")
    Btn(T, {
        Name="Rejoin Server",
        Callback=function()
            pcall(function()
                game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
            end)
        end,
    }, "Rejoin")

    Sec(T, "Character")
    Btn(T, {
        Name="Reset Character",
        Callback=function()
            local h = GetHuman()
            if h then
                h.Health = 0
                Notify("Reset", "Character reset.", 3)
            end
        end,
    }, "ResetChar")
    Btn(T, {
        Name="Respawn at Spawn 1",
        Callback=function() Car.TeleportToSpawn(1) end,
    }, "RespawnSpawn")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SETTINGS TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Settings then
    local T = Tabs.Settings

    Sec(T, "Anti-AFK")
    Tog(T, {
        Name="Anti-AFK", CurrentValue=true, Flag="AntiAFK",
        Callback=function(v) State.AntiAFK=v end,
    }, "AntiAFK")

    Sec(T, "Keybinds")
    Kbnd(T, {
        Name="Toggle UI", CurrentKeybind="RightShift",
        HoldToInteract=false, Flag="KB_UI",
        Callback=function() pcall(function() Window:Toggle() end) end,
    }, "KB_UI")
    Kbnd(T, {
        Name="Panic - Clear All ESP", CurrentKeybind="End",
        HoldToInteract=false, Flag="KB_Panic",
        Callback=function()
            State.ESP_Players = false
            State.ESP_Cars    = false
            ESP.ClearAll()
            Notify("Panic", "All ESP cleared!", 3)
        end,
    }, "KB_Panic")
    Kbnd(T, {
        Name="Flip Car", CurrentKeybind="F",
        HoldToInteract=false, Flag="KB_Flip",
        Callback=Car.Flip,
    }, "KB_Flip")
    Kbnd(T, {
        Name="Launch Car", CurrentKeybind="G",
        HoldToInteract=false, Flag="KB_Launch",
        Callback=Car.Launch,
    }, "KB_Launch")
    Kbnd(T, {
        Name="Forward Boost", CurrentKeybind="H",
        HoldToInteract=false, Flag="KB_Boost",
        Callback=Car.Boost,
    }, "KB_Boost")

    Sec(T, "Credits")
    Lbl(T, HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "Author: " .. HUB.Author)
    Lbl(T, "Game: " .. HUB.Game)
    Lbl(T, "UI: Rayfield")

    Sec(T, "Danger Zone")
    Btn(T, {
        Name="Unload Hub",
        Callback=function()
            State.Trucker_FullLoop = false
            if State.NoclipConn    then pcall(function() State.NoclipConn:Disconnect()    end) end
            if State.FlyConn       then pcall(function() State.FlyConn:Disconnect()       end) end
            if State.FreecamConn   then pcall(function() State.FreecamConn:Disconnect()   end) end
            if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
            if State.RainbowConn   then pcall(function() State.RainbowConn:Disconnect()   end) end
            if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end) end

            local hrp = GetHRP()
            if hrp then
                local bg = hrp:FindFirstChild("__FlyGyro")
                local bv = hrp:FindFirstChild("__FlyVel")
                if bg then pcall(function() bg:Destroy() end) end
                if bv then pcall(function() bv:Destroy() end) end
            end

            local h = GetHuman()
            if h then
                pcall(function()
                    h.PlatformStand = false
                    h.MaxHealth     = 100
                    h.Health        = 100
                end)
            end

            local seat = GetVehicleSeat()
            if seat then pcall(function() seat.MaxSpeed = 100 end) end

            CM:Cleanup()
            Vis.RestoreLight()
            Vis.MuteAll(false)
            pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
            pcall(function() Camera.FieldOfView = 70 end)
            ESP.ClearAll()
            _G[INSTANCE_KEY] = nil
            pcall(function() Window:Destroy() end)
            Log("Hub unloaded.")
        end,
    }, "Unload")
end

Log("All controls created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CHARACTER RESPAWN
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode    then pcall(Car.SetGodMode, true)  end
    if State.NoClip     then pcall(Car.SetNoClip, true)   end
    if State.FlyActive  then pcall(Car.SetFly, true)      end
    if State.FullBright then pcall(Vis.FullBright, true)  end
    if State.NoFog      then pcall(Vis.NoFog, true)       end
    if State.FOV ~= 70  then pcall(Vis.SetFOV, State.FOV) end
    Log("Character respawned - features reapplied")
end, "CharacterAdded")

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end, "OnTeleport")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INSTANCE GUARD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_G[INSTANCE_KEY] = {
    version   = HUB.Version,
    timestamp = os.time(),
    destroy   = function()
        State.Trucker_FullLoop = false
        if State.NoclipConn     then pcall(function() State.NoclipConn:Disconnect()     end) end
        if State.FlyConn        then pcall(function() State.FlyConn:Disconnect()        end) end
        if State.FreecamConn    then pcall(function() State.FreecamConn:Disconnect()    end) end
        if State.SpeedHackConn  then pcall(function() State.SpeedHackConn:Disconnect()  end) end
        if State.RainbowConn    then pcall(function() State.RainbowConn:Disconnect()    end) end
        if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end) end

        local hrp = GetHRP()
        if hrp then
            local bg = hrp:FindFirstChild("__FlyGyro")
            local bv = hrp:FindFirstChild("__FlyVel")
            if bg then pcall(function() bg:Destroy() end) end
            if bv then pcall(function() bv:Destroy() end) end
        end

        local h = GetHuman()
        if h then
            pcall(function()
                h.PlatformStand = false
                h.MaxHealth     = 100
                h.Health        = 100
            end)
        end

        local seat = GetVehicleSeat()
        if seat then pcall(function() seat.MaxSpeed = 100 end) end

        CM:Cleanup()
        Vis.RestoreLight()
        Vis.MuteAll(false)
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DONE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Notify(HUB.Name, "Loaded v" .. HUB.Version .. " - Trucker Auto Ready!", 5)
Log("Initialization complete - v" .. HUB.Version)
