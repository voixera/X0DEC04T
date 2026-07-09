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
-- WINDUI LOAD
--═══════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

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

-- Validate logo
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
    
    if State.NoClip then Movement.SetNoClip(true) end
    if State.FullBright then Misc.SetFullBright(true) end
    if State.NoFog then Misc.SetNoFog(true) end
    if State.HideName then Misc.SetHideName(true) end
    if State.FOV ~= 70 then Misc.SetFOV(State.FOV) end
end)

-- Lighting persistence check
task.spawn(function()
    while task.wait(5) do
        if State.FullBright then Misc.SetFullBright(true) end
        if State.NoFog then Misc.SetNoFog(true) end
        if State.NoShadows then Misc.SetNoShadows(true) end
    end
end)

Util.Notify(HUB.Name, "Loaded v" .. HUB.Version, 5)
print("[X0DEC04T] Fully loaded and running")
