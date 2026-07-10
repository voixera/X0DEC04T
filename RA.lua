--═══════════════════════════════════════════════════════════════
-- X0DEC04T REST AREA TROLL HUB v1.5 FINAL
-- CONFESSION BOARD H4CK - Precision Targeted
-- Uses confirmed path: Workspace.ConfessZell.MULAI MENULIS.ConfessionSurface.GridRoot
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

local genv = (getgenv and getgenv()) or _G
local fireproximityprompt = fireproximityprompt or genv.fireproximityprompt
local hookmetamethod      = hookmetamethod      or genv.hookmetamethod
local getnamecallmethod   = getnamecallmethod   or genv.getnamecallmethod
local gethui              = gethui              or genv.gethui

local INSTANCE_KEY = "__X0DEC04T_REST_TROLL_v15"
if _G[INSTANCE_KEY] then pcall(function() _G[INSTANCE_KEY].destroy() end); _G[INSTANCE_KEY]=nil; task.wait(0.2) end

local function Log(m) print("[TROLL] "..tostring(m)) end
Log("Loading Rest Area Troll Hub v1.5 FINAL...")

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ANTI-KICK
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
task.spawn(function()
    local kickScript = PS:FindFirstChild("kick")
    if kickScript then
        pcall(function() kickScript.Disabled = true end)
        pcall(function() kickScript:Destroy() end)
    end
    if typeof(hookmetamethod) == "function" then
        pcall(function()
            local oldNC
            oldNC = hookmetamethod(game, "__namecall", function(self, ...)
                local m = getnamecallmethod and getnamecallmethod() or ""
                if m == "Kick" and typeof(self) == "Instance" and self:IsA("Player") then
                    return
                end
                return oldNC(self, ...)
            end)
        end)
    end
end)

local function safeCB(fn)
    if not fn then return function() end end
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then Log("CB: "..tostring(err)) end
    end
end

local WindUI
local wOk = pcall(function()
    WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)
if not wOk or not WindUI then warn("[TROLL] WindUI failed"); return end

local HUB = {Name="REST AREA TROLL", Version="1.5"}
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
    pcall(function() hrp.CFrame = CFrame.new(pos + Vector3.new(0,3,0)) end)
    return true
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- REMOTES
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Remotes = {}
local function loadRemotes()
    local gr = RS:FindFirstChild("GiftCoinRemotes")
    Remotes.SendGift = gr and gr:FindFirstChild("SendGift")

    Remotes.Radio        = RS:FindFirstChild("radi0")
    Remotes.Piano        = WS:FindFirstChild("GlobalPianoConnector")
    Remotes.Confession   = RS:FindFirstChild("ConfessionEvent")
    Remotes.ConfLike     = RS:FindFirstChild("ConfessionLikeEvent")
    Remotes.KirimLaporan = RS:FindFirstChild("KirimLaporan")

    local fs = RS:FindFirstChild("FishingSystem")
    if fs then
        Remotes.FishGiver = fs:FindFirstChild("FishGiver")
        local ie = fs:FindFirstChild("InventoryEvents")
        Remotes.SellAllFish = ie and ie:FindFirstChild("Inventory_SellAll")
    end

    Remotes.FireworksToggle = RS:FindFirstChild("FireworksToggle")
    Remotes.UpdateSignEvent = RS:FindFirstChild("UpdateSignEvent")
    Remotes.TeleportRequest = RS:FindFirstChild("TeleportRequest")

    Remotes.RoseGift      = RS:FindFirstChild("RoseGiftEvents")
    Remotes.SunflowerGift = RS:FindFirstChild("SunflowerGiftEvents")
    Remotes.WhiteroseGift = RS:FindFirstChild("WhiteroseGiftEvents")
    Remotes.BungaGift     = RS:FindFirstChild("BungaGiftEvents")
    Remotes.BonekaGift    = RS:FindFirstChild("BonekaGiftEvents")

    local cr = RS:FindFirstChild("CarryRemotes")
    if cr then
        Remotes.CarryRequest  = cr:FindFirstChild("CarryRequest")
        Remotes.CarryResponse = cr:FindFirstChild("CarryResponse")
        Remotes.CarryEnd      = cr:FindFirstChild("CarryEnd")
    end

    local hd = RS:FindFirstChild("HDAdminHDClient")
    local hdSigs = hd and hd:FindFirstChild("Signals")
    if hdSigs then
        Remotes.RequestCommand = hdSigs:FindFirstChild("RequestCommand")
        Remotes.ForceChat      = hdSigs:FindFirstChild("ForceChat")
        Remotes.ForceBubble    = hdSigs:FindFirstChild("ForceBubbleChat")
    end

    Log("Remotes cached")
end
loadRemotes()

local function tryFire(remote, ...)
    if not remote then return false end
    local args = table.pack(...)
    local ok, res
    if remote:IsA("RemoteEvent") then
        ok, res = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
    elseif remote:IsA("RemoteFunction") then
        ok, res = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
    end
    return ok, res
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
    if name == "[ALL PLAYERS]" then Target.Player="ALL"; Target.Name="ALL"; return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == name then Target.Player=p; Target.Name=name; return end
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
-- HD ADMIN
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local HD_PREFIX = ";"
local function RunHD(cmd)
    if Remotes.RequestCommand then tryFire(Remotes.RequestCommand, HD_PREFIX..cmd) end
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- ★★★ CONFESSION BOARD H4CK (PRECISION TARGETED) ★★★
-- Confirmed path: Workspace.ConfessZell.MULAI MENULIS.ConfessionSurface.GridRoot
-- Each card = Frame named "Conf_<numbers>_<numbers>" inside GridRoot
-- First TextLabel in card = confession text
-- Second TextLabel = username (starts with "— ")
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ConfBoard = {
    gridRoot = nil,        -- The GridRoot frame containing all cards
    cards = {},            -- {[frame] = {textLabel=, userLabel=, likeBtn=, deleteBtn=, origText=, origUser=}}
    hackActive = false,
    hackText = "H4CKED BY X0DEC04T",
    replaceUsers = true,
    hackUser = "— X0DEC04T",
    clearActive = false,
    hideAllActive = false,
    scanDelay = 1.5,
}

function ConfBoard:FindGridRoot()
    -- Try direct path first (fast)
    local zell = WS:FindFirstChild("ConfessZell")
    if not zell then Log("ConfessZell not found"); return false end
    
    -- MULAI MENULIS or MULAI MENULIS1
    local wall = zell:FindFirstChild("MULAI MENULIS") or zell:FindFirstChild("MULAI MENULIS1")
    if not wall then
        -- fallback: search
        for _, ch in ipairs(zell:GetChildren()) do
            if ch.Name:upper():find("MULAI") or ch.Name:upper():find("MENULIS") then
                wall = ch; break
            end
        end
    end
    if not wall then Log("MULAI MENULIS wall not found"); return false end
    
    local sg = wall:FindFirstChild("ConfessionSurface")
    if not sg then
        -- Search for any SurfaceGui
        for _, ch in ipairs(wall:GetChildren()) do
            if ch:IsA("SurfaceGui") then sg = ch; break end
        end
    end
    if not sg then Log("ConfessionSurface not found"); return false end
    
    local grid = sg:FindFirstChild("GridRoot")
    if not grid then
        for _, ch in ipairs(sg:GetChildren()) do
            if ch:IsA("Frame") then grid = ch; break end
        end
    end
    if not grid then Log("GridRoot not found"); return false end
    
    self.gridRoot = grid
    Log("GridRoot found: "..grid:GetFullName())
    return true
end

function ConfBoard:IsCardFrame(obj)
    return obj and obj:IsA("Frame") and (obj.Name:find("^Conf_") ~= nil or obj.Name:find("^Confession") ~= nil)
end

function ConfBoard:ParseCard(cardFrame)
    -- Find text elements inside this card
    local data = {frame=cardFrame, textLabel=nil, userLabel=nil, likeBtn=nil, deleteBtn=nil}
    for _, d in ipairs(cardFrame:GetDescendants()) do
        if d:IsA("TextLabel") then
            local txt = d.Text or ""
            if not data.textLabel then
                data.textLabel = d
                data.origText = txt
            elseif not data.userLabel and (txt:sub(1,1) == "—" or txt:sub(1,1) == "-" or txt:sub(1,3) == "— ") then
                data.userLabel = d
                data.origUser = txt
            elseif not data.userLabel then
                -- Fallback: second textlabel is usually user
                data.userLabel = d
                data.origUser = txt
            end
        elseif d:IsA("TextButton") then
            local n = d.Name:lower()
            if n:find("delete") then
                data.deleteBtn = d
            elseif not data.likeBtn then
                data.likeBtn = d
            end
        end
    end
    return data
end

function ConfBoard:ScanCards()
    self.cards = {}
    if not self.gridRoot then return 0 end
    
    for _, child in ipairs(self.gridRoot:GetChildren()) do
        if self:IsCardFrame(child) then
            self.cards[child] = self:ParseCard(child)
        end
    end
    
    local count = 0
    for _ in pairs(self.cards) do count = count + 1 end
    Log("Scanned "..count.." cards")
    return count
end

function ConfBoard:ApplyToCard(cardData)
    if not cardData then return end
    pcall(function()
        if self.clearActive then
            -- Make card invisible
            if cardData.frame then
                cardData.frame.Visible = false
            end
        elseif self.hideAllActive then
            -- Hide text but keep frame
            if cardData.textLabel then cardData.textLabel.TextTransparency = 1 end
            if cardData.userLabel then cardData.userLabel.TextTransparency = 1 end
        else
            -- Replace text
            if cardData.textLabel then
                cardData.textLabel.Text = self.hackText
                cardData.textLabel.TextTransparency = 0
            end
            if self.replaceUsers and cardData.userLabel then
                cardData.userLabel.Text = self.hackUser
                cardData.userLabel.TextTransparency = 0
            end
            if cardData.frame then
                cardData.frame.Visible = true
            end
        end
    end)
end

function ConfBoard:ApplyAll()
    local n = 0
    for _, data in pairs(self.cards) do
        self:ApplyToCard(data)
        n = n + 1
    end
    return n
end

function ConfBoard:RestoreAll()
    for _, data in pairs(self.cards) do
        pcall(function()
            if data.textLabel and data.origText then
                data.textLabel.Text = data.origText
                data.textLabel.TextTransparency = 0
            end
            if data.userLabel and data.origUser then
                data.userLabel.Text = data.origUser
                data.userLabel.TextTransparency = 0
            end
            if data.frame then
                data.frame.Visible = true
            end
        end)
    end
    Log("Restored all cards")
end

function ConfBoard:RecolorAll(textColor, userColor, bgColor)
    for _, data in pairs(self.cards) do
        pcall(function()
            if data.textLabel and textColor then data.textLabel.TextColor3 = textColor end
            if data.userLabel and userColor then data.userLabel.TextColor3 = userColor end
            if data.frame and bgColor then data.frame.BackgroundColor3 = bgColor end
        end)
    end
end

function ConfBoard:StartHackLoop()
    task.spawn(function()
        Log("Confession hack loop STARTED")
        -- Initial apply
        self:ScanCards()
        self:ApplyAll()
        -- Watch for new cards
        local addedConn
        if self.gridRoot then
            addedConn = self.gridRoot.ChildAdded:Connect(function(child)
                if not self.hackActive then return end
                task.wait(0.3) -- let card build fully
                if self:IsCardFrame(child) then
                    self.cards[child] = self:ParseCard(child)
                    self:ApplyToCard(self.cards[child])
                end
            end)
        end
        -- Periodic re-apply (in case text is set by another script)
        while self.hackActive do
            self:ApplyAll()
            task.wait(self.scanDelay)
        end
        if addedConn then pcall(function() addedConn:Disconnect() end) end
        Log("Confession hack loop STOPPED")
    end)
end

-- Init
task.spawn(function()
    task.wait(2)
    if ConfBoard:FindGridRoot() then
        ConfBoard:ScanCards()
    end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- FIRE CONFESS PROMPT (fast auto-write via prompt)
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local ConfPrompt = {
    autoWrite = false,
    text = "X0DEC04T WAS HERE",
    delay = 5,
}

function ConfPrompt:FindPrompt()
    local zell = WS:FindFirstChild("ConfessZell")
    if not zell then return nil end
    for _, obj in ipairs(zell:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then return obj end
    end
    return nil
end

function ConfPrompt:StartAutoWrite()
    task.spawn(function()
        local hrp = GetHRP()
        if not hrp then return end
        local savedCF = hrp.CFrame
        local prompt = self:FindPrompt()
        if not prompt then Log("No confess prompt"); return end
        
        -- TP to the prompt's part
        local part = prompt.Parent
        if part and part:IsA("BasePart") then
            TPTo(part.Position + Vector3.new(0, 2, 0))
            task.wait(0.5)
        end
        
        while self.autoWrite do
            -- Fire the prompt to open UI
            if fireproximityprompt then
                pcall(function() fireproximityprompt(prompt) end)
            end
            task.wait(0.3)
            -- Find the TextBox in ConfessionUI and set text
            local ui = PG:FindFirstChild("ConfessionUI")
            if ui then
                for _, d in ipairs(ui:GetDescendants()) do
                    if d:IsA("TextBox") then
                        pcall(function() d.Text = self.text end)
                    end
                    if d:IsA("TextButton") and (d.Text:find("Kirim") or d.Text:find("Send")) then
                        pcall(function()
                            -- Fire the click via GuiService or direct event
                            for _, sig in ipairs({d.Activated, d.MouseButton1Click}) do
                                if sig then
                                    -- Try to invoke handlers directly
                                    if typeof(getconnections) == "function" then
                                        for _, con in ipairs(getconnections(sig)) do
                                            if con.Fire then con:Fire() end
                                            if con.Function then pcall(con.Function) end
                                        end
                                    end
                                end
                            end
                        end)
                    end
                end
            end
            -- Also try server remote directly (may be blocked)
            tryFire(Remotes.Confession, self.text)
            task.wait(self.delay)
        end
        
        -- TP back
        local hrp2 = GetHRP()
        if hrp2 then pcall(function() hrp2.CFrame = savedCF end) end
    end)
end

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OTHER TROLL
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local COORDS = {
    GiftStation = Vector3.new(107.379, 20.685, -191.165),
    LaporStation = Vector3.new(-26.263, 20.893, -156.398),
}

local giftSpam = false
local giftDelay = 1.0
local function GiftSpamLoop()
    task.spawn(function()
        local hrp = GetHRP(); if not hrp then return end
        local saved = hrp.CFrame
        TPTo(COORDS.GiftStation); task.wait(0.5)
        while giftSpam do
            ForEachTarget(function(p) tryFire(Remotes.SendGift, p, 1) end)
            task.wait(giftDelay)
        end
        local hrp2 = GetHRP(); if hrp2 then pcall(function() hrp2.CFrame = saved end) end
    end)
end

local function RadioPlay(id) tryFire(Remotes.Radio, tonumber(id) or id) end
local function RadioStop() tryFire(Remotes.Radio, 0) end

local pianoSpam = false
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
                            pcall(function() s:Sit(hum) end); break
                        end
                    end
                end
            end)
            task.wait(0.2)
        end
    end)
end

local laporSpam = false
local function LaporSpamLoop()
    task.spawn(function()
        local hrp = GetHRP(); if not hrp then return end
        local saved = hrp.CFrame
        TPTo(COORDS.LaporStation); task.wait(0.5)
        while laporSpam do
            ForEachTarget(function(p) tryFire(Remotes.KirimLaporan, p, "spam", "Exploiting") end)
            task.wait(0.8)
        end
        local hrp2 = GetHRP(); if hrp2 then pcall(function() hrp2.CFrame = saved end) end
    end)
end

local flowerType = "Rose"
local flowerSpam = false
local function SendFlower(kind)
    local map = {Rose=Remotes.RoseGift, Sunflower=Remotes.SunflowerGift, Whiterose=Remotes.WhiteroseGift, Bunga=Remotes.BungaGift, Boneka=Remotes.BonekaGift}
    local r = map[kind]; if not r then return end
    ForEachTarget(function(p) tryFire(r, p) end)
end
local function FlowerSpamLoop()
    task.spawn(function()
        while flowerSpam do SendFlower(flowerType); task.wait(0.5) end
    end)
end

local function ForceChat(text)
    local t = TargetName(); if not t then return end
    RunHD("forcechat "..t.." "..text)
    ForEachTarget(function(p)
        tryFire(Remotes.ForceChat, p, text)
        tryFire(Remotes.ForceBubble, p, text)
    end)
end

local function SellAllFish() tryFire(Remotes.SellAllFish) end

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
        flyBv = Instance.new("BodyVelocity"); flyBv.MaxForce=Vector3.one*1e5; flyBv.Velocity=Vector3.zero; flyBv.Parent=hrp
        flyBg = Instance.new("BodyGyro"); flyBg.MaxTorque=Vector3.one*1e5; flyBg.P=1e4; flyBg.CFrame=hrp.CFrame; flyBg.Parent=hrp
        flyConn = RunService.RenderStepped:Connect(function()
            if not flyBv or not flyBv.Parent then return end
            local cam = WS.CurrentCamera; local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir=dir-Vector3.yAxis end
            flyBv.Velocity=dir*60; flyBg.CFrame=cam.CFrame
        end)
    end
end

CM:Add(LP.Idled, function()
    if State.AntiAFK then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.zero) end) end
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
    if State.Speed~=16 then local h=GetHum(); if h then h.WalkSpeed=State.Speed end end
    if State.Jump~=50 then local h=GetHum(); if h then h.JumpPower=State.Jump end end
    if State.Noclip then Noclip(true) end
    if State.Fly then Fly(true) end
end)

--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- UI
--━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
local Window = WindUI:CreateWindow({
    Title=HUB.Name, Icon="skull", Author="v"..HUB.Version,
    Folder="X0DEC04T_TROLL", Size=UDim2.fromOffset(650,520),
    Transparent=true, Theme="Dark", SideBarWidth=170, HasOutline=true
})
pcall(function() WindUI:Notify({Title=HUB.Name, Content="v"..HUB.Version.." loaded", Duration=4, Icon="check"}) end)
local function Notify(t,c,d) pcall(function() WindUI:Notify({Title=t,Content=c,Duration=d or 4,Icon="info"}) end) end

local logoGui, logoActive = nil, false
local function CreateLogo()
    if logoGui and logoGui.Parent then return end
    logoGui = Instance.new("ScreenGui"); logoGui.Name="TrollLogo"; logoGui.ResetOnSpawn=false; logoGui.IgnoreGuiInset=true
    pcall(function() logoGui.Parent = GuiParent() end)
    local btn = Instance.new("ImageButton"); btn.Size=UDim2.new(0,60,0,60); btn.Position=UDim2.new(0,20,0.5,-30)
    btn.BackgroundTransparency=1; btn.AutoButtonColor=false
    btn.Image="rbxassetid://"..tostring(LOGO_ASSET_ID); btn.ScaleType=Enum.ScaleType.Fit
    btn.Active=true; btn.Draggable=true; btn.Parent=logoGui
    btn.MouseButton1Click:Connect(function()
        if logoGui then logoGui.Enabled=false end; logoActive=false
        pcall(function() Window:Open() end)
    end)
end
CreateLogo(); if logoGui then logoGui.Enabled=false end

CM:Add(UserInputService.InputBegan, function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        task.wait(0.1)
        if logoActive then
            if logoGui then logoGui.Enabled=false end; logoActive=false
            pcall(function() Window:Open() end)
        else
            if logoGui then logoGui.Enabled=true end; logoActive=true
            pcall(function() Window:Close() end)
        end
    end
end)

local Tabs = {
    Target      = Window:Tab({Title="Target",       Icon="target"}),
    Confession  = Window:Tab({Title="Confession",   Icon="edit"}),
    Troll       = Window:Tab({Title="Troll",        Icon="skull"}),
    Chat        = Window:Tab({Title="Chat",         Icon="message-circle"}),
    Sound       = Window:Tab({Title="Sound",        Icon="music"}),
    Self        = Window:Tab({Title="Self",         Icon="user"}),
    HDAdmin     = Window:Tab({Title="HD Admin",     Icon="shield"}),
    Settings    = Window:Tab({Title="Settings",     Icon="settings"}),
}
Window:SelectTab(1)

-- ═══ TARGET ═══
Tabs.Target:Section({Title="Select Target"})
local plrDrop = Tabs.Target:Dropdown({
    Title="Player", Values=GetPlayerList(), Value="[ALL PLAYERS]",
    Callback=safeCB(SetTarget)
})
Tabs.Target:Button({Title="Refresh List", Callback=safeCB(function()
    pcall(function() plrDrop:Refresh(GetPlayerList()) end)
    Notify("Target","Refreshed",2)
end)})
SetTarget("[ALL PLAYERS]")
Players.PlayerAdded:Connect(function() task.wait(1); pcall(function() plrDrop:Refresh(GetPlayerList()) end) end)
Players.PlayerRemoving:Connect(function() task.wait(1); pcall(function() plrDrop:Refresh(GetPlayerList()) end) end)

-- ═══ CONFESSION H4CK (main feature) ═══
Tabs.Confession:Section({Title="Story Wall H4CK - Client-side (100% works on YOUR screen)"})

Tabs.Confession:Paragraph({
    Title="How it works",
    Desc="Confirmed path: Workspace.ConfessZell > MULAI MENULIS > ConfessionSurface > GridRoot. Each card is a Frame named Conf_xxx with a TextLabel (text) and TextLabel (author). Auto-H4CK loop replaces every card and catches new ones as they appear."
})

Tabs.Confession:Button({Title="Scan Board Now", Callback=safeCB(function()
    if not ConfBoard.gridRoot then ConfBoard:FindGridRoot() end
    local n = ConfBoard:ScanCards()
    if ConfBoard.gridRoot then
        Notify("Confession", "GridRoot found\nCards: "..n, 5)
    else
        Notify("Confession", "GridRoot NOT found (try again after loading zone)", 5)
    end
end)})

Tabs.Confession:Input({Title="Custom Confession Text", Value="H4CKED BY X0DEC04T", Callback=safeCB(function(v)
    ConfBoard.hackText = v
end)})

Tabs.Confession:Input({Title="Custom Author (— name)", Value="— X0DEC04T", Callback=safeCB(function(v)
    ConfBoard.hackUser = v
end)})

Tabs.Confession:Toggle({Title="Also Replace Author Names", Default=true, Callback=safeCB(function(v)
    ConfBoard.replaceUsers = v
end)})

Tabs.Confession:Button({Title="Replace All NOW (one-time)", Callback=safeCB(function()
    if not ConfBoard.gridRoot then ConfBoard:FindGridRoot() end
    ConfBoard:ScanCards()
    ConfBoard.clearActive = false; ConfBoard.hideAllActive = false
    local n = ConfBoard:ApplyAll()
    Notify("Confession", "Replaced "..n.." cards", 4)
end)})

Tabs.Confession:Toggle({Title="AUTO H4CK CONFESSION (loop + catch new)", Default=false, Callback=safeCB(function(v)
    ConfBoard.hackActive = v
    ConfBoard.clearActive = false
    ConfBoard.hideAllActive = false
    if v then
        if not ConfBoard.gridRoot then ConfBoard:FindGridRoot() end
        ConfBoard:StartHackLoop()
        Notify("Confession", "AUTO H4CK ON - all cards will show your text", 4)
    else
        Notify("Confession", "AUTO H4CK OFF", 3)
    end
end)})

Tabs.Confession:Section({Title="Clear / Hide Board"})

Tabs.Confession:Toggle({Title="AUTO CLEAR BOARD (make all cards invisible)", Default=false, Callback=safeCB(function(v)
    ConfBoard.hackActive = v
    ConfBoard.clearActive = v
    ConfBoard.hideAllActive = false
    if v then
        if not ConfBoard.gridRoot then ConfBoard:FindGridRoot() end
        ConfBoard:StartHackLoop()
        Notify("Confession", "AUTO CLEAR ON - board is empty", 4)
    end
end)})

Tabs.Confession:Toggle({Title="AUTO HIDE TEXT ONLY (frames visible, text gone)", Default=false, Callback=safeCB(function(v)
    ConfBoard.hackActive = v
    ConfBoard.hideAllActive = v
    ConfBoard.clearActive = false
    if v then
        if not ConfBoard.gridRoot then ConfBoard:FindGridRoot() end
        ConfBoard:StartHackLoop()
    end
end)})

Tabs.Confession:Button({Title="Restore Original Confessions", Callback=safeCB(function()
    ConfBoard.hackActive = false
    ConfBoard.clearActive = false
    ConfBoard.hideAllActive = false
    ConfBoard:RestoreAll()
    Notify("Confession", "All originals restored", 3)
end)})

Tabs.Confession:Section({Title="Recolor Cards"})
Tabs.Confession:Button({Title="Red Text", Callback=safeCB(function()
    ConfBoard:RecolorAll(Color3.fromRGB(255,50,50), nil, nil)
end)})
Tabs.Confession:Button({Title="Green Text", Callback=safeCB(function()
    ConfBoard:RecolorAll(Color3.fromRGB(50,255,50), nil, nil)
end)})
Tabs.Confession:Button({Title="Rainbow Cycle 5s", Callback=safeCB(function()
    task.spawn(function()
        local colors = {Color3.fromRGB(255,0,0),Color3.fromRGB(255,127,0),Color3.fromRGB(255,255,0),Color3.fromRGB(0,255,0),Color3.fromRGB(0,127,255),Color3.fromRGB(75,0,130),Color3.fromRGB(148,0,211)}
        for _, c in ipairs(colors) do
            ConfBoard:RecolorAll(c, c, nil)
            task.wait(0.7)
        end
    end)
end)})
Tabs.Confession:Button({Title="Black BG + White Text", Callback=safeCB(function()
    ConfBoard:RecolorAll(Color3.new(1,1,1), Color3.new(1,1,1), Color3.new(0,0,0))
end)})

Tabs.Confession:Section({Title="Auto-Write via Confession UI (real posts)"})
Tabs.Confession:Paragraph({
    Title="Warning",
    Desc="This TPs to the wall, opens the write UI, fills text, and tries to click Kirim. Server rate-limits confessions. Use with caution."
})
Tabs.Confession:Input({Title="Post Text", Value="X0DEC04T WAS HERE", Callback=safeCB(function(v)
    ConfPrompt.text = v
end)})
Tabs.Confession:Slider({Title="Delay Between Posts (sec)", Value={Min=3,Max=30,Default=5}, Step=1, Callback=safeCB(function(v)
    ConfPrompt.delay = v
end)})
Tabs.Confession:Toggle({Title="AUTO WRITE Real Confessions (TP to wall)", Default=false, Callback=safeCB(function(v)
    ConfPrompt.autoWrite = v
    if v then ConfPrompt:StartAutoWrite() end
end)})

-- ═══ TROLL ═══
Tabs.Troll:Section({Title="Gift Spam"})
Tabs.Troll:Slider({Title="Delay", Value={Min=0.5,Max=3,Default=1}, Step=0.1, Callback=safeCB(function(v) giftDelay=v end)})
Tabs.Troll:Toggle({Title="Gift Spam (auto-TP)", Default=false, Callback=safeCB(function(v) giftSpam=v; if v then GiftSpamLoop() end end)})

Tabs.Troll:Section({Title="Flowers"})
Tabs.Troll:Dropdown({Title="Type", Values={"Rose","Sunflower","Whiterose","Bunga","Boneka"}, Value="Rose", Callback=safeCB(function(v) flowerType=v end)})
Tabs.Troll:Button({Title="Send Once", Callback=safeCB(function() SendFlower(flowerType) end)})
Tabs.Troll:Toggle({Title="Flower Spam", Default=false, Callback=safeCB(function(v) flowerSpam=v; if v then FlowerSpamLoop() end end)})

Tabs.Troll:Section({Title="Other"})
Tabs.Troll:Toggle({Title="Force Seat Lock", Default=false, Callback=safeCB(function(v) seatLockLoop=v; if v then SeatLockLoop() end end)})
Tabs.Troll:Toggle({Title="Laporan Spam (auto-TP)", Default=false, Callback=safeCB(function(v) laporSpam=v; if v then LaporSpamLoop() end end)})
Tabs.Troll:Button({Title="TP Me To Target", Callback=safeCB(function()
    if Target.Player and Target.Player ~= "ALL" then
        local ch = Target.Player.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if hrp then TPTo(hrp.Position) end
    end
end)})

-- ═══ CHAT ═══
Tabs.Chat:Section({Title="Force Chat"})
local chatText = "I love X0DEC04T"
Tabs.Chat:Input({Title="Text", Value=chatText, Callback=safeCB(function(v) chatText=v end)})
Tabs.Chat:Button({Title="Force Target Chat", Callback=safeCB(function() ForceChat(chatText) end)})

-- ═══ SOUND ═══
Tabs.Sound:Section({Title="Radio"})
local radioId = "142376088"
Tabs.Sound:Input({Title="Sound ID", Value=radioId, Callback=safeCB(function(v) radioId=v end)})
Tabs.Sound:Button({Title="Play", Callback=safeCB(function() RadioPlay(radioId) end)})
Tabs.Sound:Button({Title="Stop", Callback=safeCB(RadioStop)})

Tabs.Sound:Section({Title="Piano"})
Tabs.Sound:Toggle({Title="Piano Spam", Default=false, Callback=safeCB(function(v)
    pianoSpam=v
    if v then task.spawn(function()
        while pianoSpam do
            for i=1,25 do tryFire(Remotes.Piano, i, true) end
            task.wait(0.15)
        end
    end) end
end)})

-- ═══ SELF ═══
Tabs.Self:Section({Title="Movement"})
Tabs.Self:Slider({Title="Speed", Value={Min=16,Max=300,Default=16}, Step=4, Callback=safeCB(function(v)
    State.Speed=v; local h=GetHum(); if h then pcall(function() h.WalkSpeed=v end) end
end)})
Tabs.Self:Slider({Title="Jump", Value={Min=50,Max=500,Default=50}, Step=10, Callback=safeCB(function(v)
    State.Jump=v; local h=GetHum(); if h then pcall(function() h.JumpPower=v end) end
end)})
Tabs.Self:Toggle({Title="Fly", Default=false, Callback=safeCB(function(v) State.Fly=v; Fly(v) end)})
Tabs.Self:Toggle({Title="Noclip", Default=false, Callback=safeCB(function(v) State.Noclip=v; Noclip(v) end)})

Tabs.Self:Section({Title="Protection"})
Tabs.Self:Toggle({Title="God Mode", Default=false, Callback=safeCB(function(v) State.GodMode=v end)})
Tabs.Self:Toggle({Title="Anti-AFK", Default=true, Callback=safeCB(function(v) State.AntiAFK=v end)})

-- ═══ HD ADMIN ═══
Tabs.HDAdmin:Section({Title="Custom Command"})
local hdInput = "kick player"
Tabs.HDAdmin:Input({Title="Command (no prefix)", Value=hdInput, Callback=safeCB(function(v) hdInput=v end)})
Tabs.HDAdmin:Button({Title="Execute", Callback=safeCB(function() RunHD(hdInput) end)})

Tabs.HDAdmin:Section({Title="Quick Actions on Target"})
local hdActs = {
    {"Kick","kick"},{"Ban","ban"},{"Kill","kill"},{"Fling","fling"},
    {"Freeze","freeze"},{"Thaw","thaw"},{"Explode","explode"},
    {"Fire","fire"},{"Sit","sit"},{"Jump","jump"},{"Blind","blind"},
    {"Invisible","invisible"},{"Visible","visible"},{"Slap","slap"},
}
for _, a in ipairs(hdActs) do
    Tabs.HDAdmin:Button({Title=a[1], Callback=safeCB(function()
        local t = TargetName(); if t then RunHD(a[2].." "..t) end
    end)})
end

-- ═══ SETTINGS ═══
Tabs.Settings:Button({Title="PANIC (stop all loops + restore board)", Callback=safeCB(function()
    giftSpam=false; pianoSpam=false; seatLockLoop=false; laporSpam=false
    flowerSpam=false
    ConfBoard.hackActive=false; ConfBoard.clearActive=false; ConfBoard.hideAllActive=false
    ConfPrompt.autoWrite=false
    ConfBoard:RestoreAll()
    RadioStop()
    Notify("PANIC","All stopped + board restored",4)
end)})

Tabs.Settings:Button({Title="Minimize (RightShift)", Callback=safeCB(function()
    pcall(function() Window:Close() end); task.wait(0.2)
    if logoGui then logoGui.Enabled=true end; logoActive=true
end)})

Tabs.Settings:Button({Title="Reload Remotes + Board", Callback=safeCB(function()
    loadRemotes()
    ConfBoard:FindGridRoot()
    ConfBoard:ScanCards()
    Notify("Reload","Done",2)
end)})

Tabs.Settings:Button({Title="Unload Hub", Callback=safeCB(function()
    giftSpam=false; pianoSpam=false; seatLockLoop=false; laporSpam=false
    flowerSpam=false
    ConfBoard.hackActive=false; ConfBoard.clearActive=false
    ConfPrompt.autoWrite=false
    ConfBoard:RestoreAll()
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup(); _G[INSTANCE_KEY]=nil
    pcall(function() Window:Destroy() end)
end)})

_G[INSTANCE_KEY] = {version=HUB.Version, destroy=function()
    giftSpam=false; pianoSpam=false; seatLockLoop=false; laporSpam=false
    flowerSpam=false
    ConfBoard.hackActive=false; ConfBoard.clearActive=false
    ConfPrompt.autoWrite=false
    ConfBoard:RestoreAll()
    Noclip(false); Fly(false)
    if logoGui then pcall(function() logoGui:Destroy() end) end
    CM:Cleanup()
    pcall(function() Window:Destroy() end)
end}

Log("v1.5 READY - Confession Board H4CK loaded with confirmed path")
