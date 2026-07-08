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

local LocalPlayer = Players.LocalPlayer

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
    Version = "0.0.2",
    Author  = "voixera",
    Folder  = "X0DEC04T_Hub",
    LogoID  = "rbxassetid://91626851418651",
}

--═══════════════════════════════════════════════════════════════
-- REMOTE REFERENCES (listeners only)
--═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local R = {
    Generator = {
        SkillCheck        = Remotes.Generator:FindFirstChild("SkillCheckEvent"),
        SkillCheckFail    = Remotes.Generator:FindFirstChild("SkillCheckFailEvent"),
        GenDone           = Remotes.Generator:FindFirstChild("GenDone"),
        AllGenDone        = Remotes.Generator:FindFirstChild("allgendone"),
        EscapeTime        = Remotes.Generator:FindFirstChild("Escapetime"),
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
    Generators = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Generators"),
    Mazes      = Workspace:FindFirstChild("Mazes"),
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
    Lobby      = Workspace:FindFirstChild("Lobby"),
}

--═══════════════════════════════════════════════════════════════
-- STATE
--═══════════════════════════════════════════════════════════════
local State = {
    -- Awareness
    ChaseAlert         = true,
    AttackAlert        = true,
    SkillCheckNotify   = true,
    HealSkillNotify    = true,
    GenDoneNotify      = true,
    AllGensNotify      = true,
    OneLeftNotify      = true,
    HookNotify         = true,
    DeathNotify        = true,

    -- ESP
    ESP_Generators     = false,
    ESP_Killer         = false,
    ESP_Survivors      = false,
    ESP_Items          = false,
    ESP_Weapons        = false,
    ESP_Clones         = false,
    ESP_MaxDistance    = 500,

    -- Movement
    WalkSpeed          = 16,
    JumpPower          = 50,
    NoClip             = false,
    InfJump            = false,

    -- Anti-AFK
    AntiAFK            = true,

    -- Runtime
    IsKiller           = false,
    MatchActive        = false,
    ESPObjects         = {},
    Connections        = {},
    NoClipConn         = nil,
    InfJumpConn        = nil,
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
    WindUI:Notify({
        Title    = title or HUB.Name,
        Content  = content or "",
        Duration = duration or 4,
        Icon     = "bell",
    })
end

function Util.GetGuiParent()
    local parent = CoreGui
    pcall(function() if gethui then parent = gethui() end end)
    return parent
end

function Util.CleanupESP()
    for _, obj in pairs(State.ESPObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    State.ESPObjects = {}
end

--═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
--═══════════════════════════════════════════════════════════════
local ESP = {}

function ESP.CreateTag(adornee, text, color)
    if not adornee then return end

    -- Try to attach to primary part
    local part = adornee
    if adornee:IsA("Model") then
        part = adornee.PrimaryPart
              or adornee:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end

    local bb = Instance.new("BillboardGui")
    bb.Name           = "X0DEC_ESP"
    bb.Adornee        = part
    bb.Size           = UDim2.new(0, 180, 0, 50)
    bb.StudsOffset    = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = State.ESP_MaxDistance
    bb.Parent         = Util.GetGuiParent()

    local frame = Instance.new("Frame")
    frame.Size                   = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent                 = bb

    local label = Instance.new("TextLabel")
    label.Size                   = UDim2.new(1, 0, 0.6, 0)
    label.BackgroundTransparency = 1
    label.Text                   = text
    label.TextColor3             = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3       = Color3.new(0, 0, 0)
    label.Font                   = Enum.Font.GothamBold
    label.TextSize               = 14
    label.Parent                 = frame

    local distLabel = Instance.new("TextLabel")
    distLabel.Name                   = "Distance"
    distLabel.Size                   = UDim2.new(1, 0, 0.4, 0)
    distLabel.Position               = UDim2.new(0, 0, 0.6, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Text                   = "0m"
    distLabel.TextColor3             = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font                   = Enum.Font.Gotham
    distLabel.TextSize               = 12
    distLabel.Parent                 = frame

    table.insert(State.ESPObjects, bb)
    return bb, label, distLabel
end

function ESP.UpdateDistances()
    local hrp = Util.GetHRP()
    if not hrp then return end

    for _, bb in ipairs(State.ESPObjects) do
        if bb.Parent and bb.Adornee then
            local dist = (bb.Adornee.Position - hrp.Position).Magnitude
            local distLabel = bb:FindFirstChild("Distance", true)
            if distLabel then
                distLabel.Text = math.floor(dist) .. "m"
            end
        end
    end
end

function ESP.ScanGenerators()
    if not State.ESP_Generators or not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        ESP.CreateTag(gen, "⚡ Generator: " .. gen.Name, Color3.fromRGB(255, 200, 60))
    end
end

function ESP.ScanPlayers()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local isKiller = plr.Character:GetAttribute("Killer")
                          or plr.Character:GetAttribute("IsKiller")
                          or plr.Character.Name:lower():match("killer")

            if isKiller and State.ESP_Killer then
                ESP.CreateTag(plr.Character, "☠ KILLER: " .. plr.Name, Color3.fromRGB(255, 60, 60))
            elseif not isKiller and State.ESP_Survivors then
                ESP.CreateTag(plr.Character, "◈ " .. plr.Name, Color3.fromRGB(60, 200, 255))
            end
        end
    end
end

function ESP.ScanItems()
    if not State.ESP_Items then return end
    local itemsFolder = ReplicatedStorage:FindFirstChild("Items")
    -- Ground items: check Workspace for spawned pickups
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and (obj:GetAttribute("Item") or obj:GetAttribute("Pickup")) then
            ESP.CreateTag(obj, "🎒 " .. obj.Name, Color3.fromRGB(180, 255, 100))
        end
    end
end

function ESP.ScanWeapons()
    if not State.ESP_Weapons or not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetDescendants()) do
        if w:IsA("Model") or (w:IsA("BasePart") and w.Name:lower():match("weapon")) then
            ESP.CreateTag(w, "⚔ " .. w.Name, Color3.fromRGB(255, 100, 200))
        end
    end
end

function ESP.ScanClones()
    if not State.ESP_Clones or not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        ESP.CreateTag(c, "👥 Clone", Color3.fromRGB(150, 150, 255))
    end
end

function ESP.RefreshAll()
    Util.CleanupESP()
    ESP.ScanGenerators()
    ESP.ScanPlayers()
    ESP.ScanItems()
    ESP.ScanWeapons()
    ESP.ScanClones()
end

-- Auto refresh
task.spawn(function()
    while true do
        task.wait(2)
        if State.ESP_Generators or State.ESP_Killer or State.ESP_Survivors
        or State.ESP_Items or State.ESP_Weapons or State.ESP_Clones then
            ESP.RefreshAll()
        end
    end
end)

-- Distance updater
RunService.Heartbeat:Connect(function()
    ESP.UpdateDistances()
end)

--═══════════════════════════════════════════════════════════════
-- MOVEMENT FEATURES
--═══════════════════════════════════════════════════════════════
local Movement = {}

function Movement.ApplyWalkSpeed()
    local hum = Util.GetHumanoid()
    if hum then hum.WalkSpeed = State.WalkSpeed end
end

function Movement.ApplyJumpPower()
    local hum = Util.GetHumanoid()
    if hum then
        hum.JumpPower = State.JumpPower
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
        Util.Notify("Teleport", "Sent to nearest generator (" .. math.floor(minDist) .. "m)", 3)
    else
        Util.Notify("Teleport", "No generators found", 3)
    end
end

function Movement.TeleportToPlayer(playerName)
    local target = Players:FindFirstChild(playerName)
    if not target or not target.Character then
        Util.Notify("Teleport", "Player not found", 3)
        return
    end
    local hrp = Util.GetHRP()
    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if hrp and targetHRP then
        hrp.CFrame = targetHRP.CFrame + Vector3.new(0, 0, 3)
        Util.Notify("Teleport", "Sent to " .. playerName, 3)
    end
end

--═══════════════════════════════════════════════════════════════
-- AWARENESS LISTENERS
--═══════════════════════════════════════════════════════════════
local Awareness = {}

function Awareness.Setup()
    -- Skill Check Notifications
    if R.Generator.SkillCheck then
        Util.SafeConnect(R.Generator.SkillCheck.OnClientEvent, function(gen, point, kind, difficulty)
            if State.SkillCheckNotify then
                Util.Notify("⚡ Skill Check!",
                    "Difficulty: " .. tostring(difficulty or "?"), 2)
            end
        end)
    end

    if R.Healing.SkillCheck then
        Util.SafeConnect(R.Healing.SkillCheck.OnClientEvent, function(...)
            if State.HealSkillNotify then
                Util.Notify("❤ Heal Skill Check!", "Complete the check", 2)
            end
        end)
    end

    -- Skill check failure
    if R.Generator.SkillCheckFail then
        Util.SafeConnect(R.Generator.SkillCheckFail.OnClientEvent, function(...)
            if State.SkillCheckNotify then
                Util.Notify("✗ Skill Check Failed", "Generator progress lost!", 3)
            end
        end)
    end

    -- Gen done
    if R.Generator.GenDone then
        Util.SafeConnect(R.Generator.GenDone.OnClientEvent, function(...)
            if State.GenDoneNotify then
                Util.Notify("✓ Generator Complete!", "One gen done", 3)
            end
        end)
    end

    -- All gens done
    if R.Generator.AllGenDone then
        Util.SafeConnect(R.Generator.AllGenDone.OnClientEvent, function(...)
            if State.AllGensNotify then
                Util.Notify("🚪 All Gens Done!", "Escape gates are powered!", 6)
            end
        end)
    end

    -- Chase music
    if R.Chase.Music then
        Util.SafeConnect(R.Chase.Music.OnClientEvent, function(...)
            if State.ChaseAlert then
                Util.Notify("⚠ Chase Active", "Killer is chasing someone", 3)
            end
        end)
    end

    -- Attack alerts
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function(...)
            if State.AttackAlert then
                Util.Notify("⚠ LUNGE!", "Killer is attacking!", 2)
            end
        end)
    end

    if R.KillerPerks.KingScourge then
        local start = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if start then
            Util.SafeConnect(start.OnClientEvent, function(...)
                if State.AttackAlert then
                    Util.Notify("⚠ KING SCOURGE!", "Dodge NOW!", 2)
                end
            end)
        end
    end

    -- Killer detection
    if R.Game.KillerMorph then
        Util.SafeConnect(R.Game.KillerMorph.OnClientEvent, function(...)
            State.IsKiller = true
            Util.Notify("Role", "You are the KILLER", 5)
        end)
    end

    -- Match state
    if R.Game.Start then
        Util.SafeConnect(R.Game.Start.OnClientEvent, function(...)
            State.MatchActive = true
            State.IsKiller = false
            Util.Notify("Match Started", "Good luck!", 3)
        end)
    end

    if R.Game.RoundEnd then
        Util.SafeConnect(R.Game.RoundEnd.OnClientEvent, function(...)
            State.MatchActive = false
            Util.CleanupESP()
        end)
    end

    -- One left
    if R.Game.OneLeft then
        Util.SafeConnect(R.Game.OneLeft.OnClientEvent, function(...)
            if State.OneLeftNotify then
                Util.Notify("⚠ Last Survivor!", "You are alone", 5)
            end
        end)
    end

    -- Death
    if R.Game.Death then
        Util.SafeConnect(R.Game.Death.OnClientEvent, function(...)
            if State.DeathNotify then
                Util.Notify("💀 Death", "A survivor has died", 3)
            end
        end)
    end

    -- Hooks
    if R.Carry.HookEvent then
        Util.SafeConnect(R.Carry.HookEvent.OnClientEvent, function(...)
            if State.HookNotify then
                Util.Notify("🪝 Hooked", "Someone was hooked", 3)
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
-- WINDOW
--═══════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
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
        if Window.Open then Window:Open()
        elseif Window.SetVisibility then Window:SetVisibility(true)
        else Window:Toggle() end
    end)
end

function Launcher:MinimizeWindow()
    pcall(function()
        if Window.Close then Window:Close()
        elseif Window.SetVisibility then Window:SetVisibility(false)
        else Window:Toggle() end
    end)
    self:Show()
end

pcall(function()
    if Window.OnClose then Window:OnClose(function() Launcher:MinimizeWindow() end) end
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
-- TABS
--═══════════════════════════════════════════════════════════════
local Tabs = {
    Main      = Window:Tab({ Title = "Main",      Icon = "home"       }),
    Awareness = Window:Tab({ Title = "Awareness", Icon = "bell"       }),
    ESP       = Window:Tab({ Title = "ESP",       Icon = "eye"        }),
    Movement  = Window:Tab({ Title = "Movement",  Icon = "footprints" }),
    Settings  = Window:Tab({ Title = "Settings",  Icon = "settings"   }),
}
Window:SelectTab(1)

--═══════════════════════════════════════════════════════════════
-- MAIN TAB
--═══════════════════════════════════════════════════════════════
Tabs.Main:Section({ Title = "Welcome" })

Tabs.Main:Paragraph({
    Title = HUB.Name,
    Desc  = "Premium hub for " .. HUB.Game .. "\nVersion " .. HUB.Version .. " by " .. HUB.Author,
})

Tabs.Main:Paragraph({
    Title = "⚠ Game Architecture Notice",
    Desc  = "This game uses server-authoritative proximity interactions. Auto-Repair/Heal features are not possible via remotes. This hub focuses on Awareness, ESP, and Movement.",
})

Tabs.Main:Section({ Title = "Match Info" })

local RoleLabel = Tabs.Main:Paragraph({ Title = "Your Role", Desc = "Waiting..." })
local MatchLabel = Tabs.Main:Paragraph({ Title = "Match State", Desc = "Waiting..." })

task.spawn(function()
    while true do
        pcall(function()
            RoleLabel:SetDesc(State.IsKiller and "🔪 KILLER" or "🏃 SURVIVOR")
            MatchLabel:SetDesc(State.MatchActive and "🟢 In Match" or "🔴 Lobby")
        end)
        task.wait(1)
    end
end)

--═══════════════════════════════════════════════════════════════
-- AWARENESS TAB
--═══════════════════════════════════════════════════════════════
Tabs.Awareness:Section({ Title = "Killer Alerts" })

Tabs.Awareness:Toggle({
    Title = "Chase Music Alert",
    Desc  = "Alert when chase music plays",
    Value = true,
    Callback = function(v) State.ChaseAlert = v end,
})

Tabs.Awareness:Toggle({
    Title = "Attack Alert (Lunge / King Scourge)",
    Desc  = "Alert when killer uses attack",
    Value = true,
    Callback = function(v) State.AttackAlert = v end,
})

Tabs.Awareness:Section({ Title = "Skill Checks" })

Tabs.Awareness:Toggle({
    Title = "Generator Skill Check Notify",
    Desc  = "Alert with difficulty when a skill check spawns",
    Value = true,
    Callback = function(v) State.SkillCheckNotify = v end,
})

Tabs.Awareness:Toggle({
    Title = "Healing Skill Check Notify",
    Desc  = "Alert when heal skill check appears",
    Value = true,
    Callback = function(v) State.HealSkillNotify = v end,
})

Tabs.Awareness:Section({ Title = "Objectives" })

Tabs.Awareness:Toggle({
    Title = "Generator Done Notify",
    Value = true,
    Callback = function(v) State.GenDoneNotify = v end,
})

Tabs.Awareness:Toggle({
    Title = "All Gens Done Notify",
    Desc  = "Big alert when escape opens",
    Value = true,
    Callback = function(v) State.AllGensNotify = v end,
})

Tabs.Awareness:Toggle({
    Title = "Hook Notify",
    Desc  = "Alert when someone gets hooked",
    Value = true,
    Callback = function(v) State.HookNotify = v end,
})

Tabs.Awareness:Toggle({
    Title = "Death Notify",
    Value = true,
    Callback = function(v) State.DeathNotify = v end,
})

Tabs.Awareness:Toggle({
    Title = "Last Survivor Notify",
    Value = true,
    Callback = function(v) State.OneLeftNotify = v end,
})

--═══════════════════════════════════════════════════════════════
-- ESP TAB
--═══════════════════════════════════════════════════════════════
Tabs.ESP:Section({ Title = "Players" })

Tabs.ESP:Toggle({
    Title = "Killer ESP",
    Desc  = "Red highlight on killer",
    Value = false,
    Callback = function(v) State.ESP_Killer = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Survivor ESP",
    Desc  = "Blue highlight on teammates",
    Value = false,
    Callback = function(v) State.ESP_Survivors = v; ESP.RefreshAll() end,
})

Tabs.ESP:Section({ Title = "Objectives" })

Tabs.ESP:Toggle({
    Title = "Generator ESP",
    Desc  = "Show all generators",
    Value = false,
    Callback = function(v) State.ESP_Generators = v; ESP.RefreshAll() end,
})

Tabs.ESP:Section({ Title = "Items & Weapons" })

Tabs.ESP:Toggle({
    Title = "Item ESP",
    Desc  = "Show ground items",
    Value = false,
    Callback = function(v) State.ESP_Items = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Weapon ESP",
    Desc  = "Show weapons",
    Value = false,
    Callback = function(v) State.ESP_Weapons = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Clone ESP",
    Desc  = "Show shadow clones",
    Value = false,
    Callback = function(v) State.ESP_Clones = v; ESP.RefreshAll() end,
})

Tabs.ESP:Section({ Title = "Settings" })

Tabs.ESP:Slider({
    Title = "Max Distance",
    Value = { Min = 50, Max = 2000, Default = 500 },
    Callback = function(v)
        State.ESP_MaxDistance = v
        for _, bb in ipairs(State.ESPObjects) do
            if bb.Parent then bb.MaxDistance = v end
        end
    end,
})

Tabs.ESP:Button({
    Title = "Refresh ESP",
    Callback = function()
        ESP.RefreshAll()
        Util.Notify("ESP", "Refreshed", 2)
    end,
})

--═══════════════════════════════════════════════════════════════
-- MOVEMENT TAB
--═══════════════════════════════════════════════════════════════
Tabs.Movement:Section({ Title = "Speed" })

Tabs.Movement:Slider({
    Title = "WalkSpeed",
    Value = { Min = 16, Max = 100, Default = 16 },
    Callback = function(v)
        State.WalkSpeed = v
        Movement.ApplyWalkSpeed()
    end,
})

Tabs.Movement:Slider({
    Title = "JumpPower",
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(v)
        State.JumpPower = v
        Movement.ApplyJumpPower()
    end,
})

Tabs.Movement:Section({ Title = "Advanced" })

Tabs.Movement:Toggle({
    Title = "NoClip",
    Desc  = "Walk through walls",
    Value = false,
    Callback = function(v)
        State.NoClip = v
        Movement.SetNoClip(v)
    end,
})

Tabs.Movement:Toggle({
    Title = "Infinite Jump",
    Desc  = "Jump mid-air",
    Value = false,
    Callback = function(v)
        State.InfJump = v
        Movement.SetInfJump(v)
    end,
})

Tabs.Movement:Section({ Title = "Teleport" })

Tabs.Movement:Button({
    Title = "Teleport to Nearest Generator",
    Callback = Movement.TeleportToNearestGenerator,
})

local selectedPlayer = ""
Tabs.Movement:Dropdown({
    Title = "Select Player",
    Values = (function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        return names
    end)(),
    Callback = function(v) selectedPlayer = v end,
})

Tabs.Movement:Button({
    Title = "Teleport to Selected Player",
    Callback = function()
        if selectedPlayer ~= "" then Movement.TeleportToPlayer(selectedPlayer) end
    end,
})

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
--═══════════════════════════════════════════════════════════════
Tabs.Settings:Section({ Title = "Anti-AFK" })

Tabs.Settings:Toggle({
    Title = "Anti-AFK",
    Desc  = "Prevent idle disconnect",
    Value = true,
    Callback = function(v) State.AntiAFK = v end,
})

Tabs.Settings:Section({ Title = "Theme" })

Tabs.Settings:Dropdown({
    Title  = "Theme",
    Values = { "Dark", "Light", "Rose", "Blood", "Midnight" },
    Value  = "Dark",
    Callback = function(v)
        pcall(function() WindUI:SetTheme(v) end)
    end,
})

Tabs.Settings:Section({ Title = "Config" })

local ConfigMgr = Window.ConfigManager and Window.ConfigManager:CreateConfig("default")

Tabs.Settings:Button({
    Title = "Save Config",
    Callback = function()
        if ConfigMgr then
            ConfigMgr:Save()
            Util.Notify("Config", "Saved", 3)
        end
    end,
})

Tabs.Settings:Button({
    Title = "Load Config",
    Callback = function()
        if ConfigMgr then
            ConfigMgr:Load()
            Util.Notify("Config", "Loaded", 3)
        end
    end,
})

Tabs.Settings:Section({ Title = "Keybinds" })

Tabs.Settings:Keybind({
    Title = "Toggle UI",
    Value = "RightShift",
    Callback = function()
        pcall(function() Window:Toggle() end)
    end,
})

Tabs.Settings:Keybind({
    Title = "Panic Disable ESP",
    Value = "End",
    Callback = function()
        State.ESP_Killer = false
        State.ESP_Survivors = false
        State.ESP_Generators = false
        State.ESP_Items = false
        State.ESP_Weapons = false
        State.ESP_Clones = false
        Util.CleanupESP()
        Util.Notify("PANIC", "All ESP disabled", 3)
    end,
})

Tabs.Settings:Section({ Title = "Info" })

Tabs.Settings:Paragraph({
    Title = "Credits",
    Desc  = "Created by " .. HUB.Author .. "\nVersion " .. HUB.Version .. "\nGame: " .. HUB.Game,
})

Tabs.Settings:Button({
    Title = "Unload Hub",
    Callback = function()
        for _, conn in ipairs(State.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        if State.NoClipConn then State.NoClipConn:Disconnect() end
        if State.InfJumpConn then State.InfJumpConn:Disconnect() end
        Util.CleanupESP()
        if Launcher.Gui then Launcher.Gui:Destroy() end
        Window:Destroy()
    end,
})

--═══════════════════════════════════════════════════════════════
-- INITIALIZATION
--═══════════════════════════════════════════════════════════════
Awareness.Setup()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Movement.ApplyWalkSpeed()
    Movement.ApplyJumpPower()
    if State.NoClip then Movement.SetNoClip(true) end
end)

Util.Notify(HUB.Name, "Loaded v" .. HUB.Version, 5)
print("[X0DEC04T] Production hub loaded")
