--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.3.0 - Car Driving Indonesia
-- UI: Rayfield | Barista Auto Loop with Overlay
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
local INSTANCE_KEY = "__X0DEC04T_CDI_v230"
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

Log("CDI Hub v2.3.0 starting...")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOAD RAYFIELD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Rayfield = nil
local RAYFIELD_URLS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
for _, url in ipairs(RAYFIELD_URLS) do
    local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(result) == "table" then Rayfield = result; break end
end
if not Rayfield then Err("Rayfield failed"); return end

local HUB = { Name="X0DEC04T Hub", Game="Car Driving Indonesia", Version="2.3.0", Author="voixera" }

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONNECTION MANAGER
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local CM = { _list = {} }
function CM:Add(signal, callback, label)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then table.insert(self._list, conn); return conn end
    return nil
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOTIFY
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Notify(title, content, dur)
    pcall(function()
        Rayfield:Notify({Title=tostring(title or ""), Content=tostring(content or ""), Duration=tonumber(dur) or 4, Image=4483345998})
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE SCANNER
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local RemoteDB, RemoteDBAll = {}, {}
local function ScanRemotes()
    RemoteDB, RemoteDBAll = {}, {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            RemoteDB[obj.Name:lower():gsub("%s+","")] = obj
            table.insert(RemoteDBAll, obj)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            RemoteDB[obj.Name:lower():gsub("%s+","")] = obj
            table.insert(RemoteDBAll, obj)
        end
    end
end
ScanRemotes()

local function FindRemote(name)
    local key = name:lower():gsub("%s+","")
    if RemoteDB[key] then return RemoteDB[key] end
    for k, v in pairs(RemoteDB) do if k:find(key, 1, true) then return v end end
    return nil
end

local function DumpRemotes()
    for _, r in ipairs(RemoteDBAll) do Log("  [" .. r.ClassName .. "] " .. r:GetFullName()) end
end

local CDI = {
    Cars        = Workspace:FindFirstChild("Cars") or Workspace:FindFirstChild("Vehicles"),
    SpawnPoints = Workspace:FindFirstChild("SpawnPoints") or Workspace:FindFirstChild("Spawn"),
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {
    ESP_Players=false, ESP_Cars=false, ESP_ShowName=true, ESP_ShowDist=true, ESP_MaxDist=500,
    Color_Player=Color3.fromRGB(60,220,255), Color_Car=Color3.fromRGB(255,200,60),
    CarSpeed=0, FlyActive=false, FlyConn=nil, GodMode=false,
    NoclipConn=nil, NoClip=false, RainbowCar=false, RainbowConn=nil,
    SpeedHack=false, SpeedHackConn=nil, SpeedHackValue=500,
    Freecam=false, FreecamConn=nil,
    TP_Target="", SavedPositions={},
    RemoteName="", RemoteArg="", RemoteSpamConn=nil,
    FolderName="",

    -- Barista
    Barista_AutoLoop     = false,
    Barista_CoffeeDelay  = 15,
    Barista_Delay        = 2,
    Barista_JobsDone     = 0,
    Barista_Status       = "Idle",
    Barista_StartTime    = 0,
    Barista_Earnings     = 0,
    Barista_PerDelivery  = 5000,
    Barista_StatusLbl    = nil,
    Barista_MoneyBefore  = 0,

    -- Overlay
    Overlay_Gui          = nil,
    Overlay_StatusLbl    = nil,
    Overlay_TimeLbl      = nil,
    Overlay_EarnLbl      = nil,
    Overlay_JobsLbl      = nil,
    Overlay_UpdateConn   = nil,

    FullBright=false, NoFog=false, NoShadows=false, FOV=70, ClockTime=14,
    RemoveBlur=false, LowGraphics=false, NoParticles=false,
    AntiAFK=true, AutoRejoin=false, NoSound=false, MutedSounds={},
    ESPCache={}, LightBackup={}, CurrentCarModel=nil,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HELPERS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function GetCharacter() return LocalPlayer.Character end
local function GetHRP() local ch=GetCharacter(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local ch=GetCharacter(); return ch and ch:FindFirstChildOfClass("Humanoid") end
local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function GetPlayerCar()
    local ch = GetCharacter()
    if not ch or not CDI.Cars then return nil end
    for _, car in ipairs(CDI.Cars:GetChildren()) do
        for _, seat in ipairs(car:GetDescendants()) do
            if (seat:IsA("VehicleSeat") or seat:IsA("Seat")) and seat.Occupant and seat.Occupant.Parent == ch then
                return car
            end
        end
    end
    return nil
end
local function GetVehicleSeat()
    local car = GetPlayerCar()
    return car and (car:FindFirstChildOfClass("VehicleSeat") or car:FindFirstChildWhichIsA("VehicleSeat", true))
end
local function GetCarRoot()
    local car = GetPlayerCar()
    return car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart"))
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FORMAT HELPERS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function FormatTime(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    else
        return string.format("%02d:%02d", m, s)
    end
end

local function FormatMoney(n)
    n = tonumber(n) or 0
    local formatted = tostring(math.floor(n))
    while true do
        local k
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return "RP. " .. formatted
end

-- Try to read player money from leaderstats or common patterns
local function GetPlayerMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local n = v.Name:lower()
            if n:find("money") or n:find("rp") or n:find("cash") or n:find("balance") then
                return tonumber(v.Value) or 0
            end
        end
    end
    for _, key in ipairs({"Money","Cash","Balance","RP"}) do
        local v = LocalPlayer:GetAttribute(key)
        if v then return tonumber(v) or 0 end
    end
    return 0
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP SYSTEM
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ESP = {}
function ESP.Clear(obj)
    local c = State.ESPCache[obj]
    if not c then return end
    for _, inst in pairs(c) do
        if typeof(inst) == "Instance" and inst.Parent then pcall(function() inst:Destroy() end) end
    end
    State.ESPCache[obj] = nil
end
function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Clear(obj) end
    State.ESPCache = {}
end
local function MakeBB(adornee, label, color, showName, showDist, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Adornee=adornee; bb.Size=UDim2.new(0,220,0,55); bb.StudsOffset=Vector3.new(0,4,0)
    bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.MaxDistance=maxDist or 500
    bb.Parent=GuiParent()
    local nl = Instance.new("TextLabel", bb)
    nl.Size=UDim2.new(1,0,0.6,0); nl.BackgroundTransparency=1; nl.Text=tostring(label or "")
    nl.TextColor3=color; nl.TextStrokeTransparency=0; nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Visible=showName
    local dl = Instance.new("TextLabel", bb)
    dl.Size=UDim2.new(1,0,0.4,0); dl.Position=UDim2.new(0,0,0.6,0); dl.BackgroundTransparency=1; dl.Text="0m"
    dl.TextColor3=Color3.fromRGB(220,220,220); dl.TextStrokeTransparency=0; dl.Font=Enum.Font.Gotham; dl.TextSize=12; dl.Visible=showDist
    return bb, nl, dl
end
function ESP.AddTarget(adornee, model, label, color)
    if State.ESPCache[adornee] then ESP.Clear(adornee) end
    local hl = Instance.new("Highlight")
    hl.Adornee=model or adornee; hl.FillColor=color; hl.OutlineColor=Color3.new(1,1,1)
    hl.FillTransparency=0.5; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=GuiParent()
    local bb, nl, dl = MakeBB(adornee, label, color, State.ESP_ShowName, State.ESP_ShowDist, State.ESP_MaxDist)
    State.ESPCache[adornee] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=adornee }
end
function ESP.UpdateDistances()
    local hrp = GetHRP(); if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then
            c.dl.Text = math.floor((c.hrp.Position - hrp.Position).Magnitude) .. "m"
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
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                if State.ESP_Players and not State.ESPCache[hrp] then
                    ESP.AddTarget(hrp, p.Character, p.Name, State.Color_Player)
                elseif not State.ESP_Players then ESP.Clear(hrp) end
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
                ESP.AddTarget(root, car, car.Name, State.Color_Car)
            elseif not State.ESP_Cars then ESP.Clear(root) end
        end
    end
end
function ESP.RefreshAll() ESP.Validate(); ESP.ScanPlayers(); ESP.ScanCars() end
task.spawn(function() while task.wait(2) do pcall(ESP.RefreshAll) end end)
CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDistances) end, "ESP")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CAR FEATURES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Car = {}
function Car.ApplySpeed()
    local seat = GetVehicleSeat()
    if seat then seat.MaxSpeed = 100 + (tonumber(State.CarSpeed) or 0); Notify("Speed","MaxSpeed = "..seat.MaxSpeed, 2)
    else Notify("Speed","Get in a car first.",3) end
end
function Car.ResetSpeed() local seat = GetVehicleSeat(); if seat then seat.MaxSpeed = 100 end end
function Car.SetSpeedHack(e)
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn=nil end
    if e then
        State.SpeedHackConn = RunService.Heartbeat:Connect(function()
            local seat = GetVehicleSeat()
            if seat then seat.MaxSpeed = tonumber(State.SpeedHackValue) or 500 end
        end)
    end
end
function Car.Flip()
    local car = GetPlayerCar(); if not car then Notify("Flip","Get in a car.",3); return end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if root then root.CFrame = CFrame.new(root.Position) end
end
function Car.Launch()
    local root = GetCarRoot(); if not root then Notify("Launch","Get in a car.",3); return end
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0,200,0); bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Parent = root
    game:GetService("Debris"):AddItem(bv, 0.2)
end
function Car.Boost()
    local root = GetCarRoot(); if not root then return end
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = root.CFrame.LookVector * 400; bv.MaxForce = Vector3.new(math.huge, 0, math.huge); bv.Parent = root
    game:GetService("Debris"):AddItem(bv, 0.3)
end
function Car.SetRainbow(e)
    if State.RainbowConn then pcall(function() State.RainbowConn:Disconnect() end); State.RainbowConn=nil end
    if e then
        State.RainbowConn = RunService.Heartbeat:Connect(function()
            local car = GetPlayerCar(); if not car then return end
            local color = Color3.fromHSV((tick()*0.3)%1, 1, 1)
            for _, p in ipairs(car:GetDescendants()) do
                if p:IsA("BasePart") and not p.Name:lower():find("wheel") then p.Color = color end
            end
        end)
    end
end
function Car.TeleportToPlayer(name)
    if not name or name == "" then return end
    local target = Players:FindFirstChild(name); if not target or not target.Character then return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    local root = GetCarRoot()
    if root then root.CFrame = tHRP.CFrame + Vector3.new(0,5,6)
    else local hrp = GetHRP(); if hrp then hrp.CFrame = tHRP.CFrame + Vector3.new(0,0,4) end end
end
function Car.TeleportToSpawn(i)
    if not CDI.SpawnPoints then return end
    local sp = CDI.SpawnPoints:GetChildren()[tonumber(i) or 1]; if not sp then return end
    local pos = sp:IsA("BasePart") and sp.CFrame or (sp.PrimaryPart and sp:GetPrimaryPartCFrame())
    if not pos then return end
    local root = GetCarRoot()
    if root then root.CFrame = pos + Vector3.new(0,4,0)
    else local hrp = GetHRP(); if hrp then hrp.CFrame = pos + Vector3.new(0,4,0) end end
end
function Car.SavePosition(label)
    local hrp = GetHRP(); if not hrp then return end
    label = label ~= "" and label or ("Pos"..(#State.SavedPositions+1))
    table.insert(State.SavedPositions, {name=label, cframe=hrp.CFrame})
end
function Car.LoadPosition(label)
    for _, e in ipairs(State.SavedPositions) do
        if e.name == label then
            local root = GetCarRoot()
            if root then root.CFrame = e.cframe + Vector3.new(0,3,0)
            else local hrp = GetHRP(); if hrp then hrp.CFrame = e.cframe end end
            return
        end
    end
end
function Car.SetNoClip(e)
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn=nil end
    if e then
        State.NoclipConn = RunService.Stepped:Connect(function()
            local car = GetPlayerCar()
            if car then for _,p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
            local ch = GetCharacter()
            if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        end)
    end
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local h = GetHuman()
    if e then
        if h then h.PlatformStand = true end
        local hrp = GetHRP()
        if hrp then
            local bg = Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=9e4; bg.CFrame=hrp.CFrame; bg.Parent=hrp; bg.Name="__FlyGyro"
            local bv = Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=9e4; bv.Parent=hrp; bv.Name="__FlyVel"
            State.FlyConn = RunService.RenderStepped:Connect(function()
                local h2=GetHRP(); if not h2 then return end
                local bg2=h2:FindFirstChild("__FlyGyro"); local bv2=h2:FindFirstChild("__FlyVel")
                if not bg2 or not bv2 then return end
                local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 120 or 60
                local cf = Camera.CFrame; local mv = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
                bv2.Velocity = mv * spd; bg2.CFrame = cf
            end)
        end
    else
        if h then h.PlatformStand=false end
        local hrp=GetHRP()
        if hrp then
            local bg=hrp:FindFirstChild("__FlyGyro"); local bv=hrp:FindFirstChild("__FlyVel")
            if bg then bg:Destroy() end; if bv then bv:Destroy() end
        end
    end
end
function Car.SetGodMode(e)
    local h=GetHuman(); if not h then return end
    if e then h.MaxHealth=math.huge; h.Health=math.huge
    else h.MaxHealth=100; h.Health=100 end
end
function Car.DeleteAllCars()
    if not CDI.Cars then return end
    for _,c in ipairs(CDI.Cars:GetChildren()) do pcall(function() c:Destroy() end) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BARISTA OVERLAY (Black fullscreen with stats)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Overlay = {}

function Overlay.Build()
    if State.Overlay_Gui and State.Overlay_Gui.Parent then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "__BaristaOverlay"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = GuiParent()

    -- Black background covering the whole screen
    local bg = Instance.new("Frame", gui)
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.Position = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BorderSizePixel = 0
    bg.BackgroundTransparency = 0
    bg.ZIndex = 1

    -- Center container
    local container = Instance.new("Frame", bg)
    container.Size = UDim2.new(0, 420, 0, 340)
    container.Position = UDim2.new(0.5, -210, 0.5, -170)
    container.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    container.BorderSizePixel = 0
    container.ZIndex = 2

    local containerCorner = Instance.new("UICorner", container)
    containerCorner.CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", container)
    stroke.Color = Color3.fromRGB(60, 60, 70)
    stroke.Thickness = 1

    -- Title bar
    local titleBar = Instance.new("Frame", container)
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    titleBar.BorderSizePixel = 0
    titleBar.ZIndex = 3
    local tbCorner = Instance.new("UICorner", titleBar)
    tbCorner.CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel", titleBar)
    title.Size = UDim2.new(1, -20, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Barista Auto - Running"
    title.TextColor3 = Color3.fromRGB(230, 230, 235)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 4

    -- Status line
    local statusFrame = Instance.new("Frame", container)
    statusFrame.Size = UDim2.new(1, -30, 0, 60)
    statusFrame.Position = UDim2.new(0, 15, 0, 65)
    statusFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    statusFrame.BorderSizePixel = 0
    statusFrame.ZIndex = 3
    Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)

    local statusTitle = Instance.new("TextLabel", statusFrame)
    statusTitle.Size = UDim2.new(1, -20, 0, 20)
    statusTitle.Position = UDim2.new(0, 10, 0, 6)
    statusTitle.BackgroundTransparency = 1
    statusTitle.Text = "STATUS"
    statusTitle.TextColor3 = Color3.fromRGB(120, 120, 130)
    statusTitle.Font = Enum.Font.Gotham
    statusTitle.TextSize = 11
    statusTitle.TextXAlignment = Enum.TextXAlignment.Left
    statusTitle.ZIndex = 4

    local statusLbl = Instance.new("TextLabel", statusFrame)
    statusLbl.Size = UDim2.new(1, -20, 0, 28)
    statusLbl.Position = UDim2.new(0, 10, 0, 26)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Idle"
    statusLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 18
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.ZIndex = 4

    -- Runtime line
    local timeFrame = Instance.new("Frame", container)
    timeFrame.Size = UDim2.new(1, -30, 0, 60)
    timeFrame.Position = UDim2.new(0, 15, 0, 135)
    timeFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    timeFrame.BorderSizePixel = 0
    timeFrame.ZIndex = 3
    Instance.new("UICorner", timeFrame).CornerRadius = UDim.new(0, 8)

    local timeTitle = Instance.new("TextLabel", timeFrame)
    timeTitle.Size = UDim2.new(1, -20, 0, 20)
    timeTitle.Position = UDim2.new(0, 10, 0, 6)
    timeTitle.BackgroundTransparency = 1
    timeTitle.Text = "RUNTIME"
    timeTitle.TextColor3 = Color3.fromRGB(120, 120, 130)
    timeTitle.Font = Enum.Font.Gotham
    timeTitle.TextSize = 11
    timeTitle.TextXAlignment = Enum.TextXAlignment.Left
    timeTitle.ZIndex = 4

    local timeLbl = Instance.new("TextLabel", timeFrame)
    timeLbl.Size = UDim2.new(1, -20, 0, 28)
    timeLbl.Position = UDim2.new(0, 10, 0, 26)
    timeLbl.BackgroundTransparency = 1
    timeLbl.Text = "00:00"
    timeLbl.TextColor3 = Color3.fromRGB(90, 200, 250)
    timeLbl.Font = Enum.Font.GothamBold
    timeLbl.TextSize = 20
    timeLbl.TextXAlignment = Enum.TextXAlignment.Left
    timeLbl.ZIndex = 4

    -- Earnings line
    local earnFrame = Instance.new("Frame", container)
    earnFrame.Size = UDim2.new(1, -30, 0, 60)
    earnFrame.Position = UDim2.new(0, 15, 0, 205)
    earnFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    earnFrame.BorderSizePixel = 0
    earnFrame.ZIndex = 3
    Instance.new("UICorner", earnFrame).CornerRadius = UDim.new(0, 8)

    local earnTitle = Instance.new("TextLabel", earnFrame)
    earnTitle.Size = UDim2.new(1, -20, 0, 20)
    earnTitle.Position = UDim2.new(0, 10, 0, 6)
    earnTitle.BackgroundTransparency = 1
    earnTitle.Text = "EARNINGS"
    earnTitle.TextColor3 = Color3.fromRGB(120, 120, 130)
    earnTitle.Font = Enum.Font.Gotham
    earnTitle.TextSize = 11
    earnTitle.TextXAlignment = Enum.TextXAlignment.Left
    earnTitle.ZIndex = 4

    local earnLbl = Instance.new("TextLabel", earnFrame)
    earnLbl.Size = UDim2.new(1, -20, 0, 28)
    earnLbl.Position = UDim2.new(0, 10, 0, 26)
    earnLbl.BackgroundTransparency = 1
    earnLbl.Text = "RP. 0"
    earnLbl.TextColor3 = Color3.fromRGB(120, 240, 140)
    earnLbl.Font = Enum.Font.GothamBold
    earnLbl.TextSize = 20
    earnLbl.TextXAlignment = Enum.TextXAlignment.Left
    earnLbl.ZIndex = 4

    -- Jobs count (bottom line)
    local jobsLbl = Instance.new("TextLabel", container)
    jobsLbl.Size = UDim2.new(1, -30, 0, 26)
    jobsLbl.Position = UDim2.new(0, 15, 0, 280)
    jobsLbl.BackgroundTransparency = 1
    jobsLbl.Text = "Deliveries: 0"
    jobsLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
    jobsLbl.Font = Enum.Font.Gotham
    jobsLbl.TextSize = 14
    jobsLbl.TextXAlignment = Enum.TextXAlignment.Left
    jobsLbl.ZIndex = 4

    -- Footer hint
    local hint = Instance.new("TextLabel", bg)
    hint.Size = UDim2.new(1, 0, 0, 20)
    hint.Position = UDim2.new(0, 0, 1, -30)
    hint.BackgroundTransparency = 1
    hint.Text = "Turn off Auto Barista in the hub to close"
    hint.TextColor3 = Color3.fromRGB(80, 80, 90)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 12
    hint.ZIndex = 2

    State.Overlay_Gui       = gui
    State.Overlay_StatusLbl = statusLbl
    State.Overlay_TimeLbl   = timeLbl
    State.Overlay_EarnLbl   = earnLbl
    State.Overlay_JobsLbl   = jobsLbl
end

function Overlay.Show()
    Overlay.Build()
    if State.Overlay_Gui then State.Overlay_Gui.Enabled = true end

    -- Live updater
    if State.Overlay_UpdateConn then
        pcall(function() State.Overlay_UpdateConn:Disconnect() end)
    end
    State.Overlay_UpdateConn = RunService.Heartbeat:Connect(function()
        if not State.Overlay_TimeLbl then return end
        local elapsed = tick() - State.Barista_StartTime
        pcall(function()
            State.Overlay_TimeLbl.Text   = FormatTime(elapsed)
            State.Overlay_EarnLbl.Text   = FormatMoney(State.Barista_Earnings)
            State.Overlay_JobsLbl.Text   = "Deliveries: " .. State.Barista_JobsDone
            State.Overlay_StatusLbl.Text = State.Barista_Status
        end)
    end)
end

function Overlay.Hide()
    if State.Overlay_UpdateConn then
        pcall(function() State.Overlay_UpdateConn:Disconnect() end)
        State.Overlay_UpdateConn = nil
    end
    if State.Overlay_Gui then
        pcall(function() State.Overlay_Gui:Destroy() end)
        State.Overlay_Gui       = nil
        State.Overlay_StatusLbl = nil
        State.Overlay_TimeLbl   = nil
        State.Overlay_EarnLbl   = nil
        State.Overlay_JobsLbl   = nil
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BARISTA AUTOMATION
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Barista = {}

local BARISTA_POS = {
    JobSelection = Vector3.new(-2707.53, 5.71, 945.41),
    CoffeeMaker  = Vector3.new(383.72,  7.15, 1334.33),
    Standby      = Vector3.new(387.46,  6.60, 1334.43),
}

function Barista.SetStatus(txt)
    State.Barista_Status = txt
    if State.Barista_StatusLbl then
        pcall(function()
            State.Barista_StatusLbl:Set("Status: " .. txt .. " | Coffees: " .. State.Barista_JobsDone)
        end)
    end
    Log("[Barista] " .. txt)
end

function Barista.TeleportTo(pos, yOffset)
    local hrp = GetHRP(); if not hrp then return false end
    yOffset = yOffset or 3
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOffset, 0))
    return true
end

function Barista.FirePrompt(prompt)
    if not prompt or not prompt.Enabled then return false end
    local ok = pcall(function()
        if fireproximityprompt then fireproximityprompt(prompt) end
    end)
    return ok
end

function Barista.FindPromptByText(parent, action, object)
    if not parent then return nil end
    for _, v in ipairs(parent:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local a = tostring(v.ActionText):lower()
            local o = tostring(v.ObjectText):lower()
            if (not action or a:find(action:lower(), 1, true))
            and (not object or o:find(object:lower(), 1, true)) then
                return v
            end
        end
    end
    return nil
end

function Barista.GetJobSelectionPrompt()
    local sel = Workspace.Etc.Job:FindFirstChild("Selection")
    if sel then return sel:FindFirstChildWhichIsA("ProximityPrompt", true) end
    return nil
end

function Barista.GetCoffeePrompt()
    local jj = Workspace.Etc.Job:FindFirstChild("JanjiJiwa")
    if jj then
        local starter = jj:FindFirstChild("Starter")
        if starter then
            return Barista.FindPromptByText(starter, "make", "coffee")
                or starter:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
    end
    return nil
end

function Barista.GetDeliveryPrompt()
    local npcFolder = Workspace:FindFirstChild("NPC")
    if not npcFolder then return nil end
    for _, npc in ipairs(npcFolder:GetChildren()) do
        for _, v in ipairs(npc:GetDescendants()) do
            if v:IsA("ProximityPrompt") and v.Enabled then
                local a = tostring(v.ActionText):lower()
                local o = tostring(v.ObjectText):lower()
                if a:find("deliver") or o:find("coffee") or a:find("give") then
                    return v, npc
                end
            end
        end
    end
    return nil
end

function Barista.SelectJob()
    Barista.SetStatus("Opening job selection")
    Barista.TeleportTo(BARISTA_POS.JobSelection, 3)
    task.wait(0.7)
    local prompt = Barista.GetJobSelectionPrompt()
    if prompt then Barista.FirePrompt(prompt) end
    task.wait(1.5)
    Barista.SetStatus("Job selector opened")
    return true
end

function Barista.GoToCoffeeMaker()
    Barista.SetStatus("Moving to coffee maker")
    Barista.TeleportTo(BARISTA_POS.CoffeeMaker, 3)
    task.wait(0.5)
    return true
end

function Barista.MakeCoffee()
    Barista.SetStatus("Making coffee")
    local prompt = Barista.GetCoffeePrompt()
    if not prompt then Barista.SetStatus("No coffee prompt"); return false end
    Barista.FirePrompt(prompt)
    local delay = tonumber(State.Barista_CoffeeDelay) or 15
    local elapsed = 0
    while elapsed < delay and State.Barista_AutoLoop do
        task.wait(1)
        elapsed = elapsed + 1
        Barista.SetStatus("Brewing " .. (delay - elapsed) .. "s")
    end
    return true
end

function Barista.Deliver()
    Barista.SetStatus("Finding customer")
    local start = tick()
    local prompt, npc
    while tick() - start < 8 do
        prompt, npc = Barista.GetDeliveryPrompt()
        if prompt then break end
        task.wait(0.3)
    end
    if not prompt or not npc then Barista.SetStatus("No customer found"); return false end

    local hrpNPC = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
    if hrpNPC then
        local hrp = GetHRP()
        if hrp then hrp.CFrame = hrpNPC.CFrame + Vector3.new(0, 0, 3); task.wait(0.5) end
    end

    local moneyBefore = GetPlayerMoney()
    Barista.FirePrompt(prompt)
    task.wait(0.8)
    local moneyAfter = GetPlayerMoney()

    State.Barista_JobsDone = State.Barista_JobsDone + 1

    -- Prefer real money delta if leaderstats gave a positive number
    local delta = moneyAfter - moneyBefore
    if delta > 0 then
        State.Barista_Earnings = State.Barista_Earnings + delta
    else
        State.Barista_Earnings = State.Barista_Earnings + (tonumber(State.Barista_PerDelivery) or 5000)
    end

    Barista.SetStatus("Delivered #" .. State.Barista_JobsDone)
    return true
end

function Barista.SetAutoLoop(enable)
    State.Barista_AutoLoop = enable
    if not enable then
        Barista.SetStatus("Loop stopped")
        Overlay.Hide()
        return
    end

    -- Reset session stats
    State.Barista_StartTime  = tick()
    State.Barista_Earnings   = 0
    State.Barista_JobsDone   = 0
    Barista.SetStatus("Loop starting")

    Overlay.Show()

    task.spawn(function()
        Barista.SelectJob()
        task.wait(4)  -- give user a moment to click Janji Jawa Barista

        while State.Barista_AutoLoop do
            Barista.GoToCoffeeMaker(); task.wait(0.5)
            if not State.Barista_AutoLoop then break end

            Barista.MakeCoffee()
            if not State.Barista_AutoLoop then break end

            Barista.Deliver()
            if not State.Barista_AutoLoop then break end

            task.wait(State.Barista_Delay)
        end
        Barista.SetStatus("Loop ended")
        Overlay.Hide()
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOLDER ENGINE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local FolderEngine = {}
local function FindFolder(name)
    local key = name:lower():gsub("%s+","_")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and obj.Name:lower():gsub("%s+","_") == key then return obj end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and obj.Name:lower():find(name:lower(), 1, true) then return obj end
    end
    return nil
end
function FolderEngine.Delete(name) local f=FindFolder(name); if f then pcall(function() f:Destroy() end); Notify("Folder","Deleted "..f.Name,3) end end
function FolderEngine.Hide(name)
    local f=FindFolder(name); if not f then return end
    for _,v in ipairs(f:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=1 end end
end
function FolderEngine.Show(name)
    local f=FindFolder(name); if not f then return end
    for _,v in ipairs(f:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=0 end end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE EXPLOIT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function ParseArg(str)
    if not str or str == "" then return nil end
    local n = tonumber(str); if n then return n end
    if str:lower() == "true" then return true end
    if str:lower() == "false" then return false end
    return str
end
local RemoteExploit = {}
function RemoteExploit.Fire(name, argStr)
    local rem = FindRemote(name); if not rem then Notify("Remote","Not found: "..name,3); return end
    local arg = ParseArg(argStr)
    pcall(function()
        if rem:IsA("RemoteEvent") then rem:FireServer(arg) else rem:InvokeServer(arg) end
    end)
    Notify("Remote","Fired "..rem.Name,3)
end
function RemoteExploit.SetSpam(e, name, argStr, iv)
    if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end); State.RemoteSpamConn=nil end
    if e then
        local rem = FindRemote(name); if not rem then return end
        local arg = ParseArg(argStr); local last = 0
        State.RemoteSpamConn = RunService.Heartbeat:Connect(function()
            if tick()-last >= (iv or 0.5) then
                last = tick()
                pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(arg) else rem:InvokeServer(arg) end end)
            end
        end)
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Vis = {}
function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,
    }
end
function Vis.RestoreLight() for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e)
    Vis.BackupLight()
    if e then
        Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false
    else Vis.RestoreLight() end
end
function Vis.NoFog(e) Vis.BackupLight(); if e then Lighting.FogEnd=999999; Lighting.FogStart=999999 else Lighting.FogEnd=State.LightBackup.FogEnd or 100000 end end
function Vis.NoShadows(e) Vis.BackupLight(); Lighting.GlobalShadows = not e end
function Vis.LowGfx(e) pcall(function() settings().Rendering.QualityLevel = e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end) end
function Vis.SetFOV(f) if Camera then Camera.FieldOfView = tonumber(f) or 70 end end
function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end
function Vis.RemoveBlur(e)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then v.Enabled = not e end
    end
end
function Vis.NoParticles(e)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Trail") then v.Enabled = not e end
    end
end
function Vis.MuteAll(e)
    if e then
        for _,s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") then table.insert(State.MutedSounds, {s=s, v=s.Volume}); s.Volume=0 end
        end
    else
        for _,en in ipairs(State.MutedSounds) do if en.s and en.s.Parent then en.s.Volume=en.v end end
        State.MutedSounds = {}
    end
end
function Vis.Freecam(e)
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end); State.FreecamConn=nil end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look=Camera.CFrame.LookVector; local right=Camera.CFrame.RightVector
            local mv=Vector3.zero; local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 6 or 2
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
            pos = pos + mv * spd
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else Camera.CameraType = Enum.CameraType.Custom end
end
function Vis.ServerHop()
    pcall(function()
        local TS = game:GetService("TeleportService")
        local raw = game:HttpGet("https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(raw)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); return
            end
        end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTI-AFK & LOOPS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end
end, "AntiAFK")
task.spawn(function() while task.wait(5) do
    if State.FullBright then pcall(Vis.FullBright,true) end
    if State.NoFog then pcall(Vis.NoFog,true) end
end end)
task.spawn(function() while task.wait(1) do
    if State.GodMode then local h=GetHuman(); if h then h.MaxHealth=math.huge; h.Health=math.huge end end
end end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WINDOW
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Window = Rayfield:CreateWindow({
    Name = HUB.Name .. "  v" .. HUB.Version,
    LoadingTitle = HUB.Name,
    LoadingSubtitle = "Car Driving Indonesia - by " .. HUB.Author,
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})
assert(Window, "Window failed")

local Tabs = {}
local TAB_DEFS = {
    { key="Main",     name="Main",     icon="home"     },
    { key="Car",      name="Car",      icon="zap"      },
    { key="Barista",  name="Barista",  icon="coffee"   },
    { key="Teleport", name="Teleport", icon="map-pin"  },
    { key="ESP",      name="ESP",      icon="eye"      },
    { key="Remote",   name="Remotes",  icon="radio"    },
    { key="Folder",   name="Folders",  icon="folder"   },
    { key="Visuals",  name="Visuals",  icon="sun"      },
    { key="Misc",     name="Misc",     icon="wrench"   },
    { key="Settings", name="Settings", icon="settings" },
}
for _, def in ipairs(TAB_DEFS) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok then Tabs[def.key] = tab end
end

local function Sec(t,n) if t then pcall(function() t:CreateSection(n) end) end end
local function Tog(t,c) if t then pcall(function() t:CreateToggle(c) end) end end
local function Btn(t,c) if t then pcall(function() t:CreateButton(c) end) end end
local function Sld(t,c) if t then pcall(function() t:CreateSlider(c) end) end end
local function Inp(t,c) if t then pcall(function() t:CreateInput(c) end) end end
local function Lbl(t,x) if t then local ok,r=pcall(function() return t:CreateLabel(x) end); return r end end
local function Kbnd(t,c) if t then pcall(function() t:CreateKeybind(c) end) end end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MAIN TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Main then
    local T = Tabs.Main
    Sec(T,"Welcome")
    Lbl(T, "X0DEC04T Hub v" .. HUB.Version)
    Lbl(T, "Game: Car Driving Indonesia")
    Lbl(T, "Author: " .. HUB.Author)
    Sec(T,"Info")
    Lbl(T, "Remotes: " .. #RemoteDBAll)
    Lbl(T, "Cars: " .. (CDI.Cars and "OK" or "MISSING"))
    Sec(T,"Guide")
    Lbl(T, "Barista tab - Auto Janji Jawa job")
    Lbl(T, "Car tab - speed, fly, noclip")
    Lbl(T, "RightShift = Toggle UI")
    Btn(T, {Name="Dump Remotes", Callback=DumpRemotes})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CAR TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Car then
    local T = Tabs.Car
    Sec(T,"Speed")
    Sld(T, {Name="Extra Speed", Range={0,500}, Increment=10, CurrentValue=0, Flag="ES", Callback=function(v) State.CarSpeed=v; Car.ApplySpeed() end})
    Btn(T, {Name="Apply Speed", Callback=Car.ApplySpeed})
    Btn(T, {Name="Reset Speed", Callback=function() State.CarSpeed=0; Car.ResetSpeed() end})
    Sec(T,"Speed Hack")
    Sld(T, {Name="SpeedHack Value", Range={100,2000}, Increment=50, CurrentValue=500, Flag="SHV", Callback=function(v) State.SpeedHackValue=v; if State.SpeedHack then Car.SetSpeedHack(true) end end})
    Tog(T, {Name="Speed Hack", CurrentValue=false, Flag="SH", Callback=function(v) State.SpeedHack=v; Car.SetSpeedHack(v) end})
    Sec(T,"Actions")
    Btn(T, {Name="Flip Car", Callback=Car.Flip})
    Btn(T, {Name="Launch", Callback=Car.Launch})
    Btn(T, {Name="Boost", Callback=Car.Boost})
    Btn(T, {Name="Delete All Cars", Callback=Car.DeleteAllCars})
    Sec(T,"Abilities")
    Tog(T, {Name="NoClip", CurrentValue=false, Flag="NC", Callback=function(v) State.NoClip=v; Car.SetNoClip(v) end})
    Tog(T, {Name="Fly (on foot)", CurrentValue=false, Flag="FL", Callback=function(v) State.FlyActive=v; Car.SetFly(v) end})
    Tog(T, {Name="God Mode", CurrentValue=false, Flag="GM", Callback=function(v) State.GodMode=v; Car.SetGodMode(v) end})
    Tog(T, {Name="Rainbow Car", CurrentValue=false, Flag="RB", Callback=function(v) State.RainbowCar=v; Car.SetRainbow(v) end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BARISTA TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Barista then
    local T = Tabs.Barista

    Sec(T, "Janji Jawa Barista")
    Lbl(T, "Auto Coffee Making & Delivery")
    Lbl(T, "Job Selection: " .. (Barista.GetJobSelectionPrompt() and "OK" or "N/A"))
    Lbl(T, "Coffee Maker: " .. (Barista.GetCoffeePrompt() and "OK" or "N/A - go inside shop"))

    Sec(T, "Status")
    State.Barista_StatusLbl = Lbl(T, "Status: Idle | Coffees: 0")

    Sec(T, "How to use")
    Lbl(T, "1. Toggle Auto Loop ON")
    Lbl(T, "2. Job UI opens - click Janji Jawa Barista")
    Lbl(T, "3. Black overlay appears with stats")
    Lbl(T, "4. Toggle OFF to close overlay")

    Sec(T, "Timing")
    Sld(T, {
        Name = "Coffee Brew Delay (seconds)",
        Range = {5, 30}, Increment = 1, CurrentValue = 15, Flag = "BaristaCoffeeDelay",
        Callback = function(v) State.Barista_CoffeeDelay = tonumber(v) or 15 end,
    })
    Sld(T, {
        Name = "Cycle Delay (seconds)",
        Range = {1, 10}, Increment = 1, CurrentValue = 2, Flag = "BaristaDelay",
        Callback = function(v) State.Barista_Delay = tonumber(v) or 2 end,
    })
    Sld(T, {
        Name = "Est. Earnings per Delivery (RP)",
        Range = {1000, 50000}, Increment = 500, CurrentValue = 5000, Flag = "BaristaPer",
        Callback = function(v) State.Barista_PerDelivery = tonumber(v) or 5000 end,
    })

    Sec(T, "Automation")
    Tog(T, {
        Name = "Auto Barista (Full Loop)",
        CurrentValue = false, Flag = "BaristaAuto",
        Callback = function(v) Barista.SetAutoLoop(v) end,
    })

    Sec(T, "Manual Steps")
    Btn(T, {Name="1. Open Job Selection", Callback=function() Barista.SelectJob() end})
    Btn(T, {Name="2. TP to Coffee Maker", Callback=function() Barista.GoToCoffeeMaker() end})
    Btn(T, {Name="3. Make Coffee", Callback=function()
        local p = Barista.GetCoffeePrompt()
        if p then Barista.FirePrompt(p); Notify("Barista","Coffee prompt fired",2)
        else Notify("Barista","No coffee prompt",3) end
    end})
    Btn(T, {Name="4. Deliver to Customer", Callback=function() Barista.Deliver() end})

    Sec(T, "Debug")
    Btn(T, {Name="Find Customer", Callback=function()
        local p, npc = Barista.GetDeliveryPrompt()
        if p then Notify("Customer", npc.Name .. " found", 4); Log("Customer: " .. npc:GetFullName())
        else Notify("Customer", "No active customer.", 3) end
    end})
    Btn(T, {Name="Reset Counter", Callback=function()
        State.Barista_JobsDone = 0
        State.Barista_Earnings = 0
        State.Barista_StartTime = tick()
        Barista.SetStatus("Reset")
    end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TELEPORT TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Teleport then
    local T = Tabs.Teleport
    Sec(T,"Player TP")
    Inp(T, {Name="Player Name", PlaceholderText="Case-sensitive", RemoveTextAfterFocusLost=false, Callback=function(v) State.TP_Target=v end})
    Btn(T, {Name="TP to Player", Callback=function() Car.TeleportToPlayer(State.TP_Target) end})
    Sec(T,"Spawns")
    if CDI.SpawnPoints then
        for i, sp in ipairs(CDI.SpawnPoints:GetChildren()) do
            if i > 15 then break end
            Btn(T, {Name="Spawn "..i.." - "..sp.Name, Callback=function() Car.TeleportToSpawn(i) end})
        end
    else Lbl(T,"No spawn points found") end
    Sec(T,"Saved Positions")
    local sp = ""
    Inp(T, {Name="Label", PlaceholderText="e.g. Garage", RemoveTextAfterFocusLost=false, Callback=function(v) sp=v end})
    Btn(T, {Name="Save", Callback=function() Car.SavePosition(sp); Notify("Saved",sp,2) end})
    Btn(T, {Name="Load", Callback=function() Car.LoadPosition(sp) end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.ESP then
    local T = Tabs.ESP
    Sec(T,"ESP")
    Tog(T, {Name="Player ESP", CurrentValue=false, Flag="PE", Callback=function(v) State.ESP_Players=v; if not v then for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then local h=p.Character:FindFirstChild("HumanoidRootPart"); if h then ESP.Clear(h) end end end end end})
    Tog(T, {Name="Car ESP", CurrentValue=false, Flag="CE", Callback=function(v) State.ESP_Cars=v; if not v and CDI.Cars then for _,c in ipairs(CDI.Cars:GetChildren()) do local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then ESP.Clear(r) end end end end})
    Sec(T,"Display")
    Tog(T, {Name="Names", CurrentValue=true, Flag="EN", Callback=function(v) State.ESP_ShowName=v; for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end end})
    Tog(T, {Name="Distance", CurrentValue=true, Flag="ED", Callback=function(v) State.ESP_ShowDist=v; for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end end})
    Sld(T, {Name="Max Distance", Range={50,3000}, Increment=50, CurrentValue=500, Flag="EMD", Callback=function(v) State.ESP_MaxDist=v; for _,c in pairs(State.ESPCache) do if c.bb then c.bb.MaxDistance=v end end end})
    Sec(T,"Actions")
    Btn(T, {Name="Refresh", Callback=function() ESP.ClearAll(); ESP.RefreshAll() end})
    Btn(T, {Name="Clear All", Callback=ESP.ClearAll})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Remote then
    local T = Tabs.Remote
    Sec(T,"Info"); Lbl(T,"Total: " .. #RemoteDBAll)
    Sec(T,"Fire")
    Inp(T, {Name="Name", PlaceholderText="Remote name", RemoveTextAfterFocusLost=false, Callback=function(v) State.RemoteName=v end})
    Inp(T, {Name="Arg", PlaceholderText="Argument", RemoveTextAfterFocusLost=false, Callback=function(v) State.RemoteArg=v end})
    Btn(T, {Name="Fire", Callback=function() RemoteExploit.Fire(State.RemoteName, State.RemoteArg) end})
    Sec(T,"Spam")
    local iv=0.5
    Sld(T, {Name="Interval x0.1s", Range={1,50}, Increment=1, CurrentValue=5, Flag="SI", Callback=function(v) iv=v/10 end})
    Tog(T, {Name="Spam", CurrentValue=false, Flag="SP", Callback=function(v) RemoteExploit.SetSpam(v, State.RemoteName, State.RemoteArg, iv) end})
    Btn(T, {Name="Dump Remotes", Callback=DumpRemotes})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FOLDER TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Folder then
    local T = Tabs.Folder
    Sec(T,"Folder Control")
    Inp(T, {Name="Name", PlaceholderText="e.g. Roads", RemoveTextAfterFocusLost=false, Callback=function(v) State.FolderName=v end})
    Btn(T, {Name="Delete", Callback=function() FolderEngine.Delete(State.FolderName) end})
    Btn(T, {Name="Hide", Callback=function() FolderEngine.Hide(State.FolderName) end})
    Btn(T, {Name="Show", Callback=function() FolderEngine.Show(State.FolderName) end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Visuals then
    local T = Tabs.Visuals
    Sec(T,"Lighting")
    Tog(T, {Name="FullBright", CurrentValue=false, Flag="FB", Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    Tog(T, {Name="No Fog", CurrentValue=false, Flag="NF", Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    Tog(T, {Name="No Shadows", CurrentValue=false, Flag="NS", Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end})
    Sld(T, {Name="Time", Range={0,24}, Increment=1, CurrentValue=14, Flag="TOD", Callback=function(v) Vis.SetClock(v) end})
    Sec(T,"Camera")
    Sld(T, {Name="FOV", Range={30,120}, Increment=5, CurrentValue=70, Flag="FOV2", Callback=function(v) State.FOV=v; Vis.SetFOV(v) end})
    Tog(T, {Name="Freecam", CurrentValue=false, Flag="FC", Callback=function(v) Vis.Freecam(v) end})
    Sec(T,"FX")
    Tog(T, {Name="Remove Blur/Bloom", CurrentValue=false, Flag="RBB", Callback=function(v) Vis.RemoveBlur(v) end})
    Tog(T, {Name="No Particles", CurrentValue=false, Flag="NP", Callback=function(v) Vis.NoParticles(v) end})
    Tog(T, {Name="Low Graphics", CurrentValue=false, Flag="LG", Callback=function(v) Vis.LowGfx(v) end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MISC TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Misc then
    local T = Tabs.Misc
    Sec(T,"Audio")
    Tog(T, {Name="Mute All", CurrentValue=false, Flag="MA", Callback=function(v) Vis.MuteAll(v) end})
    Sec(T,"Server")
    Btn(T, {Name="Server Hop", Callback=Vis.ServerHop})
    Btn(T, {Name="Rejoin", Callback=function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end) end})
    Btn(T, {Name="Copy JobId", Callback=function() if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","",2) end end})
    Sec(T,"Character")
    Btn(T, {Name="Reset Character", Callback=function() local h=GetHuman(); if h then h.Health=0 end end})
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SETTINGS TAB
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Settings then
    local T = Tabs.Settings
    Sec(T,"Anti-AFK")
    Tog(T, {Name="Anti-AFK", CurrentValue=true, Flag="AA", Callback=function(v) State.AntiAFK=v end})
    Sec(T,"Keybinds")
    Kbnd(T, {Name="Toggle UI", CurrentKeybind="RightShift", HoldToInteract=false, Flag="KUI", Callback=function() pcall(function() Window:Toggle() end) end})
    Kbnd(T, {Name="Panic ESP", CurrentKeybind="End", HoldToInteract=false, Flag="KP", Callback=function() State.ESP_Players=false; State.ESP_Cars=false; ESP.ClearAll() end})
    Sec(T,"Credits")
    Lbl(T, HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "By " .. HUB.Author)
    Sec(T,"Unload")
    Btn(T, {Name="Unload Hub", Callback=function()
        State.Barista_AutoLoop = false
        Overlay.Hide()
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
        if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
        if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
        if State.RainbowConn then pcall(function() State.RainbowConn:Disconnect() end) end
        if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end) end
        CM:Cleanup(); Vis.RestoreLight(); Vis.MuteAll(false)
        pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        ESP.ClearAll()
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end})
end

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGodMode, true) end
    if State.NoClip then pcall(Car.SetNoClip, true) end
    if State.FlyActive then pcall(Car.SetFly, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
end, "CharAdded")

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        State.Barista_AutoLoop = false
        Overlay.Hide()
        CM:Cleanup()
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v" .. HUB.Version .. " - Barista Overlay Ready", 5)
Log("Init complete v" .. HUB.Version)
