--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Tools - Cinematic Suite v2.4.1 [Fluent UI]
-- FULL HD | Clear Frame Auto Cine | Floating Logo | Fixed Icons
--═══════════════════════════════════════════════════════════════════════════════

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local Workspace           = game:GetService("Workspace")
local CoreGui             = game:GetService("CoreGui")
local TextChatService     = game:GetService("TextChatService")
local LocalizationService = game:GetService("LocalizationService")
local StarterGui          = game:GetService("StarterGui")
local ContentProvider     = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local TOOL_KEY = "__X0DEC04T_Tools_v241"
if _G[TOOL_KEY] then
    local prev = _G[TOOL_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[TOOL_KEY] = nil
    task.wait(0.2)
end

local function Log(m) print("[X0DEC04T Tools] " .. tostring(m)) end
Log("v2.4.1 starting")

--------------------------------------------------------------------------------
-- FLUENT LOAD
--------------------------------------------------------------------------------
local Fluent, SaveManager, InterfaceManager
local ok1, r1 = pcall(function()
    return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
end)
if not ok1 or not r1 then error("[X0DEC04T] Fluent failed: " .. tostring(r1)) end
Fluent = r1

local ok2, r2 = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
end)
SaveManager = ok2 and r2 or nil

local ok3, r3 = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
end)
InterfaceManager = ok3 and r3 or nil

local TOOL = {
    Name    = "X0DEC04T Tools",
    Version = "2.4.1",
    Author  = "voixera",
    Discord = "discord.gg/x0dec04t",
    LogoId  = "rbxassetid://85855925276969",
}

--------------------------------------------------------------------------------
-- CONNECTION MANAGER
--------------------------------------------------------------------------------
local CM = { _list = {} }
function CM:Add(sig, cb)
    if not sig then return end
    local ok, conn = pcall(function() return sig:Connect(cb) end)
    if ok and conn then table.insert(self._list, conn); return conn end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------
local function IsTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, cfg = pcall(function() return TextChatService.ChatInputBarConfiguration end)
    if ok and cfg and cfg.IsFocused then return true end
    return false
end

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Char()  return LocalPlayer.Character end
local function HRP()   local c = Char(); return c and c:FindFirstChild("HumanoidRootPart") end

local function Notif(t, c, d)
    pcall(function()
        Fluent:Notify({ Title = tostring(t), Content = tostring(c), Duration = tonumber(d) or 3 })
    end)
end

--------------------------------------------------------------------------------
-- GRAPHICS QUALITY
--------------------------------------------------------------------------------
local GfxBackup = {}
local function BackupGfx()
    if next(GfxBackup) then return end
    pcall(function()
        GfxBackup = {
            QualityLevel = settings().Rendering.QualityLevel,
            GlobalShadows = Lighting.GlobalShadows,
            Brightness = Lighting.Brightness,
            EnvDiff = Lighting.EnvironmentDiffuseScale,
            EnvSpec = Lighting.EnvironmentSpecularScale,
        }
    end)
end
local function SetQuality(level)
    BackupGfx()
    local q = {
        MAX    = {Q=Enum.QualityLevel.Level21, S=true, B=2.5, D=1,   P=1   },
        Ultra  = {Q=Enum.QualityLevel.Level21, S=true, B=2,   D=1,   P=1   },
        High   = {Q=Enum.QualityLevel.Level14, S=true, B=1.5, D=0.8, P=0.8 },
        Medium = {Q=Enum.QualityLevel.Level10, S=true, B=1.2, D=0.5, P=0.5 },
        Low    = {Q=Enum.QualityLevel.Level05, S=false,B=1,   D=0.3, P=0   },
        Potato = {Q=Enum.QualityLevel.Level01, S=false,B=0.8, D=0,   P=0   },
    }
    local s = q[level]; if not s then return end
    pcall(function()
        settings().Rendering.QualityLevel = s.Q
        Lighting.GlobalShadows            = s.S
        Lighting.Brightness               = s.B
        Lighting.EnvironmentDiffuseScale  = s.D
        Lighting.EnvironmentSpecularScale = s.P
        if level == "MAX" then
            Lighting.ShadowSoftness = 0.5
            Lighting.GlobalShadows = true
            pcall(function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
        end
    end)
end

--------------------------------------------------------------------------------
-- LIGHTING BACKUP / RESTORE
--------------------------------------------------------------------------------
local LightingBackup = {}
local function BackupLighting()
    if next(LightingBackup) then return end
    pcall(function()
        LightingBackup = {
            Ambient              = Lighting.Ambient,
            OutdoorAmbient       = Lighting.OutdoorAmbient,
            Brightness           = Lighting.Brightness,
            ClockTime            = Lighting.ClockTime,
            FogEnd               = Lighting.FogEnd,
            FogStart             = Lighting.FogStart,
            FogColor             = Lighting.FogColor,
            GlobalShadows        = Lighting.GlobalShadows,
            ExposureCompensation = Lighting.ExposureCompensation,
            EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        }
    end)
end
local function RestoreLighting()
    for k, v in pairs(LightingBackup) do pcall(function() Lighting[k] = v end) end
end

local function GetOrCreate(parent, className, name)
    local e = parent:FindFirstChild(name or className)
    if e and e:IsA(className) then return e end
    local inst = Instance.new(className)
    inst.Name = name or className; inst.Parent = parent
    return inst
end
local function RemoveEffect(name)
    local e = Lighting:FindFirstChild(name); if e then e:Destroy() end
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local State = {
    -- Freecam
    FreecamActive      = false,
    FreecamSpeed       = 20,
    FreecamFOV         = 70,
    FreecamSensitivity = 0.4,
    FreecamRollEnabled = false,
    FreecamSmoothing   = 0.15,
    _fcTargetCF = nil, _fcCurrentCF = nil,
    _fcPitch = 0, _fcYaw = 0, _fcRoll = 0,
    _fcSavedCamType = nil, _fcSavedFOV = 70,

    -- Gameplay HD
    GameplayHD      = false,
    GameplayQuality = "MAX",
    GameplayFOV     = 75,

    -- Cinematic Bars
    CineBarsActive  = false,
    CineBarsSize    = 0.08,
    CineBarsGui     = nil,
    CineBarsAnim    = true,
    _cineBarTop     = nil,
    _cineBarBot     = nil,
    _cineBarsLocked = false,

    -- Frame
    FrameGui     = nil,
    FrameMode    = "None",
    FrameOpacity = 1.0,
    FrameColor   = Color3.new(0, 0, 0),

    -- DOF
    DOFEnabled = false, DOFFarIntensity = 0, DOFFocusDist = 30,
    DOFInFocusRadius = 5, DOFNearIntensity = 0, DOFAutoFocus = false,

    -- Color Correction
    ColorEnabled = false, ColorBrightness = 0, ColorContrast = 0,
    ColorSaturation = 0, ColorTintR = 1, ColorTintG = 1, ColorTintB = 1,

    -- Bloom
    BloomEnabled = false, BloomIntensity = 0.5, BloomSize = 24, BloomThreshold = 2,

    -- Sun Rays
    SunRaysEnabled = false, SunRaysIntensity = 0.25, SunRaysSpread = 0.5,

    -- Atmosphere
    AtmoEnabled = false, AtmoDensity = 0.395, AtmoOffset = 0,
    AtmoColor = Color3.fromRGB(199,199,199), AtmoDecay = Color3.fromRGB(106,112,125),
    AtmoGlare = 0, AtmoHaze = 0,

    -- HDR
    HDREnabled = false, ExposureComp = 0,

    -- Photo Mode
    PhotoModeActive = false, PhotoHideUI = true, PhotoHideChar = false,
    PhotoGridLines = false, PhotoGridGui = nil,

    -- Auto Cinematic
    AutoCineActive = false, AutoCineLoop = true, AutoCineSpeed = 0.3,
    AutoCineWaypoints = {}, AutoCineIndex = 1, AutoCineTween = nil,
    AutoCineEasing = "Sine", _autoCineConn = nil,
    AutoCineClearFrame = true,   -- Clear bars + frame during cine for clean shot
    _savedFrameMode = "None",    -- Remember frame to restore

    -- Camera Shake
    ShakeActive = false, ShakeIntensity = 0.5, ShakeSpeed = 10, ShakeType = "Sine",

    -- Time
    TimeAnimActive = false, TimeAnimSpeed = 1,

    -- Floating Logo
    FloatingLogo         = true,
    LogoGui              = nil,
    LogoImage            = nil,
    LogoSize             = 60,
    LogoTransparency     = 0.1,

    CurrentPreset = "None",
}

--------------------------------------------------------------------------------
-- APPLY LIGHTING EFFECTS
--------------------------------------------------------------------------------
local function ApplyDOF()
    local d = GetOrCreate(Lighting,"DepthOfFieldEffect","X0_DOF")
    d.Enabled = State.DOFEnabled; d.FarIntensity = State.DOFFarIntensity
    d.FocusDistance = State.DOFFocusDist; d.InFocusRadius = State.DOFInFocusRadius
    d.NearIntensity = State.DOFNearIntensity
end
local function ApplyCC()
    local c = GetOrCreate(Lighting,"ColorCorrectionEffect","X0_CC")
    c.Enabled = State.ColorEnabled; c.Brightness = State.ColorBrightness
    c.Contrast = State.ColorContrast; c.Saturation = State.ColorSaturation
    c.TintColor = Color3.new(math.clamp(State.ColorTintR,0,5),math.clamp(State.ColorTintG,0,5),math.clamp(State.ColorTintB,0,5))
end
local function ApplyBloom()
    local b = GetOrCreate(Lighting,"BloomEffect","X0_Bloom")
    b.Enabled = State.BloomEnabled; b.Intensity = State.BloomIntensity
    b.Size = State.BloomSize; b.Threshold = State.BloomThreshold
end
local function ApplySunRays()
    local s = GetOrCreate(Lighting,"SunRaysEffect","X0_SunRays")
    s.Enabled = State.SunRaysEnabled; s.Intensity = State.SunRaysIntensity
    s.Spread = State.SunRaysSpread
end
local function ApplyAtmo()
    local a = GetOrCreate(Lighting,"Atmosphere","X0_Atmo")
    a.Density = State.AtmoDensity; a.Offset = State.AtmoOffset
    a.Color = State.AtmoColor; a.Decay = State.AtmoDecay
    a.Glare = State.AtmoGlare; a.Haze = State.AtmoHaze
end
local function ApplyHDR()
    BackupLighting()
    if State.HDREnabled then
        pcall(function()
            Lighting.ExposureCompensation = State.ExposureComp
            Lighting.EnvironmentDiffuseScale = 1
            Lighting.EnvironmentSpecularScale = 1
            Lighting.GlobalShadows = true
        end)
    end
end
local function RemoveAllEffects()
    for _,n in ipairs({"X0_DOF","X0_CC","X0_Bloom","X0_SunRays","X0_Atmo"}) do RemoveEffect(n) end
    State.DOFEnabled=false; State.ColorEnabled=false; State.BloomEnabled=false
    State.SunRaysEnabled=false; State.AtmoEnabled=false; State.HDREnabled=false
end

--------------------------------------------------------------------------------
-- CINEMATIC BARS
--------------------------------------------------------------------------------
local function SetCineBars(enable, animate, lock)
    if enable and State.CineBarsActive and State._cineBarsLocked and lock then
        return
    end

    if not enable then
        if State.CineBarsGui then
            local sg = State.CineBarsGui
            local top = State._cineBarTop
            local bot = State._cineBarBot

            if animate and State.CineBarsAnim and top and bot and top.Parent and bot.Parent then
                local dur = 0.4
                TweenService:Create(top, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { Size = UDim2.new(1, 0, 0, 0) }):Play()
                local tw2 = TweenService:Create(bot, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                    { Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, 0) })
                tw2:Play()
                tw2.Completed:Connect(function() pcall(function() sg:Destroy() end) end)
            else
                pcall(function() sg:Destroy() end)
            end
            State.CineBarsGui = nil
            State._cineBarTop = nil
            State._cineBarBot = nil
        end
        State.CineBarsActive = false
        State._cineBarsLocked = false
        return
    end

    if State.CineBarsGui then
        pcall(function() State.CineBarsGui:Destroy() end)
        State.CineBarsGui = nil
        State._cineBarTop = nil
        State._cineBarBot = nil
    end

    State.CineBarsActive = true
    if lock then State._cineBarsLocked = true end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_CineBars"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 998; sg.Parent = GuiParent()

    local barH = State.CineBarsSize

    local top = Instance.new("Frame", sg)
    top.BackgroundColor3 = Color3.new(0,0,0); top.BorderSizePixel = 0; top.ZIndex = 10

    local bot = Instance.new("Frame", sg)
    bot.BackgroundColor3 = Color3.new(0,0,0); bot.BorderSizePixel = 0; bot.ZIndex = 10

    if animate and State.CineBarsAnim then
        top.Size = UDim2.new(1,0,0,0); top.Position = UDim2.new(0,0,0,0)
        bot.Size = UDim2.new(1,0,0,0); bot.Position = UDim2.new(0,0,1,0)
        local dur = 0.5
        TweenService:Create(top, TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            { Size = UDim2.new(1,0,barH,0) }):Play()
        TweenService:Create(bot, TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
            { Size = UDim2.new(1,0,barH,0), Position = UDim2.new(0,0,1-barH,0) }):Play()
    else
        top.Size = UDim2.new(1,0,barH,0); top.Position = UDim2.new(0,0,0,0)
        bot.Size = UDim2.new(1,0,barH,0); bot.Position = UDim2.new(0,0,1-barH,0)
    end

    State.CineBarsGui = sg
    State._cineBarTop = top
    State._cineBarBot = bot
end

-- Bar watchdog (only runs when bars are locked)
task.spawn(function()
    while task.wait(0.5) do
        if State.AutoCineActive and State._cineBarsLocked then
            local top = State._cineBarTop
            local bot = State._cineBarBot
            local sg = State.CineBarsGui
            local needsRebuild = false

            if not sg or not sg.Parent then needsRebuild = true
            elseif not top or not top.Parent then needsRebuild = true
            elseif not bot or not bot.Parent then needsRebuild = true
            else
                local barH = State.CineBarsSize
                if top.Size.Y.Scale < barH - 0.005 or bot.Size.Y.Scale < barH - 0.005 then
                    pcall(function()
                        top.Size = UDim2.new(1, 0, barH, 0)
                        top.Position = UDim2.new(0, 0, 0, 0)
                        bot.Size = UDim2.new(1, 0, barH, 0)
                        bot.Position = UDim2.new(0, 0, 1 - barH, 0)
                    end)
                end
            end

            if needsRebuild then
                Log("[Bars] Rebuilding - bars were removed during AutoCine")
                SetCineBars(true, false, true)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- FRAME SYSTEM
--------------------------------------------------------------------------------
local FRAME_DEFS = {
    Portrait       = { ratio=9/16,  axis="H", label="9:16 Portrait"     },
    Landscape_16_9 = { ratio=16/9,  axis="V", label="16:9 Landscape"    },
    Square         = { ratio=1/1,   axis="H", label="1:1 Square"        },
    Widescreen_21_9= { ratio=21/9,  axis="V", label="21:9 Widescreen"   },
    Instagram_4_5  = { ratio=4/5,   axis="H", label="4:5 Instagram"     },
    Cinema_235     = { ratio=2.35,  axis="V", label="2.35:1 Cinema"     },
    Letterbox_185  = { ratio=1.85,  axis="V", label="1.85:1 Letterbox"  },
}

local function DestroyFrame()
    if State.FrameGui then pcall(function() State.FrameGui:Destroy() end); State.FrameGui = nil end
end

local function BuildFrame(mode, animate)
    DestroyFrame()
    if not mode or mode == "None" then return end
    local def = FRAME_DEFS[mode]; if not def then return end
    local vp = Camera.ViewportSize
    local vpW = math.max(1,vp.X); local vpH = math.max(1,vp.Y)
    local alpha = 1-math.clamp(State.FrameOpacity,0,1)
    local col = State.FrameColor; local dur = animate and 0.45 or 0

    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Frame"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    sg.DisplayOrder=996; sg.Parent=GuiParent()

    local function MakeBar(xS,yS,wS,hS,axS,ayS,awS,ahS)
        local f = Instance.new("Frame",sg)
        f.BackgroundColor3=col; f.BackgroundTransparency=alpha
        f.BorderSizePixel=0; f.ZIndex=8
        if dur>0 then
            f.Size=UDim2.new(awS or 0,0,ahS or 0,0)
            f.Position=UDim2.new(axS or xS,0,ayS or yS,0)
            TweenService:Create(f,TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
                {Size=UDim2.new(wS,0,hS,0),Position=UDim2.new(xS,0,yS,0)}):Play()
        else
            f.Size=UDim2.new(wS,0,hS,0); f.Position=UDim2.new(xS,0,yS,0)
        end
    end

    if def.axis == "H" then
        local cW = vpH*def.ratio; local bW = math.max(0,(vpW-cW)/2)/vpW
        if bW>0.001 then
            MakeBar(0,0,bW,1, 0,0,0,1)
            MakeBar(1-bW,0,bW,1, 1,0,0,1)
        end
    else
        local cH = vpW/def.ratio; local bH = math.max(0,(vpH-cH)/2)/vpH
        if bH>0.001 then
            MakeBar(0,0,1,bH, 0,0,1,0)
            MakeBar(0,1-bH,1,bH, 0,1,1,0)
        end
    end
    State.FrameGui = sg
end

local function SetFrame(mode,animate)
    State.FrameMode = mode or "None"
    BuildFrame(mode,animate)
    if mode ~= "None" then
        local def=FRAME_DEFS[mode]; Notif("Frame",(def and def.label) or mode,3)
    end
end

local _frameResizeConn = nil
local function StartFrameResize()
    if _frameResizeConn then pcall(function() _frameResizeConn:Disconnect() end) end
    _frameResizeConn = Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if State.FrameMode~="None" then task.defer(function() BuildFrame(State.FrameMode,false) end) end
    end)
end
StartFrameResize()

--------------------------------------------------------------------------------
-- GRID LINES
--------------------------------------------------------------------------------
local function SetGridLines(enable)
    if State.PhotoGridGui then pcall(function() State.PhotoGridGui:Destroy() end); State.PhotoGridGui=nil end
    if not enable then return end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Grid"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.DisplayOrder=997; sg.Parent=GuiParent()
    local function ML(x,y,w,h,a)
        local f=Instance.new("Frame",sg); f.Position=UDim2.new(x,0,y,0); f.Size=UDim2.new(w,0,h,0)
        f.BackgroundColor3=Color3.fromRGB(255,255,255); f.BackgroundTransparency=a or 0.72
        f.BorderSizePixel=0; f.ZIndex=9
    end
    ML(1/3,0,0.002,1); ML(2/3,0,0.002,1); ML(0,1/3,1,0.002); ML(0,2/3,1,0.002)
    ML(0.499,0,0.002,1,0.85); ML(0,0.499,1,0.002,0.85)
    ML(0.618,0,0.001,1,0.88); ML(0,0.618,1,0.001,0.88)
    State.PhotoGridGui=sg
end

--------------------------------------------------------------------------------
-- AUTO DOF FOCUS
--------------------------------------------------------------------------------
local AutoFocusConn = nil
local function SetAutoFocus(e)
    if AutoFocusConn then pcall(function() AutoFocusConn:Disconnect() end); AutoFocusConn=nil end
    if not e then return end
    AutoFocusConn = RunService.Heartbeat:Connect(function()
        if not State.DOFEnabled or not State.DOFAutoFocus then return end
        local vp=Camera.ViewportSize
        local ray=Camera:ScreenPointToRay(vp.X/2,vp.Y/2)
        local res=Workspace:Raycast(ray.Origin,ray.Direction*600)
        if res then State.DOFFocusDist=res.Distance
            local d=Lighting:FindFirstChild("X0_DOF"); if d then d.FocusDistance=res.Distance end
        end
    end)
end

--------------------------------------------------------------------------------
-- FREECAM
--------------------------------------------------------------------------------
local FreecamRSConn = nil

local function StopFreecam()
    State.FreecamActive = false
    if FreecamRSConn then pcall(function() FreecamRSConn:Disconnect() end); FreecamRSConn=nil end
    pcall(function()
        Camera.CameraType = State._fcSavedCamType or Enum.CameraType.Custom
        Camera.FieldOfView = State._fcSavedFOV
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
    Notif("Freecam","OFF",2)
end

local function StartFreecam()
    if State.FreecamActive then StopFreecam(); return end
    State.FreecamActive = true
    State._fcSavedCamType = Camera.CameraType
    State._fcSavedFOV = Camera.FieldOfView
    local cf=Camera.CFrame; local lv=cf.LookVector
    State._fcPitch=math.asin(math.clamp(-lv.Y,-1,1))
    State._fcYaw=math.atan2(-lv.X,-lv.Z); State._fcRoll=0
    State._fcCurrentCF=cf; State._fcTargetCF=cf
    pcall(function()
        Camera.CameraType=Enum.CameraType.Scriptable
        Camera.FieldOfView=State.FreecamFOV
        UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter
    end)

    FreecamRSConn = RunService.RenderStepped:Connect(function(dt)
        if not State.FreecamActive then return end
        pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end)
        local delta=UserInputService:GetMouseDelta(); local sens=State.FreecamSensitivity*0.01
        State._fcYaw=State._fcYaw-delta.X*sens
        State._fcPitch=math.clamp(State._fcPitch-delta.Y*sens,math.rad(-89),math.rad(89))
        if State.FreecamRollEnabled then
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then State._fcRoll=State._fcRoll+math.rad(1.2) end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then State._fcRoll=State._fcRoll-math.rad(1.2) end
        end
        local spd=State.FreecamSpeed*dt; local md=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md+Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md+Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+Vector3.new(1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md=md+Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then md=md+Vector3.new(0,-1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then spd=spd*4 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Z) then spd=spd*0.12 end
        local rotCF=CFrame.Angles(0,State._fcYaw,0)*CFrame.Angles(State._fcPitch,0,0)*CFrame.Angles(0,0,State._fcRoll)
        local wm=md.Magnitude>0 and (rotCF*(md.Unit*spd)) or Vector3.zero
        State._fcTargetCF=CFrame.new(State._fcTargetCF.Position+wm)*rotCF
        local a=math.clamp(1-State.FreecamSmoothing,0.01,1)
        State._fcCurrentCF=State._fcCurrentCF:Lerp(State._fcTargetCF,a)
        local shakeCF=CFrame.new()
        if State.ShakeActive then
            local t=tick()*State.ShakeSpeed; local i=State.ShakeIntensity*0.1
            if State.ShakeType=="Perlin" then
                shakeCF=CFrame.Angles(math.noise(t,0)*i,math.noise(0,t)*i,math.noise(0,0,t)*i)
            elseif State.ShakeType=="Trauma" then
                local sh=(State.ShakeIntensity*0.01)^2
                shakeCF=CFrame.Angles(math.noise(t*0.9)*sh,math.noise(t*1.1)*sh,math.noise(t*0.7)*sh)
            else shakeCF=CFrame.Angles(math.sin(t*1.3)*i,math.sin(t*0.9)*i,math.sin(t*1.7)*i) end
        end
        pcall(function() Camera.CFrame=State._fcCurrentCF*shakeCF; Camera.FieldOfView=State.FreecamFOV end)
    end)
    Notif("Freecam","ON - WASD | Ctrl=fast | Z=slow | Q/E=roll",5)
end

--------------------------------------------------------------------------------
-- CAMERA SHAKE
--------------------------------------------------------------------------------
local ShakeConn = nil
local function SetCameraShake(e)
    State.ShakeActive=e
    if ShakeConn then pcall(function() ShakeConn:Disconnect() end); ShakeConn=nil end
    if not e then return end
    if not State.FreecamActive then
        ShakeConn=RunService.RenderStepped:Connect(function()
            if not State.ShakeActive or State.FreecamActive then return end
            local t=tick()*State.ShakeSpeed; local i=State.ShakeIntensity*0.1
            pcall(function() Camera.CFrame=Camera.CFrame*CFrame.Angles(math.sin(t*1.3)*i,math.sin(t*0.9)*i,math.sin(t*1.7)*i) end)
        end)
    end
end

--------------------------------------------------------------------------------
-- FOV / TIME
--------------------------------------------------------------------------------
local function AnimateFOV(target,dur)
    dur=dur or 1; local s=Camera.FieldOfView; local st=tick()
    local conn; conn=RunService.RenderStepped:Connect(function()
        local a=math.clamp((tick()-st)/dur,0,1)
        Camera.FieldOfView=s+(target-s)*(1-(1-a)^3)
        if a>=1 then conn:Disconnect(); State.FreecamFOV=target end
    end)
end
local TimeAnimConn = nil
local function SetTimeAnim(e)
    State.TimeAnimActive=e
    if TimeAnimConn then pcall(function() TimeAnimConn:Disconnect() end); TimeAnimConn=nil end
    if not e then return end
    TimeAnimConn=RunService.Heartbeat:Connect(function(dt) Lighting.ClockTime=(Lighting.ClockTime+dt*State.TimeAnimSpeed)%24 end)
end

--------------------------------------------------------------------------------
-- PHOTO MODE
--------------------------------------------------------------------------------
local function SetPhotoMode(enable)
    State.PhotoModeActive=enable
    if enable then
        SetCineBars(true,true,false)
        if State.PhotoGridLines then SetGridLines(true) end
        if State.PhotoHideChar then
            local c=Char(); if c then for _,p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then pcall(function() p.LocalTransparencyModifier=1 end) end end end
        end
        if State.PhotoHideUI then pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end) end
        if not State.FreecamActive then StartFreecam() end
        Notif("Photo Mode","ON",4)
    else
        SetCineBars(false,true,false)
        SetGridLines(false)
        local c=Char(); if c then for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then pcall(function() p.LocalTransparencyModifier=0 end) end end end
        pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true) end)
        if State.FreecamActive then StopFreecam() end
        Notif("Photo Mode","OFF",2)
    end
end

--------------------------------------------------------------------------------
-- AUTO CINEMATIC
--------------------------------------------------------------------------------
local function SaveWaypoint()
    table.insert(State.AutoCineWaypoints, Camera.CFrame)
    Notif("Waypoint","Saved #"..#State.AutoCineWaypoints,2)
end
local function ClearWaypoints()
    State.AutoCineWaypoints={}; State.AutoCineIndex=1; Notif("Waypoints","Cleared",2)
end

local function StopAutoCine()
    State.AutoCineActive = false
    State._cineBarsLocked = false
    if State.AutoCineTween then pcall(function() State.AutoCineTween:Cancel() end); State.AutoCineTween=nil end
    if State._autoCineConn then pcall(function() State._autoCineConn:Disconnect() end); State._autoCineConn=nil end
    pcall(function()
        if Camera.CameraType==Enum.CameraType.Scriptable then
            Camera.CameraType = State._fcSavedCamType or Enum.CameraType.Custom
        end
    end)
    State.FreecamActive = false
    -- Animate bars out (if any were shown)
    SetCineBars(false, true, false)
    -- Restore the frame that was active before cine started
    if State._savedFrameMode and State._savedFrameMode ~= "None" then
        SetFrame(State._savedFrameMode, true)
        State._savedFrameMode = "None"
    end
    Notif("Auto Cine","Stopped",2)
end

local function GetEasing(name)
    return ({
        Sine=Enum.EasingStyle.Sine, Quad=Enum.EasingStyle.Quad,
        Cubic=Enum.EasingStyle.Cubic, Expo=Enum.EasingStyle.Exponential,
        Elastic=Enum.EasingStyle.Elastic, Bounce=Enum.EasingStyle.Bounce,
        Linear=Enum.EasingStyle.Linear,
    })[name] or Enum.EasingStyle.Sine
end

local function StartAutoCine()
    if #State.AutoCineWaypoints<2 then Notif("Auto Cine","Need 2+ waypoints",3); return end
    if State.AutoCineActive then StopAutoCine(); return end

    State.AutoCineActive=true; State.AutoCineIndex=1
    State._fcSavedCamType=Camera.CameraType; State._fcSavedFOV=Camera.FieldOfView
    pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end)
    State.FreecamActive=true

    -- Clear Frame mode: remove all bars + frame for a clean cinematic shot
    if State.AutoCineClearFrame then
        State._savedFrameMode = State.FrameMode
        SetCineBars(false, false, false)
        DestroyFrame()
        State.FrameMode = "None"
        Notif("Auto Cine","RUNNING - Clean frame mode",4)
    else
        SetCineBars(true, true, true)
        Notif("Auto Cine","RUNNING - "..#State.AutoCineWaypoints.." waypoints",4)
    end

    local function FlyToNext()
        if not State.AutoCineActive then return end
        local wps=State.AutoCineWaypoints
        local target=wps[State.AutoCineIndex]; if not target then StopAutoCine(); return end
        local dist=(Camera.CFrame.Position-target.Position).Magnitude
        local dur=math.max(1.5, dist/math.max(0.01,State.AutoCineSpeed*30))

        local obj=Instance.new("CFrameValue"); obj.Value=Camera.CFrame
        local tw=TweenService:Create(obj,
            TweenInfo.new(dur,GetEasing(State.AutoCineEasing),Enum.EasingDirection.InOut),
            {Value=target})
        State.AutoCineTween=tw

        if State._autoCineConn then pcall(function() State._autoCineConn:Disconnect() end) end
        State._autoCineConn=obj.Changed:Connect(function(v)
            if not State.AutoCineActive then return end
            pcall(function() Camera.CFrame=v end)
        end)

        tw:Play()
        tw.Completed:Connect(function(ps)
            if State._autoCineConn then pcall(function() State._autoCineConn:Disconnect() end); State._autoCineConn=nil end
            pcall(function() obj:Destroy() end)
            if not State.AutoCineActive then return end
            if ps~=Enum.PlaybackState.Completed then return end
            State.AutoCineIndex=State.AutoCineIndex+1
            if State.AutoCineIndex>#wps then
                if State.AutoCineLoop then State.AutoCineIndex=1; task.defer(FlyToNext)
                else StopAutoCine() end
            else task.defer(FlyToNext) end
        end)
    end

    FlyToNext()
end

--------------------------------------------------------------------------------
-- PRESET SYSTEM
--------------------------------------------------------------------------------
local Presets = {}

local function ApplyPresetTable(p)
    RemoveAllEffects()
    if p.quality then SetQuality(p.quality) end
    if p.dof then
        State.DOFEnabled=true; State.DOFFarIntensity=p.dof.far or 0
        State.DOFFocusDist=p.dof.focus or 30; State.DOFInFocusRadius=p.dof.radius or 5
        State.DOFNearIntensity=p.dof.near or 0; ApplyDOF()
    end
    if p.color then
        State.ColorEnabled=true; State.ColorContrast=p.color.contrast or 0
        State.ColorSaturation=p.color.saturation or 0; State.ColorBrightness=p.color.brightness or 0
        State.ColorTintR=p.color.tintR or 1; State.ColorTintG=p.color.tintG or 1; State.ColorTintB=p.color.tintB or 1
        ApplyCC()
    end
    if p.bloom then State.BloomEnabled=true; State.BloomIntensity=p.bloom.intensity or 0.5
        State.BloomSize=p.bloom.size or 24; State.BloomThreshold=p.bloom.threshold or 2; ApplyBloom() end
    if p.sunrays then State.SunRaysEnabled=true; State.SunRaysIntensity=p.sunrays.intensity or 0.2
        State.SunRaysSpread=p.sunrays.spread or 0.5; ApplySunRays() end
    if p.atmosphere then
        State.AtmoEnabled=true; State.AtmoDensity=p.atmosphere.density or 0.35
        State.AtmoOffset=p.atmosphere.offset or 0; State.AtmoHaze=p.atmosphere.haze or 0
        State.AtmoGlare=p.atmosphere.glare or 0
        State.AtmoColor=p.atmosphere.color or Color3.fromRGB(199,199,199)
        State.AtmoDecay=p.atmosphere.decay or Color3.fromRGB(106,112,125); ApplyAtmo()
    end
    if p.hdr then State.HDREnabled=true; State.ExposureComp=p.hdr.exposure or 0; ApplyHDR() end
    if p.lighting then BackupLighting()
        if p.lighting.brightness then Lighting.Brightness=p.lighting.brightness end
        if p.lighting.ambient then Lighting.Ambient=p.lighting.ambient end
        if p.lighting.outdoor then Lighting.OutdoorAmbient=p.lighting.outdoor end
        if p.lighting.time then Lighting.ClockTime=p.lighting.time end
    end
    if p.bars then State.CineBarsSize=p.bars; SetCineBars(true,true,false) end
    State.CurrentPreset=p.name or "Custom"
    Notif("Preset",(p.name or "Custom").." applied",3)
end

Presets["HD"] = {
    name="HD (Full HD)", quality="MAX",
    color={contrast=0.28, saturation=0.35, brightness=0.10, tintR=1.03, tintG=1, tintB=0.97},
    bloom={intensity=0.65, size=28, threshold=1.9},
    sunrays={intensity=0.32, spread=0.58},
    atmosphere={density=0.36, haze=1.8, glare=0.28,
        color=Color3.fromRGB(200,212,225), decay=Color3.fromRGB(100,112,130)},
    hdr={exposure=0.30},
    lighting={brightness=2.0, time=14,
        ambient=Color3.fromRGB(95,100,115), outdoor=Color3.fromRGB(155,165,180)},
    dof={far=0.25, focus=45, radius=15, near=0.08},
}
Presets["HDR"] = { name="HDR", quality="Ultra",
    color={contrast=0.25,saturation=0.35,brightness=0.12,tintR=1.02,tintG=1,tintB=0.98},
    bloom={intensity=0.55,size=28,threshold=1.8},sunrays={intensity=0.28,spread=0.55},
    atmosphere={density=0.38,haze=2,glare=0.35,color=Color3.fromRGB(195,208,228),decay=Color3.fromRGB(95,108,130)},
    hdr={exposure=0.35},lighting={brightness=1.8,time=13,ambient=Color3.fromRGB(90,95,110),outdoor=Color3.fromRGB(140,150,170)},
    dof={far=0.3,focus=40,radius=10,near=0.1},bars=0.07}
Presets["Cinematic"] = { name="Cinematic",quality="High",
    color={contrast=0.3,saturation=-0.08,brightness=0.02},
    bloom={intensity=0.6,size=28,threshold=2},sunrays={intensity=0.2,spread=0.5},
    atmosphere={density=0.36,haze=1.5,glare=0.2,color=Color3.fromRGB(190,200,215),decay=Color3.fromRGB(100,108,125)},
    dof={far=1,focus=20,radius=8,near=0.6},bars=0.08}
Presets["Night"] = { name="Night",quality="High",
    color={contrast=0.5,saturation=-0.28,brightness=-0.28,tintR=0.72,tintG=0.82,tintB=1.05},
    bloom={intensity=1.1,size=38,threshold=1.4},
    atmosphere={density=0.55,haze=3,color=Color3.fromRGB(60,70,100),decay=Color3.fromRGB(20,25,50)},
    hdr={exposure=-0.2},lighting={brightness=0.3,time=22,ambient=Color3.fromRGB(30,35,55),outdoor=Color3.fromRGB(20,25,45)},
    dof={far=0.8,focus=15,radius=5,near=0.4},bars=0.09}
Presets["Vintage"] = { name="Vintage",quality="Medium",
    color={contrast=0.22,saturation=-0.48,brightness=0.12,tintR=1.08,tintG=0.92,tintB=0.72},
    bloom={intensity=0.3,size=16,threshold=2.5},sunrays={intensity=0.4,spread=0.8},
    atmosphere={density=0.45,offset=0.1,haze=4,glare=0.3,color=Color3.fromRGB(210,190,160),decay=Color3.fromRGB(140,120,90)},
    lighting={brightness=1.1,time=15},dof={far=0.5,focus=25,radius=6,near=0.3},bars=0.10}
Presets["Bright"] = { name="Bright",quality="High",
    color={contrast=0.08,saturation=0.22,brightness=0.22},
    bloom={intensity=0.8,size=32,threshold=1.7},sunrays={intensity=0.35,spread=0.6},
    atmosphere={density=0.28,haze=0.5,glare=0.4,color=Color3.fromRGB(210,220,235),decay=Color3.fromRGB(180,190,200)},
    hdr={exposure=0.5},lighting={brightness=2.2,time=13},bars=0.06}
Presets["Sunset"] = { name="Sunset",quality="High",
    color={contrast=0.28,saturation=0.3,brightness=0.05,tintR=1.15,tintG=0.90,tintB=0.75},
    bloom={intensity=0.7,size=30,threshold=1.9},sunrays={intensity=0.45,spread=0.7},
    atmosphere={density=0.5,offset=0.15,haze=5,glare=0.55,color=Color3.fromRGB(255,140,60),decay=Color3.fromRGB(180,60,30)},
    hdr={exposure=0.25},lighting={brightness=1.5,time=17.5,ambient=Color3.fromRGB(180,100,50),outdoor=Color3.fromRGB(220,130,60)},
    dof={far=0.4,focus=35,radius=12,near=0.1},bars=0.08}
Presets["Portrait"] = { name="Portrait",quality="High",
    color={contrast=0.16,saturation=0.12,brightness=0.06},
    bloom={intensity=0.5,size=24,threshold=2.0},
    dof={far=0.85,focus=10,radius=4,near=0.65},
    atmosphere={density=0.3,haze=0.8,glare=0.1,color=Color3.fromRGB(205,208,220),decay=Color3.fromRGB(105,110,128)},
    hdr={exposure=0.15},lighting={brightness=1.5,time=14}}
Presets["Landscape"] = { name="Landscape",quality="Ultra",
    color={contrast=0.2,saturation=0.28,brightness=0.1,tintR=1,tintG=1.02,tintB=1.04},
    bloom={intensity=0.45,size=30,threshold=2.1},sunrays={intensity=0.32,spread=0.6},
    atmosphere={density=0.42,haze=3,glare=0.3,color=Color3.fromRGB(185,205,230),decay=Color3.fromRGB(90,110,145)},
    hdr={exposure=0.28},lighting={brightness=1.9,time=13},bars=0.06}

local function ApplyPreset(name)
    if name=="Reset" then
        RemoveAllEffects(); RestoreLighting(); SetCineBars(false,true,false); DestroyFrame()
        pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end)
        State.CurrentPreset="None"; Notif("Preset","Reset",2); return
    end
    local p=Presets[name]; if p then ApplyPresetTable(p) end
end

--------------------------------------------------------------------------------
-- GAMEPLAY HD
--------------------------------------------------------------------------------
local function SetGameplayHD(enable)
    State.GameplayHD=enable
    if enable then
        BackupLighting()
        SetQuality(State.GameplayQuality or "MAX")
        State.ColorEnabled=true
        State.ColorContrast=0.22; State.ColorSaturation=0.28
        State.ColorBrightness=0.08; State.ColorTintR=1.02; State.ColorTintG=1; State.ColorTintB=0.98
        ApplyCC()
        State.BloomEnabled=true; State.BloomIntensity=0.45; State.BloomSize=26; State.BloomThreshold=2.0
        ApplyBloom()
        State.SunRaysEnabled=true; State.SunRaysIntensity=0.22; State.SunRaysSpread=0.5
        ApplySunRays()
        State.AtmoEnabled=true; State.AtmoDensity=0.35; State.AtmoHaze=1.6; State.AtmoGlare=0.25
        State.AtmoColor=Color3.fromRGB(200,212,225); State.AtmoDecay=Color3.fromRGB(100,112,130)
        ApplyAtmo()
        State.HDREnabled=true; State.ExposureComp=0.28
        ApplyHDR()
        pcall(function()
            Lighting.GlobalShadows=true
            Lighting.EnvironmentDiffuseScale=1
            Lighting.EnvironmentSpecularScale=1
            Lighting.ShadowSoftness=0.5
        end)
        if not State.FreecamActive then pcall(function() Camera.FieldOfView=State.GameplayFOV end) end
        Notif("Gameplay HD","MAX quality + HDR + Full grade",5)
    else
        RemoveAllEffects(); RestoreLighting()
        pcall(function() settings().Rendering.QualityLevel=Enum.QualityLevel.Automatic end)
        if not State.FreecamActive then pcall(function() Camera.FieldOfView=State._fcSavedFOV>0 and State._fcSavedFOV or 70 end) end
        Notif("Gameplay HD","OFF",3)
    end
end

--------------------------------------------------------------------------------
-- SCREENSHOT
--------------------------------------------------------------------------------
local function TakeScreenshot()
    Notif("Screenshot","Hiding UI 2s - press screenshot key!",4)
    task.spawn(function()
        local w=_G[TOOL_KEY] and _G[TOOL_KEY].window
        pcall(function() if w then w:SetVisible(false) end end); task.wait(2)
        pcall(function() if w then w:SetVisible(true) end end)
    end)
end

--------------------------------------------------------------------------------
-- FLOATING LOGO
--------------------------------------------------------------------------------
local FloatingLogo = {}
local function DestroyLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local gp = GuiParent()
    if gp then
        for _, c in ipairs(gp:GetChildren()) do
            if c.Name == "X0_Tools_Logo" then pcall(function() c:Destroy() end) end
        end
    end
    State.LogoGui = nil; State.LogoImage = nil
end

function FloatingLogo.Build()
    DestroyLogo()
    local gp = GuiParent(); if not gp then return false end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Tools_Logo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 999999; sg.Enabled = true
    local ok = pcall(function() sg.Parent = gp end)
    if not ok then pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end

    local size = State.LogoSize
    local img = Instance.new("ImageButton")
    img.Name = "Logo"
    img.Size = UDim2.new(0, size, 0, size)
    img.Position = UDim2.new(0, 20, 0, 100)
    img.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    img.BackgroundTransparency = 0.4
    img.BorderSizePixel = 0
    img.Image = TOOL.LogoId
    img.ImageTransparency = State.LogoTransparency
    img.ScaleType = Enum.ScaleType.Fit
    img.AutoButtonColor = false
    img.Active = true; img.Selectable = true; img.Visible = true
    img.ZIndex = 100; img.Parent = sg
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 10)

    local dragging, dragStart, startPos, dragMoved = false, Vector2.zero, UDim2.new(), false
    img.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = img.Position; dragMoved = false
        end
    end)
    img.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            if d.Magnitude > 4 then dragMoved = true end
            img.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    img.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    img.MouseButton1Click:Connect(function()
        if dragMoved then return end
        pcall(function()
            local h = _G[TOOL_KEY]
            if h and h.window and h.window.Minimize then h.window:Minimize() end
        end)
    end)

    State.LogoGui = sg; State.LogoImage = img
    return true
end

function FloatingLogo.SetVisible(v)
    State.FloatingLogo = v
    if v then FloatingLogo.Build() else DestroyLogo() end
end
function FloatingLogo.SetSize(sz)
    State.LogoSize = sz
    if State.LogoImage then State.LogoImage.Size = UDim2.new(0, sz, 0, sz) end
end
function FloatingLogo.SetTransparency(a)
    State.LogoTransparency = a
    if State.LogoImage then State.LogoImage.ImageTransparency = a end
end
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({TOOL.LogoId}) end) end)

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------
local function CleanupAll()
    if State.FreecamActive then pcall(StopFreecam) end
    if State.AutoCineActive then pcall(StopAutoCine) end
    pcall(function() SetPhotoMode(false) end)
    pcall(function() SetCameraShake(false) end)
    pcall(function() SetTimeAnim(false) end)
    pcall(function() SetGameplayHD(false) end)
    pcall(function() SetCineBars(false, false, false) end)
    pcall(function() SetGridLines(false) end)
    pcall(function() DestroyFrame() end)
    pcall(function() SetAutoFocus(false) end)
    pcall(function() DestroyLogo() end)
    if _frameResizeConn then pcall(function() _frameResizeConn:Disconnect() end) end
    pcall(function() ApplyPreset("Reset") end)
    CM:Cleanup()
end

--------------------------------------------------------------------------------
-- WINDOW + TABS
--------------------------------------------------------------------------------
local Window = Fluent:CreateWindow({
    Title=TOOL.Name, SubTitle="Cinematic Suite v"..TOOL.Version.." | "..TOOL.Author,
    TabWidth=150, Size=UDim2.fromOffset(720, 550),
    Acrylic=true, Theme="Dark", MinimizeKey=Enum.KeyCode.F6,
})

_G[TOOL_KEY] = { version = TOOL.Version, window = Window, destroy = CleanupAll }

local Tabs = {
    Freecam  = Window:AddTab({Title="Freecam",   Icon="camera"}),
    Frame    = Window:AddTab({Title="Frame",      Icon="crop"}),
    Photo    = Window:AddTab({Title="Photo",      Icon="image"}),
    Presets  = Window:AddTab({Title="Presets",    Icon="layers"}),
    Effects  = Window:AddTab({Title="Effects",    Icon="wand"}),
    AutoCine = Window:AddTab({Title="Auto Cine",  Icon="play-circle"}),
    GameHD   = Window:AddTab({Title="Gameplay HD",Icon="monitor"}),
    Settings = Window:AddTab({Title="Settings",   Icon="settings"}),
}

--------------------------------------------------------------------------------
-- FREECAM TAB
--------------------------------------------------------------------------------
do local T=Tabs.Freecam
    T:AddButton({Title="Toggle Freecam [F7]",Description="WASD | Ctrl=fast | Z=slow | Q/E=roll",Callback=StartFreecam})
    T:AddSlider("FC_S",{Title="Speed",Default=20,Min=1,Max=300,Rounding=0}):OnChanged(function(v) State.FreecamSpeed=v end)
    T:AddSlider("FC_F",{Title="FOV",Default=70,Min=10,Max=140,Rounding=0}):OnChanged(function(v) State.FreecamFOV=v; if State.FreecamActive then pcall(function() Camera.FieldOfView=v end) end end)
    T:AddSlider("FC_Se",{Title="Sensitivity",Default=40,Min=1,Max=200,Rounding=0}):OnChanged(function(v) State.FreecamSensitivity=v*0.01 end)
    T:AddSlider("FC_Sm",{Title="Smoothing",Default=15,Min=0,Max=99,Rounding=0}):OnChanged(function(v) State.FreecamSmoothing=v*0.01 end)
    T:AddToggle("FC_R",{Title="Roll Q/E",Default=false}):OnChanged(function(v) State.FreecamRollEnabled=v end)
    T:AddButton({Title="FOV Zoom In",Callback=function() AnimateFOV(40,1.5) end})
    T:AddButton({Title="FOV Zoom Out",Callback=function() AnimateFOV(State.FreecamFOV,1.5) end})
    T:AddButton({Title="Reset Camera",Callback=function() if State.FreecamActive then StopFreecam() end; pcall(function() Camera.CameraType=Enum.CameraType.Custom end) end})
    T:AddToggle("FC_Sh",{Title="Shake",Default=false}):OnChanged(function(v) SetCameraShake(v) end)
    T:AddSlider("FC_SI",{Title="Shake Intensity",Default=50,Min=1,Max=200,Rounding=0}):OnChanged(function(v) State.ShakeIntensity=v*0.01 end)
    T:AddSlider("FC_SS",{Title="Shake Speed",Default=10,Min=1,Max=60,Rounding=0}):OnChanged(function(v) State.ShakeSpeed=v end)
    T:AddDropdown("FC_ST",{Title="Shake Type",Values={"Sine","Perlin","Trauma"},Default="Sine"}):OnChanged(function(v) State.ShakeType=v end)
end

--------------------------------------------------------------------------------
-- FRAME TAB
--------------------------------------------------------------------------------
do local T=Tabs.Frame
    T:AddButton({Title="About Frame Crops",Description="Black bars mask viewport to target ratio.",
        Callback=function() Notif("Frame","Desktop crop system",5) end})
    local fk={"None","Portrait","Landscape_16_9","Square","Widescreen_21_9","Instagram_4_5","Cinema_235","Letterbox_185"}
    local fl={None="None",Portrait="9:16 Portrait",Landscape_16_9="16:9 Landscape",Square="1:1 Square",
        Widescreen_21_9="21:9 Widescreen",Instagram_4_5="4:5 Instagram",Cinema_235="2.35:1 Cinema",Letterbox_185="1.85:1 Letterbox"}
    local dn={}; for _,k in ipairs(fk) do table.insert(dn,fl[k]) end
    local lk={}; for _,k in ipairs(fk) do lk[fl[k]]=k end
    T:AddDropdown("FR_S",{Title="Aspect Ratio",Values=dn,Default="None"}):OnChanged(function(v) SetFrame(lk[v] or "None",true) end)
    T:AddSlider("FR_O",{Title="Bar Opacity",Default=100,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.FrameOpacity=v*0.01; if State.FrameMode~="None" then BuildFrame(State.FrameMode,false) end end)
    T:AddButton({Title="Remove Frame",Callback=function() DestroyFrame(); State.FrameMode="None"; Notif("Frame","Removed",2) end})
    T:AddButton({Title="Portrait Mode (9:16)",Callback=function()
        ApplyPreset("Portrait"); SetFrame("Portrait",true)
        if not State.FreecamActive then StartFreecam() end
        State.FreecamFOV=72; pcall(function() Camera.FieldOfView=72 end)
    end})
    T:AddButton({Title="Landscape Mode (16:9)",Callback=function()
        ApplyPreset("Landscape"); SetFrame("Landscape_16_9",true)
        if not State.FreecamActive then StartFreecam() end
        State.FreecamFOV=78; pcall(function() Camera.FieldOfView=78 end)
    end})
    T:AddButton({Title="Cinema Mode (2.35:1)",Callback=function()
        ApplyPreset("Cinematic"); SetFrame("Cinema_235",true)
        if not State.FreecamActive then StartFreecam() end
        State.FreecamFOV=80; pcall(function() Camera.FieldOfView=80 end)
    end})
    T:AddButton({Title="Square Mode (1:1)",Callback=function()
        ApplyPreset("HD"); SetFrame("Square",true)
        if not State.FreecamActive then StartFreecam() end
        State.FreecamFOV=70; pcall(function() Camera.FieldOfView=70 end)
    end})
end

--------------------------------------------------------------------------------
-- PHOTO TAB
--------------------------------------------------------------------------------
do local T=Tabs.Photo
    T:AddToggle("PM",{Title="Photo Mode [F10]",Default=false}):OnChanged(function(v) SetPhotoMode(v) end)
    T:AddToggle("PM_UI",{Title="Hide UI",Default=true}):OnChanged(function(v) State.PhotoHideUI=v end)
    T:AddToggle("PM_CH",{Title="Hide Character",Default=false}):OnChanged(function(v)
        State.PhotoHideChar=v; local c=Char(); if c then for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") or p:IsA("Decal") then pcall(function() p.LocalTransparencyModifier=v and 1 or 0 end) end end end
    end)
    T:AddToggle("PM_GR",{Title="Grid Lines",Default=false}):OnChanged(function(v) State.PhotoGridLines=v; SetGridLines(v) end)
    T:AddToggle("PM_CB",{Title="Cinematic Bars",Default=false}):OnChanged(function(v) SetCineBars(v,true,false) end)
    T:AddToggle("PM_CA",{Title="Animate Bars",Default=true}):OnChanged(function(v) State.CineBarsAnim=v end)
    T:AddSlider("PM_BS",{Title="Bar Size %",Default=8,Min=2,Max=25,Rounding=0}):OnChanged(function(v) State.CineBarsSize=v*0.01; if State.CineBarsActive then SetCineBars(true,false,State._cineBarsLocked) end end)
    T:AddButton({Title="Screenshot (hides UI 2s)",Callback=TakeScreenshot})
end

--------------------------------------------------------------------------------
-- PRESETS TAB
--------------------------------------------------------------------------------
do local T=Tabs.Presets
    T:AddParagraph({Title="FULL HD Preset",Content="The flagship preset: MAX quality + HDR + rich atmosphere + vivid color grading.\nBest overall visuals available."})
    T:AddButton({Title="APPLY FULL HD",Callback=function() ApplyPreset("HD") end})

    local pN={"HD","HDR","Cinematic","Night","Vintage","Bright","Sunset","Portrait","Landscape","Reset"}
    T:AddDropdown("PR_S",{Title="Other Presets",Values=pN,Default="HD"})
    T:AddButton({Title="Apply Selected",Callback=function()
        local v=(Fluent.Options["PR_S"] and Fluent.Options["PR_S"].Value) or "HD"; ApplyPreset(v)
    end})
    for _,n in ipairs(pN) do local nm=n
        T:AddButton({Title="> "..nm,Callback=function() ApplyPreset(nm) end}) end
    T:AddButton({Title="Cinematic Full Enter",Callback=function() ApplyPreset("Cinematic"); if not State.FreecamActive then StartFreecam() end end})
    T:AddButton({Title="Reset Everything",Callback=function() CleanupAll(); Notif("Reset","All OFF",3) end})
end

--------------------------------------------------------------------------------
-- EFFECTS TAB
--------------------------------------------------------------------------------
do local T=Tabs.Effects
    T:AddToggle("E_DOF",{Title="Depth of Field",Default=false}):OnChanged(function(v) State.DOFEnabled=v; ApplyDOF() end)
    T:AddToggle("E_AF",{Title="Auto Focus",Default=false}):OnChanged(function(v) State.DOFAutoFocus=v; SetAutoFocus(v) end)
    T:AddSlider("E_FD",{Title="Focus Dist",Default=30,Min=1,Max=300,Rounding=0}):OnChanged(function(v) State.DOFFocusDist=v; ApplyDOF() end)
    T:AddSlider("E_FR",{Title="Focus Radius",Default=5,Min=0,Max=50,Rounding=1}):OnChanged(function(v) State.DOFInFocusRadius=v; ApplyDOF() end)
    T:AddSlider("E_FF",{Title="Far Blur",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.DOFFarIntensity=v*0.01; ApplyDOF() end)
    T:AddSlider("E_FN",{Title="Near Blur",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.DOFNearIntensity=v*0.01; ApplyDOF() end)
    T:AddToggle("E_BL",{Title="Bloom",Default=false}):OnChanged(function(v) State.BloomEnabled=v; ApplyBloom() end)
    T:AddSlider("E_BI",{Title="Bloom Int",Default=50,Min=0,Max=300,Rounding=0}):OnChanged(function(v) State.BloomIntensity=v*0.01; ApplyBloom() end)
    T:AddSlider("E_BS",{Title="Bloom Size",Default=24,Min=0,Max=56,Rounding=0}):OnChanged(function(v) State.BloomSize=v; ApplyBloom() end)
    T:AddSlider("E_BT",{Title="Bloom Thresh",Default=200,Min=0,Max=400,Rounding=0}):OnChanged(function(v) State.BloomThreshold=v*0.01; ApplyBloom() end)
    T:AddToggle("E_CC",{Title="Color Correction",Default=false}):OnChanged(function(v) State.ColorEnabled=v; ApplyCC() end)
    T:AddSlider("E_CB",{Title="Brightness",Default=0,Min=-100,Max=100,Rounding=0}):OnChanged(function(v) State.ColorBrightness=v*0.01; ApplyCC() end)
    T:AddSlider("E_CO",{Title="Contrast",Default=0,Min=-100,Max=100,Rounding=0}):OnChanged(function(v) State.ColorContrast=v*0.01; ApplyCC() end)
    T:AddSlider("E_CS",{Title="Saturation",Default=0,Min=-100,Max=100,Rounding=0}):OnChanged(function(v) State.ColorSaturation=v*0.01; ApplyCC() end)
    T:AddToggle("E_SR",{Title="Sun Rays",Default=false}):OnChanged(function(v) State.SunRaysEnabled=v; ApplySunRays() end)
    T:AddSlider("E_SI",{Title="SunRay Int",Default=25,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.SunRaysIntensity=v*0.01; ApplySunRays() end)
    T:AddSlider("E_SS",{Title="SunRay Spread",Default=50,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.SunRaysSpread=v*0.01; ApplySunRays() end)
    T:AddToggle("E_AT",{Title="Atmosphere",Default=false}):OnChanged(function(v) State.AtmoEnabled=v; ApplyAtmo() end)
    T:AddSlider("E_AD",{Title="Density",Default=40,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.AtmoDensity=v*0.01; ApplyAtmo() end)
    T:AddSlider("E_AH",{Title="Haze",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.AtmoHaze=v*0.1; ApplyAtmo() end)
    T:AddSlider("E_AG",{Title="Glare",Default=0,Min=0,Max=100,Rounding=0}):OnChanged(function(v) State.AtmoGlare=v*0.01; ApplyAtmo() end)
    T:AddToggle("E_HD",{Title="HDR Exposure",Default=false}):OnChanged(function(v) State.HDREnabled=v; ApplyHDR() end)
    T:AddSlider("E_HE",{Title="Exposure",Default=0,Min=-100,Max=100,Rounding=0}):OnChanged(function(v) State.ExposureComp=v*0.01; ApplyHDR() end)
    T:AddSlider("E_TD",{Title="Time of Day",Default=14,Min=0,Max=24,Rounding=1}):OnChanged(function(v) Lighting.ClockTime=v end)
    T:AddToggle("E_TA",{Title="Animate Time",Default=false}):OnChanged(function(v) SetTimeAnim(v) end)
    T:AddSlider("E_TS",{Title="Time Speed",Default=1,Min=1,Max=100,Rounding=0}):OnChanged(function(v) State.TimeAnimSpeed=v end)
    T:AddButton({Title="Remove All Effects",Callback=function() ApplyPreset("Reset") end})
end

--------------------------------------------------------------------------------
-- AUTO CINEMATIC TAB
--------------------------------------------------------------------------------
do local T=Tabs.AutoCine
    T:AddButton({Title="How to use",Description="1. Move camera to a position\n2. Save Waypoint (F11)\n3. Repeat 2+ times\n4. Start - clean fullscreen shot (no bars)\n5. Stop - restores previous frame",
        Callback=function() Notif("Auto Cine","Save waypoints then Start",5) end})
    T:AddButton({Title="Save Waypoint [F11]",Callback=SaveWaypoint})
    T:AddButton({Title="Clear Waypoints",Callback=ClearWaypoints})
    T:AddButton({Title="Count",Callback=function() Notif("WP",#State.AutoCineWaypoints.." saved",3) end})
    T:AddSlider("AC_S",{Title="Travel Speed",Default=30,Min=1,Max=200,Rounding=0}):OnChanged(function(v) State.AutoCineSpeed=v*0.01 end)
    T:AddToggle("AC_L",{Title="Loop",Default=true}):OnChanged(function(v) State.AutoCineLoop=v end)
    T:AddToggle("AC_Clear",{Title="Clear Frame (no bars during cine)",Default=true}):OnChanged(function(v) State.AutoCineClearFrame=v end)
    T:AddDropdown("AC_E",{Title="Easing",Values={"Sine","Quad","Cubic","Expo","Elastic","Bounce","Linear"},Default="Sine"}):OnChanged(function(v) State.AutoCineEasing=v end)
    T:AddButton({Title="Start / Stop",Callback=function() if State.AutoCineActive then StopAutoCine() else StartAutoCine() end end})
    T:AddButton({Title="Force Stop",Callback=StopAutoCine})
    T:AddButton({Title="Quick Orbit Demo (8 pts)",Callback=function()
        local hrp=HRP(); if not hrp then Notif("Demo","No char",2); return end
        ClearWaypoints(); local b=hrp.CFrame; local r=25
        for i=0,7 do local a=(i/8)*math.pi*2
            table.insert(State.AutoCineWaypoints,CFrame.new(b.Position+Vector3.new(math.cos(a)*r,6+i*0.5,math.sin(a)*r),b.Position))
        end; Notif("Demo","8 points added",3)
    end})
    T:AddButton({Title="Apply Cinematic Preset",Callback=function() ApplyPreset("Cinematic") end})
end

--------------------------------------------------------------------------------
-- GAMEPLAY HD TAB
--------------------------------------------------------------------------------
do local T=Tabs.GameHD
    T:AddButton({Title="About Gameplay HD",Description="MAX quality + Full HD grade while playing normally.\nCamera stays as Follow. No freecam needed.",
        Callback=function() Notif("HD","Play normally with FULL HD visuals",5) end})
    T:AddToggle("GH_On",{Title="Enable Gameplay HD",Default=false}):OnChanged(function(v) SetGameplayHD(v) end)
    T:AddDropdown("GH_Q",{Title="Quality",Values={"MAX","Ultra","High","Medium","Low","Potato"},Default="MAX"}):OnChanged(function(v) State.GameplayQuality=v; if State.GameplayHD then SetQuality(v) end end)
    T:AddSlider("GH_F",{Title="FOV",Default=75,Min=50,Max=110,Rounding=0}):OnChanged(function(v) State.GameplayFOV=v; if not State.FreecamActive then pcall(function() Camera.FieldOfView=v end) end end)
    T:AddToggle("GH_D",{Title="Subtle DOF",Default=false}):OnChanged(function(v)
        State.DOFEnabled=v; if v then State.DOFFarIntensity=0.15; State.DOFFocusDist=35; State.DOFInFocusRadius=12; State.DOFNearIntensity=0.05 end; ApplyDOF()
    end)
    T:AddToggle("GH_AF",{Title="Auto Focus",Default=false}):OnChanged(function(v) State.DOFAutoFocus=v; SetAutoFocus(v) end)
    T:AddToggle("GH_BL",{Title="Bloom",Default=true}):OnChanged(function(v) State.BloomEnabled=v; ApplyBloom() end)
    T:AddToggle("GH_SR",{Title="Sun Rays",Default=true}):OnChanged(function(v) State.SunRaysEnabled=v; ApplySunRays() end)
    T:AddToggle("GH_AT",{Title="Atmosphere",Default=true}):OnChanged(function(v) State.AtmoEnabled=v; ApplyAtmo() end)
    T:AddToggle("GH_CC",{Title="Color Grade",Default=true}):OnChanged(function(v) State.ColorEnabled=v; ApplyCC() end)
    T:AddToggle("GH_HD",{Title="HDR",Default=true}):OnChanged(function(v) State.HDREnabled=v; ApplyHDR() end)
    T:AddButton({Title="Apply FULL HD Preset",Callback=function() ApplyPreset("HD") end})
    T:AddButton({Title="Apply HDR Preset",Callback=function() ApplyPreset("HDR") end})
    T:AddButton({Title="Reset Default",Callback=function() SetGameplayHD(false); ApplyPreset("Reset") end})
end

--------------------------------------------------------------------------------
-- SETTINGS TAB
--------------------------------------------------------------------------------
do local T=Tabs.Settings
    T:AddParagraph({Title="Floating Logo",Content="Draggable logo. Click to toggle hub visibility."})
    T:AddToggle("FloatLogo",{Title="Floating Logo",Default=true}):OnChanged(function(v) FloatingLogo.SetVisible(v) end)
    T:AddSlider("LogoSize",{Title="Logo Size",Default=60,Min=30,Max=140,Rounding=0}):OnChanged(function(v) FloatingLogo.SetSize(v) end)
    T:AddSlider("LogoAlpha",{Title="Logo Transparency %",Default=10,Min=0,Max=90,Rounding=0}):OnChanged(function(v) FloatingLogo.SetTransparency(v/100) end)
    T:AddButton({Title="Rebuild Logo",Callback=function() State.FloatingLogo=true; FloatingLogo.Build(); Notif("Logo","Rebuilt",2) end})

    T:AddButton({Title="Copy Discord",Callback=function()
        if setclipboard then setclipboard(TOOL.Discord); Notif("Discord","Copied!",3)
        else Notif("Discord",TOOL.Discord,6) end
    end})
    T:AddButton({Title="Unload All",Description="Stop everything and close hub",Callback=function()
        CleanupAll(); _G[TOOL_KEY]=nil; pcall(function() Fluent:Destroy() end)
    end})

    if SaveManager and InterfaceManager then
        local ok=pcall(function()
            SaveManager:SetLibrary(Fluent); InterfaceManager:SetLibrary(Fluent)
            SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({})
            InterfaceManager:SetFolder("X0DEC04T_Tools"); SaveManager:SetFolder("X0DEC04T_Tools/configs")
        end)
        if ok then
            pcall(function() InterfaceManager:BuildInterfaceSection(T) end)
            pcall(function() SaveManager:BuildConfigSection(T) end)
        end
    end
end

--------------------------------------------------------------------------------
-- KEYBINDS
--------------------------------------------------------------------------------
local KB={}
CM:Add(UserInputService.InputBegan,function(inp,gpe)
    if gpe or IsTyping() then return end
    local cb=KB[inp.KeyCode]; if cb then pcall(cb) end
end)
KB[Enum.KeyCode.F7]=function() StartFreecam() end
KB[Enum.KeyCode.F10]=function() SetPhotoMode(not State.PhotoModeActive) end
KB[Enum.KeyCode.F11]=function() SaveWaypoint() end
KB[Enum.KeyCode.F12]=function() TakeScreenshot() end

--------------------------------------------------------------------------------
-- BUILD LOGO ON STARTUP
--------------------------------------------------------------------------------
task.spawn(function()
    task.wait(0.5)
    if State.FloatingLogo then
        local ok = FloatingLogo.Build()
        if not ok then for i = 1, 3 do task.wait(1); if FloatingLogo.Build() then break end end end
    end
    while task.wait(5) do
        if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then
            FloatingLogo.Build()
        end
    end
end)

Window:SelectTab(1)
Notif(TOOL.Name,"v"..TOOL.Version.." | Clean Cine | Wand Icon | FULL HD",8)
Log("v2.4.1 fully loaded")
