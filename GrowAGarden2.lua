```lua
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
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/main.lua",
        "https://cdn.footagesus.me/WindUI/main.lua"
    }
    for _, url in ipairs(urls) do
        local ok, result = pcall(function()
            return loadstring(game:HttpGet(url, true))()
        end)
        if ok and result then
            WindUI = result
            break
        else
            warn("[X0DEC04T] WindUI load failed from: " .. url .. " | " .. tostring(result))
        end
    end
end

if not WindUI then
    pcall(function()
        Services.StarterGui:SetCore("SendNotification", {
            Title = "X0DEC04T Hub",
            Text = "Failed to load WindUI. Check executor HTTP support.",
            Duration = 10
        })
    end)
    return
end

local ScriptData = {
    Connections = {},
    Loops = {},
    ESPObjects = {},
    UIVisible = true,
    MinimizeGui = nil,
    WindUIGui = nil,
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

local function BuildMinimizeButton()
    local sg = Instance.new("ScreenGui")
    sg.Name = "X0D_MinBtn"
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

    local btn = Instance.new("TextButton")
    btn.Name = "X0DBtn"
    btn.Size = UDim2.new(0, 56, 0, 56)
    btn.Position = UDim2.new(1, -76, 0, 16)
    btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = sg

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = btn

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 0, 120))
    }
    grad.Rotation = 135
    grad.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(170, 80, 255)
    stroke.Thickness = 2
    stroke.Parent = btn

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0.6, 0)
    lbl.Position = UDim2.new(0, 0, 0.1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "X0D"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = btn

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, 0, 0.3, 0)
    sub.Position = UDim2.new(0, 0, 0.68, 0)
    sub.BackgroundTransparency = 1
    sub.Text = "HUB"
    sub.TextColor3 = Color3.fromRGB(200, 160, 255)
    sub.TextScaled = true
    sub.Font = Enum.Font.Gotham
    sub.Parent = btn

    local dragging, dragStart, startPos = false, nil, nil
    local clickTime = 0
    local hasMoved = false

    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            hasMoved = false
            dragStart = inp.Position
            startPos = btn.Position
            clickTime = tick()
        end
    end)

    btn.InputChanged:Connect(function(inp)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - dragStart
            if delta.Magnitude > 5 then hasMoved = true end
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if not hasMoved and tick() - clickTime < 0.3 then
                ScriptData.UIVisible = not ScriptData.UIVisible
                if ScriptData.WindUIGui then
                    ScriptData.WindUIGui.Enabled = ScriptData.UIVisible
                end
                local targetRot = ScriptData.UIVisible and 0 or 180
                Services.TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Rotation = targetRot}):Play()
                local targetColor = ScriptData.UIVisible and Color3.fromRGB(170, 80, 255) or Color3.fromRGB(255, 80, 80)
                Services.TweenService:Create(stroke, TweenInfo.new(0.25), {Color = targetColor}):Play()
            end
        end
    end)

    btn.MouseEnter:Connect(function()
        Services.TweenService:Create(btn, TweenInfo.new(0.15), {Size = UDim2.new(0, 64, 0, 64)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        Services.TweenService:Create(btn, TweenInfo.new(0.15), {Size = UDim2.new(0, 56, 0, 56)}):Play()
    end)

    ScriptData.MinimizeGui = sg
    return sg
end

BuildMinimizeButton()

local Tabs = {}
SafeCall(function() Tabs.Main = Window:Tab({ Title = "Main", Icon = "rbxassetid://10734950" }) end)
SafeCall(function() Tabs.Player = Window:Tab({ Title = "Player", Icon = "rbxassetid://10747372" }) end)
SafeCall(function() Tabs.Teleport = Window:Tab({ Title = "Teleport", Icon = "rbxassetid://10723407" }) end)
SafeCall(function() Tabs.Visual = Window:Tab({ Title = "Visual", Icon = "rbxassetid://10734896" }) end)
SafeCall(function() Tabs.Misc = Window:Tab({ Title = "Misc", Icon = "rbxassetid://10734949" }) end)
SafeCall(function() Tabs.Settings = Window:Tab({ Title = "Settings", Icon = "rbxassetid://10734952" }) end)
SafeCall(function() Tabs.Credits = Window:Tab({ Title = "Credits", Icon = "rbxassetid://10747373" }) end)

local function MkToggle(tab, name, flag, cb)
    SafeCall(function()
        tab:Toggle({
            Title = name,
            Default = false,
            Flag = flag,
            Callback = cb
        })
    end)
end

local function MkButton(tab, name, cb)
    SafeCall(function()
        tab:Button({ Title = name, Callback = cb })
    end)
end

local function MkSlider(tab, name, flag, min, max, def, cb)
    SafeCall(function()
        tab:Slider({
            Title = name,
            Flag = flag,
            Step = 1,
            Value = { Min = min, Max = max, Default = def },
            Callback = cb
        })
    end)
end

local function MkInput(tab, name, placeholder, cb)
    SafeCall(function()
        tab:Input({
            Title = name,
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

local function MkDropdown(tab, name, flag, list, cb)
    SafeCall(function()
        tab:Dropdown({
            Title = name,
            Flag = flag,
            Values = list,
            Callback = cb
        })
    end)
end

-- =====================
-- MAIN TAB
-- =====================
if Tabs.Main then
    MkSection(Tabs.Main, "Farming")

    MkToggle(Tabs.Main, "Auto Harvest", "AutoHarvest", function(v)
        ScriptData.Config.Main.AutoHarvest = v
        if v then
            Notify("Auto Harvest", "Enabled", 2)
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
            Notify("Auto Harvest", "Disabled", 2)
            StopLoop("AutoHarvest")
        end
    end)

    MkToggle(Tabs.Main, "Auto Plant", "AutoPlant", function(v)
        ScriptData.Config.Main.AutoPlant = v
        if v then
            Notify("Auto Plant", "Enabled", 2)
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
            Notify("Auto Plant", "Disabled", 2)
            StopLoop("AutoPlant")
        end
    end)

    MkToggle(Tabs.Main, "Auto Water", "AutoWater", function(v)
        ScriptData.Config.Main.AutoWater = v
        if v then
            Notify("Auto Water", "Enabled", 2)
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
            Notify("Auto Water", "Disabled", 2)
            StopLoop("AutoWater")
        end
    end)

    MkToggle(Tabs.Main, "Auto Fertilize", "AutoFertilize", function(v)
        ScriptData.Config.Main.AutoFertilize = v
        if v then
            Notify("Auto Fertilize", "Enabled", 2)
            CreateLoop("AutoFertilize", function()
                for _, plant in ipairs(FindPlants()) do
                    if plant and plant.Parent then
                        Fire("FertilizePlant", plant)
                        Fire("Fertilize", plant)
                    end
                end
            end, 1)
        else
            Notify("Auto Fertilize", "Disabled", 2)
            StopLoop("AutoFertilize")
        end
    end)

    MkSection(Tabs.Main, "Shop & Economy")

    MkInput(Tabs.Main, "Seed Name", "e.g. Carrot", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedSeed = v
            Notify("Seed Set", v, 2)
        end
    end)

    MkInput(Tabs.Main, "Gear Name", "e.g. Basic Watering Can", function(v)
        if v and v ~= "" then
            ScriptData.Config.Main.SelectedGear = v
            Notify("Gear Set", v, 2)
        end
    end)

    MkToggle(Tabs.Main, "Auto Sell", "AutoSell", function(v)
        ScriptData.Config.Main.AutoSell = v
        if v then
            Notify("Auto Sell", "Enabled", 2)
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
            Notify("Auto Sell", "Disabled", 2)
            StopLoop("AutoSell")
        end
    end)

    MkToggle(Tabs.Main, "Auto Buy Seeds", "AutoBuySeeds", function(v)
        ScriptData.Config.Main.AutoBuySeeds = v
        if v then
            Notify("Auto Buy Seeds", "Enabled", 2)
            CreateLoop("AutoBuySeeds", function()
                Fire("BuySeed", ScriptData.Config.Main.SelectedSeed)
                Fire("PurchaseSeed", ScriptData.Config.Main.SelectedSeed)
            end, 3)
        else
            Notify("Auto Buy Seeds", "Disabled", 2)
            StopLoop("AutoBuySeeds")
        end
    end)

    MkToggle(Tabs.Main, "Auto Buy Gear", "AutoBuyGear", function(v)
        ScriptData.Config.Main.AutoBuyGear = v
        if v then
            Notify("Auto Buy Gear", "Enabled", 2)
            CreateLoop("AutoBuyGear", function()
                Fire("BuyGear", ScriptData.Config.Main.SelectedGear)
                Fire("PurchaseGear", ScriptData.Config.Main.SelectedGear)
            end, 3)
        else
            Notify("Auto Buy Gear", "Disabled", 2)
            StopLoop("AutoBuyGear")
        end
    end)

    MkSection(Tabs.Main, "Automation")

    MkToggle(Tabs.Main, "Auto Collect Drops", "AutoCollectDrops", function(v)
        ScriptData.Config.Main.AutoCollectDrops = v
        if v then
            Notify("Auto Collect", "Enabled", 2)
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
            Notify("Auto Collect", "Disabled", 2)
            StopLoop("AutoCollectDrops")
        end
    end)

    MkToggle(Tabs.Main, "Auto Quest", "AutoQuest", function(v)
        ScriptData.Config.Main.AutoQuest = v
        if v then
            Notify("Auto Quest", "Enabled", 2)
            CreateLoop("AutoQuest", function()
                Fire("AcceptQuest")
                Fire("Quest")
                Fire("CompleteQuest")
                Fire("TurnInQuest")
            end, 2)
        else
            Notify("Auto Quest", "Disabled", 2)
            StopLoop("AutoQuest")
        end
    end)

    MkToggle(Tabs.Main, "Auto Upgrade", "AutoUpgrade", function(v)
        ScriptData.Config.Main.AutoUpgrade = v
        if v then
            Notify("Auto Upgrade", "Enabled", 2)
            CreateLoop("AutoUpgrade", function()
                Fire("Upgrade")
                Fire("upgrade")
                Fire("UpgradeTool")
                Fire("UpgradePlot")
            end, 3)
        else
            Notify("Auto Upgrade", "Disabled", 2)
            StopLoop("AutoUpgrade")
        end
    end)

    MkToggle(Tabs.Main, "Auto Rebirth", "AutoRebirth", function(v)
        ScriptData.Config.Main.AutoRebirth = v
        if v then
            Notify("Auto Rebirth", "Enabled", 2)
            CreateLoop("AutoRebirth", function()
                Fire("Rebirth")
                Fire("rebirth")
                Fire("Prestige")
            end, 5)
        else
            Notify("Auto Rebirth", "Disabled", 2)
            StopLoop("AutoRebirth")
        end
    end)

    MkToggle(Tabs.Main, "Auto Claim Rewards", "AutoClaimRewards", function(v)
        ScriptData.Config.Main.AutoClaimRewards = v
        if v then
            Notify("Auto Claim", "Enabled", 2)
            CreateLoop("AutoClaimRewards", function()
                Fire("ClaimReward")
                Fire("Claim")
                Fire("ClaimDaily")
                Fire("ClaimAchievement")
            end, 2)
        else
            Notify("Auto Claim", "Disabled", 2)
            StopLoop("AutoClaimRewards")
        end
    end)

    MkToggle(Tabs.Main, "Auto Event", "AutoEvent", function(v)
        ScriptData.Config.Main.AutoEvent = v
        if v then
            Notify("Auto Event", "Enabled", 2)
            CreateLoop("AutoEvent", function()
                Fire("JoinEvent")
                Fire("Event")
                Fire("event")
            end, 2)
        else
            Notify("Auto Event", "Disabled", 2)
            StopLoop("AutoEvent")
        end
    end)

    MkToggle(Tabs.Main, "Auto Gift", "AutoGift", function(v)
        ScriptData.Config.Main.AutoGift = v
        if v then
            Notify("Auto Gift", "Enabled", 2)
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
            Notify("Auto Gift", "Disabled", 2)
            StopLoop("AutoGift")
        end
    end)
end

-- =====================
-- PLAYER TAB
-- =====================
if Tabs.Player then
    MkSection(Tabs.Player, "Movement")

    MkSlider(Tabs.Player, "WalkSpeed", "WalkSpeed", 16, 200, 16, function(v)
        ScriptData.Config.Player.WalkSpeed = v
        local h = GetHum()
        if h then h.WalkSpeed = v end
    end)

    MkSlider(Tabs.Player, "JumpPower", "JumpPower", 50, 300, 50, function(v)
        ScriptData.Config.Player.JumpPower = v
        local h = GetHum()
        if h then h.JumpPower = v h.UseJumpPower = true end
    end)

    MkSlider(Tabs.Player, "Gravity", "Gravity", 0, 196, 196, function(v)
        ScriptData.Config.Player.Gravity = v
        workspace.Gravity = v
    end)

    MkSection(Tabs.Player, "Flight")

    MkToggle(Tabs.Player, "Fly", "Fly", function(v)
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

    MkSlider(Tabs.Player, "Fly Speed", "FlySpeed", 10, 300, 50, function(v)
        ScriptData.Config.Player.FlySpeed = v
    end)

    MkSection(Tabs.Player, "Abilities")

    MkToggle(Tabs.Player, "NoClip", "NoClip", function(v)
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

    MkToggle(Tabs.Player, "Infinite Jump", "InfiniteJump", function(v)
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

    MkToggle(Tabs.Player, "Anti AFK", "AntiAFK", function(v)
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

    MkToggle(Tabs.Player, "Spinbot", "Spinbot", function(v)
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

    MkSlider(Tabs.Player, "Spinbot Speed", "SpinbotSpeed", 1, 50, 10, function(v)
        ScriptData.Config.Player.SpinbotSpeed = v
    end)

    MkButton(Tabs.Player, "Safe Reset", function()
        local h = GetHum()
        if h then h.Health = 0 Notify("Reset", "Character reset", 2) end
    end)
end

-- =====================
-- TELEPORT TAB
-- =====================
if Tabs.Teleport then
    MkSection(Tabs.Teleport, "Locations")

    MkButton(Tabs.Teleport, "Teleport to Shop", function()
        UpdateCache()
        task.wait(0.1)
        if GameCache.Shop then
            local p = GameCache.Shop:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Shop", 2) end
        else
            Notify("Error", "Shop not found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "Teleport to Garden", function()
        UpdateCache()
        task.wait(0.1)
        if GameCache.Garden then
            local p = GameCache.Garden:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Garden", 2) end
        else
            Notify("Error", "Garden not found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "Teleport to Spawn", function()
        UpdateCache()
        task.wait(0.1)
        if GameCache.Spawn then
            TeleportTo(GameCache.Spawn.Position + Vector3.new(0, 5, 0))
            Notify("Teleport", "Teleported to Spawn", 2)
        else
            Notify("Error", "Spawn not found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "Teleport to NPCs", function()
        UpdateCache()
        task.wait(0.1)
        if #GameCache.NPCs > 0 then
            local npc = GameCache.NPCs[1]
            local p = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(5, 0, 0)) Notify("Teleport", "Teleported to NPC", 2) end
        else
            Notify("Error", "No NPCs found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "Teleport to Events", function()
        local events = FindAll(workspace, "event", "Model")
        if #events > 0 then
            local p = events[1]:FindFirstChildWhichIsA("BasePart")
            if p then TeleportTo(p.Position + Vector3.new(0, 5, 0)) Notify("Teleport", "Teleported to Event", 2) end
        else
            Notify("Error", "No events found", 3)
        end
    end)

    MkSection(Tabs.Teleport, "Players")

    local selPlayer = ""
    MkInput(Tabs.Teleport, "Player Name", "Type exact name", function(v) selPlayer = v end)

    do
        local names = {}
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(names, p.Name) end
        end
        if #names == 0 then names = {"No players"} end
        MkDropdown(Tabs.Teleport, "Or Select Player", "SelPlayerDrop", names, function(v) selPlayer = v end)
    end

    MkButton(Tabs.Teleport, "Teleport to Player", function()
        if selPlayer == "" then Notify("Error", "Select or type a player", 3) return end
        local target
        for _, p in ipairs(Services.Players:GetPlayers()) do
            if p.Name:lower() == selPlayer:lower() then target = p break end
        end
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            TeleportTo(target.Character.HumanoidRootPart.Position + Vector3.new(5, 0, 0))
            Notify("Success", "Teleported to " .. target.Name, 2)
        else
            Notify("Error", "Player not found", 3)
        end
    end)

    MkButton(Tabs.Teleport, "Refresh Player List", function()
        Notify("Info", "Retype player name to refresh", 3)
    end)
end

-- =====================
-- VISUAL TAB
-- =====================
if Tabs.Visual then
    MkSection(Tabs.Visual, "ESP")

    MkToggle(Tabs.Visual, "Player ESP", "PlayerESP", function(v)
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

    MkToggle(Tabs.Visual, "Seed ESP", "SeedESP", function(v)
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

    MkToggle(Tabs.Visual, "Fruit ESP", "FruitESP", function(v)
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

    MkToggle(Tabs.Visual, "Item ESP", "ItemESP", function(v)
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

    MkToggle(Tabs.Visual, "NPC ESP", "NPCESP", function(v)
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

    MkToggle(Tabs.Visual, "Chest ESP", "ChestESP", function(v)
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

    MkSection(Tabs.Visual, "Rendering")

    MkToggle(Tabs.Visual, "Fullbright", "Fullbright", function(v)
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

    MkButton(Tabs.Visual, "Remove Fog", function()
        Services.Lighting.FogEnd = 100000
        for _, e in ipairs(Services.Lighting:GetChildren()) do
            pcall(function()
                if e:IsA("Atmosphere") then e.Density = 0 e.Haze = 0
                elseif e:IsA("PostEffect") then e.Enabled = false end
            end)
        end
        Notify("Success", "Fog removed", 2)
    end)

    MkButton(Tabs.Visual, "FPS Boost", function()
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
        Notify("Success", "FPS Boost applied", 2)
    end)

    MkButton(Tabs.Visual, "Destroy Effects", function()
        for _, v in pairs(workspace:GetDescendants()) do
            if not IsProtectedPath(v) then
                pcall(function()
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v:Destroy()
                    end
                end)
            end
        end
        Notify("Success", "Effects destroyed", 2)
    end)

    MkButton(Tabs.Visual, "Clear All ESP", function()
        ClearESP()
        StopLoop("PlayerESP") StopLoop("SeedESP") StopLoop("FruitESP")
        StopLoop("ItemESP") StopLoop("NPCESP") StopLoop("ChestESP")
        Notify("Success", "All ESP cleared", 2)
    end)
end

-- =====================
-- MISC TAB
-- =====================
if Tabs.Misc then
    MkSection(Tabs.Misc, "Server")

    MkButton(Tabs.Misc, "Server Hop", function()
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
                else
                    Notify("Error", "No servers found", 3)
                end
            end)
        end)
    end)

    MkButton(Tabs.Misc, "Rejoin", function()
        Services.TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)

    MkButton(Tabs.Misc, "Copy JobId", function()
        if setclipboard then setclipboard(game.JobId) Notify("Copied", game.JobId, 2)
        else Notify("Error", "Clipboard not supported", 3) end
    end)

    MkButton(Tabs.Misc, "Copy PlaceId", function()
        if setclipboard then setclipboard(tostring(game.PlaceId)) Notify("Copied", tostring(game.PlaceId), 2)
        else Notify("Error", "Clipboard not supported", 3) end
    end)

    MkSection(Tabs.Misc, "Game")

    MkButton(Tabs.Misc, "Destroy Game UI", function()
        for _, g in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if not IsProtectedPath(g) and g ~= ScriptData.WindUIGui then
                pcall(function() g:Destroy() end)
            end
        end
        Notify("Success", "Game UI destroyed", 2)
    end)
end

-- =====================
-- SETTINGS TAB
-- =====================
if Tabs.Settings then
    MkSection(Tabs.Settings, "Configuration")

    local profileName = "default"

    MkInput(Tabs.Settings, "Profile Name", "Enter profile name", function(v)
        profileName = (v and v ~= "") and v or "default"
    end)

    MkButton(Tabs.Settings, "Save Config", function()
        if SaveCfg(profileName) then Notify("Saved", profileName, 2)
        else Notify("Error", "writefile not available", 3) end
    end)

    MkButton(Tabs.Settings, "Load Config", function()
        if LoadCfg(profileName) then Notify("Loaded", profileName, 2)
        else Notify("Error", "No config found: " .. profileName, 3) end
    end)

    MkButton(Tabs.Settings, "Delete Config", function()
        local f = "X0D_GAG2_" .. profileName .. ".json"
        if isfile and isfile(f) and delfile then
            pcall(function() delfile(f) end)
            Notify("Deleted", profileName, 2)
        else
            Notify("Error", "File not found", 3)
        end
    end)

    MkToggle(Tabs.Settings, "Auto Save (60s)", "AutoSaveCfg", function(v)
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

    MkLabel(Tabs.Settings, "Click the X0D button to toggle UI")
    MkLabel(Tabs.Settings, "You can drag the X0D button anywhere")
end

-- =====================
-- CREDITS TAB
-- =====================
if Tabs.Credits then
    MkSection(Tabs.Credits, "About")

    MkParagraph(Tabs.Credits, "X0DEC04T Hub v1.0.0",
        "Premium automation hub for Grow a Garden 2.\nCreated by X0DEC04T | Powered by WindUI")

    MkParagraph(Tabs.Credits, "Features",
        "Auto Harvest / Plant / Water / Fertilize\n" ..
        "Auto Sell / Buy Seeds / Buy Gear\n" ..
        "Auto Collect / Quest / Upgrade / Rebirth\n" ..
        "Auto Claim / Event / Gift\n" ..
        "Fly / NoClip / Infinite Jump / Anti AFK\n" ..
        "Player/Seed/Fruit/Item/NPC/Chest ESP\n" ..
        "FPS Boost / Fullbright / Teleports")

    MkButton(Tabs.Credits, "Copy Discord", function()
        if setclipboard then setclipboard("discord.gg/x0dec04t") Notify("Discord", "Link copied!", 2)
        else Notify("Discord", "discord.gg/x0dec04t", 5) end
    end)
end

-- =====================
-- CHARACTER RESTORE ON RESPAWN
-- =====================
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

Notify("X0DEC04T Hub", "Loaded! Tap X0D button to toggle UI.", 5)

-- =====================
-- CLEANUP
-- =====================
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
```
