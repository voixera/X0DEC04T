--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.6 - VEHICLE TWEEN EDITION
-- 🏍️ Tween the whole bike (safer than HRP tween)
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local TweenService      = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local LocalPlayer = Players.LocalPlayer
pcall(function() LocalizationService.RobloxLocaleId = "en-us" end)

local INSTANCE_KEY = "__X0DEC04T_DDS_v16"
if _G[INSTANCE_KEY] then
    pcall(function() _G[INSTANCE_KEY].destroy() end)
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

local WindUI = nil
for _, url in ipairs({
    "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua",
    "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
}) do
    local ok, r = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and type(r) == "table" then WindUI = r; break end
end
if not WindUI then warn("WindUI failed"); return end
pcall(function() if WindUI.SetLanguage then WindUI:SetLanguage("en") end end)

local HUB = {
    Name    = "X0DEC04T Hub",
    Game    = "Drag Drive Simulator",
    Version = "1.6",
    Author  = "voixera",
    LogoId  = "rbxassetid://91626851418651",
    Discord = "discord.gg/x0dec04t",
}

local State = {
    AutoCourier = false,
    MinDelay = 2,
    MaxDelay = 4,
    VehicleSpeed = 200,        -- studs/sec for vehicle tween
    HoverHeight = 4,
    AutoEquipBox = true,
    UseVehicleTween = true,

    DeliveriesDone = 0,
    SessionMoney = 0,
    LastMoneyRaw = 0,
    SessionStartTime = tick(),
    CurrentStatus = "Idle",

    WalkSpeedEnabled = false,
    WalkSpeedValue = 30,
    DefaultWalkSpeed = 16,

    AntiAFK = true,
    Notifications = true,
    UIOpen = true,
    LogoGui = nil,

    CourierRunning = false,
    NoclipConn = nil,
    ActiveTween = nil,
    UnAnchorConn = nil,
}

local function GuiParent()
    local p = CoreGui
    pcall(function() if gethui then p = gethui() end end)
    return p
end

local function Notify(t, c, d)
    if not State.Notifications then return end
    pcall(function()
        WindUI:Notify({Title=tostring(t or ""),Content=tostring(c or ""),Duration=tonumber(d) or 3,Icon="bell"})
    end)
end

local function Char() return LocalPlayer.Character end
local function HRP() local c=Char(); return c and c:FindFirstChild("HumanoidRootPart") end
local function Hum() local c=Char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function GetPG() return LocalPlayer:FindFirstChild("PlayerGui") end
local function RandomDelay() return State.MinDelay + math.random() * (State.MaxDelay - State.MinDelay) end

LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.zero)
        end)
    end
end)

local function ParseMoney(str)
    if not str then return 0 end
    local clean = str:gsub("Rp%.?", ""):gsub("[^%d]", "")
    return tonumber(clean) or 0
end

local function FindMoneyLabel()
    local pg = GetPG()
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text:find("Rp") then
            local val = ParseMoney(d.Text)
            if val > 1000 then return d end
        end
    end
    return nil
end

local function GetLivrason() return Workspace:FindFirstChild("Livrason") end

local function GetTakePrompt()
    local liv = GetLivrason()
    if not liv then return nil, nil end
    local take1 = liv:FindFirstChild("Take1")
    if not take1 then return nil, nil end
    local take = take1:FindFirstChild("Take")
    if not take then return nil, nil end
    return take:FindFirstChildWhichIsA("ProximityPrompt"), take
end

local function GetActiveLocation()
    local liv = GetLivrason()
    if not liv then return nil, nil, nil end
    local locFolder = liv:FindFirstChild("Location")
    if not locFolder then return nil, nil, nil end
    for _, locNum in ipairs(locFolder:GetChildren()) do
        local block = locNum:FindFirstChild("Block")
        if block then
            local prompt = block:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt and prompt.Enabled then
                return prompt, block, locNum.Name
            end
        end
    end
    return nil, nil, nil
end

local function HasBoxTool()
    local ch = Char()
    if not ch then return false end
    local t = ch:FindFirstChildWhichIsA("Tool")
    if t then return true, t end
    return false, nil
end

local function HasBoxInBackpack()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false, nil end
    local t = bp:FindFirstChildWhichIsA("Tool")
    if t then return true, t end
    return false, nil
end

local function EquipBoxIfNeeded()
    if HasBoxTool() then return true end
    local hasBp, tool = HasBoxInBackpack()
    if hasBp and tool then
        local h = Hum()
        if h then pcall(function() h:EquipTool(tool) end); return true end
    end
    return false
end

-- ═══════════════════════════════════════════
-- VEHICLE
-- ═══════════════════════════════════════════
local function FindMyMotorcycle()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m.Name:find(LocalPlayer.Name) and m:FindFirstChild("DriveSeat") then
            return m
        end
    end
    return nil
end

local function GetSeat()
    local h = Hum()
    if h and h.SeatPart then return h.SeatPart end
    return nil
end

local function IsInVehicle() return GetSeat() ~= nil end

local function GetVehicleModel()
    local seat = GetSeat()
    if not seat then return FindMyMotorcycle() end
    local m = seat.Parent
    while m and not (m:IsA("Model") and m.PrimaryPart) do
        m = m.Parent
        if m == Workspace then return nil end
    end
    return m
end

local function MountMotorcycle()
    local bike = FindMyMotorcycle()
    if not bike then return false end
    local seat = bike:FindFirstChild("DriveSeat")
    if not seat or not seat:IsA("VehicleSeat") then return false end
    if seat.Occupant then return true end
    local h = Hum()
    if h then
        pcall(function() seat:Sit(h) end)
        task.wait(0.6)
        return IsInVehicle()
    end
    return false
end

local function Dismount()
    local seat = GetSeat()
    if seat then
        local h = Hum()
        if h then
            pcall(function() seat:Sit(nil) end)
            pcall(function() h.Sit = false end)
        end
    end
end

-- ═══════════════════════════════════════════
-- NOCLIP + freeze physics on vehicle during tween
-- ═══════════════════════════════════════════
local function ApplyNoclip()
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn = nil end
    State.NoclipConn = RunService.Stepped:Connect(function()
        if not State.AutoCourier then return end
        local ch = Char()
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    pcall(function() p.CanCollide = false end)
                end
            end
        end
        local v = GetVehicleModel()
        if v then
            for _, p in ipairs(v:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then
                    pcall(function() p.CanCollide = false end)
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════
-- VEHICLE TWEEN (the real solution)
-- Tweens the entire welded vehicle model
-- ═══════════════════════════════════════════
local function TweenVehicleTo(targetPos)
    local vehicle = GetVehicleModel()
    if not vehicle or not vehicle.PrimaryPart then return false end

    if State.ActiveTween then
        pcall(function() State.ActiveTween:Cancel() end)
        State.ActiveTween = nil
    end

    local pp = vehicle.PrimaryPart
    local currentPos = pp.Position
    local targetFlat = Vector3.new(targetPos.X, targetPos.Y + State.HoverHeight, targetPos.Z)
    local distance = (currentPos - targetFlat).Magnitude
    if distance < 3 then return true end

    local travelTime = distance / State.VehicleSpeed
    travelTime = math.max(travelTime, 0.5)  -- min time so it looks natural

    -- Face direction
    local dir = (targetFlat - currentPos).Unit
    local lookTarget = targetFlat + Vector3.new(dir.X, 0, dir.Z) * 10
    local targetCF = CFrame.new(targetFlat, Vector3.new(lookTarget.X, targetFlat.Y, lookTarget.Z))

    -- Anchor the primary part to prevent physics fighting
    local wasAnchored = pp.Anchored
    pp.Anchored = true

    -- Kill velocity on all parts to prevent lag
    for _, p in ipairs(vehicle:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                p.AssemblyLinearVelocity = Vector3.zero
                p.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end

    local info = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(pp, info, { CFrame = targetCF })

    State.ActiveTween = tween
    tween:Play()

    local startTime = tick()
    while tween.PlaybackState == Enum.PlaybackState.Playing do
        if not State.AutoCourier then tween:Cancel(); pp.Anchored = wasAnchored; return false end
        if tick() - startTime > travelTime + 3 then tween:Cancel(); break end
        -- Continuously null velocity during tween
        for _, p in ipairs(vehicle:GetDescendants()) do
            if p:IsA("BasePart") then
                pcall(function()
                    p.AssemblyLinearVelocity = Vector3.zero
                    p.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        task.wait(0.05)
    end

    -- Restore anchor state
    pp.Anchored = wasAnchored
    State.ActiveTween = nil
    return true
end

-- ═══════════════════════════════════════════
-- CHARACTER MOVE (for after dismount)
-- Uses short-distance CFrame set (safe, small delta)
-- ═══════════════════════════════════════════
local function MoveCharacterTo(targetPos, maxDist)
    maxDist = maxDist or 30
    local hrp = HRP()
    if not hrp then return false end
    local dist = (hrp.Position - targetPos).Magnitude
    if dist > maxDist then
        -- Too far, do a short tween instead
        local travelTime = dist / 60
        local info = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
        local targetCF = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        local tween = TweenService:Create(hrp, info, { CFrame = targetCF })
        tween:Play()
        local st = tick()
        while tween.PlaybackState == Enum.PlaybackState.Playing do
            if not State.AutoCourier then tween:Cancel(); return false end
            if tick() - st > travelTime + 2 then tween:Cancel(); break end
            task.wait(0.05)
        end
    else
        -- Close enough, just set directly (small delta = safe)
        pcall(function() hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) end)
    end
    return true
end

local function FirePrompt(prompt)
    if not prompt then return false end
    local hrp = HRP()
    local parent = prompt.Parent
    if not hrp or not parent or not parent:IsA("BasePart") then return false end
    local dist = (parent.Position - hrp.Position).Magnitude
    if dist > 25 then return false end
    local ok = pcall(function() fireproximityprompt(prompt) end)
    return ok
end

-- ═══════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════
local function StartCourier()
    if State.CourierRunning then return end
    State.CourierRunning = true
    ApplyNoclip()

    task.spawn(function()
        while State.AutoCourier do
            local hasBox = HasBoxTool() or HasBoxInBackpack()

            if not hasBox then
                -- ══ PICKUP PHASE ══
                local takePrompt, takePart = GetTakePrompt()
                if not takePrompt or not takePart then
                    State.CurrentStatus = "⏳ Waiting for Take1..."
                    task.wait(2)
                else
                    -- Mount motorcycle
                    if not IsInVehicle() then
                        State.CurrentStatus = "🏍️ Mounting bike..."
                        if not MountMotorcycle() then
                            State.CurrentStatus = "⚠️ No motorcycle! Spawn one."
                            task.wait(3)
                        else
                            task.wait(0.7)
                        end
                    end

                    if IsInVehicle() then
                        State.CurrentStatus = "🚚 Vehicle-tween to basecamp..."
                        TweenVehicleTo(takePart.Position + Vector3.new(0, 0, -8))
                        task.wait(0.4)

                        State.CurrentStatus = "🛑 Dismounting..."
                        Dismount()
                        task.wait(0.5)

                        State.CurrentStatus = "🚶 Walk to prompt..."
                        MoveCharacterTo(takePart.Position, 30)
                        task.wait(0.3)

                        State.CurrentStatus = "📦 Picking up..."
                        for i = 1, 3 do
                            FirePrompt(takePrompt)
                            task.wait(0.4)
                            if HasBoxTool() or HasBoxInBackpack() then break end
                        end
                        task.wait(0.5)
                    end
                end
            else
                -- ══ DELIVER PHASE ══
                if State.AutoEquipBox then EquipBoxIfNeeded() end

                local locPrompt, locBlock, locName = GetActiveLocation()
                if not locPrompt or not locBlock then
                    State.CurrentStatus = "⏳ Waiting for destination..."
                    task.wait(2)
                else
                    -- Get back on bike
                    if not IsInVehicle() then
                        State.CurrentStatus = "🏍️ Getting on bike..."
                        MountMotorcycle()
                        task.wait(0.7)
                    end

                    if IsInVehicle() then
                        State.CurrentStatus = "🎯 Vehicle-tween to Loc " .. locName
                        TweenVehicleTo(locBlock.Position + Vector3.new(0, 0, -8))
                        task.wait(0.4)

                        Dismount()
                        task.wait(0.5)
                    end

                    State.CurrentStatus = "🚶 Walk to drop..."
                    MoveCharacterTo(locBlock.Position, 30)
                    task.wait(0.3)

                    EquipBoxIfNeeded()
                    task.wait(0.3)

                    State.CurrentStatus = "📬 Delivering..."
                    for i = 1, 3 do
                        FirePrompt(locPrompt)
                        task.wait(0.4)
                        if not HasBoxTool() and not HasBoxInBackpack() then break end
                    end

                    if not HasBoxTool() and not HasBoxInBackpack() then
                        State.DeliveriesDone = State.DeliveriesDone + 1
                        local delay = RandomDelay()
                        State.CurrentStatus = "✅ #" .. State.DeliveriesDone .. " done | " .. string.format("%.1fs", delay)
                        task.wait(delay)
                    else
                        State.CurrentStatus = "⚠️ Retry..."
                        task.wait(1.5)
                    end
                end
            end
            task.wait(0.1)
        end

        if State.ActiveTween then pcall(function() State.ActiveTween:Cancel() end); State.ActiveTween = nil end
        State.CurrentStatus = "🔴 Stopped"
        State.CourierRunning = false
    end)
end

local function StopCourier()
    State.AutoCourier = false
    if State.ActiveTween then pcall(function() State.ActiveTween:Cancel() end); State.ActiveTween = nil end
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn = nil end
end

local function ApplyWalkSpeed()
    local h = Hum()
    if h then
        pcall(function()
            h.WalkSpeed = State.WalkSpeedEnabled and State.WalkSpeedValue or State.DefaultWalkSpeed
        end)
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.WalkSpeedEnabled then ApplyWalkSpeed() end
    if State.AutoCourier then ApplyNoclip() end
end)

task.spawn(function()
    task.wait(3)
    local lbl = FindMoneyLabel()
    if lbl then State.LastMoneyRaw = ParseMoney(lbl.Text) end
    while true do
        task.wait(1.5)
        if not lbl or not lbl.Parent then lbl = FindMoneyLabel() end
        if lbl then
            local cur = ParseMoney(lbl.Text)
            if State.LastMoneyRaw == 0 then State.LastMoneyRaw = cur
            elseif cur > State.LastMoneyRaw then
                State.SessionMoney = State.SessionMoney + (cur - State.LastMoneyRaw)
                State.LastMoneyRaw = cur
            elseif cur < State.LastMoneyRaw then State.LastMoneyRaw = cur end
        end
    end
end)

-- WINDUI
local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "truck",
    Author = HUB.Author .. " | " .. HUB.Game,
    Folder = "X0DEC04T_DDS",
    Size = UDim2.fromOffset(600, 430),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
    KeySystem = false,
    Language = "en",
})

Window:EditOpenButton({ Title = HUB.Name, Icon = "truck", Enabled = false, Draggable = true })

local function CreateFloatingLogo()
    if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0_Logo"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 1000
    sg.Parent = GuiParent()
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 60, 0, 60)
    container.Position = UDim2.new(0, 20, 0, 100)
    container.BackgroundTransparency = 1; container.Active = true; container.Parent = sg
    local img = Instance.new("ImageLabel", container)
    img.Size = UDim2.new(1, 0, 1, 0); img.BackgroundTransparency = 1
    img.Image = HUB.LogoId; img.ScaleType = Enum.ScaleType.Fit; img.ZIndex = 2
    local btn = Instance.new("TextButton", container)
    btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.AutoButtonColor = false; btn.ZIndex = 3
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = container.Position; moved = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then moved = true end
            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved then
                pcall(function()
                    if State.UIOpen then Window:Close(); State.UIOpen = false
                    else Window:Open(); State.UIOpen = true end
                end)
            end
            dragging = false
        end
    end)
    State.LogoGui = sg
end
CreateFloatingLogo()

local Tabs = {
    Info       = Window:Tab({ Title = "Info",       Icon = "info" }),
    Automation = Window:Tab({ Title = "Automation", Icon = "zap" }),
    Utility    = Window:Tab({ Title = "Utility",    Icon = "wrench" }),
}

Tabs.Info:Section({ Title = "About" })
Tabs.Info:Paragraph({
    Title = HUB.Name .. " v" .. HUB.Version,
    Desc = "Game: " .. HUB.Game .. "\nMode: Vehicle Tween (bypass AC)"
})

Tabs.Info:Section({ Title = "Live Stats" })
local statsPara = Tabs.Info:Paragraph({ Title = "Session Stats", Desc = "Loading..." })
local statusPara = Tabs.Info:Paragraph({ Title = "Current Status", Desc = "Idle" })

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local elapsed = math.floor(tick() - State.SessionStartTime)
            local mins = math.floor(elapsed/60); local secs = elapsed%60
            local rate = (State.DeliveriesDone > 0 and elapsed > 0) and math.floor((State.DeliveriesDone/elapsed)*3600) or 0
            local moneyRate = (State.SessionMoney > 0 and elapsed > 0) and math.floor((State.SessionMoney/elapsed)*3600) or 0
            local moneyLbl = FindMoneyLabel(); local curMoney = moneyLbl and moneyLbl.Text or "?"
            local text = "Total: " .. curMoney
                .. "\nEarned: Rp. " .. State.SessionMoney
                .. "\nDeliveries: " .. State.DeliveriesDone
                .. "\nRate: " .. rate .. " del/hr | Rp. " .. moneyRate .. "/hr"
                .. "\nSession: " .. string.format("%02d:%02d", mins, secs)
                .. "\nPing: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms"
            if statsPara and statsPara.SetDesc then pcall(function() statsPara:SetDesc(text) end) end
            if statusPara and statusPara.SetDesc then pcall(function() statusPara:SetDesc(State.CurrentStatus) end) end
        end)
    end
end)

Tabs.Info:Section({ Title = "Speed Setup" })
Tabs.Info:Paragraph({
    Title = "Recommended",
    Desc = "Vehicle Speed: 150-300 (safe)\n"
        .. "Delay Min: 2, Max: 4\n"
        .. "= ~150-300 deliveries/hr safely\n\n"
        .. "TOO FAST = anti-cheat kick!\n"
        .. "Start slow (100), increase if safe"
})

Tabs.Info:Button({
    Title = "Copy Discord",
    Callback = function()
        if setclipboard then setclipboard(HUB.Discord) end
        Notify("Discord", "Copied", 3)
    end
})

Tabs.Automation:Section({ Title = "🚚 Courier" })
Tabs.Automation:Toggle({
    Title = "🚚 Auto Courier",
    Default = false,
    Callback = function(v)
        State.AutoCourier = v
        if v then StartCourier(); Notify("Started", "Vehicle tween mode", 3)
        else StopCourier(); Notify("Stopped", "", 2) end
    end
})

Tabs.Automation:Section({ Title = "⚡ Vehicle Speed" })
Tabs.Automation:Slider({
    Title = "Vehicle Speed (studs/sec)",
    Value = { Min = 50, Max = 500, Default = 200 },
    Callback = function(v) State.VehicleSpeed = tonumber(v) or 200 end
})

Tabs.Automation:Slider({
    Title = "Hover Height",
    Value = { Min = 2, Max = 15, Default = 4 },
    Callback = function(v) State.HoverHeight = tonumber(v) or 4 end
})

Tabs.Automation:Section({ Title = "⏱️ Delays" })
Tabs.Automation:Slider({
    Title = "Min Delay (sec)",
    Value = { Min = 1, Max = 10, Default = 2 },
    Callback = function(v)
        State.MinDelay = tonumber(v) or 2
        if State.MinDelay > State.MaxDelay then State.MaxDelay = State.MinDelay end
    end
})
Tabs.Automation:Slider({
    Title = "Max Delay (sec)",
    Value = { Min = 2, Max = 15, Default = 4 },
    Callback = function(v)
        State.MaxDelay = tonumber(v) or 4
        if State.MaxDelay < State.MinDelay then State.MinDelay = State.MaxDelay end
    end
})

Tabs.Automation:Toggle({
    Title = "Auto Equip Box",
    Default = true,
    Callback = function(v) State.AutoEquipBox = v end
})

Tabs.Automation:Section({ Title = "📊 Stats" })
Tabs.Automation:Button({
    Title = "Reset Counter",
    Callback = function()
        State.DeliveriesDone = 0; State.SessionMoney = 0; State.SessionStartTime = tick()
        local lbl = FindMoneyLabel()
        State.LastMoneyRaw = lbl and ParseMoney(lbl.Text) or 0
        Notify("Reset", "Stats cleared", 2)
    end
})
Tabs.Automation:Button({
    Title = "🛑 STOP",
    Callback = function()
        State.AutoCourier = false
        StopCourier()
        Notify("STOP", "Emergency stop", 2)
    end
})

Tabs.Utility:Section({ Title = "🏃 Movement" })
Tabs.Utility:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 60, Default = 30 },
    Callback = function(v)
        State.WalkSpeedValue = tonumber(v) or 30
        if State.WalkSpeedEnabled then ApplyWalkSpeed() end
    end
})
Tabs.Utility:Toggle({
    Title = "Enable Walk Speed",
    Default = false,
    Callback = function(v) State.WalkSpeedEnabled = v; ApplyWalkSpeed() end
})

Tabs.Utility:Section({ Title = "🏍️ Vehicle" })
Tabs.Utility:Button({
    Title = "Mount Motorcycle",
    Callback = function()
        if MountMotorcycle() then Notify("Mounted", "", 2)
        else Notify("Fail", "Spawn bike first", 3) end
    end
})
Tabs.Utility:Button({
    Title = "Dismount",
    Callback = function() Dismount(); Notify("Off bike", "", 2) end
})

Tabs.Utility:Section({ Title = "🛡️ Anti AFK" })
Tabs.Utility:Toggle({
    Title = "Anti AFK",
    Default = true,
    Callback = function(v) State.AntiAFK = v end
})

Tabs.Utility:Section({ Title = "🖼️ UI" })
Tabs.Utility:Toggle({
    Title = "Notifications",
    Default = true,
    Callback = function(v) State.Notifications = v end
})
Tabs.Utility:Toggle({
    Title = "Floating Logo",
    Default = true,
    Callback = function(v)
        if v then
            if not State.LogoGui or not State.LogoGui.Parent then CreateFloatingLogo()
            else State.LogoGui.Enabled = true end
        else
            if State.LogoGui then State.LogoGui.Enabled = false end
        end
    end
})

Tabs.Utility:Section({ Title = "⚠️ Danger" })
Tabs.Utility:Button({
    Title = "🔴 Unload",
    Callback = function()
        StopCourier()
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        local h = Hum(); if h then pcall(function() h.WalkSpeed = State.DefaultWalkSpeed end) end
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end
})

_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        StopCourier()
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v" .. HUB.Version .. " Vehicle Tween loaded", 5)
print("[X0DEC04T] v1.6 loaded")
