--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.6.3 - Violence District [WindUI]
-- CLEAN Survivor UI - No emojis
-- Fixed: Invisible (Void TP flow), while+continue error
-- Sections: ESP | Automation | Player
-- Keybinds (double-tap, blocked while typing):
--   V = Sprint | H = Auto Heal | G = Invisible
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

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local INSTANCE_KEY = "__X0DEC04T_v063_WindUI"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local _t0 = os.clock()
local function Log(m) print(string.format("[X0DEC04T][+%.2fs] %s", os.clock()-_t0, tostring(m))) end

Log("v0.6.3 starting")

-- ═══════════════════════════════════════════
-- WINDUI
-- ═══════════════════════════════════════════
local WindUI = nil
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then WindUI = r; break end
end
if not WindUI then warn("WindUI failed"); return end
Log("WindUI loaded")

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.6.3",
    Author  = "voixera",
}

-- ═══════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- TYPING DETECTION
-- ═══════════════════════════════════════════
local function IsTyping()
    if UserInputService:GetFocusedTextBox() then return true end
    local ok, cfg = pcall(function() return TextChatService.ChatInputBarConfiguration end)
    if ok and cfg and cfg.IsFocused then return true end
    return false
end

-- ═══════════════════════════════════════════
-- KEYBIND MANAGER (double-tap)
-- ═══════════════════════════════════════════
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
function KB.SetKey(name, key)
    if KB._binds[name] then KB._binds[name].key = key end
end

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

-- ═══════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")

local function GetRemote(...)
    if not Remotes then return nil end
    local cur = Remotes
    for _, n in ipairs({...}) do
        cur = cur:FindFirstChild(n); if not cur then return nil end
    end
    return cur
end

local function FindDeep(root, name)
    if not root then return nil end
    for _, v in ipairs(root:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and v.Name == name then
            return v
        end
    end
end

local function FindByKW(root, kw)
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
    Gen = { RepairEvent = GetRemote("Generator","RepairEvent") },
    Game = {
        Start = GetRemote("Game","Start"),
        KillerMorph = GetRemote("Game","KillerMorph"),
        RoundEnd = GetRemote("Game","RoundEnd"),
    },
    Heal = GetRemote("Items","Medkit","heal") or FindDeep(Remotes,"HealEvent") or FindDeep(Remotes,"heal"),
    HealAlts = {},
    Perks = {},
}
for _, r in ipairs(FindByKW(Remotes,"heal")) do table.insert(R.HealAlts, r) end
for _, kw in ipairs({"invis","hidden","stealth","cloak","perk"}) do
    for _, r in ipairs(FindByKW(Remotes,kw)) do table.insert(R.Perks, r) end
end

Log("Heal: "..(R.Heal and R.Heal:GetFullName() or "nil"))
Log("Heal alts: "..#R.HealAlts.." | Perks: "..#R.Perks)

-- ═══════════════════════════════════════════
-- WORKSPACE
-- ═══════════════════════════════════════════
local WS = {
    Map = Workspace:FindFirstChild("Map"),
    Clones = Workspace:FindFirstChild("Clones"),
    FakeChars = Workspace:FindFirstChild("FakeCharacters"),
}

-- ═══════════════════════════════════════════
-- SCANNERS (full map)
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
            if (n == "generator" or n:find("^generator") or n:find("gen%d"))
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

local function FindByName(names, mustBeModel)
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local ok = mustBeModel and v:IsA("Model") or (v:IsA("Model") or v:IsA("BasePart"))
        if ok then
            local n = v.Name:lower()
            for _, name in ipairs(names) do
                if n == name or n:find("^"..name) then
                    table.insert(list, v); break
                end
            end
        end
    end
    return list
end

local function GetPallets() return FindByName({"palletwrong","pallet"}, true) end
local function GetVaults() return FindByName({"window","vault"}, true) end
local function GetExits()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        local n = v.Name:lower()
        if v:IsA("Model") or v:IsA("BasePart") then
            if n:find("exit") or n:find("gate") or n:find("escape") then
                table.insert(list, v)
            end
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

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- ESP toggles
    ESP_Killer = false, ESP_Survivor = false,
    ESP_Zombie = false, ESP_HealthBar = true,
    ESP_Distance = true, ESP_Generator = false,
    ESP_GenProgress = false, ESP_Vault = false,
    ESP_Pallet = false, ESP_Exit = false,
    ESP_MaxDistance = 1500,

    Color_Killer = Color3.fromRGB(255,40,40),
    Color_Survivor = Color3.fromRGB(60,120,255),
    Color_Zombie = Color3.fromRGB(180,60,180),
    Color_Generator = Color3.fromRGB(255,200,60),
    Color_Vault = Color3.fromRGB(0,255,200),
    Color_Pallet = Color3.fromRGB(255,165,0),
    Color_Exit = Color3.fromRGB(100,255,100),

    -- Automation
    AutoGenRush = false,
    GenKillerRadius = 30,
    AutoGenMode = "Legit",
    AutoSkillcheck = false,
    SkillcheckMode = "Legit",
    RemoveSkillcheck = false,
    AutoHeal = false,
    AutoHealThreshold = 60,
    AutoHealDelay = 1.5,
    LastHealTime = 0,

    -- Player
    NoFallDamage = false,
    Sprint = false,
    SprintSpeed = 28,
    Invisible = false,

    -- Runtime
    WalkSpeed = 16,
    ESPCache = {},
    GenProgressGuis = {},

    -- Invisible refs (void TP flow)
    InvisibleSavedPos = nil,
    InvisibleVoidPos = nil,

    -- Connections
    InvisibleConn = nil,
    NoFallConn = nil,
    AutoHealConn = nil,
    SkillcheckConn = nil,
    RemoveSCConn = nil,
    AntiAFK = true,

    CachedKiller = nil,
    KillerCacheTime = 0,
    CurrentTargetGen = nil,
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

-- ═══════════════════════════════════════════
-- ROLE DETECTION
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════
local ESP = {}
local ESPGui
do
    local old = GuiParent():FindFirstChild("X0_ESP_v4")
    if old then old:Destroy() end
    ESPGui = Instance.new("ScreenGui")
    ESPGui.Name="X0_ESP_v4"; ESPGui.ResetOnSpawn=false
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

local function MakeEntry(obj, label, color, isChar)
    local rp = GetRootPart(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency=isChar and 0.5 or 0.6
    hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=Workspace
    local bb = Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,200,0, isChar and 75 or 55)
    bb.AlwaysOnTop=true; bb.LightInfluence=0
    bb.MaxDistance=State.ESP_MaxDistance
    bb.ResetOnSpawn=false; bb.Adornee=rp; bb.Parent=ESPGui
    local nl = Instance.new("TextLabel", bb)
    nl.Size=UDim2.new(1,0,0,22); nl.BackgroundTransparency=1
    nl.Text=label; nl.TextColor3=color
    nl.TextStrokeTransparency=0.4; nl.Font=Enum.Font.GothamBold; nl.TextSize=14
    local dl = Instance.new("TextLabel", bb)
    dl.Size=UDim2.new(1,0,0,16); dl.Position=UDim2.new(0,0,0,22)
    dl.BackgroundTransparency=1; dl.Text="0m"
    dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency=0.4; dl.Font=Enum.Font.Gotham; dl.TextSize=12
    local hp = nil
    if isChar then
        hp = Instance.new("TextLabel", bb)
        hp.Size=UDim2.new(1,0,0,16); hp.Position=UDim2.new(0,0,0,38)
        hp.BackgroundTransparency=1; hp.Text="[HP] ?"
        hp.TextColor3=Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency=0.4; hp.Font=Enum.Font.GothamBold; hp.TextSize=12
    end
    return {rp=rp, obj=obj, hl=hl, bb=bb, nl=nl, dl=dl, hp=hp, isChar=isChar, color=color}
end

function ESP.Add(obj, label, color, isChar)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e = MakeEntry(obj, label, color, isChar or false)
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
            if not rp then table.insert(rem, obj)
            else
                if e.rp ~= rp then
                    e.rp = rp
                    pcall(function() e.bb.Adornee = rp end)
                    pcall(function() e.hl.Adornee = obj end)
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
                            e.hp.Text = "[HP] "..hp.."/"..mx
                            local pct = (mx>0) and hp/mx or 0
                            e.hp.TextColor3 = pct>0.6 and Color3.fromRGB(60,220,60)
                                or pct>0.3 and Color3.fromRGB(255,180,60)
                                or Color3.fromRGB(255,50,50)
                            e.hp.Visible = State.ESP_HealthBar
                        end
                    end)
                end
                if not e.isChar and obj:IsA("Model") then
                    local prog = obj:GetAttribute("RepairProgress")
                    if prog then
                        pcall(function()
                            e.nl.Text = "[GEN] "..math.floor(prog).."%"
                            e.nl.TextColor3 = prog >= 100
                                and Color3.fromRGB(60,255,60)
                                or State.Color_Generator
                        end)
                    end
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
            if isK then
                if State.ESP_Killer then
                    if not State.ESPCache[char] then
                        ESP.Add(char, "[KILLER] "..p.Name, State.Color_Killer, true)
                    end
                else
                    if State.ESPCache[char] then ESP.Remove(char) end
                end
            else
                if State.ESP_Survivor then
                    if not State.ESPCache[char] then
                        ESP.Add(char, "[SURV] "..p.Name, State.Color_Survivor, true)
                    end
                else
                    if State.ESPCache[char] then ESP.Remove(char) end
                end
            end
        end
    end
end

function ESP.ScanZombies()
    local zombies = GetZombies()
    for obj in pairs(State.ESPCache) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid")
           and not Players:GetPlayerFromCharacter(obj) then
            local stillZombie = false
            for _, z in ipairs(zombies) do if z == obj then stillZombie=true; break end end
            if not stillZombie then ESP.Remove(obj) end
        end
    end
    for _, z in ipairs(zombies) do
        if State.ESP_Zombie then
            if not State.ESPCache[z] then
                ESP.Add(z, "[ZOMBIE]", State.Color_Zombie, true)
            end
        else
            if State.ESPCache[z] then ESP.Remove(z) end
        end
    end
end

function ESP.ScanGens()
    local gens = FindAllGenerators()
    for obj in pairs(State.ESPCache) do
        if obj:IsA("Model") and obj:GetAttribute("RepairProgress") ~= nil then
            local exists = false
            for _, g in ipairs(gens) do if g == obj then exists=true; break end end
            if not exists then ESP.Remove(obj) end
        end
    end
    for _, g in ipairs(gens) do
        if State.ESP_Generator then
            if not State.ESPCache[g] then
                local prog = g:GetAttribute("RepairProgress") or 0
                ESP.Add(g, "[GEN] "..math.floor(prog).."%", State.Color_Generator, false)
            end
        else
            if State.ESPCache[g] then ESP.Remove(g) end
        end
    end
end

function ESP.ScanPallets()
    for _, p in ipairs(GetPallets()) do
        if State.ESP_Pallet then
            if not State.ESPCache[p] then ESP.Add(p, "[PALLET]", State.Color_Pallet, false) end
        else if State.ESPCache[p] then ESP.Remove(p) end end
    end
end
function ESP.ScanVaults()
    for _, w in ipairs(GetVaults()) do
        if State.ESP_Vault then
            if not State.ESPCache[w] then ESP.Add(w, "[VAULT]", State.Color_Vault, false) end
        else if State.ESPCache[w] then ESP.Remove(w) end end
    end
end
function ESP.ScanExits()
    for _, e in ipairs(GetExits()) do
        if State.ESP_Exit then
            if not State.ESPCache[e] then ESP.Add(e, "[EXIT] "..e.Name, State.Color_Exit, false) end
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

-- ═══════════════════════════════════════════
-- GENERATOR PROGRESS BILLBOARDS
-- ═══════════════════════════════════════════
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
            lbl.TextColor3 = Color3.fromRGB(255,220,60)
            lbl.TextStrokeTransparency = 0
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 18
            table.insert(State.GenProgressGuis, bb)
            task.spawn(function()
                while bb.Parent and State.ESP_GenProgress do
                    local prog = gen:GetAttribute("RepairProgress") or 0
                    local players = gen:GetAttribute("PlayersRepairingCount") or 0
                    lbl.Text = string.format("[GEN] %d%% [%d]", math.floor(prog), players)
                    lbl.TextColor3 = (prog >= 100)
                        and Color3.fromRGB(60,255,60)
                        or Color3.fromRGB(255,220,60)
                    task.wait(0.5)
                end
            end)
        end
    end
end

-- ═══════════════════════════════════════════
-- SPRINT (V) & MOVEMENT
-- ═══════════════════════════════════════════
local Move = {}
function Move.Speed()
    local h = Hum(); if h then h.WalkSpeed = State.WalkSpeed end
end
function Move.SetSprint(e)
    local h = Hum(); if not h then return end
    h.WalkSpeed = e and State.SprintSpeed or State.WalkSpeed
end

-- ═══════════════════════════════════════════
-- NO FALL DAMAGE
-- ═══════════════════════════════════════════
local function SetNoFall(e)
    if State.NoFallConn then pcall(function() State.NoFallConn:Disconnect() end); State.NoFallConn=nil end
    local c = Char()
    if c then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then
            if e then
                pcall(function()
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end)
            else
                pcall(function()
                    h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                end)
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- INVISIBLE (Void TP flow)
-- Character goes to void, POV stays in game
-- ═══════════════════════════════════════════
local function SetInvisible(enable)
    if State.InvisibleConn then
        pcall(function() State.InvisibleConn:Disconnect() end)
        State.InvisibleConn = nil
    end

    local char = Char()
    if not char then Notify("Invisible","No character",2); return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then Notify("Invisible","No HRP/Humanoid",2); return end

    -- ── OFF: bring character back ──
    if not enable then
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = hum
        end)

        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.WalkSpeed = State.Sprint and State.SprintSpeed or State.WalkSpeed
        end)

        if State.InvisibleSavedPos then
            pcall(function()
                hrp.CFrame = CFrame.new(State.InvisibleSavedPos + Vector3.new(0,3,0))
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            State.InvisibleSavedPos = nil
        end

        pcall(function()
            char:SetAttribute("Invisible", false)
            char:SetAttribute("Untargettable", false)
            char:SetAttribute("Hidden", false)
        end)

        local head = char:FindFirstChild("Head")
        if head then
            for _, g in ipairs(head:GetChildren()) do
                if g:IsA("BillboardGui") then
                    pcall(function() g.Enabled = true end)
                end
            end
        end

        State.InvisibleVoidPos = nil
        Notify("Invisible", "OFF - Character returned", 2)
        return
    end

    -- ── ON: void TP, lock camera ──
    State.InvisibleSavedPos = hrp.Position
    local savedCFrame = hrp.CFrame

    local voidPos = Vector3.new(hrp.Position.X, -5000, hrp.Position.Z)
    State.InvisibleVoidPos = voidPos

    pcall(function()
        Camera.CameraType = Enum.CameraType.Scriptable
        Camera.CFrame = CFrame.new(savedCFrame.Position + Vector3.new(0, 5, 8), savedCFrame.Position)
    end)

    pcall(function()
        hum.PlatformStand = true
        hum.AutoRotate = false
    end)

    pcall(function()
        hrp.CFrame = CFrame.new(voidPos)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end)

    pcall(function()
        char:SetAttribute("Invisible", true)
        char:SetAttribute("Untargettable", true)
        char:SetAttribute("Hidden", true)
    end)

    for _, r in ipairs(R.Perks) do
        pcall(function() r:FireServer(true) end)
    end

    local head = char:FindFirstChild("Head")
    if head then
        for _, g in ipairs(head:GetChildren()) do
            if g:IsA("BillboardGui") then
                pcall(function() g.Enabled = false end)
            end
        end
    end

    -- Maintenance loop
    State.InvisibleConn = RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end
        local c = Char(); if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local humNow = c:FindFirstChildOfClass("Humanoid")
        if not h or not humNow then return end

        -- Snap back to void if drifted
        if State.InvisibleVoidPos then
            local dist = (h.Position - State.InvisibleVoidPos).Magnitude
            if dist > 20 then
                pcall(function()
                    h.CFrame = CFrame.new(State.InvisibleVoidPos)
                    h.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end

        -- Keep camera at saved position
        if State.InvisibleSavedPos then
            local currentLook = Camera.CFrame.LookVector
            local camPos = State.InvisibleSavedPos + Vector3.new(0, 5, 0)
            pcall(function()
                Camera.CFrame = CFrame.new(camPos, camPos + currentLook)
            end)
        end

        -- Keep humanoid frozen
        pcall(function()
            humNow.PlatformStand = true
            humNow.AutoRotate = false
        end)

        -- Re-apply attributes
        pcall(function()
            if c:GetAttribute("Invisible") ~= true then c:SetAttribute("Invisible", true) end
            if c:GetAttribute("Untargettable") ~= true then c:SetAttribute("Untargettable", true) end
        end)
    end)

    Notify("Invisible", "ON - In void, POV locked", 2)
end

-- ═══════════════════════════════════════════
-- AUTO HEAL (H)
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- AUTO GEN RUSH (with Killer Radius)
-- ═══════════════════════════════════════════
local function SetAutoGenRush(enable)
    if enable then
        if not R.Gen.RepairEvent then
            Notify("Auto Gen","Missing remote",4); State.AutoGenRush = false; return
        end
        task.spawn(function()
            while State.AutoGenRush do
                task.wait(0.3)
                local hrp = HRP()
                if hrp then
                    -- Check killer distance
                    local killerNear = false
                    local killer = Role.FindKiller()
                    if killer and killer.Character then
                        local khrp = killer.Character:FindFirstChild("HumanoidRootPart")
                        if khrp then
                            local d = (khrp.Position - hrp.Position).Magnitude
                            if d <= State.GenKillerRadius then
                                State.CurrentTargetGen = nil
                                killerNear = true
                            end
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
                                        local dist = (hb.Position - hrp.Position).Magnitude
                                        if dist < bd then bd = dist; best = g end
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
    else
        State.CurrentTargetGen = nil
    end
end

-- ═══════════════════════════════════════════
-- AUTO PERFECT SKILLCHECK
-- ═══════════════════════════════════════════
local function SetAutoSkillcheck(enable)
    if State.SkillcheckConn then
        pcall(function() State.SkillcheckConn:Disconnect() end)
        State.SkillcheckConn = nil
    end
    if not enable then return end

    State.SkillcheckConn = RunService.Heartbeat:Connect(function()
        if not State.AutoSkillcheck then return end
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, gui in ipairs(pg:GetChildren()) do
            if gui.Name:find("SkillCheckPromptGui") and gui.Enabled then
                if State.SkillcheckMode == "Instant" then
                    for _, k in ipairs({Enum.KeyCode.F, Enum.KeyCode.Space, Enum.KeyCode.E}) do
                        pcall(function() VirtualInputMgr:SendKeyEvent(true, k, false, game) end)
                        task.delay(0.05, function()
                            pcall(function() VirtualInputMgr:SendKeyEvent(false, k, false, game) end)
                        end)
                    end
                    local ch = Char()
                    if ch then
                        pcall(function()
                            ch:SetAttribute("SkillcheckPerfect", true)
                            ch:SetAttribute("SkillcheckSuccess", true)
                        end)
                    end
                else
                    for _, box in ipairs(gui:GetDescendants()) do
                        if box:IsA("Frame") and box.Name:lower():find("indicator") then
                            task.wait(0.15)
                            pcall(function() VirtualInputMgr:SendKeyEvent(true, Enum.KeyCode.F, false, game) end)
                            task.delay(0.05, function()
                                pcall(function() VirtualInputMgr:SendKeyEvent(false, Enum.KeyCode.F, false, game) end)
                            end)
                            break
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- REMOVE SKILLCHECK
-- ═══════════════════════════════════════════
local function SetRemoveSkillcheck(enable)
    if State.RemoveSCConn then
        pcall(function() State.RemoveSCConn:Disconnect() end)
        State.RemoveSCConn = nil
    end
    if not enable then
        local ch = Char()
        if ch then
            local sc = ch:FindFirstChild("Skillcheck-gen")
            if sc then pcall(function() sc.Disabled = false end) end
            pcall(function() ch:SetAttribute("skillcheckfrequency", 1) end)
        end
        return
    end
    local function disable()
        local ch = Char(); if not ch then return end
        local sc = ch:FindFirstChild("Skillcheck-gen")
        if sc then pcall(function() sc.Disabled = true end) end
        pcall(function()
            ch:SetAttribute("skillcheckfrequency", 0)
            ch:SetAttribute("skillcheckspeed", 0)
        end)
    end
    disable()
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
            if ch:GetAttribute("skillcheckfrequency") ~= 0 then
                pcall(function() ch:SetAttribute("skillcheckfrequency", 0) end)
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- ANTI AFK
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

-- ═══════════════════════════════════════════
-- MATCH HOOKS
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- REGISTER KEYBINDS
-- ═══════════════════════════════════════════
KB.Register("Sprint", Enum.KeyCode.V, function()
    State.Sprint = not State.Sprint
    Move.SetSprint(State.Sprint)
    Notify("Sprint (VV)", State.Sprint and "ON" or "OFF", 1.5)
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

-- ═══════════════════════════════════════════
-- WINDUI SETUP
-- ═══════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "shield",
    Author = HUB.Author.." | "..HUB.Game,
    Folder = "X0DEC04T",
    Size = UDim2.fromOffset(560, 400),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    KeySystem = false,
})

Window:EditOpenButton({
    Title = HUB.Name,
    Icon = "shield",
    CornerRadius = UDim.new(0,10),
    StrokeThickness = 2,
    Enabled = true,
    Draggable = true,
})

local Tabs = {
    Main       = Window:Tab({ Title = "Main",       Icon = "home" }),
    ESP        = Window:Tab({ Title = "ESP",        Icon = "eye" }),
    Automation = Window:Tab({ Title = "Automation", Icon = "zap" }),
    Player     = Window:Tab({ Title = "Player",     Icon = "user" }),
    Settings   = Window:Tab({ Title = "Settings",   Icon = "settings" }),
}

-- ═══════════ MAIN ═══════════
Tabs.Main:Section({ Title = "Info" })
Tabs.Main:Paragraph({
    Title = HUB.Name.." v"..HUB.Version,
    Desc = "Game: "..HUB.Game.."\nAuthor: "..HUB.Author,
})

Tabs.Main:Section({ Title = "Fixed in v"..HUB.Version })
Tabs.Main:Paragraph({
    Title = "What's New",
    Desc = "- Invisible now uses Void TP flow (character in void, POV stays in game)\n"
        .."- Fixed while+continue error in Auto Gen Rush\n"
        .."- All emojis removed from UI\n"
        .."- Keybinds still blocked while typing\n"
        .."- Double-tap V/H/G keybinds",
})

Tabs.Main:Section({ Title = "Keybinds" })
Tabs.Main:Paragraph({
    Title = "Double-Tap to Toggle",
    Desc = "V V   Sprint\n"
        .."H H   Auto Heal\n"
        .."G G   Invisible\n\n"
        .."Auto-disabled while typing in chat",
})

Tabs.Main:Section({ Title = "Debug" })
Tabs.Main:Button({
    Title = "Save Diagnostic to workspace",
    Callback = function()
        local out = {"=== X0DEC04T DIAGNOSTIC v"..HUB.Version.." ===", os.date()}
        if Remotes then
            table.insert(out, "\n=== REMOTES ===")
            for _, v in ipairs(Remotes:GetDescendants()) do
                if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                    table.insert(out, v:GetFullName())
                end
            end
        end
        local ch = LocalPlayer.Character
        if ch then
            table.insert(out, "\n=== LOCAL CHARACTER ATTRIBUTES ===")
            for k,v in pairs(ch:GetAttributes()) do
                table.insert(out, k.." = "..tostring(v))
            end
        end
        table.insert(out, "\n=== GENERATORS ===")
        for _, g in ipairs(FindAllGenerators()) do
            table.insert(out, g:GetFullName())
        end
        table.insert(out, "\n=== ZOMBIES ===")
        for _, z in ipairs(GetZombies()) do
            table.insert(out, z:GetFullName())
        end
        local killer = Role.FindKiller()
        if killer and killer.Character then
            table.insert(out, "\n=== KILLER ("..killer.Name..") ATTRIBUTES ===")
            for k,v in pairs(killer.Character:GetAttributes()) do
                table.insert(out, k.." = "..tostring(v))
            end
        end
        if writefile then
            writefile("x0dec04t_diag.txt", table.concat(out, "\n"))
            Notify("Saved","workspace/x0dec04t_diag.txt",4)
        else
            Notify("Error","writefile not supported",3)
        end
    end,
})

-- ═══════════ ESP ═══════════
Tabs.ESP:Section({ Title = "Players" })
Tabs.ESP:Toggle({
    Title = "Killer ESP",
    Desc = "Show killer position + HP",
    Default = false,
    Callback = function(v)
        State.ESP_Killer = v; Role.ResetKillerCache()
        if not v then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and State.ESPCache[p.Character] then
                    local k = Role.FindKiller()
                    if k == p then ESP.Remove(p.Character) end
                end
            end
        end
        ESP.RefreshAll()
    end,
})
Tabs.ESP:Toggle({
    Title = "Survivor ESP",
    Desc = "Show other survivors + HP",
    Default = false,
    Callback = function(v)
        State.ESP_Survivor = v; Role.ResetKillerCache()
        if not v then
            local k = Role.FindKiller()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p ~= k and p.Character then
                    if State.ESPCache[p.Character] then ESP.Remove(p.Character) end
                end
            end
        end
        ESP.RefreshAll()
    end,
})

Tabs.ESP:Section({ Title = "Zombies" })
Tabs.ESP:Toggle({
    Title = "Zombie ESP",
    Desc = "Show all zombie/NPC positions",
    Default = false,
    Callback = function(v)
        State.ESP_Zombie = v
        if not v then
            for _, z in ipairs(GetZombies()) do ESP.Remove(z) end
        else
            ESP.ScanZombies()
        end
    end,
})

Tabs.ESP:Section({ Title = "Display" })
Tabs.ESP:Toggle({
    Title = "Health Bar ESP",
    Desc = "Show HP under name",
    Default = true,
    Callback = function(v) State.ESP_HealthBar = v end,
})
Tabs.ESP:Toggle({
    Title = "Distance ESP",
    Desc = "Show distance in meters",
    Default = true,
    Callback = function(v) State.ESP_Distance = v end,
})

Tabs.ESP:Section({ Title = "Generators" })
Tabs.ESP:Toggle({
    Title = "Generator ESP",
    Desc = "Highlight all generators on map",
    Default = false,
    Callback = function(v)
        State.ESP_Generator = v
        if not v then
            for _, g in ipairs(FindAllGenerators()) do ESP.Remove(g) end
        else
            ESP.ScanGens()
        end
    end,
})
Tabs.ESP:Toggle({
    Title = "Generator Progress ESP",
    Desc = "Show big progress % above each gen",
    Default = false,
    Callback = function(v)
        State.ESP_GenProgress = v
        SetGenProgressGuis(v)
    end,
})

Tabs.ESP:Section({ Title = "Map Objects" })
Tabs.ESP:Toggle({
    Title = "Vault ESP",
    Desc = "Highlight windows/vaults",
    Default = false,
    Callback = function(v)
        State.ESP_Vault = v
        if not v then
            for _, w in ipairs(GetVaults()) do ESP.Remove(w) end
        else ESP.ScanVaults() end
    end,
})
Tabs.ESP:Toggle({
    Title = "Pallet ESP",
    Desc = "Highlight pallets",
    Default = false,
    Callback = function(v)
        State.ESP_Pallet = v
        if not v then
            for _, p in ipairs(GetPallets()) do ESP.Remove(p) end
        else ESP.ScanPallets() end
    end,
})
Tabs.ESP:Toggle({
    Title = "Exit Gate ESP",
    Desc = "Highlight exit gates/escape",
    Default = false,
    Callback = function(v)
        State.ESP_Exit = v
        if not v then
            for _, e in ipairs(GetExits()) do ESP.Remove(e) end
        else ESP.ScanExits() end
    end,
})

Tabs.ESP:Section({ Title = "ESP Settings" })
Tabs.ESP:Slider({
    Title = "Max Distance",
    Value = { Min = 100, Max = 3000, Default = 1500 },
    Callback = function(v) State.ESP_MaxDistance = tonumber(v) or 1500 end,
})
Tabs.ESP:Button({
    Title = "Refresh All ESP",
    Callback = function()
        ESP.ClearAll(); Role.ResetKillerCache(); ESP.RefreshAll()
        Notify("ESP","Refreshed",2)
    end,
})
Tabs.ESP:Button({
    Title = "Clear All ESP",
    Callback = function() ESP.ClearAll(); Notify("ESP","Cleared",2) end,
})

-- ═══════════ AUTOMATION ═══════════
Tabs.Automation:Section({ Title = "Auto Gen Rush" })
Tabs.Automation:Slider({
    Title = "Killer Radius (stop if killer within)",
    Value = { Min = 10, Max = 100, Default = 30 },
    Callback = function(v) State.GenKillerRadius = tonumber(v) or 30 end,
})
Tabs.Automation:Dropdown({
    Title = "Gen Mode",
    Values = { "Legit", "Instant" },
    Value = "Legit",
    Callback = function(v) State.AutoGenMode = v end,
})
Tabs.Automation:Toggle({
    Title = "Auto Gen Rush",
    Desc = "Auto-repair nearest gen (skips when killer nearby)",
    Default = false,
    Callback = function(v)
        State.AutoGenRush = v
        SetAutoGenRush(v)
    end,
})

Tabs.Automation:Section({ Title = "Auto Perfect Skillcheck" })
Tabs.Automation:Dropdown({
    Title = "Skillcheck Mode",
    Values = { "Legit", "Instant" },
    Value = "Legit",
    Callback = function(v)
        State.SkillcheckMode = v
        if State.AutoSkillcheck then SetAutoSkillcheck(true) end
    end,
})
Tabs.Automation:Toggle({
    Title = "Auto Perfect Skillcheck",
    Desc = "Hit skillcheck automatically",
    Default = false,
    Callback = function(v)
        State.AutoSkillcheck = v
        SetAutoSkillcheck(v)
    end,
})

Tabs.Automation:Section({ Title = "Remove Skillcheck" })
Tabs.Automation:Toggle({
    Title = "Remove Skillcheck",
    Desc = "Disable skillcheck popups entirely",
    Default = false,
    Callback = function(v)
        State.RemoveSkillcheck = v
        SetRemoveSkillcheck(v)
    end,
})

Tabs.Automation:Section({ Title = "Auto Heal (Double-tap H)" })
Tabs.Automation:Slider({
    Title = "Heal Below HP %",
    Value = { Min = 10, Max = 95, Default = 60 },
    Callback = function(v) State.AutoHealThreshold = tonumber(v) or 60 end,
})
Tabs.Automation:Slider({
    Title = "Heal Delay (x0.5s)",
    Value = { Min = 1, Max = 10, Default = 3 },
    Callback = function(v) State.AutoHealDelay = (tonumber(v) or 3)*0.5 end,
})
Tabs.Automation:Toggle({
    Title = "Auto Heal",
    Desc = "Auto heal when HP drops (keybind: HH)",
    Default = false,
    Callback = function(v)
        State.AutoHeal = v
        SetAutoHeal(v)
    end,
})

-- ═══════════ PLAYER ═══════════
Tabs.Player:Section({ Title = "No Fall Damage" })
Tabs.Player:Toggle({
    Title = "No Fall Damage",
    Desc = "Prevents fall damage/ragdoll",
    Default = false,
    Callback = function(v)
        State.NoFallDamage = v
        SetNoFall(v)
    end,
})

Tabs.Player:Section({ Title = "Sprint (Double-tap V)" })
Tabs.Player:Slider({
    Title = "Sprint Speed",
    Value = { Min = 16, Max = 60, Default = 28 },
    Callback = function(v)
        State.SprintSpeed = tonumber(v) or 28
        if State.Sprint then Move.SetSprint(true) end
    end,
})
Tabs.Player:Toggle({
    Title = "Sprint",
    Desc = "Boost walk speed (keybind: VV)",
    Default = false,
    Callback = function(v)
        State.Sprint = v
        Move.SetSprint(v)
    end,
})

Tabs.Player:Section({ Title = "Invisible (Double-tap G)" })
Tabs.Player:Paragraph({
    Title = "How It Works",
    Desc = "Character teleports to void (Y=-5000).\n"
        .."Camera stays locked at your original position.\n"
        .."Other players cannot see or hit you.\n"
        .."Your POV stays like normal game view.",
})
Tabs.Player:Toggle({
    Title = "Invisible",
    Desc = "Void TP + POV lock (keybind: GG)",
    Default = false,
    Callback = function(v)
        State.Invisible = v
        SetInvisible(v)
    end,
})

-- ═══════════ SETTINGS ═══════════
Tabs.Settings:Section({ Title = "General" })
Tabs.Settings:Toggle({
    Title = "Anti-AFK",
    Default = true,
    Callback = function(v) State.AntiAFK = v end,
})
Tabs.Settings:Toggle({
    Title = "Block Keybinds While Typing",
    Default = true,
    Callback = function(v) KB.BlockWhileTyping = v end,
})
Tabs.Settings:Slider({
    Title = "Double-Tap Window (x0.05s)",
    Value = { Min = 3, Max = 20, Default = 7 },
    Callback = function(v) KB.DoubleTapWindow = (tonumber(v) or 7)*0.05 end,
})

Tabs.Settings:Section({ Title = "Credits" })
Tabs.Settings:Paragraph({
    Title = HUB.Name.." v"..HUB.Version,
    Desc = "by "..HUB.Author.."\nWindUI - Violence District",
})

Tabs.Settings:Section({ Title = "Danger Zone" })
Tabs.Settings:Button({
    Title = "Unload Hub",
    Callback = function()
        for _, k in ipairs({
            "NoFallConn","InvisibleConn","AutoHealConn",
            "SkillcheckConn","RemoveSCConn",
        }) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        State.AutoGenRush=false; State.ESP_GenProgress=false
        State.Invisible=false; State.AutoHeal=false
        SetInvisible(false); SetGenProgressGuis(false); SetAutoHeal(false)
        SetAutoSkillcheck(false); SetRemoveSkillcheck(false)
        if ESPRender then ESPRender:Disconnect() end
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = Hum()
        end)
        _G[INSTANCE_KEY] = nil
        Window:Destroy()
    end,
})

-- ═══════════════════════════════════════════
-- CHARACTER RESPAWN
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.CharacterAdded, function()
    State.InvisibleSavedPos = nil
    State.InvisibleVoidPos = nil
    -- Reset camera in case it was scriptable
    pcall(function()
        Camera.CameraType = Enum.CameraType.Custom
    end)
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
    if State.Sprint then pcall(Move.SetSprint, true) end
    if State.NoFallDamage then pcall(SetNoFall, true) end
    if State.AutoHeal then pcall(SetAutoHeal, true) end
    if State.RemoveSkillcheck then pcall(SetRemoveSkillcheck, true) end
    if State.AutoSkillcheck then pcall(SetAutoSkillcheck, true) end
    task.wait(0.5); ESP.RefreshAll()
    if State.ESP_GenProgress then SetGenProgressGuis(true) end
end)

-- ═══════════════════════════════════════════
-- GLOBAL INSTANCE
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        for _, k in ipairs({
            "NoFallConn","InvisibleConn","AutoHealConn",
            "SkillcheckConn","RemoveSCConn",
        }) do
            if State[k] then pcall(function() State[k]:Disconnect() end) end
        end
        State.AutoGenRush=false
        SetInvisible(false); SetGenProgressGuis(false); SetAutoHeal(false)
        SetAutoSkillcheck(false); SetRemoveSkillcheck(false)
        if ESPRender then ESPRender:Disconnect() end
        if ESPGui then pcall(function() ESPGui:Destroy() end) end
        CM:Cleanup(); ESP.ClearAll()
        pcall(function()
            Camera.CameraType = Enum.CameraType.Custom
        end)
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v"..HUB.Version.." | VV / HH / GG", 5)
Log("v0.6.3 loaded")
