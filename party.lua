--═══════════════════════════════════════════════════════════════
-- X0DEC04T Cidro Janji Hub v1.2.0 - ANTI-DETECTION
-- FIX for Error 267: namecallInstance detector
-- Removed all metatable hooks. Rate-limited. Human-like delays.
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local INSTANCE_KEY = "__X0DEC04T_CIDRO_v120_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _logStart = os.clock()
local SILENT = false  -- set true to disable ALL prints
local function Log(msg)
    if SILENT then return end
    print(string.format("[X0][+%.1fs] %s", os.clock()-_logStart, tostring(msg)))
end

Log("v1.2.0 loading (anti-detection mode)")

-- ═══════════════════════════════════════════
-- IMPORTANT: 3-second cooldown before anything fires
-- Prevents rapid-load detection
-- ═══════════════════════════════════════════
local READY = false
task.spawn(function()
    task.wait(3)
    READY = true
    Log("Ready state active — actions now permitted")
end)

-- Load Rayfield
local Rayfield = nil
for _, url in ipairs({
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source"
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then Rayfield = r; break end
end
if not Rayfield then warn("Rayfield failed"); return end

local HUB = {
    Name="X0DEC04T Cidro Hub", Game="Cidro Janji",
    Version="1.2.0-safe", Author="voixera", PlaceId=112171352246014,
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

-- REMOTES
local Remotes      = ReplicatedStorage:FindFirstChild("Remotes")
local Gamepass     = ReplicatedStorage:FindFirstChild("Gamepass")
local RoleManager  = ReplicatedStorage:FindFirstChild("RoleManager")
local Events       = ReplicatedStorage:FindFirstChild("Events")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")

local R = {
    AdminInput      = Remotes and Remotes:FindFirstChild("AdminInputEvent"),
    AdminCommand    = Remotes and Remotes:FindFirstChild("AdminCommand"),
    AdminGlobal     = Remotes and Remotes:FindFirstChild("AdminGlobalInputEvent"),
    AdminNotify     = Remotes and Remotes:FindFirstChild("AdminNotify"),
    GiftVIP         = Gamepass and Gamepass:FindFirstChild("AdminGiftVIP"),
    IsAdmin         = Gamepass and Gamepass:FindFirstChild("IsAdmin"),
    AddWhitelist    = RoleManager and RoleManager:FindFirstChild("AddWhitelist"),
    ClientPlayDance = Events and Events:FindFirstChild("ClientPlayDance"),
    RemoveTitle     = RemoteEvents and RemoteEvents:FindFirstChild("RemoveTitle"),
}

Log("Remotes mapped: AdminInput=" .. (R.AdminInput and "Y" or "N")
    .. " AdminCommand=" .. (R.AdminCommand and "Y" or "N"))

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    AutoKickAll=false,
    KickInterval=2,             -- default 2s per kick (safe)
    KickExceptMe=true,
    KickExceptFriends=false,
    KickWhitelist={},

    LoopRespawn=false,
    LoopRespawnTarget="",
    LoopRespawnInterval=3,      -- default 3s (safe)

    -- Payload discovery
    WorkingKickPayload=nil,     -- index of format that worked
    WorkingKillPayload=nil,
    DiscoveryMode=false,

    -- Rate limit
    LastFireTime=0,
    FireCooldown=0.4,           -- min 0.4s between ANY remote fires

    -- Utility
    AntiAFK=true, AutoRejoin=false,

    KickAttempts=0,
    KillAttempts=0,

    KickLoopThread=nil,
    RespawnLoopThread=nil,
}

-- ═══════════════════════════════════════════
-- SAFE FIRE — Rate limited, single-payload, jittered
-- ═══════════════════════════════════════════

-- Human-like jitter: 0.85x to 1.15x of interval
local function Jitter(base)
    return base * (0.85 + math.random() * 0.30)
end

-- Safe fire — ONE remote, ONE payload, respect cooldown
local function SafeFire(remote, ...)
    if not remote then return false end
    if not READY then return false end

    local now = tick()
    local wait_needed = State.FireCooldown - (now - State.LastFireTime)
    if wait_needed > 0 then
        task.wait(wait_needed)
    end
    State.LastFireTime = tick()

    local args = table.pack(...)
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    return ok
end

-- ═══════════════════════════════════════════
-- PAYLOAD FORMATS (single format per index)
-- Try one at a time to discover working one
-- ═══════════════════════════════════════════
local KICK_FORMATS = {
    function(name, plr) return {":kick " .. name} end,
    function(name, plr) return {"kick", name} end,
    function(name, plr) return {"kick", plr} end,
    function(name, plr) return {":kick", name} end,
    function(name, plr) return {"Kick", plr} end,
    function(name, plr) return {"Kick", name} end,
    function(name, plr) return {":k " .. name} end,
    function(name, plr) return {":ban " .. name} end,
    function(name, plr) return {"ban", plr} end,
    function(name, plr) return {{cmd="kick", target=name}} end,
    function(name, plr) return {{Command="kick", Target=name}} end,
    function(name, plr) return {":kick " .. name .. " byebye"} end,
    function(name, plr) return {"kick", name, "byebye"} end,
    function(name, plr) return {":crash " .. name} end,
}

local KILL_FORMATS = {
    function(name, plr) return {":kill " .. name} end,
    function(name, plr) return {"kill", name} end,
    function(name, plr) return {"kill", plr} end,
    function(name, plr) return {":kill", name} end,
    function(name, plr) return {"Kill", plr} end,
    function(name, plr) return {":respawn " .. name} end,
    function(name, plr) return {"respawn", plr} end,
    function(name, plr) return {":refresh " .. name} end,
    function(name, plr) return {":sethp " .. name .. " 0"} end,
    function(name, plr) return {"sethealth", plr, 0} end,
    function(name, plr) return {"damage", plr, 999} end,
    function(name, plr) return {{cmd="kill", target=name}} end,
}

local ADMIN_REMOTES = { R.AdminInput, R.AdminCommand, R.AdminGlobal }

-- Fire single format via preferred remote
local function TryKickPayload(plr, formatIdx)
    if not plr then return false end
    local fmt = KICK_FORMATS[formatIdx]
    if not fmt then return false end
    local payload = fmt(plr.Name, plr)
    for _, remote in ipairs(ADMIN_REMOTES) do
        if remote then
            local ok = SafeFire(remote, table.unpack(payload))
            if ok then State.KickAttempts = State.KickAttempts + 1 end
        end
    end
    return true
end

local function TryKillPayload(plr, formatIdx)
    if not plr then return false end
    local fmt = KILL_FORMATS[formatIdx]
    if not fmt then return false end
    local payload = fmt(plr.Name, plr)
    for _, remote in ipairs(ADMIN_REMOTES) do
        if remote then
            local ok = SafeFire(remote, table.unpack(payload))
            if ok then State.KillAttempts = State.KillAttempts + 1 end
        end
    end
    return true
end

-- Cycle through formats (if working one not known, cycle each attempt)
local function KickPlayerSafe(plr)
    if not plr then return end
    local idx
    if State.WorkingKickPayload then
        idx = State.WorkingKickPayload
    else
        idx = ((State.KickAttempts) % #KICK_FORMATS) + 1
    end
    TryKickPayload(plr, idx)
end

local function KillPlayerSafe(plr)
    if not plr then return end
    local idx
    if State.WorkingKillPayload then
        idx = State.WorkingKillPayload
    else
        idx = ((State.KillAttempts) % #KILL_FORMATS) + 1
    end
    TryKillPayload(plr, idx)
end

-- Skip filter
local function IsInList(list, name)
    for _, n in ipairs(list) do
        if n:lower() == name:lower() then return true end
    end
    return false
end

local function ShouldSkip(plr)
    if not plr or not plr.Parent then return true end
    if State.KickExceptMe and plr == LocalPlayer then return true end
    if IsInList(State.KickWhitelist, plr.Name) then return true end
    if State.KickExceptFriends then
        local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
        if ok and isFriend then return true end
    end
    return false
end

-- ═══════════════════════════════════════════
-- AUTO KICK LOOP (safe, jittered)
-- ═══════════════════════════════════════════
local function StartKickLoop()
    if State.KickLoopThread then return end
    State.KickLoopThread = task.spawn(function()
        while State.AutoKickAll do
            -- Shuffle player list for randomness
            local list = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if not ShouldSkip(p) then table.insert(list, p) end
            end
            for i = #list, 2, -1 do
                local j = math.random(i)
                list[i], list[j] = list[j], list[i]
            end

            for _, plr in ipairs(list) do
                if not State.AutoKickAll then break end
                KickPlayerSafe(plr)
                task.wait(Jitter(State.KickInterval))
            end
            task.wait(Jitter(1))
        end
        State.KickLoopThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- LOOP RESPAWN
-- ═══════════════════════════════════════════
local function StartRespawnLoop()
    if State.RespawnLoopThread then return end
    State.RespawnLoopThread = task.spawn(function()
        while State.LoopRespawn do
            local target = Players:FindFirstChild(State.LoopRespawnTarget)
            if target then
                KillPlayerSafe(target)
            end
            task.wait(Jitter(State.LoopRespawnInterval))
        end
        State.RespawnLoopThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- PAYLOAD DISCOVERY
-- Fire one format, wait, check if anything happened
-- ═══════════════════════════════════════════
local function DiscoverKickPayload(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then
        Rayfield:Notify({Title="Discovery", Content="Target not found", Duration=3})
        return
    end
    Rayfield:Notify({Title="Discovery", Content="Testing kick formats on " .. targetName, Duration=5})
    task.spawn(function()
        for i = 1, #KICK_FORMATS do
            if not target or not target.Parent then
                State.WorkingKickPayload = i - 1
                Log("Discovery: format #" .. (i-1) .. " kicked " .. targetName)
                Rayfield:Notify({Title="Discovery", Content="FOUND: format #" .. (i-1), Duration=8})
                return
            end
            Log("Trying kick format #" .. i)
            TryKickPayload(target, i)
            task.wait(3)  -- give server time to react + rate limit
        end
        Rayfield:Notify({Title="Discovery", Content="No format worked", Duration=5})
    end)
end

local function DiscoverKillPayload(targetName)
    local target = Players:FindFirstChild(targetName)
    if not target then return end
    Rayfield:Notify({Title="Discovery", Content="Testing kill formats", Duration=5})
    task.spawn(function()
        for i = 1, #KILL_FORMATS do
            if not target or not target.Character then task.wait(1) end
            local ch = target.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local hpBefore = hum and hum.Health or 100

            TryKillPayload(target, i)
            task.wait(2.5)

            if not target.Character or (target.Character:FindFirstChildOfClass("Humanoid")
               and target.Character:FindFirstChildOfClass("Humanoid").Health < hpBefore) then
                State.WorkingKillPayload = i
                Log("Discovery: kill format #" .. i .. " worked")
                Rayfield:Notify({Title="Discovery", Content="FOUND kill format #" .. i, Duration=8})
                return
            end
        end
        Rayfield:Notify({Title="Discovery", Content="No kill format worked", Duration=5})
    end)
end

-- ═══════════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════════
CM:Add(LocalPlayer.Idled, function()
    if State.AntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

CM:Add(LocalPlayer.OnTeleport, function(ts)
    if State.AutoRejoin and ts == Enum.TeleportState.Failed then
        task.wait(3)
        pcall(function() TeleportService:Teleport(HUB.PlaceId, LocalPlayer) end)
    end
end)

local function ServerHop()
    pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"..tostring(HUB.PlaceId)
            .."/servers/Public?sortOrder=Asc&limit=100")
        local dok, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if dok and data and data.data then
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(HUB.PlaceId, s.id, LocalPlayer)
                    return
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name                   = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle           = HUB.Name,
    LoadingSubtitle        = "Anti-Detection Build",
    Theme                  = "DarkBlue",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",     name="Main",       icon="home"},
    {key="Discovery",name="Discovery",  icon="search"},
    {key="Kick",     name="Auto Kick",  icon="user-x"},
    {key="Respawn",  name="Loop Kill",  icon="skull"},
    {key="Self",     name="Self Perks", icon="crown"},
    {key="Utility",  name="Utility",    icon="wrench"},
    {key="Settings", name="Settings",   icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- MAIN
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("v1.2.0 — Anti-Detection Build")
    T:CreateLabel("Fixes Error 267 (namecall detector)")
    T:CreateLabel("No metatable hooks. Rate limited.")
    T:CreateLabel("Waits 3s before firing any remote")

    T:CreateSection("Remote Status")
    T:CreateLabel("AdminInput: " .. (R.AdminInput and "Found" or "Missing"))
    T:CreateLabel("AdminCommand: " .. (R.AdminCommand and "Found" or "Missing"))
    T:CreateLabel("AdminGlobal: " .. (R.AdminGlobal and "Found" or "Missing"))

    T:CreateSection("READ FIRST")
    T:CreateLabel("1. Go to Discovery tab")
    T:CreateLabel("2. Test kick formats on alt account")
    T:CreateLabel("3. Once found, use Auto Kick tab")
    T:CreateLabel("Never rush — wait for cooldowns")

    T:CreateSection("Panic")
    T:CreateButton({Name="STOP ALL LOOPS", Callback=function()
        State.AutoKickAll=false
        State.LoopRespawn=false
        Rayfield:Notify({Title="Panic", Content="All loops stopped", Duration=3})
    end})
end

-- DISCOVERY TAB — most important
if Tabs.Discovery then
    local T = Tabs.Discovery
    T:CreateSection("Payload Discovery")
    T:CreateLabel("Tests kick/kill formats ONE AT A TIME")
    T:CreateLabel("Uses safe 3s delays. WON'T get detected.")
    T:CreateLabel("Best: use alt account as target")

    local testName = ""
    T:CreateInput({Name="Target Player Name (use alt!)",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) testName = tostring(v or "") end})

    T:CreateButton({Name="Discover Kick Format", Callback=function()
        if testName == "" then
            Rayfield:Notify({Title="Discovery", Content="Enter target name", Duration=3})
            return
        end
        DiscoverKickPayload(testName)
    end})

    T:CreateButton({Name="Discover Kill Format", Callback=function()
        if testName == "" then
            Rayfield:Notify({Title="Discovery", Content="Enter target name", Duration=3})
            return
        end
        DiscoverKillPayload(testName)
    end})

    T:CreateSection("Working Formats Found")
    T:CreateLabel("Kick: (run discovery to find)")
    T:CreateLabel("Kill: (run discovery to find)")

    T:CreateButton({Name="Reset Discovery", Callback=function()
        State.WorkingKickPayload=nil
        State.WorkingKillPayload=nil
    end})

    T:CreateSection("Check My Admin Status")
    T:CreateButton({Name="Check IsAdmin (safe)", Callback=function()
        if R.IsAdmin then
            task.spawn(function()
                task.wait(1)
                local ok, res = pcall(function() return R.IsAdmin:InvokeServer() end)
                local msg = ok and ("Result: " .. tostring(res)) or ("Error")
                Rayfield:Notify({Title="IsAdmin", Content=msg, Duration=5})
                Log(msg)
            end)
        end
    end})
end

-- KICK TAB
if Tabs.Kick then
    local T = Tabs.Kick
    T:CreateSection("Auto Kick All (SAFE MODE)")
    T:CreateLabel("Uses discovered format if available")
    T:CreateLabel("Otherwise cycles formats slowly")
    T:CreateLabel("Interval MUST be >= 1s to avoid detection")

    T:CreateSlider({Name="Interval Per Kick (seconds)",
        Range={1,10}, Increment=1, CurrentValue=2, Flag="KI",
        Callback=function(v) State.KickInterval = tonumber(v) or 2 end})

    T:CreateToggle({Name="Enable Auto Kick All", CurrentValue=false, Flag="AKA",
        Callback=function(v)
            State.AutoKickAll = v
            if v then StartKickLoop() end
        end})

    T:CreateSection("Skip Filters")
    T:CreateToggle({Name="Skip Myself", CurrentValue=true, Flag="KEM",
        Callback=function(v) State.KickExceptMe = v end})
    T:CreateToggle({Name="Skip Friends", CurrentValue=false, Flag="KEF",
        Callback=function(v) State.KickExceptFriends = v end})

    T:CreateInput({Name="Skip Names (comma-separated)",
        PlaceholderText="name1,name2", RemoveTextAfterFocusLost=false,
        Callback=function(v)
            State.KickWhitelist = {}
            for name in string.gmatch(tostring(v or ""), "([^,]+)") do
                table.insert(State.KickWhitelist, name:match("^%s*(.-)%s*$"))
            end
        end})

    T:CreateSection("Single Kick")
    local singleKick = ""
    T:CreateInput({Name="Player Name",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) singleKick = tostring(v or "") end})
    T:CreateButton({Name="Kick This Player (single)", Callback=function()
        local plr = Players:FindFirstChild(singleKick)
        if plr then KickPlayerSafe(plr) end
    end})

    T:CreateSection("Stop")
    T:CreateButton({Name="Stop Kick Loop", Callback=function()
        State.AutoKickAll = false
    end})
end

-- RESPAWN TAB
if Tabs.Respawn then
    local T = Tabs.Respawn
    T:CreateSection("Loop Kill Single Target")

    T:CreateInput({Name="Target Name",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.LoopRespawnTarget = tostring(v or "") end})

    T:CreateSlider({Name="Kill Interval (seconds)",
        Range={1,15}, Increment=1, CurrentValue=3, Flag="LRI",
        Callback=function(v) State.LoopRespawnInterval = tonumber(v) or 3 end})

    T:CreateToggle({Name="Enable Loop Kill", CurrentValue=false, Flag="LR",
        Callback=function(v)
            State.LoopRespawn = v
            if v then
                if State.LoopRespawnTarget == "" then
                    State.LoopRespawn = false
                    Rayfield:Notify({Title="Loop", Content="Set target first", Duration=3})
                    return
                end
                StartRespawnLoop()
            end
        end})

    T:CreateButton({Name="Kill Target Once", Callback=function()
        local t = Players:FindFirstChild(State.LoopRespawnTarget)
        if t then KillPlayerSafe(t) end
    end})

    T:CreateButton({Name="Stop Loop", Callback=function()
        State.LoopRespawn = false
    end})
end

-- SELF PERKS
if Tabs.Self then
    local T = Tabs.Self
    T:CreateSection("Grant Self Perks")

    T:CreateButton({Name="Grant Self VIP (once)", Callback=function()
        if R.GiftVIP then
            SafeFire(R.GiftVIP, LocalPlayer)
        end
    end})

    T:CreateButton({Name="Whitelist Self (once)", Callback=function()
        if R.AddWhitelist then
            SafeFire(R.AddWhitelist, LocalPlayer)
        end
    end})
end

-- UTILITY
if Tabs.Utility then
    local T = Tabs.Utility
    T:CreateSection("Anti-AFK")
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="AAF",
        Callback=function(v) State.AntiAFK = v end})

    T:CreateSection("Server")
    T:CreateButton({Name="Server Hop", Callback=ServerHop})
    T:CreateButton({Name="Rejoin", Callback=function()
        pcall(function() TeleportService:Teleport(HUB.PlaceId, LocalPlayer) end)
    end})
    T:CreateToggle({Name="Auto Rejoin on Kick", CurrentValue=false, Flag="AR",
        Callback=function(v) State.AutoRejoin = v end})

    T:CreateSection("Silent Mode")
    T:CreateToggle({Name="Silent (no prints)", CurrentValue=false, Flag="SM",
        Callback=function(v) SILENT = v end})
end

-- SETTINGS
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("About")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Anti-detection rewrite")
    T:CreateLabel("Never uses hookfunction / metatables")
    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload", Callback=function()
        State.AutoKickAll=false; State.LoopRespawn=false
        CM:Cleanup()
        _G[INSTANCE_KEY]=nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- Panic keybind
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.End then
        State.AutoKickAll=false; State.LoopRespawn=false
        Rayfield:Notify({Title="Panic", Content="Stopped", Duration=2})
    end
end)

_G[INSTANCE_KEY] = {
    version=HUB.Version, timestamp=os.time(),
    destroy=function()
        State.AutoKickAll=false; State.LoopRespawn=false
        CM:Cleanup()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Rayfield:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded (3s cooldown)", Duration=5})
Log("Ready — anti-detection build")
