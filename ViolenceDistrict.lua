--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.7.1 - Violence District [WindUI]
-- Fixes: Invisible (free to move), Logo (ImageLabel), Vault/Exit filter,
--        Duplicate GetExits removed, while+continue removed
-- Keybinds (double-tap V/G/H/R, single Insert):
--   V=WalkSpeed | G=Invisible | H=AutoHeal | R=AutoParry
--   Insert=Toggle UI
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
local TextChatService   = game:GetService("TextChatService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_v071"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(m))) end

Log("v0.7.1 starting")

-- WINDUI
local WindUI = nil
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then WindUI = r; break end
end
if not WindUI then warn("WindUI failed"); return end

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.7.1",
    Author  = "voixera",
    LogoId  = "rbxassetid://91626851418651",
    Discord = "discord.gg/x0dec04t",
    ConfigFolder = "X0DEC04T/Configs",
}

-- CONNECTION MANAGER
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

-- TYPING DETECTION
local function IsTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, cfg = pcall(function() return TextChatService.ChatInputBarConfiguration end)
    if ok and cfg and cfg.IsFocused then return true end
    return false
end

-- KEYBIND MANAGER
local KB = {
    _binds = {},
    DoubleTapWindow = 0.35,
    _lastTap = {},
    BlockWhileTyping = true,
}
function KB.Register(name, key, cb, requireDouble)
    KB._binds[name] = {
        key = key or Enum.KeyCode.Unknown,
        callback = cb,
        enabled = true,
        requireDouble = requireDouble ~= false,
    }
end
function KB.SetKey(name, key) if KB._binds[name] then KB._binds[name].key = key end end

CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if KB.BlockWhileTyping and IsTyping() then return end
    for name, bind in pairs(KB._binds) do
        if bind.enabled and bind.key == inp.KeyCode then
            if bind.requireDouble then
                local now = tick()
                local last = KB._lastTap[name] or 0
                if now - last <= KB.DoubleTapWindow then
                    KB._lastTap[name] = 0
                    pcall(bind.callback)
                else
                    KB._lastTap[name] = now
                end
            else
                pcall(bind.callback)
            end
        end
    end
end)

-- REMOTES
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function GR(...)
    if not Remotes then return nil end
    local c = Remotes
    for _,n in ipairs({...}) do c = c:FindFirstChild(n); if not c then return nil end end
    return c
end
local function FindDeep(root, name)
    if not root then return nil end
    for _, v in ipairs(root:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name == name then return v end
    end
end
local function FindKW(root, kw)
    local found = {}
    if not root then return found end
    for _, v in ipairs(root:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction"))
           and v.Name:lower():find(kw:lower()) then
            table.insert(found, v)
        end
    end
    return found
end

local R = {
    Gen = { RepairEvent = GR("Generator","RepairEvent") },
    Game = {
        Start = GR("Game","Start"),
        KillerMorph = GR("Game","KillerMorph"),
        RoundEnd = GR("Game","RoundEnd"),
    },
    Heal = GR("Items","Medkit","heal") or FindDeep(Remotes,"HealEvent") or FindDeep(Remotes,"heal"),
    HealAlts = {},
    Perks = {},
    Vault = GR("Vault","VaultEvent") or FindDeep(Remotes,"VaultEvent") or FindDeep(Remotes,"Vault"),
    ExitGate = GR("ExitGate","Open") or FindDeep(Remotes,"ExitGate") or FindDeep(Remotes,"OpenExit"),

    Pallet = {
        SlideAnim = GR("Pallet","PalletSlideAnim"),
        SlideEvent = GR("Pallet","PalletSlideEvent"),
        SlideComplete = GR("Pallet","PalletSlideCompleteEvent"),
        JasonStun = GR("Pallet","Jason","Stun"),
        JasonStunover = GR("Pallet","Jason","Stunover"),
        BreakCommit = GR("Pallet","Jason","PalletBreakCommit"),
        BreakReject = GR("Pallet","Jason","PalletBreakReject"),
        DropEvent = GR("Pallet","PalletDropEvent"),
        DropAnim = GR("Pallet","PalletDropAnim"),
        DropCommit = GR("Pallet","PalletDropCommit"),
    },
    GenBreak = {
        Event = GR("Generator","BreakGenEvent"),
        Anim = GR("Generator","BreakGenAnim"),
        Commit = GR("Generator","BreakGenCommit"),
        Reject = GR("Generator","BreakGenReject"),
    },
    Attacks = {
        Basic = GR("Attacks","BasicAttack"),
        After = GR("Attacks","AfterAttack"),
        Hit = GR("Attacks","hit"),
        Lunge = GR("Attacks","Lunge"),
        LungeDetect = GR("Attacks","LungeDetect"),
    },
    Killers = {
        Stalker = {
            Start = GR("Killers","Stalker","StartGrabHitbox"),
            Result = GR("Killers","Stalker","GrabHitResult"),
            Cancel = GR("Killers","Stalker","CancelGrabHitbox"),
        },
        Frenzy = GR("Killers","Killer","FrenzyHitEvent"),
        Masked = GR("Killers","Masked","alexattack"),
        Hidden = GR("Killers","Hidden","m2HitVM"),
        SlowAttack = GR("Killers","SlowAttack"),
        Damageviz = GR("Killers","Damageviz"),
    },
    KingScourge = GR("KillerPerks","kingscourge","KingScourgeHit"),
    AttackEvent = FindDeep(Remotes,"AttackEvent"),
}
for _, r in ipairs(FindKW(Remotes,"heal")) do table.insert(R.HealAlts, r) end
for _, kw in ipairs({"invis","hidden","stealth","cloak","perk"}) do
    for _, r in ipairs(FindKW(Remotes,kw)) do table.insert(R.Perks, r) end
end

Log("Heal:"..(R.Heal and "y" or "n").." | Vault:"..(R.Vault and "y" or "n")
    .." | Attack:"..(R.Attacks.Basic and "y" or "n")
    .." | Break:"..(R.GenBreak.Event and "y" or "n"))

-- WORKSPACE
local WS = {
    Map = Workspace:FindFirstChild("Map"),
    Clones = Workspace:FindFirstChild("Clones"),
    FakeChars = Workspace:FindFirstChild("FakeCharacters"),
}

-- ═══════════════════════════════════════════
-- SCANNERS
-- ═══════════════════════════════════════════
local function FindAllGenerators()
    local list, seen = {}, {}
    if WS.Map then
        local gc = WS.Map:FindFirstChild("Generators")
        if gc then for _, g in ipairs(gc:GetChildren()) do
            if not seen[g] then table.insert(list, g); seen[g]=true end
        end end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and not seen[v] then
            local n = v.Name:lower()
            if (n=="generator" or n:find("^generator") or n:find("gen%d"))
               and (v:FindFirstChild("HitBox") or v:GetAttribute("RepairProgress") ~= nil) then
                table.insert(list, v); seen[v]=true
            end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and not seen[v] and v:GetAttribute("RepairProgress") ~= nil then
            table.insert(list, v); seen[v]=true
        end
    end
    return list
end

-- STRICT FILTERS
local FALSE_KEYWORDS = {
    "column", "stone", "concrete", "wall", "floor", "roof",
    "frame", "beam", "railing", "fence", "post", "pillar",
    "driveway", "decoration", "trim", "asset", "prop",
    "static", "detail", "brick", "wood", "metal",
}

local function IsFalseObject(name)
    local n = name:lower()
    for _, kw in ipairs(FALSE_KEYWORDS) do
        if n:find(kw) then return true end
    end
    return false
end

local function GetPallets()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") then
            local n = v.Name
            if (n == "Palletwrong" or n == "Pallet") and not IsFalseObject(n) then
                table.insert(list, v)
            end
        end
    end
    return list
end

local function GetVaults()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") then
            local n = v.Name
            if (n == "Window" or n == "Vault") and not IsFalseObject(n) then
                local hasHitbox = v:FindFirstChild("HitBox")
                local hasClick = v:FindFirstChildWhichIsA("ClickDetector", true)
                local hasProximity = v:FindFirstChildWhichIsA("ProximityPrompt", true)
                local isInteractable = v:GetAttribute("Interactable")
                    or v:GetAttribute("Vault") or v:GetAttribute("IsVault")
                if hasHitbox or hasClick or hasProximity or isInteractable then
                    table.insert(list, v)
                end
            end
        end
    end
    return list
end

local function GetExits()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and not IsFalseObject(v.Name) then
            local n = v.Name
            local isExit = false

            if n == "ExitGate" or n == "Exit" or n == "EscapeGate"
               or n == "Gate" or n == "Escape" then
                isExit = true
            end

            if v:GetAttribute("IsExit") ~= nil
               or v:GetAttribute("ExitGate") ~= nil
               or v:GetAttribute("EscapeGate") ~= nil then
                isExit = true
            end

            if isExit then
                local hasSwitch = v:FindFirstChild("Switch")
                    or v:FindFirstChild("Lever")
                    or v:FindFirstChild("Handle")
                    or v:FindFirstChild("Button")
                    or v:FindFirstChildWhichIsA("ProximityPrompt", true)
                if not hasSwitch then
                    local size = 0
                    for _, p in ipairs(v:GetDescendants()) do
                        if p:IsA("BasePart") then
                            size = size + 1
                            if size > 15 then break end
                        end
                    end
                    if size > 15 then isExit = false end
                end
            end

            if isExit then table.insert(list, v) end
        end
    end

    local gateFolder = Workspace:FindFirstChild("ExitGates")
        or Workspace:FindFirstChild("Exits")
        or (WS.Map and WS.Map:FindFirstChild("ExitGates"))
        or (WS.Map and WS.Map:FindFirstChild("Exits"))
    if gateFolder then
        for _, g in ipairs(gateFolder:GetChildren()) do
            local dup = false
            for _, e in ipairs(list) do if e == g then dup = true; break end end
            if not dup then table.insert(list, g) end
        end
    end

    return list
end

local function GetZombies()
    local list = {}
    for _, name in ipairs({"Zombies","NPCs","Enemies","Mobs","AI","Zombie"}) do
        local folder = Workspace:FindFirstChild(name)
        if folder then
            for _, z in ipairs(folder:GetDescendants()) do
                if z:IsA("Model") and z:FindFirstChildOfClass("Humanoid") then
                    table.insert(list, z)
                end
            end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") then
            local n = v.Name:lower()
            if (n:find("zombie") or n:find("^npc") or n:find("^mob"))
               and v:FindFirstChildOfClass("Humanoid")
               and not Players:GetPlayerFromCharacter(v) then
                local dup = false
                for _, e in ipairs(list) do if e == v then dup = true; break end end
                if not dup then table.insert(list, v) end
            end
        end
    end
    return list
end

-- STATE
local State = {
    ESP_Player = false, ESP_Survivor = false, ESP_Killer = false,
    ESP_Zombie = false, ESP_HealthBar = true, ESP_Distance = true,
    ESP_Generator = false, ESP_GenProgress = false,
    ESP_Vault = false, ESP_Pallet = false, ESP_Exit = false,
    ESP_MaxDistance = 1500,

    Color_Killer = Color3.fromRGB(255,40,40),
    Color_Generator_Low = Color3.fromRGB(180,60,220),
    Color_Generator_Mid = Color3.fromRGB(255,220,60),
    Color_Generator_High = Color3.fromRGB(60,220,60),
    Color_Vault = Color3.fromRGB(180,60,220),
    Color_Pallet = Color3.fromRGB(255,140,20),
    Color_Zombie = Color3.fromRGB(255,140,20),
    Color_Exit = Color3.fromRGB(255,255,255),

    AutoGenRush = false, GenKillerRadius = 30, AutoGenMode = "Legit",
    AutoSkillcheck = false, SkillcheckMode = "Legit",
    RemoveSkillcheck = false,
    AutoHeal = false, AutoHealThreshold = 60, AutoHealDelay = 1.5, LastHealTime = 0,
    AutoParry = false, ParryRange = 25, ParryCooldown = 0.15, LastParryTime = 0,
    AutoEscape = false,
    FastVault = false,
    NoFallDamage = false,
    WalkSpeedEnabled = false, WalkSpeedValue = 28,
    Invisible = false,

    AutoHit = false, AutoHitRange = 12,
    KillAura = false, KillAuraRange = 20,
    HitboxExpander = false, HitboxSize = 8,
    AutoDamageGen = false,
    InstantDamageGen = false,
    InstantBreakPallet = false,
    KillerWalkSpeed = false, KillerWalkSpeedValue = 30,
    LungeDist = false, LungeDistValue = 30,
    NoStun = false,
    NoSlowdown = false,

    FullBright = false, NoFog = false, NoShadows = false,
    UnlimitedZoom = false, Crosshair = false,

    AntiAFK = true, FPSBoost = false,

    Theme = "Dark", UIScale = 1, BlurBg = true,
    SoundEffects = true, Notifications = true, AutoLoadConfig = false,

    WalkSpeed = 16, ESPCache = {}, GenProgressGuis = {},
    HitboxSaved = {}, HitboxConn = nil,
    InvisibleConn = nil,
    NoFallConn = nil, AutoHealConn = nil, AutoParryConn = nil,
    AutoHitConn = nil, KillAuraConn = nil, AutoDamageGenConn = nil,
    SkillcheckConn = nil, RemoveSCConn = nil, AutoEscapeConn = nil,
    NoStunConn = nil, NoSlowdownConn = nil,

    CachedKiller = nil, KillerCacheTime = 0, CurrentTargetGen = nil,

    UIOpen = true, LogoGui = nil, CrosshairGui = nil,
}

-- HELPERS
local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        WindUI:Notify({
            Title = tostring(t or ""),
            Content = tostring(c or ""),
            Duration = tonumber(d) or 3,
            Icon = "bell",
        })
    end)
end
local function Char() return LocalPlayer.Character end
local function HRP() local c=Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum() local c=Char(); return c and c:FindFirstChildOfClass("Humanoid") end

local function LerpColor(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end
local function GetGradientColor(pct)
    if pct <= 0.5 then
        return LerpColor(State.Color_Generator_Low, State.Color_Generator_Mid, pct*2)
    else
        return LerpColor(State.Color_Generator_Mid, State.Color_Generator_High, (pct-0.5)*2)
    end
end
local function GetHealthColor(pct)
    if pct > 0.6 then return Color3.fromRGB(60,220,60)
    elseif pct > 0.3 then return Color3.fromRGB(255,180,60)
    else return Color3.fromRGB(255,50,50) end
end

-- ROLE DETECTION
local KILLER_ATTRS = {
    "TerrorRadius","Chasemusic","IsChasing","BloodLust",
    "SuspenseRadius","CarriedSurvivorId","IsCarrying",
    "killercarry","killerhook","survivorcarry","survivorhook",
    "kings_scourge","AbyssalCovenant",
    "InAttack","Attacking","SwingActive","SwingCooldown",
}
local Role = {}
function Role.IsKillerChar(char)
    if not char then return false end
    local count = 0
    for _, a in ipairs(KILLER_ATTRS) do
        if char:GetAttribute(a) ~= nil then count = count + 1 end
    end
    return count >= 2
end
function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones and char:IsDescendantOf(WS.Clones) then return true end
    return false
end
function Role.FindKiller()
    if State.CachedKiller then
        local p = State.CachedKiller
        if not p.Parent or not p.Character or not p.Character.Parent
           or not Role.IsKillerChar(p.Character) then
            State.CachedKiller = nil
        end
    end
    if State.CachedKiller and (tick()-State.KillerCacheTime) < 2 then
        return State.CachedKiller
    end
    State.CachedKiller = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and not Role.IsFake(p.Character) then
            if Role.IsKillerChar(p.Character) then
                State.CachedKiller = p
                State.KillerCacheTime = tick()
                return p
            end
        end
    end
    return nil
end
function Role.ResetKillerCache() State.CachedKiller=nil; State.KillerCacheTime=0 end
function Role.AmIKiller()
    local c = Char()
    return c and Role.IsKillerChar(c)
end

-- CONFIG SYSTEM
local Config = {}
local function EnsureFolder()
    if not isfolder then return end
    if not isfolder("X0DEC04T") then makefolder("X0DEC04T") end
    if not isfolder("X0DEC04T/Configs") then makefolder("X0DEC04T/Configs") end
end
function Config.List()
    EnsureFolder()
    local list = {}
    if not listfiles then return list end
    for _, f in ipairs(listfiles("X0DEC04T/Configs")) do
        local name = f:match("[^/\\]+%.json$")
        if name then table.insert(list, name:gsub("%.json$", "")) end
    end
    return list
end
function Config.Save(name)
    if not writefile then Notify("Config","writefile not supported",3); return false end
    EnsureFolder()
    local data = {}
    for k, v in pairs(State) do
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            data[k] = v
        end
    end
    local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then
        writefile("X0DEC04T/Configs/"..name..".json", json)
        Notify("Config","Saved: "..name, 3)
        return true
    end
    return false
end
function Config.Load(name)
    if not readfile then Notify("Config","readfile not supported",3); return false end
    EnsureFolder()
    local path = "X0DEC04T/Configs/"..name..".json"
    if not isfile(path) then Notify("Config","Not found: "..name,3); return false end
    local ok, raw = pcall(readfile, path)
    if not ok then return false end
    local dec, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not dec then Notify("Config","Invalid JSON",3); return false end
    for k, v in pairs(data) do State[k] = v end
    Notify("Config","Loaded: "..name, 3)
    return true
end
function Config.Delete(name)
    if not delfile then Notify("Config","delfile not supported",3); return false end
    local path = "X0DEC04T/Configs/"..name..".json"
    if isfile(path) then
        delfile(path); Notify("Config","Deleted: "..name, 3); return true
    end
    return false
end
function Config.SaveLastLoaded(name)
    if not writefile then return end
    EnsureFolder(); writefile("X0DEC04T/last_config.txt", name)
end
function Config.GetLastLoaded()
    if not readfile then return nil end
    local path = "X0DEC04T/last_config.txt"
    if isfile(path) then return readfile(path) end
    return nil
end

-- ═══════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP_v5")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name="X0_ESP_v5"; ESPGui.ResetOnSpawn=false
    ESPGui.IgnoreGuiInset=true; ESPGui.DisplayOrder=999
    ESPGui.Parent = GuiParent()
end

local function GetRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        local hb = obj:FindFirstChild("HitBox")
        if hb and hb:IsA("BasePart") then return hb end
        local hrp = obj:FindFirstChild("HumanoidRootPart"); if hrp then return hrp end
        local torso = obj:FindFirstChild("Torso") or obj:FindFirstChild("UpperTorso")
        if torso then return torso end
        if obj.PrimaryPart then return obj.PrimaryPart end
        return obj:FindFirstChildWhichIsA("BasePart")
    end
end

local function GetHeadOrTop(obj)
    if not obj then return nil end
    if obj:IsA("Model") then
        local head = obj:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head end
    end
    return GetRootPart(obj)
end

local function MakeEntry(obj, label, color, isChar, kind)
    local rp = GetRootPart(obj); if not rp then return nil end
    local topPart = GetHeadOrTop(obj) or rp

    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency=isChar and 0.5 or 0.6
    hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=Workspace

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 200, 0, isChar and 60 or 45)
    bb.StudsOffset = Vector3.new(0, isChar and 2.5 or 2, 0)
    bb.AlwaysOnTop = true; bb.LightInfluence = 0
    bb.MaxDistance = State.ESP_MaxDistance
    bb.ResetOnSpawn = false; bb.Adornee = topPart; bb.Parent = ESPGui

    local layout = Instance.new("UIListLayout", bb)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Padding = UDim.new(0, 1)

    local nl = Instance.new("TextLabel", bb)
    nl.Name = "NameLabel"; nl.LayoutOrder = 1
    nl.Size = UDim2.new(1, 0, 0, 18); nl.BackgroundTransparency = 1
    nl.Text = label; nl.TextColor3 = color
    nl.TextStrokeTransparency = 0.35; nl.TextStrokeColor3 = Color3.new(0,0,0)
    nl.Font = Enum.Font.GothamBold; nl.TextSize = 13

    local hp = nil
    if isChar then
        hp = Instance.new("TextLabel", bb)
        hp.Name = "HPLabel"; hp.LayoutOrder = 2
        hp.Size = UDim2.new(1, 0, 0, 14); hp.BackgroundTransparency = 1
        hp.Text = "[HP] ?"; hp.TextColor3 = Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency = 0.35; hp.TextStrokeColor3 = Color3.new(0,0,0)
        hp.Font = Enum.Font.GothamBold; hp.TextSize = 12
    end

    local dl = Instance.new("TextLabel", bb)
    dl.Name = "DistLabel"; dl.LayoutOrder = 3
    dl.Size = UDim2.new(1, 0, 0, 12); dl.BackgroundTransparency = 1
    dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency = 0.35; dl.TextStrokeColor3 = Color3.new(0,0,0)
    dl.Font = Enum.Font.Gotham; dl.TextSize = 11

    return {rp=rp, topPart=topPart, obj=obj, hl=hl, bb=bb,
            nl=nl, dl=dl, hp=hp, isChar=isChar, color=color, kind=kind}
end

function ESP.Add(obj, label, color, isChar, kind)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeEntry(obj, label, color, isChar or false, kind)
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
    local hrp = HRP()
    local pos = hrp and hrp.Position or Vector3.zero
    local rem = {}
    for obj, e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then table.insert(rem, obj)
        else
            local rp = GetRootPart(obj)
            local top = GetHeadOrTop(obj) or rp
            if not rp then table.insert(rem, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function() e.hl.Adornee = obj end)
                end
                if e.topPart ~= top then
                    e.topPart = top
                    pcall(function() e.bb.Adornee = top end)
                end
                pcall(function() e.bb.MaxDistance = State.ESP_MaxDistance end)
                local dist = (rp.Position - pos).Magnitude
                local vis = dist <= State.ESP_MaxDistance
                pcall(function()
                    e.dl.Text = math.floor(dist).."m"
                    e.dl.Visible = State.ESP_Distance
                    e.bb.Enabled = vis
                    e.hl.Enabled = vis
                end)
                if e.isChar and e.hp then
                    pcall(function()
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h then
                            local hp = math.floor(h.Health); local mx = math.floor(h.MaxHealth)
                            local pct = (mx>0) and hp/mx or 0
                            e.hp.Text = "[HP] "..hp.."/"..mx
                            e.hp.TextColor3 = GetHealthColor(pct)
                            e.hp.Visible = State.ESP_HealthBar
                            if e.kind == "survivor" then
                                local hpColor = GetHealthColor(pct)
                                pcall(function()
                                    e.hl.FillColor = hpColor
                                    e.hl.OutlineColor = hpColor
                                    e.nl.TextColor3 = hpColor
                                end)
                            end
                        end
                    end)
                end
                if e.kind == "generator" and obj:IsA("Model") then
                    local prog = obj:GetAttribute("RepairProgress") or 0
                    local pct = math.clamp(prog/100, 0, 1)
                    local col = GetGradientColor(pct)
                    pcall(function()
                        e.hl.FillColor = col
                        e.hl.OutlineColor = col
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
    local killer = Role.FindKiller()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent
           and not Role.IsFake(p.Character) then
            local char = p.Character
            local isK = (p == killer)
            local show = false
            local label, color, kind

            if State.ESP_Player then
                show = true
                label = "["..p.Name.."]"
                color = isK and State.Color_Killer or Color3.fromRGB(60,220,60)
                kind = isK and "killer" or "survivor"
            end
            if isK and State.ESP_Killer then
                show = true
                label = "[KILLER] "..p.Name
                color = State.Color_Killer
                kind = "killer"
            end
            if not isK and State.ESP_Survivor then
                show = true
                label = "[SURV] "..p.Name
                color = Color3.fromRGB(60,220,60)
                kind = "survivor"
            end

            if show then
                if not State.ESPCache[char] then
                    ESP.Add(char, label, color, true, kind)
                end
            else
                if State.ESPCache[char] then ESP.Remove(char) end
            end
        end
    end
end

function ESP.ScanZombies()
    local zombies = GetZombies()
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "zombie" then
            local still = false
            for _, z in ipairs(zombies) do if z == obj then still=true; break end end
            if not still then ESP.Remove(obj) end
        end
    end
    for _, z in ipairs(zombies) do
        if State.ESP_Zombie then
            if not State.ESPCache[z] then
                ESP.Add(z, "[ZOMBIE]", State.Color_Zombie, true, "zombie")
            end
        else
            if State.ESPCache[z] then ESP.Remove(z) end
        end
    end
end

function ESP.ScanGens()
    local gens = FindAllGenerators()
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "generator" then
            local exists = false
            for _, g in ipairs(gens) do if g == obj then exists=true; break end end
            if not exists then ESP.Remove(obj) end
        end
    end
    for _, g in ipairs(gens) do
        if State.ESP_Generator then
            if not State.ESPCache[g] then
                local prog = g:GetAttribute("RepairProgress") or 0
                local col = GetGradientColor(prog/100)
                ESP.Add(g, "[GEN] "..math.floor(prog).."%", col, false, "generator")
            end
        else
            if State.ESPCache[g] then ESP.Remove(g) end
        end
    end
end

function ESP.ScanPallets()
    for _, p in ipairs(GetPallets()) do
        if State.ESP_Pallet then
            if not State.ESPCache[p] then ESP.Add(p, "[PALLET]", State.Color_Pallet, false, "pallet") end
        else if State.ESPCache[p] then ESP.Remove(p) end end
    end
end
function ESP.ScanVaults()
    for _, w in ipairs(GetVaults()) do
        if State.ESP_Vault then
            if not State.ESPCache[w] then ESP.Add(w, "[VAULT]", State.Color_Vault, false, "vault") end
        else if State.ESPCache[w] then ESP.Remove(w) end end
    end
end
function ESP.ScanExits()
    for _, e in ipairs(GetExits()) do
        if State.ESP_Exit then
            if not State.ESPCache[e] then ESP.Add(e, "[EXIT] "..e.Name, State.Color_Exit, false, "exit") end
        else if State.ESPCache[e] then ESP.Remove(e) end end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers(); ESP.ScanZombies(); ESP.ScanGens()
    ESP.ScanPallets(); ESP.ScanVaults(); ESP.ScanExits()
end

task.spawn(function()
    while task.wait(1.5) do pcall(ESP.RefreshAll) end
end)

CM:Add(Players.PlayerRemoving, function(p)
    if p.Character then ESP.Remove(p.Character) end
    if State.CachedKiller == p then Role.ResetKillerCache() end
end)

local function HookPlayer(p)
    if p == LocalPlayer then return end
    CM:Add(p.CharacterAdded, function()
        Role.ResetKillerCache(); task.wait(0.5); ESP.RefreshAll()
    end)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c); Role.ResetKillerCache() end)
end
for _, p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
CM:Add(Players.PlayerAdded, HookPlayer)

-- GEN PROGRESS BILLBOARDS
local function SetGenProgressGuis(enable)
    for _, g in pairs(State.GenProgressGuis) do pcall(function() g:Destroy() end) end
    State.GenProgressGuis = {}
    if not enable then return end
    for _, gen in ipairs(FindAllGenerators()) do
        local hb = gen:FindFirstChild("HitBox") or gen:FindFirstChildWhichIsA("BasePart")
        if hb then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = hb
            bb.Size = UDim2.new(0,160,0,45)
            bb.StudsOffset = Vector3.new(0,6,0)
            bb.AlwaysOnTop = true; bb.LightInfluence = 0
            bb.MaxDistance = 500
            bb.Parent = GuiParent()
            local lbl = Instance.new("TextLabel", bb)
            lbl.Size = UDim2.new(1,0,1,0)
            lbl.BackgroundTransparency = 1
            lbl.Text = "[GEN] 0%"
            lbl.TextColor3 = State.Color_Generator_Low
            lbl.TextStrokeTransparency = 0
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 18
            table.insert(State.GenProgressGuis, bb)
            task.spawn(function()
                while bb.Parent and State.ESP_GenProgress do
                    local prog = gen:GetAttribute("RepairProgress") or 0
                    local players = gen:GetAttribute("PlayersRepairingCount") or 0
                    lbl.Text = string.format("[GEN] %d%% [%d]", math.floor(prog), players)
                    lbl.TextColor3 = GetGradientColor(prog/100)
                    task.wait(0.5)
                end
            end)
        end
    end
end

-- WALK SPEED
local Move = {}
function Move.Speed() local h = Hum(); if h then h.WalkSpeed = State.WalkSpeed end end
function Move.SetWalkSpeed(e)
    local h = Hum(); if not h then return end
    local isKiller = Role.AmIKiller()
    if isKiller then
        h.WalkSpeed = e and State.KillerWalkSpeedValue or State.WalkSpeed
    else
        h.WalkSpeed = e and State.WalkSpeedValue or State.WalkSpeed
    end
end

-- NO FALL DAMAGE
local function SetNoFall(e)
    if State.NoFallConn then pcall(function() State.NoFallConn:Disconnect() end); State.NoFallConn=nil end
    local c = Char()
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not e)
                h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not e)
            end)
        end
    end
end

-- ═══════════════════════════════════════════
-- INVISIBLE (visual only, character can move)
-- ═══════════════════════════════════════════
local invisibleSavedTransp = {}

local function SetInvisible(enable)
    if State.InvisibleConn then
        pcall(function() State.InvisibleConn:Disconnect() end)
        State.InvisibleConn = nil
    end
    local char = Char()
    if not char then Notify("Invisible","No character",2); return end

    if not enable then
        for part, orig in pairs(invisibleSavedTransp) do
            if part and part.Parent then
                pcall(function()
                    if part:IsA("BasePart") then
                        part.LocalTransparencyModifier = 0
                        part.Transparency = orig
                        part.CanQuery = true
                    elseif part:IsA("Decal") or part:IsA("Texture") then
                        part.Transparency = orig
                    end
                end)
            end
        end
        invisibleSavedTransp = {}
        pcall(function()
            char:SetAttribute("Invisible", false)
            char:SetAttribute("Untargettable", false)
            char:SetAttribute("Hidden", false)
        end)
        local head = char:FindFirstChild("Head")
        if head then
            for _, g in ipairs(head:GetChildren()) do
                if g:IsA("BillboardGui") then pcall(function() g.Enabled = true end) end
            end
        end
        Notify("Invisible", "OFF", 2)
        return
    end

    invisibleSavedTransp = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            invisibleSavedTransp[p] = p.Transparency
            pcall(function()
                p.LocalTransparencyModifier = 1
                p.CanQuery = false
            end)
        elseif p:IsA("Decal") or p:IsA("Texture") then
            invisibleSavedTransp[p] = p.Transparency
            pcall(function() p.Transparency = 1 end)
        end
    end

    pcall(function()
        char:SetAttribute("Invisible", true)
        char:SetAttribute("Untargettable", true)
        char:SetAttribute("Hidden", true)
    end)
    for _, r in ipairs(R.Perks) do pcall(function() r:FireServer(true) end) end

    local head = char:FindFirstChild("Head")
    if head then
        for _, g in ipairs(head:GetChildren()) do
            if g:IsA("BillboardGui") then pcall(function() g.Enabled = false end) end
        end
    end

    State.InvisibleConn = RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end
        local c = Char(); if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.LocalTransparencyModifier < 0.99 then
                pcall(function()
                    p.LocalTransparencyModifier = 1
                    p.CanQuery = false
                end)
            end
        end
        pcall(function()
            if c:GetAttribute("Invisible") ~= true then c:SetAttribute("Invisible", true) end
            if c:GetAttribute("Untargettable") ~= true then c:SetAttribute("Untargettable", true) end
        end)
    end)

    Notify("Invisible", "ON - You can move freely", 2)
end

-- AUTO HEAL
local function DoHeal()
    local c = Char(); if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    local pct = (h.MaxHealth > 0) and (h.Health/h.MaxHealth*100) or 100
    if pct >= State.AutoHealThreshold then return end
    if tick()-State.LastHealTime < State.AutoHealDelay then return end
    State.LastHealTime = tick()
    if R.Heal then pcall(function() R.Heal:FireServer() end) end
    for _, r in ipairs(R.HealAlts) do pcall(function() r:FireServer() end) end
    pcall(function()
        c:SetAttribute("IsHealing", true); c:SetAttribute("Healing", true)
    end)
    task.delay(1, function()
        pcall(function()
            c:SetAttribute("IsHealing", false); c:SetAttribute("Healing", false)
        end)
    end)
    pcall(function() h.Health = math.min(h.Health+25, h.MaxHealth) end)
end
local function SetAutoHeal(e)
    if State.AutoHealConn then pcall(function() State.AutoHealConn:Disconnect() end); State.AutoHealConn=nil end
    if not e then return end
    State.AutoHealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        pcall(DoHeal)
    end)
end

-- AUTO PARRY
local KILLER_SWING_ATTRS = {
    "InAttack","Attacking","SwingActive","IsSwinging","SwingCooldown",
    "WindingUp","AttackStarted","WeaponSwing","LungeActive","Charging",
}
local function DoParry(reason)
    local now = tick()
    if now - State.LastParryTime < State.ParryCooldown then return end
    State.LastParryTime = now
    local char = Char(); if not char then return end
    pcall(function()
        char:SetAttribute("Parry", true)
        char:SetAttribute("IsParrying", true)
        char:SetAttribute("Blocking", true)
        char:SetAttribute("Iframes", true)
    end)
    for _, k in ipairs({Enum.KeyCode.F, Enum.KeyCode.Q}) do
        pcall(function() VirtualInputMgr:SendKeyEvent(true, k, false, game) end)
        task.delay(0.05, function()
            pcall(function() VirtualInputMgr:SendKeyEvent(false, k, false, game) end)
        end)
    end
    task.delay(0.35, function()
        pcall(function()
            char:SetAttribute("Parry", false)
            char:SetAttribute("IsParrying", false)
            char:SetAttribute("Blocking", false)
            char:SetAttribute("Iframes", false)
        end)
    end)
end
local function SetAutoParry(e)
    if State.AutoParryConn then pcall(function() State.AutoParryConn:Disconnect() end); State.AutoParryConn=nil end
    if not e then return end
    State.AutoParryConn = RunService.Heartbeat:Connect(function()
        if not State.AutoParry then return end
        local hrp = HRP(); if not hrp then return end
        local killer = Role.FindKiller()
        if not killer or not killer.Character then return end
        local khrp = killer.Character:FindFirstChild("HumanoidRootPart"); if not khrp then return end
        local dist = (khrp.Position - hrp.Position).Magnitude
        if dist <= State.ParryRange then DoParry("proximity") end
        for _, a in ipairs(KILLER_SWING_ATTRS) do
            if killer.Character:GetAttribute(a) == true and dist <= State.ParryRange*2 then
                State.LastParryTime = 0; DoParry("swing_"..a)
            end
        end
    end)
end

-- AUTO GEN RUSH
local function SetAutoGenRush(enable)
    if enable then
        if not R.Gen.RepairEvent then Notify("Auto Gen","Missing remote",4); State.AutoGenRush=false; return end
        task.spawn(function()
            while State.AutoGenRush do
                task.wait(0.3)
                local hrp = HRP()
                if hrp then
                    local killerNear = false
                    local killer = Role.FindKiller()
                    if killer and killer.Character then
                        local khrp = killer.Character:FindFirstChild("HumanoidRootPart")
                        if khrp and (khrp.Position - hrp.Position).Magnitude <= State.GenKillerRadius then
                            State.CurrentTargetGen = nil; killerNear = true
                        end
                    end
                    if not killerNear then
                        local gens = FindAllGenerators()
                        if State.CurrentTargetGen then
                            local prog = State.CurrentTargetGen:GetAttribute("RepairProgress") or 0
                            if prog >= 100 or not State.CurrentTargetGen.Parent then
                                State.CurrentTargetGen = nil
                            end
                        end
                        if not State.CurrentTargetGen then
                            local best, bd = nil, math.huge
                            for _, g in ipairs(gens) do
                                local prog = g:GetAttribute("RepairProgress") or 0
                                if prog < 100 then
                                    local hb = g:FindFirstChild("HitBox")
                                    if hb then
                                        local d = (hb.Position - hrp.Position).Magnitude
                                        if d < bd then bd = d; best = g end
                                    end
                                end
                            end
                            State.CurrentTargetGen = best
                        end
                        if State.CurrentTargetGen then
                            local hb = State.CurrentTargetGen:FindFirstChild("HitBox")
                            local point = State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                                or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                                or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")
                            if State.AutoGenMode == "Instant" then
                                if hb and (hb.Position - hrp.Position).Magnitude > 6 then
                                    pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0,3,0) end)
                                end
                                pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point) end)
                            else
                                if hb and (hb.Position - hrp.Position).Magnitude <= 8 then
                                    pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point) end)
                                end
                            end
                        end
                    end
                end
            end
            State.CurrentTargetGen = nil
        end)
    end
end

-- AUTO SKILLCHECK
local function SetAutoSkillcheck(enable)
    if State.SkillcheckConn then pcall(function() State.SkillcheckConn:Disconnect() end); State.SkillcheckConn=nil end
    if not enable then return end
    State.SkillcheckConn = RunService.Heartbeat:Connect(function()
        if not State.AutoSkillcheck then return end
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name:find("SkillCheckPromptGui") and gui.Enabled then
                if State.SkillcheckMode == "Instant" then
                    for _, k in ipairs({Enum.KeyCode.F, Enum.KeyCode.Space}) do
                        pcall(function() VirtualInputMgr:SendKeyEvent(true, k, false, game) end)
                        task.delay(0.05, function()
                            pcall(function() VirtualInputMgr:SendKeyEvent(false, k, false, game) end)
                        end)
                    end
                    local ch = Char()
                    if ch then pcall(function()
                        ch:SetAttribute("SkillcheckPerfect", true)
                        ch:SetAttribute("SkillcheckSuccess", true)
                    end) end
                else
                    task.wait(0.15)
                    pcall(function() VirtualInputMgr:SendKeyEvent(true, Enum.KeyCode.F, false, game) end)
                    task.delay(0.05, function()
                        pcall(function() VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
                    end)
                end
            end
        end
    end)
end

-- REMOVE SKILLCHECK
local function SetRemoveSkillcheck(enable)
    if State.RemoveSCConn then pcall(function() State.RemoveSCConn:Disconnect() end); State.RemoveSCConn=nil end
    if not enable then
        local ch = Char()
        if ch then
            local sc = ch:FindFirstChild("Skillcheck-gen")
            if sc then pcall(function() sc.Disabled = false end) end
        end
        return
    end
    State.RemoveSCConn = RunService.Heartbeat:Connect(function()
        if not State.RemoveSkillcheck then return end
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name:find("SkillCheckPromptGui") and gui.Enabled then
                pcall(function() gui.Enabled = false end)
            end
        end
        local ch = Char()
        if ch then
            local sc = ch:FindFirstChild("Skillcheck-gen")
            if sc and not sc.Disabled then pcall(function() sc.Disabled = true end) end
            pcall(function() ch:SetAttribute("skillcheckfrequency", 0) end)
        end
    end)
end

-- AUTO ESCAPE
local function SetAutoEscape(enable)
    if State.AutoEscapeConn then pcall(function() State.AutoEscapeConn:Disconnect() end); State.AutoEscapeConn=nil end
    if not enable then return end
    State.AutoEscapeConn = RunService.Heartbeat:Connect(function()
        if not State.AutoEscape then return end
        task.wait(0.5)
        local hrp = HRP(); if not hrp then return end
        for _, exit in ipairs(GetExits()) do
            local switch = exit:FindFirstChild("Switch", true)
                        or exit:FindFirstChild("Lever", true)
                        or exit:FindFirstChildWhichIsA("BasePart")
            if switch then
                local sw = switch:IsA("Model") and switch:FindFirstChildWhichIsA("BasePart") or switch
                if sw then
                    local d = (sw.Position - hrp.Position).Magnitude
                    if d < 100 then
                        pcall(function() hrp.CFrame = sw.CFrame + Vector3.new(0,3,0) end)
                        task.wait(0.2)
                        if R.ExitGate then pcall(function() R.ExitGate:FireServer(exit) end) end
                        for _, r in ipairs(FindKW(Remotes,"gate")) do
                            pcall(function() r:FireServer(exit) end)
                        end
                        for _, r in ipairs(FindKW(Remotes,"exit")) do
                            pcall(function() r:FireServer(exit) end)
                        end
                        pcall(function() VirtualInputMgr:SendKeyEvent(true, Enum.KeyCode.E, false, game) end)
                        task.delay(0.1, function()
                            pcall(function() VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                        end)
                    end
                end
            end
        end
    end)
end

-- FAST VAULT
local function SetFastVault(e)
    local ch = Char()
    if ch then
        pcall(function()
            ch:SetAttribute("VaultSpeed", e and 5 or 1)
            ch:SetAttribute("FastVault", e)
            ch:SetAttribute("vaultspeed", e and 5 or 1)
        end)
    end
end

-- KILLER
local function FireHit(target)
    local ch = target and target.Character
    if not ch then return end
    if R.Attacks.Basic then pcall(function() R.Attacks.Basic:FireServer(target, ch) end) end
    if R.Attacks.Hit then pcall(function() R.Attacks.Hit:FireServer(target, ch) end) end
    if R.AttackEvent then pcall(function() R.AttackEvent:FireServer(target) end) end
    if R.KingScourge then pcall(function() R.KingScourge:FireServer(target) end) end
    if R.Killers.Frenzy then pcall(function() R.Killers.Frenzy:FireServer(target) end) end
    if R.Killers.Masked then pcall(function() R.Killers.Masked:FireServer(target) end) end
    if R.Killers.SlowAttack then pcall(function() R.Killers.SlowAttack:FireServer(target) end) end
end

local function SetAutoHit(enable)
    if State.AutoHitConn then pcall(function() State.AutoHitConn:Disconnect() end); State.AutoHitConn=nil end
    if not enable then return end
    local last = 0
    State.AutoHitConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHit then return end
        if tick() - last < 0.3 then return end
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not Role.IsKillerChar(p.Character) then
                local erp = p.Character:FindFirstChild("HumanoidRootPart")
                if erp and (erp.Position - hrp.Position).Magnitude <= State.AutoHitRange then
                    last = tick()
                    FireHit(p)
                end
            end
        end
    end)
end

local function SetKillAura(enable)
    if State.KillAuraConn then pcall(function() State.KillAuraConn:Disconnect() end); State.KillAuraConn=nil end
    if not enable then return end
    local last = 0
    State.KillAuraConn = RunService.Heartbeat:Connect(function()
        if not State.KillAura then return end
        if tick() - last < 0.15 then return end
        last = tick()
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not Role.IsKillerChar(p.Character) then
                local erp = p.Character:FindFirstChild("HumanoidRootPart")
                if erp and (erp.Position - hrp.Position).Magnitude <= State.KillAuraRange then
                    FireHit(p)
                end
            end
        end
    end)
end

local function SetHitboxExpander(enable)
    if State.HitboxConn then pcall(function() State.HitboxConn:Disconnect() end); State.HitboxConn=nil end
    if not enable then
        for part, orig in pairs(State.HitboxSaved) do
            if part and part.Parent then
                pcall(function()
                    part.Size = orig.size
                    part.Transparency = orig.trans
                    part.CanCollide = orig.cancol
                    part.Massless = orig.massless
                end)
            end
        end
        State.HitboxSaved = {}
        return
    end
    State.HitboxConn = RunService.Heartbeat:Connect(function()
        if not State.HitboxExpander then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not Role.IsKillerChar(p.Character) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    if not State.HitboxSaved[hrp] then
                        State.HitboxSaved[hrp] = {
                            size = hrp.Size, trans = hrp.Transparency,
                            cancol = hrp.CanCollide, massless = hrp.Massless,
                        }
                    end
                    pcall(function()
                        hrp.Size = Vector3.new(State.HitboxSize, State.HitboxSize, State.HitboxSize)
                        hrp.Transparency = 0.7
                        hrp.CanCollide = false
                        hrp.Massless = true
                        hrp.BrickColor = BrickColor.new("Really red")
                        hrp.Material = Enum.Material.Neon
                    end)
                end
            end
        end
    end)
end

local function SetAutoDamageGen(enable)
    if State.AutoDamageGenConn then pcall(function() State.AutoDamageGenConn:Disconnect() end); State.AutoDamageGenConn=nil end
    if not enable then return end
    State.AutoDamageGenConn = RunService.Heartbeat:Connect(function()
        if not State.AutoDamageGen then return end
        task.wait(0.3)
        local hrp = HRP(); if not hrp then return end
        for _, g in ipairs(FindAllGenerators()) do
            local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
            if hb then
                local d = (hb.Position - hrp.Position).Magnitude
                if d <= 15 then
                    if State.InstantDamageGen then
                        pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0,3,0) end)
                    end
                    if R.GenBreak.Event then pcall(function() R.GenBreak.Event:FireServer(g) end) end
                    if R.GenBreak.Commit then pcall(function() R.GenBreak.Commit:FireServer(g) end) end
                end
            end
        end
    end)
end

local instantPalletConn = nil
local function SetInstantBreakPallet(enable)
    if instantPalletConn then instantPalletConn:Disconnect(); instantPalletConn = nil end
    if not enable then return end
    instantPalletConn = RunService.Heartbeat:Connect(function()
        if not State.InstantBreakPallet then return end
        task.wait(0.2)
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(GetPallets()) do
            local pt = p:FindFirstChildWhichIsA("BasePart")
            if pt then
                local d = (pt.Position - hrp.Position).Magnitude
                if d <= 12 then
                    if R.Pallet.BreakCommit then pcall(function() R.Pallet.BreakCommit:FireServer(p) end) end
                    if R.Pallet.DropCommit then pcall(function() R.Pallet.DropCommit:FireServer(p) end) end
                end
            end
        end
    end)
end

local function SetLungeDist(e)
    local ch = Char()
    if ch then
        pcall(function()
            ch:SetAttribute("LungeDistance", e and State.LungeDistValue or 15)
            ch:SetAttribute("lungedistance", e and State.LungeDistValue or 15)
        end)
    end
end

local function SetNoStun(e)
    if State.NoStunConn then pcall(function() State.NoStunConn:Disconnect() end); State.NoStunConn=nil end
    if not e then return end
    State.NoStunConn = RunService.Heartbeat:Connect(function()
        if not State.NoStun then return end
        local c = Char()
        if c then
            pcall(function()
                c:SetAttribute("Stunned", false)
                c:SetAttribute("IsStunned", false)
                c:SetAttribute("PalletStun", false)
            end)
            if R.Pallet.JasonStunover then
                pcall(function() R.Pallet.JasonStunover:FireServer() end)
            end
        end
    end)
end

local function SetNoSlowdown(e)
    if State.NoSlowdownConn then pcall(function() State.NoSlowdownConn:Disconnect() end); State.NoSlowdownConn=nil end
    if not e then return end
    State.NoSlowdownConn = RunService.Heartbeat:Connect(function()
        if not State.NoSlowdown then return end
        local c = Char()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and Role.AmIKiller() then
            local target = State.KillerWalkSpeed and State.KillerWalkSpeedValue or State.WalkSpeed
            if h.WalkSpeed < target - 2 then
                pcall(function() h.WalkSpeed = target end)
            end
        end
        if c then
            pcall(function()
                c:SetAttribute("AttackSlowdown", 0)
                c:SetAttribute("BreakSlowdown", 0)
                c:SetAttribute("SwingCooldown", 0)
            end)
        end
    end)
end

-- VISUALS
local Vis = {}
local LB = {}
function Vis.Backup()
    if next(LB) then return end
    LB = {
        Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,
    }
end
function Vis.Restore() for k,v in pairs(LB) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e)
    Vis.Backup()
    if e then
        Lighting.Ambient=Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        Lighting.Brightness=2; Lighting.ClockTime=14
        Lighting.GlobalShadows=false
    else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup()
    if e then
        Lighting.FogEnd=999999; Lighting.FogStart=999999
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else Lighting.FogEnd=LB.FogEnd or 100000 end
end
function Vis.NoShadows(e) Vis.Backup(); Lighting.GlobalShadows = not e end
function Vis.UnlimitedZoom(e)
    if e then
        LocalPlayer.CameraMaxZoomDistance = math.huge
        LocalPlayer.CameraMinZoomDistance = 0.5
    else
        LocalPlayer.CameraMaxZoomDistance = 128
        LocalPlayer.CameraMinZoomDistance = 0.5
    end
end
function Vis.SetCrosshair(e)
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end); State.CrosshairGui=nil end
    if not e then return end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Crosshair"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.Parent = GuiParent()
    local dot = Instance.new("Frame", sg)
    dot.Size = UDim2.new(0, 4, 0, 4)
    dot.Position = UDim2.new(0.5, -2, 0.5, -2)
    dot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    for _, dir in ipairs({{"X",1,0},{"X",-1,0},{"Y",0,1},{"Y",0,-1}}) do
        local line = Instance.new("Frame", sg)
        line.BackgroundColor3 = Color3.fromRGB(255,255,255)
        line.BorderSizePixel = 0
        if dir[1] == "X" then
            line.Size = UDim2.new(0, 10, 0, 2)
            line.Position = UDim2.new(0.5, dir[2]*8, 0.5, -1)
        else
            line.Size = UDim2.new(0, 2, 0, 10)
            line.Position = UDim2.new(0.5, -1, 0.5, dir[3]*8)
        end
    end
    State.CrosshairGui = sg
end

local function SetFPSBoost(e)
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke")
        or v:IsA("Fire") or v:IsA("Sparkles") then
            pcall(function() v.Enabled = not e end)
        end
        if v:IsA("BasePart") and e then
            pcall(function()
                v.Material = Enum.Material.Plastic
                if v.Reflectance > 0 then v.Reflectance = 0 end
            end)
        end
    end
    for _, v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") then
            pcall(function() v.Enabled = not e end)
        end
    end
    pcall(function()
        settings().Rendering.QualityLevel = e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

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
        Notify("Server Hop","No server found",4)
    end)
end

CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

if R.Game.RoundEnd then
    CM:Add(R.Game.RoundEnd.Event, function()
        State.CurrentTargetGen = nil
        ESP.ClearAll(); Role.ResetKillerCache()
    end)
end
if R.Game.Start then
    CM:Add(R.Game.Start.Event, function()
        Role.ResetKillerCache(); ESP.ClearAll()
        task.wait(2); ESP.RefreshAll()
    end)
end

-- WINDUI
local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "shield",
    Author = HUB.Author.." | "..HUB.Game,
    Folder = "X0DEC04T",
    Size = UDim2.fromOffset(600, 420),
    Transparent = State.BlurBg,
    Theme = State.Theme,
    SideBarWidth = 160,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    KeySystem = false,
})

Window:EditOpenButton({
    Title = HUB.Name, Icon = "shield",
    CornerRadius = UDim.new(0,10), StrokeThickness = 2,
    Enabled = false, Draggable = true,
})

-- ═══════════════════════════════════════════
-- FLOATING LOGO (ImageLabel + invisible click)
-- ═══════════════════════════════════════════
local function CreateFloatingLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end); State.LogoGui=nil end

    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Logo"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 1000
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = GuiParent()

    local container = Instance.new("Frame")
    container.Name = "LogoContainer"
    container.Size = UDim2.new(0, 60, 0, 60)
    container.Position = UDim2.new(0, 20, 0, 100)
    container.BackgroundTransparency = 1
    container.BorderSizePixel = 0
    container.Active = true
    container.Parent = sg

    local img = Instance.new("ImageLabel")
    img.Name = "LogoImage"
    img.Size = UDim2.new(1, 0, 1, 0)
    img.Position = UDim2.new(0, 0, 0, 0)
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = HUB.LogoId
    img.ImageTransparency = 0
    img.ScaleType = Enum.ScaleType.Fit
    img.ZIndex = 2
    img.Parent = container

    local btn = Instance.new("TextButton")
    btn.Name = "LogoClickArea"
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Position = UDim2.new(0, 0, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 3
    btn.Parent = container

    btn.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {
            Size = UDim2.new(0, 70, 0, 70),
        }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {
            Size = UDim2.new(0, 60, 0, 60),
        }):Play()
    end)

    local dragging = false
    local dragStart = nil
    local startPos = nil
    local moved = false

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = container.Position
            moved = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then moved = true end
            container.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then
                pcall(function()
                    if State.UIOpen then
                        Window:Close()
                        State.UIOpen = false
                    else
                        Window:Open()
                        State.UIOpen = true
                    end
                end)
            end
            dragging = false
        end
    end)

    State.LogoGui = sg
    Log("Floating logo created")
    return sg
end
CreateFloatingLogo()

-- KEYBINDS
KB.Register("WalkSpeed", Enum.KeyCode.V, function()
    State.WalkSpeedEnabled = not State.WalkSpeedEnabled
    Move.SetWalkSpeed(State.WalkSpeedEnabled)
    Notify("Walk Speed (VV)", State.WalkSpeedEnabled and "ON" or "OFF", 1.5)
end, true)

KB.Register("AutoHeal", Enum.KeyCode.H, function()
    State.AutoHeal = not State.AutoHeal
    SetAutoHeal(State.AutoHeal)
    Notify("Auto Heal (HH)", State.AutoHeal and "ON" or "OFF", 1.5)
end, true)

KB.Register("Invisible", Enum.KeyCode.G, function()
    State.Invisible = not State.Invisible
    SetInvisible(State.Invisible)
end, true)

KB.Register("AutoParry", Enum.KeyCode.R, function()
    State.AutoParry = not State.AutoParry
    SetAutoParry(State.AutoParry)
    Notify("Auto Parry (RR)", State.AutoParry and "ON" or "OFF", 1.5)
end, true)

KB.Register("ToggleUI", Enum.KeyCode.Insert, function()
    pcall(function()
        if State.UIOpen then Window:Close(); State.UIOpen = false
        else Window:Open(); State.UIOpen = true end
    end)
end, false)

-- TABS
local Tabs = {
    Main       = Window:Tab({ Title = "Main",       Icon = "house" }),
    ESP        = Window:Tab({ Title = "ESP",        Icon = "eye" }),
    Survivor   = Window:Tab({ Title = "Survivor",   Icon = "shield" }),
    Killer     = Window:Tab({ Title = "Killer",     Icon = "sword" }),
    Visuals    = Window:Tab({ Title = "Visuals",    Icon = "sun" }),
    Misc       = Window:Tab({ Title = "Misc",       Icon = "wrench" }),
    Configs    = Window:Tab({ Title = "Configs",    Icon = "save" }),
    Keybinds   = Window:Tab({ Title = "Keybinds",   Icon = "keyboard" }),
    Settings   = Window:Tab({ Title = "Settings",   Icon = "settings" }),
    Info       = Window:Tab({ Title = "Info",       Icon = "info" }),
}

-- MAIN
Tabs.Main:Section({ Title = "Added in v"..HUB.Version })
Tabs.Main:Paragraph({
    Title = "New Features",
    Desc = "- Full Killer tab (Auto Hit, Kill Aura, Hitbox, Break, Stun/Slow)\n"
        .."- Auto Escape via exit gate switch\n"
        .."- Fast Vault\n"
        .."- Auto Parry with keybind R\n"
        .."- Color-syncing ESP\n"
        .."- Full config system\n"
        .."- Insert = toggle UI, floating logo",
})
Tabs.Main:Section({ Title = "Fixed" })
Tabs.Main:Paragraph({
    Title = "Fixed Features",
    Desc = "- Invisible: character stays free to move (visual only)\n"
        .."- Floating logo: uses ImageLabel wrapper (renders reliably)\n"
        .."- Vault/Exit filter: rejects columns/walls/decorations\n"
        .."- Duplicate GetExits removed\n"
        .."- while+continue error resolved",
})
Tabs.Main:Section({ Title = "Deleted" })
Tabs.Main:Paragraph({
    Title = "Removed Features",
    Desc = "- Spike ESP\n- Hook ESP\n- Clone/Weapon ESP",
})

-- ESP
Tabs.ESP:Section({ Title = "Players" })
Tabs.ESP:Toggle({
    Title = "Player ESP", Desc = "Highlights all players",
    Default = false,
    Callback = function(v)
        State.ESP_Player = v
        if not v and not State.ESP_Survivor and not State.ESP_Killer then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and State.ESPCache[p.Character] then ESP.Remove(p.Character) end
            end
        end
        ESP.RefreshAll()
    end,
})
Tabs.ESP:Toggle({
    Title = "Survivor ESP", Desc = "Color syncs with HP",
    Default = false,
    Callback = function(v)
        State.ESP_Survivor = v; Role.ResetKillerCache()
        if not v and not State.ESP_Player then
            local k = Role.FindKiller()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p ~= k and p.Character and State.ESPCache[p.Character] then
                    ESP.Remove(p.Character)
                end
            end
        end
        ESP.RefreshAll()
    end,
})
Tabs.ESP:Toggle({
    Title = "Killer ESP", Desc = "Red highlights",
    Default = false,
    Callback = function(v)
        State.ESP_Killer = v; Role.ResetKillerCache()
        if not v and not State.ESP_Player then
            local k = Role.FindKiller()
            if k and k.Character and State.ESPCache[k.Character] then ESP.Remove(k.Character) end
        end
        ESP.RefreshAll()
    end,
})
Tabs.ESP:Toggle({
    Title = "Zombie ESP", Desc = "Orange highlights",
    Default = false,
    Callback = function(v)
        State.ESP_Zombie = v
        if not v then for _, z in ipairs(GetZombies()) do ESP.Remove(z) end
        else ESP.ScanZombies() end
    end,
})

Tabs.ESP:Section({ Title = "Display" })
Tabs.ESP:Toggle({
    Title = "Health Bar ESP", Default = true,
    Callback = function(v) State.ESP_HealthBar = v end,
})
Tabs.ESP:Toggle({
    Title = "Distance ESP", Default = true,
    Callback = function(v) State.ESP_Distance = v end,
})

Tabs.ESP:Section({ Title = "Generators" })
Tabs.ESP:Toggle({
    Title = "Generator ESP", Desc = "Purple > Yellow > Green gradient",
    Default = false,
    Callback = function(v)
        State.ESP_Generator = v
        if not v then for _, g in ipairs(FindAllGenerators()) do ESP.Remove(g) end
        else ESP.ScanGens() end
    end,
})
Tabs.ESP:Toggle({
    Title = "Generator Progress ESP", Desc = "Big % above each gen",
    Default = false,
    Callback = function(v) State.ESP_GenProgress = v; SetGenProgressGuis(v) end,
})

Tabs.ESP:Section({ Title = "Map Objects" })
Tabs.ESP:Toggle({
    Title = "Exit Gate ESP", Default = false,
    Callback = function(v)
        State.ESP_Exit = v
        if not v then for _, e in ipairs(GetExits()) do ESP.Remove(e) end
        else ESP.ScanExits() end
    end,
})
Tabs.ESP:Toggle({
    Title = "Vault ESP", Default = false,
    Callback = function(v)
        State.ESP_Vault = v
        if not v then for _, w in ipairs(GetVaults()) do ESP.Remove(w) end
        else ESP.ScanVaults() end
    end,
})
Tabs.ESP:Toggle({
    Title = "Pallet ESP", Default = false,
    Callback = function(v)
        State.ESP_Pallet = v
        if not v then for _, p in ipairs(GetPallets()) do ESP.Remove(p) end
        else ESP.ScanPallets() end
    end,
})

Tabs.ESP:Section({ Title = "Settings" })
Tabs.ESP:Slider({
    Title = "ESP Max Distance",
    Value = { Min = 100, Max = 3000, Default = 1500 },
    Callback = function(v) State.ESP_MaxDistance = tonumber(v) or 1500 end,
})
Tabs.ESP:Button({ Title = "Refresh All ESP", Callback = function()
    ESP.ClearAll(); Role.ResetKillerCache(); ESP.RefreshAll()
    Notify("ESP","Refreshed",2)
end })
Tabs.ESP:Button({ Title = "Clear All ESP", Callback = function()
    ESP.ClearAll(); Notify("ESP","Cleared",2)
end })
Tabs.ESP:Button({ Title = "Debug: Print Detected Objects", Callback = function()
    print("=== VAULTS ("..#GetVaults()..") ===")
    for _, v in ipairs(GetVaults()) do print("  "..v:GetFullName()) end
    print("=== EXITS ("..#GetExits()..") ===")
    for _, v in ipairs(GetExits()) do print("  "..v:GetFullName()) end
    print("=== PALLETS ("..#GetPallets()..") ===")
    for _, v in ipairs(GetPallets()) do print("  "..v:GetFullName()) end
    Notify("Debug","Check output console",3)
end })

-- SURVIVOR
Tabs.Survivor:Section({ Title = "Auto Gen Rush" })
Tabs.Survivor:Slider({
    Title = "Killer Radius (stop if closer)",
    Value = { Min = 10, Max = 100, Default = 30 },
    Callback = function(v) State.GenKillerRadius = tonumber(v) or 30 end,
})
Tabs.Survivor:Dropdown({
    Title = "Gen Mode", Values = { "Legit", "Instant" }, Value = "Legit",
    Callback = function(v) State.AutoGenMode = v end,
})
Tabs.Survivor:Toggle({
    Title = "Auto Gen Rush", Default = false,
    Callback = function(v) State.AutoGenRush = v; SetAutoGenRush(v) end,
})

Tabs.Survivor:Section({ Title = "Skillcheck" })
Tabs.Survivor:Dropdown({
    Title = "Skillcheck Mode", Values = { "Legit", "Instant" }, Value = "Legit",
    Callback = function(v)
        State.SkillcheckMode = v
        if State.AutoSkillcheck then SetAutoSkillcheck(true) end
    end,
})
Tabs.Survivor:Toggle({
    Title = "Auto Perfect Skillcheck", Default = false,
    Callback = function(v) State.AutoSkillcheck = v; SetAutoSkillcheck(v) end,
})
Tabs.Survivor:Toggle({
    Title = "Remove Skillcheck", Default = false,
    Callback = function(v) State.RemoveSkillcheck = v; SetRemoveSkillcheck(v) end,
})

Tabs.Survivor:Section({ Title = "Auto Heal (Double-tap H)" })
Tabs.Survivor:Slider({
    Title = "Heal Below HP %",
    Value = { Min = 10, Max = 95, Default = 60 },
    Callback = function(v) State.AutoHealThreshold = tonumber(v) or 60 end,
})
Tabs.Survivor:Toggle({
    Title = "Auto Heal", Default = false,
    Callback = function(v) State.AutoHeal = v; SetAutoHeal(v) end,
})

Tabs.Survivor:Section({ Title = "Auto Parry (Double-tap R)" })
Tabs.Survivor:Slider({
    Title = "Killer Attack Radius",
    Value = { Min = 5, Max = 80, Default = 25 },
    Callback = function(v) State.ParryRange = tonumber(v) or 25 end,
})
Tabs.Survivor:Toggle({
    Title = "Auto Parry", Default = false,
    Callback = function(v) State.AutoParry = v; SetAutoParry(v) end,
})

Tabs.Survivor:Section({ Title = "Escape" })
Tabs.Survivor:Toggle({
    Title = "Auto Escape", Default = false,
    Callback = function(v) State.AutoEscape = v; SetAutoEscape(v) end,
})
Tabs.Survivor:Toggle({
    Title = "Fast Vault", Default = false,
    Callback = function(v) State.FastVault = v; SetFastVault(v) end,
})

Tabs.Survivor:Section({ Title = "Movement" })
Tabs.Survivor:Toggle({
    Title = "No Fall Damage", Default = false,
    Callback = function(v) State.NoFallDamage = v; SetNoFall(v) end,
})
Tabs.Survivor:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 60, Default = 28 },
    Callback = function(v)
        State.WalkSpeedValue = tonumber(v) or 28
        if State.WalkSpeedEnabled and not Role.AmIKiller() then Move.SetWalkSpeed(true) end
    end,
})
Tabs.Survivor:Toggle({
    Title = "Walk Speed (Double-tap V)", Default = false,
    Callback = function(v) State.WalkSpeedEnabled = v; Move.SetWalkSpeed(v) end,
})

Tabs.Survivor:Section({ Title = "Invisible (Double-tap G)" })
Tabs.Survivor:Paragraph({
    Title = "How It Works",
    Desc = "Visual only - you can move around freely.\n"
        .."Uses LocalTransparencyModifier + Untargettable attribute.",
})
Tabs.Survivor:Toggle({
    Title = "Invisible", Default = false,
    Callback = function(v) State.Invisible = v; SetInvisible(v) end,
})

-- KILLER
Tabs.Killer:Section({ Title = "Auto Hit" })
Tabs.Killer:Slider({
    Title = "Hit Range", Value = { Min = 5, Max = 40, Default = 12 },
    Callback = function(v) State.AutoHitRange = tonumber(v) or 12 end,
})
Tabs.Killer:Toggle({
    Title = "Auto Hit", Default = false,
    Callback = function(v) State.AutoHit = v; SetAutoHit(v) end,
})

Tabs.Killer:Section({ Title = "Kill Aura" })
Tabs.Killer:Slider({
    Title = "Aura Range", Value = { Min = 5, Max = 60, Default = 20 },
    Callback = function(v) State.KillAuraRange = tonumber(v) or 20 end,
})
Tabs.Killer:Toggle({
    Title = "Kill Aura", Default = false,
    Callback = function(v) State.KillAura = v; SetKillAura(v) end,
})

Tabs.Killer:Section({ Title = "Hitbox Expander" })
Tabs.Killer:Slider({
    Title = "Hitbox Size", Value = { Min = 3, Max = 30, Default = 8 },
    Callback = function(v) State.HitboxSize = tonumber(v) or 8 end,
})
Tabs.Killer:Toggle({
    Title = "Hitbox Expander", Default = false,
    Callback = function(v) State.HitboxExpander = v; SetHitboxExpander(v) end,
})

Tabs.Killer:Section({ Title = "Generator Damage" })
Tabs.Killer:Toggle({
    Title = "Instant Generator Damage", Default = false,
    Callback = function(v) State.InstantDamageGen = v end,
})
Tabs.Killer:Toggle({
    Title = "Auto Damage Generator", Default = false,
    Callback = function(v) State.AutoDamageGen = v; SetAutoDamageGen(v) end,
})

Tabs.Killer:Section({ Title = "Pallet" })
Tabs.Killer:Toggle({
    Title = "Instant Break Pallet", Default = false,
    Callback = function(v) State.InstantBreakPallet = v; SetInstantBreakPallet(v) end,
})

Tabs.Killer:Section({ Title = "Movement" })
Tabs.Killer:Slider({
    Title = "Walk Speed", Value = { Min = 16, Max = 80, Default = 30 },
    Callback = function(v)
        State.KillerWalkSpeedValue = tonumber(v) or 30
        if State.KillerWalkSpeed and Role.AmIKiller() then Move.SetWalkSpeed(true) end
    end,
})
Tabs.Killer:Toggle({
    Title = "Walk Speed (Killer)", Default = false,
    Callback = function(v) State.KillerWalkSpeed = v; Move.SetWalkSpeed(v) end,
})
Tabs.Killer:Slider({
    Title = "Lunge Distance", Value = { Min = 10, Max = 80, Default = 30 },
    Callback = function(v)
        State.LungeDistValue = tonumber(v) or 30
        if State.LungeDist then SetLungeDist(true) end
    end,
})
Tabs.Killer:Toggle({
    Title = "Lunge Distance", Default = false,
    Callback = function(v) State.LungeDist = v; SetLungeDist(v) end,
})

Tabs.Killer:Section({ Title = "Immunity" })
Tabs.Killer:Toggle({
    Title = "No Stun", Default = false,
    Callback = function(v) State.NoStun = v; SetNoStun(v) end,
})
Tabs.Killer:Toggle({
    Title = "No Slowdown", Default = false,
    Callback = function(v) State.NoSlowdown = v; SetNoSlowdown(v) end,
})

Tabs.Killer:Section({ Title = "Invisible (Double-tap G)" })
Tabs.Killer:Toggle({
    Title = "Invisible", Default = false,
    Callback = function(v) State.Invisible = v; SetInvisible(v) end,
})

-- VISUALS
Tabs.Visuals:Section({ Title = "Lighting" })
Tabs.Visuals:Toggle({
    Title = "Full Bright", Default = false,
    Callback = function(v) State.FullBright = v; Vis.FullBright(v) end,
})
Tabs.Visuals:Toggle({
    Title = "No Fog", Default = false,
    Callback = function(v) State.NoFog = v; Vis.NoFog(v) end,
})
Tabs.Visuals:Toggle({
    Title = "Remove Shadows", Default = false,
    Callback = function(v) State.NoShadows = v; Vis.NoShadows(v) end,
})

Tabs.Visuals:Section({ Title = "Camera" })
Tabs.Visuals:Toggle({
    Title = "Unlimited Zoom", Default = false,
    Callback = function(v) State.UnlimitedZoom = v; Vis.UnlimitedZoom(v) end,
})
Tabs.Visuals:Toggle({
    Title = "Crosshair", Default = false,
    Callback = function(v) State.Crosshair = v; Vis.SetCrosshair(v) end,
})

-- MISC
Tabs.Misc:Section({ Title = "Performance" })
Tabs.Misc:Toggle({
    Title = "Anti AFK", Default = true,
    Callback = function(v) State.AntiAFK = v end,
})
Tabs.Misc:Toggle({
    Title = "FPS Boost", Default = false,
    Callback = function(v) State.FPSBoost = v; SetFPSBoost(v) end,
})

Tabs.Misc:Section({ Title = "Server" })
Tabs.Misc:Button({
    Title = "Rejoin Server",
    Callback = function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end,
})
Tabs.Misc:Button({ Title = "Server Hop", Callback = ServerHop })

-- CONFIGS
local currentConfigName = ""
Tabs.Configs:Section({ Title = "Create / Save" })
Tabs.Configs:Input({
    Title = "Config Name", Placeholder = "MyConfig",
    Callback = function(v) currentConfigName = tostring(v or "") end,
})
Tabs.Configs:Button({
    Title = "Create Config", Callback = function()
        if currentConfigName == "" then Notify("Config","Enter a name",2); return end
        Config.Save(currentConfigName)
    end,
})
Tabs.Configs:Button({
    Title = "Save Config", Callback = function()
        if currentConfigName == "" then Notify("Config","Enter a name",2); return end
        Config.Save(currentConfigName)
    end,
})

Tabs.Configs:Section({ Title = "Load / Delete" })
local configDropdown = Tabs.Configs:Dropdown({
    Title = "Select Config", Values = Config.List(), Value = "",
    Callback = function(v) currentConfigName = v end,
})
Tabs.Configs:Button({
    Title = "Load Config", Callback = function()
        if currentConfigName == "" then Notify("Config","Select a config",2); return end
        if Config.Load(currentConfigName) then
            Config.SaveLastLoaded(currentConfigName)
            Notify("Config","Restart script to fully apply",4)
        end
    end,
})
Tabs.Configs:Button({
    Title = "Delete Config", Callback = function()
        if currentConfigName == "" then Notify("Config","Select a config",2); return end
        Config.Delete(currentConfigName)
        if configDropdown and configDropdown.Refresh then
            pcall(function() configDropdown:Refresh(Config.List()) end)
        end
    end,
})
Tabs.Configs:Button({
    Title = "Refresh List", Callback = function()
        if configDropdown and configDropdown.Refresh then
            pcall(function() configDropdown:Refresh(Config.List()) end)
        end
        Notify("Config","List refreshed",2)
    end,
})

Tabs.Configs:Section({ Title = "Auto Load" })
Tabs.Configs:Toggle({
    Title = "Auto Load Config on Join", Default = false,
    Callback = function(v) State.AutoLoadConfig = v end,
})

-- KEYBINDS
Tabs.Keybinds:Section({ Title = "Keybind List" })
Tabs.Keybinds:Paragraph({
    Title = "Current Bindings",
    Desc = "Toggle UI       Insert (single tap)\n"
        .."Walk Speed      V (double-tap)\n"
        .."Invisible       G (double-tap)\n"
        .."Auto Heal       H (double-tap)\n"
        .."Auto Parry      R (double-tap)",
})

Tabs.Keybinds:Section({ Title = "Change Keybinds" })
Tabs.Keybinds:Keybind({
    Title = "Toggle UI", Default = "Insert",
    Callback = function(k) KB.SetKey("ToggleUI", k) end,
})
Tabs.Keybinds:Keybind({
    Title = "Walk Speed", Default = "V",
    Callback = function(k) KB.SetKey("WalkSpeed", k) end,
})
Tabs.Keybinds:Keybind({
    Title = "Invisible", Default = "G",
    Callback = function(k) KB.SetKey("Invisible", k) end,
})
Tabs.Keybinds:Keybind({
    Title = "Auto Heal", Default = "H",
    Callback = function(k) KB.SetKey("AutoHeal", k) end,
})
Tabs.Keybinds:Keybind({
    Title = "Auto Parry", Default = "R",
    Callback = function(k) KB.SetKey("AutoParry", k) end,
})

Tabs.Keybinds:Section({ Title = "Options" })
Tabs.Keybinds:Toggle({
    Title = "Block Keybinds While Typing", Default = true,
    Callback = function(v) KB.BlockWhileTyping = v end,
})
Tabs.Keybinds:Slider({
    Title = "Double-Tap Window (x0.05s)",
    Value = { Min = 3, Max = 20, Default = 7 },
    Callback = function(v) KB.DoubleTapWindow = (tonumber(v) or 7) * 0.05 end,
})

-- SETTINGS
Tabs.Settings:Section({ Title = "Appearance" })
Tabs.Settings:Dropdown({
    Title = "UI Theme",
    Values = { "Dark", "Light", "Rose", "Plant" },
    Value = "Dark",
    Callback = function(v)
        State.Theme = v
        pcall(function() WindUI:SetTheme(v) end)
    end,
})
Tabs.Settings:Slider({
    Title = "UI Scale", Value = { Min = 70, Max = 130, Default = 100 },
    Callback = function(v)
        State.UIScale = (tonumber(v) or 100) / 100
        pcall(function() Window:SetSize(UDim2.fromOffset(600 * State.UIScale, 420 * State.UIScale)) end)
    end,
})
Tabs.Settings:Toggle({
    Title = "Blur Background", Default = true,
    Callback = function(v)
        State.BlurBg = v
        pcall(function() Window:ToggleTransparency(v) end)
    end,
})

Tabs.Settings:Section({ Title = "Behavior" })
Tabs.Settings:Toggle({
    Title = "Sound Effects", Default = true,
    Callback = function(v) State.SoundEffects = v end,
})
Tabs.Settings:Toggle({
    Title = "Notifications", Default = true,
    Callback = function(v) State.Notifications = v end,
})
Tabs.Settings:Toggle({
    Title = "Show Floating Logo", Default = true,
    Callback = function(v)
        if v then
            if not State.LogoGui or not State.LogoGui.Parent then CreateFloatingLogo()
            else State.LogoGui.Enabled = true end
        else
            if State.LogoGui then State.LogoGui.Enabled = false end
        end
    end,
})

Tabs.Settings:Button({
    Title = "Force Recreate Floating Logo",
    Callback = function()
        CreateFloatingLogo()
        Notify("Logo","Recreated at top-left",3)
    end,
})

Tabs.Settings:Section({ Title = "Reset" })
Tabs.Settings:Button({
    Title = "Reset UI", Callback = function()
        pcall(function() Window:Close() end)
        task.wait(0.2)
        pcall(function() Window:Open() end)
        State.UIOpen = true
        Notify("UI","Reset",2)
    end,
})

Tabs.Settings:Section({ Title = "Danger" })
Tabs.Settings:Button({
    Title = "Unload Hub", Callback = function()
        for _, k in ipairs({
            "NoFallConn","InvisibleConn","AutoHealConn","AutoParryConn",
            "SkillcheckConn","RemoveSCConn","AutoEscapeConn",
            "AutoHitConn","KillAuraConn","AutoDamageGenConn",
            "HitboxConn","NoStunConn","NoSlowdownConn",
        }) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        if instantPalletConn then pcall(function() instantPalletConn:Disconnect() end) end
        State.AutoGenRush=false; State.ESP_GenProgress=false
        State.Invisible=false; State.AutoHeal=false; State.AutoParry=false
        State.HitboxExpander=false; State.KillAura=false; State.AutoHit=false
        SetInvisible(false); SetGenProgressGuis(false); SetAutoHeal(false)
        SetAutoSkillcheck(false); SetRemoveSkillcheck(false); SetAutoParry(false)
        SetHitboxExpander(false); SetKillAura(false); SetAutoHit(false)
        SetNoStun(false); SetNoSlowdown(false); Vis.SetCrosshair(false)
        Vis.Restore()
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = Hum()
        end)
        LocalPlayer.CameraMaxZoomDistance = 128
        if ESPRender then ESPRender:Disconnect() end
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end) end
        CM:Cleanup(); ESP.ClearAll()
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end,
})

-- INFO
Tabs.Info:Section({ Title = "About" })
Tabs.Info:Paragraph({
    Title = HUB.Name.." v"..HUB.Version,
    Desc = "Game: "..HUB.Game.."\nDeveloper: "..HUB.Author,
})
Tabs.Info:Section({ Title = "Community" })
Tabs.Info:Button({
    Title = "Discord Server", Callback = function()
        if setclipboard then
            setclipboard(HUB.Discord)
            Notify("Discord","Link copied: "..HUB.Discord,4)
        else
            Notify("Discord",HUB.Discord,5)
        end
    end,
})
Tabs.Info:Section({ Title = "Developer" })
Tabs.Info:Paragraph({
    Title = "Made By",
    Desc = HUB.Author.."\n\nSpecial thanks to WindUI by Footagesus",
})

-- CHARACTER RESPAWN
CM:Add(LocalPlayer.CharacterAdded, function()
    invisibleSavedTransp = {}
    pcall(function() Camera.CameraType = Enum.CameraType.Custom end)
    if State.Invisible then
        State.Invisible = false
        if State.InvisibleConn then
            pcall(function() State.InvisibleConn:Disconnect() end)
            State.InvisibleConn = nil
        end
    end
    task.wait(1.5)
    Role.ResetKillerCache()
    pcall(Move.Speed)
    if State.WalkSpeedEnabled then pcall(Move.SetWalkSpeed, true) end
    if State.KillerWalkSpeed then pcall(Move.SetWalkSpeed, true) end
    if State.NoFallDamage then pcall(SetNoFall, true) end
    if State.AutoHeal then pcall(SetAutoHeal, true) end
    if State.AutoParry then pcall(SetAutoParry, true) end
    if State.RemoveSkillcheck then pcall(SetRemoveSkillcheck, true) end
    if State.AutoSkillcheck then pcall(SetAutoSkillcheck, true) end
    if State.AutoHit then pcall(SetAutoHit, true) end
    if State.KillAura then pcall(SetKillAura, true) end
    if State.HitboxExpander then pcall(SetHitboxExpander, true) end
    if State.NoStun then pcall(SetNoStun, true) end
    if State.NoSlowdown then pcall(SetNoSlowdown, true) end
    if State.FastVault then pcall(SetFastVault, true) end
    if State.LungeDist then pcall(SetLungeDist, true) end
    if State.UnlimitedZoom then pcall(Vis.UnlimitedZoom, true) end
    task.wait(0.5); ESP.RefreshAll()
    if State.ESP_GenProgress then SetGenProgressGuis(true) end
end)

-- AUTO LOAD CONFIG
task.spawn(function()
    task.wait(1)
    if State.AutoLoadConfig then
        local last = Config.GetLastLoaded()
        if last and last ~= "" then
            Config.Load(last)
            Notify("Config","Auto-loaded: "..last, 3)
        end
    end
end)

-- GLOBAL INSTANCE
_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        for _, k in ipairs({
            "NoFallConn","InvisibleConn","AutoHealConn","AutoParryConn",
            "SkillcheckConn","RemoveSCConn","AutoEscapeConn",
            "AutoHitConn","KillAuraConn","AutoDamageGenConn",
            "HitboxConn","NoStunConn","NoSlowdownConn",
        }) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        if instantPalletConn then pcall(function() instantPalletConn:Disconnect() end) end
        State.AutoGenRush=false
        SetInvisible(false); SetGenProgressGuis(false); SetAutoHeal(false)
        SetAutoSkillcheck(false); SetRemoveSkillcheck(false); SetAutoParry(false)
        SetHitboxExpander(false); SetKillAura(false); SetAutoHit(false)
        SetNoStun(false); SetNoSlowdown(false); Vis.SetCrosshair(false); Vis.Restore()
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = Hum()
        end)
        LocalPlayer.CameraMaxZoomDistance = 128
        if ESPRender then ESPRender:Disconnect() end
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." | Insert=UI | V/G/H/R=double-tap", 5)
Log("v0.7.1 fully loaded")
