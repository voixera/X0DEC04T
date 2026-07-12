--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.5.7 - Violence District
-- FIXED: Auto Parry (proximity + damage + remote spam)
-- FIXED: All features now have keybind support
-- ADDED: Keybind manager for every major feature
-- ADDED: Parry force-fire on killer swing detection
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
local TeleportService   = game:GetService("TeleportService")
local VirtualInputMgr   = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_v057_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _logStart = os.clock()
local function Log(msg) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_logStart, tostring(msg))) end
local function Err(msg,d) warn(string.format("[X0DEC04T][+%.2fs] ERROR: %s | %s", os.clock()-_logStart, tostring(msg), tostring(d or ""))) end

Log("v0.5.7 starting")

local Rayfield = nil
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then Err("Rayfield failed"); return end

local HUB = { Name="X0DEC04T Hub", Game="Violence District", Version="0.5.7", Author="voixera" }

-- ═══════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════
local CM = { _list = {} }
function CM:Add(sig, cb, label)
    if not sig then return end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

-- ═══════════════════════════════════════════
-- KEYBIND MANAGER
-- ═══════════════════════════════════════════
local KB = {
    _binds = {},
    -- Default keybinds for every feature
    Keys = {
        Invisible       = Enum.KeyCode.X,
        AutoParry       = Enum.KeyCode.P,
        AutoHeal        = Enum.KeyCode.H,
        GodMode         = Enum.KeyCode.G,
        NoClip          = Enum.KeyCode.N,
        InfJump         = Enum.KeyCode.J,
        SpeedBoost      = Enum.KeyCode.B,
        FleeKiller      = Enum.KeyCode.F,
        FullBright      = Enum.KeyCode.L,
        Freecam         = Enum.KeyCode.V,
        AutoGenRush     = Enum.KeyCode.R,
        AutoSkillcheck  = Enum.KeyCode.K,
        GenProgress     = Enum.KeyCode.O,
        OwnHP           = Enum.KeyCode.U,
        PanicClearESP   = Enum.KeyCode.End,
        ForceParry      = Enum.KeyCode.Q,
        ForceHeal       = Enum.KeyCode.Y,
        ServerHop       = Enum.KeyCode.M,
        KillerESP       = Enum.KeyCode.F1,
        SurvivorESP     = Enum.KeyCode.F2,
        GeneratorESP    = Enum.KeyCode.F3,
        PalletESP       = Enum.KeyCode.F4,
        VaultESP        = Enum.KeyCode.F5,
        HookESP         = Enum.KeyCode.F6,
        NoFog           = Enum.KeyCode.F7,
        NoShadows       = Enum.KeyCode.F8,
    }
}

function KB.Register(name, defaultKey, callback)
    KB._binds[name] = {
        key      = defaultKey or Enum.KeyCode.Unknown,
        callback = callback,
        enabled  = true,
    }
end

function KB.SetKey(name, keyCode)
    if KB._binds[name] then
        KB._binds[name].key = keyCode
    end
end

function KB.SetEnabled(name, v)
    if KB._binds[name] then KB._binds[name].enabled = v end
end

-- Global key handler
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    for name, bind in pairs(KB._binds) do
        if bind.enabled and bind.key == inp.KeyCode then
            pcall(bind.callback)
        end
    end
end, "KB_Global")

-- ═══════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════
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

local function FindRemoteDeep(root, targetName)
    if not root then return nil end
    for _, v in ipairs(root:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name == targetName then
            return v
        end
    end
    return nil
end

local function FindRemotesByKeyword(root, keyword)
    local found = {}
    if not root then return found end
    for _, v in ipairs(root:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            if v.Name:lower():find(keyword:lower()) then
                table.insert(found, v)
            end
        end
    end
    return found
end

local R = {
    Gen = {
        RepairEvent = GetRemote("Generator","RepairEvent"),
    },
    Game = {
        Start       = GetRemote("Game","Start"),
        KillerMorph = GetRemote("Game","KillerMorph"),
        RoundEnd    = GetRemote("Game","RoundEnd"),
    },
    Items = {
        ParryDagger = GetRemote("Items","Parrying Dagger","parry")
                   or GetRemote("Items","Parrying Dagger","Parry")
                   or GetRemote("Items","ParryingDagger","parry"),
        Heal        = GetRemote("Items","Medkit","heal")
                   or FindRemoteDeep(Remotes,"HealEvent")
                   or FindRemoteDeep(Remotes,"heal"),
    },
    Parry = {},
    Heal  = {},
}

-- Aggressive remote discovery
do
    if not R.Items.ParryDagger then
        for _, name in ipairs({"parry","Parry","ParryEvent","block","Block","parryevent"}) do
            local f = FindRemoteDeep(Remotes, name)
            if f then R.Items.ParryDagger = f; break end
        end
    end

    for _, r in ipairs(FindRemotesByKeyword(Remotes,"parry")) do
        table.insert(R.Parry, r)
    end
    for _, r in ipairs(FindRemotesByKeyword(Remotes,"block")) do
        table.insert(R.Parry, r)
    end
    for _, r in ipairs(FindRemotesByKeyword(Remotes,"dodge")) do
        table.insert(R.Parry, r)
    end

    if not R.Items.Heal then
        for _, name in ipairs({
            "HealEvent","heal","Heal","MedkitHeal","selfheal",
            "SelfHeal","Medkit","UseItem","useitem",
        }) do
            local f = FindRemoteDeep(Remotes, name)
            if f then R.Items.Heal = f; break end
        end
        if not R.Items.Heal then
            local h = FindRemotesByKeyword(Remotes,"heal")
            if #h > 0 then R.Items.Heal = h[1] end
        end
    end

    for _, r in ipairs(FindRemotesByKeyword(Remotes,"heal")) do
        table.insert(R.Heal, r)
    end
end

Log("Parry remote: "..(R.Items.ParryDagger and R.Items.ParryDagger:GetFullName() or "nil"))
Log("Heal remote:  "..(R.Items.Heal and R.Items.Heal:GetFullName() or "nil"))
Log("Parry remotes found: "..#R.Parry)
Log("Heal remotes found:  "..#R.Heal)

-- ═══════════════════════════════════════════
-- WORKSPACE REFS
-- ═══════════════════════════════════════════
local WS = {
    Map        = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then WS.Generators = WS.Map:FindFirstChild("Generators") end

local function GetPallets()
    local list = {}
    if not WS.Map then return list end
    for _, v in ipairs(WS.Map:GetChildren()) do
        if v:IsA("Model") and v.Name == "Palletwrong" then
            table.insert(list, v)
        end
    end
    return list
end

local function GetVaults()
    local list = {}
    if not WS.Map then return list end
    for _, v in ipairs(WS.Map:GetChildren()) do
        if v:IsA("Model") and v.Name == "Window" then
            table.insert(list, v)
        end
    end
    return list
end

local function GetHooks()
    local list = {}
    if not WS.Map then return list end
    for _, v in ipairs(WS.Map:GetChildren()) do
        if v:IsA("Model") and v.Name == "Hook" then
            table.insert(list, v)
        end
    end
    return list
end

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- ESP
    ESP_Generators=false, ESP_Killer=false, ESP_Survivors=false,
    ESP_Items=false, ESP_Weapons=false, ESP_Clones=false,
    ESP_Pallets=false, ESP_Vaults=false, ESP_Hooks=false,
    ESP_ShowHP=true, ESP_MaxDistance=500,
    ESP_ShowDistance=true, ESP_ShowName=true,

    Color_Killer    = Color3.fromRGB(255,40,40),
    Color_Survivor  = Color3.fromRGB(60,120,255),
    Color_Generator = Color3.fromRGB(255,200,60),
    Color_Item      = Color3.fromRGB(120,255,120),
    Color_Weapon    = Color3.fromRGB(255,120,220),
    Color_Clone     = Color3.fromRGB(180,180,180),
    Color_Pallet    = Color3.fromRGB(255,165,0),
    Color_Vault     = Color3.fromRGB(0,255,200),
    Color_Hook      = Color3.fromRGB(200,100,100),

    -- Movement
    WalkSpeed=16, JumpPower=50, NoClip=false, InfJump=false,

    -- Visuals
    FullBright=false, NoFog=false, NoShadows=false, ClearWeather=false,
    LowGraphics=false, FOV=70, ClockTime=14,
    RemoveBlur=false, RemoveCC=false, Freecam=false, HideName=false,
    NoSound=false, MuteBGMusic=false, NoParticles=false,

    -- Misc
    AutoRejoin=false, AntiAFK=true,

    -- Survivor
    Invisible=false, InvisibleHotkey=Enum.KeyCode.X,
    SurvSpeedBoost=false, SurvSpeedValue=24,

    -- Auto Parry
    AutoParry=false, ParryRange=20, ParryMode="Remote+Key",
    ParryCooldown=0.25,
    ParryOnHit=true,
    ShowParryRing=false, ParryRingColor="Red", ParryDebug=false,
    ParryFireRate=0.08,

    -- Auto Heal
    AutoHeal=false, AutoHealThreshold=60,
    AutoHealDelay=1.5, AutoHealMethod="All",

    -- Combat
    NoFallDamage=false, FleeKiller=false, FleeDistance=40,
    GodMode=false,

    -- Gen
    AutoGenRush=false, AutoGenMode="Instant",
    AutoSkillcheck=false, ShowGenProgress=false,

    -- HP
    ShowOwnHP=false,

    -- Match
    IsKiller=false, MatchActive=false,

    -- Caches
    ESPCache={},
    LightBackup={}, MutedSounds={},
    SavedTransparencies={},

    -- Connections
    NoClipConn=nil, InfJumpConn=nil, FreecamConn=nil,
    NoFallConn=nil, FleeConn=nil, GodModeConn=nil,
    AutoParryConn=nil, AutoParryHitConn=nil,
    AutoHealConn=nil, InvisibleConn=nil,
    SkillcheckGUIConn=nil,
    ParryKillerWatchConn=nil,

    -- Timers
    LastParryTime=0, LastHealTime=0, HealCount=0,

    -- Misc references
    GenProgressGuis={}, ParryRing=nil, HPGui=nil,
    HPText=nil, HPBar=nil,
    CachedKiller=nil, KillerCacheTime=0,
    CurrentTargetGen=nil,
}

-- ═══════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════
local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Notify(t, c, d)
    pcall(function()
        Rayfield:Notify({
            Title    = tostring(t or ""),
            Content  = tostring(c or ""),
            Duration = tonumber(d) or 4,
            Image    = 4483345998,
        })
    end)
end

-- ═══════════════════════════════════════════
-- ROLE DETECTION
-- ═══════════════════════════════════════════
local Role = {}
local KILLER_ATTRS = {
    "TerrorRadius","Chasemusic","IsChasing","BloodLust",
    "SuspenseRadius","CarriedSurvivorId","IsCarrying",
    "killercarry","killerhook","survivorcarry","survivorhook",
    "kings_scourge","AbyssalCovenant",
    "InAttack","Attacking","SwingActive","SwingCooldown",
}

function Role.IsKillerChar(char)
    if not char then return false end
    local count = 0
    for _, attr in ipairs(KILLER_ATTRS) do
        if char:GetAttribute(attr) ~= nil then count = count + 1 end
    end
    return count >= 2
end

function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones and char:IsDescendantOf(WS.Clones) then return true end
    return false
end

function Role.FindKiller()
    if State.CachedKiller then
        local p = State.CachedKiller
        if not p.Parent or not p.Character or not p.Character.Parent
           or not Role.IsKillerChar(p.Character) then
            State.CachedKiller = nil
        end
    end
    if State.CachedKiller and (tick()-State.KillerCacheTime) < 2 then
        return State.CachedKiller
    end
    State.CachedKiller = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not Role.IsFake(p.Character) then
            if Role.IsKillerChar(p.Character) then
                State.CachedKiller = p
                State.KillerCacheTime = tick()
                return p
            end
        end
    end
    return nil
end

function Role.ResetKillerCache()
    State.CachedKiller = nil
    State.KillerCacheTime = 0
end

-- ═══════════════════════════════════════════
-- ESP v2
-- ═══════════════════════════════════════════
local ESP = {}

local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP_v2")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "X0_ESP_v2"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.DisplayOrder = 999
    ESPGui.Parent = GuiParent()
end

local ESPRenderConn = nil

local function GetRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp end
        local torso = obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
        if torso then return torso end
        if obj.PrimaryPart then return obj.PrimaryPart end
        return obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

local function GetHumanoid(obj)
    if not obj then return nil end
    if obj:IsA("Model") then return obj:FindFirstChildOfClass("Humanoid") end
    return nil
end

local function MakeESPEntry(obj, label, color, isChar)
    local rootPart = GetRootPart(obj)
    if not rootPart then return nil end

    local hl = Instance.new("Highlight")
    hl.Name = "X0_HL"
    hl.Adornee = obj
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = isChar and 0.5 or 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Name = "X0_BB"
    bb.Size = UDim2.new(0, 200, 0, isChar and 75 or 55)
    bb.StudsOffsetWorldSpace = Vector3.zero
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = State.ESP_MaxDistance
    bb.ResetOnSpawn = false
    bb.ClipsDescendants = false
    bb.Adornee = rootPart
    bb.Parent = ESPGui

    local nameL = Instance.new("TextLabel", bb)
    nameL.Name = "NameL"
    nameL.Size = UDim2.new(1,0,0,22); nameL.Position = UDim2.new(0,0,0,0)
    nameL.BackgroundTransparency = 1; nameL.Text = label
    nameL.TextColor3 = color; nameL.TextStrokeTransparency = 0.4
    nameL.TextStrokeColor3 = Color3.new(0,0,0); nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 14; nameL.Visible = State.ESP_ShowName

    local distL = Instance.new("TextLabel", bb)
    distL.Name = "DistL"
    distL.Size = UDim2.new(1,0,0,16); distL.Position = UDim2.new(0,0,0,22)
    distL.BackgroundTransparency = 1; distL.Text = "0m"
    distL.TextColor3 = Color3.fromRGB(220,220,220); distL.TextStrokeTransparency = 0.4
    distL.TextStrokeColor3 = Color3.new(0,0,0); distL.Font = Enum.Font.Gotham
    distL.TextSize = 12; distL.Visible = State.ESP_ShowDistance

    local hpL = nil
    if isChar then
        hpL = Instance.new("TextLabel", bb)
        hpL.Name = "HPL"
        hpL.Size = UDim2.new(1,0,0,16); hpL.Position = UDim2.new(0,0,0,38)
        hpL.BackgroundTransparency = 1; hpL.Text = "[HP] ?"
        hpL.TextColor3 = Color3.fromRGB(255,100,100); hpL.TextStrokeTransparency = 0.4
        hpL.TextStrokeColor3 = Color3.new(0,0,0); hpL.Font = Enum.Font.GothamBold
        hpL.TextSize = 12; hpL.Visible = State.ESP_ShowHP
    end

    return {
        rootPart  = rootPart,
        adornee   = obj,
        label     = label,
        color     = color,
        isChar    = isChar,
        highlight = hl,
        bb        = bb,
        nameLabel = nameL,
        distLabel = distL,
        hpLabel   = hpL,
    }
end

function ESP.Add(obj, label, color, isChar)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local entry = MakeESPEntry(obj, label, color, isChar or false)
    if entry then State.ESPCache[obj] = entry end
end

function ESP.Remove(obj)
    local e = State.ESPCache[obj]
    if not e then return end
    if e.highlight then pcall(function() e.highlight:Destroy() end) end
    if e.bb then pcall(function() e.bb:Destroy() end) end
    State.ESPCache[obj] = nil
end

function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Remove(obj) end
    State.ESPCache = {}
end

local function StartESPRender()
    if ESPRenderConn then ESPRenderConn:Disconnect() end
    ESPRenderConn = RunService.RenderStepped:Connect(function()
        local localChar = LocalPlayer.Character
        local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")
        local localPos  = localHRP and localHRP.Position or Vector3.zero
        local toRemove  = {}

        for obj, e in pairs(State.ESPCache) do
            if not obj or not obj.Parent then
                table.insert(toRemove, obj)
            else
                local rp = GetRootPart(obj)
                if not rp then
                    table.insert(toRemove, obj)
                else
                    if e.rootPart ~= rp then
                        e.rootPart = rp
                        if e.bb      then pcall(function() e.bb.Adornee = rp end) end
                        if e.highlight then pcall(function() e.highlight.Adornee = obj end) end
                    end

                    if e.bb then
                        pcall(function()
                            e.bb.Adornee    = rp
                            e.bb.MaxDistance = State.ESP_MaxDistance
                        end)
                    end
                    if e.highlight then
                        pcall(function() e.highlight.Adornee = obj end)
                    end

                    local dist    = (rp.Position - localPos).Magnitude
                    local visible = dist <= State.ESP_MaxDistance

                    if e.distLabel then
                        pcall(function()
                            e.distLabel.Text    = math.floor(dist) .. "m"
                            e.distLabel.Visible = State.ESP_ShowDistance
                        end)
                    end
                    if e.bb        then pcall(function() e.bb.Enabled        = visible end) end
                    if e.highlight then pcall(function() e.highlight.Enabled  = visible end) end

                    if e.isChar and e.hpLabel then
                        pcall(function()
                            local hum = GetHumanoid(obj)
                            if hum then
                                local hp  = math.floor(hum.Health)
                                local max = math.floor(hum.MaxHealth)
                                e.hpLabel.Text = "[HP] "..hp.."/"..max
                                local pct = (max > 0) and (hp/max) or 0
                                if pct > 0.6 then
                                    e.hpLabel.TextColor3 = Color3.fromRGB(60,220,60)
                                elseif pct > 0.3 then
                                    e.hpLabel.TextColor3 = Color3.fromRGB(255,180,60)
                                else
                                    e.hpLabel.TextColor3 = Color3.fromRGB(255,50,50)
                                end
                                e.hpLabel.Visible = State.ESP_ShowHP
                            end
                        end)
                    end
                    if e.nameLabel then
                        pcall(function() e.nameLabel.Visible = State.ESP_ShowName end)
                    end
                end
            end
        end

        for _, obj in ipairs(toRemove) do ESP.Remove(obj) end
    end)
end

StartESPRender()

function ESP.ScanPlayers()
    local killer = Role.FindKiller()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent
           and not Role.IsFake(p.Character) then
            local char = p.Character
            local isK  = (p == killer)
            if isK then
                if State.ESP_Killer then
                    if not State.ESPCache[char] then
                        ESP.Add(char, "[KILLER] "..p.Name, State.Color_Killer, true)
                    end
                else
                    if State.ESPCache[char] then ESP.Remove(char) end
                end
            else
                if State.ESP_Survivors then
                    if not State.ESPCache[char] then
                        ESP.Add(char, "[SURV] "..p.Name, State.Color_Survivor, true)
                    end
                else
                    if State.ESPCache[char] then ESP.Remove(char) end
                end
            end
        end
    end
end

function ESP.ScanGens()
    if not WS.Generators then return end
    for _, g in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators then
            if not State.ESPCache[g] then
                local prog = g:GetAttribute("RepairProgress") or 0
                ESP.Add(g, "[GEN] "..math.floor(prog).."%", State.Color_Generator, false)
            end
        else
            if State.ESPCache[g] then ESP.Remove(g) end
        end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons then
            if not State.ESPCache[w] then
                ESP.Add(w, "[WEP] "..w.Name, State.Color_Weapon, false)
            end
        else
            if State.ESPCache[w] then ESP.Remove(w) end
        end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones then
            if not State.ESPCache[c] then
                ESP.Add(c, "[CLONE]", State.Color_Clone, false)
            end
        else
            if State.ESPCache[c] then ESP.Remove(c) end
        end
    end
end

function ESP.ScanPallets()
    for _, p in ipairs(GetPallets()) do
        if State.ESP_Pallets then
            if not State.ESPCache[p] then
                ESP.Add(p, "[PALLET]", State.Color_Pallet, false)
            end
        else
            if State.ESPCache[p] then ESP.Remove(p) end
        end
    end
end

function ESP.ScanVaults()
    for _, w in ipairs(GetVaults()) do
        if State.ESP_Vaults then
            if not State.ESPCache[w] then
                ESP.Add(w, "[VAULT]", State.Color_Vault, false)
            end
        else
            if State.ESPCache[w] then ESP.Remove(w) end
        end
    end
end

function ESP.ScanHooks()
    for _, h in ipairs(GetHooks()) do
        if State.ESP_Hooks then
            if not State.ESPCache[h] then
                ESP.Add(h, "[HOOK]", State.Color_Hook, false)
            end
        else
            if State.ESPCache[h] then ESP.Remove(h) end
        end
    end
end

function ESP.ScanItems()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and (o:GetAttribute("Item") or o:GetAttribute("Pickup")) then
            if State.ESP_Items then
                if not State.ESPCache[o] then
                    ESP.Add(o, "[ITEM] "..o.Name, State.Color_Item, false)
                end
            else
                if State.ESPCache[o] then ESP.Remove(o) end
            end
        end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers(); ESP.ScanGens(); ESP.ScanWeapons()
    ESP.ScanClones();  ESP.ScanPallets(); ESP.ScanVaults()
    ESP.ScanHooks();   ESP.ScanItems()
end

task.spawn(function()
    while task.wait(1.5) do pcall(ESP.RefreshAll) end
end)

CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Remove(p.Character) end
    if State.CachedKiller == p then Role.ResetKillerCache() end
end, "PR")

local function HookPlayer(p)
    if p == LocalPlayer then return end
    CM:Add(p.CharacterAdded, function()
        Role.ResetKillerCache()
        task.wait(0.5); ESP.RefreshAll()
    end, "CA:"..p.Name)
    CM:Add(p.CharacterRemoving, function(char)
        ESP.Remove(char); Role.ResetKillerCache()
    end, "CR:"..p.Name)
end

for _, p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
CM:Add(Players.PlayerAdded, function(p) HookPlayer(p) end, "PA")

task.spawn(function()
    while task.wait(3) do
        if State.ESP_Killer or State.ESP_Survivors then
            local prev = State.CachedKiller
            Role.ResetKillerCache()
            local new = Role.FindKiller()
            if new ~= prev then ESP.ClearAll(); ESP.RefreshAll() end
        end
    end
end)

-- ═══════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════
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
    local h = Move.GetHuman(); if h then h.WalkSpeed = State.WalkSpeed end
end
function Move.Jump()
    local h = Move.GetHuman()
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end

function Move.SetNoClip(e)
    if State.NoClipConn then
        pcall(function() State.NoClipConn:Disconnect() end)
        State.NoClipConn = nil
    end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer.Character
            if ch then
                for _, p in ipairs(ch:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
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
    if not WS.Generators then Notify("TP","No gens",3); return end
    local hrp = Move.GetHRP(); if not hrp then return end
    local best, bd = nil, math.huge
    for _, g in ipairs(WS.Generators:GetChildren()) do
        local p = g:FindFirstChild("HitBox") or g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then
            local d = (p.Position-hrp.Position).Magnitude
            if d < bd then bd=d; best=p end
        end
    end
    if best then hrp.CFrame = best.CFrame + Vector3.new(0,4,0); Notify("TP","Done",3) end
end

function Move.ToPlayer()
    if tpTarget == "" then Notify("TP","Enter name",3); return end
    local t = Players:FindFirstChild(tpTarget)
    if not t or not t.Character then Notify("TP","Not found",3); return end
    local hrp  = Move.GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Notify("TP","Done",3)
    end
end

function Move.NearestExit()
    local hrp = Move.GetHRP(); if not hrp then return end
    local best, bd = nil, math.huge
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and
           (o.Name:lower():find("exit") or o.Name:lower():find("gate")) then
            local d = (o.Position-hrp.Position).Magnitude
            if d < bd then bd=d; best=o end
        end
    end
    if best then hrp.CFrame = best.CFrame + Vector3.new(0,4,0); Notify("TP","Exit",3) end
end

-- ═══════════════════════════════════════════
-- VISUALS
-- ═══════════════════════════════════════════
local Vis = {}
function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient        = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness     = Lighting.Brightness,
        ClockTime      = Lighting.ClockTime,
        FogEnd         = Lighting.FogEnd,
        FogStart       = Lighting.FogStart,
        GlobalShadows  = Lighting.GlobalShadows,
    }
end
function Vis.RestoreLight()
    for k, v in pairs(State.LightBackup) do pcall(function() Lighting[k] = v end) end
end
function Vis.FullBright(e)
    Vis.BackupLight()
    if e then
        Lighting.Ambient        = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness     = 2
        Lighting.ClockTime      = 14
        Lighting.GlobalShadows  = false
    else Vis.RestoreLight() end
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
        Lighting.FogEnd = State.LightBackup.FogEnd or 100000
    end
end
function Vis.NoShadows(e) Vis.BackupLight(); Lighting.GlobalShadows = not e end
function Vis.ClearWx(e)
    if e then
        for _, o in ipairs(Lighting:GetDescendants()) do
            if o:IsA("Atmosphere") then o.Density=0; o.Haze=0 end
        end
    end
end
function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel = e
            and Enum.QualityLevel.Level01
            or  Enum.QualityLevel.Automatic
    end)
end
function Vis.SetFOV(f)
    if Camera then Camera.FieldOfView = tonumber(f) or 70 end
end
function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end
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
    local ch = LocalPlayer.Character; if not ch then return end
    local head = ch:FindFirstChild("Head"); if not head then return end
    for _, g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end
function Vis.MuteAll(e)
    if e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") then
                table.insert(State.MutedSounds, {s=s, v=s.Volume})
                s.Volume = 0
            end
        end
    else
        for _, en in ipairs(State.MutedSounds) do
            if en.s and en.s.Parent then en.s.Volume = en.v end
        end
        State.MutedSounds = {}
    end
end
function Vis.MuteBG(e)
    local bg = Workspace:FindFirstChild("BackgroundSounds"); if not bg then return end
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
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then mv = mv + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
            pos = pos + mv * 2
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end
function Vis.ServerHop()
    pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"..tostring(game.PlaceId)
            .."/servers/Public?sortOrder=Asc&limit=100"
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
        Notify("Server Hop","No server found",4)
    end)
end

-- ═══════════════════════════════════════════
-- HP BAR
-- ═══════════════════════════════════════════
local HP = {}
function HP.Create()
    if State.HPGui then pcall(function() State.HPGui:Destroy() end); State.HPGui=nil end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_HP"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.Parent = GuiParent()
    local frame = Instance.new("Frame", sg)
    frame.Size = UDim2.new(0,220,0,55)
    frame.Position = UDim2.new(0,15,0.5,-25)
    frame.BackgroundColor3 = Color3.fromRGB(20,20,25)
    frame.BackgroundTransparency = 0.3; frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke", frame)
    st.Color = Color3.fromRGB(255,100,100); st.Thickness = 1.5
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1,-10,0,18); title.Position = UDim2.new(0,5,0,3)
    title.BackgroundTransparency = 1; title.Text = "[HP] HEALTH"
    title.TextColor3 = Color3.fromRGB(255,220,220); title.Font = Enum.Font.GothamBold
    title.TextSize = 12; title.TextXAlignment = Enum.TextXAlignment.Left
    local hpText = Instance.new("TextLabel", frame)
    hpText.Size = UDim2.new(1,-10,0,15); hpText.Position = UDim2.new(0,5,0,20)
    hpText.BackgroundTransparency = 1; hpText.Text = "100/100"
    hpText.TextColor3 = Color3.fromRGB(255,255,255); hpText.Font = Enum.Font.GothamBold
    hpText.TextSize = 14; hpText.TextXAlignment = Enum.TextXAlignment.Right
    local barBg = Instance.new("Frame", frame)
    barBg.Size = UDim2.new(1,-10,0,12); barBg.Position = UDim2.new(0,5,1,-17)
    barBg.BackgroundColor3 = Color3.fromRGB(40,40,45); barBg.BorderSizePixel = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0,3)
    local barFill = Instance.new("Frame", barBg)
    barFill.Size = UDim2.new(1,0,1,0)
    barFill.BackgroundColor3 = Color3.fromRGB(60,220,60); barFill.BorderSizePixel = 0
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0,3)
    State.HPGui = sg; State.HPText = hpText; State.HPBar = barFill
end

function HP.Update()
    if not State.ShowOwnHP or not State.HPGui then return end
    local ch = LocalPlayer.Character
    local h  = ch and ch:FindFirstChildOfClass("Humanoid")
    if h then
        local hp  = math.floor(h.Health)
        local max = math.floor(h.MaxHealth)
        local pct = (max > 0) and (hp/max) or 0
        if State.HPText then State.HPText.Text = hp.."/"..max end
        if State.HPBar then
            State.HPBar.Size = UDim2.new(pct,0,1,0)
            if pct > 0.6 then
                State.HPBar.BackgroundColor3 = Color3.fromRGB(60,220,60)
            elseif pct > 0.3 then
                State.HPBar.BackgroundColor3 = Color3.fromRGB(255,180,60)
            else
                State.HPBar.BackgroundColor3 = Color3.fromRGB(255,50,50)
            end
        end
    end
end

function HP.SetVisible(v)
    State.ShowOwnHP = v
    if v then
        if not State.HPGui then HP.Create() end
        HP.Update()
    else
        if State.HPGui then pcall(function() State.HPGui:Destroy() end); State.HPGui=nil end
    end
end

CM:Add(RunService.Heartbeat, function()
    if State.ShowOwnHP then pcall(HP.Update) end
end, "HP.HB")

-- ═══════════════════════════════════════════
-- SURVIVOR ABILITIES
-- ═══════════════════════════════════════════
local Surv = {}

function Surv.SetInvisible(enable)
    if State.InvisibleConn then
        pcall(function() State.InvisibleConn:Disconnect() end)
        State.InvisibleConn = nil
    end
    local char = LocalPlayer.Character; if not char then return end
    if not enable then
        for part, orig in pairs(State.SavedTransparencies) do
            if part and part.Parent then
                pcall(function()
                    part.Transparency = orig
                    part.LocalTransparencyModifier = 0
                end)
            end
        end
        State.SavedTransparencies = {}
        pcall(function() char:SetAttribute("Untargettable", false) end)
        return
    end
    local function applyInvisible()
        local c = LocalPlayer.Character; if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                if State.SavedTransparencies[p] == nil then
                    State.SavedTransparencies[p] = p.Transparency
                end
                pcall(function() p.Transparency = 1; p.CanQuery = false end)
            elseif p:IsA("Decal") or p:IsA("Texture") then
                if State.SavedTransparencies[p] == nil then
                    State.SavedTransparencies[p] = p.Transparency
                end
                pcall(function() p.Transparency = 1 end)
            end
        end
        pcall(function() c:SetAttribute("Untargettable", true) end)
        local head = c:FindFirstChild("Head")
        if head then
            for _, g in ipairs(head:GetChildren()) do
                if g:IsA("BillboardGui") then pcall(function() g.Enabled = false end) end
            end
        end
    end
    applyInvisible()
    State.InvisibleConn = RunService.Heartbeat:Connect(function()
        if not State.Invisible then return end
        local c = LocalPlayer.Character; if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.Transparency < 1 then
                if State.SavedTransparencies[p] == nil then
                    State.SavedTransparencies[p] = p.Transparency
                end
                pcall(function() p.Transparency = 1 end)
            end
        end
        pcall(function() c:SetAttribute("Untargettable", true) end)
    end)
end

function Surv.SetSpeedBoost(enable)
    local h = Move.GetHuman(); if not h then return end
    h.WalkSpeed = enable and State.SurvSpeedValue or State.WalkSpeed
end

function Surv.SetNoFall(enable)
    if State.NoFallConn then
        pcall(function() State.NoFallConn:Disconnect() end)
        State.NoFallConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h and enable then
            pcall(function()
                h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end)
        elseif h then
            pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
        end
    end
end

function Surv.SetGodMode(enable)
    if State.GodModeConn then
        pcall(function() State.GodModeConn:Disconnect() end)
        State.GodModeConn = nil
    end
    if enable then
        State.GodModeConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character; if not char then return end
            pcall(function()
                char:SetAttribute("Iframes",      true)
                char:SetAttribute("Untargettable", true)
                char:SetAttribute("Knocked",       false)
                char:SetAttribute("Parry",         true)
            end)
            local h = char:FindFirstChildOfClass("Humanoid")
            if h and h.Health < h.MaxHealth then
                pcall(function() h.Health = h.MaxHealth end)
            end
        end)
    else
        local char = LocalPlayer.Character
        if char then
            pcall(function()
                char:SetAttribute("Iframes",      false)
                char:SetAttribute("Untargettable", false)
                char:SetAttribute("Parry",         false)
            end)
        end
    end
end

function Surv.SetFleeKiller(enable)
    if State.FleeConn then
        pcall(function() State.FleeConn:Disconnect() end)
        State.FleeConn = nil
    end
    if enable then
        local lastFlee = 0
        State.FleeConn = RunService.Heartbeat:Connect(function()
            if tick()-lastFlee < 0.5 then return end
            local hrp = Move.GetHRP(); if not hrp then return end
            local killer = Role.FindKiller()
            if killer and killer.Character then
                local khrp = killer.Character:FindFirstChild("HumanoidRootPart")
                if khrp then
                    local dist = (khrp.Position-hrp.Position).Magnitude
                    if dist < State.FleeDistance then
                        local dir = hrp.Position - khrp.Position
                        if dir.Magnitude > 0.1 then
                            dir = Vector3.new(dir.X,0,dir.Z).Unit
                            local newPos = hrp.Position + dir*(State.FleeDistance+15)
                            pcall(function() hrp.CFrame = CFrame.new(newPos, newPos+dir) end)
                            lastFlee = tick()
                        end
                    end
                end
            end
        end)
    end
end

function Surv.UpdateParryRing()
    if State.ParryRing then
        pcall(function() State.ParryRing:Destroy() end)
        State.ParryRing = nil
    end
    if not State.ShowParryRing then return end
    local ring = Instance.new("Part")
    ring.Name = "ParryRing"
    ring.Size = Vector3.new(0.2, State.ParryRange*2, State.ParryRange*2)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true; ring.CanCollide = false
    ring.CanQuery = false; ring.CanTouch = false
    ring.Material = Enum.Material.Neon; ring.Transparency = 0.7
    local colors = {
        Red=Color3.fromRGB(255,40,40), Blue=Color3.fromRGB(40,120,255),
        Green=Color3.fromRGB(40,255,40), Yellow=Color3.fromRGB(255,220,40),
        Purple=Color3.fromRGB(180,40,255), White=Color3.fromRGB(255,255,255),
    }
    ring.Color = colors[State.ParryRingColor] or colors.Red
    ring.Parent = Workspace
    State.ParryRing = ring
    task.spawn(function()
        while State.ParryRing == ring and ring.Parent do
            local h = Move.GetHRP()
            if h then
                ring.CFrame = CFrame.new(h.Position - Vector3.new(0,2.5,0))
                           * CFrame.Angles(0,0,math.rad(90))
            end
            task.wait()
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO PARRY — Fixed & Aggressive
-- ═══════════════════════════════════════════
local function FireParryRemotes()
    -- Primary parry remote
    if R.Items.ParryDagger then
        pcall(function() R.Items.ParryDagger:FireServer() end)
    end
    -- All discovered parry/block remotes
    for _, remote in ipairs(R.Parry) do
        pcall(function() remote:FireServer() end)
    end
end

local function FireParryKeys()
    for _, key in ipairs({
        Enum.KeyCode.F, Enum.KeyCode.E,
        Enum.KeyCode.Q, Enum.KeyCode.R,
    }) do
        pcall(function()
            VirtualInputMgr:SendKeyEvent(true,  key, false, game)
        end)
        task.delay(State.ParryFireRate, function()
            pcall(function()
                VirtualInputMgr:SendKeyEvent(false, key, false, game)
            end)
        end)
    end
end

local function SetParryAttribute(v)
    local char = LocalPlayer.Character; if not char then return end
    pcall(function()
        char:SetAttribute("Parry",      v)
        char:SetAttribute("IsParrying", v)
        char:SetAttribute("Blocking",   v)
        char:SetAttribute("Iframes",    v)
    end)
end

local function DoParry(reason)
    local now = tick()
    if now - State.LastParryTime < State.ParryCooldown then return end
    State.LastParryTime = now

    if State.ParryDebug then
        Log("Parry fired | reason="..tostring(reason).." t="..string.format("%.3f",now))
    end

    -- Attribute parry (instant, server-side)
    SetParryAttribute(true)
    task.delay(0.25, function() SetParryAttribute(false) end)

    -- Remote fire
    if State.ParryMode ~= "Key Only" then
        FireParryRemotes()
    end

    -- Key simulation
    if State.ParryMode ~= "Remote Only" then
        task.spawn(FireParryKeys)
    end
end

function Surv.SetAutoParry(enable)
    -- Disconnect all previous parry connections
    if State.AutoParryConn then
        pcall(function() State.AutoParryConn:Disconnect() end)
        State.AutoParryConn = nil
    end
    if State.AutoParryHitConn then
        pcall(function() State.AutoParryHitConn:Disconnect() end)
        State.AutoParryHitConn = nil
    end
    if State.ParryKillerWatchConn then
        pcall(function() State.ParryKillerWatchConn:Disconnect() end)
        State.ParryKillerWatchConn = nil
    end

    if not enable then return end

    -- Layer 1: Proximity + swing attribute watcher (Heartbeat)
    State.AutoParryConn = RunService.Heartbeat:Connect(function()
        if not State.AutoParry then return end
        local hrp = Move.GetHRP(); if not hrp then return end
        local killer = Role.FindKiller()
        if not killer or not killer.Character then return end
        local khrp = killer.Character:FindFirstChild("HumanoidRootPart")
        if not khrp then return end

        local dist = (khrp.Position - hrp.Position).Magnitude

        -- Proximity trigger
        if dist <= State.ParryRange then
            DoParry("proximity")
        end

        -- Swing attribute trigger (wider range)
        local isAtk = killer.Character:GetAttribute("InAttack")
                   or killer.Character:GetAttribute("Attacking")
                   or killer.Character:GetAttribute("SwingActive")
                   or killer.Character:GetAttribute("IsSwinging")
                   or killer.Character:GetAttribute("Chasing")
        if isAtk and dist <= State.ParryRange * 2 then
            State.LastParryTime = 0 -- force immediate fire on swing
            DoParry("swing_attr")
        end
    end)

    -- Layer 2: On damage received
    if State.ParryOnHit then
        local function HookHumanoid(hum)
            if not hum then return end
            local prevHP = hum.Health
            if State.AutoParryHitConn then
                pcall(function() State.AutoParryHitConn:Disconnect() end)
            end
            State.AutoParryHitConn = hum.HealthChanged:Connect(function(newHP)
                if newHP < prevHP then
                    State.LastParryTime = 0 -- bypass cooldown on real hit
                    DoParry("health_drop")
                    task.delay(0.1, function() DoParry("health_drop_retry") end)
                end
                prevHP = newHP
            end)
        end
        local char = LocalPlayer.Character
        if char then HookHumanoid(char:FindFirstChildOfClass("Humanoid")) end
        -- Re-hook after respawn (handled in CharacterAdded)
        State._hookHumanoid = HookHumanoid
    end

    -- Layer 3: Watch killer for attribute changes via GetPropertyChangedSignal workaround
    task.spawn(function()
        while State.AutoParry do
            task.wait(0.05)
            local killer = Role.FindKiller()
            if killer and killer.Character then
                local kchar = killer.Character
                local hrp   = Move.GetHRP()
                local khrp  = kchar:FindFirstChild("HumanoidRootPart")
                if hrp and khrp then
                    local dist = (khrp.Position - hrp.Position).Magnitude
                    if dist <= State.ParryRange * 1.8 then
                        for _, attrName in ipairs({
                            "InAttack","Attacking","SwingActive","SwingCooldown",
                            "IsSwinging","hitlag","HitStop",
                        }) do
                            local v = kchar:GetAttribute(attrName)
                            if v == true then
                                DoParry("poll_"..attrName)
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO HEAL — Fixed
-- ═══════════════════════════════════════════
local function DoHeal()
    local char = LocalPlayer.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local pct  = (hum.MaxHealth > 0) and (hum.Health / hum.MaxHealth * 100) or 100
    if pct >= State.AutoHealThreshold then return end
    if tick() - State.LastHealTime < State.AutoHealDelay then return end
    State.LastHealTime = tick()
    State.HealCount = State.HealCount + 1

    if State.AutoHealMethod == "Remote" or State.AutoHealMethod == "All" then
        if R.Items.Heal then pcall(function() R.Items.Heal:FireServer() end) end
        for _, r in ipairs(R.Heal) do
            pcall(function() r:FireServer() end)
        end
    end

    if State.AutoHealMethod == "Attribute" or State.AutoHealMethod == "All" then
        pcall(function()
            char:SetAttribute("IsHealing", true)
            char:SetAttribute("Healing",   true)
        end)
        task.delay(1, function()
            pcall(function()
                char:SetAttribute("IsHealing", false)
                char:SetAttribute("Healing",   false)
            end)
        end)
    end

    if State.AutoHealMethod == "All" then
        pcall(function() hum.Health = math.min(hum.Health+25, hum.MaxHealth) end)
        for _, key in ipairs({Enum.KeyCode.H, Enum.KeyCode.Z}) do
            pcall(function() VirtualInputMgr:SendKeyEvent(true,  key, false, game) end)
            task.delay(0.08, function()
                pcall(function() VirtualInputMgr:SendKeyEvent(false, key, false, game) end)
            end)
        end
    end

    Log(string.format("Heal #%d | HP %.0f/%.0f (%.0f%%)",
        State.HealCount, hum.Health, hum.MaxHealth, pct))
end

function Surv.SetAutoHeal(enable)
    if State.AutoHealConn then
        pcall(function() State.AutoHealConn:Disconnect() end)
        State.AutoHealConn = nil
    end
    State.HealCount = 0
    if not enable then return end
    State.AutoHealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        pcall(DoHeal)
    end)
end

-- AUTO SKILLCHECK
function Surv.SetAutoSkillcheck(enable)
    if State.SkillcheckGUIConn then
        pcall(function() State.SkillcheckGUIConn:Disconnect() end)
        State.SkillcheckGUIConn = nil
    end
    if not enable then
        local char = LocalPlayer.Character
        if char then
            local sc = char:FindFirstChild("Skillcheck-gen")
            if sc then pcall(function() sc.Disabled = false end) end
            pcall(function() char:SetAttribute("skillcheckfrequency", 1) end)
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui.Name:find("SkillCheckPromptGui") then
                    pcall(function() gui.Enabled = true end)
                end
            end
        end
        return
    end
    local function disableScript()
        local char = LocalPlayer.Character; if not char then return end
        local sc = char:FindFirstChild("Skillcheck-gen")
        if sc then pcall(function() sc.Disabled = true end) end
        pcall(function()
            char:SetAttribute("skillcheckfrequency", 0)
            char:SetAttribute("skillcheckspeed",     0)
        end)
    end
    disableScript()
    State.SkillcheckGUIConn = RunService.Heartbeat:Connect(function()
        if not State.AutoSkillcheck then return end
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name:find("SkillCheckPromptGui") and gui.Enabled then
                pcall(function() gui.Enabled = false end)
            end
        end
        local char = LocalPlayer.Character
        if char then
            local sc = char:FindFirstChild("Skillcheck-gen")
            if sc and not sc.Disabled then pcall(function() sc.Disabled = true end) end
            if char:GetAttribute("skillcheckfrequency") ~= 0 then
                pcall(function() char:SetAttribute("skillcheckfrequency", 0) end)
            end
        end
    end)
end

-- AUTO GEN RUSH
function Surv.SetAutoGenRush(enable)
    if enable then
        if not R.Gen.RepairEvent then
            Notify("Auto Gen","Missing remote",4)
            State.AutoGenRush = false; return
        end
        task.spawn(function()
            while State.AutoGenRush do
                task.wait(0.3)
                if WS.Generators then
                    local hrp = Move.GetHRP()
                    if hrp then
                        if State.CurrentTargetGen then
                            local prog = State.CurrentTargetGen:GetAttribute("RepairProgress") or 0
                            if prog >= 100 or not State.CurrentTargetGen.Parent then
                                State.CurrentTargetGen = nil
                            end
                        end
                        if not State.CurrentTargetGen then
                            local best, bd = nil, math.huge
                            for _, g in ipairs(WS.Generators:GetChildren()) do
                                local prog = g:GetAttribute("RepairProgress") or 0
                                if prog < 100 then
                                    local hb = g:FindFirstChild("HitBox")
                                    if hb then
                                        local d = (hb.Position-hrp.Position).Magnitude
                                        if d < bd then bd=d; best=g end
                                    end
                                end
                            end
                            State.CurrentTargetGen = best
                        end
                        if State.CurrentTargetGen then
                            local hb    = State.CurrentTargetGen:FindFirstChild("HitBox")
                            local point = State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                                       or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                                       or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")
                            if State.AutoGenMode == "Instant" then
                                if hb and (hb.Position-hrp.Position).Magnitude > 6 then
                                    pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0,3,0) end)
                                end
                                pcall(function()
                                    R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point)
                                end)
                            else
                                if hb and (hb.Position-hrp.Position).Magnitude <= 8 then
                                    pcall(function()
                                        R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            State.CurrentTargetGen = nil
        end)
    else
        State.CurrentTargetGen = nil
    end
end

-- GEN PROGRESS
function Surv.SetGenProgress(enable)
    for _, g in pairs(State.GenProgressGuis) do pcall(function() g:Destroy() end) end
    State.GenProgressGuis = {}
    if not enable or not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        local hb = gen:FindFirstChild("HitBox") or gen:FindFirstChildWhichIsA("BasePart")
        if hb then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = hb; bb.Size = UDim2.new(0,140,0,40)
            bb.StudsOffset = Vector3.new(0,5,0)
            bb.AlwaysOnTop = true; bb.LightInfluence = 0
            bb.MaxDistance = 500; bb.Parent = GuiParent()
            local lbl = Instance.new("TextLabel", bb)
            lbl.Size = UDim2.new(1,0,1,0); lbl.BackgroundTransparency = 1
            lbl.Text = "[GEN] 0%"; lbl.TextColor3 = Color3.fromRGB(255,220,60)
            lbl.TextStrokeTransparency = 0; lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 16
            table.insert(State.GenProgressGuis, bb)
            task.spawn(function()
                while bb.Parent and State.ShowGenProgress do
                    local prog    = gen:GetAttribute("RepairProgress") or 0
                    local players = gen:GetAttribute("PlayersRepairingCount") or 0
                    lbl.Text = string.format("[GEN] %d%% [%d]", math.floor(prog), players)
                    lbl.TextColor3 = (prog >= 100)
                        and Color3.fromRGB(60,255,60)
                        or  Color3.fromRGB(255,220,60)
                    task.wait(0.5)
                end
            end)
        end
    end
end

-- ═══════════════════════════════════════════
-- MATCH HOOKS
-- ═══════════════════════════════════════════
if R.Game.RoundEnd then
    CM:Add(R.Game.RoundEnd.Event, function()
        State.MatchActive = false
        ESP.ClearAll(); Role.ResetKillerCache()
        State.CurrentTargetGen = nil
    end, "RoundReset")
end
if R.Game.Start then
    CM:Add(R.Game.Start.Event, function()
        State.MatchActive = true; State.IsKiller = false
        Role.ResetKillerCache(); ESP.ClearAll()
        task.spawn(function()
            for i = 1, 15 do
                task.wait(1); Role.ResetKillerCache()
                if State.ESP_Killer or State.ESP_Survivors then ESP.RefreshAll() end
            end
        end)
    end, "MatchStart")
end
if R.Game.KillerMorph then
    CM:Add(R.Game.KillerMorph.Event, function()
        State.IsKiller = true; Role.ResetKillerCache()
    end, "KMorph")
end

CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end, "AntiAFK")

-- Periodic lighting refresh
task.spawn(function()
    while task.wait(5) do
        if State.FullBright then pcall(Vis.FullBright, true) end
        if State.NoFog      then pcall(Vis.NoFog, true)      end
    end
end)

-- ═══════════════════════════════════════════
-- REGISTER ALL KEYBINDS
-- ═══════════════════════════════════════════
KB.Register("Invisible", KB.Keys.Invisible, function()
    State.Invisible = not State.Invisible
    Surv.SetInvisible(State.Invisible)
    Notify("Invisible", State.Invisible and "ON" or "OFF", 2)
end)

KB.Register("AutoParry", KB.Keys.AutoParry, function()
    State.AutoParry = not State.AutoParry
    Surv.SetAutoParry(State.AutoParry)
    Notify("Auto Parry", State.AutoParry and "ON" or "OFF", 2)
end)

KB.Register("AutoHeal", KB.Keys.AutoHeal, function()
    State.AutoHeal = not State.AutoHeal
    Surv.SetAutoHeal(State.AutoHeal)
    Notify("Auto Heal", State.AutoHeal and "ON" or "OFF", 2)
end)

KB.Register("GodMode", KB.Keys.GodMode, function()
    State.GodMode = not State.GodMode
    Surv.SetGodMode(State.GodMode)
    Notify("God Mode", State.GodMode and "ON" or "OFF", 2)
end)

KB.Register("NoClip", KB.Keys.NoClip, function()
    State.NoClip = not State.NoClip
    Move.SetNoClip(State.NoClip)
    Notify("NoClip", State.NoClip and "ON" or "OFF", 2)
end)

KB.Register("InfJump", KB.Keys.InfJump, function()
    State.InfJump = not State.InfJump
    Move.SetInfJump(State.InfJump)
    Notify("Inf Jump", State.InfJump and "ON" or "OFF", 2)
end)

KB.Register("SpeedBoost", KB.Keys.SpeedBoost, function()
    State.SurvSpeedBoost = not State.SurvSpeedBoost
    Surv.SetSpeedBoost(State.SurvSpeedBoost)
    Notify("Speed Boost", State.SurvSpeedBoost and "ON" or "OFF", 2)
end)

KB.Register("FleeKiller", KB.Keys.FleeKiller, function()
    State.FleeKiller = not State.FleeKiller
    Surv.SetFleeKiller(State.FleeKiller)
    Notify("Flee Killer", State.FleeKiller and "ON" or "OFF", 2)
end)

KB.Register("FullBright", KB.Keys.FullBright, function()
    State.FullBright = not State.FullBright
    Vis.FullBright(State.FullBright)
    Notify("FullBright", State.FullBright and "ON" or "OFF", 2)
end)

KB.Register("Freecam", KB.Keys.Freecam, function()
    State.Freecam = not State.Freecam
    Vis.Freecam(State.Freecam)
    Notify("Freecam", State.Freecam and "ON" or "OFF", 2)
end)

KB.Register("AutoGenRush", KB.Keys.AutoGenRush, function()
    State.AutoGenRush = not State.AutoGenRush
    Surv.SetAutoGenRush(State.AutoGenRush)
    Notify("Auto Gen Rush", State.AutoGenRush and "ON" or "OFF", 2)
end)

KB.Register("AutoSkillcheck", KB.Keys.AutoSkillcheck, function()
    State.AutoSkillcheck = not State.AutoSkillcheck
    Surv.SetAutoSkillcheck(State.AutoSkillcheck)
    Notify("Auto Skillcheck", State.AutoSkillcheck and "ON" or "OFF", 2)
end)

KB.Register("GenProgress", KB.Keys.GenProgress, function()
    State.ShowGenProgress = not State.ShowGenProgress
    Surv.SetGenProgress(State.ShowGenProgress)
    Notify("Gen Progress", State.ShowGenProgress and "ON" or "OFF", 2)
end)

KB.Register("OwnHP", KB.Keys.OwnHP, function()
    HP.SetVisible(not State.ShowOwnHP)
    Notify("HP Bar", State.ShowOwnHP and "ON" or "OFF", 2)
end)

KB.Register("PanicClearESP", KB.Keys.PanicClearESP, function()
    State.ESP_Killer=false; State.ESP_Survivors=false
    State.ESP_Generators=false; State.ESP_Items=false
    State.ESP_Weapons=false; State.ESP_Clones=false
    State.ESP_Pallets=false; State.ESP_Vaults=false; State.ESP_Hooks=false
    ESP.ClearAll()
    Notify("Panic","ESP cleared",3)
end)

KB.Register("ForceParry", KB.Keys.ForceParry, function()
    State.LastParryTime = 0
    DoParry("manual_key")
    Notify("Parry","Fired!",1)
end)

KB.Register("ForceHeal", KB.Keys.ForceHeal, function()
    State.LastHealTime = 0
    pcall(DoHeal)
    Notify("Heal","Manual triggered",2)
end)

KB.Register("ServerHop", KB.Keys.ServerHop, function()
    Vis.ServerHop()
end)

-- ESP toggles via keys
KB.Register("KillerESP", KB.Keys.KillerESP, function()
    State.ESP_Killer = not State.ESP_Killer
    Role.ResetKillerCache()
    ESP.RefreshAll()
    Notify("Killer ESP", State.ESP_Killer and "ON" or "OFF", 2)
end)

KB.Register("SurvivorESP", KB.Keys.SurvivorESP, function()
    State.ESP_Survivors = not State.ESP_Survivors
    ESP.RefreshAll()
    Notify("Survivor ESP", State.ESP_Survivors and "ON" or "OFF", 2)
end)

KB.Register("GeneratorESP", KB.Keys.GeneratorESP, function()
    State.ESP_Generators = not State.ESP_Generators
    ESP.RefreshAll()
    Notify("Generator ESP", State.ESP_Generators and "ON" or "OFF", 2)
end)

KB.Register("PalletESP", KB.Keys.PalletESP, function()
    State.ESP_Pallets = not State.ESP_Pallets
    ESP.RefreshAll()
    Notify("Pallet ESP", State.ESP_Pallets and "ON" or "OFF", 2)
end)

KB.Register("VaultESP", KB.Keys.VaultESP, function()
    State.ESP_Vaults = not State.ESP_Vaults
    ESP.RefreshAll()
    Notify("Vault ESP", State.ESP_Vaults and "ON" or "OFF", 2)
end)

KB.Register("HookESP", KB.Keys.HookESP, function()
    State.ESP_Hooks = not State.ESP_Hooks
    ESP.RefreshAll()
    Notify("Hook ESP", State.ESP_Hooks and "ON" or "OFF", 2)
end)

KB.Register("NoFog", KB.Keys.NoFog, function()
    State.NoFog = not State.NoFog
    Vis.NoFog(State.NoFog)
    Notify("No Fog", State.NoFog and "ON" or "OFF", 2)
end)

KB.Register("NoShadows", KB.Keys.NoShadows, function()
    State.NoShadows = not State.NoShadows
    Vis.NoShadows(State.NoShadows)
    Notify("No Shadows", State.NoShadows and "ON" or "OFF", 2)
end)

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name                   = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle           = HUB.Name,
    LoadingSubtitle        = "by " .. HUB.Author,
    Theme                  = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",     name="Main",     icon="home"},
    {key="Survivor", name="Survivor", icon="shield"},
    {key="ESP",      name="ESP",      icon="eye"},
    {key="Movement", name="Movement", icon="footprints"},
    {key="Visuals",  name="Visuals",  icon="sun"},
    {key="Misc",     name="Misc",     icon="wrench"},
    {key="Keybinds", name="Keybinds", icon="keyboard"},
    {key="Settings", name="Settings", icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- ════════════════
-- MAIN TAB
-- ════════════════
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("Info")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Game: "..HUB.Game.." | Author: "..HUB.Author)
    T:CreateSection("Status")
    T:CreateLabel("Generators: "..(WS.Generators and #WS.Generators:GetChildren() or 0))
    T:CreateLabel("Pallets: "..#GetPallets().." | Vaults: "..#GetVaults())
    T:CreateLabel("Parry Remote: "..(R.Items.ParryDagger and "Found" or "Missing"))
    T:CreateLabel("Heal Remote:  "..(R.Items.Heal and "Found" or "Missing"))
    T:CreateLabel("Parry Remotes: "..#R.Parry.." | Heal Remotes: "..#R.Heal)
    T:CreateSection("Quick Keys Reference")
    T:CreateLabel("P = Auto Parry | H = Auto Heal | G = God Mode")
    T:CreateLabel("N = NoClip | J = Inf Jump | B = Speed Boost")
    T:CreateLabel("X = Invisible | F = Flee Killer | L = FullBright")
    T:CreateLabel("V = Freecam | R = Auto Gen | K = Auto Skillcheck")
    T:CreateLabel("Q = Force Parry | Y = Force Heal | M = Server Hop")
    T:CreateLabel("F1=KillerESP F2=SurvESP F3=GenESP F4=PalletESP")
    T:CreateLabel("F5=VaultESP F6=HookESP F7=NoFog F8=NoShadows")
    T:CreateLabel("End = Panic (Clear all ESP)")
    T:CreateSection("Debug")
    T:CreateButton({Name="Force Re-Detect Killer", Callback=function()
        Role.ResetKillerCache(); ESP.ClearAll(); ESP.RefreshAll()
        local k = Role.FindKiller()
        Notify("Killer", k and ("Found: "..k.Name) or "Not found", 3)
    end})
    T:CreateButton({Name="Print All Remotes to Output", Callback=function()
        if Remotes then
            Log("=== REMOTES ===")
            for _, v in ipairs(Remotes:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    Log(v:GetFullName())
                end
            end
        end
        Notify("Remotes","Check output console",3)
    end})
    T:CreateButton({Name="Refresh ESP Now", Callback=function()
        ESP.ClearAll(); Role.ResetKillerCache(); ESP.RefreshAll()
        Notify("ESP","Refreshed",3)
    end})
    T:CreateButton({Name="Force Test Parry", Callback=function()
        State.LastParryTime = 0
        DoParry("test")
        Notify("Parry","Test fired!",2)
    end})
end

-- ════════════════
-- SURVIVOR TAB
-- ════════════════
if Tabs.Survivor then
    local T = Tabs.Survivor

    T:CreateSection("Health Display")
    T:CreateToggle({Name="Show Own HP Bar [U]", CurrentValue=false, Flag="OwnHP",
        Callback=function(v) HP.SetVisible(v) end})

    T:CreateSection("Invisible [X]")
    T:CreateToggle({Name="Invisible", CurrentValue=false, Flag="Inv",
        Callback=function(v) State.Invisible=v; Surv.SetInvisible(v) end})

    T:CreateSection("Speed [B]")
    T:CreateToggle({Name="Speed Boost", CurrentValue=false, Flag="SB",
        Callback=function(v) State.SurvSpeedBoost=v; Surv.SetSpeedBoost(v) end})
    T:CreateSlider({Name="Speed Value", Range={16,60}, Increment=1, CurrentValue=24, Flag="SBVal",
        Callback=function(v)
            State.SurvSpeedValue = tonumber(v) or 24
            if State.SurvSpeedBoost then Surv.SetSpeedBoost(true) end
        end})

    T:CreateSection("Auto Parry [P] | Force: [Q]")
    T:CreateToggle({Name="Enable Auto Parry", CurrentValue=false, Flag="AP",
        Callback=function(v) State.AutoParry=v; Surv.SetAutoParry(v) end})
    T:CreateSlider({Name="Parry Trigger Range (studs)", Range={5,80}, Increment=1, CurrentValue=20, Flag="PR",
        Callback=function(v)
            State.ParryRange = tonumber(v) or 20
            if State.ShowParryRing then Surv.UpdateParryRing() end
        end})
    T:CreateSlider({Name="Parry Cooldown (x0.05s)", Range={1,20}, Increment=1, CurrentValue=5, Flag="PCD",
        Callback=function(v)
            State.ParryCooldown = (tonumber(v) or 5) * 0.05
        end})
    T:CreateSlider({Name="Key Fire Delay (x0.01s)", Range={1,20}, Increment=1, CurrentValue=8, Flag="PFR",
        Callback=function(v)
            State.ParryFireRate = (tonumber(v) or 8) * 0.01
        end})
    T:CreateDropdown({Name="Parry Mode",
        Options={"Remote+Key","Remote Only","Key Only"},
        CurrentOption={"Remote+Key"}, Flag="PM",
        Callback=function(v)
            State.ParryMode = (type(v)=="table" and v[1]) or v
            if State.AutoParry then Surv.SetAutoParry(true) end
        end})
    T:CreateToggle({Name="Instant Parry On Damage", CurrentValue=true, Flag="POH",
        Callback=function(v)
            State.ParryOnHit = v
            if State.AutoParry then Surv.SetAutoParry(true) end
        end})
    T:CreateToggle({Name="Parry Debug Log", CurrentValue=false, Flag="PDB",
        Callback=function(v) State.ParryDebug = v end})
    T:CreateToggle({Name="Show Range Ring", CurrentValue=false, Flag="PRing",
        Callback=function(v) State.ShowParryRing=v; Surv.UpdateParryRing() end})
    T:CreateDropdown({Name="Ring Color",
        Options={"Red","Blue","Green","Yellow","Purple","White"},
        CurrentOption={"Red"}, Flag="PRC",
        Callback=function(v)
            State.ParryRingColor = (type(v)=="table" and v[1]) or v
            if State.ShowParryRing then Surv.UpdateParryRing() end
        end})
    T:CreateButton({Name="Force Parry NOW", Callback=function()
        State.LastParryTime = 0; DoParry("manual_btn")
        Notify("Parry","Fired!",1)
    end})

    T:CreateSection("Auto Self Heal [H] | Force: [Y]")
    T:CreateToggle({Name="Enable Auto Heal", CurrentValue=false, Flag="AH",
        Callback=function(v) State.AutoHeal=v; Surv.SetAutoHeal(v) end})
    T:CreateSlider({Name="Heal Below HP %", Range={10,95}, Increment=5, CurrentValue=60, Flag="AHT",
        Callback=function(v) State.AutoHealThreshold = tonumber(v) or 60 end})
    T:CreateSlider({Name="Heal Delay (x0.5s)", Range={1,10}, Increment=1, CurrentValue=3, Flag="AHD",
        Callback=function(v) State.AutoHealDelay = (tonumber(v) or 3) * 0.5 end})
    T:CreateDropdown({Name="Heal Method",
        Options={"All","Remote","Attribute"},
        CurrentOption={"All"}, Flag="AHM",
        Callback=function(v) State.AutoHealMethod = (type(v)=="table" and v[1]) or v end})
    T:CreateButton({Name="Manual Heal Now", Callback=function()
        State.LastHealTime = 0; pcall(DoHeal)
        Notify("Heal","Manual triggered",2)
    end})

    T:CreateSection("Utility")
    T:CreateToggle({Name="No Fall Damage", CurrentValue=false, Flag="NF",
        Callback=function(v) State.NoFallDamage=v; Surv.SetNoFall(v) end})
    T:CreateToggle({Name="Flee Killer [F]", CurrentValue=false, Flag="FK",
        Callback=function(v) State.FleeKiller=v; Surv.SetFleeKiller(v) end})
    T:CreateSlider({Name="Flee Distance", Range={10,100}, Increment=5, CurrentValue=40, Flag="FD",
        Callback=function(v) State.FleeDistance = tonumber(v) or 40 end})
    T:CreateToggle({Name="God Mode [G]", CurrentValue=false, Flag="GM",
        Callback=function(v) State.GodMode=v; Surv.SetGodMode(v) end})

    T:CreateSection("Auto Generator Rush [R]")
    T:CreateDropdown({Name="Gen Mode", Options={"Instant","Legit"}, CurrentOption={"Instant"}, Flag="AGM",
        Callback=function(v) State.AutoGenMode = (type(v)=="table" and v[1]) or v end})
    T:CreateToggle({Name="Enable Auto Gen Rush", CurrentValue=false, Flag="AGR",
        Callback=function(v) State.AutoGenRush=v; Surv.SetAutoGenRush(v) end})

    T:CreateSection("Auto Skillcheck [K]")
    T:CreateToggle({Name="Disable Skillchecks", CurrentValue=false, Flag="ASC",
        Callback=function(v) State.AutoSkillcheck=v; Surv.SetAutoSkillcheck(v) end})

    T:CreateSection("Generator Info [O]")
    T:CreateToggle({Name="Show Progress Above Gens", CurrentValue=false, Flag="GP",
        Callback=function(v) State.ShowGenProgress=v; Surv.SetGenProgress(v) end})
end

-- ════════════════
-- ESP TAB
-- ════════════════
if Tabs.ESP then
    local T = Tabs.ESP
    T:CreateSection("Player ESP")
    T:CreateToggle({Name="Killer ESP [F1]", CurrentValue=false, Flag="E1",
        Callback=function(v)
            State.ESP_Killer = v; Role.ResetKillerCache()
            if not v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then ESP.Remove(p.Character) end
                end
            end
            ESP.RefreshAll()
        end})
    T:CreateToggle({Name="Survivor ESP [F2]", CurrentValue=false, Flag="E2",
        Callback=function(v)
            State.ESP_Survivors = v; Role.ResetKillerCache()
            if not v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then ESP.Remove(p.Character) end
                end
            end
            ESP.RefreshAll()
        end})
    T:CreateToggle({Name="Show HP on Players", CurrentValue=true, Flag="EHP",
        Callback=function(v) State.ESP_ShowHP = v end})

    T:CreateSection("Object ESP")
    T:CreateToggle({Name="Generator ESP [F3]", CurrentValue=false, Flag="E3",
        Callback=function(v)
            State.ESP_Generators = v
            if not v and WS.Generators then
                for _, g in ipairs(WS.Generators:GetChildren()) do ESP.Remove(g) end
            end
        end})
    T:CreateToggle({Name="Pallet ESP [F4]", CurrentValue=false, Flag="E4",
        Callback=function(v)
            State.ESP_Pallets = v
            if not v then for _, p in ipairs(GetPallets()) do ESP.Remove(p) end end
        end})
    T:CreateToggle({Name="Vault ESP [F5]", CurrentValue=false, Flag="E5",
        Callback=function(v)
            State.ESP_Vaults = v
            if not v then for _, w in ipairs(GetVaults()) do ESP.Remove(w) end end
        end})
    T:CreateToggle({Name="Hook ESP [F6]", CurrentValue=false, Flag="E5H",
        Callback=function(v)
            State.ESP_Hooks = v
            if not v then for _, h in ipairs(GetHooks()) do ESP.Remove(h) end end
        end})
    T:CreateToggle({Name="Item ESP", CurrentValue=false, Flag="E6",
        Callback=function(v) State.ESP_Items = v end})
    T:CreateToggle({Name="Weapon ESP", CurrentValue=false, Flag="E7",
        Callback=function(v)
            State.ESP_Weapons = v
            if not v and WS.Weapons then
                for _, w in ipairs(WS.Weapons:GetChildren()) do ESP.Remove(w) end
            end
        end})
    T:CreateToggle({Name="Clone ESP", CurrentValue=false, Flag="E8",
        Callback=function(v)
            State.ESP_Clones = v
            if not v and WS.Clones then
                for _, c in ipairs(WS.Clones:GetChildren()) do ESP.Remove(c) end
            end
        end})

    T:CreateSection("Display Options")
    T:CreateToggle({Name="Show Names", CurrentValue=true, Flag="E9",
        Callback=function(v) State.ESP_ShowName = v end})
    T:CreateToggle({Name="Show Distance", CurrentValue=true, Flag="E10",
        Callback=function(v) State.ESP_ShowDistance = v end})
    T:CreateSlider({Name="Max Distance (studs)", Range={50,2000}, Increment=50, CurrentValue=500, Flag="E11",
        Callback=function(v) State.ESP_MaxDistance = tonumber(v) or 500 end})

    T:CreateSection("Actions")
    T:CreateButton({Name="Refresh All ESP", Callback=function()
        ESP.ClearAll(); Role.ResetKillerCache(); ESP.RefreshAll()
        Notify("ESP","Refreshed",3)
    end})
    T:CreateButton({Name="Clear All ESP [End]", Callback=function()
        ESP.ClearAll(); Notify("ESP","Cleared",3)
    end})
end

-- ════════════════
-- MOVEMENT TAB
-- ════════════════
if Tabs.Movement then
    local T = Tabs.Movement
    T:CreateSection("Speed & Jump")
    T:CreateSlider({Name="Walk Speed", Range={16,200}, Increment=1, CurrentValue=16, Flag="M1",
        Callback=function(v)
            State.WalkSpeed = tonumber(v) or 16
            if not State.SurvSpeedBoost then Move.Speed() end
        end})
    T:CreateSlider({Name="Jump Power", Range={50,300}, Increment=5, CurrentValue=50, Flag="M2",
        Callback=function(v) State.JumpPower = tonumber(v) or 50; Move.Jump() end})

    T:CreateSection("Advanced")
    T:CreateToggle({Name="NoClip [N]", CurrentValue=false, Flag="M3",
        Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end})
    T:CreateToggle({Name="Infinite Jump [J]", CurrentValue=false, Flag="M4",
        Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end})

    T:CreateSection("Teleport")
    T:CreateButton({Name="TP Nearest Generator", Callback=Move.NearestGen})
    T:CreateButton({Name="TP Nearest Exit",       Callback=Move.NearestExit})
    T:CreateInput({Name="Player Name", PlaceholderText="Name...",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) tpTarget = tostring(v or "") end})
    T:CreateButton({Name="TP to Player", Callback=Move.ToPlayer})
end

-- ════════════════
-- VISUALS TAB
-- ════════════════
if Tabs.Visuals then
    local T = Tabs.Visuals
    T:CreateSection("Lighting")
    T:CreateToggle({Name="FullBright [L]", CurrentValue=false, Flag="V1",
        Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    T:CreateToggle({Name="No Fog [F7]", CurrentValue=false, Flag="V2",
        Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    T:CreateToggle({Name="No Shadows [F8]", CurrentValue=false, Flag="V3",
        Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end})
    T:CreateToggle({Name="Clear Weather", CurrentValue=false, Flag="V4",
        Callback=function(v) State.ClearWeather=v; Vis.ClearWx(v) end})
    T:CreateSlider({Name="Time of Day", Range={0,24}, Increment=1, CurrentValue=14, Flag="V5",
        Callback=function(v) State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime) end})

    T:CreateSection("Camera")
    T:CreateSlider({Name="FOV", Range={30,120}, Increment=5, CurrentValue=70, Flag="V6",
        Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end})
    T:CreateToggle({Name="Freecam [V]", CurrentValue=false, Flag="V7",
        Callback=function(v) State.Freecam=v; Vis.Freecam(v) end})

    T:CreateSection("Post FX")
    T:CreateToggle({Name="Remove Blur/Bloom", CurrentValue=false, Flag="V8",
        Callback=function(v) State.RemoveBlur=v; Vis.PostFX(v) end})
    T:CreateToggle({Name="Remove Color Correction", CurrentValue=false, Flag="V9",
        Callback=function(v) State.RemoveCC=v; Vis.ColorCorr(v) end})
    T:CreateToggle({Name="No Particles", CurrentValue=false, Flag="V10",
        Callback=function(v) State.NoParticles=v; Vis.Particles(v) end})

    T:CreateSection("Performance")
    T:CreateToggle({Name="Low Graphics", CurrentValue=false, Flag="V11",
        Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end})
end

-- ════════════════
-- MISC TAB
-- ════════════════
if Tabs.Misc then
    local T = Tabs.Misc
    T:CreateSection("Audio")
    T:CreateToggle({Name="Mute All Sounds", CurrentValue=false, Flag="X1",
        Callback=function(v) State.NoSound=v; Vis.MuteAll(v) end})
    T:CreateToggle({Name="Mute BG Music", CurrentValue=false, Flag="X2",
        Callback=function(v) State.MuteBGMusic=v; Vis.MuteBG(v) end})

    T:CreateSection("Character")
    T:CreateToggle({Name="Hide Own Name", CurrentValue=false, Flag="X3",
        Callback=function(v) State.HideName=v; Vis.HideName(v) end})

    T:CreateSection("Server [M]")
    T:CreateButton({Name="Server Hop", Callback=Vis.ServerHop})
    T:CreateButton({Name="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end})
    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","Job ID",3) end
    end})

    T:CreateSection("Utility")
    T:CreateToggle({Name="Auto Rejoin on Kick", CurrentValue=false, Flag="X4",
        Callback=function(v) State.AutoRejoin=v end})
end

-- ════════════════
-- KEYBINDS TAB
-- ════════════════
if Tabs.Keybinds then
    local T = Tabs.Keybinds

    T:CreateSection("Combat")
    T:CreateKeybind({Name="Auto Parry Toggle", CurrentKeybind="P",
        HoldToInteract=false, Flag="KB_AutoParry",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("AutoParry", key) end
        end})
    T:CreateKeybind({Name="Force Parry (Manual)", CurrentKeybind="Q",
        HoldToInteract=false, Flag="KB_ForceParry",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("ForceParry", key) end
        end})
    T:CreateKeybind({Name="Auto Heal Toggle", CurrentKeybind="H",
        HoldToInteract=false, Flag="KB_AutoHeal",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("AutoHeal", key) end
        end})
    T:CreateKeybind({Name="Force Heal (Manual)", CurrentKeybind="Y",
        HoldToInteract=false, Flag="KB_ForceHeal",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("ForceHeal", key) end
        end})
    T:CreateKeybind({Name="God Mode Toggle", CurrentKeybind="G",
        HoldToInteract=false, Flag="KB_GodMode",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("GodMode", key) end
        end})
    T:CreateKeybind({Name="Flee Killer Toggle", CurrentKeybind="F",
        HoldToInteract=false, Flag="KB_Flee",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("FleeKiller", key) end
        end})

    T:CreateSection("Character")
    T:CreateKeybind({Name="Invisible Toggle", CurrentKeybind="X",
        HoldToInteract=false, Flag="KB_Invisible",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("Invisible", key) end
        end})
    T:CreateKeybind({Name="Speed Boost Toggle", CurrentKeybind="B",
        HoldToInteract=false, Flag="KB_SpeedBoost",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("SpeedBoost", key) end
        end})

    T:CreateSection("Movement")
    T:CreateKeybind({Name="NoClip Toggle", CurrentKeybind="N",
        HoldToInteract=false, Flag="KB_NoClip",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("NoClip", key) end
        end})
    T:CreateKeybind({Name="Infinite Jump Toggle", CurrentKeybind="J",
        HoldToInteract=false, Flag="KB_InfJump",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("InfJump", key) end
        end})

    T:CreateSection("Generators")
    T:CreateKeybind({Name="Auto Gen Rush Toggle", CurrentKeybind="R",
        HoldToInteract=false, Flag="KB_GenRush",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("AutoGenRush", key) end
        end})
    T:CreateKeybind({Name="Auto Skillcheck Toggle", CurrentKeybind="K",
        HoldToInteract=false, Flag="KB_Skillcheck",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("AutoSkillcheck", key) end
        end})
    T:CreateKeybind({Name="Gen Progress Toggle", CurrentKeybind="O",
        HoldToInteract=false, Flag="KB_GenProgress",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("GenProgress", key) end
        end})

    T:CreateSection("Visuals")
    T:CreateKeybind({Name="FullBright Toggle", CurrentKeybind="L",
        HoldToInteract=false, Flag="KB_FullBright",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("FullBright", key) end
        end})
    T:CreateKeybind({Name="Freecam Toggle", CurrentKeybind="V",
        HoldToInteract=false, Flag="KB_Freecam",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("Freecam", key) end
        end})
    T:CreateKeybind({Name="HP Bar Toggle", CurrentKeybind="U",
        HoldToInteract=false, Flag="KB_OwnHP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("OwnHP", key) end
        end})
    T:CreateKeybind({Name="No Fog Toggle", CurrentKeybind="F7",
        HoldToInteract=false, Flag="KB_NoFog",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("NoFog", key) end
        end})
    T:CreateKeybind({Name="No Shadows Toggle", CurrentKeybind="F8",
        HoldToInteract=false, Flag="KB_NoShadows",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("NoShadows", key) end
        end})

    T:CreateSection("ESP")
    T:CreateKeybind({Name="Killer ESP Toggle", CurrentKeybind="F1",
        HoldToInteract=false, Flag="KB_KillerESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("KillerESP", key) end
        end})
    T:CreateKeybind({Name="Survivor ESP Toggle", CurrentKeybind="F2",
        HoldToInteract=false, Flag="KB_SurvESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("SurvivorESP", key) end
        end})
    T:CreateKeybind({Name="Generator ESP Toggle", CurrentKeybind="F3",
        HoldToInteract=false, Flag="KB_GenESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("GeneratorESP", key) end
        end})
    T:CreateKeybind({Name="Pallet ESP Toggle", CurrentKeybind="F4",
        HoldToInteract=false, Flag="KB_PalletESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("PalletESP", key) end
        end})
    T:CreateKeybind({Name="Vault ESP Toggle", CurrentKeybind="F5",
        HoldToInteract=false, Flag="KB_VaultESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("VaultESP", key) end
        end})
    T:CreateKeybind({Name="Hook ESP Toggle", CurrentKeybind="F6",
        HoldToInteract=false, Flag="KB_HookESP",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("HookESP", key) end
        end})

    T:CreateSection("Misc")
    T:CreateKeybind({Name="Server Hop", CurrentKeybind="M",
        HoldToInteract=false, Flag="KB_ServerHop",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("ServerHop", key) end
        end})
    T:CreateKeybind({Name="Panic Clear ESP", CurrentKeybind="End",
        HoldToInteract=false, Flag="KB_Panic",
        Callback=function(k)
            local ok, key = pcall(function() return Enum.KeyCode[k] end)
            if ok and key then KB.SetKey("PanicClearESP", key) end
        end})
end

-- ════════════════
-- SETTINGS TAB
-- ════════════════
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("Anti-AFK")
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="S1",
        Callback=function(v) State.AntiAFK=v end})
    T:CreateSection("Credits")
    T:CreateLabel(HUB.Name.." v"..HUB.Version.." by "..HUB.Author)
    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Hub", Callback=function()
        for _, key in ipairs({
            "NoClipConn","InfJumpConn","FreecamConn","NoFallConn","GodModeConn",
            "FleeConn","AutoParryConn","AutoParryHitConn","AutoHealConn",
            "SkillcheckGUIConn","InvisibleConn","ParryKillerWatchConn",
        }) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.AutoGenRush=false; State.ShowGenProgress=false
        State.ShowOwnHP=false; State.AutoHeal=false; State.AutoParry=false
        Surv.SetGenProgress(false); Surv.SetInvisible(false)
        Surv.SetAutoSkillcheck(false); Surv.SetAutoHeal(false)
        Surv.SetAutoParry(false)
        if State.ParryRing then pcall(function() State.ParryRing:Destroy() end) end
        if State.HPGui     then pcall(function() State.HPGui:Destroy() end)    end
        if ESPRenderConn   then ESPRenderConn:Disconnect() end
        if ESPGui          then pcall(function() ESPGui:Destroy() end) end
        CM:Cleanup(); Vis.RestoreLight()
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        _G[INSTANCE_KEY] = nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- ═══════════════════════════════════════════
-- CHARACTER RESPAWN — re-hook everything
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.CharacterAdded, function()
    State.SavedTransparencies = {}
    task.wait(1.5)
    Role.ResetKillerCache()
    pcall(Move.Speed); pcall(Move.Jump)
    if State.NoClip         then pcall(Move.SetNoClip,  true) end
    if State.InfJump        then pcall(Move.SetInfJump, true) end
    if State.FullBright     then pcall(Vis.FullBright,  true) end
    if State.NoFog          then pcall(Vis.NoFog,       true) end
    if State.HideName       then pcall(Vis.HideName,    true) end
    if State.FOV ~= 70      then pcall(Vis.SetFOV,  State.FOV) end
    if State.Invisible      then pcall(Surv.SetInvisible,   true) end
    if State.SurvSpeedBoost then pcall(Surv.SetSpeedBoost,  true) end
    if State.NoFallDamage   then pcall(Surv.SetNoFall,      true) end
    if State.GodMode        then pcall(Surv.SetGodMode,     true) end
    if State.FleeKiller     then pcall(Surv.SetFleeKiller,  true) end
    if State.AutoParry      then pcall(Surv.SetAutoParry,   true) end
    if State.AutoHeal       then pcall(Surv.SetAutoHeal,    true) end
    if State.AutoSkillcheck then pcall(Surv.SetAutoSkillcheck, true) end
    if State.ShowOwnHP      then pcall(HP.Create) end
    task.wait(0.5)
    ESP.RefreshAll()
end, "CharAdded")

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
end, "Teleport")

-- ═══════════════════════════════════════════
-- GLOBAL INSTANCE
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version   = HUB.Version,
    timestamp = os.time(),
    destroy   = function()
        for _, key in ipairs({
            "NoClipConn","InfJumpConn","FreecamConn","NoFallConn","GodModeConn",
            "FleeConn","AutoParryConn","AutoParryHitConn","AutoHealConn",
            "SkillcheckGUIConn","InvisibleConn","ParryKillerWatchConn",
        }) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.AutoGenRush=false; State.ShowGenProgress=false
        State.ShowOwnHP=false; State.AutoHeal=false; State.AutoParry=false
        Surv.SetGenProgress(false); Surv.SetInvisible(false)
        Surv.SetAutoSkillcheck(false); Surv.SetAutoHeal(false)
        Surv.SetAutoParry(false)
        if State.ParryRing then pcall(function() State.ParryRing:Destroy() end) end
        if State.HPGui     then pcall(function() State.HPGui:Destroy() end)    end
        if ESPRenderConn   then ESPRenderConn:Disconnect() end
        if ESPGui          then pcall(function() ESPGui:Destroy() end) end
        CM:Cleanup(); Vis.RestoreLight()
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." ready! | "..#R.Parry.." parry remotes found", 5)
Log("Ready — v0.5.7 fully loaded")
