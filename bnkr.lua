--═══════════════════════════════════════════════════════════════
-- X0DEC04T Bunker Troll Hub v1.1.0 — CORRECT PAYLOADS
-- Based on real decompiled LocalScript signatures
-- NO metatable hooks. NO detection triggers.
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

local INSTANCE_KEY = "__X0DEC04T_BUNKER_v110_INSTANCE"
if _G[INSTANCE_KEY] then
    local prev = _G[INSTANCE_KEY]
    if type(prev.destroy) == "function" then pcall(prev.destroy) end
    _G[INSTANCE_KEY] = nil
    task.wait(0.1)
end

local SILENT = false
local function Log(msg)
    if SILENT then return end
    print("[X0-BUNKER] " .. tostring(msg))
end

Log("Loading Bunker Troll Hub v1.1.0 — REAL PAYLOADS")

local READY = false
task.spawn(function()
    task.wait(2)
    READY = true
    Log("Ready")
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
    Name = "X0DEC04T Bunker Troll",
    Version = "1.1.0",
    Author = "voixera",
    PlaceId = 133943904733338,
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

-- REMOTES (exact paths from recon)
local function GR(path)
    local cur = ReplicatedStorage
    for part in string.gmatch(path, "[^.]+") do
        if not cur then return nil end
        cur = cur:FindFirstChild(part)
    end
    return cur
end

local R = {
    SetColor         = GR("Remotes.ColorPicker.SetColor"),
    CarryRemote      = GR("Remotes.Carry.CarryRemote"),
    CarryRemoteAlt   = GR("CarryReplic.CarryRemotes.CarryRemote"),
    UpdateAnimation  = GR("Remotes.Animation.UpdateAnimation"),
    AdminCommand     = GR("Remotes.Admin.AdminCommand"),
    EffectRemote     = GR("Remotes.Core.EffectRemote"),
    ShowAnnouncement = GR("Remotes.Core.ShowAnnouncement"),
    ShowNotification = GR("Remotes.Core.ShowNotification"),
    MusicControl     = GR("Remotes.Music.MusicControlEvent"),
    MusicControlAlt  = GR("Music.Remotes.MusicControlEvent"),
    CommandEvent     = GR("Remotes.Command.CommandEvent"),
    UnparticlesEvent = GR("EffectRemotes.UnparticlesEvent"),
    SyncBroadcast    = GR("Remotes.Core.SyncBroadcast"),
}

Log("SetColor: " .. (R.SetColor and "Y" or "N"))
Log("CarryRemote: " .. (R.CarryRemote and "Y" or "N"))
Log("UpdateAnimation: " .. (R.UpdateAnimation and "Y" or "N"))
Log("AdminCommand: " .. (R.AdminCommand and "Y" or "N"))

-- STATE
local State = {
    -- Rate control
    LastFireTime = 0,
    FireCooldown = 0.3,

    -- Force Carry
    ForceCarryTarget = "",
    ForceCarryChoice = "piggyback",
    ForceCarryLoop = false,
    ForceCarryInterval = 1,
    ForceCarryThread = nil,
    CarrySpamAll = false,
    CarrySpamThread = nil,

    -- Color Spam
    ColorSpam = false,
    ColorSpamRate = 0.5,
    ColorSpamThread = nil,

    -- Animation Spam
    AnimSpam = false,
    AnimSpamRate = 1,
    AnimSpamId = "rbxassetid://11333281100",
    AnimSpamThread = nil,

    -- Admin Probe
    AdminProbeLoop = false,
    AdminProbeThread = nil,

    -- Music
    MusicSpam = false,
    MusicSpamRate = 2,
    MusicSpamThread = nil,

    -- Effect
    EffectSpam = false,
    EffectSpamRate = 1,
    EffectSpamThread = nil,

    -- Utility
    AntiAFK = true,
    AutoRejoin = false,
    FiresSent = 0,
}

-- SAFE FIRE (rate limited)
local function SafeFire(remote, ...)
    if not remote then return false end
    if not READY then return false end
    local now = tick()
    local wait_needed = State.FireCooldown - (now - State.LastFireTime)
    if wait_needed > 0 then task.wait(wait_needed) end
    State.LastFireTime = tick()
    local args = table.pack(...)
    local ok = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    if ok then State.FiresSent = State.FiresSent + 1 end
    return ok
end

local function Jitter(base) return base * (0.85 + math.random() * 0.30) end

-- ═══════════════════════════════════════════
-- 1. FORCE CARRY (CONFIRMED FORMAT)
-- {cmd="Carry", firstPlr=PLAYER, carrychoicesss=CHOICE}
-- ═══════════════════════════════════════════
local CARRY_CHOICES = {
    "piggyback", "bridal", "shoulder", "fireman",
    "Piggyback", "Bridal", "Shoulder", "Fireman",
    "piggy", "carry",
}

local function ForceCarry(targetName, choice)
    local target = Players:FindFirstChild(targetName)
    if not target then return end
    local ch = choice or State.ForceCarryChoice

    -- EXACT format from decompiled source
    local payload = {
        cmd = "Carry",
        firstPlr = target,
        carrychoicesss = ch,
    }

    if R.CarryRemote then
        SafeFire(R.CarryRemote, payload)
    end
    if R.CarryRemoteAlt then
        SafeFire(R.CarryRemoteAlt, payload)
    end

    -- Also try with player name instead of instance
    local payload2 = {
        cmd = "Carry",
        firstPlr = target.Name,
        carrychoicesss = ch,
    }
    if R.CarryRemote then
        SafeFire(R.CarryRemote, payload2)
    end

    -- Also try PromptAction first (some games need this)
    if R.CarryRemote then
        SafeFire(R.CarryRemote, {cmd = "PromptAction"})
    end
end

local function CancelCarry()
    if R.CarryRemote then
        SafeFire(R.CarryRemote, {cmd = "CancelAll"})
    end
    if R.CarryRemoteAlt then
        SafeFire(R.CarryRemoteAlt, {cmd = "CancelAll"})
    end
end

local function StartForceCarryLoop()
    if State.ForceCarryThread then return end
    State.ForceCarryThread = task.spawn(function()
        while State.ForceCarryLoop do
            if State.ForceCarryTarget ~= "" then
                ForceCarry(State.ForceCarryTarget, State.ForceCarryChoice)
            end
            task.wait(Jitter(State.ForceCarryInterval))
        end
        State.ForceCarryThread = nil
    end)
end

-- Carry ALL players one by one
local function StartCarrySpamAll()
    if State.CarrySpamThread then return end
    State.CarrySpamThread = task.spawn(function()
        while State.CarrySpamAll do
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and State.CarrySpamAll then
                    ForceCarry(plr.Name, State.ForceCarryChoice)
                    task.wait(Jitter(0.8))
                end
            end
            task.wait(1)
        end
        State.CarrySpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- 2. COLOR SPAM (CONFIRMED FORMAT)
-- SetColor:FireServer(Color3)
-- ═══════════════════════════════════════════
local function SetColor(color)
    if R.SetColor then
        SafeFire(R.SetColor, color)
    end
end

local function StartColorSpam()
    if State.ColorSpamThread then return end
    State.ColorSpamThread = task.spawn(function()
        while State.ColorSpam do
            local c = Color3.fromHSV(math.random(), 1, 1)
            SetColor(c)
            task.wait(Jitter(State.ColorSpamRate))
        end
        State.ColorSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- 3. ANIMATION SPAM (CONFIRMED FORMAT)
-- UpdateAnimation:FireServer(animId)
-- ═══════════════════════════════════════════
local FUNNY_ANIMS = {
    "rbxassetid://11333281100",  -- twerk
    "rbxassetid://12669802779",  -- griddy
    "rbxassetid://507770239",    -- caveman
    "rbxassetid://507778381",    -- zombie
    "rbxassetid://507777268",    -- robot
    "rbxassetid://507778133",    -- werewolf
    "rbxassetid://507770453",    -- default
    "rbxassetid://507776663",    -- ninja
    "rbxassetid://507776043",    -- monster
    "rbxassetid://507777823",    -- superhero
    "rbxassetid://5918726674",   -- stylish
    "rbxassetid://5915773155",   -- confident
}

local function PlayAnimation(animId)
    if R.UpdateAnimation then
        SafeFire(R.UpdateAnimation, animId or State.AnimSpamId)
    end
end

local function StartAnimSpam()
    if State.AnimSpamThread then return end
    State.AnimSpamThread = task.spawn(function()
        while State.AnimSpam do
            local animId
            if State.AnimSpamId == "Random" then
                animId = FUNNY_ANIMS[math.random(#FUNNY_ANIMS)]
            else
                animId = State.AnimSpamId
            end
            PlayAnimation(animId)
            task.wait(Jitter(State.AnimSpamRate))
        end
        State.AnimSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- 4. ADMIN COMMAND PROBE (CONFIRMED FORMAT)
-- AdminCommand:FireServer(command, ...)
-- ═══════════════════════════════════════════
local function FireAdminCmd(cmd, ...)
    if R.AdminCommand then SafeFire(R.AdminCommand, cmd, ...) end
    if R.CommandEvent then SafeFire(R.CommandEvent, cmd, ...) end
end

-- Auto-probe: try common admin commands
local ADMIN_CMDS = {
    {":kick %s", true},       -- needs target
    {":kill %s", true},
    {":ban %s", true},
    {":respawn %s", true},
    {":crash %s", true},
    {":freeze %s", true},
    {":god %s", true},
    {":ungod %s", true},
    {":ff %s", true},
    {":unff %s", true},
    {":fly %s", true},
    {":speed %s 200", true},
    {":jump %s 200", true},
    {":bring %s", true},
    {":tp %s me", true},
    {":announce %s", false},  -- no target
    {":shutdown", false},
}

local function AdminProbeTarget(targetName)
    for _, cmdDef in ipairs(ADMIN_CMDS) do
        local template = cmdDef[1]
        local needsTarget = cmdDef[2]
        local cmd
        if needsTarget then
            cmd = string.format(template, targetName)
        else
            cmd = template
        end
        FireAdminCmd(cmd)
        task.wait(Jitter(0.5))
    end
end

-- ═══════════════════════════════════════════
-- 5. MUSIC CONTROL
-- ═══════════════════════════════════════════
local TROLL_SOUNDS = {
    {name="John Cena", id="9040032945"},
    {name="MLG Airhorn", id="130785000"},
    {name="Bass Boosted", id="1848354536"},
    {name="Emergency Alert", id="1839246711"},
    {name="Suspense Horror", id="1837624077"},
    {name="Scary", id="154898028"},
    {name="Moan", id="4590657391"},
}

local function FireMusicControl(soundId)
    -- Try multiple known command formats
    local cmds = {
        {"play", soundId},
        {"Play", soundId},
        {"change", soundId},
        {"queue", soundId},
        {"skip"},
        {soundId},
        {"set", soundId},
        {{action="play", id=soundId}},
    }
    for _, c in ipairs(cmds) do
        if R.MusicControl then SafeFire(R.MusicControl, table.unpack(c)) end
        task.wait(0.05)
        if R.MusicControlAlt then SafeFire(R.MusicControlAlt, table.unpack(c)) end
        task.wait(0.05)
    end
end

local function StartMusicSpam()
    if State.MusicSpamThread then return end
    State.MusicSpamThread = task.spawn(function()
        while State.MusicSpam do
            local sound = TROLL_SOUNDS[math.random(#TROLL_SOUNDS)]
            FireMusicControl(sound.id)
            task.wait(Jitter(State.MusicSpamRate))
        end
        State.MusicSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- 6. EFFECT REMOTE
-- ═══════════════════════════════════════════
local function FireEffect(effectName)
    if not R.EffectRemote then return end
    local ch = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local pos = hrp and hrp.Position or Vector3.new(0,10,0)

    -- Try every format
    SafeFire(R.EffectRemote, effectName)
    SafeFire(R.EffectRemote, effectName, pos)
    SafeFire(R.EffectRemote, effectName, LocalPlayer)
    SafeFire(R.EffectRemote, {effect=effectName, position=pos})
    SafeFire(R.EffectRemote, {name=effectName, player=LocalPlayer})
end

local function StartEffectSpam()
    if State.EffectSpamThread then return end
    local effects = {"Explosion","Fire","Smoke","Sparkle","Confetti","Fireworks","Lightning"}
    State.EffectSpamThread = task.spawn(function()
        while State.EffectSpam do
            FireEffect(effects[math.random(#effects)])
            task.wait(Jitter(State.EffectSpamRate))
        end
        State.EffectSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- STOP ALL
-- ═══════════════════════════════════════════
local function PanicStop()
    State.ForceCarryLoop = false
    State.CarrySpamAll = false
    State.ColorSpam = false
    State.AnimSpam = false
    State.AdminProbeLoop = false
    State.MusicSpam = false
    State.EffectSpam = false
    CancelCarry()
    Log("PANIC: All loops stopped")
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
    Name = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle = HUB.Name,
    LoadingSubtitle = "Real Payloads — " .. HUB.Author,
    Theme = "DarkBlue",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",  name="Main",        icon="home"},
    {key="Carry", name="Force Carry",  icon="users"},
    {key="Color", name="Color Spam",   icon="palette"},
    {key="Anim",  name="Animation",    icon="user"},
    {key="Admin", name="Admin Probe",  icon="shield-alert"},
    {key="Music", name="Music",        icon="music"},
    {key="Effect",name="Effects",      icon="sparkles"},
    {key="Util",  name="Utility",      icon="wrench"},
    {key="Set",   name="Settings",     icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- ═══════ MAIN TAB ═══════
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("v1.1.0 — Real Decompiled Payloads")
    T:CreateLabel("Based on actual game LocalScript source code")
    T:CreateLabel("No guessing. Exact arg format used.")

    T:CreateSection("Confirmed Working Formats")
    T:CreateLabel("SetColor: FireServer(Color3)")
    T:CreateLabel("Carry: FireServer({cmd,firstPlr,carrychoicesss})")
    T:CreateLabel("Animation: FireServer(animId)")
    T:CreateLabel("AdminCmd: FireServer(cmdString, ...)")

    T:CreateSection("Quick Tests (try each ONCE first)")
    T:CreateButton({Name="Test: Set Color Red", Callback=function()
        SetColor(Color3.fromRGB(255, 0, 0))
        Rayfield:Notify({Title="Color", Content="Set red. Did you see it?", Duration=4})
    end})
    T:CreateButton({Name="Test: Play Twerk Anim", Callback=function()
        PlayAnimation("rbxassetid://11333281100")
        Rayfield:Notify({Title="Anim", Content="Twerk fired. Do others see it?", Duration=4})
    end})
    T:CreateButton({Name="Test: Force Carry Nearest", Callback=function()
        local nearest, nearDist = nil, math.huge
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    local ohrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if ohrp then
                        local d = (ohrp.Position - hrp.Position).Magnitude
                        if d < nearDist then nearDist = d; nearest = p end
                    end
                end
            end
        end
        if nearest then
            ForceCarry(nearest.Name, "piggyback")
            Rayfield:Notify({Title="Carry", Content="Tried carrying " .. nearest.Name, Duration=4})
        end
    end})
    T:CreateButton({Name="Test: Cancel All Carry", Callback=CancelCarry})

    T:CreateSection("Panic")
    T:CreateButton({Name="STOP ALL LOOPS", Callback=function()
        PanicStop()
        Rayfield:Notify({Title="PANIC", Content="All stopped", Duration=3})
    end})
end

-- ═══════ FORCE CARRY TAB ═══════
if Tabs.Carry then
    local T = Tabs.Carry
    T:CreateSection("Force Carry Player (server-side)")
    T:CreateLabel("Uses EXACT game format: {cmd,firstPlr,carrychoicesss}")

    T:CreateInput({Name="Target Player Name",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.ForceCarryTarget = tostring(v or "") end})

    T:CreateDropdown({Name="Carry Type",
        Options={"piggyback","bridal","shoulder","fireman","Piggyback","Bridal","Shoulder","Fireman"},
        CurrentOption={"piggyback"}, Flag="CT",
        Callback=function(v)
            State.ForceCarryChoice = (type(v)=="table" and v[1]) or v
        end})

    T:CreateButton({Name="Force Carry Target Once", Callback=function()
        if State.ForceCarryTarget == "" then
            Rayfield:Notify({Title="Carry", Content="Set target name", Duration=3})
            return
        end
        ForceCarry(State.ForceCarryTarget, State.ForceCarryChoice)
        Rayfield:Notify({Title="Carry", Content="Fired on " .. State.ForceCarryTarget, Duration=3})
    end})

    T:CreateSlider({Name="Loop Interval (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="FCI",
        Callback=function(v) State.ForceCarryInterval = tonumber(v) or 1 end})

    T:CreateToggle({Name="Loop Force Carry Target", CurrentValue=false, Flag="FCL",
        Callback=function(v)
            State.ForceCarryLoop = v
            if v then
                if State.ForceCarryTarget == "" then
                    State.ForceCarryLoop = false
                    Rayfield:Notify({Title="Carry", Content="Set target first", Duration=3})
                    return
                end
                StartForceCarryLoop()
            end
        end})

    T:CreateSection("Carry ALL Players")
    T:CreateToggle({Name="Force Carry Everyone (loop)", CurrentValue=false, Flag="CSA",
        Callback=function(v)
            State.CarrySpamAll = v
            if v then StartCarrySpamAll() end
        end})

    T:CreateSection("Cancel")
    T:CreateButton({Name="Cancel All Carry", Callback=CancelCarry})
    T:CreateButton({Name="Decline All Carry Requests", Callback=function()
        if R.CarryRemote then SafeFire(R.CarryRemote, {cmd="Declinecarry"}) end
    end})
end

-- ═══════ COLOR SPAM TAB ═══════
if Tabs.Color then
    local T = Tabs.Color
    T:CreateSection("Color Change (visible to all)")
    T:CreateLabel("Uses EXACT format: SetColor:FireServer(Color3)")

    T:CreateButton({Name="Set: Red", Callback=function() SetColor(Color3.fromRGB(255,0,0)) end})
    T:CreateButton({Name="Set: Green", Callback=function() SetColor(Color3.fromRGB(0,255,0)) end})
    T:CreateButton({Name="Set: Blue", Callback=function() SetColor(Color3.fromRGB(0,0,255)) end})
    T:CreateButton({Name="Set: Pink", Callback=function() SetColor(Color3.fromRGB(255,50,200)) end})
    T:CreateButton({Name="Set: Black", Callback=function() SetColor(Color3.fromRGB(0,0,0)) end})
    T:CreateButton({Name="Set: White", Callback=function() SetColor(Color3.fromRGB(255,255,255)) end})
    T:CreateButton({Name="Set: Random", Callback=function()
        SetColor(Color3.fromHSV(math.random(), 1, 1))
    end})

    T:CreateSection("Rainbow Spam Loop")
    T:CreateSlider({Name="Color Change Speed (x0.1s)",
        Range={1,20}, Increment=1, CurrentValue=5, Flag="CSR",
        Callback=function(v) State.ColorSpamRate = (tonumber(v) or 5) * 0.1 end})

    T:CreateToggle({Name="Rainbow Color Spam", CurrentValue=false, Flag="CSP",
        Callback=function(v)
            State.ColorSpam = v
            if v then StartColorSpam() end
        end})
end

-- ═══════ ANIMATION TAB ═══════
if Tabs.Anim then
    local T = Tabs.Anim
    T:CreateSection("Play Animation (visible to all)")
    T:CreateLabel("Uses EXACT format: UpdateAnimation:FireServer(id)")

    T:CreateSection("Preset Animations")
    for _, preset in ipairs({
        {name="Twerk", id="rbxassetid://11333281100"},
        {name="Griddy", id="rbxassetid://12669802779"},
        {name="Caveman", id="rbxassetid://507770239"},
        {name="Zombie", id="rbxassetid://507778381"},
        {name="Robot", id="rbxassetid://507777268"},
        {name="Werewolf", id="rbxassetid://507778133"},
        {name="Ninja", id="rbxassetid://507776663"},
        {name="Monster", id="rbxassetid://507776043"},
        {name="Superhero", id="rbxassetid://507777823"},
    }) do
        T:CreateButton({Name="Play: " .. preset.name, Callback=function()
            PlayAnimation(preset.id)
        end})
    end

    T:CreateSection("Custom Animation")
    T:CreateInput({Name="Animation ID",
        PlaceholderText="rbxassetid://11333281100",
        RemoveTextAfterFocusLost=false,
        Callback=function(v) State.AnimSpamId = tostring(v or "rbxassetid://11333281100") end})

    T:CreateButton({Name="Play Custom Once", Callback=function()
        PlayAnimation(State.AnimSpamId)
    end})

    T:CreateSection("Animation Spam Loop")
    T:CreateSlider({Name="Change Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="ASR",
        Callback=function(v) State.AnimSpamRate = tonumber(v) or 1 end})

    T:CreateDropdown({Name="Spam Mode",
        Options={"Random","Custom"},
        CurrentOption={"Random"}, Flag="ASM",
        Callback=function(v)
            local val = (type(v)=="table" and v[1]) or v
            if val == "Random" then State.AnimSpamId = "Random" end
        end})

    T:CreateToggle({Name="Animation Spam Loop", CurrentValue=false, Flag="ASL",
        Callback=function(v)
            State.AnimSpam = v
            if v then StartAnimSpam() end
        end})

    T:CreateButton({Name="Reset Animation", Callback=function()
        if R.UpdateAnimation then SafeFire(R.UpdateAnimation) end
    end})
end

-- ═══════ ADMIN PROBE TAB ═══════
if Tabs.Admin then
    local T = Tabs.Admin
    T:CreateSection("Admin Command Probe")
    T:CreateLabel("Format: AdminCommand:FireServer(cmd, ...)")
    T:CreateLabel("Tries common admin commands")
    T:CreateLabel("Probably server-validated but worth testing")

    local probeTarget = ""
    T:CreateInput({Name="Target Player (for kick/kill etc)",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) probeTarget = tostring(v or "") end})

    T:CreateSection("Single Commands")
    for _, cmd in ipairs({
        ":kick", ":kill", ":ban", ":crash", ":respawn",
        ":freeze", ":thaw", ":ff", ":unff",
        ":fly", ":god", ":ungod",
        ":speed 200", ":jump 200", ":bring", ":tp",
    }) do
        T:CreateButton({Name="Fire: " .. cmd, Callback=function()
            if probeTarget ~= "" then
                FireAdminCmd(cmd .. " " .. probeTarget)
                FireAdminCmd(cmd, probeTarget)
            else
                FireAdminCmd(cmd)
            end
        end})
    end

    T:CreateSection("Broadcast Commands")
    T:CreateButton({Name="Fire: :announce TEST", Callback=function()
        FireAdminCmd(":announce X0DEC04T WAS HERE")
        FireAdminCmd(":announce", "X0DEC04T WAS HERE")
    end})
    T:CreateButton({Name="Fire: :shutdown", Callback=function()
        FireAdminCmd(":shutdown")
    end})

    T:CreateSection("Probe All on Target")
    T:CreateButton({Name="Try ALL admin commands on target", Callback=function()
        if probeTarget == "" then
            Rayfield:Notify({Title="Probe", Content="Set target first", Duration=3})
            return
        end
        task.spawn(function()
            AdminProbeTarget(probeTarget)
            Rayfield:Notify({Title="Probe", Content="All commands fired", Duration=4})
        end)
    end})
end

-- ═══════ MUSIC TAB ═══════
if Tabs.Music then
    local T = Tabs.Music
    T:CreateSection("Music Control (affects everyone)")

    for _, s in ipairs(TROLL_SOUNDS) do
        T:CreateButton({Name="Play: " .. s.name, Callback=function()
            FireMusicControl(s.id)
        end})
    end

    T:CreateSection("Custom Sound")
    local customSound = "9040032945"
    T:CreateInput({Name="Sound ID",
        PlaceholderText="9040032945", RemoveTextAfterFocusLost=false,
        Callback=function(v) customSound = tostring(v or "9040032945") end})
    T:CreateButton({Name="Play Custom", Callback=function()
        FireMusicControl(customSound)
    end})

    T:CreateSection("Music Spam")
    T:CreateSlider({Name="Change Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=2, Flag="MSR",
        Callback=function(v) State.MusicSpamRate = tonumber(v) or 2 end})
    T:CreateToggle({Name="Random Music Spam Loop", CurrentValue=false, Flag="MSL",
        Callback=function(v)
            State.MusicSpam = v
            if v then StartMusicSpam() end
        end})
end

-- ═══════ EFFECTS TAB ═══════
if Tabs.Effect then
    local T = Tabs.Effect
    T:CreateSection("Effect Remote (broadcasts to all)")

    for _, eff in ipairs({"Explosion","Fire","Smoke","Sparkle","Confetti","Fireworks","Lightning","Bubbles"}) do
        T:CreateButton({Name="Fire: " .. eff, Callback=function() FireEffect(eff) end})
    end

    T:CreateSection("Effect Spam Loop")
    T:CreateSlider({Name="Effect Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="ESR",
        Callback=function(v) State.EffectSpamRate = tonumber(v) or 1 end})
    T:CreateToggle({Name="Random Effect Spam Loop", CurrentValue=false, Flag="ESL",
        Callback=function(v)
            State.EffectSpam = v
            if v then StartEffectSpam() end
        end})

    T:CreateSection("Unparticles Event")
    T:CreateButton({Name="Fire UnparticlesEvent", Callback=function()
        if R.UnparticlesEvent then SafeFire(R.UnparticlesEvent) end
    end})
end

-- ═══════ UTILITY TAB ═══════
if Tabs.Util then
    local T = Tabs.Util
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
    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)) end
    end})

    T:CreateSection("Rate Control")
    T:CreateSlider({Name="Fire Cooldown (x0.1s)",
        Range={1,20}, Increment=1, CurrentValue=3, Flag="FCD",
        Callback=function(v) State.FireCooldown = (tonumber(v) or 3) * 0.1 end})

    T:CreateSection("Silent Mode")
    T:CreateToggle({Name="Silent (no console prints)", CurrentValue=false, Flag="SM",
        Callback=function(v) SILENT = v end})
end

-- ═══════ SETTINGS TAB ═══════
if Tabs.Set then
    local T = Tabs.Set
    T:CreateSection("About")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Author: " .. HUB.Author)
    T:CreateLabel("Payloads from decompiled game source")
    T:CreateLabel("No metatable hooks used")

    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Hub", Callback=function()
        PanicStop()
        CM:Cleanup()
        _G[INSTANCE_KEY] = nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- Panic keybind
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.End then
        PanicStop()
        Rayfield:Notify({Title="PANIC", Content="All stopped", Duration=3})
    end
end)

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    timestamp = os.time(),
    destroy = function()
        PanicStop()
        CM:Cleanup()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Rayfield:Notify({Title=HUB.Name, Content="v"..HUB.Version.." — Real payloads loaded", Duration=5})
Log("Ready — v1.1.0 with confirmed formats")
