--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.1 - Drag Drive Simulator [WindUI]
-- COURIER AUTOFARM EDITION
-- 100% Anti-Cheat Safe (uses only fireproximityprompt)
-- Tabs: Info | Automation | Utility
--═══════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local Workspace         = game:GetService("Workspace")
local CoreGui           = game:GetService("CoreGui")
local TweenService      = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

local LocalPlayer = Players.LocalPlayer

pcall(function()
    LocalizationService.RobloxLocaleId = "en-us"
end)

local INSTANCE_KEY = "__X0DEC04T_DDS_v11"
if _G[INSTANCE_KEY] then
    pcall(function() _G[INSTANCE_KEY].destroy() end)
    _G[INSTANCE_KEY] = nil
    task.wait(0.15)
end

-- WINDUI
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
    Version = "0.0.1",
    Author  = "voixera",
    LogoId  = "rbxassetid://85855925276969",
    Discord = "discord.gg/x0dec04t",
}

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    -- Courier Autofarm
    AutoCourier = false,
    CourierMode = "Instant",  -- Instant / Fast / Legit
    CourierDelay = 0.5,
    AutoEquipBox = true,

    -- Stats
    DeliveriesDone = 0,
    SessionMoney = 0,
    LastMoneyRaw = 0,
    SessionStartTime = tick(),
    CurrentStatus = "Idle",

    -- Utility
    WalkSpeedEnabled = false,
    WalkSpeedValue = 30,
    DefaultWalkSpeed = 16,
    NoclipEnabled = false,

    -- Anti AFK
    AntiAFK = true,

    -- UI
    Notifications = true,
    UIOpen = true,
    LogoGui = nil,

    -- Runtime
    CourierRunning = false,
    NoclipConn = nil,
}

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
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

-- ═══════════════════════════════════════════
-- ANTI AFK
-- ═══════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    if State.AntiAFK then
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.zero)
        end)
    end
end)

-- ═══════════════════════════════════════════
-- MONEY DETECTION
-- ═══════════════════════════════════════════
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
            if val > 1000 then
                return d
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════
-- COURIER SYSTEM
-- ═══════════════════════════════════════════
local function GetLivrason()
    return Workspace:FindFirstChild("Livrason")
end

local function GetTakePrompt()
    local liv = GetLivrason()
    if not liv then return nil end
    local take1 = liv:FindFirstChild("Take1")
    if not take1 then return nil end
    local take = take1:FindFirstChild("Take")
    if not take then return nil end
    return take:FindFirstChildWhichIsA("ProximityPrompt"), take
end

local function GetLocationFolder()
    local liv = GetLivrason()
    if not liv then return nil end
    return liv:FindFirstChild("Location")
end

local function GetActiveLocation()
    -- Returns the Location whose prompt is Enabled
    local locFolder = GetLocationFolder()
    if not locFolder then return nil, nil end
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
    -- Check if tool is equipped in character
    for _, c in ipairs(ch:GetChildren()) do
        if c:IsA("Tool") then
            local n = c.Name:lower()
            if n:find("box") or n:find("package") or n:find("parcel") or n:find("delivery") then
                return true, c
            end
        end
    end
    -- Also check any tool
    local anyTool = ch:FindFirstChildWhichIsA("Tool")
    if anyTool then return true, anyTool end
    return false
end

local function HasBoxInBackpack()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return false end
    for _, c in ipairs(bp:GetChildren()) do
        if c:IsA("Tool") then
            local n = c.Name:lower()
            if n:find("box") or n:find("package") or n:find("parcel") or n:find("delivery") then
                return true, c
            end
        end
    end
    local anyTool = bp:FindFirstChildWhichIsA("Tool")
    if anyTool then return true, anyTool end
    return false
end

local function EquipBoxIfNeeded()
    local hasEquipped = HasBoxTool()
    if hasEquipped then return true end
    local hasInBp, tool = HasBoxInBackpack()
    if hasInBp and tool then
        local ch = Char()
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function() h:EquipTool(tool) end)
            task.wait(0.3)
            return HasBoxTool()
        end
    end
    return false
end

local function SafeTeleport(cframe)
    local hrp = HRP()
    if not hrp then return false end
    local ch = Char()
    -- If sitting in vehicle, teleport the vehicle
    local hum = Hum()
    if hum and hum.SeatPart then
        local seat = hum.SeatPart
        local vehicleModel = seat:FindFirstAncestorOfClass("Model")
        if vehicleModel and vehicleModel.PrimaryPart then
            pcall(function() vehicleModel:SetPrimaryPartCFrame(cframe) end)
            return true
        elseif seat then
            pcall(function() seat.CFrame = cframe end)
            return true
        end
    end
    pcall(function() hrp.CFrame = cframe end)
    return true
end

local function WalkTo(position, maxTime)
    local hum = Hum()
    local hrp = HRP()
    if not hum or not hrp then return false end
    maxTime = maxTime or 15
    local startTime = tick()
    hum:MoveTo(position)
    while (hrp.Position - position).Magnitude > 5 and (tick() - startTime) < maxTime do
        task.wait(0.2)
        if not State.AutoCourier then return false end
        hum:MoveTo(position)
    end
    return true
end

local function FirePrompt(prompt)
    if not prompt then return false end
    local ok = pcall(function()
        fireproximityprompt(prompt, 1)
    end)
    return ok
end

-- ═══════════════════════════════════════════
-- MAIN COURIER LOOP
-- ═══════════════════════════════════════════
local function StartCourier()
    if State.CourierRunning then return end
    State.CourierRunning = true

    task.spawn(function()
        while State.AutoCourier do
            local liv = GetLivrason()
            if not liv then
                State.CurrentStatus = "Livrason folder not found"
                task.wait(2)
            else
                -- Check if we have a box (means job in progress)
                local hasBox = HasBoxTool() or HasBoxInBackpack()

                if not hasBox then
                    -- Step 1: Go to Take1 to start job
                    State.CurrentStatus = "Going to basecamp..."
                    local takePrompt, takePart = GetTakePrompt()
                    if takePrompt and takePart then
                        if State.CourierMode == "Instant" or State.CourierMode == "Fast" then
                            SafeTeleport(takePart.CFrame + Vector3.new(0, 5, 0))
                            task.wait(0.5)
                        else
                            WalkTo(takePart.Position, 30)
                        end
                        State.CurrentStatus = "Picking up package..."
                        task.wait(0.3)
                        FirePrompt(takePrompt)
                        task.wait(1.5)  -- wait for tool to appear
                    else
                        State.CurrentStatus = "Waiting for Take1 prompt..."
                        task.wait(1)
                    end
                else
                    -- Step 2: Equip box if in backpack
                    if State.AutoEquipBox then
                        EquipBoxIfNeeded()
                    end

                    -- Step 3: Find active delivery location
                    local locPrompt, locBlock, locName = GetActiveLocation()
                    if locPrompt and locBlock then
                        State.CurrentStatus = "Delivering to Location " .. locName
                        if State.CourierMode == "Instant" then
                            SafeTeleport(locBlock.CFrame + Vector3.new(0, 5, 0))
                            task.wait(0.5)
                        elseif State.CourierMode == "Fast" then
                            SafeTeleport(locBlock.CFrame + Vector3.new(0, 5, -8))
                            task.wait(0.3)
                            WalkTo(locBlock.Position, 5)
                        else -- Legit
                            WalkTo(locBlock.Position, 60)
                        end

                        -- Ensure equipped before firing
                        EquipBoxIfNeeded()
                        task.wait(0.3)

                        State.CurrentStatus = "Delivering..."
                        FirePrompt(locPrompt)
                        task.wait(1.5)

                        -- Check if delivered (box gone)
                        if not HasBoxTool() and not HasBoxInBackpack() then
                            State.DeliveriesDone = State.DeliveriesDone + 1
                            State.CurrentStatus = "Delivered! Total: " .. State.DeliveriesDone
                            task.wait(State.CourierDelay)
                        else
                            State.CurrentStatus = "Delivery may have failed, retrying..."
                            task.wait(1)
                        end
                    else
                        State.CurrentStatus = "Waiting for destination..."
                        task.wait(1)
                    end
                end
            end
            task.wait(0.1)
        end
        State.CurrentStatus = "Autofarm stopped"
        State.CourierRunning = false
    end)
end

local function StopCourier()
    State.AutoCourier = false
    State.CurrentStatus = "Stopped"
end

-- ═══════════════════════════════════════════
-- UTILITY: WALKSPEED
-- ═══════════════════════════════════════════
local function ApplyWalkSpeed()
    local h = Hum()
    if h then
        pcall(function()
            h.WalkSpeed = State.WalkSpeedEnabled and State.WalkSpeedValue or State.DefaultWalkSpeed
        end)
    end
end

-- ═══════════════════════════════════════════
-- UTILITY: NOCLIP
-- ═══════════════════════════════════════════
local function ApplyNoclip()
    if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end); State.NoclipConn = nil end
    if not State.NoclipEnabled then
        local ch = Char()
        if ch then
            for _, p in ipairs(ch:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
            end
        end
        return
    end
    State.NoclipConn = RunService.Stepped:Connect(function()
        if not State.NoclipEnabled then return end
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

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.5)
    if State.WalkSpeedEnabled then ApplyWalkSpeed() end
    if State.NoclipEnabled then ApplyNoclip() end
end)

-- ═══════════════════════════════════════════
-- MONEY TRACKER
-- ═══════════════════════════════════════════
task.spawn(function()
    task.wait(3)
    local lbl = FindMoneyLabel()
    if lbl then State.LastMoneyRaw = ParseMoney(lbl.Text) end
    while true do
        task.wait(1.5)
        if not lbl or not lbl.Parent then lbl = FindMoneyLabel() end
        if lbl then
            local cur = ParseMoney(lbl.Text)
            if State.LastMoneyRaw == 0 then
                State.LastMoneyRaw = cur
            elseif cur > State.LastMoneyRaw then
                State.SessionMoney = State.SessionMoney + (cur - State.LastMoneyRaw)
                State.LastMoneyRaw = cur
            elseif cur < State.LastMoneyRaw then
                State.LastMoneyRaw = cur
            end
        end
    end
end)

-- ═══════════════════════════════════════════
-- WINDUI SETUP
-- ═══════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title = HUB.Name,
    Icon = "truck",
    Author = HUB.Author .. " | " .. HUB.Game,
    Folder = "X0DEC04T_DDS",
    Size = UDim2.fromOffset(580, 420),
    Transparent = true,
    Theme = "Dark",
    SideBarWidth = 150,
    HideSearchBar = false,
    ScrollBarEnabled = true,
    KeySystem = false,
    Language = "en",
})

Window:EditOpenButton({
    Title = HUB.Name, Icon = "truck",
    Enabled = false, Draggable = true,
})

-- ═══════════════════════════════════════════
-- FLOATING LOGO
-- ═══════════════════════════════════════════
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
    btn.MouseEnter:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {Size = UDim2.new(0, 70, 0, 70)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(container, TweenInfo.new(0.15), {Size = UDim2.new(0, 60, 0, 60)}):Play()
    end)
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

-- ═══════════════════════════════════════════
-- TABS
-- ═══════════════════════════════════════════
local Tabs = {
    Info       = Window:Tab({ Title = "Info",       Icon = "info" }),
    Automation = Window:Tab({ Title = "Automation", Icon = "zap" }),
    Utility    = Window:Tab({ Title = "Utility",    Icon = "wrench" }),
}

-- ═══════════════════════════════════════════
-- INFO TAB
-- ═══════════════════════════════════════════
Tabs.Info:Section({ Title = "About" })
Tabs.Info:Paragraph({
    Title = HUB.Name .. " v" .. HUB.Version,
    Desc = "Game: " .. HUB.Game
        .. "\nDeveloper: " .. HUB.Author
        .. "\nMode: FULL AUTO Courier"
})

Tabs.Info:Section({ Title = "Live Stats" })
local statsPara = Tabs.Info:Paragraph({
    Title = "Session Stats",
    Desc = "Loading..."
})
local statusPara = Tabs.Info:Paragraph({
    Title = "Current Status",
    Desc = "Idle"
})

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            local elapsed = math.floor(tick() - State.SessionStartTime)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            local rate = 0
            if State.DeliveriesDone > 0 and elapsed > 0 then
                rate = math.floor((State.DeliveriesDone / elapsed) * 3600)
            end
            local moneyRate = 0
            if State.SessionMoney > 0 and elapsed > 0 then
                moneyRate = math.floor((State.SessionMoney / elapsed) * 3600)
            end
            local moneyLbl = FindMoneyLabel()
            local curMoney = moneyLbl and moneyLbl.Text or "?"

            local text = "Total Money: " .. curMoney
                .. "\nEarned Session: Rp. " .. State.SessionMoney
                .. "\nDeliveries: " .. State.DeliveriesDone
                .. "\nRate: " .. rate .. " deliv/hr | Rp. " .. moneyRate .. "/hr"
                .. "\nSession: " .. string.format("%02d:%02d", mins, secs)
                .. "\nPing: " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms"
            if statsPara and statsPara.SetDesc then
                pcall(function() statsPara:SetDesc(text) end)
            end
            if statusPara and statusPara.SetDesc then
                pcall(function() statusPara:SetDesc(State.CurrentStatus) end)
            end
        end)
    end
end)

Tabs.Info:Section({ Title = "How To Use" })
Tabs.Info:Paragraph({
    Title = "Quick Guide",
    Desc = "1. Go to Automation tab\n"
        .. "2. Choose mode (Instant recommended)\n"
        .. "3. Turn ON Auto Courier\n"
        .. "4. Watch the money roll in!\n\n"
        .. "The bot handles EVERYTHING:\n"
        .. "- Pickup box at Take1\n"
        .. "- Equip the box\n"
        .. "- Teleport to destination\n"
        .. "- Deliver the box\n"
        .. "- Loop forever"
})

Tabs.Info:Section({ Title = "Community" })
Tabs.Info:Button({
    Title = "Copy Discord",
    Callback = function()
        if setclipboard then setclipboard(HUB.Discord) end
        Notify("Discord", "Copied: " .. HUB.Discord, 3)
    end
})

-- ═══════════════════════════════════════════
-- AUTOMATION TAB
-- ═══════════════════════════════════════════
Tabs.Automation:Section({ Title = "Courier Autofarm" })

Tabs.Automation:Paragraph({
    Title = "Full Auto Delivery",
    Desc = "Automatically picks up packages,\nteleports to destination, and delivers.\n100% hands-free!"
})

Tabs.Automation:Dropdown({
    Title = "Mode",
    Values = { "Instant", "Fast", "Legit" },
    Value = "Instant",
    Callback = function(v)
        State.CourierMode = v
        Notify("Mode", "Set to: " .. v, 2)
    end
})

Tabs.Automation:Slider({
    Title = "Delay Between Deliveries (sec)",
    Value = { Min = 0, Max = 5, Default = 1 },
    Callback = function(v)
        State.CourierDelay = tonumber(v) or 0.5
    end
})

Tabs.Automation:Toggle({
    Title = "Auto Equip Box",
    Desc = "Auto-equip box from backpack",
    Default = true,
    Callback = function(v) State.AutoEquipBox = v end
})

Tabs.Automation:Toggle({
    Title = "Auto Courier",
    Desc = "MAIN TOGGLE - starts autofarm",
    Default = false,
    Callback = function(v)
        State.AutoCourier = v
        if v then
            StartCourier()
            Notify("Auto Courier", "STARTED - Full auto mode", 3)
        else
            StopCourier()
            Notify("Auto Courier", "STOPPED", 2)
        end
    end
})

Tabs.Automation:Section({ Title = "Mode Descriptions" })
Tabs.Automation:Paragraph({
    Title = "Instant Mode",
    Desc = "Teleport directly to Take1 & Location\nFastest — ~5 sec per delivery"
})
Tabs.Automation:Paragraph({
    Title = "Fast Mode",
    Desc = "Teleport near, walk last few studs\nSafer, ~10 sec per delivery"
})
Tabs.Automation:Paragraph({
    Title = "Legit Mode",
    Desc = "Walk/drive to destinations\nMost natural, slowest"
})

Tabs.Automation:Section({ Title = "Stats" })
Tabs.Automation:Button({
    Title = "Reset Counter",
    Callback = function()
        State.DeliveriesDone = 0
        State.SessionMoney = 0
        State.SessionStartTime = tick()
        local lbl = FindMoneyLabel()
        State.LastMoneyRaw = lbl and ParseMoney(lbl.Text) or 0
        Notify("Stats", "Reset complete", 2)
    end
})

-- ═══════════════════════════════════════════
-- UTILITY TABS
-- ═══════════════════════════════════════════
Tabs.Utility:Section({ Title = "Movement" })

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
    Callback = function(v)
        State.WalkSpeedEnabled = v
        ApplyWalkSpeed()
    end
})

Tabs.Utility:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls",
    Default = false,
    Callback = function(v)
        State.NoclipEnabled = v
        ApplyNoclip()
    end
})

Tabs.Utility:Section({ Title = "Teleports" })

Tabs.Utility:Button({
    Title = "TP to Courier Basecamp (Take1)",
    Callback = function()
        local _, takePart = GetTakePrompt()
        if takePart then
            SafeTeleport(takePart.CFrame + Vector3.new(0, 5, 0))
            Notify("Teleport", "At basecamp", 2)
        else
            Notify("Teleport", "Take1 not found", 3)
        end
    end
})

Tabs.Utility:Button({
    Title = "TP to Active Delivery Location",
    Callback = function()
        local _, block, name = GetActiveLocation()
        if block then
            SafeTeleport(block.CFrame + Vector3.new(0, 5, 0))
            Notify("Teleport", "At Location " .. name, 2)
        else
            Notify("Teleport", "No active location", 3)
        end
    end
})

Tabs.Utility:Button({
    Title = "TP to Free Coffee (nearest)",
    Callback = function()
        local hrp = HRP()
        if not hrp then return end
        local best, bd = nil, math.huge
        for _, m in ipairs(Workspace:GetChildren()) do
            if m.Name == "PinewoodCoffeeMachine" then
                local part = m:FindFirstChild("InteractiveScreen") or m:FindFirstChildWhichIsA("BasePart")
                if part then
                    local d = (part.Position - hrp.Position).Magnitude
                    if d < bd then bd = d; best = part end
                end
            end
        end
        if best then
            SafeTeleport(best.CFrame + Vector3.new(0, 5, 0))
            Notify("Teleport", "At coffee machine", 2)
        end
    end
})

Tabs.Utility:Button({
    Title = "TP to BOB (Daily Code)",
    Callback = function()
        SafeTeleport(CFrame.new(-646, 5, -679))
        Notify("Teleport", "At BOB", 2)
    end
})

Tabs.Utility:Section({ Title = "Anti AFK" })
Tabs.Utility:Toggle({
    Title = "Anti AFK",
    Default = true,
    Callback = function(v) State.AntiAFK = v end
})

Tabs.Utility:Section({ Title = "UI" })
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

Tabs.Utility:Section({ Title = "Danger Zone" })
Tabs.Utility:Button({
    Title = "Unload Hub",
    Callback = function()
        StopCourier()
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        local h = Hum(); if h then pcall(function() h.WalkSpeed = State.DefaultWalkSpeed end) end
        _G[INSTANCE_KEY] = nil
        pcall(function() Window:Destroy() end)
    end
})

-- ═══════════════════════════════════════════
-- FINISH
-- ═══════════════════════════════════════════
_G[INSTANCE_KEY] = {
    version = HUB.Version,
    destroy = function()
        StopCourier()
        if State.NoclipConn then pcall(function() State.NoclipConn:Disconnect() end) end
        if State.LogoGui then pcall(function() State.LogoGui:Destroy() end) end
        pcall(function() Window:Destroy() end)
    end,
}

Notify(HUB.Name, "v" .. HUB.Version .. " Is Loaded!", 5)
print("[X0DEC04T] v0.0.1 Loaded successfully")
