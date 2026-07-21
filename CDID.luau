--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.4.0 - Car Driving Indonesia
--═══════════════════════════════════════════════════════════════════════════════

local Players         = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService      = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService     = game:GetService("HttpService")
local Workspace       = game:GetService("Workspace")
local CoreGui         = game:GetService("CoreGui")
local VirtualUser     = game:GetService("VirtualUser")
local Lighting        = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local TweenService    = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_CDI_v240"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _logStart = os.clock()
local function Log(msg) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock() - _logStart, tostring(msg))) end
local function Err(msg, detail) warn(string.format("[X0DEC04T][+%.2fs] ERROR: %s | %s", os.clock() - _logStart, tostring(msg), tostring(detail or ""))) end

Log("CDI Hub v2.4.0 starting (Fluent UI)")

--------------------------------------------------------------------------------
-- FLUENT LOAD
--------------------------------------------------------------------------------
local Fluent, SaveManager, InterfaceManager

local ok1, r1 = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)
if not ok1 or not r1 then Err("Fluent failed", r1); return end
Fluent = r1

local ok2, r2 = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
end)
SaveManager = ok2 and r2 or nil

local ok3, r3 = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)
InterfaceManager = ok3 and r3 or nil

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Car Driving Indonesia",
    Version = "2.4.0",
    Author  = "#ONTOP",
    LogoId  = "rbxassetid://85855925276969",
    Discord = "discord.gg/x0dec04t",
}

--------------------------------------------------------------------------------
-- CONNECTION MANAGER
--------------------------------------------------------------------------------
local CM = { _list = {} }
function CM:Add(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then table.insert(self._list, conn); return conn end
    return nil
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

local function Notify(title, content, dur)
    pcall(function()
        Fluent:Notify({ Title = tostring(title or ""), Content = tostring(content or ""), Duration = tonumber(dur) or 4 })
    end)
end

--------------------------------------------------------------------------------
-- REMOTE SCANNER
--------------------------------------------------------------------------------
local RemoteDB, RemoteDBAll = {}, {}
local function ScanRemotes()
    RemoteDB, RemoteDBAll = {}, {}
    local function scan(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                RemoteDB[obj.Name:lower():gsub("%s+", "")] = obj
                table.insert(RemoteDBAll, obj)
            end
        end
    end
    scan(ReplicatedStorage)
    scan(Workspace)
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
    for _, r in ipairs(RemoteDBAll) do Log("  [" .. r.ClassName .. "] " .. r:GetFullName()) end
end

local CDI = {
    Cars = Workspace:FindFirstChild("Cars") or Workspace:FindFirstChild("Vehicles"),
    SpawnPoints = Workspace:FindFirstChild("SpawnPoints") or Workspace:FindFirstChild("Spawn"),
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
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
    Barista_PerDelivery  = 600000,
    Barista_MoneyBefore  = 0,

    -- Overlay HUD
    Overlay_Gui        = nil,
    Overlay_StatusLbl  = nil,
    Overlay_TimeLbl    = nil,
    Overlay_EarnLbl    = nil,
    Overlay_JobsLbl    = nil,
    Overlay_UpdateConn = nil,

    -- Floating Logo
    FloatingLogo     = true,
    LogoGui          = nil,
    LogoImage        = nil,
    LogoSize         = 60,
    LogoTransparency = 0.1,

    FullBright=false, NoFog=false, NoShadows=false, FOV=70, ClockTime=14,
    RemoveBlur=false, LowGraphics=false, NoParticles=false,
    AntiAFK=true, AutoRejoin=false, NoSound=false, MutedSounds={},
    ESPCache={}, LightBackup={}, CurrentCarModel=nil,
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------
local function GetCharacter() return LocalPlayer.Character end
local function GetHRP() local ch = GetCharacter(); return ch and ch:FindFirstChild("HumanoidRootPart") end
local function GetHuman() local ch = GetCharacter(); return ch and ch:FindFirstChildOfClass("Humanoid") end
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

local function FormatTime(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
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

--------------------------------------------------------------------------------
-- MONEY READER
--------------------------------------------------------------------------------
local _moneyKeys = {"Money","Cash","Balance","RP","Rupiah","Uang","Gold","Coins","Duit"}
local _moneyValueObj = nil

local function FindMoneyObject()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local n = v.Name:lower()
            if n:find("money") or n:find("rp") or n:find("cash") or n:find("balance")
            or n:find("rupiah") or n:find("uang") or n:find("coin") or n:find("gold") then
                return v
            end
        end
    end
    for _, key in ipairs(_moneyKeys) do
        local v = LocalPlayer:FindFirstChild(key)
        if v and v:IsA("ValueBase") then return v end
    end
    for _, key in ipairs(_moneyKeys) do
        local v = LocalPlayer:FindFirstChild(key, true)
        if v and v:IsA("NumberValue") then return v end
    end
    return nil
end

local function GetPlayerMoney()
    if _moneyValueObj and _moneyValueObj.Parent then
        return tonumber(_moneyValueObj.Value) or 0
    end
    for _, key in ipairs(_moneyKeys) do
        local v = LocalPlayer:GetAttribute(key)
        if v then return tonumber(v) or 0 end
    end
    local obj = FindMoneyObject()
    if obj then _moneyValueObj = obj; return tonumber(obj.Value) or 0 end
    return 0
end

local _moneyChangedConn = nil
local function HookMoneyChanged()
    if _moneyChangedConn then pcall(function() _moneyChangedConn:Disconnect() end) end
    local obj = FindMoneyObject()
    if not obj then return end
    _moneyValueObj = obj
    _moneyChangedConn = obj.Changed:Connect(function(newVal)
        if State.Barista_AutoLoop then
            local delta = (tonumber(newVal) or 0) - State.Barista_MoneyBefore
            if delta > 0 then
                State.Barista_Earnings = State.Barista_Earnings + delta
                Log("[Barista] Money +$" .. delta)
            end
            State.Barista_MoneyBefore = tonumber(newVal) or 0
        end
    end)
    Log("[Barista] Money hook attached to: " .. obj:GetFullName())
end

--------------------------------------------------------------------------------
-- FLOATING LOGO
--------------------------------------------------------------------------------
local FloatingLogo = {}
local function DestroyLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local gp = GuiParent()
    if gp then
        for _, c in ipairs(gp:GetChildren()) do
            if c.Name == "X0_CDI_Logo" then pcall(function() c:Destroy() end) end
        end
    end
    State.LogoGui = nil; State.LogoImage = nil
end

function FloatingLogo.Build()
    DestroyLogo()
    local gp = GuiParent(); if not gp then return false end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_CDI_Logo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 999999; sg.Enabled = true
    local ok = pcall(function() sg.Parent = gp end)
    if not ok then pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end

    local size = State.LogoSize
    local img = Instance.new("ImageButton")
    img.Name = "Logo"
    img.Size = UDim2.new(0, size, 0, size)
    img.Position = UDim2.new(0, 20, 0, 100)
    img.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    img.BackgroundTransparency = 0.4
    img.BorderSizePixel = 0
    img.Image = HUB.LogoId
    img.ImageTransparency = State.LogoTransparency
    img.ScaleType = Enum.ScaleType.Fit
    img.AutoButtonColor = false
    img.Active = true; img.Selectable = true; img.Visible = true
    img.ZIndex = 100; img.Parent = sg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 10)

    local dragging, dragStart, startPos, dragMoved = false, Vector2.zero, UDim2.new(), false
    img.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = img.Position; dragMoved = false
        end
    end)
    img.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            if d.Magnitude > 4 then dragMoved = true end
            img.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    img.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    img.MouseButton1Click:Connect(function()
        if dragMoved then return end
        pcall(function()
            local h = _G[INSTANCE_KEY]
            if h and h.window and h.window.Minimize then h.window:Minimize() end
        end)
    end)

    State.LogoGui = sg; State.LogoImage = img
    return true
end
function FloatingLogo.SetVisible(v) State.FloatingLogo = v; if v then FloatingLogo.Build() else DestroyLogo() end end
function FloatingLogo.SetSize(sz) State.LogoSize = sz; if State.LogoImage then State.LogoImage.Size = UDim2.new(0, sz, 0, sz) end end
function FloatingLogo.SetTransparency(a) State.LogoTransparency = a; if State.LogoImage then State.LogoImage.ImageTransparency = a end end
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({HUB.LogoId}) end) end)

--------------------------------------------------------------------------------
-- ESP SYSTEM
--------------------------------------------------------------------------------
local ESP = {}
function ESP.Clear(obj)
    local c = State.ESPCache[obj]
    if not c then return end
    for _, inst in pairs(c) do
        if typeof(inst) == "Instance" and inst.Parent then pcall(function() inst:Destroy() end) end
    end
    State.ESPCache[obj] = nil
end
function ESP.ClearAll() for obj in pairs(State.ESPCache) do ESP.Clear(obj) end; State.ESPCache = {} end
local function MakeBB(adornee, label, color, showName, showDist, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Adornee = adornee; bb.Size = UDim2.new(0, 220, 0, 55)
    bb.StudsOffset = Vector3.new(0, 4, 0); bb.AlwaysOnTop = true
    bb.LightInfluence = 0; bb.MaxDistance = maxDist or 500; bb.Parent = GuiParent()
    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1,0,0.6,0); nl.BackgroundTransparency = 1
    nl.Text = tostring(label or ""); nl.TextColor3 = color
    nl.TextStrokeTransparency = 0; nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14; nl.Visible = showName
    local dl = Instance.new("TextLabel", bb)
    dl.Size = UDim2.new(1,0,0.4,0); dl.Position = UDim2.new(0,0,0.6,0)
    dl.BackgroundTransparency = 1; dl.Text = "0m"
    dl.TextColor3 = Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency = 0; dl.Font = Enum.Font.Gotham
    dl.TextSize = 12; dl.Visible = showDist
    return bb, nl, dl
end
function ESP.AddTarget(adornee, model, label, color)
    if State.ESPCache[adornee] then ESP.Clear(adornee) end
    local hl = Instance.new("Highlight")
    hl.Adornee = model or adornee; hl.FillColor = color
    hl.OutlineColor = Color3.new(1,1,1); hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = GuiParent()
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
function ESP.Validate() for obj in pairs(State.ESPCache) do if not obj or not obj.Parent then ESP.Clear(obj) end end end
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
CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDistances) end)

--------------------------------------------------------------------------------
-- CAR FEATURES
--------------------------------------------------------------------------------
local Car = {}
function Car.ApplySpeed()
    local seat = GetVehicleSeat()
    if seat then seat.MaxSpeed = 100 + (tonumber(State.CarSpeed) or 0); Notify("Speed", "MaxSpeed = " .. seat.MaxSpeed, 2)
    else Notify("Speed", "Get in a car first", 3) end
end
function Car.ResetSpeed() local seat = GetVehicleSeat(); if seat then seat.MaxSpeed = 100 end end
function Car.SetSpeedHack(e)
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn = nil end
    if e then
        State.SpeedHackConn = RunService.Heartbeat:Connect(function()
            local seat = GetVehicleSeat()
            if seat then seat.MaxSpeed = tonumber(State.SpeedHackValue) or 500 end
        end)
    end
end
function Car.Flip()
    local car = GetPlayerCar(); if not car then Notify("Flip","Get in a car",3); return end
    local root = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if root then root.CFrame = CFrame.new(root.Position) end
end
function Car.Launch()
    local root = GetCarRoot(); if not root then Notify("Launch","Get in a car",3); return end
    local bv = Instance.new("BodyVelocity"); bv.Velocity = Vector3.new(0,200,0)
    bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Parent = root
    game:GetService("Debris"):AddItem(bv, 0.2)
end
function Car.Boost()
    local root = GetCarRoot(); if not root then return end
    local bv = Instance.new("BodyVelocity"); bv.Velocity = root.CFrame.LookVector * 400
    bv.MaxForce = Vector3.new(math.huge, 0, math.huge); bv.Parent = root
    game:GetService("Debris"):AddItem(bv, 0.3)
end
function Car.SetRainbow(e)
    if State.RainbowConn then pcall(function() State.RainbowConn:Disconnect() end); State.RainbowConn = nil end
    if e then
        State.RainbowConn = RunService.Heartbeat:Connect(function()
            local car = GetPlayerCar(); if not car then return end
            local color = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
            for _, p in ipairs(car:GetDescendants()) do
                if p:IsA("BasePart") and not p.Name:lower():find("wheel") then p.Color = color end
            end
        end)
    end
end
function Car.TeleportToPlayer(name)
    if not name or name == "" then return end
    local target = Players:FindFirstChild(name)
    if not target or not target.Character then Notify("TP","Player not found",3); return end
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
    label = (label ~= "" and label) or ("Pos" .. (#State.SavedPositions + 1))
    table.insert(State.SavedPositions, {name=label, cframe=hrp.CFrame})
    Notify("Saved", label, 2)
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
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn = nil end
    if e then
        State.NoclipConn = RunService.Stepped:Connect(function()
            local car = GetPlayerCar()
            if car then for _, p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
            local ch = GetCharacter()
            if ch then for _, p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
        end)
    end
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn = nil end
    local h = GetHuman()
    if e then
        if h then h.PlatformStand = true end
        local hrp = GetHRP()
        if hrp then
            local bg = Instance.new("BodyGyro"); bg.MaxTorque = Vector3.new(9e9,9e9,9e9); bg.P = 9e4; bg.CFrame = hrp.CFrame; bg.Parent = hrp; bg.Name = "__FlyGyro"
            local bv = Instance.new("BodyVelocity"); bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.P = 9e4; bv.Parent = hrp; bv.Name = "__FlyVel"
            State.FlyConn = RunService.RenderStepped:Connect(function()
                local h2 = GetHRP(); if not h2 then return end
                local bg2 = h2:FindFirstChild("__FlyGyro"); local bv2 = h2:FindFirstChild("__FlyVel")
                if not bg2 or not bv2 then return end
                local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 120 or 60
                local cf = Camera.CFrame; local mv = Vector3.zero
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
                bv2.Velocity = mv * spd; bg2.CFrame = cf
            end)
        end
    else
        if h then h.PlatformStand = false end
        local hrp = GetHRP()
        if hrp then
            local bg = hrp:FindFirstChild("__FlyGyro"); local bv = hrp:FindFirstChild("__FlyVel")
            if bg then bg:Destroy() end; if bv then bv:Destroy() end
        end
    end
end
function Car.SetGodMode(e)
    local h = GetHuman(); if not h then return end
    if e then h.MaxHealth = math.huge; h.Health = math.huge
    else h.MaxHealth = 100; h.Health = 100 end
end
function Car.DeleteAllCars()
    if not CDI.Cars then return end
    for _, c in ipairs(CDI.Cars:GetChildren()) do pcall(function() c:Destroy() end) end
    Notify("Cars","All deleted",2)
end

--------------------------------------------------------------------------------
-- BARISTA OVERLAY (small corner HUD)
--------------------------------------------------------------------------------
local Overlay = {}
function Overlay.Build()
    if State.Overlay_Gui then pcall(function() State.Overlay_Gui:Destroy() end); State.Overlay_Gui = nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "__BaristaHUD"; gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false; gui.DisplayOrder = 999; gui.Parent = GuiParent()

    local card = Instance.new("Frame", gui)
    card.Size = UDim2.new(0, 260, 0, 170)
    card.Position = UDim2.new(1, -270, 0, 10)
    card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
    card.BackgroundTransparency = 0.08; card.BorderSizePixel = 0
    card.ZIndex = 10
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromRGB(55,55,70); stroke.Thickness = 1

    local titleBar = Instance.new("Frame", card)
    titleBar.Size = UDim2.new(1,0,0,36); titleBar.BackgroundColor3 = Color3.fromRGB(24,24,30)
    titleBar.BorderSizePixel = 0; titleBar.ZIndex = 11
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

    local dot = Instance.new("Frame", titleBar)
    dot.Size = UDim2.new(0,8,0,8); dot.Position = UDim2.new(0,10,0.5,-4)
    dot.BackgroundColor3 = Color3.fromRGB(60,220,100); dot.BorderSizePixel = 0
    dot.ZIndex = 12
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local titleLbl = Instance.new("TextLabel", titleBar)
    titleLbl.Size = UDim2.new(1,-30,1,0); titleLbl.Position = UDim2.new(0,24,0,0)
    titleLbl.BackgroundTransparency = 1; titleLbl.Text = "Barista Auto"
    titleLbl.TextColor3 = Color3.fromRGB(230,230,235); titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13; titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.ZIndex = 12

    local function MakeRow(parent, yPos, keyText, valueColor)
        local keyLbl = Instance.new("TextLabel", parent)
        keyLbl.Size = UDim2.new(0,80,0,22); keyLbl.Position = UDim2.new(0,10,0,yPos)
        keyLbl.BackgroundTransparency = 1; keyLbl.Text = keyText
        keyLbl.TextColor3 = Color3.fromRGB(110,110,125); keyLbl.Font = Enum.Font.Gotham
        keyLbl.TextSize = 11; keyLbl.TextXAlignment = Enum.TextXAlignment.Left; keyLbl.ZIndex = 11

        local valLbl = Instance.new("TextLabel", parent)
        valLbl.Size = UDim2.new(1,-100,0,22); valLbl.Position = UDim2.new(0,95,0,yPos)
        valLbl.BackgroundTransparency = 1; valLbl.Text = "--"
        valLbl.TextColor3 = valueColor or Color3.fromRGB(230,230,235); valLbl.Font = Enum.Font.GothamBold
        valLbl.TextSize = 12; valLbl.TextXAlignment = Enum.TextXAlignment.Left; valLbl.ZIndex = 11
        return valLbl
    end

    local statusLbl = MakeRow(card, 44, "Status", Color3.fromRGB(255,230,100))
    local timeLbl   = MakeRow(card, 72, "Runtime", Color3.fromRGB(90,200,250))
    local earnLbl   = MakeRow(card, 100, "Earned", Color3.fromRGB(100,240,140))
    local jobsLbl   = MakeRow(card, 128, "Delivered", Color3.fromRGB(200,200,215))

    local hint = Instance.new("TextLabel", card)
    hint.Size = UDim2.new(1,-10,0,16); hint.Position = UDim2.new(0,5,1,-18)
    hint.BackgroundTransparency = 1; hint.Text = "Toggle OFF in hub to stop"
    hint.TextColor3 = Color3.fromRGB(70,70,85); hint.Font = Enum.Font.Gotham
    hint.TextSize = 10; hint.ZIndex = 11

    State.Overlay_Gui = gui; State.Overlay_StatusLbl = statusLbl
    State.Overlay_TimeLbl = timeLbl; State.Overlay_EarnLbl = earnLbl
    State.Overlay_JobsLbl = jobsLbl
end

function Overlay.Show()
    Overlay.Build()
    if State.Overlay_Gui then State.Overlay_Gui.Enabled = true end
    if State.Overlay_UpdateConn then pcall(function() State.Overlay_UpdateConn:Disconnect() end); State.Overlay_UpdateConn = nil end
    State.Overlay_UpdateConn = RunService.Heartbeat:Connect(function()
        if not (State.Overlay_TimeLbl and State.Overlay_TimeLbl.Parent) then return end
        local elapsed = tick() - State.Barista_StartTime
        pcall(function()
            State.Overlay_TimeLbl.Text = FormatTime(elapsed)
            State.Overlay_EarnLbl.Text = FormatMoney(State.Barista_Earnings)
            State.Overlay_JobsLbl.Text = tostring(State.Barista_JobsDone)
            State.Overlay_StatusLbl.Text = State.Barista_Status
        end)
    end)
end

function Overlay.Hide()
    if State.Overlay_UpdateConn then pcall(function() State.Overlay_UpdateConn:Disconnect() end); State.Overlay_UpdateConn = nil end
    if State.Overlay_Gui then
        pcall(function() State.Overlay_Gui:Destroy() end)
        State.Overlay_Gui = nil; State.Overlay_StatusLbl = nil
        State.Overlay_TimeLbl = nil; State.Overlay_EarnLbl = nil; State.Overlay_JobsLbl = nil
    end
end

--------------------------------------------------------------------------------
-- BARISTA AUTOMATION
--------------------------------------------------------------------------------
local Barista = {}
local BARISTA_POS = {
    JobSelection = Vector3.new(-2707.53, 5.71,  945.41),
    CoffeeMaker  = Vector3.new(383.72, 7.15, 1334.33),
    Standby      = Vector3.new(387.46, 6.60, 1334.43),
}
function Barista.SetStatus(txt) State.Barista_Status = txt; Log("[Barista] " .. txt) end
function Barista.TeleportTo(pos, yOffset)
    local hrp = GetHRP(); if not hrp then return false end
    yOffset = yOffset or 3
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOffset, 0))
    return true
end
function Barista.FirePrompt(prompt)
    if not prompt or not prompt.Enabled then return false end
    local ok = pcall(function() if fireproximityprompt then fireproximityprompt(prompt) end end)
    return ok
end
function Barista.FindPromptByText(parent, action, object)
    if not parent then return nil end
    for _, v in ipairs(parent:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local a = tostring(v.ActionText):lower()
            local o = tostring(v.ObjectText):lower()
            if (not action or a:find(action:lower(), 1, true))
            and (not object or o:find(object:lower(), 1, true)) then return v end
        end
    end
    return nil
end
function Barista.GetJobSelectionPrompt()
    local ok, jb = pcall(function() return Workspace.Etc.Job end)
    if not ok or not jb then return nil end
    local sel = jb:FindFirstChild("Selection")
    if sel then return sel:FindFirstChildWhichIsA("ProximityPrompt", true) end
    return nil
end
function Barista.GetCoffeePrompt()
    local ok, jb = pcall(function() return Workspace.Etc.Job end)
    if not ok or not jb then return nil end
    local jj = jb:FindFirstChild("JanjiJiwa")
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
    local hrp = GetHRP()
    local bestPrompt, bestNPC, bestDist = nil, nil, math.huge
    local function searchIn(root)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled then
                local a = tostring(obj.ActionText):lower()
                local o = tostring(obj.ObjectText):lower()
                local isDelivery = a:find("deliver") or a:find("give") or a:find("serve")
                    or o:find("coffee") or o:find("order") or o:find("kopi")
                if isDelivery then
                    local part = obj.Parent
                    while part and not part:FindFirstChildOfClass("Humanoid") and part.Parent ~= Workspace do
                        part = part.Parent
                    end
                    if part then
                        local npcRoot = part:FindFirstChild("HumanoidRootPart") or part:FindFirstChildWhichIsA("BasePart")
                        local dist = math.huge
                        if hrp and npcRoot then dist = (hrp.Position - npcRoot.Position).Magnitude end
                        if dist < bestDist then bestDist = dist; bestPrompt = obj; bestNPC = part end
                    end
                end
            end
        end
    end
    local npcFolder = Workspace:FindFirstChild("NPC") or Workspace:FindFirstChild("NPCs") or Workspace:FindFirstChild("Characters")
    if npcFolder then searchIn(npcFolder) end
    if not bestPrompt then searchIn(Workspace) end
    return bestPrompt, bestNPC
end
function Barista.SelectJob()
    Barista.SetStatus("Opening job selection")
    Barista.TeleportTo(BARISTA_POS.JobSelection, 3)
    task.wait(0.8)
    local prompt = Barista.GetJobSelectionPrompt()
    if prompt then Barista.FirePrompt(prompt); Barista.SetStatus("Job selector opened - pick Janji Jawa Barista")
    else Barista.SetStatus("Job selector N/A") end
    task.wait(1.5); return true
end
function Barista.GoToCoffeeMaker()
    Barista.SetStatus("Moving to coffee maker")
    Barista.TeleportTo(BARISTA_POS.CoffeeMaker, 3)
    task.wait(0.5); return true
end
function Barista.MakeCoffee()
    Barista.SetStatus("Making coffee")
    local prompt = Barista.GetCoffeePrompt()
    if not prompt then Barista.SetStatus("No coffee prompt found"); return false end
    Barista.FirePrompt(prompt)
    local delay = tonumber(State.Barista_CoffeeDelay) or 15
    local elapsed = 0
    while elapsed < delay and State.Barista_AutoLoop do
        task.wait(1); elapsed = elapsed + 1
        Barista.SetStatus("Brewing... " .. (delay - elapsed) .. "s left")
    end
    return true
end
function Barista.Deliver()
    Barista.SetStatus("Finding customer...")
    local start = tick()
    local prompt, npc = nil, nil
    while tick() - start < 10 do
        if not State.Barista_AutoLoop then return false end
        prompt, npc = Barista.GetDeliveryPrompt()
        if prompt then break end
        task.wait(0.35)
    end
    if not prompt or not npc then
        Barista.SetStatus("No customer found - retrying next cycle")
        return false
    end
    local npcRoot = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
    if npcRoot then
        local hrp = GetHRP()
        if hrp then hrp.CFrame = CFrame.new(npcRoot.Position + Vector3.new(0,0,3)); task.wait(0.5) end
    end
    local waitStart = tick()
    while not prompt.Enabled and tick() - waitStart < 3 do task.wait(0.15) end
    if not prompt.Enabled then Barista.SetStatus("Prompt disabled, skipping"); return false end
    local moneyBefore = GetPlayerMoney()
    Barista.FirePrompt(prompt)
    task.wait(1.2)
    local moneyAfter = GetPlayerMoney()
    local snapshotDelta = moneyAfter - moneyBefore
    State.Barista_JobsDone = State.Barista_JobsDone + 1
    if snapshotDelta > 0 then
        Log("[Barista] Snapshot delta: +" .. snapshotDelta)
    else
        local perDel = tonumber(State.Barista_PerDelivery) or 5000
        State.Barista_Earnings = State.Barista_Earnings + perDel
        Log("[Barista] No real delta - added estimate +" .. perDel)
    end
    Barista.SetStatus("Delivered #" .. State.Barista_JobsDone)
    return true
end
function Barista.SetAutoLoop(enable)
    State.Barista_AutoLoop = enable
    if not enable then
        Barista.SetStatus("Loop stopped"); Overlay.Hide()
        if _moneyChangedConn then pcall(function() _moneyChangedConn:Disconnect() end); _moneyChangedConn = nil end
        return
    end
    State.Barista_StartTime = tick()
    State.Barista_Earnings = 0
    State.Barista_JobsDone = 0
    State.Barista_MoneyBefore = GetPlayerMoney()
    HookMoneyChanged()
    Barista.SetStatus("Loop starting...")
    Overlay.Show()
    task.spawn(function()
        Barista.SelectJob()
        task.wait(4)
        while State.Barista_AutoLoop do
            Barista.GoToCoffeeMaker(); task.wait(0.5)
            if not State.Barista_AutoLoop then break end
            local brewOk = Barista.MakeCoffee()
            if not brewOk then task.wait(2) end
            if not State.Barista_AutoLoop then break end
            Barista.Deliver()
            if not State.Barista_AutoLoop then break end
            task.wait(math.max(1, tonumber(State.Barista_Delay) or 2))
        end
        Barista.SetStatus("Loop ended")
        Overlay.Hide()
    end)
end

--------------------------------------------------------------------------------
-- FOLDER ENGINE
--------------------------------------------------------------------------------
local FolderEngine = {}
local function FindFolder(name)
    local key = name:lower():gsub("%s+", "_")
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and obj.Name:lower():gsub("%s+", "_") == key then return obj end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Folder") or obj:IsA("Model")) and obj.Name:lower():find(name:lower(), 1, true) then return obj end
    end
    return nil
end
function FolderEngine.Delete(name) local f = FindFolder(name); if f then pcall(function() f:Destroy() end); Notify("Folder","Deleted "..f.Name,3) end end
function FolderEngine.Hide(name) local f = FindFolder(name); if not f then return end; for _,v in ipairs(f:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=1 end end end
function FolderEngine.Show(name) local f = FindFolder(name); if not f then return end; for _,v in ipairs(f:GetDescendants()) do if v:IsA("BasePart") then v.Transparency=0 end end end

--------------------------------------------------------------------------------
-- REMOTE EXPLOIT
--------------------------------------------------------------------------------
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
    pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(arg) else rem:InvokeServer(arg) end end)
    Notify("Remote","Fired "..rem.Name,3)
end
function RemoteExploit.SetSpam(e, name, argStr, iv)
    if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end); State.RemoteSpamConn = nil end
    if e then
        local rem = FindRemote(name); if not rem then return end
        local arg = ParseArg(argStr); local last = 0
        State.RemoteSpamConn = RunService.Heartbeat:Connect(function()
            if tick() - last >= (iv or 0.5) then last = tick()
                pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer(arg) else rem:InvokeServer(arg) end end)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- VISUALS
--------------------------------------------------------------------------------
local Vis = {}
function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
    }
end
function Vis.RestoreLight() for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e)
    Vis.BackupLight()
    if e then Lighting.Ambient=Color3.fromRGB(255,255,255); Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
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
            if s:IsA("Sound") then table.insert(State.MutedSounds,{s=s,v=s.Volume}); s.Volume=0 end
        end
    else
        for _,en in ipairs(State.MutedSounds) do if en.s and en.s.Parent then en.s.Volume=en.v end end
        State.MutedSounds = {}
    end
end
function Vis.Freecam(e)
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end); State.FreecamConn = nil end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look = Camera.CFrame.LookVector; local right = Camera.CFrame.RightVector
            local mv = Vector3.zero; local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 6 or 2
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
            pos = pos + mv * spd
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else Camera.CameraType = Enum.CameraType.Custom end
end
function Vis.ServerHop()
    pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100")
        local data = HttpService:JSONDecode(raw)
        for _, s in ipairs(data.data or {}) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); return
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- ANTI-AFK
--------------------------------------------------------------------------------
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end
end)
task.spawn(function() while task.wait(5) do
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.NoFog then pcall(Vis.NoFog, true) end
end end)
task.spawn(function() while task.wait(1) do
    if State.GodMode then local h = GetHuman(); if h then h.MaxHealth = math.huge; h.Health = math.huge end end
end end)

--------------------------------------------------------------------------------
-- FLUENT WINDOW
--------------------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title    = HUB.Name .. " v" .. HUB.Version,
    SubTitle = HUB.Game .. " | " .. HUB.Author,
    TabWidth = 160,
    Size     = UDim2.fromOffset(640, 470),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift,
})

_G[INSTANCE_KEY] = { version = HUB.Version, window = Window, destroy = function() end }

local Tabs = {
    Main     = Window:AddTab({Title="Main",     Icon="home"}),
    Car      = Window:AddTab({Title="Car",      Icon="car"}),
    Barista  = Window:AddTab({Title="Barista",  Icon="coffee"}),
    Teleport = Window:AddTab({Title="Teleport", Icon="map-pin"}),
    ESP      = Window:AddTab({Title="ESP",      Icon="eye"}),
    Remote   = Window:AddTab({Title="Remotes",  Icon="radio"}),
    Folder   = Window:AddTab({Title="Folders",  Icon="folder"}),
    Visuals  = Window:AddTab({Title="Visuals",  Icon="sun"}),
    Misc     = Window:AddTab({Title="Misc",     Icon="wrench"}),
    Settings = Window:AddTab({Title="Settings", Icon="settings"}),
}

--------------------------------------------------------------------------------
-- MAIN TAB
--------------------------------------------------------------------------------
Tabs.Main:AddParagraph({Title="Welcome", Content="X0DEC04T Hub v"..HUB.Version.."\nGame: "..HUB.Game.."\nAuthor: "..HUB.Author})
Tabs.Main:AddParagraph({Title="Info", Content="Remotes: "..#RemoteDBAll.."\nCars: "..(CDI.Cars and "OK" or "MISSING").."\nMoney: "..FormatMoney(GetPlayerMoney())})
Tabs.Main:AddParagraph({Title="Quick Guide", Content="Barista tab: Auto Janji Jawa loop\nCar tab: speed / fly / noclip\nRightShift: minimize UI"})
Tabs.Main:AddButton({Title="Dump Remotes (console)", Callback=DumpRemotes})
Tabs.Main:AddButton({Title="Rescan Remotes", Callback=function() ScanRemotes(); Notify("Remotes","Rescanned: "..#RemoteDBAll,3) end})

--------------------------------------------------------------------------------
-- CAR TAB
--------------------------------------------------------------------------------
Tabs.Car:AddSlider("ExtraSpeed",{Title="Extra Speed",Default=0,Min=0,Max=500,Rounding=0}):OnChanged(function(v) State.CarSpeed=v; Car.ApplySpeed() end)
Tabs.Car:AddButton({Title="Apply Speed", Callback=Car.ApplySpeed})
Tabs.Car:AddButton({Title="Reset Speed", Callback=function() State.CarSpeed=0; Car.ResetSpeed() end})
Tabs.Car:AddSlider("SpeedHackVal",{Title="SpeedHack Value",Default=500,Min=100,Max=2000,Rounding=0}):OnChanged(function(v) State.SpeedHackValue=v; if State.SpeedHack then Car.SetSpeedHack(true) end end)
Tabs.Car:AddToggle("SpeedHack",{Title="Speed Hack (constant)",Default=false}):OnChanged(function(v) State.SpeedHack=v; Car.SetSpeedHack(v) end)
Tabs.Car:AddButton({Title="Flip Car", Callback=Car.Flip})
Tabs.Car:AddButton({Title="Launch Up", Callback=Car.Launch})
Tabs.Car:AddButton({Title="Boost Forward", Callback=Car.Boost})
Tabs.Car:AddButton({Title="Delete All Cars", Callback=Car.DeleteAllCars})
Tabs.Car:AddToggle("NoClip",{Title="NoClip",Default=false}):OnChanged(function(v) State.NoClip=v; Car.SetNoClip(v) end)
Tabs.Car:AddToggle("Fly",{Title="Fly (on foot)",Default=false}):OnChanged(function(v) State.FlyActive=v; Car.SetFly(v) end)
Tabs.Car:AddToggle("GodMode",{Title="God Mode",Default=false}):OnChanged(function(v) State.GodMode=v; Car.SetGodMode(v) end)
Tabs.Car:AddToggle("RainbowCar",{Title="Rainbow Car",Default=false}):OnChanged(function(v) State.RainbowCar=v; Car.SetRainbow(v) end)

--------------------------------------------------------------------------------
-- BARISTA TAB
--------------------------------------------------------------------------------
Tabs.Barista:AddParagraph({Title="Janji Jawa Barista", Content="Auto Coffee Making + Delivery loop.\nJob prompt: "..(Barista.GetJobSelectionPrompt() and "Found" or "N/A").."\nCoffee prompt: "..(Barista.GetCoffeePrompt() and "Found" or "N/A - enter shop first")})
Tabs.Barista:AddParagraph({Title="How to use", Content="1. Toggle 'Auto Barista Loop' ON\n2. Job selector opens - click Janji Jawa Barista\n3. Small HUD appears top-right\n4. Toggle OFF to stop"})
Tabs.Barista:AddSlider("BrewDelay",{Title="Coffee Brew Delay (sec)",Default=15,Min=5,Max=30,Rounding=0}):OnChanged(function(v) State.Barista_CoffeeDelay = tonumber(v) or 15 end)
Tabs.Barista:AddSlider("CycleDelay",{Title="Cycle Delay (sec)",Default=2,Min=1,Max=10,Rounding=0}):OnChanged(function(v) State.Barista_Delay = tonumber(v) or 2 end)
Tabs.Barista:AddSlider("PerDelivery",{Title="Fallback RP per Delivery",Default=5000,Min=1000,Max=999999,Rounding=0}):OnChanged(function(v) State.Barista_PerDelivery = tonumber(v) or 5000 end)
Tabs.Barista:AddToggle("BaristaAuto",{Title="Auto Barista Loop",Default=false}):OnChanged(function(v) Barista.SetAutoLoop(v) end)
Tabs.Barista:AddButton({Title="1. Open Job Selection", Callback=function() task.spawn(Barista.SelectJob) end})
Tabs.Barista:AddButton({Title="2. TP to Coffee Maker", Callback=function() Barista.GoToCoffeeMaker() end})
Tabs.Barista:AddButton({Title="3. Fire Coffee Prompt", Callback=function()
    local p = Barista.GetCoffeePrompt()
    if p then Barista.FirePrompt(p); Notify("Barista","Coffee prompt fired",2)
    else Notify("Barista","No coffee prompt found",3) end
end})
Tabs.Barista:AddButton({Title="4. Deliver to Customer", Callback=function() task.spawn(Barista.Deliver) end})
Tabs.Barista:AddButton({Title="Find Customer (log)", Callback=function()
    local p, npc = Barista.GetDeliveryPrompt()
    if p then Notify("Customer", (npc and npc.Name or "?") .. " found", 4)
    else Notify("Customer","No active customer found",3) end
end})
Tabs.Barista:AddButton({Title="Hook Money Tracker", Callback=function() HookMoneyChanged(); Notify("Money","Tracker attached - check console",3) end})
Tabs.Barista:AddButton({Title="Reset Session Stats", Callback=function()
    State.Barista_JobsDone = 0; State.Barista_Earnings = 0
    State.Barista_StartTime = tick(); Barista.SetStatus("Stats reset")
end})

--------------------------------------------------------------------------------
-- TELEPORT TAB
--------------------------------------------------------------------------------
Tabs.Teleport:AddInput("PlayerName",{Title="Player Name",Placeholder="Case-sensitive"}):OnChanged(function(v) State.TP_Target=v end)
Tabs.Teleport:AddButton({Title="TP to Player", Callback=function() Car.TeleportToPlayer(State.TP_Target) end})
if CDI.SpawnPoints then
    for i, sp in ipairs(CDI.SpawnPoints:GetChildren()) do
        if i > 15 then break end
        local idx = i
        Tabs.Teleport:AddButton({Title="Spawn "..idx.." - "..sp.Name, Callback=function() Car.TeleportToSpawn(idx) end})
    end
else
    Tabs.Teleport:AddParagraph({Title="Spawns", Content="No spawn points found"})
end
local savedPosName = ""
Tabs.Teleport:AddInput("SaveLabel",{Title="Position Label",Placeholder="e.g. Garage"}):OnChanged(function(v) savedPosName = v end)
Tabs.Teleport:AddButton({Title="Save Position", Callback=function() Car.SavePosition(savedPosName) end})
Tabs.Teleport:AddButton({Title="Load Position", Callback=function() Car.LoadPosition(savedPosName) end})

--------------------------------------------------------------------------------
-- ESP TAB
--------------------------------------------------------------------------------
Tabs.ESP:AddToggle("PlayerESP",{Title="Player ESP",Default=false}):OnChanged(function(v)
    State.ESP_Players=v
    if not v then for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer and p.Character then local h=p.Character:FindFirstChild("HumanoidRootPart"); if h then ESP.Clear(h) end end end end
end)
Tabs.ESP:AddToggle("CarESP",{Title="Car ESP",Default=false}):OnChanged(function(v)
    State.ESP_Cars=v
    if not v and CDI.Cars then for _,c in ipairs(CDI.Cars:GetChildren()) do local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then ESP.Clear(r) end end end
end)
Tabs.ESP:AddToggle("ESPNames",{Title="Show Names",Default=true}):OnChanged(function(v) State.ESP_ShowName=v; for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end end)
Tabs.ESP:AddToggle("ESPDist",{Title="Show Distance",Default=true}):OnChanged(function(v) State.ESP_ShowDist=v; for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end end)
Tabs.ESP:AddSlider("ESPMaxDist",{Title="Max Distance",Default=500,Min=50,Max=3000,Rounding=0}):OnChanged(function(v) State.ESP_MaxDist=v; for _,c in pairs(State.ESPCache) do if c.bb then c.bb.MaxDistance=v end end end)
Tabs.ESP:AddButton({Title="Refresh ESP", Callback=function() ESP.ClearAll(); ESP.RefreshAll() end})
Tabs.ESP:AddButton({Title="Clear All ESP", Callback=ESP.ClearAll})

--------------------------------------------------------------------------------
-- REMOTE TAB
--------------------------------------------------------------------------------
Tabs.Remote:AddParagraph({Title="Remotes", Content="Total: "..#RemoteDBAll})
Tabs.Remote:AddInput("RemName",{Title="Remote Name",Placeholder="Name"}):OnChanged(function(v) State.RemoteName=v end)
Tabs.Remote:AddInput("RemArg",{Title="Argument",Placeholder="Value"}):OnChanged(function(v) State.RemoteArg=v end)
Tabs.Remote:AddButton({Title="Fire Once", Callback=function() RemoteExploit.Fire(State.RemoteName, State.RemoteArg) end})
local spamIv = 0.5
Tabs.Remote:AddSlider("SpamInterval",{Title="Spam Interval x0.1s",Default=5,Min=1,Max=50,Rounding=0}):OnChanged(function(v) spamIv = v / 10 end)
Tabs.Remote:AddToggle("SpamRemote",{Title="Spam Remote",Default=false}):OnChanged(function(v) RemoteExploit.SetSpam(v, State.RemoteName, State.RemoteArg, spamIv) end)
Tabs.Remote:AddButton({Title="Dump All (console)", Callback=DumpRemotes})

--------------------------------------------------------------------------------
-- FOLDER TAB
--------------------------------------------------------------------------------
Tabs.Folder:AddInput("FolderName",{Title="Folder / Model Name",Placeholder="e.g. Roads"}):OnChanged(function(v) State.FolderName=v end)
Tabs.Folder:AddButton({Title="Delete", Callback=function() FolderEngine.Delete(State.FolderName) end})
Tabs.Folder:AddButton({Title="Hide", Callback=function() FolderEngine.Hide(State.FolderName) end})
Tabs.Folder:AddButton({Title="Show", Callback=function() FolderEngine.Show(State.FolderName) end})

--------------------------------------------------------------------------------
-- VISUALS TAB
--------------------------------------------------------------------------------
Tabs.Visuals:AddToggle("FullBright",{Title="FullBright",Default=false}):OnChanged(function(v) State.FullBright=v; Vis.FullBright(v) end)
Tabs.Visuals:AddToggle("NoFog",{Title="No Fog",Default=false}):OnChanged(function(v) State.NoFog=v; Vis.NoFog(v) end)
Tabs.Visuals:AddToggle("NoShadows",{Title="No Shadows",Default=false}):OnChanged(function(v) State.NoShadows=v; Vis.NoShadows(v) end)
Tabs.Visuals:AddSlider("TimeOfDay",{Title="Time of Day",Default=14,Min=0,Max=24,Rounding=0}):OnChanged(function(v) Vis.SetClock(v) end)
Tabs.Visuals:AddSlider("FOV",{Title="FOV",Default=70,Min=30,Max=120,Rounding=0}):OnChanged(function(v) State.FOV=v; Vis.SetFOV(v) end)
Tabs.Visuals:AddToggle("Freecam",{Title="Freecam",Default=false}):OnChanged(function(v) Vis.Freecam(v) end)
Tabs.Visuals:AddToggle("RemoveBlur",{Title="Remove Blur/Bloom",Default=false}):OnChanged(function(v) Vis.RemoveBlur(v) end)
Tabs.Visuals:AddToggle("NoParticles",{Title="No Particles",Default=false}):OnChanged(function(v) Vis.NoParticles(v) end)
Tabs.Visuals:AddToggle("LowGfx",{Title="Low Graphics",Default=false}):OnChanged(function(v) Vis.LowGfx(v) end)

--------------------------------------------------------------------------------
-- MISC TAB
--------------------------------------------------------------------------------
Tabs.Misc:AddToggle("MuteAll",{Title="Mute All Sounds",Default=false}):OnChanged(function(v) Vis.MuteAll(v) end)
Tabs.Misc:AddButton({Title="Server Hop", Callback=Vis.ServerHop})
Tabs.Misc:AddButton({Title="Rejoin", Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end})
Tabs.Misc:AddButton({Title="Copy JobId", Callback=function() if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","JobId",2) end end})
Tabs.Misc:AddButton({Title="Reset Character", Callback=function() local h=GetHuman(); if h then h.Health=0 end end})

--------------------------------------------------------------------------------
-- SETTINGS TAB
--------------------------------------------------------------------------------
Tabs.Settings:AddToggle("AntiAFK",{Title="Anti-AFK",Default=true}):OnChanged(function(v) State.AntiAFK=v end)

Tabs.Settings:AddParagraph({Title="Floating Logo", Content="Draggable logo. Click to toggle hub visibility."})
Tabs.Settings:AddToggle("FloatLogo",{Title="Floating Logo",Default=true}):OnChanged(function(v) FloatingLogo.SetVisible(v) end)
Tabs.Settings:AddSlider("LogoSize",{Title="Logo Size",Default=60,Min=30,Max=140,Rounding=0}):OnChanged(function(v) FloatingLogo.SetSize(v) end)
Tabs.Settings:AddSlider("LogoAlpha",{Title="Logo Transparency %",Default=10,Min=0,Max=90,Rounding=0}):OnChanged(function(v) FloatingLogo.SetTransparency(v/100) end)
Tabs.Settings:AddButton({Title="Rebuild Logo", Callback=function() State.FloatingLogo=true; FloatingLogo.Build(); Notify("Logo","Rebuilt",2) end})

Tabs.Settings:AddKeybind("ToggleUI",{Title="Toggle UI",Mode="Toggle",Default="RightShift"}):OnClick(function() Window:Minimize() end)
Tabs.Settings:AddKeybind("PanicESP",{Title="Panic (clear ESP)",Mode="Toggle",Default="End"}):OnClick(function() State.ESP_Players=false; State.ESP_Cars=false; ESP.ClearAll() end)

Tabs.Settings:AddParagraph({Title="Credits", Content=HUB.Name.." v"..HUB.Version.."\nBy "..HUB.Author})

Tabs.Settings:AddButton({Title="Unload Hub", Callback=function()
    State.Barista_AutoLoop = false
    Overlay.Hide()
    if _moneyChangedConn then pcall(function() _moneyChangedConn:Disconnect() end) end
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
    if State.RainbowConn then pcall(function() State.RainbowConn:Disconnect() end) end
    if State.RemoteSpamConn then pcall(function() State.RemoteSpamConn:Disconnect() end) end
    CM:Cleanup(); Vis.RestoreLight(); Vis.MuteAll(false)
    pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
    ESP.ClearAll(); DestroyLogo()
    _G[INSTANCE_KEY] = nil
    pcall(function() Fluent:Destroy() end)
end})

-- SaveManager / InterfaceManager
if SaveManager and InterfaceManager then
    local setupOk = pcall(function()
        SaveManager:SetLibrary(Fluent)
        InterfaceManager:SetLibrary(Fluent)
        SaveManager:IgnoreThemeSettings()
        SaveManager:SetIgnoreIndexes({})
        InterfaceManager:SetFolder("X0DEC04T_CDI")
        SaveManager:SetFolder("X0DEC04T_CDI/configs")
    end)
    if setupOk then
        pcall(function() InterfaceManager:BuildInterfaceSection(Tabs.Settings) end)
        pcall(function() SaveManager:BuildConfigSection(Tabs.Settings) end)
    end
end

--------------------------------------------------------------------------------
-- CHARACTER RESPAWN
--------------------------------------------------------------------------------
CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGodMode, true) end
    if State.NoClip then pcall(Car.SetNoClip, true) end
    if State.FlyActive then pcall(Car.SetFly, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.Barista_AutoLoop then task.wait(2); HookMoneyChanged() end
    if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
end)

_G[INSTANCE_KEY].destroy = function()
    State.Barista_AutoLoop = false
    Overlay.Hide()
    if _moneyChangedConn then pcall(function() _moneyChangedConn:Disconnect() end) end
    CM:Cleanup(); ESP.ClearAll(); DestroyLogo()
    pcall(function() Fluent:Destroy() end)
end

-- Build logo on startup with retries + watchdog
task.spawn(function()
    task.wait(0.5)
    if State.FloatingLogo then
        local ok = FloatingLogo.Build()
        if not ok then for i = 1, 3 do task.wait(1); if FloatingLogo.Build() then break end end end
    end
    while task.wait(5) do
        if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
    end
end)

Window:SelectTab(1)
Notify(HUB.Name, "v" .. HUB.Version .. " loaded - Fluent UI + Logo", 5)
Log("Init complete v" .. HUB.Version)
