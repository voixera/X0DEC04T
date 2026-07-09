--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.0.6 - Violence District
-- UI: Rayfield (universal executor compatibility)
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

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- DUPLICATE GUARD
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local INSTANCE_KEY = "__X0DEC04T_v006_INSTANCE"
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

Log("Script starting...")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOAD RAYFIELD
-- Rayfield works on all major executors including Xeno, Delta,
-- Solara, Wave, Codex, Synapse X, KRNL.
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
        Log("Rayfield loaded from: " .. url)
        break
    else
        Err("Failed: " .. url, tostring(result))
    end
end

if not Rayfield then
    Err("FATAL: Rayfield failed to load from all mirrors")
    return
end

Log("UI library ready")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HUB CONFIG
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.6",
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
-- KILLER LIST
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local KillerFolder  = ReplicatedStorage:FindFirstChild("Killers")
local KNOWN_KILLERS = {}
if KillerFolder then
    for _, child in ipairs(KillerFolder:GetChildren()) do
        local n = child.Name
        if n ~= "!General" and n ~= "Perks" then
            KNOWN_KILLERS[n:lower()] = true
        end
    end
end
Log("Killers loaded: " .. (function()
    local c = 0; for _ in pairs(KNOWN_KILLERS) do c = c + 1 end; return c
end)())

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local R = {
    Generator   = {},
    Healing     = {},
    Chase       = {},
    Attacks     = {},
    KillerPerks = {},
    Game        = {},
    Carry       = {},
}

if Remotes then
    local function F(parent, name)
        return parent and parent:FindFirstChild(name) or nil
    end
    local gen = F(Remotes, "Generator")
    R.Generator.SkillCheck     = F(gen, "SkillCheckEvent")
    R.Generator.SkillCheckFail = F(gen, "SkillCheckFailEvent")
    R.Generator.GenDone        = F(gen, "GenDone")
    R.Generator.AllGenDone     = F(gen, "allgendone")
    local heal = F(Remotes, "Healing")
    R.Healing.SkillCheck = F(heal, "SkillCheckEvent")
    local ch = F(Remotes, "Chase")
    R.Chase.Music = F(ch, "ChaseMusicEvent")
    local atk = F(Remotes, "Attacks")
    R.Attacks.Lunge = F(atk, "Lunge")
    local kp = F(Remotes, "KillerPerks")
    R.KillerPerks.KingScourge = F(kp, "kingscourge")
    local gm = F(Remotes, "Game")
    R.Game.Start       = F(gm, "Start")
    R.Game.RoundEnd    = F(gm, "RoundEnd")
    R.Game.KillerMorph = F(gm, "KillerMorph")
    R.Game.OneLeft     = F(gm, "Oneleft")
    R.Game.Death       = F(gm, "death")
    local cr = F(Remotes, "Carry")
    R.Carry.HookEvent = F(cr, "HookEvent")
    Log("Remotes resolved")
else
    Err("Remotes folder not found")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WORKSPACE REFS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local WS = {
    Map       = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones    = Workspace:FindFirstChild("Clones"),
    FakeChars = Workspace:FindFirstChild("FakeCharacters"),
    Weapons   = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then WS.Generators = WS.Map:FindFirstChild("Generators") end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {
    ChaseAlert       = true,
    AttackAlert      = true,
    SkillCheckNotify = true,
    HealSkillNotify  = true,
    GenDoneNotify    = true,
    AllGensNotify    = true,
    OneLeftNotify    = true,
    HookNotify       = true,
    DeathNotify      = true,
    ESP_Generators   = false,
    ESP_Killer       = false,
    ESP_Survivors    = false,
    ESP_Items        = false,
    ESP_Weapons      = false,
    ESP_Clones       = false,
    ESP_MaxDistance  = 500,
    ESP_ShowDistance = true,
    ESP_ShowName     = true,
    Color_Killer     = Color3.fromRGB(255,  40,  40),
    Color_Survivor   = Color3.fromRGB( 60, 220, 255),
    Color_Generator  = Color3.fromRGB(255, 200,  60),
    Color_Item       = Color3.fromRGB(120, 255, 120),
    Color_Weapon     = Color3.fromRGB(255, 120, 220),
    Color_Clone      = Color3.fromRGB(180, 180, 180),
    WalkSpeed        = 16,
    JumpPower        = 50,
    NoClip           = false,
    InfJump          = false,
    FullBright       = false,
    NoFog            = false,
    NoShadows        = false,
    ClearWeather     = false,
    LowGraphics      = false,
    FOV              = 70,
    ClockTime        = 14,
    RemoveBlur       = false,
    RemoveCC         = false,
    Freecam          = false,
    HideName         = false,
    NoSound          = false,
    MuteBGMusic      = false,
    NoParticles      = false,
    AutoRejoin       = false,
    AntiAFK          = true,
    IsKiller         = false,
    MatchActive      = false,
    ESPCache         = {},
    LightBackup      = {},
    MutedSounds      = {},
    NoClipConn       = nil,
    InfJumpConn      = nil,
    FreecamConn      = nil,
    AwarenessReady   = false,
}

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
-- ROLE
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
        if n:find(k, 1, true) then return k:gsub("^%l", string.upper) end
    end
    return "Killer"
end

function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones    and char:IsDescendantOf(WS.Clones)    then return true end
    return false
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP
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

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function MakeBB(hrp, label, color, showName, showDist, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Adornee        = hrp
    bb.Size           = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset    = Vector3.new(0, 3.5, 0)
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

    local bb, nl, dl = MakeBB(
        hrp, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance
    )
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

    local bb, nl, dl = MakeBB(
        part, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance
    )
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
        elseif not State.ESP_Generators then ESP.Clear(g) end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.AddObj(w, "⚔ " .. w.Name, State.Color_Weapon)
        elseif not State.ESP_Weapons then ESP.Clear(w) end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones and not State.ESPCache[c] then
            ESP.AddObj(c, "👥 Clone", State.Color_Clone)
        elseif not State.ESP_Clones then ESP.Clear(c) end
    end
end

function ESP.ScanItems()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and (o:GetAttribute("Item") or o:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[o] then
                ESP.AddObj(o, "🎒 " .. o.Name, State.Color_Item)
            elseif not State.ESP_Items then ESP.Clear(o) end
        end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers()
    ESP.ScanGens()
    ESP.ScanWeapons()
    ESP.ScanClones()
    ESP.ScanItems()
end

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
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end

function Move.SetNoClip(e)
    if State.NoClipConn then
        pcall(function() State.NoClipConn:Disconnect() end)
        State.NoClipConn = nil
    end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer.Character; if not ch then return end
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
    if not WS.Generators then Notify("TP","No generators folder.",3); return end
    local hrp = Move.GetHRP(); if not hrp then return end
    local best, bd = nil, math.huge
    for _, g in ipairs(WS.Generators:GetChildren()) do
        local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then
            local d = (p.Position - hrp.Position).Magnitude
            if d < bd then bd=d; best=p end
        end
    end
    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0,4,0)
        Notify("TP","Teleported to generator (" .. math.floor(bd) .. "m)",3)
    end
end

function Move.ToPlayer()
    if tpTarget == "" then Notify("TP","Enter a name first.",3); return end
    local t = Players:FindFirstChild(tpTarget)
    if not t or not t.Character then Notify("TP","Not found: "..tpTarget,3); return end
    local hrp  = Move.GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Notify("TP","Teleported to "..tpTarget,3)
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
    for k,v in pairs(State.LightBackup) do
        pcall(function() Lighting[k]=v end)
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
    else Vis.RestoreLight() end
end

function Vis.NoFog(e)
    Vis.BackupLight()
    if e then
        Lighting.FogEnd=999999; Lighting.FogStart=999999
        for _,a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else
        Lighting.FogEnd   = State.LightBackup.FogEnd   or 100000
        Lighting.FogStart = State.LightBackup.FogStart or 0
    end
end

function Vis.NoShadows(e)
    Vis.BackupLight(); Lighting.GlobalShadows = not e
end

function Vis.ClearWx(e)
    if e then
        for _,o in ipairs(Lighting:GetDescendants()) do
            if o:IsA("Atmosphere") then o.Density=0; o.Haze=0 end
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

function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end

function Vis.PostFX(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not rm
        end
    end
end

function Vis.ColorCorr(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then v.Enabled = not rm end
    end
end

function Vis.Particles(rm)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire")
        or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = not rm
        end
    end
end

function Vis.HideName(e)
    local ch = LocalPlayer.Character; if not ch then return end
    local head = ch:FindFirstChild("Head"); if not head then return end
    for _,g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end

function Vis.MuteAll(e)
    if e then
        for _,s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and not table.find(State.MutedSounds, s) then
                table.insert(State.MutedSounds, {s=s, v=s.Volume})
                s.Volume = 0
            end
        end
    else
        for _,entry in ipairs(State.MutedSounds) do
            if entry.s and entry.s.Parent then entry.s.Volume = entry.v end
        end
        State.MutedSounds = {}
    end
end

function Vis.MuteBG(e)
    local bg = Workspace:FindFirstChild("BackgroundSounds"); if not bg then return end
    for _,s in ipairs(bg:GetDescendants()) do
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
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)
            then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            then mv=mv-Vector3.new(0,1,0) end
            pos = pos + mv*2
            Camera.CFrame = CFrame.new(pos, pos+look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

function Vis.ServerHop()
    local ok,e = pcall(function()
        local TS  = game:GetService("TeleportService")
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"..tostring(game.PlaceId)
            .."/servers/Public?sortOrder=Asc&limit=100"
        )
        local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if dok and data and data.data then
            for _,s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
        Notify("Server Hop","No server found.",4)
    end)
    if not ok then Notify("Server Hop","Error: "..tostring(e),4) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AWARENESS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SetupAwareness()
    if State.AwarenessReady then return end
    State.AwarenessReady = true

    local function Conn(sig, cb, label)
        if sig then CM:Add(sig, cb, label) end
    end

    Conn(R.Generator.SkillCheck and R.Generator.SkillCheck.OnClientEvent,
        function() if State.SkillCheckNotify then Notify("Skill Check!","Hit the mark!",2) end end,
        "GenSkillCheck")
    Conn(R.Generator.SkillCheckFail and R.Generator.SkillCheckFail.OnClientEvent,
        function() if State.SkillCheckNotify then Notify("Skill Check FAIL","Progress lost!",3) end end,
        "GenSkillFail")
    Conn(R.Healing.SkillCheck and R.Healing.SkillCheck.OnClientEvent,
        function() if State.HealSkillNotify then Notify("Heal Check!","",2) end end,
        "HealSC")
    Conn(R.Generator.GenDone and R.Generator.GenDone.OnClientEvent,
        function() if State.GenDoneNotify then Notify("Generator Done!","",3) end end,
        "GenDone")
    Conn(R.Generator.AllGenDone and R.Generator.AllGenDone.OnClientEvent,
        function() if State.AllGensNotify then Notify("All Generators Done!","Find the exit!",6) end end,
        "AllGens")
    Conn(R.Chase.Music and R.Chase.Music.OnClientEvent,
        function() if State.ChaseAlert then Notify("⚠ CHASE!","Killer nearby!",3) end end,
        "Chase")
    Conn(R.Attacks.Lunge and R.Attacks.Lunge.OnClientEvent,
        function() if State.AttackAlert then Notify("⚠ LUNGE!","",2) end end,
        "Lunge")

    if R.KillerPerks.KingScourge then
        local s = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if s then
            Conn(s.OnClientEvent,
                function() if State.AttackAlert then Notify("⚠ SCOURGE!","",2) end end,
                "Scourge")
        end
    end

    Conn(R.Game.KillerMorph and R.Game.KillerMorph.OnClientEvent,
        function() State.IsKiller=true; Notify("Role","You are the KILLER",5) end,
        "KillerMorph")
    Conn(R.Game.Start and R.Game.Start.OnClientEvent,
        function() State.MatchActive=true; State.IsKiller=false; Notify("Match Started","Good luck!",3) end,
        "GameStart")
    Conn(R.Game.RoundEnd and R.Game.RoundEnd.OnClientEvent,
        function() State.MatchActive=false; ESP.ClearAll() end,
        "RoundEnd")
    Conn(R.Game.OneLeft and R.Game.OneLeft.OnClientEvent,
        function() if State.OneLeftNotify then Notify("Last Survivor!","",5) end end,
        "OneLeft")
    Conn(R.Game.Death and R.Game.Death.OnClientEvent,
        function() if State.DeathNotify then Notify("You Died","",3) end end,
        "Death")
    Conn(R.Carry.HookEvent and R.Carry.HookEvent.OnClientEvent,
        function() if State.HookNotify then Notify("Hooked!","",3) end end,
        "Hook")
    Conn(LocalPlayer.Idled,
        function()
            if State.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end
        end, "AntiAFK")

    Log("Awareness ready")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BUILD UI - SYNCHRONOUS, NO YIELDS INSIDE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Log("Creating window...")

local Window = Rayfield:CreateWindow({
    Name             = HUB.Name .. "  v" .. HUB.Version,
    LoadingTitle     = HUB.Name,
    LoadingSubtitle  = "by " .. HUB.Author,
    Theme            = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

assert(Window, "Window creation failed - Rayfield returned nil")
Log("Window created")

-- ── TABS ─────────────────────────────────────────────────────
Log("Creating tabs...")

local Tabs = {}
local TAB_DEFS = {
    { key="Main",      name="Main",      icon="home"          },
    { key="Awareness", name="Awareness", icon="bell"          },
    { key="ESP",       name="ESP",       icon="eye"           },
    { key="Movement",  name="Movement",  icon="footprints"    },
    { key="Visuals",   name="Visuals",   icon="sun"           },
    { key="Misc",      name="Misc",      icon="wrench"        },
    { key="Settings",  name="Settings",  icon="settings"      },
}

for _, def in ipairs(TAB_DEFS) do
    local ok, tab = pcall(function()
        return Window:CreateTab(def.name, def.icon)
    end)
    if ok and tab then
        Tabs[def.key] = tab
        Log("Tab created: " .. def.name)
    else
        Err("Tab failed: " .. def.name, tostring(tab))
    end
end

assert(next(Tabs), "No tabs were created - aborting")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RAYFIELD ELEMENT HELPERS
-- Rayfield API:
--   tab:CreateSection(name)
--   tab:CreateToggle({Name,CurrentValue,Flag,Callback})
--   tab:CreateButton({Name,Callback})
--   tab:CreateSlider({Name,Range,Increment,CurrentValue,Flag,Callback})
--   tab:CreateInput({Name,PlaceholderText,RemoveTextAfterFocusLost,Callback})
--   tab:CreateLabel(text)
--   tab:CreateDropdown({Name,Options,CurrentOption,Flag,Callback})
--   tab:CreateKeybind({Name,CurrentKeybind,HoldToInteract,Flag,Callback})
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function Sec(tab, name)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateSection(name) end)
    if not ok then Err("Section:"..name, err) end
    Log("Section created: " .. name)
end

local function Tog(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateToggle(cfg) end)
    if not ok then Err("Toggle:"..tostring(label), err) end
end

local function Btn(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateButton(cfg) end)
    if not ok then Err("Button:"..tostring(label), err) end
end

local function Sld(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateSlider(cfg) end)
    if not ok then Err("Slider:"..tostring(label), err) end
end

local function Inp(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateInput(cfg) end)
    if not ok then Err("Input:"..tostring(label), err) end
end

local function Lbl(tab, text)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateLabel(text) end)
    if not ok then Err("Label:"..tostring(text), err) end
end

local function Drp(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateDropdown(cfg) end)
    if not ok then Err("Dropdown:"..tostring(label), err) end
end

local function Kbnd(tab, cfg, label)
    if not tab then return end
    local ok, err = pcall(function() tab:CreateKeybind(cfg) end)
    if not ok then Err("Keybind:"..tostring(label), err) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- POPULATE TABS - fully synchronous, zero yields
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ── MAIN ─────────────────────────────────────────────────────
if Tabs.Main then
    local T = Tabs.Main

    Sec(T, "Information")

    Lbl(T, "X0DEC04T Hub v" .. HUB.Version .. " — " .. HUB.Game)
    Lbl(T, "Author: " .. HUB.Author)

    local killerList = {}
    for k in pairs(KNOWN_KILLERS) do
        killerList[#killerList+1] = k:gsub("^%l", string.upper)
    end
    Lbl(T, "Killers: " .. (#killerList > 0 and table.concat(killerList, ", ") or "None"))

    Sec(T, "Keybinds")
    Lbl(T, "RightShift → Toggle UI")
    Lbl(T, "End → Panic / Clear all ESP")
end

-- ── AWARENESS ────────────────────────────────────────────────
if Tabs.Awareness then
    local T = Tabs.Awareness

    Sec(T, "Killer Alerts")
    Tog(T,{
        Name="Chase Music Alert", CurrentValue=true, Flag="ChaseAlert",
        Callback=function(v) State.ChaseAlert=v end
    },"ChaseAlert")
    Tog(T,{
        Name="Attack Alert", CurrentValue=true, Flag="AttackAlert",
        Callback=function(v) State.AttackAlert=v end
    },"AttackAlert")

    Sec(T, "Skill Check Alerts")
    Tog(T,{
        Name="Generator Skill Check", CurrentValue=true, Flag="GenSC",
        Callback=function(v) State.SkillCheckNotify=v end
    },"GenSC")
    Tog(T,{
        Name="Heal Skill Check", CurrentValue=true, Flag="HealSC",
        Callback=function(v) State.HealSkillNotify=v end
    },"HealSC")

    Sec(T, "Objective Alerts")
    Tog(T,{Name="Generator Done",   CurrentValue=true, Flag="GenDone",  Callback=function(v) State.GenDoneNotify=v  end},"GenDone")
    Tog(T,{Name="All Gens Done",    CurrentValue=true, Flag="AllGens",  Callback=function(v) State.AllGensNotify=v  end},"AllGens")
    Tog(T,{Name="Hook Notify",      CurrentValue=true, Flag="HookN",    Callback=function(v) State.HookNotify=v     end},"HookN")
    Tog(T,{Name="Death Notify",     CurrentValue=true, Flag="DeathN",   Callback=function(v) State.DeathNotify=v    end},"DeathN")
    Tog(T,{Name="Last Survivor",    CurrentValue=true, Flag="LastN",    Callback=function(v) State.OneLeftNotify=v  end},"LastN")
end

-- ── ESP ──────────────────────────────────────────────────────
if Tabs.ESP then
    local T = Tabs.ESP

    Sec(T, "Player ESP")
    Tog(T,{
        Name="Killer ESP", CurrentValue=false, Flag="KillerESP",
        Callback=function(v)
            State.ESP_Killer=v
            if not v then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p.Character and Role.IsKiller(p.Character) then
                        ESP.Clear(p.Character)
                    end
                end
            end
        end
    },"KillerESP")
    Tog(T,{
        Name="Survivor ESP", CurrentValue=false, Flag="SurvivorESP",
        Callback=function(v)
            State.ESP_Survivors=v
            if not v then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p.Character and not Role.IsKiller(p.Character) then
                        ESP.Clear(p.Character)
                    end
                end
            end
        end
    },"SurvivorESP")

    Sec(T, "Object ESP")
    Tog(T,{
        Name="Generator ESP", CurrentValue=false, Flag="GenESP",
        Callback=function(v)
            State.ESP_Generators=v
            if not v and WS.Generators then
                for _,g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end
            end
        end
    },"GenESP")
    Tog(T,{Name="Item ESP",   CurrentValue=false, Flag="ItemESP",   Callback=function(v) State.ESP_Items=v   end},"ItemESP")
    Tog(T,{
        Name="Weapon ESP", CurrentValue=false, Flag="WeaponESP",
        Callback=function(v)
            State.ESP_Weapons=v
            if not v and WS.Weapons then
                for _,w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end
            end
        end
    },"WeaponESP")
    Tog(T,{
        Name="Clone ESP", CurrentValue=false, Flag="CloneESP",
        Callback=function(v)
            State.ESP_Clones=v
            if not v and WS.Clones then
                for _,c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end
            end
        end
    },"CloneESP")

    Sec(T, "Display")
    Tog(T,{
        Name="Show Names", CurrentValue=true, Flag="ESPNames",
        Callback=function(v)
            State.ESP_ShowName=v
            for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end
        end
    },"ESPNames")
    Tog(T,{
        Name="Show Distance", CurrentValue=true, Flag="ESPDist",
        Callback=function(v)
            State.ESP_ShowDistance=v
            for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end
        end
    },"ESPDist")
    Sld(T,{
        Name="Max Distance", Range={50,2000}, Increment=50,
        CurrentValue=500, Flag="ESPMaxDist",
        Callback=function(v)
            State.ESP_MaxDistance=tonumber(v) or 500
            for _,c in pairs(State.ESPCache) do
                if c.bb then c.bb.MaxDistance=State.ESP_MaxDistance end
            end
        end
    },"ESPMaxDist")

    Sec(T, "Actions")
    Btn(T,{
        Name="Refresh ESP",
        Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end
    },"RefreshESP")
    Btn(T,{
        Name="Clear All ESP",
        Callback=function() ESP.ClearAll(); Notify("ESP","Cleared",2) end
    },"ClearESP")
end

-- ── MOVEMENT ─────────────────────────────────────────────────
if Tabs.Movement then
    local T = Tabs.Movement

    Sec(T, "Speed")
    Sld(T,{
        Name="Walk Speed", Range={16,200}, Increment=1,
        CurrentValue=16, Flag="WalkSpeed",
        Callback=function(v) State.WalkSpeed=tonumber(v) or 16; Move.Speed() end
    },"WalkSpeed")
    Sld(T,{
        Name="Jump Power", Range={50,300}, Increment=5,
        CurrentValue=50, Flag="JumpPower",
        Callback=function(v) State.JumpPower=tonumber(v) or 50; Move.Jump() end
    },"JumpPower")

    Sec(T, "Advanced")
    Tog(T,{
        Name="NoClip", CurrentValue=false, Flag="NoClip",
        Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end
    },"NoClip")
    Tog(T,{
        Name="Infinite Jump", CurrentValue=false, Flag="InfJump",
        Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end
    },"InfJump")

    Sec(T, "Teleport")
    Btn(T,{Name="TP Nearest Generator", Callback=Move.NearestGen},"TPGen")
    Inp(T,{
        Name="Player Name",
        PlaceholderText="Enter name (case-sensitive)",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) tpTarget=tostring(v or "") end
    },"TPInput")
    Btn(T,{Name="TP to Player", Callback=Move.ToPlayer},"TPPlayer")
end

-- ── VISUALS ──────────────────────────────────────────────────
if Tabs.Visuals then
    local T = Tabs.Visuals

    Sec(T, "Lighting")
    Tog(T,{Name="FullBright",    CurrentValue=false, Flag="FullBright",   Callback=function(v) State.FullBright=v;   Vis.FullBright(v) end},"FB")
    Tog(T,{Name="No Fog",        CurrentValue=false, Flag="NoFog",        Callback=function(v) State.NoFog=v;         Vis.NoFog(v)      end},"NFog")
    Tog(T,{Name="No Shadows",    CurrentValue=false, Flag="NoShadows",    Callback=function(v) State.NoShadows=v;    Vis.NoShadows(v)  end},"NShadows")
    Tog(T,{Name="Clear Weather", CurrentValue=false, Flag="ClearWeather", Callback=function(v) State.ClearWeather=v; Vis.ClearWx(v)    end},"ClearWx")
    Sld(T,{
        Name="Time of Day", Range={0,24}, Increment=1,
        CurrentValue=14, Flag="TimeOfDay",
        Callback=function(v) State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime) end
    },"TimeOfDay")

    Sec(T, "Camera")
    Sld(T,{
        Name="Field of View", Range={30,120}, Increment=5,
        CurrentValue=70, Flag="FOV",
        Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end
    },"FOV")
    Tog(T,{
        Name="Freecam", CurrentValue=false, Flag="Freecam",
        Callback=function(v) State.Freecam=v; Vis.Freecam(v) end
    },"Freecam")

    Sec(T, "Post-Processing")
    Tog(T,{Name="Remove Blur/Bloom",       CurrentValue=false, Flag="RmBlur", Callback=function(v) State.RemoveBlur=v;  Vis.PostFX(v)    end},"RmBlur")
    Tog(T,{Name="Remove Color Correction", CurrentValue=false, Flag="RmCC",   Callback=function(v) State.RemoveCC=v;    Vis.ColorCorr(v) end},"RmCC")
    Tog(T,{Name="No Particles",            CurrentValue=false, Flag="NoPart", Callback=function(v) State.NoParticles=v; Vis.Particles(v) end},"NoPart")

    Sec(T, "Performance")
    Tog(T,{
        Name="Low Graphics", CurrentValue=false, Flag="LowGfx",
        Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end
    },"LowGfx")
end

-- ── MISC ─────────────────────────────────────────────────────
if Tabs.Misc then
    local T = Tabs.Misc

    Sec(T, "Audio")
    Tog(T,{Name="Mute All Sounds",       CurrentValue=false, Flag="MuteAll", Callback=function(v) State.NoSound=v;     Vis.MuteAll(v) end},"MuteAll")
    Tog(T,{Name="Mute Background Music", CurrentValue=false, Flag="MuteBG",  Callback=function(v) State.MuteBGMusic=v; Vis.MuteBG(v)  end},"MuteBG")

    Sec(T, "Character")
    Tog(T,{
        Name="Hide Own Name", CurrentValue=false, Flag="HideName",
        Callback=function(v) State.HideName=v; Vis.HideName(v) end
    },"HideName")

    Sec(T, "Utility")
    Tog(T,{
        Name="Auto Rejoin", CurrentValue=false, Flag="AutoRejoin",
        Callback=function(v) State.AutoRejoin=v end
    },"AutoRejoin")
    Btn(T,{Name="Server Hop",  Callback=Vis.ServerHop},"ServerHop")
    Btn(T,{
        Name="Copy JobId",
        Callback=function()
            if setclipboard then
                setclipboard(tostring(game.JobId))
                Notify("Copied","JobId copied to clipboard!",3)
            else
                Notify("Error","Clipboard not supported on this executor.",3)
            end
        end
    },"CopyJob")
    Btn(T,{
        Name="Rejoin",
        Callback=function()
            pcall(function()
                game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
            end)
        end
    },"Rejoin")
end

-- ── SETTINGS ─────────────────────────────────────────────────
if Tabs.Settings then
    local T = Tabs.Settings

    Sec(T, "Anti-AFK")
    Tog(T,{
        Name="Anti-AFK", CurrentValue=true, Flag="AntiAFK",
        Callback=function(v) State.AntiAFK=v end
    },"AntiAFK")

    Sec(T, "Keybinds")
    Kbnd(T,{
        Name="Toggle UI", CurrentKeybind="RightShift",
        HoldToInteract=false, Flag="KB_Toggle",
        Callback=function()
            pcall(function() Window:Toggle() end)
        end
    },"KB_Toggle")
    Kbnd(T,{
        Name="Panic — Clear All ESP", CurrentKeybind="End",
        HoldToInteract=false, Flag="KB_Panic",
        Callback=function()
            State.ESP_Killer=false; State.ESP_Survivors=false
            State.ESP_Generators=false; State.ESP_Items=false
            State.ESP_Weapons=false;    State.ESP_Clones=false
            ESP.ClearAll()
            Notify("Panic","All ESP cleared!",3)
        end
    },"KB_Panic")

    Sec(T, "Credits")
    Lbl(T, HUB.Name .. " v" .. HUB.Version)
    Lbl(T, "Author: " .. HUB.Author)
    Lbl(T, "Game: " .. HUB.Game)
    Lbl(T, "Executors: Xeno, Medium, Delta, Solara, Wave")

    Sec(T, "Danger Zone")
    Btn(T,{
        Name="Unload Hub",
        Callback=function()
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
            Log("Hub unloaded")
        end
    },"Unload")
end

Log("All controls created")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- POST-BUILD SETUP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SetupAwareness()

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

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end, "OnTeleport")

-- Lighting enforcement loop
task.spawn(function()
    while task.wait(5) do
        if State.FullBright   then pcall(Vis.FullBright, true) end
        if State.NoFog        then pcall(Vis.NoFog,      true) end
        if State.NoShadows    then pcall(Vis.NoShadows,  true) end
        if State.ClearWeather then pcall(Vis.ClearWx,    true) end
    end
end)

-- Register destroy for guard
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

Notify(HUB.Name, "Loaded v" .. HUB.Version .. " — Enjoy!", 5)
Log("Initialization complete — v" .. HUB.Version)
