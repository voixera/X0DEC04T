--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.9.1
--═══════════════════════════════════════════════════════════════════════════════

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local HttpService         = game:GetService("HttpService")
local Workspace           = game:GetService("Workspace")
local CoreGui             = game:GetService("CoreGui")
local VirtualUser         = game:GetService("VirtualUser")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local VirtualInputMgr     = game:GetService("VirtualInputManager")
local TextChatService     = game:GetService("TextChatService")
local TweenService        = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")
local ContentProvider     = game:GetService("ContentProvider")
local Stats               = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_v191"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("v1.9.1 starting")

-- ═══════════════════════════════════════════════════════════════
-- FLUENT UI LOAD
-- ═══════════════════════════════════════════════════════════════
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "1.0.1",
    Author  = "My Gw",
    LogoId  = "rbxassetid://85855925276969",   -- NEW logo asset
    Discord = "discord.gg/x0dec04t",
}

local KILLER_RED = Color3.fromRGB(220, 60, 60)

-- ═══════════════════════════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════════════════════════
local CM = { _list = {} }
function CM:Add(sig, cb)
    if not sig then return end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

local function IsTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, cfg = pcall(function() return TextChatService.ChatInputBarConfiguration end)
    if ok and cfg and cfg.IsFocused then return true end
    return false
end

local KB = { _binds = {}, DoubleTapWindow = 0.35, _lastTap = {}, BlockWhileTyping = true }
function KB.Register(name, key, cb, requireDouble)
    KB._binds[name] = { key = key, callback = cb, enabled = true, requireDouble = requireDouble }
end

CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if KB.BlockWhileTyping and IsTyping() then return end
    for name, bind in pairs(KB._binds) do
        if bind.enabled and bind.key == inp.KeyCode then
            if bind.requireDouble then
                local now = tick()
                if now - (KB._lastTap[name] or 0) <= KB.DoubleTapWindow then
                    KB._lastTap[name] = 0; pcall(bind.callback)
                else KB._lastTap[name] = now end
            else pcall(bind.callback) end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- REMOTES (expanded for heal / adrenaline)
-- ═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function GR(...)
    if not Remotes then return nil end
    local c = Remotes
    for _, n in ipairs({...}) do
        c = c:FindFirstChild(n)
        if not c then return nil end
    end
    return c
end

-- Deep search helper for remotes with a partial name match
local function DeepFindRemote(keywords)
    if not Remotes then return nil end
    for _, obj in ipairs(Remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if n:find(kw, 1, true) then return obj end
            end
        end
    end
    return nil
end

local R = {
    Gen = {
        RepairEvent = GR("Generator","RepairEvent"),
        BreakEvent  = GR("Generator","BreakGenEvent"),
        BreakCommit = GR("Generator","BreakGenCommit"),
    },
    SkillCheck = {
        GenResult  = GR("Generator","SkillCheckResultEvent"),
        HealResult = GR("Healing","SkillCheckResultEvent"),
    },
    -- HEAL REMOTES - multiple variants tried
    Heal              = GR("Healing","HealEvent"),
    HealCommit        = GR("Healing","HealCommit"),
    HealSelf          = GR("Healing","HealSelf"),
    HealPlayer        = GR("Healing","HealPlayer"),
    HealStart         = GR("Healing","StartHeal"),
    HealFinish        = GR("Healing","FinishHeal"),
    MedKit            = GR("Items","MedKit","Heal") or GR("Items","Medkit","Heal"),
    AdrenalineHealthy = GR("Items","Adrenaline Shot","Healthy"),
    AdrenalineInject  = GR("Items","Adrenaline Shot","Inject"),
    AdrenalineUse     = GR("Items","Adrenaline Shot","Use"),
    Attacks = {
        Basic = GR("Attacks","BasicAttack"),
        After = GR("Attacks","AfterAttack"),
        Hit   = GR("Attacks","hit"),
        Lunge = GR("Attacks","Lunge"),
    },
    AttackEvent = GR("AttackEvent"),
    Killers = {
        Frenzy      = GR("Killers","Killer","FrenzyHitEvent"),
        Masked      = GR("Killers","Masked","alexattack"),
        Hidden      = GR("Killers","Hidden","m2HitVM"),
        SlowAttack  = GR("Killers","SlowAttack"),
        CureInject  = GR("Killers","Cure","inject"),
        StalkerGrab = GR("Killers","Stalker","grab"),
    },
    KingScourge = GR("KillerPerks","kingscourge","KingScourgeHit"),
    Pallet = {
        BreakCommit = GR("Pallet","Jason","PalletBreakCommit"),
        DropCommit  = GR("Pallet","PalletDropCommit"),
        Stunover    = GR("Pallet","Jason","Stunover"),
    },
    Vault     = GR("Window","VaultEvent"),
    FastVault = GR("Window","fastvault"),
}

-- Auto-discover heal remotes if not found by name
if not R.Heal then
    R.Heal = DeepFindRemote({"heal","medkit","medical","bandage"})
    if R.Heal then Log("[Heal] Auto-discovered: " .. R.Heal:GetFullName()) end
end
if not R.AdrenalineHealthy then
    R.AdrenalineHealthy = DeepFindRemote({"adrenal","inject","syringe","shot"})
    if R.AdrenalineHealthy then Log("[Adren] Auto-discovered: " .. R.AdrenalineHealthy:GetFullName()) end
end

-- ═══════════════════════════════════════════════════════════════
-- OBJECT FINDERS
-- ═══════════════════════════════════════════════════════════════
local function FindAllGenerators()
    local list = {}
    local map = Workspace:FindFirstChild("Map")
    if map then
        local gc = map:FindFirstChild("Generators")
        if gc then
            for _, g in ipairs(gc:GetChildren()) do
                if g:IsA("Model") then table.insert(list, g) end
            end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Generator" and v:GetAttribute("RepairProgress") ~= nil then
            local exists = false
            for _, e in ipairs(list) do if e == v then exists = true; break end end
            if not exists then table.insert(list, v) end
        end
    end
    return list
end

local function GetPallets()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "Palletwrong" or v.Name == "Pallet") then
            table.insert(list, v)
        end
    end
    return list
end

local function GetVaults()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Window" then table.insert(list, v) end
    end
    return list
end

local function GetExits()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Gate" then table.insert(list, v) end
    end
    return list
end

local function GetZombies()
    local list = {}
    local clones = Workspace:FindFirstChild("Clones")
    if clones then
        for _, obj in ipairs(clones:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                table.insert(list, obj)
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local n = obj.Name:lower()
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true; break end
            end
            if not isPlayer and (n:find("infected") or n:find("corpse") or n:find("minion")
            or n:find("cure") or n:find("zombie") or n:find("puppet")) then
                local exists = false
                for _, e in ipairs(list) do if e == obj then exists = true; break end end
                if not exists then table.insert(list, obj) end
            end
        end
    end
    return list
end

-- ═══════════════════════════════════════════════════════════════
-- KILLER DETECTION
-- ═══════════════════════════════════════════════════════════════
local function IsPlayerKiller(plr, character)
    if not plr then return false end
    character = character or plr.Character
    local isKiller = false

    if character then
        pcall(function()
            local role = tostring(character:GetAttribute("Role") or ""):lower()
            if role:find("killer") then isKiller = true end
        end)
        if isKiller then return true end
        pcall(function()
            if character:GetAttribute("IsKiller") == true then isKiller = true end
        end)
        if isKiller then return true end
    end

    pcall(function()
        local role = tostring(plr:GetAttribute("Role") or ""):lower()
        if role:find("killer") then isKiller = true end
    end)
    if isKiller then return true end

    pcall(function()
        if plr:GetAttribute("IsKiller") == true then isKiller = true end
    end)
    if isKiller then return true end

    pcall(function()
        local kf = Workspace:FindFirstChild("Killers")
        if kf and kf:FindFirstChild(plr.Name) then isKiller = true end
    end)
    if isKiller then return true end

    pcall(function()
        if plr.Team and tostring(plr.Team.Name):lower():find("killer") then
            isKiller = true
        end
    end)
    if isKiller then return true end

    if character then
        for _, killerName in ipairs({"Killer","JasonAI","MaskedAI","HiddenAI","StalkerAI","FrenzyAI"}) do
            if character:FindFirstChild(killerName) then isKiller = true; break end
        end
    end

    return isKiller
end

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local State = {
    ESP_Player = false, ESP_Zombie = false,
    ESP_HealthBar = true, ESP_Distance = true,
    ESP_Generator = false, ESP_Vault = false,
    ESP_Pallet = false, ESP_Exit = false,
    ESP_MaxDistance = 1500,
    Color_Player = Color3.fromRGB(60,220,60),
    Color_Killer = KILLER_RED,
    Color_Vault  = Color3.fromRGB(180,60,220),
    Color_Pallet = Color3.fromRGB(255,140,20),
    Color_Zombie = Color3.fromRGB(255,140,20),
    Color_Exit   = Color3.fromRGB(255,255,255),

    ESP_Hook          = false,
    ESP_HookConn      = nil,
    ESP_HookOriginals = {},
    ESP_HookTransparency = 0.75,
    ESP_HookMode      = "Walls",

    AutoGenRush = false, GenKillerRadius = 30, AutoGenMode = "Legit",
    RemoveSkillcheck = false,
    AutoHeal = false, AutoHealThreshold = 60, LastHealTime = 0,
    HealCooldown = 1.2,
    FastVault = false, NoFallDamage = false,
    WalkSpeedEnabled = false, WalkSpeedValue = 28,
    Invisible = false, UnlockCursor = false,

    AutoHit = false, AutoHitRange = 12,
    AutoHitAll = false, AutoHitAllDelay = 5,
    AutoDamageGen = false, InstantDamageGen = false,
    InstantBreakPallet = false,
    KillerWalkSpeedEnabled = false, KillerWalkSpeedValue = 30,
    NoStun = false, NoSlowdown = false,

    TeleportTarget = nil, AutoFollowTarget = nil,
    AutoFollowEnabled = false, AutoFollowOffset = Vector3.new(2,0,2),

    -- Visuals (auto)
    FullBright = true,
    NoFog = true,
    NoShadows = true,
    UnlimitedZoom = false,
    Crosshair = false,

    -- FPS Counter (small)
    FPSCounter        = true,
    FPSGui            = nil,
    FPSLabel          = nil,
    FPSFrames         = 0,
    FPSLastUpdate     = 0,
    FPSValue          = 0,
    FPSPingValue      = 0,

    AntiAFK = true, FPSBoost = false,
    Notifications = true,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,

    WalkSpeed = 16, ESPCache = {},
    CurrentTargetGen = nil, UIOpen = true,
    CrosshairGui = nil,
    InvisOriginalCF = nil, InvisVoidY = 9000,

    FloatingLogo         = true,
    LogoGui              = nil,
    LogoImage            = nil,
    LogoSize             = 60,
    LogoTransparency     = 0.1,
    LogoInitialized      = false,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        Fluent:Notify({ Title=tostring(t), Content=tostring(c), Duration=tonumber(d) or 3 })
    end)
end
local function Char() return LocalPlayer.Character end
local function HRP()  local c = Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum()  local c = Char(); return c and c:FindFirstChildOfClass("Humanoid") end

local function LerpColor(c1,c2,t)
    return Color3.new(c1.R+(c2.R-c1.R)*t,c1.G+(c2.G-c1.G)*t,c1.B+(c2.B-c1.B)*t)
end
local function GetGradientColor(pct)
    if pct<=0.5 then return LerpColor(Color3.fromRGB(180,60,220),Color3.fromRGB(255,220,60),pct*2)
    else return LerpColor(Color3.fromRGB(255,220,60),Color3.fromRGB(60,220,60),(pct-0.5)*2) end
end
local function GetHealthColor(pct)
    if pct>0.6 then return Color3.fromRGB(60,220,60)
    elseif pct>0.3 then return Color3.fromRGB(255,180,60)
    else return Color3.fromRGB(255,50,50) end
end

local function GetAllOtherPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    return list
end

local function GetMyPos()
    if State.Invisible and State.InvisOriginalCF then return State.InvisOriginalCF.Position end
    local hrp = HRP(); return hrp and hrp.Position or nil
end

-- ═══════════════════════════════════════════════════════════════
-- VISUALS ENGINE (auto-persistent)
-- ═══════════════════════════════════════════════════════════════
local Vis = {}
local LB  = {}

function Vis.Backup()
    if next(LB) then return end
    LB = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
    }
end

function Vis.Restore()
    for k, v in pairs(LB) do pcall(function() Lighting[k] = v end) end
end

function Vis.ApplyFullBright()
    if not State.FullBright then return end
    pcall(function()
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2; Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    end)
end

function Vis.ApplyNoFog()
    if not State.NoFog then return end
    pcall(function() Lighting.FogEnd = 999999; Lighting.FogStart = 999999 end)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
        end
    end
end

function Vis.ApplyNoShadows()
    if not State.NoShadows then return end
    pcall(function() Lighting.GlobalShadows = false end)
end

function Vis.ApplyAll()
    if State.FullBright then Vis.ApplyFullBright() end
    if State.NoFog      then Vis.ApplyNoFog()      end
    if State.NoShadows  then Vis.ApplyNoShadows()  end
end

function Vis.FullBright(e)
    Vis.Backup(); State.FullBright = e
    if e then Vis.ApplyFullBright() else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup(); State.NoFog = e
    if e then Vis.ApplyNoFog() else pcall(function() Lighting.FogEnd = LB.FogEnd or 100000 end) end
end
function Vis.NoShadows(e)
    Vis.Backup(); State.NoShadows = e
    pcall(function() Lighting.GlobalShadows = not e end)
end
function Vis.UnlimitedZoom(e)
    LocalPlayer.CameraMaxZoomDistance = e and math.huge or 128
    LocalPlayer.CameraMinZoomDistance = 0.5
end
function Vis.SetCrosshair(e)
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end); State.CrosshairGui = nil end
    if not e then return end
    local sg = Instance.new("ScreenGui"); sg.Name = "X0_Cross"
    sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true; sg.Parent = GuiParent()
    local dot = Instance.new("Frame", sg)
    dot.Size = UDim2.new(0, 4, 0, 4); dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50); dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    State.CrosshairGui = sg
end

-- Auto-persistence hooks
CM:Add(Lighting.Changed, function(prop)
    if prop == "FogEnd" or prop == "FogStart" or prop == "FogColor" then
        if State.NoFog then Vis.ApplyNoFog() end
    elseif prop == "GlobalShadows" then
        if State.NoShadows then pcall(function() Lighting.GlobalShadows = false end) end
    elseif prop == "Ambient" or prop == "OutdoorAmbient" or prop == "Brightness" or prop == "ClockTime" then
        if State.FullBright then Vis.ApplyFullBright() end
    end
end)

CM:Add(Lighting.DescendantAdded, function(obj)
    task.wait(0.1)
    if obj:IsA("Atmosphere") and State.NoFog then
        pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
        CM:Add(obj.Changed, function()
            if State.NoFog then
                pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
            end
        end)
    end
end)

for _, obj in ipairs(Lighting:GetDescendants()) do
    if obj:IsA("Atmosphere") then
        CM:Add(obj.Changed, function()
            if State.NoFog then
                pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
            end
        end)
    end
end

CM:Add(Workspace.ChildAdded, function(child)
    if child.Name == "Map" or child.Name == "Match" or child.Name == "Round" then
        task.wait(1)
        Vis.ApplyAll()
        Notify("Auto Visuals", "Re-applied for new match", 2)
    end
end)

task.spawn(function()
    while task.wait(1.5) do pcall(function() Vis.ApplyAll() end) end
end)

-- ═══════════════════════════════════════════════════════════════
-- SMALL FPS + PING HUD (compact overlay)
-- ═══════════════════════════════════════════════════════════════
local FPSCounter = {}

local function DestroyFPS()
    if State.FPSGui then pcall(function() State.FPSGui:Destroy() end) end
    State.FPSGui = nil; State.FPSLabel = nil
end

function FPSCounter.Build()
    DestroyFPS()
    local gp = GuiParent()
    if not gp then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_FPS"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 998
    sg.Parent = gp

    -- SMALL compact overlay: just two tiny stacked labels
    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0, 68, 0, 26)          -- much smaller than before
    frame.Position = UDim2.new(0, 8, 0, 8)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    frame.BackgroundTransparency = 0.35
    frame.BorderSizePixel = 0

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(60, 60, 75)
    stroke.Thickness = 1; stroke.Transparency = 0.5

    -- FPS label (top row)
    local fpsLbl = Instance.new("TextLabel", frame)
    fpsLbl.Size = UDim2.new(1, -6, 0, 12)
    fpsLbl.Position = UDim2.new(0, 3, 0, 1)
    fpsLbl.BackgroundTransparency = 1
    fpsLbl.Text = "-- fps"
    fpsLbl.TextColor3 = Color3.fromRGB(120, 240, 120)
    fpsLbl.Font = Enum.Font.GothamBold
    fpsLbl.TextSize = 10                          -- tiny
    fpsLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Ping label (bottom row)
    local pingLbl = Instance.new("TextLabel", frame)
    pingLbl.Size = UDim2.new(1, -6, 0, 12)
    pingLbl.Position = UDim2.new(0, 3, 0, 13)
    pingLbl.BackgroundTransparency = 1
    pingLbl.Text = "-- ms"
    pingLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    pingLbl.Font = Enum.Font.Gotham
    pingLbl.TextSize = 10                         -- tiny
    pingLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Draggable
    local dragging, dragStart, startPos = false, Vector2.zero, UDim2.new()
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                        startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    State.FPSGui = sg
    State.FPSLabel = { fps = fpsLbl, ping = pingLbl }
end

local function GetPingMs()
    local ok, ping = pcall(function()
        return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    return ok and ping or 0
end

CM:Add(RunService.RenderStepped, function(dt)
    if not State.FPSCounter or not State.FPSLabel then return end
    State.FPSFrames = State.FPSFrames + 1
    local now = tick()
    if now - State.FPSLastUpdate >= 0.5 then
        local elapsed = now - State.FPSLastUpdate
        State.FPSValue = math.floor(State.FPSFrames / elapsed)
        State.FPSFrames = 0
        State.FPSLastUpdate = now
        State.FPSPingValue = GetPingMs()

        pcall(function()
            State.FPSLabel.fps.Text = State.FPSValue .. " fps"
            if State.FPSValue >= 55 then
                State.FPSLabel.fps.TextColor3 = Color3.fromRGB(120, 240, 120)
            elseif State.FPSValue >= 30 then
                State.FPSLabel.fps.TextColor3 = Color3.fromRGB(255, 210, 100)
            else
                State.FPSLabel.fps.TextColor3 = Color3.fromRGB(255, 90, 90)
            end

            State.FPSLabel.ping.Text = State.FPSPingValue .. " ms"
            if State.FPSPingValue < 100 then
                State.FPSLabel.ping.TextColor3 = Color3.fromRGB(160, 240, 200)
            elseif State.FPSPingValue < 250 then
                State.FPSLabel.ping.TextColor3 = Color3.fromRGB(255, 210, 100)
            else
                State.FPSLabel.ping.TextColor3 = Color3.fromRGB(255, 90, 90)
            end
        end)
    end
end)

function FPSCounter.SetVisible(v)
    State.FPSCounter = v
    if v then FPSCounter.Build() else DestroyFPS() end
end

-- ═══════════════════════════════════════════════════════════════
-- FLOATING LOGO (new asset)
-- ═══════════════════════════════════════════════════════════════
local FloatingLogo = {}

local function DestroyLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local gp = GuiParent()
    if gp then
        for _, child in ipairs(gp:GetChildren()) do
            if child.Name == "X0_Logo" then pcall(function() child:Destroy() end) end
        end
    end
    State.LogoGui = nil; State.LogoImage = nil
end

function FloatingLogo.Build()
    DestroyLogo()
    local gp = GuiParent()
    if not gp then Log("[Logo] No GUI parent!"); return false end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Logo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 999999
    sg.Enabled = true
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
    img.Image = HUB.LogoId    -- Uses new 85855925276969
    img.ImageTransparency = State.LogoTransparency
    img.ScaleType = Enum.ScaleType.Fit
    img.AutoButtonColor = false
    img.Active = true; img.Selectable = true; img.Visible = true
    img.ZIndex = 100
    img.Parent = sg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 10)

    local dragging, dragStart, startPos, dragMoved = false, Vector2.zero, UDim2.new(), false
    img.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position
            startPos = img.Position; dragMoved = false
        end
    end)
    img.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            if d.Magnitude > 4 then dragMoved = true end
            img.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    img.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    img.MouseButton1Click:Connect(function()
        if dragMoved then return end
        pcall(function()
            local h = _G[INSTANCE_KEY]
            if h and h.window and h.window.Minimize then h.window:Minimize() end
        end)
    end)

    State.LogoGui = sg; State.LogoImage = img; State.LogoInitialized = true
    return true
end

function FloatingLogo.SetVisible(v)
    State.FloatingLogo = v
    if v then FloatingLogo.Build() else DestroyLogo() end
end
function FloatingLogo.SetSize(sz)
    State.LogoSize = sz
    if State.LogoImage then State.LogoImage.Size = UDim2.new(0, sz, 0, sz) end
end
function FloatingLogo.SetTransparency(a)
    State.LogoTransparency = a
    if State.LogoImage then State.LogoImage.ImageTransparency = a end
end

task.spawn(function()
    pcall(function() ContentProvider:PreloadAsync({HUB.LogoId}) end)
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name="X0_ESP"; ESPGui.ResetOnSpawn=false
    ESPGui.IgnoreGuiInset=true; ESPGui.DisplayOrder=999
    ESPGui.Parent=GuiParent()
end

local function GetRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj:FindFirstChild("HitBox")
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChild("UpperTorso")
            or obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart")
    end
end

local function MakeEntry(obj, label, color, isChar, kind, hlOnly)
    local rp = GetRootPart(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency=isChar and 0.5 or 0.6; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=Workspace
    if hlOnly then return {rp=rp,obj=obj,hl=hl,bb=nil,nl=nil,dl=nil,hp=nil,isChar=isChar,color=color,kind=kind} end
    local bb=Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,200,0,isChar and 55 or 40)
    bb.StudsOffset=Vector3.new(0,isChar and 2.5 or 2,0)
    bb.AlwaysOnTop=true; bb.LightInfluence=0
    bb.MaxDistance=State.ESP_MaxDistance; bb.Adornee=rp; bb.Parent=ESPGui
    Instance.new("UIListLayout",bb).HorizontalAlignment=Enum.HorizontalAlignment.Center
    local nl=Instance.new("TextLabel",bb)
    nl.Size=UDim2.new(1,0,0,18); nl.BackgroundTransparency=1
    nl.Text=label; nl.TextColor3=color
    nl.TextStrokeTransparency=0.3; nl.Font=Enum.Font.GothamBold; nl.TextSize=13
    local hp=nil
    if isChar then
        hp=Instance.new("TextLabel",bb)
        hp.Size=UDim2.new(1,0,0,14); hp.BackgroundTransparency=1
        hp.Text="[HP] ?"; hp.TextColor3=Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency=0.3; hp.Font=Enum.Font.GothamBold; hp.TextSize=12
    end
    local dl=Instance.new("TextLabel",bb)
    dl.Size=UDim2.new(1,0,0,12); dl.BackgroundTransparency=1
    dl.Text="0m"; dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency=0.3; dl.Font=Enum.Font.Gotham; dl.TextSize=11
    return {rp=rp,obj=obj,hl=hl,bb=bb,nl=nl,dl=dl,hp=hp,isChar=isChar,color=color,kind=kind}
end

function ESP.Add(obj,label,color,isChar,kind,hlOnly)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e=MakeEntry(obj,label,color,isChar or false,kind,hlOnly)
    if e then State.ESPCache[obj]=e end
end
function ESP.Remove(obj)
    local e=State.ESPCache[obj]; if not e then return end
    if e.hl then pcall(function() e.hl:Destroy() end) end
    if e.bb then pcall(function() e.bb:Destroy() end) end
    State.ESPCache[obj]=nil
end
function ESP.ClearAll()
    for o in pairs(State.ESPCache) do ESP.Remove(o) end
    State.ESPCache={}
end

local ESPRender = RunService.RenderStepped:Connect(function()
    local refPos
    if State.Invisible and State.InvisOriginalCF then refPos=Camera.CFrame.Position
    else local hrp=HRP(); refPos=hrp and hrp.Position or Vector3.zero end
    local rem={}
    for obj,e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then table.insert(rem,obj)
        else
            local rp=GetRootPart(obj)
            if not rp then table.insert(rem,obj)
            else
                if e.rp~=rp then
                    e.rp=rp
                    pcall(function() e.hl.Adornee=obj; if e.bb then e.bb.Adornee=rp end end)
                end
                local dist=(rp.Position-refPos).Magnitude
                local vis=dist<=State.ESP_MaxDistance
                pcall(function()
                    e.hl.Enabled=vis
                    if e.bb then
                        e.bb.MaxDistance=State.ESP_MaxDistance
                        e.bb.Enabled=vis
                        if e.dl then
                            e.dl.Text=math.floor(dist).."m"
                            e.dl.Visible=State.ESP_Distance
                        end
                    end
                end)

                if e.isChar and e.hp then
                    pcall(function()
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h then
                            local hp = math.floor(h.Health)
                            local mx = math.floor(h.MaxHealth)
                            local pct = (mx > 0) and hp/mx or 0
                            e.hp.Text = "[HP] " .. hp .. "/" .. mx
                            e.hp.TextColor3 = GetHealthColor(pct)
                            e.hp.Visible = State.ESP_HealthBar

                            if e.kind == "player" then
                                if e.isKiller then
                                    e.hl.FillColor = KILLER_RED
                                    e.hl.OutlineColor = KILLER_RED
                                    if e.nl then e.nl.TextColor3 = KILLER_RED end
                                else
                                    local hc = GetHealthColor(pct)
                                    e.hl.FillColor = hc
                                    e.hl.OutlineColor = hc
                                    if e.nl then e.nl.TextColor3 = hc end
                                end
                            end
                        end
                    end)
                end

                if e.kind=="generator" and obj:IsA("Model") and e.nl then
                    pcall(function()
                        local prog = obj:GetAttribute("RepairProgress") or 0
                        local col = GetGradientColor(prog/100)
                        e.hl.FillColor = col
                        e.hl.OutlineColor = col
                        e.nl.TextColor3 = col
                        e.nl.Text = "[GEN] " .. math.floor(prog) .. "%"
                    end)
                end
            end
        end
    end
    for _,o in ipairs(rem) do ESP.Remove(o) end
end)

function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            if State.ESP_Player then
                if not State.ESPCache[p.Character] then
                    local isKiller = IsPlayerKiller(p, p.Character)
                    local col = isKiller and KILLER_RED or State.Color_Player
                    local label = isKiller and ("[KILLER] " .. p.Name) or ("[" .. p.Name .. "]")
                    ESP.Add(p.Character, label, col, true, "player", false)
                    local entry = State.ESPCache[p.Character]
                    if entry then
                        entry.isKiller = isKiller
                        entry.baseColor = col
                        entry.playerRef = p
                    end
                end
            else
                if State.ESPCache[p.Character] then ESP.Remove(p.Character) end
            end
        end
    end
end

function ESP.ScanZombies()
    local z=GetZombies(); local m={}; for _,v in ipairs(z) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="zombie" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(z) do
        if State.ESP_Zombie then if not State.ESPCache[v] then ESP.Add(v,"[CURE] "..v.Name,State.Color_Zombie,true,"zombie",false) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanGens()
    local g=FindAllGenerators(); local m={}; for _,v in ipairs(g) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="generator" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(g) do
        if State.ESP_Generator then if not State.ESPCache[v] then local p=v:GetAttribute("RepairProgress") or 0; ESP.Add(v,"[GEN] "..math.floor(p).."%",GetGradientColor(p/100),false,"generator",false) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanPallets()
    local p=GetPallets(); local m={}; for _,v in ipairs(p) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="pallet" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(p) do
        if State.ESP_Pallet then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Pallet,false,"pallet",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanVaults()
    local w=GetVaults(); local m={}; for _,v in ipairs(w) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="vault" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(w) do
        if State.ESP_Vault then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Vault,false,"vault",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanExits()
    local e=GetExits(); local m={}; for _,v in ipairs(e) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="exit" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(e) do
        if State.ESP_Exit then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Exit,false,"exit",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers(); ESP.ScanZombies(); ESP.ScanGens()
    ESP.ScanPallets(); ESP.ScanVaults(); ESP.ScanExits()
end

task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            for obj, entry in pairs(State.ESPCache) do
                if entry.kind == "player" and obj.Parent then
                    local plr = entry.playerRef
                    if not plr or plr.Character ~= obj then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Character == obj then plr = p; break end
                        end
                        entry.playerRef = plr
                    end
                    if plr then
                        local nowKiller = IsPlayerKiller(plr, obj)
                        if nowKiller ~= entry.isKiller then
                            entry.isKiller = nowKiller
                            if entry.nl then
                                entry.nl.Text = nowKiller and ("[KILLER] " .. plr.Name) or ("[" .. plr.Name .. "]")
                            end
                        end
                    end
                end
            end
            ESP.RefreshAll()
        end)
    end
end)

CM:Add(Players.PlayerRemoving, function(p) if p.Character then ESP.Remove(p.Character) end end)
local function HookPlayer(p)
    if p==LocalPlayer then return end
    CM:Add(p.CharacterAdded, function() task.wait(0.5); ESP.RefreshAll() end)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c) end)
    CM:Add(p:GetAttributeChangedSignal("Role"), function()
        if p.Character and State.ESPCache[p.Character] then
            local entry = State.ESPCache[p.Character]
            local nowKiller = IsPlayerKiller(p, p.Character)
            entry.isKiller = nowKiller
            if entry.nl then
                entry.nl.Text = nowKiller and ("[KILLER] " .. p.Name) or ("[" .. p.Name .. "]")
            end
        end
    end)
    CM:Add(p:GetAttributeChangedSignal("IsKiller"), function()
        if p.Character and State.ESPCache[p.Character] then
            local entry = State.ESPCache[p.Character]
            local nowKiller = IsPlayerKiller(p, p.Character)
            entry.isKiller = nowKiller
            if entry.nl then
                entry.nl.Text = nowKiller and ("[KILLER] " .. p.Name) or ("[" .. p.Name .. "]")
            end
        end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
CM:Add(Players.PlayerAdded, HookPlayer)

-- ═══════════════════════════════════════════════════════════════
-- ESP HOOK
-- ═══════════════════════════════════════════════════════════════
local function IsWallCandidate(part)
    if not part:IsA("BasePart") then return false end
    if part.Transparency >= 0.95 then return false end
    if part:IsDescendantOf(Camera) then return false end
    local model = part:FindFirstAncestorOfClass("Model")
    if model then
        if model:FindFirstChildOfClass("Humanoid") then return false end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character == model then return false end
        end
    end
    if part == Workspace.Terrain then return false end
    local n = (part.Name or ""):lower()
    if n:find("wall") or n:find("building") or n:find("house")
        or n:find("roof") or n:find("floor") or n:find("ceiling")
        or n:find("door") or n:find("side") or n:find("panel") then return true end
    local s = part.Size
    local minA = math.min(s.X, s.Y, s.Z); local maxA = math.max(s.X, s.Y, s.Z)
    if minA < 3 and maxA > 10 then return true end
    return false
end

local function ApplyESPHook()
    for _, entry in ipairs(State.ESP_HookOriginals) do
        if entry.part and entry.part.Parent then
            pcall(function() entry.part.Transparency = entry.origT end)
        end
    end
    State.ESP_HookOriginals = {}
    if not State.ESP_Hook then return end
    local mode = State.ESP_HookMode
    local targetTrans = math.clamp(State.ESP_HookTransparency, 0, 1)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local shouldModify = false
            if mode == "Everything" then
                if obj.Transparency < 0.9 then
                    local model = obj:FindFirstAncestorOfClass("Model")
                    local isChar = false
                    if model and model:FindFirstChildOfClass("Humanoid") then isChar = true end
                    if not isChar then shouldModify = true end
                end
            elseif mode == "Walls" then
                shouldModify = IsWallCandidate(obj)
            end
            if shouldModify then
                table.insert(State.ESP_HookOriginals, {part=obj, origT=obj.Transparency})
                pcall(function() obj.Transparency = targetTrans end)
            end
        end
    end
end

local function SetESPHook(enable)
    State.ESP_Hook = enable
    if State.ESP_HookConn then pcall(function() State.ESP_HookConn:Disconnect() end); State.ESP_HookConn = nil end
    if not enable then
        for _, entry in ipairs(State.ESP_HookOriginals) do
            if entry.part and entry.part.Parent then
                pcall(function() entry.part.Transparency = entry.origT end)
            end
        end
        State.ESP_HookOriginals = {}
        Notify("ESP Hook", "OFF", 2); return
    end
    ApplyESPHook()
    State.ESP_HookConn = Workspace.DescendantAdded:Connect(function(obj)
        if not State.ESP_Hook then return end
        task.wait(0.2)
        if obj:IsA("BasePart") then
            local shouldModify = false
            if State.ESP_HookMode == "Everything" then
                if obj.Transparency < 0.9 then
                    local model = obj:FindFirstAncestorOfClass("Model")
                    if not (model and model:FindFirstChildOfClass("Humanoid")) then shouldModify = true end
                end
            elseif State.ESP_HookMode == "Walls" then
                shouldModify = IsWallCandidate(obj)
            end
            if shouldModify then
                table.insert(State.ESP_HookOriginals, {part=obj, origT=obj.Transparency})
                pcall(function() obj.Transparency = State.ESP_HookTransparency end)
            end
        end
    end)
    Notify("ESP Hook", "ON", 3)
end

-- ═══════════════════════════════════════════════════════════════
-- TELEPORT TO PLAYER
-- ═══════════════════════════════════════════════════════════════
local AutoFollowConn=nil
local function GetPlayerNames()
    local n={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(n,p.Name) end end
    if #n==0 then table.insert(n,"None") end; return n
end
local function FindPlayerByName(name)
    if not name or name=="None" then return nil end; return Players:FindFirstChild(name)
end
local function TeleportToPlayer(target,offset)
    if not target then return false end
    local p=FindPlayerByName(target); if not p or not p.Character then return false end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); if not prp then return false end
    local hrp=HRP(); if not hrp then return false end
    local dest=prp.CFrame+(offset or Vector3.zero)
    if State.Invisible then
        State.InvisOriginalCF=dest
        pcall(function() hrp.CFrame=dest; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
        task.delay(0.05,function()
            if State.Invisible then pcall(function() hrp.CFrame=CFrame.new(0,State.InvisVoidY,0); hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end) end
        end)
    else pcall(function() hrp.CFrame=dest; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end) end
    return true
end
local function SetAutoFollow(enable)
    if AutoFollowConn then pcall(function() AutoFollowConn:Disconnect() end); AutoFollowConn=nil end
    if not enable then State.AutoFollowEnabled=false; return end
    State.AutoFollowEnabled=true; local last=0
    AutoFollowConn=RunService.Heartbeat:Connect(function()
        if not State.AutoFollowEnabled or not State.AutoFollowTarget then return end
        if tick()-last<0.1 then return end; last=tick()
        pcall(TeleportToPlayer,State.AutoFollowTarget,State.AutoFollowOffset)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT / INVISIBLE / OTHER FEATURES
-- ═══════════════════════════════════════════════════════════════
local function SetWalkSpeed(e) local h=Hum(); if h then h.WalkSpeed=e and State.WalkSpeedValue or State.WalkSpeed end end
local function SetKillerWalkSpeed(e) local h=Hum(); if h then h.WalkSpeed=e and State.KillerWalkSpeedValue or State.WalkSpeed end end
local function SetNoFall(e)
    local c=Char(); if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,not e); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,not e) end)
end

local InvisHB,InvisRS,InvisMV=nil,nil,nil
local VOID_Y,VOID_THRESH=9000,150
local InvisCam={pitch=0,yaw=0}
local function DisconnectInvis()
    if InvisHB then pcall(function() InvisHB:Disconnect() end); InvisHB=nil end
    if InvisRS then pcall(function() InvisRS:Disconnect() end); InvisRS=nil end
    if InvisMV then pcall(function() InvisMV:Disconnect() end); InvisMV=nil end
end
local function SetInvisible(enable)
    DisconnectInvis()
    local char,hrp,hum=Char(),HRP(),Hum()
    if not enable then
        State.Invisible=false
        if State.InvisOriginalCF and hrp then
            pcall(function() hrp.Anchored=false; hrp.CFrame=State.InvisOriginalCF; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
        end
        State.InvisOriginalCF=nil
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        if char then local head=char:FindFirstChild("Head"); if head then for _,g in ipairs(head:GetChildren()) do if g:IsA("BillboardGui") then pcall(function() g.Enabled=true end) end end end end
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,true); hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true); hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true); hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true) end) end
        Notify("Invisible","OFF",2); return
    end
    if not char or not hrp or not hum then State.Invisible=false; Notify("Invisible","No character",2); return end
    State.Invisible=true; State.InvisOriginalCF=hrp.CFrame
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false); hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end)
    local head=char:FindFirstChild("Head"); if head then for _,g in ipairs(head:GetChildren()) do if g:IsA("BillboardGui") then pcall(function() g.Enabled=false end) end end end
    local lv=Camera.CFrame.LookVector; InvisCam.pitch=math.asin(math.clamp(-lv.Y,-1,1)); InvisCam.yaw=math.atan2(-lv.X,-lv.Z)
    pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end)
    pcall(function() hrp.CFrame=CFrame.new(0,VOID_Y,0); hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
    InvisRS=RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end
        if Camera.CameraType~=Enum.CameraType.Scriptable then pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end) end
        local d=UserInputService:GetMouseDelta()
        InvisCam.yaw=InvisCam.yaw-math.rad(d.X*0.35)
        InvisCam.pitch=math.clamp(InvisCam.pitch-math.rad(d.Y*0.35),math.rad(-80),math.rad(80))
        if State.InvisOriginalCF then
            pcall(function() Camera.CFrame=CFrame.new(State.InvisOriginalCF.Position+Vector3.new(0,1.5,0))*CFrame.Angles(0,InvisCam.yaw,0)*CFrame.Angles(InvisCam.pitch,0,0) end)
        end
    end)
    InvisMV=RunService.Heartbeat:Connect(function(dt)
        if not State.Invisible or not State.InvisOriginalCF or IsTyping() then return end
        local spd=State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed; local md=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md+Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md+Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+Vector3.new(1,0,0) end
        if md.Magnitude>0.1 then
            md=md.Unit; local wd=CFrame.Angles(0,InvisCam.yaw,0)*md
            local cur=State.InvisOriginalCF.Position; local nxt=cur+wd*spd*dt
            State.InvisOriginalCF=CFrame.new(Vector3.new(nxt.X,cur.Y,nxt.Z))*CFrame.Angles(0,InvisCam.yaw,0)
        end
    end)
    InvisHB=RunService.Heartbeat:Connect(function()
        if not State.Invisible then return end
        local rp,hm=HRP(),Hum(); if not rp or not hm then return end
        local pos=rp.Position
        if math.abs(pos.Y-VOID_Y)>VOID_THRESH or math.abs(pos.X)>200 or math.abs(pos.Z)>200 then
            pcall(function() rp.CFrame=CFrame.new(0,VOID_Y,0); rp.AssemblyLinearVelocity=Vector3.zero; rp.AssemblyAngularVelocity=Vector3.zero end)
        end
        pcall(function() if hm.Health<hm.MaxHealth then hm.Health=hm.MaxHealth end; hm:SetStateEnabled(Enum.HumanoidStateType.Dead,false) end)
    end)
    Notify("Invisible","ON",3)
end

local UnlockCursorConn=nil
local function SetUnlockCursor(e)
    if UnlockCursorConn then pcall(function() UnlockCursorConn:Disconnect() end); UnlockCursorConn=nil end
    if not e then pcall(function() UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true end); return end
    UnlockCursorConn=RunService.RenderStepped:Connect(function()
        if State.UnlockCursor and UserInputService.MouseBehavior~=Enum.MouseBehavior.Default then
            pcall(function() UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true end)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO HEAL (FIXED - fires every possible heal remote + skillcheck bypass)
-- ═══════════════════════════════════════════════════════════════
--[[
    WHY THE OLD ONE DIDN'T WORK
    ═══════════════════════════
    The previous code only fired R.Heal:FireServer() with no args, but
    Violence District's heal event usually needs:
      - self reference (the local character)
      - "Perfect" skillcheck confirmation
      - or requires a Progress/Start event before the actual heal

    THE FIX
    ═══════
    1. Fires EVERY heal-related remote we can find, with multiple
       argument combinations.
    2. Sends "Perfect" skillcheck on both Gen + Heal channels.
    3. Also fires medkit / adrenaline remotes so healing items work.
    4. Sets the character's "healing" attribute to trigger animation
       and repeatedly bumps humanoid.Health for backup.
]]

local AutoHealConn = nil
local function FireHealRemotes()
    local char = Char()
    if not char then return end

    -- Try every heal remote variant with multiple argument styles
    local healRemotes = {
        R.Heal, R.HealCommit, R.HealSelf, R.HealPlayer,
        R.HealStart, R.HealFinish, R.MedKit,
    }
    for _, rem in ipairs(healRemotes) do
        if rem then
            pcall(function()
                if rem:IsA("RemoteEvent") then
                    -- Try multiple arg combinations
                    rem:FireServer()
                    rem:FireServer(LocalPlayer)
                    rem:FireServer(char)
                    rem:FireServer(LocalPlayer, char)
                    rem:FireServer("Perfect")
                    rem:FireServer(LocalPlayer, "Perfect")
                elseif rem:IsA("RemoteFunction") then
                    rem:InvokeServer()
                    rem:InvokeServer(LocalPlayer)
                    rem:InvokeServer(char)
                end
            end)
        end
    end

    -- Skillcheck bypass on heal channel
    if R.SkillCheck.HealResult then
        pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end)
        pcall(function() R.SkillCheck.HealResult:FireServer(LocalPlayer, "Perfect") end)
    end
    if R.SkillCheck.GenResult then
        pcall(function() R.SkillCheck.GenResult:FireServer("Perfect") end)
    end

    -- Adrenaline shot
    local adrenRemotes = { R.AdrenalineHealthy, R.AdrenalineInject, R.AdrenalineUse }
    for _, rem in ipairs(adrenRemotes) do
        if rem then
            pcall(function()
                if rem:IsA("RemoteEvent") then
                    rem:FireServer()
                    rem:FireServer(LocalPlayer)
                    rem:FireServer(char)
                elseif rem:IsA("RemoteFunction") then
                    rem:InvokeServer()
                end
            end)
        end
    end

    -- Set attributes that some games use
    pcall(function()
        char:SetAttribute("Healing", true)
        char:SetAttribute("IsHealing", true)
        char:SetAttribute("Health", char:FindFirstChildOfClass("Humanoid").MaxHealth)
    end)
end

local function SetAutoHeal(e)
    if AutoHealConn then pcall(function() AutoHealConn:Disconnect() end); AutoHealConn = nil end
    if not e then return end

    Log("[Heal] Auto Heal ENABLED - remotes: " ..
        tostring(R.Heal and "Heal" or "-") .. " | " ..
        tostring(R.AdrenalineHealthy and "Adren" or "-") .. " | " ..
        tostring(R.SkillCheck.HealResult and "SC" or "-"))

    AutoHealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        local c = Char(); if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
        if h.Health <= 0 then return end

        local pct = (h.MaxHealth > 0) and (h.Health / h.MaxHealth * 100) or 100
        if pct >= State.AutoHealThreshold then return end
        if tick() - State.LastHealTime < State.HealCooldown then return end
        State.LastHealTime = tick()

        FireHealRemotes()
    end)
end

-- Manual heal button helper
local function ForceHealNow()
    FireHealRemotes()
    -- Backup: try to set humanoid health directly (works in some games)
    local h = Hum()
    if h then pcall(function() h.Health = h.MaxHealth end) end
    Notify("Heal", "Forced all heal remotes", 2)
end

-- ═══════════════════════════════════════════════════════════════
-- REMOVE SKILLCHECK
-- ═══════════════════════════════════════════════════════════════
local RemoveSCConn=nil
local function SetRemoveSkillcheck(e)
    if RemoveSCConn then pcall(function() RemoveSCConn:Disconnect() end); RemoveSCConn=nil end
    if not e then local ch=Char(); if ch then for _,n in ipairs({"Skillcheck-gen","Skillcheck-player"}) do local s=ch:FindFirstChild(n); if s then pcall(function() s.Disabled=false end) end end end; return end
    RemoveSCConn=RunService.Heartbeat:Connect(function()
        if not State.RemoveSkillcheck then return end
        local ch=Char(); if ch then for _,n in ipairs({"Skillcheck-gen","Skillcheck-player"}) do local s=ch:FindFirstChild(n); if s and not s.Disabled then pcall(function() s.Disabled=true end) end end end
        local pg=LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _,gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local gn=gui.Name:lower()
                if gn:find("skillcheck") or gn:find("skill_check") then
                    if R.SkillCheck.GenResult then pcall(function() R.SkillCheck.GenResult:FireServer("Perfect") end) end
                    if R.SkillCheck.HealResult then pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end) end
                    pcall(function() gui.Enabled=false end)
                end
            end
        end
    end)
end

local function SetAutoGenRush(enable)
    if not enable then return end
    if not R.Gen.RepairEvent then Notify("Auto Gen","Missing remote",4); State.AutoGenRush = false; return end
    spawn(function()
        while State.AutoGenRush do
            wait(0.3)
            local myPos = GetMyPos()
            if myPos then
                local playerNear = false
                for _, p in ipairs(GetAllOtherPlayers()) do
                    local pc = p.Character
                    if pc then
                        local ph = pc:FindFirstChild("HumanoidRootPart")
                        if ph and (ph.Position - myPos).Magnitude <= State.GenKillerRadius then
                            State.CurrentTargetGen = nil; playerNear = true; break
                        end
                    end
                end
                if not playerNear then
                    if State.CurrentTargetGen then
                        local progress = State.CurrentTargetGen:GetAttribute("RepairProgress") or 0
                        if progress >= 100 or not State.CurrentTargetGen.Parent then State.CurrentTargetGen = nil end
                    end
                    if not State.CurrentTargetGen then
                        local best, bestDist = nil, math.huge
                        for _, g in ipairs(FindAllGenerators()) do
                            local progress = g:GetAttribute("RepairProgress") or 0
                            if progress < 100 then
                                local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
                                if hb then
                                    local dist = (hb.Position - myPos).Magnitude
                                    if dist < bestDist then bestDist = dist; best = g end
                                end
                            end
                        end
                        State.CurrentTargetGen = best
                    end
                    if State.CurrentTargetGen then
                        local hb = State.CurrentTargetGen:FindFirstChild("HitBox") or State.CurrentTargetGen:FindFirstChildWhichIsA("BasePart")
                        local point = State.CurrentTargetGen:FindFirstChild("GeneratorPoint1")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")
                        if hb and (hb.Position - myPos).Magnitude <= 8 then
                            pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point) end)
                        end
                    end
                end
            end
        end
        State.CurrentTargetGen = nil
    end)
end

local function SetFastVault(e) local ch=Char(); if ch then pcall(function() ch:SetAttribute("vaultspeed",e and 5 or 1) end) end end

local function FireHit(target)
    local ch=target and target.Character; if not ch then return end
    if R.Attacks.Basic      then pcall(function() R.Attacks.Basic:FireServer(target,ch) end) end
    if R.Attacks.Hit        then pcall(function() R.Attacks.Hit:FireServer(target,ch) end) end
    if R.AttackEvent        then pcall(function() R.AttackEvent:FireServer(target) end) end
    if R.KingScourge        then pcall(function() R.KingScourge:FireServer(target) end) end
    if R.Killers.Frenzy     then pcall(function() R.Killers.Frenzy:FireServer(target) end) end
    if R.Killers.Masked     then pcall(function() R.Killers.Masked:FireServer(target) end) end
    if R.Killers.SlowAttack then pcall(function() R.Killers.SlowAttack:FireServer(target) end) end
    if R.Killers.CureInject then pcall(function() R.Killers.CureInject:FireServer(target) end) end
end

local AutoHitConn=nil
local function SetAutoHit(e)
    if AutoHitConn then pcall(function() AutoHitConn:Disconnect() end); AutoHitConn=nil end
    if not e then return end; local last=0
    AutoHitConn=RunService.Heartbeat:Connect(function()
        if not State.AutoHit or tick()-last<0.3 then return end
        local hrp=HRP(); if not hrp then return end
        for _,p in ipairs(GetAllOtherPlayers()) do
            local ep=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if ep and (ep.Position-hrp.Position).Magnitude<=State.AutoHitRange then last=tick(); FireHit(p) end
        end
    end)
end

local AutoHitAllConn=nil
local function SetAutoHitAll(e)
    if AutoHitAllConn then pcall(function() AutoHitAllConn:Disconnect() end); AutoHitAllConn=nil end
    if not e then return end; local last=0
    AutoHitAllConn=RunService.Heartbeat:Connect(function()
        if not State.AutoHitAll or tick()-last<State.AutoHitAllDelay then return end; last=tick()
        for _,p in ipairs(GetAllOtherPlayers()) do pcall(FireHit,p) end
    end)
end

local AutoDamageGenConn=nil
local function SetAutoDamageGen(e)
    if AutoDamageGenConn then pcall(function() AutoDamageGenConn:Disconnect() end); AutoDamageGenConn=nil end
    if not e then return end
    AutoDamageGenConn=RunService.Heartbeat:Connect(function()
        if not State.AutoDamageGen then return end; task.wait(0.3)
        local hrp=HRP(); if not hrp then return end
        for _,g in ipairs(FindAllGenerators()) do
            local hb=g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
            if hb and (hb.Position-hrp.Position).Magnitude<=15 then
                if State.InstantDamageGen then pcall(function() hrp.CFrame=hb.CFrame+Vector3.new(0,3,0) end) end
                if R.Gen.BreakEvent then pcall(function() R.Gen.BreakEvent:FireServer(g) end) end
                if R.Gen.BreakCommit then pcall(function() R.Gen.BreakCommit:FireServer(g) end) end
            end
        end
    end)
end

local InstPalletConn=nil
local function SetInstantBreakPallet(e)
    if InstPalletConn then InstPalletConn:Disconnect(); InstPalletConn=nil end
    if not e then return end
    InstPalletConn=RunService.Heartbeat:Connect(function()
        if not State.InstantBreakPallet then return end; task.wait(0.2)
        local hrp=HRP(); if not hrp then return end
        for _,p in ipairs(GetPallets()) do
            local pt=p:FindFirstChildWhichIsA("BasePart")
            if pt and (pt.Position-hrp.Position).Magnitude<=12 then
                if R.Pallet.BreakCommit then pcall(function() R.Pallet.BreakCommit:FireServer(p) end) end
                if R.Pallet.DropCommit then pcall(function() R.Pallet.DropCommit:FireServer(p) end) end
            end
        end
    end)
end

local NoStunConn=nil
local function SetNoStun(e)
    if NoStunConn then pcall(function() NoStunConn:Disconnect() end); NoStunConn=nil end
    if not e then return end
    NoStunConn=RunService.Heartbeat:Connect(function()
        if not State.NoStun then return end; local c=Char()
        if c then pcall(function() c:SetAttribute("Knocked",false) end); if R.Pallet.Stunover then pcall(function() R.Pallet.Stunover:FireServer() end) end end
    end)
end

local NoSlowConn=nil
local function SetNoSlowdown(e)
    if NoSlowConn then pcall(function() NoSlowConn:Disconnect() end); NoSlowConn=nil end
    if not e then return end
    NoSlowConn=RunService.Heartbeat:Connect(function()
        if not State.NoSlowdown then return end
        local h=Hum(); if not h then return end
        local t=State.KillerWalkSpeedEnabled and State.KillerWalkSpeedValue or (State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed)
        if h.WalkSpeed<t-2 then pcall(function() h.WalkSpeed=t end) end
    end)
end

local function SetFPSBoost(e)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then pcall(function() v.Enabled=not e end) end
    end
    pcall(function() settings().Rendering.QualityLevel=e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
end

local function ServerHop()
    pcall(function()
        local raw=game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local ok,data=pcall(HttpService.JSONDecode,HttpService,raw)
        if ok and data and data.data then for _,s in ipairs(data.data) do if s.playing<s.maxPlayers and s.id~=game.JobId then TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer); return end end end
        Notify("Server Hop","No server found",4)
    end)
end

CM:Add(LocalPlayer.Idled,function() if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end end)

-- ═══════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════
KB.Register("WalkSpeed",Enum.KeyCode.V,function() State.WalkSpeedEnabled=not State.WalkSpeedEnabled; SetWalkSpeed(State.WalkSpeedEnabled); Notify("Walk Speed",State.WalkSpeedEnabled and "ON" or "OFF",1.5) end,true)
KB.Register("AutoHeal",Enum.KeyCode.H,function() State.AutoHeal=not State.AutoHeal; SetAutoHeal(State.AutoHeal); Notify("Auto Heal",State.AutoHeal and "ON" or "OFF",1.5) end,true)
KB.Register("Invisible",Enum.KeyCode.G,function() if not Char() then return end; State.Invisible=not State.Invisible; SetInvisible(State.Invisible) end,true)

-- ═══════════════════════════════════════════════════════════════
-- AUTO-APPLY VISUALS ON JOIN
-- ═══════════════════════════════════════════════════════════════
Vis.Backup()
task.spawn(function()
    task.wait(0.3)
    Vis.ApplyAll()
    Log("[Visuals] Auto-applied on join")
end)

-- ═══════════════════════════════════════════════════════════════
-- FLUENT UI WINDOW
-- ═══════════════════════════════════════════════════════════════
local Window = Fluent:CreateWindow({
    Title    = HUB.Name .. " v" .. HUB.Version,
    SubTitle = HUB.Game .. " | " .. HUB.Author,
    TabWidth = 160,
    Size     = UDim2.fromOffset(620, 450),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.Insert,
})

_G[INSTANCE_KEY] = { version=HUB.Version, window=Window, destroy=function() end }

local Tabs = {
    ESP      = Window:AddTab({ Title="ESP",      Icon="eye"      }),
    Survivor = Window:AddTab({ Title="Survivor", Icon="shield"   }),
    Teleport = Window:AddTab({ Title="Teleport", Icon="map-pin"  }),
    Killer   = Window:AddTab({ Title="Killer",   Icon="swords"   }),
    Visuals  = Window:AddTab({ Title="Visuals",  Icon="sun"      }),
    Misc     = Window:AddTab({ Title="Misc",     Icon="wrench"   }),
    Settings = Window:AddTab({ Title="Settings", Icon="settings" }),
}

-- ── ESP TAB ─────────────────────────────────────────────────────
Tabs.ESP:AddToggle("ESP_Player",  {Title="Player ESP (Killer = RED)", Default=false}):OnChanged(function(v) State.ESP_Player=v; ESP.RefreshAll() end)
Tabs.ESP:AddToggle("ESP_Zombie",  {Title="Zombie / Cure ESP",Default=false}):OnChanged(function(v) State.ESP_Zombie=v; ESP.ScanZombies() end)
Tabs.ESP:AddToggle("ESP_HP",      {Title="Health Bar",     Default=true}):OnChanged(function(v) State.ESP_HealthBar=v end)
Tabs.ESP:AddToggle("ESP_Dist",    {Title="Distance",       Default=true}):OnChanged(function(v) State.ESP_Distance=v end)
Tabs.ESP:AddToggle("ESP_Gen",     {Title="Generator ESP",  Default=false}):OnChanged(function(v) State.ESP_Generator=v; ESP.ScanGens() end)
Tabs.ESP:AddToggle("ESP_Pallet",  {Title="Pallet ESP",     Default=false}):OnChanged(function(v) State.ESP_Pallet=v; ESP.ScanPallets() end)
Tabs.ESP:AddToggle("ESP_Vault",   {Title="Vault ESP",      Default=false}):OnChanged(function(v) State.ESP_Vault=v; ESP.ScanVaults() end)
Tabs.ESP:AddToggle("ESP_Exit",    {Title="Exit Gate ESP",  Default=false}):OnChanged(function(v) State.ESP_Exit=v; ESP.ScanExits() end)
Tabs.ESP:AddSlider("ESP_MaxDist", {Title="Max Distance", Default=1500, Min=100, Max=3000, Rounding=0}):OnChanged(function(v) State.ESP_MaxDistance=v end)

Tabs.ESP:AddParagraph({Title="ESP Hook (See Through Walls)", Content="Makes walls transparent so you can see enemies through them."})
Tabs.ESP:AddDropdown("ESP_HookMode",{Title="Hook Mode",Values={"Walls","Everything"},Default="Walls"}):OnChanged(function(v)
    State.ESP_HookMode=v
    if State.ESP_Hook then ApplyESPHook() end
end)
Tabs.ESP:AddSlider("ESP_HookTrans",{Title="Wall Transparency %",Default=75,Min=30,Max=95,Rounding=0}):OnChanged(function(v)
    State.ESP_HookTransparency=v/100
    if State.ESP_Hook then
        for _, entry in ipairs(State.ESP_HookOriginals) do
            if entry.part and entry.part.Parent then
                pcall(function() entry.part.Transparency=State.ESP_HookTransparency end)
            end
        end
    end
end)
Tabs.ESP:AddToggle("ESP_Hook",{Title="Enable ESP Hook",Default=false}):OnChanged(function(v) SetESPHook(v) end)
Tabs.ESP:AddButton({Title="Rescan Walls", Callback=function()
    if State.ESP_Hook then ApplyESPHook(); Notify("ESP Hook", "Rescanned", 3) end
end})
Tabs.ESP:AddButton({Title="Refresh ESP", Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end})

-- ── SURVIVOR TAB ────────────────────────────────────────────────
Tabs.Survivor:AddToggle("RemoveSC",{Title="Remove Skillcheck",Default=false}):OnChanged(function(v) State.RemoveSkillcheck=v; SetRemoveSkillcheck(v) end)
Tabs.Survivor:AddSlider("GenRadius",{Title="Killer Safety Radius",Default=30,Min=10,Max=100,Rounding=0}):OnChanged(function(v) State.GenKillerRadius=v end)
Tabs.Survivor:AddDropdown("GenMode",{Title="Gen Mode",Values={"Legit","Instant"},Default="Legit"}):OnChanged(function(v) State.AutoGenMode=v end)
Tabs.Survivor:AddToggle("AutoGen",{Title="Auto Gen Rush",Default=false}):OnChanged(function(v) State.AutoGenRush=v; SetAutoGenRush(v) end)

-- HEAL SECTION
Tabs.Survivor:AddParagraph({Title="Auto Heal", Content="Fires every heal remote + adrenaline + skillcheck perfect.\nLower cooldown = faster healing but more server load."})
Tabs.Survivor:AddSlider("HealHP",{Title="Heal Below HP %",Default=60,Min=10,Max=99,Rounding=0}):OnChanged(function(v) State.AutoHealThreshold=v end)
Tabs.Survivor:AddSlider("HealCD",{Title="Heal Cooldown (sec)",Default=12,Min=3,Max=50,Rounding=0}):OnChanged(function(v) State.HealCooldown=v/10 end)
Tabs.Survivor:AddToggle("AutoHeal",{Title="Auto Heal (HH)",Default=false}):OnChanged(function(v) State.AutoHeal=v; SetAutoHeal(v) end)
Tabs.Survivor:AddButton({Title="Force Heal Now", Callback=ForceHealNow})

Tabs.Survivor:AddToggle("NoFall",{Title="No Fall Damage",Default=false}):OnChanged(function(v) State.NoFallDamage=v; SetNoFall(v) end)
Tabs.Survivor:AddSlider("WalkSpd",{Title="Walk Speed",Default=28,Min=16,Max=80,Rounding=0}):OnChanged(function(v) State.WalkSpeedValue=v; if State.WalkSpeedEnabled then SetWalkSpeed(true) end end)
Tabs.Survivor:AddToggle("WalkSpdOn",{Title="Walk Speed (VV)",Default=false}):OnChanged(function(v) State.WalkSpeedEnabled=v; SetWalkSpeed(v) end)
Tabs.Survivor:AddToggle("FastVault",{Title="Fast Vault",Default=false}):OnChanged(function(v) State.FastVault=v; SetFastVault(v) end)
Tabs.Survivor:AddToggle("Invis",{Title="Invisible (GG)",Default=false}):OnChanged(function(v) State.Invisible=v; SetInvisible(v) end)
Tabs.Survivor:AddToggle("UnlockCur",{Title="Unlock Cursor",Default=false}):OnChanged(function(v) State.UnlockCursor=v; SetUnlockCursor(v) end)

-- ── TELEPORT TAB (PLAYER ONLY) ──────────────────────────────────
local tpNames = GetPlayerNames()
local tpDrop = Tabs.Teleport:AddDropdown("TPPlayer",{Title="Select Player",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.TeleportTarget=(v=="None") and nil or v end)
Tabs.Teleport:AddButton({Title="Teleport Now",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local ok=TeleportToPlayer(State.TeleportTarget,Vector3.new(2,0,2))
    Notify("TP",ok and ("To "..State.TeleportTarget) or "Failed",3)
end})
Tabs.Teleport:AddButton({Title="Teleport Behind",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local p=FindPlayerByName(State.TeleportTarget); if not p or not p.Character then return end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); if not prp then return end
    local behind=prp.CFrame*CFrame.new(0,0,3); local hrp=HRP(); if not hrp then return end
    if State.Invisible then State.InvisOriginalCF=behind; pcall(function() hrp.CFrame=behind end)
        task.delay(0.05,function() if State.Invisible then pcall(function() hrp.CFrame=CFrame.new(0,VOID_Y,0) end) end end)
    else pcall(function() hrp.CFrame=behind end) end
    Notify("TP","Behind "..State.TeleportTarget,2)
end})
Tabs.Teleport:AddButton({Title="Bring Player to Me",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local p=FindPlayerByName(State.TeleportTarget); if not p or not p.Character then return end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); local hrp=HRP()
    if prp and hrp then pcall(function() prp.CFrame=hrp.CFrame+Vector3.new(2,0,0) end); Notify("TP","Brought "..State.TeleportTarget,3) end
end})

local followDrop = Tabs.Teleport:AddDropdown("FollowPlayer",{Title="Follow Target",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.AutoFollowTarget=(v=="None") and nil or v end)
Tabs.Teleport:AddSlider("FollowOff",{Title="Follow Offset",Default=2,Min=0,Max=8,Rounding=0}):OnChanged(function(v) State.AutoFollowOffset=Vector3.new(v,0,v) end)
Tabs.Teleport:AddToggle("AutoFollow",{Title="Auto Follow",Default=false}):OnChanged(function(v) State.AutoFollowEnabled=v; SetAutoFollow(v) end)
Tabs.Teleport:AddButton({Title="Refresh Player List",Callback=function()
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n); tpDrop:SetValue(n[1] or "None") end)
    pcall(function() followDrop:SetValues(n); followDrop:SetValue(n[1] or "None") end)
    State.TeleportTarget=(n[1]~="None") and n[1] or nil; State.AutoFollowTarget=State.TeleportTarget
    Notify("TP","Refreshed - "..#n.." player(s)",3)
end})

CM:Add(Players.PlayerAdded,function() task.wait(1)
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end); pcall(function() followDrop:SetValues(n) end)
end)
CM:Add(Players.PlayerRemoving,function(p) task.wait(0.5)
    if State.TeleportTarget==p.Name then State.TeleportTarget=nil end
    if State.AutoFollowTarget==p.Name then State.AutoFollowTarget=nil; if State.AutoFollowEnabled then SetAutoFollow(false) end end
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end); pcall(function() followDrop:SetValues(n) end)
end)

-- ── KILLER TAB ──────────────────────────────────────────────────
Tabs.Killer:AddSlider("HitRange",{Title="Hit Range",Default=12,Min=5,Max=40,Rounding=0}):OnChanged(function(v) State.AutoHitRange=v end)
Tabs.Killer:AddToggle("AutoHit",{Title="Auto Hit",Default=false}):OnChanged(function(v) State.AutoHit=v; SetAutoHit(v) end)
Tabs.Killer:AddSlider("HitAllDelay",{Title="Hit All Delay (sec)",Default=5,Min=1,Max=30,Rounding=0}):OnChanged(function(v) State.AutoHitAllDelay=v end)
Tabs.Killer:AddToggle("AutoHitAll",{Title="Auto Hit All",Default=false}):OnChanged(function(v) State.AutoHitAll=v; SetAutoHitAll(v) end)
Tabs.Killer:AddButton({Title="Hit All Now",Callback=function()
    local pl=GetAllOtherPlayers(); if #pl==0 then Notify("Hit","No players",2); return end
    for _,p in ipairs(pl) do pcall(FireHit,p) end; Notify("Hit","Hit "..#pl,3)
end})
Tabs.Killer:AddToggle("InstDmgGen",{Title="Instant Damage Gen",Default=false}):OnChanged(function(v) State.InstantDamageGen=v end)
Tabs.Killer:AddToggle("AutoDmgGen",{Title="Auto Damage Gen",Default=false}):OnChanged(function(v) State.AutoDamageGen=v; SetAutoDamageGen(v) end)
Tabs.Killer:AddToggle("InstPallet",{Title="Instant Break Pallet",Default=false}):OnChanged(function(v) State.InstantBreakPallet=v; SetInstantBreakPallet(v) end)
Tabs.Killer:AddSlider("KillerSpd",{Title="Killer Speed",Default=30,Min=16,Max=120,Rounding=0}):OnChanged(function(v) State.KillerWalkSpeedValue=v; if State.KillerWalkSpeedEnabled then SetKillerWalkSpeed(true) end end)
Tabs.Killer:AddToggle("KillerSpdOn",{Title="Killer Walk Speed",Default=false}):OnChanged(function(v) State.KillerWalkSpeedEnabled=v; SetKillerWalkSpeed(v) end)
Tabs.Killer:AddToggle("NoStun",{Title="No Stun",Default=false}):OnChanged(function(v) State.NoStun=v; SetNoStun(v) end)
Tabs.Killer:AddToggle("NoSlow",{Title="No Slowdown",Default=false}):OnChanged(function(v) State.NoSlowdown=v; SetNoSlowdown(v) end)

-- ── VISUALS TAB ─────────────────────────────────────────────────
Tabs.Visuals:AddParagraph({Title="Auto Visuals", Content="FullBright, NoFog, NoShadows are ENABLED by default and persist across matches automatically."})
Tabs.Visuals:AddToggle("FullBright",{Title="Full Bright (auto)",Default=true}):OnChanged(function(v) Vis.FullBright(v) end)
Tabs.Visuals:AddToggle("NoFog",{Title="No Fog (auto)",Default=true}):OnChanged(function(v) Vis.NoFog(v) end)
Tabs.Visuals:AddToggle("NoShadow",{Title="No Shadows (auto)",Default=true}):OnChanged(function(v) Vis.NoShadows(v) end)
Tabs.Visuals:AddButton({Title="Force Re-apply Visuals Now", Callback=function() Vis.ApplyAll(); Notify("Visuals","Re-applied",2) end})
Tabs.Visuals:AddToggle("UnlimZoom",{Title="Unlimited Zoom",Default=false}):OnChanged(function(v) State.UnlimitedZoom=v; Vis.UnlimitedZoom(v) end)
Tabs.Visuals:AddToggle("Crosshair",{Title="Crosshair",Default=false}):OnChanged(function(v) State.Crosshair=v; Vis.SetCrosshair(v) end)

-- ── MISC TAB ────────────────────────────────────────────────────
Tabs.Misc:AddParagraph({Title="Performance", Content="Small FPS + ping overlay (top-left). Draggable."})
Tabs.Misc:AddToggle("FPSCounter",{Title="FPS + Ping HUD",Default=true}):OnChanged(function(v) FPSCounter.SetVisible(v) end)
Tabs.Misc:AddToggle("AntiAFK",{Title="Anti AFK",Default=true}):OnChanged(function(v) State.AntiAFK=v end)
Tabs.Misc:AddToggle("FPSBoost",{Title="FPS Boost (disables particles)",Default=false}):OnChanged(function(v) State.FPSBoost=v; SetFPSBoost(v) end)
Tabs.Misc:AddButton({Title="Rejoin",Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId,LocalPlayer) end) end})
Tabs.Misc:AddButton({Title="Server Hop",Callback=ServerHop})
Tabs.Misc:AddButton({Title="Copy Discord",Callback=function()
    if setclipboard then setclipboard(HUB.Discord); Notify("Discord","Copied!",3) else Notify("Discord",HUB.Discord,5) end
end})

-- ── SETTINGS TAB ────────────────────────────────────────────────
Tabs.Settings:AddToggle("Notifs",{Title="Notifications",Default=true}):OnChanged(function(v) State.Notifications=v end)

Tabs.Settings:AddParagraph({Title="Floating Logo", Content="Draggable logo. Click to toggle hub."})
Tabs.Settings:AddToggle("FloatLogo",{Title="Floating Logo",Default=true}):OnChanged(function(v) FloatingLogo.SetVisible(v) end)
Tabs.Settings:AddSlider("LogoSize",{Title="Logo Size",Default=60,Min=30,Max=140,Rounding=0}):OnChanged(function(v) FloatingLogo.SetSize(v) end)
Tabs.Settings:AddSlider("LogoAlpha",{Title="Logo Transparency %",Default=10,Min=0,Max=90,Rounding=0}):OnChanged(function(v) FloatingLogo.SetTransparency(v/100) end)
Tabs.Settings:AddButton({Title="Rebuild Logo (if missing)", Callback=function()
    State.FloatingLogo = true; FloatingLogo.Build(); Notify("Logo","Rebuilt",2)
end})

Tabs.Settings:AddButton({Title="Unload Hub",Callback=function()
    SetInvisible(false); SetAutoHeal(false); SetRemoveSkillcheck(false)
    SetAutoFollow(false); SetAutoHit(false); SetAutoHitAll(false)
    SetAutoDamageGen(false); SetInstantBreakPallet(false)
    SetNoStun(false); SetNoSlowdown(false); SetUnlockCursor(false)
    SetESPHook(false); FPSCounter.SetVisible(false)
    Vis.SetCrosshair(false); Vis.Restore()
    LocalPlayer.CameraMaxZoomDistance=128
    if ESPRender then ESPRender:Disconnect() end
    if ESPGui then pcall(function() ESPGui:Destroy() end) end
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end) end
    DestroyLogo(); DestroyFPS()
    CM:Cleanup(); ESP.ClearAll(); _G[INSTANCE_KEY]=nil
    pcall(function() Fluent:Destroy() end)
end})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("X0DEC04T")
SaveManager:SetFolder("X0DEC04T/violence-district")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- ═══════════════════════════════════════════════════════════════
-- RESPAWN HOOK
-- ═══════════════════════════════════════════════════════════════
CM:Add(LocalPlayer.CharacterAdded,function()
    task.wait(1.5)
    State.Invisible=false; State.InvisOriginalCF=nil; DisconnectInvis()
    Vis.ApplyAll()
    if State.WalkSpeedEnabled       then pcall(SetWalkSpeed,true)       end
    if State.KillerWalkSpeedEnabled then pcall(SetKillerWalkSpeed,true) end
    if State.NoFallDamage           then pcall(SetNoFall,true)          end
    if State.AutoHeal               then pcall(SetAutoHeal,true)        end
    if State.RemoveSkillcheck       then pcall(SetRemoveSkillcheck,true)end
    if State.AutoFollowEnabled      then pcall(SetAutoFollow,true)      end
    if State.AutoHit                then pcall(SetAutoHit,true)         end
    if State.AutoHitAll             then pcall(SetAutoHitAll,true)      end
    if State.NoStun                 then pcall(SetNoStun,true)          end
    if State.NoSlowdown             then pcall(SetNoSlowdown,true)      end
    if State.UnlimitedZoom          then pcall(Vis.UnlimitedZoom,true)  end
    if State.UnlockCursor           then pcall(SetUnlockCursor,true)    end
    if State.ESP_Hook               then task.wait(1); pcall(ApplyESPHook) end
    if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
    if State.FPSCounter and not (State.FPSGui and State.FPSGui.Parent) then FPSCounter.Build() end
    task.wait(0.5); ESP.RefreshAll()
end)

_G[INSTANCE_KEY].destroy = function()
    pcall(SetInvisible,false); pcall(function() SetESPHook(false) end)
    DisconnectInvis(); DestroyLogo(); DestroyFPS()
    pcall(function() Fluent:Destroy() end)
end

task.spawn(function()
    task.wait(0.5)
    if State.FloatingLogo then
        local ok = FloatingLogo.Build()
        if not ok then for i = 1, 3 do task.wait(1); if FloatingLogo.Build() then break end end end
    end
    if State.FPSCounter then FPSCounter.Build() end
    while task.wait(5) do
        if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
        if State.FPSCounter and not (State.FPSGui and State.FPSGui.Parent) then FPSCounter.Build() end
    end
end)

Window:SelectTab(1)
Notify(HUB.Name,"v"..HUB.Version.." - Heal fixed | Small FPS | New logo",6)
Log("v1.0.1 fully loaded")
