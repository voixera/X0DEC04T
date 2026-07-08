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
            if not ok then warn("Loop[" .. name .. "]: " .. tostring(err)) end
            task.wait(waitTime or 0.5)
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
    local ok, result = pcall(function()
        for _, d in ipairs(parent:GetDescendants()) do
            if not IsProtectedPath(d) then
                local nm = not name or d.Name:lower():find(name:lower())
                local cl = not class or d:IsA(class)
                if nm and cl then return d end
            end
        end
        return nil
    end)
    if ok then return result end
    return nil
end

local function FindAll(parent, name, class)
    local r = {}
    if not parent or IsProtectedPath(parent) then return r end
    pcall(function()
        for _, d in ipairs(parent:GetDescendants()) do
            if not IsProtectedPath(d) then
                local nm = not name or d.Name:lower():find(name:lower())
                local cl = not class or d:IsA(class)
                if nm and cl then table.insert(r, d) end
            end
        end
    end)
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

local function FireAll(names, ...)
    for _, name in ipairs(names) do Fire(name, ...) end
end

local function TryClickDetector(model)
    pcall(function()
        local cd = FindFirst(model, nil, "ClickDetector")
        if cd then fireclickdetector(cd) end
    end)
    pcall(function()
        local pp = FindFirst(model, nil, "ProximityPrompt")
        if pp then fireproximityprompt(pp) end
    end)
end

local function FindPlots()
    local plots = {}
    local function scanParent(p)
        if not p then return end
        pcall(function()
            for _, obj in ipairs(p:GetDescendants()) do
                if obj:IsA("Model") then
                    local n = obj.Name:lower()
                    if n:find("plot") or obj:FindFirstChild("Soil") or obj:FindFirstChild("SeedSlot") then
                        table.insert(plots, obj)
                    end
                end
            end
        end)
    end
    scanParent(workspace:FindFirstChild("PlayerPlots"))
    scanParent(workspace:FindFirstChild("Plots"))
    scanParent(workspace:FindFirstChild("Gardens"))
    scanParent(workspace:FindFirstChild(LocalPlayer.Name))
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") then
                local n = obj.Name:lower()
                if (n:find("plot") or n:find("garden")) and obj:FindFirstChild("Owner") then
                    local owner = obj:FindFirstChild("Owner")
                    if owner and (owner.Value == LocalPlayer or owner.Value == LocalPlayer.Name) then
                        table.insert(plots, obj)
                    end
                end
            end
        end
    end)
    return plots
end

local function FindPlants()
    local plants = {}
    local seen = {}
    local function addPlant(obj)
        local k = tostring(obj)
        if not seen[k] then
            seen[k] = true
            table.insert(plants, obj)
        end
    end
    pcall(function()
        for _, plot in ipairs(FindPlots()) do
            for _, obj in ipairs(plot:GetDescendants()) do
                if obj:IsA("Model") and obj.Name:lower():find("plant") then addPlant(obj) end
                if obj:IsA("BasePart") and obj:FindFirstChild("Harvest") then addPlant(obj) end
            end
        end
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not IsProtectedPath(obj) and obj:IsA("Model") then
                local n = obj.Name:lower()
                if n:find("plant") or n:find("crop") or n:find("flower") or n:find("tree") then
                    if obj:FindFirstChild("Stem") or obj:FindFirstChild("Harvest") or obj:FindFirstChild("Stage") or obj:FindFirstChild("Grown") then
                        addPlant(obj)
                    end
                end
            end
        end
    end)
    return plants
end

local function UpdateCache()
    task.spawn(function()
        pcall(function()
            GameCache.Garden = workspace:FindFirstChild("Garden")
                or workspace:FindFirstChild("PlayerGarden")
                or workspace:FindFirstChild("PlayerPlots")
                or workspace:FindFirstChild(LocalPlayer.Name)
            GameCache.Shop = workspace:FindFirstChild("Shop")
                or workspace:FindFirstChild("Store")
                or FindFirst(workspace, "shop", "Model")
            GameCache.SellArea = workspace:FindFirstChild("SellArea")
                or workspace:FindFirstChild("Sell")
                or FindFirst(workspace, "sell", "Model")
                or FindFirst(workspace, "stall", "Model")
            GameCache.Spawn = workspace:FindFirstChild("SpawnLocation")
                or workspace:FindFirstChild("Spawn")
            GameCache.Plots = FindPlots()
            GameCache.Plants = FindPlants()
            GameCache.NPCs = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if not IsProtectedPath(obj) and obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                    local n = obj.Name:lower()
                    if n:find("npc") or n:find("merchant") or n:find("vendor") or n:find("shop") then
                        table.insert(GameCache.NPCs, obj)
                    end
                end
            end
            GameCache.Drops = {}
            for _, obj in ipairs(workspace:GetDescendants()) do
                if not IsProtectedPath(obj) and obj:IsA("BasePart") then
                    local n = obj.Name:lower()
                    if n:find("drop") or n:find("coin") or n:find("money") or n:find("reward") then
                        table.insert(GameCache.Drops, obj)
                    end
                end
            end
        end)
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
    pcall(function()
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
    end)
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

local existingCoreGui = {}
for _, g in ipairs(Services.CoreGui:GetChildren()) do existingCoreGui[g] = true end
local existingPlayerGui = {}
for _, g in ipairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do existingPlayerGui[g] = true end

local Window
SafeCall(function()
    Window = WindUI:CreateWindow({
        Title = "X0DEC04T Hub",
        SubTitle = "X0DEC04T",
        Icon = "rbxassetid://10734950",
        Author = "X0DEC04T",
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

task.wait(0.5)

for _, g in ipairs(Services.CoreGui:GetChildren()) do
    if not existingCoreGui[g] and g:IsA("ScreenGui") then
        ScriptData.WindUIGui = g
        break
    end
end
if not ScriptData.WindUIGui then
    for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if not existingPlayerGui[g] and g:IsA("ScreenGui") then
            ScriptData.WindUIGui = g
            break
        end
    end
end

if ScriptData.WindUIGui then
    ScriptData.WindUIGui.Enabled = false
    ScriptData.UIVisible = false
end

local function ShowUI()
    ScriptData.UIVisible = true
    if ScriptData.WindUIGui then
        ScriptData.WindUIGui.Enabled = true
    end
end

local function HideUI()
    ScriptData.UIVisible = false
    if ScriptData.WindUIGui then
        ScriptData.WindUIGui.Enabled = false
    end
end

local function ToggleUI()
    if ScriptData.UIVisible then HideUI() else ShowUI() end
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
        local ok = pcall(function() sg.Parent = Services.CoreGui end)
        if not ok or sg.Parent ~= Services.CoreGui then
            sg.Parent = LocalPlayer.PlayerGui
        end
    end

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(0, 90, 0, 90)
    container.Position = UDim2.new(0, 20, 0.5, -45)
    container.BackgroundTransparency = 1
    container.Parent = sg

    local outerGlow = Instance.new("ImageLabel")
    outerGlow.Name = "OuterGlow"
    outerGlow.Size = UDim2.new(1.5, 0, 1.5, 0)
    outerGlow.Position = UDim2.new(-0.25, 0, -0.25, 0)
    outerGlow.BackgroundTransparency = 1
    outerGlow.Image = "rbxassetid://5028857472"
    outerGlow.ImageColor3 = Color3.fromRGB(0, 195, 210)
    outerGlow.ImageTransparency = 0.5
    outerGlow.ZIndex = 1
    outerGlow.Parent = container

    task.spawn(function()
        local growing = true
        while sg.Parent do
            local target = growing and 0.3 or 0.6
            Services.TweenService:Create(outerGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
                ImageTransparency = target
            }):Play()
            growing = not growing
            task.wait(1.5)
        end
    end)

    local circleBtn = Instance.new("ImageButton")
    circleBtn.Name = "CircleBtn"
    circleBtn.Size = UDim2.new(1, 0, 1, 0)
    circleBtn.Position = UDim2.new(0, 0, 0, 0)
    circleBtn.BackgroundColor3 = Color3.fromRGB(0, 195, 210)
    circleBtn.BorderSizePixel = 0
    circleBtn.ZIndex = 2
    circleBtn.AutoButtonColor = false
    circleBtn.Image = ""
    circleBtn.Parent = container

    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = circleBtn

    local circleGrad = Instance.new("UIGradient")
    circleGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 220, 240)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 180))
    }
    circleGrad.Rotation = 135
    circleGrad.Parent = circleBtn

    local circleStroke = Instance.new("UIStroke")
    circleStroke.Color = Color3.fromRGB(255, 255, 255)
    circleStroke.Thickness = 2
    circleStroke.Transparency = 0.5
    circleStroke.Parent = circleBtn

    local innerCircle = Instance.new("Frame")
    innerCircle.Name = "InnerCircle"
    innerCircle.Size = UDim2.new(0.78, 0, 0.78, 0)
    innerCircle.Position = UDim2.new(0.11, 0, 0.11, 0)
    innerCircle.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    innerCircle.BorderSizePixel = 0
    innerCircle.ZIndex = 3
    innerCircle.Parent = circleBtn

    local innerCorner = Instance.new("UICorner")
    innerCorner.CornerRadius = UDim.new(1, 0)
    innerCorner.Parent = innerCircle

    local topLabel = Instance.new("TextLabel")
    topLabel.Size = UDim2.new(1, -4, 0.45, 0)
    topLabel.Position = UDim2.new(0, 2, 0.06, 0)
    topLabel.BackgroundTransparency = 1
    topLabel.Text = "X0D"
    topLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    topLabel.TextScaled = true
    topLabel.Font = Enum.Font.GothamBold
    topLabel.ZIndex = 4
    topLabel.Parent = innerCircle

    local bottomLabel = Instance.new("TextLabel")
    bottomLabel.Size = UDim2.new(1, -4, 0.32, 0)
    bottomLabel.Position = UDim2.new(0, 2, 0.58, 0)
    bottomLabel.BackgroundTransparency = 1
    bottomLabel.Text = "HUB"
    bottomLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bottomLabel.TextScaled = true
    bottomLabel.Font = Enum.Font.GothamBold
    bottomLabel.ZIndex = 4
    bottomLabel.Parent = innerCircle

    local dragging = false
    local dragStart = nil
    local startPos = nil
    local hasMoved = false
    local clickTime = 0

    circleBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
            dragStart = inp.Position
            startPos = container.Position
            clickTime = tick()
        end
    end)

    AddConnection("HubBtnMove", Services.UserInputService.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            container.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    AddConnection("HubBtnEnd", Services.UserInputService.InputEnded:Connect(function(inp)
        if (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) and dragging then
            dragging = false
            if not hasMoved and tick() - clickTime < 0.35 then
                ToggleUI()
                local isOpen = ScriptData.UIVisible
                local newColor = isOpen and Color3.fromRGB(0, 195, 210) or Color3.fromRGB(150, 50, 220)
                circleGrad.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, isOpen and Color3.fromRGB(0, 220, 240) or Color3.fromRGB(170, 60, 240)),
                    ColorSequenceKeypoint.new(1, isOpen and Color3.fromRGB(0, 150, 180) or Color3.fromRGB(100, 20, 180))
                }
                outerGlow.ImageColor3 = newColor
                Services.TweenService:Create(circleBtn, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Size = UDim2.new(1.15, 0, 1.15, 0),
                    Position = UDim2.new(-0.075, 0, -0.075, 0)
                }):Play()
                task.delay(0.1, function()
                    Services.TweenService:Create(circleBtn, TweenInfo.new(0.15), {
                        Size = UDim2.new(1, 0, 1, 0),
                        Position = UDim2.new(0, 0, 0, 0)
                    }):Play()
                end)
            end
        end
    end))

    circleBtn.MouseEnter:Connect(function()
        Services.TweenService:Create(container, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 98, 0, 98),
            Position = UDim2.new(
                container.Position.X.Scale, container.Position.X.Offset - 4,
                container.Position.Y.Scale, container.Position.Y.Offset - 4
            )
        }):Play()
    end)

    circleBtn.MouseLeave:Connect(function()
        Services.TweenService:Create(container, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 90, 0, 90),
            Position = UDim2.new(
                container.Position.X.Scale, container.Position.X.Offset + 4,
                container.Position.Y.Scale, container.Position.Y.Offset + 4
            )
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

local function MkSection(tab, title)
    SafeCall(function() tab:Section({ Title = title }) end)
end

local function MkToggle(tab, title, icon, flag, cb)
    SafeCall(function()
        tab:Toggle({
            Title = title,
            Icon = icon,
            Default = false,
            Flag = flag,
            Callback = cb
        })
    end)
end

local function MkButton(tab, title, icon, cb)
    SafeCall(function()
        tab:Button({ Title = title, Icon = icon, Callback = cb })
    end)
end

local function MkSlider(tab, title, icon, flag, min, max, def, cb)
    SafeCall(function()
        tab:Slider({
            Title = title,
            Icon = icon,
            Flag = flag,
            Step = 1,
            Value = { Min = min, Max = max, Default = def },
            Callback = cb
        })
    end)
end

local function MkInput(tab, title, icon, placeholder, cb)
    SafeCall(function()
        tab:Input({
            Title = title,
            Icon = icon,
            Placeholder = placeholder,
            Value = "",
            Callback = cb
        })
    end)
end

local function MkDropdown(tab, title, icon, flag, list, cb)
    SafeCall(function()
        tab:Dropdown({
            Title = title,
            Icon = icon,
            Flag = flag,
            Values = list,
            Callback = cb
        })
    end)
end

local function MkLabel(tab, text)
    SafeCall(function() tab:Label({ Title = text }) end)
end

local function MkParagraph(tab, title, desc)
    SafeCall(function() tab:Paragraph({ Title = title, Description = desc }) end)
end

-- ========================
-- MAIN TAB
-- ========================
if Tabs.Main then
    MkSection(Tabs.Main, "Farming")

    MkToggle(Tabs.Main, "Auto Harvest", "rbxassetid://10734950", "AutoHarvest", function(v)
        ScriptData.Config.Main.AutoHarvest = v
        if v then
            Notify("Auto Harvest", "Enabled", 2)
            CreateLoop("AutoHarvest", function()
                UpdateCache()
                for _, plant in ipairs(GameCache.Plants) do
                    if plant and plant.Parent then
                        local ready = plant:FindFirstChild("Ready")
                            or plant:FindFirstChild("Harvestable")
                            or plant:FindFirstChild("Grown")
                            or plant:FindFirstChild("FullyGrown")
                        if ready and ready.Value == true then
                            TryClickDetector(plant)
                            FireAll({"HarvestPlant","Harvest","harvest","Collect","collect"}, plant)
                        end
                    end
                end
            end, 0.5)
        else
            Notify("Auto Harvest", "Disabled", 2)
            StopLoop("AutoHarvest")
        end
    end)

    MkToggle(Tabs.Main, "Auto Plant", "rbxassetid://10734950", "AutoPlant", function(v)
        ScriptData.Config.Main.AutoPlant = v
        if v then
            Notify("Auto Plant", "Enabled", 2)
            CreateLoop("AutoPlant", function()
                UpdateCache()
                for _, plot in ipairs(GameCache.Plots) do
                    if plot and plot.Parent then
                        local isEmpty = plot:FindFirstChild("Empty")
                            or plot:FindFirstChild("Available")
                            or plot:FindFirstChild("IsEmpty")
                        local hasPlant = FindFirst(plot, "plant", "Model")
                            or FindFirst(plot, "crop", "Model")
                        local canPlant = (isEmpty and (isEmpty.Value == true or isEmpty.Value == 1)) or (not hasPlant)
                        if canPlant then
                            TryClickDetector(plot)
                            FireAll({"PlantSeed","Plant","plant","SeedPlot","Grow"}, plot, ScriptData.Config.Main.SelectedSeed)
                            FireAll({"BuyAndPlant","AutoPlant"}, ScriptData.Config.Main.SelectedSeed)
                        end
                    end
                end
            end, 0.5)
        else
            Notify("Auto Plant", "Disabled", 2)
            StopLoop("AutoPlant")
        end
    end)

    MkToggle(Tabs.Main, "Auto Water", "rbxassetid://10734950", "AutoWater", function(v)
        ScriptData.Config.Main.AutoWater = v
        if v then
            Notify("Auto Water", "Enabled", 2)
            CreateLoop("AutoWater", function()
                for _, plant in ipairs(GameCache.Plants) do
                    if plant and plant.Parent then
                        TryClickDetector(plant)
                        FireAll({"WaterPlant","Water","water","WaterCrop"}, plant)
                    end
                end
            end, 0.5)
        else
            Notify("Auto Water", "Disabled", 2)
            StopLoop("AutoWater")
        end
    end)

    MkToggle(Tabs.Main, "Auto Fertilize", "rbxassetid://10734950", "AutoFertilize", function(v)
        ScriptData.Config.Main.AutoFertilize = v
        if v then
            Notify("Auto Fertilize", "Enabled", 2)
            CreateLoop("AutoFertilize", function()
                for _, plant in ipairs(GameCache.Plants) do
                    if plant and plant.Parent then
                        FireAll({"FertilizePlant","Fertilize","fertilize","UseFertilizer","ApplyFertilizer"}, plant)
                    end
                end
            end, 1)
        else
            Notify("Auto Fertilize", "Disabled", 2)
            StopLoop("AutoFertilize")
        end
    end)

    MkSection(Tabs.Main, "Shop & Economy")

    MkInput(Tabs.Main, "Seed Name", "rbxassetid://10734950", "e.g. Carrot", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedSeed = v
            Notify("Seed Set", v, 2)
        end
    end)

    MkInput(Tabs.Main, "Gear Name", "rbxassetid://10734950", "e.g. Basic Watering Can", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedGear = v
            Notify("Gear Set", v, 2)
        end
    end)

    MkToggle(Tabs.Main, "Auto Sell", "rbxassetid://10734950", "AutoSell", function(v)
        ScriptData.Config.Main.AutoSell = v
        if v then
            Notify("Auto Sell", "Enabled", 2)
            CreateLoop("AutoSell", function()
                FireAll({"SellProduce","Sell","sell","SellItems","SellAll","SellCrops"})
                if GameCache.SellArea then
                    local root = GetRoot()
                    if root then
                        local part = nil
                        pcall(function()
                            part = GameCache.SellArea:IsA("BasePart") and GameCache.SellArea or GameCache.SellArea:FindFirstChildWhichIsA("BasePart")
                        end)
                        if part then
                            local old = root.CFrame
                            root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                            task.wait(0.2)
                            pcall(function() root.CFrame = old end)
                        end
                    end
                end
            end, 2)
        else
            Notify("Auto Sell", "Disabled", 2)
            StopLoop("AutoSell")
        end
    end)

    MkToggle(Tabs.Main, "Auto Buy Seeds", "rbxassetid://10734950", "AutoBuySeeds", function(v)
        ScriptData.Config.Main.AutoBuySeeds = v
        if v then
            Notify("Auto Buy Seeds", "Enabled", 2)
            CreateLoop("AutoBuySeeds", function()
                FireAll({"BuySeed","PurchaseSeed","BuyItem"}, ScriptData.Config.Main.SelectedSeed)
                FireAll({"buy","purchase"}, "seed", ScriptData.Config.Main.SelectedSeed)
            end, 3)
        else
            Notify("Auto Buy Seeds", "Disabled", 2)
            StopLoop("AutoBuySeeds")
        end
    end)

    MkToggle(Tabs.Main, "Auto Buy Gear", "rbxassetid://10734950", "AutoBuyGear", function(v)
        ScriptData.Config.Main.AutoBuyGear = v
        if v then
            Notify("Auto Buy Gear", "Enabled", 2)
            CreateLoop("AutoBuyGear", function()
                FireAll({"BuyGear","PurchaseGear","BuyTool"}, ScriptData.Config.Main.SelectedGear)
                FireAll({"buy","purchase"}, "gear", ScriptData.Config.Main.SelectedGear)
            end, 3)
        else
            Notify("Auto Buy Gear", "Disabled", 2)
            StopLoop("AutoBuyGear")
        end
    end)

    MkSection(Tabs.Main, "Automation")

    MkToggle(Tabs.Main, "Auto Collect Drops", "rbxassetid://10734950", "AutoCollectDrops", function(v)
        ScriptData.Config.Main.AutoCollectDrops = v
        if v then
            Notify("Auto Collect", "Enabled", 2)
            CreateLoop("AutoCollectDrops", function()
                UpdateCache()
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
            Notify("Auto Collect", "Disabled", 2)
            StopLoop("AutoCollectDrops")
        end
    end)

    MkToggle(Tabs.Main, "Auto Quest", "rbxassetid://10734950", "AutoQuest", function(v)
        ScriptData.Config.Main.AutoQuest = v
        if v then
            Notify("Auto Quest", "Enabled", 2)
            CreateLoop("AutoQuest", function()
                FireAll({"AcceptQuest","Quest","quest","StartQuest","CompleteQuest","TurnInQuest","FinishQuest"})
            end, 2)
        else
            Notify("Auto Quest", "Disabled", 2)
            StopLoop("AutoQuest")
        end
    end)

    MkToggle(Tabs.Main, "Auto Upgrade", "rbxassetid://10734950", "AutoUpgrade", function(v)
        ScriptData.Config.Main.AutoUpgrade = v
        if v then
            Notify("Auto Upgrade", "Enabled", 2)
            CreateLoop("AutoUpgrade", function()
                FireAll({"Upgrade","upgrade","UpgradeTool","UpgradePlot","UpgradeGarden","LevelUp"})
            end, 3)
        else
            Notify("Auto Upgrade", "Disabled", 2)
            StopLoop("AutoUpgrade")
        end
    end)

    MkToggle(Tabs.Main, "Auto Rebirth", "rbxassetid://10734950", "AutoRebirth", function(v)
        ScriptData.Config.Main.AutoRebirth = v
        if v then
            Notify("Auto Rebirth", "Enabled", 2)
            CreateLoop("AutoRebirth", function()
                FireAll({"Rebirth","rebirth","Prestige","prestige","Reset"})
            end, 5)
        else
            Notify("Auto Rebirth", "Disabled", 2)
            StopLoop("AutoRebirth")
        end
    end)

    MkToggle(Tabs.Main, "Auto Claim Rewards", "rbxassetid://10734950", "AutoClaimRewards", function(v)
        ScriptData.Config.Main.AutoClaimRewards = v
        if v then
            Notify("Auto Claim", "Enabled", 2)
            CreateLoop("AutoClaimRewards", function()
                FireAll({"ClaimReward","Claim","claim","ClaimDaily","ClaimAchievement","ClaimBonus"})
            end, 2)
        else
            Notify("Auto Claim", "Disabled", 2)
            StopLoop("AutoClaimRewards")
        end
    end)

    MkToggle(Tabs.Main, "Auto Event", "rbxassetid://10734950", "AutoEvent", function(v)
        ScriptData.Config.Main.AutoEvent = v
        if v then
            Notify("Auto Event", "Enabled", 2)
            CreateLoop("AutoEvent", function()
                FireAll({"JoinEvent","Event","event","StartEvent","ParticipateEvent"})
            end, 2)
        else
            Notify("Auto Event", "Disabled", 2)
            StopLoop("AutoEvent")
        end
    end)

    MkToggle(Tabs.Main, "Auto Gift", "rbxassetid://10734950", "AutoGift", function(v)
        ScriptData.Config.Main.AutoGift = v
        if v then
            Notify("Auto Gift", "Enabled", 2)
            CreateLoop("AutoGift", function()
                for _, gift in ipairs(FindAll(workspace, "gift", "Model")) do
                    if gift and gift.Parent then
                        TryClickDetector(gift)
                        FireAll({"OpenGift","ClaimGift","CollectGift","Gift"}, gift)
                    end
                end
            end, 1)
        else
            Notify("Auto Gift", "Disabled", 2)
            StopLoop("AutoGift")
        end
    end)
end

-- ========================
-- PLAYER TAB
-- ========================
if Tabs.Player then
    MkSection(Tabs.Player, "Movement")

    MkSlider(Tabs.Player, "WalkSpeed", "rbxassetid://10747372", "WalkSpeed", 16, 200, 16, function(v)
        ScriptData.Config.Player.WalkSpeed = v
        local h = GetHum()
        if h then h.WalkSpeed = v end
    end)

    MkSlider(Tabs.Player, "JumpPower", "rbxassetid://10747372", "JumpPower", 50, 300, 50, function(v)
        ScriptData.Config.Player.JumpPower = v
        local h = GetHum()
        if h then h.JumpPower = v h.UseJumpPower = true end
    end)

    MkSlider(Tabs.Player, "Gravity", "rbxassetid://10747372", "Gravity", 0, 196, 196, function(v)
        ScriptData.Config.Player.Gravity = v
        workspace.Gravity = v
    end)

    MkSection(Tabs.Player, "Flight")

    MkToggle(Tabs.Player, "Fly", "rbxassetid://10747372", "Fly", function(v)
        ScriptData.Config.Player.Fly = v
        if v then
            Notify("Fly", "WASD + Space/Shift", 3)
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
            Notify("Fly", "Disabled", 2)
            StopLoop("Fly")
            local root = GetRoot()
            if root then
                local bv = root:FindFirstChild("X0D_FlyBV")
                if bv then bv:Destroy() end
            end
        end
    end)

    MkSlider(Tabs.Player, "Fly Speed", "rbxassetid://10747372", "FlySpeed", 10, 300, 50, function(v)
        ScriptData.Config.Player.FlySpeed = v
    end)

    MkSection(Tabs.Player, "Abilities")

    MkToggle(Tabs.Player, "NoClip", "rbxassetid://10747372", "NoClip", function(v)
        ScriptData.Config.Player.NoClip = v
        if v then
            Notify("NoClip", "Enabled", 2)
            CreateLoop("NoClip", function()
                local c = GetChar()
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end, 0.1)
        else
            Notify("NoClip", "Disabled", 2)
            StopLoop("NoClip")
            local c = GetChar()
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then p.CanCollide = true end
                end
            end
        end
    end)

    MkToggle(Tabs.Player, "Infinite Jump", "rbxassetid://10747372", "InfiniteJump", function(v)
        ScriptData.Config.Player.InfiniteJump = v
        if v then
            Notify("Infinite Jump", "Enabled", 2)
            AddConnection("InfiniteJump", Services.UserInputService.JumpRequest:Connect(function()
                local h = GetHum()
                if h and ScriptData.Config.Player.InfiniteJump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        else
            Notify("Infinite Jump", "Disabled", 2)
            RemoveConnection("InfiniteJump")
        end
    end)

    MkToggle(Tabs.Player, "Anti AFK", "rbxassetid://10747372", "AntiAFK", function(v)
        ScriptData.Config.Player.AntiAFK = v
        if v then
            Notify("Anti AFK", "Enabled", 2)
            AddConnection("AntiAFK", LocalPlayer.Idled:Connect(function()
                Services.VirtualUser:CaptureController()
                Services.VirtualUser:ClickButton2(Vector2.new())
            end))
        else
            Notify("Anti AFK", "Disabled", 2)
            RemoveConnection("AntiAFK")
        end
    end)

    MkToggle(Tabs.Player, "Spinbot", "rbxassetid://10747372", "Spinbot", function(v)
        ScriptData.Config.Player.Spinbot = v
        if v then
            Notify("Spinbot", "Enabled", 2)
            CreateLoop("Spinbot", function()
                local root = GetRoot()
                if root then
                    root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(ScriptData.Config.Player.SpinbotSpeed), 0)
                end
            end, 0.01)
        else
            Notify("Spinbot", "Disabled", 2)
            StopLoop("Spinbot")
        end
    end)

    MkSlider(Tabs.Player, "Spinbot Speed", "rbxassetid://10747372", "SpinbotSpeed", 1, 50, 10, function(v)
        ScriptData.Config.Player.SpinbotSpeed = v
    end)

    MkButton(Tabs.Player, "Safe Reset", "rbxassetid://10747372", function()
        local h = GetHum()
        if h then h.Health = 0 Notify("Reset", "Character reset", 2) end
    end)
end

-- ========================
-- TELEPORT TAB
-- ========================
if Tabs.Teleport then
    MkSection(Tabs.Teleport, "Locations")

    MkButton(Tabs.Teleport, "Teleport to Shop", "rbxassetid://10723407", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Shop then
            local p = GameCache.Shop:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Shop", 2)
            else Notify("Error", "Shop has no parts", 3) end
        else Notify("Error", "Shop not found", 3) end
    end)

    MkButton(Tabs.Teleport, "Teleport to Garden", "rbxassetid://10723407", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Garden then
            local p = GameCache.Garden:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Garden", 2)
            else Notify("Error", "Garden has no parts", 3) end
        else Notify("Error", "Garden not found", 3) end
    end)

    MkButton(Tabs.Teleport, "Teleport to Spawn", "rbxassetid://10723407", function()
        UpdateCache() task.wait(0.1)
        if GameCache.Spawn then
            TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
            Notify("Teleport", "Teleported to Spawn", 2)
        else Notify("Error", "Spawn not found", 3) end
    end)

    MkButton(Tabs.Teleport, "Teleport to NPCs", "rbxassetid://10723407", function()
        UpdateCache() task.wait(0.1)
        if #GameCache.NPCs > 0 then
            local npc = GameCache.NPCs[1]
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(5, 0, 0)) Notify("Teleport", "Teleported to NPC", 2) end
        else Notify("Error", "No NPCs found", 3) end
    end)

    MkButton(Tabs.Teleport, "Teleport to Events", "rbxassetid://10723407", function()
        local events = FindAll(workspace, "event", "Model")
        if #events > 0 then
            local p = events[1]:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Event", 2) end
        else Notify("Error", "No events found", 3) end
    end)

    MkSection(Tabs.Teleport, "Players")

    local selPlayer = ""
    MkInput(Tabs.Teleport, "Player Name", "rbxassetid://10723407", "Type exact name", function(v) selPlayer = v end)

    do
        local names = {}
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if #names == 0 then names = {"No players"} end
        MkDropdown(Tabs.Teleport, "Or Select Player", "rbxassetid://10723407", "SelPlayerDrop", names, function(v) selPlayer = v end)
    end

    MkButton(Tabs.Teleport, "Teleport to Player", "rbxassetid://10723407", function()
        if selPlayer == "" then Notify("Error", "Select or type a player", 3) return end
        local target
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p.Name:lower() == selPlayer:lower() then target = p break end
        end
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            TeleportTo(target.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
            Notify("Teleport", "Teleported to " .. target.Name, 2)
        else Notify("Error", "Player not found", 3) end
    end)

    MkButton(Tabs.Teleport, "Refresh Player List", "rbxassetid://10723407", function()
        Notify("Info", "Retype player name to refresh list", 3)
    end)
end

-- ========================
-- VISUAL TAB
-- ========================
if Tabs.Visual then
    MkSection(Tabs.Visual, "ESP")

    MkToggle(Tabs.Visual, "Player ESP", "rbxassetid://10734896", "PlayerESP", function(v)
        ScriptData.Config.Visual.PlayerESP = v
        if v then
            Notify("Player ESP", "Enabled", 2)
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
            Notify("Player ESP", "Disabled", 2)
            StopLoop("PlayerESP")
            for _, p in ipairs(Services.Players:GetPlayers()) do
                if p.Character then RemoveESP(p.Character) end
            end
        end
    end)

    MkToggle(Tabs.Visual, "Seed ESP", "rbxassetid://10734896", "SeedESP", function(v)
        ScriptData.Config.Visual.SeedESP = v
        if v then
            Notify("Seed ESP", "Enabled", 2)
            CreateLoop("SeedESP", function()
                for _, s in ipairs(FindAll(workspace, "seed", "Model")) do
                    if s and s.Parent and not ScriptData.ESPObjects[tostring(s)] then
                        MakeESP(s, "Seed", Color3.fromRGB(50, 255, 50))
                    end
                end
            end, 1)
        else
            Notify("Seed ESP", "Disabled", 2)
            StopLoop("SeedESP")
        end
    end)

    MkToggle(Tabs.Visual, "Fruit ESP", "rbxassetid://10734896", "FruitESP", function(v)
        ScriptData.Config.Visual.FruitESP = v
        if v then
            Notify("Fruit ESP", "Enabled", 2)
            CreateLoop("FruitESP", function()
                for _, f in ipairs(FindAll(workspace, "fruit", "Model")) do
                    if f and f.Parent and not ScriptData.ESPObjects[tostring(f)] then
                        MakeESP(f, "Fruit", Color3.fromRGB(255, 165, 0))
                    end
                end
            end, 1)
        else
            Notify("Fruit ESP", "Disabled", 2)
            StopLoop("FruitESP")
        end
    end)

    MkToggle(Tabs.Visual, "Item ESP", "rbxassetid://10734896", "ItemESP", function(v)
        ScriptData.Config.Visual.ItemESP = v
        if v then
            Notify("Item ESP", "Enabled", 2)
            CreateLoop("ItemESP", function()
                for _, i in ipairs(FindAll(workspace, "item", "Model")) do
                    if i and i.Parent and not ScriptData.ESPObjects[tostring(i)] then
                        MakeESP(i, "Item", Color3.fromRGB(0, 200, 255))
                    end
                end
            end, 1)
        else
            Notify("Item ESP", "Disabled", 2)
            StopLoop("ItemESP")
        end
    end)

    MkToggle(Tabs.Visual, "NPC ESP", "rbxassetid://10734896", "NPCESP", function(v)
        ScriptData.Config.Visual.NPCESP = v
        if v then
            Notify("NPC ESP", "Enabled", 2)
            CreateLoop("NPCESP", function()
                for _, n in ipairs(GameCache.NPCs) do
                    if n and n.Parent and not ScriptData.ESPObjects[tostring(n)] then
                        MakeESP(n, "NPC", Color3.fromRGB(255, 255, 0))
                    end
                end
            end, 1)
        else
            Notify("NPC ESP", "Disabled", 2)
            StopLoop("NPCESP")
        end
    end)

    MkToggle(Tabs.Visual, "Chest ESP", "rbxassetid://10734896", "ChestESP", function(v)
        ScriptData.Config.Visual.ChestESP = v
        if v then
            Notify("Chest ESP", "Enabled", 2)
            CreateLoop("ChestESP", function()
                for _, c in ipairs(FindAll(workspace, "chest", "Model")) do
                    if c and c.Parent and not ScriptData.ESPObjects[tostring(c)] then
                        MakeESP(c, "Chest", Color3.fromRGB(255, 215, 0))
                    end
                end
            end, 1)
        else
            Notify("Chest ESP", "Disabled", 2)
            StopLoop("ChestESP")
        end
    end)

    MkButton(Tabs.Visual, "Clear All ESP", "rbxassetid://10734896", function()
        ClearESP()
        for _, n in ipairs({"PlayerESP","SeedESP","FruitESP","ItemESP","NPCESP","ChestESP"}) do StopLoop(n) end
        Notify("ESP", "All ESP cleared", 2)
    end)

    MkSection(Tabs.Visual, "Rendering")

    MkToggle(Tabs.Visual, "Fullbright", "rbxassetid://10734896", "Fullbright", function(v)
        ScriptData.Config.Visual.Fullbright = v
        if v then
            Notify("Fullbright", "Enabled", 2)
            Services.Lighting.Brightness = 2
            Services.Lighting.ClockTime = 14
            Services.Lighting.FogEnd = 100000
            Services.Lighting.GlobalShadows = false
        else
            Notify("Fullbright", "Disabled", 2)
            Services.Lighting.Brightness = ScriptData.OriginalValues.Brightness
            Services.Lighting.ClockTime = ScriptData.OriginalValues.ClockTime
            Services.Lighting.FogEnd = ScriptData.OriginalValues.FogEnd
            Services.Lighting.GlobalShadows = ScriptData.OriginalValues.GlobalShadows
        end
    end)

    MkButton(Tabs.Visual, "Remove Fog", "rbxassetid://10734896", function()
        Services.Lighting.FogEnd = 100000
        for _, e in ipairs(Services.Lighting:GetChildren()) do
            pcall(function()
                if e:IsA("Atmosphere") then e.Density = 0 e.Haze = 0
                elseif e:IsA("PostEffect") then e.Enabled = false end
            end)
        end
        Notify("Fog", "Removed", 2)
    end)

    MkButton(Tabs.Visual, "FPS Boost", "rbxassetid://10734896", function()
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
        Notify("FPS Boost", "Applied", 2)
    end)

    MkButton(Tabs.Visual, "Destroy Effects", "rbxassetid://10734896", function()
        for _, v in pairs(workspace:GetDescendants()) do
            if not IsProtectedPath(v) then
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v:Destroy()
                    end
                end)
            end
        end
        Notify("Effects", "Destroyed", 2)
    end)
end

-- ========================
-- MISC TAB
-- ========================
if Tabs.Misc then
    MkSection(Tabs.Misc, "Server")

    MkButton(Tabs.Misc, "Server Hop", "rbxassetid://10734949", function()
        Notify("Server Hop", "Finding server...", 3)
        task.spawn(function()
            pcall(function()
                local req = request or http_request or (syn and syn.request)
                if not req then Notify("Error", "HTTP not supported", 3) return end
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
                else Notify("Error", "No servers found", 3) end
            end)
        end)
    end)

    MkButton(Tabs.Misc, "Rejoin", "rbxassetid://10734949", function()
        Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    MkButton(Tabs.Misc, "Copy JobId", "rbxassetid://10734949", function()
        if setclipboard then setclipboard(game.JobId) Notify("Copied", "JobId copied", 2)
        else Notify("Error", "Clipboard not supported", 3) end
    end)

    MkButton(Tabs.Misc, "Copy PlaceId", "rbxassetid://10734949", function()
        if setclipboard then setclipboard(tostring(game.PlaceId)) Notify("Copied", "PlaceId copied", 2)
        else Notify("Error", "Clipboard not supported", 3) end
    end)

    MkSection(Tabs.Misc, "Game")

    MkButton(Tabs.Misc, "Destroy Game UI", "rbxassetid://10734949", function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if not IsProtectedPath(g) and g ~= ScriptData.WindUIGui and g ~= ScriptData.MinimizeGui then
                pcall(function() g:Destroy() end)
            end
        end
        Notify("UI", "Game UI destroyed", 2)
    end)
end

-- ========================
-- SETTINGS TAB
-- ========================
if Tabs.Settings then
    MkSection(Tabs.Settings, "Configuration")

    local profileName = "default"

    MkInput(Tabs.Settings, "Profile Name", "rbxassetid://10734952", "Enter profile name", function(v)
        profileName = (v and v ~= "") and v or "default"
    end)

    MkButton(Tabs.Settings, "Save Config", "rbxassetid://10734952", function()
        if SaveCfg(profileName) then Notify("Saved", profileName, 2)
        else Notify("Error", "writefile not available", 3) end
    end)

    MkButton(Tabs.Settings, "Load Config", "rbxassetid://10734952", function()
        if LoadCfg(profileName) then Notify("Loaded", profileName, 2)
        else Notify("Error", "No config: " .. profileName, 3) end
    end)

    MkButton(Tabs.Settings, "Delete Config", "rbxassetid://10734952", function()
        local f = "X0D_GAG2_" .. profileName .. ".json"
        if isfile and isfile(f) and delfile then
            pcall(function() delfile(f) end)
            Notify("Deleted", profileName, 2)
        else Notify("Error", "File not found", 3) end
    end)

    MkToggle(Tabs.Settings, "Auto Save (60s)", "rbxassetid://10734952", "AutoSaveCfg", function(v)
        ScriptData.Config.Settings.AutoSave = v
        if v then
            Notify("Auto Save", "Enabled", 2)
            CreateLoop("AutoSave", function() SaveCfg(profileName) end, 60)
        else
            Notify("Auto Save", "Disabled", 2)
            StopLoop("AutoSave")
        end
    end)

    MkSection(Tabs.Settings, "Toggle UI")
    MkLabel(Tabs.Settings, "Click the X0D HUB button to open/close UI")
    MkLabel(Tabs.Settings, "Drag the X0D HUB button to reposition it")
    MkLabel(Tabs.Settings, "Cyan = Open | Purple = Closed")
end

-- ========================
-- CREDITS TAB
-- ========================
if Tabs.Credits then
    MkSection(Tabs.Credits, "About")

    MkParagraph(Tabs.Credits, "X0DEC04T Hub v1.0.0",
        "Premium automation hub for Grow a Garden 2.\nCreated by X0DEC04T\nPowered by WindUI")

    MkParagraph(Tabs.Credits, "Features",
        "Auto Harvest / Plant / Water / Fertilize\n" ..
        "Auto Sell / Buy Seeds / Buy Gear\n" ..
        "Auto Collect / Quest / Upgrade / Rebirth\n" ..
        "Auto Claim / Event / Gift\n" ..
        "Fly / NoClip / Infinite Jump / Anti AFK\n" ..
        "Spinbot / Fullbright / ESP (6 types)\n" ..
        "FPS Boost / Teleports / Server Hop")

    MkButton(Tabs.Credits, "Copy Discord", "rbxassetid://10747373", function()
        if setclipboard then setclipboard("discord.gg/x0dec04t") Notify("Discord", "Link copied!", 2)
        else Notify("Discord", "discord.gg/x0dec04t", 5) end
    end)
end

-- ========================
-- CHARACTER RESTORE ON RESPAWN
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
    UpdateCache()
end))

AddConnection("PlayerRemESP", Services.Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer and p.Character then RemoveESP(p.Character) end
end))

task.spawn(function()
    while task.wait(8) do UpdateCache() end
end)

pcall(function() LoadCfg("default") end)

Notify("X0DEC04T Hub", "Loaded! Click the X0D HUB button to open the UI.", 6)

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
