--═══════════════════════════════════════════════════════════════
-- X0DEC04T Bunker Troll Hub v1.0.0
-- Place ID: 133943904733338
-- NO metatable hooks. NO namecall detection triggers.
-- All actions = SERVER-SIDE broadcast (affects everyone)
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

local INSTANCE_KEY = "__X0DEC04T_BUNKER_v100_INSTANCE"
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

Log("Loading Bunker Troll Hub v1.0.0")

-- Mandatory warm-up delay
local READY = false
task.spawn(function()
    task.wait(2.5)
    READY = true
    Log("Ready to fire remotes")
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
    Game = "Bunker Party",
    Version = "1.0.0",
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

-- REMOTES MAP
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local function GR(path)
    local cur = ReplicatedStorage
    for part in string.gmatch(path, "[^.]+") do
        if not cur then return nil end
        cur = cur:FindFirstChild(part)
    end
    return cur
end

local R = {
    -- Core (broadcasts)
    EffectRemote      = GR("Remotes.Core.EffectRemote"),
    ShowAnnouncement  = GR("Remotes.Core.ShowAnnouncement"),
    ShowNotification  = GR("Remotes.Core.ShowNotification"),
    SyncBroadcast     = GR("Remotes.Core.SyncBroadcast"),
    RequestSync       = GR("Remotes.Core.RequestSync"),
    LatencyPing       = GR("Remotes.Core.LatencyPing"),

    -- Music
    MusicControl      = GR("Remotes.Music.MusicControlEvent"),
    MusicControlAlt   = GR("Music.Remotes.MusicControlEvent"),

    -- Animation
    UpdateAnimation   = GR("Remotes.Animation.UpdateAnimation"),
    SaveFavorites     = GR("Remotes.Animation.SaveFavorites"),
    AnimSync          = GR("network.AnimationSync.UpdateSync"),

    -- Carry (potentially force-carry others)
    CarryRemote       = GR("Remotes.Carry.CarryRemote"),
    CarryRemoteAlt    = GR("CarryReplic.CarryRemotes.CarryRemote"),

    -- Colors
    SetColor          = GR("Remotes.ColorPicker.SetColor"),
    ColorChanged      = GR("Remotes.ColorPicker.ColorChanged"),

    -- Effects
    UnparticlesEvent  = GR("EffectRemotes.UnparticlesEvent"),

    -- Admin (probably auth-locked but let's test)
    AdminCommand      = GR("Remotes.Admin.AdminCommand"),
    CommandEvent      = GR("Remotes.Command.CommandEvent"),
    SendAnnouncement  = GR("Remotes.Admin.SendAnnouncement"),
    LookupPlayer      = GR("Remotes.Admin.LookupPlayer"),

    -- Info gathering
    GetStaffList      = GR("Remotes.Admin.GetStaffList"),
    GetSocialStats    = GR("Remotes.Avatar.GetSocialStats"),
    GetTotalDonation  = GR("Remotes.Donation.GetTotalDonation"),
    CheckCommandAccess= GR("Remotes.Shop.CheckCommandAccess"),

    -- Donation abuse
    SubmitDonation    = GR("Remotes.Donation.SubmitDonationMessage"),
    PromptDonation    = GR("Remotes.Donation.PromptDonationMessage"),
}

Log("EffectRemote: " .. (R.EffectRemote and "YES" or "NO"))
Log("MusicControl: " .. (R.MusicControl and "YES" or "NO"))
Log("UpdateAnimation: " .. (R.UpdateAnimation and "YES" or "NO"))
Log("CarryRemote: " .. (R.CarryRemote and "YES" or "NO"))

-- STATE
local State = {
    -- Rate limit
    LastFireTime=0, FireCooldown=0.3,

    -- Troll loops
    EffectSpam=false, EffectSpamRate=0.5, EffectSpamPayload="Random",
    MusicSpam=false, MusicSpamRate=1, MusicSpamId="9040032945",
    AnnouncementSpam=false, AnnouncementSpamRate=2, AnnouncementSpamText="TROLLED",
    NotificationSpam=false, NotificationSpamRate=1.5, NotificationSpamText="X0DEC04T",
    ForceAnimSpam=false, ForceAnimRate=1, ForceAnimId="rbxassetid://507770239",
    ColorSpamAll=false, ColorSpamRate=0.5,
    CarrySpam=false, CarrySpamTarget="",

    -- Loops
    EffectSpamThread=nil,
    MusicSpamThread=nil,
    AnnouncementSpamThread=nil,
    NotificationSpamThread=nil,
    ForceAnimSpamThread=nil,
    ColorSpamThread=nil,
    CarrySpamThread=nil,

    -- Utility
    AntiAFK=true, AutoRejoin=false,

    -- Stats
    FiresSent=0,
}

-- ═══════════════════════════════════════════
-- SAFE FIRE (no metatable, just pcall + rate limit)
-- ═══════════════════════════════════════════
local function SafeFire(remote, ...)
    if not remote then return false, "nil remote" end
    if not READY then return false, "not ready" end

    -- Rate limit
    local now = tick()
    local wait_needed = State.FireCooldown - (now - State.LastFireTime)
    if wait_needed > 0 then task.wait(wait_needed) end
    State.LastFireTime = tick()

    local args = table.pack(...)
    local ok, err = pcall(function()
        if remote:IsA("RemoteEvent") then
            remote:FireServer(table.unpack(args, 1, args.n))
        elseif remote:IsA("RemoteFunction") then
            remote:InvokeServer(table.unpack(args, 1, args.n))
        end
    end)
    if ok then State.FiresSent = State.FiresSent + 1 end
    return ok, err
end

-- Jitter for human-like timing
local function Jitter(base) return base * (0.85 + math.random() * 0.30) end

-- ═══════════════════════════════════════════
-- TROLL 1: EFFECT SPAM (broadcasts visual effects to all)
-- ═══════════════════════════════════════════
local EFFECT_PAYLOADS = {
    -- try various formats to see what works
    "Explosion", "Fire", "Smoke", "Sparkle", "Confetti", "Rainbow",
    "Fireworks", "Lightning", "Bubbles",
    {Type="Explosion"}, {Type="Fire"}, {effect="explosion"},
    {name="explosion"}, {Effect="Boom"},
}

local function FireEffect(customPayload)
    if not R.EffectRemote then return end
    local payload = customPayload
    if State.EffectSpamPayload == "Random" and not customPayload then
        payload = EFFECT_PAYLOADS[math.random(#EFFECT_PAYLOADS)]
    elseif not customPayload then
        payload = State.EffectSpamPayload
    end

    -- Try firing with player position
    local ch = LocalPlayer.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local pos = hrp and hrp.Position or Vector3.new(0, 10, 0)

    -- Try multiple formats
    SafeFire(R.EffectRemote, payload)
    task.wait(0.05)
    SafeFire(R.EffectRemote, payload, pos)
    task.wait(0.05)
    SafeFire(R.EffectRemote, payload, LocalPlayer)
end

local function StartEffectSpam()
    if State.EffectSpamThread then return end
    State.EffectSpamThread = task.spawn(function()
        while State.EffectSpam do
            FireEffect()
            task.wait(Jitter(State.EffectSpamRate))
        end
        State.EffectSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 2: MUSIC SPAM (changes music for everyone)
-- ═══════════════════════════════════════════
local function FireMusic(soundId)
    local id = soundId or State.MusicSpamId
    -- Try formats
    local payloads = {
        {"Play", id},
        {"play", id},
        {id},
        {"SetSong", id},
        {{action="Play", id=id}},
        {"Change", id},
        {"Queue", id},
        {"Skip"},
    }
    for _, p in ipairs(payloads) do
        if R.MusicControl then SafeFire(R.MusicControl, table.unpack(p)) end
        task.wait(0.05)
        if R.MusicControlAlt then SafeFire(R.MusicControlAlt, table.unpack(p)) end
        task.wait(0.05)
    end
end

local function StartMusicSpam()
    if State.MusicSpamThread then return end
    State.MusicSpamThread = task.spawn(function()
        while State.MusicSpam do
            FireMusic()
            task.wait(Jitter(State.MusicSpamRate))
        end
        State.MusicSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 3: ANNOUNCEMENT SPAM
-- ═══════════════════════════════════════════
local function FireAnnouncement(text)
    text = text or State.AnnouncementSpamText
    if R.ShowAnnouncement then
        SafeFire(R.ShowAnnouncement, text)
        SafeFire(R.ShowAnnouncement, text, LocalPlayer.Name)
        SafeFire(R.ShowAnnouncement, text, 10)  -- with duration
        SafeFire(R.ShowAnnouncement, {message=text})
        SafeFire(R.ShowAnnouncement, {text=text, sender=LocalPlayer.Name})
    end
    if R.SendAnnouncement then
        SafeFire(R.SendAnnouncement, text)
    end
end

local function StartAnnouncementSpam()
    if State.AnnouncementSpamThread then return end
    State.AnnouncementSpamThread = task.spawn(function()
        while State.AnnouncementSpam do
            FireAnnouncement(State.AnnouncementSpamText .. " " .. math.random(1000,9999))
            task.wait(Jitter(State.AnnouncementSpamRate))
        end
        State.AnnouncementSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 4: NOTIFICATION SPAM
-- ═══════════════════════════════════════════
local function FireNotification(text)
    text = text or State.NotificationSpamText
    if R.ShowNotification then
        SafeFire(R.ShowNotification, text)
        SafeFire(R.ShowNotification, text, "info")
        SafeFire(R.ShowNotification, text, 5)
        SafeFire(R.ShowNotification, {message=text})
        SafeFire(R.ShowNotification, {title="X0DEC04T", text=text})
    end
end

local function StartNotificationSpam()
    if State.NotificationSpamThread then return end
    State.NotificationSpamThread = task.spawn(function()
        while State.NotificationSpam do
            FireNotification(State.NotificationSpamText .. " " .. math.random(1000,9999))
            task.wait(Jitter(State.NotificationSpamRate))
        end
        State.NotificationSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 5: FORCE ANIMATION ON SELF (visible to all)
-- ═══════════════════════════════════════════
local FUNNY_ANIMS = {
    "rbxassetid://507770239",  -- caveman
    "rbxassetid://507770453",  -- default
    "rbxassetid://507771019",  -- fart
    "rbxassetid://507776043",  -- monster
    "rbxassetid://507776663",  -- ninja
    "rbxassetid://507777268",  -- pirate
    "rbxassetid://507777268",  -- robot
    "rbxassetid://507777823",  -- superhero
    "rbxassetid://507778133",  -- werewolf
    "rbxassetid://507778381",  -- zombie
    "rbxassetid://517110198",  -- bear
    "rbxassetid://11333281100",-- twerk
    "rbxassetid://12669802779",-- griddy
}

local function FireForceAnim(animId)
    animId = animId or State.ForceAnimId
    if State.ForceAnimId == "Random" then
        animId = FUNNY_ANIMS[math.random(#FUNNY_ANIMS)]
    end
    if R.UpdateAnimation then
        SafeFire(R.UpdateAnimation, animId)
        SafeFire(R.UpdateAnimation, animId, "walk")
        SafeFire(R.UpdateAnimation, {id=animId, type="walk"})
        SafeFire(R.UpdateAnimation, {animId=animId})
    end
    if R.AnimSync then
        SafeFire(R.AnimSync, animId)
    end
end

local function StartForceAnimSpam()
    if State.ForceAnimSpamThread then return end
    State.ForceAnimSpamThread = task.spawn(function()
        while State.ForceAnimSpam do
            FireForceAnim()
            task.wait(Jitter(State.ForceAnimRate))
        end
        State.ForceAnimSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 6: COLOR SPAM (change your color rapidly)
-- ═══════════════════════════════════════════
local function FireColorRandom()
    if not R.SetColor then return end
    local c = Color3.fromHSV(math.random(), 1, 1)
    SafeFire(R.SetColor, c)
    SafeFire(R.SetColor, c, LocalPlayer)
    SafeFire(R.SetColor, "Head", c)
    SafeFire(R.SetColor, "Torso", c)
end

local function StartColorSpam()
    if State.ColorSpamThread then return end
    State.ColorSpamThread = task.spawn(function()
        while State.ColorSpamAll do
            FireColorRandom()
            task.wait(Jitter(State.ColorSpamRate))
        end
        State.ColorSpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 7: FORCE CARRY (try to force-carry others)
-- ═══════════════════════════════════════════
local function FireForceCarry(targetName)
    if not R.CarryRemote then return end
    local target = Players:FindFirstChild(targetName)
    if not target then return end

    -- Try formats
    SafeFire(R.CarryRemote, "Carry", target)
    SafeFire(R.CarryRemote, target)
    SafeFire(R.CarryRemote, target.Name)
    SafeFire(R.CarryRemote, "Start", target)
    SafeFire(R.CarryRemote, "Request", target)
    SafeFire(R.CarryRemote, {action="Carry", target=target.Name})

    if R.CarryRemoteAlt then
        SafeFire(R.CarryRemoteAlt, "Carry", target)
        SafeFire(R.CarryRemoteAlt, target)
    end
end

local function StartCarrySpam()
    if State.CarrySpamThread then return end
    State.CarrySpamThread = task.spawn(function()
        while State.CarrySpam do
            FireForceCarry(State.CarrySpamTarget)
            task.wait(0.5)
        end
        State.CarrySpamThread = nil
    end)
end

-- ═══════════════════════════════════════════
-- TROLL 8: DONATION SPAM (spawn donation popups)
-- ═══════════════════════════════════════════
local function FireDonationSpam(text)
    text = text or ("X0DEC04T " .. math.random(1000,9999))
    if R.SubmitDonation then
        SafeFire(R.SubmitDonation, text)
        SafeFire(R.SubmitDonation, {message=text, amount=1})
        SafeFire(R.SubmitDonation, text, 100)
    end
    if R.PromptDonation then
        SafeFire(R.PromptDonation, text)
    end
end

-- ═══════════════════════════════════════════
-- TROLL 9: UNPARTICLES EVENT (particle grief)
-- ═══════════════════════════════════════════
local function FireUnparticles()
    if not R.UnparticlesEvent then return end
    SafeFire(R.UnparticlesEvent)
    SafeFire(R.UnparticlesEvent, LocalPlayer)
    SafeFire(R.UnparticlesEvent, true)
end

-- ═══════════════════════════════════════════
-- ADMIN PROBE (try to fire admin commands)
-- ═══════════════════════════════════════════
local function TryAdminCommand(cmd, arg)
    if R.AdminCommand then
        SafeFire(R.AdminCommand, cmd, arg)
        SafeFire(R.AdminCommand, cmd .. " " .. tostring(arg))
        SafeFire(R.AdminCommand, {command=cmd, arg=arg})
    end
    if R.CommandEvent then
        SafeFire(R.CommandEvent, cmd, arg)
        SafeFire(R.CommandEvent, cmd .. " " .. tostring(arg))
    end
end

-- ═══════════════════════════════════════════
-- INFO GATHERING
-- ═══════════════════════════════════════════
local function CheckMyCommandAccess()
    if not R.CheckCommandAccess then return "no remote" end
    local ok, res = pcall(function() return R.CheckCommandAccess:InvokeServer() end)
    return ok and tostring(res) or "err"
end

local function GetStaffList()
    if not R.GetStaffList then return end
    SafeFire(R.GetStaffList)
    -- Response comes through StaffListResult event
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

-- Listen to admin responses (info only, no hook)
if R.LookupPlayer then
    local resultRemote = GR("Remotes.Admin.LookupPlayerResult")
    if resultRemote then
        CM:Add(resultRemote.OnClientEvent, function(...)
            Log("LookupResult: " .. table.concat({tostring(...)}, " | "))
        end)
    end
end

if R.GetStaffList then
    local resultRemote = GR("Remotes.Admin.StaffListResult")
    if resultRemote then
        CM:Add(resultRemote.OnClientEvent, function(...)
            local args = {...}
            Log("Staff: " .. tostring(#args) .. " entries")
        end)
    end
end

-- ═══════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════
local Window = Rayfield:CreateWindow({
    Name = HUB.Name .. " v" .. HUB.Version,
    LoadingTitle = HUB.Name,
    LoadingSubtitle = "Bunker Party Griefer",
    Theme = "DarkBlue",
    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,
})

local Tabs = {}
for _, def in ipairs({
    {key="Main",     name="Main",       icon="home"},
    {key="Broadcast",name="Broadcasts", icon="megaphone"},
    {key="Music",    name="Music Troll",icon="music"},
    {key="Effects",  name="Effects",    icon="sparkles"},
    {key="Animation",name="Anim Troll", icon="user"},
    {key="Colors",   name="Colors",     icon="palette"},
    {key="Carry",    name="Force Carry",icon="users"},
    {key="Admin",    name="Admin Probe",icon="shield-alert"},
    {key="Utility",  name="Utility",    icon="wrench"},
    {key="Settings", name="Settings",   icon="settings"},
}) do
    local ok, tab = pcall(function() return Window:CreateTab(def.name, def.icon) end)
    if ok and tab then Tabs[def.key] = tab end
end

-- MAIN
if Tabs.Main then
    local T = Tabs.Main
    T:CreateSection("Info")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Game: Bunker Party (PID " .. HUB.PlaceId .. ")")
    T:CreateLabel("Mode: Pure remote firing, no hooks")

    T:CreateSection("Remote Status")
    T:CreateLabel("EffectRemote: " .. (R.EffectRemote and "Y" or "N"))
    T:CreateLabel("MusicControl: " .. (R.MusicControl and "Y" or "N"))
    T:CreateLabel("ShowAnnouncement: " .. (R.ShowAnnouncement and "Y" or "N"))
    T:CreateLabel("UpdateAnimation: " .. (R.UpdateAnimation and "Y" or "N"))
    T:CreateLabel("CarryRemote: " .. (R.CarryRemote and "Y" or "N"))
    T:CreateLabel("SetColor: " .. (R.SetColor and "Y" or "N"))

    T:CreateSection("Test Buttons")
    T:CreateButton({Name="Test EffectRemote (once)", Callback=function()
        FireEffect()
        Rayfield:Notify({Title="Effect", Content="Fired", Duration=3})
    end})
    T:CreateButton({Name="Test ShowAnnouncement (once)", Callback=function()
        FireAnnouncement("X0DEC04T Test")
        Rayfield:Notify({Title="Announce", Content="Fired", Duration=3})
    end})
    T:CreateButton({Name="Test MusicControl (once)", Callback=function()
        FireMusic()
        Rayfield:Notify({Title="Music", Content="Fired", Duration=3})
    end})
    T:CreateButton({Name="Check My Command Access", Callback=function()
        local res = CheckMyCommandAccess()
        Rayfield:Notify({Title="Access", Content=res, Duration=5})
    end})

    T:CreateSection("Keybinds")
    T:CreateLabel("End = PANIC stop all")

    T:CreateSection("Stats")
    T:CreateLabel("Fires sent: 0")

    T:CreateSection("Global Panic")
    T:CreateButton({Name="STOP ALL LOOPS", Callback=function()
        State.EffectSpam=false; State.MusicSpam=false
        State.AnnouncementSpam=false; State.NotificationSpam=false
        State.ForceAnimSpam=false; State.ColorSpamAll=false
        State.CarrySpam=false
        Rayfield:Notify({Title="PANIC", Content="Stopped everything", Duration=3})
    end})
end

-- BROADCASTS
if Tabs.Broadcast then
    local T = Tabs.Broadcast
    T:CreateSection("Announcement Spam (broadcasts to all)")

    T:CreateInput({Name="Announcement Text",
        PlaceholderText="X0DEC04T was here", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.AnnouncementSpamText = tostring(v or "TROLLED") end})

    T:CreateSlider({Name="Announcement Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=2, Flag="ASR",
        Callback=function(v) State.AnnouncementSpamRate = tonumber(v) or 2 end})

    T:CreateToggle({Name="Announcement Spam", CurrentValue=false, Flag="AS",
        Callback=function(v)
            State.AnnouncementSpam = v
            if v then StartAnnouncementSpam() end
        end})

    T:CreateButton({Name="Send Announcement Once", Callback=function()
        FireAnnouncement(State.AnnouncementSpamText)
    end})

    T:CreateSection("Notification Spam")

    T:CreateInput({Name="Notification Text",
        PlaceholderText="X0DEC04T", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.NotificationSpamText = tostring(v or "X0DEC04T") end})

    T:CreateSlider({Name="Notification Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=2, Flag="NSR",
        Callback=function(v) State.NotificationSpamRate = tonumber(v) or 2 end})

    T:CreateToggle({Name="Notification Spam", CurrentValue=false, Flag="NS",
        Callback=function(v)
            State.NotificationSpam = v
            if v then StartNotificationSpam() end
        end})
end

-- MUSIC TROLL
if Tabs.Music then
    local T = Tabs.Music
    T:CreateSection("Music Control (affects everyone)")

    T:CreateInput({Name="Sound Asset ID",
        PlaceholderText="9040032945", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.MusicSpamId = tostring(v or "9040032945") end})

    T:CreateSlider({Name="Music Change Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="MSR",
        Callback=function(v) State.MusicSpamRate = tonumber(v) or 1 end})

    T:CreateToggle({Name="Music Spam Loop", CurrentValue=false, Flag="MS",
        Callback=function(v)
            State.MusicSpam = v
            if v then StartMusicSpam() end
        end})

    T:CreateButton({Name="Change Music Once", Callback=function()
        FireMusic()
    end})

    T:CreateSection("Preset Troll Sounds")
    for _, preset in ipairs({
        {name="John Cena", id="9040032945"},
        {name="MLG Airhorn", id="130785000"},
        {name="Bass Boosted", id="1848354536"},
        {name="Emergency Alert", id="1839246711"},
        {name="Loud Beep", id="4590657391"},
    }) do
        T:CreateButton({Name="Play: " .. preset.name, Callback=function()
            State.MusicSpamId = preset.id
            FireMusic(preset.id)
        end})
    end
end

-- EFFECTS
if Tabs.Effects then
    local T = Tabs.Effects
    T:CreateSection("Effect Broadcast Spam")

    T:CreateDropdown({Name="Effect Type",
        Options={"Random","Explosion","Fire","Smoke","Sparkle","Confetti","Rainbow","Fireworks","Lightning","Bubbles"},
        CurrentOption={"Random"}, Flag="ET",
        Callback=function(v) State.EffectSpamPayload = (type(v)=="table" and v[1]) or v end})

    T:CreateSlider({Name="Effect Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="ER",
        Callback=function(v) State.EffectSpamRate = tonumber(v) or 1 end})

    T:CreateToggle({Name="Effect Spam Loop", CurrentValue=false, Flag="ES",
        Callback=function(v)
            State.EffectSpam = v
            if v then StartEffectSpam() end
        end})

    T:CreateButton({Name="Fire Effect Once", Callback=function() FireEffect() end})

    T:CreateSection("Particle/Unparticles Grief")
    T:CreateButton({Name="Fire UnparticlesEvent", Callback=FireUnparticles})
end

-- ANIMATION TROLL
if Tabs.Animation then
    local T = Tabs.Animation
    T:CreateSection("Force Animation on Self (visible to all)")

    T:CreateInput({Name="Animation ID",
        PlaceholderText="rbxassetid://11333281100 (twerk)", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.ForceAnimId = tostring(v or "rbxassetid://507770239") end})

    T:CreateSlider({Name="Animation Change Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="FAR",
        Callback=function(v) State.ForceAnimRate = tonumber(v) or 1 end})

    T:CreateToggle({Name="Force Anim Spam Loop", CurrentValue=false, Flag="FAS",
        Callback=function(v)
            State.ForceAnimSpam = v
            if v then StartForceAnimSpam() end
        end})

    T:CreateSection("Preset Funny Animations")
    for _, preset in ipairs({
        {name="Twerk", id="rbxassetid://11333281100"},
        {name="Griddy", id="rbxassetid://12669802779"},
        {name="Caveman", id="rbxassetid://507770239"},
        {name="Zombie", id="rbxassetid://507778381"},
        {name="Robot", id="rbxassetid://507777268"},
        {name="Werewolf", id="rbxassetid://507778133"},
    }) do
        T:CreateButton({Name="Play: " .. preset.name, Callback=function()
            State.ForceAnimId = preset.id
            FireForceAnim(preset.id)
        end})
    end

    T:CreateButton({Name="Random Anim", Callback=function()
        FireForceAnim(FUNNY_ANIMS[math.random(#FUNNY_ANIMS)])
    end})
end

-- COLORS
if Tabs.Colors then
    local T = Tabs.Colors
    T:CreateSection("Color Spam (rapid color changes)")

    T:CreateSlider({Name="Color Change Rate (seconds)",
        Range={1,10}, Increment=1, CurrentValue=1, Flag="CR",
        Callback=function(v) State.ColorSpamRate = (tonumber(v) or 1) * 0.5 end})

    T:CreateToggle({Name="Rainbow Color Spam", CurrentValue=false, Flag="CS",
        Callback=function(v)
            State.ColorSpamAll = v
            if v then StartColorSpam() end
        end})

    T:CreateButton({Name="Random Color Once", Callback=FireColorRandom})
end

-- FORCE CARRY
if Tabs.Carry then
    local T = Tabs.Carry
    T:CreateSection("Force Carry Player")
    T:CreateLabel("Attempts to carry them without consent")

    T:CreateInput({Name="Target Player Name",
        PlaceholderText="username", RemoveTextAfterFocusLost=false,
        Callback=function(v) State.CarrySpamTarget = tostring(v or "") end})

    T:CreateToggle({Name="Force Carry Loop", CurrentValue=false, Flag="FCL",
        Callback=function(v)
            State.CarrySpam = v
            if v then StartCarrySpam() end
        end})

    T:CreateButton({Name="Force Carry Once", Callback=function()
        if State.CarrySpamTarget == "" then
            Rayfield:Notify({Title="Carry", Content="Set target name first", Duration=3})
            return
        end
        FireForceCarry(State.CarrySpamTarget)
    end})
end

-- ADMIN PROBE
if Tabs.Admin then
    local T = Tabs.Admin
    T:CreateSection("Admin Command Probe")
    T:CreateLabel("Test if server validates admin properly")
    T:CreateLabel("Most likely won't work but worth trying")

    local probeCmd = ""
    local probeArg = ""

    T:CreateInput({Name="Command",
        PlaceholderText=":kick", RemoveTextAfterFocusLost=false,
        Callback=function(v) probeCmd = tostring(v or "") end})

    T:CreateInput({Name="Argument (playername or value)",
        PlaceholderText="playername", RemoveTextAfterFocusLost=false,
        Callback=function(v) probeArg = tostring(v or "") end})

    T:CreateButton({Name="Fire Admin Command", Callback=function()
        TryAdminCommand(probeCmd, probeArg)
        Rayfield:Notify({Title="Probe", Content="Fired " .. probeCmd, Duration=3})
    end})

    T:CreateSection("Info Gathering")
    T:CreateButton({Name="Get Staff List", Callback=GetStaffList})
    T:CreateButton({Name="Get My Total Donation", Callback=function()
        if R.GetTotalDonation then
            local ok, res = pcall(function() return R.GetTotalDonation:InvokeServer() end)
            Rayfield:Notify({Title="Donation", Content=tostring(res), Duration=5})
        end
    end})
    T:CreateButton({Name="Get Social Stats", Callback=function()
        if R.GetSocialStats then
            local ok, res = pcall(function() return R.GetSocialStats:InvokeServer(LocalPlayer) end)
            Log("Social: " .. tostring(res))
            Rayfield:Notify({Title="Social", Content="Printed to F9", Duration=3})
        end
    end})

    T:CreateSection("Donation Prompt Spam")
    T:CreateButton({Name="Send Donation Message", Callback=function()
        FireDonationSpam("X0DEC04T " .. math.random(1000,9999))
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

    T:CreateButton({Name="Copy Job ID", Callback=function()
        if setclipboard then setclipboard(tostring(game.JobId)); Rayfield:Notify({Title="Copied",Content="Job ID",Duration=2}) end
    end})

    T:CreateSection("Rate Limit Control")
    T:CreateSlider({Name="Fire Cooldown (x0.1s)",
        Range={1,20}, Increment=1, CurrentValue=3, Flag="FCD",
        Callback=function(v) State.FireCooldown = (tonumber(v) or 3) * 0.1 end})
    T:CreateLabel("Lower = faster but risker")
    T:CreateLabel("Default 0.3s = safe")

    T:CreateSection("Silent Mode")
    T:CreateToggle({Name="Silent (no prints)", CurrentValue=false, Flag="SM",
        Callback=function(v) SILENT = v end})
end

-- SETTINGS
if Tabs.Settings then
    local T = Tabs.Settings
    T:CreateSection("About")
    T:CreateLabel(HUB.Name .. " v" .. HUB.Version)
    T:CreateLabel("Author: " .. HUB.Author)
    T:CreateLabel("100% remote-fire based")
    T:CreateLabel("No metatable hooks, no detection triggers")

    T:CreateSection("Danger Zone")
    T:CreateButton({Name="Unload Hub", Callback=function()
        State.EffectSpam=false; State.MusicSpam=false
        State.AnnouncementSpam=false; State.NotificationSpam=false
        State.ForceAnimSpam=false; State.ColorSpamAll=false
        State.CarrySpam=false
        CM:Cleanup()
        _G[INSTANCE_KEY]=nil
        pcall(function() Rayfield:Destroy() end)
    end})
end

-- Panic keybind
CM:Add(UserInputService.InputBegan, function(inp, gpe)
    if gpe then return end
    if inp.KeyCode == Enum.KeyCode.End then
        State.EffectSpam=false; State.MusicSpam=false
        State.AnnouncementSpam=false; State.NotificationSpam=false
        State.ForceAnimSpam=false; State.ColorSpamAll=false
        State.CarrySpam=false
        Rayfield:Notify({Title="PANIC","Stopped all loops",Duration=3})
    end
end)

_G[INSTANCE_KEY] = {
    version=HUB.Version, timestamp=os.time(),
    destroy=function()
        State.EffectSpam=false; State.MusicSpam=false
        State.AnnouncementSpam=false; State.NotificationSpam=false
        State.ForceAnimSpam=false; State.ColorSpamAll=false
        State.CarrySpam=false
        CM:Cleanup()
        pcall(function() Rayfield:Destroy() end)
    end,
}

Rayfield:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded", Duration=5})
Log("Ready — Bunker troll hub loaded")
