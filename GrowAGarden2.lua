local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Lighting = game:GetService("Lighting"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    VirtualUser = game:GetService("VirtualUser"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    CoreGui = game:GetService("CoreGui"),
    StarterGui = game:GetService("StarterGui")
}

local LocalPlayer = Services.Players.LocalPlayer

local WindUI
do
    local urls = {
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua"
    }
    for _, url in ipairs(urls) do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url, true))()
        end)
        if ok and result then
            WindUI = result
            break
        end
    end
end

if not WindUI then
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "X0DEC04T Hub",
            Text = "Failed to load WindUI.",
            Duration = 10
        })
    end)
    return
end

local ScriptData = {
    Connections = {},
    Loops = {},
    ESPObjects = {},
    UIVisible = false,
    WindUIGui = nil,
    MinimizeGui = nil,
    OriginalValues = {
        WalkSpeed = 16,
        JumpPower = 50,
        Gravity = 196.2,
        Brightness = Services.Lighting.Brightness,
        ClockTime = Services.Lighting.ClockTime,
        FogEnd = Services.Lighting.FogEnd,
        GlobalShadows = Services.Lighting.GlobalShadows
    },
    Config = {
        Main = {
            AutoHarvest = false, AutoPlant = false, AutoWater = false,
            AutoSell = false, AutoBuySeeds = false, AutoBuyGear = false,
            AutoCollectDrops = false, AutoQuest = false, AutoUpgrade = false,
            AutoRebirth = false, AutoClaimRewards = false, AutoEvent = false,
            AutoGift = false, AutoFertilize = false,
            SelectedSeed = "Carrot", SelectedGear = "Basic Watering Can"
        },
        Player = {
            WalkSpeed = 16, JumpPower = 50, Gravity = 196.2,
            Fly = false, FlySpeed = 50, NoClip = false,
            InfiniteJump = false, AntiAFK = false,
            Spinbot = false, SpinbotSpeed = 10
        },
        Visual = {
            PlayerESP = false, SeedESP = false, FruitESP = false,
            ItemESP = false, NPCESP = false, ChestESP = false,
            Fullbright = false
        },
        Settings = {AutoSave = false}
    }
}

local GameCache = {
    Garden = nil, Shop = nil, NPCs = {}, Spawn = nil,
    Plants = {}, Drops = {}, Remotes = {}, Plots = {}, SellArea = nil
}

local function SafeCall(fn)
    local ok, err = pcall(fn)
    if not ok then warn("[X0DEC04T]: " .. tostring(err)) end
    return ok
end

local function IsProtectedPath(obj)
    local cur = obj
    local depth = 0
    while cur and depth < 15 do
        local n = cur.Name:lower()
        if n:find("topbarplus") or n:find("clientmodules") or n:find("packages")
            or cur == Services.ReplicatedStorage
        then
            return true
        end
        cur = cur.Parent
        depth += 1
    end
    return false
end

local function AddConnection(name, conn)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
    end
    ScriptData.Connections[name] = conn
end

local function RemoveConnection(name)
    if ScriptData.Connections[name] then
        pcall(function() ScriptData.Connections[name]:Disconnect() end)
        ScriptData.Connections[name] = nil
    end
end

local function CreateLoop(name, fn, waitTime)
    if ScriptData.Loops[name] then
        ScriptData.Loops[name] = false
        task.wait(0.1)
    end
    ScriptData.Loops[name] = true
    task.spawn(function()
        while ScriptData.Loops[name] do
            local ok, err = pcall(fn)
            if not ok then warn("Loop[" .. name .. "]: " .. err) end
            task.wait(waitTime or 0.1)
        end
    end)
end

local function StopLoop(name)
    ScriptData.Loops[name] = false
end

local function GetChar() return LocalPlayer.Character end
local function GetHum()
    local c = GetChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function GetRoot()
    local c = GetChar()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

local function TeleportTo(pos)
    local r = GetRoot()
    if r then r.CFrame = CFrame.new(pos) end
end

local function FindFirst(parent, name, class)
    if not parent or IsProtectedPath(parent) then return nil end
    for _, d in ipairs(parent:GetDescendants()) do
        if not IsProtectedPath(d) then
            local nm = not name or d.Name:lower():find(name:lower())
            local cl = not class or d:IsA(class)
            if nm and cl then return d end
        end
    end
    return nil
end

local function FindAll(parent, name, class)
    local r = {}
    if not parent or IsProtectedPath(parent) then return r end
    for _, d in ipairs(parent:GetDescendants()) do
        if not IsProtectedPath(d) then
            local nm = not name or d.Name:lower():find(name:lower())
            local cl = not class or d:IsA(class)
            if nm and cl then table.insert(r, d) end
        end
    end
    return r
end

local function GetRemote(name)
    if GameCache.Remotes[name] then return GameCache.Remotes[name] end
    local r = nil
    pcall(function()
        for _, d in ipairs(Services.ReplicatedStorage:GetDescendants()) do
            if d.Name:lower() == name:lower() and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                r = d
                break
            end
        end
    end)
    if r then GameCache.Remotes[name] = r end
    return r
end

local function Fire(name, ...)
    local args = {...}
    local remote = GetRemote(name)
    if remote then
        pcall(function()
            if remote:IsA("RemoteEvent") then remote:FireServer(table.unpack(args))
            elseif remote:IsA("RemoteFunction") then remote:InvokeServer(table.unpack(args)) end
        end)
        return true
    end
    return false
end

local function FindPlots()
    local plots = {}
    local parents = {
        workspace:FindFirstChild("PlayerPlots"),
        workspace:FindFirstChild("Plots"),
        workspace:FindFirstChild("Gardens"),
        workspace:FindFirstChild(LocalPlayer.Name)
    }
    for _, p in ipairs(parents) do
        if p then
            for _, obj in ipairs(p:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("plot") or obj:FindFirstChild("Soil")) then
                    table.insert(plots, obj)
                end
            end
        end
    end
    return plots
end

local function FindPlants()
    local plants = {}
    for _, plot in ipairs(FindPlots()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("plant") then
                table.insert(plants, obj)
            end
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("plant") and obj:FindFirstChild("Stem") then
            table.insert(plants, obj)
        end
    end
    return plants
end

local function UpdateCache()
    task.spawn(function()
        GameCache.Garden = workspace:FindFirstChild("Garden") or workspace:FindFirstChild("PlayerGarden") or workspace:FindFirstChild("PlayerPlots")
        GameCache.Shop = workspace:FindFirstChild("Shop") or workspace:FindFirstChild("Store") or FindFirst(workspace, "shop", "Model")
        GameCache.SellArea = workspace:FindFirstChild("SellArea") or workspace:FindFirstChild("Sell") or FindFirst(workspace, "sell", "Model")
        GameCache.Spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
        GameCache.Plots = FindPlots()
        GameCache.Plants = FindPlants()
        GameCache.NPCs = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not IsProtectedPath(obj) and obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj.Name:lower():find("npc") then
                table.insert(GameCache.NPCs, obj)
            end
        end
        GameCache.Drops = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not IsProtectedPath(obj) and obj:IsA("BasePart") then
                local n = obj.Name:lower()
                if n:find("drop") or n:find("coin") or n:find("money") then
                    table.insert(GameCache.Drops, obj)
                end
            end
        end
    end)
end

local function MakeESP(object, text, color)
    if not object then return end
    local key = tostring(object)
    if ScriptData.ESPObjects[key] then return end
    local tgt = object
    if object:IsA("Model") then
        tgt = object:FindFirstChild("HumanoidRootPart") or object:FindFirstChild("Head") or object:FindFirstChildWhichIsA("BasePart")
    end
    if not tgt then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "X0D_ESP"
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 100, 0, 50)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = tgt
    local lb = Instance.new("TextLabel")
    lb.Size = UDim2.new(1, 0, 1, 0)
    lb.BackgroundTransparency = 1
    lb.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    lb.TextStrokeTransparency = 0.5
    lb.Text = text or object.Name
    lb.TextScaled = true
    lb.Font = Enum.Font.GothamBold
    lb.Parent = bb
    ScriptData.ESPObjects[key] = bb
    pcall(function()
        local hl = Instance.new("Highlight")
        hl.FillColor = color or Color3.fromRGB(255, 255, 255)
        hl.OutlineColor = color or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.5
        hl.Parent = object
        ScriptData.ESPObjects[key .. "_hl"] = hl
    end)
end

local function RemoveESP(obj)
    local k = tostring(obj)
    if ScriptData.ESPObjects[k] then pcall(function() ScriptData.ESPObjects[k]:Destroy() end) ScriptData.ESPObjects[k] = nil end
    if ScriptData.ESPObjects[k .. "_hl"] then pcall(function() ScriptData.ESPObjects[k .. "_hl"]:Destroy() end) ScriptData.ESPObjects[k .. "_hl"] = nil end
end

local function ClearESP()
    for _, e in pairs(ScriptData.ESPObjects) do pcall(function() e:Destroy() end) end
    ScriptData.ESPObjects = {}
end

local function SaveCfg(name)
    name = name or "default"
    if not writefile then return false end
    local ok, res = pcall(function() return Services.HttpService:JSONEncode(ScriptData.Config) end)
    if ok then pcall(function() writefile("X0D_GAG2_" .. name .. ".json", res) end) return true end
    return false
end

local function LoadCfg(name)
    name = name or "default"
    local f = "X0D_GAG2_" .. name .. ".json"
    if not (isfile and isfile(f) and readfile) then return false end
    local ok, res = pcall(function() return Services.HttpService:JSONDecode(readfile(f)) end)
    if ok and res then
        for cat, settings in pairs(res) do
            if ScriptData.Config[cat] then
                for k, v in pairs(settings) do ScriptData.Config[cat][k] = v end
            end
        end
        return true
    end
    return false
end

local function Notify(title, msg, dur)
    pcall(function()
        WindUI:Notify({ Title = title, Content = msg, Duration = dur or 3 })
    end)
end

UpdateCache()

local existingGui = {}
for _, g in ipairs(Services.CoreGui:GetChildren()) do existingGui[g] = true end
for _, g in ipairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do existingGui[g] = true end

local Window
SafeCall(function()
    Window = WindUI:CreateWindow({
        Title = "X0DEC04T Hub",
        SubTitle = "Grow a Garden 2",
        Icon = "rbxassetid://94393427540369",
        Author = "voixera",
        Folder = "X0DEC04THub",
        Size = UDim2.fromOffset(580, 460),
        Transparent = true,
        Theme = "Dark",
        Resizable = false
    })
end)

if not Window then
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "X0DEC04T Hub",
            Text = "Failed to create window.",
            Duration = 10
        })
    end)
    return
end

task.wait(0.3)

for _, g in ipairs(Services.CoreGui:GetChildren()) do
    if not existingGui[g] and g:IsA("ScreenGui") then
        ScriptData.WindUIGui = g
        break
    end
end
if not ScriptData.WindUIGui then
    for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if not existingGui[g] and g:IsA("ScreenGui") then
            ScriptData.WindUIGui = g
            break
        end
    end
end

if ScriptData.WindUIGui then
    ScriptData.WindUIGui.Enabled = false
    ScriptData.UIVisible = false
end

local function BuildHubButton()
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0D_HubButton"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 9999
    if gethui then
        sg.Parent = gethui()
    else
        pcall(function() sg.Parent = Services.CoreGui end)
        if not sg.Parent or sg.Parent ~= Services.CoreGui then
            sg.Parent = LocalPlayer.PlayerGui
        end
    end

    local outerBtn = Instance.new("Frame")
    outerBtn.Name = "OuterFrame"
    outerBtn.Size = UDim2.new(0, 90, 0, 90)
    outerBtn.Position = UDim2.new(0, 20, 0.5, -45)
    outerBtn.BackgroundTransparency = 1
    outerBtn.Parent = sg

    local circleBack = Instance.new("Frame")
    circleBack.Name = "CircleBack"
    circleBack.Size = UDim2.new(1, 0, 1, 0)
    circleBack.BackgroundColor3 = Color3.fromRGB(0, 195, 210)
    circleBack.BorderSizePixel = 0
    circleBack.Parent = outerBtn

    local cornerBack = Instance.new("UICorner")
    cornerBack.CornerRadius = UDim.new(1, 0)
    cornerBack.Parent = circleBack

    local gradBack = Instance.new("UIGradient")
    gradBack.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 210, 230)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 180))
    }
    gradBack.Rotation = 135
    gradBack.Parent = circleBack

    local innerCircle = Instance.new("Frame")
    innerCircle.Name = "InnerCircle"
    innerCircle.Size = UDim2.new(0.82, 0, 0.82, 0)
    innerCircle.Position = UDim2.new(0.09, 0, 0.09, 0)
    innerCircle.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    innerCircle.BorderSizePixel = 0
    innerCircle.Parent = circleBack

    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(1, 0)
    innerCorner.Parent = innerCircle

    local topText = Instance.new("TextLabel")
    topText.Name = "TopText"
    topText.Size = UDim2.new(1, 0, 0.45, 0)
    topText.Position = UDim2.new(0, 0, 0.08, 0)
    topText.BackgroundTransparency = 1
    topText.Text = "X0D"
    topText.TextColor3 = Color3.fromRGB(255, 255, 255)
    topText.TextScaled = true
    topText.Font = Enum.Font.GothamBold
    topText.Parent = innerCircle

    local bottomText = Instance.new("TextLabel")
    bottomText.Name = "BottomText"
    bottomText.Size = UDim2.new(1, 0, 0.3, 0)
    bottomText.Position = UDim2.new(0, 0, 0.58, 0)
    bottomText.BackgroundTransparency = 1
    bottomText.Text = "HUB"
    bottomText.TextColor3 = Color3.fromRGB(255, 255, 255)
    bottomText.TextScaled = true
    bottomText.Font = Enum.Font.GothamBold
    bottomText.Parent = innerCircle

    local clickBtn = Instance.new("TextButton")
    clickBtn.Name = "ClickBtn"
    clickBtn.Size = UDim2.new(1, 0, 1, 0)
    clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""
    clickBtn.Parent = outerBtn

    local clickCorner = Instance.new("UICorner")
    clickCorner.CornerRadius = UDim.new(1, 0)
    clickCorner.Parent = clickBtn

    local pulseFrame = Instance.new("Frame")
    pulseFrame.Name = "Pulse"
    pulseFrame.Size = UDim2.new(1, 0, 1, 0)
    pulseFrame.BackgroundColor3 = Color3.fromRGB(0, 210, 230)
    pulseFrame.BackgroundTransparency = 0.7
    pulseFrame.BorderSizePixel = 0
    pulseFrame.ZIndex = 0
    pulseFrame.Parent = outerBtn

    local pulseCorner = Instance.new("UICorner")
    pulseCorner.CornerRadius = UDim.new(1, 0)
    pulseCorner.Parent = pulseFrame

    task.spawn(function()
        while sg.Parent do
            Services.TweenService:Create(pulseFrame, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = UDim2.new(1.4, 0, 1.4, 0),
                Position = UDim2.new(-0.2, 0, -0.2, 0),
                BackgroundTransparency = 1
            }):Play()
            task.wait(0.05)
            pulseFrame.Size = UDim2.new(1, 0, 1, 0)
            pulseFrame.Position = UDim2.new(0, 0, 0, 0)
            pulseFrame.BackgroundTransparency = 0.7
            task.wait(2)
        end
    end)

    local dragging, dragStart, startPos = false, nil, nil
    local clickTime = 0
    local hasMoved = false

    clickBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
            dragStart = inp.Position
            startPos = outerBtn.Position
            clickTime = tick()
        end
    end)

    Services.UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            if delta.Magnitude > 6 then hasMoved = true end
            outerBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    Services.UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if not hasMoved and tick() - clickTime < 0.35 then
                    ScriptData.UIVisible = not ScriptData.UIVisible
                    if ScriptData.WindUIGui then
                        ScriptData.WindUIGui.Enabled = ScriptData.UIVisible
                    end
                    local targetColor = ScriptData.UIVisible
                        and Color3.fromRGB(0, 210, 230)
                        or Color3.fromRGB(180, 50, 255)
                    Services.TweenService:Create(circleBack, TweenInfo.new(0.3), {
                        BackgroundColor3 = targetColor
                    }):Play()
                    Services.TweenService:Create(outerBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, 100, 0, 100)
                    }):Play()
                    task.delay(0.15, function()
                        Services.TweenService:Create(outerBtn, TweenInfo.new(0.15), {
                            Size = UDim2.new(0, 90, 0, 90)
                        }):Play()
                    end)
                end
            end
        end
    end)

    clickBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(outerBtn, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 98, 0, 98)
        }):Play()
    end)

    clickBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(outerBtn, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 90, 0, 90)
        }):Play()
    end)

    ScriptData.MinimizeGui = sg
    return sg
end

BuildHubButton()

local Tabs = {}
SafeCall(function() Tabs.Main = Window:Tab({ Title = "Main", Icon = "rbxassetid://10734950" }) end)
SafeCall(function() Tabs.Player = Window:Tab({ Title = "Player", Icon = "rbxassetid://10747372" }) end)
SafeCall(function() Tabs.Teleport = Window:Tab({ Title = "Teleport", Icon = "rbxassetid://10723407" }) end)
SafeCall(function() Tabs.Visual = Window:Tab({ Title = "Visual", Icon = "rbxassetid://10734896" }) end)
SafeCall(function() Tabs.Misc = Window:Tab({ Title = "Misc", Icon = "rbxassetid://10734949" }) end)
SafeCall(function() Tabs.Settings = Window:Tab({ Title = "Settings", Icon = "rbxassetid://10734952" }) end)
SafeCall(function() Tabs.Credits = Window:Tab({ Title = "Credits", Icon = "rbxassetid://10747373" }) end)

local Icons = {
    Harvest     = "🌾",
    Plant       = "🌱",
    Water       = "💧",
    Fertilize   = "🧪",
    Sell        = "💰",
    BuySeed     = "🛒",
    BuyGear     = "⚙️",
    Collect     = "✨",
    Quest       = "📜",
    Upgrade     = "⬆️",
    Rebirth     = "🔄",
    Claim       = "🎁",
    Event       = "🎉",
    Gift        = "🎀",
    Speed       = "🏃",
    Jump        = "⬆️",
    Gravity     = "🌍",
    Fly         = "✈️",
    FlySpeed    = "💨",
    NoClip      = "👻",
    InfJump     = "🦘",
    AntiAFK     = "🛡️",
    Spinbot     = "🌀",
    SpinSpeed   = "🔁",
    Reset       = "💀",
    Shop        = "🏪",
    Garden      = "🌻",
    Spawn       = "🏠",
    NPC         = "👤",
    Events      = "🎪",
    Player      = "👥",
    PlayerESP   = "🔴",
    SeedESP     = "🟢",
    FruitESP    = "🟠",
    ItemESP     = "🔵",
    NPCESP      = "🟡",
    ChestESP    = "🟤",
    Fullbright  = "☀️",
    Fog         = "🌫️",
    FPS         = "⚡",
    Effects     = "💥",
    ClearESP    = "🗑️",
    ServerHop   = "🔀",
    Rejoin      = "🔃",
    CopyJob     = "📋",
    CopyPlace   = "🔑",
    DestroyUI   = "🗑️",
    Save        = "💾",
    Load        = "📂",
    Delete      = "❌",
    AutoSave    = "🔒",
    ToggleUI    = "👁️",
    Credits     = "ℹ️",
    Discord     = "💬",
    SeedInput   = "🌿",
    GearInput   = "🔧"
}

local function MkToggle(tab, icon, name, flag, cb)
    SafeCall(function()
        tab:Toggle({
            Title = icon .. " " .. name,
            Default = false,
            Flag = flag,
            Callback = cb
        })
    end)
end

local function MkButton(tab, icon, name, cb)
    SafeCall(function()
        tab:Button({ Title = icon .. " " .. name, Callback = cb })
    end)
end

local function MkSlider(tab, icon, name, flag, min, max, def, cb)
    SafeCall(function()
        tab:Slider({
            Title = icon .. " " .. name,
            Flag = flag,
            Step = 1,
            Value = { Min = min, Max = max, Default = def },
            Callback = cb
        })
    end)
end

local function MkInput(tab, icon, name, placeholder, cb)
    SafeCall(function()
        tab:Input({
            Title = icon .. " " .. name,
            Placeholder = placeholder,
            Value = "",
            Callback = cb
        })
    end)
end

local function MkSection(tab, name)
    SafeCall(function() tab:Section({ Title = name }) end)
end

local function MkLabel(tab, text)
    SafeCall(function() tab:Label({ Title = text }) end)
end

local function MkParagraph(tab, title, desc)
    SafeCall(function() tab:Paragraph({ Title = title, Description = desc }) end)
end

local function MkDropdown(tab, icon, name, flag, list, cb)
    SafeCall(function()
        tab:Dropdown({
            Title = icon .. " " .. name,
            Flag = flag,
            Values = list,
            Callback = cb
        })
    end)
end

-- ========================
-- MAIN TAB
-- ========================
if Tabs.Main then
    MkSection(Tabs.Main, "🌾 Farming")

    MkToggle(Tabs.Main, Icons.Harvest, "Auto Harvest", "AutoHarvest", function(v)
        ScriptData.Config.Main.AutoHarvest = v
        if v then
            Notify(Icons.Harvest .. " Auto Harvest", "Enabled", 2)
            CreateLoop("AutoHarvest", function()
                for _, plant in ipairs(FindPlants()) do
                    if plant and plant.Parent then
                        local ready = plant:FindFirstChild("Ready") or plant:FindFirstChild("Harvestable") or plant:FindFirstChild("Grown")
                        if ready and ready.Value == true then
                            pcall(function()
                                local cd = FindFirst(plant, nil, "ClickDetector")
                                if cd then fireclickdetector(cd) end
                            end)
                            pcall(function()
                                local pp = FindFirst(plant, nil, "ProximityPrompt")
                                if pp then fireproximityprompt(pp) end
                            end)
                            Fire("HarvestPlant", plant)
                            Fire("Harvest", plant)
                            Fire("harvest", plant)
                        end
                    end
                end
            end, 0.5)
        else
            Notify(Icons.Harvest .. " Auto Harvest", "Disabled", 2)
            StopLoop("AutoHarvest")
        end
    end)

    MkToggle(Tabs.Main, Icons.Plant, "Auto Plant", "AutoPlant", function(v)
        ScriptData.Config.Main.AutoPlant = v
        if v then
            Notify(Icons.Plant .. " Auto Plant", "Enabled", 2)
            CreateLoop("AutoPlant", function()
                for _, plot in ipairs(FindPlots()) do
                    if plot and plot.Parent then
                        local isEmpty = plot:FindFirstChild("Empty") or plot:FindFirstChild("Available")
                        local hasPlant = FindFirst(plot, "plant", "Model")
                        if (isEmpty and isEmpty.Value == true) or (not hasPlant) then
                            pcall(function()
                                local cd = FindFirst(plot, nil, "ClickDetector")
                                if cd then fireclickdetector(cd) end
                            end)
                            pcall(function()
                                local pp = FindFirst(plot, nil, "ProximityPrompt")
                                if pp then fireproximityprompt(pp) end
                            end)
                            Fire("PlantSeed", plot, ScriptData.Config.Main.SelectedSeed)
                            Fire("Plant", plot, ScriptData.Config.Main.SelectedSeed)
                        end
                    end
                end
            end, 0.5)
        else
            Notify(Icons.Plant .. " Auto Plant", "Disabled", 2)
            StopLoop("AutoPlant")
        end
    end)

    MkToggle(Tabs.Main, Icons.Water, "Auto Water", "AutoWater", function(v)
        ScriptData.Config.Main.AutoWater = v
        if v then
            Notify(Icons.Water .. " Auto Water", "Enabled", 2)
            CreateLoop("AutoWater", function()
                for _, plant in ipairs(FindPlants()) do
                    if plant and plant.Parent then
                        pcall(function()
                            local cd = FindFirst(plant, nil, "ClickDetector")
                            if cd then fireclickdetector(cd) end
                        end)
                        pcall(function()
                            local pp = FindFirst(plant, nil, "ProximityPrompt")
                            if pp then fireproximityprompt(pp) end
                        end)
                        Fire("WaterPlant", plant)
                        Fire("Water", plant)
                    end
                end
            end, 0.5)
        else
            Notify(Icons.Water .. " Auto Water", "Disabled", 2)
            StopLoop("AutoWater")
        end
    end)

    MkToggle(Tabs.Main, Icons.Fertilize, "Auto Fertilize", "AutoFertilize", function(v)
        ScriptData.Config.Main.AutoFertilize = v
        if v then
            Notify(Icons.Fertilize .. " Auto Fertilize", "Enabled", 2)
            CreateLoop("AutoFertilize", function()
                for _, plant in ipairs(FindPlants()) do
                    if plant and plant.Parent then
                        Fire("FertilizePlant", plant)
                        Fire("Fertilize", plant)
                    end
                end
            end, 1)
        else
            Notify(Icons.Fertilize .. " Auto Fertilize", "Disabled", 2)
            StopLoop("AutoFertilize")
        end
    end)

    MkSection(Tabs.Main, "💰 Shop & Economy")

    MkInput(Tabs.Main, Icons.SeedInput, "Seed Name", "e.g. Carrot", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedSeed = v
            Notify(Icons.SeedInput .. " Seed Set", v, 2)
        end
    end)

    MkInput(Tabs.Main, Icons.GearInput, "Gear Name", "e.g. Basic Watering Can", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedGear = v
            Notify(Icons.GearInput .. " Gear Set", v, 2)
        end
    end)

    MkToggle(Tabs.Main, Icons.Sell, "Auto Sell", "AutoSell", function(v)
        ScriptData.Config.Main.AutoSell = v
        if v then
            Notify(Icons.Sell .. " Auto Sell", "Enabled", 2)
            CreateLoop("AutoSell", function()
                Fire("SellProduce")
                Fire("Sell")
                Fire("sell")
                if GameCache.SellArea then
                    local root = GetRoot()
                    if root then
                        local part = GameCache.SellArea:IsA("BasePart") and GameCache.SellArea or GameCache.SellArea:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local old = root.CFrame
                            root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.2)
                            root.CFrame = old
                        end
                    end
                end
            end, 2)
        else
            Notify(Icons.Sell .. " Auto Sell", "Disabled", 2)
            StopLoop("AutoSell")
        end
    end)

    MkToggle(Tabs.Main, Icons.BuySeed, "Auto Buy Seeds", "AutoBuySeeds", function(v)
        ScriptData.Config.Main.AutoBuySeeds = v
        if v then
            Notify(Icons.BuySeed .. " Auto Buy Seeds", "Enabled", 2)
            CreateLoop("AutoBuySeeds", function()
                Fire("BuySeed", ScriptData.Config.Main.SelectedSeed)
                Fire("PurchaseSeed", ScriptData.Config.Main.SelectedSeed)
            end, 3)
        else
            Notify(Icons.BuySeed .. " Auto Buy Seeds", "Disabled", 2)
            StopLoop("AutoBuySeeds")
        end
    end)

    MkToggle(Tabs.Main, Icons.BuyGear, "Auto Buy Gear", "AutoBuyGear", function(v)
        ScriptData.Config.Main.AutoBuyGear = v
        if v then
            Notify(Icons.BuyGear .. " Auto Buy Gear", "Enabled", 2)
            CreateLoop("AutoBuyGear", function()
                Fire("BuyGear", ScriptData.Config.Main.SelectedGear)
                Fire("PurchaseGear", ScriptData.Config.Main.SelectedGear)
            end, 3)
        else
            Notify(Icons.BuyGear .. " Auto Buy Gear", "Disabled", 2)
            StopLoop("AutoBuyGear")
        end
    end)

    MkSection(Tabs.Main, "⚡ Automation")

    MkToggle(Tabs.Main, Icons.Collect, "Auto Collect Drops", "AutoCollectDrops", function(v)
        ScriptData.Config.Main.AutoCollectDrops = v
        if v then
            Notify(Icons.Collect .. " Auto Collect", "Enabled", 2)
            CreateLoop("AutoCollectDrops", function()
                local root = GetRoot()
                if root then
                    for _, drop in ipairs(GameCache.Drops) do
                        if drop and drop.Parent and drop:IsA("BasePart") then
                            pcall(function() drop.CFrame = root.CFrame end)
                        end
                    end
                end
            end, 0.1)
        else
            Notify(Icons.Collect .. " Auto Collect", "Disabled", 2)
            StopLoop("AutoCollectDrops")
        end
    end)

    MkToggle(Tabs.Main, Icons.Quest, "Auto Quest", "AutoQuest", function(v)
        ScriptData.Config.Main.AutoQuest = v
        if v then
            Notify(Icons.Quest .. " Auto Quest", "Enabled", 2)
            CreateLoop("AutoQuest", function()
                Fire("AcceptQuest")
                Fire("Quest")
                Fire("CompleteQuest")
                Fire("TurnInQuest")
            end, 2)
        else
            Notify(Icons.Quest .. " Auto Quest", "Disabled", 2)
            StopLoop("AutoQuest")
        end
    end)

    MkToggle(Tabs.Main, Icons.Upgrade, "Auto Upgrade", "AutoUpgrade", function(v)
        ScriptData.Config.Main.AutoUpgrade = v
        if v then
            Notify(Icons.Upgrade .. " Auto Upgrade", "Enabled", 2)
            CreateLoop("AutoUpgrade", function()
                Fire("Upgrade")
                Fire("upgrade")
                Fire("UpgradeTool")
                Fire("UpgradePlot")
            end, 3)
        else
            Notify(Icons.Upgrade .. " Auto Upgrade", "Disabled", 2)
            StopLoop("AutoUpgrade")
        end
    end)

    MkToggle(Tabs.Main, Icons.Rebirth, "Auto Rebirth", "AutoRebirth", function(v)
        ScriptData.Config.Main.AutoRebirth = v
        if v then
            Notify(Icons.Rebirth .. " Auto Rebirth", "Enabled", 2)
            CreateLoop("AutoRebirth", function()
                Fire("Rebirth")
                Fire("rebirth")
                Fire("Prestige")
            end, 5)
        else
            Notify(Icons.Rebirth .. " Auto Rebirth", "Disabled", 2)
            StopLoop("AutoRebirth")
        end
    end)

    MkToggle(Tabs.Main, Icons.Claim, "Auto Claim Rewards", "AutoClaimRewards", function(v)
        ScriptData.Config.Main.AutoClaimRewards = v
        if v then
            Notify(Icons.Claim .. " Auto Claim", "Enabled", 2)
            CreateLoop("AutoClaimRewards", function()
                Fire("ClaimReward")
                Fire("Claim")
                Fire("ClaimDaily")
                Fire("ClaimAchievement")
            end, 2)
        else
            Notify(Icons.Claim .. " Auto Claim", "Disabled", 2)
            StopLoop("AutoClaimRewards")
        end
    end)

    MkToggle(Tabs.Main, Icons.Event, "Auto Event", "AutoEvent", function(v)
        ScriptData.Config.Main.AutoEvent = v
        if v then
            Notify(Icons.Event .. " Auto Event", "Enabled", 2)
            CreateLoop("AutoEvent", function()
                Fire("JoinEvent")
                Fire("Event")
                Fire("event")
            end, 2)
        else
            Notify(Icons.Event .. " Auto Event", "Disabled", 2)
            StopLoop("AutoEvent")
        end
    end)

    MkToggle(Tabs.Main, Icons.Gift, "Auto Gift", "AutoGift", function(v)
        ScriptData.Config.Main.AutoGift = v
        if v then
            Notify(Icons.Gift .. " Auto Gift", "Enabled", 2)
            CreateLoop("AutoGift", function()
                for _, gift in ipairs(FindAll(workspace, "gift", "Model")) do
                    if gift and gift.Parent then
                        pcall(function()
                            local cd = FindFirst(gift, nil, "ClickDetector")
                            if cd then fireclickdetector(cd) end
                        end)
                        pcall(function()
                            local pp = FindFirst(gift, nil, "ProximityPrompt")
                            if pp then fireproximityprompt(pp) end
                        end)
                        Fire("OpenGift", gift)
                        Fire("ClaimGift", gift)
                    end
                end
            end, 1)
        else
            Notify(Icons.Gift .. " Auto Gift", "Disabled", 2)
            StopLoop("AutoGift")
        end
    end)
end

-- ========================
-- PLAYER TAB
-- ========================
if Tabs.Player then
    MkSection(Tabs.Player, "🏃 Movement")

    MkSlider(Tabs.Player, Icons.Speed, "WalkSpeed", "WalkSpeed", 16, 200, 16, function(v)
        ScriptData.Config.Player.WalkSpeed = v
        local h = GetHum()
        if h then h.WalkSpeed = v end
    end)

    MkSlider(Tabs.Player, Icons.Jump, "JumpPower", "JumpPower", 50, 300, 50, function(v)
        ScriptData.Config.Player.JumpPower = v
        local h = GetHum()
        if h then h.JumpPower = v h.UseJumpPower = true end
    end)

    MkSlider(Tabs.Player, Icons.Gravity, "Gravity", "Gravity", 0, 196, 196, function(v)
        ScriptData.Config.Player.Gravity = v
        workspace.Gravity = v
    end)

    MkSection(Tabs.Player, "✈️ Flight")

    MkToggle(Tabs.Player, Icons.Fly, "Fly", "Fly", function(v)
        ScriptData.Config.Player.Fly = v
        if v then
            Notify(Icons.Fly .. " Fly", "WASD + Space/Shift", 3)
            CreateLoop("Fly", function()
                local root = GetRoot()
                local hum = GetHum()
                if root and hum then
                    local bv = root:FindFirstChild("X0D_FlyBV")
                    if not bv then
                        bv = Instance.new("BodyVelocity")
                        bv.Name = "X0D_FlyBV"
                        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                        bv.Parent = root
                    end
                    local vel = Vector3.new(0, 0, 0)
                    local speed = ScriptData.Config.Player.FlySpeed
                    if hum.MoveDirection.Magnitude > 0 then vel += hum.MoveDirection * speed end
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, speed, 0) end
                    if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel -= Vector3.new(0, speed, 0) end
                    bv.Velocity = vel
                else
                    StopLoop("Fly")
                end
            end, 0.01)
        else
            Notify(Icons.Fly .. " Fly", "Disabled", 2)
            StopLoop("Fly")
            local root = GetRoot()
            if root then
                local bv = root:FindFirstChild("X0D_FlyBV")
                if bv then bv:Destroy() end
            end
        end
    end)

    MkSlider(Tabs.Player, Icons.FlySpeed, "Fly Speed", "FlySpeed", 10, 300, 50, function(v)
        ScriptData.Config.Player.FlySpeed = v
    end)

    MkSection(Tabs.Player, "💪 Abilities")

    MkToggle(Tabs.Player, Icons.NoClip, "NoClip", "NoClip", function(v)
        ScriptData.Config.Player.NoClip = v
        if v then
            Notify(Icons.NoClip .. " NoClip", "Enabled", 2)
            CreateLoop("NoClip", function()
                local c = GetChar()
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end, 0.1)
        else
            Notify(Icons.NoClip .. " NoClip", "Disabled", 2)
            StopLoop("NoClip")
            local c = GetChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
                end
            end
        end
    end)

    MkToggle(Tabs.Player, Icons.InfJump, "Infinite Jump", "InfiniteJump", function(v)
        ScriptData.Config.Player.InfiniteJump = v
        if v then
            Notify(Icons.InfJump .. " Infinite Jump", "Enabled", 2)
            AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                local h = GetHum()
                if h and ScriptData.Config.Player.InfiniteJump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        else
            Notify(Icons.InfJump .. " Infinite Jump", "Disabled", 2)
            RemoveConnection("InfiniteJump")
        end
    end)

    MkToggle(Tabs.Player, Icons.AntiAFK, "Anti AFK", "AntiAFK", function(v)
        ScriptData.Config.Player.AntiAFK = v
        if v then
            Notify(Icons.AntiAFK .. " Anti AFK", "Enabled", 2)
            AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
                Services.VirtualUser:CaptureController()
                Services.VirtualUser:ClickButton2(Vector2.new())
            end))
        else
            Notify(Icons.AntiAFK .. " Anti AFK", "Disabled", 2)
            RemoveConnection("AntiAFK")
        end
    end)

    MkToggle(Tabs.Player, Icons.Spinbot, "Spinbot", "Spinbot", function(v)
        ScriptData.Config.Player.Spinbot = v
        if v then
            Notify(Icons.Spinbot .. " Spinbot", "Enabled", 2)
            CreateLoop("Spinbot", function()
                local root = GetRoot()
                if root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(ScriptData.Config.Player.SpinbotSpeed), 0)
                end
            end, 0.01)
        else
            Notify(Icons.Spinbot .. " Spinbot", "Disabled", 2)
            StopLoop("Spinbot")
        end
    end)

    MkSlider(Tabs.Player, Icons.SpinSpeed, "Spinbot Speed", "SpinbotSpeed", 1, 50, 10, function(v)
        ScriptData.Config.Player.SpinbotSpeed = v
    end)

    MkButton(Tabs.Player, Icons.Reset, "Safe Reset", function()
        local h = GetHum()
        if h then h.Health = 0 Notify(Icons.Reset .. " Reset", "Character reset", 2) end
    end)
end

-- ========================
-- TELEPORT TAB
-- ========================
if Tabs.Teleport then
    MkSection(Tabs.Teleport, "📍 Locations")

    MkButton(Tabs.Teleport, Icons.Shop, "Teleport to Shop", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Shop then
            local p = GameCache.Shop:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify(Icons.Shop .. " Teleport", "Teleported to Shop", 2) end
        else Notify("❌ Error", "Shop not found", 3) end
    end)

    MkButton(Tabs.Teleport, Icons.Garden, "Teleport to Garden", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Garden then
            local p = GameCache.Garden:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify(Icons.Garden .. " Teleport", "Teleported to Garden", 2) end
        else Notify("❌ Error", "Garden not found", 3) end
    end)

    MkButton(Tabs.Teleport, Icons.Spawn, "Teleport to Spawn", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Spawn then
            TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
            Notify(Icons.Spawn .. " Teleport", "Teleported to Spawn", 2)
        else Notify("❌ Error", "Spawn not found", 3) end
    end)

    MkButton(Tabs.Teleport, Icons.NPC, "Teleport to NPCs", function()
        UpdateCache() task.wait(0.1)
        if #GameCache.NPCs > 0 then
            local npc = GameCache.NPCs[1]
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(5, 0, 0)) Notify(Icons.NPC .. " Teleport", "Teleported to NPC", 2) end
        else Notify("❌ Error", "No NPCs found", 3) end
    end)

    MkButton(Tabs.Teleport, Icons.Events, "Teleport to Events", function()
        local events = FindAll(workspace, "event", "Model")
        if #events > 0 then
            local p = events[1]:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify(Icons.Events .. " Teleport", "Teleported to Event", 2) end
        else Notify("❌ Error", "No events found", 3) end
    end)

    MkSection(Tabs.Teleport, "👥 Players")

    local selPlayer = ""
    MkInput(Tabs.Teleport, Icons.Player, "Player Name", "Type exact name", function(v) selPlayer = v end)

    do
        local names = {}
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if #names == 0 then names = {"No players"} end
        MkDropdown(Tabs.Teleport, Icons.Player, "Or Select Player", "SelPlayerDrop", names, function(v) selPlayer = v end)
    end

    MkButton(Tabs.Teleport, "➡️", "Teleport to Player", function()
        if selPlayer == "" then Notify("❌ Error", "Select or type a player", 3) return end
        local target
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p.Name:lower() == selPlayer:lower() then target = p break end
        end
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            TeleportTo(target.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
            Notify("➡️ Teleport", "Teleported to " .. target.Name, 2)
        else
            Notify("❌ Error", "Player not found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "🔄", "Refresh Player List", function()
        Notify("ℹ️ Info", "Retype player name to refresh", 3)
    end)
end

-- ========================
-- VISUAL TAB
-- ========================
if Tabs.Visual then
    MkSection(Tabs.Visual, "👁️ ESP")

    MkToggle(Tabs.Visual, Icons.PlayerESP, "Player ESP", "PlayerESP", function(v)
        ScriptData.Config.Visual.PlayerESP = v
        if v then
            Notify(Icons.PlayerESP .. " Player ESP", "Enabled", 2)
            CreateLoop("PlayerESP", function()
                for _, p in ipairs(Services.Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if not ScriptData.ESPObjects[tostring(p.Character)] then
                            MakeESP(p.Character, p.Name, Color3.fromRGB(255, 50, 50))
                        end
                    end
                end
            end, 1)
        else
            Notify(Icons.PlayerESP .. " Player ESP", "Disabled", 2)
            StopLoop("PlayerESP")
            for _, p in ipairs(Services.Players:GetPlayers()) do
                if p.Character then RemoveESP(p.Character) end
            end
        end
    end)

    MkToggle(Tabs.Visual, Icons.SeedESP, "Seed ESP", "SeedESP", function(v)
        ScriptData.Config.Visual.SeedESP = v
        if v then
            Notify(Icons.SeedESP .. " Seed ESP", "Enabled", 2)
            CreateLoop("SeedESP", function()
                for _, s in ipairs(FindAll(workspace, "seed", "Model")) do
                    if s and s.Parent and not ScriptData.ESPObjects[tostring(s)] then
                        MakeESP(s, "Seed", Color3.fromRGB(50, 255, 50))
                    end
                end
            end, 1)
        else
            Notify(Icons.SeedESP .. " Seed ESP", "Disabled", 2)
            StopLoop("SeedESP")
        end
    end)

    MkToggle(Tabs.Visual, Icons.FruitESP, "Fruit ESP", "FruitESP", function(v)
        ScriptData.Config.Visual.FruitESP = v
        if v then
            Notify(Icons.FruitESP .. " Fruit ESP", "Enabled", 2)
            CreateLoop("FruitESP", function()
                for _, f in ipairs(FindAll(workspace, "fruit", "Model")) do
                    if f and f.Parent and not ScriptData.ESPObjects[tostring(f)] then
                        MakeESP(f, "Fruit", Color3.fromRGB(255, 165, 0))
                    end
                end
            end, 1)
        else
            Notify(Icons.FruitESP .. " Fruit ESP", "Disabled", 2)
            StopLoop("FruitESP")
        end
    end)

    MkToggle(Tabs.Visual, Icons.ItemESP, "Item ESP", "ItemESP", function(v)
        ScriptData.Config.Visual.ItemESP = v
        if v then
            Notify(Icons.ItemESP .. " Item ESP", "Enabled", 2)
            CreateLoop("ItemESP", function()
                for _, i in ipairs(FindAll(workspace, "item", "Model")) do
                    if i and i.Parent and not ScriptData.ESPObjects[tostring(i)] then
                        MakeESP(i, "Item", Color3.fromRGB(0, 200, 255))
                    end
                end
            end, 1)
        else
            Notify(Icons.ItemESP .. " Item ESP", "Disabled", 2)
            StopLoop("ItemESP")
        end
    end)

    MkToggle(Tabs.Visual, Icons.NPCESP, "NPC ESP", "NPCESP", function(v)
        ScriptData.Config.Visual.NPCESP = v
        if v then
            Notify(Icons.NPCESP .. " NPC ESP", "Enabled", 2)
            CreateLoop("NPCESP", function()
                for _, n in ipairs(GameCache.NPCs) do
                    if n and n.Parent and not ScriptData.ESPObjects[tostring(n)] then
                        MakeESP(n, "NPC", Color3.fromRGB(255, 255, 0))
                    end
                end
            end, 1)
        else
            Notify(Icons.NPCESP .. " NPC ESP", "Disabled", 2)
            StopLoop("NPCESP")
        end
    end)

    MkToggle(Tabs.Visual, Icons.ChestESP, "Chest ESP", "ChestESP", function(v)
        ScriptData.Config.Visual.ChestESP = v
        if v then
            Notify(Icons.ChestESP .. " Chest ESP", "Enabled", 2)
            CreateLoop("ChestESP", function()
                for _, c in ipairs(FindAll(workspace, "chest", "Model")) do
                    if c and c.Parent and not ScriptData.ESPObjects[tostring(c)] then
                        MakeESP(c, "Chest", Color3.fromRGB(255, 215, 0))
                    end
                end
            end, 1)
        else
            Notify(Icons.ChestESP .. " Chest ESP", "Disabled", 2)
            StopLoop("ChestESP")
        end
    end)

    MkButton(Tabs.Visual, Icons.ClearESP, "Clear All ESP", function()
        ClearESP()
        for _, name in ipairs({"PlayerESP","SeedESP","FruitESP","ItemESP","NPCESP","ChestESP"}) do
            StopLoop(name)
        end
        Notify(Icons.ClearESP .. " ESP", "All ESP cleared", 2)
    end)

    MkSection(Tabs.Visual, "🎨 Rendering")

    MkToggle(Tabs.Visual, Icons.Fullbright, "Fullbright", "Fullbright", function(v)
        ScriptData.Config.Visual.Fullbright = v
        if v then
            Notify(Icons.Fullbright .. " Fullbright", "Enabled", 2)
            Services.Lighting.Brightness = 2
            Services.Lighting.ClockTime = 14
            Services.Lighting.FogEnd = 100000
            Services.Lighting.GlobalShadows = false
        else
            Notify(Icons.Fullbright .. " Fullbright", "Disabled", 2)
            Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
            Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
            Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
            Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
        end
    end)

    MkButton(Tabs.Visual, Icons.Fog, "Remove Fog", function()
        Services.Lighting.FogEnd = 100000
        for _, e in ipairs(Services.Lighting:GetChildren()) do
            pcall(function()
                if e:IsA("Atmosphere") then e.Density = 0 e.Haze = 0
                elseif e:IsA("PostEffect") then e.Enabled = false end
            end)
        end
        Notify(Icons.Fog .. " Fog", "Removed", 2)
    end)

    MkButton(Tabs.Visual, Icons.FPS, "FPS Boost", function()
        pcall(function()
            workspace.Terrain.WaterWaveSize = 0
            workspace.Terrain.WaterWaveSpeed = 0
            workspace.Terrain.WaterReflectance = 0
            workspace.Terrain.WaterTransparency = 0
        end)
        Services.Lighting.GlobalShadows = false
        Services.Lighting.FogEnd = 9e9
        pcall(function() settings().Rendering.QualityLevel = "Level01" end)
        for _, v in pairs(workspace:GetDescendants()) do
            if not IsProtectedPath(v) then
                pcall(function()
                    if v:IsA("BasePart") then v.Material = Enum.Material.Plastic v.Reflectance = 0
                    elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 1
                    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = false
                    elseif v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled = false end
                end)
            end
        end
        for _, e in pairs(Services.Lighting:GetChildren()) do
            pcall(function() if e:IsA("PostEffect") then e.Enabled = false end end)
        end
        Notify(Icons.FPS .. " FPS Boost", "Applied", 2)
    end)

    MkButton(Tabs.Visual, Icons.Effects, "Destroy Effects", function()
        for _, v in pairs(workspace:GetDescendants()) do
            if not IsProtectedPath(v) then
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v:Destroy()
                    end
                end)
            end
        end
        Notify(Icons.Effects .. " Effects", "Destroyed", 2)
    end)
end

-- ========================
-- MISC TAB
-- ========================
if Tabs.Misc then
    MkSection(Tabs.Misc, "🌐 Server")

    MkButton(Tabs.Misc, Icons.ServerHop, "Server Hop", function()
        Notify(Icons.ServerHop .. " Server Hop", "Finding server...", 3)
        task.spawn(function()
            pcall(function()
                local req = request or http_request or (syn and syn.request)
                if not req then Notify("❌ Error", "HTTP not supported", 3) return end
                local res = req({ Url = ("https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId), Method = "GET" })
                local body = Services.HttpService:JSONDecode(res.Body)
                local servers = {}
                if body and body.data then
                    for _, s in ipairs(body.data) do
                        if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s) end
                    end
                end
                if #servers > 0 then
                    Services.TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)].id, LocalPlayer)
                else
                    Notify("❌ Error", "No servers found", 3)
                end
            end)
        end)
    end)

    MkButton(Tabs.Misc, Icons.Rejoin, "Rejoin", function()
        Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    MkButton(Tabs.Misc, Icons.CopyJob, "Copy JobId", function()
        if setclipboard then setclipboard(game.JobId) Notify(Icons.CopyJob .. " Copied", game.JobId, 2)
        else Notify("❌ Error", "Clipboard not supported", 3) end
    end)

    MkButton(Tabs.Misc, Icons.CopyPlace, "Copy PlaceId", function()
        if setclipboard then setclipboard(tostring(game.PlaceId)) Notify(Icons.CopyPlace .. " Copied", tostring(game.PlaceId), 2)
        else Notify("❌ Error", "Clipboard not supported", 3) end
    end)

    MkSection(Tabs.Misc, "🎮 Game")

    MkButton(Tabs.Misc, Icons.DestroyUI, "Destroy Game UI", function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if not IsProtectedPath(g) and g ~= ScriptData.WindUIGui and g ~= ScriptData.MinimizeGui then
                pcall(function() g:Destroy() end)
            end
        end
        Notify(Icons.DestroyUI .. " UI", "Game UI destroyed", 2)
    end)
end

-- ========================
-- SETTINGS TAB
-- ========================
if Tabs.Settings then
    MkSection(Tabs.Settings, "💾 Configuration")

    local profileName = "default"

    MkInput(Tabs.Settings, "📝", "Profile Name", "Enter profile name", function(v)
        profileName = (v and v ~= "") and v or "default"
    end)

    MkButton(Tabs.Settings, Icons.Save, "Save Config", function()
        if SaveCfg(profileName) then Notify(Icons.Save .. " Saved", profileName, 2)
        else Notify("❌ Error", "writefile not available", 3) end
    end)

    MkButton(Tabs.Settings, Icons.Load, "Load Config", function()
        if LoadCfg(profileName) then Notify(Icons.Load .. " Loaded", profileName, 2)
        else Notify("❌ Error", "No config: " .. profileName, 3) end
    end)

    MkButton(Tabs.Settings, Icons.Delete, "Delete Config", function()
        local f = "X0D_GAG2_" .. profileName .. ".json"
        if isfile and isfile(f) and delfile then
            pcall(function() delfile(f) end)
            Notify(Icons.Delete .. " Deleted", profileName, 2)
        else
            Notify("❌ Error", "File not found", 3)
        end
    end)

    MkToggle(Tabs.Settings, Icons.AutoSave, "Auto Save (60s)", "AutoSaveCfg", function(v)
        ScriptData.Config.Settings.AutoSave = v
        if v then
            Notify(Icons.AutoSave .. " Auto Save", "Enabled", 2)
            CreateLoop("AutoSave", function() SaveCfg(profileName) end, 60)
        else
            Notify(Icons.AutoSave .. " Auto Save", "Disabled", 2)
            StopLoop("AutoSave")
        end
    end)

    MkSection(Tabs.Settings, Icons.ToggleUI .. " UI Toggle")
    MkLabel(Tabs.Settings, "Click the X0D HUB button to open/close UI")
    MkLabel(Tabs.Settings, "Drag the X0D HUB button to reposition it")
    MkLabel(Tabs.Settings, "Cyan = UI Open | Purple = UI Closed")
end

-- ========================
-- CREDITS TAB
-- ========================
if Tabs.Credits then
    MkSection(Tabs.Credits, Icons.Credits .. " About")

    MkParagraph(Tabs.Credits, "X0DEC04T Hub v1.0.0",
        "Premium automation hub for Grow a Garden 2.\nCreated by X0DEC04T\nPowered by WindUI")

    MkParagraph(Tabs.Credits, "📋 Features List",
        Icons.Harvest .. " Auto Harvest  " .. Icons.Plant .. " Auto Plant\n" ..
        Icons.Water .. " Auto Water  " .. Icons.Fertilize .. " Auto Fertilize\n" ..
        Icons.Sell .. " Auto Sell  " .. Icons.BuySeed .. " Auto Buy Seeds\n" ..
        Icons.BuyGear .. " Auto Buy Gear  " .. Icons.Collect .. " Auto Collect\n" ..
        Icons.Quest .. " Auto Quest  " .. Icons.Upgrade .. " Auto Upgrade\n" ..
        Icons.Rebirth .. " Auto Rebirth  " .. Icons.Claim .. " Auto Claim\n" ..
        Icons.Event .. " Auto Event  " .. Icons.Gift .. " Auto Gift\n" ..
        Icons.Fly .. " Fly  " .. Icons.NoClip .. " NoClip\n" ..
        Icons.InfJump .. " Infinite Jump  " .. Icons.AntiAFK .. " Anti AFK\n" ..
        Icons.Spinbot .. " Spinbot  " .. Icons.Fullbright .. " Fullbright\n" ..
        Icons.PlayerESP .. " Player ESP  " .. Icons.SeedESP .. " Seed ESP\n" ..
        Icons.FruitESP .. " Fruit ESP  " .. Icons.ChestESP .. " Chest ESP")

    MkButton(Tabs.Credits, Icons.Discord, "Copy Discord", function()
        if setclipboard then setclipboard("discord.gg/x0dec04t") Notify(Icons.Discord .. " Discord", "Link copied!", 2)
        else Notify(Icons.Discord .. " Discord", "discord.gg/x0dec04t", 5) end
    end)
end

-- ========================
-- CHARACTER RESTORE
-- ========================
AddConnection("CharAdded", LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    if ScriptData.Config.Player.WalkSpeed ~= ScriptData.OriginalValues.WalkSpeed then
        hum.WalkSpeed = ScriptData.Config.Player.WalkSpeed
    end
    if ScriptData.Config.Player.JumpPower ~= ScriptData.OriginalValues.JumpPower then
        hum.JumpPower = ScriptData.Config.Player.JumpPower
        hum.UseJumpPower = true
    end
end))

AddConnection("PlayerRemESP", Services.Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer and p.Character then RemoveESP(p.Character) end
end))

task.spawn(function()
    while task.wait(10) do UpdateCache() end
end)

pcall(function() LoadCfg("default") end)

Notify("✅ X0DEC04T Hub", "Loaded! Click the X0D HUB button to open!", 5)

-- ========================
-- CLEANUP
-- ========================
local function Cleanup()
    for _, conn in pairs(ScriptData.Connections) do pcall(function() conn:Disconnect() end) end
    for name in pairs(ScriptData.Loops) do ScriptData.Loops[name] = false end
    ClearESP()
    pcall(function() workspace.Gravity = ScriptData.OriginalValues.Gravity end)
    pcall(function()
        Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
        Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
        Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
        Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
    end)
    local root = GetRoot()
    if root then
        local bv = root:FindFirstChild("X0D_FlyBV")
        if bv then pcall(function() bv:Destroy() end) end
    end
    local h = GetHum()
    if h then
        pcall(function()
            h.WalkSpeed = ScriptData.OriginalValues.WalkSpeed
            h.JumpPower = ScriptData.OriginalValues.JumpPower
        end)
    end
end

Services.Players.PlayerRemoving:Connect(function(p)
    if p == LocalPlayer then Cleanup() end
end)
