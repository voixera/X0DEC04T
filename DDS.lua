--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.5 - TURBO EDITION
-- ⚡ Fast tween + Instant mode option
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

local INSTANCE_KEY = "__X0DEC04T_DDS_v15"
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
    Version = "1.5",
    Author  = "voixera",
    LogoId  = "rbxassetid://91626851418651",
    Discord = "discord.gg/x0dec04t",
}

local State = {
    AutoCourier = false,
    MinDelay = 1,
    MaxDelay = 2,
    TravelSpeed = 500,
    HoverHeight = 5,
    InstantMode = false,
    AutoEquipBox = true,

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
        if h then
            pcall(function() h:EquipTool(tool) end)
            return true
        end
    end
    return false
end

local function GetSeat()
    local h = Hum()
    if h and h.SeatPart then return h.SeatPart end
    return nil
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
    end)
end

-- ═══════════════════════════════════════════
-- FAST TWEEN (or instant)
-- ═══════════════════════════════════════════
local function TweenTo(targetPos)
    local hrp = HRP()
    if not hrp then return false end

    if State.ActiveTween then
        pcall(function() State.ActiveTween:Cancel() end)
        State.ActiveTween = nil
    end

    local currentPos = hrp.Position
    local targetFlat = Vector3.new(targetPos.X, targetPos.Y + State.HoverHeight, targetPos.Z)
    local distance = (currentPos - targetFlat).Magnitude
    if distance < 2 then return true end

    -- INSTANT MODE: fixed 0.3s travel regardless of distance
    local travelTime
    if State.InstantMode then
        travelTime = 0.3
    else
        travelTime = distance / State.TravelSpeed
        travelTime = math.max(travelTime, 0.15)
    end

    local dir = (targetFlat - currentPos).Unit
    local lookTarget = targetFlat + Vector3.new(dir.X, 0, dir.Z) * 10
    local targetCF = CFrame.new(targetFlat, Vector3.new(lookTarget.X, targetFlat.Y, lookTarget.Z))

    local info = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, info, { CFrame = targetCF })

    State.ActiveTween = tween
    tween:Play()

    local startTime = tick()
    while tween.PlaybackState == Enum.PlaybackState.Playing do
        if not State.AutoCourier then tween:Cancel(); return false end
        if tick() - startTime > travelTime + 2 then tween:Cancel(); break end
        task.wait(0.05)
    end

    State.ActiveTween = nil
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
-- FAST MAIN LOOP
-- ═══════════════════════════════════════════
local function StartCourier()
    if State.CourierRunning then return end
    State.CourierRunning = true
    ApplyNoclip()

    task.spawn(function()
        while State.AutoCourier do
            -- Dismount immediately if on bike (character-only mode is fastest)
            if GetSeat() then Dismount(); task.wait(0.2) end

            local hasBox = HasBoxTool() or HasBoxInBackpack()

            if not hasBox then
                local takePrompt, takePart = GetTakePrompt()
                if not takePrompt or not takePart then
                    State.CurrentStatus = "⏳ Waiting for Take1..."
                    task.wait(1)
                else
                    State.CurrentStatus = "🚚 Fast tween to basecamp..."
                    TweenTo(takePart.Position)
                    task.wait(0.1)

                    State.CurrentStatus = "📦 Picking up..."
                    -- Fire multiple times to ensure it registers
                    for i = 1, 3 do
                        FirePrompt(takePrompt)
                        task.wait(0.3)
                        if HasBoxTool() or HasBoxInBackpack() then break end
                    end
                    task.wait(0.5)
                end
            else
                if State.AutoEquipBox then EquipBoxIfNeeded() end

                local locPrompt, locBlock, locName = GetActiveLocation()
                if not locPrompt or not locBlock then
                    State.CurrentStatus = "⏳ Waiting for destination..."
                    task.wait(1)
                else
                    State.CurrentStatus = "🎯 Fast tween to Loc " .. locName
                    TweenTo(locBlock.Position)
                    task.wait(0.1)

                    EquipBoxIfNeeded()
                    task.wait(0.15)

                    State.CurrentStatus = "📬 Delivering..."
                    -- Fire multiple times to ensure it registers
                    for i = 1, 3 do
                        FirePrompt(locPrompt)
                        task.wait(0.3)
                        if not HasBoxTool() and not HasBoxInBackpack() then break end
                    end

                    if not HasBoxTool() and not HasBoxInBackpack() then
                        State.DeliveriesDone = State.DeliveriesDone + 1
                        local delay = RandomDelay()
                        State.CurrentStatus = "✅ #" .. State.DeliveriesDone .. " done | " .. string.format("%.1fs", delay)
                        task.wait(delay)
                    else
                        State.CurrentStatus = "⚠️ Retry..."
                        task.wait(1)
                    end
                end
            end
            task.wait(0.05)
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
    Icon = "zap",
    Author = HUB.Author .. " | " .. HUB.Game,
    Folder = "X0DEC04T_DDS",
    Size = UDim2.fromOffset(600, 430),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
    KeySystem = false,
    Language = "en",
})

Window:EditOpenButton({ Title = HUB.Name, Icon = "zap", Enabled = false, Draggable = true })

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
    Title = HUB.Name .. " v" .. HUB.Version .. " TURBO",
    Desc = "Game: " .. HUB.Game .. "\nMode: FAST TWEEN"
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

Tabs.Info:Section({ Title = "Speed Tips" })
Tabs.Info:Paragraph({
    Title = "For MAX SPEED",
    Desc = "1. Enable INSTANT MODE = 0.3s per trip\n"
        .. "2. Set delay Min:0.5 Max:1\n"
        .. "3. Should get ~500 deliveries/hr!\n\n"
        .. "For safer speed: Speed=500, Delay=1-2"
})

Tabs.Info:Button({
    Title = "Copy Discord",
    Callback = function()
        if setclipboard then setclipboard(HUB.Discord) end
        Notify("Discord", "Copied", 3)
    end
})

-- AUTOMATION
Tabs.Automation:Section({ Title = "🚚 Courier Autofarm" })
Tabs.Automation:Toggle({
    Title = "🚚 Auto Courier",
    Default = false,
    Callback = function(v)
        State.AutoCourier = v
        if v then StartCourier(); Notify("Auto Courier", "TURBO STARTED", 3)
        else StopCourier(); Notify("Auto Courier", "STOPPED", 2) end
    end
})

Tabs.Automation:Section({ Title = "⚡ SPEED" })

Tabs.Automation:Toggle({
    Title = "⚡ INSTANT MODE",
    Desc = "0.3s per trip regardless of distance (FASTEST)",
    Default = false,
    Callback = function(v)
        State.InstantMode = v
        Notify("Instant Mode", v and "ON - MAX SPEED" or "OFF - use speed slider", 2)
    end
})

Tabs.Automation:Slider({
    Title = "Travel Speed (studs/sec)",
    Value = { Min = 100, Max = 3000, Default = 500 },
    Callback = function(v) State.TravelSpeed = tonumber(v) or 500 end
})

Tabs.Automation:Slider({
    Title = "Min Delay (x0.5 sec)",
    Value = { Min = 1, Max = 10, Default = 2 },
    Callback = function(v)
        State.MinDelay = (tonumber(v) or 2) * 0.5
        if State.MinDelay > State.MaxDelay then State.MaxDelay = State.MinDelay end
    end
})

Tabs.Automation:Slider({
    Title = "Max Delay (x0.5 sec)",
    Value = { Min = 2, Max = 20, Default = 4 },
    Callback = function(v)
        State.MaxDelay = (tonumber(v) or 4) * 0.5
        if State.MaxDelay < State.MinDelay then State.MinDelay = State.MaxDelay end
    end
})

Tabs.Automation:Slider({
    Title = "Hover Height",
    Value = { Min = 0, Max = 15, Default = 5 },
    Callback = function(v) State.HoverHeight = tonumber(v) or 5 end
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
        Notify("Stats", "Reset", 2)
    end
})
Tabs.Automation:Button({
    Title = "🛑 EMERGENCY STOP",
    Callback = function()
        State.AutoCourier = false
        StopCourier()
        Notify("STOP", "Stopped", 3)
    end
})

Tabs.Utility:Section({ Title = "🏃 Movement" })
Tabs.Utility:Slider({
    Title = "Walk Speed",
    Value = { Min = 16, Max = 100, Default = 30 },
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
    Title = "Show Floating Logo",
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

Tabs.Utility:Section({ Title = "⚠️ Danger Zone" })
Tabs.Utility:Button({
    Title = "🔴 Unload Hub",
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

Notify(HUB.Name, "v" .. HUB.Version .. " TURBO loaded!", 5)
print("[X0DEC04T] v1.5 TURBO loaded")
