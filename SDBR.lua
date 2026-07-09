--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.7.6 - Border RP (Scarface)
-- FIX: Auto-equip tool before sell
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

local INSTANCE_KEY = "__X0DEC04T_BRP_v276"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(m))) end
local function Err(m,d) warn(string.format("[X0DEC04T] ERR: %s | %s", tostring(m), tostring(d or ""))) end
Log("BorderRP Hub v2.7.6 starting...")

local Rayfield
for _, url in ipairs({"https://sirius.menu/rayfield","https://raw.githubusercontent.com/shlexware/Rayfield/main/source"}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then Err("Rayfield failed"); return end

local HUB = { Name="X0DEC04T Hub", Game="Border RP", Version="2.7.6", Author="voixera" }

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
    PurchaseWorldItem       = GetRemote("WorldBuyableItemService.PurchaseWorldBuyableItem"),
    Detain                  = GetRemote("Handcuffs.Detain"),
    Jail                    = GetRemote("Handcuffs.Jail"),
    BatonSwing              = GetRemote("Baton.Swing"),
    UnstuckVehicle          = GetRemote("VehicleService.UnstuckVehicle"),
    JoinTeam                = GetRemote("TeamService.JoinTeam"),
    ApplyRollbackCFrame     = GetRemote("AntiTp.ApplyRollbackCFrame"),
}
local remoteCount = 0
for _, v in pairs(BRP) do if v then remoteCount = remoteCount + 1 end end
Log("Loaded " .. remoteCount .. " BRP remotes")

local BRP_PATHS = {
    NPC = Workspace:FindFirstChild("NPC"),
    Vehicles = Workspace:FindFirstChild("Vehicles"),
    LaunderTrigger = Workspace:FindFirstChild("LaunderPrompts") and Workspace.LaunderPrompts:FindFirstChild("LaunderTrigger"),
    WorldBuyableItems = Workspace:FindFirstChild("WorldBuyableItems"),
}

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
    SellNPC = Vector3.new(209.93, 17.23, -46.54),
    Laundry = Vector3.new(6804.78, 17.43, -34.70),
    Shop    = Vector3.new(6823.57, 17.40, -20.00),
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
    TP_Target="", SavedPositions={},
    RemoteName="", RemoteArg="",

    Smuggler_AutoLoop=false,
    Smuggler_JobsDone=0,
    Smuggler_UseRemotes=true, Smuggler_AutoLaunder=true,
    Smuggler_ItemName = "Fake Diamond Ring",
    Smuggler_SellerName = "Seller4",
    Smuggler_BuyRetries = 2,
    Smuggler_SellRetries = 5,
    Smuggler_Delay = 1,
    Smuggler_DebugMode = false,
    Smuggler_ApproachMethod = "WalkFinal",
    Smuggler_SyncWait = 1.5,
    Smuggler_AutoEquip = true,
    Smuggler_EquipAll = true,
    POS_Shop = DEFAULT_POS.Shop,
    POS_Sell = DEFAULT_POS.SellNPC,
    POS_Laundry = DEFAULT_POS.Laundry,

    -- Anti-cheat
    AntiTpBypass = true,
    TPStrategy = "Chunked",
    TPChunkSize = 150,
    TPTweenSpeed = 500,

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
            return seat:FindFirstAncestorOfClass("Model")
        end
    end
end
local function GetVehicleSeat() local c = GetPlayerCar(); return c and (c:FindFirstChildOfClass("VehicleSeat") or c:FindFirstChildWhichIsA("VehicleSeat", true)) end
local function GetCarRoot() local c = GetPlayerCar(); return c and (c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")) end
local function GetWantedLevel(p) return tonumber(p and p:GetAttribute("WantedLevel")) or 0 end
local function IsWanted(p) return GetWantedLevel(p) >= (State.Police_MinWantedLevel or 1) end
local function GetRank(p) return tostring(p and p:GetAttribute("CurrentRankName") or "Unknown") end

-- Count items in backpack+character by name
local function CountItems(toolName)
    local count = 0
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name == toolName then count = count + 1 end
        end
    end
    local ch = GetChar()
    if ch then
        for _, t in ipairs(ch:GetChildren()) do
            if t:IsA("Tool") and t.Name == toolName then count = count + 1 end
        end
    end
    return count
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTITP BYPASS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local AntiTpBypass = {
    enabled = false,
    hookInstalled = false,
    blockedOut = 0,
    lastTPTime = 0,
    protectDuration = 3,
}

function AntiTpBypass.MarkTeleport()
    AntiTpBypass.lastTPTime = tick()
end

function AntiTpBypass.Enable()
    if AntiTpBypass.hookInstalled then
        AntiTpBypass.enabled = true
        return
    end
    
    local rollbackRemote = BRP.ApplyRollbackCFrame
    
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        
        local function hooked(self, ...)
            local method = getnamecallmethod()
            if AntiTpBypass.enabled and rollbackRemote and self == rollbackRemote
            and (method == "FireServer" or method == "InvokeServer") then
                AntiTpBypass.blockedOut = AntiTpBypass.blockedOut + 1
                if State.Smuggler_DebugMode then
                    Log("[AntiTp] Blocked out #" .. AntiTpBypass.blockedOut)
                end
                return
            end
            return oldNamecall(self, ...)
        end
        
        if newcclosure then
            mt.__namecall = newcclosure(hooked)
        else
            mt.__namecall = hooked
        end
        setreadonly(mt, true)
    end)
    
    if ok then
        AntiTpBypass.hookInstalled = true
        AntiTpBypass.enabled = true
        Log("[AntiTp] Bypass hook installed")
    end
end

function AntiTpBypass.Disable()
    AntiTpBypass.enabled = false
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SMART TELEPORT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local SmartTP = {}

function SmartTP.Instant(pos, yOff)
    if not pos then return false end
    AntiTpBypass.MarkTeleport()
    local hrp = GetHRP(); if not hrp then return false end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, yOff or 3, 0))
    task.wait(0.3)
    return true
end

function SmartTP.Chunked(pos, yOff)
    if not pos then return false end
    AntiTpBypass.MarkTeleport()
    local hrp = GetHRP(); if not hrp then return false end
    local chunkSize = State.TPChunkSize or 150
    local targetPos = pos + Vector3.new(0, yOff or 3, 0)
    local startPos = hrp.Position
    local totalDist = (targetPos - startPos).Magnitude
    
    if totalDist <= chunkSize then
        hrp.CFrame = CFrame.new(targetPos)
        task.wait(0.2)
        return true
    end
    
    local steps = math.ceil(totalDist / chunkSize)
    local direction = (targetPos - startPos).Unit
    
    for i = 1, steps do
        if not hrp or not hrp.Parent then return false end
        local stepPos = startPos + direction * math.min(chunkSize * i, totalDist)
        hrp.CFrame = CFrame.new(stepPos)
        task.wait(0.15)
    end
    
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(0.3)
    return true
end

function SmartTP.Tween(pos, yOff)
    if not pos then return false end
    AntiTpBypass.MarkTeleport()
    local hrp = GetHRP(); if not hrp then return false end
    local speed = State.TPTweenSpeed or 500
    local targetPos = pos + Vector3.new(0, yOff or 3, 0)
    local dist = (targetPos - hrp.Position).Magnitude
    local duration = math.max(0.1, dist / speed)
    
    local tween = TweenService:Create(hrp,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {CFrame = CFrame.new(targetPos)})
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.3)
    return true
end

function SmartTP.Velocity(pos, yOff)
    if not pos then return false end
    AntiTpBypass.MarkTeleport()
    local hrp = GetHRP(); if not hrp then return false end
    local targetPos = pos + Vector3.new(0, yOff or 3, 0)
    local dist = (targetPos - hrp.Position).Magnitude
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = (targetPos - hrp.Position).Unit * 300
    bv.Parent = hrp
    
    local duration = math.max(0.2, dist / 300)
    task.wait(duration)
    
    bv:Destroy()
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(0.3)
    return true
end

function SmartTP.Go(pos, yOff)
    if State.AntiTpBypass then AntiTpBypass.Enable() end
    local strategy = State.TPStrategy or "Chunked"
    if strategy == "Instant"  then return SmartTP.Instant(pos, yOff)  end
    if strategy == "Chunked"  then return SmartTP.Chunked(pos, yOff)  end
    if strategy == "Tween"    then return SmartTP.Tween(pos, yOff)    end
    if strategy == "Velocity" then return SmartTP.Velocity(pos, yOff) end
    return SmartTP.Chunked(pos, yOff)
end

function SmartTP.Walk(targetPos, timeout)
    local hrp = GetHRP()
    local hum = GetHuman()
    if not hrp or not hum then return false end
    
    timeout = timeout or 5
    hum:MoveTo(targetPos)
    
    local start = tick()
    while tick() - start < timeout do
        if (hrp.Position - targetPos).Magnitude < 4 then return true end
        task.wait(0.1)
    end
    return false
end

--━ ESP
local ESP = {}
function ESP.Clear(o)
    local c = State.ESPCache[o]; if not c then return end
    for _, i in pairs(c) do if typeof(i)=="Instance" and i.Parent then pcall(function() i:Destroy() end) end end
    State.ESPCache[o] = nil
end
function ESP.ClearAll() for o in pairs(State.ESPCache) do ESP.Clear(o) end; State.ESPCache = {} end
function ESP.AddTarget(a, model, label, color)
    if State.ESPCache[a] then ESP.Clear(a) end
    local hl = Instance.new("Highlight")
    hl.Adornee=model or a; hl.FillColor=color; hl.OutlineColor=Color3.new(1,1,1)
    hl.FillTransparency=0.5; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=GuiParent()
    local bb = Instance.new("BillboardGui")
    bb.Adornee=a; bb.Size=UDim2.new(0,260,0,55); bb.StudsOffset=Vector3.new(0,4,0)
    bb.AlwaysOnTop=true; bb.LightInfluence=0; bb.MaxDistance=State.ESP_MaxDist; bb.Parent=GuiParent()
    local nl = Instance.new("TextLabel", bb)
    nl.Size=UDim2.new(1,0,0.6,0); nl.BackgroundTransparency=1; nl.Text=tostring(label)
    nl.TextColor3=color; nl.TextStrokeTransparency=0; nl.Font=Enum.Font.GothamBold; nl.TextSize=14; nl.Visible=State.ESP_ShowName
    local dl = Instance.new("TextLabel", bb)
    dl.Size=UDim2.new(1,0,0.4,0); dl.Position=UDim2.new(0,0,0.6,0); dl.BackgroundTransparency=1; dl.Text="0m"
    dl.TextColor3=Color3.fromRGB(220,220,220); dl.TextStrokeTransparency=0; dl.Font=Enum.Font.Gotham; dl.TextSize=12; dl.Visible=State.ESP_ShowDist
    State.ESPCache[a] = {hl=hl, bb=bb, nl=nl, dl=dl, hrp=a}
end
function ESP.UpdateDist()
    local hrp = GetHRP(); if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then c.dl.Text = math.floor((c.hrp.Position - hrp.Position).Magnitude) .. "m" end
    end
end
function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local wanted = IsWanted(p); local wl = GetWantedLevel(p); local rank = GetRank(p)
                local isPolice = rank:lower():find("police") or rank:lower():find("cop") or rank:lower():find("agent")
                local show = false; local color = State.Color_Player; local label = p.Name .. " [" .. rank .. "]"
                if State.ESP_Wanted and wanted then
                    show = true; color = State.Color_Wanted; label = p.Name .. " [Wanted " .. wl .. "]"
                elseif State.ESP_Police and isPolice then
                    show = true; color = State.Color_Police; label = "[Police] " .. p.Name
                elseif State.ESP_Players then
                    show = true
                    if wanted then color = State.Color_Wanted; label = p.Name .. " [W" .. wl .. "]" end
                end
                if show and not State.ESPCache[hrp] then ESP.AddTarget(hrp, p.Character, label, color)
                elseif not show then ESP.Clear(hrp) end
            end
        end
    end
end
function ESP.RefreshAll()
    for o in pairs(State.ESPCache) do if not o or not o.Parent then ESP.Clear(o) end end
    ESP.ScanPlayers()
end
task.spawn(function() while task.wait(2) do pcall(ESP.RefreshAll) end end)
CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDist) end)

--━ CAR
local Car = {}
function Car.ApplySpeed()
    local seat = GetVehicleSeat()
    if seat then seat.MaxSpeed = 100 + (tonumber(State.CarSpeed) or 0); Notify("Speed","="..seat.MaxSpeed,2)
    else Notify("Speed","Enter a vehicle.",3) end
end
function Car.SetSpeedHack(e)
    if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end); State.SpeedHackConn=nil end
    if e then State.SpeedHackConn = RunService.Heartbeat:Connect(function()
        local s = GetVehicleSeat(); if s then s.MaxSpeed = tonumber(State.SpeedHackValue) or 500 end
    end) end
end
function Car.Flip() local c=GetPlayerCar(); if c then local r=c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart"); if r then r.CFrame=CFrame.new(r.Position) end end end
function Car.Boost()
    local r = GetCarRoot(); if not r then return end
    local bv = Instance.new("BodyVelocity"); bv.Velocity=r.CFrame.LookVector*400
    bv.MaxForce=Vector3.new(math.huge,0,math.huge); bv.Parent=r
    game:GetService("Debris"):AddItem(bv, 0.3)
end
function Car.SetNoClip(e)
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn=nil end
    if e then State.NoclipConn = RunService.Stepped:Connect(function()
        local car = GetPlayerCar()
        if car then for _,p in ipairs(car:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        local ch = GetChar()
        if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end) end
end
function Car.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local h = GetHuman()
    if e then
        if h then h.PlatformStand = true end
        local hrp = GetHRP()
        if hrp then
            local bg = Instance.new("BodyGyro"); bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=9e4; bg.CFrame=hrp.CFrame; bg.Parent=hrp; bg.Name="__FG"
            local bv = Instance.new("BodyVelocity"); bv.Velocity=Vector3.zero; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.P=9e4; bv.Parent=hrp; bv.Name="__FV"
            State.FlyConn = RunService.RenderStepped:Connect(function()
                local h2 = GetHRP(); if not h2 then return end
                local bg2 = h2:FindFirstChild("__FG"); local bv2 = h2:FindFirstChild("__FV")
                if not bg2 or not bv2 then return end
                local spd = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 150 or 70
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
        if h then h.PlatformStand = false end
        local hrp = GetHRP()
        if hrp then local a=hrp:FindFirstChild("__FG"); local b=hrp:FindFirstChild("__FV"); if a then a:Destroy() end; if b then b:Destroy() end end
    end
end
function Car.SetGod(e) local h=GetHuman(); if h then if e then h.MaxHealth=math.huge; h.Health=math.huge else h.MaxHealth=100; h.Health=100 end end end
function Car.TeleportToPlayer(name)
    if not name or name=="" then return end
    local t = Players:FindFirstChild(name); if not t or not t.Character then return end
    local th = t.Character:FindFirstChild("HumanoidRootPart"); if not th then return end
    SmartTP.Go(th.Position + Vector3.new(0, 0, 4), 0)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SMUGGLER - WITH AUTO EQUIP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Smuggler = {}

function Smuggler.FirePrompt(prompt)
    if not prompt then return false end
    if not prompt.Enabled then
        if State.Smuggler_DebugMode then Log("Prompt disabled: " .. prompt:GetFullName()) end
        return false
    end
    local ok = pcall(function()
        if fireproximityprompt then fireproximityprompt(prompt) end
    end)
    if State.Smuggler_DebugMode then Log("Fired [" .. tostring(ok) .. "] " .. prompt:GetFullName()) end
    return ok
end

-- Equip a single tool by name
function Smuggler.EquipTool(toolName)
    local ch = GetChar()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not ch or not backpack then return false end
    
    if ch:FindFirstChild(toolName) then
        if State.Smuggler_DebugMode then Log("[Equip] Already equipped: " .. toolName) end
        return true
    end
    
    local tool = backpack:FindFirstChild(toolName)
    if tool then
        local hum = GetHuman()
        if hum then
            local ok = pcall(function() hum:EquipTool(tool) end)
            task.wait(0.3)
            if State.Smuggler_DebugMode then Log("[Equip] " .. tostring(ok) .. " - " .. toolName) end
            return ok
        end
    end
    
    if State.Smuggler_DebugMode then Log("[Equip] Not found in backpack: " .. toolName) end
    return false
end

-- Equip ALL matching tools (for multi-sell)
function Smuggler.EquipAll(toolName)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local hum = GetHuman()
    if not hum then return 0 end
    
    local count = 0
    for _, t in ipairs(backpack:GetChildren()) do
        if t:IsA("Tool") and t.Name == toolName then
            pcall(function() hum:EquipTool(t) end)
            count = count + 1
            task.wait(0.15)
        end
    end
    if State.Smuggler_DebugMode then Log("[EquipAll] Equipped " .. count .. " x " .. toolName) end
    return count
end

function Smuggler.GetBuyPrompt(itemName)
    itemName = itemName or State.Smuggler_ItemName
    if not BRP_PATHS.WorldBuyableItems then return nil end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(itemName)
    if not item then return nil end
    local handle = item:FindFirstChild("Handle")
    if handle then
        local pa = handle:FindFirstChild("PromptAttachment")
        if pa then
            local pp = pa:FindFirstChildOfClass("ProximityPrompt")
            if pp then return pp, item end
        end
    end
    for _, obj in ipairs(item:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then return obj, item end
    end
    return nil, item
end

function Smuggler.GetItemPos(itemName)
    itemName = itemName or State.Smuggler_ItemName
    if not BRP_PATHS.WorldBuyableItems then return nil end
    local item = BRP_PATHS.WorldBuyableItems:FindFirstChild(itemName)
    if not item then return nil end
    local handle = item:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle.Position end
    if item:IsA("BasePart") then return item.Position end
    local part = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

function Smuggler.BuyItem()
    Log("[Smuggler] Buying " .. State.Smuggler_ItemName)
    local prompt, item = Smuggler.GetBuyPrompt(State.Smuggler_ItemName)
    if not item then Log("[Smuggler] Item not found"); return false end
    local pos = Smuggler.GetItemPos(State.Smuggler_ItemName)
    if pos then SmartTP.Go(pos, 3) end
    if not prompt then Log("[Smuggler] No buy prompt"); return false end
    for i = 1, State.Smuggler_BuyRetries or 2 do
        Smuggler.FirePrompt(prompt)
        task.wait(0.4)
    end
    return true
end

function Smuggler.GetSellPrompt(sellerName)
    if not BRP_PATHS.NPC then return nil end
    local seller = BRP_PATHS.NPC:FindFirstChild(sellerName or "Seller4")
    if not seller then
        for _, npc in ipairs(BRP_PATHS.NPC:GetChildren()) do
            if npc.Name:lower():find("seller") then
                local hrp = npc:FindFirstChild("HumanoidRootPart")
                if hrp then local p = hrp:FindFirstChild("SellSmuggledGoodsPrompt"); if p then return p, npc end end
            end
        end
        return nil
    end
    local hrp = seller:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    return hrp:FindFirstChild("SellSmuggledGoodsPrompt"), seller
end

function Smuggler.SellItems()
    -- STEP 1: EQUIP THE ITEM FIRST (critical!)
    if State.Smuggler_AutoEquip then
        local itemCount = CountItems(State.Smuggler_ItemName)
        Log("[Smuggler] Items in inventory: " .. itemCount)
        
        if itemCount == 0 then
            Log("[Smuggler] No items to sell - skipping")
            return false
        end
        
        if State.Smuggler_EquipAll then
            Smuggler.EquipAll(State.Smuggler_ItemName)
        else
            Smuggler.EquipTool(State.Smuggler_ItemName)
        end
        task.wait(0.4)
    end
    
    -- STEP 2: MOVE TO SELLER
    Log("[Smuggler] Moving to seller")
    local prompt, seller = Smuggler.GetSellPrompt(State.Smuggler_SellerName)
    
    if not seller then
        SmartTP.Go(State.POS_Sell, 3)
        task.wait(State.Smuggler_SyncWait)
    else
        local sHRP = seller:FindFirstChild("HumanoidRootPart")
        if not sHRP then
            SmartTP.Go(State.POS_Sell, 3)
            task.wait(State.Smuggler_SyncWait)
        else
            local sellerPos = sHRP.Position
            
            if State.Smuggler_ApproachMethod == "WalkFinal" then
                Log("[Smuggler] TP + walk approach")
                local myHRP = GetHRP()
                local direction = myHRP and (myHRP.Position - sellerPos) or Vector3.new(0, 0, 1)
                if direction.Magnitude < 1 then direction = Vector3.new(0, 0, 1) end
                direction = direction.Unit
                local nearPos = sellerPos + direction * 15
                SmartTP.Go(nearPos, 3)
                task.wait(0.6)
                
                local hum = GetHuman()
                if hum then
                    local walkTarget = sellerPos + sHRP.CFrame.LookVector * 2
                    hum:MoveTo(walkTarget)
                    local walkStart = tick()
                    while tick() - walkStart < 4 do
                        local mh = GetHRP()
                        if mh and (mh.Position - sellerPos).Magnitude < 4 then break end
                        task.wait(0.1)
                    end
                    task.wait(0.5)
                end
            elseif State.Smuggler_ApproachMethod == "HighSpeedWalk" then
                Log("[Smuggler] High-speed walk approach")
                local hum = GetHuman()
                local origSpeed = hum and hum.WalkSpeed or 16
                local myHRP = GetHRP()
                local direction = myHRP and (myHRP.Position - sellerPos) or Vector3.new(0, 0, 1)
                if direction.Magnitude < 1 then direction = Vector3.new(0, 0, 1) end
                direction = direction.Unit
                local nearPos = sellerPos + direction * 25
                SmartTP.Go(nearPos, 3)
                task.wait(0.5)
                if hum then hum.WalkSpeed = 80 end
                if hum then
                    hum:MoveTo(sellerPos + sHRP.CFrame.LookVector * 2)
                    local walkStart = tick()
                    while tick() - walkStart < 3 do
                        local mh = GetHRP()
                        if mh and (mh.Position - sellerPos).Magnitude < 4 then break end
                        task.wait(0.1)
                    end
                end
                if hum then hum.WalkSpeed = origSpeed end
                task.wait(0.5)
            else
                Log("[Smuggler] Direct TP approach")
                local frontPos = sellerPos + sHRP.CFrame.LookVector * 2
                SmartTP.Go(frontPos, 0)
                task.wait(State.Smuggler_SyncWait)
            end
            
            local myHRP = GetHRP()
            if myHRP then
                if State.Smuggler_DebugMode then
                    Log("[Smuggler] Final distance: " .. math.floor((myHRP.Position - sellerPos).Magnitude))
                end
                myHRP.CFrame = CFrame.lookAt(myHRP.Position, sellerPos)
                task.wait(0.2)
            end
        end
    end
    
    -- STEP 3: RE-EQUIP (in case something changed) AND SELL
    if State.Smuggler_AutoEquip then
        Smuggler.EquipAll(State.Smuggler_ItemName)
        task.wait(0.3)
    end
    
    Log("[Smuggler] Firing sell prompt")
    local retries = State.Smuggler_SellRetries or 5
    for i = 1, retries do
        -- Re-equip between each attempt in case tool got dropped
        if State.Smuggler_AutoEquip and i > 1 then
            local ch = GetChar()
            if ch and not ch:FindFirstChild(State.Smuggler_ItemName) then
                Smuggler.EquipTool(State.Smuggler_ItemName)
                task.wait(0.2)
            end
        end
        
        if prompt then Smuggler.FirePrompt(prompt) end
        if State.Smuggler_UseRemotes and BRP.SellSmuggledGoods then
            pcall(function() BRP.SellSmuggledGoods:FireServer() end)
        end
        task.wait(0.5)
    end
    
    State.Smuggler_JobsDone = State.Smuggler_JobsDone + 1
    Log("[Smuggler] Sold #" .. State.Smuggler_JobsDone)
    return true
end

function Smuggler.GetLaunderPrompt()
    if BRP_PATHS.LaunderTrigger then
        local pp = BRP_PATHS.LaunderTrigger:FindFirstChild("PromptPart")
        if pp then return pp:FindFirstChild("LaunderBriefcasePrompt") end
    end
end

function Smuggler.LaunderMoney()
    if not State.Smuggler_AutoLaunder then return true end
    Log("[Smuggler] Moving to laundry")
    SmartTP.Go(State.POS_Laundry, 3); task.wait(0.6)
    Log("[Smuggler] Laundering")
    local prompt = Smuggler.GetLaunderPrompt()
    if prompt then 
        for i = 1, 2 do
            Smuggler.FirePrompt(prompt)
            task.wait(0.4)
        end
    end
    if State.Smuggler_UseRemotes and BRP.LaunderBriefcase then
        pcall(function() BRP.LaunderBriefcase:FireServer() end); task.wait(0.4)
    end
    return true
end

function Smuggler.RunCycle()
    Smuggler.BuyItem();     if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
    Smuggler.SellItems();   if not State.Smuggler_AutoLoop then return end; task.wait(0.3)
    Smuggler.LaunderMoney()
end

function Smuggler.SetAutoLoop(e)
    State.Smuggler_AutoLoop = e
    if not e then Log("[Smuggler] Stopped"); return end
    Log("[Smuggler] Started")
    task.spawn(function()
        while State.Smuggler_AutoLoop do
            local ok, err = pcall(Smuggler.RunCycle)
            if not ok then Log("Cycle err: " .. tostring(err)) end
            if not State.Smuggler_AutoLoop then break end
            task.wait(State.Smuggler_Delay)
        end
        Log("[Smuggler] Loop ended")
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- POLICE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Police = {}

function Police.CreateFOV()
    if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
    if Drawing then
        State.Police_FOVCircle = Drawing.new("Circle")
        State.Police_FOVCircle.Thickness = 1; State.Police_FOVCircle.NumSides = 60
        State.Police_FOVCircle.Radius = State.Police_AimFOV
        State.Police_FOVCircle.Filled = false; State.Police_FOVCircle.Visible = false
        State.Police_FOVCircle.Transparency = 0.7; State.Police_FOVCircle.Color = Color3.fromRGB(255, 50, 50)
    end
end

function Police.UpdateFOV()
    if State.Police_FOVCircle then
        local vp = Camera.ViewportSize
        State.Police_FOVCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
        State.Police_FOVCircle.Radius = State.Police_AimFOV
        State.Police_FOVCircle.Visible = State.Police_ShowFOV and (State.Police_AutoAim or State.Police_AutoFire)
    end
end

function Police.GetTarget()
    local myHRP = GetHRP(); if not myHRP then return nil, nil end
    local vp = Camera.ViewportSize; local center = Vector2.new(vp.X/2, vp.Y/2)
    local bestP, bestPart, bestDist = nil, nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local should = false
                if State.Police_TargetAll then should = true
                elseif State.Police_TargetWanted then should = IsWanted(p) end
                if should then
                    local aim = p.Character:FindFirstChild(State.Police_AimPart) or p.Character:FindFirstChild("HumanoidRootPart")
                    if aim then
                        local sp, on = Camera:WorldToScreenPoint(aim.Position)
                        if on then
                            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if d <= State.Police_AimFOV and d < bestDist then
                                bestP=p; bestPart=aim; bestDist=d
                            end
                        end
                    end
                end
            end
        end
    end
    return bestP, bestPart
end

function Police.AimAt(part)
    if not part or not part.Parent then return end
    local tp = part.Position
    if State.Police_AimSmooth <= 1 then Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, tp)
    else local cur = Camera.CFrame; Camera.CFrame = cur:Lerp(CFrame.lookAt(cur.Position, tp), math.clamp(1/State.Police_AimSmooth, 0.05, 1)) end
end

function Police.TryFire()
    pcall(function() mouse1click() end)
    if BRP.BatonSwing and State.Police_CurrentTarget then
        pcall(function() BRP.BatonSwing:FireServer(State.Police_CurrentTarget) end)
    end
end

function Police.TryArrest()
    local t = State.Police_CurrentTarget
    if not t or not t.Character then return end
    local tHRP = t.Character:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    local myHRP = GetHRP()
    if myHRP then
        local d = (myHRP.Position - tHRP.Position).Magnitude
        if d > 8 then
            SmartTP.Go(tHRP.Position + tHRP.CFrame.LookVector * -3, 0)
            task.wait(0.3)
        end
    end
    if BRP.Detain then
        pcall(function() BRP.Detain:InvokeServer(t) end)
        Log("Arrested: " .. t.Name)
    end
    if BRP.Jail then task.wait(0.4); pcall(function() BRP.Jail:InvokeServer(t) end) end
end

function Police.SetAutoAim(e)
    State.Police_AutoAim = e
    if State.Police_AimConn then pcall(function() State.Police_AimConn:Disconnect() end); State.Police_AimConn=nil end
    if e then
        Police.CreateFOV()
        State.Police_AimConn = RunService.RenderStepped:Connect(function()
            Police.UpdateFOV()
            local p, part = Police.GetTarget()
            State.Police_CurrentTarget = p
            if part and (UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or State.Police_AutoFire) then
                Police.AimAt(part)
            end
        end)
        Notify("Aimbot", "Enabled - hold RMB to lock", 3)
    else
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle.Visible = false end) end
        State.Police_CurrentTarget = nil
    end
end

function Police.SetAutoFire(e)
    State.Police_AutoFire = e
    if State.Police_FireConn then pcall(function() State.Police_FireConn:Disconnect() end); State.Police_FireConn=nil end
    if e then
        local last = 0
        State.Police_FireConn = RunService.Heartbeat:Connect(function()
            if State.Police_CurrentTarget and tick() - last >= 0.15 then
                last = tick(); Police.TryFire()
            end
        end)
    end
end

function Police.SetAutoArrest(e)
    State.Police_AutoArrest = e
    if State.Police_ArrestConn then pcall(function() State.Police_ArrestConn:Disconnect() end); State.Police_ArrestConn=nil end
    if e then
        local last = 0
        State.Police_ArrestConn = RunService.Heartbeat:Connect(function()
            if State.Police_CurrentTarget and tick() - last >= 2.5 then last = tick(); Police.TryArrest() end
        end)
    end
end

--━ VISUALS
local Vis = {}
function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart, GlobalShadows=Lighting.GlobalShadows}
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
function Vis.SetFOV(f) if Camera then Camera.FieldOfView = tonumber(f) or 70 end end
function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end
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

CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end
end)
task.spawn(function() while task.wait(1) do
    if State.GodMode then local h=GetHuman(); if h then h.MaxHealth=math.huge; h.Health=math.huge end end
end end)
CM:Add(UserInputService.JumpRequest, function()
    if State.InfiniteJump then local h=GetHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
end)

local function GetSellerNames()
    local names = {}
    if BRP_PATHS.NPC then
        for _, npc in ipairs(BRP_PATHS.NPC:GetChildren()) do
            if npc.Name:lower():find("seller") then table.insert(names, npc.Name) end
        end
    end
    if #names == 0 then table.insert(names, "Seller4") end
    return names
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
    {key="Main", name="Main", icon="home"},
    {key="Car", name="Vehicle", icon="zap"},
    {key="Smuggler", name="Smuggler", icon="package"},
    {key="Police", name="Police", icon="shield"},
    {key="Teleport", name="Teleport", icon="map-pin"},
    {key="ESP", name="ESP", icon="eye"},
    {key="Remote", name="Remotes", icon="radio"},
    {key="Visuals", name="Visuals", icon="sun"},
    {key="Misc", name="Misc", icon="wrench"},
    {key="Settings", name="Settings", icon="settings"},
}) do
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
local function Drp(t,c) if t then pcall(function() t:CreateDropdown(c) end) end end

if Tabs.Main then
    local T = Tabs.Main
    Sec(T, "X0DEC04T Hub v" .. HUB.Version)
    Lbl(T, "Game: Border RP (Scarface)")
    Lbl(T, "PlaceId: 136020512003847")
    Sec(T, "System")
    Lbl(T, "Remotes wired: " .. remoteCount)
    Lbl(T, "Buyable items: " .. (BRP_PATHS.WorldBuyableItems and #BRP_PATHS.WorldBuyableItems:GetChildren() or 0))
    Lbl(T, "Sellers found: " .. #GetSellerNames())
    Sec(T, "Player")
    Lbl(T, "Team: " .. (LocalPlayer.Team and LocalPlayer.Team.Name or "None"))
    Lbl(T, "Rank: " .. GetRank(LocalPlayer))
end

if Tabs.Car then
    local T = Tabs.Car
    Sec(T, "Speed")
    Sld(T, {Name="Extra Speed", Range={0,500}, Increment=10, CurrentValue=0, Flag="ES",
        Callback=function(v) State.CarSpeed=v; Car.ApplySpeed() end})
    Sld(T, {Name="SpeedHack Value", Range={100,2000}, Increment=50, CurrentValue=500, Flag="SHV",
        Callback=function(v) State.SpeedHackValue=v; if State.SpeedHack then Car.SetSpeedHack(true) end end})
    Tog(T, {Name="Speed Hack", CurrentValue=false, Flag="SH",
        Callback=function(v) State.SpeedHack=v; Car.SetSpeedHack(v) end})
    Sec(T, "Actions")
    Btn(T, {Name="Flip Car", Callback=Car.Flip})
    Btn(T, {Name="Boost Forward", Callback=Car.Boost})
    Btn(T, {Name="Unstuck Vehicle", Callback=function() if BRP.UnstuckVehicle then pcall(function() BRP.UnstuckVehicle:FireServer() end) end end})
    Sec(T, "Abilities")
    Tog(T, {Name="NoClip", CurrentValue=false, Flag="NC", Callback=function(v) State.NoClip=v; Car.SetNoClip(v) end})
    Tog(T, {Name="Fly", CurrentValue=false, Flag="FL", Callback=function(v) State.FlyActive=v; Car.SetFly(v) end})
    Tog(T, {Name="God Mode", CurrentValue=false, Flag="GM", Callback=function(v) State.GodMode=v; Car.SetGod(v) end})
    Sec(T, "Character")
    Sld(T, {Name="WalkSpeed", Range={16,200}, Increment=4, CurrentValue=16, Flag="WS",
        Callback=function(v) State.WalkSpeed=v; local h=GetHuman(); if h then h.WalkSpeed=v end end})
    Sld(T, {Name="JumpPower", Range={50,300}, Increment=10, CurrentValue=50, Flag="JP",
        Callback=function(v) State.JumpPower=v; local h=GetHuman(); if h then h.JumpPower=v end end})
    Tog(T, {Name="Infinite Jump", CurrentValue=false, Flag="IJ", Callback=function(v) State.InfiniteJump=v end})
end

if Tabs.Smuggler then
    local T = Tabs.Smuggler
    Sec(T, "Auto Smuggler")
    Lbl(T, "Loop: Buy - Equip - Sell - Launder")
    
    Sec(T, "Item Selection")
    local buyableNames = GetBuyableItemNames()
    Drp(T, {Name="Item to Buy", Options=buyableNames,
        CurrentOption={"Fake Diamond Ring"}, MultiOption=false, Flag="ItemPick",
        Callback=function(v) State.Smuggler_ItemName = (type(v)=="table" and v[1]) or v end})
    Sld(T, {Name="Buy Prompt Retries", Range={1,5}, Increment=1, CurrentValue=2, Flag="BR",
        Callback=function(v) State.Smuggler_BuyRetries = v end})
    
    Sec(T, "Equip Settings")
    Tog(T, {Name="Auto Equip Before Sell", CurrentValue=true, Flag="AE",
        Callback=function(v) State.Smuggler_AutoEquip = v end})
    Tog(T, {Name="Equip All Copies (multi-sell)", CurrentValue=true, Flag="EA",
        Callback=function(v) State.Smuggler_EquipAll = v end})
    
    Sec(T, "Seller Approach")
    local sellerNames = GetSellerNames()
    Drp(T, {Name="Target Seller", Options=sellerNames,
        CurrentOption={State.Smuggler_SellerName}, MultiOption=false, Flag="SN",
        Callback=function(v) State.Smuggler_SellerName = (type(v)=="table" and v[1]) or v end})
    Drp(T, {Name="Approach Method", Options={"WalkFinal","HighSpeedWalk","DirectTP"},
        CurrentOption={"WalkFinal"}, MultiOption=false, Flag="AM",
        Callback=function(v) State.Smuggler_ApproachMethod = (type(v)=="table" and v[1]) or v end})
    Sld(T, {Name="Sell Retries", Range={1,10}, Increment=1, CurrentValue=5, Flag="SR",
        Callback=function(v) State.Smuggler_SellRetries = v end})
    Sld(T, {Name="Server Sync Wait (0.1s)", Range={5,30}, Increment=1, CurrentValue=15, Flag="SW",
        Callback=function(v) State.Smuggler_SyncWait = v / 10 end})
    
    Sec(T, "Anti-Cheat Bypass")
    Tog(T, {Name="AntiTp Rollback Bypass", CurrentValue=true, Flag="ATP",
        Callback=function(v) 
            State.AntiTpBypass = v
            if v then AntiTpBypass.Enable() else AntiTpBypass.Disable() end
        end})
    Drp(T, {Name="Teleport Strategy", 
        Options={"Instant","Chunked","Tween","Velocity"},
        CurrentOption={"Chunked"}, MultiOption=false, Flag="TPS",
        Callback=function(v) State.TPStrategy = (type(v)=="table" and v[1]) or v end})
    Sld(T, {Name="Chunk Size (studs)", Range={50,500}, Increment=25, CurrentValue=150, Flag="TCS",
        Callback=function(v) State.TPChunkSize = v end})
    
    Sec(T, "Timing")
    Sld(T, {Name="Cycle Delay (sec)", Range={0,10}, Increment=1, CurrentValue=1, Flag="SD",
        Callback=function(v) State.Smuggler_Delay = v end})
    Tog(T, {Name="Use Remote Backup", CurrentValue=true, Flag="UR",
        Callback=function(v) State.Smuggler_UseRemotes = v end})
    Tog(T, {Name="Auto Launder", CurrentValue=true, Flag="AL",
        Callback=function(v) State.Smuggler_AutoLaunder = v end})
    Tog(T, {Name="Debug Mode", CurrentValue=false, Flag="DBG",
        Callback=function(v) State.Smuggler_DebugMode = v end})
    
    Sec(T, "Main Toggle")
    Tog(T, {Name="Auto Smuggler (Full Loop)", CurrentValue=false, Flag="AS",
        Callback=function(v) Smuggler.SetAutoLoop(v) end})
    
    Sec(T, "Manual Steps")
    Btn(T, {Name="1. Buy Item", Callback=function() task.spawn(Smuggler.BuyItem) end})
    Btn(T, {Name="2. Equip Item(s)", Callback=function()
        task.spawn(function()
            if State.Smuggler_EquipAll then
                Smuggler.EquipAll(State.Smuggler_ItemName)
            else
                Smuggler.EquipTool(State.Smuggler_ItemName)
            end
        end)
    end})
    Btn(T, {Name="3. Sell to NPC", Callback=function() task.spawn(Smuggler.SellItems) end})
    Btn(T, {Name="4. Launder Money", Callback=function() task.spawn(Smuggler.LaunderMoney) end})
    
    Sec(T, "Direct Remote Fire")
    Btn(T, {Name="Fire SellSmuggledGoods", Callback=function()
        if BRP.SellSmuggledGoods then pcall(function() BRP.SellSmuggledGoods:FireServer() end); Notify("Sent","",2) end
    end})
    Btn(T, {Name="Fire LaunderBriefcase", Callback=function()
        if BRP.LaunderBriefcase then pcall(function() BRP.LaunderBriefcase:FireServer() end); Notify("Sent","",2) end
    end})
    Btn(T, {Name="Count Items in Inventory", Callback=function()
        local c = CountItems(State.Smuggler_ItemName)
        Notify("Inventory", c .. " x " .. State.Smuggler_ItemName, 4)
        Log("Items: " .. c)
    end})
end

if Tabs.Police then
    local T = Tabs.Police
    Sec(T, "Police Aimbot")
    Sec(T, "Targeting")
    Tog(T, {Name="Target Wanted Only", CurrentValue=true, Flag="TW", Callback=function(v) State.Police_TargetWanted=v end})
    Tog(T, {Name="Target All Players", CurrentValue=false, Flag="TA", Callback=function(v) State.Police_TargetAll=v end})
    Sld(T, {Name="Min Wanted Level", Range={1,10}, Increment=1, CurrentValue=1, Flag="MWL",
        Callback=function(v) State.Police_MinWantedLevel=v end})
    Drp(T, {Name="Aim Part", Options={"Head","HumanoidRootPart","UpperTorso","LowerTorso"},
        CurrentOption={"Head"}, MultiOption=false, Flag="AP",
        Callback=function(v) State.Police_AimPart = (type(v)=="table" and v[1]) or v end})
    Sec(T, "Aim Settings")
    Sld(T, {Name="FOV Radius", Range={30,500}, Increment=10, CurrentValue=150, Flag="AFOV",
        Callback=function(v) State.Police_AimFOV=v end})
    Sld(T, {Name="Smoothness", Range={1,20}, Increment=1, CurrentValue=1, Flag="ASM",
        Callback=function(v) State.Police_AimSmooth=v end})
    Tog(T, {Name="Show FOV Circle", CurrentValue=true, Flag="SFOV", Callback=function(v) State.Police_ShowFOV=v end})
    Sec(T, "Controls")
    Tog(T, {Name="Auto-Aim (hold RMB)", CurrentValue=false, Flag="AAim", Callback=function(v) Police.SetAutoAim(v) end})
    Tog(T, {Name="Auto-Fire", CurrentValue=false, Flag="AFire", Callback=function(v) Police.SetAutoFire(v) end})
    Tog(T, {Name="Auto-Arrest", CurrentValue=false, Flag="AArr", Callback=function(v) Police.SetAutoArrest(v) end})
    Sec(T, "Quick Actions")
    Btn(T, {Name="TP to Nearest Wanted", Callback=function()
        local myHRP = GetHRP(); if not myHRP then return end
        local best, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and IsWanted(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then local d = (hrp.Position - myHRP.Position).Magnitude; if d < bestDist then best = p; bestDist = d end end
            end
        end
        if best and best.Character then
            local hrp = best.Character:FindFirstChild("HumanoidRootPart")
            if hrp then SmartTP.Go(hrp.Position + hrp.CFrame.LookVector * -5, 1)
                Notify("TP", "Moved to " .. best.Name, 3) end
        else Notify("TP", "No wanted players", 3) end
    end})
    Btn(T, {Name="Detain Current Target", Callback=function()
        if State.Police_CurrentTarget and BRP.Detain then
            pcall(function() BRP.Detain:InvokeServer(State.Police_CurrentTarget) end)
        end
    end})
end

if Tabs.Teleport then
    local T = Tabs.Teleport
    Sec(T, "Player TP")
    Inp(T, {Name="Name", PlaceholderText="Case-sensitive", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.TP_Target=v end})
    Btn(T, {Name="TP to Player", Callback=function() Car.TeleportToPlayer(State.TP_Target) end})
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(names, p.Name) end end
    Drp(T, {Name="Player Dropdown", Options=#names>0 and names or {"None"}, CurrentOption={names[1] or "None"},
        MultiOption=false, Flag="TPD",
        Callback=function(v) Car.TeleportToPlayer((type(v)=="table" and v[1]) or v) end})
    Sec(T, "Quick Locations")
    Btn(T, {Name="Shop (El Capo)", Callback=function() SmartTP.Go(State.POS_Shop, 3) end})
    Btn(T, {Name="Sell NPC", Callback=function() SmartTP.Go(State.POS_Sell, 3) end})
    Btn(T, {Name="Laundry", Callback=function() SmartTP.Go(State.POS_Laundry, 3) end})
end

if Tabs.ESP then
    local T = Tabs.ESP
    Sec(T, "ESP")
    Tog(T, {Name="All Players", CurrentValue=false, Flag="PE", Callback=function(v) State.ESP_Players = v end})
    Tog(T, {Name="Wanted (Red)", CurrentValue=false, Flag="WE", Callback=function(v) State.ESP_Wanted=v end})
    Tog(T, {Name="Police (Blue)", CurrentValue=false, Flag="POE", Callback=function(v) State.ESP_Police=v end})
    Sec(T, "Display")
    Tog(T, {Name="Show Names", CurrentValue=true, Flag="EN",
        Callback=function(v) State.ESP_ShowName=v; for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end end})
    Tog(T, {Name="Show Distance", CurrentValue=true, Flag="ED",
        Callback=function(v) State.ESP_ShowDist=v; for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end end})
    Sld(T, {Name="Max Distance", Range={100,5000}, Increment=100, CurrentValue=800, Flag="EMD",
        Callback=function(v) State.ESP_MaxDist=v; for _,c in pairs(State.ESPCache) do if c.bb then c.bb.MaxDistance=v end end end})
    Btn(T, {Name="Refresh", Callback=function() ESP.ClearAll(); ESP.RefreshAll() end})
    Btn(T, {Name="Clear All", Callback=ESP.ClearAll})
end

if Tabs.Remote then
    local T = Tabs.Remote
    Sec(T, "Fire Remote")
    Lbl(T, "Total: " .. #RemoteDBAll)
    Inp(T, {Name="Name", PlaceholderText="Remote name", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.RemoteName=v end})
    Inp(T, {Name="Arg", PlaceholderText="Optional", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.RemoteArg=v end})
    Btn(T, {Name="Fire", Callback=function()
        local r = FindRemote(State.RemoteName)
        if not r then Notify("Remote", "Not found", 3); return end
        local a = State.RemoteArg
        local n = tonumber(a); if n then a = n end
        if a == "true" then a = true elseif a == "false" then a = false end
        pcall(function() if r:IsA("RemoteEvent") then r:FireServer(a) else r:InvokeServer(a) end end)
        Notify("Remote", "Fired " .. r.Name, 2)
    end})
end

if Tabs.Visuals then
    local T = Tabs.Visuals
    Sec(T, "Lighting")
    Tog(T, {Name="FullBright", CurrentValue=false, Flag="FB", Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    Tog(T, {Name="No Fog", CurrentValue=false, Flag="NF", Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    Sld(T, {Name="Time of Day", Range={0,24}, Increment=1, CurrentValue=14, Flag="TOD", Callback=function(v) Vis.SetClock(v) end})
    Sec(T, "Camera")
    Sld(T, {Name="FOV", Range={30,120}, Increment=5, CurrentValue=70, Flag="FOV2", Callback=function(v) State.FOV=v; Vis.SetFOV(v) end})
end

if Tabs.Misc then
    local T = Tabs.Misc
    Sec(T, "Audio")
    Tog(T, {Name="Mute All Sounds", CurrentValue=false, Flag="MA", Callback=function(v) Vis.MuteAll(v) end})
    Sec(T, "Server")
    Btn(T, {Name="Server Hop", Callback=Vis.ServerHop})
    Btn(T, {Name="Rejoin", Callback=function() pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end) end})
    Sec(T, "Utility")
    Btn(T, {Name="Copy Current Position", Callback=function()
        local h = GetHRP()
        if h then
            local p = h.Position
            local s = string.format("Vector3.new(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
            Log("Pos: " .. s)
            if setclipboard then setclipboard(s) end
            Notify("Copied", s, 3)
        end
    end})
    Btn(T, {Name="Copy JobId", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","JobId",2) end
    end})
end

if Tabs.Settings then
    local T = Tabs.Settings
    Sec(T, "Anti-AFK")
    Tog(T, {Name="Anti-AFK", CurrentValue=true, Flag="AA", Callback=function(v) State.AntiAFK=v end})
    Sec(T, "Keybinds")
    Kbnd(T, {Name="Toggle UI", CurrentKeybind="RightShift", HoldToInteract=false, Flag="KUI",
        Callback=function() pcall(function() Window:Toggle() end) end})
    Kbnd(T, {Name="Panic (Disable All)", CurrentKeybind="End", HoldToInteract=false, Flag="KP",
        Callback=function()
            State.ESP_Players=false; State.ESP_Wanted=false; State.ESP_Police=false
            ESP.ClearAll()
            Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
            Smuggler.SetAutoLoop(false)
            Notify("PANIC", "All disabled", 3)
        end})
    Kbnd(T, {Name="Toggle Aimbot", CurrentKeybind="RightAlt", HoldToInteract=false, Flag="KAim",
        Callback=function() State.Police_AutoAim = not State.Police_AutoAim; Police.SetAutoAim(State.Police_AutoAim) end})
    Sec(T, "Credits")
    Lbl(T, HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "by " .. HUB.Author)
    Sec(T, "Unload")
    Btn(T, {Name="Unload Hub", Callback=function()
        Smuggler.SetAutoLoop(false)
        Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTpBypass.Disable()
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end) end
        if State.SpeedHackConn then pcall(function() State.SpeedHackConn:Disconnect() end) end
        CM:Cleanup(); Vis.RestoreLight(); Vis.MuteAll(false)
        pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        ESP.ClearAll(); _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end})
end

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    if State.GodMode then pcall(Car.SetGod, true) end
    if State.NoClip then pcall(Car.SetNoClip, true) end
    if State.FlyActive then pcall(Car.SetFly, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.WalkSpeed ~= 16 then local h=GetHuman(); if h then h.WalkSpeed=State.WalkSpeed end end
    if State.AntiTpBypass then AntiTpBypass.Enable() end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        Smuggler.SetAutoLoop(false)
        Police.SetAutoAim(false); Police.SetAutoFire(false); Police.SetAutoArrest(false)
        AntiTpBypass.Disable()
        if State.Police_FOVCircle then pcall(function() State.Police_FOVCircle:Remove() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v" .. HUB.Version .. " loaded", 4)
Log("v2.7.6 init complete | " .. remoteCount .. " remotes")
