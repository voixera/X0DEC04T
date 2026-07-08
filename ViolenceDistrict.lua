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
    Version = "0.0.1",
    Author  = "voixera",
    Folder  = "X0DEC04T_Hub",
    ConfigFolder = "X0DEC04T_Hub/Configs",
    LogoID  = "rbxassetid://91626851418651",
}

--═══════════════════════════════════════════════════════════════
-- REMOTE REFERENCES
--═══════════════════════════════════════════════════════════════
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local R = {
    Generator = {
        Repair            = Remotes.Generator:FindFirstChild("RepairEvent"),
        RepairAnim        = Remotes.Generator:FindFirstChild("RepairAnim"),
        RepairVFX         = Remotes.Generator:FindFirstChild("RepairVFX"),
        SkillCheck        = Remotes.Generator:FindFirstChild("SkillCheckEvent"),
        SkillCheckResult  = Remotes.Generator:FindFirstChild("SkillCheckResultEvent"),
        SkillCheckFail    = Remotes.Generator:FindFirstChild("SkillCheckFailEvent"),
        SkillCheckValid   = Remotes.Generator:FindFirstChild("Skillcheckvalidated"),
        GenDone           = Remotes.Generator:FindFirstChild("GenDone"),
        AllGenDone        = Remotes.Generator:FindFirstChild("allgendone"),
        EscapeTime        = Remotes.Generator:FindFirstChild("Escapetime"),
        BreakGenAnim      = Remotes.Generator:FindFirstChild("BreakGenAnim"),
        BreakGenCommit    = Remotes.Generator:FindFirstChild("BreakGenCommit"),
        BreakGenEvent     = Remotes.Generator:FindFirstChild("BreakGenEvent"),
        BreakGenReject    = Remotes.Generator:FindFirstChild("BreakGenReject"),
    },

    Exit = {
        LeverEvent = Remotes.Exit:FindFirstChild("LeverEvent"),
        LeverAnim  = Remotes.Exit:FindFirstChild("LeverAnim"),
        Gate       = Remotes.Exit:FindFirstChild("gate"),
    },

    Healing = {
        HealEvent         = Remotes.Healing:FindFirstChild("HealEvent"),
        HealAnim          = Remotes.Healing:FindFirstChild("HealAnim"),
        HealAnimRec       = Remotes.Healing:FindFirstChild("HealAnimRec"),
        HealDone          = Remotes.Healing:FindFirstChild("Healdone"),
        StopHealing       = Remotes.Healing:FindFirstChild("Stophealing"),
        Reset             = Remotes.Healing:FindFirstChild("Reset"),
        DisplayBlood      = Remotes.Healing:FindFirstChild("DisplayBlood"),
        SkillCheck        = Remotes.Healing:FindFirstChild("SkillCheckEvent"),
        SkillCheckResult  = Remotes.Healing:FindFirstChild("SkillCheckResultEvent"),
        SkillCheckFail    = Remotes.Healing:FindFirstChild("SkillCheckFailEvent"),
        SkillCheckValid   = Remotes.Healing:FindFirstChild("Skillcheckvalidated"),
    },

    Carry = {
        PlayAnimation       = Remotes.Carry:FindFirstChild("PlayAnimation"),
        CarryAnim           = Remotes.Carry:FindFirstChild("CarryAnim"),
        CarrySurvivor       = Remotes.Carry:FindFirstChild("CarrySurvivorEvent"),
        DropSurvivor        = Remotes.Carry:FindFirstChild("DropSurvivorEvent"),
        GetCarriedAnim      = Remotes.Carry:FindFirstChild("GetCarriedAnim"),
        HookCommit          = Remotes.Carry:FindFirstChild("HookCommit"),
        HookEvent           = Remotes.Carry:FindFirstChild("HookEvent"),
        HookSuccess         = Remotes.Carry:FindFirstChild("HookEventsucceess"),
        HookPhase           = Remotes.Carry:FindFirstChild("HookPhase"),
        HookReject          = Remotes.Carry:FindFirstChild("HookReject"),
        SelfUnhook          = Remotes.Carry:FindFirstChild("SelfUnHookEvent"),
        Unhook              = Remotes.Carry:FindFirstChild("UnHookEvent"),
        UnhookSuccess       = Remotes.Carry:FindFirstChild("UnhookSuccess"),
    },

    Chase = {
        Music = Remotes.Chase:FindFirstChild("ChaseMusicEvent"),
        Run   = Remotes.Chase:FindFirstChild("Runevent"),
    },

    Attacks = {
        BasicAttack  = Remotes.Attacks:FindFirstChild("BasicAttack"),
        AfterAttack  = Remotes.Attacks:FindFirstChild("AfterAttack"),
        Lunge        = Remotes.Attacks:FindFirstChild("Lunge"),
        LungeDetect  = Remotes.Attacks:FindFirstChild("LungeDetect"),
        TrailEvent   = Remotes.Attacks:FindFirstChild("TrailEvent"),
        Hit          = Remotes.Attacks:FindFirstChild("hit"),
    },

    KillerPerks = {
        AbyssalCovenant   = Remotes.KillerPerks:FindFirstChild("Abyssal Covenant"),
        ResentmentClinger = Remotes.KillerPerks:FindFirstChild("Resentment Clinger"),
        KingScourge       = Remotes.KillerPerks:FindFirstChild("kingscourge"),
        ActivateBindable  = Remotes.KillerPerks:FindFirstChild("Activatecdbindable"),
        ActivateRemote    = Remotes.KillerPerks:FindFirstChild("Activatecdremote"),
        StackRemote       = Remotes.KillerPerks:FindFirstChild("StackRemote"),
    },

    Items = {
        Adrenaline    = Remotes.Items:FindFirstChild("Adrenaline Shot"),
        Bandage       = Remotes.Items:FindFirstChild("Bandage"),
        Flashlight    = Remotes.Items:FindFirstChild("Flashlight"),
        Gate          = Remotes.Items:FindFirstChild("Gate"),
        HolyWater     = Remotes.Items:FindFirstChild("Holy Water"),
        ParryingDagger= Remotes.Items:FindFirstChild("Parrying Dagger"),
        RiotShield    = Remotes.Items:FindFirstChild("Riot Shield"),
        ShadowClone   = Remotes.Items:FindFirstChild("Shadow Clone"),
        Tracker       = Remotes.Items:FindFirstChild("Tracker"),
        TwistOfFate   = Remotes.Items:FindFirstChild("Twist of Fate"),
        WaxCandle     = Remotes.Items:FindFirstChild("WaxBound Candle"),
    },

    Mechanics = {
        Crouch            = Remotes.Mechanics:FindFirstChild("Crouch"),
        Fall              = Remotes.Mechanics:FindFirstChild("Fall"),
        Teleport          = Remotes.Mechanics:FindFirstChild("Teleportcharacter"),
        SyncPos           = Remotes.Mechanics:FindFirstChild("syncPosition"),
        CancelAction      = Remotes.Mechanics:FindFirstChild("cancelaction"),
        SpecialAttack     = Remotes.Mechanics:FindFirstChild("Specialattack"),
        PalletStun        = Remotes.Mechanics:FindFirstChild("PalletStun"),
        ParriedBindable   = Remotes.Mechanics:FindFirstChild("Parriedbindable"),
        ParriedClient     = Remotes.Mechanics:FindFirstChild("parriedclient"),
        GotKnocked        = Remotes.Mechanics:FindFirstChild("gotknocked"),
        MoriEnd           = Remotes.Mechanics:FindFirstChild("moriend"),
        ApplyMori         = Remotes.Mechanics:FindFirstChild("Applymori"),
        ApplySP           = Remotes.Mechanics:FindFirstChild("Applysp"),
        ChangeAttribute   = Remotes.Mechanics:FindFirstChild("ChangeAttribute"),
        NetRemote         = Remotes.Mechanics:FindFirstChild("NetRemote"),
    },

    Game = {
        Start             = Remotes.Game:FindFirstChild("Start"),
        RoundEnd          = Remotes.Game:FindFirstChild("RoundEnd"),
        RoundEndEvent     = Remotes.Game:FindFirstChild("RoundEndEvent"),
        LoadMap           = Remotes.Game:FindFirstChild("LoadMap"),
        Loaded            = Remotes.Game:FindFirstChild("Loaded"),
        KillerMorph       = Remotes.Game:FindFirstChild("KillerMorph"),
        OneLeft           = Remotes.Game:FindFirstChild("Oneleft"),
        Death             = Remotes.Game:FindFirstChild("death"),
        IdleRefresh       = Remotes.Game:FindFirstChild("IdleRefreshEvent"),
        EquipItems        = Remotes.Game:FindFirstChild("EquipItems"),
        EndGame           = Remotes.Game:FindFirstChild("endgame"),
        PlayerAction      = Remotes.Game:FindFirstChild("PlayerActionEvent"),
    },

    Events = {
        Christmas = Remotes.Events:FindFirstChild("Christmas"),
        Halloween = Remotes.Events:FindFirstChild("Halloween"),
        Medal     = Remotes.Events:FindFirstChild("Medal"),
    },
}

--═══════════════════════════════════════════════════════════════
-- WORKSPACE REFERENCES
--═══════════════════════════════════════════════════════════════
local WS = {
    Interactables = Workspace:FindFirstChild("Interactables"),
    Map           = Workspace:FindFirstChild("Map"),
    Mazes         = Workspace:FindFirstChild("Mazes"),
    Clones        = Workspace:FindFirstChild("Clones"),
    FakeChars     = Workspace:FindFirstChild("FakeCharacters"),
    Weapons       = Workspace:FindFirstChild("Weapons"),
    Lobby         = Workspace:FindFirstChild("Lobby"),
}

--═══════════════════════════════════════════════════════════════
-- STATE MANAGER
--═══════════════════════════════════════════════════════════════
local State = {
    AutoRepair       = false,
    AutoSkillCheck   = false,
    SkillCheckMode   = "Perfect",
    SkillCheckNotify = false,
    AutoExit         = false,
    NotifyAllGens    = true,
    AutoHealTeam     = false,
    AutoHealSelf     = false,
    AutoHealSkill    = false,
    AutoParry        = false,
    AutoFlashlight   = false,
    AutoRiotRush     = false,
    AutoTwistFate    = false,
    AutoHolyWater    = false,
    AutoSelfUnhook   = false,
    AutoUnhookTeam   = false,
    AutoWiggle       = false,
    InfiniteSprint   = false,
    AntiAFK          = true,
    ESP_Killer       = false,
    ESP_Survivors    = false,
    ESP_Generators   = false,
    ESP_Exits        = false,
    ESP_Items        = false,
    ESP_Hooks        = false,
    ChaseAlert       = false,
    AttackAlert      = false,
    KillerAlert      = false,
    WalkSpeed        = 16,
    JumpPower        = 50,
    NoClip           = false,
    AutoGifts        = false,
    AutoMedals       = false,
    IsKiller         = false,
    MatchActive      = false,
    ESPObjects       = {},
    Connections      = {},
}

--═══════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
--═══════════════════════════════════════════════════════════════
local Util = {}

function Util.SafeFire(remote, ...)
    if not remote then
        warn("[X0DEC04T] Remote missing:", debug.traceback())
        return false
    end
    local args = {...}
    local ok, err = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args))
        elseif remote:IsA("RemoteFunction") then
            return remote:InvokeServer(table.unpack(args))
        end
    end)
    if not ok then warn("[X0DEC04T] Fire failed:", err) end
    return ok
end

function Util.SafeConnect(signal, callback)
    if not signal then return nil end
    local ok, conn = pcall(function()
        return signal:Connect(callback)
    end)
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
    local char = Util.GetCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

function Util.GetHumanoid()
    local char = Util.GetCharacter()
    return char:FindFirstChildOfClass("Humanoid")
end

function Util.Distance(a, b)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

function Util.Notify(title, content, duration)
    WindUI:Notify({
        Title    = title or HUB.Name,
        Content  = content or "",
        Duration = duration or 4,
        Icon     = "bell",
    })
end

function Util.CleanupESP()
    for _, obj in pairs(State.ESPObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    State.ESPObjects = {}
end

function Util.GetGuiParent()
    local parent = CoreGui
    pcall(function()
        if gethui then parent = gethui() end
    end)
    return parent
end

--═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
--═══════════════════════════════════════════════════════════════
local ESP = {}

function ESP.CreateBillboard(adornee, text, color)
    if not adornee then return nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = "X0DEC04T_ESP"
    bb.Adornee = adornee
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text or "ESP"
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Parent = bb

    bb.Parent = Util.GetGuiParent()
    table.insert(State.ESPObjects, bb)
    return bb, label
end

function ESP.ScanInteractables()
    if not WS.Interactables then return end
    for _, obj in ipairs(WS.Interactables:GetChildren()) do
        -- Placeholder - awaiting Interactables verification
    end
end

function ESP.RefreshAll()
    Util.CleanupESP()
    if State.ESP_Generators then ESP.ScanInteractables() end
end

--═══════════════════════════════════════════════════════════════
-- FEATURE STUBS (Awaiting Argument Verification)
--═══════════════════════════════════════════════════════════════
local Features = {}

function Features.AutoRepair()
    task.spawn(function()
        while State.AutoRepair do
            -- TODO: VERIFY ARGS for R.Generator.Repair
            task.wait(0.5)
        end
    end)
end

function Features.SetupSkillCheck()
    if R.Generator.SkillCheck then
        Util.SafeConnect(R.Generator.SkillCheck.OnClientEvent, function(...)
            if State.SkillCheckNotify then
                Util.Notify("Skill Check!", "Generator skill check triggered")
            end
            if State.AutoSkillCheck then
                -- TODO: VERIFY ARGS for R.Generator.SkillCheckResult
            end
        end)
    end
    if R.Healing.SkillCheck then
        Util.SafeConnect(R.Healing.SkillCheck.OnClientEvent, function(...)
            if State.AutoHealSkill then
                -- TODO: VERIFY ARGS for R.Healing.SkillCheckResult
            end
        end)
    end
end

function Features.AutoExit()
    task.spawn(function()
        while State.AutoExit do
            -- TODO: VERIFY ARGS for R.Exit.LeverEvent
            task.wait(0.5)
        end
    end)
end

function Features.AutoHealTeam()
    task.spawn(function()
        while State.AutoHealTeam do
            -- TODO: VERIFY ARGS for R.Healing.HealEvent
            task.wait(0.5)
        end
    end)
end

function Features.AutoHealSelf()
    task.spawn(function()
        while State.AutoHealSelf do
            -- TODO: VERIFY ARGS for R.Items.Bandage.Fire
            task.wait(1)
        end
    end)
end

function Features.AutoParry()
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function(...)
            if State.AutoParry then
                -- TODO: VERIFY ARGS for R.Items.ParryingDagger.parry
            end
        end)
    end
end

function Features.AutoSelfUnhook()
    task.spawn(function()
        while State.AutoSelfUnhook do
            -- TODO: VERIFY ARGS for R.Carry.SelfUnhook
            task.wait(1)
        end
    end)
end

function Features.AutoUnhookTeam()
    task.spawn(function()
        while State.AutoUnhookTeam do
            -- TODO: VERIFY ARGS for R.Carry.Unhook
            task.wait(0.5)
        end
    end)
end

function Features.AutoWiggle()
    task.spawn(function()
        while State.AutoWiggle do
            -- TODO: VERIFY ARGS for R.Carry.DropSurvivor
            task.wait(0.1)
        end
    end)
end

function Features.InfiniteSprint()
    task.spawn(function()
        while State.InfiniteSprint do
            -- TODO: VERIFY ARGS for R.Chase.Run
            task.wait(0.5)
        end
    end)
end

function Features.AntiAFK()
    Util.SafeConnect(LocalPlayer.Idled, function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end

function Features.SetupChaseAlert()
    if R.Chase.Music then
        Util.SafeConnect(R.Chase.Music.OnClientEvent, function(...)
            if State.ChaseAlert then
                Util.Notify("Chase!", "Killer is chasing someone", 3)
            end
        end)
    end
end

function Features.SetupAttackAlert()
    if R.Attacks.Lunge then
        Util.SafeConnect(R.Attacks.Lunge.OnClientEvent, function(...)
            if State.AttackAlert then
                Util.Notify("Attack!", "Killer is lunging!", 2)
            end
        end)
    end
    if R.KillerPerks.KingScourge then
        local start = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        if start then
            Util.SafeConnect(start.OnClientEvent, function(...)
                if State.AttackAlert then
                    Util.Notify("King Scourge!", "Dodge incoming attack!", 2)
                end
            end)
        end
    end
end

function Features.SetupKillerDetection()
    if R.Game.KillerMorph then
        Util.SafeConnect(R.Game.KillerMorph.OnClientEvent, function(...)
            State.IsKiller = true
            Util.Notify("Role Assigned", "You are the KILLER - survivor features disabled", 5)
        end)
    end
end

function Features.SetupMatchState()
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
    if R.Generator.AllGenDone then
        Util.SafeConnect(R.Generator.AllGenDone.OnClientEvent, function(...)
            if State.NotifyAllGens then
                Util.Notify("Gens Complete!", "All generators finished - find the exit!", 5)
            end
        end)
    end
    if R.Game.OneLeft then
        Util.SafeConnect(R.Game.OneLeft.OnClientEvent, function(...)
            Util.Notify("Last Survivor!", "You are the last one alive", 5)
        end)
    end
end

function Features.ApplyWalkSpeed()
    local hum = Util.GetHumanoid()
    if hum then hum.WalkSpeed = State.WalkSpeed end
end

function Features.ApplyJumpPower()
    local hum = Util.GetHumanoid()
    if hum then hum.JumpPower = State.JumpPower end
end

function Features.NoClip()
    task.spawn(function()
        while State.NoClip do
            local char = Util.GetCharacter()
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
            task.wait(0.1)
        end
    end)
end

--═══════════════════════════════════════════════════════════════
-- WINDOW CREATION
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
-- FLOATING LAUNCHER (Minimize Replacement)
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

    -- Hover animations
    local hoverIn  = TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(165, 54) })
    local hoverOut = TweenService:Create(Button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(155, 50) })
    local glowIn   = TweenService:Create(Glow, TweenInfo.new(0.2), { ImageTransparency = 0.3 })
    local glowOut  = TweenService:Create(Glow, TweenInfo.new(0.2), { ImageTransparency = 0.55 })

    Button.MouseEnter:Connect(function() hoverIn:Play(); glowIn:Play() end)
    Button.MouseLeave:Connect(function() hoverOut:Play(); glowOut:Play() end)

    -- Pulsing glow
    task.spawn(function()
        while Glow.Parent do
            TweenService:Create(Glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.4 }):Play()
            task.wait(1.5)
            TweenService:Create(Glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { ImageTransparency = 0.65 }):Play()
            task.wait(1.5)
        end
    end)

    -- Drag (PC + Mobile)
    local dragging      = false
    local dragStart     = nil
    local startPos      = nil
    local dragThreshold = 5
    local didDrag       = false

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
            if delta.Magnitude > dragThreshold then didDrag = true end
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

-- Hook minimize event
pcall(function()
    if Window.OnClose then
        Window:OnClose(function()
            Launcher:MinimizeWindow()
        end)
    end
end)

-- Fallback state monitor for older WindUI versions
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
    Main       = Window:Tab({ Title = "Main",        Icon = "home"       }),
    Generator  = Window:Tab({ Title = "Generator",   Icon = "zap"        }),
    Escape     = Window:Tab({ Title = "Escape",      Icon = "door-open"  }),
    Healing    = Window:Tab({ Title = "Healing",     Icon = "heart"      }),
    Items      = Window:Tab({ Title = "Items",       Icon = "backpack"   }),
    Survival   = Window:Tab({ Title = "Survival",    Icon = "shield"     }),
    ESP        = Window:Tab({ Title = "ESP",         Icon = "eye"        }),
    Movement   = Window:Tab({ Title = "Movement",    Icon = "footprints" }),
    Events     = Window:Tab({ Title = "Events",      Icon = "gift"       }),
    Settings   = Window:Tab({ Title = "Settings",    Icon = "settings"   }),
}

Window:SelectTab(1)

--═══════════════════════════════════════════════════════════════
-- MAIN TAB
--═══════════════════════════════════════════════════════════════
Tabs.Main:Section({ Title = "Welcome" })

Tabs.Main:Paragraph({
    Title = HUB.Name,
    Desc  = "Premium hub for " .. HUB.Game .. "\nVersion " .. HUB.Version .. " | Created by " .. HUB.Author,
})

Tabs.Main:Paragraph({
    Title = "⚠ Skeleton Build Notice",
    Desc  = "This build has full UI, config, theme, and keybind systems ready. Feature FireServer arguments require Remote Spy verification and are marked TODO in source.",
})

Tabs.Main:Section({ Title = "Match Info" })

local RoleLabel = Tabs.Main:Paragraph({ Title = "Your Role", Desc = "Waiting for match..." })

task.spawn(function()
    while true do
        pcall(function()
            RoleLabel:SetDesc(State.IsKiller and "KILLER (features limited)" or "SURVIVOR")
        end)
        task.wait(1)
    end
end)

--═══════════════════════════════════════════════════════════════
-- GENERATOR TAB
--═══════════════════════════════════════════════════════════════
Tabs.Generator:Section({ Title = "Repair" })

Tabs.Generator:Toggle({
    Title = "Auto Repair Generator",
    Desc  = "Automatically holds repair on nearest generator",
    Value = false,
    Callback = function(v)
        State.AutoRepair = v
        if v then Features.AutoRepair() end
    end,
})

Tabs.Generator:Section({ Title = "Skill Check" })

Tabs.Generator:Toggle({
    Title = "Auto Skill Check",
    Desc  = "Auto-completes skill checks (requires arg verification)",
    Value = false,
    Callback = function(v) State.AutoSkillCheck = v end,
})

Tabs.Generator:Dropdown({
    Title  = "Skill Check Mode",
    Values = { "Perfect", "Good" },
    Value  = "Perfect",
    Callback = function(v) State.SkillCheckMode = v end,
})

Tabs.Generator:Toggle({
    Title = "Skill Check Notifications",
    Desc  = "Notify when a skill check appears",
    Value = false,
    Callback = function(v) State.SkillCheckNotify = v end,
})

--═══════════════════════════════════════════════════════════════
-- ESCAPE TAB
--═══════════════════════════════════════════════════════════════
Tabs.Escape:Section({ Title = "Exit Gates" })

Tabs.Escape:Toggle({
    Title = "Auto Open Exit",
    Desc  = "Auto-pulls exit lever when possible",
    Value = false,
    Callback = function(v)
        State.AutoExit = v
        if v then Features.AutoExit() end
    end,
})

Tabs.Escape:Toggle({
    Title = "Notify All Gens Complete",
    Desc  = "Alert when all generators finish",
    Value = true,
    Callback = function(v) State.NotifyAllGens = v end,
})

--═══════════════════════════════════════════════════════════════
-- HEALING TAB
--═══════════════════════════════════════════════════════════════
Tabs.Healing:Section({ Title = "Team Healing" })

Tabs.Healing:Toggle({
    Title = "Auto Heal Teammates",
    Desc  = "Heal nearby wounded survivors",
    Value = false,
    Callback = function(v)
        State.AutoHealTeam = v
        if v then Features.AutoHealTeam() end
    end,
})

Tabs.Healing:Toggle({
    Title = "Auto Heal Skill Checks",
    Desc  = "Auto-complete healing skill checks",
    Value = false,
    Callback = function(v) State.AutoHealSkill = v end,
})

Tabs.Healing:Section({ Title = "Self Healing" })

Tabs.Healing:Toggle({
    Title = "Auto Bandage (Self)",
    Desc  = "Auto-use bandage when wounded",
    Value = false,
    Callback = function(v)
        State.AutoHealSelf = v
        if v then Features.AutoHealSelf() end
    end,
})

--═══════════════════════════════════════════════════════════════
-- ITEMS TAB
--═══════════════════════════════════════════════════════════════
Tabs.Items:Section({ Title = "Combat Items" })

Tabs.Items:Toggle({
    Title = "Auto Parry (Parrying Dagger)",
    Desc  = "Auto-parry killer attacks",
    Value = false,
    Callback = function(v) State.AutoParry = v end,
})

Tabs.Items:Toggle({
    Title = "Auto Riot Shield Rush",
    Desc  = "Auto-rush to stun killer",
    Value = false,
    Callback = function(v) State.AutoRiotRush = v end,
})

Tabs.Items:Toggle({
    Title = "Auto Flashlight",
    Desc  = "Auto-blind killer when facing",
    Value = false,
    Callback = function(v) State.AutoFlashlight = v end,
})

Tabs.Items:Section({ Title = "Utility Items" })

Tabs.Items:Toggle({
    Title = "Auto Twist of Fate",
    Desc  = "Auto-fire Twist of Fate",
    Value = false,
    Callback = function(v) State.AutoTwistFate = v end,
})

Tabs.Items:Toggle({
    Title = "Auto Holy Water",
    Desc  = "Auto-throw Holy Water",
    Value = false,
    Callback = function(v) State.AutoHolyWater = v end,
})

--═══════════════════════════════════════════════════════════════
-- SURVIVAL TAB
--═══════════════════════════════════════════════════════════════
Tabs.Survival:Section({ Title = "Hook Escape" })

Tabs.Survival:Toggle({
    Title = "Auto Self-Unhook",
    Desc  = "Auto-attempt self-unhook when hooked",
    Value = false,
    Callback = function(v)
        State.AutoSelfUnhook = v
        if v then Features.AutoSelfUnhook() end
    end,
})

Tabs.Survival:Toggle({
    Title = "Auto Unhook Teammates",
    Desc  = "Auto-rescue nearby hooked teammates",
    Value = false,
    Callback = function(v)
        State.AutoUnhookTeam = v
        if v then Features.AutoUnhookTeam() end
    end,
})

Tabs.Survival:Toggle({
    Title = "Auto Wiggle (Escape Carry)",
    Desc  = "Auto-wiggle when being carried",
    Value = false,
    Callback = function(v)
        State.AutoWiggle = v
        if v then Features.AutoWiggle() end
    end,
})

Tabs.Survival:Section({ Title = "Utility" })

Tabs.Survival:Toggle({
    Title = "Infinite Sprint",
    Desc  = "Continuously trigger sprint",
    Value = false,
    Callback = function(v)
        State.InfiniteSprint = v
        if v then Features.InfiniteSprint() end
    end,
})

Tabs.Survival:Toggle({
    Title = "Anti-AFK",
    Desc  = "Prevents idle disconnect",
    Value = true,
    Callback = function(v) State.AntiAFK = v end,
})

--═══════════════════════════════════════════════════════════════
-- ESP TAB
--═══════════════════════════════════════════════════════════════
Tabs.ESP:Section({ Title = "Players" })

Tabs.ESP:Toggle({
    Title = "Killer ESP",
    Desc  = "Highlight killer with distance",
    Value = false,
    Callback = function(v) State.ESP_Killer = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Survivor ESP",
    Desc  = "Highlight teammates (filters fake characters)",
    Value = false,
    Callback = function(v) State.ESP_Survivors = v; ESP.RefreshAll() end,
})

Tabs.ESP:Section({ Title = "Objectives" })

Tabs.ESP:Toggle({
    Title = "Generator ESP",
    Desc  = "Show generators with progress",
    Value = false,
    Callback = function(v) State.ESP_Generators = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Exit ESP",
    Desc  = "Show exit gates",
    Value = false,
    Callback = function(v) State.ESP_Exits = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Hook ESP",
    Desc  = "Show hook locations",
    Value = false,
    Callback = function(v) State.ESP_Hooks = v; ESP.RefreshAll() end,
})

Tabs.ESP:Toggle({
    Title = "Item ESP",
    Desc  = "Show ground items and weapons",
    Value = false,
    Callback = function(v) State.ESP_Items = v; ESP.RefreshAll() end,
})

Tabs.ESP:Section({ Title = "Alerts" })

Tabs.ESP:Toggle({
    Title = "Chase Music Alert",
    Desc  = "Notify when chase music plays",
    Value = false,
    Callback = function(v) State.ChaseAlert = v end,
})

Tabs.ESP:Toggle({
    Title = "Attack Alert (Lunge/Scourge)",
    Desc  = "Notify when killer attacks",
    Value = false,
    Callback = function(v) State.AttackAlert = v end,
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
        Features.ApplyWalkSpeed()
    end,
})

Tabs.Movement:Slider({
    Title = "JumpPower",
    Value = { Min = 50, Max = 200, Default = 50 },
    Callback = function(v)
        State.JumpPower = v
        Features.ApplyJumpPower()
    end,
})

Tabs.Movement:Section({ Title = "Advanced" })

Tabs.Movement:Toggle({
    Title = "NoClip",
    Desc  = "Walk through walls (risky)",
    Value = false,
    Callback = function(v)
        State.NoClip = v
        if v then Features.NoClip() end
    end,
})

Tabs.Movement:Section({ Title = "Teleport" })

Tabs.Movement:Button({
    Title = "Teleport to Nearest Generator",
    Desc  = "Requires Interactables scan",
    Callback = function()
        Util.Notify("Teleport", "Feature awaiting Interactables verification", 3)
    end,
})

Tabs.Movement:Button({
    Title = "Teleport to Nearest Exit",
    Desc  = "Requires Interactables scan",
    Callback = function()
        Util.Notify("Teleport", "Feature awaiting Interactables verification", 3)
    end,
})

--═══════════════════════════════════════════════════════════════
-- EVENTS TAB
--═══════════════════════════════════════════════════════════════
Tabs.Events:Section({ Title = "Seasonal" })

Tabs.Events:Toggle({
    Title = "Auto Collect Christmas Gifts",
    Desc  = "Auto-collect event gifts",
    Value = false,
    Callback = function(v) State.AutoGifts = v end,
})

Tabs.Events:Toggle({
    Title = "Auto Claim Medal Quests",
    Desc  = "Auto-claim completed medals",
    Value = false,
    Callback = function(v) State.AutoMedals = v end,
})

--═══════════════════════════════════════════════════════════════
-- SETTINGS TAB
--═══════════════════════════════════════════════════════════════
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
            Util.Notify("Config", "Configuration saved", 3)
        end
    end,
})

Tabs.Settings:Button({
    Title = "Load Config",
    Callback = function()
        if ConfigMgr then
            ConfigMgr:Load()
            Util.Notify("Config", "Configuration loaded", 3)
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
    Title = "Panic (Disable All)",
    Value = "End",
    Callback = function()
        for k, v in pairs(State) do
            if type(v) == "boolean" then State[k] = false end
        end
        Util.CleanupESP()
        Util.Notify("PANIC", "All features disabled", 3)
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
        Util.CleanupESP()
        if Launcher.Gui then Launcher.Gui:Destroy() end
        Window:Destroy()
    end,
})

--═══════════════════════════════════════════════════════════════
-- INITIALIZATION
--═══════════════════════════════════════════════════════════════
Features.SetupSkillCheck()
Features.SetupChaseAlert()
Features.SetupAttackAlert()
Features.SetupKillerDetection()
Features.SetupMatchState()
Features.AutoParry()
Features.AntiAFK()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    Features.ApplyWalkSpeed()
    Features.ApplyJumpPower()
end)

Util.Notify(HUB.Name, "Hub loaded successfully - v" .. HUB.Version, 5)
print("[X0DEC04T] Hub loaded. Feature args require Remote Spy verification.")
