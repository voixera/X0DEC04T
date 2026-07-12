--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v2.0.0 - Snowball Battles [GAMEPLAY EDITION]
-- PlaceID: 106701494743444
-- Gameplay: Roll snowball → grow big → push enemies off map
-- Features: Auto Grow, Auto Push, Anti-Knockoff, Auto Vote,
--           Edge Guard, Target Weakest, Ram Enemies, ESP,
--           Fly, Speed, God Mode, Auto Skill, and more
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
local INSTANCE_KEY = "__X0DEC04T_SnowballBattles_v200"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[SB2][+%.2fs] %s", os.clock()-_t0, tostring(m))) end
Log("Snowball Battles Hub v2.0.0 loading...")

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
function CM:Add(sig, cb)
    if not sig then return end
    local ok, c = pcall(function() return sig:Connect(cb) end)
    if ok and c then table.insert(self._list, c); return c end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

-- ═══════════════════════════════════════════
-- KEYBIND MANAGER
-- ═══════════════════════════════════════════
local KB = { _binds = {} }
function KB.Register(name, key, cb)
    KB._binds[name] = { key=key or Enum.KeyCode.Unknown, callback=cb, enabled=true }
end
function KB.SetKey(name, k) if KB._binds[name] then KB._binds[name].key=k end end

CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    for _, b in pairs(KB._binds) do
        if b.enabled and b.key == inp.KeyCode then pcall(b.callback) end
    end
end)

-- ═══════════════════════════════════════════
-- REMOTES (from your diagnostic)
-- ═══════════════════════════════════════════
local Remote = ReplicatedStorage:WaitForChild("Remote", 10)
local R = {
    PushBall     = Remote and Remote:FindFirstChild("Fight") and Remote.Fight:FindFirstChild("PushBall"),
    Standup      = Remote and Remote:FindFirstChild("Fight") and Remote.Fight:FindFirstChild("Standup"),
    GetHurt      = Remote and Remote:FindFirstChild("Fight") and Remote.Fight:FindFirstChild("GetHurt"),
    Health       = Remote and Remote:FindFirstChild("GameGUI") and Remote.GameGUI:FindFirstChild("Health"),
    Vote         = Remote and Remote:FindFirstChild("MapVoter") and Remote.MapVoter:FindFirstChild("Vote"),
    NotifyVotes  = Remote and Remote:FindFirstChild("MapVoter") and Remote.MapVoter:FindFirstChild("NotifyVotes"),
    JoinGame     = Remote and Remote:FindFirstChild("PlaytestGUI") and Remote.PlaytestGUI:FindFirstChild("JoinGame"),
    SkillRcv     = Remote and Remote:FindFirstChild("Skill") and Remote.Skill:FindFirstChild("SkillReceiver"),
    SkillBuff    = Remote and Remote:FindFirstChild("Skill") and Remote.Skill:FindFirstChild("SkillBuffReceiver"),
    SpeedHit     = Remote and Remote:FindFirstChild("Skill") and Remote.Skill:FindFirstChild("SpeedHit"),
    PlayAnim     = Remote and Remote:FindFirstChild("Anim") and Remote.Anim:FindFirstChild("CharacterPlayAnim"),
    RedeemCode   = Remote and Remote:FindFirstChild("Reward") and Remote.Reward:FindFirstChild("RedeemCode"),
    DailyClaim   = Remote and Remote:FindFirstChild("Reward") and Remote.Reward:FindFirstChild("DailyRewardClaim"),
    Spectate     = Remote and Remote:FindFirstChild("SpectateGUI") and Remote.SpectateGUI:FindFirstChild("SpectateTargetPlayer"),
    Revenge      = Remote and Remote:FindFirstChild("SpectateGUI") and Remote.SpectateGUI:FindFirstChild("RevengeByTicket"),
}
Log("PushBall: "..(R.PushBall and "✓" or "✗"))
Log("Standup:  "..(R.Standup and "✓" or "✗"))
Log("Vote:     "..(R.Vote and "✓" or "✗"))

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- === CORE GAMEPLAY ===
    AutoGrow          = false,     -- roll around to grow snowball
    GrowPattern       = "Circle",  -- Circle, Zigzag, Spiral, Random, Nearest Snow
    GrowRadius        = 30,
    GrowSpeed         = 30,

    AutoRam           = false,     -- ram nearest enemy with snowball
    RamRange          = 100,
    RamMinBallSize    = 5,         -- only ram when ball is big enough
    RamSpeed          = 60,

    AutoPushOff       = false,     -- push enemies off the map
    PushForce         = 150,
    PushRange         = 20,

    AntiKnockoff      = false,     -- prevent being pushed off edges
    EdgeGuardDist     = 30,        -- warn distance from edge
    AntiFall          = false,     -- teleport back if falling

    AutoVote          = false,
    AutoVoteMap       = "First",   -- First, Random, Last

    AutoRejoin        = true,      -- auto rejoin after elimination

    -- === COMBAT REMOTES ===
    AutoPushBall      = false,     -- spam PushBall remote at nearest
    PushBallDelay     = 0.3,
    PushBallRange     = 100,

    AutoStandup       = true,
    AntiStun          = false,

    -- === AIM ===
    AimAssist         = false,
    AutoAim           = false,
    AimSmoothing      = 0.2,
    AimFOV            = 200,
    AimBone           = "HumanoidRootPart",
    AimTarget         = nil,

    -- === ESP ===
    ESP_Players       = false,
    ESP_Snowballs     = false,     -- big snowballs (yours or enemies')
    ESP_MapEdges      = false,     -- show death boundaries
    ESP_ShowHP        = true,
    ESP_ShowDist      = true,
    ESP_ShowName      = true,
    ESP_ShowSize      = true,      -- show snowball size
    ESP_MaxDist       = 1500,
    Color_Enemy       = Color3.fromRGB(255,50,50),
    Color_Self        = Color3.fromRGB(60,255,120),
    Color_Ball        = Color3.fromRGB(180,220,255),
    Color_Edge        = Color3.fromRGB(255,150,0),

    -- === MOVEMENT ===
    WalkSpeed         = 16,
    JumpPower         = 50,
    NoClip            = false,
    InfJump           = false,
    SpeedBoost        = false,
    SpeedValue        = 50,
    Fly               = false,
    FlySpeed          = 60,

    -- === VISUAL ===
    FullBright        = false,
    NoFog             = false,
    NoShadows         = false,
    FOV               = 70,
    Freecam           = false,
    RemoveBlur        = false,
    NoParticles       = false,
    LowGfx            = false,
    ShowOwnHP         = false,
    ShowStats         = false,
    ShowSnowballSize  = false,
    HideName          = false,

    -- === CHARACTER ===
    GodMode           = false,
    InfBallSize       = false,     -- try to keep snowball huge
    BallSizeMultiplier= 3,

    -- === AUTO SKILL ===
    AutoSkill         = false,
    SkillDelay        = 1.5,
    AutoRevenge       = false,

    -- === MISC ===
    AntiAFK           = true,
    TPTarget          = "",

    -- === CACHES / CONNECTIONS ===
    ESPCache          = {},
    LightBackup       = {},
    MutedSounds       = {},
    Kills             = 0,
    Deaths            = 0,
    Rejoins           = 0,

    AutoGrowConn      = nil,
    AutoRamConn       = nil,
    AutoPushOffConn   = nil,
    AntiKnockoffConn  = nil,
    AutoPushBallConn  = nil,
    AutoStandupConn   = nil,
    AimConn           = nil,
    GodConn           = nil,
    FlyConn           = nil,
    NoClipConn        = nil,
    InfJumpConn       = nil,
    FreecamConn       = nil,
    AntiFallConn      = nil,
    BallSizeConn      = nil,
    AutoSkillTask     = nil,

    HPGui             = nil,
    StatsGui          = nil,
    SnowballGui       = nil,
    EdgeGui           = nil,
}

-- ═══════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════
local function Gui()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    pcall(function()
        Rayfield:Notify({Title=t,Content=c,Duration=d or 3,Image=4483345998})
    end)
end
local function Char() return LocalPlayer.Character end
local function HRP()
    local c = Char(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function Hum()
    local c = Char(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetRoot(o)
    if not o then return nil end
    if o:IsA("BasePart") then return o end
    if o:IsA("Model") then
        return o:FindFirstChild("HumanoidRootPart")
            or o:FindFirstChild("Torso") or o:FindFirstChild("UpperTorso")
            or o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
    end
end

-- ═══════════════════════════════════════════
-- SNOWBALL DETECTOR
-- Finds your own snowball attached to character
-- ═══════════════════════════════════════════
local Snowball = {}

function Snowball.GetOwnBall()
    local char = Char(); if not char then return nil end
    -- Try common names for the snowball attached to character
    for _, v in ipairs(char:GetDescendants()) do
        local n = v.Name:lower()
        if v:IsA("BasePart") and (n:find("ball") or n:find("bola") or n:find("salju") or n:find("snow")) then
            return v
        end
    end
    -- Search workspace for ball owned by us
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n:find("ball") or n:find("bola") or n:find("salju") then
                if v:GetAttribute("Owner") == LocalPlayer.Name
                   or v:GetAttribute("Player") == LocalPlayer.Name then
                    return v
                end
            end
        end
    end
    return nil
end

function Snowball.GetSize(ball)
    if not ball then return 0 end
    return math.max(ball.Size.X, ball.Size.Y, ball.Size.Z)
end

function Snowball.GetAllBalls()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if (n:find("ball") or n:find("bola") or n:find("salju"))
               and v.Size.Magnitude > 1 then
                table.insert(list, v)
            end
        end
    end
    return list
end

function Snowball.GetPlayerBall(p)
    if not p or not p.Character then return nil end
    for _, v in ipairs(p.Character:GetDescendants()) do
        if v:IsA("BasePart") then
            local n = v.Name:lower()
            if n:find("ball") or n:find("bola") or n:find("salju") then
                return v
            end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            if v:GetAttribute("Owner") == p.Name
               or v:GetAttribute("Player") == p.Name then
                return v
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- PLAYERS HELPER
-- ═══════════════════════════════════════════
local PH = {}
function PH.Others()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then table.insert(list, p) end
        end
    end
    return list
end
function PH.Nearest()
    local hrp = HRP(); if not hrp then return nil end
    local best, bd = nil, math.huge
    for _, p in ipairs(PH.Others()) do
        local erp = GetRoot(p.Character)
        if erp then
            local d = (erp.Position-hrp.Position).Magnitude
            if d < bd then bd = d; best = p end
        end
    end
    return best, bd
end
function PH.WeakestBall()
    -- Enemy with smallest snowball (easiest to push off)
    local best, minSize = nil, math.huge
    for _, p in ipairs(PH.Others()) do
        local ball = Snowball.GetPlayerBall(p)
        local sz = ball and Snowball.GetSize(ball) or 0
        if sz < minSize then
            minSize = sz
            best = p
        end
    end
    return best
end
function PH.NearestToEdge()
    -- Enemy closest to falling off the map (easy kill)
    local best, bd = nil, math.huge
    for _, p in ipairs(PH.Others()) do
        local erp = GetRoot(p.Character)
        if erp then
            -- Find nearest ground below
            local ray = Workspace:Raycast(erp.Position,
                Vector3.new(0,-500,0),
                RaycastParams.new())
            local edgeDist = ray and ((erp.Position - ray.Position).Magnitude) or 999
            if edgeDist > 20 then -- likely near edge
                local hrp = HRP()
                if hrp then
                    local d = (erp.Position - hrp.Position).Magnitude
                    if d < bd then bd = d; best = p end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════
-- MAP EDGE DETECTION
-- ═══════════════════════════════════════════
local Map = {}

function Map.RayDown(from, dist)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = {Char()}
    return Workspace:Raycast(from, Vector3.new(0,-(dist or 500),0), rp)
end

function Map.DistToEdge()
    -- Cast in 8 directions to find nearest edge
    local hrp = HRP(); if not hrp then return 999, Vector3.zero end
    local pos = hrp.Position
    local minDist, edgeDir = 999, Vector3.zero
    for _, dir in ipairs({
        Vector3.new(1,0,0), Vector3.new(-1,0,0),
        Vector3.new(0,0,1), Vector3.new(0,0,-1),
        Vector3.new(1,0,1).Unit, Vector3.new(-1,0,1).Unit,
        Vector3.new(1,0,-1).Unit, Vector3.new(-1,0,-1).Unit,
    }) do
        for step = 5, 200, 5 do
            local checkPos = pos + dir*step
            local ray = Map.RayDown(checkPos + Vector3.new(0,5,0), 30)
            if not ray then -- no ground below = edge
                if step < minDist then
                    minDist = step; edgeDir = dir
                end
                break
            end
        end
    end
    return minDist, edgeDir
end

function Map.IsOverVoid()
    local hrp = HRP(); if not hrp then return false end
    local ray = Map.RayDown(hrp.Position + Vector3.new(0,5,0), 100)
    return ray == nil
end

-- ═══════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════
local ESPGui
do
    local old = Gui():FindFirstChild("X0_SB2_ESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "X0_SB2_ESP"; ESPGui.ResetOnSpawn=false
    ESPGui.IgnoreGuiInset=true; ESPGui.DisplayOrder=999
    ESPGui.Parent = Gui()
end

local ESP = {}
local ESPRender

local function MakeESP(obj, label, color, isChar)
    local rp = GetRoot(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency=isChar and 0.45 or 0.6
    hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=Workspace
    local bb = Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,220,0, isChar and 85 or 45)
    bb.AlwaysOnTop=true; bb.LightInfluence=0
    bb.MaxDistance=State.ESP_MaxDist; bb.ResetOnSpawn=false
    bb.Adornee=rp; bb.Parent=ESPGui
    local nl = Instance.new("TextLabel", bb)
    nl.Size=UDim2.new(1,0,0,20); nl.BackgroundTransparency=1
    nl.Text=label; nl.TextColor3=color
    nl.TextStrokeTransparency=0.35; nl.Font=Enum.Font.GothamBold; nl.TextSize=14
    local dl = Instance.new("TextLabel", bb)
    dl.Size=UDim2.new(1,0,0,16); dl.Position=UDim2.new(0,0,0,20)
    dl.BackgroundTransparency=1; dl.Text="0m"
    dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency=0.35; dl.Font=Enum.Font.Gotham; dl.TextSize=12
    local hpL, szL = nil, nil
    if isChar then
        hpL = Instance.new("TextLabel", bb)
        hpL.Size=UDim2.new(1,0,0,16); hpL.Position=UDim2.new(0,0,0,36)
        hpL.BackgroundTransparency=1; hpL.Text="HP: ?"
        hpL.TextColor3=Color3.fromRGB(60,220,60)
        hpL.TextStrokeTransparency=0.35; hpL.Font=Enum.Font.GothamBold; hpL.TextSize=12
        szL = Instance.new("TextLabel", bb)
        szL.Size=UDim2.new(1,0,0,16); szL.Position=UDim2.new(0,0,0,52)
        szL.BackgroundTransparency=1; szL.Text="Ball: 0"
        szL.TextColor3=Color3.fromRGB(180,220,255)
        szL.TextStrokeTransparency=0.35; szL.Font=Enum.Font.GothamBold; szL.TextSize=12
    end
    return {rp=rp, obj=obj, hl=hl, bb=bb, nl=nl, dl=dl, hpL=hpL, szL=szL, isChar=isChar, color=color}
end

function ESP.Add(obj, label, color, isChar)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeESP(obj, label, color, isChar or false)
    if e then State.ESPCache[obj]=e end
end
function ESP.Remove(obj)
    local e = State.ESPCache[obj]; if not e then return end
    pcall(function() e.hl:Destroy() end); pcall(function() e.bb:Destroy() end)
    State.ESPCache[obj]=nil
end
function ESP.ClearAll()
    for o in pairs(State.ESPCache) do ESP.Remove(o) end
    State.ESPCache={}
end

if ESPRender then ESPRender:Disconnect() end
ESPRender = RunService.RenderStepped:Connect(function()
    local hrp = HRP()
    local pos = hrp and hrp.Position or Vector3.zero
    local rem = {}
    for obj, e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then table.insert(rem, obj)
        else
            local rp = GetRoot(obj)
            if not rp then table.insert(rem, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function() e.bb.Adornee=rp end)
                    pcall(function() e.hl.Adornee=obj end)
                end
                pcall(function() e.bb.MaxDistance=State.ESP_MaxDist end)
                local dist = (rp.Position-pos).Magnitude
                local vis = dist <= State.ESP_MaxDist
                pcall(function()
                    e.dl.Text = math.floor(dist).."m"
                    e.dl.Visible = State.ESP_ShowDist
                    e.nl.Visible = State.ESP_ShowName
                    e.bb.Enabled = vis; e.hl.Enabled = vis
                end)
                if e.isChar then
                    pcall(function()
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h and e.hpL then
                            local hp = math.floor(h.Health); local mx = math.floor(h.MaxHealth)
                            e.hpL.Text = "HP: "..hp.."/"..mx
                            local pct = mx>0 and hp/mx or 0
                            e.hpL.TextColor3 = pct>0.6 and Color3.fromRGB(60,220,60)
                                or pct>0.3 and Color3.fromRGB(255,180,60)
                                or Color3.fromRGB(255,50,50)
                            e.hpL.Visible = State.ESP_ShowHP
                        end
                        if e.szL then
                            local plr = Players:GetPlayerFromCharacter(obj)
                            if plr then
                                local ball = Snowball.GetPlayerBall(plr)
                                local sz = ball and Snowball.GetSize(ball) or 0
                                e.szL.Text = "Ball: "..string.format("%.1f",sz)
                                e.szL.TextColor3 = sz>10 and Color3.fromRGB(255,80,80)
                                    or sz>5 and Color3.fromRGB(255,180,60)
                                    or Color3.fromRGB(180,220,255)
                                e.szL.Visible = State.ESP_ShowSize
                            end
                        end
                    end)
                end
            end
        end
    end
    for _, o in ipairs(rem) do ESP.Remove(o) end
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

function ESP.ScanSnowballs()
    for _, b in ipairs(Snowball.GetAllBalls()) do
        if State.ESP_Snowballs then
            if not State.ESPCache[b] and b.Size.Magnitude > 2 then
                local sz = Snowball.GetSize(b)
                ESP.Add(b, "❄️ "..string.format("%.1f",sz), State.Color_Ball, false)
            end
        else
            if State.ESPCache[b] then ESP.Remove(b) end
        end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers()
    if State.ESP_Snowballs then ESP.ScanSnowballs() end
end

task.spawn(function()
    while task.wait(1.5) do pcall(ESP.RefreshAll) end
end)

local function HookP(p)
    if p == LocalPlayer then return end
    CM:Add(p.CharacterAdded, function() task.wait(0.5); ESP.RefreshAll() end)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c) end)
end
for _, p in ipairs(Players:GetPlayers()) do HookP(p) end
CM:Add(Players.PlayerAdded, HookP)
CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Remove(p.Character) end
end)

-- ═══════════════════════════════════════════
-- AIM
-- ═══════════════════════════════════════════
local Aim = {}
local function ScreenDist(o)
    local rp = GetRoot(o); if not rp then return math.huge end
    local sp, os_ = Camera:WorldToScreenPoint(rp.Position)
    if not os_ then return math.huge end
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    return (Vector2.new(sp.X, sp.Y)-c).Magnitude
end
function Aim.Best()
    local best, bd = nil, State.AimFOV
    for _, p in ipairs(PH.Others()) do
        local sd = ScreenDist(p.Character)
        if sd < bd then bd = sd; best = p end
    end
    return best
end
function Aim.LockOn(p)
    if not p or not p.Character then return end
    local b = p.Character:FindFirstChild(State.AimBone)
        or p.Character:FindFirstChild("HumanoidRootPart")
    if not b then return end
    local goal = CFrame.new(Camera.CFrame.Position, b.Position)
    Camera.CFrame = Camera.CFrame:Lerp(goal, State.AimSmoothing)
end
function Aim.Set(e)
    if State.AimConn then pcall(function() State.AimConn:Disconnect() end); State.AimConn=nil end
    if not e then return end
    State.AimConn = RunService.RenderStepped:Connect(function()
        if not (State.AimAssist or State.AutoAim) then return end
        local t = Aim.Best(); State.AimTarget = t
        if not t then return end
        if State.AutoAim then Aim.LockOn(t)
        elseif State.AimAssist then
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                Aim.LockOn(t)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO GROW — Move character to grow snowball
-- ═══════════════════════════════════════════
local Grow = {}
local growTime = 0

function Grow.Set(enable)
    if State.AutoGrowConn then
        pcall(function() State.AutoGrowConn:Disconnect() end)
        State.AutoGrowConn = nil
    end
    if not enable then
        local h = Hum()
        if h then h:MoveTo(HRP().Position) end -- stop
        return
    end
    growTime = tick()
    State.AutoGrowConn = RunService.Heartbeat:Connect(function()
        if not State.AutoGrow then return end
        local hrp = HRP(); local hum = Hum()
        if not hrp or not hum then return end
        local center = hrp.Position
        local target

        if State.GrowPattern == "Circle" then
            local t = tick()
            local ang = t * 2
            target = center + Vector3.new(math.cos(ang)*State.GrowRadius, 0, math.sin(ang)*State.GrowRadius)
        elseif State.GrowPattern == "Zigzag" then
            local t = tick()
            local zig = math.sin(t*3) * State.GrowRadius
            local fwd = hrp.CFrame.LookVector * State.GrowRadius
            target = center + fwd + Vector3.new(zig, 0, 0)
        elseif State.GrowPattern == "Spiral" then
            local t = tick()
            local r = (t % 10) * State.GrowRadius/10
            target = center + Vector3.new(math.cos(t*2)*r, 0, math.sin(t*2)*r)
        elseif State.GrowPattern == "Random" then
            if tick() - growTime > 2 then
                growTime = tick()
                target = center + Vector3.new(
                    math.random(-State.GrowRadius, State.GrowRadius),
                    0,
                    math.random(-State.GrowRadius, State.GrowRadius)
                )
            end
        elseif State.GrowPattern == "Nearest Snow" then
            -- Move toward nearest snow patch (any part with "snow" in name)
            local best, bd = nil, math.huge
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    if n:find("snow") and not n:find("ball") then
                        local d = (obj.Position - center).Magnitude
                        if d < bd and d > 5 then bd = d; best = obj end
                    end
                end
            end
            if best then target = best.Position end
        end

        if target then
            hum.WalkSpeed = State.GrowSpeed
            hum:MoveTo(target)
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO RAM — Charge at enemy with snowball
-- ═══════════════════════════════════════════
local Ram = {}
function Ram.Set(enable)
    if State.AutoRamConn then
        pcall(function() State.AutoRamConn:Disconnect() end)
        State.AutoRamConn = nil
    end
    if not enable then return end
    State.AutoRamConn = RunService.Heartbeat:Connect(function()
        if not State.AutoRam then return end
        local hrp = HRP(); local hum = Hum()
        if not hrp or not hum then return end

        -- Check ball size
        local ball = Snowball.GetOwnBall()
        local ballSize = ball and Snowball.GetSize(ball) or 0
        if ballSize < State.RamMinBallSize then return end

        -- Find target
        local target = PH.WeakestBall() or PH.Nearest()
        if not target or not target.Character then return end
        local erp = GetRoot(target.Character); if not erp then return end
        local dist = (erp.Position - hrp.Position).Magnitude
        if dist > State.RamRange then return end

        -- Charge at them
        hum.WalkSpeed = State.RamSpeed
        hum:MoveTo(erp.Position)
    end)
end

-- ═══════════════════════════════════════════
-- AUTO PUSH OFF — Push enemies over the edge
-- ═══════════════════════════════════════════
local PushOff = {}
function PushOff.Set(enable)
    if State.AutoPushOffConn then
        pcall(function() State.AutoPushOffConn:Disconnect() end)
        State.AutoPushOffConn = nil
    end
    if not enable then return end
    State.AutoPushOffConn = RunService.Heartbeat:Connect(function()
        if not State.AutoPushOff then return end
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(PH.Others()) do
            local erp = GetRoot(p.Character); if not erp then continue end
            local dist = (erp.Position - hrp.Position).Magnitude
            if dist <= State.PushRange then
                -- Find edge direction (away from map center)
                local pushDir = (erp.Position - Vector3.new(0, erp.Position.Y, 0)).Unit
                if pushDir.Magnitude < 0.1 then
                    pushDir = (erp.Position - hrp.Position).Unit
                end
                pushDir = Vector3.new(pushDir.X, 0.2, pushDir.Z)

                -- Fire PushBall remote
                if R.PushBall then
                    local tries = {
                        function() R.PushBall:FireServer(p, pushDir * State.PushForce) end,
                        function() R.PushBall:FireServer(p, pushDir, State.PushForce) end,
                        function() R.PushBall:FireServer(pushDir * State.PushForce) end,
                        function() R.PushBall:FireServer(p) end,
                        function() R.PushBall:FireServer(p, erp.Position + pushDir*50) end,
                    }
                    for _, fn in ipairs(tries) do pcall(fn) end
                end

                -- Also apply local velocity for visual (won't affect server but helps aim)
                pcall(function()
                    erp.AssemblyLinearVelocity = pushDir * State.PushForce
                end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- ANTI KNOCKOFF — Prevent being pushed
-- ═══════════════════════════════════════════
local AK = {}
function AK.Set(enable)
    if State.AntiKnockoffConn then
        pcall(function() State.AntiKnockoffConn:Disconnect() end)
        State.AntiKnockoffConn = nil
    end
    if not enable then return end
    local savedPos = nil
    State.AntiKnockoffConn = RunService.Heartbeat:Connect(function()
        if not State.AntiKnockoff then return end
        local hrp = HRP(); if not hrp then return end

        -- Save safe pos if not near edge
        local edgeDist, edgeDir = Map.DistToEdge()
        if edgeDist > State.EdgeGuardDist then
            savedPos = hrp.Position
        else
            -- Near edge! Kill horizontal velocity
            local vel = hrp.AssemblyLinearVelocity
            if math.abs(vel.X) > 5 or math.abs(vel.Z) > 5 then
                pcall(function()
                    hrp.AssemblyLinearVelocity = Vector3.new(vel.X*0.1, vel.Y, vel.Z*0.1)
                end)
            end
        end

        -- If over void, teleport back
        if State.AntiFall and Map.IsOverVoid() and savedPos then
            pcall(function()
                hrp.CFrame = CFrame.new(savedPos + Vector3.new(0,3,0))
                hrp.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO PUSH BALL (fire remote spam)
-- ═══════════════════════════════════════════
local APB = {}
function APB.Set(enable)
    if State.AutoPushBallConn then
        pcall(function() State.AutoPushBallConn:Disconnect() end)
        State.AutoPushBallConn = nil
    end
    if not enable then return end
    local last = 0
    State.AutoPushBallConn = RunService.Heartbeat:Connect(function()
        if not State.AutoPushBall then return end
        if tick()-last < State.PushBallDelay then return end
        local hrp = HRP(); if not hrp then return end
        local target = PH.Nearest()
        if not target or not target.Character then return end
        local erp = GetRoot(target.Character); if not erp then return end
        local dist = (erp.Position - hrp.Position).Magnitude
        if dist > State.PushBallRange then return end
        last = tick()

        local dir = (erp.Position - hrp.Position).Unit
        if R.PushBall then
            for _, fn in ipairs({
                function() R.PushBall:FireServer(target, dir * 100) end,
                function() R.PushBall:FireServer(target, dir, 100) end,
                function() R.PushBall:FireServer(erp.Position) end,
                function() R.PushBall:FireServer(dir) end,
                function() R.PushBall:FireServer(target) end,
            }) do pcall(fn) end
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO STANDUP
-- ═══════════════════════════════════════════
local AS = {}
function AS.Set(enable)
    if State.AutoStandupConn then
        pcall(function() State.AutoStandupConn:Disconnect() end)
        State.AutoStandupConn = nil
    end
    if not enable then return end
    State.AutoStandupConn = RunService.Heartbeat:Connect(function()
        if not State.AutoStandup then return end
        local h = Hum(); if not h then return end
        local s = h:GetState()
        if s == Enum.HumanoidStateType.Physics
           or s == Enum.HumanoidStateType.FallingDown
           or s == Enum.HumanoidStateType.Ragdoll
           or s == Enum.HumanoidStateType.PlatformStanding then
            if R.Standup then pcall(function() R.Standup:FireServer() end) end
            pcall(function()
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
                h.PlatformStand = false
            end)
        end
    end)
end

-- ═══════════════════════════════════════════
-- GOD MODE
-- ═══════════════════════════════════════════
function Snowball.SetGod(e)
    if State.GodConn then pcall(function() State.GodConn:Disconnect() end); State.GodConn=nil end
    if not e then return end
    State.GodConn = RunService.Heartbeat:Connect(function()
        if not State.GodMode then return end
        local c = Char(); if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and h.Health < h.MaxHealth then
            pcall(function() h.Health = h.MaxHealth end)
        end
        pcall(function()
            c:SetAttribute("Godmode", true)
            c:SetAttribute("Invincible", true)
        end)
    end)
end

-- ═══════════════════════════════════════════
-- BALL SIZE MULTIPLIER (client-side visual)
-- ═══════════════════════════════════════════
function Snowball.SetBigBall(e)
    if State.BallSizeConn then
        pcall(function() State.BallSizeConn:Disconnect() end)
        State.BallSizeConn = nil
    end
    if not e then return end
    State.BallSizeConn = RunService.Heartbeat:Connect(function()
        if not State.InfBallSize then return end
        local ball = Snowball.GetOwnBall()
        if ball then
            local target = State.BallSizeMultiplier
            if ball.Size.X < target then
                pcall(function()
                    ball.Size = Vector3.new(target, target, target)
                end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO VOTE
-- ═══════════════════════════════════════════
function Snowball.DoVote()
    if not R.Vote then return end
    -- Vote is likely FireServer(mapName) or (mapId)
    -- Try common patterns
    for i = 1, 3 do
        pcall(function() R.Vote:FireServer(i) end)
    end
    Notify("Vote", "Fired votes", 2)
end

function Snowball.SetAutoVote(enable)
    if not enable then return end
    task.spawn(function()
        while State.AutoVote do
            task.wait(3)
            Snowball.DoVote()
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO SKILL
-- ═══════════════════════════════════════════
function Snowball.SetAutoSkill(enable)
    if not enable then return end
    task.spawn(function()
        while State.AutoSkill do
            task.wait(State.SkillDelay)
            if R.SkillRcv then pcall(function() R.SkillRcv:FireServer() end) end
            if R.SkillBuff then pcall(function() R.SkillBuff:FireServer() end) end
            for _, k in ipairs({Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.R}) do
                pcall(function() VirtualInputMgr:SendKeyEvent(true, k, false, game) end)
                task.wait(0.05)
                pcall(function() VirtualInputMgr:SendKeyEvent(false, k, false, game) end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════
local Move = {}
function Move.Speed() local h=Hum(); if h then h.WalkSpeed=State.WalkSpeed end end
function Move.Jump() local h=Hum(); if h then h.UseJumpPower=true; h.JumpPower=State.JumpPower end end
function Move.SetNoClip(e)
    if State.NoClipConn then pcall(function() State.NoClipConn:Disconnect() end); State.NoClipConn=nil end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local c=Char()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=false end
                end
            end
        end)
    end
end
function Move.SetInfJump(e)
    if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end); State.InfJumpConn=nil end
    if e then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h=Hum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end
function Move.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local c=Char(); local hrp=HRP(); local h=Hum()
    if not c or not hrp or not h then return end
    local bv = c:FindFirstChild("X0_FlyBV")
    local bg = c:FindFirstChild("X0_FlyBG")
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    if not e then h.PlatformStand=false; return end
    h.PlatformStand=true
    bv = Instance.new("BodyVelocity", hrp)
    bv.Name="X0_FlyBV"; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.Velocity=Vector3.zero
    bg = Instance.new("BodyGyro", hrp)
    bg.Name="X0_FlyBG"; bg.MaxTorque=Vector3.new(9e9,9e9,9e9); bg.P=1000
    State.FlyConn = RunService.RenderStepped:Connect(function()
        if not State.Fly then return end
        local look = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
        bv.Velocity = mv * State.FlySpeed
        bg.CFrame = Camera.CFrame
    end)
end
function Move.TPNearest()
    local p = PH.Nearest()
    if not p or not p.Character then Notify("TP","No target",2); return end
    local erp = GetRoot(p.Character); local hrp = HRP()
    if erp and hrp then
        hrp.CFrame = erp.CFrame * CFrame.new(0,3,3)
        Notify("TP", "→ "..p.Name, 2)
    end
end
function Move.TPPlayer(n)
    if not n or n=="" then return end
    local t = Players:FindFirstChild(n)
    if not t or not t.Character then Notify("TP","Not found",2); return end
    local hrp=HRP(); local thrp=t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Notify("TP", "→ "..n, 2)
    end
end
function Move.ServerHop()
    pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and d and d.data then
            for _, s in ipairs(d.data) do
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
        Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,
    }
end
function Vis.Restore()
    for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end
end
function Vis.FullBright(e)
    Vis.Backup()
    if e then
        Lighting.Ambient=Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.Brightness=2; Lighting.ClockTime=14
        Lighting.GlobalShadows=false
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup()
    if e then
        Lighting.FogEnd=999999; Lighting.FogStart=999999
        for _, a in ipairs(Lighting:GetDescendants()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else Lighting.FogEnd = State.LightBackup.FogEnd or 100000 end
end
function Vis.NoShadows(e) Vis.Backup(); Lighting.GlobalShadows = not e end
function Vis.FOV(f) Camera.FieldOfView = f or 70 end
function Vis.PostFX(rm)
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
            v.Enabled = not rm
        end
    end
end
function Vis.Particles(rm)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = not rm
        end
    end
end
function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel = e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end
function Vis.MuteAll(e)
    if e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") then table.insert(State.MutedSounds, {s=s,v=s.Volume}); s.Volume=0 end
        end
    else
        for _, en in ipairs(State.MutedSounds) do
            if en.s and en.s.Parent then en.s.Volume=en.v end
        end
        State.MutedSounds={}
    end
end
function Vis.HideName(e)
    local c=Char(); if not c then return end
    local h=c:FindFirstChild("Head"); if not h then return end
    for _, g in ipairs(h:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end
function Vis.Freecam(e)
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end); State.FreecamConn=nil end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look=Camera.CFrame.LookVector; local right=Camera.CFrame.RightVector
            local sp = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 6 or 2
            local mv=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
            pos = pos + mv*sp
            Camera.CFrame = CFrame.new(pos, pos+look)
        end)
    else Camera.CameraType=Enum.CameraType.Custom end
end

-- ═══════════════════════════════════════════
-- HUD
-- ═══════════════════════════════════════════
local HUD = {}

function HUD.HPBar()
    if State.HPGui then pcall(function() State.HPGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_HP"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=Gui()
    local f = Instance.new("Frame", sg)
    f.Size=UDim2.new(0,240,0,55); f.Position=UDim2.new(0,15,0.5,-28)
    f.BackgroundColor3=Color3.fromRGB(20,20,25); f.BackgroundTransparency=0.25
    f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local st=Instance.new("UIStroke",f); st.Color=Color3.fromRGB(100,180,255); st.Thickness=1.5
    local title = Instance.new("TextLabel", f)
    title.Size=UDim2.new(1,-10,0,18); title.Position=UDim2.new(0,5,0,4)
    title.BackgroundTransparency=1; title.Text="❄️ HEALTH"
    title.TextColor3=Color3.fromRGB(180,220,255)
    title.Font=Enum.Font.GothamBold; title.TextSize=12
    title.TextXAlignment=Enum.TextXAlignment.Left
    local hpT = Instance.new("TextLabel", f)
    hpT.Size=UDim2.new(1,-10,0,18); hpT.Position=UDim2.new(0,5,0,20)
    hpT.BackgroundTransparency=1; hpT.Text="100 / 100"
    hpT.TextColor3=Color3.fromRGB(255,255,255)
    hpT.Font=Enum.Font.GothamBold; hpT.TextSize=15
    hpT.TextXAlignment=Enum.TextXAlignment.Right
    local bg = Instance.new("Frame", f)
    bg.Size=UDim2.new(1,-10,0,12); bg.Position=UDim2.new(0,5,1,-16)
    bg.BackgroundColor3=Color3.fromRGB(40,40,45); bg.BorderSizePixel=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,4)
    local fill = Instance.new("Frame", bg)
    fill.Size=UDim2.new(1,0,1,0); fill.BackgroundColor3=Color3.fromRGB(100,180,255)
    fill.BorderSizePixel=0
    Instance.new("UICorner",fill).CornerRadius=UDim.new(0,4)
    State.HPGui=sg; HUD.hpT=hpT; HUD.hpB=fill
end

function HUD.UpdateHP()
    if not State.ShowOwnHP or not State.HPGui then return end
    local h = Hum(); if not h then return end
    local hp = math.floor(h.Health); local mx = math.floor(h.MaxHealth)
    local pct = mx>0 and hp/mx or 0
    HUD.hpT.Text = hp.." / "..mx
    HUD.hpB.Size = UDim2.new(pct,0,1,0)
    HUD.hpB.BackgroundColor3 = pct>0.6 and Color3.fromRGB(100,180,255)
        or pct>0.3 and Color3.fromRGB(255,180,60)
        or Color3.fromRGB(255,50,50)
end

function HUD.Stats()
    if State.StatsGui then pcall(function() State.StatsGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Stats"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=Gui()
    local f = Instance.new("Frame", sg)
    f.Size=UDim2.new(0,180,0,100); f.Position=UDim2.new(1,-195,0,120)
    f.BackgroundColor3=Color3.fromRGB(15,15,20); f.BackgroundTransparency=0.2
    f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local st=Instance.new("UIStroke",f); st.Color=Color3.fromRGB(100,180,255); st.Thickness=1.5
    local function Row(y,name)
        local l=Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,-10,0,18); l.Position=UDim2.new(0,5,0,y)
        l.BackgroundTransparency=1; l.Text=name..": 0"
        l.TextColor3=Color3.fromRGB(200,220,255)
        l.Font=Enum.Font.GothamBold; l.TextSize=12
        l.TextXAlignment=Enum.TextXAlignment.Left
        return l
    end
    local t=Instance.new("TextLabel",f)
    t.Size=UDim2.new(1,-10,0,18); t.Position=UDim2.new(0,5,0,4)
    t.BackgroundTransparency=1; t.Text="❄️ STATS"
    t.TextColor3=Color3.fromRGB(100,200,255)
    t.Font=Enum.Font.GothamBold; t.TextSize=13
    t.TextXAlignment=Enum.TextXAlignment.Left
    HUD.K=Row(22,"Kills"); HUD.D=Row(40,"Deaths"); HUD.R=Row(58,"Rejoins"); HUD.B=Row(76,"Ball Size")
    State.StatsGui=sg
end

function HUD.UpdateStats()
    if not State.StatsGui then return end
    HUD.K.Text = "Kills: "..State.Kills
    HUD.D.Text = "Deaths: "..State.Deaths
    HUD.R.Text = "Rejoins: "..State.Rejoins
    local ball = Snowball.GetOwnBall()
    HUD.B.Text = "Ball: "..string.format("%.1f", ball and Snowball.GetSize(ball) or 0)
end

function HUD.SnowballIndicator()
    if State.SnowballGui then pcall(function() State.SnowballGui:Destroy() end) end
    if not State.ShowSnowballSize then return end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Snowball"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=Gui()
    local f = Instance.new("Frame", sg)
    f.Size=UDim2.new(0,180,0,50); f.Position=UDim2.new(0.5,-90,0.85,0)
    f.BackgroundColor3=Color3.fromRGB(20,20,25); f.BackgroundTransparency=0.3
    f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)
    local st=Instance.new("UIStroke",f); st.Color=Color3.fromRGB(180,220,255); st.Thickness=1.5
    local lbl = Instance.new("TextLabel", f)
    lbl.Size=UDim2.new(1,-10,1,-4); lbl.Position=UDim2.new(0,5,0,2)
    lbl.BackgroundTransparency=1; lbl.Text="❄️ Ball: 0.0"
    lbl.TextColor3=Color3.fromRGB(180,220,255)
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=18
    State.SnowballGui=sg; HUD.snowLbl=lbl
end

function HUD.UpdateSnowball()
    if not State.SnowballGui then return end
    local ball = Snowball.GetOwnBall()
    local sz = ball and Snowball.GetSize(ball) or 0
    HUD.snowLbl.Text = string.format("❄️ Ball Size: %.2f", sz)
    HUD.snowLbl.TextColor3 = sz>10 and Color3.fromRGB(255,150,60)
        or sz>5 and Color3.fromRGB(255,255,150)
        or Color3.fromRGB(180,220,255)
end

function HUD.EdgeWarning()
    if State.EdgeGui then pcall(function() State.EdgeGui:Destroy() end) end
    if not State.AntiKnockoff then return end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Edge"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=Gui()
    local f = Instance.new("Frame", sg)
    f.Size=UDim2.new(1,0,0,4); f.Position=UDim2.new(0,0,0,0)
    f.BackgroundColor3=Color3.fromRGB(255,0,0); f.BackgroundTransparency=0.5
    f.BorderSizePixel=0; f.Visible=false
    State.EdgeGui=sg; HUD.edgeBar=f
end

function HUD.UpdateEdge()
    if not State.EdgeGui or not HUD.edgeBar then return end
    if not State.AntiKnockoff then HUD.edgeBar.Visible=false; return end
    local dist = Map.DistToEdge()
    if dist < State.EdgeGuardDist then
        HUD.edgeBar.Visible=true
        HUD.edgeBar.BackgroundColor3 = Color3.fromRGB(255, math.floor(dist*8), 0)
    else HUD.edgeBar.Visible=false end
end

CM:Add(RunService.Heartbeat, function()
    if State.ShowOwnHP then pcall(HUD.UpdateHP) end
    if State.StatsGui then pcall(HUD.UpdateStats) end
    if State.SnowballGui then pcall(HUD.UpdateSnowball) end
    if State.EdgeGui then pcall(HUD.UpdateEdge) end
end)

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
                        Notify("🎯 Elim!", p.Name.." knocked off!", 2)
                    end
                    prev[p] = h.Health
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════
KB.Register("AutoGrow", Enum.KeyCode.T, function()
    State.AutoGrow = not State.AutoGrow
    Grow.Set(State.AutoGrow)
    Notify("Auto Grow", State.AutoGrow and "ON" or "OFF", 1.5)
end)
KB.Register("AutoRam", Enum.KeyCode.R, function()
    State.AutoRam = not State.AutoRam
    Ram.Set(State.AutoRam)
    Notify("Auto Ram", State.AutoRam and "ON" or "OFF", 1.5)
end)
KB.Register("AutoPushOff", Enum.KeyCode.P, function()
    State.AutoPushOff = not State.AutoPushOff
    PushOff.Set(State.AutoPushOff)
    Notify("Push Off", State.AutoPushOff and "ON" or "OFF", 1.5)
end)
KB.Register("AntiKnockoff", Enum.KeyCode.Q, function()
    State.AntiKnockoff = not State.AntiKnockoff
    AK.Set(State.AntiKnockoff)
    HUD.EdgeWarning()
    Notify("Anti Knockoff", State.AntiKnockoff and "ON" or "OFF", 1.5)
end)
KB.Register("GodMode", Enum.KeyCode.G, function()
    State.GodMode = not State.GodMode
    Snowball.SetGod(State.GodMode)
    Notify("God Mode", State.GodMode and "ON" or "OFF", 1.5)
end)
KB.Register("Fly", Enum.KeyCode.F, function()
    State.Fly = not State.Fly
    Move.SetFly(State.Fly)
    Notify("Fly", State.Fly and "ON" or "OFF", 1.5)
end)
KB.Register("SpeedBoost", Enum.KeyCode.B, function()
    State.SpeedBoost = not State.SpeedBoost
    local h = Hum()
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
end)
KB.Register("Freecam", Enum.KeyCode.V, function()
    State.Freecam = not State.Freecam
    Vis.Freecam(State.Freecam)
end)
KB.Register("HPBar", Enum.KeyCode.H, function()
    State.ShowOwnHP = not State.ShowOwnHP
    if State.ShowOwnHP then HUD.HPBar()
    else if State.HPGui then State.HPGui:Destroy(); State.HPGui=nil end end
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
KB.Register("PlayerESP", Enum.KeyCode.F1, function()
    State.ESP_Players = not State.ESP_Players
    ESP.RefreshAll()
    Notify("Player ESP", State.ESP_Players and "ON" or "OFF", 1.5)
end)
KB.Register("BallESP", Enum.KeyCode.F2, function()
    State.ESP_Snowballs = not State.ESP_Snowballs
    if not State.ESP_Snowballs then
        for o in pairs(State.ESPCache) do
            if not Players:GetPlayerFromCharacter(o) then ESP.Remove(o) end
        end
    else ESP.ScanSnowballs() end
    Notify("Ball ESP", State.ESP_Snowballs and "ON" or "OFF", 1.5)
end)
KB.Register("TPNearest", Enum.KeyCode.X, function() Move.TPNearest() end)
KB.Register("ServerHop", Enum.KeyCode.M, function() Move.ServerHop() end)
KB.Register("PanicClear", Enum.KeyCode.End, function()
    State.ESP_Players=false; State.ESP_Snowballs=false; ESP.ClearAll()
    Notify("Panic", "ESP cleared", 1.5)
end)
KB.Register("ForceStandup", Enum.KeyCode.U, function()
    if R.Standup then pcall(function() R.Standup:FireServer() end) end
    local h = Hum(); if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
    Notify("Standup", "Fired", 1)
end)
KB.Register("BigBall", Enum.KeyCode.Y, function()
    State.InfBallSize = not State.InfBallSize
    Snowball.SetBigBall(State.InfBallSize)
    Notify("Big Ball", State.InfBallSize and "ON" or "OFF", 1.5)
end)

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local HUB = {Name="X0DEC04T", Game="Snowball Battles", Ver="2.0.0", Author="voixera"}

local Window = Rayfield:CreateWindow({
    Name = "❄️ "..HUB.Name.." v"..HUB.Ver.." - "..HUB.Game,
    LoadingTitle = HUB.Name.." | Gameplay Edition",
    LoadingSubtitle = "by "..HUB.Author,
    Theme = "Default",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {k="Main",     n="Main",     i="home"},
    {k="Gameplay", n="Gameplay", i="target"},
    {k="Combat",   n="Combat",   i="sword"},
    {k="Defense",  n="Defense",  i="shield"},
    {k="Aim",      n="Aim",      i="crosshair"},
    {k="ESP",      n="ESP",      i="eye"},
    {k="Movement", n="Movement", i="footprints"},
    {k="Visuals",  n="Visuals",  i="sun"},
    {k="Lobby",    n="Lobby",    i="users"},
    {k="Misc",     n="Misc",     i="wrench"},
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
    T:CreateLabel("Gameplay: Roll → Grow → Push enemies off map")
    T:CreateSection("🎯 Recommended Combo")
    T:CreateLabel("1. Enable Auto Grow (T) → grow ball fast")
    T:CreateLabel("2. Enable Auto Ram (R) → charge weakest")
    T:CreateLabel("3. Enable Anti-Knockoff (Q) → safety")
    T:CreateLabel("4. Enable Player ESP (F1) → see enemies")
    T:CreateSection("Remote Status")
    T:CreateLabel("PushBall:  "..(R.PushBall and "✅" or "❌"))
    T:CreateLabel("Standup:   "..(R.Standup and "✅" or "❌"))
    T:CreateLabel("Vote:      "..(R.Vote and "✅" or "❌"))
    T:CreateLabel("Skill:     "..(R.SkillRcv and "✅" or "❌"))
    T:CreateSection("Quick Keys")
    T:CreateLabel("T=Grow | R=Ram | P=Push | Q=Guard | U=Standup")
    T:CreateLabel("F=Fly | B=Speed | G=God | Y=Big Ball | H=HP")
    T:CreateLabel("E=Auto Aim | Z=Aim Assist | X=TP Nearest")
    T:CreateLabel("F1=Player ESP | F2=Ball ESP | L=Bright | V=Freecam")
end

-- GAMEPLAY (main features)
if Tabs.Gameplay then
    local T = Tabs.Gameplay

    T:CreateSection("🌨️ Auto Grow Snowball [T]")
    T:CreateLabel("Automatically moves to grow your snowball")
    T:CreateToggle({Name="Enable Auto Grow", CurrentValue=false, Flag="AG",
        Callback=function(v) State.AutoGrow=v; Grow.Set(v) end})
    T:CreateDropdown({Name="Growing Pattern",
        Options={"Circle","Zigzag","Spiral","Random","Nearest Snow"},
        CurrentOption={"Circle"}, Flag="AGP",
        Callback=function(v) State.GrowPattern=(type(v)=="table" and v[1]) or v end})
    T:CreateSlider({Name="Grow Radius", Range={10,100}, Increment=5,
        CurrentValue=30, Flag="AGR",
        Callback=function(v) State.GrowRadius=tonumber(v) or 30 end})
    T:CreateSlider({Name="Movement Speed", Range={16,100}, Increment=2,
        CurrentValue=30, Flag="AGS",
        Callback=function(v) State.GrowSpeed=tonumber(v) or 30 end})

    T:CreateSection("💥 Auto Ram Enemies [R]")
    T:CreateLabel("Charges at weakest enemy with big ball")
    T:CreateToggle({Name="Enable Auto Ram", CurrentValue=false, Flag="AR",
        Callback=function(v) State.AutoRam=v; Ram.Set(v) end})
    T:CreateSlider({Name="Ram Range", Range={20,200}, Increment=10,
        CurrentValue=100, Flag="ARR",
        Callback=function(v) State.RamRange=tonumber(v) or 100 end})
    T:CreateSlider({Name="Min Ball Size to Ram", Range={1,20}, Increment=1,
        CurrentValue=5, Flag="ARMS",
        Callback=function(v) State.RamMinBallSize=tonumber(v) or 5 end})
    T:CreateSlider({Name="Ram Charge Speed", Range={20,150}, Increment=5,
        CurrentValue=60, Flag="ARS",
        Callback=function(v) State.RamSpeed=tonumber(v) or 60 end})

    T:CreateSection("🎯 Big Ball [Y] (client-side)")
    T:CreateToggle({Name="Keep Ball Big", CurrentValue=false, Flag="BB",
        Callback=function(v) State.InfBallSize=v; Snowball.SetBigBall(v) end})
    T:CreateSlider({Name="Ball Size", Range={2,20}, Increment=1,
        CurrentValue=5, Flag="BBS",
        Callback=function(v) State.BallSizeMultiplier=tonumber(v) or 5 end})

    T:CreateSection("Snowball Indicator")
    T:CreateToggle({Name="Show Ball Size on Screen", CurrentValue=false, Flag="SBS",
        Callback=function(v) State.ShowSnowballSize=v; HUD.SnowballIndicator() end})
end

-- COMBAT
if Tabs.Combat then
    local T = Tabs.Combat

    T:CreateSection("Push Off Map [P]")
    T:CreateLabel("Pushes enemies toward edges when close")
    T:CreateToggle({Name="Auto Push Off Map", CurrentValue=false, Flag="APO",
        Callback=function(v) State.AutoPushOff=v; PushOff.Set(v) end})
    T:CreateSlider({Name="Push Range", Range={5,50}, Increment=2,
        CurrentValue=20, Flag="APOR",
        Callback=function(v) State.PushRange=tonumber(v) or 20 end})
    T:CreateSlider({Name="Push Force", Range={50,500}, Increment=25,
        CurrentValue=150, Flag="APF",
        Callback=function(v) State.PushForce=tonumber(v) or 150 end})

    T:CreateSection("PushBall Remote Spam")
    T:CreateToggle({Name="Auto Fire PushBall", CurrentValue=false, Flag="APB",
        Callback=function(v) State.AutoPushBall=v; APB.Set(v) end})
    T:CreateSlider({Name="Fire Delay (x0.1s)", Range={1,20}, Increment=1,
        CurrentValue=3, Flag="APBD",
        Callback=function(v) State.PushBallDelay=(tonumber(v) or 3)*0.1 end})
    T:CreateSlider({Name="Fire Range", Range={20,300}, Increment=10,
        CurrentValue=100, Flag="APBR",
        Callback=function(v) State.PushBallRange=tonumber(v) or 100 end})

    T:CreateSection("Manual Actions")
    T:CreateButton({Name="Push Nearest Enemy NOW", Callback=function()
        local t = PH.Nearest()
        if t and R.PushBall then
            local erp = GetRoot(t.Character); local hrp = HRP()
            if erp and hrp then
                local dir = (erp.Position - hrp.Position).Unit
                for _, fn in ipairs({
                    function() R.PushBall:FireServer(t, dir*State.PushForce) end,
                    function() R.PushBall:FireServer(t, dir, State.PushForce) end,
                }) do pcall(fn) end
                Notify("Push", "→ "..t.Name, 1)
            end
        end
    end})
    T:CreateButton({Name="Push Nearest To Edge", Callback=function()
        local t = PH.NearestToEdge()
        if t and R.PushBall then
            local erp = GetRoot(t.Character); local hrp = HRP()
            if erp and hrp then
                local dir = (erp.Position - hrp.Position).Unit
                for _, fn in ipairs({
                    function() R.PushBall:FireServer(t, dir*State.PushForce*2) end,
                    function() R.PushBall:FireServer(t, dir, State.PushForce*2) end,
                }) do pcall(fn) end
                Notify("Push", t.Name.." → EDGE!", 2)
            end
        end
    end})

    T:CreateSection("Auto Skill")
    T:CreateToggle({Name="Auto Use Skill", CurrentValue=false, Flag="ASK",
        Callback=function(v) State.AutoSkill=v; Snowball.SetAutoSkill(v) end})
    T:CreateSlider({Name="Skill Delay (x0.5s)", Range={1,10}, Increment=1,
        CurrentValue=3, Flag="ASD",
        Callback=function(v) State.SkillDelay=(tonumber(v) or 3)*0.5 end})
end

-- DEFENSE
if Tabs.Defense then
    local T = Tabs.Defense

    T:CreateSection("🛡️ Anti Knockoff [Q]")
    T:CreateLabel("Prevents being pushed off the map")
    T:CreateToggle({Name="Anti Knockoff", CurrentValue=false, Flag="AK",
        Callback=function(v) State.AntiKnockoff=v; AK.Set(v); HUD.EdgeWarning() end})
    T:CreateSlider({Name="Edge Guard Distance", Range={10,80}, Increment=5,
        CurrentValue=30, Flag="AKD",
        Callback=function(v) State.EdgeGuardDist=tonumber(v) or 30 end})
    T:CreateToggle({Name="Anti Fall (TP back if falling)", CurrentValue=false, Flag="AF",
        Callback=function(v) State.AntiFall=v end})

    T:CreateSection("Auto Standup [U]")
    T:CreateToggle({Name="Auto Standup When Knocked", CurrentValue=true, Flag="AS",
        Callback=function(v) State.AutoStandup=v; AS.Set(v) end})

    T:CreateSection("God Mode [G]")
    T:CreateToggle({Name="God Mode", CurrentValue=false, Flag="GM",
        Callback=function(v) State.GodMode=v; Snowball.SetGod(v) end})

    T:CreateSection("HP Bar [H]")
    T:CreateToggle({Name="Show HP Bar", CurrentValue=false, Flag="HPB",
        Callback=function(v)
            State.ShowOwnHP=v
            if v then HUD.HPBar()
            else if State.HPGui then State.HPGui:Destroy(); State.HPGui=nil end end
        end})

    T:CreateSection("Auto Rejoin")
    T:CreateToggle({Name="Auto Rejoin After Elimination", CurrentValue=true, Flag="ARJ",
        Callback=function(v) State.AutoRejoin=v end})
end

-- AIM
if Tabs.Aim then
    local T = Tabs.Aim
    T:CreateSection("Aim [Z]/[E]")
    T:CreateToggle({Name="Aim Assist (hold RMB)", CurrentValue=false, Flag="AA1",
        Callback=function(v) State.AimAssist=v; Aim.Set(v or State.AutoAim) end})
    T:CreateToggle({Name="Auto Aim (always)", CurrentValue=false, Flag="AA2",
        Callback=function(v) State.AutoAim=v; Aim.Set(v or State.AimAssist) end})
    T:CreateSlider({Name="Smoothing (x0.05)", Range={1,20}, Increment=1,
        CurrentValue=4, Flag="AAS",
        Callback=function(v) State.AimSmoothing=(tonumber(v) or 4)*0.05 end})
    T:CreateSlider({Name="FOV", Range={50,500}, Increment=10,
        CurrentValue=200, Flag="AAF",
        Callback=function(v) State.AimFOV=tonumber(v) or 200 end})
    T:CreateDropdown({Name="Aim Bone",
        Options={"Head","HumanoidRootPart","Torso","UpperTorso"},
        CurrentOption={"HumanoidRootPart"}, Flag="AAB",
        Callback=function(v) State.AimBone=(type(v)=="table" and v[1]) or v end})
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
    T:CreateToggle({Name="Show Ball Size", CurrentValue=true, Flag="E3",
        Callback=function(v) State.ESP_ShowSize=v end})
    T:CreateToggle({Name="Show Name", CurrentValue=true, Flag="E4",
        Callback=function(v) State.ESP_ShowName=v end})
    T:CreateToggle({Name="Show Distance", CurrentValue=true, Flag="E5",
        Callback=function(v) State.ESP_ShowDist=v end})

    T:CreateSection("Ball ESP [F2]")
    T:CreateToggle({Name="Snowball ESP (size)", CurrentValue=false, Flag="E6",
        Callback=function(v)
            State.ESP_Snowballs=v
            if not v then
                for o in pairs(State.ESPCache) do
                    if not Players:GetPlayerFromCharacter(o) then ESP.Remove(o) end
                end
            else ESP.ScanSnowballs() end
        end})

    T:CreateSection("Settings")
    T:CreateSlider({Name="Max Distance", Range={100,3000}, Increment=100,
        CurrentValue=1500, Flag="E7",
        Callback=function(v) State.ESP_MaxDist=tonumber(v) or 1500 end})

    T:CreateSection("Actions")
    T:CreateButton({Name="Refresh All", Callback=function()
        ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2)
    end})
    T:CreateButton({Name="Clear All [End]", Callback=function()
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
            if not State.SpeedBoost and not State.AutoGrow then Move.Speed() end
        end})
    T:CreateSlider({Name="Jump Power", Range={50,500}, Increment=5,
        CurrentValue=50, Flag="M2",
        Callback=function(v) State.JumpPower=tonumber(v) or 50; Move.Jump() end})
    T:CreateToggle({Name="Speed Boost [B]", CurrentValue=false, Flag="M3",
        Callback=function(v)
            State.SpeedBoost=v
            local h=Hum()
            if h then h.WalkSpeed = v and State.SpeedValue or State.WalkSpeed end
        end})
    T:CreateSlider({Name="Boost Value", Range={20,200}, Increment=5,
        CurrentValue=50, Flag="M4",
        Callback=function(v)
            State.SpeedValue=tonumber(v) or 50
            if State.SpeedBoost then local h=Hum(); if h then h.WalkSpeed=State.SpeedValue end end
        end})

    T:CreateSection("Advanced")
    T:CreateToggle({Name="Fly [F]", CurrentValue=false, Flag="M5",
        Callback=function(v) State.Fly=v; Move.SetFly(v) end})
    T:CreateSlider({Name="Fly Speed", Range={20,200}, Increment=10,
        CurrentValue=60, Flag="M6",
        Callback=function(v) State.FlySpeed=tonumber(v) or 60 end})
    T:CreateToggle({Name="NoClip [N]", CurrentValue=false, Flag="M7",
        Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end})
    T:CreateToggle({Name="Infinite Jump [J]", CurrentValue=false, Flag="M8",
        Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end})

    T:CreateSection("Teleport [X]")
    T:CreateButton({Name="TP to Nearest [X]", Callback=Move.TPNearest})
    T:CreateInput({Name="Player Name", PlaceholderText="Username...",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.TPTarget=tostring(v or "") end})
    T:CreateButton({Name="TP to Player", Callback=function() Move.TPPlayer(State.TPTarget) end})
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
    T:CreateToggle({Name="No Particles", CurrentValue=false, Flag="V7",
        Callback=function(v) State.NoParticles=v; Vis.Particles(v) end})
    T:CreateToggle({Name="Low Graphics", CurrentValue=false, Flag="V8",
        Callback=function(v) State.LowGfx=v; Vis.LowGfx(v) end})
    T:CreateToggle({Name="Hide Name Tag", CurrentValue=false, Flag="V9",
        Callback=function(v) State.HideName=v; Vis.HideName(v) end})
    T:CreateToggle({Name="Mute All Sounds", CurrentValue=false, Flag="V10",
        Callback=function(v) Vis.MuteAll(v) end})
    T:CreateSection("HUD")
    T:CreateToggle({Name="Stats Overlay", CurrentValue=false, Flag="V11",
        Callback=function(v)
            State.ShowStats=v
            if v then HUD.Stats()
            else if State.StatsGui then State.StatsGui:Destroy(); State.StatsGui=nil end end
        end})
end

-- LOBBY
if Tabs.Lobby then
    local T = Tabs.Lobby
    T:CreateSection("Map Voting")
    T:CreateToggle({Name="Auto Vote", CurrentValue=false, Flag="AV",
        Callback=function(v) State.AutoVote=v; Snowball.SetAutoVote(v) end})
    T:CreateDropdown({Name="Vote Preference",
        Options={"First","Random","Last"},
        CurrentOption={"First"}, Flag="AVM",
        Callback=function(v) State.AutoVoteMap=(type(v)=="table" and v[1]) or v end})
    T:CreateButton({Name="Force Vote All 3", Callback=Snowball.DoVote})
    T:CreateButton({Name="Force Join Game", Callback=function()
        if R.JoinGame then pcall(function() R.JoinGame:FireServer() end); Notify("Join","Fired",2) end
    end})
end

-- MISC
if Tabs.Misc then
    local T = Tabs.Misc
    T:CreateSection("Server [M]")
    T:CreateButton({Name="Server Hop", Callback=Move.ServerHop})
    T:CreateButton({Name="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end})
    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","Job ID",2) end
    end})
    T:CreateSection("Rewards")
    T:CreateInput({Name="Redeem Code", PlaceholderText="Enter code...",
        RemoveTextAfterFocusLost=true,
        Callback=function(v)
            if R.RedeemCode then
                pcall(function() R.RedeemCode:FireServer(v) end)
                Notify("Code","Sent: "..v,2)
            end
        end})
    T:CreateButton({Name="Claim Daily", Callback=function()
        if R.DailyClaim then pcall(function() R.DailyClaim:FireServer() end); Notify("Daily","Claimed",2) end
    end})
end

-- KEYBINDS
if Tabs.Keybinds then
    local T = Tabs.Keybinds
    T:CreateSection("Gameplay")
    T:CreateKeybind({Name="Auto Grow", CurrentKeybind="T", Flag="KB1",
        HoldToInteract=false, Callback=MakeKB("AutoGrow")})
    T:CreateKeybind({Name="Auto Ram", CurrentKeybind="R", Flag="KB2",
        HoldToInteract=false, Callback=MakeKB("AutoRam")})
    T:CreateKeybind({Name="Auto Push Off", CurrentKeybind="P", Flag="KB3",
        HoldToInteract=false, Callback=MakeKB("AutoPushOff")})
    T:CreateKeybind({Name="Big Ball", CurrentKeybind="Y", Flag="KB4",
        HoldToInteract=false, Callback=MakeKB("BigBall")})
    T:CreateSection("Defense")
    T:CreateKeybind({Name="Anti Knockoff", CurrentKeybind="Q", Flag="KB5",
        HoldToInteract=false, Callback=MakeKB("AntiKnockoff")})
    T:CreateKeybind({Name="Force Standup", CurrentKeybind="U", Flag="KB6",
        HoldToInteract=false, Callback=MakeKB("ForceStandup")})
    T:CreateKeybind({Name="God Mode", CurrentKeybind="G", Flag="KB7",
        HoldToInteract=false, Callback=MakeKB("GodMode")})
    T:CreateKeybind({Name="HP Bar", CurrentKeybind="H", Flag="KB8",
        HoldToInteract=false, Callback=MakeKB("HPBar")})
    T:CreateSection("Aim")
    T:CreateKeybind({Name="Aim Assist", CurrentKeybind="Z", Flag="KB9",
        HoldToInteract=false, Callback=MakeKB("AimAssist")})
    T:CreateKeybind({Name="Auto Aim", CurrentKeybind="E", Flag="KB10",
        HoldToInteract=false, Callback=MakeKB("AutoAim")})
    T:CreateSection("Movement")
    T:CreateKeybind({Name="Fly", CurrentKeybind="F", Flag="KB11",
        HoldToInteract=false, Callback=MakeKB("Fly")})
    T:CreateKeybind({Name="Speed Boost", CurrentKeybind="B", Flag="KB12",
        HoldToInteract=false, Callback=MakeKB("SpeedBoost")})
    T:CreateKeybind({Name="NoClip", CurrentKeybind="N", Flag="KB13",
        HoldToInteract=false, Callback=MakeKB("NoClip")})
    T:CreateKeybind({Name="Inf Jump", CurrentKeybind="J", Flag="KB14",
        HoldToInteract=false, Callback=MakeKB("InfJump")})
    T:CreateKeybind({Name="TP Nearest", CurrentKeybind="X", Flag="KB15",
        HoldToInteract=false, Callback=MakeKB("TPNearest")})
    T:CreateSection("Visuals")
    T:CreateKeybind({Name="FullBright", CurrentKeybind="L", Flag="KB16",
        HoldToInteract=false, Callback=MakeKB("FullBright")})
    T:CreateKeybind({Name="Freecam", CurrentKeybind="V", Flag="KB17",
        HoldToInteract=false, Callback=MakeKB("Freecam")})
    T:CreateSection("ESP")
    T:CreateKeybind({Name="Player ESP", CurrentKeybind="F1", Flag="KB18",
        HoldToInteract=false, Callback=MakeKB("PlayerESP")})
    T:CreateKeybind({Name="Ball ESP", CurrentKeybind="F2", Flag="KB19",
        HoldToInteract=false, Callback=MakeKB("BallESP")})
    T:CreateSection("Misc")
    T:CreateKeybind({Name="Server Hop", CurrentKeybind="M", Flag="KB20",
        HoldToInteract=false, Callback=MakeKB("ServerHop")})
    T:CreateKeybind({Name="Panic Clear", CurrentKeybind="End", Flag="KB21",
        HoldToInteract=false, Callback=MakeKB("PanicClear")})
end

-- SETTINGS
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="S1",
        Callback=function(v) State.AntiAFK=v end})
    T:CreateSection("Credits")
    T:CreateLabel(HUB.Name.." v"..HUB.Ver)
    T:CreateLabel("Game: "..HUB.Game.." | by "..HUB.Author)
    T:CreateSection("⚠️ Danger")
    T:CreateButton({Name="Unload Hub", Callback=function()
        for _, k in ipairs({"AutoGrowConn","AutoRamConn","AutoPushOffConn",
            "AntiKnockoffConn","AutoPushBallConn","AutoStandupConn","AimConn",
            "GodConn","FlyConn","NoClipConn","InfJumpConn","FreecamConn",
            "AntiFallConn","BallSizeConn"}) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        for _, s in pairs({State.HPGui, State.StatsGui, State.SnowballGui, State.EdgeGui, ESPGui}) do
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
end)

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
    if State.SpeedBoost then local h=Hum(); if h then h.WalkSpeed=State.SpeedValue end end
    if State.GodMode then pcall(Snowball.SetGod, true) end
    if State.AutoGrow then pcall(Grow.Set, true) end
    if State.AutoRam then pcall(Ram.Set, true) end
    if State.AutoPushOff then pcall(PushOff.Set, true) end
    if State.AntiKnockoff then pcall(AK.Set, true) end
    if State.AutoPushBall then pcall(APB.Set, true) end
    if State.AutoStandup then pcall(AS.Set, true) end
    if State.AimAssist or State.AutoAim then pcall(Aim.Set, true) end
    if State.Fly then pcall(Move.SetFly, true) end
    if State.InfBallSize then pcall(Snowball.SetBigBall, true) end
    if State.ShowOwnHP then pcall(HUD.HPBar) end
    if State.ShowStats then pcall(HUD.Stats) end
    if State.ShowSnowballSize then pcall(HUD.SnowballIndicator) end
    if State.AntiKnockoff then pcall(HUD.EdgeWarning) end
    task.wait(0.5); ESP.RefreshAll()
    State.Rejoins = State.Rejoins + 1
end)

task.spawn(function()
    while task.wait(5) do
        if State.FullBright then pcall(Vis.FullBright, true) end
        if State.NoFog then pcall(Vis.NoFog, true) end
    end
end)

-- ═══════════════════════════════════════════
-- INSTANCE
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version = HUB.Ver,
    destroy = function()
        for _, k in ipairs({"AutoGrowConn","AutoRamConn","AutoPushOffConn",
            "AntiKnockoffConn","AutoPushBallConn","AutoStandupConn","AimConn",
            "GodConn","FlyConn","NoClipConn","InfJumpConn","FreecamConn",
            "AntiFallConn","BallSizeConn"}) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        for _, s in pairs({State.HPGui, State.StatsGui, State.SnowballGui, State.EdgeGui, ESPGui}) do
            if s then pcall(function() s:Destroy() end) end
        end
        if ESPRender then ESPRender:Disconnect() end
        ESP.ClearAll(); CM:Cleanup(); Vis.Restore()
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView=70 end)
        pcall(function() Rayfield:Destroy() end)
    end,
}

Notify("❄️ Snowball Battles Hub", "v"..HUB.Ver.." loaded! Try T + R + Q combo", 5)
Log("v2.0.0 ready!")
