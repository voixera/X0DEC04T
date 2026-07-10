--═══════════════════════════════════════════════════════════════
-- X0DEC04T REST AREA TROLL HUB v1.0
--═══════════════════════════════════════════════════════════════

local LOGO_ASSET_ID = 132469099334813
local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local WS                = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")
local TweenService      = game:GetService("TweenService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local PS = LP:WaitForChild("PlayerScripts")

local INSTANCE_KEY = "__X0DEC04T_REST_TROLL_v1"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY]=nil; task.wait(0.2) end

local function Log(m) print("[TROLL] "..tostring(m)) end
Log("Loading Rest Area Troll Hub v1.0...")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 🛡️ ANTI-CHEAT KILL (must run FIRST)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
task.spawn(function()
    -- Disable the client kick script
    local kickScript = PS:FindFirstChild("kick")
    if kickScript and kickScript:IsA("LocalScript") then
        pcall(function() kickScript.Disabled = true end)
        pcall(function() kickScript:Destroy() end)
        Log("✓ Disabled PlayerScripts.kick")
    end
    
    -- Block Kick calls
    local mt = getrawmetatable(game)
    pcall(function() setreadonly(mt, false) end)
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and self:IsA("Player") then
            Log("✋ Blocked Kick call on "..self.Name)
            return
        end
        return oldNamecall(self, ...)
    end)
    pcall(function() setreadonly(mt, true) end)
    Log("✓ Kick namecall blocked")
end)

local function safeCB(fn) if not fn then return function() end end; return function(...) local a=table.pack(...); task.defer(function() local ok,err=pcall(function() fn(table.unpack(a,1,a.n)) end); if not ok then Log("CB err: "..tostring(err)) end end) end end

local WindUI; local ok = pcall(function() WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))() end)
if not ok or not WindUI then warn("[TROLL] WindUI failed"); return end

local HUB = {Name="REST AREA TROLL", Version="1.0"}
local CM = {_list={}}
function CM:Add(sig,cb) if not sig then return end; local ok,c=pcall(function() return sig:Connect(cb) end); if ok and c then table.insert(self._list,c); return c end end
function CM:Cleanup() for _,c in ipairs(self._list) do pcall(function() c:Disconnect() end) end; self._list={} end

local function GuiParent() local p=CoreGui; pcall(function() if gethui then p=gethui() end end); return p end
local function GetChar() return LP.Character end
local function GetHRP() local c=GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c=GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 📡 REMOTE CACHE
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = {}
local function loadRemotes()
    Remotes.SendGift        = RS:FindFirstChild("GiftCoinRemotes") and RS.GiftCoinRemotes:FindFirstChild("SendGift")
    Remotes.GiftNotify      = RS:FindFirstChild("GiftCoinRemotes") and RS.GiftCoinRemotes:FindFirstChild("GiftNotify")
    Remotes.OpenGiftUI      = RS:FindFirstChild("GiftCoinRemotes") and RS.GiftCoinRemotes:FindFirstChild("OpenGiftUI")
    Remotes.ModifyCoins     = RS:FindFirstChild("AdminRemotes") and RS.AdminRemotes:FindFirstChild("ModifyCoins")
    Remotes.GetCoins        = RS:FindFirstChild("AdminRemotes") and RS.AdminRemotes:FindFirstChild("GetCoins")
    Remotes.Radio           = RS:FindFirstChild("radi0")
    Remotes.Piano           = WS:FindFirstChild("GlobalPianoConnector")
    Remotes.GlobalAnnounce  = RS:FindFirstChild("GlobalAnnouncementEvent")
    Remotes.Confession      = RS:FindFirstChild("ConfessionEvent")
    Remotes.ConfessionLike  = RS:FindFirstChild("ConfessionLikeEvent")
    Remotes.KirimLaporan    = RS:FindFirstChild("KirimLaporan")
    Remotes.SellFish        = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("SellFish")
    Remotes.SellAllFish     = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("InventoryEvents") and RS.FishingSystem.InventoryEvents:FindFirstChild("Inventory_SellAll")
    Remotes.FishGiver       = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("FishGiver")
    Remotes.FishCaught      = RS:FindFirstChild("FishingSystem") and RS.FishingSystem:FindFirstChild("FishCaught")
    Remotes.PurchaseLuck    = RS:FindFirstChild("PurchaseLuckBoost")
    -- HD Admin
    local hdSigs = RS:FindFirstChild("HDAdminHDClient") and RS.HDAdminHDClient:FindFirstChild("Signals")
    if hdSigs then
        Remotes.RequestCommand       = hdSigs:FindFirstChild("RequestCommand")
        Remotes.RequestCommandSilent = hdSigs:FindFirstChild("RequestCommandSilent")
        Remotes.ExecuteBroadcast     = hdSigs:FindFirstChild("ExecuteBroadcast")
        Remotes.ExecuteAlert         = hdSigs:FindFirstChild("ExecuteAlert")
        Remotes.ExecutePoll          = hdSigs:FindFirstChild("ExecutePoll")
        Remotes.Notice               = hdSigs:FindFirstChild("Notice")
        Remotes.Message              = hdSigs:FindFirstChild("Message")
        Remotes.Hint                 = hdSigs:FindFirstChild("Hint")
        Remotes.ShowWarning          = hdSigs:FindFirstChild("ShowWarning")
        Remotes.ForceChat            = hdSigs:FindFirstChild("ForceChat")
        Remotes.ForceBubbleChat      = hdSigs:FindFirstChild("ForceBubbleChat")
        Remotes.SystemMessage        = hdSigs:FindFirstChild("SystemMessage")
        Remotes.CreateAlert          = hdSigs:FindFirstChild("CreateAlert")
        Remotes.CreatePollMenu       = hdSigs:FindFirstChild("CreatePollMenu")
        Remotes.CreateBanMenu        = hdSigs:FindFirstChild("CreateBanMenu")
        Remotes.PlaySoundInstance    = hdSigs:FindFirstChild("PlaySoundInstance")
        Remotes.UpdateIceBlock       = hdSigs:FindFirstChild("UpdateIceBlock")
        Remotes.BecomeControlled     = hdSigs:FindFirstChild("BecomeControlled")
    end
    Log("✓ Remotes cached")
end
loadRemotes()

local function tryFire(remote, ...)
    if not remote then return false, "no remote" end
    local ok, err
    if remote:IsA("RemoteEvent") then
        ok, err = pcall(function() remote:FireServer(...) end)
    elseif remote:IsA("RemoteFunction") then
        ok, err = pcall(function() return remote:InvokeServer(...) end)
    end
    return ok, err
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 👥 TARGET MANAGER
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

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 🎭 TROLL ACTIONS
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 1. GIFT SPAM (opens gift UI on target constantly)
local giftSpam = false
local function GiftSpamLoop()
    task.spawn(function()
        while giftSpam do
            ForEachTarget(function(p)
                if Remotes.SendGift then
                    tryFire(Remotes.SendGift, p, 1, "coin")
                    tryFire(Remotes.SendGift, p.UserId, 1)
                    tryFire(Remotes.SendGift, p.Name, 1)
                end
                if Remotes.OpenGiftUI then
                    tryFire(Remotes.OpenGiftUI, p)
                end
            end)
            task.wait(0.3)
        end
    end)
end

-- 2. FAKE ALERT SPAM
local alertSpam = false
local alertText = "You have been reported!"
local function AlertSpamLoop()
    task.spawn(function()
        while alertSpam do
            ForEachTarget(function(p)
                for _, r in ipairs({Remotes.CreateAlert, Remotes.ExecuteAlert, Remotes.Notice, Remotes.Message, Remotes.ShowWarning}) do
                    tryFire(r, p, alertText, "REST AREA MODERATION")
                    tryFire(r, {p}, alertText)
                    tryFire(r, alertText, p)
                end
            end)
            task.wait(0.5)
        end
    end)
end

-- 3. FORCE CHAT
local function ForceChatTarget(text)
    ForEachTarget(function(p)
        for _, r in ipairs({Remotes.ForceChat, Remotes.ForceBubbleChat}) do
            tryFire(r, p, text)
            tryFire(r, {p}, text)
            tryFire(r, p.Name, text)
        end
    end)
end

-- 4. GLOBAL ANNOUNCEMENT SPAM
local announceSpam = false
local announceText = "X0DEC04T WAS HERE 😈"
local function AnnounceSpamLoop()
    task.spawn(function()
        while announceSpam do
            tryFire(Remotes.GlobalAnnounce, announceText)
            tryFire(Remotes.GlobalAnnounce, {Message=announceText})
            tryFire(Remotes.SystemMessage, announceText)
            task.wait(0.4)
        end
    end)
end

-- 5. RADIO HIJACK
local function RadioPlay(soundId)
    local id = tonumber(soundId) or soundId
    tryFire(Remotes.Radio, id)
    tryFire(Remotes.Radio, "play", id)
    tryFire(Remotes.Radio, {Action="play", Id=id})
end
local function RadioStop()
    tryFire(Remotes.Radio, "stop")
    tryFire(Remotes.Radio, 0)
    tryFire(Remotes.Radio, nil)
end

-- 6. CONFESSION SPAM
local confSpam = false
local confText = "spammed by X0DEC04T"
local function ConfessionSpamLoop()
    task.spawn(function()
        while confSpam do
            tryFire(Remotes.Confession, confText)
            tryFire(Remotes.Confession, {Text=confText, Anonymous=true})
            task.wait(0.5)
        end
    end)
end

-- 7. COIN FARM (self)
local function GrindCoins(amount)
    amount = amount or 999999
    if not Remotes.ModifyCoins then Log("no ModifyCoins"); return end
    local ok, res = tryFire(Remotes.ModifyCoins, LP, amount)
    Log("ModifyCoins →"..tostring(ok).." "..tostring(res))
    local ok2, res2 = tryFire(Remotes.ModifyCoins, LP.UserId, amount)
    Log("ModifyCoins UserId →"..tostring(ok2).." "..tostring(res2))
    local ok3, res3 = tryFire(Remotes.ModifyCoins, amount)
    Log("ModifyCoins int →"..tostring(ok3).." "..tostring(res3))
end

-- 8. SEAT LOCK (force target into a seat, they can't leave)
local seatLockLoop = false
local function SeatLockLoop()
    task.spawn(function()
        while seatLockLoop do
            ForEachTarget(function(p)
                local ch = p.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hum then
                    -- Find any seat
                    for _, s in ipairs(WS:GetDescendants()) do
                        if s:IsA("Seat") or s:IsA("VehicleSeat") then
                            if not s.Occupant then
                                pcall(function() s:Sit(hum) end)
                                break
                            end
                        end
                    end
                end
            end)
            task.wait(0.15)
        end
    end)
end

-- 9. PIANO SPAM (loud note server-wide)
local pianoSpam = false
local function PianoSpamLoop()
    task.spawn(function()
        while pianoSpam do
            for i = 1, 25 do
                tryFire(Remotes.Piano, i, true)
                tryFire(Remotes.Piano, "play", i)
            end
            task.wait(0.1)
        end
    end)
end

-- 10. FAKE BAN SCREEN
local function FakeBan(reason)
    ForEachTarget(function(p)
        tryFire(Remotes.CreateBanMenu, p, {Reason=reason or "You have been banned", Duration="Permanent", Moderator="System"})
        tryFire(Remotes.CreateBanMenu, {p}, reason)
        tryFire(Remotes.CreateBanMenu, p, reason)
    end)
end

-- 11. FREEZE (ice block)
local function IceFreeze(state)
    ForEachTarget(function(p)
        tryFire(Remotes.UpdateIceBlock, p, state)
        tryFire(Remotes.UpdateIceBlock, {Player=p, State=state})
    end)
end

-- 12. LAPORAN SPAM (report system)
local laporSpam = false
local function LaporSpamLoop()
    task.spawn(function()
        while laporSpam do
            ForEachTarget(function(p)
                tryFire(Remotes.KirimLaporan, p, "spam by X0DEC04T", "Exploiting")
                tryFire(Remotes.KirimLaporan, {Target=p, Reason="troll"})
            end)
            task.wait(0.4)
        end
    end)
end

-- 13. HD ADMIN COMMAND
local function RunHDCommand(cmdText)
    if not Remotes.RequestCommand then return end
    local ok, res = tryFire(Remotes.RequestCommand, cmdText)
    Log("HD cmd '"..cmdText.."' → "..tostring(ok).." "..tostring(res))
end

-- 14. SELL ALL FISH
local function SellAllFish()
    if not Remotes.SellAllFish then Log("no SellAllFish"); return end
    local ok, res = tryFire(Remotes.SellAllFish)
    Log("SellAllFish → "..tostring(ok).." "..tostring(res))
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- 🚀 SELF FEATURES
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
    if flyBv then flyBv:Destroy() end; if flyBg then flyBg:Destroy() end
    if flyConn then flyConn:Disconnect() end
    local hrp = GetHRP(); if not hrp then return end
    if on then
        flyBv = Instance.new("BodyVelocity"); flyBv.MaxForce = Vector3.new(1,1,1)*1e5; flyBv.Velocity = Vector3.zero; flyBv.Parent = hrp
        flyBg = Instance.new("BodyGyro"); flyBg.MaxTorque = Vector3.new(1,1,1)*1e5; flyBg.P = 1e4; flyBg.CFrame = hrp.CFrame; flyBg.Parent = hrp
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
-- 🖥️ UI
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Window = WindUI:CreateWindow({Title=HUB.Name, Icon="skull", Author="v"..HUB.Version, Folder="X0DEC04T_TROLL", Size=UDim2.fromOffset(600,480), Transparent=true, Theme="Dark", SideBarWidth=170, HasOutline=true})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded 😈", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t,Content=c,Duration=d or 4,Icon="info"}) end) end

-- Logo minimize
local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui"); logoGui.Name="TrollLogo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton")
    btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0,20,0.5,-30); btn.BackgroundTransparency=1
    btn.AutoButtonColor=false; btn.Image="rbxassetid://"..tostring(LOGO_ASSET_ID); btn.ScaleType=Enum.ScaleType.Fit
    btn.Active=true; btn.Draggable=true; btn.Parent=logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled=false end; logoActive=false; pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.wait(0.1)
        if logoActive then if logoGui then logoGui.Enabled=false end; logoActive=false; pcall(function() Window:Open() end)
        else if logoGui then logoGui.Enabled=true end; logoActive=true; pcall(function() Window:Close() end) end
    end
end)

local Tabs = {
    Target   = Window:Tab({Title="🎯 Target",   Icon="target"}),
    Troll    = Window:Tab({Title="😈 Troll",    Icon="skull"}),
    Chat     = Window:Tab({Title="💬 Chat/Msg", Icon="message-circle"}),
    Sound    = Window:Tab({Title="🎵 Sound",    Icon="music"}),
    Self     = Window:Tab({Title="⚡ Self",     Icon="user"}),
    HDAdmin  = Window:Tab({Title="🛡 HD Cmds",  Icon="shield"}),
    Settings = Window:Tab({Title="⚙ Settings",  Icon="settings"}),
}
Window:SelectTab(1)

-- TARGET TAB
Tabs.Target:Section({Title="Select Target"})
local plrDropdown = Tabs.Target:Dropdown({Title="Player", Values=GetPlayerList(), Value="[ALL PLAYERS]", Callback=safeCB(SetTarget)})
Tabs.Target:Button({Title="🔄 Refresh Player List", Callback=safeCB(function()
    pcall(function() plrDropdown:Refresh(GetPlayerList()) end)
    Notify("Target", "List refreshed", 2)
end)})
SetTarget("[ALL PLAYERS]")

Players.PlayerAdded:Connect(function() task.wait(1); pcall(function() plrDropdown:Refresh(GetPlayerList()) end) end)
Players.PlayerRemoving:Connect(function() task.wait(1); pcall(function() plrDropdown:Refresh(GetPlayerList()) end) end)

Tabs.Target:Paragraph({Title="Current Target", Desc="Selected: "..Target.Name.."\n\n[ALL PLAYERS] = affects everyone in server\nSpecific player = affects only them"})

-- TROLL TAB
Tabs.Troll:Section({Title="🎁 Gift & Alert Spam"})
Tabs.Troll:Toggle({Title="Gift Spam (open UI + send gifts)", Default=false, Callback=safeCB(function(v) giftSpam=v; if v then GiftSpamLoop() end end)})
Tabs.Troll:Input({Title="Alert Text", Value="You have been reported!", Callback=safeCB(function(v) alertText=v end)})
Tabs.Troll:Toggle({Title="Alert Spam", Default=false, Callback=safeCB(function(v) alertSpam=v; if v then AlertSpamLoop() end end)})
Tabs.Troll:Button({Title="⚠️ Send FAKE BAN Screen", Callback=safeCB(function() FakeBan("Banned for exploiting - X0DEC04T"); Notify("Fake Ban", "Sent to "..Target.Name, 3) end)})

Tabs.Troll:Section({Title="🪑 Seat & Freeze"})
Tabs.Troll:Toggle({Title="Force Seat Lock (spam sit)", Default=false, Callback=safeCB(function(v) seatLockLoop=v; if v then SeatLockLoop() end end)})
Tabs.Troll:Button({Title="🥶 Freeze Target (Ice)", Callback=safeCB(function() IceFreeze(true); Notify("Freeze","frozen "..Target.Name,3) end)})
Tabs.Troll:Button({Title="🔥 Unfreeze Target", Callback=safeCB(function() IceFreeze(false) end)})

Tabs.Troll:Section({Title="📢 Report / Confession"})
Tabs.Troll:Toggle({Title="Laporan (Report) Spam", Default=false, Callback=safeCB(function(v) laporSpam=v; if v then LaporSpamLoop() end end)})
Tabs.Troll:Input({Title="Confession Text", Value="spammed by X0DEC04T", Callback=safeCB(function(v) confText=v end)})
Tabs.Troll:Toggle({Title="Confession Spam", Default=false, Callback=safeCB(function(v) confSpam=v; if v then ConfessionSpamLoop() end end)})

-- CHAT/MSG TAB
Tabs.Chat:Section({Title="💬 Force Chat (make target say things)"})
local forceChatText = "I love X0DEC04T"
Tabs.Chat:Input({Title="Text to force", Value="I love X0DEC04T", Callback=safeCB(function(v) forceChatText=v end)})
Tabs.Chat:Button({Title="Force Target to Say It (Chat)", Callback=safeCB(function() ForceChatTarget(forceChatText); Notify("ForceChat","sent",3) end)})
Tabs.Chat:Button({Title="Force Target Bubble Chat", Callback=safeCB(function()
    ForEachTarget(function(p)
        tryFire(Remotes.ForceBubbleChat, p, forceChatText)
        tryFire(Remotes.ForceBubbleChat, {p}, forceChatText)
    end)
end)})

Tabs.Chat:Section({Title="📣 Global Announcement"})
Tabs.Chat:Input({Title="Announce Text", Value="X0DEC04T WAS HERE 😈", Callback=safeCB(function(v) announceText=v end)})
Tabs.Chat:Button({Title="📣 Send ONE Global Announcement", Callback=safeCB(function()
    tryFire(Remotes.GlobalAnnounce, announceText)
    tryFire(Remotes.SystemMessage, announceText)
    Notify("Announce","sent globally",3)
end)})
Tabs.Chat:Toggle({Title="Announce SPAM (loop)", Default=false, Callback=safeCB(function(v) announceSpam=v; if v then AnnounceSpamLoop() end end)})

-- SOUND TAB
Tabs.Sound:Section({Title="🎵 Radio Hijack"})
local radioId = "142376088"
Tabs.Sound:Input({Title="Sound ID (Roblox asset ID)", Value="142376088", Callback=safeCB(function(v) radioId=v end)})
Tabs.Sound:Button({Title="▶ Play on Radio (server-wide)", Callback=safeCB(function() RadioPlay(radioId); Notify("Radio","playing "..radioId,3) end)})
Tabs.Sound:Button({Title="⏹ Stop Radio", Callback=safeCB(RadioStop)})

Tabs.Sound:Section({Title="🎹 Piano Spam"})
Tabs.Sound:Toggle({Title="Piano Note SPAM", Default=false, Callback=safeCB(function(v) pianoSpam=v; if v then PianoSpamLoop() end end)})

-- SELF TAB
Tabs.Self:Section({Title="Movement"})
Tabs.Self:Slider({Title="Walk Speed", Value={Min=16,Max=300,Default=16}, Step=4, Callback=safeCB(function(v) State.Speed=v; local h=GetHum(); if h then pcall(function() h.WalkSpeed=v end) end end)})
Tabs.Self:Slider({Title="Jump Power", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v) State.Jump=v; local h=GetHum(); if h then pcall(function() h.JumpPower=v end) end end)})
Tabs.Self:Toggle({Title="Fly (WASD+Space+Ctrl)", Default=false, Callback=safeCB(function(v) State.Fly=v; Fly(v) end)})
Tabs.Self:Toggle({Title="Noclip", Default=false, Callback=safeCB(function(v) State.Noclip=v; Noclip(v) end)})

Tabs.Self:Section({Title="Protection"})
Tabs.Self:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Self:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

Tabs.Self:Section({Title="💰 Coin & Fish Exploits"})
Tabs.Self:Button({Title="💰 Give 999,999 Coins (via ModifyCoins)", Callback=safeCB(function() GrindCoins(999999) end)})
Tabs.Self:Button({Title="💰 Give 1,000,000,000 Coins", Callback=safeCB(function() GrindCoins(1000000000) end)})
Tabs.Self:Button({Title="🎣 Sell All Fish (instant)", Callback=safeCB(SellAllFish)})
Tabs.Self:Button({Title="📊 Check My Coins", Callback=safeCB(function()
    local ok, c = tryFire(Remotes.GetCoins, LP)
    Notify("Coins", tostring(c), 4)
end)})

-- HD ADMIN COMMANDS TAB
Tabs.HDAdmin:Section({Title="Try HD Admin Commands (may need rank)"})
local hdCmdInput = ";kick "
Tabs.HDAdmin:Input({Title="Command (with ; prefix)", Value=";kick playername", Callback=safeCB(function(v) hdCmdInput=v end)})
Tabs.HDAdmin:Button({Title="▶ Execute", Callback=safeCB(function() RunHDCommand(hdCmdInput) end)})

Tabs.HDAdmin:Section({Title="Quick Commands (targets selected player)"})
local hdActions = {
    {"Kick", ";kick"}, {"Ban", ";ban"}, {"Fling", ";fling"}, {"Kill", ";kill"},
    {"Freeze", ";freeze"}, {"Thaw", ";thaw"}, {"Invisible", ";invisible"},
    {"Blind", ";blind"}, {"Confuse", ";confuse"}, {"Sit", ";sit"},
    {"Explode", ";explode"}, {"Fire", ";fire"}, {"Sparkles", ";sparkles"},
    {"Smoke", ";smoke"}, {"Jump", ";jump"}, {"Punish", ";punish"},
}
for _, act in ipairs(hdActions) do
    Tabs.HDAdmin:Button({Title=act[1].." Target", Callback=safeCB(function()
        if Target.Player == "ALL" then RunHDCommand(act[2].." all")
        elseif Target.Player then RunHDCommand(act[2].." "..Target.Player.Name) end
    end)})
end

-- SETTINGS
Tabs.Settings:Button({Title="Minimize (RightShift)", Callback=safeCB(function()
    pcall(function() Window:Close() end); task.wait(0.2)
    if logoGui then logoGui.Enabled=true end; logoActive=true
end)})
Tabs.Settings:Button({Title="🛑 PANIC (stop all spams)", Callback=safeCB(function()
    giftSpam=false; alertSpam=false; announceSpam=false; confSpam=false
    seatLockLoop=false; pianoSpam=false; laporSpam=false
    RadioStop()
    Notify("PANIC","All spams stopped",4)
end)})
Tabs.Settings:Button({Title="🔄 Reload Remotes", Callback=safeCB(function() loadRemotes(); Notify("Reloaded","remotes",2) end)})
Tabs.Settings:Button({Title="❌ Unload Hub", Callback=safeCB(function()
    giftSpam=false; alertSpam=false; announceSpam=false; confSpam=false
    seatLockLoop=false; pianoSpam=false; laporSpam=false
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

_G[INSTANCE_KEY] = {version=HUB.Version, destroy=function()
    giftSpam=false; alertSpam=false; announceSpam=false; confSpam=false
    seatLockLoop=false; pianoSpam=false; laporSpam=false
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); pcall(function() Window:Destroy() end)
end}

Log("Rest Area Troll Hub v1.0 READY 😈")
