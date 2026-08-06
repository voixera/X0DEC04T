--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.1.1 - Violence District [Fluent UI]
-- Fixed: Auto Parry using parryResult listener + reliable trigger
-- Fixed: Instant SkillCheck auto-detect (no manual lock button)
--═══════════════════════════════════════════════════════════════════════════════

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local HttpService         = game:GetService("HttpService")
local Workspace           = game:GetService("Workspace")
local CoreGui             = game:GetService("CoreGui")
local VirtualUser         = game:GetService("VirtualUser")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local VirtualInputMgr     = game:GetService("VirtualInputManager")
local TextChatService     = game:GetService("TextChatService")
local TweenService        = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")
local ContentProvider     = game:GetService("ContentProvider")
local Stats               = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_v111"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

for _, oldKey in ipairs({"__X0DEC04T_v105","__X0DEC04T_v106","__X0DEC04T_v107","__X0DEC04T_v108","__X0DEC04T_v109","__X0DEC04T_v110"}) do
    if _G[oldKey] then
        local prev = _G[oldKey]
        if type(prev.destroy) == "function" then pcall(prev.destroy) end
        _G[oldKey] = nil
        task.wait(0.1)
    end
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("v1.1.1 starting")

local Fluent           = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager      = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local HUB = {
    Name = "X0DEC04T Hub", Game = "Violence District", Version = "1.1.1",
    Author = "#ONTOP", LogoId = "rbxassetid://85855925276969", Discord = "discord.gg/x0dec04t",
}

local KILLER_RED = Color3.fromRGB(220, 60, 60)

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

local function IsTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, cfg = pcall(function() return TextChatService.ChatInputBarConfiguration end)
    if ok and cfg and cfg.IsFocused then return true end
    return false
end

local KB = { _binds = {}, DoubleTapWindow = 0.35, _lastTap = {}, BlockWhileTyping = true }
function KB.Register(name, key, cb, requireDouble)
    KB._binds[name] = { key = key, callback = cb, enabled = true, requireDouble = requireDouble }
end
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if KB.BlockWhileTyping and IsTyping() then return end
    for name, bind in pairs(KB._binds) do
        if bind.enabled and bind.key == inp.KeyCode then
            if bind.requireDouble then
                local now = tick()
                if now - (KB._lastTap[name] or 0) <= KB.DoubleTapWindow then
                    KB._lastTap[name] = 0; pcall(bind.callback)
                else KB._lastTap[name] = now end
            else pcall(bind.callback) end
        end
    end
end)

--------------------------------------------------------------------------------
-- REMOTES
--------------------------------------------------------------------------------
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function GR(...)
    if not Remotes then return nil end
    local c = Remotes
    for _, n in ipairs({...}) do
        c = c:FindFirstChild(n)
        if not c then return nil end
    end
    return c
end
local function DeepFindRemote(keywords)
    if not Remotes then return nil end
    for _, obj in ipairs(Remotes:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n = obj.Name:lower()
            for _, kw in ipairs(keywords) do
                if n:find(kw, 1, true) then return obj end
            end
        end
    end
    return nil
end

local R = {
    Gen = {
        RepairEvent = GR("Generator","RepairEvent"),
        RepairVFX   = GR("Generator","RepairVFX"),
        RepairAnim  = GR("Generator","RepairAnim"),
        SkillCheckEvent  = GR("Generator","SkillCheckEvent"),
        SkillCheckFail   = GR("Generator","SkillCheckFailEvent"),
        SkillCheckResult = GR("Generator","SkillCheckResultEvent"),
        SkillCheckValidated = GR("Generator","Skillcheckvalidated"),
        BreakEvent  = GR("Generator","BreakGenEvent"),
        BreakCommit = GR("Generator","BreakGenCommit"),
        GenDone     = GR("Generator","GenDone"),
    },
    Parry = {
        Event  = GR("Items","Parrying Dagger","parry"),
        Result = GR("Items","Parrying Dagger","parryResult"),
    },
    Heal       = GR("Healing","HealEvent"),
    HealCommit = GR("Healing","HealCommit"),
    HealSelf   = GR("Healing","HealSelf"),
    HealPlayer = GR("Healing","HealPlayer"),
    HealStart  = GR("Healing","StartHeal"),
    HealFinish = GR("Healing","FinishHeal"),
    HealResult = GR("Healing","SkillCheckResultEvent"),
    MedKit     = GR("Items","MedKit","Heal") or GR("Items","Medkit","Heal"),
    AdrenalineHealthy = GR("Items","Adrenaline Shot","Healthy"),
    AdrenalineInject  = GR("Items","Adrenaline Shot","Inject"),
    AdrenalineUse     = GR("Items","Adrenaline Shot","Use"),
    Attacks = {
        Basic = GR("Attacks","BasicAttack"),
        After = GR("Attacks","AfterAttack"),
        Hit   = GR("Attacks","hit"),
        Lunge = GR("Attacks","Lunge"),
    },
    AttackEvent = GR("AttackEvent"),
    Killers = {
        Frenzy     = GR("Killers","Killer","FrenzyHitEvent"),
        Masked     = GR("Killers","Masked","alexattack"),
        Hidden     = GR("Killers","Hidden","m2HitVM"),
        SlowAttack = GR("Killers","SlowAttack"),
        CureInject = GR("Killers","Cure","inject"),
        StalkerGrab= GR("Killers","Stalker","grab"),
    },
    KingScourge = GR("KillerPerks","kingscourge","KingScourgeHit"),
    Pallet = {
        BreakCommit = GR("Pallet","Jason","PalletBreakCommit"),
        DropCommit  = GR("Pallet","PalletDropCommit"),
        Stunover    = GR("Pallet","Jason","Stunover"),
    },
    Vault     = GR("Window","VaultEvent"),
    FastVault = GR("Window","fastvault"),
    Revive = nil, GetUp = nil, StandUp = nil, Recovered = nil,
    GateOpen = nil, GateEscape = nil,
}

if not R.Heal then R.Heal = DeepFindRemote({"heal","medkit","medical","bandage"}) end
if not R.AdrenalineHealthy then R.AdrenalineHealthy = DeepFindRemote({"adrenal","inject","syringe","shot"}) end
R.Revive     = DeepFindRemote({"revive","getup","get_up","standup","stand_up","recover","wakeup","wake_up","rescued","pickup","pick_up"})
R.GetUp      = DeepFindRemote({"getup","get_up","stand","wakeup"})
R.StandUp    = DeepFindRemote({"standup","stand_up","rise","recover"})
R.Recovered  = DeepFindRemote({"recovered","healed","rescued"})
R.GateOpen   = DeepFindRemote({"gate","exit","open"})
R.GateEscape = DeepFindRemote({"escape","leave","survive"})

Log("[Remotes] RepairEvent="..tostring(R.Gen.RepairEvent))
Log("[Remotes] Parry.Event="..tostring(R.Parry.Event))
Log("[Remotes] Parry.Result="..tostring(R.Parry.Result))

--------------------------------------------------------------------------------
-- KNOCKED STATE
--------------------------------------------------------------------------------
local KNOCKED_ATTR_NAMES = {
    "Knocked","Downed","Down","IsDown","IsDowned","IsKnocked",
    "BleedOut","Dying","Crawling","OnGround",
}
local KNOCKED_STATE_STRINGS = {"knocked","downed","down","dying","crawling","bleedout","bleed"}

local function IsKnocked()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, attrName in ipairs(KNOCKED_ATTR_NAMES) do
        local ok, val = pcall(function() return char:GetAttribute(attrName) end)
        if ok and val == true then return true end
    end
    local ok2, stateVal = pcall(function() return tostring(char:GetAttribute("State") or "") end)
    if ok2 and stateVal then
        local sv = stateVal:lower()
        for _, s in ipairs(KNOCKED_STATE_STRINGS) do
            if sv:find(s, 1, true) then return true end
        end
    end
    for _, child in ipairs(char:GetChildren()) do
        local n = child.Name:lower()
        if child:IsA("BoolValue") and child.Value == true then
            for _, kw in ipairs({"knock","down","downed","dying","crawl","bleed"}) do
                if n:find(kw, 1, true) then return true end
            end
        end
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.WalkSpeed == 0 and hum.Health > 0 and hum.Health <= 1 then return true end
        local hs = hum:GetState()
        if hs == Enum.HumanoidStateType.FallingDown or hs == Enum.HumanoidStateType.Ragdoll then return true end
    end
    return false
end

local function ClearKnockedState()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _, attrName in ipairs(KNOCKED_ATTR_NAMES) do
        pcall(function() char:SetAttribute(attrName, false) end)
    end
    pcall(function() char:SetAttribute("State", "Alive") end)
    pcall(function() char:SetAttribute("Healing", true) end)
    pcall(function() char:SetAttribute("IsAlive", true) end)
    for _, child in ipairs(char:GetChildren()) do
        local n = child.Name:lower()
        if child:IsA("BoolValue") then
            for _, kw in ipairs({"knock","down","downed","dying","crawl","bleed"}) do
                if n:find(kw, 1, true) then pcall(function() child.Value = false end) end
            end
        end
    end
    local reviveRemotes = {R.Revive, R.GetUp, R.StandUp, R.Recovered}
    for _, rem in ipairs(reviveRemotes) do
        if rem then
            pcall(function()
                if rem:IsA("RemoteEvent") then
                    rem:FireServer(); rem:FireServer(LocalPlayer); rem:FireServer("Revived")
                elseif rem:IsA("RemoteFunction") then rem:InvokeServer() end
            end)
        end
    end
    if hum then
        pcall(function()
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Running, true)
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        pcall(function()
            if hum.Health < hum.MaxHealth * 0.5 then hum.Health = hum.MaxHealth end
        end)
        pcall(function() if hum.WalkSpeed < 8 then hum.WalkSpeed = 16 end end)
    end
end

--------------------------------------------------------------------------------
-- OBJECT FINDERS
--------------------------------------------------------------------------------
local Cache = {
    generators = {}, genDirty = true, pallets = {}, palDirty = true,
    vaults = {}, vaultDirty = true, exits = {}, exitDirty = true,
}

CM:Add(Workspace.DescendantAdded, function(d)
    if d:IsA("Model") then
        Cache.genDirty = true; Cache.palDirty = true
        Cache.vaultDirty = true; Cache.exitDirty = true
    end
end)
CM:Add(Workspace.DescendantRemoving, function(d)
    if d:IsA("Model") then
        Cache.genDirty = true; Cache.palDirty = true
        Cache.vaultDirty = true; Cache.exitDirty = true
    end
end)

local function FindAllGenerators()
    if not Cache.genDirty then return Cache.generators end
    local list = {}
    local map = Workspace:FindFirstChild("Map")
    if map then
        local gc = map:FindFirstChild("Generators")
        if gc then
            for _, g in ipairs(gc:GetChildren()) do
                if g:IsA("Model") then table.insert(list, g) end
            end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Generator" and v:GetAttribute("RepairProgress") ~= nil then
            local exists = false
            for _, e in ipairs(list) do if e == v then exists = true; break end end
            if not exists then table.insert(list, v) end
        end
    end
    Cache.generators = list; Cache.genDirty = false
    return list
end

local function GetPallets()
    if not Cache.palDirty then return Cache.pallets end
    local l = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "Palletwrong" or v.Name == "Pallet") then table.insert(l, v) end
    end
    Cache.pallets = l; Cache.palDirty = false
    return l
end

local function GetVaults()
    if not Cache.vaultDirty then return Cache.vaults end
    local l = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Window" then table.insert(l, v) end
    end
    Cache.vaults = l; Cache.vaultDirty = false
    return l
end

local function GetExits()
    if not Cache.exitDirty then return Cache.exits end
    local l = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "Gate" or v.Name == "ExitGate"
            or v.Name == "Exit" or v.Name:lower():find("gate")) then
            table.insert(l, v)
        end
    end
    Cache.exits = l; Cache.exitDirty = false
    return l
end

--------------------------------------------------------------------------------
-- ZOMBIE FINDER
--------------------------------------------------------------------------------
local ZOMBIE_KEYWORDS = {
    "infected","corpse","minion","cure","zombie","puppet","enemy","hostile",
    "npc","mob","clone","husk","walker","runner","shambler","victim","dummy","bot","spawn",
}
local ZOMBIE_FOLDER_NAMES = {
    "Clones","Zombies","NPCs","NPC","Enemies","Enemy","Cures","Cure","Minions","Minion",
    "Puppets","Infected","Mobs","AI","Bots","Dummies","SpawnedNPCs","Entities","Monsters",
}

local function IsRealPlayerModel(obj)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == obj then return true end
    end
    return false
end

local function HasRigBody(obj)
    if not obj:IsA("Model") then return false end
    if obj:FindFirstChildOfClass("Humanoid") then return true end
    if obj:FindFirstChild("HumanoidRootPart") then return true end
    if obj:FindFirstChild("HitBox") then return true end
    if obj:FindFirstChild("Torso") then return true end
    if obj:FindFirstChild("UpperTorso") then return true end
    if obj:FindFirstChild("Head") then return true end
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = d.Name
            if n == "HumanoidRootPart" or n == "HitBox" or n == "Torso"
                or n == "UpperTorso" or n == "Head" then return true end
        end
    end
    return false
end

local function IsZombieModel(obj)
    if not obj:IsA("Model") then return false end
    if IsRealPlayerModel(obj) then return false end
    if not HasRigBody(obj) then return false end
    local ok, isAttr = pcall(function()
        return obj:GetAttribute("IsCure") or obj:GetAttribute("IsMinion")
            or obj:GetAttribute("IsEnemy") or obj:GetAttribute("Enemy")
            or obj:GetAttribute("Zombie") or obj:GetAttribute("IsZombie")
            or obj:GetAttribute("IsNPC") or obj:GetAttribute("IsAI")
    end)
    if ok and isAttr then return true end
    local n = obj.Name:lower()
    for _, kw in ipairs(ZOMBIE_KEYWORDS) do
        if n:find(kw, 1, true) then return true end
    end
    local parent = obj.Parent
    while parent and parent ~= Workspace do
        local pn = parent.Name
        for _, folderName in ipairs(ZOMBIE_FOLDER_NAMES) do
            if pn == folderName or pn:lower():find(folderName:lower(), 1, true) then return true end
        end
        parent = parent.Parent
    end
    return false
end

local function GetZombies()
    local list = {}; local seen = {}
    for _, folderName in ipairs(ZOMBIE_FOLDER_NAMES) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") and not seen[obj]
                    and not IsRealPlayerModel(obj) and HasRigBody(obj) then
                    seen[obj] = true; table.insert(list, obj)
                end
            end
        end
    end
    local killersFolder = Workspace:FindFirstChild("Killers")
    if killersFolder then
        for _, obj in ipairs(killersFolder:GetDescendants()) do
            if obj:IsA("Model") and not seen[obj]
                and not IsRealPlayerModel(obj) and HasRigBody(obj) then
                seen[obj] = true; table.insert(list, obj)
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not seen[obj] and IsZombieModel(obj) then
            seen[obj] = true; table.insert(list, obj)
        end
    end
    return list
end

--------------------------------------------------------------------------------
-- KILLER DETECTION
--------------------------------------------------------------------------------
local function IsPlayerKiller(plr, character)
    if not plr then return false end
    character = character or plr.Character
    if character then
        local ok1, r1 = pcall(function()
            return tostring(character:GetAttribute("Role") or ""):lower():find("killer")
        end)
        if ok1 and r1 then return true end
        local ok2, r2 = pcall(function() return character:GetAttribute("IsKiller") == true end)
        if ok2 and r2 then return true end
    end
    local ok3, r3 = pcall(function()
        return tostring(plr:GetAttribute("Role") or ""):lower():find("killer")
    end)
    if ok3 and r3 then return true end
    local ok4, r4 = pcall(function() return plr:GetAttribute("IsKiller") == true end)
    if ok4 and r4 then return true end
    local ok5, r5 = pcall(function()
        local kf = Workspace:FindFirstChild("Killers")
        return kf and kf:FindFirstChild(plr.Name)
    end)
    if ok5 and r5 then return true end
    local ok6, r6 = pcall(function()
        return plr.Team and tostring(plr.Team.Name):lower():find("killer")
    end)
    if ok6 and r6 then return true end
    if character then
        for _, kn in ipairs({"Killer","JasonAI","MaskedAI","HiddenAI","StalkerAI","FrenzyAI"}) do
            if character:FindFirstChild(kn) then return true end
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local State = {
    ESP_Player = false, ESP_Zombie = false, ESP_HealthBar = true, ESP_Distance = true,
    ESP_Generator = false, ESP_Vault = false, ESP_Pallet = false, ESP_Exit = false,
    ESP_MaxDistance = 1500,
    Color_Player = Color3.fromRGB(60, 220, 60), Color_Killer = KILLER_RED,
    Color_Vault = Color3.fromRGB(180, 60, 220), Color_Pallet = Color3.fromRGB(255, 140, 20),
    Color_Zombie = Color3.fromRGB(255, 140, 20), Color_Exit = Color3.fromRGB(255, 255, 255),

    SkillCheckMode = "Off",
    CurrentRepairPoint = nil, CurrentRepairGen = nil,
    InstantLastFire = 0, InstantAnchorCF = nil, InstantBodyLock = false,
    InstantLastRepairAnim = 0,

    AutoGenRush = false, GenKillerRadius = 30, AutoGenMode = "Legit",
    AutoHeal = false, AutoHealThreshold = 60, LastHealTime = 0, HealCooldown = 1.2,

    AntiKnock = false, AutoReviveSelf = false, GenWhileKnocked = false,
    LastKnockedCheck = 0, WasKnocked = false,

    BypassGate = false,

    FastVault = false, NoFallDamage = false,
    WalkSpeedEnabled = false, WalkSpeedValue = 28, Invisible = false, UnlockCursor = false,

    AutoHit = false, AutoHitRange = 12, AutoHitAll = false, AutoHitAllDelay = 5,
    AutoDamageGen = false, InstantDamageGen = false, InstantBreakPallet = false,
    KillerWalkSpeedEnabled = false, KillerWalkSpeedValue = 30, NoStun = false, NoSlowdown = false,

    TeleportTarget = nil, AutoFollowTarget = nil, AutoFollowEnabled = false,
    AutoFollowOffset = Vector3.new(2, 0, 2),

    FullBright = true, NoFog = true, NoShadows = true, UnlimitedZoom = false,

    AimEnabled = false, AimConn = nil, AimRMBOnly = false, AimRMBConn = nil, AimRMBHeld = false,
    AimSmoothing = 0.5, AimFOV = 90, AimPart = "Head",
    AimShowFOV = false, AimFOVGui = nil, AimFOVCircle = nil,
    AimTeamCheck = false, AimMaxDistance = 200,

    Crosshair = false, CrosshairStyle = "Dot", CrosshairSize = 4,
    CrosshairColor = Color3.fromRGB(255, 50, 50), CrosshairGui = nil,

    FPSCounter = true, FPSGui = nil, FPSLabel = nil, FPSFrames = 0, FPSLastUpdate = 0,
    FPSValue = 0, FPSPingValue = 0, FPSCap = "None",

    AntiAFK = true, FPSBoost = false, Notifications = true,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    WalkSpeed = 16, ESPCache = {}, CurrentTargetGen = nil, UIOpen = true,
    InvisOriginalCF = nil, InvisVoidY = 9000,

    FloatingLogo = true, LogoGui = nil, LogoImage = nil,
    LogoSize = 60, LogoTransparency = 0.1, LogoInitialized = false,

    AutoParry = false, AutoParryRange = 15, ParryCircle = true, ParryCircleGui = nil,
    LastParryTime = 0, ParryCooldown = 90,
    ParryStats = { total = 0, success = 0, fail = 0 },
    KillerAnimHooked = false, LastHP = 100,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function() Fluent:Notify({ Title = tostring(t), Content = tostring(c), Duration = tonumber(d) or 3 }) end)
end
local function Char() return LocalPlayer.Character end
local function HRP() local c = Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum() local c = Char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function LerpColor(c1, c2, t)
    return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t)
end
local function GetGradientColor(pct)
    if pct <= 0.5 then return LerpColor(Color3.fromRGB(180,60,220), Color3.fromRGB(255,220,60), pct*2)
    else return LerpColor(Color3.fromRGB(255,220,60), Color3.fromRGB(60,220,60), (pct-0.5)*2) end
end
local function GetHealthColor(pct)
    if pct > 0.6 then return Color3.fromRGB(60, 220, 60)
    elseif pct > 0.3 then return Color3.fromRGB(255, 180, 60)
    else return Color3.fromRGB(255, 50, 50) end
end
local function GetAllOtherPlayers()
    local l = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character
            and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(l, p)
        end
    end
    return l
end
local function GetMyPos()
    if State.Invisible and State.InvisOriginalCF then
        return State.InvisOriginalCF.Position
    end
    local hrp = HRP()
    return hrp and hrp.Position or nil
end

--------------------------------------------------------------------------------
-- VISUALS
--------------------------------------------------------------------------------
local Vis, LB = {}, {}
function Vis.Backup()
    if next(LB) then return end
    LB = {
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        GlobalShadows = Lighting.GlobalShadows,
    }
end
function Vis.Restore()
    for k, v in pairs(LB) do pcall(function() Lighting[k] = v end) end
end
function Vis.ApplyFullBright()
    if not State.FullBright then return end
    pcall(function()
        Lighting.Ambient = Color3.new(1,1,1); Lighting.OutdoorAmbient = Color3.new(1,1,1)
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
    end)
end
function Vis.ApplyNoFog()
    if not State.NoFog then return end
    pcall(function() Lighting.FogEnd = 999999; Lighting.FogStart = 999999 end)
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
        end
    end
end
function Vis.ApplyNoShadows()
    if not State.NoShadows then return end
    pcall(function() Lighting.GlobalShadows = false end)
end
function Vis.ApplyAll()
    if State.FullBright then Vis.ApplyFullBright() end
    if State.NoFog then Vis.ApplyNoFog() end
    if State.NoShadows then Vis.ApplyNoShadows() end
end
function Vis.FullBright(e)
    Vis.Backup(); State.FullBright = e
    if e then Vis.ApplyFullBright() else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup(); State.NoFog = e
    if e then Vis.ApplyNoFog()
    else pcall(function() Lighting.FogEnd = LB.FogEnd or 100000 end) end
end
function Vis.NoShadows(e)
    Vis.Backup(); State.NoShadows = e
    pcall(function() Lighting.GlobalShadows = not e end)
end
function Vis.UnlimitedZoom(e)
    LocalPlayer.CameraMaxZoomDistance = e and math.huge or 128
    LocalPlayer.CameraMinZoomDistance = 0.5
end

CM:Add(Lighting.Changed, function(prop)
    if (prop == "FogEnd" or prop == "FogStart") and State.NoFog then Vis.ApplyNoFog()
    elseif prop == "GlobalShadows" and State.NoShadows then
        pcall(function() Lighting.GlobalShadows = false end)
    elseif (prop == "Ambient" or prop == "OutdoorAmbient"
        or prop == "Brightness" or prop == "ClockTime") and State.FullBright then
        Vis.ApplyFullBright()
    end
end)
CM:Add(Lighting.DescendantAdded, function(obj)
    task.wait(0.1)
    if obj:IsA("Atmosphere") and State.NoFog then
        pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
    end
end)
CM:Add(Workspace.ChildAdded, function(child)
    if child.Name == "Map" or child.Name == "Match" or child.Name == "Round" then
        task.wait(1); Vis.ApplyAll()
        Cache.genDirty = true; Cache.palDirty = true
        Cache.vaultDirty = true; Cache.exitDirty = true
    end
end)
task.spawn(function() while task.wait(1.5) do pcall(Vis.ApplyAll) end end)

--------------------------------------------------------------------------------
-- AIMBOT
--------------------------------------------------------------------------------
local function GetAimTarget()
    local hrp = HRP()
    if not hrp then return nil end
    local myPos = hrp.Position; local camCF = Camera.CFrame
    local bestTarget, bestAngle = nil, math.huge
    local fovRad = math.rad(State.AimFOV / 2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local teamOK = true
            if State.AimTeamCheck and p.Team and LocalPlayer.Team and p.Team == LocalPlayer.Team then teamOK = false end
            if teamOK then
                local targetPart = p.Character:FindFirstChild(State.AimPart)
                    or p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
                if targetPart then
                    local hum = p.Character:FindFirstChildOfClass("Humanoid")
                    if not (hum and hum.Health <= 0) then
                        local dist = (targetPart.Position - myPos).Magnitude
                        if dist <= State.AimMaxDistance then
                            local dir = (targetPart.Position - camCF.Position).Unit
                            local dot = camCF.LookVector:Dot(dir)
                            local angle = math.acos(math.clamp(dot, -1, 1))
                            if angle <= fovRad and angle < bestAngle then
                                bestAngle = angle; bestTarget = targetPart
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end
local function AimAtTarget(targetPart, dt)
    if not targetPart or not targetPart.Parent then return end
    local camPos = Camera.CFrame.Position
    local dir = (targetPart.Position - camPos).Unit
    local targetCF = CFrame.lookAt(camPos, camPos + dir)
    local alpha = 1 - (1 - math.clamp(State.AimSmoothing, 0.01, 1)) ^ (dt * 60)
    pcall(function() Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha) end)
end
local function SetAimbot(enable)
    State.AimEnabled = enable
    if State.AimConn then pcall(function() State.AimConn:Disconnect() end); State.AimConn = nil end
    if not enable then return end
    State.AimConn = RunService.RenderStepped:Connect(function(dt)
        if not State.AimEnabled or State.AimRMBOnly then return end
        local target = GetAimTarget()
        if target then AimAtTarget(target, dt) end
    end)
end
local function SetRMBAim(enable)
    State.AimRMBOnly = enable
    if State.AimRMBConn then pcall(function() State.AimRMBConn:Disconnect() end); State.AimRMBConn = nil end
    if not enable then return end
    CM:Add(UserInputService.InputBegan, function(input, gpe)
        if not gpe and input.UserInputType == Enum.UserInputType.MouseButton2 then State.AimRMBHeld = true end
    end)
    CM:Add(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then State.AimRMBHeld = false end
    end)
    State.AimRMBConn = RunService.RenderStepped:Connect(function(dt)
        if not State.AimRMBOnly or not State.AimRMBHeld then return end
        local target = GetAimTarget()
        if target then AimAtTarget(target, dt) end
    end)
end
local function DestroyAimFOV()
    if State.AimFOVGui then pcall(function() State.AimFOVGui:Destroy() end); State.AimFOVGui=nil; State.AimFOVCircle=nil end
end
local function BuildAimFOV()
    DestroyAimFOV()
    if not State.AimShowFOV then return end
    local sg = Instance.new("ScreenGui"); sg.Name="X0_AimFOV"; sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true; sg.DisplayOrder=995; sg.Parent=GuiParent()
    local vp = Camera.ViewportSize
    local radius = math.tan(math.rad(State.AimFOV/2)) * (vp.Y/2)
    local circle = Instance.new("Frame", sg)
    circle.Size = UDim2.new(0, radius*2, 0, radius*2)
    circle.Position = UDim2.new(0.5, -radius, 0.5, -radius)
    circle.BackgroundTransparency = 1; circle.BorderSizePixel = 0
    local stroke = Instance.new("UIStroke", circle); stroke.Color=Color3.fromRGB(255,255,255); stroke.Thickness=1; stroke.Transparency=0.5
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
    State.AimFOVGui = sg; State.AimFOVCircle = circle
end
task.spawn(function()
    while task.wait(0.5) do
        if State.AimShowFOV and State.AimFOVCircle then
            pcall(function()
                local vp = Camera.ViewportSize
                local r = math.tan(math.rad(State.AimFOV/2)) * (vp.Y/2)
                State.AimFOVCircle.Size = UDim2.new(0, r*2, 0, r*2)
                State.AimFOVCircle.Position = UDim2.new(0.5, -r, 0.5, -r)
            end)
        end
    end
end)

--------------------------------------------------------------------------------
-- CROSSHAIR
--------------------------------------------------------------------------------
local function DestroyCrosshair()
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end); State.CrosshairGui=nil end
end
local function BuildCrosshair()
    DestroyCrosshair()
    if not State.Crosshair then return end
    local sg = Instance.new("ScreenGui"); sg.Name="X0_Cross"; sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true; sg.DisplayOrder=997; sg.Parent=GuiParent()
    local col=State.CrosshairColor; local sz=State.CrosshairSize; local style=State.CrosshairStyle
    if style == "Dot" then
        local dot = Instance.new("Frame", sg)
        dot.Size=UDim2.new(0,sz,0,sz); dot.Position=UDim2.new(0.5,-sz/2,0.5,-sz/2)
        dot.BackgroundColor3=col; dot.BorderSizePixel=0
        Instance.new("UICorner", dot).CornerRadius=UDim.new(1,0)
    elseif style == "Cross" then
        local h=Instance.new("Frame",sg); h.Size=UDim2.new(0,sz*5,0,2); h.Position=UDim2.new(0.5,-sz*2.5,0.5,-1); h.BackgroundColor3=col; h.BorderSizePixel=0
        local v=Instance.new("Frame",sg); v.Size=UDim2.new(0,2,0,sz*5); v.Position=UDim2.new(0.5,-1,0.5,-sz*2.5); v.BackgroundColor3=col; v.BorderSizePixel=0
    elseif style == "Plus" then
        local gap,len,thick=sz,sz*3,2
        for _, cfg in ipairs({
            {sz=UDim2.new(0,thick,0,len), pos=UDim2.new(0.5,-thick/2,0.5,-(gap+len))},
            {sz=UDim2.new(0,thick,0,len), pos=UDim2.new(0.5,-thick/2,0.5,gap)},
            {sz=UDim2.new(0,len,0,thick), pos=UDim2.new(0.5,-(gap+len),0.5,-thick/2)},
            {sz=UDim2.new(0,len,0,thick), pos=UDim2.new(0.5,gap,0.5,-thick/2)},
        }) do
            local f=Instance.new("Frame",sg); f.Size=cfg.sz; f.Position=cfg.pos; f.BackgroundColor3=col; f.BorderSizePixel=0
        end
    elseif style == "Circle" then
        local c=Instance.new("Frame",sg); c.Size=UDim2.new(0,sz*4,0,sz*4); c.Position=UDim2.new(0.5,-sz*2,0.5,-sz*2); c.BackgroundTransparency=1; c.BorderSizePixel=0
        local stroke=Instance.new("UIStroke",c); stroke.Color=col; stroke.Thickness=2
        Instance.new("UICorner",c).CornerRadius=UDim.new(1,0)
        local dot=Instance.new("Frame",sg); dot.Size=UDim2.new(0,3,0,3); dot.Position=UDim2.new(0.5,-1.5,0.5,-1.5); dot.BackgroundColor3=col; dot.BorderSizePixel=0
        Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    end
    State.CrosshairGui = sg
end

--------------------------------------------------------------------------------
-- FPS PILL HUD
--------------------------------------------------------------------------------
local FPSCounter = {}
local function DestroyFPS()
    if State.FPSGui then pcall(function() State.FPSGui:Destroy() end) end
    State.FPSGui = nil; State.FPSLabel = nil
end
function FPSCounter.Build()
    DestroyFPS()
    local gp = GuiParent(); if not gp then return end
    local sg = Instance.new("ScreenGui"); sg.Name="X0_FPS"; sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true; sg.DisplayOrder=998; sg.Parent=gp
    local pill = Instance.new("Frame", sg)
    pill.Size=UDim2.new(0,105,0,20); pill.Position=UDim2.new(0,10,0,10)
    pill.BackgroundColor3=Color3.fromRGB(10,10,12); pill.BackgroundTransparency=0.15; pill.BorderSizePixel=0
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)
    local stroke=Instance.new("UIStroke",pill); stroke.Color=Color3.fromRGB(45,45,55); stroke.Thickness=1; stroke.Transparency=0.3
    local layout=Instance.new("UIListLayout",pill)
    layout.FillDirection=Enum.FillDirection.Horizontal
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    local fpsLbl=Instance.new("TextLabel",pill)
    fpsLbl.Size=UDim2.new(0,42,1,0); fpsLbl.BackgroundTransparency=1
    fpsLbl.Text="-- fps"; fpsLbl.TextColor3=Color3.fromRGB(255,90,90)
    fpsLbl.Font=Enum.Font.GothamBold; fpsLbl.TextSize=11
    fpsLbl.TextXAlignment=Enum.TextXAlignment.Right; fpsLbl.LayoutOrder=1
    local sep=Instance.new("TextLabel",pill)
    sep.Size=UDim2.new(0,12,1,0); sep.BackgroundTransparency=1
    sep.Text=" . "; sep.TextColor3=Color3.fromRGB(180,180,180)
    sep.Font=Enum.Font.GothamBold; sep.TextSize=11; sep.LayoutOrder=2
    local pingLbl=Instance.new("TextLabel",pill)
    pingLbl.Size=UDim2.new(0,46,1,0); pingLbl.BackgroundTransparency=1
    pingLbl.Text="-- ms"; pingLbl.TextColor3=Color3.fromRGB(120,240,120)
    pingLbl.Font=Enum.Font.GothamBold; pingLbl.TextSize=11
    pingLbl.TextXAlignment=Enum.TextXAlignment.Left; pingLbl.LayoutOrder=3
    local dragging,dragStart,startPos=false,Vector2.zero,UDim2.new()
    pill.Active=true
    pill.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=pill.Position
        end
    end)
    pill.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            pill.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    pill.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    State.FPSGui=sg; State.FPSLabel={fps=fpsLbl, ping=pingLbl}
end
local function GetPingMs()
    local ok, ping = pcall(function()
        return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    return ok and ping or 0
end
CM:Add(RunService.RenderStepped, function()
    if not State.FPSCounter or not State.FPSLabel then return end
    State.FPSFrames = State.FPSFrames + 1
    local now = tick()
    if now - State.FPSLastUpdate >= 0.5 then
        local elapsed = now - State.FPSLastUpdate
        State.FPSValue = math.floor(State.FPSFrames / elapsed)
        State.FPSFrames = 0; State.FPSLastUpdate = now
        State.FPSPingValue = GetPingMs()
        pcall(function()
            State.FPSLabel.fps.Text = State.FPSValue .. " fps"
            State.FPSLabel.fps.TextColor3 = State.FPSValue >= 55 and Color3.fromRGB(120,240,120)
                or (State.FPSValue >= 30 and Color3.fromRGB(255,210,100) or Color3.fromRGB(255,90,90))
            State.FPSLabel.ping.Text = State.FPSPingValue .. " ms"
            State.FPSLabel.ping.TextColor3 = State.FPSPingValue < 100 and Color3.fromRGB(120,240,120)
                or (State.FPSPingValue < 250 and Color3.fromRGB(255,210,100) or Color3.fromRGB(255,90,90))
        end)
    end
end)
function FPSCounter.SetVisible(v)
    State.FPSCounter = v
    if v then FPSCounter.Build() else DestroyFPS() end
end
local function SetFPSCap(val)
    State.FPSCap = val
    if val == "None" or val == "Unlimited" then
        if setfpscap then pcall(function() setfpscap(9999) end) end
        Notify("FPS Cap", "Unlimited", 2)
    else
        local num = tonumber(val)
        if num and setfpscap then pcall(function() setfpscap(num) end); Notify("FPS Cap", num.." FPS", 2)
        elseif not setfpscap then Notify("FPS Cap", "setfpscap not supported", 4) end
    end
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
            if c.Name == "X0_Logo" then pcall(function() c:Destroy() end) end
        end
    end
    State.LogoGui = nil; State.LogoImage = nil
end
function FloatingLogo.Build()
    DestroyLogo()
    local gp = GuiParent(); if not gp then return false end
    local sg = Instance.new("ScreenGui"); sg.Name="X0_Logo"; sg.ResetOnSpawn=false
    sg.IgnoreGuiInset=true; sg.DisplayOrder=999999; sg.Enabled=true
    local ok = pcall(function() sg.Parent = gp end)
    if not ok then pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end
    local size = State.LogoSize
    local img = Instance.new("ImageButton"); img.Name="Logo"
    img.Size=UDim2.new(0,size,0,size); img.Position=UDim2.new(0,20,0,100)
    img.BackgroundColor3=Color3.fromRGB(20,20,25); img.BackgroundTransparency=0.4; img.BorderSizePixel=0
    img.Image=HUB.LogoId; img.ImageTransparency=State.LogoTransparency
    img.ScaleType=Enum.ScaleType.Fit; img.AutoButtonColor=false
    img.Active=true; img.Selectable=true; img.Visible=true; img.ZIndex=100; img.Parent=sg
    Instance.new("UICorner",img).CornerRadius=UDim.new(0,10)
    local dragging,dragStart,startPos,dragMoved=false,Vector2.zero,UDim2.new(),false
    img.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=img.Position; dragMoved=false
        end
    end)
    img.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dragStart
            if d.Magnitude>4 then dragMoved=true end
            img.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    img.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end)
    img.MouseButton1Click:Connect(function()
        if dragMoved then return end
        pcall(function()
            local h = _G[INSTANCE_KEY]
            if h and h.window and h.window.Minimize then h.window:Minimize() end
        end)
    end)
    State.LogoGui=sg; State.LogoImage=img; State.LogoInitialized=true
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
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({HUB.LogoId}) end) end)

--------------------------------------------------------------------------------
-- ESP SYSTEM
--------------------------------------------------------------------------------
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name="X0_ESP"; ESPGui.ResetOnSpawn=false
    ESPGui.IgnoreGuiInset=true; ESPGui.DisplayOrder=999
    ESPGui.Parent=GuiParent()
end
local function GetRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj:FindFirstChild("HitBox") or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
            or obj:FindFirstChild("Head") or obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart", true)
    end
end
local function MakeEntry(obj, label, color, isChar, kind, hlOnly)
    local rp = GetRootPart(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency = isChar and 0.5 or 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = Workspace
    if hlOnly then
        return {rp=rp,obj=obj,hl=hl,bb=nil,nl=nil,dl=nil,hp=nil,isChar=isChar,color=color,kind=kind}
    end
    local bb = Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,200,0,isChar and 55 or 40)
    bb.StudsOffset=Vector3.new(0, isChar and 2.5 or 2, 0)
    bb.AlwaysOnTop=true; bb.LightInfluence=0
    bb.MaxDistance=State.ESP_MaxDistance; bb.Adornee=rp; bb.Parent=ESPGui
    Instance.new("UIListLayout",bb).HorizontalAlignment=Enum.HorizontalAlignment.Center
    local nl = Instance.new("TextLabel",bb)
    nl.Size=UDim2.new(1,0,0,18); nl.BackgroundTransparency=1
    nl.Text=label; nl.TextColor3=color; nl.TextStrokeTransparency=0.3
    nl.Font=Enum.Font.GothamBold; nl.TextSize=13
    local hp = nil
    if isChar then
        hp = Instance.new("TextLabel",bb)
        hp.Size=UDim2.new(1,0,0,14); hp.BackgroundTransparency=1
        hp.Text="[HP] ?"; hp.TextColor3=Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency=0.3; hp.Font=Enum.Font.GothamBold; hp.TextSize=12
    end
    local dl = Instance.new("TextLabel",bb)
    dl.Size=UDim2.new(1,0,0,12); dl.BackgroundTransparency=1
    dl.Text="0m"; dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency=0.3; dl.Font=Enum.Font.Gotham; dl.TextSize=11
    return {rp=rp,obj=obj,hl=hl,bb=bb,nl=nl,dl=dl,hp=hp,isChar=isChar,color=color,kind=kind}
end
function ESP.Add(obj, label, color, isChar, kind, hlOnly)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeEntry(obj, label, color, isChar or false, kind, hlOnly)
    if e then State.ESPCache[obj] = e end
end
function ESP.Remove(obj)
    local e = State.ESPCache[obj]; if not e then return end
    if e.hl then pcall(function() e.hl:Destroy() end) end
    if e.bb then pcall(function() e.bb:Destroy() end) end
    State.ESPCache[obj] = nil
end
function ESP.ClearAll()
    for o in pairs(State.ESPCache) do ESP.Remove(o) end
    State.ESPCache = {}
end
local ESPRender = RunService.RenderStepped:Connect(function()
    local refPos
    if State.Invisible and State.InvisOriginalCF then refPos = Camera.CFrame.Position
    else local hrp = HRP(); refPos = hrp and hrp.Position or Vector3.zero end
    local maxD = State.ESP_MaxDistance
    local rem = {}
    for obj, e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then table.insert(rem, obj)
        else
            local rp = GetRootPart(obj)
            if not rp then table.insert(rem, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function()
                        e.hl.Adornee = obj
                        if e.bb then e.bb.Adornee = rp end
                    end)
                end
                local dist = (rp.Position - refPos).Magnitude
                local vis = dist <= maxD
                pcall(function()
                    e.hl.Enabled = vis
                    if e.bb then
                        e.bb.MaxDistance = maxD; e.bb.Enabled = vis
                        if e.dl then e.dl.Text = math.floor(dist).."m"; e.dl.Visible = State.ESP_Distance end
                    end
                end)
                if e.isChar and e.hp then
                    pcall(function()
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h then
                            local hp = math.floor(h.Health); local mx = math.floor(h.MaxHealth)
                            local pct = (mx > 0) and hp/mx or 0
                            e.hp.Text = "[HP] "..hp.."/"..mx
                            e.hp.TextColor3 = GetHealthColor(pct); e.hp.Visible = State.ESP_HealthBar
                            if e.kind == "player" then
                                if e.isKiller then
                                    e.hl.FillColor = KILLER_RED; e.hl.OutlineColor = KILLER_RED
                                    if e.nl then e.nl.TextColor3 = KILLER_RED end
                                else
                                    local hc = GetHealthColor(pct)
                                    e.hl.FillColor = hc; e.hl.OutlineColor = hc
                                    if e.nl then e.nl.TextColor3 = hc end
                                end
                            end
                        end
                    end)
                end
                if e.kind == "generator" and obj:IsA("Model") and e.nl then
                    pcall(function()
                        local prog = obj:GetAttribute("RepairProgress") or 0
                        local col = GetGradientColor(prog / 100)
                        e.hl.FillColor = col; e.hl.OutlineColor = col
                        e.nl.TextColor3 = col
                        e.nl.Text = "[GEN] "..math.floor(prog).."%"
                    end)
                end
            end
        end
    end
    for _, o in ipairs(rem) do ESP.Remove(o) end
end)
function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            if State.ESP_Player then
                if not State.ESPCache[p.Character] then
                    local ik = IsPlayerKiller(p, p.Character)
                    local col = ik and KILLER_RED or State.Color_Player
                    local label = ik and ("[KILLER] "..p.Name) or ("["..p.Name.."]")
                    ESP.Add(p.Character, label, col, true, "player", false)
                    local entry = State.ESPCache[p.Character]
                    if entry then entry.isKiller = ik; entry.baseColor = col; entry.playerRef = p end
                end
            else
                if State.ESPCache[p.Character] then ESP.Remove(p.Character) end
            end
        end
    end
end
function ESP.ScanZombies()
    local z = GetZombies(); local m = {}
    for _, v in ipairs(z) do m[v] = true end
    for o in pairs(State.ESPCache) do
        if State.ESPCache[o] and State.ESPCache[o].kind == "zombie" and not m[o] then ESP.Remove(o) end
    end
    if not State.ESP_Zombie then
        for _, v in ipairs(z) do if State.ESPCache[v] then ESP.Remove(v) end end
        return
    end
    for _, v in ipairs(z) do
        if not State.ESPCache[v] then
            local label = "[CURE] "..v.Name
            local n = v.Name:lower()
            if n:find("minion",1,true) then label = "[MINION] "..v.Name
            elseif n:find("zombie",1,true) then label = "[ZOMBIE] "..v.Name
            elseif n:find("infected",1,true) then label = "[ZOMBIE] "..v.Name
            elseif n:find("puppet",1,true) then label = "[PUPPET] "..v.Name
            elseif n:find("enemy",1,true) then label = "[ENEMY] "..v.Name end
            ESP.Add(v, label, State.Color_Zombie, true, "zombie", false)
        end
    end
end
function ESP.ScanGens()
    local g = FindAllGenerators(); local m = {}
    for _, v in ipairs(g) do m[v] = true end
    for o in pairs(State.ESPCache) do
        if State.ESPCache[o] and State.ESPCache[o].kind == "generator" and not m[o] then ESP.Remove(o) end
    end
    for _, v in ipairs(g) do
        if State.ESP_Generator then
            if not State.ESPCache[v] then
                local p = v:GetAttribute("RepairProgress") or 0
                ESP.Add(v, "[GEN] "..math.floor(p).."%", GetGradientColor(p/100), false, "generator", false)
            end
        else
            if State.ESPCache[v] then ESP.Remove(v) end
        end
    end
end
function ESP.ScanPallets()
    local p = GetPallets(); local m = {}
    for _, v in ipairs(p) do m[v] = true end
    for o in pairs(State.ESPCache) do
        if State.ESPCache[o] and State.ESPCache[o].kind == "pallet" and not m[o] then ESP.Remove(o) end
    end
    for _, v in ipairs(p) do
        if State.ESP_Pallet then
            if not State.ESPCache[v] then ESP.Add(v, "", State.Color_Pallet, false, "pallet", true) end
        else
            if State.ESPCache[v] then ESP.Remove(v) end
        end
    end
end
function ESP.ScanVaults()
    local w = GetVaults(); local m = {}
    for _, v in ipairs(w) do m[v] = true end
    for o in pairs(State.ESPCache) do
        if State.ESPCache[o] and State.ESPCache[o].kind == "vault" and not m[o] then ESP.Remove(o) end
    end
    for _, v in ipairs(w) do
        if State.ESP_Vault then
            if not State.ESPCache[v] then ESP.Add(v, "", State.Color_Vault, false, "vault", true) end
        else
            if State.ESPCache[v] then ESP.Remove(v) end
        end
    end
end
function ESP.ScanExits()
    local e = GetExits(); local m = {}
    for _, v in ipairs(e) do m[v] = true end
    for o in pairs(State.ESPCache) do
        if State.ESPCache[o] and State.ESPCache[o].kind == "exit" and not m[o] then ESP.Remove(o) end
    end
    for _, v in ipairs(e) do
        if State.ESP_Exit then
            if not State.ESPCache[v] then ESP.Add(v, "", State.Color_Exit, false, "exit", true) end
        else
            if State.ESPCache[v] then ESP.Remove(v) end
        end
    end
end
function ESP.RefreshAll()
    ESP.ScanPlayers(); ESP.ScanZombies()
    ESP.ScanGens(); ESP.ScanPallets()
    ESP.ScanVaults(); ESP.ScanExits()
end
task.spawn(function()
    while task.wait(0.5) do if State.ESP_Zombie then pcall(ESP.ScanZombies) end end
end)
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            for obj, entry in pairs(State.ESPCache) do
                if entry.kind == "player" and obj.Parent then
                    local plr = entry.playerRef
                    if not plr or plr.Character ~= obj then
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Character == obj then plr = p; break end
                        end
                        entry.playerRef = plr
                    end
                    if plr then
                        local nk = IsPlayerKiller(plr, obj)
                        if nk ~= entry.isKiller then
                            entry.isKiller = nk
                            if entry.nl then
                                entry.nl.Text = nk and ("[KILLER] "..plr.Name) or ("["..plr.Name.."]")
                            end
                        end
                    end
                end
            end
            ESP.RefreshAll()
        end)
    end
end)
CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Remove(p.Character) end
end)
local function HookPlayer(p)
    if p == LocalPlayer then return end
    CM:Add(p.CharacterAdded, function() task.wait(0.5); ESP.RefreshAll() end)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c) end)
end
for _, p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
CM:Add(Players.PlayerAdded, HookPlayer)

--------------------------------------------------------------------------------
-- ANTI-KNOCK
--------------------------------------------------------------------------------
local AntiKnockConn = nil
local function SetAntiKnock(enable)
    if AntiKnockConn then pcall(function() AntiKnockConn:Disconnect() end); AntiKnockConn = nil end
    if not enable then State.AntiKnock = false; return end
    State.AntiKnock = true
    AntiKnockConn = RunService.Heartbeat:Connect(function()
        if not State.AntiKnock then return end
        local now = tick()
        if now - State.LastKnockedCheck < 0.25 then return end
        State.LastKnockedCheck = now
        local knocked = IsKnocked()
        if knocked and not State.WasKnocked then
            State.WasKnocked = true
            pcall(ClearKnockedState)
            Notify("Anti-Knock", "Knocked! Auto-clearing...", 2)
        elseif knocked then
            pcall(ClearKnockedState)
        elseif not knocked and State.WasKnocked then
            State.WasKnocked = false
        end
    end)
end

--------------------------------------------------------------------------------
-- HEAL SYSTEM
--------------------------------------------------------------------------------
local function FireHealRemotes()
    local char = LocalPlayer.Character
    if not char then return end
    if IsKnocked() then ClearKnockedState(); task.wait(0.05) end
    local rems = {R.Heal, R.HealCommit, R.HealSelf, R.HealPlayer, R.HealStart, R.HealFinish, R.MedKit}
    for _, rem in ipairs(rems) do
        if rem then
            pcall(function()
                if rem:IsA("RemoteEvent") then
                    rem:FireServer(); rem:FireServer(LocalPlayer); rem:FireServer("Perfect")
                elseif rem:IsA("RemoteFunction") then rem:InvokeServer() end
            end)
        end
    end
    if R.HealResult then pcall(function() R.HealResult:FireServer("Perfect") end) end
    local adren = {R.AdrenalineHealthy, R.AdrenalineInject, R.AdrenalineUse}
    for _, rem in ipairs(adren) do
        if rem then pcall(function() if rem:IsA("RemoteEvent") then rem:FireServer() end end) end
    end
    pcall(function() char:SetAttribute("Healing", true) end)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health < hum.MaxHealth then pcall(function() hum.Health = hum.MaxHealth end) end
end
local AutoHealConn = nil
local function SetAutoHeal(e)
    if AutoHealConn then pcall(function() AutoHealConn:Disconnect() end); AutoHealConn = nil end
    if not e then return end
    AutoHealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        local c = Char(); if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return end
        local pct = (h.MaxHealth > 0) and (h.Health/h.MaxHealth*100) or 100
        if pct >= State.AutoHealThreshold then return end
        if tick() - State.LastHealTime < State.HealCooldown then return end
        State.LastHealTime = tick()
        pcall(FireHealRemotes)
    end)
end
local function ForceHealNow()
    pcall(FireHealRemotes)
    local h = Hum()
    if h then pcall(function() h.Health = h.MaxHealth end) end
    Notify("Heal", "Forced", 2)
end

--══════════════════════════════════════════════════════════════════════════════
-- SKILL CHECK SYSTEM (3 modes: Off/Legit/Fast/Instant, auto-detect gen)
--══════════════════════════════════════════════════════════════════════════════
local function SetSkillCheckGuiVisible(visible)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, gui in ipairs(pg:GetChildren()) do
        local n = gui.Name:lower()
        if n:find("skillcheck") then
            pcall(function() gui.Enabled = visible end)
        end
    end
end

local function FirePerfectSkillCheck(gen, point)
    if not R.Gen.SkillCheckResult then return end
    pcall(function() R.Gen.SkillCheckResult:FireServer("success", 1, gen, point) end)
    if R.Gen.SkillCheckValidated then
        pcall(function() R.Gen.SkillCheckValidated:FireServer(gen, point) end)
    end
end

local function ReleaseInstantLock()
    if State.CurrentRepairPoint and R.Gen.RepairEvent then
        pcall(function()
            R.Gen.RepairEvent:FireServer(State.CurrentRepairPoint, false, 1.5)
        end)
    end
    State.CurrentRepairGen = nil
    State.CurrentRepairPoint = nil
    State.InstantAnchorCF = nil
    State.InstantBodyLock = false
    local hrp = HRP()
    if hrp then pcall(function() hrp.Anchored = false end) end
end

local skillCheckHooked = false
local function HookSkillCheckAutoPerfect()
    if skillCheckHooked then return end
    if not R.Gen.SkillCheckEvent then return end
    skillCheckHooked = true
    CM:Add(R.Gen.SkillCheckEvent.OnClientEvent, function(gen, point)
        if State.SkillCheckMode == "Off" then return end
        State.CurrentRepairGen = gen
        State.CurrentRepairPoint = point
        if State.SkillCheckMode == "Fast" then
            SetSkillCheckGuiVisible(false)
        end
        local delay = State.SkillCheckMode == "Fast" and 0.05
            or (State.SkillCheckMode == "Instant" and 0.02 or 0.15)
        task.delay(delay, function()
            FirePerfectSkillCheck(gen, point)
            if State.SkillCheckMode == "Fast" then
                task.wait(0.3)
                SetSkillCheckGuiVisible(true)
            end
        end)
    end)
    Log("[SkillCheck] Auto-perfect hook installed")
end

local repairAnimHooked = false
local function HookRepairAnimTracking()
    if repairAnimHooked then return end
    if not R.Gen.RepairAnim then return end
    repairAnimHooked = true
    CM:Add(R.Gen.RepairAnim.OnClientEvent, function(cf, isRepairing, point, animId, isBreak)
        if typeof(point) ~= "Instance" or typeof(isRepairing) ~= "boolean" then return end
        if isRepairing then
            State.CurrentRepairPoint = point
            State.CurrentRepairGen = point.Parent
            State.InstantLastRepairAnim = tick()
            if State.SkillCheckMode == "Instant" and typeof(cf) == "CFrame" then
                State.InstantAnchorCF = cf
                State.InstantBodyLock = true
                Notify("Instant", "Locked "..point.Parent.Name.." @ "..point.Name, 2)
            end
        end
    end)
end

local InstantRepairConn = nil
local function StartInstantMode()
    if InstantRepairConn then pcall(function() InstantRepairConn:Disconnect() end); InstantRepairConn = nil end
    InstantRepairConn = RunService.Heartbeat:Connect(function()
        if State.SkillCheckMode ~= "Instant" then return end
        if not R.Gen.RepairEvent then return end
        if not State.CurrentRepairPoint or not State.CurrentRepairGen then return end
        local now = tick()
        if now - State.InstantLastFire < 0.1 then return end
        State.InstantLastFire = now
        if not State.CurrentRepairGen.Parent then
            Notify("Instant", "Generator gone", 2)
            ReleaseInstantLock()
            return
        end
        local ok, prog = pcall(function() return State.CurrentRepairGen:GetAttribute("RepairProgress") or 0 end)
        if not ok then prog = 0 end
        if prog >= 100 then
            Notify("Instant", "Generator done! ("..State.CurrentRepairGen.Name..")", 3)
            ReleaseInstantLock()
            return
        end
        local hb = State.CurrentRepairGen:FindFirstChild("HitBox")
            or State.CurrentRepairGen:FindFirstChildWhichIsA("BasePart")
        local killerNear = false
        if hb then
            for _, p in ipairs(GetAllOtherPlayers()) do
                if IsPlayerKiller(p, p.Character) then
                    local pc = p.Character
                    if pc then
                        local ph = pc:FindFirstChild("HumanoidRootPart")
                        if ph and (ph.Position - hb.Position).Magnitude <= State.GenKillerRadius then
                            killerNear = true; break
                        end
                    end
                end
            end
        end
        if killerNear then return end
        pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentRepairPoint, true) end)
        pcall(function() R.Gen.SkillCheckResult:FireServer("success", 1, State.CurrentRepairGen, State.CurrentRepairPoint) end)
    end)
end

local BodyAnchorConn = nil
local function StartBodyAnchor()
    if BodyAnchorConn then pcall(function() BodyAnchorConn:Disconnect() end); BodyAnchorConn = nil end
    BodyAnchorConn = RunService.Heartbeat:Connect(function()
        if State.SkillCheckMode ~= "Instant" then return end
        if not State.InstantBodyLock or not State.InstantAnchorCF then return end
        local hrp = HRP()
        if not hrp then return end
        local dist = (hrp.Position - State.InstantAnchorCF.Position).Magnitude
        if dist > 3 then
            pcall(function() hrp.CFrame = State.InstantAnchorCF end)
        end
    end)
end
local function StopBodyAnchor()
    if BodyAnchorConn then pcall(function() BodyAnchorConn:Disconnect() end); BodyAnchorConn = nil end
    local hrp = HRP()
    if hrp then pcall(function() hrp.Anchored = false end) end
end

local function SetSkillCheckMode(mode)
    if State.SkillCheckMode == "Instant" and mode ~= "Instant" then
        ReleaseInstantLock()
        StopBodyAnchor()
    end
    State.SkillCheckMode = mode
    HookSkillCheckAutoPerfect()
    HookRepairAnimTracking()
    if mode == "Off" then
        if InstantRepairConn then pcall(function() InstantRepairConn:Disconnect() end); InstantRepairConn = nil end
        SetSkillCheckGuiVisible(true)
        Notify("Skill Check", "Disabled", 2)
    elseif mode == "Instant" then
        StartInstantMode()
        StartBodyAnchor()
        Notify("Skill Check", "INSTANT - walk to gen and repair, then walk away", 4)
    elseif mode == "Fast" then
        if InstantRepairConn then pcall(function() InstantRepairConn:Disconnect() end); InstantRepairConn = nil end
        Notify("Skill Check", "FAST - hides GUI + auto-perfect", 3)
    elseif mode == "Legit" then
        if InstantRepairConn then pcall(function() InstantRepairConn:Disconnect() end); InstantRepairConn = nil end
        SetSkillCheckGuiVisible(true)
        Notify("Skill Check", "LEGIT - normal repair + auto-perfect", 3)
    end
end

task.spawn(function()
    task.wait(1)
    HookSkillCheckAutoPerfect()
    HookRepairAnimTracking()
end)

--------------------------------------------------------------------------------
-- AUTO GEN RUSH
--------------------------------------------------------------------------------
local function SetAutoGenRush(enable)
    if not enable then return end
    if not R.Gen.RepairEvent then
        Notify("Auto Gen", "Missing remote", 4)
        State.AutoGenRush = false
        return
    end
    task.spawn(function()
        while State.AutoGenRush do
            task.wait(0.25)
            local myPos = GetMyPos()
            if myPos then
                local knocked = IsKnocked()
                local canProceed = true
                if knocked and not State.GenWhileKnocked then canProceed = false end
                if canProceed then
                    local killerNear = false
                    if not knocked then
                        for _, p in ipairs(GetAllOtherPlayers()) do
                            if IsPlayerKiller(p, p.Character) then
                                local pc = p.Character
                                if pc then
                                    local ph = pc:FindFirstChild("HumanoidRootPart")
                                    if ph and (ph.Position - myPos).Magnitude <= State.GenKillerRadius then
                                        State.CurrentTargetGen = nil
                                        killerNear = true; break
                                    end
                                end
                            end
                        end
                    end
                    if not killerNear then
                        if State.CurrentTargetGen then
                            local ok1, prog = pcall(function()
                                return State.CurrentTargetGen:GetAttribute("RepairProgress") or 0
                            end)
                            if not ok1 then prog = 0 end
                            local ok2, parentExists = pcall(function()
                                return State.CurrentTargetGen.Parent ~= nil
                            end)
                            if not ok2 then parentExists = false end
                            if prog >= 100 or not parentExists then
                                State.CurrentTargetGen = nil
                            end
                        end
                        if not State.CurrentTargetGen then
                            local best, bestD = nil, math.huge
                            for _, g in ipairs(FindAllGenerators()) do
                                local prog = g:GetAttribute("RepairProgress") or 0
                                if prog < 100 then
                                    local hb = g:FindFirstChild("HitBox")
                                        or g:FindFirstChildWhichIsA("BasePart")
                                    if hb then
                                        local d = (hb.Position - myPos).Magnitude
                                        if d < bestD then bestD = d; best = g end
                                    end
                                end
                            end
                            State.CurrentTargetGen = best
                        end
                        if State.CurrentTargetGen then
                            local hb = nil
                            pcall(function()
                                hb = State.CurrentTargetGen:FindFirstChild("HitBox")
                                    or State.CurrentTargetGen:FindFirstChildWhichIsA("BasePart")
                            end)
                            if hb then
                                local distToGen = (hb.Position - myPos).Magnitude
                                if knocked and State.GenWhileKnocked then
                                    local char = Char()
                                    if char then
                                        for _, attrName in ipairs(KNOCKED_ATTR_NAMES) do
                                            pcall(function() char:SetAttribute(attrName, false) end)
                                        end
                                        pcall(function() char:SetAttribute("State", "Alive") end)
                                    end
                                end
                                if distToGen <= 8 or (knocked and State.GenWhileKnocked) then
                                    local pt = State.CurrentTargetGen:FindFirstChild("GeneratorPoint1")
                                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")
                                    if pt then
                                        pcall(function() R.Gen.RepairEvent:FireServer(pt, true) end)
                                        pcall(function()
                                            R.Gen.SkillCheckResult:FireServer("success", 1, State.CurrentTargetGen, pt)
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        State.CurrentTargetGen = nil
    end)
end

--------------------------------------------------------------------------------
-- BYPASS EXIT GATE
--------------------------------------------------------------------------------
local GATE_OPEN_ATTRS = {"Open","Opened","IsOpen","Activated","Powered","Unlocked","GateOpen","Complete","Finished"}
local function ForceOpenGate(gate)
    if not gate or not gate.Parent then return end
    for _, attr in ipairs(GATE_OPEN_ATTRS) do
        pcall(function() gate:SetAttribute(attr, true) end)
    end
    if R.GateOpen then
        pcall(function()
            if R.GateOpen:IsA("RemoteEvent") then
                R.GateOpen:FireServer(gate); R.GateOpen:FireServer(gate, true)
            elseif R.GateOpen:IsA("RemoteFunction") then
                R.GateOpen:InvokeServer(gate)
            end
        end)
    end
    if R.GateEscape then
        pcall(function()
            if R.GateEscape:IsA("RemoteEvent") then R.GateEscape:FireServer(gate) end
        end)
    end
    for _, child in ipairs(gate:GetDescendants()) do
        if child:IsA("BasePart") then
            local n = child.Name:lower()
            if n:find("barrier",1,true) or n:find("block",1,true)
                or n:find("wall",1,true) or n:find("door",1,true) then
                pcall(function() child.CanCollide = false; child.Transparency = 1 end)
            end
        end
    end
end
local BypassGateConn = nil
local function SetBypassGate(enable)
    if BypassGateConn then pcall(function() BypassGateConn:Disconnect() end); BypassGateConn = nil end
    if not enable then State.BypassGate = false; return end
    State.BypassGate = true
    local last = 0
    BypassGateConn = RunService.Heartbeat:Connect(function()
        if not State.BypassGate then return end
        local now = tick()
        if now - last < 0.5 then return end
        last = now
        for _, gate in ipairs(GetExits()) do ForceOpenGate(gate) end
    end)
    Notify("Bypass Gate", "Forcing all exit gates open", 3)
end
local function TeleportToNearestGate()
    local hrp = HRP(); if not hrp then Notify("Gate", "No character", 2); return end
    local gates = GetExits()
    if #gates == 0 then Notify("Gate", "No gates found", 3); return end
    local best, bestD = nil, math.huge
    for _, gate in ipairs(gates) do
        local part = gate:FindFirstChildWhichIsA("BasePart", true)
        if part then
            local d = (part.Position - hrp.Position).Magnitude
            if d < bestD then bestD = d; best = part end
        end
    end
    if best then
        local dest = best.CFrame + Vector3.new(0, 3, 0)
        if State.Invisible then
            State.InvisOriginalCF = dest
            pcall(function() hrp.CFrame = dest end)
            task.delay(0.05, function()
                if State.Invisible then pcall(function() hrp.CFrame = CFrame.new(0, State.InvisVoidY, 0) end) end
            end)
        else pcall(function() hrp.CFrame = dest end) end
        Notify("Gate", string.format("Teleported (%.0fm)", bestD), 2)
    end
end
local function ForceEscape()
    if R.GateEscape then
        pcall(function()
            if R.GateEscape:IsA("RemoteEvent") then
                R.GateEscape:FireServer(); R.GateEscape:FireServer(LocalPlayer)
            end
        end)
    end
    local char = Char()
    if char then
        pcall(function() char:SetAttribute("Escaped", true) end)
        pcall(function() char:SetAttribute("Survived", true) end)
    end
    Notify("Gate", "Escape signal sent", 2)
end

--------------------------------------------------------------------------------
-- MOVEMENT / MISC
--------------------------------------------------------------------------------
local AutoFollowConn = nil
local function GetPlayerNames()
    local n = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(n, p.Name) end
    end
    if #n == 0 then table.insert(n, "None") end
    return n
end
local function FindPlayerByName(name)
    if not name or name == "None" then return nil end
    return Players:FindFirstChild(name)
end
local function TeleportToPlayer(target, offset)
    if not target then return false end
    local p = FindPlayerByName(target)
    if not p or not p.Character then return false end
    local prp = p.Character:FindFirstChild("HumanoidRootPart")
    if not prp then return false end
    local hrp = HRP(); if not hrp then return false end
    local dest = prp.CFrame + (offset or Vector3.zero)
    if State.Invisible then
        State.InvisOriginalCF = dest
        pcall(function() hrp.CFrame = dest end)
        task.delay(0.05, function()
            if State.Invisible then pcall(function() hrp.CFrame = CFrame.new(0, State.InvisVoidY, 0) end) end
        end)
    else pcall(function() hrp.CFrame = dest end) end
    return true
end
local function SetAutoFollow(enable)
    if AutoFollowConn then pcall(function() AutoFollowConn:Disconnect() end); AutoFollowConn = nil end
    if not enable then State.AutoFollowEnabled = false; return end
    State.AutoFollowEnabled = true
    local last = 0
    AutoFollowConn = RunService.Heartbeat:Connect(function()
        if not State.AutoFollowEnabled or not State.AutoFollowTarget then return end
        if tick() - last < 0.1 then return end
        last = tick()
        pcall(TeleportToPlayer, State.AutoFollowTarget, State.AutoFollowOffset)
    end)
end
local function SetWalkSpeed(e)
    local h = Hum()
    if h then h.WalkSpeed = e and State.WalkSpeedValue or State.WalkSpeed end
end
local function SetKillerWalkSpeed(e)
    local h = Hum()
    if h then h.WalkSpeed = e and State.KillerWalkSpeedValue or State.WalkSpeed end
end
local function SetNoFall(e)
    local c = Char(); if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not e)
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not e)
    end)
end

local InvisHB, InvisRS, InvisMV = nil, nil, nil
local VOID_Y = 9000
local InvisCam = { pitch = 0, yaw = 0 }
local function DisconnectInvis()
    if InvisHB then pcall(function() InvisHB:Disconnect() end); InvisHB = nil end
    if InvisRS then pcall(function() InvisRS:Disconnect() end); InvisRS = nil end
    if InvisMV then pcall(function() InvisMV:Disconnect() end); InvisMV = nil end
end
local function SetInvisible(enable)
    DisconnectInvis()
    local char, hrp, hum = Char(), HRP(), Hum()
    if not enable then
        State.Invisible = false
        if State.InvisOriginalCF and hrp then
            pcall(function() hrp.Anchored = false; hrp.CFrame = State.InvisOriginalCF end)
        end
        State.InvisOriginalCF = nil
        pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                for _, g in ipairs(head:GetChildren()) do
                    if g:IsA("BillboardGui") then pcall(function() g.Enabled = true end) end
                end
            end
        end
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end)
        end
        return
    end
    if not char or not hrp or not hum then State.Invisible = false; return end
    State.Invisible = true
    State.InvisOriginalCF = hrp.CFrame
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    end)
    local head = char:FindFirstChild("Head")
    if head then
        for _, g in ipairs(head:GetChildren()) do
            if g:IsA("BillboardGui") then pcall(function() g.Enabled = false end) end
        end
    end
    local lv = Camera.CFrame.LookVector
    InvisCam.pitch = math.asin(math.clamp(-lv.Y, -1, 1))
    InvisCam.yaw = math.atan2(-lv.X, -lv.Z)
    pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
    pcall(function() hrp.CFrame = CFrame.new(0, VOID_Y, 0) end)
    InvisRS = RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end
        pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
        local d = UserInputService:GetMouseDelta()
        InvisCam.yaw = InvisCam.yaw - math.rad(d.X * 0.35)
        InvisCam.pitch = math.clamp(InvisCam.pitch - math.rad(d.Y * 0.35), math.rad(-80), math.rad(80))
        if State.InvisOriginalCF then
            pcall(function()
                Camera.CFrame = CFrame.new(State.InvisOriginalCF.Position + Vector3.new(0, 1.5, 0))
                    * CFrame.Angles(0, InvisCam.yaw, 0) * CFrame.Angles(InvisCam.pitch, 0, 0)
            end)
        end
    end)
    InvisMV = RunService.Heartbeat:Connect(function(dt)
        if not State.Invisible or not State.InvisOriginalCF or IsTyping() then return end
        local spd = State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed
        local md = Vector3.zero; local vertMove = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md = md + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md = md + Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md = md + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md = md + Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vertMove = vertMove + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then vertMove = vertMove - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then vertMove = vertMove + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then vertMove = vertMove - 1 end
        local cur = State.InvisOriginalCF.Position
        local newX, newY, newZ = cur.X, cur.Y, cur.Z
        if md.Magnitude > 0.1 then
            md = md.Unit
            local wd = CFrame.Angles(0, InvisCam.yaw, 0) * md
            local nxt = cur + wd * spd * dt
            newX = nxt.X; newZ = nxt.Z
        end
        if vertMove ~= 0 then newY = cur.Y + vertMove * spd * dt end
        State.InvisOriginalCF = CFrame.new(Vector3.new(newX, newY, newZ)) * CFrame.Angles(0, InvisCam.yaw, 0)
    end)
end

local UnlockCursorConn = nil
local function SetUnlockCursor(e)
    if UnlockCursorConn then pcall(function() UnlockCursorConn:Disconnect() end); UnlockCursorConn = nil end
    if not e then return end
    UnlockCursorConn = RunService.RenderStepped:Connect(function()
        if State.UnlockCursor then
            pcall(function()
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        end
    end)
end

local function FireHit(target)
    local ch = target and target.Character; if not ch then return end
    if R.Attacks.Basic then pcall(function() R.Attacks.Basic:FireServer(target, ch) end) end
    if R.Attacks.Hit then pcall(function() R.Attacks.Hit:FireServer(target, ch) end) end
    if R.AttackEvent then pcall(function() R.AttackEvent:FireServer(target) end) end
    if R.KingScourge then pcall(function() R.KingScourge:FireServer(target) end) end
    if R.Killers.Frenzy then pcall(function() R.Killers.Frenzy:FireServer(target) end) end
    if R.Killers.Masked then pcall(function() R.Killers.Masked:FireServer(target) end) end
    if R.Killers.SlowAttack then pcall(function() R.Killers.SlowAttack:FireServer(target) end) end
    if R.Killers.CureInject then pcall(function() R.Killers.CureInject:FireServer(target) end) end
end

local AutoHitConn = nil
local function SetAutoHit(e)
    if AutoHitConn then pcall(function() AutoHitConn:Disconnect() end); AutoHitConn = nil end
    if not e then return end
    local last = 0
    AutoHitConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHit or tick() - last < 0.3 then return end
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(GetAllOtherPlayers()) do
            local ep = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if ep and (ep.Position - hrp.Position).Magnitude <= State.AutoHitRange then
                last = tick(); FireHit(p)
            end
        end
    end)
end
local AutoHitAllConn = nil
local function SetAutoHitAll(e)
    if AutoHitAllConn then pcall(function() AutoHitAllConn:Disconnect() end); AutoHitAllConn = nil end
    if not e then return end
    local last = 0
    AutoHitAllConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHitAll or tick() - last < State.AutoHitAllDelay then return end
        last = tick()
        for _, p in ipairs(GetAllOtherPlayers()) do pcall(FireHit, p) end
    end)
end
local AutoDamageGenConn = nil
local function SetAutoDamageGen(e)
    if AutoDamageGenConn then pcall(function() AutoDamageGenConn:Disconnect() end); AutoDamageGenConn = nil end
    if not e then return end
    AutoDamageGenConn = RunService.Heartbeat:Connect(function()
        if not State.AutoDamageGen then return end
        task.wait(0.3)
        local hrp = HRP(); if not hrp then return end
        for _, g in ipairs(FindAllGenerators()) do
            local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
            if hb and (hb.Position - hrp.Position).Magnitude <= 15 then
                if State.InstantDamageGen then
                    pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0) end)
                end
                if R.Gen.BreakEvent then pcall(function() R.Gen.BreakEvent:FireServer(g) end) end
                if R.Gen.BreakCommit then pcall(function() R.Gen.BreakCommit:FireServer(g) end) end
            end
        end
    end)
end
local InstPalletConn = nil
local function SetInstantBreakPallet(e)
    if InstPalletConn then InstPalletConn:Disconnect(); InstPalletConn = nil end
    if not e then return end
    InstPalletConn = RunService.Heartbeat:Connect(function()
        if not State.InstantBreakPallet then return end
        task.wait(0.2)
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(GetPallets()) do
            local pt = p:FindFirstChildWhichIsA("BasePart")
            if pt and (pt.Position - hrp.Position).Magnitude <= 12 then
                if R.Pallet.BreakCommit then pcall(function() R.Pallet.BreakCommit:FireServer(p) end) end
                if R.Pallet.DropCommit then pcall(function() R.Pallet.DropCommit:FireServer(p) end) end
            end
        end
    end)
end
local NoStunConn = nil
local function SetNoStun(e)
    if NoStunConn then pcall(function() NoStunConn:Disconnect() end); NoStunConn = nil end
    if not e then return end
    NoStunConn = RunService.Heartbeat:Connect(function()
        if not State.NoStun then return end
        local c = Char()
        if c then
            pcall(function() c:SetAttribute("Knocked", false) end)
            if R.Pallet.Stunover then pcall(function() R.Pallet.Stunover:FireServer() end) end
        end
    end)
end
local NoSlowConn = nil
local function SetNoSlowdown(e)
    if NoSlowConn then pcall(function() NoSlowConn:Disconnect() end); NoSlowConn = nil end
    if not e then return end
    NoSlowConn = RunService.Heartbeat:Connect(function()
        if not State.NoSlowdown then return end
        local h = Hum(); if not h then return end
        local t = State.KillerWalkSpeedEnabled and State.KillerWalkSpeedValue
            or (State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed)
        if h.WalkSpeed < t - 2 then pcall(function() h.WalkSpeed = t end) end
    end)
end
local function SetFPSBoost(e)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
            pcall(function() v.Enabled = not e end)
        end
    end
    pcall(function()
        settings().Rendering.QualityLevel = e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end
local function SetFastVault(e)
    local ch = Char()
    if ch then pcall(function() ch:SetAttribute("vaultspeed", e and 5 or 1) end) end
end

--══════════════════════════════════════════════════════════════════════════════
-- AUTO PARRY v2 - Uses parryResult listener + reliable RMB trigger
--══════════════════════════════════════════════════════════════════════════════
local ATTACK_ANIM_WHITELIST = {
    ["110355011987939"] = { name = "Attack1" },
    ["139369275981139"] = { name = "Attack2" },
    ["85030641905220"]  = { name = "Attack3" },
    ["102055678391920"] = { name = "Attack4" },
    ["102746205979822"] = { name = "AttackAlt1" },
    ["111223305405046"] = { name = "AttackAlt2" },
    ["96355067685976"]  = { name = "SlashAttack" },
}
local ATTACK_NAME_PATTERNS = {"attack","slash","swing","hit","lunge","strike","kill","stab","chop","smash","punch","swipe"}
local NON_ATTACK_PATTERNS = {"idle","walk","run","sprint","turn","stand","crouch","vault","jump","fall","land","carry","pickup","hold","chase"}

local ParryState = {
    killers = {},
    AttemptCooldown = 1.0,
    LastAttemptTime = 0,
    LastHPCheck = 0,
    PreviousHP = 100,
    DamageThreshold = 5,
    FacingAngle = 160,
    LastAnimByKiller = {},
    ServerCooldownEnd = 0,
    ResultListenerConn = nil,
}

local function HasParryDagger()
    local char = Char()
    if not char then return false end
    return char:FindFirstChild("Parrying Dagger") ~= nil
end

local function TriggerParry()
    -- Method 1: Simulate RMB click
    pcall(function()
        VirtualInputMgr:SendMouseButtonEvent(0, 0, 1, true, game, 0)
        task.wait()
        VirtualInputMgr:SendMouseButtonEvent(0, 0, 1, false, game, 0)
    end)
    -- Method 2: Fire parry remote directly as backup
    task.spawn(function()
        if R.Parry.Event then
            pcall(function() R.Parry.Event:FireServer() end)
            pcall(function() R.Parry.Event:FireServer(true) end)
            pcall(function() R.Parry.Event:FireServer(LocalPlayer) end)
        end
    end)
end

local function StartParryResultListener()
    if ParryState.ResultListenerConn then
        pcall(function() ParryState.ResultListenerConn:Disconnect() end)
        ParryState.ResultListenerConn = nil
    end
    if not R.Parry.Result then return end
    ParryState.ResultListenerConn = R.Parry.Result.OnClientEvent:Connect(function(success, cooldownSec)
        if typeof(success) == "boolean" then
            if success then
                State.ParryStats.success = State.ParryStats.success + 1
                Log("[Parry] SERVER SUCCESS (cd="..tostring(cooldownSec).."s)")
                Notify("Parry", "SUCCESS", 1.5)
                if typeof(cooldownSec) == "number" then
                    ParryState.ServerCooldownEnd = tick() + cooldownSec
                    State.LastParryTime = tick()
                    State.ParryCooldown = cooldownSec
                end
            else
                State.ParryStats.fail = State.ParryStats.fail + 1
                Log("[Parry] SERVER FAIL")
            end
        end
    end)
    Log("[Parry] Result listener installed")
end

local function IsParryOnCooldown()
    return tick() < ParryState.ServerCooldownEnd
end

local function CleanupParryHooks()
    ParryState.killers = {}
    ParryState.LastAnimByKiller = {}
    State.KillerAnimHooked = false
end

local function KillerFacingSurvivor(killerChar)
    local myHRP = HRP()
    local killerHRP = killerChar and killerChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not killerHRP then return false, math.huge end
    local toSurvivor = (myHRP.Position - killerHRP.Position)
    local dist = toSurvivor.Magnitude
    if dist > State.AutoParryRange then return false, dist end
    local forward = killerHRP.CFrame.LookVector
    local dot = forward:Dot(toSurvivor.Unit)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    return angle <= (ParryState.FacingAngle / 2), dist
end

local function IsAttackAnimation(track)
    if not track or not track.Animation then return false, "no_track" end
    local animId = tostring(track.Animation.AnimationId)
    local animName = tostring(track.Name):lower()
    local idNum = animId:match("(%d+)")
    if idNum and ATTACK_ANIM_WHITELIST[idNum] then
        return true, "id:"..ATTACK_ANIM_WHITELIST[idNum].name
    end
    for _, pattern in ipairs(NON_ATTACK_PATTERNS) do
        if animName:find(pattern, 1, true) then return false, "blacklisted" end
    end
    for _, pattern in ipairs(ATTACK_NAME_PATTERNS) do
        if animName:find(pattern, 1, true) then return true, "name:"..pattern end
    end
    if idNum then Log("[Parry] UNKNOWN ANIM id="..idNum.." name="..animName) end
    return false, "unknown"
end

local function ExecuteParry(reason, killerDist)
    local now = tick()
    if now - ParryState.LastAttemptTime < ParryState.AttemptCooldown then return false, "attempt_cd" end
    if IsParryOnCooldown() then
        local remaining = math.max(0, ParryState.ServerCooldownEnd - now)
        Log(string.format("[Parry] On cooldown (%.1fs left)", remaining))
        return false, "server_cd"
    end
    if not HasParryDagger() then
        Log("[Parry] No dagger equipped")
        return false, "no_dagger"
    end
    ParryState.LastAttemptTime = now
    State.ParryStats.total = State.ParryStats.total + 1
    Log(string.format("[Parry] TRIGGER reason=%s dist=%.1f", reason, killerDist or 0))
    Notify("Auto Parry", string.format("[%s] %.0fm", reason, killerDist or 0), 1)
    task.spawn(TriggerParry)
    return true, "executed"
end

local function HookKillerAnim(killerPlayer)
    if not killerPlayer or killerPlayer == LocalPlayer then return end
    if ParryState.killers[killerPlayer] and ParryState.killers[killerPlayer].hooked then return end
    local killerChar = killerPlayer.Character
    if not killerChar then return end
    local kHum = killerChar:FindFirstChildOfClass("Humanoid")
    if not kHum then return end
    local animator = kHum:FindFirstChildOfClass("Animator")
    if not animator then return end
    ParryState.killers[killerPlayer] = { hooked = true }
    Log("[Parry] Hooked killer: "..killerPlayer.Name)
    animator.AnimationPlayed:Connect(function(track)
        if not State.AutoParry then return end
        local isAttack, reason = IsAttackAnimation(track)
        if not isAttack then return end
        local id = tostring(track.Animation.AnimationId):match("(%d+)") or "?"
        local lastId = ParryState.LastAnimByKiller[killerPlayer]
        local now = tick()
        if lastId and lastId.id == id and now - lastId.t < 0.3 then return end
        ParryState.LastAnimByKiller[killerPlayer] = { id = id, t = now }
        local facing, dist = KillerFacingSurvivor(killerChar)
        if not facing then
            Log(string.format("[Parry] Attack %s but not facing (dist=%.1f)", reason, dist))
            return
        end
        ExecuteParry(reason, dist)
    end)
end

local HPMonitorConn = nil
local function StartHPMonitor()
    if HPMonitorConn then pcall(function() HPMonitorConn:Disconnect() end); HPMonitorConn = nil end
    HPMonitorConn = RunService.Heartbeat:Connect(function()
        if not State.AutoParry then return end
        local now = tick()
        if now - ParryState.LastHPCheck < 0.05 then return end
        ParryState.LastHPCheck = now
        local h = Hum()
        if not h or h.Health <= 0 then return end
        local currentHP = math.floor(h.Health)
        local damage = ParryState.PreviousHP - currentHP
        ParryState.PreviousHP = currentHP
        if damage < ParryState.DamageThreshold then return end
        local myHRP = HRP(); if not myHRP then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsPlayerKiller(p, p.Character) then
                local kChar = p.Character
                if kChar then
                    local kHRP = kChar:FindFirstChild("HumanoidRootPart")
                    if kHRP then
                        local dist = (kHRP.Position - myHRP.Position).Magnitude
                        if dist <= State.AutoParryRange then
                            ExecuteParry("hp_drop", dist); break
                        end
                    end
                end
            end
        end
    end)
end

local function StopHPMonitor()
    if HPMonitorConn then pcall(function() HPMonitorConn:Disconnect() end); HPMonitorConn = nil end
end

local function SetAutoParry(enable)
    State.AutoParry = enable
    if not enable then
        CleanupParryHooks()
        StopHPMonitor()
        if ParryState.ResultListenerConn then
            pcall(function() ParryState.ResultListenerConn:Disconnect() end)
            ParryState.ResultListenerConn = nil
        end
        return
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsPlayerKiller(p, p.Character) then HookKillerAnim(p) end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            CM:Add(p.CharacterAdded, function()
                task.wait(1)
                if State.AutoParry and IsPlayerKiller(p, p.Character) then HookKillerAnim(p) end
            end)
        end
    end
    StartHPMonitor()
    StartParryResultListener()
    if R.Parry.Event then
        Notify("Auto Parry", "Enabled - parry system found", 3)
    else
        Notify("Auto Parry", "WARNING: parry remote missing", 5)
    end
end

CM:Add(Players.PlayerAdded, function(p)
    task.wait(2)
    if State.AutoParry and IsPlayerKiller(p, p.Character) then HookKillerAnim(p) end
end)

--------------------------------------------------------------------------------
-- PARRY CIRCLE
--------------------------------------------------------------------------------
local RING_SEGMENTS = 100
local ringFolder = nil
local ringParts = {}
local function DestroyParryCircle()
    if ringFolder then pcall(function() ringFolder:Destroy() end); ringFolder = nil end
    ringParts = {}
end
local function BuildParryCircle()
    DestroyParryCircle()
    if not State.ParryCircle or not State.AutoParry then return end
    ringFolder = Instance.new("Folder")
    ringFolder.Name = "X0_ParryRing"; ringFolder.Parent = Workspace
    for i = 1, RING_SEGMENTS do
        local part = Instance.new("Part")
        part.Name = "R"..i
        part.Anchored = true; part.CanCollide = false
        part.CanTouch = false; part.CanQuery = false
        part.CastShadow = false; part.Material = Enum.Material.Neon
        part.Color = Color3.fromRGB(255, 0, 0)
        part.Transparency = 0; part.Size = Vector3.new(1, 0.35, 0.35)
        part.CFrame = CFrame.new(0, -500, 0); part.Parent = ringFolder
        table.insert(ringParts, part)
    end
    CM:Add(RunService.Heartbeat, function()
        if not State.AutoParry or not State.ParryCircle or not ringFolder then
            for _, p in ipairs(ringParts) do
                if p and p.Parent then p.CFrame = CFrame.new(0, -500, 0) end
            end
            return
        end
        local hrp = HRP(); if not hrp then return end
        local center = hrp.Position
        local y = center.Y - 2.9
        local range = State.AutoParryRange
        for i, part in ipairs(ringParts) do
            if not part or not part.Parent then return end
            local angle = (i / RING_SEGMENTS) * math.pi * 2
            local nextAngle = ((i + 1) / RING_SEGMENTS) * math.pi * 2
            local x1 = center.X + math.cos(angle) * range
            local z1 = center.Z + math.sin(angle) * range
            local x2 = center.X + math.cos(nextAngle) * range
            local z2 = center.Z + math.sin(nextAngle) * range
            local p1 = Vector3.new(x1, y, z1); local p2 = Vector3.new(x2, y, z2)
            local mid = (p1 + p2) / 2; local len = (p2 - p1).Magnitude
            part.Size = Vector3.new(len + 0.05, 0.35, 0.35)
            part.CFrame = CFrame.lookAt(mid, p2)
            part.Transparency = 0
        end
    end)
end

--------------------------------------------------------------------------------
-- SERVER HOP / ANTI-AFK
--------------------------------------------------------------------------------
local function ServerHop()
    pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
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
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

KB.Register("WalkSpeed", Enum.KeyCode.V, function()
    State.WalkSpeedEnabled = not State.WalkSpeedEnabled
    SetWalkSpeed(State.WalkSpeedEnabled)
    Notify("Walk Speed", State.WalkSpeedEnabled and "ON" or "OFF", 1.5)
end, true)
KB.Register("AutoHeal", Enum.KeyCode.H, function()
    State.AutoHeal = not State.AutoHeal
    SetAutoHeal(State.AutoHeal)
    Notify("Auto Heal", State.AutoHeal and "ON" or "OFF", 1.5)
end, true)
KB.Register("Invisible", Enum.KeyCode.G, function()
    if not Char() then return end
    State.Invisible = not State.Invisible
    SetInvisible(State.Invisible)
end, true)
KB.Register("AntiKnock", Enum.KeyCode.K, function()
    State.AntiKnock = not State.AntiKnock
    SetAntiKnock(State.AntiKnock)
    Notify("Anti-Knock", State.AntiKnock and "ON" or "OFF", 1.5)
end, true)

Vis.Backup()
task.spawn(function() task.wait(0.3); Vis.ApplyAll() end)

--════════════════════════════════════════════════════════════════════════════════
-- FLUENT UI
--════════════════════════════════════════════════════════════════════════════════
local Window = Fluent:CreateWindow({
    Title = HUB.Name.." v"..HUB.Version,
    SubTitle = HUB.Game.." | "..HUB.Author,
    TabWidth = 160, Size = UDim2.fromOffset(620, 480),
    Acrylic = true, Theme = "Dark", MinimizeKey = Enum.KeyCode.Insert,
})
_G[INSTANCE_KEY] = { version = HUB.Version, window = Window, destroy = function() end }

local Tabs = {
    ESP      = Window:AddTab({Title="ESP",      Icon="eye"}),
    Aim      = Window:AddTab({Title="Aim",      Icon="crosshair"}),
    Survivor = Window:AddTab({Title="Survivor", Icon="shield"}),
    Teleport = Window:AddTab({Title="Teleport", Icon="map-pin"}),
    Killer   = Window:AddTab({Title="Killer",   Icon="swords"}),
    Visuals  = Window:AddTab({Title="Visuals",  Icon="sun"}),
    Misc     = Window:AddTab({Title="Misc",     Icon="wrench"}),
    Settings = Window:AddTab({Title="Settings", Icon="settings"}),
}

do
    local S = Tabs.ESP:AddSection("Entity ESP")
    S:AddToggle("ESP_Player",{Title="Player ESP (Killer = RED)",Default=false}):OnChanged(function(v) State.ESP_Player=v; ESP.RefreshAll() end)
    S:AddToggle("ESP_Zombie",{Title="Cure/Zombie/Minion ESP",Default=false}):OnChanged(function(v) State.ESP_Zombie=v; ESP.ScanZombies() end)
    S:AddToggle("ESP_HP",{Title="Health Bar",Default=true}):OnChanged(function(v) State.ESP_HealthBar=v end)
    S:AddToggle("ESP_Dist",{Title="Distance",Default=true}):OnChanged(function(v) State.ESP_Distance=v end)
end
do
    local S = Tabs.ESP:AddSection("Objects ESP")
    S:AddToggle("ESP_Gen",{Title="Generator ESP",Default=false}):OnChanged(function(v) State.ESP_Generator=v; ESP.ScanGens() end)
    S:AddToggle("ESP_Pallet",{Title="Pallet ESP",Default=false}):OnChanged(function(v) State.ESP_Pallet=v; ESP.ScanPallets() end)
    S:AddToggle("ESP_Vault",{Title="Vault ESP",Default=false}):OnChanged(function(v) State.ESP_Vault=v; ESP.ScanVaults() end)
    S:AddToggle("ESP_Exit",{Title="Exit Gate ESP",Default=false}):OnChanged(function(v) State.ESP_Exit=v; ESP.ScanExits() end)
end
do
    local S = Tabs.ESP:AddSection("ESP Settings")
    S:AddSlider("ESP_MaxDist",{Title="Max Distance",Default=1500,Min=100,Max=3000,Rounding=0}):OnChanged(function(v) State.ESP_MaxDistance=v end)
    S:AddButton({Title="Refresh ESP",Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end})
end

do
    local S = Tabs.Aim:AddSection("Aimbot")
    S:AddToggle("Aimbot",{Title="Enable Aimbot",Default=false}):OnChanged(function(v) SetAimbot(v) end)
    S:AddToggle("RMBAim",{Title="RMB Aim (Hold Right Click)",Default=false}):OnChanged(function(v) SetRMBAim(v) end)
    S:AddToggle("AimTeamCheck",{Title="Skip Same Team",Default=false}):OnChanged(function(v) State.AimTeamCheck=v end)
    S:AddDropdown("AimPart",{Title="Aim At Part",Values={"Head","HumanoidRootPart","UpperTorso","Torso"},Default="Head"}):OnChanged(function(v) State.AimPart=v end)
end
do
    local S = Tabs.Aim:AddSection("Aim Tuning")
    S:AddSlider("AimSmooth",{Title="Smoothing",Default=50,Min=1,Max=100,Rounding=0}):OnChanged(function(v) State.AimSmoothing=v/100 end)
    S:AddSlider("AimFOV",{Title="Aim FOV",Default=90,Min=10,Max=360,Rounding=0}):OnChanged(function(v) State.AimFOV=v; if State.AimShowFOV then BuildAimFOV() end end)
    S:AddSlider("AimMaxDist",{Title="Max Distance",Default=200,Min=20,Max=1000,Rounding=0}):OnChanged(function(v) State.AimMaxDistance=v end)
    S:AddToggle("AimShowFOV",{Title="Show FOV Circle",Default=false}):OnChanged(function(v) State.AimShowFOV=v; if v then BuildAimFOV() else DestroyAimFOV() end end)
end
do
    local S = Tabs.Aim:AddSection("Crosshair")
    S:AddToggle("Crosshair",{Title="Enable Crosshair",Default=false}):OnChanged(function(v) State.Crosshair=v; BuildCrosshair() end)
    S:AddDropdown("CrossStyle",{Title="Style",Values={"Dot","Cross","Plus","Circle"},Default="Dot"}):OnChanged(function(v) State.CrosshairStyle=v; if State.Crosshair then BuildCrosshair() end end)
    S:AddSlider("CrossSize",{Title="Size",Default=4,Min=2,Max=20,Rounding=0}):OnChanged(function(v) State.CrosshairSize=v; if State.Crosshair then BuildCrosshair() end end)
end

-- SURVIVOR TAB
do
    local S = Tabs.Survivor:AddSection("Feature Invisible")
    S:AddToggle("Invis",{Title="Invisible (Double-tap G)",Default=false}):OnChanged(function(v) State.Invisible=v; SetInvisible(v) end)
    S:AddToggle("UnlockCur",{Title="Unlock Cursor",Default=false}):OnChanged(function(v) State.UnlockCursor=v; SetUnlockCursor(v) end)
end
do
    local S = Tabs.Survivor:AddSection("Auto Parry [BETA]")
    S:AddToggle("AutoParry",{Title="Auto Parry (attack detection)",Default=false}):OnChanged(function(v)
        State.AutoParry=v; SetAutoParry(v)
        if v then BuildParryCircle() else DestroyParryCircle() end
    end)
    S:AddSlider("ParryRange",{Title="Parry Range",Default=15,Min=5,Max=30,Rounding=0}):OnChanged(function(v) State.AutoParryRange=v end)
    S:AddToggle("ParryCircle",{Title="Show Parry Range Circle",Default=true}):OnChanged(function(v)
        State.ParryCircle=v
        if State.AutoParry then if v then BuildParryCircle() else DestroyParryCircle() end end
    end)
    S:AddButton({Title="Test Parry NOW",Callback=function()
        TriggerParry()
        Notify("Parry Test", "RMB simulated + remote fired", 2)
    end})
    S:AddButton({Title="Parry Stats",Callback=function()
        local remaining = math.max(0, ParryState.ServerCooldownEnd - tick())
        Notify("Parry Stats", string.format(
            "Attempts: %d | Success: %d | Fails: %d | CD: %.0fs",
            State.ParryStats.total, State.ParryStats.success, State.ParryStats.fail, remaining
        ), 5)
    end})
    S:AddButton({Title="Check Dagger",Callback=function()
        Notify("Dagger", HasParryDagger() and "EQUIPPED" or "NOT EQUIPPED", 3)
    end})
end
do
    local S = Tabs.Survivor:AddSection("Survival Utility")
    S:AddToggle("AntiKnock",{Title="Anti-Knock (Double-tap K)",Default=false}):OnChanged(function(v) State.AntiKnock=v; SetAntiKnock(v) end)
    S:AddButton({Title="Force Clear Knocked",Callback=function() ClearKnockedState(); Notify("Anti-Knock","Force-cleared!",2) end})
    S:AddToggle("NoFall",{Title="No Fall Damage",Default=false}):OnChanged(function(v) State.NoFallDamage=v; SetNoFall(v) end)
    S:AddToggle("FastVault",{Title="Fast Vault",Default=false}):OnChanged(function(v) State.FastVault=v; SetFastVault(v) end)
end
do
    local S = Tabs.Survivor:AddSection("Walk Speed")
    S:AddSlider("WalkSpd",{Title="Walk Speed Value",Default=28,Min=16,Max=80,Rounding=0}):OnChanged(function(v) State.WalkSpeedValue=v; if State.WalkSpeedEnabled then SetWalkSpeed(true) end end)
    S:AddToggle("WalkSpdOn",{Title="Enable (Double-tap V)",Default=false}):OnChanged(function(v) State.WalkSpeedEnabled=v; SetWalkSpeed(v) end)
end
do
    local S = Tabs.Survivor:AddSection("Auto Generator Rush")
    S:AddSlider("GenRadius",{Title="Killer Safety Radius",Default=30,Min=10,Max=100,Rounding=0}):OnChanged(function(v) State.GenKillerRadius=v end)
    S:AddToggle("AutoGen",{Title="Auto Gen Rush",Default=false}):OnChanged(function(v) State.AutoGenRush=v; SetAutoGenRush(v) end)
    S:AddToggle("GenWhileKnocked",{Title="Gen Rush While Knocked [OP]",Default=false}):OnChanged(function(v) State.GenWhileKnocked=v end)
end
do
    local S = Tabs.Survivor:AddSection("Skill Check System")
    S:AddDropdown("SkillCheckMode",{
        Title = "Mode",
        Values = {"Off", "Legit", "Fast", "Instant"},
        Default = "Off",
    }):OnChanged(function(v) SetSkillCheckMode(v) end)
    S:AddButton({
        Title = "Release Instant Lock",
        Callback = function() ReleaseInstantLock(); Notify("Instant","Released",2) end,
    })
    S:AddParagraph({
        Title = "Mode Info",
        Content = "Off: disabled\n"
               .. "Legit: normal repair + auto-perfect skillcheck\n"
               .. "Fast: hides skillcheck GUI + auto-perfect\n"
               .. "Instant: auto-detects when you start a gen, anchors body at gen while view is free. Blocks new gen until current done."
    })
end
do
    local S = Tabs.Survivor:AddSection("Auto Heal")
    S:AddSlider("HealHP",{Title="Heal Below HP %",Default=60,Min=10,Max=99,Rounding=0}):OnChanged(function(v) State.AutoHealThreshold=v end)
    S:AddSlider("HealCD",{Title="Cooldown (x0.1s)",Default=12,Min=3,Max=50,Rounding=0}):OnChanged(function(v) State.HealCooldown=v/10 end)
    S:AddToggle("AutoHeal",{Title="Auto Heal (Double-tap H)",Default=false}):OnChanged(function(v) State.AutoHeal=v; SetAutoHeal(v) end)
    S:AddButton({Title="Force Heal Now",Callback=ForceHealNow})
end
do
    local S = Tabs.Survivor:AddSection("Bypass Exit Gate")
    S:AddToggle("BypassGate",{Title="Force Exit Gate Open",Default=false}):OnChanged(function(v) State.BypassGate=v; SetBypassGate(v) end)
    S:AddButton({Title="Teleport to Nearest Gate",Callback=TeleportToNearestGate})
    S:AddButton({Title="Force Escape Now",Callback=ForceEscape})
    S:AddButton({Title="Open All Gates (Once)",Callback=function()
        local gates = GetExits()
        for _, g in ipairs(gates) do ForceOpenGate(g) end
        Notify("Gate", "Opened "..#gates.." gates", 3)
    end})
end

-- Teleport Tab
local tpNames = GetPlayerNames()
local tpDrop, followDrop
do
    local S = Tabs.Teleport:AddSection("Player Teleport")
    tpDrop = S:AddDropdown("TPPlayer",{Title="Select Player",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.TeleportTarget = (v=="None") and nil or v end)
    S:AddButton({Title="Teleport Now",Callback=function()
        if not State.TeleportTarget then return end
        local ok = TeleportToPlayer(State.TeleportTarget, Vector3.new(2, 0, 2))
        Notify("TP", ok and ("To "..State.TeleportTarget) or "Failed", 3)
    end})
    S:AddButton({Title="Teleport Behind",Callback=function()
        if not State.TeleportTarget then return end
        local p = FindPlayerByName(State.TeleportTarget)
        if not p or not p.Character then return end
        local prp = p.Character:FindFirstChild("HumanoidRootPart"); if not prp then return end
        local behind = prp.CFrame * CFrame.new(0, 0, 3)
        local hrp = HRP(); if not hrp then return end
        if State.Invisible then
            State.InvisOriginalCF = behind
            pcall(function() hrp.CFrame = behind end)
            task.delay(0.05, function()
                if State.Invisible then pcall(function() hrp.CFrame = CFrame.new(0, VOID_Y, 0) end) end
            end)
        else pcall(function() hrp.CFrame = behind end) end
    end})
    S:AddButton({Title="Bring Player to Me",Callback=function()
        if not State.TeleportTarget then return end
        local p = FindPlayerByName(State.TeleportTarget)
        if not p or not p.Character then return end
        local prp = p.Character:FindFirstChild("HumanoidRootPart")
        local hrp = HRP()
        if prp and hrp then pcall(function() prp.CFrame = hrp.CFrame + Vector3.new(2, 0, 0) end) end
    end})
end
do
    local S = Tabs.Teleport:AddSection("Auto Follow")
    followDrop = S:AddDropdown("FollowPlayer",{Title="Follow Target",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.AutoFollowTarget = (v=="None") and nil or v end)
    S:AddSlider("FollowOff",{Title="Follow Offset",Default=2,Min=0,Max=8,Rounding=0}):OnChanged(function(v) State.AutoFollowOffset = Vector3.new(v, 0, v) end)
    S:AddToggle("AutoFollow",{Title="Auto Follow",Default=false}):OnChanged(function(v) State.AutoFollowEnabled=v; SetAutoFollow(v) end)
    S:AddButton({Title="Refresh Player List",Callback=function()
        local n = GetPlayerNames()
        pcall(function() tpDrop:SetValues(n); tpDrop:SetValue(n[1] or "None") end)
        pcall(function() followDrop:SetValues(n); followDrop:SetValue(n[1] or "None") end)
        State.TeleportTarget = (n[1] ~= "None") and n[1] or nil
    end})
end
CM:Add(Players.PlayerAdded, function()
    task.wait(1)
    local n = GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end)
    pcall(function() followDrop:SetValues(n) end)
end)
CM:Add(Players.PlayerRemoving, function(p)
    task.wait(0.5)
    if State.TeleportTarget == p.Name then State.TeleportTarget = nil end
    if State.AutoFollowTarget == p.Name then
        State.AutoFollowTarget = nil
        if State.AutoFollowEnabled then SetAutoFollow(false) end
    end
    local n = GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end)
    pcall(function() followDrop:SetValues(n) end)
end)

-- Killer Tab
do
    local S = Tabs.Killer:AddSection("Auto Hit")
    S:AddSlider("HitRange",{Title="Hit Range",Default=12,Min=5,Max=40,Rounding=0}):OnChanged(function(v) State.AutoHitRange=v end)
    S:AddToggle("AutoHit",{Title="Auto Hit (in range)",Default=false}):OnChanged(function(v) State.AutoHit=v; SetAutoHit(v) end)
    S:AddSlider("HitAllDelay",{Title="Hit All Delay (sec)",Default=5,Min=1,Max=30,Rounding=0}):OnChanged(function(v) State.AutoHitAllDelay=v end)
    S:AddToggle("AutoHitAll",{Title="Auto Hit All",Default=false}):OnChanged(function(v) State.AutoHitAll=v; SetAutoHitAll(v) end)
    S:AddButton({Title="Hit All Now",Callback=function()
        local pl = GetAllOtherPlayers()
        for _, p in ipairs(pl) do pcall(FireHit, p) end
        Notify("Hit","Hit "..#pl,3)
    end})
end
do
    local S = Tabs.Killer:AddSection("Generator Sabotage")
    S:AddToggle("InstDmgGen",{Title="Instant Damage Gen",Default=false}):OnChanged(function(v) State.InstantDamageGen=v end)
    S:AddToggle("AutoDmgGen",{Title="Auto Damage Gen",Default=false}):OnChanged(function(v) State.AutoDamageGen=v; SetAutoDamageGen(v) end)
end
do
    local S = Tabs.Killer:AddSection("Pallet Control")
    S:AddToggle("InstPallet",{Title="Instant Break Pallet",Default=false}):OnChanged(function(v) State.InstantBreakPallet=v; SetInstantBreakPallet(v) end)
end
do
    local S = Tabs.Killer:AddSection("Killer Speed")
    S:AddSlider("KillerSpd",{Title="Speed Value",Default=30,Min=16,Max=120,Rounding=0}):OnChanged(function(v) State.KillerWalkSpeedValue=v; if State.KillerWalkSpeedEnabled then SetKillerWalkSpeed(true) end end)
    S:AddToggle("KillerSpdOn",{Title="Enable Killer Speed",Default=false}):OnChanged(function(v) State.KillerWalkSpeedEnabled=v; SetKillerWalkSpeed(v) end)
end
do
    local S = Tabs.Killer:AddSection("Killer Protection")
    S:AddToggle("NoStun",{Title="No Stun",Default=false}):OnChanged(function(v) State.NoStun=v; SetNoStun(v) end)
    S:AddToggle("NoSlow",{Title="No Slowdown",Default=false}):OnChanged(function(v) State.NoSlowdown=v; SetNoSlowdown(v) end)
end

-- Visuals Tab
do
    local S = Tabs.Visuals:AddSection("Lighting")
    S:AddToggle("FullBright",{Title="Full Bright",Default=true}):OnChanged(function(v) Vis.FullBright(v) end)
    S:AddToggle("NoFog",{Title="No Fog",Default=true}):OnChanged(function(v) Vis.NoFog(v) end)
    S:AddToggle("NoShadow",{Title="No Shadows",Default=true}):OnChanged(function(v) Vis.NoShadows(v) end)
    S:AddButton({Title="Force Re-apply",Callback=function() Vis.ApplyAll(); Notify("Visuals","Re-applied",2) end})
end
do
    local S = Tabs.Visuals:AddSection("Camera")
    S:AddToggle("UnlimZoom",{Title="Unlimited Zoom",Default=false}):OnChanged(function(v) State.UnlimitedZoom=v; Vis.UnlimitedZoom(v) end)
end

-- Misc Tab
do
    local S = Tabs.Misc:AddSection("Performance")
    S:AddToggle("FPSCounter",{Title="FPS + Ping HUD",Default=true}):OnChanged(function(v) FPSCounter.SetVisible(v) end)
    S:AddDropdown("FPSCap",{Title="Lock FPS",Values={"None","30","60","120","144","165","180","240","360"},Default="None"}):OnChanged(function(v) SetFPSCap(v) end)
    S:AddToggle("FPSBoost",{Title="FPS Boost",Default=false}):OnChanged(function(v) State.FPSBoost=v; SetFPSBoost(v) end)
end
do
    local S = Tabs.Misc:AddSection("Utility")
    S:AddToggle("AntiAFK",{Title="Anti AFK",Default=true}):OnChanged(function(v) State.AntiAFK=v end)
    S:AddButton({Title="Rejoin Server",Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end})
    S:AddButton({Title="Server Hop",Callback=ServerHop})
end
do
    local S = Tabs.Misc:AddSection("Community")
    S:AddButton({Title="Copy Discord Link",Callback=function()
        if setclipboard then setclipboard(HUB.Discord); Notify("Discord","Copied!",3)
        else Notify("Discord",HUB.Discord,5) end
    end})
end

-- Settings Tab
do
    local S = Tabs.Settings:AddSection("Hub Settings")
    S:AddToggle("Notifs",{Title="Notifications",Default=true}):OnChanged(function(v) State.Notifications=v end)
end
do
    local S = Tabs.Settings:AddSection("Floating Logo")
    S:AddToggle("FloatLogo",{Title="Show Floating Logo",Default=true}):OnChanged(function(v) FloatingLogo.SetVisible(v) end)
    S:AddSlider("LogoSize",{Title="Logo Size",Default=60,Min=30,Max=140,Rounding=0}):OnChanged(function(v) FloatingLogo.SetSize(v) end)
    S:AddSlider("LogoAlpha",{Title="Transparency %",Default=10,Min=0,Max=90,Rounding=0}):OnChanged(function(v) FloatingLogo.SetTransparency(v/100) end)
    S:AddButton({Title="Rebuild Logo",Callback=function() State.FloatingLogo=true; FloatingLogo.Build(); Notify("Logo","Rebuilt",2) end})
end
do
    local S = Tabs.Settings:AddSection("Danger Zone")
    S:AddButton({Title="Unload Hub",Callback=function()
        SetInvisible(false); SetAutoHeal(false)
        SetAutoFollow(false); SetAutoHit(false); SetAutoHitAll(false)
        SetAutoDamageGen(false); SetInstantBreakPallet(false)
        SetNoStun(false); SetNoSlowdown(false); SetUnlockCursor(false)
        SetAutoParry(false); DestroyParryCircle(); SetAntiKnock(false)
        SetBypassGate(false); SetSkillCheckMode("Off"); StopBodyAnchor()
        SetAimbot(false); SetRMBAim(false); DestroyCrosshair(); DestroyAimFOV()
        FPSCounter.SetVisible(false); Vis.Restore()
        LocalPlayer.CameraMaxZoomDistance = 128
        if setfpscap then pcall(function() setfpscap(9999) end) end
        if ESPRender then ESPRender:Disconnect() end
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        DestroyLogo(); DestroyFPS(); CM:Cleanup(); ESP.ClearAll()
        _G[INSTANCE_KEY] = nil
        pcall(function() Fluent:Destroy() end)
    end})
end

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings(); SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("X0DEC04T")
SaveManager:SetFolder("X0DEC04T/violence-district")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

CM:Add(LocalPlayer.CharacterAdded, function()
    task.wait(1.5)
    State.Invisible = false; State.InvisOriginalCF = nil; State.WasKnocked = false
    State.CurrentRepairGen = nil; State.CurrentRepairPoint = nil
    State.InstantAnchorCF = nil; State.InstantBodyLock = false
    DisconnectInvis(); Vis.ApplyAll()
    Cache.genDirty = true; Cache.palDirty = true
    Cache.vaultDirty = true; Cache.exitDirty = true
    if State.WalkSpeedEnabled then pcall(SetWalkSpeed, true) end
    if State.KillerWalkSpeedEnabled then pcall(SetKillerWalkSpeed, true) end
    if State.NoFallDamage then pcall(SetNoFall, true) end
    if State.AutoHeal then pcall(SetAutoHeal, true) end
    if State.AutoFollowEnabled then pcall(SetAutoFollow, true) end
    if State.AutoHit then pcall(SetAutoHit, true) end
    if State.AutoHitAll then pcall(SetAutoHitAll, true) end
    if State.NoStun then pcall(SetNoStun, true) end
    if State.NoSlowdown then pcall(SetNoSlowdown, true) end
    if State.UnlimitedZoom then pcall(Vis.UnlimitedZoom, true) end
    if State.AntiKnock then pcall(SetAntiKnock, true) end
    if State.BypassGate then pcall(SetBypassGate, true) end
    if State.AutoParry then
        pcall(SetAutoParry, true)
        if State.ParryCircle then BuildParryCircle() end
    end
    if State.UnlockCursor then pcall(SetUnlockCursor, true) end
    skillCheckHooked = false; repairAnimHooked = false
    HookSkillCheckAutoPerfect(); HookRepairAnimTracking()
    if State.SkillCheckMode == "Instant" then
        StartInstantMode(); StartBodyAnchor()
    end
    if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
    if State.FPSCounter and not (State.FPSGui and State.FPSGui.Parent) then FPSCounter.Build() end
    task.wait(0.5)
    ESP.RefreshAll()
end)

_G[INSTANCE_KEY].destroy = function()
    pcall(SetInvisible, false); pcall(SetAntiKnock, false)
    pcall(SetBypassGate, false); pcall(SetSkillCheckMode, "Off")
    pcall(StopBodyAnchor)
    pcall(function() SetAimbot(false) end)
    pcall(function() SetRMBAim(false) end)
    pcall(function() SetAutoParry(false) end)
    DisconnectInvis0(); DestroyLogo(); DestroyFPS()
    DestroyCrosshair(); DestroyAimFOV()
    if setfpscap then pcall(function() setfpscap(9999) end) end
    pcall(function() Fluent:Destroy() end)
end

task.spawn(function()
    task.wait(0.5)
    if State.FloatingLogo then
        local ok = FloatingLogo.Build()
        if not ok then
            for i = 1, 3 do task.wait(1); if FloatingLogo.Build() then break end end
        end
    end
    if State.FPSCounter then FPSCounter.Build() end
    while task.wait(5) do
        if State.FloatingLogo and not (State.LogoGui and State.LogoGui.Parent) then FloatingLogo.Build() end
        if State.FPSCounter and not (State.FPSGui and State.FPSGui.Parent) then FPSCounter.Build() end
    end
end)

Window:SelectTab(1)
Notify(HUB.Name, "v"..HUB.Version.." Loaded", 6)
Log("v1.1.1 fully loaded")
