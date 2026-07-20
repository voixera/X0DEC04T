--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.7.0 - Violence District [WindUI]
-- Production fixes:
--   * Invisible v7 - Void Teleport Y=9000 + can move + gen works + ESP stays
--   * Auto Parry v6 - AnimationPlayed + attribute polling + rebind
--   * Auto Skillcheck v10 - Confirmed CCW rotation mechanic
--═══════════════════════════════════════════════════════════════════════════════

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
local LocalizationService = game:GetService("LocalizationService")
local ContentProvider   = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_v170"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("v1.7.0 starting")

local WindUI = nil
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then WindUI = r; break end
end
if not WindUI then warn("WindUI failed"); return end
pcall(function() if WindUI.SetLanguage then WindUI:SetLanguage("en") end end)

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.1",
    Author  = "voixera",
    LogoId  = "rbxassetid://85104740393904",
    Discord = "discord.gg/x0dec04t",
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
function KB.SetKey(name, key) if KB._binds[name] then KB._binds[name].key = key end end

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

-- REMOTES
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local function GR(...)
    if not Remotes then return nil end
    local c = Remotes
    for _, n in ipairs({...}) do c = c:FindFirstChild(n); if not c then return nil end end
    return c
end

local R = {
    Gen = {
        RepairEvent = GR("Generator","RepairEvent"),
        BreakEvent  = GR("Generator","BreakGenEvent"),
        BreakCommit = GR("Generator","BreakGenCommit"),
    },
    SkillCheck = {
        GenResult  = GR("Generator","SkillCheckResultEvent"),
        GenEvent   = GR("Generator","SkillCheckEvent"),
        HealResult = GR("Healing","SkillCheckResultEvent"),
    },
    Heal              = GR("Healing","HealEvent"),
    AdrenalineHealthy = GR("Items","Adrenaline Shot","Healthy"),
    Parry             = GR("Items","Parrying Dagger","parry"),
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
    ShadowClone = GR("Items","Shadow Clone","clonespawn"),
}

Log("Parry: "     .. (R.Parry             and "OK" or "MISSING"))
Log("SC Result: " .. (R.SkillCheck.GenResult and "OK" or "MISSING"))
Log("RepairEvent: ".. (R.Gen.RepairEvent   and "OK" or "MISSING"))

-- OBJECT FINDERS
local function FindAllGenerators()
    local list = {}
    local map  = Workspace:FindFirstChild("Map")
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
            for _, existing in ipairs(list) do if existing == v then exists = true; break end end
            if not exists then table.insert(list, v) end
        end
    end
    return list
end

local function GetPallets()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "Palletwrong" or v.Name == "Pallet") then
            table.insert(list, v)
        end
    end
    return list
end

local function GetVaults()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Window" then
            table.insert(list, v)
        end
    end
    return list
end

local function GetExits()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Gate" then
            table.insert(list, v)
        end
    end
    return list
end

local function GetZombies()
    local list = {}
    local clones = Workspace:FindFirstChild("Clones")
    if clones then
        for _, obj in ipairs(clones:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                table.insert(list, obj)
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            local name = obj.Name:lower()
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true; break end
            end
            if not isPlayer then
                if name:find("infected") or name:find("corpse") or name:find("minion")
                or name:find("cure") or name:find("zombie") or name:find("puppet") then
                    local exists = false
                    for _, e in ipairs(list) do if e == obj then exists = true; break end end
                    if not exists then table.insert(list, obj) end
                end
            end
        end
    end
    return list
end

-- STATE
local State = {
    ESP_Player   = false, ESP_Survivor = false, ESP_Killer   = false,
    ESP_Zombie   = false, ESP_HealthBar= true,  ESP_Distance = true,
    ESP_Generator= false,
    ESP_Vault    = false, ESP_Pallet   = false, ESP_Exit     = false,
    ESP_MaxDistance = 1500,

    Color_Killer  = Color3.fromRGB(255,40,40),
    Color_Vault   = Color3.fromRGB(180,60,220),
    Color_Pallet  = Color3.fromRGB(255,140,20),
    Color_Zombie  = Color3.fromRGB(255,140,20),
    Color_Exit    = Color3.fromRGB(255,255,255),

    AutoGenRush       = false, GenKillerRadius   = 30, AutoGenMode = "Legit",
    AutoSkillcheck    = false, SkillcheckMode    = "Fast",
    RemoveSkillcheck  = false,
    AutoHeal          = false, AutoHealThreshold = 60, LastHealTime = 0,
    AutoParry         = false, ParryRange        = 25, ParryPredictive = true,
    DaggerCooldownEstimate  = 90,
    LastDaggerUse           = 0,
    DaggerNotifiedCooldown  = false,
    IsCurrentlyParrying     = false,
    IsMobile        = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    MobileParryButton = nil,
    LastParryTime   = 0,
    KillerLastPos   = nil,
    KillerVelocity  = Vector3.zero,
    FastVault       = false, NoFallDamage = false,
    WalkSpeedEnabled= false, WalkSpeedValue = 28,
    Invisible       = false, UnlockCursor   = false,

    AutoHit         = false, AutoHitRange = 12,
    AutoHitAll      = false, AutoHitAllDelay = 5,

    AutoDamageGen   = false, InstantDamageGen   = false,
    InstantBreakPallet = false,
    KillerWalkSpeed = false, KillerWalkSpeedValue = 30,
    NoStun          = false, NoSlowdown = false,

    FullBright      = false, NoFog = false, NoShadows = false,
    UnlimitedZoom   = false, Crosshair = false,

    AntiAFK         = true,  FPSBoost  = false,
    Theme           = "Dark", BlurBg   = true, Notifications = true,
    ShowFloatingLogo= true,

    WalkSpeed       = 16, ESPCache = {},
    CachedKiller    = nil, KillerCacheTime = 0, CurrentTargetGen = nil,
    UIOpen          = true, LogoGui = nil, CrosshairGui = nil,

    -- Invis state
    InvisOriginalCF = nil,
    InvisVoidPos    = Vector3.new(0, 9000, 0),
    InvisVoidY      = 9000,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        WindUI:Notify({ Title=tostring(t), Content=tostring(c), Duration=tonumber(d) or 3, Icon="bell" })
    end)
end
local function Char() return LocalPlayer.Character end
local function HRP()  local c = Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum()  local c = Char(); return c and c:FindFirstChildOfClass("Humanoid") end

local function LerpColor(c1, c2, t)
    return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t)
end
local function GetGradientColor(pct)
    if pct <= 0.5 then return LerpColor(Color3.fromRGB(180,60,220), Color3.fromRGB(255,220,60), pct*2)
    else return LerpColor(Color3.fromRGB(255,220,60), Color3.fromRGB(60,220,60), (pct-0.5)*2) end
end
local function GetHealthColor(pct)
    if pct > 0.6 then return Color3.fromRGB(60,220,60)
    elseif pct > 0.3 then return Color3.fromRGB(255,180,60)
    else return Color3.fromRGB(255,50,50) end
end

-- ROLE DETECTION
local KILLER_UNIQUE_ATTRS = {
    "Chasemusic","TerrorRadius","Suspense","SuspenseRadius","BloodLust"
}
local SURVIVOR_UNIQUE_ATTRS = {
    "vaultspeed","healboost","Parry","Iframes","repairboost",
    "skillcheckspeed","skillcheckfrequency","wereStrongerTogether",
    "bleedboost","unhookspeed","healnerf"
}

local Role = {}
function Role.IsKillerChar(char)
    if not char then return false end
    local killerScore = 0
    for _, a in ipairs(KILLER_UNIQUE_ATTRS) do
        if char:GetAttribute(a) ~= nil then killerScore += 1 end
    end
    local survivorScore = 0
    for _, a in ipairs(SURVIVOR_UNIQUE_ATTRS) do
        if char:GetAttribute(a) ~= nil then survivorScore += 1 end
    end
    if killerScore >= 3 and survivorScore < 3 then return true end
    if killerScore >= 2 and char:FindFirstChild("Weapon") and char.Weapon:IsA("Model") then
        return true
    end
    return false
end
function Role.FindKiller()
    if State.CachedKiller then
        local p = State.CachedKiller
        if not p.Parent or not p.Character or not Role.IsKillerChar(p.Character) then
            State.CachedKiller = nil
        end
    end
    if State.CachedKiller and (tick() - State.KillerCacheTime) < 2 then
        return State.CachedKiller
    end
    State.CachedKiller = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and Role.IsKillerChar(p.Character) then
            State.CachedKiller = p; State.KillerCacheTime = tick(); return p
        end
    end
    return nil
end
function Role.ResetKillerCache() State.CachedKiller = nil; State.KillerCacheTime = 0 end
function Role.AmIKiller()   local c = Char(); return c and Role.IsKillerChar(c) end
function Role.AmISurvivor()
    local c = Char(); if not c then return false end
    return c:GetAttribute("vaultspeed") ~= nil or c:GetAttribute("Parry") ~= nil
end

local function GetAllSurvivors()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if not Role.IsKillerChar(p.Character) then table.insert(list, p) end
        end
    end
    return list
end

-- ═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
-- Works even when invisible (uses world-space objects, not character)
-- ═══════════════════════════════════════════════════════════════
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name          = "X0_ESP"
    ESPGui.ResetOnSpawn  = false
    ESPGui.IgnoreGuiInset= true
    ESPGui.DisplayOrder  = 999
    ESPGui.Parent        = GuiParent()
end

local function GetRootPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj:FindFirstChild("HitBox")
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChild("UpperTorso")
            or obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart")
    end
end

local function MakeEntry(obj, label, color, isChar, kind, highlightOnly)
    local rp = GetRootPart(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee           = obj
    hl.FillColor         = color
    hl.OutlineColor      = color
    hl.FillTransparency  = isChar and 0.5 or 0.6
    hl.OutlineTransparency = 0
    hl.DepthMode         = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent            = Workspace

    if highlightOnly then
        return { rp=rp, obj=obj, hl=hl, bb=nil, nl=nil, dl=nil, hp=nil, isChar=isChar, color=color, kind=kind }
    end

    local bb = Instance.new("BillboardGui")
    bb.Size         = UDim2.new(0, 200, 0, isChar and 55 or 40)
    bb.StudsOffset  = Vector3.new(0, isChar and 2.5 or 2, 0)
    bb.AlwaysOnTop  = true
    bb.LightInfluence = 0
    bb.MaxDistance  = State.ESP_MaxDistance
    bb.Adornee      = rp
    bb.Parent       = ESPGui

    local layout = Instance.new("UIListLayout", bb)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment   = Enum.VerticalAlignment.Bottom

    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1,0,0,18); nl.BackgroundTransparency = 1
    nl.Text = label; nl.TextColor3 = color
    nl.TextStrokeTransparency = 0.3; nl.Font = Enum.Font.GothamBold; nl.TextSize = 13

    local hp = nil
    if isChar then
        hp = Instance.new("TextLabel", bb)
        hp.Size = UDim2.new(1,0,0,14); hp.BackgroundTransparency = 1
        hp.Text = "[HP] ?"; hp.TextColor3 = Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency = 0.3; hp.Font = Enum.Font.GothamBold; hp.TextSize = 12
    end

    local dl = Instance.new("TextLabel", bb)
    dl.Size = UDim2.new(1,0,0,12); dl.BackgroundTransparency = 1
    dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency = 0.3; dl.Font = Enum.Font.Gotham; dl.TextSize = 11

    return { rp=rp, obj=obj, hl=hl, bb=bb, nl=nl, dl=dl, hp=hp, isChar=isChar, color=color, kind=kind }
end

function ESP.Add(obj, label, color, isChar, kind, highlightOnly)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeEntry(obj, label, color, isChar or false, kind, highlightOnly)
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

-- ──────────────────────────────────────────────────────────────
-- ESP RENDER: Distance calculated from REAL world position
-- When invisible, we use InvisOriginalCF (where player visually is)
-- NOT from HRP (which is at Y=9000)
-- ──────────────────────────────────────────────────────────────
local ESPRender = RunService.RenderStepped:Connect(function()
    -- Get reference position for distance calculation
    local refPos
    if State.Invisible and State.InvisOriginalCF then
        -- Use the virtual (camera) position so distances make sense
        refPos = Camera.CFrame.Position
    else
        local hrp = HRP()
        refPos = hrp and hrp.Position or Vector3.zero
    end

    local rem = {}
    for obj, e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then
            table.insert(rem, obj)
        else
            local rp = GetRootPart(obj)
            if not rp then
                table.insert(rem, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function()
                        e.hl.Adornee = obj
                        if e.bb then e.bb.Adornee = rp end
                    end)
                end

                local dist = (rp.Position - refPos).Magnitude
                local vis  = dist <= State.ESP_MaxDistance
                pcall(function()
                    e.hl.Enabled = vis
                    if e.bb then
                        e.bb.MaxDistance = State.ESP_MaxDistance
                        e.bb.Enabled     = vis
                        if e.dl then
                            e.dl.Text    = math.floor(dist) .. "m"
                            e.dl.Visible = State.ESP_Distance
                        end
                    end
                end)

                if e.isChar and e.hp then
                    pcall(function()
                        local h  = obj:FindFirstChildOfClass("Humanoid")
                        if h then
                            local hp  = math.floor(h.Health)
                            local mx  = math.floor(h.MaxHealth)
                            local pct = (mx > 0) and hp / mx or 0
                            e.hp.Text       = "[HP] " .. hp .. "/" .. mx
                            e.hp.TextColor3 = GetHealthColor(pct)
                            e.hp.Visible    = State.ESP_HealthBar
                            if e.kind == "survivor" then
                                local hc = GetHealthColor(pct)
                                e.hl.FillColor    = hc
                                e.hl.OutlineColor = hc
                                if e.nl then e.nl.TextColor3 = hc end
                            end
                        end
                    end)
                end

                if e.kind == "generator" and obj:IsA("Model") and e.nl then
                    pcall(function()
                        local prog = obj:GetAttribute("RepairProgress") or 0
                        local col  = GetGradientColor(prog / 100)
                        e.hl.FillColor    = col
                        e.hl.OutlineColor = col
                        e.nl.TextColor3   = col
                        e.nl.Text         = "[GEN] " .. math.floor(prog) .. "%"
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
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            local char = p.Character
            local isK  = (p == killer)
            local show, label, color, kind = false, nil, nil, nil
            if State.ESP_Player then
                show  = true
                label = "[" .. p.Name .. "]"
                color = isK and State.Color_Killer or Color3.fromRGB(60,220,60)
                kind  = isK and "killer" or "survivor"
            end
            if isK and State.ESP_Killer then
                show = true; label = "[KILLER] " .. p.Name
                color = State.Color_Killer; kind = "killer"
            end
            if not isK and State.ESP_Survivor then
                show = true; label = "[SURV] " .. p.Name
                color = Color3.fromRGB(60,220,60); kind = "survivor"
            end
            if show then
                if not State.ESPCache[char] then ESP.Add(char, label, color, true, kind, false) end
            else
                if State.ESPCache[char] then ESP.Remove(char) end
            end
        end
    end
end

function ESP.ScanZombies()
    local zombies = GetZombies()
    local zMap = {}
    for _, z in ipairs(zombies) do zMap[z] = true end
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "zombie" and not zMap[obj] then
            ESP.Remove(obj)
        end
    end
    for _, z in ipairs(zombies) do
        if State.ESP_Zombie then
            if not State.ESPCache[z] then
                ESP.Add(z, "[CURE] " .. z.Name, State.Color_Zombie, true, "zombie", false)
            end
        else
            if State.ESPCache[z] then ESP.Remove(z) end
        end
    end
end

function ESP.ScanGens()
    local gens = FindAllGenerators()
    local gMap = {}
    for _, g in ipairs(gens) do gMap[g] = true end
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "generator" and not gMap[obj] then
            ESP.Remove(obj)
        end
    end
    for _, g in ipairs(gens) do
        if State.ESP_Generator then
            if not State.ESPCache[g] then
                local prog = g:GetAttribute("RepairProgress") or 0
                local col  = GetGradientColor(prog / 100)
                ESP.Add(g, "[GEN] " .. math.floor(prog) .. "%", col, false, "generator", false)
            end
        else
            if State.ESPCache[g] then ESP.Remove(g) end
        end
    end
end

function ESP.ScanPallets()
    local pallets = GetPallets()
    local pMap = {}
    for _, p in ipairs(pallets) do pMap[p] = true end
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "pallet" and not pMap[obj] then
            ESP.Remove(obj)
        end
    end
    for _, p in ipairs(pallets) do
        if State.ESP_Pallet then
            if not State.ESPCache[p] then
                ESP.Add(p, "", State.Color_Pallet, false, "pallet", true)
            end
        else
            if State.ESPCache[p] then ESP.Remove(p) end
        end
    end
end

function ESP.ScanVaults()
    local vaults = GetVaults()
    local vMap = {}
    for _, v in ipairs(vaults) do vMap[v] = true end
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "vault" and not vMap[obj] then
            ESP.Remove(obj)
        end
    end
    for _, w in ipairs(vaults) do
        if State.ESP_Vault then
            if not State.ESPCache[w] then
                ESP.Add(w, "", State.Color_Vault, false, "vault", true)
            end
        else
            if State.ESPCache[w] then ESP.Remove(w) end
        end
    end
end

function ESP.ScanExits()
    local exits = GetExits()
    local eMap = {}
    for _, e in ipairs(exits) do eMap[e] = true end
    for obj in pairs(State.ESPCache) do
        if State.ESPCache[obj] and State.ESPCache[obj].kind == "exit" and not eMap[obj] then
            ESP.Remove(obj)
        end
    end
    for _, e in ipairs(exits) do
        if State.ESP_Exit then
            if not State.ESPCache[e] then
                ESP.Add(e, "", State.Color_Exit, false, "exit", true)
            end
        else
            if State.ESPCache[e] then ESP.Remove(e) end
        end
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

-- MOVEMENT HELPERS
local function SetWalkSpeed(e)
    local h = Hum(); if not h then return end
    if Role.AmIKiller() then h.WalkSpeed = e and State.KillerWalkSpeedValue or State.WalkSpeed
    else h.WalkSpeed = e and State.WalkSpeedValue or State.WalkSpeed end
end

local function SetNoFall(e)
    local c = Char(); if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not e)
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     not e)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- INVISIBLE v7 - VOID TELEPORT
--
-- HOW IT WORKS:
--   • HRP teleports to Y=9000 (server shows you there = invisible)
--   • Camera set to Scriptable and stays in the real game world
--   • Mouse delta drives camera rotation so you can look around
--   • Movement input is captured and applied to InvisOriginalCF
--     so your "virtual position" moves around the real map
--   • Generator repair fires with the virtual position context
--   • ESP distance uses camera position (not void HRP)
--   • HRP stays pinned at void every heartbeat
--   • Health kept full to prevent void death
-- ═══════════════════════════════════════════════════════════════
local InvisHeartbeat    = nil
local InvisRenderStep   = nil
local InvisMovementConn = nil

local VOID_Y      = 9000
local VOID_THRESH = 150

local InvisCamAngles = { pitch = 0, yaw = 0 }

local function DisconnectInvis()
    if InvisHeartbeat    then pcall(function() InvisHeartbeat:Disconnect()    end); InvisHeartbeat    = nil end
    if InvisRenderStep   then pcall(function() InvisRenderStep:Disconnect()   end); InvisRenderStep   = nil end
    if InvisMovementConn then pcall(function() InvisMovementConn:Disconnect() end); InvisMovementConn = nil end
end

local function SetInvisible(enable)
    DisconnectInvis()

    local char = Char()
    local hrp  = HRP()
    local hum  = Hum()

    -- ── DISABLE ──────────────────────────────────────────────────
    if not enable then
        State.Invisible = false

        -- Restore HRP to saved virtual position
        if State.InvisOriginalCF and hrp then
            pcall(function()
                hrp.Anchored                = false
                hrp.CFrame                  = State.InvisOriginalCF
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        State.InvisOriginalCF = nil

        -- Restore camera to follow character
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
        end)

        -- Restore head BillboardGuis
        if char then
            local head = char:FindFirstChild("Head")
            if head then
                for _, g in ipairs(head:GetChildren()) do
                    if g:IsA("BillboardGui") then pcall(function() g.Enabled = true end) end
                end
            end
        end

        -- Restore humanoid states
        if hum then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead,        true)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     true)
                hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,   true)
            end)
        end

        Notify("Invisible", "OFF - Restored to map", 2)
        return
    end

    -- ── ENABLE ───────────────────────────────────────────────────
    if not char or not hrp or not hum then
        State.Invisible = false
        Notify("Invisible", "No character", 2)
        return
    end

    State.Invisible       = true
    State.InvisOriginalCF = hrp.CFrame  -- save real-world position

    -- Disable death/falling states
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead,        false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,     false)
    end)

    -- Hide overhead guis (nametag, health)
    local head = char:FindFirstChild("Head")
    if head then
        for _, g in ipairs(head:GetChildren()) do
            if g:IsA("BillboardGui") then pcall(function() g.Enabled = false end) end
        end
    end

    -- Set camera to Scriptable BEFORE moving HRP
    local savedCamCF = Camera.CFrame
    local lv         = savedCamCF.LookVector
    InvisCamAngles.pitch = math.asin(math.clamp(-lv.Y, -1, 1))
    InvisCamAngles.yaw   = math.atan2(-lv.X, -lv.Z)

    pcall(function()
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame     = savedCamCF
    end)

    -- Teleport HRP to void
    pcall(function()
        hrp.CFrame                  = CFrame.new(0, VOID_Y, 0)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)

    -- ── RENDER STEP: Camera free-look + movement visual ──────────
    InvisRenderStep = RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end

        -- Restore camera type if overridden
        if Camera.CameraType ~= Enum.CameraType.Scriptable then
            pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
        end

        -- Mouse delta → rotate camera
        local delta = UserInputService:GetMouseDelta()
        InvisCamAngles.yaw   = InvisCamAngles.yaw   - math.rad(delta.X * 0.35)
        InvisCamAngles.pitch = math.clamp(
            InvisCamAngles.pitch - math.rad(delta.Y * 0.35),
            math.rad(-80), math.rad(80)
        )

        -- Camera position = virtual player position (InvisOriginalCF)
        if State.InvisOriginalCF then
            local camPos = State.InvisOriginalCF.Position + Vector3.new(0, 1.5, 0)
            pcall(function()
                Camera.CFrame =
                    CFrame.new(camPos)
                    * CFrame.Angles(0, InvisCamAngles.yaw,   0)
                    * CFrame.Angles(InvisCamAngles.pitch, 0, 0)
            end)
        end
    end)

    -- ── MOVEMENT: WASD moves InvisOriginalCF in real world ────────
    -- We read move direction from Humanoid.MoveDirection but since
    -- HRP is in void that's unreliable. Instead we read input directly.
    local MOVE_SPEED    = State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed
    InvisMovementConn = RunService.Heartbeat:Connect(function(dt)
        if not State.Invisible then return end
        if not State.InvisOriginalCF then return end
        if IsTyping() then return end

        -- Update speed dynamically
        MOVE_SPEED = State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed

        -- Build movement vector from WASD
        local moveDir = Vector3.zero
        local w = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)
        local s = UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)
        local a = UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)
        local d = UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right)

        if w then moveDir = moveDir + Vector3.new(0, 0, -1) end
        if s then moveDir = moveDir + Vector3.new(0, 0,  1) end
        if a then moveDir = moveDir + Vector3.new(-1, 0, 0) end
        if d then moveDir = moveDir + Vector3.new( 1, 0, 0) end

        if moveDir.Magnitude > 0.1 then
            moveDir = moveDir.Unit

            -- Rotate movement by camera yaw
            local rotY   = CFrame.Angles(0, InvisCamAngles.yaw, 0)
            local worldDir = rotY * moveDir

            -- Move virtual position
            local currentPos = State.InvisOriginalCF.Position
            local newPos     = currentPos + (worldDir * MOVE_SPEED * dt)

            -- Keep on ground level (Y doesn't change from movement)
            newPos = Vector3.new(newPos.X, currentPos.Y, newPos.Z)

            -- Update InvisOriginalCF (preserves orientation)
            State.InvisOriginalCF = CFrame.new(newPos)
                * CFrame.Angles(0, InvisCamAngles.yaw, 0)
        end
    end)

    -- ── HEARTBEAT: Keep HRP pinned at void + prevent death ────────
    InvisHeartbeat = RunService.Heartbeat:Connect(function()
        if not State.Invisible then return end

        local rp = HRP()
        local hm = Hum()
        if not rp or not hm then return end

        -- Re-pin if drifted from void
        local pos = rp.Position
        if math.abs(pos.Y - VOID_Y) > VOID_THRESH
        or math.abs(pos.X) > 200
        or math.abs(pos.Z) > 200 then
            pcall(function()
                rp.CFrame                  = CFrame.new(0, VOID_Y, 0)
                rp.AssemblyLinearVelocity  = Vector3.zero
                rp.AssemblyAngularVelocity = Vector3.zero
            end)
        end

        -- Keep health full (void damage prevention)
        pcall(function()
            if hm.Health < hm.MaxHealth then
                hm.Health = hm.MaxHealth
            end
            hm:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        end)
    end)

    Notify("Invisible", "ON | Void Y=9000 | WASD moves | Mouse look", 4)
end

-- UNLOCK CURSOR
local UnlockCursorConn = nil
local function SetUnlockCursor(enable)
    if UnlockCursorConn then pcall(function() UnlockCursorConn:Disconnect() end); UnlockCursorConn = nil end
    if not enable then
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        return
    end
    UnlockCursorConn = RunService.RenderStepped:Connect(function()
        if not State.UnlockCursor then return end
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
            pcall(function()
                UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
                UserInputService.MouseIconEnabled = true
            end)
        end
    end)
end

-- AUTO HEAL
local AutoHealConn = nil
local function DoHeal()
    local c = Char(); if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid"); if not h then return end
    local pct = (h.MaxHealth > 0) and (h.Health / h.MaxHealth * 100) or 100
    if pct >= State.AutoHealThreshold then return end
    if tick() - State.LastHealTime < 1.5 then return end
    State.LastHealTime = tick()
    if R.Heal              then pcall(function() R.Heal:FireServer() end) end
    if R.AdrenalineHealthy then pcall(function() R.AdrenalineHealthy:FireServer() end) end
    if R.SkillCheck.HealResult then pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end) end
end
local function SetAutoHeal(e)
    if AutoHealConn then pcall(function() AutoHealConn:Disconnect() end); AutoHealConn = nil end
    if not e then return end
    AutoHealConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        pcall(DoHeal)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO PARRY v6
-- ═══════════════════════════════════════════════════════════════
local AutoParryConn = nil
local KillerHooks   = {}

local ATTACK_ATTRS = {
    "InAttack","Attacking","SwingActive","IsSwinging",
    "WindingUp","AttackStarted","LungeActive","Charging",
    "PreparingAttack","AttackWindup","SwingWindup",
    "IsAttacking","attacking","attackactive",
}
local ATTACK_ANIM_PATTERNS = {
    "attack","swing","slash","lunge","hit","strike",
    "grab","leap","throw","spear","inject",
}

local PARRY_MIN_INTERVAL = 0.3
local PARRY_HOLD_TIME    = 0.35
local PARRY_MAX_RANGE    = 30

local function FindParryButton()
    if not State.IsMobile then return nil end
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return nil end
    for _, gui in ipairs(pg:GetDescendants()) do
        if gui:IsA("ImageButton") or gui:IsA("TextButton") then
            local name = gui.Name:lower()
            for _, kw in ipairs({"parry","dagger","attack"}) do
                if name:find(kw) then
                    local vis = false
                    pcall(function() vis = gui.Visible and gui.AbsoluteSize.X > 20 end)
                    if vis then return gui end
                end
            end
        end
    end
    return nil
end

local function TapMobileParryButton()
    local btn = State.MobileParryButton or FindParryButton()
    if not btn then return end
    State.MobileParryButton = btn
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    pcall(function() VirtualInputMgr:SendTouchEvent(0, Enum.UserInputState.Begin, pos, game) end)
    task.delay(0.15, function()
        pcall(function() VirtualInputMgr:SendTouchEvent(0, Enum.UserInputState.End, pos, game) end)
    end)
end

local function HoldDesktopParry()
    pcall(function()
        VirtualInputMgr:SendMouseButtonEvent(
            Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 1, true, game, 0)
    end)
end
local function ReleaseDesktopParry()
    pcall(function()
        VirtualInputMgr:SendMouseButtonEvent(
            Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 1, false, game, 0)
    end)
end

local function IsDaggerReady()
    local char = Char()
    if char and char:GetAttribute("Parry") == true then return false end
    if State.LastDaggerUse > 0 then
        return (tick() - State.LastDaggerUse) >= State.DaggerCooldownEstimate
    end
    return true
end
local function GetDaggerCooldownRemaining()
    if State.LastDaggerUse > 0 then
        return math.max(0, State.DaggerCooldownEstimate - (tick() - State.LastDaggerUse))
    end
    return 0
end
local function HasDagger()
    local char = Char(); if not char then return false end
    return char:FindFirstChild("Parrying Dagger") ~= nil
end

local function IsKillerInRange(killerChar)
    -- When invisible, use virtual position for range check
    local myPos
    if State.Invisible and State.InvisOriginalCF then
        myPos = State.InvisOriginalCF.Position
    else
        local hrp = HRP()
        myPos = hrp and hrp.Position or Vector3.zero
    end
    if not killerChar then return false end
    local kHrp = killerChar:FindFirstChild("HumanoidRootPart")
    if not kHrp then return false end
    local dist = (kHrp.Position - myPos).Magnitude
    return dist <= State.ParryRange, dist
end

local function DoParry(reason)
    local now = tick()
    if now - State.LastParryTime < PARRY_MIN_INTERVAL then return false end
    if not HasDagger() then return false end
    if not IsDaggerReady() then
        if not State.DaggerNotifiedCooldown then
            State.DaggerNotifiedCooldown = true
            Notify("Parry", string.format("CD: %.1fs", GetDaggerCooldownRemaining()), 1.5)
        end
        return false
    end

    State.DaggerNotifiedCooldown = false
    State.LastParryTime          = now
    State.LastDaggerUse          = now
    State.IsCurrentlyParrying    = true

    local char = Char()
    if not char then return false end
    pcall(function()
        char:SetAttribute("Parry",  true)
        char:SetAttribute("Iframes",true)
    end)

    if R.Parry then pcall(function() R.Parry:FireServer() end) end

    if State.IsMobile then
        TapMobileParryButton()
    else
        HoldDesktopParry()
        task.delay(PARRY_HOLD_TIME, ReleaseDesktopParry)
    end

    task.delay(0.5, function()
        pcall(function()
            if char then
                char:SetAttribute("Parry",  false)
                char:SetAttribute("Iframes",false)
            end
        end)
        State.IsCurrentlyParrying = false
    end)

    Notify("Parry", string.format("HIT [%s]", reason or "?"), 1)
    return true
end

local function ClearKillerHooks()
    for _, conn in ipairs(KillerHooks) do pcall(function() conn:Disconnect() end) end
    KillerHooks = {}
end

local function HookKillerCharacter(killer)
    ClearKillerHooks()
    if not killer or not killer.Character then return end
    local kchar = killer.Character
    local khum  = kchar:FindFirstChildOfClass("Humanoid")

    for _, attr in ipairs(ATTACK_ATTRS) do
        local conn = kchar:GetAttributeChangedSignal(attr):Connect(function()
            if not State.AutoParry then return end
            if kchar:GetAttribute(attr) ~= true then return end
            if IsKillerInRange(kchar) then DoParry("attr:" .. attr) end
        end)
        table.insert(KillerHooks, conn)
    end

    if khum then
        local animConn = khum.AnimationPlayed:Connect(function(track)
            if not State.AutoParry then return end
            if not track or not track.Animation then return end
            local animName = (track.Animation.Name or ""):lower()
            local animId   = tostring(track.Animation.AnimationId or ""):lower()
            local isAttack = false
            for _, pattern in ipairs(ATTACK_ANIM_PATTERNS) do
                if animName:find(pattern) or animId:find(pattern) then isAttack = true; break end
            end
            if isAttack and IsKillerInRange(kchar) then DoParry("anim:" .. animName) end
        end)
        table.insert(KillerHooks, animConn)
    end

    local rebindConn = killer.CharacterAdded:Connect(function()
        task.wait(0.3)
        if State.AutoParry then HookKillerCharacter(killer) end
    end)
    table.insert(KillerHooks, rebindConn)
end

local function SetAutoParry(enable)
    if AutoParryConn then pcall(function() AutoParryConn:Disconnect() end); AutoParryConn = nil end
    ClearKillerHooks()

    if not enable then
        if not State.IsMobile then ReleaseDesktopParry() end
        Notify("Auto Parry", "OFF", 2)
        return
    end

    local lastKiller      = nil
    local lastKillerCheck = 0
    local killerHistory   = {}

    local function TrackKiller(pos)
        table.insert(killerHistory, { t=tick(), pos=pos })
        if #killerHistory > 5 then table.remove(killerHistory, 1) end
    end
    local function GetKillerVelocity()
        if #killerHistory < 2 then return Vector3.zero end
        local first = killerHistory[1]; local last = killerHistory[#killerHistory]
        local dt = last.t - first.t; if dt <= 0 then return Vector3.zero end
        return (last.pos - first.pos) / dt
    end

    if State.IsMobile then State.MobileParryButton = FindParryButton() end

    AutoParryConn = RunService.Heartbeat:Connect(function()
        if not State.AutoParry then return end

        local now = tick()
        local killer
        if now - lastKillerCheck > 1 then killer = Role.FindKiller(); lastKillerCheck = now
        else killer = State.CachedKiller end

        if not killer or not killer.Character then
            if #KillerHooks > 0 then ClearKillerHooks() end
            lastKiller = nil; killerHistory = {}; return
        end

        if killer ~= lastKiller then
            lastKiller = killer; HookKillerCharacter(killer); killerHistory = {}
        end

        local kchar = killer.Character
        local kHrp  = kchar:FindFirstChild("HumanoidRootPart"); if not kHrp then return end

        -- My virtual position
        local myPos
        if State.Invisible and State.InvisOriginalCF then
            myPos = State.InvisOriginalCF.Position
        else
            local hrp = HRP(); myPos = hrp and hrp.Position or Vector3.zero
        end

        TrackKiller(kHrp.Position)
        local dist = (kHrp.Position - myPos).Magnitude
        if dist > PARRY_MAX_RANGE then return end

        for _, attr in ipairs(ATTACK_ATTRS) do
            if kchar:GetAttribute(attr) == true and dist <= State.ParryRange then
                DoParry("poll:" .. attr); return
            end
        end

        if State.ParryPredictive and dist <= State.ParryRange then
            local vel   = GetKillerVelocity()
            local speed = vel.Magnitude
            if speed > 15 then
                local toMe = (myPos - kHrp.Position).Unit
                local dot  = vel.Unit:Dot(toMe)
                if dot > 0.7 and dist <= State.ParryRange * 0.6 then
                    DoParry("predictive"); return
                end
            end
        end
    end)

    Notify("Auto Parry", "ON | " .. (State.IsMobile and "MOBILE" or "DESKTOP") .. " | CD " .. State.DaggerCooldownEstimate .. "s", 3)
end

-- ═══════════════════════════════════════════════════════════════
-- AUTO GEN RUSH
-- Works while invisible: fires remote with virtual position context
-- Generator is on the map (not affected by player being in void)
-- ═══════════════════════════════════════════════════════════════
local function SetAutoGenRush(enable)
    if not enable then return end
    if not R.Gen.RepairEvent then Notify("Auto Gen","Missing remote",4); State.AutoGenRush = false; return end
    task.spawn(function()
        while State.AutoGenRush do
            task.wait(0.3)
            -- Use virtual position when invisible
            local myPos
            if State.Invisible and State.InvisOriginalCF then
                myPos = State.InvisOriginalCF.Position
            else
                local hrp = HRP()
                myPos = hrp and hrp.Position
            end
            if not myPos then continue end

            local killerNear = false
            local killer = Role.FindKiller()
            if killer and killer.Character then
                local khrp = killer.Character:FindFirstChild("HumanoidRootPart")
                if khrp and (khrp.Position - myPos).Magnitude <= State.GenKillerRadius then
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
                            local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
                            if hb then
                                local d = (hb.Position - myPos).Magnitude
                                if d < bd then bd = d; best = g end
                            end
                        end
                    end
                    State.CurrentTargetGen = best
                end

                if State.CurrentTargetGen then
                    local hb = State.CurrentTargetGen:FindFirstChild("HitBox")
                        or State.CurrentTargetGen:FindFirstChildWhichIsA("BasePart")
                    local point = State.CurrentTargetGen:FindFirstChild("GeneratorPoint1")
                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                        or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")

                    if State.AutoGenMode == "Instant" then
                        -- Move virtual position to generator, also move HRP briefly to validate
                        if hb then
                            if State.Invisible then
                                -- Update virtual position to gen
                                State.InvisOriginalCF = CFrame.new(
                                    hb.Position + Vector3.new(0, 3, 0)
                                )
                                -- Briefly move HRP to gen for server validation then re-void
                                local hrp = HRP()
                                if hrp then
                                    pcall(function()
                                        hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0)
                                    end)
                                    task.delay(0.05, function()
                                        if State.Invisible then
                                            pcall(function()
                                                hrp.CFrame = CFrame.new(0, VOID_Y, 0)
                                                hrp.AssemblyLinearVelocity  = Vector3.zero
                                                hrp.AssemblyAngularVelocity = Vector3.zero
                                            end)
                                        end
                                    end)
                                end
                            else
                                local hrp = HRP()
                                if hrp and (hb.Position - hrp.Position).Magnitude > 6 then
                                    pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0) end)
                                end
                            end
                        end
                        pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point) end)
                    else
                        -- Legit: only repair if virtual position is close enough
                        if hb and (hb.Position - myPos).Magnitude <= 8 then
                            -- In legit mode while invisible, briefly teleport HRP to gen
                            if State.Invisible then
                                local hrp = HRP()
                                if hrp then
                                    pcall(function()
                                        hrp.CFrame = hb.CFrame + Vector3.new(0, 3, 0)
                                    end)
                                    pcall(function() R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point) end)
                                    task.delay(0.05, function()
                                        if State.Invisible then
                                            pcall(function()
                                                hrp.CFrame = CFrame.new(0, VOID_Y, 0)
                                                hrp.AssemblyLinearVelocity  = Vector3.zero
                                                hrp.AssemblyAngularVelocity = Vector3.zero
                                            end)
                                        end
                                    end)
                                end
                            else
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

-- ═══════════════════════════════════════════════════════════════
-- AUTO SKILLCHECK v10
-- ═══════════════════════════════════════════════════════════════
local SkillcheckConn = nil

local SC = {
    activeGui    = nil, checkFrame    = nil,
    line         = nil, goal          = nil,
    startTime    = 0,   firedThisSC   = false,
    goalRotSeen  = nil, zoneEnterTime = nil,
    lineHistory  = {},
}

local function ResetSC()
    SC.activeGui    = nil; SC.checkFrame   = nil
    SC.line         = nil; SC.goal         = nil
    SC.startTime    = 0;   SC.firedThisSC  = false
    SC.goalRotSeen  = nil; SC.zoneEnterTime= nil
    SC.lineHistory  = {}
end

local function GetActiveSCGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return nil, nil end
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local n = gui.Name
            if n == "SkillCheckPromptGui" or n == "SkillCheckPromptGui-con" then
                local check = gui:FindFirstChild("Check")
                if check then
                    local goal = check:FindFirstChild("Goal")
                    if goal and goal.Visible then return gui, check end
                end
            end
        end
    end
    return nil, nil
end

local function IsRepairingGenerator()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
    local progressGui = pg:FindFirstChild("ProgressPromptGui")
    if not progressGui or not progressGui.Enabled then return false end
    for _, desc in ipairs(progressGui:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local txt = desc.Text and desc.Text:upper() or ""
            if txt == "REPAIR" then return true end
        end
    end
    return false
end

local function IsHealing()
    local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return false end
    local progressGui = pg:FindFirstChild("ProgressPromptGui")
    if not progressGui or not progressGui.Enabled then return false end
    for _, desc in ipairs(progressGui:GetDescendants()) do
        if desc:IsA("TextLabel") then
            local txt = desc.Text and desc.Text:upper() or ""
            if txt:find("HEAL") or txt:find("BANDAGE") then return true end
        end
    end
    return false
end

local function CalcVelocity()
    local h = SC.lineHistory; if #h < 2 then return 0 end
    local first = h[1]; local last = h[#h]
    local dt = last.t - first.t; if dt <= 0 then return 0 end
    local drot = last.rot - first.rot
    if drot > 180 then drot = drot - 360 elseif drot < -180 then drot = drot + 360 end
    return drot / dt
end

local function Sample()
    if not SC.line or not SC.goal then return end
    local lineRot = SC.line.Rotation
    local goalRot = SC.goal.Rotation
    if goalRot ~= 0 and not SC.goalRotSeen then SC.goalRotSeen = goalRot end
    table.insert(SC.lineHistory, { t=tick(), rot=lineRot })
    if #SC.lineHistory > 8 then table.remove(SC.lineHistory, 1) end
end

local function ShouldFire(mode)
    if not SC.line or not SC.goal then return false, "no_elements" end
    if not SC.goalRotSeen then return false, "no_goal" end
    local lineRot   = SC.line.Rotation
    if lineRot == 0 then return false, "line_not_started" end
    local matchPoint = SC.goalRotSeen - 360
    local velocity   = CalcVelocity()
    local distToMatch= lineRot - matchPoint

    if mode == "Fast" then
        local predictedRot  = lineRot + (velocity * 0.05)
        local predictedDist = predictedRot - matchPoint
        if distToMatch > 0 and predictedDist <= 4 then
            return true, string.format("fast_predict line=%.1f pred=%.1f match=%.1f", lineRot, predictedRot, matchPoint)
        end
        if math.abs(distToMatch) <= 5 then
            return true, string.format("fast_close dist=%.1f", distToMatch)
        end
        return false, string.format("fast_wait dist=%.1f", distToMatch)

    elseif mode == "Legit" then
        if math.abs(distToMatch) <= 6 then
            return true, string.format("legit_match dist=%.1f", distToMatch)
        end
        return false, string.format("legit_wait dist=%.1f", distToMatch)
    end
    return false, "no_mode"
end

local function ExecuteSkillcheck(mode, action, reason)
    if SC.firedThisSC then return false end
    SC.firedThisSC = true
    if mode == "Instant" then
        if action == "gen"  and R.SkillCheck.GenResult  then pcall(function() R.SkillCheck.GenResult:FireServer("Perfect") end) end
        if action == "heal" and R.SkillCheck.HealResult then pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end) end
        return true
    end
    pcall(function() VirtualInputMgr:SendKeyEvent(true,  Enum.KeyCode.Space, false, game) end)
    task.delay(0.05, function()
        pcall(function() VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
    end)
    Notify("SC", string.format("[%s] %s", mode, reason or ""), 1)
    return true
end

local function SetAutoSkillcheck(enable)
    if SkillcheckConn then pcall(function() SkillcheckConn:Disconnect() end); SkillcheckConn = nil end
    ResetSC()
    if not enable then Notify("Auto Skillcheck", "OFF", 2); return end

    SkillcheckConn = RunService.Heartbeat:Connect(function()
        if not State.AutoSkillcheck then return end
        local gui, check = GetActiveSCGui()
        if not gui then if SC.activeGui then ResetSC() end; return end

        local isGen  = IsRepairingGenerator()
        local isHeal = IsHealing()
        if not isGen and not isHeal then return end
        local action = isGen and "gen" or "heal"

        if SC.activeGui ~= gui then
            ResetSC()
            SC.activeGui  = gui; SC.checkFrame = check; SC.startTime = tick()
            SC.line = check:FindFirstChild("Line"); SC.goal = check:FindFirstChild("Goal")
        end
        if SC.firedThisSC then return end
        if not SC.line or not SC.goal then
            SC.line = check:FindFirstChild("Line"); SC.goal = check:FindFirstChild("Goal")
        end
        Sample()
        local elapsed = tick() - SC.startTime

        if State.SkillcheckMode == "Instant" then
            ExecuteSkillcheck("Instant", action, "immediate")
        elseif State.SkillcheckMode == "Fast" then
            local trigger, reason = ShouldFire("Fast")
            if trigger then ExecuteSkillcheck("Fast", action, reason)
            elseif elapsed >= 1.5 then ExecuteSkillcheck("Fast", action, "timeout") end
        elseif State.SkillcheckMode == "Legit" then
            local trigger, reason = ShouldFire("Legit")
            if trigger then
                if not SC.zoneEnterTime then SC.zoneEnterTime = tick() end
                local seed = math.floor(SC.startTime * 1000) % 100000
                local reactionDelay = 0.03 + (seed % 40) / 1000
                if tick() - SC.zoneEnterTime >= reactionDelay then
                    ExecuteSkillcheck("Legit", action, reason)
                end
            else
                SC.zoneEnterTime = nil
                if elapsed >= 1.7 then ExecuteSkillcheck("Legit", action, "timeout") end
            end
        end
    end)
    Notify("Auto Skillcheck", "v10 | " .. State.SkillcheckMode, 3)
end

-- REMOVE SKILLCHECK
local RemoveSCConn = nil
local function SetRemoveSkillcheck(enable)
    if RemoveSCConn then pcall(function() RemoveSCConn:Disconnect() end); RemoveSCConn = nil end
    if not enable then
        local ch = Char()
        if ch then
            for _, name in ipairs({"Skillcheck-gen","Skillcheck-player"}) do
                local sc = ch:FindFirstChild(name)
                if sc then pcall(function() sc.Disabled = false end) end
            end
        end
        return
    end
    RemoveSCConn = RunService.Heartbeat:Connect(function()
        if not State.RemoveSkillcheck then return end
        local ch = Char()
        if ch then
            for _, name in ipairs({"Skillcheck-gen","Skillcheck-player"}) do
                local sc = ch:FindFirstChild(name)
                if sc and not sc.Disabled then pcall(function() sc.Disabled = true end) end
            end
        end
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                if gui.Name == "SkillCheckPromptGui" or gui.Name == "SkillCheckPromptGui-con" then
                    pcall(function() gui.Enabled = false end)
                    if R.SkillCheck.GenResult then pcall(function() R.SkillCheck.GenResult:FireServer("Perfect") end) end
                end
            end
        end
    end)
end

local function SetFastVault(e)
    local ch = Char()
    if ch then pcall(function() ch:SetAttribute("vaultspeed", e and 5 or 1) end) end
end

-- KILLER HIT
local function FireHit(target)
    local ch = target and target.Character; if not ch then return end
    if R.Attacks.Basic    then pcall(function() R.Attacks.Basic:FireServer(target, ch) end) end
    if R.Attacks.Hit      then pcall(function() R.Attacks.Hit:FireServer(target, ch) end) end
    if R.AttackEvent      then pcall(function() R.AttackEvent:FireServer(target) end) end
    if R.KingScourge      then pcall(function() R.KingScourge:FireServer(target) end) end
    if R.Killers.Frenzy   then pcall(function() R.Killers.Frenzy:FireServer(target) end) end
    if R.Killers.Masked   then pcall(function() R.Killers.Masked:FireServer(target) end) end
    if R.Killers.SlowAttack then pcall(function() R.Killers.SlowAttack:FireServer(target) end) end
    if R.Killers.CureInject then pcall(function() R.Killers.CureInject:FireServer(target) end) end
end

local AutoHitConn = nil
local function SetAutoHit(enable)
    if AutoHitConn then pcall(function() AutoHitConn:Disconnect() end); AutoHitConn = nil end
    if not enable then return end
    local last = 0
    AutoHitConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHit then return end
        if tick() - last < 0.3 then return end
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(GetAllSurvivors()) do
            local erp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if erp and (erp.Position - hrp.Position).Magnitude <= State.AutoHitRange then
                last = tick(); FireHit(p)
            end
        end
    end)
end

local AutoHitAllConn = nil
local function SetAutoHitAll(enable)
    if AutoHitAllConn then pcall(function() AutoHitAllConn:Disconnect() end); AutoHitAllConn = nil end
    if not enable then return end
    local last = 0
    AutoHitAllConn = RunService.Heartbeat:Connect(function()
        if not State.AutoHitAll then return end
        if tick() - last < State.AutoHitAllDelay then return end
        last = tick()
        local survivors = GetAllSurvivors()
        if #survivors == 0 then return end
        for _, p in ipairs(survivors) do pcall(FireHit, p) end
    end)
    Notify("Auto Hit All", "ON - Every " .. State.AutoHitAllDelay .. "s", 3)
end

local AutoDamageGenConn = nil
local function SetAutoDamageGen(enable)
    if AutoDamageGenConn then pcall(function() AutoDamageGenConn:Disconnect() end); AutoDamageGenConn = nil end
    if not enable then return end
    AutoDamageGenConn = RunService.Heartbeat:Connect(function()
        if not State.AutoDamageGen then return end
        task.wait(0.3)
        local hrp = HRP(); if not hrp then return end
        for _, g in ipairs(FindAllGenerators()) do
            local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
            if hb and (hb.Position - hrp.Position).Magnitude <= 15 then
                if State.InstantDamageGen then pcall(function() hrp.CFrame = hb.CFrame + Vector3.new(0,3,0) end) end
                if R.Gen.BreakEvent  then pcall(function() R.Gen.BreakEvent:FireServer(g) end) end
                if R.Gen.BreakCommit then pcall(function() R.Gen.BreakCommit:FireServer(g) end) end
            end
        end
    end)
end

local InstantPalletConn = nil
local function SetInstantBreakPallet(enable)
    if InstantPalletConn then InstantPalletConn:Disconnect(); InstantPalletConn = nil end
    if not enable then return end
    InstantPalletConn = RunService.Heartbeat:Connect(function()
        if not State.InstantBreakPallet then return end
        task.wait(0.2)
        local hrp = HRP(); if not hrp then return end
        for _, p in ipairs(GetPallets()) do
            local pt = p:FindFirstChildWhichIsA("BasePart")
            if pt and (pt.Position - hrp.Position).Magnitude <= 12 then
                if R.Pallet.BreakCommit then pcall(function() R.Pallet.BreakCommit:FireServer(p) end) end
                if R.Pallet.DropCommit  then pcall(function() R.Pallet.DropCommit:FireServer(p) end) end
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

local NoSlowdownConn = nil
local function SetNoSlowdown(e)
    if NoSlowdownConn then pcall(function() NoSlowdownConn:Disconnect() end); NoSlowdownConn = nil end
    if not e then return end
    NoSlowdownConn = RunService.Heartbeat:Connect(function()
        if not State.NoSlowdown then return end
        local c = Char(); local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and Role.AmIKiller() then
            local target = State.KillerWalkSpeed and State.KillerWalkSpeedValue or State.WalkSpeed
            if h.WalkSpeed < target - 2 then pcall(function() h.WalkSpeed = target end) end
        end
    end)
end

-- VISUALS
local Vis = {}
local LB  = {}
function Vis.Backup()
    if next(LB) then return end
    LB = { Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
           Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
           FogEnd=Lighting.FogEnd, GlobalShadows=Lighting.GlobalShadows }
end
function Vis.Restore() for k,v in pairs(LB) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e)
    Vis.Backup()
    if e then Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
        Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false
    else Vis.Restore() end
end
function Vis.NoFog(e)
    Vis.Backup()
    if e then Lighting.FogEnd=999999
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else Lighting.FogEnd = LB.FogEnd or 100000 end
end
function Vis.NoShadows(e) Vis.Backup(); Lighting.GlobalShadows = not e end
function Vis.UnlimitedZoom(e)
    LocalPlayer.CameraMaxZoomDistance = e and math.huge or 128
    LocalPlayer.CameraMinZoomDistance = 0.5
end
function Vis.SetCrosshair(e)
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end); State.CrosshairGui = nil end
    if not e then return end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Crosshair"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=GuiParent()
    local dot = Instance.new("Frame", sg)
    dot.Size=UDim2.new(0,4,0,4); dot.Position=UDim2.new(0.5,-2,0.5,-2)
    dot.BackgroundColor3=Color3.fromRGB(255,50,50); dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    State.CrosshairGui = sg
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

local function ServerHop()
    pcall(function()
        local raw = game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer); return
                end
            end
        end
        Notify("Server Hop","No server",4)
    end)
end

CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end
end)

-- ═══════════════════════════════════════════════════════════════
-- WINDUI WINDOW
-- ═══════════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title        = HUB.Name,
    Icon         = "shield",
    Author       = HUB.Author .. " | " .. HUB.Game,
    Folder       = "X0DEC04T",
    Size         = UDim2.fromOffset(620, 440),
    Transparent  = State.BlurBg,
    Theme        = State.Theme,
    SideBarWidth = 160,
    HideSearchBar= false,
    ScrollBarEnabled = true,
    KeySystem    = false,
    Language     = "en",
})
Window:EditOpenButton({ Title=HUB.Name, Icon="shield", Enabled=false, Draggable=true })

-- FLOATING LOGO
local function CreateFloatingLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end); State.LogoGui = nil end
    local sg = Instance.new("ScreenGui")
    sg.Name="X0_Logo"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.DisplayOrder=1000
    sg.Parent = GuiParent()
    local container = Instance.new("Frame", sg)
    container.Size=UDim2.new(0,55,0,55); container.Position=UDim2.new(0,20,0,100)
    container.BackgroundTransparency=1; container.BorderSizePixel=0; container.Active=true
    local img = Instance.new("ImageLabel", container)
    img.Size=UDim2.new(1,0,1,0); img.BackgroundTransparency=1
    img.Image=HUB.LogoId; img.ScaleType=Enum.ScaleType.Fit; img.ZIndex=2
    local fallback = Instance.new("TextLabel", container)
    fallback.Size=UDim2.new(1,0,1,0); fallback.BackgroundTransparency=1
    fallback.Text="X0"; fallback.TextColor3=Color3.new(1,1,1)
    fallback.TextStrokeTransparency=0; fallback.TextStrokeColor3=Color3.fromRGB(120,80,255)
    fallback.Font=Enum.Font.GothamBlack; fallback.TextSize=26; fallback.Visible=false; fallback.ZIndex=1
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync({img}) end)
        task.wait(1.5)
        local loaded = false; pcall(function() loaded = img.IsLoaded end)
        if not loaded then img.Visible=false; fallback.Visible=true end
    end)
    local btn = Instance.new("TextButton", container)
    btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.AutoButtonColor=false; btn.ZIndex=5
    btn.MouseEnter:Connect(function() TweenService:Create(container,TweenInfo.new(0.15),{Size=UDim2.new(0,65,0,65)}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(container,TweenInfo.new(0.15),{Size=UDim2.new(0,55,0,55)}):Play() end)
    local dragging,dragStart,startPos,moved = false,nil,nil,false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=container.Position; moved=false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging then
            local delta=input.Position-dragStart
            if delta.Magnitude>5 then moved=true end
            container.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            if dragging and not moved then
                pcall(function()
                    if State.UIOpen then Window:Close(); State.UIOpen=false
                    else Window:Open(); State.UIOpen=true end
                end)
            end
            dragging=false
        end
    end)
    State.LogoGui = sg
end
task.spawn(function() task.wait(1); if State.ShowFloatingLogo then CreateFloatingLogo() end end)

-- KEYBINDS
KB.Register("WalkSpeed", Enum.KeyCode.V, function()
    State.WalkSpeedEnabled = not State.WalkSpeedEnabled; SetWalkSpeed(State.WalkSpeedEnabled)
    Notify("Walk Speed", State.WalkSpeedEnabled and "ON" or "OFF", 1.5)
end, true)
KB.Register("AutoHeal", Enum.KeyCode.H, function()
    State.AutoHeal = not State.AutoHeal; SetAutoHeal(State.AutoHeal)
    Notify("Auto Heal", State.AutoHeal and "ON" or "OFF", 1.5)
end, true)
KB.Register("Invisible", Enum.KeyCode.G, function()
    if not Char() then return end
    State.Invisible = not State.Invisible; SetInvisible(State.Invisible)
end, true)
KB.Register("AutoParry", Enum.KeyCode.R, function()
    State.AutoParry = not State.AutoParry; SetAutoParry(State.AutoParry)
    Notify("Auto Parry", State.AutoParry and "ON" or "OFF", 1.5)
end, true)
KB.Register("ToggleUI", Enum.KeyCode.Insert, function()
    pcall(function()
        if State.UIOpen then Window:Close(); State.UIOpen=false
        else Window:Open(); State.UIOpen=true end
    end)
end, false)

-- TABS
local Tabs = {
    Main     = Window:Tab({ Title="Main",     Icon="house"     }),
    ESP      = Window:Tab({ Title="ESP",      Icon="eye"       }),
    Survivor = Window:Tab({ Title="Survivor", Icon="shield"    }),
    Killer   = Window:Tab({ Title="Killer",   Icon="sword"     }),
    Visuals  = Window:Tab({ Title="Visuals",  Icon="sun"       }),
    Misc     = Window:Tab({ Title="Misc",     Icon="wrench"    }),
    Settings = Window:Tab({ Title="Settings", Icon="settings"  }),
    Info     = Window:Tab({ Title="Info",     Icon="info"      }),
}

-- MAIN TAB
Tabs.Main:Section({ Title = "v"..HUB.Version.." Changelog" })
Tabs.Main:Paragraph({
    Title = "Invisible v7 Features",
    Desc  = "• WASD moves your virtual position around the real map\n"
         .. "• Mouse look works freely while in void\n"
         .. "• Generator repair works (brief HRP flash to gen location)\n"
         .. "• ESP distances use camera position, not void HRP\n"
         .. "• ESP highlights/billboards remain active while invisible\n"
         .. "• Health kept full, death states disabled in void"
})
Tabs.Main:Section({ Title = "Role" })
Tabs.Main:Paragraph({
    Title = "Detected Role",
    Desc  = "You are: " .. (Role.AmIKiller() and "KILLER" or (Role.AmISurvivor() and "SURVIVOR" or "UNKNOWN"))
})

-- ESP TAB
Tabs.ESP:Section({ Title = "Players" })
Tabs.ESP:Toggle({Title="Player ESP",        Default=false, Callback=function(v) State.ESP_Player   = v; ESP.RefreshAll() end})
Tabs.ESP:Toggle({Title="Survivor ESP",      Default=false, Callback=function(v) State.ESP_Survivor  = v; Role.ResetKillerCache(); ESP.RefreshAll() end})
Tabs.ESP:Toggle({Title="Killer ESP",        Default=false, Callback=function(v) State.ESP_Killer    = v; Role.ResetKillerCache(); ESP.RefreshAll() end})
Tabs.ESP:Toggle({Title="Zombie/Cure ESP",   Default=false, Callback=function(v) State.ESP_Zombie    = v; ESP.ScanZombies() end})
Tabs.ESP:Section({ Title = "Display" })
Tabs.ESP:Toggle({Title="Health Bar",        Default=true,  Callback=function(v) State.ESP_HealthBar = v end})
Tabs.ESP:Toggle({Title="Distance",          Default=true,  Callback=function(v) State.ESP_Distance  = v end})
Tabs.ESP:Section({ Title = "Map Objects" })
Tabs.ESP:Toggle({Title="Generator ESP (%)", Default=false, Callback=function(v) State.ESP_Generator = v; ESP.ScanGens() end})
Tabs.ESP:Toggle({Title="Pallet ESP",        Default=false, Callback=function(v) State.ESP_Pallet    = v; ESP.ScanPallets() end})
Tabs.ESP:Toggle({Title="Vault ESP",         Default=false, Callback=function(v) State.ESP_Vault     = v; ESP.ScanVaults() end})
Tabs.ESP:Toggle({Title="Exit Gate ESP",     Default=false, Callback=function(v) State.ESP_Exit      = v; ESP.ScanExits() end})
Tabs.ESP:Section({ Title = "Settings" })
Tabs.ESP:Slider({Title="Max Distance", Value={Min=100,Max=3000,Default=1500}, Callback=function(v) State.ESP_MaxDistance=v end})
Tabs.ESP:Button({Title="Refresh ESP", Callback=function() ESP.ClearAll(); Role.ResetKillerCache(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end})

-- SURVIVOR TAB
Tabs.Survivor:Section({ Title = "Auto Skillcheck v10" })
Tabs.Survivor:Paragraph({
    Title = "Mode Info",
    Desc  = "FAST = Predictive fire (50ms lead)\n"
         .. "INSTANT = Fire remote directly\n"
         .. "LEGIT = 30-70ms reaction delay"
})
Tabs.Survivor:Dropdown({
    Title="Skillcheck Mode", Values={"Fast","Instant","Legit"}, Value="Fast",
    Callback=function(v) State.SkillcheckMode=v; if State.AutoSkillcheck then SetAutoSkillcheck(true) end end
})
Tabs.Survivor:Toggle({Title="Auto Skillcheck", Default=false, Callback=function(v) State.AutoSkillcheck=v; SetAutoSkillcheck(v) end})
Tabs.Survivor:Toggle({Title="Remove Skillcheck",Default=false,Callback=function(v) State.RemoveSkillcheck=v; SetRemoveSkillcheck(v) end})

Tabs.Survivor:Section({ Title = "Auto Gen Rush" })
Tabs.Survivor:Paragraph({
    Title = "Invisible + Gen",
    Desc  = "Walk virtual position near generator using WASD.\n"
         .. "Gen Rush will fire repair remotes when in range.\n"
         .. "Instant mode teleports HRP briefly for server validation."
})
Tabs.Survivor:Slider({Title="Killer Radius",  Value={Min=10,Max=100,Default=30}, Callback=function(v) State.GenKillerRadius=v end})
Tabs.Survivor:Dropdown({Title="Gen Mode", Values={"Legit","Instant"}, Value="Legit", Callback=function(v) State.AutoGenMode=v end})
Tabs.Survivor:Toggle({Title="Auto Gen Rush", Default=false, Callback=function(v) State.AutoGenRush=v; SetAutoGenRush(v) end})

Tabs.Survivor:Section({ Title = "Auto Heal (HH)" })
Tabs.Survivor:Slider({Title="Heal Below HP%", Value={Min=10,Max=95,Default=60}, Callback=function(v) State.AutoHealThreshold=v end})
Tabs.Survivor:Toggle({Title="Auto Heal", Default=false, Callback=function(v) State.AutoHeal=v; SetAutoHeal(v) end})

Tabs.Survivor:Section({ Title = "Auto Parry v6 (RR)" })
Tabs.Survivor:Paragraph({
    Title = "Works while Invisible",
    Desc  = "Range check uses virtual position (camera location).\n"
         .. "Parry remote still fires from void - server validates."
})
Tabs.Survivor:Slider({Title="Dagger Cooldown", Value={Min=1,Max=180,Default=90}, Callback=function(v) State.DaggerCooldownEstimate=v end})
Tabs.Survivor:Slider({Title="Parry Range",     Value={Min=5,Max=80,Default=25},  Callback=function(v) State.ParryRange=v end})
Tabs.Survivor:Toggle({Title="Predictive",      Default=true, Callback=function(v) State.ParryPredictive=v end})
Tabs.Survivor:Toggle({Title="Auto Parry",      Default=false,Callback=function(v) State.AutoParry=v; SetAutoParry(v) end})
Tabs.Survivor:Button({Title="Check Dagger", Callback=function()
    local hasDagger = HasDagger(); local ready = IsDaggerReady()
    if not hasDagger then Notify("Dagger","NOT equipped",3)
    elseif ready then Notify("Dagger","READY",2)
    else Notify("Dagger","CD: "..string.format("%.1fs",GetDaggerCooldownRemaining()),3) end
end})

Tabs.Survivor:Section({ Title = "Movement" })
Tabs.Survivor:Toggle({Title="No Fall Damage",  Default=false, Callback=function(v) State.NoFallDamage=v; SetNoFall(v) end})
Tabs.Survivor:Slider({Title="Walk Speed",      Value={Min=16,Max=60,Default=28}, Callback=function(v)
    State.WalkSpeedValue=v
    if State.WalkSpeedEnabled and not Role.AmIKiller() then SetWalkSpeed(true) end
end})
Tabs.Survivor:Toggle({Title="Walk Speed (VV)", Default=false, Callback=function(v) State.WalkSpeedEnabled=v; SetWalkSpeed(v) end})
Tabs.Survivor:Toggle({Title="Fast Vault",      Default=false, Callback=function(v) State.FastVault=v; SetFastVault(v) end})

Tabs.Survivor:Section({ Title = "Invisible v7 (GG)" })
Tabs.Survivor:Paragraph({
    Title = "Controls",
    Desc  = "GG (double G) = toggle\n"
         .. "WASD = move virtual position around map\n"
         .. "Mouse = free look\n"
         .. "Gen Rush auto-repairs when in virtual range\n"
         .. "ESP stays active with correct distances"
})
Tabs.Survivor:Toggle({Title="Invisible", Default=false, Callback=function(v)
    State.Invisible = v; SetInvisible(v)
end})

Tabs.Survivor:Section({ Title = "Cursor" })
Tabs.Survivor:Toggle({Title="Unlock Cursor", Default=false, Callback=function(v) State.UnlockCursor=v; SetUnlockCursor(v) end})

Tabs.Survivor:Button({
    Title = "DEBUG: Show SC Rotations",
    Callback = function()
        task.spawn(function()
            for i = 1, 30 do
                local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then break end
                local scGui = pg:FindFirstChild("SkillCheckPromptGui")
                if scGui and scGui.Enabled then
                    local check = scGui:FindFirstChild("Check")
                    if check then
                        local line = check:FindFirstChild("Line")
                        local goal = check:FindFirstChild("Goal")
                        if line and goal then
                            local diff = math.abs(line.Rotation - goal.Rotation)
                            if diff > 180 then diff = 360 - diff end
                            print(string.format("[SC] Line=%.1f Goal=%.1f Diff=%.1f", line.Rotation, goal.Rotation, diff))
                        end
                    end
                end
                task.wait(0.1)
            end
        end)
        Notify("Debug","Logging rotations 3s - F9",3)
    end
})

-- KILLER TAB
Tabs.Killer:Section({ Title = "Auto Hit (Range)" })
Tabs.Killer:Slider({Title="Hit Range", Value={Min=5,Max=40,Default=12}, Callback=function(v) State.AutoHitRange=v end})
Tabs.Killer:Toggle({Title="Auto Hit", Default=false, Callback=function(v) State.AutoHit=v; SetAutoHit(v) end})
Tabs.Killer:Section({ Title = "Auto Hit ALL (Map-Wide)" })
Tabs.Killer:Paragraph({Title="Warning", Desc="Hits EVERY survivor. No range limit."})
Tabs.Killer:Slider({Title="Delay (sec)", Value={Min=1,Max=30,Default=5}, Callback=function(v) State.AutoHitAllDelay=v end})
Tabs.Killer:Toggle({Title="Auto Hit ALL", Default=false, Callback=function(v) State.AutoHitAll=v; SetAutoHitAll(v) end})
Tabs.Killer:Button({Title="Hit All Now", Callback=function()
    local survivors = GetAllSurvivors()
    if #survivors==0 then Notify("Hit All","No survivors",2); return end
    for _, p in ipairs(survivors) do pcall(FireHit, p) end
    Notify("Hit All","Hit "..#survivors.." survivors",3)
end})
Tabs.Killer:Section({ Title = "Generator" })
Tabs.Killer:Toggle({Title="Instant Damage Gen", Default=false, Callback=function(v) State.InstantDamageGen=v end})
Tabs.Killer:Toggle({Title="Auto Damage Gen",    Default=false, Callback=function(v) State.AutoDamageGen=v; SetAutoDamageGen(v) end})
Tabs.Killer:Section({ Title = "Pallet" })
Tabs.Killer:Toggle({Title="Instant Break Pallet", Default=false, Callback=function(v) State.InstantBreakPallet=v; SetInstantBreakPallet(v) end})
Tabs.Killer:Section({ Title = "Movement/Immunity" })
Tabs.Killer:Slider({Title="Killer Speed", Value={Min=16,Max=80,Default=30}, Callback=function(v)
    State.KillerWalkSpeedValue=v; if State.KillerWalkSpeed and Role.AmIKiller() then SetWalkSpeed(true) end
end})
Tabs.Killer:Toggle({Title="Walk Speed (Killer)", Default=false, Callback=function(v) State.KillerWalkSpeed=v; SetWalkSpeed(v) end})
Tabs.Killer:Toggle({Title="No Stun",             Default=false, Callback=function(v) State.NoStun=v; SetNoStun(v) end})
Tabs.Killer:Toggle({Title="No Slowdown",         Default=false, Callback=function(v) State.NoSlowdown=v; SetNoSlowdown(v) end})

-- VISUALS TAB
Tabs.Visuals:Section({ Title = "Lighting" })
Tabs.Visuals:Toggle({Title="Full Bright", Default=false, Callback=function(v) State.FullBright=v; Vis.FullBright(v) end})
Tabs.Visuals:Toggle({Title="No Fog",      Default=false, Callback=function(v) State.NoFog=v; Vis.NoFog(v) end})
Tabs.Visuals:Toggle({Title="No Shadows",  Default=false, Callback=function(v) State.NoShadows=v; Vis.NoShadows(v) end})
Tabs.Visuals:Section({ Title = "Camera" })
Tabs.Visuals:Toggle({Title="Unlimited Zoom", Default=false, Callback=function(v) State.UnlimitedZoom=v; Vis.UnlimitedZoom(v) end})
Tabs.Visuals:Toggle({Title="Crosshair",      Default=false, Callback=function(v) State.Crosshair=v; Vis.SetCrosshair(v) end})

-- MISC TAB
Tabs.Misc:Section({ Title = "Performance" })
Tabs.Misc:Toggle({Title="Anti AFK",  Default=true,  Callback=function(v) State.AntiAFK=v end})
Tabs.Misc:Toggle({Title="FPS Boost", Default=false, Callback=function(v) State.FPSBoost=v; SetFPSBoost(v) end})
Tabs.Misc:Section({ Title = "Server" })
Tabs.Misc:Button({Title="Rejoin",    Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end})
Tabs.Misc:Button({Title="Server Hop",Callback=ServerHop})

-- SETTINGS TAB
Tabs.Settings:Section({ Title = "UI" })
Tabs.Settings:Dropdown({Title="Theme", Values={"Dark","Light","Rose","Plant"}, Value="Dark", Callback=function(v) pcall(function() WindUI:SetTheme(v) end) end})
Tabs.Settings:Toggle({Title="Blur BG",        Default=true,  Callback=function(v) pcall(function() Window:ToggleTransparency(v) end) end})
Tabs.Settings:Toggle({Title="Notifications",  Default=true,  Callback=function(v) State.Notifications=v end})
Tabs.Settings:Toggle({Title="Floating Logo",  Default=true,  Callback=function(v)
    State.ShowFloatingLogo=v
    if v then if not State.LogoGui or not State.LogoGui.Parent then CreateFloatingLogo()
              else State.LogoGui.Enabled=true end
    else if State.LogoGui then State.LogoGui.Enabled=false end end
end})
Tabs.Settings:Button({Title="Recreate Logo", Callback=CreateFloatingLogo})
Tabs.Settings:Section({ Title = "Danger" })
Tabs.Settings:Button({Title="Unload Hub", Callback=function()
    SetInvisible(false); SetAutoHeal(false); SetAutoParry(false)
    SetAutoSkillcheck(false); SetRemoveSkillcheck(false); SetAutoHit(false)
    SetAutoHitAll(false); SetAutoDamageGen(false); SetInstantBreakPallet(false)
    SetNoStun(false); SetNoSlowdown(false); SetUnlockCursor(false)
    Vis.SetCrosshair(false); Vis.Restore()
    LocalPlayer.CameraMaxZoomDistance = 128
    if ESPRender then ESPRender:Disconnect() end
    if ESPGui then pcall(function() ESPGui:Destroy() end) end
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end) end
    CM:Cleanup(); ESP.ClearAll()
    _G[INSTANCE_KEY] = nil
    pcall(function() Window:Destroy() end)
end})

-- INFO TAB
Tabs.Info:Section({ Title = "About" })
Tabs.Info:Paragraph({
    Title = HUB.Name .. " v" .. HUB.Version,
    Desc  = "Game: "     .. HUB.Game   .. "\n"
         .. "Dev: "      .. HUB.Author .. "\n"
         .. "Platform: " .. (State.IsMobile and "Mobile" or "Desktop")
})
Tabs.Info:Section({ Title = "Discord" })
Tabs.Info:Button({Title="Copy Discord", Callback=function()
    if setclipboard then setclipboard(HUB.Discord); Notify("Discord","Copied",3) end
end})

-- CHARACTER RESPAWN HANDLER
CM:Add(LocalPlayer.CharacterAdded, function(char)
    task.wait(1.5)
    Role.ResetKillerCache()

    -- Don't auto-restore invisible on respawn (character is new)
    State.Invisible       = false
    State.InvisOriginalCF = nil
    DisconnectInvis()

    if State.WalkSpeedEnabled  then pcall(SetWalkSpeed, true) end
    if State.KillerWalkSpeed   then pcall(SetWalkSpeed, true) end
    if State.NoFallDamage      then pcall(SetNoFall, true) end
    if State.AutoHeal          then pcall(SetAutoHeal, true) end
    if State.AutoParry         then pcall(SetAutoParry, true) end
    if State.RemoveSkillcheck  then pcall(SetRemoveSkillcheck, true) end
    if State.AutoSkillcheck    then pcall(SetAutoSkillcheck, true) end
    if State.AutoHit           then pcall(SetAutoHit, true) end
    if State.AutoHitAll        then pcall(SetAutoHitAll, true) end
    if State.NoStun            then pcall(SetNoStun, true) end
    if State.NoSlowdown        then pcall(SetNoSlowdown, true) end
    if State.UnlimitedZoom     then pcall(Vis.UnlimitedZoom, true) end
    if State.UnlockCursor      then pcall(SetUnlockCursor, true) end

    task.wait(0.5); ESP.RefreshAll()
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        pcall(SetInvisible, false)
        DisconnectInvis()
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." Loaded", 6)
Log("v0.0.1 fully loaded")
