--═══════════════════════════════════════════════════════════════
-- X0DEC04T Party Hub v1.0.0
-- Games: Cidro Janji, Bunker, Salon de Fiestas & similar party venues
-- Features: Server-wide lag, flashbang, disco floor, screen effects
-- WARNING: Some features affect ALL players in the server (grief)
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
local Chat              = game:GetService("Chat")
local SoundService      = game:GetService("SoundService")
local StarterGui        = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_PARTY_v100_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _logStart = os.clock()
local function Log(msg) print(string.format("[X0DEC04T-PARTY][+%.2fs] %s", os.clock()-_logStart, tostring(msg))) end
local function Err(msg,d) warn(string.format("[X0DEC04T-PARTY][+%.2fs] ERROR: %s | %s", os.clock()-_logStart, tostring(msg), tostring(d or ""))) end

Log("v1.0.0 starting")

local Rayfield = nil
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then Err("Rayfield failed"); return end

local HUB = {
    Name    = "X0DEC04T Party Hub",
    Game    = "Party/Venue Games",
    Version = "1.0.0",
    Author  = "voixera",
}

-- CONNECTION MANAGER
local CM = { _list = {} }
function CM:Add(sig, cb, label)
    if not sig then return end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

-- STATE
local State = {
    -- Movement
    WalkSpeed=16, JumpPower=50, NoClip=false, InfJump=false,
    FlyEnabled=false, FlySpeed=50,

    -- Visuals (self)
    FullBright=false, NoFog=false, LowGraphics=false, FOV=70,
    ClockTime=14, FreecamActive=false,

    -- Anti-lag (for self)
    AntiLagMode=false,
    AntiFlashSelf=true,

    -- Party features
    DiscoFloor=false, DiscoFloorSpeed=0.3,
    DiscoLighting=false, DiscoLightSpeed=0.2,
    Strobe=false, StrobeSpeed=0.05, StrobeIntensity=1,
    RainbowParts=false, RainbowSpeed=0.1,
    FogSpam=false, FogColor="Random",
    SkyChanger=false, SkyMode="Random",

    -- Screen/UI features
    FullBrightSelf=false,
    ScreenShake=false, ScreenShakeIntensity=5,

    -- Grief / Lag features (server-wide via client effects)
    LagBombActive=false, LagBombIntensity=100,
    ParticleSpam=false, ParticleSpamCount=50,
    FlashSpam=false, FlashSpamSpeed=0.1,
    ExplosionSpam=false, ExplosionRate=0.5,
    SoundSpam=false, SoundSpamId="9040032945", SoundSpamVolume=10,
    ChatSpam=false, ChatSpamMsg="X0DEC04T Party Hub", ChatSpamDelay=1,
    BeamSpam=false, BeamSpamCount=20,

    -- Music / Audio
    MusicBoost=false, MusicVolume=5,
    MuteBGM=false, MuteAll=false,

    -- Character effects (self visual)
    RainbowChar=false,
    GlowChar=false, GlowColor=Color3.fromRGB(255,50,255),
    BigHead=false, BigHeadSize=5,
    SmallChar=false, SmallCharSize=0.3,
    TrailEnabled=false, TrailColor="Rainbow",

    -- ESP for party
    ESP_Players=false, ESP_ShowDistance=true, ESP_MaxDist=500,

    -- Utility
    AntiAFK=true, AutoRejoin=false,
    InfiniteYield=false,
    HideName=false,

    -- Connections
    NoClipConn=nil, InfJumpConn=nil, FlyConn=nil, FreecamConn=nil,
    DiscoFloorConn=nil, DiscoLightConn=nil, StrobeConn=nil,
    RainbowConn=nil, FogSpamConn=nil, SkyConn=nil,
    LagBombConn=nil, ParticleConn=nil, FlashConn=nil,
    ExplosionConn=nil, SoundConn=nil, ChatConn=nil, BeamConn=nil,
    ScreenShakeConn=nil, RainbowCharConn=nil,
    ESPRenderConn=nil,

    -- Caches
    ESPCache={},
    OriginalFloorColors={}, OriginalFloorMaterials={},
    OriginalPartColors={},
    OriginalSkybox=nil,
    OriginalLighting={},
    SpawnedParts={},
    SpawnedGuis={},
    OriginalCharColors={},
    OriginalHeadSize=nil,
    OriginalCharSize=nil,
    OriginalCharTrail=nil,
    ScreenBlindGui=nil,
}

-- GUI PARENT
local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Notify(t,c,d)
    pcall(function()
        Rayfield:Notify({
            Title=tostring(t or ""),
            Content=tostring(c or ""),
            Duration=tonumber(d) or 4,
            Image=4483345998,
        })
    end)
end

-- HELPERS
local function GetHuman()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function GetHRP()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function RandomColor()
    return Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
end

local function RandomBrightColor()
    local h = math.random()
    return Color3.fromHSV(h, 1, 1)
end

-- ═══════════════════════════════════════════
-- MOVEMENT
-- ═══════════════════════════════════════════
local Move = {}
function Move.Speed()
    local h = GetHuman()
    if h then h.WalkSpeed = State.WalkSpeed end
end
function Move.Jump()
    local h = GetHuman()
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end

function Move.SetNoClip(e)
    if State.NoClipConn then pcall(function() State.NoClipConn:Disconnect() end); State.NoClipConn=nil end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer.Character
            if ch then
                for _, p in ipairs(ch:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end)
    end
end

function Move.SetInfJump(e)
    if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end); State.InfJumpConn=nil end
    if e then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h = GetHuman()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

function Move.SetFly(e)
    if State.FlyConn then pcall(function() State.FlyConn:Disconnect() end); State.FlyConn=nil end
    local ch = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local bg = ch:FindFirstChild("X0_FlyBG")
    local bv = ch:FindFirstChild("X0_FlyBV")
    if bg then bg:Destroy() end
    if bv then bv:Destroy() end

    if not e then
        hum.PlatformStand = false
        return
    end

    bg = Instance.new("BodyGyro", hrp)
    bg.Name = "X0_FlyBG"
    bg.P = 9e4
    bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.CFrame = hrp.CFrame

    bv = Instance.new("BodyVelocity", hrp)
    bv.Name = "X0_FlyBV"
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Velocity = Vector3.zero

    State.FlyConn = RunService.RenderStepped:Connect(function()
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local r = c:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end

        local mv = Vector3.zero
        local cam = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - cam.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + cam.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end

        bv.Velocity = mv * State.FlySpeed
        bg.CFrame = cam
        h.PlatformStand = true
    end)
end

-- ═══════════════════════════════════════════
-- PARTY / DISCO EFFECTS (self visual only)
-- ═══════════════════════════════════════════
local Party = {}

-- Get all floor-like parts (baseplate, dance floor, big parts)
local function GetFloorParts()
    local list = {}
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") and not p:IsDescendantOf(LocalPlayer.Character or Instance.new("Model")) then
            local sz = p.Size
            -- Floors are usually wide but short
            if sz.Y < 5 and (sz.X > 8 or sz.Z > 8) then
                local n = p.Name:lower()
                if n:find("floor") or n:find("dance") or n:find("stage") or n:find("baseplate")
                   or n:find("ground") or n:find("tile") or p.Position.Y < 3 then
                    table.insert(list, p)
                end
            end
        end
    end
    return list
end

function Party.SetDiscoFloor(e)
    if State.DiscoFloorConn then pcall(function() State.DiscoFloorConn:Disconnect() end); State.DiscoFloorConn=nil end
    if not e then
        for part, orig in pairs(State.OriginalFloorColors) do
            if part and part.Parent then
                pcall(function() part.Color = orig end)
            end
        end
        for part, orig in pairs(State.OriginalFloorMaterials) do
            if part and part.Parent then
                pcall(function() part.Material = orig end)
            end
        end
        State.OriginalFloorColors = {}
        State.OriginalFloorMaterials = {}
        return
    end
    -- Cache originals
    local floors = GetFloorParts()
    for _, p in ipairs(floors) do
        if State.OriginalFloorColors[p] == nil then
            State.OriginalFloorColors[p] = p.Color
            State.OriginalFloorMaterials[p] = p.Material
        end
    end
    local t = 0
    State.DiscoFloorConn = RunService.Heartbeat:Connect(function(dt)
        if not State.DiscoFloor then return end
        t = t + dt
        if t < State.DiscoFloorSpeed then return end
        t = 0
        for part in pairs(State.OriginalFloorColors) do
            if part and part.Parent then
                pcall(function()
                    part.Color = RandomBrightColor()
                    part.Material = Enum.Material.Neon
                end)
            end
        end
    end)
end

function Party.SetDiscoLighting(e)
    if State.DiscoLightConn then pcall(function() State.DiscoLightConn:Disconnect() end); State.DiscoLightConn=nil end
    if not e then
        if State.OriginalLighting.Ambient then
            Lighting.Ambient = State.OriginalLighting.Ambient
            Lighting.OutdoorAmbient = State.OriginalLighting.OutdoorAmbient
            Lighting.ColorShift_Top = State.OriginalLighting.ColorShift_Top
        end
        return
    end
    State.OriginalLighting.Ambient = Lighting.Ambient
    State.OriginalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
    State.OriginalLighting.ColorShift_Top = Lighting.ColorShift_Top
    local t = 0
    State.DiscoLightConn = RunService.Heartbeat:Connect(function(dt)
        if not State.DiscoLighting then return end
        t = t + dt
        if t < State.DiscoLightSpeed then return end
        t = 0
        local c = RandomBrightColor()
        pcall(function()
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
            Lighting.ColorShift_Top = c
        end)
    end)
end

function Party.SetStrobe(e)
    if State.StrobeConn then pcall(function() State.StrobeConn:Disconnect() end); State.StrobeConn=nil end
    if not e then
        if State.OriginalLighting.Brightness then
            Lighting.Brightness = State.OriginalLighting.Brightness
        end
        return
    end
    State.OriginalLighting.Brightness = State.OriginalLighting.Brightness or Lighting.Brightness
    local flip = false
    local t = 0
    State.StrobeConn = RunService.Heartbeat:Connect(function(dt)
        if not State.Strobe then return end
        t = t + dt
        if t < State.StrobeSpeed then return end
        t = 0
        flip = not flip
        pcall(function()
            Lighting.Brightness = flip and (5 * State.StrobeIntensity) or 0
        end)
    end)
end

function Party.SetRainbowParts(e)
    if State.RainbowConn then pcall(function() State.RainbowConn:Disconnect() end); State.RainbowConn=nil end
    if not e then
        for part, orig in pairs(State.OriginalPartColors) do
            if part and part.Parent then
                pcall(function() part.Color = orig end)
            end
        end
        State.OriginalPartColors = {}
        return
    end
    -- Cache visible parts
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("BasePart") and p.Transparency < 1
           and (not LocalPlayer.Character or not p:IsDescendantOf(LocalPlayer.Character)) then
            if State.OriginalPartColors[p] == nil then
                State.OriginalPartColors[p] = p.Color
            end
        end
    end
    local t = 0
    State.RainbowConn = RunService.Heartbeat:Connect(function(dt)
        if not State.RainbowParts then return end
        t = t + dt
        if t < State.RainbowSpeed then return end
        t = 0
        local baseHue = tick() * 0.5
        for part in pairs(State.OriginalPartColors) do
            if part and part.Parent then
                pcall(function()
                    part.Color = Color3.fromHSV((baseHue + part.Position.X * 0.01) % 1, 1, 1)
                end)
            end
        end
    end)
end

function Party.SetFogSpam(e)
    if State.FogSpamConn then pcall(function() State.FogSpamConn:Disconnect() end); State.FogSpamConn=nil end
    if not e then
        Lighting.FogColor = Color3.fromRGB(191,191,191)
        Lighting.FogEnd = 100000
        return
    end
    State.FogSpamConn = RunService.Heartbeat:Connect(function()
        if not State.FogSpam then return end
        pcall(function()
            if State.FogColor == "Random" then
                Lighting.FogColor = RandomBrightColor()
            elseif State.FogColor == "Red" then
                Lighting.FogColor = Color3.fromRGB(255,50,50)
            elseif State.FogColor == "Green" then
                Lighting.FogColor = Color3.fromRGB(50,255,50)
            elseif State.FogColor == "Blue" then
                Lighting.FogColor = Color3.fromRGB(50,50,255)
            elseif State.FogColor == "Purple" then
                Lighting.FogColor = Color3.fromRGB(180,50,255)
            end
            Lighting.FogEnd = 40
            Lighting.FogStart = 0
        end)
    end)
end

function Party.SetSkyChanger(e)
    if State.SkyConn then pcall(function() State.SkyConn:Disconnect() end); State.SkyConn=nil end
    if not e then
        if State.OriginalSkybox then
            for _, o in ipairs(Lighting:GetChildren()) do
                if o:IsA("Sky") and o.Name == "X0_PartySky" then o:Destroy() end
            end
            pcall(function() State.OriginalSkybox.Parent = Lighting end)
        end
        return
    end
    if not State.OriginalSkybox then
        for _, o in ipairs(Lighting:GetChildren()) do
            if o:IsA("Sky") then
                State.OriginalSkybox = o:Clone()
                o.Parent = nil
                break
            end
        end
    end
    local t = 0
    State.SkyConn = RunService.Heartbeat:Connect(function(dt)
        if not State.SkyChanger then return end
        t = t + dt
        if t < 0.5 then return end
        t = 0
        pcall(function()
            for _, o in ipairs(Lighting:GetChildren()) do
                if o:IsA("Sky") and o.Name == "X0_PartySky" then o:Destroy() end
            end
            local sky = Instance.new("Sky")
            sky.Name = "X0_PartySky"
            sky.CelestialBodiesShown = false
            local c = RandomBrightColor()
            local hex = string.format("%02X%02X%02X",
                math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
            -- Use solid-color-generated sky isn't supported; use pre-picked SkyboxIds
            local skies = {
                "rbxassetid://6444884785", "rbxassetid://6444884337",
                "rbxassetid://6444884051", "rbxassetid://6444320645",
            }
            local id = skies[math.random(#skies)]
            sky.SkyboxBk = id
            sky.SkyboxDn = id
            sky.SkyboxFt = id
            sky.SkyboxLf = id
            sky.SkyboxRt = id
            sky.SkyboxUp = id
            sky.Parent = Lighting
        end)
    end)
end

-- ═══════════════════════════════════════════
-- LAG / GRIEF (client-side effects that affect all)
-- ═══════════════════════════════════════════
local Grief = {}

-- LAG BOMB — spawn tons of particles/parts locally on server-facing objects
function Grief.SetLagBomb(e)
    if State.LagBombConn then pcall(function() State.LagBombConn:Disconnect() end); State.LagBombConn=nil end
    if not e then
        for _, p in ipairs(State.SpawnedParts) do
            if p and p.Parent then pcall(function() p:Destroy() end) end
        end
        State.SpawnedParts = {}
        return
    end
    State.LagBombConn = RunService.Heartbeat:Connect(function()
        if not State.LagBombActive then return end
        local hrp = GetHRP()
        if not hrp then return end
        for i = 1, math.floor(State.LagBombIntensity/10) do
            local part = Instance.new("Part")
            part.Name = "X0_LagBomb"
            part.Size = Vector3.new(math.random(1,3), math.random(1,3), math.random(1,3))
            part.Position = hrp.Position + Vector3.new(math.random(-30,30), math.random(0,20), math.random(-30,30))
            part.Material = Enum.Material.Neon
            part.Color = RandomBrightColor()
            part.Anchored = false
            part.CanCollide = false
            part.Massless = true
            part.Parent = Workspace

            -- Add particle emitter for extra lag
            local pe = Instance.new("ParticleEmitter", part)
            pe.Rate = 500
            pe.Lifetime = NumberRange.new(2, 5)
            pe.Size = NumberSequence.new(1, 3)
            pe.Color = ColorSequence.new(RandomBrightColor(), RandomBrightColor())
            pe.Speed = NumberRange.new(5, 20)

            -- Add light
            local pl = Instance.new("PointLight", part)
            pl.Color = RandomBrightColor()
            pl.Brightness = 5
            pl.Range = 30

            table.insert(State.SpawnedParts, part)

            -- Auto-cleanup old parts to prevent client crash
            if #State.SpawnedParts > 500 then
                local old = table.remove(State.SpawnedParts, 1)
                if old and old.Parent then pcall(function() old:Destroy() end) end
            end
        end
    end)
end

-- PARTICLE SPAM
function Grief.SetParticleSpam(e)
    if State.ParticleConn then pcall(function() State.ParticleConn:Disconnect() end); State.ParticleConn=nil end
    if not e then
        for _, p in ipairs(State.SpawnedParts) do
            if p and p.Parent and p.Name == "X0_ParticleSpam" then
                pcall(function() p:Destroy() end)
            end
        end
        return
    end
    State.ParticleConn = RunService.Heartbeat:Connect(function()
        if not State.ParticleSpam then return end
        local hrp = GetHRP()
        if not hrp then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                for _, part in ipairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") and not part:FindFirstChild("X0_ParticleSpam") then
                        local pe = Instance.new("ParticleEmitter")
                        pe.Name = "X0_ParticleSpam"
                        pe.Rate = State.ParticleSpamCount
                        pe.Lifetime = NumberRange.new(1, 3)
                        pe.Size = NumberSequence.new(2)
                        pe.Color = ColorSequence.new(RandomBrightColor())
                        pe.Speed = NumberRange.new(5, 15)
                        pe.Texture = "rbxassetid://243660364"
                        pe.LightEmission = 1
                        pe.Parent = part
                    end
                end
            end
        end
    end)
end

-- FLASH SPAM (screen flash for LocalPlayer only, since we can't force on others)
function Grief.SetFlashSpam(e)
    if State.FlashConn then pcall(function() State.FlashConn:Disconnect() end); State.FlashConn=nil end
    if not e then
        if State.ScreenBlindGui then pcall(function() State.ScreenBlindGui:Destroy() end); State.ScreenBlindGui=nil end
        return
    end

    if not State.ScreenBlindGui then
        local sg = Instance.new("ScreenGui")
        sg.Name = "X0_FlashSpam"
        sg.ResetOnSpawn = false
        sg.DisplayOrder = 999999
        sg.IgnoreGuiInset = true
        sg.Parent = GuiParent()
        local f = Instance.new("Frame", sg)
        f.Size = UDim2.new(1,0,1,0)
        f.Position = UDim2.new(0,0,0,0)
        f.BackgroundColor3 = Color3.new(1,1,1)
        f.BackgroundTransparency = 0
        f.BorderSizePixel = 0
        State.ScreenBlindGui = sg
        State.ScreenBlindFrame = f
    end

    local flip = false
    local t = 0
    State.FlashConn = RunService.Heartbeat:Connect(function(dt)
        if not State.FlashSpam then return end
        t = t + dt
        if t < State.FlashSpamSpeed then return end
        t = 0
        if State.ScreenBlindFrame then
            flip = not flip
            State.ScreenBlindFrame.BackgroundColor3 = flip and RandomBrightColor() or Color3.new(0,0,0)
            State.ScreenBlindFrame.BackgroundTransparency = flip and 0.3 or 0.5
        end
    end)
end

-- EXPLOSION SPAM (visual only, near players)
function Grief.SetExplosionSpam(e)
    if State.ExplosionConn then pcall(function() State.ExplosionConn:Disconnect() end); State.ExplosionConn=nil end
    if not e then return end
    local t = 0
    State.ExplosionConn = RunService.Heartbeat:Connect(function(dt)
        if not State.ExplosionSpam then return end
        t = t + dt
        if t < State.ExplosionRate then return end
        t = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ex = Instance.new("Explosion")
                    ex.Position = hrp.Position + Vector3.new(math.random(-5,5), 0, math.random(-5,5))
                    ex.BlastRadius = 10
                    ex.BlastPressure = 0
                    ex.DestroyJointRadiusPercent = 0
                    ex.Visible = true
                    ex.Parent = Workspace
                end
            end
        end
    end)
end

-- SOUND SPAM
function Grief.SetSoundSpam(e)
    if State.SoundConn then pcall(function() State.SoundConn:Disconnect() end); State.SoundConn=nil end
    if not e then
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and s.Name == "X0_SoundSpam" then
                pcall(function() s:Stop(); s:Destroy() end)
            end
        end
        return
    end
    State.SoundConn = RunService.Heartbeat:Connect(function()
        if not State.SoundSpam then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp and not hrp:FindFirstChild("X0_SoundSpam") then
                    local snd = Instance.new("Sound")
                    snd.Name = "X0_SoundSpam"
                    snd.SoundId = "rbxassetid://" .. State.SoundSpamId
                    snd.Volume = State.SoundSpamVolume
                    snd.Looped = true
                    snd.RollOffMinDistance = 100
                    snd.RollOffMaxDistance = 10000
                    snd.Parent = hrp
                    snd:Play()
                end
            end
        end
    end)
end

-- BEAM SPAM (giant colorful beams from LocalPlayer to every player)
function Grief.SetBeamSpam(e)
    if State.BeamConn then pcall(function() State.BeamConn:Disconnect() end); State.BeamConn=nil end
    if not e then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "X0_BeamSpam" then
                pcall(function() obj:Destroy() end)
            end
        end
        return
    end
    State.BeamConn = RunService.Heartbeat:Connect(function()
        if not State.BeamSpam then return end
        local hrp = GetHRP()
        if not hrp then return end
        -- Clean previous
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "X0_BeamSpam" then
                pcall(function() obj:Destroy() end)
            end
        end
        -- Spawn beams to each player
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local other = plr.Character:FindFirstChild("HumanoidRootPart")
                if other then
                    for i = 1, State.BeamSpamCount do
                        local a1 = Instance.new("Attachment", hrp)
                        a1.Name = "X0_BeamSpam"
                        local a2 = Instance.new("Attachment", other)
                        a2.Name = "X0_BeamSpam"
                        local beam = Instance.new("Beam")
                        beam.Name = "X0_BeamSpam"
                        beam.Attachment0 = a1
                        beam.Attachment1 = a2
                        beam.Width0 = 5
                        beam.Width1 = 5
                        beam.Color = ColorSequence.new(RandomBrightColor(), RandomBrightColor())
                        beam.LightEmission = 1
                        beam.LightInfluence = 0
                        beam.Texture = "rbxassetid://446111271"
                        beam.TextureSpeed = 5
                        beam.Segments = 20
                        beam.Parent = Workspace
                    end
                end
            end
        end
    end)
end

-- CHAT SPAM
function Grief.SetChatSpam(e)
    if State.ChatConn then pcall(function() State.ChatConn:Disconnect() end); State.ChatConn=nil end
    if not e then return end
    task.spawn(function()
        while State.ChatSpam do
            task.wait(State.ChatSpamDelay)
            pcall(function()
                local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
                if chatEvent then
                    local sayReq = chatEvent:FindFirstChild("SayMessageRequest")
                    if sayReq then
                        sayReq:FireServer(State.ChatSpamMsg .. " " .. math.random(1000,9999), "All")
                    end
                end
            end)
        end
    end)
end

-- ═══════════════════════════════════════════
-- CHARACTER EFFECTS
-- ═══════════════════════════════════════════
local CharFX = {}

function CharFX.SetRainbowChar(e)
    if State.RainbowCharConn then pcall(function() State.RainbowCharConn:Disconnect() end); State.RainbowCharConn=nil end
    if not e then
        local ch = LocalPlayer.Character
        if ch then
            for part, orig in pairs(State.OriginalCharColors) do
                if part and part.Parent then
                    pcall(function() part.Color = orig end)
                end
            end
        end
        State.OriginalCharColors = {}
        return
    end
    local ch = LocalPlayer.Character
    if not ch then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") and State.OriginalCharColors[p] == nil then
            State.OriginalCharColors[p] = p.Color
        end
    end
    local t = 0
    State.RainbowCharConn = RunService.Heartbeat:Connect(function(dt)
        if not State.RainbowChar then return end
        t = t + dt
        local hue = (tick() * 0.5) % 1
        local c = LocalPlayer.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then
                if State.OriginalCharColors[p] == nil then
                    State.OriginalCharColors[p] = p.Color
                end
                pcall(function()
                    p.Color = Color3.fromHSV((hue + p.Position.Y * 0.05) % 1, 1, 1)
                end)
            end
        end
    end)
end

function CharFX.SetGlowChar(e)
    local ch = LocalPlayer.Character
    if not ch then return end
    -- Remove existing
    for _, obj in ipairs(ch:GetDescendants()) do
        if obj.Name == "X0_Glow" then pcall(function() obj:Destroy() end) end
    end
    if not e then return end
    for _, p in ipairs(ch:GetDescendants()) do
        if p:IsA("BasePart") then
            local pl = Instance.new("PointLight")
            pl.Name = "X0_Glow"
            pl.Color = State.GlowColor
            pl.Brightness = 3
            pl.Range = 15
            pl.Parent = p
        end
    end
end

function CharFX.SetBigHead(e)
    local ch = LocalPlayer.Character
    if not ch then return end
    local head = ch:FindFirstChild("Head")
    if not head then return end
    if not State.OriginalHeadSize then
        State.OriginalHeadSize = head.Size
    end
    if e then
        pcall(function() head.Size = State.OriginalHeadSize * State.BigHeadSize end)
    else
        pcall(function() head.Size = State.OriginalHeadSize end)
    end
end

function CharFX.SetSmallChar(e)
    local ch = LocalPlayer.Character
    local hum = GetHuman()
    if not ch or not hum then return end
    if e then
        pcall(function()
            hum.HipHeight = 0
            hum.BodyDepthScale.Value = State.SmallCharSize
            hum.BodyHeightScale.Value = State.SmallCharSize
            hum.BodyWidthScale.Value = State.SmallCharSize
            hum.HeadScale.Value = State.SmallCharSize
        end)
    else
        pcall(function()
            hum.BodyDepthScale.Value = 1
            hum.BodyHeightScale.Value = 1
            hum.BodyWidthScale.Value = 1
            hum.HeadScale.Value = 1
        end)
    end
end

function CharFX.SetTrail(e)
    local ch = LocalPlayer.Character
    if not ch then return end
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    local head = ch:FindFirstChild("Head")
    if not hrp or not head then return end
    for _, obj in ipairs(ch:GetDescendants()) do
        if obj.Name == "X0_Trail" then pcall(function() obj:Destroy() end) end
    end
    if not e then return end
    local a1 = Instance.new("Attachment", head); a1.Name = "X0_Trail"
    local a2 = Instance.new("Attachment", hrp); a2.Name = "X0_Trail"
    a2.Position = Vector3.new(0, -2, 0)
    local trail = Instance.new("Trail")
    trail.Name = "X0_Trail"
    trail.Attachment0 = a1
    trail.Attachment1 = a2
    trail.Lifetime = 2
    trail.MinLength = 0
    trail.LightEmission = 1
    if State.TrailColor == "Rainbow" then
        local seq = {}
        for i = 0, 10 do
            table.insert(seq, ColorSequenceKeypoint.new(i/10, Color3.fromHSV(i/10, 1, 1)))
        end
        trail.Color = ColorSequence.new(seq)
    else
        trail.Color = ColorSequence.new(Color3.fromRGB(255,50,255))
    end
    trail.Parent = ch
end

-- ═══════════════════════════════════════════
-- SCREEN SHAKE (self)
-- ═══════════════════════════════════════════
function Party.SetScreenShake(e)
    if State.ScreenShakeConn then pcall(function() State.ScreenShakeConn:Disconnect() end); State.ScreenShakeConn=nil end
    if not e then return end
    State.ScreenShakeConn = RunService.RenderStepped:Connect(function()
        if not State.ScreenShake then return end
        pcall(function()
            local i = State.ScreenShakeIntensity
            Camera.CFrame = Camera.CFrame * CFrame.new(
                math.random(-i,i)*0.05,
                math.random(-i,i)*0.05,
                math.random(-i,i)*0.05
            )
        end)
    end)
end

-- ═══════════════════════════════════════════
-- VISUALS / LIGHTING (self)
-- ═══════════════════════════════════════════
local Vis = {}
function Vis.FullBright(e)
    if e then
        Lighting.Ambient = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255,255,255)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(70,70,70)
        Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end
end

function Vis.NoFog(e)
    if e then
        Lighting.FogEnd = 999999
        Lighting.FogStart = 999999
    else
        Lighting.FogEnd = 100000
    end
end

function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel = e
            and Enum.QualityLevel.Level01
            or Enum.QualityLevel.Automatic
    end)
end

function Vis.SetFOV(f)
    if Camera then Camera.FieldOfView = tonumber(f) or 70 end
end

function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end

-- Freecam
function Vis.Freecam(e)
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end); State.FreecamConn=nil end
    if e then
        Camera.CameraType = Enum.CameraType.Scriptable
        local pos = Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local mv = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv = mv + look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv = mv - look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv = mv - right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv = mv + right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv = mv + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv = mv - Vector3.new(0,1,0) end
            pos = pos + mv * 2
            Camera.CFrame = CFrame.new(pos, pos + look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

-- Mute all sounds (self only)
function Vis.MuteAll(e)
    for _, s in ipairs(Workspace:GetDescendants()) do
        if s:IsA("Sound") and s.Name ~= "X0_SoundSpam" then
            pcall(function() s.Volume = e and 0 or 1 end)
        end
    end
    for _, s in ipairs(SoundService:GetDescendants()) do
        if s:IsA("Sound") then pcall(function() s.Volume = e and 0 or 1 end) end
    end
end

function Vis.MuteBGM(e)
    for _, s in ipairs(Workspace:GetDescendants()) do
        if s:IsA("Sound") and (s.Name:lower():find("music") or s.Name:lower():find("bgm")) then
            pcall(function() s.Volume = e and 0 or 1 end)
        end
    end
end

-- Music boost (make party music louder for self)
function Vis.MusicBoost(e)
    for _, s in ipairs(Workspace:GetDescendants()) do
        if s:IsA("Sound") and (s.Name:lower():find("music") or s.Name:lower():find("bgm") or s.Looped) then
            pcall(function() s.Volume = e and State.MusicVolume or 1 end)
        end
    end
end

-- ═══════════════════════════════════════════
-- ANTI-LAG / ANTI-FLASH (protection for self)
-- ═══════════════════════════════════════════
local AntiLag = {}
function AntiLag.SetAntiFlash(e)
    if e then
        -- Reduce blur, remove color correction
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("BlurEffect") or v:IsA("BloomEffect")
            or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
                pcall(function() v.Enabled = false end)
            end
        end
        -- Also cap brightness
        pcall(function()
            if Lighting.Brightness > 2 then Lighting.Brightness = 2 end
        end)
    else
        for _, v in ipairs(Lighting:GetDescendants()) do
            if v:IsA("BlurEffect") or v:IsA("BloomEffect")
            or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") then
                pcall(function() v.Enabled = true end)
            end
        end
    end
end

function AntiLag.SetAntiLag(e)
    if e then
        Vis.LowGfx(true)
        -- Remove all particles from workspace
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire")
            or v:IsA("Smoke") or v:IsA("Sparkles") or v:IsA("Trail") or v:IsA("Beam") then
                if v.Name ~= "X0_Trail" and v.Name ~= "X0_ParticleSpam"
                   and v.Name ~= "X0_BeamSpam" and v.Name ~= "X0_LagBomb" then
                    pcall(function() v.Enabled = false end)
                end
            end
        end
        -- Remove Meshes on distant parts
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
    else
        Vis.LowGfx(false)
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire")
            or v:IsA("Smoke") or v:IsA("Sparkles") then
                pcall(function() v.Enabled = true end)
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- ESP (simple for party)
-- ═══════════════════════════════════════════
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_PartyESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name = "X0_PartyESP"
    ESPGui.ResetOnSpawn = false
    ESPGui.IgnoreGuiInset = true
    ESPGui.DisplayOrder = 998
    ESPGui.Parent = GuiParent()
end

function ESP.Add(plr)
    if not plr or plr == LocalPlayer then return end
    if State.ESPCache[plr] then return end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(255, 100, 200)
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.6
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = Workspace

    local bb = Instance.new("BillboardGui")
    bb.Adornee = hrp
    bb.Size = UDim2.new(0, 200, 0, 40)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = State.ESP_MaxDist
    bb.Parent = ESPGui

    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1,0,0,20)
    nl.BackgroundTransparency = 1
    nl.Text = plr.Name
    nl.TextColor3 = Color3.fromRGB(255,255,255)
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14

    local dl = Instance.new("TextLabel", bb)
    dl.Size = UDim2.new(1,0,0,16)
    dl.Position = UDim2.new(0,0,0,20)
    dl.BackgroundTransparency = 1
    dl.Text = "0m"
    dl.TextColor3 = Color3.fromRGB(200,200,200)
    dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.Gotham
    dl.TextSize = 12

    State.ESPCache[plr] = {hl=hl, bb=bb, nl=nl, dl=dl, hrp=hrp}
end

function ESP.Remove(plr)
    local e = State.ESPCache[plr]
    if not e then return end
    if e.hl then pcall(function() e.hl:Destroy() end) end
    if e.bb then pcall(function() e.bb:Destroy() end) end
    State.ESPCache[plr] = nil
end

function ESP.ClearAll()
    for plr in pairs(State.ESPCache) do ESP.Remove(plr) end
    State.ESPCache = {}
end

function ESP.RefreshAll()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if State.ESP_Players then
                if not State.ESPCache[plr] then ESP.Add(plr) end
            else
                if State.ESPCache[plr] then ESP.Remove(plr) end
            end
        end
    end
end

function ESP.Start()
    if State.ESPRenderConn then State.ESPRenderConn:Disconnect() end
    State.ESPRenderConn = RunService.RenderStepped:Connect(function()
        local hrp = GetHRP()
        local myPos = hrp and hrp.Position or Vector3.zero
        for plr, e in pairs(State.ESPCache) do
            if plr and plr.Parent and plr.Character then
                local newHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if newHrp then
                    if e.hrp ~= newHrp then
                        e.hrp = newHrp
                        pcall(function() e.bb.Adornee = newHrp end)
                    end
                    local dist = (newHrp.Position - myPos).Magnitude
                    if e.dl then
                        pcall(function()
                            e.dl.Text = math.floor(dist) .. "m"
                            e.dl.Visible = State.ESP_ShowDistance
                        end)
                    end
                    if e.bb then pcall(function() e.bb.MaxDistance = State.ESP_MaxDist end) end
                end
            else
                ESP.Remove(plr)
            end
        end
    end)
end
ESP.Start()

task.spawn(function()
    while task.wait(2) do
        if State.ESP_Players then pcall(ESP.RefreshAll) end
    end
end)

CM:Add(Players.PlayerAdded, function(p)
    CM:Add(p.CharacterAdded, function()
        task.wait(0.5)
        if State.ESP_Players then ESP.Add(p) end
    end, "CA:"..p.Name)
end, "PA")

CM:Add(Players.PlayerRemoving, function(p) ESP.Remove(p) end, "PR")

-- ═══════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end, "AntiAFK")

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
end, "Teleport")

-- INFINITE YIELD LOADER
local function LoadInfYield()
    if State.InfiniteYield then return end
    pcall(function()
        loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()
        State.InfiniteYield = true
        Notify("Infinite Yield","Loaded! Type ;cmds",5)
    end)
end

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name                   = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle           = HUB.Name,
    LoadingSubtitle        = "Party Griefer by " .. HUB.Author,
    Theme                  = "Amethyst",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",     name="Main",     icon="home"},
    {key="Party",    name="Party FX", icon="party-popper"},
    {key="Grief",    name="Grief",    icon="skull"},
    {key="Character",name="Character",icon="user"},
    {key="Movement", name="Movement", icon="footprints"},
    {key="Visuals",  name="Visuals",  icon="sun"},
    {key="AntiLag",  name="AntiLag",  icon="shield"},
    {key="ESP",      name="ESP",      icon="eye"},
    {key="Utility",  name="Utility",  icon="wrench"},
    {key="Settings", name="Settings", icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- MAIN TAB
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("Info")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Type: Party / Venue griefer")
    T:CreateLabel("Author: " .. HUB.Author)
    T:CreateSection("Warnings")
    T:CreateLabel("Grief features spawn objects LOCALLY")
    T:CreateLabel("They lag YOUR client but visible to you")
    T:CreateLabel("Some effects (Explosion/Sound) are server-side")
    T:CreateLabel("Use responsibly! May get you banned")
    T:CreateSection("Keybinds")
    T:CreateLabel("End = Kill all effects (panic)")
    T:CreateLabel("Home = Toggle Anti-Flash")
    T:CreateLabel("Insert = Toggle Fly")
    T:CreateSection("Quick Actions")
    T:CreateButton({Name="PANIC — Kill All Effects", Callback=function()
        -- Disable all grief
        State.DiscoFloor=false; Party.SetDiscoFloor(false)
        State.DiscoLighting=false; Party.SetDiscoLighting(false)
        State.Strobe=false; Party.SetStrobe(false)
        State.RainbowParts=false; Party.SetRainbowParts(false)
        State.FogSpam=false; Party.SetFogSpam(false)
        State.SkyChanger=false; Party.SetSkyChanger(false)
        State.LagBombActive=false; Grief.SetLagBomb(false)
        State.ParticleSpam=false; Grief.SetParticleSpam(false)
        State.FlashSpam=false; Grief.SetFlashSpam(false)
        State.ExplosionSpam=false; Grief.SetExplosionSpam(false)
        State.SoundSpam=false; Grief.SetSoundSpam(false)
        State.BeamSpam=false; Grief.SetBeamSpam(false)
        State.ChatSpam=false
        State.ScreenShake=false; Party.SetScreenShake(false)
        Notify("PANIC","All effects killed",3)
    end})
    T:CreateButton({Name="Load Infinite Yield", Callback=LoadInfYield})
    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","Job ID",3) end
    end})
end

-- PARTY FX TAB
if Tabs.Party then
    local T = Tabs.Party
    T:CreateSection("Disco Floor")
    T:CreateToggle({Name="Rainbow Dance Floor", CurrentValue=false, Flag="DF",
        Callback=function(v) State.DiscoFloor=v; Party.SetDiscoFloor(v) end})
    T:CreateSlider({Name="Floor Speed (x0.1s)", Range={1,10}, Increment=1, CurrentValue=3, Flag="DFS",
        Callback=function(v) State.DiscoFloorSpeed = (tonumber(v) or 3) * 0.1 end})

    T:CreateSection("Disco Lighting")
    T:CreateToggle({Name="Rainbow Lighting", CurrentValue=false, Flag="DL",
        Callback=function(v) State.DiscoLighting=v; Party.SetDiscoLighting(v) end})
    T:CreateSlider({Name="Light Speed (x0.1s)", Range={1,10}, Increment=1, CurrentValue=2, Flag="DLS",
        Callback=function(v) State.DiscoLightSpeed = (tonumber(v) or 2) * 0.1 end})

    T:CreateSection("Strobe Light")
    T:CreateToggle({Name="Strobe Effect", CurrentValue=false, Flag="ST",
        Callback=function(v) State.Strobe=v; Party.SetStrobe(v) end})
    T:CreateSlider({Name="Strobe Speed (ms)", Range={20,500}, Increment=10, CurrentValue=50, Flag="STS",
        Callback=function(v) State.StrobeSpeed = (tonumber(v) or 50) / 1000 end})
    T:CreateSlider({Name="Strobe Intensity", Range={1,10}, Increment=1, CurrentValue=1, Flag="STI",
        Callback=function(v) State.StrobeIntensity = tonumber(v) or 1 end})

    T:CreateSection("Rainbow Everything")
    T:CreateToggle({Name="Rainbow All Parts", CurrentValue=false, Flag="RP",
        Callback=function(v) State.RainbowParts=v; Party.SetRainbowParts(v) end})
    T:CreateSlider({Name="Rainbow Speed (x0.1s)", Range={1,10}, Increment=1, CurrentValue=1, Flag="RPS",
        Callback=function(v) State.RainbowSpeed = (tonumber(v) or 1) * 0.1 end})

    T:CreateSection("Colored Fog")
    T:CreateToggle({Name="Fog Spam", CurrentValue=false, Flag="FGS",
        Callback=function(v) State.FogSpam=v; Party.SetFogSpam(v) end})
    T:CreateDropdown({Name="Fog Color",
        Options={"Random","Red","Green","Blue","Purple"},
        CurrentOption={"Random"}, Flag="FGC",
        Callback=function(v) State.FogColor = (type(v)=="table" and v[1]) or v end})

    T:CreateSection("Sky")
    T:CreateToggle({Name="Sky Changer", CurrentValue=false, Flag="SKY",
        Callback=function(v) State.SkyChanger=v; Party.SetSkyChanger(v) end})

    T:CreateSection("Screen Effects")
    T:CreateToggle({Name="Screen Shake", CurrentValue=false, Flag="SS",
        Callback=function(v) State.ScreenShake=v; Party.SetScreenShake(v) end})
    T:CreateSlider({Name="Shake Intensity", Range={1,20}, Increment=1, CurrentValue=5, Flag="SSI",
        Callback=function(v) State.ScreenShakeIntensity = tonumber(v) or 5 end})
end

-- GRIEF TAB
if Tabs.Grief then
    local T = Tabs.Grief

    T:CreateSection("WARNING: These may get you banned")

    T:CreateSection("Lag Bomb (Local particles + parts)")
    T:CreateToggle({Name="Lag Bomb Active", CurrentValue=false, Flag="LB",
        Callback=function(v) State.LagBombActive=v; Grief.SetLagBomb(v) end})
    T:CreateSlider({Name="Lag Intensity", Range={10,500}, Increment=10, CurrentValue=100, Flag="LBI",
        Callback=function(v) State.LagBombIntensity = tonumber(v) or 100 end})

    T:CreateSection("Particle Spam (attaches to all players)")
    T:CreateToggle({Name="Particle Spam", CurrentValue=false, Flag="PS",
        Callback=function(v) State.ParticleSpam=v; Grief.SetParticleSpam(v) end})
    T:CreateSlider({Name="Particle Rate", Range={10,500}, Increment=10, CurrentValue=50, Flag="PSC",
        Callback=function(v) State.ParticleSpamCount = tonumber(v) or 50 end})

    T:CreateSection("Flash Spam (blinds YOUR screen)")
    T:CreateToggle({Name="Flash Spam (self only)", CurrentValue=false, Flag="FS",
        Callback=function(v) State.FlashSpam=v; Grief.SetFlashSpam(v) end})
    T:CreateSlider({Name="Flash Speed (ms)", Range={20,500}, Increment=10, CurrentValue=100, Flag="FSS",
        Callback=function(v) State.FlashSpamSpeed = (tonumber(v) or 100) / 1000 end})

    T:CreateSection("Explosion Spam (server-side, visible to all)")
    T:CreateToggle({Name="Explosion Spam", CurrentValue=false, Flag="EXS",
        Callback=function(v) State.ExplosionSpam=v; Grief.SetExplosionSpam(v) end})
    T:CreateSlider({Name="Explosion Rate (x0.1s)", Range={1,20}, Increment=1, CurrentValue=5, Flag="EXR",
        Callback=function(v) State.ExplosionRate = (tonumber(v) or 5) * 0.1 end})

    T:CreateSection("Sound Spam (server-side loud sounds)")
    T:CreateToggle({Name="Sound Spam", CurrentValue=false, Flag="SN",
        Callback=function(v) State.SoundSpam=v; Grief.SetSoundSpam(v) end})
    T:CreateInput({Name="Sound Asset ID", PlaceholderText="9040032945",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.SoundSpamId = tostring(v or "9040032945") end})
    T:CreateSlider({Name="Sound Volume", Range={1,10}, Increment=1, CurrentValue=10, Flag="SNV",
        Callback=function(v) State.SoundSpamVolume = tonumber(v) or 10 end})

    T:CreateSection("Beam Spam (visual)")
    T:CreateToggle({Name="Beam Spam", CurrentValue=false, Flag="BS",
        Callback=function(v) State.BeamSpam=v; Grief.SetBeamSpam(v) end})
    T:CreateSlider({Name="Beams per player", Range={1,50}, Increment=1, CurrentValue=20, Flag="BSC",
        Callback=function(v) State.BeamSpamCount = tonumber(v) or 20 end})

    T:CreateSection("Chat Spam (uses game's chat)")
    T:CreateInput({Name="Chat Message", PlaceholderText="X0DEC04T Party Hub",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.ChatSpamMsg = tostring(v or "X0DEC04T") end})
    T:CreateSlider({Name="Chat Delay (x0.5s)", Range={1,20}, Increment=1, CurrentValue=2, Flag="CSD",
        Callback=function(v) State.ChatSpamDelay = (tonumber(v) or 2) * 0.5 end})
    T:CreateToggle({Name="Chat Spam", CurrentValue=false, Flag="CS",
        Callback=function(v) State.ChatSpam=v; Grief.SetChatSpam(v) end})
end

-- CHARACTER TAB
if Tabs.Character then
    local T = Tabs.Character
    T:CreateSection("Rainbow / Glow")
    T:CreateToggle({Name="Rainbow Character", CurrentValue=false, Flag="RC",
        Callback=function(v) State.RainbowChar=v; CharFX.SetRainbowChar(v) end})
    T:CreateToggle({Name="Glow Character", CurrentValue=false, Flag="GC",
        Callback=function(v) State.GlowChar=v; CharFX.SetGlowChar(v) end})
    T:CreateColorPicker({Name="Glow Color", Color=Color3.fromRGB(255,50,255), Flag="GCC",
        Callback=function(v)
            State.GlowColor = v
            if State.GlowChar then CharFX.SetGlowChar(true) end
        end})

    T:CreateSection("Size Modifiers")
    T:CreateToggle({Name="Big Head", CurrentValue=false, Flag="BH",
        Callback=function(v) State.BigHead=v; CharFX.SetBigHead(v) end})
    T:CreateSlider({Name="Head Size", Range={2,20}, Increment=1, CurrentValue=5, Flag="BHS",
        Callback=function(v)
            State.BigHeadSize = tonumber(v) or 5
            if State.BigHead then CharFX.SetBigHead(true) end
        end})
    T:CreateToggle({Name="Small Character", CurrentValue=false, Flag="SC",
        Callback=function(v) State.SmallChar=v; CharFX.SetSmallChar(v) end})
    T:CreateSlider({Name="Small Scale (x0.1)", Range={1,9}, Increment=1, CurrentValue=3, Flag="SCS",
        Callback=function(v)
            State.SmallCharSize = (tonumber(v) or 3) * 0.1
            if State.SmallChar then CharFX.SetSmallChar(true) end
        end})

    T:CreateSection("Trail")
    T:CreateToggle({Name="Character Trail", CurrentValue=false, Flag="TR",
        Callback=function(v) State.TrailEnabled=v; CharFX.SetTrail(v) end})
    T:CreateDropdown({Name="Trail Color",
        Options={"Rainbow","Pink"},
        CurrentOption={"Rainbow"}, Flag="TRC",
        Callback=function(v)
            State.TrailColor = (type(v)=="table" and v[1]) or v
            if State.TrailEnabled then CharFX.SetTrail(true) end
        end})
end

-- MOVEMENT TAB
if Tabs.Movement then
    local T = Tabs.Movement
    T:CreateSection("Speed & Jump")
    T:CreateSlider({Name="Walk Speed", Range={16,200}, Increment=1, CurrentValue=16, Flag="WS",
        Callback=function(v) State.WalkSpeed = tonumber(v) or 16; Move.Speed() end})
    T:CreateSlider({Name="Jump Power", Range={50,500}, Increment=10, CurrentValue=50, Flag="JP",
        Callback=function(v) State.JumpPower = tonumber(v) or 50; Move.Jump() end})

    T:CreateSection("Special")
    T:CreateToggle({Name="NoClip", CurrentValue=false, Flag="NC",
        Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end})
    T:CreateToggle({Name="Infinite Jump", CurrentValue=false, Flag="IJ",
        Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end})
    T:CreateToggle({Name="Fly (WASD + Space/Ctrl)", CurrentValue=false, Flag="FLY",
        Callback=function(v) State.FlyEnabled=v; Move.SetFly(v) end})
    T:CreateSlider({Name="Fly Speed", Range={10,300}, Increment=10, CurrentValue=50, Flag="FLYS",
        Callback=function(v) State.FlySpeed = tonumber(v) or 50 end})
end

-- VISUALS TAB
if Tabs.Visuals then
    local T = Tabs.Visuals
    T:CreateSection("Lighting")
    T:CreateToggle({Name="FullBright", CurrentValue=false, Flag="FB",
        Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    T:CreateToggle({Name="No Fog", CurrentValue=false, Flag="NF",
        Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    T:CreateSlider({Name="Time of Day", Range={0,24}, Increment=1, CurrentValue=14, Flag="TOD",
        Callback=function(v) State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime) end})

    T:CreateSection("Camera")
    T:CreateSlider({Name="FOV", Range={30,120}, Increment=5, CurrentValue=70, Flag="FOV",
        Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end})
    T:CreateToggle({Name="Freecam", CurrentValue=false, Flag="FC",
        Callback=function(v) State.FreecamActive=v; Vis.Freecam(v) end})

    T:CreateSection("Audio")
    T:CreateToggle({Name="Mute All Sounds", CurrentValue=false, Flag="MA",
        Callback=function(v) State.MuteAll=v; Vis.MuteAll(v) end})
    T:CreateToggle({Name="Mute BG Music", CurrentValue=false, Flag="MB",
        Callback=function(v) State.MuteBGM=v; Vis.MuteBGM(v) end})
    T:CreateToggle({Name="Boost Music", CurrentValue=false, Flag="MBS",
        Callback=function(v) State.MusicBoost=v; Vis.MusicBoost(v) end})
    T:CreateSlider({Name="Music Volume", Range={1,10}, Increment=1, CurrentValue=5, Flag="MV",
        Callback=function(v)
            State.MusicVolume = tonumber(v) or 5
            if State.MusicBoost then Vis.MusicBoost(true) end
        end})
end

-- ANTI-LAG TAB
if Tabs.AntiLag then
    local T = Tabs.AntiLag
    T:CreateSection("Protection for YOU")
    T:CreateToggle({Name="Anti-Flash (removes bright effects)", CurrentValue=true, Flag="AF",
        Callback=function(v) State.AntiFlashSelf=v; AntiLag.SetAntiFlash(v) end})
    T:CreateToggle({Name="Anti-Lag Mode (max FPS)", CurrentValue=false, Flag="AL",
        Callback=function(v) State.AntiLagMode=v; AntiLag.SetAntiLag(v) end})
    T:CreateToggle({Name="Low Graphics", CurrentValue=false, Flag="LG",
        Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end})

    T:CreateSection("Cleanup")
    T:CreateButton({Name="Kill All Particles", Callback=function()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Fire")
            or v:IsA("Smoke") or v:IsA("Sparkles") then
                pcall(function() v.Enabled = false end)
            end
        end
        Notify("Cleanup","Particles killed",3)
    end})
    T:CreateButton({Name="Kill All Beams/Trails", Callback=function()
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("Beam") or v:IsA("Trail") then
                pcall(function() v.Enabled = false end)
            end
        end
        Notify("Cleanup","Beams/Trails killed",3)
    end})
    T:CreateButton({Name="Kill All Sounds", Callback=function()
        for _, s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") then pcall(function() s:Stop(); s.Volume=0 end) end
        end
        Notify("Cleanup","Sounds killed",3)
    end})
end

-- ESP TAB
if Tabs.ESP then
    local T = Tabs.ESP
    T:CreateSection("Player ESP")
    T:CreateToggle({Name="Show All Players", CurrentValue=false, Flag="EP",
        Callback=function(v)
            State.ESP_Players=v
            if not v then ESP.ClearAll() else ESP.RefreshAll() end
        end})
    T:CreateToggle({Name="Show Distance", CurrentValue=true, Flag="ED",
        Callback=function(v) State.ESP_ShowDistance=v end})
    T:CreateSlider({Name="Max Distance", Range={50,2000}, Increment=50, CurrentValue=500, Flag="EMD",
        Callback=function(v) State.ESP_MaxDist=tonumber(v) or 500 end})
    T:CreateButton({Name="Refresh ESP", Callback=function() ESP.ClearAll(); ESP.RefreshAll() end})
end

-- UTILITY TAB
if Tabs.Utility then
    local T = Tabs.Utility
    T:CreateSection("Anti-AFK")
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="AAF",
        Callback=function(v) State.AntiAFK=v end})

    T:CreateSection("Character")
    T:CreateToggle({Name="Hide Own Name", CurrentValue=false, Flag="HN",
        Callback=function(v)
            State.HideName=v
            local ch = LocalPlayer.Character
            if ch then
                local head = ch:FindFirstChild("Head")
                if head then
                    for _, g in ipairs(head:GetChildren()) do
                        if g:IsA("BillboardGui") then g.Enabled = not v end
                    end
                end
            end
        end})

    T:CreateSection("Server")
    T:CreateButton({Name="Server Hop", Callback=function()
        pcall(function()
            local raw = game:HttpGet(
                "https://games.roblox.com/v1/games/"..tostring(game.PlaceId)
                .."/servers/Public?sortOrder=Asc&limit=100")
            local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
            if dok and data and data.data then
                for _, s in ipairs(data.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        return
                    end
                end
            end
            Notify("Hop","No server found",4)
        end)
    end})
    T:CreateButton({Name="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end})
    T:CreateToggle({Name="Auto Rejoin on Kick", CurrentValue=false, Flag="AR",
        Callback=function(v) State.AutoRejoin=v end})

    T:CreateSection("Scripts")
    T:CreateButton({Name="Load Infinite Yield", Callback=LoadInfYield})
end

-- SETTINGS TAB
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("Credits")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Author: " .. HUB.Author)
    T:CreateLabel("For Party/Venue games")
    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Hub", Callback=function()
        -- Disable everything
        for _, key in ipairs({
            "NoClipConn","InfJumpConn","FlyConn","FreecamConn",
            "DiscoFloorConn","DiscoLightConn","StrobeConn",
            "RainbowConn","FogSpamConn","SkyConn",
            "LagBombConn","ParticleConn","FlashConn",
            "ExplosionConn","SoundConn","BeamConn",
            "ScreenShakeConn","RainbowCharConn","ESPRenderConn",
        }) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.ChatSpam=false
        Party.SetDiscoFloor(false); Party.SetDiscoLighting(false)
        Party.SetStrobe(false); Party.SetRainbowParts(false)
        Party.SetFogSpam(false); Party.SetSkyChanger(false)
        Grief.SetLagBomb(false); Grief.SetParticleSpam(false)
        Grief.SetFlashSpam(false); Grief.SetExplosionSpam(false)
        Grief.SetSoundSpam(false); Grief.SetBeamSpam(false)
        CharFX.SetRainbowChar(false); CharFX.SetGlowChar(false)
        CharFX.SetBigHead(false); CharFX.SetSmallChar(false)
        CharFX.SetTrail(false)
        ESP.ClearAll()
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        if State.ScreenBlindGui then pcall(function() State.ScreenBlindGui:Destroy() end) end
        CM:Cleanup()
        pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        _G[INSTANCE_KEY] = nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- KEYBINDS
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.End then
        -- Panic
        State.DiscoFloor=false; Party.SetDiscoFloor(false)
        State.DiscoLighting=false; Party.SetDiscoLighting(false)
        State.Strobe=false; Party.SetStrobe(false)
        State.RainbowParts=false; Party.SetRainbowParts(false)
        State.FogSpam=false; Party.SetFogSpam(false)
        State.LagBombActive=false; Grief.SetLagBomb(false)
        State.ParticleSpam=false; Grief.SetParticleSpam(false)
        State.FlashSpam=false; Grief.SetFlashSpam(false)
        State.ExplosionSpam=false; Grief.SetExplosionSpam(false)
        State.SoundSpam=false; Grief.SetSoundSpam(false)
        State.BeamSpam=false; Grief.SetBeamSpam(false)
        State.ChatSpam=false
        State.ScreenShake=false; Party.SetScreenShake(false)
        Notify("PANIC","All effects killed",3)
    elseif inp.KeyCode == Enum.KeyCode.Home then
        State.AntiFlashSelf = not State.AntiFlashSelf
        AntiLag.SetAntiFlash(State.AntiFlashSelf)
        Notify("Anti-Flash", State.AntiFlashSelf and "ON" or "OFF", 2)
    elseif inp.KeyCode == Enum.KeyCode.Insert then
        State.FlyEnabled = not State.FlyEnabled
        Move.SetFly(State.FlyEnabled)
        Notify("Fly", State.FlyEnabled and "ON" or "OFF", 2)
    end
end, "Keybinds")

-- CHARACTER RESPAWN
CM:Add(LocalPlayer.CharacterAdded, function()
    State.OriginalCharColors = {}
    State.OriginalHeadSize = nil
    task.wait(1)
    pcall(Move.Speed); pcall(Move.Jump)
    if State.NoClip       then pcall(Move.SetNoClip, true) end
    if State.InfJump      then pcall(Move.SetInfJump, true) end
    if State.FlyEnabled   then pcall(Move.SetFly, true) end
    if State.FullBright   then pcall(Vis.FullBright, true) end
    if State.NoFog        then pcall(Vis.NoFog, true) end
    if State.FOV ~= 70    then pcall(Vis.SetFOV, State.FOV) end
    if State.RainbowChar  then pcall(CharFX.SetRainbowChar, true) end
    if State.GlowChar     then pcall(CharFX.SetGlowChar, true) end
    if State.BigHead      then pcall(CharFX.SetBigHead, true) end
    if State.SmallChar    then pcall(CharFX.SetSmallChar, true) end
    if State.TrailEnabled then pcall(CharFX.SetTrail, true) end
end, "CharAdded")

-- Apply anti-flash on load if defaulted on
if State.AntiFlashSelf then AntiLag.SetAntiFlash(true) end

-- GLOBAL INSTANCE
_G[INSTANCE_KEY] = {
    version   = HUB.Version,
    timestamp = os.time(),
    destroy   = function()
        for _, key in ipairs({
            "NoClipConn","InfJumpConn","FlyConn","FreecamConn",
            "DiscoFloorConn","DiscoLightConn","StrobeConn",
            "RainbowConn","FogSpamConn","SkyConn",
            "LagBombConn","ParticleConn","FlashConn",
            "ExplosionConn","SoundConn","BeamConn",
            "ScreenShakeConn","RainbowCharConn","ESPRenderConn",
        }) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.ChatSpam=false
        pcall(function()
            Party.SetDiscoFloor(false); Party.SetDiscoLighting(false)
            Party.SetStrobe(false); Party.SetRainbowParts(false)
            Party.SetFogSpam(false); Party.SetSkyChanger(false)
            Grief.SetLagBomb(false); Grief.SetParticleSpam(false)
            Grief.SetFlashSpam(false); Grief.SetExplosionSpam(false)
            Grief.SetSoundSpam(false); Grief.SetBeamSpam(false)
            CharFX.SetRainbowChar(false); CharFX.SetGlowChar(false)
            CharFX.SetBigHead(false); CharFX.SetSmallChar(false)
            CharFX.SetTrail(false)
            ESP.ClearAll()
            if ESPGui then ESPGui:Destroy() end
            if State.ScreenBlindGui then State.ScreenBlindGui:Destroy() end
        end)
        CM:Cleanup()
        pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        pcall(function() Rayfield:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." loaded! Press End = Panic", 5)
Log("Ready — Party Hub loaded")
