--═══════════════════════════════════════════════════════════════
-- X0DEC04T REST AREA TROLL HUB v1.2
--═══════════════════════════════════════════════════════════════

local LOGO_ASSET_ID = 132469099334813
local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local WS                = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local PS = LP:WaitForChild("PlayerScripts")

-- Executor shims
local genv = (getgenv and getgenv()) or _G
local fireproximityprompt = fireproximityprompt or genv.fireproximityprompt
local getconnections      = getconnections      or genv.getconnections
local hookmetamethod      = hookmetamethod      or genv.hookmetamethod
local getnamecallmethod   = getnamecallmethod   or genv.getnamecallmethod
local gethui              = gethui              or genv.gethui

local INSTANCE_KEY = "__X0DEC04T_REST_TROLL_v12"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY]=nil; task.wait(0.2) end

local function Log(m) print("[TROLL] "..tostring(m)) end
Log("Loading Rest Area Troll Hub v1.2...")

-- Known coordinates from your inspection
local COORDS = {
    GiftStation   = Vector3.new(107.379, 20.685, -191.165),
    LaporStation  = Vector3.new(-26.263, 20.893, -156.398),
    ATM           = Vector3.new(106.652, 27.725, -196.164),
    Donation      = Vector3.new(-89.725, 30.131, -29.738),
    Shop1         = Vector3.new(187.588, 30.897, -203.959),
    RodShop       = Vector3.new(44.540, 19.175, -178.162),
    Shop2         = Vector3.new(68.030, 22.464, -192.302),
}

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTI-KICK
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
task.spawn(function()
    local kickScript = PS:FindFirstChild("kick")
    if kickScript then
        pcall(function() kickScript.Disabled = true end)
        pcall(function() kickScript:Destroy() end)
        Log("Disabled PlayerScripts.kick")
    end
    if typeof(hookmetamethod) == "function" then
        local ok = pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod and getnamecallmethod() or ""
                if method == "Kick" and typeof(self) == "Instance" and self:IsA("Player") then
                    Log("Blocked Kick on "..tostring(self.Name))
                    return
                end
                return oldNamecall(self, ...)
            end)
        end)
        if ok then Log("Kick namecall hooked") end
    end
end)

local function safeCB(fn)
    if not fn then return function() end end
    return function(...)
        local a = table.pack(...)
        task.defer(function()
            local ok, err = pcall(function() fn(table.unpack(a, 1, a.n)) end)
            if not ok then Log("CB err: "..tostring(err)) end
        end)
    end
end

local WindUI
local wOk = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not wOk or not WindUI then warn("[TROLL] WindUI failed"); return end

local HUB = {Name="REST AREA TROLL", Version="1.2"}
local CM = {_list={}}
function CM:Add(sig, cb)
    if not sig then return end
    local ok, c = pcall(function() return sig:Connect(cb) end)
    if ok and c then table.insert(self._list, c); return c end
end
function CM:Cleanup()
    for _, c in ipairs(self._list) do pcall(function() c:Disconnect() end) end
    self._list = {}
end

local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end
local function GetChar() return LP.Character end
local function GetHRP() local c=GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c=GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end

local function TPTo(pos)
    local hrp = GetHRP(); if not hrp then return false end
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
    return true
end

local function TPBackAfter(savedCF, seconds)
    task.delay(seconds or 0.5, function()
        local hrp = GetHRP()
        if hrp and savedCF then pcall(function() hrp.CFrame = savedCF end) end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTE CACHE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = {}
local function loadRemotes()
    local gr = RS:FindFirstChild("GiftCoinRemotes")
    Remotes.SendGift        = gr and gr:FindFirstChild("SendGift")
    Remotes.GiftNotify      = gr and gr:FindFirstChild("GiftNotify")
    Remotes.OpenGiftUI      = gr and gr:FindFirstChild("OpenGiftUI")
    Remotes.GetOnlinePlayers = gr and gr:FindFirstChild("GetOnlinePlayers")

    local am = RS:FindFirstChild("AdminRemotes")
    Remotes.ModifyCoins   = am and am:FindFirstChild("ModifyCoins")
    Remotes.GetCoins      = am and am:FindFirstChild("GetCoins")
    Remotes.GetPlayerList = am and am:FindFirstChild("GetPlayerList")

    Remotes.Radio          = RS:FindFirstChild("radi0")
    Remotes.Piano          = WS:FindFirstChild("GlobalPianoConnector")
    Remotes.GlobalAnnounce = RS:FindFirstChild("GlobalAnnouncementEvent")
    Remotes.Confession     = RS:FindFirstChild("ConfessionEvent")
    Remotes.ConfessionLike = RS:FindFirstChild("ConfessionLikeEvent")
    Remotes.KirimLaporan   = RS:FindFirstChild("KirimLaporan")
    Remotes.KickEvent      = RS:FindFirstChild("KickEvent")

    local fs = RS:FindFirstChild("FishingSystem")
    Remotes.FishGiver = fs and fs:FindFirstChild("FishGiver")
    Remotes.SellFish  = fs and fs:FindFirstChild("SellFish")
    if fs then
        local ie = fs:FindFirstChild("InventoryEvents")
        Remotes.SellAllFish = ie and ie:FindFirstChild("Inventory_SellAll")
        Remotes.InventoryGetData = ie and ie:FindFirstChild("Inventory_GetData")
    end

    local hd = RS:FindFirstChild("HDAdminHDClient")
    local hdSigs = hd and hd:FindFirstChild("Signals")
    if hdSigs then
        Remotes.RequestCommand        = hdSigs:FindFirstChild("RequestCommand")
        Remotes.RequestCommandSilent  = hdSigs:FindFirstChild("RequestCommandSilent")
        Remotes.ExecuteBroadcast      = hdSigs:FindFirstChild("ExecuteBroadcast")
        Remotes.ExecuteAlert          = hdSigs:FindFirstChild("ExecuteAlert")
        Remotes.ForceChat             = hdSigs:FindFirstChild("ForceChat")
        Remotes.ForceBubbleChat       = hdSigs:FindFirstChild("ForceBubbleChat")
        Remotes.SystemMessage         = hdSigs:FindFirstChild("SystemMessage")
        Remotes.CreateAlert           = hdSigs:FindFirstChild("CreateAlert")
        Remotes.CreateBanMenu         = hdSigs:FindFirstChild("CreateBanMenu")
        Remotes.UpdateIceBlock        = hdSigs:FindFirstChild("UpdateIceBlock")
        Remotes.BecomeControlled      = hdSigs:FindFirstChild("BecomeControlled")
    end
    Log("Remotes cached")
end
loadRemotes()

local function tryFire(remote, ...)
    if not remote then return false, "no remote" end
    local args = table.pack(...)
    local ok, err
    if remote:IsA("RemoteEvent") then
        ok, err = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
    elseif remote:IsA("RemoteFunction") then
        ok, err = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
    end
    return ok, err
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TARGET
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Target = {Player=nil, Name="None"}
local function GetPlayerList()
    local list = {"[ALL PLAYERS]"}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then table.insert(list, p.Name) end
    end
    return list
end
local function SetTarget(name)
    if name == "[ALL PLAYERS]" then Target.Player = "ALL"; Target.Name = "ALL"; return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then Target.Player = p; Target.Name = name; return end
    end
end
local function ForEachTarget(fn)
    if Target.Player == "ALL" then
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then fn(p) end end
    elseif Target.Player and Target.Player.Parent then
        fn(Target.Player)
    end
end
local function TargetName()
    if Target.Player == "ALL" then return "all"
    elseif Target.Player then return Target.Player.Name end
    return nil
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- HD ADMIN - try multiple prefixes (you're OWNER so must work)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HD_PREFIX = ";"  -- will be auto-detected
local HD_PREFIXES = {";", ":", "!", "/", "-", "."}

local function RunHDCommand(cmdBody)
    if not Remotes.RequestCommand then Log("no RequestCommand"); return end
    -- Try current prefix first
    local ok, res = tryFire(Remotes.RequestCommand, HD_PREFIX..cmdBody)
    Log("HD '"..HD_PREFIX..cmdBody.."' -> "..tostring(ok).." "..tostring(res))
    return ok, res
end

local function DetectHDPrefix()
    task.spawn(function()
        Log("Detecting HD prefix...")
        for _, pfx in ipairs(HD_PREFIXES) do
            local ok, res = tryFire(Remotes.RequestCommand, pfx.."jump me")
            Log(" try '"..pfx.."' -> "..tostring(ok).." "..tostring(res))
            if res == true or res == "ok" or (type(res) == "table" and (res.success or res.ok)) then
                HD_PREFIX = pfx
                Log("Detected HD prefix: "..pfx)
                return
            end
            task.wait(0.3)
        end
        -- Also try RequestCommandSilent
        if Remotes.RequestCommandSilent then
            for _, pfx in ipairs(HD_PREFIXES) do
                local ok, res = tryFire(Remotes.RequestCommandSilent, pfx.."jump me")
                Log(" silent '"..pfx.."' -> "..tostring(ok).." "..tostring(res))
                if res == true or res == "ok" then
                    HD_PREFIX = pfx
                    Remotes.RequestCommand = Remotes.RequestCommandSilent
                    Log("Detected via silent, prefix: "..pfx)
                    return
                end
                task.wait(0.3)
            end
        end
    end)
end
DetectHDPrefix()

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- TROLL ACTIONS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- GIFT SPAM (auto-TP to gift station!)
local giftSpam = false
local giftDelay = 1.0
local function GiftSpamLoop()
    task.spawn(function()
        local hrp = GetHRP()
        if not hrp then return end
        local savedCF = hrp.CFrame
        -- TP to gift station once
        TPTo(COORDS.GiftStation)
        task.wait(0.5)
        
        while giftSpam do
            ForEachTarget(function(p)
                tryFire(Remotes.SendGift, p, 1)
                tryFire(Remotes.SendGift, p.UserId, 1)
            end)
            task.wait(giftDelay) -- rate-limit safe
        end
        
        -- TP back
        local hrp2 = GetHRP()
        if hrp2 then pcall(function() hrp2.CFrame = savedCF end) end
    end)
end

-- OPEN GIFT UI ON TARGET (no rate limit? no distance check)
local giftUISpam = false
local function GiftUISpamLoop()
    task.spawn(function()
        while giftUISpam do
            ForEachTarget(function(p)
                tryFire(Remotes.OpenGiftUI, p)
                tryFire(Remotes.OpenGiftUI, p.Name)
                tryFire(Remotes.OpenGiftUI, p.UserId)
            end)
            task.wait(0.4)
        end
    end)
end

-- ALERT SPAM (HD Admin)
local alertSpam = false
local alertText = "You have been reported"
local function AlertSpamLoop()
    task.spawn(function()
        while alertSpam do
            local t = TargetName()
            if t then
                RunHDCommand("notif "..t.." "..alertText)
                RunHDCommand("hint "..alertText)
                RunHDCommand("m "..alertText)
            end
            task.wait(0.5)
        end
    end)
end

-- FORCE CHAT (HD Admin)
local function ForceChat(text)
    local t = TargetName()
    if t then
        RunHDCommand("forcechat "..t.." "..text)
        RunHDCommand("bubble "..t.." "..text)
        RunHDCommand("say "..t.." "..text)
    end
    -- Also try direct signals
    ForEachTarget(function(p)
        tryFire(Remotes.ForceChat, p, text)
        tryFire(Remotes.ForceBubbleChat, p, text)
    end)
end

-- GLOBAL ANNOUNCE
local announceSpam = false
local announceText = "X0DEC04T WAS HERE"
local function AnnounceOnce()
    tryFire(Remotes.GlobalAnnounce, announceText)
    tryFire(Remotes.GlobalAnnounce, {Message=announceText})
    tryFire(Remotes.SystemMessage, announceText)
    RunHDCommand("m "..announceText)
end
local function AnnounceSpamLoop()
    task.spawn(function()
        while announceSpam do
            AnnounceOnce()
            task.wait(0.5)
        end
    end)
end

-- RADIO
local function RadioPlay(soundId)
    local id = tonumber(soundId) or soundId
    tryFire(Remotes.Radio, id)
    tryFire(Remotes.Radio, "play", id)
    tryFire(Remotes.Radio, {Action="play", Id=id})
end
local function RadioStop()
    tryFire(Remotes.Radio, "stop")
    tryFire(Remotes.Radio, 0)
end

-- CONFESSION SPAM
local confSpam = false
local confText = "spammed"
local function ConfessionSpamLoop()
    task.spawn(function()
        while confSpam do
            tryFire(Remotes.Confession, confText)
            tryFire(Remotes.Confession, {Text=confText, Anonymous=true})
            task.wait(0.6)
        end
    end)
end

-- SEAT LOCK
local seatLockLoop = false
local function SeatLockLoop()
    task.spawn(function()
        while seatLockLoop do
            ForEachTarget(function(p)
                local ch = p.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hum then
                    for _, s in ipairs(WS:GetDescendants()) do
                        if (s:IsA("Seat") or s:IsA("VehicleSeat")) and not s.Occupant then
                            pcall(function() s:Sit(hum) end)
                            break
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)
end

-- PIANO SPAM
local pianoSpam = false
local function PianoSpamLoop()
    task.spawn(function()
        while pianoSpam do
            for i = 1, 25 do
                tryFire(Remotes.Piano, i, true)
            end
            task.wait(0.15)
        end
    end)
end

-- FAKE BAN
local function FakeBan(reason)
    local t = TargetName()
    if t then RunHDCommand("banmenu "..t.." "..reason) end
    ForEachTarget(function(p)
        tryFire(Remotes.CreateBanMenu, p, {Reason=reason, Duration="Permanent", Moderator="System"})
    end)
end

-- FREEZE (HD Admin)
local function Freeze()
    local t = TargetName(); if not t then return end
    RunHDCommand("freeze "..t)
    RunHDCommand("ice "..t)
end
local function Thaw()
    local t = TargetName(); if not t then return end
    RunHDCommand("thaw "..t)
    RunHDCommand("unfreeze "..t)
end

-- LAPORAN SPAM (with TP)
local laporSpam = false
local function LaporSpamLoop()
    task.spawn(function()
        local hrp = GetHRP(); if not hrp then return end
        local savedCF = hrp.CFrame
        TPTo(COORDS.LaporStation); task.wait(0.5)
        while laporSpam do
            ForEachTarget(function(p)
                tryFire(Remotes.KirimLaporan, p, "spam", "Exploiting")
                tryFire(Remotes.KirimLaporan, {Target=p, Reason="troll"})
                tryFire(Remotes.KirimLaporan, p.Name, "spam")
            end)
            task.wait(0.8)
        end
        local hrp2 = GetHRP(); if hrp2 then pcall(function() hrp2.CFrame = savedCF end) end
    end)
end

-- FISH GIVER (self)
local function GiveFish(fishName, amount)
    amount = amount or 10
    for i = 1, amount do
        tryFire(Remotes.FishGiver, fishName)
        tryFire(Remotes.FishGiver, fishName, 1)
        tryFire(Remotes.FishGiver, {Name=fishName, Amount=1})
    end
end

local function SellAllFish()
    local ok, res = tryFire(Remotes.SellAllFish)
    Log("SellAll -> "..tostring(ok).." "..tostring(res))
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- SELF
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local State = {Speed=16, Jump=50, Fly=false, Noclip=false, AntiAFK=true, GodMode=false}

local noclipConn
local function Noclip(on)
    if noclipConn then noclipConn:Disconnect(); noclipConn=nil end
    if on then
        noclipConn = RunService.Stepped:Connect(function()
            local ch = GetChar(); if not ch then return end
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end)
    end
end

local flyBv, flyBg, flyConn
local function Fly(on)
    if flyBv then flyBv:Destroy(); flyBv=nil end
    if flyBg then flyBg:Destroy(); flyBg=nil end
    if flyConn then flyConn:Disconnect(); flyConn=nil end
    local hrp = GetHRP(); if not hrp then return end
    if on then
        flyBv = Instance.new("BodyVelocity")
        flyBv.MaxForce = Vector3.new(1,1,1)*1e5
        flyBv.Velocity = Vector3.zero
        flyBv.Parent = hrp
        flyBg = Instance.new("BodyGyro")
        flyBg.MaxTorque = Vector3.new(1,1,1)*1e5
        flyBg.P = 1e4
        flyBg.CFrame = hrp.CFrame
        flyBg.Parent = hrp
        flyConn = RunService.RenderStepped:Connect(function()
            if not flyBv or not flyBv.Parent then return end
            local cam = WS.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0,1,0) end
            flyBv.Velocity = dir * 60
            flyBg.CFrame = cam.CFrame
        end)
    end
end

CM:Add(LP.Idled, function()
    if State.AntiAFK then
        pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end)
    end
end)

task.spawn(function()
    while task.wait(1) do
        if State.GodMode then
            local h = GetHum()
            if h then pcall(function() h.MaxHealth=math.huge; h.Health=math.huge end) end
        end
    end
end)

CM:Add(LP.CharacterAdded, function()
    task.wait(1)
    if State.Speed ~= 16 then local h=GetHum(); if h then h.WalkSpeed=State.Speed end end
    if State.Jump ~= 50 then local h=GetHum(); if h then h.JumpPower=State.Jump end end
    if State.Noclip then Noclip(true) end
    if State.Fly then Fly(true) end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI (no emoji anywhere)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Window = WindUI:CreateWindow({
    Title=HUB.Name, Icon="skull", Author="v"..HUB.Version,
    Folder="X0DEC04T_TROLL", Size=UDim2.fromOffset(620,490),
    Transparent=true, Theme="Dark", SideBarWidth=170, HasOutline=true
})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t,Content=c,Duration=d or 4,Icon="info"}) end) end

local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui")
    logoGui.Name="TrollLogo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton")
    btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0,20,0.5,-30)
    btn.BackgroundTransparency=1; btn.AutoButtonColor=false
    btn.Image="rbxassetid://"..tostring(LOGO_ASSET_ID); btn.ScaleType=Enum.ScaleType.Fit
    btn.Active=true; btn.Draggable=true; btn.Parent=logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled=false end
        logoActive=false
        pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.wait(0.1)
        if logoActive then
            if logoGui then logoGui.Enabled=false end
            logoActive=false
            pcall(function() Window:Open() end)
        else
            if logoGui then logoGui.Enabled=true end
            logoActive=true
            pcall(function() Window:Close() end)
        end
    end
end)

local Tabs = {
    Target   = Window:Tab({Title="Target",       Icon="target"}),
    Troll    = Window:Tab({Title="Troll",        Icon="skull"}),
    Chat     = Window:Tab({Title="Chat",         Icon="message-circle"}),
    Sound    = Window:Tab({Title="Sound",        Icon="music"}),
    Self     = Window:Tab({Title="Self",         Icon="user"}),
    HDAdmin  = Window:Tab({Title="HD Admin",     Icon="shield"}),
    Fish     = Window:Tab({Title="Fish",         Icon="fish"}),
    Settings = Window:Tab({Title="Settings",     Icon="settings"}),
}
Window:SelectTab(1)

-- TARGET TAB
Tabs.Target:Section({Title="Select Target"})
local plrDropdown = Tabs.Target:Dropdown({
    Title="Player", Values=GetPlayerList(), Value="[ALL PLAYERS]",
    Callback=safeCB(SetTarget)
})
Tabs.Target:Button({Title="Refresh Player List", Callback=safeCB(function()
    pcall(function() plrDropdown:Refresh(GetPlayerList()) end)
    Notify("Target", "List refreshed", 2)
end)})
SetTarget("[ALL PLAYERS]")

Players.PlayerAdded:Connect(function()
    task.wait(1); pcall(function() plrDropdown:Refresh(GetPlayerList()) end)
end)
Players.PlayerRemoving:Connect(function()
    task.wait(1); pcall(function() plrDropdown:Refresh(GetPlayerList()) end)
end)

Tabs.Target:Paragraph({
    Title="Info",
    Desc="[ALL PLAYERS] affects everyone in server.\nSpecific player affects only them.\nYou are HD Admin OWNER = full command access."
})

-- TROLL TAB
Tabs.Troll:Section({Title="Gift Spam (auto-TP to station)"})
Tabs.Troll:Slider({Title="Gift Delay (seconds)", Value={Min=0.5,Max=3,Default=1}, Step=0.1, Callback=safeCB(function(v) giftDelay=v end)})
Tabs.Troll:Toggle({Title="Gift Spam Coins", Default=false, Callback=safeCB(function(v) giftSpam=v; if v then GiftSpamLoop() end end)})
Tabs.Troll:Toggle({Title="Open Gift UI Spam (no TP needed)", Default=false, Callback=safeCB(function(v) giftUISpam=v; if v then GiftUISpamLoop() end end)})

Tabs.Troll:Section({Title="Alert / Ban Screen"})
Tabs.Troll:Input({Title="Alert Text", Value="You have been reported", Callback=safeCB(function(v) alertText=v end)})
Tabs.Troll:Toggle({Title="Alert Spam", Default=false, Callback=safeCB(function(v) alertSpam=v; if v then AlertSpamLoop() end end)})
Tabs.Troll:Button({Title="Send Fake Ban Screen", Callback=safeCB(function()
    FakeBan("Banned for exploiting"); Notify("Fake Ban","Sent to "..Target.Name,3)
end)})

Tabs.Troll:Section({Title="Seat Lock / Freeze"})
Tabs.Troll:Toggle({Title="Force Seat Lock", Default=false, Callback=safeCB(function(v) seatLockLoop=v; if v then SeatLockLoop() end end)})
Tabs.Troll:Button({Title="Freeze Target", Callback=safeCB(function() Freeze(); Notify("Freeze","froze "..Target.Name,3) end)})
Tabs.Troll:Button({Title="Thaw Target", Callback=safeCB(function() Thaw(); Notify("Thaw","thawed",3) end)})

Tabs.Troll:Section({Title="Report / Confession"})
Tabs.Troll:Toggle({Title="Laporan Spam (auto-TP)", Default=false, Callback=safeCB(function(v) laporSpam=v; if v then LaporSpamLoop() end end)})
Tabs.Troll:Input({Title="Confession Text", Value="spammed", Callback=safeCB(function(v) confText=v end)})
Tabs.Troll:Toggle({Title="Confession Spam", Default=false, Callback=safeCB(function(v) confSpam=v; if v then ConfessionSpamLoop() end end)})

-- CHAT TAB
Tabs.Chat:Section({Title="Force Target Chat"})
local forceChatText = "I love X0DEC04T"
Tabs.Chat:Input({Title="Text to force", Value="I love X0DEC04T", Callback=safeCB(function(v) forceChatText=v end)})
Tabs.Chat:Button({Title="Force Target Chat", Callback=safeCB(function() ForceChat(forceChatText); Notify("Chat","sent",3) end)})

Tabs.Chat:Section({Title="Global Announcement"})
Tabs.Chat:Input({Title="Text", Value="X0DEC04T WAS HERE", Callback=safeCB(function(v) announceText=v end)})
Tabs.Chat:Button({Title="Send One Global Announce", Callback=safeCB(function() AnnounceOnce(); Notify("Announce","sent",3) end)})
Tabs.Chat:Toggle({Title="Announce Spam Loop", Default=false, Callback=safeCB(function(v) announceSpam=v; if v then AnnounceSpamLoop() end end)})

-- SOUND TAB
Tabs.Sound:Section({Title="Radio Hijack (server-wide)"})
local radioId = "142376088"
Tabs.Sound:Input({Title="Sound ID", Value="142376088", Callback=safeCB(function(v) radioId=v end)})
Tabs.Sound:Button({Title="Play on Radio", Callback=safeCB(function() RadioPlay(radioId); Notify("Radio","playing "..radioId,3) end)})
Tabs.Sound:Button({Title="Stop Radio", Callback=safeCB(RadioStop)})

Tabs.Sound:Section({Title="Piano"})
Tabs.Sound:Toggle({Title="Piano Note Spam", Default=false, Callback=safeCB(function(v) pianoSpam=v; if v then PianoSpamLoop() end end)})

-- SELF TAB
Tabs.Self:Section({Title="Movement"})
Tabs.Self:Slider({Title="Walk Speed", Value={Min=16,Max=300,Default=16}, Step=4, Callback=safeCB(function(v)
    State.Speed=v; local h=GetHum(); if h then pcall(function() h.WalkSpeed=v end) end
end)})
Tabs.Self:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v)
    State.Jump=v; local h=GetHum(); if h then pcall(function() h.JumpPower=v end) end
end)})
Tabs.Self:Toggle({Title="Fly (WASD+Space+Ctrl)", Default=false, Callback=safeCB(function(v) State.Fly=v; Fly(v) end)})
Tabs.Self:Toggle({Title="Noclip", Default=false, Callback=safeCB(function(v) State.Noclip=v; Noclip(v) end)})

Tabs.Self:Section({Title="Protection"})
Tabs.Self:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Self:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

Tabs.Self:Section({Title="Info"})
Tabs.Self:Button({Title="Check My Coins", Callback=safeCB(function()
    local ok, c = tryFire(Remotes.GetCoins, LP)
    Notify("Coins", "OK:"..tostring(ok).." | "..tostring(c), 5)
end)})
Tabs.Self:Button({Title="Show HD Prefix", Callback=safeCB(function() Notify("HD Prefix", "Current: "..HD_PREFIX, 4) end)})

-- HD ADMIN TAB
Tabs.HDAdmin:Section({Title="Custom Command (uses detected prefix "..HD_PREFIX..")"})
local hdCmdInput = "kick playername"
Tabs.HDAdmin:Input({Title="Command (no prefix)", Value="kick playername", Callback=safeCB(function(v) hdCmdInput=v end)})
Tabs.HDAdmin:Button({Title="Execute", Callback=safeCB(function() RunHDCommand(hdCmdInput) end)})

Tabs.HDAdmin:Section({Title="Quick Commands on Target"})
local hdActions = {
    {"Kick", "kick"}, {"Ban", "ban"}, {"Fling", "fling"}, {"Kill", "kill"},
    {"Freeze", "freeze"}, {"Thaw", "thaw"}, {"Invisible", "invisible"}, {"Visible", "visible"},
    {"Blind", "blind"}, {"Sit", "sit"}, {"Stand", "stand"},
    {"Explode", "explode"}, {"Fire", "fire"}, {"Sparkles", "sparkles"},
    {"Smoke", "smoke"}, {"Jump", "jump"}, {"Punish", "punish"}, {"Unpunish", "unpunish"},
    {"Freefall", "freefall"}, {"Slap", "slap"},
}
for _, act in ipairs(hdActions) do
    Tabs.HDAdmin:Button({Title=act[1].." Target", Callback=safeCB(function()
        local t = TargetName()
        if t then RunHDCommand(act[2].." "..t) end
    end)})
end

-- FISH TAB
Tabs.Fish:Section({Title="Fish Cheats"})
Tabs.Fish:Button({Title="Sell All Fish", Callback=safeCB(SellAllFish)})
local fishName = "Salmon"
Tabs.Fish:Input({Title="Fish Name", Value="Salmon", Callback=safeCB(function(v) fishName=v end)})
Tabs.Fish:Button({Title="Try Give 10 Fish", Callback=safeCB(function() GiveFish(fishName, 10) end)})
Tabs.Fish:Button({Title="Try Give 100 Fish", Callback=safeCB(function() GiveFish(fishName, 100) end)})

-- SETTINGS TAB
Tabs.Settings:Button({Title="Minimize (RightShift)", Callback=safeCB(function()
    pcall(function() Window:Close() end); task.wait(0.2)
    if logoGui then logoGui.Enabled=true end
    logoActive=true
end)})
Tabs.Settings:Button({Title="PANIC (stop all spam loops)", Callback=safeCB(function()
    giftSpam=false; giftUISpam=false; alertSpam=false; announceSpam=false
    confSpam=false; seatLockLoop=false; pianoSpam=false; laporSpam=false
    RadioStop()
    Notify("PANIC","All stopped",4)
end)})
Tabs.Settings:Button({Title="Reload Remotes", Callback=safeCB(function() loadRemotes(); Notify("Reloaded","remotes cached",2) end)})
Tabs.Settings:Button({Title="Re-detect HD Prefix", Callback=safeCB(DetectHDPrefix)})
Tabs.Settings:Button({Title="Unload Hub", Callback=safeCB(function()
    giftSpam=false; giftUISpam=false; alertSpam=false; announceSpam=false
    confSpam=false; seatLockLoop=false; pianoSpam=false; laporSpam=false
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

_G[INSTANCE_KEY] = {version=HUB.Version, destroy=function()
    giftSpam=false; giftUISpam=false; alertSpam=false; announceSpam=false
    confSpam=false; seatLockLoop=false; pianoSpam=false; laporSpam=false
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup()
    pcall(function() Window:Destroy() end)
end}

Log("Rest Area Troll Hub v1.2 READY")
Log("You are HD Admin OWNER - all commands should work")
