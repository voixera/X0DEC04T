--═══════════════════════════════════════════════════════════════
-- SERVICES
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
local SoundService      = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--═══════════════════════════════════════════════════════════════
-- WINDUI LOAD (SAFE)
--═══════════════════════════════════════════════════════════════
local function SafeLoadWindUI()
    local rawSuccess, raw = pcall(function()
        return game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
    end)

    if not rawSuccess or type(raw) ~= "string" or #raw < 100 then
        warn("[X0DEC04T] Failed to fetch WindUI source (HttpGet issue or empty response)")
        return nil
    end

    local compileSuccess, chunk = pcall(loadstring, raw)
    if not compileSuccess or type(chunk) ~= "function" then
        warn("[X0DEC04T] WindUI source failed to compile: " .. tostring(chunk))
        return nil
    end

    local runSuccess, result = pcall(chunk)
    if not runSuccess then
        warn("[X0DEC04T] WindUI errored on execution: " .. tostring(result))
        return nil
    end

    return result
end

local WindUI = SafeLoadWindUI()

if not WindUI then
    warn("[X0DEC04T] CRITICAL: WindUI failed to load. Aborting script.")
    return
end

print("[X0DEC04T] WindUI loaded successfully")

--═══════════════════════════════════════════════════════════════
-- HUB CONFIGURATION
--═══════════════════════════════════════════════════════════════
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.6",
    Author  = "voixera",
    Folder  = "X0DEC04T_Hub",
    LogoID  = "rbxassetid://132469099334813",
}

pcall(function()
    game:GetService("ContentProvider"):PreloadAsync({HUB.LogoID})
end)

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
-- REMOTE REFERENCES
--═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local R = {
    Generator = {
        SkillCheck     = Remotes.Generator:FindFirstChild("SkillCheckEvent"),
        SkillCheckFail = Remotes.Generator:FindFirstChild("SkillCheckFailEvent"),
        GenDone        = Remotes.Generator:FindFirstChild("GenDone"),
        AllGenDone     = Remotes.Generator:FindFirstChild("allgendone"),
        EscapeTime     = Remotes.Generator:FindFirstChild("Escapetime"),
    },
    Healing = {
        SkillCheck = Remotes.Healing:FindFirstChild("SkillCheckEvent"),
    },
    Chase = {
        Music = Remotes.Chase:FindFirstChild("ChaseMusicEvent"),
    },
    Attacks = {
        Lunge       = Remotes.Attacks:FindFirstChild("Lunge"),
        BasicAttack = Remotes.Attacks:FindFirstChild("BasicAttack"),
    },
    KillerPerks = {
        KingScourge = Remotes.KillerPerks:FindFirstChild("kingscourge"),
    },
    Game = {
        Start       = Remotes.Game:FindFirstChild("Start"),
        RoundEnd    = Remotes.Game:FindFirstChild("RoundEnd"),
        KillerMorph = Remotes.Game:FindFirstChild("KillerMorph"),
        OneLeft     = Remotes.Game:FindFirstChild("Oneleft"),
        Death       = Remotes.Game:FindFirstChild("death"),
    },
    Carry = {
        HookEvent   = Remotes.Carry:FindFirstChild("HookEvent"),
        UnhookEvent = Remotes.Carry:FindFirstChild("UnHookEvent"),
        HookPhase   = Remotes.Carry:FindFirstChild("HookPhase"),
    },
}

--═══════════════════════════════════════════════════════════════
-- WORKSPACE REFERENCES
--═══════════════════════════════════════════════════════════════
local WS = {
    Map        = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Mazes      = Workspace:FindFirstChild("Mazes"),
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then
    WS.Generators = WS.Map:FindFirstChild("Generators")
end

--═══════════════════════════════════════════════════════════════
-- STATE
--═══════════════════════════════════════════════════════════════
local State = {
    ChaseAlert         = true,
    AttackAlert        = true,
    SkillCheckNotify   = true,
    HealSkillNotify    = true,
    GenDoneNotify      = true,
    AllGensNotify      = true,
    OneLeftNotify      = true,
    HookNotify         = true,
    DeathNotify        = true,

    ESP_Generators     = false,
    ESP_Killer         = false,
    ESP_Survivors      = false,
    ESP_Items          = false,
    ESP_Weapons        = false,
    ESP_Clones         = false,
    ESP_MaxDistance    = 500,
    ESP_ShowDistance   = true,
    ESP_ShowName       = true,

    Color_Killer       = Color3.fromRGB(255, 40, 40),
    Color_Survivor     = Color3.fromRGB(60, 220, 255),
    Color_Generator    = Color3.fromRGB(255, 200, 60),
    Color_Item         = Color3.fromRGB(120, 255, 120),
    Color_Weapon       = Color3.fromRGB(255, 120, 220),
    Color_Clone        = Color3.fromRGB(180, 180, 180),

    WalkSpeed          = 16,
    JumpPower          = 50,
    NoClip             = false,
    InfJump            = false,

    FullBright         = false,
    NoFog              = false,
    NoShadows          = false,
    ClearWeather       = false,
    LowGraphics        = false,
    FOV                = 70,
    Time               = 14,
    RemoveBlur         = false,
    RemoveColorCorr    = false,
    Freecam            = false,
    HideName           = false,
    NoSound            = false,
    MuteBGMusic        = false,
    NoParticles        = false,
    AutoRejoin         = false,

    AntiAFK            = true,

    IsKiller           = false,
    MatchActive        = false,
    ESPCache           = {},
    Connections        = {},
    NoClipConn         = nil,
    InfJumpConn        = nil,
    FreecamConn        = nil,
    LightingBackup     = {},
    MutedSounds        = {},
}

--═══════════════════════════════════════════════════════════════
-- UTILITY
--═══════════════════════════════════════════════════════════════
local Util = {}

function Util.SafeConnect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then
        table.insert(State.Connections, conn)
        return conn
    end
    return nil
end

function Util.GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Util.GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

function Util.GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

function Util.Notify(title, content, duration)
    local success, err = pcall(function()
        WindUI:Notify({
            Title    = title or HUB.Name,
            Content  = content or "",
            Duration = duration or 4,
            Icon     = "bell",
        })
    end)
    if not success then
        warn("[X0DEC04T] Notify failed:", err)
    end
end

function Util.GetGuiParent()
    local parent = CoreGui
    pcall(function() if gethui then parent = gethui() end end)
    return parent
end

function Util.CleanupESP()
    for adornee, _ in pairs(State.ESPCache) do
        for _, obj in pairs(State.ESPCache[adornee]) do
            if typeof(obj) == "Instance" and obj.Parent then
                obj:Destroy()
            end
        end
        State.ESPCache[adornee] = nil
    end
end

--═══════════════════════════════════════════════════════════════
-- ROLE DETECTION
--═══════════════════════════════════════════════════════════════
local Role = {}

function Role.IsKiller(character)
    if not character then return false end
    if character:GetAttribute("Killer") == true
    or character:GetAttribute("IsKiller") == true
    or character:GetAttribute("Role") == "Killer" then
        return true
    end
    local charName = character.Name:lower()
    for killerName, _ in pairs(KNOWN_KILLERS) do
        if charName:find(killerName, 1, true) then return true end
    end
    return false
end

function Role.GetKillerName(character)
    if not character then return "Unknown" end
    local charName = character.Name:lower()
    for killerName, _ in pairs(KNOWN_KILLERS) do
        if charName:find(killerName, 1, true) then
            return killerName:gsub("^%l", string.upper)
        end
    end
    return "Killer"
end

function Role.IsFakeCharacter(character)
    if not character then return true end
    if WS.FakeChars and character:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones and character:IsDescendantOf(WS.Clones) then return true end
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
                obj:Destroy()
            end
        end
        State.ESPCache[adornee] = nil
    end
end

function ESP.ClearAll()
    for adornee, _ in pairs(State.ESPCache) do
        ESP.Clear(adornee)
    end
    State.ESPCache = {}
end

function ESP.CreateCharacterESP(character, label, color)
    if State.ESPCache[character] then ESP.Clear(character) end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
              or character:FindFirstChild("Torso")
              or character:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local highlight = Instance.new("Highlight")
    highlight.Name                = "X0DEC_Highlight"
    highlight.Adornee             = character
    highlight.FillColor           = color
    highlight.OutlineColor        = Color3.new(1, 1, 1)
    highlight.FillTransparency    = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent              = Util.GetGuiParent()

    local bb = Instance.new("BillboardGui")
    bb.Name           = "X0DEC_Info"
    bb.Adornee        = hrp
    bb.Size           = UDim2.new(0, 200, 0, 45)
    bb.StudsOffset    = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = math.max(50, State.ESP_MaxDistance)
    bb.Parent         = Util.GetGuiParent()

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name                   = "NameLabel"
    nameLabel.Size                   = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = tostring(label)
    nameLabel.TextColor3             = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 14
    nameLabel.Visible                = State.ESP_ShowName == true
    nameLabel.Parent                 = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name                   = "DistanceLabel"
    distLabel.Size                   = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position               = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text                   = "0m"
    distLabel.TextColor3             = Color3.fromRGB(230, 230, 230)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font                   = Enum.Font.Gotham
    distLabel.TextSize               = 12
    distLabel.Visible                = State.ESP_ShowDistance == true
    distLabel.Parent                 = bb

    State.ESPCache[character] = {
        highlight = highlight,
        billboard = bb,
        nameLabel = nameLabel,
        distLabel = distLabel,
        hrp = hrp,
    }
end

function ESP.CreateObjectESP(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end

    local part = model
    if model:IsA("Model") then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end

    local highlight = Instance.new("Highlight")
    highlight.Name                = "X0DEC_Highlight"
    highlight.Adornee             = model
    highlight.FillColor           = color
    highlight.OutlineColor        = color
    highlight.FillTransparency    = 0.7
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent              = Util.GetGuiParent()

    local bb = Instance.new("BillboardGui")
    bb.Name           = "X0DEC_Info"
    bb.Adornee        = part
    bb.Size           = UDim2.new(0, 180, 0, 45)
    bb.StudsOffset    = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = math.max(50, State.ESP_MaxDistance)
    bb.Parent         = Util.GetGuiParent()

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name                   = "NameLabel"
    nameLabel.Size                   = UDim2.new(1, 0, 0.6, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text                   = tostring(label)
    nameLabel.TextColor3             = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3       = Color3.new(0, 0, 0)
    nameLabel.Font                   = Enum.Font.GothamBold
    nameLabel.TextSize               = 13
    nameLabel.Visible                = State.ESP_ShowName == true
    nameLabel.Parent                 = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name                   = "DistanceLabel"
    distLabel.Size                   = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position               = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text                   = "0m"
    distLabel.TextColor3             = Color3.fromRGB(220, 220, 220)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font                   = Enum.Font.Gotham
    distLabel.TextSize               = 11
    distLabel.Visible                = State.ESP_ShowDistance == true
    distLabel.Parent                 = bb

    State.ESPCache[model] = {
        highlight = highlight,
        billboard = bb,
        nameLabel = nameLabel,
        distLabel = distLabel,
        hrp = part,
    }
end

function ESP.UpdateDistances()
    local hrp = Util.GetHRP()
    if not hrp then return end
    for adornee, cache in pairs(State.ESPCache) do
        if cache.distLabel and cache.hrp and cache.hrp.Parent then
            local dist = (cache.hrp.Position - hrp.Position).Magnitude
            cache.distLabel.Text = tostring(math.floor(dist)) .. "m"
        end
    end
end

function ESP.Validate()
    for adornee, _ in pairs(State.ESPCache) do
        if not adornee or not adornee.Parent then
            ESP.Clear(adornee)
        end
    end
end

function ESP.ScanPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and not Role.IsFakeCharacter(char) then
                local isKiller = Role.IsKiller(char)
                
                if isKiller and State.ESP_Killer and not State.ESPCache[char] then
                    local killerName = Role.GetKillerName(char)
                    ESP.CreateCharacterESP(char, "☠ " .. killerName .. " [" .. plr.Name .. "]", State.Color_Killer)
                elseif not isKiller and State.ESP_Survivors and not State.ESPCache[char] then
                    ESP.CreateCharacterESP(char, "◈ " .. plr.Name, State.Color_Survivor)
                elseif isKiller and not State.ESP_Killer then
                    ESP.Clear(char)
                elseif not isKiller and not State.ESP_Survivors then
                    ESP.Clear(char)
                end
            end
        end
    end
end

function ESP.ScanGenerators()
    if not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators and not State.ESPCache[gen] then
            ESP.CreateObjectESP(gen, "⚡ " .. gen.Name, State.Color_Generator)
        elseif not State.ESP_Generators then
            ESP.Clear(gen)
        end
    end
end

function ESP.ScanItems()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj:GetAttribute("Item") or obj:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[obj] then
                ESP.CreateObjectESP(obj, "🎒 " .. obj.Name, State.Color_Item)
            elseif not State.ESP_Items then
                ESP.Clear(obj)
            end
        end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.CreateObjectESP(w, "⚔ " .. w.Name, State.Color_Weapon)
        elseif not State.ESP_Weapons then
            ESP.Clear(w)
        end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones and not State.ESPCache[c] then
            ESP.CreateObjectESP(c, "👥 Clone", State.Color_Clone)
        elseif not State.ESP_Clones then
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
    plr.CharacterRemoving:Connect(function(char) ESP.Clear(char) end)
end)

for _, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        plr.CharacterRemoving:Connect(function(char) ESP.Clear(char) end)
    end
end

--═══════════════════════════════════════════════════════════════
-- MOVEMENT
--═══════════════════════════════════════════════════════════════
local Movement = {}

function Movement.ApplyWalkSpeed()
    local hum = Util.GetHumanoid()
    if hum then hum.WalkSpeed = tonumber(State.WalkSpeed) or 16 end
end

function Movement.ApplyJumpPower()
    local hum = Util.GetHumanoid()
    if hum then 
        hum.JumpPower = tonumber(State.JumpPower) or 50
        hum.UseJumpPower = true
    end
end

function Movement.SetNoClip(enabled)
    if State.NoClipConn then 
        State.NoClipConn:Disconnect() 
        State.NoClipConn = nil 
    end
    if enabled then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
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
            local hum = Util.GetHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

function Movement.TeleportToNearestGenerator()
    if not WS.Generators then 
        Util.Notify("Teleport", "Generators folder not found", 3)
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
                minDist = d 
                nearest = part 
            end
        end
    end
    
    if nearest then
        hrp.CFrame = nearest.CFrame + Vector3.new(0, 3, 0)
        Util.Notify("Teleport", "Sent to nearest generator (" .. tostring(math.floor(minDist)) .. "m)", 3)
    else
        Util.Notify("Teleport", "No generators found", 3)
    end
end

function Movement.TeleportToPlayer(playerName)
    if type(playerName) ~= "string" or playerName == "" then
        Util.Notify("Teleport", "Invalid player name", 3)
        return
    end
    
    local target = Players:FindFirstChild(playerName)
    if not target or not target.Character then 
        Util.Notify("Teleport", "Player not found: " .. tostring(playerName), 3)
        return 
    end
    
    local hrp = Util.GetHRP()
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    
    if hrp and targetHRP then
        hrp.CFrame = targetHRP.CFrame + Vector3.new(0, 0, 3)
        Util.Notify("Teleport", "Sent to " .. tostring(playerName), 3)
    else
        Util.Notify("Teleport", "Target has no HumanoidRootPart", 3)
    end
end

--═══════════════════════════════════════════════════════════════
-- MISCELLANEOUS / VISUALS
--═══════════════════════════════════════════════════════════════
local Misc = {}

function Misc.BackupLighting()
    if next(State.LightingBackup) then return end
    State.LightingBackup = {
        Ambient              = Lighting.Ambient,
        OutdoorAmbient       = Lighting.OutdoorAmbient,
        Brightness           = Lighting.Brightness,
        ClockTime            = Lighting.ClockTime,
        FogEnd               = Lighting.FogEnd,
        FogStart             = Lighting.FogStart,
        FogColor             = Lighting.FogColor,
        GlobalShadows        = Lighting.GlobalShadows,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

function Misc.SetFullBright(enabled)
    Misc.BackupLighting()
    if enabled then
        Lighting.Ambient                  = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient           = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness               = 2
        Lighting.ClockTime                = 14
        Lighting.GlobalShadows            = false
        Lighting.EnvironmentDiffuseScale  = 1
        Lighting.EnvironmentSpecularScale = 1
    else
        for k, v in pairs(State.LightingBackup) do 
            pcall(function() Lighting[k] = v end) 
        end
    end
end

function Misc.SetNoFog(enabled)
    Misc.BackupLighting()
    if enabled then
        Lighting.FogEnd   = 999999
        Lighting.FogStart = 999999
        for _, atm in ipairs(Lighting:GetChildren()) do
            if atm:IsA("Atmosphere") then 
                atm.Density = 0
                atm.Haze = 0 
            end
        end
    else
        Lighting.FogEnd   = State.LightingBackup.FogEnd or 100000
        Lighting.FogStart = State.LightingBackup.FogStart or 0
    end
end

function Misc.SetNoShadows(enabled)
    Misc.BackupLighting()
    Lighting.GlobalShadows = not enabled
end

function Misc.SetClearWeather(enabled)
    Misc.BackupLighting()
    if enabled then
        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj:IsA("Atmosphere") then 
                obj.Density = 0
                obj.Haze = 0
            end
        end
    end
end

function Misc.SetLowGraphics(enabled)
    settings().Rendering.QualityLevel = enabled 
        and Enum.QualityLevel.Level01 
        or Enum.QualityLevel.Automatic
end

function Misc.SetFOV(fov)
    fov = tonumber(fov) or 70
    if Camera then 
        Camera.FieldOfView = fov 
    end
end

function Misc.SetTime(time)
    time = tonumber(time) or 14
    Lighting.ClockTime = time
end

function Misc.RemovePostFX(remove)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
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

function Misc.SetNoParticles(enabled)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire") 
        or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Trail") then
            v.Enabled = not enabled
        end
    end
end

function Misc.SetHideName(enabled)
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        for _, gui in ipairs(head:GetChildren()) do
            if gui:IsA("BillboardGui") then 
                gui.Enabled = not enabled 
            end
        end
    end
end

function Misc.SetNoSound(enabled)
    if enabled then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and s.Playing and not table.find(State.MutedSounds, s) then
                s.Volume = 0
                table.insert(State.MutedSounds, s)
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

function Misc.SetMuteBGMusic(enabled)
    local bgFolder = Workspace:FindFirstChild("BackgroundSounds")
    if not bgFolder then return end
    for _, s in ipairs(bgFolder:GetDescendants()) do
        if s:IsA("Sound") then 
            s.Volume = enabled and 0 or 1 
        end
    end
end

function Misc.SetFreecam(enabled)
    if State.FreecamConn then 
        State.FreecamConn:Disconnect() 
        State.FreecamConn = nil 
    end
    if enabled then
        local speed = 2
        local pos = Camera.CFrame.Position
        Camera.CameraType = Enum.CameraType.Scriptable
        
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local move = Vector3.new()
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0, 1, 0) end
            
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
        local TS = game:GetService("TeleportService")
        local HS = game:GetService("HttpService")
        local servers = HS:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"))
        
        if servers.data then
            for _, s in ipairs(servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(tostring(game.PlaceId), s.id, LocalPlayer)
                    return
                end
            end
        end
    end)
    
    if not ok then 
        Util.Notify("Server Hop", "Failed: " .. tostring(err), 3) 
    end
end

function Misc.AutoRejoin()
    LocalPlayer.OnTeleport:Connect(function(state)
        if State.AutoRejoin and state == Enum.TeleportState.Failed then
            wait(3)
            game:GetService("TeleportService"):Teleport(tostring(game.PlaceId), LocalPlayer)
        end
    end)
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        if State.AutoRejoin then
            wait(3)
            game:GetService("TeleportService"):Teleport(tostring(game.PlaceId), LocalPlayer)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS LISTENERS
--═══════════════════════════════════════════════════════════════
local Awareness = {}

function Awareness.Setup()
    if R.Generator.SkillCheck then
        Util.SafeConnect(R.Generator.SkillCheck.OnClientEvent, function(gen, point, kind, difficulty)
            if State.SkillCheckNotify then
                Util.Notify("Skill Check!", "Difficulty: " .. tostring(difficulty or "?"), 2)
            end
        end)
    end
    
    if R.Healing.SkillCheck then
        Util.SafeConnect(R.Healing.SkillCheck.OnClientEvent, function()
            if State.HealSkillNotify then 
                Util.Notify("Heal Skill Check!", "Complete the check", 2) 
            end
        end)
    end
    
    if R.Generator.SkillCheckFail then
        Util.SafeConnect(R.Generator.SkillCheckFail.OnClientEvent, function()
            if State.SkillCheckNotify then 
                Util.Notify("Skill Check Failed", "Generator progress lost!", 3) 
            end
        end)
    end
    
    if R.Generator.GenDone then
        Util.SafeConnect(R.Generator.GenDone.OnClientEvent, function()
            if State.GenDoneNotify then 
                Util.Notify("Generator Complete!", "One gen done", 3) 
            end
        end)
    end
    
    if R.Generator.AllGenDone then
        Util.SafeConnect(R.Generator.AllGenDone.OnClientEvent, function()
            if State.AllGensNotify then 
                Util.Notify("All Gens Done!", "Escape gates powered!", 6) 
            end
        end)
    end
    
    if R.Chase.Music then
        Util.SafeConnect(R.Chase.Music.OnClientEvent, function()
            if State.ChaseAlert then 
                Util.Notify("Chase Active", "Killer is chasing someone", 3) 
            end
        end)
    end
    
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function()
            if State.AttackAlert then 
                Util.Notify("LUNGE!", "Killer is attacking!", 2) 
            end
        end)
    end
    
    if R.KillerPerks.KingScourge then
        local start = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if start then
            Util.SafeConnect(start.OnClientEvent, function()
                if State.AttackAlert then 
                    Util.Notify("KING SCOURGE!", "Dodge NOW!", 2) 
                end
            end)
        end
    end
    
    if R.Game.KillerMorph then
        Util.SafeConnect(R.Game.KillerMorph.OnClientEvent, function()
            State.IsKiller = true
            Util.Notify("Role", "You are the KILLER", 5)
        end)
    end
    
    if R.Game.Start then
        Util.SafeConnect(R.Game.Start.OnClientEvent, function()
            State.MatchActive = true
            State.IsKiller = false
            Util.Notify("Match Started", "Good luck!", 3)
        end)
    end
    
    if R.Game.RoundEnd then
        Util.SafeConnect(R.Game.RoundEnd.OnClientEvent, function()
            State.MatchActive = false
            ESP.ClearAll()
        end)
    end
    
    if R.Game.OneLeft then
        Util.SafeConnect(R.Game.OneLeft.OnClientEvent, function()
            if State.OneLeftNotify then 
                Util.Notify("Last Survivor!", "You are alone", 5) 
            end
        end)
    end
    
    if R.Game.Death then
        Util.SafeConnect(R.Game.Death.OnClientEvent, function()
            if State.DeathNotify then 
                Util.Notify("Death", "A survivor has died", 3) 
            end
        end)
    end
    
    if R.Carry.HookEvent then
        Util.SafeConnect(R.Carry.HookEvent.OnClientEvent, function()
            if State.HookNotify then 
                Util.Notify("Hooked", "Someone was hooked", 3) 
            end
        end)
    end
    
    Util.SafeConnect(LocalPlayer.Idled, function()
        if State.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- WINDOW CREATION (Safe)
--═══════════════════════════════════════════════════════════════
local Window

local windowSuccess = pcall(function()
    Window = WindUI:CreateWindow({
        Title        = HUB.Name,
        Icon         = "skull",
        Author       = "by " .. HUB.Author .. " | " .. HUB.Game,
        Folder       = HUB.Folder,
        Size         = UDim2.fromOffset(580, 460),
        Transparent  = true,
        Theme        = "Dark",
        SideBarWidth = 160,
        HasOutline   = true,
        KeySystem    = false,
    })
end)

if not windowSuccess or not Window then
    warn("[X0DEC04T] CRITICAL: Window creation failed - aborting script load")
    return
end

print("[X0DEC04T] Window created successfully")

--═══════════════════════════════════════════════════════════════
-- FLOATING LAUNCHER
--═══════════════════════════════════════════════════════════════
local Launcher = {}
Launcher.Instance = nil
Launcher.Gui      = nil
Launcher.Visible  = false

function Launcher:Build()
    if self.Gui and self.Gui.Parent then return self.Gui end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "X0DEC04T_Launcher"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.DisplayOrder   = 999999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Enabled        = false
    ScreenGui.Parent         = Util.GetGuiParent()

    local Button = Instance.new("TextButton")
    Button.Name             = "LauncherButton"
    Button.Size             = UDim2.fromOffset(155, 50)
    Button.Position         = UDim2.new(0, 20, 0.5, -25)
    Button.BackgroundColor3 = Color3.fromRGB(25, 20, 45)
    Button.BorderSizePixel  = 0
    Button.AutoButtonColor  = false
    Button.Text             = ""
    Button.ZIndex           = 10
    Button.Parent           = ScreenGui

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 14)
    Corner.Parent       = Button

    local Gradient = Instance.new("UIGradient")
    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 90, 200)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 80, 220)),
    })
    Gradient.Rotation = 45
    Gradient.Parent   = Button

    local Stroke = Instance.new("UIStroke")
    Stroke.Thickness       = 1.5
    Stroke.Color           = Color3.fromRGB(160, 130, 255)
    Stroke.Transparency    = 0.3
    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Stroke.Parent          = Button

    local Glow = Instance.new("ImageLabel")
    Glow.Name                   = "Glow"
    Glow.BackgroundTransparency = 1
    Glow.Image                  = "rbxassetid://5028857084"
    Glow.ImageColor3            = Color3.fromRGB(140, 100, 255)
    Glow.ImageTransparency      = 0.55
    Glow.ScaleType              = Enum.ScaleType.Slice
    Glow.SliceCenter            = Rect.new(24, 24, 276, 276)
    Glow.Size                   = UDim2.new(1, 30, 1, 30)
    Glow.Position               = UDim2.new(0, -15, 0, -15)
    Glow.ZIndex                 = 9
    Glow.Parent                 = Button

    local Logo = Instance.new("ImageLabel")
    Logo.Name             = "Logo"
    Logo.Size             = UDim2.fromOffset(38, 38)
    Logo.Position         = UDim2.new(0, 6, 0.5, -19)
    Logo.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
    Logo.BorderSizePixel  = 0
    Logo.Image            = HUB.LogoID
    Logo.ZIndex           = 11
    Logo.Parent           = Button

    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(1, 0)
    LogoCorner.Parent       = Logo

    local LogoStroke = Instance.new("UIStroke")
    LogoStroke.Color        = Color3.fromRGB(200, 180, 255)
    LogoStroke.Thickness    = 1
    LogoStroke.Transparency = 0.4
    LogoStroke.Parent       = Logo

    local Label = Instance.new("TextLabel")
    Label.Name                   = "Label"
    Label.BackgroundTransparency = 1
    Label.Size                   = UDim2.new(1, -55, 1, 0)
    Label.Position               = UDim2.new(0, 50, 0, 0)
    Label.Text                   = "X0DEC04T"
    Label.Font                   = Enum.Font.GothamBold
    Label.TextSize               = 15
    Label.TextColor3             = Color3.fromRGB(255, 255, 255)
    Label.TextStrokeTransparency = 0.6
    Label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
    Label.TextXAlignment         = Enum.TextXAlignment.Center
    Label.ZIndex                 = 11
    Label.Parent                 = Button

    local hoverIn  = TweenService:Create(Button, TweenInfo.new(0.2), { Size = UDim2.fromOffset(165, 54) })
    local hoverOut = TweenService:Create(Button, TweenInfo.new(0.2), { Size = UDim2.fromOffset(155, 50) })
    local glowIn   = TweenService:Create(Glow, TweenInfo.new(0.2), { ImageTransparency = 0.3 })
    local glowOut  = TweenService:Create(Glow, TweenInfo.new(0.2), { ImageTransparency = 0.55 })

    Button.MouseEnter:Connect(function() hoverIn:Play(); glowIn:Play() end)
    Button.MouseLeave:Connect(function() hoverOut:Play(); glowOut:Play() end)

    task.spawn(function()
        while Glow.Parent do
            TweenService:Create(Glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.4 }):Play()
            task.wait(1.5)
            TweenService:Create(Glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.65 }):Play()
            task.wait(1.5)
        end
    end)

    local dragging, dragStart, startPos, didDrag = false, nil, nil, false
    Button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            didDrag   = false
            dragStart = input.Position
            startPos  = Button.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then didDrag = true end
            Button.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    Button.MouseButton1Click:Connect(function()
        if didDrag then return end
        Launcher:Hide()
        Launcher:RestoreWindow()
    end)

    self.Gui      = ScreenGui
    self.Instance = Button
    return ScreenGui
end

function Launcher:Show()
    if not self.Gui then self:Build() end
    self.Gui.Enabled = true
    self.Visible    = true
    self.Instance.Size = UDim2.fromOffset(0, 50)
    TweenService:Create(self.Instance, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(155, 50),
    }):Play()
end

function Launcher:Hide()
    if self.Gui then self.Gui.Enabled = false end
    self.Visible = false
end

function Launcher:RestoreWindow()
    pcall(function()
        if Window.Open then 
            Window:Open()
        elseif Window.SetVisibility then 
            Window:SetVisibility(true)
        else 
            Window:Toggle() 
        end
    end)
end

function Launcher:MinimizeWindow()
    pcall(function()
        if Window.Close then 
            Window:Close()
        elseif Window.SetVisibility then 
            Window:SetVisibility(false)
        else 
            Window:Toggle() 
        end
    end)
    self:Show()
end

pcall(function()
    if Window.OnClose then 
        Window:OnClose(function() Launcher:MinimizeWindow() end) 
    end
end)

task.spawn(function()
    local lastState = true
    while task.wait(0.3) do
        local isOpen = true
        pcall(function()
            if Window.UIElements and Window.UIElements.Main then
                isOpen = Window.UIElements.Main.Visible
            end
        end)
        if lastState and not isOpen and not Launcher.Visible then
            Launcher:Show()
        elseif not lastState and isOpen and Launcher.Visible then
            Launcher:Hide()
        end
        lastState = isOpen
    end
end)

Launcher:Build()

--═══════════════════════════════════════════════════════════════
-- TAB CREATION (Safe)
--═══════════════════════════════════════════════════════════════
local Tabs = {}
local tabList = {"Main", "Awareness", "ESP", "Movement", "Visuals", "Misc", "Settings"}

for i, name in ipairs(tabList) do
    local success, tab = pcall(function()
        return Window:Tab({ Title = name })
    end)
    
    if success and tab then
        Tabs[name] = tab
    else
        print("[X0DEC04T] Warning: Tab '"..name.."' failed to create")
    end
end

if not Tabs.Main or not Tabs.Awareness or not Tabs.ESP 
or not Tabs.Movement or not Tabs.Visuals or not Tabs.Misc or not Tabs.Settings then
    error("[X0DEC04T] Not all tabs could be created - aborting")
    return
end

Window:SelectTab(1)
print("[X0DEC04T] All tabs created: " .. table.concat(tabList, ", "))

--═══════════════════════════════════════════════════════════════
-- MAIN TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Main:Section({ Title = "Welcome" })

Tabs.Main:Paragraph({
    Title = HUB.Name,
    Desc  = "Premium hub for " .. HUB.Game .. "\nVersion " .. HUB.Version .. " by " .. HUB.Author,
})

Tabs.Main:Paragraph({
    Title = "Game Architecture",
    Desc  = "Server-authoritative game.\nFocus: Awareness, ESP, Movement, Visuals.",
})

local killersText = {}
for k, _ in pairs(KNOWN_KILLERS) do
    table.insert(killersText, k:gsub("^%l", string.upper))
end
Tabs.Main:Paragraph({
    Title = "Detected Killers",
    Desc  = #killersText > 0 and table.concat(killersText, ", ") or "None detected",
})

Tabs.Main:Section({ Title = "Match Info" })

local RoleLabel  = Tabs.Main:Paragraph({ Title = "Your Role", Desc = "Waiting..." })
local MatchLabel = Tabs.Main:Paragraph({ Title = "Match State", Desc = "Waiting..." })

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            RoleLabel:SetDesc(State.IsKiller and "KILLER" or "SURVIVOR")
            MatchLabel:SetDesc(State.MatchActive and "In Match" or "Lobby")
        end)
    end
end)

--═══════════════════════════════════════════════════════════════
-- AWARENESS TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Awareness:Section({ Title = "Killer Alerts" })

Tabs.Awareness:Toggle({ 
    Title = "Chase Music Alert", 
    Desc  = "Alert when chase music plays", 
    Value = true, 
    Callback = function(v) State.ChaseAlert = v end 
})

Tabs.Awareness:Toggle({ 
    Title = "Attack Alert (Lunge/Scourge)", 
    Desc  = "Alert when killer attacks", 
    Value = true, 
    Callback = function(v) State.AttackAlert = v end 
})

Tabs.Awareness:Section({ Title = "Skill Checks" })

Tabs.Awareness:Toggle({ 
    Title = "Gen Skill Check Notify", 
    Value = true, 
    Callback = function(v) State.SkillCheckNotify = v end 
})

Tabs.Awareness:Toggle({ 
    Title = "Heal Skill Check Notify", 
    Value = true, 
    Callback = function(v) State.HealSkillNotify = v end 
})

Tabs.Awareness:Section({ Title = "Objectives" })

Tabs.Awareness:Toggle({ Title = "Gen Done Notify",    Value = true, Callback = function(v) State.GenDoneNotify = v end })
Tabs.Awareness:Toggle({ Title = "All Gens Done Notify", Value = true, Callback = function(v) State.AllGensNotify = v end })
Tabs.Awareness:Toggle({ Title = "Hook Notify",           Value = true, Callback = function(v) State.HookNotify = v end })
Tabs.Awareness:Toggle({ Title = "Death Notify",          Value = true, Callback = function(v) State.DeathNotify = v end })
Tabs.Awareness:Toggle({ Title = "Last Survivor Notify",  Value = true, Callback = function(v) State.OneLeftNotify = v end })

--═══════════════════════════════════════════════════════════════
-- ESP TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.ESP:Section({ Title = "Players (Highlight)" })

Tabs.ESP:Toggle({
    Title = "Killer ESP",
    Desc  = "Red highlight through walls + killer name",
    Value = false,
    Callback = function(v)
        State.ESP_Killer = v
        if not v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and Role.IsKiller(plr.Character) then 
                    ESP.Clear(plr.Character) 
                end
            end
        end
    end,
})

Tabs.ESP:Toggle({
    Title = "Survivor ESP",
    Desc  = "Cyan highlight through walls + player name",
    Value = false,
    Callback = function(v)
        State.ESP_Survivors = v
        if not v then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and not Role.IsFakeCharacter(plr.Character) and not Role.IsKiller(plr.Character) then 
                    ESP.Clear(plr.Character) 
                end
            end
        end
    end,
})

Tabs.ESP:Section({ Title = "Objects" })

Tabs.ESP:Toggle({
    Title = "Generator ESP",
    Desc  = "Yellow highlight",
    Value = false,
    Callback = function(v)
        State.ESP_Generators = v
        if not v and WS.Generators then 
            for _, g in ipairs(WS.Generators:GetChildren()) do 
                ESP.Clear(g) 
            end 
        end
    end,
})

Tabs.ESP:Toggle({ Title = "Item ESP",      Desc  = "Green highlight", Value = false, Callback = function(v) State.ESP_Items = v end })
Tabs.ESP:Toggle({ Title = "Weapon ESP",    Desc  = "Pink highlight", Value = false, Callback = function(v) State.ESP_Weapons = v; if not v and WS.Weapons then for _, w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end end end })
Tabs.ESP:Toggle({ Title = "Clone ESP",       Desc  = "Gray highlight", Value = false, Callback = function(v) State.ESP_Clones = v; if not v and WS.Clones then for _, c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end end end })

Tabs.ESP:Section({ Title = "Display" })

Tabs.ESP:Toggle({ 
    Title = "Show Name", 
    Value = true, 
    Callback = function(v) 
        State.ESP_ShowName = v 
        for _, cache in pairs(State.ESPCache) do 
            if cache.nameLabel then 
                cache.nameLabel.Visible = v 
            end 
        end 
    end,
})

Tabs.ESP:Toggle({
    Title = "Show Distance",
    Value = true,
    Callback = function(v)
        State.ESP_ShowDistance = v
        for _, cache in pairs(State.ESPCache) do
            if cache.distLabel then 
                cache.distLabel.Visible = v 
            end 
        end
    end,
})

Tabs.ESP:Slider({
    Title = "Max Distance",
    Value = { Min = 50, Max = 2000, Default = 500, Step = 50 },
    Callback = function(v)
        local num = tonumber(v) or 500
        State.ESP_MaxDistance = num
        for _, cache in pairs(State.ESPCache) do
            if cache.billboard then 
                cache.billboard.MaxDistance = num 
            end 
        end
    end,
})

Tabs.ESP:Button({ Title = "Refresh All ESP", Callback = function() ESP.ClearAll(); ESP.RefreshAll(); Util.Notify("ESP", "Refreshed", 2) end })
Tabs.ESP:Button({ Title = "Clear All ESP",  Callback = function() ESP.ClearAll(); Util.Notify("ESP", "Cleared", 2) end })

--═══════════════════════════════════════════════════════════════
-- MOVEMENT TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Movement:Section({ Title = "Speed" })

Tabs.Movement:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 100, Default = 16, Step = 1 },
    Callback = function(v)
        State.WalkSpeed = tonumber(v) or 16
        Movement.ApplyWalkSpeed()
    end,
})

Tabs.Movement:Slider({
    Title = "JumpPower",
    Value = { Min = 50, Max = 200, Default = 50, Step = 1 },
    Callback = function(v)
        State.JumpPower = tonumber(v) or 50
        Movement.ApplyJumpPower()
    end,
})

Tabs.Movement:Section({ Title = "Advanced" })

Tabs.Movement:Toggle({
    Title = "NoClip",
    Desc  = "Walk through walls",
    Value = false,
    Callback = function(v) State.NoClip = v; Movement.SetNoClip(v) end,
})

Tabs.Movement:Toggle({
    Title = "Infinite Jump",
    Desc  = "Jump mid-air",
    Value = false,
    Callback = function(v) State.InfJump = v; Movement.SetInfJump(v) end,
})

Tabs.Movement:Section({ Title = "Teleport" })

Tabs.Movement:Button({
    Title = "Teleport to Nearest Generator",
    Callback = Movement.TeleportToNearestGenerator,
})

local teleTargetName = ""
Tabs.Movement:Input({
    Title = "Target Player Name",
    Desc  = "Enter exact name (case-sensitive)",
    Value = "",
    Placeholder = "PlayerName...",
    Callback = function(v)
        teleTargetName = tostring(v or "")
    end,
})

Tabs.Movement:Button({
    Title = "Teleport to Target",
    Callback = function()
        if teleTargetName and teleTargetName ~= "" then
            Movement.TeleportToPlayer(teleTargetName)
        else
            Util.Notify("Movement", "Enter a target player name above", 3)
        end
    end,
})

--═══════════════════════════════════════════════════════════════
-- VISUALS TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Visuals:Section({ Title = "Lighting" })

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "FullBright",
        Desc  = "Max brightness",
        Value = false,
        Callback = function(v) State.FullBright = v; Misc.SetFullBright(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "No Fog",
        Desc  = "Remove fog + atmosphere",
        Value = false,
        Callback = function(v) State.NoFog = v; Misc.SetNoFog(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "No Shadows",
        Desc  = "Disable global shadows",
        Value = false,
        Callback = function(v) State.NoShadows = v; Misc.SetNoShadows(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "Clear Weather",
        Desc  = "Remove haze/rain",
        Value = false,
        Callback = function(v) State.ClearWeather = v; Misc.SetClearWeather(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Slider({
        Title = "Time of Day",
        Value = { Min = 0, Max = 24, Default = 14, Step = 0.5 },
        Callback = function(v) State.Time = tonumber(v) or 14; Misc.SetTime(State.Time) end,
    })
end)

Tabs.Visuals:Section({ Title = "Camera" })

pcall(function()
    Tabs.Visuals:Slider({
        Title = "FOV",
        Value = { Min = 30, Max = 120, Default = 70, Step = 5 },
        Callback = function(v) State.FOV = tonumber(v) or 70; Misc.SetFOV(State.FOV) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "Freecam",
        Desc  = "Free camera (WASD + Space/Ctrl)",
        Value = false,
        Callback = function(v) State.Freecam = v; Misc.SetFreecam(v) end,
    })
end)

Tabs.Visuals:Section({ Title = "Post-FX" })

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "Remove Blur/Bloom/DOF",
        Desc  = "Cleaner view",
        Value = false,
        Callback = function(v) State.RemoveBlur = v; Misc.RemovePostFX(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "Remove Color Correction",
        Desc  = "Disables tint filters",
        Value = false,
        Callback = function(v) State.RemoveColorCorr = v; Misc.RemoveColorCorrection(v) end,
    })
end)

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "No Particles",
        Desc  = "Kill particles/fire/smoke",
        Value = false,
        Callback = function(v) State.NoParticles = v; Misc.SetNoParticles(v) end,
    })
end)

Tabs.Visuals:Section({ Title = "Performance" })

pcall(function()
    Tabs.Visuals:Toggle({
        Title = "Low Graphics Mode",
        Desc  = "FPS boost",
        Value = false,
        Callback = function(v) State.LowGraphics = v; Misc.SetLowGraphics(v) end,
    })
end)

--═══════════════════════════════════════════════════════════════
-- MISC TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Misc:Section({ Title = "Audio" })

pcall(function()
    Tabs.Misc:Toggle({
        Title = "Mute All Sounds",
        Desc  = "Silences game sounds",
        Value = false,
        Callback = function(v) State.NoSound = v; Misc.SetNoSound(v) end,
    })
end)

pcall(function()
    Tabs.Misc:Toggle({
        Title = "Mute Background Music",
        Desc  = "Silences BackgroundSounds",
        Value = false,
        Callback = function(v) State.MuteBGMusic = v; Misc.SetMuteBGMusic(v) end,
    })
end)

Tabs.Misc:Section({ Title = "Character" })

pcall(function()
    Tabs.Misc:Toggle({
        Title = "Hide Own Name",
        Desc  = "Hides overhead tag",
        Value = false,
        Callback = function(v) State.HideName = v; Misc.SetHideName(v) end,
    })
end)

Tabs.Misc:Section({ Title = "Automation" })

pcall(function()
    Tabs.Misc:Toggle({
        Title = "Auto Rejoin on Kick",
        Desc  = "Rejoins on disconnect",
        Value = false,
        Callback = function(v) State.AutoRejoin = v; Misc.AutoRejoin() end,
    })
end)

pcall(function()
    Tabs.Misc:Button({
        Title = "Server Hop",
        Desc  = "Joins new server",
        Callback = Misc.ServerHop,
    })
end)

pcall(function()
    Tabs.Misc:Button({
        Title = "Copy JobId",
        Callback = function()
            if setclipboard then 
                setclipboard(tostring(game.JobId))
                Util.Notify("Copied", "JobId -> clipboard", 3)
            else
                Util.Notify("Error", "Clipboard unsupported", 3)
            end
        end,
    })
end)

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB CONTENT
--═══════════════════════════════════════════════════════════════
Tabs.Settings:Section({ Title = "Anti-AFK" })

pcall(function()
    Tabs.Settings:Toggle({
        Title = "Anti-AFK",
        Desc  = "Prevents idle kick",
        Value = true,
        Callback = function(v) State.AntiAFK = v end,
    })
end)

Tabs.Settings:Section({ Title = "Theme" })

pcall(function()
    Tabs.Settings:Dropdown({
        Title  = "Theme",
        Values = {"Dark", "Light"},
        Multi  = false,
        AllowNone = false,
        Value  = {"Dark"},
        Callback = function(v)
            local t = typeof(v) == "table" and v[1] or tostring(v):upper()
            pcall(function() 
                WindUI:SetTheme(t) 
            end)
        end,
    })
end)

Tabs.Settings:Section({ Title = "Config" })

pcall(function()
    Tabs.Settings:Button({
        Title = "Save Config",
        Callback = function()
            pcall(function()
                local cfgManager = Window.ConfigManager and Window.ConfigManager.ConfigManager
                if cfgManager then
                    cfgManager:Save("X0DEC04T_Default")
                    Util.Notify("Config", "Saved", 3)
                end
            end)
        end,
    })
end)

pcall(function()
    Tabs.Settings:Button({
        Title = "Load Config",
        Callback = function()
            pcall(function()
                local cfgManager = Window.ConfigManager and Window.ConfigManager.ConfigManager
                if cfgManager then
                    cfgManager:Load("X0DEC04T_Default")
                    Util.Notify("Config", "Loaded", 3)
                end
            end)
        end,
    })
end)

Tabs.Settings:Section({ Title = "Keybinds" })

pcall(function()
    Tabs.Settings:Keybind({
        Title = "Toggle UI",
        Value = "RightShift",
        Callback = function() pcall(function() Window:Toggle() end) end,
    })
end)

pcall(function()
    Tabs.Settings:Keybind({
        Title = "Panic ESP",
        Value = "End",
        Callback = function()
            State.ESP_Killer     = false
            State.ESP_Survivors  = false
            State.ESP_Generators = false
            State.ESP_Items      = false
            State.ESP_Weapons    = false
            State.ESP_Clones     = false
            ESP.ClearAll()
            Util.Notify("Panic", "ESP disabled", 3)
        end,
    })
end)

Tabs.Settings:Section({ Title = "Info" })

Tabs.Settings:Paragraph({
    Title = "Credits",
    Desc  = "Created by " .. HUB.Author .. "\nVersion " .. HUB.Version .. "\nGame: " .. HUB.Game,
})

pcall(function()
    Tabs.Settings:Button({
        Title = "Unload Hub",
        Callback = function()
            for _, conn in ipairs(State.Connections) do
                pcall(function() conn:Disconnect() end)
            end
            
            if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
            if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
            if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
            
            for k, v in pairs(State.LightingBackup) do 
                pcall(function() Lighting[k] = v end) 
            end
            
            ESP.ClearAll()
            
            if Launcher.Gui then 
                pcall(function() Launcher.Gui:Destroy() end) 
            end
            
            pcall(function() Window:Destroy() end)
        end,
    })
end)

--═══════════════════════════════════════════════════════════════
-- INITIALIZATION
--═══════════════════════════════════════════════════════════════
print("[X0DEC04T] Setting up awareness listeners...")
Awareness.Setup()

print("[X0DEC04T] Setting up auto-rejoin...")
Misc.AutoRejoin()

print("[X0DEC04T] Character spawn handler...")
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Movement.ApplyWalkSpeed()
    Movement.ApplyJumpPower()
    
    if State.NoClip then 
        Movement.SetNoClip(true) 
    end
    if State.FullBright then 
        Misc.SetFullBright(true) 
    end
    if State.NoFog then 
        Misc.SetNoFog(true) 
    end
    if State.HideName then 
        Misc.SetHideName(true) 
    end
    if State.FOV ~= 70 then 
        Misc.SetFOV(State.FOV) 
    end
end)

-- Lighting persistence check
task.spawn(function()
    while task.wait(5) do
        if State.FullBright then 
            Misc.SetFullBright(true) 
        end
        if State.NoFog then 
            Misc.SetNoFog(true) 
        end
        if State.NoShadows then 
            Misc.SetNoShadows(true) 
        end
    end
end)

Util.Notify(HUB.Name, "Loaded v" .. HUB.Version, 5)
print("[X0DEC04T] Fully loaded and running")
