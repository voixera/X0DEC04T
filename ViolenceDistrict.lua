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
-- WINDUI LOAD (ROBUST MULTI-MIRROR)
--═══════════════════════════════════════════════════════════════
local WindUI

local function tryLoadWindUI()
    local sources = {
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
    }

    for i, url in ipairs(sources) do
        print("[X0DEC04T] Trying WindUI source #" .. i .. ": " .. url)

        local ok, raw = pcall(function() return game:HttpGet(url) end)
        if not ok or type(raw) ~= "string" then
            warn("[X0DEC04T] Source #" .. i .. " HttpGet failed")
        elseif #raw < 500 then
            warn("[X0DEC04T] Source #" .. i .. " returned tiny response (" .. #raw .. " chars)")
        elseif raw:sub(1, 15):lower():find("<!doctype") or raw:sub(1, 5):lower():find("<html") then
            warn("[X0DEC04T] Source #" .. i .. " returned HTML (redirect/error page)")
        else
            local compileOk, chunk = pcall(loadstring, raw)
            if not compileOk or type(chunk) ~= "function" then
                warn("[X0DEC04T] Source #" .. i .. " compile fail: " .. tostring(chunk))
            else
                local runOk, result = pcall(chunk)
                if runOk and type(result) == "table" then
                    print("[X0DEC04T] SUCCESS: WindUI loaded from source #" .. i)
                    return result
                else
                    warn("[X0DEC04T] Source #" .. i .. " execution fail: " .. tostring(result))
                end
            end
        end
        task.wait(0.3)
    end
    return nil
end

WindUI = tryLoadWindUI()

if not WindUI then
    warn("╔══════════════════════════════════════════════════╗")
    warn("║  X0DEC04T Hub - WindUI FAILED TO LOAD           ║")
    warn("║  All mirror sources failed. Possible causes:    ║")
    warn("║  - Executor's HttpGet is broken/blocked         ║")
    warn("║  - Firewall / no internet                       ║")
    warn("║  - GitHub rate-limited your IP                  ║")
    warn("║  Try: rejoin, wait 60s, use different executor  ║")
    warn("╚══════════════════════════════════════════════════╝")
    return
end

print("[X0DEC04T] WindUI ready")

--═══════════════════════════════════════════════════════════════
-- SAFE UI HELPER
--═══════════════════════════════════════════════════════════════
local function Safe(fn, label)
    local ok, err = pcall(fn)
    if not ok then
        warn("[X0DEC04T] UI FAIL ("..tostring(label or "?").."): "..tostring(err))
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
    Folder  = "X0DEC04T_Hub",
    LogoID  = "rbxassetid://91626851418651",
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
-- REMOTES
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
    Healing = { SkillCheck = Remotes.Healing:FindFirstChild("SkillCheckEvent") },
    Chase   = { Music = Remotes.Chase:FindFirstChild("ChaseMusicEvent") },
    Attacks = {
        Lunge       = Remotes.Attacks:FindFirstChild("Lunge"),
        BasicAttack = Remotes.Attacks:FindFirstChild("BasicAttack"),
    },
    KillerPerks = { KingScourge = Remotes.KillerPerks:FindFirstChild("kingscourge") },
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
-- WORKSPACE
--═══════════════════════════════════════════════════════════════
local WS = {
    Map        = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Mazes      = Workspace:FindFirstChild("Mazes"),
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then WS.Generators = WS.Map:FindFirstChild("Generators") end

--═══════════════════════════════════════════════════════════════
-- STATE
--═══════════════════════════════════════════════════════════════
local State = {
    ChaseAlert=true, AttackAlert=true, SkillCheckNotify=true, HealSkillNotify=true,
    GenDoneNotify=true, AllGensNotify=true, OneLeftNotify=true, HookNotify=true, DeathNotify=true,
    ESP_Generators=false, ESP_Killer=false, ESP_Survivors=false, ESP_Items=false,
    ESP_Weapons=false, ESP_Clones=false, ESP_MaxDistance=500, ESP_ShowDistance=true, ESP_ShowName=true,
    Color_Killer=Color3.fromRGB(255,40,40), Color_Survivor=Color3.fromRGB(60,220,255),
    Color_Generator=Color3.fromRGB(255,200,60), Color_Item=Color3.fromRGB(120,255,120),
    Color_Weapon=Color3.fromRGB(255,120,220), Color_Clone=Color3.fromRGB(180,180,180),
    WalkSpeed=16, JumpPower=50, NoClip=false, InfJump=false,
    FullBright=false, NoFog=false, NoShadows=false, ClearWeather=false, LowGraphics=false,
    FOV=70, Time=14, RemoveBlur=false, RemoveColorCorr=false, Freecam=false,
    HideName=false, NoSound=false, MuteBGMusic=false, NoParticles=false, AutoRejoin=false,
    AntiAFK=true, IsKiller=false, MatchActive=false,
    ESPCache={}, Connections={}, NoClipConn=nil, InfJumpConn=nil, FreecamConn=nil,
    LightingBackup={}, MutedSounds={},
}

--═══════════════════════════════════════════════════════════════
-- UTILITY
--═══════════════════════════════════════════════════════════════
local Util = {}

function Util.SafeConnect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function() return signal:Connect(callback) end)
    if ok and conn then table.insert(State.Connections, conn); return conn end
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
    pcall(function()
        WindUI:Notify({
            Title = title or HUB.Name,
            Content = content or "",
            Duration = duration or 4,
            Icon = "bell",
        })
    end)
end

function Util.GetGuiParent()
    local parent = CoreGui
    pcall(function() if gethui then parent = gethui() end end)
    return parent
end

--═══════════════════════════════════════════════════════════════
-- ROLE
--═══════════════════════════════════════════════════════════════
local Role = {}

function Role.IsKiller(character)
    if not character then return false end
    if character:GetAttribute("Killer") == true
    or character:GetAttribute("IsKiller") == true
    or character:GetAttribute("Role") == "Killer" then return true end
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
        if n:find(k, 1, true) then return k:gsub("^%l", string.upper) end
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
-- ESP
--═══════════════════════════════════════════════════════════════
local ESP = {}

function ESP.Clear(adornee)
    if State.ESPCache[adornee] then
        for _, obj in pairs(State.ESPCache[adornee]) do
            if typeof(obj) == "Instance" and obj.Parent then obj:Destroy() end
        end
        State.ESPCache[adornee] = nil
    end
end

function ESP.ClearAll()
    for adornee, _ in pairs(State.ESPCache) do ESP.Clear(adornee) end
    State.ESPCache = {}
end

function ESP.CreateCharacterESP(character, label, color)
    if State.ESPCache[character] then ESP.Clear(character) end
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = character
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1,1,1)
    highlight.FillTransparency = 0.55
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = Util.GetGuiParent()

    local bb = Instance.new("BillboardGui")
    bb.Adornee = hrp
    bb.Size = UDim2.new(0,200,0,45)
    bb.StudsOffset = Vector3.new(0,3.5,0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = math.max(50, State.ESP_MaxDistance)
    bb.Parent = Util.GetGuiParent()

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1,0,0.6,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = tostring(label)
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Visible = State.ESP_ShowName
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1,0,0.4,0)
    distLabel.Position = UDim2.new(0,0,0.6,0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(230,230,230)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.Visible = State.ESP_ShowDistance
    distLabel.Parent = bb

    State.ESPCache[character] = { highlight=highlight, billboard=bb, nameLabel=nameLabel, distLabel=distLabel, hrp=hrp }
end

function ESP.CreateObjectESP(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end
    local part = model
    if model:IsA("Model") then part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") end
    if not part then return end

    local highlight = Instance.new("Highlight")
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.7
    highlight.OutlineTransparency = 0.2
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = Util.GetGuiParent()

    local bb = Instance.new("BillboardGui")
    bb.Adornee = part
    bb.Size = UDim2.new(0,180,0,45)
    bb.StudsOffset = Vector3.new(0,2,0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = math.max(50, State.ESP_MaxDistance)
    bb.Parent = Util.GetGuiParent()

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1,0,0.6,0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = tostring(label)
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.Visible = State.ESP_ShowName
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(1,0,0.4,0)
    distLabel.Position = UDim2.new(0,0,0.6,0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text = "0m"
    distLabel.TextColor3 = Color3.fromRGB(220,220,220)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 11
    distLabel.Visible = State.ESP_ShowDistance
    distLabel.Parent = bb

    State.ESPCache[model] = { highlight=highlight, billboard=bb, nameLabel=nameLabel, distLabel=distLabel, hrp=part }
end

function ESP.UpdateDistances()
    local hrp = Util.GetHRP()
    if not hrp then return end
    for adornee, cache in pairs(State.ESPCache) do
        if cache.distLabel and cache.hrp and cache.hrp.Parent then
            local dist = (cache.hrp.Position - hrp.Position).Magnitude
            cache.distLabel.Text = tostring(math.floor(dist)).."m"
        end
    end
end

function ESP.Validate()
    for adornee, _ in pairs(State.ESPCache) do
        if not adornee or not adornee.Parent then ESP.Clear(adornee) end
    end
end

function ESP.ScanPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char and not Role.IsFakeCharacter(char) then
                local isK = Role.IsKiller(char)
                if isK and State.ESP_Killer and not State.ESPCache[char] then
                    ESP.CreateCharacterESP(char, "☠ "..Role.GetKillerName(char).." ["..plr.Name.."]", State.Color_Killer)
                elseif not isK and State.ESP_Survivors and not State.ESPCache[char] then
                    ESP.CreateCharacterESP(char, "◈ "..plr.Name, State.Color_Survivor)
                elseif isK and not State.ESP_Killer then ESP.Clear(char)
                elseif not isK and not State.ESP_Survivors then ESP.Clear(char) end
            end
        end
    end
end

function ESP.ScanGenerators()
    if not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators and not State.ESPCache[gen] then
            ESP.CreateObjectESP(gen, "⚡ "..gen.Name, State.Color_Generator)
        elseif not State.ESP_Generators then ESP.Clear(gen) end
    end
end

function ESP.ScanItems()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj:GetAttribute("Item") or obj:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[obj] then
                ESP.CreateObjectESP(obj, "🎒 "..obj.Name, State.Color_Item)
            elseif not State.ESP_Items then ESP.Clear(obj) end
        end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.CreateObjectESP(w, "⚔ "..w.Name, State.Color_Weapon)
        elseif not State.ESP_Weapons then ESP.Clear(w) end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones and not State.ESPCache[c] then
            ESP.CreateObjectESP(c, "👥 Clone", State.Color_Clone)
        elseif not State.ESP_Clones then ESP.Clear(c) end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers(); ESP.ScanGenerators(); ESP.ScanItems(); ESP.ScanWeapons(); ESP.ScanClones()
end

task.spawn(function()
    while task.wait(2) do pcall(ESP.RefreshAll) end
end)

RunService.Heartbeat:Connect(function() pcall(ESP.UpdateDistances) end)

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
    if hum then hum.JumpPower = tonumber(State.JumpPower) or 50; hum.UseJumpPower = true end
end

function Movement.SetNoClip(enabled)
    if State.NoClipConn then State.NoClipConn:Disconnect(); State.NoClipConn = nil end
    if enabled then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
                end
            end
        end)
    end
end

function Movement.SetInfJump(enabled)
    if State.InfJumpConn then State.InfJumpConn:Disconnect(); State.InfJumpConn = nil end
    if enabled then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local hum = Util.GetHumanoid()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

function Movement.TeleportToNearestGenerator()
    if not WS.Generators then Util.Notify("Teleport","No generators folder",3); return end
    local hrp = Util.GetHRP(); if not hrp then return end
    local nearest, minDist = nil, math.huge
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        local part = gen.PrimaryPart or gen:FindFirstChildWhichIsA("BasePart")
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < minDist then minDist = d; nearest = part end
        end
    end
    if nearest then
        hrp.CFrame = nearest.CFrame + Vector3.new(0,3,0)
        Util.Notify("Teleport","Sent to gen ("..math.floor(minDist).."m)",3)
    end
end

function Movement.TeleportToPlayer(name)
    if type(name) ~= "string" or name == "" then Util.Notify("TP","Invalid name",3); return end
    local target = Players:FindFirstChild(name)
    if not target or not target.Character then Util.Notify("TP","Not found: "..name,3); return end
    local hrp, thrp = Util.GetHRP(), target.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Util.Notify("Teleport","Sent to "..name,3)
    end
end

--═══════════════════════════════════════════════════════════════
-- MISC / VISUALS
--═══════════════════════════════════════════════════════════════
local Misc = {}

function Misc.BackupLighting()
    if next(State.LightingBackup) then return end
    State.LightingBackup = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

function Misc.SetFullBright(enabled)
    Misc.BackupLighting()
    if enabled then
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2; Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.EnvironmentSpecularScale = 1
    else
        for k,v in pairs(State.LightingBackup) do pcall(function() Lighting[k] = v end) end
    end
end

function Misc.SetNoFog(enabled)
    Misc.BackupLighting()
    if enabled then
        Lighting.FogEnd = 999999; Lighting.FogStart = 999999
        for _, atm in ipairs(Lighting:GetChildren()) do
            if atm:IsA("Atmosphere") then atm.Density = 0; atm.Haze = 0 end
        end
    else
        Lighting.FogEnd = State.LightingBackup.FogEnd or 100000
        Lighting.FogStart = State.LightingBackup.FogStart or 0
    end
end

function Misc.SetNoShadows(enabled)
    Misc.BackupLighting(); Lighting.GlobalShadows = not enabled
end

function Misc.SetClearWeather(enabled)
    Misc.BackupLighting()
    if enabled then
        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj:IsA("Atmosphere") then obj.Density = 0; obj.Haze = 0 end
        end
    end
end

function Misc.SetLowGraphics(enabled)
    settings().Rendering.QualityLevel = enabled and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
end

function Misc.SetFOV(fov)
    if Camera then Camera.FieldOfView = tonumber(fov) or 70 end
end

function Misc.SetTime(t) Lighting.ClockTime = tonumber(t) or 14 end

function Misc.RemovePostFX(remove)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not remove
        end
    end
    for _, v in ipairs(Camera:GetDescendants()) do
        if v:IsA("BlurEffect") then v.Enabled = not remove end
    end
end

function Misc.RemoveColorCorrection(remove)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then v.Enabled = not remove end
    end
end

function Misc.SetNoParticles(enabled)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Trail") then
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
            if gui:IsA("BillboardGui") then gui.Enabled = not enabled end
        end
    end
end

function Misc.SetNoSound(enabled)
    if enabled then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and s.Playing and not table.find(State.MutedSounds, s) then
                s.Volume = 0; table.insert(State.MutedSounds, s)
            end
        end
    else
        for _, s in ipairs(State.MutedSounds) do
            if s and s.Parent then pcall(function() s.Volume = 1 end) end
        end
        State.MutedSounds = {}
    end
end

function Misc.SetMuteBGMusic(enabled)
    local bg = Workspace:FindFirstChild("BackgroundSounds")
    if not bg then return end
    for _, s in ipairs(bg:GetDescendants()) do
        if s:IsA("Sound") then s.Volume = enabled and 0 or 1 end
    end
end

function Misc.SetFreecam(enabled)
    if State.FreecamConn then State.FreecamConn:Disconnect(); State.FreecamConn = nil end
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
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
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
    pcall(function()
        local TS = game:GetService("TeleportService")
        local servers = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100"))
        if servers.data then
            for _, s in ipairs(servers.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(tostring(game.PlaceId), s.id, LocalPlayer)
                    return
                end
            end
        end
    end)
end

function Misc.AutoRejoin()
    LocalPlayer.OnTeleport:Connect(function(state)
        if State.AutoRejoin and state == Enum.TeleportState.Failed then
            wait(3); game:GetService("TeleportService"):Teleport(tostring(game.PlaceId), LocalPlayer)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS
--═══════════════════════════════════════════════════════════════
local Awareness = {}

function Awareness.Setup()
    if R.Generator.SkillCheck then
        Util.SafeConnect(R.Generator.SkillCheck.OnClientEvent, function(gen,pt,kind,diff)
            if State.SkillCheckNotify then Util.Notify("Skill Check!","Difficulty: "..tostring(diff or "?"),2) end
        end)
    end
    if R.Healing.SkillCheck then
        Util.SafeConnect(R.Healing.SkillCheck.OnClientEvent, function()
            if State.HealSkillNotify then Util.Notify("Heal Skill Check!","",2) end
        end)
    end
    if R.Generator.SkillCheckFail then
        Util.SafeConnect(R.Generator.SkillCheckFail.OnClientEvent, function()
            if State.SkillCheckNotify then Util.Notify("Skill Check Failed","Progress lost!",3) end
        end)
    end
    if R.Generator.GenDone then
        Util.SafeConnect(R.Generator.GenDone.OnClientEvent, function()
            if State.GenDoneNotify then Util.Notify("Gen Complete","One gen done",3) end
        end)
    end
    if R.Generator.AllGenDone then
        Util.SafeConnect(R.Generator.AllGenDone.OnClientEvent, function()
            if State.AllGensNotify then Util.Notify("All Gens Done!","Gates powered!",6) end
        end)
    end
    if R.Chase.Music then
        Util.SafeConnect(R.Chase.Music.OnClientEvent, function()
            if State.ChaseAlert then Util.Notify("Chase Active","Killer chasing",3) end
        end)
    end
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function()
            if State.AttackAlert then Util.Notify("LUNGE!","Attack!",2) end
        end)
    end
    if R.KillerPerks.KingScourge then
        local st = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if st then
            Util.SafeConnect(st.OnClientEvent, function()
                if State.AttackAlert then Util.Notify("KING SCOURGE!","Dodge!",2) end
            end)
        end
    end
    if R.Game.KillerMorph then
        Util.SafeConnect(R.Game.KillerMorph.OnClientEvent, function()
            State.IsKiller = true; Util.Notify("Role","You are KILLER",5)
        end)
    end
    if R.Game.Start then
        Util.SafeConnect(R.Game.Start.OnClientEvent, function()
            State.MatchActive = true; State.IsKiller = false
            Util.Notify("Match Started","Good luck!",3)
        end)
    end
    if R.Game.RoundEnd then
        Util.SafeConnect(R.Game.RoundEnd.OnClientEvent, function()
            State.MatchActive = false; ESP.ClearAll()
        end)
    end
    if R.Game.OneLeft then
        Util.SafeConnect(R.Game.OneLeft.OnClientEvent, function()
            if State.OneLeftNotify then Util.Notify("Last Survivor!","",5) end
        end)
    end
    if R.Game.Death then
        Util.SafeConnect(R.Game.Death.OnClientEvent, function()
            if State.DeathNotify then Util.Notify("Death","A survivor died",3) end
        end)
    end
    if R.Carry.HookEvent then
        Util.SafeConnect(R.Carry.HookEvent.OnClientEvent, function()
            if State.HookNotify then Util.Notify("Hooked","Someone hooked",3) end
        end)
    end
    Util.SafeConnect(LocalPlayer.Idled, function()
        if State.AntiAFK then
            VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- WINDOW
--═══════════════════════════════════════════════════════════════
local Window
local windowSuccess = pcall(function()
    Window = WindUI:CreateWindow({
        Title = HUB.Name,
        Icon = "skull",
        Author = "by "..HUB.Author.." | "..HUB.Game,
        Folder = HUB.Folder,
        Size = UDim2.fromOffset(580,460),
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 160,
        HasOutline = true,
        KeySystem = false,
    })
end)

if not windowSuccess or not Window then
    warn("[X0DEC04T] Window creation failed"); return
end
print("[X0DEC04T] Window created")

--═══════════════════════════════════════════════════════════════
-- TABS
--═══════════════════════════════════════════════════════════════
local Tabs = {}
local tabList = {"Main","Awareness","ESP","Movement","Visuals","Misc","Settings"}

for i, name in ipairs(tabList) do
    local ok, tab = pcall(function() return Window:Tab({ Title = name, Icon = "" }) end)
    if ok and tab then Tabs[name] = tab
    else warn("[X0DEC04T] Tab '"..name.."' failed") end
end

Safe(function() if Window.SelectTab then Window:SelectTab(1) end end, "SelectTab")

--═══════════════════════════════════════════════════════════════
-- MAIN TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Main:Section({ Title = "Welcome" }) end, "Main Sec1")

Safe(function()
    Tabs.Main:Paragraph({
        Title = HUB.Name,
        Desc = "Premium hub for "..HUB.Game.."\nVersion "..HUB.Version.." by "..HUB.Author,
    })
end, "Main P1")

Safe(function()
    Tabs.Main:Paragraph({
        Title = "Focus Areas",
        Desc = "Awareness, ESP, Movement, Visuals",
    })
end, "Main P2")

local killersText = {}
for k,_ in pairs(KNOWN_KILLERS) do table.insert(killersText, k:gsub("^%l",string.upper)) end

Safe(function()
    Tabs.Main:Paragraph({
        Title = "Detected Killers",
        Desc = #killersText > 0 and table.concat(killersText,", ") or "None detected",
    })
end, "Main P3")

Safe(function() Tabs.Main:Section({ Title = "Match Info" }) end, "Main Sec2")

local RoleLabel, MatchLabel
Safe(function() RoleLabel = Tabs.Main:Paragraph({ Title = "Your Role", Desc = "Waiting..." }) end, "Main P4")
Safe(function() MatchLabel = Tabs.Main:Paragraph({ Title = "Match State", Desc = "Waiting..." }) end, "Main P5")

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if RoleLabel and RoleLabel.SetDesc then RoleLabel:SetDesc(State.IsKiller and "KILLER" or "SURVIVOR")
            elseif RoleLabel and RoleLabel.SetTitle then RoleLabel:SetTitle(State.IsKiller and "Role: KILLER" or "Role: SURVIVOR") end
            if MatchLabel and MatchLabel.SetDesc then MatchLabel:SetDesc(State.MatchActive and "In Match" or "Lobby")
            elseif MatchLabel and MatchLabel.SetTitle then MatchLabel:SetTitle(State.MatchActive and "State: In Match" or "State: Lobby") end
        end)
    end
end)

--═══════════════════════════════════════════════════════════════
-- AWARENESS TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Awareness:Section({ Title = "Killer Alerts" }) end, "Aw Sec1")

Safe(function()
    Tabs.Awareness:Toggle({
        Title = "Chase Music Alert",
        Desc = "Alert when chase music plays",
        Default = true,
        Callback = function(v) State.ChaseAlert = v end,
    })
end, "Aw T1")

Safe(function()
    Tabs.Awareness:Toggle({
        Title = "Attack Alert (Lunge/Scourge)",
        Desc = "Alert when killer attacks",
        Default = true,
        Callback = function(v) State.AttackAlert = v end,
    })
end, "Aw T2")

Safe(function() Tabs.Awareness:Section({ Title = "Skill Checks" }) end, "Aw Sec2")

Safe(function()
    Tabs.Awareness:Toggle({ Title = "Gen Skill Check Notify", Default = true,
        Callback = function(v) State.SkillCheckNotify = v end })
end, "Aw T3")

Safe(function()
    Tabs.Awareness:Toggle({ Title = "Heal Skill Check Notify", Default = true,
        Callback = function(v) State.HealSkillNotify = v end })
end, "Aw T4")

Safe(function() Tabs.Awareness:Section({ Title = "Objectives" }) end, "Aw Sec3")

Safe(function() Tabs.Awareness:Toggle({ Title = "Gen Done Notify",    Default = true, Callback = function(v) State.GenDoneNotify = v end }) end, "Aw T5")
Safe(function() Tabs.Awareness:Toggle({ Title = "All Gens Done Notify", Default = true, Callback = function(v) State.AllGensNotify = v end }) end, "Aw T6")
Safe(function() Tabs.Awareness:Toggle({ Title = "Hook Notify",         Default = true, Callback = function(v) State.HookNotify = v end }) end, "Aw T7")
Safe(function() Tabs.Awareness:Toggle({ Title = "Death Notify",        Default = true, Callback = function(v) State.DeathNotify = v end }) end, "Aw T8")
Safe(function() Tabs.Awareness:Toggle({ Title = "Last Survivor Notify",Default = true, Callback = function(v) State.OneLeftNotify = v end }) end, "Aw T9")

--═══════════════════════════════════════════════════════════════
-- ESP TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.ESP:Section({ Title = "Players" }) end, "ESP Sec1")

Safe(function()
    Tabs.ESP:Toggle({
        Title = "Killer ESP", Desc = "Red highlight + name", Default = false,
        Callback = function(v)
            State.ESP_Killer = v
            if not v then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character and Role.IsKiller(plr.Character) then ESP.Clear(plr.Character) end
                end
            end
        end,
    })
end, "ESP T1")

Safe(function()
    Tabs.ESP:Toggle({
        Title = "Survivor ESP", Desc = "Cyan highlight + name", Default = false,
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
end, "ESP T2")

Safe(function() Tabs.ESP:Section({ Title = "Objects" }) end, "ESP Sec2")

Safe(function()
    Tabs.ESP:Toggle({
        Title = "Generator ESP", Desc = "Yellow highlight", Default = false,
        Callback = function(v)
            State.ESP_Generators = v
            if not v and WS.Generators then
                for _, g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end
            end
        end,
    })
end, "ESP T3")

Safe(function() Tabs.ESP:Toggle({ Title = "Item ESP",   Desc = "Green highlight", Default = false, Callback = function(v) State.ESP_Items = v end }) end, "ESP T4")
Safe(function() Tabs.ESP:Toggle({ Title = "Weapon ESP", Desc = "Pink highlight",  Default = false,
    Callback = function(v) State.ESP_Weapons = v; if not v and WS.Weapons then for _,w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end end end }) end, "ESP T5")
Safe(function() Tabs.ESP:Toggle({ Title = "Clone ESP",  Desc = "Gray highlight",  Default = false,
    Callback = function(v) State.ESP_Clones = v; if not v and WS.Clones then for _,c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end end end }) end, "ESP T6")

Safe(function() Tabs.ESP:Section({ Title = "Display" }) end, "ESP Sec3")

Safe(function()
    Tabs.ESP:Toggle({ Title = "Show Name", Default = true,
        Callback = function(v)
            State.ESP_ShowName = v
            for _, cache in pairs(State.ESPCache) do
                if cache.nameLabel then cache.nameLabel.Visible = v end
            end
        end })
end, "ESP T7")

Safe(function()
    Tabs.ESP:Toggle({ Title = "Show Distance", Default = true,
        Callback = function(v)
            State.ESP_ShowDistance = v
            for _, cache in pairs(State.ESPCache) do
                if cache.distLabel then cache.distLabel.Visible = v end
            end
        end })
end, "ESP T8")

Safe(function()
    Tabs.ESP:Slider({
        Title = "Max Distance",
        Value = { Min = 50, Max = 2000, Default = 500 },
        Step = 50,
        Callback = function(v)
            local num = tonumber(v) or 500
            State.ESP_MaxDistance = num
            for _, cache in pairs(State.ESPCache) do
                if cache.billboard then cache.billboard.MaxDistance = num end
            end
        end,
    })
end, "ESP Slider")

Safe(function() Tabs.ESP:Button({ Title = "Refresh All ESP", Callback = function() ESP.ClearAll(); ESP.RefreshAll(); Util.Notify("ESP","Refreshed",2) end }) end, "ESP B1")
Safe(function() Tabs.ESP:Button({ Title = "Clear All ESP",   Callback = function() ESP.ClearAll(); Util.Notify("ESP","Cleared",2) end }) end, "ESP B2")

--═══════════════════════════════════════════════════════════════
-- MOVEMENT TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Movement:Section({ Title = "Speed" }) end, "Mv Sec1")

Safe(function()
    Tabs.Movement:Slider({
        Title = "WalkSpeed",
        Value = { Min = 16, Max = 100, Default = 16 },
        Step = 1,
        Callback = function(v)
            State.WalkSpeed = tonumber(v) or 16
            Movement.ApplyWalkSpeed()
        end,
    })
end, "Mv Slider1")

Safe(function()
    Tabs.Movement:Slider({
        Title = "JumpPower",
        Value = { Min = 50, Max = 200, Default = 50 },
        Step = 1,
        Callback = function(v)
            State.JumpPower = tonumber(v) or 50
            Movement.ApplyJumpPower()
        end,
    })
end, "Mv Slider2")

Safe(function() Tabs.Movement:Section({ Title = "Advanced" }) end, "Mv Sec2")

Safe(function()
    Tabs.Movement:Toggle({ Title = "NoClip", Desc = "Walk through walls", Default = false,
        Callback = function(v) State.NoClip = v; Movement.SetNoClip(v) end })
end, "Mv T1")

Safe(function()
    Tabs.Movement:Toggle({ Title = "Infinite Jump", Desc = "Jump mid-air", Default = false,
        Callback = function(v) State.InfJump = v; Movement.SetInfJump(v) end })
end, "Mv T2")

Safe(function() Tabs.Movement:Section({ Title = "Teleport" }) end, "Mv Sec3")

Safe(function()
    Tabs.Movement:Button({ Title = "TP to Nearest Generator",
        Callback = Movement.TeleportToNearestGenerator })
end, "Mv B1")

local teleTargetName = ""
Safe(function()
    Tabs.Movement:Input({
        Title = "Target Player Name",
        Desc = "Case-sensitive",
        Value = "",
        Placeholder = "PlayerName",
        Callback = function(v) teleTargetName = tostring(v or "") end,
    })
end, "Mv Input")

Safe(function()
    Tabs.Movement:Button({ Title = "TP to Target",
        Callback = function()
            if teleTargetName ~= "" then Movement.TeleportToPlayer(teleTargetName)
            else Util.Notify("TP","Enter name first",3) end
        end })
end, "Mv B2")

--═══════════════════════════════════════════════════════════════
-- VISUALS TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Visuals:Section({ Title = "Lighting" }) end, "V Sec1")

Safe(function() Tabs.Visuals:Toggle({ Title="FullBright", Desc="Max brightness", Default=false,
    Callback=function(v) State.FullBright=v; Misc.SetFullBright(v) end }) end, "V T1")
Safe(function() Tabs.Visuals:Toggle({ Title="No Fog", Desc="Remove fog", Default=false,
    Callback=function(v) State.NoFog=v; Misc.SetNoFog(v) end }) end, "V T2")
Safe(function() Tabs.Visuals:Toggle({ Title="No Shadows", Desc="Disable shadows", Default=false,
    Callback=function(v) State.NoShadows=v; Misc.SetNoShadows(v) end }) end, "V T3")
Safe(function() Tabs.Visuals:Toggle({ Title="Clear Weather", Desc="Remove haze/rain", Default=false,
    Callback=function(v) State.ClearWeather=v; Misc.SetClearWeather(v) end }) end, "V T4")

Safe(function()
    Tabs.Visuals:Slider({
        Title = "Time of Day",
        Value = { Min = 0, Max = 24, Default = 14 },
        Step = 1,
        Callback = function(v) State.Time = tonumber(v) or 14; Misc.SetTime(State.Time) end,
    })
end, "V Slider1")

Safe(function() Tabs.Visuals:Section({ Title = "Camera" }) end, "V Sec2")

Safe(function()
    Tabs.Visuals:Slider({
        Title = "FOV",
        Value = { Min = 30, Max = 120, Default = 70 },
        Step = 5,
        Callback = function(v) State.FOV = tonumber(v) or 70; Misc.SetFOV(State.FOV) end,
    })
end, "V Slider2")

Safe(function() Tabs.Visuals:Toggle({ Title="Freecam", Desc="WASD + Space/Ctrl", Default=false,
    Callback=function(v) State.Freecam=v; Misc.SetFreecam(v) end }) end, "V T5")

Safe(function() Tabs.Visuals:Section({ Title = "Post-FX" }) end, "V Sec3")

Safe(function() Tabs.Visuals:Toggle({ Title="Remove Blur/Bloom/DOF", Default=false,
    Callback=function(v) State.RemoveBlur=v; Misc.RemovePostFX(v) end }) end, "V T6")
Safe(function() Tabs.Visuals:Toggle({ Title="Remove Color Correction", Default=false,
    Callback=function(v) State.RemoveColorCorr=v; Misc.RemoveColorCorrection(v) end }) end, "V T7")
Safe(function() Tabs.Visuals:Toggle({ Title="No Particles", Default=false,
    Callback=function(v) State.NoParticles=v; Misc.SetNoParticles(v) end }) end, "V T8")

Safe(function() Tabs.Visuals:Section({ Title = "Performance" }) end, "V Sec4")

Safe(function() Tabs.Visuals:Toggle({ Title="Low Graphics", Desc="FPS boost", Default=false,
    Callback=function(v) State.LowGraphics=v; Misc.SetLowGraphics(v) end }) end, "V T9")

--═══════════════════════════════════════════════════════════════
-- MISC TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Misc:Section({ Title = "Audio" }) end, "M Sec1")

Safe(function() Tabs.Misc:Toggle({ Title="Mute All Sounds", Default=false,
    Callback=function(v) State.NoSound=v; Misc.SetNoSound(v) end }) end, "M T1")
Safe(function() Tabs.Misc:Toggle({ Title="Mute BG Music", Default=false,
    Callback=function(v) State.MuteBGMusic=v; Misc.SetMuteBGMusic(v) end }) end, "M T2")

Safe(function() Tabs.Misc:Section({ Title = "Character" }) end, "M Sec2")

Safe(function() Tabs.Misc:Toggle({ Title="Hide Own Name", Default=false,
    Callback=function(v) State.HideName=v; Misc.SetHideName(v) end }) end, "M T3")

Safe(function() Tabs.Misc:Section({ Title = "Automation" }) end, "M Sec3")

Safe(function() Tabs.Misc:Toggle({ Title="Auto Rejoin on Kick", Default=false,
    Callback=function(v) State.AutoRejoin=v end }) end, "M T4")

Safe(function() Tabs.Misc:Button({ Title="Server Hop", Callback=Misc.ServerHop }) end, "M B1")

Safe(function() Tabs.Misc:Button({ Title="Copy JobId",
    Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Util.Notify("Copied","JobId",3)
        else Util.Notify("Err","No clipboard",3) end
    end }) end, "M B2")

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
--═══════════════════════════════════════════════════════════════
Safe(function() Tabs.Settings:Section({ Title = "Anti-AFK" }) end, "S Sec1")

Safe(function() Tabs.Settings:Toggle({ Title="Anti-AFK", Desc="Prevents idle kick", Default=true,
    Callback=function(v) State.AntiAFK=v end }) end, "S T1")

Safe(function() Tabs.Settings:Section({ Title = "Theme" }) end, "S Sec2")

Safe(function()
    Tabs.Settings:Dropdown({
        Title = "Theme",
        Values = {"Dark","Light"},
        Value = "Dark",
        Callback = function(v)
            local t = typeof(v) == "table" and v[1] or tostring(v)
            pcall(function() WindUI:SetTheme(t) end)
        end,
    })
end, "S Dropdown")

Safe(function() Tabs.Settings:Section({ Title = "Keybinds" }) end, "S Sec3")

Safe(function() Tabs.Settings:Keybind({ Title="Toggle UI", Value="RightShift",
    Callback=function() pcall(function() Window:Toggle() end) end }) end, "S K1")

Safe(function() Tabs.Settings:Keybind({ Title="Panic ESP", Value="End",
    Callback=function()
        State.ESP_Killer=false; State.ESP_Survivors=false; State.ESP_Generators=false
        State.ESP_Items=false; State.ESP_Weapons=false; State.ESP_Clones=false
        ESP.ClearAll(); Util.Notify("Panic","ESP disabled",3)
    end }) end, "S K2")

Safe(function() Tabs.Settings:Section({ Title = "Info" }) end, "S Sec4")

Safe(function() Tabs.Settings:Paragraph({
    Title = "Credits",
    Desc = "By "..HUB.Author.." | v"..HUB.Version.."\nGame: "..HUB.Game,
}) end, "S P1")

Safe(function() Tabs.Settings:Button({ Title="Unload Hub",
    Callback=function()
        for _, c in ipairs(State.Connections) do pcall(function() c:Disconnect() end) end
        if State.NoClipConn then pcall(function() State.NoClipConn:Disconnect() end) end
        if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
        if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
        for k,v in pairs(State.LightingBackup) do pcall(function() Lighting[k]=v end) end
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end }) end, "S B1")

--═══════════════════════════════════════════════════════════════
-- INITIALIZATION
--═══════════════════════════════════════════════════════════════
print("[X0DEC04T] Setting up awareness...")
Awareness.Setup()

print("[X0DEC04T] Setting up auto-rejoin...")
Misc.AutoRejoin()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Movement.ApplyWalkSpeed(); Movement.ApplyJumpPower()
    if State.NoClip then Movement.SetNoClip(true) end
    if State.FullBright then Misc.SetFullBright(true) end
    if State.NoFog then Misc.SetNoFog(true) end
    if State.HideName then Misc.SetHideName(true) end
    if State.FOV ~= 70 then Misc.SetFOV(State.FOV) end
end)

task.spawn(function()
    while task.wait(5) do
        if State.FullBright then Misc.SetFullBright(true) end
        if State.NoFog then Misc.SetNoFog(true) end
        if State.NoShadows then Misc.SetNoShadows(true) end
    end
end)

Util.Notify(HUB.Name, "Loaded v"..HUB.Version, 5)
print("[X0DEC04T] Fully loaded")
