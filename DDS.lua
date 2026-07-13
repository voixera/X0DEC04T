--═══════════════════════════════════════════════════════════════
-- X0DEC04T Hub v1.4 - Drag Drive Simulator [WindUI]
-- 🚀 HRP TWEEN AUTO-DRIVE (bypasses A-Chassis physics)
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

local INSTANCE_KEY = "__X0DEC04T_DDS_v14"
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
    Version = "1.4",
    Author  = "voixera",
    LogoId  = "rbxassetid://91626851418651",
    Discord = "discord.gg/x0dec04t",
}

local State = {
    AutoCourier = false,
    MinDelay = 3,
    MaxDelay = 6,
    TravelSpeed = 80,
    HoverHeight = 5,
    UseBike = true,           -- true = tween while on bike, false = dismount and tween char
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
            task.wait(0.4)
            return HasBoxTool()
        end
    end
    return false
end

local function GetSeat()
    local h = Hum()
    if h and h.SeatPart and h.SeatPart:IsA("VehicleSeat") then
        return h.SeatPart
    end
    return nil
end

local function IsInVehicle() return GetSeat() ~= nil end

local function FindMyMotorcycle()
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m.Name:find(LocalPlayer.Name) and m:FindFirstChild("DriveSeat") then
            return m
        end
    end
    return nil
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
            task.wait(0.5)
        end
    end
end

-- ═══════════════════════════════════════════
-- NOCLIP
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
    end)
end

-- ═══════════════════════════════════════════
-- HRP TWEEN (THE MAGIC!)
-- Tweens character's HumanoidRootPart - bike follows automatically since seated
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

    local travelTime = distance / State.TravelSpeed
    travelTime = math.max(travelTime, 0.3)

    -- Face direction of travel
    local dir = (targetFlat - currentPos).Unit
    local lookTarget = targetFlat + Vector3.new(dir.X, 0, dir.Z) * 10
    local targetCF = CFrame.new(targetFlat, Vector3.new(lookTarget.X, targetFlat.Y, lookTarget.Z))

    local info = TweenInfo.new(travelTime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(hrp, info, { CFrame = targetCF })

    State.ActiveTween = tween
    tween:Play()

    local startTime = tick()
    while tween.PlaybackState == Enum.PlaybackState.Playing do
        if not State.AutoCourier then tween:Cancel(); return false end
        if tick() - startTime > travelTime + 5 then tween:Cancel(); break end
        task.wait(0.1)
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
    if dist > 20 then return false end
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
                -- STEP 1: Go to Take1
                local takePrompt, takePart = GetTakePrompt()
                if not takePrompt or not takePart then
                    State.CurrentStatus = "⏳ Waiting for Take1..."
                    task.wait(2)
                else
                    -- Optionally mount bike (visual only)
                    if State.UseBike and not IsInVehicle() then
                        State.CurrentStatus = "🏍️ Mounting..."
                        MountMotorcycle()
                        task.wait(0.5)
                    end

                    State.CurrentStatus = "🚚 Tween to basecamp..."
                    TweenTo(takePart.Position)
                    task.wait(0.4)

                    if IsInVehicle() then
                        State.CurrentStatus = "🛑 Dismounting..."
                        
