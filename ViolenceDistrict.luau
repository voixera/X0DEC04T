--═══════════════════════════════════════════════════════════════════════════════
-- X0DEC04T Hub
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

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
    LocalizationService.SystemLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_v181"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local function Log(m) print("[X0DEC04T] " .. tostring(m)) end
Log("v1.8.1 starting")

-- ═══════════════════════════════════════════════════════════════
-- FLUENT UI LOAD
-- ═══════════════════════════════════════════════════════════════
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = "0.0.7",
    Author  = "voixera",
    LogoId  = "rbxassetid://112894385091124",
    Discord = "discord.gg/x0dec04t",
}

local KILLER_RED = Color3.fromRGB(220, 60, 60)

-- ═══════════════════════════════════════════════════════════════
-- CONNECTION MANAGER
-- ═══════════════════════════════════════════════════════════════
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

-- ═══════════════════════════════════════════════════════════════
-- REMOTES
-- ═══════════════════════════════════════════════════════════════
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

local R = {
    Gen = {
        RepairEvent = GR("Generator","RepairEvent"),
        BreakEvent  = GR("Generator","BreakGenEvent"),
        BreakCommit = GR("Generator","BreakGenCommit"),
    },
    SkillCheck = {
        GenResult  = GR("Generator","SkillCheckResultEvent"),
        HealResult = GR("Healing","SkillCheckResultEvent"),
    },
    Heal              = GR("Healing","HealEvent"),
    AdrenalineHealthy = GR("Items","Adrenaline Shot","Healthy"),
    Attacks = {
        Basic = GR("Attacks","BasicAttack"),
        After = GR("Attacks","AfterAttack"),
        Hit   = GR("Attacks","hit"),
        Lunge = GR("Attacks","Lunge"),
    },
    AttackEvent = GR("AttackEvent"),
    Killers = {
        Frenzy      = GR("Killers","Killer","FrenzyHitEvent"),
        Masked      = GR("Killers","Masked","alexattack"),
        Hidden      = GR("Killers","Hidden","m2HitVM"),
        SlowAttack  = GR("Killers","SlowAttack"),
        CureInject  = GR("Killers","Cure","inject"),
        StalkerGrab = GR("Killers","Stalker","grab"),
    },
    KingScourge = GR("KillerPerks","kingscourge","KingScourgeHit"),
    Pallet = {
        BreakCommit = GR("Pallet","Jason","PalletBreakCommit"),
        DropCommit  = GR("Pallet","PalletDropCommit"),
        Stunover    = GR("Pallet","Jason","Stunover"),
    },
    Vault     = GR("Window","VaultEvent"),
    FastVault = GR("Window","fastvault"),
}

-- ═══════════════════════════════════════════════════════════════
-- OBJECT FINDERS
-- ═══════════════════════════════════════════════════════════════
local function FindAllGenerators()
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
        if v:IsA("Model") and v.Name == "Window" then table.insert(list, v) end
    end
    return list
end

local function GetExits()
    local list = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name == "Gate" then table.insert(list, v) end
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
            local n = obj.Name:lower()
            local isPlayer = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character == obj then isPlayer = true; break end
            end
            if not isPlayer and (n:find("infected") or n:find("corpse") or n:find("minion")
            or n:find("cure") or n:find("zombie") or n:find("puppet")) then
                local exists = false
                for _, e in ipairs(list) do if e == obj then exists = true; break end end
                if not exists then table.insert(list, obj) end
            end
        end
    end
    return list
end

-- ═══════════════════════════════════════════════════════════════
-- KILLER DETECTION
-- ═══════════════════════════════════════════════════════════════
local function IsPlayerKiller(plr, character)
    if not plr then return false end
    character = character or plr.Character
    local isKiller = false

    -- Check 1: Role attribute on character
    if character then
        pcall(function()
            local role = tostring(character:GetAttribute("Role") or ""):lower()
            if role:find("killer") then isKiller = true end
        end)
        if isKiller then return true end

        -- Check 2: IsKiller attribute
        pcall(function()
            if character:GetAttribute("IsKiller") == true then isKiller = true end
        end)
        if isKiller then return true end
    end

    -- Check 3: Role attribute on Player
    pcall(function()
        local role = tostring(plr:GetAttribute("Role") or ""):lower()
        if role:find("killer") then isKiller = true end
    end)
    if isKiller then return true end

    -- Check 4: IsKiller attribute on Player
    pcall(function()
        if plr:GetAttribute("IsKiller") == true then isKiller = true end
    end)
    if isKiller then return true end

    -- Check 5: Workspace.Killers folder
    pcall(function()
        local kf = Workspace:FindFirstChild("Killers")
        if kf and kf:FindFirstChild(plr.Name) then isKiller = true end
    end)
    if isKiller then return true end

    -- Check 6: Team name
    pcall(function()
        if plr.Team and tostring(plr.Team.Name):lower():find("killer") then
            isKiller = true
        end
    end)
    if isKiller then return true end

    -- Check 7: Character has killer-specific children
    if character then
        for _, killerName in ipairs({"Killer","JasonAI","MaskedAI","HiddenAI","StalkerAI","FrenzyAI"}) do
            if character:FindFirstChild(killerName) then isKiller = true; break end
        end
    end

    return isKiller
end

-- ═══════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════
local State = {
    ESP_Player = false, ESP_Zombie = false,
    ESP_HealthBar = true, ESP_Distance = true,
    ESP_Generator = false, ESP_Vault = false,
    ESP_Pallet = false, ESP_Exit = false,
    ESP_MaxDistance = 1500,
    Color_Player = Color3.fromRGB(60,220,60),
    Color_Killer = KILLER_RED,
    Color_Vault  = Color3.fromRGB(180,60,220),
    Color_Pallet = Color3.fromRGB(255,140,20),
    Color_Zombie = Color3.fromRGB(255,140,20),
    Color_Exit   = Color3.fromRGB(255,255,255),

    AutoGenRush = false, GenKillerRadius = 30, AutoGenMode = "Legit",
    RemoveSkillcheck = false,
    AutoHeal = false, AutoHealThreshold = 60, LastHealTime = 0,
    FastVault = false, NoFallDamage = false,
    WalkSpeedEnabled = false, WalkSpeedValue = 28,
    Invisible = false, UnlockCursor = false,

    AutoHit = false, AutoHitRange = 12,
    AutoHitAll = false, AutoHitAllDelay = 5,
    AutoDamageGen = false, InstantDamageGen = false,
    InstantBreakPallet = false,
    KillerWalkSpeedEnabled = false, KillerWalkSpeedValue = 30,
    NoStun = false, NoSlowdown = false,

    TeleportTarget = nil, AutoFollowTarget = nil,
    AutoFollowEnabled = false, AutoFollowOffset = Vector3.new(2,0,2),

    FullBright = false, NoFog = false, NoShadows = false,
    UnlimitedZoom = false, Crosshair = false,

    AntiAFK = true, FPSBoost = false,
    Notifications = true, ShowFloatingLogo = true,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,

    WalkSpeed = 16, ESPCache = {},
    CurrentTargetGen = nil, UIOpen = true,
    LogoGui = nil, CrosshairGui = nil,
    InvisOriginalCF = nil, InvisVoidY = 9000,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end
local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        Fluent:Notify({ Title=tostring(t), Content=tostring(c), Duration=tonumber(d) or 3 })
    end)
end
local function Char() return LocalPlayer.Character end
local function HRP()  local c = Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum()  local c = Char(); return c and c:FindFirstChildOfClass("Humanoid") end

local function LerpColor(c1,c2,t)
    return Color3.new(c1.R+(c2.R-c1.R)*t,c1.G+(c2.G-c1.G)*t,c1.B+(c2.B-c1.B)*t)
end
local function GetGradientColor(pct)
    if pct<=0.5 then return LerpColor(Color3.fromRGB(180,60,220),Color3.fromRGB(255,220,60),pct*2)
    else return LerpColor(Color3.fromRGB(255,220,60),Color3.fromRGB(60,220,60),(pct-0.5)*2) end
end
local function GetHealthColor(pct)
    if pct>0.6 then return Color3.fromRGB(60,220,60)
    elseif pct>0.3 then return Color3.fromRGB(255,180,60)
    else return Color3.fromRGB(255,50,50) end
end

local function GetAllOtherPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    return list
end

local function GetMyPos()
    if State.Invisible and State.InvisOriginalCF then return State.InvisOriginalCF.Position end
    local hrp = HRP(); return hrp and hrp.Position or nil
end

-- ═══════════════════════════════════════════════════════════════
-- ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════
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
        return obj:FindFirstChild("HitBox")
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Torso")
            or obj:FindFirstChild("UpperTorso")
            or obj.PrimaryPart
            or obj:FindFirstChildWhichIsA("BasePart")
    end
end

local function MakeEntry(obj, label, color, isChar, kind, hlOnly)
    local rp = GetRootPart(obj); if not rp then return nil end
    local hl = Instance.new("Highlight")
    hl.Adornee=obj; hl.FillColor=color; hl.OutlineColor=color
    hl.FillTransparency=isChar and 0.5 or 0.6; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=Workspace
    if hlOnly then return {rp=rp,obj=obj,hl=hl,bb=nil,nl=nil,dl=nil,hp=nil,isChar=isChar,color=color,kind=kind} end
    local bb=Instance.new("BillboardGui")
    bb.Size=UDim2.new(0,200,0,isChar and 55 or 40)
    bb.StudsOffset=Vector3.new(0,isChar and 2.5 or 2,0)
    bb.AlwaysOnTop=true; bb.LightInfluence=0
    bb.MaxDistance=State.ESP_MaxDistance; bb.Adornee=rp; bb.Parent=ESPGui
    Instance.new("UIListLayout",bb).HorizontalAlignment=Enum.HorizontalAlignment.Center
    local nl=Instance.new("TextLabel",bb)
    nl.Size=UDim2.new(1,0,0,18); nl.BackgroundTransparency=1
    nl.Text=label; nl.TextColor3=color
    nl.TextStrokeTransparency=0.3; nl.Font=Enum.Font.GothamBold; nl.TextSize=13
    local hp=nil
    if isChar then
        hp=Instance.new("TextLabel",bb)
        hp.Size=UDim2.new(1,0,0,14); hp.BackgroundTransparency=1
        hp.Text="[HP] ?"; hp.TextColor3=Color3.fromRGB(255,100,100)
        hp.TextStrokeTransparency=0.3; hp.Font=Enum.Font.GothamBold; hp.TextSize=12
    end
    local dl=Instance.new("TextLabel",bb)
    dl.Size=UDim2.new(1,0,0,12); dl.BackgroundTransparency=1
    dl.Text="0m"; dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeTransparency=0.3; dl.Font=Enum.Font.Gotham; dl.TextSize=11
    return {rp=rp,obj=obj,hl=hl,bb=bb,nl=nl,dl=dl,hp=hp,isChar=isChar,color=color,kind=kind}
end

function ESP.Add(obj,label,color,isChar,kind,hlOnly)
    if not obj or not obj.Parent then return end
    if State.ESPCache[obj] then ESP.Remove(obj) end
    local e=MakeEntry(obj,label,color,isChar or false,kind,hlOnly)
    if e then State.ESPCache[obj]=e end
end
function ESP.Remove(obj)
    local e=State.ESPCache[obj]; if not e then return end
    if e.hl then pcall(function() e.hl:Destroy() end) end
    if e.bb then pcall(function() e.bb:Destroy() end) end
    State.ESPCache[obj]=nil
end
function ESP.ClearAll()
    for o in pairs(State.ESPCache) do ESP.Remove(o) end
    State.ESPCache={}
end

-- ═══════════════════════════════════════════════════════════════
-- ESP RENDER LOOP - FIXED: killers stay RED
-- ═══════════════════════════════════════════════════════════════
local ESPRender = RunService.RenderStepped:Connect(function()
    local refPos
    if State.Invisible and State.InvisOriginalCF then refPos=Camera.CFrame.Position
    else local hrp=HRP(); refPos=hrp and hrp.Position or Vector3.zero end
    local rem={}
    for obj,e in pairs(State.ESPCache) do
        if not obj or not obj.Parent then table.insert(rem,obj)
        else
            local rp=GetRootPart(obj)
            if not rp then table.insert(rem,obj)
            else
                if e.rp~=rp then
                    e.rp=rp
                    pcall(function() e.hl.Adornee=obj; if e.bb then e.bb.Adornee=rp end end)
                end
                local dist=(rp.Position-refPos).Magnitude
                local vis=dist<=State.ESP_MaxDistance
                pcall(function()
                    e.hl.Enabled=vis
                    if e.bb then
                        e.bb.MaxDistance=State.ESP_MaxDistance
                        e.bb.Enabled=vis
                        if e.dl then
                            e.dl.Text=math.floor(dist).."m"
                            e.dl.Visible=State.ESP_Distance
                        end
                    end
                end)

                -- Character (player/zombie) HP + color update
                if e.isChar and e.hp then
                    pcall(function()
                        local h = obj:FindFirstChildOfClass("Humanoid")
                        if h then
                            local hp = math.floor(h.Health)
                            local mx = math.floor(h.MaxHealth)
                            local pct = (mx > 0) and hp/mx or 0
                            e.hp.Text = "[HP] " .. hp .. "/" .. mx
                            e.hp.TextColor3 = GetHealthColor(pct)
                            e.hp.Visible = State.ESP_HealthBar

                            if e.kind == "player" then
                                if e.isKiller then
                                    -- KILLER: always stay red, never follow HP color
                                    e.hl.FillColor    = KILLER_RED
                                    e.hl.OutlineColor = KILLER_RED
                                    if e.nl then e.nl.TextColor3 = KILLER_RED end
                                else
                                    -- SURVIVOR: color follows HP
                                    local hc = GetHealthColor(pct)
                                    e.hl.FillColor    = hc
                                    e.hl.OutlineColor = hc
                                    if e.nl then e.nl.TextColor3 = hc end
                                end
                            end
                        end
                    end)
                end

                -- Generator progress color
                if e.kind=="generator" and obj:IsA("Model") and e.nl then
                    pcall(function()
                        local prog = obj:GetAttribute("RepairProgress") or 0
                        local col = GetGradientColor(prog/100)
                        e.hl.FillColor = col
                        e.hl.OutlineColor = col
                        e.nl.TextColor3 = col
                        e.nl.Text = "[GEN] " .. math.floor(prog) .. "%"
                    end)
                end
            end
        end
    end
    for _,o in ipairs(rem) do ESP.Remove(o) end
end)

-- ═══════════════════════════════════════════════════════════════
-- ESP SCANNERS - stores isKiller flag on entry
-- ═══════════════════════════════════════════════════════════════
function ESP.ScanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character.Parent then
            if State.ESP_Player then
                if not State.ESPCache[p.Character] then
                    local isKiller = IsPlayerKiller(p, p.Character)
                    local col      = isKiller and KILLER_RED or State.Color_Player
                    local label    = "[" .. p.Name .. "]"
                    if isKiller then label = "[KILLER] " .. p.Name end

                    ESP.Add(p.Character, label, col, true, "player", false)

                    -- Store role flag on the cache entry for the render loop
                    local entry = State.ESPCache[p.Character]
                    if entry then
                        entry.isKiller  = isKiller
                        entry.baseColor = col
                        entry.playerRef = p
                    end
                end
            else
                if State.ESPCache[p.Character] then ESP.Remove(p.Character) end
            end
        end
    end
end

function ESP.ScanZombies()
    local z=GetZombies(); local m={}; for _,v in ipairs(z) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="zombie" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(z) do
        if State.ESP_Zombie then if not State.ESPCache[v] then ESP.Add(v,"[CURE] "..v.Name,State.Color_Zombie,true,"zombie",false) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanGens()
    local g=FindAllGenerators(); local m={}; for _,v in ipairs(g) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="generator" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(g) do
        if State.ESP_Generator then if not State.ESPCache[v] then local p=v:GetAttribute("RepairProgress") or 0; ESP.Add(v,"[GEN] "..math.floor(p).."%",GetGradientColor(p/100),false,"generator",false) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanPallets()
    local p=GetPallets(); local m={}; for _,v in ipairs(p) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="pallet" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(p) do
        if State.ESP_Pallet then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Pallet,false,"pallet",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanVaults()
    local w=GetVaults(); local m={}; for _,v in ipairs(w) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="vault" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(w) do
        if State.ESP_Vault then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Vault,false,"vault",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.ScanExits()
    local e=GetExits(); local m={}; for _,v in ipairs(e) do m[v]=true end
    for o in pairs(State.ESPCache) do if State.ESPCache[o] and State.ESPCache[o].kind=="exit" and not m[o] then ESP.Remove(o) end end
    for _,v in ipairs(e) do
        if State.ESP_Exit then if not State.ESPCache[v] then ESP.Add(v,"",State.Color_Exit,false,"exit",true) end
        else if State.ESPCache[v] then ESP.Remove(v) end end
    end
end

function ESP.RefreshAll()
    ESP.ScanPlayers(); ESP.ScanZombies(); ESP.ScanGens()
    ESP.ScanPallets(); ESP.ScanVaults(); ESP.ScanExits()
end

-- Periodic refresh + killer re-check for late role assignments
task.spawn(function()
    while task.wait(1.5) do
        pcall(function()
            -- Re-check killer status on existing player entries
            for obj, entry in pairs(State.ESPCache) do
                if entry.kind == "player" and obj.Parent then
                    local plr = entry.playerRef
                    if not plr or plr.Character ~= obj then
                        -- Re-resolve player reference
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p.Character == obj then plr = p; break end
                        end
                        entry.playerRef = plr
                    end
                    if plr then
                        local nowKiller = IsPlayerKiller(plr, obj)
                        if nowKiller ~= entry.isKiller then
                            entry.isKiller = nowKiller
                            -- Update label immediately
                            if entry.nl then
                                if nowKiller then
                                    entry.nl.Text = "[KILLER] " .. plr.Name
                                else
                                    entry.nl.Text = "[" .. plr.Name .. "]"
                                end
                            end
                            Log("[ESP] " .. plr.Name .. " killer status -> " .. tostring(nowKiller))
                        end
                    end
                end
            end
            ESP.RefreshAll()
        end)
    end
end)

CM:Add(Players.PlayerRemoving, function(p) if p.Character then ESP.Remove(p.Character) end end)
local function HookPlayer(p)
    if p==LocalPlayer then return end
    CM:Add(p.CharacterAdded, function()
        task.wait(0.5)
        ESP.RefreshAll()
    end)
    CM:Add(p.CharacterRemoving, function(c) ESP.Remove(c) end)

    -- Listen for role attribute changes on the player
    CM:Add(p:GetAttributeChangedSignal("Role"), function()
        if p.Character and State.ESPCache[p.Character] then
            local entry = State.ESPCache[p.Character]
            local nowKiller = IsPlayerKiller(p, p.Character)
            entry.isKiller = nowKiller
            if entry.nl then
                entry.nl.Text = nowKiller and ("[KILLER] " .. p.Name) or ("[" .. p.Name .. "]")
            end
        end
    end)
    CM:Add(p:GetAttributeChangedSignal("IsKiller"), function()
        if p.Character and State.ESPCache[p.Character] then
            local entry = State.ESPCache[p.Character]
            local nowKiller = IsPlayerKiller(p, p.Character)
            entry.isKiller = nowKiller
            if entry.nl then
                entry.nl.Text = nowKiller and ("[KILLER] " .. p.Name) or ("[" .. p.Name .. "]")
            end
        end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do HookPlayer(p) end
CM:Add(Players.PlayerAdded, HookPlayer)

-- ═══════════════════════════════════════════════════════════════
-- LOBBY TELEPORT
-- ═══════════════════════════════════════════════════════════════
local LobbyState = { Method="Auto", LastAttempt=0, CooldownSecs=5 }

local function IsInMatch()
    if Workspace:FindFirstChild("Map") then return true end
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v.Name=="Generator" then return true end
        if v.Name=="Gate" or v.Name=="Pallet" then return true end
    end
    return false
end

local function FindLobbyPosition()
    for _,fn in ipairs({"Lobby","LobbyArea","Hub","Menu","Waiting"}) do
        local f=Workspace:FindFirstChild(fn)
        if f then local p=f:FindFirstChildWhichIsA("BasePart",true); if p then return p.Position+Vector3.new(0,5,0) end end
    end
    local sp=Workspace:FindFirstChildWhichIsA("SpawnLocation",true)
    if sp then return sp.Position+Vector3.new(0,5,0) end
    return nil
end

local function FindLobbyPlaceId()
    local id=nil
    pcall(function()
        local cfg=ReplicatedStorage:FindFirstChild("Config") or ReplicatedStorage:FindFirstChild("GameConfig")
        if cfg then id=cfg:GetAttribute("LobbyPlaceId") or cfg:GetAttribute("MainPlaceId") end
    end)
    if id then return id end
    if game.PlaceId~=game.GameId then return game.GameId end
    return nil
end

local function FindLobbyRemotes()
    local kw={"leave","lobby","return","exit","menu","hub","quit","back"}
    local found={}
    for _,obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local n=obj.Name:lower()
            for _,k in ipairs(kw) do if n:find(k) then table.insert(found,obj); break end end
        end
    end
    return found
end

local function GoToLobby(method)
    method=method or LobbyState.Method
    local now=tick()
    if now-LobbyState.LastAttempt<LobbyState.CooldownSecs then
        Notify("Lobby","Cooldown "..math.ceil(LobbyState.CooldownSecs-(now-LobbyState.LastAttempt)).."s",2); return
    end
    LobbyState.LastAttempt=now

    if method=="Auto" then
        local remotes=FindLobbyRemotes()
        if #remotes>0 then
            for _,r in ipairs(remotes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer() else r:InvokeServer() end end) end
            Notify("Lobby","Remote fired",3)
            task.delay(2,function()
                if IsInMatch() then
                    local pos=FindLobbyPosition()
                    if pos then local hrp=HRP(); if hrp then pcall(function() hrp.CFrame=CFrame.new(pos) end) end; Notify("Lobby","Moved to zone",3) end
                end
            end); return
        end
        local pos=FindLobbyPosition()
        if pos then local hrp=HRP(); if hrp then pcall(function() hrp.CFrame=CFrame.new(pos) end) end; Notify("Lobby","Moved to zone",3); return end
        local id=FindLobbyPlaceId()
        if id and id~=game.PlaceId then Notify("Lobby","Teleporting...",4); pcall(function() TeleportService:Teleport(id,LocalPlayer) end); return end
        Notify("Lobby","Rejoining...",4); pcall(function() TeleportService:Teleport(game.PlaceId,LocalPlayer) end)
    elseif method=="Remote" then
        local r=FindLobbyRemotes()
        for _,v in ipairs(r) do pcall(function() if v:IsA("RemoteEvent") then v:FireServer() else v:InvokeServer() end end) end
        Notify("Lobby",#r>0 and "Fired" or "None found",3)
    elseif method=="Position" then
        local pos=FindLobbyPosition()
        if pos then local hrp=HRP(); if hrp then pcall(function() hrp.CFrame=CFrame.new(pos) end) end end
        Notify("Lobby",pos and "Moved" or "No zone",3)
    elseif method=="Rejoin" then
        pcall(function() TeleportService:Teleport(game.PlaceId,LocalPlayer) end); Notify("Lobby","Rejoining...",4)
    elseif method=="Die" then
        local hum=Hum(); if hum then pcall(function() hum.Health=0 end) end; Notify("Lobby","Died",3)
    end
end

-- ═══════════════════════════════════════════════════════════════
-- TELEPORT TO PLAYER
-- ═══════════════════════════════════════════════════════════════
local AutoFollowConn=nil

local function GetPlayerNames()
    local n={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then table.insert(n,p.Name) end end
    if #n==0 then table.insert(n,"None") end; return n
end

local function FindPlayerByName(name)
    if not name or name=="None" then return nil end; return Players:FindFirstChild(name)
end

local function TeleportToPlayer(target,offset)
    if not target then return false end
    local p=FindPlayerByName(target); if not p or not p.Character then return false end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); if not prp then return false end
    local hrp=HRP(); if not hrp then return false end
    local dest=prp.CFrame+(offset or Vector3.zero)
    if State.Invisible then
        State.InvisOriginalCF=dest
        pcall(function() hrp.CFrame=dest; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
        task.delay(0.05,function()
            if State.Invisible then pcall(function() hrp.CFrame=CFrame.new(0,State.InvisVoidY,0); hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end) end
        end)
    else pcall(function() hrp.CFrame=dest; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end) end
    return true
end

local function SetAutoFollow(enable)
    if AutoFollowConn then pcall(function() AutoFollowConn:Disconnect() end); AutoFollowConn=nil end
    if not enable then State.AutoFollowEnabled=false; return end
    State.AutoFollowEnabled=true; local last=0
    AutoFollowConn=RunService.Heartbeat:Connect(function()
        if not State.AutoFollowEnabled or not State.AutoFollowTarget then return end
        if tick()-last<0.1 then return end; last=tick()
        pcall(TeleportToPlayer,State.AutoFollowTarget,State.AutoFollowOffset)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- MOVEMENT / INVISIBLE / FEATURES
-- ═══════════════════════════════════════════════════════════════
local function SetWalkSpeed(e) local h=Hum(); if h then h.WalkSpeed=e and State.WalkSpeedValue or State.WalkSpeed end end
local function SetKillerWalkSpeed(e) local h=Hum(); if h then h.WalkSpeed=e and State.KillerWalkSpeedValue or State.WalkSpeed end end
local function SetNoFall(e)
    local c=Char(); if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
    pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.FallingDown,not e); h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,not e) end)
end

-- INVISIBLE
local InvisHB,InvisRS,InvisMV=nil,nil,nil
local VOID_Y,VOID_THRESH=9000,150
local InvisCam={pitch=0,yaw=0}

local function DisconnectInvis()
    if InvisHB then pcall(function() InvisHB:Disconnect() end); InvisHB=nil end
    if InvisRS then pcall(function() InvisRS:Disconnect() end); InvisRS=nil end
    if InvisMV then pcall(function() InvisMV:Disconnect() end); InvisMV=nil end
end

local function SetInvisible(enable)
    DisconnectInvis()
    local char,hrp,hum=Char(),HRP(),Hum()
    if not enable then
        State.Invisible=false
        if State.InvisOriginalCF and hrp then
            pcall(function() hrp.Anchored=false; hrp.CFrame=State.InvisOriginalCF; hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
        end
        State.InvisOriginalCF=nil
        pcall(function() Camera.CameraType=Enum.CameraType.Custom end)
        if char then local head=char:FindFirstChild("Head"); if head then for _,g in ipairs(head:GetChildren()) do if g:IsA("BillboardGui") then pcall(function() g.Enabled=true end) end end end end
        if hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,true); hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,true); hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,true); hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true) end) end
        Notify("Invisible","OFF",2); return
    end
    if not char or not hrp or not hum then State.Invisible=false; Notify("Invisible","No character",2); return end
    State.Invisible=true; State.InvisOriginalCF=hrp.CFrame
    pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false); hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown,false); hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll,false) end)
    local head=char:FindFirstChild("Head"); if head then for _,g in ipairs(head:GetChildren()) do if g:IsA("BillboardGui") then pcall(function() g.Enabled=false end) end end end
    local lv=Camera.CFrame.LookVector; InvisCam.pitch=math.asin(math.clamp(-lv.Y,-1,1)); InvisCam.yaw=math.atan2(-lv.X,-lv.Z)
    pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end)
    pcall(function() hrp.CFrame=CFrame.new(0,VOID_Y,0); hrp.AssemblyLinearVelocity=Vector3.zero; hrp.AssemblyAngularVelocity=Vector3.zero end)
    InvisRS=RunService.RenderStepped:Connect(function()
        if not State.Invisible then return end
        if Camera.CameraType~=Enum.CameraType.Scriptable then pcall(function() Camera.CameraType=Enum.CameraType.Scriptable end) end
        local d=UserInputService:GetMouseDelta()
        InvisCam.yaw=InvisCam.yaw-math.rad(d.X*0.35)
        InvisCam.pitch=math.clamp(InvisCam.pitch-math.rad(d.Y*0.35),math.rad(-80),math.rad(80))
        if State.InvisOriginalCF then
            pcall(function() Camera.CFrame=CFrame.new(State.InvisOriginalCF.Position+Vector3.new(0,1.5,0))*CFrame.Angles(0,InvisCam.yaw,0)*CFrame.Angles(InvisCam.pitch,0,0) end)
        end
    end)
    InvisMV=RunService.Heartbeat:Connect(function(dt)
        if not State.Invisible or not State.InvisOriginalCF or IsTyping() then return end
        local spd=State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed; local md=Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md=md+Vector3.new(0,0,-1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md=md+Vector3.new(0,0,1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md=md+Vector3.new(-1,0,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md=md+Vector3.new(1,0,0) end
        if md.Magnitude>0.1 then
            md=md.Unit; local wd=CFrame.Angles(0,InvisCam.yaw,0)*md
            local cur=State.InvisOriginalCF.Position; local nxt=cur+wd*spd*dt
            State.InvisOriginalCF=CFrame.new(Vector3.new(nxt.X,cur.Y,nxt.Z))*CFrame.Angles(0,InvisCam.yaw,0)
        end
    end)
    InvisHB=RunService.Heartbeat:Connect(function()
        if not State.Invisible then return end
        local rp,hm=HRP(),Hum(); if not rp or not hm then return end
        local pos=rp.Position
        if math.abs(pos.Y-VOID_Y)>VOID_THRESH or math.abs(pos.X)>200 or math.abs(pos.Z)>200 then
            pcall(function() rp.CFrame=CFrame.new(0,VOID_Y,0); rp.AssemblyLinearVelocity=Vector3.zero; rp.AssemblyAngularVelocity=Vector3.zero end)
        end
        pcall(function() if hm.Health<hm.MaxHealth then hm.Health=hm.MaxHealth end; hm:SetStateEnabled(Enum.HumanoidStateType.Dead,false) end)
    end)
    Notify("Invisible","ON",3)
end

local UnlockCursorConn=nil
local function SetUnlockCursor(e)
    if UnlockCursorConn then pcall(function() UnlockCursorConn:Disconnect() end); UnlockCursorConn=nil end
    if not e then pcall(function() UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true end); return end
    UnlockCursorConn=RunService.RenderStepped:Connect(function()
        if State.UnlockCursor and UserInputService.MouseBehavior~=Enum.MouseBehavior.Default then
            pcall(function() UserInputService.MouseBehavior=Enum.MouseBehavior.Default; UserInputService.MouseIconEnabled=true end)
        end
    end)
end

local AutoHealConn=nil
local function SetAutoHeal(e)
    if AutoHealConn then pcall(function() AutoHealConn:Disconnect() end); AutoHealConn=nil end
    if not e then return end
    AutoHealConn=RunService.Heartbeat:Connect(function()
        if not State.AutoHeal then return end
        local c=Char(); if not c then return end; local h=c:FindFirstChildOfClass("Humanoid"); if not h then return end
        local pct=(h.MaxHealth>0) and (h.Health/h.MaxHealth*100) or 100
        if pct>=State.AutoHealThreshold or tick()-State.LastHealTime<1.5 then return end
        State.LastHealTime=tick()
        if R.Heal then pcall(function() R.Heal:FireServer() end) end
        if R.AdrenalineHealthy then pcall(function() R.AdrenalineHealthy:FireServer() end) end
        if R.SkillCheck.HealResult then pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end) end
    end)
end

local RemoveSCConn=nil
local function SetRemoveSkillcheck(e)
    if RemoveSCConn then pcall(function() RemoveSCConn:Disconnect() end); RemoveSCConn=nil end
    if not e then local ch=Char(); if ch then for _,n in ipairs({"Skillcheck-gen","Skillcheck-player"}) do local s=ch:FindFirstChild(n); if s then pcall(function() s.Disabled=false end) end end end; return end
    RemoveSCConn=RunService.Heartbeat:Connect(function()
        if not State.RemoveSkillcheck then return end
        local ch=Char(); if ch then for _,n in ipairs({"Skillcheck-gen","Skillcheck-player"}) do local s=ch:FindFirstChild(n); if s and not s.Disabled then pcall(function() s.Disabled=true end) end end end
        local pg=LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _,gui in ipairs(pg:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Enabled then
                local gn=gui.Name:lower()
                if gn:find("skillcheck") or gn:find("skill_check") then
                    if R.SkillCheck.GenResult then pcall(function() R.SkillCheck.GenResult:FireServer("Perfect") end) end
                    if R.SkillCheck.HealResult then pcall(function() R.SkillCheck.HealResult:FireServer("Perfect") end) end
                    pcall(function() gui.Enabled=false end)
                end
            end
        end
    end)
end

local function SetAutoGenRush(enable)
    if not enable then return end
    if not R.Gen.RepairEvent then
        Notify("Auto Gen","Missing remote",4)
        State.AutoGenRush = false
        return
    end

    spawn(function()
        while State.AutoGenRush do
            wait(0.3)

            local myPos = GetMyPos()
            if myPos then

                local playerNear = false

                for _, p in ipairs(GetAllOtherPlayers()) do
                    local pc = p.Character
                    if pc then
                        local ph = pc:FindFirstChild("HumanoidRootPart")
                        if ph then
                            if (ph.Position - myPos).Magnitude <= State.GenKillerRadius then
                                State.CurrentTargetGen = nil
                                playerNear = true
                                break
                            end
                        end
                    end
                end

                if not playerNear then

                    if State.CurrentTargetGen then
                        local progress = State.CurrentTargetGen:GetAttribute("RepairProgress") or 0
                        if progress >= 100 or not State.CurrentTargetGen.Parent then
                            State.CurrentTargetGen = nil
                        end
                    end

                    if not State.CurrentTargetGen then
                        local best, bestDist = nil, math.huge

                        for _, g in ipairs(FindAllGenerators()) do
                            local progress = g:GetAttribute("RepairProgress") or 0
                            if progress < 100 then
                                local hb = g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
                                if hb then
                                    local dist = (hb.Position - myPos).Magnitude
                                    if dist < bestDist then
                                        bestDist = dist
                                        best = g
                                    end
                                end
                            end
                        end

                        State.CurrentTargetGen = best
                    end

                    if State.CurrentTargetGen then
                        local hb = State.CurrentTargetGen:FindFirstChild("HitBox") or State.CurrentTargetGen:FindFirstChildWhichIsA("BasePart")
                        local point = State.CurrentTargetGen:FindFirstChild("GeneratorPoint1")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint2")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint3")
                            or State.CurrentTargetGen:FindFirstChild("GeneratorPoint4")

                        if hb and (hb.Position - myPos).Magnitude <= 8 then
                            pcall(function()
                                R.Gen.RepairEvent:FireServer(State.CurrentTargetGen, point)
                            end)
                        end
                    end
                end
            end
        end

        State.CurrentTargetGen = nil
    end)
end

local function SetFastVault(e) local ch=Char(); if ch then pcall(function() ch:SetAttribute("vaultspeed",e and 5 or 1) end) end end

-- KILLER
local function FireHit(target)
    local ch=target and target.Character; if not ch then return end
    if R.Attacks.Basic      then pcall(function() R.Attacks.Basic:FireServer(target,ch) end) end
    if R.Attacks.Hit        then pcall(function() R.Attacks.Hit:FireServer(target,ch) end) end
    if R.AttackEvent        then pcall(function() R.AttackEvent:FireServer(target) end) end
    if R.KingScourge        then pcall(function() R.KingScourge:FireServer(target) end) end
    if R.Killers.Frenzy     then pcall(function() R.Killers.Frenzy:FireServer(target) end) end
    if R.Killers.Masked     then pcall(function() R.Killers.Masked:FireServer(target) end) end
    if R.Killers.SlowAttack then pcall(function() R.Killers.SlowAttack:FireServer(target) end) end
    if R.Killers.CureInject then pcall(function() R.Killers.CureInject:FireServer(target) end) end
end

local AutoHitConn=nil
local function SetAutoHit(e)
    if AutoHitConn then pcall(function() AutoHitConn:Disconnect() end); AutoHitConn=nil end
    if not e then return end; local last=0
    AutoHitConn=RunService.Heartbeat:Connect(function()
        if not State.AutoHit or tick()-last<0.3 then return end
        local hrp=HRP(); if not hrp then return end
        for _,p in ipairs(GetAllOtherPlayers()) do
            local ep=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if ep and (ep.Position-hrp.Position).Magnitude<=State.AutoHitRange then last=tick(); FireHit(p) end
        end
    end)
end

local AutoHitAllConn=nil
local function SetAutoHitAll(e)
    if AutoHitAllConn then pcall(function() AutoHitAllConn:Disconnect() end); AutoHitAllConn=nil end
    if not e then return end; local last=0
    AutoHitAllConn=RunService.Heartbeat:Connect(function()
        if not State.AutoHitAll or tick()-last<State.AutoHitAllDelay then return end; last=tick()
        for _,p in ipairs(GetAllOtherPlayers()) do pcall(FireHit,p) end
    end)
end

local AutoDamageGenConn=nil
local function SetAutoDamageGen(e)
    if AutoDamageGenConn then pcall(function() AutoDamageGenConn:Disconnect() end); AutoDamageGenConn=nil end
    if not e then return end
    AutoDamageGenConn=RunService.Heartbeat:Connect(function()
        if not State.AutoDamageGen then return end; task.wait(0.3)
        local hrp=HRP(); if not hrp then return end
        for _,g in ipairs(FindAllGenerators()) do
            local hb=g:FindFirstChild("HitBox") or g:FindFirstChildWhichIsA("BasePart")
            if hb and (hb.Position-hrp.Position).Magnitude<=15 then
                if State.InstantDamageGen then pcall(function() hrp.CFrame=hb.CFrame+Vector3.new(0,3,0) end) end
                if R.Gen.BreakEvent then pcall(function() R.Gen.BreakEvent:FireServer(g) end) end
                if R.Gen.BreakCommit then pcall(function() R.Gen.BreakCommit:FireServer(g) end) end
            end
        end
    end)
end

local InstPalletConn=nil
local function SetInstantBreakPallet(e)
    if InstPalletConn then InstPalletConn:Disconnect(); InstPalletConn=nil end
    if not e then return end
    InstPalletConn=RunService.Heartbeat:Connect(function()
        if not State.InstantBreakPallet then return end; task.wait(0.2)
        local hrp=HRP(); if not hrp then return end
        for _,p in ipairs(GetPallets()) do
            local pt=p:FindFirstChildWhichIsA("BasePart")
            if pt and (pt.Position-hrp.Position).Magnitude<=12 then
                if R.Pallet.BreakCommit then pcall(function() R.Pallet.BreakCommit:FireServer(p) end) end
                if R.Pallet.DropCommit then pcall(function() R.Pallet.DropCommit:FireServer(p) end) end
            end
        end
    end)
end

local NoStunConn=nil
local function SetNoStun(e)
    if NoStunConn then pcall(function() NoStunConn:Disconnect() end); NoStunConn=nil end
    if not e then return end
    NoStunConn=RunService.Heartbeat:Connect(function()
        if not State.NoStun then return end; local c=Char()
        if c then pcall(function() c:SetAttribute("Knocked",false) end); if R.Pallet.Stunover then pcall(function() R.Pallet.Stunover:FireServer() end) end end
    end)
end

local NoSlowConn=nil
local function SetNoSlowdown(e)
    if NoSlowConn then pcall(function() NoSlowConn:Disconnect() end); NoSlowConn=nil end
    if not e then return end
    NoSlowConn=RunService.Heartbeat:Connect(function()
        if not State.NoSlowdown then return end
        local h=Hum(); if not h then return end
        local t=State.KillerWalkSpeedEnabled and State.KillerWalkSpeedValue or (State.WalkSpeedEnabled and State.WalkSpeedValue or State.WalkSpeed)
        if h.WalkSpeed<t-2 then pcall(function() h.WalkSpeed=t end) end
    end)
end

-- VISUALS
local Vis,LB={},{}
function Vis.Backup() if next(LB) then return end; LB={Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,Brightness=Lighting.Brightness,ClockTime=Lighting.ClockTime,FogEnd=Lighting.FogEnd,GlobalShadows=Lighting.GlobalShadows} end
function Vis.Restore() for k,v in pairs(LB) do pcall(function() Lighting[k]=v end) end end
function Vis.FullBright(e) Vis.Backup(); if e then Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1); Lighting.Brightness=2; Lighting.ClockTime=14; Lighting.GlobalShadows=false else Vis.Restore() end end
function Vis.NoFog(e) Vis.Backup(); if e then Lighting.FogEnd=999999; for _,a in ipairs(Lighting:GetChildren()) do if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end end else Lighting.FogEnd=LB.FogEnd or 100000 end end
function Vis.NoShadows(e) Vis.Backup(); Lighting.GlobalShadows=not e end
function Vis.UnlimitedZoom(e) LocalPlayer.CameraMaxZoomDistance=e and math.huge or 128; LocalPlayer.CameraMinZoomDistance=0.5 end
function Vis.SetCrosshair(e)
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end); State.CrosshairGui=nil end
    if not e then return end
    local sg=Instance.new("ScreenGui"); sg.Name="X0_Cross"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; sg.Parent=GuiParent()
    local dot=Instance.new("Frame",sg); dot.Size=UDim2.new(0,4,0,4); dot.Position=UDim2.new(0.5,-2,0.5,-2); dot.BackgroundColor3=Color3.fromRGB(255,50,50); dot.BorderSizePixel=0
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0); State.CrosshairGui=sg
end

local function SetFPSBoost(e)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then pcall(function() v.Enabled=not e end) end
    end
    pcall(function() settings().Rendering.QualityLevel=e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic end)
end

local function ServerHop()
    pcall(function()
        local raw=game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100")
        local ok,data=pcall(HttpService.JSONDecode,HttpService,raw)
        if ok and data and data.data then for _,s in ipairs(data.data) do if s.playing<s.maxPlayers and s.id~=game.JobId then TeleportService:TeleportToPlaceInstance(game.PlaceId,s.id,LocalPlayer); return end end end
        Notify("Server Hop","No server found",4)
    end)
end

CM:Add(LocalPlayer.Idled,function() if State.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end end)

-- ═══════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════
KB.Register("WalkSpeed",Enum.KeyCode.V,function() State.WalkSpeedEnabled=not State.WalkSpeedEnabled; SetWalkSpeed(State.WalkSpeedEnabled); Notify("Walk Speed",State.WalkSpeedEnabled and "ON" or "OFF",1.5) end,true)
KB.Register("AutoHeal",Enum.KeyCode.H,function() State.AutoHeal=not State.AutoHeal; SetAutoHeal(State.AutoHeal); Notify("Auto Heal",State.AutoHeal and "ON" or "OFF",1.5) end,true)
KB.Register("Invisible",Enum.KeyCode.G,function() if not Char() then return end; State.Invisible=not State.Invisible; SetInvisible(State.Invisible) end,true)
KB.Register("GoLobby",Enum.KeyCode.F5,function() GoToLobby("Auto") end,false)

-- ═══════════════════════════════════════════════════════════════
-- FLUENT UI WINDOW
-- ═══════════════════════════════════════════════════════════════
local Window = Fluent:CreateWindow({
    Title    = HUB.Name .. " v" .. HUB.Version,
    SubTitle = HUB.Game .. " | " .. HUB.Author,
    TabWidth = 160,
    Size     = UDim2.fromOffset(620, 450),
    Acrylic  = true,
    Theme    = "Dark",
    MinimizeKey = Enum.KeyCode.Insert,
})

local Tabs = {
    ESP      = Window:AddTab({ Title="ESP",      Icon="eye"      }),
    Survivor = Window:AddTab({ Title="Survivor", Icon="shield"   }),
    Teleport = Window:AddTab({ Title="Teleport", Icon="map-pin"  }),
    Killer   = Window:AddTab({ Title="Killer",   Icon="swords"   }),
    Visuals  = Window:AddTab({ Title="Visuals",  Icon="sun"      }),
    Misc     = Window:AddTab({ Title="Misc",     Icon="wrench"   }),
    Settings = Window:AddTab({ Title="Settings", Icon="settings" }),
}

-- ── ESP TAB ─────────────────────────────────────────────────────
Tabs.ESP:AddToggle("ESP_Player",  {Title="Player ESP (Killer = RED)", Default=false}):OnChanged(function(v) State.ESP_Player=v; ESP.RefreshAll() end)
Tabs.ESP:AddToggle("ESP_Zombie",  {Title="Zombie / Cure ESP",Default=false}):OnChanged(function(v) State.ESP_Zombie=v; ESP.ScanZombies() end)
Tabs.ESP:AddToggle("ESP_HP",      {Title="Health Bar",     Default=true}):OnChanged(function(v) State.ESP_HealthBar=v end)
Tabs.ESP:AddToggle("ESP_Dist",    {Title="Distance",       Default=true}):OnChanged(function(v) State.ESP_Distance=v end)
Tabs.ESP:AddToggle("ESP_Gen",     {Title="Generator ESP",  Default=false}):OnChanged(function(v) State.ESP_Generator=v; ESP.ScanGens() end)
Tabs.ESP:AddToggle("ESP_Pallet",  {Title="Pallet ESP",     Default=false}):OnChanged(function(v) State.ESP_Pallet=v; ESP.ScanPallets() end)
Tabs.ESP:AddToggle("ESP_Vault",   {Title="Vault ESP",      Default=false}):OnChanged(function(v) State.ESP_Vault=v; ESP.ScanVaults() end)
Tabs.ESP:AddToggle("ESP_Exit",    {Title="Exit Gate ESP",  Default=false}):OnChanged(function(v) State.ESP_Exit=v; ESP.ScanExits() end)
Tabs.ESP:AddSlider("ESP_MaxDist", {Title="Max Distance", Default=1500, Min=100, Max=3000, Rounding=0}):OnChanged(function(v) State.ESP_MaxDistance=v end)
Tabs.ESP:AddButton({Title="Refresh ESP", Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Notify("ESP","Refreshed",2) end})
Tabs.ESP:AddButton({Title="Force Re-scan Killers", Callback=function()
    for obj, entry in pairs(State.ESPCache) do
        if entry.kind == "player" and entry.playerRef then
            local nowKiller = IsPlayerKiller(entry.playerRef, obj)
            entry.isKiller = nowKiller
            if entry.nl then
                entry.nl.Text = nowKiller and ("[KILLER] " .. entry.playerRef.Name) or ("[" .. entry.playerRef.Name .. "]")
            end
        end
    end
    Notify("ESP","Killer status re-checked",3)
end})

-- ── SURVIVOR TAB ────────────────────────────────────────────────
Tabs.Survivor:AddToggle("RemoveSC",{Title="Remove Skillcheck",Default=false}):OnChanged(function(v) State.RemoveSkillcheck=v; SetRemoveSkillcheck(v) end)
Tabs.Survivor:AddSlider("GenRadius",{Title="Killer Safety Radius",Default=30,Min=10,Max=100,Rounding=0}):OnChanged(function(v) State.GenKillerRadius=v end)
Tabs.Survivor:AddDropdown("GenMode",{Title="Gen Mode",Values={"Legit","Instant"},Default="Legit"}):OnChanged(function(v) State.AutoGenMode=v end)
Tabs.Survivor:AddToggle("AutoGen",{Title="Auto Gen Rush",Default=false}):OnChanged(function(v) State.AutoGenRush=v; SetAutoGenRush(v) end)
Tabs.Survivor:AddSlider("HealHP",{Title="Heal Below HP %",Default=60,Min=10,Max=95,Rounding=0}):OnChanged(function(v) State.AutoHealThreshold=v end)
Tabs.Survivor:AddToggle("AutoHeal",{Title="Auto Heal (HH)",Default=false}):OnChanged(function(v) State.AutoHeal=v; SetAutoHeal(v) end)
Tabs.Survivor:AddToggle("NoFall",{Title="No Fall Damage",Default=false}):OnChanged(function(v) State.NoFallDamage=v; SetNoFall(v) end)
Tabs.Survivor:AddSlider("WalkSpd",{Title="Walk Speed",Default=28,Min=16,Max=80,Rounding=0}):OnChanged(function(v) State.WalkSpeedValue=v; if State.WalkSpeedEnabled then SetWalkSpeed(true) end end)
Tabs.Survivor:AddToggle("WalkSpdOn",{Title="Walk Speed (VV)",Default=false}):OnChanged(function(v) State.WalkSpeedEnabled=v; SetWalkSpeed(v) end)
Tabs.Survivor:AddToggle("FastVault",{Title="Fast Vault",Default=false}):OnChanged(function(v) State.FastVault=v; SetFastVault(v) end)
Tabs.Survivor:AddToggle("Invis",{Title="Invisible (GG)",Default=false}):OnChanged(function(v) State.Invisible=v; SetInvisible(v) end)
Tabs.Survivor:AddToggle("UnlockCur",{Title="Unlock Cursor",Default=false}):OnChanged(function(v) State.UnlockCursor=v; SetUnlockCursor(v) end)

-- ── TELEPORT TAB ────────────────────────────────────────────────
Tabs.Teleport:AddDropdown("LobbyMethod",{Title="Lobby Method",Values={"Auto","Remote","Position","Rejoin","Die"},Default="Auto"}):OnChanged(function(v) LobbyState.Method=v end)
Tabs.Teleport:AddButton({Title="Go To Lobby (F5)", Callback=function() GoToLobby(LobbyState.Method) end})
Tabs.Teleport:AddButton({Title="Detect Lobby Info", Callback=function()
    task.spawn(function()
        local im=IsInMatch(); local lp=FindLobbyPosition(); local li=FindLobbyPlaceId(); local lr=FindLobbyRemotes()
        Notify("Lobby","Match="..tostring(im).." Pos="..(lp and "YES" or "NO").." Id="..tostring(li).." Remotes="..#lr,6)
    end)
end})

local tpNames = GetPlayerNames()
local tpDrop = Tabs.Teleport:AddDropdown("TPPlayer",{Title="Select Player",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.TeleportTarget=(v=="None") and nil or v end)
Tabs.Teleport:AddButton({Title="Teleport Now",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local ok=TeleportToPlayer(State.TeleportTarget,Vector3.new(2,0,2))
    Notify("TP",ok and ("To "..State.TeleportTarget) or "Failed",3)
end})
Tabs.Teleport:AddButton({Title="Teleport Behind",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local p=FindPlayerByName(State.TeleportTarget); if not p or not p.Character then return end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); if not prp then return end
    local behind=prp.CFrame*CFrame.new(0,0,3); local hrp=HRP(); if not hrp then return end
    if State.Invisible then State.InvisOriginalCF=behind; pcall(function() hrp.CFrame=behind end)
        task.delay(0.05,function() if State.Invisible then pcall(function() hrp.CFrame=CFrame.new(0,VOID_Y,0) end) end end)
    else pcall(function() hrp.CFrame=behind end) end
    Notify("TP","Behind "..State.TeleportTarget,2)
end})
Tabs.Teleport:AddButton({Title="Bring Player to Me",Callback=function()
    if not State.TeleportTarget then Notify("TP","No player",3); return end
    local p=FindPlayerByName(State.TeleportTarget); if not p or not p.Character then return end
    local prp=p.Character:FindFirstChild("HumanoidRootPart"); local hrp=HRP()
    if prp and hrp then pcall(function() prp.CFrame=hrp.CFrame+Vector3.new(2,0,0) end); Notify("TP","Brought "..State.TeleportTarget,3) end
end})

local followDrop = Tabs.Teleport:AddDropdown("FollowPlayer",{Title="Follow Target",Values=tpNames,Default=tpNames[1]}):OnChanged(function(v) State.AutoFollowTarget=(v=="None") and nil or v end)
Tabs.Teleport:AddSlider("FollowOff",{Title="Follow Offset",Default=2,Min=0,Max=8,Rounding=0}):OnChanged(function(v) State.AutoFollowOffset=Vector3.new(v,0,v) end)
Tabs.Teleport:AddToggle("AutoFollow",{Title="Auto Follow",Default=false}):OnChanged(function(v) State.AutoFollowEnabled=v; SetAutoFollow(v) end)
Tabs.Teleport:AddButton({Title="Refresh Player List",Callback=function()
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n); tpDrop:SetValue(n[1] or "None") end)
    pcall(function() followDrop:SetValues(n); followDrop:SetValue(n[1] or "None") end)
    State.TeleportTarget=(n[1]~="None") and n[1] or nil; State.AutoFollowTarget=State.TeleportTarget
    Notify("TP","Refreshed - "..#n.." player(s)",3)
end})

-- Auto-refresh player list
CM:Add(Players.PlayerAdded,function() task.wait(1)
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end)
    pcall(function() followDrop:SetValues(n) end)
end)
CM:Add(Players.PlayerRemoving,function(p) task.wait(0.5)
    if State.TeleportTarget==p.Name then State.TeleportTarget=nil end
    if State.AutoFollowTarget==p.Name then State.AutoFollowTarget=nil; if State.AutoFollowEnabled then SetAutoFollow(false) end end
    local n=GetPlayerNames()
    pcall(function() tpDrop:SetValues(n) end)
    pcall(function() followDrop:SetValues(n) end)
end)

-- ── KILLER TAB ──────────────────────────────────────────────────
Tabs.Killer:AddSlider("HitRange",{Title="Hit Range",Default=12,Min=5,Max=40,Rounding=0}):OnChanged(function(v) State.AutoHitRange=v end)
Tabs.Killer:AddToggle("AutoHit",{Title="Auto Hit",Default=false}):OnChanged(function(v) State.AutoHit=v; SetAutoHit(v) end)
Tabs.Killer:AddSlider("HitAllDelay",{Title="Hit All Delay (sec)",Default=5,Min=1,Max=30,Rounding=0}):OnChanged(function(v) State.AutoHitAllDelay=v end)
Tabs.Killer:AddToggle("AutoHitAll",{Title="Auto Hit All",Default=false}):OnChanged(function(v) State.AutoHitAll=v; SetAutoHitAll(v) end)
Tabs.Killer:AddButton({Title="Hit All Now",Callback=function()
    local pl=GetAllOtherPlayers(); if #pl==0 then Notify("Hit","No players",2); return end
    for _,p in ipairs(pl) do pcall(FireHit,p) end; Notify("Hit","Hit "..#pl,3)
end})
Tabs.Killer:AddToggle("InstDmgGen",{Title="Instant Damage Gen",Default=false}):OnChanged(function(v) State.InstantDamageGen=v end)
Tabs.Killer:AddToggle("AutoDmgGen",{Title="Auto Damage Gen",Default=false}):OnChanged(function(v) State.AutoDamageGen=v; SetAutoDamageGen(v) end)
Tabs.Killer:AddToggle("InstPallet",{Title="Instant Break Pallet",Default=false}):OnChanged(function(v) State.InstantBreakPallet=v; SetInstantBreakPallet(v) end)
Tabs.Killer:AddSlider("KillerSpd",{Title="Killer Speed",Default=30,Min=16,Max=120,Rounding=0}):OnChanged(function(v) State.KillerWalkSpeedValue=v; if State.KillerWalkSpeedEnabled then SetKillerWalkSpeed(true) end end)
Tabs.Killer:AddToggle("KillerSpdOn",{Title="Killer Walk Speed",Default=false}):OnChanged(function(v) State.KillerWalkSpeedEnabled=v; SetKillerWalkSpeed(v) end)
Tabs.Killer:AddToggle("NoStun",{Title="No Stun",Default=false}):OnChanged(function(v) State.NoStun=v; SetNoStun(v) end)
Tabs.Killer:AddToggle("NoSlow",{Title="No Slowdown",Default=false}):OnChanged(function(v) State.NoSlowdown=v; SetNoSlowdown(v) end)

-- ── VISUALS TAB ─────────────────────────────────────────────────
Tabs.Visuals:AddToggle("FullBright",{Title="Full Bright",Default=false}):OnChanged(function(v) State.FullBright=v; Vis.FullBright(v) end)
Tabs.Visuals:AddToggle("NoFog",{Title="No Fog",Default=false}):OnChanged(function(v) State.NoFog=v; Vis.NoFog(v) end)
Tabs.Visuals:AddToggle("NoShadow",{Title="No Shadows",Default=false}):OnChanged(function(v) State.NoShadows=v; Vis.NoShadows(v) end)
Tabs.Visuals:AddToggle("UnlimZoom",{Title="Unlimited Zoom",Default=false}):OnChanged(function(v) State.UnlimitedZoom=v; Vis.UnlimitedZoom(v) end)
Tabs.Visuals:AddToggle("Crosshair",{Title="Crosshair",Default=false}):OnChanged(function(v) State.Crosshair=v; Vis.SetCrosshair(v) end)

-- ── MISC TAB ────────────────────────────────────────────────────
Tabs.Misc:AddToggle("AntiAFK",{Title="Anti AFK",Default=true}):OnChanged(function(v) State.AntiAFK=v end)
Tabs.Misc:AddToggle("FPSBoost",{Title="FPS Boost",Default=false}):OnChanged(function(v) State.FPSBoost=v; SetFPSBoost(v) end)
Tabs.Misc:AddButton({Title="Rejoin",Callback=function() pcall(function() TeleportService:Teleport(game.PlaceId,LocalPlayer) end) end})
Tabs.Misc:AddButton({Title="Server Hop",Callback=ServerHop})
Tabs.Misc:AddButton({Title="Copy Discord",Callback=function()
    if setclipboard then setclipboard(HUB.Discord); Notify("Discord","Copied!",3) else Notify("Discord",HUB.Discord,5) end
end})

-- ── SETTINGS TAB ────────────────────────────────────────────────
Tabs.Settings:AddToggle("Notifs",{Title="Notifications",Default=true}):OnChanged(function(v) State.Notifications=v end)
Tabs.Settings:AddButton({Title="Unload Hub",Callback=function()
    SetInvisible(false); SetAutoHeal(false); SetRemoveSkillcheck(false)
    SetAutoFollow(false); SetAutoHit(false); SetAutoHitAll(false)
    SetAutoDamageGen(false); SetInstantBreakPallet(false)
    SetNoStun(false); SetNoSlowdown(false); SetUnlockCursor(false)
    Vis.SetCrosshair(false); Vis.Restore()
    LocalPlayer.CameraMaxZoomDistance=128
    if ESPRender then ESPRender:Disconnect() end
    if ESPGui then pcall(function() ESPGui:Destroy() end) end
    if State.CrosshairGui then pcall(function() State.CrosshairGui:Destroy() end) end
    CM:Cleanup(); ESP.ClearAll(); _G[INSTANCE_KEY]=nil
    pcall(function() Fluent:Destroy() end)
end})

SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("X0DEC04T")
SaveManager:SetFolder("X0DEC04T/violence-district")
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- ═══════════════════════════════════════════════════════════════
-- RESPAWN
-- ═══════════════════════════════════════════════════════════════
CM:Add(LocalPlayer.CharacterAdded,function()
    task.wait(1.5)
    State.Invisible=false; State.InvisOriginalCF=nil; DisconnectInvis()
    if State.WalkSpeedEnabled       then pcall(SetWalkSpeed,true)       end
    if State.KillerWalkSpeedEnabled then pcall(SetKillerWalkSpeed,true) end
    if State.NoFallDamage           then pcall(SetNoFall,true)          end
    if State.AutoHeal               then pcall(SetAutoHeal,true)        end
    if State.RemoveSkillcheck       then pcall(SetRemoveSkillcheck,true)end
    if State.AutoFollowEnabled      then pcall(SetAutoFollow,true)      end
    if State.AutoHit                then pcall(SetAutoHit,true)         end
    if State.AutoHitAll             then pcall(SetAutoHitAll,true)      end
    if State.NoStun                 then pcall(SetNoStun,true)          end
    if State.NoSlowdown             then pcall(SetNoSlowdown,true)      end
    if State.UnlimitedZoom          then pcall(Vis.UnlimitedZoom,true)  end
    if State.UnlockCursor           then pcall(SetUnlockCursor,true)    end
    task.wait(0.5); ESP.RefreshAll()
end)

_G[INSTANCE_KEY]={
    version=HUB.Version,
    destroy=function() pcall(SetInvisible,false); DisconnectInvis(); pcall(function() Fluent:Destroy() end) end
}

Window:SelectTab(1)
Notify(HUB.Name,"v"..HUB.Version.." Loaded - Killer ESP fixed",6)
Log("v0.0.7 fully loaded")
