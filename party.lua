--═══════════════════════════════════════════════════════════════
-- X0DEC04T Cidro Janji Server Hub v1.1.0
-- Place ID: 112171352246014
-- Pure server-side actions. No visuals. No client effects.
-- Fires exposed AdminInputEvent / AdminCommand remotes.
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local HttpService       = game:GetService("HttpService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local TeleportService   = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

local INSTANCE_KEY = "__X0DEC04T_CIDRO_v110_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local _logStart = os.clock()
local function Log(msg) print(string.format("[X0-CIDRO][+%.2fs] %s", os.clock()-_logStart, tostring(msg))) end
local function Err(msg,d) warn(string.format("[X0-CIDRO][+%.2fs] ERROR: %s | %s", os.clock()-_logStart, tostring(msg), tostring(d or ""))) end

Log("Loading v1.1.0 - Cidro Janji server hub")

-- Load Rayfield
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
    Name="X0DEC04T Cidro Hub", Game="Cidro Janji",
    Version="1.1.0", Author="voixera", PlaceId=112171352246014,
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
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local Gamepass = ReplicatedStorage:FindFirstChild("Gamepass")
local RoleManager = ReplicatedStorage:FindFirstChild("RoleManager")
local RoleRemotes = ReplicatedStorage:FindFirstChild("RoleRemotes")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local Events = ReplicatedStorage:FindFirstChild("Events")
local DJRemotes = ReplicatedStorage:FindFirstChild("DJRemotes")

local R = {
    AdminInput       = Remotes and Remotes:FindFirstChild("AdminInputEvent"),
    AdminCommand     = Remotes and Remotes:FindFirstChild("AdminCommand"),
    AdminGlobal      = Remotes and Remotes:FindFirstChild("AdminGlobalInputEvent"),
    AdminNotify      = Remotes and Remotes:FindFirstChild("AdminNotify"),

    GiftVIP          = Gamepass and Gamepass:FindFirstChild("AdminGiftVIP"),
    RevokeVIP        = Gamepass and Gamepass:FindFirstChild("AdminRevokeVIP"),
    IsAdmin          = Gamepass and Gamepass:FindFirstChild("IsAdmin"),

    AddWhitelist     = RoleManager and RoleManager:FindFirstChild("AddWhitelist"),
    RemoveWhitelist  = RoleManager and RoleManager:FindFirstChild("RemoveWhitelist"),
    AddRole          = RoleManager and RoleManager:FindFirstChild("AddRole"),
    RemoveRole       = RoleManager and RoleManager:FindFirstChild("RemoveRole"),
    GetWhitelist     = RoleManager and RoleManager:FindFirstChild("GetWhitelist"),
    GetPlayers       = RoleManager and RoleManager:FindFirstChild("GetPlayers"),

    ReportPlayerInfo = RoleRemotes and RoleRemotes:FindFirstChild("ReportPlayerInfo"),
    GetProfile       = RoleRemotes and RoleRemotes:FindFirstChild("GetProfile"),
    GetPlayerData    = Remotes and Remotes:FindFirstChild("GetPlayerData"),

    RemoveTitle      = RemoteEvents and RemoteEvents:FindFirstChild("RemoveTitle"),
    ReqPlayerTitles  = RemoteEvents and RemoteEvents:FindFirstChild("RequestPlayerTitles"),

    ClientPlayDance  = Events and Events:FindFirstChild("ClientPlayDance"),

    DJPitch          = DJRemotes and DJRemotes:FindFirstChild("RequestSetPitch"),
    DJRemoveFav      = DJRemotes and DJRemotes:FindFirstChild("RequestRemoveFavorite"),
    DJUpdateSkip     = DJRemotes and DJRemotes:FindFirstChild("UpdateVoteSkip"),
    DJVoteSkip       = DJRemotes and DJRemotes:FindFirstChild("RequestVoteSkip"),
}

Log("AdminInput: " .. (R.AdminInput and "FOUND" or "MISSING"))
Log("AdminCommand: " .. (R.AdminCommand and "FOUND" or "MISSING"))
Log("AdminGlobal: " .. (R.AdminGlobal and "FOUND" or "MISSING"))
Log("IsAdmin: " .. (R.IsAdmin and "FOUND" or "MISSING"))

-- STATE
local State = {
    -- Kick All
    AutoKickAll=false,
    KickInterval=0.5,
    KickExceptMe=true,
    KickExceptFriends=false,
    KickWhitelist={},          -- names to skip
    KickTargetName="",         -- optional single target

    -- Respawn Loop (single target)
    LoopRespawn=false,
    LoopRespawnTarget="",
    LoopRespawnInterval=1,

    -- Auto Grant Self
    AutoGiftVIP=false,
    AutoWhitelistMe=false,

    -- Admin abuse toggles
    RemoveAllTitles=false,
    ForceDanceAll=false,
    ForceDanceInterval=2,
    ForceDanceId="",

    -- Anti-detection
    AntiKick=true,
    AntiAdminNotify=true,

    -- Payload strategy
    PayloadMode="Auto",  -- "Auto" tries all, or specific format

    -- Utility
    AntiAFK=true, AutoRejoin=false,

    -- Connections
    KickLoopThread=nil,
    RespawnLoopThread=nil,
    DanceLoopThread=nil,
    AntiKickConn=nil,
    AntiNotifyConn=nil,

    -- Stats
    KickAttempts=0,
    RespawnAttempts=0,
    LastKickTarget="",
    LastRespawnHP=100,
}

-- ═══════════════════════════════════════════
-- PAYLOAD BUILDER
-- ═══════════════════════════════════════════
-- Since we don't know the exact server signature, try MANY formats
local function BuildKickPayloads(targetName, targetPlayer)
    return {
        -- Command string formats
        {":kick " .. targetName},
        {":kick " .. targetName .. " Kicked"},
        {"kick", targetName},
        {"kick", targetPlayer},
        {"Kick", targetName},
        {"Kick", targetPlayer},
        {"KICK", targetName},
        {":k " .. targetName},
        {":ban " .. targetName},
        {"ban", targetName},
        {"remove", targetName},
        {":crash " .. targetName},

        -- Table formats
        {{Command="kick", Target=targetName}},
        {{cmd="kick", target=targetName}},
        {{Action="Kick", Player=targetName}},
        {{Type="Kick", Name=targetName}},
        {{action="kick", player=targetPlayer}},

        -- Args-array formats
        {"kick", {targetName}},
        {"kick", {targetPlayer}},
        {targetName, "kick"},
        {targetPlayer, "kick"},

        -- With reason
        {"kick", targetName, "byebye"},
        {"kick", targetPlayer, "byebye"},
        {":kick", targetName, "byebye"},
    }
end

local function BuildKillPayloads(targetName, targetPlayer)
    return {
        {":kill " .. targetName},
        {"kill", targetName},
        {"kill", targetPlayer},
        {"Kill", targetName},
        {"Kill", targetPlayer},
        {":k " .. targetName},
        {":respawn " .. targetName},
        {"respawn", targetName},
        {"respawn", targetPlayer},
        {"Respawn", targetPlayer},
        {":refresh " .. targetName},
        {"refresh", targetName},
        {":sethp " .. targetName .. " 0"},
        {":damage " .. targetName .. " 999"},
        {"damage", targetName, 999},
        {"damage", targetPlayer, 999},
        {"sethealth", targetName, 0},
        {"sethealth", targetPlayer, 0},

        {{Command="kill", Target=targetName}},
        {{cmd="kill", target=targetName}},
        {{Action="Kill", Player=targetName}},
        {{Action="Respawn", Player=targetName}},
    }
end

-- Fire a payload set through ALL admin remotes
local function FireAllAdminRemotes(payloads)
    local remotes = { R.AdminInput, R.AdminCommand, R.AdminGlobal }
    for _, remote in ipairs(remotes) do
        if remote and remote:IsA("RemoteEvent") then
            for _, args in ipairs(payloads) do
                pcall(function() remote:FireServer(unpack(args)) end)
            end
        elseif remote and remote:IsA("RemoteFunction") then
            for _, args in ipairs(payloads) do
                pcall(function() remote:InvokeServer(unpack(args)) end)
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- CORE ACTIONS
-- ═══════════════════════════════════════════

local function IsInList(list, name)
    for _, n in ipairs(list) do
        if n:lower() == name:lower() then return true end
    end
    return false
end

local function ShouldSkipPlayer(plr)
    if not plr or not plr.Parent then return true end
    if State.KickExceptMe and plr == LocalPlayer then return true end
    if IsInList(State.KickWhitelist, plr.Name) then return true end
    if State.KickExceptFriends then
        local ok, isFriend = pcall(function() return LocalPlayer:IsFriendsWith(plr.UserId) end)
        if ok and isFriend then return true end
    end
    return false
end

local function KickPlayer(plr)
    if not plr then return end
    State.KickAttempts = State.KickAttempts + 1
    State.LastKickTarget = plr.Name
    local payloads = BuildKickPayloads(plr.Name, plr)
    FireAllAdminRemotes(payloads)
end

local function KillPlayer(plr)
    if not plr then return end
    State.RespawnAttempts = State.RespawnAttempts + 1
    local payloads = BuildKillPayloads(plr.Name, plr)
    FireAllAdminRemotes(payloads)
end

-- ═══════════════════════════════════════════
-- AUTO KICK ALL LOOP
-- ═══════════════════════════════════════════
local function StartKickAllLoop()
    if State.KickLoopThread then return end
    State.KickLoopThread = task.spawn(function()
        while State.AutoKickAll do
            for _, plr in ipairs(Players:GetPlayers()) do
                if not State.AutoKickAll then break end
                if not ShouldSkipPlayer(plr) then
                    KickPlayer(plr)
                    task.wait(State.KickInterval)
                end
            end
            task.wait(0.5)
        end
        State.KickLoopThread = nil
    end)
end

local function StopKickAllLoop()
    State.AutoKickAll = false
    State.KickLoopThread = nil
end

-- ═══════════════════════════════════════════
-- LOOP RESPAWN (single target)
-- ═══════════════════════════════════════════
local function StartRespawnLoop()
    if State.RespawnLoopThread then return end
    State.RespawnLoopThread = task.spawn(function()
        while State.LoopRespawn do
            local target = Players:FindFirstChild(State.LoopRespawnTarget)
            if target then
                KillPlayer(target)
            end
            task.wait(State.LoopRespawnInterval)
        end
        State.RespawnLoopThread = nil
    end)
end

local function StopRespawnLoop()
    State.LoopRespawn = false
    State.RespawnLoopThread = nil
end

-- ═══════════════════════════════════════════
-- ANTI-KICK (block AdminNotify targeting us)
-- ═══════════════════════════════════════════
local function SetAntiKick(e)
    if State.AntiKickConn then pcall(function() State.AntiKickConn:Disconnect() end); State.AntiKickConn=nil end
    if not e then return end
    -- Hook the Kick metatable if exploit supports it
    if hookfunction and getrawmetatable then
        local success = pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" and self == LocalPlayer then
                    Log("Anti-Kick: blocked kick attempt")
                    return
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
        if success then Log("Anti-Kick: hook installed") end
    end
end

-- ═══════════════════════════════════════════
-- BLOCK ADMIN NOTIFY (hide any GUI warning)
-- ═══════════════════════════════════════════
local function SetAntiAdminNotify(e)
    if State.AntiNotifyConn then pcall(function() State.AntiNotifyConn:Disconnect() end); State.AntiNotifyConn=nil end
    if not e then return end
    if R.AdminNotify then
        -- Just don't respond to it, but also block display
        State.AntiNotifyConn = R.AdminNotify.OnClientEvent:Connect(function(...)
            Log("Blocked AdminNotify: " .. tostring(select(1, ...)))
        end)
    end
end

-- ═══════════════════════════════════════════
-- AUTO GIFT SELF VIP / WHITELIST
-- ═══════════════════════════════════════════
local function AutoGiftSelfVIP()
    if not R.GiftVIP then return false end
    local ok = pcall(function()
        R.GiftVIP:FireServer(LocalPlayer)
        R.GiftVIP:FireServer(LocalPlayer.Name)
        R.GiftVIP:FireServer(LocalPlayer.UserId)
    end)
    return ok
end

local function AutoWhitelistSelf()
    if not R.AddWhitelist then return false end
    local ok = pcall(function()
        R.AddWhitelist:FireServer(LocalPlayer)
        R.AddWhitelist:FireServer(LocalPlayer.Name)
        R.AddWhitelist:FireServer(LocalPlayer.UserId)
    end)
    return ok
end

-- ═══════════════════════════════════════════
-- REMOVE ALL TITLES / FORCE DANCE
-- ═══════════════════════════════════════════
local function RemoveTitlesFromAll()
    if not R.RemoveTitle then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        pcall(function()
            R.RemoveTitle:FireServer(plr)
            R.RemoveTitle:FireServer(plr.Name)
            R.RemoveTitle:FireServer(plr.UserId)
        end)
    end
end

local function StartForceDanceLoop()
    if State.DanceLoopThread then return end
    if not R.ClientPlayDance then return end
    State.DanceLoopThread = task.spawn(function()
        while State.ForceDanceAll do
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    pcall(function()
                        if State.ForceDanceId ~= "" then
                            R.ClientPlayDance:FireServer(plr, State.ForceDanceId)
                        else
                            R.ClientPlayDance:FireServer(plr)
                        end
                    end)
                end
            end
            task.wait(State.ForceDanceInterval)
        end
        State.DanceLoopThread = nil
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

-- Server hop
local function ServerHop()
    pcall(function()
        local raw = game:HttpGet(
            "https://games.roblox.com/v1/games/"..tostring(HUB.PlaceId).."/servers/Public?sortOrder=Asc&limit=100")
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
    LoadingSubtitle        = "Cidro Janji | " .. HUB.Author,
    Theme                  = "DarkBlue",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings   = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",     name="Main",       icon="home"},
    {key="Kick",     name="Auto Kick",  icon="user-x"},
    {key="Respawn",  name="Loop Kill",  icon="skull"},
    {key="Self",     name="Self Perks", icon="crown"},
    {key="Admin",    name="Admin Cmd",  icon="terminal"},
    {key="Extras",   name="Extras",     icon="zap"},
    {key="Utility",  name="Utility",    icon="wrench"},
    {key="Settings", name="Settings",   icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- MAIN TAB
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("Info")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Game: Cidro Janji")
    T:CreateLabel("Mode: Server-side only (no visuals)")

    T:CreateSection("Remote Status")
    T:CreateLabel("AdminInput: " .. (R.AdminInput and "✓" or "✗"))
    T:CreateLabel("AdminCommand: " .. (R.AdminCommand and "✓" or "✗"))
    T:CreateLabel("AdminGlobal: " .. (R.AdminGlobal and "✓" or "✗"))
    T:CreateLabel("GiftVIP: " .. (R.GiftVIP and "✓" or "✗"))
    T:CreateLabel("AddWhitelist: " .. (R.AddWhitelist and "✓" or "✗"))

    T:CreateSection("Test Admin Access")
    T:CreateButton({Name="Check if I'm Admin", Callback=function()
        if R.IsAdmin then
            local ok, res = pcall(function() return R.IsAdmin:InvokeServer() end)
            local msg = ok and ("Result: " .. tostring(res)) or ("Error: " .. tostring(res))
            Rayfield:Notify({Title="IsAdmin", Content=msg, Duration=5})
            Log("IsAdmin: " .. msg)
        else
            Rayfield:Notify({Title="IsAdmin", Content="Remote missing", Duration=3})
        end
    end})

    T:CreateButton({Name="Test Fire AdminInput on Self", Callback=function()
        Log("Test-firing AdminInput on self...")
        local payloads = BuildKillPayloads(LocalPlayer.Name, LocalPlayer)
        FireAllAdminRemotes(payloads)
        Log("Test fired. Watch for effect on your character.")
    end})

    T:CreateSection("Stats")
    T:CreateLabel("Kick attempts: 0")
    T:CreateLabel("Kill attempts: 0")

    T:CreateSection("Keybinds")
    T:CreateLabel("End = Stop all loops (panic)")
end

-- KICK TAB
if Tabs.Kick then
    local T = Tabs.Kick
    T:CreateSection("Auto Kick All Players")
    T:CreateLabel("Loops through all players and fires kick")
    T:CreateLabel("Tries every admin remote + payload format")

    T:CreateToggle({Name="Enable Auto Kick All", CurrentValue=false, Flag="AKA",
        Callback=function(v)
            State.AutoKickAll = v
            if v then StartKickAllLoop() else StopKickAllLoop() end
            Log("AutoKickAll: " .. tostring(v))
        end})

    T:CreateSlider({Name="Interval Between Kicks (x0.1s)",
        Range={1,30}, Increment=1, CurrentValue=5, Flag="KI",
        Callback=function(v) State.KickInterval = (tonumber(v) or 5) * 0.1 end})

    T:CreateSection("Skip Filters")
    T:CreateToggle({Name="Skip Myself", CurrentValue=true, Flag="KEM",
        Callback=function(v) State.KickExceptMe = v end})
    T:CreateToggle({Name="Skip Friends", CurrentValue=false, Flag="KEF",
        Callback=function(v) State.KickExceptFriends = v end})

    T:CreateSection("Manual Whitelist (comma-separated)")
    T:CreateInput({Name="Skip Player Names", PlaceholderText="name1,name2,name3",
        RemoveTextAfterFocusLost=false,
        Callback=function(v)
            State.KickWhitelist = {}
            for name in string.gmatch(tostring(v or ""), "([^,]+)") do
                table.insert(State.KickWhitelist, name:match("^%s*(.-)%s*$"))
            end
            Log("Whitelist: " .. #State.KickWhitelist .. " players")
        end})

    T:CreateSection("Kick Single Player")
    T:CreateInput({Name="Target Name", PlaceholderText="username",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.KickTargetName = tostring(v or "") end})
    T:CreateButton({Name="Kick Target Now", Callback=function()
        local target = Players:FindFirstChild(State.KickTargetName)
        if target then
            KickPlayer(target)
            Log("Fired kick on: " .. State.KickTargetName)
        else
            Log("Player not found: " .. State.KickTargetName)
        end
    end})

    T:CreateSection("Quick Actions")
    T:CreateButton({Name="Kick Everyone Once", Callback=function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if not ShouldSkipPlayer(plr) then
                KickPlayer(plr)
                task.wait(0.1)
            end
        end
        Log("Fired kick on all players")
    end})

    T:CreateButton({Name="Stop All Kick Loops", Callback=function()
        State.AutoKickAll = false
        Log("Stopped kick loops")
    end})
end

-- RESPAWN LOOP TAB
if Tabs.Respawn then
    local T = Tabs.Respawn
    T:CreateSection("Loop Respawn Single Target")
    T:CreateLabel("Locks a player in death loop")

    T:CreateInput({Name="Target Player Name", PlaceholderText="username",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.LoopRespawnTarget = tostring(v or "") end})

    T:CreateSlider({Name="Kill Interval (x0.5s)",
        Range={1,20}, Increment=1, CurrentValue=2, Flag="LRI",
        Callback=function(v) State.LoopRespawnInterval = (tonumber(v) or 2) * 0.5 end})

    T:CreateToggle({Name="Enable Loop Kill", CurrentValue=false, Flag="LR",
        Callback=function(v)
            State.LoopRespawn = v
            if v then
                if State.LoopRespawnTarget == "" then
                    Log("Set a target name first!")
                    State.LoopRespawn = false
                    return
                end
                StartRespawnLoop()
                Log("Loop kill started on: " .. State.LoopRespawnTarget)
            else
                StopRespawnLoop()
                Log("Loop kill stopped")
            end
        end})

    T:CreateSection("Manual")
    T:CreateButton({Name="Kill Target Once", Callback=function()
        local target = Players:FindFirstChild(State.LoopRespawnTarget)
        if target then
            KillPlayer(target)
            Log("Fired kill on: " .. State.LoopRespawnTarget)
        else
            Log("Target not found")
        end
    end})

    T:CreateButton({Name="Kill All Once", Callback=function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                KillPlayer(plr)
                task.wait(0.05)
            end
        end
        Log("Killed all players once")
    end})

    T:CreateButton({Name="Stop Loop Kill", Callback=function()
        State.LoopRespawn = false
        Log("Stopped")
    end})
end

-- SELF PERKS TAB
if Tabs.Self then
    local T = Tabs.Self
    T:CreateSection("Grant Self Perks (may or may not work)")

    T:CreateButton({Name="Grant Self VIP", Callback=function()
        local ok = AutoGiftSelfVIP()
        Log("VIP gift fired: " .. tostring(ok))
    end})

    T:CreateButton({Name="Add Self to Whitelist", Callback=function()
        local ok = AutoWhitelistSelf()
        Log("Whitelist fired: " .. tostring(ok))
    end})

    T:CreateButton({Name="Add Self as Admin (probe)", Callback=function()
        if R.AddRole then
            pcall(function()
                R.AddRole:FireServer(LocalPlayer, "Admin")
                R.AddRole:FireServer(LocalPlayer.Name, "Admin")
                R.AddRole:FireServer(LocalPlayer, "admin")
                R.AddRole:FireServer(LocalPlayer, "Owner")
                R.AddRole:FireServer(LocalPlayer.UserId, "Admin")
            end)
        end
        Log("Role add fired")
    end})

    T:CreateSection("Loop Self Grant")
    T:CreateToggle({Name="Auto Grant VIP Every 5s", CurrentValue=false, Flag="AGV",
        Callback=function(v)
            State.AutoGiftVIP = v
            if v then
                task.spawn(function()
                    while State.AutoGiftVIP do
                        AutoGiftSelfVIP()
                        task.wait(5)
                    end
                end)
            end
        end})

    T:CreateToggle({Name="Auto Whitelist Every 5s", CurrentValue=false, Flag="AWM",
        Callback=function(v)
            State.AutoWhitelistMe = v
            if v then
                task.spawn(function()
                    while State.AutoWhitelistMe do
                        AutoWhitelistSelf()
                        task.wait(5)
                    end
                end)
            end
        end})
end

-- ADMIN COMMAND TAB
if Tabs.Admin then
    local T = Tabs.Admin
    T:CreateSection("Raw Admin Command")
    T:CreateLabel("Type a command to fire on ALL admin remotes")

    local customCmd = ""
    local customArg = ""

    T:CreateInput({Name="Command", PlaceholderText=":kick playername",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) customCmd = tostring(v or "") end})

    T:CreateInput({Name="Extra Arg (optional)", PlaceholderText="playername or value",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) customArg = tostring(v or "") end})

    T:CreateButton({Name="Fire Command", Callback=function()
        local args
        if customArg ~= "" then
            args = { {customCmd, customArg}, {customCmd, Players:FindFirstChild(customArg) or customArg} }
        else
            args = { {customCmd} }
        end
        FireAllAdminRemotes(args)
        Log("Fired command: " .. customCmd .. " " .. customArg)
    end})

    T:CreateSection("Common Admin Command Presets")
    for _, cmd in ipairs({":kick", ":kill", ":respawn", ":refresh", ":ban", ":crash",
                         ":ff", ":unff", ":god", ":ungod", ":freeze", ":thaw",
                         ":tp", ":bring", ":to", ":view"}) do
        T:CreateButton({Name="Fire " .. cmd .. " " .. (customArg ~= "" and customArg or "[arg]"), Callback=function()
            if customArg ~= "" then
                FireAllAdminRemotes({
                    {cmd .. " " .. customArg},
                    {cmd, customArg},
                    {cmd, Players:FindFirstChild(customArg) or customArg},
                })
                Log("Fired: " .. cmd .. " " .. customArg)
            else
                Log("Set 'Extra Arg' first")
            end
        end})
    end
end

-- EXTRAS TAB
if Tabs.Extras then
    local T = Tabs.Extras
    T:CreateSection("Title Grief")
    T:CreateButton({Name="Remove Title From All Players", Callback=function()
        RemoveTitlesFromAll()
        Log("Fired title removal on all")
    end})

    T:CreateSection("Force Dance on All")
    T:CreateInput({Name="Dance ID (leave empty for default)", PlaceholderText="dance_id",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.ForceDanceId = tostring(v or "") end})
    T:CreateSlider({Name="Dance Interval (x0.5s)", Range={1,10}, Increment=1, CurrentValue=4, Flag="FDI",
        Callback=function(v) State.ForceDanceInterval = (tonumber(v) or 4) * 0.5 end})
    T:CreateToggle({Name="Force Dance Loop", CurrentValue=false, Flag="FDA",
        Callback=function(v)
            State.ForceDanceAll = v
            if v then StartForceDanceLoop() end
        end})

    T:CreateSection("DJ Grief (if game has DJ system)")
    T:CreateButton({Name="Skip Song (vote)", Callback=function()
        if R.DJVoteSkip then pcall(function() R.DJVoteSkip:FireServer() end) end
        if R.DJUpdateSkip then pcall(function() R.DJUpdateSkip:FireServer() end) end
    end})
    T:CreateSlider({Name="Set Pitch", Range={1,30}, Increment=1, CurrentValue=10, Flag="DJP",
        Callback=function(v)
            if R.DJPitch then
                pcall(function() R.DJPitch:FireServer((tonumber(v) or 10) * 0.1) end)
            end
        end})
end

-- UTILITY TAB
if Tabs.Utility then
    local T = Tabs.Utility
    T:CreateSection("Anti-Detection")
    T:CreateToggle({Name="Anti-Kick (blocks kicks on you)", CurrentValue=true, Flag="AK",
        Callback=function(v) State.AntiKick=v; SetAntiKick(v) end})
    T:CreateToggle({Name="Block AdminNotify events", CurrentValue=true, Flag="ANN",
        Callback=function(v) State.AntiAdminNotify=v; SetAntiAdminNotify(v) end})

    T:CreateSection("Anti-AFK")
    T:CreateToggle({Name="Anti-AFK", CurrentValue=true, Flag="AAF",
        Callback=function(v) State.AntiAFK = v end})

    T:CreateSection("Server")
    T:CreateButton({Name="Server Hop", Callback=ServerHop})
    T:CreateButton({Name="Rejoin Server", Callback=function()
        pcall(function() TeleportService:Teleport(HUB.PlaceId, LocalPlayer) end)
    end})
    T:CreateToggle({Name="Auto Rejoin on Kick", CurrentValue=false, Flag="AR",
        Callback=function(v) State.AutoRejoin = v end})

    T:CreateSection("Diagnostic")
    T:CreateButton({Name="List All Players", Callback=function()
        Log("=== PLAYERS (" .. #Players:GetPlayers() .. ") ===")
        for _, p in ipairs(Players:GetPlayers()) do
            Log(p.Name .. " | ID=" .. p.UserId)
        end
    end})
    T:CreateButton({Name="Dump Remote List", Callback=function()
        Log("=== REMOTES ===")
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                Log(v.ClassName .. " | " .. v:GetFullName())
            end
        end
    end})
end

-- SETTINGS TAB
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("Credits")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Author: " .. HUB.Author)
    T:CreateLabel("Target: Cidro Janji (PID " .. HUB.PlaceId .. ")")

    T:CreateSection("Notes")
    T:CreateLabel("This hub exploits exposed admin remotes")
    T:CreateLabel("If nothing works, server validates properly")
    T:CreateLabel("Some remotes may throttle/rate-limit")

    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Hub", Callback=function()
        State.AutoKickAll=false; State.LoopRespawn=false
        State.AutoGiftVIP=false; State.AutoWhitelistMe=false
        State.ForceDanceAll=false
        if State.AntiKickConn then pcall(function() State.AntiKickConn:Disconnect() end) end
        if State.AntiNotifyConn then pcall(function() State.AntiNotifyConn:Disconnect() end) end
        CM:Cleanup()
        _G[INSTANCE_KEY] = nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- KEYBIND: End = panic stop
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.End then
        State.AutoKickAll=false; State.LoopRespawn=false
        State.AutoGiftVIP=false; State.AutoWhitelistMe=false
        State.ForceDanceAll=false
        Log("PANIC: All loops stopped")
        Rayfield:Notify({Title="PANIC", Content="All loops stopped", Duration=3})
    end
end)

-- Apply anti-kick by default
if State.AntiKick then SetAntiKick(true) end
if State.AntiAdminNotify then SetAntiAdminNotify(true) end

-- GLOBAL INSTANCE
_G[INSTANCE_KEY] = {
    version=HUB.Version, timestamp=os.time(),
    destroy=function()
        State.AutoKickAll=false; State.LoopRespawn=false
        State.AutoGiftVIP=false; State.AutoWhitelistMe=false
        State.ForceDanceAll=false
        if State.AntiKickConn then pcall(function() State.AntiKickConn:Disconnect() end) end
        if State.AntiNotifyConn then pcall(function() State.AntiNotifyConn:Disconnect() end) end
        CM:Cleanup()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Rayfield:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded", Duration=5})
Log("Ready — server-side hub loaded")
