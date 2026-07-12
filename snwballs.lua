--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.1.0 - Snowball Battles
-- PlaceID: 106701494743444
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
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ═══════════════════════════════════════════
-- SINGLETON
-- ═══════════════════════════════════════════
local INSTANCE_KEY = "__X0DEC04T_SnowballBattles_v110"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _logStart = os.clock()
local function Log(msg)
    print(string.format("[SB-Hub][+%.2fs] %s", os.clock()-_logStart, tostring(msg)))
end

Log("Snowball Battles Hub v1.1.0 loading...")

-- ═══════════════════════════════════════════
-- RAYFIELD
-- ═══════════════════════════════════════════
local Rayfield = nil
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then warn("Rayfield failed"); return end

-- ═══════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════
local CM = { _list = {} }
function CM:Add(sig, cb, label)
    if not sig then return nil end
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
local KB = { _binds = {} }
function KB.Register(name, defaultKey, callback)
    KB._binds[name] = {
        key      = defaultKey or Enum.KeyCode.Unknown,
        callback = callback,
        enabled  = true,
    }
end
function KB.SetKey(name, keyCode)
    if KB._binds[name] then KB._binds[name].key = keyCode end
end

CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    for _, bind in pairs(KB._binds) do
        if bind.enabled and bind.key == inp.KeyCode then
            pcall(bind.callback)
        end
    end
end, "KB_Global")

-- ═══════════════════════════════════════════
-- REMOTES — MAPPED FROM GAME
-- ═══════════════════════════════════════════
local Remote = ReplicatedStorage:WaitForChild("Remote", 10)

local R = {
    -- Fight
    PushBall    = Remote and Remote:FindFirstChild("Fight") 
                    and Remote.Fight:FindFirstChild("PushBall"),
    Standup     = Remote and Remote:FindFirstChild("Fight") 
                    and Remote.Fight:FindFirstChild("Standup"),
    GetHurt     = Remote and Remote:FindFirstChild("Fight") 
                    and Remote.Fight:FindFirstChild("GetHurt"),

    -- GUI
    Health      = Remote and Remote:FindFirstChild("GameGUI") 
                    and Remote.GameGUI:FindFirstChild("Health"),

    -- Skills
    SkillReceiver    = Remote and Remote:FindFirstChild("Skill") 
                        and Remote.Skill:FindFirstChild("SkillReceiver"),
    SkillBuffReceiver= Remote and Remote:FindFirstChild("Skill") 
                        and Remote.Skill:FindFirstChild("SkillBuffReceiver"),
    SpeedHit         = Remote and Remote:FindFirstChild("Skill") 
                        and Remote.Skill:FindFirstChild("SpeedHit"),
    FireBallRun      = Remote and Remote:FindFirstChild("Skill") 
                        and Remote.Skill:FindFirstChild("Buff") 
                        and Remote.Skill.Buff:FindFirstChild("FireBallRun"),

    -- Anim
    PlayAnim    = Remote and Remote:FindFirstChild("Anim") 
                    and Remote.Anim:FindFirstChild("CharacterPlayAnim"),
    CameraShake = Remote and Remote:FindFirstChild("Anim") 
                    and Remote.Anim:FindFirstChild("CameraShake"),

    -- Reward
    RedeemCode  = Remote and Remote:FindFirstChild("Reward") 
                    and Remote.Reward:FindFirstChild("RedeemCode"),
    DailyClaim  = Remote and Remote:FindFirstChild("Reward") 
                    and Remote.Reward:FindFirstChild("DailyRewardClaim"),

    -- Spectate
    Spectate    = Remote and Remote:FindFirstChild("SpectateGUI") 
                    and Remote.SpectateGUI:FindFirstChild("SpectateTargetPlayer"),

    -- DeadPool
    TornadoState = Remote and Remote:FindFirstChild("DeadPool") 
                    and Remote.DeadPool:FindFirstChild("TornadoStateRequest"),
    TsunamiState = Remote and Remote:FindFirstChild("DeadPool") 
                    and Remote.DeadPool:FindFirstChild("TsunamiStateRequest"),

    -- Vote
    Vote        = Remote and Remote:FindFirstChild("MapVoter") 
                    and Remote.MapVoter:FindFirstChild("Vote"),
    JoinGame    = Remote and Remote:FindFirstChild("PlaytestGUI") 
                    and Remote.PlaytestGUI:FindFirstChild("JoinGame"),
}

Log("PushBall: "..(R.PushBall and "✓" or "✗"))
Log("Standup:  "..(R.Standup and "✓" or "✗"))
Log("GetHurt:  "..(R.GetHurt and "✓" or "✗"))
Log("Skill:    "..(R.SkillReceiver and "✓" or "✗"))

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- Auto Throw
    AutoThrow      = false,
    ThrowDelay     = 0.3,
    ThrowRange     = 150,
    ThrowTarget    = "Nearest",
    AutoLead       = true,      -- predict enemy position
    ThrowPower     = 100,
    LastThrow      = 0,

    -- Auto Dodge / Standup
    AutoDodge      = false,
    AutoStandup    = true,      -- auto stand up when knocked
    DodgeRange     = 20,
    LastDodge      = 0,
    DodgeCD        = 0.6,
    AntiStun       = false,

    -- Aim
    AimAssist      = false,
    AutoAim        = false,
    AimSmoothing   = 0.2,
    AimFOV         = 150,
    AimBone        = "HumanoidRootPart",
    ShowFOVCircle  = false,
    AimTarget      = nil,
    AimKey         = "Mouse2",  -- RMB

    -- ESP
    ESP_Players    = false,
    ESP_Balls      = false,
    ESP_ShowHP     = true,
    ESP_ShowDist   = true,
    ESP_ShowName   = true,
    ESP_MaxDist    = 800,

    Color_Enemy    = Color3.fromRGB(255,50,50),
    Color_Ally     = Color3.fromRGB(60,180,255),
    Color_Ball     = Color3.fromRGB(180,220,255),

    -- Movement
    WalkSpeed      = 16,
    JumpPower      = 50,
    NoClip         = false,
    InfJump        = false,
    SpeedBoost     = false,
    SpeedValue     = 40,

    -- Visual
    FullBright     = false,
    NoFog          = false,
    NoShadows      = false,
    FOV            = 70,
    Freecam        = false,
    RemoveBlur     = false,
    NoParticles    = false,
    LowGfx         = false,

    -- God / HP
    GodMode        = false,
    ShowOwnHP      = false,
    AntiPush       = false,     -- prevent push knockback
    InfHealth      = false,

    -- Misc
    AntiAFK        = true,
    AutoRejoin     = false,
    HideName       = false,
    AutoSkill      = false,
    SkillDelay     = 1.0,
    AutoVote       = false,

    -- HUD
    ShowStats      = false,
    ShowRadar      = false,

    -- Cache
    ESPCache       = {},
    LightBackup    = {},
    MutedSounds    = {},

    -- Connections
    AutoThrowConn  = nil,
    AutoDodgeConn  = nil,
    GodModeConn    = nil,
    AimConn        = nil,
    NoClipConn     = nil,
    InfJumpConn    = nil,
    FreecamConn    = nil,
    StandupConn    = nil,
    HurtConn       = nil,
    AntiPushConn   = nil,
    AutoSkillConn  = nil,

    -- GUI refs
    HPGui          = nil,
    HPText         = nil,
    HPBar          = nil,
    AimCircle      = nil,
    StatsGui       = nil,
    RadarGui       = nil,

    -- Stats
    Kills          = 0,
    Hits           = 0,
    Deaths         = 0,
    Throws         = 0,

    -- TP
    TPTarget       = "",
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
            Title = tostring(t or ""),
            Content = tostring(c or ""),
            Duration = tonumber(d) or 3,
            Image = 4483345998,
        })
    end)
end
local function GetChar() return LocalPlayer.Character end
local function GetHRP()
    local c = GetChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function GetHuman()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetRoot(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChild("UpperTorso")
            or obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart")
    end
    return nil
end

-- ═══════════════════════════════════════════
-- PLAYER HELPERS (no teams in this game - all attackers)
-- ═══════════════════════════════════════════
local PH = {}

function PH.GetOthers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(list, p)
            end
        end
    end
    return list
end

function PH.Nearest()
    local hrp = GetHRP(); if not hrp then return nil, math.huge end
    local best, bd = nil, math.huge
    for _, p in ipairs(PH.GetOthers()) do
        local erp = GetRoot(p.Character)
        if erp then
            local d = (erp.Position - hrp.Position).Magnitude
            if d < bd then bd = d; best = p end
        end
    end
    return best, bd
end

function PH.LowestHP()
    local best, minHP = nil, math.huge
    for _, p in ipairs(PH.GetOthers()) do
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < minHP then
            minHP = hum.Health
            best = p
        end
    end
    return best
end

-- ═══════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_SB_ESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "X0_SB_ESP"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.DisplayOrder = 999
    ESPGui.Parent = GuiParent()
end

local ESP = {}
local ESPRender = nil

local function MakeEntry(obj, label, color, isChar)
    local rp = GetRoot(obj); if not rp then return nil end

    local hl = Instance.new("Highlight")
    hl.Adornee = obj
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = isChar and 0.45 or 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, isChar and 70 or 40)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = State.ESP_MaxDist
    bb.ResetOnSpawn = false
    bb.Adornee = rp
    bb.Parent = ESPGui

    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1,0,0,20)
    nl.BackgroundTransparency = 1
    nl.Text = label
    nl.TextColor3 = color
    nl.TextStrokeTransparency = 0.35
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14

    local dl = Instance.new("TextLabel", bb)
    dl.Size = UDim2.new(1,0,0,16)
    dl.Position = UDim2.new(0,0,0,20)
    dl.BackgroundTransparency = 1
    dl.Text = "0m"
    dl.TextColor3 = Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency = 0.35
    dl.Font = Enum.Font.Gotham
    dl.TextSize = 12

    local hl2 = nil
    if isChar then
        hl2 = Instance.new("TextLabel", bb)
        hl2.Size = UDim2.new(1,0,0,16)
        hl2.Position = UDim2.new(0,0,0,36)
        hl2.BackgroundTransparency = 1
        hl2.Text = "HP: 100"
        hl2.TextColor3 = Color3.fromRGB(60,220,60)
        hl2.TextStrokeTransparency = 0.35
        hl2.Font = Enum.Font.GothamBold
        hl2.TextSize = 13
    end

    return {rp=rp, obj=obj, hl=hl, bb=bb, nl=nl, dl=dl, hpL=hl2, isChar=isChar, color=color}
end

function ESP.Add(obj, label, color, isChar)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeEntry(obj, label, color, isChar or false)
    if e then State.ESPCache[obj] = e end
end

function ESP.Remove(obj)
    local e = State.ESPCache[obj]; if not e then return end
    pcall(function() e.hl:Destroy() end)
    pcall(function() e.bb:Destroy() end)
    State.ESPCache[obj] = nil
end

function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Remove(obj) end
    State.ESPCache = {}
end

if ESPRender then ESPRender:Disconnect() end
ESPRender = RunService.RenderStepped:Connect(function()
    local hrp = GetHRP()
    local pos = hrp and hrp.Position or Vector3.zero
    local toRemove = {}
    for obj, e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then
            table.insert(toRemove, obj)
        else
            local rp = GetRoot(obj)
            if not rp then table.insert(toRemove, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function() e.bb.Adornee = rp end)
                    pcall(function() e.hl.Adornee = obj end)
                end
                pcall(function() e.bb.MaxDistance = State.ESP_MaxDist end)
                local dist = (rp.Position - pos).Magnitude
                local vis = dist <= State.ESP_MaxDist
                pcall(function()
                    e.dl.Text = math.floor(dist).."m"
                    e.dl.Visible = State.ESP_ShowDist
                    e.nl.Visible = State.ESP_ShowName
                    e.bb.Enabled = vis
                    e.hl.Enabled = vis
                end)
                if e.isChar and e.hpL then
                    pcall(function()
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if hum then
                            local hp = math.floor(hum.Health)
                            local mx = math.floor(hum.MaxHealth)
                            e.hpL.Text = "HP: "..hp.."/"..mx
                            local pct = mx>0 and hp/mx or 0
                            e.hpL.TextColor3 = pct>0.6 and Color3.fromRGB(60,220,60)
                                or pct>0.3 and Color3.fromRGB(255,180,60)
                                or Color3.fromRGB(255,50,50)
                            e.hpL.Visible = State.ESP_ShowHP
                        end
                    end)
                end
            end
        end
    end
    for _, o in ipairs(toRemove) do ESP.Remove(o) end
end)

function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            if State.ESP_Players then
                if not State.ESPCache[p.Character] then
                    ESP.Add(p.Character, "["..p.Name.."]", State.Color_Enemy, true)
                end
            else
                if State.ESPCache[p.Character] then ESP.Remove(p.Character) end
            end
        end
    end
end

function ESP.ScanBalls()
    -- Snowballs in this game are called "Bola Salju" or similar - scan workspace
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find("ball") or n:find("bola") or n:find("salju") or n:find("snow"))
           and (obj:IsA("BasePart") or (obj:IsA("Model") and obj.PrimaryPart)) then
            if State.ESP_Balls then
                if not State.ESPCache[obj] then
                    ESP.Add(obj, "[BALL]", State.Color_Ball, false)
                end
            else
                if State.ESPCache[obj] then ESP.Remove(obj) end
            end
        end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers()
    if State.ESP_Balls then ESP.ScanBalls() end
end

task.spawn(function()
    while task.wait(1.5) do pcall(ESP.RefreshAll) end
end)

local function HookP(p)
    if p == LocalPlayer then return end
    CM:Add(p.CharacterAdded, function()
        task.wait(0.5); ESP.RefreshAll()
    end, "CA:"..p.Name)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c) end, "CR:"..p.Name)
end
for _, p in ipairs(Players:GetPlayers()) do HookP(p) end
CM:Add(Players.PlayerAdded, HookP, "PA")
CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Remove(p.Character) end
end, "PR")

-- ═══════════════════════════════════════════
-- AIM
-- ═══════════════════════════════════════════
local Aim = {}

local function ScreenDist(obj)
    local rp = GetRoot(obj); if not rp then return math.huge end
    local sp, onScreen = Camera:WorldToScreenPoint(rp.Position)
    if not onScreen then return math.huge end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    return (Vector2.new(sp.X, sp.Y) - center).Magnitude
end

function Aim.Best()
    local best, bd = nil, State.AimFOV
    for _, p in ipairs(PH.GetOthers()) do
        local sd = ScreenDist(p.Character)
        if sd < bd then bd = sd; best = p end
    end
    return best
end

function Aim.LockOn(p)
    if not p or not p.Character then return end
    local bone = p.Character:FindFirstChild(State.AimBone)
        or p.Character:FindFirstChild("HumanoidRootPart")
    if not bone then return end
    local tp = bone.Position
    -- Lead prediction
    if State.AutoLead then
        local vel = bone.AssemblyLinearVelocity
        if vel.Magnitude > 3 then
            local hrp = GetHRP()
            if hrp then
                local dist = (bone.Position - hrp.Position).Magnitude
                local travelTime = dist / 100 -- snowball speed estimate
                tp = tp + vel * travelTime * 0.5
            end
        end
    end
    local goal = CFrame.new(Camera.CFrame.Position, tp)
    Camera.CFrame = Camera.CFrame:Lerp(goal, State.AimSmoothing)
end

function Aim.DrawCircle()
    if State.AimCircle then pcall(function() State.AimCircle:Destroy() end) end
    if not State.ShowFOVCircle then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_AimFOV"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 998
    sg.Parent = GuiParent()
    local cx, cy = Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2
    local r = State.AimFOV
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(0, r*2, 0, r*2)
    f.Position = UDim2.new(0, cx-r, 0, cy-r)
    f.BackgroundTransparency = 1
    Instance.new("UICorner", f).CornerRadius = UDim.new(1,0)
    local st = Instance.new("UIStroke", f)
    st.Color = Color3.fromRGB(255,80,80)
    st.Thickness = 1.5
    State.AimCircle = sg
end

function Aim.Set(enable)
    if State.AimConn then
        pcall(function() State.AimConn:Disconnect() end)
        State.AimConn = nil
    end
    Aim.DrawCircle()
    if not enable then return end
    State.AimConn = RunService.RenderStepped:Connect(function()
        if not (State.AimAssist or State.AutoAim) then return end
        local t = Aim.Best()
        State.AimTarget = t
        if not t then return end
        if State.AutoAim then
            Aim.LockOn(t)
        elseif State.AimAssist then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                Aim.LockOn(t)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- SNOWBALL COMBAT
-- ═══════════════════════════════════════════
local Snow = {}

-- Throw a snowball at target position using PushBall remote
local function FirePushBall(targetPos, targetPlayer)
    if not R.PushBall then return end
    local hrp = GetHRP(); if not hrp then return end
    local dir = (targetPos - hrp.Position).Unit
    local power = State.ThrowPower

    -- Try multiple argument combos — PushBall likely takes direction/target
    local tries = {
        function() R.PushBall:FireServer(targetPos) end,
        function() R.PushBall:FireServer(dir, power) end,
        function() R.PushBall:FireServer(dir, power, targetPlayer) end,
        function() R.PushBall:FireServer(targetPlayer, targetPos) end,
        function() R.PushBall:FireServer(dir) end,
        function() R.PushBall:FireServer(targetPos, power) end,
        function() R.PushBall:FireServer() end,
    }
    for _, fn in ipairs(tries) do
        pcall(fn)
    end

    State.Throws = State.Throws + 1
end

-- Simulate throw via input as backup
local function SimulateThrowInput()
    local vp = Camera.ViewportSize
    pcall(function()
        VirtualInputMgr:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true, game, 1)
    end)
    task.delay(0.05, function()
        pcall(function()
            VirtualInputMgr:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
        end)
    end)
end

-- ─── Auto Throw ─────────────────────────
function Snow.SetAutoThrow(enable)
    if State.AutoThrowConn then
        pcall(function() State.AutoThrowConn:Disconnect() end)
        State.AutoThrowConn = nil
    end
    if not enable then return end

    State.AutoThrowConn = RunService.Heartbeat:Connect(function()
        if not State.AutoThrow then return end
        if tick() - State.LastThrow < State.ThrowDelay then return end
        local hrp = GetHRP(); if not hrp then return end

        local target
        if State.ThrowTarget == "Nearest" then
            target = PH.Nearest()
        elseif State.ThrowTarget == "Aim Target" then
            target = State.AimTarget or Aim.Best()
        elseif State.ThrowTarget == "Lowest HP" then
            target = PH.LowestHP()
        elseif State.ThrowTarget == "Random" then
            local list = PH.GetOthers()
            if #list > 0 then target = list[math.random(1,#list)] end
        end

        if target and target.Character then
            local erp = GetRoot(target.Character)
            if erp then
                local dist = (erp.Position - hrp.Position).Magnitude
                if dist <= State.ThrowRange then
                    State.LastThrow = tick()

                    -- Aim camera at target first
                    if State.AutoAim or State.AimAssist then
                        Aim.LockOn(target)
                    end

                    -- Predict position
                    local aimPos = erp.Position + Vector3.new(0, 2, 0)
                    if State.AutoLead then
                        local vel = erp.AssemblyLinearVelocity
                        if vel.Magnitude > 3 then
                            local travelTime = dist / 100
                            aimPos = aimPos + vel * travelTime * 0.6
                        end
                    end

                    FirePushBall(aimPos, target)
                    SimulateThrowInput()
                end
            end
        end
    end)
end

-- ─── Auto Dodge / Standup ───────────────
function Snow.SetAutoStandup(enable)
    if State.StandupConn then
        pcall(function() State.StandupConn:Disconnect() end)
        State.StandupConn = nil
    end
    if not enable then return end
    -- Watch for knock-down state via humanoid
    State.StandupConn = RunService.Heartbeat:Connect(function()
        if not State.AutoStandup then return end
        local hum = GetHuman(); if not hum then return end
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Physics
           or state == Enum.HumanoidStateType.FallingDown
           or state == Enum.HumanoidStateType.Ragdoll
           or state == Enum.HumanoidStateType.PlatformStanding then
            if R.Standup then
                pcall(function() R.Standup:FireServer() end)
            end
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum.PlatformStand = false
            end)
        end
    end)
end

function Snow.SetAutoDodge(enable)
    if State.AutoDodgeConn then
        pcall(function() State.AutoDodgeConn:Disconnect() end)
        State.AutoDodgeConn = nil
    end
    if State.HurtConn then
        pcall(function() State.HurtConn:Disconnect() end)
        State.HurtConn = nil
    end
    if not enable then return end

    -- Layer 1: Watch for incoming balls
    State.AutoDodgeConn = RunService.Heartbeat:Connect(function()
        if not State.AutoDodge then return end
        if tick() - State.LastDodge < State.DodgeCD then return end
        local hrp = GetHRP(); if not hrp then return end

        local threat = false
        for _, obj in ipairs(Workspace:GetDescendants()) do
            local n = obj.Name:lower()
            if (n:find("ball") or n:find("bola") or n:find("salju"))
               and obj:IsA("BasePart") then
                local dist = (obj.Position - hrp.Position).Magnitude
                if dist < State.DodgeRange then
                    local vel = obj.AssemblyLinearVelocity
                    if vel.Magnitude > 8 then
                        local toMe = (hrp.Position - obj.Position).Unit
                        if toMe:Dot(vel.Unit) > 0.3 then
                            threat = true
                            break
                        end
                    end
                end
            end
        end

        if threat then
            State.LastDodge = tick()
            -- Jump + strafe dodge
            local hum = GetHuman()
            if hum then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
            -- Random strafe teleport
            local dirs = {
                Vector3.new(6,0,0), Vector3.new(-6,0,0),
                Vector3.new(0,0,6), Vector3.new(0,0,-6),
            }
            local d = dirs[math.random(1,#dirs)]
            pcall(function()
                hrp.CFrame = hrp.CFrame + d
            end)
            -- Fire standup remote just in case
            if R.Standup then
                pcall(function() R.Standup:FireServer() end)
            end
        end
    end)

    -- Layer 2: GetHurt listener (instant reaction)
    if R.GetHurt then
        State.HurtConn = R.GetHurt.OnClientEvent:Connect(function(...)
            if not State.AutoDodge then return end
            if tick() - State.LastDodge < 0.15 then return end
            State.LastDodge = tick()
            if R.Standup then
                pcall(function() R.Standup:FireServer() end)
            end
            local hum = GetHuman()
            if hum then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    hum.PlatformStand = false
                end)
            end
        end)
    end
end

-- ─── Anti-Push / Anti-Stun ───────────────
function Snow.SetAntiPush(enable)
    if State.AntiPushConn then
        pcall(function() State.AntiPushConn:Disconnect() end)
        State.AntiPushConn = nil
    end
    if not enable then return end
    State.AntiPushConn = RunService.Heartbeat:Connect(function()
        if not State.AntiPush then return end
        local hrp = GetHRP(); if not hrp then return end
        local vel = hrp.AssemblyLinearVelocity
        -- Cancel any external velocity (except gravity)
        if math.abs(vel.X) > 1 or math.abs(vel.Z) > 1 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
            end)
        end
        pcall(function()
            local hum = GetHuman()
            if hum then hum.PlatformStand = false end
        end)
    end)
end

-- ─── God Mode ───────────────────────────
function Snow.SetGod(enable)
    if State.GodModeConn then
        pcall(function() State.GodModeConn:Disconnect() end)
        State.GodModeConn = nil
    end
    if not enable then return end
    State.GodModeConn = RunService.Heartbeat:Connect(function()
        if not State.GodMode then return end
        local char = GetChar(); if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health < hum.MaxHealth then
            pcall(function() hum.Health = hum.MaxHealth end)
        end
        pcall(function()
            char:SetAttribute("Godmode", true)
            char:SetAttribute("Invincible", true)
        end)
    end)
end

-- ─── Auto Skill Spam ────────────────────
function Snow.SetAutoSkill(enable)
    if State.AutoSkillConn then
        pcall(function() State.AutoSkillConn:Disconnect() end)
        State.AutoSkillConn = nil
    end
    if not enable then return end
    task.spawn(function()
        while State.AutoSkill do
            task.wait(State.SkillDelay)
            if R.SkillReceiver then
                pcall(function() R.SkillReceiver:FireServer() end)
            end
            if R.SkillBuffReceiver then
                pcall(function() R.SkillBuffReceiver:FireServer() end)
            end
            -- Try triggering equipped ball skill
            for _, key in ipairs({Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.R}) do
                pcall(function()
                    VirtualInputMgr:SendKeyEvent(true, key, false, game)
                end)
                task.wait(0.05)
                pcall(function()
                    VirtualInputMgr:SendKeyEvent(false, key, false, game)
                end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════
local Move = {}
function Move.Speed()
    local h = GetHuman(); if h then h.WalkSpeed = State.WalkSpeed end
end
function Move.Jump()
    local h = GetHuman()
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end
function Move.SetNoClip(e)
    if State.NoClipConn then
        pcall(function() State.NoClipConn:Disconnect() end)
        State.NoClipConn = nil
    end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local c = GetChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
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
            local h = GetHuman()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end
function Move.TPPlayer(name)
    if not name or name == "" then return end
    local t = Players:FindFirstChild(name)
    if not t or not t.Character then Notify("TP", "Not found", 2); return end
    local hrp = GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Notify("TP", "→ "..name, 2)
    end
end
function Move.TPNearest()
    local p = PH.Nearest()
    if not p or not p.Character then Notify("TP", "No target", 2); return end
    local erp = GetRoot(p.Character); local hrp = GetHRP()
    if erp and hrp then
        hrp.CFrame = erp.CFrame + erp.CFrame.LookVector * -4 + Vector3.new(0,2,0)
        Notify("TP", "→ "..p.Name, 2)
    end
end
function Move.ServerHop()
    pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"..game.PlaceId
            .."/servers/Public?sortOrder=Asc&limit=100"
        )
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- VISUALS
-- ═══════════════════════════════════════════
local Vis = {}
function Vis.Backup()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
    }
end
function Vis.Restore()
    for k,v in pairs(State.LightBackup) do
        pcall(function() Lighting[k] = v end)
    end
end
function Vis.FullBright(e)
    Vis.Backup()
    if e then
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then a.Density = 0; a.Haze = 0 end
        end
    else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup()
    if e then
        Lighting.FogEnd = 999999
        Lighting.FogStart = 999999
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then a.Density = 0; a.Haze = 0 end
        end
    else
        Lighting.FogEnd = State.LightBackup.FogEnd or 100000
    end
end
function Vis.NoShadows(e) Vis.Backup(); Lighting.GlobalShadows = not e end
function Vis.FOV(f) Camera.FieldOfView = tonumber(f) or 70 end
function Vis.PostFX(rm)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect")
        or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
            v.Enabled = not rm
        end
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
function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel = e
            and Enum.QualityLevel.Level01
            or Enum.QualityLevel.Automatic
    end)
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
function Vis.HideName(e)
    local c = GetChar(); if not c then return end
    local h = c:FindFirstChild("Head"); if not h then return end
    for _, g in ipairs(h:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
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
            local look = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local sp = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 6 or 2
            local mv = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
            pos = pos + mv * sp
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

-- ═══════════════════════════════════════════
-- HP BAR
-- ═══════════════════════════════════════════
local HP = {}
function HP.Create()
    if State.HPGui then pcall(function() State.HPGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_HP"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.Parent = GuiParent()
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(0, 240, 0, 55)
    f.Position = UDim2.new(0, 15, 0.5, -28)
    f.BackgroundColor3 = Color3.fromRGB(20,20,25)
    f.BackgroundTransparency = 0.25
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local st = Instance.new("UIStroke", f)
    st.Color = Color3.fromRGB(100,180,255); st.Thickness = 1.5
    local title = Instance.new("TextLabel", f)
    title.Size = UDim2.new(1,-10,0,18); title.Position = UDim2.new(0,5,0,4)
    title.BackgroundTransparency = 1; title.Text = "❄️ HEALTH"
    title.TextColor3 = Color3.fromRGB(180,220,255)
    title.Font = Enum.Font.GothamBold; title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    local hpT = Instance.new("TextLabel", f)
    hpT.Size = UDim2.new(1,-10,0,18); hpT.Position = UDim2.new(0,5,0,20)
    hpT.BackgroundTransparency = 1; hpT.Text = "100 / 100"
    hpT.TextColor3 = Color3.fromRGB(255,255,255)
    hpT.Font = Enum.Font.GothamBold; hpT.TextSize = 15
    hpT.TextXAlignment = Enum.TextXAlignment.Right
    local bg = Instance.new("Frame", f)
    bg.Size = UDim2.new(1,-10,0,12); bg.Position = UDim2.new(0,5,1,-16)
    bg.BackgroundColor3 = Color3.fromRGB(40,40,45); bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,4)
    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new(1,0,1,0)
    fill.BackgroundColor3 = Color3.fromRGB(100,180,255)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,4)
    State.HPGui = sg; State.HPText = hpT; State.HPBar = fill
end
function HP.Update()
    if not State.ShowOwnHP or not State.HPGui then return end
    local h = GetHuman(); if not h then return end
    local hp = math.floor(h.Health); local mx = math.floor(h.MaxHealth)
    local pct = mx > 0 and hp/mx or 0
    State.HPText.Text = hp.." / "..mx
    State.HPBar.Size = UDim2.new(pct,0,1,0)
    State.HPBar.BackgroundColor3 = pct>0.6 and Color3.fromRGB(100,180,255)
        or pct>0.3 and Color3.fromRGB(255,180,60)
        or Color3.fromRGB(255,50,50)
end
function HP.SetVisible(v)
    State.ShowOwnHP = v
    if v then
        if not State.HPGui then HP.Create() end
        HP.Update()
    else
        if State.HPGui then pcall(function() State.HPGui:Destroy() end); State.HPGui = nil end
    end
end
CM:Add(RunService.Heartbeat, function()
    if State.ShowOwnHP then pcall(HP.Update) end
end, "HP_HB")

-- ═══════════════════════════════════════════
-- STATS
-- ═══════════════════════════════════════════
local Stats = {}
function Stats.Create()
    if State.StatsGui then pcall(function() State.StatsGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Stats"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.Parent = GuiParent()
    local f = Instance.new("Frame", sg)
    f.Size = UDim2.new(0, 180, 0, 100)
    f.Position = UDim2.new(1, -195, 0, 120)
    f.BackgroundColor3 = Color3.fromRGB(15,15,20)
    f.BackgroundTransparency = 0.2
    f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8)
    local st = Instance.new("UIStroke", f)
    st.Color = Color3.fromRGB(100,180,255); st.Thickness = 1.5
    local function Row(y, name)
        local l = Instance.new("TextLabel", f)
        l.Size = UDim2.new(1,-10,0,18); l.Position = UDim2.new(0,5,0,y)
        l.BackgroundTransparency = 1; l.Text = name..": 0"
        l.TextColor3 = Color3.fromRGB(200,220,255)
        l.Font = Enum.Font.GothamBold; l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Name = name
        return l
    end
    local t = Instance.new("TextLabel", f)
    t.Size = UDim2.new(1,-10,0,18); t.Position = UDim2.new(0,5,0,4)
    t.BackgroundTransparency = 1; t.Text = "❄️ STATS"
    t.TextColor3 = Color3.fromRGB(100,200,255)
    t.Font = Enum.Font.GothamBold; t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    Stats.K = Row(22, "Kills")
    Stats.D = Row(40, "Deaths")
    Stats.H = Row(58, "Hits")
    Stats.T = Row(76, "Throws")
    State.StatsGui = sg
end
function Stats.Update()
    if not State.StatsGui then return end
    Stats.K.Text = "Kills:  "..State.Kills
    Stats.D.Text = "Deaths: "..State.Deaths
    Stats.H.Text = "Hits:   "..State.Hits
    Stats.T.Text = "Throws: "..State.Throws
end
CM:Add(RunService.Heartbeat, function()
    if State.StatsGui then pcall(Stats.Update) end
end, "Stats_HB")

-- ═══════════════════════════════════════════
-- KILL TRACKER
-- ═══════════════════════════════════════════
task.spawn(function()
    local prev = {}
    while task.wait(0.3) do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h then
                    local pv = prev[p] or h.MaxHealth
                    if h.Health <= 0 and pv > 0 then
                        State.Kills = State.Kills + 1
                        Notify("🎯 Kill!", p.Name.." got snowballed!", 2)
                    end
                    prev[p] = h.Health
                end
            end
        end
    end
end)

-- Track own damage
if R.GetHurt then
    CM:Add(R.GetHurt.OnClientEvent, function()
        State.Hits = State.Hits + 1
    end, "HurtTrack")
end

-- ═══════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════
KB.Register("AutoThrow", Enum.KeyCode.T, function()
    State.AutoThrow = not State.AutoThrow
    Snow.SetAutoThrow(State.AutoThrow)
    Notify("Auto Throw", State.AutoThrow and "ON" or "OFF", 1.5)
end)
KB.Register("AutoDodge", Enum.KeyCode.Y, function()
    State.AutoDodge = not State.AutoDodge
    Snow.SetAutoDodge(State.AutoDodge)
    Notify("Auto Dodge", State.AutoDodge and "ON" or "OFF", 1.5)
end)
KB.Register("AutoStandup", Enum.KeyCode.U, function()
    State.AutoStandup = not State.AutoStandup
    Snow.SetAutoStandup(State.AutoStandup)
    Notify("Auto Standup", State.AutoStandup and "ON" or "OFF", 1.5)
end)
KB.Register("AimAssist", Enum.KeyCode.Z, function()
    State.AimAssist = not State.AimAssist
    Aim.Set(State.AimAssist or State.AutoAim)
    Notify("Aim Assist", State.AimAssist and "ON" or "OFF", 1.5)
end)
KB.Register("AutoAim", Enum.KeyCode.E, function()
    State.AutoAim = not State.AutoAim
    Aim.Set(State.AutoAim or State.AimAssist)
    Notify("Auto Aim", State.AutoAim and "ON" or "OFF", 1.5)
end)
KB.Register("GodMode", Enum.KeyCode.G, function()
    State.GodMode = not State.GodMode
    Snow.SetGod(State.GodMode)
    Notify("God Mode", State.GodMode and "ON" or "OFF", 1.5)
end)
KB.Register("SpeedBoost", Enum.KeyCode.B, function()
    State.SpeedBoost = not State.SpeedBoost
    local h = GetHuman()
    if h then h.WalkSpeed = State.SpeedBoost and State.SpeedValue or State.WalkSpeed end
    Notify("Speed", State.SpeedBoost and "ON" or "OFF", 1.5)
end)
KB.Register("NoClip", Enum.KeyCode.N, function()
    State.NoClip = not State.NoClip
    Move.SetNoClip(State.NoClip)
    Notify("NoClip", State.NoClip and "ON" or "OFF", 1.5)
end)
KB.Register("InfJump", Enum.KeyCode.J, function()
    State.InfJump = not State.InfJump
    Move.SetInfJump(State.InfJump)
    Notify("Inf Jump", State.InfJump and "ON" or "OFF", 1.5)
end)
KB.Register("FullBright", Enum.KeyCode.L, function()
    State.FullBright = not State.FullBright
    Vis.FullBright(State.FullBright)
    Notify("FullBright", State.FullBright and "ON" or "OFF", 1.5)
end)
KB.Register("Freecam", Enum.KeyCode.V, function()
    State.Freecam = not State.Freecam
    Vis.Freecam(State.Freecam)
    Notify("Freecam", State.Freecam and "ON" or "OFF", 1.5)
end)
KB.Register("HPBar", Enum.KeyCode.H, function()
    HP.SetVisible(not State.ShowOwnHP)
end)
KB.Register("PlayerESP", Enum.KeyCode.F1, function()
    State.ESP_Players = not State.ESP_Players
    ESP.RefreshAll()
    Notify("Player ESP", State.ESP_Players and "ON" or "OFF", 1.5)
end)
KB.Register("BallESP", Enum.KeyCode.F2, function()
    State.ESP_Balls = not State.ESP_Balls
    if not State.ESP_Balls then
        for o in pairs(State.ESPCache) do
            if not Players:GetPlayerFromCharacter(o) then ESP.Remove(o) end
        end
    else ESP.ScanBalls() end
    Notify("Ball ESP", State.ESP_Balls and "ON" or "OFF", 1.5)
end)
KB.Register("TPNearest", Enum.KeyCode.X, function()
    Move.TPNearest()
end)
KB.Register("ServerHop", Enum.KeyCode.M, function()
    Move.ServerHop()
end)
KB.Register("PanicClear", Enum.KeyCode.End, function()
    State.ESP_Players = false; State.ESP_Balls = false
    ESP.ClearAll()
    Notify("Panic", "ESP cleared", 1.5)
end)
KB.Register("AntiPush", Enum.KeyCode.P, function()
    State.AntiPush = not State.AntiPush
    Snow.SetAntiPush(State.AntiPush)
    Notify("Anti Push", State.AntiPush and "ON" or "OFF", 1.5)
end)
KB.Register("ManualThrow", Enum.KeyCode.R, function()
    local t = PH.Nearest()
    if t and t.Character then
        local erp = GetRoot(t.Character)
        if erp then
            FirePushBall(erp.Position + Vector3.new(0,2,0), t)
            SimulateThrowInput()
            Notify("Throw", "→ "..t.Name, 1)
        end
    end
end)

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local HUB = { Name="X0DEC04T", Game="Snowball Battles", Ver="1.1.0", Author="voixera" }

local Window = Rayfield:CreateWindow({
    Name = "❄️ "..HUB.Name.." v"..HUB.Ver.." - "..HUB.Game,
    LoadingTitle = HUB.Name.." | Snowball Battles",
    LoadingSubtitle = "by "..HUB.Author,
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {k="Main", n="Main", i="home"},
    {k="Combat", n="Combat", i="sword"},
    {k="Aim", n="Aim", i="crosshair"},
    {k="ESP", n="ESP", i="eye"},
    {k="Movement", n="Movement", i="footprints"},
    {k="Visuals", n="Visuals", i="sun"},
    {k="Misc", n="Misc", i="wrench"},
    {k="Keybinds", n="Keybinds", i="keyboard"},
    {k="Settings", n="Settings", i="settings"},
}) do
    local ok, t = pcall(function() return Window:CreateTab(def.n, def.i) end)
    if ok and t then Tabs[def.k] = t end
end

local function MakeKB(name)
    return function(k)
        local ok, key = pcall(function() return Enum.KeyCode[k] end)
        if ok and key then KB.SetKey(name, key) end
    end
end

-- MAIN
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("❄️ Snowball Battles Hub v"..HUB.Ver)
    T:CreateLabel("by "..HUB.Author)
    T:CreateSection("Remote Status")
    T:CreateLabel("PushBall (throw):  "..(R.PushBall and "✅ Found" or "❌ Missing"))
    T:CreateLabel("Standup (dodge):   "..(R.Standup and "✅ Found" or "❌ Missing"))
    T:CreateLabel("GetHurt (listener):"..(R.GetHurt and "✅ Found" or "❌ Missing"))
    T:CreateLabel("Skill Remote:      "..(R.SkillReceiver and "✅ Found" or "❌ Missing"))
    T:CreateSection("Quick Keys")
    T:CreateLabel("T=AutoThrow | Y=AutoDodge | U=AutoStandup")
    T:CreateLabel("E=AutoAim | Z=AimAssist | R=Manual Throw")
    T:CreateLabel("G=GodMode | B=Speed | N=NoClip | J=InfJump")
    T:CreateLabel("H=HPBar | L=FullBright | V=Freecam | P=AntiPush")
    T:CreateLabel("F1=PlayerESP | F2=BallESP | X=TP Enemy")
    T:CreateLabel("M=ServerHop | End=PanicClear")
    T:CreateSection("Quick Actions")
    T:CreateButton({Name="Throw at Nearest", Callback=function()
        local t = PH.Nearest()
        if t and t.Character then
            local erp = GetRoot(t.Character)
            if erp then
                FirePushBall(erp.Position + Vector3.new(0,2,0), t)
                SimulateThrowInput()
                Notify("Throw", "→ "..t.Name, 1)
            end
        end
    end})
    T:CreateButton({Name="Force Standup", Callback=function()
        if R.Standup then pcall(function() R.Standup:FireServer() end) end
        local h = GetHuman()
        if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
        Notify("Standup", "Fired", 1)
    end})
end

-- COMBAT
if Tabs.Combat then
    local T = Tabs.Combat
    T:CreateSection("Auto Throw [T]")
    T:CreateToggle({Name="Enable Auto Throw", CurrentValue=false, Flag="AT",
        Callback=function(v) State.AutoThrow=v; Snow.SetAutoThrow(v) end})
    T:CreateDropdown({Name="Target Selection",
        Options={"Nearest","Aim Target","Lowest HP","Random"},
        CurrentOption={"Nearest"}, Flag="ATTG",
        Callback=function(v) State.ThrowTarget=(type(v)=="table" and v[1]) or v end})
    T:CreateSlider({Name="Throw Delay (x0.05s)", Range={1,30}, Increment=1,
        CurrentValue=6, Flag="ATD",
        Callback=function(v) State.ThrowDelay=(tonumber(v) or 6)*0.05 end})
    T:CreateSlider({Name="Throw Range", Range={20,400}, Increment=10,
        CurrentValue=150, Flag="ATR",
        Callback=function(v) State.ThrowRange=tonumber(v) or 150 end})
    T:CreateSlider({Name="Throw Power", Range={20,300}, Increment=10,
        CurrentValue=100, Flag="ATP",
        Callback=function(v) State.ThrowPower=tonumber(v) or 100 end})
    T:CreateToggle({Name="Auto Lead (predict movement)", CurrentValue=true, Flag="AL",
        Callback=function(v) State.AutoLead=v end})
    T:CreateButton({Name="Manual Throw [R]", Callback=function()
        local t = PH.Nearest()
        if t and t.Character then
            local erp = GetRoot(t.Character)
            if erp then
                FirePushBall(erp.Position + Vector3.new(0,2,0), t)
                SimulateThrowInput()
                Notify("Throw", "→ "..t.Name, 1)
            end
        end
    end})

    T:CreateSection("Auto Dodge [Y]")
    T:CreateToggle({Name="Enable Auto Dodge", CurrentValue=false, Flag="AD",
        Callback=function(v) State.AutoDodge=v; Snow.SetAutoDodge(v) end})
    T:CreateSlider({Name="Detection Range", Range={5,60}, Increment=5,
        CurrentValue=20, Flag="ADR",
        Callback=function(v) State.DodgeRange=tonumber(v) or 20 end})
    T:CreateSlider({Name="Dodge Cooldown (x0.1s)", Range={2,20}, Increment=1,
        CurrentValue=6, Flag="ADC",
        Callback=function(v) State.DodgeCD=(tonumber(v) or 6)*0.1 end})

    T:CreateSection("Auto Standup [U]")
    T:CreateToggle({Name="Auto Standup When Knocked", CurrentValue=true, Flag="AS",
        Callback=function(v) State.AutoStandup=v; Snow.SetAutoStandup(v) end})

    T:CreateSection("Defense")
    T:CreateToggle({Name="God Mode [G]", CurrentValue=false, Flag="GM",
        Callback=function(v) State.GodMode=v; Snow.SetGod(v) end})
    T:CreateToggle({Name="Anti-Push [P]", CurrentValue=false, Flag="APU",
        Callback=function(v) State.AntiPush=v; Snow.SetAntiPush(v) end})

    T:CreateSection("Auto Skill")
    T:CreateToggle({Name="Auto Use Skill", CurrentValue=false, Flag="ASK",
        Callback=function(v) State.AutoSkill=v; Snow.SetAutoSkill(v) end})
    T:CreateSlider({Name="Skill Delay (x0.5s)", Range={1,10}, Increment=1,
        CurrentValue=2, Flag="ASD",
        Callback=function(v) State.SkillDelay=(tonumber(v) or 2)*0.5 end})
end

-- AIM
if Tabs.Aim then
    local T = Tabs.Aim
    T:CreateSection("Aim Assist [Z] | Auto Aim [E]")
    T:CreateToggle({Name="Aim Assist (hold RMB to lock)", CurrentValue=false, Flag="AA1",
        Callback=function(v) State.AimAssist=v; Aim.Set(v or State.AutoAim) end})
    T:CreateToggle({Name="Auto Aim (always lock nearest)", CurrentValue=false, Flag="AA2",
        Callback=function(v) State.AutoAim=v; Aim.Set(v or State.AimAssist) end})
    T:CreateSlider({Name="Smoothing (x0.05)", Range={1,20}, Increment=1,
        CurrentValue=4, Flag="AAS",
        Callback=function(v) State.AimSmoothing=(tonumber(v) or 4)*0.05 end})
    T:CreateSlider({Name="FOV Radius", Range={50,500}, Increment=10,
        CurrentValue=150, Flag="AAF",
        Callback=function(v)
            State.AimFOV=tonumber(v) or 150
            if State.ShowFOVCircle then Aim.DrawCircle() end
        end})
    T:CreateDropdown({Name="Target Bone",
        Options={"Head","HumanoidRootPart","Torso","UpperTorso"},
        CurrentOption={"HumanoidRootPart"}, Flag="AAB",
        Callback=function(v) State.AimBone=(type(v)=="table" and v[1]) or v end})
    T:CreateToggle({Name="Show FOV Circle", CurrentValue=false, Flag="AAC",
        Callback=function(v) State.ShowFOVCircle=v; Aim.DrawCircle() end})
end

-- ESP
if Tabs.ESP then
    local T = Tabs.ESP
    T:CreateSection("Player ESP [F1]")
    T:CreateToggle({Name="Player ESP", CurrentValue=false, Flag="E1",
        Callback=function(v)
            State.ESP_Players=v
            if not v then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then ESP.Remove(p.Character) end
                end
            else ESP.ScanPlayers() end
        end})
    T:CreateToggle({Name="Show HP", CurrentValue=true, Flag="E2",
        Callback=function(v) State.ESP_ShowHP=v end})
    T:CreateToggle({Name="Show Name", CurrentValue=true, Flag="E3",
        Callback=function(v) State.ESP_ShowName=v end})
    T:CreateToggle({Name="Show Distance", CurrentValue=true, Flag="E4",
        Callback=function(v) State.ESP_ShowDist=v end})

    T:CreateSection("Ball ESP [F2]")
    T:CreateToggle({Name="Snowball ESP", CurrentValue=false, Flag="E5",
        Callback=function(v)
            State.ESP_Balls=v
            if not v then
                for o in pairs(State.ESPCache) do
                    if not Players:GetPlayerFromCharacter(o) then ESP.Remove(o) end
                end
            else ESP.ScanBalls() end
        end})

    T:CreateSection("Settings")
    T:CreateSlider({Name="Max Distance", Range={50,3000}, Increment=50,
        CurrentValue=800, Flag="E6",
        Callback=function(v) State.ESP_MaxDist=tonumber(v) or 800 end})

    T:CreateSection("Actions")
    T:CreateButton({Name="Refresh ESP", Callback=function()
        ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2)
    end})
    T:CreateButton({Name="Clear All ESP [End]", Callback=function()
        ESP.ClearAll(); Notify("ESP","Cleared",2)
    end})
end

-- MOVEMENT
if Tabs.Movement then
    local T = Tabs.Movement
    T:CreateSection("Speed & Jump")
    T:CreateSlider({Name="Walk Speed", Range={16,200}, Increment=1,
        CurrentValue=16, Flag="M1",
        Callback=function(v)
            State.WalkSpeed=tonumber(v) or 16
            if not State.SpeedBoost then Move.Speed() end
        end})
    T:CreateSlider({Name="Jump Power", Range={50,500}, Increment=5,
        CurrentValue=50, Flag="M2",
        Callback=function(v) State.JumpPower=tonumber(v) or 50; Move.Jump() end})
    T:CreateToggle({Name="Speed Boost [B]", CurrentValue=false, Flag="M3",
        Callback=function(v)
            State.SpeedBoost=v
            local h=GetHuman()
            if h then h.WalkSpeed = v and State.SpeedValue or State.WalkSpeed end
        end})
    T:CreateSlider({Name="Boost Speed Value", Range={20,150}, Increment=5,
        CurrentValue=40, Flag="M4",
        Callback=function(v)
            State.SpeedValue=tonumber(v) or 40
            if State.SpeedBoost then
                local h=GetHuman()
                if h then h.WalkSpeed=State.SpeedValue end
            end
        end})
    T:CreateSection("Advanced")
    T:CreateToggle({Name="NoClip [N]", CurrentValue=false, Flag="M5",
        Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end})
    T:CreateToggle({Name="Infinite Jump [J]", CurrentValue=false, Flag="M6",
        Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end})
    T:CreateSection("Teleport [X]")
    T:CreateButton({Name="TP to Nearest [X]", Callback=Move.TPNearest})
    T:CreateInput({Name="Player Name", PlaceholderText="Username...",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.TPTarget=tostring(v or "") end})
    T:CreateButton({Name="TP to Player", Callback=function()
        Move.TPPlayer(State.TPTarget)
    end})
end

-- VISUALS
if Tabs.Visuals then
    local T = Tabs.Visuals
    T:CreateSection("Lighting")
    T:CreateToggle({Name="FullBright [L]", CurrentValue=false, Flag="V1",
        Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    T:CreateToggle({Name="No Fog", CurrentValue=false, Flag="V2",
        Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    T:CreateToggle({Name="No Shadows", CurrentValue=false, Flag="V3",
        Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end})
    T:CreateSection("Camera")
    T:CreateSlider({Name="FOV", Range={30,120}, Increment=5, CurrentValue=70, Flag="V4",
        Callback=function(v) State.FOV=tonumber(v) or 70; Vis.FOV(State.FOV) end})
    T:CreateToggle({Name="Freecam [V]", CurrentValue=false, Flag="V5",
        Callback=function(v) State.Freecam=v; Vis.Freecam(v) end})
    T:CreateSection("Effects")
    T:CreateToggle({Name="Remove Blur/Bloom", CurrentValue=false, Flag="V6",
        Callback=function(v) State.RemoveBlur=v; Vis.PostFX(v) end})
    T:CreateToggle({Name="No Particles/Snow FX", CurrentValue=false, Flag="V7",
        Callback=function(v) State.NoParticles=v; Vis.Particles(v) end})
    T:CreateSection("Performance")
    T:CreateToggle({Name="Low Graphics", CurrentValue=false, Flag="V8",
        Callback=function(v) State.LowGfx=v; Vis.LowGfx(v) end})
    T:CreateSection("HUD")
    T:CreateToggle({Name="HP Bar [H]", CurrentValue=false, Flag="V9",
        Callback=function(v) HP.SetVisible(v) end})
    T:CreateToggle({Name="Stats Overlay", CurrentValue=false, Flag="V10",
        Callback=function(v)
            State.ShowStats=v
            if v then Stats.Create(); Stats.Update()
            else
                if State.StatsGui then pcall(function() State.StatsGui:Destroy() end); State.StatsGui=nil end
            end
        end})
    T:CreateSection("Character")
    T:CreateToggle({Name="Hide Name Tag", CurrentValue=false, Flag="V11",
        Callback=function(v) State.HideName=v; Vis.HideName(v) end})
end

-- MISC
if Tabs.Misc then
    local T = Tabs.Misc
    T:CreateSection("Audio")
    T:CreateToggle({Name="Mute All Sounds", CurrentValue=false, Flag="X1",
        Callback=function(v) Vis.MuteAll(v) end})
    T:CreateSection("Server [M]")
    T:CreateButton({Name="Server Hop", Callback=Move.ServerHop})
    T:CreateButton({Name="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end})
    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","Job ID",2) end
    end})
    T:CreateSection("Reward")
    T:CreateInput({Name="Redeem Code", PlaceholderText="Code...",
        RemoveTextAfterFocusLost=true,
        Callback=function(v)
            if R.RedeemCode then
                pcall(function() R.RedeemCode:FireServer(v) end)
                Notify("Code","Sent: "..v,2)
            end
        end})
    T:CreateButton({Name="Claim Daily Reward", Callback=function()
        if R.DailyClaim then
            pcall(function() R.DailyClaim:FireServer() end)
            Notify("Daily","Claimed",2)
        end
    end})
    T:CreateSection("Debug")
    T:CreateButton({Name="Reset Stats", Callback=function()
        State.Kills=0; State.Deaths=0; State.Hits=0; State.Throws=0
        Notify("Stats","Reset",2)
    end})
end

-- KEYBINDS
if Tabs.Keybinds then
    local T = Tabs.Keybinds
    T:CreateSection("Combat")
    T:CreateKeybind({Name="Auto Throw", CurrentKeybind="T", Flag="KB1",
        HoldToInteract=false, Callback=MakeKB("AutoThrow")})
    T:CreateKeybind({Name="Manual Throw", CurrentKeybind="R", Flag="KB2",
        HoldToInteract=false, Callback=MakeKB("ManualThrow")})
    T:CreateKeybind({Name="Auto Dodge", CurrentKeybind="Y", Flag="KB3",
        HoldToInteract=false, Callback=MakeKB("AutoDodge")})
    T:CreateKeybind({Name="Auto Standup", CurrentKeybind="U", Flag="KB4",
        HoldToInteract=false, Callback=MakeKB("AutoStandup")})
    T:CreateKeybind({Name="God Mode", CurrentKeybind="G", Flag="KB5",
        HoldToInteract=false, Callback=MakeKB("GodMode")})
    T:CreateKeybind({Name="Anti-Push", CurrentKeybind="P", Flag="KB6",
        HoldToInteract=false, Callback=MakeKB("AntiPush")})
    T:CreateSection("Aim")
    T:CreateKeybind({Name="Aim Assist", CurrentKeybind="Z", Flag="KB7",
        HoldToInteract=false, Callback=MakeKB("AimAssist")})
    T:CreateKeybind({Name="Auto Aim", CurrentKeybind="E", Flag="KB8",
        HoldToInteract=false, Callback=MakeKB("AutoAim")})
    T:CreateSection("Movement")
    T:CreateKeybind({Name="Speed Boost", CurrentKeybind="B", Flag="KB9",
        HoldToInteract=false, Callback=MakeKB("SpeedBoost")})
    T:CreateKeybind({Name="NoClip", CurrentKeybind="N", Flag="KB10",
        HoldToInteract=false, Callback=MakeKB("NoClip")})
    T:CreateKeybind({Name="Infinite Jump", CurrentKeybind="J", Flag="KB11",
        HoldToInteract=false, Callback=MakeKB("InfJump")})
    T:CreateKeybind({Name="TP Nearest", CurrentKeybind="X", Flag="KB12",
        HoldToInteract=false, Callback=MakeKB("TPNearest")})
    T:CreateSection("Visuals")
    T:CreateKeybind({Name="FullBright", CurrentKeybind="L", Flag="KB13",
        HoldToInteract=false, Callback=MakeKB("FullBright")})
    T:CreateKeybind({Name="Freecam", CurrentKeybind="V", Flag="KB14",
        HoldToInteract=false, Callback=MakeKB("Freecam")})
    T:CreateKeybind({Name="HP Bar", CurrentKeybind="H", Flag="KB15",
        HoldToInteract=false, Callback=MakeKB("HPBar")})
    T:CreateSection("ESP")
    T:CreateKeybind({Name="Player ESP", CurrentKeybind="F1", Flag="KB16",
        HoldToInteract=false, Callback=MakeKB("PlayerESP")})
    T:CreateKeybind({Name="Ball ESP", CurrentKeybind="F2", Flag="KB17",
        HoldToInteract=false, Callback=MakeKB("BallESP")})
    T:CreateSection("Misc")
    T:CreateKeybind({Name="Server Hop", CurrentKeybind="M", Flag="KB18",
        HoldToInteract=false, Callback=MakeKB("ServerHop")})
    T:CreateKeybind({Name="Panic Clear", CurrentKeybind="End", Flag="KB19",
        HoldToInteract=false, Callback=MakeKB("PanicClear")})
end

-- SETTINGS
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="S1",
        Callback=function(v) State.AntiAFK=v end})
    T:CreateToggle({Name="Auto Rejoin on Kick", CurrentValue=false, Flag="S2",
        Callback=function(v) State.AutoRejoin=v end})
    T:CreateSection("Credits")
    T:CreateLabel(HUB.Name.." v"..HUB.Ver)
    T:CreateLabel("Game: "..HUB.Game)
    T:CreateLabel("Author: "..HUB.Author)
    T:CreateSection("⚠️ Danger")
    T:CreateButton({Name="Unload Hub", Callback=function()
        local conns = {"NoClipConn","InfJumpConn","FreecamConn","GodModeConn",
            "AutoThrowConn","AutoDodgeConn","AimConn","StandupConn","HurtConn",
            "AntiPushConn","AutoSkillConn"}
        for _, k in ipairs(conns) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        for _, s in pairs({State.AimCircle, State.HPGui, State.StatsGui, ESPGui}) do
            if s then pcall(function() s:Destroy() end) end
        end
        if ESPRender then ESPRender:Disconnect() end
        ESP.ClearAll(); CM:Cleanup(); Vis.Restore()
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView=70 end)
        _G[INSTANCE_KEY]=nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- ═══════════════════════════════════════════
-- ANTI-AFK
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end, "AFK")

-- ═══════════════════════════════════════════
-- RESPAWN
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.CharacterAdded, function()
    State.Deaths = State.Deaths + 1
    task.wait(1.5)
    pcall(Move.Speed); pcall(Move.Jump)
    if State.NoClip then pcall(Move.SetNoClip, true) end
    if State.InfJump then pcall(Move.SetInfJump, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.NoFog then pcall(Vis.NoFog, true) end
    if State.HideName then pcall(Vis.HideName, true) end
    if State.FOV ~= 70 then Vis.FOV(State.FOV) end
    if State.SpeedBoost then
        local h = GetHuman()
        if h then h.WalkSpeed = State.SpeedValue end
    end
    if State.GodMode then pcall(Snow.SetGod, true) end
    if State.AutoThrow then pcall(Snow.SetAutoThrow, true) end
    if State.AutoDodge then pcall(Snow.SetAutoDodge, true) end
    if State.AutoStandup then pcall(Snow.SetAutoStandup, true) end
    if State.AntiPush then pcall(Snow.SetAntiPush, true) end
    if State.AutoSkill then pcall(Snow.SetAutoSkill, true) end
    if State.AimAssist or State.AutoAim then pcall(Aim.Set, true) end
    if State.ShowOwnHP then pcall(HP.Create) end
    task.wait(0.5); ESP.RefreshAll()
end, "CharAdded")

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
end, "TP")

-- Refresh full bright/no fog periodically
task.spawn(function()
    while task.wait(5) do
        if State.FullBright then pcall(Vis.FullBright, true) end
        if State.NoFog then pcall(Vis.NoFog, true) end
    end
end)

-- ═══════════════════════════════════════════
-- GLOBAL INSTANCE
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version = HUB.Ver,
    destroy = function()
        for _, k in ipairs({"NoClipConn","InfJumpConn","FreecamConn","GodModeConn",
            "AutoThrowConn","AutoDodgeConn","AimConn","StandupConn","HurtConn",
            "AntiPushConn","AutoSkillConn"}) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        for _, s in pairs({State.AimCircle, State.HPGui, State.StatsGui, ESPGui}) do
            if s then pcall(function() s:Destroy() end) end
        end
        if ESPRender then ESPRender:Disconnect() end
        ESP.ClearAll(); CM:Cleanup(); Vis.Restore()
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView=70 end)
        pcall(function() Rayfield:Destroy() end)
    end,
}

Notify("❄️ Snowball Battles Hub", "v"..HUB.Ver.." loaded!", 5)
Log("Ready!")
