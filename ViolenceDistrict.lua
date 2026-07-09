--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.0.6 - Violence District
-- Compatible with Xeno, Medium, Delta, Solara, Wave
--═══════════════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--═══════════════════════════════════════════════════════════════
-- WINDUI LOADER
--═══════════════════════════════════════════════════════════════
local WindUI
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"))()
end)

if success and type(result) == "table" then
    WindUI = result
    print("[X0DEC04T] WindUI loaded successfully")
else
    warn("[X0DEC04T] WindUI failed: " .. tostring(result))
    -- Fallback loader
    local fallbacks = {
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/src/init.lua",
    }
    for i, url in ipairs(fallbacks) do
        local ok, res = pcall(function()
            return loadstring(game:HttpGet(url))()
        end)
        if ok and type(res) == "table" then
            WindUI = res
            print("[X0DEC04T] WindUI loaded from fallback #" .. i)
            break
        else
            warn("[X0DEC04T] Fallback #" .. i .. " failed: " .. tostring(res))
        end
        task.wait(0.5)
    end
end

if not WindUI then
    warn("[X0DEC04T] All WindUI sources failed. Aborting.")
    return
end

--═══════════════════════════════════════════════════════════════
-- SAFE HELPER
--═══════════════════════════════════════════════════════════════
local function Safe(fn, label)
    local ok, err = pcall(fn)
    if not ok then
        warn("[X0DEC04T] Error in [" .. tostring(label or "?") .. "]: " .. tostring(err))
    end
end

--═══════════════════════════════════════════════════════════════
-- HUB CONFIG
--═══════════════════════════════════════════════════════════════
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.6",
    Author  = "voixera",
    Folder  = "X0DEC04T",
}

--═══════════════════════════════════════════════════════════════
-- KILLER ROSTER
--═══════════════════════════════════════════════════════════════
local KillerFolder = ReplicatedStorage:FindFirstChild("Killers")
local KNOWN_KILLERS = {}
if KillerFolder then
    for _, child in ipairs(KillerFolder:GetChildren()) do
        if child.Name ~= "!General" and child.Name ~= "Perks" then
            KNOWN_KILLERS[child.Name:lower()] = true
        end
    end
end

--═══════════════════════════════════════════════════════════════
-- REMOTES
--═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local R = {
    Generator = {},
    Healing   = {},
    Chase     = {},
    Attacks   = {},
    KillerPerks = {},
    Game      = {},
    Carry     = {},
}

if Remotes then
    local gen = Remotes:FindFirstChild("Generator")
    if gen then
        R.Generator.SkillCheck     = gen:FindFirstChild("SkillCheckEvent")
        R.Generator.SkillCheckFail = gen:FindFirstChild("SkillCheckFailEvent")
        R.Generator.GenDone        = gen:FindFirstChild("GenDone")
        R.Generator.AllGenDone     = gen:FindFirstChild("allgendone")
    end
    local heal = Remotes:FindFirstChild("Healing")
    if heal then
        R.Healing.SkillCheck = heal:FindFirstChild("SkillCheckEvent")
    end
    local ch = Remotes:FindFirstChild("Chase")
    if ch then
        R.Chase.Music = ch:FindFirstChild("ChaseMusicEvent")
    end
    local atk = Remotes:FindFirstChild("Attacks")
    if atk then
        R.Attacks.Lunge      = atk:FindFirstChild("Lunge")
        R.Attacks.BasicAttack = atk:FindFirstChild("BasicAttack")
    end
    local kp = Remotes:FindFirstChild("KillerPerks")
    if kp then
        R.KillerPerks.KingScourge = kp:FindFirstChild("kingscourge")
    end
    local gm = Remotes:FindFirstChild("Game")
    if gm then
        R.Game.Start       = gm:FindFirstChild("Start")
        R.Game.RoundEnd    = gm:FindFirstChild("RoundEnd")
        R.Game.KillerMorph = gm:FindFirstChild("KillerMorph")
        R.Game.OneLeft     = gm:FindFirstChild("Oneleft")
        R.Game.Death       = gm:FindFirstChild("death")
    end
    local cr = Remotes:FindFirstChild("Carry")
    if cr then
        R.Carry.HookEvent   = cr:FindFirstChild("HookEvent")
        R.Carry.UnhookEvent = cr:FindFirstChild("UnHookEvent")
    end
end

--═══════════════════════════════════════════════════════════════
-- WORKSPACE REFS
--═══════════════════════════════════════════════════════════════
local WS = {
    Map       = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Mazes     = Workspace:FindFirstChild("Mazes"),
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
    -- Awareness
    ChaseAlert        = true,
    AttackAlert       = true,
    SkillCheckNotify  = true,
    HealSkillNotify   = true,
    GenDoneNotify     = true,
    AllGensNotify     = true,
    OneLeftNotify     = true,
    HookNotify        = true,
    DeathNotify       = true,

    -- ESP
    ESP_Generators    = false,
    ESP_Killer        = false,
    ESP_Survivors     = false,
    ESP_Items         = false,
    ESP_Weapons       = false,
    ESP_Clones        = false,
    ESP_MaxDistance   = 500,
    ESP_ShowDistance  = true,
    ESP_ShowName      = true,
    Color_Killer      = Color3.fromRGB(255, 40, 40),
    Color_Survivor    = Color3.fromRGB(60, 220, 255),
    Color_Generator   = Color3.fromRGB(255, 200, 60),
    Color_Item        = Color3.fromRGB(120, 255, 120),
    Color_Weapon      = Color3.fromRGB(255, 120, 220),
    Color_Clone       = Color3.fromRGB(180, 180, 180),

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
    Time              = 14,
    RemoveBlur        = false,
    RemoveColorCorr   = false,
    Freecam           = false,

    -- Misc
    HideName          = false,
    NoSound           = false,
    MuteBGMusic       = false,
    NoParticles       = false,
    AutoRejoin        = false,
    AntiAFK           = true,

    -- Internal
    IsKiller          = false,
    MatchActive       = false,
    ESPCache          = {},
    Connections       = {},
    NoClipConn        = nil,
    InfJumpConn       = nil,
    FreecamConn       = nil,
    LightingBackup    = {},
    MutedSounds       = {},
}

--═══════════════════════════════════════════════════════════════
-- UTIL
--═══════════════════════════════════════════════════════════════
local Util = {}

function Util.SafeConnect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function()
        return signal:Connect(callback)
    end)
    if ok and conn then
        table.insert(State.Connections, conn)
        return conn
    end
end

function Util.GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Util.GetHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Util.Notify(title, content, dur)
    pcall(function()
        WindUI:Notify({
            Title    = title or HUB.Name,
            Content  = content or "",
            Duration = dur or 4,
            Icon     = "bell",
        })
    end)
end

function Util.GetGuiParent()
    local p = CoreGui
    pcall(function()
        if gethui then p = gethui() end
    end)
    return p
end

--═══════════════════════════════════════════════════════════════
-- ROLE
--═══════════════════════════════════════════════════════════════
local Role = {}

function Role.IsKiller(character)
    if not character then return false end
    if character:GetAttribute("Killer")   == true then return true end
    if character:GetAttribute("IsKiller") == true then return true end
    if character:GetAttribute("Role")     == "Killer" then return true end
    local n = character.Name:lower()
    for k, _ in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

function Role.GetKillerName(character)
    if not character then return "Unknown" end
    local n = character.Name:lower()
    for k, _ in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then
            return k:gsub("^%l", string.upper)
        end
    end
    return "Killer"
end

function Role.IsFakeCharacter(character)
    if not character then return true end
    if WS.FakeChars and character:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones    and character:IsDescendantOf(WS.Clones)    then return true end
    return false
end

--═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
--═══════════════════════════════════════════════════════════════
local ESP = {}

function ESP.Clear(adornee)
    if State.ESPCache[adornee] then
        for _, obj in pairs(State.ESPCache[adornee]) do
            if typeof(obj) == "Instance" and obj.Parent then
                pcall(function() obj:Destroy() end)
            end
        end
        State.ESPCache[adornee] = nil
    end
end

function ESP.ClearAll()
    for a, _ in pairs(State.ESPCache) do
        ESP.Clear(a)
    end
    State.ESPCache = {}
end

function ESP.CreateCharacterESP(character, label, color)
    if State.ESPCache[character] then ESP.Clear(character) end
    local hrp = character:FindFirstChild("HumanoidRootPart")
              or character:FindFirstChild("Torso")
              or character:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local guiParent = Util.GetGuiParent()

    -- Highlight
    local hl = Instance.new("Highlight")
    hl.Adornee           = character
    hl.FillColor         = color
    hl.OutlineColor      = Color3.new(1, 1, 1)
    hl.FillTransparency  = 0.55
    hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent            = guiParent

    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Adornee    = hrp
    bb.Size       = UDim2.new(0, 200, 0, 45)
    bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = math.max(50, State.ESP_MaxDistance)
    bb.Parent      = guiParent

    local nl = Instance.new("TextLabel")
    nl.Size                 = UDim2.new(1, 0, 0.6, 0)
    nl.BackgroundTransparency = 1
    nl.Text                 = tostring(label)
    nl.TextColor3           = color
    nl.TextStrokeTransparency = 0
    nl.Font                 = Enum.Font.GothamBold
    nl.TextSize             = 14
    nl.Visible              = State.ESP_ShowName
    nl.Parent               = bb

    local dl = Instance.new("TextLabel")
    dl.Size                 = UDim2.new(1, 0, 0.4, 0)
    dl.Position             = UDim2.new(0, 0, 0.6, 0)
    dl.BackgroundTransparency = 1
    dl.Text                 = "0m"
    dl.TextColor3           = Color3.fromRGB(230, 230, 230)
    dl.TextStrokeTransparency = 0
    dl.Font                 = Enum.Font.Gotham
    dl.TextSize             = 12
    dl.Visible              = State.ESP_ShowDistance
    dl.Parent               = bb

    State.ESPCache[character] = {
        highlight  = hl,
        billboard  = bb,
        nameLabel  = nl,
        distLabel  = dl,
        hrp        = hrp,
    }
end

function ESP.CreateObjectESP(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end

    local part = model
    if model:IsA("Model") then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end

    local guiParent = Util.GetGuiParent()

    local hl = Instance.new("Highlight")
    hl.Adornee             = model
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.7
    hl.OutlineTransparency = 0.2
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = guiParent

    local bb = Instance.new("BillboardGui")
    bb.Adornee     = part
    bb.Size        = UDim2.new(0, 180, 0, 45)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = math.max(50, State.ESP_MaxDistance)
    bb.Parent      = guiParent

    local nl = Instance.new("TextLabel")
    nl.Size                 = UDim2.new(1, 0, 0.6, 0)
    nl.BackgroundTransparency = 1
    nl.Text                 = tostring(label)
    nl.TextColor3           = color
    nl.TextStrokeTransparency = 0
    nl.Font                 = Enum.Font.GothamBold
    nl.TextSize             = 13
    nl.Visible              = State.ESP_ShowName
    nl.Parent               = bb

    local dl = Instance.new("TextLabel")
    dl.Size                 = UDim2.new(1, 0, 0.4, 0)
    dl.Position             = UDim2.new(0, 0, 0.6, 0)
    dl.BackgroundTransparency = 1
    dl.Text                 = "0m"
    dl.TextColor3           = Color3.fromRGB(220, 220, 220)
    dl.TextStrokeTransparency = 0
    dl.Font                 = Enum.Font.Gotham
    dl.TextSize             = 11
    dl.Visible              = State.ESP_ShowDistance
    dl.Parent               = bb

    State.ESPCache[model] = {
        highlight = hl,
        billboard = bb,
        nameLabel = nl,
        distLabel = dl,
        hrp       = part,
    }
end

function ESP.UpdateDistances()
    local hrp = Util.GetHRP()
    if not hrp then return end
    for _, cache in pairs(State.ESPCache) do
        if cache.distLabel and cache.hrp and cache.hrp.Parent then
            local dist = math.floor(
                (cache.hrp.Position - hrp.Position).Magnitude
            )
            cache.distLabel.Text = tostring(dist) .. "m"
        end
    end
end

function ESP.Validate()
    for a, _ in pairs(State.ESPCache) do
        if not a or not a.Parent then
            ESP.Clear(a)
        end
    end
end

function ESP.ScanPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and not Role.IsFakeCharacter(char) then
                local isK = Role.IsKiller(char)
                if isK and State.ESP_Killer then
                    if not State.ESPCache[char] then
                        ESP.CreateCharacterESP(
                            char,
                            "☠ " .. Role.GetKillerName(char) .. " [" .. plr.Name .. "]",
                            State.Color_Killer
                        )
                    end
                elseif not isK and State.ESP_Survivors then
                    if not State.ESPCache[char] then
                        ESP.CreateCharacterESP(
                            char,
                            "◈ " .. plr.Name,
                            State.Color_Survivor
                        )
                    end
                else
                    ESP.Clear(char)
                end
            end
        end
    end
end

function ESP.ScanGenerators()
    if not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators then
            if not State.ESPCache[gen] then
                ESP.CreateObjectESP(gen, "⚡ " .. gen.Name, State.Color_Generator)
            end
        else
            ESP.Clear(gen)
        end
    end
end

function ESP.ScanItems()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model")
        and (obj:GetAttribute("Item") or obj:GetAttribute("Pickup")) then
            if State.ESP_Items then
                if not State.ESPCache[obj] then
                    ESP.CreateObjectESP(obj, "🎒 " .. obj.Name, State.Color_Item)
                end
            else
                ESP.Clear(obj)
            end
        end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons then
            if not State.ESPCache[w] then
                ESP.CreateObjectESP(w, "⚔ " .. w.Name, State.Color_Weapon)
            end
        else
            ESP.Clear(w)
        end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones then
            if not State.ESPCache[c] then
                ESP.CreateObjectESP(c, "👥 Clone", State.Color_Clone)
            end
        else
            ESP.Clear(c)
        end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers()
    ESP.ScanGenerators()
    ESP.ScanItems()
    ESP.ScanWeapons()
    ESP.ScanClones()
end

-- Periodic refresh loop
task.spawn(function()
    while task.wait(2) do
        pcall(ESP.RefreshAll)
    end
end)

RunService.Heartbeat:Connect(function()
    pcall(ESP.UpdateDistances)
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then ESP.Clear(plr.Character) end
end)

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterRemoving:Connect(function(char)
        ESP.Clear(char)
    end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterRemoving:Connect(function(char)
            ESP.Clear(char)
        end)
    end
end

--═══════════════════════════════════════════════════════════════
-- MOVEMENT
--═══════════════════════════════════════════════════════════════
local Movement = {}

function Movement.ApplyWalkSpeed()
    local h = Util.GetHumanoid()
    if h then h.WalkSpeed = tonumber(State.WalkSpeed) or 16 end
end

function Movement.ApplyJumpPower()
    local h = Util.GetHumanoid()
    if h then
        h.UseJumpPower = true
        h.JumpPower    = tonumber(State.JumpPower) or 50
    end
end

function Movement.SetNoClip(enabled)
    if State.NoClipConn then
        State.NoClipConn:Disconnect()
        State.NoClipConn = nil
    end
    if enabled then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    end
end

function Movement.SetInfJump(enabled)
    if State.InfJumpConn then
        State.InfJumpConn:Disconnect()
        State.InfJumpConn = nil
    end
    if enabled then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h = Util.GetHumanoid()
            if h then
                h:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

function Movement.TPNearestGenerator()
    if not WS.Generators then
        Util.Notify("Teleport", "No generators folder found.", 3)
        return
    end
    local hrp = Util.GetHRP()
    if not hrp then return end

    local nearest, minDist = nil, math.huge
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        local part = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < minDist then
                minDist   = d
                nearest   = part
            end
        end
    end

    if nearest then
        hrp.CFrame = nearest.CFrame + Vector3.new(0, 4, 0)
        Util.Notify("Teleport", "Sent to generator (" .. math.floor(minDist) .. "m)", 3)
    else
        Util.Notify("Teleport", "No generators found.", 3)
    end
end

function Movement.TPToPlayer(name)
    if type(name) ~= "string" or name == "" then
        Util.Notify("Teleport", "Enter a player name first.", 3)
        return
    end
    local target = Players:FindFirstChild(name)
    if not target or not target.Character then
        Util.Notify("Teleport", "Player not found: " .. name, 3)
        return
    end
    local hrp     = Util.GetHRP()
    local tHRP    = target.Character:FindFirstChild("HumanoidRootPart")
    if hrp and tHRP then
        hrp.CFrame = tHRP.CFrame + Vector3.new(0, 0, 3)
        Util.Notify("Teleport", "Sent to " .. name, 3)
    end
end

--═══════════════════════════════════════════════════════════════
-- MISC / VISUALS
--═══════════════════════════════════════════════════════════════
local Misc = {}

function Misc.BackupLighting()
    if next(State.LightingBackup) then return end
    State.LightingBackup = {
        Ambient                 = Lighting.Ambient,
        OutdoorAmbient          = Lighting.OutdoorAmbient,
        Brightness              = Lighting.Brightness,
        ClockTime               = Lighting.ClockTime,
        FogEnd                  = Lighting.FogEnd,
        FogStart                = Lighting.FogStart,
        FogColor                = Lighting.FogColor,
        GlobalShadows           = Lighting.GlobalShadows,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale= Lighting.EnvironmentSpecularScale,
    }
end

function Misc.RestoreLighting()
    for k, v in pairs(State.LightingBackup) do
        pcall(function() Lighting[k] = v end)
    end
end

function Misc.SetFullBright(enable)
    Misc.BackupLighting()
    if enable then
        Lighting.Ambient                  = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient           = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness               = 2
        Lighting.ClockTime                = 14
        Lighting.GlobalShadows            = false
        Lighting.EnvironmentDiffuseScale  = 1
        Lighting.EnvironmentSpecularScale = 1
    else
        Misc.RestoreLighting()
    end
end

function Misc.SetNoFog(enable)
    Misc.BackupLighting()
    if enable then
        Lighting.FogEnd   = 999999
        Lighting.FogStart = 999999
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then
                a.Density = 0
                a.Haze    = 0
            end
        end
    else
        Lighting.FogEnd   = State.LightingBackup.FogEnd   or 100000
        Lighting.FogStart = State.LightingBackup.FogStart or 0
    end
end

function Misc.SetNoShadows(enable)
    Misc.BackupLighting()
    Lighting.GlobalShadows = not enable
end

function Misc.SetClearWeather(enable)
    Misc.BackupLighting()
    if enable then
        for _, o in ipairs(Lighting:GetDescendants()) do
            if o:IsA("Atmosphere") then
                o.Density = 0
                o.Haze    = 0
            end
        end
    end
end

function Misc.SetLowGraphics(enable)
    pcall(function()
        settings().Rendering.QualityLevel =
            enable and Enum.QualityLevel.Level01
                    or Enum.QualityLevel.Automatic
    end)
end

function Misc.SetFOV(fov)
    if Camera then
        Camera.FieldOfView = tonumber(fov) or 70
    end
end

function Misc.SetTime(t)
    Lighting.ClockTime = tonumber(t) or 14
end

function Misc.RemovePostFX(remove)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect")
        or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect")
        or v:IsA("BloomEffect") then
            v.Enabled = not remove
        end
    end
    for _, v in ipairs(Camera:GetDescendants()) do
        if v:IsA("BlurEffect") then
            v.Enabled = not remove
        end
    end
end

function Misc.RemoveColorCorrection(remove)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then
            v.Enabled = not remove
        end
    end
end

function Misc.SetNoParticles(enable)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter")
        or v:IsA("Fire")
        or v:IsA("Smoke")
        or v:IsA("Sparkles")
        or v:IsA("Trail") then
            v.Enabled = not enable
        end
    end
end

function Misc.SetHideName(enable)
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        for _, g in ipairs(head:GetChildren()) do
            if g:IsA("BillboardGui") then
                g.Enabled = not enable
            end
        end
    end
end

function Misc.SetNoSound(enable)
    if enable then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and s.Playing then
                if not table.find(State.MutedSounds, s) then
                    s.Volume = 0
                    table.insert(State.MutedSounds, s)
                end
            end
        end
    else
        for _, s in ipairs(State.MutedSounds) do
            if s and s.Parent then
                pcall(function() s.Volume = 1 end)
            end
        end
        State.MutedSounds = {}
    end
end

function Misc.SetMuteBGMusic(enable)
    local bg = Workspace:FindFirstChild("BackgroundSounds")
    if not bg then return end
    for _, s in ipairs(bg:GetDescendants()) do
        if s:IsA("Sound") then
            s.Volume = enable and 0 or 1
        end
    end
end

function Misc.SetFreecam(enable)
    if State.FreecamConn then
        State.FreecamConn:Disconnect()
        State.FreecamConn = nil
    end

    if enable then
        local pos   = Camera.CFrame.Position
        local speed = 2
        Camera.CameraType = Enum.CameraType.Scriptable

        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look  = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local move  = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                move = move + look
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                move = move - look
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                move = move - right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                move = move + right
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                move = move + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                move = move - Vector3.new(0, 1, 0)
            end

            pos = pos + move * speed
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
        local hrp = Util.GetHRP()
        if hrp then Camera.CFrame = hrp.CFrame end
    end
end

function Misc.ServerHop()
    local ok, err = pcall(function()
        local TS   = game:GetService("TeleportService")
        local raw  = game:HttpGet(
            "https://games.roblox.com/v1/games/"
            .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"
        )
        local list = HttpService:JSONDecode(raw)
        if list and list.data then
            for _, s in ipairs(list.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(
                        tostring(game.PlaceId), s.id, LocalPlayer
                    )
                    return
                end
            end
        end
        Util.Notify("Server Hop", "No available server found.", 4)
    end)
    if not ok then
        Util.Notify("Server Hop", "Error: " .. tostring(err), 4)
    end
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS
--═══════════════════════════════════════════════════════════════
local Awareness = {}

function Awareness.Setup()
    -- Generator skill check
    if R.Generator.SkillCheck then
        Util.SafeConnect(R.Generator.SkillCheck.OnClientEvent, function(_, _, _, diff)
            if State.SkillCheckNotify then
                Util.Notify("Skill Check!", "Difficulty: " .. tostring(diff or "?"), 2)
            end
        end)
    end

    -- Generator skill check fail
    if R.Generator.SkillCheckFail then
        Util.SafeConnect(R.Generator.SkillCheckFail.OnClientEvent, function()
            if State.SkillCheckNotify then
                Util.Notify("Skill Check FAIL", "Generator progress lost!", 3)
            end
        end)
    end

    -- Heal skill check
    if R.Healing.SkillCheck then
        Util.SafeConnect(R.Healing.SkillCheck.OnClientEvent, function()
            if State.HealSkillNotify then
                Util.Notify("Heal Check!", "", 2)
            end
        end)
    end

    -- Generator done
    if R.Generator.GenDone then
        Util.SafeConnect(R.Generator.GenDone.OnClientEvent, function()
            if State.GenDoneNotify then
                Util.Notify("Generator Done!", "", 3)
            end
        end)
    end

    -- All generators done
    if R.Generator.AllGenDone then
        Util.SafeConnect(R.Generator.AllGenDone.OnClientEvent, function()
            if State.AllGensNotify then
                Util.Notify("All Generators Done!", "Find the exit!", 6)
            end
        end)
    end

    -- Chase music
    if R.Chase.Music then
        Util.SafeConnect(R.Chase.Music.OnClientEvent, function()
            if State.ChaseAlert then
                Util.Notify("⚠ CHASE!", "Killer is nearby!", 3)
            end
        end)
    end

    -- Lunge
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function()
            if State.AttackAlert then
                Util.Notify("⚠ LUNGE!", "Killer lunged!", 2)
            end
        end)
    end

    -- King Scourge
    if R.KillerPerks.KingScourge then
        local s = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if s then
            Util.SafeConnect(s.OnClientEvent, function()
                if State.AttackAlert then
                    Util.Notify("⚠ SCOURGE!", "King Scourge active!", 2)
                end
            end)
        end
    end

    -- Killer morph (role detection)
    if R.Game.KillerMorph then
        Util.SafeConnect(R.Game.KillerMorph.OnClientEvent, function()
            State.IsKiller = true
            Util.Notify("Role", "You are the KILLER", 5)
        end)
    end

    -- Match start
    if R.Game.Start then
        Util.SafeConnect(R.Game.Start.OnClientEvent, function()
            State.MatchActive = true
            State.IsKiller    = false
            Util.Notify("Match Started", "Good luck!", 3)
        end)
    end

    -- Round end
    if R.Game.RoundEnd then
        Util.SafeConnect(R.Game.RoundEnd.OnClientEvent, function()
            State.MatchActive = false
            ESP.ClearAll()
        end)
    end

    -- One survivor left
    if R.Game.OneLeft then
        Util.SafeConnect(R.Game.OneLeft.OnClientEvent, function()
            if State.OneLeftNotify then
                Util.Notify("Last Survivor!", "You are the last one!", 5)
            end
        end)
    end

    -- Death
    if R.Game.Death then
        Util.SafeConnect(R.Game.Death.OnClientEvent, function()
            if State.DeathNotify then
                Util.Notify("You Died", "", 3)
            end
        end)
    end

    -- Hook
    if R.Carry.HookEvent then
        Util.SafeConnect(R.Carry.HookEvent.OnClientEvent, function()
            if State.HookNotify then
                Util.Notify("Hooked!", "You are on the hook!", 3)
            end
        end)
    end

    -- Anti-AFK
    Util.SafeConnect(LocalPlayer.Idled, function()
        if State.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- AUTO REJOIN
--═══════════════════════════════════════════════════════════════
local function SetupAutoRejoin()
    LocalPlayer.OnTeleport:Connect(function(teleportState)
        if State.AutoRejoin and teleportState == Enum.TeleportState.Failed then
            task.wait(3)
            pcall(function()
                game:GetService("TeleportService"):Teleport(
                    tostring(game.PlaceId), LocalPlayer
                )
            end)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- BUILD UI
--═══════════════════════════════════════════════════════════════
local Window
local windowOk, windowErr = pcall(function()
    Window = WindUI:CreateWindow({
        Title        = HUB.Name,
        Icon         = "skull",
        Author       = "by " .. HUB.Author .. "  |  " .. HUB.Game,
        Folder       = HUB.Folder,
        Size         = UDim2.fromOffset(580, 480),
        Transparent  = true,
        Theme        = "Dark",
        SideBarWidth = 160,
        HasOutline   = true,
        KeySystem    = false,
    })
end)

if not windowOk or not Window then
    warn("[X0DEC04T] Window creation failed: " .. tostring(windowErr))
    return
end

print("[X0DEC04T] Window created successfully")

--═══════════════════════════════════════════════════════════════
-- TABS
--═══════════════════════════════════════════════════════════════
local Tabs = {}
local TabNames = {
    "Main",
    "Awareness",
    "ESP",
    "Movement",
    "Visuals",
    "Misc",
    "Settings",
}

for _, name in ipairs(TabNames) do
    local ok, tab = pcall(function()
        return Window:Tab({ Title = name })
    end)
    if ok and tab then
        Tabs[name] = tab
    else
        warn("[X0DEC04T] Tab '" .. name .. "' failed to create")
    end
end

-- Select first tab
Safe(function()
    if Window.SelectTab then Window:SelectTab(1) end
end, "SelectTab")

--═══════════════════════════════════════════════════════════════
-- MAIN TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Main then
    local mainTab = Tabs.Main

    Safe(function()
        mainTab:Section({ Title = "Welcome to " .. HUB.Name })
    end, "Main_WelcomeSec")

    Safe(function()
        mainTab:Paragraph({
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Premium script hub for " .. HUB.Game
                 .. "\nAuthor: " .. HUB.Author,
        })
    end, "Main_Info")

    Safe(function()
        mainTab:Paragraph({
            Title = "Modules",
            Desc  = "Awareness  •  ESP  •  Movement  •  Visuals  •  Misc",
        })
    end, "Main_Modules")

    -- Killer list
    local killerNames = {}
    for k in pairs(KNOWN_KILLERS) do
        table.insert(killerNames, k:gsub("^%l", string.upper))
    end
    Safe(function()
        mainTab:Paragraph({
            Title = "Detected Killers (" .. #killerNames .. ")",
            Desc  = #killerNames > 0
                and table.concat(killerNames, ", ")
                or  "None detected",
        })
    end, "Main_Killers")

    Safe(function()
        mainTab:Section({ Title = "Live Match Info" })
    end, "Main_MatchSec")

    local RoleLabel, MatchLabel

    Safe(function()
        RoleLabel = mainTab:Paragraph({
            Title = "Your Role",
            Desc  = "Waiting for match...",
        })
    end, "Main_RoleLabel")

    Safe(function()
        MatchLabel = mainTab:Paragraph({
            Title = "Match State",
            Desc  = "Waiting...",
        })
    end, "Main_MatchLabel")

    -- Update labels every second
    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                if RoleLabel and RoleLabel.SetDesc then
                    RoleLabel:SetDesc(
                        State.IsKiller and "🔪 KILLER" or "🏃 SURVIVOR"
                    )
                end
                if MatchLabel and MatchLabel.SetDesc then
                    MatchLabel:SetDesc(
                        State.MatchActive and "⚡ In Match" or "🕐 In Lobby"
                    )
                end
            end)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Awareness then
    local awTab = Tabs.Awareness

    Safe(function() awTab:Section({ Title = "Killer Alerts" }) end, "Aw_S1")

    Safe(function()
        awTab:Toggle({
            Title    = "Chase Music Alert",
            Desc     = "Notifies when chase music starts",
            Default  = true,
            Callback = function(v) State.ChaseAlert = v end,
        })
    end, "Aw_T1")

    Safe(function()
        awTab:Toggle({
            Title    = "Attack Alert",
            Desc     = "Notifies on Lunge or Scourge",
            Default  = true,
            Callback = function(v) State.AttackAlert = v end,
        })
    end, "Aw_T2")

    Safe(function() awTab:Section({ Title = "Skill Check Alerts" }) end, "Aw_S2")

    Safe(function()
        awTab:Toggle({
            Title    = "Generator Skill Check",
            Desc     = "Notifies on gen skill checks",
            Default  = true,
            Callback = function(v) State.SkillCheckNotify = v end,
        })
    end, "Aw_T3")

    Safe(function()
        awTab:Toggle({
            Title    = "Heal Skill Check",
            Desc     = "Notifies on healing skill checks",
            Default  = true,
            Callback = function(v) State.HealSkillNotify = v end,
        })
    end, "Aw_T4")

    Safe(function() awTab:Section({ Title = "Objective Alerts" }) end, "Aw_S3")

    Safe(function()
        awTab:Toggle({
            Title    = "Generator Done",
            Desc     = "Notifies when a gen is finished",
            Default  = true,
            Callback = function(v) State.GenDoneNotify = v end,
        })
    end, "Aw_T5")

    Safe(function()
        awTab:Toggle({
            Title    = "All Generators Done",
            Desc     = "Notifies when all gens complete",
            Default  = true,
            Callback = function(v) State.AllGensNotify = v end,
        })
    end, "Aw_T6")

    Safe(function()
        awTab:Toggle({
            Title    = "Hook Notify",
            Desc     = "Notifies when you are hooked",
            Default  = true,
            Callback = function(v) State.HookNotify = v end,
        })
    end, "Aw_T7")

    Safe(function()
        awTab:Toggle({
            Title    = "Death Notify",
            Desc     = "Notifies on death",
            Default  = true,
            Callback = function(v) State.DeathNotify = v end,
        })
    end, "Aw_T8")

    Safe(function()
        awTab:Toggle({
            Title    = "Last Survivor Notify",
            Desc     = "Notifies when you are the last survivor",
            Default  = true,
            Callback = function(v) State.OneLeftNotify = v end,
        })
    end, "Aw_T9")
end

--═══════════════════════════════════════════════════════════════
-- ESP TAB
--═══════════════════════════════════════════════════════════════
if Tabs.ESP then
    local espTab = Tabs.ESP

    Safe(function() espTab:Section({ Title = "Player ESP" }) end, "ESP_S1")

    Safe(function()
        espTab:Toggle({
            Title    = "Killer ESP",
            Desc     = "Highlights killer in red",
            Default  = false,
            Callback = function(v)
                State.ESP_Killer = v
                if not v then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and Role.IsKiller(p.Character) then
                            ESP.Clear(p.Character)
                        end
                    end
                end
            end,
        })
    end, "ESP_T1")

    Safe(function()
        espTab:Toggle({
            Title    = "Survivor ESP",
            Desc     = "Highlights survivors in cyan",
            Default  = false,
            Callback = function(v)
                State.ESP_Survivors = v
                if not v then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character
                        and not Role.IsFakeCharacter(p.Character)
                        and not Role.IsKiller(p.Character) then
                            ESP.Clear(p.Character)
                        end
                    end
                end
            end,
        })
    end, "ESP_T2")

    Safe(function() espTab:Section({ Title = "Object ESP" }) end, "ESP_S2")

    Safe(function()
        espTab:Toggle({
            Title    = "Generator ESP",
            Desc     = "Highlights generators in yellow",
            Default  = false,
            Callback = function(v)
                State.ESP_Generators = v
                if not v and WS.Generators then
                    for _, g in ipairs(WS.Generators:GetChildren()) do
                        ESP.Clear(g)
                    end
                end
            end,
        })
    end, "ESP_T3")

    Safe(function()
        espTab:Toggle({
            Title    = "Item ESP",
            Desc     = "Highlights items in green",
            Default  = false,
            Callback = function(v)
                State.ESP_Items = v
            end,
        })
    end, "ESP_T4")

    Safe(function()
        espTab:Toggle({
            Title    = "Weapon ESP",
            Desc     = "Highlights weapons in pink",
            Default  = false,
            Callback = function(v)
                State.ESP_Weapons = v
                if not v and WS.Weapons then
                    for _, w in ipairs(WS.Weapons:GetChildren()) do
                        ESP.Clear(w)
                    end
                end
            end,
        })
    end, "ESP_T5")

    Safe(function()
        espTab:Toggle({
            Title    = "Clone ESP",
            Desc     = "Highlights clones in gray",
            Default  = false,
            Callback = function(v)
                State.ESP_Clones = v
                if not v and WS.Clones then
                    for _, c in ipairs(WS.Clones:GetChildren()) do
                        ESP.Clear(c)
                    end
                end
            end,
        })
    end, "ESP_T6")

    Safe(function() espTab:Section({ Title = "Display Options" }) end, "ESP_S3")

    Safe(function()
        espTab:Toggle({
            Title    = "Show Name",
            Desc     = "Shows name label on ESP",
            Default  = true,
            Callback = function(v)
                State.ESP_ShowName = v
                for _, cache in pairs(State.ESPCache) do
                    if cache.nameLabel then
                        cache.nameLabel.Visible = v
                    end
                end
            end,
        })
    end, "ESP_T7")

    Safe(function()
        espTab:Toggle({
            Title    = "Show Distance",
            Desc     = "Shows distance in meters",
            Default  = true,
            Callback = function(v)
                State.ESP_ShowDistance = v
                for _, cache in pairs(State.ESPCache) do
                    if cache.distLabel then
                        cache.distLabel.Visible = v
                    end
                end
            end,
        })
    end, "ESP_T8")

    Safe(function()
        espTab:Slider({
            Title    = "Max Render Distance",
            Desc     = "Maximum distance ESP is visible",
            Value    = { Min = 50, Max = 2000, Default = 500 },
            Step     = 50,
            Callback = function(v)
                local n = tonumber(v) or 500
                State.ESP_MaxDistance = n
                for _, cache in pairs(State.ESPCache) do
                    if cache.billboard then
                        cache.billboard.MaxDistance = n
                    end
                end
            end,
        })
    end, "ESP_Slider")

    Safe(function() espTab:Section({ Title = "Actions" }) end, "ESP_S4")

    Safe(function()
        espTab:Button({
            Title    = "Refresh ESP",
            Desc     = "Force re-scan all entities",
            Callback = function()
                ESP.ClearAll()
                ESP.RefreshAll()
                Util.Notify("ESP", "Refreshed!", 2)
            end,
        })
    end, "ESP_B1")

    Safe(function()
        espTab:Button({
            Title    = "Clear All ESP",
            Desc     = "Remove all ESP highlights",
            Callback = function()
                ESP.ClearAll()
                Util.Notify("ESP", "All cleared.", 2)
            end,
        })
    end, "ESP_B2")
end

--═══════════════════════════════════════════════════════════════
-- MOVEMENT TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Movement then
    local mvTab = Tabs.Movement

    Safe(function() mvTab:Section({ Title = "Speed Settings" }) end, "Mv_S1")

    Safe(function()
        mvTab:Slider({
            Title    = "Walk Speed",
            Desc     = "Default: 16",
            Value    = { Min = 16, Max = 200, Default = 16 },
            Step     = 1,
            Callback = function(v)
                State.WalkSpeed = tonumber(v) or 16
                Movement.ApplyWalkSpeed()
            end,
        })
    end, "Mv_Slider1")

    Safe(function()
        mvTab:Slider({
            Title    = "Jump Power",
            Desc     = "Default: 50",
            Value    = { Min = 50, Max = 300, Default = 50 },
            Step     = 5,
            Callback = function(v)
                State.JumpPower = tonumber(v) or 50
                Movement.ApplyJumpPower()
            end,
        })
    end, "Mv_Slider2")

    Safe(function() mvTab:Section({ Title = "Advanced Movement" }) end, "Mv_S2")

    Safe(function()
        mvTab:Toggle({
            Title    = "NoClip",
            Desc     = "Walk through walls",
            Default  = false,
            Callback = function(v)
                State.NoClip = v
                Movement.SetNoClip(v)
            end,
        })
    end, "Mv_T1")

    Safe(function()
        mvTab:Toggle({
            Title    = "Infinite Jump",
            Desc     = "Jump while in the air",
            Default  = false,
            Callback = function(v)
                State.InfJump = v
                Movement.SetInfJump(v)
            end,
        })
    end, "Mv_T2")

    Safe(function() mvTab:Section({ Title = "Teleport" }) end, "Mv_S3")

    Safe(function()
        mvTab:Button({
            Title    = "TP to Nearest Generator",
            Desc     = "Teleports you to the closest generator",
            Callback = Movement.TPNearestGenerator,
        })
    end, "Mv_B1")

    local teleportTargetName = ""

    Safe(function()
        mvTab:Input({
            Title       = "Target Player Name",
            Desc        = "Case-sensitive player name",
            Value       = "",
            Placeholder = "PlayerName",
            Callback    = function(v)
                teleportTargetName = tostring(v or "")
            end,
        })
    end, "Mv_Input")

    Safe(function()
        mvTab:Button({
            Title    = "TP to Target Player",
            Desc     = "Teleports to the entered player",
            Callback = function()
                if teleportTargetName ~= "" then
                    Movement.TPToPlayer(teleportTargetName)
                else
                    Util.Notify("Teleport", "Enter a player name first.", 3)
                end
            end,
        })
    end, "Mv_B2")
end

--═══════════════════════════════════════════════════════════════
-- VISUALS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Visuals then
    local visTab = Tabs.Visuals

    Safe(function() visTab:Section({ Title = "Lighting" }) end, "Vis_S1")

    Safe(function()
        visTab:Toggle({
            Title    = "FullBright",
            Desc     = "Removes all darkness",
            Default  = false,
            Callback = function(v)
                State.FullBright = v
                Misc.SetFullBright(v)
            end,
        })
    end, "Vis_T1")

    Safe(function()
        visTab:Toggle({
            Title    = "No Fog",
            Desc     = "Removes map fog",
            Default  = false,
            Callback = function(v)
                State.NoFog = v
                Misc.SetNoFog(v)
            end,
        })
    end, "Vis_T2")

    Safe(function()
        visTab:Toggle({
            Title    = "No Shadows",
            Desc     = "Disables global shadows",
            Default  = false,
            Callback = function(v)
                State.NoShadows = v
                Misc.SetNoShadows(v)
            end,
        })
    end, "Vis_T3")

    Safe(function()
        visTab:Toggle({
            Title    = "Clear Weather",
            Desc     = "Removes atmospheric effects",
            Default  = false,
            Callback = function(v)
                State.ClearWeather = v
                Misc.SetClearWeather(v)
            end,
        })
    end, "Vis_T4")

    Safe(function()
        visTab:Slider({
            Title    = "Time of Day",
            Desc     = "0 = Midnight, 14 = Day, 24 = Midnight",
            Value    = { Min = 0, Max = 24, Default = 14 },
            Step     = 1,
            Callback = function(v)
                State.Time = tonumber(v) or 14
                Misc.SetTime(State.Time)
            end,
        })
    end, "Vis_Slider1")

    Safe(function() visTab:Section({ Title = "Camera" }) end, "Vis_S2")

    Safe(function()
        visTab:Slider({
            Title    = "Field of View",
            Desc     = "Default: 70",
            Value    = { Min = 30, Max = 120, Default = 70 },
            Step     = 5,
            Callback = function(v)
                State.FOV = tonumber(v) or 70
                Misc.SetFOV(State.FOV)
            end,
        })
    end, "Vis_Slider2")

    Safe(function()
        visTab:Toggle({
            Title    = "Freecam",
            Desc     = "Free camera  (WASD / Space / Ctrl)",
            Default  = false,
            Callback = function(v)
                State.Freecam = v
                Misc.SetFreecam(v)
            end,
        })
    end, "Vis_T5")

    Safe(function() visTab:Section({ Title = "Post-Processing" }) end, "Vis_S3")

    Safe(function()
        visTab:Toggle({
            Title    = "Remove Blur / Bloom",
            Desc     = "Disables blur and bloom effects",
            Default  = false,
            Callback = function(v)
                State.RemoveBlur = v
                Misc.RemovePostFX(v)
            end,
        })
    end, "Vis_T6")

    Safe(function()
        visTab:Toggle({
            Title    = "Remove Color Correction",
            Desc     = "Disables color grading effects",
            Default  = false,
            Callback = function(v)
                State.RemoveColorCorr = v
                Misc.RemoveColorCorrection(v)
            end,
        })
    end, "Vis_T7")

    Safe(function()
        visTab:Toggle({
            Title    = "No Particles",
            Desc     = "Removes particles, fire, smoke, etc.",
            Default  = false,
            Callback = function(v)
                State.NoParticles = v
                Misc.SetNoParticles(v)
            end,
        })
    end, "Vis_T8")

    Safe(function() visTab:Section({ Title = "Performance" }) end, "Vis_S4")

    Safe(function()
        visTab:Toggle({
            Title    = "Low Graphics",
            Desc     = "Sets quality to Level 1",
            Default  = false,
            Callback = function(v)
                State.LowGraphics = v
                Misc.SetLowGraphics(v)
            end,
        })
    end, "Vis_T9")
end

--═══════════════════════════════════════════════════════════════
-- MISC TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Misc then
    local miscTab = Tabs.Misc

    Safe(function() miscTab:Section({ Title = "Audio" }) end, "Misc_S1")

    Safe(function()
        miscTab:Toggle({
            Title    = "Mute All Sounds",
            Desc     = "Silences all game sounds",
            Default  = false,
            Callback = function(v)
                State.NoSound = v
                Misc.SetNoSound(v)
            end,
        })
    end, "Misc_T1")

    Safe(function()
        miscTab:Toggle({
            Title    = "Mute Background Music",
            Desc     = "Silences background music only",
            Default  = false,
            Callback = function(v)
                State.MuteBGMusic = v
                Misc.SetMuteBGMusic(v)
            end,
        })
    end, "Misc_T2")

    Safe(function() miscTab:Section({ Title = "Character" }) end, "Misc_S2")

    Safe(function()
        miscTab:Toggle({
            Title    = "Hide Own Name",
            Desc     = "Hides your name/tag above head",
            Default  = false,
            Callback = function(v)
                State.HideName = v
                Misc.SetHideName(v)
            end,
        })
    end, "Misc_T3")

    Safe(function() miscTab:Section({ Title = "Utility" }) end, "Misc_S3")

    Safe(function()
        miscTab:Toggle({
            Title    = "Auto Rejoin on Kick",
            Desc     = "Auto-rejoins if teleport fails",
            Default  = false,
            Callback = function(v)
                State.AutoRejoin = v
            end,
        })
    end, "Misc_T4")

    Safe(function()
        miscTab:Button({
            Title    = "Server Hop",
            Desc     = "Joins a different server",
            Callback = Misc.ServerHop,
        })
    end, "Misc_B1")

    Safe(function()
        miscTab:Button({
            Title    = "Copy JobId",
            Desc     = "Copies current server JobId",
            Callback = function()
                if setclipboard then
                    setclipboard(tostring(game.JobId))
                    Util.Notify("Copied", "JobId copied to clipboard.", 3)
                else
                    Util.Notify("Error", "Clipboard not supported on this executor.", 3)
                end
            end,
        })
    end, "Misc_B2")

    Safe(function()
        miscTab:Button({
            Title    = "Rejoin Server",
            Desc     = "Teleports back to this game",
            Callback = function()
                pcall(function()
                    game:GetService("TeleportService"):Teleport(
                        game.PlaceId, LocalPlayer
                    )
                end)
            end,
        })
    end, "Misc_B3")
end

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
--═══════════════════════════════════════════════════════════════
if Tabs.Settings then
    local setTab = Tabs.Settings

    Safe(function() setTab:Section({ Title = "Anti-AFK" }) end, "Set_S1")

    Safe(function()
        setTab:Toggle({
            Title    = "Anti-AFK",
            Desc     = "Prevents idle kick",
            Default  = true,
            Callback = function(v)
                State.AntiAFK = v
            end,
        })
    end, "Set_T1")

    Safe(function() setTab:Section({ Title = "UI Theme" }) end, "Set_S2")

    Safe(function()
        setTab:Dropdown({
            Title    = "Theme",
            Desc     = "UI color theme",
            Values   = { "Dark", "Light" },
            Value    = "Dark",
            Callback = function(v)
                local theme = type(v) == "table" and v[1] or tostring(v)
                pcall(function() WindUI:SetTheme(theme) end)
            end,
        })
    end, "Set_Dropdown")

    Safe(function() setTab:Section({ Title = "Keybinds" }) end, "Set_S3")

    Safe(function()
        setTab:Keybind({
            Title    = "Toggle UI Visibility",
            Desc     = "Show/hide the hub window",
            Value    = "RightShift",
            Callback = function()
                pcall(function() Window:Toggle() end)
            end,
        })
    end, "Set_KB1")

    Safe(function()
        setTab:Keybind({
            Title    = "Panic  —  Clear All ESP",
            Desc     = "Instantly disables all ESP",
            Value    = "End",
            Callback = function()
                State.ESP_Killer      = false
                State.ESP_Survivors   = false
                State.ESP_Generators  = false
                State.ESP_Items       = false
                State.ESP_Weapons     = false
                State.ESP_Clones      = false
                ESP.ClearAll()
                Util.Notify("Panic", "All ESP disabled!", 3)
            end,
        })
    end, "Set_KB2")

    Safe(function() setTab:Section({ Title = "Credits" }) end, "Set_S4")

    Safe(function()
        setTab:Paragraph({
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Made by " .. HUB.Author
                 .. "\nGame: " .. HUB.Game
                 .. "\nCompatible: Xeno, Medium, Delta, Solara, Wave",
        })
    end, "Set_Credits")

    Safe(function() setTab:Section({ Title = "Danger Zone" }) end, "Set_S5")

    Safe(function()
        setTab:Button({
            Title    = "Unload Hub",
            Desc     = "Removes hub and restores settings",
            Callback = function()
                -- Disconnect all connections
                for _, conn in ipairs(State.Connections) do
                    pcall(function() conn:Disconnect() end)
                end
                if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
                if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
                if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end

                -- Restore lighting
                Misc.RestoreLighting()

                -- Restore camera
                pcall(function()
                    Camera.CameraType  = Enum.CameraType.Custom
                    Camera.FieldOfView = 70
                end)

                -- Clear ESP
                ESP.ClearAll()

                -- Destroy window
                pcall(function() Window:Destroy() end)

                Util.Notify("Unloaded", HUB.Name .. " has been removed.", 4)
                print("[X0DEC04T] Hub unloaded.")
            end,
        })
    end, "Set_Unload")
end

--═══════════════════════════════════════════════════════════════
-- INITIALIZE
--═══════════════════════════════════════════════════════════════
print("[X0DEC04T] Setting up Awareness...")
Awareness.Setup()

print("[X0DEC04T] Setting up Auto-Rejoin...")
SetupAutoRejoin()

-- Re-apply movement settings on respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    pcall(Movement.ApplyWalkSpeed)
    pcall(Movement.ApplyJumpPower)
    if State.NoClip   then Movement.SetNoClip(true)  end
    if State.InfJump  then Movement.SetInfJump(true)  end
    if State.FullBright then Misc.SetFullBright(true) end
    if State.NoFog    then Misc.SetNoFog(true)        end
    if State.HideName then Misc.SetHideName(true)     end
    if State.FOV ~= 70 then Misc.SetFOV(State.FOV)   end
end)

-- Periodic lighting enforcement (game sometimes resets it)
task.spawn(function()
    while task.wait(5) do
        if State.FullBright   then pcall(Misc.SetFullBright,   true) end
        if State.NoFog        then pcall(Misc.SetNoFog,        true) end
        if State.NoShadows    then pcall(Misc.SetNoShadows,    true) end
        if State.ClearWeather then pcall(Misc.SetClearWeather, true) end
    end
end)

-- Done
Util.Notify(HUB.Name, "Loaded successfully  •  v" .. HUB.Version, 5)
print("[X0DEC04T] ✓ Fully loaded — v" .. HUB.Version)
