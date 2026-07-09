--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v0.0.6 - Violence District
-- Fixed build: synchronous UI, API discovery, state machine
--═══════════════════════════════════════════════════════════════

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SERVICES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local Lighting          = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LOGGER
-- All output goes through here so every message has a prefix
-- and elapsed timestamp. Never yields.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Logger = {}
Logger._start = os.clock()

function Logger.log(msg)
    local t = string.format("%.3f", os.clock() - Logger._start)
    print(string.format("[X0DEC04T][+%ss] %s", t, tostring(msg)))
end

function Logger.warn(msg)
    local t = string.format("%.3f", os.clock() - Logger._start)
    warn(string.format("[X0DEC04T][+%ss] WARN: %s", t, tostring(msg)))
end

function Logger.fail(msg, detail)
    local t = string.format("%.3f", os.clock() - Logger._start)
    warn(string.format("[X0DEC04T][+%ss] FAIL: %s | %s", t, tostring(msg), tostring(detail or "")))
end

Logger.log("Script started")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INITIALIZATION STATE MACHINE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Boot = {}

Boot.States = {
    NOT_STARTED      = "NOT_STARTED",
    LOADING_LIBRARY  = "LOADING_LIBRARY",
    CREATING_WINDOW  = "CREATING_WINDOW",
    CREATING_TABS    = "CREATING_TABS",
    CREATING_CONTROLS= "CREATING_CONTROLS",
    READY            = "READY",
    FAILED           = "FAILED",
}

Boot._state   = Boot.States.NOT_STARTED
Boot._aborted = false

function Boot.SetState(s)
    Logger.log("State -> " .. tostring(s))
    Boot._state = s
end

function Boot.Fail(reason, detail)
    Boot.SetState(Boot.States.FAILED)
    Logger.fail(reason, detail)
    Boot._aborted = true
end

function Boot.IsAborted()
    return Boot._aborted
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- INSTANCE MANAGER
-- Replaces the old _G.__X0DEC04T_LOADED boolean.
-- Stores version, window reference, destroy function, timestamp.
-- Destroys any previous instance before continuing.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local INSTANCE_KEY = "__X0DEC04T_INSTANCE"
local HUB_VERSION  = "0.0.6"

local function DestroyPreviousInstance()
    local prev = _G[INSTANCE_KEY]
    if not prev then return end

    Logger.log("Previous instance found (v"
        .. tostring(prev.version)
        .. " started at "
        .. tostring(prev.timestamp)
        .. ") - destroying now")

    if type(prev.destroy) == "function" then
        local ok, err = pcall(prev.destroy)
        if not ok then
            Logger.warn("Previous destroy() threw: " .. tostring(err))
        end
    end

    _G[INSTANCE_KEY] = nil
    Logger.log("Previous instance destroyed")
end

local function RegisterInstance(window, destroyFn)
    _G[INSTANCE_KEY] = {
        version   = HUB_VERSION,
        window    = window,
        destroy   = destroyFn,
        timestamp = os.time(),
    }
    Logger.log("Instance registered (v" .. HUB_VERSION .. ")")
end

-- Destroy old instance synchronously before anything else
DestroyPreviousInstance()

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- CONNECTION MANAGER
-- Every RBXScriptConnection created in this script is tracked
-- here. Unload() disconnects everything in one call.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ConnectionManager = {}
ConnectionManager._list = {}

function ConnectionManager:Add(conn, label)
    if not conn then
        Logger.warn("ConnectionManager:Add - nil connection for: " .. tostring(label))
        return
    end
    table.insert(self._list, { conn = conn, label = tostring(label or "?") })
    Logger.log("Signal Connected: " .. tostring(label or "?"))
end

function ConnectionManager:Connect(signal, callback, label)
    if not signal then
        Logger.warn("Signal Failed (nil signal): " .. tostring(label or "?"))
        return nil
    end
    if type(callback) ~= "function" then
        Logger.warn("Signal Failed (nil callback): " .. tostring(label or "?"))
        return nil
    end
    local ok, conn = pcall(function()
        return signal:Connect(callback)
    end)
    if not ok or not conn then
        Logger.warn("Signal Failed: " .. tostring(label or "?") .. " | " .. tostring(conn))
        return nil
    end
    self:Add(conn, label)
    return conn
end

function ConnectionManager:Cleanup()
    local count = 0
    for _, entry in ipairs(self._list) do
        local ok, err = pcall(function() entry.conn:Disconnect() end)
        if not ok then
            Logger.warn("Disconnect failed for [" .. entry.label .. "]: " .. tostring(err))
        end
        count = count + 1
    end
    self._list = {}
    Logger.log("ConnectionManager cleaned up " .. count .. " connections")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OBJECT VALIDATOR
-- Checks that an object is non-nil and has the required methods.
-- On failure: logs exact object, method, error. Returns false.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function ValidateObject(obj, label, requiredMethods)
    if obj == nil then
        Logger.fail("Object is nil", label)
        return false
    end

    local t = type(obj)
    if t ~= "table" and t ~= "userdata" then
        Logger.fail("Object has wrong type: " .. t, label)
        return false
    end

    if requiredMethods then
        for _, methodName in ipairs(requiredMethods) do
            if type(obj[methodName]) ~= "function" then
                Logger.fail(
                    label .. " missing method '" .. methodName .. "'",
                    "got: " .. type(obj[methodName])
                )
                return false
            end
        end
    end

    Logger.log(label .. " validated OK")
    return true
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- API DISCOVERY LAYER
-- Probes any UI library object and returns a translation table
-- mapping logical names to actual method names.
-- This layer is the ONLY thing that calls raw UI methods.
-- All other code calls API functions, never raw methods.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local UIAdapter = {}

-- Maps logical → list of candidate method names in priority order
local WINDOW_CREATE_CANDIDATES = {
    "CreateWindow", "createWindow", "new", "New", "Window",
}

local TAB_CREATE_CANDIDATES = {
    "Tab", "AddTab", "MakeTab", "createTab", "addTab",
}

local ELEMENT_CANDIDATES = {
    Section   = { "Section",  "AddSection",  "addSection",  "MakeSection"  },
    Toggle    = { "Toggle",   "AddToggle",   "addToggle",   "MakeToggle"   },
    Button    = { "Button",   "AddButton",   "addButton",   "MakeButton"   },
    Slider    = { "Slider",   "AddSlider",   "addSlider",   "MakeSlider"   },
    Input     = { "Input",    "AddInput",    "addInput",    "AddTextbox",
                  "Textbox",  "MakeInput"                                   },
    Paragraph = { "Paragraph","AddParagraph","addParagraph","MakeParagraph" },
    Dropdown  = { "Dropdown", "AddDropdown", "addDropdown", "MakeDropdown" },
    Keybind   = { "Keybind",  "AddKeybind",  "addKeybind",  "AddBind",
                  "Bind",     "MakeBind"                                    },
}

-- Discover which method name on `obj` matches one of the candidates
local function discoverMethod(obj, candidates, logical)
    for _, name in ipairs(candidates) do
        if type(obj[name]) == "function" then
            Logger.log("  Discovered " .. logical .. " -> obj." .. name)
            return name
        end
    end
    -- Dump all keys for diagnosis if nothing found
    Logger.warn("  Could not find method for: " .. logical)
    local found = {}
    for k, v in pairs(obj) do
        table.insert(found, k .. "(" .. type(v) .. ")")
    end
    Logger.warn("  Available keys: " .. table.concat(found, ", "))
    return nil
end

-- Probe library-level: find CreateWindow equivalent
function UIAdapter.ProbeLibrary(lib)
    Logger.log("Probing library API...")
    local createFn = discoverMethod(lib, WINDOW_CREATE_CANDIDATES, "CreateWindow")
    return createFn
end

-- Probe window-level: find Tab creation method
function UIAdapter.ProbeWindow(win)
    Logger.log("Probing Window API...")
    local tabFn = discoverMethod(win, TAB_CREATE_CANDIDATES, "Tab")
    return tabFn
end

-- Probe tab-level: build full element method map
-- Returns { Section="Section", Toggle="AddToggle", ... } or nil
function UIAdapter.ProbeTab(tab, tabName)
    Logger.log("Probing Tab[" .. tostring(tabName) .. "] API...")
    local map = {}
    local allFound = true

    for logical, candidates in pairs(ELEMENT_CANDIDATES) do
        local actual = discoverMethod(tab, candidates, logical)
        if actual then
            map[logical] = actual
        else
            Logger.warn("Tab[" .. tostring(tabName) .. "]: no method for " .. logical)
            -- Do not abort — continue with partial map
            allFound = false
        end
    end

    Logger.log("Tab API probe complete. All methods found: " .. tostring(allFound))
    return map
end

-- The method map populated after first tab creation
UIAdapter._methodMap  = {}
UIAdapter._tabFn      = nil   -- actual window method to create a tab
UIAdapter._window     = nil   -- reference to the window object
UIAdapter._lib        = nil   -- reference to the library

-- Call a tab-level element method using the discovered map
-- tab        : the tab object
-- logical    : "Toggle", "Button", etc.
-- cfg        : config table passed to the method
-- label      : debug label
-- Returns the result (may be nil for void methods)
function UIAdapter.Call(tab, logical, cfg, label)
    if not tab then
        Logger.fail("UIAdapter.Call: tab is nil", label)
        return nil
    end

    local actualName = UIAdapter._methodMap[logical]
    if not actualName then
        Logger.fail("UIAdapter.Call: no mapping for '" .. logical .. "'", label)
        return nil
    end

    local method = tab[actualName]
    if type(method) ~= "function" then
        Logger.fail(
            "UIAdapter.Call: tab." .. actualName .. " is not a function",
            "type=" .. type(method) .. " label=" .. tostring(label)
        )
        return nil
    end

    local ok, result = pcall(method, tab, cfg)
    if not ok then
        Logger.fail(
            "UIAdapter.Call: " .. actualName .. " threw an error",
            "label=" .. tostring(label) .. " err=" .. tostring(result)
        )
        return nil
    end

    Logger.log("Control Created: " .. tostring(label or logical))
    return result
end

-- Convenience wrappers so call sites read cleanly
local function Sec(tab, title)
    UIAdapter.Call(tab, "Section",   { Title = title }, "Section:" .. tostring(title))
end
local function Tog(tab, cfg,  label) UIAdapter.Call(tab, "Toggle",    cfg, label) end
local function Btn(tab, cfg,  label) UIAdapter.Call(tab, "Button",    cfg, label) end
local function Sld(tab, cfg,  label) UIAdapter.Call(tab, "Slider",    cfg, label) end
local function Inp(tab, cfg,  label) UIAdapter.Call(tab, "Input",     cfg, label) end
local function Par(tab, cfg,  label) UIAdapter.Call(tab, "Paragraph", cfg, label) end
local function Drp(tab, cfg,  label) UIAdapter.Call(tab, "Dropdown",  cfg, label) end
local function Kbnd(tab, cfg, label) UIAdapter.Call(tab, "Keybind",   cfg, label) end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HUB CONFIG
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Violence District",
    Version = HUB_VERSION,
    Author  = "voixera",
    Folder  = "X0DEC04T_Hub",
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- KILLER LIST
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local KillerFolder  = ReplicatedStorage:FindFirstChild("Killers")
local KNOWN_KILLERS = {}
if KillerFolder then
    for _, child in ipairs(KillerFolder:GetChildren()) do
        local n = child.Name
        if n ~= "!General" and n ~= "Perks" then
            KNOWN_KILLERS[n:lower()] = true
        end
    end
end
Logger.log("Known killers loaded: " .. tostring(
    (function() local c=0; for _ in pairs(KNOWN_KILLERS) do c=c+1 end; return c end)()
))

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local R = {
    Generator   = {},
    Healing     = {},
    Chase       = {},
    Attacks     = {},
    KillerPerks = {},
    Game        = {},
    Carry       = {},
}

if Remotes then
    local function find(parent, name)
        return parent and parent:FindFirstChild(name) or nil
    end
    local gen = find(Remotes, "Generator")
    R.Generator.SkillCheck     = find(gen, "SkillCheckEvent")
    R.Generator.SkillCheckFail = find(gen, "SkillCheckFailEvent")
    R.Generator.GenDone        = find(gen, "GenDone")
    R.Generator.AllGenDone     = find(gen, "allgendone")
    local heal = find(Remotes, "Healing")
    R.Healing.SkillCheck = find(heal, "SkillCheckEvent")
    local ch = find(Remotes, "Chase")
    R.Chase.Music = find(ch, "ChaseMusicEvent")
    local atk = find(Remotes, "Attacks")
    R.Attacks.Lunge       = find(atk, "Lunge")
    R.Attacks.BasicAttack = find(atk, "BasicAttack")
    local kp = find(Remotes, "KillerPerks")
    R.KillerPerks.KingScourge = find(kp, "kingscourge")
    local gm = find(Remotes, "Game")
    R.Game.Start       = find(gm, "Start")
    R.Game.RoundEnd    = find(gm, "RoundEnd")
    R.Game.KillerMorph = find(gm, "KillerMorph")
    R.Game.OneLeft     = find(gm, "Oneleft")
    R.Game.Death       = find(gm, "death")
    local cr = find(Remotes, "Carry")
    R.Carry.HookEvent   = find(cr, "HookEvent")
    R.Carry.UnhookEvent = find(cr, "UnHookEvent")
    Logger.log("Remotes resolved")
else
    Logger.warn("Remotes folder not found in ReplicatedStorage")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- WORKSPACE REFS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local WS = {
    Map       = Workspace:FindFirstChild("Map"),
    Generators = nil,
    Clones    = Workspace:FindFirstChild("Clones"),
    FakeChars = Workspace:FindFirstChild("FakeCharacters"),
    Weapons   = Workspace:FindFirstChild("Weapons"),
}
if WS.Map then WS.Generators = WS.Map:FindFirstChild("Generators") end
Logger.log("WS.Generators = " .. tostring(WS.Generators ~= nil))

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STATE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {
    -- Awareness
    ChaseAlert       = true,
    AttackAlert      = true,
    SkillCheckNotify = true,
    HealSkillNotify  = true,
    GenDoneNotify    = true,
    AllGensNotify    = true,
    OneLeftNotify    = true,
    HookNotify       = true,
    DeathNotify      = true,
    -- ESP
    ESP_Generators   = false,
    ESP_Killer       = false,
    ESP_Survivors    = false,
    ESP_Items        = false,
    ESP_Weapons      = false,
    ESP_Clones       = false,
    ESP_MaxDistance  = 500,
    ESP_ShowDistance = true,
    ESP_ShowName     = true,
    Color_Killer     = Color3.fromRGB(255,  40,  40),
    Color_Survivor   = Color3.fromRGB( 60, 220, 255),
    Color_Generator  = Color3.fromRGB(255, 200,  60),
    Color_Item       = Color3.fromRGB(120, 255, 120),
    Color_Weapon     = Color3.fromRGB(255, 120, 220),
    Color_Clone      = Color3.fromRGB(180, 180, 180),
    -- Movement
    WalkSpeed  = 16,
    JumpPower  = 50,
    NoClip     = false,
    InfJump    = false,
    -- Visuals
    FullBright   = false,
    NoFog        = false,
    NoShadows    = false,
    ClearWeather = false,
    LowGraphics  = false,
    FOV          = 70,
    ClockTime    = 14,
    RemoveBlur   = false,
    RemoveCC     = false,
    Freecam      = false,
    -- Misc
    HideName    = false,
    NoSound     = false,
    MuteBGMusic = false,
    NoParticles = false,
    AutoRejoin  = false,
    AntiAFK     = true,
    -- Internal
    IsKiller    = false,
    MatchActive = false,
    ESPCache    = {},
    LightBackup = {},
    MutedSounds = {},
    -- Per-session connections (not in ConnectionManager because
    -- they live only while toggle is ON)
    NoClipConn  = nil,
    InfJumpConn = nil,
    FreecamConn = nil,
    AwarenessReady = false,
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UTILITIES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Util = {}

function Util.GetHRP()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

function Util.GetHuman()
    local ch = LocalPlayer.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

function Util.GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

-- Notify via whatever library is loaded. Called after UI is ready.
-- Safe to call before UI is ready (silently drops).
local _pendingNotifies = {}
local _uiReady         = false

function Util.Notify(title, body, dur)
    if not _uiReady then
        table.insert(_pendingNotifies, { title=title, body=body, dur=dur })
        return
    end
    pcall(function()
        UIAdapter._lib:Notify({
            Title    = tostring(title or ""),
            Content  = tostring(body  or ""),
            Duration = tonumber(dur)  or 4,
            Icon     = "bell",
        })
    end)
end

local function FlushNotifies()
    for _, n in ipairs(_pendingNotifies) do
        Util.Notify(n.title, n.body, n.dur)
    end
    _pendingNotifies = {}
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ROLE DETECTION
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Role = {}

function Role.IsKiller(char)
    if not char then return false end
    if char:GetAttribute("Killer")   == true     then return true end
    if char:GetAttribute("IsKiller") == true     then return true end
    if char:GetAttribute("Role")     == "Killer" then return true end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

function Role.KillerName(char)
    if not char then return "Killer" end
    local n = char.Name:lower()
    for k in pairs(KNOWN_KILLERS) do
        if n:find(k, 1, true) then return k:gsub("^%l", string.upper) end
    end
    return "Killer"
end

function Role.IsFake(char)
    if not char then return true end
    if WS.FakeChars and char:IsDescendantOf(WS.FakeChars) then return true end
    if WS.Clones    and char:IsDescendantOf(WS.Clones)    then return true end
    return false
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ESP
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ESP = {}

function ESP.Clear(obj)
    local cache = State.ESPCache[obj]
    if not cache then return end
    for _, inst in pairs(cache) do
        if typeof(inst) == "Instance" and inst.Parent then
            pcall(function() inst:Destroy() end)
        end
    end
    State.ESPCache[obj] = nil
end

function ESP.ClearAll()
    for obj in pairs(State.ESPCache) do ESP.Clear(obj) end
    State.ESPCache = {}
end

local function MakeBillboard(hrp, label, color, showName, showDist, maxDist)
    local bb = Instance.new("BillboardGui")
    bb.Adornee        = hrp
    bb.Size           = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset    = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop    = true
    bb.LightInfluence = 0
    bb.MaxDistance    = maxDist or 500
    bb.Parent         = Util.GuiParent()
    local nl = Instance.new("TextLabel", bb)
    nl.Size                   = UDim2.new(1, 0, 0.6, 0)
    nl.BackgroundTransparency = 1
    nl.Text                   = tostring(label or "")
    nl.TextColor3             = color
    nl.TextStrokeTransparency = 0
    nl.Font                   = Enum.Font.GothamBold
    nl.TextSize               = 14
    nl.Visible                = showName
    local dl = Instance.new("TextLabel", bb)
    dl.Size                   = UDim2.new(1, 0, 0.4, 0)
    dl.Position               = UDim2.new(0, 0, 0.6, 0)
    dl.BackgroundTransparency = 1
    dl.Text                   = "0m"
    dl.TextColor3             = Color3.fromRGB(220, 220, 220)
    dl.TextStrokeTransparency = 0
    dl.Font                   = Enum.Font.Gotham
    dl.TextSize               = 12
    dl.Visible                = showDist
    return bb, nl, dl
end

function ESP.AddChar(char, label, color)
    if State.ESPCache[char] then ESP.Clear(char) end
    local hrp = char:FindFirstChild("HumanoidRootPart")
              or char:FindFirstChild("Torso")
              or char:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end
    local hl = Instance.new("Highlight")
    hl.Adornee          = char
    hl.FillColor        = color
    hl.OutlineColor     = Color3.new(1, 1, 1)
    hl.FillTransparency = 0.55
    hl.DepthMode        = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent           = Util.GuiParent()
    local bb, nl, dl   = MakeBillboard(
        hrp, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance
    )
    State.ESPCache[char] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=hrp }
end

function ESP.AddObj(model, label, color)
    if State.ESPCache[model] then ESP.Clear(model) end
    local part = model
    if model:IsA("Model") then
        part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    end
    if not part then return end
    local hl = Instance.new("Highlight")
    hl.Adornee             = model
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.7
    hl.OutlineTransparency = 0.2
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = Util.GuiParent()
    local bb, nl, dl = MakeBillboard(
        part, label, color,
        State.ESP_ShowName, State.ESP_ShowDistance, State.ESP_MaxDistance
    )
    State.ESPCache[model] = { hl=hl, bb=bb, nl=nl, dl=dl, hrp=part }
end

function ESP.UpdateDist()
    local hrp = Util.GetHRP(); if not hrp then return end
    for _, c in pairs(State.ESPCache) do
        if c.dl and c.hrp and c.hrp.Parent then
            c.dl.Text = math.floor(
                (c.hrp.Position - hrp.Position).Magnitude
            ) .. "m"
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
            local isK  = Role.IsKiller(char)
            if isK and State.ESP_Killer and not State.ESPCache[char] then
                ESP.AddChar(char,
                    "☠ " .. Role.KillerName(char) .. " [" .. p.Name .. "]",
                    State.Color_Killer)
            elseif not isK and State.ESP_Survivors and not State.ESPCache[char] then
                ESP.AddChar(char, "◈ " .. p.Name, State.Color_Survivor)
            elseif (isK and not State.ESP_Killer) or
                   (not isK and not State.ESP_Survivors) then
                ESP.Clear(char)
            end
        end
    end
end

function ESP.ScanGens()
    if not WS.Generators then return end
    for _, g in ipairs(WS.Generators:GetChildren()) do
        if State.ESP_Generators and not State.ESPCache[g] then
            ESP.AddObj(g, "⚡ " .. g.Name, State.Color_Generator)
        elseif not State.ESP_Generators then ESP.Clear(g) end
    end
end

function ESP.ScanWeapons()
    if not WS.Weapons then return end
    for _, w in ipairs(WS.Weapons:GetChildren()) do
        if State.ESP_Weapons and not State.ESPCache[w] then
            ESP.AddObj(w, "⚔ " .. w.Name, State.Color_Weapon)
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

function ESP.ScanItems()
    for _, o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and
           (o:GetAttribute("Item") or o:GetAttribute("Pickup")) then
            if State.ESP_Items and not State.ESPCache[o] then
                ESP.AddObj(o, "🎒 " .. o.Name, State.Color_Item)
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
    ESP.ScanItems()
end

-- Background tasks - run independently, never block UI build
task.spawn(function()
    while task.wait(2) do pcall(ESP.RefreshAll) end
end)

ConnectionManager:Add(
    RunService.Heartbeat:Connect(function() pcall(ESP.UpdateDist) end),
    "ESP.UpdateDist"
)
ConnectionManager:Add(
    Players.PlayerRemoving:Connect(function(p)
        if p.Character then ESP.Clear(p.Character) end
    end),
    "Players.PlayerRemoving"
)
ConnectionManager:Add(
    Players.PlayerAdded:Connect(function(p)
        ConnectionManager:Add(
            p.CharacterRemoving:Connect(function(c) ESP.Clear(c) end),
            "CharacterRemoving:" .. p.Name
        )
    end),
    "Players.PlayerAdded"
)
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
        ConnectionManager:Add(
            p.CharacterRemoving:Connect(function(c) ESP.Clear(c) end),
            "CharacterRemoving:" .. p.Name
        )
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- MOVEMENT
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Move = {}

function Move.Speed()
    local h = Util.GetHuman()
    if h then h.WalkSpeed = State.WalkSpeed end
end

function Move.Jump()
    local h = Util.GetHuman()
    if h then h.UseJumpPower = true; h.JumpPower = State.JumpPower end
end

function Move.SetNoClip(e)
    if State.NoClipConn then
        pcall(function() State.NoClipConn:Disconnect() end)
        State.NoClipConn = nil
    end
    if e then
        State.NoClipConn = RunService.Stepped:Connect(function()
            local ch = LocalPlayer.Character; if not ch then return end
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
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
            local h = Util.GetHuman()
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end

local tpTargetName = ""

function Move.NearestGen()
    if not WS.Generators then
        Util.Notify("TP","No generators folder.",3); return
    end
    local hrp = Util.GetHRP(); if not hrp then return end
    local best, bd = nil, math.huge
    for _, g in ipairs(WS.Generators:GetChildren()) do
        local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
        if p then
            local d = (p.Position - hrp.Position).Magnitude
            if d < bd then bd=d; best=p end
        end
    end
    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0,4,0)
        Util.Notify("TP","Teleported (" .. math.floor(bd) .. "m)",3)
    end
end

function Move.ToPlayer()
    if tpTargetName == "" then
        Util.Notify("TP","Enter a name first.",3); return
    end
    local t = Players:FindFirstChild(tpTargetName)
    if not t or not t.Character then
        Util.Notify("TP","Not found: " .. tpTargetName,3); return
    end
    local hrp  = Util.GetHRP()
    local thrp = t.Character:FindFirstChild("HumanoidRootPart")
    if hrp and thrp then
        hrp.CFrame = thrp.CFrame + Vector3.new(0,0,3)
        Util.Notify("TP","Teleported to " .. tpTargetName,3)
    end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- VISUALS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Vis = {}

function Vis.BackupLight()
    if next(State.LightBackup) then return end
    State.LightBackup = {
        Ambient                  = Lighting.Ambient,
        OutdoorAmbient           = Lighting.OutdoorAmbient,
        Brightness               = Lighting.Brightness,
        ClockTime                = Lighting.ClockTime,
        FogEnd                   = Lighting.FogEnd,
        FogStart                 = Lighting.FogStart,
        GlobalShadows            = Lighting.GlobalShadows,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

function Vis.RestoreLight()
    for k,v in pairs(State.LightBackup) do
        pcall(function() Lighting[k]=v end)
    end
end

function Vis.FullBright(e)
    Vis.BackupLight()
    if e then
        Lighting.Ambient                  = Color3.fromRGB(255,255,255)
        Lighting.OutdoorAmbient           = Color3.fromRGB(255,255,255)
        Lighting.Brightness               = 2
        Lighting.ClockTime                = 14
        Lighting.GlobalShadows            = false
        Lighting.EnvironmentDiffuseScale  = 1
        Lighting.EnvironmentSpecularScale = 1
    else Vis.RestoreLight() end
end

function Vis.NoFog(e)
    Vis.BackupLight()
    if e then
        Lighting.FogEnd=999999; Lighting.FogStart=999999
        for _,a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a.Density=0; a.Haze=0 end
        end
    else
        Lighting.FogEnd   = State.LightBackup.FogEnd   or 100000
        Lighting.FogStart = State.LightBackup.FogStart or 0
    end
end

function Vis.NoShadows(e)
    Vis.BackupLight(); Lighting.GlobalShadows = not e
end

function Vis.ClearWx(e)
    if e then
        for _,o in ipairs(Lighting:GetDescendants()) do
            if o:IsA("Atmosphere") then o.Density=0; o.Haze=0 end
        end
    end
end

function Vis.LowGfx(e)
    pcall(function()
        settings().Rendering.QualityLevel =
            e and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end)
end

function Vis.SetFOV(f)
    if Camera then Camera.FieldOfView = tonumber(f) or 70 end
end

function Vis.SetClock(t) Lighting.ClockTime = tonumber(t) or 14 end

function Vis.PostFX(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect")
        or v:IsA("SunRaysEffect") or v:IsA("BloomEffect") then
            v.Enabled = not rm
        end
    end
end

function Vis.ColorCorr(rm)
    for _,v in ipairs(Lighting:GetDescendants()) do
        if v:IsA("ColorCorrectionEffect") then v.Enabled = not rm end
    end
end

function Vis.Particles(rm)
    for _,v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("ParticleEmitter") or v:IsA("Fire")
        or v:IsA("Smoke") or v:IsA("Sparkles") then
            v.Enabled = not rm
        end
    end
end

function Vis.HideName(e)
    local ch = LocalPlayer.Character; if not ch then return end
    local head = ch:FindFirstChild("Head"); if not head then return end
    for _,g in ipairs(head:GetChildren()) do
        if g:IsA("BillboardGui") then g.Enabled = not e end
    end
end

function Vis.MuteAll(e)
    if e then
        for _,s in ipairs(Workspace:GetDescendants()) do
            if s:IsA("Sound") and not table.find(State.MutedSounds, s) then
                table.insert(State.MutedSounds, {s=s, v=s.Volume})
                s.Volume = 0
            end
        end
    else
        for _,entry in ipairs(State.MutedSounds) do
            if entry.s and entry.s.Parent then entry.s.Volume = entry.v end
        end
        State.MutedSounds = {}
    end
end

function Vis.MuteBG(e)
    local bg = Workspace:FindFirstChild("BackgroundSounds"); if not bg then return end
    for _,s in ipairs(bg:GetDescendants()) do
        if s:IsA("Sound") then s.Volume = e and 0 or 1 end
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
            local look  = Camera.CFrame.LookVector
            local right = Camera.CFrame.RightVector
            local mv    = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv=mv+look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv=mv-look  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv=mv-right end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv=mv+right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)
            then mv=mv+Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
            then mv=mv-Vector3.new(0,1,0) end
            pos = pos + mv*2
            Camera.CFrame = CFrame.new(pos, pos+look)
        end)
    else
        Camera.CameraType = Enum.CameraType.Custom
    end
end

function Vis.ServerHop()
    local ok,e = pcall(function()
        local TS  = game:GetService("TeleportService")
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId)
            .. "/servers/Public?sortOrder=Asc&limit=100"
        )
        local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if dok and data and data.data then
            for _,s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TS:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
        Util.Notify("Server Hop","No server found.",4)
    end)
    if not ok then Util.Notify("Server Hop","Error: " .. tostring(e),4) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- AWARENESS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function SetupAwareness()
    if State.AwarenessReady then return end
    State.AwarenessReady = true

    -- Each connection passes the signal directly (not `nil and signal`).
    -- ConnectionManager.Connect handles nil signals gracefully.
    local CM = ConnectionManager

    CM:Connect(R.Generator.SkillCheck and R.Generator.SkillCheck.OnClientEvent,
        function()
            if State.SkillCheckNotify then
                Util.Notify("Skill Check!","Hit the mark!",2)
            end
        end, "GenSkillCheck")

    CM:Connect(R.Generator.SkillCheckFail and R.Generator.SkillCheckFail.OnClientEvent,
        function()
            if State.SkillCheckNotify then
                Util.Notify("Skill Check FAIL","Progress lost!",3)
            end
        end, "GenSkillFail")

    CM:Connect(R.Healing.SkillCheck and R.Healing.SkillCheck.OnClientEvent,
        function()
            if State.HealSkillNotify then Util.Notify("Heal Check!","",2) end
        end, "HealSkillCheck")

    CM:Connect(R.Generator.GenDone and R.Generator.GenDone.OnClientEvent,
        function()
            if State.GenDoneNotify then Util.Notify("Generator Done!","",3) end
        end, "GenDone")

    CM:Connect(R.Generator.AllGenDone and R.Generator.AllGenDone.OnClientEvent,
        function()
            if State.AllGensNotify then
                Util.Notify("All Generators Done!","Find the exit!",6)
            end
        end, "AllGensDone")

    CM:Connect(R.Chase.Music and R.Chase.Music.OnClientEvent,
        function()
            if State.ChaseAlert then Util.Notify("⚠ CHASE!","Killer nearby!",3) end
        end, "ChaseMusic")

    CM:Connect(R.Attacks.Lunge and R.Attacks.Lunge.OnClientEvent,
        function()
            if State.AttackAlert then Util.Notify("⚠ LUNGE!","",2) end
        end, "Lunge")

    if R.KillerPerks.KingScourge then
        local s = R.KillerPerks.KingScourge:FindFirstChild("KingScourgeStart")
        CM:Connect(s and s.OnClientEvent,
            function()
                if State.AttackAlert then Util.Notify("⚠ SCOURGE!","",2) end
            end, "KingScourge")
    end

    CM:Connect(R.Game.KillerMorph and R.Game.KillerMorph.OnClientEvent,
        function()
            State.IsKiller = true
            Util.Notify("Role","You are the KILLER",5)
        end, "KillerMorph")

    CM:Connect(R.Game.Start and R.Game.Start.OnClientEvent,
        function()
            State.MatchActive = true; State.IsKiller = false
            Util.Notify("Match Started","Good luck!",3)
        end, "GameStart")

    CM:Connect(R.Game.RoundEnd and R.Game.RoundEnd.OnClientEvent,
        function()
            State.MatchActive = false; ESP.ClearAll()
        end, "RoundEnd")

    CM:Connect(R.Game.OneLeft and R.Game.OneLeft.OnClientEvent,
        function()
            if State.OneLeftNotify then Util.Notify("Last Survivor!","",5) end
        end, "OneLeft")

    CM:Connect(R.Game.Death and R.Game.Death.OnClientEvent,
        function()
            if State.DeathNotify then Util.Notify("You Died","",3) end
        end, "Death")

    CM:Connect(R.Carry.HookEvent and R.Carry.HookEvent.OnClientEvent,
        function()
            if State.HookNotify then Util.Notify("Hooked!","",3) end
        end, "Hook")

    CM:Connect(LocalPlayer.Idled,
        function()
            if State.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.zero)
            end
        end, "AntiAFK")

    Logger.log("Awareness ready - all signals connected")
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- LIBRARY LOADER
-- Synchronous. Returns the library table or nil.
-- No task.wait() inside - either the HttpGet resolves or it fails.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local MIRRORS = {
    "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
}

local function LoadLibraryFromURL(url)
    Logger.log("  Fetching: " .. url)

    local httpOk, raw = pcall(function() return game:HttpGet(url) end)
    if not httpOk then
        Logger.fail("HttpGet failed", tostring(raw)); return nil
    end
    if type(raw) ~= "string" or #raw < 200 then
        Logger.fail("Response too short", #raw .. " bytes"); return nil
    end
    local trimmed = raw:match("^%s*(.-)%s*$") or raw
    if trimmed:sub(1,1) == "<" then
        Logger.fail("Got HTML (404 or redirect)"); return nil
    end

    local compileOk, chunk = pcall(loadstring, raw)
    if not compileOk or type(chunk) ~= "function" then
        Logger.fail("loadstring failed", tostring(chunk)); return nil
    end

    local execOk, lib = pcall(chunk)
    if not execOk then
        Logger.fail("Library execution failed", tostring(lib)); return nil
    end
    if type(lib) ~= "table" then
        Logger.fail("Library returned " .. type(lib) .. " (expected table)"); return nil
    end

    return lib
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ORION SHIM
-- Wraps Orion in the exact same API surface as real WindUI so
-- the rest of the script never needs to branch on which lib loaded.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local function BuildOrionShim(OrionLib, orionWin)
    -- The shim exposes: CreateWindow, Tab, Notify
    -- Each Tab() call returns an object with the WindUI method names
    -- already on it, so UIAdapter.ProbeTab will find them directly.

    local function makeTabShim(orionTab)
        local shim = {}

        function shim:Section(c)
            pcall(function()
                orionTab:AddSection({ Name = (c and c.Title) or "" })
            end)
        end
        function shim:Toggle(c)
            pcall(function()
                orionTab:AddToggle({
                    Name     = (c and c.Title)   or "",
                    Default  = (c and c.Default) or false,
                    Callback = (c and c.Callback) or function() end,
                })
            end)
        end
        function shim:Button(c)
            pcall(function()
                orionTab:AddButton({
                    Name     = (c and c.Title)    or "",
                    Callback = (c and c.Callback) or function() end,
                })
            end)
        end
        function shim:Slider(c)
            pcall(function()
                local v = (c and c.Value) or {}
                orionTab:AddSlider({
                    Name      = (c and c.Title)    or "",
                    Min       = v.Min     or 0,
                    Max       = v.Max     or 100,
                    Default   = v.Default or 50,
                    Color     = Color3.fromRGB(255,255,255),
                    Increment = (c and c.Step)     or 1,
                    Callback  = (c and c.Callback) or function() end,
                })
            end)
        end
        function shim:Input(c)
            pcall(function()
                orionTab:AddTextbox({
                    Name          = (c and c.Title)    or "",
                    Default       = (c and c.Value)    or "",
                    TextDisappear = true,
                    Callback      = (c and c.Callback) or function() end,
                })
            end)
        end
        function shim:Paragraph(c)
            pcall(function()
                orionTab:AddParagraph(
                    (c and c.Title) or "",
                    (c and c.Desc)  or ""
                )
            end)
            return { SetDesc = function() end }
        end
        function shim:Dropdown(c)
            pcall(function()
                orionTab:AddDropdown({
                    Name     = (c and c.Title)    or "",
                    Default  = (c and c.Value)    or "",
                    Options  = (c and c.Values)   or {},
                    Callback = (c and c.Callback) or function() end,
                })
            end)
        end
        function shim:Keybind(c)
            pcall(function()
                local ks = (c and c.Value) or "RightShift"
                local kc = Enum.KeyCode[ks] or Enum.KeyCode.RightShift
                orionTab:AddBind({
                    Name     = (c and c.Title)    or "",
                    Default  = kc,
                    Hold     = false,
                    Callback = (c and c.Callback) or function() end,
                })
            end)
        end

        return shim
    end

    local libShim = {}

    function libShim:CreateWindow(_cfg)
        -- Window already created; return self so Window = lib:CreateWindow(...)
        -- then Window:Tab(...) works
        return self
    end

    function libShim:Tab(cfg)
        local title = (cfg and cfg.Title) or "Tab"
        local ok, orionTab = pcall(function()
            return orionWin:MakeTab({
                Name        = title,
                Icon        = "rbxassetid://4483345998",
                PremiumOnly = false,
            })
        end)
        if not ok or not orionTab then
            Logger.fail("Orion MakeTab failed for '" .. title .. "'", tostring(orionTab))
            return nil
        end
        return makeTabShim(orionTab)
    end

    function libShim:Notify(cfg)
        pcall(function()
            OrionLib:MakeNotification({
                Name    = (cfg and cfg.Title)    or "",
                Content = (cfg and cfg.Content)  or "",
                Time    = (cfg and cfg.Duration) or 4,
            })
        end)
    end

    function libShim:Toggle()  end
    function libShim:Destroy()
        pcall(function() OrionLib:Destroy() end)
    end

    return libShim
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Boot.Initialize()
-- The single entry point for the entire initialization sequence.
-- Runs synchronously from start to finish.
-- No task.wait() anywhere inside the UI build path.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
function Boot.Initialize()
    Boot.SetState(Boot.States.NOT_STARTED)

    ----------------------------------------------------------------
    -- PHASE 1: Load library
    ----------------------------------------------------------------
    Boot.SetState(Boot.States.LOADING_LIBRARY)

    local lib = nil

    for _, url in ipairs(MIRRORS) do
        lib = LoadLibraryFromURL(url)
        if lib then
            Logger.log("Library Loaded: WindUI from " .. url)
            break
        end
    end

    if not lib then
        Logger.log("All WindUI mirrors failed - trying Orion fallback")
        local orionOk, OrionLib = pcall(function()
            return loadstring(game:HttpGet(
                "https://raw.githubusercontent.com/shlexware/Orion/main/source"
            ))()
        end)

        if orionOk and type(OrionLib) == "table" then
            Logger.log("Library Loaded: Orion fallback")

            local orionWin = OrionLib:MakeWindow({
                Name            = HUB.Name .. " v" .. HUB.Version,
                HidePremium     = false,
                SaveConfig      = false,
                ConfigFolder    = HUB.Folder,
                IntroEnabled    = false,
            })

            lib = BuildOrionShim(OrionLib, orionWin)

            -- For Orion shim, the method map is pre-known because
            -- the shim uses exactly the WindUI method names.
            UIAdapter._methodMap = {
                Section   = "Section",
                Toggle    = "Toggle",
                Button    = "Button",
                Slider    = "Slider",
                Input     = "Input",
                Paragraph = "Paragraph",
                Dropdown  = "Dropdown",
                Keybind   = "Keybind",
            }
            Logger.log("Orion shim method map pre-populated")
        else
            Boot.Fail("No UI library could be loaded", tostring(OrionLib))
            return
        end
    end

    UIAdapter._lib = lib

    ----------------------------------------------------------------
    -- PHASE 2: Discover CreateWindow method, create Window
    ----------------------------------------------------------------
    Boot.SetState(Boot.States.CREATING_WINDOW)

    -- Find the actual CreateWindow method name
    local createFn = UIAdapter.ProbeLibrary(lib)
    if not createFn then
        Boot.Fail("Cannot find CreateWindow on library")
        return
    end

    Logger.log("Calling lib." .. createFn .. "()...")

    local Window = nil
    local winOk, winErr = pcall(function()
        Window = lib[createFn](lib, {
            Title        = HUB.Name,
            Icon         = "skull",
            Author       = "by " .. HUB.Author .. "  •  " .. HUB.Game,
            Folder       = HUB.Folder,
            Size         = UDim2.fromOffset(580, 480),
            Transparent  = true,
            Theme        = "Dark",
            SideBarWidth = 160,
            HasOutline   = true,
            KeySystem    = false,
        })
    end)

    if not winOk then
        Boot.Fail("CreateWindow threw", tostring(winErr))
        return
    end

    -- Validate the window object
    if not ValidateObject(Window, "Window", nil) then
        Boot.Fail("Window object is invalid after creation")
        return
    end

    Logger.log("Window Created")
    UIAdapter._window = Window

    ----------------------------------------------------------------
    -- PHASE 3: Discover Tab creation method on the Window
    ----------------------------------------------------------------
    local tabFn = UIAdapter.ProbeWindow(Window)
    if not tabFn then
        Boot.Fail("Window has no Tab creation method - UI cannot continue")
        return
    end

    UIAdapter._tabFn = tabFn

    ----------------------------------------------------------------
    -- PHASE 4: Create Tabs + probe element API from first tab
    ----------------------------------------------------------------
    Boot.SetState(Boot.States.CREATING_TABS)

    local TAB_NAMES = {
        "Main", "Awareness", "ESP",
        "Movement", "Visuals", "Misc", "Settings"
    }

    local Tabs = {}

    for _, name in ipairs(TAB_NAMES) do
        local tabOk, tabResult = pcall(function()
            return Window[tabFn](Window, { Title = name })
        end)

        if not tabOk then
            Logger.fail("Tab[" .. name .. "] threw", tostring(tabResult))
            -- Continue - skip this tab but keep building others
        elseif not ValidateObject(tabResult, "Tab[" .. name .. "]", nil) then
            Logger.fail("Tab[" .. name .. "] returned invalid object")
            -- Continue
        else
            Tabs[name] = tabResult
            Logger.log("Tab Created: " .. name)

            -- Probe element API once from the first valid tab
            -- (only if not already populated - Orion shim pre-populates it)
            if not next(UIAdapter._methodMap) then
                UIAdapter._methodMap = UIAdapter.ProbeTab(tabResult, name)
                if not UIAdapter._methodMap or not next(UIAdapter._methodMap) then
                    Boot.Fail("Tab API probe returned empty map from Tab[" .. name .. "]")
                    return
                end
                Logger.log("Element method map established from Tab[" .. name .. "]")
            end
        end
    end

    -- Require at least one tab to have been created
    local tabCount = 0
    for _ in pairs(Tabs) do tabCount = tabCount + 1 end
    Logger.log("Tabs created: " .. tabCount .. "/" .. #TAB_NAMES)

    if tabCount == 0 then
        Boot.Fail("Zero tabs were created - cannot build controls")
        return
    end

    ----------------------------------------------------------------
    -- PHASE 5: Create controls
    -- Everything from here is synchronous.
    -- NO task.wait(), NO coroutine yields.
    -- Each element is guarded individually so one failure
    -- does not abort the rest.
    ----------------------------------------------------------------
    Boot.SetState(Boot.States.CREATING_CONTROLS)

    -- ── MAIN ─────────────────────────────────────────────────────
    if Tabs.Main then
        local T = Tabs.Main

        Sec(T, "Welcome")

        Par(T, {
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Script hub for " .. HUB.Game .. "\nAuthor: " .. HUB.Author,
        }, "Main_Info")

        local killerList = {}
        for k in pairs(KNOWN_KILLERS) do
            killerList[#killerList+1] = k:gsub("^%l", string.upper)
        end
        Par(T, {
            Title = "Detected Killers",
            Desc  = #killerList > 0
                and table.concat(killerList, ", ")
                or  "None found",
        }, "Main_Killers")

        Sec(T, "Keybinds")
        Par(T, {
            Title = "Default Keybinds",
            Desc  = "RightShift → Toggle UI\nEnd → Panic / Clear ESP",
        }, "Main_Keys")
    end

    -- ── AWARENESS ────────────────────────────────────────────────
    if Tabs.Awareness then
        local T = Tabs.Awareness

        Sec(T, "Killer Alerts")
        Tog(T, {
            Title="Chase Music Alert", Desc="Notify when chase starts",
            Default=true,
            Callback=function(v) State.ChaseAlert=v end
        }, "Aw_Chase")
        Tog(T, {
            Title="Attack Alert", Desc="Notify on lunge/scourge",
            Default=true,
            Callback=function(v) State.AttackAlert=v end
        }, "Aw_Attack")

        Sec(T, "Skill Check Alerts")
        Tog(T, {
            Title="Generator Skill Check", Desc="Notify on gen checks",
            Default=true,
            Callback=function(v) State.SkillCheckNotify=v end
        }, "Aw_GenSC")
        Tog(T, {
            Title="Heal Skill Check", Desc="Notify on heal checks",
            Default=true,
            Callback=function(v) State.HealSkillNotify=v end
        }, "Aw_HealSC")

        Sec(T, "Objective Alerts")
        Tog(T,{Title="Generator Done",   Desc="",Default=true,Callback=function(v) State.GenDoneNotify=v  end},"Aw_GenDone")
        Tog(T,{Title="All Gens Done",    Desc="",Default=true,Callback=function(v) State.AllGensNotify=v  end},"Aw_AllGens")
        Tog(T,{Title="Hook Notify",      Desc="",Default=true,Callback=function(v) State.HookNotify=v     end},"Aw_Hook")
        Tog(T,{Title="Death Notify",     Desc="",Default=true,Callback=function(v) State.DeathNotify=v    end},"Aw_Death")
        Tog(T,{Title="Last Survivor",    Desc="",Default=true,Callback=function(v) State.OneLeftNotify=v  end},"Aw_Last")
    end

    -- ── ESP ──────────────────────────────────────────────────────
    if Tabs.ESP then
        local T = Tabs.ESP

        Sec(T, "Player ESP")
        Tog(T, {
            Title="Killer ESP", Desc="Red highlight", Default=false,
            Callback=function(v)
                State.ESP_Killer=v
                if not v then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p.Character and Role.IsKiller(p.Character) then
                            ESP.Clear(p.Character)
                        end
                    end
                end
            end
        }, "ESP_Killer")
        Tog(T, {
            Title="Survivor ESP", Desc="Cyan highlight", Default=false,
            Callback=function(v)
                State.ESP_Survivors=v
                if not v then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p.Character and not Role.IsKiller(p.Character) then
                            ESP.Clear(p.Character)
                        end
                    end
                end
            end
        }, "ESP_Survivor")

        Sec(T, "Object ESP")
        Tog(T,{Title="Generator ESP",Desc="Yellow",Default=false,
            Callback=function(v)
                State.ESP_Generators=v
                if not v and WS.Generators then
                    for _,g in ipairs(WS.Generators:GetChildren()) do ESP.Clear(g) end
                end
            end},"ESP_Gen")
        Tog(T,{Title="Item ESP",   Desc="Green",Default=false,Callback=function(v) State.ESP_Items=v   end},"ESP_Item")
        Tog(T,{Title="Weapon ESP", Desc="Pink", Default=false,
            Callback=function(v)
                State.ESP_Weapons=v
                if not v and WS.Weapons then
                    for _,w in ipairs(WS.Weapons:GetChildren()) do ESP.Clear(w) end
                end
            end},"ESP_Weapon")
        Tog(T,{Title="Clone ESP",  Desc="Gray", Default=false,
            Callback=function(v)
                State.ESP_Clones=v
                if not v and WS.Clones then
                    for _,c in ipairs(WS.Clones:GetChildren()) do ESP.Clear(c) end
                end
            end},"ESP_Clone")

        Sec(T, "Display")
        Tog(T,{Title="Show Names",    Desc="",Default=true,
            Callback=function(v)
                State.ESP_ShowName=v
                for _,c in pairs(State.ESPCache) do if c.nl then c.nl.Visible=v end end
            end},"ESP_Names")
        Tog(T,{Title="Show Distance", Desc="",Default=true,
            Callback=function(v)
                State.ESP_ShowDistance=v
                for _,c in pairs(State.ESPCache) do if c.dl then c.dl.Visible=v end end
            end},"ESP_Dist")
        Sld(T,{Title="Max Distance",Desc="Render range",
            Value={Min=50,Max=2000,Default=500},Step=50,
            Callback=function(v)
                State.ESP_MaxDistance=tonumber(v) or 500
                for _,c in pairs(State.ESPCache) do
                    if c.bb then c.bb.MaxDistance=State.ESP_MaxDistance end
                end
            end},"ESP_MaxDist")

        Sec(T, "Actions")
        Btn(T,{Title="Refresh ESP",Desc="Re-scan all entities",
            Callback=function() ESP.ClearAll(); ESP.RefreshAll(); Util.Notify("ESP","Refreshed",2) end},"ESP_Refresh")
        Btn(T,{Title="Clear All ESP",Desc="Remove all highlights",
            Callback=function() ESP.ClearAll(); Util.Notify("ESP","Cleared",2) end},"ESP_Clear")
    end

    -- ── MOVEMENT ─────────────────────────────────────────────────
    if Tabs.Movement then
        local T = Tabs.Movement

        Sec(T, "Speed")
        Sld(T,{Title="Walk Speed",Desc="Default: 16",
            Value={Min=16,Max=200,Default=16},Step=1,
            Callback=function(v) State.WalkSpeed=tonumber(v) or 16; Move.Speed() end},"Mv_Speed")
        Sld(T,{Title="Jump Power",Desc="Default: 50",
            Value={Min=50,Max=300,Default=50},Step=5,
            Callback=function(v) State.JumpPower=tonumber(v) or 50; Move.Jump() end},"Mv_Jump")

        Sec(T, "Advanced")
        Tog(T,{Title="NoClip",      Desc="Walk through walls",Default=false,
            Callback=function(v) State.NoClip=v;  Move.SetNoClip(v)  end},"Mv_NoClip")
        Tog(T,{Title="Infinite Jump",Desc="Jump while airborne",Default=false,
            Callback=function(v) State.InfJump=v; Move.SetInfJump(v) end},"Mv_InfJump")

        Sec(T, "Teleport")
        Btn(T,{Title="TP Nearest Generator",Desc="Teleport to closest gen",
            Callback=Move.NearestGen},"Mv_TPGen")
        Inp(T,{Title="Player Name",Desc="Case-sensitive",Value="",Placeholder="Enter name",
            Callback=function(v) tpTargetName=tostring(v or "") end},"Mv_Input")
        Btn(T,{Title="TP to Player",Desc="Teleport to entered player",
            Callback=Move.ToPlayer},"Mv_TPPlayer")
    end

    -- ── VISUALS ──────────────────────────────────────────────────
    if Tabs.Visuals then
        local T = Tabs.Visuals

        Sec(T, "Lighting")
        Tog(T,{Title="FullBright",    Desc="Remove all darkness",Default=false,
            Callback=function(v) State.FullBright=v;   Vis.FullBright(v)  end},"Vis_FB")
        Tog(T,{Title="No Fog",        Desc="Remove map fog",    Default=false,
            Callback=function(v) State.NoFog=v;         Vis.NoFog(v)       end},"Vis_Fog")
        Tog(T,{Title="No Shadows",    Desc="Disable shadows",   Default=false,
            Callback=function(v) State.NoShadows=v;    Vis.NoShadows(v)   end},"Vis_Shad")
        Tog(T,{Title="Clear Weather", Desc="Remove atmosphere", Default=false,
            Callback=function(v) State.ClearWeather=v; Vis.ClearWx(v)     end},"Vis_Wx")
        Sld(T,{Title="Time of Day",Desc="0=Night  14=Day",
            Value={Min=0,Max=24,Default=14},Step=1,
            Callback=function(v) State.ClockTime=tonumber(v) or 14; Vis.SetClock(State.ClockTime) end},"Vis_Time")

        Sec(T, "Camera")
        Sld(T,{Title="Field of View",Desc="Default: 70",
            Value={Min=30,Max=120,Default=70},Step=5,
            Callback=function(v) State.FOV=tonumber(v) or 70; Vis.SetFOV(State.FOV) end},"Vis_FOV")
        Tog(T,{Title="Freecam",Desc="WASD / Space / Ctrl",Default=false,
            Callback=function(v) State.Freecam=v; Vis.Freecam(v) end},"Vis_Cam")

        Sec(T, "Post-Processing")
        Tog(T,{Title="Remove Blur/Bloom",      Desc="",Default=false,
            Callback=function(v) State.RemoveBlur=v; Vis.PostFX(v)    end},"Vis_Blur")
        Tog(T,{Title="Remove Color Correction", Desc="",Default=false,
            Callback=function(v) State.RemoveCC=v;   Vis.ColorCorr(v) end},"Vis_CC")
        Tog(T,{Title="No Particles",            Desc="",Default=false,
            Callback=function(v) State.NoParticles=v; Vis.Particles(v) end},"Vis_Part")

        Sec(T, "Performance")
        Tog(T,{Title="Low Graphics",Desc="Quality Level 1",Default=false,
            Callback=function(v) State.LowGraphics=v; Vis.LowGfx(v) end},"Vis_Gfx")
    end

    -- ── MISC ─────────────────────────────────────────────────────
    if Tabs.Misc then
        local T = Tabs.Misc

        Sec(T, "Audio")
        Tog(T,{Title="Mute All Sounds",      Desc="",Default=false,
            Callback=function(v) State.NoSound=v;     Vis.MuteAll(v) end},"Misc_Mute")
        Tog(T,{Title="Mute Background Music",Desc="",Default=false,
            Callback=function(v) State.MuteBGMusic=v; Vis.MuteBG(v)  end},"Misc_MuteBG")

        Sec(T, "Character")
        Tog(T,{Title="Hide Own Name",Desc="Hide your nametag",Default=false,
            Callback=function(v) State.HideName=v; Vis.HideName(v) end},"Misc_Name")

        Sec(T, "Utility")
        Tog(T,{Title="Auto Rejoin",Desc="Rejoin on kick",Default=false,
            Callback=function(v) State.AutoRejoin=v end},"Misc_AR")
        Btn(T,{Title="Server Hop",Desc="Join a different server",
            Callback=Vis.ServerHop},"Misc_SHop")
        Btn(T,{Title="Copy JobId",Desc="Copy server ID to clipboard",
            Callback=function()
                if setclipboard then
                    setclipboard(tostring(game.JobId))
                    Util.Notify("Copied","JobId copied!",3)
                else
                    Util.Notify("Error","Clipboard not supported.",3)
                end
            end},"Misc_Copy")
        Btn(T,{Title="Rejoin",Desc="Teleport back to this game",
            Callback=function()
                pcall(function()
                    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
                end)
            end},"Misc_Rejoin")
    end

    -- ── SETTINGS ─────────────────────────────────────────────────
    if Tabs.Settings then
        local T = Tabs.Settings

        Sec(T, "Anti-AFK")
        Tog(T,{Title="Anti-AFK",Desc="Prevent idle disconnect",Default=true,
            Callback=function(v) State.AntiAFK=v end},"Set_AFK")

        Sec(T, "Keybinds")
        Kbnd(T,{Title="Toggle UI",         Desc="Show/hide window",Value="RightShift",
            Callback=function() pcall(function() Window:Toggle() end) end},"Set_KB1")
        Kbnd(T,{Title="Panic — Clear ESP", Desc="Disable all ESP", Value="End",
            Callback=function()
                State.ESP_Killer=false; State.ESP_Survivors=false
                State.ESP_Generators=false; State.ESP_Items=false
                State.ESP_Weapons=false;    State.ESP_Clones=false
                ESP.ClearAll()
                Util.Notify("Panic","All ESP cleared!",3)
            end},"Set_KB2")

        Sec(T, "Credits")
        Par(T, {
            Title = HUB.Name .. " v" .. HUB.Version,
            Desc  = "Author: "    .. HUB.Author
                 .. "\nGame: "    .. HUB.Game
                 .. "\nExecutors: Xeno, Medium, Delta, Solara, Wave",
        }, "Set_Credits")

        Sec(T, "Danger Zone")
        Btn(T,{Title="Unload Hub",Desc="Remove hub and restore settings",
            Callback=function()
                -- Stop toggle-based connections first
                if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
                if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
                if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
                -- Disconnect all managed connections
                ConnectionManager:Cleanup()
                -- Restore visuals
                Vis.RestoreLight()
                pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
                pcall(function() Camera.FieldOfView = 70 end)
                -- Clear ESP
                ESP.ClearAll()
                -- Clear instance
                _G[INSTANCE_KEY] = nil
                -- Destroy window
                pcall(function() Window:Destroy() end)
                Logger.log("Hub unloaded cleanly")
            end},"Set_Unload")
    end

    ----------------------------------------------------------------
    -- PHASE 6: Post-build setup
    ----------------------------------------------------------------
    SetupAwareness()

    ConnectionManager:Add(
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            pcall(Move.Speed)
            pcall(Move.Jump)
            if State.NoClip     then pcall(Move.SetNoClip,  true) end
            if State.InfJump    then pcall(Move.SetInfJump, true) end
            if State.FullBright then pcall(Vis.FullBright,  true) end
            if State.NoFog      then pcall(Vis.NoFog,       true) end
            if State.HideName   then pcall(Vis.HideName,    true) end
            if State.FOV ~= 70  then pcall(Vis.SetFOV, State.FOV) end
        end),
        "CharacterAdded"
    )

    ConnectionManager:Add(
        LocalPlayer.OnTeleport:Connect(function(ts)
            if State.AutoRejoin and ts == Enum.TeleportState.Failed then
                task.wait(3)
                pcall(function()
                    game:GetService("TeleportService"):Teleport(
                        game.PlaceId, LocalPlayer
                    )
                end)
            end
        end),
        "OnTeleport"
    )

    task.spawn(function()
        while task.wait(5) do
            if State.FullBright   then pcall(Vis.FullBright, true) end
            if State.NoFog        then pcall(Vis.NoFog,      true) end
            if State.NoShadows    then pcall(Vis.NoShadows,  true) end
            if State.ClearWeather then pcall(Vis.ClearWx,    true) end
        end
    end)

    ----------------------------------------------------------------
    -- PHASE 7: Show window + flush pending notifications
    ----------------------------------------------------------------
    Boot.SetState(Boot.States.READY)

    pcall(function()
        if Window.SelectTab then Window:SelectTab(1) end
    end)

    -- Register destroy function for the instance manager
    RegisterInstance(Window, function()
        ConnectionManager:Cleanup()
        if State.NoClipConn  then pcall(function() State.NoClipConn:Disconnect()  end) end
        if State.InfJumpConn then pcall(function() State.InfJumpConn:Disconnect() end) end
        if State.FreecamConn then pcall(function() State.FreecamConn:Disconnect() end) end
        Vis.RestoreLight()
        pcall(function() Camera.CameraType  = Enum.CameraType.Custom end)
        pcall(function() Camera.FieldOfView = 70 end)
        ESP.ClearAll()
        pcall(function() Window:Destroy() end)
    end)

    _uiReady = true
    FlushNotifies()

    Util.Notify(HUB.Name, "Loaded v" .. HUB.Version, 5)
    Logger.log("Initialization Complete - v" .. HUB.Version)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ENTRY POINT
-- Boot.Initialize() runs entirely synchronously.
-- It is NOT wrapped in task.spawn() so there is no scheduler
-- preemption during the UI build.
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Boot.Initialize()
