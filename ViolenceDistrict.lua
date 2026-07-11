--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.3.1 - Violence District
-- FIXED: Vaults ESP (was called Windows before)
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

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_v031_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _logStart = os.clock()
local function Log(msg) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_logStart, tostring(msg))) end
local function Err(msg,d) warn(string.format("[X0DEC04T][+%.2fs] ERROR: %s | %s", os.clock()-_logStart, tostring(msg), tostring(d or ""))) end

Log("Script starting - v0.3.1")

local WindUI = nil
local ok, result = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if ok and result then WindUI = result; Log("Wind UI loaded")
else Err("Wind UI failed", tostring(result)); return end

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.3.1",
    Author  = "voixera",
}

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

local KNOWN_KILLERS = {
    ["stalker"]=true, ["killer"]=true, ["hidden"]=true, ["abysswalker"]=true,
    ["veil"]=true, ["slasher"]=true, ["masked"]=true, ["cure"]=true, ["jason"]=true,
}

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

local function GetRemote(...)
    if not Remotes then return nil end
    local current = Remotes
    for _, name in ipairs({...}) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local R = {
    Gen = {
        SkillCheck       = GetRemote("Generator", "SkillCheckEvent"),
        SkillCheckResult = GetRemote("Generator", "SkillCheckResultEvent"),
        SkillCheckFail   = GetRemote("Generator", "SkillCheckFailEvent"),
        GenDone          = GetRemote("Generator", "GenDone"),
        AllGenDone       = GetRemote("Generator", "allgendone"),
        RepairEvent      = GetRemote("Generator", "RepairEvent"),
    },
    Heal = {
        SkillCheck       = GetRemote("Healing", "SkillCheckEvent"),
        SkillCheckResult = GetRemote("Healing", "SkillCheckResultEvent"),
        SkillCheckFail   = GetRemote("Healing", "SkillCheckFailEvent"),
    },
    Chase = { Music = GetRemote("Chase", "ChaseMusicEvent") },
    Attack = { Basic = GetRemote("Attacks", "BasicAttack"), Lunge = GetRemote("Attacks", "Lunge") },
    Carry = {
        Hook = GetRemote("Carry", "HookEvent"),
        UnHook = GetRemote("Carry", "UnHookEvent"),
        HookPhase = GetRemote("Carry", "HookPhase"),
    },
    Game = {
        Start = GetRemote("Game", "Start"),
        KillerMorph = GetRemote("Game", "KillerMorph"),
        RoundEnd = GetRemote("Game", "RoundEnd"),
        OneLeft = GetRemote("Game", "Oneleft"),
        Death = GetRemote("Game", "death"),
    },
    KPerk = { KingScourgeStart = GetRemote("KillerPerks", "kingscourge", "KingScourgeStart") },
    Mech = { GotKnocked = GetRemote("Mechanics", "gotknocked") },
    Msg = { Announce = GetRemote("Messages", "AnnounceMessage") },
    Exit = { Gate = GetRemote("Exit", "gate") },
    Items = { ParryDagger = GetRemote("Items", "Parrying Dagger", "parry") },
}

Log("Remotes mapped")

local WS = {
    Map        = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones     = Workspace:FindFirstChild("Clones"),
    FakeChars  = Workspace:FindFirstChild("FakeCharacters"),
    Weapons    = Workspace:FindFirstChild("Weapons"),
    Pallets    = nil,
    Vaults     = nil,
}

local function DeepFind(name)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Folder") and v.Name:lower() == name:lower() then return v end
    end
    return nil
end

if WS.Map then
    WS.Generators = WS.Map:FindFirstChild("Generators")
    WS.Pallets    = WS.Map:FindFirstChild("Pallets") or DeepFind("Pallets")
    WS.Vaults     = WS.Map:FindFirstChild("Vaults") or DeepFind("Vaults")
else
    WS.Pallets = DeepFind("Pallets")
    WS.Vaults  = DeepFind("Vaults")
end

Log("Pallets: " .. (WS.Pallets and "Found @" .. WS.Pallets:GetFullName() or "NOT FOUND"))
Log("Vaults: " .. (WS.Vaults and "Found @" .. WS.Vaults:GetFullName() or "NOT FOUND"))
Log("Generators: " .. (WS.Generators and "Found" or "NOT FOUND"))

local State = {
    ChaseAlert=true, AttackAlert=true, LungeAlert=true, HookAlert=true,
    HookPhaseAlert=true, UnhookAlert=true, KnockedAlert=true,
    SkillCheckNotify=true, HealSkillNotify=true, GenDoneNotify=true,
    AllGensNotify=true, OneLeftNotify=true, DeathNotify=true,
    KingScourgeAlert=true, GateAlert=true, AnnounceAlert=true,

    ESP_Generators=false, ESP_Killer=false, ESP_Survivors=false,
    ESP_Items=false, ESP_Weapons=false, ESP_Clones=false,
    ESP_Pallets=false, ESP_Vaults=false,
    ESP_MaxDistance=500, ESP_ShowDistance=true, ESP_ShowName=true,

    Color_Killer    = Color3.fromRGB(255,40,40),
    Color_Survivor  = Color3.fromRGB(60,120,255),
    Color_Generator = Color3.fromRGB(255,200,60),
    Color_Item      = Color3.fromRGB(120,255,120),
    Color_Weapon    = Color3.fromRGB(255,120,220),
    Color_Clone     = Color3.fromRGB(180,180,180),
    Color_Pallet    = Color3.fromRGB(255,165,0),
    Color_Vault     = Color3.fromRGB(0,255,200),

    WalkSpeed=16, JumpPower=50, NoClip=false, InfJump=false,
    FullBright=false, NoFog=false, NoShadows=false, ClearWeather=false,
    LowGraphics=false, FOV=70, ClockTime=14,
    RemoveBlur=false, RemoveCC=false, Freecam=false, HideName=false,
    NoSound=false, MuteBGMusic=false, NoParticles=false,
    AutoRejoin=false, AntiAFK=true,

    Invisible=false, InvisibleHotkey=Enum.KeyCode.X,
    SurvSpeedBoost=false, SurvSpeedValue=24,
    AutoParry=false, ParryRange=20, ShowParryRing=false, ParryRingColor="Red",
    NoFallDamage=false, FleeKiller=false, FleeDistance=40,
    GodMode=false, AutoGenRush=false,
    AutoSkillcheck=false, SkillcheckMode="Legit", ShowGenProgress=false,

    IsKiller=false, MatchActive=false,
    ESPCache={}, LightBackup={}, MutedSounds={},
    NoClipConn=nil, InfJumpConn=nil, FreecamConn=nil,
    NoFallConn=nil, FleeConn=nil, GodModeConn=nil,
    AutoParryConn=nil, AutoSkillConn=nil,
    GenProgressGuis={}, ParryRing=nil,
    AwarenessReady=false,
}

local Role = {}
function Role.IsKiller(char)
    if not char then return false end
    if char:GetAttribute("Killer")==true or char:GetAttribute("IsKiller")==true then return true end
    if char:GetAttribute("Role")=="Killer" then return true end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k,1,true) then return true end
    end
    local plr = Players:GetPlayerFromCharacter(char)
    if plr and plr:GetAttribute("AllowKiller") == true then return true end
    return false
end
function Role.KillerName(char)
    if not char then return "Killer" end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k,1,true) then return k:gsub("^%l",string.upper) end
    end
    return char.Name
end
function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones and char:IsDescendantOf(WS.Clones) then return true end
    return false
end

local function Notify(t,c,d)
    pcall(function()
        WindUI:Notify({ Title=tostring(t or ""), Content=tostring(c or ""), Duration=tonumber(d) or 4 })
    end)
end

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local ESP = {}
function ESP.Clear(obj)
    local c = State.ESPCache[obj]; if not c then return end
    for _, inst in pairs(c) do
        if typeof(inst)=="Instance" and inst.Parent then pcall(function() inst:Destroy() end) end
    end
    State.ESPCache[obj] = nil
end
function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Clear(obj) end
    State.ESPCache = {}
end

local function MakeBB(hrp, label, color)
    local bb = Instance.new("BillboardGui")
    bb.Adornee = hrp
    bb.Size = UDim2.new(0,200,0,50)
    bb.StudsOffset = Vector3.new(0,3.5,0)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = State.ESP_MaxDistance
    bb.Parent = GuiParent()
    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1,0,0.6,0)
    nl.BackgroundTransparency = 1
    nl.Text = tostring(label or "")
    nl.TextColor3 = color
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = 14
    nl.Visible = State.ESP_ShowName
    local dl = Instance.new("TextLabel", bb)
    dl.Size = UDim2.new(1,0,0.4,0)
    dl.Position = UDim2.new(0,0,0.6,0)
    dl.BackgroundTransparency = 1
    dl.Text = "0m"
    dl.TextColor3 = Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.Gotham
    dl.TextSize = 12
    dl.Visible = State.ESP_ShowDistance
    return bb, nl, dl
end

function ESP.AddChar(char, label, color)
    if State.ESPCache[char] then ESP.Clear(char) end
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = char
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = GuiParent()
    local bb,nl,dl = MakeBB(hrp,label,color)
    State.ESPCache[char] = {hl=hl,bb=bb,nl=nl,dl=dl,hrp=hrp}
end

function ESP.AddObj(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end
    local part = model
    if model:IsA("Model") then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end
    local hl = Instance.new("Highlight")
    hl.Adornee = model
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.6
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = GuiParent()
    local bb,nl,dl = MakeBB(part,label,color)
    State.ESPCache[model] = {hl=hl,bb=bb,nl=nl,dl=dl,hrp=part}
end

function ESP.UpdateDist()
    local ch = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then
            c.dl.Text = math.floor((c.hrp.Position-hrp.Position).Magnitude).."m"
        end
    end
end

function ESP.Validate()
    for obj in pairs(State.ESPCache) do
        if not obj or not obj.Parent then ESP.Clear(obj) end
    end
end

function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not Role.IsFake(p.Character) then
            local char = p.Character
            local isK = Role.IsKiller(char)
            if isK and State.ESP_Killer then
                if not State.ESPCache[char] then
                    ESP.AddChar(char, "☠ KILLER ["..p.Name.."]", State.Color_Killer)
                end
            elseif not isK and State.ESP_Survivors then
                if not State.ESPCache[char] then
                    ESP.AddChar(char, "◈ "..p.Name, State.Color_Survivor)
                end
            elseif (isK and not State.ESP_Killer) or (not isK and not State.ESP_Survivors) then
                ESP.Clear(char)
            end
        end
    end
end

function ESP.ScanGens()
    if not WS.Generators then return end
    for _, g in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators and not State.ESPCache[g] then
            local prog = g:GetAttribute("RepairProgress") or 0
            ESP.AddObj(g, "⚡ Generator "..math.floor(prog).."%", State.Color_Generator)
        elseif not State.ESP_Generators then ESP.Clear(g) end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.AddObj(w, "⚔ "..w.Name, State.Color_Weapon)
        elseif not State.ESP_Weapons then ESP.Clear(w) end
    end
end

function ESP.ScanClones()
    if not WS.Clones then return end
    for _, c in ipairs(WS.Clones:GetChildren()) do
        if State.ESP_Clones and not State.ESPCache[c] then
            ESP.AddObj(c, "👥 Clone", State.Color_Clone)
        elseif not State.ESP_Clones then ESP.Clear(c) end
    end
end

function ESP.ScanPallets()
    if not WS.Pallets then return end
    for _, p in ipairs(WS.Pallets:GetChildren()) do
        if State.ESP_Pallets and not State.ESPCache[p] then
            ESP.AddObj(p, "🪵 Pallet", State.Color_Pallet)
        elseif not State.ESP_Pallets then ESP.Clear(p) end
    end
end

function ESP.ScanVaults()
    if not WS.Vaults then return end
    for _, w in ipairs(WS.Vaults:GetChildren()) do
        if State.ESP_Vaults and not State.ESPCache[w] then
            ESP.AddObj(w, "🪟 Vault", State.Color_Vault)
        elseif not State.ESP_Vaults then ESP.Clear(w) end
    end
end

function ESP.ScanItems()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and (o:GetAttribute("Item") or o:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[o] then
                ESP.AddObj(o, "🎒 "..o.Name, State.Color_Item)
            elseif not State.ESP_Items then ESP.Clear(o) end
        end
    end
end

function ESP.RefreshAll()
    ESP.Validate()
    ESP.ScanPlayers()
    ESP.ScanGens()
    ESP.ScanWeapons()
    ESP.ScanClones()
    ESP.ScanPallets()
    ESP.ScanVaults()
    ESP.ScanItems()
end

task.spawn(function()
    while task.wait(2) do pcall(ESP.RefreshAll) end
end)

CM:Add(RunService.Heartbeat, function() pcall(ESP.UpdateDist) end, "ESP.HB")
CM:Add(Players.PlayerRemoving, function(p) if p.Character then ESP.Clear(p.Character) end end, "PR")
CM:Add(Players.PlayerAdded, function(p)
    CM:Add(p.CharacterRemoving, function(c) ESP.Clear(c) end, "CR:"..p.Name)
end, "PA")
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
        CM:Add(p.CharacterRemoving, function(c) ESP.Clear(c) end, "CR:"..p.Name)
    end
end

local Move = {}
function Move.GetHuman() local ch=LocalPlayer.Character; return ch and ch:FindFirstChildOfClass("Humanoid") end
function Move.GetHRP() local ch=LocalPlayer.Character; return ch and ch:FindFirstChild("HumanoidRootPart") end
function Move.Speed() local h=Move.GetHuman(); if h then h.WalkSpeed=State.WalkSpeed end end
function Move.Jump() local h=Move.GetHuman(); if h then h.UseJumpPower=true; h.JumpPower=State.JumpPower end end

function Move.SetNoClip(e)
    if State.NoClipConn then pcall(function() State.NoClipConn:Disconnect() end); State.NoClipConn=nil end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch=LocalPlayer.Character; if not ch then return end
            for _,p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide=false end
            end
        end)
    end
end

function Move.SetInfJump(e)
    if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end); State.InfJumpConn=nil end
    if e then
        State.InfJumpConn = UserInputService.JumpRequest:Connect(function()
            local h=Move.GetHuman(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local tpTarget = ""
function Move.NearestGen()
    if not WS.Generators then Notify("TP","No generators.",3); return end
    local hrp=Move.GetHRP(); if not hrp then return end
    local best,bd=nil,math.huge
    for _,g in ipairs(WS.Generators:GetChildren()) do
        local p=g:FindFirstChild("HitBox") or g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then local d=(p.Position-hrp.Position).Magnitude; if d<bd then bd=d;best=p end end
    end
    if best then hrp.CFrame=best.CFrame+Vector3.new(0,4,0); Notify("TP","TP'd ("..math.floor(bd).."m)",3) end
end

function Move.ToPlayer()
    if tpTarget=="" then Notify("TP","Enter name first.",3); return end
    local t=Players:FindFirstChild(tpTarget)
    if not t or not t.Character then Notify("TP","Not found: "..tpTarget,3); return end
    local hrp=Move.GetHRP(); local thrp=t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then hrp.CFrame=thrp.CFrame+Vector3.new(0,0,3); Notify("TP","TP'd to "..tpTarget,3) end
end

function Move.NearestExit()
    local hrp=Move.GetHRP(); if not hrp then return end
    local best,bd=nil,math.huge
    for _,o in ipairs(Workspace:GetDescendants()) do
        if (o.Name:lower():find("exit") or o.Name:lower():find("gate")) and o:IsA("BasePart") then
            local d=(o.Position-hrp.Position).Magnitude
            if d<bd then bd=d;best=o end
        end
    end
    if best then hrp.CFrame=best.CFrame+Vector3.new(0,4,0); Notify("TP","TP'd to exit ("..math.floor(bd).."m)",3)
    else Notify("TP","No exit found.",3) end
end

local Vis = {}
function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,
    }
end
function Vis.RestoreLight()
    for k,v in pairs(State.LightBackup) do pcall(function() Lighting[k]=v end) end
end
function Vis.FullBright(e)
    Vis.BackupLight()
    if e then
        Lighting.Ambient=Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.Brightness=2; Lighting.ClockTime=14
        Lighting.GlobalShadows=false
    else Vis.RestoreLight() end
end
function Vis.NoFog(e)
    Vis.BackupLight()
    if e then
        Lighting.FogEnd=999999; Lighting.FogStart=999999
        for _,a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0;a.Haze=0 end
        end
    else Lighting.FogEnd=State.LightBackup.FogEnd or 100000; Lighting.FogStart=State.LightBackup.FogStart or 0 end
end
function Vis.NoShadows(e) Vis.BackupLight(); Lighting.GlobalShadows=not e end
function Vis.ClearWx(e)
    if e then for _,o in ipairs(Lighting:GetDescendants()) do
        if o:IsA("Atmosphere") then o.Density=0;o.Haze=0 end
    end end
end
function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel = e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end
function Vis.SetFOV(f) if Camera then Camera.FieldOfView=tonumber(f) or 70 end end
function Vis.SetClock(t) Lighting.ClockTime=tonumber(t) or 14 end
function Vis.PostFX(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not rm
        end
    end
end
function Vis.ColorCorr(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then v.Enabled=not rm end
    end
end
function Vis.Particles(rm)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = not rm
        end
    end
end
function Vis.HideName(e)
    local ch=LocalPlayer.Character; if not ch then return end
    local head=ch:FindFirstChild("Head"); if not head then return end
    for _,g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled=not e end
    end
end
function Vis.MuteAll(e)
    if e then
        for _,s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") then
                table.insert(State.MutedSounds,{s=s,v=s.Volume}); s.Volume=0
            end
        end
    else
        for _,en in ipairs(State.MutedSounds) do
            if en.s and en.s.Parent then en.s.Volume=en.v end
        end
        State.MutedSounds={}
    end
end
function Vis.MuteBG(e)
    local bg=Workspace:FindFirstChild("BackgroundSounds"); if not bg then return end
    for _,s in ipairs(bg:GetDescendants()) do
        if s:IsA("Sound") then s.Volume=e and 0 or 1 end
    end
end
function Vis.Freecam(e)
    if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end); State.FreecamConn=nil end
    if e then
        Camera.CameraType=Enum.CameraType.Scriptable
        local pos=Camera.CFrame.Position
        State.FreecamConn = RunService.RenderStepped:Connect(function()
            local look=Camera.CFrame.LookVector; local right=Camera.CFrame.RightVector
            local mv=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv-Vector3.new(0,1,0) end
            pos=pos+mv*2
            Camera.CFrame=CFrame.new(pos,pos+look)
        end)
    else Camera.CameraType=Enum.CameraType.Custom end
end
function Vis.ServerHop()
    pcall(function()
        local raw=game:HttpGet("https://games.roblox.com/v1/games/"..tostring(game.PlaceId).."/servers/Public?sortOrder=Asc&limit=100")
        local dok,data=pcall(HttpService.JSONDecode,HttpService,raw)
        if dok and data and data.data then
            for _,s in ipairs(data.data) do
                if s.playing<s.maxPlayers and s.id~=game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer)
                    return
                end
            end
        end
        Notify("Server Hop","No server found.",4)
    end)
end

local Surv = {}

function Surv.SetInvisible(enable)
    local char = LocalPlayer.Character; if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") or p:IsA("Decal") then
            pcall(function() p.LocalTransparencyModifier = enable and 1 or 0 end)
        end
    end
end

function Surv.SetSpeedBoost(enable)
    local h = Move.GetHuman(); if not h then return end
    h.WalkSpeed = enable and State.SurvSpeedValue or State.WalkSpeed
end

function Surv.SetNoFall(enable)
    if State.NoFallConn then pcall(function() State.NoFallConn:Disconnect() end); State.NoFallConn=nil end
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then
            if enable then
                pcall(function()
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end)
                State.NoFallConn = h.StateChanged:Connect(function(old, new)
                    if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Freefall then
                        local hrp = char:FindFirstChild("HumanoidRootPart")
                        if hrp then hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z) end
                    end
                end)
            else
                pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
            end
        end
    end
end

function Surv.SetGodMode(enable)
    if State.GodModeConn then pcall(function() State.GodModeConn:Disconnect() end); State.GodModeConn=nil end
    if enable then
        State.GodModeConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if char then
                pcall(function()
                    char:SetAttribute("Iframes", true)
                    char:SetAttribute("Untargettable", true)
                    char:SetAttribute("Knocked", false)
                    char:SetAttribute("Parry", true)
                end)
                local h = char:FindFirstChildOfClass("Humanoid")
                if h then
                    if h.Health < h.MaxHealth then pcall(function() h.Health = h.MaxHealth end) end
                    local trg = char:FindFirstChild("RagdollTrigger")
                    if trg and trg:IsA("BoolValue") and trg.Value then
                        pcall(function() trg.Value = false end)
                    end
                end
            end
        end)
    else
        local char = LocalPlayer.Character
        if char then
            pcall(function()
                char:SetAttribute("Iframes", false)
                char:SetAttribute("Untargettable", false)
                char:SetAttribute("Parry", false)
            end)
        end
    end
end

function Surv.SetFleeKiller(enable)
    if State.FleeConn then pcall(function() State.FleeConn:Disconnect() end); State.FleeConn=nil end
    if enable then
        local lastFlee = 0
        State.FleeConn = RunService.Heartbeat:Connect(function()
            if tick() - lastFlee < 0.5 then return end
            local hrp = Move.GetHRP(); if not hrp then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and not Role.IsFake(p.Character) and Role.IsKiller(p.Character) then
                    local khrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp then
                        local dist = (khrp.Position - hrp.Position).Magnitude
                        if dist < State.FleeDistance then
                            local dir = (hrp.Position - khrp.Position)
                            if dir.Magnitude > 0.1 then
                                dir = Vector3.new(dir.X, 0, dir.Z).Unit
                                local newPos = hrp.Position + dir * (State.FleeDistance + 15)
                                pcall(function() hrp.CFrame = CFrame.new(newPos, newPos + dir) end)
                                lastFlee = tick()
                            end
                        end
                    end
                end
            end
        end)
    end
end

function Surv.UpdateParryRing()
    if State.ParryRing then pcall(function() State.ParryRing:Destroy() end); State.ParryRing=nil end
    if not State.ShowParryRing then return end
    local ring = Instance.new("Part")
    ring.Name = "ParryRing"
    ring.Size = Vector3.new(0.2, State.ParryRange*2, State.ParryRange*2)
    ring.Shape = Enum.PartType.Cylinder
    ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false; ring.CanTouch = false
    ring.Material = Enum.Material.Neon; ring.Transparency = 0.7
    local colors = {
        Red = Color3.fromRGB(255,40,40), Blue = Color3.fromRGB(40,120,255),
        Green = Color3.fromRGB(40,255,40), Yellow = Color3.fromRGB(255,220,40),
        Purple = Color3.fromRGB(180,40,255), White = Color3.fromRGB(255,255,255),
    }
    ring.Color = colors[State.ParryRingColor] or colors.Red
    ring.Parent = Workspace
    State.ParryRing = ring
    task.spawn(function()
        while State.ParryRing == ring and ring.Parent do
            local h = Move.GetHRP()
            if h then
                ring.CFrame = CFrame.new(h.Position - Vector3.new(0,2.5,0)) * CFrame.Angles(0,0,math.rad(90))
            end
            task.wait()
        end
    end)
end

function Surv.SetAutoParry(enable)
    if State.AutoParryConn then pcall(function() State.AutoParryConn:Disconnect() end); State.AutoParryConn=nil end
    if enable then
        if not R.Items.ParryDagger then
            Notify("Auto Parry", "Parrying Dagger remote not found!", 4)
            return
        end
        local lastParry = 0
        State.AutoParryConn = RunService.Heartbeat:Connect(function()
            if tick() - lastParry < 0.5 then return end
            local hrp = Move.GetHRP(); if not hrp then return end
            local char = LocalPlayer.Character; if not char then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and Role.IsKiller(p.Character) then
                    local khrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if khrp then
                        local dist = (khrp.Position - hrp.Position).Magnitude
                        if dist <= State.ParryRange then
                            pcall(function() R.Items.ParryDagger:FireServer() end)
                            lastParry = tick()
                            break
                        end
                    end
                end
            end
        end)
    end
end

function Surv.SetAutoGenRush(enable)
    if enable then
        if not R.Gen.RepairEvent then
            Notify("Auto Gen Rush", "RepairEvent not found!", 4)
            State.AutoGenRush = false
            return
        end
        task.spawn(function()
            while State.AutoGenRush do
                task.wait(0.5)
                if WS.Generators then
                    local hrp = Move.GetHRP()
                    if hrp then
                        local best, bd = nil, math.huge
                        for _, g in ipairs(WS.Generators:GetChildren()) do
                            local prog = g:GetAttribute("RepairProgress") or 0
                            if prog < 100 then
                                local hb = g:FindFirstChild("HitBox")
                                if hb then
                                    local d = (hb.Position - hrp.Position).Magnitude
                                    if d < bd then bd = d; best = g end
                                end
                            end
                        end
                        if best then
                            local hb = best:FindFirstChild("HitBox")
                            local point = best:FindFirstChild("GeneratorPoint2")
                                       or best:FindFirstChild("GeneratorPoint3")
                                       or best:FindFirstChild("GeneratorPoint4")
                            if hb and (hb.Position - hrp.Position).Magnitude > 8 then
                                pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0) end)
                            end
                            pcall(function() R.Gen.RepairEvent:FireServer(best, point) end)
                        end
                    end
                end
            end
        end)
    end
end

function Surv.SetAutoSkillcheck(enable)
    if State.AutoSkillConn then pcall(function() State.AutoSkillConn:Disconnect() end); State.AutoSkillConn=nil end
    if enable then
        if R.Gen.SkillCheck then
            State.AutoSkillConn = R.Gen.SkillCheck.OnClientEvent:Connect(function(gen, point)
                local delay = 0.15
                if State.SkillcheckMode == "Fast" then delay = 0.05
                elseif State.SkillcheckMode == "Instant" then delay = 0 end
                task.wait(delay)
                pcall(function()
                    VirtualInputMgr:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.03)
                    VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
                if R.Gen.SkillCheckResult then
                    pcall(function() R.Gen.SkillCheckResult:FireServer(gen, point, true) end)
                end
            end)
        end
        if R.Heal.SkillCheck then
            CM:Add(R.Heal.SkillCheck.OnClientEvent, function(...)
                local delay = 0.15
                if State.SkillcheckMode == "Fast" then delay = 0.05
                elseif State.SkillcheckMode == "Instant" then delay = 0 end
                task.wait(delay)
                pcall(function()
                    VirtualInputMgr:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                    task.wait(0.03)
                    VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                end)
                if R.Heal.SkillCheckResult then
                    pcall(function() R.Heal.SkillCheckResult:FireServer(...) end)
                end
            end, "HealAutoSkill")
        end
    end
end

function Surv.SetGenProgress(enable)
    for _, g in pairs(State.GenProgressGuis) do pcall(function() g:Destroy() end) end
    State.GenProgressGuis = {}
    if not enable then return end
    if not WS.Generators then return end
    for _, gen in ipairs(WS.Generators:GetChildren()) do
        local hb = gen:FindFirstChild("HitBox") or gen:FindFirstChildWhichIsA("BasePart")
        if hb then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = hb
            bb.Size = UDim2.new(0,140,0,40)
            bb.StudsOffset = Vector3.new(0,5,0)
            bb.AlwaysOnTop = true
            bb.LightInfluence = 0
            bb.MaxDistance = 500
            bb.Parent = GuiParent()
            local lbl = Instance.new("TextLabel", bb)
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "⚡ 0%"
            lbl.TextColor3 = Color3.fromRGB(255,220,60)
            lbl.TextStrokeTransparency = 0
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 16
            table.insert(State.GenProgressGuis, bb)
            task.spawn(function()
                while bb.Parent and State.ShowGenProgress do
                    local prog = gen:GetAttribute("RepairProgress") or 0
                    local players = gen:GetAttribute("PlayersRepairingCount") or 0
                    lbl.Text = string.format("⚡ %d%% [%d🔧]", math.floor(prog), players)
                    lbl.TextColor3 = prog >= 100 and Color3.fromRGB(60,255,60) or Color3.fromRGB(255,220,60)
                    task.wait(0.5)
                end
            end)
        end
    end
end

Log("Survivor module loaded")

local function SetupAwareness()
    if State.AwarenessReady then return end
    State.AwarenessReady = true
    local function Conn(sig,cb,l) if sig then CM:Add(sig,cb,l) end end
    local function BindConn(sig,cb,l) if sig then CM:Add(sig.Event,cb,l) end end

    Conn(R.Gen.SkillCheck and R.Gen.SkillCheck.OnClientEvent, function()
        if State.SkillCheckNotify and not State.AutoSkillcheck then Notify("⚙ Skill Check!","Hit SPACE!",2) end
    end,"GenSC")
    Conn(R.Gen.SkillCheckFail and R.Gen.SkillCheckFail.OnClientEvent, function()
        if State.SkillCheckNotify then Notify("⚙ Skill Check FAIL","Progress lost!",3) end
    end,"GenSCFail")
    BindConn(R.Gen.GenDone, function()
        if State.GenDoneNotify then Notify("⚡ Generator Done!","",3) end
    end,"GenDone")
    BindConn(R.Gen.AllGenDone, function()
        if State.AllGensNotify then Notify("⚡ All Gens Done!","Find exit!",6) end
    end,"AllGens")
    Conn(R.Heal.SkillCheck and R.Heal.SkillCheck.OnClientEvent, function()
        if State.HealSkillNotify and not State.AutoSkillcheck then Notify("💊 Heal Check!","",2) end
    end,"HealSC")
    Conn(R.Chase.Music and R.Chase.Music.OnClientEvent, function()
        if State.ChaseAlert then Notify("⚠ CHASE!","Killer nearby!",3) end
    end,"Chase")
    Conn(R.Attack.Lunge and R.Attack.Lunge.OnClientEvent, function()
        if State.LungeAlert then Notify("⚠ LUNGE!","",2) end
    end,"Lunge")
    Conn(R.Attack.Basic and R.Attack.Basic.OnClientEvent, function()
        if State.AttackAlert then Notify("⚠ ATTACK!","",2) end
    end,"Attack")
    Conn(R.Carry.Hook and R.Carry.Hook.OnClientEvent, function()
        if State.HookAlert then Notify("🪝 HOOKED!","",4) end
    end,"Hook")
    Conn(R.Carry.HookPhase and R.Carry.HookPhase.OnClientEvent, function(phase)
        if State.HookPhaseAlert then Notify("🪝 Hook Phase "..tostring(phase),"",3) end
    end,"HookPhase")
    Conn(R.Carry.UnHook and R.Carry.UnHook.OnClientEvent, function()
        if State.UnhookAlert then Notify("🪝 Unhooked!","",3) end
    end,"UnHook")
    BindConn(R.Mech.GotKnocked, function()
        if State.KnockedAlert then Notify("💀 KNOCKED!","",3) end
    end,"Knocked")
    Conn(R.KPerk.KingScourgeStart and R.KPerk.KingScourgeStart.OnClientEvent, function()
        if State.KingScourgeAlert then Notify("👑 King Scourge!","",3) end
    end,"KScourge")
    BindConn(R.Exit.Gate, function()
        if State.GateAlert then Notify("🚪 Gate Opened!","",5) end
    end,"Gate")
    BindConn(R.Game.KillerMorph, function()
        State.IsKiller=true; Notify("☠ Role","You are KILLER!",5)
    end,"KMorph")
    BindConn(R.Game.Start, function()
        State.MatchActive=true; State.IsKiller=false; Notify("🎮 Match Started","Good luck!",3)
    end,"GStart")
    BindConn(R.Game.RoundEnd, function()
        State.MatchActive=false; ESP.ClearAll()
    end,"RoundEnd")
    Conn(R.Game.OneLeft and R.Game.OneLeft.OnClientEvent, function()
        if State.OneLeftNotify then Notify("👤 Last Survivor!","",5) end
    end,"OneLeft")
    Conn(R.Game.Death and R.Game.Death.OnClientEvent, function()
        if State.DeathNotify then Notify("💀 You Died","",4) end
    end,"Death")
    Conn(R.Msg.Announce and R.Msg.Announce.OnClientEvent, function(msg)
        if State.AnnounceAlert then Notify("📢 Announce",tostring(msg or ""),5) end
    end,"Announce")
    CM:Add(LocalPlayer.Idled, function()
        if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end
    end,"AntiAFK")
    Log("Awareness ready")
end

local Window = WindUI:CreateWindow({
    Title = HUB.Name, Icon = "shield",
    Author = HUB.Author.." • "..HUB.Game,
    Folder = "X0DEC04T_Hub",
    Size = UDim2.fromOffset(580, 420),
    Transparent = true, Theme = "Dark",
    SideBarWidth = 180, HasOutline = true,
})
assert(Window, "Window failed!")

local Tabs = {}
local TAB_LIST = {
    {key="Main",name="Main",icon="home"},
    {key="Survivor",name="Survivor",icon="shield"},
    {key="Awareness",name="Awareness",icon="bell"},
    {key="ESP",name="ESP",icon="eye"},
    {key="Movement",name="Movement",icon="footprints"},
    {key="Visuals",name="Visuals",icon="sun"},
    {key="Misc",name="Misc",icon="wrench"},
    {key="Settings",name="Settings",icon="settings"},
}
for _, def in ipairs(TAB_LIST) do
    local ok, tab = pcall(function() return Window:Tab({Title=def.name, Icon=def.icon}) end)
    if ok and tab then Tabs[def.key]=tab end
end

if Tabs.Main then
    local T = Tabs.Main
    T:Section({Title="Information"})
    T:Paragraph({Title=HUB.Name.." v"..HUB.Version, Desc="Game: "..HUB.Game.."\nAuthor: "..HUB.Author})
    T:Section({Title="Keybinds"})
    T:Paragraph({Title="Shortcuts", Desc="RightShift = Toggle UI\nEnd = Panic (Clear ESP)\nX = Toggle Invisible"})
    T:Section({Title="Detection Status"})
    T:Paragraph({Title="Workspace", Desc=
        "Generators: "..(WS.Generators and "✅" or "❌").."\n"..
        "Pallets: "..(WS.Pallets and "✅" or "❌").."\n"..
        "Vaults: "..(WS.Vaults and "✅" or "❌")})
end

if Tabs.Survivor then
    local T = Tabs.Survivor
    T:Section({Title="Feature Invisible"})
    T:Toggle({Title="Invisible", Value=false, Callback=function(v) State.Invisible=v; Surv.SetInvisible(v) end})
    T:Toggle({Title="Speed Boost", Value=false, Callback=function(v) State.SurvSpeedBoost=v; Surv.SetSpeedBoost(v) end})
    T:Slider({Title="Speed Boost Value", Value={Min=16,Max=60,Default=24}, Step=1, Callback=function(v)
        State.SurvSpeedValue=tonumber(v) or 24
        if State.SurvSpeedBoost then Surv.SetSpeedBoost(true) end
    end})
    T:Keybind({Title="Hotkey Invisible", Value="X", Callback=function(k)
        local ok, key = pcall(function() return Enum.KeyCode[k] end)
        if ok and key then State.InvisibleHotkey=key; Notify("Hotkey","Set to "..k,3) end
    end})

    T:Section({Title="Auto Parry [BETA]"})
    T:Toggle({Title="Enable Auto Parry", Value=false, Callback=function(v)
        State.AutoParry=v; Surv.SetAutoParry(v)
    end})
    T:Slider({Title="Parry Range", Value={Min=5,Max=50,Default=20}, Step=1, Callback=function(v)
        State.ParryRange=tonumber(v) or 20
        if State.ShowParryRing then Surv.UpdateParryRing() end
    end})
    T:Toggle({Title="Show Visual Range", Value=false, Callback=function(v)
        State.ShowParryRing=v; Surv.UpdateParryRing()
    end})
    T:Dropdown({Title="Ring Color", Values={"Red","Blue","Green","Yellow","Purple","White"}, Value="Red", Callback=function(v)
        State.ParryRingColor=v
        if State.ShowParryRing then Surv.UpdateParryRing() end
    end})

    T:Section({Title="Survival Utility"})
    T:Toggle({Title="No Fall Damage", Value=false, Callback=function(v)
        State.NoFallDamage=v; Surv.SetNoFall(v)
    end})
    T:Toggle({Title="Flee Killer (Auto TP)", Value=false, Callback=function(v)
        State.FleeKiller=v; Surv.SetFleeKiller(v)
    end})
    T:Slider({Title="Flee Distance", Value={Min=10,Max=100,Default=40}, Step=5, Callback=function(v)
        State.FleeDistance=tonumber(v) or 40
    end})
    T:Toggle({Title="God Mode", Value=false, Callback=function(v)
        State.GodMode=v; Surv.SetGodMode(v)
    end})

    T:Section({Title="Auto Generator Rush"})
    T:Toggle({Title="Enable Auto Gen Rush", Value=false, Callback=function(v)
        State.AutoGenRush=v; Surv.SetAutoGenRush(v)
    end})

    T:Section({Title="Auto Skillcheck Perfect"})
    T:Dropdown({Title="Mode", Values={"Instant","Fast","Legit"}, Value="Legit", Callback=function(v)
        State.SkillcheckMode=v
    end})
    T:Toggle({Title="Enable Auto Skillcheck", Value=false, Callback=function(v)
        State.AutoSkillcheck=v; Surv.SetAutoSkillcheck(v)
        if v then Notify("Auto Skillcheck","Enabled!",3) end
    end})

    T:Section({Title="Generator Info"})
    T:Toggle({Title="Show Generator Progression", Value=false, Callback=function(v)
        State.ShowGenProgress=v; Surv.SetGenProgress(v)
    end})
end

if Tabs.Awareness then
    local T = Tabs.Awareness
    T:Section({Title="Killer Alerts"})
    T:Toggle({Title="Chase Music", Value=true, Callback=function(v) State.ChaseAlert=v end})
    T:Toggle({Title="Basic Attack", Value=true, Callback=function(v) State.AttackAlert=v end})
    T:Toggle({Title="Lunge", Value=true, Callback=function(v) State.LungeAlert=v end})
    T:Toggle({Title="King Scourge", Value=true, Callback=function(v) State.KingScourgeAlert=v end})
    T:Section({Title="Survivor Alerts"})
    T:Toggle({Title="Knocked", Value=true, Callback=function(v) State.KnockedAlert=v end})
    T:Toggle({Title="Hook", Value=true, Callback=function(v) State.HookAlert=v end})
    T:Toggle({Title="Hook Phase", Value=true, Callback=function(v) State.HookPhaseAlert=v end})
    T:Toggle({Title="Unhook", Value=true, Callback=function(v) State.UnhookAlert=v end})
    T:Section({Title="Skill Checks"})
    T:Toggle({Title="Gen Skillcheck Alert", Value=true, Callback=function(v) State.SkillCheckNotify=v end})
    T:Toggle({Title="Heal Skillcheck Alert", Value=true, Callback=function(v) State.HealSkillNotify=v end})
    T:Section({Title="Objectives"})
    T:Toggle({Title="Gen Done", Value=true, Callback=function(v) State.GenDoneNotify=v end})
    T:Toggle({Title="All Gens Done", Value=true, Callback=function(v) State.AllGensNotify=v end})
    T:Toggle({Title="Gate Opened", Value=true, Callback=function(v) State.GateAlert=v end})
    T:Toggle({Title="Last Survivor", Value=true, Callback=function(v) State.OneLeftNotify=v end})
    T:Toggle({Title="Death", Value=true, Callback=function(v) State.DeathNotify=v end})
    T:Toggle({Title="Announcements", Value=true, Callback=function(v) State.AnnounceAlert=v end})
end

if Tabs.ESP then
    local T = Tabs.ESP
    T:Section({Title="Player ESP (Red=Killer, Blue=Survivor)"})
    T:Toggle({Title="Killer ESP (RED)", Value=false, Callback=function(v)
        State.ESP_Killer=v
        if not v then for _,p in ipairs(Players:GetPlayers()) do
            if p.Character and Role.IsKiller(p.Character) then ESP.Clear(p.Character) end
        end end
    end})
    T:Toggle({Title="Survivor ESP (BLUE)", Value=false, Callback=function(v)
        State.ESP_Survivors=v
        if not v then for _,p in ipairs(Players:GetPlayers()) do
            if p.Character and not Role.IsKiller(p.Character) then ESP.Clear(p.Character) end
        end end
    end})

    T:Section({Title="Object ESP"})
    T:Toggle({Title="Generator ESP", Value=false, Callback=function(v)
        State.ESP_Generators=v
        if not v and WS.Generators then for _,g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end end
    end})
    T:Toggle({Title="Pallet ESP", Value=false, Callback=function(v)
        State.ESP_Pallets=v
        if not v and WS.Pallets then for _,p in ipairs(WS.Pallets:GetChildren()) do ESP.Clear(p) end end
    end})
    T:Toggle({Title="Vault ESP (Windows)", Value=false, Callback=function(v)
        State.ESP_Vaults=v
        if not v and WS.Vaults then for _,w in ipairs(WS.Vaults:GetChildren()) do ESP.Clear(w) end end
    end})
    T:Toggle({Title="Item ESP", Value=false, Callback=function(v) State.ESP_Items=v end})
    T:Toggle({Title="Weapon ESP", Value=false, Callback=function(v)
        State.ESP_Weapons=v
        if not v and WS.Weapons then for _,w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end end
    end})
    T:Toggle({Title="Clone ESP", Value=false, Callback=function(v)
        State.ESP_Clones=v
        if not v and WS.Clones then for _,c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end end
    end})

    T:Section({Title="Display"})
    T:Toggle({Title="Show Names", Value=true, Callback=function(v)
        State.ESP_ShowName=v
        for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end
    end})
    T:Toggle({Title="Show Distance", Value=true, Callback=function(v)
        State.ESP_ShowDistance=v
        for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end
    end})
    T:Slider({Title="Max Distance", Value={Min=50,Max=2000,Default=500}, Step=50, Callback=function(v)
        State.ESP_MaxDistance=tonumber(v) or 500
        for _,c in pairs(State.ESPCache) do if c.bb then c.bb.MaxDistance=State.ESP_MaxDistance end end
    end})

    T:Section({Title="Actions"})
    T:Button({Title="Refresh ESP", Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end})
    T:Button({Title="Clear All ESP", Callback=function() ESP.ClearAll(); Notify("ESP","Cleared",2) end})
end

if Tabs.Movement then
    local T = Tabs.Movement
    T:Section({Title="Speed & Jump"})
    T:Slider({Title="Walk Speed", Value={Min=16,Max=200,Default=16}, Step=1, Callback=function(v)
        State.WalkSpeed=tonumber(v) or 16
        if not State.SurvSpeedBoost then Move.Speed() end
    end})
    T:Slider({Title="Jump Power", Value={Min=50,Max=300,Default=50}, Step=5, Callback=function(v)
        State.JumpPower=tonumber(v) or 50; Move.Jump()
    end})
    T:Section({Title="Advanced"})
    T:Toggle({Title="NoClip", Value=false, Callback=function(v) State.NoClip=v; Move.SetNoClip(v) end})
    T:Toggle({Title="Infinite Jump", Value=false, Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end})
    T:Section({Title="Teleport"})
    T:Button({Title="TP Nearest Generator", Callback=Move.NearestGen})
    T:Button({Title="TP Nearest Exit", Callback=Move.NearestExit})
    T:Input({Title="Player Name", Placeholder="Name...", Callback=function(v) tpTarget=tostring(v or "") end})
    T:Button({Title="TP to Player", Callback=Move.ToPlayer})
end

if Tabs.Visuals then
    local T = Tabs.Visuals
    T:Section({Title="Lighting"})
    T:Toggle({Title="FullBright", Value=false, Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
    T:Toggle({Title="No Fog", Value=false, Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
    T:Toggle({Title="No Shadows", Value=false, Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end})
    T:Toggle({Title="Clear Weather", Value=false, Callback=function(v) State.ClearWeather=v; Vis.ClearWx(v) end})
    T:Slider({Title="Time of Day", Value={Min=0,Max=24,Default=14}, Step=1, Callback=function(v)
        State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime)
    end})
    T:Section({Title="Camera"})
    T:Slider({Title="FOV", Value={Min=30,Max=120,Default=70}, Step=5, Callback=function(v)
        State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV)
    end})
    T:Toggle({Title="Freecam", Value=false, Callback=function(v) State.Freecam=v; Vis.Freecam(v) end})
    T:Section({Title="Post FX"})
    T:Toggle({Title="Remove Blur/Bloom", Value=false, Callback=function(v) State.RemoveBlur=v; Vis.PostFX(v) end})
    T:Toggle({Title="Remove Color Correction", Value=false, Callback=function(v) State.RemoveCC=v; Vis.ColorCorr(v) end})
    T:Toggle({Title="No Particles", Value=false, Callback=function(v) State.NoParticles=v; Vis.Particles(v) end})
    T:Section({Title="Performance"})
    T:Toggle({Title="Low Graphics", Value=false, Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end})
end

if Tabs.Misc then
    local T = Tabs.Misc
    T:Section({Title="Audio"})
    T:Toggle({Title="Mute All Sounds", Value=false, Callback=function(v) State.NoSound=v; Vis.MuteAll(v) end})
    T:Toggle({Title="Mute BG Music", Value=false, Callback=function(v) State.MuteBGMusic=v; Vis.MuteBG(v) end})
    T:Section({Title="Character"})
    T:Toggle({Title="Hide Own Name", Value=false, Callback=function(v) State.HideName=v; Vis.HideName(v) end})
    T:Section({Title="Server"})
    T:Button({Title="Server Hop", Callback=Vis.ServerHop})
    T:Button({Title="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end})
    T:Button({Title="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Notify("Copied","Job ID!",3)
        else Notify("Error","Clipboard unsupported",3) end
    end})
    T:Section({Title="Utility"})
    T:Toggle({Title="Auto Rejoin on Kick", Value=false, Callback=function(v) State.AutoRejoin=v end})
end

if Tabs.Settings then
    local T = Tabs.Settings
    T:Section({Title="Anti-AFK"})
    T:Toggle({Title="Anti-AFK", Value=true, Callback=function(v) State.AntiAFK=v end})
    T:Section({Title="Credits"})
    T:Paragraph({Title=HUB.Name.." v"..HUB.Version, Desc="Author: "..HUB.Author.."\nGame: "..HUB.Game.."\nUI: Wind UI"})
    T:Section({Title="Danger Zone"})
    T:Button({Title="Unload Hub", Callback=function()
        for _, key in ipairs({"NoClipConn","InfJumpConn","FreecamConn","NoFallConn","GodModeConn","FleeConn","AutoParryConn","AutoSkillConn"}) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.AutoGenRush = false
        State.ShowGenProgress = false
        Surv.SetGenProgress(false)
        if State.ParryRing then pcall(function() State.ParryRing:Destroy() end) end
        CM:Cleanup(); Vis.RestoreLight()
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView=70 end)
        ESP.ClearAll()
        _G[INSTANCE_KEY]=nil
        pcall(function() Window:Destroy() end)
        Log("Unloaded")
    end})
end

SetupAwareness()

CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        pcall(function() Window:Toggle() end)
    elseif inp.KeyCode == Enum.KeyCode.End then
        State.ESP_Killer=false; State.ESP_Survivors=false
        State.ESP_Generators=false; State.ESP_Items=false
        State.ESP_Weapons=false; State.ESP_Clones=false
        State.ESP_Pallets=false; State.ESP_Vaults=false
        ESP.ClearAll(); Notify("Panic","All ESP cleared!",3)
    elseif inp.KeyCode == State.InvisibleHotkey then
        State.Invisible = not State.Invisible
        Surv.SetInvisible(State.Invisible)
        Notify("Invisible", State.Invisible and "ON" or "OFF", 2)
    end
end, "Keybinds")

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1.5)
    pcall(Move.Speed); pcall(Move.Jump)
    if State.NoClip then pcall(Move.SetNoClip, true) end
    if State.InfJump then pcall(Move.SetInfJump, true) end
    if State.FullBright then pcall(Vis.FullBright, true) end
    if State.NoFog then pcall(Vis.NoFog, true) end
    if State.HideName then pcall(Vis.HideName, true) end
    if State.FOV ~= 70 then pcall(Vis.SetFOV, State.FOV) end
    if State.Invisible then pcall(Surv.SetInvisible, true) end
    if State.SurvSpeedBoost then pcall(Surv.SetSpeedBoost, true) end
    if State.NoFallDamage then pcall(Surv.SetNoFall, true) end
    if State.GodMode then pcall(Surv.SetGodMode, true) end
    if State.FleeKiller then pcall(Surv.SetFleeKiller, true) end
    if State.AutoParry then pcall(Surv.SetAutoParry, true) end
    if State.AutoSkillcheck then pcall(Surv.SetAutoSkillcheck, true) end
end, "CharAdded")

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end
end, "Teleport")

task.spawn(function()
    while task.wait(5) do
        if State.FullBright then pcall(Vis.FullBright, true) end
        if State.NoFog then pcall(Vis.NoFog, true) end
        if State.NoShadows then pcall(Vis.NoShadows, true) end
        if State.ClearWeather then pcall(Vis.ClearWx, true) end
    end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version, timestamp = os.time(),
    destroy = function()
        for _, key in ipairs({"NoClipConn","InfJumpConn","FreecamConn","NoFallConn","GodModeConn","FleeConn","AutoParryConn","AutoSkillConn"}) do
            if State[key] then pcall(function() State[key]:Disconnect() end) end
        end
        State.AutoGenRush = false
        State.ShowGenProgress = false
        Surv.SetGenProgress(false)
        if State.ParryRing then pcall(function() State.ParryRing:Destroy() end) end
        CM:Cleanup(); Vis.RestoreLight()
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView=70 end)
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." loaded!", 5)
Log("v"..HUB.Version.." ready")
