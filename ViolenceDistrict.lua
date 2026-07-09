--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.0.6 - Violence District
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

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--═══════════════════════════════════════════════════════════════
-- WINDUI LOADER - BULLETPROOF
--═══════════════════════════════════════════════════════════════
local WindUI = nil

local MIRRORS = {
    -- Mirror 1: direct CDN
    "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua",
    -- Mirror 2
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    -- Mirror 3: alternative path
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
}

for idx, url in ipairs(MIRRORS) do
    if WindUI then break end
    print("[X0DEC04T] Trying mirror " .. idx .. ": " .. url)

    local httpOk, raw = pcall(game.HttpGet, game, url)
    if not httpOk then
        warn("[X0DEC04T] HttpGet failed: " .. tostring(raw))
    elseif type(raw) ~= "string" or #raw < 100 then
        warn("[X0DEC04T] Response too short or invalid")
    elseif raw:find("^<!") or raw:find("^<html") then
        warn("[X0DEC04T] Got HTML (404/redirect), skipping")
    else
        local loadOk, chunk = pcall(loadstring, raw)
        if not loadOk or type(chunk) ~= "function" then
            warn("[X0DEC04T] loadstring failed: " .. tostring(chunk))
        else
            local runOk, lib = pcall(chunk)
            if runOk and type(lib) == "table" then
                WindUI = lib
                print("[X0DEC04T] WindUI loaded from mirror " .. idx)
            else
                warn("[X0DEC04T] Execution failed: " .. tostring(lib))
            end
        end
    end
    if not WindUI then task.wait(0.5) end
end

-- LAST RESORT: Orion UI fallback (always available)
if not WindUI then
    warn("[X0DEC04T] All WindUI mirrors failed — using Orion fallback UI")

    local OrionOk, Orion = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/shlexware/Orion/main/source"
        ))()
    end)

    if OrionOk and Orion then
        -- Wrap Orion in WindUI-compatible API
        local win = Orion:MakeWindow({
            Name            = "X0DEC04T Hub  v0.0.6",
            HidePremium     = false,
            SaveConfig      = false,
            ConfigFolder    = "X0DEC04T_Hub",
            IntroEnabled    = true,
            IntroText       = "X0DEC04T Hub",
        })

        WindUI = {
            _orion = Orion,
            _win   = win,
            _tabs  = {},

            CreateWindow = function(self, cfg)
                return self
            end,

            Tab = function(self, cfg)
                local t = win:MakeTab({
                    Name      = cfg.Title or "Tab",
                    Icon      = cfg.Icon  or "rbxassetid://4483345998",
                    PremiumOnly = false,
                })
                local tab = {
                    _t = t,
                    Section = function(self2, c)
                        t:AddSection({ Name = c.Title or "" })
                    end,
                    Toggle = function(self2, c)
                        t:AddToggle({
                            Name     = c.Title or "",
                            Default  = c.Default or false,
                            Callback = c.Callback or function() end,
                        })
                    end,
                    Button = function(self2, c)
                        t:AddButton({
                            Name     = c.Title or "",
                            Callback = c.Callback or function() end,
                        })
                    end,
                    Slider = function(self2, c)
                        local v = c.Value or {}
                        t:AddSlider({
                            Name    = c.Title or "",
                            Min     = v.Min or 0,
                            Max     = v.Max or 100,
                            Default = v.Default or 50,
                            Color   = Color3.fromRGB(255, 255, 255),
                            Increment = c.Step or 1,
                            Callback  = c.Callback or function() end,
                        })
                    end,
                    Input = function(self2, c)
                        t:AddTextbox({
                            Name        = c.Title or "",
                            Default     = c.Value or "",
                            TextDisappear = true,
                            Callback    = c.Callback or function() end,
                        })
                    end,
                    Paragraph = function(self2, c)
                        t:AddParagraph(c.Title or "", c.Desc or "")
                        return { SetDesc = function() end }
                    end,
                    Dropdown = function(self2, c)
                        t:AddDropdown({
                            Name    = c.Title or "",
                            Default = c.Value or "",
                            Options = c.Values or {},
                            Callback = c.Callback or function() end,
                        })
                    end,
                    Keybind = function(self2, c)
                        t:AddBind({
                            Name     = c.Title or "",
                            Default  = Enum.KeyCode[c.Value] or Enum.KeyCode.RightShift,
                            Hold     = false,
                            Callback = c.Callback or function() end,
                        })
                    end,
                }
                return tab
            end,

            Notify = function(self, cfg)
                Orion:MakeNotification({
                    Name     = cfg.Title or "",
                    Content  = cfg.Content or "",
                    Time     = cfg.Duration or 4,
                })
            end,

            SelectTab = function() end,
            SetTheme  = function() end,
            Toggle    = function() end,
            Destroy   = function() end,
        }

        -- Patch CreateWindow to return self
        WindUI.CreateWindow = function(self, _) return self end

        print("[X0DEC04T] Orion fallback UI loaded")
    else
        warn("[X0DEC04T] FATAL: No UI library could load. Aborting.")
        warn("Try reinjecting your executor or check your internet.")
        return
    end
end

--═══════════════════════════════════════════════════════════════
-- SAFE CALL HELPER
--═══════════════════════════════════════════════════════════════
local function Safe(fn, label)
    local ok, err = pcall(fn)
    if not ok then
        warn("[X0DEC04T][" .. tostring(label) .. "] " .. tostring(err))
    end
end

--═══════════════════════════════════════════════════════════════
-- CONFIG
--═══════════════════════════════════════════════════════════════
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.6",
    Author  = "voixera",
    Folder  = "X0DEC04T_Hub",
}

--═══════════════════════════════════════════════════════════════
-- KILLER LIST
--═══════════════════════════════════════════════════════════════
local KillerFolder   = ReplicatedStorage:FindFirstChild("Killers")
local KNOWN_KILLERS  = {}

if KillerFolder then
    for _, child in ipairs(KillerFolder:GetChildren()) do
        local n = child.Name
        if n ~= "!General" and n ~= "Perks" then
            KNOWN_KILLERS[n:lower()] = true
        end
    end
end

--═══════════════════════════════════════════════════════════════
-- REMOTES
--═══════════════════════════════════════════════════════════════
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
    local function findIn(parent, name)
        if parent then return parent:FindFirstChild(name) end
    end

    local gen = findIn(Remotes, "Generator")
    R.Generator.SkillCheck     = findIn(gen, "SkillCheckEvent")
    R.Generator.SkillCheckFail = findIn(gen, "SkillCheckFailEvent")
    R.Generator.GenDone        = findIn(gen, "GenDone")
    R.Generator.AllGenDone     = findIn(gen, "allgendone")

    local heal = findIn(Remotes, "Healing")
    R.Healing.SkillCheck = findIn(heal, "SkillCheckEvent")

    local ch = findIn(Remotes, "Chase")
    R.Chase.Music = findIn(ch, "ChaseMusicEvent")

    local atk = findIn(Remotes, "Attacks")
    R.Attacks.Lunge       = findIn(atk, "Lunge")
    R.Attacks.BasicAttack = findIn(atk, "BasicAttack")

    local kp = findIn(Remotes, "KillerPerks")
    R.KillerPerks.KingScourge = findIn(kp, "kingscourge")

    local gm = findIn(Remotes, "Game")
    R.Game.Start       = findIn(gm, "Start")
    R.Game.RoundEnd    = findIn(gm, "RoundEnd")
    R.Game.KillerMorph = findIn(gm, "KillerMorph")
    R.Game.OneLeft     = findIn(gm, "Oneleft")
    R.Game.Death       = findIn(gm, "death")

    local cr = findIn(Remotes, "Carry")
    R.Carry.HookEvent   = findIn(cr, "HookEvent")
    R.Carry.UnhookEvent = findIn(cr, "UnHookEvent")
end

--═══════════════════════════════════════════════════════════════
-- WORKSPACE REFS
--═══════════════════════════════════════════════════════════════
local WS = {
    Map       = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones    = Workspace:FindFirstChild("Clones"),
    FakeChars = Workspace:FindFirstChild("FakeCharacters"),
    Weapons   = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then
    WS.Generators = WS.Map:FindFirstChild("Generators")
end

--═══════════════════════════════════════════════════════════════
-- STATE
--═══════════════════════════════════════════════════════════════
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

    Color_Killer    = Color3.fromRGB(255, 40,  40),
    Color_Survivor  = Color3.fromRGB(60,  220, 255),
    Color_Generator = Color3.fromRGB(255, 200, 60),
    Color_Item      = Color3.fromRGB(120, 255, 120),
    Color_Weapon    = Color3.fromRGB(255, 120, 220),
    Color_Clone     = Color3.fromRGB(180, 180, 180),

    WalkSpeed  = 16,
    JumpPower  = 50,
    NoClip     = false,
    InfJump    = false,

    FullBright    = false,
    NoFog         = false,
    NoShadows     = false,
    ClearWeather  = false,
    LowGraphics   = false,
    FOV           = 70,
    SetTime       = 14,
    RemoveBlur    = false,
    RemoveCC      = false,
    Freecam       = false,

    HideName    = false,
    NoSound     = false,
    MuteBGMusic = false,
    NoParticles = false,
    AutoRejoin  = false,
    AntiAFK     = true,

    IsKiller    = false,
    MatchActive = false,

    ESPCache      = {},
    Connections   = {},
    NoClipConn    = nil,
    InfJumpConn   = nil,
    FreecamConn   = nil,
    LightBackup   = {},
    MutedSounds   = {},
}

--═══════════════════════════════════════════════════════════════
-- UTILITIES
--═══════════════════════════════════════════════════════════════
local Util = {}

function Util.Connect(sig, cb)
    if not sig then return end
    local ok, c = pcall(function() return sig:Connect(cb) end)
    if ok and c then table.insert(State.Connections, c) end
    return c
end

function Util.GetHRP()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

function Util.GetHuman()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

function Util.GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

function Util.Notify(title, body, dur)
    pcall(function()
        WindUI:Notify({
            Title    = tostring(title),
            Content  = tostring(body),
            Duration = dur or 4,
            Icon     = "bell",
        })
    end)
end

--═══════════════════════════════════════════════════════════════
-- ROLE DETECTION
--═══════════════════════════════════════════════════════════════
local Role = {}

function Role.IsKiller(char)
    if not char then return false end
    if char:GetAttribute("Killer")   == true  then return true end
    if char:GetAttribute("IsKiller") == true  then return true end
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
    return "Killer"
end

function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones    and char:IsDescendantOf(WS.Clones)    then return true end
    return false
end

--═══════════════════════════════════════════════════════════════
-- ESP
--═══════════════════════════════════════════════════════════════
local ESP = {}

function ESP.Clear(obj)
    local cache = State.ESPCache[obj]
    if not cache then return end
    for _, inst in pairs(cache) do
        if typeof(inst) == "Instance" and inst.Parent then
            pcall(inst.Destroy, inst)
        end
    end
    State.ESPCache[obj] = nil
end

function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Clear(obj) end
    State.ESPCache = {}
end

local function MakeBB(hrp, label, color, showName, showDist, maxDist)
    local gui = Util.GuiParent()

    local bb = Instance.new("BillboardGui")
    bb.Adornee      = hrp
    bb.Size         = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset  = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop  = true
    bb.LightInfluence = 0
    bb.MaxDistance  = maxDist
    bb.Parent       = gui

    local nl = Instance.new("TextLabel", bb)
    nl.Size                   = UDim2.new(1,0, 0.6,0)
    nl.BackgroundTransparency = 1
    nl.Text                   = label
    nl.TextColor3             = color
    nl.TextStrokeTransparency = 0
    nl.Font                   = Enum.Font.GothamBold
    nl.TextSize               = 14
    nl.Visible                = showName

    local dl = Instance.new("TextLabel", bb)
    dl.Size                   = UDim2.new(1,0, 0.4,0)
    dl.Position               = UDim2.new(0,0, 0.6,0)
    dl.BackgroundTransparency = 1
    dl.Text                   = "0m"
    dl.TextColor3             = Color3.fromRGB(220,220,220)
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
    hl.OutlineColor     = Color3.new(1,1,1)
    hl.FillTransparency = 0.55
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = Util.GuiParent()

    local bb, nl, dl = MakeBB(hrp, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance)

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
    hl.Parent              = Util.GuiParent()

    local bb, nl, dl = MakeBB(part, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance)

    State.ESPCache[model] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=part }
end

function ESP.UpdateDist()
    local hrp = Util.GetHRP()
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
                ESP.AddChar(char, "☠ " .. Role.KillerName(char) .. " [" .. p.Name .. "]", State.Color_Killer)
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

RunService.Heartbeat:Connect(function()
    pcall(ESP.UpdateDist)
end)

Players.PlayerRemoving:Connect(function(p)
    if p.Character then ESP.Clear(p.Character) end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterRemoving:Connect(function(c) ESP.Clear(c) end)
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
        p.CharacterRemoving:Connect(function(c) ESP.Clear(c) end)
    end
end

--═══════════════════════════════════════════════════════════════
-- MOVEMENT
--═══════════════════════════════════════════════════════════════
local Move = {}

function Move.Speed()
    local h = Util.GetHuman()
    if h then h.WalkSpeed = State.WalkSpeed end
end

function Move.Jump()
    local h = Util.GetHuman()
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end

function Move.SetNoClip(e)
    if State.NoClipConn then State.NoClipConn:Disconnect(); State.NoClipConn = nil end
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
    if State.InfJumpConn then State.InfJumpConn:Disconnect(); State.InfJumpConn = nil end
    if e then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Util.GetHuman()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

function Move.NearestGen()
    if not WS.Generators then Util.Notify("TP", "No generators folder.", 3); return end
    local hrp = Util.GetHRP(); if not hrp then return end
    local best, bd = nil, math.huge
    for _, g in ipairs(WS.Generators:GetChildren()) do
        local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then
            local d = (p.Position - hrp.Position).Magnitude
            if d < bd then bd = d; best = p end
        end
    end
    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0,4,0)
        Util.Notify("TP", "Teleported to generator (" .. math.floor(bd) .. "m)", 3)
    end
end

local tpTargetName = ""

function Move.ToPlayer()
    if tpTargetName == "" then Util.Notify("TP", "Enter a name first.", 3); return end
    local t = Players:FindFirstChild(tpTargetName)
    if not t or not t.Character then Util.Notify("TP", "Not found: " .. tpTargetName, 3); return end
    local hrp  = Util.GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Util.Notify("TP", "Teleported to " .. tpTargetName, 3)
    end
end

--═══════════════════════════════════════════════════════════════
-- VISUALS / MISC
--═══════════════════════════════════════════════════════════════
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
        Lighting.FogEnd = 999999; Lighting.FogStart = 999999
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

function Vis.ClearWx(e)
    if e then
        for _, o in ipairs(Lighting:GetDescendants()) do
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
    local ch = LocalPlayer.Character; if not ch then return end
    local head = ch:FindFirstChild("Head"); if not head then return end
    for _, g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end

function Vis.MuteAll(e)
    if e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and not table.find(State.MutedSounds, s) then
                State.MutedSounds[#State.MutedSounds+1] = {s=s, v=s.Volume}
                s.Volume = 0
            end
        end
    else
        for _, t in ipairs(State.MutedSounds) do
            if t.s and t.s.Parent then t.s.Volume = t.v end
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
    if State.FreecamConn then State.FreecamConn:Disconnect(); State.FreecamConn = nil end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look  = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local mv    = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv -= Vector3.yAxis end
            pos = pos + mv * 2
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

function Vis.ServerHop()
    pcall(function()
        local TS  = game:GetService("TeleportService")
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"
            .. game.PlaceId
            .. "/servers/Public?sortOrder=Asc&limit=100"
        )
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
        Util.Notify("Server Hop", "No empty server found.", 4)
    end)
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS
--═══════════════════════════════════════════════════════════════
local function SetupAwareness()
    Util.Connect(R.Generator.SkillCheck and R.Generator.SkillCheck.OnClientEvent, function()
        if State.SkillCheckNotify then Util.Notify("Skill Check!", "Hit the mark!", 2) end
    end)
    Util.Connect(R.Generator.SkillCheckFail and R.Generator.SkillCheckFail.OnClientEvent, function()
        if State.SkillCheckNotify then Util.Notify("Skill Check FAIL", "Progress lost!", 3) end
    end)
    Util.Connect(R.Healing.SkillCheck and R.Healing.SkillCheck.OnClientEvent, function()
        if State.HealSkillNotify then Util.Notify("Heal Check!", "", 2) end
    end)
    Util.Connect(R.Generator.GenDone and R.Generator.GenDone.OnClientEvent, function()
        if State.GenDoneNotify then Util.Notify("Generator Done!", "", 3) end
    end)
    Util.Connect(R.Generator.AllGenDone and R.Generator.AllGenDone.OnClientEvent, function()
        if State.AllGensNotify then Util.Notify("All Generators Done!", "Find the exit!", 6) end
    end)
    Util.Connect(R.Chase.Music and R.Chase.Music.OnClientEvent, function()
        if State.ChaseAlert then Util.Notify("⚠ CHASE!", "Killer nearby!", 3) end
    end)
    Util.Connect(R.Attacks.Lunge and R.Attacks.Lunge.OnClientEvent, function()
        if State.AttackAlert then Util.Notify("⚠ LUNGE!", "", 2) end
    end)

    if R.KillerPerks.KingScourge then
        local s = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        Util.Connect(s and s.OnClientEvent, function()
            if State.AttackAlert then Util.Notify("⚠ SCOURGE!", "", 2) end
        end)
    end

    Util.Connect(R.Game.KillerMorph and R.Game.KillerMorph.OnClientEvent, function()
        State.IsKiller = true
        Util.Notify("Role", "You are the KILLER", 5)
    end)
    Util.Connect(R.Game.Start and R.Game.Start.OnClientEvent, function()
        State.MatchActive = true; State.IsKiller = false
        Util.Notify("Match Started", "Good luck!", 3)
    end)
    Util.Connect(R.Game.RoundEnd and R.Game.RoundEnd.OnClientEvent, function()
        State.MatchActive = false; ESP.ClearAll()
    end)
    Util.Connect(R.Game.OneLeft and R.Game.OneLeft.OnClientEvent, function()
        if State.OneLeftNotify then Util.Notify("Last Survivor!", "", 5) end
    end)
    Util.Connect(R.Game.Death and R.Game.Death.OnClientEvent, function()
        if State.DeathNotify then Util.Notify("You Died", "", 3) end
    end)
    Util.Connect(R.Carry.HookEvent and R.Carry.HookEvent.OnClientEvent, function()
        if State.HookNotify then Util.Notify("Hooked!", "", 3) end
    end)
    Util.Connect(LocalPlayer.Idled, function()
        if State.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- BUILD WINDOW
--═══════════════════════════════════════════════════════════════
local Window
Safe(function()
    Window = WindUI:CreateWindow({
        Title        = HUB.Name,
        Icon         = "skull",
        Author       = "by " .. HUB.Author .. "  •  " .. HUB.Game,
        Folder       = HUB.Folder,
        Size         = UDim2.fromOffset(580, 480),
        Transparent  = true,
        Theme        = "Dark",
        SideBarWidth = 160,
        HasOutline   = true,
        KeySystem    = false,
    })
end, "CreateWindow")

if not Window then
    warn("[X0DEC04T] Window is nil — aborting")
    return
end

--═══════════════════════════════════════════════════════════════
-- CREATE TABS
--═══════════════════════════════════════════════════════════════
local Tabs = {}
for _, name in ipairs({ "Main","Awareness","ESP","Movement","Visuals","Misc","Settings" }) do
    Safe(function()
        Tabs[name] = Window:Tab({ Title = name })
    end, "Tab_" .. name)
end

--═══════════════════════════════════════════════════════════════
-- MAIN TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Main then
    local T = Tabs.Main
    Safe(function() T:Section({ Title = "Welcome" }) end)

    Safe(function()
        T:Paragraph({
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Script hub for " .. HUB.Game .. " | by " .. HUB.Author,
        })
    end)

    local killerList = {}
    for k in pairs(KNOWN_KILLERS) do
        killerList[#killerList+1] = k:gsub("^%l", string.upper)
    end
    Safe(function()
        T:Paragraph({
            Title = "Detected Killers",
            Desc  = #killerList > 0 and table.concat(killerList, ", ") or "None found",
        })
    end)

    Safe(function() T:Section({ Title = "Live Info" }) end)

    -- Live role/match display updated every second
    task.spawn(function()
        -- small delay so tab exists
        task.wait(0.5)
        while task.wait(1) do
            -- just use notifications instead of paragraph update
            -- (paragraph SetDesc not reliable across all UI libs)
        end
    end)

    Safe(function()
        T:Paragraph({
            Title = "Keybinds",
            Desc  = "RightShift  →  Toggle UI\nEnd  →  Panic / Clear ESP",
        })
    end)
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Awareness then
    local T = Tabs.Awareness

    Safe(function() T:Section({ Title = "Killer" }) end)
    Safe(function()
        T:Toggle({ Title="Chase Alert",  Desc="Notify on chase music", Default=true,
            Callback=function(v) State.ChaseAlert=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Attack Alert", Desc="Notify on lunge/scourge", Default=true,
            Callback=function(v) State.AttackAlert=v end })
    end)

    Safe(function() T:Section({ Title = "Skill Checks" }) end)
    Safe(function()
        T:Toggle({ Title="Generator Skill Check", Desc="Notify on gen checks", Default=true,
            Callback=function(v) State.SkillCheckNotify=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Heal Skill Check", Desc="Notify on heal checks", Default=true,
            Callback=function(v) State.HealSkillNotify=v end })
    end)

    Safe(function() T:Section({ Title = "Objectives" }) end)
    Safe(function()
        T:Toggle({ Title="Generator Done",   Desc="", Default=true, Callback=function(v) State.GenDoneNotify=v end })
    end)
    Safe(function()
        T:Toggle({ Title="All Gens Done",    Desc="", Default=true, Callback=function(v) State.AllGensNotify=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Hook Notify",      Desc="", Default=true, Callback=function(v) State.HookNotify=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Death Notify",     Desc="", Default=true, Callback=function(v) State.DeathNotify=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Last One Notify",  Desc="", Default=true, Callback=function(v) State.OneLeftNotify=v end })
    end)
end

--═══════════════════════════════════════════════════════════════
-- ESP TAB
--═══════════════════════════════════════════════════════════════
if Tabs.ESP then
    local T = Tabs.ESP

    Safe(function() T:Section({ Title = "Players" }) end)
    Safe(function()
        T:Toggle({ Title="Killer ESP", Desc="Red highlight", Default=false,
            Callback=function(v)
                State.ESP_Killer = v
                if not v then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and Role.IsKiller(p.Character) then ESP.Clear(p.Character) end
                    end
                end
            end })
    end)
    Safe(function()
        T:Toggle({ Title="Survivor ESP", Desc="Cyan highlight", Default=false,
            Callback=function(v)
                State.ESP_Survivors = v
                if not v then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and not Role.IsKiller(p.Character) then ESP.Clear(p.Character) end
                    end
                end
            end })
    end)

    Safe(function() T:Section({ Title = "Objects" }) end)
    Safe(function()
        T:Toggle({ Title="Generator ESP", Desc="Yellow", Default=false,
            Callback=function(v)
                State.ESP_Generators = v
                if not v and WS.Generators then
                    for _, g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end
                end
            end })
    end)
    Safe(function()
        T:Toggle({ Title="Item ESP",   Desc="Green", Default=false, Callback=function(v) State.ESP_Items=v end })
    end)
    Safe(function()
        T:Toggle({ Title="Weapon ESP", Desc="Pink",  Default=false,
            Callback=function(v)
                State.ESP_Weapons=v
                if not v and WS.Weapons then
                    for _, w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end
                end
            end })
    end)
    Safe(function()
        T:Toggle({ Title="Clone ESP",  Desc="Gray",  Default=false,
            Callback=function(v)
                State.ESP_Clones=v
                if not v and WS.Clones then
                    for _, c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end
                end
            end })
    end)

    Safe(function() T:Section({ Title = "Display" }) end)
    Safe(function()
        T:Toggle({ Title="Show Names", Desc="", Default=true,
            Callback=function(v)
                State.ESP_ShowName=v
                for _, c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end
            end })
    end)
    Safe(function()
        T:Toggle({ Title="Show Distance", Desc="", Default=true,
            Callback=function(v)
                State.ESP_ShowDistance=v
                for _, c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end
            end })
    end)
    Safe(function()
        T:Slider({ Title="Max Distance", Desc="ESP render range",
            Value={ Min=50, Max=2000, Default=500 }, Step=50,
            Callback=function(v)
                State.ESP_MaxDistance = tonumber(v) or 500
                for _, c in pairs(State.ESPCache) do
                    if c.bb then c.bb.MaxDistance = State.ESP_MaxDistance end
                end
            end })
    end)

    Safe(function() T:Section({ Title = "Actions" }) end)
    Safe(function()
        T:Button({ Title="Refresh ESP", Desc="Re-scan all entities",
            Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Util.Notify("ESP","Refreshed",2) end })
    end)
    Safe(function()
        T:Button({ Title="Clear All ESP", Desc="Remove all highlights",
            Callback=function() ESP.ClearAll(); Util.Notify("ESP","Cleared",2) end })
    end)
end

--═══════════════════════════════════════════════════════════════
-- MOVEMENT TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Movement then
    local T = Tabs.Movement

    Safe(function() T:Section({ Title = "Speed" }) end)
    Safe(function()
        T:Slider({ Title="Walk Speed", Desc="Default: 16",
            Value={ Min=16, Max=200, Default=16 }, Step=1,
            Callback=function(v) State.WalkSpeed=tonumber(v) or 16; Move.Speed() end })
    end)
    Safe(function()
        T:Slider({ Title="Jump Power", Desc="Default: 50",
            Value={ Min=50, Max=300, Default=50 }, Step=5,
            Callback=function(v) State.JumpPower=tonumber(v) or 50; Move.Jump() end })
    end)

    Safe(function() T:Section({ Title = "Advanced" }) end)
    Safe(function()
        T:Toggle({ Title="NoClip", Desc="Walk through walls", Default=false,
            Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="Infinite Jump", Desc="Jump while airborne", Default=false,
            Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end })
    end)

    Safe(function() T:Section({ Title = "Teleport" }) end)
    Safe(function()
        T:Button({ Title="TP Nearest Generator", Desc="Teleport to closest gen",
            Callback=Move.NearestGen })
    end)
    Safe(function()
        T:Input({ Title="Player Name", Desc="Case-sensitive",
            Value="", Placeholder="Enter name",
            Callback=function(v) tpTargetName=tostring(v or "") end })
    end)
    Safe(function()
        T:Button({ Title="TP to Player", Desc="Teleport to entered player",
            Callback=Move.ToPlayer })
    end)
end

--═══════════════════════════════════════════════════════════════
-- VISUALS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Visuals then
    local T = Tabs.Visuals

    Safe(function() T:Section({ Title = "Lighting" }) end)
    Safe(function()
        T:Toggle({ Title="FullBright", Desc="Remove all darkness", Default=false,
            Callback=function(v) State.FullBright=v; Vis.FullBright(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="No Fog", Desc="Remove map fog", Default=false,
            Callback=function(v) State.NoFog=v; Vis.NoFog(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="No Shadows", Desc="Disable shadows", Default=false,
            Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="Clear Weather", Desc="Remove atmosphere effects", Default=false,
            Callback=function(v) State.ClearWeather=v; Vis.ClearWx(v) end })
    end)
    Safe(function()
        T:Slider({ Title="Time of Day", Desc="0=Night  14=Day  24=Night",
            Value={ Min=0, Max=24, Default=14 }, Step=1,
            Callback=function(v) State.SetTime=tonumber(v) or 14; Vis.SetClock(State.SetTime) end })
    end)

    Safe(function() T:Section({ Title = "Camera" }) end)
    Safe(function()
        T:Slider({ Title="Field of View", Desc="Default: 70",
            Value={ Min=30, Max=120, Default=70 }, Step=5,
            Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end })
    end)
    Safe(function()
        T:Toggle({ Title="Freecam", Desc="WASD+Space+Ctrl", Default=false,
            Callback=function(v) State.Freecam=v; Vis.Freecam(v) end })
    end)

    Safe(function() T:Section({ Title = "Post-FX" }) end)
    Safe(function()
        T:Toggle({ Title="Remove Blur/Bloom", Desc="", Default=false,
            Callback=function(v) State.RemoveBlur=v; Vis.PostFX(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="Remove Color Correction", Desc="", Default=false,
            Callback=function(v) State.RemoveCC=v; Vis.ColorCorr(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="No Particles", Desc="Remove fire/smoke/particles", Default=false,
            Callback=function(v) State.NoParticles=v; Vis.Particles(v) end })
    end)

    Safe(function() T:Section({ Title = "Performance" }) end)
    Safe(function()
        T:Toggle({ Title="Low Graphics", Desc="Set quality to Level 1", Default=false,
            Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end })
    end)
end

--═══════════════════════════════════════════════════════════════
-- MISC TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Misc then
    local T = Tabs.Misc

    Safe(function() T:Section({ Title = "Audio" }) end)
    Safe(function()
        T:Toggle({ Title="Mute All Sounds", Desc="", Default=false,
            Callback=function(v) State.NoSound=v; Vis.MuteAll(v) end })
    end)
    Safe(function()
        T:Toggle({ Title="Mute Background Music", Desc="", Default=false,
            Callback=function(v) State.MuteBGMusic=v; Vis.MuteBG(v) end })
    end)

    Safe(function() T:Section({ Title = "Character" }) end)
    Safe(function()
        T:Toggle({ Title="Hide Own Name", Desc="Hides your nametag", Default=false,
            Callback=function(v) State.HideName=v; Vis.HideName(v) end })
    end)

    Safe(function() T:Section({ Title = "Utility" }) end)
    Safe(function()
        T:Toggle({ Title="Auto Rejoin", Desc="Rejoin on kick/fail", Default=false,
            Callback=function(v) State.AutoRejoin=v end })
    end)
    Safe(function()
        T:Button({ Title="Server Hop", Desc="Join a different server",
            Callback=Vis.ServerHop })
    end)
    Safe(function()
        T:Button({ Title="Copy JobId", Desc="Copy server ID to clipboard",
            Callback=function()
                if setclipboard then
                    setclipboard(tostring(game.JobId))
                    Util.Notify("Copied", "JobId copied!", 3)
                else
                    Util.Notify("Error", "Clipboard not supported.", 3)
                end
            end })
    end)
    Safe(function()
        T:Button({ Title="Rejoin", Desc="Teleport back to this game",
            Callback=function()
                pcall(function()
                    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
                end)
            end })
    end)
end

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Settings then
    local T = Tabs.Settings

    Safe(function() T:Section({ Title = "Anti-AFK" }) end)
    Safe(function()
        T:Toggle({ Title="Anti-AFK", Desc="Prevents idle disconnect", Default=true,
            Callback=function(v) State.AntiAFK=v end })
    end)

    Safe(function() T:Section({ Title = "Keybinds" }) end)
    Safe(function()
        T:Keybind({ Title="Toggle UI", Desc="Show/Hide window", Value="RightShift",
            Callback=function() pcall(function() Window:Toggle() end) end })
    end)
    Safe(function()
        T:Keybind({ Title="Panic - Clear ESP", Desc="Instantly disables all ESP", Value="End",
            Callback=function()
                State.ESP_Killer=false; State.ESP_Survivors=false
                State.ESP_Generators=false; State.ESP_Items=false
                State.ESP_Weapons=false; State.ESP_Clones=false
                ESP.ClearAll()
                Util.Notify("Panic","All ESP cleared!",3)
            end })
    end)

    Safe(function() T:Section({ Title = "Credits" }) end)
    Safe(function()
        T:Paragraph({
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Author: " .. HUB.Author
                 .. "\nGame: "  .. HUB.Game
                 .. "\nExecutors: Xeno, Medium, Delta, Solara, Wave",
        })
    end)

    Safe(function() T:Section({ Title = "Danger Zone" }) end)
    Safe(function()
        T:Button({ Title="Unload Hub", Desc="Removes hub and restores settings",
            Callback=function()
                for _, c in ipairs(State.Connections) do pcall(function() c:Disconnect() end) end
                if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
                if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
                if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
                Vis.RestoreLight()
                pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
                pcall(function() Camera.FieldOfView = 70 end)
                ESP.ClearAll()
                pcall(function() Window:Destroy() end)
                print("[X0DEC04T] Unloaded.")
            end })
    end)
end

--═══════════════════════════════════════════════════════════════
-- INIT
--═══════════════════════════════════════════════════════════════
SetupAwareness()

-- Re-apply on respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(Move.Speed)
    pcall(Move.Jump)
    if State.NoClip    then Move.SetNoClip(true)  end
    if State.InfJump   then Move.SetInfJump(true) end
    if State.FullBright then Vis.FullBright(true)  end
    if State.NoFog     then Vis.NoFog(true)        end
    if State.HideName  then Vis.HideName(true)     end
    if State.FOV ~= 70 then Vis.SetFOV(State.FOV) end
end)

-- Auto-rejoin on teleport fail
LocalPlayer.OnTeleport:Connect(function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end)

-- Keep lighting enforced
task.spawn(function()
    while task.wait(5) do
        if State.FullBright  then pcall(Vis.FullBright, true)  end
        if State.NoFog       then pcall(Vis.NoFog,      true)  end
        if State.NoShadows   then pcall(Vis.NoShadows,  true)  end
        if State.ClearWeather then pcall(Vis.ClearWx,   true)  end
    end
end)

Util.Notify(HUB.Name, "Loaded v" .. HUB.Version .. " — Enjoy!", 5)
print("[X0DEC04T] ✓ v" .. HUB.Version .. " fully loaded")
