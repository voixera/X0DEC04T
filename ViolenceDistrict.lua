--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.1.0 - Violence District
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
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DUPLICATE GUARD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local INSTANCE_KEY = "__X0DEC04T_v010_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then
        pcall(prev.destroy)
    end
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

Log("Script starting - v0.1.0")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOAD WIND UI
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Wind = nil

local WIND_URLS = {
    "https://raw.githubusercontent.com/Footeum/WindUI/main/WindUI.lua",
    "https://raw.githubusercontent.com/Footeum/WindUI/main/dist/source.lua",
}

for _, url in ipairs(WIND_URLS) do
    Log("Trying Wind UI: " .. url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and result then
        Wind = result
        Log("Wind UI loaded from: " .. url)
        break
    else
        Err("Failed: " .. url, tostring(result))
    end
end

if not Wind then
    Err("FATAL: Wind UI failed to load from all mirrors")
    return
end

Log("Wind UI ready")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HUB CONFIG
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.1.0",
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
        return conn
    end
    Err("CM:Add connect failed", tostring(label))
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
-- KNOWN KILLERS (from scan)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local KNOWN_KILLERS = {
    ["stalker"]     = true,
    ["killer"]      = true,
    ["hidden"]      = true,
    ["abysswalker"] = true,
    ["veil"]        = true,
    ["slasher"]     = true,
    ["masked"]      = true,
    ["cure"]        = true,
    ["jason"]       = true,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTES (mapped from scan output)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

local function GetRemote(...)
    if not Remotes then return nil end
    local current = Remotes
    for _, name in ipairs({...}) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local R = {
    -- Generator
    Gen = {
        SkillCheck     = GetRemote("Generator", "SkillCheckEvent"),
        SkillCheckFail = GetRemote("Generator", "SkillCheckFailEvent"),
        GenDone        = GetRemote("Generator", "GenDone"),
        AllGenDone     = GetRemote("Generator", "allgendone"),
        RepairEvent    = GetRemote("Generator", "RepairEvent"),
    },
    -- Healing
    Heal = {
        SkillCheck     = GetRemote("Healing", "SkillCheckEvent"),
        SkillCheckFail = GetRemote("Healing", "SkillCheckFailEvent"),
        HealDone       = GetRemote("Healing", "Healdone"),
    },
    -- Chase
    Chase = {
        Music = GetRemote("Chase", "ChaseMusicEvent"),
        Run   = GetRemote("Chase", "Runevent"),
    },
    -- Attacks
    Attack = {
        Basic  = GetRemote("Attacks", "BasicAttack"),
        Lunge  = GetRemote("Attacks", "Lunge"),
        Hit    = GetRemote("Attacks", "hit"),
    },
    -- Carry / Hook
    Carry = {
        Hook       = GetRemote("Carry", "HookEvent"),
        UnHook     = GetRemote("Carry", "UnHookEvent"),
        HookPhase  = GetRemote("Carry", "HookPhase"),
        SelfUnHook = GetRemote("Carry", "SelfUnHookEvent"),
    },
    -- Game Events
    Game = {
        Start      = GetRemote("Game", "Start"),
        KillerMorph= GetRemote("Game", "KillerMorph"),
        RoundEnd   = GetRemote("Game", "RoundEnd"),
        OneLeft    = GetRemote("Game", "Oneleft"),
        Death      = GetRemote("Game", "death"),
        EndScreen  = GetRemote("Game", "EndScreenEvent"),
        Reward     = GetRemote("Game", "RewardEvent"),
    },
    -- Killer Perks
    KPerk = {
        KingScourgeStart = GetRemote("KillerPerks", "kingscourge", "KingScourgeStart"),
        KingScourgeHit   = GetRemote("KillerPerks", "kingscourge", "KingScourgeHit"),
    },
    -- Window / Pallet
    Window = {
        VaultEvent = GetRemote("Window", "VaultEvent"),
        FastVault  = GetRemote("Window", "fastvault"),
    },
    Pallet = {
        Drop = GetRemote("Pallet", "PalletDropEvent"),
        Slide= GetRemote("Pallet", "PalletSlideEvent"),
    },
    -- Mechanics
    Mech = {
        GotKnocked = GetRemote("Mechanics", "gotknocked"),
        Slow       = GetRemote("Mechanics", "Slow"),
        Highlight  = GetRemote("Mechanics", "Highlight"),
    },
    -- Messages
    Msg = {
        Announce = GetRemote("Messages", "AnnounceMessage"),
        MapInfo  = GetRemote("Messages", "Mapinfo"),
    },
    -- Items
    Items = {
        FlashlightActivate = GetRemote("Items", "Flashlight", "Activate"),
        TrackerBeep        = GetRemote("Items", "Tracker", "beep"),
    },
    -- Exit
    Exit = {
        Lever = GetRemote("Exit", "LeverEvent"),
        Gate  = GetRemote("Exit", "gate"),
    },
}

Log("Remotes mapped successfully")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WORKSPACE REFS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local WS = {
    Map        = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
    Pallets    = nil,
}
if WS.Map then
    WS.Generators = WS.Map:FindFirstChild("Generators")
    WS.Pallets    = WS.Map:FindFirstChild("Pallets")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {
    -- Awareness
    ChaseAlert        = true,
    AttackAlert       = true,
    LungeAlert        = true,
    HookAlert         = true,
    HookPhaseAlert    = true,
    UnhookAlert       = true,
    KnockedAlert      = true,
    SkillCheckNotify  = true,
    HealSkillNotify   = true,
    GenDoneNotify     = true,
    AllGensNotify     = true,
    OneLeftNotify     = true,
    DeathNotify       = true,
    KingScourgeAlert  = true,
    GateAlert         = true,
    AnnounceAlert     = true,

    -- ESP
    ESP_Generators    = false,
    ESP_Killer        = false,
    ESP_Survivors     = false,
    ESP_Items         = false,
    ESP_Weapons       = false,
    ESP_Clones        = false,
    ESP_Pallets       = false,
    ESP_MaxDistance   = 500,
    ESP_ShowDistance  = true,
    ESP_ShowName      = true,

    -- ESP Colors
    Color_Killer      = Color3.fromRGB(255,  40,  40),
    Color_Survivor    = Color3.fromRGB( 60, 220, 255),
    Color_Generator   = Color3.fromRGB(255, 200,  60),
    Color_Item        = Color3.fromRGB(120, 255, 120),
    Color_Weapon      = Color3.fromRGB(255, 120, 220),
    Color_Clone       = Color3.fromRGB(180, 180, 180),
    Color_Pallet      = Color3.fromRGB(255, 165,   0),

    -- Movement
    WalkSpeed         = 16,
    JumpPower         = 50,
    NoClip            = false,
    InfJump           = false,

    -- Visuals
    FullBright        = false,
    NoFog             = false,
    NoShadows         = false,
    ClearWeather      = false,
    LowGraphics       = false,
    FOV               = 70,
    ClockTime         = 14,
    RemoveBlur        = false,
    RemoveCC          = false,
    Freecam           = false,
    HideName          = false,
    NoSound           = false,
    MuteBGMusic       = false,
    NoParticles       = false,

    -- Misc
    AutoRejoin        = false,
    AntiAFK           = true,

    -- Internal
    IsKiller          = false,
    MatchActive       = false,
    ESPCache          = {},
    LightBackup       = {},
    MutedSounds       = {},
    NoClipConn        = nil,
    InfJumpConn       = nil,
    FreecamConn       = nil,
    AwarenessReady    = false,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ROLE DETECTION
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Role = {}

function Role.IsKiller(char)
    if not char then return false end
    if char:GetAttribute("Killer")   == true     then return true end
    if char:GetAttribute("IsKiller") == true     then return true end
    if char:GetAttribute("Role")     == "Killer" then return true end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

function Role.KillerName(char)
    if not char then return "Killer" end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then
            return k:gsub("^%l", string.upper)
        end
    end
    return char.Name
end

function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones    and char:IsDescendantOf(WS.Clones)    then return true end
    return false
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- NOTIFY
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Notify(title, content, dur)
    pcall(function()
        Wind:Notify({
            Title    = tostring(title   or ""),
            Content  = tostring(content or ""),
            Duration = tonumber(dur)    or 4,
        })
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP SYSTEM
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ESP = {}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

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
    for obj in pairs(State.ESPCache) do
        ESP.Clear(obj)
    end
    State.ESPCache = {}
end

local function MakeBillboard(hrp, label, color)
    local bb = Instance.new("BillboardGui")
    bb.Adornee        = hrp
    bb.Size           = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset    = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = State.ESP_MaxDistance
    bb.Parent         = GuiParent()

    local nl = Instance.new("TextLabel", bb)
    nl.Size                   = UDim2.new(1, 0, 0.6, 0)
    nl.BackgroundTransparency = 1
    nl.Text                   = tostring(label or "")
    nl.TextColor3             = color
    nl.TextStrokeTransparency = 0
    nl.Font                   = Enum.Font.GothamBold
    nl.TextSize               = 14
    nl.Visible                = State.ESP_ShowName

    local dl = Instance.new("TextLabel", bb)
    dl.Size                   = UDim2.new(1, 0, 0.4, 0)
    dl.Position               = UDim2.new(0, 0, 0.6, 0)
    dl.BackgroundTransparency = 1
    dl.Text                   = "0m"
    dl.TextColor3             = Color3.fromRGB(220, 220, 220)
    dl.TextStrokeTransparency = 0
    dl.Font                   = Enum.Font.Gotham
    dl.TextSize               = 12
    dl.Visible                = State.ESP_ShowDistance

    return bb, nl, dl
end

function ESP.AddChar(char, label, color)
    if State.ESPCache[char] then ESP.Clear(char) end
    local hrp = char:FindFirstChild("HumanoidRootPart")
              or char:FindFirstChild("Torso")
              or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local hl = Instance.new("Highlight")
    hl.Adornee          = char
    hl.FillColor        = color
    hl.OutlineColor     = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.55
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = GuiParent()

    local bb, nl, dl = MakeBillboard(hrp, label, color)
    State.ESPCache[char] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=hrp }
end

function ESP.AddObj(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end
    local part = model
    if model:IsA("Model") then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end

    local hl = Instance.new("Highlight")
    hl.Adornee             = model
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.7
    hl.OutlineTransparency = 0.2
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = GuiParent()

    local bb, nl, dl = MakeBillboard(part, label, color)
    State.ESPCache[model] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=part }
end

function ESP.UpdateDist()
    local ch  = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then
            c.dl.Text = math.floor(
                (c.hrp.Position - hrp.Position).Magnitude
            ) .. "m"
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
        if p ~= LocalPlayer and p.Character and not Role.IsFake(p.Character) then
            local char = p.Character
            local isK  = Role.IsKiller(char)
            if isK and State.ESP_Killer and not State.ESPCache[char] then
                ESP.AddChar(char,
                    "☠ " .. Role.KillerName(char) .. " [" .. p.Name .. "]",
                    State.Color_Killer)
            elseif not isK and State.ESP_Survivors and not State.ESPCache[char] then
                ESP.AddChar(char, "◈ " .. p.Name, State.Color_Survivor)
            elseif (isK and not State.ESP_Killer) or (not isK and not State.ESP_Survivors) then
                ESP.Clear(char)
            end
        end
    end
end

function ESP.ScanGens()
    if not WS.Generators then return end
    for _, g in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators and not State.ESPCache[g] then
            ESP.AddObj(g, "⚡ " .. g.Name, State.Color_Generator)
        elseif not State.ESP_Generators then
            ESP.Clear(g)
        end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.AddObj(w, "⚔ " .. w.Name, State.Color_Weapon)
        elseif not State.ESP_Weapons then
            ESP.Clear(w)
        end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones and not State.ESPCache[c] then
            ESP.AddObj(c, "👥 Clone", State.Color_Clone)
        elseif not State.ESP_Clones then
            ESP.Clear(c)
        end
    end
end

function ESP.ScanPallets()
    if not WS.Pallets then return end
    for _, p in ipairs(WS.Pallets:GetChildren()) do
        if State.ESP_Pallets and not State.ESPCache[p] then
            ESP.AddObj(p, "🪵 Pallet", State.Color_Pallet)
        elseif not State.ESP_Pallets then
            ESP.Clear(p)
        end
    end
end

function ESP.ScanItems()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and
            (o:GetAttribute("Item") or o:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[o] then
                ESP.AddObj(o, "🎒 " .. o.Name, State.Color_Item)
            elseif not State.ESP_Items then
                ESP.Clear(o)
            end
        end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers()
    ESP.ScanGens()
    ESP.ScanWeapons()
    ESP.ScanClones()
    ESP.ScanPallets()
    ESP.ScanItems()
end

-- ESP update loops
task.spawn(function()
    while task.wait(2) do pcall(ESP.RefreshAll) end
end)

CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDist) end, "ESP.Heartbeat")

CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Clear(p.Character) end
end, "PlayerRemoving")

CM:Add(Players.PlayerAdded, function(p)
    CM:Add(p.CharacterRemoving, function(c) ESP.Clear(c) end, "CharRemove:"..p.Name)
end, "PlayerAdded")

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
        CM:Add(p.CharacterRemoving, function(c) ESP.Clear(c) end, "CharRemove:"..p.Name)
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MOVEMENT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Move = {}

function Move.GetHuman()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

function Move.GetHRP()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

function Move.Speed()
    local h = Move.GetHuman()
    if h then h.WalkSpeed = State.WalkSpeed end
end

function Move.Jump()
    local h = Move.GetHuman()
    if h then
        h.UseJumpPower = true
        h.JumpPower    = State.JumpPower
    end
end

function Move.SetNoClip(e)
    if State.NoClipConn then
        pcall(function() State.NoClipConn:Disconnect() end)
        State.NoClipConn = nil
    end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer.Character
            if not ch then return end
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
end

function Move.SetInfJump(e)
    if State.InfJumpConn then
        pcall(function() State.InfJumpConn:Disconnect() end)
        State.InfJumpConn = nil
    end
    if e then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Move.GetHuman()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local tpTarget = ""

function Move.NearestGen()
    if not WS.Generators then
        Notify("TP", "No generators found.", 3)
        return
    end
    local hrp = Move.GetHRP()
    if not hrp then return end
    local best, bd = nil, math.huge
    for _, g in ipairs(WS.Generators:GetChildren()) do
        local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then
            local d = (p.Position - hrp.Position).Magnitude
            if d < bd then bd = d; best = p end
        end
    end
    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0, 4, 0)
        Notify("TP", "Teleported to generator (" .. math.floor(bd) .. "m)", 3)
    end
end

function Move.ToPlayer()
    if tpTarget == "" then
        Notify("TP", "Enter a player name first.", 3)
        return
    end
    local t = Players:FindFirstChild(tpTarget)
    if not t or not t.Character then
        Notify("TP", "Player not found: " .. tpTarget, 3)
        return
    end
    local hrp  = Move.GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0, 0, 3)
        Notify("TP", "Teleported to " .. tpTarget, 3)
    end
end

function Move.NearestExit()
    local hrp = Move.GetHRP()
    if not hrp then return end
    local best, bd = nil, math.huge
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o.Name:lower():find("exit") or o.Name:lower():find("gate") then
            if o:IsA("BasePart") then
                local d = (o.Position - hrp.Position).Magnitude
                if d < bd then bd = d; best = o end
            end
        end
    end
    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0, 4, 0)
        Notify("TP", "Teleported to exit (" .. math.floor(bd) .. "m)", 3)
    else
        Notify("TP", "No exit found.", 3)
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
        Lighting.Ambient                  = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient           = Color3.fromRGB(255, 255, 255)
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
            if a:IsA("Atmosphere") then
                a.Density = 0
                a.Haze    = 0
            end
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

function Vis.ClearWx(e)
    if e then
        for _, o in ipairs(Lighting:GetDescendants()) do
            if o:IsA("Atmosphere") then
                o.Density = 0
                o.Haze    = 0
            end
        end
    end
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

function Vis.PostFX(rm)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not rm
        end
    end
end

function Vis.ColorCorr(rm)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then v.Enabled = not rm end
    end
end

function Vis.Particles(rm)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire")
        or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = not rm
        end
    end
end

function Vis.HideName(e)
    local ch   = LocalPlayer.Character
    if not ch then return end
    local head = ch:FindFirstChild("Head")
    if not head then return end
    for _, g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end

function Vis.MuteAll(e)
    if e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and not table.find(State.MutedSounds, s) then
                table.insert(State.MutedSounds, { s = s, v = s.Volume })
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

function Vis.MuteBG(e)
    local bg = Workspace:FindFirstChild("BackgroundSounds")
    if not bg then return end
    for _, s in ipairs(bg:GetDescendants()) do
        if s:IsA("Sound") then s.Volume = e and 0 or 1 end
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
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                mv = mv + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                mv = mv - Vector3.new(0, 1, 0)
            end
            pos = pos + mv * 2
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

function Vis.ServerHop()
    local ok, e = pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"
        )
        local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if dok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
        Notify("Server Hop", "No open server found.", 4)
    end)
    if not ok then Notify("Server Hop", "Error: " .. tostring(e), 4) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AWARENESS SYSTEM
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SetupAwareness()
    if State.AwarenessReady then return end
    State.AwarenessReady = true

    local function Conn(sig, cb, label)
        if sig then CM:Add(sig, cb, label) end
    end

    -- BindableEvent uses .Event not .OnClientEvent
    local function BindConn(sig, cb, label)
        if sig then CM:Add(sig.Event, cb, label) end
    end

    -- Generator
    Conn(R.Gen.SkillCheck and R.Gen.SkillCheck.OnClientEvent,
        function()
            if State.SkillCheckNotify then
                Notify("⚙ Skill Check!", "Hit the mark on the generator!", 2)
            end
        end, "GenSC")

    Conn(R.Gen.SkillCheckFail and R.Gen.SkillCheckFail.OnClientEvent,
        function()
            if State.SkillCheckNotify then
                Notify("⚙ Skill Check FAIL", "Generator progress lost!", 3)
            end
        end, "GenSCFail")

    BindConn(R.Gen.GenDone,
        function()
            if State.GenDoneNotify then
                Notify("⚡ Generator Done!", "One generator repaired.", 3)
            end
        end, "GenDone")

    BindConn(R.Gen.AllGenDone,
        function()
            if State.AllGensNotify then
                Notify("⚡ All Generators Done!", "Find the exit gate!", 6)
            end
        end, "AllGens")

    -- Healing
    Conn(R.Heal.SkillCheck and R.Heal.SkillCheck.OnClientEvent,
        function()
            if State.HealSkillNotify then
                Notify("💊 Heal Skill Check!", "", 2)
            end
        end, "HealSC")

    Conn(R.Heal.SkillCheckFail and R.Heal.SkillCheckFail.OnClientEvent,
        function()
            if State.HealSkillNotify then
                Notify("💊 Heal Skill Check FAIL", "", 2)
            end
        end, "HealSCFail")

    -- Chase
    Conn(R.Chase.Music and R.Chase.Music.OnClientEvent,
        function()
            if State.ChaseAlert then
                Notify("⚠ CHASE!", "Killer is near you!", 3)
            end
        end, "Chase")

    -- Attacks
    Conn(R.Attack.Lunge and R.Attack.Lunge.OnClientEvent,
        function()
            if State.LungeAlert then
                Notify("⚠ LUNGE!", "Killer is lunging at you!", 2)
            end
        end, "Lunge")

    Conn(R.Attack.Basic and R.Attack.Basic.OnClientEvent,
        function()
            if State.AttackAlert then
                Notify("⚠ ATTACK!", "Killer swung at you!", 2)
            end
        end, "BasicAttack")

    -- Carry / Hook
    Conn(R.Carry.Hook and R.Carry.Hook.OnClientEvent,
        function()
            if State.HookAlert then
                Notify("🪝 HOOKED!", "You have been hooked!", 4)
            end
        end, "Hook")

    Conn(R.Carry.HookPhase and R.Carry.HookPhase.OnClientEvent,
        function(phase)
            if State.HookPhaseAlert then
                Notify("🪝 Hook Phase " .. tostring(phase), "", 3)
            end
        end, "HookPhase")

    Conn(R.Carry.UnHook and R.Carry.UnHook.OnClientEvent,
        function()
            if State.UnhookAlert then
                Notify("🪝 Unhooked!", "You have been unhooked!", 3)
            end
        end, "UnHook")

    -- Knocked
    BindConn(R.Mech.GotKnocked,
        function()
            if State.KnockedAlert then
                Notify("💀 KNOCKED DOWN!", "You are on the ground!", 3)
            end
        end, "Knocked")

    -- King Scourge
    Conn(R.KPerk.KingScourgeStart and R.KPerk.KingScourgeStart.OnClientEvent,
        function()
            if State.KingScourgeAlert then
                Notify("👑 King Scourge!", "Killer perk activated!", 3)
            end
        end, "KingScourge")

    -- Gate
    BindConn(R.Exit.Gate,
        function()
            if State.GateAlert then
                Notify("🚪 Exit Gate!", "Gate has been opened!", 5)
            end
        end, "Gate")

    -- Game events (BindableEvent)
    BindConn(R.Game.KillerMorph,
        function()
            State.IsKiller = true
            Notify("☠ Role", "You are the KILLER!", 5)
        end, "KillerMorph")

    BindConn(R.Game.Start,
        function()
            State.MatchActive = true
            State.IsKiller    = false
            Notify("🎮 Match Started", "Good luck survivor!", 3)
        end, "GameStart")

    BindConn(R.Game.RoundEnd,
        function()
            State.MatchActive = false
            ESP.ClearAll()
        end, "RoundEnd")

    Conn(R.Game.OneLeft and R.Game.OneLeft.OnClientEvent,
        function()
            if State.OneLeftNotify then
                Notify("👤 Last Survivor!", "You are the last one alive!", 5)
            end
        end, "OneLeft")

    Conn(R.Game.Death and R.Game.Death.OnClientEvent,
        function()
            if State.DeathNotify then
                Notify("💀 You Died", "Better luck next time.", 4)
            end
        end, "Death")

    -- Announce messages
    Conn(R.Msg.Announce and R.Msg.Announce.OnClientEvent,
        function(msg)
            if State.AnnounceAlert then
                Notify("📢 Announcement", tostring(msg or ""), 5)
            end
        end, "Announce")

    -- Anti-AFK
    CM:Add(LocalPlayer.Idled,
        function()
            if State.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end
        end, "AntiAFK")

    Log("Awareness system ready")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BUILD WIND UI
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Log("Creating Wind UI window...")

local Window = Wind:CreateWindow({
    Title    = HUB.Name,
    Footer   = "v" .. HUB.Version .. " | " .. HUB.Author,
})

assert(Window, "Window creation failed!")
Log("Window created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TABS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Tabs = {}
local TAB_LIST = {
    { key = "Main",      name = "Main"      },
    { key = "Awareness", name = "Awareness" },
    { key = "ESP",       name = "ESP"       },
    { key = "Movement",  name = "Movement"  },
    { key = "Visuals",   name = "Visuals"   },
    { key = "Misc",      name = "Misc"      },
    { key = "Settings",  name = "Settings"  },
}

for _, def in ipairs(TAB_LIST) do
    local ok, tab = pcall(function()
        return Window:CreateTab(def.name)
    end)
    if ok and tab then
        Tabs[def.key] = tab
        Log("Tab: " .. def.name)
    else
        Err("Tab failed: " .. def.name, tostring(tab))
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WIND UI HELPERS
-- Wind UI API:
--   tab:CreateSection(name)
--   tab:CreateToggle(name, default, callback)
--   tab:CreateButton(name, callback)
--   tab:CreateSlider(name, min, max, default, callback)
--   tab:CreateTextBox(name, placeholder, callback)
--   tab:CreateLabel(text)
--   tab:CreateDropdown(name, options, default, callback)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Sec(tab, name)
    if not tab then return end
    pcall(function() tab:CreateSection(name) end)
end

local function Tog(tab, name, default, cb)
    if not tab then return end
    pcall(function() tab:CreateToggle(name, default, cb) end)
end

local function Btn(tab, name, cb)
    if not tab then return end
    pcall(function() tab:CreateButton(name, cb) end)
end

local function Sld(tab, name, min, max, default, cb)
    if not tab then return end
    pcall(function() tab:CreateSlider(name, min, max, default, cb) end)
end

local function Inp(tab, name, placeholder, cb)
    if not tab then return end
    pcall(function() tab:CreateTextBox(name, placeholder, cb) end)
end

local function Lbl(tab, text)
    if not tab then return end
    pcall(function() tab:CreateLabel(text) end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: MAIN
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Main then
    local T = Tabs.Main

    Sec(T, "Information")
    Lbl(T, "Hub: " .. HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "Game: " .. HUB.Game)
    Lbl(T, "Author: " .. HUB.Author)

    Sec(T, "Killers Detected")
    local killerList = {}
    for k in pairs(KNOWN_KILLERS) do
        killerList[#killerList + 1] = k:gsub("^%l", string.upper)
    end
    table.sort(killerList)
    Lbl(T, table.concat(killerList, ", "))

    Sec(T, "Quick Info")
    Lbl(T, "Toggle UI: RightShift")
    Lbl(T, "Panic / Clear ESP: End")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: AWARENESS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Awareness then
    local T = Tabs.Awareness

    Sec(T, "Killer Alerts")
    Tog(T, "Chase Music Alert",    true,  function(v) State.ChaseAlert       = v end)
    Tog(T, "Basic Attack Alert",   true,  function(v) State.AttackAlert      = v end)
    Tog(T, "Lunge Alert",          true,  function(v) State.LungeAlert       = v end)
    Tog(T, "King Scourge Alert",   true,  function(v) State.KingScourgeAlert = v end)

    Sec(T, "Survivor Alerts")
    Tog(T, "Knocked Down Alert",   true,  function(v) State.KnockedAlert     = v end)
    Tog(T, "Hook Alert",           true,  function(v) State.HookAlert        = v end)
    Tog(T, "Hook Phase Alert",     true,  function(v) State.HookPhaseAlert   = v end)
    Tog(T, "Unhook Alert",         true,  function(v) State.UnhookAlert      = v end)

    Sec(T, "Skill Check Alerts")
    Tog(T, "Generator Skill Check",true,  function(v) State.SkillCheckNotify = v end)
    Tog(T, "Heal Skill Check",     true,  function(v) State.HealSkillNotify  = v end)

    Sec(T, "Objective Alerts")
    Tog(T, "Generator Done",       true,  function(v) State.GenDoneNotify    = v end)
    Tog(T, "All Generators Done",  true,  function(v) State.AllGensNotify    = v end)
    Tog(T, "Exit Gate Opened",     true,  function(v) State.GateAlert        = v end)
    Tog(T, "Last Survivor",        true,  function(v) State.OneLeftNotify    = v end)
    Tog(T, "Death Notify",         true,  function(v) State.DeathNotify      = v end)
    Tog(T, "Announcements",        true,  function(v) State.AnnounceAlert    = v end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: ESP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.ESP then
    local T = Tabs.ESP

    Sec(T, "Player ESP")
    Tog(T, "Killer ESP", false, function(v)
        State.ESP_Killer = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and Role.IsKiller(p.Character) then
                    ESP.Clear(p.Character)
                end
            end
        end
    end)
    Tog(T, "Survivor ESP", false, function(v)
        State.ESP_Survivors = v
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and not Role.IsKiller(p.Character) then
                    ESP.Clear(p.Character)
                end
            end
        end
    end)

    Sec(T, "Object ESP")
    Tog(T, "Generator ESP", false, function(v)
        State.ESP_Generators = v
        if not v and WS.Generators then
            for _, g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end
        end
    end)
    Tog(T, "Pallet ESP", false, function(v)
        State.ESP_Pallets = v
        if not v and WS.Pallets then
            for _, p in ipairs(WS.Pallets:GetChildren()) do ESP.Clear(p) end
        end
    end)
    Tog(T, "Item ESP", false, function(v)
        State.ESP_Items = v
    end)
    Tog(T, "Weapon ESP", false, function(v)
        State.ESP_Weapons = v
        if not v and WS.Weapons then
            for _, w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end
        end
    end)
    Tog(T, "Clone ESP", false, function(v)
        State.ESP_Clones = v
        if not v and WS.Clones then
            for _, c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end
        end
    end)

    Sec(T, "Display Settings")
    Tog(T, "Show Names", true, function(v)
        State.ESP_ShowName = v
        for _, c in pairs(State.ESPCache) do
            if c.nl then c.nl.Visible = v end
        end
    end)
    Tog(T, "Show Distance", true, function(v)
        State.ESP_ShowDistance = v
        for _, c in pairs(State.ESPCache) do
            if c.dl then c.dl.Visible = v end
        end
    end)
    Sld(T, "Max Distance", 50, 2000, 500, function(v)
        State.ESP_MaxDistance = tonumber(v) or 500
        for _, c in pairs(State.ESPCache) do
            if c.bb then c.bb.MaxDistance = State.ESP_MaxDistance end
        end
    end)

    Sec(T, "Actions")
    Btn(T, "Refresh ESP", function()
        ESP.ClearAll()
        ESP.RefreshAll()
        Notify("ESP", "Refreshed all ESP.", 2)
    end)
    Btn(T, "Clear All ESP", function()
        ESP.ClearAll()
        Notify("ESP", "Cleared all ESP.", 2)
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: MOVEMENT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Movement then
    local T = Tabs.Movement

    Sec(T, "Speed & Jump")
    Sld(T, "Walk Speed", 16, 200, 16, function(v)
        State.WalkSpeed = tonumber(v) or 16
        Move.Speed()
    end)
    Sld(T, "Jump Power", 50, 300, 50, function(v)
        State.JumpPower = tonumber(v) or 50
        Move.Jump()
    end)

    Sec(T, "Advanced Movement")
    Tog(T, "NoClip", false, function(v)
        State.NoClip = v
        Move.SetNoClip(v)
    end)
    Tog(T, "Infinite Jump", false, function(v)
        State.InfJump = v
        Move.SetInfJump(v)
    end)

    Sec(T, "Teleport")
    Btn(T, "TP to Nearest Generator", Move.NearestGen)
    Btn(T, "TP to Nearest Exit", Move.NearestExit)
    Inp(T, "Player Name", "Case-sensitive name...", function(v)
        tpTarget = tostring(v or "")
    end)
    Btn(T, "TP to Player", Move.ToPlayer)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: VISUALS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Visuals then
    local T = Tabs.Visuals

    Sec(T, "Lighting")
    Tog(T, "FullBright",    false, function(v) State.FullBright    = v; Vis.FullBright(v) end)
    Tog(T, "No Fog",        false, function(v) State.NoFog         = v; Vis.NoFog(v)      end)
    Tog(T, "No Shadows",    false, function(v) State.NoShadows     = v; Vis.NoShadows(v)  end)
    Tog(T, "Clear Weather", false, function(v) State.ClearWeather  = v; Vis.ClearWx(v)    end)
    Sld(T, "Time of Day", 0, 24, 14, function(v)
        State.ClockTime = tonumber(v) or 14
        Vis.SetClock(State.ClockTime)
    end)

    Sec(T, "Camera")
    Sld(T, "Field of View", 30, 120, 70, function(v)
        State.FOV = tonumber(v) or 70
        Vis.SetFOV(State.FOV)
    end)
    Tog(T, "Freecam (WASD + Space/Ctrl)", false, function(v)
        State.Freecam = v
        Vis.Freecam(v)
    end)

    Sec(T, "Post Processing")
    Tog(T, "Remove Blur / Bloom", false, function(v)
        State.RemoveBlur = v
        Vis.PostFX(v)
    end)
    Tog(T, "Remove Color Correction", false, function(v)
        State.RemoveCC = v
        Vis.ColorCorr(v)
    end)
    Tog(T, "No Particles", false, function(v)
        State.NoParticles = v
        Vis.Particles(v)
    end)

    Sec(T, "Performance")
    Tog(T, "Low Graphics", false, function(v)
        State.LowGraphics = v
        Vis.LowGfx(v)
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: MISC
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Misc then
    local T = Tabs.Misc

    Sec(T, "Audio")
    Tog(T, "Mute All Sounds", false, function(v)
        State.NoSound = v
        Vis.MuteAll(v)
    end)
    Tog(T, "Mute Background Music", false, function(v)
        State.MuteBGMusic = v
        Vis.MuteBG(v)
    end)

    Sec(T, "Character")
    Tog(T, "Hide Own Name", false, function(v)
        State.HideName = v
        Vis.HideName(v)
    end)

    Sec(T, "Server")
    Btn(T, "Server Hop", Vis.ServerHop)
    Btn(T, "Rejoin", function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end)
    Btn(T, "Copy Job ID", function()
        if setclipboard then
            setclipboard(tostring(game.JobId))
            Notify("Copied", "Job ID copied to clipboard!", 3)
        else
            Notify("Error", "Clipboard not supported on your executor.", 3)
        end
    end)

    Sec(T, "Utility")
    Tog(T, "Auto Rejoin on Kick", false, function(v)
        State.AutoRejoin = v
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TAB: SETTINGS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if Tabs.Settings then
    local T = Tabs.Settings

    Sec(T, "Anti-AFK")
    Tog(T, "Anti-AFK (Auto)", true, function(v)
        State.AntiAFK = v
    end)

    Sec(T, "Credits")
    Lbl(T, HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "Author: " .. HUB.Author)
    Lbl(T, "Game: " .. HUB.Game)
    Lbl(T, "UI: Wind UI")

    Sec(T, "Danger Zone")
    Btn(T, "Unload Hub", function()
        if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
        if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
        if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
        CM:Cleanup()
        Vis.RestoreLight()
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
        Log("Hub unloaded successfully")
    end)
end

Log("All tabs and controls created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- POST BUILD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SetupAwareness()

-- Keyboard shortcuts
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        pcall(function() Window:Toggle() end)
    elseif inp.KeyCode == Enum.KeyCode.End then
        State.ESP_Killer      = false
        State.ESP_Survivors   = false
        State.ESP_Generators  = false
        State.ESP_Items       = false
        State.ESP_Weapons     = false
        State.ESP_Clones      = false
        State.ESP_Pallets     = false
        ESP.ClearAll()
        Notify("Panic", "All ESP cleared!", 3)
    end
end, "Keybinds")

-- Re-apply settings on character respawn
CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1)
    pcall(Move.Speed)
    pcall(Move.Jump)
    if State.NoClip     then pcall(Move.SetNoClip,  true) end
    if State.InfJump    then pcall(Move.SetInfJump, true) end
    if State.FullBright then pcall(Vis.FullBright,  true) end
    if State.NoFog      then pcall(Vis.NoFog,       true) end
    if State.HideName   then pcall(Vis.HideName,    true) end
    if State.FOV ~= 70  then pcall(Vis.SetFOV, State.FOV) end
end, "CharacterAdded")

-- Auto-rejoin on teleport fail
CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end, "OnTeleport")

-- Lighting enforcement
task.spawn(function()
    while task.wait(5) do
        if State.FullBright   then pcall(Vis.FullBright, true) end
        if State.NoFog        then pcall(Vis.NoFog,      true) end
        if State.NoShadows    then pcall(Vis.NoShadows,  true) end
        if State.ClearWeather then pcall(Vis.ClearWx,    true) end
    end
end)

-- Register instance for guard
_G[INSTANCE_KEY] = {
    version   = HUB.Version,
    timestamp = os.time(),
    destroy   = function()
        if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
        if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
        if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
        CM:Cleanup()
        Vis.RestoreLight()
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v" .. HUB.Version .. " loaded! Enjoy.", 5)
Log("X0DEC04T Hub v" .. HUB.Version .. " fully initialized")
